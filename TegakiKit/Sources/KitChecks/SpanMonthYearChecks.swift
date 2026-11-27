// KitChecks: the joined months and years of 1.4.3 (docs/R1_4_3_CONTRACT.md §11.1; section "span month & year (1.4.3)"):
// the month's and the year's floors (`SpanAlign.monthFloors` with the three forms ア イ ウ, `SpanAlign.yearFloors`), the
// floors' inputs of the two engines (`MonthLayoutInput.gridFloor`, `memoFloor`, `rowFloors`; `YearLayoutInput.rowFloors`),
// `PageScroll.scrollDelta` across a shift of joined months (§3.5), and `SpanLayout` over month and year windows. main.swift
// calls `runSpanMonthYearChecks()` right after `runWindowFingerChecks()`; it uses main.swift's `section`, `check`,
// `checkEqual`, `passed`, `failures`, `tokyo`, `date` and `Rng`, and SpanChecks.swift's `SpanFixtures` (plan, window, weekPages,
// dayPages, october).
//
// The expectations are worked out by hand from the rules (a row is its ink bottom + 12 lu, at least 175 lu on the month and
// 60 lu on the year, at most 1,200 / 400 lu; the memo is 6,000 lu or its ink bottom + 50; a floor table that raises on a
// shift and on grown ink and takes the window's largest on erasing and on deciding again) and written as literals; the pages
// laid out without floors are the reference of "nothing else moves". The fixtures (Monday weeks, Tokyo):
// - five months, September 2026 – January 2027: September's 6th row (10/5–10/11) has ink to 250 (262 lu, grid bottom
//   1,137), October's 3rd row (10/12–10/18) ink to 400 (412 lu, grid bottom 1,287, the tallest), November's 2nd row
//   (11/2–11/8) ink to 300 (312 lu, grid bottom 1,187) and an all-day and a timed event in its 6th row, December nothing
//   (1,050), January a memo line to 6,100 (memo 6,150, the tallest; grid 1,050);
// - five years, 2024 – 2028: 2024 nothing (60 lu × 31), 2025 ink in 01-15 to 200 (row 15: 212), 2026 three all-day events
//   on 3/3 (row 3: 16 + 3 × 18 + 8 = 78) and ink in 12-31 to 380 (row 31: 392), 2027 ink in 02-28 to 500 (row 28: the cap,
//   400), 2028 ink in 07-15 to 100 (row 15: 112);
// - the same five months with the Sunday start (ア only: the same floors, other days in the 6th rows), and December,
//   February and March (grid bottoms all 1,050) with December's memo ink at 5,950 and 5,950.5 (the memo floor's boundary).
import Foundation
import CoreGraphics
import Layout

// MARK: - Fixtures

private enum MonthYearFixtures {
    static let now = date(2026, 10, 12, 12)

    static func d(_ y: Int, _ m: Int, _ day: Int) -> DayKey { DayKey(year: y, month: m, day: day) }

    static func allDay(_ id: String, _ start: DayKey, days: Int = 1) -> LayoutEvent {
        LayoutEvent(id: id, title: id, allDay: true, start: start.startOfDay(in: tokyo), end: start.adding(days: days).startOfDay(in: tokyo),
                    colorHex: "#33b679", calendarId: "primary")
    }

    static func timed(_ id: String, _ day: DayKey, hour: Int) -> LayoutEvent {
        let start = day.startOfDay(in: tokyo).addingTimeInterval(TimeInterval(hour) * 3600)
        return LayoutEvent(id: id, title: id, allDay: false, start: start, end: start.addingTimeInterval(3600), colorHex: "#039be5", calendarId: "primary")
    }

    static func month(_ y: Int, _ m: Int, events: [LayoutEvent] = [], ink: [CellKey: CGFloat] = [:], weekStart: WeekStart = .monday) -> MonthLayoutInput {
        MonthLayoutInput(month: YearMonth(year: y, month: m), events: events, inkBottoms: ink, now: now, calendar: tokyo, weekStart: weekStart)
    }

    static func lay(_ input: MonthLayoutInput, _ floors: SpanAlign.Floors = .none) -> MonthPageLayout {
        MonthLayoutEngine.layout(input.floored(by: floors))
    }

    static func year(_ y: Int, events: [LayoutEvent] = [], ink: [CellKey: CGFloat] = [:]) -> YearLayoutInput {
        YearLayoutInput(year: y, events: events, inkBottoms: ink, now: now, calendar: tokyo)
    }

    static func lay(_ input: YearLayoutInput, _ floors: SpanAlign.Floors = .none) -> YearPageLayout {
        YearLayoutEngine.layout(input.floored(by: floors))
    }

    static let september = month(2026, 9, ink: [.day(d(2026, 10, 7)): 250])
    static let october = month(2026, 10, ink: [.day(d(2026, 10, 14)): 400])
    static let november = month(2026, 11, events: [allDay("N30", d(2026, 11, 30)), timed("D1", d(2026, 12, 1), hour: 9)],
                                ink: [.day(d(2026, 11, 4)): 300])
    static let december = month(2026, 12)
    static let january = month(2027, 1, ink: [.memo: 6100])
    static let february = month(2027, 2)
    static let march = month(2027, 3)

    /// September 2026 – January 2027.
    static let fiveMonths = [september, october, november, december, january]

    static let year2024 = year(2024)
    static let year2025 = year(2025, ink: [.yearDay(month: 1, day: 15): 200])
    static let year2026 = year(2026, events: [allDay("Y1", d(2026, 3, 3)), allDay("Y2", d(2026, 3, 3)), allDay("Y3", d(2026, 3, 2), days: 3)],
                               ink: [.yearDay(month: 12, day: 31): 380])
    static let year2027 = year(2027, ink: [.yearDay(month: 2, day: 28): 500])
    static let year2028 = year(2028, ink: [.yearDay(month: 7, day: 15): 100])

    /// 2024 – 2028.
    static let fiveYears = [year2024, year2025, year2026, year2027, year2028]

    static func naturals(_ inputs: [MonthLayoutInput]) -> [SpanAlign.MonthNatural] {
        inputs.map { SpanAlign.MonthNatural(lay($0)) }
    }

    static func naturalRows(_ inputs: [YearLayoutInput]) -> [[CGFloat]] {
        inputs.map { SpanAlign.naturalRows(of: lay($0)) }
    }

    static func monthWindow(_ inputs: [MonthLayoutInput], _ floors: SpanAlign.Floors) -> SpanLayout {
        SpanFixtures.window(inputs.map { lay($0, floors) as any PageLayout }, plan: SpanFixtures.plan(.month))
    }

    static func yearWindow(_ inputs: [YearLayoutInput], _ floors: SpanAlign.Floors) -> SpanLayout {
        SpanFixtures.window(inputs.map { lay($0, floors) as any PageLayout }, plan: SpanFixtures.plan(.year))
    }

    /// The 31 values of a year floor with `others` everywhere but the rows given (day number → height).
    static func yearRows(_ others: CGFloat, _ rows: [Int: CGFloat]) -> [CGFloat] {
        (1...31).map { rows[$0] ?? others }
    }

    /// Today's (1.4.2's) answer of `PageScroll.scrollDelta`: the band at y in `old` and its tops in both.
    static func middleAnswer(_ old: any PageLayout, _ new: any PageLayout, _ y: CGFloat) -> CGFloat {
        guard y.isFinite, let band = old.band(atY: y), let oldTop = old.bandTop(band), let newTop = new.bandTop(band) else { return 0 }
        return newTop - oldTop
    }
}

private typealias MYF = MonthYearFixtures

// MARK: - The section

func runSpanMonthYearChecks() {
    section("span month & year (1.4.3)")
    let start = passed + failures.count
    print("   SpanAlign.monthForm is \(SpanAlign.monthForm) (P-B3: memo = ア, rows = イ, none = ウ); every form is checked below")
    monthYearDefaultChecks()
    monthFloorTableChecks()
    monthFormChecks()
    monthCapChecks()
    yearFloorChecks()
    monthYearPolicyChecks()
    monthScrollChecks()
    monthYearWindowChecks()
    print("   \(passed + failures.count - start) checks in this section")
}

// MARK: - Left out, the floors give 1.4.2's pages (§2.1, §11.1)

