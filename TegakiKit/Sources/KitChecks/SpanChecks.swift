// KitChecks: the checks of the joined pages of 1.3 (docs/M7C_CONTRACT.md §10.1, section "span (1.3)").
// main.swift calls `runSpanChecks()` right after "compat with 1.0 (K-7)"; it uses main.swift's
// `section`, `check`, `checkEqual`, `tokyo`, `date`, `october`, `allDay`, `timed` and `Rng`.
//
// This file holds the Layout half of §10.1 (SpanName, SpanPlan, SpanAlign, SpanLayout, K-10; role K,
// part 1). The InkModel half (SpanGuard, SpanComposer, PageDelta; part 2) goes into its own file with
// a `runSpanInkChecks()` that opens the section "span ink (1.3)" and is called on the line after
// `runSpanChecks()` in main.swift; `SpanFixtures` below is shared with it (the real names and the
// prefixed names of §10.1, the plans, the window pages).
//
// The expectations are worked out apart from the code under test: page numbers from Foundation's
// calendar (UTC, days since 1970-01-01, only years after 1582, where Foundation's calendar is
// Gregorian), names and rects as literals, the window table as the numbers of B_DESIGN.md §6.2 and
// the contract's §3.6.
import Foundation
import CoreGraphics
import Layout

// MARK: - Shared fixtures (part 1 and part 2)

enum SpanFixtures {
    /// Names that exist in real data (§10.1): page ids (a Sunday week too), cells, the old band cells,
    /// names a later version may use, stroke ids of the web version ("~w1") and of the app, ids with a
    /// "|" that is not a page prefix (an import, a hand-edited JSON, an unknown tool). None of them is
    /// prefixed or virtual.
    static let realNames: [String] = [
        "d-2026-11-02", "w-2026-11-02", "w-2026-11-01", "m1-2026-11", "y-2026",
        "grid", "extra", "memo", "2026-11-02", "01-20", "02-30", "allday", "allday:2026-11-02",
        "band:2026-11-02", "focus:2026-11", "plan:2026-11-02", "wb-2026-11-02", "db-2026-11-02",
        "8F14E45F-CEEA-467A-9E0E-5C0C1A9B6E0F", "k3j2h1~w1", "s1~w1", "abc~", "~w1",
        "abc|def", "|grid", "grid|", "w-2026|x", "d-2026-11-2|x", "w-2026-11-02x|y", "m1-2026-1|x",
        "y-26|x", "W-2026-11-02|x", "w-\u{FF12}\u{FF10}\u{FF12}\u{FF16}-11-02|x", "xw-2026-11-02|grid",
        "photo|img", "text|1", "span", "span-week-1", "spa~n",
        String(repeating: "a", count: 128),
    ]

    /// The real page ids the prefixed names are made with.
    static let pageIds = ["d-2026-11-02", "w-2026-11-02", "w-2026-11-01", "m1-2026-11", "y-2026", "w-1969-12-29"]

    /// The local parts the prefixed names are made with (a local part may hold a "|" of its own).
    static let locals = ["grid", "extra", "memo", "2026-11-02", "01-20", "8F14E45F-CEEA-467A-9E0E-5C0C1A9B6E0F",
                         "k3j2h1~w1", "a|b", "", "span~a~3", "allday:2026-11-02"]

    /// Every page id × every local part, joined by hand.
    static var prefixedNames: [(name: String, page: String, local: String)] {
        pageIds.flatMap { page in locals.map { (page + "|" + $0, page, $0) } }
    }

    static func plan(_ kind: PageKind, _ weekStart: WeekStart = .monday, _ device: SpanDeviceClass = .iPad11,
                     _ orientation: SpanOrientation = .portrait) -> SpanPlan {
        SpanPlan(kind: kind, weekStart: weekStart, deviceClass: device, orientation: orientation)
    }

    /// Days since 1970-01-01 by Foundation (UTC), not by `DayKey`.
    static func dayNumber(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let date = utc.date(from: DateComponents(year: y, month: m, day: d))!
        return Int((date.timeIntervalSince(epoch) / 86_400).rounded())
    }

    /// "YYYY-MM-DD" of the day `n` days after 1970-01-01, and its weekday (0 = Sunday), by Foundation.
    static func ymd(dayNumber n: Int) -> (text: String, weekday: Int) {
        let date = epoch.addingTimeInterval(TimeInterval(n) * 86_400)
        let c = utc.dateComponents([.year, .month, .day, .weekday], from: date)
        return (String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!), c.weekday! - 1)
    }

    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static let epoch: Date = utc.date(from: DateComponents(year: 1970, month: 1, day: 1))!
}

// MARK: - The section

func runSpanChecks() {
    section("span (1.3)")
    spanNameChecks()
    spanPlanNumberChecks()
    spanPlanGeometryChecks()
    spanWindowTableChecks()
    spanShiftAndFlingChecks()
    spanK10Checks()
}

// MARK: - SpanName (§2.1, §3.2, §6.1)

