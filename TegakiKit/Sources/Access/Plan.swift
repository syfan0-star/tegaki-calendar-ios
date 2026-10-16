// Access: the subscription plans and the pure "who may write" state machine of てがきカレンダー
// (M5_CONTRACT §1). Foundation only — this target depends on nothing else, not even DayKit. The
// StoreKit layer (Sources/TegakiCalendar/Store/*) maps `Transaction` / `Status` onto the inputs
// defined here; the views read the results.
import Foundation

/// The two auto-renewable subscriptions of the group「てがきカレンダー」(M5_CONTRACT §1.1). Both give
/// the same service level; only the period differs (Apple handles the switch between them).
public enum Plan: String, Codable, CaseIterable, Sendable, Equatable {
    case monthly, yearly

    /// "com.syfan0.tegakicalendar.monthly" / "com.syfan0.tegakicalendar.yearly"
    public var productID: String { ProductIDs.prefix + rawValue }

    /// 月額 1、年額 12
    public var months: Int {
        switch self {
        case .monthly: return 1
        case .yearly: return 12
        }
    }

    /// The plan behind a product ID; nil for anything but the two IDs above.
    public init?(productID: String) {
        guard productID.hasPrefix(ProductIDs.prefix) else { return nil }
        self.init(rawValue: String(productID.dropFirst(ProductIDs.prefix.count)))
    }
}

/// Product identifiers and the contract's numbers (M5_CONTRACT §1.1).
public enum ProductIDs {
    public static let prefix = "com.syfan0.tegakicalendar."
    public static let groupReferenceName = "てがきカレンダー"
    /// Plan.allCases.map(\.productID)
    public static let all: Set<String> = Set(Plan.allCases.map(\.productID))
    /// 契約の価格（円）。表示には使わない（表示は StoreKit の displayPrice）。KitChecks と写真モードの固定値
    public static let contractPrice: [Plan: Decimal] = [.monthly: 300, .yearly: 2400]
    public static let trialDays = 14
}
