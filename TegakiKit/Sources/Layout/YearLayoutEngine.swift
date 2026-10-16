import Foundation
import CoreGraphics
import Holidays

/// Input of the year page layout.
public struct YearLayoutInput: Sendable {
    public var year: Int
    public var events: [LayoutEvent]
    /// Bottom edge of the handwriting of each "MM-DD" cell (cell-relative lu).
    public var inkBottoms: [CellKey: CGFloat]
    public var now: Date
    public var calendar: Calendar

    public init(year: Int, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar) {
        self.year = year
        self.events = events
        self.inkBottoms = inkBottoms
        self.now = now
        self.calendar = calendar
    }
}

/// One row of the year page (the row of day number `dayNumber`). It grows with the busiest of the
/// 12 months and with the handwriting of its 12 cells.
public struct YearRow: Equatable, Sendable {
    /// 1…31.
    public var dayNumber: Int
    /// (0, y, 1400, h).
    public var frame: CGRect
    /// Largest lane count of the 12 cells of the row.
    public var laneCount: Int

    public init(dayNumber: Int, frame: CGRect, laneCount: Int) {
        self.dayNumber = dayNumber
        self.frame = frame
        self.laneCount = laneCount
    }
}

/// An all-day chip of the year page. A multi-day event has one chip on each day it covers, all in
/// the same lane of its month column, linked from day to day.
public struct YearChip: Equatable, Sendable {
    public var eventId: String
    public var frame: CGRect
    public var day: DayKey
    public var lane: Int
    /// The event started before this day's 0:00 (square off the top corners).
    public var continuesUp: Bool
    /// The event continues after the next 0:00 (square off the bottom corners).
    public var continuesDown: Bool
    /// When the event continues on the next day of the same month: the top y of that day's chip
    /// (draw the colour down to it). nil on the month's last day.
    public var linkToY: CGFloat?
    public var title: String
    public var colorHex: String
    /// The lane is thinner than `PaperSpec.yearThinLane`: a tap opens the day instead.
    public var isThin: Bool
    public var fontScale: CGFloat

    public init(eventId: String, frame: CGRect, day: DayKey, lane: Int, continuesUp: Bool, continuesDown: Bool, linkToY: CGFloat?, title: String, colorHex: String, isThin: Bool, fontScale: CGFloat) {
        self.eventId = eventId
        self.frame = frame
        self.day = day
        self.lane = lane
        self.continuesUp = continuesUp
        self.continuesDown = continuesDown
        self.linkToY = linkToY
        self.title = title
        self.colorHex = colorHex
        self.isThin = isThin
        self.fontScale = fontScale
    }
}

/// The year page in paper coordinates (lu): 12 month columns × 31 day rows (the day-number gutter
/// on the left, 56 lu). Timed events are not shown (DESIGN §2.6).
public struct YearPageLayout: PageLayout, Equatable, Sendable {
    /// "y-2026".
    public var pageId: String
    public var year: Int
    /// 1400 × Σ rows[i].frame.height.
    public var size: CGSize
    /// 31 rows, top to bottom.
    public var rows: [YearRow]
    /// 12 × 31 = 372 cells (dates that do not exist included).
    public var cells: [CellKey: CGRect]
    /// 2/30, 4/31 … and 2/29 of a common year (drawn hatched), month by month.
    public var invalidCells: [CellKey]
    public var chips: [YearChip]
    /// Existing days only (365 / 366). `frame` is the tap area of the weekday letter
    /// (cellX, cellY, 40, 28).
    public var dateLabels: [DateLabel]
    public var todayCell: CellKey?

    public init(pageId: String, year: Int, size: CGSize, rows: [YearRow], cells: [CellKey: CGRect], invalidCells: [CellKey], chips: [YearChip], dateLabels: [DateLabel], todayCell: CellKey?) {
        self.pageId = pageId
        self.year = year
        self.size = size
        self.rows = rows
        self.cells = cells
        self.invalidCells = invalidCells
        self.chips = chips
        self.dateLabels = dateLabels
        self.todayCell = todayCell
    }

    public var kind: PageKind { .year }

    public var allDayBars: [AllDayBar] { [] }

    public var timedBoxes: [TimedEventBox] { [] }

    public var nowLine: NowLine? { nil }

    /// Paper rect of month `month` (1…12): (56 + (month − 1) × 112, 0, 112, height).
    public func columnFrame(month: Int) -> CGRect {
        let m = min(PaperSpec.yearColumns, max(1, month))
        return CGRect(x: Self.columnX(month: m), y: 0, width: PaperSpec.yearColumnWidth, height: size.height)
    }

