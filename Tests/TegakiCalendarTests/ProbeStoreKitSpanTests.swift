import Access
import StoreKit
import StoreKitTest
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4 D0b probe (docs/M7D_CONTRACT.md; the quick branch r14-q-probe): `StoreKitSessionTests.testIneligibleAfterATrial`
/// fails on iOS 27.2 (24B8117; D0 run 44632524223: 46 of 46 eligibility reads said true, also after the trial expired).
/// The 1.3 runs never ran it (the old simulators skipped every SKTestSession test). Two orders, in one process:
///
/// - `test1FirstReadAfterHistory` makes no eligibility read (no `model.refresh()`, no `client.products`) until the
///   history shows the purchase: buy monthly, poll (10 s) until `currentEntitlements` or `Transaction.all` shows the
///   introductory transaction, expire it, poll (10 s) until the renewals say `.expired`, then log the group's
///   `Transaction.all` (id, offer, expiry, revocation), the static `Product.SubscriptionInfo.isEligibleForIntroOffer(for:)`
///   first, then each product's `subscription.isEligibleForIntroOffer`, then LiveStoreClient's copy.
/// - `test2ReadBeforePurchase` is the failing test's order: eligibility read before buying, `refreshUntil` (which reads
///   the products again) after the purchase and after the expiry, then the same reads.
///
/// Both then read the eligibility every 300 ms for 15 s (each read logged with its UTC time in ms) and finally once
/// right after `session.clearTransactions()` and once a second later (Apple's iOS 27 note: clearTransactions resets
/// it at once). Every phase logs its elapsed time. Lines start with `probe-store:` (LiveStoreClient's own `store:`
/// lines come between them). The setUp, tearDown and helpers are StoreKitSessionTests' (copied from
/// StoreKitSessionTests.swift:24-126), changed so that a timeout or a StoreKit error is logged instead of failing.
///
/// It is a probe: it never fails on what it measures (it skips, as StoreKitSessionTests does, when the simulator's test
/// environment does not work). The class name ends in `SpanTests`, so the quick lane runs it (StoreKitSessionTests is
/// not on the quick lane); on a full run it sorts before StoreKitSessionTests.
@MainActor
final class ProbeStoreKitSpanTests: XCTestCase {
    private var session: SKTestSession!
    private var client: LiveStoreClient!
    private var model: StoreModel!
    private var started = Date()
    private var phaseStarted = Date()
    private var lines: [String] = []

    override func setUp() async throws {
        started = Date()
        phaseStarted = started
        log("setUp \(name) at \(Self.clock()) iOS \(UIDevice.current.systemVersion)")
        do {
            session = try SKTestSession(configurationFileNamed: "Products")
        } catch {
            log("setUp: SKTestSession failed: \(error)")
            throw XCTSkip("probe: SKTestSession(configurationFileNamed: \"Products\") failed: \(error)")
        }
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()
        session.storefront = "JPN"
        session.locale = Locale(identifier: "ja_JP")
        try await skipUnlessTheTestEnvironmentWorks()
        client = LiveStoreClient()
        model = StoreModel(client: client, cache: NoopAccessCache())
        phase("setUp")
    }

