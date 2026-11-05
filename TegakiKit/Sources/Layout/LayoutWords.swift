import Foundation
import DayKit

/// The words the layout engines put into a page (1.2, docs/M7B_CONTRACT.md §0, §3.1 rule 4, F-5):
/// the month page's 「+n件」 chip, the 〜 before the end time of an overnight event's tail chip
/// (「〜11:00」) and the separator of a time range (「9:00〜10:30」). The engines take them in their
/// input (`words:`, default `.japanese`); words never change the geometry (D9, G-2), only the text of
/// the chips and boxes.
///
/// The texts come from `KitStrings` (`kit.layout.*`); `tailPrefix` and `timeRange` are the values the
/// contract fixed for every language (ja 〜, ko ~, the others –), `moreOne` / `moreOther` are
/// translated.
public struct LayoutWords: Equatable, Sendable {
    /// The chip of the hidden events, one and other (D5, 0-8): 「+%@件」 (ja: both the same).
    public var moreOne: String
    public var moreOther: String
    /// Put before the end time of the tail of an overnight event: 「〜」 (「〜11:00」).
    public var tailPrefix: String
    /// A range of two texts: 「%1$@〜%2$@」.
    public var timeRange: String
    /// The language, for the plural rule of `more`.
    public var language: UILanguage

    /// The words of 1.1 (`of(.ja)`: 「+%@件」, 「〜」, 「%1$@〜%2$@」).
    public static let japanese = LayoutWords.of(.ja)

    /// The words of `language`, from `KitStrings` (a text that is not translated yet falls back to
    /// en, as every Kit text does).
    public static func of(_ language: UILanguage) -> LayoutWords {
        LayoutWords(
            moreOne: KitStrings.text("kit.layout.more.one", language),
            moreOther: KitStrings.text("kit.layout.more.other", language),
            tailPrefix: KitStrings.text("kit.layout.tailPrefix", language),
            timeRange: KitStrings.text("kit.layout.timeRange", language),
            language: language
        )
    }

    /// The chip of `n` hidden events: 「+3件」 (ja), "+3 more" (en): `moreOne` or `moreOther` (the form
    /// `language.pluralCategory(n)` picks) with the number, written as `String(n)` (1.1's 「+\(n)件」).
    public func more(_ n: Int) -> String {
        KitStrings.fill(language.pluralCategory(n) == .one ? moreOne : moreOther, [String(n)])
    }

    /// `timeRange` filled with two texts: range("9:00", "10:30") → 「9:00〜10:30」 (ja),
    /// "9:00–10:30" (en). The texts are put in as they are (they may be times or dates).
    public func range(_ start: String, _ end: String) -> String {
        KitStrings.fill(timeRange, [start, end])
    }

    /// `tailPrefix` before a time: tail("11:00") → 「〜11:00」 (ja), "–11:00" (en).
    public func tail(_ end: String) -> String {
        tailPrefix + end
    }
}