private func monthYearDefaultChecks() {
    let none = SpanAlign.Floors()
    check(none == .none && none.monthGrid == 0 && none.monthMemo == 0 && none.monthRows.isEmpty && none.yearRows.isEmpty,
          "span my: Floors() has no month or year floor")
    checkEqual(SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500),
               SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500, monthGrid: 0, monthMemo: 0, monthRows: [], yearRows: []),
               "span my: Floors(dayExtra:weekExtra:) has no month or year floor")
    let full = SpanAlign.Floors(dayExtra: 1, weekExtra: 2, monthGrid: 1287, monthMemo: 6150, monthRows: [200], yearRows: [80])
    check(full.floor(for: .month) == 0 && full.floor(for: .year) == 0 && full.floor(for: .day) == 1 && full.floor(for: .week) == 2,
          "span my: floor(for:) stays 0 for the month and the year (they read monthFloors / yearFloors)")
    check(full != .none && SpanAlign.Floors(monthRows: [0]) != .none, "span my: a month or year floor makes Floors differ from none")

    let input = MYF.october
    check(input.gridFloor == 0 && input.memoFloor == 0 && input.rowFloors.isEmpty, "span my: MonthLayoutInput's floors default to none")
    check(MYF.year2026.rowFloors.isEmpty, "span my: YearLayoutInput's floors default to none")
    let floored = input.floored(by: full)
    check(floored.gridFloor == 1287 && floored.memoFloor == 6150 && floored.rowFloors == [200] && floored.month == input.month
          && floored.inkBottoms == input.inkBottoms && floored.weekStart == input.weekStart,
          "span my: MonthLayoutInput.floored(by:) takes the month floors and keeps the rest")
    check(input.floored(by: full).floored(by: .none).gridFloor == 0 && input.floored(by: full).floored(by: .none).rowFloors.isEmpty,
          "span my: floored(by: .none) leaves the month floors out again")
    check(MYF.year2026.floored(by: full).rowFloors == [80] && MYF.year2026.floored(by: full).year == 2026,
          "span my: YearLayoutInput.floored(by:) takes the year floors and keeps the rest")

    // Months: every month of 2026 and February 2027, both week starts, four kinds of ink and the events of the window
    // fixtures; a floor left out, 0, junk, or not above the page's own numbers gives the page without floors, ==.
    let events = [MYF.allDay("A", MYF.d(2026, 10, 13), days: 3), MYF.allDay("B", MYF.d(2026, 10, 13)), MYF.timed("C", MYF.d(2026, 10, 14), hour: 9),
                  MYF.allDay("N30", MYF.d(2026, 11, 30)), MYF.timed("D1", MYF.d(2026, 12, 1), hour: 9)]
    let months = (1...12).map { YearMonth(year: 2026, month: $0) } + [YearMonth(year: 2027, month: 2)]
    for ym in months {
        let inks: [[CellKey: CGFloat]] = [[:], [.memo: 800], [.day(ym.firstDay): 300, .day(ym.firstDay.adding(days: 20)): 640],
                                          [.day(ym.firstDay.adding(days: 9)): 1300, .memo: 6200]]
        for weekStart in WeekStart.allCases {
            for (k, ink) in inks.enumerated() {
                let base = MonthLayoutInput(month: ym, events: events, inkBottoms: ink, now: MYF.now, calendar: tokyo, weekStart: weekStart)
                let page = MonthLayoutEngine.layout(base)
                let rows = page.rows.map(\.frame.height)
                let label = "span my: \(ym.inkPageId) \(weekStart) ink \(k)"
                var variants: [(String, MonthLayoutInput)] = []
                func add(_ name: String, _ change: (inout MonthLayoutInput) -> Void) {
                    var v = base
                    change(&v)
                    variants.append((name, v))
                }
                add("floors 0") { $0.gridFloor = 0; $0.memoFloor = 0; $0.rowFloors = [] }
                add("six row floors 0") { $0.rowFloors = Array(repeating: 0, count: 6) }
                add("junk floors") { $0.gridFloor = .nan; $0.memoFloor = -.infinity; $0.rowFloors = [-5, .nan, .infinity, -.infinity, 0, -1] }
                add("the grid floor at its own grid bottom") { $0.gridFloor = page.memo.minY }
                add("a grid floor below") { $0.gridFloor = page.memo.minY - 100 }
                add("the memo floor at its own memo") { $0.memoFloor = page.memo.height }
                add("a memo floor below") { $0.memoFloor = 700 }
                add("row floors at its own rows") { $0.rowFloors = rows }
                add("row floors below and short") { $0.rowFloors = rows.dropLast(2).map { $0 - 10 } }
                add("all of its own numbers") { $0.gridFloor = page.memo.minY; $0.memoFloor = page.memo.height; $0.rowFloors = rows }
                for (name, v) in variants {
                    check(MonthLayoutEngine.layout(v) == page, "\(label): \(name) give the page without floors")
                }
            }
        }
    }

    // Years: a leap year, the window's years, every floor that is not above the page's own rows.
    for input in [MYF.year2024, MYF.year2026, MYF.year2027, MYF.year(2028, events: [MYF.allDay("L", MYF.d(2028, 2, 28), days: 3)], ink: [.yearDay(month: 2, day: 29): 90])] {
        let page = YearLayoutEngine.layout(input)
        let rows = page.rows.map(\.frame.height)
        let floorsList: [(String, [CGFloat])] = [("[]", []), ("31 zeros", Array(repeating: 0, count: 31)), ("junk", [.nan, -.infinity, .infinity, -3]),
                                                 ("its own rows", rows), ("its own rows − 5", rows.map { $0 - 5 }), ("5 of its own rows", Array(rows.prefix(5))),
                                                 ("60s", Array(repeating: 60, count: 31))]
        for (name, floors) in floorsList {
            var v = input
            v.rowFloors = floors
            check(YearLayoutEngine.layout(v) == page, "span my: y-\(input.year) row floors \(name) give the page without floors")
        }
    }
}

// MARK: - monthFloors' table (§3.3, §4.1, 0g-12)

