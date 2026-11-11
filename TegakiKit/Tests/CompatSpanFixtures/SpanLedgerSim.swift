import Foundation
import CoreGraphics
@_spi(SpanLedger) import InkModel
import Layout
import CompatFixtures

/// What the canvas's ledger does to the window's virtual page in the joined path (docs/M7C_CONTRACT.md
/// §3.3), as plain values, so KitChecks and the compat-span fixtures go through the Kit's path
/// (`SpanComposer` → `PageDelta` → `InkPage.add` / `remove`) without the app: a new stroke gets the cell
/// `SpanLayout.inkCell(forCenter:)` gives (the owner page's own cell, prefixed) and the id `ownerId` gives
/// ("<owner page>|<fresh id>", §3.3 1); an erase tombstones and journals only the ids that are live
/// (§3.3 2); the lasso's move makes copies with fresh ids in the cells under the moved centres and
/// tombstones the originals (`InkLedger.moveStrokes`, K-2); ↶ puts an erased stroke back as a copy with a
/// fresh id (`InkLedger.perform`). Ids come from a seed and the clock moves by 1 ms a step, so the bytes are
/// the same on every run.
public struct SpanLedgerSim {
    public let layout: SpanLayout?
    /// The window as composed (its alias table, its pages).
    public private(set) var virtual: SpanVirtualPage
    /// The ledger's page (the virtual id, window names).
    public private(set) var page: InkPage
    /// The steps since the last `takeJournal()`.
    public private(set) var journal: [SpanJournalEntry] = []
    public var ids: CompatFixtures.SeededIds
    /// The last time used (ms).
    public private(set) var clock: Int
    public let dev: String?

    public init(virtual: SpanVirtualPage, layout: SpanLayout? = nil, seed: UInt64, firstTime: Int, dev: String?) {
        self.virtual = virtual
        self.layout = layout
        page = virtual.ledgerPage
        ids = CompatFixtures.SeededIds(seed: seed)
        clock = firstTime - 1
        self.dev = dev
    }

    /// The window holding what the ledger has now (for `SpanComposer.extract`).
    public var current: SpanVirtualPage {
        virtual.with(ledgerPage: page)
    }

    public mutating func now() -> Int {
        clock += 1
        return clock
    }

    /// `ownerId` of §3.3 1: the owner page of the (prefixed) cell in front of a fresh id.
    public mutating func ownerId(_ cell: CellKey) -> String {
        let fresh = ids.next()
        guard let parts = SpanName.split(cell.raw) else { return fresh }
        return SpanName.prefixed(id: fresh, page: parts.page)
    }

    /// The journal so far, emptied.
    public mutating func takeJournal() -> [SpanJournalEntry] {
        defer { journal = [] }
        return journal
    }

    // MARK: Steps

