import SwiftUI

@main
struct TypikeyApp: App {
    var body: some Scene {
        WindowGroup {
            SetupView()
        }
    }
}

struct SetupView: View {
    @State private var practiceText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Typikey is a keyboard with large targets, built for people with limited fine motor control.", systemImage: "keyboard")
                        .font(.title3)
                        .padding(.vertical, 8)
                }
                Section("Try it here") {
                    TextField("Tap here, hold the globe key, choose Typikey", text: $practiceText, axis: .vertical)
                        .font(.title2)
                        .lineLimit(3...6)
                }
                Section("Enable the keyboard") {
                    step(1, "Open Settings")
                    step(2, "General → Keyboard → Keyboards")
                    step(3, "Add New Keyboard…")
                    step(4, "Select Typikey")
                }
                Section("Use it") {
                    step(1, "Open any app with a text field (Notes, Messages)")
                    step(2, "Tap the text field, then hold the globe key")
                    step(3, "Select Typikey")
                }
                Section("How it types") {
                    Label("A word grid, like TouchChat: one tap inserts one whole word. Categories switch pages at the top.", systemImage: "square.grid.3x3")
                    Label("abc opens the letter keyboard — the fallback for words not in the grid, just like TouchChat's own.", systemImage: "keyboard")
                    Label("Slide your finger across the keys — nothing happens until you lift. The key under your finger lights up.", systemImage: "hand.draw")
                    Label("Accidental double-taps are ignored for half a second.", systemImage: "clock")
                }
            }
            .navigationTitle("Typikey")
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }
}
