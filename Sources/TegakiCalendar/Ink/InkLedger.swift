import CoreGraphics
import Foundation
import InkModel
import Layout
import PencilKit

// This file deliberately imports no UIKit so it can be type-checked against the macOS SDK on a Mac
// without Xcode (docs/M2_CONTRACT.md §8, M3A_CONTRACT.md §2.2). Colours go through InkColors (InkTools.swift).

/// What one `canvasViewDrawingDidChange` did to the ledger (M2 contract §3).
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

    /// A stored stroke as a `PKStroke`: the cell-relative control points unchanged, placed with a
    /// translation `transform` to `cellOrigin` (the cell's top-left corner). Shared by the canvas
    /// drawing (`InkLedger.drawing()`) and the snapshot pictures (`InkSnapshot`, M3B_CONTRACT §3.5).
    ///
    /// Two stored strokes with the same creation date, count, ink and first point would share a
    /// fingerprint (possible for web-imported strokes). The creation date is nudged by a microsecond
    /// until the fingerprint is not in `map`; the stored `inkStart` is left untouched.
    static func makePKStroke(_ stroke: InkStroke, cellOrigin: CGPoint, avoiding map: [StrokeFingerprint: String]) -> PKStroke {
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
        var creationDate = stroke.inkStart
        var pk = PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: creationDate), transform: transform, mask: nil)
        var attempts = 0
        while map[fingerprint(of: pk)] != nil, attempts < 64 {
            creationDate = creationDate.addingTimeInterval(0.000_001)
            pk = PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: creationDate), transform: transform, mask: nil)
            attempts += 1
        }
        return pk
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
/// Works for any page (month / week / day / year) through `PageLayout` (M3A_CONTRACT.md §2.1):
/// the layout owns the cell rectangles, the cell a new stroke belongs to, and which cells grow.
///
/// - `drawing()` turns the ledger into a `PKDrawing`: each stroke keeps its cell-relative control
///   points and is placed with a translation `transform` to its cell's top-left corner.
/// - `applyCanvasChange(_:)` diffs what the canvas holds against a fingerprint → id map: strokes the
///   canvas has that the map does not are new (they get an id and a cell); strokes the map has that
///   the canvas lost were erased (they get a tombstone).
/// - History is the ledger's own (add / remove ops, newest 200). Undoing a deletion re-adds *clones
///   with new ids*, because a tombstoned id can never come back (same rule as the web version).
/// - The ledger never mixes pages: `page.pageId == layout.pageId` always holds. A `reload` or
///   `relayout` with another page id is a programming error of the owner; it is reported through
///   `onPageMismatch` (an assertion in Debug) and ignored.
/// - Every page that enters the ledger (`init`, `reload`) goes through `BandMigration.migrate`
///   (M4B_CONTRACT §3.3): the strokes of the week / day pages' former all-day band move onto the
///   `grid` cell, idempotently, so the canvas never has to know the old cells.
@MainActor
final class InkLedger {
    static let historyLimit = 200

    /// Called with a message when a page / layout pair with different ids reaches the ledger. The
    /// default is `assertionFailure` (contract §2.1: assert in Debug, ignore in Release); the unit
    /// tests replace it to exercise the ignore path.
    static var onPageMismatch: (String) -> Void = { message in assertionFailure(message) }

    private(set) var page: InkPage
    private(set) var layout: any PageLayout
    /// Written into `InkStroke.dev` of new strokes (the app passes `identifierForVendor`).
    var deviceId: String?

    /// Fingerprint → stroke id for every stroke that is currently *in the canvas drawing*.
    private var fingerprintToId: [StrokeFingerprint: String] = [:]
    /// Ids in the order `drawing()` emitted them (lets `bind(to:)` re-key from the canvas's copy).
    private var builtIds: [String] = []
    /// Ops to perform to undo (newest last) and to redo (newest last).
    private var undoStack: [InkOp] = []
    private var redoStack: [InkOp] = []

