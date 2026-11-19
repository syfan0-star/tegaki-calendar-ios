import Foundation
import CoreGraphics

// The ink of the joined pages (1.3, docs/M7C_CONTRACT.md §2.1, §3.2, §3.4, §4.1, D4, D6, D7, D17, D21;
// B_DESIGN.md §2.4 3, 5, 6): the window's real pages are put together into one virtual page for the
// canvas's ledger (`SpanComposer.compose`), the ledger's journal comes back as one delta per real page
// (`deltas`), the screen applies each delta to its real page with today's `InkPage.add` / `remove`
// (`apply`; a page is never written back whole), and the safety net takes a page's range back out of the
// virtual page to merge into the real one (`extract`). Pure values: no clock, no files.
//
// Names in the window: every stroke id, cell, tombstone and unknown-tool key of real page P is
// "<P>|<name>" (`SpanName`); an id whose prefixed form is longer than 128 bytes (`InkPage.add` and
// `remove` would ignore it, `InkStroke.isValidId`) gets the alias "<P>|span~a~<n>" kept in `SpanAliases`.
// The cell of a stroke is always "<P>|<cell>". The unknown-tool objects keep their own "id" and "cell"
// (they are not drawn; only their keys are prefixed), so they come back byte for byte. Points are never
// touched: a point outside the paper (within InkPoint's ±100,000 lu) stays as it is, relative to its
// cell (§4.1).
//
// Everything goes back to its real page by its name alone (a prefix or an alias), added and removed
// alike: a tombstone has no cell, so a stroke routed by its cell could not be erased again. The ledger
// therefore makes every id of the joined path with `ownerId` ("<owner page>|<fresh id>": a new stroke,
// the copies of the lasso's move and of ↶, §3.3 1); a name that tells no page reaches no real page and
// `SpanComposer.unroutedNames` lists it for the session to record.

/// What one step of the ledger did to the virtual page (§2.1, §3.3 2): the strokes it added and the ids
/// it tombstoned, with the window's names (a prefixed id or an alias, a prefixed cell). The ledger records
/// a removal only for an id that was live in the virtual page at that moment (§3.4 削除の守り (a)).
public struct SpanJournalEntry: Sendable, Equatable {
    public var added: [InkStroke]
    public var removed: [String]
    /// The time of the step (ms): the tombstones' time, as the ledger's `page.remove(ids:at:)`.
    public var at: Int
    /// The undo group of the step (§4.4), nil when it stands alone.
    public var group: UUID?

    public init(added: [InkStroke] = [], removed: [String] = [], at: Int, group: UUID? = nil) {
        self.added = added
        self.removed = removed
        self.at = at
        self.group = group
    }
}

/// The change of one real page (§2.1, §3.4): strokes added (real ids, the page's own cells) and ids
/// tombstoned at `at`. Only additions and tombstones, ids never come back, so applying deltas in any
/// order, or twice, gives the same page (B_DESIGN.md §2.4 5 (b)).
public struct PageDelta: Sendable, Equatable {
    public let pageId: String
    public let added: [InkStroke]
    public let removed: [String]
    public let at: Int
    /// The session's number when the delta was made (D7): the session drops a delta of an older number.
    public let epoch: Int
    /// The undo group (§4.4).
    public let group: UUID?

    public init(pageId: String, added: [InkStroke], removed: [String], at: Int, epoch: Int, group: UUID? = nil) {
        self.pageId = pageId
        self.added = added
        self.removed = removed
        self.at = at
        self.epoch = epoch
        self.group = group
    }
}

/// The aliases of a session's long ids (§3.2, D4): "<pageId>|span~a~<n>" ↔ the real id on that page.
/// A session keeps one table for every window it composes, so a stroke keeps its window name when the
/// window shifts; the numbers only grow.
public struct SpanAliases: Sendable, Equatable {
    /// alias → the real id (the page is the alias's prefix).
    public private(set) var originals: [String: String]
    /// "<pageId>|<real id>" → alias.
    private var aliasOf: [String: String]
    /// The number the next alias gets.
    public private(set) var next: Int

    public init() {
        originals = [:]
        aliasOf = [:]
        next = 1
    }

    /// An empty table.
    public static let empty = SpanAliases()

    public var isEmpty: Bool { originals.isEmpty }

    /// The real id of an alias; nil for any other name.
    public func original(of alias: String) -> String? {
        originals[alias]
    }

