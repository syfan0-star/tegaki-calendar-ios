import Foundation
import CoreGraphics
@_exported import DayKit

/// Fixed numbers of the paper (logical units, "lu"). Same values as the web version (SPEC §3) and
/// docs/DESIGN.md §2.2, so a web page converts to an app page by plain addition.
public enum PaperSpec {
    // MARK: - Month (M2, unchanged)

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

    // MARK: - The growing last cell (1.1, M7A_CONTRACT D3 / §3.1)

    /// The step of the last cell of a page (the month's `memo`, the day's `extra`): the blank paper
    /// below the handwriting grows 400 lu at a time (`PaperGrowth.tailHeight`).
    public static let growStep: CGFloat = 400
    /// The largest height the steps reach (K-9). Only handwriting already below it (from a 1.0 device
    /// or the web version) makes the cell taller (`inkBottom + 50`); new strokes below it are dropped.
    public static let growMax: CGFloat = 6000
    /// The least height of the day page's `extra` cell below 24:00 (= `memoMin`, M7A-9).
    public static let dayExtraMin: CGFloat = 700

    /// Height of one all-day lane including its gap (25).
    public static var allDayLaneStep: CGFloat { allDayLane + allDayGap }
    /// Horizontal inset of bars, chips and date labels from the cell edges (4).
    public static let cellInset: CGFloat = 4
    /// Number of cells of the month grid (42).
    public static var monthCellCount: Int { monthColumns * monthRows }

    // MARK: - Week (M3a, DESIGN §2.2)

    public static let weekWidth: CGFloat = 1400
    /// The time-label gutter on the left.
    public static let weekGutter: CGFloat = 64
    public static let weekColumns = 7
    /// 190.857142… (never rounded, as in the web version).
    public static var weekColumnWidth: CGFloat { (weekWidth - weekGutter) / CGFloat(weekColumns) }
    public static let weekHourHeight: CGFloat = 80
    /// 1920. The time grid never grows; since M4b it is the whole paper (the all-day band is a fixed
    /// view outside the paper, M4B_CONTRACT §2, so the former weekBand* constants are gone).
    public static var weekGridHeight: CGFloat { weekHourHeight * 24 }
    /// Horizontal inset of a band bar from the column edges (0 on a continuing side).
    public static let weekBarInset: CGFloat = 3
    /// Timed boxes: padding inside a day column and the gap between overlap columns.
    public static let weekBoxPadLeft: CGFloat = 2
    public static let weekBoxPadRight: CGFloat = 6
    public static let weekBoxGap: CGFloat = 2
    // Lane height is the month's: allDayLane 22 + allDayGap 3 = allDayLaneStep 25.

    // MARK: - Day (M3a)

    public static let dayWidth: CGFloat = 1000
    public static let dayGutter: CGFloat = 72
    /// The timeline column is x 72…660; the memo area is 660…1000.
    public static let dayTimelineRight: CGFloat = 660
    public static let dayHourHeight: CGFloat = 100
    /// 2400. The time grid never grows; since M4b it is the whole paper (the former dayBand*
    /// constants are gone, M4B_CONTRACT §2.4).
    public static var dayGridHeight: CGFloat { dayHourHeight * 24 }
    /// Lane 22 + gap 2 = 24 (DESIGN §2.2 「24」). Used by the fixed band (`AllDayBandMetrics`).
    public static let dayLaneGap: CGFloat = 2
    public static var dayLaneStep: CGFloat { allDayLane + dayLaneGap }
    /// The day band's bars sit inside the timeline column (web .sh-allday-items).
    public static let dayChipPadLeft: CGFloat = 4
    public static let dayChipPadRight: CGFloat = 12
    public static let dayBoxPadLeft: CGFloat = 4
    public static let dayBoxPadRight: CGFloat = 14
    public static let dayBoxGap: CGFloat = 3
    /// Ruled lines of the memo area (same as the month's memo area).
    public static let dayRuleStep: CGFloat = 50
    public static let dayRuleInset: CGFloat = 20

    // MARK: - Year (M3a)