    /// A new stroke through `points` (window lu): the centre of their bounds decides the owner and the cell
    /// (`SpanLayout.drop`); a stroke `drop` does not keep is not added (M4C-25) and gives nil. The points
    /// are stored relative to the cell, whatever page they reach into (§4.1).
    @discardableResult
    public mutating func draw(_ points: [CGPoint], size: CGFloat = 3.5, tool: InkTool = .pen, color: String = "#1f2937") -> InkStroke? {
        guard let layout = layout, !points.isEmpty else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let center = CGPoint(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
        guard case .keep(let owner, let local) = layout.drop(center: center) else { return nil }
        let cell = SpanName.prefixed(local, page: owner)
        precondition(cell == layout.inkCell(forCenter: center), "drop and inkCell disagree at \(center)")
        let origin = layout.cells[cell]?.origin ?? .zero
        let inkPoints = points.enumerated().map { i, p in
            InkPoint(x: p.x - origin.x, y: p.y - origin.y, dtMs: 8 * i, sizeW: size, sizeH: size,
                     opacity: 1, force: 0.5, azimuth: 0.785, altitude: 1.2)
        }
        return put(cell: cell, points: inkPoints, tool: tool, color: color)
    }

    /// A new stroke in a window cell with cell-relative points (what `draw` does after it found the cell).
    @discardableResult
    public mutating func put(cell: CellKey, points: [InkPoint], tool: InkTool = .pen, color: String = "#1f2937") -> InkStroke {
        let t = now()
        let stroke = InkStroke(id: ownerId(cell), cell: cell, tool: tool, color: color, t: t, dev: dev, points: points)
        page.add(stroke)
        journal.append(SpanJournalEntry(added: [stroke], at: t))
        return stroke
    }

    /// Erases the ids that are live in the ledger's page (the eraser, or the lasso's delete); the others
    /// are neither tombstoned nor journaled (§3.4 削除の守り (a)). Returns the ids it erased.
    @discardableResult
    public mutating func erase(_ windowIds: [String], group: UUID? = nil) -> [String] {
        let live = windowIds.filter { page.isLive($0) }
        guard !live.isEmpty else { return [] }
        let t = now()
        page.remove(ids: live, at: t)
        journal.append(SpanJournalEntry(removed: live, at: t, group: group))
        return live
    }

    /// The lasso's move by `delta` (window lu): copies with fresh owner ids in the cells under the moved
    /// centres, the originals tombstoned, one step. Returns the copies.
    @discardableResult
    public mutating func move(_ windowIds: [String], by delta: CGVector, group: UUID? = nil) -> [InkStroke] {
        guard let layout = layout else { return [] }
        let originals = windowIds.compactMap { id in page.isLive(id) ? page.strokes[id] : nil }
        guard !originals.isEmpty else { return [] }
        let t = now()
        var clones: [InkStroke] = []
        for s in originals {
            let origin = layout.cells[s.cell]?.origin ?? .zero
            let bounds = s.paperBounds(cellOrigin: origin) ?? CGRect(origin: origin, size: .zero)
            let moved = bounds.offsetBy(dx: delta.dx, dy: delta.dy)
            let newCell = layout.inkCell(forCenter: CGPoint(x: moved.midX, y: moved.midY))
            let newOrigin = layout.cells[newCell]?.origin ?? .zero
            clones.append(s.translated(by: delta, from: origin, to: newCell, newCellOrigin: newOrigin, id: ownerId(newCell), at: t))
        }
        page.remove(ids: originals.map(\.id), at: t)
        for c in clones { page.add(c) }
        journal.append(SpanJournalEntry(added: clones, removed: originals.map(\.id), at: t, group: group))
        return clones
    }

    /// A move to another place given by hand: the copy of each live stroke goes to `cell` (a window cell)
    /// with the same cell-relative points (the random edits' cross-page move). Returns the copies.
    @discardableResult
    public mutating func move(_ windowIds: [String], toCell cell: CellKey) -> [InkStroke] {
        let originals = windowIds.compactMap { id in page.isLive(id) ? page.strokes[id] : nil }
        guard !originals.isEmpty else { return [] }
        let t = now()
        let clones = originals.map { s in
            InkStroke(id: ownerId(cell), cell: cell, tool: s.tool, color: s.color, t: t, dev: s.dev, points: s.points)
        }
        page.remove(ids: originals.map(\.id), at: t)
        for c in clones { page.add(c) }
        journal.append(SpanJournalEntry(added: clones, removed: originals.map(\.id), at: t))
        return clones
    }

    /// ↶ of an erase: the stroke as it was, back as a copy with a fresh owner id (its own id is tombstoned).
    @discardableResult
    public mutating func undoCopy(_ stroke: InkStroke) -> InkStroke? {
        guard !stroke.points.isEmpty else { return nil }
        var s = stroke
        if page.deleted[s.id] != nil || page.strokes[s.id] != nil { s.id = ownerId(s.cell) }
        let t = now()
        page.add(s)
        guard page.strokes[s.id] != nil else { return nil }
        journal.append(SpanJournalEntry(added: [s], at: t))
        return s
    }
}

/// The screen's side of a window in the joined path (§3.4, §3.5), as plain values: a `PageSlot` per real
/// page (read pages go through `BandMigration.migrate` first, as `show` does), deltas applied with
/// `SpanComposer.apply` (never a page written back whole), the safety net, and the save through
/// `SpanGuard.checkForSave` and `InkPageCodec.encode`.
public struct SpanSlotsSim {
    public private(set) var slots: [String: InkPage]
    /// The pages that changed, in the order they first changed.
    public private(set) var dirty: [String] = []
    /// The ids each page got from deltas in this session (`checkForSave`'s `added`).
    public private(set) var added: [String: Set<String>] = [:]
    /// Pages the safety net had to bring something back to (none when every delta arrived).
    public private(set) var recovered: [String] = []

    public init(pages: [InkPage]) {
        var slots: [String: InkPage] = [:]
        for page in pages { slots[page.pageId] = BandMigration.migrate(page) }
        self.slots = slots
    }

    mutating func markDirty(_ pageId: String) {
        if !dirty.contains(pageId) { dirty.append(pageId) }
    }

    /// Applies each delta to its page's slot; a delta of a page that has no slot is not applied.
    public mutating func deliver(_ deltas: [PageDelta]) {
        for delta in deltas {
            guard let page = slots[delta.pageId] else { continue }
            let next = SpanComposer.apply(delta, to: page)
            added[delta.pageId, default: []].formUnion(delta.added.map(\.id))
            if next != page {
                slots[delta.pageId] = next
                markDirty(delta.pageId)
            }
        }
    }

    /// The safety net of every slot: the page's range of the window merged in; replaced (and dirty) only
    /// when the content differs.
    public mutating func safetyNet(_ virtual: SpanVirtualPage) {
        for pageId in virtual.pageIds {
            guard let page = slots[pageId] else { continue }
            let merged = InkPage.merge(page, SpanComposer.extract(pageId: pageId, from: virtual))
            precondition(merged.pageId == pageId, "the safety net changed the page id of \(pageId)")
            if merged.contentDiffers(from: page) {
                slots[pageId] = merged
                recovered.append(pageId)
                markDirty(pageId)
            }
        }
    }

    /// Changes a slot by hand (a test of the guard: a leak put into a slot).
    public mutating func edit(_ pageId: String, _ body: (inout InkPage) -> Void) {
        guard var page = slots[pageId] else { return }
        body(&page)
        slots[pageId] = page
        markDirty(pageId)
    }

    /// `PageSlot.persist` of a page: `SpanGuard.checkForSave` with the session's added ids, then the bytes
    /// the store would write (nil when refused).
    public func save(_ pageId: String, mode: SpanGuard.Mode = .release) -> (check: SpanGuard.SaveCheck, data: Data?) {
        guard let page = slots[pageId] else { return (.refused, nil) }
        let check = SpanGuard.checkForSave(page, added: added[pageId] ?? [], mode: mode)
        switch check {
        case .ok: return (check, try? InkPageCodec.encode(page))
        case .repaired(let fixed, _, _): return (check, try? InkPageCodec.encode(fixed))
        case .refused: return (check, nil)
        }
    }
}
