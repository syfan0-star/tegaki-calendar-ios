import Access
import Foundation
import StoreKit

/// The words of the purchase flow (M5_CONTRACT §2.5): what a `StoreMessage` says in a toast or a
/// footnote, how a thrown error becomes a message, and the fixed prices of the screenshot mode.
/// Only the screenshot mode and `PaywallSheetTests` use the `demo*` prices; the real screens show
/// StoreKit's `displayPrice` (whose yen sign may be the full-width 「￥」 U+FFE5 on a device, while
/// these three use U+00A5).
enum StoreStrings {
    // MARK: Purchase

    static let purchased = "購読を開始しました。ありがとうございます"
    /// `.purchased` while `access` is `.trial`.
    static let trialStarted = "\(ProductIDs.trialDays) 日間の無料試用を開始しました"
    static let pending = "承認待ちです。承認されると自動で使えるようになります"
    static let unverified = "購入を確認できませんでした。しばらくしてから「購入を復元」をお試しください"
    static let offline = "App Store に接続できません。回線を確認してもう一度お試しください"
    static let notAvailable = "お住まいの地域ではこのプランを購入できません"

    static func generic(_ error: Error) -> String {
        "購入できませんでした（\(error.localizedDescription)）"
    }

    // MARK: Restore

    static let restored = "購入を復元しました"
    static let nothingToRestore = "復元できる購入がありません。購入したときと同じ Apple Account でサインインしているか確認してください"

    // MARK: Prices

    static let productsUnavailable = "App Store から価格を取得できませんでした。回線を確認して「再読み込み」を押してください"

    /// 写真モードの固定値（記号は U+00A5）
    static let demoMonthlyPrice = "¥300"
    static let demoYearlyPrice = "¥2,400"
    static let demoPerMonthPrice = "¥200"

    // MARK: Mapping

    /// The sentence for `message` (U shows it in a toast or under the CTA). `.purchased` says
    /// 「14 日間の無料試用を開始しました」 when `access` is `.trial` (§2.4 4: `access` is updated
    /// before `message`, so the caller passes the snapshot's current `access`).
    static func text(for message: StoreMessage, access: AccessState) -> String {
        switch message {
        case .purchased:
            if case .trial = access { return trialStarted }
            return purchased
        case .restored:
            return restored
        case .nothingToRestore:
            return nothingToRestore
        case .pending:
            return pending
        case .productsUnavailable:
            return productsUnavailable
        case .failed(let text):
            return text
        }
    }

    /// The message for an error thrown by `purchase` or `restore` (§2.5): `StoreKitError.networkError`
    /// and `URLError` → `offline`, `.notAvailableInStorefront` → `notAvailable`, `.userCancelled` →
    /// nil (nothing is shown), anything else → `generic`.
    static func failure(_ error: Error) -> StoreMessage? {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .userCancelled:
                return nil
            case .networkError:
                return .failed(offline)
            case .notAvailableInStorefront:
                return .failed(notAvailable)
            default:
                return .failed(generic(error))
            }
        }
        if error is URLError {
            return .failed(offline)
        }
        return .failed(generic(error))
    }
}
