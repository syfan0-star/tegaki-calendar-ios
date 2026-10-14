import Layout
import XCTest
@testable import TegakiCalendar

/// Screenshot mode (M3a contract §8.3, M3b §6.3, M4 §8.3): the launch arguments, the fixed 「今日」,
/// the demo page of every page kind, the M3b sheets (`--screenshot-sheet`) with their demo calendars,
/// and the M4 sheets (`sync`, `import`) with the demo sync values.
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

    // MARK: M3b sheets

    func testParseEverySheet() {
        let sheets: [(String, ScreenshotMode.Sheet)] = [("create", .create), ("edit", .edit), ("lasso", .lasso), ("settings", .settings)]
        for (name, sheet) in sheets {
            let config = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", name])
            XCTAssertEqual(config?.sheet, sheet, name)
            XCTAssertEqual(config?.page, .month, name)
            XCTAssertEqual(config?.month, october, name)
        }
        // A sheet wins over the page argument (sheets live on the month page).
        let withPage = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-page", "week", "--screenshot-sheet", "edit"])
        XCTAssertEqual(withPage?.sheet, .edit)
        XCTAssertEqual(withPage?.page, .month)
    }

    func testSheetDefaultsAndBadValues() {
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode"])?.sheet)
        let bad = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-page", "week", "--screenshot-sheet", "bogus"])
        XCTAssertNil(bad?.sheet)
        XCTAssertEqual(bad?.page, .week, "an unknown sheet leaves the page argument alone")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet"])?.sheet)
    }

    func testDemoCalendarOptionsAndIds() {
        let options = ScreenshotMode.calendarOptions
        XCTAssertEqual(options.count, 4)
        XCTAssertEqual(options.map { $0.id }, ["demo-work", "demo-family", "demo-personal", "demo-events"])
        for option in options {
            XCTAssertTrue(option.isWritable, option.id)
            XCTAssertTrue(option.acceptsNewEvents, option.id)
            XCTAssertFalse(option.isSubscribed)
            XCTAssertFalse(option.isBirthday)
            XCTAssertEqual(option.sourceTitle, "見本")
        }
        XCTAssertEqual(EventStoreModel.demoDefaultCalendarId, "demo-personal")
        XCTAssertTrue(options.contains { $0.id == EventStoreModel.demoDefaultCalendarId })

        // The lasso demo stroke is on the month page; the edit demo event is 家族旅行 in 家族.
        let page = ScreenshotMode.demoPage(for: october)
        XCTAssertTrue(page.isLive(ScreenshotMode.lassoDemoStrokeId))
        let trip = ScreenshotMode.demoEvents(for: october).first { $0.id == ScreenshotMode.editDemoEventId }
        XCTAssertEqual(trip?.title, "家族旅行")
        XCTAssertEqual(trip?.calendarId, "demo-family")
        XCTAssertEqual(trip?.allDay, true)
        XCTAssertEqual(ScreenshotMode.createDemoDay(for: october), DayKey(year: 2026, month: 10, day: 14))
    }

    // MARK: M4 sheets (M4 contract §6.6, §8.3)

    func testParseM4Sheets() {
        let sheets: [(String, ScreenshotMode.Sheet)] = [("sync", .sync), ("import", .`import`)]
        for (name, sheet) in sheets {
            let config = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", name])
            XCTAssertEqual(config?.sheet, sheet, name)
            XCTAssertEqual(config?.page, .month, name)
            XCTAssertEqual(config?.month, october, name)
        }
        // Unknown values still mean no sheet (the raw values are lower case).
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "Sync"])?.sheet)
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "export"])?.sheet)
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "bogus"])?.sheet)
        XCTAssertEqual(ScreenshotMode.Sheet.allCases.count, 6)
        XCTAssertEqual(ScreenshotMode.Sheet.allCases.map { $0.rawValue }, ["create", "edit", "lasso", "settings", "sync", "import"])
    }

    func testDemoSyncValues() {
        let today = ScreenshotMode.todayInstant(for: october)
        XCTAssertEqual(ScreenshotMode.demoLastSyncAt(for: today), today.addingTimeInterval(-180))
        XCTAssertEqual(ScreenshotMode.demoLastSyncAt(for: today).timeIntervalSince(today), -180, accuracy: 0.001)
        // 10:00 on the 7th → 9:57 (「最後に同期」 in the `sync` sheet).
        let minutes = Int(ScreenshotMode.demoLastSyncAt(for: today).timeIntervalSince(DayKey(year: 2026, month: 10, day: 7).startOfDay()) / 60)
        XCTAssertEqual(minutes, 9 * 60 + 57)

        XCTAssertEqual(ScreenshotMode.importDemoOutcome, ImportOutcome(pagesChanged: 12, strokesAdded: 348, pagesSeen: 12))
        XCTAssertEqual(ScreenshotMode.importDemoOutcome.pagesChanged, 12)
        XCTAssertEqual(ScreenshotMode.importDemoOutcome.strokesAdded, 348)
        XCTAssertEqual(ScreenshotMode.importDemoOutcome.pagesSeen, 12)
        XCTAssertEqual(WebImportSheet.resultText(ScreenshotMode.importDemoOutcome), "Web 版の手書きを取り込みました（12 ページ・348 本）")
    }
}
