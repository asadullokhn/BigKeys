import Foundation
import Vision

/// The screen-learning word pipeline, shared by the broadcast extension
/// (which feeds it live frames) and the container app (which runs it on a
/// synthetic image for the on-device self-test). Keeping it in one place
/// is what makes the OCR path verifiable without a live broadcast — the
/// only thing the extension adds on top is ReplayKit frame delivery.
enum ScreenWords {
    static let suiteName = "group.com.asadullokh.ch5.typikey"
    static let countsKey = "screenWords"
    static let stampKey = "screenWordsStamp"
    static let keyboardAccessKey = "keyboardHasFullAccess"

    /// Function words carry no context signal — the keyboard's bigrams and
    /// seeds already cover them, and letting them dominate the store would
    /// drown the distinctive words this feature exists to surface.
    static let stopwords: Set<String> = [
        "the", "and", "you", "for", "that", "with", "this", "are", "was",
        "have", "but", "not", "all", "can", "will", "from", "they", "been",
        "were", "which", "their", "your", "there", "would", "about", "into",
        "more", "some", "them", "than", "then", "also", "when", "what",
        "how", "who", "why", "has", "had", "its", "our", "out", "get",
    ]

    /// Lowercased tokens of 3-24 characters containing at least one letter
    /// and no digits, apostrophes allowed inside a word, function words
    /// dropped.
    static func tokens(in line: String) -> [String] {
        var splitSet = CharacterSet.alphanumerics
        splitSet.insert(charactersIn: "'")
        return line.lowercased()
            .components(separatedBy: splitSet.inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { token in
                token.count >= 3 && token.count <= 24
                    && token.rangeOfCharacter(from: .letters) != nil
                    // Digit-substitution artifacts ("he11o", "0ffice") are a
                    // classic OCR corruption — real words with digits are
                    // rare enough that dropping them all is the safer trade.
                    && token.rangeOfCharacter(from: .decimalDigits) == nil
                    && !stopwords.contains(token)
            }
    }

    /// A configured recognizer: on-device, cheapest pass, whatever language
    /// is on screen. `.fast` matters under the extension's ~50 MB ceiling.
    static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        return request
    }

    /// Confidence floor: garbled low-confidence OCR is the top context
    /// polluter — a wrong word suggested later is worse than a missed one.
    static func words(from request: VNRecognizeTextRequest) -> Set<String> {
        var found: Set<String> = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { continue }
            for token in tokens(in: candidate.string) {
                found.insert(token)
            }
        }
        return found
    }

    /// Merges new appearances into the bounded shared store.
    static func merge(_ fresh: Set<String>, into suite: UserDefaults) {
        guard !fresh.isEmpty else { return }
        var counts = (suite.dictionary(forKey: countsKey) as? [String: Int]) ?? [:]
        for word in fresh {
            counts[word, default: 0] += 1
        }
        if counts.count > 400 {
            counts = Dictionary(
                uniqueKeysWithValues: counts.sorted { $0.value > $1.value }.prefix(400).map { ($0.key, $0.value) })
        }
        suite.set(counts, forKey: countsKey)
        suite.set(Date().timeIntervalSince1970, forKey: stampKey)
    }
}
