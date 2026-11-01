// a21e469 TegakiKit/Sources/DayKit/DayKey.swift:1-93  DayKeyV10
import Foundation

/// One calendar day (year / month / day) in the proleptic Gregorian calendar.
///
/// A `DayKeyV10` carries no time of day and no time zone, so date arithmetic on it never depends on
/// the device clock settings. The web version does the same with 'YYYY-MM-DD' strings and UTC
/// arithmetic; here the day number (days since 1970-01-01) plays that role.
public struct DayKeyV10: Hashable, Comparable, CustomStringConvertible, Sendable {
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
        let key = DayKeyV10(year: y, month: m, day: d)
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

    public func adding(days: Int) -> DayKeyV10 {
        DayKeyV10(dayNumber: dayNumber + days)
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

    public static func < (lhs: DayKeyV10, rhs: DayKeyV10) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    /// 'YYYY-MM-DD'
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
