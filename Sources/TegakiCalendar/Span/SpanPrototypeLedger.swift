#if SPAN_PROTOTYPE
import CoreGraphics
import Foundation
@_spi(SpanLedger) import InkModel
import Layout
import PencilKit

// The prototype's copy of the ledger (1.3, docs/M7C_CONTRACT.md D12, §3.3, §4.6): `InkLedger` of 43fe366
// (Ink/InkLedger.swift) with the type renamed, changed only where the window of joined pages needs it.
// Ink/InkLedger.swift itself stays byte for byte (it is one of the frozen files until the prototype has
// gone up, §6.4); this file is compiled only into the prototype build (`SPAN_PROTOTYPE`, which only the
// xcodebuild command line sets) and goes away when the real ledger has the window (S6).
//
// What differs from `InkLedger` (and nothing else):
// - the ledger edits a window's virtual page: `init(window:layout:)` and `reload(window:keepHistory:)`
//   take a `SpanVirtualPage` (its `ledgerPage` is SPI, hence the import above) and keep its aliases;
// - §3.3 1: the three places that make an id — a new stroke (`makeInkStroke`), a lasso's moved copy
//   (`moveStrokes`) and ↶'s copy (`perform`) — make it with `ownerId`: "<owner page>|<fresh id>", the
//   owner being the page the stroke's cell names, so every stroke finds its way back to its real page;
// - §3.3 2: a journal of what each step did (`SpanJournalEntry`), a removal only for an id that was live
//   in the virtual page at that moment (and the canvas's diff tombstones nothing else, §3.4 削除の守り
//   (a)), turned into one `PageDelta` per real page by `takeDeltas` with the window's aliases
//   (`SpanComposer.deltas` and `unroutedNames` over the same journal);
// - §3.3 4: `needsMoreRoom` asks `PaperGrowth` with the page's own cell name (the prefix taken off);
// - §3.3 3: `pruneHistory(touching:)` forgets the steps of pages that leave the window (the canvas calls it
//   before the window is composed again around other pages, §3.6).
// The helper types `InkChange`, `StrokeGeometry` and `InkOp` are the ones of Ink/InkLedger.swift.

// This file deliberately imports no UIKit so it can be type-checked against the macOS SDK on a Mac
// without Xcode (docs/M2_CONTRACT.md §8, M3A_CONTRACT.md §2.2). Colours go through InkColors (InkTools.swift).

// MARK: - Ledger

/// The ledger of one window's handwriting and its bridge to `PKCanvasView` (DESIGN.md §3.3–3.5, §3.13).
/// Works for the window's virtual page through `SpanLayout` (a `PageLayout`): the layout owns the cell
/// rectangles ("<pageId>|<cell>"), the cell a new stroke belongs to (that of the page under its centre),
/// and which cells grow.
///
/// - `drawing()` turns the ledger into a `PKDrawing`: each stroke keeps its cell-relative control
///   points and is placed with a translation `transform` to its cell's top-left corner.
/// - `applyCanvasChange(_:)` diffs what the canvas holds against a fingerprint → id map: strokes the
///   canvas has that the map does not are new (they get an owner id and a cell); strokes the map has that
///   the canvas lost were erased (they get a tombstone).
/// - History is the ledger's own (add / remove ops, newest 200). Undoing a deletion re-adds *clones
///   with new ids*, because a tombstoned id can never come back (same rule as the web version).
/// - Every step is written to `journal`; the owner takes it as deltas of the real pages
///   (`takeDeltas`) right after the step (§3.4 (a)).
/// - The ledger never mixes pages: `page.pageId == layout.pageId` always holds. A `reload` or
///   `relayout` with another page id is a programming error of the owner; it is reported through
///   `onPageMismatch` (an assertion in Debug) and ignored.
/// - Every page that enters the ledger (`init`, `reload`) goes through `BandMigration.migrate`
///   (M4B_CONTRACT §3.3; the window's prefixed cells are no band cells, so it changes nothing there:
///   `SpanComposer.compose` migrated each real page before it put them together).
@MainActor
final class SpanPrototypeLedger {
    static let historyLimit = 200

    /// Called with a message when a page / layout pair with different ids reaches the ledger. The
    /// default is `assertionFailure` (contract §2.1: assert in Debug, ignore in Release); the unit
    /// tests replace it to exercise the ignore path.
    static var onPageMismatch: (String) -> Void = { message in assertionFailure(message) }