    /// `page` and `layout` must be the same page (`page.pageId == layout.pageId`). The owner builds
    /// both from one page id, so a mismatch here is reported like `reload` / `relayout`; the ledger
    /// then starts with an empty page for the layout rather than mixing two pages. The page is
    /// migrated (`BandMigration.migrate`, M4B_CONTRACT §3.3) on the way in.
    init(page: InkPage, layout: any PageLayout, deviceId: String? = nil) {
        if page.pageId == layout.pageId {
            self.page = BandMigration.migrate(page)
        } else {
            Self.onPageMismatch("InkLedger: page \(page.pageId) does not belong to layout \(layout.pageId)")
            self.page = InkPage.empty(pageId: layout.pageId)
        }
        self.layout = layout
        self.deviceId = deviceId
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Replaces the page (a merge from elsewhere, an import, a remote update). The history is kept
    /// only when the caller says so; its ops are harmless against a merged page.
    /// A page of another id is ignored (reported through `onPageMismatch`): the ledger never mixes pages.
    ///
    /// The fingerprint map and `builtIds` are **not** touched (M4 contract §5.4): they describe the
    /// strokes the canvas is showing right now, not the page. The pen may be on the paper when a
    /// remote update lands; when it lifts, `applyCanvasChange` then still knows every stroke the
    /// canvas holds (nothing is re-added under a new id, and a stroke another device erased is not
    /// revived) and only the stroke just drawn is new. The next `drawing()` rebuilds the map from
    /// the page. The page is migrated (`BandMigration.migrate`) on the way in, like in `init`.
    func reload(page: InkPage, keepHistory: Bool) {
        guard page.pageId == layout.pageId else {
            Self.onPageMismatch("InkLedger.reload: page \(page.pageId) does not belong to layout \(layout.pageId)")
            return
        }
        self.page = BandMigration.migrate(page)
        if !keepHistory {
            undoStack.removeAll()
            redoStack.removeAll()
        }
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
        let cells = layout.cells
        map.reserveCapacity(live.count)
        strokes.reserveCapacity(live.count)
        for stroke in live {
            guard !stroke.points.isEmpty, let cell = cells[stroke.cell] else { continue }
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
    /// A layout of another page is ignored (reported through `onPageMismatch`); the drawing of the
    /// current layout is returned so the canvas keeps showing what it already shows.
    func relayout(_ layout: any PageLayout) -> PKDrawing {
        if layout.pageId == page.pageId {
            self.layout = layout
        } else {
            Self.onPageMismatch("InkLedger.relayout: layout \(layout.pageId) does not belong to page \(page.pageId)")
        }
        return drawing()
    }

    // MARK: PKDrawing → ledger

    /// Diffs the canvas against the map. New strokes get a UUID and a cell (the layout's
    /// `inkCell(forCenter:)` of the centre of their paper-space bounds, which never fails);
    /// erased strokes get tombstones.
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

    /// True when the stroke's bottom needs more room than its cell currently has (the cell must
    /// grow). Always false for a cell that does not grow with ink (the week / day time grid, contract
    /// §1.10): writing there never triggers a relayout.
    func needsMoreRoom(_ stroke: InkStroke) -> Bool {
        guard layout.growsWithInk(stroke.cell), let cell = layout.cells[stroke.cell] else { return false }
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

    // MARK: Selection (M3B_CONTRACT §3.2)

    /// The live strokes among `ids` (no tombstone), in the order of `ids`. Unknown, tombstoned and
    /// repeated ids are skipped.
    func strokes(ids: [String]) -> [InkStroke] {
        var seen = Set<String>()
        var out: [InkStroke] = []
        out.reserveCapacity(ids.count)
        for id in ids where seen.insert(id).inserted {
            if let s = page.strokes[id], page.deleted[id] == nil { out.append(s) }
        }
        return out
    }

    /// Paper-space bounds of a live stroke (`InkStroke.paperBounds`: its control points grown by half
    /// the nib); nil when the stroke is not live or its cell is not in the layout (it is not drawn).
    func paperBounds(of id: String) -> CGRect? {
        guard let s = page.strokes[id], page.deleted[id] == nil, let cell = layout.cells[s.cell] else { return nil }
        return s.paperBounds(cellOrigin: cell.origin)
    }

    /// The union of `paperBounds(of:)` over `ids`; nil when none of them has bounds.
    func paperBounds(ids: [String]) -> CGRect? {
        LassoGeometry.union(ids.compactMap { paperBounds(of: $0) })
    }

    /// The id of a stroke the canvas holds, by its fingerprint; nil for a stroke the ledger did not
    /// build (one being drawn right now).
    func id(of canvasStroke: PKStroke) -> String? {
        fingerprintToId[StrokeGeometry.fingerprint(of: canvasStroke)]
    }

    /// Removes `ids` as **one** undoable op (`.remove`; undo re-adds clones with fresh ids, as after
    /// the eraser). Ids that are not live are ignored; an empty `InkChange` when nothing was removed.
    /// The caller puts `drawing()` on the canvas afterwards.
    func removeStrokes(ids: [String]) -> InkChange {
        let present = strokes(ids: ids)
        guard !present.isEmpty else { return InkChange(added: [], removedIds: []) }
        let removedIds = present.map { $0.id }
        page.remove(ids: removedIds, at: Self.nowMs())
        forget(ids: removedIds)
        push(undo: .add(present))
        redoStack.removeAll()
        return InkChange(added: [], removedIds: removedIds)
    }

    /// Moves the selection: the originals get tombstones and clones translated by `delta` (paper lu)
    /// are added with **new ids** (`t` = now), as **one** batch op. A clone's cell is decided again
    /// from the centre of its moved bounds with `layout.inkCell(forCenter:)` (DESIGN §3.7), so a
    /// stroke dragged onto another day belongs to that day. `newIds` follows the order of `ids`
    /// (originals that were not live are dropped). Nothing happens for a zero or non-finite delta or
    /// when no original is live. The caller puts `drawing()` on the canvas afterwards.
    func moveStrokes(ids: [String], by delta: CGVector) -> (change: InkChange, newIds: [String]) {
        let nothing = (change: InkChange(added: [], removedIds: []), newIds: [String]())
        guard delta.dx.isFinite, delta.dy.isFinite, delta.dx != 0 || delta.dy != 0 else { return nothing }
        let originals = strokes(ids: ids)
        guard !originals.isEmpty else { return nothing }
        let now = Self.nowMs()
        var clones: [InkStroke] = []
        clones.reserveCapacity(originals.count)
        for s in originals {
            // A stroke whose cell the layout lacks is not drawn (and so cannot be selected); should
            // it ever get here, it is placed from the paper's origin like `makeInkStroke` does.
            let origin = layout.cells[s.cell]?.origin ?? .zero
            let bounds = s.paperBounds(cellOrigin: origin) ?? CGRect(origin: origin, size: .zero)
            let moved = bounds.offsetBy(dx: delta.dx, dy: delta.dy)
            let newCell = layout.inkCell(forCenter: CGPoint(x: moved.midX, y: moved.midY))
            let newOrigin = layout.cells[newCell]?.origin ?? .zero
            clones.append(s.translated(by: delta, from: origin, to: newCell, newCellOrigin: newOrigin, at: now))
        }
        let removedIds = originals.map { $0.id }
        page.remove(ids: removedIds, at: now)
        for c in clones { page.add(c) }
        forget(ids: removedIds)
        // Undo = put the originals back (as clones with fresh ids: their ids are tombstoned now) and
        // take the moved copies away. One batch, one tap of ↶ (DESIGN §3.13).
        push(undo: .batch([.add(originals), .remove(clones)]))
        redoStack.removeAll()
        return (change: InkChange(added: clones, removedIds: removedIds), newIds: clones.map { $0.id })
    }

    /// Drops `ids` from the fingerprint map (the caller rebuilds the canvas drawing anyway, which
    /// rebuilds the map; this only keeps the map honest in between).
    private func forget(ids: [String]) {
        let gone = Set(ids)
        builtIds.removeAll { gone.contains($0) }
        fingerprintToId = fingerprintToId.filter { !gone.contains($0.value) }
    }

    // MARK: Conversions

    private static func makePKStroke(_ stroke: InkStroke, cellOrigin: CGPoint, avoiding map: [StrokeFingerprint: String]) -> PKStroke {
        StrokeGeometry.makePKStroke(stroke, cellOrigin: cellOrigin, avoiding: map)
    }

    private func makeInkStroke(from pk: PKStroke, now: Int) -> InkStroke {
        let bounds = StrokeGeometry.paperBounds(of: pk)
        // The layout decides the cell, including every fallback (off the paper, the time gutter of
        // the week / day page, the date gutter of the year page: contract §1.6–1.8). The point may
        // then be left of or above the cell, so cell-relative coordinates can be negative.
        let cell = layout.inkCell(forCenter: CGPoint(x: bounds.midX, y: bounds.midY))
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

    private static func nowMs() -> Int {
        Int((Date().timeIntervalSince1970 * 1000).rounded())
    }
}
