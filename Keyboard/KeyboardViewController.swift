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
// 4. Stable targets: prediction lives in the suggestion bar, and language
//    switching relabels cells in place — grid positions never move,
//    because motor planning depends on stable positions.
// Word-class colors follow the Fitzgerald key convention AAC systems use.

// MARK: - Language

enum Lang: String {
    case en, ms // English, Malay (Bahasa Melayu) — Singapore's context

    var spellCheckCode: String {
        switch self {
        case .en: return "en_US"
        case .ms: return "ms_MY"
        }
    }
}

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

// A cell is one concept with one grid position; language only changes its
// label. Malay translations are drafts — verify with Fadillah before
// putting this in front of Sayfullah.
private struct VocabWord {
    let en: String
    let ms: String
    let emoji: String?
    let wordClass: WordClass

    init(_ en: String, ms: String? = nil, emoji: String? = nil, _ wordClass: WordClass) {
        self.en = en
        self.ms = ms ?? en
        self.emoji = emoji
        self.wordClass = wordClass
    }

    func text(_ lang: Lang) -> String {
        lang == .ms ? ms : en
    }
}

private struct Category {
    let en: String
    let ms: String
    let words: [VocabWord]

    func name(_ lang: Lang) -> String {
        lang == .ms ? ms : en
    }
}

