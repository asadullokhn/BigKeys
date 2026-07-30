import UIKit

// MVP keyboard for limited fine motor control, modeled on the TouchChat
// interface the user already trusts: a color-coded word grid with category
// pages, where one tap inserts one whole word — the letter keyboard is only
// the fallback for words not in the grid (exactly TouchChat's own pattern).
//
// Access principles, each from the CH5 research:
// 1. Explore-then-commit: touching down costs nothing; sliding moves the
//    highlight; only lifting commits (VoiceOver keyboard pattern).
// 2. Double-tap guard: a repeat commit of the same key within 0.5s is
//    ignored (Game Accessibility Guidelines debounce recommendation).
// 3. No dead zones: every point of the surface belongs to a key, so
//    precision is never required — the nearest key wins.
// 4. Stable targets: prediction lives in the suggestion bar; grid cells
//    never reorder, because motor planning depends on stable positions.
// Word-class colors follow the Fitzgerald key convention AAC systems use.

// MARK: - Vocabulary

private enum WordClass {
    case pronoun, verb, descriptor, noun, social, question, punct

    var color: UIColor {
        switch self {
        case .pronoun:    return UIColor(red: 1.00, green: 0.92, blue: 0.55, alpha: 1) // yellow
        case .verb:       return UIColor(red: 0.72, green: 0.90, blue: 0.63, alpha: 1) // green
        case .descriptor: return UIColor(red: 0.65, green: 0.82, blue: 0.98, alpha: 1) // blue
        case .noun:       return UIColor(red: 1.00, green: 0.80, blue: 0.58, alpha: 1) // orange
        case .social:     return UIColor(red: 1.00, green: 0.75, blue: 0.85, alpha: 1) // pink
        case .question:   return UIColor(red: 0.85, green: 0.75, blue: 0.98, alpha: 1) // purple
        case .punct:      return UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1) // gray
        }
    }
}

private struct VocabWord {
    let text: String
    let emoji: String?
    let wordClass: WordClass

    init(_ text: String, _ emoji: String? = nil, _ wordClass: WordClass) {
        self.text = text
        self.emoji = emoji
        self.wordClass = wordClass
    }
}

