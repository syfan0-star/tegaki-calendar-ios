import Foundation
import CoreGraphics
import Holidays

/// Input of the day page layout.
public struct DayLayoutInput: Sendable {
    public var day: DayKey
    public var events: [LayoutEvent]
    /// Only `.allDayDay` is read; the time grid never grows.
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

/// The day page in paper coordinates (lu): the all-day band on top (one full-width cell), below it
/// the timeline (x 72…660) and the memo area (660…1000) as one fixed 2400 lu cell.
public struct DayPageLayout: PageLayout, Equatable, Sendable {
    /// "d-2026-10-04".
    public var pageId: String
    public var day: DayKey
    /// 1000 × (band height + 2400).
    public var size: CGSize
    /// (0, 0, 1000, bandH).
    public var band: CGRect
    /// (0, bandH, 1000, 2400).
    public var grid: CGRect
    /// (72, bandH, 588, 2400).
    public var timeline: CGRect
    /// (660, bandH, 340, 2400).
    public var memo: CGRect
    public var laneCount: Int
    /// lane 22 / step 24 / gap 2 unless the band reached its cap.
    public var laneMetrics: LaneMetrics
    /// `.allDayDay` + `.grid`.
    public var cells: [CellKey: CGRect]
    /// All-day chips inside the timeline column; `row` 0, `lane` = display order.
    public var allDayBars: [AllDayBar]
    public var timedBoxes: [TimedEventBox]
    /// One label of height 0 (the sticky header draws the date).
    public var dateLabels: [DateLabel]
    public var nowLine: NowLine?
    public var isToday: Bool

    public init(pageId: String, day: DayKey, size: CGSize, band: CGRect, grid: CGRect, timeline: CGRect, memo: CGRect, laneCount: Int, laneMetrics: LaneMetrics, cells: [CellKey: CGRect], allDayBars: [AllDayBar], timedBoxes: [TimedEventBox], dateLabels: [DateLabel], nowLine: NowLine?, isToday: Bool) {
        self.pageId = pageId
        self.day = day
        self.size = size
        self.band = band
        self.grid = grid
        self.timeline = timeline
        self.memo = memo
        self.laneCount = laneCount
        self.laneMetrics = laneMetrics
        self.cells = cells
        self.allDayBars = allDayBars
        self.timedBoxes = timedBoxes
        self.dateLabels = dateLabels
        self.nowLine = nowLine
        self.isToday = isToday
    }

    public var kind: PageKind { .day }

    /// Paper y of a minute of the day: grid.minY + minutes × 100 / 60.
    public func minutesToY(_ minutes: Int) -> CGFloat {
        grid.minY + CGFloat(minutes) * PaperSpec.dayHourHeight / 60
    }

    /// Inside the band → `.allDayDay`; inside the grid → `.grid`; outside the paper → nil.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= 0, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        return point.y < band.height ? .allDayDay : .grid
    }

    /// Above the grid (negative y included) → `.allDayDay`; else `.grid`.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        guard point.y.isFinite else { return .grid }
        return point.y < band.height ? .allDayDay : .grid
    }

    /// Only the all-day band grows.
    public func growsWithInk(_ cell: CellKey) -> Bool {
        cell.isAllDayDay
    }

    /// Boxes first, then the band's chips.
    public func hit(at point: CGPoint) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        for box in timedBoxes where box.frame.contains(point) {
            return .timedBox(box.eventId)
        }
        for bar in allDayBars where bar.frame.contains(point) {
            return .allDayBar(bar.eventId)
        }
        return nil
    }

    /// "allday" / "grid" / nil.
    public func band(atY y: CGFloat) -> PageBand? {
        guard y.isFinite, y >= 0, y < size.height else { return nil }
        return y < band.height ? .allDay : .grid
    }

    public func bandTop(_ band: PageBand) -> CGFloat? {
        if band == .allDay { return self.band.minY }
        if band == .grid { return grid.minY }
        return nil
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

    /// All-day: the band cell. Timed: the timeline column × the minutes of its start and end (clipped
    /// to the day). nil when the range does not start on this day, or the clipped range is empty.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        guard DayKey(range.start, calendar: calendar) == day else { return nil }
        if range.allDay { return cells[.allDayDay] }
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        let startMinute = range.start < dayStart ? 0 : TimedEventEngine.minutesOfDay(range.start, calendar: calendar)
        let endMinute = range.end >= dayEnd ? EventGeometry.dayMinutes : TimedEventEngine.minutesOfDay(range.end, calendar: calendar)
        guard endMinute > startMinute else { return nil }
        let top = minutesToY(startMinute)
        return CGRect(x: timeline.minX, y: top, width: timeline.width, height: minutesToY(endMinute) - top)
    }
}

