import Access
import Foundation

/// A copy of one `Product` as the paywall needs it (M5_CONTRACT §2.1). Prices are StoreKit's
/// formatted strings; nothing in the app fixes a price (the fixed 「¥2,400」 lives in the screenshot
/// mode only, `StoreStrings.demo*`).
struct StoreProduct: Equatable, Sendable {
    var id: String
    /// StoreKit の product.displayPrice。ja_JP の ICU では記号が全角「￥」(U+FFE5) になりうる（テストは数字だけで比べる）
    var displayPrice: String
    var price: Decimal
    /// product.subscription?.subscriptionGroupID（renewals の問い合わせに使う。Connect が付ける番号で .storekit の値とは違う）
    var subscriptionGroupID: String?
    /// product.subscription?.isEligibleForIntroOffer（await）
    var isEligibleForIntroOffer: Bool
    /// introductoryOffer が .freeTrial なら日数（P2W → 14）。無ければ nil
    var introDays: Int?
    /// product.priceFormatStyle で price / 12 を整形した「¥200」（年額だけ。月額は nil）
    var perMonthDisplayPrice: String?
}

/// What `Product.purchase()` came back with, reduced to what the model acts on (§2.1).
enum StorePurchaseResult: Equatable, Sendable {
    /// 検証済み。finish 済み
    case success(EntitlementInput)
    /// 承認待ち（Ask to Buy）
    case pending
    /// userCancelled
    case cancelled
    /// VerificationResult.unverified（finish しない）
    case unverified
}

/// The App Store as `StoreModel` sees it (§2.1): `LiveStoreClient` is StoreKit 2, the tests use
/// `FakeStoreClient`, the screenshot mode `InertStoreClient`. The model calls every method from the
/// main actor; an implementation is free to run elsewhere.
protocol StoreClient: Sendable {
    func products(ids: Set<String>) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> StorePurchaseResult
    /// 検証済みだけ
    func currentEntitlements() async -> [EntitlementInput]
    /// Product.SubscriptionInfo.status(for: groupID)（iOS 15+ の静的 API。Product を要しないのでオフライン起動でも
    /// Product.products の失敗に引きずられない）
    func renewals(groupID: String) async throws -> [RenewalInput]
    /// Transaction.updates の写し（検証済みのものを finish してから流す。取消された Transaction も revocationDate
    /// 付きで流す）。StoreModel.start() が 1 本だけ購読する
    func updates() -> AsyncStream<EntitlementInput>
    /// Transaction.unfinished を 1 回走査し、検証済みのものを finish する（start() が updates の購読の直後に 1 回呼ぶ）
    func finishUnfinished() async
    /// AppStore.sync()
    func sync() async throws
}
