import Combine
import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// The sync engine over the fake iCloud (M4_CONTRACT §8.2, 0–36 and 1.2.3's 37–50): the account check, the
/// debounce, conflicts, pulls, deletions, the retry backoff, the zone loss, the silent push, the account
/// switch, the erase, the web import, and (1.2.3) the account confirmed again after a failed check, an
/// account change, the background and a silent push. `TestSleeper` stands in for the clock's sleeps, the
/// clock is fixed, and the page files live in a temporary directory. No iCloud account anywhere.
@MainActor
final class SyncEngineTests: XCTestCase {
    private var directory: URL!
    private var store: InkPageStore!
    private var stateStore: SyncStateStore!
    private var db: InMemoryCloudDatabase!
    private var sleeper: TestSleeper!
    private var engine: SyncEngine!
    private var now = Date(timeIntervalSince1970: 1_760_150_500)
    private var remoteUpdates: [InkPage] = []
    /// The status after every change of `snapshot.status` (consecutive repeats dropped).
    private var statuses: [SyncStatus] = []
    private var subscription: AnyCancellable?

    private let month = "m1-2026-10"
    private let week = "w-2026-10-05"
    private let subscriptionInfo: [AnyHashable: Any] = ["subscriptionID": "tegaki-zone-changes"]

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncEngineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        stateStore = SyncStateStore(fileURL: store.stateFileURL)
        db = InMemoryCloudDatabase()
        sleeper = TestSleeper()
        now = Date(timeIntervalSince1970: 1_760_150_500)
        remoteUpdates = []
        statuses = []
        makeEngine()
    }

    override func tearDown() async throws {
        subscription = nil
        engine?.onRemoteUpdate = nil
        engine = nil
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    /// The engine may outlive the test (a task still asleep in the sleeper), so nothing here holds
    /// the test strongly or unowned.
    private func makeEngine() {
        let sleeper = self.sleeper!
        engine = SyncEngine(
            store: store,
            stateStore: stateStore,
            database: db,
            clock: { [weak self] in self?.now ?? Date(timeIntervalSince1970: 1_760_150_500) },
            sleep: { await sleeper.sleep($0) }
        )
        engine.onRemoteUpdate = { [weak self] page in self?.remoteUpdates.append(page) }
        // 1.2.3 (docs/R1_2_3.md §4): two or more sleeps woken by one advance() settle in between.
        let made: SyncEngine = engine
        sleeper.settle = { [weak made] in await made?.waitUntilIdle() }
        subscription = engine.$snapshot.sink { [weak self] snapshot in
            guard let self = self else { return }
            if self.statuses.last != snapshot.status { self.statuses.append(snapshot.status) }
        }
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

    private func storedPage(_ name: String) throws -> InkPage {
        try InkPageRecord.page(from: XCTUnwrap(db.records[name], "record \(name)"))
    }

    private func count(_ op: InMemoryCloudDatabase.Operation) -> Int {
        db.calls.filter { $0 == op }.count
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

    /// Yields until `condition` holds (for work that is paused inside the fake, which `waitUntilIdle`
    /// would wait for forever).
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<4000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("timed out", file: file, line: line)
    }

    // MARK: - 0: the test host

    func test00TestHostUsesTheFake() {
        XCTAssertTrue(SyncEngine.isTestHost)
        XCTAssertFalse(SyncEngine.usesCloudKit)
        XCTAssertTrue(SyncEngine.shared.database is InMemoryCloudDatabase)
        XCTAssertEqual(SyncEngine.shared.snapshot.status, .synced)
    }

    // MARK: - 1, 2: start

    func test01StartWithoutAccount() async throws {
        db.status = .noAccount
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .localOnly(.noAccount))
        XCTAssertEqual(db.calls, [.accountStatus])
        XCTAssertNil(engine.state.account)

        try engine.save(page(month, ["a"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertEqual(engine.snapshot.dirtyCount, 1)
        XCTAssertEqual(db.calls, [.accountStatus])
        XCTAssertEqual(sleeper.recorded, [])
        XCTAssertEqual(stateStore.load().dirty, [month])
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a"])
        XCTAssertEqual(status.header.text, "この端末のみ")
    }

    func test02StartWithAccount() async throws {
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.account, "_user-a")
        XCTAssertNil(engine.state.pendingAccount)
        XCTAssertEqual(db.calls, [.accountStatus, .userRecordName, .ensureZone, .ensureSubscription, .fetchChanges])
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.snapshot.lastSyncAt, now)
        XCTAssertTrue(engine.state.zoneReady)
        XCTAssertTrue(engine.state.subscriptionReady)
        XCTAssertNotNil(engine.state.zoneToken)
        XCTAssertEqual(db.subscriptionIDs, ["tegaki-zone-changes"])
        let saved = stateStore.load()
        XCTAssertEqual(saved.account, "_user-a")
        XCTAssertEqual(saved.lastSyncAt, InkPageRecord.ms(from: now))
        XCTAssertEqual(statuses, [.pending, .syncing, .synced])
    }

    // MARK: - 3–5: save, debounce, push

    func test03SaveDebouncePush() async throws {
        await startSynced()
        statuses = []
        try engine.save(page(month, ["a"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .pending)
        XCTAssertEqual(sleeper.recorded, [1.5])
        XCTAssertEqual(count(.save), 0)
        XCTAssertEqual(engine.snapshot.dirtyCount, 1)

        await sleeper.advance()
        await engine.waitUntilIdle()
        let stored = try XCTUnwrap(db.records[month])
        guard case .asset? = stored.fields["doc"] else { return XCTFail("doc is an asset") }
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
        XCTAssertEqual(engine.state.seen[month]?.changeTag, stored.changeTag)
        XCTAssertEqual(engine.state.seen[month]?.systemFields, stored.systemFields)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(engine.snapshot.dirtyCount, 0)
        XCTAssertEqual(statuses, [.pending, .syncing, .synced])
        XCTAssertEqual(stateStore.load().seen[month]?.changeTag, stored.changeTag)
    }

    func test04ConsecutiveSavesAreOnePush() async throws {
        await startSynced()
        for i in 0..<5 {
            try engine.save(page(month, ["a\(i)"]))
        }
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.recorded, [1.5])
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.recorded, [1.5, 1.5])
        XCTAssertEqual(count(.save), 0)
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 1)
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a0", "a1", "a2", "a3", "a4"])
        XCTAssertEqual(status, .synced)
    }

    func test05SaveWhileSending() async throws {
        await startSynced()
        db.pause(.save)
        try engine.save(page(month, ["v1"]))
        await engine.waitUntilIdle()
        await sleeper.advance()
        await waitUntil { self.db.calls.contains(.save) }
        XCTAssertEqual(status, .syncing)
        try engine.save(page(month, ["v2"]))
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 2)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["v1", "v2"])
    }

    // MARK: - 6, 7: conflicts

    func test06ConflictMergesAndSavesAgain() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        db.simulateRemoteSave(try record(page(month, ["a", "c"])))
        remoteUpdates = []

        try engine.save(page(month, ["a", "d"]))
        await flushDebounce()
        XCTAssertEqual(count(.save), 3)
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a", "c", "d"])
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a", "c", "d"])
        XCTAssertEqual(remoteUpdates.map { $0.pageId }, [month])
        XCTAssertEqual(remoteUpdates.first?.liveStrokeIds, ["a", "c", "d"])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(engine.state.seen[month]?.changeTag, db.records[month]?.changeTag)
        XCTAssertEqual(status, .synced)
    }

    func test07FourConflictsGiveUpUntilTheRetry() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        let server = db.simulateRemoteSave(try record(page(month, ["a", "c"])))
        db.alwaysFail = .serverRecordChanged(server: server)

        try engine.save(page(month, ["a", "d"]))
        await flushDebounce()
        XCTAssertEqual(count(.save), 1 + 4)
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertEqual(status, .pending)
        XCTAssertEqual(sleeper.recorded.last, 15)
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a", "c", "d"])

        db.alwaysFail = nil
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a", "c", "d"])
    }

    // MARK: - 8–12: pull

    func test08PullBringsTheOtherDevicesStrokes() async throws {
        await startSynced()
        let before = engine.state.zoneToken
        db.simulateRemoteSave(try record(page(week, ["b"])))
        await engine.syncNow()
        XCTAssertEqual(store.load(week).liveStrokeIds, ["b"])
        XCTAssertEqual(remoteUpdates.map { $0.pageId }, [week])
        XCTAssertEqual(engine.state.seen[week]?.changeTag, db.records[week]?.changeTag)
        XCTAssertNotEqual(engine.state.zoneToken, before)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(count(.save), 0)
    }

    func test09OwnRecordsAreSkippedByThePull() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        remoteUpdates = []
        await engine.syncNow()
        XCTAssertTrue(remoteUpdates.isEmpty)
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a"])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(count(.save), 1)
    }

    func test10LocalOnlyStrokesAreQueued() async throws {
        await startSynced()
        // A file the ledger does not know, and a newer record on the server.
        try store.save(page(month, ["a"]))
        db.simulateRemoteSave(try record(page(month, ["b"])))
        await engine.syncNow()
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a", "b"])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a", "b"])
        XCTAssertEqual(engine.state.dirty, [])
        let fetch = try XCTUnwrap(db.calls.lastIndex(of: .fetchChanges))
        let save = try XCTUnwrap(db.calls.lastIndex(of: .save))
        XCTAssertLessThan(fetch, save)

        // The same through pageOpened: queued, sent by the next push.
        try store.save(page(week, ["c"]))
        db.simulateRemoteSave(try record(page(week, ["d"])))
        engine.pageOpened(week)
        await engine.waitUntilIdle()
        XCTAssertEqual(store.load(week).liveStrokeIds, ["c", "d"])
        XCTAssertEqual(engine.state.dirty, [week])
        XCTAssertNil(db.records[week].flatMap { try? InkPageRecord.page(from: $0) }?.strokes["c"])
        await engine.syncNow()
        XCTAssertEqual(try storedPage(week).liveStrokeIds, ["c", "d"])
        XCTAssertEqual(engine.state.dirty, [])
    }

    func test11DeletedNamesRemoveTheFile() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        XCTAssertTrue(store.exists(month))
        db.simulateRemoteDelete(month)
        remoteUpdates = []
        await engine.syncNow()
        XCTAssertFalse(store.exists(month))
        XCTAssertEqual(remoteUpdates.count, 1)
        XCTAssertEqual(remoteUpdates.first?.pageId, month)
        XCTAssertEqual(remoteUpdates.first?.liveStrokeCount, 0)
        XCTAssertNil(engine.state.seen[month])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
    }

    func test12ChangeTokenExpiredFetchesEverythingOnce() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(month, ["b"])))
        db.expireToken()
        let before = count(.fetchChanges)
        await engine.syncNow()
        XCTAssertEqual(count(.fetchChanges) - before, 2)
        XCTAssertEqual(store.load(month).liveStrokeIds, ["b"])
        XCTAssertEqual(status, .synced)
        XCTAssertNotNil(engine.state.zoneToken)
        XCTAssertEqual(engine.state.seen[month]?.changeTag, db.records[month]?.changeTag)
    }

    // MARK: - 13–15: failures and the backoff

    func test13NetworkUnavailableRetriesWithBackoff() async throws {
        await startSynced()
        db.failNext[.save] = .networkUnavailable
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertEqual(sleeper.recorded, [1.5, 15])

        db.failNext[.save] = .networkUnavailable
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.recorded, [1.5, 15, 30])

        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])

        // The backoff was reset by the success.
        db.failNext[.save] = .networkUnavailable
        try engine.save(page(month, ["b"]))
        await flushDebounce()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.recorded.last, 15)
    }

    func test14QuotaExceededDoesNotRetryByItself() async throws {
        await startSynced()
        db.failNext[.save] = .quotaExceeded
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        XCTAssertEqual(status, .error(.quota))
        XCTAssertTrue(status.isError)
        XCTAssertEqual(status.settingsText, "iCloud の容量が足りません")
        XCTAssertEqual(sleeper.recorded, [1.5])
        XCTAssertEqual(engine.state.dirty, [month])

        await engine.syncNow()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(sleeper.recorded, [1.5])
    }

    func test15RetryLaterUsesTheServerHint() async throws {
        await startSynced()
        db.failNext[.save] = .retryLater(after: 120)
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        XCTAssertEqual(status, .pending)
        XCTAssertEqual(sleeper.recorded.last, 120)
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
    }

    // MARK: - 16: the zone is gone

    func test16ZoneLossSendsEverythingAgain() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        try engine.save(page(week, ["b"]))
        await flushDebounce()
        let oldTags = engine.state.seen.mapValues { $0.changeTag }

        db.simulateZoneDeleted()
        let mark = db.calls.count
        await engine.syncNow()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .ensureZone, .ensureSubscription, .fetchChanges, .save, .save])
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(Set(db.records.keys), [month, week])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertTrue(engine.state.zoneReady)
        XCTAssertTrue(engine.state.subscriptionReady)
        XCTAssertNotNil(engine.state.zoneToken)
        XCTAssertEqual(Set(engine.state.seen.keys), [month, week])
        XCTAssertNotEqual(engine.state.seen[month]?.changeTag, oldTags[month])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
        XCTAssertEqual(try storedPage(week).liveStrokeIds, ["b"])
    }

    // MARK: - 17: pageOpened

    func test17PageOpenedFetchesOncePerCooldown() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(month, ["b"])))
        engine.pageOpened(month)
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(store.load(month).liveStrokeIds, ["b"])
        XCTAssertEqual(remoteUpdates.count, 1)

        engine.pageOpened(month)
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)

        now = now.addingTimeInterval(31)
        engine.pageOpened(month)
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 2)
        XCTAssertEqual(remoteUpdates.count, 1) // same tag: nothing

        engine.pageOpened("d-2026-10-07")
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 3)
        XCTAssertFalse(store.exists("d-2026-10-07"))
        XCTAssertEqual(remoteUpdates.count, 1)
        XCTAssertEqual(engine.state.dirty, [])
    }

    // MARK: - 18: the silent push

    func test18RemoteNotification() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(month, ["b"])))
        let brought = await engine.handleRemoteNotification(subscriptionInfo)
        XCTAssertTrue(brought)
        XCTAssertEqual(store.load(month).liveStrokeIds, ["b"])
        XCTAssertEqual(sleeper.recorded, [20])
        await sleeper.advance()
        await engine.waitUntilIdle()

        let mark = db.calls.count
        let foreign = await engine.handleRemoteNotification([:])
        XCTAssertFalse(foreign)
        XCTAssertEqual(db.calls.count, mark)
        XCTAssertEqual(sleeper.recorded, [20])

        let nothingNew = await engine.handleRemoteNotification(subscriptionInfo)
        XCTAssertFalse(nothingNew)
        await sleeper.advance()
        await engine.waitUntilIdle()

        db.pause(.fetchChanges)
        db.simulateRemoteSave(try record(page(week, ["c"])))
        let task = Task { await self.engine.handleRemoteNotification(self.subscriptionInfo) }
        await waitUntil { self.sleeper.recorded.last == 20 && self.sleeper.waiting == 1 }
        await sleeper.advance()
        let timedOut = await task.value
        XCTAssertFalse(timedOut)
        XCTAssertFalse(store.exists(week))
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(store.load(week).liveStrokeIds, ["c"])
        XCTAssertEqual(status, .synced)
    }

    // MARK: - 19–22: accounts

    func test19AnotherAccountStopsTheSync() async throws {
        await startSynced()
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.pendingAccount, "_user-b")
        XCTAssertEqual(engine.state.account, "_user-a")
        XCTAssertEqual(stateStore.load().pendingAccount, "_user-b")
        XCTAssertEqual(status.header.text, "停止中")
        XCTAssertTrue(status.isError)

        let saves = count(.save)
        try engine.save(page(month, ["a"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertEqual(count(.save), saves)
        XCTAssertEqual(sleeper.recorded, [])
        XCTAssertEqual(status, .accountMismatch)
    }

    func test20KeepInkMovesEverythingToTheNewAccount() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        try store.save(page(week, ["b"]))
        let oldTag = engine.state.seen[month]?.changeTag
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)

        let saves = count(.save)
        await engine.resolveAccountChange(.keepInk)
        XCTAssertEqual(engine.state.account, "_user-b")
        XCTAssertNil(engine.state.pendingAccount)
        XCTAssertEqual(status, .synced)
        XCTAssertGreaterThanOrEqual(count(.save) - saves, 2)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(Set(engine.state.seen.keys), [month, week])
        XCTAssertNotEqual(engine.state.seen[month]?.changeTag, oldTag)
        XCTAssertNotNil(engine.state.zoneToken)
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
        XCTAssertEqual(try storedPage(week).liveStrokeIds, ["b"])
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a"])
        XCTAssertEqual(stateStore.load().account, "_user-b")
    }

    func test21EraseInkStartsEmptyWithTheNewAccount() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        // The other account's iCloud: empty but for its own page.
        db.simulateZoneDeleted()
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)
        db.simulateRemoteSave(try record(page(week, ["b"])))

        await engine.resolveAccountChange(.eraseInk)
        XCTAssertEqual(engine.state.account, "_user-b")
        XCTAssertNil(engine.state.pendingAccount)
        XCTAssertEqual(store.allPageIds(), [week])
        XCTAssertEqual(store.load(week).liveStrokeIds, ["b"])
        XCTAssertFalse(store.exists(month))
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(stateStore.load().account, "_user-b")
        XCTAssertNil(db.records[month])
    }

    func test22SignOutAndBackIn() async throws {
        await startSynced()
        db.simulateAccountChange(status: .noAccount, userName: "_user-a")
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .localOnly(.noAccount))
        XCTAssertEqual(engine.state.account, "_user-a")

        try engine.save(page(month, ["a"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertEqual(sleeper.recorded, [])

        db.simulateAccountChange(status: .available, userName: "_user-a")
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.account, "_user-a")
        XCTAssertNil(engine.state.pendingAccount)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
    }

    // MARK: - 23, 24, 29: erase everything

    func test23EraseEverything() async throws {
        await startSynced()
        for i in 0..<202 {
            db.simulateRemoteSave(try record(page("d-2026-01-\(String(format: "%03d", i))", ["s"])))
        }
        let trial = Date(timeIntervalSince1970: 1_760_000_000)
        db.simulateRemoteSave(InkPageRecord.makeMeta(webImportedAt: nil, trialStartedAt: trial, seen: nil))
        await engine.syncNow()
        XCTAssertEqual(store.allPageIds().count, 202)
        // One name the other device deleted already: still in `seen`, gone from the server.
        db.simulateRemoteDelete("d-2026-01-000")
        XCTAssertNotNil(engine.state.seen["d-2026-01-000"])

        let mark = db.calls.count
        let flags = db.fetchChangesNamesOnly.count
        try await engine.eraseEverything()
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertEqual(db.records.keys.filter { $0 != "meta" }, [])
        XCTAssertNotNil(db.records["meta"])
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .delete, .delete, .fetchChanges])
        XCTAssertEqual(Array(db.fetchChangesNamesOnly[flags...]), [true, true])
        XCTAssertEqual(db.deletedNames.count, 201)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(engine.state.seen, [:])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertNotNil(engine.state.zoneToken)
        XCTAssertEqual(engine.state.account, "_user-a")
        XCTAssertTrue(engine.state.zoneReady)
        XCTAssertNil(engine.state.webImportedAt)
        XCTAssertEqual(status, .synced)
        XCTAssertFalse(stateStore.load().pendingCloudErase)

        // Nothing comes back with the next pull.
        await engine.syncNow()
        XCTAssertEqual(store.allPageIds(), [])
    }

    func test24EraseInterruptedByTheNetwork() async throws {
        await startSynced()
        for i in 0..<3 {
            db.simulateRemoteSave(try record(page("d-2026-01-0\(i)", ["s"])))
        }
        await engine.syncNow()
        XCTAssertEqual(store.allPageIds().count, 3)

        db.failNext[.delete] = .networkUnavailable
        do {
            try await engine.eraseEverything()
            XCTFail("the erase should throw")
        } catch {
            XCTAssertEqual(error as? CloudError, .networkUnavailable)
        }
        XCTAssertTrue(engine.state.pendingCloudErase)
        XCTAssertTrue(stateStore.load().pendingCloudErase)
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(db.records.count, 3)

        let mark = db.calls.count
        let flags = db.fetchChangesNamesOnly.count
        await engine.syncNow()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .delete, .fetchChanges, .fetchChanges])
        XCTAssertEqual(Array(db.fetchChangesNamesOnly[flags...]), [true, true, false])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertTrue(db.records.isEmpty)
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertEqual(status, .synced)
    }

    func testEraseWhenTheZoneIsGoneHasNothingToDelete() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        db.simulateZoneDeleted()

        try await engine.eraseEverything()
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertFalse(engine.state.zoneReady)
        XCTAssertEqual(engine.state.seen, [:])
        XCTAssertEqual(sleeper.recorded, [1.5]) // no backoff retry was scheduled

        // The next round trip makes the zone again instead of failing on the erase.
        let mark = db.calls.count
        await engine.syncNow()
        XCTAssertEqual(Array(db.calls[mark...]), [.ensureZone, .ensureSubscription, .fetchChanges])
        XCTAssertEqual(status, .synced)
        XCTAssertTrue(db.records.isEmpty)
    }

    func test29PendingEraseRunsBeforeThePull() async throws {
        var pending = SyncState.empty
        pending.account = "_user-a"
        pending.pendingCloudErase = true
        pending.zoneReady = true
        pending.subscriptionReady = true
        try stateStore.save(pending)
        try await db.ensureZone()
        db.simulateRemoteSave(try record(page(month, ["a"])))

        let mark = db.calls.count
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName, .fetchChanges, .delete, .fetchChanges, .fetchChanges])
        XCTAssertEqual(db.fetchChangesNamesOnly, [true, true, false])
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertTrue(db.records.isEmpty)
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .synced)
    }

    // MARK: - 25, 26, 30: the web import

    func test25ImportPages() async throws {
        await startSynced()
        let pages = [page(month, ["a", "b"]), page(week, ["c"])]
        var progress: [Int] = []
        var totals: [Int] = []
        let outcome = try await engine.importPages(pages) { done, total in
            progress.append(done)
            totals.append(total)
        }
        XCTAssertEqual(outcome, ImportOutcome(pagesChanged: 2, strokesAdded: 3, pagesSeen: 2))
        XCTAssertEqual(progress, [1, 2])
        XCTAssertEqual(totals, [2, 2])
        XCTAssertEqual(engine.state.dirty, [month, week])
        XCTAssertEqual(engine.snapshot.webImportedAt, now)
        XCTAssertEqual(stateStore.load().webImportedAt, InkPageRecord.ms(from: now))
        let meta = try XCTUnwrap(db.records["meta"])
        XCTAssertEqual(InkPageRecord.metaValues(from: meta).webImportedAt, now)
        XCTAssertEqual(meta.fields["schema"], .int(1))
        XCTAssertEqual(store.load(month).liveStrokeIds, ["a", "b"])

        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a", "b"])
        XCTAssertEqual(try storedPage(week).liveStrokeIds, ["c"])
        XCTAssertEqual(sleeper.recorded, []) // no debounce
        XCTAssertEqual(status, .synced)

        let again = try await engine.importPages(pages) { _, _ in }
        XCTAssertEqual(again, ImportOutcome(pagesChanged: 0, strokesAdded: 0, pagesSeen: 2))
        XCTAssertEqual(engine.state.dirty, [])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 2 + 1 + 1) // two pages, Meta twice
    }

    func test26ImportUpdatesTheOpenPage() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        remoteUpdates = []
        let outcome = try await engine.importPages([page(month, ["b"])]) { _, _ in }
        XCTAssertEqual(outcome, ImportOutcome(pagesChanged: 1, strokesAdded: 1, pagesSeen: 1))
        XCTAssertEqual(remoteUpdates.count, 1)
        XCTAssertEqual(remoteUpdates.first?.pageId, month)
        XCTAssertEqual(remoteUpdates.first?.liveStrokeIds, ["a", "b"])
        await engine.waitUntilIdle()
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a", "b"])
    }

    func test30MetaConflictKeepsTheServersTrialDate() async throws {
        await startSynced()
        let trial = Date(timeIntervalSince1970: 1_760_000_000)
        db.simulateRemoteSave(InkPageRecord.makeMeta(webImportedAt: nil, trialStartedAt: trial, seen: nil))
        _ = try await engine.importPages([page(month, ["a"])]) { _, _ in }
        let meta = try XCTUnwrap(db.records["meta"])
        let values = InkPageRecord.metaValues(from: meta)
        XCTAssertEqual(values.trialStartedAt, trial)
        XCTAssertEqual(values.webImportedAt, now)
        XCTAssertEqual(engine.state.seen["meta"]?.changeTag, meta.changeTag)

        // A later import with the Meta known: the server's newer import date wins over the clock.
        await engine.waitUntilIdle()
        let later = now.addingTimeInterval(600)
        var newer = meta
        newer.fields["webImportedAt"] = .date(later)
        db.simulateRemoteSave(newer)
        _ = try await engine.importPages([page(week, ["b"])]) { _, _ in }
        let merged = try XCTUnwrap(db.records["meta"])
        XCTAssertEqual(InkPageRecord.metaValues(from: merged).webImportedAt, later)
        XCTAssertEqual(InkPageRecord.metaValues(from: merged).trialStartedAt, trial)
    }

    // MARK: - 27, 28, 31–36

    func test27ScreenshotDemoIsInert() async throws {
        let demo = SyncEngine.screenshotDemo(now: now)
        XCTAssertEqual(demo.snapshot, SyncSnapshot(status: .synced, lastSyncAt: now.addingTimeInterval(-180), dirtyCount: 0, webImportedAt: nil))
        let fake = try XCTUnwrap(demo.database as? InMemoryCloudDatabase)
        demo.start()
        try demo.save(page(month, ["a"]))
        demo.pageOpened(month)
        await demo.syncNow()
        let brought = await demo.handleRemoteNotification(subscriptionInfo)
        XCTAssertFalse(brought)
        try await demo.eraseEverything()
        await demo.waitUntilIdle()
        XCTAssertEqual(fake.calls, [])
        XCTAssertEqual(demo.snapshot.status, .synced)
        XCTAssertEqual(demo.snapshot.lastSyncAt, now.addingTimeInterval(-180))
        XCTAssertEqual(demo.load(month).liveStrokeCount, 0)
        XCTAssertEqual(demo.state, .empty)
    }

    func test28SaveBeforeStartIsSentByStart() async throws {
        try engine.save(page(month, ["a"]))
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateStore.fileURL.path))
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
        XCTAssertEqual(count(.save), 1)
        await sleeper.advance() // the debounce of the early save: nothing left to send
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 1)
    }

    func test31RecordErasedElsewhereIsMadeAgain() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        XCTAssertNotNil(engine.state.seen[month])
        db.simulateRemoteDelete(month)

        let saves = count(.save)
        try engine.save(page(month, ["b"]))
        await flushDebounce()
        XCTAssertEqual(count(.save) - saves, 2)
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a", "b"])
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(engine.state.seen[month]?.changeTag, db.records[month]?.changeTag)
    }

    func test32FirstStartOffline() async throws {
        db.failNext[.userRecordName] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertNil(engine.state.account)
        XCTAssertEqual(count(.fetchChanges), 0)
        XCTAssertEqual(count(.save), 0)
        XCTAssertEqual(sleeper.recorded, [15])

        try engine.save(page(month, ["a"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.recorded, [15, 1.5])
        XCTAssertEqual(count(.save), 0)

        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.account, "_user-a")
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
        XCTAssertEqual(count(.save), 1)
        let name = try XCTUnwrap(db.calls.lastIndex(of: .userRecordName))
        let save = try XCTUnwrap(db.calls.lastIndex(of: .save))
        XCTAssertLessThan(name, save)
    }

    func test33StartQueuesPagesTheLedgerDoesNotKnow() async throws {
        try store.save(page(month, ["a"]))
        try store.save(page(week, ["b"]))
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 2)
        XCTAssertEqual(Set(db.records.keys), [month, week])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(try storedPage(week).liveStrokeIds, ["b"])
    }

    func test34StateFileThatCannotBeWritten() async throws {
        // The "directory" of the state file is a plain file: every save of the ledger fails.
        let blocker = directory.appendingPathComponent("blocker", isDirectory: false)
        try Data().write(to: blocker)
        stateStore = SyncStateStore(fileURL: blocker.appendingPathComponent("state.json"))
        makeEngine()
        await startSynced()
        XCTAssertTrue(engine.stateSaveFailed)

        try engine.save(page(month, ["a"]))
        XCTAssertEqual(engine.state.dirty, [month])
        await flushDebounce()
        XCTAssertEqual(try storedPage(month).liveStrokeIds, ["a"])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
    }

    func test35ConfigurationErrorDoesNotRetryByItself() async throws {
        await startSynced()
        db.failNext[.save] = .configuration("x")
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        XCTAssertEqual(status, .error(.server("x")))
        XCTAssertEqual(status.settingsText, "同期に失敗しました")
        XCTAssertTrue(status.settingsFooter.hasSuffix("\nx"))
        XCTAssertEqual(sleeper.recorded, [1.5])
        XCTAssertEqual(engine.state.dirty, [month])

        await engine.syncNow()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(sleeper.recorded, [1.5])
    }

    func test36StartIsIdempotent() async throws {
        engine.start()
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.accountStatus), 1)
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.accountStatus), 1)
        XCTAssertEqual(count(.fetchChanges), 1)
        XCTAssertEqual(status, .synced)
    }

    // MARK: - The wording (§6.1)

    func testStatusWording() {
        XCTAssertEqual(SyncStatus.synced.header, HeaderSync(text: "保存済み", symbol: "icloud", isError: false))
        XCTAssertEqual(SyncStatus.pending.header, HeaderSync(text: "同期中", symbol: "icloud", isError: false))
        XCTAssertEqual(SyncStatus.syncing.header, HeaderSync(text: "同期中", symbol: "arrow.triangle.2.circlepath.icloud", isError: false))
        XCTAssertEqual(SyncStatus.offline.header, HeaderSync(text: "オフライン", symbol: "icloud.slash", isError: false))
        XCTAssertEqual(SyncStatus.localOnly(.noAccount).header, HeaderSync(text: "この端末のみ", symbol: "icloud.slash", isError: false))
        XCTAssertEqual(SyncStatus.error(.quota).header, HeaderSync(text: "エラー", symbol: "exclamationmark.icloud", isError: true))
        XCTAssertEqual(SyncStatus.accountMismatch.header, HeaderSync(text: "停止中", symbol: "person.crop.circle.badge.exclamationmark", isError: true))

        XCTAssertEqual(SyncStatus.synced.settingsText, "同期済み")
        XCTAssertEqual(SyncStatus.pending.settingsText, "同期中…")
        XCTAssertEqual(SyncStatus.syncing.settingsText, "同期中…")
        XCTAssertEqual(SyncStatus.offline.settingsText, "オフライン")
        XCTAssertEqual(SyncStatus.localOnly(.noAccount).settingsText, "iCloud にサインインしていません")
        XCTAssertEqual(SyncStatus.localOnly(.restricted).settingsText, "この端末では iCloud が制限されています")
        XCTAssertEqual(SyncStatus.localOnly(.unknown).settingsText, "iCloud を確認できません")
        XCTAssertEqual(SyncStatus.localOnly(.notAuthenticated).settingsText, "iCloud を確認できません")
        XCTAssertEqual(SyncStatus.error(.quota).settingsText, "iCloud の容量が足りません")
        XCTAssertEqual(SyncStatus.error(.permission).settingsText, "iCloud を使えません")
        XCTAssertEqual(SyncStatus.error(.server("m")).settingsText, "同期に失敗しました")
        XCTAssertEqual(SyncStatus.accountMismatch.settingsText, "別の iCloud アカウントです")

        XCTAssertEqual(SyncStatus.synced.settingsFooter, "手書きはこの端末と、あなたの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きが見られます。")
        XCTAssertEqual(SyncStatus.pending.settingsFooter, "書いた手書きを iCloud へ送っています。")
        XCTAssertEqual(SyncStatus.syncing.settingsFooter, SyncStatus.pending.settingsFooter)
        XCTAssertEqual(SyncStatus.offline.settingsFooter, "オフラインです。手書きはこの端末に保存され、接続が戻ると同期されます。")
        XCTAssertEqual(SyncStatus.localOnly(.noAccount).settingsFooter, "iCloud にサインインするとほかの端末と同期できます。手書きはこの端末の中だけに保存しています。")
        XCTAssertEqual(SyncStatus.localOnly(.restricted).settingsFooter, "手書きはこの端末の中だけに保存しています。")
        XCTAssertEqual(SyncStatus.localOnly(.unknown).settingsFooter, "「設定」アプリで iCloud を確認してください。手書きはこの端末の中だけに保存しています。")
        XCTAssertEqual(SyncStatus.error(.quota).settingsFooter, "iCloud の容量が不足しているため、手書きを同期できません。この端末には保存されています。")
        XCTAssertEqual(SyncStatus.error(.permission).settingsFooter, "iCloud の設定でこのアプリの利用が許可されていません。")
        XCTAssertEqual(SyncStatus.error(.server("zone")).settingsFooter, "手書きの同期に失敗しました。この端末には保存されています（あとで再試行します）。\nzone")
        XCTAssertEqual(SyncStatus.accountMismatch.settingsFooter, "この端末の手書きは、前に同期していた iCloud アカウントのものです。「新しいアカウントで使い始める」から選んでください。")

        XCTAssertFalse(SyncStatus.synced.isError)
        XCTAssertFalse(SyncStatus.offline.isError)
        XCTAssertFalse(SyncStatus.localOnly(.restricted).isError)
        XCTAssertTrue(SyncStatus.error(.permission).isError)
        XCTAssertTrue(SyncStatus.accountMismatch.isError)
        XCTAssertEqual(ImportOutcome(pagesChanged: 12, strokesAdded: 348, pagesSeen: 12).strokesAdded, 348)

        // 1.1 (M7A_CONTRACT §6.1): the device is 「この端末」 in every sentence; only 「ほかの iPad や
        // iPhone」 (both kinds by name) keeps the word.
        let every: [SyncStatus] = [.synced, .pending, .syncing, .offline, .localOnly(.noAccount), .localOnly(.restricted),
                                   .localOnly(.unknown), .localOnly(.notAuthenticated), .error(.quota), .error(.permission),
                                   .error(.server("m")), .accountMismatch]
        for status in every {
            for text in [status.header.text, status.settingsText, status.settingsFooter] {
                XCTAssertFalse(text.contains("この iPad"), "\(status): \(text)")
                XCTAssertFalse(text.replacingOccurrences(of: "ほかの iPad や iPhone", with: "").contains("iPad"), "\(status): \(text)")
            }
        }
    }

    // MARK: - 1.1: a page a 1.0 device cut at 20,000 strokes (M7A_CONTRACT §1.3 / §5.1, K-9)

    /// A 1.0 device keeps only the first 20,000 strokes (in id order) each time it reads a page and
    /// sends that back when it edits it (F8). 1.1 reads up to 60,000, so the device that has all
    /// 20,500 keeps them when the cut record arrives, marks the page dirty (the merge differs from the
    /// record) and sends the 20,500 again — `SyncEngine` is unchanged; `InkPage.maxStrokes` does it.
    func testMergeRemoteOfATruncatedPageMarksDirty() async throws {
        let id = "y-2026"
        var full = InkPage.empty(pageId: id)
        for i in 0..<20_500 {
            let point = InkPoint(x: CGFloat(i % 50), y: CGFloat(i / 50), dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.4)
            full.add(InkStroke(id: String(format: "s%05d", i), cell: .yearDay(month: 1 + i % 12, day: 1 + i % 28), tool: .pen,
                               color: "#1f2937", t: 1_760_000_001_000 + i, points: [point]))
        }
        XCTAssertEqual(full.liveStrokeCount, 20_500)

        // This 1.1 device wrote the page and sent it.
        await startSynced()
        try engine.save(full)
        await flushDebounce()
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(id).liveStrokeCount, 20_500)

        // A 1.0 device read it (the first 20,000 ids), edited and sent the cut page: no tombstones.
        var cut = InkPage.empty(pageId: id)
        for strokeId in full.strokes.keys.sorted().prefix(StrokeBudget.legacyReadCap) {
            cut.add(full.strokes[strokeId]!)
        }
        XCTAssertEqual(cut.liveStrokeCount, 20_000)
        XCTAssertTrue(cut.deleted.isEmpty)
        db.simulateRemoteSave(try record(cut))

        // Fetched (the page was opened): the file keeps all 20,500 and the page is queued again.
        engine.pageOpened(id)
        await engine.waitUntilIdle()
        XCTAssertEqual(store.load(id).liveStrokeCount, 20_500, "1.1 reads past 20,000 (InkPage.maxStrokes)")
        XCTAssertEqual(store.peek(id)?.strokeIds.count, 20_500)
        XCTAssertEqual(store.peek(id)?.tombstones, 0)
        XCTAssertEqual(engine.state.dirty, [id], "the merge differs from the cut record")

        // The next round sends the 20,500 back; nothing was tombstoned on the way.
        await engine.syncNow()
        let sent = try storedPage(id)
        XCTAssertEqual(sent.liveStrokeCount, 20_500)
        XCTAssertEqual(Set(sent.liveStrokeIds), Set(full.liveStrokeIds))
        XCTAssertTrue(sent.deleted.isEmpty)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(store.load(id).liveStrokeCount, 20_500)
    }

    // MARK: - 1.2: the week start (docs/M7B_CONTRACT.md §10.3, §10.8)

    /// A Sunday week page is a page like any other: nothing in the engine looks at the id's form (K-11).
    func testSundayPageSyncsLikeAnyPage() async throws {
        await startSynced()
        let sunday = "w-2026-10-04"
        try engine.save(page(sunday, ["a"]))
        await flushDebounce()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(try storedPage(sunday).liveStrokeIds, ["a"])

        // Another device adds a stroke; the merge keeps both.
        var other = page(sunday, ["a"])
        other.add(stroke("b", t: 1_760_000_002_000))
        db.simulateRemoteSave(try record(other))
        await engine.syncNow()
        XCTAssertEqual(Set(store.load(sunday).liveStrokeIds), ["a", "b"])
        XCTAssertEqual(store.allPageIds(), [sunday])
    }

    /// F7: 「全て消す」 takes both forms (and it means it: the sentence says everything).
    func testEraseEverythingRemovesBothForms() async throws {
        await startSynced()
        try engine.save(page(week, ["a"]))
        try engine.save(page("w-2026-10-04", ["b"]))
        await flushDebounce()
        XCTAssertEqual(Set(store.allPageIds()), [week, "w-2026-10-04"])
        try await engine.eraseEverything()
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertEqual(db.records.keys.filter { $0 != "meta" }, [])
    }

    /// K-11: switching opens another page and touches nothing: Monday's strokes are there on the way
    /// back, and neither page has the other's.
    func testSwitchKeepsBothForms() async throws {
        await startSynced()
        let wednesday = DayKey(year: 2026, month: 10, day: 7)
        let mondayId = PageNavigation.pageId(.week, focus: wednesday, weekStart: .monday)
        let sundayId = PageNavigation.pageId(.week, focus: wednesday, weekStart: .sunday)
        XCTAssertEqual(mondayId, "w-2026-10-05")
        XCTAssertEqual(sundayId, "w-2026-10-04")

        try engine.save(page(mondayId, ["monday"]))
        XCTAssertTrue(engine.load(sundayId).liveStrokeIds.isEmpty, "the other form starts empty")
        try engine.save(page(sundayId, ["sunday"]))
        await flushDebounce()
        XCTAssertEqual(engine.load(mondayId).liveStrokeIds, ["monday"])
        XCTAssertEqual(engine.load(sundayId).liveStrokeIds, ["sunday"])
        XCTAssertEqual(engine.load(mondayId).deleted, [:], "nothing is tombstoned")
        XCTAssertEqual(WeekStartImpact.weekPages(engine.allLocalPageIds()).monday, 1)
        XCTAssertEqual(WeekStartImpact.weekPages(engine.allLocalPageIds()).sunday, 1)
    }

    /// §10.3, 4 (1), the premise: after a failed pull a stroke's push reaches `.synced` and writes
    /// `lastSyncAt`, yet nothing came from iCloud. Only `zoneToken` tells: a pull writes it.
    func testPushOnlyLeavesNoZoneToken() async throws {
        db.failNext[.fetchChanges] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertNil(engine.state.zoneToken)

        // The retry's pull fails again; the debounced push goes through.
        try engine.save(page(month, ["a"]))
        db.failNext[.fetchChanges] = .networkUnavailable
        await flushDebounce()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertNotNil(engine.snapshot.lastSyncAt, "a push writes it too: no mark of a pull")
        XCTAssertNil(engine.state.zoneToken)
        XCTAssertFalse(WeekStartChoice.readyToCheck(status: status, zoneToken: engine.state.zoneToken))

        // The next retry's pull succeeds: now it is ready.
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        XCTAssertNotNil(engine.state.zoneToken)
        XCTAssertTrue(WeekStartChoice.readyToCheck(status: status, zoneToken: engine.state.zoneToken))
    }

    // MARK: - 1.2.3: the account is confirmed before anything is sent (docs/R1_2_3.md §5, M4_CONTRACT §8.2 37–52)

    /// The ledger of a device that synced with `_user-a` (zone and subscription made), as 1.2.2 wrote it.
    private func priorAccountA() throws {
        var prior = SyncState.empty
        prior.account = "_user-a"
        prior.zoneReady = true
        prior.subscriptionReady = true
        try stateStore.save(prior)
    }

    /// 37 (G1): the launch's check failed (`accountStatus` threw) after the Apple Account was switched while
    /// the app was not running. The page fetch and the retry do not talk to the new account unchecked.
    func testAccountCheckThatFailedAtLaunchIsMadeAgain() async throws {
        try priorAccountA()
        try store.save(page(month, ["a"]))
        db.userName = "_user-b"
        db.failNext[.accountStatus] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(db.calls, [.accountStatus])
        XCTAssertEqual(sleeper.recorded, [15])

        engine.pageOpened(week)
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 0)

        await sleeper.advance() // the retry
        await engine.waitUntilIdle()
        XCTAssertEqual(db.calls, [.accountStatus, .accountStatus, .userRecordName])
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.pendingAccount, "_user-b")
        XCTAssertEqual(engine.state.dirty, [month])
        XCTAssertTrue(db.records.isEmpty)
    }

    /// 38 (G1): `.temporarilyUnavailable` at launch; the foreground's round trip checks again.
    func testTemporarilyUnavailableAccountIsCheckedAgainByTheForeground() async throws {
        try priorAccountA()
        try store.save(page(month, ["a"]))
        db.userName = "_user-b"
        db.status = .temporarilyUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .pending)
        XCTAssertEqual(db.calls, [.accountStatus])
        XCTAssertEqual(sleeper.recorded, [15])

        db.status = .available
        await engine.syncNow()
        XCTAssertEqual(db.calls, [.accountStatus, .accountStatus, .userRecordName])
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(count(.save), 0)
        XCTAssertEqual(count(.fetchChanges), 0)
    }

    /// 39 (G1, G2): `userRecordName` threw at launch; neither the retry nor the debounced push sends.
    func testFailedUserRecordNameKeepsTheCheckForTheRetryAndThePush() async throws {
        try priorAccountA()
        try store.save(page(month, ["a"]))
        db.userName = "_user-b"
        db.failNext[.userRecordName] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)

        try engine.save(page(week, ["b"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.recorded, [15, 1.5])
        await sleeper.advance() // the retry, then the debounce
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(count(.save), 0)
        XCTAssertEqual(count(.fetchChanges), 0)
        XCTAssertEqual(Set(engine.state.dirty), [month, week])
    }

    /// 40 (G2): a push queued (behind a page fetch) before `.CKAccountChanged` confirms the account first.
    func testPushQueuedBeforeAnAccountChangeConfirmsFirst() async throws {
        await startSynced()
        db.pause(.fetchRecords)
        engine.pageOpened(week) // a page fetch, paused inside the fake
        await waitUntil { self.db.calls.contains(.fetchRecords) }
        try engine.save(page(month, ["a"]))
        await waitUntil { self.sleeper.waiting == 1 }
        await sleeper.advance() // the debounce: the push is queued behind the fetch
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await waitUntil { self.engine.accountChangesHandled == 1 } // its round trip is queued behind the push
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 0, "nothing went to the other account")
        XCTAssertNil(db.records[month])
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.pendingAccount, "_user-b")
        XCTAssertEqual(engine.state.dirty, [month])
    }

    /// 41 (G2): the web import sends no `Meta` and no page to an account that was not confirmed.
    func testImportDoesNotSendMetaToAnUnconfirmedAccount() async throws {
        try priorAccountA()
        try store.save(page(month, ["a"]))
        db.userName = "_user-b"
        db.failNext[.accountStatus] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)

        let outcome = try await engine.importPages([page(week, ["c"])]) { _, _ in }
        XCTAssertEqual(outcome.pagesChanged, 1)
        await engine.waitUntilIdle()
        XCTAssertFalse(db.calls.contains(.save))
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.snapshot.webImportedAt, now)
        XCTAssertEqual(Set(engine.state.dirty), [month, week])
    }

    /// 42 (G2, the erase): nothing is deleted from an unconfirmed account; adopting the new account drops
    /// the erase that was pending for the old one, so the new account's ink stays and comes to the device.
    func testEraseWaitsForTheAccountAndKeepInkDropsIt() async throws {
        try priorAccountA()
        try await db.ensureZone()
        db.simulateRemoteSave(try record(page(week, ["b"]))) // the new account's own page
        try store.save(page(month, ["a"]))
        db.userName = "_user-b"
        db.failNext[.accountStatus] = .networkUnavailable
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)

        do {
            try await engine.eraseEverything()
            XCTFail("the iCloud part waits for the account")
        } catch {}
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertNotNil(db.records[week])
        XCTAssertTrue(db.deletedNames.isEmpty)
        XCTAssertTrue(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .accountMismatch)

        await engine.resolveAccountChange(.keepInk)
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertFalse(stateStore.load().pendingCloudErase)
        XCTAssertTrue(db.deletedNames.isEmpty)
        XCTAssertNotNil(db.records[week])
        XCTAssertEqual(store.load(week).liveStrokeIds, ["b"])
        XCTAssertEqual(status, .synced)
    }

    /// 43 (`.CKAccountChanged` during a push): only the page in flight can reach the new account.
    func testAccountChangeStopsThePushUnderWay() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        try engine.save(page(week, ["b"]))
        await engine.waitUntilIdle()
        await sleeper.advance() // the generation moved: the debounce sleeps again
        await engine.waitUntilIdle()
        db.pause(.save)
        await sleeper.advance() // the push starts; month's save is paused
        await waitUntil { self.db.calls.contains(.save) }
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await waitUntil { self.engine.accountChangesHandled == 1 }
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 1, "only the page in flight")
        XCTAssertNil(db.records[week])
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(Set(engine.state.dirty), [month, week])
    }

    /// 44 (G3): a silent push that arrives before `.CKAccountChanged` confirms the account first.
    func testSilentPushConfirmsTheAccountFirst() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(week, ["b"])))
        db.userName = "_user-b" // switched; `.CKAccountChanged` not here yet
        let mark = db.calls.count
        let brought = await engine.handleRemoteNotification(subscriptionInfo)
        XCTAssertFalse(brought)
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName])
        XCTAssertFalse(store.exists(week))
        XCTAssertEqual(status, .accountMismatch)
    }

    /// 45 (G3): a check made in the background does not clear the mark; the retry that fires first after a
    /// switch during the suspension checks again, and so does the return to the foreground.
    func testTimerAfterTheBackgroundConfirmsTheAccountFirst() async throws {
        await startSynced()
        engine.applicationDidEnterBackground()
        let mark = db.calls.count
        db.failNext[.save] = .networkUnavailable
        try engine.save(page(month, ["a"])) // saveNow on the way out
        await flushDebounce()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName, .save])
        XCTAssertEqual(status, .offline)

        db.userName = "_user-b" // switched while suspended
        let fetches = count(.fetchChanges)
        await sleeper.advance() // the retry fires first on resume
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 1)
        XCTAssertEqual(count(.fetchChanges), fetches)
        XCTAssertEqual(status, .accountMismatch)

        engine.applicationDidBecomeActive()
        await engine.waitUntilIdle()
        db.simulateAccountChange(status: .available, userName: "_user-b") // late
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(count(.save), 1)
        XCTAssertNil(db.records[month])
    }

    /// 46 (G3): the return to the foreground comes before `.CKAccountChanged`.
    func testReturnToForegroundConfirmsTheAccountFirst() async throws {
        await startSynced()
        engine.applicationDidEnterBackground()
        db.userName = "_user-b"
        let mark = db.calls.count
        engine.applicationDidBecomeActive()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName])
        XCTAssertEqual(status, .accountMismatch)
    }

    /// 47 (the cost): a return without the background (`.inactive` only) adds no check; a return from the
    /// background adds one.
    func testReturnWithoutBackgroundDoesNotCheckAgain() async throws {
        await startSynced()
        var mark = db.calls.count
        engine.applicationDidBecomeActive()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges])

        engine.applicationDidEnterBackground()
        mark = db.calls.count
        engine.applicationDidBecomeActive()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName, .fetchChanges])

        mark = db.calls.count
        engine.applicationDidBecomeActive()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges])
        XCTAssertEqual(status, .synced)
    }

    /// 48 (the epoch of the round trip): `.CKAccountChanged` while the zone is being made (after "keep my
    /// ink") stops the round trip before its pull and push; the next one finds the third account.
    func testAccountChangeWhileTheZoneIsMadeStopsTheRoundTrip() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .accountMismatch)
        db.simulateRemoteSave(try record(page(week, ["b"])))
        let saves = count(.save)

        db.pause(.ensureZone)
        let choice = Task { await self.engine.resolveAccountChange(.keepInk) }
        await waitUntil { self.db.calls.last == .ensureZone }
        db.simulateAccountChange(status: .available, userName: "_user-c")
        await waitUntil { self.engine.accountChangesHandled == 2 }
        db.resume()
        await choice.value
        await engine.waitUntilIdle()
        XCTAssertFalse(store.exists(week), "nothing merged from the account that was left")
        XCTAssertEqual(count(.save), saves)
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.pendingAccount, "_user-c")
    }

    /// 49 (G3, the round trip that iOS froze): the push sending in the background when the app was suspended
    /// stops when the app comes back, before its next page.
    func testFrozenPushStopsWhenTheAppComesBack() async throws {
        await startSynced()
        engine.applicationDidEnterBackground()
        try engine.save(page(month, ["a"]))
        try engine.save(page(week, ["b"]))
        await engine.waitUntilIdle()
        await sleeper.advance() // the generation moved: the debounce sleeps again
        await engine.waitUntilIdle()
        db.pause(.save)
        await sleeper.advance() // the push: checked, month's save is paused (the app is suspended)
        await waitUntil { self.db.calls.contains(.save) }
        db.userName = "_user-b"
        engine.applicationDidBecomeActive()
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 1)
        XCTAssertNil(db.records[week])
        XCTAssertEqual(status, .accountMismatch)
    }

    /// 50 (G3, the same, woken before anything else): the push goes on after a long suspension; its last
    /// check is older than `awayRecheckAfter`, so it stops before the next page and the account is checked.
    func testFrozenPushWokenLaterChecksTheAccountFirst() async throws {
        await startSynced()
        engine.applicationDidEnterBackground()
        try engine.save(page(month, ["a"]))
        try engine.save(page(week, ["b"]))
        await engine.waitUntilIdle()
        await sleeper.advance()
        await engine.waitUntilIdle()
        db.pause(.save)
        await sleeper.advance()
        await waitUntil { self.db.calls.contains(.save) }
        db.userName = "_user-b"
        now = now.addingTimeInterval(60) // suspended for a minute
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), 1)
        XCTAssertNil(db.records[week])
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.dirty, [week])
    }

    /// 51 (the zone loss): in the background, `.zoneMissing` (what a switched account looks like) does not
    /// send every page again before the account is confirmed.
    func testZoneLossInTheBackgroundConfirmsTheAccountFirst() async throws {
        await startSynced()
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        try engine.save(page(week, ["b"]))
        await flushDebounce()
        engine.applicationDidEnterBackground()
        try engine.save(page(week, ["b", "c"]))
        await engine.waitUntilIdle()
        db.pause(.save)
        let mark = db.calls.count
        await sleeper.advance()
        await waitUntil { self.db.calls[mark...].contains(.save) } // the check passed; week's save is paused
        db.userName = "_user-b"
        db.simulateZoneDeleted()
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName, .save, .accountStatus, .userRecordName])
        XCTAssertFalse(db.calls[mark...].contains(.ensureZone))
        XCTAssertTrue(db.records.isEmpty)
        XCTAssertEqual(status, .accountMismatch)
        XCTAssertEqual(engine.state.dirty, [week], "the zone loss's resend did not run")
    }

    /// 52 (the erase): `.CKAccountChanged` during the erase's account check stops the erase; the round trip
    /// queued with it checks again and then finishes the erase (the same account here).
    func testAccountChangeDuringTheEraseCheckStopsTheErase() async throws {
        await startSynced()
        db.simulateRemoteSave(try record(page(week, ["b"])))
        engine.applicationDidEnterBackground()
        let mark = db.calls.count
        db.pause(.userRecordName)
        let erase = Task { try await self.engine.eraseEverything() }
        await waitUntil { self.db.calls.count > mark + 1 }
        db.simulateAccountChange(status: .available, userName: "_user-a")
        await waitUntil { self.engine.accountChangesHandled == 1 }
        db.resume()
        do {
            try await erase.value
            XCTFail("the erase stopped for the account change")
        } catch {}
        await engine.waitUntilIdle()
        let calls = Array(db.calls[mark...])
        let firstDelete = try XCTUnwrap(calls.firstIndex(of: .delete))
        let names = calls.indices.filter { calls[$0] == .userRecordName }
        XCTAssertEqual(names.count, 2)
        XCTAssertLessThan(names.dropFirst().first ?? Int.max, firstDelete, "deleted only after the second check")
        XCTAssertNil(db.records[week])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .synced)
    }
}