private let vocabulary: [(name: String, words: [VocabWord])] = [
    ("Core", [
        VocabWord("I", nil, .pronoun), VocabWord("you", nil, .pronoun),
        VocabWord("want", nil, .verb), VocabWord("like", nil, .verb),
        VocabWord("go", nil, .verb), VocabWord("help", "🤝", .verb),
        VocabWord("more", nil, .descriptor), VocabWord("stop", "✋", .verb),
        VocabWord("yes", "✅", .social), VocabWord("no", "❌", .social),
        VocabWord("not", nil, .descriptor), VocabWord("this", nil, .pronoun),
        VocabWord("that", nil, .pronoun), VocabWord("good", "👍", .descriptor),
        VocabWord("bad", "👎", .descriptor), VocabWord("now", nil, .descriptor),
        VocabWord("later", nil, .descriptor), VocabWord("what", nil, .question),
        VocabWord("where", nil, .question), VocabWord("when", nil, .question),
        VocabWord("who", nil, .question), VocabWord("can", nil, .verb),
        VocabWord(".", nil, .punct), VocabWord("?", nil, .punct),
    ]),
    ("People", [
        VocabWord("I", nil, .pronoun), VocabWord("you", nil, .pronoun),
        VocabWord("Mum", "👩", .noun), VocabWord("Dad", "👨", .noun),
        VocabWord("brother", "👦", .noun), VocabWord("sister", "👧", .noun),
        VocabWord("friend", "🧑‍🤝‍🧑", .noun), VocabWord("teacher", "🧑‍🏫", .noun),
        VocabWord("doctor", "🧑‍⚕️", .noun), VocabWord("everyone", "👥", .noun),
        VocabWord("we", nil, .pronoun), VocabWord("they", nil, .pronoun),
    ]),
    ("Actions", [
        VocabWord("eat", "🍽️", .verb), VocabWord("drink", "🥤", .verb),
        VocabWord("play", "🎮", .verb), VocabWord("watch", "📺", .verb),
        VocabWord("draw", "🎨", .verb), VocabWord("read", "📖", .verb),
        VocabWord("write", "✍️", .verb), VocabWord("make", "🛠️", .verb),
        VocabWord("open", nil, .verb), VocabWord("close", nil, .verb),
        VocabWord("give", nil, .verb), VocabWord("get", nil, .verb),
        VocabWord("come", nil, .verb), VocabWord("look", "👀", .verb),
        VocabWord("listen", "👂", .verb), VocabWord("wait", "⏳", .verb),
    ]),
    ("Feelings", [
        VocabWord("happy", "😊", .descriptor), VocabWord("sad", "😢", .descriptor),
        VocabWord("angry", "😠", .descriptor), VocabWord("tired", "😴", .descriptor),
        VocabWord("excited", "🤩", .descriptor), VocabWord("scared", "😨", .descriptor),
        VocabWord("bored", "🥱", .descriptor), VocabWord("sick", "🤒", .descriptor),
        VocabWord("hungry", "😋", .descriptor), VocabWord("thirsty", "🥵", .descriptor),
        VocabWord("okay", "🙆", .descriptor), VocabWord("great", "🌟", .descriptor),
    ]),
    ("Food", [
        VocabWord("water", "💧", .noun), VocabWord("rice", "🍚", .noun),
        VocabWord("chicken", "🍗", .noun), VocabWord("noodles", "🍜", .noun),
        VocabWord("bread", "🍞", .noun), VocabWord("fruit", "🍎", .noun),
        VocabWord("banana", "🍌", .noun), VocabWord("juice", "🧃", .noun),
        VocabWord("milk", "🥛", .noun), VocabWord("tea", "🍵", .noun),
        VocabWord("biryani", "🍛", .noun), VocabWord("chocolate", "🍫", .noun),
    ]),
    ("Places", [
        VocabWord("home", "🏠", .noun), VocabWord("school", "🏫", .noun),
        VocabWord("outside", "🌳", .noun), VocabWord("shop", "🛒", .noun),
        VocabWord("park", "🏞️", .noun), VocabWord("bus", "🚌", .noun),
        VocabWord("MRT", "🚇", .noun), VocabWord("restaurant", "🍔", .noun),
        VocabWord("hospital", "🏥", .noun), VocabWord("toilet", "🚻", .noun),
        VocabWord("here", nil, .descriptor), VocabWord("there", nil, .descriptor),
    ]),
    ("Art", [
        VocabWord("draw", "🎨", .verb), VocabWord("paint", "🖌️", .verb),
        VocabWord("color", "🌈", .noun), VocabWord("picture", "🖼️", .noun),
        VocabWord("comic", "📚", .noun), VocabWord("monster", "👾", .noun),
        VocabWord("idea", "💡", .noun), VocabWord("cool", "😎", .descriptor),
        VocabWord("funny", "😂", .descriptor), VocabWord("new", "✨", .descriptor),
        VocabWord("finished", "🏁", .descriptor), VocabWord("show you", "👀", .social),
    ]),
    ("Chat", [
        VocabWord("hello", "👋", .social), VocabWord("bye", "👋", .social),
        VocabWord("please", "🙏", .social), VocabWord("thank you", "🙏", .social),
        VocabWord("sorry", nil, .social), VocabWord("how are you", nil, .social),
        VocabWord("I'm good", nil, .social), VocabWord("wait a moment", "⏳", .social),
        VocabWord("nice to meet you", nil, .social), VocabWord("see you later", nil, .social),
        VocabWord("I use this to talk", "💬", .social), VocabWord("haha", "😂", .social),
    ]),
]

