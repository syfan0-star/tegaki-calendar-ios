import Access
import StoreKit
import XCTest
@testable import TegakiCalendar

/// `StoreModel` over the fake App Store (M5_CONTRACT §7.3.2): the cached first frame, the refresh
/// (resolve → reconcile → save), the offline rules, the purchase and restore messages, the
/// coalescing of overlapping refreshes, the hourly product fetch, the updates stream, the
/// UserDefaults cache and the screenshot demo. `now` is fixed; no StoreKit anywhere.
@MainActor
final class StoreModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private let day: TimeInterval = 86_400

    private var client: FakeStoreClient!
    private var cache: MemoryAccessCache!
    private var clock: TestClock!
    private var model: StoreModel!
    /// `client.entitlementsCalls` at the moment each coalesced `refresh()` returned.
    private var callsAtReturn: [Int] = []

    override func setUp() async throws {
        client = FakeStoreClient()
        cache = MemoryAccessCache()
        clock = TestClock(now)
        callsAtReturn = []
        makeModel()
    }

    override func tearDown() async throws {
        client.updatesContinuation.finish() // ends the model's updates listener
        model = nil
    }

    // MARK: - Helpers

    private func makeModel() {
        let clock = self.clock!
        model = StoreModel(client: client, cache: cache, now: { clock.now })
    }

    private var access: AccessState { model.snapshot.access }
    private var message: StoreMessage? { model.snapshot.message }

    private func entitlement(_ plan: Plan, id: UInt64 = 1, expires: TimeInterval, introductory: Bool = false, revoked: Bool = false) -> EntitlementInput {
        EntitlementInput(
            id: id,
            productID: plan.productID,
            subscriptionGroupID: FakeStoreClient.groupID,
            purchaseDate: now.addingTimeInterval(-day),
            expirationDate: now.addingTimeInterval(expires),
            revocationDate: revoked ? now : nil,
            isIntroductory: introductory
        )
    }

    private func subscribed(until: TimeInterval, willAutoRenew: Bool = true, inGrace: Bool = false) -> AccessSnapshot {
        AccessSnapshot(
            state: .subscribed(Subscription(plan: .yearly, until: now.addingTimeInterval(until), willAutoRenew: willAutoRenew, inGrace: inGrace)),
            savedAt: now
        )
    }

    /// Yields, then sleeps in 5 ms steps (5 s at most), until `condition` holds.
    private func waitUntil(_ condition: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
        for _ in 0..<1000 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("timed out", file: file, line: line)
    }

    private func awaitFirstRefresh() async {
        let done = await model.awaitFirstRefresh(timeout: .seconds(5))
        XCTAssertTrue(done)
    }

    // MARK: - Start and refresh

    func testStartShowsTheCachedStateFirst() async {
        cache = MemoryAccessCache(subscribed(until: 10 * day))
        makeModel()
        model.start()
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(access, cache.stored?.state)
        XCTAssertEqual(model.snapshot.offers, [])
        XCTAssertFalse(model.snapshot.refreshed)
        await awaitFirstRefresh()
        // The fake has no entitlement: the first refresh ends the cached right (the store was reached).
        XCTAssertEqual(access, .readOnly(.notSubscribed))
        model.start() // a second call does nothing
        XCTAssertEqual(client.finishUnfinishedCalls, 1)
    }

    func testRefreshResolvesAndSaves() async {
        client.entitlements = [entitlement(.yearly, expires: 300 * day)]
        await model.refresh()
        let expected = AccessState.subscribed(Subscription(plan: .yearly, until: now.addingTimeInterval(300 * day), willAutoRenew: true, inGrace: false))
        XCTAssertEqual(access, expected)
        XCTAssertEqual(cache.saved?.state, expected)
        XCTAssertEqual(cache.saved?.savedAt, now)
        XCTAssertEqual(model.snapshot.offers.map(\.plan), [.yearly, .monthly])
        XCTAssertEqual(model.snapshot.offers[0].displayPrice, StoreStrings.demoYearlyPrice)
        XCTAssertEqual(model.snapshot.offers[0].perMonthDisplayPrice, StoreStrings.demoPerMonthPrice)
        XCTAssertEqual(model.snapshot.offers[1].displayPrice, StoreStrings.demoMonthlyPrice)
        XCTAssertNil(model.snapshot.offers[1].perMonthDisplayPrice)
        XCTAssertTrue(model.snapshot.storeReachable)
        XCTAssertTrue(model.snapshot.refreshed)
        XCTAssertEqual(model.snapshot.phase, .idle)
        XCTAssertNil(message)
        XCTAssertEqual(client.renewalsCalls, [FakeStoreClient.groupID])
        XCTAssertFalse(model.isReadOnly)
    }

    func testOfflineKeepsACachedSubscription() async {
        client.productsResult = .failure(URLError(.notConnectedToInternet))
        client.entitlements = []
        cache = MemoryAccessCache(subscribed(until: 10 * day))
        makeModel()
        await model.refresh(reason: .paywall)
        XCTAssertEqual(access, cache.stored?.state)
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(message, .productsUnavailable)
        XCTAssertFalse(model.snapshot.storeReachable)
        XCTAssertEqual(model.snapshot.offers, [])
        XCTAssertEqual(client.renewalsCalls, []) // no group id without products or entitlements
        XCTAssertEqual(cache.saveCount, 0)
    }

    func testOfflineWithAnExpiredCacheIsReadOnly() async {
        client.productsResult = .failure(URLError(.notConnectedToInternet))
        cache = MemoryAccessCache(subscribed(until: -1 * day, willAutoRenew: false))
        makeModel()
        await model.refresh()
        XCTAssertEqual(access, .readOnly(.expired))
        XCTAssertTrue(model.isReadOnly)
        XCTAssertNil(message) // an automatic refresh never sets .productsUnavailable
        XCTAssertEqual(cache.saveCount, 0)
    }

    // MARK: - Purchase

    func testPurchaseSuccessClosesWithAMessage() async {
        client.purchaseResults = [.success(.success(entitlement(.yearly, id: 42, expires: 365 * day)))]
        client.pauseEntitlements = true
        let purchase = Task { await self.model.purchase(.yearly) }
        await waitUntil(client.entitlementsWaiting == 1)
        // Before the refresh completes: the right is there and the message is set.
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(access.plan, .yearly)
        XCTAssertEqual(message, .purchased(.yearly))
        XCTAssertEqual(model.snapshot.phase, .purchasing(.yearly))
        XCTAssertEqual(StoreStrings.text(for: message!, access: access), StoreStrings.purchased)
        client.pauseEntitlements = false
        client.resumeEntitlements()
        await purchase.value
        XCTAssertEqual(model.snapshot.phase, .idle)
        XCTAssertEqual(client.purchaseCalls, [Plan.yearly.productID])
        XCTAssertEqual(client.entitlementsCalls, 1)
        XCTAssertTrue(access.canEdit) // the fake's entitlements are still empty: the update's copy carries the right
        XCTAssertEqual(message, .purchased(.yearly))
        XCTAssertEqual(cache.saved?.state, access)
    }

    func testPurchaseWhileRefreshingDoesNotJoinStaleResult() async {
        client.entitlements = []
        client.pauseEntitlements = true
        let refresh = Task { await self.model.refresh() }
        await waitUntil(client.entitlementsWaiting == 1)
        client.purchaseResults = [.success(.success(entitlement(.yearly, id: 7, expires: 365 * day)))]
        let purchase = Task { await self.model.purchase(.yearly) }
        await waitUntil(message == .purchased(.yearly))
        XCTAssertTrue(access.canEdit)
        // The purchase's refresh waits for the running one and for a rerun after it.
        XCTAssertEqual(client.entitlementsCalls, 1)
        client.entitlements = [entitlement(.yearly, id: 7, expires: 365 * day)]
        client.pauseEntitlements = false
        client.resumeEntitlements()
        await refresh.value
        await purchase.value
        XCTAssertEqual(client.entitlementsCalls, 2)
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(message, .purchased(.yearly))
        XCTAssertEqual(model.snapshot.phase, .idle)
    }

    func testPurchasePendingCancelledUnverified() async {
        client.purchaseResults = [.success(.pending), .success(.cancelled), .success(.unverified)]
        await model.purchase(.monthly)
        XCTAssertEqual(message, .pending)
        XCTAssertFalse(access.canEdit)
        model.clearMessage()
        await model.purchase(.monthly)
        XCTAssertNil(message)
        await model.purchase(.monthly)
        XCTAssertEqual(message, .failed(StoreStrings.unverified))
        XCTAssertEqual(model.snapshot.phase, .idle)
        XCTAssertEqual(client.purchaseCalls.count, 3)
        XCTAssertEqual(client.entitlementsCalls, 0) // only a success refreshes
    }

    func testPurchaseErrorsAreMapped() async {
        client.purchaseResults = [
            .failure(StoreKitError.networkError(URLError(.notConnectedToInternet))),
            .failure(StoreKitError.notAvailableInStorefront),
            .failure(StoreKitError.userCancelled),
            .failure(URLError(.timedOut)),
            .failure(StoreKitError.unknown),
        ]
        await model.purchase(.yearly)
        XCTAssertEqual(message, .failed(StoreStrings.offline))
        model.clearMessage()
        await model.purchase(.yearly)
        XCTAssertEqual(message, .failed(StoreStrings.notAvailable))
        model.clearMessage()
        await model.purchase(.yearly)
        XCTAssertNil(message)
        await model.purchase(.yearly)
        XCTAssertEqual(message, .failed(StoreStrings.offline))
        model.clearMessage()
        await model.purchase(.yearly)
        XCTAssertEqual(message, .failed(StoreStrings.generic(StoreKitError.unknown)))
        XCTAssertEqual(model.snapshot.phase, .idle)
        XCTAssertFalse(access.canEdit)
    }

    // MARK: - Restore

    func testRestoreMessages() async {
        client.entitlements = [entitlement(.monthly, expires: 20 * day)]
        await model.restore()
        XCTAssertEqual(message, .restored)
        XCTAssertEqual(client.syncCalls, 1)
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(model.snapshot.phase, .idle)

        model.clearMessage()
        client.entitlements = []
        await model.restore()
        XCTAssertEqual(message, .nothingToRestore)
        XCTAssertEqual(client.syncCalls, 2)
        XCTAssertEqual(access, .readOnly(.notSubscribed))

        model.clearMessage()
        client.syncError = URLError(.notConnectedToInternet)
        let callsBefore = client.entitlementsCalls
        await model.restore()
        XCTAssertEqual(message, .failed(StoreStrings.offline))
        XCTAssertEqual(client.syncCalls, 3)
        XCTAssertEqual(client.entitlementsCalls, callsBefore) // a failed sync does not refresh
        XCTAssertEqual(model.snapshot.phase, .idle)
    }

    // MARK: - Updates stream

    func testUpdatesStreamRefreshes() async {
        model.start()
        await awaitFirstRefresh()
        XCTAssertEqual(access, .readOnly(.notSubscribed))
        client.updatesContinuation.yield(entitlement(.monthly, id: 7, expires: 30 * day))
        await waitUntil(access.canEdit)
        XCTAssertEqual(access.plan, .monthly)
        XCTAssertEqual(client.entitlementsCalls, 2)
        XCTAssertEqual(cache.saved?.state, access)
    }

    func testUpdatesCarryRevocation() async {
        model.start()
        await awaitFirstRefresh()
        XCTAssertEqual(access, .readOnly(.notSubscribed))
        client.updatesContinuation.yield(entitlement(.yearly, id: 9, expires: 300 * day, revoked: true))
        await waitUntil(access == .readOnly(.revoked))
        XCTAssertEqual(cache.saved?.state, .readOnly(.revoked))
    }

    func testRenewalsRevocationReplacesTheUpdatesCopy() async {
        // The updates copy of a purchase (no revocation yet) is in memory; the next status query says
        // the same transaction was refunded: the refund wins (§1.4), not the stale copy.
        model.start()
        await awaitFirstRefresh()
        client.updatesContinuation.yield(entitlement(.yearly, id: 5, expires: 300 * day))
        await waitUntil(access.canEdit)
        client.entitlements = []
        client.renewalsResult = .success([
            RenewalInput(productID: Plan.yearly.productID, state: .revoked, willAutoRenew: false, latestTransaction: entitlement(.yearly, id: 5, expires: 300 * day, revoked: true)),
        ])
        await model.refresh()
        XCTAssertEqual(access, .readOnly(.revoked))
        XCTAssertEqual(cache.saved?.state, .readOnly(.revoked))
    }

    // MARK: - Coalescing and the hourly product fetch

    func testRefreshCoalesces() async {
        client.pauseEntitlements = true
        let first = Task { await self.model.refresh(); self.callsAtReturn.append(self.client.entitlementsCalls) }
        await waitUntil(client.entitlementsWaiting == 1)
        let second = Task { await self.model.refresh(); self.callsAtReturn.append(self.client.entitlementsCalls) }
        let third = Task { await self.model.refresh(); self.callsAtReturn.append(self.client.entitlementsCalls) }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(client.entitlementsCalls, 1) // the two late callers did not start runs of their own
        client.pauseEntitlements = false
        client.resumeEntitlements()
        await first.value
        await second.value
        await third.value
        XCTAssertEqual(client.entitlementsCalls, 2) // the running one + one rerun shared by the waiters
        XCTAssertEqual(callsAtReturn, [2, 2, 2]) // all three returned after the rerun
        XCTAssertEqual(client.productsCalls, 1) // the rerun had the offers already
    }

    func testProductsNotRefetchedWithinAnHour() async {
        await model.refresh()
        XCTAssertEqual(client.productsCalls, 1)
        XCTAssertEqual(model.snapshot.offers.count, 2)
        await model.refresh()
        XCTAssertEqual(client.productsCalls, 1)
        clock.now = now.addingTimeInterval(59 * 60)
        await model.refresh()
        XCTAssertEqual(client.productsCalls, 1)
        clock.now = now.addingTimeInterval(61 * 60)
        await model.refresh()
        XCTAssertEqual(client.productsCalls, 2)
        XCTAssertEqual(client.entitlementsCalls, 4)
    }

    func testNormalRefreshKeepsMessage() async {
        client.productsResult = .failure(URLError(.notConnectedToInternet))
        client.purchaseResults = [.success(.success(entitlement(.yearly, id: 3, expires: 365 * day)))]
        await model.purchase(.yearly)
        // The purchase's own (automatic) refresh saw products fail: the message is still .purchased.
        XCTAssertEqual(message, .purchased(.yearly))
        XCTAssertEqual(client.productsCalls, 1)
        XCTAssertTrue(access.canEdit)
        await model.refresh(reason: .automatic)
        XCTAssertEqual(message, .purchased(.yearly))
        XCTAssertEqual(client.productsCalls, 2) // offers are still empty: tried again, failed again
        await model.refresh(reason: .paywall)
        XCTAssertEqual(message, .productsUnavailable)
        XCTAssertEqual(model.snapshot.offers, [])
    }

    // MARK: - Offline rules (reconcile)

    func testOfflineKeepsGraceFromCache() async {
        client.productsResult = .failure(URLError(.notConnectedToInternet))
        client.renewalsResult = .failure(URLError(.notConnectedToInternet))
        client.entitlements = [entitlement(.yearly, expires: -1 * day)]
        cache = MemoryAccessCache(subscribed(until: 5 * day, willAutoRenew: true, inGrace: true))
        makeModel()
        await model.refresh()
        XCTAssertEqual(access, cache.stored?.state)
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(client.renewalsCalls, [FakeStoreClient.groupID])
        XCTAssertFalse(model.snapshot.storeReachable)
        XCTAssertNil(cache.saved)
        XCTAssertEqual(cache.saveCount, 0)
    }

    func testOfflineFirstLaunchIsUnknown() async {
        client.productsResult = .failure(URLError(.notConnectedToInternet))
        client.entitlements = []
        await model.refresh()
        XCTAssertEqual(access, .readOnly(.unknown))
        XCTAssertNil(cache.saved)
        XCTAssertFalse(model.snapshot.storeReachable)
        XCTAssertTrue(model.snapshot.refreshed)
        XCTAssertEqual(PlanText.statusTitle(access), "確認中（閲覧専用）")
    }

    func testOfflineKeepsRevokedFromCache() async {
        client.productsResult = .failure(URLError(.notConnectedToInternet))
        client.entitlements = []
        cache = MemoryAccessCache(AccessSnapshot(state: .readOnly(.revoked), savedAt: now))
        makeModel()
        await model.refresh()
        XCTAssertEqual(access, .readOnly(.revoked))
        XCTAssertEqual(cache.saveCount, 0)
    }

    func testRenewalsUnavailableDoesNotExpire() async {
        client.renewalsResult = .failure(URLError(.timedOut))
        client.entitlements = [entitlement(.yearly, expires: -1 * day)]
        await model.refresh()
        XCTAssertEqual(client.productsCalls, 1)
        XCTAssertEqual(model.snapshot.offers.count, 2) // the store was reached for the products…
        XCTAssertFalse(model.snapshot.storeReachable) // …but the last call (renewals) failed
        XCTAssertEqual(access, .readOnly(.unknown)) // row 13 with renewals == nil
        XCTAssertNil(cache.saved)
    }

    // MARK: - Start-up details

    func testUnfinishedAreFinishedAtStart() async {
        model.start()
        await awaitFirstRefresh()
        XCTAssertEqual(client.finishUnfinishedCalls, 1)
        XCTAssertEqual(client.entitlementsCalls, 1)
        XCTAssertEqual(client.productsCalls, 1)
    }

    func testAwaitFirstRefresh() async {
        let early = await model.awaitFirstRefresh(timeout: .milliseconds(50))
        XCTAssertFalse(early)
        XCTAssertFalse(model.snapshot.refreshed)
        // A waiter that is already waiting is released by the refresh itself.
        let waiter = Task { await self.model.awaitFirstRefresh(timeout: .seconds(5)) }
        await model.refresh()
        let released = await waiter.value
        XCTAssertTrue(released)
        XCTAssertTrue(model.snapshot.refreshed)
        let late = await model.awaitFirstRefresh(timeout: .milliseconds(50))
        XCTAssertTrue(late)
    }

    // MARK: - The UserDefaults cache (§1.3)

    func testUserDefaultsCacheRoundTrip() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "test-\(UUID())"))
        let store = UserDefaultsAccessCache(defaults: defaults)
        XCTAssertEqual(UserDefaultsAccessCache.defaultKey, "accessStateCache")
        XCTAssertEqual(store.key, "accessStateCache")
        XCTAssertNil(store.load())

        let snapshot = subscribed(until: 10 * day)
        store.save(snapshot)
        XCTAssertEqual(store.load(), snapshot)
        XCTAssertNotNil(defaults.data(forKey: "accessStateCache"))
        XCTAssertEqual(defaults.data(forKey: "accessStateCache"), AccessCache.encode(snapshot))

        let trial = AccessSnapshot(state: .trial(Trial(plan: .monthly, until: now.addingTimeInterval(14 * day), willAutoRenew: true)), savedAt: now)
        store.save(trial)
        XCTAssertEqual(store.load(), trial)

        store.clear() // removeObject
        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: "accessStateCache"))

        defaults.set(Data("not a snapshot".utf8), forKey: UserDefaultsAccessCache.defaultKey)
        XCTAssertNil(store.load())

        let other = UserDefaultsAccessCache(defaults: defaults, key: "other")
        other.save(snapshot)
        XCTAssertEqual(other.load(), snapshot)
        XCTAssertNil(store.load())
    }

    // MARK: - Screenshot demo and messages

    func testScreenshotDemo() async {
        let demo = StoreModel.screenshotDemo(access: .readOnly(.notSubscribed))
        XCTAssertEqual(demo.snapshot.access, .readOnly(.notSubscribed))
        XCTAssertTrue(demo.isReadOnly)
        XCTAssertEqual(demo.snapshot.offers.map(\.plan), [.yearly, .monthly])
        XCTAssertEqual(demo.snapshot.offers[0].displayPrice, StoreStrings.demoYearlyPrice)
        XCTAssertEqual(demo.snapshot.offers[0].perMonthDisplayPrice, StoreStrings.demoPerMonthPrice)
        XCTAssertEqual(demo.snapshot.offers[0].price, 2400)
        XCTAssertEqual(demo.snapshot.offers[1].displayPrice, StoreStrings.demoMonthlyPrice)
        XCTAssertNil(demo.snapshot.offers[1].perMonthDisplayPrice)
        XCTAssertEqual(demo.snapshot.offers[1].price, 300)
        XCTAssertTrue(demo.snapshot.offers.allSatisfy { $0.isEligibleForIntroOffer && $0.introDays == 14 })
        XCTAssertTrue(demo.snapshot.refreshed)
        XCTAssertTrue(demo.snapshot.storeReachable)
        XCTAssertEqual(demo.snapshot.phase, .idle)
        XCTAssertNil(demo.snapshot.message)
        // Nothing moves it.
        demo.start()
        await demo.refresh()
        await demo.purchase(.yearly)
        await demo.restore()
        XCTAssertEqual(demo.snapshot.access, .readOnly(.notSubscribed))
        XCTAssertNil(demo.snapshot.message)
        let done = await demo.awaitFirstRefresh(timeout: .milliseconds(10))
        XCTAssertTrue(done)
        // The yen sign of the fixed prices is U+00A5 (a device may show U+FFE5).
        XCTAssertEqual(StoreStrings.demoYearlyPrice.unicodeScalars.first?.value, 0xA5)
        XCTAssertEqual(StoreStrings.demoMonthlyPrice.filter(\.isNumber), "300")
        XCTAssertEqual(StoreStrings.demoYearlyPrice.filter(\.isNumber), "2400")
        XCTAssertEqual(StoreStrings.demoPerMonthPrice.filter(\.isNumber), "200")

        let subscriber = StoreModel.screenshotDemo(access: StoreModel.demoSubscription(today: now), eligible: false)
        XCTAssertEqual(subscriber.snapshot.access, .subscribed(Subscription(plan: .yearly, until: now.addingTimeInterval(200 * day), willAutoRenew: true, inGrace: false)))
        XCTAssertFalse(subscriber.isReadOnly)
        XCTAssertTrue(subscriber.snapshot.offers.allSatisfy { !$0.isEligibleForIntroOffer })
    }

    func testMakeInTheTestHostIsInert() async {
        // The XCTest host gets the screenshot demo (no StoreKit configuration while the unit tests run).
        let hosted = StoreModel.make()
        XCTAssertFalse(hosted.isReadOnly)
        XCTAssertTrue(hosted.snapshot.refreshed)
        hosted.start()
        await hosted.refresh()
        XCTAssertFalse(hosted.isReadOnly)
        let readOnly = StoreModel.make(screenshotReadOnly: true)
        XCTAssertFalse(readOnly.isReadOnly) // not in screenshot mode: the argument does not apply
    }

    func testMessageTexts() {
        let trial = AccessState.trial(Trial(plan: .yearly, until: now.addingTimeInterval(14 * day), willAutoRenew: true))
        let paid = AccessState.subscribed(Subscription(plan: .yearly, until: now.addingTimeInterval(365 * day), willAutoRenew: true, inGrace: false))
        XCTAssertEqual(StoreStrings.text(for: .purchased(.yearly), access: trial), StoreStrings.trialStarted)
        XCTAssertEqual(StoreStrings.trialStarted, "14 日間の無料試用を開始しました")
        XCTAssertEqual(StoreStrings.text(for: .purchased(.yearly), access: paid), "購読を開始しました。ありがとうございます")
        XCTAssertEqual(StoreStrings.text(for: .restored, access: paid), "購入を復元しました")
        XCTAssertEqual(StoreStrings.text(for: .nothingToRestore, access: .readOnly(.notSubscribed)), StoreStrings.nothingToRestore)
        XCTAssertEqual(StoreStrings.text(for: .pending, access: .readOnly(.notSubscribed)), "承認待ちです。承認されると自動で使えるようになります")
        XCTAssertEqual(StoreStrings.text(for: .productsUnavailable, access: .readOnly(.notSubscribed)), StoreStrings.productsUnavailable)
        XCTAssertEqual(StoreStrings.text(for: .failed("x"), access: .readOnly(.notSubscribed)), "x")
        XCTAssertTrue(StoreStrings.nothingToRestore.contains("Apple Account"))
        XCTAssertTrue(StoreStrings.productsUnavailable.contains("再読み込み"))
        XCTAssertTrue(StoreStrings.unverified.contains("購入を復元"))

        XCTAssertNil(StoreStrings.failure(StoreKitError.userCancelled))
        XCTAssertEqual(StoreStrings.failure(StoreKitError.networkError(URLError(.timedOut))), .failed(StoreStrings.offline))
        XCTAssertEqual(StoreStrings.failure(URLError(.cannotFindHost)), .failed(StoreStrings.offline))
        XCTAssertEqual(StoreStrings.failure(StoreKitError.notAvailableInStorefront), .failed(StoreStrings.notAvailable))
        XCTAssertEqual(StoreStrings.failure(StoreKitError.unknown), .failed(StoreStrings.generic(StoreKitError.unknown)))
        XCTAssertTrue(StoreStrings.generic(StoreKitError.unknown).hasPrefix("購入できませんでした（"))
    }

    func testOffersFromProducts() {
        let unknown = StoreProduct(id: "com.example.other", displayPrice: "¥1", price: 1, subscriptionGroupID: nil, isEligibleForIntroOffer: false, introDays: nil, perMonthDisplayPrice: nil)
        let offers = StoreModel.offers(from: [unknown] + FakeStoreClient.demoProducts)
        XCTAssertEqual(offers.map(\.plan), [.yearly, .monthly])
        XCTAssertEqual(offers[0].price, 2400)
        XCTAssertEqual(offers[0].introDays, 14)
        XCTAssertEqual(offers[1].displayPrice, StoreStrings.demoMonthlyPrice)
        XCTAssertEqual(StoreModel.offers(from: []), [])
    }
}
