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
/// Timing: `Transaction.updates` and the status queries usually take a few hundred milliseconds to reflect a
/// `buyProduct` / `expireSubscription` / `refundTransaction`, so the state assertions poll (`awaitAction`,
/// `refreshUntil`, `pollUntil`; the same polling as `TestSleeper`'s tests). The limits are the constants at the top
/// of the class.
///
/// iOS 27.2 (24B8117; 1.4 D0b, docs/M7D.md "D0b"), the first runtime on which CI runs these tests (1.3's
/// simulators skipped them all, see `skipUnlessTheTestEnvironmentWorks`): its test environment keeps the
/// intro-offer eligibility true after an expired free trial in the group's history. In probe run 44659376399
/// the per-group answer and both products' said true in 41–42 reads over 15 seconds, with and without a read
/// before the purchase, and also after `clearTransactions()`. `testIneligibleAfterATrial` therefore reads
/// nothing before the purchase, nor until the history shows it, and, when the answer stays true while
/// `Transaction.all` holds the expired introductory transaction, logs the evidence (`store-test: eligibility
/// after the trial = …`) and skips; any other outcome is asserted as before. The app shows StoreKit's answer as it is (`LiveStoreClient`), so no
/// app code changes for it.
///
/// iOS 27.2 test environment timing (1.4 D3, docs/M7D.md): CI run 44802640918 (r14 283b7ed) failed here twice in three
/// attempts on what the environment did, not on what the app answered (the store's code is 1.3's). In attempt 2,
/// StoreKit's own answers (the `store: entitlements` / `store: renewals` lines, before any app logic) still said "intro
/// entitlement, subscribed" in 48 refreshes over 5.1 s after `expireSubscription`: the expiry came late or was lost. In
/// attempt 3, after `model.start()` and a purchase, the only `Transaction.updates` delivery in 5 s (3 s after the
/// purchase) was the transaction testRefundRevokes had refunded about 6.6 s earlier, with the purchase's id 0 (ids start
/// at 0 again after `clearTransactions()`); the purchase's own update did not come, and no refresh followed the stale
/// one (a StoreKit call stalled). `StoreModel` keeps the updates' copies by transaction id and a copy wins over
/// `currentEntitlements`, so such a leftover hides a new purchase with its id until the purchase's own update replaces
/// it; real ids are unique, so only this environment can do that. The waits therefore tell the environment from the
/// app: `awaitAction` first waits for the raw state (`Transaction.currentEntitlements` and
/// `Product.SubscriptionInfo.status(for:)`, read directly: `RawStoreState`) to show the action, up to `envTimeout`,
/// issuing an expiry or a refund once more after `reissueAfter` (`store-test: expiry re-issued after …`), and only then
/// requires the app's exact state, within `appTimeout`. A raw state that never shows the action fails with the evidence
/// (the raw answers and `Transaction.all`), never skips. testUpdatesStreamTriggersRefresh still never refreshes; the
/// app's own listener gets `updatesTimeout`. setUp waits up to `settleTimeout` for an empty raw state. Every wait keeps
/// the 5 s it had before; anything longer is drawn from `extraWaitBudget`, so the class ends within about 3 minutes.
@MainActor
final class StoreKitSessionTests: XCTestCase {
    // MARK: - Waits (1.4 D3, the class's comment)

