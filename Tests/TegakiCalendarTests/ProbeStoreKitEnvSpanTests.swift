import Access
import Combine
import StoreKit
import StoreKitTest
import XCTest
@testable import TegakiCalendar

/// 1.4 D3 probe (the quick branch r14-q-skprobe; never merged): what StoreKit's test environment on iOS 27.2 (24B8117)
/// does under StoreKitSessionTests. CI run 44802640918 (r14, 283b7ed) ran the unit tests three times: attempt 2 failed
/// testExpiringMakesItReadOnly (after `expireSubscription` the raw answer stayed "intro entitlement, subscribed" for
/// 5.1 s), attempt 3 failed testUpdatesStreamTriggersRefresh (the only `Transaction.updates` delivery was the transaction
/// testRefundRevokes had refunded, id 0 again after `clearTransactions()`, and the new purchase's update never came).
///
/// One test, `test1Rounds`, runs `rounds` rounds. Each round replays StoreKitSessionTests' eight tests in their (name)
/// order, each with that class's setUp and tearDown done inline (a new `SKTestSession`, `clearTransactions()`,
/// `resetToDefaultState()`, JPN / ja_JP, a new `LiveStoreClient` and `StoreModel`; at the end `clearTransactions()` and
/// all three dropped): S1 buy (testBuyingMonthlyStartsATrial), C configuration, S2 expire (testExpiringMakesItReadOnly),
/// E ineligible (testIneligibleAfterATrial), S3 refund (testRefundRevokes), S4 restore (testRestoreAfterClearingTransactions),
/// U US storefront, S5 updates (testUpdatesStreamTriggersRefresh). The instruments, all on the test's side (no app code
/// changes):
///
/// - a witness: a detached task iterating `Transaction.updates` for the whole round (it never finishes a transaction),
///   logging every delivery with the ms since the round began, the scenario it came in and whether it is stale (bought
///   before that scenario began, so a previous scenario's);
/// - every StoreKit call the test makes is timed, and one over a second is logged as a stall;
/// - after each action the raw state (`Transaction.currentEntitlements` and `Product.SubscriptionInfo.status(for:)`, not
///   through the app) is read every 100 ms for up to 15 s, the app's model refreshed as the real test does, and the ms
///   until each showed the action are logged; when an expiry or a refund is not shown in 15 s, `Transaction.all` is
///   logged and the call is issued once more (late or lost);
/// - in S5 the model's `snapshot` changes (`$snapshot`) are timed against the deliveries (did a refresh follow each
///   update), and in rounds 4 to 6 the stale updates are drained first: `Transaction.updates` is read for up to 1.5 s (until
///   400 ms of silence) before `model.start()`, each delivery finished and logged.
///
/// Every line starts with `probe-sk:` (NSLog; LiveStoreClient's own `store:` lines come between them), and each round
/// ends with `probe-sk: round=<r> summary …`, the test with `probe-sk: final …`. It never fails on what it measures (it
/// skips, as StoreKitSessionTests does, when the simulator's test environment does not work), and its waits are bounded:
/// no round starts after `roundBudget` and no scenario after `scenarioBudget` seconds. The class name ends in `SpanTests`
/// (the quick lane's pattern); on r14-q-skprobe the quick lane runs this class alone.
@MainActor
final class ProbeStoreKitEnvSpanTests: XCTestCase {
    private static let rounds = 6
    /// No round starts after this many seconds of the test, no scenario after `scenarioBudget`.
    private static let roundBudget: TimeInterval = 270
    private static let scenarioBudget: TimeInterval = 330
    /// The raw state is read this long after an action (and as long again after a second call).
    private static let pollLimit: TimeInterval = 15
    /// A StoreKit call (or a model refresh) at least this long is a stall.
    private static let stallLimit: TimeInterval = 1
    /// StoreKitSessionTests' waits (`refreshUntil`, `waitUntil`): an app answer later than this fails the real test.
    private static let realLimitMS = 5000

    private let box = ProbeSKBox()
    private var session: SKTestSession?
    private var client: LiveStoreClient?
    private var model: StoreModel?
    private var sink: AnyCancellable?
    private var testStart = Date()
    private var notes = ProbeNotes(round: 0)
    private var allNotes: [ProbeNotes] = []
    private var lines: [String] = []

    // MARK: - The probe

    func test1Rounds() async throws {
        testStart = Date()
        log("start: \(ProcessInfo.processInfo.operatingSystemVersionString); \(Self.rounds) rounds of StoreKitSessionTests' 8 scenarios in its order "
            + "(S1 buy, C configuration, S2 expire, E ineligible, S3 refund, S4 restore, U US storefront, S5 updates); S5 drains Transaction.updates first in rounds 4-6")
        for round in 1...Self.rounds {
            let elapsed = Date().timeIntervalSince(testStart)
            if elapsed > Self.roundBudget {
                log("budget: \(Int(elapsed)) s after \(round - 1) rounds; no more rounds")
                break
            }
            let roundStart = Date()
            box.beginRound(round)
            notes = ProbeNotes(round: round)
            let witness = startWitness(round: round)
            log("round \(round) begins, \(Int(elapsed)) s into the test")
            try? await Task.sleep(for: .milliseconds(200)) // the witness subscribes
            try await runScenario("S1", round: round) { await s1Buy() }
            try await runScenario("C", round: round) { await cConfiguration() }
            try await runScenario("S2", round: round) { await s2Expire() }
            try await runScenario("E", round: round) { await eIneligible() }
            try await runScenario("S3", round: round) { await s3Refund() }
            try await runScenario("S4", round: round) { await s4Restore() }
            try await runScenario("U", round: round) { await uUSStorefront() }
            try await runScenario("S5", round: round) { await s5Updates(round: round) }
            try? await Task.sleep(for: .milliseconds(300)) // late deliveries of the round's last scenario
            summarize(round: round, started: roundStart)
            box.endRound()
            witness.cancel()
        }
        finalSummary()
        let all = XCTAttachment(string: lines.joined(separator: "\n"))
        all.name = "probe-sk.txt"
        all.lifetime = .keepAlways
        add(all)
    }

