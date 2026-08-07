import Foundation
import NaturalLanguage

/// Where a word belongs on the board, decided on device.
///
/// Named-entity recognition needs a sentence: asked about a bare word,
/// Apple's tagger calls "John" an OtherWord, "Singapore" not a place, and
/// "Fadillah" an adjective. Putting the word into carrier sentences fixes
/// almost all of that — the same tagger then reads Hafiz, Ratna, Fadillah
/// and John as people, and Singapore, Suria and Paris as places, while
/// still correctly refusing "pizza" and "satay".
enum WordFiling {
    /// Sentences chosen so each puts the word in a position that a
    /// different entity type naturally occupies.
    private static let carriers = [
        "%@ is coming to lunch with us.",
        "I met %@ yesterday at the park.",
        "We are going to %@ on Friday.",
    ]

    /// "People", "Places", "Actions", or nil when the evidence is weak.
    /// Nil is a real answer: a word filed into the wrong category is worse
    /// than one that stays only in Mine, where the user put it.
    static func category(for word: String) -> String? {
        guard !word.contains(" "), word.count >= 2 else { return nil }
        let subject = word.capitalized

        var person = 0
        var place = 0
        for carrier in carriers {
            switch entity(of: subject, in: String(format: carrier, subject)) {
            case .personalName: person += 1
            case .placeName: place += 1
            default: break
            }
        }
        if person > 0 || place > 0 {
            return person >= place ? "People" : "Places"
        }

        // No entity signal: fall back to part of speech, which does work on
        // a bare word. Verbs are the only class with a board of their own.
        let lower = word.lowercased()
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = lower
        let (tag, _) = tagger.tag(at: lower.startIndex, unit: .word, scheme: .lexicalClass)
        return tag == .verb ? "Actions" : nil
    }

    private static func entity(of target: String, in sentence: String) -> NLTag? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence
        var found: NLTag?
        tagger.enumerateTags(
            in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            if String(sentence[range]).caseInsensitiveCompare(target) == .orderedSame, let tag {
                found = tag
                return false
            }
            return true
        }
        return found
    }
}

/// Verb forms that follow the sentence, the way TouchChat's boards do: type
/// "I am" and the `go` key becomes `going`, in the same cell it has always
/// been. This is relabeling in place — the same mechanism language
/// switching already uses — so grid positions never move (invariant 1) and
/// muscle memory survives. The user aims at the same square and gets the
/// word that actually fits the sentence, instead of typing "I am go" and
/// having to fix it letter by letter.
///
/// English only. Malay marks tense with separate particles rather than by
/// inflecting the verb, so `.base` is always correct there and the Malay
/// board is deliberately left alone (invariant 8: no unverified strings).
enum Grammar {

    /// The form the next verb should take, read from the words already typed.
    enum VerbForm {
        case base           // I go, you go, to go, will go, don't go
        case thirdPerson    // he goes
        case progressive    // I am going
        case past           // I went, I have gone -> past participle
    }

    /// Auxiliaries that put the next verb in the -ing form.
    private static let progressiveAuxiliaries: Set<String> =
        ["am", "is", "are", "was", "were", "being", "i'm", "you're", "he's", "she's", "it's", "we're", "they're"]

    /// Words after which the verb stays in its plain base form. Modals,
    /// "to", negations, and plural/first/second-person subjects.
    private static let baseTriggers: Set<String> = [
        "to", "will", "would", "can", "could", "should", "must", "may", "might", "shall",
        "don't", "doesn't", "didn't", "won't", "can't", "let", "please", "help",
        "i", "you", "we", "they",
    ]

    /// Subjects that take the -s form.
    private static let thirdPersonSubjects: Set<String> = ["he", "she", "it", "mum", "dad", "everyone", "who"]

    /// Auxiliaries that call for the past participle.
    private static let perfectAuxiliaries: Set<String> = ["have", "has", "had", "i've", "you've", "we've", "they've"]

    /// Irregular verbs among the shipped vocabulary, plus the handful a user
    /// is most likely to add. Anything absent falls through to the regular
    /// rules below, which are correct for the vast majority of English verbs.
    /// Each entry: base -> (thirdPerson, progressive, past, pastParticiple)
    private static let irregular: [String: (String, String, String, String)] = [
        "go":     ("goes", "going", "went", "gone"),
        "eat":    ("eats", "eating", "ate", "eaten"),
        "drink":  ("drinks", "drinking", "drank", "drunk"),
        "write":  ("writes", "writing", "wrote", "written"),
        "make":   ("makes", "making", "made", "made"),
        "give":   ("gives", "giving", "gave", "given"),
        "get":    ("gets", "getting", "got", "got"),
        "come":   ("comes", "coming", "came", "come"),
        "read":   ("reads", "reading", "read", "read"),
        "draw":   ("draws", "drawing", "drew", "drawn"),
        "see":    ("sees", "seeing", "saw", "seen"),
        "take":   ("takes", "taking", "took", "taken"),
        "sleep":  ("sleeps", "sleeping", "slept", "slept"),
        "buy":    ("buys", "buying", "bought", "bought"),
        "have":   ("has", "having", "had", "had"),
        "do":     ("does", "doing", "did", "done"),
        "say":    ("says", "saying", "said", "said"),
        "feel":   ("feels", "feeling", "felt", "felt"),
        "leave":  ("leaves", "leaving", "left", "left"),
        "sit":    ("sits", "sitting", "sat", "sat"),
        "stand":  ("stands", "standing", "stood", "stood"),
        "run":    ("runs", "running", "ran", "run"),
        "put":    ("puts", "putting", "put", "put"),
    ]

