import InkModel
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §7, §10.2 row Y; M4_CONTRACT §8.2, 54–59): the sync engine's two hooks for the
/// joined pages. `pagesOpened(_:)` fetches the pages of a window with one `fetchRecords`, behind the same gate
/// as `pageOpened` (the account check, the cooldown, the epoch, the counted queue); `onRemoteDelete` follows
/// `onRemoteUpdate(empty)` for a record deleted in iCloud; the inert engine ignores both.
///
/// A live engine over a temporary `InkPageStore` and `InMemoryCloudDatabase`, `TestSleeper` for every sleep
/// (no real sleep anywhere: work paused in the fake is awaited by yielding, as all of it runs on the main
/// actor), a fixed clock. SyncEngineTests.swift stays as in 1.2.3 (§6.4); the helpers below copy its own.
/// TestSleeper's cautions (docs/R1_2_3.md §4.3) hold: `advance()` is called from one task at a time, and
/// never while the fake has an operation paused.
@MainActor
final class SyncEngineSpanTests: XCTestCase {
    private var directory: URL!
    private var store: InkPageStore!
    private var stateStore: SyncStateStore!
    private var db: InMemoryCloudDatabase!
    private var sleeper: TestSleeper!
    private var engine: SyncEngine!
    private var now = Date(timeIntervalSince1970: 1_760_150_500)
    private var remoteUpdates: [InkPage] = []
    /// Both hooks, in the order they were called: "update <page id> <live strokes>", "delete <page id>".
    private var events: [String] = []

