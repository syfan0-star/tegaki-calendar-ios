import InkModel
import XCTest
@testable import TegakiCalendar

/// 1.2.4 (M4_CONTRACT §8.2, 60–62): 「全て消す」 and the single-page fetch of `pageOpened`. The fetch asks for
/// nothing while the iCloud half of the erase is pending (`pendingCloudErase`), neither when `pageOpened` is
/// called nor when its work runs, since the round trip finishes that deletion before it pulls anything (§4.5
/// 10) and a page fetched before it would write the erased ink back on this device and, with the next launch,
/// send it to iCloud again. 60 and 61: a fetch queued before the erase (behind another page's request, or
/// behind the account check of the return from the background) runs after the files are gone and before the
/// iCloud half. 62: the iCloud half failed, and a page is opened before the retry.
///
/// A live engine over a temporary `InkPageStore` and `InMemoryCloudDatabase`, `TestSleeper` for every sleep, a
/// fixed clock. SyncEngineTests.swift stays as in 1.2.3; the helpers below copy its own. TestSleeper's cautions
/// (docs/R1_2_3.md §4.3) hold: `advance()` is called from one task at a time, and never while the fake has an
/// operation paused.
@MainActor
final class SyncEngineEraseFetchTests: XCTestCase {
    private var directory: URL!
    private var store: InkPageStore!
    private var stateStore: SyncStateStore!
    private var db: InMemoryCloudDatabase!
    private var sleeper: TestSleeper!
    private var engine: SyncEngine!
    private var now = Date(timeIntervalSince1970: 1_760_150_500)
    private var remoteUpdates: [InkPage] = []