func spanNameChecks() {
    checkEqual(String(SpanName.separator), "|", "span name: the separator is |")
    checkEqual(SpanName.virtualPrefix, "span~", "span name: the virtual prefix is span~")
    checkEqual(SpanName.idByteLimit, 128, "span name: ids are at most 128 bytes (InkStroke.isValidId)")

    // Real names are never prefixed nor virtual, and strip / split leave them alone.
    for name in SpanFixtures.realNames {
        check(!SpanName.isPrefixed(name) && SpanName.split(name) == nil && SpanName.strip(id: name) == name
              && SpanName.strip(CellKey(raw: name)) == CellKey(raw: name) && !SpanName.isVirtual(name),
              "span name: the real name \(name) is not prefixed, not virtual, and strip keeps it")
    }

    // Prefixed names: "<page>|<local>" both ways.
    for (name, page, local) in SpanFixtures.prefixedNames {
        let split = SpanName.split(name)
        check(SpanName.prefixed(id: local, page: page) == name && SpanName.prefixed(CellKey(raw: local), page: page).raw == name
              && SpanName.isPrefixed(name) && split?.page == page && split?.local == local
              && SpanName.strip(id: name) == local && SpanName.strip(CellKey(raw: name)).raw == local,
              "span name: \(name) is prefixed, splits into (\(page), \(local)) and strips to \(local)")
    }
    check(SpanName.isPrefixed("w-2026-13-45|grid"), "span name: the form is what counts (w-2026-13-45|grid is prefixed, as SpanGuard sees it)")
    checkEqual(SpanName.strip(id: "w-2026-11-02|d-2026-11-03|grid"), "d-2026-11-03|grid", "span name: strip removes one prefix")
    check(SpanName.split("y-2026|")?.local == "" && SpanName.split("y-2026|")?.page == "y-2026", "span name: an empty local part")

    // The virtual page id and the aliases of long ids.
    checkEqual(SpanName.virtualPageId(.week, session: 7), "span~week~7", "span name: the virtual id of a week session")
    checkEqual(SpanName.virtualPageId(.day, session: 0), "span~day~0", "span name: the virtual id of a day session")
    check(SpanName.isVirtual("span~week~7") && !SpanName.isPrefixed("span~week~7") && PageNavigation.parse(pageId: "span~week~7") == nil,
          "span name: a virtual id is virtual, not prefixed, and no page id")
    let alias = SpanName.alias(page: "w-2026-11-02", number: 12)
    checkEqual(alias, "w-2026-11-02|span~a~12", "span name: the alias form <pageId>|span~a~<n>")
    check(SpanName.isPrefixed(alias) && SpanName.isVirtual(SpanName.strip(id: alias)),
          "span name: a stripped alias starts with span~ (SpanGuard's rule stops it if the table misses it)")
    check(SpanName.aliasNumber(alias).map { $0.page == "w-2026-11-02" && $0.number == 12 } == true, "span name: the alias's page and number")
    for bad in ["w-2026-11-02|span~a~", "w-2026-11-02|span~a~x", "w-2026-11-02|span~a~012", "span~a~3", "w-2026-11-02|span~b~3", "w-2026-11-02|grid"] {
        check(SpanName.aliasNumber(bad) == nil, "span name: \(bad) is no alias")
    }
    check(SpanName.alias(page: "d-2026-11-02", number: 3) != SpanName.alias(page: "d-2026-11-03", number: 3),
          "span name: the same number on two pages gives two names")
    let page13 = "w-2026-11-02|" // 13 bytes
    check(!SpanName.needsAlias(page13 + String(repeating: "x", count: 115)), "span name: a prefixed id of 128 bytes needs no alias")
    check(SpanName.needsAlias(page13 + String(repeating: "x", count: 116)), "span name: a prefixed id of 129 bytes needs an alias")
    check(SpanName.needsAlias(page13 + String(repeating: "\u{3042}", count: 39)), "span name: bytes, not characters, count (13 + 39 × 3 = 130)")

    // The page's own name gives the page's own answers (isTail, needsMoreRoom).
    for (page, local) in [("d-2026-11-02", CellKey.extra), ("m1-2026-11", .memo), ("d-2026-11-02", .grid), ("y-2026", CellKey(raw: "01-20"))] {
        let stripped = SpanName.strip(SpanName.prefixed(local, page: page))
        check(PaperGrowth.isTail(stripped) == PaperGrowth.isTail(local)
              && [0, 100, 5950, 5951, 7000].allSatisfy { b in
                  PaperGrowth.needsMoreRoom(cell: stripped, cellHeight: 6000, inkBottom: b) == PaperGrowth.needsMoreRoom(cell: local, cellHeight: 6000, inkBottom: b)
              },
              "span name: \(page)|\(local) stripped gives isTail and needsMoreRoom of \(local)")
    }
    check(PaperGrowth.isTail(SpanName.strip(CellKey(raw: "d-2026-11-02|extra"))) && !PaperGrowth.isTail(CellKey(raw: "d-2026-11-02|extra")),
          "span name: a prefixed extra is the tail only once stripped (why the ledger strips first, §3.3)")
}

// MARK: - SpanPlan: page numbers and ids (§3.2, §3.9)

