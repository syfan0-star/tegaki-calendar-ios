// KitChecks: the iPhone Duo's span plans, 1.4 (docs/M7D_CONTRACT.md §4.6, §4.7, §6; section "duo (1.4)"), and the mode
// `--span-state` (§3.3, gate 3 (b)). main.swift calls `runSpanStateIfAsked()` before every check and `runDuoChecks()` right
// after `runOverviewCapChecks()`; it uses main.swift's `section`, `check`, `checkEqual`, `passed` and `failures`.
//
// THE OUTER SCREEN MEASURED, THE INNER ONE ESTIMATED. Apple has not published the Duo's screens in points. CI measured the
// outer screen (1.4 D1d, docs/M7D.md): duo.yml's duo-shots, run 44696154794 (commit f9bb459, Xcode 27.2 27B52, the iPhone
// Duo on iOS 27.2 24B91016s), the last `duo measure:` line of each photo and orientation (§4.2): the window 466 × 678 and
// 678 × 466, the safe area (top, left, bottom, right) 0, 0, 34, 84 in portrait and 0, 84, 34, 0 in landscape (the system's
// side strip), scale 3, two header rows in both orientations (the column 382 or 594 pt is under the header's 600), and the
// paper area `paper=` (the screen's `toolbar: paperArea=`: the all-day band of the photo's own events already taken off, so
// the week's band there is taller than one lane and its paper shorter than the day's). The inner screen could not be opened
// on CI (path 3, §4.2): its paper areas stay the estimates of docs/m7d/CODE_SURVEY.md §3.2 (docs/m7d/duo_span_calc.py: the
// screen 669 × 951 or 626 × 890 less a header of one row (portrait 255–334 pt, landscape 197–223 pt) and the one-lane band;
// the day 4 pt below the week), and every one of its rows says "(estimate)".
// 1.3's estimated Duo rows (SpanChecks.swift, "Duo inner V … (1.4 checks it again)") stay in SpanChecks as 1.3's checks
// (TESTS_1_3 keeps that file byte for byte); the Duo's rows of 1.4, measured and estimated, are here.
//
// Each row: the Duo is `.iPhone` on both screens (`SpanDeviceClass(screen:isPad: false)`), the plan's orientation is the
// screen's, and its `overviewCap` is `WindowClass.capsOverview(windowSize:)` of the screen (the window fills it): the outer
// screen caps, the inner one (a wide window, §4.7) does not. The expectations are literals worked out by hand with a separate
// calculation that re-implements ZoomPolicy's and SpanPlan's rules for the week and the day (as 1.3's PLAN_PB6 rows were),
// never read back from the code under test: V (±0.006), R of that V, the plan's R, the window SpanSession.windowRadius builds
// (the larger R; its stroke cap aside), maxVisiblePages, the lowest zoom (±0.000001) and the hours on screen there (±0.001).
// The measured rows' numbers were worked out that way too and agree with `KitChecks --span-state` and with V, R and the cap
// of the measure lines themselves, which `measuredLines` (below) writes out as CI printed them.
import Foundation
import CoreGraphics
import Layout

/// One Duo paper area (measured or estimated, as its name says) and what its plan gives.
private struct DuoRow {
    let name: String
    /// The screen (pt), which the window fills.
    let screen: CGSize
    let landscape: Bool
    let kind: PageKind
    /// The paper area (pt).
    let area: CGSize
    /// `WindowClass.capsOverview` of the screen.
    let caps: Bool
    let v: CGFloat
    let r: Int
    let planR: Int
    let pages: Int
    let maxPages: CGFloat?
    let minZoom: CGFloat
    let hours: CGFloat
}

