// KitChecks: the iPhone Duo's span plans, 1.4 (docs/M7D_CONTRACT.md §4.6, §4.7, §6; section "duo (1.4)"), and the mode
// `--span-state` (§3.3, gate 3 (b)). main.swift calls `runSpanStateIfAsked()` before every check and `runDuoChecks()` right
// after `runOverviewCapChecks()`; it uses main.swift's `section`, `check`, `checkEqual`, `passed` and `failures`.
//
// ESTIMATES. Apple has not published the Duo's screens in points, and CI has not measured them yet. Every paper area below is
// an estimate of docs/m7d/CODE_SURVEY.md §3.2 (docs/m7d/duo_span_calc.py): the inner screen 669 × 951 or 626 × 890 and the
// outer one 466 × 678, less the header, the one-lane all-day band and the safe areas as today's devices measure them (one-row
// header portrait 255–334 pt, landscape 197–223 pt; two-row header 334 pt; the day 4 pt below the week). They are to be
// replaced by the values duo-probe / duo-shots measure (the `duo measure:` lines, §4.2), the expectations worked out again by
// hand for them; a screen CI cannot measure (the inner one on road 3, §4.2) stays an estimate, and says so here.
// 1.3's estimated Duo rows (SpanChecks.swift, "Duo inner V … (1.4 checks it again)") stay in SpanChecks as 1.3's checks
// (TESTS_1_3 keeps that file byte for byte); the Duo's rows of 1.4 are here.
//
// Each row: the Duo is `.iPhone` on both screens (`SpanDeviceClass(screen:isPad: false)`), the plan's orientation is the
// screen's, and its `overviewCap` is `WindowClass.capsOverview(windowSize:)` of the screen (the window fills it): the outer
// screen caps, the inner one (a wide window, §4.7) does not. The expectations are literals worked out by hand with a separate
// calculation that re-implements ZoomPolicy's and SpanPlan's rules for the week and the day (as 1.3's PLAN_PB6 rows were),
// never read back from the code under test: V (±0.006), R of that V, the plan's R, the window SpanSession.windowRadius builds
// (the larger R; its stroke cap aside), maxVisiblePages, the lowest zoom (±0.000001) and the hours on screen there (±0.001).
import Foundation
import CoreGraphics
import Layout

/// One estimated Duo paper area and what its plan gives.
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