    /// Verbs that never inflect here: modals have no -ing or -s form, and
    /// "can" sits on the home board as a modal, not as a main verb.
    private static let invariable: Set<String> = ["can", "will", "must", "should", "would", "may", "might"]

    /// Reads the tail of what has been typed and decides which form the next
    /// verb should take. Only the last one or two words matter, which keeps
    /// this cheap enough to run on every keystroke.
    static func verbForm(after context: String) -> VerbForm {
        let words = context
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
        guard let last = words.last else { return .base }

        // "I am not going", "he is never eating" — an adverb between the
        // auxiliary and the verb must not break the agreement.
        let adverbs: Set<String> = ["not", "never", "always", "still", "just", "really", "also"]
        let effective = adverbs.contains(last) && words.count >= 2 ? words[words.count - 2] : last

        if progressiveAuxiliaries.contains(effective) { return .progressive }
        if perfectAuxiliaries.contains(effective) { return .past }
        if baseTriggers.contains(effective) { return .base }
        if thirdPersonSubjects.contains(effective) { return .thirdPerson }
        return .base
    }

    /// The verb in the requested form. Falls back to the base word whenever
    /// a rule would be a guess — a wrong word in a fixed position is worse
    /// than an uninflected one.
    static func inflect(_ verb: String, as form: VerbForm) -> String {
        let lower = verb.lowercased()
        guard !invariable.contains(lower), !verb.contains(" ") else { return verb }

        if let forms = irregular[lower] {
            switch form {
            case .base: return verb
            case .thirdPerson: return forms.0
            case .progressive: return forms.1
            case .past: return forms.3   // participle: "I have gone", "I have eaten"
            }
        }

        switch form {
        case .base: return verb
        case .thirdPerson: return thirdPersonForm(lower)
        case .progressive: return progressiveForm(lower)
        case .past: return pastForm(lower)
        }
    }

    private static func thirdPersonForm(_ verb: String) -> String {
        if verb.hasSuffix("s") || verb.hasSuffix("sh") || verb.hasSuffix("ch")
            || verb.hasSuffix("x") || verb.hasSuffix("z") || verb.hasSuffix("o") {
            return verb + "es"
        }
        if verb.hasSuffix("y"), let before = verb.dropLast().last, !isVowel(before) {
            return verb.dropLast() + "ies"
        }
        return verb + "s"
    }

    private static func progressiveForm(_ verb: String) -> String {
        if verb.hasSuffix("ie") { return verb.dropLast(2) + "ying" }        // lie -> lying
        if verb.hasSuffix("e"), !verb.hasSuffix("ee"), verb.count > 2 {
            return verb.dropLast() + "ing"                                  // make -> making
        }
        if shouldDoubleFinalConsonant(verb) { return verb + String(verb.last!) + "ing" }
        return verb + "ing"
    }

    private static func pastForm(_ verb: String) -> String {
        if verb.hasSuffix("e") { return verb + "d" }
        if verb.hasSuffix("y"), let before = verb.dropLast().last, !isVowel(before) {
            return verb.dropLast() + "ied"
        }
        if shouldDoubleFinalConsonant(verb) { return verb + String(verb.last!) + "ed" }
        return verb + "ed"
    }

    /// CVC one-syllable verbs double the final consonant: stop -> stopping,
    /// sit -> sitting. w/x/y never double.
    private static func shouldDoubleFinalConsonant(_ verb: String) -> Bool {
        let characters = Array(verb)
        guard characters.count >= 3 else { return false }
        let last = characters[characters.count - 1]
        let middle = characters[characters.count - 2]
        let first = characters[characters.count - 3]
        guard !isVowel(last), !"wxy".contains(last) else { return false }
        guard isVowel(middle), !isVowel(first) else { return false }
        // Only single-syllable verbs; a rough but reliable proxy is length.
        return characters.count <= 4
    }

    private static func isVowel(_ character: Character) -> Bool {
        "aeiou".contains(character)
    }
}