private func row(_ name: String, _ sw: CGFloat, _ sh: CGFloat, _ kind: PageKind, _ w: CGFloat, _ h: CGFloat, caps: Bool,
                 v: CGFloat, r: Int, planR: Int, pages: Int, maxPages: CGFloat?, minZoom: CGFloat, hours: CGFloat) -> DuoRow {
    DuoRow(name: name, screen: CGSize(width: sw, height: sh), landscape: sw > sh, kind: kind, area: CGSize(width: w, height: h),
           caps: caps, v: v, r: r, planR: planR, pages: pages, maxPages: maxPages, minZoom: minZoom, hours: hours)
}

/// The rows (the inner screen's estimated, the outer one's measured; see the head of the file). Inner portrait: the width
/// binds, so V is the area's shape and every hour fits; the day's V over 2.05 widens its window from the row's 5 to 7. Inner
/// landscape: no cap (the plan is the iPhone's landscape row of P-B6 ア, R 4 / 7: 9 weeks, 15 days), every hour fits. Outer
/// portrait (measured): the week's paper 382 × 343 is wider than tall, so the cap (3) is there but below the lowest zoom
/// (382 ÷ 4200 = 0.0910 < 343 ÷ 1920 = 0.1786); the day's 382 × 402 is taller than wide, so it has none; every hour fits; the
/// day's V 2.28 widens its window to 7. Outer landscape (measured): the cap binds (V 3 / 5, windows 7 / 9) and the lowest
/// zoom shows part of the day: 12.46 hours of the week (594 ÷ 4200 on a 141 pt paper) and 15.99 of the day (594 ÷ 5000 on
/// 190 pt).
private let duoRows: [DuoRow] = [
    // Inner screen A, 669 × 951 portrait (header 334 or 255 pt).
    row("inner A portrait (estimate)", 669, 951, .week, 669, 617, caps: false, v: 1.49, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.321354, hours: 24),
    row("inner A portrait (estimate)", 669, 951, .day, 669, 613, caps: false, v: 2.62, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.255417, hours: 24),
    row("inner A portrait (estimate)", 669, 951, .week, 669, 696, caps: false, v: 1.32, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.362500, hours: 24),
    row("inner A portrait (estimate)", 669, 951, .day, 669, 692, caps: false, v: 2.32, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.288333, hours: 24),
    // Inner screen B, 626 × 890 portrait.
    row("inner B portrait (estimate)", 626, 890, .week, 626, 556, caps: false, v: 1.54, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.289583, hours: 24),
    row("inner B portrait (estimate)", 626, 890, .day, 626, 552, caps: false, v: 2.72, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.230000, hours: 24),
    row("inner B portrait (estimate)", 626, 890, .week, 626, 635, caps: false, v: 1.35, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.330729, hours: 24),
    row("inner B portrait (estimate)", 626, 890, .day, 626, 631, caps: false, v: 2.38, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.262917, hours: 24),
    // Inner screen A, 951 × 669 landscape (header 223 or 197 pt).
    row("inner A landscape (estimate)", 951, 669, .week, 951, 446, caps: false, v: 2.92, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.232292, hours: 24),
    row("inner A landscape (estimate)", 951, 669, .day, 951, 442, caps: false, v: 5.16, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.184167, hours: 24),
    row("inner A landscape (estimate)", 951, 669, .week, 951, 472, caps: false, v: 2.76, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.245833, hours: 24),
    row("inner A landscape (estimate)", 951, 669, .day, 951, 468, caps: false, v: 4.88, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.195000, hours: 24),
    // Inner screen B, 890 × 626 landscape.
    row("inner B landscape (estimate)", 890, 626, .week, 890, 403, caps: false, v: 3.03, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.209896, hours: 24),
    row("inner B landscape (estimate)", 890, 626, .day, 890, 399, caps: false, v: 5.35, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.166250, hours: 24),
    row("inner B landscape (estimate)", 890, 626, .week, 890, 429, caps: false, v: 2.85, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.223438, hours: 24),
    row("inner B landscape (estimate)", 890, 626, .day, 890, 425, caps: false, v: 5.03, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.177083, hours: 24),
    // The inner landscape areas under the all-day band at its 35 % cap: the one-lane band at the overview is 3 + 18 + 4 = 25 pt,
    // so the band-and-paper area is the one-lane paper + 25 and the paper keeps that − ⌊0.35 × that⌋ (AllDayBandMetrics). No
    // cap all the same: the band never changes the answer (§4.7, C12).
    row("inner A landscape, band at 35 % (estimate)", 951, 669, .week, 951, 307, caps: false, v: 4.25, r: 4, planR: 4, pages: 9, maxPages: nil, minZoom: 0.159896, hours: 24),
    row("inner A landscape, band at 35 % (estimate)", 951, 669, .day, 951, 304, caps: false, v: 7.51, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.126667, hours: 24),
    row("inner A landscape, band at 35 % (estimate)", 951, 669, .week, 951, 324, caps: false, v: 4.03, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.168750, hours: 24),
    row("inner A landscape, band at 35 % (estimate)", 951, 669, .day, 951, 321, caps: false, v: 7.11, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.133750, hours: 24),
    row("inner B landscape, band at 35 % (estimate)", 890, 626, .week, 890, 279, caps: false, v: 4.37, r: 4, planR: 4, pages: 9, maxPages: nil, minZoom: 0.145313, hours: 24),
    row("inner B landscape, band at 35 % (estimate)", 890, 626, .day, 890, 276, caps: false, v: 7.74, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.115000, hours: 24),
    row("inner B landscape, band at 35 % (estimate)", 890, 626, .week, 890, 296, caps: false, v: 4.12, r: 4, planR: 4, pages: 9, maxPages: nil, minZoom: 0.154167, hours: 24),
    row("inner B landscape, band at 35 % (estimate)", 890, 626, .day, 890, 293, caps: false, v: 7.29, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.122083, hours: 24),
    // The outer screen, 466 × 678 portrait, measured (run 44696154794): the paper 382 pt wide (the 84 pt side strip off
    // the right), two header rows.
    row("outer portrait (measured)", 466, 678, .week, 382, 343, caps: true, v: 1.527, r: 2, planR: 2, pages: 5, maxPages: 3, minZoom: 0.178646, hours: 24),
    row("outer portrait (measured)", 466, 678, .day, 382, 402, caps: true, v: 2.281, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.167500, hours: 24),
    // The outer screen, 678 × 466 landscape, measured: the paper 594 pt wide (the 84 pt strip off the left), two header rows
    // (594 is under 600, so the estimates' one-row header and their full width of 678 do not happen).
    row("outer landscape (measured)", 678, 466, .week, 594, 141, caps: true, v: 3.000, r: 3, planR: 3, pages: 7, maxPages: 3, minZoom: 0.141429, hours: 12.462),
    row("outer landscape (measured)", 678, 466, .day, 594, 190, caps: true, v: 5.000, r: 4, planR: 4, pages: 9, maxPages: 5, minZoom: 0.118800, hours: 15.993),
]

