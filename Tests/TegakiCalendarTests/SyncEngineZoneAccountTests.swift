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
/// 「消して始める」 brought them back from there.
///
/// G4b (the review's findings G4-R1, G4-R2): the round trip's own zone recovery confirms the account too (an
/// `.inactive` return, 「今すぐ同期」, a retry timer; M4_CONTRACT §8.2 16, `SyncEngineTests.test16`), and so do the
/// other two signs of a switched account when the new account already has this app's zone (a record gone in the
/// push or in the import's `Meta`, a change token expired in the pull), and 「全て消す」 always checks before it lists
/// or deletes anything (§8.2 23, `SyncEngineTests.test23`). Still open, with no sign or a frozen test in the way
/// (docs/M7C.md, G4b): a page id both accounts have (a page opened, a conflict), a record never sent before. An iCloud
/// erase that failed after its check now confirms the account before it is retried (G4b-R1, §8.2 24, `test24`).
///
/// The switch is played as CloudKit sees it: `db.userName` is the new account and its iCloud has no zone of this app
/// (`simulateZoneDeleted`, the fake being one database), and `.CKAccountChanged` comes later
/// (`simulateAccountChange`), or never in the test. A live engine over a temporary `InkPageStore` and
/// `InMemoryCloudDatabase`, `TestSleeper` for every sleep, a fixed clock. SyncEngineTests.swift stays as in 1.2.3
/// except the call lists of test16, test23 and test24; the helpers below copy its own. TestSleeper's cautions (docs/R1_2_3.md §4.3) hold.
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

    // MARK: - G4b: the round trip's own zone recovery (G4-R1)

    /// The return to `.active` from `.inactive` only (no `.background`): a Mac window brought to the front again
    /// after the switch in System Settings (docs/R1_2_3.md §11.2), an iPad after Control Center, Notification
    /// Center, the app switcher or a system alert. No check is due (`SyncEngineTests.test47`); the round trip's
    /// pull finds the zone gone and asks the account before the recovery.
    ///
    /// Fails on 80d1ab0 (g4-fix round 1) and 43fe366: calls `[fetchChanges, ensureZone, ensureSubscription,
    /// fetchChanges, save, save]`, both pages in `_user-b`'s iCloud, and 「消して始める」 brings them back.
    func testInactiveReturnAfterTheSwitchConfirmsTheAccountFirst() async throws {
        try await syncedWithTwoPages()
        switchedWithoutTheNotification()
        let mark = db.calls.count
        engine.applicationDidBecomeActive()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [])

        await lateAccountChange()
        nothingWentToTheOtherAccount(dirty: [])
        await engine.resolveAccountChange(.eraseInk)
        await engine.waitUntilIdle()
        XCTAssertEqual(store.allPageIds(), [], "the old account's ink did not come back")
        XCTAssertEqual(inkNames(), [])
        XCTAssertEqual(status, .synced)
    }

    /// 「今すぐ同期」 after the switch. Fails on 80d1ab0 and 43fe366 as above.
    func testSyncNowAfterTheSwitchConfirmsTheAccountFirst() async throws {
        try await syncedWithTwoPages()
        switchedWithoutTheNotification()
        let mark = db.calls.count
        await engine.syncNow()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [])
    }

    /// A backoff retry timer (an earlier pull failed offline in the foreground) that fires after the switch.
    /// Fails on 80d1ab0 and 43fe366 as above.
    func testRetryTimerAfterTheSwitchConfirmsTheAccountFirst() async throws {
        try await syncedWithTwoPages()
        db.failNext[.fetchChanges] = .networkUnavailable
        await engine.syncNow()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.waiting, 1)
        switchedWithoutTheNotification()
        let mark = db.calls.count
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .accountStatus, .userRecordName])
        nothingWentToTheOtherAccount(dirty: [])
    }

    // MARK: - G4b: a new account that already has this app's zone (G4-R2)

    /// The other account's own page in its iCloud (it used the app on another device).
    private let otherPage = "w-2026-11-02"

    /// The Apple Account is `_user-b` now, whose iCloud has this app's zone with its own week page ("bee") and none
    /// of this device's records (the fake being one database). `.CKAccountChanged` has not been handled.
    private func switchedIntoAnExistingZoneWithoutTheNotification() throws {
        db.userName = "_user-b"
        db.records = [:]
        db.simulateRemoteSave(try InkPageRecord.make(page(otherPage, ["bee"]), seen: nil))
        XCTAssertEqual(inkNames(), [otherPage])
    }

    /// The other account's iCloud is as it was, and the engine waits for the person's answer.
    private func theOtherAccountIsUntouched(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(inkNames(), [otherPage], "nothing of this device in the other account's iCloud", file: file, line: line)
        XCTAssertEqual(try InkPageRecord.page(from: XCTUnwrap(db.records[otherPage])).liveStrokeIds, ["bee"], file: file, line: line)
        XCTAssertEqual(status, .accountMismatch, file: file, line: line)
        XCTAssertEqual(engine.state.account, "_user-a", file: file, line: line)
        XCTAssertEqual(engine.state.pendingAccount, "_user-b", file: file, line: line)
    }

    /// The 1.5 s push of two written pages meets `.recordNotFound` (a sign of a switched account, docs/R1_2_3.md
    /// §3.6) and asks the account before it makes any record again.
    ///
    /// Fails on 80d1ab0 and 43fe366: calls `[save, save, save, save]`, both pages made in `_user-b`'s iCloud.
    func testPushIntoAnotherAccountsZoneConfirmsTheAccountFirst() async throws {
        try await syncedWithTwoPages()
        try engine.save(page(month, ["a", "x"]))
        try engine.save(page(week, ["b", "c"]))
        await engine.waitUntilIdle()
        XCTAssertEqual(sleeper.waiting, 1)
        try switchedIntoAnExistingZoneWithoutTheNotification()
        let mark = db.calls.count
        // The debounced push (the second save moved the debounce on: it sleeps once more).
        while db.calls.count == mark, sleeper.waiting > 0 {
            await sleeper.advance()
            await engine.waitUntilIdle()
        }
        XCTAssertEqual(Array(db.calls[mark...]), [.save, .accountStatus, .userRecordName])
        theOtherAccountIsUntouched()
        XCTAssertEqual(engine.state.dirty, [month, week])
    }

    /// The round trip's pull meets an expired change token (another account's zone, docs/R1_2_3.md §2 M3) and asks
    /// the account before it fetches and merges that zone's records.
    ///
    /// Fails on 80d1ab0 and 43fe366: the other account's page is merged into this device and the status is `.synced`.
    func testExpiredTokenInAnotherAccountsZoneMergesNothing() async throws {
        try await syncedWithTwoPages()
        try switchedIntoAnExistingZoneWithoutTheNotification()
        db.expireToken()
        let mark = db.calls.count
        await engine.syncNow()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.fetchChanges, .accountStatus, .userRecordName])
        theOtherAccountIsUntouched()
        XCTAssertEqual(store.allPageIds(), [month, week], "the other account's page was not merged here")
        XCTAssertEqual(remoteUpdates, [])
    }

    /// 「Web 版の手書きを取り込む」 after the switch, before the notification: `Meta` (saved with `_user-a`'s tag)
    /// meets `.recordNotFound` and the account is asked before `Meta` is made again; the imported page is not sent.
    ///
    /// Fails on 1b838f2 and 43fe366: calls `[save, save, save]`, `Meta` and the imported page made in `_user-b`'s iCloud.
    func testImportAfterTheSwitchWritesNothingThere() async throws {
        try await syncedWithTwoPages()
        _ = try await engine.importPages([page("d-2026-10-07", ["web1"])]) { _, _ in }
        await flushDebounce()
        XCTAssertNotNil(db.records[InkPageRecord.metaRecordName])
        XCTAssertEqual(status, .synced)
        try switchedIntoAnExistingZoneWithoutTheNotification()
        let mark = db.calls.count
        _ = try await engine.importPages([page("d-2026-10-08", ["web2"])]) { _, _ in }
        await flushDebounce()
        XCTAssertEqual(Array(db.calls[mark...]), [.save, .accountStatus, .userRecordName])
        XCTAssertNil(db.records[InkPageRecord.metaRecordName], "no Meta in the other account's iCloud")
        theOtherAccountIsUntouched()
    }

    /// The same account whose `Meta` is gone (its iCloud data was deleted elsewhere): after the check `Meta` is made
    /// again, as before G4b.
    func testImportMakesMetaAgainInTheSameAccountAfterTheCheck() async throws {
        try await syncedWithTwoPages()
        _ = try await engine.importPages([page("d-2026-10-07", ["web1"])]) { _, _ in }
        await flushDebounce()
        db.simulateRemoteDelete(InkPageRecord.metaRecordName)
        let mark = db.calls.count
        _ = try await engine.importPages([page("d-2026-10-08", ["web2"])]) { _, _ in }
        await flushDebounce()
        XCTAssertEqual(Array(db.calls[mark...]), [.save, .accountStatus, .userRecordName, .save, .save])
        XCTAssertNotNil(db.records[InkPageRecord.metaRecordName])
        XCTAssertNotNil(db.records["d-2026-10-08"])
        XCTAssertEqual(status, .synced)
    }

    // MARK: - G4b: 「全て消す」 and the account (G4-R2 (c))

    /// 「全て消す」 after the switch, before the notification: the erase confirms the account first, finds the other
    /// one and lists and deletes nothing there. The iCloud deletion stays pending for `_user-a`.
    ///
    /// Fails on 80d1ab0 and 43fe366: calls `[fetchChanges, delete, fetchChanges]`, the other account's page deleted.
    private func erasedAfterTheSwitch() async throws {
        try await syncedWithTwoPages()
        try switchedIntoAnExistingZoneWithoutTheNotification()
        let mark = db.calls.count
        do {
            try await engine.eraseEverything()
            XCTFail("the iCloud part of the erase is not done")
        } catch {
            XCTAssertEqual(error as? CloudError, .other("account"))
        }
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName])
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertTrue(engine.state.pendingCloudErase)
        theOtherAccountIsUntouched()

        await lateAccountChange()
        XCTAssertEqual(count(.delete), 0)
        theOtherAccountIsUntouched()
    }

    /// 「全て消す」 passed its check in `_user-a`, then its iCloud part failed (offline), then the switch with a late
    /// notification: the retry (the backoff timer here; 「今すぐ同期」 and an `.inactive` return run the same round trip)
    /// confirms the account before it lists or deletes anything, and the deletion stays pending for `_user-a`.
    ///
    /// Fails on dcc5fec and 43fe366: calls `[fetchChanges, delete, fetchChanges, fetchChanges]`, the other account's
    /// page deleted, the status synced (the review's G4b-R1).
    func testEraseRetriedAfterTheSwitchDeletesNothingThere() async throws {
        try await syncedWithTwoPages()
        db.failNext[.delete] = .networkUnavailable
        do {
            try await engine.eraseEverything()
            XCTFail("the iCloud part of the erase is not done")
        } catch {
            XCTAssertEqual(error as? CloudError, .networkUnavailable)
        }
        await engine.waitUntilIdle()
        XCTAssertTrue(engine.state.pendingCloudErase)
        XCTAssertEqual(status, .offline)
        XCTAssertEqual(sleeper.waiting, 1)

        try switchedIntoAnExistingZoneWithoutTheNotification()
        let mark = db.calls.count
        await sleeper.advance()
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...]), [.accountStatus, .userRecordName])
        XCTAssertTrue(engine.state.pendingCloudErase)
        XCTAssertTrue(stateStore.load().pendingCloudErase)
        theOtherAccountIsUntouched()

        await lateAccountChange()
        XCTAssertFalse(db.calls[mark...].contains(.delete))
        theOtherAccountIsUntouched()
    }

    /// 「消して始める」: the pending deletion belonged to `_user-a` and is dropped; the other account's page comes to
    /// this device and stays in its iCloud; nothing waits or retries.
    func testEraseAfterTheSwitchThenEraseInkDeletesNothingThere() async throws {
        try await erasedAfterTheSwitch()
        await engine.resolveAccountChange(.eraseInk)
        await engine.waitUntilIdle()
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertFalse(stateStore.load().pendingCloudErase)
        XCTAssertEqual(count(.delete), 0)
        XCTAssertEqual(inkNames(), [otherPage])
        XCTAssertEqual(store.allPageIds(), [otherPage])
        XCTAssertEqual(engine.state.account, "_user-b")
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(sleeper.waiting, 0)
    }

    /// 「残して始める」: the same; this device (empty after the erase) is adopted by `_user-b`, whose page stays.
    func testEraseAfterTheSwitchThenKeepInkDeletesNothingThere() async throws {
        try await erasedAfterTheSwitch()
        await engine.resolveAccountChange(.keepInk)
        await engine.waitUntilIdle()
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertFalse(stateStore.load().pendingCloudErase)
        XCTAssertEqual(count(.delete), 0)
        XCTAssertEqual(inkNames(), [otherPage])
        XCTAssertEqual(store.allPageIds(), [otherPage])
        XCTAssertEqual(engine.state.account, "_user-b")
        XCTAssertEqual(status, .synced)
        XCTAssertEqual(sleeper.waiting, 0)
    }

    /// 「あとで」, then the Apple Account is `_user-a` again: the pending deletion runs in `_user-a`'s iCloud, the
    /// account it was made for, once that account is confirmed.
    func testEraseAfterTheSwitchRunsWhenTheFirstAccountComesBack() async throws {
        try await erasedAfterTheSwitch()
        await engine.resolveAccountChange(.later)
        db.records = [:]
        db.simulateRemoteSave(try InkPageRecord.make(page(month, ["a"]), seen: nil))
        db.simulateRemoteSave(try InkPageRecord.make(page(week, ["b"]), seen: nil))
        let mark = db.calls.count
        db.simulateAccountChange(status: .available, userName: "_user-a")
        await engine.waitUntilIdle()
        XCTAssertEqual(Array(db.calls[mark...].prefix(4)), [.accountStatus, .userRecordName, .fetchChanges, .delete])
        XCTAssertEqual(inkNames(), [])
        XCTAssertEqual(store.allPageIds(), [])
        XCTAssertFalse(engine.state.pendingCloudErase)
        XCTAssertNil(engine.state.pendingAccount)
        XCTAssertEqual(status, .synced)
    }
}
