import Foundation
@_exported import DayKit

/// The Monday-start grid of one month, as the month page draws it.
public struct MonthGrid: Equatable, Sendable {
    public let year: Int
    public let month: Int
    /// Exactly 42 days (6 weeks), starting on the Monday on or before the 1st of the month.
    public let days: [DayKey]
    /// Number of week rows (4...6) needed to show every day of the month.
    public let rowCount: Int

    public init(year: Int, month: Int, days: [DayKey], rowCount: Int) {
        self.year = year
        self.month = month
        self.days = days
        self.rowCount = rowCount
    }

    /// The rows that are actually shown (`rowCount` rows of 7 days).
    public var rows: [[DayKey]] {
        (0..<rowCount).map { row in Array(days[(row * MonthLayout.columns)..<((row + 1) * MonthLayout.columns)]) }
    }

    /// All 6 rows of 7 days (the month page always draws 42 days, DESIGN §2.3).
    public var allRows: [[DayKey]] {
        (0..<(MonthLayout.gridDayCount / MonthLayout.columns)).map { row in
            Array(days[(row * MonthLayout.columns)..<((row + 1) * MonthLayout.columns)])
        }
    }

    public var firstDay: DayKey { days[0] }

    /// Last day of the last shown row.
    public var lastVisibleDay: DayKey { days[rowCount * MonthLayout.columns - 1] }

    public func contains(_ day: DayKey) -> Bool {
        day.year == year && day.month == month
    }
}

/// Pure layout rules for the month page (Monday-start, 7 columns). No UI, no time zones.
public enum MonthLayout {
    public static let columns = 7
    public static let gridDayCount = 42

    /// The Monday on or before `day` (weekday 1 = Monday).
    public static func mondayOnOrBefore(_ day: DayKey) -> DayKey {
        day.adding(days: -((day.weekday + 6) % 7))
    }

    /// First cell of the 42-day grid for the month.
    public static func firstGridDay(year: Int, month: Int) -> DayKey {
        mondayOnOrBefore(DayKey(year: year, month: month, day: 1))
    }

    /// Number of rows (4...6) needed to show every day of the month, Monday-start.
    public static func rowCount(year: Int, month: Int) -> Int {
        let offset = (DayKey(year: year, month: month, day: 1).weekday + 6) % 7 // 0 = Monday
        let dayCount = DayKey.daysInMonth(year: year, month: month)
        return (offset + dayCount + columns - 1) / columns
    }

    public static func grid(year: Int, month: Int) -> MonthGrid {
        let first = firstGridDay(year: year, month: month)
        let days = (0..<gridDayCount).map { first.adding(days: $0) }
        return MonthGrid(year: year, month: month, days: days, rowCount: rowCount(year: year, month: month))
    }

    public static func grid(for yearMonth: YearMonth) -> MonthGrid {
        grid(year: yearMonth.year, month: yearMonth.month)
    }
}
