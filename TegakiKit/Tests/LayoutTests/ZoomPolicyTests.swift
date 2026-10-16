import XCTest
import Foundation
import CoreGraphics
import Layout

/// The zoom-scale limits of the four pages and the viewport the sticky header follows
/// (M4C_CONTRACT §1.1 / §1.2: the overview, fitAll, is the lower limit since M4c). The numbers are
/// the tables of §1.2; the same checks run in KitChecks.
final class ZoomPolicyTests: XCTestCase {
    private typealias F = M3aFixtures
    private let readableWeek: CGFloat = 90 / (1336.0 / 7)
    private let readableDay: CGFloat = 330.0 / 588
    private let readableYear: CGFloat = 150.0 / 112

    /// The overview rectangles of the empty pages (D1).
    private func overview(_ kind: PageKind) -> CGSize {
        switch kind {
        case .month: return CGSize(width: 1400, height: 1050)
        case .week: return CGSize(width: 1400, height: 1920)
        case .day: return CGSize(width: 1000, height: 2400)
        case .year: return CGSize(width: 1400, height: 1860)
        }
    }

    private func bounds(_ kind: PageKind, _ width: CGFloat, _ height: CGFloat) -> ZoomPolicy.Bounds {
        ZoomPolicy.bounds(kind, overview: overview(kind), viewport: CGSize(width: width, height: height))
    }

    func testConstants() {
        XCTAssertEqual(ZoomPolicy.readableZoom(.month), 0.5, accuracy: 1e-4)
        XCTAssertEqual(ZoomPolicy.readableZoom(.week), 0.47156, accuracy: 1e-4)
        XCTAssertEqual(ZoomPolicy.readableZoom(.day), 0.56122, accuracy: 1e-4)
        XCTAssertEqual(ZoomPolicy.readableZoom(.year), 1.33929, accuracy: 1e-4)
        XCTAssertEqual(ZoomPolicy.keyColumnWidth(.month), 200)
        XCTAssertEqual(ZoomPolicy.keyColumnWidth(.week), 1336.0 / 7)
        XCTAssertEqual(ZoomPolicy.keyColumnWidth(.day), 588, "the timeline column")
        XCTAssertEqual(ZoomPolicy.keyColumnWidth(.year), 112)
        XCTAssertEqual(ZoomPolicy.readableColumnPoints(.month), 100)
        XCTAssertEqual(ZoomPolicy.readableColumnPoints(.week), 90)
        XCTAssertEqual(ZoomPolicy.readableColumnPoints(.day), 330)
        XCTAssertEqual(ZoomPolicy.readableColumnPoints(.year), 150, "M4B-22")
        XCTAssertEqual(ZoomPolicy.paperWidth(.month), 1400)
        XCTAssertEqual(ZoomPolicy.paperWidth(.week), 1400)
        XCTAssertEqual(ZoomPolicy.paperWidth(.day), 1000)
        XCTAssertEqual(ZoomPolicy.paperWidth(.year), 1400)
        XCTAssertEqual(ZoomPolicy.maxStoredRatio, 64, "M4C-9")
    }

    func testOverviewSize() {
        let emptyMonth = F.monthLayout([])
        XCTAssertEqual(ZoomPolicy.overviewSize(emptyMonth), CGSize(width: 1400, height: 1050), "an empty October: 6 × 175")
        XCTAssertEqual(ZoomPolicy.overviewSize(emptyMonth).height, emptyMonth.memo.minY)
        let busyMonth = F.monthLayout(F.demo)
        XCTAssertEqual(ZoomPolicy.overviewSize(busyMonth), CGSize(width: 1400, height: busyMonth.memo.minY), "a busy month: memo.minY")
        XCTAssertGreaterThan(ZoomPolicy.overviewSize(busyMonth).height, 1050, "the demo month's rows grew")
        XCTAssertLessThan(ZoomPolicy.overviewSize(busyMonth).height, busyMonth.size.height, "the memo area is not in the overview (M4C-12)")
        XCTAssertEqual(ZoomPolicy.overviewSize(F.monthLayout([], ink: [.day(F.day(2026, 10, 7)): 500])), CGSize(width: 1400, height: 1050 - 175 + 512), "handwriting grows a row and the overview")
        XCTAssertEqual(ZoomPolicy.overviewSize(F.weekLayout(F.demo)), CGSize(width: 1400, height: 1920), "week: the whole paper")
        XCTAssertEqual(ZoomPolicy.overviewSize(F.dayLayout(F.demo)), CGSize(width: 1000, height: 2400), "day: the whole paper")
        XCTAssertEqual(ZoomPolicy.overviewSize(F.yearLayout([])), CGSize(width: 1400, height: 1860), "an empty year: 31 × 60")
        XCTAssertEqual(ZoomPolicy.overviewSize(F.yearLayout(F.demo)), CGSize(width: 1400, height: 1896), "the demo year: the 16th's row is 96")
        XCTAssertEqual(ZoomPolicy.overviewSize(F.yearLayout(F.demo)), F.yearLayout(F.demo).size)
    }