    public static let yearWidth: CGFloat = 1400
    /// The day-number gutter (1…31) on the left.
    public static let yearGutter: CGFloat = 56
    public static let yearColumns = 12
    public static let yearRows = 31
    public static let yearColumnWidth: CGFloat = 112
    public static let yearRowBase: CGFloat = 60
    public static let yearRowMax: CGFloat = 400
    /// The weekday-letter line at the top of a cell.
    public static let yearHeader: CGFloat = 16
    /// Lane 16 + gap 2 = 18 (DESIGN §2.2 「レーン高＋隙間」).
    public static let yearLane: CGFloat = 16
    public static let yearLaneGap: CGFloat = 2
    public static var yearLaneStep: CGFloat { yearLane + yearLaneGap }
    public static let yearInkMargin: CGFloat = 8
    /// Chips occupy the right 55 % of a cell (the left 45 % is for handwriting).
    public static let yearChipLeft: CGFloat = 0.45
    /// Inset of the weekday letter and the chips from the cell edges.
    public static let yearPad: CGFloat = 3
    /// Height of the holiday-name line.
    public static let yearHolidayLine: CGFloat = 12
    /// A chip whose lane is thinner than this is "thin": a tap opens the day instead of the event.
    public static let yearThinLane: CGFloat = 12

    // MARK: - Timed boxes (week and day)

    /// Vertical gap between back-to-back boxes.
    public static let boxVerticalGap: CGFloat = 1
    public static let boxMinHeight: CGFloat = 4
    /// Minimum visual length of a box, in minutes.
    public static let timedMinVisualMinutes = 15
    /// On-screen thickness of the current-time line (pt, independent of the zoom scale).
    public static let nowLineWidthPoints: CGFloat = 2
}

/// Key of one ink cell. Month page: "2026-10-04" for a day, "memo" for the memo area below the grid.
/// Week page: "grid" for the time grid. Day page: "grid" (0:00–24:00) and, since 1.1, "extra" (the
/// free memo area below 24:00). Year page: "MM-DD" (also for dates that
/// do not exist, like "02-30"). The week / day band keys "allday:2026-10-04" / "allday" (M3a–M4) are
/// no longer created: the band left the paper in M4b and `BandMigration` moves their strokes onto
/// "grid" on load, but the keys stay readable forever (M4B_CONTRACT §2.4 / §3).
/// Stored in JSON as the plain string (DESIGN §3.4); the persistence format never changes.
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

    /// The day this key stands for, nil for the memo area (or any non-day key, including
    /// "allday:…" and "MM-DD").
    public var day: DayKey? {
        DayKey(ymd: raw)
    }

    public var isMemo: Bool { raw == CellKey.memo.raw }

    public var description: String { raw }
}

// MARK: - Week / day / year keys (M3A_CONTRACT §1.2)

extension CellKey {
    private static let allDayPrefix = "allday:"

    /// A day of the week page's former all-day band: "allday:2026-10-04" (read by `BandMigration`;
    /// not created since M4b).
    public static func allDay(_ d: DayKey) -> CellKey {
        CellKey(raw: allDayPrefix + d.description)
    }

    /// The day page's former all-day band (one cell; read by `BandMigration`, not created since M4b).
    public static let allDayDay = CellKey(raw: "allday")

    /// The time grid of the week and day pages (one cell; the time gutter and the day page's memo
    /// area belong to it too).
    public static let grid = CellKey(raw: "grid")

    /// A cell of the year page: "MM-DD" (zero padded). `month` 1…12 and `day` 1…31 only; dates that
    /// do not exist (02-30) are allowed because the paper has a cell for them.
    public static func yearDay(month: Int, day: Int) -> CellKey {
        precondition((1...12).contains(month) && (1...31).contains(day), "yearDay(month:day:) takes month 1…12 and day 1…31")
        return CellKey(raw: String(format: "%02d-%02d", month, day))
    }

    /// The day of an "allday:YYYY-MM-DD" key; nil for every other key.
    public var allDayDate: DayKey? {
        guard raw.hasPrefix(Self.allDayPrefix) else { return nil }
        return DayKey(ymd: String(raw.dropFirst(Self.allDayPrefix.count)))
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

    public var isGrid: Bool { raw == CellKey.grid.raw }

    /// The day page's free memo area below 24:00 (1.1, M7A_CONTRACT §3.3). K-1: the name never starts
    /// with "allday", so `BandMigration` never touches it and a 1.0 device keeps it unchanged (an
    /// unknown cell: read, kept, written back, not drawn).
    public static let extra = CellKey(raw: "extra")

    public var isExtra: Bool { raw == CellKey.extra.raw }

    public var isAllDayDay: Bool { raw == CellKey.allDayDay.raw }
}
