import Foundation

/// The first column of a week (1.2, O-2, K-11, docs/M7B_CONTRACT.md §10.1). The layouts and the page
/// ids take it as an input with the default `.monday`, so the Monday path is 1.1's; the app always
/// passes its setting (D15, lint L-13). Only `WeekStartChoice` in the app reads the region's custom
/// (L-14); nothing in TegakiKit reads a locale's first day of the week.
public enum WeekStart: String, CaseIterable, Sendable, Codable {
    case monday, sunday

    /// `DayKey.weekday` of the first column: 1 / 0.
    public var firstWeekday: Int {
        self == .monday ? 1 : 0
    }

    /// The 7 `DayKey.weekday` values in column order: [1, 2, 3, 4, 5, 6, 0] / [0, 1, 2, 3, 4, 5, 6].
    public var order: [Int] {
        (0..<7).map { (firstWeekday + $0) % 7 }
    }

    /// The column (0...6) of `day` in a week. `.monday` gives 1.1's `(weekday + 6) % 7`.
    public func column(of day: DayKey) -> Int {
        (day.weekday - firstWeekday + 7) % 7
    }

    /// The first day of the week containing `day` (`.monday`: `MonthLayout.mondayOnOrBefore`).
    public func firstDay(of day: DayKey) -> DayKey {
        day.adding(days: -column(of: day))
    }

    /// What the date of a week page id says (K-11 rule 1): a Monday → `.monday`, a Sunday → `.sunday`,
    /// any other day → nil.
    public init?(weekPageDate day: DayKey) {
        switch day.weekday {
        case 1: self = .monday
        case 0: self = .sunday
        default: return nil
        }
    }

    /// The rule of the automatic setting (0-44, §10.3): no region or Japan → Monday (the owner's
    /// decision: ICU says Sunday for ja_JP); a region whose first day is Sunday → Sunday; everything
    /// else (Monday, and the Saturday and Friday regions, which this version reads as Monday) → Monday.
    public static func automatic(region: String?, firstDayOfWeek: Locale.Weekday) -> WeekStart {
        guard let region, region != "JP" else { return .monday }
        return firstDayOfWeek == .sunday ? .sunday : .monday
    }
}
