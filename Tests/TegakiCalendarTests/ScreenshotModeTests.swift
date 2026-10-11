import Layout
import XCTest
@testable import TegakiCalendar

/// Screenshot mode (M3a contract §8.3): the launch arguments, the fixed 「今日」, and the demo page
/// of every page kind.
final class ScreenshotModeTests: XCTestCase {
    private let october = YearMonth(year: 2026, month: 10)

    func testParseEveryPage() {
        let pages: [(String, PageKind)] = [("day", .day), ("week", .week), ("month", .month), ("year", .year)]
        for (name, kind) in pages {
            let config = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", name])
            XCTAssertEqual(config?.page, kind, name)
            XCTAssertEqual(config?.month, october, name)
        }
    }

    func testDefaultsAndBadValues() {
        XCTAssertNil(ScreenshotMode.parse([]))
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-month", "2026-10"]))

        let plain = ScreenshotMode.parse(["--screenshot-mode"])
        XCTAssertEqual(plain?.page, .month)
        XCTAssertEqual(plain?.month, YearMonth.current())

        let bad = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "bogus"])
        XCTAssertEqual(bad?.page, .month)
        XCTAssertEqual(bad?.month, october)

        let badMonth = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-13"])
        XCTAssertEqual(badMonth?.month, YearMonth.current())
    }

    func testFocusAndTodayAreTheSeventh() {
        let config = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week"])
        XCTAssertEqual(config?.focus, DayKey(year: 2026, month: 10, day: 7))
        let expected = DayKey(year: 2026, month: 10, day: 7).startOfDay().addingTimeInterval(10 * 3600)
        XCTAssertEqual(config?.today, expected)
        XCTAssertEqual(config.map { DayKey($0.today) }, config?.focus)
    }

    func testDemoPageIdsMatchTheNavigation() {
        let focus = DayKey(year: 2026, month: 10, day: 7)
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .month, focus: focus).pageId, "m1-2026-10")
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .week, focus: focus).pageId, "w-2026-10-05")
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .day, focus: focus).pageId, "d-2026-10-07")
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .year, focus: focus).pageId, "y-2026")
        for kind in PageKind.allCases {
            let page = ScreenshotMode.demoPage(kind: kind, focus: focus)
            XCTAssertEqual(page.pageId, PageNavigation.pageId(kind, focus: focus))
            XCTAssertFalse(page.liveStrokes.isEmpty, "\(kind) has demo strokes")
        }
    }

    func testDemoStrokesSitInTheirPagesCells() {
        let focus = DayKey(year: 2026, month: 10, day: 7)
        let week = ScreenshotMode.demoPage(kind: .week, focus: focus)
        XCTAssertEqual(Set(week.liveStrokes.map { $0.cell.raw }), ["allday:2026-10-07", "grid"])
        let day = ScreenshotMode.demoPage(kind: .day, focus: focus)
        XCTAssertEqual(Set(day.liveStrokes.map { $0.cell.raw }), ["allday", "grid"])
        // The day page's memo strokes lie in the memo column (x ≥ 660).
        for stroke in day.liveStrokes where stroke.cell.isGrid {
            XCTAssertTrue(stroke.points.allSatisfy { $0.x >= PaperSpec.dayTimelineRight })
        }
        let year = ScreenshotMode.demoPage(kind: .year, focus: focus)
        XCTAssertEqual(Set(year.liveStrokes.map { $0.cell.raw }), ["10-07", "02-30"])
    }

    func testDemoEventsIncludeTheSeventh() {
        let events = ScreenshotMode.demoEvents(for: october)
        let seventh = DayKey(year: 2026, month: 10, day: 7)
        let dayStart = seventh.startOfDay()
        let dayEnd = seventh.adding(days: 1).startOfDay()
        let onSeventh = events.filter { $0.overlaps(dayStart, dayEnd) }
        XCTAssertEqual(Set(onSeventh.map { $0.title }), ["締切", "打合せ", "電話", "歯科"])
        XCTAssertEqual(onSeventh.filter { $0.allDay }.map { $0.title }, ["締切"])
        let meeting = events.first { $0.title == "打合せ" }
        XCTAssertEqual(meeting?.start, dayStart.addingTimeInterval(10 * 3600))
        XCTAssertEqual(meeting?.end, dayStart.addingTimeInterval(11 * 3600 + 30 * 60))
        // Ids are unique and the M2 ids did not move.
        XCTAssertEqual(Set(events.map { $0.id }).count, events.count)
        XCTAssertEqual(events.first?.id, "demo-1")
        XCTAssertEqual(events.first?.title, "運動会")
    }
}
