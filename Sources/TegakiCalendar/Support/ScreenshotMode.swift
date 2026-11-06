import Foundation
import Holidays
import InkModel
import Layout

/// Screenshot mode for CI (docs/M2.md §2.1, M3a contract §7, M3b contract §5): the app launched with
/// `--screenshot-mode` skips the onboarding, never asks EventKit for anything, shows deterministic
/// demo events for the month given by `--screenshot-month YYYY-MM` (default: the current month) on
/// the page given by `--screenshot-page day|week|month|year` (default: month), treats a fixed instant
/// as 「今日」, and preloads a few ink strokes in memory (nothing is saved). With
/// `--screenshot-sheet create|edit|lasso|settings|sync|import` the month page opens one of the M3b /
/// M4 sheets (the create / edit sheet, the lasso selection with its menu, the settings screen, the
/// settings screen with the demo sync engine, the finished web import) half a second after the
/// canvas appeared; writes are no-ops. The sync engine is `SyncEngine.screenshotDemo(now:)` (M4
/// contract §6.6): the header shows 「☁ 保存済み」 and nothing touches iCloud. Never active unless
/// `--screenshot-mode` is present.
/// Landscape (M4B contract §6.4): only an iPhone turns with `--screenshot-landscape`
/// (`UIWindowScene.requestGeometryUpdate`); an iPad cannot, because iPadOS ignores the request for
/// an app that supports multitasking (and simctl cannot rotate the device).
/// Zoom (M4C contract §2.4 / §5.3; 1.1.1): `--screenshot-zoom <ratio>` opens the page at that ratio to
/// its opening zoom (`ZoomPolicy.Bounds.open`; 1 = the opening zoom, clamped by the canvas, so 0.1 is the
/// whole page as a pinch to the minimum shows it) and `--screenshot-offset <x>,<y>` puts that paper
/// point (lu) at the top left, so the CI's photos share the canvas's zoom path.
/// Purchase (M5_CONTRACT §7.5): `--screenshot-sheet paywall` opens the purchase sheet on the month page
/// (trial-eligible sample); `--screenshot-readonly` starts the store as `.readOnly(.notSubscribed)` (badge, 20 s toast).
/// Export (M6_CONTRACT §3.5, 0-6): `--screenshot-sheet export` opens `ExportSheet` in its `.choose`
/// state on the month page (the two buttons and their notes; nothing is written).
/// 1.1 (M7A_CONTRACT §7.3): `--screenshot-toolbar collapsed|collapsed-right` starts with the toolbar
/// folded into the dock button (bottom left / right), `--screenshot-tool eraser|marker|lasso|event`
/// starts with that tool (the eraser as the toolbar's, so its note shows the return to the pen),
/// `--screenshot-grown` adds two strokes that grow the month's memo area and the day's free memo
/// area below 24:00, and `--screenshot-sheet info` opens the settings at 「情報」 (the stroke counts of
/// `StrokeCensus.demo(year:)`). The toolbar, eraser and notice memories are never read or written.
/// 1.1 fix (the UI tests of the eraser and of the free memo area, `EraserAndBelowDayUITests`): two
/// arguments the CI's photos never pass, so the photos do not change. `--screenshot-probe` makes the
/// canvas an accessibility element 「ink-canvas」 whose value reads out its zoom, offset, stroke counts,
/// tool and the last canvas events (`InkCanvasView.Coordinator.probeValue()`), and keeps every toast
/// for 20 s (`probeToastDuration`, so a slow simulator cannot miss it); `--screenshot-select <ids>`
/// starts with the lasso and these strokes selected (any page; the `lasso` sheet does the same for
/// the month's wave).
/// 1.1.1 (docs/R1_1_1.md): `--screenshot-empty` opens the paper with no demo events and no demo ink, for
/// `BlankPaperShotsUITests` (the `blank-paper` job of build.yml). The CI's other photos never pass it.
/// `--screenshot-tall-year` (same job) writes a line in every row of January on the year page, so its
/// paper is about 2,600 lu (`tallYearDemoPage`): a year that grew, before and after the fix.
/// `--screenshot-pinch-hint` shows the one-time pinch hint half a second after the canvas appeared, for
/// the photos of the hint (normal use decides with `CalendarRootScreen.pinchHintDue`, never here).
/// 1.2 (docs/M7B_CONTRACT.md §7.4, §10.7): `--screenshot-holidays auto|none|<国>[-<州>]` picks the holidays
/// (without it, or with a broken value, Japan's, whatever the simulator's region is, 0-26),
/// `--screenshot-week-start auto|monday|sunday` the week start (without it, or with a broken value, Monday,
/// 0-46), `--screenshot-sheet holidays` opens the picker of the holidays in the settings, and
/// `--screenshot-sheet week-start` the settings with the question of switching the week start. The demo
/// events' and calendars' titles follow the language (`demo.*`); the demo ink never does (K-7). The
/// language is `-AppleLanguages` and `-AppleLocale` (the app's UserDefaults argument domain).
/// `--screenshot-store-ink` (docs/M7B.md, FIX4; only `store-shots.yml` passes it): the richer handwriting of
/// the App Store's photos (`ScreenshotStoreInk.swift`) and the 7th's call away from its meeting. Without
/// it the demo pages and events are what the fixtures and the Japanese photos have seen (K-7, J-4).
enum ScreenshotMode {
    /// The sheets a screenshot can show (`--screenshot-sheet`; M3b contract §5, M4 contract §6.6,
    /// M5 contract §7.5: `paywall`, M6 contract §3.5: `export`, 1.1 (M7A_CONTRACT §7.3): `info`,
    /// 1.2 (docs/M7B_CONTRACT.md §7.4, §10.7): `holidays`, `week-start`).
    enum Sheet: String, CaseIterable, Sendable {
        case create, edit, lasso, settings, sync, `import`, paywall, export, info, holidays
        case weekStart = "week-start"
    }

