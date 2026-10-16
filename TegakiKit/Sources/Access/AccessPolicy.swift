// The pure state machine (M5_CONTRACT §1.2 truth table, §1.3 reconcile). Inputs are copies of
// StoreKit's verified `Transaction` and `Product.SubscriptionInfo.Status`; `now` is always an argument
// so tests can pin it.
import Foundation

/// `Product.SubscriptionInfo.RenewalState`, copied.
public enum RenewalState: String, Codable, Sendable {
    case subscribed, expired, inBillingRetryPeriod, inGracePeriod, revoked, unknown
}

/// Transaction 1 件の写し（S が写す。検証済みのものだけ）
public struct EntitlementInput: Equatable, Sendable {
    /// Transaction.id（重複排除の鍵）
    public var id: UInt64
    public var productID: String
    /// Transaction.subscriptionGroupID（renewals の問い合わせに使う）
    public var subscriptionGroupID: String?
    public var purchaseDate: Date
    public var expirationDate: Date?
    public var revocationDate: Date?
    /// 導入オファー（無料トライアル）で得た権利か（Transaction.offerType == .introductory、17.2 以降は offer?.type）
    public var isIntroductory: Bool

    public init(id: UInt64, productID: String, subscriptionGroupID: String? = nil, purchaseDate: Date, expirationDate: Date?, revocationDate: Date? = nil, isIntroductory: Bool) {
        self.id = id
        self.productID = productID
        self.subscriptionGroupID = subscriptionGroupID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isIntroductory = isIntroductory
    }
}

/// Product.SubscriptionInfo.Status 1 件の写し（検証済みの renewalInfo だけ。無ければ空配列）
public struct RenewalInput: Equatable, Sendable {
    /// renewalInfo.currentProductID
    public var productID: String
    public var state: RenewalState
    public var willAutoRenew: Bool
    public var gracePeriodExpirationDate: Date?
    /// renewalInfo.renewalDate は iOS 18.0 以降（配信対象は 17.0）。17 では nil → expirationDate に落ちる
    public var renewalDate: Date?
    /// 次回から切り替わる商品 ID（表示には使わない）
    public var autoRenewPreference: String?
    /// Status.transaction（最新の Transaction。検証済みなら写す）。currentEntitlements が一時的に空でも権利を落とさないための控え
    public var latestTransaction: EntitlementInput?

    public init(productID: String, state: RenewalState, willAutoRenew: Bool, gracePeriodExpirationDate: Date? = nil, renewalDate: Date? = nil, autoRenewPreference: String? = nil, latestTransaction: EntitlementInput? = nil) {
        self.productID = productID
        self.state = state
        self.willAutoRenew = willAutoRenew
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
        self.renewalDate = renewalDate
        self.autoRenewPreference = autoRenewPreference
        self.latestTransaction = latestTransaction
    }
}

