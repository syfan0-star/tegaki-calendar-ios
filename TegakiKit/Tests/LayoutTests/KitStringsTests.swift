import XCTest
import Foundation
import Layout

/// `KitStrings` and `UILanguage.pluralCategory` (docs/M7B_CONTRACT.md §2.3, §2.6, D5, 0-8).
final class KitStringsTests: XCTestCase {
    /// Runs in CI after the translations (X) are in (L-2 is the same rule on the sources).
    func testEveryKeyHasTenLanguages() {
        XCTAssertFalse(KitStrings.keys.isEmpty)
        XCTAssertEqual(KitStrings.keys, KitStrings.keys.sorted())
        for key in KitStrings.keys {
            for language in UILanguage.allCases {
                XCTAssertFalse((KitStrings.value(key, language) ?? "").isEmpty, "\(key) in \(language.rawValue)")
            }
        }
        // The ja-only patterns of D6 are in the ja table alone.
        for key in ["kit.date.ja.dayTitle", "kit.date.ja.weekTitle", "kit.date.ja.plainDay"] {
            XCTAssertNotNil(KitStrings.value(key, .ja), key)
            XCTAssertFalse(KitStrings.keys.contains(key), key)
            for language in UILanguage.allCases where language != .ja {
                XCTAssertNil(KitStrings.value(key, language), "\(key) in \(language.rawValue)")
            }
        }
    }

    func testPluralCategories() {
        let oneOnlyAtOne: [UILanguage] = [.en, .de, .es, .it]
        let oneAtZeroAndOne: [UILanguage] = [.fr, .ptBR]
        let alwaysOther: [UILanguage] = [.ja, .ko, .zhHans, .zhHant]
        XCTAssertEqual(oneOnlyAtOne.count + oneAtZeroAndOne.count + alwaysOther.count, UILanguage.allCases.count)
        for language in oneOnlyAtOne {
            XCTAssertEqual([0, 1, 2, 5, 21].map { language.pluralCategory($0) }, [.other, .one, .other, .other, .other], language.rawValue)
        }
        for language in oneAtZeroAndOne {
            XCTAssertEqual([0, 1, 2, 5, 21].map { language.pluralCategory($0) }, [.one, .one, .other, .other, .other], language.rawValue)
        }
        for language in alwaysOther {
            XCTAssertEqual([0, 1, 2, 5, 21].map { language.pluralCategory($0) }, [.other, .other, .other, .other, .other], language.rawValue)
        }
        XCTAssertEqual(KitStrings.plural("kit.layout.more", .ja, count: 1, ["1"]), "+1件")
        XCTAssertEqual(KitStrings.plural("kit.layout.more", .ja, count: 12, ["12"]), "+12件")
    }

    func testFormatPlaceholders() {
        XCTAssertEqual(KitStrings.format("kit.date.ja.monthTitle", .ja, ["2026", "10"]), "2026年10月", "%1$@ %2$@")
        XCTAssertEqual(KitStrings.format("%2$@ %1$@", .ja, ["a", "b"]), "b a", "any order")
        XCTAssertEqual(KitStrings.format("%@ and %@", .en, ["a", "b"]), "a and b", "%@ in order")
        XCTAssertEqual(KitStrings.format("%@ / %@", .en, ["a"]), "a / %@", "a missing argument leaves the placeholder")
        XCTAssertEqual(KitStrings.format("100%", .en, []), "100%", "a % that is no placeholder")
        XCTAssertEqual(KitStrings.text("kit.no.such.key", .ja), "kit.no.such.key", "a missing key gives the key")
        XCTAssertEqual(KitStrings.text("kit.no.such.key", .de), "kit.no.such.key", "a missing key gives the key")
        XCTAssertEqual(KitStrings.format("%@ %@", .ja, ["%@", "x"]), "%@ x", "an argument is not read again")
    }
}
