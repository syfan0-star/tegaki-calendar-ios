@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §6.6, §10.2 row S, D3 の 7, D7, D22): the holes H1–H3 of 1.2.3, on both paths, over a
// live `SyncEngine` (a temporary `InkPageStore`, `InMemoryCloudDatabase`, `TestSleeper`; SessionTestBed in
// SpanSessionTests.swift).
//
// - The one-page path: `OnePageSession` with stand-ins for the screen's body (`OnePageScreenStandIn`: `.id(canvasIdentity)`
//   makes a new canvas when the identity changes, else the canvas takes the page) and for the canvas
//   (`OnePageCanvasStandIn`: the real `InkLedger`, reloaded keeping its history for the same page as
//   InkCanvasView.swift:857-861 does, writing through the binding's gate, at once or on the next turn as
//   `publishPage` does, :1478-1508).
// - The joined path: `SpanSession` with the real `InkLedger` on the window (its journal into the inbox) or the value
//   stand-in `JoinedLedgerStandIn`.
// Each H test fails with its fix taken out (43fe366's behaviour); docs/M7C.md records the runs.

/// The canvas of the one-page path, as far as these tests need it.
@MainActor
final class OnePageCanvasStandIn {
    let identity: String
    let ledger: InkLedger
    private let base: String
    private weak var session: OnePageSession?
    private var second: TimeInterval = 0

    init(_ session: OnePageSession, base: String, layout: any PageLayout, seed: Int) {
        identity = session.canvasIdentity(base: base)
        self.base = base
        self.session = session
        ledger = InkLedger(page: session.page, layout: layout, deviceId: "erase-test")
        var n = 0
        ledger.makeId = {
            n += 1
            return String(format: "%08x-0000-4000-8000-%012x", seed, n)
        }
        var ms = 1_790_000_200_000 + seed * 1000
        ledger.nowMs = {
            ms += 1
            return ms
        }
        _ = ledger.drawing()
    }

    /// `update(from:)` for the screen's page of the same id: a page that changed is reloaded, the history kept.
    func update(from page: InkPage) {
        guard page.pageId == ledger.page.pageId, page != ledger.page else { return }
        ledger.reload(page: page, keepHistory: true)
    }

    /// The binding's write of the ledger's page (`publishPage`); true when the screen took it.
    @discardableResult
    func publish() -> Bool {
        let page = ledger.page
        return session?.canvasWrote(page, madeFor: identity, base: base) ?? false
    }

    /// `publishPage` inside `updateUIView`: the write of the page as it is now, handed on to the next turn.
    func publishLater() -> () -> Bool {
        let page = ledger.page
        let identity = identity
        let base = base
        return { [weak session] in session?.canvasWrote(page, madeFor: identity, base: base) ?? false }
    }

    /// The pen writes a short stroke at `origin` (paper lu); the change is published unless `publish` is false.
    @discardableResult
    func draw(at origin: CGPoint, publish: Bool = true) -> String? {
        second += 1
        let points = (0..<5).map { i in
            PKStrokePoint(location: CGPoint(x: origin.x + CGFloat(i) * 3, y: origin.y + CGFloat(i)), timeOffset: TimeInterval(i) * 0.016,
                          size: CGSize(width: 3.5, height: 3.5), opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black),
                              path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 1_790_000_000 + second)),
                              transform: .identity, mask: nil)
        let change = ledger.applyCanvasChange(PKDrawing(strokes: ledger.drawing().strokes + [stroke]))
        if publish { self.publish() }
        return change.added.first?.id
    }

    func erase(_ ids: [String]) {
        _ = ledger.removeStrokes(ids: ids)
        publish()
    }

    /// ↶: true when the ledger had a step to undo (then the page is published).
    @discardableResult
    func undo() -> Bool {
        guard ledger.undo() != nil else { return false }
        publish()
        return true
    }
}

