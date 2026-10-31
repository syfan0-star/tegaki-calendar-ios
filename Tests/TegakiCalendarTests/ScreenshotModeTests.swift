import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// Screenshot mode (M3a contract §8.3, M3b §6.3, M4 §8.3, M4B §7.3, M4C §7.3): the launch arguments,
/// the fixed 「今日」, the demo page of every page kind, the M3b sheets (`--screenshot-sheet`) with
/// their demo calendars, the M4 sheets (`sync`, `import`) with the demo sync values, M4b's
/// `--screenshot-landscape`, the Sunday week of `--screenshot-month 2026-06` and the demo strokes
/// that already sit on the grid, M4c's `--screenshot-zoom` / `--screenshot-offset`, M5's `paywall` and
/// `--screenshot-readonly`, and M6's `export` sheet (M6_CONTRACT §3.5 / §7.2). 1.1 (M7A_CONTRACT §7.2 /
/// §7.3): `--screenshot-toolbar`, `--screenshot-tool`, `--screenshot-grown`, the `info` sheet with its
/// demo counts, and the demo pages as JSON fixtures that the 1.0 copy reads (0-23).
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

    // MARK: M4c (M4C contract §2.4, §5.3, §7.3)

    /// `--screenshot-zoom <ratio>` (a finite positive number, else 1) and `--screenshot-offset x,y`
    /// (two finite numbers, else nil); nothing else changes, and a sheet keeps them.
    func testParseZoomAndOffset() {
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month"]
        let plain = ScreenshotMode.parse(base)
        XCTAssertEqual(plain?.zoomRatio, 1, "no argument → the overview")
        XCTAssertNil(plain?.offset)

        let zoomed = ScreenshotMode.parse(base + ["--screenshot-zoom", "2", "--screenshot-offset", "400,200"])
        XCTAssertEqual(zoomed?.zoomRatio, 2)
        XCTAssertEqual(zoomed?.offset, CGPoint(x: 400, y: 200))
        // Everything else is unchanged by the two arguments.
        XCTAssertEqual(zoomed?.page, plain?.page)
        XCTAssertEqual(zoomed?.month, plain?.month)
        XCTAssertEqual(zoomed?.today, plain?.today)
        XCTAssertEqual(zoomed?.focus, plain?.focus)
        XCTAssertEqual(zoomed?.sheet, plain?.sheet)
        XCTAssertEqual(zoomed?.landscape, plain?.landscape)
        XCTAssertEqual(zoomed?.page, .month)
        XCTAssertEqual(zoomed?.month, october)

        // The zoom: decimals are read; a value that is not a finite positive number is 1.
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-zoom", "1.5"])?.zoomRatio ?? 0, 1.5, accuracy: 1e-9)
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-zoom", "3"])?.zoomRatio, 3)
        for bad in ["abc", "0", "-1", "inf", "nan", ""] {
            XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-zoom", bad])?.zoomRatio, 1, "zoom \(bad)")
        }
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-zoom"])?.zoomRatio, 1, "no value")
        XCTAssertEqual(ScreenshotMode.parseZoomRatio("2"), 2)
        XCTAssertNil(ScreenshotMode.parseZoomRatio("inf"))
        XCTAssertNil(ScreenshotMode.parseZoomRatio("0"))

        // The offset: exactly two finite numbers joined by a comma.
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-offset", "300,700"])?.offset, CGPoint(x: 300, y: 700))
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-offset", "0,0"])?.offset, CGPoint(x: 0, y: 0))
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-offset", "12.5,-3"])?.offset, CGPoint(x: 12.5, y: -3))
        for bad in ["400", "a,b", "1,2,3", "1,", ",2", "inf,2", "1,nan", ""] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-offset", bad])?.offset, "offset \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-offset"])?.offset, "no value")
        XCTAssertEqual(ScreenshotMode.parseOffset("400,200"), CGPoint(x: 400, y: 200))
        XCTAssertNil(ScreenshotMode.parseOffset("400"))

        // With a sheet the values stay (they act on the month page the sheet sits on).
        let sheet = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "edit", "--screenshot-zoom", "2", "--screenshot-offset", "400,200"])
        XCTAssertEqual(sheet?.zoomRatio, 2)
        XCTAssertEqual(sheet?.offset, CGPoint(x: 400, y: 200))
        XCTAssertEqual(sheet?.sheet, .edit)
        XCTAssertEqual(sheet?.page, .month)
        // The CI's week / year photos (M4C contract §2.4).
        let week = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-zoom", "3", "--screenshot-offset", "300,700"])
        XCTAssertEqual(week?.page, .week)
        XCTAssertEqual(week?.zoomRatio, 3)
        XCTAssertEqual(week?.offset, CGPoint(x: 300, y: 700))
        // Without `--screenshot-mode` the arguments mean nothing.
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-zoom", "2", "--screenshot-offset", "400,200"]))
        // The defaults of the fields themselves.
        let config = ScreenshotMode.Config(page: .week, month: october, today: Date(), focus: DayKey(year: 2026, month: 10, day: 7), sheet: nil)
        XCTAssertEqual(config.zoomRatio, 1)
        XCTAssertNil(config.offset)
        XCTAssertFalse(config.landscape)
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
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "bogus"])?.sheet)
        // M6 contract §3.5 / §7.2: `export` is a sheet now (the choice state over the month page).
        let export = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-sheet", "export"])
        XCTAssertEqual(export?.sheet, .export)
        XCTAssertEqual(export?.page, .month)
        XCTAssertEqual(export?.month, october)
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "Export"])?.sheet)
        // M5 contract §7.5: `paywall` is the seventh sheet; M6 contract §3.5: `export` the eighth;
        // 1.1 (M7A_CONTRACT §7.3): `info` the ninth.
        XCTAssertEqual(ScreenshotMode.Sheet.allCases.count, 9)
        XCTAssertEqual(ScreenshotMode.Sheet.allCases.map { $0.rawValue }, ["create", "edit", "lasso", "settings", "sync", "import", "paywall", "export", "info"])
    }

    // MARK: M5 (M5_CONTRACT §7.5, §7.6)

    /// `--screenshot-readonly`: false without the flag, true with it, nothing else changes; it combines
    /// with `--screenshot-sheet paywall` (the month page, `.paywall`, read only), and the paywall sheet
    /// alone is not read only.
    func testParseReadOnly() {
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month"]
        let plain = ScreenshotMode.parse(base)
        let readOnly = ScreenshotMode.parse(base + ["--screenshot-readonly"])
        XCTAssertEqual(plain?.readOnly, false)
        XCTAssertEqual(readOnly?.readOnly, true)
        XCTAssertEqual(readOnly?.page, plain?.page)
        XCTAssertEqual(readOnly?.month, plain?.month)
        XCTAssertEqual(readOnly?.today, plain?.today)
        XCTAssertEqual(readOnly?.focus, plain?.focus)
        XCTAssertEqual(readOnly?.sheet, plain?.sheet)
        XCTAssertNil(readOnly?.sheet)
        XCTAssertEqual(readOnly?.landscape, plain?.landscape)
        XCTAssertEqual(readOnly?.zoomRatio, plain?.zoomRatio)
        XCTAssertEqual(readOnly?.offset, plain?.offset)
        XCTAssertEqual(readOnly?.page, .month)
        XCTAssertEqual(readOnly?.month, october)

        let both = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "paywall", "--screenshot-readonly"])
        XCTAssertEqual(both?.page, .month)
        XCTAssertEqual(both?.sheet, .paywall)
        XCTAssertEqual(both?.readOnly, true)
        let paywall = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "paywall"])
        XCTAssertEqual(paywall?.sheet, .paywall)
        XCTAssertEqual(paywall?.page, .month)
        XCTAssertEqual(paywall?.readOnly, false)
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", "paywall"])?.month, october)

        // The CI's photos (§7.5): the 11-inch day page and the iPhone's week page, read only.
        let day = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "day", "--screenshot-readonly"])
        XCTAssertEqual(day?.page, .day)
        XCTAssertEqual(day?.readOnly, true)
        XCTAssertEqual(day?.focus, DayKey(year: 2026, month: 10, day: 7))
        let week = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-readonly"])
        XCTAssertEqual(week?.page, .week)
        XCTAssertEqual(week?.readOnly, true)
        // With the other flags.
        let all = ScreenshotMode.parse(base + ["--screenshot-landscape", "--screenshot-zoom", "2", "--screenshot-offset", "400,200", "--screenshot-readonly"])
        XCTAssertEqual(all?.readOnly, true)
        XCTAssertEqual(all?.landscape, true)
        XCTAssertEqual(all?.zoomRatio, 2)
        XCTAssertEqual(all?.offset, CGPoint(x: 400, y: 200))
        // Without `--screenshot-mode` the flag means nothing.
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-readonly"]))
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-sheet", "paywall", "--screenshot-readonly"]))
        // The field's default.
        let config = ScreenshotMode.Config(page: .week, month: october, today: Date(), focus: DayKey(year: 2026, month: 10, day: 7), sheet: nil)
        XCTAssertFalse(config.readOnly)
    }

    // MARK: 1.1 (M7A_CONTRACT §7.2, §7.3)

    /// `--screenshot-toolbar collapsed|collapsed-right`, `--screenshot-tool eraser|marker|lasso|event`
    /// (unknown values → nil; the `lasso` sheet wins), `--screenshot-grown`, and the `info` sheet.
    func testParseToolbarToolAndGrown() {
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month"]
        let plain = ScreenshotMode.parse(base)
        XCTAssertNil(plain?.toolbar)
        XCTAssertNil(plain?.tool)
        XCTAssertEqual(plain?.grown, false)

        // The toolbar.
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-toolbar", "collapsed"])?.toolbar, .collapsed)
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-toolbar", "collapsed-right"])?.toolbar, .collapsedRight)
        for bad in ["expanded", "peek", "Collapsed", "collapsedRight", "right", ""] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-toolbar", bad])?.toolbar, "toolbar \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-toolbar"])?.toolbar, "no value")
        XCTAssertEqual(ScreenshotMode.ToolbarShot.collapsed.mode, .collapsed)
        XCTAssertEqual(ScreenshotMode.ToolbarShot.collapsedRight.mode, .collapsed)
        XCTAssertEqual(ScreenshotMode.ToolbarShot.collapsed.edge, .leading)
        XCTAssertEqual(ScreenshotMode.ToolbarShot.collapsedRight.edge, .trailing)

        // The first tool.
        let tools: [(String, ScreenshotMode.ToolShot, CanvasTool)] = [
            ("eraser", .eraser, .eraser), ("marker", .marker, .ink(InkPresets.defaultMarker)),
            ("lasso", .lasso, .lasso), ("event", .event, .eventRect),
        ]
        for (name, shot, tool) in tools {
            let config = ScreenshotMode.parse(base + ["--screenshot-tool", name])
            XCTAssertEqual(config?.tool, shot, name)
            XCTAssertEqual(shot.canvasTool, tool, name)
            XCTAssertEqual(config.map(ScreenshotMode.startTool), tool, name)
            XCTAssertEqual(config?.page, .month, name)
            XCTAssertNil(config?.sheet, name)
        }
        XCTAssertEqual(ScreenshotMode.ToolShot.eraser.eraserOrigin, .toolbar, "the toolbar's eraser: its note shows the return")
        XCTAssertNil(ScreenshotMode.ToolShot.marker.eraserOrigin)
        for bad in ["pen", "Eraser", "eventRect", ""] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-tool", bad])?.tool, "tool \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-tool"])?.tool, "no value")
        XCTAssertEqual(plain.map(ScreenshotMode.startTool), .ink(ToolbarPalette.defaultPen), "the default pen (黒・中)")
        // The lasso sheet needs the lasso: it wins over the tool argument.
        let lassoSheet = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "lasso", "--screenshot-tool", "eraser"])
        XCTAssertEqual(lassoSheet?.sheet, .lasso)
        XCTAssertEqual(lassoSheet?.tool, .lasso)
        XCTAssertEqual(lassoSheet.map(ScreenshotMode.startTool), .lasso)
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "lasso"])?.tool, .lasso)
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "settings", "--screenshot-tool", "eraser"])?.tool, .eraser)

        // Grown.
        let grown = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "day", "--screenshot-grown", "--screenshot-offset", "0,9999"])
        XCTAssertEqual(grown?.grown, true)
        XCTAssertEqual(grown?.page, .day)
        XCTAssertEqual(grown?.offset, CGPoint(x: 0, y: 9999))
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-grown"]), "without `--screenshot-mode` nothing")

        // The CI's photos (§7.4): everything else is unchanged by the three arguments.
        let all = ScreenshotMode.parse(base + ["--screenshot-toolbar", "collapsed", "--screenshot-tool", "marker", "--screenshot-grown"])
        XCTAssertEqual(all?.toolbar, .collapsed)
        XCTAssertEqual(all?.tool, .marker)
        XCTAssertEqual(all?.grown, true)
        XCTAssertEqual(all?.page, plain?.page)
        XCTAssertEqual(all?.month, plain?.month)
        XCTAssertEqual(all?.today, plain?.today)
        XCTAssertEqual(all?.focus, plain?.focus)
        XCTAssertEqual(all?.sheet, plain?.sheet)
        XCTAssertEqual(all?.zoomRatio, plain?.zoomRatio)
        XCTAssertEqual(all?.offset, plain?.offset)
        XCTAssertEqual(all?.readOnly, plain?.readOnly)
        XCTAssertEqual(all?.landscape, plain?.landscape)

        // The `info` sheet sits on the month page like the others.
        let info = ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-sheet", "info"])
        XCTAssertEqual(info?.sheet, .info)
        XCTAssertEqual(info?.page, .month)
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-sheet", "Info"])?.sheet)

        // The fields' defaults.
        let config = ScreenshotMode.Config(page: .week, month: october, today: Date(), focus: DayKey(year: 2026, month: 10, day: 7), sheet: nil)
        XCTAssertNil(config.toolbar)
        XCTAssertNil(config.tool)
        XCTAssertFalse(config.grown)
    }

    /// `--screenshot-grown` adds one stroke deep in the month's memo area (bottom ≈ 1,009 → the memo
    /// area 1,500) and one in the day's free memo area (`extra`, → 1,100); without it the demo pages
    /// are those of 1.0.1 (the month's memo dot keeps the memo area at 700, the day has no `extra` ink).
    func testGrownDemoPages() {
        let focus = DayKey(year: 2026, month: 10, day: 7)
        let now = ScreenshotMode.todayInstant(for: october)
        // The usual pages: unchanged, and the default follows the (absent) `--screenshot-grown`.
        for kind in PageKind.allCases {
            XCTAssertEqual(ScreenshotMode.demoPage(kind: kind, focus: focus), ScreenshotMode.demoPage(kind: kind, focus: focus, grown: false), "\(kind)")
        }
        XCTAssertEqual(ScreenshotMode.demoPage(for: october), ScreenshotMode.demoPage(kind: .month, focus: focus))
        let month = ScreenshotMode.demoPage(kind: .month, focus: focus)
        XCTAssertEqual(month.liveStrokeIds, ["demo-stroke-dot", "demo-stroke-marker", "demo-stroke-wave"])
        XCTAssertEqual(month.inkBottoms()[.memo] ?? 0, 64.5, accuracy: 0.001)
        let monthLayout = MonthLayoutEngine.layout(MonthLayoutInput(month: october, events: ScreenshotMode.demoEvents(for: october), inkBottoms: month.inkBottoms(), now: now))
        XCTAssertEqual(monthLayout.memo.height, 700, "the month paper of the photos is that of 1.0.1 (0-1)")
        let day = ScreenshotMode.demoPage(kind: .day, focus: focus)
        XCTAssertEqual(day.liveStrokeIds, ["demo-stroke-day-circle", "demo-stroke-day-wave1", "demo-stroke-day-wave2"])
        XCTAssertNil(day.inkBottoms()[.extra])
        let dayLayout = DayLayoutEngine.layout(DayLayoutInput(day: focus, events: ScreenshotMode.demoEvents(for: october), inkBottoms: day.inkBottoms(), now: now))
        XCTAssertEqual(dayLayout.extra.height, 700)

        // The grown month: the three strokes as before and the red wave in the memo area.
        let grownMonth = ScreenshotMode.demoPage(kind: .month, focus: focus, grown: true)
        XCTAssertEqual(ScreenshotMode.demoPage(for: october, grown: true), grownMonth)
        XCTAssertEqual(grownMonth.liveStrokeIds, ["demo-stroke-dot", "demo-stroke-marker", "demo-stroke-memo-deep", "demo-stroke-wave"])
        let deep = grownMonth.strokes[ScreenshotMode.grownMemoStrokeId]
        XCTAssertEqual(ScreenshotMode.grownMemoStrokeId, "demo-stroke-memo-deep")
        XCTAssertEqual(deep?.cell, .memo)
        XCTAssertEqual(deep?.tool, .pen)
        XCTAssertEqual(deep?.color, "#dc2626")
        XCTAssertEqual(deep?.points.count, 40)
        XCTAssertEqual(deep?.points.first?.x, 60)
        XCTAssertEqual(deep?.points.first?.y, 1_000)
        for (id, stroke) in month.strokes {
            XCTAssertEqual(grownMonth.strokes[id], stroke, id)
        }
        let memoBottom = grownMonth.inkBottoms()[.memo] ?? 0
        XCTAssertEqual(memoBottom, 1_009, accuracy: 0.5)
        XCTAssertEqual(MonthLayoutEngine.memoHeight(inkBottom: memoBottom), 1_500)
        let grownMonthLayout = MonthLayoutEngine.layout(MonthLayoutInput(month: october, events: ScreenshotMode.demoEvents(for: october), inkBottoms: grownMonth.inkBottoms(), now: now))
        XCTAssertEqual(grownMonthLayout.memo.height, 1_500)
        XCTAssertEqual(grownMonthLayout.memo.minY, monthLayout.memo.minY, "the rows do not move")
        XCTAssertEqual(grownMonthLayout.size.height, monthLayout.size.height + 800)

        // The grown day: the three strokes as before and the black wave in `extra`.
        let grownDay = ScreenshotMode.demoPage(kind: .day, focus: focus, grown: true)
        XCTAssertEqual(grownDay.liveStrokeIds, ["demo-stroke-day-circle", "demo-stroke-day-extra", "demo-stroke-day-wave1", "demo-stroke-day-wave2"])
        let extra = grownDay.strokes[ScreenshotMode.grownDayStrokeId]
        XCTAssertEqual(ScreenshotMode.grownDayStrokeId, "demo-stroke-day-extra")
        XCTAssertEqual(extra?.cell, .extra)
        XCTAssertEqual(extra?.color, "#1f2937")
        XCTAssertEqual(extra?.points.first?.x, 30)
        XCTAssertEqual(extra?.points.first?.y, 300)
        for (id, stroke) in day.strokes {
            XCTAssertEqual(grownDay.strokes[id], stroke, id)
        }
        let extraBottom = grownDay.inkBottoms()[.extra] ?? 0
        XCTAssertEqual(extraBottom, 309, accuracy: 0.5)
        let grownDayLayout = DayLayoutEngine.layout(DayLayoutInput(day: focus, events: ScreenshotMode.demoEvents(for: october), inkBottoms: grownDay.inkBottoms(), now: now))
        XCTAssertEqual(grownDayLayout.extra, CGRect(x: 0, y: 2_400, width: 1_000, height: 1_100))
        XCTAssertEqual(grownDayLayout.size.height, 3_500)
        XCTAssertEqual(grownDayLayout.grid, dayLayout.grid, "the 24-hour grid does not move (K-4)")
        // The stroke's centre lies below 24:00, so the canvas would file it under `extra` too.
        let centreY = 2_400 + ((extra?.points.map { $0.y }.min() ?? 0) + (extra?.points.map { $0.y }.max() ?? 0)) / 2
        XCTAssertEqual(grownDayLayout.inkCell(forCenter: CGPoint(x: 150, y: centreY)), .extra)

        // The other kinds do not grow; no page needs a band migration (K-1).
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .week, focus: focus, grown: true), ScreenshotMode.demoPage(kind: .week, focus: focus))
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .year, focus: focus, grown: true), ScreenshotMode.demoPage(kind: .year, focus: focus))
        for page in [grownMonth, grownDay] {
            XCTAssertFalse(BandMigration.needsMigration(page), page.pageId)
            XCTAssertFalse(page.liveStrokes.contains { BandMigration.isBandCell($0.cell) }, page.pageId)
        }
    }

    /// The `info` sheet (§7.3): `StrokeCensus.demo(year:)` counts the four demo pages — the largest is
    /// the day page (3 strokes, a tie with the month page, whose pageId is larger), and this year's
    /// year page has 2 strokes (the n of 「年のページ（2026年）・n 本」 in the photo).
    func testInfoSheetDemoCounts() {
        let demo = StrokeCensus.demo(year: 2026)
        XCTAssertEqual(demo.largest, StrokeBudget.Entry(pageId: "d-2026-10-07", strokes: 3, tombstones: 0))
        XCTAssertEqual(demo.year, StrokeBudget.Entry(pageId: "y-2026", strokes: 2, tombstones: 0))
        XCTAssertEqual(demo.unreadable, 0)
        XCTAssertEqual(StrokeCensus.rowText(demo.largest, counting: false), "日のページ（2026年10月7日）・3 本")
        XCTAssertEqual(StrokeCensus.yearRowText(demo.year, year: 2026, counting: false), "年のページ（2026年）・2 本")
        // The same pages the screen shows.
        let focus = DayKey(year: 2026, month: 10, day: 7)
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .month, focus: focus).budgetCount, 3)
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .week, focus: focus).budgetCount, 2)
        XCTAssertEqual(ScreenshotMode.demoPage(kind: .year, focus: focus).budgetCount, 2)
    }

    /// The demo pages as the JSON a stored page is (`InkPageCodec.encode`), compared byte for byte
    /// with `TegakiKit/Tests/Fixtures/compat11/screenshot-*.json`, which the 1.0 copy reads in K's
    /// compat checks (M7A_CONTRACT §1.4, 0-23: only this test makes them). A missing or different file
    /// is a failure; the JSON is then written to `$TEGAKI_FIXTURE_OUT` (the CI's `shots/fixtures/`),
    /// from where the lead reads it and commits it. Never write the fixtures by hand.
    func testDemoPagesMatchCompatFixtures() throws {
        let focus = DayKey(year: 2026, month: 10, day: 7)
        let pages: [(name: String, page: InkPage)] = [
            ("screenshot-day", ScreenshotMode.demoPage(kind: .day, focus: focus, grown: false)),
            ("screenshot-week", ScreenshotMode.demoPage(kind: .week, focus: focus, grown: false)),
            ("screenshot-month", ScreenshotMode.demoPage(kind: .month, focus: focus, grown: false)),
            ("screenshot-year", ScreenshotMode.demoPage(kind: .year, focus: focus, grown: false)),
            ("screenshot-month-grown", ScreenshotMode.demoPage(kind: .month, focus: focus, grown: true)),
            ("screenshot-day-grown", ScreenshotMode.demoPage(kind: .day, focus: focus, grown: true)),
        ]
        let repository = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = repository.appendingPathComponent("TegakiKit/Tests/Fixtures/compat11", isDirectory: true)
        let outPath = ProcessInfo.processInfo.environment["TEGAKI_FIXTURE_OUT"] ?? ""
        let out = outPath.isEmpty ? nil : URL(fileURLWithPath: outPath, isDirectory: true)

        var problems: [String] = []
        for (name, page) in pages {
            // What the fixture must be (K-1, K-5): known cells only, no band cell, nothing unknown, and
            // the JSON reads back to the same page.
            XCTAssertTrue(page.unknown.isEmpty, name)
            XCTAssertTrue(page.unknownStrokes.isEmpty, name)
            XCTAssertTrue(page.deleted.isEmpty, name)
            XCTAssertFalse(page.liveStrokes.contains { BandMigration.isBandCell($0.cell) || $0.cell.raw.hasPrefix("allday") }, name)
            let json = try InkPageCodec.encode(page)
            XCTAssertEqual(try InkPageCodec.decode(json), page, name)

            let file = folder.appendingPathComponent("\(name).json", isDirectory: false)
            let stored = try? Data(contentsOf: file)
            if stored == json { continue }
            problems.append(stored == nil ? "\(name).json is missing" : "\(name).json differs")
            if let out = out {
                try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
                try json.write(to: out.appendingPathComponent("\(name).json", isDirectory: false), options: [.atomic])
            }
        }
        let where_ = out.map { "written to \($0.path)" } ?? "set TEGAKI_FIXTURE_OUT to have them written"
        XCTAssertTrue(problems.isEmpty, "\(problems.joined(separator: ", ")) in \(folder.path) (\(where_))")
        // The cells each page carries (what K's checks expect the 1.0 copy to draw or keep).
        let cells = Dictionary(uniqueKeysWithValues: pages.map { ($0.name, Set($0.page.liveStrokes.map { $0.cell.raw })) })
        XCTAssertEqual(cells["screenshot-day"], ["grid"])
        XCTAssertEqual(cells["screenshot-day-grown"], ["grid", "extra"])
        XCTAssertEqual(cells["screenshot-week"], ["grid"])
        XCTAssertEqual(cells["screenshot-month"], ["2026-10-14", "2026-10-20", "memo"])
        XCTAssertEqual(cells["screenshot-month-grown"], ["2026-10-14", "2026-10-20", "memo"])
        XCTAssertEqual(cells["screenshot-year"], ["10-07", "02-30"])
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