func spanPlanNumberChecks() {
    let mon = SpanFixtures.plan(.week, .monday)
    let sun = SpanFixtures.plan(.week, .sunday)
    let dayPlan = SpanFixtures.plan(.day)
    let monthPlan = SpanFixtures.plan(.month)
    let yearPlan = SpanFixtures.plan(.year)

    // Anchors (Python's datetime: 2026-11-09 is day 20766, a Monday; 1970-01-01 a Thursday).
    let anchors: [(SpanPlan, String, Int)] = [
        (dayPlan, "d-1970-01-01", 0), (dayPlan, "d-1969-12-31", -1), (dayPlan, "d-2026-11-11", 20768),
        (mon, "w-1970-01-05", 0), (mon, "w-1969-12-29", -1), (mon, "w-2026-11-09", 2966), (mon, "w-2026-11-02", 2965),
        (mon, "w-2026-12-28", 2973), (mon, "w-2027-01-04", 2974),
        (sun, "w-1970-01-04", 0), (sun, "w-1969-12-28", -1), (sun, "w-2026-11-08", 2966), (sun, "w-2026-11-01", 2965),
        (sun, "w-2026-12-27", 2973), (sun, "w-2027-01-03", 2974),
        (monthPlan, "m1-2026-11", 2026 * 12 + 10), (monthPlan, "m1-2026-12", 24323), (monthPlan, "m1-2027-01", 24324),
        (monthPlan, "m1-0001-01", 12), (yearPlan, "y-2026", 2026), (yearPlan, "y-2027", 2027), (yearPlan, "y-0001", 1),
    ]
    for (plan, id, n) in anchors {
        checkEqual(plan.index(of: id), n, "span plan: \(plan.kind) \(plan.weekStart) index of \(id)")
        checkEqual(plan.pageId(at: n), id, "span plan: \(plan.kind) \(plan.weekStart) page id of \(n)")
    }
    check(mon.index(of: "w-2026-11-09") == sun.index(of: "w-2026-11-08"),
          "span plan: a Monday and the Sunday before it have the same number (7n + 4 / 7n + 3)")

    // Next and previous pages across the year boundaries (and a leap day, and 2100 without one).
    let steps: [(SpanPlan, String, Int, String)] = [
        (mon, "w-2026-12-28", 1, "w-2027-01-04"), (mon, "w-2027-01-04", -1, "w-2026-12-28"),
        (sun, "w-2026-12-27", 1, "w-2027-01-03"), (sun, "w-2027-01-03", -1, "w-2026-12-27"),
        (mon, "w-2026-11-02", 9, "w-2027-01-04"), (sun, "w-2026-11-01", 9, "w-2027-01-03"),
        (dayPlan, "d-2026-12-31", 1, "d-2027-01-01"), (dayPlan, "d-2027-01-01", -1, "d-2026-12-31"),
        (dayPlan, "d-2028-02-28", 1, "d-2028-02-29"), (dayPlan, "d-2028-02-28", 2, "d-2028-03-01"),
        (dayPlan, "d-2100-02-28", 1, "d-2100-03-01"), (dayPlan, "d-1970-01-01", -1, "d-1969-12-31"),
        (monthPlan, "m1-2026-12", 1, "m1-2027-01"), (monthPlan, "m1-2027-01", -1, "m1-2026-12"),
        (monthPlan, "m1-2026-11", 14, "m1-2028-01"), (monthPlan, "m1-2026-01", -13, "m1-2024-12"),
        (yearPlan, "y-2026", 1, "y-2027"), (yearPlan, "y-2000", -1, "y-1999"),
    ]
    for (plan, id, delta, expected) in steps {
        let next = plan.index(of: id).map { plan.pageId(at: $0 + delta) }
        checkEqual(next, expected, "span plan: \(plan.kind) \(plan.weekStart) \(id) \(delta > 0 ? "+" : "")\(delta) is \(expected)")
    }

    // Every page of 1900…2200 both ways, against Foundation's calendar.
    var firstBad: String?
    let lo = SpanFixtures.dayNumber(1900, 1, 1)
    let hi = SpanFixtures.dayNumber(2200, 12, 31)
    var n = lo
    while n <= hi && firstBad == nil {
        let (text, weekday) = SpanFixtures.ymd(dayNumber: n)
        if dayPlan.pageId(at: n) != "d-" + text || dayPlan.index(of: "d-" + text) != n { firstBad = "day \(text)" }
        let weekIndex = Int((Double(n) / 7).rounded(.down))
        if weekday == 1 && (mon.pageId(at: weekIndex) != "w-" + text || mon.index(of: "w-" + text) != weekIndex) { firstBad = "Monday week \(text)" }
        if weekday == 0 && (sun.pageId(at: weekIndex) != "w-" + text || sun.index(of: "w-" + text) != weekIndex) { firstBad = "Sunday week \(text)" }
        if weekday == 0 && mon.index(of: "w-" + text) != nil { firstBad = "a Sunday id in a Monday plan \(text)" }
        if weekday == 1 && sun.index(of: "w-" + text) != nil { firstBad = "a Monday id in a Sunday plan \(text)" }
        if weekday > 1 && (mon.index(of: "w-" + text) != nil || sun.index(of: "w-" + text) != nil) { firstBad = "a mid-week id \(text)" }
        n += 1
    }
    check(firstBad == nil, "span plan: day and week (Monday and Sunday) ids of 1900…2200 go both ways, other weekdays are refused (\(firstBad ?? "all"))")
    var monthBad: String?
    for y in 1900...2200 {
        for m in 1...12 {
            let id = String(format: "m1-%04d-%02d", y, m)
            if monthPlan.index(of: id) != y * 12 + m - 1 || monthPlan.pageId(at: y * 12 + m - 1) != id { monthBad = monthBad ?? id }
        }
        let id = String(format: "y-%04d", y)
        if yearPlan.index(of: id) != y || yearPlan.pageId(at: y) != id { monthBad = monthBad ?? id }
    }
    check(monthBad == nil, "span plan: month and year ids of 1900…2200 go both ways (\(monthBad ?? "all"))")

    // Each week's first day: the right weekday, 7 days after the one before (Foundation).
    var weekBad: String?
    for plan in [mon, sun] {
        for i in -100...4000 {
            let text = String(plan.pageId(at: i).dropFirst(2))
            let expected = SpanFixtures.ymd(dayNumber: i * 7 + (plan.weekStart == .monday ? 4 : 3))
            if text != expected.text || expected.weekday != plan.weekStart.firstWeekday { weekBad = weekBad ?? "\(plan.weekStart) \(i)" }
            if plan.firstDay(at: i).description != text { weekBad = weekBad ?? "firstDay \(plan.weekStart) \(i)" }
        }
    }
    check(weekBad == nil, "span plan: page n of a Monday week is day 7n + 4, of a Sunday week 7n + 3 (\(weekBad ?? "all"))")

    // What a plan refuses.
    let refused: [(SpanPlan, String)] = [
        (mon, "w-2026-11-08"), (mon, "w-2026-11-10"), (sun, "w-2026-11-09"), (sun, "w-2026-11-14"),
        (mon, "d-2026-11-09"), (mon, "m1-2026-11"), (mon, "y-2026"), (mon, "span~week~0"), (mon, "w-2026-11-09|grid"),
        (mon, "w-2026-13-01"), (mon, "w-2026-11-9"), (mon, ""), (mon, "W-2026-11-09"), (mon, "wb-2026-11-09"),
        (dayPlan, "w-2026-11-09"), (dayPlan, "d-2026-02-29"), (dayPlan, "d-2026-11-09 "), (dayPlan, "span~day~1"),
        (monthPlan, "m1-2026-13"), (monthPlan, "m1-2026-1"), (monthPlan, "d-2026-11-01"), (yearPlan, "y-26"), (yearPlan, "y-2026-01"),
    ]
    for (plan, id) in refused {
        check(plan.index(of: id) == nil, "span plan: a \(plan.kind) \(plan.weekStart) plan refuses \(id)")
    }
    checkEqual(dayPlan.index(of: "d-2028-02-29"), SpanFixtures.dayNumber(2028, 2, 29), "span plan: d-2028-02-29 exists")

    // The page holding a day.
    for d in 9...15 {
        checkEqual(mon.index(containing: DayKey(year: 2026, month: 11, day: d)), 2966, "span plan: Monday week: 2026-11-\(d) is on page 2966")
    }
    checkEqual(mon.index(containing: DayKey(year: 2026, month: 11, day: 8)), 2965, "span plan: Monday week: Sunday 11-08 is on the page before")
    for d in 8...14 {
        checkEqual(sun.index(containing: DayKey(year: 2026, month: 11, day: d)), 2966, "span plan: Sunday week: 2026-11-\(d) is on page 2966")
    }
    checkEqual(sun.index(containing: DayKey(year: 2026, month: 11, day: 15)), 2967, "span plan: Sunday week: Sunday 11-15 starts the next page")
    checkEqual(mon.index(containing: DayKey(year: 2027, month: 1, day: 3)), 2973, "span plan: Monday week: 2027-01-03 is on the week of 2026-12-28")
    checkEqual(sun.index(containing: DayKey(year: 2027, month: 1, day: 2)), 2973, "span plan: Sunday week: 2027-01-02 is on the week of 2026-12-27")
    checkEqual(dayPlan.index(containing: DayKey(year: 2026, month: 11, day: 11)), 20768, "span plan: the day page of 2026-11-11")
    checkEqual(monthPlan.index(containing: DayKey(year: 2026, month: 11, day: 30)), 24322, "span plan: the month page of 2026-11-30")
    checkEqual(yearPlan.index(containing: DayKey(year: 2026, month: 12, day: 31)), 2026, "span plan: the year page of 2026-12-31")

    // A plan is one shape.
    check(mon == SpanFixtures.plan(.week, .monday) && mon != sun && mon != SpanFixtures.plan(.week, .monday, .iPhone),
          "span plan: equal when everything is equal, else not")
}