private func monthFloorTableChecks() {
    typealias N = SpanAlign.MonthNatural
    let naturals = [N(rows: [175, 175, 412, 175, 175, 175], gridBottom: 1287, memoHeight: 6000),
                    N(rows: [175, 312, 175, 175, 175, 175], gridBottom: 1187, memoHeight: 6150)]
    let kept = SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500, yearRows: MYF.yearRows(60, [28: 400]))

    // ア: the grid bottom and the memo height, by the table of the day's and the week's floors.
    let memoRules: [(String, CGFloat, CGFloat, [N], SpanAlign.Change, CGFloat, CGFloat)] = [
        ("a shift never lowers", 1400, 6500, naturals, .shift, 1400, 6500),
        ("a shift raises", 1000, 6000, naturals, .shift, 1287, 6150),
        ("ink that grew elsewhere keeps", 1400, 6500, naturals, .inkGrew, 1400, 6500),
        ("ink that grew raises", 1000, 6000, naturals, .inkGrew, 1287, 6150),
        ("erasing lowers to the window's largest", 1400, 6500, naturals, .inkShrank, 1287, 6150),
        ("deciding again takes the window's largest", 1400, 6500, naturals, .redecide, 1287, 6150),
        ("a shift to no page keeps", 1400, 6500, [], .shift, 1400, 6500),
        ("erasing with no page is 0", 1400, 6500, [], .inkShrank, 0, 0),
        ("deciding again with no page is 0", 1400, 6500, [], .redecide, 0, 0),
        ("a previous floor that is not finite counts as 0", .nan, -.infinity, naturals, .shift, 1287, 6150),
        ("a natural that is not finite counts as 0", 0, 0, [N(rows: [], gridBottom: .nan, memoHeight: .infinity)], .redecide, 0, 0),
    ]
    for (name, grid, memo, ns, change, wantGrid, wantMemo) in memoRules {
        var previous = kept
        previous.monthGrid = grid
        previous.monthMemo = memo
        previous.monthRows = [175, 312, 412, 175, 175, 175]   // イ's row floors from before: ア drops them on every change
        let floors = SpanAlign.monthFloors(previous: previous, naturals: ns, form: .memo, change: change)
        var want = kept
        want.monthGrid = wantGrid
        want.monthMemo = wantMemo
        checkEqual(floors, want, "span my: ア: \(name) (the day's, the week's and the year's floors kept, no row floor)")
    }

    // イ: row by row, and the memo height; no grid floor.
    let rowRules: [(String, [CGFloat], [N], SpanAlign.Change, [CGFloat], CGFloat)] = [
        ("a shift never lowers a row", [200, 200, 200, 200, 200, 200], naturals, .shift, [200, 312, 412, 200, 200, 200], 6150),
        ("ink that grew raises a row", [200, 200, 200, 200, 200, 200], naturals, .inkGrew, [200, 312, 412, 200, 200, 200], 6150),
        ("erasing lowers every row to the window's largest", [200, 200, 200, 200, 200, 200], naturals, .inkShrank, [175, 312, 412, 175, 175, 175], 6150),
        ("deciding again takes every row's largest", [200, 200, 200, 200, 200, 200], naturals, .redecide, [175, 312, 412, 175, 175, 175], 6150),
        ("no previous row floor", [], naturals, .shift, [175, 312, 412, 175, 175, 175], 6150),
        ("a short previous list counts the rest as 0", [500], naturals, .shift, [500, 312, 412, 175, 175, 175], 6150),
        ("a short natural counts the rest as 0", [], [N(rows: [180], gridBottom: 1055, memoHeight: 6000)], .redecide, [180, 0, 0, 0, 0, 0], 6000),
        ("no page and deciding again is no row floor", [200, 200, 200, 200, 200, 200], [], .redecide, [], 0),
        ("junk rows count as 0", [.nan, 200], [N(rows: [.infinity, -4, 175], gridBottom: 0, memoHeight: 0)], .redecide, [0, 0, 175, 0, 0, 0], 0),
    ]
    for (name, rows, ns, change, wantRows, wantMemo) in rowRules {
        var previous = kept
        previous.monthRows = rows
        previous.monthGrid = 1400
        previous.monthMemo = 6000
        let floors = SpanAlign.monthFloors(previous: previous, naturals: ns, form: .rows, change: change)
        var want = kept
        want.monthRows = wantRows
        want.monthMemo = wantMemo
        checkEqual(floors, want, "span my: イ: \(name) (no grid floor; the others kept)")
    }

    // ウ: no month floor at all, whatever came before.
    for change in [SpanAlign.Change.shift, .inkGrew, .inkShrank, .redecide] {
        let previous = SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500, monthGrid: 1400, monthMemo: 6500, monthRows: [200], yearRows: [70])
        checkEqual(SpanAlign.monthFloors(previous: previous, naturals: naturals, form: .none, change: change),
                   SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500, yearRows: [70]), "span my: ウ: \(change) leaves no month floor")
    }

    // Switching the form drops the other form's floor.
    let fromRows = SpanAlign.Floors(monthGrid: 0, monthMemo: 6150, monthRows: [175, 312, 412, 175, 175, 175])
    let toMemo = SpanAlign.monthFloors(previous: fromRows, naturals: naturals, form: .memo, change: .shift)
    check(toMemo.monthRows.isEmpty && toMemo.monthGrid == 1287 && toMemo.monthMemo == 6150, "span my: イ's row floors are dropped by ア")
    let fromMemo = SpanAlign.Floors(monthGrid: 1400, monthMemo: 6150)
    let toRows = SpanAlign.monthFloors(previous: fromMemo, naturals: naturals, form: .rows, change: .shift)
    check(toRows.monthGrid == 0 && toRows.monthRows == [175, 312, 412, 175, 175, 175], "span my: ア's grid floor is dropped by イ")

    // MonthNatural from a page without floors.
    let page = MYF.lay(MYF.october)
    checkEqual(SpanAlign.MonthNatural(page), N(rows: [175, 175, 412, 175, 175, 175], gridBottom: 1287, memoHeight: 6000),
               "span my: October's natural numbers (its 3rd row 412, grid bottom 1,287, memo 6,000)")
    checkEqual(SpanAlign.MonthNatural(MYF.lay(MYF.january)), N(rows: Array(repeating: 175, count: 6), gridBottom: 1050, memoHeight: 6150),
               "span my: January's natural numbers (memo 6,100 + 50)")
}

// MARK: - The three forms on a window of five months (§4.1, §4.2, 0g-10, 0g-11)

