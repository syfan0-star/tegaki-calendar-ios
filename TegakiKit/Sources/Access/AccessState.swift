// The access state the whole app reads (M5_CONTRACT §1.2): paid, in the free trial, or read only
// with a reason. `canEdit` is the only thing the gated operations look at (§3.1).
import Foundation

/// A paid period.
public struct Subscription: Equatable, Codable, Sendable {
    public var plan: Plan
    /// willAutoRenew なら次回更新日、解約済みなら有効期限、猶予中なら猶予の期限
    public var until: Date
    public var willAutoRenew: Bool
    /// 支払いに失敗して請求猶予期間にいる（Apple の gracePeriodExpirationDate まで使える）
    public var inGrace: Bool

    public init(plan: Plan, until: Date, willAutoRenew: Bool, inGrace: Bool) {
        self.plan = plan
        self.until = until
        self.willAutoRenew = willAutoRenew
        self.inGrace = inGrace
    }
}

/// The 14-day introductory offer.
public struct Trial: Equatable, Codable, Sendable {
    public var plan: Plan
    /// 試用の終了（willAutoRenew なら有料に移る日）
    public var until: Date
    public var willAutoRenew: Bool

    public init(plan: Plan, until: Date, willAutoRenew: Bool) {
        self.plan = plan
        self.until = until
        self.willAutoRenew = willAutoRenew
    }
}

/// Why the app is read only.
public enum ReadOnlyReason: String, Codable, Sendable {
    /// 権利が一度も無い（初回・新しい Apple Account）
    case notSubscribed
    /// 期限切れ（解約後、または猶予も尽きた）
    case expired
    /// 猶予なしの請求リトライ中（Apple が再請求を試みている）
    case billingRetry
    /// 返金・取消
    case revoked
    /// 控えも無く StoreKit にも届かない（初回起動がオフラインなど）
    case unknown
}

public enum AccessState: Equatable, Codable, Sendable {
    case subscribed(Subscription)
    case trial(Trial)
    case readOnly(ReadOnlyReason)

    /// .subscribed / .trial なら true（止める操作の判定はこれだけを見る。§3.1）
    public var canEdit: Bool {
        switch self {
        case .subscribed, .trial: return true
        case .readOnly: return false
        }
    }

    /// readOnly は nil
    public var plan: Plan? {
        switch self {
        case .subscribed(let s): return s.plan
        case .trial(let t): return t.plan
        case .readOnly: return nil
        }
    }

    /// readOnly は nil
    public var until: Date? {
        switch self {
        case .subscribed(let s): return s.until
        case .trial(let t): return t.until
        case .readOnly: return nil
        }
    }
}