    func testFitAllTable() {
        // (width, month height, week / day height with a one-lane band) → fitAll of month / week / day / year (M4C_CONTRACT §1.2).
        let devices: [(name: String, width: CGFloat, height: CGFloat, bandHeight: CGFloat, month: CGFloat, week: CGFloat, day: CGFloat, year: CGFloat)] = [
            ("iPhone 17 portrait", 402, 580, 555, 0.2871, 0.2871, 0.2313, 0.2871),
            ("iPhone 390 portrait", 390, 580, 555, 0.2786, 0.2786, 0.2313, 0.2786),
            ("iPad mini portrait", 744, 950, 925, 0.5314, 0.4818, 0.3854, 0.5108),
            ("iPad 11 portrait", 834, 1020, 995, 0.5957, 0.5182, 0.4146, 0.5484),
            ("iPad 13 portrait", 1024, 1180, 1155, 0.7314, 0.6016, 0.4813, 0.6344),
            ("iPad 13 landscape", 1366, 830, 805, 0.7905, 0.4193, 0.3354, 0.4462),
            ("iPad 11 landscape", 1210, 640, 615, 0.6095, 0.3203, 0.2563, 0.3441),
            ("iPad mini landscape", 1133, 550, 525, 0.5238, 0.2734, 0.2188, 0.2957),
            ("iPhone 17 landscape", 874, 230, 205, 0.2190, 0.1068, 0.0854, 0.1237),
        ]
        for d in devices {
            let full = CGSize(width: d.width, height: d.height)
            let band = CGSize(width: d.width, height: d.bandHeight)
            let expected: [(PageKind, CGSize, CGFloat)] = [(.month, full, d.month), (.week, band, d.week), (.day, band, d.day), (.year, full, d.year)]
            for (kind, viewport, fitAll) in expected {
                let label = "\(kind), \(d.name)"
                let got = ZoomPolicy.fitAll(kind, overview: overview(kind), viewport: viewport)
                XCTAssertEqual(got, fitAll, accuracy: 1e-3, label)
                XCTAssertEqual(got, min(viewport.width / overview(kind).width, viewport.height / overview(kind).height), accuracy: 1e-9, label)
                XCTAssertLessThanOrEqual(got, ZoomPolicy.fitZoom(kind, viewportWidth: viewport.width) + 1e-12, "fitAll ≤ fit: \(label)")
                let b = ZoomPolicy.bounds(kind, overview: overview(kind), viewport: viewport)
                XCTAssertEqual(b.min, got, accuracy: 1e-9, "bounds.min = fitAll: \(label)")
                XCTAssertEqual(b.fit, ZoomPolicy.fitZoom(kind, viewportWidth: viewport.width), accuracy: 1e-9, label)
                XCTAssertEqual(b.max, ZoomPolicy.maxZoom(kind, viewportWidth: viewport.width), accuracy: 1e-9, label)
                XCTAssertGreaterThanOrEqual(b.max, 2 * b.min - 1e-9, "a pinch always has room: \(label)")
            }
        }
        XCTAssertEqual(ZoomPolicy.fitAll(.month, overview: overview(.month), viewport: CGSize(width: 1024, height: 1180)), 1024.0 / 1400, accuracy: 1e-9, "13 inch month: fit-to-width, unchanged from M4b")
        XCTAssertEqual(ZoomPolicy.fitAll(.month, overview: overview(.month), viewport: CGSize(width: 1366, height: 830)), 830.0 / 1050, accuracy: 1e-9, "13 inch landscape month: the height binds")
        XCTAssertEqual(ZoomPolicy.fitAll(.month, overview: CGSize(width: 1400, height: 1275), viewport: CGSize(width: 1366, height: 830)), 830.0 / 1275, accuracy: 1e-9, "a row grown to 400 lowers the overview")
        XCTAssertEqual(ZoomPolicy.fitAll(.week, overview: overview(.week), viewport: CGSize(width: 1024, height: 1180)), 1180.0 / 1920, accuracy: 1e-9, "13 inch week without a band")
        XCTAssertEqual(ZoomPolicy.fitAll(.week, overview: overview(.week), viewport: CGSize(width: 1024, height: 1150)), 1150.0 / 1920, accuracy: 1e-9, "the band grew")
        XCTAssertEqual(ZoomPolicy.fitAll(.day, overview: overview(.day), viewport: CGSize(width: 402, height: 580)), 580.0 / 2400, accuracy: 1e-9)
        XCTAssertEqual(ZoomPolicy.fitAll(.month, overview: overview(.month), viewport: CGSize(width: 874, height: 402)), 402.0 / 1050, accuracy: 1e-9, "iPhone landscape month 874 × 402")
    }

