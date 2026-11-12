import Combine
import Foundation
import InkModel

/// The iCloud sync engine (M4_CONTRACT §4.4, §4.5, DESIGN §5; the web version's ink-store.js is the
/// reference for how it behaves). The files on the device are the authority; iCloud is the way to
/// the other devices and a backup. The engine owns the `InkPageStore` (the screen saves and loads
/// through `save` / `load`), keeps the dirty ledger in `ink/state.json`, pushes 1.5 s after the last
/// save, pulls on start / foreground / silent push, retries from 15 s doubling up to 5 minutes, and
/// never mixes the data of two iCloud accounts.
///
/// All cloud work runs through one serial queue (`enqueue`), so a pull and a push never overlap;
/// requests that arrive while a round trip runs queue one more round trip after it.
@MainActor
final class SyncEngine: ObservableObject {
    /// The engine the app uses (§4.4): the screenshot mode and the XCTest host get an inert engine
    /// over the fake, `--no-icloud` a live engine over the fake, everything else the real CloudKit.
    /// Only the last branch ever makes a `CKContainer`.
    static let shared: SyncEngine = {
        if ScreenshotMode.isActive, let config = ScreenshotMode.current {
            return screenshotDemo(now: config.today)
        }
        if isTestHost {
            return screenshotDemo(now: Date())
        }
        if CommandLine.arguments.contains("--no-icloud") {
            return live(database: InMemoryCloudDatabase())
        }
        return live()
    }()

