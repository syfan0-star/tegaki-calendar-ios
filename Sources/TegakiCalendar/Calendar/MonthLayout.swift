import Foundation

/// A year + month pair (e.g. 2026年10月).
struct YearMonth: Hashable {
    var year: Int
    var month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    static func current(calendar: Calendar = DayKey.deviceCalendar) -> YearMonth {
        let today = DayKey.today(calendar: calendar)
        return YearMonth(year: today.year, month: today.month)
    }

    var next: YearMonth {
        month == 12 ? YearMonth(year: year + 1, month: 1) : YearMonth(year: year, month: month + 1)
    }

    var previous: YearMonth {
        month == 1 ? YearMonth(year: year - 1, month: 12) : YearMonth(year: year, month: month - 1)
    }

    var firstDay: DayKey { DayKey(year: year, month: month, day: 1) }

    var lastDay: DayKey { DayKey(year: year, month: month, day: DayKey.daysInMonth(year: year, month: month)) }

    /// "2026年10月"
    var title: String { "\(year)年\(month)月" }
}

/// The Monday-start grid of one month, as the month page draws it.
struct MonthGrid: Equatable {
    let year: Int
    let month: Int
    /// Exactly 42 days (6 weeks), starting on the Monday on or before the 1st of the month.
    let days: [DayKey]
    /// Number of week rows (4...6) needed to show every day of the month.
    let rowCount: Int

    /// The rows that are actually shown (`rowCount` rows of 7 days).
    var rows: [[DayKey]] {
        (0..<rowCount).map { row in Array(days[(row * MonthLayout.columns)..<((row + 1) * MonthLayout.columns)]) }
    }

    var firstDay: DayKey { days[0] }

    /// Last day of the last shown row.
    var lastVisibleDay: DayKey { days[rowCount * MonthLayout.columns - 1] }

    func contains(_ day: DayKey) -> Bool {
        day.year == year && day.month == month
    }
}

/// Pure layout rules for the month page (Monday-start, 7 columns). No UI, no time zones.
enum MonthLayout {
    static let columns = 7
    static let gridDayCount = 42

    /// The Monday on or before `day` (weekday 1 = Monday).
    static func mondayOnOrBefore(_ day: DayKey) -> DayKey {
        day.adding(days: -((day.weekday + 6) % 7))
    }

    /// First cell of the 42-day grid for the month.
    static func firstGridDay(year: Int, month: Int) -> DayKey {
        mondayOnOrBefore(DayKey(year: year, month: month, day: 1))
    }

    /// Number of rows (4...6) needed to show every day of the month, Monday-start.
    static func rowCount(year: Int, month: Int) -> Int {
        let offset = (DayKey(year: year, month: month, day: 1).weekday + 6) % 7 // 0 = Monday
        let dayCount = DayKey.daysInMonth(year: year, month: month)
        return (offset + dayCount + columns - 1) / columns
    }

    static func grid(year: Int, month: Int) -> MonthGrid {
        let first = firstGridDay(year: year, month: month)
        let days = (0..<gridDayCount).map { first.adding(days: $0) }
        return MonthGrid(year: year, month: month, days: days, rowCount: rowCount(year: year, month: month))
    }

    static func grid(for yearMonth: YearMonth) -> MonthGrid {
        grid(year: yearMonth.year, month: yearMonth.month)
    }
}