/// One `duo measure:` line of duo-shots' run 44696154794 as CI printed it (§4.2; the last line of each photo and
/// orientation, and the iPhone 17's first launch beside them): the window, the kind, the paper area and what the line read of
/// the window plan through the Kit: its class and orientation, the cap asked (`cap=on`), V to three decimals, R of that V,
/// the cap of the paper area (`maxPages=`), whether it binds (`capped=`) and `wide=`. The month and the year are one-page
/// paths (no window is built of them); their lines are the plan the joined path would use, kept here as CI printed them.
private struct MeasuredLine {
    let photo: String
    let window: CGSize
    let kind: PageKind
    let paper: CGSize
    let orientation: SpanOrientation
    let capOn: Bool
    let v: String
    let r: Int
    let maxPages: CGFloat?
    let capped: Bool
    let wide: Bool
}

private func printed(_ photo: String, _ ww: CGFloat, _ wh: CGFloat, _ kind: PageKind, _ pw: CGFloat, _ ph: CGFloat,
                     _ orientation: SpanOrientation, cap: Bool, v: String, r: Int, maxPages: CGFloat?, capped: Bool,
                     wide: Bool) -> MeasuredLine {
    MeasuredLine(photo: photo, window: CGSize(width: ww, height: wh), kind: kind, paper: CGSize(width: pw, height: ph),
                 orientation: orientation, capOn: cap, v: v, r: r, maxPages: maxPages, capped: capped, wide: wide)
}

