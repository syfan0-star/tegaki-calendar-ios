import Layout
import XCTest
@testable import TegakiCalendar

/// The app's words (docs/M7B_CONTRACT.md §0, §2.5): the fallback of a missing key, the choice of the
/// plural form, the placeholders. The tests run with `-testLanguage ja -testRegion JP` (0-25).
final class L10nTests: XCTestCase {
    func testTheTestsRunInJapanese() {
        XCTAssertEqual(L.language, .ja)
    }

    func testMissingKeyFallsBackToEnglish() {
        let unknown = "no.such.key"
        XCTAssertEqual(L.text(unknown), unknown, "no language has it: the key itself")
        XCTAssertEqual(L.text(unknown, in: .de), unknown)
        XCTAssertNil(L.value(unknown, in: .de), "value has no fallback")
        XCTAssertEqual(L.format(unknown, "a"), unknown)
        // A key en has: every language reads en's text through the same function when it lacks one;
        // all ten have it, so this is en's own value and the fallback's first step.
        XCTAssertEqual(L.text("export.close", in: .en), L.value("export.close", in: .en))
        XCTAssertNotEqual(L.text("export.close", in: .en), "export.close")
    }

    func testPluralPicksOneOrOther() {
        // Japanese has one form: both keys are the same text.
        XCTAssertEqual(L.text("import.skipped.one", in: .ja), L.text("import.skipped.other", in: .ja))
        XCTAssertEqual(L.plural("import.skipped", count: 1, "1"), "1 ページは対象外のため飛ばしました")
        XCTAssertEqual(L.plural("import.skipped", count: 2, "2"), "2 ページは対象外のため飛ばしました")
        // The category, per language (0-8), and that the pair is really two texts where it matters.
        XCTAssertEqual(UILanguage.en.pluralCategory(1), .one)
        XCTAssertEqual(UILanguage.en.pluralCategory(0), .other)
        XCTAssertEqual(UILanguage.fr.pluralCategory(0), .one)
        XCTAssertEqual(UILanguage.ja.pluralCategory(1), .other)
        XCTAssertNotEqual(L.text("import.result.pages.one", in: .en), L.text("import.result.pages.other", in: .en))
    }

    func testFormatReplacesInOrder() {
        XCTAssertEqual(L.format("export.done.pdf", "a.pdf", "1 B"), "a.pdf（1 B）")
        XCTAssertEqual(L.format("toolbar.badge.penWidth", "赤", "太"), "ペン・赤・太")
        // The rule of the fill (the numbered form takes its own argument; a stray % stays).
        XCTAssertEqual(KitStrings.fill("%2$@ %1$@ 100%", ["a", "b"]), "b a 100%")
    }

    /// A count keeps 1.1's form in Japanese and is grouped elsewhere (D5, J-1).
    func testCount() {
        XCTAssertEqual(L.count(1234), "1234")
        XCTAssertEqual(L.count(1234, in: .ja), "1234")
        XCTAssertEqual(L.count(1234, in: .de), DateText.number(1234, .de))
        XCTAssertEqual(L.count(12, in: .en), "12")
    }
}
