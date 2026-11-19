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
    /// 1.3 (docs/M7C_CONTRACT.md §3.3 5, §3.4 削除の守り (b)): on the joined path, the ids of the strokes the
    /// canvas lost that the ledger did not tombstone, because the change was not the eraser's
    /// (`allowRemovals` false) or took too many strokes at once (§3.16). The canvas must then put `drawing()`
    /// back (`needsRebuild`). Always empty on the one-page path, which takes every removal as 1.2.3 does.
    var refusedRemovals: [String] = []
    /// 1.3 (§3.4 削除の守り (a), B_DESIGN.md §2.4 6 (a)): on the joined path, the ids the canvas lost that were
    /// not live in the page, so the ledger neither tombstoned nor journalled them and only forgot their
    /// fingerprints. `alreadyErased`: tombstoned in the page already (another device erased the stroke while
    /// the canvas still showed it: a race that is allowed). `unknownRemovals`: in neither the page's strokes
    /// nor its tombstones (a fingerprint left behind, say by a page that left the window: a fault of the
    /// joined path, which the owner records and, in Debug, stops at). Both always empty on the one-page path.
    var alreadyErased: [String] = []
    var unknownRemovals: [String] = []

    var isEmpty: Bool { added.isEmpty && removedIds.isEmpty }
    /// The canvas lost strokes the ledger kept (`refusedRemovals`): rebuild the drawing from the ledger. A
    /// caller reads it before `isEmpty`, which is true when nothing else changed.
    var needsRebuild: Bool { !refusedRemovals.isEmpty }
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

/// 1.3 (docs/M7C_CONTRACT.md §4.4, D23): one step of the ledger's history: its op, the real pages it
/// touches and its undo group, so `InkLedger.pruneHistory(touching:)` can drop a page's steps together.
struct InkHistoryStep {
    var op: InkOp
    /// The real pages the op's strokes carry in front of their ids and cells (`SpanName.split`); empty on
    /// the one-page path, whose names carry no page.
    var pageIds: Set<String>
    /// Steps of one group are dropped together. In 1.3 only a lasso move across pages of the window has
    /// one (its source and destination pages); 1.5 uses it for an event's undo and its handwriting.
    var group: UUID?
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
/// - 1.3 (docs/M7C_CONTRACT.md §3.3, §4.4): the same ledger edits the window of joined pages (the
///   virtual page of `SpanComposer.compose` with a `SpanLayout`) once its owner sets `ownerId`. Then every
///   id it makes carries its owner page, each step goes to `journal`, only a live id is tombstoned, a
///   removal that is not the eraser's or takes too many strokes is refused, and each history step knows
///   its pages and group. With `ownerId` nil (the one-page path) none of that runs and the ledger does
///   what it did in 1.2.3, call for call (the same `makeId` and `nowMs` calls in the same order).
@MainActor
final class InkLedger {
    static let historyLimit = 200
    /// 1.3 (§3.16, §3.4 削除の守り (b)): one change of the joined path that would tombstone more than this
    /// many strokes is refused (`applyCanvasChange`).
    static let removalLimit = 50
    /// 1.3 (§3.16): … as is one that would tombstone at least half of a window page's live strokes, when
    /// that is at least this many.
    static let pageRemovalLimit = 20

    /// Called with a message when a page / layout pair with different ids reaches the ledger. The
    /// default is `assertionFailure` (contract §2.1: assert in Debug, ignore in Release); the unit
    /// tests replace it to exercise the ignore path.
    static var onPageMismatch: (String) -> Void = { message in assertionFailure(message) }

