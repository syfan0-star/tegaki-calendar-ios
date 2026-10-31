import Foundation
import CoreGraphics

/// One control point of a stroke: every attribute of a `PKStrokePoint` (DESIGN §3.9).
/// Values are rounded on construction (x, y to 0.1 lu; size / opacity / force to 0.01;
/// azimuth / altitude to 0.001 rad), so equal points compare equal and JSON stays compact.
public struct InkPointV10: Hashable, Codable, Sendable {
    /// Cell-relative position (paper point − the cell's top-left corner), lu.
    public var x: CGFloat
    public var y: CGFloat
    /// Milliseconds since the stroke started.
    public var dtMs: Int
    public var sizeW: CGFloat
    public var sizeH: CGFloat
    public var opacity: CGFloat
    public var force: CGFloat
    /// Radians.
    public var azimuth: CGFloat
    public var altitude: CGFloat

    /// Numbers per point in the flat `pts` array.
    public static let valuesPerPoint = 9
    /// Coordinates beyond this are garbage (pages are a few thousand lu).
    public static let maxCoordinate: CGFloat = 100_000

    public init(x: CGFloat, y: CGFloat, dtMs: Int, sizeW: CGFloat, sizeH: CGFloat, opacity: CGFloat, force: CGFloat, azimuth: CGFloat, altitude: CGFloat) {
        self.x = InkPointV10.round1(x)
        self.y = InkPointV10.round1(y)
        self.dtMs = dtMs
        self.sizeW = InkPointV10.round2(sizeW)
        self.sizeH = InkPointV10.round2(sizeH)
        self.opacity = InkPointV10.round2(opacity)
        self.force = InkPointV10.round2(force)
        self.azimuth = InkPointV10.round3(azimuth)
        self.altitude = InkPointV10.round3(altitude)
    }

    /// Builds a point from 9 consecutive numbers of a flat `pts` array; nil when the position is
    /// missing, non-finite or absurd (such a point is dropped, DESIGN §3.9 "壊れた線は捨てる").
    public init?(values: ArraySlice<Double>) {
        guard values.count >= InkPointV10.valuesPerPoint else { return nil }
        let v = Array(values.prefix(InkPointV10.valuesPerPoint))
        guard v[0].isFinite, v[1].isFinite, abs(v[0]) <= Double(InkPointV10.maxCoordinate), abs(v[1]) <= Double(InkPointV10.maxCoordinate) else { return nil }
        let dt = v[2].isFinite && abs(v[2]) < 1e15 ? Int(v[2].rounded()) : 0
        self.init(
            x: CGFloat(v[0]), y: CGFloat(v[1]), dtMs: dt,
            sizeW: CGFloat(v[3]), sizeH: CGFloat(v[4]), opacity: CGFloat(v[5]), force: CGFloat(v[6]),
            azimuth: CGFloat(v[7]), altitude: CGFloat(v[8])
        )
    }

    /// The 9 numbers of the point, in the order of the flat `pts` array.
    public var values: [Double] {
        [Double(x), Double(y), Double(dtMs), Double(sizeW), Double(sizeH), Double(opacity), Double(force), Double(azimuth), Double(altitude)]
    }

    /// Parses a flat `pts` array (a trailing partial point is ignored, bad points are dropped).
    public static func points(fromFlat flat: [Double], limit: Int = InkStrokeV10.maxPoints) -> [InkPointV10] {
        var out: [InkPointV10] = []
        var i = 0
        while i + valuesPerPoint <= flat.count && out.count < limit {
            if let p = InkPointV10(values: flat[i..<(i + valuesPerPoint)]) { out.append(p) }
            i += valuesPerPoint
        }
        return out
    }

    public static func flat(_ points: [InkPointV10]) -> [Double] {
        var out: [Double] = []
        out.reserveCapacity(points.count * valuesPerPoint)
        for p in points { out.append(contentsOf: p.values) }
        return out
    }

    static func round1(_ v: CGFloat) -> CGFloat { v.isFinite ? ((v * 10).rounded() / 10) + 0 : 0 }
    static func round2(_ v: CGFloat) -> CGFloat { v.isFinite ? ((v * 100).rounded() / 100) + 0 : 0 }
    static func round3(_ v: CGFloat) -> CGFloat { v.isFinite ? ((v * 1000).rounded() / 1000) + 0 : 0 }
}