private func monthFormChecks() {
    let inputs = MYF.fiveMonths
    let natural = inputs.map { MYF.lay($0) }
    let names = ["m1-2026-09", "m1-2026-10", "m1-2026-11", "m1-2026-12", "m1-2027-01"]
    checkEqual(natural.map(\.pageId), names, "span my: the five months of the window")
    checkEqual(natural.map(\.memo.minY), [1137, 1287, 1187, 1050, 1050], "span my: their natural grid bottoms")
    checkEqual(natural.map(\.memo.height), [6000, 6000, 6000, 6000, 6150], "span my: their natural memo heights")
    let naturals = MYF.naturals(inputs)

    // ア.
    let memo = SpanAlign.monthFloors(previous: .none, naturals: naturals, form: .memo, change: .redecide)
    checkEqual(memo, SpanAlign.Floors(monthGrid: 1287, monthMemo: 6150), "span my: ア: the window's floors are October's grid bottom and January's memo")
    let a = inputs.map { MYF.lay($0, memo) }
    checkEqual(a.map(\.memo.minY), [1287, 1287, 1287, 1287, 1287], "span my: ア: every month's separator line (memo.minY) is at 1,287")
    checkEqual(a.map(\.memo.height), [6150, 6150, 6150, 6150, 6150], "span my: ア: every month's memo is 6,150 tall")
    checkEqual(a.map(\.size.height), [7437, 7437, 7437, 7437, 7437], "span my: ア: every month ends at 7,437")
    checkEqual(a.map { $0.rows[5].frame.height }, [412, 175, 275, 412, 412], "span my: ア: the 6th rows (1,287 − the top of each 6th row)")
    for (k, (page, base)) in zip(a, natural).enumerated() {
        let id = names[k]
        check((0..<5).allSatisfy { page.rows[$0] == base.rows[$0] }, "span my: ア: \(id): rows 1–5 do not move")
        check(page.rows[5].frame.minY == base.rows[5].frame.minY && page.rows[5].frame.minX == 0 && page.rows[5].frame.width == 1400
              && page.rows[5].days == base.rows[5].days && page.rows[5].laneCount == base.rows[5].laneCount && page.rows[5].maxChips == base.rows[5].maxChips,
              "span my: ア: \(id): the 6th row keeps its top, its width and its days, only its height changes")
        let sixth = Set(base.rows[5].days.map { CellKey.day($0) })
        var bad: [String] = []
        for (key, rect) in base.cells {
            guard let got = page.cells[key] else { bad.append(key.raw); continue }
            if key == .memo {
                if got != CGRect(x: 0, y: 1287, width: 1400, height: 6150) { bad.append(key.raw) }
            } else if sixth.contains(key) {
                if got != CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: page.rows[5].frame.height) { bad.append(key.raw) }
            } else if got != rect {
                bad.append(key.raw)
            }
        }
        check(bad.isEmpty && page.cells.count == base.cells.count,
              "span my: ア: \(id): only the 6th row's cells grow and the memo moves to 1,287 (wrong: \(bad.sorted().prefix(4)))")
        check(page.dateLabels == base.dateLabels && page.timedChips == base.timedChips && page.allDayBars == base.allDayBars,
              "span my: ア: \(id): the date labels, the chips and the bars do not move")
    }
    check(a[2].timedChips.count == 1 && a[2].allDayBars.count == 1, "span my: ア: November's 6th row keeps its chip and its bar")
    check(a.allSatisfy { ZoomPolicy.overviewSize($0) == CGSize(width: 1400, height: 1287) },
          "span my: ア: every month's overview is 1,400 × 1,287, so the lowest zoom is the window's whichever month is the middle (0g-16)")

    // イ.
    let rows = SpanAlign.monthFloors(previous: .none, naturals: naturals, form: .rows, change: .redecide)
    checkEqual(rows, SpanAlign.Floors(monthMemo: 6150, monthRows: [175, 312, 412, 175, 175, 262]), "span my: イ: the window's floors are every row's largest")
    let i = inputs.map { MYF.lay($0, rows) }
    for (k, page) in i.enumerated() {
        let id = names[k]
        checkEqual(page.rows.map(\.frame.height), [175, 312, 412, 175, 175, 262], "span my: イ: \(id): the six rows are the window's")
        checkEqual(page.rows.map(\.frame.minY), [0, 175, 487, 899, 1074, 1249], "span my: イ: \(id): the row tops line up")
        check(page.memo == CGRect(x: 0, y: 1511, width: 1400, height: 6150) && page.size.height == 7661,
              "span my: イ: \(id): the separator line at 1,511 and the memo's end line up")
        let base = natural[k]
        check(base.cells.allSatisfy { key, rect in page.cells[key].map { $0.minX == rect.minX && $0.width == rect.width } == true },
              "span my: イ: \(id): every cell keeps its x and its width")
        check(zip(page.dateLabels, base.dateLabels).allSatisfy { $0.day == $1.day && $0.frame.minX == $1.frame.minX } && page.dateLabels.count == base.dateLabels.count,
              "span my: イ: \(id): the date labels keep their columns")
        checkEqual(ZoomPolicy.overviewSize(page), CGSize(width: 1400, height: 1511), "span my: イ: \(id): the overview is 1,400 × 1,511")
    }

    // ウ.
    let u = SpanAlign.monthFloors(previous: memo, naturals: naturals, form: .none, change: .redecide)
    checkEqual(u, .none, "span my: ウ: no floor")
    check(zip(inputs.map { MYF.lay($0, u) }, natural).allSatisfy { $0 == $1 }, "span my: ウ: every month is its page without floors")

    // The month form of the window does not touch the week's floors in the same Floors (they are independent).
    let mixed = SpanAlign.monthFloors(previous: SpanAlign.Floors(weekExtra: 6500), naturals: naturals, form: .memo, change: .redecide)
    check(mixed.weekExtra == 6500 && mixed.monthGrid == 1287, "span my: the week's floor rides along untouched")

    // ア with the Sunday start (K-11): the same five months in 42-day grids from Sunday. The ink and the events fall in
    // the same rows (10/7 in September's 6th, 10/14 in October's 3rd, 11/4 in November's 1st, 11/30 and 12/1 in its 5th),
    // so the floors are the same; the 6th rows hold other days (10/4…, 11/1…, 12/6…, 1/3…, 1/31…).
    let sundayInputs = inputs.map { input -> MonthLayoutInput in
        var sunday = input
        sunday.weekStart = .sunday
        return sunday
    }
    let sundayNatural = sundayInputs.map { MYF.lay($0) }
    let sundayFloors = SpanAlign.monthFloors(previous: .none, naturals: MYF.naturals(sundayInputs), form: .memo, change: .redecide)
    check(sundayNatural.map(\.memo.minY) == [1137, 1287, 1187, 1050, 1050] && sundayFloors == SpanAlign.Floors(monthGrid: 1287, monthMemo: 6150),
          "span my: ア, Sunday start: natural grid bottoms 1,137 / 1,287 / 1,187 / 1,050 / 1,050, floors October's grid bottom and January's memo")
    let sundayA = sundayInputs.map { MYF.lay($0, sundayFloors) }
    check(sundayA.map(\.memo.minY) == [1287, 1287, 1287, 1287, 1287] && sundayA.map { $0.rows[5].frame.height } == [412, 175, 275, 412, 412]
          && sundayA.map { $0.rows[5].days.first } == [MYF.d(2026, 10, 4), MYF.d(2026, 11, 1), MYF.d(2026, 12, 6), MYF.d(2027, 1, 3), MYF.d(2027, 1, 31)],
          "span my: ア, Sunday start: every separator line at 1,287, the 6th rows (from 10/4, 11/1, 12/6, 1/3, 1/31) 412 / 175 / 275 / 412 / 412")
    var sundayBad: [String] = []
    for (k, (page, base)) in zip(sundayA, sundayNatural).enumerated() {
        let sixth = Set(base.rows[5].days.map { CellKey.day($0) })
        let rowsKept = (0..<5).allSatisfy { page.rows[$0] == base.rows[$0] } && page.rows[5].frame.minY == base.rows[5].frame.minY
        let cellsKept = page.cells.count == base.cells.count && base.cells.allSatisfy { key, rect in
            if key == .memo { return page.cells[key] == CGRect(x: 0, y: 1287, width: 1400, height: 6150) }
            if sixth.contains(key) { return page.cells[key] == CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: page.rows[5].frame.height) }
            return page.cells[key] == rect
        }
        if !(rowsKept && cellsKept) { sundayBad.append(names[k]) }
    }
    check(sundayBad.isEmpty, "span my: ア, Sunday start: rows 1–5 do not move, only the 6th row's cells grow, the memo moves to 1,287 × 6,150 (wrong: \(sundayBad))")

    // The memo floor takes effect only when a month's memo ink goes past 5,950 lu (§4.2, 0g-12: the memo is
    // max(6,000, ink + 50)). December, February and March have the same grid bottom (1,050), so the grid floor moves
    // nothing and only the memo floor can.
    for (ink, want) in [(CGFloat(5950), CGFloat(6000)), (5950.5, 6000.5)] {
        let window = [MYF.month(2026, 12, ink: [.memo: ink]), MYF.february, MYF.march]
        let ns = MYF.naturals(window)
        let floors = SpanAlign.monthFloors(previous: .none, naturals: ns, form: .memo, change: .redecide)
        checkEqual(ns.map(\.memoHeight), [want, 6000, 6000], "span my: December's memo ink to \(ink) makes its natural memo \(want) tall")
        checkEqual(floors, SpanAlign.Floors(monthGrid: 1050, monthMemo: want), "span my: memo ink to \(ink): the floors are 1,050 and \(want)")
        let floored = window.map { MYF.lay($0, floors) }
        if ink == 5950 {
            check(zip(floored, window.map { MYF.lay($0) }).allSatisfy { $0 == $1 },
                  "span my: memo ink to 5,950: the memo floor 6,000 changes nothing, every page is its page without floors")
        } else {
            check(floored.allSatisfy { $0.memo == CGRect(x: 0, y: 1050, width: 1400, height: 6000.5) && $0.size.height == 7050.5 },
                  "span my: memo ink to 5,950.5: every page's memo is 6,000.5 tall from 1,050 (the page ends at 7,050.5)")
        }
    }
}

// MARK: - The months that cannot reach (§4.1 4) and the caps