    private(set) var page: InkPage
    private(set) var layout: any PageLayout
    /// Written into `InkStroke.dev` of new strokes (the app passes `identifierForVendor`).
    var deviceId: String?
    /// The id of every stroke the ledger makes: a new stroke (`makeInkStroke`), a moved clone
    /// (`moveStrokes`) and an undo's clone (`perform`). 1.1 (M7A_CONTRACT §0, §7.2): the tests seed it
    /// (`testLedgerWritesTheCompatShapes`); the default is a fresh lower-case UUID, as before.
    var makeId: () -> String = { InkStroke.newId() }
    /// "Now" in ms since the epoch for tombstones, moved clones' `t` and the fallback `t` of a new
    /// stroke (`applyCanvasChange`, `moveStrokes`, `perform`, `removeStrokes`). The tests pin it; the
    /// default is the wall clock, as before.
    var nowMs: () -> Int = { InkLedger.wallClockMs() }
    /// 1.3 (docs/M7C_CONTRACT.md §3.3 1): the id of every stroke the ledger makes on the joined path, for
    /// the stroke's window cell ("<page>|<cell>"): the owner page in front of a fresh id
    /// (`SpanName.prefixed(id:page:)`). When set it replaces `makeId` at all three places that make an id —
    /// a new stroke (`makeInkStroke`, the cell `layout.inkCell` gave), a lasso's moved copy (`moveStrokes`,
    /// the destination cell) and ↶'s copy (`perform`, the stroke's cell) — so every stroke finds its real
    /// page by its id alone (`SpanComposer.deltas`, `unroutedNames`). nil (the one-page path): `makeId`, as
    /// before. Setting it is what puts the ledger on the joined path (see the type's note).
    var ownerId: ((CellKey) -> String)? = nil
    /// 1.3 (§3.3 2, §3.4): what each change did to the page, oldest first, with the window's names: the
    /// strokes it added and the ids it tombstoned, each live a moment before (`SpanJournalEntry`), and the
    /// group of its history step. `applyCanvasChange`, `perform` (↶ ↷, one entry per add or remove it does),
    /// `removeStrokes` and `moveStrokes` write it; the owner turns it into `PageDelta`s
    /// (`SpanComposer.deltas` with its aliases) and empties it. Written only on the joined path (`ownerId`
    /// set): on the one-page path no one reads it, so it stays empty and costs nothing.
    var journal: [SpanJournalEntry] = []
    /// 1.3 (§4.4): the group mark of a lasso move across pages. The tests seed it, like `makeId`.
    var makeGroup: () -> UUID = { UUID() }

    /// Fingerprint → stroke id for every stroke that is currently *in the canvas drawing*.
    private var fingerprintToId: [StrokeFingerprint: String] = [:]
    /// Ids in the order `drawing()` emitted them (lets `bind(to:)` re-key from the canvas's copy).
    private var builtIds: [String] = []
    /// Steps to perform to undo (newest last) and to redo (newest last).
    private var undoStack: [InkHistoryStep] = []
    private var redoStack: [InkHistoryStep] = []

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

    /// 1.1 (M7A_CONTRACT §3.6): takes `layout` without building a drawing, for a layout in which only
    /// the height of the page's last cell changed (`PaperGrowth.onlyTailHeightChanged`). Every cell
    /// keeps its origin, so the strokes' transforms and the fingerprint map stay valid; the new layout
    /// is still needed for `needsMoreRoom`, `inkCell` and `moveStrokes`. A layout of another page is
    /// ignored (reported through `onPageMismatch`, like `relayout`).
    func adopt(_ layout: any PageLayout) {
        guard layout.pageId == page.pageId else {
            Self.onPageMismatch("InkLedger.adopt: layout \(layout.pageId) does not belong to page \(page.pageId)")
            return
        }
        self.layout = layout
    }

    // MARK: PKDrawing → ledger