    /// Rect of the cell of (month 1…12, day 1…31); nil out of range.
    public func cellFrame(month: Int, day: Int) -> CGRect? {
        guard (1...PaperSpec.yearColumns).contains(month), (1...PaperSpec.yearRows).contains(day) else { return nil }
        return cells[.yearDay(month: month, day: day)]
    }

    /// Day number (1…31) of the row containing paper y; nil outside.
    public func row(atY y: CGFloat) -> Int? {
        guard y.isFinite else { return nil }
        return rows.first(where: { y >= $0.frame.minY && y < $0.frame.maxY })?.dayNumber
    }

    /// The cell under a point inside the date columns (56 ≤ x ≤ 1400, 0 ≤ y < height); nil in the
    /// day-number gutter or outside the paper.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= PaperSpec.yearGutter, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        guard let day = row(atY: point.y) else { return nil }
        let month = min(PaperSpec.yearColumns - 1, Int(floor((point.x - PaperSpec.yearGutter) / PaperSpec.yearColumnWidth + 1e-9))) + 1
        return .yearDay(month: month, day: day)
    }

    /// The nearest cell: the gutter and the left outside belong to January (x goes negative,
    /// DESIGN §3.4), the right outside to December, above the paper to day 1, below to day 31.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        guard point.x.isFinite, point.y.isFinite else { return .yearDay(month: 1, day: 1) }
        let rawMonth = floor((point.x - PaperSpec.yearGutter) / PaperSpec.yearColumnWidth + 1e-9)
        let month = Int(LayoutMath.clamp(rawMonth, 0, CGFloat(PaperSpec.yearColumns - 1))) + 1
        let y = LayoutMath.clamp(point.y, 0, max(size.height - 0.001, 0))
        let day = row(atY: y) ?? PaperSpec.yearRows
        return .yearDay(month: month, day: day)
    }

    /// Every one of the 372 cells grows with handwriting.
    public func growsWithInk(_ cell: CellKey) -> Bool {
        cells[cell] != nil
    }

    /// Chips first (a thin chip opens its day), then the weekday letters.
    public func hit(at point: CGPoint) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        for chip in chips where chip.frame.contains(point) {
            return chip.isThin ? .date(chip.day) : .allDayBar(chip.eventId)
        }
        for label in dateLabels where label.frame.contains(point) {
            return .date(label.day)
        }
        return nil
    }

    /// The date of the cell under a double tap (M4C_CONTRACT §4.3): `cell(at:)` (nil in the
    /// day-number gutter, x < 56, and outside the paper) → (month, day) → `DayKey(year:month:day:)`,
    /// nil when that date does not exist (2/30, 4/31, 2/29 of a common year; `DayKey.isValid`).
    public func dayAt(point: CGPoint) -> DayKey? {
        guard let md = cell(at: point)?.yearMonthDay else { return nil }
        let day = DayKey(year: year, month: md.month, day: md.day)
        return day.isValid ? day : nil
    }

    /// "row:d" (d = 1…31) / nil.
    public func band(atY y: CGFloat) -> PageBand? {
        guard let day = row(atY: y) else { return nil }
        return .row(day)
    }

    public func bandTop(_ band: PageBand) -> CGFloat? {
        guard let day = band.rowIndex, day >= 1, day <= rows.count else { return nil }
        return rows[day - 1].frame.minY
    }

    // MARK: Rect → event, event → rect (M3B_CONTRACT §1.7)

    /// An all-day event on the date under the rect's centre, clamped onto the date columns (the
    /// day-number gutter and the left outside → January, the right outside → December, above the
    /// paper → day 1, below → day 31). A date that does not exist (2/30, 4/31, 2/29 of a common
    /// year) becomes the month's last day (web yearCellForRect).
    public func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard let r = EventGeometry.normalized(rect) else { return nil }
        return .allDay(eventDay(for: r), calendar: calendar)
    }

    /// The cell of the date the range starts on; nil when it is in another year.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        let day = DayKey(range.start, calendar: calendar)
        guard day.year == year else { return nil }
        return cellFrame(month: day.month, day: day.day)
    }

    /// The (existing) date a rect means; see `eventRange(for:now:calendar:)`.
    public func eventDay(for rect: CGRect) -> DayKey {
        let r = EventGeometry.normalized(rect) ?? CGRect(x: PaperSpec.yearGutter, y: 0, width: 0, height: 0)
        let cx = LayoutMath.clamp(r.midX, PaperSpec.yearGutter, PaperSpec.yearWidth)
        let cy = LayoutMath.clamp(r.midY, 0, size.height)
        let month = min(PaperSpec.yearColumns - 1, Int(floor((cx - PaperSpec.yearGutter) / PaperSpec.yearColumnWidth + 1e-9))) + 1
        let dayNumber = row(atY: min(cy, size.height - 0.001)) ?? PaperSpec.yearRows
        return DayKey(year: year, month: month, day: min(dayNumber, DayKey.daysInMonth(year: year, month: month)))
    }

    static func columnX(month: Int) -> CGFloat {
        PaperSpec.yearGutter + CGFloat(month - 1) * PaperSpec.yearColumnWidth
    }
}