/// measure.txt of run 44696154794 (the artifact duo-shots; shot-checks.txt has the same values by photo).
private let measuredLines: [MeasuredLine] = [
    printed("iphone-portrait-week-first", 402, 874, .week, 402, 477, .portrait, cap: true, v: "1.156", r: 2, maxPages: nil, capped: false, wide: false),
    printed("outer-portrait-week-pencil", 466, 678, .week, 382, 343, .portrait, cap: true, v: "1.527", r: 2, maxPages: 3, capped: false, wide: false),
    printed("outer-portrait-day-pencil", 466, 678, .day, 382, 402, .portrait, cap: true, v: "2.281", r: 3, maxPages: nil, capped: false, wide: false),
    printed("outer-portrait-month-pencil", 466, 678, .month, 382, 456.67, .portrait, cap: true, v: "1.000", r: 2, maxPages: nil, capped: false, wide: false),
    printed("outer-portrait-year-pencil", 466, 678, .year, 382, 435, .portrait, cap: true, v: "1.167", r: 2, maxPages: nil, capped: false, wide: false),
    printed("outer-landscape-week-pencil", 678, 466, .week, 594, 141, .landscape, cap: true, v: "3.000", r: 3, maxPages: 3, capped: true, wide: false),
    printed("outer-landscape-day-pencil", 678, 466, .day, 594, 190, .landscape, cap: true, v: "5.000", r: 4, maxPages: 5, capped: true, wide: false),
    printed("outer-landscape-month-pencil", 678, 466, .month, 594, 244.67, .landscape, cap: true, v: "1.821", r: 2, maxPages: nil, capped: false, wide: false),
    printed("outer-landscape-year-pencil", 678, 466, .year, 594, 223, .landscape, cap: true, v: "3.000", r: 3, maxPages: 3, capped: true, wide: false),
]

/// The lu of one hour of the 24-hour grid: week 1920 ÷ 24, day 2400 ÷ 24.
private func luPerHour(_ kind: PageKind) -> CGFloat { kind == .day ? 100 : 80 }

