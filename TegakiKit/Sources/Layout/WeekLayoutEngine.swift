import Foundation
import CoreGraphics
import Holidays

/// Input of the week page layout.
public struct WeekLayoutInput: Sendable {
    /// The week's first day (normalized from `focus` by `weekStart`): a Monday or a Sunday.
    public var firstDay: DayKey
    public var events: [LayoutEvent]
    /// Kept for the callers (M4B-17); the time grid never grows with ink. Since 1.3 only `.extra` is read,
    /// and only with `freeMemo`: the week memo is `PaperGrowth.tailHeight` of it (docs/M7C_CONTRACT.md §5.2).
    public var inkBottoms: [CellKey: CGFloat]
    public var now: Date
    public var calendar: Calendar
    /// Where the colour and the name of a day come from; never the shape of the paper (D9, §5.4).
    public var holidays: HolidayCalendar
    /// The words of the boxes (D9, §3.1 rule 4).
    public var words: LayoutWords
    /// The first column (§10.1). The two week starts are two pages with their own ids (K-11).
    public var weekStart: WeekStart
    /// 1.3 (docs/M7C_CONTRACT.md D16, §5, `SpanAlign`): the least height of the week memo below 24:00,
    /// so the joined weeks of a window end at the same line. Read only when `freeMemo` is true; there it
    /// works as the day's (`DayLayoutInput.extraFloor`: 0, or anything not above the memo's own
    /// `PaperGrowth.tailHeight`, gives the same layout; not finite or negative counts as 0). With
    /// `freeMemo` false (the default) it changes nothing: any value gives 1.2.3's week, `==`.
    public var extraFloor: CGFloat
    /// 1.3 (docs/M7C_CONTRACT.md §5.2, D3 (4)): the week memo below 24:00 (the cell `extra`, 1400 wide,
    /// `PaperGrowth.tailHeight` of `inkBottoms[.extra]` tall, at least 6,000 lu and at least `extraFloor`).
    /// The app's two callers (the one-page path and the joined path) pass true. Left out it is false and
    /// the week is 1.2.3's, `==` (§2.1: a new argument has a default, and leaving it out keeps 1.2.3's
    /// behaviour), so the frozen tests, the prototype and the old tools lay out the week they always did.
    public var freeMemo: Bool

    public init(focus: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar, holidays: HolidayCalendar = .japan, words: LayoutWords = .japanese, weekStart: WeekStart = .monday, extraFloor: CGFloat = 0, freeMemo: Bool = false) {
        firstDay = weekStart.firstDay(of: focus)
        self.events = events
        self.inkBottoms = inkBottoms
        self.now = now
        self.calendar = calendar
        self.holidays = holidays
        self.words = words
        self.weekStart = weekStart
        self.extraFloor = extraFloor
        self.freeMemo = freeMemo
    }
}

/// The week page in paper coordinates (lu): the 24-hour grid, fixed 1400 × 1920, starting at 0:00, and
/// since 1.3, when the input asks for it (`WeekLayoutInput.freeMemo`), the week memo below 24:00 (`extra`,
/// the whole width, 6,000 lu or more; docs/M7C_CONTRACT.md §5.2). A week without it is 1.2.3's.
/// The all-day band is not on the paper since M4b: `allDayBand` describes the fixed band the screen
/// draws above the paper (M4B_CONTRACT §2).
public struct WeekPageLayout: PageLayout, Equatable, Sendable {
    /// "w-2026-09-28" (the first day of the week: a Monday or a Sunday, K-11).
    public var pageId: String
    /// 7 days, the week start's day first (read the order of the columns from here).
    public var days: [DayKey]
    /// 1400 × 1920 (1400 × (1920 + `extra.height`) with the week memo).
    public var size: CGSize
    /// The time grid (0, 0, 1400, 1920): 0:00–24:00, never grows (the whole paper without the week memo).
    public var grid: CGRect
    /// The fixed all-day band above the paper (drawn by the screen, not on the paper).
    public var allDayBand: AllDayBandLayout
    /// `[.grid: grid]` (with the week memo also `.extra: extra`).
    public var cells: [CellKey: CGRect]
    /// Always empty (protocol requirement; the paper has no band).
    public var allDayBars: [AllDayBar]
    public var timedBoxes: [TimedEventBox]
    /// 7 labels of height 0 at the top of each column (not tappable on the paper: the sticky header
    /// draws and handles them).
    public var dateLabels: [DateLabel]
    public var nowLine: NowLine?
    public var todayColumn: Int?
    /// 1.3 (docs/M7C_CONTRACT.md §5.2): the week memo below 24:00, (0, 1920, 1400, h) with h =
    /// `PaperGrowth.tailHeight(inkBottom: inkBottoms[.extra] ?? 0)` (at least 6,000) and at least
    /// `WeekLayoutInput.extraFloor`. A week laid out without it (`freeMemo` false: the default `.zero`, no
    /// `.extra` in `cells`) is 1.2.3's.
    public var extra: CGRect