/// Pure layout of the year page (DESIGN §2.2 / §2.6, M3A_CONTRACT §1.8).
public enum YearLayoutEngine {
    /// Height of a row: `min(400, max(60, 16 + lanes × 18 + 8, inkBottom + 12))`.
    public static func rowHeight(laneCount: Int, inkBottom: CGFloat) -> CGFloat {
        let lanes = CGFloat(max(0, laneCount))
        let content = PaperSpec.yearHeader + lanes * PaperSpec.yearLaneStep + PaperSpec.yearInkMargin
        let ink = LayoutMath.sanitizedInk(inkBottom) + PaperSpec.inkPad
        return min(PaperSpec.yearRowMax, max(PaperSpec.yearRowBase, max(content, ink)))
    }

    /// Lane packing of month `month` (1…12): `packAllDayLanes` over every day of the month, so a
    /// multi-day event keeps one lane across its days (columns are 0-based day indices).
    public static func monthSpans(events: [LayoutEvent], year: Int, month: Int, calendar: Calendar) -> [(event: LayoutEvent, startCol: Int, endCol: Int, lane: Int)] {
        guard (1...12).contains(month) else { return [] }
        let count = DayKey.daysInMonth(year: year, month: month)
        let days = (1...count).map { DayKey(year: year, month: month, day: $0) }
        return MonthLayoutEngine.packAllDayLanes(events: events, days: days, calendar: calendar)
    }

    /// Lane metrics of one cell: thinned only when its row reached the cap because of this cell's
    /// own lanes (`16 + lanes × 18 + 8 > 400`); other cells of the same row are not affected.
    static func cellLaneMetrics(laneCount: Int) -> LaneMetrics {
        if PaperSpec.yearHeader + CGFloat(laneCount) * PaperSpec.yearLaneStep + PaperSpec.yearInkMargin > PaperSpec.yearRowMax {
            return LanePacking.metrics(
                laneCount: laneCount,
                lane: PaperSpec.yearLane,
                gap: PaperSpec.yearLaneGap,
                available: PaperSpec.yearRowMax - PaperSpec.yearHeader - PaperSpec.yearInkMargin
            )
        }
        return .plain(lane: PaperSpec.yearLane, gap: PaperSpec.yearLaneGap)
    }