    /// Diffs the canvas against the map. New strokes get a UUID and a cell (the layout's
    /// `inkCell(forCenter:)` of the centre of their paper-space bounds, which never fails);
    /// erased strokes get tombstones.
    ///
    /// 1.3 (docs/M7C_CONTRACT.md §3.3 5, §3.4 削除の守り): on the joined path, when `allowRemovals` is false
    /// (the tool is not the eraser) or the change would tombstone too many strokes at once (more than
    /// `removalLimit`, or at least half of a window page's live strokes and at least `pageRemovalLimit`,
    /// §3.16), nothing is tombstoned: the lost ids come back in `refusedRemovals` (`needsRebuild`) and the
    /// new strokes are still taken in. On the joined path only an id live in the page is tombstoned (a lost
    /// id that is not is only forgotten and comes back in `alreadyErased` or `unknownRemovals`), and the
    /// change goes to `journal`. The one-page path (`ownerId` nil) ignores `allowRemovals` and takes every
    /// removal, as 1.2.3 does (§3.3 5: 「1 ページの道は今どおり（常に許す）」).
    func applyCanvasChange(_ drawing: PKDrawing, allowRemovals: Bool = true) -> InkChange {
        var seen = Set<StrokeFingerprint>()
        var added: [InkStroke] = []
        var addedFingerprints: [(StrokeFingerprint, String)] = []
        let now = nowMs()
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
        // 1.3 (§3.3 5): on the joined path, a removal the ledger does not take (see above) leaves the page,
        // the map and the history as they are; the canvas rebuilds its drawing from the ledger.
        var refused: [String] = []
        if !removedIds.isEmpty, ownerId != nil, !allowRemovals || removesTooMany(removed) {
            refused = removedIds
            removedIds = []
            removed = []
            if added.isEmpty { return InkChange(added: [], removedIds: [], refusedRemovals: refused) }
        }
        // 1.3 (§3.4 削除の守り (a), B_DESIGN.md §2.4 6 (a)): on the joined path a lost id that is not live is
        // neither tombstoned nor journalled (its tombstone would reach its page and win there), only forgotten,
        // and returned: tombstoned already, or unknown to the page.
        var dead: [String] = []
        var alreadyErased: [String] = []
        var unknown: [String] = []
        if ownerId != nil {
            dead = removedIds.filter { !page.isLive($0) }
            alreadyErased = dead.filter { page.deleted[$0] != nil }
            unknown = dead.filter { page.deleted[$0] == nil }
            removedIds.removeAll { !page.isLive($0) }
            removed.removeAll { !page.isLive($0.id) }
            if added.isEmpty && removedIds.isEmpty {
                forget(ids: dead)
                return InkChange(added: [], removedIds: [], alreadyErased: alreadyErased, unknownRemovals: unknown)
            }
        }

        for s in added { page.add(s) }
        if !removedIds.isEmpty { page.remove(ids: removedIds, at: now) }
        record(added: added, removed: removedIds, at: now)

        for id in removedIds {
            builtIds.removeAll { $0 == id }
        }
        fingerprintToId = fingerprintToId.filter { !removedIds.contains($0.value) }
        if !dead.isEmpty { forget(ids: dead) }
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

        return InkChange(added: added, removedIds: removedIds, refusedRemovals: refused, alreadyErased: alreadyErased,
                         unknownRemovals: unknown)
    }

    /// 1.3 (§3.16): would tombstoning `strokes` (live strokes of the window, one canvas change) take too
    /// many at once: more than `removalLimit`, or, on one of the window's pages, at least
    /// `pageRemovalLimit` and at least half of that page's live strokes? A stroke's page is the one its id
    /// carries (else its cell's); a stroke with neither counts only toward `removalLimit`.
    private func removesTooMany(_ strokes: [InkStroke]) -> Bool {
        guard strokes.count >= Self.pageRemovalLimit else { return false }
        if strokes.count > Self.removalLimit { return true }
        var taken: [String: Int] = [:]
        for stroke in strokes {
            if let owner = Self.page(of: stroke) { taken[owner, default: 0] += 1 }
        }
        taken = taken.filter { $0.value >= Self.pageRemovalLimit }
        guard !taken.isEmpty else { return false }
        var live: [String: Int] = [:]
        for stroke in page.strokes.values where page.deleted[stroke.id] == nil {
            if let owner = Self.page(of: stroke), taken[owner] != nil { live[owner, default: 0] += 1 }
        }
        return taken.contains { owner, count in count * 2 >= live[owner, default: 0] }
    }