    public init(pageId: String, days: [DayKey], size: CGSize, grid: CGRect, allDayBand: AllDayBandLayout, cells: [CellKey: CGRect], allDayBars: [AllDayBar], timedBoxes: [TimedEventBox], dateLabels: [DateLabel], nowLine: NowLine?, todayColumn: Int?, extra: CGRect = .zero) {
        self.pageId = pageId
        self.days = days
        self.size = size
        self.grid = grid
        self.allDayBand = allDayBand
        self.cells = cells
        self.allDayBars = allDayBars
        self.timedBoxes = timedBoxes
        self.dateLabels = dateLabels
        self.nowLine = nowLine
        self.todayColumn = todayColumn
        self.extra = extra
    }

    public var kind: PageKind { .week }

    /// Paper rect of day column `col` (0…6): (64 + col × 190.857…, 0, 190.857…, 1920).
    public func columnFrame(_ col: Int) -> CGRect {
        let c = min(PaperSpec.weekColumns - 1, max(0, col))
        return CGRect(x: PaperSpec.weekGutter + CGFloat(c) * PaperSpec.weekColumnWidth, y: grid.minY, width: PaperSpec.weekColumnWidth, height: grid.height)
    }

    /// Day column under paper x: nil in the gutter (x < 64) or right of the paper (x > 1400);
    /// x == 1400 is column 6 (web xToColumn).
    public func column(atX x: CGFloat) -> Int? {
        guard x.isFinite, x >= PaperSpec.weekGutter, x <= PaperSpec.weekWidth else { return nil }
        return min(PaperSpec.weekColumns - 1, Int(floor((x - PaperSpec.weekGutter) / PaperSpec.weekColumnWidth + 1e-9)))
    }

    /// Paper y of a minute of the day: minutes × 80 / 60 (the grid starts at the paper's top).
    public func minutesToY(_ minutes: Int) -> CGFloat {
        grid.minY + CGFloat(minutes) * PaperSpec.weekHourHeight / 60
    }