    public static func layout(_ input: YearLayoutInput) -> YearPageLayout {
        let calendar = input.calendar
        let year = input.year
        let today = DayKey(input.now, calendar: calendar)
        let months = 1...PaperSpec.yearColumns
        let dayNumbers = 1...PaperSpec.yearRows

        // Lanes per month column, and the lanes needed by each (month, day) cell.
        let spansByMonth = months.map { monthSpans(events: input.events, year: year, month: $0, calendar: calendar) }
        var needed = Array(repeating: Array(repeating: 0, count: PaperSpec.yearRows + 1), count: PaperSpec.yearColumns + 1)
        for m in months {
            for span in spansByMonth[m - 1] {
                guard span.startCol <= span.endCol else { continue }
                for index in span.startCol...span.endCol where index + 1 <= PaperSpec.yearRows {
                    needed[m][index + 1] = max(needed[m][index + 1], span.lane + 1)
                }
            }
        }

        // Rows: the busiest month and the deepest handwriting of the 12 cells decide the height.
        var rows: [YearRow] = []
        var y: CGFloat = 0
        for d in dayNumbers {
            var lanes = 0
            var ink: CGFloat = 0
            for m in months {
                lanes = max(lanes, needed[m][d])
                ink = max(ink, LayoutMath.sanitizedInk(input.inkBottoms[.yearDay(month: m, day: d)] ?? 0))
            }
            let height = rowHeight(laneCount: lanes, inkBottom: ink)
            rows.append(YearRow(dayNumber: d, frame: CGRect(x: 0, y: y, width: PaperSpec.yearWidth, height: height), laneCount: lanes))
            y += height
        }
        let totalHeight = y

        // Cells, invalid dates and the weekday-letter labels.
        var allDays: [DayKey] = []
        for m in months {
            for d in 1...DayKey.daysInMonth(year: year, month: m) { allDays.append(DayKey(year: year, month: m, day: d)) }
        }
        let holidays = JapaneseHolidays.names(for: allDays)
        var cells: [CellKey: CGRect] = [:]
        var invalid: [CellKey] = []
        var labels: [DateLabel] = []
        for m in months {
            let daysInMonth = DayKey.daysInMonth(year: year, month: m)
            let cellX = YearPageLayout.columnX(month: m)
            for d in dayNumbers {
                let key = CellKey.yearDay(month: m, day: d)
                let row = rows[d - 1]
                let frame = CGRect(x: cellX, y: row.frame.minY, width: PaperSpec.yearColumnWidth, height: row.frame.height)
                cells[key] = frame
                if d > daysInMonth {
                    invalid.append(key)
                    continue
                }
                let day = DayKey(year: year, month: m, day: d)
                let holiday = holidays[day]
                labels.append(DateLabel(
                    day: day,
                    frame: CGRect(x: cellX, y: frame.minY, width: 40, height: 28),
                    isToday: day == today,
                    inMonth: true,
                    tone: LayoutMath.tone(of: day, holiday: holiday),
                    holidayName: holiday
                ))
            }
        }

        // Chips: one per covered day, same lane within the month column, thinned per cell.
        let chipX = PaperSpec.yearColumnWidth * PaperSpec.yearChipLeft
        let chipWidth = PaperSpec.yearColumnWidth * (1 - PaperSpec.yearChipLeft) - PaperSpec.yearPad
        var chips: [YearChip] = []
        for m in months {
            let daysInMonth = DayKey.daysInMonth(year: year, month: m)
            let cellX = YearPageLayout.columnX(month: m)
            for span in spansByMonth[m - 1] {
                guard span.startCol <= span.endCol else { continue }
                for index in span.startCol...span.endCol {
                    let d = index + 1
                    guard d >= 1, d <= daysInMonth else { continue }
                    let day = DayKey(year: year, month: m, day: d)
                    let metrics = cellLaneMetrics(laneCount: needed[m][d])
                    let cellY = rows[d - 1].frame.minY
                    let frame = CGRect(
                        x: cellX + chipX,
                        y: cellY + PaperSpec.yearHeader + CGFloat(span.lane) * metrics.step,
                        width: chipWidth,
                        height: metrics.lane
                    )
                    let dayStart = day.startOfDay(in: calendar)
                    let dayEnd = day.adding(days: 1).startOfDay(in: calendar)
                    let continuesDown = span.event.end > dayEnd
                    var linkToY: CGFloat?
                    if continuesDown && d < daysInMonth {
                        let next = cellLaneMetrics(laneCount: needed[m][d + 1])
                        linkToY = rows[d].frame.minY + PaperSpec.yearHeader + CGFloat(span.lane) * next.step
                    }
                    chips.append(YearChip(
                        eventId: span.event.id,
                        frame: frame,
                        day: day,
                        lane: span.lane,
                        continuesUp: span.event.start < dayStart,
                        continuesDown: continuesDown,
                        linkToY: linkToY,
                        title: span.event.title,
                        colorHex: span.event.colorHex,
                        isThin: metrics.lane < PaperSpec.yearThinLane,
                        fontScale: metrics.fontScale
                    ))
                }
            }
        }

        let todayCell: CellKey? = today.year == year && (1...12).contains(today.month) && (1...31).contains(today.day)
            ? .yearDay(month: today.month, day: today.day)
            : nil

        return YearPageLayout(
            pageId: PageNavigation.pageId(.year, focus: DayKey(year: year, month: 1, day: 1)),
            year: year,
            size: CGSize(width: PaperSpec.yearWidth, height: totalHeight),
            rows: rows,
            cells: cells,
            invalidCells: invalid,
            chips: chips,
            dateLabels: labels,
            todayCell: todayCell
        )
    }
}
