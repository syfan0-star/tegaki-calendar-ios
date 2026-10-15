import Foundation
import CoreGraphics
import Holidays

/// Input of the day page layout.
public struct DayLayoutInput: Sendable {
    public var day: DayKey
    public var events: [LayoutEvent]
    /// Kept for the callers (M4B-17); not read since M4b: nothing on the day page grows with ink.
    public var inkBottoms: [CellKey: CGFloat]
    public var now: Date
    public var calendar: Calendar

    public init(day: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar) {
        self.day = day
        self.events = events
        self.inkBottoms = inkBottoms
        self.now = now
        self.calendar = calendar
    }
}

/// The day page in paper coordinates (lu): the timeline (x 72…660) and the memo area (660…1000) as
/// one fixed 1000 × 2400 cell starting at 0:00. The all-day band is not on the paper since M4b:
/// `allDayBand` describes the fixed band the screen draws above the paper (M4B_CONTRACT §2).
public struct DayPageLayout: PageLayout, Equatable, Sendable {
    /// "d-2026-10-04".
    public var pageId: String
    public var day: DayKey
    /// 1000 × 2400 (fixed).
    public var size: CGSize
    /// (0, 0, 1000, 2400) = the whole paper.
    public var grid: CGRect
    /// (72, 0, 588, 2400).
    public var timeline: CGRect
    /// (660, 0, 340, 2400).
    public var memo: CGRect
    /// The fixed all-day band above the paper (drawn by the screen, not on the paper).
    public var allDayBand: AllDayBandLayout
    /// `[.grid: grid]`.
    public var cells: [CellKey: CGRect]
    /// Always empty (protocol requirement; the paper has no band).
    public var allDayBars: [AllDayBar]
    public var timedBoxes: [TimedEventBox]
    /// One label of height 0 (the sticky header draws the date).
    public var dateLabels: [DateLabel]
    public var nowLine: NowLine?
    public var isToday: Bool

    public init(pageId: String, day: DayKey, size: CGSize, grid: CGRect, timeline: CGRect, memo: CGRect, allDayBand: AllDayBandLayout, cells: [CellKey: CGRect], allDayBars: [AllDayBar], timedBoxes: [TimedEventBox], dateLabels: [DateLabel], nowLine: NowLine?, isToday: Bool) {
        self.pageId = pageId
        self.day = day
        self.size = size
        self.grid = grid
        self.timeline = timeline
        self.memo = memo
        self.allDayBand = allDayBand
        self.cells = cells
        self.allDayBars = allDayBars
        self.timedBoxes = timedBoxes
        self.dateLabels = dateLabels
        self.nowLine = nowLine
        self.isToday = isToday
    }

    public var kind: PageKind { .day }

    /// Paper y of a minute of the day: minutes × 100 / 60 (the grid starts at the paper's top).
    public func minutesToY(_ minutes: Int) -> CGFloat {
        grid.minY + CGFloat(minutes) * PaperSpec.dayHourHeight / 60
    }

    /// Inside the paper (the gutter and the memo area included) → `.grid`; outside → nil.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= 0, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        return .grid
    }

    /// Always `.grid` (above the paper, a negative y, included): the day page has one ink cell.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        .grid
    }

    /// Nothing on the day page grows with handwriting (the time grid is fixed).
    public func growsWithInk(_ cell: CellKey) -> Bool {
        false
    }

    /// Boxes only; the band's bars are the screen's buttons.
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

    // MARK: Rect → event, event → rect (M3B_CONTRACT §1.6)

    /// A timed event on this day with the minutes of `EventGeometry.timelineSlot` (y relative to the
    /// grid's top). The column is always the timeline: a drag in the memo area or the time gutter
    /// still means the day (web "column outside the timeline still uses the day").
    public func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard let r = EventGeometry.normalized(rect) else { return nil }
        let slot = EventGeometry.timelineSlot(minY: r.minY - grid.minY, maxY: r.maxY - grid.minY, hourHeight: PaperSpec.dayHourHeight)
        return .timed(day, startMinute: slot.startMinute, endMinute: slot.endMinute, calendar: calendar)
    }

    /// Timed: the timeline column × the minutes of its start and end (clipped to the day). All-day:
    /// nil (the paper has no band; the fixed band shows it). nil also when the range does not start
    /// on this day, or the clipped range is empty.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        guard DayKey(range.start, calendar: calendar) == day else { return nil }
        if range.allDay { return nil }
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        let startMinute = range.start < dayStart ? 0 : TimedEventEngine.minutesOfDay(range.start, calendar: calendar)
        let endMinute = range.end >= dayEnd ? EventGeometry.dayMinutes : TimedEventEngine.minutesOfDay(range.end, calendar: calendar)
        guard endMinute > startMinute else { return nil }
        let top = minutesToY(startMinute)
        return CGRect(x: timeline.minX, y: top, width: timeline.width, height: minutesToY(endMinute) - top)
    }
}