private func monthCapChecks() {
    // October with every one of rows 1–5 at the cap: 5 × 1,200 + 175 = 6,175.
    let tall = MYF.month(2026, 10, ink: [.day(MYF.d(2026, 10, 1)): 1188, .day(MYF.d(2026, 10, 7)): 1188, .day(MYF.d(2026, 10, 14)): 1188,
                                         .day(MYF.d(2026, 10, 21)): 1188, .day(MYF.d(2026, 10, 28)): 1188])
    checkEqual(MYF.lay(tall).memo.minY, 6175, "span my cap: the tall October's grid bottom is 6,175")
    let floors = SpanAlign.monthFloors(previous: .none, naturals: MYF.naturals([tall, MYF.november]), form: .memo, change: .redecide)
    checkEqual(floors.monthGrid, 6175, "span my cap: the window's grid floor is 6,175")
    let november = MYF.lay(MYF.november, floors)
    check(november.rows[5].frame.height == 1200 && november.memo.minY == 1012 + 1200,
          "span my cap: November cannot reach 6,175: its 6th row stops at 1,200 and its separator line stays at 2,212")
    check((0..<5).allSatisfy { november.rows[$0] == MYF.lay(MYF.november).rows[$0] }, "span my cap: November's rows 1–5 still do not move")
    checkEqual(MYF.lay(tall, floors).memo.minY, 6175, "span my cap: the tall October is on its own floor")

    // December (rows of 175, the 6th row's top at 875): a floor 1,200 below the 6th row's top is reached, more is not.
    let december = MYF.december
    let reach = MYF.lay(december, SpanAlign.Floors(monthGrid: 2075))
    check(reach.rows[5].frame.height == 1200 && reach.memo.minY == 2075, "span my cap: a floor of 2,075 is just reached (6th row 1,200)")
    let past = MYF.lay(december, SpanAlign.Floors(monthGrid: 2075.5))
    check(past.rows[5].frame.height == 1200 && past.memo.minY == 2075, "span my cap: a floor of 2,075.5 is not (memo.minY 2,075)")
    let between = MYF.lay(december, SpanAlign.Floors(monthGrid: 1333.25))
    check(between.rows[5].frame.height == 458.25 && between.memo.minY == 1333.25 && between.rows[5].frame.maxY == between.memo.minY,
          "span my cap: a floor of 1,333.25 is met exactly (the 6th row ends where the memo starts)")

    // A row floor and a year floor above the cap stop at the cap; the memo floor has no cap of its own.
    var rowInput = december
    rowInput.rowFloors = [1500, 0, 0, 0, 0, 0]
    checkEqual(MonthLayoutEngine.layout(rowInput).rows[0].frame.height, 1200, "span my cap: a month row floor of 1,500 stops at 1,200")
    var memoInput = december
    memoInput.memoFloor = 9000.5
    checkEqual(MonthLayoutEngine.layout(memoInput).memo.height, 9000.5, "span my cap: a memo floor of 9,000.5 is the memo's height")
    var yearInput = MYF.year2024
    yearInput.rowFloors = [500, 399.5]
    checkEqual(Array(YearLayoutEngine.layout(yearInput).rows.prefix(3).map(\.frame.height)), [400, 399.5, 60], "span my cap: a year row floor of 500 stops at 400")

    // The cap of the memo (K-9) is counted from each month's own separator line.
    let a = MYF.lay(MYF.december, SpanAlign.Floors(monthGrid: 1287, monthMemo: 6150))
    checkEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1287 + 6000.5), in: a), .beyondCap, "span my cap: 6,000.5 below the floored separator line is beyond the cap")
    checkEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1287 + 6000), in: a), nil, "span my cap: 6,000 below it is kept")
}

// MARK: - yearFloors (§5.1, 0g-21)

private func yearFloorChecks() {
    let inputs = MYF.fiveYears
    let natural = inputs.map { MYF.lay($0) }
    let naturalRows = MYF.naturalRows(inputs)
    checkEqual(naturalRows[1][14], 212, "span my year: 2025's row 15 is 212")
    checkEqual(naturalRows[2][2], 78, "span my year: 2026's row 3 is 78 (three lanes)")
    checkEqual(naturalRows[2][30], 392, "span my year: 2026's row 31 is 392")
    checkEqual(naturalRows[3][27], 400, "span my year: 2027's row 28 is the cap, 400")
    checkEqual(naturalRows[4][14], 112, "span my year: 2028's row 15 is 112")
    check(naturalRows.allSatisfy { $0.count == 31 } && naturalRows[0].allSatisfy { $0 == 60 }, "span my year: 31 rows each, 2024's all 60")

    let want = MYF.yearRows(60, [3: 78, 15: 212, 28: 400, 31: 392])
    let floors = SpanAlign.yearFloors(previous: SpanAlign.Floors(dayExtra: 7000, monthGrid: 1287), naturalRows: naturalRows, change: .redecide)
    checkEqual(floors, SpanAlign.Floors(dayExtra: 7000, monthGrid: 1287, yearRows: want), "span my year: row by row the window's largest (the other floors kept)")
    check(floors.yearRows.allSatisfy { $0 <= 400 }, "span my year: every floor is 400 or less")

    let laid = inputs.map { MYF.lay($0, floors) }
    let tops = (0..<31).map { r in want[0..<r].reduce(CGFloat(0), +) }
    for (k, page) in laid.enumerated() {
        let base = natural[k]
        let id = "y-\(inputs[k].year)"
        checkEqual(page.rows.map(\.frame.height), want, "span my year: \(id): every row is the window's")
        checkEqual(page.rows.map(\.frame.minY), tops, "span my year: \(id): the row tops line up (the same day on one line)")
        checkEqual(page.size, CGSize(width: 1400, height: 2702), "span my year: \(id): the paper is 1,400 × 2,702")
        check(base.cells.allSatisfy { key, rect in
            guard let got = page.cells[key], let day = key.yearMonthDay else { return false }
            return got.minX == rect.minX && got.width == rect.width && got.minY == tops[day.day - 1] && got.height == want[day.day - 1]
        } && page.cells.count == base.cells.count, "span my year: \(id): every cell keeps its x and its width and takes its row")
        check(page.invalidCells == base.invalidCells && page.todayCell == base.todayCell && page.rows.map(\.laneCount) == base.rows.map(\.laneCount),
              "span my year: \(id): the invalid cells, today and the lanes do not change")
        check(zip(page.chips, base.chips).allSatisfy { p, b in
            p.eventId == b.eventId && p.day == b.day && p.frame.minX == b.frame.minX && p.frame.size == b.frame.size
                && p.frame.minY - tops[p.day.day - 1] == b.frame.minY - base.rows[b.day.day - 1].frame.minY
        } && page.chips.count == base.chips.count, "span my year: \(id): the chips keep their place in their cell")
        check(zip(page.dateLabels, base.dateLabels).allSatisfy { p, b in
            p.day == b.day && p.frame.minX == b.frame.minX && p.frame.size == b.frame.size && p.frame.minY == tops[p.day.day - 1]
        } && page.dateLabels.count == base.dateLabels.count, "span my year: \(id): the weekday letters go with their rows")
    }
    check(laid[2].chips.count == 5, "span my year: 2026 keeps its five chips (Y1, Y2 on 3/3 and Y3 on 3/2–3/4)")
    check(laid.allSatisfy { ZoomPolicy.overviewSize($0) == CGSize(width: 1400, height: 2702) },
          "span my year: every year's overview (the whole paper) is 1,400 × 2,702 (0g-16's rule for the year)")

    // The table, row by row.
    let r15 = MYF.yearRows(60, [15: 212])
    let r28 = MYF.yearRows(60, [28: 400])
    let previous = MYF.yearRows(60, [3: 78])
    let rules: [(String, [CGFloat], [[CGFloat]], SpanAlign.Change, [CGFloat])] = [
        ("a shift never lowers a row", previous, [r15, r28], .shift, MYF.yearRows(60, [3: 78, 15: 212, 28: 400])),
        ("ink that grew raises a row", previous, [r15, r28], .inkGrew, MYF.yearRows(60, [3: 78, 15: 212, 28: 400])),
        ("erasing lowers every row to the window's largest", previous, [r15, r28], .inkShrank, MYF.yearRows(60, [15: 212, 28: 400])),
        ("deciding again takes every row's largest", previous, [r15, r28], .redecide, MYF.yearRows(60, [15: 212, 28: 400])),
        ("a shift to no page keeps", previous, [], .shift, previous),
        ("deciding again with no page is no floor", previous, [], .redecide, []),
        ("a short natural counts the rest as 0", [], [[60, 70]], .redecide, [60, 70] + Array(repeating: 0, count: 29)),
        ("a value that is not finite counts as 0", [.nan], [[.infinity, 61]], .shift, [0, 61] + Array(repeating: 0, count: 29)),
    ]
    for (name, prev, rows, change, wantRows) in rules {
        let got = SpanAlign.yearFloors(previous: SpanAlign.Floors(weekExtra: 6500, monthRows: [175], yearRows: prev), naturalRows: rows, change: change)
        checkEqual(got, SpanAlign.Floors(weekExtra: 6500, monthRows: [175], yearRows: wantRows), "span my year: \(name) (the others kept)")
    }
}

// MARK: - The floors' policy as the session drives it (§3.3, third edition, 0g-12, 0g-16)

