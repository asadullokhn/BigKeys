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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeroHeader()

                    EngineStatusSection()

                    TryItCard(practiceText: $practiceText)

                    NavigationLink {
                        MyWordsView()
                    } label: {
                        MyWordsNavCard()
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 12) {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    step(1, "Open Settings")
                                    step(2, "General → Keyboard → Keyboards")
                                    step(3, "Add New Keyboard…")
                                    step(4, "Select Typikey")
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Use it")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    step(1, "Open any app with a text field (Notes, Messages)")
                                    step(2, "Tap the text field, then hold the globe key")
                                    step(3, "Select Typikey")
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            Text("Set up the keyboard")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                        .homeCardStyle()

                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("A word grid, like TouchChat: one tap inserts one whole word. Categories switch pages at the top.", systemImage: "square.grid.3x3")
                                Label("abc opens the letter keyboard — the fallback for words not in the grid, just like TouchChat's own.", systemImage: "keyboard")
                                Label("Slide your finger across the keys — nothing happens until you lift. The key under your finger lights up.", systemImage: "hand.draw")
                                Label("Accidental double-taps are ignored for half a second.", systemImage: "clock")
                            }
                            .padding(.top, 10)
                        } label: {
                            Text("How it types")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                        .homeCardStyle()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
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

/// Shared card chrome for the home screen: a rounded, softly shaded
/// surface on the system's secondary grouped background so it reads
/// correctly in both light and dark mode.
private extension View {
    func homeCardStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

/// App identity: the icon's 2x2 key-tile motif inline next to the name,
/// compact enough to sit at the top of the scroll view without pushing
/// the status card below the fold.
private struct HeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                KeyTileMotif()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Typikey")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("The big-word keyboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Label("Large targets, built for people with limited fine motor control.", systemImage: "hand.point.up.braille")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

/// The app icon's 2x2 rounded-tile grid, recreated inline with the exact
/// Fitzgerald colors the keyboard's word-class palette uses (see
/// `WordClass.color` in KeyboardViewController.swift): pronoun yellow,
/// verb green, descriptor blue, noun orange.
private struct KeyTileMotif: View {
    private let yellow = Color(red: 1.00, green: 0.92, blue: 0.55)
    private let green = Color(red: 0.72, green: 0.90, blue: 0.63)
    private let blue = Color(red: 0.65, green: 0.82, blue: 0.98)
    private let orange = Color(red: 1.00, green: 0.80, blue: 0.58)

    var body: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            GridRow {
                tile(yellow)
                tile(green)
            }
            GridRow {
                tile(blue)
                tile(orange)
            }
        }
    }

    private func tile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
    }
}

private struct TryItCard: View {
    @Binding var practiceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it here")
                .font(.headline)
            TextField("Tap here, hold the globe key, choose Typikey", text: $practiceText, axis: .vertical)
                .font(.title3)
                .lineLimit(4...8)
                .frame(minHeight: 120, alignment: .topLeading)
        }
        .homeCardStyle()
    }
}

private struct MyWordsNavCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("My Words & Phrases")
                    .font(.title3.weight(.semibold))
                Text("Add your own keys to the keyboard's Mine page")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .homeCardStyle()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Tremor-friendly "My Words" editor (Gilbert build, task G2). Reads and
/// writes the same shared-suite keys the keyboard extension owns
/// (`myWords`, `captureCounts` — see Task G1): the app always has access
/// to the app group, unlike the keyboard, which gates on Full Access.
/// The keyboard picks up edits here on its next `viewWillAppear`.
struct MyWordsView: View {
    private let store: UserDefaults =
        UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") ?? .standard

    @State private var myWords: [String] = []
    @State private var captureCounts: [String: Int] = [:]
    @State private var armedWord: String?
    @State private var newWord = ""

    private var captureCandidates: [(word: String, count: Int)] {
        captureCounts
            .filter { $0.value >= 3 }
            .filter { candidate in !myWords.contains { $0.caseInsensitiveCompare(candidate.key) == .orderedSame } }
            .map { (word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        List {
            if !captureCandidates.isEmpty {
                Section("Words you type a lot") {
                    ForEach(captureCandidates, id: \.word) { candidate in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(candidate.word)
                                .font(.title2)
                            Text("typed \(candidate.count) times")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button {
                                    addCapturedWord(candidate.word)
                                } label: {
                                    Text("Add")
                                        .font(.title3.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    skipCapturedWord(candidate.word)
                                } label: {
                                    Text("Skip")
                                        .font(.title3.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section("My words and phrases") {
                if myWords.isEmpty {
                    Text("Words you add appear here, and on the keyboard's Mine page.")
                        .foregroundStyle(.secondary)
                }
                ForEach(myWords, id: \.self) { word in
                    HStack {
                        Text(word)
                            .font(.title3)
                            .accessibilityIdentifier(word)
                        Spacer()
                        Button {
                            removeWord(word)
                        } label: {
                            Text(armedWord == word ? "Tap again" : "Remove")
                                .font(.headline)
                                .frame(minWidth: 130, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(armedWord == word ? .red : nil)
                    }
                    .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Add a word or phrase…", text: $newWord)
                        .font(.title2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("myWordsField")
                    Button {
                        addManualWord()
                    } label: {
                        Text("Add")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("myWordsAdd")
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("My Words")
        .onAppear(perform: reload)
    }

    private func reload() {
        myWords = freshMyWords()
        captureCounts = freshCaptureCounts()
    }

    /// Reads myWords straight from the shared suite — never from @State —
    /// so a caller about to mutate and write back never clobbers a write
    /// the keyboard extension made in between this screen's last reload
    /// and now.
    private func freshMyWords() -> [String] {
        (store.array(forKey: "myWords") as? [String]) ?? []
    }

    private func freshCaptureCounts() -> [String: Int] {
        (store.dictionary(forKey: "captureCounts") as? [String: Int]) ?? [:]
    }

    private func addCapturedWord(_ word: String) {
        var words = freshMyWords()
        if !words.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
            words.append(word)
            store.set(words, forKey: "myWords")
        }
        myWords = words

        var counts = freshCaptureCounts()
        counts.removeValue(forKey: word)
        store.set(counts, forKey: "captureCounts")
        captureCounts = counts
    }

    private func skipCapturedWord(_ word: String) {
        var counts = freshCaptureCounts()
        counts.removeValue(forKey: word)
        store.set(counts, forKey: "captureCounts")
        captureCounts = counts
    }

    private func removeWord(_ word: String) {
        if armedWord == word {
            var words = freshMyWords()
            words.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
            store.set(words, forKey: "myWords")
            myWords = words
            armedWord = nil
        } else {
            armedWord = word
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if armedWord == word { armedWord = nil }
            }
        }
    }

    private func addManualWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var words = freshMyWords()
        guard !words.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            myWords = words
            newWord = ""
            return
        }
        words.append(trimmed)
        store.set(words, forKey: "myWords")
        myWords = words
        newWord = ""
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Phrase completion")
                .font(.headline)
            Label(status, systemImage: statusSymbol)
            if let probeResult {
                Label(probeResult, systemImage: "stopwatch")
            }
            Button(probing ? "Generating…" : "Test generation") { runProbe() }
                .disabled(probing || statusSymbol != "checkmark.circle")
        }
        .homeCardStyle()
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
