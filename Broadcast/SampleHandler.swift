import ReplayKit
import Vision

/// Screen learning: a broadcast upload extension the user starts explicitly
/// from the app's "Learn from my screen" card (or Control Center). While the
/// system's red recording indicator is visible, throttled frames are OCR'd
/// on-device and merged into a word-frequency store in the app group. The
/// keyboard reads that store to bias its suggestions toward what the user is
/// currently looking at.
///
/// Privacy contract (matches invariant 5's spirit): everything stays on this
/// device. No network, no frames retained, no text history — only a bounded
/// word -> count dictionary in the shared container.
///
/// Memory contract: broadcast extensions are jetsam-killed near ~50 MB RSS.
/// Every guard here serves that ceiling: 1 frame / 2 s throttle, .fast
/// recognition, autoreleasepool per frame, no buffer retention.
final class SampleHandler: RPBroadcastSampleHandler {

    private let suite = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey")

    private let lock = NSLock()
    private var lastProcessedAt = Date.distantPast
    private var isProcessing = false

    /// Words present in the previously processed frame. A word only counts
    /// again once it has left the screen — staring at a static page for a
    /// minute must not inflate its words 30x.
    private var previousFrameWords: Set<String> = []

    /// Function words carry no context signal — the keyboard's bigrams and
    /// seeds already cover them, and letting them dominate the store would
    /// drown the distinctive words this feature exists to surface.
    private static let stopwords: Set<String> = [
        "the", "and", "you", "for", "that", "with", "this", "are", "was",
        "have", "but", "not", "all", "can", "will", "from", "they", "been",
        "were", "which", "their", "your", "there", "would", "about", "into",
        "more", "some", "them", "than", "then", "also", "when", "what",
        "how", "who", "why", "has", "had", "its", "our", "out", "get",
    ]

    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast           // on-device, cheapest pass
        request.usesLanguageCorrection = false     // raw tokens, not autocorrect
        request.automaticallyDetectsLanguage = true // read the screen in whatever language it's in
        return request
    }()

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        lock.lock()
        let due = !isProcessing && Date().timeIntervalSince(lastProcessedAt) >= 2
        if due {
            isProcessing = true
            lastProcessedAt = Date()
        }
        lock.unlock()
        guard due else { return }
        defer {
            lock.lock()
            isProcessing = false
            lock.unlock()
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        autoreleasepool {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try? handler.perform([textRequest])
            harvest()
        }
    }

    /// Tokenizes the recognized lines and merges NEW appearances (words not
    /// in the previous frame) into the shared store. Written through every
    /// processed frame — at most one write / 2 s — so a jetsam kill mid-
    /// session loses nothing.
    private func harvest() {
        var frameWords: Set<String> = []
        for observation in textRequest.results ?? [] {
            // Confidence floor: garbled low-confidence OCR is the #1
            // context polluter — a wrong word suggested later is worse
            // than a missed one.
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { continue }
            for token in Self.tokens(in: candidate.string) {
                frameWords.insert(token)
            }
        }
        let fresh = frameWords.subtracting(previousFrameWords)
        previousFrameWords = frameWords
        guard !fresh.isEmpty, let suite else { return }

        var counts = (suite.dictionary(forKey: "screenWords") as? [String: Int]) ?? [:]
        for word in fresh {
            counts[word, default: 0] += 1
        }
        // Bound the store: keep the 400 strongest words, drop the tail.
        if counts.count > 400 {
            counts = Dictionary(
                uniqueKeysWithValues: counts.sorted { $0.value > $1.value }.prefix(400).map { ($0.key, $0.value) })
        }
        suite.set(counts, forKey: "screenWords")
        suite.set(Date().timeIntervalSince1970, forKey: "screenWordsStamp")
    }

    /// Lowercased tokens of 3-24 characters containing at least one letter,
    /// apostrophes allowed inside a word, function words dropped.
    private static func tokens(in line: String) -> [String] {
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
}