func runDuoChecks() {
    section("duo (1.4)")
    let start = passed + failures.count
    print("   the Duo's outer paper areas are MEASURED (duo-shots run 44696154794); the inner ones are ESTIMATES (path 3, §4.2):")
    for row in duoRows {
        let label = "duo: \(row.name) \(row.kind) \(Int(row.area.width)) × \(Int(row.area.height))"
        let deviceClass = SpanDeviceClass(screen: row.screen, isPad: false)
        checkEqual(deviceClass, .iPhone, "\(label): the Duo is .iPhone")
        let orientation = SpanOrientation(screen: row.screen)
        checkEqual(orientation, row.landscape ? .landscape : .portrait, "\(label): the plan's orientation is the screen's")
        let caps = WindowClass.capsOverview(windowSize: row.screen)
        checkEqual(caps, row.caps, "\(label): the window \(row.caps ? "caps" : "does not cap") the overview")
        let plan = SpanPlan(kind: row.kind, weekStart: .monday, deviceClass: deviceClass, orientation: orientation, overviewCap: caps)
        let v = plan.visiblePages(viewport: row.area)
        check(abs(v - row.v) <= 0.006, "\(label): V \(v) is \(row.v)")
        let r = SpanPlan.radius(forVisiblePages: v)
        checkEqual(r, row.r, "\(label): R of V is \(row.r)")
        checkEqual(plan.radius, row.planR, "\(label): the plan's R is \(row.planR)")
        checkEqual(2 * max(plan.radius, r) + 1, row.pages, "\(label): the window is \(row.pages) pages")
        checkEqual(plan.maxVisiblePages(viewport: row.area), row.maxPages, "\(label): the cap is \(row.maxPages.map { "\($0)" } ?? "none")")
        let bounds = plan.zoomBounds(overview: ZoomPolicy.baseSize(row.kind), viewport: row.area)
        check(abs(bounds.min - row.minZoom) <= 0.000001, "\(label): the lowest zoom \(bounds.min) is \(row.minZoom)")
        let hours = min(24, row.area.height / bounds.min / luPerHour(row.kind))
        check(abs(hours - row.hours) <= 0.001, "\(label): \(hours) hours on screen at the lowest zoom, \(row.hours) by hand")
        print(String(format: "     %@ %@ %.0f × %.0f: cap %@, V %.3f, R %d (row %d), %d pages, lowest zoom %.6f, %.2f h",
                     row.name, row.kind.rawValue, row.area.width, row.area.height, caps ? "on" : "off", v, r, plan.radius,
                     2 * max(plan.radius, r) + 1, bounds.min, hours))
    }

    // §4.7: a wide window's plan has no cap, so the inner landscape's lowest zoom is the plain one (1.3's P-B6 ア: the height
    // ÷ 1920 or 2400 where that is below the width ÷ 1400 or 1000) at one lane and with the band at its 35 % cap alike. With
    // 1.3's rule (overviewCap true on every window) the same areas would cap or not by the band's lanes (C12). Both lowest
    // zooms are worked out by hand (1.3's: the cap = width ÷ (3 × 1400 or 5 × 1000) where it is above the plain one).
    let innerA = CGSize(width: 951, height: 669)
    let innerB = CGSize(width: 890, height: 626)
    // (name, screen, kind, paper area, 1.4's lowest zoom, the lowest zoom with 1.3's cap)
    let border: [(String, CGSize, PageKind, CGSize, CGFloat, CGFloat)] = [
        ("inner A landscape one lane (estimate)", innerA, .week, CGSize(width: 951, height: 446), 0.232292, 0.232292),
        ("inner A landscape one lane (estimate)", innerA, .day, CGSize(width: 951, height: 442), 0.184167, 0.190200),
        ("inner A landscape one lane (estimate)", innerA, .week, CGSize(width: 951, height: 472), 0.245833, 0.245833),
        ("inner A landscape one lane (estimate)", innerA, .day, CGSize(width: 951, height: 468), 0.195000, 0.195000),
        ("inner A landscape band at 35 % (estimate)", innerA, .week, CGSize(width: 951, height: 307), 0.159896, 0.226429),
        ("inner A landscape band at 35 % (estimate)", innerA, .day, CGSize(width: 951, height: 304), 0.126667, 0.190200),
        ("inner B landscape one lane (estimate)", innerB, .week, CGSize(width: 890, height: 403), 0.209896, 0.211905),
        ("inner B landscape one lane (estimate)", innerB, .week, CGSize(width: 890, height: 429), 0.223438, 0.223438),
        ("inner B landscape band at 35 % (estimate)", innerB, .week, CGSize(width: 890, height: 279), 0.145313, 0.211905),
        ("inner B landscape band at 35 % (estimate)", innerB, .day, CGSize(width: 890, height: 276), 0.115000, 0.178000),
    ]
    for (name, screen, kind, area, lowest14, capped13) in border {
        let label = "duo: \(name) \(kind) \(Int(area.width)) × \(Int(area.height))"
        let wide = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape,
                            overviewCap: WindowClass.capsOverview(windowSize: screen))
        check(abs(wide.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area).min - lowest14) <= 0.000001,
              "\(label): 1.4's lowest zoom is the plain \(lowest14) (no cap)")
        let rule13 = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
        check(abs(rule13.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area).min - capped13) <= 0.000001,
              "\(label): with 1.3's cap the lowest zoom would be \(capped13)")
    }
    // The border C12 named: with 1.3's cap the inner A landscape week is uncapped at one lane (the plain 0.232292) and capped
    // with the band at 35 % (0.226429, where the plain one is 0.159896); 1.4's wide window gives the plain one at both (above).
    let week13 = SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
    let oneLane13 = week13.zoomBounds(overview: ZoomPolicy.baseSize(.week), viewport: CGSize(width: 951, height: 446)).min
    let tallBand13 = week13.zoomBounds(overview: ZoomPolicy.baseSize(.week), viewport: CGSize(width: 951, height: 307)).min
    check(abs(oneLane13 - 0.232292) <= 0.000001 && abs(tallBand13 - 0.226429) <= 0.000001,
          "duo: 1.3's cap would flip the inner landscape week with the band's lanes (C12: \(oneLane13) uncapped, \(tallBand13) capped); 1.4's wide window never caps")

    // The outer landscape (measured) caps as today's iPhone in landscape does: the opening zoom is the cap too (594 ÷
    // (3 × 1400) and 594 ÷ (5 × 1000), above the plain 141 ÷ 1920 and 190 ÷ 2400), and fit-to-width stays the width ÷ 1400 or
    // 1000.
    let outer: [(PageKind, CGSize, CGFloat, CGFloat)] = [
        (.week, CGSize(width: 594, height: 141), 0.141429, 0.424286),
        (.day, CGSize(width: 594, height: 190), 0.118800, 0.594000),
    ]
    for (kind, area, open, fit) in outer {
        let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape,
                            overviewCap: WindowClass.capsOverview(windowSize: CGSize(width: 678, height: 466)))
        let b = plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area)
        check(abs(b.open - open) <= 0.000001, "duo: outer landscape (measured) \(kind) opens at its capped lowest zoom \(open)")
        check(abs(b.fit - fit) <= 0.000001, "duo: outer landscape (measured) \(kind) fit-to-width stays \(fit)")
    }

    // §4.2: the measure lines as CI printed them (run 44696154794). The Kit gives the same plan (the screen's class and
    // orientation, the cap of a window that is not wide), V to three decimals, R, the paper area's cap, whether it binds
    // (`capped=`: the plain V above the cap, as `ScreenshotMode.measureLine` writes it) and `wide=` — a change of
    // SpanPlan's or WindowClass's rules shows here before the next duo-shots.
    print("   the measure lines of duo-shots run 44696154794:")
    for m in measuredLines {
        let paper = String(format: "%.2fx%.2f", Double(m.paper.width), Double(m.paper.height))
        let label = "duo: measured \(m.photo) \(m.kind) \(paper)"
        let deviceClass = SpanDeviceClass(screen: m.window, isPad: false)
        let orientation = SpanOrientation(screen: m.window)
        let caps = WindowClass.capsOverview(windowSize: m.window)
        checkEqual(deviceClass, .iPhone, "\(label): plan=iPhone")
        checkEqual(orientation, m.orientation, "\(label): plan=…,\(m.orientation.rawValue)")
        checkEqual(caps, m.capOn, "\(label): cap=\(m.capOn ? "on" : "off")")
        let plan = SpanPlan(kind: m.kind, weekStart: .monday, deviceClass: deviceClass, orientation: orientation, overviewCap: caps)
        let v = plan.visiblePages(viewport: m.paper)
        let vText = String(format: "%.3f", Double(v))
        checkEqual(vText, m.v, "\(label): V=\(m.v)")
        let r = SpanPlan.radius(forVisiblePages: v)
        checkEqual(r, m.r, "\(label): R=\(m.r)")
        let cap = plan.maxVisiblePages(viewport: m.paper)
        let capText = cap.map { "\(Int($0))" } ?? "nil"
        checkEqual(cap, m.maxPages, "\(label): maxPages=\(m.maxPages.map { "\(Int($0))" } ?? "nil")")
        let binds = cap.map { SpanPlan.visiblePages(m.kind, viewport: m.paper) > $0 } ?? false
        checkEqual(binds, m.capped, "\(label): capped=\(m.capped)")
        checkEqual(WindowClass.isWide(m.window), m.wide, "\(label): wide=\(m.wide)")
        print("     \(m.photo): \(m.kind.rawValue) paper \(paper), V \(vText), R \(r), cap \(capText), capped \(binds)")
    }
    print("   \(passed + failures.count - start) checks in this section")
}