    /// `--screenshot-toolbar` (1.1, §7.3): the toolbar starts collapsed, its dock button in the bottom
    /// left (`collapsed`) or the bottom right (`collapsed-right`). nil (no value or an unknown one) =
    /// the expanded bar, as before.
    enum ToolbarShot: String, Equatable, Sendable, CaseIterable {
        case collapsed
        case collapsedRight = "collapsed-right"

        /// The state the screen starts in (`ToolbarMode.collapsed` for both).
        var mode: ToolbarMode { .collapsed }

        /// The corner of the dock button.
        var edge: ToolbarEdge {
            switch self {
            case .collapsed: return .leading
            case .collapsedRight: return .trailing
            }
        }
    }

    /// `--screenshot-tool` (1.1, §7.3): the tool the screen starts with. nil (no value or an unknown
    /// one) = the default pen. `--screenshot-sheet lasso` wins (it needs the lasso; `parse` then
    /// reports `.lasso` here).
    enum ToolShot: String, Equatable, Sendable, CaseIterable {
        case eraser, marker, lasso, event

        /// The canvas tool: the eraser, the default marker (黄), the lasso, the 予定 tool.
        var canvasTool: CanvasTool {
            switch self {
            case .eraser: return .eraser
            case .marker: return .ink(InkPresets.defaultMarker)
            case .lasso: return .lasso
            case .event: return .eventRect
            }
        }

        /// The eraser starts as the toolbar's (`EraserOrigin.toolbar`), so the toolbar's note shows
        /// 「（消すとペンに戻ります）」; nil for the other tools.
        var eraserOrigin: EraserOrigin? {
            self == .eraser ? .toolbar : nil
        }
    }

    /// The tool a screenshot starts with (§7.3): the lasso for the `lasso` sheet or a preselection
    /// (`--screenshot-select`), else `config.tool`'s, else the default pen (黒・中; the remembered pen
    /// is never read in screenshot mode).
    static func startTool(_ config: Config) -> CanvasTool {
        if config.sheet == .lasso || !config.select.isEmpty { return .lasso }
        return config.tool?.canvasTool ?? .ink(ToolbarPalette.defaultPen)
    }

    /// The strokes the canvas selects once its zoom is known: the month's wave for the `lasso` sheet,
    /// else `--screenshot-select`'s ids (unknown ids are ignored by the canvas); none in normal use.
    static func initialSelection(_ config: Config?) -> [String] {
        guard let config else { return [] }
        return config.sheet == .lasso ? [lassoDemoStrokeId] : config.select
    }

