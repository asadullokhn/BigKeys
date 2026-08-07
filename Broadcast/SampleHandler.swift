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
///
/// The OCR and tokenizing logic lives in `ScreenWords` so the container app
/// can exercise the identical path in its on-device self-test — everything
/// this file adds is ReplayKit frame delivery and throttling.
final class SampleHandler: RPBroadcastSampleHandler {

    private let suite = UserDefaults(suiteName: ScreenWords.suiteName)

    private let lock = NSLock()
    private var lastProcessedAt = Date.distantPast
    private var isProcessing = false

    /// Words present in the previously processed frame. A word only counts
    /// again once it has left the screen — staring at a static page for a
    /// minute must not inflate its words 30x.
    private var previousFrameWords: Set<String> = []

    private lazy var textRequest = ScreenWords.makeRequest()

    /// Records that a session started, so the app can distinguish "the
    /// broadcast never ran" from "it ran and found nothing worth keeping".
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        suite?.set(Date().timeIntervalSince1970, forKey: "screenSessionStart")
    }

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

    /// Merges NEW appearances (words not in the previous frame) into the
    /// shared store. Written through every processed frame — at most one
    /// write / 2 s — so a jetsam kill mid-session loses nothing.
    private func harvest() {
        let frameWords = ScreenWords.words(from: textRequest)
        let fresh = frameWords.subtracting(previousFrameWords)
        previousFrameWords = frameWords
        guard let suite else { return }
        suite.set(Date().timeIntervalSince1970, forKey: "screenLastFrame")
        ScreenWords.merge(fresh, into: suite)
    }
}
