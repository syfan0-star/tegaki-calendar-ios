import Foundation
import CoreGraphics

/// The handwriting ledger of one page: a small state-based CRDT, ported from the web version's
/// js/ink/model.js (DESIGN §3.9, §5.3).
///
/// - Strokes are immutable and identified by a random id.
/// - Deleting a stroke records a tombstone (id → deletion time in ms). A tombstoned id never comes back.
/// - `merge(a, b)` = (strokes(a) ∪ strokes(b)) − (tombstones(a) ∪ tombstones(b)); commutative,
///   associative and idempotent, so devices converge whatever the sync order.
/// - Items the reader does not understand (`unknown` top-level keys, strokes with an unknown `tool`)
///   are kept and written back, so an older app never destroys a newer app's data.
public struct InkPage: Codable, Equatable, Sendable {
    public static let maxStrokes = 20_000
    public static let maxTombstones = 200_000
    public static let maxPageIdLength = 256
    public static let knownKeys: Set<String> = ["v", "pageId", "strokes", "deleted", "updatedAt"]

    /// Format version (1). Older or newer values are read and written back unchanged.
    public var v: Int
    /// "m1-2026-10" etc., the same string as the web version.
    public var pageId: String
    public var strokes: [String: InkStroke]
    /// id → deletion time (ms since the epoch).
    public var deleted: [String: Int]
    public var updatedAt: Int
    /// Top-level items this version does not know, written back as they were.
    public var unknown: [String: JSONValue]
    /// Strokes whose `tool` this version does not know (raw JSON, keyed by id), written back, not drawn.
    public var unknownStrokes: [String: JSONValue]

    public init(
        v: Int = 1,
        pageId: String,
        strokes: [String: InkStroke] = [:],
        deleted: [String: Int] = [:],
        updatedAt: Int = 0,
        unknown: [String: JSONValue] = [:],
        unknownStrokes: [String: JSONValue] = [:]
    ) {
        self.v = v
        self.pageId = pageId
        self.strokes = strokes
        self.deleted = deleted
        self.updatedAt = updatedAt
        self.unknown = unknown
        self.unknownStrokes = unknownStrokes
    }

    public static func empty(pageId: String) -> InkPage {
        InkPage(pageId: pageId)
    }

    // MARK: - Reading

    /// Visible strokes in draw order: markers first (under the pens), then pens; each by `t`, then id.
    public var liveStrokes: [InkStroke] {
        strokes.values
            .filter { deleted[$0.id] == nil }
            .sorted(by: InkPage.drawsBefore)
    }

    public var liveStrokeCount: Int {
        strokes.values.reduce(0) { $0 + (deleted[$1.id] == nil ? 1 : 0) }
    }

    public func isLive(_ id: String) -> Bool {
        strokes[id] != nil && deleted[id] == nil
    }

    static func drawsBefore(_ a: InkStroke, _ b: InkStroke) -> Bool {
        let ka = a.tool == .marker ? 0 : 1
        let kb = b.tool == .marker ? 0 : 1
        if ka != kb { return ka < kb }
        if a.t != b.t { return a.t < b.t }
        return a.id < b.id
    }

    /// Bottom edge of the handwriting of each cell (max over its live strokes of point y + nib/2).
    /// Cells without ink are absent.
    public func inkBottoms() -> [CellKey: CGFloat] {
        var out: [CellKey: CGFloat] = [:]
        for stroke in strokes.values where deleted[stroke.id] == nil {
            let bottom = stroke.bottom
            out[stroke.cell] = max(out[stroke.cell] ?? 0, bottom)
        }
        return out
    }

    // MARK: - Editing

    /// Adds a stroke. Ignored when its id is tombstoned, invalid, or it has no points. When the id
    /// already exists the deterministic pick of the two contents wins (strokes are immutable, so this
    /// only matters for corrupted input). `updatedAt` becomes at least `at` (default: the stroke's `t`).
    public mutating func add(_ s: InkStroke, at ms: Int? = nil) {
        guard InkStroke.isValidId(s.id), deleted[s.id] == nil, !s.points.isEmpty else { return }
        if let prev = strokes[s.id] {
            let chosen = InkPage.pickStroke(prev, s)
            if chosen == prev { return }
            strokes[s.id] = chosen
        } else {
            strokes[s.id] = s
        }
        unknownStrokes[s.id] = nil
        updatedAt = max(updatedAt, max(0, ms ?? s.t))
    }