    /// True when this process hosts XCTest (`XCTestCase` is loaded, or XCTest's environment is set).
    nonisolated static var isTestHost: Bool {
        if NSClassFromString("XCTestCase") != nil { return true }
        let environment = ProcessInfo.processInfo.environment
        for key in ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"] where environment[key] != nil {
            return true
        }
        return false
    }

    /// True only when `shared` is the live engine over CloudKit; the AppDelegate registers for
    /// remote notifications only then (§6.7).
    nonisolated static var usesCloudKit: Bool {
        !ScreenshotMode.isActive && !isTestHost && !CommandLine.arguments.contains("--no-icloud")
    }

    static func live(database: any CloudDatabase = CloudKitDatabase()) -> SyncEngine {
        let engine = SyncEngine(store: InkPageStore(), stateStore: SyncStateStore(), database: database)
        // 1.2.3 (docs/R1_2_3.md §3, G3): until the first `applicationDidBecomeActive()` the app may be a
        // background launch (a silent push); every round trip confirms the account until then.
        engine.awayFromForeground = true
        return engine
    }

    /// The engine of the screenshot mode and of the XCTest host (§6.6): 「保存済み」 three minutes ago,
    /// and `start` / `save` / `pageOpened` / `syncNow` do nothing (no file, no database).
    static func screenshotDemo(now: Date) -> SyncEngine {
        let engine = SyncEngine(store: InkPageStore(), stateStore: SyncStateStore(), database: InMemoryCloudDatabase(), clock: { now })
        engine.inactive = true
        engine.snapshot = SyncSnapshot(status: .synced, lastSyncAt: now.addingTimeInterval(-SyncEngine.demoLastSyncOffset), dirtyCount: 0, webImportedAt: nil)
        return engine
    }

    /// `screenshotDemo` shows the last sync this long before `now` (10:00 − 3 min = 9:57).
    static let demoLastSyncOffset: TimeInterval = 180

    @Published private(set) var snapshot = SyncSnapshot(status: .pending, lastSyncAt: nil, dirtyCount: 0, webImportedAt: nil)

    /// Called with the merged page when a page changed from iCloud (or an import). The screen
    /// ignores pages it is not showing (§5.4).
    var onRemoteUpdate: ((InkPage) -> Void)?

    /// 1.3 (docs/M7C_CONTRACT.md §7, D5): called with the page id when the pull finds that page's record
    /// deleted in iCloud (another device's 「全て消す」), right after `onRemoteUpdate` was given the empty page,
    /// which stays. Never for the `Meta` record. Only the pull calls it; nothing here deletes because of it (a
    /// deletion is still made by `cloudErase` alone), and the inert engine never pulls. nil, as in 1.2.3,
    /// changes nothing.
    var onRemoteDelete: ((String) -> Void)?

    let store: InkPageStore
    let stateStore: SyncStateStore
    let database: any CloudDatabase

    /// The ledger (§1.1). Internal so the tests can look at it.
    private(set) var state: SyncState = .empty

    private let clock: () -> Date
    /// @MainActor (1.2.3, docs/R1_2_3.md §4): a sleep that returns goes on to `pause`'s `beginJob()` without
    /// leaving the main actor, so the tests' `TestSleeper.advance()` sees the woken task counted again.
    private let sleep: @MainActor (TimeInterval) async -> Void

    /// `screenshotDemo`: everything is a no-op.
    private var inactive = false
    private var started = false
    /// `start()` has read the state file; before that, dirty marks stay in memory only.
    private var stateLoaded = false
    private var backoff = SyncBackoff()
    /// Bumped by every `save` of a page; `push` clears the dirty mark only when it did not move.
    private var pageGeneration: [String: Int] = [:]
    /// The time of the last `pageOpened` fetch per page (the 30 s cooldown).
    private var lastPageFetch: [String: Date] = [:]
    /// Asks for a fresh account check in the next round trip: the launch, `.CKAccountChanged`, and since
    /// 1.2.3 a check that gave no clear answer, the account choice, the return from the background and a
    /// silent push (docs/R1_2_3.md §3).
    private var accountCheckRequested = false
    /// Bumped by the erase, the account choice and, since 1.2.3, `.CKAccountChanged` and the return from
    /// the background; work started under an older epoch stops before its next request or write.
    private var workEpoch = 0
    /// 1.2.3 (docs/R1_2_3.md §3, G3): true from `applicationDidEnterBackground()` until the next
    /// `applicationDidBecomeActive()`, and in the app (`live()`) from launch until the first one. While true
    /// every round trip confirms the account first: an Apple Account is switched in the Settings app, i.e.
    /// while this app is in the background or suspended, and `.CKAccountChanged` can reach the engine after
    /// the timers that elapsed meanwhile, a silent push or the foreground round trip. A check made in the
    /// background does not clear it (the switch can come after that check). The tests' engines start in the
    /// foreground (false).
    private var awayFromForeground = false
    /// 1.2.3: when the last check that confirmed the account was asked (`clock()`); see `checkStillFresh()`.
    private var accountCheckedAt: Date?

    /// 1.2.3 (docs/R1_2_3.md §3): while away from the foreground, a round trip whose last account check is
    /// older than this stops before its next request and queues one that checks first (a round trip that
    /// iOS froze and that goes on when the app wakes, maybe after the Apple Account was switched). A round
    /// trip in the background normally ends within a second or two of its check.
    static let awayRecheckAfter: TimeInterval = 10

    // The one debounce task and the one retry task (§4.5): a task whose epoch moved does nothing.
    private var debounceGeneration = 0
    private var debounceEpoch = 0
    private var debounceTask: Task<Void, Never>?
    private var retryEpoch = 0
    private var retryTask: Task<Void, Never>?
    private var accountTask: Task<Void, Never>?

    // The serial queue and the idle bookkeeping (§4.4 `waitUntilIdle`).
    private var queueTail: Task<Void, Never>?
    private var pendingCycle: Task<Int, Never>?
    private var activeJobs = 0
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        store: InkPageStore,
        stateStore: SyncStateStore,
        database: any CloudDatabase,
        clock: @escaping () -> Date = Date.init,
        sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.store = store
        self.stateStore = stateStore
        self.database = database
        self.clock = clock
        self.sleep = sleep
    }

    // MARK: - The store (§5.3)

    /// `store.load` (no sync). The inert engine returns an empty page.
    func load(_ pageId: String) -> InkPage {
        if inactive { return InkPage.empty(pageId: pageId) }
        return store.load(pageId)
    }

    /// Merges `page` with the file (a remote update the screen missed is never lost; tombstones keep
    /// deletions), writes the file, queues the page and pushes 1.5 s later (§4.5 2). A failure to
    /// write the file is thrown (the screen shows 「手書きを保存できませんでした」); a failure to
    /// write the state file is only recorded (the dirty mark stays in memory and `start()` of the
    /// next launch queues every page the ledger does not know).
    func save(_ page: InkPage) throws {
        guard !inactive else { return }
        let id = page.pageId
        let merged = InkPage.merge(store.load(id), page)
        try store.save(merged)
        if merged.contentDiffers(from: page) {
            onRemoteUpdate?(merged)
        }
        pageGeneration[id, default: 0] += 1
        state.markDirty(id)
        if snapshot.status == .synced {
            setStatus(.pending)
        }
        persistState()
        switch snapshot.status {
        case .localOnly, .accountMismatch:
            return // queued only; sent once an account is confirmed
        default:
            scheduleDebouncedPush()
        }
    }

    /// Fetches that one page (`fetchRecords`) unless it was fetched within the last 30 s, and
    /// merges what is newer (§4.5 3).
    func pageOpened(_ pageId: String) {
        guard !inactive, started else { return }
        switch snapshot.status {
        case .synced, .pending, .offline, .error:
            break
        default:
            return
        }
        // 1.2.3 (docs/R1_2_3.md §3, G2): no single-page fetch while the account is unconfirmed or a check is
        // due (the next pull brings the page anyway). Before the cooldown, so the page is fetched when it is
        // opened again after the check. 1.2.4: nor while the iCloud half of 「全て消す」 is pending (§4.5 10:
        // nothing is pulled before it is done; the record still in iCloud would bring the erased ink back).
        guard !needsAccountCheck, !state.pendingCloudErase else { return }
        let now = clock()
        if let last = lastPageFetch[pageId], now.timeIntervalSince(last) < SyncBackoff.pageFetchCooldown {
            return
        }
        lastPageFetch[pageId] = now
        enqueue { await self.fetchPage(pageId) }
    }

    func allLocalPageIds() -> [String] {
        store.allPageIds()
    }

    // MARK: - Commands (§4.4)

    /// Once per launch (the AppDelegate). Reads the ledger, queues every local page it does not know,
    /// subscribes to account changes and queues the first round trip. A second call does nothing.
    func start() {
        guard !inactive, !started else { return }
        started = true
        let early = state.dirty
        var loaded = stateStore.load()
        for id in early { loaded.markDirty(id) }
        for id in store.allPageIds() where loaded.seen[id] == nil { loaded.markDirty(id) }
        state = loaded
        stateLoaded = true
        persistState()
        // The first round trip of a launch always confirms the account (a sign-out while the app
        // was not running sends no `.CKAccountChanged`); `accountStatus()` is cheap.
        accountCheckRequested = true
        CloudKitDatabase.clearUploadDirectory()
        let database = self.database
        accountTask = Task { @MainActor [weak self] in
            for await _ in database.accountChanges {
                guard let self = self else { return }
                self.accountChanged()
                // Tests (§8.2): `waitUntilIdle` waits until every change the fake sent has been handled.
                // (`accountChanged()` always queues a round trip, so this wakes nobody; kept as a guard.)
                self.accountChangesHandled += 1
                self.wakeIdleWaitersIfIdle()
            }
        }
        enqueueCycle()
    }

    /// 「今すぐ同期」, foreground, silent push: one round trip now, without the debounce (§4.5 6).
    func syncNow() async {
        guard !inactive, started else { return }
        cancelDebounce()
        cancelRetry()
        _ = await enqueueCycle().value
    }

    /// 1.2.3 (docs/R1_2_3.md §3, G3): scenePhase `.background` (CalendarRootScreen). Every round trip
    /// confirms the account until the next `applicationDidBecomeActive()`, which asks for one more check.
    func applicationDidEnterBackground() {
        guard !inactive, started else { return }
        awayFromForeground = true
    }

    func applicationDidBecomeActive() {
        guard !inactive, started else { return }
        if awayFromForeground {
            // 1.2.3 (G3): back from the background. Work that iOS froze stops at its next epoch check, and
            // the first round trip confirms the account, whatever arrives first (this call, an elapsed
            // timer, `.CKAccountChanged`).
            awayFromForeground = false
            accountCheckRequested = true
            workEpoch += 1
        }
        // Counted (spawn), so `waitUntilIdle` waits for it (§8.2).
        spawn { await self.syncNow() }
    }

    /// A silent push (§4.5 7): false at once unless it is our zone subscription; otherwise a round
    /// trip is queued and this returns within 20 s (`SyncBackoff.notificationBudget`): true when
    /// the pull brought at least one change in that time. The round trip goes on either way.
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard !inactive, started else { return false }
        guard database.subscriptionID(in: userInfo) == CloudKitDatabase.subscriptionID else { return false }
        // 1.2.3 (docs/R1_2_3.md §3, G3): a silent push often wakes the app from suspension, before
        // `.CKAccountChanged`: the round trip confirms the account first, and in the background the work
        // that iOS froze stops at its next epoch check.
        accountCheckRequested = true
        if awayFromForeground {
            workEpoch += 1
        }
        cancelDebounce()
        cancelRetry()
        let cycle = enqueueCycle()
        var finished = false
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            spawn {
                let changes = await cycle.value
                guard !finished else { return }
                finished = true
                continuation.resume(returning: changes > 0)
            }
            spawn {
                await self.pause(SyncBackoff.notificationBudget)
                guard !finished else { return }
                finished = true
                continuation.resume(returning: false)
            }
        }
    }

    /// The answer to 「別の iCloud アカウントです」 (§4.5 9).
    func resolveAccountChange(_ choice: AccountChangeChoice) async {
        guard !inactive, started, let pending = state.pendingAccount else { return }
        switch choice {
        case .keepInk:
            workEpoch += 1
            state.adoptAccount(pending, allLocalPageIds: store.allPageIds())
            // 1.2.3 (docs/R1_2_3.md §3): an iCloud erase that was pending belonged to the previous account;
            // it is never done in the new one (M4.md §4.1: no records of another account are deleted later).
            state.pendingCloudErase = false
            pageGeneration = [:]
            persistState()
            setStatus(.pending)
            // 1.2.3: the name adopted is the one of the last check; the round trip confirms it again first.
            accountCheckRequested = true
            _ = await enqueueCycle().value
        case .eraseInk:
            workEpoch += 1
            cancelDebounce()
            cancelRetry()
            try? store.removeAll()
            var fresh = SyncState.empty
            fresh.account = pending
            state = fresh
            pageGeneration = [:]
            lastPageFetch = [:]
            persistState()
            setStatus(.pending)
            // 1.2.3: as `.keepInk`, the adopted name is confirmed again before anything is fetched.
            accountCheckRequested = true
            _ = await enqueueCycle().value
        case .later:
            break
        }
    }

    /// 「この iPad の手書きを全て消す」 (§4.5 10): every file on the device, then every `InkPage` in
    /// iCloud (200 at a time). A failure on the iCloud side is thrown; `pendingCloudErase` stays
    /// set, and the next round trip finishes the deletion before it pulls anything.
    func eraseEverything() async throws {
        guard !inactive else { return }
        cancelDebounce()
        cancelRetry()
        workEpoch += 1
        try store.removeAll()
        pageGeneration = [:]
        lastPageFetch = [:]
        let cloud = started && cloudUsable
        state.resetAfterErase(cloudPending: cloud)
        persistState()
        guard cloud else { return }
        let outcome = enqueue { () -> Error? in
            // 1.2.3 (docs/R1_2_3.md §3, G2): nothing is deleted from an account that was not confirmed, nor
            // after an account change during the check. The deletion stays pending (`pendingCloudErase`) for
            // the round trip after the check; the screen says the iCloud part failed. The status is the check's.
            let epoch = self.workEpoch
            guard await self.confirmedForSending() else { return CloudError.other("account") }
            do {
                try await self.cloudErase(epoch: epoch)
                self.finishRoundTrip()
                return nil
            } catch is Interrupted {
                // An account change (or the return from the background) stopped it; the round trip queued
                // with it sets the status.
                return CloudError.other("account")
            } catch {
                let cloudError = SyncEngine.cloudError(error)
                self.handleFailure(cloudError)
                return cloudError
            }
        }
        if let error = await outcome.value {
            throw error
        }
    }

    /// 「Web 版の手書きを取り込む」 (§4.5 11): merges every page into the files, counts what changed,
    /// records the time (state and `Meta`) and pushes without the debounce.
    func importPages(_ pages: [InkPage], progress: @escaping (_ done: Int, _ total: Int) -> Void) async throws -> ImportOutcome {
        var outcome = ImportOutcome(pagesChanged: 0, strokesAdded: 0, pagesSeen: pages.count)
        guard !inactive else { return outcome }
        let total = pages.count
        for (index, page) in pages.enumerated() {
            let id = page.pageId
            let local = store.load(id)
            let merged = InkPage.merge(local, page)
            if merged.contentDiffers(from: local) {
                try store.save(merged)
                pageGeneration[id, default: 0] += 1
                state.markDirty(id)
                outcome.pagesChanged += 1
                outcome.strokesAdded += Set(merged.liveStrokeIds).subtracting(local.liveStrokeIds).count
                onRemoteUpdate?(merged)
            }
            progress(index + 1, total)
            await Task.yield()
        }
        let now = clock()
        state.webImportedAt = InkPageRecord.ms(from: now)
        persistState()
        if started, cloudUsable, accountConfirmed {
            _ = await enqueue {
                // 1.2.3 (G2): the check that is due is made first; no `Meta` to an unconfirmed account.
                let epoch = self.workEpoch
                guard await self.confirmedForSending() else { return }
                await self.saveMeta(webImportedAt: now, epoch: epoch)
            }.value
        }
        if snapshot.status == .synced, state.isDirty {
            setStatus(.pending)
        }
        enqueuePush()
        return outcome
    }

    // MARK: - Tests (§8.2)

    /// `.CKAccountChanged` notifications handled so far (the account stream is not a counted job).
    private(set) var accountChangesHandled = 0

    /// Waits until every task of the engine has finished, except the ones suspended in `sleep`, and (over
    /// the fake) until every account change it sent has been handled. 1.2.3: no `Task.yield` grace any
    /// more: `TestSleeper.advance()` returns only after each woken task is counted again
    /// (docs/R1_2_3.md §4). New work of the engine must be counted (`enqueue` / `spawn`, never a bare `Task`).
    func waitUntilIdle() async {
        while activeJobs > 0 || (accountTask != nil && accountChangesHandled < accountChangesSentByFake) {
            await withCheckedContinuation { continuation in
                idleWaiters.append(continuation)
            }
        }
    }

    private var accountChangesSentByFake: Int {
        (database as? InMemoryCloudDatabase)?.accountChangesSent ?? 0
    }

    // MARK: - The round trip (§4.5)

    private enum Work {
        case cycle, pushOnly
    }

    private struct Interrupted: Error {}

    /// A round trip; returns how many changes the pull brought (for the silent push).
    private func run(_ work: Work) async -> Int {
        guard started else { return 0 }
        let epoch = workEpoch
        switch work {
        case .cycle:
            if needsAccountCheck {
                guard await checkAccount() else { return 0 }
            }
        case .pushOnly:
            // 1.2.3 (docs/R1_2_3.md §3, G2): a push queued before an account change, after a failed check or
            // across the background confirms the account first; nothing goes to an account not confirmed.
            guard await confirmedForSending() else { return 0 }
        }
        do {
            // 1.2.3 (M1): an account change (or the return from the background) during the check stops the
            // round trip here, before the pending erase; the round trip queued with it checks again.
            try checkEpoch(epoch)
            if state.pendingCloudErase {
                try await cloudErase(epoch: epoch)
            }
            try checkEpoch(epoch)
            if work == .cycle {
                await ensureZoneAndSubscription()
                try checkEpoch(epoch)
            }
            var pulled = 0
            var gaveUp = false
            do {
                if work == .cycle {
                    pulled = try await pull(epoch: epoch)
                }
                gaveUp = try await push(epoch: epoch)
            } catch CloudError.zoneMissing {
                try checkEpoch(epoch)
                // 1.2.3 (M3): a zone that is missing is what a switched account looks like; while a check is
                // due the account is confirmed before every local page is sent again.
                try await confirmAgainIfDue(epoch)
                let recovered = try await recoverFromZoneLoss(epoch: epoch)
                pulled += recovered.pulled
                gaveUp = recovered.gaveUp
            }
            try checkEpoch(epoch)
            if gaveUp {
                setStatus(.pending)
                scheduleBackoffRetry(serverHint: nil)
            } else {
                finishRoundTrip()
                if pushAgain {
                    // A save arrived while its page was being sent: once more, without the debounce.
                    pushAgain = false
                    enqueuePush()
                }
            }
            return pulled
        } catch is Interrupted {
            return 0
        } catch {
            handleFailure(SyncEngine.cloudError(error))
            return 0
        }
    }

    /// Set by `push` when a page's generation moved while it was being sent: one more push, no debounce.
    private var pushAgain = false

    private func checkEpoch(_ epoch: Int) throws {
        if epoch != workEpoch { throw Interrupted() }
    }

    private var needsAccountCheck: Bool {
        if accountCheckRequested || awayFromForeground { return true }
        if state.account == nil || state.pendingAccount != nil { return true }
        switch snapshot.status {
        case .localOnly, .accountMismatch:
            return true
        default:
            return false
        }
    }

    /// 1.2.3 (docs/R1_2_3.md §3, G2): the gate of the work outside the cycle (the push without a pull, the
    /// import's `Meta`, the erase): true when the account is confirmed, after the check that is due (launch,
    /// `.CKAccountChanged`, a failed check, the background) has been made, and no account change came during
    /// that check. An account that was never confirmed is false here: only the cycle confirms it.
    private func confirmedForSending() async -> Bool {
        guard accountConfirmed else { return false }
        guard needsAccountCheck else { return true }
        let epoch = workEpoch
        guard await checkAccount() else { return false }
        return epoch == workEpoch
    }

    /// 1.2.3 (docs/R1_2_3.md §3): a sign that the account may have been switched (the zone or the change
    /// token gone, a record gone) while a check is due: the account is confirmed before anything more is
    /// sent or merged. Not confirmed → `Interrupted` (the check has set the status and any retry).
    private func confirmAgainIfDue(_ epoch: Int) async throws {
        guard needsAccountCheck else { return }
        guard await checkAccount() else { throw Interrupted() }
        try checkEpoch(epoch)
    }

    /// 1.2.3 (docs/R1_2_3.md §3): before each request a round trip sends while away from the foreground. When
    /// the last check is older than `awayRecheckAfter` (the round trip was frozen by iOS and goes on after
    /// waking), it stops and queues a round trip that checks first.
    private func checkStillFresh() throws {
        guard awayFromForeground else { return }
        if let checkedAt = accountCheckedAt, abs(clock().timeIntervalSince(checkedAt)) <= SyncEngine.awayRecheckAfter {
            return
        }
        accountCheckRequested = true
        enqueueCycle()
        throw Interrupted()
    }

    private var accountConfirmed: Bool {
        guard state.account != nil, state.pendingAccount == nil else { return false }
        switch snapshot.status {
        case .localOnly, .accountMismatch:
            return false
        default:
            return true
        }
    }

    /// iCloud can be reached in principle (the account is confirmed): synced / pending / syncing /
    /// offline / error.
    private var cloudUsable: Bool {
        switch snapshot.status {
        case .synced, .pending, .syncing, .offline, .error:
            return true
        case .localOnly, .accountMismatch:
            return false
        }
    }

    /// `accountStatus()` → `userRecordName()`; true when the account is confirmed and the round trip
    /// may go on (§4.5 「アカウント確認」, 8).
    private func checkAccount() async -> Bool {
        // 1.2.3 (docs/R1_2_3.md §3, G1): cleared now so that a `.CKAccountChanged` arriving during the check
        // asks again; put back on every way out that neither confirmed nor rejected the account, so the next
        // round trip (retry, foreground, debounced push, import, erase) checks again instead of talking to an
        // account that was never confirmed in this launch.
        accountCheckRequested = false
        // When the question was asked: an answer is only as new as the question (see below and `checkStillFresh()`).
        let askedAt = clock()
        let accountStatus: CloudAccountStatus
        do {
            accountStatus = try await database.accountStatus()
        } catch {
            accountCheckRequested = true
            handleFailure(SyncEngine.cloudError(error))
            return false
        }
        switch accountStatus {
        case .noAccount:
            setStatus(.localOnly(.noAccount))
            return false
        case .restricted:
            setStatus(.localOnly(.restricted))
            return false
        case .couldNotDetermine:
            setStatus(.localOnly(.unknown))
            return false
        case .temporarilyUnavailable:
            accountCheckRequested = true
            scheduleBackoffRetry(serverHint: nil)
            return false
        case .available:
            break
        }
        let name: String
        do {
            name = try await database.userRecordName()
        } catch {
            accountCheckRequested = true
            handleFailure(SyncEngine.cloudError(error))
            return false
        }
        // 1.2.3 (docs/R1_2_3.md §3.5): away from the foreground, an answer that took longer than
        // `awayRecheckAfter` may have been given before iOS suspended the app and the Apple Account was switched,
        // and only delivered now. It is not used: the check is asked for again after the backoff (not at once,
        // so a slow answer in the background does not loop).
        if awayFromForeground, abs(clock().timeIntervalSince(askedAt)) > SyncEngine.awayRecheckAfter {
            accountCheckRequested = true
            scheduleBackoffRetry(serverHint: nil)
            return false
        }
        if let account = state.account {
            if account != name {
                state.pendingAccount = name
                persistState()
                setStatus(.accountMismatch)
                return false
            }
            state.pendingAccount = nil
        } else {
            state.account = name
        }
        accountCheckedAt = askedAt
        persistState()
        switch snapshot.status {
        case .localOnly, .accountMismatch:
            setStatus(.pending)
        default:
            break
        }
        return true
    }

    private func accountChanged() {
        accountCheckRequested = true
        // 1.2.3 (docs/R1_2_3.md §3): work already running for the old account stops at its next epoch check
        // (a push does not send its remaining pages, a pull in flight does not merge), like the erase and the
        // account choice. The round trip queued here confirms the account and sets the status.
        workEpoch += 1
        enqueueCycle()
    }

    private func ensureZoneAndSubscription() async {
        if !state.zoneReady {
            do {
                try await database.ensureZone()
                state.zoneReady = true
                persistState()
            } catch {
                // The pull reports the problem; the zone is made again next time.
            }
        }
        if state.zoneReady, !state.subscriptionReady {
            do {
                try await database.ensureSubscription()
                state.subscriptionReady = true
                persistState()
            } catch {
                // Next time.
            }
        }
    }

    /// The zone is gone (§4.5 「ゾーン消失」): every local page goes again, the zone and the
    /// subscription are made again, then one pull and one push. A second `.zoneMissing` is
    /// `.error(.server("zone"))`.
    /// `epoch` (1.2.3): the round trip's; an account change during `ensureZone` / `ensureSubscription` stops it.
    private func recoverFromZoneLoss(epoch: Int) async throws -> (pulled: Int, gaveUp: Bool) {
        state.resetAfterZoneLoss(allLocalPageIds: store.allPageIds())
        pageGeneration = [:]
        persistState()
        do {
            try await database.ensureZone()
            try checkEpoch(epoch)
            state.zoneReady = true
            try await database.ensureSubscription()
            try checkEpoch(epoch)
            state.subscriptionReady = true
            persistState()
            let pulled = try await pull(epoch: epoch)
            let gaveUp = try await push(epoch: epoch)
            return (pulled, gaveUp)
        } catch CloudError.zoneMissing {
            throw CloudError.other("zone")
        }
    }

    /// `fetchChanges(since: zoneToken)` and the merge of every changed page (§4.5 4). Returns how
    /// many records or deletions changed something on the device. `epoch` (1.2.3): the round trip's, taken
    /// before its account check (no longer read here, so a change during the check is not missed).
    private func pull(epoch: Int) async throws -> Int {
        markSyncing()
        var expiredOnce = false
        while true {
            let changes: CloudZoneChanges
            do {
                try checkStillFresh()
                changes = try await database.fetchChanges(since: state.zoneToken, namesOnly: false)
            } catch CloudError.changeTokenExpired where !expiredOnce {
                try checkEpoch(epoch)
                // 1.2.3: an expired token can be another account's zone; while a check is due it comes first.
                try await confirmAgainIfDue(epoch)
                expiredOnce = true
                state.zoneToken = nil
                state.seen = [:]
                persistState()
                continue
            }
            try checkEpoch(epoch)
            let count = apply(changes)
            state.zoneToken = changes.token
            state.lastSyncAt = InkPageRecord.ms(from: clock())
            persistState()
            return count
        }
    }

    /// Merges fetched records into the files (records this device sent are skipped by their
    /// change tag) and removes deleted pages.
    private func apply(_ changes: CloudZoneChanges) -> Int {
        var changed = 0
        for record in changes.changed {
            let name = record.recordName
            if record.recordType == InkPageRecord.metaRecordType {
                let values = InkPageRecord.metaValues(from: record)
                if let webImportedAt = values.webImportedAt {
                    state.webImportedAt = InkPageRecord.ms(from: webImportedAt)
                }
                if let seen = InkPageRecord.seen(from: record) { state.seen[name] = seen }
                continue
            }
            guard record.recordType == InkPageRecord.recordType else { continue }
            if let tag = record.changeTag, state.seen[name]?.changeTag == tag { continue }
            if mergeRemote(record) { changed += 1 }
        }
        for name in changes.deletedNames {
            if name == InkPageRecord.metaRecordName {
                state.seen[name] = nil
                continue
            }
            if store.exists(name) {
                try? store.remove(name)
                changed += 1
            }
            state.seen[name] = nil
            state.clearDirty(name)
            onRemoteUpdate?(InkPage.empty(pageId: name))
            onRemoteDelete?(name)
        }
        return changed
    }

    /// Merges one fetched `InkPage` record into its file (§4.5 3 and 4). Returns true when the file
    /// changed. A record whose body cannot be read is ignored (and not remembered, so it is tried
    /// again next time).
    @discardableResult
    private func mergeRemote(_ record: CloudRecord) -> Bool {
        let name = record.recordName
        let remote: InkPage
        do {
            remote = try InkPageRecord.page(from: record)
        } catch {
            return false
        }
        let local = store.load(name)
        let merged = InkPage.merge(local, remote)
        var changed = false
        if merged.contentDiffers(from: local) {
            do {
                try store.save(merged)
            } catch {
                return false
            }
            changed = true
            onRemoteUpdate?(merged)
        }
        if merged.contentDiffers(from: remote) {
            state.markDirty(name)
        }
        if let seen = InkPageRecord.seen(from: record) {
            state.seen[name] = seen
        }
        return changed
    }

    /// `pageOpened`: the page alone, with the cooldown already checked (§4.5 3).
    private func fetchPage(_ pageId: String) async {
        // 1.2.3 (docs/R1_2_3.md §3, G2): looked at again when it runs (it may have been queued before an
        // account change or the background); skipped while a check is due (the next pull brings the page).
        // 1.2.4: and while the iCloud half of 「全て消す」 is pending (it may have been queued before the erase).
        guard started, !needsAccountCheck, !state.pendingCloudErase else { return }
        let epoch = workEpoch
        do {
            let records = try await database.fetchRecords(names: [pageId])
            try checkEpoch(epoch)
            guard let record = records[pageId] else { return }
            if let tag = record.changeTag, state.seen[pageId]?.changeTag == tag { return }
            mergeRemote(record)
            persistState()
        } catch CloudError.networkUnavailable {
            handleFailure(.networkUnavailable)
        } catch CloudError.zoneMissing {
            do {
                try checkEpoch(epoch)
                // 1.2.3 (M3): as in `run`, the account first when a check became due meanwhile.
                try await confirmAgainIfDue(epoch)
                let recovered = try await recoverFromZoneLoss(epoch: epoch)
                if recovered.gaveUp {
                    setStatus(.pending)
                    scheduleBackoffRetry(serverHint: nil)
                } else {
                    finishRoundTrip()
                }
            } catch is Interrupted {
                return
            } catch {
                handleFailure(SyncEngine.cloudError(error))
            }
        } catch {
            // Silently ignored: the next pull brings the page anyway.
        }
    }

    /// Sends every dirty page (§4.5 5). Returns true when a page was left dirty because its
    /// conflicts did not settle within 3 retries (or a vanished record could not be made again).
    /// `epoch` (1.2.3): the round trip's, as in `pull`.
    private func push(epoch: Int) async throws -> Bool {
        pushAgain = false
        guard state.isDirty else { return false }
        markSyncing()
        var gaveUp = false
        for id in state.dirty {
            let generation = pageGeneration[id] ?? 0
            var page = store.load(id)
            var seen = state.seen[id]
            var conflicts = 0
            var recreated = false
            while true {
                let record: CloudRecord
                do {
                    record = try InkPageRecord.make(page, seen: seen)
                } catch {
                    throw CloudError.other(error.localizedDescription)
                }
                do {
                    // 1.2.3: a push frozen in the background and woken later checks the account again.
                    try checkStillFresh()
                    let saved = try await database.save(record)
                    try checkEpoch(epoch)
                    state.seen[id] = InkPageRecord.seen(from: saved)
                    if (pageGeneration[id] ?? 0) == generation {
                        state.clearDirty(id)
                    } else {
                        pushAgain = true
                    }
                    state.lastSyncAt = InkPageRecord.ms(from: clock())
                    persistState()
                    break
                } catch CloudError.serverRecordChanged(let server) {
                    try checkEpoch(epoch)
                    conflicts += 1
                    if let remote = try? InkPageRecord.page(from: server) {
                        let merged = InkPage.merge(store.load(id), remote)
                        try store.save(merged)
                        onRemoteUpdate?(merged)
                        page = merged
                    } else {
                        page = store.load(id)
                    }
                    seen = InkPageRecord.seen(from: server)
                    state.seen[id] = seen
                    persistState()
                    if conflicts > SyncBackoff.maxConflictRetries {
                        gaveUp = true
                        break
                    }
                } catch CloudError.recordNotFound {
                    try checkEpoch(epoch)
                    // 1.2.3: a record gone can be another account; while a check is due it comes first.
                    try await confirmAgainIfDue(epoch)
                    if recreated {
                        throw CloudError.other("record")
                    }
                    recreated = true
                    seen = nil
                    state.seen[id] = nil
                    persistState()
                }
            }
        }
        return gaveUp
    }

    /// `Meta.webImportedAt` (§1.2): saved with `.ifServerRecordUnchanged`; on a conflict the server's
    /// values are read and each field keeps the later date. Failures are ignored. `epoch` (1.2.3): taken
    /// before the account check; an account change stops the retries and nothing is remembered.
    private func saveMeta(webImportedAt: Date, epoch: Int) async {
        let name = InkPageRecord.metaRecordName
        var seen = state.seen[name]
        var web: Date? = webImportedAt
        var trial: Date?
        var attempts = 0
        var recreated = false
        while attempts <= SyncBackoff.maxConflictRetries {
            guard epoch == workEpoch, (try? checkStillFresh()) != nil else { return }
            let record = InkPageRecord.makeMeta(webImportedAt: web, trialStartedAt: trial, seen: seen)
            do {
                let saved = try await database.save(record)
                guard epoch == workEpoch else { return }
                state.seen[name] = InkPageRecord.seen(from: saved)
                persistState()
                return
            } catch CloudError.serverRecordChanged(let server) {
                attempts += 1
                let values = InkPageRecord.metaValues(from: server)
                web = SyncEngine.later(web, values.webImportedAt)
                trial = SyncEngine.later(trial, values.trialStartedAt)
                seen = InkPageRecord.seen(from: server)
            } catch CloudError.recordNotFound where !recreated {
                recreated = true
                seen = nil
            } catch {
                return
            }
        }
    }

    /// The iCloud half of the erase (§4.5 10): list the `InkPage` names (names only), delete them
    /// 200 at a time, then take a fresh token. `epoch` (1.2.3): the caller's, taken before its account
    /// check, so an account change during the check stops the erase before it deletes anything.
    private func cloudErase(epoch: Int) async throws {
        try checkEpoch(epoch)
        markSyncing()
        var after: CloudZoneChanges?
        do {
            try checkStillFresh()
            let listing = try await database.fetchChanges(since: nil, namesOnly: true)
            try checkEpoch(epoch)
            let names = listing.changed.filter { $0.recordType == InkPageRecord.recordType }.map { $0.recordName }
            try await deleteInBatches(names)
            try checkEpoch(epoch)
            after = try? await database.fetchChanges(since: nil, namesOnly: true)
            try checkEpoch(epoch)
        } catch CloudError.zoneMissing {
            // The zone is gone, so nothing is left to delete; the next round trip makes it again
            // (otherwise a pending erase would fail here on every cycle and never reach ensureZone).
            try checkEpoch(epoch)
            state.zoneReady = false
            state.subscriptionReady = false
        }
        state.pendingCloudErase = false
        state.zoneToken = after?.token
        state.seen = [:]
        state.lastSyncAt = InkPageRecord.ms(from: clock())
        persistState()
    }

    /// `delete(names:)` 200 at a time; `.limitExceeded` halves the batch, down to one name.
    private func deleteInBatches(_ names: [String]) async throws {
        var index = 0
        var batchSize = 200
        while index < names.count {
            let end = min(index + batchSize, names.count)
            let chunk = Array(names[index..<end])
            do {
                try checkStillFresh()
                try await database.delete(names: chunk)
                index = end
            } catch CloudError.limitExceeded {
                guard chunk.count > 1 else { throw CloudError.limitExceeded }
                batchSize = max(1, chunk.count / 2)
            }
        }
    }

    // MARK: - Status, failures, timers

    private func markSyncing() {
        if cloudUsable, snapshot.status != .syncing {
            setStatus(.syncing)
        }
    }

    /// After a successful round trip: `.synced` or `.pending` (something is still queued), backoff reset.
    private func finishRoundTrip() {
        backoff.reset()
        setStatus(state.isDirty ? .pending : .synced)
    }

    /// The table of §4.5: what each failure does to the status and whether it retries by itself.
    private func handleFailure(_ error: CloudError) {
        switch error {
        case .networkUnavailable:
            setStatus(.offline)
            scheduleBackoffRetry(serverHint: nil)
        case .notAuthenticated:
            setStatus(.localOnly(.notAuthenticated))
        case .quotaExceeded:
            setStatus(.error(.quota))
        case .permissionFailure:
            setStatus(.error(.permission))
        case .configuration(let message):
            setStatus(.error(.server(message)))
        case .retryLater(let after):
            setStatus(.pending)
            scheduleBackoffRetry(serverHint: after)
        case .limitExceeded:
            setStatus(.error(.server("limit")))
            scheduleBackoffRetry(serverHint: nil)
        case .recordNotFound:
            setStatus(.error(.server("record")))
            scheduleBackoffRetry(serverHint: nil)
        case .zoneMissing:
            setStatus(.error(.server("zone")))
            scheduleBackoffRetry(serverHint: nil)
        case .changeTokenExpired, .serverRecordChanged:
            setStatus(.pending)
            scheduleBackoffRetry(serverHint: nil)
        case .other(let message):
            setStatus(.error(.server(message)))
            scheduleBackoffRetry(serverHint: nil)
        }
    }

    private static func cloudError(_ error: Error) -> CloudError {
        (error as? CloudError) ?? .other(error.localizedDescription)
    }

    private static func later(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case (nil, nil): return nil
        case (let a?, nil): return a
        case (nil, let b?): return b
        case (let a?, let b?): return max(a, b)
        }
    }

    private func setStatus(_ status: SyncStatus) {
        if snapshot.status != status {
            snapshot.status = status
        }
    }

    /// Writes the ledger (failures are recorded, never thrown) and refreshes the snapshot.
    private func persistState() {
        if stateLoaded {
            do {
                try stateStore.save(state)
            } catch {
                stateSaveFailed = true
            }
        }
        var next = snapshot
        next.lastSyncAt = state.lastSyncAt.map(InkPageRecord.date(fromMs:))
        next.dirtyCount = state.dirty.count
        next.webImportedAt = state.webImportedAt.map(InkPageRecord.date(fromMs:))
        if next != snapshot {
            snapshot = next
        }
    }

    /// The last `stateStore.save` threw (the dirty marks live on in memory).
    private(set) var stateSaveFailed = false

    /// 15 s → 30 → 60 → … → 300 (or the server's hint when longer), then one round trip.
    private func scheduleBackoffRetry(serverHint: TimeInterval?) {
        let delay = backoff.nextDelay(serverHint: serverHint)
        backoff.recordFailure()
        scheduleRetry(after: delay)
    }

    private func scheduleRetry(after delay: TimeInterval) {
        cancelRetry()
        let epoch = retryEpoch
        retryTask = spawn {
            await self.pause(delay)
            guard epoch == self.retryEpoch else { return }
            self.retryTask = nil
            _ = await self.enqueueCycle().value
        }
    }

    private func cancelRetry() {
        retryEpoch += 1
        retryTask = nil
    }

    /// One debounce task: 1.5 s after the last `save`, a push (§4.5 「デバウンスと再試行の Task」).
    private func scheduleDebouncedPush() {
        debounceGeneration += 1
        guard debounceTask == nil else { return }
        let epoch = debounceEpoch
        // The generation this task starts from: saves that arrive during the sleep move it on.
        var generation = debounceGeneration
        debounceTask = spawn {
            while true {
                await self.pause(SyncBackoff.debounce)
                guard epoch == self.debounceEpoch else { return }
                if generation == self.debounceGeneration { break }
                generation = self.debounceGeneration
            }
            self.debounceTask = nil
            _ = await self.enqueuePush().value
        }
    }

    private func cancelDebounce() {
        debounceEpoch += 1
        debounceTask = nil
    }

    // MARK: - The serial queue and the job count

    /// Queues one round trip; a round trip that is queued but not started yet is shared.
    @discardableResult
    private func enqueueCycle() -> Task<Int, Never> {
        if let pending = pendingCycle { return pending }
        let task = enqueue { () -> Int in
            self.pendingCycle = nil
            return await self.run(.cycle)
        }
        pendingCycle = task
        return task
    }

    @discardableResult
    private func enqueuePush() -> Task<Int, Never> {
        enqueue { await self.run(.pushOnly) }
    }

    /// Runs `body` after everything queued before it.
    @discardableResult
    private func enqueue<T>(_ body: @escaping @MainActor () async -> T) -> Task<T, Never> {
        beginJob()
        let previous = queueTail
        let task = Task { @MainActor () -> T in
            if let previous = previous { await previous.value }
            let result = await body()
            self.endJob()
            return result
        }
        queueTail = Task { @MainActor in
            _ = await task.value
        }
        return task
    }

    /// A task outside the queue (timers, the notification race).
    @discardableResult
    private func spawn(_ body: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        beginJob()
        return Task { @MainActor in
            await body()
            self.endJob()
        }
    }

    /// `sleep` that does not count as running work (`waitUntilIdle` ignores sleeping tasks).
    private func pause(_ seconds: TimeInterval) async {
        endJob()
        await sleep(seconds)
        beginJob()
    }

    private func beginJob() {
        activeJobs += 1
    }

    private func endJob() {
        activeJobs -= 1
        if activeJobs <= 0 {
            activeJobs = 0
            wakeIdleWaitersIfIdle()
        }
    }

    private func wakeIdleWaitersIfIdle() {
        guard activeJobs == 0 else { return }
        let waiters = idleWaiters
        idleWaiters = []
        for waiter in waiters { waiter.resume() }
    }
}