// MARK: - SpanPlan: origin, owner, focus (§3.2, D15, §3.16)

func spanPlanGeometryChecks() {
    let week = SpanFixtures.plan(.week)          // iPad 11 portrait: R = 2
    let dayPlan = SpanFixtures.plan(.day)        // iPad 11 portrait: R = 3
    checkEqual(week.pageWidth, 1400, "span plan: a week page is 1400 lu wide")
    checkEqual(dayPlan.pageWidth, 1000, "span plan: a day page is 1000 lu wide")

    checkEqual(week.origin(of: 2966, around: 2966), 2800, "span plan: the focus week sits at R × 1400 = 2800")
    checkEqual(week.origin(of: 2964, around: 2966), 0, "span plan: the window's first week sits at 0")
    checkEqual(week.origin(of: 2968, around: 2966), 5600, "span plan: the window's last week sits at 5600")
    checkEqual(dayPlan.origin(of: 20768, around: 20768), 3000, "span plan: the focus day sits at R × 1000 = 3000")
    checkEqual(dayPlan.origin(of: 20765, around: 20768), 0, "span plan: the window's first day sits at 0")
    checkEqual(week.window(around: 2966), 2964...2968, "span plan: the week window is focus ± 2")
    checkEqual(dayPlan.window(around: 20768), 20765...20771, "span plan: the day window is focus ± 3")

    // Half-open [k W, (k + 1) W); exactly on a boundary goes right.
    let ownerCases: [(SpanPlan, CGFloat, Int)] = [
        (week, 0, 0), (week, 1399.999, 0), (week, 1400, 1), (week, 1400.001, 1), (week, 2800, 2), (week, 2799.9999, 1),
        (week, -0.001, -1), (week, -1400, -1), (week, -1400.001, -2), (week, 7000, 5),
        (dayPlan, 999.5, 0), (dayPlan, 1000, 1), (dayPlan, -1000, -1), (dayPlan, -999.99, -1), (dayPlan, 2500, 2),
        (week, .nan, 0), (week, .infinity, 0), (week, -.infinity, 0),
    ]
    for (plan, x, k) in ownerCases {
        checkEqual(plan.owner(ofCenterX: x), k, "span plan: \(plan.kind) x = \(x) belongs to slot \(k)")
    }
    var ownerBad: String?
    for plan in [week, dayPlan] {
        let w: CGFloat = plan.kind == .week ? 1400 : 1000
        for k in -30...60 {
            let x = CGFloat(k) * w
            if plan.owner(ofCenterX: x) != k || plan.owner(ofCenterX: x - 0.0001) != k - 1 || plan.owner(ofCenterX: x + 0.0001) != k {
                ownerBad = ownerBad ?? "\(plan.kind) \(k)"
            }
        }
    }
    check(ownerBad == nil, "span plan: every boundary k × W of -30…60 goes right, a hair left of it goes left (\(ownerBad ?? "all"))")

    // The focus stays inside [X − 6 %, X + W + 6 %) of the previous page (84 lu for a week, 60 for a day).
    checkEqual(SpanPlan.focusHysteresis, 0.06, "span plan: the hysteresis is 6 % of a page")
    let focusCases: [(SpanPlan, CGFloat, Int, Int)] = [
        (week, 2716, 2, 2), (week, 2715.999, 2, 1), (week, 4283.999, 2, 2), (week, 4284, 2, 3), (week, 4200, 2, 2),
        (week, 2800, 2, 2), (week, 3500, 1, 2), (week, 10_000, 2, 7), (week, -50, 2, -1), (week, .nan, 2, 2),
        (dayPlan, -60, 0, 0), (dayPlan, -60.001, 0, -1), (dayPlan, 1059.99, 0, 0), (dayPlan, 1060, 0, 1), (dayPlan, 1000, 0, 0),
        (dayPlan, 1000, 1, 1), (dayPlan, 939.999, 1, 0), (dayPlan, 940, 1, 1),
    ]
    for (plan, x, previous, expected) in focusCases {
        checkEqual(plan.focus(midX: x, previous: previous), expected, "span plan: \(plan.kind) focus at midX \(x) after \(previous) is \(expected)")
    }
}

