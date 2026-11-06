import Foundation
import Layout

/// The app's words in the language of the screen (1.2, docs/M7B_CONTRACT.md §0, §2.5).
///
/// Every text the app shows goes through here: `Text(L.text("settings.title"))`,
/// `L.format("sync.lastSync", time)`, `L.plural("export.progress", count: total, done, all)`. The
/// keys and their ja (the 1.1 text, J-1) are in tools/l10n/source/app-<owner>.json, the other nine
/// languages in tools/l10n/translations/; tools/l10n/build.py writes them into
/// Resources/Localizable.xcstrings (or, with `--format strings`, the `.lproj/Localizable.strings`
/// files), and iOS picks the `.lproj` of the screen (§2.1). The Kit's words (titles, plan texts,
/// holidays) come from its own functions, which take `language: L.language` (D4).
///
/// Numbers are formatted before they are passed (D5: `DateText.number`), so a value only has the
/// placeholders `%@` and `%n$@`, filled by the rule of `KitStrings.fill` (no `String(format:)`: a
/// stray `%` in a translation cannot crash or eat an argument). A plural is the pair `<key>.one` /
/// `<key>.other`, picked by `UILanguage.pluralCategory` (0-8).
enum L {
    /// The language of the screen: `UILanguage.current`, the `.lproj` iOS chose for the app, read
    /// once (iOS ends the app when its language changes). The unit tests run with
    /// `-testLanguage ja -testRegion JP` (0-25), so it is `.ja` there.
    static let language: UILanguage = UILanguage.current

    /// The locale for formatting in the language of the screen and the device's region (§2.1: not
    /// `Locale.current`, whose language can differ from the `.lproj` iOS chose).
    static var locale: Locale { language.locale() }

    /// The text of `key` in the language of the screen (the Localizable table of the `.lproj` iOS
    /// chose, the same as `language`). A key that table does not have gives the en text, and a key
    /// en does not have either gives the key itself; in a DEBUG build and in the screenshot mode the
    /// first miss of each key is logged as "l10n: missing <key>" (the l10n-shots job counts them).
    static func text(_ key: String) -> String {
        if let found = lookUp(key, in: Bundle.main) {
            return found
        }
        reportMissing(key)
        return value(key, in: .en) ?? key
    }

    /// The text of `key` in the `.lproj` of `language`, with the same fallback (en, then the key);
    /// nothing is logged. For the tests and the checks of the language choice (ToolbarFitTests
    /// measures the ten languages with it).
    static func text(_ key: String, in language: UILanguage) -> String {
        value(key, in: language) ?? value(key, in: .en) ?? key
    }

    /// `text(key)` with its placeholders filled: `%@` takes the next argument, `%n$@` the n-th.
    static func format(_ key: String, _ args: String...) -> String {
        KitStrings.fill(text(key), args)
    }

    /// `format(key + ".one", …)` or `format(key + ".other", …)`, the form `count` takes in the
    /// language of the screen. `count` only picks the form; a text that shows the number gets it in
    /// `args`, already formatted (`DateText.number(count, L.language)`).
    static func plural(_ key: String, count: Int, _ args: String...) -> String {
        KitStrings.fill(text(key + "." + language.pluralCategory(count).rawValue), args)
    }

    /// The text of `key` in the `.lproj` of `language` itself, without any fallback: nil when that
    /// table does not have the key (or the app has no such `.lproj`). For the check that every
    /// language has every key (LocalizationBundleTests), which the fallback of `text` would hide.
    static func value(_ key: String, in language: UILanguage) -> String? {
        guard let bundle = languageBundles[language] else { return nil }
        return lookUp(key, in: bundle)
    }

    /// A count inside a sentence (「3 ページ」): ja keeps what 1.1's `\(n)` wrote, without grouping
    /// (「1234 ページ」, J-1), every other language groups it (`DateText.number`, D5). The fixed numbers
    /// 1.1 wrote with a comma (20,000) use `DateText.number` directly (§3.2).
    static func count(_ n: Int, in language: UILanguage = L.language) -> String {
        language == .ja ? String(n) : DateText.number(n, language)
    }

    // MARK: - Looking up

    /// What `localizedString` returns for a key its table does not have: three private-use
    /// characters, which no text of the tables has. They have no capitals, because with
    /// `-NSShowNonLocalizedStrings YES` (the l10n-shots job) Foundation logs the miss and returns
    /// this value in capitals, and with `-NSDoubleLocalizedStrings YES` it returns it doubled
    /// ("<marker> <marker>"); both still start with the marker (measured with macOS's Foundation:
    /// a word in the marker came back as "L10N-MISSING" and was shown).
    private static let missingMarker = "\u{E000}\u{E001}\u{E000}"

    /// The text of `key` in the Localizable table of `bundle`, nil when the table does not have it.
    /// A found text comes back doubled with `-NSDoubleLocalizedStrings YES`, as that switch means
    /// (Foundation drops the first "%" so the placeholders stay as many: "%@ x" → "@ x %@ x"). The
    /// key in capitals also counts as a miss, in case a Foundation returns that instead of the
    /// value (a key starts with a small letter, so a found text is never its capitals).
    private static func lookUp(_ key: String, in bundle: Bundle) -> String? {
        let found = bundle.localizedString(forKey: key, value: missingMarker, table: nil)
        if found.hasPrefix(missingMarker)
            || (found.utf16.count == key.utf16.count && found == key.uppercased()) {
            return nil
        }
        return found
    }

    /// The bundle of each `.lproj` of the app (`ja.lproj`, `pt-BR.lproj`, …): a bundle made from
    /// the folder looks its strings up in that language only.
    private static let languageBundles: [UILanguage: Bundle] = {
        var bundles: [UILanguage: Bundle] = [:]
        for language in UILanguage.allCases {
            if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundles[language] = bundle
            }
        }
        return bundles
    }()

    // MARK: - Missing keys

    private static let missingKeys = MissingKeys()

    private static func reportMissing(_ key: String) {
        #if DEBUG
        let wanted = true
        #else
        let wanted = ScreenshotMode.isActive
        #endif
        if wanted, missingKeys.isFirst(key) {
            NSLog("l10n: missing %@", key)
        }
    }

    /// The keys already logged (each once, however often a view asks for it).
    private final class MissingKeys: @unchecked Sendable {
        private let lock = NSLock()
        private var keys: Set<String> = []

        func isFirst(_ key: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return keys.insert(key).inserted
        }
    }
}