private let vocabulary: [Category] = [
    Category(en: "Core", ms: "Teras", words: [
        VocabWord("I", ms: "saya", .pronoun), VocabWord("you", ms: "awak", .pronoun),
        VocabWord("want", ms: "mahu", .verb), VocabWord("like", ms: "suka", .verb),
        VocabWord("go", ms: "pergi", .verb), VocabWord("help", ms: "tolong", emoji: "🤝", .verb),
        VocabWord("more", ms: "lagi", .descriptor), VocabWord("stop", ms: "berhenti", emoji: "✋", .verb),
        VocabWord("yes", ms: "ya", emoji: "✅", .social), VocabWord("no", ms: "tidak", emoji: "❌", .social),
        VocabWord("not", ms: "bukan", .descriptor), VocabWord("this", ms: "ini", .pronoun),
        VocabWord("that", ms: "itu", .pronoun), VocabWord("good", ms: "bagus", emoji: "👍", .descriptor),
        VocabWord("bad", ms: "teruk", emoji: "👎", .descriptor), VocabWord("now", ms: "sekarang", .descriptor),
        VocabWord("later", ms: "nanti", .descriptor), VocabWord("what", ms: "apa", .question),
        VocabWord("where", ms: "di mana", .question), VocabWord("when", ms: "bila", .question),
        VocabWord("who", ms: "siapa", .question), VocabWord("can", ms: "boleh", .verb),
        VocabWord(".", .punct), VocabWord("?", .punct),
    ]),
    Category(en: "People", ms: "Orang", words: [
        VocabWord("I", ms: "saya", .pronoun), VocabWord("you", ms: "awak", .pronoun),
        VocabWord("Mum", ms: "Ibu", emoji: "👩", .noun), VocabWord("Dad", ms: "Ayah", emoji: "👨", .noun),
        VocabWord("brother", ms: "abang", emoji: "👦", .noun), VocabWord("sister", ms: "kakak", emoji: "👧", .noun),
        VocabWord("friend", ms: "kawan", emoji: "🧑‍🤝‍🧑", .noun), VocabWord("teacher", ms: "cikgu", emoji: "🧑‍🏫", .noun),
        VocabWord("doctor", ms: "doktor", emoji: "🧑‍⚕️", .noun), VocabWord("everyone", ms: "semua", emoji: "👥", .noun),
        VocabWord("we", ms: "kami", .pronoun), VocabWord("they", ms: "mereka", .pronoun),
    ]),
    Category(en: "Actions", ms: "Tindakan", words: [
        VocabWord("eat", ms: "makan", emoji: "🍽️", .verb), VocabWord("drink", ms: "minum", emoji: "🥤", .verb),
        VocabWord("play", ms: "main", emoji: "🎮", .verb), VocabWord("watch", ms: "tonton", emoji: "📺", .verb),
        VocabWord("draw", ms: "lukis", emoji: "🎨", .verb), VocabWord("read", ms: "baca", emoji: "📖", .verb),
        VocabWord("write", ms: "tulis", emoji: "✍️", .verb), VocabWord("make", ms: "buat", emoji: "🛠️", .verb),
        VocabWord("open", ms: "buka", .verb), VocabWord("close", ms: "tutup", .verb),
        VocabWord("give", ms: "beri", .verb), VocabWord("get", ms: "dapat", .verb),
        VocabWord("come", ms: "datang", .verb), VocabWord("look", ms: "tengok", emoji: "👀", .verb),
        VocabWord("listen", ms: "dengar", emoji: "👂", .verb), VocabWord("wait", ms: "tunggu", emoji: "⏳", .verb),
    ]),
    Category(en: "Feelings", ms: "Perasaan", words: [
        VocabWord("happy", ms: "gembira", emoji: "😊", .descriptor), VocabWord("sad", ms: "sedih", emoji: "😢", .descriptor),
        VocabWord("angry", ms: "marah", emoji: "😠", .descriptor), VocabWord("tired", ms: "penat", emoji: "😴", .descriptor),
        VocabWord("excited", ms: "teruja", emoji: "🤩", .descriptor), VocabWord("scared", ms: "takut", emoji: "😨", .descriptor),
        VocabWord("bored", ms: "bosan", emoji: "🥱", .descriptor), VocabWord("sick", ms: "sakit", emoji: "🤒", .descriptor),
        VocabWord("hungry", ms: "lapar", emoji: "😋", .descriptor), VocabWord("thirsty", ms: "haus", emoji: "🥵", .descriptor),
        VocabWord("okay", ms: "okay", emoji: "🙆", .descriptor), VocabWord("great", ms: "hebat", emoji: "🌟", .descriptor),
    ]),
    Category(en: "Food", ms: "Makanan", words: [
        VocabWord("water", ms: "air", emoji: "💧", .noun), VocabWord("rice", ms: "nasi", emoji: "🍚", .noun),
        VocabWord("chicken", ms: "ayam", emoji: "🍗", .noun), VocabWord("noodles", ms: "mi", emoji: "🍜", .noun),
        VocabWord("bread", ms: "roti", emoji: "🍞", .noun), VocabWord("fruit", ms: "buah", emoji: "🍎", .noun),
        VocabWord("banana", ms: "pisang", emoji: "🍌", .noun), VocabWord("juice", ms: "jus", emoji: "🧃", .noun),
        VocabWord("milk", ms: "susu", emoji: "🥛", .noun), VocabWord("tea", ms: "teh", emoji: "🍵", .noun),
        VocabWord("biryani", ms: "briyani", emoji: "🍛", .noun), VocabWord("chocolate", ms: "coklat", emoji: "🍫", .noun),
    ]),
    Category(en: "Places", ms: "Tempat", words: [
        VocabWord("home", ms: "rumah", emoji: "🏠", .noun), VocabWord("school", ms: "sekolah", emoji: "🏫", .noun),
        VocabWord("outside", ms: "luar", emoji: "🌳", .noun), VocabWord("shop", ms: "kedai", emoji: "🛒", .noun),
        VocabWord("park", ms: "taman", emoji: "🏞️", .noun), VocabWord("bus", ms: "bas", emoji: "🚌", .noun),
        VocabWord("MRT", emoji: "🚇", .noun), VocabWord("restaurant", ms: "restoran", emoji: "🍔", .noun),
        VocabWord("hospital", emoji: "🏥", .noun), VocabWord("toilet", ms: "tandas", emoji: "🚻", .noun),
        VocabWord("here", ms: "sini", .descriptor), VocabWord("there", ms: "sana", .descriptor),
    ]),
    Category(en: "Art", ms: "Seni", words: [
        VocabWord("draw", ms: "lukis", emoji: "🎨", .verb), VocabWord("paint", ms: "cat", emoji: "🖌️", .verb),
        VocabWord("color", ms: "warna", emoji: "🌈", .noun), VocabWord("picture", ms: "gambar", emoji: "🖼️", .noun),
        VocabWord("comic", ms: "komik", emoji: "📚", .noun), VocabWord("monster", ms: "raksasa", emoji: "👾", .noun),
        VocabWord("idea", emoji: "💡", .noun), VocabWord("cool", ms: "menarik", emoji: "😎", .descriptor),
        VocabWord("funny", ms: "kelakar", emoji: "😂", .descriptor), VocabWord("new", ms: "baru", emoji: "✨", .descriptor),
        VocabWord("finished", ms: "siap", emoji: "🏁", .descriptor), VocabWord("show you", ms: "tunjuk", emoji: "👀", .social),
    ]),
    Category(en: "Chat", ms: "Sembang", words: [
        VocabWord("hello", ms: "hai", emoji: "👋", .social), VocabWord("bye", emoji: "👋", .social),
        VocabWord("please", ms: "tolong", emoji: "🙏", .social), VocabWord("thank you", ms: "terima kasih", emoji: "🙏", .social),
        VocabWord("sorry", ms: "maaf", .social), VocabWord("how are you", ms: "apa khabar", .social),
        VocabWord("I'm good", ms: "khabar baik", .social), VocabWord("wait a moment", ms: "tunggu sekejap", emoji: "⏳", .social),
        VocabWord("nice to meet you", ms: "selamat berkenalan", .social), VocabWord("see you later", ms: "jumpa lagi", .social),
        VocabWord("I use this to talk", ms: "Saya guna ini untuk bercakap", emoji: "💬", .social),
        VocabWord("haha", emoji: "😂", .social),
    ]),
]

