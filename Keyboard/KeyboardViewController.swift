import UIKit
import NaturalLanguage

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
        case .punct:      return Palette.paper
        }
    }
}

/// The keyboard's whole visual system, in one place.
///
/// The rule, learnable in one sentence: **light keys put words on the
/// screen; dark keys change the board or fix what you wrote.** Before this,
/// punctuation, letters, category tiles and the delete keys were four
/// different shades of gray — indistinguishable at a glance despite doing
/// completely different things. Now the shade IS the meaning.
///
/// Fixed (non-adaptive) colors on purpose: an AAC board must look identical
/// in every lighting mode, because the user navigates it by remembered
/// color and position, not by reading it fresh each time.
private enum Palette {
    /// Types a character — letters, numbers, punctuation. Word cells use
    /// their Fitzgerald class color instead, but sit in the same light
    /// family so "light = writes" holds for all of them.
    static let paper = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    /// Moves you somewhere: Home, Categories, abc/123, EN/MS, size, tiles.
    static let navigate = UIColor(red: 0.35, green: 0.43, blue: 0.54, alpha: 1)
    /// Fixes what you wrote: delete, word-delete, cursors, return, dismiss.
    static let edit = UIColor(red: 0.24, green: 0.27, blue: 0.32, alpha: 1)
    /// Clear all, once armed — the only irreversible key on the board.
    static let destructive = UIColor(red: 0.84, green: 0.24, blue: 0.24, alpha: 1)
    /// Ring drawn around the key under the finger. Explore-then-commit only
    /// works if "which key am I on" is unmistakable, so the highlight is a
    /// thick ring plus a shade shift rather than a color swap — the class
    /// color has to survive, since that is what the user is aiming by.
    static let focus = UIColor(red: 0.00, green: 0.42, blue: 0.90, alpha: 1)

    static let onLight = UIColor.black
    static let onDark = UIColor.white
}