    // MARK: - setUp and tearDown (StoreKitSessionTests', inline)

    /// One scenario: the real setUp, `body`, the real tearDown. Not run when the test is over `scenarioBudget`.
    private func runScenario(_ name: String, round: Int, _ body: () async -> Void) async throws {
        let elapsed = Date().timeIntervalSince(testStart)
        if elapsed > Self.scenarioBudget {
            log("\(name): not run, \(Int(elapsed)) s into the test (over the budget)")
            notes.parts.append("\(name)=budget")
            return
        }
        let start = Date()
        guard try await setUpScenario(name, round: round) else {
            notes.parts.append("\(name)=setUpFailed")
            return
        }
        await body()
        tearDownScenario(name)
        let ms = ProbeSK.ms(since: start)
        notes.durations.append("\(name):\(ms)")
        log("\(name): \(ms) ms with its setUp and tearDown")
    }

    /// StoreKitSessionTests.setUp. The environment check skips the test only in round 1's first scenario (later ones log).
    private func setUpScenario(_ name: String, round: Int) async throws -> Bool {
        box.beginScenario(name)
        let start = Date()
        let made: SKTestSession
        do {
            made = try SKTestSession(configurationFileNamed: "Products")
        } catch {
            log("\(name) setUp: SKTestSession failed: \(error)")
            if round == 1 && name == "S1" {
                throw XCTSkip("probe: SKTestSession(configurationFileNamed: \"Products\") failed: \(error)")
            }
            return false
        }
        made.disableDialogs = true
        timed("\(name) setUp clearTransactions") { made.clearTransactions() }
        timed("\(name) setUp resetToDefaultState") { made.resetToDefaultState() }
        made.storefront = "JPN"
        made.locale = Locale(identifier: "ja_JP")
        session = made
        let problem = await timedAsync("\(name) setUp environment check") { await environmentProblem() }
        if let problem {
            log("\(name) setUp: the test environment does not work: \(problem)")
            if round == 1 && name == "S1" {
                made.clearTransactions()
                session = nil
                throw XCTSkip("StoreKit test environment unavailable on this simulator: \(problem) (as StoreKitSessionTests skips; Xcode 26.3-26.6 defect, docs/M5.md §3)")
            }
        }
        let client = LiveStoreClient()
        let model = StoreModel(client: client, cache: NoopAccessCache())
        self.client = client
        self.model = model
        let box = self.box
        sink = model.$snapshot.sink { snapshot in
            if let line = box.notePublish(access: ProbeSK.short(snapshot.access), refreshed: snapshot.refreshed) {
                ProbeSK.emit(line)
            }
        }
        log("\(name) setUp: \(ProbeSK.ms(since: start)) ms")
        return true
    }