// MARK: - 1.3: the pages of a window (docs/M7C_CONTRACT.md §7, D5)

extension SyncEngine {
    /// `pageOpened` for the pages a window shows at once (the joined week and day pages; up to 15): the same
    /// gate — nothing on the inert engine or before `start()`, only while iCloud can be reached, no fetch while
    /// an account check is due (G2; looked at when called and again when it runs), the 30 s cooldown per page
    /// (shared with `pageOpened`; a page named twice is due once) — then one `fetchRecords` for every page that
    /// is due (a page without a record is simply absent) and each record merged by `mergeRemote`, one at a
    /// time in the order given, as `fetchPage` does. The work goes through `enqueue`, so `waitUntilIdle`
    /// counts it. `pageOpened` itself is unchanged (the one-page screen keeps calling it).
    /// Stricter than `pageOpened` in two ways: nothing is fetched while the iCloud half of 「全て消す」 is pending
    /// (`pendingCloudErase`; looked at when called and again when it runs), since the round trip finishes that
    /// deletion before it pulls anything and a page fetched before it would bring the erased ink back to this
    /// device (and with the next launch to iCloud); and the epoch is taken when it is called, so work queued
    /// before the erase, an account change or the return from the background is dropped.
    func pagesOpened(_ pageIds: [String]) {
        guard !inactive, started else { return }
        switch snapshot.status {
        case .synced, .pending, .offline, .error:
            break
        default:
            return
        }
        // Before the cooldown, as in `pageOpened`: a page refused now is fetched when it is opened again after
        // the check or the erase.
        guard !needsAccountCheck, !state.pendingCloudErase else { return }
        let now = clock()
        var due: [String] = []
        for pageId in pageIds {
            if let last = lastPageFetch[pageId], now.timeIntervalSince(last) < SyncBackoff.pageFetchCooldown {
                continue
            }
            lastPageFetch[pageId] = now
            due.append(pageId)
        }
        guard !due.isEmpty else { return }
        // Taken now, before the request, and checked when the work runs and after the request: an account
        // change, the erase, the account choice or the return from the background in between leaves it unmade
        // or its answer unmerged.
        let epoch = workEpoch
        enqueue { await self.fetchPages(due, epoch: epoch) }
    }

