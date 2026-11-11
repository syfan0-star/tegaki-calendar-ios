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

    /// The week pages from each first day (October 2026 in Tokyo, like main.swift's fixtures).
    static func weekPages(_ firstDays: [DayKey], weekStart: WeekStart, events: [LayoutEvent], now: Date) -> [any PageLayout] {
        firstDays.map { WeekLayoutEngine.layout(WeekLayoutInput(focus: $0, events: events, inkBottoms: [:], now: now, calendar: tokyo, weekStart: weekStart)) }
    }

    /// The day pages, with the bottom of each day's free-memo ink and the window's floor.
    static func dayPages(_ days: [DayKey], events: [LayoutEvent], now: Date, extraBottoms: [DayKey: CGFloat] = [:], floor: CGFloat = 0) -> [any PageLayout] {
        days.map { d in
            DayLayoutEngine.layout(DayLayoutInput(day: d, events: events, inkBottoms: extraBottoms[d].map { [.extra: $0] } ?? [:], now: now, calendar: tokyo, extraFloor: floor))
        }
    }

    /// A window of `pages` whose slot 0 is page `firstId` of `plan`.
    static func window(_ pages: [any PageLayout], plan: SpanPlan, session: Int = 0, viewOnly: Set<String> = []) -> SpanLayout {
        SpanLayout(pages: pages, plan: plan, firstIndex: pages.first.flatMap { plan.index(of: $0.pageId) } ?? 0, session: session, viewOnly: viewOnly)
    }

    static func october(_ d: Int) -> DayKey { DayKey(year: 2026, month: 10, day: d) }
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
    spanAlignChecks()
    spanAllDayBandChecks()
    spanOnePageChecks()
    spanWeekWindowChecks()
    spanDayWindowChecks()
    spanRoutingChecks()
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

// MARK: - SpanAlign and the engines' floors (D16, §3.2, §3.8)

func spanAlignChecks() {
    let now = october(14, 10)
    let events = [timed("t1", 13, 9, 0, 10, 30), allDay("a1", 12, 15)]
    func dayPage(_ d: Int, bottom: CGFloat?, floor: CGFloat? = nil) -> DayPageLayout {
        let ink: [CellKey: CGFloat] = bottom.map { [.extra: $0] } ?? [:]
        let day = DayKey(year: 2026, month: 10, day: d)
        if let floor {
            return DayLayoutEngine.layout(DayLayoutInput(day: day, events: events, inkBottoms: ink, now: now, calendar: tokyo, extraFloor: floor))
        }
        return DayLayoutEngine.layout(DayLayoutInput(day: day, events: events, inkBottoms: ink, now: now, calendar: tokyo))
    }

    // Left out (or 0, or not above the page's own height, or not usable) the day is today's, ==.
    for bottom in [nil, CGFloat(0), 3000, 5950, 6500] as [CGFloat?] {
        let today = dayPage(13, bottom: bottom)
        for floor in [CGFloat(0), 5000, 6000, -100, .nan, .infinity, -.infinity] {
            check(dayPage(13, bottom: bottom, floor: floor) == today, "span align: a day with ink bottom \(bottom.map { "\($0)" } ?? "none") and floor \(floor) is today's day")
        }
    }
    checkEqual(dayPage(13, bottom: nil).extra.height, 6000, "span align: today's free memo is 6,000 lu")

    // A floor above the page's own height makes only the free memo taller.
    let plain = dayPage(13, bottom: 100)
    let floored = dayPage(13, bottom: 100, floor: 7000)
    checkEqual(floored.extra, CGRect(x: 0, y: 2400, width: 1000, height: 7000), "span align: floor 7,000 → extra (0, 2400, 1000, 7000)")
    checkEqual(floored.size, CGSize(width: 1000, height: 9400), "span align: floor 7,000 → the paper is 1000 × 9400")
    checkEqual(floored.cells[.extra], CGRect(x: 0, y: 2400, width: 1000, height: 7000), "span align: the extra cell follows the floor")
    check(floored.grid == plain.grid && floored.timeline == plain.timeline && floored.memo == plain.memo && floored.cells[.grid] == plain.cells[.grid]
          && floored.timedBoxes == plain.timedBoxes && floored.dateLabels == plain.dateLabels && floored.nowLine == plain.nowLine
          && floored.allDayBand == plain.allDayBand && floored.pageId == plain.pageId && floored.isToday == plain.isToday,
          "span align: nothing but the free memo moves (K-4)")
    checkEqual(dayPage(13, bottom: 7150, floor: 7000).extra.height, 7200, "span align: the page's own 7,200 (7,150 + 50) beats floor 7,000")
    checkEqual(dayPage(13, bottom: 7150, floor: 7300).extra.height, 7300, "span align: floor 7,300 beats the page's own 7,200")
    // The floor never moves the cap (6,000 lu below 24:00 on every page, K-9).
    checkEqual(PaperGrowth.drop(center: CGPoint(x: 500, y: 2400 + 6000.5), in: floored), .beyondCap, "span align: on a floored day, 6,000.5 below 24:00 is still beyond the cap")
    checkEqual(PaperGrowth.drop(center: CGPoint(x: 500, y: 2400 + 6000), in: floored), nil, "span align: on a floored day, 6,000 below 24:00 is kept")

    // The week has no memo yet (§5): any floor gives today's week, Monday and Sunday.
    for ws in WeekStart.allCases {
        let week = WeekLayoutEngine.layout(WeekLayoutInput(focus: DayKey(year: 2026, month: 10, day: 14), events: events, inkBottoms: [.grid: 1500], now: now, calendar: tokyo, weekStart: ws))
        for floor in [CGFloat(0), 7000, .nan] {
            let w = WeekLayoutEngine.layout(WeekLayoutInput(focus: DayKey(year: 2026, month: 10, day: 14), events: events, inkBottoms: [.grid: 1500], now: now, calendar: tokyo, weekStart: ws, extraFloor: floor))
            check(w == week, "span align: a \(ws) week with floor \(floor) is today's week (no week memo before §5)")
        }
    }

    // The floors and their changes (B_DESIGN.md:288).
    checkEqual(SpanAlign.Floors.none, SpanAlign.Floors(dayExtra: 0, weekExtra: 0), "span align: no floor is 0 and 0")
    let floors = SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500)
    check(floors.floor(for: .day) == 7000 && floors.floor(for: .week) == 6500 && floors.floor(for: .month) == 0 && floors.floor(for: .year) == 0,
          "span align: the floor of each kind")
    let naturals: [(CGFloat, CGFloat)] = [(0, 6000), (5950, 6000), (5951, 6001), (6950, 7000), (.nan, 6000), (-5, 6000), (.infinity, 6000)]
    for (bottom, height) in naturals {
        checkEqual(SpanAlign.natural(inkBottom: bottom), height, "span align: the natural height of an extra with ink bottom \(bottom) is \(height)")
    }
    let rules: [(String, CGFloat, [CGFloat], SpanAlign.Change, CGFloat)] = [
        ("a shift never lowers", 7000, [6000, 6000, 6000], .shift, 7000),
        ("a shift raises", 6000, [6000, 6800], .shift, 6800),
        ("a shift to no page keeps", 6000, [], .shift, 6000),
        ("ink that grew raises", 7000, [6000, 7200], .inkGrew, 7200),
        ("ink that grew elsewhere keeps", 7000, [6000], .inkGrew, 7000),
        ("erasing lowers to the tallest", 7000, [6000, 6500], .inkShrank, 6500),
        ("erasing lowers to 6,000", 7000, [6000], .inkShrank, 6000),
        ("deciding again takes the tallest", 9000, [6000, 6100], .redecide, 6100),
        ("deciding again without pages is 0", 9000, [], .redecide, 0),
        ("a previous floor that is not finite counts as 0", .nan, [6000], .shift, 6000),
        ("a natural height that is not finite counts as 0", 0, [.infinity, 6000], .redecide, 6000),
    ]
    for (name, previous, heights, change, expected) in rules {
        checkEqual(SpanAlign.floor(previous: previous, naturals: heights, change: change), expected, "span align: \(name)")
    }
    checkEqual(SpanAlign.dayFloors(previous: SpanAlign.Floors(dayExtra: 0, weekExtra: 6500), extraInkBottoms: [0, 6950, 100], change: .redecide),
               SpanAlign.Floors(dayExtra: 7000, weekExtra: 6500), "span align: the day floor of a window from its ink bottoms (the week's is kept)")

    // A window of days through a shift and an erase: the floor stays when the deep day leaves, drops on erasing.
    var floor = SpanAlign.dayFloors(previous: .none, extraInkBottoms: [0, 6950, 0], change: .redecide).dayExtra
    checkEqual(floor, 7000, "span align: a window with a line at 6,950 lu lines up at 7,000")
    floor = SpanAlign.dayFloors(previous: SpanAlign.Floors(dayExtra: floor), extraInkBottoms: [0, 0, 0], change: .shift).dayExtra
    checkEqual(floor, 7000, "span align: the deep day left the window: the floor stays 7,000")
    floor = SpanAlign.dayFloors(previous: SpanAlign.Floors(dayExtra: floor), extraInkBottoms: [0, 120, 0], change: .inkShrank).dayExtra
    checkEqual(floor, 6000, "span align: erasing in the window brings it down to 6,000")
    let lined = [12, 13, 14].map { dayPage($0, bottom: $0 == 13 ? 6950 : 0, floor: 7000) }
    check(lined.allSatisfy { $0.extra.height == 7000 && $0.size.height == 9400 }, "span align: the three days laid out with the floor end at the same line (9,400)")
}