    /// The alias of a real id of `page`, when it has one.
    public func alias(of id: String, page: String) -> String? {
        aliasOf[SpanName.prefixed(id: id, page: page)]
    }

    /// The window name of a real id of `page`: "<page>|<id>" when it fits 128 bytes, else its alias
    /// (made when it has none yet).
    mutating func windowName(of id: String, page: String) -> String {
        let prefixed = SpanName.prefixed(id: id, page: page)
        guard SpanName.needsAlias(prefixed) else { return prefixed }
        if let alias = aliasOf[prefixed] { return alias }
        let alias = SpanName.alias(page: page, number: next)
        next += 1
        aliasOf[prefixed] = alias
        originals[alias] = id
        return alias
    }

    /// (page, real id) of a window name: an alias of the table, or a prefixed name whose rest is no
    /// virtual name (a stripped alias the table does not know never comes out, §3.2). nil otherwise.
    public func resolve(_ name: String) -> (page: String, id: String)? {
        if let id = originals[name], let parts = SpanName.split(name) { return (parts.page, id) }
        guard let parts = SpanName.split(name), !parts.local.isEmpty, !SpanName.isVirtual(parts.local) else { return nil }
        return (parts.page, parts.local)
    }
}

/// The window's pages as one page for the canvas's ledger (§2.1): a wrapper, not an `InkPage`, with no
/// JSON and no `Codable`, so it cannot be handed to the save, the sync, the export or the PDF. The ledger
/// edits `ledgerPage` (whose id is the virtual "span~<kind>~<n>", which `SpanGuard` refuses at every way
/// out); the screen gets the real pages back only through `SpanComposer.deltas` and `extract`. `v`,
/// `updatedAt` and the unknown top-level items of the real pages stay in the screen's `PageSlot`; the
/// wrapper keeps each page's `v` and `updatedAt` only so `extract` gives them back.
///
/// The ledger edits an `InkPage`, so the page inside cannot be a type of its own. What keeps it from the
/// ways out is twofold: `ledgerPage` is SPI (`@_spi(SpanLedger) import InkModel`), visible only in the
/// files that name it (the ledger and the canvas), so the screen, the save, the export and the PDF do not
/// see it at all; and `SpanGuard` refuses its page id at every way out at run time (the save, the import
/// and the export, the PDF's page).
public struct SpanVirtualPage: Sendable, Equatable {
    public let plan: SpanPlan
    public let session: Int
    /// The real page ids, left to right.
    public let pageIds: [String]
    /// The page the ledger edits: the virtual id, every name prefixed (or aliased). SPI: only the files
    /// that hand it to the ledger import it (see the type's note).
    @_spi(SpanLedger) public let ledgerPage: InkPage
    public let aliases: SpanAliases
    /// The pages `BandMigration.migrate` changed while composing: the screen saves them (§3.2, as
    /// today's `show` does).
    public let migratedPageIds: [String]
    /// Pages left out: not of the plan's kind or week start (K-11), or a page id `SpanPlan` does not read.
    public let skippedPageIds: [String]
    let stamps: [String: Stamp]

    struct Stamp: Sendable, Equatable {
        let v: Int
        let updatedAt: Int
    }

    /// The virtual page id ("span~<kind>~<session>", the `SpanLayout`'s `pageId`).
    public var pageId: String { ledgerPage.pageId }

    /// The same window holding what the ledger has now (its id stays the virtual one).
    public func with(ledgerPage page: InkPage) -> SpanVirtualPage {
        var page = page
        page.pageId = ledgerPage.pageId
        return SpanVirtualPage(plan: plan, session: session, pageIds: pageIds, ledgerPage: page, aliases: aliases,
                               migratedPageIds: migratedPageIds, skippedPageIds: skippedPageIds, stamps: stamps)
    }

    /// The real page and id of a stroke of the ledger's page, by its id alone (a prefix or an alias); nil
    /// for an id that is no window name (such a stroke reaches no real page, `SpanComposer.unroutedNames`).
    public func owner(ofStroke stroke: InkStroke) -> (page: String, id: String)? {
        SpanComposer.route(stroke, aliases: aliases)
    }
}