/// Ink kinds of the first version. A stroke whose `tool` is some other string is kept as raw JSON in
/// `InkPageV10.unknownStrokes` (written back, not drawn).
public enum InkToolV10: String, Codable, Sendable, CaseIterable {
    case pen
    case marker

    public var defaultColor: String {
        switch self {
        case .pen: return "#1f2937"
        case .marker: return "#fde047"
        }
    }
}

/// One stroke of the ledger (DESIGN §3.4 / §3.9). Strokes are immutable values identified by `id`.
public struct InkStrokeV10: Hashable, Codable, Sendable, Identifiable {
    public static let maxPoints = 20_000
    public static let maxIdLength = 128

    /// UUID string (a web import keeps the web id).
    public var id: String
    /// The cell the stroke belongs to (the cell under the centre of its bounding box).
    public var cell: CellKeyV10
    public var tool: InkToolV10
    /// "#rrggbb", lower case.
    public var color: String
    /// Time the stroke was written, ms since the epoch.
    public var t: Int
    /// Device id, if known.
    public var dev: String?
    /// Control points, cell-relative.
    public var points: [InkPointV10]

    /// `PKStrokePath.creationDate` to use when the stroke is rebuilt (derived from `t`).
    public var inkStart: Date {
        Date(timeIntervalSince1970: Double(t) / 1000)
    }

    public init(id: String = InkStrokeV10.newId(), cell: CellKeyV10, tool: InkToolV10, color: String, t: Int, dev: String? = nil, points: [InkPointV10]) {
        self.id = id
        self.cell = cell
        self.tool = tool
        self.color = InkStrokeV10.normalizeColor(color) ?? tool.defaultColor
        self.t = max(0, t)
        self.dev = dev
        self.points = Array(points.prefix(InkStrokeV10.maxPoints))
    }

    /// A fresh lower-case UUID.
    public static func newId() -> String {
        UUID().uuidString.lowercased()
    }

    /// Ids are JSON object keys: non-empty and at most 128 characters.
    public static func isValidId(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= maxIdLength
    }

