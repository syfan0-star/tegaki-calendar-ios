import Foundation
import CoreGraphics

/// The lasso's mathematics (M3B_CONTRACT §2.1): a port of the pure functions of the web version's
/// js/ink/geometry.js and js/ink/surface.js. Points and rects are in paper coordinates (lu).
public enum LassoGeometry {
    /// A lasso vertex is stored only when it is at least this far from the previous one (lu).
    public static let minStep: CGFloat = 2
    /// A lasso smaller than this in both directions is a tap (lu).
    public static let minExtent: CGFloat = 4
    /// The lasso polygon is simplified this much before hit-testing (lu).
    public static let simplifyEpsilon: CGFloat = 1
    /// A lasso with more vertices than this is simplified more coarsely (ε 2, 4, 8).
    public static let maxVertices = 512
    /// Padding around the strokes of a snapshot (lu).
    public static let snapshotPadding: CGFloat = 12
    /// A tiny selection is never enlarged more than this in a snapshot.
    public static let snapshotMaxZoom: CGFloat = 4

    // MARK: Point in polygon, stroke in lasso

    /// Even-odd point-in-polygon test. Fewer than 3 vertices (or a non-finite point) → false.
    public static func pointInPolygon(_ p: CGPoint, _ polygon: [CGPoint]) -> Bool {
        let n = polygon.count
        guard n >= 3, p.x.isFinite, p.y.isFinite else { return false }
        var inside = false
        var j = n - 1
        for i in 0..<n {
            let pi = polygon[i]
            let pj = polygon[j]
            if (pi.y > p.y) != (pj.y > p.y) && p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// True when at least half of the stroke's points (`inside × 2 ≥ valid`) lie inside the polygon.
    /// Non-finite points are not counted; no (valid) point → false; fewer than 3 vertices → false.
    /// `bounds` (the polygon's bounding rect, computed once by a caller testing many strokes) skips
    /// the polygon test for points outside it. Stops as soon as the answer is certain.
    public static func strokeInLasso(points: [CGPoint], polygon: [CGPoint], bounds: CGRect? = nil) -> Bool {
        guard polygon.count >= 3, !points.isEmpty else { return false }
        let box: CGRect
        if let b = bounds, isFinite(b) {
            box = b
        } else if let b = self.bounds(of: polygon) {
            box = b
        } else {
            return false
        }
        let count = points.count
        var valid = 0
        var inside = 0
        for (i, p) in points.enumerated() {
            guard p.x.isFinite, p.y.isFinite else { continue }
            valid += 1
            if p.x >= box.minX && p.x <= box.maxX && p.y >= box.minY && p.y <= box.maxY && pointInPolygon(p, polygon) {
                inside += 1
                if inside * 2 >= count { return true } // valid ≤ count: already at least half
            } else if inside * 2 + (count - 1 - i) < valid {
                return false // even if every remaining point were inside, it would stay under half
            }
        }
        if valid == 0 { return false }
        return inside * 2 >= valid
    }

    // MARK: Lasso polygon

    /// Drops non-finite points, rejects a degenerate lasso (fewer than 3 vertices, or smaller than
    /// `minExtent` in both directions: a tap) and closes the path by repeating its first vertex at the
    /// end (web closeLassoPolygon).
    public static func closedPolygon(_ points: [CGPoint], minExtent: CGFloat = minExtent) -> [CGPoint]? {
        var poly: [CGPoint] = []
        poly.reserveCapacity(points.count + 1)
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        for p in points where p.x.isFinite && p.y.isFinite {
            poly.append(p)
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        guard poly.count >= 3 else { return nil }
        if maxX - minX < minExtent && maxY - minY < minExtent { return nil }
        if let first = poly.first, let last = poly.last, first != last {
            poly.append(first)
        }
        return poly
    }

    /// Ramer–Douglas–Peucker simplification: keeps the first and last vertex and every vertex needed
    /// so that no dropped vertex is farther than `epsilon` from the result (a closed lasso stays
    /// closed). Returns a copy of the input when it has 4 vertices or fewer, when `epsilon` is not
    /// positive, or when the result would have fewer than 4 vertices (3 + the closing one).
    public static func simplified(_ polygon: [CGPoint], epsilon: CGFloat = simplifyEpsilon) -> [CGPoint] {
        let n = polygon.count
        guard n > 4, epsilon.isFinite, epsilon > 0 else { return polygon }
        var keep = [Bool](repeating: false, count: n)
        keep[0] = true
        keep[n - 1] = true
        let eps2 = epsilon * epsilon
        var stack: [(Int, Int)] = [(0, n - 1)]
        while let (a, b) = stack.popLast() {
            if b - a < 2 { continue }
            let ax = polygon[a].x
            let ay = polygon[a].y
            let vx = polygon[b].x - ax
            let vy = polygon[b].y - ay
            let len2 = vx * vx + vy * vy
            var far = -1
            var farD2 = eps2
            for i in (a + 1)..<b {
                let wx = polygon[i].x - ax
                let wy = polygon[i].y - ay
                let t = len2 > 0 ? min(max((wx * vx + wy * vy) / len2, 0), 1) : 0
                let dx = wx - t * vx
                let dy = wy - t * vy
                let d2 = dx * dx + dy * dy
                if d2 > farD2 {
                    farD2 = d2
                    far = i
                }
            }
            if far < 0 { continue }
            keep[far] = true
            stack.append((a, far))
            stack.append((far, b))
        }
        var out: [CGPoint] = []
        out.reserveCapacity(n)
        for i in 0..<n where keep[i] { out.append(polygon[i]) }
        return out.count >= 4 ? out : polygon
    }

    /// The polygon of a finished lasso (web _endLasso): `closedPolygon` → `simplified(ε 1)`, and while
    /// it still has more than `maxVertices` vertices, ε 2, 4, 8. nil for a tap.
    public static func lassoPolygon(_ points: [CGPoint]) -> [CGPoint]? {
        guard let closed = closedPolygon(points) else { return nil }
        var poly = simplified(closed, epsilon: simplifyEpsilon)
        var eps = simplifyEpsilon * 2
        while poly.count > maxVertices && eps <= 8 {
            poly = simplified(closed, epsilon: eps)
            eps *= 2
        }
        return poly
    }

    // MARK: Rects

    /// Bounding rect of the finite points; nil when there is none.
    public static func bounds(of polygon: [CGPoint]) -> CGRect? {
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        for p in polygon where p.x.isFinite && p.y.isFinite {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        guard minX.isFinite else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The smallest rect containing every finite rect; nil when there is none (web unionBBox).
    public static func union(_ rects: [CGRect]) -> CGRect? {
        var out: CGRect?
        for r in rects where isFinite(r) {
            let s = r.standardized
            if let cur = out {
                out = CGRect(
                    x: min(cur.minX, s.minX),
                    y: min(cur.minY, s.minY),
                    width: max(cur.maxX, s.maxX) - min(cur.minX, s.minX),
                    height: max(cur.maxY, s.maxY) - min(cur.minY, s.minY)
                )
            } else {
                out = s
            }
        }
        return out
    }

    /// Limits a selection move so the selection box stays on the paper [0, W] × [0, H]. A box that
    /// already sticks out may move back inwards but not further out; the clamp never pushes it by
    /// itself (web clampMoveDelta). Non-finite deltas count as 0; a non-finite box is not clamped.
    public static func clampedMoveDelta(bbox: CGRect, dx: CGFloat, dy: CGFloat, pageSize: CGSize) -> CGVector {
        let mx = dx.isFinite ? dx : 0
        let my = dy.isFinite ? dy : 0
        guard isFinite(bbox) else { return CGVector(dx: mx, dy: my) }
        func axis(_ lo: CGFloat, _ hi: CGFloat, _ d: CGFloat, _ limit: CGFloat) -> CGFloat {
            guard limit.isFinite, limit > 0 else { return d }
            return min(max(d, min(0, -lo)), max(0, limit - hi))
        }
        return CGVector(
            dx: axis(bbox.minX, bbox.maxX, mx, pageSize.width),
            dy: axis(bbox.minY, bbox.maxY, my, pageSize.height)
        )
    }

    /// Layout of a snapshot image (web computeSnapshotLayout): `bbox` grown by `pad`, scaled to fit
    /// `maxSize` but never enlarged more than `maxZoom`. `size` = clamp(round(w × zoom), 1, maxW) ×
    /// clamp(round(h × zoom), 1, maxH). nil for a non-finite box.
    public static func snapshotLayout(bbox: CGRect, pad: CGFloat = snapshotPadding, maxSize: CGSize = CGSize(width: 480, height: 240), maxZoom: CGFloat = snapshotMaxZoom) -> (rect: CGRect, zoom: CGFloat, size: CGSize)? {
        guard isFinite(bbox) else { return nil }
        let p = pad.isFinite && pad >= 0 ? pad : snapshotPadding
        let mw = maxSize.width.isFinite && maxSize.width >= 1 ? maxSize.width.rounded(.down) : 480
        let mh = maxSize.height.isFinite && maxSize.height >= 1 ? maxSize.height.rounded(.down) : 240
        let box = bbox.standardized
        let rect = CGRect(x: box.minX - p, y: box.minY - p, width: box.width + 2 * p, height: box.height + 2 * p)
        let w = max(rect.width, 1e-6)
        let h = max(rect.height, 1e-6)
        let zoomCap = maxZoom.isFinite && maxZoom > 0 ? maxZoom : snapshotMaxZoom
        let zoom = min(mw / w, mh / h, zoomCap)
        let width = min(max((w * zoom).rounded(), 1), mw)
        let height = min(max((h * zoom).rounded(), 1), mh)
        return (rect, zoom, CGSize(width: width, height: height))
    }

    static func isFinite(_ r: CGRect) -> Bool {
        r.origin.x.isFinite && r.origin.y.isFinite && r.size.width.isFinite && r.size.height.isFinite
    }
}
