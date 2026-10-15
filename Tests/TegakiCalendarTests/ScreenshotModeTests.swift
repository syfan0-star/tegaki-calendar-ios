import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// Screenshot mode (M3a contract §8.3, M3b §6.3, M4 §8.3, M4B §7.3): the launch arguments, the fixed
/// 「今日」, the demo page of every page kind, the M3b sheets (`--screenshot-sheet`) with their demo
/// calendars, the M4 sheets (`sync`, `import`) with the demo sync values, and M4b's
/// `--screenshot-landscape`, the Sunday week of `--screenshot-month 2026-06` and the demo strokes
/// that already sit on the grid.
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
        // M4b: the week / day paper has no band any more; every stroke is on the grid.
        let week = ScreenshotMode.demoPage(kind: .week, focus: focus)
        XCTAssertEqual(Set(week.liveStrokes.map { $0.cell.raw }), ["grid"])
        let day = ScreenshotMode.demoPage(kind: .day, focus: focus)
        XCTAssertEqual(Set(day.liveStrokes.map { $0.cell.raw }), ["grid"])
        // The day page's strokes lie in the memo column (x ≥ 660).
        for stroke in day.liveStrokes where stroke.cell.isGrid {
            XCTAssertTrue(stroke.points.allSatisfy { $0.x >= PaperSpec.dayTimelineRight })
        }
        let year = ScreenshotMode.demoPage(kind: .year, focus: focus)
        XCTAssertEqual(Set(year.liveStrokes.map { $0.cell.raw }), ["10-07", "02-30"])
    }

    // MARK: M4b (M4B contract §2.7, §6.4, §7.3)

    /// The demo strokes already sit where `BandMigration` would put the M3a–M4 band strokes: the
    /// week wave at the top of the Wednesday column, the day circle at the top of the memo column.
    func testDemoPagesNeedNoMigration() {
        let focus = DayKey(year: 2026, month: 10, day: 7)
        for kind in PageKind.allCases {
            let page = ScreenshotMode.demoPage(kind: kind, focus: focus)
            XCTAssertFalse(BandMigration.needsMigration(page), "\(kind)")
            XCTAssertEqual(BandMigration.migrate(page), page, "\(kind)")
        }
        let week = ScreenshotMode.demoPage(kind: .week, focus: focus)
        let wave = week.strokes["demo-stroke-week-wave"]
        XCTAssertEqual(wave?.cell, .grid)
        // x from 12 + 64 + 2 × 190.857… = 457.71…, y 40 ± 5 (just under 0:00 of the Wednesday).
        XCTAssertEqual(wave?.points.first?.x ?? 0, 12 + PaperSpec.weekGutter + 2 * PaperSpec.weekColumnWidth, accuracy: 0.11)
        XCTAssertEqual(wave?.points.first?.y ?? 0, 40, accuracy: 0.11)
        XCTAssertTrue(wave?.points.allSatisfy { abs($0.y - 40) <= 5.1 } ?? false)
        let day = ScreenshotMode.demoPage(kind: .day, focus: focus)
        let circle = day.strokes["demo-stroke-day-circle"]
        XCTAssertEqual(circle?.cell, .grid)
        XCTAssertEqual(circle?.points.first?.x ?? 0, 814, accuracy: 0.11)   // (800, 30), radius 14
        XCTAssertEqual(circle?.points.first?.y ?? 0, 30, accuracy: 0.11)
    }

    func testParseLandscape() {
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week"]
        let portrait = ScreenshotMode.parse(base)
        let landscape = ScreenshotMode.parse(base + ["--screenshot-landscape"])
        XCTAssertEqual(portrait?.landscape, false)
        XCTAssertEqual(landscape?.landscape, true)
        // Everything else is unchanged by the flag.
        XCTAssertEqual(landscape?.page, portrait?.page)
        XCTAssertEqual(landscape?.month, portrait?.month)
        XCTAssertEqual(landscape?.today, portrait?.today)
        XCTAssertEqual(landscape?.focus, portrait?.focus)
        XCTAssertEqual(landscape?.sheet, portrait?.sheet)
        XCTAssertEqual(landscape?.page, .week)
        XCTAssertEqual(landscape?.month, october)
        // The flag alone, and with a sheet.
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-landscape"])?.landscape, true)
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-mode"])?.landscape, false)
        let sheet = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "edit", "--screenshot-landscape"])
        XCTAssertEqual(sheet?.landscape, true)
        XCTAssertEqual(sheet?.sheet, .edit)
        XCTAssertEqual(sheet?.page, .month)
        // Without `--screenshot-mode` the flag means nothing.
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-landscape"]))
    }

    /// `--screenshot-month 2026-06` (the CI's `iphone-portrait-week-sun.png`, M4B contract §6.3):
    /// the focus is the 7th, a Sunday, so today's column is the last one of the week.
    func testJuneFocusIsASunday() throws {
        let config = try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-06", "--screenshot-page", "week"]))
        XCTAssertEqual(config.focus, DayKey(year: 2026, month: 6, day: 7))
        XCTAssertEqual(config.focus.weekday, 0, "Sunday")
        XCTAssertEqual(DayKey(config.today), DayKey(year: 2026, month: 6, day: 7))
        XCTAssertEqual(DayKey(config.today).weekday, 0)
        let expected = DayKey(year: 2026, month: 6, day: 7).startOfDay().addingTimeInterval(10 * 3600)
        XCTAssertEqual(config.today, expected)
        XCTAssertEqual(config.page, .week)
        XCTAssertEqual(PageNavigation.pageId(config.page, focus: config.focus), "w-2026-06-01")
        // The week's demo band (the month's all-day events overlapping 6/1〜6/7): 運動会 on the 3rd,
        // キャンプ on the 4th–5th and 締切 on the 7th, one lane; 家族旅行 starts on the 9th.
        let events = ScreenshotMode.demoEvents(for: YearMonth(year: 2026, month: 6))
        let band = AllDayBandEngine.week(monday: DayKey(year: 2026, month: 6, day: 1), events: events, now: config.today)
        XCTAssertEqual(band.todayColumn, 6)
        XCTAssertEqual(band.bars.map { $0.title }, ["運動会", "キャンプ", "締切"])
        XCTAssertEqual(band.laneCount, 1)
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