    /// After the raw state shows an action, the app must reach the asserted state within this many seconds (its model
    /// refreshed on every poll). Every wait gets at least this much without drawing on `extraWaitBudget`: the whole wait
    /// of each assertion before 1.4.
    nonisolated private static let appTimeout: TimeInterval = 5
    /// How long one action (a purchase, an expiry, a refund, `clearTransactions()`) may take to show in the raw state.
    nonisolated private static let envTimeout: TimeInterval = 30
    /// An expiry or a refund the raw state has not shown after this many seconds is issued once more.
    nonisolated private static let reissueAfter: TimeInterval = 10
    /// testUpdatesStreamTriggersRefresh: how long after the purchase the app's own `Transaction.updates` listener may
    /// take (and at least `appTimeout` after the raw state shows the purchase). An update can come several seconds late,
    /// and a late one of an earlier test with the same id stands in for the purchase until the purchase's own replaces it.
    nonisolated private static let updatesTimeout: TimeInterval = 30
    /// setUp waits up to this long for an empty raw state after `clearTransactions()` / `resetToDefaultState()`.
    nonisolated private static let settleTimeout: TimeInterval = 5
    /// What all the waits of the class in one test process may spend beyond their `appTimeout` together (setUp's
    /// settle counts from 0). Once it is spent, every wait is as long as before 1.4 and fails as it did. So the 8 tests
    /// wait at most 17 × `appTimeout` (85 s) plus this, besides setUp's storefront check and the StoreKit calls' own time.
    nonisolated private static let extraWaitBudget: TimeInterval = 80

    /// How much of `extraWaitBudget` this test process has spent.
    private static var extraWaitSpent: TimeInterval = 0
    /// The subscription group, from the process's first purchase (setUp's settle reads its status).
    private static var knownGroupID: String?

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
        await settle()
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

