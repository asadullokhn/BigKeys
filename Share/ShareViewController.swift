import UIKit
import UniformTypeIdentifiers
import Vision

/// "Share to Typikey": the sanctioned way to hand the keyboard some
/// context, and the one that costs no recording at all.
///
/// Select a message and share it, or share a screenshot of a conversation,
/// and the words land in the same store the broadcast extension writes to.
/// No red indicator, no permission prompt, no session to remember to stop —
/// and it works from any app, because the share sheet is Apple's own answer
/// to "let another app see this".
///
/// Honest about who this is for: it still costs several precise taps, so it
/// suits a caregiver loading vocabulary ahead of time better than it suits
/// the person whose taps we are trying to save. The zero-tap paths —
/// keyword capture, and learning from what he writes — remain the ones that
/// carry daily use.
final class ShareViewController: UIViewController {

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let doneButton = UIButton(configuration: .filled())
    private let spinner = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        Task { await handleInput() }
    }

    private func buildUI() {
        view.backgroundColor = .systemBackground

        titleLabel.text = "Reading…"
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.numberOfLines = 0

        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0

        doneButton.setTitle("Done", for: .normal)
        doneButton.isHidden = true
        doneButton.addAction(UIAction { [weak self] _ in self?.finish() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, spinner, doneButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        spinner.startAnimating()
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 56),
            doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
    }

    private func handleInput() async {
        var words: Set<String> = []
        for item in (extensionContext?.inputItems as? [NSExtensionItem]) ?? [] {
            for provider in item.attachments ?? [] {
                if let text = await load(String.self, from: provider, type: .plainText) {
                    words.formUnion(ScreenWords.tokens(in: text))
                } else if let url = await load(URL.self, from: provider, type: .url) {
                    // The address itself carries words worth having (a site
                    // name, an article slug); its contents are not fetched,
                    // because nothing here ever touches the network.
                    words.formUnion(ScreenWords.tokens(in: url.absoluteString.replacingOccurrences(
                        of: "[-_/.?=&]", with: " ", options: .regularExpression)))
                } else if let image = await load(UIImage.self, from: provider, type: .image) {
                    words.formUnion(readText(from: image))
                }
            }
        }
        present(words)
    }

    private func load<T>(_ type: T.Type, from provider: NSItemProvider, type utType: UTType) async -> T? {
        guard provider.hasItemConformingToTypeIdentifier(utType.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: utType.identifier) { value, _ in
                if let value = value as? T {
                    continuation.resume(returning: value)
                } else if T.self == UIImage.self, let url = value as? URL,
                          let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    continuation.resume(returning: image as? T)
                } else if T.self == String.self, let url = value as? URL {
                    continuation.resume(returning: url.absoluteString as? T)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// The same OCR path the broadcast extension and the app's reader test
    /// use, so a shared screenshot is read exactly as a live screen is.
    private func readText(from image: UIImage) -> Set<String> {
        guard let cgImage = image.cgImage else { return [] }
        let request = ScreenWords.makeRequest()
        // A still image is worth the accurate pass: there is no frame budget
        // here, unlike in the broadcast extension.
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        return ScreenWords.words(from: request)
    }

    private func present(_ words: Set<String>) {
        spinner.stopAnimating()
        spinner.isHidden = true
        doneButton.isHidden = false

        guard !words.isEmpty, let suite = UserDefaults(suiteName: ScreenWords.suiteName) else {
            titleLabel.text = "Nothing to learn"
            bodyLabel.text = "No readable words were found in what you shared."
            return
        }
        ScreenWords.merge(words, into: suite)
        titleLabel.text = "Learned \(words.count) words"
        bodyLabel.text = words.sorted().prefix(20).joined(separator: " · ")
            + "\n\nThey will show up as suggestions while typing. Names and places can be added to the board in Typikey → My Words."
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