    /// StoreKitSessionTests.swift:43-56, copied (the skip is logged too).
    private func skipUnlessTheTestEnvironmentWorks() async throws {
        var storefront = await Storefront.current?.countryCode
        let deadline = Date().addingTimeInterval(3)
        while storefront != "JPN", Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            storefront = await Storefront.current?.countryCode
        }
        if storefront == "JPN" { return }
        let monthly = try? await Product.products(for: [Plan.monthly.productID]).first
        if monthly?.price == 300 { return }
        log("setUp: skipped: storefront \(storefront ?? "nil"), monthly price \(monthly.map { "\($0.price)" } ?? "nil")")
        throw XCTSkip("StoreKit test environment unavailable on this simulator: SKTestSession's storefront stayed \(storefront ?? "nil"), monthly price \(monthly.map { "\($0.price)" } ?? "nil") (Xcode 26.3–26.6 defect; docs/M5.md §3)")
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        model = nil
        client = nil
        session = nil
        log("tearDown \(name) at \(Self.clock()), \(Self.ms(Date().timeIntervalSince(started))) ms after setUp began")
        let all = XCTAttachment(string: lines.joined(separator: "\n"))
        all.name = "probe-store-\(name).txt"
        all.lifetime = .keepAlways
        add(all)
    }

    // MARK: - Logging

    private static let clockFormat: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(identifier: "UTC")
        format.dateFormat = "HH:mm:ss.SSS"
        return format
    }()

    private static func clock() -> String { clockFormat.string(from: Date()) }
    private static func ms(_ seconds: TimeInterval) -> String { String(format: "%.0f", seconds * 1000) }

    private static let isoFormat: ISO8601DateFormatter = {
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return format
    }()

    private static func iso(_ date: Date?) -> String { date.map { isoFormat.string(from: $0) } ?? "-" }

    /// One `probe-store:` line: the UTC time, the ms since setUp began, the text (cut into pieces of 900 characters).
    private func log(_ text: String) {
        let line = "\(Self.clock()) +\(Self.ms(Date().timeIntervalSince(started)))ms \(text)"
        lines.append(line)
        let limit = 900
        guard line.count > limit else {
            NSLog("probe-store: %@", line)
            return
        }
        let pieces = stride(from: 0, to: line.count, by: limit).map { start -> String in
            let from = line.index(line.startIndex, offsetBy: start)
            let to = line.index(from, offsetBy: limit, limitedBy: line.endIndex) ?? line.endIndex
            return String(line[from..<to])
        }
        for (index, piece) in pieces.enumerated() {
            NSLog("probe-store: [%d/%d] %@", index + 1, pieces.count, piece)
        }
    }

    /// Ends a phase: its elapsed time since the previous one.
    private func phase(_ name: String, _ note: String = "") {
        let now = Date()
        log("phase \(name): \(Self.ms(now.timeIntervalSince(phaseStarted))) ms\(note.isEmpty ? "" : "; \(note)")")
        phaseStarted = now
    }

    // MARK: - Helpers (StoreKitSessionTests', copied from StoreKitSessionTests.swift:67-126; a timeout is logged, not failed)

    private var access: AccessState { model.snapshot.access }

    /// `refresh()`, then `condition`; every 100 ms until it holds or `timeout` s pass. Logs the outcome.
    @discardableResult
    private func refreshUntil(_ what: String, timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let start = Date()
        var tries = 0
        while true {
            tries += 1
            await model.refresh()
            if condition() {
                log("refreshUntil \(what): yes after \(Self.ms(Date().timeIntervalSince(start))) ms, \(tries) refreshes; access \(access)")
                return true
            }
            if Date().timeIntervalSince(start) >= timeout { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        log("refreshUntil \(what): NO within \(timeout) s (\(tries) refreshes); access \(access)")
        return false
    }

    /// An async `condition` every `interval` ms until it holds or `timeout` s pass. Logs the outcome.
    @discardableResult
    private func pollUntil(_ what: String, timeout: TimeInterval, interval: Int = 100, _ condition: () async -> Bool) async -> Bool {
        let start = Date()
        var tries = 0
        while true {
            tries += 1
            if await condition() {
                log("pollUntil \(what): yes after \(Self.ms(Date().timeIntervalSince(start))) ms, \(tries) tries")
                return true
            }
            if Date().timeIntervalSince(start) >= timeout { break }
            try? await Task.sleep(for: .milliseconds(interval))
        }
        log("pollUntil \(what): NO within \(timeout) s (\(tries) tries)")
        return false
    }

    /// `session.buyProduct` (a purchase outside the app); a thrown error is logged.
    private func buy(_ plan: Plan) async -> Transaction? {
        do {
            let transaction = try await session.buyProduct(identifier: plan.productID)
            log("buy \(plan): \(Self.describe(transaction, verified: true))")
            return transaction
        } catch {
            log("buy \(plan): threw \(error)")
            return nil
        }
    }

    private func expire(_ plan: Plan) {
        do {
            try session.expireSubscription(productIdentifier: plan.productID)
            log("expireSubscription \(plan): done")
        } catch {
            log("expireSubscription \(plan): threw \(error)")
        }
    }

    private static func planName(_ productID: String) -> String {
        Plan(productID: productID).map { "\($0)" } ?? productID
    }

    /// A transaction's fields that decide the eligibility.
    private static func describe(_ transaction: Transaction, verified: Bool) -> String {
        var offer = "offer(<17.2)"
        if #available(iOS 17.2, *) {
            offer = transaction.offer.map { "offer type=\($0.type.rawValue) introductory=\($0.type == .introductory) mode=\($0.paymentMode?.rawValue ?? "-") id=\($0.id ?? "-")" } ?? "offer nil"
        }
        let copy = LiveStoreClient.copy(transaction)
        return "id=\(transaction.id) original=\(transaction.originalID) \(planName(transaction.productID)) group=\(transaction.subscriptionGroupID ?? "-") verified=\(verified) copy.isIntroductory=\(copy.isIntroductory) \(offer) purchased=\(iso(transaction.purchaseDate)) expires=\(iso(transaction.expirationDate)) revoked=\(iso(transaction.revocationDate)) upgraded=\(transaction.isUpgraded) env=\(transaction.environment.rawValue)"
    }

    /// `Transaction.all` (the device's history), every transaction (verified or not) of the group, or all when nil.
    private func history(groupID: String?) async -> [(transaction: Transaction, verified: Bool)] {
        var out: [(transaction: Transaction, verified: Bool)] = []
        for await result in Transaction.all {
            switch result {
            case .verified(let transaction):
                if groupID == nil || transaction.subscriptionGroupID == groupID { out.append((transaction, true)) }
            case .unverified(let transaction, _):
                if groupID == nil || transaction.subscriptionGroupID == groupID { out.append((transaction, false)) }
            }
        }
        return out
    }

    private func logHistory(_ label: String, groupID: String?) async {
        let start = Date()
        let items = await history(groupID: groupID)
        log("\(label): Transaction.all of group \(groupID ?? "(all)"): \(items.count) in \(Self.ms(Date().timeIntervalSince(start))) ms")
        for (index, item) in items.enumerated() {
            log("\(label): history \(index): \(Self.describe(item.transaction, verified: item.verified))")
        }
    }

    /// One read of the eligibility straight from StoreKit: the static per-group answer first (when the group is known),
    /// then each product's `subscription.isEligibleForIntroOffer` (fresh `Product.products(for:)`). Logged with ms.
    @discardableResult
    private func readEligibility(_ label: String, groupID: String?, staticFirst: Bool = true) async -> String {
        let startClock = Self.clock()
        let t0 = Date()
        var staticText = "static -"
        var productText = "products -"
        func readStatic() async {
            guard let groupID = groupID else { return }
            let t = Date()
            let eligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
            staticText = "static(\(groupID))=\(eligible) [\(Self.ms(Date().timeIntervalSince(t))) ms]"
        }
        func readProducts() async {
            let t = Date()
            do {
                let products = try await Product.products(for: ProductIDs.all)
                var parts: [String] = []
                for product in products.sorted(by: { $0.id < $1.id }) {
                    let eligible = await product.subscription?.isEligibleForIntroOffer
                    parts.append("\(Self.planName(product.id))=\(eligible.map { "\($0)" } ?? "no-subscription")")
                }
                productText = "products \(parts.joined(separator: " ")) [\(Self.ms(Date().timeIntervalSince(t))) ms]"
            } catch {
                productText = "products threw \(error)"
            }
        }
        if staticFirst {
            await readStatic()
            await readProducts()
        } else {
            await readProducts()
            await readStatic()
        }
        let text = "\(staticText) \(productText)"
        log("\(label): read at \(startClock) (\(Self.ms(Date().timeIntervalSince(t0))) ms): \(text)")
        return text
    }

    /// LiveStoreClient's copy (`client.products`, as the app reads it; its own `store: products` line follows).
    private func readThroughClient(_ label: String) async {
        do {
            let products = try await client.products(ids: ProductIDs.all)
            log("\(label): LiveStoreClient \(products.map { "\(Self.planName($0.id))=\($0.isEligibleForIntroOffer)" }.joined(separator: " "))")
        } catch {
            log("\(label): LiveStoreClient threw \(error)")
        }
    }

    /// What both tests do once the subscription is expired: the history, the first reads, 15 s of reads, and the reads
    /// after `clearTransactions()`.
    private func afterExpiry(_ label: String, groupID: String?) async {
        await logHistory("\(label) after expiry", groupID: groupID)
        phase("\(label) history")
        await readEligibility("\(label) first read after history (static, then products)", groupID: groupID)
        await readThroughClient("\(label) first read after history")
        phase("\(label) first reads")
        let start = Date()
        var reads = 0
        var seen: [String: Int] = [:]
        while Date().timeIntervalSince(start) < 15 {
            reads += 1
            let text = await readEligibility("\(label) poll \(reads)", groupID: groupID)
            let values = text.replacingOccurrences(of: "\\[[0-9]+ ms\\]", with: "", options: .regularExpression)
            seen[values, default: 0] += 1
            try? await Task.sleep(for: .milliseconds(300))
        }
        phase("\(label) 15 s of reads", "\(reads) reads; answers \(seen.map { "\($0.value)× \($0.key)" }.sorted().joined(separator: " | "))")
        await logHistory("\(label) after the reads", groupID: groupID)
        session.clearTransactions()
        log("\(label): clearTransactions() at \(Self.clock())")
        await readEligibility("\(label) right after clearTransactions", groupID: groupID)
        try? await Task.sleep(for: .seconds(1))
        await readEligibility("\(label) 1 s after clearTransactions", groupID: groupID)
        await logHistory("\(label) after clearTransactions", groupID: nil)
        phase("\(label) clearTransactions")
    }

    // MARK: - The probes (XCTest runs them in name order)

    /// The challenge's order: no eligibility read until the history holds the trial and the renewals say expired.
    func test1FirstReadAfterHistory() async {
        log("test1: no eligibility read until the history shows the expired trial")
        guard let transaction = await buy(.monthly) else {
            phase("test1 buy", "no transaction: stop")
            return
        }
        let groupID = transaction.subscriptionGroupID
        phase("test1 buy", "group \(groupID ?? "nil")")

        var source = "-"
        await pollUntil("test1 the introductory transaction in currentEntitlements or Transaction.all", timeout: 10, interval: 200) {
            let entitlements = await client.currentEntitlements()
            if entitlements.contains(where: { $0.id == transaction.id && $0.isIntroductory }) {
                source = "currentEntitlements"
                return true
            }
            let items = await history(groupID: groupID)
            if items.contains(where: { $0.transaction.id == transaction.id && LiveStoreClient.copy($0.transaction).isIntroductory }) {
                source = "Transaction.all"
                return true
            }
            return false
        }
        phase("test1 history shows the purchase", "seen first in \(source)")
        await logHistory("test1 before expiry", groupID: groupID)

        expire(.monthly)
        phase("test1 expire")
        if let groupID = groupID {
            await pollUntil("test1 renewals say expired", timeout: 10, interval: 200) {
                (try? await client.renewals(groupID: groupID).contains { $0.state == .expired }) ?? false
            }
        } else {
            log("test1: no group id: renewals not polled")
        }
        phase("test1 renewals expired")
        await afterExpiry("test1", groupID: groupID)
        log("test1 done at \(Self.clock())")
    }

    /// The failing test's order (StoreKitSessionTests.swift:256-273): a read before buying, `refreshUntil` after the
    /// purchase and after the expiry; then the same reads as test1.
    func test2ReadBeforePurchase() async {
        log("test2: the failing test's order (eligibility read before the purchase)")
        await readThroughClient("test2 before the purchase")
        phase("test2 read before")
        guard let transaction = await buy(.monthly) else {
            phase("test2 buy", "no transaction: stop")
            return
        }
        let groupID = transaction.subscriptionGroupID
        phase("test2 buy", "group \(groupID ?? "nil")")
        await refreshUntil("test2 canEdit") { access.canEdit }
        phase("test2 refreshUntil canEdit")
        expire(.monthly)
        await refreshUntil("test2 readOnly(.expired)") { access == .readOnly(.expired) }
        phase("test2 refreshUntil expired")
        await afterExpiry("test2", groupID: groupID)
        log("test2 done at \(Self.clock())")
    }
}