// MARK: - The all-day band of a run of days (§3.8)

func spanAllDayBandChecks() {
    let now = october(13, 10)
    let colW = (1400.0 - 64.0) / 7.0
    // X: Mon 10/5–Sun 10/11; C: Sat 10/10–Tue 10/13 (across the weeks); Y: Thu 10/15.
    let x = allDay("X", 5, 12)
    let c = allDay("C", 10, 14)
    let y = allDay("Y", 15, 16)
    let events = [x, c, y, timed("t", 13, 9, 0, 10, 0)]
    let twoWeeks = (5...18).map { DayKey(year: 2026, month: 10, day: $0) }

    // One page gives what week(firstDay:weekStart:…) / day(_:…) give, Monday and Sunday.
    let mondayDays = Array(twoWeeks[0..<7])
    checkEqual(AllDayBandEngine.pages(.week, days: mondayDays, events: events, now: now, calendar: tokyo),
               [AllDayBandEngine.week(firstDay: mondayDays[0], weekStart: .monday, events: events, now: now, calendar: tokyo)],
               "span band: one Monday week is week(firstDay:weekStart:)")
    let sundayDays = (4...10).map { DayKey(year: 2026, month: 10, day: $0) }
    checkEqual(AllDayBandEngine.pages(.week, days: sundayDays, events: events, now: now, calendar: tokyo),
               [AllDayBandEngine.week(firstDay: sundayDays[0], weekStart: .sunday, events: events, now: now, calendar: tokyo)],
               "span band: one Sunday week is week(firstDay:weekStart:)")
    for d in [10, 13, 15, 20] {
        let day = DayKey(year: 2026, month: 10, day: d)
        checkEqual(AllDayBandEngine.pages(.day, days: [day], events: events, now: now, calendar: tokyo),
                   [AllDayBandEngine.day(day, events: events, now: now, calendar: tokyo)], "span band: one day 10-\(d) is day(_:)")
    }
    checkEqual(AllDayBandEngine.pages(.week, days: [], events: events, now: now, calendar: tokyo), [], "span band: no days, no bands")

    // Two weeks packed together: C keeps lane 1 on both sides (week by week it would be 1, then 0).
    let perWeek = [AllDayBandEngine.week(firstDay: twoWeeks[0], weekStart: .monday, events: events, now: now, calendar: tokyo),
                   AllDayBandEngine.week(firstDay: twoWeeks[7], weekStart: .monday, events: events, now: now, calendar: tokyo)]
    check(perWeek[0].bars.first { $0.eventId == "C" }?.lane == 1 && perWeek[1].bars.first { $0.eventId == "C" }?.lane == 0,
          "span band: packed week by week, C would change lanes at the boundary (1 → 0)")
    let bands = AllDayBandEngine.pages(.week, days: twoWeeks, events: events, now: now, calendar: tokyo)
    checkEqual(bands.count, 2, "span band: 14 days are two week bands")
    if bands.count == 2 {
        let a = [
            AllDayBandBar(eventId: "X", title: "X", colorHex: "#33b679", lane: 0, startCol: 0, endCol: 6, continuesLeft: false, continuesRight: false, minX: 64 + 3, maxX: 1400 - 3),
            AllDayBandBar(eventId: "C", title: "C", colorHex: "#33b679", lane: 1, startCol: 5, endCol: 6, continuesLeft: false, continuesRight: true, minX: 64 + 5 * colW + 3, maxX: 1400),
        ]
        let b = [
            AllDayBandBar(eventId: "Y", title: "Y", colorHex: "#33b679", lane: 0, startCol: 3, endCol: 3, continuesLeft: false, continuesRight: false, minX: 64 + 3 * colW + 3, maxX: 64 + 4 * colW - 3),
            AllDayBandBar(eventId: "C", title: "C", colorHex: "#33b679", lane: 1, startCol: 0, endCol: 1, continuesLeft: true, continuesRight: false, minX: 64, maxX: 64 + 2 * colW - 3),
        ]
        func same(_ p: [AllDayBandBar], _ q: [AllDayBandBar]) -> Bool {
            p.count == q.count && zip(p, q).allSatisfy {
                $0.eventId == $1.eventId && $0.lane == $1.lane && $0.startCol == $1.startCol && $0.endCol == $1.endCol
                    && $0.continuesLeft == $1.continuesLeft && $0.continuesRight == $1.continuesRight
                    && abs($0.minX - $1.minX) < 1e-9 && abs($0.maxX - $1.maxX) < 1e-9 && $0.title == $1.title
            }
        }
        check(same(bands[0].bars, a), "span band: the week of 10-05 has X on lane 0 and C on lane 1, squared off on the right")
        check(same(bands[1].bars, b), "span band: the week of 10-12 has Y on lane 0 and C on lane 1, squared off on the left")
        check(bands[0].laneCount == 2 && bands[1].laneCount == 2, "span band: both weeks have the window's 2 lanes")
        check(bands[0].days == mondayDays && bands[1].days == Array(twoWeeks[7..<14]), "span band: each band has its week's days")
        check(bands[0].todayColumn == nil && bands[1].todayColumn == 1, "span band: today (Tue 10-13) is column 1 of the second week")
        check(bands[0].tones == AllDayBandLayout.empty(kind: .week, days: mondayDays).tones && bands[1].columnMinX == perWeek[1].columnMinX,
              "span band: each band keeps its own colours and the week's columns")
    }
    let floored = AllDayBandEngine.pages(.week, days: twoWeeks, events: events, now: now, calendar: tokyo, minimumLaneCount: 4)
    check(floored.allSatisfy { $0.laneCount == 4 }, "span band: the lane count never goes below the session's 4")
    check(AllDayBandEngine.pages(.week, days: twoWeeks, events: [], now: now, calendar: tokyo).allSatisfy { $0.laneCount == 0 && $0.bars.isEmpty },
          "span band: without events no lanes")

    // A Sunday window: the boundary is Saturday → Sunday.
    let sundayRun = (4...17).map { DayKey(year: 2026, month: 10, day: $0) }
    let sundayBands = AllDayBandEngine.pages(.week, days: sundayRun, events: events, now: now, calendar: tokyo)
    let cFirst = sundayBands.first?.bars.first { $0.eventId == "C" }
    let cSecond = sundayBands.last?.bars.first { $0.eventId == "C" }
    check(sundayBands.count == 2 && cFirst?.startCol == 6 && cFirst?.endCol == 6 && cFirst?.continuesRight == true
          && cSecond?.startCol == 0 && cSecond?.endCol == 2 && cSecond?.continuesLeft == true && cFirst?.lane == cSecond?.lane,
          "span band: Sunday weeks: C is Saturday on the first page, Sunday–Tuesday on the second, one lane")

    // Days: D1 10/12–10/13, D2 10/13, D3 10/14 over three day pages.
    let d1 = allDay("D1", 12, 14)
    let d2 = allDay("D2", 13, 14)
    let d3 = allDay("D3", 14, 15)
    let days = (12...14).map { DayKey(year: 2026, month: 10, day: $0) }
    let dayBands = AllDayBandEngine.pages(.day, days: days, events: [d1, d2, d3], now: now, calendar: tokyo)
    func lanes(_ band: AllDayBandLayout) -> [String] { band.bars.map { "\($0.eventId)@\($0.lane)\($0.continuesLeft ? "<" : "")\($0.continuesRight ? ">" : "")" } }
    check(dayBands.count == 3 && lanes(dayBands[0]) == ["D1@0>"] && lanes(dayBands[1]) == ["D1@0<", "D2@1"] && lanes(dayBands[2]) == ["D3@0"],
          "span band: three days: D1 on lane 0 across 10-12 and 10-13, D2 on lane 1, D3 back on lane 0 (\(dayBands.map(lanes)))")
    check(dayBands.allSatisfy { $0.laneCount == 2 && $0.kind == .day && $0.columnMinX == [72] }
          && dayBands.allSatisfy { $0.bars.allSatisfy { $0.minX == 72 + 4 && $0.maxX == 660 - 12 } },
          "span band: every day band has 2 lanes and the day's bar geometry")
    check(dayBands.map(\.todayColumn) == [nil, 0, nil], "span band: today's column is on 10-13 only")
}

