import Foundation
import CoreGraphics

/// Lining up the bottom of the joined pages (1.3, docs/M7C_CONTRACT.md D16, §3.2, §3.8, §5.2; B_DESIGN.md
/// §3.1, :288): every page of a window gets the height of its tallest last cell as a lower bound
/// (a floor), so the day's free memo and the week memo below 24:00 run on as one band. The engines take
/// the floor as an input (`DayLayoutInput.extraFloor`, `WeekLayoutInput.extraFloor`); left out it is 0
/// and the output is today's, `==`. Since 1.1.1 every day's `extra` is 6,000 lu already, and so is every
/// week memo, so a floor only matters once a line ends past 5,950 lu (`PaperGrowth.tailHeight`). Only
/// positions and heights move; no cell changes its meaning (K-4) and nothing is stored (K-5). The week's
/// floor is read only for a week laid out with its memo (`WeekLayoutInput.freeMemo`); a week without it
/// ignores any floor.
/// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §3.3, §4.1, §5.1): the joined months and years line up too. The month
/// (ア, `monthForm`) lines up its separator line (`memo.minY`) by lengthening only its last row
/// (`MonthLayoutInput.gridFloor`) and its memo's height (`memoFloor`); イ lines up every row (`rowFloors`);
/// ウ nothing. The year lines up its 31 rows (`YearLayoutInput.rowFloors`). Left out, every floor is 0 or
/// empty and the engines give 1.4.2's output, `==`. Again only positions and heights move (K-4, K-5).
public enum SpanAlign {
    /// The floors of a window's last cells (lu): the day's `extra` and the week's (the week memo, §5).
    /// 0 is no floor.
    /// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §3.3, §4.1, §5.1): the month's and the year's floors, each 0 or
    /// empty for no floor, so `Floors()` and `Floors(dayExtra:weekExtra:)` are 1.4.2's values and
    /// `Floors.none == Floors(dayExtra: 0, weekExtra: 0)` still holds. They are read with `monthFloors` /
    /// `yearFloors` and handed to the engines (`MonthLayoutInput.gridFloor`, `memoFloor`, `rowFloors`;
    /// `YearLayoutInput.rowFloors`), never through `floor(for:)`.
    public struct Floors: Equatable, Sendable {
        public var dayExtra: CGFloat
        public var weekExtra: CGFloat
        /// ア (`MonthForm.memo`): the floor of the bottom of the month's grid (= the separator line =
        /// `memo.minY`): the largest natural grid bottom of the window. 0 is no floor.
        public var monthGrid: CGFloat
        /// ア and イ: the floor of the height of the month's `memo` (the day's and the week's `extra`
        /// floors' idea, so the memo band ends on one line). 0 is no floor.
        public var monthMemo: CGFloat
        /// イ (`MonthForm.rows`): the floors of the 6 rows' heights, row by row. Empty is no floor.
        public var monthRows: [CGFloat]
        /// The floors of the year's 31 rows' heights (index 0 is day 1). Empty is no floor.
        public var yearRows: [CGFloat]

        public init(dayExtra: CGFloat = 0, weekExtra: CGFloat = 0, monthGrid: CGFloat = 0, monthMemo: CGFloat = 0,
                    monthRows: [CGFloat] = [], yearRows: [CGFloat] = []) {
            self.dayExtra = dayExtra
            self.weekExtra = weekExtra
            self.monthGrid = monthGrid
            self.monthMemo = monthMemo
            self.monthRows = monthRows
            self.yearRows = yearRows
        }

        /// No floor: every page is laid out as it is today.
        public static let none = Floors()

        /// The floor of a kind's last cell (0 for the month and the year: their floors are not one number,
        /// they are read from `monthGrid`, `monthMemo`, `monthRows` and `yearRows`).
        public func floor(for kind: PageKind) -> CGFloat {
            switch kind {
            case .day: return dayExtra
            case .week: return weekExtra
            case .month, .year: return 0
            }
        }
    }