private extension UIColor {
    /// Shifts a color toward black or white by `amount` (0-1). Used for the
    /// focus state: light keys deepen, dark keys lift, so every key visibly
    /// reacts no matter where it sits on the scale.
    func shifted(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let isDark = (0.299 * r + 0.587 * g + 0.114 * b) < 0.5
        let target: CGFloat = isDark ? 1 : 0
        return UIColor(
            red: r + (target - r) * amount,
            green: g + (target - g) * amount,
            blue: b + (target - b) * amount,
            alpha: a)
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
    // Browsing is its own vocabulary: the words that move you around a page
    // or a video are almost none of the words you use to talk to a person,
    // and typing them letter by letter is exactly the cost this keyboard
    // exists to remove.
    Category(en: "Web", ms: "Web", words: [
        VocabWord("search", ms: "cari", emoji: "🔍", .verb), VocabWord("open", ms: "buka", .verb),
        VocabWord("watch", ms: "tonton", emoji: "📺", .verb), VocabWord("play", ms: "main", emoji: "▶️", .verb),
        VocabWord("next", ms: "seterusnya", emoji: "⏭️", .descriptor), VocabWord("back", ms: "kembali", emoji: "◀️", .descriptor),
        VocabWord("video", ms: "video", emoji: "🎬", .noun), VocabWord("music", ms: "muzik", emoji: "🎵", .noun),
        VocabWord("news", ms: "berita", emoji: "📰", .noun), VocabWord("game", ms: "permainan", emoji: "🎮", .noun),
        VocabWord("YouTube", emoji: "▶️", .noun), VocabWord("Google", emoji: "🔎", .noun),
        VocabWord("link", ms: "pautan", emoji: "🔗", .noun), VocabWord("page", ms: "halaman", emoji: "📄", .noun),
        VocabWord("share", ms: "kongsi", emoji: "📤", .verb), VocabWord("download", ms: "muat turun", emoji: "⬇️", .verb),
        VocabWord("www.", .noun), VocabWord(".com", .noun),
        VocabWord("how to", ms: "bagaimana", .question), VocabWord("what is", ms: "apa itu", .question),
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
        case char(String)
        case shift
        case delete       // pinned: one character
        case deleteWord   // pinned
        case clearAll     // pinned, two-tap armed (Task 3)
        case cursorLeft   // pinned (Task 3)
        case cursorRight  // pinned (Task 3)
        case home         // pinned: back to the home board
        case toCategories
        case toWords(Int) // index into allCategories()
        case toLetters
        case toNumbers
        case space
        case ret
        case size
        case dismiss
        case language
    }

    private enum Level: Equatable {
        case home, categories, letters, numbers
        case words(Int) // index into allCategories()
    }

    private struct Key {
        let action: KeyAction
        let label: String
        let view: UILabel
        let row: Int
        let col: Int // 0...contentColumns+1
        let colSpan: Int
        let rowSpan: Int
    }

    // Three height presets, cycled by the ⤢ key like Apple's keyboard
    // minimize behavior. Layout is fully width-responsive on top: when the
    // system narrows us (floating, Split View, Slide Over, Stage Manager)
    // the grid drops to compact mode instead of breaking.
    // Same three-preset cycle on both device families; the phone numbers
    // are smaller because an iPad preset would swallow an iPhone screen.
    private var sizePresets: [CGFloat] {
        UIDevice.current.userInterfaceIdiom == .phone ? [260, 310, 360] : [280, 360, 440]
    }
    private var sizeIndex = 2
    private var heightConstraint: NSLayoutConstraint?
    private var healAttempts = 0
    private var lastCompact = false
    private let topBarHeight: CGFloat = 56
    private let debounceInterval: TimeInterval = 0.5

    // The system can grant the extension's window LESS height than we
    // request (iPadOS 26 reserves an input-assistant band above
    // third-party keyboards). heightDeficit accumulates the measured
    // shortfall so the REQUEST compensates for it; requestedHeight is
    // what we ask the constraint for everywhere we used to ask for the
    // raw preset. Capped at 160 so it can never runaway. The whole request
    // is additionally clamped to 60% of the screen so a preset tuned for
    // portrait can never bury the app in iPhone landscape.
    private var heightDeficit: CGFloat = 0
    private var requestedHeight: CGFloat {
        let screenHeight = (view.window?.screen ?? UIScreen.main).bounds.height
        return min(sizePresets[sizeIndex] + heightDeficit, screenHeight * 0.6)
    }

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
    private var contentRowCount = 4

    /// The form verb cells are currently showing, recomputed whenever the
    /// text around the cursor changes. Held rather than derived on the fly
    /// so a rebuild is only triggered when the form actually changes.
    private var verbForm: Grammar.VerbForm = .base

    /// Inflected label -> the vocabulary word it came from, so a relabelled
    /// key keeps its color and emoji, and usage is counted against the base
    /// word rather than scattering across "go", "going" and "goes".
    private var inflectionBase: [String: String] = [:]
    private var level: Level = .home
    private var clearArmedAt: Date?
    private var lastIntentSignature: String?

    // Compact (floating / Split View / Slide Over): word boards drop to 5
    // wide-enough columns showing the first 20 content cells; the typing
    // levels keep all 10 columns — a letter that isn't there at all is
    // worse than a narrower key. Pinned columns never move: layoutKeys()
    // sizes col 0 and the right pinned column from bounds.width alone
    // (bounds.width / 12), never from contentColumns, so their frames are
    // identical whether the content grid is 5 or 10 columns wide.
    private var contentColumns: Int {
        switch level {
        case .letters, .numbers: return 10
        default: return isCompact ? 5 : 10
        }
    }

    private var isWordLevel: Bool {
        switch level {
        case .home, .categories, .words: return true
        case .letters, .numbers: return false
        }
    }
    private var shifted = false
    private var lang: Lang = .en
    private var lastCommit: (action: KeyAction, at: Date)?

    // Haptics are a no-op on iPads (no Taptic Engine) — wired anyway so an
    // iPhone build gets them for free. The input click is the audible
    // press feedback and needs no Full Access.
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    private let trackingView = TrackingView()
    private var suggestionButtons: [UIButton] = []
    private var globeButton: UIButton?
    private var highlightedIndex: Int?

    // Learned usage, persisted in the extension's own sandbox — no Full
    // Access, no shared containers, nothing leaves the keyboard.
    private var usageCounts: [String: Int] = [:]
    private var learnedBigrams: [String: Int] = [:]

    // The user's own words (Task G1 capture). Loaded in viewDidLoad and
    // reloaded in viewWillAppear so app-side edits in My Words appear the
    // next time the keyboard shows.
    private var myWords: [String] = []

    // Words recently OCR'd off the user's screen by the broadcast
    // extension (screen learning). Read-only here; reaches this process
    // through the app group, so it is empty without Full Access — and the
    // keyboard must work identically either way (invariant 5). Context
    // decays: a session older than 30 minutes stops influencing anything.
    private var screenWords: [String: Int] = [:]

    // Accumulates the current letters-level word as it's typed one key at
    // a time; cleared on any terminator (space/return/punctuation/delete/
    // level change/field switch) so only real letter-by-letter typing is
    // ever counted — grid-cell word taps never touch this.
    private var typedToken = ""

    /// Built-in vocabulary text, lowercased, for a case-insensitive
    /// "already known" check when deciding whether a typed token is a
    /// capture candidate.
    private static let knownVocabWords: Set<String> = Set(vocabIndex.keys.map { $0.lowercased() })

    /// Persistence home. With Full Access granted, learning and settings
    /// live in the app group so the container app can read and (later)
    /// edit them; without it, everything stays in the extension's own
    /// sandbox exactly as before — the keyboard never REQUIRES the grant.
    private lazy var store: UserDefaults = {
        guard hasFullAccess,
              let shared = UserDefaults(suiteName: "group.com.asadullokh.ch5.typikey") else {
            return .standard
        }
        // One-time migration: adopt the sandbox learning the first time
        // the shared container becomes reachable, never overwriting data
        // that is already there.
        if shared.object(forKey: "usage") == nil,
           UserDefaults.standard.object(forKey: "usage") != nil {
            for key in ["usage", "bigrams", "lang", "sizeIndex"] {
                if let value = UserDefaults.standard.object(forKey: key) {
                    shared.set(value, forKey: key)
                }
            }
        }
        // Reaching this line proves Full Access is granted — the app has no
        // other way to know, so it reads this flag to tell the user whether
        // screen learning can actually reach the keyboard.
        shared.set(true, forKey: ScreenWords.keyboardAccessKey)
        return shared
    }()

    // Phrase completion (spec 2026-08-04). completionWords is the current
    // continuation; empty means none. Requests are issued only from the
    // trigger points (commit / textDidChange), never from inside
    // updateSuggestions — that would loop through onResult.
    private let completionEngine = CompletionEngine()
    private var completionWords: [String] = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        usageCounts = (store.dictionary(forKey: "usage") as? [String: Int]) ?? [:]
        learnedBigrams = (store.dictionary(forKey: "bigrams") as? [String: Int]) ?? [:]
        myWords = (store.array(forKey: "myWords") as? [String]) ?? []
        reloadScreenWords()
        if let saved = store.string(forKey: "lang"), let restored = Lang(rawValue: saved) {
            lang = restored
        }
        if store.object(forKey: "sizeIndex") != nil {
            sizeIndex = min(max(store.integer(forKey: "sizeIndex"), 0), sizePresets.count - 1)
        }

        // Height lives on OUR content view, never on the root view. The
        // system derives the window height from content fitting; a height
        // constraint on the root view fights the system's cached window
        // frame, and the loser gets re-cached — that feedback loop is what
        // made the keyboard grow on every open/close cycle.
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.isMultipleTouchEnabled = false
        trackingView.controller = self
        view.addSubview(trackingView)
        let height = trackingView.heightAnchor.constraint(equalToConstant: sizePresets[sizeIndex])
        NSLayoutConstraint.activate([
            trackingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trackingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
        heightConstraint = height

        boardBackground.backgroundColor = .systemBackground
        trackingView.addSubview(boardBackground)

        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        trackingView.addGestureRecognizer(hover)

        buildSuggestionBar()
        buildKeys()
    }

    // Pointer support (trackpad, Apple Pencil hover, AssistiveTouch
    // pointer devices): moves the same explore highlight touch does, but
    // never commits — lift/click still drives commit via touchLifted.
    @objc private func handleHover(_ g: UIHoverGestureRecognizer) {
        switch g.state {
        case .began, .changed:
            touchMoved(to: g.location(in: trackingView))
        case .ended, .cancelled, .failed:
            touchCancelled()
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload before buildKeys() below so app-side My Words edits and a
        // fresh field both show up on this appearance, and so a stale
        // in-progress token from a previous field never leaks into a new one.
        myWords = (store.array(forKey: "myWords") as? [String]) ?? []
        reloadScreenWords()
        typedToken = ""
        heightConstraint?.constant = requestedHeight
        let signature = "\(textDocumentProxy.keyboardType?.rawValue ?? -1)|\(textDocumentProxy.returnKeyType?.rawValue ?? -1)"
        // Unconditional and unconditionally FIRST: reads and clears any
        // pending restore on every single appearance, on every instance,
        // whether or not this instance's own lastIntentSignature already
        // matches. A note must never outlive the one appearance it was
        // written for — see consumePendingRestore.
        let restored = consumePendingRestore(matching: signature)
        if signature != lastIntentSignature {
            lastIntentSignature = signature
            if let restored {
                level = restored
            } else {
                applyIntentLevel()
            }
        } else if let restored {
            level = restored // surviving instance after a ⌄ dismiss+retap: harmless reassert
        }
        buildKeys() // also refreshes the Go label for the new field
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
        // Compares against requestedHeight (not the raw preset) so it
        // doesn't fight the undersize compensation below.
        let drift = trackingView.bounds.height - requestedHeight
        if !isRotating, !pendingHeightFix, drift > 1, healAttempts < 2, heightConstraint != nil {
            pendingHeightFix = true
            healAttempts += 1
            DispatchQueue.main.async { [weak self] in
                guard let self, let constraint = self.heightConstraint else { return }
                // A genuine value change — same-value updates are no-ops to
                // the layout engine and never shrink the stale window.
                constraint.constant = self.requestedHeight - 2
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                constraint.constant = self.requestedHeight
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.pendingHeightFix = false
            }
        }

        // Compensate: the system can hand the extension LESS height than
        // trackingView requests (iPadOS 26 reserves an input-assistant
        // band above third-party keyboards). Measure the shortfall
        // against the real container and bump the request by exactly
        // that much — guarded to escalate only when a NEW, larger
        // deficit is measured, so this can never compound into the
        // historic growth-loop bug documented at the top of this file.
        // The 160pt cap is applied BEFORE the comparison (not just to
        // the stored value) — otherwise, once heightDeficit is capped,
        // a stale/lagging view.bounds.height keeps reporting a raw
        // deficit above the (now-static) capped value forever, and this
        // block re-fires — and calls setNeedsLayout() — every single
        // layout pass indefinitely.
        // !isCompact: floating keyboard / Split View / Slide Over grants
        // are small BY DESIGN — that is not the input-assistant-band
        // shortfall this mechanism exists to compensate for. heightDeficit
        // never decays on its own, so measuring a compact-mode grant here
        // would let a float episode pin the deficit at the 160pt cap and
        // then inflate the docked, full-width keyboard afterward.
        // Pad-only: the reserved band this compensates for is an iPadOS 26
        // behavior. On a phone the only wide layout is landscape, where a
        // grant below the (screen-clamped) request is normal — learning it
        // as a deficit would leak extra height back into portrait.
        if !isRotating, !isCompact, UIDevice.current.userInterfaceIdiom == .pad,
           let constraint = heightConstraint, view.bounds.height > 0,
           view.bounds.height < constraint.constant - 1 {
            let deficit = min(constraint.constant - view.bounds.height, 160)
            if deficit > heightDeficit {
                heightDeficit = deficit
                constraint.constant = requestedHeight
                view.setNeedsLayout()
            }
        }
    }

    // On rotation the system can hand the extension transient, oversized
    // bounds. Reassert our height across the transition so the keyboard
    // settles back to its preset instead of staying huge.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        isRotating = true
        healAttempts = 0
        coordinator.animate(alongsideTransition: { _ in
            self.heightConstraint?.constant = self.requestedHeight
            self.view.setNeedsLayout()
        }, completion: { _ in
            self.heightConstraint?.constant = self.requestedHeight
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.isRotating = false
            self.view.setNeedsLayout()
        })
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // An external context refresh (e.g. first responder moving to a
        // different field without this instance's viewWillAppear firing)
        // can bridge a half-typed token across fields. Reset rather than
        // count — the same reset-don't-count policy as every other
        // ambiguous path below.
        typedToken = ""
        refreshVerbForms()
        updateSuggestions()
        requestPhraseCompletion()
    }

    /// Rebuilds only when the required verb form actually changed — a
    /// rebuild on every keystroke would fight the explore-then-commit
    /// slide, since rebuilding drops the highlight. `buildKeys` recomputes
    /// the form itself, so this only decides whether to call it.
    private func refreshVerbForms() {
        guard lang == .en, isWordLevel else { return }
        guard Grammar.verbForm(after: contextBefore()) != verbForm else { return }
        buildKeys()
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
        // Mine appends after the built-in categories — never reorders them
        // (invariant 1). Plain-text cells built on the fly; myWords are
        // never added to vocabIndex (that stays the built-in lookup only).
        let mineWords = myWords.map { VocabWord($0, .social) }
        // Auto-filing (Gilbert: the board should quietly configure itself,
        // but visibly, so nobody hunts for a word): a user's word that is
        // recognizably a person, place, or action ALSO appears at the end
        // of that category's page (invariant 1: new words go at the end),
        // in Mine's pink so it always reads as "his word". Everything
        // still lives in Mine regardless; ambiguous words stay Mine-only.
        var builtIn = vocabulary.map { (name: $0.name(lang), en: $0.en, words: $0.words) }
        for word in myWords {
            guard let target = autoCategory(for: word),
                  let i = builtIn.firstIndex(where: { $0.en == target }),
                  !builtIn[i].words.contains(where: { $0.en.caseInsensitiveCompare(word) == .orderedSame })
            else { continue }
            builtIn[i].words.append(VocabWord(word, .social))
        }
        return [(recentsName, unique)] + builtIn.map { ($0.name, $0.words) } + [("Mine", mineWords)]
    }

    /// On-device semantic filing for a user's word: personal names go to
    /// People, place names to Places, verbs to Actions. Single words only —
    /// phrases stay Mine-only. Cached: NLTagger per word per keystroke
    /// would be wasteful, and a word's reading never changes.
    private var autoFileCache: [String: String?] = [:]

    private func autoCategory(for word: String) -> String? {
        if let cached = autoFileCache[word] { return cached }
        let result = WordFiling.category(for: word)
        autoFileCache[word] = result
        return result
    }

    // MARK: Frame (spec: pinned columns identical on every level)

    private var leftColumn: [(KeyAction, String)] {
        [(.home, "Home"),
         (.clearAll, clearArmedAt == nil ? "Clear all" : "tap again"),
         (.deleteWord, lang == .ms ? "⌫ kata" : "⌫ word"),
         (.cursorLeft, "←")]
    }

    private var rightColumn: [(KeyAction, String)] {
        [(.delete, "⌫"),
         (.ret, goLabel()),
         (.cursorRight, "→"),
         (.dismiss, "⌄")]
    }

    /// allCategories() index of the Chat board (offset 1 for Recents).
    private var chatWordsIndex: Int {
        (vocabulary.firstIndex { $0.en == "Chat" } ?? 0) + 1
    }

    /// allCategories() index of the Web board (offset 1 for Recents).
    private var webWordsIndex: Int {
        (vocabulary.firstIndex { $0.en == "Web" } ?? 0) + 1
    }

    /// Spec: applied once when the keyboard attaches to a field; never
    /// switches mid-typing. Manual navigation always wins afterwards.
    ///
    /// Keyboard extensions have no field-identity API, so `viewWillAppear`
    /// only recomputes this mapping when the field's keyboardType/
    /// returnKeyType signature differs from the last one THIS INSTANCE
    /// saw (`lastIntentSignature`, plain in-memory — correct whenever the
    /// instance itself survives the reshow, e.g. ordinary backgrounding/
    /// foregrounding of a still-visible keyboard).
    ///
    /// Tapping the in-keyboard ⌄ key (`commit(.dismiss)`) can additionally
    /// tear down and recreate the whole controller instance before the
    /// field is retapped — instance survival across that specific
    /// dismiss+retap is NOT an API guarantee either way, so
    /// `commit(.dismiss)` also writes the current signature, level, and
    /// a timestamp to UserDefaults via `persistPendingRestore`.
    /// `viewWillAppear` calls `consumePendingRestore` UNCONDITIONALLY,
    /// once, at the very top of every appearance — on every instance,
    /// regardless of whether that instance's own `lastIntentSignature`
    /// already matches — and the note is always read and cleared
    /// together in that one call. It is applied only if the signature
    /// still matches and it is no older than `pendingRestoreTTL` (120s).
    /// That unconditional consume is what keeps the note from surviving
    /// past the single reshow it was written for: a note nobody follows
    /// up on (dismissed, never retapped) cannot linger to ambush some
    /// unrelated later field that happens to share the same signature —
    /// it is gone (read and cleared) the very next time ANY field
    /// attaches, matching or not.
    ///
    /// Known accepted miss: retapping a *different* field that happens
    /// to share the exact same signature within the TTL window of a
    /// dismiss inherits the dismissed field's level instead of getting a
    /// fresh mapping — there is no way to tell that case apart from a
    /// re-show of the same field.
    private func applyIntentLevel() {
        switch textDocumentProxy.keyboardType {
        case .numberPad?, .decimalPad?, .phonePad?:
            level = .numbers; return
        case .emailAddress?, .URL?:
            // An address is spelled, not chosen from a board.
            level = .letters; return
        case .webSearch?:
            // A search box wants whole words — "YouTube", "how to" — far
            // more than it wants letters, and letters are one tap away.
            level = .words(webWordsIndex); return
        case .asciiCapable?:
            level = .letters; return
        default:
            break
        }
        switch textDocumentProxy.returnKeyType {
        case .google?, .yahoo?: level = .words(webWordsIndex)
        case .search?: level = .words(webWordsIndex)
        case .send?: level = .words(chatWordsIndex)
        default: level = .home
        }
    }

    /// A restore only makes sense moments after a dismiss — past this
    /// age a note is more likely to ambush some unrelated later field
    /// than to reflect a genuine reshow, so consumePendingRestore treats
    /// it as absent (while still clearing it).
    private let pendingRestoreTTL: TimeInterval = 120

    /// Called right before `dismissKeyboard()` so the level survives even
    /// if dismissing tears down this controller instance.
    private func persistPendingRestore(signature: String, level: Level) {
        let defaults = UserDefaults.standard
        defaults.set(signature, forKey: "pendingRestoreSignature")
        defaults.set(Date().timeIntervalSince1970, forKey: "pendingRestoreTimestamp")
        switch level {
        case .home: defaults.set("home", forKey: "pendingRestoreLevel")
        case .categories: defaults.set("categories", forKey: "pendingRestoreLevel")
        case .letters: defaults.set("letters", forKey: "pendingRestoreLevel")
        case .numbers: defaults.set("numbers", forKey: "pendingRestoreLevel")
        case .words(let index):
            defaults.set("words", forKey: "pendingRestoreLevel")
            defaults.set(index, forKey: "pendingRestoreWordsIndex")
        }
    }

    /// Reads AND clears any pending restore from a prior dismiss —
    /// called unconditionally, once, at the top of every
    /// `viewWillAppear`, regardless of whether the caller's own
    /// `lastIntentSignature` already matches. That unconditional call is
    /// what guarantees a note never outlives the single appearance it
    /// was written for: it is gone after this one read, whether or not
    /// it matched. Returns the saved level only when the signature still
    /// matches and the note is fresh (see `pendingRestoreTTL`); returns
    /// nil (having still cleared it) otherwise.
    private func consumePendingRestore(matching signature: String) -> Level? {
        let defaults = UserDefaults.standard
        let pendingSignature = defaults.string(forKey: "pendingRestoreSignature")
        let pendingLevel = defaults.string(forKey: "pendingRestoreLevel")
        let pendingWordsIndex = defaults.integer(forKey: "pendingRestoreWordsIndex")
        let pendingTimestamp = defaults.object(forKey: "pendingRestoreTimestamp") as? TimeInterval
        defaults.removeObject(forKey: "pendingRestoreSignature")
        defaults.removeObject(forKey: "pendingRestoreLevel")
        defaults.removeObject(forKey: "pendingRestoreWordsIndex")
        defaults.removeObject(forKey: "pendingRestoreTimestamp")
        guard pendingSignature == signature,
              let pendingTimestamp, Date().timeIntervalSince1970 - pendingTimestamp <= pendingRestoreTTL
        else { return nil }
        switch pendingLevel {
        case "home": return .home
        case "categories": return .categories
        case "letters": return .letters
        case "numbers": return .numbers
        case "words": return .words(pendingWordsIndex)
        default: return nil
        }
    }

    /// Go key follows the field, like the system keyboard's return key.
    private func goLabel() -> String {
        switch textDocumentProxy.returnKeyType {
        case .search?, .google?, .yahoo?: return "Search"
        case .send?: return "Send"
        case .go?: return "Go"
        case .done?: return "Done"
        default: return "return"
        }
    }

    /// A content cell that can span multiple grid slots (e.g. a wide
    /// space bar, or a big 2x2 category tile). Default span is 1x1 — a
    /// normal single cell.
    private struct ContentCell {
        let action: KeyAction
        let label: String
        let colSpan: Int
        let rowSpan: Int

        init(_ action: KeyAction, _ label: String, colSpan: Int = 1, rowSpan: Int = 1) {
            self.action = action
            self.label = label
            self.colSpan = colSpan
            self.rowSpan = rowSpan
        }
    }

    /// Core + Chat fill the home board: 36 word cells + 4 nav cells = 4x10.
    private var homeWords: [VocabWord] {
        (vocabulary.first { $0.en == "Core" }?.words ?? []) +
        (vocabulary.first { $0.en == "Chat" }?.words ?? [])
    }

    private func wordCell(_ word: VocabWord) -> ContentCell {
        var text = word.text(lang)
        // Verb keys follow the sentence: after "I am", `go` reads `going`.
        // The cell does not move — this is the same relabel-in-place
        // mechanism as the language switch (invariants 1 and 7). English
        // only; Malay marks tense with particles, not inflection.
        if word.wordClass == .verb, lang == .en {
            let inflected = Grammar.inflect(text, as: verbForm)
            if inflected != text {
                inflectionBase[inflected] = text
                text = inflected
            }
        }
        return ContentCell(word.wordClass == .punct ? .punct(text) : .word(text), text)
    }

    private func contentRows(for level: Level) -> [[ContentCell?]] {
        let cols = contentColumns
        switch level {
        case .home:
            var cells: [ContentCell?] = [
                ContentCell(.toCategories, "Categories"),
                ContentCell(.toLetters, "abc"),
                ContentCell(.language, lang == .en ? "EN" : "MS"),
                ContentCell(.size, "⤢"),
            ]
            cells += homeWords.map { Optional(wordCell($0)) }
            return chunk(cells, into: cols, maxRows: wordBoardMaxRows)
        case .categories:
            if cols >= 10 {
                // Big targets suit the AAC use case: five tiles across,
                // each a 2x2 block. The number of bands follows the number
                // of categories, so adding one (Web, say) grows the board
                // downward instead of pushing Mine off the end — which is
                // what a fixed 10-slot tiling used to do.
                let categories = allCategories()
                let bands = max(2, Int(ceil(Double(categories.count) / 5.0)))
                var rows: [[ContentCell?]] = Array(
                    repeating: Array(repeating: nil, count: cols), count: bands * 2)
                for (i, category) in categories.enumerated() {
                    rows[(i / 5) * 2][(i % 5) * 2] = ContentCell(
                        .toWords(i), category.name, colSpan: 2, rowSpan: 2)
                }
                return rows
            } else if wordBoardMaxRows == 8 {
                // Phone: five tiles across in full-height bands, same rule.
                let categories = allCategories()
                let bands = max(2, Int(ceil(Double(categories.count) / 5.0)))
                var rows: [[ContentCell?]] = Array(
                    repeating: Array(repeating: nil, count: cols), count: bands * 4)
                for (i, category) in categories.enumerated() {
                    rows[(i / 5) * 4][i % 5] = ContentCell(.toWords(i), category.name, rowSpan: 4)
                }
                return rows
            } else {
                // iPad compact (floating / Split View): plain single cells.
                let categories = allCategories()
                let cells: [ContentCell?] = categories.enumerated().map { (i, category) in
                    ContentCell(.toWords(i), category.name)
                }
                return chunk(cells, into: cols)
            }
        case .words(let index):
            let categories = allCategories()
            let words = index < categories.count ? categories[index].words : []
            if words.isEmpty {
                // Mine's empty state isn't Recents' "used often" story —
                // same English hint in both languages (invariant 8: no new
                // Malay strings). Mine is always the last category
                // allCategories() appends, so that's the robust way to
                // detect it — never a name string match.
                let isMine = index == categories.count - 1
                let hint = isMine
                    ? "Add words in the Typikey app"
                    : (lang == .ms
                        ? "Perkataan yang kerap digunakan akan muncul di sini"
                        : "Words you use often will appear here")
                // Recents' hint jumps to Core (toWords(1)) since its text
                // points there; Mine's hint has nowhere in particular to
                // jump to, so it just backs out to the category picker.
                let hintAction: KeyAction = isMine ? .toCategories : .toWords(1)
                var rows: [[ContentCell?]] = Array(repeating: Array(repeating: nil, count: cols), count: 4)
                rows[0][0] = ContentCell(hintAction, hint, colSpan: cols)
                return rows
            }
            let cells: [ContentCell?] = words.map { Optional(wordCell($0)) }
            return chunk(cells, into: cols, maxRows: wordBoardMaxRows)
        case .letters:
            var rows: [[ContentCell?]] = [
                "qwertyuiop".map { Optional(ContentCell(.char(String($0)), String($0))) },
                "asdfghjkl".map { Optional(ContentCell(.char(String($0)), String($0))) } + [Optional(ContentCell(.shift, "⇧"))],
                "zxcvbnm".map { Optional(ContentCell(.char(String($0)), String($0))) }
                    + [Optional(ContentCell(.char(","), ",")), Optional(ContentCell(.char("."), ".")), Optional(ContentCell(.char("?"), "?"))],
                Array(repeating: nil, count: cols),
            ]
            rows[3][0] = ContentCell(.space, "space", colSpan: 8)
            rows[3][8] = ContentCell(.toNumbers, "123", colSpan: 2)
            return rows
        case .numbers:
            var rows: [[ContentCell?]] = [
                "1234567890".map { Optional(ContentCell(.char(String($0)), String($0))) },
                ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { Optional(ContentCell(.char($0), $0)) },
                [".", ",", "?", "!", "'"].map { Optional(ContentCell(.char($0), $0)) },
                Array(repeating: nil, count: cols),
            ]
            rows[2] += Array(repeating: nil, count: cols - rows[2].count)
            rows[3][0] = ContentCell(.space, "space", colSpan: 8)
            rows[3][8] = ContentCell(.toLetters, "abc", colSpan: 2)
            return rows
        }
    }

    /// Pack cells row-major into at least 4 and at most `maxRows` rows of
    /// `cols`, padding with nil. Word boards pass 8 on phones so ALL cells
    /// stay reachable in the 5-column grid — a phone is not an occasional
    /// squeeze like Split View, it's the whole device.
    private func chunk(_ cells: [ContentCell?], into cols: Int, maxRows: Int = 4) -> [[ContentCell?]] {
        var rows: [[ContentCell?]] = []
        for start in stride(from: 0, to: cells.count, by: cols) {
            rows.append(Array(cells[start..<min(start + cols, cells.count)]))
        }
        while rows.count < 4 { rows.append([]) }
        rows = Array(rows.prefix(maxRows))
        for i in rows.indices where rows[i].count < cols {
            rows[i] += Array(repeating: nil, count: cols - rows[i].count)
        }
        return rows
    }

    /// 8 content rows for word boards on a compact phone, 4 everywhere else.
    private var wordBoardMaxRows: Int {
        UIDevice.current.userInterfaceIdiom == .phone && isCompact ? 8 : 4
    }

    // MARK: Building

    private func buildSuggestionBar() {
        for i in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .systemFont(ofSize: 23, weight: .semibold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.65
            // Filled pill, not tinted text: a suggestion is a target to be
            // hit, so it has to look as tappable as a key.
            button.backgroundColor = Palette.paper
            button.setTitleColor(Palette.onLight, for: .normal)
            button.layer.cornerRadius = 14
            button.tag = i
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            trackingView.addSubview(button)
            suggestionButtons.append(button)
        }
    }

    private func buildKeys() {
        keys.forEach { $0.view.removeFromSuperview() }
        keys = []
        // A mid-slide rebuild (e.g. clear-all's relabel, a level switch)
        // can shrink the key count while a touch is still moving; a stale
        // highlightedIndex from the old, larger array would then index
        // out of bounds in the next touchMoved restyle.
        highlightedIndex = nil
        globeButton?.removeFromSuperview()
        globeButton = nil

        // Recomputed here, on every rebuild, so the board is right no
        // matter what caused it — a level change back from the letters
        // keyboard, a re-show, or the sentence simply moving on.
        verbForm = lang == .en ? Grammar.verbForm(after: contextBefore()) : .base
        inflectionBase.removeAll()

        let content = contentRows(for: level)
        contentRowCount = content.count

        // Pinned columns are ALWAYS 4 rows (invariant 9) even when the
        // content grid runs 8 rows on a phone — layoutKeys() gives the two
        // grids independent row heights.
        for row in 0..<4 {
            addKey(leftColumn[row], row: row, col: 0)
            addKey(rightColumn[row], row: row, col: contentColumns + 1)
        }
        for (row, cells) in content.enumerated() {
            for (i, cell) in cells.enumerated() {
                if let cell {
                    addKey((cell.action, cell.label), row: row, col: i + 1, colSpan: cell.colSpan, rowSpan: cell.rowSpan)
                }
            }
        }

        // The globe lives in the top suggestion bar (same slot on every
        // level and every device), never in the content grid — it used
        // to overwrite the last home cell ("haha"), silently dropping it.
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

    private func addKey(_ def: (KeyAction, String), row: Int, col: Int, colSpan: Int = 1, rowSpan: Int = 1) {
        let keyLabel = UILabel()
        keyLabel.numberOfLines = 2
        keyLabel.textAlignment = .center
        keyLabel.adjustsFontSizeToFitWidth = true
        // Was 0.5, which let "I use this to talk" shrink to roughly half the
        // size of "I" on the same board — the longest labels became the
        // hardest to read. Wrapping to a second line first keeps every key
        // within one comfortable size band.
        keyLabel.lineBreakMode = .byWordWrapping
        keyLabel.minimumScaleFactor = 0.7
        keyLabel.layer.cornerRadius = 14
        keyLabel.layer.masksToBounds = true
        keyLabel.isUserInteractionEnabled = false
        style(keyLabel, action: def.0, label: def.1, highlighted: false)
        trackingView.addSubview(keyLabel)
        keys.append(Key(action: def.0, label: def.1, view: keyLabel, row: row, col: col, colSpan: colSpan, rowSpan: rowSpan))
    }

    /// Which of the three jobs a key does. The role decides its color, and
    /// the color is the only thing the user needs to read to know whether a
    /// key will write, travel, or undo.
    private enum KeyRole { case write, navigate, edit }

    private func role(of action: KeyAction) -> KeyRole {
        switch action {
        case .word, .punct, .char, .space:
            return .write
        case .home, .toCategories, .toWords, .toLetters, .toNumbers, .language, .size, .shift:
            return .navigate
        case .delete, .deleteWord, .clearAll, .cursorLeft, .cursorRight, .ret, .dismiss:
            return .edit
        }
    }

    private func style(_ label: UILabel, action: KeyAction, label text: String, highlighted: Bool) {
        var background: UIColor
        switch role(of: action) {
        case .write:
            if case .word(let w) = action, let word = vocabIndex[w] ?? vocabIndex[inflectionBase[w] ?? w] {
                background = word.wordClass.color
            } else if case .word = action {
                background = WordClass.social.color // a word of the user's own
            } else {
                background = Palette.paper
            }
        case .navigate:
            background = Palette.navigate
        case .edit:
            // Armed clear-all is the one irreversible key; it announces
            // itself in red rather than relying on the label change alone.
            background = (isClearAllArmed(action)) ? Palette.destructive : Palette.edit
        }

        let onDark = background == Palette.navigate || background == Palette.edit
            || background == Palette.destructive
        let foreground = onDark ? Palette.onDark : Palette.onLight
        label.backgroundColor = highlighted ? background.shifted(by: 0.22) : background
        label.textColor = foreground
        label.layer.borderWidth = highlighted ? 4 : 0
        label.layer.borderColor = highlighted ? Palette.focus.cgColor : nil

        switch action {
        case .word(let w):
            if let word = vocabIndex[w] ?? vocabIndex[inflectionBase[w] ?? w], let emoji = word.emoji {
                // The WORD is what gets typed, so it leads; the emoji is a
                // recognition cue above it, deliberately smaller. It used to
                // be the other way round, which made the label hard to read.
                let content = NSMutableAttributedString(
                    string: emoji + "\n", attributes: [.font: UIFont.systemFont(ofSize: 17)])
                content.append(NSAttributedString(
                    string: text, attributes: [
                        .font: UIFont.systemFont(ofSize: 19, weight: .semibold),
                        .foregroundColor: foreground,
                    ]))
                label.attributedText = content
            } else {
                label.attributedText = nil
                label.font = .systemFont(ofSize: 21, weight: .semibold)
                label.text = text
            }
        case .punct:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 30, weight: .semibold)
            label.text = text
        case .char:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 32, weight: .medium)
            label.text = level == .letters && shifted ? text.uppercased() : text
        case .home, .toCategories, .toWords, .toLetters, .toNumbers, .language, .size, .shift:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 18, weight: .semibold)
            label.text = text
        default:
            label.attributedText = nil
            label.font = .systemFont(ofSize: 19, weight: .medium)
            label.text = text
        }
    }

    private func isClearAllArmed(_ action: KeyAction) -> Bool {
        if case .clearAll = action { return clearArmedAt != nil }
        return false
    }

    private func restyleAll() {
        for (i, key) in keys.enumerated() {
            style(key.view, action: key.action, label: key.label, highlighted: i == highlightedIndex)
        }
    }

    // MARK: Layout

    private func layoutKeys() {
        let fullBounds = trackingView.bounds
        var bounds = fullBounds
        // viewDidLayoutSubviews compensates the height REQUEST when the
        // system grants less than we asked for; this clamp is only a
        // defensive floor for the transient frame before that lands, so
        // it targets the raw preset — not the (possibly inflated)
        // requested height — and converges to the designed size.
        bounds.size.height = min(bounds.height, min(view.bounds.height > 0 ? view.bounds.height : sizePresets[sizeIndex], sizePresets[sizeIndex]))
        guard bounds.width > 0, !keys.isEmpty else { return }
        let yOffset = fullBounds.height - bounds.height
        layoutYOffset = yOffset
        boardBackground.frame = CGRect(
            x: 0, y: yOffset, width: fullBounds.width, height: fullBounds.height - yOffset)
        let inset: CGFloat = 4

        // The globe gets a fixed square slot at the right end of the top
        // bar — same place on every level and device — instead of living
        // inside the content grid, where it used to silently overwrite
        // whatever cell was last in the bottom row.
        let globeWidth: CGFloat = globeButton != nil ? (topBarHeight - inset * 2) : 0
        let barWidth = bounds.width - inset * 2 - globeWidth
        let slotWidth = barWidth / 3
        for (i, button) in suggestionButtons.enumerated() {
            button.frame = CGRect(
                x: inset + CGFloat(i) * slotWidth + 3, y: yOffset + inset,
                width: slotWidth - 6, height: topBarHeight - inset * 2)
        }
        if let globe = globeButton {
            globe.frame = CGRect(
                x: bounds.width - inset - globeWidth, y: yOffset + inset,
                width: globeWidth, height: topBarHeight - inset * 2)
        }

        // Pinned columns are sized from bounds.width alone — never from
        // contentColumns — so col 0 and the right pinned column land on
        // the exact same frame whether the content grid is 5 columns
        // (compact) or 10 (full width/typing levels). pinnedW is
        // identical to the old uniform cell width (bounds.width / 12,
        // since there are always 2 pinned columns + up to 10 content
        // columns at full width); at contentColumns == 10 this makes
        // contentW == pinnedW == bounds.width / 12 too, so the geometry
        // below is numerically identical to the pre-fix single-cellW
        // math at full width — only compact mode's content columns
        // (still evenly split, just across 5 instead of 10) differ.
        let pinnedW = bounds.width / 12
        let contentW = (bounds.width - 2 * pinnedW) / CGFloat(contentColumns)
        let gridTop = yOffset + topBarHeight
        // Pinned columns always divide the band into 4 (invariant 9: their
        // frames never depend on the content grid); the content grid rows
        // can be 8 on a phone.
        let pinnedRowH = (fullBounds.height - gridTop) / 4
        let contentRowH = (fullBounds.height - gridTop) / CGFloat(max(contentRowCount, 4))
        // A transient sub-topBarHeight container (before the height
        // compensation above lands) would otherwise yield negative
        // frames here — bail rather than draw them.
        guard pinnedRowH > 0 else { return }

        for key in keys {
            let x: CGFloat
            let width: CGFloat
            let rowH: CGFloat
            if key.col == 0 {
                x = 0
                width = pinnedW
                rowH = pinnedRowH
            } else if key.col == contentColumns + 1 {
                x = bounds.width - pinnedW
                width = pinnedW
                rowH = pinnedRowH
            } else {
                x = pinnedW + CGFloat(key.col - 1) * contentW
                width = contentW * CGFloat(key.colSpan)
                rowH = contentRowH
            }
            key.view.frame = CGRect(
                x: x + 3,
                y: gridTop + CGFloat(key.row) * rowH + 3,
                width: width - 6, height: rowH * CGFloat(key.rowSpan) - 6)
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
    /// nearest key by center distance. The globe now lives in the top
    /// bar, so this guard already excludes it — no separate check needed.
    private func keyIndex(at point: CGPoint) -> Int? {
        guard point.y > layoutYOffset + topBarHeight else { return nil } // suggestion buttons handle themselves
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
        // Double-tap guard; delete, word-delete, clear-all, and the
        // cursor arrows are exempt — repeats are intentional for those.
        if !isDebounceExempt(action),
           let last = lastCommit, last.action == action,
           Date().timeIntervalSince(last.at) < debounceInterval {
            return
        }
        UIDevice.current.playInputClick()
        impactFeedback.impactOccurred()
        lastCommit = (action, Date())

        switch action {
        case .word(let w):
            insertWord(w)
        case .punct(let p):
            terminateToken()
            insertPunctuation(p)
        case .char(let c):
            // An apostrophe is token-internal (so "don't" accumulates as
            // one token) even though it isn't a letter — terminateToken's
            // ≥3 requirement below counts letters only, so it doesn't
            // inflate the count, but the stored/counted key keeps it.
            if let ch = c.first, c.count == 1, ch.isLetter || ch == "'" || ch == "\u{2019}" {
                typedToken += c.lowercased()
            } else {
                terminateToken()
            }
            textDocumentProxy.insertText(shifted ? c.uppercased() : c)
            if shifted { shifted = false; restyleAll() }
        case .shift:
            shifted.toggle()
            restyleAll()
        case .delete:
            // Deleting mid-word makes the accumulated token unreliable —
            // reset rather than count a partial/garbled word.
            typedToken = ""
            textDocumentProxy.deleteBackward()
        case .deleteWord:
            typedToken = ""
            deleteLastWord()
        case .home:
            typedToken = ""
            completionWords = []
            level = .home; buildKeys()
        case .toCategories:
            typedToken = ""
            completionWords = []
            level = .categories; buildKeys()
        case .toWords(let i):
            typedToken = ""
            completionWords = []
            level = .words(i); buildKeys()
        case .toLetters:
            typedToken = ""
            completionWords = []
            level = .letters; buildKeys()
        case .toNumbers:
            typedToken = ""
            completionWords = []
            level = .numbers; buildKeys()
        case .clearAll:
            typedToken = ""
            completionWords = []
            handleClearAll()
        case .cursorLeft:
            typedToken = ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        case .cursorRight:
            typedToken = ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        case .space:
            terminateToken()
            textDocumentProxy.insertText(" ")
        case .ret:
            terminateToken()
            textDocumentProxy.insertText("\n")
        case .size:
            sizeIndex = (sizeIndex + 1) % sizePresets.count
            store.set(sizeIndex, forKey: "sizeIndex")
            heightConstraint?.constant = requestedHeight
        case .dismiss:
            let signature = "\(textDocumentProxy.keyboardType?.rawValue ?? -1)|\(textDocumentProxy.returnKeyType?.rawValue ?? -1)"
            persistPendingRestore(signature: signature, level: level)
            dismissKeyboard()
        case .language:
            completionWords = []
            // Same positions, new labels — muscle memory survives the switch.
            lang = lang == .en ? .ms : .en
            store.set(lang.rawValue, forKey: "lang")
            buildKeys()
        }
        updateSuggestions()
        requestPhraseCompletion()
    }

    /// Repeats are intentional for deletes and cursor movement; clear-all
    /// has its own two-tap arm and must not have its second tap swallowed.
    private func isDebounceExempt(_ action: KeyAction) -> Bool {
        switch action {
        case .delete, .deleteWord, .clearAll, .cursorLeft, .cursorRight: return true
        default: return false
        }
    }

    private func handleClearAll() {
        if let armed = clearArmedAt, Date().timeIntervalSince(armed) < 3 {
            clearArmedAt = nil
            clearAllText()
            buildKeys() // restore the "Clear all" label
            return
        }
        clearArmedAt = Date()
        buildKeys() // relabel to "tap again"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.clearArmedAt != nil else { return }
            if Date().timeIntervalSince(self.clearArmedAt!) >= 3 {
                self.clearArmedAt = nil
                self.buildKeys() // disarm quietly
            }
        }
    }

    /// Clears everything the field exposes. Extensions only see a context
    /// window; in his real use (messages, search) that is the whole text.
    private func clearAllText() {
        if let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: after.count)
        }
        var passes = 0
        while let before = textDocumentProxy.documentContextBeforeInput,
              !before.isEmpty, passes < 200 {
            for _ in 0..<before.count { textDocumentProxy.deleteBackward() }
            passes += 1
        }
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

        // Count the base word, not the inflected label: "go", "goes" and
        // "going" are one key and one habit, and Recents would otherwise
        // fill up with three entries for the same cell.
        let counted = inflectionBase[word] ?? word
        usageCounts[counted, default: 0] += 1
        store.set(usageCounts, forKey: "usage")
        if !previous.isEmpty {
            learnedBigrams["\(previous.lowercased())|\(counted)", default: 0] += 1
            store.set(learnedBigrams, forKey: "bigrams")
        }
        refreshVerbForms()
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

    // MARK: Capture (Task G1 — letters-level typing, not grid-cell taps)

    /// Ends the current typed token — called on a terminator (space,
    /// return, grid punctuation, or a non-letter/non-apostrophe char).
    /// Counts it as a capture candidate when it has ≥3 letters (the
    /// apostrophe in a contraction like "don't" doesn't count toward
    /// that minimum, but stays in the stored/counted key) and isn't
    /// already known; always clears the accumulator either way.
    private func terminateToken() {
        let token = typedToken
        typedToken = ""
        let letterCount = token.filter(\.isLetter).count
        guard letterCount >= 3,
              token.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "\u{2019}" }),
              !isKnownWord(token) else { return }
        // Structured fields (email/URL/search) yield fragments like
        // "gmail" or "com" that are never real vocabulary — skip counting,
        // typing still works normally either way.
        switch textDocumentProxy.keyboardType {
        case .emailAddress?, .URL?, .webSearch?: return
        default: break
        }
        var counts = (store.dictionary(forKey: "captureCounts") as? [String: Int]) ?? [:]
        counts[token, default: 0] += 1
        store.set(counts, forKey: "captureCounts")
    }

    /// Case-insensitive check against myWords and the built-in vocabulary
    /// — `token` is already lowercased by the time it reaches here.
    private func isKnownWord(_ token: String) -> Bool {
        if myWords.contains(where: { $0.lowercased() == token }) { return true }
        return Self.knownVocabWords.contains(token)
    }

    // MARK: Prediction (on-device only — no Full Access, no network)

    /// The spell-check languages this system offers, resolved once.
    private static let checkerLanguages = UITextChecker.availableLanguages

    /// The language the user is ACTUALLY typing, detected from the field's
    /// own text — completions follow the text, not a settings toggle
    /// (Cotypist's "it just works in any language" feel). Falls back to
    /// the manual EN/MS toggle on short or ambiguous context, so nothing
    /// changes for a user who never leaves one language.
    private func completionLanguage() -> String {
        let sample = String((textDocumentProxy.documentContextBeforeInput ?? "").suffix(200))
        guard sample.count >= 12 else { return lang.spellCheckCode }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let detected = recognizer.dominantLanguage,
              (recognizer.languageHypotheses(withMaximum: 1)[detected] ?? 0) > 0.7,
              let match = Self.checkerLanguages.first(where: { $0.hasPrefix(detected.rawValue) })
        else { return lang.spellCheckCode }
        return match
    }

    /// Screen learning input: the broadcast extension's word-frequency
    /// store, honored only while fresh. Without Full Access the key simply
    /// never exists in `.standard` and this stays empty.
    private func reloadScreenWords() {
        let stamp = store.double(forKey: "screenWordsStamp")
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < 1800 else {
            screenWords = [:]
            return
        }
        screenWords = (store.dictionary(forKey: "screenWords") as? [String: Int]) ?? [:]
    }

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
        // Screen context: words the user is looking at right now are
        // likely in the reply. Weighted above the generic seeds but below
        // any real learned bigram, so personal learning always wins.
        for (word, count) in screenWords.sorted(by: { $0.value > $1.value }).prefix(15) {
            scores[word, default: 0] += min(count, 4)
        }
        return scores.sorted { $0.value > $1.value }.prefix(3).map(\.key)
    }

    private func topVocabulary() -> [String] {
        // myWords go first and are never starved by usage ranking — the
        // user's own words matter for completion regardless of how often
        // built-in vocabulary has been used.
        let ranked = usageCounts.sorted { $0.value > $1.value }.map(\.key)
        let screenTop = screenWords.sorted { $0.value > $1.value }.prefix(10).map(\.key)
        var seen = Set<String>()
        var result: [String] = []
        for word in myWords + screenTop + ranked {
            guard !seen.contains(word) else { continue }
            seen.insert(word)
            result.append(word)
            if result.count == 40 { break }
        }
        return result
    }

    private func requestPhraseCompletion() {
        guard isWordLevel, !completionEngine.isDegraded else {
            completionWords = []
            return
        }
        completionEngine.requestCompletion(
            context: contextBefore(),
            vocabulary: topVocabulary()
        ) { [weak self] completion in
            guard let self else { return }
            self.completionWords = completion?.words ?? []
            self.updateSuggestions()
        }
    }

    private func currentPartialWord() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        return context.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
    }

    private func updateSuggestions() {
        let titles: [String]
        if isWordLevel {
            if !completionWords.isEmpty {
                // Two chips, no symbols to decode: the short one is the next
                // word, the long one is the whole continuation. Since the
                // long chip starts with the short chip's word, the
                // relationship explains itself.
                var slots: [String] = [completionWords[0]]
                if completionWords.count >= 2 {
                    slots.append(completionWords.joined(separator: " "))
                }
                if let bigram = predictNextWords().first,
                   !slots.contains(bigram),
                   bigram != completionWords[0] {
                    slots.append(bigram)
                }
                titles = Array(slots.prefix(3))
            } else {
                titles = predictNextWords()
            }
        } else {
            let word = currentPartialWord()
            if word.count >= 2 {
                // Screen-learned matches lead: a name or product word seen
                // on screen won't be in the system dictionary at all, and
                // that is exactly the word worth one tap instead of ten.
                let lower = word.lowercased()
                var slots = screenWords
                    .filter { $0.key.hasPrefix(lower) && $0.key != lower }
                    .sorted { $0.value > $1.value }
                    .prefix(2)
                    .map(\.key)
                let checker = UITextChecker()
                let range = NSRange(location: 0, length: word.utf16.count)
                for completion in checker.completions(
                    forPartialWordRange: range, in: word, language: completionLanguage()) ?? [] {
                    if !slots.contains(where: { $0.caseInsensitiveCompare(completion) == .orderedSame }) {
                        slots.append(completion)
                    }
                }
                titles = Array(slots.prefix(3))
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
        UIDevice.current.playInputClick()
        impactFeedback.impactOccurred()
        if isWordLevel, !completionWords.isEmpty {
            if title == completionWords[0] {
                insertWord(completionWords[0])
                completionWords = []
                updateSuggestions()
                requestPhraseCompletion()
                return
            }
            if title == completionWords.joined(separator: " ") {
                for word in completionWords { insertWord(word) }
                completionWords = []
                updateSuggestions()
                requestPhraseCompletion()
                return
            }
        }
        if isWordLevel {
            insertWord(title)
        } else {
            // The chip replaces whatever was typed so far with a full
            // suggestion — typedToken no longer matches what's on screen.
            // Reset rather than count: the completed word wasn't typed
            // letter-by-letter, so it isn't a capture candidate.
            typedToken = ""
            let word = currentPartialWord()
            for _ in 0..<word.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(title + " ")
        }
        updateSuggestions()
    }
}

/// Routes raw touches to the controller so keys commit on lift-off
/// rather than touch-down.
private final class TrackingView: UIView, UIInputViewAudioFeedback {
    weak var controller: KeyboardViewController?

    var enableInputClicksWhenVisible: Bool { true }

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
