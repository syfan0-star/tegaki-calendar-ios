import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4 D1d (docs/M7D.md; docs/M7D_CONTRACT.md §3.5, §4.1, §7.3): the compact header's tight first row. On the iPhone
// Duo's outer screen in portrait (382 pt beside its 84 pt side strip) 1.3's row cut the month and week titles
// (「2026年1…」, 「10/5〜10…」, duo-shots run 44696154794). Below `PageHeaderView.roomyCompactWidth` the first row gives the
// title 22 pt more; from it up — the 402 pt iPhone 17 and the 440 pt iPhone that J-4 photographs, every iPad — the
// header is 1.3's. The pieces' sizes come from the photos (iOS 27.2, the same in 1.3's Xcode 26.6 ones): with the 12 pt
// side paddings the fixed parts of 1.3's row take 324 pt (`fixedWidth`). Mutations: any other `roomyCompactWidth` fails
// the first test (the rows at 399.99, 400 and 402); other tight constants fail the second; a tight row that keeps a
// spacer or 1.3's ◀ ▶ gap or ＋ width, or any change to 1.3's two arms of the body, fails the fourth (it reads the source
// in code only, as OnePageRevealTests does: XCTest does not lay out the header).
@MainActor
final class PageHeaderRoomTests: XCTestCase {
    /// 1.3's compact first row without its title, on iOS 27.2: the paddings 12 + 12, ◀ ▶ 44 + 6 + 44, seven gaps of 4,
    /// 「今日」 56, ＋ 52, ☁ 26, ⚙ 44 (measured: the title starts at 115 and 「今日」 at 200 on the 402 pt iPhone 17).
    private let fixedWidth: CGFloat = 324
    /// The longest Japanese short title at the minimum scale (17 pt × 0.6): 「10/24〜10/30」, 69.8 pt.
    private let longestTitle: CGFloat = 70

    /// The title's room in the compact first row the header draws at `width`.
    private func room(_ width: CGFloat) -> CGFloat {
        width - fixedWidth + (PageHeaderView.usesTightRow(compact: true, width: width) ? PageHeaderView.tightTitleGain : 0)
    }

    /// The decision, by the width the owner passes (`CalendarRootScreen.screenColumn`: the column's width inside the safe
    /// area; compact below `CalendarRootScreen.compactWidth`).
    func testTightRowOnlyBelowTheIPhone17() {
        let table: [(name: String, width: CGFloat, tight: Bool)] = [
            ("a narrow iPad window", 320, true),
            ("iPhone SE, 12 mini, 13 mini in portrait", 375, true),
            ("the Duo's outer screen in portrait (466 − 84)", 382, true),
            ("iPhone 12 to 14, 16e in portrait", 390, true),
            ("iPhone 14 Pro, 15, 16 in portrait", 393, true),
            ("just below the edge", 399.99, true),
            ("the edge", 400, false),
            ("iPhone 17 in portrait (J-4)", 402, false),
            ("iPhone Air in portrait", 420, false),
            ("iPhone 16 Plus in portrait", 430, false),
            ("iPhone 18 Pro Max in portrait (J-4)", 440, false),
            ("the Duo's outer screen in landscape (678 − 84)", 594, false),
            ("iPad mini in portrait (J-4, one row)", 744, false),
            ("iPhone 17 in landscape (874 − 2 × 62, one row)", 750, false),
            ("iPad Pro 11-inch in portrait (J-4, one row)", 834, false),
            ("iPad Pro 13-inch in portrait (J-4, one row)", 1032, false),
            ("no width given", .infinity, false),
            ("not a number", .nan, false),
        ]
        for row in table {
            let compact = row.width < CalendarRootScreen.compactWidth
            XCTAssertEqual(PageHeaderView.usesTightRow(compact: compact, width: row.width), row.tight, "\(row.name): \(row.width) pt")
        }
        XCTAssertEqual(PageHeaderView.roomyCompactWidth, 400)
        // The one-row header is never tight, whatever width it is given.
        for width: CGFloat in [0, 320, 375, 382, 399] {
            XCTAssertFalse(PageHeaderView.usesTightRow(compact: false, width: width), "one row at \(width) pt")
        }
    }

    /// The tight row's pieces and the room they give the title: every width from 375 pt has the room of the longest
    /// Japanese short title; the widths that keep 1.3's row had it already, and keep exactly 1.3's room.
    func testTightRowGivesTheTitleItsRoom() {
        XCTAssertEqual(PageHeaderView.tightNavigationSpacing, 0)
        XCTAssertEqual(PageHeaderView.tightAddEventSymbolWidth, 20)
        XCTAssertGreaterThanOrEqual(PageHeaderView.tightAddEventSymbolWidth + 2 * 12, 44, "the ＋ capsule keeps a 44 pt wide target")
        XCTAssertEqual(PageHeaderView.tightTitleGain, 22, "8 (the spacers' gaps) + 6 (◀ ▶) + 8 (＋)")
        XCTAssertEqual(fixedWidth + longestTitle - PageHeaderView.tightTitleGain, 372, "the tight row fits the longest title from 372 pt")
        for width: CGFloat in [375, 382, 390, 393] {
            XCTAssertLessThan(width - fixedWidth, longestTitle, "1.3's row cuts the longest title at \(width) pt")
            XCTAssertGreaterThanOrEqual(room(width), longestTitle, "the tight row at \(width) pt")
        }
        for width: CGFloat in [400, 402, 420, 430, 440] {
            XCTAssertEqual(room(width), width - fixedWidth, "1.3's row at \(width) pt")
            XCTAssertGreaterThanOrEqual(room(width), longestTitle, "1.3's row at \(width) pt")
        }
        XCTAssertEqual(room(375), 73)
        XCTAssertEqual(room(382), 80, "the Duo's outer screen: more than the iPhone 17's 78")
        XCTAssertEqual(room(402), 78)
        XCTAssertEqual(room(440), 116)
    }

