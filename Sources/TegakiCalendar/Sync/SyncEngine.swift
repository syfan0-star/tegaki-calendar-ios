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
        SyncEngine(store: InkPageStore(), stateStore: SyncStateStore(), database: database)
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

    let store: InkPageStore
    let stateStore: SyncStateStore
    let database: any CloudDatabase

    /// The ledger (§1.1). Internal so the tests can look at it.
    private(set) var state: SyncState = .empty

    private let clock: () -> Date
    private let sleep: (TimeInterval) async -> Void

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
    /// `.CKAccountChanged` asks for a fresh account check in the next round trip.
    private var accountCheckRequested = false
    /// Bumped by the erase and the account change; work started under an older epoch stops writing.
    private var workEpoch = 0

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
        sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
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
        guard accountConfirmed else { return }
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

    func applicationDidBecomeActive() {
        guard !inactive, started else { return }
        Task { @MainActor in
            await self.syncNow()
        }
    }

    /// A silent push (§4.5 7): false at once unless it is our zone subscription; otherwise a round
    /// trip is queued and this returns within 20 s (`SyncBackoff.notificationBudget`): true when
    /// the pull brought at least one change in that time. The round trip goes on either way.
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard !inactive, started else { return false }
        guard database.subscriptionID(in: userInfo) == CloudKitDatabase.subscriptionID else { return false }
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
            pageGeneration = [:]
            persistState()
            setStatus(.pending)
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
            do {
                try await self.cloudErase()
                self.finishRoundTrip()
                return nil
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
            _ = await enqueue { await self.saveMeta(webImportedAt: now) }.value
        }
        if snapshot.status == .synced, state.isDirty {
            setStatus(.pending)
        }
        enqueuePush()
        return outcome
    }

    // MARK: - Tests (§8.2)

    /// Waits until every task of the engine has finished, except the ones suspended in `sleep`.
    func waitUntilIdle() async {
        while true {
            // Let tasks that were just resumed (a sleep that returned, an account change) run first.
            for _ in 0..<3 { await Task.yield() }
            if activeJobs == 0 { return }
            await withCheckedContinuation { continuation in
                idleWaiters.append(continuation)
            }
        }
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
            guard accountConfirmed else { return 0 }
        }
        do {
            if state.pendingCloudErase {
                try await cloudErase()
            }
            try checkEpoch(epoch)
            if work == .cycle {
                await ensureZoneAndSubscription()
            }
            var pulled = 0
            var gaveUp = false
            do {
                if work == .cycle {
                    pulled = try await pull()
                }
                gaveUp = try await push()
            } catch CloudError.zoneMissing {
                try checkEpoch(epoch)
                let recovered = try await recoverFromZoneLoss()
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
        if accountCheckRequested { return true }
        if state.account == nil || state.pendingAccount != nil { return true }
        switch snapshot.status {
        case .localOnly, .accountMismatch:
            return true
        default:
            return false
        }
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
        accountCheckRequested = false
        let accountStatus: CloudAccountStatus
        do {
            accountStatus = try await database.accountStatus()
        } catch {
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
            scheduleBackoffRetry(serverHint: nil)
            return false
        case .available:
            break
        }
        let name: String
        do {
            name = try await database.userRecordName()
        } catch {
            handleFailure(SyncEngine.cloudError(error))
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
    private func recoverFromZoneLoss() async throws -> (pulled: Int, gaveUp: Bool) {
        state.resetAfterZoneLoss(allLocalPageIds: store.allPageIds())
        pageGeneration = [:]
        persistState()
        do {
            try await database.ensureZone()
            state.zoneReady = true
            try await database.ensureSubscription()
            state.subscriptionReady = true
            persistState()
            let pulled = try await pull()
            let gaveUp = try await push()
            return (pulled, gaveUp)
        } catch CloudError.zoneMissing {
            throw CloudError.other("zone")
        }
    }

    /// `fetchChanges(since: zoneToken)` and the merge of every changed page (§4.5 4). Returns how
    /// many records or deletions changed something on the device.
    private func pull() async throws -> Int {
        let epoch = workEpoch
        markSyncing()
        var expiredOnce = false
        while true {
            let changes: CloudZoneChanges
            do {
                changes = try await database.fetchChanges(since: state.zoneToken, namesOnly: false)
            } catch CloudError.changeTokenExpired where !expiredOnce {
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
        guard started, accountConfirmed else { return }
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
                let recovered = try await recoverFromZoneLoss()
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
    private func push() async throws -> Bool {
        let epoch = workEpoch
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
    /// values are read and each field keeps the later date. Failures are ignored.
    private func saveMeta(webImportedAt: Date) async {
        let name = InkPageRecord.metaRecordName
        var seen = state.seen[name]
        var web: Date? = webImportedAt
        var trial: Date?
        var attempts = 0
        var recreated = false
        while attempts <= SyncBackoff.maxConflictRetries {
            let record = InkPageRecord.makeMeta(webImportedAt: web, trialStartedAt: trial, seen: seen)
            do {
                let saved = try await database.save(record)
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
    /// 200 at a time, then take a fresh token.
    private func cloudErase() async throws {
        let epoch = workEpoch
        markSyncing()
        var after: CloudZoneChanges?
        do {
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
            let waiters = idleWaiters
            idleWaiters = []
            for waiter in waiters { waiter.resume() }
        }
    }
}