    func testBoundaryAndMaxZoom() {
        // maxZoom is unchanged from M4b (M4C-16): max(4 × fit, 2 × readable), the width alone.
        let widths: [CGFloat] = [375, 390, 402, 664, 665, 667, 678, 690, 744, 834, 1024, 1133, 1210, 1366]
        for width in widths {
            for kind in PageKind.allCases {
                let label = "\(kind) at \(width)"
                let fit = width / ZoomPolicy.paperWidth(kind)
                let readable = ZoomPolicy.readableZoom(kind)
                XCTAssertEqual(ZoomPolicy.fitZoom(kind, viewportWidth: width), fit, accuracy: 1e-9, label)
                let maxZ = ZoomPolicy.maxZoom(kind, viewportWidth: width)
                XCTAssertEqual(maxZ, max(4 * fit, 2 * readable), accuracy: 1e-9, label)
                XCTAssertGreaterThanOrEqual(maxZ, 4 * fit - 1e-12, "maxZoom ≥ 4 × fit: \(label)")
                XCTAssertGreaterThanOrEqual(maxZ, 2 * readable - 1e-12, "maxZoom ≥ 2 × readable: \(label)")
                let tall = bounds(kind, width, 100_000)
                XCTAssertEqual(tall.min, fit, accuracy: 1e-9, "the width decides in a tall area: \(label)")
                XCTAssertEqual(tall.max, maxZ, accuracy: 1e-9, label)
                let square = bounds(kind, width, width)
                XCTAssertEqual(square.min, min(fit, width / overview(kind).height), accuracy: 1e-9, "a square area: \(label)")
                XCTAssertGreaterThanOrEqual(square.max, square.min, label)
            }
        }
        let maxTable: [(name: String, width: CGFloat, monthWeek: CGFloat, day: CGFloat, year: CGFloat)] = [
            ("iPhone", 402, 1.1486, 1.608, 2.6786),
            ("iPad mini", 744, 2.1257, 2.976, 2.6786),
            ("iPad 11", 834, 2.3829, 3.336, 2.6786),
            ("iPad 13", 1024, 2.9257, 4.096, 2.9257),
        ]
        for m in maxTable {
            XCTAssertEqual(ZoomPolicy.maxZoom(.month, viewportWidth: m.width), m.monthWeek, accuracy: 1e-3, "month, \(m.name)")
            XCTAssertEqual(ZoomPolicy.maxZoom(.week, viewportWidth: m.width), m.monthWeek, accuracy: 1e-3, "week, \(m.name)")
            XCTAssertEqual(ZoomPolicy.maxZoom(.day, viewportWidth: m.width), m.day, accuracy: 1e-3, "day, \(m.name)")
            XCTAssertEqual(ZoomPolicy.maxZoom(.year, viewportWidth: m.width), m.year, accuracy: 1e-3, "year, \(m.name)")
        }
        XCTAssertEqual(ZoomPolicy.maxZoom(.year, viewportWidth: 402), 2 * readableYear, accuracy: 1e-9, "iPhone year: 2 × readable")
        XCTAssertEqual(ZoomPolicy.maxZoom(.year, viewportWidth: 1024), 4 * 1024.0 / 1400, accuracy: 1e-9, "13 inch year: 4 × fit")
        XCTAssertEqual(ZoomPolicy.maxZoom(.week, viewportWidth: 300), 2 * readableWeek, accuracy: 1e-9, "a 300 pt week: 2 × readable wins")
        XCTAssertEqual(ZoomPolicy.maxZoom(.day, viewportWidth: 250), 2 * readableDay, accuracy: 1e-9)
        // The room a pinch has above the overview (maxZoom / fitAll, §1.2).
        let iphoneMonth = bounds(.month, 402, 580)
        let iphoneDay = bounds(.day, 402, 555)
        let iphoneYear = bounds(.year, 402, 580)
        let ipadWeek = bounds(.week, 1024, 1155)
        let ipadDay = bounds(.day, 1024, 1155)
        let ipadYear = bounds(.year, 1024, 1180)
        XCTAssertEqual(iphoneMonth.max / iphoneMonth.min, 4.0, accuracy: 0.1)
        XCTAssertEqual(iphoneDay.max / iphoneDay.min, 7.0, accuracy: 0.1)
        XCTAssertEqual(iphoneYear.max / iphoneYear.min, 9.3, accuracy: 0.1)
        XCTAssertEqual(ipadWeek.max / ipadWeek.min, 4.9, accuracy: 0.1)
        XCTAssertEqual(ipadDay.max / ipadDay.min, 8.5, accuracy: 0.1)
        XCTAssertEqual(ipadYear.max / ipadYear.min, 4.6, accuracy: 0.1)
        let landscapeDay = bounds(.day, 874, 205)
        XCTAssertEqual(landscapeDay.max / landscapeDay.min, 41, accuracy: 1, "the largest ratio")
        XCTAssertLessThan(landscapeDay.max / landscapeDay.min, ZoomPolicy.maxStoredRatio)
    }

