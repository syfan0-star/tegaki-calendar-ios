import Foundation

/// One calendar day (year / month / day) in the proleptic Gregorian calendar.
///
/// A `DayKey` carries no time of day and no time zone, so date arithmetic on it never depends on
/// the device clock settings. The web version does the same with 'YYYY-MM-DD' strings and UTC
/// arithmetic; here the day number (days since 1970-01-01) plays that role.
public struct DayKey: Hashable, Comparable, CustomStringConvertible, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Builds the day from a day number (days since 1970-01-01, negative before).
    /// Howard Hinnant's `civil_from_days` algorithm.
    public init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097                                     // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365 // [0, 399]
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)               // [0, 365]
        let mp = (5 * doy + 2) / 153                                    // [0, 11]
        let d = doy - (153 * mp + 2) / 5 + 1                            // [1, 31]
        let m = mp < 10 ? mp + 3 : mp - 9                               // [1, 12]
        self.init(year: m <= 2 ? y + 1 : y, month: m, day: d)
    }

    /// Parses 'YYYY-MM-DD'; nil for anything else (or an impossible date).
    public init?(ymd: String) {
        let parts = ymd.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        let key = DayKey(year: y, month: m, day: d)
        guard key.isValid else { return nil }
        self = key
    }

    /// Days since 1970-01-01 (Howard Hinnant's `days_from_civil`).
    public var dayNumber: Int {
        Self.dayNumber(year: year, month: month, day: day)
    }

    public static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400                                 // [0, 399]
        let mp = month > 2 ? month - 3 : month + 9              // [0, 11]
        let doy = (153 * mp + 2) / 5 + day - 1                  // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy         // [0, 146096]
        return era * 146_097 + doe - 719_468
    }

    /// Day of week: 0 = Sunday, 1 = Monday, ... 6 = Saturday.
    public var weekday: Int {
        let r = (dayNumber + 4) % 7 // 1970-01-01 was a Thursday (4)
        return r < 0 ? r + 7 : r
    }

    /// True when the stored year/month/day form a real date.
    public var isValid: Bool {
        month >= 1 && month <= 12 && day >= 1 && day <= Self.daysInMonth(year: year, month: month)
    }

    public func adding(days: Int) -> DayKey {
        DayKey(dayNumber: dayNumber + days)
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    /// 'YYYY-MM-DD'
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Bridging to Foundation dates

    /// A Gregorian calendar in the device time zone (never the device's preferred calendar,
    /// which could be the Japanese imperial calendar).
    public static var deviceCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    /// The local calendar day that contains `date`.
    public init(_ date: Date, calendar: Calendar = DayKey.deviceCalendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(calendar: Calendar = DayKey.deviceCalendar) -> DayKey {
        DayKey(Date(), calendar: calendar)
    }

    /// Local midnight at the start of this day.
    public func startOfDay(in calendar: Calendar = DayKey.deviceCalendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: Double(dayNumber) * 86_400)
    }
}

/// A year + month pair (e.g. 2026年10月).
public struct YearMonth: Hashable, Sendable {
    public var year: Int
    public var month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public static func current(calendar: Calendar = DayKey.deviceCalendar) -> YearMonth {
        let today = DayKey.today(calendar: calendar)
        return YearMonth(year: today.year, month: today.month)
    }

    public var next: YearMonth {
        month == 12 ? YearMonth(year: year + 1, month: 1) : YearMonth(year: year, month: month + 1)
    }

    public var previous: YearMonth {
        month == 1 ? YearMonth(year: year - 1, month: 12) : YearMonth(year: year, month: month - 1)
    }

    public var firstDay: DayKey { DayKey(year: year, month: month, day: 1) }

    public var lastDay: DayKey { DayKey(year: year, month: month, day: DayKey.daysInMonth(year: year, month: month)) }

    /// "2026年10月"
    public var title: String { "\(year)年\(month)月" }

    /// Web-compatible ink page id of the Monday-start month page: "m1-2026-10".
    public var inkPageId: String { String(format: "m1-%04d-%02d", year, month) }

    public func contains(_ day: DayKey) -> Bool {
        day.year == year && day.month == month
    }
}
