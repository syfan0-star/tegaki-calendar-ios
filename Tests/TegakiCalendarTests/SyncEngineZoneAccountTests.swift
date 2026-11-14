import InkModel
import XCTest
@testable import TegakiCalendar

/// G4 (docs/M7C.md, wave C1, lead decision 3): the zone found missing by the work outside the round trip — the
/// single-page fetch of `pageOpened` and the push without a pull (the 1.5 s debounce) — is confirmed against the
/// account before the zone recovery marks every local page dirty and sends it. A missing zone is what a switched
/// Apple Account looks like (docs/R1_2_3.md §2 M3), and in the foreground nothing orders `.CKAccountChanged`
/// before the new account's answers: with the app side by side with the Settings app (iPad) or on a Mac
/// (docs/R1_2_3.md §11.2), a page opened or a stroke sent after the switch can meet the new account's empty
/// iCloud before the notification is handled. In 1.2.3 that zone loss was confirmed only "when a check is due"
/// (`confirmAgainIfDue`), so the recovery sent every page of this device into the other person's iCloud, and
/// 「消して始める」 brought them back from there. The round trip's own zone recovery keeps 1.2.3's order (M4_CONTRACT
/// §8.2 16, `SyncEngineTests.test16ZoneLossSendsEverythingAgain`).
///
/// The switch is played as CloudKit sees it: `db.userName` is the new account and its iCloud has no zone of this app
/// (`simulateZoneDeleted`, the fake being one database), and `.CKAccountChanged` comes later
/// (`simulateAccountChange`), or never in the test. A live engine over a temporary `InkPageStore` and
/// `InMemoryCloudDatabase`, `TestSleeper` for every sleep, a fixed clock. SyncEngineTests.swift stays as in 1.2.3;
/// the helpers below copy its own. TestSleeper's cautions (docs/R1_2_3.md §4.3) hold.
@MainActor
final class SyncEngineZoneAccountTests: XCTestCase {
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
            .appendingPathComponent("SyncEngineZoneAccountTests-\(UUID().uuidString)", isDirectory: true)
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

    private func count(_ op: InMemoryCloudDatabase.Operation) -> Int {
        db.calls.filter { $0 == op }.count
    }

    /// The `InkPage` records in iCloud (not `Meta`).
    private func inkNames() -> [String] {
        db.records.keys.filter { $0 != InkPageRecord.metaRecordName }.sorted()
    }

