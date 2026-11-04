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
        Self.fill(language.pluralCategory(n) == .one ? moreOne : moreOther, [String(n)])
    }

    /// `timeRange` filled with two texts: range("9:00", "10:30") → 「9:00〜10:30」 (ja),
    /// "9:00–10:30" (en). The texts are put in as they are (they may be times or dates).
    public func range(_ start: String, _ end: String) -> String {
        Self.fill(timeRange, [start, end])
    }

    /// `tailPrefix` before a time: tail("11:00") → 「〜11:00」 (ja), "–11:00" (en).
    public func tail(_ end: String) -> String {
        tailPrefix + end
    }

    /// The placeholders of `template` filled from `args`, by the rule of `KitStrings.format`: `%@`
    /// takes the next argument (a `%n$@` does not move this count), `%n$@` takes `args[n − 1]` (n from
    /// 1 to 99), any other `%` stays, and so does a placeholder whose argument is missing.
    static func fill(_ template: String, _ args: [String]) -> String {
        let percent = UInt8(ascii: "%"), at = UInt8(ascii: "@"), dollar = UInt8(ascii: "$")
        let zero = UInt8(ascii: "0"), nine = UInt8(ascii: "9")
        guard template.utf8.contains(percent) else { return template }
        let bytes = Array(template.utf8)
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count + 16)
        var copied = 0  // bytes[..<copied] are in `result` already
        var next = 0    // the argument of the next "%@"
        var i = 0
        while i < bytes.count {
            guard bytes[i] == percent else {
                i += 1
                continue
            }
            var end = i + 1  // the "@" of the placeholder that starts at i, if there is one
            var argument = -1
            if end < bytes.count, bytes[end] == at {
                argument = next
                next += 1
            } else {
                var n = 0
                while end < bytes.count, end - i <= 2, bytes[end] >= zero, bytes[end] <= nine, n > 0 || bytes[end] != zero {
                    n = n * 10 + Int(bytes[end] - zero)
                    end += 1
                }
                if n > 0, end + 1 < bytes.count, bytes[end] == dollar, bytes[end + 1] == at {
                    argument = n - 1
                    end += 1
                }
            }
            guard argument >= 0 else {
                i += 1
                continue
            }
            if argument < args.count {
                result.append(contentsOf: bytes[copied..<i])
                result.append(contentsOf: args[argument].utf8)
                copied = end + 1
            }
            i = end + 1
        }
        if copied == 0 { return template }
        result.append(contentsOf: bytes[copied...])
        return String(decoding: result, as: UTF8.self)
    }
}