    /// Tombstones `ids` at time `ms` (kept at the later time if already tombstoned). Ids not present
    /// are tombstoned too: the stroke may exist on another device.
    public mutating func remove(ids: [String], at ms: Int) {
        let time = max(0, ms)
        var changed = false
        for id in ids where InkStroke.isValidId(id) {
            if let prev = deleted[id] {
                if time > prev { deleted[id] = time }
            } else {
                deleted[id] = time
            }
            strokes[id] = nil
            unknownStrokes[id] = nil
            changed = true
        }
        if changed { updatedAt = max(updatedAt, time) }
    }

    // MARK: - Merge (web version mergePages)

    /// Union of strokes (deterministic pick on a shared id), union of tombstones (later time wins),
    /// tombstoned strokes dropped, `updatedAt` = max, `v` = max, unknown items united.
    public static func merge(_ a: InkPage, _ b: InkPage) -> InkPage {
        var deleted: [String: Int] = [:]
        for (id, t) in a.deleted where InkStroke.isValidId(id) { deleted[id] = max(0, t) }
        for (id, t) in b.deleted where InkStroke.isValidId(id) {
            let time = max(0, t)
            if let cur = deleted[id] {
                if time > cur { deleted[id] = time }
            } else {
                deleted[id] = time
            }
        }

        var strokes: [String: InkStroke] = [:]
        for (id, s) in a.strokes where s.id == id && deleted[id] == nil && !s.points.isEmpty {
            strokes[id] = s
        }
        for (id, s) in b.strokes where s.id == id && deleted[id] == nil && !s.points.isEmpty {
            if let cur = strokes[id] {
                strokes[id] = pickStroke(cur, s)
            } else {
                strokes[id] = s
            }
        }

        var unknownStrokes: [String: JSONValue] = [:]
        for (id, j) in a.unknownStrokes where deleted[id] == nil && strokes[id] == nil {
            unknownStrokes[id] = j
        }
        for (id, j) in b.unknownStrokes where deleted[id] == nil && strokes[id] == nil {
            if let cur = unknownStrokes[id] {
                unknownStrokes[id] = pickJSON(cur, j)
            } else {
                unknownStrokes[id] = j
            }
        }

        var unknown = a.unknown
        for (key, j) in b.unknown {
            if let cur = unknown[key] {
                unknown[key] = pickJSON(cur, j)
            } else {
                unknown[key] = j
            }
        }

        return InkPage(
            v: max(a.v, b.v),
            pageId: pickPageId(a.pageId, b.pageId),
            strokes: strokes,
            deleted: deleted,
            updatedAt: max(a.updatedAt, b.updatedAt),
            unknown: unknown,
            unknownStrokes: unknownStrokes
        )
    }

    /// Total order on stroke contents (two strokes with one id should be identical; if they ever
    /// differ every replica must still pick the same one). 0 only when every field is equal.
    public static func compareStrokes(_ a: InkStroke, _ b: InkStroke) -> Int {
        if a.t != b.t { return a.t < b.t ? -1 : 1 }
        if a.tool != b.tool { return a.tool.rawValue < b.tool.rawValue ? -1 : 1 }
        if a.color != b.color { return a.color < b.color ? -1 : 1 }
        if a.cell.raw != b.cell.raw { return a.cell.raw < b.cell.raw ? -1 : 1 }
        let ad = a.dev.map { "1" + $0 } ?? "0"
        let bd = b.dev.map { "1" + $0 } ?? "0"
        if ad != bd { return ad < bd ? -1 : 1 }
        if a.points.count != b.points.count { return a.points.count < b.points.count ? -1 : 1 }
        for (p, q) in zip(a.points, b.points) {
            let pv = p.values
            let qv = q.values
            for i in 0..<pv.count where pv[i] != qv[i] {
                return pv[i] < qv[i] ? -1 : 1
            }
        }
        if a.id != b.id { return a.id < b.id ? -1 : 1 }
        return 0
    }

    static func pickStroke(_ a: InkStroke, _ b: InkStroke) -> InkStroke {
        compareStrokes(a, b) >= 0 ? a : b
    }

    static func pickJSON(_ a: JSONValue, _ b: JSONValue) -> JSONValue {
        a.serialized() >= b.serialized() ? a : b
    }

    /// "" is neutral; otherwise the smaller string wins (deterministic).
    static func pickPageId(_ a: String, _ b: String) -> String {
        if a == b || b.isEmpty { return a }
        if a.isEmpty { return b }
        return a < b ? a : b
    }

