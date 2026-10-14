import Foundation
import CoreGraphics
import Holidays

/// Input of the week page layout.
public struct WeekLayoutInput: Sendable {
    /// The week's Monday (normalized from `focus`).
    public var monday: DayKey
    public var events: [LayoutEvent]
    /// Bottom edge of the handwriting of each cell (cell-relative lu). Only the 7 `allday:` cells
    /// are read; the time grid never grows.
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

/// The week page in paper coordinates (lu): the all-day band on top (7 cells, grows with its
/// events and handwriting), the 24-hour grid below (fixed 1920).
public struct WeekPageLayout: PageLayout, Equatable, Sendable {
    /// "w-2026-09-28" (the Monday).
    public var pageId: String
    /// 7 days, Monday first.
    public var days: [DayKey]
    /// 1400 × (band height + 1920).
    public var size: CGSize
    /// The all-day band (0, 0, 1400, bandH).
    public var band: CGRect
    /// The time grid (0, bandH, 1400, 1920).
    public var grid: CGRect
    public var laneCount: Int
    /// lane 22 / step 25 / gap 3 / fontScale 1 unless the band reached its cap.
    public var laneMetrics: LaneMetrics
    /// 7 `.allDay(day)` cells + `.grid`.
    public var cells: [CellKey: CGRect]
    /// `row` is always 0.
    public var allDayBars: [AllDayBar]
    public var timedBoxes: [TimedEventBox]
    /// 7 labels of height 0 at the top of each column (not tappable on the paper: the sticky header
    /// draws and handles them).
    public var dateLabels: [DateLabel]
    public var nowLine: NowLine?
    public var todayColumn: Int?

    public init(pageId: String, days: [DayKey], size: CGSize, band: CGRect, grid: CGRect, laneCount: Int, laneMetrics: LaneMetrics, cells: [CellKey: CGRect], allDayBars: [AllDayBar], timedBoxes: [TimedEventBox], dateLabels: [DateLabel], nowLine: NowLine?, todayColumn: Int?) {
        self.pageId = pageId
        self.days = days
        self.size = size
        self.band = band
        self.grid = grid
        self.laneCount = laneCount
        self.laneMetrics = laneMetrics
        self.cells = cells
        self.allDayBars = allDayBars
        self.timedBoxes = timedBoxes
        self.dateLabels = dateLabels
        self.nowLine = nowLine
        self.todayColumn = todayColumn
    }

    public var kind: PageKind { .week }

    /// Paper rect of day column `col` (0…6) inside the grid: (64 + col × 190.857…, grid.minY, 190.857…, 1920).
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

    /// Paper y of a minute of the day: grid.minY + minutes × 80 / 60.
    public func minutesToY(_ minutes: Int) -> CGFloat {
        grid.minY + CGFloat(minutes) * PaperSpec.weekHourHeight / 60
    }

    /// Inside the band with x ≥ 64 → that column's `.allDay`; inside the grid → `.grid`; else nil
    /// (the band's time gutter belongs to no cell).
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= 0, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        if point.y < band.height {
            guard let col = column(atX: point.x), col < days.count else { return nil }
            return .allDay(days[col])
        }
        return .grid
    }

    /// Above the grid (y < bandH, negative y included) → the nearest column's `.allDay` (the time
    /// gutter and the outside belong to Monday's / Sunday's band, DESIGN §3.4); else `.grid`.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        guard point.x.isFinite, point.y.isFinite, days.count == PaperSpec.weekColumns else { return .grid }
        if point.y < band.height {
            let raw = floor((point.x - PaperSpec.weekGutter) / PaperSpec.weekColumnWidth + 1e-9)
            let col = Int(LayoutMath.clamp(raw, 0, CGFloat(PaperSpec.weekColumns - 1)))
            return .allDay(days[col])
        }
        return .grid
    }

    /// Only the 7 band cells grow; the time grid is fixed.
    public func growsWithInk(_ cell: CellKey) -> Bool {
        guard let date = cell.allDayDate else { return false }
        return days.contains(date)
    }

    /// Boxes first, then band bars; the date labels have no height and are never hit.
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

    // MARK: Rect → event, event → rect (M3B_CONTRACT §1.5)

    /// The nearest day column for any x: the time gutter (x < 64) and the left outside → 0, the right
    /// outside → 6 (web nearestWeekColumn). `clamp(floor((x − 64) / colW + 1e-9), 0, 6)`.
    public func nearestColumn(atX x: CGFloat) -> Int {
        let raw = floor((x - PaperSpec.weekGutter) / PaperSpec.weekColumnWidth + 1e-9)
        return Int(LayoutMath.clamp(raw, 0, CGFloat(PaperSpec.weekColumns - 1)))
    }

    /// A timed event in the column under the rect's centre (the nearest column from the gutter or
    /// outside the paper), with the minutes of `EventGeometry.timelineSlot` (y relative to the grid's
    /// top: a drag started in the band clamps to 0:00).
    public func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard let r = EventGeometry.normalized(rect) else { return nil }
        let col = column(atX: r.midX) ?? nearestColumn(atX: r.midX)
        guard col < days.count else { return nil }
        let slot = EventGeometry.timelineSlot(minY: r.minY - grid.minY, maxY: r.maxY - grid.minY, hourHeight: PaperSpec.weekHourHeight)
        return .timed(days[col], startMinute: slot.startMinute, endMinute: slot.endMinute, calendar: calendar)
    }

    /// All-day: the band cell of the range's first day. Timed: its column × the minutes of its start
    /// and end (clipped to the day). nil when the start day is not in this week, or the clipped
    /// range is empty.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        let day = DayKey(range.start, calendar: calendar)
        guard let col = days.firstIndex(of: day) else { return nil }
        if range.allDay { return cells[.allDay(day)] }
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

