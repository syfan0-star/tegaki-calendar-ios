import Foundation
import CoreGraphics

/// One week row of the month page.
public struct RowLayout: Equatable, Sendable {
    public var index: Int
    /// Paper rect of the row: x 0, width 1400.
    public var frame: CGRect
    /// The 7 days of the row, Monday first.
    public var days: [DayKey]
    /// Number of all-day lanes used by the row (0 when it has no all-day event).
    public var laneCount: Int
    /// Largest number of **shown** timed chips of the row's 7 days (at most `PaperSpec.timedChipCap`).
    public var maxChips: Int

    public init(index: Int, frame: CGRect, days: [DayKey], laneCount: Int, maxChips: Int) {
        self.index = index
        self.frame = frame
        self.days = days
        self.laneCount = laneCount
        self.maxChips = maxChips
    }
}

/// An all-day event bar in one week row (a multi-day event is one bar per row it crosses).
public struct AllDayBar: Equatable, Sendable {
    public var eventId: String
    public var frame: CGRect
    public var row: Int
    public var lane: Int
    /// The event started before this row's Monday (draw an open left end).
    public var continuesLeft: Bool
    /// The event continues after this row's Sunday (draw an open right end).
    public var continuesRight: Bool
    public var colorHex: String
    public var title: String

    public init(eventId: String, frame: CGRect, row: Int, lane: Int, continuesLeft: Bool, continuesRight: Bool, colorHex: String, title: String) {
        self.eventId = eventId
        self.frame = frame
        self.row = row
        self.lane = lane
        self.continuesLeft = continuesLeft
        self.continuesRight = continuesRight
        self.colorHex = colorHex
        self.title = title
    }
}

/// A one-line timed event chip ("9:00 会議") or the 「+n件」 chip (`moreCount > 0`, `eventId == nil`).
public struct TimedChip: Equatable, Sendable {
    public var eventId: String?
    public var frame: CGRect
    public var day: DayKey
    /// "9:00" (start time). "〜11:00" for the tail of an overnight event, "" when it covers the whole day.
    public var timeText: String
    public var title: String
    public var colorHex: String
    /// Number of hidden events behind a 「+n件」 chip; 0 for an ordinary chip.
    public var moreCount: Int

    public init(eventId: String?, frame: CGRect, day: DayKey, timeText: String, title: String, colorHex: String, moreCount: Int) {
        self.eventId = eventId
        self.frame = frame
        self.day = day
        self.timeText = timeText
        self.title = title
        self.colorHex = colorHex
        self.moreCount = moreCount
    }

    public var isMore: Bool { moreCount > 0 }
}

/// Colour class of a date number: weekday, Saturday (blue), Sunday or holiday (red).
public enum DayTone: Equatable, Sendable {
    case normal, saturday, sundayOrHoliday
}

/// The date number of one cell.
public struct DateLabel: Equatable, Sendable {
    public var day: DayKey
    public var frame: CGRect
    public var isToday: Bool
    public var inMonth: Bool
    public var tone: DayTone
    public var holidayName: String?

    public init(day: DayKey, frame: CGRect, isToday: Bool, inMonth: Bool, tone: DayTone, holidayName: String?) {
        self.day = day
        self.frame = frame
        self.isToday = isToday
        self.inMonth = inMonth
        self.tone = tone
        self.holidayName = holidayName
    }
}

// `HitTarget` lives in PageLayout.swift since M3a (it gained `.timedBox` for the week / day pages).

/// The month page in paper coordinates (lu).
public struct MonthPageLayout: Equatable, Sendable {
    /// Paper size: width 1400, height = sum of the 6 rows + memo area.
    public var size: CGSize
    /// The 6 week rows, top to bottom.
    public var rows: [RowLayout]
    /// The memo area below the grid.
    public var memo: CGRect
    /// Rect of every cell: 42 days + `.memo`.
    public var cells: [CellKey: CGRect]
    public var allDayBars: [AllDayBar]
    public var timedChips: [TimedChip]
    public var dateLabels: [DateLabel]

    public init(size: CGSize, rows: [RowLayout], memo: CGRect, cells: [CellKey: CGRect], allDayBars: [AllDayBar], timedChips: [TimedChip], dateLabels: [DateLabel]) {
        self.size = size
        self.rows = rows
        self.memo = memo
        self.cells = cells
        self.allDayBars = allDayBars
        self.timedChips = timedChips
        self.dateLabels = dateLabels
    }

