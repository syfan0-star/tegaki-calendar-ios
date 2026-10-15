import Foundation
import CoreGraphics

/// The four pages of the calendar.
public enum PageKind: String, CaseIterable, Codable, Sendable {
    case day, week, month, year
}

/// A horizontal band of a page used as the reference of the scroll correction (DESIGN §3.5).
/// Month: "row:0"…"row:5", "memo". Week / day: "grid" (the "allday" band left the paper in M4b; the
/// value stays as a type, the week / day pages no longer return it). Year: "row:1"…"row:31".
public struct PageBand: Hashable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }

    /// "row:<index>" (month: 0…5, year: the day number 1…31).
    public static func row(_ index: Int) -> PageBand { PageBand(raw: "row:\(index)") }
    public static let memo = PageBand(raw: "memo")
    public static let allDay = PageBand(raw: "allday")
    public static let grid = PageBand(raw: "grid")

    /// The index of a "row:<index>" band; nil for the others.
    public var rowIndex: Int? {
        guard raw.hasPrefix("row:") else { return nil }
        return Int(raw.dropFirst(4))
    }

    public var description: String { raw }
}

/// What a finger tap on the paper hits.
public enum HitTarget: Equatable, Sendable {
    /// A month bar, a week / day band bar or a year chip (event id).
    case allDayBar(String)
    /// A month chip (event id).
    case timedChip(String)
    /// A box on the week / day time grid (event id).
    case timedBox(String)
    /// The month page's 「+n件」 chip.
    case moreChips(DayKey)
    /// A month date number, a year weekday letter or a thin year chip → the day page.
    case date(DayKey)
}

/// The current-time line (week / day). `y` is in paper coordinates (the grid starts at the paper's
/// top since M4b); `x0…x1` is today's column (week) or the timeline column (day).
public struct NowLine: Equatable, Sendable {
    public var y: CGFloat
    public var x0: CGFloat
    public var x1: CGFloat
    /// Wall-clock minutes of the day (0…1439).
    public var minute: Int

    public init(y: CGFloat, x0: CGFloat, x1: CGFloat, minute: Int) {
        self.y = y
        self.x0 = x0
        self.x1 = x1
        self.minute = minute
    }
}

/// A timed event box on the time grid (the web version's createEventBox + timedBoxRect).
public struct TimedEventBox: Equatable, Sendable {
    public var eventId: String
    /// Paper rect (the grid's top is already added).
    public var frame: CGRect
    /// The day column the box belongs to.
    public var day: DayKey
    /// Visual minutes (0…1440, clipped to the day, at least 15 minutes).
    public var startMinute: Int
    public var endMinute: Int
    /// Overlap column (0-based) and the number of columns of its cluster.
    public var column: Int
    public var columns: Int
    public var title: String
    /// "9:00〜10:30" (the event's real start and end, web formatTimeRangeJa).
    public var timeText: String
    /// "9:00" (for the one-line mode, web formatTimeJa).
    public var startText: String
    public var colorHex: String
    /// `event.end <= now` (drawn faded).
    public var isPast: Bool

    public init(eventId: String, frame: CGRect, day: DayKey, startMinute: Int, endMinute: Int, column: Int, columns: Int, title: String, timeText: String, startText: String, colorHex: String, isPast: Bool) {
        self.eventId = eventId
        self.frame = frame
        self.day = day
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.column = column
        self.columns = columns
        self.title = title
        self.timeText = timeText
        self.startText = startText
        self.colorHex = colorHex
        self.isPast = isPast
    }
}

/// The geometry of one page in paper coordinates (lu). 担当 I uses it only as `any PageLayout`.
/// Deliberately not `Equatable` (existentials cannot be compared); the concrete types are.
public protocol PageLayout: Sendable {
    var kind: PageKind { get }
    /// "d-2026-10-04" / "w-2026-09-28" / "m1-2026-10" / "y-2026".
    var pageId: String { get }
    var size: CGSize { get }
    /// Rect of every ink cell of the page.
    var cells: [CellKey: CGRect] { get }
    var dateLabels: [DateLabel] { get }
    /// Empty on the year page (which has `YearPageLayout.chips` instead).
    var allDayBars: [AllDayBar] { get }
    /// Week and day only; empty elsewhere.
    var timedBoxes: [TimedEventBox] { get }
    /// Week and day, only while today is on the page; nil elsewhere.
    var nowLine: NowLine? { get }
    /// The cell containing the point; nil when the point is in no cell (outside the paper included).
    func cell(at point: CGPoint) -> CellKey?
    /// The cell a stroke belongs to, from the center of its bounds. Never nil: every per-page
    /// fallback (outside the paper, the time gutter, the year's day-number gutter) lives here.
    func inkCell(forCenter point: CGPoint) -> CellKey
    /// Does handwriting in the cell make it grow (M3A_CONTRACT §1.10)?
    func growsWithInk(_ cell: CellKey) -> Bool
    /// What a finger tap hits.
    func hit(at point: CGPoint) -> HitTarget?
    /// The band containing paper y; nil outside the paper.
    func band(atY y: CGFloat) -> PageBand?
    /// Top edge of a band; nil for a band the page does not have.
    func bandTop(_ band: PageBand) -> CGFloat?
    /// Paper rect → the event it means (web rectToEventRange, M3B_CONTRACT §1). `now` only decides
    /// the day the month page's memo area stands for. nil only for a non-finite rect (a rect outside
    /// the paper snaps to the nearest cell / column).
    func eventRange(for rect: CGRect, now: Date, calendar: Calendar) -> EventRange?
    /// The paper rect an event range occupies (web snapEventRect, the 予定 tool's live preview); nil
    /// when the range is not on this page (another week's day, another year, …).
    func snapRect(for range: EventRange, calendar: Calendar) -> CGRect?
}

extension PageLayout {
    /// True when kind, pageId, size and the cell rects are the same (担当 I decides with it whether
    /// the drawing has to be recomposed).
    public func sameGeometry(as other: any PageLayout) -> Bool {
        kind == other.kind && pageId == other.pageId && size == other.size && cells == other.cells
    }
}

public enum PageScroll {
    /// DESIGN §3.5 generalized to every page: how far the band containing `topVisibleY` in `old`
    /// moved in `new` (paper lu; the caller adds it to `contentOffset.y` × zoomScale). 0 when
    /// `old.band(atY:)` is nil (outside the paper) or `new` lacks that band.
    public static func scrollDelta(old: any PageLayout, new: any PageLayout, topVisibleY: CGFloat) -> CGFloat {
        guard topVisibleY.isFinite, let band = old.band(atY: topVisibleY) else { return 0 }
        guard let oldTop = old.bandTop(band), let newTop = new.bandTop(band) else { return 0 }
        return newTop - oldTop
    }
}

// MARK: - Shared helpers for the engines

enum LayoutMath {
    /// `v` clamped to [lo, hi]; `lo` when NaN.
    static func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        if v.isNaN { return lo }
        return min(max(v, lo), hi)
    }

    /// Finite and non-negative, else 0 (same rule as the month engine's `sanitized`).
    static func sanitizedInk(_ v: CGFloat) -> CGFloat {
        v.isFinite ? max(0, v) : 0
    }

    /// Tone of a date number: Sunday or holiday red, Saturday blue.
    static func tone(of day: DayKey, holiday: String?) -> DayTone {
        if holiday != nil || day.weekday == 0 { return .sundayOrHoliday }
        if day.weekday == 6 { return .saturday }
        return .normal
    }
}