    /// `pagesOpened`: the pages that are due, with the cooldown already checked. `fetchPage` for several
    /// pages with one request; its failures are handled as there.
    private func fetchPages(_ pageIds: [String], epoch: Int) async {
        // Looked at again when it runs (it may have been queued before an account change, a check that found
        // another account, the background or 「全て消す」); skipped while a check is due or the iCloud erase is
        // pending, and when the epoch moved since the call (the next pull brings the pages).
        guard started, !needsAccountCheck, !state.pendingCloudErase, epoch == workEpoch else { return }
        do {
            // Before the request while away from the foreground (today a check is then always due, so the
            // guard above has returned already; kept so the gate stays whole if that ever changes).
            try checkStillFresh()
            let records = try await database.fetchRecords(names: pageIds)
            try checkEpoch(epoch)
            for pageId in pageIds {
                guard let record = records[pageId] else { continue }
                if let tag = record.changeTag, state.seen[pageId]?.changeTag == tag { continue }
                mergeRemote(record)
                persistState()
            }
        } catch CloudError.networkUnavailable {
            handleFailure(.networkUnavailable)
        } catch CloudError.zoneMissing {
            do {
                try checkEpoch(epoch)
                // As in `fetchPage` (1.2.3, M3): the account first when a check became due meanwhile.
                try await confirmAgainIfDue(epoch)
                let recovered = try await recoverFromZoneLoss(epoch: epoch)
                if recovered.gaveUp {
                    setStatus(.pending)
                    scheduleBackoffRetry(serverHint: nil)
                } else {
                    finishRoundTrip()
                }
            } catch is Interrupted {
                return
            } catch {
                handleFailure(SyncEngine.cloudError(error))
            }
        } catch {
            // Silently ignored (an `Interrupted` from the epoch or the freshness check too): the next pull
            // brings the pages anyway.
        }
    }
}