    private let month = "m1-2026-10"
    private let week = "w-2026-10-05"

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncEngineEraseFetchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        stateStore = SyncStateStore(fileURL: store.stateFileURL)
        db = InMemoryCloudDatabase()
        sleeper = TestSleeper()
        now = Date(timeIntervalSince1970: 1_760_150_500)
        remoteUpdates = []
        makeEngine()
    }

    override func tearDown() async throws {
        engine?.onRemoteUpdate = nil
        engine = nil
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    /// The engine may outlive the test (a task still asleep in the sleeper), so nothing here holds the test
    /// strongly or unowned. Called again, it is the next launch over the same files, state file and iCloud.
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

    /// The `InkPage` records in iCloud (not `Meta`).
    private func inkNames() -> [String] {
        db.records.keys.filter { $0 != InkPageRecord.metaRecordName }.sorted()
    }

    /// Started and synced, with the month page ("a", "b") and the week page ("q") in iCloud and on the device
    /// (another device wrote them; the first pull brought them).
    private func syncedWithTwoPages() async throws {
        db.simulateRemoteSave(try record(page(month, ["a", "b"])))
        db.simulateRemoteSave(try record(page(week, ["q"])))
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(store.allPageIds().sorted(), [month, week])
        XCTAssertEqual(inkNames(), [month, week])
        XCTAssertEqual(engine.state.dirty, [])
    }

    /// The next launch (a new engine over the same files, state file and iCloud, and its first round trip)
    /// leaves the device and iCloud empty and sends nothing.
    private func nextLaunchSendsNothing(file: StaticString = #filePath, line: UInt = #line) async {
        engine.onRemoteUpdate = nil
        makeEngine()
        let saves = count(.save)
        engine.start()
        XCTAssertEqual(engine.state.dirty, [], "start() found no page the ledger does not know", file: file, line: line)
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), saves, "nothing was sent again", file: file, line: line)
        XCTAssertEqual(inkNames(), [], file: file, line: line)
        XCTAssertEqual(store.allPageIds(), [], file: file, line: line)
        XCTAssertEqual(status, .synced, file: file, line: line)
    }

    /// Yields until `condition` holds (for work that is paused inside the fake, which `waitUntilIdle` would
    /// wait for forever). After 4000 yields it polls every millisecond for up to 5 s, as SyncEngineTests does.
    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<4000 {
            if condition() { return }
            await Task.yield()
        }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        if condition() { return }
        XCTFail("timed out", file: file, line: line)
    }

    // MARK: - 60, 61: a fetch queued before the erase

    /// 60: on a slow network the week page's request is under way (paused in the fake) and the month page,
    /// opened next, waits behind it; then 「全て消す」. The files go at once and the iCloud half waits behind the
    /// month page's fetch. That fetch asks for nothing (the iCloud half is pending), the request under way is
    /// stopped by its epoch (as in 1.2.3), the erase succeeds, and neither page comes back, on the screen, on
    /// the device or, with the next launch, in iCloud.
    ///
    /// Fails on 43fe366: the queued fetch asks for the month page (`fetchRecords` 2), writes it back with "a"
    /// and "b" and hands it to the screen; the erase then empties iCloud, the ledger forgets the page, and the
    /// next launch's `start()` marks it dirty and sends it to iCloud again.
    func testPageFetchQueuedBehindAnotherFetchBeforeTheEraseAsksForNothing() async throws {
        try await syncedWithTwoPages()
        let mark = db.calls.count
        db.pause(.fetchRecords)
        engine.pageOpened(week) // its request is under way…
        await waitUntil { self.count(.fetchRecords) == 1 }
        engine.pageOpened(month) // …and this fetch waits behind it
        XCTAssertEqual(status, .synced)

        let current: SyncEngine = engine
        let erase = Task { @MainActor in try await current.eraseEverything() }
        await waitUntil { self.engine.state.pendingCloudErase }
        XCTAssertEqual(store.allPageIds(), [], "the files went at once")
        remoteUpdates = []
        db.resume()
        try await erase.value
        await engine.waitUntilIdle()

        XCTAssertEqual(Array(db.calls[mark...]), [.fetchRecords, .fetchChanges, .delete, .fetchChanges])
        XCTAssertEqual(count(.fetchRecords), 1, "the fetch queued before the erase asked for nothing")
        XCTAssertEqual(store.allPageIds(), [], "the erased ink did not come back")
        XCTAssertEqual(remoteUpdates.map(\.pageId), [])
        XCTAssertEqual(inkNames(), [])
        XCTAssertEqual(engine.state.seen, [:])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .synced)

        await nextLaunchSendsNothing()
    }

    /// 61: the same when the queue is held by the account check of the return from the background. The check
    /// clears its request when it starts (G1), so a page opened during it is queued behind the round trip. The
    /// erase comes before the check answers: the round trip stops at its epoch after the check, the queued
    /// fetch asks for nothing, and the iCloud half deletes both pages.
    ///
    /// Fails on 43fe366: the queued fetch runs with the new epoch, asks for the month page (calls
    /// `[accountStatus, userRecordName, fetchRecords, …]`) and writes it back; the next launch sends it again.
    func testPageFetchQueuedDuringTheForegroundCheckBeforeTheEraseAsksForNothing() async throws {
        try await syncedWithTwoPages()
        engine.applicationDidEnterBackground()
        let mark = db.calls.count
        db.pause(.accountStatus)
        engine.applicationDidBecomeActive() // its round trip's check is under way…
        await waitUntil { self.count(.accountStatus) == 2 }
        engine.pageOpened(month) // …and this fetch waits behind the round trip
        XCTAssertEqual(status, .synced)

        let current: SyncEngine = engine
        let erase = Task { @MainActor in try await current.eraseEverything() }
        await waitUntil { self.engine.state.pendingCloudErase }
        XCTAssertEqual(store.allPageIds(), [])
        remoteUpdates = []
        db.resume()
        try await erase.value
        await engine.waitUntilIdle()

        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName, .fetchChanges, .delete, .fetchChanges])
        XCTAssertEqual(count(.fetchRecords), 0, "the fetch queued before the erase asked for nothing")
        XCTAssertEqual(store.allPageIds(), [], "the erased ink did not come back")
        XCTAssertEqual(remoteUpdates.map(\.pageId), [])
        XCTAssertEqual(inkNames(), [])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .synced)

        await nextLaunchSendsNothing()
    }

    // MARK: - 62: the iCloud half failed

    /// 62: the iCloud half of 「全て消す」 fails (offline): the files are gone, the records are still in iCloud,
    /// `pendingCloudErase` stays and the retry waits 15 s. The network comes back and the month page is opened
    /// before the retry: nothing is asked for and nothing comes back. The retry finishes the deletion before it
    /// pulls; the device stays empty. The refused call started no cooldown: once another device writes the
    /// page anew, opening it at the same instant fetches it, with only the new stroke. The next launch sends
    /// nothing.
    ///
    /// Fails on 43fe366: the page opened before the retry is fetched (`fetchRecords` 1) and written back with
    /// "a" and "b"; the retry deletes the records in iCloud but leaves the file, and the next launch sends it to
    /// iCloud again.
    func testNoPageFetchWhileTheCloudEraseIsPending() async throws {
        try await syncedWithTwoPages()
        db.failNext[.delete] = .networkUnavailable
        do {
            try await engine.eraseEverything()
            XCTFail("the iCloud half of the erase did not fail")
        } catch {
            XCTAssertEqual(error as? CloudError, .networkUnavailable)
        }
        XCTAssertTrue(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.recorded.last, 15)
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertEqual(inkNames(), [month, week], "the records are still in iCloud")

        remoteUpdates = []
        engine.pageOpened(month) // the network is back; the retry has not come yet
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 0, "nothing is fetched while the iCloud half is pending")
        XCTAssertFalse(store.exists(month), "the erased ink did not come back")
        XCTAssertEqual(remoteUpdates.map(\.pageId), [])
        XCTAssertTrue(engine.state.pendingCloudErase)

        let mark = db.calls.count
        await sleeper.advance() // the retry: the round trip finishes the deletion before it pulls
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .delete, .fetchChanges, .fetchChanges])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertEqual(inkNames(), [])
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)

        db.simulateRemoteSave(try record(page(month, ["n"]))) // another device writes the page anew
        engine.pageOpened(month) // the same instant as the refused call
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.fetchRecords), 1)
        XCTAssertEqual(store.load(month).liveStrokeIds, ["n"], "only the new stroke")
        XCTAssertEqual(remoteUpdates.map(\.pageId), [month])
        XCTAssertEqual(engine.state.dirty, [])

        engine.onRemoteUpdate = nil
        makeEngine()
        let saves = count(.save)
        engine.start()
        XCTAssertEqual(engine.state.dirty, [])
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.save), saves, "the next launch sends nothing")
        XCTAssertEqual(store.load(month).liveStrokeIds, ["n"])
        XCTAssertEqual(try InkPageRecord.page(from: XCTUnwrap(db.records[month])).liveStrokeIds, ["n"])
        XCTAssertEqual(status, .synced)
    }
}
