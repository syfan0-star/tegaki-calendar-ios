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

    // en: 9 texts
    private static let en: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "Su",
        "kit.weekday.letter.1": "Mo",
        "kit.weekday.letter.2": "Tu",
        "kit.weekday.letter.3": "We",
        "kit.weekday.letter.4": "Th",
        "kit.weekday.letter.5": "Fr",
        "kit.weekday.letter.6": "Sa",
    ]

    // zh-Hans: 9 texts
    private static let zhHans: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "日",
        "kit.weekday.letter.1": "一",
        "kit.weekday.letter.2": "二",
        "kit.weekday.letter.3": "三",
        "kit.weekday.letter.4": "四",
        "kit.weekday.letter.5": "五",
        "kit.weekday.letter.6": "六",
    ]

    // zh-Hant: 9 texts
    private static let zhHant: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "日",
        "kit.weekday.letter.1": "一",
        "kit.weekday.letter.2": "二",
        "kit.weekday.letter.3": "三",
        "kit.weekday.letter.4": "四",
        "kit.weekday.letter.5": "五",
        "kit.weekday.letter.6": "六",
    ]

    // ko: 9 texts
    private static let ko: [String: String] = [
        "kit.layout.tailPrefix": "~",
        "kit.layout.timeRange": "%1$@~%2$@",
        "kit.weekday.letter.0": "일",
        "kit.weekday.letter.1": "월",
        "kit.weekday.letter.2": "화",
        "kit.weekday.letter.3": "수",
        "kit.weekday.letter.4": "목",
        "kit.weekday.letter.5": "금",
        "kit.weekday.letter.6": "토",
    ]

    // fr: 9 texts
    private static let fr: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "di",
        "kit.weekday.letter.1": "lu",
        "kit.weekday.letter.2": "ma",
        "kit.weekday.letter.3": "me",
        "kit.weekday.letter.4": "je",
        "kit.weekday.letter.5": "ve",
        "kit.weekday.letter.6": "sa",
    ]

    // de: 9 texts
    private static let de: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "So",
        "kit.weekday.letter.1": "Mo",
        "kit.weekday.letter.2": "Di",
        "kit.weekday.letter.3": "Mi",
        "kit.weekday.letter.4": "Do",
        "kit.weekday.letter.5": "Fr",
        "kit.weekday.letter.6": "Sa",
    ]

    // es: 9 texts
    private static let es: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "do",
        "kit.weekday.letter.1": "lu",
        "kit.weekday.letter.2": "ma",
        "kit.weekday.letter.3": "mi",
        "kit.weekday.letter.4": "ju",
        "kit.weekday.letter.5": "vi",
        "kit.weekday.letter.6": "sá",
    ]

    // it: 9 texts
    private static let it: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "do",
        "kit.weekday.letter.1": "lu",
        "kit.weekday.letter.2": "ma",
        "kit.weekday.letter.3": "me",
        "kit.weekday.letter.4": "gi",
        "kit.weekday.letter.5": "ve",
        "kit.weekday.letter.6": "sa",
    ]

    // pt-BR: 9 texts
    private static let ptBR: [String: String] = [
        "kit.layout.tailPrefix": "–",
        "kit.layout.timeRange": "%1$@–%2$@",
        "kit.weekday.letter.0": "dom",
        "kit.weekday.letter.1": "seg",
        "kit.weekday.letter.2": "ter",
        "kit.weekday.letter.3": "qua",
        "kit.weekday.letter.4": "qui",
        "kit.weekday.letter.5": "sex",
        "kit.weekday.letter.6": "sáb",
    ]
}