/// A stroke of a neighbour page that reaches into the page a PDF is drawn from (D17): the stroke with
/// its real id and its owner's own cell, and that cell's rect moved into the PDF page's coordinates. Not
/// an `InkPage` and not saved anywhere: `PDFPageRenderer` only draws it.
public struct SpanPDFInk: Sendable, Equatable {
    /// The owner page.
    public let pageId: String
    public let stroke: InkStroke
    /// The owner's cell in the coordinates of the page the PDF draws (x moved by the pages' distance).
    public let cellRect: CGRect

    public init(pageId: String, stroke: InkStroke, cellRect: CGRect) {
        self.pageId = pageId
        self.stroke = stroke
        self.cellRect = cellRect
    }
}

public enum SpanComposer {
    // MARK: Compose

    /// The virtual page of `pages` (left to right) for `plan` (§3.2): each real page first goes through
    /// `BandMigration.migrate` with its own id (a prefixed cell is no band cell any more,
    /// BandMigration.swift:17-19), then its strokes, tombstones and unknown-tool items get the window's
    /// names. A page `plan.index(of:)` does not read is left out (`skippedPageIds`); a page given twice is
    /// merged into its first place. `session` is the number in the virtual id; `aliases` is the session's
    /// table so far (a shifted window keeps every alias). A stroke that is tombstoned on its own page is
    /// not carried (its page's JSON does not hold it either).
    ///
    /// A stored name that is itself virtual ("span~…": only in broken or foreign data, which the save
    /// guard drops and the import refuses) stays out of the window. In it, it would be "<page>|span~…", a
    /// name no delta and no safety net can take back to its page, and it could be the very alias a long
    /// id of the same page gets ("<page>|span~a~<n>"): a stored tombstone "span~a~1" would erase that
    /// stroke in the window, and the safety net would then tombstone it on its page. The page's slot
    /// keeps the name; `SpanGuard.checkForSave` drops it at the save.
    public static func compose(_ pages: [InkPage], plan: SpanPlan, session: Int = 0, aliases: SpanAliases = .empty) -> SpanVirtualPage {
        var order: [String] = []
        var real: [String: InkPage] = [:]
        var skipped: [String] = []
        var migrated: [String] = []
        for page in pages {
            guard plan.index(of: page.pageId) != nil else {
                skipped.append(page.pageId)
                continue
            }
            let moved = BandMigration.migrate(page)
            if moved != page && !migrated.contains(page.pageId) { migrated.append(page.pageId) }
            if let current = real[page.pageId] {
                real[page.pageId] = InkPage.merge(current, moved)
            } else {
                order.append(page.pageId)
                real[page.pageId] = moved
            }
        }

        var table = aliases
        var ledger = InkPage(pageId: SpanName.virtualPageId(plan.kind, session: session))
        var stamps: [String: SpanVirtualPage.Stamp] = [:]
        for pageId in order {
            let page = real[pageId]!
            stamps[pageId] = SpanVirtualPage.Stamp(v: page.v, updatedAt: page.updatedAt)
            ledger.updatedAt = max(ledger.updatedAt, page.updatedAt)
            for key in page.deleted.keys.sorted() where !SpanName.isVirtual(key) {
                ledger.deleted[table.windowName(of: key, page: pageId)] = page.deleted[key]!
            }
            for key in page.strokes.keys.sorted() where page.deleted[key] == nil && !SpanName.isVirtual(key) {
                var stroke = page.strokes[key]!
                guard !SpanName.isVirtual(stroke.id) else { continue }
                stroke.id = table.windowName(of: stroke.id, page: pageId)
                stroke.cell = SpanName.prefixed(stroke.cell, page: pageId)
                ledger.strokes[table.windowName(of: key, page: pageId)] = stroke
            }
            for key in page.unknownStrokes.keys.sorted() where page.deleted[key] == nil && !SpanName.isVirtual(key) {
                ledger.unknownStrokes[table.windowName(of: key, page: pageId)] = page.unknownStrokes[key]!
            }
        }
        return SpanVirtualPage(plan: plan, session: session, pageIds: order, ledgerPage: ledger, aliases: table,
                               migratedPageIds: migrated, skippedPageIds: skipped, stamps: stamps)
    }

    // MARK: Journal → deltas