/// The screen's body for the one-page path: the canvas is made anew when `canvasIdentity` changes (`.id(...)`), else
/// it takes the page.
@MainActor
final class OnePageScreenStandIn {
    let session: OnePageSession
    let base: String
    let layout: any PageLayout
    private(set) var canvas: OnePageCanvasStandIn
    private(set) var canvasesMade = 1

    init(_ session: OnePageSession, base: String, layout: any PageLayout) {
        self.session = session
        self.base = base
        self.layout = layout
        canvas = OnePageCanvasStandIn(session, base: base, layout: layout, seed: 1)
    }

    func render() {
        if canvas.identity != session.canvasIdentity(base: base) {
            canvasesMade += 1
            canvas = OnePageCanvasStandIn(session, base: base, layout: layout, seed: canvasesMade)
        } else {
            canvas.update(from: session.page)
        }
    }
}

@MainActor
final class ScreenEraseTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!

    private let week = "w-2026-11-16"
    private let otherWeek = "w-2026-11-23"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)

    override func setUp() async throws {
        bed = try SessionTestBed("ScreenEraseTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
    }

    override func tearDown() async throws {
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    private func weekLayout(_ focus: DayKey) -> any PageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: [], inkBottoms: [:], now: bed.now, calendar: SessionTestBed.tokyo))
    }

    /// A page of `ids` (grid strokes) saved and sent, then shown on the one-page path as the screen shows it: the
    /// session reads it, the engine's two hooks go to it (the screen's `appear`), the body makes the canvas.
    private func showSyncedPage(_ ids: [String]) async throws -> (OnePageSession, OnePageScreenStandIn) {
        await bed.startSynced()
        try bed.engine.save(bed.page(week, ids))
        await bed.flushDebounce()
        XCTAssertNotNil(bed.db.records[week])
        let sleeper = bed.sessionSleeper
        let session = OnePageSession(sync: bed.engine, sleep: { await sleeper.sleep($0) })
        session.open(bed.engine.load(week))
        bed.engine.onRemoteUpdate = { [weak session] in session?.applyRemote($0) }
        bed.engine.onRemoteDelete = { [weak session] in session?.remoteDeleted($0) }
        let screen = OnePageScreenStandIn(session, base: "\(week)|monday", layout: weekLayout(nov16))
        return (session, screen)
    }

    /// The live stroke ids of the page's record in the fake iCloud (nil: no record).
    private func cloudIds(_ pageId: String) throws -> Set<String>? {
        guard let record = bed.db.records[pageId] else { return nil }
        return Set(try InkPageRecord.page(from: record).liveStrokeIds)
    }

    // MARK: - The one-page path (OnePageSession)

    /// H1: another device's 「全て消す」 deletes the shown page's record; the page here empties (with the stroke written
    /// meanwhile, §6.6), and the next stroke saves a page that holds that stroke only — the erased strokes never go
    /// back to iCloud.
    func testRemoteEraseIsNotUndoneByTheNextSave() async throws {
        let (session, screen) = try await showSyncedPage(["a", "b"])
        screen.canvas.draw(at: CGPoint(x: 200, y: 300))
        XCTAssertTrue(session.isDirty)
        bed.db.simulateRemoteDelete(week)
        await bed.engine.syncNow()
        XCTAssertEqual(session.page.liveStrokeCount, 0)
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.epoch, 1)
        screen.render()
        XCTAssertEqual(screen.canvasesMade, 2, "the canvas is made anew from the empty page")
        let fresh = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 400, y: 600)))
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertEqual(bed.live(week), [fresh])
        XCTAssertEqual(try cloudIds(week), [fresh])
    }

    /// H1: after the record deletion, ↶ (here of an erase made before it) has nothing to bring back: the canvas and its
    /// history are new.
    func testUndoAfterRemoteEraseDoesNotBringStrokesBack() async throws {
        let (session, screen) = try await showSyncedPage(["a", "b"])
        screen.canvas.erase(["b"])
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertEqual(try cloudIds(week), ["a"])
        XCTAssertTrue(screen.canvas.ledger.canUndo)
        bed.db.simulateRemoteDelete(week)
        await bed.engine.syncNow()
        screen.render()
        XCTAssertFalse(screen.canvas.ledger.canUndo)
        XCTAssertFalse(screen.canvas.undo())
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertEqual(session.page.liveStrokeCount, 0)
        XCTAssertFalse(bed.store.exists(week))
        XCTAssertNil(try cloudIds(week))
    }

    /// H1, H3 (§2.1's last point): a write the old canvas handed on to the next turn, arriving after the canvas was made
    /// anew (「全て消す」, then a record deletion), is dropped by the binding's identity gate.
    func testLatePublishFromTheOldCanvasIsDropped() async throws {
        let (session, screen) = try await showSyncedPage(["a", "b"])
        // 「全て消す」 (the screen's `eraseAllInk`: the session, then the engine).
        screen.canvas.draw(at: CGPoint(x: 200, y: 300), publish: false)
        let late = screen.canvas.publishLater()
        session.eraseAll()
        screen.render()
        try await bed.engine.eraseEverything()
        XCTAssertFalse(late(), "the old canvas's late write is not taken")
        XCTAssertEqual(session.page.liveStrokeCount, 0)
        XCTAssertFalse(session.isDirty)
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertNil(try cloudIds(week))

        // A record deletion from another device.
        let mine = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 300, y: 400)))
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertEqual(try cloudIds(week), [mine])
        screen.canvas.draw(at: CGPoint(x: 500, y: 700), publish: false)
        let late2 = screen.canvas.publishLater()
        bed.db.simulateRemoteDelete(week)
        await bed.engine.syncNow()
        screen.render()
        XCTAssertFalse(late2())
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertFalse(bed.store.exists(week))
        XCTAssertNil(try cloudIds(week))
    }

    /// H2: 「消して始める」 closes the screen's page before the engine's `await`; while it waits, going to the background,
    /// the export, the old canvas's late write, a new stroke, the save timer and a page change write nothing, so the new
    /// account's store and iCloud never get the old account's page.
    func testEraseAndStartClosesTheScreenBeforeAwait() async throws {
        let (session, screen) = try await showSyncedPage(["a", "b"])
        screen.canvas.draw(at: CGPoint(x: 200, y: 300)) // unsaved, its timer waiting
        let oldCanvas = screen.canvas
        XCTAssertTrue(session.isDirty)
        bed.db.simulateZoneDeleted()
        bed.db.simulateAccountChange(status: .available, userName: "_user-b")
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(bed.status, .accountMismatch)

        // The screen's `chooseAccount(.eraseInk)`: the session first, then the engine's await (held at its account check).
        bed.db.pause(.accountStatus)
        let checks = bed.db.calls.filter { $0 == .accountStatus }.count
        session.beginEraseAndStart()
        screen.render()
        XCTAssertEqual(screen.canvasesMade, 2)
        let answer = Task { @MainActor in await self.bed.engine.resolveAccountChange(.eraseInk) }
        await bed.yieldUntil { bed.db.calls.filter { $0 == .accountStatus }.count > checks }
        XCTAssertEqual(bed.store.allPageIds(), [], "the engine emptied the store before its await")

        session.saveNow()                                  // (1) the background (`scenePhaseChanged`)
        session.saveNow()                                  // (3) the export (`openExport`)
        XCTAssertFalse(oldCanvas.publish())                // the old canvas's late write
        screen.canvas.draw(at: CGPoint(x: 400, y: 500))    // (4) a new stroke on the new canvas
        await bed.sessionSleeper.advance()                 // (5) the 1.5 s timers
        session.saveNow()                                  // (2) another page (`show`): saved first …
        session.open(bed.engine.load(otherWeek))           //     … then opened
        XCTAssertEqual(bed.store.allPageIds(), [], "nothing was written meanwhile")
        XCTAssertEqual(bed.engine.state.dirty, [])

        bed.db.resume()
        await answer.value
        XCTAssertEqual(bed.engine.state.account, "_user-b")
        session.reload(bed.engine.load(otherWeek))         // `reloadShownPage`
        session.endEraseAndStart()
        await bed.flushSessionTimers()
        await bed.flushDebounce()
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertNil(bed.db.records[week])
        XCTAssertEqual(bed.engine.state.dirty, [])
        // Saving goes on afterwards.
        var page = session.page
        page.add(bed.stroke("new-account", x: 300))
        XCTAssertTrue(session.canvasWrote(page, madeFor: session.canvasIdentity(base: "\(otherWeek)|monday"), base: "\(otherWeek)|monday"))
        await bed.flushSessionTimers()
        XCTAssertEqual(bed.live(otherWeek), ["new-account"])
    }

    /// H3: after 「全て消す」 and after 「消して始める」, ↶ has nothing: the canvas is made anew each time.
    func testUndoIsEmptyAfterEraseAllAndEraseAndStart() async throws {
        let (session, screen) = try await showSyncedPage(["a", "b"])
        screen.canvas.erase(["b"])
        XCTAssertTrue(screen.canvas.ledger.canUndo)
        session.eraseAll()
        screen.render()
        XCTAssertEqual(screen.canvasesMade, 2)
        XCTAssertFalse(screen.canvas.ledger.canUndo)
        XCTAssertFalse(screen.canvas.undo())
        XCTAssertEqual(session.page.liveStrokeCount, 0)

        let id = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 100, y: 100)))
        screen.canvas.erase([id])
        XCTAssertTrue(screen.canvas.ledger.canUndo)
        session.beginEraseAndStart()
        screen.render()
        XCTAssertEqual(screen.canvasesMade, 3)
        XCTAssertFalse(screen.canvas.ledger.canUndo)
        XCTAssertFalse(screen.canvas.undo())
        session.endEraseAndStart()
        XCTAssertEqual(session.page.liveStrokeCount, 0)
        XCTAssertFalse(session.isDirty)
    }

    /// The pieces 1.2.3 had, unchanged (D3 の 7): the timer saves 1.5 s after the last change, once; a remote update merges
    /// and keeps the unsaved stroke (dirty only when this device has strokes the update lacks); a migrated page is saved.
    func testOnePageSessionKeepsTheOneTwoThreeSaving() async throws {
        let (session, screen) = try await showSyncedPage(["a"])
        session.onSaveFailed = { _ in XCTFail("no save fails here") }
        let mine = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 100, y: 100)))
        screen.canvas.draw(at: CGPoint(x: 200, y: 100))
        await bed.yieldUntil { bed.sessionSleeper.waiting == 2 }
        XCTAssertEqual(Array(bed.sessionSleeper.recorded.suffix(2)), [1.5, 1.5])
        XCTAssertFalse(bed.store.load(week).isLive(mine))
        await bed.flushSessionTimers()
        XCTAssertTrue(bed.store.load(week).isLive(mine))
        XCTAssertEqual(bed.live(week).count, 3)
        // An update from another device: merged, nothing of this device's to send back.
        var theirs = bed.store.load(week)
        theirs.add(bed.stroke("theirs", x: 600))
        XCTAssertTrue(session.applyRemote(theirs))
        XCTAssertFalse(session.isDirty)
        XCTAssertTrue(session.page.isLive("theirs"))
        XCTAssertFalse(session.applyRemote(theirs), "the same update again changes nothing")
        XCTAssertFalse(session.applyRemote(bed.page(otherWeek, ["x"])), "another page is not the shown one")
        // A stroke of the last 1.5 s survives an update that lacks it, and makes the page dirty.
        screen.render()
        let unsaved = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 300, y: 300)))
        var older = theirs
        older.add(bed.stroke("theirs2", x: 700))
        XCTAssertTrue(session.applyRemote(older))
        XCTAssertTrue(session.page.isLive(unsaved))
        XCTAssertTrue(session.isDirty)
        // The growth-cap notice: once per open page.
        XCTAssertTrue(session.noteGrowthCap(pageId: week))
        XCTAssertFalse(session.noteGrowthCap(pageId: week))
        session.forgetGrowthCap()
        XCTAssertTrue(session.noteGrowthCap(pageId: week))
        XCTAssertEqual(session.records, [])
    }

    /// §3.16, 1.2.3's `scheduleSave` (CalendarRootScreen.swift:2520-2527 of 43fe366): every change starts the 1.5 s timer
    /// again, so the page is saved 1.5 s after the last change; the timer of an earlier change does nothing when it wakes.
    func testOnePageSaveTimerRunsAfterTheLastChange() async throws {
        let (session, screen) = try await showSyncedPage(["a"])
        let first = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 100, y: 100)))
        await bed.yieldUntil { bed.sessionSleeper.waiting == 1 }
        let second = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 200, y: 100)))
        await bed.yieldUntil { bed.sessionSleeper.waiting == 2 }
        let store = bed.store
        let pageId = self.week
        var storedWhenTheFirstWoke: Set<String>?
        // `advance()` wakes the two timers in order and settles in between: the first change's timer has run by then.
        bed.sessionSleeper.settle = {
            if storedWhenTheFirstWoke == nil { storedWhenTheFirstWoke = Set(store.load(pageId).liveStrokeIds) }
        }
        await bed.sessionSleeper.advance()
        XCTAssertEqual(storedWhenTheFirstWoke, ["a"], "the first change's timer saved nothing")
        XCTAssertEqual(bed.live(week), ["a", first, second], "the last change's timer saved the page")
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(bed.sessionSleeper.waiting, 0)
        XCTAssertEqual(session.records, [])
    }

    /// D14, D3 (2): the one-page path saves through `PageSlot.persist` too. A page of the shapes 1.2.3 writes passes the
    /// guard untouched; a window name that leaked into the shown page (only the joined path makes such names) is repaired
    /// at the save — the page's own prefix stripped, another page's name dropped — recorded and reported (Debug stops
    /// there), the shown page holds the repaired page, and the rest is written as it was. The page is not refused.
    func testOnePageSaveGoesThroughTheGuard() async throws {
        let (session, screen) = try await showSyncedPage(["a"])
        let mine = try XCTUnwrap(screen.canvas.draw(at: CGPoint(x: 100, y: 100)))
        session.saveNow()
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(bed.live(week), ["a", mine])
        XCTAssertEqual(bed.store.load(week).strokes[mine], session.page.strokes[mine])
        XCTAssertEqual(session.records, [])
        XCTAssertEqual(faults, [])

        var leaked = session.page
        leaked.add(bed.stroke(week + "|own", cell: SpanName.prefixed(.grid, page: week), x: 400))
        leaked.add(bed.stroke(otherWeek + "|theirs", cell: SpanName.prefixed(.grid, page: otherWeek), x: 500))
        XCTAssertTrue(session.canvasWrote(leaked, madeFor: screen.canvas.identity, base: screen.base))
        var failures: [String] = []
        session.onSaveFailed = { failures.append($0) }
        session.saveNow()
        XCTAssertEqual(failures, [], "a repaired page is saved, not refused")
        XCTAssertFalse(session.isDirty)
        let saved = bed.store.load(week)
        XCTAssertEqual(Set(saved.liveStrokeIds), ["a", mine, "own"])
        XCTAssertEqual(saved.strokes["own"]?.cell, .grid)
        XCTAssertEqual(saved.strokes[mine], leaked.strokes[mine])
        XCTAssertEqual(saved.strokes["a"], leaked.strokes["a"])
        XCTAssertFalse(saved.strokes.keys.contains { SpanGuard.isWindowName($0) })
        XCTAssertTrue(SpanGuard.checkForTransfer(saved))
        XCTAssertEqual(Set(session.page.liveStrokeIds), ["a", mine, "own"], "the shown page is the repaired one")
        XCTAssertEqual(faults.count, 1)
        XCTAssertEqual(session.records.count, 1)
        XCTAssertTrue(session.records.first?.contains("stripped \(week)|own") == true)
        XCTAssertTrue(session.records.first?.contains("dropped \(otherWeek)|theirs") == true)
    }

    // MARK: - The joined path (SpanSession)

    /// A week window around 11/16 (11/2 … 11/30) whose pages are read, `week` holding `ids` saved and sent.
    private func openSyncedWindow(_ ids: [String]) async throws -> SpanSession {
        await bed.startSynced()
        try bed.engine.save(bed.page(week, ids))
        await bed.flushDebounce()
        let session = bed.session(.week, focus: nov16)
        await session.prefetch()
        await bed.engine.waitUntilIdle() // its pages' fetch (`pagesOpened`) is done
        return session
    }

    /// H1 on the joined path: the record deletion empties the window page; a delta the canvas made before it took the
    /// new window (its old number) is dropped for that page, the safety net leaves the page alone until then, and the
    /// next stroke on the new window saves that stroke only.
    func testRemoteEraseIsNotUndoneByTheNextSaveOnTheJoinedPath() async throws {
        let session = try await openSyncedWindow(["a", "b"])
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: week)
        ledger.put()
        bed.db.simulateRemoteDelete(week)
        await bed.engine.syncNow()
        XCTAssertEqual(session.page(week)?.liveStrokeCount, 0)
        ledger.draw(on: week, x: 500) // still on the old window
        ledger.deliver()
        XCTAssertEqual(session.page(week)?.liveStrokeCount, 0)
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertFalse(bed.store.exists(week))
        ledger.take()
        let fresh = try XCTUnwrap(ledger.draw(on: week, x: 700))
        ledger.deliver()
        XCTAssertEqual(session.saveAll(), [])
        await bed.flushDebounce()
        let real = try XCTUnwrap(SpanName.split(fresh.id)?.local)
        XCTAssertEqual(bed.live(week), [real])
        XCTAssertEqual(try cloudIds(week), [real])
        XCTAssertEqual(faults, [])
    }

    /// H1 on the joined path, with the real ledger: the deleted page's ↶ steps go when the canvas takes the new window
    /// (`takeHistoryPrune` → `InkLedger.pruneHistory(touching:)`), so ↶ brings nothing back.
    func testUndoAfterRemoteEraseDoesNotBringStrokesBackOnTheJoinedPath() async throws {
        let session = try await openSyncedWindow(["a", "b"])
        let ledger = InkLedger(page: session.window.ledgerPage, layout: session.layout, deviceId: "erase-test")
        var n = 0
        ledger.ownerId = { [weak session] cell in
            n += 1
            return session?.ownerId(for: cell) ?? "x\(n)"
        }
        _ = ledger.drawing()
        var basis = session.windowVersion
        func put() {
            session.inbox.put(journal: ledger.journal, window: session.window.with(ledgerPage: ledger.page), basis: basis, epoch: session.epoch)
            ledger.journal = []
            session.drainInbox()
        }
        _ = ledger.removeStrokes(ids: [SpanName.prefixed(id: "b", page: week)])
        put()
        XCTAssertEqual(session.saveAll(), [])
        await bed.flushDebounce()
        XCTAssertEqual(try cloudIds(week), ["a"])
        XCTAssertTrue(ledger.canUndo)
        bed.db.simulateRemoteDelete(week)
        await bed.engine.syncNow()
        // The canvas takes the new window: its ledger reloads keeping the history, then drops the deleted page's steps.
        ledger.reload(page: session.window.ledgerPage, keepHistory: true)
        ledger.pruneHistory(touching: session.takeHistoryPrune())
        basis = session.windowVersion
        XCTAssertFalse(ledger.canUndo)
        XCTAssertNil(ledger.undo())
        put()
        XCTAssertEqual(session.saveAll(), [])
        await bed.flushDebounce()
        XCTAssertFalse(bed.store.exists(week))
        XCTAssertNil(try cloudIds(week))
        XCTAssertEqual(faults, [])
    }

    /// H1, H3 on the joined path: a delta of the canvas made before its page was reset (the old number) is dropped for
    /// that page; a page the reset did not touch takes its delta (the canvas's ledger had it all along).
    func testLatePublishFromTheOldCanvasIsDroppedOnTheJoinedPath() async throws {
        let session = try await openSyncedWindow(["a"])
        let ledger = JoinedLedgerStandIn(session)
        bed.db.simulateRemoteDelete(week)
        await bed.engine.syncNow()
        XCTAssertEqual(session.epoch, 1)
        ledger.draw(on: week)
        ledger.draw(on: otherWeek)
        ledger.deliver()
        XCTAssertEqual(session.page(week)?.liveStrokeCount, 0)
        XCTAssertEqual(session.page(otherWeek)?.liveStrokeCount, 1)
        XCTAssertTrue(session.records.contains { $0.hasPrefix("dropped a delta of number 0 for \(week)") })
        // 「全て消す」: every page.
        session.cancelAll()
        ledger.take()
        ledger.draw(on: otherWeek, x: 600)
        session.cancelAll() // the canvas's window is older again
        ledger.deliver()
        XCTAssertEqual(session.page(otherWeek)?.liveStrokeCount, 0)
        XCTAssertEqual(faults, [])
    }

    /// H2 on the joined path: `closeWithoutSaving()` before the `await`; afterwards no save, timer, delta or update writes
    /// anything of the old account.
    func testEraseAndStartClosesTheScreenBeforeAwaitOnTheJoinedPath() async throws {
        let session = try await openSyncedWindow(["a", "b"])
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: week)
        ledger.put()
        bed.db.simulateZoneDeleted()
        bed.db.simulateAccountChange(status: .available, userName: "_user-b")
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(bed.status, .accountMismatch)
        bed.db.pause(.accountStatus)
        let checks = bed.db.calls.filter { $0 == .accountStatus }.count
        session.closeWithoutSaving()
        let answer = Task { @MainActor in await self.bed.engine.resolveAccountChange(.eraseInk) }
        await bed.yieldUntil { bed.db.calls.filter { $0 == .accountStatus }.count > checks }
        XCTAssertEqual(session.saveAll(), [])
        ledger.draw(on: week, x: 500)
        ledger.deliver()
        session.remoteUpdated(bed.page(week, ["c"]))
        await bed.sessionSleeper.advance()
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertTrue(session.isClosed)
        XCTAssertEqual(session.page(week)?.liveStrokeCount, 0)
        bed.db.resume()
        await answer.value
        await bed.flushDebounce()
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertNil(bed.db.records[week])
        XCTAssertEqual(faults, [])
    }

    /// H3 on the joined path: 「全て消す」 hands every page to the canvas's history prune and the screen opens a new session
    /// (a new identity, so a new canvas with no ↶); 「消して始める」 closes the session.
    func testUndoIsEmptyAfterEraseAllAndEraseAndStartOnTheJoinedPath() async throws {
        let session = try await openSyncedWindow(["a"])
        session.cancelAll()
        XCTAssertEqual(session.takeHistoryPrune(), Set(session.pageIds))
        let next = bed.session(.week, focus: nov16, number: 2)
        XCTAssertNotEqual(next.id, session.id)
        next.closeWithoutSaving()
        XCTAssertTrue(next.isClosed)
        XCTAssertEqual(next.saveAll(), [])
        let third = bed.session(.week, focus: nov16, number: 3)
        XCTAssertNotEqual(third.id, next.id)
        XCTAssertEqual(faults, [])
    }
}
