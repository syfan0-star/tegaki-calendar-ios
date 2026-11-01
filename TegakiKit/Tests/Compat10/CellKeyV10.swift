// a21e469 TegakiKit/Sources/Layout/PaperSpec.swift:1-2  imports
import Foundation
import CoreGraphics

/// The week constants of `PaperSpec` that `BandMigration` uses (the rest of PaperSpec is not copied).
public enum PaperSpecV10 {
    // a21e469 TegakiKit/Sources/Layout/PaperSpec.swift:36-41  PaperSpecV10.weekWidth / weekGutter / weekColumns / weekColumnWidth
    public static let weekWidth: CGFloat = 1400
    /// The time-label gutter on the left.
    public static let weekGutter: CGFloat = 64
    public static let weekColumns = 7
    /// 190.857142… (never rounded, as in the web version).
    public static var weekColumnWidth: CGFloat { (weekWidth - weekGutter) / CGFloat(weekColumns) }
}

// a21e469 TegakiKit/Sources/Layout/PaperSpec.swift:114-200  CellKeyV10
/// Key of one ink cell. Month page: "2026-10-04" for a day, "memo" for the memo area below the grid.
/// Week page: "grid" for the time grid. Day page: "grid". Year page: "MM-DD" (also for dates that
/// do not exist, like "02-30"). The week / day band keys "allday:2026-10-04" / "allday" (M3a–M4) are
/// no longer created: the band left the paper in M4b and `BandMigrationV10` moves their strokes onto
/// "grid" on load, but the keys stay readable forever (M4B_CONTRACT §2.4 / §3).
/// Stored in JSON as the plain string (DESIGN §3.4); the persistence format never changes.
public struct CellKeyV10: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        raw = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    /// The cell of a calendar day: "YYYY-MM-DD".
    public static func day(_ d: DayKeyV10) -> CellKeyV10 {
        CellKeyV10(raw: d.description)
    }

    /// The memo area of the month page.
    public static let memo = CellKeyV10(raw: "memo")

    /// The day this key stands for, nil for the memo area (or any non-day key, including
    /// "allday:…" and "MM-DD").
    public var day: DayKeyV10? {
        DayKeyV10(ymd: raw)
    }

    public var isMemo: Bool { raw == CellKeyV10.memo.raw }

    public var description: String { raw }
}

// MARK: - Week / day / year keys (M3A_CONTRACT §1.2)

extension CellKeyV10 {
    private static let allDayPrefix = "allday:"

    /// A day of the week page's former all-day band: "allday:2026-10-04" (read by `BandMigrationV10`;
    /// not created since M4b).
    public static func allDay(_ d: DayKeyV10) -> CellKeyV10 {
        CellKeyV10(raw: allDayPrefix + d.description)
    }

    /// The day page's former all-day band (one cell; read by `BandMigrationV10`, not created since M4b).
    public static let allDayDay = CellKeyV10(raw: "allday")

    /// The time grid of the week and day pages (one cell; the time gutter and the day page's memo
    /// area belong to it too).
    public static let grid = CellKeyV10(raw: "grid")

    /// A cell of the year page: "MM-DD" (zero padded). `month` 1…12 and `day` 1…31 only; dates that
    /// do not exist (02-30) are allowed because the paper has a cell for them.
    public static func yearDay(month: Int, day: Int) -> CellKeyV10 {
        precondition((1...12).contains(month) && (1...31).contains(day), "yearDay(month:day:) takes month 1…12 and day 1…31")
        return CellKeyV10(raw: String(format: "%02d-%02d", month, day))
    }

    /// The day of an "allday:YYYY-MM-DD" key; nil for every other key.
    public var allDayDate: DayKeyV10? {
        guard raw.hasPrefix(Self.allDayPrefix) else { return nil }
        return DayKeyV10(ymd: String(raw.dropFirst(Self.allDayPrefix.count)))
    }

    /// (month, day) of an "MM-DD" key (month 1…12, day 1…31); nil for every other key.
    public var yearMonthDay: (month: Int, day: Int)? {
        let parts = raw.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }), parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let m = Int(parts[0]), let d = Int(parts[1]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        return (m, d)
    }

    public var isGrid: Bool { raw == CellKeyV10.grid.raw }

    public var isAllDayDay: Bool { raw == CellKeyV10.allDayDay.raw }
}
