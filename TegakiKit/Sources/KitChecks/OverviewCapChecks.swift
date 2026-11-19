// KitChecks: the iPhone's landscape overview cap of 1.3 (P-B6 イ, the owner's answer of 11/18; docs/M7C_CONTRACT.md
// §3.6, §3.16, §10.1, B_DESIGN.md §3.1, §6.2; section "overview cap (1.3)"). main.swift calls `runOverviewCapChecks()`
// right after `runWeekMemoChecks()`; it uses main.swift's `section`, `check` and `checkEqual`.
//
// On the joined path an iPhone in landscape shows at most 3 week pages / 5 day pages across at its lowest and its
// opening zoom (windows 7 / 9); every other device and orientation, and every plan made without `overviewCap`, keeps
// its numbers. The expectations are literals worked out by hand from B_DESIGN.md §6.2 (V 3 → 7 pages, V 5 → 9 pages)
// and from the reference and measured paper areas (the cap = width ÷ (pages × 1,400 or 1,000 lu)), not read back from
// the code under test; where an answer must not change, it is compared with `ZoomPolicy.bounds` or the plan without
// the cap.
import Foundation
import CoreGraphics
import Layout

func runOverviewCapChecks() {
    section("overview cap (1.3)")
    let kinds: [PageKind] = [.month, .week, .day, .year]
    let devices = SpanDeviceClass.allCases
    let orientations = SpanOrientation.allCases
    // The paper's width (lu) and the cap (pages) of the week and the day, as literals.
    func width(_ kind: PageKind) -> CGFloat { kind == .day ? 1000 : 1400 }
    func capPages(_ kind: PageKind) -> CGFloat { kind == .day ? 5 : 3 }

    // 1. The rule: an iPhone in landscape only; week and year 3, day 5, month none.
    for device in devices {
        for orientation in orientations {
            for kind in kinds {
                let expected: CGFloat?
                if device == .iPhone && orientation == .landscape {
                    expected = kind == .day ? 5 : (kind == .month ? nil : 3)
                } else {
                    expected = nil
                }
                checkEqual(SpanPlan.overviewCapPages(kind, deviceClass: device, orientation: orientation), expected,
                           "overview cap: \(device) \(orientation) \(kind) caps at \(expected.map { "\($0)" } ?? "nothing")")
            }
        }
    }

    // 2. The window table with the cap (B_DESIGN.md §6.2's row 「iPhone 横（上限ありにした場合）」): the iPhone's landscape
    // month 2.85 → 7, week 3 → 7, day 5 → 9, year 3 → 7; every other row as without the cap.
    let capped: [PageKind: (CGFloat, Int)] = [.month: (2.85, 7), .week: (3.00, 7), .day: (5.00, 9), .year: (3.00, 7)]
    for device in devices {
        for orientation in orientations {
            for kind in kinds {
                let plain = SpanPlan(kind: kind, weekStart: .monday, deviceClass: device, orientation: orientation)
                let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: device, orientation: orientation, overviewCap: true)
                check(plan != plain && plan.overviewCap && !plain.overviewCap, "overview cap: \(device) \(orientation) \(kind) the flag is part of the plan")
                if device == .iPhone && orientation == .landscape, let (v, pages) = capped[kind] {
                    check(abs(plan.visiblePages - v) <= 0.006, "overview cap: iPhone landscape \(kind) V \(plan.visiblePages) is \(v)")
                    checkEqual(plan.windowSize, pages, "overview cap: iPhone landscape \(kind) is \(pages) pages")
                    checkEqual(plan.radius, (pages - 1) / 2, "overview cap: iPhone landscape \(kind) R")
                } else {
                    checkEqual(plan.visiblePages, plain.visiblePages, "overview cap: \(device) \(orientation) \(kind) V as without the cap")
                    checkEqual(plan.radius, plain.radius, "overview cap: \(device) \(orientation) \(kind) R as without the cap")
                }
                // The page numbers, ids and places do not depend on the cap.
                for index in [-3, 0, 2_917, 20_000] {
                    checkEqual(plan.pageId(at: index), plain.pageId(at: index), "overview cap: \(kind) page id \(index)")
                    checkEqual(plan.origin(of: index, around: index), CGFloat(plan.radius) * width(kind), "overview cap: \(kind) origin \(index)")
                }
            }
        }
    }
    // Without the flag the plan is P-B6 ア: the uncapped table (spanWindowTableChecks) and no cap for any area.
    checkEqual(SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape),
               SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape, overviewCap: false),
               "overview cap: the default is no cap")
    checkEqual(SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape).windowSize, 9,
               "overview cap: without the flag the iPhone's landscape week stays 9 pages")
    checkEqual(SpanPlan(kind: .day, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape).windowSize, 15,
               "overview cap: without the flag the iPhone's landscape day stays 15 pages")

    // The week start does not matter (the owner's note of 11/18 on Sunday weeks): a capped Sunday week is the Monday's.
    for orientation in orientations {
        let monday = SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPhone, orientation: orientation, overviewCap: true)
        let sunday = SpanPlan(kind: .week, weekStart: .sunday, deviceClass: .iPhone, orientation: orientation, overviewCap: true)
        checkEqual(sunday.visiblePages, monday.visiblePages, "overview cap: a Sunday week's V is the Monday week's (\(orientation))")
        checkEqual(sunday.windowSize, monday.windowSize, "overview cap: a Sunday week's window is the Monday week's (\(orientation))")
        checkEqual(sunday.zoomBounds(overview: ZoomPolicy.baseSize(.week), viewport: CGSize(width: 874, height: 205)),
                   monday.zoomBounds(overview: ZoomPolicy.baseSize(.week), viewport: CGSize(width: 874, height: 205)),
                   "overview cap: a Sunday week's limits are the Monday week's (\(orientation))")
    }

    // 3. The zoom limits. Paper areas (pt): the reference row, the measured iPhone 17 and the Pro Max's estimate.
    let areas: [(String, PageKind, CGSize)] = [
        ("iPhone reference landscape", .week, CGSize(width: 874, height: 205)),
        ("iPhone reference landscape", .day, CGSize(width: 874, height: 205)),
        ("iPhone 17 landscape (measured)", .week, CGSize(width: 750, height: 179)),
        ("iPhone 17 landscape (measured)", .day, CGSize(width: 750, height: 175)),
        ("iPhone Pro Max landscape (estimate)", .week, CGSize(width: 832, height: 217)),
        ("iPhone Pro Max landscape (estimate)", .day, CGSize(width: 832, height: 213)),
    ]
    // (min = open = width ÷ (pages × W), the hours on screen = height ÷ zoom (lu), worked out by hand)
    let expectedZoom: [(CGFloat, CGFloat)] = [(0.208095, 985.1), (0.174800, 1172.8), (0.178571, 1002.4), (0.150000, 1166.7),
                                              (0.198095, 1095.4), (0.166400, 1280.0)]
    for ((name, kind, area), (zoom, hours)) in zip(areas, expectedZoom) {
        let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
        let plain = ZoomPolicy.bounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: area)
        let b = plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area)
        check(abs(b.min - zoom) < 0.00001, "overview cap: \(name) \(kind) lowest zoom \(b.min) is \(zoom)")
        check(abs(b.open - zoom) < 0.00001 && abs(b.open - b.min) < 1e-12, "overview cap: \(name) \(kind) opens at the lowest zoom \(b.open)")
        checkEqual(b.fit, plain.fit, "overview cap: \(name) \(kind) fit-to-width stays")
        checkEqual(b.max, plain.max, "overview cap: \(name) \(kind) the highest zoom stays")
        check(b.min / plain.min > 1.7 && b.min / plain.min < 2.1, "overview cap: \(name) \(kind) about twice the overview's size (\(b.min) against \(plain.min))")
        check(abs(area.height / b.min - hours) < 0.1, "overview cap: \(name) \(kind) \(area.height / b.min) lu of the hours on screen")
        let day: CGFloat = kind == .day ? 2400 : 1920
        check(area.height / b.min < day * 0.6 && area.height / b.min > day * 0.45, "overview cap: \(name) \(kind) about half of the 24 hours")
        let pagesAcross = area.width / (width(kind) * b.min)
        check(abs(pagesAcross - capPages(kind)) < 1e-9, "overview cap: \(name) \(kind) \(pagesAcross) pages across")
        checkEqual(ZoomPolicy.zoom(forRatio: 1, bounds: b), b.open, "overview cap: \(name) \(kind) ratio 1 is the capped opening")
        checkEqual(ZoomPolicy.ratio(forZoom: b.open, bounds: b), 1, "overview cap: \(name) \(kind) the capped opening stores ratio 1")
        check(ZoomPolicy.ratio(forZoom: b.open * 2, bounds: b) == 2, "overview cap: \(name) \(kind) a pinch to twice stores 2")
        // A fling at the capped overview turns exactly one page, centred (P-B5 ア; a page narrower than the screen).
        let page = width(kind) * b.min
        let centred = (CGFloat(plan.radius) + 0.5) * page - area.width / 2
        let next = plan.flingTarget(offsetX: centred, velocity: 1, zoom: b.min, viewportWidth: area.width)
        check(abs(next - centred - page) < 1e-6, "overview cap: \(name) \(kind) a fling turns one page")
        let back = plan.flingTarget(offsetX: centred, velocity: -1, zoom: b.min, viewportWidth: area.width)
        check(abs(centred - back - page) < 1e-6, "overview cap: \(name) \(kind) a fling back turns one page")
    }

    // 4. Many all-day lanes (M7C.md, S1's lead's decision 1): the measured paper area shorter, the cap holds V at 3 / 5
    // and the window at the plan's R, where the uncapped V would widen it (week up to 7.99, day up to 13.98).
    for kind in [PageKind.week, .day] {
        let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape, overviewCap: true)
        let plain = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: .landscape)
        for height in stride(from: CGFloat(205), through: 150, by: -5) {
            let area = CGSize(width: 874, height: height)
            let v = plan.visiblePages(viewport: area)
            checkEqual(v, capPages(kind), "overview cap: \(kind) of 874 × \(height) shows \(v) pages")
            checkEqual(SpanPlan.radius(forVisiblePages: v), kind == .day ? 4 : 3, "overview cap: \(kind) of 874 × \(height) keeps R \(plan.radius)")
            checkEqual(plain.visiblePages(viewport: area), SpanPlan.visiblePages(kind, viewport: area),
                       "overview cap: \(kind) of 874 × \(height) without the flag is the measured V")
        }
        check(SpanPlan.visiblePages(kind, viewport: CGSize(width: 874, height: 150)) > (kind == .day ? 13.9 : 7.9),
              "overview cap: \(kind) the uncapped V of 80 pt of lanes is the one the lead's decision 1 widened for")
    }

    // 5. The paper area's own orientation (a turn has its cap before the window is decided anew): a capped iPhone plan
    // of either orientation caps a landscape area and leaves a portrait one (and the first frame's width alone) as it was.
    for kind in [PageKind.week, .day] {
        for orientation in orientations {
            let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: .iPhone, orientation: orientation, overviewCap: true)
            let landscape = CGSize(width: 874, height: 205)
            let cap: CGFloat = kind == .day ? 874.0 / 5000 : 874.0 / 4200
            check(abs(plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: landscape).min - cap) < 1e-12,
                  "overview cap: a \(orientation) plan caps a landscape area (\(kind))")
            for area in [CGSize(width: 402, height: 540), CGSize(width: 402, height: 460), CGSize(width: 440, height: 622),
                         CGSize(width: 874, height: 0), CGSize(width: 402, height: 0)] {
                checkEqual(plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area),
                           ZoomPolicy.bounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: area),
                           "overview cap: a \(orientation) plan leaves \(area) (\(kind)) as it was")
            }
            // A paper area not measured yet has no cap (the first frame: the width alone decides, as fitAll does).
            for area in [CGSize(width: 874, height: 0), CGSize(width: 402, height: 0), CGSize(width: 874, height: -205),
                         CGSize(width: 874, height: CGFloat.nan), CGSize(width: 874, height: CGFloat.infinity),
                         CGSize(width: CGFloat.nan, height: 205), CGSize(width: 0, height: 205)] {
                checkEqual(plan.maxVisiblePages(viewport: area), nil, "overview cap: no cap for the unmeasured \(area) (\(kind), \(orientation) plan)")
            }
            checkEqual(plan.maxVisiblePages(viewport: landscape), capPages(kind), "overview cap: the cap of 874 × 205 (\(kind), \(orientation) plan)")
            // An iPhone's portrait paper area under an all-day band at its 35 % cap is wider than tall (PB6-C3): the cap
            // applies there, but it is below the lowest zoom, so the limits and V stay 1.2.3's.
            for area in [CGSize(width: 402, height: 368), CGSize(width: 375, height: 330), CGSize(width: 440, height: 405)] {
                checkEqual(SpanOrientation(screen: area), .landscape, "overview cap: \(area) is wider than tall")
                checkEqual(plan.maxVisiblePages(viewport: area), capPages(kind), "overview cap: \(area) has the cap (\(kind))")
                let plain = ZoomPolicy.bounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: area)
                check(area.width / (capPages(kind) * width(kind)) < plain.min * 0.6,
                      "overview cap: \(area)'s cap is well below its lowest zoom \(plain.min) (\(kind))")
                checkEqual(plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area), plain,
                           "overview cap: a \(orientation) plan leaves the tall-band \(area) (\(kind)) as it was")
                checkEqual(plan.visiblePages(viewport: area), SpanPlan.visiblePages(kind, viewport: area),
                           "overview cap: the tall-band \(area) (\(kind)) keeps its measured V")
            }
        }
    }

    // 6. iPads: never capped, in any orientation, area or kind (the iPad mini's landscape day V 5.18 included).
    let pads: [CGSize] = [CGSize(width: 1133, height: 525), CGSize(width: 1133, height: 485), CGSize(width: 1180, height: 565),
                          CGSize(width: 1210, height: 615), CGSize(width: 1376, height: 777), CGSize(width: 834, height: 955),
                          CGSize(width: 744, height: 874), CGSize(width: 590, height: 820)]
    for device in devices where device != .iPhone {
        for orientation in orientations {
            for kind in kinds {
                let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: device, orientation: orientation, overviewCap: true)
                for area in pads {
                    checkEqual(plan.zoomBounds(overview: ZoomPolicy.baseSize(kind), viewport: area),
                               ZoomPolicy.bounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: area),
                               "overview cap: \(device) \(orientation) \(kind) \(area) is never capped")
                    checkEqual(plan.visiblePages(viewport: area), SpanPlan.visiblePages(kind, viewport: area),
                               "overview cap: \(device) \(orientation) \(kind) \(area) V as measured")
                }
            }
        }
    }

    // 7. ZoomPolicy.cappedBounds alone: nil, a bad count, a bad width or a cap at or below the lowest zoom → bounds `==`;
    // otherwise min ≤ open ≤ max with min the cap (random inputs).
    let overview = ZoomPolicy.baseSize(.week)
    let iPhone = CGSize(width: 874, height: 205)
    for pages in [nil, CGFloat.nan, .infinity, -.infinity, 0, -3, 6, 100] as [CGFloat?] {
        checkEqual(ZoomPolicy.cappedBounds(.week, overview: overview, viewport: iPhone, maxVisiblePages: pages),
                   ZoomPolicy.bounds(.week, overview: overview, viewport: iPhone),
                   "overview cap: cappedBounds with \(pages.map { "\($0)" } ?? "nil") pages is bounds")
    }
    for areaWidth in [CGFloat.nan, 0, -874] {
        let area = CGSize(width: areaWidth, height: 205)
        checkEqual(ZoomPolicy.cappedBounds(.week, overview: overview, viewport: area, maxVisiblePages: 3),
                   ZoomPolicy.bounds(.week, overview: overview, viewport: area), "overview cap: cappedBounds of a width \(areaWidth) is bounds")
    }
    var seed: UInt64 = 0x5EED_B6
    func next() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 11) / CGFloat(1 << 53)
    }
    for n in 0..<300 {
        let kind = kinds[n % 4]
        let area = CGSize(width: 200 + next() * 1300, height: next() * 1300)
        let ov = CGSize(width: ZoomPolicy.paperWidth(kind), height: 500 + next() * 4000)
        let pages = 0.5 + next() * 12
        let plain = ZoomPolicy.bounds(kind, overview: ov, viewport: area)
        let b = ZoomPolicy.cappedBounds(kind, overview: ov, viewport: area, maxVisiblePages: pages)
        let cap = area.width / (pages * ZoomPolicy.paperWidth(kind))
        check(b.min <= b.open + 1e-12 && b.open <= b.max + 1e-12 && b.fit == plain.fit, "overview cap: random \(n) is ordered")
        check(abs(b.min - max(plain.min, cap)) < 1e-12, "overview cap: random \(n) lowest zoom is max(bounds, cap)")
        check(cap > plain.min || b == plain, "overview cap: random \(n) a cap at or below the lowest zoom changes nothing")
    }
}