    struct Config: Equatable, Sendable {
        var page: PageKind
        var month: YearMonth
        /// The instant that counts as "now" (the 「今日」 mark), so a screenshot never depends on the clock.
        var today: Date
        /// The day the page opens on: the 7th of `month` (the week / day pages show that day).
        var focus: DayKey
        /// The sheet to open on the month page; nil = none (`--screenshot-page` then decides the page).
        var sheet: Sheet?
        /// `--screenshot-landscape`: the screen asks the window scene for landscape once it is active
        /// (M4B contract §6.4; an iPhone follows, an iPad does not).
        var landscape: Bool = false
        /// `--screenshot-zoom`: the ratio to the page's opening zoom the canvas opens at (M4C contract
        /// §5.3, 1.1.1). 1 unless the value is finite and positive; a ratio past `maxZoom` or below the
        /// minimum is clamped by the canvas (担当 P).
        var zoomRatio: CGFloat = 1
        /// `--screenshot-offset "x,y"`: the paper point (lu) shown at the top left; nil when the value
        /// is not two finite numbers (the canvas then uses its usual first position).
        var offset: CGPoint? = nil
        /// `--screenshot-readonly` (M5 contract §7.5): the store is
        /// `StoreModel.screenshotDemo(access: .readOnly(.notSubscribed))` (`CalendarRootScreen` passes
        /// this to `StoreModel.make(screenshotReadOnly:)`, M5-34). Combines with a sheet.
        var readOnly: Bool = false
        /// `--screenshot-toolbar` (1.1, §7.3): nil = the expanded bar.
        var toolbar: ToolbarShot? = nil
        /// `--screenshot-tool` (1.1, §7.3): nil = the default pen; `.lasso` with the `lasso` sheet.
        var tool: ToolShot? = nil
        /// `--screenshot-grown` (1.1, §7.3): the demo pages carry the two strokes that grow the memo
        /// area of the month and the free memo area of the day (`demoPage(kind:focus:grown:)`).
        var grown: Bool = false
        /// `--screenshot-probe` (the UI tests): the canvas reads out its state as an accessibility value
        /// and the toasts stay `probeToastDuration`. Never passed by the photos.
        var probe: Bool = false
        /// `--screenshot-select "id1,id2"` (the UI tests): the strokes selected with the lasso at the
        /// start (`initialSelection`); empty = none. The `lasso` sheet keeps its own stroke.
        var select: [String] = []
        /// `--screenshot-empty` (1.1.1, docs/R1_1_1.md): no demo events and no demo ink, the paper as it is on
        /// a month or a year nobody has written on yet.
        var empty: Bool = false
        /// `--screenshot-tall-year` (1.1.1, docs/R1_1_1.md): the year page with a line in every row of
        /// January (`tallYearDemoPage`), with or without `empty`.
        var tallYear: Bool = false
        /// `--screenshot-pinch-hint` (1.1.1, docs/R1_1_1.md): the one-time pinch hint, for its photos.
        var pinchHint: Bool = false
        /// `--screenshot-holidays` (1.2, §7.4): the only holiday setting screenshot mode knows (the
        /// memory is not read or written). Japan unless asked, whatever the simulator's region (0-26).
        var holidays: HolidaySetting = ScreenshotMode.japanHolidays
        /// `--screenshot-week-start` (1.2, §10.7): the only week start screenshot mode knows. Monday
        /// unless asked, whatever the simulator's region (0-46).
        var weekStart: WeekStart = .monday
        /// `--screenshot-store-ink` (docs/M7B.md, FIX4): the App Store's demo ink and events.
        var storeInk: Bool = false
    }

    /// Screenshot mode's holidays unless `--screenshot-holidays` says otherwise (0-26).
    static let japanHolidays: HolidaySetting = HolidayRegion(code: "JP").map(HolidaySetting.region) ?? .automatic

    /// How long a toast stays with `--screenshot-probe` (the read-only photo's 20 s, M5-24).
    static let probeToastDuration: TimeInterval = 20

    /// Parsed once from the launch arguments; nil in normal use.
    static let current: Config? = parse(ProcessInfo.processInfo.arguments)

    static var isActive: Bool { current != nil }

    static func parse(_ arguments: [String]) -> Config? {
        guard arguments.contains("--screenshot-mode") else { return nil }
        var month = YearMonth.current()
        if let index = arguments.firstIndex(of: "--screenshot-month"), index + 1 < arguments.count,
           let parsed = parseMonth(arguments[index + 1]) {
            month = parsed
        }
        var page = PageKind.month
        if let index = arguments.firstIndex(of: "--screenshot-page"), index + 1 < arguments.count,
           let parsed = PageKind(rawValue: arguments[index + 1]) {
            page = parsed
        }
        var sheet: Sheet?
        if let index = arguments.firstIndex(of: "--screenshot-sheet"), index + 1 < arguments.count {
            sheet = Sheet(rawValue: arguments[index + 1]) // an unknown value → no sheet
        }
        // A sheet always sits on the month page (M3b contract §5): it wins over `--screenshot-page`.
        if sheet != nil { page = .month }
        let landscape = arguments.contains("--screenshot-landscape")
        // M4c: the zoom ratio and the paper offset stay even with a sheet (they act on the month page).
        var zoomRatio: CGFloat = 1
        if let index = arguments.firstIndex(of: "--screenshot-zoom"), index + 1 < arguments.count,
           let parsed = parseZoomRatio(arguments[index + 1]) {
            zoomRatio = parsed
        }
        var offset: CGPoint?
        if let index = arguments.firstIndex(of: "--screenshot-offset"), index + 1 < arguments.count {
            offset = parseOffset(arguments[index + 1]) // an unreadable value → nil
        }
        // M5: the read-only sample (M5_CONTRACT §7.5).
        let readOnly = arguments.contains("--screenshot-readonly")
        // 1.1 (§7.3): the folded toolbar, the first tool, the grown demo pages. Unknown values → nil.
        var toolbar: ToolbarShot?
        if let index = arguments.firstIndex(of: "--screenshot-toolbar"), index + 1 < arguments.count {
            toolbar = ToolbarShot(rawValue: arguments[index + 1])
        }
        var tool: ToolShot?
        if let index = arguments.firstIndex(of: "--screenshot-tool"), index + 1 < arguments.count {
            tool = ToolShot(rawValue: arguments[index + 1])
        }
        // The UI tests' preselection: ids separated by commas (empty pieces dropped).
        var select: [String] = []
        if let index = arguments.firstIndex(of: "--screenshot-select"), index + 1 < arguments.count {
            select = arguments[index + 1].split(separator: ",").map(String.init)
        }
        // The lasso sheet and a preselection need the lasso (the selected strokes keep their frame): it wins.
        if sheet == .lasso || !select.isEmpty { tool = .lasso }
        let grown = arguments.contains("--screenshot-grown")
        let probe = arguments.contains("--screenshot-probe")
        let empty = arguments.contains("--screenshot-empty")
        let tallYear = arguments.contains("--screenshot-tall-year")
        let pinchHint = arguments.contains("--screenshot-pinch-hint")
        // 1.2 (§7.4, §10.7): a missing or broken value is Japan / Monday, not the simulator's region.
        var holidays = japanHolidays
        if let index = arguments.firstIndex(of: "--screenshot-holidays"), index + 1 < arguments.count {
            holidays = parseHolidays(arguments[index + 1]) ?? japanHolidays
        }
        var weekStart = WeekStart.monday
        if let index = arguments.firstIndex(of: "--screenshot-week-start"), index + 1 < arguments.count {
            weekStart = parseWeekStart(arguments[index + 1]) ?? .monday
        }
        let storeInk = arguments.contains("--screenshot-store-ink")
        return Config(page: page, month: month, today: todayInstant(for: month), focus: focusDay(for: month), sheet: sheet, landscape: landscape, zoomRatio: zoomRatio, offset: offset, readOnly: readOnly, toolbar: toolbar, tool: tool, grown: grown, probe: probe, select: select, empty: empty, tallYear: tallYear, pinchHint: pinchHint, holidays: holidays, weekStart: weekStart, storeInk: storeInk)
    }

