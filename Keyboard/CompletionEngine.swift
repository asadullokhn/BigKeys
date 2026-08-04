import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device phrase completion. All FoundationModels access lives here;
/// the controller only sees requestCompletion/isDegraded. On any
/// unavailability or repeated failure the engine degrades permanently for
/// the session and the keyboard behaves exactly as it did before this
/// feature existed. On the simulator generation always fails, so the
/// degraded path is the tested path.
final class CompletionEngine {

    struct Completion {
        let words: [String]
    }

    private(set) var isDegraded = false

    private let debounceInterval: TimeInterval = 0.3
    private let timeout: TimeInterval = 2.0
    private var generation = 0
    private var consecutiveFailures = 0
    private var pendingWork: DispatchWorkItem?

    func requestCompletion(context: String,
                           vocabulary: [String],
                           onResult: @escaping (Completion?) -> Void) {
        pendingWork?.cancel()
        generation += 1
        let token = generation

        guard !isDegraded else { onResult(nil); return }

        let work = DispatchWorkItem { [weak self] in
            self?.generate(context: context, vocabulary: vocabulary, token: token, onResult: onResult)
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func deliver(_ completion: Completion?, token: Int,
                         onResult: @escaping (Completion?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, token == self.generation else { return }
            onResult(completion)
        }
    }

    private func recordFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= 2 {
            isDegraded = true
            session = nil
        }
    }

    /// Splits the model's text into at most five clean words; nil when
    /// nothing usable remains.
    private func sanitize(_ text: String) -> Completion? {
        let words = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)
        return words.isEmpty ? nil : Completion(words: Array(words))
    }

#if canImport(FoundationModels)
    private var session: Any?

    private func generate(context: String, vocabulary: [String], token: Int,
                          onResult: @escaping (Completion?) -> Void) {
        guard #available(iOS 26.0, *) else {
            isDegraded = true
            deliver(nil, token: token, onResult: onResult)
            return
        }
        guard SystemLanguageModel.default.availability == .available else {
            isDegraded = true
            deliver(nil, token: token, onResult: onResult)
            return
        }

        let voice = vocabulary.prefix(40).joined(separator: ", ")
        let snippet = String(context.suffix(200))
        let prompt = """
        Continue the user's sentence naturally. Answer with at most 5 words, \
        plain text only, no punctuation unless it ends the sentence. Match the \
        user's simple, direct style. Words this user often uses: \(voice).
        Sentence so far: \(snippet)
        """

        let existing = session as? LanguageModelSession
        let liveSession = existing ?? LanguageModelSession()
        session = liveSession

        Task { [weak self] in
            guard let self else { return }
            let generator = Task {
                try await liveSession.respond(to: prompt).content
            }
            let watchdog = Task {
                try await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                generator.cancel()
            }
            do {
                let text = try await generator.value
                watchdog.cancel()
                await MainActor.run {
                    self.consecutiveFailures = 0
                    self.deliver(self.sanitize(text), token: token, onResult: onResult)
                }
            } catch {
                watchdog.cancel()
                await MainActor.run {
                    self.recordFailure()
                    self.deliver(nil, token: token, onResult: onResult)
                }
            }
        }
    }
#else
    private var session: Any?

    private func generate(context: String, vocabulary: [String], token: Int,
                          onResult: @escaping (Completion?) -> Void) {
        isDegraded = true
        deliver(nil, token: token, onResult: onResult)
    }
#endif
}
