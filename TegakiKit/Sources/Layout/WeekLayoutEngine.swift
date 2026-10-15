import Foundation
import CoreGraphics
import Holidays

/// Input of the week page layout.
public struct WeekLayoutInput: Sendable {
    /// The week's Monday (normalized from `focus`).
    public var monday: DayKey
    public var events: [LayoutEvent]
    /// Kept for the callers (M4B-17); not read since M4b: nothing on the week page grows with ink.
    public var inkBottoms: [CellKey: CGFloat]
    public var now: Date
    public var calendar: Calendar

    public init(focus: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar) {
        monday = MonthLayout.mondayOnOrBefore(focus)
        self.events = events
        self.inkBottoms = inkBottoms
        self.now = now
        self.calendar = calendar
    }
}

/// The week page in paper coordinates (lu): the 24-hour grid, fixed 1400 × 1920, starting at 0:00.
/// The all-day band is not on the paper since M4b: `allDayBand` describes the fixed band the screen
/// draws above the paper (M4B_CONTRACT §2).
public struct WeekPageLayout: PageLayout, Equatable, Sendable {
    /// "w-2026-09-28" (the Monday).
    public var pageId: String
    /// 7 days, Monday first.
    public var days: [DayKey]
    /// 1400 × 1920 (fixed).
    public var size: CGSize
    /// The time grid (0, 0, 1400, 1920) = the whole paper.
    public var grid: CGRect
    /// The fixed all-day band above the paper (drawn by the screen, not on the paper).
    public var allDayBand: AllDayBandLayout
    /// `[.grid: grid]`.
    public var cells: [CellKey: CGRect]
    /// Always empty (protocol requirement; the paper has no band).
    public var allDayBars: [AllDayBar]
    public var timedBoxes: [TimedEventBox]
    /// 7 labels of height 0 at the top of each column (not tappable on the paper: the sticky header
    /// draws and handles them).
    public var dateLabels: [DateLabel]
    public var nowLine: NowLine?
    public var todayColumn: Int?

    public init(pageId: String, days: [DayKey], size: CGSize, grid: CGRect, allDayBand: AllDayBandLayout, cells: [CellKey: CGRect], allDayBars: [AllDayBar], timedBoxes: [TimedEventBox], dateLabels: [DateLabel], nowLine: NowLine?, todayColumn: Int?) {
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

    /// Inside the paper (the time gutter included) → `.grid`; outside → nil.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= 0, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        return .grid
    }

    /// Always `.grid` (above the paper, a negative y, included): the week page has one ink cell.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        .grid
    }

    /// Nothing on the week page grows with handwriting (the time grid is fixed).
    public func growsWithInk(_ cell: CellKey) -> Bool {
        false
    }

    /// Boxes only; the band's bars are the screen's buttons and the date labels have no height.
    public func hit(at point: CGPoint) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        for box in timedBoxes where box.frame.contains(point) {
            return .timedBox(box.eventId)
        }
        return nil
    }

    /// "grid" inside the paper / nil.
    public func band(atY y: CGFloat) -> PageBand? {
        guard y.isFinite, y >= 0, y < size.height else { return nil }
        return .grid
    }

    /// 0 for `.grid`; nil for every other band (the paper has no all-day band).
    public func bandTop(_ band: PageBand) -> CGFloat? {
        band == .grid ? grid.minY : nil
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
        let monday = input.monday
        let days = (0..<PaperSpec.weekColumns).map { monday.adding(days: $0) }
        let colW = PaperSpec.weekColumnWidth
        let gutter = PaperSpec.weekGutter
        let today = DayKey(input.now, calendar: calendar)
        let grid = CGRect(x: 0, y: 0, width: PaperSpec.weekWidth, height: PaperSpec.weekGridHeight)

        // The all-day band (the web version's allDayRowsForRange) lives outside the paper.
        let band = AllDayBandEngine.week(monday: monday, events: input.events, now: input.now, calendar: calendar)

        var labels: [DateLabel] = []
        var boxes: [TimedEventBox] = []
        let holidays = JapaneseHolidays.names(for: days)
        for (i, day) in days.enumerated() {
            let x = gutter + CGFloat(i) * colW
            let holiday = holidays[day]
            labels.append(DateLabel(
                day: day,
                frame: CGRect(x: x, y: 0, width: colW, height: 0),
                isToday: day == today,
                inMonth: true,
                tone: LayoutMath.tone(of: day, holiday: holiday),
                holidayName: holiday
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
                    timeText: TimedEventEngine.timeRangeText(start: slot.event.start, end: slot.event.end, calendar: calendar),
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

        return WeekPageLayout(
            pageId: PageNavigation.pageId(.week, focus: monday),
            days: days,
            size: CGSize(width: PaperSpec.weekWidth, height: PaperSpec.weekGridHeight),
            grid: grid,
            allDayBand: band,
            cells: [.grid: grid],
            allDayBars: [],
            timedBoxes: boxes,
            dateLabels: labels,
            nowLine: nowLine,
            todayColumn: todayColumn
        )
    }
}
