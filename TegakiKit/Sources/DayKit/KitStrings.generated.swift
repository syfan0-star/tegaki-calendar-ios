// 生成物。直さない。tools/l10n/build.py
//
// Written by `python3 -I tools/l10n/build.py <repo>` (docs/M7B_CONTRACT.md §2.3) from the Kit's
// sources and tools/l10n/translations/<language>.json. To change a text, change those files and
// run the generator again: this file is written over.
//
// Sources: tools/l10n/source/kit-H.json (2 keys), tools/l10n/source/kit-K.json (61 keys).

/// The strings of TegakiKit, one table per language (D4: no `.strings`, `.xcstrings` or
/// `Bundle.module`, so the language is always the one passed in, the same on a Mac, in CI and in
/// the app). The Kit's functions take `language: UILanguage` (default `.ja`, the 1.1 text) and
/// read their words here.
public enum KitStrings {
    /// The keys that are to have a text in all ten languages (L-2), sorted: every key of the Kit's
    /// sources but the `jaOnly` ones (the ja-only formats such as `kit.date.ja.*`, which only the ja
    /// table has). Until a language is translated, `value` is nil for its keys and `text` falls back.
    public static let keys: [String] = [
        "kit.app.name",
        "kit.budget.count.one",
        "kit.budget.count.other",
        "kit.budget.page.day",
        "kit.budget.page.month",
        "kit.budget.page.week",
        "kit.budget.page.year",
        "kit.export.jsonFileName",
        "kit.export.kind.day",
        "kit.export.kind.month",
        "kit.export.kind.week",
        "kit.export.kind.year",
        "kit.holiday.dayOff",
        "kit.holiday.estimatedSuffix",
        "kit.layout.more.one",
        "kit.layout.more.other",
        "kit.layout.tailPrefix",
        "kit.layout.timeRange",
        "kit.legal.appleEULATitle",
        "kit.plan.badge.readOnly",
        "kit.plan.cancelPath",
        "kit.plan.date.expires",
        "kit.plan.date.graceUntil",
        "kit.plan.date.renews",
        "kit.plan.date.trialEnds",
        "kit.plan.date.trialEndsPaid",
        "kit.plan.monthly",
        "kit.plan.note.billingRetry",
        "kit.plan.note.expired",
        "kit.plan.note.notSubscribed",
        "kit.plan.note.revoked",
        "kit.plan.note.unknown",
        "kit.plan.paymentPath",
        "kit.plan.perPeriod.monthly",
        "kit.plan.perPeriod.yearly",
        "kit.plan.savings.one",
        "kit.plan.savings.other",
        "kit.plan.status.billingRetry",
        "kit.plan.status.expired",
        "kit.plan.status.notSubscribed",
        "kit.plan.status.revoked",
        "kit.plan.status.subscribed",
        "kit.plan.status.subscribedGrace",
        "kit.plan.status.trial",
        "kit.plan.status.unknown",
        "kit.plan.yearly",
        "kit.weekday.letter.0",
        "kit.weekday.letter.1",
        "kit.weekday.letter.2",
        "kit.weekday.letter.3",
        "kit.weekday.letter.4",
        "kit.weekday.letter.5",
        "kit.weekday.letter.6",
    ]

    /// The text of `key` in `language`; when that language's table does not have the key, the en
    /// text, and when en does not have it either, the key itself.
    public static func text(_ key: String, _ language: UILanguage) -> String {
        table(language)[key] ?? en[key] ?? key
    }

    /// `text(key, language)` with its placeholders filled from `args` (`fill`).
    public static func format(_ key: String, _ language: UILanguage, _ args: [String]) -> String {
        fill(text(key, language), args)
    }

    /// `format(key + ".one", …)` or `format(key + ".other", …)`: the form that
    /// `language.pluralCategory(count)` picks (D5, 0-8). `count` only picks the form; a text that
    /// shows the number gets it in `args`, already formatted.
    public static func plural(_ key: String, _ language: UILanguage, count: Int, _ args: [String]) -> String {
        format(key + "." + language.pluralCategory(count).rawValue, language, args)
    }

    /// The text of `key` in the table of `language` itself, without the fallback of `text`; nil when
    /// that table does not have the key. For the checks that every key has all ten languages
    /// (KitChecks, KitStringsTests).
    public static func value(_ key: String, _ language: UILanguage) -> String? {
        table(language)[key]
    }