    /// "auto", "none", "JP", "US-CA", "NZ-South Canterbury"; nil for anything else. (`HolidaySetting`
    /// itself reads a broken stored value as automatic; a broken argument is Japan here.)
    static func parseHolidays(_ text: String) -> HolidaySetting? {
        switch text {
        case "auto": return .automatic
        case "none": return HolidaySetting.none
        default: return HolidayRegion(code: text).map(HolidaySetting.region)
        }
    }

    /// "auto" (what the region gives, `WeekStartChoice`), "monday", "sunday"; nil for anything else.
    static func parseWeekStart(_ text: String) -> WeekStart? {
        WeekStartChoice.Setting(rawValue: text).map(WeekStartChoice.resolve)
    }

    /// "2" → 2; nil unless the text is a finite positive number ("abc", "0", "-1", "inf" are nil).
    static func parseZoomRatio(_ text: String) -> CGFloat? {
        guard let value = Double(text), value.isFinite, value > 0 else { return nil }
        return CGFloat(value)
    }

    /// "400,200" → (400, 200); nil unless the text is exactly two finite numbers joined by a comma
    /// ("400", "a,b" and "1,2,3" are nil).
    static func parseOffset(_ text: String) -> CGPoint? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]), x.isFinite, y.isFinite else { return nil }
        return CGPoint(x: x, y: y)
    }

    /// "2026-10" → 2026年10月; nil for anything else.
    static func parseMonth(_ text: String) -> YearMonth? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]),
              year >= 1, (1...12).contains(month) else { return nil }
        return YearMonth(year: year, month: month)
    }

    /// The 7th of the month (a Wednesday in 2026-10, so the 「今日」 column sits mid-week).
    static func focusDay(for month: YearMonth) -> DayKey {
        day(7, of: month)
    }

    /// 10:00 on the 7th of the month (a plain weekday in 2026-10, so the 「今日」 circle is visible).
    static func todayInstant(for month: YearMonth) -> Date {
        focusDay(for: month).startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600)
    }

    private static func day(_ d: Int, of month: YearMonth) -> DayKey {
        DayKey(year: month.year, month: month.month, day: min(d, DayKey.daysInMonth(year: month.year, month: month.month)))
    }

    // MARK: - Demo calendars and events

    struct DemoCalendar: Sendable {
        var id: String
        var title: String
        /// "#rrggbb", as `EventKitService.hexString` would produce for a calendar colour.
        var colorHex: String
    }

    /// The four demo calendars with their titles in `language` (the ids and the colours do not change).
    static func calendars(language: UILanguage) -> [DemoCalendar] {
        [
            DemoCalendar(id: "demo-work", title: L.text("demo.calendar.work", in: language), colorHex: "#4285f4"),
            DemoCalendar(id: "demo-family", title: L.text("demo.calendar.family", in: language), colorHex: "#33b679"),
            DemoCalendar(id: "demo-personal", title: L.text("demo.calendar.personal", in: language), colorHex: "#e67c73"),
            DemoCalendar(id: "demo-events", title: L.text("demo.calendar.events", in: language), colorHex: "#f6bf26"),
        ]
    }

    static func calendarTitle(forCalendarId id: String, language: UILanguage = L.language) -> String {
        calendars(language: language).first { $0.id == id }?.title ?? ""
    }

    /// The demo calendars as the settings screen and the sheets show them (M3b contract §5): all
    /// four writable, under the source 「見本」.
    static var calendarOptions: [CalendarOption] {
        calendarOptions(language: L.language)
    }

    /// `calendarOptions` in `language` (1.2, §7.4).
    static func calendarOptions(language: UILanguage) -> [CalendarOption] {
        calendars(language: language).map { demo in
            CalendarOption(
                id: demo.id,
                title: demo.title,
                colorHex: demo.colorHex,
                sourceTitle: L.text("demo.source", in: language),
                isWritable: true,
                isSubscribed: false,
                isBirthday: false
            )
        }
    }

    /// The stroke the `lasso` sheet selects: the wavy pen stroke in the cell of the 14th
    /// (`demoPage(for:)`), so the frame and the 「予定にする／削除／選択解除」 menu are visible.
    static let lassoDemoStrokeId = "demo-stroke-wave"

    /// The event the `edit` sheet opens: 家族旅行 (all-day, the 9th–13th, calendar 家族).
    static let editDemoEventId = "demo-3"

    /// The day the `create` sheet proposes (all-day) in `month`: the 14th.
    static func createDemoDay(for month: YearMonth) -> DayKey {
        day(14, of: month)
    }

    // MARK: - Demo sync (M4 contract §6.6)

    /// The 「最後に同期」 of the demo engine (`SyncEngine.screenshotDemo(now:)`): 3 minutes before
    /// `today` (10:00 on the 7th → 9:57), so the `sync` sheet shows a fixed 「保存済み」 time.
    static func demoLastSyncAt(for today: Date) -> Date {
        today.addingTimeInterval(-180)
    }

    /// What the `import` sheet shows as the finished import: 「Web 版の手書きを取り込みました（12 ページ・348 本）」.
    static let importDemoOutcome = ImportOutcome(pagesChanged: 12, strokesAdded: 348, pagesSeen: 12)

    /// The sample month (designed around 2026-10, whose 1st is a Thursday; day numbers are reused
    /// for any month): timed events on several days, five of them on the 20th (→ 2 chips + 「+3件」);
    /// all-day events including 家族旅行 over five days across a week boundary (9th–13th) and four
    /// all-day events on the 16th (that row grows to four lanes). M3a adds the 7th (「今日」): an all-day
    /// 締切 and three timed events, two of them overlapping (10:00–11:30 and 10:30–11:00) so the week
    /// and day pages show the two-column layout. Ids are fixed, so the layout is identical from run
    /// to run; the M3a events come last so the M2 ids do not move. `empty` (1.1.1; by default
    /// `--screenshot-empty` of the running screenshot mode, so false in normal use and in the tests): none.
    /// `language` (1.2, §7.4) only changes the titles; the events and their ids are the same.
    /// `storeInk` (docs/M7B.md, FIX4; by default `--screenshot-store-ink`, so false in normal use and in the
    /// tests) moves the 7th's call to 12:30: side by side with the meeting, the words of both were cut in
    /// the App Store's week photo. Everything else is the same, ids included.
    static func demoEvents(for month: YearMonth, empty: Bool = ScreenshotMode.current?.empty ?? false, language: UILanguage = L.language, storeInk: Bool = ScreenshotMode.current?.storeInk ?? false) -> [LayoutEvent] {
        if empty { return [] }
        let calendar = DayKey.deviceCalendar
        let demoCalendars = calendars(language: language)
        let work = 0, family = 1, personal = 2, events = 3
        var out: [LayoutEvent] = []

        func instant(_ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            day(d, of: month).startOfDay(in: calendar).addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
        }
        func timed(_ title: String, _ d: Int, _ hour: Int, _ minute: Int = 0, minutes: Int = 60, in cal: Int) {
            let start = instant(d, hour, minute)
            out.append(LayoutEvent(
                id: "demo-\(out.count + 1)",
                title: title,
                allDay: false,
                start: start,
                end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                colorHex: demoCalendars[cal].colorHex,
                calendarId: demoCalendars[cal].id
            ))
        }
        func allDay(_ title: String, _ d: Int, days: Int = 1, in cal: Int) {
            let first = day(d, of: month)
            out.append(LayoutEvent(
                id: "demo-\(out.count + 1)",
                title: title,
                allDay: true,
                start: first.startOfDay(in: calendar),
                end: first.adding(days: days).startOfDay(in: calendar), // exclusive next midnight
                colorHex: demoCalendars[cal].colorHex,
                calendarId: demoCalendars[cal].id
            ))
        }

        // All-day (M2)
        allDay(L.text("demo.event.sportsDay", in: language), 3, in: events)
        allDay(L.text("demo.event.camping", in: language), 4, days: 2, in: family)
        allDay(L.text("demo.event.familyTrip", in: language), 9, days: 5, in: family)
        allDay(L.text("demo.event.reportDeadline", in: language), 16, in: work)
        allDay(L.text("demo.event.checkup", in: language), 16, in: personal)
        allDay(L.text("demo.event.trashDay", in: language), 16, in: family)
        allDay(L.text("demo.event.birthday", in: language), 16, in: family)
        allDay(L.text("demo.event.businessTrip", in: language), 21, days: 2, in: work)
        allDay(L.text("demo.event.payday", in: language), 25, in: personal)

        // Timed (M2)
        timed(L.text("demo.event.dentist", in: language), 2, 10, in: personal)
        timed(L.text("demo.event.weeklyMeeting", in: language), 6, 10, in: work)
        timed(L.text("demo.event.report", in: language), 8, 15, minutes: 30, in: work)
        timed(L.text("demo.event.clinic", in: language), 9, 14, in: personal)
        timed(L.text("demo.event.weeklyMeeting", in: language), 13, 10, in: work)
        timed(L.text("demo.event.morningMeeting", in: language), 20, 9, minutes: 15, in: work)
        timed(L.text("demo.event.weeklyMeeting", in: language), 20, 10, in: work)
        timed(L.text("demo.event.oneOnOne", in: language), 20, 13, minutes: 30, in: work)
        timed(L.text("demo.event.review", in: language), 20, 15, in: work)
        timed(L.text("demo.event.farewell", in: language), 20, 18, minutes: 120, in: personal)
        timed(L.text("demo.event.drinks", in: language), 23, 19, minutes: 120, in: personal)
        timed(L.text("demo.event.weeklyMeeting", in: language), 27, 10, in: work)
        timed(L.text("demo.event.lunch", in: language), 28, 11, 30, minutes: 90, in: family)

        // The 7th, 「今日」 (M3a): the month row stays 175 high (28 + 25 + 3×20 + 40 = 153).
        allDay(L.text("demo.event.deadline", in: language), 7, in: personal)
        timed(L.text("demo.event.meeting", in: language), 7, 10, minutes: 90, in: work)
        if storeInk {
            timed(L.text("demo.event.call", in: language), 7, 12, 30, minutes: 30, in: personal)
        } else {
            timed(L.text("demo.event.call", in: language), 7, 10, 30, minutes: 30, in: personal)
        }
        timed(L.text("demo.event.dentalCheck", in: language), 7, 14, in: personal)

        return out
    }

    // MARK: - Demo ink

    /// A few strokes for the page `kind` opened on `focus` (contract §7), so PencilKit's rendering
    /// path and the cell anchoring of every page are exercised. Points are cell-relative lu, as in a
    /// stored page. `grown` (1.1, M7A_CONTRACT §7.3; by default `--screenshot-grown` of the running
    /// screenshot mode, so false in normal use and in the tests) adds one stroke deep in the month's
    /// memo area and one in the day's free memo area below 24:00; without it the pages are exactly
    /// those of 1.0.1 (the paper of the photos does not change). `empty` (1.1.1; likewise by default
    /// `--screenshot-empty`): the page with no strokes at all, whatever `grown` says. `tallYear` (1.1.1;
    /// likewise `--screenshot-tall-year`): the year page is `tallYearDemoPage`, whatever `empty` says.
    /// `weekStart` (1.2, §10.5): the week page's id and columns; **without it the paper and the page id
    /// would disagree and the ledger stops on `onPageMismatch`**. The default Monday is the page of the
    /// fixtures, byte for byte (K-7). No language: the demo ink is the same in every language.
    /// `storeInk` (docs/M7B.md, FIX4; likewise `--screenshot-store-ink`): the App Store's page
    /// (`storeInkPage`), whatever `grown` says; `tallYear` and `empty` win over it. Without it the pages are
    /// unchanged, bit for bit.
    static func demoPage(kind: PageKind, focus: DayKey, grown: Bool = ScreenshotMode.current?.grown ?? false,
                         empty: Bool = ScreenshotMode.current?.empty ?? false,
                         tallYear: Bool = ScreenshotMode.current?.tallYear ?? false,
                         weekStart: WeekStart = .monday,
                         storeInk: Bool = ScreenshotMode.current?.storeInk ?? false) -> InkPage {
        if tallYear, kind == .year { return tallYearDemoPage(focus: focus) }
        if empty { return InkPage.empty(pageId: PageNavigation.pageId(kind, focus: focus, weekStart: weekStart)) }
        if storeInk { return storeInkPage(kind: kind, focus: focus, weekStart: weekStart) }
        switch kind {
        case .month:
            return demoPage(for: YearMonth(year: focus.year, month: focus.month), grown: grown)
        case .week:
            return weekDemoPage(focus: focus, weekStart: weekStart)
        case .day:
            return dayDemoPage(focus: focus, grown: grown)
        case .year:
            return yearDemoPage(focus: focus)
        }
    }

    /// The id of the `grown` month stroke: a red wave deep in the memo area (its bottom ≈ 1,009 lu;
    /// the memo area is 6,000 lu high since 1.1.1, `PaperGrowth.tailHeight`, and its PDF 1,500 lu).
    static let grownMemoStrokeId = "demo-stroke-memo-deep"
    /// The id of the `grown` day stroke: a black wave in the free memo area below 24:00 (`extra`,
    /// its bottom ≈ 309 lu; the area is 6,000 lu high since 1.1.1, and its PDF 1,100 lu).
    static let grownDayStrokeId = "demo-stroke-day-extra"

    /// A fixed ms epoch; each stroke gets its own `t`.
    private static let baseTime = 1_760_000_000_000

    /// The month page with three strokes: a wavy pen stroke in the cell of the 14th, a marker line
    /// over the 「+3件」 chip of the 20th, and a dot in the memo area. `grown` adds a fourth, a red wave
    /// deep in the memo area (`grownMemoStrokeId`).
    static func demoPage(for month: YearMonth, grown: Bool = false) -> InkPage {
        var page = InkPage.empty(pageId: month.inkPageId)

        // 1. Pen, wavy, 36 points across the 14th (y ≈ 141…159, below the chip area of that row).
        page.add(InkStroke(id: "demo-stroke-wave", cell: .day(day(14, of: month)), tool: .pen, color: "#1f2937", t: baseTime,
                           points: wave(x0: 24, y0: 150, count: 36, step: 4.2, amplitude: 9)))

        // 2. Marker across the third chip (「+3件」) of the 20th: chips start at y 53 in a one-lane row.
        page.add(InkStroke(id: "demo-stroke-marker", cell: .day(day(20, of: month)), tool: .marker, color: "#fde047",
                           t: baseTime + 1_000, points: markerLine(x0: 28, y0: 103, count: 16, step: 9)))

        // 3. A dot (a tiny loop) in the memo area, red, 太 nib.
        page.add(InkStroke(id: "demo-stroke-dot", cell: .memo, tool: .pen, color: "#dc2626", t: baseTime + 2_000,
                           points: circle(cx: 80, cy: 60, radius: 1.5, count: 8, nib: 6)))

        // 4. `--screenshot-grown` (1.1): red, 40 points from (60, 1000), ±7 → bottom 1007 + 1.75.
        if grown {
            page.add(InkStroke(id: grownMemoStrokeId, cell: .memo, tool: .pen, color: "#dc2626", t: baseTime + 3_000,
                               points: wave(x0: 60, y0: 1_000, count: 40, step: 6.5, amplitude: 7)))
        }

        return page
    }

    /// Week: a wavy pen stroke on the grid at the top of the Wednesday column (y 40 ± 5, just under
    /// 0:00; the same place the M3a–M4 band stroke of that cell lands after `BandMigration`, so the
    /// demo needs no migration itself, M4B contract §2.7), a marker across the top of the 10:00
    /// 打合せ box of `focus` (the box starts at grid y 800 in that day's column). The columns follow
    /// `weekStart` (1.2): Wednesday is column 2 on a Monday week, column 3 on a Sunday week.
    private static func weekDemoPage(focus: DayKey, weekStart: WeekStart) -> InkPage {
        var page = InkPage.empty(pageId: PageNavigation.pageId(.week, focus: focus, weekStart: weekStart))
        let firstDay = weekStart.firstDay(of: focus)
        let wednesday = firstDay.adding(days: (3 - firstDay.weekday + 7) % 7)
        let wednesdayX = PaperSpec.weekGutter + CGFloat(weekStart.column(of: wednesday)) * PaperSpec.weekColumnWidth
        page.add(InkStroke(id: "demo-stroke-week-wave", cell: .grid, tool: .pen, color: "#1f2937", t: baseTime,
                           points: wave(x0: wednesdayX + 12, y0: 40, count: 30, step: 5.2, amplitude: 5)))
        let column = CGFloat(weekStart.column(of: focus))
        let columnX = PaperSpec.weekGutter + column * PaperSpec.weekColumnWidth
        let boxTop = 10 * PaperSpec.weekHourHeight + 10
        page.add(InkStroke(id: "demo-stroke-week-marker", cell: .grid, tool: .marker, color: "#fde047", t: baseTime + 1_000,
                           points: markerLine(x0: columnX + 12, y0: boxTop, count: 16, step: 10)))
        return page
    }

    /// Day: a pen circle at the top of the memo column (grid (800, 30): where the M3a–M4 band
    /// stroke lands after `BandMigration`, M4B contract §2.7) and two wavy pen lines lower in the
    /// memo area (x ≥ 660). `grown` adds a black wave in the free memo area below 24:00
    /// (`grownDayStrokeId`, cell `extra`).
    private static func dayDemoPage(focus: DayKey, grown: Bool) -> InkPage {
        var page = InkPage.empty(pageId: PageNavigation.pageId(.day, focus: focus))
        page.add(InkStroke(id: "demo-stroke-day-circle", cell: .grid, tool: .pen, color: "#2563eb", t: baseTime,
                           points: circle(cx: 800, cy: 30, radius: 14, count: 24, nib: 3.5)))
        let memoLeft = PaperSpec.dayTimelineRight + 30
        page.add(InkStroke(id: "demo-stroke-day-wave1", cell: .grid, tool: .pen, color: "#1f2937", t: baseTime + 1_000,
                           points: wave(x0: memoLeft, y0: 120, count: 40, step: 6.5, amplitude: 7)))
        page.add(InkStroke(id: "demo-stroke-day-wave2", cell: .grid, tool: .pen, color: "#1f2937", t: baseTime + 2_000,
                           points: wave(x0: memoLeft, y0: 180, count: 40, step: 6.5, amplitude: 7)))
        // `--screenshot-grown` (1.1): 40 points from (30, 300) of `extra` (paper y 2,700), ±7.
        if grown {
            page.add(InkStroke(id: grownDayStrokeId, cell: .extra, tool: .pen, color: "#1f2937", t: baseTime + 3_000,
                               points: wave(x0: 30, y0: 300, count: 40, step: 6.5, amplitude: 7)))
        }
        return page
    }

    /// Year: a red pen circle in the left 45 % of `focus`'s cell (around its weekday letter), and a
    /// short pen line in the cell of 2/30, which does not exist but can still be written on.
    private static func yearDemoPage(focus: DayKey) -> InkPage {
        var page = InkPage.empty(pageId: PageNavigation.pageId(.year, focus: focus))
        page.add(InkStroke(id: "demo-stroke-year-circle", cell: .yearDay(month: focus.month, day: focus.day), tool: .pen,
                           color: "#dc2626", t: baseTime, points: circle(cx: 14, cy: 13, radius: 11, count: 24, nib: 3.5)))
        page.add(InkStroke(id: "demo-stroke-year-line", cell: .yearDay(month: 2, day: 30), tool: .pen, color: "#1f2937",
                           t: baseTime + 1_000, points: wave(x0: 20, y0: 32, count: 14, step: 5, amplitude: 1.5)))
        return page
    }

    /// A year that grew, for the photos of its size (`--screenshot-tall-year`, docs/R1_1_1.md §2.2): the
    /// demo's year is only 2 % longer than an empty one. A line low in every row of January: bottom
    /// 68.6 + 1.5 + 1.75 = 71.85, so each row is 83.85 lu (`YearLayoutEngine.rowHeight`) and the paper
    /// about 2,600 lu.
    private static func tallYearDemoPage(focus: DayKey) -> InkPage {
        var page = InkPage.empty(pageId: PageNavigation.pageId(.year, focus: focus))
        for row in 1...PaperSpec.yearRows {
            page.add(InkStroke(id: "demo-stroke-tall-year-\(row)", cell: .yearDay(month: 1, day: row), tool: .pen, color: "#1f2937",
                               t: baseTime + row * 1_000, points: wave(x0: 20, y0: 68.6, count: 14, step: 5, amplitude: 1.5)))
        }
        return page
    }

    // MARK: Stroke shapes

    private static func wave(x0: CGFloat, y0: CGFloat, count: Int, step: CGFloat, amplitude: CGFloat) -> [InkPoint] {
        (0..<count).map { i in
            InkPoint(
                x: x0 + CGFloat(i) * step, y: y0 + amplitude * sin(CGFloat(i) * 0.5), dtMs: i * 12,
                sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5 + 0.2 * sin(CGFloat(i) * 0.3),
                azimuth: 0, altitude: 1.4
            )
        }
    }

    private static func markerLine(x0: CGFloat, y0: CGFloat, count: Int, step: CGFloat) -> [InkPoint] {
        (0..<count).map { i in
            InkPoint(
                x: x0 + CGFloat(i) * step, y: y0 + 0.4 * sin(CGFloat(i)), dtMs: i * 15,
                sizeW: 18, sizeH: 18, opacity: 1, force: 0.4, azimuth: 0, altitude: 1.4
            )
        }
    }

    private static func circle(cx: CGFloat, cy: CGFloat, radius: CGFloat, count: Int, nib: CGFloat) -> [InkPoint] {
        (0...count).map { i in
            let angle = CGFloat(i) * (2 * .pi / CGFloat(count))
            return InkPoint(
                x: cx + radius * cos(angle), y: cy + radius * sin(angle), dtMs: i * 8,
                sizeW: nib, sizeH: nib, opacity: 1, force: 0.6, azimuth: 0, altitude: 1.4
            )
        }
    }
}
