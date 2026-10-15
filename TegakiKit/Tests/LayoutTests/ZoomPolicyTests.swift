import XCTest
import Foundation
import CoreGraphics
import Layout

/// The zoom-scale limits of the four pages and the viewport the sticky header follows
/// (M4B_CONTRACT §1.1). The numbers are the table of §1.1; the same checks run in KitChecks.
final class ZoomPolicyTests: XCTestCase {
    private let readableWeek: CGFloat = 90 / (1336.0 / 7)
    private let readableDay: CGFloat = 330.0 / 588
    private let readableYear: CGFloat = 150.0 / 112

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
        XCTAssertEqual(ZoomPolicy.fitTolerance, 0.95)
    }

    func testTableOfWidths() {
        // width → minZoom of month / week / day / year (M4B_CONTRACT §1.1).
        let table: [(width: CGFloat, month: CGFloat, week: CGFloat, day: CGFloat, year: CGFloat)] = [
            (375, 0.5, readableWeek, readableDay, readableYear),
            (390, 0.5, readableWeek, readableDay, readableYear),
            (402, 0.5, readableWeek, readableDay, readableYear),
            (664, 0.5, 664.0 / 1400, 0.664, readableYear),
            (665, 0.475, 665.0 / 1400, 0.665, readableYear),
            (667, 667.0 / 1400, 667.0 / 1400, 0.667, readableYear),
            (678, 678.0 / 1400, 678.0 / 1400, 0.678, readableYear),
            (690, 690.0 / 1400, 690.0 / 1400, 0.69, readableYear),
            (744, 744.0 / 1400, 744.0 / 1400, 0.744, readableYear),
            (834, 834.0 / 1400, 834.0 / 1400, 0.834, readableYear),
            (1024, 1024.0 / 1400, 1024.0 / 1400, 1.024, readableYear),
            (1133, 1133.0 / 1400, 1133.0 / 1400, 1.133, readableYear),
            (1210, 1210.0 / 1400, 1210.0 / 1400, 1.21, readableYear),
            (1366, 1366.0 / 1400, 1366.0 / 1400, 1.366, readableYear),
        ]
        for row in table {
            let expected: [(PageKind, CGFloat)] = [(.month, row.month), (.week, row.week), (.day, row.day), (.year, row.year)]
            for (kind, minZ) in expected {
                let label = "\(kind) at \(row.width)"
                let paper = ZoomPolicy.paperWidth(kind)
                let fit = row.width / paper
                XCTAssertEqual(ZoomPolicy.fitZoom(kind, viewportWidth: row.width), fit, accuracy: 1e-9, label)
                XCTAssertEqual(ZoomPolicy.minZoom(kind, viewportWidth: row.width), minZ, accuracy: 1e-4, label)
                let maxZ = ZoomPolicy.maxZoom(kind, viewportWidth: row.width)
                XCTAssertEqual(maxZ, max(4 * fit, 2 * minZ), accuracy: 1e-4, label)
                XCTAssertGreaterThanOrEqual(ZoomPolicy.minZoom(kind, viewportWidth: row.width), fit - 1e-12, "minZoom ≥ fit: \(label)")
                XCTAssertGreaterThanOrEqual(maxZ, 2 * ZoomPolicy.minZoom(kind, viewportWidth: row.width) - 1e-12, "maxZoom ≥ 2 × min: \(label)")
                XCTAssertGreaterThanOrEqual(maxZ, 4 * fit - 1e-12, "maxZoom ≥ 4 × fit: \(label)")
                let visible = ZoomPolicy.visibleWidth(kind, viewportWidth: row.width)
                XCTAssertLessThanOrEqual(visible, paper, "visibleWidth ≤ paper: \(label)")
                XCTAssertEqual(visible, min(paper, row.width / minZ), accuracy: 0.5, "visibleWidth: \(label)")
                XCTAssertEqual(ZoomPolicy.bounds(kind, viewportWidth: row.width), ZoomPolicy.Bounds(fit: ZoomPolicy.fitZoom(kind, viewportWidth: row.width), min: ZoomPolicy.minZoom(kind, viewportWidth: row.width), max: maxZ), label)
            }
        }
    }

    func testVisibleWidths() {
        let visibleTable: [(width: CGFloat, month: CGFloat, week: CGFloat, day: CGFloat, year: CGFloat)] = [
            (402, 804, 852, 716, 300),
            (390, 780, 827, 695, 291),
            (744, 1400, 1400, 1000, 555),
            (834, 1400, 1400, 1000, 623),
            (1024, 1400, 1400, 1000, 765),
            (1366, 1400, 1400, 1000, 1020),
            (678, 1400, 1400, 1000, 506),
            (690, 1400, 1400, 1000, 515),
            (667, 1400, 1400, 1000, 498),
            (664, 1328, 1400, 1000, 496),
        ]
        for row in visibleTable {
            XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: row.width), row.month, accuracy: 1, "month at \(row.width)")
            XCTAssertEqual(ZoomPolicy.visibleWidth(.week, viewportWidth: row.width), row.week, accuracy: 1, "week at \(row.width)")
            XCTAssertEqual(ZoomPolicy.visibleWidth(.day, viewportWidth: row.width), row.day, accuracy: 1, "day at \(row.width)")
            XCTAssertEqual(ZoomPolicy.visibleWidth(.year, viewportWidth: row.width), row.year, accuracy: 1, "year at \(row.width)")
        }
        XCTAssertEqual(ZoomPolicy.visibleWidth(.month, viewportWidth: 744), 1400, "exactly the paper's width when fit is the minimum")
        XCTAssertEqual(ZoomPolicy.visibleWidth(.day, viewportWidth: 1024), 1000)
    }

    func testBoundaryAndMaxZoom() {
        XCTAssertGreaterThan(ZoomPolicy.minZoom(.month, viewportWidth: 664), ZoomPolicy.fitZoom(.month, viewportWidth: 664), "1 pt below the 5 % boundary: readable wins")
        XCTAssertEqual(ZoomPolicy.minZoom(.month, viewportWidth: 664), 0.5)
        XCTAssertEqual(ZoomPolicy.minZoom(.month, viewportWidth: 665), ZoomPolicy.fitZoom(.month, viewportWidth: 665), "the exact boundary keeps fit")
        XCTAssertEqual(ZoomPolicy.minZoom(.month, viewportWidth: 665), 0.475, accuracy: 1e-9)
        XCTAssertEqual(ZoomPolicy.minZoom(.week, viewportWidth: 744), ZoomPolicy.fitZoom(.week, viewportWidth: 744), "iPad mini: fit")
        XCTAssertEqual(ZoomPolicy.maxZoom(.month, viewportWidth: 402), 1.1486, accuracy: 1e-3, "iPhone month: 4 × fit")
        XCTAssertEqual(ZoomPolicy.maxZoom(.year, viewportWidth: 402), 2.6786, accuracy: 1e-3, "iPhone year: 2 × min")
        XCTAssertEqual(ZoomPolicy.maxZoom(.year, viewportWidth: 1024), 2.9257, accuracy: 1e-3, "13 inch year: 4 × fit")
        XCTAssertEqual(ZoomPolicy.maxZoom(.day, viewportWidth: 402), 1.608, accuracy: 1e-3)
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
        let iphoneMonth = ZoomPolicy.bounds(.month, viewportWidth: 402)
        XCTAssertEqual(iphoneMonth.clamped(0.2), 0.5, "a pinch below minZoom clamps to 0.5")
        XCTAssertEqual(iphoneMonth.clamped(3), iphoneMonth.max, accuracy: 1e-9)
    }

    func testUnusableWidths() {
        for kind in PageKind.allCases {
            let readable = ZoomPolicy.readableZoom(kind)
            for bad in [CGFloat.nan, 0, -1, .infinity, -.infinity] {
                XCTAssertEqual(ZoomPolicy.fitZoom(kind, viewportWidth: bad), readable, "\(kind) at \(bad)")
                XCTAssertEqual(ZoomPolicy.minZoom(kind, viewportWidth: bad), readable, "\(kind) at \(bad)")
                XCTAssertEqual(ZoomPolicy.maxZoom(kind, viewportWidth: bad), 4 * readable, "\(kind) at \(bad)")
                XCTAssertEqual(ZoomPolicy.visibleWidth(kind, viewportWidth: bad), 0, "\(kind) at \(bad)")
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
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: 402), PaperViewport(offsetX: 0, zoom: 0.5, width: 402))
        XCTAssertEqual(PaperViewport.initial(.year, viewportWidth: 1024).zoom, readableYear, accuracy: 1e-9)
        XCTAssertEqual(PaperViewport.initial(.year, viewportWidth: 1024).width, 1024)
        XCTAssertEqual(PaperViewport.initial(.year, viewportWidth: 1024).offsetX, 0)
        XCTAssertEqual(PaperViewport.initial(.week, viewportWidth: 744).zoom, 744.0 / 1400)
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: 0), PaperViewport(offsetX: 0, zoom: 0.5, width: 0))
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: .nan), PaperViewport(offsetX: 0, zoom: 0.5, width: 0), "no NaN in a viewport")
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: -3), PaperViewport(offsetX: 0, zoom: 0.5, width: 0))
        XCTAssertEqual(PaperViewport.initial(.month, viewportWidth: 402).x(ofPaper: 1400), 700, "the first frame: the paper's right edge at 700 pt")
    }
}