/// The rows (estimates, see the head of the file). Inner portrait: the width binds, so V is the area's shape and every hour
/// fits; the day's V over 2.05 widens its window from the row's 5 to 7. Inner landscape: no cap (the plan is the iPhone's
/// landscape row of P-B6 ア, R 4 / 7: 9 weeks, 15 days), every hour fits. Outer portrait: the paper area is wider than tall, so
/// the cap is there (3 / 5) but below the lowest zoom. Outer landscape: the cap binds (V 3 / 5, windows 7 / 9, part of the day).
private let duoRows: [DuoRow] = [
    // Inner screen A, 669 × 951 portrait (header 334 or 255 pt).
    row("inner A portrait", 669, 951, .week, 669, 617, caps: false, v: 1.49, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.321354, hours: 24),
    row("inner A portrait", 669, 951, .day, 669, 613, caps: false, v: 2.62, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.255417, hours: 24),
    row("inner A portrait", 669, 951, .week, 669, 696, caps: false, v: 1.32, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.362500, hours: 24),
    row("inner A portrait", 669, 951, .day, 669, 692, caps: false, v: 2.32, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.288333, hours: 24),
    // Inner screen B, 626 × 890 portrait.
    row("inner B portrait", 626, 890, .week, 626, 556, caps: false, v: 1.54, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.289583, hours: 24),
    row("inner B portrait", 626, 890, .day, 626, 552, caps: false, v: 2.72, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.230000, hours: 24),
    row("inner B portrait", 626, 890, .week, 626, 635, caps: false, v: 1.35, r: 2, planR: 2, pages: 5, maxPages: nil, minZoom: 0.330729, hours: 24),
    row("inner B portrait", 626, 890, .day, 626, 631, caps: false, v: 2.38, r: 3, planR: 2, pages: 7, maxPages: nil, minZoom: 0.262917, hours: 24),
    // Inner screen A, 951 × 669 landscape (header 223 or 197 pt).
    row("inner A landscape", 951, 669, .week, 951, 446, caps: false, v: 2.92, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.232292, hours: 24),
    row("inner A landscape", 951, 669, .day, 951, 442, caps: false, v: 5.16, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.184167, hours: 24),
    row("inner A landscape", 951, 669, .week, 951, 472, caps: false, v: 2.76, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.245833, hours: 24),
    row("inner A landscape", 951, 669, .day, 951, 468, caps: false, v: 4.88, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.195000, hours: 24),
    // Inner screen B, 890 × 626 landscape.
    row("inner B landscape", 890, 626, .week, 890, 403, caps: false, v: 3.03, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.209896, hours: 24),
    row("inner B landscape", 890, 626, .day, 890, 399, caps: false, v: 5.35, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.166250, hours: 24),
    row("inner B landscape", 890, 626, .week, 890, 429, caps: false, v: 2.85, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.223438, hours: 24),
    row("inner B landscape", 890, 626, .day, 890, 425, caps: false, v: 5.03, r: 4, planR: 7, pages: 15, maxPages: nil, minZoom: 0.177083, hours: 24),
    // The inner landscape areas under the all-day band at its 35 % cap: the one-lane band at the overview is 3 + 18 + 4 = 25 pt,
    // so the band-and-paper area is the one-lane paper + 25 and the paper keeps that − ⌊0.35 × that⌋ (AllDayBandMetrics). No
    // cap all the same: the band never changes the answer (§4.7, C12).
    row("inner A landscape, band at 35 %", 951, 669, .week, 951, 307, caps: false, v: 4.25, r: 4, planR: 4, pages: 9, maxPages: nil, minZoom: 0.159896, hours: 24),
    row("inner A landscape, band at 35 %", 951, 669, .day, 951, 304, caps: false, v: 7.51, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.126667, hours: 24),
    row("inner A landscape, band at 35 %", 951, 669, .week, 951, 324, caps: false, v: 4.03, r: 3, planR: 4, pages: 9, maxPages: nil, minZoom: 0.168750, hours: 24),
    row("inner A landscape, band at 35 %", 951, 669, .day, 951, 321, caps: false, v: 7.11, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.133750, hours: 24),
    row("inner B landscape, band at 35 %", 890, 626, .week, 890, 279, caps: false, v: 4.37, r: 4, planR: 4, pages: 9, maxPages: nil, minZoom: 0.145313, hours: 24),
    row("inner B landscape, band at 35 %", 890, 626, .day, 890, 276, caps: false, v: 7.74, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.115000, hours: 24),
    row("inner B landscape, band at 35 %", 890, 626, .week, 890, 296, caps: false, v: 4.12, r: 4, planR: 4, pages: 9, maxPages: nil, minZoom: 0.154167, hours: 24),
    row("inner B landscape, band at 35 %", 890, 626, .day, 890, 293, caps: false, v: 7.29, r: 5, planR: 7, pages: 15, maxPages: nil, minZoom: 0.122083, hours: 24),
    // The outer screen, 466 × 678 portrait (two-row header, 334 pt).
    row("outer portrait", 466, 678, .week, 466, 344, caps: true, v: 1.86, r: 2, planR: 2, pages: 5, maxPages: 3, minZoom: 0.179167, hours: 24),
    row("outer portrait", 466, 678, .day, 466, 340, caps: true, v: 3.29, r: 3, planR: 2, pages: 7, maxPages: 5, minZoom: 0.141667, hours: 24),
    // The outer screen, 678 × 466 landscape (header 223 or 197 pt; the full width, or 124 pt of side insets off it).
    row("outer landscape", 678, 466, .week, 678, 243, caps: true, v: 3.00, r: 3, planR: 3, pages: 7, maxPages: 3, minZoom: 0.161429, hours: 18.816),
    row("outer landscape", 678, 466, .day, 678, 239, caps: true, v: 5.00, r: 4, planR: 4, pages: 9, maxPages: 5, minZoom: 0.135600, hours: 17.625),
    row("outer landscape", 678, 466, .week, 678, 269, caps: true, v: 3.00, r: 3, planR: 3, pages: 7, maxPages: 3, minZoom: 0.161429, hours: 20.830),
    row("outer landscape", 678, 466, .day, 678, 265, caps: true, v: 5.00, r: 4, planR: 4, pages: 9, maxPages: 5, minZoom: 0.135600, hours: 19.543),
    row("outer landscape, side insets", 678, 466, .week, 554, 243, caps: true, v: 3.00, r: 3, planR: 3, pages: 7, maxPages: 3, minZoom: 0.131905, hours: 23.028),
    row("outer landscape, side insets", 678, 466, .day, 554, 239, caps: true, v: 5.00, r: 4, planR: 4, pages: 9, maxPages: 5, minZoom: 0.110800, hours: 21.570),
]

