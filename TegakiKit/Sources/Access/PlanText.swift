// The words and numbers of the purchase screen and 設定 › 購入, as pure functions (M5_CONTRACT §1.5).
// Prices themselves are never fixed here: the views show StoreKit's `displayPrice`; the constants are
// for the screenshot mode and KitChecks.
//
// The words come from `KitStrings` (`kit.plan.*`, 1.2, docs/M7B_CONTRACT.md §2.6). The default
// language `.ja` gives 1.1's text (J-3); the app always passes its language (lint L-7).
import Foundation
import DayKit

public enum PlanText {
    /// 「月額」「年額」
    public static func name(_ plan: Plan, language: UILanguage = .ja) -> String {
        switch plan {
        case .monthly: return KitStrings.text("kit.plan.monthly", language)
        case .yearly: return KitStrings.text("kit.plan.yearly", language)
        }
    }

    /// 「/月」「/年」
    public static func perPeriod(_ plan: Plan, language: UILanguage = .ja) -> String {
        switch plan {
        case .monthly: return KitStrings.text("kit.plan.perPeriod.monthly", language)
        case .yearly: return KitStrings.text("kit.plan.perPeriod.yearly", language)
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
    public static func savingsText(months: Int, language: UILanguage = .ja) -> String? {
        months > 0 ? KitStrings.plural("kit.plan.savings", language, count: months, [DateText.number(months, language)]) : nil
    }

    /// yearly / 12 を 1 円に丸める: 2400 → 200
    public static func perMonth(yearly: Decimal) -> Decimal {
        var value = yearly / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded
    }

    /// 設定 › 購入 の「現在のプラン」の値
    public static func statusTitle(_ access: AccessState, language: UILanguage = .ja) -> String {
        switch access {
        case .subscribed(let s):
            let planName = name(s.plan, language: language)
            return s.inGrace
                ? KitStrings.format("kit.plan.status.subscribedGrace", language, [planName])
                : KitStrings.format("kit.plan.status.subscribed", language, [planName])
        case .trial(let t):
            return KitStrings.format("kit.plan.status.trial", language, [name(t.plan, language: language)])
        case .readOnly(let reason):
            switch reason {
            case .notSubscribed: return KitStrings.text("kit.plan.status.notSubscribed", language)
            case .expired: return KitStrings.text("kit.plan.status.expired", language)
            case .billingRetry: return KitStrings.text("kit.plan.status.billingRetry", language)
            case .revoked: return KitStrings.text("kit.plan.status.revoked", language)
            case .unknown: return KitStrings.text("kit.plan.status.unknown", language)
            }
        }
    }

    /// 設定 › 購入 の日付行のラベル（readOnly は nil）
    public static func dateLabel(_ access: AccessState, language: UILanguage = .ja) -> String? {
        switch access {
        case .subscribed(let s):
            if s.inGrace { return KitStrings.text("kit.plan.date.graceUntil", language) }
            return s.willAutoRenew ? KitStrings.text("kit.plan.date.renews", language) : KitStrings.text("kit.plan.date.expires", language)
        case .trial(let t):
            return t.willAutoRenew ? KitStrings.text("kit.plan.date.trialEndsPaid", language) : KitStrings.text("kit.plan.date.trialEnds", language)
        case .readOnly:
            return nil
        }
    }

    /// 閲覧専用の理由の短い説明（設定の脚注の先頭。canEdit なら nil）
    public static func readOnlyNote(_ reason: ReadOnlyReason, language: UILanguage = .ja) -> String {
        switch reason {
        case .notSubscribed: return KitStrings.text("kit.plan.note.notSubscribed", language)
        case .expired: return KitStrings.text("kit.plan.note.expired", language)
        case .billingRetry: return KitStrings.format("kit.plan.note.billingRetry", language, [paymentPath(language: language)])
        case .revoked: return KitStrings.text("kit.plan.note.revoked", language)
        case .unknown: return KitStrings.text("kit.plan.note.unknown", language)
        }
    }

    /// 写真モードと KitChecks の固定値（実表示は savingsText）
    public static let yearlyBadge = "4 か月分お得"
    public static let readOnlyBadge = "閲覧専用"
    /// 0-6。アプリ内は短い表記（規約・サポートは「（iPadOS 17 では「Apple ID」）」つき。M5-29）
    public static let cancelPath = "「設定」›「Apple Account」›「サブスクリプション」"
    public static let paymentPath = "「設定」›「Apple Account」›「お支払いと配送先」"

    /// `yearlyBadge` in `language` (the 4 months of the contract's prices, the screenshot mode).
    public static func yearlyBadge(language: UILanguage) -> String {
        KitStrings.plural("kit.plan.savings", language, count: 4, [DateText.number(4, language)])
    }

    /// `readOnlyBadge` in `language`.
    public static func readOnlyBadgeText(language: UILanguage) -> String {
        KitStrings.text("kit.plan.badge.readOnly", language)
    }

    /// `cancelPath` in `language`: the names of the iOS Settings screens in that language (§6.1 rule 4).
    public static func cancelPath(language: UILanguage) -> String {
        KitStrings.text("kit.plan.cancelPath", language)
    }

    /// `paymentPath` in `language` (§6.1 rule 4).
    public static func paymentPath(language: UILanguage) -> String {
        KitStrings.text("kit.plan.paymentPath", language)
    }
}