/// Global lookup so Recents cells keep their color and emoji.
private let vocabIndex: [String: VocabWord] = {
    var index: [String: VocabWord] = [:]
    for category in vocabulary {
        for word in category.words where index[word.text] == nil {
            index[word.text] = word
        }
    }
    return index
}()

/// Seed bigrams so prediction is useful before any learning has happened.
private let seedBigrams: [String: [String]] = [
    "": ["I", "you", "hello"],
    "i": ["want", "like", "need"],
    "you": ["can", "want", "okay"],
    "want": ["more", "that", "food"],
    "like": ["this", "that", "it"],
    "can": ["you", "we", "help"],
    "go": ["home", "outside", "now"],
    "help": ["me", "please"],
    "more": ["please", "time"],
    "what": ["time", "happened"],
    "where": ["are", "is"],
    "not": ["good", "now", "yet"],
    "this": ["is", "one"],
    "that": ["is", "one"],
    "eat": ["rice", "chicken", "now"],
    "drink": ["water", "juice", "tea"],
    "draw": ["monster", "picture", "now"],
    "my": ["Mum", "friend", "idea"],
    "thank": ["you"],
    "how": ["are you"],
]

// MARK: - Controller

final class KeyboardViewController: UIInputViewController {

    private enum KeyAction: Equatable {
        case word(String)
        case punct(String)
        case category(Int)
        case char(String)
        case shift
        case delete
        case deleteWord
        case toLetters
        case toNumbers
        case toGrid
        case space
        case ret
        case size
        case dismiss
    }

    private struct Key {
        let action: KeyAction
        let label: String
        let view: UILabel
    }

    private enum Layer: Equatable { case grid, letters, numbers }

    // Three height presets, cycled by the ⤢ key like Apple's keyboard
    // minimize behavior. Layout is fully width-responsive on top: when the
    // system narrows us (floating, Split View, Slide Over, Stage Manager)
    // the grid drops to compact mode instead of breaking.
    private let sizePresets: [CGFloat] = [280, 360, 440]
    private var sizeIndex = 2
    private var heightConstraint: NSLayoutConstraint!
    private var lastCompact = false
    private let topBarHeight: CGFloat = 56
    private let debounceInterval: TimeInterval = 0.5

    private var isCompact: Bool {
        view.bounds.width > 0 && view.bounds.width < 500
    }

    private var keys: [Key] = []
    private var layer: Layer = .grid
    private var categoryIndex = 1 // Recents is 0; start on Core
    private var shifted = false
    private var lastCommit: (action: KeyAction, at: Date)?

    private let trackingView = TrackingView()
    private var suggestionButtons: [UIButton] = []
    private var globeButton: UIButton?
    private var highlightedIndex: Int?