    /// "#rgb" / "#rrggbb" (any case) → "#rrggbb" lower case; nil for anything else.
    public static func normalizeColor(_ color: String) -> String? {
        let c = color.lowercased()
        let scalars = Array(c.unicodeScalars)
        guard scalars.first == "#" else { return nil }
        let hex = scalars.dropFirst()
        guard hex.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) }) else { return nil }
        if hex.count == 6 { return c }
        if hex.count == 3 {
            var out = "#"
            for s in hex {
                out.unicodeScalars.append(s)
                out.unicodeScalars.append(s)
            }
            return out
        }
        return nil
    }

    // MARK: - JSON (DESIGN §3.9)

    /// `{ "id", "cell", "tool", "color", "t", "dev"?, "pts": [9 numbers per point] }`.
    public var jsonValue: JSONValueV10 {
        var obj: [String: JSONValueV10] = [
            "id": .string(id),
            "cell": .string(cell.raw),
            "tool": .string(tool.rawValue),
            "color": .string(color),
            "t": .number(Double(t)),
            "pts": .array(InkPointV10.flat(points).map { .number($0) }),
        ]
        if let dev = dev { obj["dev"] = .string(dev) }
        return .object(obj)
    }

    /// Tolerant parse of one stroke. nil when the stroke is unusable: no valid id (and no usable
    /// `fallbackId`, the key it was stored under), no cell, a missing or unknown tool, or no usable point.
    public init?(json: JSONValueV10, fallbackId: String? = nil) {
        guard let obj = json.objectValue else { return nil }
        let storedId = obj["id"]?.stringValue
        let id: String
        if let s = storedId, InkStrokeV10.isValidId(s) {
            id = s
        } else if let f = fallbackId, InkStrokeV10.isValidId(f) {
            id = f
        } else {
            return nil
        }
        guard let cellRaw = obj["cell"]?.stringValue, !cellRaw.isEmpty else { return nil }
        guard let toolName = obj["tool"]?.stringValue, let tool = InkToolV10(rawValue: toolName) else { return nil }
        let flat = (obj["pts"]?.arrayValue ?? []).map { $0.doubleValue ?? Double.nan }
        let points = InkPointV10.points(fromFlat: flat)
        guard !points.isEmpty else { return nil }
        let tRaw = obj["t"]?.doubleValue ?? 0
        let t = tRaw.isFinite && tRaw > 0 && tRaw < 1e15 ? Int(tRaw.rounded()) : 0
        self.init(
            id: id,
            cell: CellKeyV10(raw: cellRaw),
            tool: tool,
            color: obj["color"]?.stringValue ?? tool.defaultColor,
            t: t,
            dev: obj["dev"]?.stringValue,
            points: points
        )
    }

    /// The `tool` string of a raw stroke object, whatever it is (nil when missing or not a string).
    public static func toolName(of json: JSONValueV10) -> String? {
        json["tool"]?.stringValue
    }

    public init(from decoder: Decoder) throws {
        let json = try JSONValueV10(from: decoder)
        guard let stroke = InkStrokeV10(json: json) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unusable ink stroke"))
        }
        self = stroke
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    // MARK: - Geometry

    /// Lowest point of the stroke in cell coordinates, including half the nib size (0 for no points).
    public var bottom: CGFloat {
        var bottom: CGFloat = 0
        for p in points {
            bottom = max(bottom, p.y + max(p.sizeW, p.sizeH) / 2)
        }
        return bottom
    }

    // MARK: - Paper coordinates (M3B_CONTRACT §2.2)

    /// The control points in paper coordinates (`cellOrigin` = the top-left corner of `cell`).
    /// The lasso test uses these stored points, not the drawn outline.
    public func paperPoints(cellOrigin: CGPoint) -> [CGPoint] {
        points.map { CGPoint(x: $0.x + cellOrigin.x, y: $0.y + cellOrigin.y) }
    }

    /// Bounding rect of the control points in paper coordinates, grown on every side by half the
    /// largest nib size (web strokeBBox). nil for a stroke without points.
    public func paperBounds(cellOrigin: CGPoint) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        var maxSize: CGFloat = 0
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
            maxSize = max(maxSize, max(p.sizeW, p.sizeH))
        }
        let half = maxSize / 2
        return CGRect(
            x: cellOrigin.x + minX - half,
            y: cellOrigin.y + minY - half,
            width: maxX - minX + maxSize,
            height: maxY - minY + maxSize
        )
    }

    /// A copy moved by `delta` (paper lu) with a **new id**, written at `ms`, in cell `newCell`
    /// (points become relative to `newCellOrigin`). `dev` is kept; the 0.1 lu rounding is `InkPointV10`'s
    /// own. Used by the lasso move (M3B_CONTRACT §3.2 moveStrokes).
    public func translated(by delta: CGVector, from cellOrigin: CGPoint, to newCell: CellKeyV10, newCellOrigin: CGPoint, id: String = InkStrokeV10.newId(), at ms: Int) -> InkStrokeV10 {
        let dx = cellOrigin.x + delta.dx - newCellOrigin.x
        let dy = cellOrigin.y + delta.dy - newCellOrigin.y
        let moved = points.map { p in
            InkPointV10(
                x: p.x + dx, y: p.y + dy, dtMs: p.dtMs,
                sizeW: p.sizeW, sizeH: p.sizeH, opacity: p.opacity, force: p.force,
                azimuth: p.azimuth, altitude: p.altitude
            )
        }
        return InkStrokeV10(id: id, cell: newCell, tool: tool, color: color, t: ms, dev: dev, points: moved)
    }
}

/// Identity of a `PKStroke` on the canvas, independent of its `transform` (DESIGN §3.4): the path's
/// creation date, its point count, the ink type and the first control point's position.
public struct StrokeFingerprintV10: Hashable, Sendable {
    public var creationDate: Date
    public var pointCount: Int
    public var inkType: String
    public var firstX: CGFloat
    public var firstY: CGFloat

    public init(creationDate: Date, pointCount: Int, inkType: String, firstX: CGFloat, firstY: CGFloat) {
        self.creationDate = creationDate
        self.pointCount = pointCount
        self.inkType = inkType
        self.firstX = firstX
        self.firstY = firstY
    }
}
