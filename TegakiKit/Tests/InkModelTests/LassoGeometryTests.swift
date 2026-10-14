import XCTest
import Foundation
import CoreGraphics
import InkModel

/// The lasso's mathematics (M3B_CONTRACT §2.1 / §6.1). The expectations are the web version's
/// tests/ink-geometry.test.mjs and tests/surface.test.mjs. The same checks run in KitChecks.
final class LassoGeometryTests: XCTestCase {
    /// A point list from flat [x0, y0, x1, y1, …] (the web tests' polygon format).
    private func pts(_ v: [CGFloat]) -> [CGPoint] {
        stride(from: 0, to: v.count - 1, by: 2).map { CGPoint(x: v[$0], y: v[$0 + 1]) }
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// Deterministic xorshift64* generator.
    private struct Rng {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2_685_821_657_736_338_717
        }
        mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
        mutating func double() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    }

    private func assertRect(_ actual: CGRect?, _ expected: CGRect, _ message: String = "", tolerance: CGFloat = 1e-6, file: StaticString = #filePath, line: UInt = #line) {
        guard let a = actual else {
            XCTFail("\(message): nil, expected \(expected)", file: file, line: line)
            return
        }
        XCTAssertEqual(a.minX, expected.minX, accuracy: tolerance, "\(message): minX", file: file, line: line)
        XCTAssertEqual(a.minY, expected.minY, accuracy: tolerance, "\(message): minY", file: file, line: line)
        XCTAssertEqual(a.width, expected.width, accuracy: tolerance, "\(message): width", file: file, line: line)
        XCTAssertEqual(a.height, expected.height, accuracy: tolerance, "\(message): height", file: file, line: line)
    }