public enum AccessPolicy {
    /// 入力から状態を 1 つ決める。順序は §1.2 の表のとおり（上から最初に当たった行）。
    /// `renewals == nil` = 更新情報を取得できなかった（オフラインなど）: 2・13 の行は `.readOnly(.unknown)`。
    ///
    /// 前処理: 候補 = `entitlements` ∪ `renewals?.compactMap(\.latestTransaction)`（`id` で重複排除。同じ id なら
    /// `entitlements` 側）。未知の商品 ID の候補と更新情報は無視する。E = 候補のうち取消でないもので
    /// `expirationDate` が最も遅いもの（nil の期限は最も遅い）。R = 更新情報のうち E と同じ商品のもの、無ければ先頭。
    public static func resolve(entitlements: [EntitlementInput], renewals: [RenewalInput]?, now: Date) -> AccessState {
        var ids = Set<UInt64>()
        var candidates: [EntitlementInput] = []
        for e in entitlements where ids.insert(e.id).inserted { candidates.append(e) }
        for r in renewals ?? [] {
            if let t = r.latestTransaction, ids.insert(t.id).inserted { candidates.append(t) }
        }
        let known = candidates.filter { Plan(productID: $0.productID) != nil }
        let valid = known.filter { $0.revocationDate == nil }
        let hasRevoked = known.contains { $0.revocationDate != nil }
        let latest = valid.max { expiry($0) < expiry($1) }

        let knownRenewals = (renewals ?? []).filter { Plan(productID: $0.productID) != nil }
        let renewal: RenewalInput?
        if let e = latest, let same = knownRenewals.first(where: { $0.productID == e.productID }) {
            renewal = same
        } else {
            renewal = knownRenewals.first
        }

        guard let e = latest, let plan = Plan(productID: e.productID) else {
            // 1
            if hasRevoked { return .readOnly(.revoked) }
            // 2
            guard let r = renewal, let rPlan = Plan(productID: r.productID) else {
                return .readOnly(renewals == nil ? .unknown : .notSubscribed)
            }
            switch r.state {
            case .inGracePeriod:
                // 3 / 8
                if let grace = r.gracePeriodExpirationDate, grace > now {
                    return .subscribed(Subscription(plan: rPlan, until: grace, willAutoRenew: r.willAutoRenew, inGrace: true))
                }
                return .readOnly(.expired)
            case .inBillingRetryPeriod:
                // 4
                return .readOnly(.billingRetry)
            case .subscribed:
                // 5 / 6
                if let renewalDate = r.renewalDate, renewalDate > now {
                    return .subscribed(Subscription(plan: rPlan, until: renewalDate, willAutoRenew: r.willAutoRenew, inGrace: false))
                }
                return .readOnly(.unknown)
            case .revoked:
                // 7
                return .readOnly(.revoked)
            case .expired, .unknown:
                // 8
                return .readOnly(.expired)
            }
        }

        let active = e.expirationDate.map { $0 > now } ?? true
        if active {
            if e.isIntroductory {
                // 9
                let until = e.expirationDate ?? now.addingTimeInterval(TimeInterval(ProductIDs.trialDays) * 86_400)
                return .trial(Trial(plan: plan, until: until, willAutoRenew: renewal?.willAutoRenew ?? true))
            }
            // 10
            let until = renewal?.renewalDate ?? e.expirationDate ?? .distantFuture
            return .subscribed(Subscription(plan: plan, until: until, willAutoRenew: renewal?.willAutoRenew ?? true, inGrace: false))
        }
        if let r = renewal, let rPlan = Plan(productID: r.productID) {
            switch r.state {
            case .inGracePeriod:
                // 11（3 と同じ）
                if let grace = r.gracePeriodExpirationDate, grace > now {
                    return .subscribed(Subscription(plan: rPlan, until: grace, willAutoRenew: r.willAutoRenew, inGrace: true))
                }
            case .inBillingRetryPeriod:
                // 12
                return .readOnly(.billingRetry)
            case .subscribed, .revoked, .expired, .unknown:
                break
            }
        }
        // 13
        return .readOnly(renewals == nil ? .unknown : .expired)
    }

    /// 起動時: StoreKit の結果 live と控え cached を合わせる（§1.3 の表 a〜g。c = `stateForLaunch(cached:now:)`）。
    /// `storeReachable == false` = App Store への問い合わせ（products か renewals）が投げた。
    public static func reconcile(live: AccessState, cached: AccessSnapshot?, storeReachable: Bool, now: Date) -> AccessState {
        // a
        if storeReachable { return live }
        // b
        if live.canEdit { return live }
        // c
        if live == .readOnly(.revoked) { return live }
        let fromCache = AccessCache.stateForLaunch(cached: cached, now: now)
        // d
        if fromCache.canEdit { return fromCache }
        // e
        if cached != nil, case .readOnly(let reason) = live, reason == .unknown || reason == .notSubscribed {
            return fromCache
        }
        // f
        if cached == nil { return .readOnly(.unknown) }
        // g
        return live
    }

    /// nil の期限は最も遅いとみなす
    private static func expiry(_ e: EntitlementInput) -> Date { e.expirationDate ?? .distantFuture }
}