// MARK: - SpanPlan: the window table (§3.6, B_DESIGN.md §6.2), recomputed with 1.1.1's zoom

func spanWindowTableChecks() {
    // (device, orientation, kind, V of B_DESIGN.md §6.2 (two decimals), pages of the window (§3.6))
    let table: [(SpanDeviceClass, SpanOrientation, PageKind, CGFloat, Int)] = [
        (.iPad11, .portrait, .week, 1.20, 5), (.iPad11, .portrait, .day, 2.10, 7),
        (.iPad11, .landscape, .week, 2.70, 7), (.iPad11, .landscape, .day, 4.72, 9),
        (.iPad13, .portrait, .week, 1.26, 5), (.iPad13, .portrait, .day, 2.22, 7),
        (.iPad13, .landscape, .week, 2.33, 7), (.iPad13, .landscape, .day, 4.07, 9),
        (.iPadMini, .portrait, .week, 1.16, 5), (.iPadMini, .portrait, .day, 2.04, 5),
        (.iPadMini, .landscape, .week, 2.96, 7), (.iPadMini, .landscape, .day, 5.18, 9),
        (.iPhone, .portrait, .week, 1.02, 5), (.iPhone, .portrait, .day, 1.80, 5),
        (.iPhone, .landscape, .week, 5.85, 9), (.iPhone, .landscape, .day, 10.23, 15),
        // The month and the year (1.7, 1.8; B_DESIGN.md §6.2), from the same paper areas.
        (.iPad11, .portrait, .month, 1.00, 5), (.iPad11, .portrait, .year, 1.13, 5),
        (.iPad11, .landscape, .month, 1.42, 5), (.iPad11, .landscape, .year, 2.51, 7),
        (.iPad13, .portrait, .month, 1.00, 5), (.iPad13, .portrait, .year, 1.19, 5),
        (.iPad13, .landscape, .month, 1.23, 5), (.iPad13, .landscape, .year, 2.19, 7),
        (.iPadMini, .portrait, .month, 1.00, 5), (.iPadMini, .portrait, .year, 1.09, 5),
        (.iPadMini, .landscape, .month, 1.54, 5), (.iPadMini, .landscape, .year, 2.74, 7),
        (.iPhone, .portrait, .month, 1.00, 5), (.iPhone, .portrait, .year, 1.00, 5),
        (.iPhone, .landscape, .month, 2.85, 7), (.iPhone, .landscape, .year, 5.05, 9),
    ]
    print("   window table (1.1.1 zoom = ZoomPolicy.bounds(…).min of the base size; paper area of one lane):")
    for (device, orientation, kind, v, pages) in table {
        let plan = SpanFixtures.plan(kind, .monday, device, orientation)
        let viewport = SpanPlan.referenceViewport(kind, deviceClass: device, orientation: orientation)
        let zoom = ZoomPolicy.bounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: viewport).min
        print(String(format: "     %@ %@ %@: %.0f × %.2f pt, zoom %.4f, V %.3f, R %d, %d pages",
                     device.rawValue, orientation.rawValue, kind.rawValue, viewport.width, viewport.height, zoom, plan.visiblePages, plan.radius, plan.windowSize))
        check(abs(plan.visiblePages - v) <= 0.006, "span window: \(device) \(orientation) \(kind) V \(plan.visiblePages) is B_DESIGN's \(v)")
        checkEqual(plan.windowSize, pages, "span window: \(device) \(orientation) \(kind) is \(pages) pages")
        checkEqual(plan.radius, (pages - 1) / 2, "span window: \(device) \(orientation) \(kind) R")
    }
    // 1.1.1 did not change these numbers: the week's and the day's overview is their base size.
    for kind in [PageKind.week, .day] {
        check(ZoomPolicy.baseSize(kind) == (kind == .week ? CGSize(width: 1400, height: 1920) : CGSize(width: 1000, height: 2400)),
              "span window: the \(kind) base size (the overview of 1.1.1's lower zoom) is the 24 hours")
    }

    // The iPhone Duo's inner screen (estimated, 1.4): the rule on B_DESIGN's V.
    for (v, pages) in [(CGFloat(1.37), 5), (2.40, 7), (1.00, 5), (1.27, 5)] {
        checkEqual(2 * SpanPlan.radius(forVisiblePages: v) + 1, pages, "span window: Duo inner V \(v) is \(pages) pages (1.4 checks it again)")
    }
    // The rule R = ⌈(V − 0.05) / 2 + 1⌉ at its edges.
    let rule: [(CGFloat, Int)] = [(0, 1), (0.05, 1), (1.0, 2), (2.05, 2), (2.06, 3), (4.05, 3), (4.0501, 4), (6.05, 4), (6.06, 5),
                                  (10.23, 7), (12.05, 7), (12.06, 8), (.nan, 1), (-3, 1)]
    for (v, r) in rule {
        checkEqual(SpanPlan.radius(forVisiblePages: v), r, "span window: R of V = \(v) is \(r)")
    }

    // The owner's devices and the other measurements need no more pages than their class's row.
    let variants: [(String, SpanDeviceClass, SpanOrientation, PageKind, CGSize)] = [
        ("iPad Air 11 portrait (R1_1_1 estimate)", .iPad11, .portrait, .week, CGSize(width: 820, height: 925)),
        ("iPad Air 11 portrait (R1_1_1 estimate)", .iPad11, .portrait, .day, CGSize(width: 820, height: 921)),
        ("iPad Air 11 landscape", .iPad11, .landscape, .week, CGSize(width: 1180, height: 565)),
        ("iPad Air 11 landscape", .iPad11, .landscape, .day, CGSize(width: 1180, height: 561)),
        ("iPad Pro 11 landscape (portrait header)", .iPad11, .landscape, .week, CGSize(width: 1210, height: 579)),
        ("iPad Pro 11 landscape (portrait header)", .iPad11, .landscape, .day, CGSize(width: 1210, height: 575)),
        ("iPad Pro 13 landscape (portrait header)", .iPad13, .landscape, .week, CGSize(width: 1376, height: 777)),
        ("iPad Pro 13 landscape (portrait header)", .iPad13, .landscape, .day, CGSize(width: 1376, height: 773)),
        ("iPad mini landscape (portrait header)", .iPadMini, .landscape, .week, CGSize(width: 1133, height: 489)),
        ("iPad mini landscape (portrait header)", .iPadMini, .landscape, .day, CGSize(width: 1133, height: 485)),
        ("iPhone 17 Pro Max portrait (measured)", .iPhone, .portrait, .week, CGSize(width: 440, height: 622)),
        ("iPhone 17 Pro Max portrait (measured)", .iPhone, .portrait, .day, CGSize(width: 440, height: 618)),
        ("iPhone 17 landscape (measured)", .iPhone, .landscape, .week, CGSize(width: 750, height: 179)),
        ("iPhone 17 landscape (measured)", .iPhone, .landscape, .day, CGSize(width: 750, height: 175)),
        ("iPhone Pro Max landscape (estimate)", .iPhone, .landscape, .week, CGSize(width: 832, height: 217)),
        ("iPhone Pro Max landscape (estimate)", .iPhone, .landscape, .day, CGSize(width: 832, height: 213)),
    ]
    for (name, device, orientation, kind, viewport) in variants {
        let v = SpanPlan.visiblePages(kind, viewport: viewport)
        let needed = SpanPlan.radius(forVisiblePages: v)
        let plan = SpanFixtures.plan(kind, .monday, device, orientation)
        print(String(format: "     variant %@ %@: V %.3f → %d pages (class row %d)", name, kind.rawValue, v, 2 * needed + 1, plan.windowSize))
        check(needed <= plan.radius, "span window: \(name) \(kind) needs \(2 * needed + 1) pages, the row has \(plan.windowSize)")
    }

    // The classes of the screens.
    let screens: [(CGFloat, CGFloat, Bool, SpanDeviceClass)] = [
        (744, 1133, true, .iPadMini), (1133, 744, true, .iPadMini), (820, 1180, true, .iPad11), (834, 1194, true, .iPad11),
        (1210, 834, true, .iPad11), (1024, 1366, true, .iPad13), (1376, 1032, true, .iPad13),
        (402, 874, false, .iPhone), (956, 440, false, .iPhone), (1032, 1376, false, .iPhone),
    ]
    for (w, h, pad, expected) in screens {
        checkEqual(SpanDeviceClass(screen: CGSize(width: w, height: h), isPad: pad), expected, "span window: a \(pad ? "pad" : "phone") of \(w) × \(h) is \(expected)")
    }
    checkEqual(SpanOrientation(screen: CGSize(width: 1180, height: 820)), .landscape, "span window: wider than tall is landscape")
    checkEqual(SpanOrientation(screen: CGSize(width: 820, height: 1180)), .portrait, "span window: taller than wide is portrait")
    checkEqual(SpanOrientation(screen: CGSize(width: 800, height: 800)), .portrait, "span window: a square is portrait")
}

