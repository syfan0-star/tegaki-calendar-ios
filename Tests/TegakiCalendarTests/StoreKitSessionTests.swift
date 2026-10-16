import Access
import StoreKit
import StoreKitTest
import XCTest
@testable import TegakiCalendar

/// `LiveStoreClient` and `StoreModel` against StoreKit's test environment (M5_CONTRACT §7.3.1):
/// `Support/Products.storekit` is loaded into an `SKTestSession` (the format check of §7.1), then a
/// purchase made outside the app (`session.buyProduct`) starts the trial, an expiry ends it, a
/// refund revokes it, a used trial removes the intro-offer eligibility and the `Transaction.updates`
/// listener refreshes on its own. The App Store itself is never contacted and `AppStore.sync()` is
/// never called (it may ask for a sign-in in the test environment).
///
/// Timing: `Transaction.updates` and the status queries take a few hundred milliseconds to reflect a
/// `buyProduct` / `expireSubscription` / `refundTransaction`, so the state assertions poll
/// (`waitUntil`, `refreshUntil`; the same polling as `TestSleeper`'s tests) up to 5 seconds.
@MainActor
final class StoreKitSessionTests: XCTestCase {
    private var session: SKTestSession!
    private var client: LiveStoreClient!
    private var model: StoreModel!
    private let day: TimeInterval = 86_400

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()
        session.storefront = "JPN"
        session.locale = Locale(identifier: "ja_JP")
        try await skipUnlessTheTestEnvironmentWorks()
        client = LiveStoreClient()
        model = StoreModel(client: client, cache: NoopAccessCache())
    }

    /// The simulators of Xcode 26.3–26.6 reject every SKTestSession write ("[SKTestSession] Error saving
    /// configuration file: Error Domain=SKInternalErrorDomain Code=3", the same for clearTransactions /
    /// storefront / locale; Apple forums 830493 and 836842, FB22836426 / FB23566876, fixed in the iOS 26.6
    /// simulator runtime): the storefront then stays USA (the products come back as $1.99 / $14.99) and
    /// `buyProduct` throws `StoreKitError.notEntitled` (CI run 38958098578). Until the runner has a working
    /// runtime these tests are skipped instead of failing (M5_CONTRACT §7.3.3; the fakes of
    /// StoreModelTests stay the required coverage; docs/M5.md §3).
    private func skipUnlessTheTestEnvironmentWorks() async throws {
        var storefront = await Storefront.current?.countryCode
        let deadline = Date().addingTimeInterval(3)
        while storefront != "JPN", Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            storefront = await Storefront.current?.countryCode
        }
        if storefront == "JPN" { return }
        // The storefront may lag the first product request in a working environment: the file's price
        // (¥300 under JPN) is the second witness.
        let monthly = try? await Product.products(for: [Plan.monthly.productID]).first
        if monthly?.price == 300 { return }
        throw XCTSkip("StoreKit test environment unavailable on this simulator: SKTestSession's storefront stayed \(storefront ?? "nil"), monthly price \(monthly.map { "\($0.price)" } ?? "nil") (Xcode 26.3–26.6 defect; docs/M5.md §3)")
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        model = nil
        client = nil
        session = nil
    }

    // MARK: - Helpers

    private var access: AccessState { model.snapshot.access }
    /// `.trial` specifically (row 9), not the `.subscribed` of row 5 that a status without its
    /// transaction could give while `currentEntitlements` is still empty.
    private var isTrial: Bool {
        if case .trial = access { return true }
        return false
    }

    /// Polls `condition` every 50 ms until it holds or `timeout` seconds pass (then fails).
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        if condition() { return true }
        XCTFail("timed out after \(timeout) s; access = \(String(describing: model?.snapshot.access))", file: file, line: line)
        return false
    }

    /// `refresh()`, then checks `condition`; repeats every 100 ms until it holds or `timeout` seconds
    /// pass (then fails). The test environment reflects a purchase / expiry / refund with a short delay.
    @discardableResult
    private func refreshUntil(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            await model.refresh()
            if condition() { return true }
            if Date() >= deadline { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("timed out after \(timeout) s; access = \(String(describing: model.snapshot.access))", file: file, line: line)
        return false
    }

    /// Polls an async `condition` every 100 ms until it holds or `timeout` seconds pass (then fails).
    @discardableResult
    private func pollUntil(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line, _ condition: () async throws -> Bool) async rethrows -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if try await condition() { return true }
            if Date() >= deadline { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("timed out after \(timeout) s", file: file, line: line)
        return false
    }

    /// `session.buyProduct` (a purchase outside the app, as the App Store's own sheet would make it).
    @discardableResult
    private func buy(_ plan: Plan, file: StaticString = #filePath, line: UInt = #line) async throws -> Transaction {
        let transaction = try await session.buyProduct(identifier: plan.productID)
        XCTAssertEqual(transaction.productID, plan.productID, file: file, line: line)
        return transaction
    }

    private func product(_ plan: Plan, in products: [StoreProduct], file: StaticString = #filePath, line: UInt = #line) throws -> StoreProduct {
        try XCTUnwrap(products.first { $0.id == plan.productID }, "\(plan.productID) missing", file: file, line: line)
    }

    // MARK: - Tests

    /// The format check of §7.1: the session loads both products with the contract's prices, the
    /// 14-day free trial and a subscription group.
    func testConfigurationLoadsBothProducts() async throws {
        let products = try await client.products(ids: ProductIDs.all)
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(products.map(\.id), [Plan.monthly.productID, Plan.yearly.productID]) // Plan.allCases order

        let monthly = try product(.monthly, in: products)
        XCTAssertEqual(monthly.price, 300)
        XCTAssertEqual(monthly.displayPrice.filter(\.isNumber), "300") // the yen sign may be 「￥」 (U+FFE5) in ja_JP
        XCTAssertEqual(monthly.introDays, 14)
        XCTAssertNil(monthly.perMonthDisplayPrice)
        XCTAssertNotNil(monthly.subscriptionGroupID)
        XCTAssertTrue(monthly.isEligibleForIntroOffer)

        let yearly = try product(.yearly, in: products)
        XCTAssertEqual(yearly.price, 2400)
        XCTAssertEqual(yearly.displayPrice.filter(\.isNumber), "2400")
        XCTAssertEqual(yearly.introDays, 14)
        XCTAssertEqual(yearly.perMonthDisplayPrice?.filter(\.isNumber), "200")
        XCTAssertNotNil(yearly.subscriptionGroupID)
        XCTAssertEqual(yearly.subscriptionGroupID, monthly.subscriptionGroupID)
        XCTAssertTrue(yearly.isEligibleForIntroOffer)

        // Through the model: offers yearly first, the store reached, nothing to edit yet.
        await model.refresh()
        XCTAssertEqual(model.snapshot.offers.map(\.plan), [.yearly, .monthly])
        XCTAssertTrue(model.snapshot.storeReachable)
        XCTAssertTrue(model.snapshot.refreshed)
        XCTAssertEqual(access, .readOnly(.notSubscribed))
    }

    /// The first purchase of the group is the free trial: `.trial(.monthly, willAutoRenew: true)`
    /// ending 14 days from now.
    func testBuyingMonthlyStartsATrial() async throws {
        let transaction = try await buy(.monthly)
        let bought = Date()
        await refreshUntil { isTrial }
        guard case .trial(let trial) = access else {
            return XCTFail("expected .trial, got \(access)")
        }
        XCTAssertEqual(trial.plan, .monthly)
        XCTAssertTrue(trial.willAutoRenew)
        let days = trial.until.timeIntervalSince(bought) / day
        XCTAssertGreaterThanOrEqual(days, 13, "trial ends \(trial.until)")
        XCTAssertLessThanOrEqual(days, 15, "trial ends \(trial.until)")
        let expiration = try XCTUnwrap(transaction.expirationDate)
        XCTAssertEqual(trial.until.timeIntervalSince1970, expiration.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(access.plan, .monthly)
        XCTAssertFalse(model.isReadOnly)
        XCTAssertTrue(model.snapshot.storeReachable)
        XCTAssertNil(model.snapshot.message)

        // The copy LiveStoreClient makes of the same transaction (`currentEntitlements` may lag the
        // status by a moment).
        await pollUntil {
            await client.currentEntitlements().map(\.id) == [transaction.id]
        }
        let entitlements = await client.currentEntitlements()
        XCTAssertEqual(entitlements.map(\.id), [transaction.id])
        XCTAssertEqual(entitlements.first?.isIntroductory, true)
        XCTAssertEqual(entitlements.first?.subscriptionGroupID, transaction.subscriptionGroupID)
        XCTAssertNil(entitlements.first?.revocationDate)
    }

    /// `expireSubscription` → the next refresh is read only with the reason 「期限切れ」.
    func testExpiringMakesItReadOnly() async throws {
        try await buy(.monthly)
        await refreshUntil { access.canEdit }
        try session.expireSubscription(productIdentifier: Plan.monthly.productID)
        await refreshUntil { access == .readOnly(.expired) }
        XCTAssertEqual(access, .readOnly(.expired))
        XCTAssertTrue(model.isReadOnly)
        XCTAssertTrue(model.snapshot.storeReachable) // an expiry is the store's answer, not an outage
    }

    /// `refundTransaction` → `.readOnly(.revoked)`. `Transaction.currentEntitlements` never returns the
    /// refunded transaction, so the state comes from `renewals` (`state == .revoked`, rule 7, or its
    /// `latestTransaction` with a `revocationDate`, rule 1) or from the `Transaction.updates` copy
    /// (rule 1); the route taken is logged as `store-test: refund route …` for docs/M5.md.
    func testRefundRevokes() async throws {
        model.start()
        let started = await model.awaitFirstRefresh(timeout: .seconds(5))
        XCTAssertTrue(started)
        let transaction = try await buy(.yearly)
        await refreshUntil { access.canEdit }

        try session.refundTransaction(identifier: UInt(transaction.id))
        await refreshUntil { access == .readOnly(.revoked) }
        XCTAssertEqual(access, .readOnly(.revoked))
        XCTAssertTrue(model.isReadOnly)

        // Which route carried the revocation (both may be true).
        let entitlements = await client.currentEntitlements()
        XCTAssertFalse(entitlements.contains { $0.id == transaction.id && $0.revocationDate == nil }, "a refunded transaction must not be a current entitlement")
        var route: [String] = []
        if let groupID = transaction.subscriptionGroupID, let renewals = try? await client.renewals(groupID: groupID) {
            if renewals.contains(where: { $0.state == .revoked }) { route.append("renewals.state == .revoked (rule 7)") }
            if renewals.contains(where: { $0.latestTransaction?.revocationDate != nil }) { route.append("renewals.latestTransaction.revocationDate (rule 1)") }
        }
        if entitlements.contains(where: { $0.revocationDate != nil }) { route.append("currentEntitlements with revocationDate (unexpected)") }
        NSLog("store-test: refund route = %@", route.isEmpty ? "Transaction.updates copy only (rule 1)" : route.joined(separator: " + "))
    }

    /// The intro offer is per subscription group: after a trial has run (and expired) neither
    /// product is eligible any more.
    func testIneligibleAfterATrial() async throws {
        let before = try await client.products(ids: ProductIDs.all)
        XCTAssertTrue(before.allSatisfy(\.isEligibleForIntroOffer))

        try await buy(.monthly)
        await refreshUntil { access.canEdit }
        try session.expireSubscription(productIdentifier: Plan.monthly.productID)
        await refreshUntil { access == .readOnly(.expired) }

        try await pollUntil {
            let products = try await client.products(ids: ProductIDs.all)
            return !products.contains(where: \.isEligibleForIntroOffer)
        }
        let after = try await client.products(ids: ProductIDs.all)
        XCTAssertEqual(after.count, 2)
        XCTAssertFalse(try product(.monthly, in: after).isEligibleForIntroOffer)
        XCTAssertFalse(try product(.yearly, in: after).isEligibleForIntroOffer)
    }

    /// `start()` subscribes to `Transaction.updates`: a purchase made outside the app reaches the
    /// model without anyone calling `refresh()`.
    func testUpdatesStreamTriggersRefresh() async throws {
        model.start()
        let started = await model.awaitFirstRefresh(timeout: .seconds(5))
        XCTAssertTrue(started)
        XCTAssertEqual(access, .readOnly(.notSubscribed))

        try await buy(.yearly)
        await waitUntil(timeout: 5) { model.snapshot.access.canEdit }
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(access.plan, .yearly)
        XCTAssertNil(model.snapshot.message) // a purchase outside the app shows no toast
    }

    /// The restore of §7.3.1 without `AppStore.sync()`: cleared transactions → 「未購読」; a new
    /// purchase appears in `currentEntitlements` and the next refresh has the right again.
    func testRestoreAfterClearingTransactions() async throws {
        try await buy(.yearly)
        await refreshUntil { access.canEdit }

        session.clearTransactions()
        await refreshUntil { access == .readOnly(.notSubscribed) }
        let cleared = await client.currentEntitlements()
        XCTAssertEqual(cleared, [])

        let transaction = try await buy(.yearly)
        await pollUntil {
            await client.currentEntitlements().contains { $0.id == transaction.id }
        }
        let entitlements = await client.currentEntitlements()
        XCTAssertTrue(entitlements.contains { $0.id == transaction.id })
        await refreshUntil { access.canEdit }
        XCTAssertEqual(access.plan, .yearly)
    }
}