    /// True when the stroke's bottom needs more room than its cell currently has (the cell must
    /// grow). Always false for a cell that does not grow with ink (the week / day time grid, contract
    /// §1.10): writing there never triggers a relayout. 1.1 (M7A_CONTRACT 0-2): the rule is
    /// `PaperGrowth.needsMoreRoom`, the same function the layout engines grow the cells with — the
    /// page's last cell (the month's memo area, the day's free memo area below 24:00) by
    /// `PaperGrowth.tailHeight` (open to 6,000 lu from the start since 1.1.1), the other cells by
    /// `bottom + 12`. 1.3 (docs/M7C_CONTRACT.md §3.3 4): `PaperGrowth` reads the page's own name of the
    /// cell, so a window's prefix is taken off first (with it, the memo area and the free memo area would
    /// not grow until the stroke reached their very bottom); a name without one is passed as it is.
    func needsMoreRoom(_ stroke: InkStroke) -> Bool {
        guard layout.growsWithInk(stroke.cell), let cell = layout.cells[stroke.cell] else { return false }
        return PaperGrowth.needsMoreRoom(cell: SpanName.strip(stroke.cell), cellHeight: cell.height, inkBottom: stroke.bottom)
    }

    // MARK: History

    /// Performs the newest undo op; returns the rebuilt drawing (nil when there is nothing to undo).
    func undo() -> PKDrawing? {
        guard let step = undoStack.popLast() else { return nil }
        if let inverse = perform(step.op, group: step.group) {
            redoStack.append(historyStep(inverse, group: step.group))
            Self.trim(&redoStack)
        }
        return drawing()
    }

    /// Performs the newest redo op; returns the rebuilt drawing (nil when there is nothing to redo).
    func redo() -> PKDrawing? {
        guard let step = redoStack.popLast() else { return nil }
        if let inverse = perform(step.op, group: step.group) {
            undoStack.append(historyStep(inverse, group: step.group))
            Self.trim(&undoStack)
        }
        return drawing()
    }

    /// 1.1 (M7A_CONTRACT §2.4, 0-22): undoes what one touch of the eraser erased, and nothing else.
    /// Only when the newest undo op puts back exactly the strokes `ids` (an `.add` of them, what
    /// `applyCanvasChange` pushes for an erasure) — or, when PencilKit reported that touch's erasure
    /// in several changes, when the newest ops are all such `.add`s and together put back exactly
    /// `ids`. Then those ops are undone like ↶ (the strokes come back as clones with new ids,
    /// `perform`) and the rebuilt drawing is returned. nil (nothing changes) for empty `ids` or when
    /// the top of the stack is any other op: a stroke drawn, a move, a deletion of other strokes.
    func undoIfTopRestores(ids: Set<String>) -> PKDrawing? {
        guard !ids.isEmpty else { return nil }
        var remaining = ids
        var count = 0
        for step in undoStack.reversed() {
            guard case .add(let strokes) = step.op else { break }
            let opIds = Set(strokes.map { $0.id })
            guard !opIds.isEmpty, opIds.isSubset(of: remaining) else { break }
            remaining.subtract(opIds)
            count += 1
            if remaining.isEmpty { break }
        }
        guard remaining.isEmpty, count > 0 else { return nil }
        var rebuilt: PKDrawing?
        for _ in 0..<count {
            rebuilt = undo()
        }
        return rebuilt
    }

    private func push(undo op: InkOp, group: UUID? = nil) {
        undoStack.append(historyStep(op, group: group))
        Self.trim(&undoStack)
    }

    private static func trim(_ stack: inout [InkHistoryStep]) {
        if stack.count > historyLimit {
            stack.removeFirst(stack.count - historyLimit)
        }
    }