    // MARK: - JSON (DESIGN §3.9)

    /// `{ "v", "pageId", "strokes": { id: stroke }, "deleted": { id: ms }, "updatedAt", ...unknown }`.
    public var jsonValue: JSONValue {
        var obj = unknown
        obj["v"] = .number(Double(v))
        obj["pageId"] = .string(pageId)
        var strokesObj: [String: JSONValue] = [:]
        for (id, s) in strokes where deleted[id] == nil {
            strokesObj[id] = s.jsonValue
        }
        for (id, j) in unknownStrokes where deleted[id] == nil && strokesObj[id] == nil {
            strokesObj[id] = j
        }
        obj["strokes"] = .object(strokesObj)
        obj["deleted"] = .object(deleted.mapValues { .number(Double($0)) })
        obj["updatedAt"] = .number(Double(updatedAt))
        return .object(obj)
    }

    /// Tolerant read: broken strokes are dropped, tombstoned strokes are dropped, strokes with an
    /// unknown tool go to `unknownStrokes`, unknown top-level keys to `unknown`. Never fails for a
    /// JSON object (missing parts are treated as empty).
    public init(json: JSONValue) {
        let obj = json.objectValue ?? [:]

        let vRaw = obj["v"]?.doubleValue ?? 1
        let v = vRaw.isFinite && abs(vRaw) < 1e9 ? Int(vRaw.rounded()) : 1

        var pageId = obj["pageId"]?.stringValue ?? ""
        if pageId.count > InkPage.maxPageIdLength { pageId = "" }

        var deleted: [String: Int] = [:]
        if let raw = obj["deleted"]?.objectValue {
            for (id, value) in raw where InkStroke.isValidId(id) {
                if deleted.count >= InkPage.maxTombstones { break }
                deleted[id] = InkPage.normalizeTime(value.doubleValue)
            }
        }

        var strokes: [String: InkStroke] = [:]
        var unknownStrokes: [String: JSONValue] = [:]
        func take(_ raw: JSONValue, fallbackId: String?) {
            guard strokes.count + unknownStrokes.count < InkPage.maxStrokes else { return }
            guard let sObj = raw.objectValue else { return }
            let id: String
            if let s = sObj["id"]?.stringValue, InkStroke.isValidId(s) {
                id = s
            } else if let f = fallbackId, InkStroke.isValidId(f) {
                id = f
            } else {
                return
            }
            if deleted[id] != nil { return }
            if let toolName = sObj["tool"]?.stringValue, InkTool(rawValue: toolName) == nil {
                // Unknown ink kind: keep the raw object (with its id) so it is written back unchanged.
                var kept = sObj
                kept["id"] = .string(id)
                let value = JSONValue.object(kept)
                if strokes[id] != nil { return }
                if let cur = unknownStrokes[id] {
                    unknownStrokes[id] = InkPage.pickJSON(cur, value)
                } else {
                    unknownStrokes[id] = value
                }
                return
            }
            guard let stroke = InkStroke(json: raw, fallbackId: fallbackId) else { return }
            unknownStrokes[stroke.id] = nil
            if let cur = strokes[stroke.id] {
                strokes[stroke.id] = InkPage.pickStroke(cur, stroke)
            } else {
                strokes[stroke.id] = stroke
            }
        }
        if let rawStrokes = obj["strokes"]?.objectValue {
            for key in rawStrokes.keys.sorted() {
                take(rawStrokes[key]!, fallbackId: key)
            }
        } else if let rawList = obj["strokes"]?.arrayValue {
            for raw in rawList {
                take(raw, fallbackId: nil)
            }
        }

        var unknown: [String: JSONValue] = [:]
        for (key, value) in obj where !InkPage.knownKeys.contains(key) {
            unknown[key] = value
        }

        self.init(
            v: v,
            pageId: pageId,
            strokes: strokes,
            deleted: deleted,
            updatedAt: InkPage.normalizeTime(obj["updatedAt"]?.doubleValue),
            unknown: unknown,
            unknownStrokes: unknownStrokes
        )
    }

    static func normalizeTime(_ value: Double?) -> Int {
        guard let v = value, v.isFinite, v > 0, v < 1e15 else { return 0 }
        return Int(v.rounded())
    }

    public init(from decoder: Decoder) throws {
        let json = try JSONValue(from: decoder)
        guard json.objectValue != nil else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "An ink page must be a JSON object"))
        }
        self.init(json: json)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}
