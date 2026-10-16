import Access
import Foundation
@testable import TegakiCalendar

/// The App Store of the `StoreModel` tests (M5_CONTRACT §7.3.2): what `products` / `purchase` /
/// `currentEntitlements` / `renewals` / `sync` answer is set from outside, `updates()` is a stream
/// the test feeds through `updatesContinuation`, and every call is counted. `currentEntitlements`
/// can be held back (`pauseEntitlements`) so a test can run a second command while a refresh is
/// inside the fake. Main-actor isolated like the model; nothing touches StoreKit.
@MainActor
final class FakeStoreClient: StoreClient {
    /// The group id the demo products and the fixtures carry (the .storekit's value).
    static let groupID = "21700001"

    var productsResult: Result<[StoreProduct], Error> = .success(FakeStoreClient.demoProducts)
    /// Consumed in order by `purchase`; empty → `.cancelled`.
    var purchaseResults: [Result<StorePurchaseResult, Error>] = []
    var entitlements: [EntitlementInput] = []
    var renewalsResult: Result<[RenewalInput], Error> = .success([])
    /// Thrown by `sync()` while set.
    var syncError: Error?
    /// While true, `currentEntitlements` suspends until `resumeEntitlements()`.
    var pauseEntitlements = false

    private(set) var productsCalls = 0
    private(set) var purchaseCalls: [String] = []
    private(set) var entitlementsCalls = 0
    private(set) var renewalsCalls: [String] = []
    private(set) var finishUnfinishedCalls = 0
    private(set) var syncCalls = 0
    /// How many `currentEntitlements` calls are suspended right now.
    var entitlementsWaiting: Int { entitlementContinuations.count }
    private var entitlementContinuations: [CheckedContinuation<Void, Never>] = []

    nonisolated let updatesStream: AsyncStream<EntitlementInput>
    /// `yield` an input to play `Transaction.updates`; `finish()` ends the model's listener.
    let updatesContinuation: AsyncStream<EntitlementInput>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: EntitlementInput.self)
        updatesStream = stream
        updatesContinuation = continuation
    }

    // MARK: - StoreClient

    func products(ids: Set<String>) async throws -> [StoreProduct] {
        productsCalls += 1
        return try productsResult.get().filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async throws -> StorePurchaseResult {
        purchaseCalls.append(productID)
        guard !purchaseResults.isEmpty else { return .cancelled }
        return try purchaseResults.removeFirst().get()
    }

    func currentEntitlements() async -> [EntitlementInput] {
        entitlementsCalls += 1
        if pauseEntitlements {
            await withCheckedContinuation { continuation in
                entitlementContinuations.append(continuation)
            }
        }
        return entitlements
    }

    func renewals(groupID: String) async throws -> [RenewalInput] {
        renewalsCalls.append(groupID)
        return try renewalsResult.get()
    }

    nonisolated func updates() -> AsyncStream<EntitlementInput> {
        updatesStream
    }

    func finishUnfinished() async {
        finishUnfinishedCalls += 1
    }

    func sync() async throws {
        syncCalls += 1
        if let error = syncError { throw error }
    }

    /// Lets every suspended `currentEntitlements` return (with the current `entitlements`).
    func resumeEntitlements() {
        let waiting = entitlementContinuations
        entitlementContinuations = []
        for continuation in waiting { continuation.resume() }
    }

    // MARK: - Fixtures

    /// The two products as `LiveStoreClient` would copy them from `Products.storekit`
    /// (`displayPrice` with U+00A5 as in the screenshot mode; a device may show 「￥」).
    static func product(_ plan: Plan, eligible: Bool = true) -> StoreProduct {
        switch plan {
        case .monthly:
            return StoreProduct(
                id: plan.productID,
                displayPrice: StoreStrings.demoMonthlyPrice,
                price: 300,
                subscriptionGroupID: groupID,
                isEligibleForIntroOffer: eligible,
                introDays: ProductIDs.trialDays,
                perMonthDisplayPrice: nil
            )
        case .yearly:
            return StoreProduct(
                id: plan.productID,
                displayPrice: StoreStrings.demoYearlyPrice,
                price: 2400,
                subscriptionGroupID: groupID,
                isEligibleForIntroOffer: eligible,
                introDays: ProductIDs.trialDays,
                perMonthDisplayPrice: StoreStrings.demoPerMonthPrice
            )
        }
    }

    /// In `Plan.allCases` order (monthly first), as `LiveStoreClient.products` returns them: the
    /// model's yearly-first sort is exercised.
    static let demoProducts: [StoreProduct] = Plan.allCases.map { product($0) }
}

/// The cache of the tests: what `load()` answers is set from outside, every `save` is recorded.
final class MemoryAccessCache: AccessCacheStore, @unchecked Sendable {
    /// What `load()` returns (a `save` replaces it).
    var stored: AccessSnapshot?
    /// The last snapshot the model saved; nil when it never saved.
    private(set) var saved: AccessSnapshot?
    private(set) var saveCount = 0

    init(_ stored: AccessSnapshot? = nil) {
        self.stored = stored
    }

    func load() -> AccessSnapshot? { stored }

    func save(_ snapshot: AccessSnapshot) {
        stored = snapshot
        saved = snapshot
        saveCount += 1
    }
}

/// A clock the tests move by hand (`StoreModel`'s `now`).
final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}