/// Lookup by either language's text, so Recents keeps color and emoji
/// regardless of which language a word was used in.
private let vocabIndex: [String: VocabWord] = {
    var index: [String: VocabWord] = [:]
    for category in vocabulary {
        for word in category.words {
            if index[word.en] == nil { index[word.en] = word }
            if index[word.ms] == nil { index[word.ms] = word }
        }
    }
    return index
}()

/// Seed bigrams per language so prediction is useful before any learning.
private let seedBigrams: [Lang: [String: [String]]] = [
    .en: [
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
    ],
    .ms: [
        "": ["Saya", "awak", "hai"],
        "saya": ["mahu", "suka", "boleh"],
        "awak": ["boleh", "mahu", "okay"],
        "mahu": ["makan", "lagi", "itu"],
        "suka": ["ini", "itu"],
        "boleh": ["tolong", "pergi"],
        "pergi": ["rumah", "sekolah", "sekarang"],
        "tolong": ["saya"],
        "makan": ["nasi", "ayam", "sekarang"],
        "minum": ["air", "jus", "teh"],
        "lukis": ["raksasa", "gambar"],
        "terima": ["kasih"],
        "apa": ["khabar"],
        "tidak": ["mahu", "boleh"],
    ],
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
        case language
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

    /// Top of the drawn keyboard band inside the container. Non-zero only
    /// when the system hands us an oversized container.
    fileprivate var layoutYOffset: CGFloat = 0

    /// Paints only the actual keyboard band — the rest of an oversized
    /// container stays transparent instead of a white wall.
    private let boardBackground = UIView()
    private var isRotating = false
    private var pendingHeightFix = false

    private var keys: [Key] = []
    private var layer: Layer = .grid
    private var categoryIndex = 1 // Recents is 0; start on Core
    private var shifted = false
    private var lang: Lang = .en
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
        view.backgroundColor = .clear

        usageCounts = (UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int]) ?? [:]
        learnedBigrams = (UserDefaults.standard.dictionary(forKey: "bigrams") as? [String: Int]) ?? [:]
        if let saved = UserDefaults.standard.string(forKey: "lang"), let restored = Lang(rawValue: saved) {
            lang = restored
        }
        if UserDefaults.standard.object(forKey: "sizeIndex") != nil {
            sizeIndex = min(max(UserDefaults.standard.integer(forKey: "sizeIndex"), 0), sizePresets.count - 1)
        }

        heightConstraint = NSLayoutConstraint(
            item: view!, attribute: .height, relatedBy: .equal,
            toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: sizePresets[sizeIndex])
        // Required, not 999: with allowsSelfSizing the system sizes the
        // window from this constraint, and a sub-required priority gets
        // out-prioritized after rotation, leaving a stale oversized window.
        heightConstraint.priority = .required
        view.addConstraint(heightConstraint)
        // Make the system respect our height constraint for the keyboard
        // window itself — without this, rotation can leave the container
        // at a stale system-chosen height that our 999-priority loses to.
        inputView?.allowsSelfSizing = true

        trackingView.frame = view.bounds
        trackingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        trackingView.isMultipleTouchEnabled = false
        trackingView.controller = self
        view.addSubview(trackingView)

        boardBackground.backgroundColor = .systemBackground
        trackingView.addSubview(boardBackground)

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

        // Self-heal: if the container is still oversized once rotation has
        // settled, rebuild the height constraint from scratch — reasserting
        // the existing one is not always enough to shrink the window.
        let drift = view.bounds.height - sizePresets[sizeIndex]
        if !isRotating, !pendingHeightFix, drift > 1 {
            pendingHeightFix = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // A genuine value change — same-value updates are no-ops to
                // the layout engine and never shrink the stale window.
                self.heightConstraint.constant = self.sizePresets[self.sizeIndex] - 2
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.heightConstraint.constant = self.sizePresets[self.sizeIndex]
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.pendingHeightFix = false
            }
        }
    }

    // On rotation the system can hand the extension transient, oversized
    // bounds. Reassert our height across the transition so the keyboard
    // settles back to its preset instead of staying huge.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        isRotating = true
        coordinator.animate(alongsideTransition: { _ in
            self.heightConstraint.constant = self.sizePresets[self.sizeIndex]
            self.view.setNeedsLayout()
        }, completion: { _ in
            // Nudge the constant so the system re-reads the constraint —
            // reasserting the same value after rotation is silently ignored
            // when the container kept a stale height.
            self.heightConstraint.constant = self.sizePresets[self.sizeIndex] - 1
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.heightConstraint.constant = self.sizePresets[self.sizeIndex]
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.isRotating = false
            self.view.setNeedsLayout()
        })
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateSuggestions()
    }

    // MARK: Categories

    /// Tab 0 is Recents — computed from usage across both languages.
    private func allCategories() -> [(name: String, words: [VocabWord])] {
        let recents = usageCounts
            .sorted { $0.value > $1.value }
            .compactMap { vocabIndex[$0.key] }
        var seen = Set<String>()
        var unique: [VocabWord] = []
        for word in recents where !seen.contains(word.en) {
            seen.insert(word.en)
            unique.append(word)
            if unique.count == 12 { break }
        }
        let recentsName = lang == .ms ? "Terkini" : "Recents"
        return [(recentsName, unique)] + vocabulary.map { ($0.name(lang), $0.words) }
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
                    let text = word.text(lang)
                    return (word.wordClass == .punct ? KeyAction.punct(text) : KeyAction.word(text), text)
                })
            }
            if wordRows.isEmpty {
                let hint = lang == .ms
                    ? "Perkataan yang kerap digunakan akan muncul di sini"
                    : "Words you use often will appear here — tap to go to Core"
                wordRows.append([(.category(1), hint)])
            }
            // No space or character-delete here: words insert their own
            // spacing, and character-level fixing belongs to the letter
            // layer — fewer keys means bigger targets.
            wordRows.append([
                (.toLetters, "abc"),
                (.deleteWord, lang == .ms ? "⌫ kata" : "⌫ word"),
                (.ret, "return"), (.language, lang == .en ? "EN" : "MS"),
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
                    string: text, attributes: [
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
        // Never lay out against more height than the active preset — if the
        // container is transiently oversized (mid-rotation), keys would
        // otherwise scale up with it and stick that way.
        let fullBounds = trackingView.bounds
        var bounds = fullBounds
        bounds.size.height = min(bounds.height, sizePresets[sizeIndex])
        guard bounds.width > 0, !keys.isEmpty else { return }
        // Anchor the keyboard band to the BOTTOM of the container: when the
        // system hands us an oversized container after rotation, the gap
        // opens above the keys (where the app content is) instead of
        // leaving a dead band under them.
        let yOffset = fullBounds.height - bounds.height
        layoutYOffset = yOffset
        boardBackground.frame = CGRect(
            x: 0, y: yOffset, width: fullBounds.width, height: fullBounds.height - yOffset)
        let inset: CGFloat = 4

        let barWidth = bounds.width - inset * 2
        let slotWidth = barWidth / 3
        for (i, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(
                x: inset + CGFloat(i) * slotWidth + 3, y: yOffset + inset,
                width: slotWidth - 6, height: topBarHeight - inset * 2)
        }

        var keyIndex = 0
        var gridTop = yOffset + topBarHeight

        if layer == .grid {
            let tabs = topBarKeys()
            let tabHeight: CGFloat = 44
            let tabWidth = bounds.width / CGFloat(tabs.count)
            for i in 0..<tabs.count {
                keys[keyIndex].view.frame = CGRect(
                    x: CGFloat(i) * tabWidth + 2, y: yOffset + topBarHeight + 2,
                    width: tabWidth - 4, height: tabHeight - 4)
                keyIndex += 1
            }
            gridTop = yOffset + topBarHeight + tabHeight
        }

        let rowDefs = rows(for: layer)
        let rowHeight = (fullBounds.height - gridTop) / CGFloat(rowDefs.count)

        for (rowIdx, row) in rowDefs.enumerated() {
            let y = gridTop + CGFloat(rowIdx) * rowHeight
            let isBottomRow = rowIdx == rowDefs.count - 1
            let globeWidth: CGFloat = (isBottomRow && globeButton != nil) ? bounds.width / 9 : 0
            let available = bounds.width - globeWidth
            var x: CGFloat = 0

            for (colIdx, item) in row.enumerated() {
                var width = available / CGFloat(row.count)
                if isBottomRow && row.count > 1 && row.contains(where: { $0.0 == .space }) {
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
        guard point.y > layoutYOffset + topBarHeight else { return nil } // suggestion buttons handle themselves
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
        case .language:
            // Same positions, new labels — muscle memory survives the switch.
            lang = lang == .en ? .ms : .en
            UserDefaults.standard.set(lang.rawValue, forKey: "lang")
            buildKeys()
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
    /// per language. Predictions appear in the suggestion bar so grid
    /// positions stay stable.
    private func predictNextWords() -> [String] {
        let prev = atSentenceStart() ? "" : lastWord().lowercased()
        var scores: [String: Int] = [:]

        let prefix = "\(prev)|"
        for (key, count) in learnedBigrams where key.hasPrefix(prefix) {
            scores[String(key.dropFirst(prefix.count)), default: 0] += count * 10
        }
        for (i, word) in (seedBigrams[lang]?[prev] ?? []).enumerated() {
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
                    forPartialWordRange: range, in: word, language: lang.spellCheckCode) ?? []).prefix(3))
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

    // Let touches above the keyboard band fall through to the app instead
    // of being swallowed by a transparent, oversized container.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let controller, point.y < controller.layoutYOffset { return nil }
        return super.hitTest(point, with: event)
    }

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