    func testBounds() {
        let b = ZoomPolicy.Bounds(fit: 0.3, min: 0.5, max: 1.2)
        XCTAssertEqual(b.fit, 0.3)
        XCTAssertEqual(b.min, 0.5)
        XCTAssertEqual(b.max, 1.2)
        XCTAssertEqual(b.clamped(.nan), 0.5, "NaN → min")
        XCTAssertEqual(b.clamped(0.1), 0.5)
        XCTAssertEqual(b.clamped(5), 1.2)
        XCTAssertEqual(b.clamped(0.8), 0.8)
        XCTAssertEqual(b.clamped(0.5), 0.5)
        XCTAssertEqual(b.clamped(1.2), 1.2)
        XCTAssertEqual(b.clamped(.infinity), 1.2)
        XCTAssertEqual(b.clamped(-.infinity), 0.5)
        XCTAssertEqual(b, ZoomPolicy.Bounds(fit: 0.3, min: 0.5, max: 1.2))
        XCTAssertNotEqual(b, ZoomPolicy.Bounds(fit: 0.3, min: 0.5, max: 1.3))
        let iphoneMonth = bounds(.month, 402, 580)
        XCTAssertEqual(iphoneMonth.clamped(0.2), 402.0 / 1400, accuracy: 1e-9, "a pinch below fitAll clamps to the overview 0.2871 (M4b: 0.5)")
        XCTAssertEqual(iphoneMonth.clamped(3), iphoneMonth.max, accuracy: 1e-9)
        XCTAssertEqual(iphoneMonth.fit, iphoneMonth.min, accuracy: 1e-9, "the month's overview is fit-to-width")
        let iphoneDay = bounds(.day, 402, 555)
        XCTAssertLessThan(iphoneDay.min, iphoneDay.fit, "the day's overview is below fit-to-width")
        let ipadWeek = bounds(.week, 1024, 1155)
        XCTAssertEqual(ipadWeek.min, 1155.0 / 1920, accuracy: 1e-9)
        XCTAssertLessThan(ipadWeek.min, ipadWeek.fit, "below M4b's minimum")
        let degenerate = bounds(.year, 1, 1)
        XCTAssertGreaterThanOrEqual(degenerate.max, degenerate.min)
        XCTAssertEqual(degenerate.min, 1.0 / 1860, accuracy: 1e-12)
    }