    /// How the joined months line up (1.4.3, P-B3, docs/R1_4_3_CONTRACT.md §4.1, 0g-10, 0g-11).
    public enum MonthForm: Sendable, Equatable {
        /// ア: only the memo lines up. The grid's bottom (= `memo.minY`) goes down to the window's largest
        /// by lengthening the last (6th) row alone, so the separator line, the ruled lines, the dots, the
        /// label and the memo's handwriting (kept relative to the memo's origin) move together; the memo's
        /// height lines up too. A month that would need a 6th row above `PaperSpec.monthRowMax` stops there.
        case memo
        /// イ: every row lines up, row by row, at the window's largest (and the memo's height).
        case rows
        /// ウ: nothing lines up; each month is laid out as on one page.
        case none
    }

    /// The form the joined months take (P-B3; ア unless the owner picks イ or ウ from the sample photos).
    /// Change only this value to switch (0g-10).
    public static let monthForm: MonthForm = .memo

    /// What a month page has by its own events and handwriting, read from a page laid out without floors
    /// (docs/R1_4_3_CONTRACT.md §3.3 2): the 6 rows' heights, the grid's bottom (the natural `memo.minY`)
    /// and the memo's height (`PaperGrowth.tailHeight`).
    public struct MonthNatural: Equatable, Sendable {
        public var rows: [CGFloat]
        public var gridBottom: CGFloat
        public var memoHeight: CGFloat

        public init(rows: [CGFloat], gridBottom: CGFloat, memoHeight: CGFloat) {
            self.rows = rows
            self.gridBottom = gridBottom
            self.memoHeight = memoHeight
        }

        /// The numbers of a page laid out without floors (`MonthLayoutInput`'s floors left out).
        public init(_ layout: MonthPageLayout) {
            self.init(rows: layout.rows.map(\.frame.height), gridBottom: layout.memo.minY, memoHeight: layout.memo.height)
        }
    }

    /// The natural row heights of a year page laid out without floors (`YearLayoutInput.rowFloors` left
    /// out): 31 values, day 1 first.
    public static func naturalRows(of year: YearPageLayout) -> [CGFloat] {
        year.rows.map(\.frame.height)
    }

    /// What happened to the window, which decides whether a floor may come down (B_DESIGN.md:288).
    public enum Change: Equatable, Sendable {
        /// The window moved to other pages: the floor never comes down (the rows on screen do not shrink).
        case shift
        /// A page's handwriting grew: the floor only goes up.
        case inkGrew
        /// A page's last cell shrank (erasing): the floor comes down to the tallest page of the window
        /// (P-6 A, "erase and the blank paper shrinks too").
        case inkShrank
        /// Decided again from the window alone: reopening, rotation, the end of a pinch.
        case redecide
    }

    /// The height a page's last cell has by its own handwriting (`inkBottom` cell-relative):
    /// `PaperGrowth.tailHeight`, at least 6,000 lu.
    public static func natural(inkBottom: CGFloat) -> CGFloat {
        PaperGrowth.tailHeight(inkBottom: inkBottom)
    }

    /// The floor after `change`, from the previous floor and the natural heights of the window's pages
    /// (values that are not finite or negative count as 0). `shift` and `inkGrew`: max(previous, the
    /// tallest); `inkShrank` and `redecide`: the tallest (0 for no page).
    public static func floor(previous: CGFloat, naturals: [CGFloat], change: Change) -> CGFloat {
        let tallest = naturals.reduce(CGFloat(0)) { max($0, sanitized($1)) }
        switch change {
        case .shift, .inkGrew:
            return max(sanitized(previous), tallest)
        case .inkShrank, .redecide:
            return tallest
        }
    }

    /// The day floors of a window after `change`, from the bottoms of each page's `extra` handwriting
    /// (`InkPage.inkBottoms()[.extra]`, 0 for a page without any).
    public static func dayFloors(previous: Floors, extraInkBottoms: [CGFloat], change: Change) -> Floors {
        var floors = previous
        floors.dayExtra = floor(previous: previous.dayExtra, naturals: extraInkBottoms.map(natural(inkBottom:)), change: change)
        return floors
    }