// MARK: - SpanLayout: a window of one page is the page (§3.2)

func spanOnePageChecks() {
    let now = october(13, 10)
    let events = [timed("tb", 13, 9, 0, 10, 0), timed("tc", 13, 9, 30, 11, 0), timed("td", 16, 22, 0, 23, 30), allDay("a1", 12, 15),
                  timed("tm", 6, 7, 0, 8, 0)]
    let cases: [(String, SpanPlan, any PageLayout)] = [
        ("Monday week 10-12 (today)", SpanFixtures.plan(.week, .monday),
         WeekLayoutEngine.layout(WeekLayoutInput(focus: SpanFixtures.october(14), events: events, inkBottoms: [:], now: now, calendar: tokyo, weekStart: .monday))),
        ("Sunday week 10-04", SpanFixtures.plan(.week, .sunday),
         WeekLayoutEngine.layout(WeekLayoutInput(focus: SpanFixtures.october(6), events: events, inkBottoms: [:], now: now, calendar: tokyo, weekStart: .sunday))),
        ("day 10-13 (today, a line at 6,950)", SpanFixtures.plan(.day),
         DayLayoutEngine.layout(DayLayoutInput(day: SpanFixtures.october(13), events: events, inkBottoms: [.extra: 6950], now: now, calendar: tokyo))),
        ("day 10-16 with floor 7,500", SpanFixtures.plan(.day),
         DayLayoutEngine.layout(DayLayoutInput(day: SpanFixtures.october(16), events: events, inkBottoms: [:], now: now, calendar: tokyo, extraFloor: 7500))),
        ("month 2026-10", SpanFixtures.plan(.month),
         MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: events, inkBottoms: [CellKey.day(SpanFixtures.october(7)): 300, .memo: 900], now: now, calendar: tokyo))),
        ("year 2026", SpanFixtures.plan(.year),
         YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: events, inkBottoms: [CellKey(raw: "10-13"): 120], now: now, calendar: tokyo))),
    ]
    for (name, plan, page) in cases {
        let span = SpanLayout(pages: [page], plan: plan, firstIndex: plan.index(of: page.pageId) ?? 0)
        func pre(_ c: CellKey?) -> CellKey? { c.map { CellKey(raw: page.pageId + "|" + $0.raw) } }
        var expectedCells: [CellKey: CGRect] = [:]
        for (key, rect) in page.cells { expectedCells[CellKey(raw: page.pageId + "|" + key.raw)] = rect }
        check(span.kind == page.kind && span.size == page.size && span.cells == expectedCells && span.pageId == "span~\(plan.kind.rawValue)~0",
              "span one page: \(name): kind, size, the cells (prefixed) and the virtual id")
        check(span.dateLabels == page.dateLabels && span.allDayBars == page.allDayBars && span.timedBoxes == page.timedBoxes && span.nowLine == page.nowLine,
              "span one page: \(name): labels, bars, boxes and the now line")

        var xs: [CGFloat] = [-50, -0.001, 0, 0.5, 30, 56, 63.9, 64, 72, 100, 500, 659.9, 660, 999.9, 1000, 1000.001, 1350, 1399.999, 1400, 1400.001, 1450]
        var ys: [CGFloat] = [-10, 0, 5, 28, 100, 799, 800, 1000, 1050, 1919.9, 1920, 1920.1, 2000, 2399.9, 2400, 2500, 5000, 8399, 8400, 8400.5, 9000, 9900, 9901]
        for box in page.timedBoxes { xs.append(box.frame.midX); ys.append(box.frame.midY) }
        for label in page.dateLabels { xs.append(label.frame.midX); ys.append(label.frame.midY + 0.5) }
        var points = xs.flatMap { x in ys.map { CGPoint(x: x, y: $0) } }
        points += [CGPoint(x: CGFloat.nan, y: 10), CGPoint(x: 10, y: CGFloat.nan), CGPoint(x: CGFloat.infinity, y: 10), CGPoint(x: -CGFloat.infinity, y: -CGFloat.infinity)]
        func first(_ test: (CGPoint) -> Bool) -> String {
            points.first { !test($0) }.map { "\($0)" } ?? "none"
        }
        func mapped(_ d: PaperGrowth.Drop?, _ p: CGPoint) -> SpanDrop {
            switch d {
            case .beyondCap?: return .belowCap
            case .outsidePaper?: return .outsidePaper
            case nil: return .keep(page: page.pageId, cell: page.inkCell(forCenter: p))
            }
        }
        var bad = first { span.cell(at: $0) == pre(page.cell(at: $0)) }
        check(bad == "none", "span one page: \(name): cell(at:) is the page's, prefixed (first miss \(bad))")
        bad = first { span.inkCell(forCenter: $0) == pre(page.inkCell(forCenter: $0)) }
        check(bad == "none", "span one page: \(name): inkCell(forCenter:) is the page's, prefixed (first miss \(bad))")
        bad = first { span.hit(at: $0) == page.hit(at: $0) }
        check(bad == "none", "span one page: \(name): hit(at:) is the page's (first miss \(bad))")
        bad = first { span.dayAt(point: $0) == page.dayAt(point: $0) }
        check(bad == "none", "span one page: \(name): dayAt(point:) is the page's (first miss \(bad))")
        bad = first { span.drop(center: $0) == mapped(PaperGrowth.drop(center: $0, in: page), $0) }
        check(bad == "none", "span one page: \(name): drop(center:) is PaperGrowth.drop on the page (first miss \(bad))")
        bad = first { p in
            guard p.x.isFinite, p.y.isFinite else { return span.eventTarget(at: p) == nil }
            return span.eventTarget(at: p).map { $0.pageId == page.pageId && $0.local == p } == true
        }
        check(bad == "none", "span one page: \(name): eventTarget(at:) is (the page, the point) (first miss \(bad))")
        let badY = ys.first { y in
            span.band(atY: y) != page.band(atY: y)
        }
        check(badY == nil, "span one page: \(name): band(atY:) is the page's (first miss \(badY.map { "\($0)" } ?? "none"))")
        let bands: [PageBand] = [.grid, .extra, .memo, .row(0), .row(1), .row(13), .allDay]
        check(bands.allSatisfy { span.bandTop($0) == page.bandTop($0) }, "span one page: \(name): bandTop is the page's")

        var rects: [CGRect] = [CGRect(x: 300, y: 720, width: 100, height: 80), CGRect(x: 400, y: 800, width: -100, height: -80),
                               CGRect(x: -200, y: 100, width: 50, height: 50), CGRect(x: 1500, y: 100, width: 60, height: 50),
                               CGRect(x: 700, y: -50, width: 10, height: 5), CGRect(x: 100, y: 2300, width: 300, height: 400),
                               CGRect(x: 30, y: 300, width: 10, height: 10), CGRect(x: 600, y: 1500, width: 0, height: 0),
                               CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10)]
        rects += page.timedBoxes.map(\.frame) + page.dateLabels.map { $0.frame.insetBy(dx: 2, dy: -6) }
        check(rects.allSatisfy { span.eventRange(for: $0, now: now, calendar: tokyo) == page.eventRange(for: $0, now: now, calendar: tokyo) },
              "span one page: \(name): eventRange(for:) is the page's")
        check(rects.allSatisfy { r in
            guard let n = EventGeometry.normalized(r), let t = span.eventTarget(at: CGPoint(x: n.midX, y: n.midY)) else { return page.eventRange(for: r, now: now, calendar: tokyo) == nil }
            return t.pageId == page.pageId && page.eventRange(for: r.offsetBy(dx: t.local.x - n.midX, dy: 0), now: now, calendar: tokyo) == page.eventRange(for: r, now: now, calendar: tokyo)
        }, "span one page: \(name): eventTarget(at:) of a rect's centre leads to the page's eventRange (stage 0, §4.3)")
        var ranges: [EventRange] = []
        for d in 3...20 {
            ranges.append(.timed(SpanFixtures.october(d), startMinute: 540, endMinute: 600, calendar: tokyo))
            ranges.append(.allDay(SpanFixtures.october(d), calendar: tokyo))
        }
        ranges.append(.timed(SpanFixtures.october(13), startMinute: 1380, endMinute: 1500, calendar: tokyo))
        check(ranges.allSatisfy { span.snapRect(for: $0, calendar: tokyo) == page.snapRect(for: $0, calendar: tokyo) },
              "span one page: \(name): snapRect(for:) is the page's")
        let names = Array(page.cells.keys) + [.grid, .extra, .memo, CellKey(raw: "01-20")]
        check(names.allSatisfy { span.growsWithInk(CellKey(raw: page.pageId + "|" + $0.raw)) == page.growsWithInk($0) },
              "span one page: \(name): growsWithInk of a prefixed name is the page's for the bare name")
        check(names.allSatisfy { !span.growsWithInk($0) }, "span one page: \(name): growsWithInk of a bare name is false (it names no page)")
        check(page.cells.keys.allSatisfy { span.page(containing: CellKey(raw: page.pageId + "|" + $0.raw)) == 0 } && span.page(containing: .grid) == nil,
              "span one page: \(name): page(containing:) finds slot 0 for its cells, nothing for a bare name")
    }

    // onlyTailHeightChanged of one page is PaperGrowth's.
    let plan = SpanFixtures.plan(.day)
    let pairs: [(CGFloat, CGFloat)] = [(100, 6950), (6950, 100), (100, 100), (6950, 7300)]
    for (a, b) in pairs {
        let old = DayLayoutEngine.layout(DayLayoutInput(day: SpanFixtures.october(13), events: [], inkBottoms: [.extra: a], now: now, calendar: tokyo))
        let new = DayLayoutEngine.layout(DayLayoutInput(day: SpanFixtures.october(13), events: [], inkBottoms: [.extra: b], now: now, calendar: tokyo))
        let i = plan.index(of: old.pageId) ?? 0
        checkEqual(SpanLayout(pages: [new], plan: plan, firstIndex: i).onlyTailHeightChanged(from: SpanLayout(pages: [old], plan: plan, firstIndex: i)),
                   PaperGrowth.onlyTailHeightChanged(old: old, new: new), "span one page: onlyTailHeightChanged \(a) → \(b) is PaperGrowth's")
    }
}

