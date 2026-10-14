import Combine
import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// The sync engine over the fake iCloud (M4_CONTRACT §8.2, 0–36): the account check, the debounce,
/// conflicts, pulls, deletions, the retry backoff, the zone loss, the silent push, the account
/// switch, the erase and the web import. `TestSleeper` stands in for the clock's sleeps, the clock
/// is fixed, and the page files live in a temporary directory. No iCloud account anywhere.
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
        sleeper.advance()
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
        XCTAssertEqual(status.header.text, "この iPad のみ")
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

        sleeper.advance()
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
        sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.recorded, [1.5, 1.5])
        XCTAssertEqual(count(.save), 0)
        sleeper.advance()
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
        sleeper.advance()
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
        sleeper.advance()
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
        sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.recorded, [1.5, 15, 30])

        sleeper.advance()
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
        sleeper.advance()
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
        sleeper.advance()
        await engine.waitUntilIdle()

        let mark = db.calls.count
        let foreign = await engine.handleRemoteNotification([:])
        XCTAssertFalse(foreign)
        XCTAssertEqual(db.calls.count, mark)
        XCTAssertEqual(sleeper.recorded, [20])

        let nothingNew = await engine.handleRemoteNotification(subscriptionInfo)
        XCTAssertFalse(nothingNew)
        sleeper.advance()
        await engine.waitUntilIdle()

        db.pause(.fetchChanges)
        db.simulateRemoteSave(try record(page(week, ["c"])))
        let task = Task { await self.engine.handleRemoteNotification(self.subscriptionInfo) }
        await waitUntil { self.sleeper.recorded.last == 20 && self.sleeper.waiting == 1 }
        sleeper.advance()
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
        sleeper.advance() // the debounce of the early save: nothing left to send
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

        sleeper.advance()
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
        XCTAssertEqual(SyncStatus.localOnly(.noAccount).header, HeaderSync(text: "この iPad のみ", symbol: "icloud.slash", isError: false))
        XCTAssertEqual(SyncStatus.error(.quota).header, HeaderSync(text: "エラー", symbol: "exclamationmark.icloud", isError: true))
        XCTAssertEqual(SyncStatus.accountMismatch.header, HeaderSync(text: "停止中", symbol: "person.crop.circle.badge.exclamationmark", isError: true))

        XCTAssertEqual(SyncStatus.synced.settingsText, "同期済み")
        XCTAssertEqual(SyncStatus.pending.settingsText, "同期中…")
        XCTAssertEqual(SyncStatus.syncing.settingsText, "同期中…")
        XCTAssertEqual(SyncStatus.offline.settingsText, "オフライン")
        XCTAssertEqual(SyncStatus.localOnly(.noAccount).settingsText, "iCloud にサインインしていません")
        XCTAssertEqual(SyncStatus.localOnly(.restricted).settingsText, "この iPad では iCloud が制限されています")
        XCTAssertEqual(SyncStatus.localOnly(.unknown).settingsText, "iCloud を確認できません")
        XCTAssertEqual(SyncStatus.localOnly(.notAuthenticated).settingsText, "iCloud を確認できません")
        XCTAssertEqual(SyncStatus.error(.quota).settingsText, "iCloud の容量が足りません")
        XCTAssertEqual(SyncStatus.error(.permission).settingsText, "iCloud を使えません")
        XCTAssertEqual(SyncStatus.error(.server("m")).settingsText, "同期に失敗しました")
        XCTAssertEqual(SyncStatus.accountMismatch.settingsText, "別の iCloud アカウントです")

        XCTAssertEqual(SyncStatus.synced.settingsFooter, "手書きはこの iPad と、あなたの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きが見られます。")
        XCTAssertEqual(SyncStatus.pending.settingsFooter, "書いた手書きを iCloud へ送っています。")
        XCTAssertEqual(SyncStatus.syncing.settingsFooter, SyncStatus.pending.settingsFooter)
        XCTAssertEqual(SyncStatus.offline.settingsFooter, "オフラインです。手書きはこの iPad に保存され、接続が戻ると同期されます。")
        XCTAssertEqual(SyncStatus.localOnly(.noAccount).settingsFooter, "iCloud にサインインするとほかの端末と同期できます。手書きはこの iPad の中だけに保存しています。")
        XCTAssertEqual(SyncStatus.localOnly(.restricted).settingsFooter, "手書きはこの iPad の中だけに保存しています。")
        XCTAssertEqual(SyncStatus.localOnly(.unknown).settingsFooter, "iPad の設定で iCloud を確認してください。手書きはこの iPad の中だけに保存しています。")
        XCTAssertEqual(SyncStatus.error(.quota).settingsFooter, "iCloud の容量が不足しているため、手書きを同期できません。この iPad には保存されています。")
        XCTAssertEqual(SyncStatus.error(.permission).settingsFooter, "iCloud の設定でこのアプリの利用が許可されていません。")
        XCTAssertEqual(SyncStatus.error(.server("zone")).settingsFooter, "手書きの同期に失敗しました。この iPad には保存されています（あとで再試行します）。\nzone")
        XCTAssertEqual(SyncStatus.accountMismatch.settingsFooter, "この iPad の手書きは、前に同期していた iCloud アカウントのものです。「新しいアカウントで使い始める」から選んでください。")

        XCTAssertFalse(SyncStatus.synced.isError)
        XCTAssertFalse(SyncStatus.offline.isError)
        XCTAssertFalse(SyncStatus.localOnly(.restricted).isError)
        XCTAssertTrue(SyncStatus.error(.permission).isError)
        XCTAssertTrue(SyncStatus.accountMismatch.isError)
        XCTAssertEqual(ImportOutcome(pagesChanged: 12, strokesAdded: 348, pagesSeen: 12).strokesAdded, 348)
    }
}
