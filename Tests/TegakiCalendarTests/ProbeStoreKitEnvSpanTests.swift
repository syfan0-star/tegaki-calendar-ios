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
/// U US storefront, S5 updates (testUpdatesStreamTriggersRefresh). No app code changes; the instruments are on the test's
/// side, and two of them change what StoreKit is asked, so the rounds alternate:
///
/// - odd rounds are instrumented: a witness (a detached task iterating `Transaction.updates` from the round's first
///   `SKTestSession` on, never finishing anything) logs every delivery; after each action the raw state
///   (`Transaction.currentEntitlements` and `Product.SubscriptionInfo.status(for:)`, not through the app) is read every
///   100 ms for up to 15 s next to the model's refreshes; `Transaction.unfinished` is logged at every setUp and tearDown;
/// - even rounds are plain, as StoreKitSessionTests asks: no witness, no unfinished reads, and the polls only refresh and
///   read the model (refreshUntil: refresh, check, 100 ms; S5's waitUntil: check, 50 ms, no refresh), for up to 15 s,
///   with one raw read when the wait ends; so an expiry follows the moment the app can edit, as in the real test;
/// - every round: the model's client is `ProbeModelClient`, which passes every call to the scenario's `LiveStoreClient`,
///   times each call of the model's refreshes (one of at least a second is a stall, logged and counted) and records every
///   delivery to the model's own `Transaction.updates` listener; every StoreKit call the test makes is timed too;
/// - a transaction is matched by id, product and purchase date (ids start at 0 again after `clearTransactions()`, so an
///   earlier scenario's leftover never counts as this one's), and a status by its transaction's id and purchase date;
/// - when an expiry or a refund is not shown in 15 s, `Transaction.all` is logged, the raw state read once more (late)
///   and, only when it still does not show it, the call is issued once more (lost);
/// - in S5 each delivery is timed against the purchase and against the model's next `snapshot` change; rounds 3 and 4
///   (bracketed by 1-2 and 5-6, which do not) drain `Transaction.updates` before `model.start()`: read for up to 5 s, until
///   2 s without a delivery, each delivery finished and logged.
///
/// Every line starts with `probe-sk:` (NSLog; LiveStoreClient's own `store:` lines come between them), and each round
/// ends with `probe-sk: round=<r> summary …`, the test with `probe-sk: final …`. It never fails on what it measures (it
/// skips, as StoreKitSessionTests does, when the simulator's test environment does not work), and its waits are bounded:
/// no round starts after `roundBudget` and no scenario after `scenarioBudget` seconds (a StoreKit call that never returns
/// is bounded by the CI step's limit). The class name ends in `SpanTests` (the quick lane's pattern); on r14-q-skprobe
/// the quick lane runs this class alone.
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
    /// The drain: `Transaction.updates` for up to `drainLimit` seconds, until `drainQuiet` seconds without a delivery (in
    /// attempt 3 the stale delivery came about 3 s after `model.start()`).
    private static let drainLimit: TimeInterval = 5
    private static let drainQuiet: TimeInterval = 2

    /// Odd rounds: the witness, the raw state on every poll, `Transaction.unfinished`. Even rounds: as the real test.
    private static func isInstrumented(_ round: Int) -> Bool { round % 2 == 1 }
    /// Rounds 3 and 4 drain `Transaction.updates` before S5's `model.start()`; 1-2 and 5-6, around them, do not.
    private static func drains(_ round: Int) -> Bool { round == 3 || round == 4 }

    private let box = ProbeSKBox()
    private var session: SKTestSession?
    private var client: LiveStoreClient?
    private var model: StoreModel?
    private var sink: AnyCancellable?
    private var witness: Task<Void, Never>?
    private var instrumented = true
    private var testStart = Date()
    private var notes = ProbeNotes(round: 0, mode: "-")
    private var allNotes: [ProbeNotes] = []
    private var lines: [String] = []

    // MARK: - The probe

    func test1Rounds() async throws {
        testStart = Date()
        log("start: \(ProcessInfo.processInfo.operatingSystemVersionString); \(Self.rounds) rounds of StoreKitSessionTests' 8 scenarios in its order "
            + "(S1 buy, C configuration, S2 expire, E ineligible, S3 refund, S4 restore, U US storefront, S5 updates); odd rounds instrumented "
            + "(witness, raw state on every poll, Transaction.unfinished), even rounds plain (as StoreKitSessionTests asks); "
            + "S5 drains Transaction.updates first in rounds 3-4")
        for round in 1...Self.rounds {
            let elapsed = Date().timeIntervalSince(testStart)
            if elapsed > Self.roundBudget {
                log("budget: \(Int(elapsed)) s after \(round - 1) rounds; no more rounds")
                break
            }
            let roundStart = Date()
            instrumented = Self.isInstrumented(round)
            box.beginRound(round)
            notes = ProbeNotes(round: round, mode: instrumented ? "instrumented" : "plain")
            log("round \(round) begins (\(notes.mode), drain \(Self.drains(round) ? "yes" : "no")), \(Int(elapsed)) s into the test")
            try await runScenario("S1", round: round) { await s1Buy(round: round) }
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
            witness?.cancel()
            witness = nil
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
        await tearDownScenario(name)
        let ms = ProbeSK.ms(since: start)
        notes.durations.append("\(name):\(ms)")
        log("\(name): \(ms) ms with its setUp and tearDown")
    }

    /// StoreKitSessionTests.setUp. The environment check skips the test only in round 1's first scenario (later ones log).
    /// In an instrumented round the witness starts in S1, right after the round's first `SKTestSession` exists.
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
        if name == "S1", instrumented {
            witness = startWitness(round: round)
            try? await Task.sleep(for: .milliseconds(200)) // the witness subscribes
        }
        let problem = await timedAsync("\(name) setUp environment check") { await environmentProblem() }
        if let problem {
            log("\(name) setUp: the test environment does not work: \(problem)")
            if round == 1 && name == "S1" {
                made.clearTransactions()
                session = nil
                witness?.cancel()
                witness = nil
                throw XCTSkip("StoreKit test environment unavailable on this simulator: \(problem) (as StoreKitSessionTests skips; Xcode 26.3-26.6 defect, docs/M5.md §3)")
            }
        }
        if instrumented {
            await logUnfinished("\(name) setUp")
        }
        let client = LiveStoreClient()
        let model = StoreModel(client: ProbeModelClient(base: client, box: box), cache: NoopAccessCache())
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

    /// StoreKitSessionTests.tearDown (in an instrumented round `Transaction.unfinished` is logged first).
    private func tearDownScenario(_ name: String) async {
        if instrumented {
            await logUnfinished("\(name) tearDown")
        }
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

    /// testBuyingMonthlyStartsATrial: buy monthly, refresh until `.trial`. In an instrumented round, whether the witness
    /// saw this purchase (if not, its delivery count means nothing in that round).
    private func s1Buy(round: Int) async {
        guard let model else { return }
        guard let transaction = await buy(.monthly, "S1") else {
            notes.parts.append("S1=noPurchase")
            return
        }
        let bought = await poll("S1 after the purchase", groupID: transaction.subscriptionGroupID, refresh: true, readsRaw: instrumented,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0, transaction) },
                                app: { ProbeSK.isTrial(model.snapshot.access) })
        checkApp("S1", bought)
        var witnessText = "off"
        if instrumented {
            let seen = box.deliveries(round: round).first { $0.listener == "witness" && ProbeSK.same($0, transaction) }
            if let seen {
                witnessText = "\(Int(seen.at.timeIntervalSince(transaction.purchaseDate) * 1000))"
                log("S1: the witness saw the purchase \(witnessText) ms after its purchaseDate")
            } else {
                witnessText = "notSeen"
                log("S1: the witness did NOT see the purchase (its delivery count means nothing in this round)")
            }
        }
        notes.parts.append("S1=\(bought.short),witness:\(witnessText)")
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
        let bought = await poll("S2 after the purchase", groupID: group, refresh: true, readsRaw: instrumented,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0, transaction) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S2.buy", bought)
        let expired = await pollAction("S2 expire", groupID: group, refresh: true, readsRaw: instrumented,
                                       action: { expire(.monthly, "S2") },
                                       raw: { !ProbeSK.holds($0, transaction) && ProbeSK.expired($0, transaction) },
                                       app: { model.snapshot.access == .readOnly(.expired) })
        checkApp("S2.expire", expired)
        notes.parts.append("S2=buy:\(bought.short),expire:\(expired.short)")
    }

    /// testIneligibleAfterATrial: buy monthly, wait for the history (no eligibility read), refresh until it can edit,
    /// expire, refresh until `.readOnly(.expired)`, then the eligibility read every 100 ms for up to 5 s. The history
    /// wait reads StoreKit in every round (the real test does).
    private func eIneligible() async {
        guard let client, let model else { return }
        guard let transaction = await buy(.monthly, "E") else {
            notes.parts.append("E=noPurchase")
            return
        }
        let group = transaction.subscriptionGroupID
        let history = await poll("E history", groupID: group, refresh: false, readsRaw: true,
                                 raw: { raw in
                                     raw.entitlements.contains {
                                         ProbeSK.same(id: $0.id, productID: $0.productID, purchased: $0.purchaseDate, transaction) && $0.isIntroductory
                                     }
                                 },
                                 app: { true })
        let editable = await poll("E refreshUntil canEdit", groupID: group, refresh: true, readsRaw: instrumented,
                                  raw: { _ in true },
                                  app: { model.snapshot.access.canEdit })
        checkApp("E.buy", editable)
        let expired = await pollAction("E expire", groupID: group, refresh: true, readsRaw: instrumented,
                                       action: { expire(.monthly, "E") },
                                       raw: { !ProbeSK.holds($0, transaction) && ProbeSK.expired($0, transaction) },
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
        let bought = await poll("S3 after the purchase", groupID: group, refresh: true, readsRaw: instrumented,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0, transaction) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S3.buy", bought)
        let refunded = await pollAction("S3 refund", groupID: group, refresh: true, readsRaw: instrumented,
                                        action: { refund(transaction, "S3") },
                                        raw: { !ProbeSK.holds($0, transaction) && ProbeSK.revoked($0, transaction) },
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
    /// `.readOnly(.notSubscribed)`, buy yearly again, wait for it in the entitlements, refresh until it can edit. The
    /// last wait reads StoreKit in every round (the real test does).
    private func s4Restore() async {
        guard let session, let model else { return }
        guard let first = await buy(.yearly, "S4") else {
            notes.parts.append("S4=noPurchase")
            return
        }
        let group = first.subscriptionGroupID
        let bought = await poll("S4 after the purchase", groupID: group, refresh: true, readsRaw: instrumented,
                                raw: { ProbeSK.holds($0, first) && ProbeSK.subscribed($0, first) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S4.buy", bought)
        timed("S4 clearTransactions", report: true) { session.clearTransactions() }
        let cleared = await poll("S4 after clearTransactions", groupID: group, refresh: true, readsRaw: instrumented,
                                 raw: { $0.entitlements.isEmpty },
                                 app: { model.snapshot.access == .readOnly(.notSubscribed) })
        checkApp("S4.clear", cleared)
        guard let second = await buy(.yearly, "S4 again") else {
            notes.parts.append("S4=buy:\(bought.short),clear:\(cleared.short),again:noPurchase")
            return
        }
        let again = await poll("S4 after the second purchase", groupID: group, refresh: true, readsRaw: true,
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
    /// it can edit. Rounds 3-4 drain `Transaction.updates` before `model.start()`. In a plain round the wait reads only the
    /// model, every 50 ms, as the real test's waitUntil.
    private func s5Updates(round: Int) async {
        guard let model else { return }
        var drained = "no"
        if Self.drains(round) {
            let count = await drainUpdates("S5")
            drained = "\(count)"
            if instrumented {
                await logUnfinished("S5 after the drain")
            }
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
        let result = await poll("S5 after the purchase", groupID: transaction.subscriptionGroupID, refresh: false, readsRaw: instrumented,
                                raw: { ProbeSK.holds($0, transaction) && ProbeSK.subscribed($0, transaction) },
                                app: { model.snapshot.access.canEdit })
        checkApp("S5", result)

        // The deliveries of S5 (to the model's own listener in every round, to the witness in the instrumented ones) against
        // the model's snapshot changes. A model delivery is recorded before the model gets it, so its next change is exact.
        let deliveries = box.deliveries(round: round).filter { $0.scenario == "S5" }
        let publishes = box.publishes(round: round).filter { $0.scenario == "S5" && $0.at >= startAt }
        var ownToModel: Int?
        var ownToWitness: Int?
        var toModel = 0
        var staleToModel = 0
        var refreshAfter = 0
        for delivery in deliveries {
            let afterPurchase = Int(delivery.at.timeIntervalSince(boughtAt) * 1000)
            let isOwn = ProbeSK.same(delivery, transaction)
            let isModel = delivery.listener == "model"
            if isOwn, isModel, ownToModel == nil { ownToModel = afterPurchase }
            if isOwn, !isModel, ownToWitness == nil { ownToWitness = afterPurchase }
            var nextText = "-"
            if isModel {
                toModel += 1
                if delivery.stale { staleToModel += 1 }
                let next = publishes.first { $0.at >= delivery.at }
                if next != nil { refreshAfter += 1 }
                nextText = next.map { "+\(Int($0.at.timeIntervalSince(delivery.at) * 1000)) ms (access \($0.access))" } ?? "none"
            }
            log("S5: \(delivery.listener) delivery \(afterPurchase) ms after the purchase (\(delivery.at >= startAt ? "after" : "before") model.start()): "
                + "id=\(delivery.id) \(ProbeSK.planName(delivery.productID)) purchased=\(ProbeSK.iso(delivery.purchased)) revoked=\(delivery.revoked) "
                + "stale=\(delivery.stale) own=\(isOwn); next model change \(nextText)")
        }
        let times = publishes.map { "+\(Int($0.at.timeIntervalSince(startAt) * 1000))" }
        log("S5: \(publishes.count) model changes after model.start() (ms): \(times.joined(separator: " ")); the purchase at "
            + "+\(Int(boughtAt.timeIntervalSince(startAt) * 1000)); access now \(ProbeSK.short(model.snapshot.access))")
        notes.parts.append("S5=drain:\(drained),\(result.short),ownToModel:\(ProbePoll.text(ownToModel)),"
            + "ownToWitness:\(instrumented ? ProbePoll.text(ownToWitness) : "off"),toModel:\(toModel),staleToModel:\(staleToModel),"
            + "refreshAfter:\(refreshAfter)/\(toModel),end:\(ProbeSK.short(model.snapshot.access))")
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

    /// A call of at least `stallLimit` is a stall (logged and counted); `report` logs every duration. A probe
    /// `model.refresh()` may wait behind a refresh the model's listener started (the model's own calls are timed apart).
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
                    item.purchased = transaction.purchaseDate
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

    /// Until both `raw` and `app` hold, or `pollLimit`. Instrumented (`readsRaw`): every 100 ms the raw state (logged when
    /// it changes) and, until `app` holds, `model.refresh()` when `refresh`. Plain: as StoreKitSessionTests' refreshUntil
    /// (refresh, check `app`, 100 ms) or, without `refresh`, its waitUntil (check `app`, 50 ms), ending when `app` holds;
    /// then the raw state once (`rawAtEnd`).
    private func poll(_ label: String, groupID: String?, refresh: Bool, readsRaw: Bool,
                      raw rawCondition: (ProbeRaw) -> Bool, app appCondition: () -> Bool) async -> ProbePoll {
        let start = Date()
        var result = ProbePoll()
        guard readsRaw else {
            while true {
                result.ticks += 1
                if refresh, let model {
                    await timedAsync("\(label) model.refresh") { await model.refresh() }
                }
                if appCondition() {
                    result.appMS = ProbeSK.ms(since: start)
                    break
                }
                if Date().timeIntervalSince(start) >= Self.pollLimit { break }
                try? await Task.sleep(for: .milliseconds(refresh ? 100 : 50))
            }
            let raw = await readRaw(groupID: groupID, label: "\(label) end")
            result.rawAtEnd = true
            if rawCondition(raw) { result.rawMS = ProbeSK.ms(since: start) }
            log("\(label) +\(ProbeSK.ms(since: start))ms raw at the end: \(raw.text)")
            log("\(label): app \(ProbePoll.text(result.appMS)) ms (\(result.ticks) checks), raw at the end \(result.rawMS == nil ? "does not show it" : "shows it"); "
                + "access \(model.map { ProbeSK.short($0.snapshot.access) } ?? "-")")
            return result
        }
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

    /// `action` (an expiry or a refund), then `poll`. When the raw state does not show it: if the app does, that is logged
    /// (no second call); else `Transaction.all` and one more raw read (late: shown after the poll), and only when that does
    /// not show it either, the action once more and `poll` again (lost).
    private func pollAction(_ label: String, groupID: String?, refresh: Bool, readsRaw: Bool, action: () -> String,
                            raw rawCondition: (ProbeRaw) -> Bool, app appCondition: () -> Bool) async -> ProbePoll {
        log("\(label): \(action())")
        var result = await poll(label, groupID: groupID, refresh: refresh, readsRaw: readsRaw, raw: rawCondition, app: appCondition)
        guard result.rawMS == nil else { return result }
        if result.appMS != nil {
            log("\(label): the app shows it, but no raw status of this transaction does (see the raw line); no second call")
            notes.rawMiss.append(label)
            return result
        }
        log("\(label): NOT reflected in \(Int(Self.pollLimit)) s")
        await logAll("\(label) not reflected")
        let check = await readRaw(groupID: groupID, label: "\(label) late check")
        if rawCondition(check) {
            result.late = true
            log("\(label): reflected late, after the \(Int(Self.pollLimit)) s poll (no second call): \(check.text)")
            notes.lost.append("\(label)(late)")
            return result
        }
        result.retried = true
        log("\(label): issued once more: \(action())")
        let second = await poll("\(label) (second call)", groupID: groupID, refresh: refresh, readsRaw: readsRaw, raw: rawCondition, app: appCondition)
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

    /// `Transaction.unfinished` as it is (nothing finished here): what the model's `finishUnfinished()` or a new listener
    /// could get. Instrumented rounds only; a non-zero count goes into the round's summary.
    private func logUnfinished(_ label: String) async {
        let start = Date()
        var items: [String] = []
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                items.append(ProbeSK.describe(transaction, verified: true))
            case .unverified(let transaction, _):
                items.append(ProbeSK.describe(transaction, verified: false))
            }
        }
        noteCall("\(label): Transaction.unfinished", start: start, report: false)
        log("\(label): Transaction.unfinished holds \(items.count)")
        for (index, item) in items.enumerated() {
            log("\(label): unfinished[\(index)] \(item)")
        }
        if !items.isEmpty {
            notes.unfinished.append("\(label.replacingOccurrences(of: " ", with: "."))=\(items.count)")
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
                    line = box.record(listener: "witness", listenerRound: round, id: transaction.id, productID: transaction.productID,
                                      purchased: transaction.purchaseDate, expires: transaction.expirationDate,
                                      revoked: transaction.revocationDate != nil, text: ProbeSK.describe(transaction, verified: true))
                case .unverified(let transaction, let error):
                    line = box.record(listener: "witness", listenerRound: round, id: transaction.id, productID: transaction.productID,
                                      purchased: transaction.purchaseDate, expires: transaction.expirationDate,
                                      revoked: transaction.revocationDate != nil,
                                      text: ProbeSK.describe(transaction, verified: false) + " (\(error))")
                }
                guard let line else { break }
                ProbeSK.emit(line)
            }
            ProbeSK.emit("r\(round) witness: the listener ended")
        }
    }

    /// The drain (rounds 3-4, before S5's `model.start()`): `Transaction.updates` for up to `drainLimit`, until `drainQuiet`
    /// without a delivery; each delivered transaction finished and logged. Returns how many.
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
            if now.timeIntervalSince(start) >= Self.drainLimit { break }
            if now.timeIntervalSince(drain.lastActivity() ?? start) >= Self.drainQuiet { break }
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
        var copies: [String: Int] = [:]
        for delivery in deliveries {
            if delivery.stale { staleBy["\(delivery.scenario)/\(delivery.listener)", default: 0] += 1 }
            copies[ProbeSK.key(delivery), default: 0] += 1
        }
        notes.stale = staleBy.keys.sorted().map { "\($0):\(staleBy[$0] ?? 0)" }
        // The same transaction in the same state delivered again to the same listener.
        let duplicates = copies.values.filter { $0 > 1 }.reduce(0) { $0 + $1 - 1 }
        notes.modelStalls = box.modelStalls(round: round)
        let witnessCount = deliveries.filter { $0.listener == "witness" }.count
        let line = "round=\(round) summary mode=\(notes.mode) drain=\(Self.drains(round) ? "yes" : "no") \(notes.parts.joined(separator: " ")) "
            + "deliveries=witness:\(instrumented ? "\(witnessCount)" : "off"),model:\(deliveries.count - witnessCount) duplicates=\(duplicates) "
            + "stale=\(ProbeSK.list(notes.stale)) lost=\(ProbeSK.list(notes.lost)) rawMiss=\(ProbeSK.list(notes.rawMiss)) "
            + "unfinished=\(ProbeSK.list(notes.unfinished)) stall=\(ProbeNotes.describeStalls(notes.stalls)) "
            + "modelStall=\(ProbeNotes.describeStalls(notes.modelStalls)) wouldFail=\(ProbeSK.list(notes.wouldFail)) "
            + "appLag=\(ProbeSK.list(notes.appLag)) failures=\(ProbeSK.list(notes.failures)) "
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
            + "lost=\(perRound { $0.lost }) rawMiss=\(perRound { $0.rawMiss }) stale=\(perRound { $0.stale }) "
            + "stall=\(perRound { $0.stalls.isEmpty ? [] : [ProbeNotes.describeStalls($0.stalls)] }) "
            + "modelStall=\(perRound { $0.modelStalls.isEmpty ? [] : [ProbeNotes.describeStalls($0.modelStalls)] }) "
            + "appLag=\(perRound { $0.appLag }) failures=\(perRound { $0.failures })"
        emitPlain(line)
    }
}

// MARK: - Shared helpers (no actor: the witness, the drain and the model's client run off the main actor)

private enum ProbeSK {
    /// A call of at least this many ms is a stall (the test's `stallLimit`, for the model's client).
    static let stallMS = 1000

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

    /// LiveStoreClient's copy, as the model's listener gets it.
    static func describe(_ input: EntitlementInput) -> String {
        "id=\(input.id) \(planName(input.productID)) intro=\(input.isIntroductory) purchased=\(iso(input.purchaseDate)) "
            + "expires=\(iso(input.expirationDate)) revoked=\(iso(input.revocationDate))"
    }

    /// The same transaction: the same id, product and purchase date (to 2 ms; the signed dates are whole ms). Ids start at
    /// 0 again after `clearTransactions()`, so the id alone matches an earlier scenario's leftover too.
    static func same(id: UInt64, productID: String, purchased: Date, _ transaction: Transaction) -> Bool {
        id == transaction.id && productID == transaction.productID && abs(purchased.timeIntervalSince(transaction.purchaseDate)) < 0.002
    }

    static func same(_ delivery: ProbeDelivery, _ transaction: Transaction) -> Bool {
        same(id: delivery.id, productID: delivery.productID, purchased: delivery.purchased, transaction)
    }

    /// The transaction is a current entitlement.
    static func holds(_ raw: ProbeRaw, _ transaction: Transaction) -> Bool {
        raw.entitlements.contains { same(id: $0.id, productID: $0.productID, purchased: $0.purchaseDate, transaction) }
    }

    /// The status is the transaction's (its own verified transaction: the same id and purchase date).
    static func isOf(_ status: ProbeStatus, _ transaction: Transaction) -> Bool {
        guard let id = status.transactionID, let purchased = status.purchased else { return false }
        return id == transaction.id && abs(purchased.timeIntervalSince(transaction.purchaseDate)) < 0.002
    }

    static func subscribed(_ raw: ProbeRaw, _ transaction: Transaction) -> Bool {
        raw.statuses.contains { $0.state == .subscribed && isOf($0, transaction) }
    }

    static func expired(_ raw: ProbeRaw, _ transaction: Transaction) -> Bool {
        raw.statuses.contains { $0.state == .expired && isOf($0, transaction) } && !raw.statuses.contains { $0.state == .subscribed }
    }

    static func revoked(_ raw: ProbeRaw, _ transaction: Transaction) -> Bool {
        raw.statuses.contains { ($0.state == .revoked || $0.revoked) && isOf($0, transaction) }
    }

    /// A delivery's identity and state: two equal keys to one listener are the same delivery again.
    static func key(_ delivery: ProbeDelivery) -> String {
        let purchased = Int(delivery.purchased.timeIntervalSince1970 * 1000)
        let expires = delivery.expires.map { "\(Int($0.timeIntervalSince1970 * 1000))" } ?? "-"
        return "\(delivery.listener)|\(delivery.id)|\(delivery.productID)|\(purchased)|\(expires)|\(delivery.revoked)"
    }
}

private struct ProbeStatus {
    var state: RenewalState
    var transactionID: UInt64?
    var purchased: Date?
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
            held.append("\(ProbeSK.planName(item.productID)) id=\(item.id) purchased=\(ProbeSK.iso(item.purchaseDate)) intro=\(item.isIntroductory) "
                + "expires=\(expires) revoked=\(item.revocationDate != nil)")
        }
        var states: [String] = []
        if let statusError {
            states.append("threw \(statusError)")
        } else {
            for status in statuses {
                let transactionText = status.transactionID.map { "\($0)" } ?? "-"
                let expires = ProbeSK.iso(status.expires)
                states.append("\(status.state.rawValue) tx=\(transactionText) purchased=\(ProbeSK.iso(status.purchased)) revoked=\(status.revoked) expires=\(expires)")
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
    /// A plain poll: the raw state was read once, when the wait ended (`rawMS` is that moment).
    var rawAtEnd = false
    /// Not shown in the poll, shown by the read right after it (no second call).
    var late = false
    var retried = false
    var secondRawMS: Int?
    var secondAppMS: Int?

    var short: String {
        var text = "\(rawAtEnd ? "rawEnd" : "raw"):\(Self.text(rawMS))/app:\(Self.text(appMS))"
        if late { text += "/late" }
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
    var mode: String
    var parts: [String] = []
    var durations: [String] = []
    var stalls: [ProbeStall] = []
    var modelStalls: [ProbeStall] = []
    var lost: [String] = []
    var rawMiss: [String] = []
    var unfinished: [String] = []
    var stale: [String] = []
    var wouldFail: [String] = []
    var appLag: [String] = []
    var failures: [String] = []

    /// How many stalls and the longest.
    static func describeStalls(_ stalls: [ProbeStall]) -> String {
        guard let longest = stalls.max(by: { $0.ms < $1.ms }) else { return "-" }
        return "\(stalls.count)(max \(longest.what):\(longest.ms)ms)"
    }
}

/// One delivery of `Transaction.updates`: to the witness, or to the model's own listener (through `ProbeModelClient`).
private struct ProbeDelivery {
    var listener: String
    var round: Int
    var scenario: String
    var at: Date
    var id: UInt64
    var productID: String
    var purchased: Date
    var expires: Date?
    var revoked: Bool
    var stale: Bool
}

private struct ProbePublish {
    var round: Int
    var scenario: String
    var at: Date
    var access: String
}

/// The model's client in the probe: every call goes to the scenario's `LiveStoreClient` (the model and the test share it,
/// as in StoreKitSessionTests). The calls of the model's refreshes are timed (one of at least a second is logged and
/// counted), and every delivery of its `updates()` is recorded before the model gets it. `StoreModel` takes any
/// `StoreClient`, so no app code changes.
private struct ProbeModelClient: StoreClient {
    let base: LiveStoreClient
    let box: ProbeSKBox

    func products(ids: Set<String>) async throws -> [StoreProduct] {
        let start = Date()
        defer { box.noteModelCall("products", start: start) }
        return try await base.products(ids: ids)
    }

    func purchase(productID: String) async throws -> StorePurchaseResult {
        try await base.purchase(productID: productID)
    }

    func currentEntitlements() async -> [EntitlementInput] {
        let start = Date()
        defer { box.noteModelCall("currentEntitlements", start: start) }
        return await base.currentEntitlements()
    }

    func renewals(groupID: String) async throws -> [RenewalInput] {
        let start = Date()
        defer { box.noteModelCall("renewals", start: start) }
        return try await base.renewals(groupID: groupID)
    }

    func updates() -> AsyncStream<EntitlementInput> {
        let inner = base.updates()
        let box = self.box
        return AsyncStream { continuation in
            let task = Task {
                for await input in inner {
                    let line = box.record(listener: "model", listenerRound: nil, id: input.id, productID: input.productID,
                                          purchased: input.purchaseDate, expires: input.expirationDate,
                                          revoked: input.revocationDate != nil, text: ProbeSK.describe(input))
                    if let line { ProbeSK.emit(line) }
                    continuation.yield(input)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func finishUnfinished() async {
        let start = Date()
        defer { box.noteModelCall("finishUnfinished", start: start) }
        await base.finishUnfinished()
    }

    func sync() async throws {
        try await base.sync()
    }
}

/// What the test (main actor), the witness, the model's client and the model's `$snapshot` sink share. Every access holds
/// the lock.
private final class ProbeSKBox: @unchecked Sendable {
    private let lock = NSLock()
    private var round = 0
    private var roundStart = Date()
    private var scenario = "-"
    private var scenarioStart = Date()
    private var deliveryLog: [ProbeDelivery] = []
    private var publishLog: [ProbePublish] = []
    private var modelStallLog: [(round: Int, stall: ProbeStall)] = []
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

    /// A delivery to `listener`: kept and described, or nil when the witness's round (`listenerRound`) is over (it then
    /// stops; the model's client passes nil). Stale: bought more than a second before the current scenario began.
    func record(listener: String, listenerRound: Int?, id: UInt64, productID: String, purchased: Date, expires: Date?,
                revoked: Bool, text: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let listenerRound, listenerRound != round { return nil }
        let now = Date()
        let stale = purchased < scenarioStart.addingTimeInterval(-1)
        deliveryLog.append(ProbeDelivery(listener: listener, round: round, scenario: scenario, at: now, id: id, productID: productID,
                                         purchased: purchased, expires: expires, revoked: revoked, stale: stale))
        let ms = Int(now.timeIntervalSince(roundStart) * 1000)
        return "r\(round) +\(ms)ms [\(scenario)] \(listener): update \(stale ? "STALE" : "fresh") \(text)"
    }

    /// One call of the model's client: a stall (at least `ProbeSK.stallMS`) is kept and logged.
    func noteModelCall(_ what: String, start: Date) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        guard ms >= ProbeSK.stallMS else { return }
        lock.lock()
        modelStallLog.append((round: round, stall: ProbeStall(what: "\(scenario).\(what)", ms: ms)))
        let line = "r\(round) +\(Int(Date().timeIntervalSince(roundStart) * 1000))ms [\(scenario)] STALL in the model: \(what) took \(ms) ms"
        lock.unlock()
        ProbeSK.emit(line)
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

    func modelStalls(round: Int) -> [ProbeStall] {
        lock.lock()
        defer { lock.unlock() }
        return modelStallLog.filter { $0.round == round }.map { $0.stall }
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