// MARK: - SpanLayout: three weeks (§3.2, D15, §3.9)

func spanWeekWindowChecks() {
    let now = october(13, 10)  // Tuesday 10-13 10:00
    let colW: CGFloat = (1400 - 64) / 7
    let events = [timed("tb", 13, 9, 0, 10, 0), timed("tw", 20, 9, 0, 10, 0)]
    let mon = SpanFixtures.plan(.week, .monday)
    let pages = SpanFixtures.weekPages([5, 12, 19].map(SpanFixtures.october), weekStart: .monday, events: events, now: now)
    let span = SpanFixtures.window(pages, plan: mon, session: 3)
    checkEqual(span.firstIndex, mon.index(of: "w-2026-10-05"), "span week: slot 0 is page w-2026-10-05")
    checkEqual(span.size, CGSize(width: 4200, height: 1920), "span week: three weeks are 4200 × 1920")
    checkEqual(span.pageId, "span~week~3", "span week: the virtual id of session 3")
    checkEqual(span.cells, [CellKey(raw: "w-2026-10-05|grid"): CGRect(x: 0, y: 0, width: 1400, height: 1920),
                            CellKey(raw: "w-2026-10-12|grid"): CGRect(x: 1400, y: 0, width: 1400, height: 1920),
                            CellKey(raw: "w-2026-10-19|grid"): CGRect(x: 2800, y: 0, width: 1400, height: 1920)],
               "span week: the three grids, prefixed and moved right")

    // Left of, right of and exactly on a boundary, the gutter, outside.
    let ink: [(CGFloat, CGFloat, String, SpanDrop)] = [
        (1399.5, 900, "w-2026-10-05|grid", .keep(page: "w-2026-10-05", cell: .grid)),
        (1400, 900, "w-2026-10-12|grid", .keep(page: "w-2026-10-12", cell: .grid)),
        (1400.5, 900, "w-2026-10-12|grid", .keep(page: "w-2026-10-12", cell: .grid)),
        (1430, 900, "w-2026-10-12|grid", .keep(page: "w-2026-10-12", cell: .grid)),
        (2800, 0, "w-2026-10-19|grid", .keep(page: "w-2026-10-19", cell: .grid)),
        (4200, 1920, "w-2026-10-19|grid", .keep(page: "w-2026-10-19", cell: .grid)),
        (0, 900, "w-2026-10-05|grid", .keep(page: "w-2026-10-05", cell: .grid)),
        (-0.5, 900, "w-2026-10-05|grid", .outsidePaper),
        (4200.5, 900, "w-2026-10-19|grid", .outsidePaper),
        (1400, -1, "w-2026-10-12|grid", .outsidePaper),
        (1400, 1920.01, "w-2026-10-12|grid", .outsidePaper),
        (2000, 50_000, "w-2026-10-12|grid", .outsidePaper),
    ]
    for (x, y, cell, drop) in ink {
        checkEqual(span.inkCell(forCenter: CGPoint(x: x, y: y)).raw, cell, "span week: inkCell at (\(x), \(y)) is \(cell)")
        checkEqual(span.drop(center: CGPoint(x: x, y: y)), drop, "span week: drop at (\(x), \(y))")
    }
    checkEqual(span.drop(center: CGPoint(x: CGFloat.nan, y: 5)), .outsidePaper, "span week: a centre that is not finite is outside")

    // The day under a point: Sunday 10-11 is the first page's last column, Monday 10-12 the second's first.
    let days: [(CGFloat, CGFloat, DayKey?)] = [
        (1399, 100, SpanFixtures.october(11)), (1400, 100, nil), (1430, 100, nil), (1400 + 64, 100, SpanFixtures.october(12)),
        (1400 + 64 + colW + 1, 100, SpanFixtures.october(13)), (2800 + 64 + 6 * colW + 1, 100, SpanFixtures.october(25)),
        (4200, 100, SpanFixtures.october(25)), (4200.1, 100, nil), (500, -1, nil), (64, 100, SpanFixtures.october(5)),
    ]
    for (x, y, d) in days {
        checkEqual(span.dayAt(point: CGPoint(x: x, y: y)), d, "span week: dayAt (\(x), \(y)) is \(d.map { "\($0)" } ?? "nil")")
    }

    // The boxes, the now line and the labels moved to their page.
    let box = CGRect(x: 1400 + 64 + colW + 2, y: 721, width: colW - 8, height: 78)
    let boxes = span.timedBoxes.filter { $0.eventId == "tb" }
    check(boxes.count == 1 && boxes.allSatisfy { abs($0.frame.minX - box.minX) < 1e-9 && abs($0.frame.width - box.width) < 1e-9 && $0.frame.minY == 721 && $0.frame.height == 78 },
          "span week: Tuesday 10-13 9:00–10:00 sits at x 1400 + 64 + colW + 2")
    checkEqual(span.hit(at: CGPoint(x: box.midX, y: box.midY)), .timedBox("tb"), "span week: a tap on it hits it")
    checkEqual(span.hit(at: CGPoint(x: box.midX - 1400, y: box.midY)), nil, "span week: the same place a week earlier is empty")
    checkEqual(span.hit(at: CGPoint(x: box.midX + 1400, y: box.midY)), .timedBox("tw"), "span week: and a week later is 10-20's box")
    check(span.nowLine.map { abs($0.x0 - (1400 + 64 + colW)) < 1e-9 && abs($0.x1 - (1400 + 64 + 2 * colW)) < 1e-9 && $0.y == 800 } == true,
          "span week: the now line (Tue 10:00) is on the second page at y 800")
    check(span.dateLabels.count == 21 && span.dateLabels[7].day == SpanFixtures.october(12) && span.dateLabels[7].frame.minX == 1400 + 64,
          "span week: 21 labels, the 8th is Monday 10-12 at x 1464")

    // Events: the page under the centre, the day of the centre's page.
    let ranges: [(CGRect, EventRange?)] = [
        (CGRect(x: 1400 + 64 + colW + 10, y: 800, width: 50, height: 80), .timed(SpanFixtures.october(13), startMinute: 600, endMinute: 660, calendar: tokyo)),
        (CGRect(x: 1300, y: 800, width: 400, height: 80), .timed(SpanFixtures.october(12), startMinute: 600, endMinute: 660, calendar: tokyo)),
        (CGRect(x: 1350, y: 800, width: 100, height: 80), .timed(SpanFixtures.october(12), startMinute: 600, endMinute: 660, calendar: tokyo)),
        (CGRect(x: 1200, y: 800, width: 150, height: 80), .timed(SpanFixtures.october(11), startMinute: 600, endMinute: 660, calendar: tokyo)),
        (CGRect(x: -300, y: 800, width: 100, height: 80), .timed(SpanFixtures.october(5), startMinute: 600, endMinute: 660, calendar: tokyo)),
        (CGRect(x: 5000, y: 800, width: 100, height: 80), .timed(SpanFixtures.october(25), startMinute: 600, endMinute: 660, calendar: tokyo)),
    ]
    for (rect, range) in ranges {
        checkEqual(span.eventRange(for: rect, now: now, calendar: tokyo), range, "span week: the event of \(rect)")
    }
    checkEqual(span.snapRect(for: .timed(SpanFixtures.october(20), startMinute: 540, endMinute: 600, calendar: tokyo), calendar: tokyo).map { [$0.minX, $0.minY, $0.width, $0.height] },
               [2800 + 64 + colW, 720, colW, 80], "span week: 10-20 9:00–10:00 snaps on the third page")
    checkEqual(span.snapRect(for: .timed(SpanFixtures.october(30), startMinute: 540, endMinute: 600, calendar: tokyo), calendar: tokyo), nil,
               "span week: a day outside the window has no rect")
    let targets: [(CGPoint, String, CGPoint)] = [
        (CGPoint(x: 1400, y: 50), "w-2026-10-12", CGPoint(x: 0, y: 50)), (CGPoint(x: 1399.9, y: 50), "w-2026-10-05", CGPoint(x: 1399.9, y: 50)),
        (CGPoint(x: -5, y: 10), "w-2026-10-05", CGPoint(x: -5, y: 10)), (CGPoint(x: 5000, y: 10), "w-2026-10-19", CGPoint(x: 2200, y: 10)),
    ]
    for (point, id, local) in targets {
        check(span.eventTarget(at: point).map { $0.pageId == id && abs($0.local.x - local.x) < 1e-9 && $0.local.y == local.y } == true,
              "span week: eventTarget at \(point) is \(id) \(local)")
    }
    check(span.eventTarget(at: CGPoint(x: CGFloat.nan, y: 0)) == nil, "span week: no event target for a point that is not finite")

    // Names, bands, ids.
    check(span.page(containing: CellKey(raw: "w-2026-10-12|grid")) == 1 && span.page(containing: CellKey(raw: "w-2026-10-26|grid")) == nil
          && span.page(containing: .grid) == nil && span.slot(ofPage: "w-2026-10-19") == 2, "span week: the slot of a prefixed name and of a page id")
    check(!span.growsWithInk(CellKey(raw: "w-2026-10-12|grid")) && span.band(atY: 100) == .grid && span.bandTop(.grid) == 0 && span.band(atY: 1920) == nil,
          "span week: nothing grows on a week, one band from 0")
    let shifted = SpanFixtures.window(SpanFixtures.weekPages([12, 19, 26].map(SpanFixtures.october), weekStart: .monday, events: events, now: now), plan: mon, session: 3)
    check(shifted.pageId == span.pageId && shifted.firstIndex == span.firstIndex + 1 && SpanFixtures.window(pages, plan: mon, session: 4).pageId == "span~week~4",
          "span week: the virtual id stays when the window shifts, and is the session's")
    check(!shifted.onlyTailHeightChanged(from: span) && !span.onlyTailHeightChanged(from: span), "span week: a shift or nothing is no tail-only change")

    // A view-only page, an empty window.
    let viewOnly = SpanFixtures.window(pages, plan: mon, viewOnly: ["w-2026-10-19"])
    check(viewOnly.drop(center: CGPoint(x: 3000, y: 100)) == .viewOnly && viewOnly.drop(center: CGPoint(x: 100, y: 100)) == .keep(page: "w-2026-10-05", cell: .grid),
          "span week: a view-only page drops its new strokes as viewOnly, the others keep them")
    let empty = SpanLayout(pages: [], plan: mon, firstIndex: 0)
    check(empty.size == .zero && empty.cells.isEmpty && empty.drop(center: CGPoint(x: 1, y: 1)) == .outsidePaper && empty.inkCell(forCenter: .zero) == .grid
          && empty.cell(at: .zero) == nil && empty.eventTarget(at: .zero) == nil && empty.hit(at: .zero) == nil && empty.band(atY: 0) == nil,
          "span week: an empty window keeps nothing and answers without crashing")

    // Sunday weeks: the boundary is Saturday → Sunday (§3.9 3).
    let sun = SpanFixtures.plan(.week, .sunday)
    let sundays = SpanFixtures.window(SpanFixtures.weekPages([4, 11, 18].map(SpanFixtures.october), weekStart: .sunday, events: events, now: now), plan: sun)
    check(sundays.pages.map(\.pageId) == ["w-2026-10-04", "w-2026-10-11", "w-2026-10-18"] && sundays.firstIndex == sun.index(of: "w-2026-10-04"),
          "span week: three Sunday weeks from 10-04")
    checkEqual(sundays.inkCell(forCenter: CGPoint(x: 1400, y: 10)).raw, "w-2026-10-11|grid", "span week: Sunday weeks: x 1400 is the week of Sunday 10-11")
    checkEqual(sundays.dayAt(point: CGPoint(x: 1399, y: 100)), SpanFixtures.october(10), "span week: Sunday weeks: left of the boundary is Saturday 10-10")
    checkEqual(sundays.dayAt(point: CGPoint(x: 1400 + 64 + 1, y: 100)), SpanFixtures.october(11), "span week: Sunday weeks: right of it is Sunday 10-11")
}

