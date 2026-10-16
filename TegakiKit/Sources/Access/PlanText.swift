// The words and numbers of the purchase screen and 設定 › 購入, as pure functions (M5_CONTRACT §1.5).
// Prices themselves are never fixed here: the views show StoreKit's `displayPrice`; the constants are
// for the screenshot mode and KitChecks.
import Foundation

public enum PlanText {
    /// 「月額」「年額」
    public static func name(_ plan: Plan) -> String {
        switch plan {
        case .monthly: return "月額"
        case .yearly: return "年額"
        }
    }

    /// 「/月」「/年」
    public static func perPeriod(_ plan: Plan) -> String {
        switch plan {
        case .monthly: return "/月"
        case .yearly: return "/年"
        }
    }

    /// floor(yearly の月数 12 − yearly / monthly)。300 / 2400 → 4。monthly ≤ 0 や yearly ≥ 12 × monthly なら 0
    public static func savingsMonths(monthly: Decimal, yearly: Decimal) -> Int {
        guard monthly > 0, yearly > 0, yearly < monthly * 12 else { return 0 }
        var value = Decimal(12) - yearly / monthly
        var floored = Decimal()
        NSDecimalRound(&floored, &value, 0, .down)
        return max(0, NSDecimalNumber(decimal: floored).intValue)
    }

    /// 「4 か月分お得」。0 なら nil
    public static func savingsText(months: Int) -> String? {
        months > 0 ? "\(months) か月分お得" : nil
    }

    /// yearly / 12 を 1 円に丸める: 2400 → 200
    public static func perMonth(yearly: Decimal) -> Decimal {
        var value = yearly / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded
    }

    /// 設定 › 購入 の「現在のプラン」の値
    public static func statusTitle(_ access: AccessState) -> String {
        switch access {
        case .subscribed(let s):
            return s.inGrace ? "\(name(s.plan))・請求に問題（猶予中）" : "\(name(s.plan))・有効"
        case .trial(let t):
            return "\(name(t.plan))・試用中"
        case .readOnly(let reason):
            switch reason {
            case .notSubscribed: return "未購入（閲覧専用）"
            case .expired: return "期限切れ（閲覧専用）"
            case .billingRetry: return "お支払いに問題（閲覧専用）"
            case .revoked: return "返金済み（閲覧専用）"
            case .unknown: return "確認中（閲覧専用）"
            }
        }
    }

    /// 設定 › 購入 の日付行のラベル（readOnly は nil）
    public static func dateLabel(_ access: AccessState) -> String? {
        switch access {
        case .subscribed(let s):
            if s.inGrace { return "猶予の期限" }
            return s.willAutoRenew ? "次回更新" : "有効期限"
        case .trial(let t):
            return t.willAutoRenew ? "試用の終了（有料に移行）" : "試用の終了"
        case .readOnly:
            return nil
        }
    }

    /// 閲覧専用の理由の短い説明（設定の脚注の先頭。canEdit なら nil）
    public static func readOnlyNote(_ reason: ReadOnlyReason) -> String {
        switch reason {
        case .notSubscribed: return "まだ購読していません。"
        case .expired: return "サブスクリプションの期限が切れています。"
        case .billingRetry: return "お支払いに問題があります。\(paymentPath)でお支払い方法を確認してください。"
        case .revoked: return "購入が返金または取り消されました。"
        case .unknown: return "購入の状態を確認できていません。回線が戻ると自動で確認します。"
        }
    }

    /// 写真モードと KitChecks の固定値（実表示は savingsText）
    public static let yearlyBadge = "4 か月分お得"
    public static let readOnlyBadge = "閲覧専用"
    /// 0-6。アプリ内は短い表記（規約・サポートは「（iPadOS 17 では「Apple ID」）」つき。M5-29）
    public static let cancelPath = "「設定」›「Apple Account」›「サブスクリプション」"
    public static let paymentPath = "「設定」›「Apple Account」›「お支払いと配送先」"
}
