import SwiftUI
import Vision

/// A stand-in messaging conversation, so screen learning can be seen
/// working without starting a broadcast — the whole point being that this
/// screen is rendered to an image and pushed through the *same*
/// `ScreenWords` pipeline the broadcast extension uses. What you see
/// learned here is exactly what a real broadcast would learn from a real
/// chat, minus the recording.
///
/// It also answers the question the feature exists for: a reply needs
/// words no dictionary has — a friend's name, a place, a dish — and those
/// are the words the reader picks up.
struct ConversationDemoView: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: ScreenWords.suiteName) ?? .standard

    @State private var learned: [String] = []
    @State private var reply = ""
    @State private var didRead = false

    private let messages: [Message] = [
        Message("Ratna", "Hi! Are you free on Friday?", incoming: true),
        Message("Ratna", "We are going to Jurong Point for lunch", incoming: true),
        Message("Ratna", "Hafiz is coming too, and maybe Suria", incoming: true),
        Message("Ratna", "They have the satay place you liked", incoming: true),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("This is a pretend conversation. Tap Read this screen and Typikey will pick up the words a reply would need — the same way it does during a real screen-learning session, but with nothing recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                transcript
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground)))

                Button {
                    readScreen()
                } label: {
                    Label(didRead ? "Read it again" : "Read this screen", systemImage: "text.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("demoRead")

                if didRead {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(learned.isEmpty ? "Nothing was picked up." : "Typikey picked up these words")
                            .font(.headline)
                        if !learned.isEmpty {
                            Text(learned.joined(separator: " · "))
                                .font(.body)
                                .accessibilityIdentifier("demoLearnedWords")
                            Text("They are saved now. Type a reply below — or in any other app — and they will show up as suggestions. Names like Ratna and places like Jurong are exactly what no built-in dictionary has.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground)))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Write a reply")
                        .font(.headline)
                    TextField("Tap here, then switch to Typikey", text: $reply, axis: .vertical)
                        .font(.title3)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("demoReplyField")

                    // Mirrors what the keyboard offers at the letters level,
                    // shown here too so the effect is visible even before
                    // Full Access is granted (without it the keyboard cannot
                    // read the shared container at all).
                    if !suggestions.isEmpty {
                        Text("Typikey would suggest")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { word in
                                Text(word)
                                    .font(.headline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.accentColor.opacity(0.15)))
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground)))
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Practice conversation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The sender's name is on screen, as it is in any real chat —
            // and a name is precisely the kind of word the reader exists to
            // catch, since no built-in dictionary has one.
            Text(messages.first?.sender ?? "")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(messages) { message in
                HStack {
                    if !message.incoming { Spacer(minLength: 40) }
                    Text(message.text)
                        .font(.title3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(message.incoming ? Color(.systemGray5) : Color.accentColor.opacity(0.25)))
                    if message.incoming { Spacer(minLength: 40) }
                }
            }
        }
    }

    /// The last partial word, matched against what the reader learned.
    private var suggestions: [String] {
        let partial = reply.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        guard partial.count >= 2 else { return [] }
        let lower = partial.lowercased()
        let counts = (store.dictionary(forKey: ScreenWords.countsKey) as? [String: Int]) ?? [:]
        return counts.keys
            .filter { $0.hasPrefix(lower) && $0 != lower }
            .sorted()
            .prefix(3)
            .map { $0 }
    }

    /// Renders the transcript and runs the broadcast extension's exact OCR
    /// path over the image. Nothing is recorded and no broadcast starts —
    /// the pixels never leave this process.
    @MainActor private func readScreen() {
        let renderer = ImageRenderer(content:
            transcript
                .frame(width: 900)
                .padding(24)
                .background(Color.white)
        )
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return }

        let request = ScreenWords.makeRequest()
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        let words = ScreenWords.words(from: request)
        ScreenWords.merge(words, into: store)
        learned = words.sorted()
        didRead = true
    }
}

private struct Message: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
    let incoming: Bool

    init(_ sender: String, _ text: String, incoming: Bool) {
        self.sender = sender
        self.text = text
        self.incoming = incoming
    }
}
