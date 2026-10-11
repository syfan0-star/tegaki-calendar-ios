import CoreGraphics
import Foundation
import InkModel
import Layout
import PencilKit

// This file deliberately imports no UIKit so it can be type-checked against the macOS SDK on a Mac
// without Xcode (docs/M2_CONTRACT.md §8). Colours go through InkColors (InkTools.swift).

/// What one `canvasViewDrawingDidChange` did to the ledger (contract §3).
struct InkChange {
    var added: [InkStroke]
    var removedIds: [String]

    var isEmpty: Bool { added.isEmpty && removedIds.isEmpty }
}

// MARK: - Pure stroke helpers

/// Pure geometry on `PKStroke` values: the fingerprint that stands in for a stroke id, and the
/// cell-relative point list that is stored in the ledger (DESIGN.md §3.4, §3.9).
enum StrokeGeometry {
    /// Identity of a stroke that does not depend on its `transform`, so it survives relayout:
    /// creation date (microsecond precision), control point count, ink type, first control point.
    static func fingerprint(of stroke: PKStroke) -> StrokeFingerprint {
        let path = stroke.path
        let first = path.first?.location ?? .zero
        return StrokeFingerprint(
            creationDate: path.creationDate,
            pointCount: path.count,
            inkType: stroke.ink.inkType.rawValue,
            firstX: first.x,
            firstY: first.y
        )
    }

    /// The control points of `stroke` in paper space (transform applied), moved to be relative to
    /// `cellOrigin` and rounded as the storage format asks (x, y 0.1; size / opacity / force 0.01;
    /// azimuth / altitude 0.001; time offset to whole milliseconds).
    static func cellRelativePoints(_ stroke: PKStroke, cellOrigin: CGPoint) -> [InkPoint] {
        let transform = stroke.transform
        var points: [InkPoint] = []
        points.reserveCapacity(stroke.path.count)
        for p in stroke.path {
            let paper = p.location.applying(transform)
            points.append(InkPoint(
                x: round(paper.x - cellOrigin.x, places: 1),
                y: round(paper.y - cellOrigin.y, places: 1),
                dtMs: max(0, Int((p.timeOffset * 1000).rounded())),
                sizeW: round(p.size.width, places: 2),
                sizeH: round(p.size.height, places: 2),
                opacity: round(p.opacity, places: 2),
                force: round(p.force, places: 2),
                azimuth: round(p.azimuth, places: 3),
                altitude: round(p.altitude, places: 3)
            ))
        }
        return points
    }

    /// Paper-space bounds of the stroke: `renderBounds` (already transformed) when PencilKit gives a
    /// usable rect, otherwise the bounding box of the transformed control points.
    static func paperBounds(of stroke: PKStroke) -> CGRect {
        let render = stroke.renderBounds
        if !render.isNull, !render.isInfinite, render.origin.x.isFinite, render.origin.y.isFinite,
           render.width.isFinite, render.height.isFinite {
            return render
        }
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for p in stroke.path {
            let q = p.location.applying(stroke.transform)
            minX = min(minX, q.x); maxX = max(maxX, q.x)
            minY = min(minY, q.y); maxY = max(maxY, q.y)
        }
        guard minX <= maxX, minY <= maxY else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Rounds to `places` decimals (half away from zero) and turns -0 into 0 so JSON stays tidy.
    static func round(_ value: CGFloat, places: Int) -> CGFloat {
        guard value.isFinite else { return 0 }
        let scale = pow(10, CGFloat(places))
        let r = (value * scale).rounded() / scale
        return r == 0 ? 0 : r
    }

}

// MARK: - History ops

/// One reversible edit of the ledger (the web version's `Op`: add / remove / batch).
enum InkOp {
    case add([InkStroke])
    case remove([InkStroke])
    case batch([InkOp])
}

// MARK: - Ledger

/// The ledger of one page's handwriting and its bridge to `PKCanvasView` (DESIGN.md §3.3–3.5, §3.13).
///
/// - `drawing()` turns the ledger into a `PKDrawing`: each stroke keeps its cell-relative control
///   points and is placed with a translation `transform` to its cell's top-left corner.
/// - `applyCanvasChange(_:)` diffs what the canvas holds against a fingerprint → id map: strokes the
///   canvas has that the map does not are new (they get an id and a cell); strokes the map has that
///   the canvas lost were erased (they get a tombstone).
/// - History is the ledger's own (add / remove ops, newest 200). Undoing a deletion re-adds *clones
///   with new ids*, because a tombstoned id can never come back (same rule as the web version).
@MainActor
final class InkLedger {
    static let historyLimit = 200