/// Pure layout of the week page (DESIGN §2.2 / §2.4, M3A_CONTRACT §1.6).
public enum WeekLayoutEngine {
    /// Height of the all-day band: `min(800, max(60, lanes × 25 + 30, inkBottom + 12))`.
    public static func bandHeight(laneCount: Int, inkBottom: CGFloat) -> CGFloat {
        let lanes = CGFloat(max(0, laneCount))
        let content = lanes * PaperSpec.allDayLaneStep + PaperSpec.weekBandInkMargin
        let ink = LayoutMath.sanitizedInk(inkBottom) + PaperSpec.inkPad
        return min(PaperSpec.weekBandMax, max(PaperSpec.weekBandBase, max(content, ink)))
    }

    public static func layout(_ input: WeekLayoutInput) -> WeekPageLayout {
        let calendar = input.calendar
        let monday = input.monday
        let days = (0..<PaperSpec.weekColumns).map { monday.adding(days: $0) }
        let colW = PaperSpec.weekColumnWidth
        let gutter = PaperSpec.weekGutter
        let today = DayKey(input.now, calendar: calendar)
        let weekStart = monday.startOfDay(in: calendar)
        let weekEnd = monday.adding(days: PaperSpec.weekColumns).startOfDay(in: calendar)

        // All-day lanes (the web version's allDayRowsForRange, shared with the month page).
        let spans = MonthLayoutEngine.packAllDayLanes(events: input.events, days: days, calendar: calendar)
        let laneCount = spans.reduce(0) { max($0, $1.lane + 1) }

        var inkBottom: CGFloat = 0
        for day in days {
            inkBottom = max(inkBottom, LayoutMath.sanitizedInk(input.inkBottoms[.allDay(day)] ?? 0))
        }
        let bandH = bandHeight(laneCount: laneCount, inkBottom: inkBottom)

        let laneMetrics: LaneMetrics
        if CGFloat(laneCount) * PaperSpec.allDayLaneStep + PaperSpec.weekBandInkMargin > PaperSpec.weekBandMax {
            laneMetrics = LanePacking.metrics(
                laneCount: laneCount,
                lane: PaperSpec.allDayLane,
                gap: PaperSpec.allDayGap,
                available: PaperSpec.weekBandMax - PaperSpec.weekBandTopPad - PaperSpec.weekBandInkMargin
            )
        } else {
            laneMetrics = .plain(lane: PaperSpec.allDayLane, gap: PaperSpec.allDayGap)
        }

        let band = CGRect(x: 0, y: 0, width: PaperSpec.weekWidth, height: bandH)
        let grid = CGRect(x: 0, y: bandH, width: PaperSpec.weekWidth, height: PaperSpec.weekGridHeight)

        var bars: [AllDayBar] = []
        for span in spans {
            let left = span.event.start < weekStart
            let right = span.event.end > weekEnd
            let insetLeft: CGFloat = left ? 0 : PaperSpec.weekBarInset
            let insetRight: CGFloat = right ? 0 : PaperSpec.weekBarInset
            let x = gutter + CGFloat(span.startCol) * colW + insetLeft
            let width = CGFloat(span.endCol - span.startCol + 1) * colW - insetLeft - insetRight
            let y = PaperSpec.weekBandTopPad + CGFloat(span.lane) * laneMetrics.step
            bars.append(AllDayBar(
                eventId: span.event.id,
                frame: CGRect(x: x, y: y, width: width, height: laneMetrics.lane),
                row: 0,
                lane: span.lane,
                continuesLeft: left,
                continuesRight: right,
                colorHex: span.event.colorHex,
                title: span.event.title
            ))
        }

        var cells: [CellKey: CGRect] = [:]
        var labels: [DateLabel] = []
        var boxes: [TimedEventBox] = []
        let holidays = JapaneseHolidays.names(for: days)
        for (i, day) in days.enumerated() {
            let x = gutter + CGFloat(i) * colW
            cells[.allDay(day)] = CGRect(x: x, y: 0, width: colW, height: bandH)
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
        cells[.grid] = grid

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
            size: CGSize(width: PaperSpec.weekWidth, height: bandH + PaperSpec.weekGridHeight),
            band: band,
            grid: grid,
            laneCount: laneCount,
            laneMetrics: laneMetrics,
            cells: cells,
            allDayBars: bars,
            timedBoxes: boxes,
            dateLabels: labels,
            nowLine: nowLine,
            todayColumn: todayColumn
        )
    }
}
