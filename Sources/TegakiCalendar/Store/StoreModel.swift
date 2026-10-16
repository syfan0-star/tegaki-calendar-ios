import Access
import Combine
import Foundation

/// One plan as the paywall shows it (M5_CONTRACT §2.3), copied from `StoreProduct`.
struct PlanOffer: Equatable, Sendable {
    var plan: Plan
    /// 「¥2,400」 (StoreKit's `displayPrice`; the yen sign may be the full-width 「￥」 on a device)
    var displayPrice: String
    var price: Decimal
    var isEligibleForIntroOffer: Bool
    var introDays: Int?
    /// 年額だけ 「¥200」
    var perMonthDisplayPrice: String?
}

enum StorePhase: Equatable, Sendable {
    case idle, loadingProducts, purchasing(Plan), restoring
}

/// refresh() の起点。message を触るのは .paywall（ペイウォールの「再読み込み」）だけ
enum RefreshReason: Equatable, Sendable {
    case automatic, paywall
}

enum StoreMessage: Equatable, Sendable {
    case purchased(Plan), restored, nothingToRestore, pending, productsUnavailable, failed(String)
}

/// Everything the views read (§2.3). `access` is the only input of the gated operations (§3.1).
struct StoreSnapshot: Equatable, Sendable {
    /// 起動直後は AccessCache.stateForLaunch
    var access: AccessState
    /// 年額・月額の順（U がこの順で並べる）。空 = 価格が取れていない
    var offers: [PlanOffer]
    var phase: StorePhase
    /// U がトースト／脚注に出し、clearMessage() で消す
    var message: StoreMessage?
    /// 最後に App Store へ問い合わせた呼び出し（products か renewals）が成功したか
    var storeReachable: Bool
    /// 最初の refresh() が 1 回完了した（§4.2 の初回ペイウォールの判定に使う）
    var refreshed: Bool
}

/// The one object the views read the store through (M5_CONTRACT §2.3, §2.4, D2). It asks the
/// `StoreClient` for the products, the entitlements and the renewal info, hands the copies to
/// `AccessPolicy`, reconciles the answer with the cached state and keeps the result in `snapshot`.
/// `start()` once per launch (the first frame shows the cached state), `refresh()` on every
/// foreground (U), `purchase` / `restore` from the paywall and the settings.
///
/// `refresh()` never runs twice at once: a call that arrives while one runs waits for a second
/// run after it (M5-37), so a purchase's refresh is never satisfied by a run that read the store
/// before the purchase.
@MainActor
final class StoreModel: ObservableObject {
    @Published private(set) var snapshot: StoreSnapshot

    /// `products(ids:)` is called again only when `offers` is empty or the last success is this old (M5-38).
    static let productsMaxAge: TimeInterval = 3600
    /// The screenshot subscriber's next renewal: this many days after 「今日」 (§2.3).
    static let demoUntilDays: TimeInterval = 200

    private let client: any StoreClient
    private let cache: any AccessCacheStore
    private let now: @Sendable () -> Date

    private var started = false
    /// `screenshotDemo`: start / refresh / purchase / restore do nothing.
    private var inactive = false
    private var updatesTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?

    /// Transactions seen on `updates()` or returned by `purchase` (memory only, §2.4 1): a revoked
    /// transaction reaches the policy's row 1 only through here, because `currentEntitlements`
    /// never returns one.
    private var recentUpdates: [UInt64: EntitlementInput] = [:]
    /// What the last `currentEntitlements()` / `renewals(groupID:)` returned (`purchase` resolves
    /// against these before its own refresh, §2.4 4).
    private var knownEntitlements: [EntitlementInput] = []
    private var knownRenewals: [RenewalInput]?
    private var lastProductsAt: Date?
    /// The group of the fetched products: the `renewals` query when no entitlement names a group.
    private var productsGroupID: String?