    private(set) var page: InkPage
    private(set) var layout: any PageLayout
    /// Written into `InkStroke.dev` of new strokes (the app passes `identifierForVendor`).
    var deviceId: String?
    /// The fresh part of every id the ledger makes (`ownerId` puts the owner page in front of it). The
    /// tests seed it; the default is a fresh lower-case UUID, as `InkLedger`'s.
    var makeId: () -> String = { InkStroke.newId() }
    /// §3.3 1: the id of a stroke the ledger makes for `cell` — "<owner page>|<makeId()>", the owner being
    /// the page the window's cell name starts with (`SpanName.split`). A cell that names no page (never in
    /// a `SpanLayout`) gets a bare `makeId()`, which reaches no real page: the session finds it in
    /// `takeDeltas`'s `unrouted` and records it.
    var ownerId: ((CellKey) -> String)?
    /// "Now" in ms since the epoch for tombstones, moved clones' `t` and the fallback `t` of a new
    /// stroke (`applyCanvasChange`, `moveStrokes`, `perform`, `removeStrokes`). The tests pin it; the
    /// default is the wall clock, as before.
    var nowMs: () -> Int = { SpanPrototypeLedger.wallClockMs() }

    /// The window's aliases of long ids (`SpanVirtualPage.aliases`): `takeDeltas` gives every id back to
    /// its real page with them.
    private(set) var aliases: SpanAliases
    /// §3.3 2: what each step did to the virtual page, oldest first, until `takeDeltas` takes it.
    private(set) var journal: [SpanJournalEntry] = []
    /// What the step being performed (`undo` / `redo`, whose ops may be a batch) did so far.
    private var stepAdded: [InkStroke] = []
    private var stepRemoved: [String] = []

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
    init(page: InkPage, layout: any PageLayout, aliases: SpanAliases, deviceId: String? = nil) {
        if page.pageId == layout.pageId {
            self.page = BandMigration.migrate(page)
        } else {
            Self.onPageMismatch("SpanPrototypeLedger: page \(page.pageId) does not belong to layout \(layout.pageId)")
            self.page = InkPage.empty(pageId: layout.pageId)
        }
        self.layout = layout
        self.aliases = aliases
        self.deviceId = deviceId
        ownerId = { [unowned self] cell in self.ownerName(for: cell) }
    }