/// Pure layout of the day page (DESIGN §2.2 / §2.5, M3A_CONTRACT §1.7).
public enum DayLayoutEngine {
    /// Height of the all-day band: `min(800, max(60, lanes × 24 + 30, inkBottom + 12))`.
    public static func bandHeight(laneCount: Int, inkBottom: CGFloat) -> CGFloat {
        let lanes = CGFloat(max(0, laneCount))
        let content = lanes * PaperSpec.dayLaneStep + PaperSpec.dayBandInkMargin
        let ink = LayoutMath.sanitizedInk(inkBottom) + PaperSpec.inkPad
        return min(PaperSpec.dayBandMax, max(PaperSpec.dayBandBase, max(content, ink)))
    }

    public static func layout(_ input: DayLayoutInput) -> DayPageLayout {
        let calendar = input.calendar
        let day = input.day
        let today = DayKey(input.now, calendar: calendar)
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
        let timelineWidth = PaperSpec.dayTimelineRight - PaperSpec.dayGutter

        // One-day range: every all-day event gets its own lane, in eventsOnDay order.
        let spans = MonthLayoutEngine.packAllDayLanes(events: input.events, days: [day], calendar: calendar)
        let laneCount = spans.reduce(0) { max($0, $1.lane + 1) }
        let inkBottom = LayoutMath.sanitizedInk(input.inkBottoms[.allDayDay] ?? 0)
        let bandH = bandHeight(laneCount: laneCount, inkBottom: inkBottom)

        let laneMetrics: LaneMetrics
        if CGFloat(laneCount) * PaperSpec.dayLaneStep + PaperSpec.dayBandInkMargin > PaperSpec.dayBandMax {
            laneMetrics = LanePacking.metrics(
                laneCount: laneCount,
                lane: PaperSpec.allDayLane,
                gap: PaperSpec.dayLaneGap,
                available: PaperSpec.dayBandMax - PaperSpec.dayBandTopPad - PaperSpec.dayBandInkMargin
            )
        } else {
            laneMetrics = .plain(lane: PaperSpec.allDayLane, gap: PaperSpec.dayLaneGap)
        }

        let band = CGRect(x: 0, y: 0, width: PaperSpec.dayWidth, height: bandH)
        let grid = CGRect(x: 0, y: bandH, width: PaperSpec.dayWidth, height: PaperSpec.dayGridHeight)
        let timeline = CGRect(x: PaperSpec.dayGutter, y: bandH, width: timelineWidth, height: PaperSpec.dayGridHeight)
        let memo = CGRect(x: PaperSpec.dayTimelineRight, y: bandH, width: PaperSpec.dayWidth - PaperSpec.dayTimelineRight, height: PaperSpec.dayGridHeight)

        var bars: [AllDayBar] = []
        for span in spans {
            bars.append(AllDayBar(
                eventId: span.event.id,
                frame: CGRect(
                    x: PaperSpec.dayGutter + PaperSpec.dayChipPadLeft,
                    y: PaperSpec.dayBandTopPad + CGFloat(span.lane) * laneMetrics.step,
                    width: timelineWidth - PaperSpec.dayChipPadLeft - PaperSpec.dayChipPadRight,
                    height: laneMetrics.lane
                ),
                row: 0,
                lane: span.lane,
                continuesLeft: span.event.start < dayStart,
                continuesRight: span.event.end > dayEnd,
                colorHex: span.event.colorHex,
                title: span.event.title
            ))
        }

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
            size: CGSize(width: PaperSpec.dayWidth, height: bandH + PaperSpec.dayGridHeight),
            band: band,
            grid: grid,
            timeline: timeline,
            memo: memo,
            laneCount: laneCount,
            laneMetrics: laneMetrics,
            cells: [.allDayDay: band, .grid: grid],
            allDayBars: bars,
            timedBoxes: boxes,
            dateLabels: labels,
            nowLine: nowLine,
            isToday: isToday
        )
    }
}