    /// 0 ≤ x ≤ 1400: 0 ≤ y < 1920 → `.grid` (the time gutter included), with the week memo 1920 ≤ y <
    /// height → `.extra`; outside the paper or not finite → nil.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= 0, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        if point.y < grid.maxY { return .grid }
        return cells[.extra] != nil ? .extra : nil
    }

    /// With the week memo, a centre at y ≥ 1920 (24:00 and below, beside the paper too) → `.extra`, as on
    /// the day page; everything else (above the paper, a negative y, not finite, and every centre of a
    /// week without the memo) → `.grid`. Never nil. A `grid` stroke stays `grid` wherever it lies (K-2): a
    /// line written across 24:00 with its centre above it is `grid`, its lower part shows over the memo.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        guard point.y.isFinite, point.y >= grid.maxY, cells[.extra] != nil else { return .grid }
        return .extra
    }

    /// Only the week memo below 24:00 grows with handwriting (the time grid is fixed); a week without the
    /// memo has nothing that grows.
    public func growsWithInk(_ cell: CellKey) -> Bool {
        cell.isExtra && cells[.extra] != nil
    }

    /// Boxes only; the band's bars are the screen's buttons and the date labels have no height.
    public func hit(at point: CGPoint) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        for box in timedBoxes where box.frame.contains(point) {
            return .timedBox(box.eventId)
        }
        return nil
    }

    /// The day of the column under a double tap (M4C_CONTRACT §4.3): `days[column(atX:)]` while
    /// 0 ≤ y < 1920; nil in the time gutter (x < 64), right of the paper (x > 1400; x == 1400 is the
    /// last column), above the paper, at 24:00 and below (the week memo does nothing, as the day's free
    /// memo; without it that is below the paper), or for a non-finite point. The fixed all-day band above
    /// the paper resolves its own columns (`AllDayBandLayout.day(atPaperX:)`).
    public func dayAt(point: CGPoint) -> DayKey? {
        guard point.y.isFinite, point.y >= 0, point.y < grid.maxY else { return nil }
        guard let col = column(atX: point.x), col < days.count else { return nil }
        return days[col]
    }

    /// [0, 1920) → "grid", with the week memo [1920, height) → "extra", nil outside the paper.
    public func band(atY y: CGFloat) -> PageBand? {
        guard y.isFinite, y >= 0, y < size.height else { return nil }
        if y < grid.maxY { return .grid }
        return cells[.extra] != nil ? .extra : nil
    }

    /// 0 for `.grid`, 1920 for `.extra` when the week has its memo; nil for every other band (the paper
    /// has no all-day band). Neither top moves, so the scroll correction on the week page is always 0.
    public func bandTop(_ band: PageBand) -> CGFloat? {
        if band == .grid { return grid.minY }
        if band == .extra { return cells[.extra]?.minY }
        return nil
    }

    /// Does the rect start below the day (1.3, docs/M7C_CONTRACT.md §5.2: no event is made in the week
    /// memo, the day's rule)? True when the week has its memo and the rect is finite with
    /// `rect.standardized.minY ≥ grid.maxY` (1920): the screen then refuses to make an event before it
    /// calls `eventRange(for:)`, which is unchanged. minY 1,919.9 → false, 1,920 → true; a drag upward
    /// from the memo (its normalized minY above 24:00) → false; not finite → false; a week without the
    /// memo → always false (1.2.3's week makes its 23:00 event there).
    public func startsBelowDay(_ rect: CGRect) -> Bool {
        guard cells[.extra] != nil, let r = EventGeometry.normalized(rect) else { return false }
        return r.minY >= grid.maxY
    }

    // MARK: Rect → event, event → rect (M3B_CONTRACT §1.5)

    /// The nearest day column for any x: the time gutter (x < 64) and the left outside → 0, the right
    /// outside → 6 (web nearestWeekColumn). `clamp(floor((x − 64) / colW + 1e-9), 0, 6)`.
    public func nearestColumn(atX x: CGFloat) -> Int {
        let raw = floor((x - PaperSpec.weekGutter) / PaperSpec.weekColumnWidth + 1e-9)
        return Int(LayoutMath.clamp(raw, 0, CGFloat(PaperSpec.weekColumns - 1)))
    }

    /// A timed event in the column under the rect's centre (the nearest column from the gutter or
    /// outside the paper), with the minutes of `EventGeometry.timelineSlot` (y relative to the grid's
    /// top; a drag above the paper clamps to 0:00).
    public func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard let r = EventGeometry.normalized(rect) else { return nil }
        let col = column(atX: r.midX) ?? nearestColumn(atX: r.midX)
        guard col < days.count else { return nil }
        let slot = EventGeometry.timelineSlot(minY: r.minY - grid.minY, maxY: r.maxY - grid.minY, hourHeight: PaperSpec.weekHourHeight)
        return .timed(days[col], startMinute: slot.startMinute, endMinute: slot.endMinute, calendar: calendar)
    }

    /// Timed: its column × the minutes of its start and end (clipped to the day). All-day: nil (the
    /// paper has no band; the fixed band shows it). nil also when the start day is not in this week,
    /// or the clipped range is empty.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        let day = DayKey(range.start, calendar: calendar)
        guard let col = days.firstIndex(of: day) else { return nil }
        if range.allDay { return nil }
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        let startMinute = range.start < dayStart ? 0 : TimedEventEngine.minutesOfDay(range.start, calendar: calendar)
        let endMinute = range.end >= dayEnd ? EventGeometry.dayMinutes : TimedEventEngine.minutesOfDay(range.end, calendar: calendar)
        guard endMinute > startMinute else { return nil }
        let frame = columnFrame(col)
        let top = minutesToY(startMinute)
        return CGRect(x: frame.minX, y: top, width: frame.width, height: minutesToY(endMinute) - top)
    }
}