// MARK: - --span-state <kind> <class> <orientation> <w>x<h> [cap|nocap] (§3.3, gate 3 (b); not counted)
//
// Prints what the window plan of a paper area gives, so CI's `toolbar: paperArea=` of a new SDK can be checked against the
// `span cap:` and state lines: the zoom limits (`SpanPlan.zoomBounds` with the base size as the overview: the week's and the
// day's overview is their base size; the month's and the year's of an empty page), V, the cap, R of V, the plan's R and the
// pages of the window SpanSession.windowRadius builds (its stroke cap aside). <kind> month|week|day|year, <class>
// iPhone|iPadMini|iPad11|iPad13, <orientation> portrait|landscape (the screen's, as the app passes it), <w>x<h> the paper
// area in points (decimals allowed, as the log writes them), cap (the default, what the app passes on every window but a
// wide one) or nocap. Exits 0, or 2 on a malformed line.

func runSpanStateIfAsked() {
    let arguments = CommandLine.arguments
    guard let i = arguments.firstIndex(of: "--span-state") else { return }
    let usage = "usage: KitChecks --span-state <month|week|day|year> <iPhone|iPadMini|iPad11|iPad13> <portrait|landscape> <w>x<h> [cap|nocap]"
    let rest = Array(arguments[(i + 1)...])
    guard rest.count == 4 || rest.count == 5,
          let kind = PageKind(rawValue: rest[0]),
          let deviceClass = SpanDeviceClass(rawValue: rest[1]),
          let orientation = SpanOrientation(rawValue: rest[2]) else {
        print("KitChecks: \(usage)")
        exit(2)
    }
    let sides = rest[3].lowercased().split(separator: "x", omittingEmptySubsequences: false)
    guard sides.count == 2, let w = Double(sides[0]), let h = Double(sides[1]), w.isFinite, h.isFinite, w > 0, h > 0 else {
        print("KitChecks: --span-state: the paper area must be <w>x<h> with two positive numbers, not \(rest[3])")
        exit(2)
    }
    let cap: Bool
    switch rest.count == 5 ? rest[4] : "cap" {
    case "cap": cap = true
    case "nocap": cap = false
    default:
        print("KitChecks: \(usage)")
        exit(2)
    }
    let area = CGSize(width: CGFloat(w), height: CGFloat(h))
    let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: deviceClass, orientation: orientation, overviewCap: cap)
    let bounds = plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area)
    let v = plan.visiblePages(viewport: area)
    let r = SpanPlan.radius(forVisiblePages: v)
    let maxPages = plan.maxVisiblePages(viewport: area)
    let line = [
        "span state:",
        "kind=\(kind.rawValue)",
        "class=\(deviceClass.rawValue)",
        "orientation=\(orientation.rawValue)",
        "area=\(String(format: "%.2fx%.2f", w, h))",
        "cap=\(cap ? "on" : "off")",
        "zoom=\(String(format: "%.5f", Double(bounds.min)))",
        "open=\(String(format: "%.5f", Double(bounds.open)))",
        "fit=\(String(format: "%.5f", Double(bounds.fit)))",
        "max=\(String(format: "%.5f", Double(bounds.max)))",
        "V=\(String(format: "%.3f", Double(v)))",
        "maxPages=\(maxPages.map { String(format: "%.0f", Double($0)) } ?? "nil")",
        "R=\(r)",
        "planR=\(plan.radius)",
        "pages=\(2 * max(plan.radius, r) + 1)",
    ].joined(separator: " ")
    print(line)
    exit(0)
}