    /// A hand-drawn circle of radius `r` around `center`: one vertex every ~2 lu, as the lasso stores them.
    private func circle(center: CGPoint, radius r: CGFloat, step: CGFloat = 2) -> [CGPoint] {
        let n = Int(ceil(2 * CGFloat.pi * r / step))
        return (0..<n).map { i in
            let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n)
            return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
        }
    }

    private func segmentDistance(_ q: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let vx = b.x - a.x
        let vy = b.y - a.y
        let len2 = vx * vx + vy * vy
        let t = len2 > 0 ? min(max(((q.x - a.x) * vx + (q.y - a.y) * vy) / len2, 0), 1) : 0
        return hypot(q.x - a.x - t * vx, q.y - a.y - t * vy)
    }

    func testConstants() {
        XCTAssertEqual(LassoGeometry.minStep, 2)
        XCTAssertEqual(LassoGeometry.minExtent, 4)
        XCTAssertEqual(LassoGeometry.simplifyEpsilon, 1)
        XCTAssertEqual(LassoGeometry.maxVertices, 512)
        XCTAssertEqual(LassoGeometry.snapshotPadding, 12)
        XCTAssertEqual(LassoGeometry.snapshotMaxZoom, 4)
    }

    func testPointInPolygon() {
        let square = pts([0, 0, 10, 0, 10, 10, 0, 10])
        XCTAssertTrue(LassoGeometry.pointInPolygon(p(5, 5), square))
        XCTAssertFalse(LassoGeometry.pointInPolygon(p(15, 5), square))
        XCTAssertFalse(LassoGeometry.pointInPolygon(p(-1, -1), square))
        let concave = pts([0, 0, 10, 0, 10, 10, 5, 3, 0, 10]) // a notch from the bottom
        XCTAssertFalse(LassoGeometry.pointInPolygon(p(5, 8), concave), "in the notch")
        XCTAssertTrue(LassoGeometry.pointInPolygon(p(5, 1), concave))
        var star: [CGPoint] = [] // a self-intersecting five-pointed star
        for i in 0..<5 {
            let a = CGFloat(i) * 4 * .pi / 5 - .pi / 2
            star.append(CGPoint(x: cos(a) * 10, y: sin(a) * 10))
        }
        XCTAssertFalse(LassoGeometry.pointInPolygon(p(0, 0), star), "the centre is outside under even-odd")
        XCTAssertTrue(LassoGeometry.pointInPolygon(p(0, -8), star), "a tip is inside")
        XCTAssertFalse(LassoGeometry.pointInPolygon(p(1, 1), pts([0, 0, 5, 5])), "2 vertices")
        XCTAssertFalse(LassoGeometry.pointInPolygon(p(1, 1), []), "empty")
        XCTAssertFalse(LassoGeometry.pointInPolygon(CGPoint(x: CGFloat.nan, y: 1), square), "a NaN point")
    }

    func testStrokeInLasso() {
        let lasso = pts([0, 0, 100, 0, 100, 100, 0, 100])
        XCTAssertTrue(LassoGeometry.strokeInLasso(points: pts([10, 10, 20, 20, 200, 200, 300, 300]), polygon: lasso), "2 of 4 inside")
        XCTAssertFalse(LassoGeometry.strokeInLasso(points: pts([10, 10, 200, 20, 200, 200]), polygon: lasso), "1 of 3 inside")
        XCTAssertTrue(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: lasso), "one point inside")
        XCTAssertFalse(LassoGeometry.strokeInLasso(points: pts([150, 50]), polygon: lasso), "one point outside")
        XCTAssertFalse(LassoGeometry.strokeInLasso(points: [], polygon: lasso), "no points")
        XCTAssertFalse(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: pts([0, 0, 1, 1])), "a degenerate lasso")
        XCTAssertTrue(LassoGeometry.strokeInLasso(points: [p(50, 50), CGPoint(x: CGFloat.nan, y: 0), p(500, 500)], polygon: lasso), "non-finite points are not counted")
        XCTAssertFalse(LassoGeometry.strokeInLasso(points: [CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity)], polygon: lasso), "only non-finite points")
        XCTAssertTrue(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: lasso, bounds: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)), "a non-finite bounds is ignored")
        XCTAssertTrue(LassoGeometry.strokeInLasso(points: pts([50, 50]), polygon: lasso, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)))
        XCTAssertFalse(LassoGeometry.strokeInLasso(points: pts([50, 50, 150, 50, 250, 50]), polygon: lasso, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)), "1 of 3 with bounds")
    }

    func testStrokeInLassoRandomizedAgainstCounting() {
        // Precomputed bounds and the early exits give the same answer as counting every point.
        var rng = Rng(seed: 42)
        for k in 0..<200 {
            var poly: [CGPoint] = []
            let n = 3 + rng.int(12)
            for i in 0..<n {
                let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n)
                let radius = 20 + CGFloat(rng.double()) * 80
                poly.append(CGPoint(x: 100 + radius * cos(a), y: 100 + radius * sin(a)))
            }
            var points: [CGPoint] = []
            let m = 1 + rng.int(20)
            for _ in 0..<m {
                let x: CGFloat = rng.double() < 0.05 ? CGFloat.nan : CGFloat(rng.double()) * 220 - 10
                points.append(CGPoint(x: x, y: CGFloat(rng.double()) * 220 - 10))
            }
            var valid = 0
            var inside = 0
            for q in points where q.x.isFinite && q.y.isFinite {
                valid += 1
                if LassoGeometry.pointInPolygon(q, poly) { inside += 1 }
            }
            let want = valid > 0 && inside * 2 >= valid
            XCTAssertEqual(LassoGeometry.strokeInLasso(points: points, polygon: poly), want, "case \(k)")
            XCTAssertEqual(LassoGeometry.strokeInLasso(points: points, polygon: poly, bounds: LassoGeometry.bounds(of: poly)), want, "case \(k) with bounds")
        }
    }

    func testClosedPolygon() {
        XCTAssertEqual(LassoGeometry.closedPolygon(pts([0, 0, 10, 0, 10, 10])), pts([0, 0, 10, 0, 10, 10, 0, 0]), "closes the path")
        XCTAssertEqual(LassoGeometry.closedPolygon(pts([0, 0, 10, 0, 10, 10, 0, 0])), pts([0, 0, 10, 0, 10, 10, 0, 0]), "already closed")
        XCTAssertNil(LassoGeometry.closedPolygon(pts([0, 0, 1, 1])), "2 vertices")
        XCTAssertNil(LassoGeometry.closedPolygon(pts([0, 0, 1, 1, 2, 0])), "smaller than 4 lu in both directions → a tap")
        XCTAssertEqual(LassoGeometry.closedPolygon(pts([0, 0, 5, 0, 5, 1])), pts([0, 0, 5, 0, 5, 1, 0, 0]), "4 lu in one direction is enough")
        XCTAssertEqual(LassoGeometry.closedPolygon(pts([0, 0, 3, 0, 3, 3]), minExtent: 2), pts([0, 0, 3, 0, 3, 3, 0, 0]), "a custom minExtent")
        XCTAssertEqual(LassoGeometry.closedPolygon([CGPoint(x: CGFloat.nan, y: 0), p(0, 0), p(10, 0), p(10, 10)]), pts([0, 0, 10, 0, 10, 10, 0, 0]), "non-finite points are dropped")
        XCTAssertNil(LassoGeometry.closedPolygon([]), "empty")
    }

    func testSimplified() {
        let closed = LassoGeometry.closedPolygon(circle(center: p(700, 900), radius: 500))!
        XCTAssertEqual(closed.count, Int(ceil(2 * CGFloat.pi * 500 / 2)) + 1)
        let simple = LassoGeometry.simplified(closed, epsilon: 1)
        XCTAssertLessThan(simple.count, 120, "\(simple.count) vertices")
        XCTAssertGreaterThanOrEqual(simple.count, 8)
        XCTAssertEqual(simple.first, closed.first, "the first vertex is kept")
        XCTAssertEqual(simple.last, closed.last, "the last vertex is kept (still closed)")
        // Every dropped vertex is within epsilon of the simplified outline.
        var worst: CGFloat = 0
        for q in closed {
            var best = CGFloat.infinity
            for j in 1..<simple.count { best = min(best, segmentDistance(q, simple[j - 1], simple[j])) }
            worst = max(worst, best)
        }
        XCTAssertLessThanOrEqual(worst, 1 + 1e-9, "worst \(worst) lu")
        // Small or unsimplifiable inputs come back unchanged.
        let square = pts([0, 0, 10, 0, 10, 10, 0, 10, 0, 0])
        XCTAssertEqual(LassoGeometry.simplified(square, epsilon: 1), square, "a square (5 vertices)")
        let sliver = pts([0, 0, 50, 0.2, 100, 0, 50, -0.2, 0, 0, 0.1, 0])
        XCTAssertEqual(LassoGeometry.simplified(sliver, epsilon: 1), sliver, "would collapse below 3 vertices")
        XCTAssertEqual(LassoGeometry.simplified([], epsilon: 1), [])
        XCTAssertEqual(LassoGeometry.simplified(closed, epsilon: 0), closed, "ε 0")
        XCTAssertEqual(LassoGeometry.simplified(closed, epsilon: CGFloat.nan), closed, "ε NaN")
        XCTAssertLessThan(LassoGeometry.simplified(closed, epsilon: 4).count, simple.count, "a larger ε drops more")
    }

    func testLassoPolygon() {
        let drawn = circle(center: p(700, 900), radius: 500)
        let closed = LassoGeometry.closedPolygon(drawn)!
        XCTAssertEqual(LassoGeometry.lassoPolygon(drawn), LassoGeometry.simplified(closed, epsilon: 1), "closedPolygon → simplified(ε 1)")
        XCTAssertNil(LassoGeometry.lassoPolygon(pts([0, 0, 1, 1, 2, 0])), "a tap")
        XCTAssertNil(LassoGeometry.lassoPolygon([]), "nothing")
        XCTAssertEqual(LassoGeometry.lassoPolygon(pts([0, 0, 10, 0, 10, 10])), pts([0, 0, 10, 0, 10, 10, 0, 0]), "a triangle")
        // A very wiggly lasso (4000 vertices jittering ±1.5 lu) is simplified more coarsely (ε 2, 4, 8) until it has ≤ 512 vertices.
        var wiggly: [CGPoint] = []
        for i in 0..<4000 {
            let a = 2 * CGFloat.pi * CGFloat(i) / 4000
            let radius: CGFloat = i % 2 == 0 ? 601.5 : 598.5
            wiggly.append(CGPoint(x: 700 + radius * cos(a), y: 900 + radius * sin(a)))
        }
        let wigglyClosed = LassoGeometry.closedPolygon(wiggly)!
        XCTAssertGreaterThan(LassoGeometry.simplified(wigglyClosed, epsilon: 1).count, 512, "ε 1 keeps the jitter")
        let coarse = LassoGeometry.lassoPolygon(wiggly)!
        XCTAssertLessThanOrEqual(coarse.count, 512, "\(coarse.count) vertices")
        XCTAssertEqual(coarse.first, coarse.last, "still closed")
        var expected = LassoGeometry.simplified(wigglyClosed, epsilon: 1)
        var eps: CGFloat = 2
        while expected.count > LassoGeometry.maxVertices && eps <= 8 {
            expected = LassoGeometry.simplified(wigglyClosed, epsilon: eps)
            eps *= 2
        }
        XCTAssertGreaterThan(eps, 2, "a coarser ε was needed")
        XCTAssertEqual(coarse, expected, "the first of ε 2, 4, 8 that fits")
        XCTAssertTrue(LassoGeometry.strokeInLasso(points: pts([700, 900, 710, 910]), polygon: coarse), "the centre is still inside")
    }

    func testBoundsAndUnion() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        XCTAssertNil(LassoGeometry.union([]))
        XCTAssertNil(LassoGeometry.union([CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)]), "non-finite rects are ignored")
        XCTAssertEqual(LassoGeometry.union([a, CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), CGRect(x: -5, y: 3, width: 9, height: 17)]), CGRect(x: -5, y: 0, width: 15, height: 20))
        XCTAssertEqual(LassoGeometry.union([a]), a)
        XCTAssertEqual(LassoGeometry.union([CGRect(x: 10, y: 10, width: -10, height: -10)]), a, "a negative size is standardized")
        XCTAssertEqual(LassoGeometry.bounds(of: pts([0, 0, 10, 0, 10, 10, 0, 10])), a)
        XCTAssertEqual(LassoGeometry.bounds(of: [p(3, 4)]), CGRect(x: 3, y: 4, width: 0, height: 0), "one point")
        XCTAssertEqual(LassoGeometry.bounds(of: [p(3, 4), CGPoint(x: CGFloat.nan, y: 0), p(-1, 8)]), CGRect(x: -1, y: 4, width: 4, height: 4), "non-finite points are skipped")
        XCTAssertNil(LassoGeometry.bounds(of: []))
        XCTAssertNil(LassoGeometry.bounds(of: [CGPoint(x: CGFloat.nan, y: 4)]))
    }

    func testClampedMoveDelta() {
        let page = CGSize(width: 1400, height: 1920)
        let box = CGRect(x: 100, y: 100, width: 100, height: 50)
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: 50, dy: -20, pageSize: page), CGVector(dx: 50, dy: -20), "a move that stays on the paper")
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: -500, dy: 5000, pageSize: page), CGVector(dx: -100, dy: 1770), "clamped to the edges")
        let out = CGRect(x: -3, y: 10, width: 53, height: 10) // already sticking out on the left
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: out, dx: 0, dy: 0, pageSize: page), CGVector(dx: 0, dy: 0), "never pushes a box in")
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: out, dx: -10, dy: 0, pageSize: page), CGVector(dx: 0, dy: 0), "may not go further out")
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: out, dx: 10, dy: 0, pageSize: page), CGVector(dx: 10, dy: 0), "may come back in")
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), dx: 3, dy: 4, pageSize: page), CGVector(dx: 3, dy: 4), "a non-finite box is not clamped")
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: CGFloat.nan, dy: 4, pageSize: page), CGVector(dx: 0, dy: 4), "a NaN delta counts as 0")
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: box, dx: 5000, dy: 5000, pageSize: CGSize(width: 0, height: 0)), CGVector(dx: 5000, dy: 5000), "an empty page does not clamp")
    }

    func testSnapshotLayout() {
        let l = LassoGeometry.snapshotLayout(bbox: CGRect(x: 100, y: 100, width: 376, height: 36))
        XCTAssertNotNil(l)
        if let l = l {
            assertRect(l.rect, CGRect(x: 88, y: 88, width: 400, height: 60), "padded by 12 lu")
            XCTAssertEqual(l.zoom, 1.2, accuracy: 1e-9)
            XCTAssertEqual(l.size, CGSize(width: 480, height: 72))
        }
        let tiny = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 2, height: 2))
        XCTAssertEqual(tiny?.zoom, 4, "never enlarged more than 4×")
        XCTAssertEqual(tiny?.size, CGSize(width: 104, height: 104))
        let tall = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 100, height: 2000))
        XCTAssertEqual(tall?.size.height, 240, "a tall box uses the full height")
        XCTAssertGreaterThanOrEqual(tall?.size.width ?? 0, 1)
        XCTAssertNil(LassoGeometry.snapshotLayout(bbox: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)), "a non-finite box")
        let custom = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 100, height: 100), pad: 0, maxSize: CGSize(width: 50, height: 50))
        XCTAssertEqual(custom?.zoom, 0.5)
        XCTAssertEqual(custom?.size, CGSize(width: 50, height: 50))
        let capped = LassoGeometry.snapshotLayout(bbox: CGRect(x: 0, y: 0, width: 10, height: 10), pad: 0, maxSize: CGSize(width: 50, height: 50), maxZoom: 2)
        XCTAssertEqual(capped?.zoom, 2, "a custom zoom cap")
        XCTAssertEqual(capped?.size, CGSize(width: 20, height: 20))
    }
}