    func testRatios() {
        let db = bounds(.day, 402, 555) // min 0.2313, max 1.608
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 1, bounds: db), db.min, accuracy: 1e-12)
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 2, bounds: db), 2 * db.min, accuracy: 1e-12)
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 100, bounds: db), db.max, accuracy: 1e-12, "clamped to max")
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 0.5, bounds: db), db.min, accuracy: 1e-12, "clamped to min")
        for bad in [CGFloat.nan, 0, -1, .infinity, -.infinity] {
            XCTAssertEqual(ZoomPolicy.zoom(forRatio: bad, bounds: db), db.min, accuracy: 1e-12, "ratio \(bad) → min")
        }
        let ipadMonth = bounds(.month, 1024, 1180) // min 0.7314 = fit, max 2.9257
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 2, bounds: ipadMonth), 1.4628, accuracy: 1e-3)
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 3, bounds: ipadMonth), 3 * 1024.0 / 1400, accuracy: 1e-9, "inside the range (max is 4 × fit)")
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 4, bounds: ipadMonth), 2.9257, accuracy: 1e-3, "the month's max is 4 × fitAll")
        XCTAssertEqual(ZoomPolicy.zoom(forRatio: 5, bounds: ipadMonth), 2.9257, accuracy: 1e-3, "clamped")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: db.min, bounds: db), 1, accuracy: 1e-12)
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: db.max, bounds: db), db.max / db.min, accuracy: 1e-12)
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: 2 * db.min, bounds: db), 2, accuracy: 1e-12)
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: 0.5 * db.min, bounds: db), 1, accuracy: 1e-12, "below min → 1")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: 1.0005 * db.min, bounds: db), 1, accuracy: 1e-12, "within 0.1 % of min → 1")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: .nan, bounds: db), 1)
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: 100 * db.min, bounds: db), 1, "above maxStoredRatio → 1")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: 1, bounds: ZoomPolicy.Bounds(fit: 0, min: 0, max: 1)), 1, "min 0 → 1")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: 1, bounds: ZoomPolicy.Bounds(fit: 0, min: .nan, max: 1)), 1, "min NaN → 1")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: ZoomPolicy.zoom(forRatio: 6.5, bounds: db), bounds: db), 6.5, accuracy: 1e-12, "round trip")
        XCTAssertEqual(ZoomPolicy.ratio(forZoom: ZoomPolicy.zoom(forRatio: 100, bounds: db), bounds: db), db.max / db.min, accuracy: 1e-12, "round trip through the clamp")
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(.nan), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(0), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(0.5), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(-2), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(1.0005), 1, "1 ± 0.001 is 1")
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(0.9995), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(1.001), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(1.002), 1.002)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(1), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(2), 2)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(41), 41)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(64), 64, "the limit itself")
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(64.5), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(65), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(.infinity), 1)
        XCTAssertEqual(ZoomPolicy.sanitizedRatio(-.infinity), 1)
    }

    func testCenteringInsets() {
        // The paper is always the whole paper (layout.size), never the overview rectangle.
        let dayFitAll = ZoomPolicy.fitAll(.day, overview: overview(.day), viewport: CGSize(width: 402, height: 580)) // 0.2417
        let dayInset = ZoomPolicy.centeringInsets(paper: CGSize(width: 1000, height: 2400), zoom: dayFitAll, viewport: CGSize(width: 402, height: 580))
        XCTAssertEqual(dayInset.width, (402 - 1000 * dayFitAll) / 2, accuracy: 1e-9)
        XCTAssertEqual(dayInset.width, 80.1, accuracy: 0.1, "iPhone day: 80 pt each side")
        XCTAssertEqual(dayInset.height, 0, accuracy: 1e-9)
        let ipadMonth = ZoomPolicy.centeringInsets(paper: CGSize(width: 1400, height: 1750), zoom: 1024.0 / 1400, viewport: CGSize(width: 1024, height: 1180))
        XCTAssertEqual(ipadMonth.width, 0, accuracy: 1e-9, "13 inch month: fit-to-width")
        XCTAssertEqual(ipadMonth.height, 0, accuracy: 1e-9, "the paper 1280 pt > 1180: the memo area scrolls")
        XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: 1400, height: 1750), zoom: 0.7314, viewport: CGSize(width: 1024, height: 1180)).height, 0)
        let iphoneMonth = ZoomPolicy.centeringInsets(paper: CGSize(width: 1400, height: 1750), zoom: 402.0 / 1400, viewport: CGSize(width: 402, height: 580))
        XCTAssertEqual(iphoneMonth.width, 0, accuracy: 1e-9)
        XCTAssertEqual(iphoneMonth.height, 38.8, accuracy: 0.1, "iPhone month: the whole paper (502 pt) fits")
        let ipadWeek = ZoomPolicy.centeringInsets(paper: CGSize(width: 1400, height: 1920), zoom: 1180.0 / 1920, viewport: CGSize(width: 1024, height: 1180))
        XCTAssertEqual(ipadWeek.width, 81.8, accuracy: 0.1)
        XCTAssertEqual(ipadWeek.height, 0, accuracy: 1e-9)
        XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: 1400, height: 1920), zoom: 1.2, viewport: CGSize(width: 1024, height: 1180)), .zero, "zoomed in: no margin")
        XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: 1000, height: 2400), zoom: 0.25, viewport: CGSize(width: 402, height: 580)), CGSize(width: 76, height: 0))
        XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: 1000, height: 2400), zoom: 0.25, viewport: CGSize(width: 402, height: 0)), CGSize(width: 76, height: 0), "no height yet")
        for bad in [CGFloat.nan, 0, -1, .infinity, -.infinity] {
            XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: 1000, height: 2400), zoom: bad, viewport: CGSize(width: 402, height: 580)), .zero, "zoom \(bad)")
            XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: 1000, height: 2400), zoom: 0.2, viewport: CGSize(width: bad, height: bad)), .zero, "viewport \(bad)")
        }
        XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: CGFloat.nan, height: CGFloat.nan), zoom: 0.2, viewport: CGSize(width: 402, height: 580)), .zero, "a NaN paper")
        XCTAssertEqual(ZoomPolicy.centeringInsets(paper: CGSize(width: -1, height: -1), zoom: 0.2, viewport: CGSize(width: 402, height: 580)), CGSize(width: 201, height: 290), "a negative paper counts as empty")
    }

    func testVisibleWidths() {
        // The 3-argument form (the M4b 2-argument form is gone): min(paperWidth, viewportWidth / zoom).
        XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 402, zoom: 0.5742), 700, accuracy: 0.5, "iPhone month at 2 × fitAll")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 1024, zoom: 0.7314), 1400, "stops at the paper's width")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 402, zoom: 0.2871), 1400, "the overview shows the whole width")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 402, zoom: 1.1486), 350, accuracy: 0.1, "at maxZoom")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 402, zoom: 0.5), 804, accuracy: 1e-9, "M4b's value at readable")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.week, viewportWidth: 402, zoom: readableWeek), 852.5, accuracy: 0.5)
        XCTAssertEqual(ZoomPolicy.visibleWidth(.year, viewportWidth: 402, zoom: readableYear), 300.2, accuracy: 0.5)
        XCTAssertEqual(ZoomPolicy.visibleWidth(.year, viewportWidth: 1024, zoom: readableYear), 764.6, accuracy: 0.5)
        XCTAssertEqual(ZoomPolicy.visibleWidth(.year, viewportWidth: 744, zoom: readableYear), 555.5, accuracy: 0.5)
        XCTAssertEqual(ZoomPolicy.visibleWidth(.day, viewportWidth: 1024, zoom: 2), 512)
        XCTAssertEqual(ZoomPolicy.visibleWidth(.day, viewportWidth: 500, zoom: 0.4), 1000, "never exceeds the paper")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.day, viewportWidth: 1024, zoom: 1.024), 1000, accuracy: 1e-9)
        for kind in PageKind.allCases {
            let paper = ZoomPolicy.paperWidth(kind)
            for width in [CGFloat(402), 744, 1024, 1366] {
                let fit = ZoomPolicy.fitZoom(kind, viewportWidth: width)
                XCTAssertEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: width, zoom: fit), paper, "exactly the paper's width at fit (\(kind) at \(width))")
                XCTAssertEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: width, zoom: 2 * fit), paper / 2, accuracy: 1e-9, "\(kind) at \(width)")
                XCTAssertLessThanOrEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: width, zoom: fit / 3), paper, "\(kind) at \(width)")
            }
        }
    }

    func testUnusableWidths() {
        for kind in PageKind.allCases {
            let readable = ZoomPolicy.readableZoom(kind)
            let byWidth = 402 / overview(kind).width
            for bad in [CGFloat.nan, 0, -1, .infinity, -.infinity] {
                XCTAssertEqual(ZoomPolicy.fitZoom(kind, viewportWidth: bad), readable, "\(kind) at \(bad)")
                XCTAssertEqual(ZoomPolicy.maxZoom(kind, viewportWidth: bad), 4 * readable, "\(kind) at \(bad)")
                XCTAssertEqual(ZoomPolicy.fitAll(kind, overview: overview(kind), viewport: CGSize(width: 402, height: bad)), byWidth, accuracy: 1e-9, "no height → the width alone (\(kind), \(bad))")
                XCTAssertEqual(ZoomPolicy.fitAll(kind, overview: overview(kind), viewport: CGSize(width: bad, height: 580)), readable, "no width → readable (\(kind), \(bad))")
                XCTAssertEqual(ZoomPolicy.fitAll(kind, overview: CGSize(width: bad, height: 1000), viewport: CGSize(width: 402, height: 580)), readable, "a bad overview width (\(kind), \(bad))")
                XCTAssertEqual(ZoomPolicy.fitAll(kind, overview: CGSize(width: 1400, height: bad), viewport: CGSize(width: 402, height: 580)), readable, "a bad overview height (\(kind), \(bad))")
                XCTAssertEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: bad, zoom: 0.5), 0, "\(kind) at width \(bad)")
                XCTAssertEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: 402, zoom: bad), 0, "\(kind) at zoom \(bad)")
                XCTAssertEqual(ZoomPolicy.bounds(kind, overview: overview(kind), viewport: CGSize(width: bad, height: bad)), ZoomPolicy.Bounds(fit: readable, min: readable, max: 4 * readable), "\(kind) with no viewport")
            }
        }
    }

    func testPaperViewport() {
        let v = PaperViewport(offsetX: 100, zoom: 0.5, width: 402)
        XCTAssertEqual(v.x(ofPaper: 400), 100, "lu × zoom − offsetX")
        XCTAssertEqual(v.x(ofPaper: 0), -100)
        XCTAssertEqual(v.x(ofPaper: 1400), 600)
        XCTAssertEqual(v.width(ofPaper: 200), 100, "lu × zoom")
        XCTAssertEqual(v.width(ofPaper: 0), 0)
        XCTAssertEqual(v.offsetX, 100)
        XCTAssertEqual(v.zoom, 0.5)
        XCTAssertEqual(v.width, 402)
        XCTAssertEqual(PaperViewport.zero, PaperViewport(offsetX: 0, zoom: 1, width: 0))
        XCTAssertEqual(PaperViewport.zero.x(ofPaper: 50), 50)
        XCTAssertNotEqual(v, PaperViewport.zero)
        XCTAssertEqual(v, PaperViewport(offsetX: 100, zoom: 0.5, width: 402))
        let centred = PaperViewport(offsetX: -80, zoom: 0.2417, width: 402)
        XCTAssertEqual(centred.x(ofPaper: 0), 80, "a negative offsetX (the centring margin) puts the paper's left edge at 80 pt")
        XCTAssertEqual(centred.x(ofPaper: 1000), 80 + 241.7, accuracy: 1e-9)
        // The first frame from the width alone: fitZoom (M4b: minZoom).
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: 402), PaperViewport(offsetX: 0, zoom: 402.0 / 1400, width: 402))
        XCTAssertEqual(PaperViewport.initial(.year, viewportWidth: 1024).zoom, 1024.0 / 1400, accuracy: 1e-9, "fit, not readable")
        XCTAssertEqual(PaperViewport.initial(.year, viewportWidth: 1024).width, 1024)
        XCTAssertEqual(PaperViewport.initial(.year, viewportWidth: 1024).offsetX, 0)
        XCTAssertEqual(PaperViewport.initial(.week, viewportWidth: 744).zoom, 744.0 / 1400)
        XCTAssertEqual(PaperViewport.initial(.day, viewportWidth: 402).zoom, 0.402, accuracy: 1e-9)
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: 0), PaperViewport(offsetX: 0, zoom: 0.5, width: 0))
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: .nan), PaperViewport(offsetX: 0, zoom: 0.5, width: 0), "no NaN in a viewport")
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: -3), PaperViewport(offsetX: 0, zoom: 0.5, width: 0))
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: 402).x(ofPaper: 1400), 402, "the first frame: the paper's right edge at 402 pt (M4b: 700)")
        // The first frame with the height and the overview.
        let dayFirst = PaperViewport.initial(.day, overview: overview(.day), paperSize: CGSize(width: 1000, height: 2400), viewport: CGSize(width: 402, height: 580), ratio: 1)
        XCTAssertEqual(dayFirst.zoom, 0.2417, accuracy: 1e-3)
        XCTAssertEqual(dayFirst.offsetX, -80.1, accuracy: 0.1, "centred")
        XCTAssertEqual(dayFirst.width, 402)
        XCTAssertEqual(dayFirst.x(ofPaper: 0), 80.1, accuracy: 0.1)
        let monthTwice = PaperViewport.initial(.month, overview: overview(.month), paperSize: CGSize(width: 1400, height: 1750), viewport: CGSize(width: 1024, height: 1180), ratio: 2)
        XCTAssertEqual(monthTwice.zoom, 1.4628, accuracy: 1e-3)
        XCTAssertEqual(monthTwice.offsetX, 0, "the paper is wider than the area")
        XCTAssertEqual(monthTwice.width, 1024)
        let weekFirst = PaperViewport.initial(.week, overview: overview(.week), paperSize: CGSize(width: 1400, height: 1920), viewport: CGSize(width: 1024, height: 1180), ratio: 1)
        XCTAssertEqual(weekFirst.zoom, 1180.0 / 1920, accuracy: 1e-9)
        XCTAssertEqual(weekFirst.offsetX, -81.8, accuracy: 0.1)
        let noHeight = PaperViewport.initial(.month, overview: overview(.month), paperSize: CGSize(width: 1400, height: 1750), viewport: CGSize(width: 402, height: 0), ratio: 1)
        XCTAssertEqual(noHeight.zoom, PaperViewport.initial(.month, viewportWidth: 402).zoom, "height 0 → the width alone")
        XCTAssertEqual(noHeight.offsetX, 0, accuracy: 1e-9)
        XCTAssertEqual(noHeight.width, 402)
        let noHeightDay = PaperViewport.initial(.day, overview: overview(.day), paperSize: CGSize(width: 1000, height: 2400), viewport: CGSize(width: 402, height: 0), ratio: 1)
        XCTAssertEqual(noHeightDay.zoom, 0.402, accuracy: 1e-9, "fit-to-width until the height is known")
        XCTAssertEqual(noHeightDay.offsetX, 0, accuracy: 1e-9)
        XCTAssertEqual(PaperViewport.initial(.day, overview: overview(.day), paperSize: CGSize(width: 1000, height: 2400), viewport: CGSize(width: 402, height: 580), ratio: .nan).zoom, dayFirst.zoom, accuracy: 1e-12, "ratio NaN → the overview")
        XCTAssertEqual(PaperViewport.initial(.day, overview: overview(.day), paperSize: CGSize(width: 1000, height: 2400), viewport: CGSize(width: 402, height: 580), ratio: 100).zoom, 1.608, accuracy: 1e-3, "ratio 100 → maxZoom")
        XCTAssertEqual(PaperViewport.initial(.day, overview: overview(.day), paperSize: CGSize(width: 1000, height: 2400), viewport: CGSize(width: 402, height: 580), ratio: 100).offsetX, 0)
        XCTAssertEqual(PaperViewport.initial(.month, overview: overview(.month), paperSize: CGSize(width: 1400, height: 1750), viewport: CGSize(width: CGFloat.nan, height: 580), ratio: 1), PaperViewport(offsetX: 0, zoom: 0.5, width: 0), "width NaN → (0, readable, 0)")
        XCTAssertEqual(PaperViewport.initial(.month, overview: overview(.month), paperSize: CGSize(width: 1400, height: 1750), viewport: CGSize(width: -3, height: 580), ratio: 1).width, 0)
    }
}