    /// A window of five Monday weeks (pagesOpened's pages), and a month page.
    private let weekA = "w-2026-10-05"
    private let weekB = "w-2026-10-12"
    private let weekC = "w-2026-10-19"
    private let weekD = "w-2026-10-26"
    private let weekE = "w-2026-11-02"
    private let month = "m1-2026-10"
    private let subscriptionInfo: [AnyHashable: Any] = ["subscriptionID": "tegaki-zone-changes"]

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncEngineSpanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        stateStore = SyncStateStore(fileURL: store.stateFileURL)
        db = InMemoryCloudDatabase()
        sleeper = TestSleeper()
        now = Date(timeIntervalSince1970: 1_760_150_500)
        remoteUpdates = []
        events = []
        makeEngine()
    }

    override func tearDown() async throws {
        engine?.onRemoteUpdate = nil
        engine?.onRemoteDelete = nil
        engine = nil
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    /// The engine may outlive the test (a task still asleep in the sleeper), so nothing here holds the test
    /// strongly or unowned.
    private func makeEngine() {
        let sleeper = self.sleeper!
        engine = SyncEngine(
            store: store,
            stateStore: stateStore,
            database: db,
            clock: { [weak self] in self?.now ?? Date(timeIntervalSince1970: 1_760_150_500) },
            sleep: { await sleeper.sleep($0) }
        )
        engine.onRemoteUpdate = { [weak self] page in
            self?.remoteUpdates.append(page)
            self?.events.append("update \(page.pageId) \(page.liveStrokeCount)")
        }
        engine.onRemoteDelete = { [weak self] pageId in
            self?.events.append("delete \(pageId)")
        }
        // docs/R1_2_3.md §4: two or more sleeps woken by one advance() settle in between.
        let made: SyncEngine = engine
        sleeper.settle = { [weak made] in await made?.waitUntilIdle() }
    }

    private var status: SyncStatus { engine.snapshot.status }

    private func stroke(_ id: String, t: Int = 1_760_000_001_000) -> InkStroke {
        let points = (0..<3).map { i in
            InkPoint(x: CGFloat(10 + i * 5), y: CGFloat(20 + i), dtMs: i * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: .grid, tool: .pen, color: "#1f2937", t: t, points: points)
    }

    private func page(_ id: String, _ strokeIds: [String]) -> InkPage {
        var page = InkPage.empty(pageId: id)
        for (index, strokeId) in strokeIds.enumerated() {
            page.add(stroke(strokeId, t: 1_760_000_001_000 + index))
        }
        return page
    }

    /// A record as another device would send it (never saved: no change tag).
    private func record(_ page: InkPage) throws -> CloudRecord {
        try InkPageRecord.make(page, seen: nil)
    }

    private func count(_ op: InMemoryCloudDatabase.Operation) -> Int {
        db.calls.filter { $0 == op }.count
    }

    private func live(_ pageId: String) -> Set<String> {
        Set(store.load(pageId).liveStrokeIds)
    }

    private func startSynced() async {
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
    }

    /// Lets the 1.5 s debounce pass and the push finish.
    private func flushDebounce() async {
        await engine.waitUntilIdle()
        await sleeper.advance()
        await engine.waitUntilIdle()
    }

    /// Yields until `condition` holds: for work paused inside the fake, which `waitUntilIdle` would wait for.
    /// The engine, the fake and this test all run on the main actor, so yielding lets the engine's tasks run
    /// (no real sleep).
    private func yieldUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("the condition did not hold after 10,000 yields", file: file, line: line)
    }

    /// Set by a task once `waitUntilIdle` returned (a class, so the task's closure does not mutate a captured var).
    @MainActor
    private final class Flag {
        var value = false
    }

    // MARK: - 54: the account check

    /// 54 (G2 kept): no fetch while an account check is due, neither when `pagesOpened` is called (the launch's
    /// check failed) nor when its work runs (queued behind a check that then finds another account). The call
    /// refused while the check was due starts no cooldown: once the check confirmed the account, the same pages
    /// are fetched at once.
    ///
    /// Fails without the gate at the call: the refused call would start the cooldown (its queued work stopped
    /// by the gate when it runs), so the call after the check fetches nothing (`fetchRecords` 0, not 1, and the
    /// pages stay empty). Fails without the gate when it runs: the work queued before the mismatch was found
    /// would ask for and merge what the other account's iCloud holds (`fetchRecords` 2, a stroke "b" on the page).
    func testPagesOpenedWaitsForTheAccountCheck() async throws {
        // When called: the launch's check failed (no account confirmed yet; the retry is asleep).
        db.failNext[.accountStatus] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(db.calls, [.accountStatus])
        XCTAssertEqual(sleeper.recorded, [15])
        engine.pagesOpened([weekA, weekB])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 0)

        await sleeper.advance() // the retry: the check confirms "_user-a", then the round trip
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.account, "_user-a")
        XCTAssertEqual(status, .synced)
        db.simulateRemoteSave(try record(page(weekA, ["a"])))
        db.simulateRemoteSave(try record(page(weekB, ["w"])))
        engine.pagesOpened([weekA, weekB]) // the same instant as the refused call
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(live(weekA), ["a"])
        XCTAssertEqual(live(weekB), ["w"])

        // When it runs: queued while the check of the return from the background is under way (the check has
        // cleared its request, so the call passes), it runs after that check found another account.
        now = now.addingTimeInterval(SyncBackoff.pageFetchCooldown)
        db.simulateRemoteSave(try record(page(weekA, ["a", "b"])))
        db.userName = "_user-b"
        db.pause(.accountStatus)
        let checks = count(.accountStatus)
        engine.applicationDidEnterBackground()
        engine.applicationDidBecomeActive()
        await yieldUntil { self.count(.accountStatus) == checks + 1 }
        XCTAssertEqual(status, .synced)
        engine.pagesOpened([weekA])
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.pendingAccount, "_user-b")
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(live(weekA), ["a"])

        // And at the call while the mismatch stands.
        engine.pagesOpened([weekC])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(remoteUpdates.map(\.pageId), [weekA, weekB])
    }

    // MARK: - 55: the cooldown and the epoch

    /// 55: the 30 s cooldown is per page and shared with `pageOpened` (a page fetched by one is not fetched by
    /// the other within 30 s; the pages that are due are fetched alone), and the epoch is taken before the
    /// request and checked after it (the return from the background during the request leaves its answer
    /// unmerged; the round trip it queued checks the account first).
    ///
    /// Fails without the cooldown: the second and third calls would fetch week A again (`fetchRecords` 2 and 3
    /// too early, and its stroke "b" merged before the 30 s). Fails without the epoch check, or with the epoch
    /// read after the request: the answer that came back after the epoch moved would be merged (week B with "x").
    func testPagesOpenedHonorsTheCooldownAndEpoch() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(weekA, ["a"])))
        db.simulateRemoteSave(try record(page(weekB, ["w"])))
        engine.pagesOpened([weekA, weekB])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(live(weekA), ["a"])

        // 10 s later: neither page again, through either call.
        db.simulateRemoteSave(try record(page(weekA, ["a", "b"])))
        now = now.addingTimeInterval(10)
        engine.pagesOpened([weekA, weekB])
        engine.pageOpened(weekA)
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(live(weekA), ["a"])

        // A page that is due is fetched alone (weeks A and B are not asked for: A's stroke "b" does not come).
        db.simulateRemoteSave(try record(page(weekC, ["c"])))
        engine.pagesOpened([weekA, weekC, weekB])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 2)
        XCTAssertEqual(live(weekC), ["c"])
        XCTAssertEqual(live(weekA), ["a"])

        // 30 s after the first fetch: weeks A and B are due again, week C (20 s) is not.
        db.simulateRemoteSave(try record(page(weekC, ["c", "d"])))
        now = now.addingTimeInterval(20)
        engine.pagesOpened([weekA, weekC, weekB])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 3)
        XCTAssertEqual(live(weekA), ["a", "b"])
        XCTAssertEqual(live(weekC), ["c"])

        // The epoch: the request is under way when the app comes back from the background (the epoch moves).
        now = now.addingTimeInterval(SyncBackoff.pageFetchCooldown)
        db.simulateRemoteSave(try record(page(weekB, ["w", "x"])))
        db.pause(.fetchRecords)
        engine.pagesOpened([weekB])
        await yieldUntil { self.count(.fetchRecords) == 4 }
        engine.applicationDidEnterBackground()
        engine.applicationDidBecomeActive() // its round trip waits in the queue behind the request
        db.failNext[.fetchChanges] = .networkUnavailable // so that its pull does not bring week B either
        let mark = db.calls.count
        remoteUpdates = []
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(live(weekB), ["w"])
        XCTAssertEqual(remoteUpdates.map(\.pageId), [])
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName, .fetchChanges])
        XCTAssertEqual(count(.fetchRecords), 4) // the one whose answer was dropped
        XCTAssertEqual(status, .offline)
    }

    // MARK: - 56: one request, each record merged

    /// 56: one `fetchRecords` for every page of the window; each record goes through `mergeRemote` in the
    /// order of the pages: a new page is written, another device's stroke is merged, a record whose change tag
    /// this device has seen is skipped, a page without a record is simply absent (no file, no failure), and a
    /// page with strokes only on this device is merged and queued for the next push. An empty list does nothing.
    ///
    /// Fails if the pages were fetched one by one (`fetchRecords` 5, not 1) or if a record were not merged (the
    /// pages' strokes, `seen`, the dirty mark, the state file). A merge in the order of the fetched dictionary
    /// instead of the pages fails `onRemoteUpdate`'s order here (and in 54) whenever the dictionary's order
    /// differs, which Swift's hash seed (new in every process) makes likely, not certain.
    func testPagesOpenedFetchesOnceAndMergesEach() async throws {
        await startSynced()
        engine.pagesOpened([])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 0)

        try engine.save(page(weekB, ["b1"]))
        await flushDebounce()
        try engine.save(page(weekC, ["c"]))
        await flushDebounce()
        XCTAssertEqual(engine.state.dirty, [])
        db.simulateRemoteSave(try record(page(weekA, ["a"]))) // new to this device
        db.simulateRemoteSave(try record(page(weekB, ["b1", "b2"]))) // another device added "b2"
        // weekC: the server holds the version this device sent; weekD: no record anywhere.
        try store.save(page(weekE, ["e1"])) // a stroke only on this device…
        db.simulateRemoteSave(try record(page(weekE, ["e2"]))) // …and another only in iCloud
        remoteUpdates = []

        engine.pagesOpened([weekA, weekB, weekC, weekD, weekE])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(remoteUpdates.map(\.pageId), [weekA, weekB, weekE])
        XCTAssertEqual(live(weekA), ["a"])
        XCTAssertEqual(live(weekB), ["b1", "b2"])
        XCTAssertEqual(live(weekC), ["c"])
        XCTAssertFalse(store.exists(weekD))
        XCTAssertEqual(live(weekE), ["e1", "e2"])
        for pageId in [weekA, weekB, weekC, weekE] {
            XCTAssertEqual(engine.state.seen[pageId]?.changeTag, db.records[pageId]?.changeTag, pageId)
            XCTAssertNotNil(engine.state.seen[pageId], pageId)
        }
        XCTAssertNil(engine.state.seen[weekD])
        XCTAssertEqual(engine.state.dirty, [weekE])
        let saved = stateStore.load()
        XCTAssertEqual(saved.dirty, [weekE])
        XCTAssertEqual(saved.seen[weekA]?.changeTag, db.records[weekA]?.changeTag)

        // The page with this device's stroke goes with the next push.
        await engine.syncNow()
        let sent = try InkPageRecord.page(from: XCTUnwrap(db.records[weekE]))
        XCTAssertEqual(Set(sent.liveStrokeIds), ["e1", "e2"])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
    }

    // MARK: - 57: waitUntilIdle

    /// 57: the work of `pagesOpened` is counted (`enqueue`): `waitUntilIdle` right after the call returns only
    /// once the records are merged, and while the request is suspended in the fake it does not return.
    ///
    /// Fails if the work ran in a bare `Task`: `waitUntilIdle` would return at once (no counted job), before the
    /// pages are merged, and the waiter would be done while the request is still suspended.
    func testPagesOpenedIsCountedByWaitUntilIdle() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(weekA, ["a"])))
        db.simulateRemoteSave(try record(page(weekB, ["w"])))
        engine.pagesOpened([weekA, weekB])
        await engine.waitUntilIdle()
        XCTAssertEqual(live(weekA), ["a"])
        XCTAssertEqual(live(weekB), ["w"])

        now = now.addingTimeInterval(SyncBackoff.pageFetchCooldown)
        db.simulateRemoteSave(try record(page(weekA, ["a", "b"])))
        db.pause(.fetchRecords)
        engine.pagesOpened([weekA])
        await yieldUntil { self.count(.fetchRecords) == 2 }
        let idle = Flag()
        let engine: SyncEngine = self.engine
        let waiter = Task { @MainActor in
            await engine.waitUntilIdle()
            idle.value = true
        }
        for _ in 0..<200 { await Task.yield() }
        XCTAssertFalse(idle.value, "waitUntilIdle returned while the request was suspended")
        XCTAssertEqual(live(weekA), ["a"])
        db.resume()
        await waiter.value
        XCTAssertTrue(idle.value)
        XCTAssertEqual(live(weekA), ["a", "b"])
        XCTAssertEqual(count(.fetchRecords), 2)
    }

    // MARK: - 58: the deletion of a record

    /// 58: a record deleted in iCloud (another device's 「全て消す」) calls `onRemoteUpdate` with the empty page and
    /// then `onRemoteDelete` with its id, page by page in the order of the deletions: a page this device has
    /// and a page it never had alike. The `Meta` record's deletion calls neither. The file, `seen` and the
    /// dirty mark go as in 1.2.3 (`test11DeletedNamesRemoveTheFile`), and the hooks delete and send nothing
    /// (only `cloudErase` deletes).
    ///
    /// Fails without the call (no "delete" events), with the call before `onRemoteUpdate` (the order), or with
    /// the call before the `Meta` record is skipped (a "delete meta" event).
    func testRemoteDeleteCallsBothHooksInOrder() async throws {
        await startSynced()
        try engine.save(page(month, ["m"]))
        await flushDebounce()
        db.simulateRemoteSave(try record(page(weekA, ["a"])))
        db.simulateRemoteSave(InkPageRecord.makeMeta(webImportedAt: nil, trialStartedAt: Date(timeIntervalSince1970: 1_760_000_000), seen: nil))
        await engine.syncNow()
        XCTAssertTrue(store.exists(month))
        XCTAssertTrue(store.exists(weekA))
        XCTAssertNotNil(engine.state.seen["meta"])

        db.simulateRemoteDelete(month)
        db.simulateRemoteDelete(weekA)
        db.simulateRemoteDelete("meta")
        db.simulateRemoteSave(try record(page(weekB, ["w"]))) // never on this device
        db.simulateRemoteDelete(weekB)
        events = []
        let saves = count(.save)
        await engine.syncNow()
        XCTAssertEqual(events, [
            "update \(month) 0", "delete \(month)",
            "update \(weekA) 0", "delete \(weekA)",
            "update \(weekB) 0", "delete \(weekB)",
        ])
        XCTAssertFalse(store.exists(month))
        XCTAssertFalse(store.exists(weekA))
        XCTAssertFalse(store.exists(weekB))
        XCTAssertNil(engine.state.seen[month])
        XCTAssertNil(engine.state.seen[weekA])
        XCTAssertNil(engine.state.seen["meta"])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(count(.save), saves)
        XCTAssertEqual(count(.delete), 0)
        XCTAssertEqual(status, .synced)
    }

    // MARK: - 59: the inert engine

    /// 59: the inert engine (the screenshot mode's and the XCTest host's, SyncEngine.swift:19-30) ignores both:
    /// `pagesOpened` reaches no database and merges nothing, and a record deleted in its fake calls neither hook
    /// (it never pulls). `SyncEngine.shared` in this host is that engine.
    ///
    /// Fails if `pagesOpened` reached the database without its gates (the fake's calls), or if a hook were
    /// called from a path the inert engine runs (`start`, `pageOpened`, `syncNow`, the silent push). Removing
    /// only `!inactive` from `pagesOpened` is still caught by `started` (the inert engine never starts).
    func testInactiveEngineIgnoresBothHooks() async throws {
        let demo = SyncEngine.screenshotDemo(now: now)
        let fake = try XCTUnwrap(demo.database as? InMemoryCloudDatabase)
        var demoEvents: [String] = []
        demo.onRemoteUpdate = { demoEvents.append("update \($0.pageId)") }
        demo.onRemoteDelete = { demoEvents.append("delete \($0)") }
        fake.simulateRemoteSave(try record(page(weekA, ["a"])))
        demo.start()
        demo.pagesOpened([weekA, weekB])
        demo.pageOpened(weekA)
        await demo.syncNow()
        fake.simulateRemoteDelete(weekA)
        await demo.syncNow()
        let brought = await demo.handleRemoteNotification(subscriptionInfo)
        XCTAssertFalse(brought)
        await demo.waitUntilIdle()
        XCTAssertEqual(fake.calls, [])
        XCTAssertEqual(demoEvents, [])
        XCTAssertEqual(demo.snapshot, SyncSnapshot(status: .synced, lastSyncAt: now.addingTimeInterval(-SyncEngine.demoLastSyncOffset), dirtyCount: 0, webImportedAt: nil))
        XCTAssertEqual(demo.state, .empty)
        XCTAssertEqual(demo.load(weekA).liveStrokeCount, 0)

        let shared = SyncEngine.shared
        let sharedFake = try XCTUnwrap(shared.database as? InMemoryCloudDatabase)
        let callsBefore = sharedFake.calls
        let stateBefore = shared.state
        let snapshotBefore = shared.snapshot
        shared.pagesOpened([weekA, weekB, weekC])
        await shared.waitUntilIdle()
        XCTAssertEqual(sharedFake.calls, callsBefore)
        XCTAssertEqual(shared.state, stateBefore)
        XCTAssertEqual(shared.snapshot, snapshotBefore)
    }
}
