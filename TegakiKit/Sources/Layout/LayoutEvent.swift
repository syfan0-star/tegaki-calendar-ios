import Foundation
import CoreGraphics
import Holidays

/// Normalized calendar event (the web version's CalEvent). Times are absolute instants; the layout
/// interprets them in the calendar passed with `MonthLayoutInput` (device time zone by default).
///
/// Conventions (same as the web version's event-layout.js):
/// - an event occupies [start, end); back-to-back events do not overlap;
/// - an all-day event's `end` is **the next day's 0:00 (exclusive)**, never 23:59:59;
/// - a zero-length or inverted event occupies the instant `start` and belongs to the day containing it.
public struct LayoutEvent: Hashable, Sendable {
    public var id: String
    public var title: String
    public var allDay: Bool
    public var start: Date
    public var end: Date
    public var colorHex: String
    public var calendarId: String

    public init(id: String, title: String, allDay: Bool, start: Date, end: Date, colorHex: String, calendarId: String) {
        self.id = id
        self.title = title
        self.allDay = allDay
        self.start = start
        self.end = end
        self.colorHex = colorHex
        self.calendarId = calendarId
    }

    /// Duration in seconds, never negative.
    public var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    /// Does the event intersect the half-open interval [a, b)?
    public func overlaps(_ a: Date, _ b: Date) -> Bool {
        if end <= start { return start >= a && start < b }
        return start < b && end > a
    }
}

/// Input of the month page layout.
public struct MonthLayoutInput: Sendable {
    /// The month shown.
    public var month: YearMonth
    /// Events of the visible calendars (all-day and timed).
    public var events: [LayoutEvent]
    /// Bottom edge of the handwriting of each cell (cell-relative lu). Missing cells count as 0.
    public var inkBottoms: [CellKey: CGFloat]
    /// The current time (decides the 「今日」 mark).
    public var now: Date
    /// The calendar used to turn event instants into local days (device time zone by default).
    public var calendar: Calendar
    /// Where the colour and the name of a day come from; never the shape of the paper (D9, §5.4).
    public var holidays: HolidayCalendar
    /// The words of the chips (D9, §3.1 rule 4).
    public var words: LayoutWords
    /// The first column of the 42-day grid (§10.1). The cell keys stay dates, so strokes follow their
    /// date (K-11 rule 4); a day of the other grid only is not on this page's paper (D17).
    public var weekStart: WeekStart
    /// 1.4.3 (ア, docs/R1_4_3_CONTRACT.md §2.1, §4.1; `SpanAlign.Floors.monthGrid`): the floor of the grid's
    /// bottom (= the separator line = `memo.minY`). Only the last (6th) row grows to reach it, up to
    /// `PaperSpec.monthRowMax`; past that the row stops at 1,200 lu and `memo.minY` stays above the floor.
    /// Rows 1–5 and the 6th row's top never move. 0 (or not finite, or negative) is no floor.
    public var gridFloor: CGFloat
    /// 1.4.3 (ア and イ; `SpanAlign.Floors.monthMemo`): the floor of the memo's height
    /// (`max(PaperGrowth.tailHeight, memoFloor)`); the memo's origin stays at the grid's bottom. 0 is no floor.
    public var memoFloor: CGFloat
    /// 1.4.3 (イ; `SpanAlign.Floors.monthRows`): the floors of the 6 rows' heights, row r's height being
    /// `min(PaperSpec.monthRowMax, max(its own, rowFloors[r]))`. A missing, non-finite or negative value is
    /// no floor; empty is none.
    public var rowFloors: [CGFloat]

    /// The floors are trailing arguments with defaults (the day's and the week's `extraFloor` are too):
    /// left out, the page is 1.4.2's, `==`.
    public init(month: YearMonth, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar, holidays: HolidayCalendar = .japan, words: LayoutWords = .japanese, weekStart: WeekStart = .monday, gridFloor: CGFloat = 0, memoFloor: CGFloat = 0, rowFloors: [CGFloat] = []) {
        self.month = month
        self.events = events
        self.inkBottoms = inkBottoms
        self.now = now
        self.calendar = calendar
        self.holidays = holidays
        self.words = words
        self.weekStart = weekStart
        self.gridFloor = gridFloor
        self.memoFloor = memoFloor
        self.rowFloors = rowFloors
    }

    /// This input with the month floors of `floors` (`monthGrid`, `monthMemo`, `monthRows`); the other
    /// fields are kept. `SpanAlign.Floors.none` gives the floors left out.
    public func floored(by floors: SpanAlign.Floors) -> MonthLayoutInput {
        var input = self
        input.gridFloor = floors.monthGrid
        input.memoFloor = floors.monthMemo
        input.rowFloors = floors.monthRows
        return input
    }
}
