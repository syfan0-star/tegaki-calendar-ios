import Foundation
import CoreGraphics
@_exported import DayKit

/// Fixed numbers of the paper (logical units, "lu"). Same values as the web version (SPEC §3) and
/// docs/DESIGN.md §2.2, so a web page converts to an app page by plain addition.
public enum PaperSpec {
    public static let monthWidth: CGFloat = 1400
    public static let monthColumns = 7
    public static let monthRows = 6
    public static let monthColumnWidth: CGFloat = 200
    public static let monthRowBase: CGFloat = 175
    public static let monthRowMax: CGFloat = 1200
    public static let monthDateHeader: CGFloat = 28
    public static let allDayLane: CGFloat = 22
    public static let allDayGap: CGFloat = 3
    public static let timedChip: CGFloat = 20
    /// Maximum number of timed chips shown per day (4 or more events → 2 chips + 「+n件」).
    public static let timedChipCap = 3
    public static let monthInkMargin: CGFloat = 40
    public static let inkPad: CGFloat = 12
    public static let memoMin: CGFloat = 700
    public static let memoInkPad: CGFloat = 50

    /// Height of one all-day lane including its gap (25).
    public static var allDayLaneStep: CGFloat { allDayLane + allDayGap }
    /// Horizontal inset of bars, chips and date labels from the cell edges (4).
    public static let cellInset: CGFloat = 4
    /// Number of cells of the month grid (42).
    public static var monthCellCount: Int { monthColumns * monthRows }
}

/// Key of one ink cell. Month page: "2026-10-04" for a day, "memo" for the memo area below the grid.
/// (Week / day / year keys come in M3.) Stored in JSON as the plain string.
public struct CellKey: Hashable, Codable, Sendable, CustomStringConvertible {
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
    public static func day(_ d: DayKey) -> CellKey {
        CellKey(raw: d.description)
    }

    /// The memo area of the month page.
    public static let memo = CellKey(raw: "memo")

    /// The day this key stands for, nil for the memo area (or any non-day key).
    public var day: DayKey? {
        DayKey(ymd: raw)
    }

    public var isMemo: Bool { raw == CellKey.memo.raw }

    public var description: String { raw }
}