// MARK: - SpanPlan: shift, fling, estimate, cap (§3.6, §3.15, §3.16)

func spanShiftAndFlingChecks() {
    let week = SpanFixtures.plan(.week)
    let dayPlan = SpanFixtures.plan(.day)
    // 11-inch portrait overview: the zoom of 834 × 955 / 951 (the measured paper area) → 696 / 396 pt.
    let weekZoom = ZoomPolicy.bounds(.week, overview: ZoomPolicy.baseSize(.week), viewport: CGSize(width: 834, height: 955)).min
    let dayZoom = ZoomPolicy.bounds(.day, overview: ZoomPolicy.baseSize(.day), viewport: CGSize(width: 834, height: 951)).min
    checkEqual(week.shiftAmount(pages: 1, zoom: weekZoom).rounded(), 696, "span shift: one week at the 11-inch portrait overview is 696 pt")
    checkEqual(dayPlan.shiftAmount(pages: 1, zoom: dayZoom).rounded(), 396, "span shift: one day at the 11-inch portrait overview is 396 pt")
    checkEqual(week.shiftAmount(pages: 1, zoom: 0.4974).rounded(), 696, "span shift: the measured week zoom 0.4974 (docs/M4C.md §3)")
    checkEqual(dayPlan.shiftAmount(pages: 1, zoom: 0.3962).rounded(), 396, "span shift: the measured day zoom 0.3962 (docs/M4C.md §3)")
    checkEqual(week.shiftAmount(pages: 3, zoom: 0.5), 2100, "span shift: 3 weeks at 0.5 is 2100 pt")
    checkEqual(week.shiftAmount(pages: -1, zoom: 0.5), -700, "span shift: back one week at 0.5 is -700 pt")
    checkEqual(dayPlan.shiftAmount(pages: 2, zoom: 1.5), 3000, "span shift: 2 days at 1.5 is 3000 pt")
    check(week.shiftAmount(pages: 1, zoom: .nan) == 0 && week.shiftAmount(pages: 1, zoom: 0) == 0 && week.shiftAmount(pages: 1, zoom: -1) == 0,
          "span shift: a zoom that is not finite or not positive gives 0")

    // The fling (P-B5 ア): 11-inch portrait week, 834 pt wide, zoom 0.4974 → a page is 696.36 pt and
    // page k is centred at offset (k + 0.5) × 696.36 − 417.
    checkEqual(SpanPlan.snapFraction, 0.06, "span fling: the snap distance is 6 % of the screen's width")
    checkEqual(SpanPlan.flingVelocity, 0.3, "span fling: a fling is 0.3 pt/ms or faster")
    let z: CGFloat = 0.4974
    let page: CGFloat = 1400 * 0.4974
    func centred(_ k: CGFloat) -> CGFloat { (k + 0.5) * page - 417 }
    func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 1e-6 }
    let flings: [(String, CGFloat, CGFloat, CGFloat?, CGFloat)] = [
        ("fast right from page 2", centred(2), 1.2, nil, centred(3)),
        ("fast left from page 2", centred(2), -1.2, nil, centred(1)),
        ("fast right from 0.3 past page 2", centred(2) + 0.3 * page, 2, nil, centred(3)),
        ("fast left from 0.3 past page 2", centred(2) + 0.3 * page, -2, nil, centred(2)),
        ("fast right at exactly 0.3 pt/ms", centred(2), 0.3, nil, centred(3)),
        ("fast right with UIKit proposing 5 pages on", centred(2), 4, centred(7), centred(3)),
        ("slow at 0.2999 pt/ms, 6 % right of page 2 (50.04 pt)", centred(2) + 50.04, 0.2999, nil, centred(2)),
        ("slow 6 % left of page 2", centred(2) - 50.04, 0, nil, centred(2)),
        ("slow 50.54 pt right of page 2 stays", centred(2) + 50.54, 0, nil, centred(2) + 50.54),
        ("slow, UIKit stops 30 pt past page 2", centred(2), 0.1, centred(2) + 30, centred(2)),
        ("slow, UIKit stops 200 pt past page 2", centred(2), 0.1, centred(2) + 200, centred(2) + 200),
        ("slow in the middle of two pages stays", centred(2) + page / 2, 0, nil, centred(2) + page / 2),
    ]
    for (name, offset, velocity, proposed, expected) in flings {
        let target = week.flingTarget(offsetX: offset, velocity: velocity, zoom: z, viewportWidth: 834, proposedX: proposed)
        check(near(target, expected), "span fling: \(name) → \(expected) (got \(target))")
    }
    // Zoomed in (2.0: a page is 2800 pt, wider than the screen): free flow, edges snap within 6 %.
    let zoomed: [(String, CGFloat, CGFloat, CGFloat?, CGFloat)] = [
        ("zoomed fast flows to UIKit's stop", 3000, 3, 5000, 5000),
        ("zoomed slow 40 pt right of page 2's left edge", 5640, 0, nil, 5600),
        ("zoomed slow 45 pt right of page 2's right edge on the screen's right", 8400 - 834 + 45, 0, nil, 8400 - 834),
        ("zoomed slow 200 pt in stays", 5800, 0, nil, 5800),
    ]
    for (name, offset, velocity, proposed, expected) in zoomed {
        let target = week.flingTarget(offsetX: offset, velocity: velocity, zoom: 2, viewportWidth: 834, proposedX: proposed)
        check(near(target, expected), "span fling: \(name) → \(expected) (got \(target))")
    }
    // The plan's own width when none is given (iPhone portrait 402 pt, zoom 0.2812: a page of 393.68 pt).
    let phone = SpanFixtures.plan(.week, .monday, .iPhone, .portrait)
    let phonePage: CGFloat = 1400 * 0.2812
    check(near(phone.flingTarget(offsetX: 2.5 * phonePage - 201, velocity: 1, zoom: 0.2812), 3.5 * phonePage - 201),
          "span fling: without a width the plan's reference width (iPhone 402 pt) is used")
    check(week.flingTarget(offsetX: 100, velocity: 1, zoom: .nan, proposedX: 150) == 150 && week.flingTarget(offsetX: 100, velocity: 1, zoom: 0) == 100,
          "span fling: a zoom that is not usable gives UIKit's stop")

    // The stroke estimate (0.25 KB a stroke, counted high) and the window's cap.
    let estimates: [(Int, Int)] = [(0, 0), (-5, 0), (1, 1), (250, 1), (251, 2), (500, 2), (501, 3), (1_000_000, 4000), (1_000_001, 4001)]
    for (bytes, strokes) in estimates {
        checkEqual(SpanPlan.estimatedStrokes(fileBytes: bytes), strokes, "span estimate: \(bytes) bytes are \(strokes) strokes at most")
    }
    check(SpanPlan.windowStrokeCap.iPad == 20_000 && SpanPlan.windowStrokeCap.iPhone == 12_000, "span cap: iPad 20,000 and iPhone 12,000 strokes a window (D18)")
    for device in SpanDeviceClass.allCases {
        checkEqual(SpanFixtures.plan(.week, .monday, device).strokeCap, device == .iPhone ? 12_000 : 20_000, "span cap: the cap of \(device)")
    }
}