    /// (page, real id) of a stroke the ledger holds or added, by its id alone: a prefix or an alias
    /// (`SpanAliases.resolve`), the same rule as for a removed name. nil for an id that is no window name
    /// (made with `makeId` where the joined path uses `ownerId`, §3.3 1), an alias the table does not know
    /// or a virtual name. Such a stroke goes to no page, never to the page of its cell: its tombstone could
    /// not follow it there (a removal has no cell), so the stroke would come back on its page after it was
    /// erased, in the deltas and in the safety net alike.
    static func route(_ stroke: InkStroke, aliases: SpanAliases) -> (page: String, id: String)? {
        aliases.resolve(stroke.id)
    }

    /// The stroke with its real id and its page's own cell (the prefix of the cell is taken off whatever
    /// page it names; the points are untouched).
    static func real(_ stroke: InkStroke, id: String) -> InkStroke {
        var out = stroke
        out.id = id
        out.cell = SpanName.strip(stroke.cell)
        return out
    }

    /// One delta per real page per journal step, in the journal's order; within a step the pages that get
    /// strokes come first (the destination of a move before its source, D8), then the pages that only lose
    /// some. Every id is the real one: a prefix is taken off, an alias goes back to its real id through
    /// `aliases`. A name that tells no page (an added id or a removed name with no prefix, not in the
    /// table) or that is virtual is left out, so nothing of the window ever reaches a real page;
    /// `unroutedNames` lists what was left out.
    ///
    /// `aliases` is the session's table (`SpanVirtualPage.aliases`) and has no default: given an empty
    /// table by mistake, every alias (an id longer than 128 bytes with its prefix) would be left out, and
    /// its erasing would reach its page only through the safety net (§3.2).
    public static func deltas(from journal: [SpanJournalEntry], epoch: Int, aliases: SpanAliases) -> [PageDelta] {
        var out: [PageDelta] = []
        for entry in journal {
            var pages: [String] = []
            var added: [String: [InkStroke]] = [:]
            var removed: [String: [String]] = [:]
            for stroke in entry.added {
                guard let owner = route(stroke, aliases: aliases) else { continue }
                if added[owner.page] == nil && removed[owner.page] == nil { pages.append(owner.page) }
                added[owner.page, default: []].append(real(stroke, id: owner.id))
            }
            var removalPages: [String] = []
            for name in entry.removed {
                guard let owner = aliases.resolve(name) else { continue }
                if added[owner.page] == nil && removed[owner.page] == nil { removalPages.append(owner.page) }
                removed[owner.page, default: []].append(owner.id)
            }
            for page in pages + removalPages {
                out.append(PageDelta(pageId: page, added: added[page] ?? [], removed: removed[page] ?? [], at: entry.at,
                                     epoch: epoch, group: entry.group))
            }
        }
        return out
    }

    /// The names of `journal` that `deltas` leaves out, in the journal's order: each added stroke's id and
    /// each removed name that tells no page (§3.4 (d)). Empty when the ledger makes every id with `ownerId`
    /// (§3.3 1) and the session's table is given. Anything else is a fault the session records (and stops
    /// on in Debug): the stroke is on the screen, but neither a delta nor the safety net (`extract` routes
    /// by the same names) takes it to a real page, so it is gone when the window is composed again.
    public static func unroutedNames(in journal: [SpanJournalEntry], aliases: SpanAliases) -> [String] {
        var out: [String] = []
        for entry in journal {
            for stroke in entry.added where route(stroke, aliases: aliases) == nil { out.append(stroke.id) }
            for name in entry.removed where aliases.resolve(name) == nil { out.append(name) }
        }
        return out
    }

    // MARK: Delta → real page

    /// The page with the delta applied the way the ledger edits a page today: each added stroke through
    /// `InkPage.add` (ignored when its id is tombstoned; `updatedAt` at least its `t`), then the removed
    /// ids through `InkPage.remove(ids:at:)`. A delta of another page leaves the page as it is (no delta
    /// is ever applied to a page it was not made for, §3.4 (c)). `v`, the unknown top-level items and
    /// every untouched item stay byte for byte.
    public static func apply(_ delta: PageDelta, to page: InkPage) -> InkPage {
        guard delta.pageId == page.pageId else { return page }
        var out = page
        for stroke in delta.added { out.add(stroke) }
        if !delta.removed.isEmpty { out.remove(ids: delta.removed, at: delta.at) }
        return out
    }

    // MARK: Safety net

