import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §3.4, 0e-5, changed by the lead after §7.3's header crops of run 44926505978): which title
// the header shows. The short title (`PageNavigation.compactTitle`) on the compact rows of every device and on an iPhone's
// wide row (an iPhone in landscape, the iPhone Duo's open inner screen); the long title (`PageNavigation.title`) on an iPad's
// wide row only. On the iPhone 17 in landscape 1.4.1's wide row (with 等倍) cut the long week title 「2026年10月5日〜10月11日」
// to 「2026年10月5日〜10月…」 even at the 0.6 scale. The source check reads the code only, as PageHeaderRoomTests does: the
// screen decides with `pencilPhone.isPad` (no new reading of the idiom, tools/duo/idiom_check.py) and passes the holiday
// name (F-11) with the long title only.
@MainActor
final class HeaderTitleTests: XCTestCase {
    /// The rule: short unless the row is wide on an iPad.
    func testShortTitleOnTheCompactRowsAndOnAnIPhonesWideRow() {
        XCTAssertTrue(CalendarRootScreen.usesShortTitle(compact: true, isPad: false), "an iPhone's compact rows")
        XCTAssertTrue(CalendarRootScreen.usesShortTitle(compact: true, isPad: true), "an iPad's narrow window")
        XCTAssertTrue(CalendarRootScreen.usesShortTitle(compact: false, isPad: false),
                      "an iPhone's wide row (landscape, the Duo's open inner screen)")
        XCTAssertFalse(CalendarRootScreen.usesShortTitle(compact: false, isPad: true), "an iPad's wide row keeps the long title")
    }

    /// `CalendarRootScreen.screenColumn` picks the title and the holiday name by the rule, with the screen's `isPad`.
    func testScreenPicksTheTitleByTheRule() throws {
        let screen = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: Self.screenSource, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(screen.contains("let shortTitle = Self.usesShortTitle(compact: compact, isPad: pencilPhone.isPad)"))
        XCTAssertTrue(screen.contains("title: shortTitle ? PageNavigation.compactTitle(kind, focus: focus, language: L.language, "
                                      + "weekStart: weekStart) : PageNavigation.title(kind, focus: focus, holidays: holidays, "
                                      + "language: L.language, weekStart: weekStart), compact: compact,"), "the title")
        XCTAssertTrue(screen.contains("titleHoliday: !shortTitle && kind == .day ? holidays.name(of: focus) : nil,"),
                      "the holiday name with the long title only")
        XCTAssertFalse(screen.contains("title: compact ?"), "not by the width alone")
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let screenSource = repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
}
