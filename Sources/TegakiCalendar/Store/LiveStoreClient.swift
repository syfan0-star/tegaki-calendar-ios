import Access
import Foundation
import StoreKit

/// StoreKit 2 (M5_CONTRACT §2.2): copies `Product`, `Transaction` and
/// `Product.SubscriptionInfo.Status` onto the Access module's inputs and finishes what it verified.
/// Nothing is decided here; `AccessPolicy` does that from the copies (D2). An actor, because the
/// fetched `Product`s are kept for `purchase(productID:)`.
///
/// DEBUG builds log every call as `store: …` (NSLog), so the CI's `log show` and a device's console
/// show the environment (`xcode` / `sandbox` / `production`), the product count and the states.
actor LiveStoreClient: StoreClient {
    /// The last `products(ids:)` result (`purchase` needs the `Product`; fetched again if missing).
    private var cachedProducts: [String: Product] = [:]

    init() {}

    // MARK: - Products

    /// `Product.products(for:)`, each copied with its intro-offer eligibility (awaited), the free
    /// trial's length in days and, for the yearly plan, `price / 12` formatted like the price.
    /// Ordered as `Plan.allCases` (yearly first is `StoreModel`'s job).
    func products(ids: Set<String>) async throws -> [StoreProduct] {
        let fetched = try await Product.products(for: ids)
        var out: [StoreProduct] = []
        for product in fetched {
            cachedProducts[product.id] = product
            let subscription = product.subscription
            let eligible = await subscription?.isEligibleForIntroOffer ?? false
            var introDays: Int?
            if let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
                introDays = Self.days(of: offer.period)
            }
            var perMonth: String?
            if Plan(productID: product.id) == .yearly {
                perMonth = product.priceFormatStyle.format(product.price / 12)
            }
            out.append(StoreProduct(
                id: product.id,
                displayPrice: product.displayPrice,
                price: product.price,
                subscriptionGroupID: subscription?.subscriptionGroupID,
                isEligibleForIntroOffer: eligible,
                introDays: introDays,
                perMonthDisplayPrice: perMonth
            ))
        }
        out.sort { Self.planIndex($0.id) < Self.planIndex($1.id) }
        Self.log("products: \(out.count) of \(ids.count) requested: " + out.map { "\($0.id) \($0.displayPrice) intro=\($0.introDays.map(String.init) ?? "-") eligible=\($0.isEligibleForIntroOffer)" }.joined(separator: "; "))
        return out
    }

    // MARK: - Purchase

    /// `Product.purchase()`: a verified transaction is finished and copied; an unverified one is
    /// neither. The `Product` comes from the last `products(ids:)` (fetched again when missing).
    func purchase(productID: String) async throws -> StorePurchaseResult {
        let product: Product
        if let cached = cachedProducts[productID] {
            product = cached
        } else {
            guard let found = try await Product.products(for: [productID]).first else {
                throw LiveStoreError.productNotFound(productID)
            }
            cachedProducts[productID] = found
            product = found
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                Self.log("purchase: verified \(transaction.productID) id=\(transaction.id) env=\(transaction.environment.rawValue) expires=\(Self.text(transaction.expirationDate))")
                return .success(Self.copy(transaction))
            case .unverified(let transaction, let error):
                Self.log("purchase: unverified \(transaction.productID) id=\(transaction.id): \(error)")
                return .unverified
            }
        case .pending:
            Self.log("purchase: pending \(productID)")
            return .pending
        case .userCancelled:
            Self.log("purchase: cancelled \(productID)")
            return .cancelled
        @unknown default:
            throw LiveStoreError.unknownPurchaseResult
        }
    }

    // MARK: - Entitlements and renewals

    /// The verified part of `Transaction.currentEntitlements` (the device's own copy: answers
    /// offline too; never contains a revoked transaction).
    nonisolated func currentEntitlements() async -> [EntitlementInput] {
        var out: [EntitlementInput] = []
        var environment = "-"
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                out.append(Self.copy(transaction))
                environment = transaction.environment.rawValue
            case .unverified(let transaction, let error):
                Self.log("unverified entitlement \(transaction.productID) id=\(transaction.id): \(error)")
            }
        }
        Self.log("entitlements: \(out.count) env=\(environment): " + out.map { "\($0.productID) id=\($0.id) expires=\(Self.text($0.expirationDate)) intro=\($0.isIntroductory)" }.joined(separator: "; "))
        return out
    }

    /// `Product.SubscriptionInfo.status(for:)` of the group, each status with a verified
    /// `renewalInfo` copied. `renewalDate` is an iOS 18 API (the deployment target is 17.0): nil
    /// before 18, and the policy falls back to the transaction's `expirationDate`.
    nonisolated func renewals(groupID: String) async throws -> [RenewalInput] {
        let statuses = try await Product.SubscriptionInfo.status(for: groupID)
        var out: [RenewalInput] = []
        for status in statuses {
            guard case .verified(let info) = status.renewalInfo else {
                Self.log("renewals: unverified renewalInfo in group \(groupID)")
                continue
            }
            let renewalDate: Date?
            if #available(iOS 18.0, *) {
                renewalDate = info.renewalDate
            } else {
                renewalDate = nil
            }
            var latest: EntitlementInput?
            if case .verified(let transaction) = status.transaction {
                latest = Self.copy(transaction)
            }
            out.append(RenewalInput(
                productID: info.currentProductID,
                state: Self.renewalState(status.state),
                willAutoRenew: info.willAutoRenew,
                gracePeriodExpirationDate: info.gracePeriodExpirationDate,
                renewalDate: renewalDate,
                autoRenewPreference: info.autoRenewPreference,
                latestTransaction: latest
            ))
        }
        Self.log("renewals(\(groupID)): \(out.count): " + out.map { "\($0.productID) \($0.state.rawValue) autoRenew=\($0.willAutoRenew) grace=\(Self.text($0.gracePeriodExpirationDate)) renewal=\(Self.text($0.renewalDate))" }.joined(separator: "; "))
        return out
    }

    /// `Transaction.unfinished`: finishes every verified transaction (a purchase whose `finish()`
    /// never ran because the app quit, Apple's recommended step at launch).
    nonisolated func finishUnfinished() async {
        var count = 0
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
                count += 1
            }
        }
        Self.log("finishUnfinished: \(count)")
    }

    /// `Transaction.updates`: every verified transaction is finished and copied (a revoked one
    /// carries its `revocationDate`). Ending the stream cancels the listener.
    nonisolated func updates() -> AsyncStream<EntitlementInput> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    switch result {
                    case .verified(let transaction):
                        await transaction.finish()
                        Self.log("update: \(transaction.productID) id=\(transaction.id) env=\(transaction.environment.rawValue) expires=\(Self.text(transaction.expirationDate)) revoked=\(transaction.revocationDate != nil)")
                        continuation.yield(Self.copy(transaction))
                    case .unverified(let transaction, let error):
                        Self.log("update: unverified \(transaction.productID) id=\(transaction.id): \(error)")
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `AppStore.sync()` (may ask for the Apple Account's password).
    nonisolated func sync() async throws {
        try await AppStore.sync()
        Self.log("sync: done")
    }

    // MARK: - Copies

    /// `Transaction` → `EntitlementInput` (§2.2). `isIntroductory` is `offer?.type == .introductory`
    /// from iOS 17.2 and `offerType == .introductory` before.
    nonisolated static func copy(_ transaction: Transaction) -> EntitlementInput {
        let introductory: Bool
        if #available(iOS 17.2, *) {
            introductory = transaction.offer?.type == .introductory
        } else {
            introductory = transaction.offerType == .introductory
        }
        return EntitlementInput(
            id: transaction.id,
            productID: transaction.productID,
            subscriptionGroupID: transaction.subscriptionGroupID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            isIntroductory: introductory
        )
    }

    /// `Product.SubscriptionInfo.RenewalState` → `RenewalState`; a state this build does not know is `.unknown`.
    nonisolated static func renewalState(_ state: Product.SubscriptionInfo.RenewalState) -> RenewalState {
        switch state {
        case .subscribed: return .subscribed
        case .expired: return .expired
        case .inBillingRetryPeriod: return .inBillingRetryPeriod
        case .inGracePeriod: return .inGracePeriod
        case .revoked: return .revoked
        default: return .unknown
        }
    }

    /// `.day` × value, `.week` × 7, `.month` × 30, `.year` × 365 (P2W → 14).
    nonisolated static func days(of period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }

    /// The position in `Plan.allCases`; unknown products sort last.
    nonisolated private static func planIndex(_ productID: String) -> Int {
        guard let plan = Plan(productID: productID), let index = Plan.allCases.firstIndex(of: plan) else {
            return Plan.allCases.count
        }
        return index
    }

    nonisolated private static func text(_ date: Date?) -> String {
        guard let date else { return "-" }
        return ISO8601DateFormatter().string(from: date)
    }

    /// `store: …` in DEBUG builds only (the CI greps `store: ` from `log show`).
    nonisolated static func log(_ message: String) {
        #if DEBUG
        NSLog("store: %@", message)
        #endif
    }
}

/// The two failures of `LiveStoreClient` that StoreKit has no error for.
enum LiveStoreError: LocalizedError {
    /// `Product.products(for:)` returned nothing for that id (the product is not in the storefront or Connect is not ready).
    case productNotFound(String)
    /// A `Product.PurchaseResult` this build does not know.
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "商品が見つかりません"
        case .unknownPurchaseResult: return "購入の結果を解釈できません"
        }
    }
}