/// Pure layout of the week page (DESIGN §2.2 / §2.4, M3A_CONTRACT §1.6, M4B_CONTRACT §2.3).
public enum WeekLayoutEngine {
    public static func layout(_ input: WeekLayoutInput) -> WeekPageLayout {
        let calendar = input.calendar
        let first = input.firstDay
        let days = (0..<PaperSpec.weekColumns).map { first.adding(days: $0) }
        let colW = PaperSpec.weekColumnWidth
        let gutter = PaperSpec.weekGutter
        let today = DayKey(input.now, calendar: calendar)
        let grid = CGRect(x: 0, y: 0, width: PaperSpec.weekWidth, height: PaperSpec.weekGridHeight)
        // 1.3 (docs/M7C_CONTRACT.md §5.2): the week memo below 24:00 when asked for, the day's rule (the
        // whole width, the time gutter included, open to 6,000 from the start, at least the window's floor,
        // D16). Without it the week is 1.2.3's.
        var extra = CGRect.zero
        if input.freeMemo {
            let extraHeight = max(PaperGrowth.tailHeight(inkBottom: input.inkBottoms[.extra] ?? 0), SpanAlign.sanitized(input.extraFloor))
            extra = CGRect(x: 0, y: grid.maxY, width: PaperSpec.weekWidth, height: extraHeight)
        }

        // The all-day band (the web version's allDayRowsForRange) lives outside the paper.
        let band = AllDayBandEngine.week(firstDay: first, weekStart: input.weekStart, events: input.events, now: input.now, calendar: calendar, holidays: input.holidays)

        var labels: [DateLabel] = []
        var boxes: [TimedEventBox] = []
        let holidays = input.holidays.names(for: days)
        let shortHolidays = input.holidays.names(for: days, style: .short)
        for (i, day) in days.enumerated() {
            let x = gutter + CGFloat(i) * colW
            let holiday = holidays[day]
            labels.append(DateLabel(
                day: day,
                frame: CGRect(x: x, y: 0, width: colW, height: 0),
                isToday: day == today,
                inMonth: true,
                tone: LayoutMath.tone(of: day, holiday: holiday, workday: input.holidays.isWorkday(day)),
                holidayName: holiday,
                holidayShortName: shortHolidays[day]
            ))
            for slot in TimedEventEngine.layout(events: input.events, day: day, calendar: calendar) {
                var frame = TimedEventEngine.boxFrame(
                    columnX: x,
                    columnWidth: colW,
                    startMinute: slot.startMinute,
                    endMinute: slot.endMinute,
                    column: slot.column,
                    columns: slot.columns,
                    hourHeight: PaperSpec.weekHourHeight,
                    padLeft: PaperSpec.weekBoxPadLeft,
                    padRight: PaperSpec.weekBoxPadRight,
                    gap: PaperSpec.weekBoxGap
                )
                frame.origin.y += grid.minY
                boxes.append(TimedEventBox(
                    eventId: slot.event.id,
                    frame: frame,
                    day: day,
                    startMinute: slot.startMinute,
                    endMinute: slot.endMinute,
                    column: slot.column,
                    columns: slot.columns,
                    title: slot.event.title,
                    timeText: TimedEventEngine.timeRangeText(start: slot.event.start, end: slot.event.end, calendar: calendar, words: input.words),
                    startText: TimedEventEngine.timeText(slot.event.start, calendar: calendar),
                    colorHex: slot.event.colorHex,
                    isPast: slot.event.end <= input.now
                ))
            }
        }

        let todayColumn = days.firstIndex(of: today)
        var nowLine: NowLine?
        if let col = todayColumn {
            let minute = TimedEventEngine.minutesOfDay(input.now, calendar: calendar)
            let x0 = gutter + CGFloat(col) * colW
            nowLine = NowLine(y: grid.minY + CGFloat(minute) * PaperSpec.weekHourHeight / 60, x0: x0, x1: x0 + colW, minute: minute)
        }

        var cells: [CellKey: CGRect] = [.grid: grid]
        if input.freeMemo { cells[.extra] = extra }
        return WeekPageLayout(
            pageId: PageNavigation.pageId(.week, focus: first, weekStart: input.weekStart),
            days: days,
            size: CGSize(width: PaperSpec.weekWidth, height: grid.maxY + extra.height),
            grid: grid,
            allDayBand: band,
            cells: cells,
            allDayBars: [],
            timedBoxes: boxes,
            dateLabels: labels,
            nowLine: nowLine,
            todayColumn: todayColumn,
            extra: extra
        )
    }
}