    // refresh(): one run at a time; callers that arrive during a run wait for the rerun (M5-37).
    private var refreshing = false
    private var needsRerun = false
    private var rerunReason: RefreshReason = .automatic
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstRefreshWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    init(client: any StoreClient, cache: any AccessCacheStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.cache = cache
        self.now = now
        snapshot = StoreSnapshot(
            access: AccessCache.stateForLaunch(cached: cache.load(), now: now()),
            offers: [],
            phase: .idle,
            message: nil,
            storeReachable: false,
            refreshed: false
        )
    }

    deinit {
        updatesTask?.cancel()
        startupTask?.cancel()
    }

    // MARK: - Factories (§2.3)

    /// The app's model: `LiveStoreClient` over `UserDefaultsAccessCache`. The screenshot mode gets
    /// `screenshotDemo` (`screenshotReadOnly` picks 閲覧専用 or the yearly subscriber; the caller
    /// passes `ScreenshotMode.current?.readOnly ?? false`, M5-34), and so does the XCTest host
    /// (the simulator has no StoreKit configuration while the unit tests run; same rule as
    /// `SyncEngine.shared`).
    static func make(screenshotReadOnly: Bool = false) -> StoreModel {
        if ScreenshotMode.isActive {
            let today = ScreenshotMode.current?.today ?? Date()
            return screenshotDemo(access: screenshotReadOnly ? .readOnly(.notSubscribed) : demoSubscription(today: today))
        }
        if SyncEngine.isTestHost {
            return screenshotDemo(access: demoSubscription(today: Date()))
        }
        return StoreModel(client: LiveStoreClient(), cache: UserDefaultsAccessCache())
    }

    /// 写真モード・プレビュー用: fixed offers (`StoreStrings.demo*`), an inert client, no cache;
    /// `refreshed` from the start, and `start()` / `refresh()` / `purchase` / `restore` do nothing.
    static func screenshotDemo(access: AccessState, eligible: Bool = true) -> StoreModel {
        let model = StoreModel(client: InertStoreClient(), cache: NoopAccessCache())
        model.inactive = true
        model.snapshot = StoreSnapshot(
            access: access,
            offers: demoOffers(eligible: eligible),
            phase: .idle,
            message: nil,
            storeReachable: true,
            refreshed: true
        )
        return model
    }

    /// The screenshot subscriber: 年額, renewing `demoUntilDays` after `today`.
    static func demoSubscription(today: Date) -> AccessState {
        .subscribed(Subscription(plan: .yearly, until: today.addingTimeInterval(demoUntilDays * 86_400), willAutoRenew: true, inGrace: false))
    }

    /// 年額 「¥2,400」 (「¥200」 per month), 月額 「¥300」, both with the 14-day trial.
    static func demoOffers(eligible: Bool) -> [PlanOffer] {
        [
            PlanOffer(
                plan: .yearly,
                displayPrice: StoreStrings.demoYearlyPrice,
                price: ProductIDs.contractPrice[.yearly] ?? 2400,
                isEligibleForIntroOffer: eligible,
                introDays: ProductIDs.trialDays,
                perMonthDisplayPrice: StoreStrings.demoPerMonthPrice
            ),
            PlanOffer(
                plan: .monthly,
                displayPrice: StoreStrings.demoMonthlyPrice,
                price: ProductIDs.contractPrice[.monthly] ?? 300,
                isEligibleForIntroOffer: eligible,
                introDays: ProductIDs.trialDays,
                perMonthDisplayPrice: nil
            ),
        ]
    }

    var isReadOnly: Bool { !snapshot.access.canEdit }

    // MARK: - Commands

    /// Once per launch (§2.4 1): the cached state → the `updates()` listener → `finishUnfinished()`
    /// → the first `refresh()`. A second call does nothing.
    func start() {
        guard !inactive, !started else { return }
        started = true
        snapshot.access = AccessCache.stateForLaunch(cached: cache.load(), now: now())
        let client = self.client
        updatesTask = Task { @MainActor [weak self] in
            for await input in client.updates() {
                guard let self = self else { return }
                self.recentUpdates[input.id] = input
                await self.refresh()
            }
        }
        startupTask = Task { @MainActor [weak self] in
            await client.finishUnfinished()
            guard let self = self else { return }
            await self.refresh()
        }
    }

