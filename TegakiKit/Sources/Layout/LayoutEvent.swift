import Foundation
import CoreGraphics

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

    public init(month: YearMonth, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar) {
        self.month = month
        self.events = events
        self.inkBottoms = inkBottoms
        self.now = now
        self.calendar = calendar
    }
}
