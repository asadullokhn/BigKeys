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
@MainActor
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
    private var inFlight: Task<Void, Never>?

    func requestCompletion(context: String,
                           vocabulary: [String],
                           onResult: @escaping (Completion?) -> Void) {
        pendingWork?.cancel()
        inFlight?.cancel()
        generation += 1
        let token = generation

        guard !isDegraded else { onResult(nil); return }

        let work = DispatchWorkItem { [weak self] in
            // DispatchQueue.main guarantees we're already on the main thread here;
            // assumeIsolated bridges into the MainActor-isolated generate() without
            // an extra async hop.
            MainActor.assumeIsolated {
                self?.generate(context: context, vocabulary: vocabulary, token: token, onResult: onResult)
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func deliver(_ completion: Completion?, token: Int,
                         onResult: @escaping (Completion?) -> Void) {
        guard token == generation else { return }
        onResult(completion)
    }

    private func recordFailure() {
        consecutiveFailures += 1
        session = nil
        if consecutiveFailures >= 2 {
            isDegraded = true
        }
    }

    private static let trailingPunctuation = ".!?,;:"

    /// Splits the model's text into at most five clean words; nil when
    /// nothing usable remains. Trims punctuation glued to the end of a word
    /// and drops tokens with no letters or digits (bare "-" or "▸" isn't a
    /// word).
    private func sanitize(_ text: String) -> Completion? {
        let words = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { token -> String in
                var token = token
                while let last = token.last, Self.trailingPunctuation.contains(last) {
                    token.removeLast()
                }
                return token
            }
            .filter { !$0.isEmpty }
            .filter { $0.rangeOfCharacter(from: .alphanumerics) != nil }
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
        Continue the user's sentence naturally, in the same language the \
        sentence is written in. Answer with at most 5 words, plain text only, \
        no punctuation unless it ends the sentence. Match the user's simple, \
        direct style. Words this user often uses: \(voice).
        Sentence so far: \(snippet)
        """

        let existing = session as? LanguageModelSession
        let liveSession = existing ?? LanguageModelSession()
        session = liveSession
        let watchdogTimeout = timeout

        inFlight = Task { [weak self] in
            guard let self else { return }
            // Detached: these only touch liveSession/prompt/each other, never
            // engine state, so the actual model call and its timer run off the
            // main actor instead of serializing through it.
            let generator = Task.detached {
                try await liveSession.respond(to: prompt).content
            }
            let watchdog = Task.detached {
                try await Task.sleep(nanoseconds: UInt64(watchdogTimeout * 1_000_000_000))
                generator.cancel()
            }
            // Propagate outer-task cancellation (a superseding request) down into
            // the in-flight respond() call, the same way the watchdog already does
            // for timeouts, so a stale generation never keeps running concurrently
            // with the next one.
            await withTaskCancellationHandler {
                do {
                    let text = try await generator.value
                    watchdog.cancel()
                    // Supersession bumps `generation` before cancelling us; a
                    // stale success (result arrived just as it was superseded)
                    // must not reset the failure streak for the live generation.
                    if token == self.generation {
                        self.consecutiveFailures = 0
                    }
                    self.deliver(self.sanitize(text), token: token, onResult: onResult)
                } catch {
                    watchdog.cancel()
                    // Both supersession and a watchdog timeout cancel `generator`
                    // and surface here as CancellationError, so the error type
                    // alone can't tell them apart. Only supersession cancels
                    // `inFlight` (the ambient task this closure runs as part of);
                    // the watchdog only ever cancels `generator`. A real timeout
                    // must still count as a failure and degrade like any other.
                    if Task.isCancelled { return }
                    self.recordFailure()
                    self.deliver(nil, token: token, onResult: onResult)
                }
            } onCancel: {
                generator.cancel()
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