    /// products (when needed) → currentEntitlements → renewals → resolve → reconcile → save (§2.4 2).
    /// While a run is going, this waits for it and for one more run after it (the waiters share
    /// that rerun; a `.paywall` reason carries over to it).
    func refresh(reason: RefreshReason = .automatic) async {
        guard !inactive else { return }
        if refreshing {
            needsRerun = true
            if reason == .paywall { rerunReason = .paywall }
            await withCheckedContinuation { continuation in
                refreshWaiters.append(continuation)
            }
            return
        }
        refreshing = true
        var reason = reason
        repeat {
            needsRerun = false
            rerunReason = .automatic
            await performRefresh(reason: reason)
            reason = rerunReason
        } while needsRerun
        refreshing = false
        let waiters = refreshWaiters
        refreshWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    /// True once the first `refresh()` has completed, false when `timeout` passes first.
    func awaitFirstRefresh(timeout: Duration) async -> Bool {
        if snapshot.refreshed { return true }
        let id = UUID()
        let timer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: timeout)
            self?.firstRefreshWaiters.removeValue(forKey: id)?.resume()
        }
        await withCheckedContinuation { continuation in
            if snapshot.refreshed {
                continuation.resume()
            } else {
                firstRefreshWaiters[id] = continuation
            }
        }
        timer.cancel()
        return snapshot.refreshed
    }

    /// `phase = .purchasing(plan)` → `client.purchase` → the result as `message` (§2.5). A success
    /// updates `access` first (the badge disappears the moment the paywall closes, and the
    /// 「14 日間の無料試用」 wording sees `.trial`), then refreshes. Ignored while a purchase or a
    /// restore is running (the CTA is a spinner then).
    func purchase(_ plan: Plan) async {
        guard !inactive else { return }
        switch snapshot.phase {
        case .purchasing, .restoring: return
        case .idle, .loadingProducts: break
        }
        snapshot.phase = .purchasing(plan)
        do {
            let result = try await client.purchase(productID: plan.productID)
            switch result {
            case .success(let input):
                recentUpdates[input.id] = input
                snapshot.access = AccessPolicy.resolve(entitlements: mergedEntitlements(), renewals: knownRenewals, now: now())
                snapshot.message = .purchased(plan)
                await refresh()
            case .pending:
                snapshot.message = .pending
            case .cancelled:
                break
            case .unverified:
                snapshot.message = .failed(StoreStrings.unverified)
            }
        } catch {
            if let message = StoreStrings.failure(error) {
                snapshot.message = message
            }
        }
        snapshot.phase = .idle
    }

    /// `phase = .restoring` → `AppStore.sync()` → `refresh()` → `.restored` when that gave the
    /// right to edit, `.nothingToRestore` otherwise; a throw is mapped like a purchase's (§2.5).
    func restore() async {
        guard !inactive else { return }
        switch snapshot.phase {
        case .purchasing, .restoring: return
        case .idle, .loadingProducts: break
        }
        snapshot.phase = .restoring
        do {
            try await client.sync()
            await refresh()
            snapshot.message = snapshot.access.canEdit ? .restored : .nothingToRestore
        } catch {
            if let message = StoreStrings.failure(error) {
                snapshot.message = message
            }
        }
        snapshot.phase = .idle
    }

    func clearMessage() {
        snapshot.message = nil
    }

    // MARK: - The refresh (§2.4 2)

    private func performRefresh(reason: RefreshReason) async {
        // 1. Products: only when there are none or the last fetch is an hour old (M5-38). Only a
        //    paywall's 「再読み込み」 may put a failure into `message` (a normal refresh never
        //    overwrites `.purchased` or `.nothingToRestore`).
        let productsAge = lastProductsAt.map { now().timeIntervalSince($0) } ?? .infinity
        if snapshot.offers.isEmpty || productsAge >= Self.productsMaxAge {
            if snapshot.offers.isEmpty, snapshot.phase == .idle {
                snapshot.phase = .loadingProducts
            }
            do {
                let products = try await client.products(ids: ProductIDs.all)
                snapshot.offers = Self.offers(from: products)
                lastProductsAt = now()
                if let group = products.compactMap(\.subscriptionGroupID).first {
                    productsGroupID = group
                }
                snapshot.storeReachable = true
            } catch {
                snapshot.storeReachable = false
                if reason == .paywall {
                    snapshot.message = .productsUnavailable
                }
            }
        }
        // 2. The entitlements (the device's own copy: answers offline too).
        knownEntitlements = await client.currentEntitlements()
        let entitlements = mergedEntitlements()
        // 3. The renewal info of the group; nil = could not be fetched (the policy then never
        //    declares an expiry on its own: rows 2 and 13 give `.unknown`).
        var renewals: [RenewalInput]?
        if let groupID = entitlements.compactMap(\.subscriptionGroupID).first ?? productsGroupID {
            do {
                renewals = try await client.renewals(groupID: groupID)
                snapshot.storeReachable = true
            } catch {
                renewals = nil
                snapshot.storeReachable = false
            }
        }
        knownRenewals = renewals
        // A revoked copy in the status's `latestTransaction` replaces the memory's copy of the same
        // transaction (the `updates()` copy may predate the refund): a refund the stream has not
        // delivered yet is not masked by the purchase's own copy (§1.4 返金・取消).
        for renewal in renewals ?? [] {
            if let latest = renewal.latestTransaction, latest.revocationDate != nil, recentUpdates[latest.id] != nil {
                recentUpdates[latest.id] = latest
            }
        }
        // 4. Decide, reconcile with the cache, keep (never `.unknown`, never an unreachable answer).
        let live = AccessPolicy.resolve(entitlements: mergedEntitlements(), renewals: renewals, now: now())
        let access = AccessPolicy.reconcile(live: live, cached: cache.load(), storeReachable: snapshot.storeReachable, now: now())
        snapshot.access = access
        if access != .readOnly(.unknown), snapshot.storeReachable {
            cache.save(AccessSnapshot(state: access, savedAt: now()))
        }
        if snapshot.phase == .loadingProducts {
            snapshot.phase = .idle
        }
        snapshot.refreshed = true
        let waiters = firstRefreshWaiters
        firstRefreshWaiters = [:]
        for waiter in waiters.values { waiter.resume() }
    }

    /// The last `currentEntitlements()` plus everything seen on `updates()` / returned by
    /// `purchase`, one per transaction id (the update's copy wins: it may carry a revocation).
    private func mergedEntitlements() -> [EntitlementInput] {
        var byID: [UInt64: EntitlementInput] = [:]
        for input in knownEntitlements { byID[input.id] = input }
        for input in recentUpdates.values { byID[input.id] = input }
        return byID.values.sorted { $0.id < $1.id }
    }

    /// `StoreProduct` → `PlanOffer` for the two known plans, yearly first (U shows them in this order).
    static func offers(from products: [StoreProduct]) -> [PlanOffer] {
        var offers: [PlanOffer] = []
        for product in products {
            guard let plan = Plan(productID: product.id) else { continue }
            offers.append(PlanOffer(
                plan: plan,
                displayPrice: product.displayPrice,
                price: product.price,
                isEligibleForIntroOffer: product.isEligibleForIntroOffer,
                introDays: product.introDays,
                perMonthDisplayPrice: product.perMonthDisplayPrice
            ))
        }
        return offers.sorted { $0.plan.months > $1.plan.months }
    }
}

/// The client of `screenshotDemo` (and of the XCTest host): no products, no rights, nothing happens.
struct InertStoreClient: StoreClient {
    func products(ids: Set<String>) async throws -> [StoreProduct] { [] }
    func purchase(productID: String) async throws -> StorePurchaseResult { .cancelled }
    func currentEntitlements() async -> [EntitlementInput] { [] }
    func renewals(groupID: String) async throws -> [RenewalInput] { [] }
    func updates() -> AsyncStream<EntitlementInput> {
        AsyncStream { continuation in continuation.finish() }
    }
    func finishUnfinished() async {}
    func sync() async throws {}
}