/// The lu of one hour of the 24-hour grid: week 1920 ÷ 24, day 2400 ÷ 24.
private func luPerHour(_ kind: PageKind) -> CGFloat { kind == .day ? 100 : 80 }

func runDuoChecks() {
    section("duo (1.4)")
    let start = passed + failures.count
    print("   the Duo's paper areas are ESTIMATES (docs/m7d/CODE_SURVEY.md §3.2) until duo-shots measures them (§4.2):")
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
        ("inner A landscape one lane", innerA, .week, CGSize(width: 951, height: 446), 0.232292, 0.232292),
        ("inner A landscape one lane", innerA, .day, CGSize(width: 951, height: 442), 0.184167, 0.190200),
        ("inner A landscape one lane", innerA, .week, CGSize(width: 951, height: 472), 0.245833, 0.245833),
        ("inner A landscape one lane", innerA, .day, CGSize(width: 951, height: 468), 0.195000, 0.195000),
        ("inner A landscape band at 35 %", innerA, .week, CGSize(width: 951, height: 307), 0.159896, 0.226429),
        ("inner A landscape band at 35 %", innerA, .day, CGSize(width: 951, height: 304), 0.126667, 0.190200),
        ("inner B landscape one lane", innerB, .week, CGSize(width: 890, height: 403), 0.209896, 0.211905),
        ("inner B landscape one lane", innerB, .week, CGSize(width: 890, height: 429), 0.223438, 0.223438),
        ("inner B landscape band at 35 %", innerB, .week, CGSize(width: 890, height: 279), 0.145313, 0.211905),
        ("inner B landscape band at 35 %", innerB, .day, CGSize(width: 890, height: 276), 0.115000, 0.178000),
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

    // The outer landscape caps as today's iPhone in landscape does: the opening zoom is the cap too (678 ÷ (3 × 1400) and
    // 678 ÷ (5 × 1000)), and fit-to-width stays the width ÷ 1400 or 1000.
    let outer: [(PageKind, CGSize, CGFloat, CGFloat)] = [
        (.week, CGSize(width: 678, height: 243), 0.161429, 0.484286),
        (.day, CGSize(width: 678, height: 239), 0.135600, 0.678000),
    ]
    for (kind, area, open, fit) in outer {
        let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape,
                            overviewCap: WindowClass.capsOverview(windowSize: CGSize(width: 678, height: 466)))
        let b = plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area)
        check(abs(b.open - open) <= 0.000001, "duo: outer landscape \(kind) opens at its capped lowest zoom \(open)")
        check(abs(b.fit - fit) <= 0.000001, "duo: outer landscape \(kind) fit-to-width stays \(fit)")
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