    /// The cell under a paper point (memo area included); nil outside the paper. The right edge
    /// (x == 1400) belongs to the last column, as in the web version.
    public func cell(at point: CGPoint) -> CellKey? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        guard point.x >= 0, point.x <= size.width, point.y >= 0, point.y < size.height else { return nil }
        for row in rows where point.y >= row.frame.minY && point.y < row.frame.maxY {
            let col = Int(floor(point.x / PaperSpec.monthColumnWidth))
            let clamped = min(PaperSpec.monthColumns - 1, max(0, col))
            guard clamped < row.days.count else { return nil }
            return .day(row.days[clamped])
        }
        if point.y >= memo.minY && point.y < memo.maxY { return .memo }
        return nil
    }

    /// The tappable thing under a paper point: chips first (「+n件」 → `.moreChips(day)`), then bars,
    /// then date numbers. nil when the point hits nothing.
    public func hit(at point: CGPoint) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        for chip in timedChips where chip.frame.contains(point) {
            if let id = chip.eventId, chip.moreCount == 0 { return .timedChip(id) }
            return .moreChips(chip.day)
        }
        for bar in allDayBars where bar.frame.contains(point) {
            return .allDayBar(bar.eventId)
        }
        for label in dateLabels where label.frame.contains(point) {
            return .date(label.day)
        }
        return nil
    }

    /// Row index containing paper y, or nil (memo area / outside).
    public func rowIndex(atY y: CGFloat) -> Int? {
        rows.first(where: { y >= $0.frame.minY && y < $0.frame.maxY })?.index
    }
}

// MARK: - PageLayout conformance (M3A_CONTRACT §1.5; the M2 API above is unchanged)

extension MonthPageLayout: PageLayout {
    public var kind: PageKind { .month }

    /// The month shown, derived from the grid: the 7th cell of the first row always lies in the
    /// month (the first row contains the 1st).
    public var month: YearMonth {
        if let first = rows.first, first.days.count >= 7 {
            let d = first.days[6]
            return YearMonth(year: d.year, month: d.month)
        }
        if let d = rows.first?.days.first ?? cells.keys.compactMap(\.day).min() {
            return YearMonth(year: d.year, month: d.month)
        }
        return YearMonth(year: 1970, month: 1)
    }

    /// "m1-2026-10" (`YearMonth.inkPageId`).
    public var pageId: String { month.inkPageId }

    public var timedBoxes: [TimedEventBox] { [] }

    public var nowLine: NowLine? { nil }

    /// Same as M2's `InkLedger.cellFor`: `cell(at:)`, else the point clamped into the paper, else
    /// the memo area.
    public func inkCell(forCenter point: CGPoint) -> CellKey {
        if let cell = cell(at: point) { return cell }
        let clamped = CGPoint(
            x: LayoutMath.clamp(point.x, 0, max(size.width - 0.001, 0)),
            y: LayoutMath.clamp(point.y, 0, max(size.height - 0.001, 0))
        )
        if let cell = cell(at: clamped) { return cell }
        return .memo
    }

    /// The 42 day cells and the memo area grow with handwriting.
    public func growsWithInk(_ cell: CellKey) -> Bool {
        cells[cell] != nil
    }

    /// "row:r" / "memo" / nil.
    public func band(atY y: CGFloat) -> PageBand? {
        guard y.isFinite else { return nil }
        if let index = rowIndex(atY: y) { return .row(index) }
        if y >= memo.minY && y < memo.maxY { return .memo }
        return nil
    }

    public func bandTop(_ band: PageBand) -> CGFloat? {
        if band == .memo { return memo.minY }
        guard let index = band.rowIndex, index >= 0, index < rows.count else { return nil }
        return rows[index].frame.minY
    }

    // MARK: Rect → event, event → rect (M3B_CONTRACT §1.4)

    /// An all-day event on the cell under the rect's centre (clamped onto the paper). A centre in the
    /// memo area (or below the paper) means the memo day: today when today is in this month, else
    /// the 1st.
    public func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange? {
        guard let r = EventGeometry.normalized(rect), let day = eventDay(for: r, now: now, calendar: calendar) else { return nil }
        return .allDay(day, calendar: calendar)
    }

    /// The cell of the day `range` starts on (a timed range too); nil when that day is not on the grid.
    public func snapRect(for range: EventRange, calendar: Calendar) -> CGRect? {
        cells[.day(DayKey(range.start, calendar: calendar))]
    }

    /// The day a rect means (web monthCellForRect + monthMemoCell): `cx` clamped to [0, W], `cy` to
    /// [0, H]; `cy ≥ memo.minY` → the memo day; else the cell under (cx, cy).
    public func eventDay(for rect: CGRect, now: Date, calendar: Calendar) -> DayKey? {
        guard let r = EventGeometry.normalized(rect) else { return nil }
        let cx = LayoutMath.clamp(r.midX, 0, size.width)
        let cy = LayoutMath.clamp(r.midY, 0, size.height)
        if cy >= memo.minY {
            let today = DayKey(now, calendar: calendar)
            return month.contains(today) ? today : month.firstDay
        }
        if let day = cell(at: CGPoint(x: cx, y: cy))?.day { return day }
        // Only with a degenerate layout (no rows above the memo area): the first day of the grid.
        return rows.first?.days.first
    }
}