    /// The window's virtual page (`SpanComposer.compose`) with its layout (the `SpanLayout` of the same
    /// session, whose `pageId` is the virtual id).
    convenience init(window: SpanVirtualPage, layout: SpanLayout, deviceId: String? = nil) {
        self.init(page: window.ledgerPage, layout: layout, aliases: window.aliases, deviceId: deviceId)
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
            Self.onPageMismatch("SpanPrototypeLedger.reload: page \(page.pageId) does not belong to layout \(layout.pageId)")
            return
        }
        self.page = BandMigration.migrate(page)
        if !keepHistory {
            undoStack.removeAll()
            redoStack.removeAll()
        }
    }

    /// The window composed again (the same session, so the same virtual id): its page and its aliases
    /// (the session's table only grows, so the names already in the journal keep their meaning).
    func reload(window: SpanVirtualPage, keepHistory: Bool) {
        guard window.pageId == layout.pageId else {
            Self.onPageMismatch("SpanPrototypeLedger.reload: window \(window.pageId) does not belong to layout \(layout.pageId)")
            return
        }
        aliases = window.aliases
        reload(page: window.ledgerPage, keepHistory: keepHistory)
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
            Self.onPageMismatch("SpanPrototypeLedger.relayout: layout \(layout.pageId) does not belong to page \(page.pageId)")
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
            Self.onPageMismatch("SpanPrototypeLedger.adopt: layout \(layout.pageId) does not belong to page \(page.pageId)")
            return
        }
        self.layout = layout
    }

    // MARK: PKDrawing → ledger

    /// Diffs the canvas against the map. New strokes get an owner id and a cell (the layout's
    /// `inkCell(forCenter:)` of the centre of their paper-space bounds, which never fails);
    /// erased strokes get tombstones.
    func applyCanvasChange(_ drawing: PKDrawing) -> InkChange {
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

        // §3.4 削除の守り (a), B_DESIGN.md §2.4 6 (a): only an id that is live in the virtual page now is
        // tombstoned and journalled (`InkLedger` tombstones every id the canvas lost; a tombstone of an id
        // that is not live would reach its page through the safety net and win over the stroke there).
        let liveRemoved = removedIds.filter { page.isLive($0) }
        for s in added { page.add(s) }
        if !liveRemoved.isEmpty { page.remove(ids: liveRemoved, at: now) }
        record(added: added.filter { page.strokes[$0.id] != nil }, removed: liveRemoved, at: now)

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
    /// §1.10): writing there never triggers a relayout. 1.1 (M7A_CONTRACT 0-2): the rule is
    /// `PaperGrowth.needsMoreRoom`, the same function the layout engines grow the cells with — the
    /// page's last cell (the month's memo area, the day's free memo area below 24:00) by
    /// `PaperGrowth.tailHeight` (open to 6,000 lu from the start since 1.1.1), the other cells by
    /// `bottom + 12`. §3.3 4: `PaperGrowth` reads the page's own name of the cell, so the prefix of the
    /// window is taken off first (with it, the memo area would not grow until its very bottom).
    func needsMoreRoom(_ stroke: InkStroke) -> Bool {
        guard layout.growsWithInk(stroke.cell), let cell = layout.cells[stroke.cell] else { return false }
        return PaperGrowth.needsMoreRoom(cell: SpanName.strip(stroke.cell), cellHeight: cell.height, inkBottom: stroke.bottom)
    }

    // MARK: History

    /// Performs the newest undo op; returns the rebuilt drawing (nil when there is nothing to undo).
    func undo() -> PKDrawing? {
        guard let op = undoStack.popLast() else { return nil }
        let now = nowMs()
        if let inverse = perform(op, now: now) {
            redoStack.append(inverse)
            Self.trim(&redoStack)
        }
        recordStep(at: now)
        return drawing()
    }

    /// Performs the newest redo op; returns the rebuilt drawing (nil when there is nothing to redo).
    func redo() -> PKDrawing? {
        guard let op = redoStack.popLast() else { return nil }
        let now = nowMs()
        if let inverse = perform(op, now: now) {
            undoStack.append(inverse)
            Self.trim(&undoStack)
        }
        recordStep(at: now)
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
        for op in undoStack.reversed() {
            guard case .add(let strokes) = op else { break }
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

    /// §3.3 3 (§3.6, §3.10): before the window is composed again without `pageIds`, the history forgets every
    /// step that touches one of those pages, and every step it would have to undo (or redo) after it — the
    /// older ones of ↶, the later ones of ↷ — so no step is ever half undone and no ↶ makes a copy for a page
    /// that is no longer in the window (its delta would find no page, §3.4 (d)). A stroke's page is the one
    /// its window cell names; a stroke whose cell names none is taken as touching. Nothing for an empty set.
    func pruneHistory(touching pageIds: Set<String>) {
        guard !pageIds.isEmpty else { return }
        Self.prune(&undoStack, touching: pageIds)
        Self.prune(&redoStack, touching: pageIds)
    }

    /// Drops the newest op of `stack` that touches `pageIds` and every op below it (the bottom of both
    /// stacks is the far end of the history).
    private static func prune(_ stack: inout [InkOp], touching pageIds: Set<String>) {
        guard let last = stack.lastIndex(where: { touches($0, pageIds) }) else { return }
        stack.removeFirst(last + 1)
    }

    private static func touches(_ op: InkOp, _ pageIds: Set<String>) -> Bool {
        switch op {
        case .add(let strokes), .remove(let strokes):
            return strokes.contains { stroke in
                guard let page = SpanName.split(stroke.cell.raw)?.page else { return true }
                return pageIds.contains(page)
            }
        case .batch(let ops):
            return ops.contains { touches($0, pageIds) }
        }
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
    /// clone with a fresh owner id instead. What it did goes to the step's journal entry (`recordStep`),
    /// whose time `now` is the one of every tombstone of the step (one clock reading per step, so a delta
    /// tombstones at the ledger's own time).
    private func perform(_ op: InkOp, now: Int) -> InkOp? {
        switch op {
        case .add(let strokes):
            var actuallyAdded: [InkStroke] = []
            for var s in strokes {
                guard !s.points.isEmpty else { continue }
                if page.deleted[s.id] != nil || page.strokes[s.id] != nil {
                    s.id = newId(for: s.cell)
                }
                page.add(s)
                if page.strokes[s.id] != nil { actuallyAdded.append(s) }
            }
            stepAdded += actuallyAdded
            return actuallyAdded.isEmpty ? nil : .remove(actuallyAdded)
        case .remove(let strokes):
            let present = strokes.filter { page.strokes[$0.id] != nil && page.deleted[$0.id] == nil }
            guard !present.isEmpty else { return nil }
            page.remove(ids: present.map { $0.id }, at: now)
            stepRemoved += present.map { $0.id }
            return .add(present)
        case .batch(let ops):
            var inverses: [InkOp] = []
            for sub in ops {
                if let inv = perform(sub, now: now) { inverses.append(inv) }
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
        let now = nowMs()
        page.remove(ids: removedIds, at: now)
        record(added: [], removed: removedIds, at: now)
        forget(ids: removedIds)
        push(undo: .add(present))
        redoStack.removeAll()
        return InkChange(added: [], removedIds: removedIds)
    }

    /// Moves the selection: the originals get tombstones and clones translated by `delta` (paper lu)
    /// are added with **new owner ids** (`t` = now), as **one** batch op. A clone's cell is decided again
    /// from the centre of its moved bounds with `layout.inkCell(forCenter:)` (DESIGN §3.7), so a
    /// stroke dragged onto another day — or another page of the window — belongs to that day and page.
    /// `newIds` follows the order of `ids` (originals that were not live are dropped). Nothing happens
    /// for a zero or non-finite delta or when no original is live. The caller puts `drawing()` on the
    /// canvas afterwards.
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
            clones.append(s.translated(by: delta, from: origin, to: newCell, newCellOrigin: newOrigin, id: newId(for: newCell), at: now))
        }
        let removedIds = originals.map { $0.id }
        page.remove(ids: removedIds, at: now)
        for c in clones { page.add(c) }
        record(added: clones.filter { page.strokes[$0.id] != nil }, removed: removedIds, at: now)
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

    // MARK: The window (§3.3 1, 2)

    /// The id of a stroke the ledger makes for `cell`: `ownerId`'s, else a bare `makeId()`.
    private func newId(for cell: CellKey) -> String {
        ownerId?(cell) ?? makeId()
    }

    /// `ownerId`'s rule: "<the page the cell names>|<makeId()>"; a bare `makeId()` for a cell that names
    /// no page.
    private func ownerName(for cell: CellKey) -> String {
        let fresh = makeId()
        guard let parts = SpanName.split(cell.raw) else { return fresh }
        return SpanName.prefixed(id: fresh, page: parts.page)
    }

    /// One journal entry: the strokes added, the ids tombstoned (each live a moment ago). Nothing for an
    /// empty step.
    private func record(added: [InkStroke], removed: [String], at: Int) {
        guard !added.isEmpty || !removed.isEmpty else { return }
        journal.append(SpanJournalEntry(added: added, removed: removed, at: at))
    }

    /// The journal entry of an undo / redo step (`perform` collected it).
    private func recordStep(at: Int) {
        record(added: stepAdded, removed: stepRemoved, at: at)
        stepAdded = []
        stepRemoved = []
    }

    /// Empties the journal into one delta per real page per step (`SpanComposer.deltas`, with the window's
    /// aliases and the session's `epoch`) and the names among them that tell no page
    /// (`SpanComposer.unroutedNames` over the same journal and aliases; empty while every id is an owner
    /// id, §3.4 (d)).
    func takeDeltas(epoch: Int) -> (deltas: [PageDelta], unrouted: [String]) {
        let entries = journal
        journal = []
        guard !entries.isEmpty else { return ([], []) }
        return (SpanComposer.deltas(from: entries, epoch: epoch, aliases: aliases),
                SpanComposer.unroutedNames(in: entries, aliases: aliases))
    }

    // MARK: Conversions

    private static func makePKStroke(_ stroke: InkStroke, cellOrigin: CGPoint, avoiding map: [StrokeFingerprint: String]) -> PKStroke {
        StrokeGeometry.makePKStroke(stroke, cellOrigin: cellOrigin, avoiding: map)
    }

    private func makeInkStroke(from pk: PKStroke, now: Int) -> InkStroke {
        let bounds = StrokeGeometry.paperBounds(of: pk)
        // The layout decides the cell, including every fallback (off the paper, the time gutter of
        // the week / day page, the date gutter of the year page: contract §1.6–1.8); in the window the
        // page under the centre (D15). The point may then be left of or above the cell, so
        // cell-relative coordinates can be negative.
        let cell = layout.inkCell(forCenter: CGPoint(x: bounds.midX, y: bounds.midY))
        let origin = layout.cells[cell]?.origin ?? .zero
        let tool = InkModel.InkTool(inkType: pk.ink.inkType)
        let color = InkColors.hex(of: pk.ink.color) ?? InkPresets.fallbackColorHex(for: tool)
        // `t` doubles as the creation date of the rebuilt path (`InkStroke.inkStart` derives from it).
        let t = Int((pk.path.creationDate.timeIntervalSince1970 * 1000).rounded())
        return InkStroke(
            id: newId(for: cell),
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
#endif