    /// 1.3 (§4.4): `op` as a history step with its pages (on the joined path; none on the one-page path,
    /// whose names carry no page) and `group`.
    private func historyStep(_ op: InkOp, group: UUID?) -> InkHistoryStep {
        InkHistoryStep(op: op, pageIds: ownerId == nil ? [] : Self.pages(of: op), group: group)
    }

    /// 1.3 (docs/M7C_CONTRACT.md §3.3 3, §3.10, §4.4): before pages leave the window, the history forgets
    /// every step that touches one of `pageIds` together with every step that could only be undone (or
    /// redone) after it — the older steps of ↶, the ones behind it on ↷ — and every step of a group one of
    /// the forgotten steps had, again with what lies behind it. So no step is ever half undone and no ↶ ↷
    /// makes a copy for a page the window no longer holds (its delta would find no page, §3.4 (d)). A step
    /// touches the pages in front of its strokes' ids and cells (`InkHistoryStep.pageIds`; a name without a
    /// page touches none, so the one-page path's history is never touched). Nothing for an empty set.
    func pruneHistory(touching pageIds: Set<String>) {
        guard !pageIds.isEmpty else { return }
        var undoCut = 0
        var redoCut = 0
        var groups = Set<UUID>()
        while true {
            let undo = Self.cut(undoStack, atLeast: undoCut, touching: pageIds, groups: groups)
            let redo = Self.cut(redoStack, atLeast: redoCut, touching: pageIds, groups: groups)
            guard undo != undoCut || redo != redoCut else { break }
            undoCut = undo
            redoCut = redo
            for step in undoStack[..<undoCut] + redoStack[..<redoCut] {
                if let group = step.group { groups.insert(group) }
            }
        }
        undoStack.removeFirst(undoCut)
        redoStack.removeFirst(redoCut)
    }

    /// How many steps from the bottom of `stack` (the far end of its history) go: all of them up to the
    /// newest one that touches `pageIds` or belongs to one of `groups`; never fewer than `current`.
    private static func cut(_ stack: [InkHistoryStep], atLeast current: Int, touching pageIds: Set<String>, groups: Set<UUID>) -> Int {
        let last = stack.lastIndex { step in
            !step.pageIds.isDisjoint(with: pageIds) || step.group.map { groups.contains($0) } == true
        }
        guard let last else { return current }
        return max(current, last + 1)
    }

    /// The real pages of an op's strokes (`pages(of:)` of each).
    private static func pages(of op: InkOp) -> Set<String> {
        switch op {
        case .add(let strokes), .remove(let strokes):
            return Set(strokes.flatMap { stroke -> [String] in
                [SpanName.split(stroke.id)?.page, SpanName.split(stroke.cell.raw)?.page].compactMap { $0 }
            })
        case .batch(let ops):
            return ops.reduce(into: Set<String>()) { $0.formUnion(pages(of: $1)) }
        }
    }

    /// The real page a stroke of the window belongs to: the one in front of its id, else of its cell (they
    /// agree for every stroke the ledger makes); nil for names without one.
    private static func page(of stroke: InkStroke) -> String? {
        SpanName.split(stroke.id)?.page ?? SpanName.split(stroke.cell.raw)?.page
    }