/// SpanSession reads `.redecide` as `.shift` for the month and the year after a shift's prefetch, a reload of the events, the
/// 30 s check and a remote update, decides `.inkGrew` / `.inkShrank` against the window's previous natural numbers, and asks
/// `.redecide` only when it decides the window again (reopening, a width change). These checks walk that path with the Kit's
/// table: a shift and the prefetch after it never lower; erasing lowers; deciding again lowers.
private func monthYearPolicyChecks() {
    func floorsOf(_ previous: SpanAlign.Floors, _ inputs: [MonthLayoutInput], _ change: SpanAlign.Change) -> SpanAlign.Floors {
        SpanAlign.monthFloors(previous: previous, naturals: MYF.naturals(inputs), form: .memo, change: change)
    }
    var f = floorsOf(.none, MYF.fiveMonths, .redecide)
    checkEqual(f.monthGrid, 1287, "span my policy: September – January opens on October's 1,287")
    f = floorsOf(f, [MYF.october, MYF.november, MYF.december, MYF.january, MYF.february], .shift)
    checkEqual(f.monthGrid, 1287, "span my policy: shifted to October – February: 1,287")
    let afterShift = [MYF.november, MYF.december, MYF.january, MYF.february, MYF.march]
    f = floorsOf(f, afterShift, .shift)
    checkEqual(f, SpanAlign.Floors(monthGrid: 1287, monthMemo: 6150), "span my policy: October left the window (November – March): the floors stay")
    // The prefetch reads March (now with ink in its 1st row to 337: 349 + 875 = 1,224); the session passes .shift.
    let marchRead = MYF.month(2027, 3, ink: [.day(MYF.d(2027, 3, 2)): 337])
    let read = [MYF.november, MYF.december, MYF.january, MYF.february, marchRead]
    checkEqual(floorsOf(f, read, .shift).monthGrid, 1287, "span my policy: the prefetch after the shift (read as .shift) keeps 1,287")
    checkEqual(floorsOf(f, read, .redecide).monthGrid, 1224, "span my policy: read as .redecide it would drop to the window's 1,224 (why the session reads it as .shift)")
    f = floorsOf(f, read, .shift)
    // The canvas reads the overview of the window's middle page (bandOverview): November at the opening, January now.
    checkEqual(ZoomPolicy.overviewSize(MYF.lay(MYF.november, floorsOf(.none, MYF.fiveMonths, .redecide))), CGSize(width: 1400, height: 1287),
               "span my policy: the opening window's middle (November) has an overview 1,287 tall")
    checkEqual(ZoomPolicy.overviewSize(MYF.lay(MYF.january, f)), CGSize(width: 1400, height: 1287),
               "span my policy: after the shift and the prefetch the middle (January) still has 1,287: the zoom is not pulled (0g-16)")
    // A little ink in December (row 1 to 213: 225 + 875 = 1,100): nothing of the window fell, so the session says .inkGrew.
    let decemberInk = MYF.month(2026, 12, ink: [.day(MYF.d(2026, 12, 1)): 213])
    checkEqual(floorsOf(f, [MYF.november, decemberInk, MYF.january, MYF.february, marchRead], .inkGrew).monthGrid, 1287,
               "span my policy: a little ink in another month after the tall one left keeps 1,287 (.inkGrew)")
    // Erasing March's ink: .inkShrank comes down to the window's largest (November's 1,187).
    let erased = [MYF.november, decemberInk, MYF.january, MYF.february, MYF.march]
    checkEqual(floorsOf(f, erased, .inkShrank), SpanAlign.Floors(monthGrid: 1187, monthMemo: 6150), "span my policy: erasing comes down to November's 1,187")
    checkEqual(floorsOf(f, erased, .redecide).monthGrid, 1187, "span my policy: a rotation (deciding the window again) comes down too")
    checkEqual(floorsOf(.none, erased, .redecide).monthGrid, 1187, "span my policy: reopening (a new session) starts from the window alone")

    // The year: 2027's row 28 (400) leaves the window; a shift and the prefetch keep it, erasing and deciding again do not.
    func yearOf(_ previous: SpanAlign.Floors, _ inputs: [YearLayoutInput], _ change: SpanAlign.Change) -> SpanAlign.Floors {
        SpanAlign.yearFloors(previous: previous, naturalRows: MYF.naturalRows(inputs), change: change)
    }
    var y = yearOf(.none, MYF.fiveYears, .redecide)
    let later = [MYF.year2028, MYF.year(2029), MYF.year(2030), MYF.year(2031), MYF.year(2032)]
    y = yearOf(y, later, .shift)
    check(y.yearRows[27] == 400 && y.yearRows[30] == 392, "span my policy: the year shifted past 2027 and 2026 keeps rows 28 and 31")
    check(yearOf(y, later, .shift).yearRows[27] == 400 && yearOf(y, later, .redecide).yearRows[27] == 60,
          "span my policy: the year's prefetch read as .shift keeps row 28; .redecide would drop it to 60")
    checkEqual(yearOf(y, later, .inkShrank).yearRows, MYF.yearRows(60, [15: 112]), "span my policy: erasing in the years comes down to 2028's row 15 (112)")
}

// MARK: - PageScroll.scrollDelta across a shift of joined months (§3.5, 0g-17)