    /// The week floors of a window after `change` (1.3, the week memo, docs/M7C_CONTRACT.md §5.2, D16),
    /// from the bottoms of each week page's `extra` handwriting (`InkPage.inkBottoms()[.extra]`, 0 for a
    /// page without any): the same rule as `dayFloors`, on `weekExtra`; `dayExtra` is kept.
    public static func weekFloors(previous: Floors, extraInkBottoms: [CGFloat], change: Change) -> Floors {
        var floors = previous
        floors.weekExtra = floor(previous: previous.weekExtra, naturals: extraInkBottoms.map(natural(inkBottom:)), change: change)
        return floors
    }

    /// The month floors of a window after `change` (1.4.3, docs/R1_4_3_CONTRACT.md §3.3, §4.1, §4.2, 0g-10–0g-12),
    /// from the natural numbers of each page (`MonthNatural`, read from the pages laid out without floors), by
    /// `floor(previous:naturals:change:)`'s table, the same as the day's and the week's: `shift` and
    /// `inkGrew` raise only, `inkShrank` and `redecide` take the window's largest.
    /// - ア (`.memo`): `monthGrid` from the grid bottoms, `monthMemo` from the memo heights; `monthRows` empty.
    /// - イ (`.rows`): `monthRows[r]` from row r's heights (6 rows), `monthMemo` as ア; `monthGrid` 0 (the rows
    ///   line the grid's bottom up already).
    /// - ウ (`.none`): every month floor 0 / empty.
    /// The day's, the week's and the year's floors are kept. A row floor that is missing counts as 0; a list
    /// of row floors that are all 0 is stored empty (no floor), so the answer is `Floors.none` when nothing
    /// lines up. SpanSession reads `.redecide` as `.shift` for the month after a shift's prefetch, a reload
    /// of the events, the 30 s check and a remote update (§3.3); that reading is the session's, not here.
    public static func monthFloors(previous: Floors, naturals: [MonthNatural], form: MonthForm, change: Change) -> Floors {
        var floors = previous
        switch form {
        case .memo:
            floors.monthGrid = floor(previous: previous.monthGrid, naturals: naturals.map(\.gridBottom), change: change)
            floors.monthMemo = floor(previous: previous.monthMemo, naturals: naturals.map(\.memoHeight), change: change)
            floors.monthRows = []
        case .rows:
            floors.monthGrid = 0
            floors.monthMemo = floor(previous: previous.monthMemo, naturals: naturals.map(\.memoHeight), change: change)
            floors.monthRows = rowFloors(previous: previous.monthRows, naturals: naturals.map(\.rows), count: PaperSpec.monthRows, change: change)
        case .none:
            floors.monthGrid = 0
            floors.monthMemo = 0
            floors.monthRows = []
        }
        return floors
    }

    /// The year floors of a window after `change` (1.4.3, docs/R1_4_3_CONTRACT.md §5.1, 0g-21): row r's floor
    /// from row r's natural height on each page (`naturalRows`, 31 values a page; a missing value counts as
    /// 0), by the same table as `floor(previous:naturals:change:)`. The other floors are kept; 31 floors that
    /// are all 0 are stored empty (no floor). The natural heights are at most 400 lu
    /// (`YearLayoutEngine.rowHeight`), so are the floors made from them.
    public static func yearFloors(previous: Floors, naturalRows: [[CGFloat]], change: Change) -> Floors {
        var floors = previous
        floors.yearRows = rowFloors(previous: previous.yearRows, naturals: naturalRows, count: PaperSpec.yearRows, change: change)
        return floors
    }

    /// Row r (0 ..< count) by `floor(previous:naturals:change:)`; all 0 → empty.
    static func rowFloors(previous: [CGFloat], naturals: [[CGFloat]], count: Int, change: Change) -> [CGFloat] {
        let rows = (0..<count).map { r in
            floor(previous: r < previous.count ? previous[r] : 0,
                  naturals: naturals.map { r < $0.count ? $0[r] : 0 },
                  change: change)
        }
        return rows.allSatisfy { $0 == 0 } ? [] : rows
    }

    /// A floor as the engines read it: finite and 0 or more, else 0.
    public static func sanitized(_ floor: CGFloat) -> CGFloat {
        floor.isFinite ? max(0, floor) : 0
    }
}