/// Pure layout of the day page (DESIGN §2.2 / §2.5, M3A_CONTRACT §1.7, M4B_CONTRACT §2.3).
public enum DayLayoutEngine {
    public static func layout(_ input: DayLayoutInput) -> DayPageLayout {
        let calendar = input.calendar
        let day = input.day
        let today = DayKey(input.now, calendar: calendar)
        let timelineWidth = PaperSpec.dayTimelineRight - PaperSpec.dayGutter

        let grid = CGRect(x: 0, y: 0, width: PaperSpec.dayWidth, height: PaperSpec.dayGridHeight)
        let timeline = CGRect(x: PaperSpec.dayGutter, y: 0, width: timelineWidth, height: PaperSpec.dayGridHeight)
        let memo = CGRect(x: PaperSpec.dayTimelineRight, y: 0, width: PaperSpec.dayWidth - PaperSpec.dayTimelineRight, height: PaperSpec.dayGridHeight)

        // The all-day band (one lane per event) lives outside the paper.
        let band = AllDayBandEngine.day(day, events: input.events, now: input.now, calendar: calendar)

        var boxes: [TimedEventBox] = []
        for slot in TimedEventEngine.layout(events: input.events, day: day, calendar: calendar) {
            var frame = TimedEventEngine.boxFrame(
                columnX: PaperSpec.dayGutter,
                columnWidth: timelineWidth,
                startMinute: slot.startMinute,
                endMinute: slot.endMinute,
                column: slot.column,
                columns: slot.columns,
                hourHeight: PaperSpec.dayHourHeight,
                padLeft: PaperSpec.dayBoxPadLeft,
                padRight: PaperSpec.dayBoxPadRight,
                gap: PaperSpec.dayBoxGap
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

        let holiday = JapaneseHolidays.name(of: day)
        let isToday = day == today
        let labels = [DateLabel(
            day: day,
            frame: CGRect(x: PaperSpec.dayGutter, y: 0, width: timelineWidth, height: 0),
            isToday: isToday,
            inMonth: true,
            tone: LayoutMath.tone(of: day, holiday: holiday),
            holidayName: holiday
        )]

        var nowLine: NowLine?
        if isToday {
            let minute = TimedEventEngine.minutesOfDay(input.now, calendar: calendar)
            nowLine = NowLine(
                y: grid.minY + CGFloat(minute) * PaperSpec.dayHourHeight / 60,
                x0: PaperSpec.dayGutter,
                x1: PaperSpec.dayTimelineRight,
                minute: minute
            )
        }

        return DayPageLayout(
            pageId: PageNavigation.pageId(.day, focus: day),
            day: day,
            size: CGSize(width: PaperSpec.dayWidth, height: PaperSpec.dayGridHeight),
            grid: grid,
            timeline: timeline,
            memo: memo,
            allDayBand: band,
            cells: [.grid: grid],
            allDayBars: [],
            timedBoxes: boxes,
            dateLabels: labels,
            nowLine: nowLine,
            isToday: isToday
        )
    }
}