    /// Started and synced with `_user-a`; this device wrote the month page ("a") and the week page ("b"), and both
    /// went to iCloud.
    private func syncedWithTwoPages() async throws {
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced)
        try engine.save(page(month, ["a"]))
        await flushDebounce()
        try engine.save(page(week, ["b"]))
        await flushDebounce()
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(inkNames(), [month, week])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(sleeper.waiting, 0)
    }

    /// Lets the 1.5 s debounce pass and the push finish.
    private func flushDebounce() async {
        await engine.waitUntilIdle()
        await sleeper.advance()
        await engine.waitUntilIdle()
    }

    /// The Apple Account is another one now, as CloudKit answers: `_user-b`, whose iCloud has no zone of this app.
    /// `.CKAccountChanged` has not been handled (it comes with `lateAccountChange()`).
    private func switchedWithoutTheNotification() {
        db.simulateZoneDeleted()
        db.userName = "_user-b"
    }

    /// `.CKAccountChanged` for the switch, handled after everything above.
    private func lateAccountChange() async {
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await engine.waitUntilIdle()
    }

    /// Nothing of this device went to `_user-b`'s iCloud, the engine waits for the person's answer, and the ledger
    /// was not reset by a zone recovery (the pages are not marked to be sent again).
    private func nothingWentToTheOtherAccount(dirty: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(inkNames(), [], "no page of this device in the other account's iCloud", file: file, line: line)
        XCTAssertEqual(status, .accountMismatch, file: file, line: line)
        XCTAssertEqual(engine.state.account, "_user-a", file: file, line: line)
        XCTAssertEqual(engine.state.pendingAccount, "_user-b", file: file, line: line)
        XCTAssertEqual(engine.state.dirty, dirty, "the zone recovery did not run", file: file, line: line)
        XCTAssertNotNil(engine.state.zoneToken, "the zone recovery did not run", file: file, line: line)
    }

    /// Yields until `condition` holds (for work that is paused inside the fake, which `waitUntilIdle` would wait
    /// for forever). After 4000 yields it polls every millisecond for up to 5 s, as SyncEngineTests does.
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

    // MARK: - The single-page fetch

    /// The page fetch that finds the zone gone asks the account first: the switched account is found, nothing is
    /// made or sent in its iCloud, and the late `.CKAccountChanged` changes nothing. 「消して始める」 then starts
    /// with an empty device and an empty iCloud.
    ///
    /// Fails on 43fe366: the fetch runs the zone recovery at once (calls `[fetchRecords, ensureZone,
    /// ensureSubscription, fetchChanges, save, save]`), both pages of `_user-a` go to `_user-b`'s iCloud and the
    /// status is `.synced` until the late notification; after 「消して始める」 the first pull brings "a" and "b"
    /// back to the device (what run 43537716277 of the 1.3 screen tests showed).
    func testPageFetchThatFindsTheZoneGoneConfirmsTheAccountFirst() async throws {
        try await syncedWithTwoPages()
        switchedWithoutTheNotification()
        let mark = db.calls.count
        engine.pageOpened(week)
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchRecords, .accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [])

        await lateAccountChange()
        XCTAssertEqual(count(.ensureZone), 1, "only the first launch's zone")
        nothingWentToTheOtherAccount(dirty: [])

        // 「消して始める」: the device is emptied and the new account's iCloud has nothing of the old one.
        remoteUpdates = []
        await engine.resolveAccountChange(.eraseInk)
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.state.account, "_user-b")
        XCTAssertEqual(store.allPageIds(), [], "the old account's ink did not come back")
        XCTAssertEqual(remoteUpdates.map(\.pageId), [])
        XCTAssertEqual(inkNames(), [])
        XCTAssertEqual(status, .synced)
    }

    /// The same when the check cannot be made (offline): nothing is reset or sent, the retry checks first and finds
    /// the other account.
    ///
    /// Fails on 43fe366: the recovery runs without a check (`ensureZone` right after `fetchRecords`) and both pages
    /// go to `_user-b`.
    func testPageFetchThatFindsTheZoneGoneSendsNothingWhileTheCheckFails() async throws {
        try await syncedWithTwoPages()
        switchedWithoutTheNotification()
        db.failNext[.accountStatus] = .networkUnavailable
        let mark = db.calls.count
        engine.pageOpened(week)
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchRecords, .accountStatus])
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.recorded.last, 15)
        XCTAssertEqual(inkNames(), [])
        XCTAssertEqual(engine.state.dirty, [], "the zone recovery did not run")

        await sleeper.advance() // the retry: the check comes first
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchRecords, .accountStatus, .accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [])
    }

    /// The zone deleted while the account stays the same (the app's iCloud data deleted from another device): the
    /// page fetch confirms the account and then recovers as in 1.2.3 — every local page sent again.
    ///
    /// Fails on 43fe366 only at the order of the calls (no check before `ensureZone`); the recovery is the same.
    func testPageFetchRecoversTheZoneOfTheSameAccountAfterTheCheck() async throws {
        try await syncedWithTwoPages()
        db.simulateZoneDeleted()
        let mark = db.calls.count
        engine.pageOpened(week)
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchRecords, .accountStatus, .userRecordName,
                                                  .ensureZone, .ensureSubscription, .fetchChanges, .save, .save])
        XCTAssertEqual(inkNames(), [month, week])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
        XCTAssertTrue(engine.state.zoneReady)
        XCTAssertNotNil(engine.state.zoneToken)
    }

    // MARK: - The push without a pull

    /// A stroke written just before the switch: its 1.5 s push finds the zone gone and asks the account first;
    /// nothing goes to the other account, and only the written page stays to be sent.
    ///
    /// Fails on 43fe366: the push runs the zone recovery (calls `[save, ensureZone, ensureSubscription,
    /// fetchChanges, save, save]`), every page of this device goes to `_user-b`'s iCloud and the status is
    /// `.synced`.
    func testPushThatFindsTheZoneGoneConfirmsTheAccountFirst() async throws {
        try await syncedWithTwoPages()
        try engine.save(page(week, ["b", "c"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.waiting, 1)
        switchedWithoutTheNotification()
        let mark = db.calls.count
        await sleeper.advance() // the debounced push
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.save, .accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [week])

        await lateAccountChange()
        XCTAssertEqual(count(.ensureZone), 1, "only the first launch's zone")
        nothingWentToTheOtherAccount(dirty: [week])
    }

    /// The zone of the same account deleted elsewhere: the push confirms the account and recovers as in 1.2.3.
    ///
    /// Fails on 43fe366 only at the order of the calls (no check before `ensureZone`).
    func testPushRecoversTheZoneOfTheSameAccountAfterTheCheck() async throws {
        try await syncedWithTwoPages()
        try engine.save(page(week, ["b", "c"]))
        await engine.waitUntilIdle()
        db.simulateZoneDeleted()
        let mark = db.calls.count
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.save, .accountStatus, .userRecordName,
                                                  .ensureZone, .ensureSubscription, .fetchChanges, .save, .save])
        XCTAssertEqual(inkNames(), [month, week])
        XCTAssertEqual(try InkPageRecord.page(from: XCTUnwrap(db.records[week])).liveStrokeIds, ["b", "c"])
        XCTAssertEqual(engine.state.dirty, [])
        XCTAssertEqual(status, .synced)
    }

    // MARK: - What 1.2.3 already closes (G3), kept

    /// The order of an iPhone or a full-screen iPad: the account is switched in the Settings app while this app is
    /// in the background, the app comes back (`.active`) and a page is opened while the return's check is under
    /// way; `.CKAccountChanged` is handled last. The check finds the other account, the queued fetch asks nothing.
    /// Holds on 43fe366 too (G2, G3): kept so that the fix does not open it.
    func testReturnFromTheSettingsAppThenAPageFindsTheOtherAccountFirst() async throws {
        try await syncedWithTwoPages()
        engine.applicationDidEnterBackground()
        switchedWithoutTheNotification()
        let mark = db.calls.count
        db.pause(.accountStatus)
        engine.applicationDidBecomeActive()
        await waitUntil { self.db.calls.count > mark }
        engine.pageOpened(week) // passes the gate while the check is under way; queued behind the round trip
        db.resume()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [])

        await lateAccountChange()
        XCTAssertEqual(count(.fetchRecords), 0)
        nothingWentToTheOtherAccount(dirty: [])
    }

    /// The order of the 1.3 screen test (run 43537716277): a page is opened and, in the same instant, the account is
    /// switched to one without the zone and `.CKAccountChanged` is sent. Which of the fetch and the notification
    /// runs first is the executor's; either way nothing of this device goes to the other account.
    func testPageOpenedAsTheAccountChangesSendsNothingWhicheverComesFirst() async throws {
        try await syncedWithTwoPages()
        engine.pageOpened(week)
        db.simulateZoneDeleted()
        db.simulateAccountChange(status: .available, userName: "_user-b")
        await engine.waitUntilIdle()
        XCTAssertEqual(count(.ensureZone), 1, "only the first launch's zone")
        nothingWentToTheOtherAccount(dirty: [])

        await engine.resolveAccountChange(.eraseInk)
        await engine.waitUntilIdle()
        XCTAssertEqual(store.allPageIds(), [], "the old account's ink did not come back")
        XCTAssertEqual(inkNames(), [])
    }
}