    private(set) var page: InkPage
    private(set) var layout: MonthPageLayout
    /// Written into `InkStroke.dev` of new strokes (the app passes `identifierForVendor`).
    var deviceId: String?

    /// Fingerprint → stroke id for every stroke that is currently *in the canvas drawing*.
    private var fingerprintToId: [StrokeFingerprint: String] = [:]
    /// Ids in the order `drawing()` emitted them (lets `bind(to:)` re-key from the canvas's copy).
    private var builtIds: [String] = []
    /// Ops to perform to undo (newest last) and to redo (newest last).
    private var undoStack: [InkOp] = []
    private var redoStack: [InkOp] = []

    init(page: InkPage, layout: MonthPageLayout, deviceId: String? = nil) {
        self.page = page
        self.layout = layout
        self.deviceId = deviceId
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Replaces the page (a new month, or a merge from elsewhere). The history is kept only when the
    /// caller says so (same page id); its ops are harmless against a merged page.
    func reload(page: InkPage, keepHistory: Bool) {
        self.page = page
        if !keepHistory {
            undoStack.removeAll()
            redoStack.removeAll()
        }
        fingerprintToId.removeAll()
        builtIds.removeAll()
    }

    // MARK: Ledger → PKDrawing

    /// Builds the drawing for the current layout and rebuilds the fingerprint map from it.
    /// Strokes whose cell is not in the layout stay in the page but are not drawn (and therefore are
    /// never mistaken for erased strokes).
    func drawing() -> PKDrawing {
        var map: [StrokeFingerprint: String] = [:]
        var ids: [String] = []
        var strokes: [PKStroke] = []
        let live = page.liveStrokes
        map.reserveCapacity(live.count)
        strokes.reserveCapacity(live.count)
        for stroke in live {
            guard !stroke.points.isEmpty, let cell = layout.cells[stroke.cell] else { continue }
            let pk = Self.makePKStroke(stroke, cellOrigin: cell.origin, avoiding: map)
            map[StrokeGeometry.fingerprint(of: pk)] = stroke.id
            ids.append(stroke.id)
            strokes.append(pk)
        }
        fingerprintToId = map
        builtIds = ids
        return PKDrawing(strokes: strokes)
    }

    /// Re-keys the fingerprint map from the drawing the canvas actually holds after
    /// `canvasView.drawing = ledger.drawing()`. Order is preserved by PencilKit, so this only guards
    /// against the framework normalising a value the fingerprint depends on. No-op if counts differ.
    func bind(to canvasDrawing: PKDrawing) {
        let strokes = canvasDrawing.strokes
        guard strokes.count == builtIds.count else { return }
        var map: [StrokeFingerprint: String] = [:]
        map.reserveCapacity(strokes.count)
        for (pk, id) in zip(strokes, builtIds) {
            map[StrokeGeometry.fingerprint(of: pk)] = id
        }
        fingerprintToId = map
    }

    /// Relayout (only while the pen is up): new cell rectangles, same points, new transforms.
    func relayout(_ layout: MonthPageLayout) -> PKDrawing {
        self.layout = layout
        return drawing()
    }

    // MARK: PKDrawing → ledger

    /// Diffs the canvas against the map. New strokes get a UUID and a cell (the cell under the centre
    /// of their paper-space bounds; the memo cell if none); erased strokes get tombstones.
    func applyCanvasChange(_ drawing: PKDrawing) -> InkChange {
        var seen = Set<StrokeFingerprint>()
        var added: [InkStroke] = []
        var addedFingerprints: [(StrokeFingerprint, String)] = []
        let now = Self.nowMs()
        for pk in drawing.strokes {
            let fp = StrokeGeometry.fingerprint(of: pk)
            if fingerprintToId[fp] != nil {
                seen.insert(fp)
                continue
            }
            guard pk.path.count > 0 else { continue }
            let stroke = makeInkStroke(from: pk, now: now)
            added.append(stroke)
            addedFingerprints.append((fp, stroke.id))
            seen.insert(fp)
        }
        var removed: [InkStroke] = []
        var removedIds: [String] = []
        for (fp, id) in fingerprintToId where !seen.contains(fp) {
            removedIds.append(id)
            if let s = page.strokes[id] { removed.append(s) }
        }

        guard !added.isEmpty || !removedIds.isEmpty else {
            return InkChange(added: [], removedIds: [])
        }

        for s in added { page.add(s) }
        if !removedIds.isEmpty { page.remove(ids: removedIds, at: now) }

        for id in removedIds {
            builtIds.removeAll { $0 == id }
        }
        fingerprintToId = fingerprintToId.filter { !removedIds.contains($0.value) }
        for (fp, id) in addedFingerprints {
            fingerprintToId[fp] = id
            builtIds.append(id)
        }

        // Undo = put back what was erased, then take away what was drawn.
        var undoOps: [InkOp] = []
        if !removed.isEmpty { undoOps.append(.add(removed)) }
        if !added.isEmpty { undoOps.append(.remove(added)) }
        push(undo: undoOps.count == 1 ? undoOps[0] : .batch(undoOps))
        redoStack.removeAll()

        return InkChange(added: added, removedIds: removedIds)
    }

    /// True when the stroke's bottom needs more room than its cell currently has (the row must grow).
    func needsMoreRoom(_ stroke: InkStroke) -> Bool {
        guard let cell = layout.cells[stroke.cell] else { return false }
        let pad = stroke.cell.isMemo ? PaperSpec.memoInkPad : PaperSpec.inkPad
        return stroke.bottom + pad > cell.height
    }

    // MARK: History

    /// Performs the newest undo op; returns the rebuilt drawing (nil when there is nothing to undo).
    func undo() -> PKDrawing? {
        guard let op = undoStack.popLast() else { return nil }
        if let inverse = perform(op) {
            redoStack.append(inverse)
            Self.trim(&redoStack)
        }
        return drawing()
    }

    /// Performs the newest redo op; returns the rebuilt drawing (nil when there is nothing to redo).
    func redo() -> PKDrawing? {
        guard let op = redoStack.popLast() else { return nil }
        if let inverse = perform(op) {
            undoStack.append(inverse)
            Self.trim(&undoStack)
        }
        return drawing()
    }

    private func push(undo op: InkOp) {
        undoStack.append(op)
        Self.trim(&undoStack)
    }

    private static func trim(_ stack: inout [InkOp]) {
        if stack.count > historyLimit {
            stack.removeFirst(stack.count - historyLimit)
        }
    }

    /// Applies `op` to the page and returns the op that reverses what actually happened
    /// (nil when nothing changed). Re-adding a stroke whose id is tombstoned or still live adds a
    /// clone with a fresh id instead.
    private func perform(_ op: InkOp) -> InkOp? {
        let now = Self.nowMs()
        switch op {
        case .add(let strokes):
            var actuallyAdded: [InkStroke] = []
            for var s in strokes {
                guard !s.points.isEmpty else { continue }
                if page.deleted[s.id] != nil || page.strokes[s.id] != nil {
                    s.id = InkStroke.newId()
                }
                page.add(s)
                if page.strokes[s.id] != nil { actuallyAdded.append(s) }
            }
            return actuallyAdded.isEmpty ? nil : .remove(actuallyAdded)
        case .remove(let strokes):
            let present = strokes.filter { page.strokes[$0.id] != nil && page.deleted[$0.id] == nil }
            guard !present.isEmpty else { return nil }
            page.remove(ids: present.map { $0.id }, at: now)
            return .add(present)
        case .batch(let ops):
            var inverses: [InkOp] = []
            for sub in ops {
                if let inv = perform(sub) { inverses.append(inv) }
            }
            if inverses.isEmpty { return nil }
            return inverses.count == 1 ? inverses[0] : .batch(inverses.reversed())
        }
    }

    // MARK: Conversions

    private static func makePKStroke(_ stroke: InkStroke, cellOrigin: CGPoint, avoiding map: [StrokeFingerprint: String]) -> PKStroke {
        let style = InkStyle(tool: stroke.tool, colorHex: stroke.color, width: 0)
        let ink = style.pkInk
        let points = stroke.points.map { p in
            PKStrokePoint(
                location: CGPoint(x: p.x, y: p.y),
                timeOffset: TimeInterval(p.dtMs) / 1000,
                size: CGSize(width: p.sizeW, height: p.sizeH),
                opacity: p.opacity,
                force: p.force,
                azimuth: p.azimuth,
                altitude: p.altitude
            )
        }
        let transform = CGAffineTransform(translationX: cellOrigin.x, y: cellOrigin.y)
        // Two stored strokes with the same creation date, count, ink and first point would share a
        // fingerprint (possible for web-imported strokes). Nudge the creation date by a microsecond
        // until the fingerprint is free; the stored `inkStart` is left untouched.
        var creationDate = stroke.inkStart
        var pk = PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: creationDate), transform: transform, mask: nil)
        var attempts = 0
        while map[StrokeGeometry.fingerprint(of: pk)] != nil, attempts < 64 {
            creationDate = creationDate.addingTimeInterval(0.000_001)
            pk = PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: creationDate), transform: transform, mask: nil)
            attempts += 1
        }
        return pk
    }

    private func makeInkStroke(from pk: PKStroke, now: Int) -> InkStroke {
        let bounds = StrokeGeometry.paperBounds(of: pk)
        let cell = cellFor(bounds: bounds)
        let origin = layout.cells[cell]?.origin ?? .zero
        let tool = InkModel.InkTool(inkType: pk.ink.inkType)
        let color = InkColors.hex(of: pk.ink.color) ?? InkPresets.fallbackColorHex(for: tool)
        // `t` doubles as the creation date of the rebuilt path (`InkStroke.inkStart` derives from it).
        let t = Int((pk.path.creationDate.timeIntervalSince1970 * 1000).rounded())
        return InkStroke(
            id: InkStroke.newId(),
            cell: cell,
            tool: tool,
            color: color,
            t: t > 0 ? t : now,
            dev: deviceId,
            points: StrokeGeometry.cellRelativePoints(pk, cellOrigin: origin)
        )
    }

    /// The cell under the centre of the stroke's bounds; if the centre is off the paper, the nearest
    /// cell (centre clamped into the paper); the memo cell as the last resort.
    private func cellFor(bounds: CGRect) -> CellKey {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let cell = layout.cell(at: center) { return cell }
        let size = layout.size
        let clamped = CGPoint(
            x: min(max(center.x, 0), max(size.width - 0.001, 0)),
            y: min(max(center.y, 0), max(size.height - 0.001, 0))
        )
        if let cell = layout.cell(at: clamped) { return cell }
        return CellKey.memo
    }

    private static func nowMs() -> Int {
        Int((Date().timeIntervalSince1970 * 1000).rounded())
    }
}