    /// The model's longest title, measured with the simulator's own font: every Japanese short title of 2026 and 2027
    /// (both week starts, every page kind) at the title's minimum scale (17 pt semibold × 0.6) fits the tight row's room
    /// on a 375 pt iPhone. The unit tests run in Japanese (`-testLanguage ja`), so the kanji fall back as on the owner's
    /// iPhone.
    func testLongestJapaneseShortTitleFitsAt375() {
        let font = UIFont.systemFont(ofSize: 17 * 0.6, weight: .semibold)
        func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }
        var longest: (width: CGFloat, title: String) = (0, "")
        var day = DayKey(year: 2026, month: 1, day: 1)
        let end = DayKey(year: 2028, month: 1, day: 1)
        while day < end {
            for kind in PageHeaderView.pickerOrder {
                for weekStart in [WeekStart.monday, .sunday] {
                    let title = PageNavigation.compactTitle(kind, focus: day, language: .ja, weekStart: weekStart)
                    let w = width(title)
                    if w > longest.width { longest = (w, title) }
                }
            }
            day = day.adding(days: 1)
        }
        XCTAssertGreaterThan(longest.width, 50, "the font measures (\(longest.title))")
        XCTAssertLessThanOrEqual(longest.width, room(375), "\(longest.title): \(longest.width) pt at 10.2 pt")
    }

    /// The body is 1.3's with one more arm in front: the tight rows, only when `usesTightRow`. The two arms after it are
    /// 1.3's word for word (7895d40), and the tight row is 1.3's first row without its spacers and with the tight ◀ ▶ and ＋.
    func testOnlyTheTightArmIsNew() throws {
        let code = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: Self.source, encoding: .utf8)))
        let compact13 = "VStack(spacing: 4) { HStack(spacing: 4) { navigationButtons Spacer(minLength: 0) titleText(.headline) "
            + "Spacer(minLength: 0) todayButton addEventButton syncButton settingsButton } kindPicker .frame(maxWidth: .infinity) }"
        let wide13 = "HStack(spacing: 6) { navigationButtons Spacer(minLength: 8) titleText(.title2) Spacer(minLength: 8) kindPicker "
            + ".frame(width: 220) .layoutPriority(1) readOnlyBadge todayButton addEventButton syncButton settingsButton }"
        let tight = "VStack(spacing: 4) { tightFirstRow kindPicker .frame(maxWidth: .infinity) }"
        XCTAssertEqual(try Self.body(of: "var body: some View {", in: code),
                       "if Self.usesTightRow(compact: compact, width: width) { \(tight) } else if compact { \(compact13) } else { \(wide13) } }")
        XCTAssertEqual(try Self.body(of: "private var tightFirstRow: some View {", in: code),
                       "HStack(spacing: 4) { navigationButtons(spacing: Self.tightNavigationSpacing) titleText(.headline) "
                       + ".frame(maxWidth: .infinity) todayButton addEventButton(symbolWidth: Self.tightAddEventSymbolWidth) "
                       + "syncButton settingsButton } }")
        // 1.3's pieces keep 1.3's values: ◀ ▶ 6 apart, the ＋ symbol at least 28 × 28.
        XCTAssertEqual(try Self.body(of: "private var navigationButtons: some View {", in: code), "navigationButtons(spacing: 6) }")
        XCTAssertEqual(try Self.body(of: "private var addEventButton: some View {", in: code), "addEventButton(symbolWidth: 28) }")
        XCTAssertTrue(try Self.body(of: "private func navigationButtons(spacing: CGFloat) -> some View {", in: code)
            .hasPrefix("HStack(spacing: spacing) { Button(action: onPrevious) {"))
        XCTAssertTrue(try Self.body(of: "private func addEventButton(symbolWidth: CGFloat) -> some View {", in: code)
            .contains(".frame(minWidth: symbolWidth, minHeight: 28)"))
    }

    private static let source = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/TegakiCalendar/Views/PageHeaderView.swift")

    /// The body of the declaration of `code` whose head (to its "{") is `head`, every run of white space one space (the
    /// shape of OnePageRevealTests' helper, which is private there).
    private static func body(of head: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: head), "\(head) is in PageHeaderView.swift")
        var depth = 1
        var end = start.upperBound
        while end < code.endIndex, depth > 0 {
            if code[end] == "{" { depth += 1 } else if code[end] == "}" { depth -= 1 }
            end = code.index(after: end)
        }
        return code[start.upperBound..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