// MARK: - SpanLayout: three days lined up (§3.2, D16)

func spanDayWindowChecks() {
    let now = october(13, 10)
    let plan = SpanFixtures.plan(.day)
    let days = [12, 13, 14].map(SpanFixtures.october)
    let deep: [DayKey: CGFloat] = [SpanFixtures.october(13): 6950]
    let floor = SpanAlign.dayFloors(previous: .none, extraInkBottoms: days.map { deep[$0] ?? 0 }, change: .redecide)
    let pages = SpanFixtures.dayPages(days, events: [], now: now, extraBottoms: deep, floor: floor.dayExtra)
    let span = SpanLayout(pages: pages, plan: plan, firstIndex: plan.index(of: "d-2026-10-12") ?? 0, floors: floor)
    checkEqual(span.floors.dayExtra, 7000, "span day: the window keeps its floor 7,000")
    checkEqual(span.size, CGSize(width: 3000, height: 9400), "span day: three days lined up at 2400 + 7000")
    check(span.cells[CellKey(raw: "d-2026-10-14|extra")] == CGRect(x: 2000, y: 2400, width: 1000, height: 7000)
          && span.cells[CellKey(raw: "d-2026-10-12|grid")] == CGRect(x: 0, y: 0, width: 1000, height: 2400) && span.cells.count == 6,
          "span day: six cells, every free memo 7,000 tall")
    let ink: [(CGFloat, CGFloat, String, SpanDrop)] = [
        (999.9, 2399.9, "d-2026-10-12|grid", .keep(page: "d-2026-10-12", cell: .grid)),
        (1000, 2400, "d-2026-10-13|extra", .keep(page: "d-2026-10-13", cell: .extra)),
        (1030, 500, "d-2026-10-13|grid", .keep(page: "d-2026-10-13", cell: .grid)),
        (1500, 8400, "d-2026-10-13|extra", .keep(page: "d-2026-10-13", cell: .extra)),
        (1500, 8400.5, "d-2026-10-13|extra", .belowCap),
        (2500, 9400.5, "d-2026-10-14|extra", .belowCap),
        (500, 9000, "d-2026-10-12|extra", .belowCap),
        (3000, 100, "d-2026-10-14|grid", .keep(page: "d-2026-10-14", cell: .grid)),
        (3000.1, 100, "d-2026-10-14|grid", .outsidePaper),
        (-1, 3000, "d-2026-10-12|extra", .outsidePaper),
        (1500, -0.1, "d-2026-10-13|grid", .outsidePaper),
    ]
    for (x, y, cell, drop) in ink {
        checkEqual(span.inkCell(forCenter: CGPoint(x: x, y: y)).raw, cell, "span day: inkCell at (\(x), \(y)) is \(cell)")
        checkEqual(span.drop(center: CGPoint(x: x, y: y)), drop, "span day: drop at (\(x), \(y))")
    }
    check(span.growsWithInk(CellKey(raw: "d-2026-10-13|extra")) && !span.growsWithInk(CellKey(raw: "d-2026-10-13|grid"))
          && !span.growsWithInk(.extra) && !span.growsWithInk(CellKey(raw: "d-2026-10-20|extra")),
          "span day: the prefixed free memo grows, its grid does not, a bare or foreign name does not")
    checkEqual(span.dayAt(point: CGPoint(x: 1500, y: 100)), nil, "span day: a double tap on a day page does nothing")
    checkEqual(span.eventRange(for: CGRect(x: 1100, y: 900, width: 300, height: 100), now: now, calendar: tokyo),
               .timed(SpanFixtures.october(13), startMinute: 540, endMinute: 600, calendar: tokyo), "span day: a rect on the second page is 10-13 9:00–10:00")
    checkEqual(span.eventRange(for: CGRect(x: 900, y: 900, width: 300, height: 100), now: now, calendar: tokyo),
               .timed(SpanFixtures.october(13), startMinute: 540, endMinute: 600, calendar: tokyo), "span day: a rect across the boundary goes by its centre (x 1050 → 10-13)")
    checkEqual(span.band(atY: 3000), .extra, "span day: the free memo band")
    checkEqual(span.bandTop(.extra), 2400, "span day: the free memo starts at 2400")

    // onlyTailHeightChanged, per page.
    func window(_ bottoms: [DayKey: CGFloat], floor: CGFloat = 0, days: [DayKey] = days, events: [LayoutEvent] = []) -> SpanLayout {
        let p = SpanFixtures.dayPages(days, events: events, now: now, extraBottoms: bottoms, floor: floor)
        return SpanLayout(pages: p, plan: plan, firstIndex: plan.index(of: p[0].pageId) ?? 0)
    }
    let old = window([SpanFixtures.october(13): 100])
    check(window(deep).onlyTailHeightChanged(from: old), "span day: one day's free memo grew: tail only")
    check(window(deep, floor: 7000).onlyTailHeightChanged(from: old), "span day: every free memo grew to the floor: tail only")
    check(old.onlyTailHeightChanged(from: window(deep, floor: 7000)), "span day: every free memo shrank back: tail only")
    check(!window([SpanFixtures.october(13): 100]).onlyTailHeightChanged(from: old), "span day: nothing changed: false")
    check(!window(deep, days: [13, 14, 15].map(SpanFixtures.october)).onlyTailHeightChanged(from: old), "span day: a shifted window: false")
    check(!window([SpanFixtures.october(13): 100], events: [timed("x", 13, 9, 0, 10, 0)]).onlyTailHeightChanged(from: old),
          "span day: only the events changed (no cell moved): false")
}

