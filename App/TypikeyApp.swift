import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

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
                EngineStatusSection()
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

/// Live status of the on-device phrase-completion model, so the team can
/// see on any device whether chips will appear and how fast — the same
/// model and call the keyboard uses, run in the app process.
struct EngineStatusSection: View {
    @State private var status = "Checking…"
    @State private var statusSymbol = "hourglass"
    @State private var probeResult: String?
    @State private var probing = false

    var body: some View {
        Section("Phrase completion") {
            Label(status, systemImage: statusSymbol)
            if let probeResult {
                Label(probeResult, systemImage: "stopwatch")
            }
            Button(probing ? "Generating…" : "Test generation") { runProbe() }
                .disabled(probing || statusSymbol != "checkmark.circle")
        }
        .onAppear { checkAvailability() }
    }

    private func checkAvailability() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                status = "On-device model available"
                statusSymbol = "checkmark.circle"
            case .unavailable(let reason):
                status = "Model unavailable: \(String(describing: reason)). Check Settings → Apple Intelligence & Siri."
                statusSymbol = "exclamationmark.triangle"
            @unknown default:
                status = "Model availability unknown"
                statusSymbol = "questionmark.circle"
            }
        } else {
            status = "Needs iPadOS 26 — the keyboard falls back to word prediction"
            statusSymbol = "info.circle"
        }
#else
        status = "FoundationModels not in this SDK"
        statusSymbol = "info.circle"
#endif
    }

    private func runProbe() {
#if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return }
        probing = true
        probeResult = nil
        Task {
            let session = LanguageModelSession()
            do {
                let coldStart = Date()
                let cold = try await session.respond(
                    to: "Continue naturally with at most five words: I want to").content
                let coldMs = Int(Date().timeIntervalSince(coldStart) * 1000)
                let warmStart = Date()
                _ = try await session.respond(
                    to: "Continue naturally with at most five words: today we will").content
                let warmMs = Int(Date().timeIntervalSince(warmStart) * 1000)
                await MainActor.run {
                    probeResult = "cold \(coldMs) ms, warm \(warmMs) ms — \"\(cold.prefix(40))\""
                    probing = false
                }
            } catch {
                await MainActor.run {
                    probeResult = "Generation failed: \(error.localizedDescription)"
                    probing = false
                }
            }
        }
#endif
    }
}
