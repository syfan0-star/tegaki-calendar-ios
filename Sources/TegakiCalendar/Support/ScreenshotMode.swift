import Foundation
import InkModel
import Layout

/// Screenshot mode for CI (docs/M2.md §2.1): the app launched with `--screenshot-mode` skips the
/// onboarding, never asks EventKit for anything, shows deterministic demo events for the month given
/// by `--screenshot-month YYYY-MM` (default: the current month), treats a fixed instant as 「今日」, and
/// preloads a few ink strokes in memory (nothing is saved). Never active unless `--screenshot-mode`
/// is present. (No landscape variant: iPadOS refuses a programmatic orientation change for an app
/// that supports multitasking, and simctl cannot rotate the device.)
enum ScreenshotMode {
    struct Config: Equatable, Sendable {
        var month: YearMonth
        /// The instant that counts as "now" (the 「今日」 mark), so a screenshot never depends on the clock.
        var today: Date
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
        return Config(month: month, today: todayInstant(for: month))
    }

    /// "2026-10" → 2026年10月; nil for anything else.
    static func parseMonth(_ text: String) -> YearMonth? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]),
              year >= 1, (1...12).contains(month) else { return nil }
        return YearMonth(year: year, month: month)
    }

    /// 10:00 on the 7th of the month (a plain weekday in 2026-10, so the 「今日」 circle is visible).
    static func todayInstant(for month: YearMonth) -> Date {
        day(7, of: month).startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600)
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

    /// The sample month (designed around 2026-10, whose 1st is a Thursday; day numbers are reused
    /// for any month): timed events on several days, five of them on the 20th (→ 2 chips + 「+3件」);
    /// all-day events including 家族旅行 over five days across a week boundary (9th–13th) and four
    /// all-day events on the 16th (that row grows to four lanes). Ids are fixed, so the layout is
    /// identical from run to run.
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

        // All-day
        allDay("運動会", 3, in: events)
        allDay("キャンプ", 4, days: 2, in: family)
        allDay("家族旅行", 9, days: 5, in: family)
        allDay("資料提出締切", 16, in: work)
        allDay("健康診断", 16, in: personal)
        allDay("ゴミの日", 16, in: family)
        allDay("誕生日", 16, in: family)
        allDay("出張（大阪）", 21, days: 2, in: work)
        allDay("給料日", 25, in: personal)

        // Timed
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

        return out
    }

    // MARK: - Demo ink

    /// A page with three strokes, so PencilKit's rendering path is exercised: a wavy pen stroke in
    /// the cell of the 14th, a marker line over the 「+3件」 chip of the 20th, and a dot in the memo
    /// area. Points are cell-relative lu, as in a stored page.
    static func demoPage(for month: YearMonth) -> InkPage {
        var page = InkPage.empty(pageId: month.inkPageId)
        let base = 1_760_000_000_000 // a fixed ms epoch; each stroke gets its own `t`

        // 1. Pen, wavy, 36 points across the 14th (y ≈ 141…159, below the chip area of that row).
        var wave: [InkPoint] = []
        for i in 0..<36 {
            let x = 24 + CGFloat(i) * 4.2
            let y = 150 + 9 * sin(CGFloat(i) * 0.5)
            wave.append(InkPoint(
                x: x, y: y, dtMs: i * 12,
                sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5 + 0.2 * sin(CGFloat(i) * 0.3),
                azimuth: 0, altitude: 1.4
            ))
        }
        page.add(InkStroke(id: "demo-stroke-wave", cell: .day(day(14, of: month)), tool: .pen, color: "#1f2937", t: base, points: wave))

        // 2. Marker across the third chip (「+3件」) of the 20th: chips start at y 53 in a one-lane row.
        var highlight: [InkPoint] = []
        for i in 0..<16 {
            highlight.append(InkPoint(
                x: 28 + CGFloat(i) * 9, y: 103 + 0.4 * sin(CGFloat(i)), dtMs: i * 15,
                sizeW: 18, sizeH: 18, opacity: 1, force: 0.4, azimuth: 0, altitude: 1.4
            ))
        }
        page.add(InkStroke(id: "demo-stroke-marker", cell: .day(day(20, of: month)), tool: .marker, color: "#fde047", t: base + 1_000, points: highlight))

        // 3. A dot (a tiny loop) in the memo area, red, 太 nib.
        var dot: [InkPoint] = []
        for i in 0..<8 {
            let angle = CGFloat(i) * (.pi / 4)
            dot.append(InkPoint(
                x: 80 + 1.5 * cos(angle), y: 60 + 1.5 * sin(angle), dtMs: i * 8,
                sizeW: 6, sizeH: 6, opacity: 1, force: 0.6, azimuth: 0, altitude: 1.4
            ))
        }
        page.add(InkStroke(id: "demo-stroke-dot", cell: .memo, tool: .pen, color: "#dc2626", t: base + 2_000, points: dot))

        return page
    }
}