    /// `template` with its placeholders filled from `args`, without `String(format:)` (D5): `%@`
    /// takes the next argument (the first `%@` takes `args[0]`, the second `args[1]`, …; a `%n$@`
    /// does not move this count) and `%n$@` takes `args[n - 1]` (n from 1 to 99). Nothing else is a
    /// placeholder: `%%`, `%d` and any other `%` stay as they are (numbers are formatted before they
    /// are passed). A placeholder whose argument is missing stays as it is, and a `%@` inside an
    /// argument is not filled again. The app's `L.format` and `L.plural` use the same rule.
    public static func fill(_ template: String, _ args: [String]) -> String {
        let percent = UInt8(ascii: "%"), at = UInt8(ascii: "@"), dollar = UInt8(ascii: "$")
        let zero = UInt8(ascii: "0"), nine = UInt8(ascii: "9")
        guard template.utf8.contains(percent) else { return template }
        let bytes = Array(template.utf8)
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count + 32)
        var copied = 0  // bytes[..<copied] are in `result` already
        var next = 0    // the argument of the next "%@"
        var i = 0
        while i < bytes.count {
            guard bytes[i] == percent else {
                i += 1
                continue
            }
            var end = i + 1  // ends on the "@" of the placeholder that starts at i, if there is one
            var argument = -1
            if end < bytes.count, bytes[end] == at {
                argument = next
                next += 1
            } else {
                var n = 0
                while end < bytes.count, end - i <= 2, bytes[end] >= zero, bytes[end] <= nine, n > 0 || bytes[end] != zero {
                    n = n * 10 + Int(bytes[end] - zero)
                    end += 1
                }
                if n > 0, end + 1 < bytes.count, bytes[end] == dollar, bytes[end + 1] == at {
                    argument = n - 1
                    end += 1
                }
            }
            guard argument >= 0 else {
                i += 1
                continue
            }
            if argument < args.count {
                result.append(contentsOf: bytes[copied..<i])
                result.append(contentsOf: args[argument].utf8)
                copied = end + 1
            }
            i = end + 1
        }
        if copied == 0 { return template }
        result.append(contentsOf: bytes[copied...])
        return String(decoding: result, as: UTF8.self)
    }

    private static func table(_ language: UILanguage) -> [String: String] {
        switch language {
        case .ja: return ja
        case .en: return en
        case .zhHans: return zhHans
        case .zhHant: return zhHant
        case .ko: return ko
        case .fr: return fr
        case .de: return de
        case .es: return es
        case .it: return it
        case .ptBR: return ptBR
        }
    }

    // MARK: - The tables

    // ja: 63 texts
    private static let ja: [String: String] = [
        "kit.app.name": "てがきカレンダー",
        "kit.budget.count.one": "%@ 本",
        "kit.budget.count.other": "%@ 本",
        "kit.budget.page.day": "日のページ（%@）",
        "kit.budget.page.month": "月のページ（%@）",
        "kit.budget.page.week": "週のページ（%@）",
        "kit.budget.page.year": "年のページ（%@）",
        "kit.date.ja.dayTitle": "%1$@年%2$@月%3$@日(%4$@)",
        "kit.date.ja.monthName": "%@月",
        "kit.date.ja.monthTitle": "%1$@年%2$@月",
        "kit.date.ja.plainDay": "%1$@年%2$@月%3$@日",
        "kit.date.ja.shortDay": "%1$@月%2$@日(%3$@)",
        "kit.date.ja.weekTitle": "%1$@年%2$@月%3$@日〜%4$@月%5$@日",
        "kit.date.ja.weekTitleCompact": "%1$@/%2$@〜%3$@/%4$@",
        "kit.date.ja.weekTitleCrossYear": "%1$@年%2$@月%3$@日〜%4$@年%5$@月%6$@日",
        "kit.date.ja.weekdayFull": "%@曜日",
        "kit.date.ja.yearTitle": "%@年",
        "kit.export.jsonFileName": "てがきカレンダー 手書き %@.json",
        "kit.export.kind.day": "日",
        "kit.export.kind.month": "月",
        "kit.export.kind.week": "週",
        "kit.export.kind.year": "年",
        "kit.holiday.dayOff": "振替の休み",
        "kit.holiday.estimatedSuffix": "（推定）",
        "kit.layout.more.one": "+%@件",
        "kit.layout.more.other": "+%@件",
        "kit.layout.tailPrefix": "〜",
        "kit.layout.timeRange": "%1$@〜%2$@",
        "kit.legal.appleEULATitle": "使用許諾契約（Apple 標準 EULA）",
        "kit.plan.badge.readOnly": "閲覧専用",
        "kit.plan.cancelPath": "「設定」›「Apple Account」›「サブスクリプション」",
        "kit.plan.date.expires": "有効期限",
        "kit.plan.date.graceUntil": "猶予の期限",
        "kit.plan.date.renews": "次回更新",
        "kit.plan.date.trialEnds": "試用の終了",
        "kit.plan.date.trialEndsPaid": "試用の終了（有料に移行）",
        "kit.plan.monthly": "月額",
        "kit.plan.note.billingRetry": "お支払いに問題があります。%@でお支払い方法を確認してください。",
        "kit.plan.note.expired": "サブスクリプションの期限が切れています。",
        "kit.plan.note.notSubscribed": "まだ購読していません。",
        "kit.plan.note.revoked": "購入が返金または取り消されました。",
        "kit.plan.note.unknown": "購入の状態を確認できていません。回線が戻ると自動で確認します。",
        "kit.plan.paymentPath": "「設定」›「Apple Account」›「お支払いと配送先」",
        "kit.plan.perPeriod.monthly": "/月",
        "kit.plan.perPeriod.yearly": "/年",
        "kit.plan.savings.one": "%@ か月分お得",
        "kit.plan.savings.other": "%@ か月分お得",
        "kit.plan.status.billingRetry": "お支払いに問題（閲覧専用）",
        "kit.plan.status.expired": "期限切れ（閲覧専用）",
        "kit.plan.status.notSubscribed": "未購入（閲覧専用）",
        "kit.plan.status.revoked": "返金済み（閲覧専用）",
        "kit.plan.status.subscribed": "%@・有効",
        "kit.plan.status.subscribedGrace": "%@・請求に問題（猶予中）",
        "kit.plan.status.trial": "%@・試用中",
        "kit.plan.status.unknown": "確認中（閲覧専用）",
        "kit.plan.yearly": "年額",
        "kit.weekday.letter.0": "日",
        "kit.weekday.letter.1": "月",
        "kit.weekday.letter.2": "火",
        "kit.weekday.letter.3": "水",
        "kit.weekday.letter.4": "木",
        "kit.weekday.letter.5": "金",
        "kit.weekday.letter.6": "土",
    ]

    // en: 53 texts
    private static let en: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ stroke",
        "kit.budget.count.other": "%@ strokes",
        "kit.budget.page.day": "Day page (%@)",
        "kit.budget.page.month": "Month page (%@)",
        "kit.budget.page.week": "Week page (%@)",
        "kit.budget.page.year": "Year page (%@)",
        "kit.export.jsonFileName": "Tegaki Handwriting %@.json",
        "kit.export.kind.day": "Day",
        "kit.export.kind.month": "Month",
        "kit.export.kind.week": "Week",
        "kit.export.kind.year": "Year",
        "kit.holiday.dayOff": "Day off",
        "kit.holiday.estimatedSuffix": " (est.)",
        "kit.layout.more.one": "+%@ more",
        "kit.layout.more.other": "+%@ more",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "Terms of Use (Apple Standard EULA)",
        "kit.plan.badge.readOnly": "View Only",
        "kit.plan.cancelPath": "Settings > your name > Subscriptions",
        "kit.plan.date.expires": "Expires",
        "kit.plan.date.graceUntil": "Grace Period Ends",
        "kit.plan.date.renews": "Next Renewal",
        "kit.plan.date.trialEnds": "Free Trial Ends",
        "kit.plan.date.trialEndsPaid": "Free Trial Ends (Paid After That)",
        "kit.plan.monthly": "Monthly",
        "kit.plan.note.billingRetry": "There is a problem with your payment. Check your payment method in %@.",
        "kit.plan.note.expired": "Your subscription has expired.",
        "kit.plan.note.notSubscribed": "You have not subscribed yet.",
        "kit.plan.note.revoked": "Your purchase was refunded or canceled.",
        "kit.plan.note.unknown": "Your purchase could not be checked. It is checked automatically when you are back online.",
        "kit.plan.paymentPath": "Settings > your name > Payment & Shipping",
        "kit.plan.perPeriod.monthly": "/month",
        "kit.plan.perPeriod.yearly": "/year",
        "kit.plan.savings.one": "Save %@ month",
        "kit.plan.savings.other": "Save %@ months",
        "kit.plan.status.billingRetry": "Payment problem (View Only)",
        "kit.plan.status.expired": "Expired (View Only)",
        "kit.plan.status.notSubscribed": "Not purchased (View Only)",
        "kit.plan.status.revoked": "Refunded (View Only)",
        "kit.plan.status.subscribed": "%@ · Active",
        "kit.plan.status.subscribedGrace": "%@ · Payment problem (grace period)",
        "kit.plan.status.trial": "%@ · Free trial",
        "kit.plan.status.unknown": "Checking (View Only)",
        "kit.plan.yearly": "Yearly",
        "kit.weekday.letter.0": "Su",
        "kit.weekday.letter.1": "Mo",
        "kit.weekday.letter.2": "Tu",
        "kit.weekday.letter.3": "We",
        "kit.weekday.letter.4": "Th",
        "kit.weekday.letter.5": "Fr",
        "kit.weekday.letter.6": "Sa",
    ]

    // zh-Hans: 53 texts
    private static let zhHans: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ 条线",
        "kit.budget.count.other": "%@ 条线",
        "kit.budget.page.day": "日页面（%@）",
        "kit.budget.page.month": "月页面（%@）",
        "kit.budget.page.week": "周页面（%@）",
        "kit.budget.page.year": "年页面（%@）",
        "kit.export.jsonFileName": "Tegaki 手写 %@.json",
        "kit.export.kind.day": "日",
        "kit.export.kind.month": "月",
        "kit.export.kind.week": "周",
        "kit.export.kind.year": "年",
        "kit.holiday.dayOff": "休息日",
        "kit.holiday.estimatedSuffix": "（推算）",
        "kit.layout.more.one": "+%@ 项",
        "kit.layout.more.other": "+%@ 项",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "使用条款（Apple 标准 EULA）",
        "kit.plan.badge.readOnly": "仅查看",
        "kit.plan.cancelPath": "“设置” > 你的姓名 > “订阅”",
        "kit.plan.date.expires": "有效期至",
        "kit.plan.date.graceUntil": "宽限期结束",
        "kit.plan.date.renews": "下次续订",
        "kit.plan.date.trialEnds": "试用结束",
        "kit.plan.date.trialEndsPaid": "试用结束（之后转为付费）",
        "kit.plan.monthly": "按月",
        "kit.plan.note.billingRetry": "你的付款有问题。请在%@中确认付款方式。",
        "kit.plan.note.expired": "你的订阅已过期。",
        "kit.plan.note.notSubscribed": "你尚未订阅。",
        "kit.plan.note.revoked": "你的购买已被退款或取消。",
        "kit.plan.note.unknown": "暂时无法确认购买状态。网络恢复后会自动确认。",
        "kit.plan.paymentPath": "“设置” > 你的姓名 > “付款与配送”",
        "kit.plan.perPeriod.monthly": "/月",
        "kit.plan.perPeriod.yearly": "/年",
        "kit.plan.savings.one": "省 %@ 个月",
        "kit.plan.savings.other": "省 %@ 个月",
        "kit.plan.status.billingRetry": "付款有问题（仅查看）",
        "kit.plan.status.expired": "已过期（仅查看）",
        "kit.plan.status.notSubscribed": "未购买（仅查看）",
        "kit.plan.status.revoked": "已退款（仅查看）",
        "kit.plan.status.subscribed": "%@ · 有效",
        "kit.plan.status.subscribedGrace": "%@ · 付款有问题（宽限期内）",
        "kit.plan.status.trial": "%@ · 试用中",
        "kit.plan.status.unknown": "确认中（仅查看）",
        "kit.plan.yearly": "按年",
        "kit.weekday.letter.0": "日",
        "kit.weekday.letter.1": "一",
        "kit.weekday.letter.2": "二",
        "kit.weekday.letter.3": "三",
        "kit.weekday.letter.4": "四",
        "kit.weekday.letter.5": "五",
        "kit.weekday.letter.6": "六",
    ]

    // zh-Hant: 53 texts
    private static let zhHant: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ 條線",
        "kit.budget.count.other": "%@ 條線",
        "kit.budget.page.day": "日頁面（%@）",
        "kit.budget.page.month": "月頁面（%@）",
        "kit.budget.page.week": "週頁面（%@）",
        "kit.budget.page.year": "年頁面（%@）",
        "kit.export.jsonFileName": "Tegaki 手寫 %@.json",
        "kit.export.kind.day": "日",
        "kit.export.kind.month": "月",
        "kit.export.kind.week": "週",
        "kit.export.kind.year": "年",
        "kit.holiday.dayOff": "休息日",
        "kit.holiday.estimatedSuffix": "（推估）",
        "kit.layout.more.one": "+%@ 項",
        "kit.layout.more.other": "+%@ 項",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "使用條款（Apple 標準 EULA）",
        "kit.plan.badge.readOnly": "僅檢視",
        "kit.plan.cancelPath": "「設定」> 你的姓名 >「訂閱項目」",
        "kit.plan.date.expires": "有效期限",
        "kit.plan.date.graceUntil": "寬限期結束",
        "kit.plan.date.renews": "下次續訂",
        "kit.plan.date.trialEnds": "試用結束",
        "kit.plan.date.trialEndsPaid": "試用結束（之後轉為付費）",
        "kit.plan.monthly": "月繳",
        "kit.plan.note.billingRetry": "你的付款有問題。請在%@中確認付款方式。",
        "kit.plan.note.expired": "你的訂閱已到期。",
        "kit.plan.note.notSubscribed": "你尚未訂閱。",
        "kit.plan.note.revoked": "你的購買已退款或取消。",
        "kit.plan.note.unknown": "目前無法確認購買狀態。網路恢復後會自動確認。",
        "kit.plan.paymentPath": "「設定」> 你的姓名 >「付款與寄送」",
        "kit.plan.perPeriod.monthly": "/月",
        "kit.plan.perPeriod.yearly": "/年",
        "kit.plan.savings.one": "省 %@ 個月",
        "kit.plan.savings.other": "省 %@ 個月",
        "kit.plan.status.billingRetry": "付款有問題（僅檢視）",
        "kit.plan.status.expired": "已到期（僅檢視）",
        "kit.plan.status.notSubscribed": "未購買（僅檢視）",
        "kit.plan.status.revoked": "已退款（僅檢視）",
        "kit.plan.status.subscribed": "%@ · 有效",
        "kit.plan.status.subscribedGrace": "%@ · 付款有問題（寬限期內）",
        "kit.plan.status.trial": "%@ · 試用中",
        "kit.plan.status.unknown": "確認中（僅檢視）",
        "kit.plan.yearly": "年繳",
        "kit.weekday.letter.0": "日",
        "kit.weekday.letter.1": "一",
        "kit.weekday.letter.2": "二",
        "kit.weekday.letter.3": "三",
        "kit.weekday.letter.4": "四",
        "kit.weekday.letter.5": "五",
        "kit.weekday.letter.6": "六",
    ]

    // ko: 53 texts
    private static let ko: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "선 %@개",
        "kit.budget.count.other": "선 %@개",
        "kit.budget.page.day": "일 페이지(%@)",
        "kit.budget.page.month": "월 페이지(%@)",
        "kit.budget.page.week": "주 페이지(%@)",
        "kit.budget.page.year": "연 페이지(%@)",
        "kit.export.jsonFileName": "Tegaki 손글씨 %@.json",
        "kit.export.kind.day": "일",
        "kit.export.kind.month": "월",
        "kit.export.kind.week": "주",
        "kit.export.kind.year": "연",
        "kit.holiday.dayOff": "쉬는 날",
        "kit.holiday.estimatedSuffix": " (추정)",
        "kit.layout.more.one": "+%@개",
        "kit.layout.more.other": "+%@개",
        "kit.layout.tailPrefix": "~",
        "kit.layout.timeRange": "%1$@~%2$@",
        "kit.legal.appleEULATitle": "이용 약관(Apple 표준 EULA)",
        "kit.plan.badge.readOnly": "보기 전용",
        "kit.plan.cancelPath": "설정 > 사용자의 이름 > 구독",
        "kit.plan.date.expires": "만료일",
        "kit.plan.date.graceUntil": "유예 기간 종료",
        "kit.plan.date.renews": "다음 갱신",
        "kit.plan.date.trialEnds": "체험 종료",
        "kit.plan.date.trialEndsPaid": "체험 종료(이후 유료로 전환)",
        "kit.plan.monthly": "월간",
        "kit.plan.note.billingRetry": "결제에 문제가 있어요. %@에서 결제 방법을 확인해 주세요.",
        "kit.plan.note.expired": "구독이 만료되었어요.",
        "kit.plan.note.notSubscribed": "아직 구독하지 않았어요.",
        "kit.plan.note.revoked": "구입이 환불되었거나 취소되었어요.",
        "kit.plan.note.unknown": "구입 상태를 확인하지 못했어요. 인터넷에 다시 연결되면 자동으로 확인해요.",
        "kit.plan.paymentPath": "설정 > 사용자의 이름 > 결제 및 배송",
        "kit.plan.perPeriod.monthly": "/월",
        "kit.plan.perPeriod.yearly": "/년",
        "kit.plan.savings.one": "%@개월 절약",
        "kit.plan.savings.other": "%@개월 절약",
        "kit.plan.status.billingRetry": "결제 문제(보기 전용)",
        "kit.plan.status.expired": "만료됨(보기 전용)",
        "kit.plan.status.notSubscribed": "미구입(보기 전용)",
        "kit.plan.status.revoked": "환불됨(보기 전용)",
        "kit.plan.status.subscribed": "%@ · 사용 중",
        "kit.plan.status.subscribedGrace": "%@ · 결제 문제(유예 기간)",
        "kit.plan.status.trial": "%@ · 체험 중",
        "kit.plan.status.unknown": "확인 중(보기 전용)",
        "kit.plan.yearly": "연간",
        "kit.weekday.letter.0": "일",
        "kit.weekday.letter.1": "월",
        "kit.weekday.letter.2": "화",
        "kit.weekday.letter.3": "수",
        "kit.weekday.letter.4": "목",
        "kit.weekday.letter.5": "금",
        "kit.weekday.letter.6": "토",
    ]

    // fr: 53 texts
    private static let fr: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ trait",
        "kit.budget.count.other": "%@ traits",
        "kit.budget.page.day": "Page du jour (%@)",
        "kit.budget.page.month": "Page du mois (%@)",
        "kit.budget.page.week": "Page de la semaine (%@)",
        "kit.budget.page.year": "Page de l’année (%@)",
        "kit.export.jsonFileName": "Tegaki Écriture manuscrite %@.json",
        "kit.export.kind.day": "Jour",
        "kit.export.kind.month": "Mois",
        "kit.export.kind.week": "Semaine",
        "kit.export.kind.year": "Année",
        "kit.holiday.dayOff": "Jour de repos",
        "kit.holiday.estimatedSuffix": " (estimé)",
        "kit.layout.more.one": "+%@ autre",
        "kit.layout.more.other": "+%@ autres",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "Conditions d’utilisation (CLUF standard d’Apple)",
        "kit.plan.badge.readOnly": "Lecture seule",
        "kit.plan.cancelPath": "Réglages > votre nom > Abonnements",
        "kit.plan.date.expires": "Date d’expiration",
        "kit.plan.date.graceUntil": "Fin du délai de grâce",
        "kit.plan.date.renews": "Prochain renouvellement",
        "kit.plan.date.trialEnds": "Fin de l’essai",
        "kit.plan.date.trialEndsPaid": "Fin de l’essai (payant ensuite)",
        "kit.plan.monthly": "Mensuel",
        "kit.plan.note.billingRetry": "Il y a un problème de paiement. Vérifiez votre mode de paiement dans %@.",
        "kit.plan.note.expired": "Votre abonnement a expiré.",
        "kit.plan.note.notSubscribed": "Vous n’êtes pas encore abonné.",
        "kit.plan.note.revoked": "Votre achat a été remboursé ou annulé.",
        "kit.plan.note.unknown": "L’état de votre achat n’a pas pu être vérifié. La vérification se fera automatiquement une fois la connexion rétablie.",
        "kit.plan.paymentPath": "Réglages > votre nom > Paiement et livraison",
        "kit.plan.perPeriod.monthly": "/mois",
        "kit.plan.perPeriod.yearly": "/an",
        "kit.plan.savings.one": "Économie de %@ mois",
        "kit.plan.savings.other": "Économie de %@ mois",
        "kit.plan.status.billingRetry": "Problème de paiement (lecture seule)",
        "kit.plan.status.expired": "Expiré (lecture seule)",
        "kit.plan.status.notSubscribed": "Non acheté (lecture seule)",
        "kit.plan.status.revoked": "Remboursé (lecture seule)",
        "kit.plan.status.subscribed": "%@ · Actif",
        "kit.plan.status.subscribedGrace": "%@ · Problème de paiement (délai de grâce)",
        "kit.plan.status.trial": "%@ · Essai en cours",
        "kit.plan.status.unknown": "Vérification en cours (lecture seule)",
        "kit.plan.yearly": "Annuel",
        "kit.weekday.letter.0": "di",
        "kit.weekday.letter.1": "lu",
        "kit.weekday.letter.2": "ma",
        "kit.weekday.letter.3": "me",
        "kit.weekday.letter.4": "je",
        "kit.weekday.letter.5": "ve",
        "kit.weekday.letter.6": "sa",
    ]

    // de: 53 texts
    private static let de: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ Strich",
        "kit.budget.count.other": "%@ Striche",
        "kit.budget.page.day": "Tagesseite (%@)",
        "kit.budget.page.month": "Monatsseite (%@)",
        "kit.budget.page.week": "Wochenseite (%@)",
        "kit.budget.page.year": "Jahresseite (%@)",
        "kit.export.jsonFileName": "Tegaki Handschrift %@.json",
        "kit.export.kind.day": "Tag",
        "kit.export.kind.month": "Monat",
        "kit.export.kind.week": "Woche",
        "kit.export.kind.year": "Jahr",
        "kit.holiday.dayOff": "Freier Tag",
        "kit.holiday.estimatedSuffix": " (geschätzt)",
        "kit.layout.more.one": "+%@ weiterer",
        "kit.layout.more.other": "+%@ weitere",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "Nutzungsbedingungen (Apple Standard-EULA)",
        "kit.plan.badge.readOnly": "Nur ansehen",
        "kit.plan.cancelPath": "Einstellungen > Ihr Name > Abonnements",
        "kit.plan.date.expires": "Gültig bis",
        "kit.plan.date.graceUntil": "Ende der Nachfrist",
        "kit.plan.date.renews": "Nächste Verlängerung",
        "kit.plan.date.trialEnds": "Ende der Testphase",
        "kit.plan.date.trialEndsPaid": "Ende der Testphase (danach kostenpflichtig)",
        "kit.plan.monthly": "Monatlich",
        "kit.plan.note.billingRetry": "Es gibt ein Problem mit Ihrer Zahlung. Prüfen Sie Ihre Zahlungsmethode unter %@.",
        "kit.plan.note.expired": "Ihr Abo ist abgelaufen.",
        "kit.plan.note.notSubscribed": "Sie haben noch nicht abonniert.",
        "kit.plan.note.revoked": "Ihr Kauf wurde erstattet oder widerrufen.",
        "kit.plan.note.unknown": "Ihr Kauf konnte nicht geprüft werden. Die Prüfung erfolgt automatisch, sobald Sie wieder online sind.",
        "kit.plan.paymentPath": "Einstellungen > Ihr Name > Zahlung & Versand",
        "kit.plan.perPeriod.monthly": "/Monat",
        "kit.plan.perPeriod.yearly": "/Jahr",
        "kit.plan.savings.one": "%@ Monat gespart",
        "kit.plan.savings.other": "%@ Monate gespart",
        "kit.plan.status.billingRetry": "Zahlungsproblem (Nur ansehen)",
        "kit.plan.status.expired": "Abgelaufen (Nur ansehen)",
        "kit.plan.status.notSubscribed": "Nicht gekauft (Nur ansehen)",
        "kit.plan.status.revoked": "Erstattet (Nur ansehen)",
        "kit.plan.status.subscribed": "%@ · Aktiv",
        "kit.plan.status.subscribedGrace": "%@ · Zahlungsproblem (Nachfrist)",
        "kit.plan.status.trial": "%@ · Testphase",
        "kit.plan.status.unknown": "Wird geprüft (Nur ansehen)",
        "kit.plan.yearly": "Jährlich",
        "kit.weekday.letter.0": "So",
        "kit.weekday.letter.1": "Mo",
        "kit.weekday.letter.2": "Di",
        "kit.weekday.letter.3": "Mi",
        "kit.weekday.letter.4": "Do",
        "kit.weekday.letter.5": "Fr",
        "kit.weekday.letter.6": "Sa",
    ]

    // es: 53 texts
    private static let es: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ trazo",
        "kit.budget.count.other": "%@ trazos",
        "kit.budget.page.day": "Página del día (%@)",
        "kit.budget.page.month": "Página del mes (%@)",
        "kit.budget.page.week": "Página de la semana (%@)",
        "kit.budget.page.year": "Página del año (%@)",
        "kit.export.jsonFileName": "Tegaki Escritura a mano %@.json",
        "kit.export.kind.day": "Día",
        "kit.export.kind.month": "Mes",
        "kit.export.kind.week": "Semana",
        "kit.export.kind.year": "Año",
        "kit.holiday.dayOff": "Día libre",
        "kit.holiday.estimatedSuffix": " (estimado)",
        "kit.layout.more.one": "+%@ más",
        "kit.layout.more.other": "+%@ más",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "Condiciones de uso (EULA estándar de Apple)",
        "kit.plan.badge.readOnly": "Solo lectura",
        "kit.plan.cancelPath": "Ajustes (Configuración) > su nombre > Suscripciones",
        "kit.plan.date.expires": "Caduca",
        "kit.plan.date.graceUntil": "Fin del periodo de gracia",
        "kit.plan.date.renews": "Próxima renovación",
        "kit.plan.date.trialEnds": "Fin de la prueba",
        "kit.plan.date.trialEndsPaid": "Fin de la prueba (después, de pago)",
        "kit.plan.monthly": "Mensual",
        "kit.plan.note.billingRetry": "Hay un problema con su pago. Compruebe su método de pago en %@.",
        "kit.plan.note.expired": "Su suscripción ha caducado.",
        "kit.plan.note.notSubscribed": "Aún no se ha suscrito.",
        "kit.plan.note.revoked": "Su compra se ha reembolsado o cancelado.",
        "kit.plan.note.unknown": "No se ha podido comprobar su compra. Se comprobará automáticamente cuando vuelva la conexión.",
        "kit.plan.paymentPath": "Ajustes (Configuración) > su nombre > Pago y envío",
        "kit.plan.perPeriod.monthly": "/mes",
        "kit.plan.perPeriod.yearly": "/año",
        "kit.plan.savings.one": "Ahorre %@ mes",
        "kit.plan.savings.other": "Ahorre %@ meses",
        "kit.plan.status.billingRetry": "Problema de pago (solo lectura)",
        "kit.plan.status.expired": "Caducado (solo lectura)",
        "kit.plan.status.notSubscribed": "Sin comprar (solo lectura)",
        "kit.plan.status.revoked": "Reembolsado (solo lectura)",
        "kit.plan.status.subscribed": "%@ · Activo",
        "kit.plan.status.subscribedGrace": "%@ · Problema de pago (periodo de gracia)",
        "kit.plan.status.trial": "%@ · En prueba",
        "kit.plan.status.unknown": "Comprobando (solo lectura)",
        "kit.plan.yearly": "Anual",
        "kit.weekday.letter.0": "do",
        "kit.weekday.letter.1": "lu",
        "kit.weekday.letter.2": "ma",
        "kit.weekday.letter.3": "mi",
        "kit.weekday.letter.4": "ju",
        "kit.weekday.letter.5": "vi",
        "kit.weekday.letter.6": "sá",
    ]

    // it: 53 texts
    private static let it: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ tratto",
        "kit.budget.count.other": "%@ tratti",
        "kit.budget.page.day": "Pagina del giorno (%@)",
        "kit.budget.page.month": "Pagina del mese (%@)",
        "kit.budget.page.week": "Pagina della settimana (%@)",
        "kit.budget.page.year": "Pagina dell’anno (%@)",
        "kit.export.jsonFileName": "Tegaki Scrittura a mano %@.json",
        "kit.export.kind.day": "Giorno",
        "kit.export.kind.month": "Mese",
        "kit.export.kind.week": "Settimana",
        "kit.export.kind.year": "Anno",
        "kit.holiday.dayOff": "Giorno libero",
        "kit.holiday.estimatedSuffix": " (stima)",
        "kit.layout.more.one": "+%@ altro",
        "kit.layout.more.other": "+%@ altri",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "Condizioni d’uso (EULA standard di Apple)",
        "kit.plan.badge.readOnly": "Sola lettura",
        "kit.plan.cancelPath": "Impostazioni > il Suo nome > Abbonamenti",
        "kit.plan.date.expires": "Scadenza",
        "kit.plan.date.graceUntil": "Fine del periodo di tolleranza",
        "kit.plan.date.renews": "Prossimo rinnovo",
        "kit.plan.date.trialEnds": "Fine della prova",
        "kit.plan.date.trialEndsPaid": "Fine della prova (poi a pagamento)",
        "kit.plan.monthly": "Mensile",
        "kit.plan.note.billingRetry": "C’è un problema con il pagamento. Verifichi il metodo di pagamento in %@.",
        "kit.plan.note.expired": "Il Suo abbonamento è scaduto.",
        "kit.plan.note.notSubscribed": "Non si è ancora abbonato.",
        "kit.plan.note.revoked": "L’acquisto è stato rimborsato o annullato.",
        "kit.plan.note.unknown": "Non è stato possibile verificare l’acquisto. La verifica sarà automatica quando la connessione tornerà disponibile.",
        "kit.plan.paymentPath": "Impostazioni > il Suo nome > Pagamento e spedizione",
        "kit.plan.perPeriod.monthly": "/mese",
        "kit.plan.perPeriod.yearly": "/anno",
        "kit.plan.savings.one": "Risparmi %@ mese",
        "kit.plan.savings.other": "Risparmi %@ mesi",
        "kit.plan.status.billingRetry": "Problema di pagamento (sola lettura)",
        "kit.plan.status.expired": "Scaduto (sola lettura)",
        "kit.plan.status.notSubscribed": "Non acquistato (sola lettura)",
        "kit.plan.status.revoked": "Rimborsato (sola lettura)",
        "kit.plan.status.subscribed": "%@ · Attivo",
        "kit.plan.status.subscribedGrace": "%@ · Problema di pagamento (periodo di tolleranza)",
        "kit.plan.status.trial": "%@ · In prova",
        "kit.plan.status.unknown": "Verifica in corso (sola lettura)",
        "kit.plan.yearly": "Annuale",
        "kit.weekday.letter.0": "do",
        "kit.weekday.letter.1": "lu",
        "kit.weekday.letter.2": "ma",
        "kit.weekday.letter.3": "me",
        "kit.weekday.letter.4": "gi",
        "kit.weekday.letter.5": "ve",
        "kit.weekday.letter.6": "sa",
    ]

    // pt-BR: 53 texts
    private static let ptBR: [String: String] = [
        "kit.app.name": "Tegaki",
        "kit.budget.count.one": "%@ traço",
        "kit.budget.count.other": "%@ traços",
        "kit.budget.page.day": "Página do dia (%@)",
        "kit.budget.page.month": "Página do mês (%@)",
        "kit.budget.page.week": "Página da semana (%@)",
        "kit.budget.page.year": "Página do ano (%@)",
        "kit.export.jsonFileName": "Tegaki Escrita à mão %@.json",
        "kit.export.kind.day": "Dia",
        "kit.export.kind.month": "Mês",
        "kit.export.kind.week": "Semana",
        "kit.export.kind.year": "Ano",
        "kit.holiday.dayOff": "Dia de folga",
        "kit.holiday.estimatedSuffix": " (estimado)",
        "kit.layout.more.one": "+%@ outro",
        "kit.layout.more.other": "+%@ outros",
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.legal.appleEULATitle": "Termos de Uso (EULA padrão da Apple)",
        "kit.plan.badge.readOnly": "Somente leitura",
        "kit.plan.cancelPath": "Ajustes > seu nome > Assinaturas",
        "kit.plan.date.expires": "Validade",
        "kit.plan.date.graceUntil": "Fim do período de carência",
        "kit.plan.date.renews": "Próxima renovação",
        "kit.plan.date.trialEnds": "Fim do teste",
        "kit.plan.date.trialEndsPaid": "Fim do teste (depois, pago)",
        "kit.plan.monthly": "Mensal",
        "kit.plan.note.billingRetry": "Há um problema no seu pagamento. Confira a forma de pagamento em %@.",
        "kit.plan.note.expired": "Sua assinatura expirou.",
        "kit.plan.note.notSubscribed": "Você ainda não assinou.",
        "kit.plan.note.revoked": "Sua compra foi reembolsada ou cancelada.",
        "kit.plan.note.unknown": "Não foi possível verificar sua compra. A verificação será automática quando a conexão voltar.",
        "kit.plan.paymentPath": "Ajustes > seu nome > Pagamento e Entrega",
        "kit.plan.perPeriod.monthly": "/mês",
        "kit.plan.perPeriod.yearly": "/ano",
        "kit.plan.savings.one": "Economize %@ mês",
        "kit.plan.savings.other": "Economize %@ meses",
        "kit.plan.status.billingRetry": "Problema no pagamento (somente leitura)",
        "kit.plan.status.expired": "Expirado (somente leitura)",
        "kit.plan.status.notSubscribed": "Não comprado (somente leitura)",
        "kit.plan.status.revoked": "Reembolsado (somente leitura)",
        "kit.plan.status.subscribed": "%@ · Ativo",
        "kit.plan.status.subscribedGrace": "%@ · Problema no pagamento (período de carência)",
        "kit.plan.status.trial": "%@ · Em teste",
        "kit.plan.status.unknown": "Verificando (somente leitura)",
        "kit.plan.yearly": "Anual",
        "kit.weekday.letter.0": "dom",
        "kit.weekday.letter.1": "seg",
        "kit.weekday.letter.2": "ter",
        "kit.weekday.letter.3": "qua",
        "kit.weekday.letter.4": "qui",
        "kit.weekday.letter.5": "sex",
        "kit.weekday.letter.6": "sáb",
    ]
}