// MARK: - SpanLayout: every question goes to the page under the point (random points)

func spanRoutingChecks() {
    let now = october(13, 10)
    let events = [timed("tb", 13, 9, 0, 10, 0), timed("tc", 13, 9, 30, 11, 0), timed("td", 19, 22, 0, 23, 30), timed("te", 14, 3, 0, 5, 0)]
    let windows: [(String, SpanLayout, CGFloat)] = [
        ("Monday weeks", SpanFixtures.window(SpanFixtures.weekPages([DayKey(year: 2026, month: 9, day: 28)] + [5, 12, 19, 26].map(SpanFixtures.october),
                                                                    weekStart: .monday, events: events, now: now), plan: SpanFixtures.plan(.week, .monday)), 1400),
        ("Sunday weeks", SpanFixtures.window(SpanFixtures.weekPages([4, 11, 18].map(SpanFixtures.october), weekStart: .sunday, events: events, now: now),
                                             plan: SpanFixtures.plan(.week, .sunday)), 1400),
        ("days", SpanFixtures.window(SpanFixtures.dayPages((10...16).map(SpanFixtures.october), events: events, now: now,
                                                           extraBottoms: [SpanFixtures.october(14): 6990], floor: 7040), plan: SpanFixtures.plan(.day)), 1000),
    ]
    var rng = Rng(seed: 0x5BA1_13)
    for (name, span, w) in windows {
        let n = span.pages.count
        var bad: String?
        var kept = 0
        for i in 0..<3000 {
            var x = CGFloat(rng.double()) * (CGFloat(n) * w + 400) - 200
            let y = CGFloat(rng.double()) * (span.size.height + 600) - 300
            if i % 10 == 0 { x = CGFloat(rng.int(n + 1)) * w }        // exactly on a boundary
            let p = CGPoint(x: x, y: y)
            // The slot worked out apart: ⌊x ÷ W⌋, kept on the band.
            let slot = min(max(0, Int((x / w).rounded(.down))), n - 1)
            let page = span.pages[slot]
            let local = CGPoint(x: x - CGFloat(slot) * w, y: y)
            func pre(_ c: CellKey?) -> CellKey? { c.map { CellKey(raw: page.pageId + "|" + $0.raw) } }
            if span.inkCell(forCenter: p) != pre(page.inkCell(forCenter: local)) { bad = bad ?? "inkCell \(p)" }
            if span.cell(at: p) != pre(page.cell(at: local)) { bad = bad ?? "cell \(p)" }
            if span.hit(at: p) != page.hit(at: local) { bad = bad ?? "hit \(p)" }
            if span.dayAt(point: p) != page.dayAt(point: local) { bad = bad ?? "dayAt \(p)" }
            let r = CGRect(x: x - 40, y: y - 30, width: 80, height: 60)
            if span.eventRange(for: r, now: now, calendar: tokyo) != page.eventRange(for: r.offsetBy(dx: -CGFloat(slot) * w, dy: 0), now: now, calendar: tokyo) {
                bad = bad ?? "eventRange \(r)"
            }
            switch span.drop(center: p) {
            case let .keep(id, cell):
                kept += 1
                if id != page.pageId || span.inkCell(forCenter: p).raw != id + "|" + cell.raw || x < 0 || x > CGFloat(n) * w { bad = bad ?? "keep \(p)" }
            case .outsidePaper:
                if x >= 0 && x <= CGFloat(n) * w && PaperGrowth.drop(center: local, in: page) != .outsidePaper { bad = bad ?? "outside \(p)" }
            case .belowCap:
                if PaperGrowth.drop(center: local, in: page) != .beyondCap { bad = bad ?? "belowCap \(p)" }
            case .viewOnly:
                bad = bad ?? "viewOnly \(p)"
            }
        }
        check(bad == nil && kept > 1000, "span routing: \(name): 3,000 random points go to the page under them, drop and inkCell agree (\(kept) kept; first miss \(bad ?? "none"))")
    }
}
