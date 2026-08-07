import SwiftUI

/// The two switches a person may need before a conversation: whether
/// Typikey remembers it, and whether verb keys reshape themselves.
///
/// Kept on the home screen rather than buried in Diagnostics, because it is
/// something a person reaches for *before* a private conversation, not
/// something they troubleshoot afterwards. The copy says exactly what stops
/// and what does not, since a privacy control nobody understands is worse
/// than none at all.
struct PrivateModeCard: View {
    @State private var isOn = Preferences.privateMode
    @State private var grammarOn = Preferences.smartGrammar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private mode")
                        .font(.title3.weight(.semibold))
                    Text(isOn ? "Nothing is being remembered" : "Typikey is learning as you type")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("privateModeToggle")
            .onChange(of: isOn) { _, newValue in
                Preferences.privateMode = newValue
            }

            Text("The keyboard works exactly the same — every word, every suggestion it already knows. What stops is the remembering: no new words are learned, nothing is counted, no names are picked up, and nothing new reaches My Words. The keyboard turns purple so you can see at a glance that this is on.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Toggle(isOn: $grammarOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verb keys follow the sentence")
                        .font(.title3.weight(.semibold))
                    Text(grammarOn ? "After “I am”, go reads going" : "Verb keys always read go, eat, watch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("smartGrammarToggle")
            .onChange(of: grammarOn) { _, newValue in
                Preferences.smartGrammar = newValue
            }

            Text("Keys never move — only the word on them changes. Every AAC app with this feature also lets you switch it off, because for some people the changing labels are more distracting than helpful. Turn it off and the keys stay in their plain form.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .homeCardStyle()
        .onAppear {
            isOn = Preferences.privateMode
            grammarOn = Preferences.smartGrammar
        }
    }
}