// MARK: - K-10 (§6.2): the names the app makes have no "|" and no "~"

func spanK10Checks() {
    func clean(_ s: String) -> Bool { !s.contains("|") && !s.contains("~") }
    var bad: String?
    var d = DayKey(year: 2020, month: 1, day: 1)
    while d <= DayKey(year: 2030, month: 12, day: 31) {
        for kind in PageKind.allCases {
            for ws in WeekStart.allCases {
                let id = PageNavigation.pageId(kind, focus: d, weekStart: ws)
                if !clean(id) || SpanName.isVirtual(id) { bad = bad ?? id }
            }
        }
        for cell in [CellKey.day(d), .allDay(d), .yearDay(month: d.month, day: d.day)] where !clean(cell.raw) {
            bad = bad ?? cell.raw
        }
        d = d.adding(days: 1)
    }
    check(bad == nil, "K-10: PageNavigation.pageId and the day cells of 2020…2030 have no | and no ~ (\(bad ?? "none"))")
    for cell in [CellKey.grid, .extra, .memo, .allDayDay] {
        check(clean(cell.raw) && !SpanName.isPrefixed(cell.raw), "K-10: the cell \(cell.raw) has no | and no ~")
    }
    var yearBad: String?
    for m in 1...12 {
        for day in 1...31 where !clean(CellKey.yearDay(month: m, day: day).raw) {
            yearBad = yearBad ?? CellKey.yearDay(month: m, day: day).raw
        }
    }
    check(yearBad == nil, "K-10: the 372 year cells have no | and no ~")
    // Every cell the four engines make.
    let now = date(2026, 11, 11, 12)
    let layouts: [any PageLayout] = [
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now, calendar: tokyo)),
        WeekLayoutEngine.layout(WeekLayoutInput(focus: DayKey(year: 2026, month: 11, day: 11), events: [], inkBottoms: [:], now: now, calendar: tokyo, weekStart: .monday)),
        WeekLayoutEngine.layout(WeekLayoutInput(focus: DayKey(year: 2026, month: 11, day: 11), events: [], inkBottoms: [:], now: now, calendar: tokyo, weekStart: .sunday)),
        DayLayoutEngine.layout(DayLayoutInput(day: DayKey(year: 2026, month: 11, day: 11), events: [], inkBottoms: [:], now: now, calendar: tokyo)),
        YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now, calendar: tokyo)),
    ]
    for layout in layouts {
        check(clean(layout.pageId) && layout.cells.keys.allSatisfy { clean($0.raw) && !SpanName.isPrefixed($0.raw) },
              "K-10: \(layout.pageId) and its \(layout.cells.count) cells have no | and no ~")
    }
    // The ids a plan makes are PageNavigation's.
    var planBad: String?
    for kind in PageKind.allCases {
        for ws in WeekStart.allCases {
            let plan = SpanFixtures.plan(kind, ws)
            for i in stride(from: plan.index(containing: DayKey(year: 2026, month: 11, day: 11)) - 400, through: plan.index(containing: DayKey(year: 2026, month: 11, day: 11)) + 400, by: 7) {
                let id = plan.pageId(at: i)
                if !clean(id) || id != PageNavigation.pageId(kind, focus: plan.firstDay(at: i), weekStart: ws) { planBad = planBad ?? id }
            }
        }
    }
    check(planBad == nil, "K-10: SpanPlan.pageId(at:) is PageNavigation.pageId, without | and ~ (\(planBad ?? "all"))")
}
