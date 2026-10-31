import Foundation
import CoreGraphics

// The facts of the 1.0 layouts that the compatibility checks need, written by hand (M7A_CONTRACT
// §1.4). Only RunFrozen, KitChecks and Compat10Tests use this file: tools/compat10's RunReal defines
// the same two functions from the real 1.0 Layout engines, so a fact written wrongly here makes the
// results of RunReal and RunFrozen differ.

// a21e469 TegakiKit/Sources/Layout/MonthLayoutEngine.swift:23-26
/// The 1.0 memo area of the month page: `max(700, b + 50)` with a non-finite or negative b read as 0.
/// No upper limit (F6).
public func memoHeightV10(_ b: CGFloat) -> CGFloat {
    let ink = b.isFinite ? max(0, b) : 0
    return max(700, ink + 50)
}

// a21e469 TegakiKit/Sources/Layout/DayLayoutEngine.swift:210-218
// a21e469 TegakiKit/Sources/Layout/WeekLayoutEngine.swift:235-241
// a21e469 TegakiKit/Sources/Layout/MonthLayoutEngine.swift:90-92
// a21e469 TegakiKit/Sources/Layout/MonthLayoutEngine.swift:162-164
// a21e469 TegakiKit/Sources/Layout/MonthLayout.swift:45-55
// a21e469 TegakiKit/Sources/Layout/YearLayoutEngine.swift:300-308
/// The ink cells of the 1.0 layout of a page (`layout.cells.keys`), from its id: a day page
/// "d-YYYY-MM-DD" and a week page "w-YYYY-MM-DD" have the one cell `grid`; a month page "m1-YYYY-MM"
/// has the 42 days from the Monday on or before the 1st and `memo`; a year page "y-YYYY" has the 372
/// cells "MM-DD" (dates that do not exist included). Any other id: no cell (1.0 never opens it).
public func cellsV10(pageId: String) -> Set<CellKeyV10> {
    if pageId.hasPrefix("d-") || pageId.hasPrefix("w-") {
        return DayKeyV10(ymd: String(pageId.dropFirst(2))) == nil ? [] : [.grid]
    }
    if pageId.hasPrefix("m1-") {
        let parts = pageId.dropFirst(3).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month) else { return [] }
        let first = DayKeyV10(year: year, month: month, day: 1)
        let monday = first.adding(days: -((first.weekday + 6) % 7))
        var cells: Set<CellKeyV10> = [.memo]
        for n in 0..<42 { cells.insert(.day(monday.adding(days: n))) }
        return cells
    }
    if pageId.hasPrefix("y-") {
        guard Int(pageId.dropFirst(2)) != nil else { return [] }
        var cells: Set<CellKeyV10> = []
        for month in 1...12 {
            for day in 1...31 { cells.insert(.yearDay(month: month, day: day)) }
        }
        return cells
    }
    return []
}
