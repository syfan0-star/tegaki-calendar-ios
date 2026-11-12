@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §3.3, §3.4, §3.16, §4.4, §10.2 row L): the real ledger (`InkLedger`) on the
/// joined path, editing the virtual page of a window of three weeks (or days) composed by
/// `SpanComposer.compose`, with the `SpanLayout` of the same session and an `ownerId` like the one the
/// canvas will give ("<owner page>|<fresh id>"). The one-page path (`ownerId` nil) is checked alongside
/// where a rule must not reach it; 1.2.3's own tests (`InkLedgerTests`, `WeekStartLedgerTests`) still run
/// it unchanged. Ids, times and group marks are seeded; nothing waits, so no `TestSleeper`.
@MainActor
final class InkLedgerSpanTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    /// The window's weeks (Mondays): slot 0 at x 0, slot 1 at x 1,400, slot 2 at x 2,800.
    private let weekA = "w-2026-11-02"
    private let weekB = "w-2026-11-09"
    private let weekC = "w-2026-11-16"

    // MARK: Helpers

    /// Ids "<prefix>-0000-4000-8000-<n>", times baseMs + n, group marks "00000000-0000-4000-8000-<n>".
    /// `bareIds` counts the calls of `makeId`, which the joined path must never make.
    private final class Seed {
        private let prefix: String
        private let baseMs: Int
        private var ids = 0
        private var ms = 0
        private(set) var bareIds = 0
        private(set) var groups = 0

        init(prefix: String, baseMs: Int) {
            self.prefix = prefix
            self.baseMs = baseMs
        }

        func nextId() -> String {
            ids += 1
            return id(ids)
        }

        func id(_ n: Int) -> String {
            let hex = String(n, radix: 16)
            return prefix + "-0000-4000-8000-" + String(repeating: "0", count: max(0, 12 - hex.count)) + hex
        }

        func bareId() -> String {
            bareIds += 1
            return "bare-\(bareIds)"
        }

        func nextMs() -> Int {
            ms += 1
            return baseMs + ms
        }

        func nextGroup() -> UUID {
            groups += 1
            return Seed.group(groups)
        }

        static func group(_ n: Int) -> UUID {
            UUID(uuidString: "00000000-0000-4000-8000-" + String(format: "%012d", n))!
        }
    }

    private struct Window {
        let layout: SpanLayout
        let virtual: SpanVirtualPage
    }

    /// The weeks of 11/2, 11/9 and 11/16 (Monday start), session 1, with `pages` as the stored pages (an
    /// empty page for a week not given).
    private func weekWindow(_ pages: [InkPage] = []) -> Window {
        let plan = SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPad11, orientation: .portrait)
        let first = plan.index(containing: DayKey(year: 2026, month: 11, day: 2))
        let layouts: [any PageLayout] = (first..<first + 3).map { index in
            WeekLayoutEngine.layout(WeekLayoutInput(focus: plan.firstDay(at: index), events: [], inkBottoms: [:], now: now, weekStart: .monday))
        }
        XCTAssertEqual(layouts.map { $0.pageId }, [weekA, weekB, weekC])
        let real = layouts.map { week in pages.first { $0.pageId == week.pageId } ?? InkPage.empty(pageId: week.pageId) }
        return Window(layout: SpanLayout(pages: layouts, plan: plan, firstIndex: first, session: 1),
                      virtual: SpanComposer.compose(real, plan: plan, session: 1))
    }

    /// "<page>|<fresh id>" for a window cell, as the canvas makes it; a bare id for a name without a page
    /// (such a stroke would reach no page: `SpanComposer.unroutedNames` lists it).
    nonisolated private static func ownerName(cell: CellKey, fresh: String) -> String {
        guard let page = SpanName.split(cell.raw)?.page else { return fresh }
        return SpanName.prefixed(id: fresh, page: page)
    }

    /// The ledger of the window's virtual page on the joined path, seeded, with its drawing built.
    private func joinedLedger(_ window: Window, seed: Seed) -> InkLedger {
        let ledger = InkLedger(page: window.virtual.ledgerPage, layout: window.layout, deviceId: "span-test")
        ledger.makeId = { seed.bareId() }
        ledger.nowMs = { seed.nextMs() }
        ledger.makeGroup = { seed.nextGroup() }
        ledger.ownerId = { cell in Self.ownerName(cell: cell, fresh: seed.nextId()) }
        _ = ledger.drawing()
        return ledger
    }

    /// A five-point pen stroke from `origin` (band lu), 3 lu right and 1 lu down per point, a 3.5 lu nib,
    /// written `second` seconds after 1,790,000,000.
    private func pen(at origin: CGPoint, second: TimeInterval) -> PKStroke {
        let points = (0..<5).map { i in
            PKStrokePoint(location: CGPoint(x: origin.x + CGFloat(i) * 3, y: origin.y + CGFloat(i)), timeOffset: TimeInterval(i) * 0.016,
                          size: CGSize(width: 3.5, height: 3.5), opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_790_000_000 + second)),
                        transform: .identity, mask: nil)
    }

    /// The canvas shows the ledger's drawing and the pen adds `stroke`: the change it reports.
    @discardableResult
    private func draw(_ stroke: PKStroke, on ledger: InkLedger) -> InkChange {
        ledger.applyCanvasChange(PKDrawing(strokes: ledger.drawing().strokes + [stroke]))
    }

    /// What the canvas holds when the ledger's drawing loses the strokes of `ids`.
    private func erasing(_ ids: Set<String>, from ledger: InkLedger) -> PKDrawing {
        let shown = ledger.drawing().strokes
        return PKDrawing(strokes: shown.filter { pk in !(ledger.id(of: pk).map { ids.contains($0) } ?? false) })
    }

    /// A stored pen stroke of the page's own `grid` cell (cell-relative x, y), written at `t`.
    private func stored(_ id: String, x: CGFloat, y: CGFloat, t: Int) -> InkStroke {
        InkStroke(id: id, cell: .grid, tool: InkModel.InkTool.pen, color: "#000000", t: t, dev: "other-device",
                  points: (0..<5).map { i in
                      InkPoint(x: x + CGFloat(i) * 3, y: y + CGFloat(i), dtMs: i * 16, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5,
                               azimuth: 0, altitude: 1.571)
                  })
    }

    /// A stored page holding `strokes` and the tombstones `deleted`.
    private func page(_ pageId: String, _ strokes: [InkStroke], deleted: [String: Int] = [:]) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for stroke in strokes { page.add(stroke) }
        for (id, time) in deleted { page.remove(ids: [id], at: time) }
        return page
    }

    /// A stored page of `count` strokes "<tag>-<n>" (n = 0 …), each at its own place and time.
    private func crowdedPage(_ pageId: String, count: Int, tag: String, baseT: Int) -> InkPage {
        page(pageId, (0..<count).map { n in
            stored("\(tag)-\(n)", x: 100 + CGFloat(n % 20) * 60, y: 100 + CGFloat(n / 20) * 80, t: baseT + n * 1000)
        })
    }

    // MARK: §3.3 1 — ownerId at the three places that make an id

    /// A new stroke, a lasso's moved copy and ↶'s copy each get their id from `ownerId`, asked with the right
    /// cell: the cell `SpanLayout.inkCell` gave (the middle week), the destination cell of the move (the
    /// last week), the original's cell (the middle week again). `makeId` is never asked. With `ownerId` nil
    /// the one-page ledger makes the same three ids with `makeId`, as in 1.2.3.
    /// Fails if a place still called `makeId` on the joined path (a "bare-" id, `bareIds` > 0) or asked
    /// `ownerId` with another cell (the move's source cell, say).
    func testOwnerIdGetsTheOwnerCell() throws {
        let window = weekWindow()
        let seed = Seed(prefix: "13a00000", baseMs: 1_790_100_000_000)
        let ledger = joinedLedger(window, seed: seed)
        var asked: [String] = []
        ledger.ownerId = { cell in
            asked.append(cell.raw)
            return Self.ownerName(cell: cell, fresh: seed.nextId())
        }

        let drawn = draw(pen(at: CGPoint(x: 1400 + 300, y: 500), second: 1), on: ledger)
        let stroke = try XCTUnwrap(drawn.added.first)
        XCTAssertEqual(asked, ["w-2026-11-09|grid"])
        XCTAssertEqual(stroke.cell.raw, "w-2026-11-09|grid")
        XCTAssertEqual(stroke.id, "w-2026-11-09|" + seed.id(1))

        let moved = ledger.moveStrokes(ids: [stroke.id], by: CGVector(dx: 1400, dy: 0))
        let copy = try XCTUnwrap(moved.change.added.first)
        XCTAssertEqual(asked, ["w-2026-11-09|grid", "w-2026-11-16|grid"])
        XCTAssertEqual(copy.cell.raw, "w-2026-11-16|grid")
        XCTAssertEqual(copy.id, "w-2026-11-16|" + seed.id(2))
        XCTAssertEqual(moved.newIds, [copy.id])

        XCTAssertNotNil(ledger.undo())
        XCTAssertEqual(asked, ["w-2026-11-09|grid", "w-2026-11-16|grid", "w-2026-11-09|grid"])
        XCTAssertEqual(ledger.page.liveStrokeIds, ["w-2026-11-09|" + seed.id(3)], "↶ put the original back as an owner copy")
        XCTAssertEqual(ledger.page.strokes["w-2026-11-09|" + seed.id(3)]?.cell.raw, "w-2026-11-09|grid")
        XCTAssertEqual(seed.bareIds, 0, "makeId is never asked on the joined path")

        // ownerId nil: the one-page ledger of the middle week asks makeId at the same three places.
        let single = InkLedger(page: InkPage.empty(pageId: weekB), layout: window.layout.pages[1], deviceId: "span-test")
        let plain = Seed(prefix: "13b00000", baseMs: 1_790_200_000_000)
        single.makeId = { plain.nextId() }
        single.nowMs = { plain.nextMs() }
        _ = single.drawing()
        let one = try XCTUnwrap(draw(pen(at: CGPoint(x: 300, y: 500), second: 1), on: single).added.first)
        XCTAssertEqual(one.id, plain.id(1))
        XCTAssertEqual(one.cell, .grid)
        XCTAssertEqual(single.moveStrokes(ids: [one.id], by: CGVector(dx: 100, dy: 0)).newIds, [plain.id(2)])
        XCTAssertNotNil(single.undo())
        XCTAssertEqual(single.page.liveStrokeIds, [plain.id(3)])
        XCTAssertTrue(single.journal.isEmpty, "the one-page path keeps no journal")
    }

    /// Every id the joined path makes, through a sequence of new strokes on two weeks, the eraser, a lasso
    /// move across weeks and one within a week, ↶ ↶ ↶ ↷ ↷, a lasso deletion and its ↶, is an owner id: the
    /// page in front of its id is the page in front of its cell, and `SpanComposer.unroutedNames` over the
    /// same journal with the session's aliases is empty (§3.3 1, §3.4 (d)). The added ids come in the order
    /// the seed made them.
    /// Fails if any of the three places made a bare id (`makeId`, or a fresh id without its page): that name
    /// would be listed by `unroutedNames`, and its stroke would reach no page.
    func testEveryIdOfTheJoinedPathIsAnOwnerId() throws {
        let window = weekWindow([
            page(weekA, [stored("a-1", x: 200, y: 300, t: 1_780_000_001_000), stored("a-2", x: 600, y: 300, t: 1_780_000_002_000)]),
            page(weekB, [stored("b-1", x: 400, y: 900, t: 1_780_000_003_000)]),
        ])
        let seed = Seed(prefix: "13c00000", baseMs: 1_790_300_000_000)
        let ledger = joinedLedger(window, seed: seed)
        let a1 = "w-2026-11-02|a-1"
        let b1 = "w-2026-11-09|b-1"

        let onA = try XCTUnwrap(draw(pen(at: CGPoint(x: 400, y: 1000), second: 1), on: ledger).added.first)
        let onC = try XCTUnwrap(draw(pen(at: CGPoint(x: 2800 + 500, y: 700), second: 2), on: ledger).added.first)
        XCTAssertEqual(ledger.applyCanvasChange(erasing([a1], from: ledger)).removedIds, [a1])
        XCTAssertEqual(ledger.moveStrokes(ids: [b1], by: CGVector(dx: 1400, dy: 0)).newIds, ["w-2026-11-16|" + seed.id(3)])
        XCTAssertEqual(ledger.moveStrokes(ids: [onA.id], by: CGVector(dx: 0, dy: 200)).newIds, ["w-2026-11-02|" + seed.id(4)])
        XCTAssertNotNil(ledger.undo()) // the move within the first week
        XCTAssertNotNil(ledger.undo()) // the move across weeks
        XCTAssertNotNil(ledger.undo()) // the eraser
        XCTAssertNotNil(ledger.redo()) // the eraser again
        XCTAssertNotNil(ledger.redo()) // the move across weeks again
        XCTAssertEqual(ledger.removeStrokes(ids: [onC.id]).removedIds, [onC.id])
        XCTAssertNotNil(ledger.undo()) // the deletion

        XCTAssertEqual(SpanComposer.unroutedNames(in: ledger.journal, aliases: window.virtual.aliases), [])
        XCTAssertEqual(seed.bareIds, 0)
        let added = ledger.journal.flatMap { $0.added }
        XCTAssertEqual(added.map(\.id), [
            "w-2026-11-02|" + seed.id(1), // new stroke
            "w-2026-11-16|" + seed.id(2), // new stroke
            "w-2026-11-16|" + seed.id(3), // the lasso's copy across weeks
            "w-2026-11-02|" + seed.id(4), // the lasso's copy within the week
            "w-2026-11-02|" + seed.id(5), // ↶'s copy of the stroke moved within the week
            "w-2026-11-09|" + seed.id(6), // ↶'s copy of b-1
            "w-2026-11-02|" + seed.id(7), // ↶'s copy of a-1
            "w-2026-11-16|" + seed.id(8), // ↷'s copy of the lasso's copy across weeks
            "w-2026-11-16|" + seed.id(9), // ↶'s copy of the deleted stroke
        ])
        for stroke in added + ledger.page.liveStrokes {
            let owner = try XCTUnwrap(SpanName.split(stroke.id)?.page, stroke.id)
            XCTAssertEqual(owner, SpanName.split(stroke.cell.raw)?.page, "\(stroke.id) is owned by its cell's page")
        }
        for name in ledger.journal.flatMap(\.removed) {
            XCTAssertNotNil(window.virtual.aliases.resolve(name), name)
        }
        XCTAssertEqual(ledger.journal.count, 15)
    }

    // MARK: §3.3 2 — the journal

    /// Only an id live in the page at that moment is journalled as removed. Another device erased a-1 while
    /// the canvas still showed it (`reload` keeps the fingerprints); the eraser then takes a-1 and a-2 off the
    /// canvas: a-2 alone is tombstoned and journalled, a-1 keeps the other device's tombstone time and comes
    /// back in `alreadyErased`, and its fingerprint is forgotten with a-2's (the same canvas once more is no
    /// change and returns no id). A lasso deletion of a-1 and a-3 journals a-3 only; a lasso move of a-1 alone
    /// does nothing; ↶ of a stroke another device erased journals nothing. A change that loses only ids that
    /// are not live (b-1 erased by another device; a-3, whose page came back without it, unknown to the page:
    /// a fingerprint left behind) tombstones and journals nothing, makes no history step and keeps ↷, returns
    /// the two ids split into `alreadyErased` and `unknownRemovals` (B_DESIGN.md §2.4 6 (a): the owner records
    /// them), and forgets their fingerprints. The one-page ledger, given the same erasure, tombstones both ids
    /// again as 1.2.3 does, keeps no journal and splits nothing.
    /// Fails if the joined path journalled or tombstoned a lost id that was not live (a-1 would be in the
    /// entry and its tombstone stamped with this device's time), if `perform`, `removeStrokes` or
    /// `moveStrokes` journalled an id that was not live, if a change of such ids alone pushed a step (↶ would
    /// be possible and ↷ gone), or if the forgotten ids were not returned or were put in the wrong list. Fails
    /// if a change that also tombstoned a live id kept the fingerprints of the ids that were not live (a-1
    /// would come back in `alreadyErased` with every later change of the canvas).
    func testJournalRecordsOnlyLiveRemovals() throws {
        let otherDevice = 1_785_000_000_000
        let start = page(weekA, [stored("a-1", x: 200, y: 300, t: 1_780_000_001_000), stored("a-2", x: 600, y: 300, t: 1_780_000_002_000),
                                 stored("a-3", x: 1000, y: 300, t: 1_780_000_003_000)])
        let window = weekWindow([start])
        let seed = Seed(prefix: "13d00000", baseMs: 1_790_400_000_000)
        let ledger = joinedLedger(window, seed: seed)
        let a1 = "w-2026-11-02|a-1"
        let a2 = "w-2026-11-02|a-2"
        let a3 = "w-2026-11-02|a-3"

        let shown = ledger.drawing().strokes
        var remote = ledger.page
        remote.remove(ids: [a1], at: otherDevice)
        ledger.reload(page: remote, keepHistory: true)
        let onlyA3 = PKDrawing(strokes: shown.filter { ledger.id(of: $0) == a3 })
        let change = ledger.applyCanvasChange(onlyA3)
        XCTAssertEqual(change.removedIds, [a2])
        XCTAssertFalse(change.needsRebuild)
        XCTAssertEqual(change.alreadyErased, [a1])
        XCTAssertEqual(change.unknownRemovals, [])
        XCTAssertEqual(ledger.journal, [SpanJournalEntry(added: [], removed: [a2], at: 1_790_400_000_001)])
        XCTAssertEqual(ledger.page.deleted[a1], otherDevice, "the other device's tombstone is not stamped again")
        XCTAssertEqual(ledger.page.deleted[a2], 1_790_400_000_001)
        XCTAssertEqual(ledger.page.liveStrokeIds, [a3])
        // The canvas reports the same drawing once more (its next change): a-1 is not lost again.
        let sameCanvas = ledger.applyCanvasChange(onlyA3) // asks the clock once (…002)
        XCTAssertTrue(sameCanvas.isEmpty)
        XCTAssertEqual(sameCanvas.alreadyErased + sameCanvas.unknownRemovals + sameCanvas.refusedRemovals, [],
                       "a-1's fingerprint was forgotten by the change that tombstoned a-2")
        XCTAssertEqual(ledger.journal.count, 1)

        ledger.journal.removeAll()
        XCTAssertEqual(ledger.removeStrokes(ids: [a1, a3]).removedIds, [a3])
        XCTAssertEqual(ledger.journal, [SpanJournalEntry(added: [], removed: [a3], at: 1_790_400_000_003)])

        ledger.journal.removeAll()
        XCTAssertTrue(ledger.moveStrokes(ids: [a1], by: CGVector(dx: 0, dy: 100)).newIds.isEmpty)
        XCTAssertTrue(ledger.journal.isEmpty)

        let fresh = try XCTUnwrap(draw(pen(at: CGPoint(x: 1400 + 500, y: 500), second: 1), on: ledger).added.first)
        XCTAssertEqual(ledger.journal, [SpanJournalEntry(added: [fresh], removed: [], at: 1_790_400_000_004)])
        var erasedThere = ledger.page
        erasedThere.remove(ids: [fresh.id], at: otherDevice)
        ledger.reload(page: erasedThere, keepHistory: true)
        ledger.journal.removeAll()
        XCTAssertNotNil(ledger.undo(), "↶ of the stroke another device erased")
        XCTAssertTrue(ledger.journal.isEmpty, "nothing live was removed, nothing is journalled")
        XCTAssertEqual(ledger.page.deleted[fresh.id], otherDevice)

        // Only ids that are not live: no step, ↷ kept, the ids returned.
        let b1 = "w-2026-11-09|b-1"
        let other = joinedLedger(weekWindow([start, page(weekB, [stored("b-1", x: 400, y: 900, t: 1_780_000_004_000)])]),
                                 seed: Seed(prefix: "13d10000", baseMs: 1_790_450_000_000))
        XCTAssertNotNil(draw(pen(at: CGPoint(x: 1400 + 700, y: 1200), second: 2), on: other).added.first)
        XCTAssertNotNil(other.undo())
        XCTAssertFalse(other.canUndo)
        XCTAssertTrue(other.canRedo)
        let otherShown = other.drawing().strokes
        XCTAssertEqual(otherShown.count, 4)
        var cameBack = other.page
        cameBack.remove(ids: [b1], at: otherDevice)
        cameBack.strokes[a3] = nil
        other.reload(page: cameBack, keepHistory: true)
        other.journal.removeAll()
        let lost = PKDrawing(strokes: otherShown.filter { pk in other.id(of: pk).map { ![a3, b1].contains($0) } ?? true })
        let deadOnly = other.applyCanvasChange(lost)
        XCTAssertTrue(deadOnly.isEmpty)
        XCTAssertFalse(deadOnly.needsRebuild)
        XCTAssertEqual(deadOnly.alreadyErased, [b1])
        XCTAssertEqual(deadOnly.unknownRemovals, [a3])
        XCTAssertTrue(other.journal.isEmpty)
        XCTAssertNil(other.page.deleted[a3], "an id unknown to the page gets no tombstone")
        XCTAssertEqual(other.page.deleted[b1], otherDevice)
        XCTAssertFalse(other.canUndo, "a change of ids that are not live makes no history step")
        XCTAssertTrue(other.canRedo, "… and keeps ↷")
        let again = other.applyCanvasChange(lost)
        XCTAssertTrue(again.isEmpty)
        XCTAssertEqual(again.alreadyErased + again.unknownRemovals, [], "their fingerprints are forgotten")

        // The one-page path (ownerId nil), the same erasure: 1.2.3's behaviour.
        let single = InkLedger(page: start, layout: window.layout.pages[0], deviceId: "span-test")
        single.nowMs = { 1_790_500_000_001 }
        let singleShown = single.drawing().strokes
        var singleRemote = single.page
        singleRemote.remove(ids: ["a-1"], at: otherDevice)
        single.reload(page: singleRemote, keepHistory: true)
        let singleChange = single.applyCanvasChange(PKDrawing(strokes: singleShown.filter { single.id(of: $0) == "a-3" }))
        XCTAssertEqual(Set(singleChange.removedIds), ["a-1", "a-2"])
        XCTAssertEqual(single.page.deleted["a-1"], 1_790_500_000_001)
        XCTAssertTrue(single.journal.isEmpty)
        XCTAssertEqual(singleChange.alreadyErased + singleChange.unknownRemovals + singleChange.refusedRemovals, [])
    }

    /// The journal turned into deltas (`SpanComposer.deltas` with the session's aliases) and applied with
    /// `SpanComposer.apply` to the three stored pages gives each page exactly what the ledger's page holds
    /// for it (`SpanComposer.extract`: live strokes and tombstones with their times), after new strokes on
    /// two weeks, the eraser, two lasso moves across weeks, ↶ ↶ ↷, a lasso deletion and its ↶, and a new
    /// stroke on the third week; a stroke whose id the page refuses is left out. The pages' live ids and
    /// tombstones are checked by name and time, and the deltas of the moves carry their group marks.
    /// Fails if a step was not journalled (its strokes or tombstones would be missing from the applied
    /// pages: ↶'s copies if `perform` were not, c-1's tombstone if `applyCanvasChange` were not), if an
    /// entry's time were not its tombstones' time, if a move's entry lost its group, or if a stroke the
    /// page refused were journalled (the first week would get a stroke the window does not hold).
    func testJournalDeltasEqualThePageDifference() throws {
        let stamp = 1_780_000_000_500
        let starts = [
            page(weekA, [stored("a-1", x: 200, y: 300, t: 1_780_000_001_000), stored("a-2", x: 600, y: 300, t: 1_780_000_002_000)]),
            page(weekB, [stored("b-1", x: 400, y: 900, t: 1_780_000_003_000)]),
            page(weekC, [stored("c-1", x: 300, y: 1200, t: 1_780_000_004_000), stored("c-2", x: 900, y: 1200, t: 1_780_000_005_000)],
                 deleted: ["c-old": stamp]),
        ]
        let window = weekWindow(starts)
        let base = 1_790_600_000_000
        let seed = Seed(prefix: "13e00000", baseMs: base)
        let ledger = joinedLedger(window, seed: seed)
        func a(_ n: Int) -> String { "w-2026-11-02|" + seed.id(n) }
        func b(_ n: Int) -> String { "w-2026-11-09|" + seed.id(n) }
        func c(_ n: Int) -> String { "w-2026-11-16|" + seed.id(n) }

        draw(pen(at: CGPoint(x: 500, y: 1500), second: 1), on: ledger)                     // a(1)           ms 1
        draw(pen(at: CGPoint(x: 1400 + 800, y: 600), second: 2), on: ledger)              // b(2)           ms 2
        _ = ledger.applyCanvasChange(erasing(["w-2026-11-16|c-1"], from: ledger))         // c-1 erased     ms 3
        _ = ledger.moveStrokes(ids: ["w-2026-11-09|b-1"], by: CGVector(dx: 1400, dy: 100)) // b-1 → c(3)   ms 4, group 1
        _ = ledger.moveStrokes(ids: [a(1)], by: CGVector(dx: 1400, dy: 0))               // a(1) → b(4)    ms 5, group 2
        XCTAssertNotNil(ledger.undo())                                                     // a(5) back, b(4) off; ms 6–8
        XCTAssertNotNil(ledger.undo())                                                     // b(6) back, c(3) off; ms 9–11
        XCTAssertNotNil(ledger.redo())                                                     // c(7) back, b(6) off; ms 12–14
        _ = ledger.removeStrokes(ids: ["w-2026-11-02|a-2"])                               // a-2 off        ms 15
        XCTAssertNotNil(ledger.undo())                                                     // a(8) back      ms 16
        draw(pen(at: CGPoint(x: 2800 + 600, y: 1700), second: 3), on: ledger)             // c(9)           ms 17
        // A stroke whose id the page refuses (over 128 bytes: `InkPage.add` ignores it) is not journalled
        // either, so no delta adds what the window does not hold.
        let ownerId = ledger.ownerId
        ledger.ownerId = { cell in SpanName.prefixed(id: String(repeating: "x", count: 130), page: SpanName.split(cell.raw)?.page ?? "") }
        XCTAssertEqual(draw(pen(at: CGPoint(x: 900, y: 1700), second: 4), on: ledger).added.count, 1)  // ms 18
        ledger.ownerId = ownerId
        XCTAssertEqual(seed.bareIds, 0)
        XCTAssertEqual(ledger.journal.count, 14)

        let deltas = SpanComposer.deltas(from: ledger.journal, epoch: 4, aliases: window.virtual.aliases)
        XCTAssertEqual(deltas.count, 16)
        XCTAssertTrue(deltas.allSatisfy { $0.epoch == 4 })
        XCTAssertEqual(deltas.filter { $0.group == Seed.group(1) }.count, 6, "the move across weeks, its ↶ and its ↷: 2 pages each")
        XCTAssertEqual(deltas.filter { $0.group == Seed.group(2) }.count, 4, "the other move and its ↶")
        XCTAssertEqual(deltas.filter { $0.group == nil }.count, 6)

        let current = window.virtual.with(ledgerPage: ledger.page)
        var applied: [String: InkPage] = [:]
        for start in starts {
            let mine = deltas.filter { $0.pageId == start.pageId }.reduce(start) { SpanComposer.apply($1, to: $0) }
            let expected = SpanComposer.extract(pageId: start.pageId, from: current)
            XCTAssertEqual(mine.strokes, expected.strokes, start.pageId)
            XCTAssertEqual(mine.deleted, expected.deleted, start.pageId)
            XCTAssertFalse(mine.contentDiffers(from: expected), start.pageId)
            applied[start.pageId] = mine
        }
        func bare(_ name: String) -> String { SpanName.strip(id: name) }
        XCTAssertEqual(applied[weekA]?.liveStrokeIds, ["a-1", bare(a(5)), bare(a(8))].sorted())
        XCTAssertEqual(applied[weekA]?.deleted, [bare(a(1)): base + 5, "a-2": base + 15])
        XCTAssertEqual(applied[weekB]?.liveStrokeIds, [bare(b(2))])
        XCTAssertEqual(applied[weekB]?.deleted, ["b-1": base + 4, bare(b(4)): base + 8, bare(b(6)): base + 14])
        XCTAssertEqual(applied[weekC]?.liveStrokeIds, ["c-2", bare(c(7)), bare(c(9))].sorted())
        XCTAssertEqual(applied[weekC]?.deleted, ["c-old": stamp, "c-1": base + 3, bare(c(3)): base + 11])
        XCTAssertEqual(applied[weekC]?.strokes[bare(c(7))]?.cell, .grid, "a delta carries the page's own cell")
    }

    // MARK: §3.3 3, §4.4 — the history a leaving page takes with it

    /// `pruneHistory(touching:)` drops the newest step that touches a leaving page and every step behind it,
    /// on ↶ and on ↷, and every step of a group one of them had (with what lies behind that one). First:
    /// strokes on the first, second, third and first week, the last one undone; the second week leaves: the
    /// two oldest steps go, the third week's step and the ↷ of the first week's stay (one ↷, one ↶, then
    /// nothing). Second: a move from the first week to the second and one from the third to the second share
    /// a group (seeded), with strokes between and after; the first week leaves: everything but the newest
    /// step goes, the second move although it never touched the first week. Third: the group is also reached
    /// through an older step that goes only because it lies behind a touching one: a stroke on the second
    /// week moved to the third, a stroke on the first week, the copy moved back to the second week (the two
    /// moves share a group); the first week leaves: everything goes, the newest move with the group of the
    /// oldest. The page itself never changes. The one-page ledger's steps carry no page: nothing goes.
    /// Fails if the steps behind a touching one stayed (a third ↶ would succeed), if a step of a page that
    /// stays were dropped, or without the group rule (the second move and the stroke before it would stay:
    /// a second ↶ would succeed), or if the groups were taken only from the steps that touch the leaving
    /// page (the newest move of the third case would stay: ↶ would succeed).
    func testPruneHistoryDropsTouchingStepsAndTheirGroup() throws {
        // Touching steps and those behind them.
        let window = weekWindow()
        let seed = Seed(prefix: "13f00000", baseMs: 1_790_700_000_000)
        let ledger = joinedLedger(window, seed: seed)
        draw(pen(at: CGPoint(x: 300, y: 400), second: 1), on: ledger)
        draw(pen(at: CGPoint(x: 1400 + 300, y: 400), second: 2), on: ledger)
        draw(pen(at: CGPoint(x: 2800 + 300, y: 400), second: 3), on: ledger)
        draw(pen(at: CGPoint(x: 600, y: 900), second: 4), on: ledger)
        XCTAssertNotNil(ledger.undo())
        let live = ledger.page.liveStrokeIds
        XCTAssertEqual(live, ["w-2026-11-02|" + seed.id(1), "w-2026-11-09|" + seed.id(2), "w-2026-11-16|" + seed.id(3)])
        ledger.pruneHistory(touching: ["w-2026-11-23"])
        ledger.pruneHistory(touching: [])
        ledger.pruneHistory(touching: [weekB])
        XCTAssertEqual(ledger.page.liveStrokeIds, live, "the page is not touched")
        XCTAssertNotNil(ledger.redo(), "the ↷ of the first week's stroke stays")
        XCTAssertEqual(ledger.page.liveStrokeIds.count, 4)
        XCTAssertNotNil(ledger.undo())
        XCTAssertNotNil(ledger.undo(), "the third week's step stays")
        XCTAssertEqual(ledger.page.liveStrokeIds, ["w-2026-11-02|" + seed.id(1), "w-2026-11-09|" + seed.id(2)])
        XCTAssertNil(ledger.undo(), "the second week's step and the one behind it are gone")
        ledger.pruneHistory(touching: [weekA])
        XCTAssertNotNil(ledger.redo(), "the ↷ of the third week")
        XCTAssertNil(ledger.redo(), "the ↷ of the first week's second stroke went with the first week")

        // A group.
        let grouped = weekWindow()
        let groupSeed = Seed(prefix: "13f10000", baseMs: 1_790_800_000_000)
        let groupLedger = joinedLedger(grouped, seed: groupSeed)
        let mark = Seed.group(7)
        groupLedger.makeGroup = { mark }
        let first = try XCTUnwrap(draw(pen(at: CGPoint(x: 300, y: 400), second: 1), on: groupLedger).added.first)
        XCTAssertEqual(groupLedger.moveStrokes(ids: [first.id], by: CGVector(dx: 1400, dy: 0)).newIds, ["w-2026-11-09|" + groupSeed.id(2)])
        let third = try XCTUnwrap(draw(pen(at: CGPoint(x: 2800 + 300, y: 400), second: 3), on: groupLedger).added.first)
        XCTAssertEqual(groupLedger.moveStrokes(ids: [third.id], by: CGVector(dx: -1400, dy: 200)).newIds, ["w-2026-11-09|" + groupSeed.id(4)])
        draw(pen(at: CGPoint(x: 2800 + 700, y: 900), second: 5), on: groupLedger)
        XCTAssertEqual(groupLedger.journal.map(\.group), [nil, mark, nil, mark, nil])
        let before = groupLedger.page.liveStrokeIds
        groupLedger.pruneHistory(touching: [weekA])
        XCTAssertEqual(groupLedger.page.liveStrokeIds, before)
        XCTAssertNotNil(groupLedger.undo(), "the newest step stays")
        XCTAssertEqual(groupLedger.page.liveStrokeIds, ["w-2026-11-09|" + groupSeed.id(2), "w-2026-11-09|" + groupSeed.id(4)])
        XCTAssertNil(groupLedger.undo(), "the second move went with its group, and the stroke behind it")

        // A group reached through an older step that goes only because it lies behind a touching one.
        let behindSeed = Seed(prefix: "13f20000", baseMs: 1_790_850_000_000)
        let behind = joinedLedger(weekWindow(), seed: behindSeed)
        behind.makeGroup = { mark }
        let onB = try XCTUnwrap(draw(pen(at: CGPoint(x: 1400 + 300, y: 400), second: 1), on: behind).added.first)
        let toC = behind.moveStrokes(ids: [onB.id], by: CGVector(dx: 1400, dy: 0)).newIds
        XCTAssertEqual(toC, ["w-2026-11-16|" + behindSeed.id(2)])
        draw(pen(at: CGPoint(x: 300, y: 900), second: 2), on: behind)
        let backToB = behind.moveStrokes(ids: toC, by: CGVector(dx: -1400, dy: 100)).newIds
        XCTAssertEqual(backToB, ["w-2026-11-09|" + behindSeed.id(4)])
        XCTAssertEqual(behind.journal.map(\.group), [nil, mark, nil, mark])
        let kept = behind.page.liveStrokeIds
        behind.pruneHistory(touching: [weekA])
        XCTAssertEqual(behind.page.liveStrokeIds, kept)
        XCTAssertNil(behind.undo(), "the newest move went with the group of the oldest, which lay behind the first week's stroke")
        XCTAssertFalse(behind.canRedo)

        // The one-page path: no page in any name.
        let single = InkLedger(page: InkPage.empty(pageId: weekB), layout: window.layout.pages[1], deviceId: "span-test")
        _ = single.drawing()
        draw(pen(at: CGPoint(x: 300, y: 400), second: 1), on: single)
        draw(pen(at: CGPoint(x: 600, y: 400), second: 2), on: single)
        single.pruneHistory(touching: [weekB, "grid"])
        XCTAssertNotNil(single.undo())
        XCTAssertNotNil(single.undo())
        XCTAssertNil(single.undo())
    }

    // MARK: §3.3 4 — needsMoreRoom

    /// The day's free memo area (`extra`, 6,000 lu high) of the middle day of a window of three days: a
    /// stroke whose bottom is 5,959.75 lu needs more room (`PaperGrowth.tailHeight` = bottom + 50 > 6,000),
    /// one at 5,939.75 does not, and the time grid never grows — the answers of the one-page ledger for the
    /// page's own names.
    /// Fails if the prefix were not taken off: `PaperGrowth` would read "d-2026-11-10|extra" as an ordinary
    /// cell (bottom + 12 > 6,000) and say no at 5,959.75 (the memo area would only grow at its very end).
    func testNeedsMoreRoomStripsThePrefix() {
        let plan = SpanPlan(kind: .day, weekStart: .monday, deviceClass: .iPad11, orientation: .portrait)
        let first = plan.index(containing: DayKey(year: 2026, month: 11, day: 9))
        let days: [any PageLayout] = (first..<first + 3).map { index in
            DayLayoutEngine.layout(DayLayoutInput(day: plan.firstDay(at: index), events: [], inkBottoms: [:], now: now))
        }
        XCTAssertEqual(days.map { $0.pageId }, ["d-2026-11-09", "d-2026-11-10", "d-2026-11-11"])
        let layout = SpanLayout(pages: days, plan: plan, firstIndex: first, session: 2)
        let virtual = SpanComposer.compose(days.map { InkPage.empty(pageId: $0.pageId) }, plan: plan, session: 2)
        let ledger = InkLedger(page: virtual.ledgerPage, layout: layout, deviceId: "span-test")
        ledger.ownerId = { cell in Self.ownerName(cell: cell, fresh: InkStroke.newId()) }
        let extra = CellKey(raw: "d-2026-11-10|extra")
        let grid = CellKey(raw: "d-2026-11-10|grid")
        XCTAssertEqual(layout.cells[extra], CGRect(x: 1000, y: 2400, width: 1000, height: 6000))
        func stroke(_ cell: CellKey, y: CGFloat) -> InkStroke {
            InkStroke(id: "probe", cell: cell, tool: InkModel.InkTool.pen, color: "#000000", t: 1_790_000_000_000,
                      points: [InkPoint(x: 100, y: y, dtMs: 0, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)])
        }
        XCTAssertEqual(stroke(extra, y: 5958).bottom, 5959.75)
        XCTAssertTrue(ledger.needsMoreRoom(stroke(extra, y: 5958)))
        XCTAssertFalse(ledger.needsMoreRoom(stroke(extra, y: 5938)))
        XCTAssertFalse(ledger.needsMoreRoom(stroke(grid, y: 2398)), "the time grid never grows")
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: extra, cellHeight: 6000, inkBottom: 5959.75),
                       "the prefixed name alone is an ordinary cell for PaperGrowth")

        let single = InkLedger(page: InkPage.empty(pageId: "d-2026-11-10"), layout: days[1], deviceId: "span-test")
        XCTAssertTrue(single.needsMoreRoom(stroke(.extra, y: 5958)))
        XCTAssertFalse(single.needsMoreRoom(stroke(.extra, y: 5938)))
        XCTAssertFalse(single.needsMoreRoom(stroke(.grid, y: 2398)))
    }

    // MARK: §3.3 5 — removals the ledger refuses

    /// A change that is not the eraser's (`allowRemovals` false) tombstones nothing: the stroke the canvas
    /// lost (a-2) comes back in `refusedRemovals` (`needsRebuild`), stays live and is not journalled, while
    /// the new stroke drawn in the same change is taken in (and ↶ takes back only it); the rebuilt drawing
    /// holds a-2 again. A refused change with nothing new is `isEmpty` and makes no history step (↷ is
    /// kept). The eraser (the default) then tombstones a-3. The one-page ledger (`ownerId` nil) ignores the
    /// flag and takes the same kind of change as 1.2.3 does (§3.3 5: 「1 ページの道は今どおり（常に許す）」), so
    /// a canvas may pass `allowRemovals: tool.isEraser` on both paths.
    /// Fails if `allowRemovals` were ignored on the joined path (a-2 would be tombstoned and journalled, and
    /// the rebuild would not be asked for), or obeyed on the one-page path (a-1 would stay live and be
    /// refused there).
    func testCanvasRemovalWithoutEraserRebuilds() throws {
        let start = page(weekA, [stored("a-1", x: 200, y: 300, t: 1_780_000_001_000), stored("a-2", x: 600, y: 300, t: 1_780_000_002_000),
                                 stored("a-3", x: 1000, y: 300, t: 1_780_000_003_000)])
        let window = weekWindow([start])
        let seed = Seed(prefix: "13a10000", baseMs: 1_790_900_000_000)
        let ledger = joinedLedger(window, seed: seed)
        let a1 = "w-2026-11-02|a-1"
        let a2 = "w-2026-11-02|a-2"
        let a3 = "w-2026-11-02|a-3"

        let canvas = erasing([a2], from: ledger).strokes + [pen(at: CGPoint(x: 1400 + 500, y: 800), second: 1)]
        let change = ledger.applyCanvasChange(PKDrawing(strokes: canvas), allowRemovals: false)
        XCTAssertTrue(change.needsRebuild)
        XCTAssertEqual(change.refusedRemovals, [a2])
        XCTAssertEqual(change.removedIds, [])
        XCTAssertEqual(change.added.map(\.id), ["w-2026-11-09|" + seed.id(1)])
        XCTAssertTrue(ledger.page.isLive(a2))
        XCTAssertNil(ledger.page.deleted[a2])
        XCTAssertEqual(ledger.journal, [SpanJournalEntry(added: change.added, removed: [], at: 1_790_900_000_001)])
        XCTAssertEqual(ledger.drawing().strokes.count, 4, "the rebuilt drawing shows a-2 again")
        XCTAssertNotNil(ledger.undo())
        XCTAssertEqual(ledger.page.liveStrokeIds, [a1, a2, a3])
        XCTAssertFalse(ledger.canUndo)

        ledger.journal.removeAll()
        let only = ledger.applyCanvasChange(erasing([a3], from: ledger), allowRemovals: false)
        XCTAssertTrue(only.isEmpty)
        XCTAssertTrue(only.needsRebuild)
        XCTAssertEqual(only.refusedRemovals, [a3])
        XCTAssertTrue(ledger.page.isLive(a3))
        XCTAssertTrue(ledger.journal.isEmpty)
        XCTAssertFalse(ledger.canUndo)
        XCTAssertTrue(ledger.canRedo, "a refused change makes no step and keeps ↷")

        let erased = ledger.applyCanvasChange(erasing([a3], from: ledger))
        XCTAssertEqual(erased.removedIds, [a3])
        XCTAssertFalse(erased.needsRebuild)
        XCTAssertEqual(ledger.page.liveStrokeIds, [a1, a2])
        let tombstone = try XCTUnwrap(ledger.page.deleted[a3])
        XCTAssertEqual(ledger.journal, [SpanJournalEntry(added: [], removed: [a3], at: tombstone)])

        let single = InkLedger(page: start, layout: window.layout.pages[0], deviceId: "span-test")
        single.nowMs = { 1_790_950_000_001 }
        _ = single.drawing()
        let takenThere = single.applyCanvasChange(erasing(["a-1"], from: single), allowRemovals: false)
        XCTAssertEqual(takenThere.removedIds, ["a-1"])
        XCTAssertEqual(takenThere.refusedRemovals, [])
        XCTAssertFalse(takenThere.needsRebuild)
        XCTAssertFalse(single.page.isLive("a-1"))
        XCTAssertEqual(single.page.deleted["a-1"], 1_790_950_000_001)
        XCTAssertTrue(single.canUndo)
        XCTAssertTrue(single.journal.isEmpty)
    }

    /// §3.16: one change of the joined path may not tombstone more than 50 strokes, nor at least half of a
    /// window page's live strokes when that is 20 or more. Refused (nothing tombstoned, nothing journalled,
    /// no step, every lost id in `refusedRemovals`): 51 of 120, 20 of 40, 30 + 25 on two pages of 100, and 20
    /// of a page of 40 while the next page holds 100. Taken: 50 of 120, 19 of 38, 20 of 41, and 20 of a page
    /// of 50 with 10 of a page of 100 (30 in all). A lasso deletion (`removeStrokes`) of 60 is not limited,
    /// nor is the one-page path (60 of 120 at once, as in 1.2.3).
    /// Fails if the limit were not applied (51, 20 of 40 and 55 would be tombstoned), or applied to the
    /// lasso deletion or to the one-page path, or if a boundary moved (50, 19, 20 of 41 refused). The two
    /// cases with a second page that holds strokes fail if the half were taken of the whole window's live
    /// strokes (20 of 40 beside 100 would be taken) or of the whole change's count (30 against a page of 50
    /// would be refused) instead of the page's own.
    func testTooManyRemovalsAtOnceRebuild() throws {
        struct Case {
            let name: String
            let taken: [(page: String, count: Int)]
            let pages: [(id: String, count: Int)]
            var lost: Int { taken.reduce(0) { $0 + $1.count } }
        }
        func erase(_ test: Case) -> (change: InkChange, ledger: InkLedger, live: Int) {
            let storedPages = test.pages.enumerated().map { index, page in
                crowdedPage(page.id, count: page.count, tag: "s", baseT: 1_780_000_000_000 + index * 10_000_000)
            }
            let ledger = joinedLedger(weekWindow(storedPages), seed: Seed(prefix: "13b10000", baseMs: 1_791_000_000_000))
            let live = ledger.page.liveStrokeCount
            var ids = Set<String>()
            for take in test.taken {
                for n in 0..<take.count { ids.insert(SpanName.prefixed(id: "s-\(n)", page: take.page)) }
            }
            return (ledger.applyCanvasChange(erasing(ids, from: ledger)), ledger, live)
        }

        let refused = [
            Case(name: "51 of 120", taken: [(weekA, 51)], pages: [(weekA, 120)]),
            Case(name: "20 of 40", taken: [(weekA, 20)], pages: [(weekA, 40)]),
            Case(name: "30 + 25 on two pages of 100", taken: [(weekA, 30), (weekB, 25)], pages: [(weekA, 100), (weekB, 100)]),
            Case(name: "20 of 40 beside a page of 100", taken: [(weekA, 20)], pages: [(weekA, 40), (weekB, 100)]),
        ]
        for test in refused {
            let (change, ledger, live) = erase(test)
            XCTAssertTrue(change.needsRebuild, test.name)
            XCTAssertEqual(change.refusedRemovals.count, test.lost, test.name)
            XCTAssertEqual(change.removedIds, [], test.name)
            XCTAssertEqual(ledger.page.liveStrokeCount, live, test.name)
            XCTAssertTrue(ledger.page.deleted.isEmpty, test.name)
            XCTAssertTrue(ledger.journal.isEmpty, test.name)
            XCTAssertFalse(ledger.canUndo, test.name)
        }

        let taken = [
            Case(name: "50 of 120", taken: [(weekA, 50)], pages: [(weekA, 120)]),
            Case(name: "19 of 38", taken: [(weekA, 19)], pages: [(weekA, 38)]),
            Case(name: "20 of 41", taken: [(weekA, 20)], pages: [(weekA, 41)]),
            Case(name: "20 of 50 + 10 of 100", taken: [(weekA, 20), (weekB, 10)], pages: [(weekA, 50), (weekB, 100)]),
        ]
        for test in taken {
            let (change, ledger, live) = erase(test)
            XCTAssertFalse(change.needsRebuild, test.name)
            XCTAssertEqual(change.removedIds.count, test.lost, test.name)
            XCTAssertEqual(ledger.page.liveStrokeCount, live - test.lost, test.name)
            XCTAssertEqual(ledger.journal.count, 1, test.name)
            XCTAssertEqual(ledger.journal.first?.removed.count, test.lost, test.name)
            XCTAssertTrue(ledger.canUndo, test.name)
        }

        let lasso = joinedLedger(weekWindow([crowdedPage(weekA, count: 120, tag: "s", baseT: 1_780_000_000_000)]),
                                 seed: Seed(prefix: "13b20000", baseMs: 1_791_100_000_000))
        let selected = (0..<60).map { "w-2026-11-02|s-\($0)" }
        XCTAssertEqual(lasso.removeStrokes(ids: selected).removedIds.count, 60, "a lasso deletion is not limited")
        XCTAssertEqual(lasso.page.liveStrokeCount, 60)

        let crowded = crowdedPage(weekA, count: 120, tag: "s", baseT: 1_780_000_000_000)
        let single = InkLedger(page: crowded, layout: weekWindow().layout.pages[0], deviceId: "span-test")
        _ = single.drawing()
        let sweep = single.applyCanvasChange(erasing(Set((0..<60).map { "s-\($0)" }), from: single))
        XCTAssertFalse(sweep.needsRebuild)
        XCTAssertEqual(sweep.removedIds.count, 60, "the one-page path takes any erasure, as in 1.2.3")
        XCTAssertEqual(single.page.liveStrokeCount, 60)
    }
}