private func monthScrollChecks() {
    let plan = SpanFixtures.plan(.month)
    let f1 = SpanAlign.monthFloors(previous: .none, naturals: MYF.naturals(MYF.fiveMonths), form: .memo, change: .redecide)
    let w1 = MYF.monthWindow(MYF.fiveMonths, f1)
    let next = [MYF.october, MYF.november, MYF.december, MYF.january, MYF.february]
    let f2 = SpanAlign.monthFloors(previous: f1, naturals: MYF.naturals(next), form: .memo, change: .shift)
    checkEqual(f2, f1, "span my scroll: the shift to October – February keeps the floors")
    let w2 = MYF.monthWindow(next, f2)
    check(w1.middlePageId == "m1-2026-11" && w1.middleSlot == 2 && w2.middlePageId == "m1-2026-12" && w2.slot(ofPage: "m1-2026-11") == 1,
          "span my scroll: November is the old window's middle and the new window's slot 1")
    // The fixture tells the two rules apart: November's and December's rows do not line up.
    checkEqual(w1.bandTop(.row(2)), 487, "span my scroll: the old middle (November) has its 3rd row at 487")
    checkEqual(w2.bandTop(.row(2)), 350, "span my scroll: the new middle (December) has its 3rd row at 350")
    checkEqual(MYF.middleAnswer(w1, w2, 500), -137, "span my scroll: middle against middle would move a point of November's 3rd row by −137")

    let ys: [CGFloat] = [0, 100, 175, 300, 487, 500, 662, 837, 1012, 1100, 1286, 1287, 1300, 4000, 7436]
    for y in ys {
        checkEqual(PageScroll.scrollDelta(old: w1, new: w2, topVisibleY: y), 0, "span my scroll: a shift that keeps the floors does not move y \(y)")
    }
    for y in [CGFloat(-5), 7437, 9000, .nan, .infinity] {
        checkEqual(PageScroll.scrollDelta(old: w1, new: w2, topVisibleY: y), 0, "span my scroll: y \(y) outside the paper is 0")
    }

    // The separator line goes down 120: February with ink in its 1st row to 520 (532 + 875 = 1,407).
    let tallFebruary = MYF.month(2027, 2, ink: [.day(MYF.d(2027, 2, 3)): 520])
    let lower = [MYF.october, MYF.november, MYF.december, MYF.january, tallFebruary]
    let f3 = SpanAlign.monthFloors(previous: f1, naturals: MYF.naturals(lower), form: .memo, change: .shift)
    checkEqual(f3.monthGrid, 1407, "span my scroll: February raises the grid floor to 1,407")
    let w3 = MYF.monthWindow(lower, f3)
    // 1,300 and 1,406 lie between the old line (1,287) and the new one (1,407): November's memo in the old window, its
    // lengthened 6th row in the new one, so only old's band (not new's) gives 120 there.
    let moves: [(CGFloat, CGFloat)] = [(0, 0), (100, 0), (487, 0), (1012, 0), (1200, 0), (1286.5, 0), (1287, 120), (1300, 120), (1406, 120),
                                       (2000, 120), (7000, 120), (7436, 120)]
    for (y, want) in moves {
        checkEqual(PageScroll.scrollDelta(old: w1, new: w3, topVisibleY: y), want,
                   "span my scroll: the separator line went down 120: y \(y) moves \(want) (the grid stays, the memo follows)")
    }

    // The old middle is not in the new window: 0.
    let far = MYF.monthWindow([MYF.march, MYF.month(2027, 4), MYF.month(2027, 5), MYF.month(2027, 6), MYF.month(2027, 7)], .none)
    check([CGFloat(100), 500, 1300].allSatisfy { PageScroll.scrollDelta(old: w1, new: far, topVisibleY: $0) == 0 }, "span my scroll: a window without the old middle gives 0")

    // A window of one page, a page and the other kinds keep 1.4.2's answer (the middle page's band and tops).
    let oneOctober = SpanFixtures.window([MYF.lay(MYF.october) as any PageLayout], plan: plan)
    let oneNovember = SpanFixtures.window([MYF.lay(MYF.november) as any PageLayout], plan: plan)
    let pageOctober = MYF.lay(MYF.october)
    let pageNovember = MYF.lay(MYF.november)
    var pairs: [(String, any PageLayout, any PageLayout)] = [
        ("one October → one November", oneOctober, oneNovember), ("one November → one October", oneNovember, oneOctober),
        ("five months → one November", w1, oneNovember), ("one October → five months", oneOctober, w2),
        ("five months → the November page", w1, pageNovember), ("the October page → five months", pageOctober, w2),
        ("October page → November page", pageOctober, pageNovember),
    ]
    checkEqual(PageScroll.scrollDelta(old: oneOctober, new: oneNovember, topVisibleY: 400), 487 - 350,
               "span my scroll: one October → one November compares their 3rd rows as 1.4.2 did (+137)")
    let weekPlan = SpanFixtures.plan(.week)
    let weeks = SpanFixtures.window(SpanFixtures.weekPages([5, 12, 19].map(SpanFixtures.october), weekStart: .monday, events: [], now: MYF.now), plan: weekPlan)
    let weeks2 = SpanFixtures.window(SpanFixtures.weekPages([12, 19, 26].map(SpanFixtures.october), weekStart: .monday, events: [], now: MYF.now), plan: weekPlan)
    let dayPlan = SpanFixtures.plan(.day)
    let days = SpanFixtures.window(SpanFixtures.dayPages([12, 13, 14].map(SpanFixtures.october), events: [], now: MYF.now, extraBottoms: [SpanFixtures.october(13): 6950], floor: 7000), plan: dayPlan)
    let days2 = SpanFixtures.window(SpanFixtures.dayPages([13, 14, 15].map(SpanFixtures.october), events: [], now: MYF.now), plan: dayPlan)
    let yf = SpanAlign.yearFloors(previous: .none, naturalRows: MYF.naturalRows(MYF.fiveYears), change: .redecide)
    let years = MYF.yearWindow(MYF.fiveYears, yf)
    let years2 = MYF.yearWindow([MYF.year2025, MYF.year2026, MYF.year2027, MYF.year2028, MYF.year(2029)], yf)
    let rawYears = MYF.yearWindow(MYF.fiveYears, .none)
    let rawYears2 = MYF.yearWindow([MYF.year2025, MYF.year2026, MYF.year2027, MYF.year2028, MYF.year(2029)], .none)
    pairs += [("weeks", weeks, weeks2), ("days", days, days2), ("days back", days2, days), ("lined-up years", years, years2),
              ("years without floors", rawYears, rawYears2), ("years back", rawYears2, rawYears)]
    let probe: [CGFloat] = [-1, 0, 30, 100, 175, 400, 487, 958, 1000, 1287, 1800, 1919, 1920, 2400, 2600, 5000, 9000, .nan]
    for (name, old, new) in pairs {
        let bad = probe.first { PageScroll.scrollDelta(old: old, new: new, topVisibleY: $0) != MYF.middleAnswer(old, new, $0) }
        check(bad == nil, "span my scroll: \(name) keeps 1.4.2's answer (first miss at y \(bad.map { "\($0)" } ?? "none"))")
    }
    check(probe.contains { MYF.middleAnswer(rawYears, rawYears2, $0) != 0 }, "span my scroll: the years without floors do move (the probe sees them)")
}

// MARK: - SpanLayout over month and year windows (§3.1, §5.2, §11.1)