    // Learned usage, persisted in the extension's own sandbox — no Full
    // Access, no shared containers, nothing leaves the keyboard.
    private var usageCounts: [String: Int] = [:]
    private var learnedBigrams: [String: Int] = [:]

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        usageCounts = (UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int]) ?? [:]
        learnedBigrams = (UserDefaults.standard.dictionary(forKey: "bigrams") as? [String: Int]) ?? [:]
        if UserDefaults.standard.object(forKey: "sizeIndex") != nil {
            sizeIndex = min(max(UserDefaults.standard.integer(forKey: "sizeIndex"), 0), sizePresets.count - 1)
        }

        heightConstraint = NSLayoutConstraint(
            item: view!, attribute: .height, relatedBy: .equal,
            toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: sizePresets[sizeIndex])
        heightConstraint.priority = .init(999)
        view.addConstraint(heightConstraint)

        trackingView.frame = view.bounds
        trackingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        trackingView.isMultipleTouchEnabled = false
        trackingView.controller = self
        view.addSubview(trackingView)

        buildSuggestionBar()
        buildKeys()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Rebuild when crossing the compact threshold — row chunking and
        // visible word count differ between wide and narrow layouts.
        if isCompact != lastCompact {
            lastCompact = isCompact
            buildKeys()
        }
        layoutKeys()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateSuggestions()
    }

    // MARK: Categories

    /// Tab 0 is Recents — computed from usage, falls back to a hint that
    /// it fills up as words get used.
    private func allCategories() -> [(name: String, words: [VocabWord])] {
        let recents = usageCounts
            .sorted { $0.value > $1.value }
            .prefix(12)
            .compactMap { vocabIndex[$0.key] }
        return [("Recents", Array(recents))] + vocabulary
    }

    // MARK: Rows

    private func rows(for layer: Layer) -> [[(KeyAction, String)]] {
        switch layer {
        case .grid:
            // Compact (floating / Split View) shows fewer, still-big cells
            // rather than shrinking all of them below usable target size.
            var words = allCategories()[categoryIndex].words
            let perRow = isCompact ? 4 : 6
            if isCompact { words = Array(words.prefix(12)) }
            var wordRows: [[(KeyAction, String)]] = []
            for chunk in stride(from: 0, to: words.count, by: perRow) {
                wordRows.append(words[chunk..<min(chunk + perRow, words.count)].map { word in
                    (word.wordClass == .punct ? KeyAction.punct(word.text) : KeyAction.word(word.text), word.text)
                })
            }
            if wordRows.isEmpty {
                wordRows.append([(.category(1), "Words you use often will appear here — tap to go to Core")])
            }
            wordRows.append([
                (.toLetters, "abc"), (.space, "space"),
                (.deleteWord, "⌫ word"), (.delete, "⌫"), (.ret, "return"),
                (.size, "⤢"), (.dismiss, "⌄"),
            ])
            return wordRows
        case .letters:
            return [
                "qwertyuiop".map { (KeyAction.char(String($0)), String($0)) },
                "asdfghjkl".map { (KeyAction.char(String($0)), String($0)) },
                [(.shift, "⇧")] + "zxcvbnm".map { (KeyAction.char(String($0)), String($0)) } + [(.delete, "⌫")],
                [(.toGrid, "⊞ words"), (.toNumbers, "123"), (.space, "space"), (.ret, "return"), (.dismiss, "⌄")],
            ]
        case .numbers:
            return [
                "1234567890".map { (KeyAction.char(String($0)), String($0)) },
                ["-", "/", ":", ";", "(", ")", "$", "&", "@"].map { (KeyAction.char($0), $0) },
                [".", ",", "?", "!", "'", "\""].map { (KeyAction.char($0), $0) } + [(.delete, "⌫")],
                [(.toGrid, "⊞ words"), (.toLetters, "abc"), (.space, "space"), (.ret, "return"), (.dismiss, "⌄")],
            ]
        }
    }

    private func topBarKeys() -> [(KeyAction, String)] {
        allCategories().enumerated().map { (KeyAction.category($0.offset), $0.element.name) }
    }

    // MARK: Building

    private func buildSuggestionBar() {
        for i in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.6
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 10
            button.tag = i
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            trackingView.addSubview(button)
            suggestionButtons.append(button)
        }
    }

    private func buildKeys() {
        keys.forEach { $0.view.removeFromSuperview() }
        keys = []
        globeButton?.removeFromSuperview()
        globeButton = nil

        var defs = rows(for: layer).flatMap { $0 }
        if layer == .grid {
            defs = topBarKeys() + defs
        }

        for (action, label) in defs {
            let keyLabel = UILabel()
            keyLabel.numberOfLines = 2
            keyLabel.textAlignment = .center
            keyLabel.adjustsFontSizeToFitWidth = true
            keyLabel.minimumScaleFactor = 0.5
            keyLabel.layer.cornerRadius = 10
            keyLabel.layer.masksToBounds = true
            keyLabel.isUserInteractionEnabled = false
            style(keyLabel, action: action, label: label, highlighted: false)
            trackingView.addSubview(keyLabel)
            keys.append(Key(action: action, label: label, view: keyLabel))
        }

        if needsInputModeSwitchKey {
            let globe = UIButton(type: .system)
            globe.setImage(UIImage(systemName: "globe"), for: .normal)
            globe.tintColor = .label
            globe.backgroundColor = .systemGray3
            globe.layer.cornerRadius = 10
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            trackingView.addSubview(globe)
            globeButton = globe
        }

        updateSuggestions()
        view.setNeedsLayout()
    }

    private func style(_ label: UILabel, action: KeyAction, label text: String, highlighted: Bool) {
        if highlighted {
            label.backgroundColor = .systemBlue
            label.textColor = .white
        } else if case .category(let i) = action {
            label.backgroundColor = i == categoryIndex ? .systemBlue : .systemGray4
            label.textColor = i == categoryIndex ? .white : .label
        } else if case .word(let w) = action, let word = vocabIndex[w] {
            label.backgroundColor = word.wordClass.color
            label.textColor = .black
        } else if case .punct = action {
            label.backgroundColor = WordClass.punct.color
            label.textColor = .black
        } else if case .char = action {
            label.backgroundColor = .systemGray5
            label.textColor = .label
        } else {
            label.backgroundColor = .systemGray3
            label.textColor = .label
        }

        switch action {
        case .word(let w):
            if let word = vocabIndex[w], let emoji = word.emoji {
                let content = NSMutableAttributedString(
                    string: emoji + "\n", attributes: [.font: UIFont.systemFont(ofSize: 26)])
                content.append(NSAttributedString(
                    string: word.text, attributes: [
                        .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                        .foregroundColor: highlighted ? UIColor.white : UIColor.black,
                    ]))
                label.attributedText = content
            } else {
                label.attributedText = nil
                label.font = .systemFont(ofSize: 20, weight: .semibold)
                label.text = text
            }
        case .punct:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 28, weight: .semibold)
            label.text = text
        case .category:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 17, weight: .semibold)
            label.text = text
        case .char:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 34, weight: .medium)
            label.text = layer == .letters && shifted ? text.uppercased() : text
        default:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 22, weight: .medium)
            label.text = text
        }
    }

    private func restyleAll() {
        for (i, key) in keys.enumerated() {
            style(key.view, action: key.action, label: key.label, highlighted: i == highlightedIndex)
        }
    }

    // MARK: Layout

    private func layoutKeys() {
        let bounds = trackingView.bounds
        guard bounds.width > 0, !keys.isEmpty else { return }
        let inset: CGFloat = 4

        let barWidth = bounds.width - inset * 2
        let slotWidth = barWidth / 3
        for (i, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(
                x: inset + CGFloat(i) * slotWidth + 3, y: inset,
                width: slotWidth - 6, height: topBarHeight - inset * 2)
        }

        var keyIndex = 0
        var gridTop = topBarHeight

        if layer == .grid {
            let tabs = topBarKeys()
            let tabHeight: CGFloat = 44
            let tabWidth = bounds.width / CGFloat(tabs.count)
            for i in 0..<tabs.count {
                keys[keyIndex].view.frame = CGRect(
                    x: CGFloat(i) * tabWidth + 2, y: topBarHeight + 2,
                    width: tabWidth - 4, height: tabHeight - 4)
                keyIndex += 1
            }
            gridTop = topBarHeight + tabHeight
        }

        let rowDefs = rows(for: layer)
        let rowHeight = (bounds.height - gridTop) / CGFloat(rowDefs.count)

        for (rowIdx, row) in rowDefs.enumerated() {
            let y = gridTop + CGFloat(rowIdx) * rowHeight
            let isBottomRow = rowIdx == rowDefs.count - 1
            let globeWidth: CGFloat = (isBottomRow && globeButton != nil) ? bounds.width / 9 : 0
            let available = bounds.width - globeWidth
            var x: CGFloat = 0

            for (colIdx, item) in row.enumerated() {
                var width = available / CGFloat(row.count)
                if isBottomRow && row.count > 1 {
                    let spaceShare: CGFloat = isCompact ? 0.25 : 0.4
                    let otherShare = (1 - spaceShare) / CGFloat(row.count - 1)
                    width = available * (item.0 == .space ? spaceShare : otherShare)
                }
                if isBottomRow && colIdx == 1 && globeButton != nil {
                    globeButton!.frame = CGRect(x: x + 3, y: y + 3, width: globeWidth - 6, height: rowHeight - 6)
                    x += globeWidth
                }
                keys[keyIndex].view.frame = CGRect(x: x + 3, y: y + 3, width: width - 6, height: rowHeight - 6)
                x += width
                keyIndex += 1
            }
        }
    }

    // MARK: Explore-then-commit (called by TrackingView)

    fileprivate func touchMoved(to point: CGPoint) {
        let index = keyIndex(at: point)
        guard index != highlightedIndex else { return }
        let old = highlightedIndex
        highlightedIndex = index
        if let old { style(keys[old].view, action: keys[old].action, label: keys[old].label, highlighted: false) }
        if let index { style(keys[index].view, action: keys[index].action, label: keys[index].label, highlighted: true) }
    }

    fileprivate func touchLifted(at point: CGPoint) {
        let index = keyIndex(at: point)
        highlightedIndex = nil
        restyleAll()
        guard let index else { return }
        commit(keys[index].action)
    }

    fileprivate func touchCancelled() {
        highlightedIndex = nil
        restyleAll()
    }

    /// No dead zones: any point below the suggestion bar maps to the
    /// nearest key by center distance.
    private func keyIndex(at point: CGPoint) -> Int? {
        guard point.y > topBarHeight else { return nil } // suggestion buttons handle themselves
        if let globe = globeButton, globe.frame.contains(point) { return nil }
        var best: (index: Int, distance: CGFloat)?
        for (i, key) in keys.enumerated() {
            if key.view.frame.contains(point) { return i }
            let c = CGPoint(x: key.view.frame.midX, y: key.view.frame.midY)
            let d = hypot(c.x - point.x, c.y - point.y)
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }

    // MARK: Committing

    private func commit(_ action: KeyAction) {
        // Double-tap guard; deletes are exempt — repeats are intentional.
        if action != .delete, action != .deleteWord,
           let last = lastCommit, last.action == action,
           Date().timeIntervalSince(last.at) < debounceInterval {
            return
        }
        lastCommit = (action, Date())

        switch action {
        case .word(let w):
            insertWord(w)
        case .punct(let p):
            insertPunctuation(p)
        case .category(let i):
            categoryIndex = i
            buildKeys()
        case .char(let c):
            textDocumentProxy.insertText(shifted ? c.uppercased() : c)
            if shifted { shifted = false; restyleAll() }
        case .shift:
            shifted.toggle()
            restyleAll()
        case .delete:
            textDocumentProxy.deleteBackward()
        case .deleteWord:
            deleteLastWord()
        case .toLetters:
            layer = .letters; buildKeys()
        case .toNumbers:
            layer = .numbers; buildKeys()
        case .toGrid:
            layer = .grid; buildKeys()
        case .space:
            textDocumentProxy.insertText(" ")
        case .ret:
            textDocumentProxy.insertText("\n")
        case .size:
            sizeIndex = (sizeIndex + 1) % sizePresets.count
            UserDefaults.standard.set(sizeIndex, forKey: "sizeIndex")
            heightConstraint.constant = sizePresets[sizeIndex]
        case .dismiss:
            dismissKeyboard()
        }
        updateSuggestions()
    }

    private func contextBefore() -> String {
        textDocumentProxy.documentContextBeforeInput ?? ""
    }

    /// True at the start of the document or after sentence-ending punctuation.
    private func atSentenceStart() -> Bool {
        let trimmed = contextBefore().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return ".!?".contains(last)
    }

    /// Last completed word before the cursor, for prediction and learning.
    private func lastWord() -> String {
        let context = contextBefore().trimmingCharacters(in: .whitespacesAndNewlines)
        let token = context.split(whereSeparator: { $0 == " " || $0 == "\n" }).last.map(String.init) ?? ""
        return token.trimmingCharacters(in: CharacterSet(charactersIn: ".!?,"))
    }

    /// One tap = one word. Handles spacing, sentence-start capitalization,
    /// and records usage so Recents and prediction improve over time.
    private func insertWord(_ word: String) {
        let previous = lastWord()

        var text = word
        if atSentenceStart(), let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }
        if let last = contextBefore().last, last != " ", last != "\n" {
            textDocumentProxy.insertText(" ")
        }
        textDocumentProxy.insertText(text + " ")

        usageCounts[word, default: 0] += 1
        UserDefaults.standard.set(usageCounts, forKey: "usage")
        if !previous.isEmpty {
            learnedBigrams["\(previous.lowercased())|\(word)", default: 0] += 1
            UserDefaults.standard.set(learnedBigrams, forKey: "bigrams")
        }
    }

    /// Punctuation attaches to the word before it: "hello ." → "hello. "
    private func insertPunctuation(_ p: String) {
        if contextBefore().last == " " {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(p + " ")
    }

    private func deleteLastWord() {
        var context = contextBefore()
        guard !context.isEmpty else { return }
        while let last = context.last, last == " " {
            textDocumentProxy.deleteBackward()
            context.removeLast()
        }
        while let last = context.last, last != " ", last != "\n" {
            textDocumentProxy.deleteBackward()
            context.removeLast()
        }
    }

    // MARK: Prediction (on-device only — no Full Access, no network)

    /// Grid mode: predict likely next words from learned bigrams, seeded
    /// with sensible defaults. Predictions appear in the suggestion bar so
    /// grid positions stay stable.
    private func predictNextWords() -> [String] {
        let prev = atSentenceStart() ? "" : lastWord().lowercased()
        var scores: [String: Int] = [:]

        let prefix = "\(prev)|"
        for (key, count) in learnedBigrams where key.hasPrefix(prefix) {
            scores[String(key.dropFirst(prefix.count)), default: 0] += count * 10
        }
        for (i, word) in (seedBigrams[prev] ?? []).enumerated() {
            scores[word, default: 0] += 3 - i
        }
        return scores.sorted { $0.value > $1.value }.prefix(3).map(\.key)
    }

    private func currentPartialWord() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        return context.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
    }

    private func updateSuggestions() {
        let titles: [String]
        if layer == .grid {
            titles = predictNextWords()
        } else {
            let word = currentPartialWord()
            if word.count >= 2 {
                let checker = UITextChecker()
                let range = NSRange(location: 0, length: word.utf16.count)
                titles = Array((checker.completions(
                    forPartialWordRange: range, in: word, language: "en_US") ?? []).prefix(3))
            } else {
                titles = []
            }
        }
        for (i, button) in suggestionButtons.enumerated() {
            if i < titles.count {
                button.setTitle(titles[i], for: .normal)
                button.isHidden = false
            } else {
                button.setTitle(nil, for: .normal)
                button.isHidden = true
            }
        }
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        if layer == .grid {
            insertWord(title)
        } else {
            let word = currentPartialWord()
            for _ in 0..<word.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(title + " ")
        }
        updateSuggestions()
    }
}

/// Routes raw touches to the controller so keys commit on lift-off
/// rather than touch-down.
private final class TrackingView: UIView {
    weak var controller: KeyboardViewController?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        controller?.touchMoved(to: touch.location(in: self))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        controller?.touchMoved(to: touch.location(in: self))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        controller?.touchLifted(at: touch.location(in: self))
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.touchCancelled()
    }
}
