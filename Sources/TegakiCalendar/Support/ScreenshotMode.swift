import Foundation
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
enum ScreenshotMode {
    /// The sheets a screenshot can show (`--screenshot-sheet`; M3b contract §5, M4 contract §6.6).
    enum Sheet: String, CaseIterable, Sendable {
        case create, edit, lasso, settings, sync, `import`
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
    }

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
        return Config(page: page, month: month, today: todayInstant(for: month), focus: focusDay(for: month), sheet: sheet, landscape: landscape)
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

    static let calendars: [DemoCalendar] = [
        DemoCalendar(id: "demo-work", title: "仕事", colorHex: "#4285f4"),
        DemoCalendar(id: "demo-family", title: "家族", colorHex: "#33b679"),
        DemoCalendar(id: "demo-personal", title: "個人", colorHex: "#e67c73"),
        DemoCalendar(id: "demo-events", title: "行事", colorHex: "#f6bf26"),
    ]

    static func calendarTitle(forCalendarId id: String) -> String {
        calendars.first { $0.id == id }?.title ?? ""
    }

    /// The demo calendars as the settings screen and the sheets show them (M3b contract §5): all
    /// four writable, under the source 「見本」.
    static var calendarOptions: [CalendarOption] {
        calendars.map { demo in
            CalendarOption(
                id: demo.id,
                title: demo.title,
                colorHex: demo.colorHex,
                sourceTitle: "見本",
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
    /// to run; the M3a events come last so the M2 ids do not move.
    static func demoEvents(for month: YearMonth) -> [LayoutEvent] {
        let calendar = DayKey.deviceCalendar
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
                colorHex: calendars[cal].colorHex,
                calendarId: calendars[cal].id
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
                colorHex: calendars[cal].colorHex,
                calendarId: calendars[cal].id
            ))
        }

        // All-day (M2)
        allDay("運動会", 3, in: events)
        allDay("キャンプ", 4, days: 2, in: family)
        allDay("家族旅行", 9, days: 5, in: family)
        allDay("資料提出締切", 16, in: work)
        allDay("健康診断", 16, in: personal)
        allDay("ゴミの日", 16, in: family)
        allDay("誕生日", 16, in: family)
        allDay("出張（大阪）", 21, days: 2, in: work)
        allDay("給料日", 25, in: personal)

        // Timed (M2)
        timed("歯医者", 2, 10, in: personal)
        timed("週次定例", 6, 10, in: work)
        timed("資料提出", 8, 15, minutes: 30, in: work)
        timed("通院", 9, 14, in: personal)
        timed("週次定例", 13, 10, in: work)
        timed("朝会", 20, 9, minutes: 15, in: work)
        timed("週次定例", 20, 10, in: work)
        timed("面談", 20, 13, minutes: 30, in: work)
        timed("レビュー", 20, 15, in: work)
        timed("送別会", 20, 18, minutes: 120, in: personal)
        timed("飲み会", 23, 19, minutes: 120, in: personal)
        timed("週次定例", 27, 10, in: work)
        timed("ランチ", 28, 11, 30, minutes: 90, in: family)

        // The 7th, 「今日」 (M3a): the month row stays 175 high (28 + 25 + 3×20 + 40 = 153).
        allDay("締切", 7, in: personal)
        timed("打合せ", 7, 10, minutes: 90, in: work)
        timed("電話", 7, 10, 30, minutes: 30, in: personal)
        timed("歯科", 7, 14, in: personal)

        return out
    }

    // MARK: - Demo ink

    /// A few strokes for the page `kind` opened on `focus` (contract §7), so PencilKit's rendering
    /// path and the cell anchoring of every page are exercised. Points are cell-relative lu, as in a
    /// stored page.
    static func demoPage(kind: PageKind, focus: DayKey) -> InkPage {
        switch kind {
        case .month:
            return demoPage(for: YearMonth(year: focus.year, month: focus.month))
        case .week:
            return weekDemoPage(focus: focus)
        case .day:
            return dayDemoPage(focus: focus)
        case .year:
            return yearDemoPage(focus: focus)
        }
    }

    /// A fixed ms epoch; each stroke gets its own `t`.
    private static let baseTime = 1_760_000_000_000

    /// The month page with three strokes: a wavy pen stroke in the cell of the 14th, a marker line
    /// over the 「+3件」 chip of the 20th, and a dot in the memo area.
    static func demoPage(for month: YearMonth) -> InkPage {
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

        return page
    }

    /// Week: a wavy pen stroke on the grid at the top of the Wednesday column (y 40 ± 5, just under
    /// 0:00; the same place the M3a–M4 band stroke of that cell lands after `BandMigration`, so the
    /// demo needs no migration itself, M4B contract §2.7), a marker across the top of the 10:00
    /// 打合せ box of `focus` (the box starts at grid y 800 in that day's column).
    private static func weekDemoPage(focus: DayKey) -> InkPage {
        var page = InkPage.empty(pageId: PageNavigation.pageId(.week, focus: focus))
        let wednesdayX = PaperSpec.weekGutter + 2 * PaperSpec.weekColumnWidth
        page.add(InkStroke(id: "demo-stroke-week-wave", cell: .grid, tool: .pen, color: "#1f2937", t: baseTime,
                           points: wave(x0: wednesdayX + 12, y0: 40, count: 30, step: 5.2, amplitude: 5)))
        let column = CGFloat((focus.weekday + 6) % 7)
        let columnX = PaperSpec.weekGutter + column * PaperSpec.weekColumnWidth
        let boxTop = 10 * PaperSpec.weekHourHeight + 10
        page.add(InkStroke(id: "demo-stroke-week-marker", cell: .grid, tool: .marker, color: "#fde047", t: baseTime + 1_000,
                           points: markerLine(x0: columnX + 12, y0: boxTop, count: 16, step: 10)))
        return page
    }

    /// Day: a pen circle at the top of the memo column (grid (800, 30): where the M3a–M4 band
    /// stroke lands after `BandMigration`, M4B contract §2.7) and two wavy pen lines lower in the
    /// memo area (x ≥ 660).
    private static func dayDemoPage(focus: DayKey) -> InkPage {
        var page = InkPage.empty(pageId: PageNavigation.pageId(.day, focus: focus))
        page.add(InkStroke(id: "demo-stroke-day-circle", cell: .grid, tool: .pen, color: "#2563eb", t: baseTime,
                           points: circle(cx: 800, cy: 30, radius: 14, count: 24, nib: 3.5)))
        let memoLeft = PaperSpec.dayTimelineRight + 30
        page.add(InkStroke(id: "demo-stroke-day-wave1", cell: .grid, tool: .pen, color: "#1f2937", t: baseTime + 1_000,
                           points: wave(x0: memoLeft, y0: 120, count: 40, step: 6.5, amplitude: 7)))
        page.add(InkStroke(id: "demo-stroke-day-wave2", cell: .grid, tool: .pen, color: "#1f2937", t: baseTime + 2_000,
                           points: wave(x0: memoLeft, y0: 180, count: 40, step: 6.5, amplitude: 7)))
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