    /// StoreKitSessionTests.skipUnlessTheTestEnvironmentWorks, as a description of what did not work (nil: it works).
    private func environmentProblem() async -> String? {
        var storefront = await Storefront.current?.countryCode
        let deadline = Date().addingTimeInterval(3)
        while storefront != "JPN", Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            storefront = await Storefront.current?.countryCode
        }
        if storefront == "JPN" { return nil }
        let monthly = try? await Product.products(for: [Plan.monthly.productID]).first
        if monthly?.price == 300 { return nil }
        return "SKTestSession's storefront stayed \(storefront ?? "nil"), monthly price \(monthly.map { "\($0.price)" } ?? "nil")"
    }

    /// StoreKitSessionTests.tearDown.
    private func tearDownScenario(_ name: String) {
        if let session {
            timed("\(name) tearDown clearTransactions") { session.clearTransactions() }
        }
        sink?.cancel()
        sink = nil
        model = nil
        client = nil
        session = nil
        box.relabel("\(name)~")
    }

    // MARK: - The scenarios (StoreKitSessionTests' tests, in their order)

    /// testBuyingMonthlyStartsATrial: buy monthly, refresh until `.trial`.
    private func s1Buy() async {
        guard let model else { return }
        guard let transaction = await buy(.monthly, "S1") else {
            notes.parts.append("S1=noPurchase")
            return
        }
        let bought = await poll("S1 after the purchase", groupID: transaction.subscriptionGroupID, refresh: true,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0) },
                                app: { ProbeSK.isTrial(model.snapshot.access) })
        checkApp("S1", bought)
        notes.parts.append("S1=\(bought.short)")
    }

    /// testConfigurationLoadsBothProducts: the products, then one refresh.
    private func cConfiguration() async {
        guard let client, let model else { return }
        var text = ""
        do {
            let products = try await timedAsync("C client.products", report: true) { try await client.products(ids: ProductIDs.all) }
            text = products.map { "\(ProbeSK.planName($0.id))=\($0.price)" }.joined(separator: ",")
        } catch {
            text = "threw"
            log("C: client.products threw \(error)")
        }
        await timedAsync("C model.refresh", report: true) { await model.refresh() }
        log("C: products \(text); access \(ProbeSK.short(model.snapshot.access)), offers \(model.snapshot.offers.count)")
        notes.parts.append("C=\(text.isEmpty ? "none" : text)")
    }

    /// testExpiringMakesItReadOnly: buy monthly, refresh until it can edit, expire, refresh until `.readOnly(.expired)`.
    private func s2Expire() async {
        guard let model else { return }
        guard let transaction = await buy(.monthly, "S2") else {
            notes.parts.append("S2=noPurchase")
            return
        }
        let group = transaction.subscriptionGroupID
        let bought = await poll("S2 after the purchase", groupID: group, refresh: true,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S2.buy", bought)
        let expired = await pollAction("S2 expire", groupID: group, refresh: true,
                                       action: { expire(.monthly, "S2") },
                                       raw: { !ProbeSK.holds($0, transaction) && ProbeSK.expired($0) },
                                       app: { model.snapshot.access == .readOnly(.expired) })
        checkApp("S2.expire", expired)
        notes.parts.append("S2=buy:\(bought.short),expire:\(expired.short)")
    }

    /// testIneligibleAfterATrial: buy monthly, wait for the history (no eligibility read), refresh until it can edit,
    /// expire, refresh until `.readOnly(.expired)`, then the eligibility read every 100 ms for up to 5 s.
    private func eIneligible() async {
        guard let client, let model else { return }
        guard let transaction = await buy(.monthly, "E") else {
            notes.parts.append("E=noPurchase")
            return
        }
        let group = transaction.subscriptionGroupID
        let history = await poll("E history", groupID: group, refresh: false,
                                 raw: { raw in raw.entitlements.contains { $0.id == transaction.id && $0.isIntroductory } },
                                 app: { true })
        let editable = await poll("E refreshUntil canEdit", groupID: group, refresh: true,
                                  raw: { _ in true },
                                  app: { model.snapshot.access.canEdit })
        checkApp("E.buy", editable)
        let expired = await pollAction("E expire", groupID: group, refresh: true,
                                       action: { expire(.monthly, "E") },
                                       raw: { !ProbeSK.holds($0, transaction) && ProbeSK.expired($0) },
                                       app: { model.snapshot.access == .readOnly(.expired) })
        checkApp("E.expire", expired)
        var eligibility = "notRead"
        if let group, model.snapshot.access == .readOnly(.expired) {
            let start = Date()
            var reads = 0
            var groupEligible = true
            var products: [StoreProduct] = []
            while true {
                reads += 1
                groupEligible = await timedAsync("E isEligibleForIntroOffer(for:)") {
                    await Product.SubscriptionInfo.isEligibleForIntroOffer(for: group)
                }
                do {
                    products = try await timedAsync("E client.products") { try await client.products(ids: ProductIDs.all) }
                } catch {
                    log("E: client.products threw \(error)")
                    break
                }
                if !products.contains(where: \.isEligibleForIntroOffer) { break }
                if Date().timeIntervalSince(start) >= 5 { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            eligibility = "group=\(groupEligible)," + products.map { "\(ProbeSK.planName($0.id))=\($0.isEligibleForIntroOffer)" }.joined(separator: ",")
            log("E: eligibility after \(reads) reads in \(ProbeSK.ms(since: start)) ms: \(eligibility)")
            if products.contains(where: \.isEligibleForIntroOffer) {
                await logAll("E eligible after the trial")
            }
        }
        notes.parts.append("E=history:\(ProbePoll.text(history.rawMS)),buy:\(editable.short),expire:\(expired.short),eligible:\(eligibility)")
    }

    /// testRefundRevokes: `model.start()`, buy yearly, refresh until it can edit, refund, refresh until `.readOnly(.revoked)`.
    private func s3Refund() async {
        guard let client, let model else { return }
        let startAt = Date()
        model.start()
        let started = await timedAsync("S3 awaitFirstRefresh") { await model.awaitFirstRefresh(timeout: .seconds(5)) }
        log("S3: model.start(), awaitFirstRefresh \(started) after \(ProbeSK.ms(since: startAt)) ms; access \(ProbeSK.short(model.snapshot.access))")
        if !started { notes.wouldFail.append("S3.firstRefresh") }
        guard let transaction = await buy(.yearly, "S3") else {
            notes.parts.append("S3=noPurchase")
            return
        }
        let group = transaction.subscriptionGroupID
        let bought = await poll("S3 after the purchase", groupID: group, refresh: true,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S3.buy", bought)
        let refunded = await pollAction("S3 refund", groupID: group, refresh: true,
                                        action: { refund(transaction, "S3") },
                                        raw: { !ProbeSK.holds($0, transaction) && ProbeSK.revoked($0) },
                                        app: { model.snapshot.access == .readOnly(.revoked) })
        checkApp("S3.refund", refunded)
        // The real test's route (its `store-test: refund route` line).
        let entitlements = await timedAsync("S3 client.currentEntitlements") { await client.currentEntitlements() }
        var route: [String] = []
        if let group, let renewals = try? await timedAsync("S3 client.renewals", { try await client.renewals(groupID: group) }) {
            if renewals.contains(where: { $0.state == .revoked }) { route.append("renewals.state==revoked") }
            if renewals.contains(where: { $0.latestTransaction?.revocationDate != nil }) { route.append("renewals.latestTransaction.revocationDate") }
        }
        if entitlements.contains(where: { $0.revocationDate != nil }) { route.append("currentEntitlements.revocationDate") }
        log("S3: refund route \(route.isEmpty ? "Transaction.updates copy only" : route.joined(separator: " + "))")
        notes.parts.append("S3=buy:\(bought.short),refund:\(refunded.short)")
    }

    /// testRestoreAfterClearingTransactions: buy yearly, refresh until it can edit, `clearTransactions()`, refresh until
    /// `.readOnly(.notSubscribed)`, buy yearly again, wait for it in the entitlements, refresh until it can edit.
    private func s4Restore() async {
        guard let session, let model else { return }
        guard let first = await buy(.yearly, "S4") else {
            notes.parts.append("S4=noPurchase")
            return
        }
        let group = first.subscriptionGroupID
        let bought = await poll("S4 after the purchase", groupID: group, refresh: true,
                                raw: { ProbeSK.holds($0, first) && ProbeSK.subscribed($0) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S4.buy", bought)
        timed("S4 clearTransactions", report: true) { session.clearTransactions() }
        let cleared = await poll("S4 after clearTransactions", groupID: group, refresh: true,
                                 raw: { $0.entitlements.isEmpty },
                                 app: { model.snapshot.access == .readOnly(.notSubscribed) })
        checkApp("S4.clear", cleared)
        guard let second = await buy(.yearly, "S4 again") else {
            notes.parts.append("S4=buy:\(bought.short),clear:\(cleared.short),again:noPurchase")
            return
        }
        let again = await poll("S4 after the second purchase", groupID: group, refresh: true,
                               raw: { ProbeSK.holds($0, second) },
                               app: { model.snapshot.access.canEdit })
        checkApp("S4.again", again)
        notes.parts.append("S4=buy:\(bought.short),clear:\(cleared.short),again:\(again.short)")
    }

    /// testUSStorefrontPrices: storefront USA, en_US, the products.
    private func uUSStorefront() async {
        guard let session, let client else { return }
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        do {
            let products = try await timedAsync("U client.products", report: true) { try await client.products(ids: ProductIDs.all) }
            let text = products.map { "\(ProbeSK.planName($0.id))=\($0.displayPrice)" }.joined(separator: ",")
            log("U: \(text)")
            notes.parts.append("U=\(text.isEmpty ? "none" : text)")
        } catch {
            log("U: client.products threw \(error)")
            notes.parts.append("U=threw")
        }
    }

    /// testUpdatesStreamTriggersRefresh: `model.start()`, the first refresh, buy yearly, wait (no refresh by the test) until
    /// it can edit. Rounds 4-6 drain `Transaction.updates` before `model.start()`.
    private func s5Updates(round: Int) async {
        guard let model else { return }
        var drained = "no"
        if round >= 4 {
            let count = await drainUpdates("S5")
            drained = "\(count)"
        }
        let startAt = Date()
        model.start()
        let started = await timedAsync("S5 awaitFirstRefresh") { await model.awaitFirstRefresh(timeout: .seconds(5)) }
        let firstAccess = model.snapshot.access
        log("S5: model.start(), awaitFirstRefresh \(started) after \(ProbeSK.ms(since: startAt)) ms; access \(ProbeSK.short(firstAccess))")
        if !started { notes.wouldFail.append("S5.firstRefresh") }
        if firstAccess != .readOnly(.notSubscribed) { notes.wouldFail.append("S5.notSubscribed") }
        guard let transaction = await buy(.yearly, "S5") else {
            notes.parts.append("S5=drain:\(drained),noPurchase")
            return
        }
        let boughtAt = Date()
        let result = await poll("S5 after the purchase", groupID: transaction.subscriptionGroupID, refresh: false,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S5", result)

        // The deliveries of S5 against the model's snapshot changes.
        let deliveries = box.deliveries(round: round).filter { $0.scenario == "S5" }
        let publishes = box.publishes(round: round).filter { $0.scenario == "S5" && $0.at >= startAt }
        var own: Int?
        var staleAfterStart = 0
        var refreshAfter = 0
        for delivery in deliveries {
            let afterPurchase = Int(delivery.at.timeIntervalSince(boughtAt) * 1000)
            let isOwn = delivery.id == transaction.id && delivery.productID == transaction.productID && !delivery.stale
            if isOwn, own == nil { own = afterPurchase }
            if delivery.stale, delivery.at >= startAt { staleAfterStart += 1 }
            let next = publishes.first { $0.at >= delivery.at }
            if next != nil { refreshAfter += 1 }
            let nextText = next.map { "+\(Int($0.at.timeIntervalSince(delivery.at) * 1000)) ms (access \($0.access))" } ?? "none"
            log("S5: delivery \(afterPurchase) ms after the purchase (\(delivery.at >= startAt ? "after" : "before") model.start()): id=\(delivery.id) "
                + "\(ProbeSK.planName(delivery.productID)) revoked=\(delivery.revoked) stale=\(delivery.stale) own=\(isOwn); next model change \(nextText)")
        }
        let times = publishes.map { "+\(Int($0.at.timeIntervalSince(startAt) * 1000))" }
        log("S5: \(publishes.count) model changes after model.start() (ms): \(times.joined(separator: " ")); the purchase at "
            + "+\(Int(boughtAt.timeIntervalSince(startAt) * 1000)); access now \(ProbeSK.short(model.snapshot.access))")
        notes.parts.append("S5=drain:\(drained),\(result.short),ownUpdate:\(ProbePoll.text(own)),deliveries:\(deliveries.count),"
            + "staleAfterStart:\(staleAfterStart),refreshAfter:\(refreshAfter)/\(deliveries.count),end:\(ProbeSK.short(model.snapshot.access))")
    }

    // MARK: - StoreKit calls (timed)

    private func buy(_ plan: Plan, _ label: String) async -> Transaction? {
        guard let session else { return nil }
        do {
            let transaction = try await timedAsync("\(label) buyProduct(\(plan))", report: true) {
                try await session.buyProduct(identifier: plan.productID)
            }
            log("\(label): bought \(ProbeSK.describe(transaction, verified: true))")
            return transaction
        } catch {
            log("\(label): buyProduct(\(plan)) threw \(error)")
            notes.failures.append("\(label).buy")
            return nil
        }
    }

    private func expire(_ plan: Plan, _ label: String) -> String {
        guard let session else { return "no session" }
        do {
            try timed("\(label) expireSubscription(\(plan))", report: true) {
                try session.expireSubscription(productIdentifier: plan.productID)
            }
            return "expireSubscription(\(plan)) returned"
        } catch {
            return "expireSubscription(\(plan)) threw \(error)"
        }
    }

    private func refund(_ transaction: Transaction, _ label: String) -> String {
        guard let session else { return "no session" }
        do {
            try timed("\(label) refundTransaction(\(transaction.id))", report: true) {
                try session.refundTransaction(identifier: UInt(transaction.id))
            }
            return "refundTransaction(\(transaction.id)) returned"
        } catch {
            return "refundTransaction(\(transaction.id)) threw \(error)"
        }
    }

    @discardableResult
    private func timed<T>(_ what: String, report: Bool = false, _ body: () throws -> T) rethrows -> T {
        let start = Date()
        defer { noteCall(what, start: start, report: report) }
        return try body()
    }

    @discardableResult
    private func timedAsync<T>(_ what: String, report: Bool = false, _ body: () async throws -> T) async rethrows -> T {
        let start = Date()
        defer { noteCall(what, start: start, report: report) }
        return try await body()
    }

    /// A call of at least `stallLimit` is a stall (logged and counted); `report` logs every duration.
    private func noteCall(_ what: String, start: Date, report: Bool) {
        let ms = ProbeSK.ms(since: start)
        if Double(ms) >= Self.stallLimit * 1000 {
            notes.stalls.append(ProbeStall(what: what, ms: ms))
            log("STALL: \(what) took \(ms) ms")
        } else if report {
            log("\(what) took \(ms) ms")
        }
    }

    // MARK: - The raw state

    /// `Transaction.currentEntitlements` (every one) and `Product.SubscriptionInfo.status(for:)` of the group, each timed.
    private func readRaw(groupID: String?, label: String) async -> ProbeRaw {
        var raw = ProbeRaw()
        let start = Date()
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                raw.entitlements.append(LiveStoreClient.copy(transaction))
            case .unverified(let transaction, _):
                raw.unverified.append(transaction.id)
            }
        }
        noteCall("\(label): currentEntitlements", start: start, report: false)
        guard let groupID else { return raw }
        let statusStart = Date()
        do {
            let statuses = try await Product.SubscriptionInfo.status(for: groupID)
            for status in statuses {
                var item = ProbeStatus(state: LiveStoreClient.renewalState(status.state))
                if case .verified(let transaction) = status.transaction {
                    item.transactionID = transaction.id
                    item.revoked = transaction.revocationDate != nil
                    item.expires = transaction.expirationDate
                }
                raw.statuses.append(item)
            }
        } catch {
            raw.statusError = "\(error)"
        }
        noteCall("\(label): status(for:)", start: statusStart, report: false)
        return raw
    }

    /// Every 100 ms for up to `pollLimit`: the raw state (logged when it changes) and, until `app` holds, `model.refresh()`
    /// when `refresh` (StoreKitSessionTests' refreshUntil; S5 waits without refreshing, as its waitUntil). Ends when both
    /// `raw` and `app` hold.
    private func poll(_ label: String, groupID: String?, refresh: Bool, raw rawCondition: (ProbeRaw) -> Bool, app appCondition: () -> Bool) async -> ProbePoll {
        let start = Date()
        var result = ProbePoll()
        var lastText = ""
        while true {
            result.ticks += 1
            let raw = await readRaw(groupID: groupID, label: "\(label) poll")
            let text = raw.text
            if text != lastText {
                log("\(label) +\(ProbeSK.ms(since: start))ms raw: \(text)")
                lastText = text
            }
            if result.rawMS == nil, rawCondition(raw) { result.rawMS = ProbeSK.ms(since: start) }
            if result.appMS == nil {
                if refresh, let model {
                    await timedAsync("\(label) model.refresh") { await model.refresh() }
                }
                if appCondition() { result.appMS = ProbeSK.ms(since: start) }
            }
            if result.rawMS != nil, result.appMS != nil { break }
            if Date().timeIntervalSince(start) >= Self.pollLimit { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        log("\(label): raw \(ProbePoll.text(result.rawMS)) ms, app \(ProbePoll.text(result.appMS)) ms (\(result.ticks) reads); access \(model.map { ProbeSK.short($0.snapshot.access) } ?? "-")")
        return result
    }

    /// `action` (an expiry or a refund), then `poll`; when the raw state does not show it in `pollLimit`, `Transaction.all`,
    /// the action once more and `poll` again (late or lost).
    private func pollAction(_ label: String, groupID: String?, refresh: Bool, action: () -> String,
                            raw rawCondition: (ProbeRaw) -> Bool, app appCondition: () -> Bool) async -> ProbePoll {
        log("\(label): \(action())")
        var result = await poll(label, groupID: groupID, refresh: refresh, raw: rawCondition, app: appCondition)
        guard result.rawMS == nil else { return result }
        log("\(label): NOT reflected in \(Int(Self.pollLimit)) s")
        await logAll("\(label) not reflected")
        result.retried = true
        log("\(label): issued once more: \(action())")
        let second = await poll("\(label) (second call)", groupID: groupID, refresh: refresh, raw: rawCondition, app: appCondition)
        result.secondRawMS = second.rawMS
        result.secondAppMS = second.appMS
        if let ms = second.rawMS {
            log("\(label): reflected \(ms) ms after the second call")
            notes.lost.append("\(label)(2nd:\(ms)ms)")
        } else {
            log("\(label): the second call NOT reflected in \(Int(Self.pollLimit)) s either")
            notes.lost.append("\(label)(2nd:never)")
            await logAll("\(label) second call not reflected")
        }
        return result
    }

    /// `Transaction.all` (id, product, purchase, expiry, revocation), one line each.
    private func logAll(_ label: String) async {
        let start = Date()
        var items: [String] = []
        for await result in Transaction.all {
            switch result {
            case .verified(let transaction):
                items.append(ProbeSK.describe(transaction, verified: true))
            case .unverified(let transaction, _):
                items.append(ProbeSK.describe(transaction, verified: false))
            }
        }
        noteCall("\(label): Transaction.all", start: start, report: false)
        log("\(label): Transaction.all holds \(items.count) (read in \(ProbeSK.ms(since: start)) ms)")
        for (index, item) in items.enumerated() {
            log("\(label): all[\(index)] \(item)")
        }
    }

    /// An app answer later than StoreKitSessionTests' 5 s (or never) would fail the real test; a raw state shown while
    /// the app never followed is an app lag.
    private func checkApp(_ label: String, _ result: ProbePoll) {
        let inTime = result.appMS.map { $0 <= Self.realLimitMS } ?? false
        if !inTime { notes.wouldFail.append(label) }
        if result.rawMS != nil, result.appMS == nil { notes.appLag.append(label) }
    }

    // MARK: - Transaction.updates on the test's side

    /// The round's witness: every delivery of `Transaction.updates`, logged with the round's ms and the scenario. It never
    /// finishes a transaction, and stops at the first delivery after its round.
    private func startWitness(round: Int) -> Task<Void, Never> {
        let box = self.box
        return Task.detached {
            ProbeSK.emit("r\(round) witness: listening to Transaction.updates")
            for await result in Transaction.updates {
                let line: String?
                switch result {
                case .verified(let transaction):
                    line = box.record(listenerRound: round, transaction: transaction, verified: true, note: nil)
                case .unverified(let transaction, let error):
                    line = box.record(listenerRound: round, transaction: transaction, verified: false, note: "\(error)")
                }
                guard let line else { break }
                ProbeSK.emit(line)
            }
            ProbeSK.emit("r\(round) witness: the listener ended")
        }
    }

    /// The drain (rounds 4-6, before S5's `model.start()`): `Transaction.updates` for up to 1.5 s, until 400 ms without a
    /// delivery; each delivered transaction finished and logged. Returns how many.
    private func drainUpdates(_ label: String) async -> Int {
        let drain = ProbeSKDrain()
        let box = self.box
        let task = Task.detached {
            for await result in Transaction.updates {
                guard drain.isActive() else { break }
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    drain.note("\(box.stamp()) drain: finished \(ProbeSK.describe(transaction, verified: true))")
                case .unverified(let transaction, let error):
                    await transaction.finish()
                    drain.note("\(box.stamp()) drain: finished \(ProbeSK.describe(transaction, verified: false)) (\(error))")
                }
            }
        }
        let start = Date()
        while true {
            try? await Task.sleep(for: .milliseconds(50))
            let now = Date()
            if now.timeIntervalSince(start) >= 1.5 { break }
            if now.timeIntervalSince(drain.lastActivity() ?? start) >= 0.4 { break }
        }
        drain.stop()
        task.cancel()
        let count = drain.count()
        log("\(label): drain: \(count) delivered and finished in \(ProbeSK.ms(since: start)) ms")
        return count
    }

    // MARK: - Logging

    private func log(_ text: String) {
        let line = "\(box.stamp()) \(text)"
        lines.append(line)
        ProbeSK.emit(line)
    }

    /// A line without the stamp (the summaries, which the reader greps by their start).
    private func emitPlain(_ line: String) {
        lines.append(line)
        ProbeSK.emit(line)
    }

    private func summarize(round: Int, started: Date) {
        let deliveries = box.deliveries(round: round)
        var staleBy: [String: Int] = [:]
        for delivery in deliveries where delivery.stale {
            staleBy[delivery.scenario, default: 0] += 1
        }
        notes.stale = staleBy.keys.sorted().map { "\($0):\(staleBy[$0] ?? 0)" }
        let line = "round=\(round) summary \(notes.parts.joined(separator: " ")) deliveries=\(deliveries.count) "
            + "stale=\(ProbeSK.list(notes.stale)) lost=\(ProbeSK.list(notes.lost)) stall=\(notes.stallText) "
            + "wouldFail=\(ProbeSK.list(notes.wouldFail)) appLag=\(ProbeSK.list(notes.appLag)) failures=\(ProbeSK.list(notes.failures)) "
            + "ms=\(notes.durations.joined(separator: ",")) total=\(ProbeSK.ms(since: started))"
        emitPlain(line)
        allNotes.append(notes)
    }

    private func finalSummary() {
        func perRound(_ pick: (ProbeNotes) -> [String]) -> String {
            let parts = allNotes.compactMap { notes -> String? in
                let items = pick(notes)
                return items.isEmpty ? nil : "r\(notes.round)[\(items.joined(separator: ","))]"
            }
            return parts.isEmpty ? "-" : parts.joined(separator: " ")
        }
        let line = "final rounds=\(allNotes.count) in \(ProbeSK.ms(since: testStart)) ms; wouldFail=\(perRound { $0.wouldFail }) "
            + "lost=\(perRound { $0.lost }) stale=\(perRound { $0.stale }) stall=\(perRound { $0.stalls.isEmpty ? [] : [$0.stallText] }) "
            + "appLag=\(perRound { $0.appLag }) failures=\(perRound { $0.failures })"
        emitPlain(line)
    }
}

// MARK: - Shared helpers (no actor: the witness and the drain run detached)

private enum ProbeSK {
    /// One `probe-sk:` line, cut at 900 characters.
    static func emit(_ line: String) {
        let limit = 900
        let text = line.count > limit ? String(line.prefix(limit - 6)) + " [cut]" : line
        NSLog("probe-sk: %@", text)
    }

    static func ms(since date: Date) -> Int {
        Int(Date().timeIntervalSince(date) * 1000)
    }

    static func iso(_ date: Date?) -> String {
        guard let date else { return "-" }
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return format.string(from: date)
    }

    static func planName(_ productID: String) -> String {
        Plan(productID: productID).map { "\($0)" } ?? productID
    }

    static func list(_ items: [String]) -> String {
        items.isEmpty ? "-" : items.joined(separator: ",")
    }

    static func short(_ access: AccessState) -> String {
        switch access {
        case .subscribed(let subscription): return "subscribed(\(subscription.plan))"
        case .trial(let trial): return "trial(\(trial.plan))"
        case .readOnly(let reason): return "readOnly(\(reason.rawValue))"
        }
    }

    static func isTrial(_ access: AccessState) -> Bool {
        if case .trial = access { return true }
        return false
    }

    /// The fields that tell the deliveries apart (ids start at 0 again after `clearTransactions()`).
    static func describe(_ transaction: Transaction, verified: Bool) -> String {
        let copy = LiveStoreClient.copy(transaction)
        return "id=\(transaction.id) original=\(transaction.originalID) \(planName(transaction.productID)) verified=\(verified) "
            + "intro=\(copy.isIntroductory) purchased=\(iso(transaction.purchaseDate)) expires=\(iso(transaction.expirationDate)) "
            + "revoked=\(iso(transaction.revocationDate)) upgraded=\(transaction.isUpgraded) env=\(transaction.environment.rawValue)"
    }

    /// The transaction is a current entitlement.
    static func holds(_ raw: ProbeRaw, _ transaction: Transaction) -> Bool {
        raw.entitlements.contains { $0.id == transaction.id && $0.productID == transaction.productID }
    }

    static func subscribed(_ raw: ProbeRaw) -> Bool {
        raw.statuses.contains { $0.state == .subscribed }
    }

    static func expired(_ raw: ProbeRaw) -> Bool {
        raw.statuses.contains { $0.state == .expired } && !raw.statuses.contains { $0.state == .subscribed }
    }

    static func revoked(_ raw: ProbeRaw) -> Bool {
        raw.statuses.contains { $0.state == .revoked || $0.revoked }
    }
}

private struct ProbeStatus {
    var state: RenewalState
    var transactionID: UInt64?
    var revoked = false
    var expires: Date?
}

/// One read of the raw state.
private struct ProbeRaw {
    var entitlements: [EntitlementInput] = []
    var unverified: [UInt64] = []
    var statuses: [ProbeStatus] = []
    var statusError: String?

    var text: String {
        var held: [String] = []
        for item in entitlements {
            let expires = ProbeSK.iso(item.expirationDate)
            held.append("\(ProbeSK.planName(item.productID)) id=\(item.id) intro=\(item.isIntroductory) expires=\(expires) revoked=\(item.revocationDate != nil)")
        }
        var states: [String] = []
        if let statusError {
            states.append("threw \(statusError)")
        } else {
            for status in statuses {
                let transactionText = status.transactionID.map { "\($0)" } ?? "-"
                let expires = ProbeSK.iso(status.expires)
                states.append("\(status.state.rawValue) tx=\(transactionText) revoked=\(status.revoked) expires=\(expires)")
            }
        }
        var text = "entitlements [\(held.joined(separator: "; "))]"
        if !unverified.isEmpty {
            let ids = unverified.map { "\($0)" }
            text += " unverified \(ids.joined(separator: ","))"
        }
        return text + " status [\(states.joined(separator: "; "))]"
    }
}

/// What a poll saw: the ms until the raw state and the app showed the action (nil: not in the poll's time).
private struct ProbePoll {
    var rawMS: Int?
    var appMS: Int?
    var ticks = 0
    var retried = false
    var secondRawMS: Int?
    var secondAppMS: Int?

    var short: String {
        var text = "raw:\(Self.text(rawMS))/app:\(Self.text(appMS))"
        if retried { text += "/2nd:raw:\(Self.text(secondRawMS))/app:\(Self.text(secondAppMS))" }
        return text
    }

    static func text(_ ms: Int?) -> String {
        ms.map { "\($0)" } ?? "never"
    }
}

private struct ProbeStall {
    var what: String
    var ms: Int
}

/// One round's findings, for its summary line and the final one.
private struct ProbeNotes {
    var round: Int
    var parts: [String] = []
    var durations: [String] = []
    var stalls: [ProbeStall] = []
    var lost: [String] = []
    var stale: [String] = []
    var wouldFail: [String] = []
    var appLag: [String] = []
    var failures: [String] = []

    /// How many stalls and the longest.
    var stallText: String {
        guard let longest = stalls.max(by: { $0.ms < $1.ms }) else { return "-" }
        return "\(stalls.count)(max \(longest.what):\(longest.ms)ms)"
    }
}

private struct ProbeDelivery {
    var round: Int
    var scenario: String
    var at: Date
    var id: UInt64
    var productID: String
    var revoked: Bool
    var stale: Bool
}

private struct ProbePublish {
    var round: Int
    var scenario: String
    var at: Date
    var access: String
}

/// What the test (main actor), the witness and the model's `$snapshot` sink share. Every access holds the lock.
private final class ProbeSKBox: @unchecked Sendable {
    private let lock = NSLock()
    private var round = 0
    private var roundStart = Date()
    private var scenario = "-"
    private var scenarioStart = Date()
    private var deliveryLog: [ProbeDelivery] = []
    private var publishLog: [ProbePublish] = []
    private var lastAccess = ""
    private var lastRefreshed = false

    func beginRound(_ round: Int) {
        lock.lock()
        defer { lock.unlock() }
        self.round = round
        roundStart = Date()
        scenario = "-"
        scenarioStart = roundStart
        publishLog = []
    }

    func endRound() {
        lock.lock()
        defer { lock.unlock() }
        round = 0
    }

    func beginScenario(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        scenario = name
        scenarioStart = Date()
        lastAccess = ""
        lastRefreshed = false
    }

    /// The label only (between a scenario's tearDown and the next setUp); the stale rule keeps the scenario's start.
    func relabel(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        scenario = name
    }

    /// "r<round> +<ms since the round began>ms [<scenario>]"
    func stamp() -> String {
        lock.lock()
        defer { lock.unlock() }
        return "r\(round) +\(Int(Date().timeIntervalSince(roundStart) * 1000))ms [\(scenario)]"
    }

    /// A witness's delivery: kept and described, or nil when the witness's round is over (it then stops). Stale: bought
    /// more than a second before the current scenario began.
    func record(listenerRound: Int, transaction: Transaction, verified: Bool, note: String?) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard listenerRound == round else { return nil }
        let now = Date()
        let stale = transaction.purchaseDate < scenarioStart.addingTimeInterval(-1)
        deliveryLog.append(ProbeDelivery(round: round, scenario: scenario, at: now, id: transaction.id, productID: transaction.productID,
                                         revoked: transaction.revocationDate != nil, stale: stale))
        let ms = Int(now.timeIntervalSince(roundStart) * 1000)
        return "r\(round) +\(ms)ms [\(scenario)] witness: update \(stale ? "STALE" : "fresh") \(ProbeSK.describe(transaction, verified: verified))"
            + (note.map { " (\($0))" } ?? "")
    }

    /// A change of the model's `snapshot`: kept with its time; a line when the access or `refreshed` changed.
    func notePublish(access: String, refreshed: Bool) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        publishLog.append(ProbePublish(round: round, scenario: scenario, at: now, access: access))
        guard access != lastAccess || refreshed != lastRefreshed else { return nil }
        lastAccess = access
        lastRefreshed = refreshed
        return "r\(round) +\(Int(now.timeIntervalSince(roundStart) * 1000))ms [\(scenario)] model: access \(access) refreshed=\(refreshed)"
    }

    func deliveries(round: Int) -> [ProbeDelivery] {
        lock.lock()
        defer { lock.unlock() }
        return deliveryLog.filter { $0.round == round }
    }

    func publishes(round: Int) -> [ProbePublish] {
        lock.lock()
        defer { lock.unlock() }
        return publishLog.filter { $0.round == round }
    }
}

/// The drain's listener state.
private final class ProbeSKDrain: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true
    private var last: Date?
    private var lines: [String] = []

    func isActive() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        active = false
    }

    func note(_ line: String) {
        lock.lock()
        last = Date()
        lines.append(line)
        lock.unlock()
        ProbeSK.emit(line)
    }

    func lastActivity() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return last
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }
}