/// `InkStroke` in paper coordinates (M3B_CONTRACT §2.2): the lasso test's points, the selection's
/// bounding box, and the moved copy.
final class InkStrokePaperGeometryTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5, force: Double = 0.5) -> InkPoint {
        InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: CGFloat(force), azimuth: 1.5708, altitude: 0.7854)
    }

    private func stroke(_ id: String, cell: CellKey? = nil, tool: InkTool = .pen, color: String = "#1f2937", t: Int = 1_760_150_400_123, dev: String? = "ipad-1", points: [InkPoint]? = nil) -> InkStroke {
        InkStroke(id: id, cell: cell ?? .day(day(2026, 10, 4)), tool: tool, color: color, t: t, dev: dev, points: points ?? [point(10, 20), point(30.06, 40.04, dt: 16), point(50, 90, dt: 32)])
    }

    private func assertRect(_ actual: CGRect?, _ expected: CGRect, _ message: String = "", tolerance: CGFloat = 1e-6, file: StaticString = #filePath, line: UInt = #line) {
        guard let a = actual else {
            XCTFail("\(message): nil, expected \(expected)", file: file, line: line)
            return
        }
        XCTAssertEqual(a.minX, expected.minX, accuracy: tolerance, "\(message): minX", file: file, line: line)
        XCTAssertEqual(a.minY, expected.minY, accuracy: tolerance, "\(message): minY", file: file, line: line)
        XCTAssertEqual(a.width, expected.width, accuracy: tolerance, "\(message): width", file: file, line: line)
        XCTAssertEqual(a.height, expected.height, accuracy: tolerance, "\(message): height", file: file, line: line)
    }

    func testPaperPoints() {
        let s = stroke("s1") // (10, 20), (30.1, 40), (50, 90)
        let pp = s.paperPoints(cellOrigin: CGPoint(x: 200, y: 350))
        XCTAssertEqual(pp.count, 3)
        XCTAssertEqual(pp[0], CGPoint(x: 210, y: 370))
        XCTAssertEqual(pp[1].x, 230.1, accuracy: 1e-9)
        XCTAssertEqual(pp[1].y, 390, accuracy: 1e-9)
        XCTAssertEqual(pp[2], CGPoint(x: 250, y: 440))
        XCTAssertEqual(s.paperPoints(cellOrigin: .zero).map(\.x), s.points.map(\.x), "at the origin the paper points are the cell points")
        XCTAssertEqual(stroke("e", points: []).paperPoints(cellOrigin: CGPoint(x: 200, y: 350)), [], "no points")
    }

    func testPaperBounds() {
        let s = stroke("s1") // nib 3.5 → half 1.75
        assertRect(s.paperBounds(cellOrigin: CGPoint(x: 200, y: 350)), CGRect(x: 208.25, y: 368.25, width: 43.5, height: 73.5), "the points grown by half the nib")
        assertRect(s.paperBounds(cellOrigin: .zero), CGRect(x: 8.25, y: 18.25, width: 43.5, height: 73.5))
        let marker = stroke("m", tool: .marker, points: [point(0, 0, size: 18), point(100, 0, size: 18)])
        assertRect(marker.paperBounds(cellOrigin: CGPoint(x: 200, y: 350)), CGRect(x: 191, y: 341, width: 118, height: 18), "a marker's 18 lu nib")
        let mixed = stroke("x", points: [point(0, 0, size: 2), point(10, 10, size: 6)])
        assertRect(mixed.paperBounds(cellOrigin: .zero), CGRect(x: -3, y: -3, width: 16, height: 16), "the largest nib of the stroke")
        let dot = stroke("d", points: [point(5, 5, size: 2)])
        assertRect(dot.paperBounds(cellOrigin: .zero), CGRect(x: 4, y: 4, width: 2, height: 2), "a dot is the nib's square")
        XCTAssertNil(stroke("e", points: []).paperBounds(cellOrigin: .zero), "no points")
        // The bounds contain every paper point, and the union of several strokes contains each.
        let origin = CGPoint(x: 400, y: 525)
        let b = s.paperBounds(cellOrigin: origin)!
        for q in s.paperPoints(cellOrigin: origin) {
            XCTAssertTrue(b.contains(q))
        }
        let u = LassoGeometry.union([s.paperBounds(cellOrigin: origin)!, marker.paperBounds(cellOrigin: origin)!])!
        XCTAssertTrue(u.contains(b) && u.contains(marker.paperBounds(cellOrigin: origin)!))
    }

    func testTranslated() {
        let s = stroke("s1")
        let origin = CGPoint(x: 200, y: 350)
        let newOrigin = CGPoint(x: 400, y: 350)
        let moved = s.translated(by: CGVector(dx: 250, dy: 10), from: origin, to: .day(day(2026, 10, 5)), newCellOrigin: newOrigin, at: 1_760_200_000_000)
        XCTAssertNotEqual(moved.id, s.id, "a new id")
        XCTAssertTrue(InkStroke.isValidId(moved.id))
        XCTAssertEqual(moved.cell, .day(day(2026, 10, 5)), "the new cell")
        XCTAssertEqual(moved.t, 1_760_200_000_000, "t = at")
        XCTAssertEqual(moved.dev, "ipad-1", "dev is kept")
        XCTAssertEqual(moved.tool, s.tool)
        XCTAssertEqual(moved.color, s.color)
        XCTAssertEqual(moved.points.map(\.x), [60, 80.1, 100], "x relative to the new cell (250 − 200 = +50)")
        XCTAssertEqual(moved.points.map(\.y), [30, 50, 100], "y (+10)")
        XCTAssertEqual(moved.points.map(\.dtMs), s.points.map(\.dtMs), "dt is kept")
        XCTAssertEqual(moved.points.map(\.sizeW), s.points.map(\.sizeW), "nib is kept")
        XCTAssertEqual(moved.points.map(\.force), s.points.map(\.force), "force is kept")
        XCTAssertEqual(moved.points.map(\.azimuth), s.points.map(\.azimuth))
        let before = s.paperPoints(cellOrigin: origin)
        let after = moved.paperPoints(cellOrigin: newOrigin)
        for (b, a) in zip(before, after) {
            XCTAssertEqual(a.x - b.x, 250, accuracy: 0.051, "paper x moved by dx")
            XCTAssertEqual(a.y - b.y, 10, accuracy: 0.051, "paper y moved by dy")
        }
        XCTAssertEqual(s.points.map(\.x), [10, 30.1, 50], "the original is untouched")
        let named = s.translated(by: .zero, from: origin, to: s.cell, newCellOrigin: origin, id: "clone-1", at: 5)
        XCTAssertEqual(named.id, "clone-1", "an explicit id")
        XCTAssertEqual(named.points, s.points, "zero delta, same cell → the same points")
        XCTAssertEqual(named.t, 5)
        let fine = s.translated(by: CGVector(dx: 0.04, dy: 0.06), from: origin, to: s.cell, newCellOrigin: origin, at: 5)
        XCTAssertEqual(fine.points.map(\.x), [10, 30.1, 50], "0.04 rounds away (0.1 lu grid)")
        XCTAssertEqual(fine.points.map(\.y), [20.1, 40.1, 90.1], "0.06 rounds up")
        // Moving into a cell whose origin is beyond the points gives negative cell coordinates (allowed).
        let back = moved.translated(by: CGVector(dx: -250, dy: -10), from: newOrigin, to: s.cell, newCellOrigin: origin, at: 6)
        XCTAssertEqual(back.points.map(\.x), s.points.map(\.x), "moving back restores the points")
        XCTAssertEqual(back.points.map(\.y), s.points.map(\.y))
        let far = s.translated(by: .zero, from: origin, to: .memo, newCellOrigin: CGPoint(x: 1000, y: 1000), at: 6)
        XCTAssertEqual(far.points.map(\.x), [-790, -769.9, -750])
        XCTAssertEqual(far.cell, .memo)
    }
}