    /// Applies `op` to the page and returns the op that reverses what actually happened
    /// (nil when nothing changed). Re-adding a stroke whose id is tombstoned or still live adds a
    /// clone with a fresh id instead. 1.3: the clone's id is `ownerId`'s for the stroke's cell on the
    /// joined path (§3.3 1), and each add and remove goes to `journal` with the step's `group`.
    private func perform(_ op: InkOp, group: UUID? = nil) -> InkOp? {
        let now = nowMs()
        switch op {
        case .add(let strokes):
            var actuallyAdded: [InkStroke] = []
            for var s in strokes {
                guard !s.points.isEmpty else { continue }
                if page.deleted[s.id] != nil || page.strokes[s.id] != nil {
                    s.id = ownerId?(s.cell) ?? makeId()
                }
                page.add(s)
                if page.strokes[s.id] != nil { actuallyAdded.append(s) }
            }
            record(added: actuallyAdded, removed: [], at: now, group: group)
            return actuallyAdded.isEmpty ? nil : .remove(actuallyAdded)
        case .remove(let strokes):
            let present = strokes.filter { page.strokes[$0.id] != nil && page.deleted[$0.id] == nil }
            guard !present.isEmpty else { return nil }
            let ids = present.map { $0.id }
            page.remove(ids: ids, at: now)
            record(added: [], removed: ids, at: now, group: group)
            return .add(present)
        case .batch(let ops):
            var inverses: [InkOp] = []
            for sub in ops {
                if let inv = perform(sub, group: group) { inverses.append(inv) }
            }
            if inverses.isEmpty { return nil }
            return inverses.count == 1 ? inverses[0] : .batch(inverses.reversed())
        }
    }

    /// 1.3 (§3.3 2): one journal entry on the joined path: the strokes of `added` that are in the page now
    /// and the ids of `removed` (each live a moment ago; the callers pass only those). Nothing on the
    /// one-page path (`ownerId` nil) or for an empty change.
    private func record(added: [InkStroke], removed: [String], at: Int, group: UUID? = nil) {
        guard ownerId != nil else { return }
        let landed = added.filter { page.isLive($0.id) }
        guard !landed.isEmpty || !removed.isEmpty else { return }
        journal.append(SpanJournalEntry(added: landed, removed: removed, at: at, group: group))
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
        let now = nowMs()
        page.remove(ids: removedIds, at: now)
        record(added: [], removed: removedIds, at: now)
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
    /// 1.3 (docs/M7C_CONTRACT.md §3.3 1, §3.10, §4.4): on the joined path a clone's id is `ownerId`'s for
    /// its destination cell (another page of the window when it was dragged there), and a move whose
    /// originals and clones are on more than one page is one undo group (`makeGroup`), in its history step
    /// and its journal entry.
    func moveStrokes(ids: [String], by delta: CGVector) -> (change: InkChange, newIds: [String]) {
        let nothing = (change: InkChange(added: [], removedIds: []), newIds: [String]())
        guard delta.dx.isFinite, delta.dy.isFinite, delta.dx != 0 || delta.dy != 0 else { return nothing }
        let originals = strokes(ids: ids)
        guard !originals.isEmpty else { return nothing }
        let now = nowMs()
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
            clones.append(s.translated(by: delta, from: origin, to: newCell, newCellOrigin: newOrigin, id: ownerId?(newCell) ?? makeId(), at: now))
        }
        let removedIds = originals.map { $0.id }
        page.remove(ids: removedIds, at: now)
        for c in clones { page.add(c) }
        forget(ids: removedIds)
        let group: UUID? = ownerId != nil && Self.pages(of: .batch([.add(originals), .add(clones)])).count > 1 ? makeGroup() : nil
        record(added: clones, removed: removedIds, at: now, group: group)
        // Undo = put the originals back (as clones with fresh ids: their ids are tombstoned now) and
        // take the moved copies away. One batch, one tap of ↶ (DESIGN §3.13).
        push(undo: .batch([.add(originals), .remove(clones)]), group: group)
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
            id: ownerId?(cell) ?? makeId(),
            cell: cell,
            tool: tool,
            color: color,
            t: t > 0 ? t : now,
            dev: deviceId,
            points: StrokeGeometry.cellRelativePoints(pk, cellOrigin: origin)
        )
    }

    /// The wall clock in ms since the epoch (the default of `nowMs`).
    nonisolated static func wallClockMs() -> Int {
        Int((Date().timeIntervalSince1970 * 1000).rounded())
    }
}