    /// What an earlier test left (1.4 D3): after `clearTransactions()` / `resetToDefaultState()` the raw state should be
    /// empty (no current entitlement and, once a purchase has named the group, no status). Waits for that up to
    /// `settleTimeout`, logs how long it took and goes on either way (each test asserts what it needs). An update the
    /// environment has yet to deliver is not seen here: only a listener gets it, and the tests finish nothing themselves.
    private func settle() async {
        let start = Date()
        let limit = min(Self.settleTimeout, budgetLeft)
        var raw = await readRaw(groupID: Self.knownGroupID)
        while !raw.isEmpty, Date().timeIntervalSince(start) < limit {
            try? await Task.sleep(for: .milliseconds(100))
            raw = await readRaw(groupID: Self.knownGroupID)
        }
        let elapsed = Date().timeIntervalSince(start)
        spend(elapsed, base: 0)
        log(raw.isEmpty
            ? "setUp: raw state empty after \(seconds(elapsed)) s"
            : "setUp: raw state NOT empty after \(seconds(elapsed)) s (going on): \(raw.text)")
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

    /// `refresh()`, then checks `condition`; repeats every 100 ms until it holds or `timeout` seconds
    /// pass (then fails). The test environment reflects a purchase / expiry / refund with a short delay.
    @discardableResult
    private func refreshUntil(timeout: TimeInterval = appTimeout, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async -> Bool {
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
    private func pollUntil(timeout: TimeInterval = appTimeout, file: StaticString = #filePath, line: UInt = #line, _ condition: () async throws -> Bool) async rethrows -> Bool {
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
        if let groupID = transaction.subscriptionGroupID {
            Self.knownGroupID = groupID
        }
        return transaction
    }

    private func product(_ plan: Plan, in products: [StoreProduct], file: StaticString = #filePath, line: UInt = #line) throws -> StoreProduct {
        try XCTUnwrap(products.first { $0.id == plan.productID }, "\(plan.productID) missing", file: file, line: line)
    }

    // MARK: - The environment's waits (1.4 D3)

    /// StoreKit's own answers, read directly (the calls `LiveStoreClient` makes, before any app logic): the verified
    /// `Transaction.currentEntitlements` and, when the group is known, `Product.SubscriptionInfo.status(for:)`.
    private func readRaw(groupID: String?) async -> RawStoreState {
        var raw = RawStoreState()
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                raw.entitlements.append(LiveStoreClient.copy(transaction))
            case .unverified:
                raw.unverified += 1
            }
        }
        guard let groupID else { return raw }
        do {
            for status in try await Product.SubscriptionInfo.status(for: groupID) {
                var transaction: EntitlementInput?
                if case .verified(let item) = status.transaction {
                    transaction = LiveStoreClient.copy(item)
                }
                raw.statuses.append(RawStoreState.Status(state: LiveStoreClient.renewalState(status.state), transaction: transaction))
            }
        } catch {
            raw.statusError = "\(error)"
        }
        return raw
    }

    /// `Transaction.all` (verified or not), one item each: the evidence of a raw wait that ran out.
    private func allTransactions() async -> String {
        var items: [String] = []
        for await result in Transaction.all {
            switch result {
            case .verified(let item):
                items.append(RawStoreState.describe(LiveStoreClient.copy(item)))
            case .unverified(let item, _):
                items.append("unverified " + RawStoreState.describe(LiveStoreClient.copy(item)))
            }
        }
        return items.isEmpty ? "none" : items.joined(separator: "; ")
    }

    /// What is left of `extraWaitBudget` in this test process.
    private var budgetLeft: TimeInterval { max(0, Self.extraWaitBudget - Self.extraWaitSpent) }

    /// Books a wait of `elapsed` seconds that had `base` seconds of its own.
    private func spend(_ elapsed: TimeInterval, base: TimeInterval) {
        Self.extraWaitSpent += max(0, elapsed - base)
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.1f", value)
    }

    private func log(_ text: String) {
        NSLog("store-test: %@", text)
    }

    /// Records (and logs) a raw wait that ran out: how long, why it stopped there, the last raw answers,
    /// `Transaction.all` and the app's access. A failure, never a skip.
    private func failEnvironment(_ label: String, elapsed: TimeInterval, limit: TimeInterval, reissue: String?,
                                 raw: RawStoreState, file: StaticString, line: UInt) async {
        let why = limit < Self.envTimeout ? "the class's extra wait budget was spent" : "envTimeout"
        let all = await allTransactions()
        let message = "\(label): StoreKit's test environment did not show it in \(seconds(elapsed)) s (limit "
            + "\(seconds(limit)) s, \(why))\(reissue.map { "; \($0)" } ?? ""); "
            + "\(ProcessInfo.processInfo.operatingSystemVersionString); raw: \(raw.text); Transaction.all: \(all); access \(access)"
        log(message)
        XCTFail(message, file: file, line: line)
    }

    /// Waits for what an action did, in two steps: until the raw state shows it (`raw`), up to `envTimeout`; then until
    /// the app reaches the asserted state (`app`), up to `appTimeout` more. Every poll (100 ms) refreshes the model first,
    /// and the app reaching the state ends the wait at once, also before the raw state shows it (a refund the update
    /// carried). `reissue` (an expiry or a refund) is called once more when the raw state has not shown the action after
    /// `reissueAfter`. A step that runs out fails: the raw state never showing the action with the environment's evidence,
    /// the app not following it as the app's failure. Anything beyond `appTimeout` in all draws on `extraWaitBudget`.
    /// The times and the route (first call or re-issued) are logged as `store-test: <label>: …`.
    @discardableResult
    private func awaitAction(_ label: String, groupID: String?, reissue: (() throws -> Void)? = nil,
                             file: StaticString = #filePath, line: UInt = #line,
                             raw rawShows: (RawStoreState) -> Bool, app appReached: () -> Bool) async -> Bool {
        let start = Date()
        let cap = Self.appTimeout + budgetLeft
        let rawLimit = min(Self.envTimeout, cap)
        var rawAt: TimeInterval?
        var reissuedAt: TimeInterval?
        var last = RawStoreState()
        func route() -> String {
            guard reissue != nil else { return "" }
            return reissuedAt.map { ", route: re-issued call (at \(seconds($0)) s)" } ?? ", route: first call"
        }
        while true {
            await model.refresh()
            if appReached() {
                let elapsed = Date().timeIntervalSince(start)
                spend(elapsed, base: Self.appTimeout)
                log("\(label): app after \(seconds(elapsed)) s, raw \(rawAt.map { "after \(seconds($0)) s" } ?? "not seen before")\(route())")
                return true
            }
            if rawAt == nil {
                last = await readRaw(groupID: groupID)
                if rawShows(last) { rawAt = Date().timeIntervalSince(start) }
            }
            let elapsed = Date().timeIntervalSince(start)
            if let rawAt {
                if elapsed >= min(rawAt + Self.appTimeout, cap) {
                    spend(elapsed, base: Self.appTimeout)
                    let cut = rawAt + Self.appTimeout > cap ? " (cut: the class's extra wait budget was spent)" : ""
                    let message = "\(label): the raw state showed it after \(seconds(rawAt)) s\(route()), but the app did not reach "
                        + "the asserted state by \(seconds(elapsed)) s\(cut): access \(access); raw then: \(last.text)"
                    log(message)
                    XCTFail(message, file: file, line: line)
                    return false
                }
            } else {
                if let reissue, reissuedAt == nil, elapsed >= Self.reissueAfter, elapsed < rawLimit {
                    reissuedAt = elapsed
                    do {
                        try reissue()
                        log("\(label) re-issued after \(seconds(elapsed)) s")
                    } catch {
                        log("\(label) re-issued after \(seconds(elapsed)) s; it threw \(error)")
                    }
                }
                if elapsed >= rawLimit {
                    spend(elapsed, base: Self.appTimeout)
                    var reissueText: String?
                    if reissue != nil {
                        reissueText = reissuedAt.map { "issued once more at \(seconds($0)) s" } ?? "not issued again (the limit came first)"
                    }
                    await failEnvironment(label, elapsed: elapsed, limit: rawLimit, reissue: reissueText, raw: last, file: file, line: line)
                    return false
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// A raw wait alone (the trial in the history, the restore's second purchase): polls `condition` every 100 ms up to
    /// `envTimeout` (beyond `appTimeout` on `extraWaitBudget`); running out fails with the environment's evidence.
    @discardableResult
    private func awaitRaw(_ label: String, groupID: String?, file: StaticString = #filePath, line: UInt = #line,
                          _ condition: () async -> Bool) async -> Bool {
        let start = Date()
        let limit = min(Self.envTimeout, Self.appTimeout + budgetLeft)
        while true {
            if await condition() {
                let elapsed = Date().timeIntervalSince(start)
                spend(elapsed, base: Self.appTimeout)
                log("\(label): raw after \(seconds(elapsed)) s")
                return true
            }
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= limit {
                spend(elapsed, base: Self.appTimeout)
                let raw = await readRaw(groupID: groupID)
                await failEnvironment(label, elapsed: elapsed, limit: limit, reissue: nil, raw: raw, file: file, line: line)
                return false
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// testUpdatesStreamTriggersRefresh's wait, with no refresh by the test: until the app reaches `app` on its own, up
    /// to `updatesTimeout` after the purchase and at least `appTimeout` after the raw state shows it (every 100 ms); the
    /// raw state must show the purchase within `envTimeout`. Beyond `appTimeout` it draws on `extraWaitBudget`. Each
    /// change of the app's access is logged with its time (a late update of an earlier test shows as
    /// `.readOnly(.revoked)` before the purchase's own update); the app's `store: update:` lines show what its listener got.
    @discardableResult
    private func awaitUpdates(_ label: String, groupID: String?, file: StaticString = #filePath, line: UInt = #line,
                              raw rawShows: (RawStoreState) -> Bool, app appReached: () -> Bool) async -> Bool {
        let start = Date()
        let cap = Self.appTimeout + budgetLeft
        let rawLimit = min(Self.envTimeout, cap)
        var rawAt: TimeInterval?
        var changes: [String] = []
        var seen: AccessState?
        while true {
            let elapsed = Date().timeIntervalSince(start)
            if access != seen {
                seen = access
                changes.append("+\(seconds(elapsed)) s \(access)")
            }
            if appReached() {
                spend(elapsed, base: Self.appTimeout)
                log("\(label): the app's listener reached it after \(seconds(elapsed)) s, raw "
                    + "\(rawAt.map { "after \(seconds($0)) s" } ?? "not seen before"); access \(changes.joined(separator: " → "))")
                return true
            }
            if rawAt == nil {
                let raw = await readRaw(groupID: groupID)
                let read = Date().timeIntervalSince(start)
                if rawShows(raw) {
                    rawAt = read
                } else if read >= rawLimit {
                    spend(read, base: Self.appTimeout)
                    await failEnvironment(label, elapsed: read, limit: rawLimit, reissue: nil, raw: raw, file: file, line: line)
                    return false
                }
            }
            let ended = Date().timeIntervalSince(start)
            if let rawAt, ended >= min(max(Self.updatesTimeout, rawAt + Self.appTimeout), cap) {
                spend(ended, base: Self.appTimeout)
                let raw = await readRaw(groupID: groupID)
                let all = await allTransactions()
                let cut = max(Self.updatesTimeout, rawAt + Self.appTimeout) > cap ? " (cut: the class's extra wait budget was spent)" : ""
                let message = "\(label): the raw state showed the purchase after \(seconds(rawAt)) s, but the app's listener did not "
                    + "bring the app to the asserted state by \(seconds(ended)) s\(cut): access \(changes.joined(separator: " → ")); "
                    + "raw now: \(raw.text); Transaction.all: \(all)"
                log(message)
                XCTFail(message, file: file, line: line)
                return false
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
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

    /// 1.2 (docs/M7B_CONTRACT.md §7.2): the prices of a US storefront, as the paywall shows them. The
    /// test environment takes the prices of `Products.storekit` (yen) under any storefront unless the
    /// simulator's defect above answers with the App Store's own, so this skips unless the storefront
    /// really gives the US prices (docs/M7B.md); `PaywallSheetTests.testUSPricesOnTheYearlyNote` is the
    /// coverage that always runs.
    func testUSStorefrontPrices() async throws {
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        let products = try await client.products(ids: ProductIDs.all)
        let monthly = try product(.monthly, in: products)
        let yearly = try product(.yearly, in: products)
        guard monthly.price == Decimal(string: "1.99") else {
            throw XCTSkip("the test environment gives \(monthly.price) under USA, not the App Store's $1.99")
        }
        XCTAssertEqual(monthly.displayPrice, "$1.99")
        XCTAssertEqual(yearly.displayPrice, "$14.99")
        XCTAssertEqual(yearly.perMonthDisplayPrice, "$1.25")
        XCTAssertEqual(PlanText.savingsMonths(monthly: monthly.price, yearly: yearly.price), 4)
    }

    /// The first purchase of the group is the free trial: `.trial(.monthly, willAutoRenew: true)`
    /// ending 14 days from now.
    func testBuyingMonthlyStartsATrial() async throws {
        let transaction = try await buy(.monthly)
        let bought = Date()
        await awaitAction("purchase", groupID: transaction.subscriptionGroupID, raw: { $0.holds(transaction) }, app: { isTrial })
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

    /// `expireSubscription` → the next refresh is read only with the reason 「期限切れ」. The expiry is issued once more
    /// when the raw state has not shown it after `reissueAfter` (attempt 2 of run 44802640918; the class's comment).
    func testExpiringMakesItReadOnly() async throws {
        let transaction = try await buy(.monthly)
        let groupID = transaction.subscriptionGroupID
        guard await awaitAction("purchase", groupID: groupID, raw: { $0.holds(transaction) }, app: { access.canEdit }) else { return }
        try session.expireSubscription(productIdentifier: Plan.monthly.productID)
        await awaitAction("expiry", groupID: groupID,
                          reissue: { try self.session.expireSubscription(productIdentifier: Plan.monthly.productID) },
                          raw: { $0.showsExpiry(now: Date()) }, app: { access == .readOnly(.expired) })
        XCTAssertEqual(access, .readOnly(.expired))
        XCTAssertTrue(model.isReadOnly)
        XCTAssertTrue(model.snapshot.storeReachable) // an expiry is the store's answer, not an outage
    }

    /// `refundTransaction` → `.readOnly(.revoked)`. `Transaction.currentEntitlements` never returns the
    /// refunded transaction, so the state comes from `renewals` (`state == .revoked`, rule 7, or its
    /// `latestTransaction` with a `revocationDate`, rule 1) or from the `Transaction.updates` copy
    /// (rule 1); the route taken is logged as `store-test: refund route …` for docs/M5.md. The refund is issued
    /// once more when the raw state has not shown it after `reissueAfter`.
    func testRefundRevokes() async throws {
        model.start()
        let started = await model.awaitFirstRefresh(timeout: .seconds(Self.appTimeout))
        XCTAssertTrue(started)
        let transaction = try await buy(.yearly)
        let groupID = transaction.subscriptionGroupID
        guard await awaitAction("purchase", groupID: groupID, raw: { $0.holds(transaction) }, app: { access.canEdit }) else { return }

        try session.refundTransaction(identifier: UInt(transaction.id))
        await awaitAction("refund", groupID: groupID,
                          reissue: { try self.session.refundTransaction(identifier: UInt(transaction.id)) },
                          raw: { $0.showsRefund }, app: { access == .readOnly(.revoked) })
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

    /// The group's verified history (`Transaction.all`), as `LiveStoreClient` copies a transaction. Reads no
    /// eligibility.
    private func groupHistory(_ groupID: String) async -> [EntitlementInput] {
        var history: [EntitlementInput] = []
        for await result in Transaction.all {
            if case .verified(let item) = result, item.subscriptionGroupID == groupID {
                history.append(LiveStoreClient.copy(item))
            }
        }
        return history
    }

    /// The intro offer is per subscription group: after a trial has run (and expired) neither
    /// product is eligible any more. Nothing reads the eligibility before the purchase
    /// (`testConfigurationLoadsBothProducts` holds that both products are eligible then), nor after it
    /// until the history holds the purchase as the trial (the model's first `refresh()` fetches the
    /// products, and so reads it), so the answer read after the expiry is not one this test pinned
    /// earlier. Where the answer stays true while the group's own history holds the expired trial, the
    /// evidence is logged and the test skips (iOS 27.2, the class's comment); every other outcome fails
    /// as before.
    func testIneligibleAfterATrial() async throws {
        let transaction = try await buy(.monthly)
        guard transaction.productID == Plan.monthly.productID else { return } // `buy` has recorded the failure
        let groupID = try XCTUnwrap(transaction.subscriptionGroupID, "the trial's subscription group")
        let purchaseID = transaction.id
        // The purchase in the history as the trial (probe run 44659376399: after 73 ms), read without the
        // eligibility: `currentEntitlements` (as the model reads it) or the group's `Transaction.all`.
        let inHistory = await awaitRaw("trial in the history", groupID: groupID) {
            if await client.currentEntitlements().contains(where: { $0.id == purchaseID && $0.isIntroductory }) { return true }
            return await groupHistory(groupID).contains { $0.id == purchaseID && $0.isIntroductory }
        }
        guard inHistory else { return }
        guard await awaitAction("purchase", groupID: groupID, raw: { $0.holds(transaction) }, app: { access.canEdit }) else { return }
        try session.expireSubscription(productIdentifier: Plan.monthly.productID)
        await awaitAction("expiry", groupID: groupID,
                          reissue: { try self.session.expireSubscription(productIdentifier: Plan.monthly.productID) },
                          raw: { $0.showsExpiry(now: Date()) }, app: { access == .readOnly(.expired) })
        // Asserted, and the test ends here when it does not hold. Every failure above ends the test too
        // (a `guard`, or a thrown error), so the skip below never follows a recorded failure.
        XCTAssertEqual(access, .readOnly(.expired))
        guard access == .readOnly(.expired) else { return }

        // StoreKit's answer, for the group and for each product (as the app reads it), every 100 ms for up
        // to 5 seconds.
        let started = Date()
        var reads = 0
        var groupEligible = true
        var after: [StoreProduct] = []
        while true {
            reads += 1
            groupEligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
            after = try await client.products(ids: ProductIDs.all)
            if !after.contains(where: \.isEligibleForIntroOffer) { break }
            if Date().timeIntervalSince(started) >= 5 { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        if after.contains(where: \.isEligibleForIntroOffer) {
            // The witness: the group's verified history (`Transaction.all`) holds an introductory
            // transaction whose expiry has passed.
            let now = Date()
            let history = await groupHistory(groupID)
            let trialUsed = history.contains { $0.isIntroductory && ($0.expirationDate.map { $0 <= now } ?? false) }
            let items = history.map {
                "id \($0.id) \($0.productID) introductory=\($0.isIntroductory) purchased \($0.purchaseDate) "
                    + "expires \($0.expirationDate.map { "\($0)" } ?? "nil") revoked \($0.revocationDate.map { "\($0)" } ?? "nil")"
            }
            let evidence = "\(ProcessInfo.processInfo.operatingSystemVersionString), \(reads) reads in "
                + "\(String(format: "%.1f", Date().timeIntervalSince(started))) s: "
                + "Product.SubscriptionInfo.isEligibleForIntroOffer(for: \(groupID))=\(groupEligible), "
                + "products \(after.map { "\($0.id)=\($0.isEligibleForIntroOffer)" }.joined(separator: " ")), access \(access); "
                + "Transaction.all of the group (verified): \(items.isEmpty ? "none" : items.joined(separator: "; "))"
            NSLog("store-test: eligibility after the trial = %@", evidence)
            if trialUsed, groupEligible, after.count == 2, after.allSatisfy(\.isEligibleForIntroOffer) {
                throw XCTSkip("StoreKit's test environment keeps the intro-offer eligibility true after the expired free trial "
                    + "in the group's history, as iOS 27.2 (24B8117) does in probe run 44659376399 (docs/M7D.md D0b): \(evidence)")
            }
            XCTAssertTrue(trialUsed, "Transaction.all holds no verified, introductory, expired transaction of the group: \(evidence)")
        }
        XCTAssertEqual(after.count, 2)
        XCTAssertFalse(try product(.monthly, in: after).isEligibleForIntroOffer)
        XCTAssertFalse(try product(.yearly, in: after).isEligibleForIntroOffer)
    }

    /// `start()` subscribes to `Transaction.updates`: a purchase made outside the app reaches the
    /// model without anyone calling `refresh()`. The listener gets `updatesTimeout` (attempt 3 of run 44802640918; the
    /// class's comment): a late update of an earlier test with the same id may come first.
    func testUpdatesStreamTriggersRefresh() async throws {
        model.start()
        let started = await model.awaitFirstRefresh(timeout: .seconds(Self.appTimeout))
        XCTAssertTrue(started)
        XCTAssertEqual(access, .readOnly(.notSubscribed), "before the purchase")

        let transaction = try await buy(.yearly)
        await awaitUpdates("purchase via Transaction.updates", groupID: transaction.subscriptionGroupID,
                           raw: { $0.holds(transaction) }, app: { access.canEdit && access.plan == .yearly })
        XCTAssertTrue(access.canEdit)
        XCTAssertEqual(access.plan, .yearly)
        XCTAssertNil(model.snapshot.message) // a purchase outside the app shows no toast
    }

    /// The restore of §7.3.1 without `AppStore.sync()`: cleared transactions → 「未購読」; a new
    /// purchase appears in `currentEntitlements` and the next refresh has the right again.
    func testRestoreAfterClearingTransactions() async throws {
        let first = try await buy(.yearly)
        let groupID = first.subscriptionGroupID
        guard await awaitAction("purchase", groupID: groupID, raw: { $0.holds(first) }, app: { access.canEdit }) else { return }

        session.clearTransactions()
        guard await awaitAction("clear", groupID: groupID, raw: { $0.isEmpty }, app: { access == .readOnly(.notSubscribed) }) else { return }
        let cleared = await client.currentEntitlements()
        XCTAssertEqual(cleared, [])

        let transaction = try await buy(.yearly)
        let appeared = await awaitRaw("second purchase", groupID: groupID) {
            await client.currentEntitlements().contains { $0.id == transaction.id }
        }
        guard appeared else { return }
        let entitlements = await client.currentEntitlements()
        XCTAssertTrue(entitlements.contains { $0.id == transaction.id })
        await refreshUntil { access.canEdit }
        XCTAssertEqual(access.plan, .yearly)
    }
}

/// One read of StoreKit's own answers (1.4 D3): what an action has done in the test environment, before any app logic.
/// The predicates say when the environment has done what the test asked, by what the app reads (`AccessPolicy` weighs
/// the entitlements and each status's own transaction), not when the app has answered.
private struct RawStoreState {
    struct Status {
        var state: RenewalState
        /// The status's verified transaction, copied as `LiveStoreClient` copies it.
        var transaction: EntitlementInput?
    }

    /// The verified `Transaction.currentEntitlements`, copied as `LiveStoreClient` copies them.
    var entitlements: [EntitlementInput] = []
    var unverified = 0
    /// `Product.SubscriptionInfo.status(for:)` of the group (not read while the group is unknown).
    var statuses: [Status] = []
    var statusError: String?

    /// The same transaction: id, product and purchase date (ids start at 0 again after `clearTransactions()`, so the id
    /// alone would also match an earlier test's leftover; the date to 1 s, as an earlier test's purchase is seconds older).
    static func same(_ input: EntitlementInput, _ transaction: Transaction) -> Bool {
        input.id == transaction.id && input.productID == transaction.productID
            && abs(input.purchaseDate.timeIntervalSince(transaction.purchaseDate)) < 1
    }

    static func describe(_ input: EntitlementInput) -> String {
        "id \(input.id) \(Plan(productID: input.productID).map { "\($0)" } ?? input.productID) introductory=\(input.isIntroductory) "
            + "purchased \(input.purchaseDate) expires \(input.expirationDate.map { "\($0)" } ?? "nil") "
            + "revoked \(input.revocationDate.map { "\($0)" } ?? "nil")"
    }

    /// Every transaction StoreKit answers with: the entitlements and each status's own.
    var transactions: [EntitlementInput] { entitlements + statuses.compactMap(\.transaction) }

    /// Nothing left (setUp's settle; after `clearTransactions()`): no entitlement, verified or not, and no status.
    var isEmpty: Bool { entitlements.isEmpty && unverified == 0 && statuses.isEmpty && statusError == nil }

    /// A purchase shows: it is a current entitlement, unrevoked.
    func holds(_ transaction: Transaction) -> Bool {
        entitlements.contains { Self.same($0, transaction) && $0.revocationDate == nil }
    }

    /// An expiry shows: no transaction is active any more (unrevoked with its expiry ahead), and the group's status says
    /// expired, with none subscribed, in grace or in billing retry.
    func showsExpiry(now: Date) -> Bool {
        !transactions.contains { $0.revocationDate == nil && ($0.expirationDate.map { $0 > now } ?? true) }
            && statuses.contains { $0.state == .expired }
            && !statuses.contains { [.subscribed, .inGracePeriod, .inBillingRetryPeriod].contains($0.state) }
    }

    /// A refund shows: no transaction is unrevoked any more, and a revoked one or a revoked status is there.
    var showsRefund: Bool {
        !transactions.contains { $0.revocationDate == nil }
            && (transactions.contains { $0.revocationDate != nil } || statuses.contains { $0.state == .revoked })
    }

    var text: String {
        var states = statuses.map { "\($0.state.rawValue) (\($0.transaction.map { Self.describe($0) } ?? "no verified transaction"))" }
        if let statusError { states.append("threw \(statusError)") }
        return "currentEntitlements [\(entitlements.map { Self.describe($0) }.joined(separator: "; "))]"
            + (unverified > 0 ? " and \(unverified) unverified" : "") + ", status [\(states.joined(separator: "; "))]"
    }
}