    /// The range of real page `pageId` in the virtual page (§3.4 (c), B_DESIGN.md §2.4 5 (c)): its live
    /// strokes, unknown-tool items and tombstones with the real ids and the page's own cells, each found by
    /// its name as `deltas` finds it (a name that tells no page is in no range); `v` as the page had it;
    /// `updatedAt` the newest of the page's own and of every time in the range. The screen
    /// merges it into its `PageSlot` (`InkPage.merge`); a union with tombstones, so it never loses a
    /// stroke and brings back any delta that went missing.
    ///
    /// The id is always the real one: a page id that is not a page of the window (the virtual id
    /// included) gives an empty page with the id "", which `InkPage.merge` treats as neutral, so merging
    /// the result never turns a "w-…" or "y-…" page into "span~…" (`pickPageId` keeps the smaller id, and
    /// "s" < "w", "y").
    public static func extract(pageId: String, from virtual: SpanVirtualPage) -> InkPage {
        guard virtual.pageIds.contains(pageId), let stamp = virtual.stamps[pageId] else { return InkPage(pageId: "") }
        let ledger = virtual.ledgerPage
        var out = InkPage(v: stamp.v, pageId: pageId)
        var newest = stamp.updatedAt
        for (name, time) in ledger.deleted {
            guard let owner = virtual.aliases.resolve(name), owner.page == pageId else { continue }
            out.deleted[owner.id] = max(out.deleted[owner.id] ?? time, time)
            out.strokes[owner.id] = nil
            out.unknownStrokes[owner.id] = nil
            newest = max(newest, time)
        }
        for name in ledger.strokes.keys.sorted() where ledger.deleted[name] == nil {
            let stroke = ledger.strokes[name]!
            guard let owner = route(stroke, aliases: virtual.aliases), owner.page == pageId,
                  out.deleted[owner.id] == nil else { continue }
            let mine = real(stroke, id: owner.id)
            if let current = out.strokes[owner.id] {
                out.strokes[owner.id] = InkPage.pickStroke(current, mine)
            } else {
                out.strokes[owner.id] = mine
            }
            out.unknownStrokes[owner.id] = nil
            newest = max(newest, stroke.t)
        }
        for name in ledger.unknownStrokes.keys.sorted() where ledger.deleted[name] == nil {
            guard let owner = virtual.aliases.resolve(name), owner.page == pageId, out.deleted[owner.id] == nil,
                  out.strokes[owner.id] == nil else { continue }
            let raw = ledger.unknownStrokes[name]!
            if let current = out.unknownStrokes[owner.id] {
                out.unknownStrokes[owner.id] = InkPage.pickJSON(current, raw)
            } else {
                out.unknownStrokes[owner.id] = raw
            }
        }
        out.updatedAt = newest
        return out
    }

    // MARK: PDF (D17)

    /// The strokes of the window's other pages whose bounds reach into page `pageId` (x between its left
    /// and right edge in `layout`), in drawing order (markers under pens, then by time and id), each with
    /// its real id, its owner's own cell, and that cell's rect in `pageId`'s coordinates. Empty when the
    /// page is not in both the layout and the virtual page.
    public static func neighborInk(for pageId: String, from virtual: SpanVirtualPage, layout: SpanLayout) -> [SpanPDFInk] {
        guard virtual.pageIds.contains(pageId), let slot = layout.slot(ofPage: pageId) else { return [] }
        let left = layout.origin(ofSlot: slot)
        let right = left + layout.plan.pageWidth
        var found: [(stroke: InkStroke, ink: SpanPDFInk)] = []
        for (name, stroke) in virtual.ledgerPage.strokes where virtual.ledgerPage.deleted[name] == nil {
            guard let owner = route(stroke, aliases: virtual.aliases), owner.page != pageId,
                  virtual.pageIds.contains(owner.page), let cell = layout.cells[stroke.cell],
                  let bounds = stroke.paperBounds(cellOrigin: cell.origin),
                  bounds.maxX > left, bounds.minX < right else { continue }
            let mine = real(stroke, id: owner.id)
            found.append((mine, SpanPDFInk(pageId: owner.page, stroke: mine, cellRect: cell.offsetBy(dx: -left, dy: 0))))
        }
        return found.sorted { InkPage.drawsBefore($0.stroke, $1.stroke) || (!InkPage.drawsBefore($1.stroke, $0.stroke) && $0.ink.pageId < $1.ink.pageId) }
            .map(\.ink)
    }
}