private func monthYearWindowChecks() {
    let naturals = MYF.naturals(MYF.fiveMonths)
    let f1 = SpanAlign.monthFloors(previous: .none, naturals: naturals, form: .memo, change: .redecide)
    let w = MYF.monthWindow(MYF.fiveMonths, f1)
    let names = ["m1-2026-09", "m1-2026-10", "m1-2026-11", "m1-2026-12", "m1-2027-01"]
    checkEqual(w.pages.map(\.pageId), names, "span my window: the five months side by side")
    checkEqual(w.size, CGSize(width: 7000, height: 7437), "span my window: 5 × 1,400 by 7,437")
    func pre(_ cell: CellKey, _ page: String) -> CellKey { SpanName.prefixed(cell, page: page) }

    // The page of the centre's x: left of a boundary, on it (it goes right), right of it.
    let monthPoints: [(String, CGPoint, String, CellKey)] = [
        ("left of the 1st boundary", CGPoint(x: 1399.9, y: 400), "m1-2026-09", .day(MYF.d(2026, 9, 20))),
        ("on the 1st boundary", CGPoint(x: 1400, y: 400), "m1-2026-10", .day(MYF.d(2026, 10, 12))),
        ("right of the 1st boundary", CGPoint(x: 1400.1, y: 400), "m1-2026-10", .day(MYF.d(2026, 10, 12))),
        ("October's 3rd row, Sunday", CGPoint(x: 2799.9, y: 700), "m1-2026-10", .day(MYF.d(2026, 10, 18))),
        ("November's memo", CGPoint(x: 2800 + 700, y: 1387), "m1-2026-11", .memo),
        ("December's lengthened 6th row (Wednesday)", CGPoint(x: 4200 + 450, y: 1200), "m1-2026-12", .day(MYF.d(2027, 1, 6))),
        ("September's lengthened 6th row, just above the line", CGPoint(x: 10, y: 1286.9), "m1-2026-09", .day(MYF.d(2026, 10, 5))),
        ("on September's separator line", CGPoint(x: 10, y: 1287), "m1-2026-09", .memo),
        ("January's memo, 6,000 below the line", CGPoint(x: 5600 + 100, y: 1287 + 6000), "m1-2027-01", .memo),
        ("the window's right edge", CGPoint(x: 7000, y: 100), "m1-2027-01", .day(MYF.d(2027, 1, 3))),
    ]
    for (name, point, page, cell) in monthPoints {
        checkEqual(w.inkCell(forCenter: point), pre(cell, page), "span my window: month: \(name) is \(page)'s \(cell.raw)")
        checkEqual(w.drop(center: point), SpanDrop.keep(page: page, cell: cell), "span my window: month: \(name) keeps it on \(page)")
    }
    checkEqual(MYF.lay(MYF.december).cell(at: CGPoint(x: 450, y: 1200)), .memo, "span my window: without the floor that point of December is its memo")
    checkEqual(w.drop(center: CGPoint(x: 4200 + 450, y: 1287 + 6000.5)), .belowCap, "span my window: month: 6,000.5 below the line is below the cap")
    checkEqual(w.drop(center: CGPoint(x: -0.5, y: 100)), .outsidePaper, "span my window: month: left of the band is outside")
    checkEqual(w.drop(center: CGPoint(x: 7000.5, y: 100)), .outsidePaper, "span my window: month: right of the band is outside")

    // A sweep: every point's cell and drop are its page's at the local point, prefixed.
    var rng = Rng(seed: 143)
    var bad: String?
    for _ in 0..<600 {
        let p = CGPoint(x: rng.double() * 7000, y: rng.double() * 7500 - 30)
        let s = w.slot(atX: p.x)
        let page = w.pages[s]
        let local = CGPoint(x: p.x - CGFloat(s) * 1400, y: p.y)
        if w.inkCell(forCenter: p) != pre(page.inkCell(forCenter: local), page.pageId) || w.cell(at: p) != page.cell(at: local).map({ pre($0, page.pageId) })
            || w.hit(at: p) != page.hit(at: local) || w.dayAt(point: p) != page.dayAt(point: local) {
            bad = bad ?? "\(p)"
        }
    }
    check(bad == nil, "span my window: month: 600 points go to their page's answer (first miss \(bad ?? "none"))")

    // Prefixed names get the page's answer for the bare name; taps, double taps and events go to the page under the point.
    for (slot, page) in w.pages.enumerated() {
        let dx = CGFloat(slot) * 1400
        let id = page.pageId
        check(page.cells.keys.allSatisfy { w.growsWithInk(pre($0, id)) == page.growsWithInk($0) && page.growsWithInk($0) }
              && !w.growsWithInk(.memo) && !w.growsWithInk(pre(.grid, id)), "span my window: month: \(id): growsWithInk of a prefixed name is the page's")
        var points = page.dateLabels.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        points += page.allDayBars.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        points += ((page as? MonthPageLayout)?.timedChips ?? []).map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        points += [CGPoint(x: 700, y: 1300), CGPoint(x: 450, y: 1200), CGPoint(x: 1300, y: 1286)]
        check(points.allSatisfy { w.hit(at: CGPoint(x: $0.x + dx, y: $0.y)) == page.hit(at: $0) }, "span my window: month: \(id): hit is the page's")
        check(points.allSatisfy { w.dayAt(point: CGPoint(x: $0.x + dx, y: $0.y)) == page.dayAt(point: $0) }, "span my window: month: \(id): dayAt is the page's")
        check(points.allSatisfy { p in
            let r = CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)
            return w.eventRange(for: r.offsetBy(dx: dx, dy: 0), now: MYF.now, calendar: tokyo) == page.eventRange(for: r, now: MYF.now, calendar: tokyo)
        }, "span my window: month: \(id): eventRange is the page's")
        // The memo's handwriting is kept relative to the memo's origin, which is the separator line the lines are drawn from:
        // a stroke 450 lu below the memo's top is 450 lu below the separator line, with or without the floor.
        let memo = page.cells[.memo]
        check(memo == CGRect(x: 0, y: 1287, width: 1400, height: 6150) && w.cells[pre(.memo, id)] == memo?.offsetBy(dx: dx, dy: 0),
              "span my window: month: \(id): the memo cell is the floored memo rect, moved to its slot")
    }
    let variants: [(String, [MonthPageLayout])] = [
        ("without floors", MYF.fiveMonths.map { MYF.lay($0) }),
        ("ア", MYF.fiveMonths.map { MYF.lay($0, f1) }),
        ("イ", MYF.fiveMonths.map { MYF.lay($0, SpanAlign.monthFloors(previous: .none, naturals: naturals, form: .rows, change: .redecide)) }),
        ("ア, shifted", [MYF.october, MYF.november, MYF.december, MYF.january, MYF.february].map { MYF.lay($0, f1) }),
    ]
    for (name, pages) in variants {
        check(pages.allSatisfy { page in
            let stroke = CGPoint(x: 300, y: 450)
            let paper = MonthLayoutEngine.paperPoint(of: .memo, in: page)
            return page.cells[.memo] == page.memo && paper.y + stroke.y - page.memo.minY == 450
                && MonthLayoutEngine.cellRelative(CGPoint(x: paper.x + stroke.x, y: paper.y + stroke.y), cell: .memo, in: page) == stroke
        }, "span my window: month \(name): a memo stroke and the separator line keep their distance (memo origin = memo.minY)")
    }

    // The light path: only the memos' height changed → true; a 6th row grew and the line moved → false.
    let grownMemo = [MYF.september, MYF.october, MYF.november, MYF.december, MYF.month(2027, 1, ink: [.memo: 6300])]
    let fMemo = SpanAlign.monthFloors(previous: f1, naturals: MYF.naturals(grownMemo), form: .memo, change: .inkGrew)
    check(fMemo.monthGrid == 1287 && fMemo.monthMemo == 6350, "span my window: January's memo to 6,300 raises only the memo floor (6,350)")
    let wMemo = MYF.monthWindow(grownMemo, fMemo)
    check(wMemo.onlyTailHeightChanged(from: w), "span my window: only the memos grew: the light path (onlyTailHeightChanged)")
    let grownRow = [MYF.september, MYF.october, MYF.month(2026, 11, events: MYF.november.events, ink: [.day(MYF.d(2026, 11, 4)): 600]), MYF.december, MYF.january]
    let fRow = SpanAlign.monthFloors(previous: f1, naturals: MYF.naturals(grownRow), form: .memo, change: .inkGrew)
    checkEqual(fRow.monthGrid, 1487, "span my window: November's 2nd row to 612 raises the grid floor to 1,487")
    let wRow = MYF.monthWindow(grownRow, fRow)
    check(!wRow.onlyTailHeightChanged(from: w), "span my window: a 6th row grew and the line moved: not the light path")
    check(!PaperGrowth.onlyTailHeightChanged(old: w.pages[0], new: wRow.pages[0]) && PaperGrowth.onlyTailHeightChanged(old: w.pages[0], new: wMemo.pages[0]),
          "span my window: September alone: the moved line is not light, the taller memo is")

    // Years: the gutter of the right year is its January (x goes negative), the right edge of the left year its December.
    let yf = SpanAlign.yearFloors(previous: .none, naturalRows: MYF.naturalRows([MYF.year2025, MYF.year2026, MYF.year2027]), change: .redecide)
    let yw = MYF.yearWindow([MYF.year2025, MYF.year2026, MYF.year2027], yf)
    checkEqual(yw.pages.map(\.pageId), ["y-2025", "y-2026", "y-2027"], "span my window: three years side by side")
    // Row 15 starts at 14 × 60 + 18 (row 3 is 78) = 858 and is 212 tall.
    checkEqual(yw.bandTop(.row(15)), 858, "span my window: row 15 of the lined-up years starts at 858")
    let yearPoints: [(String, CGPoint, String, CellKey)] = [
        ("left of the boundary (2025's December)", CGPoint(x: 1399.9, y: 958), "y-2025", .yearDay(month: 12, day: 15)),
        ("on the boundary (2026's gutter → January)", CGPoint(x: 1400, y: 958), "y-2026", .yearDay(month: 1, day: 15)),
        ("2026's gutter", CGPoint(x: 1400 + 20, y: 958), "y-2026", .yearDay(month: 1, day: 15)),
        ("2026's January", CGPoint(x: 1400 + 60, y: 958), "y-2026", .yearDay(month: 1, day: 15)),
        ("2027's December, row 31", CGPoint(x: 2800 + 56 + 112 * 11 + 50, y: 2702 - 1), "y-2027", .yearDay(month: 12, day: 31)),
        ("2025's row 28, lined up to 400 (1,790 – 2,190)", CGPoint(x: 56 + 112 + 30, y: 2100), "y-2025", .yearDay(month: 2, day: 28)),
    ]
    for (name, point, page, cell) in yearPoints {
        checkEqual(yw.inkCell(forCenter: point), pre(cell, page), "span my window: year: \(name) is \(page)'s \(cell.raw)")
        checkEqual(yw.drop(center: point), SpanDrop.keep(page: page, cell: cell), "span my window: year: \(name) keeps it on \(page)")
    }
    checkEqual(yw.drop(center: CGPoint(x: 500, y: 2702.5)), .outsidePaper, "span my window: year: below the paper is outside (no last cell)")
    for (slot, page) in yw.pages.enumerated() {
        let dx = CGFloat(slot) * 1400
        let id = page.pageId
        check(page.cells.keys.allSatisfy { yw.growsWithInk(pre($0, id)) && page.growsWithInk($0) }, "span my window: year: \(id): growsWithInk of a prefixed name is the page's")
        var points = page.dateLabels.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }
        if let year = page as? YearPageLayout { points += year.chips.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } }
        points += [CGPoint(x: 20, y: 958), CGPoint(x: 1399, y: 2700)]
        check(points.allSatisfy { yw.hit(at: CGPoint(x: $0.x + dx, y: $0.y)) == page.hit(at: $0) && yw.dayAt(point: CGPoint(x: $0.x + dx, y: $0.y)) == page.dayAt(point: $0) },
              "span my window: year: \(id): hit and dayAt are the page's")
        check(points.allSatisfy { p in
            let r = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
            return yw.eventRange(for: r.offsetBy(dx: dx, dy: 0), now: MYF.now, calendar: tokyo) == page.eventRange(for: r, now: MYF.now, calendar: tokyo)
        }, "span my window: year: \(id): eventRange is the page's")
    }
}
