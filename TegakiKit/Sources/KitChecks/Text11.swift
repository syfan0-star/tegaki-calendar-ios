// Text11: the text functions of 1.1, copied unchanged so that KitChecks can prove the Japanese text of
// 1.2 is the same, character for character (docs/M7B_CONTRACT.md §1.3 J-3, 0-9). NOBODY EDITS THIS FILE:
// it is the reference, not code to keep up to date.
//
// Copied from main e7b4d2f (e7b4d2f9c99dcfe4f7ba27ef9f81fe0466bf093d, 1.1; the Kit's sources are the
// same since 21ceba5). Each type is the 1.1 type with "11" added to its name; the bodies are the 1.1
// bodies, with the names of the copied types changed to the copies (PageNavigation.title →
// PageNavigation11.title inside pageLabel and pdfFileName, MonthLayoutEngine.formatTime →
// MonthLayoutEngine11.formatTime inside timeText).
//
//   PageNavigation11     TegakiKit/Sources/Layout/PageNavigation.swift:8-9 (weekdayLetters), 65-68
//                        (mondayOnOrBefore, with the one line of MonthLayout.swift:47-50 put in place of
//                        its call), 104-125 (title), 127-142 (compactTitle)
//   YearMonth.title11    TegakiKit/Sources/DayKit/DayKey.swift:153-154 (YearMonth.title)
//   StrokeBudget11       TegakiKit/Sources/InkModel/StrokeBudget.swift:83-99 (pageLabel), 101-111 (countText)
//   PlanText11           TegakiKit/Sources/Access/PlanText.swift:6-93 (every function and constant)
//   AppExport11          TegakiKit/Sources/InkModel/AppExport.swift:136-139 (jsonFileName), 141-145
//                        (pdfFileName), 147-155 (kindLabel), 157-160 (safeFileName)
//   MonthLayoutEngine11  TegakiKit/Sources/Layout/MonthLayoutEngine.swift:188-194 (timeText(for:…)),
//                        196-202 (formatTime)
//   TimedEventEngine11   TegakiKit/Sources/Layout/TimedEventEngine.swift:145-148 (timeText), 150-153
//                        (timeRangeText)
//
// What the copies still call of the current code is not text: JapaneseHolidays (its data; J-5 checks
// it), PageNavigation.parse (page ids), DayKey and the Access types.
import Foundation
import Layout
import Holidays
import Access

// MARK: - PageNavigation (Layout/PageNavigation.swift)

enum PageNavigation11 {
    /// 日 月 火 水 木 金 土, indexed by `DayKey.weekday` (0 = Sunday).
    static let weekdayLetters = ["日", "月", "火", "水", "木", "金", "土"]

    /// The Monday on or before `day` (= `MonthLayout.mondayOnOrBefore`).
    static func mondayOnOrBefore(_ day: DayKey) -> DayKey {
        day.adding(days: -((day.weekday + 6) % 7))
    }

    /// The header title (DESIGN §2.7): day 「2026年10月4日(日) 体育の日」 (the holiday name after a
    /// space, only when there is one); week 「2026年9月28日〜10月4日」 (the year on both sides when
    /// the week crosses a year, the month always on both sides); month 「2026年10月」; year 「2026年」.
    static func title(_ kind: PageKind, focus: DayKey) -> String {
        switch kind {
        case .day:
            var text = "\(focus.year)年\(focus.month)月\(focus.day)日(\(weekdayLetters[focus.weekday]))"
            if let holiday = JapaneseHolidays.name(of: focus) { text += " " + holiday }
            return text
        case .week:
            let start = mondayOnOrBefore(focus)
            let last = start.adding(days: 6)
            let head = "\(start.year)年\(start.month)月\(start.day)日"
            let tailDay = "\(last.month)月\(last.day)日"
            let tail = last.year == start.year ? tailDay : "\(last.year)年" + tailDay
            return head + "〜" + tail
        case .month:
            return "\(focus.year)年\(focus.month)月"
        case .year:
            return "\(focus.year)年"
        }
    }

    /// The short title of the compact header (an iPhone in portrait, M4B_CONTRACT §5; `title` is
    /// unchanged): day 「10月7日(水)」 (no holiday name: the paper's date heading shows it); week
    /// 「10/5〜10/11」 (month/day on both sides, never the year: 「9/28〜10/4」, 「12/28〜1/3」);
    /// month 「2026年10月」; year 「2026年」.
    static func compactTitle(_ kind: PageKind, focus: DayKey) -> String {
        switch kind {
        case .day:
            return "\(focus.month)月\(focus.day)日(\(weekdayLetters[focus.weekday]))"
        case .week:
            let start = mondayOnOrBefore(focus)
            let last = start.adding(days: 6)
            return "\(start.month)/\(start.day)〜\(last.month)/\(last.day)"
        case .month, .year:
            return title(kind, focus: focus)
        }
    }
}

// MARK: - YearMonth.title (DayKit/DayKey.swift)

extension YearMonth {
    /// "2026年10月"
    var title11: String { "\(year)年\(month)月" }
}

// MARK: - StrokeBudget (InkModel/StrokeBudget.swift)

enum StrokeBudget11 {
    /// 「年のページ（2026年）」「月のページ（2026年10月）」「週のページ（2026年10月5日〜10月11日）」
    /// (the header's week title, `PageNavigation.title(.week, focus:)`) 「日のページ（2026年10月7日）」
    /// (no weekday, no holiday name). A page id `PageNavigation.parse` cannot read is returned as it is.
    static func pageLabel(_ pageId: String) -> String {
        guard let page = PageNavigation.parse(pageId: pageId) else { return pageId }
        let d = page.focus
        switch page.kind {
        case .year:
            return "年のページ（\(PageNavigation11.title(.year, focus: d))）"
        case .month:
            return "月のページ（\(PageNavigation11.title(.month, focus: d))）"
        case .week:
            return "週のページ（\(PageNavigation11.title(.week, focus: d))）"
        case .day:
            return "日のページ（\(d.year)年\(d.month)月\(d.day)日）"
        }
    }

    /// 「12,345 本」: the number grouped by three digits with a half-width comma (whatever the locale),
    /// a space, 本.
    static func countText(_ n: Int) -> String {
        let digits = String(n.magnitude)
        var grouped = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { grouped.append(",") }
            grouped.append(ch)
        }
        return (n < 0 ? "-" : "") + grouped + " 本"
    }
}

// MARK: - PlanText (Access/PlanText.swift)

enum PlanText11 {
    /// 「月額」「年額」
    static func name(_ plan: Plan) -> String {
        switch plan {
        case .monthly: return "月額"
        case .yearly: return "年額"
        }
    }

    /// 「/月」「/年」
    static func perPeriod(_ plan: Plan) -> String {
        switch plan {
        case .monthly: return "/月"
        case .yearly: return "/年"
        }
    }

    /// floor(yearly の月数 12 − yearly / monthly)。300 / 2400 → 4。monthly ≤ 0 や yearly ≥ 12 × monthly なら 0
    static func savingsMonths(monthly: Decimal, yearly: Decimal) -> Int {
        guard monthly > 0, yearly > 0, yearly < monthly * 12 else { return 0 }
        var value = Decimal(12) - yearly / monthly
        var floored = Decimal()
        NSDecimalRound(&floored, &value, 0, .down)
        return max(0, NSDecimalNumber(decimal: floored).intValue)
    }

    /// 「4 か月分お得」。0 なら nil
    static func savingsText(months: Int) -> String? {
        months > 0 ? "\(months) か月分お得" : nil
    }

    /// yearly / 12 を 1 円に丸める: 2400 → 200
    static func perMonth(yearly: Decimal) -> Decimal {
        var value = yearly / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return rounded
    }

    /// 設定 › 購入 の「現在のプラン」の値
    static func statusTitle(_ access: AccessState) -> String {
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
    static func dateLabel(_ access: AccessState) -> String? {
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
    static func readOnlyNote(_ reason: ReadOnlyReason) -> String {
        switch reason {
        case .notSubscribed: return "まだ購読していません。"
        case .expired: return "サブスクリプションの期限が切れています。"
        case .billingRetry: return "お支払いに問題があります。\(paymentPath)でお支払い方法を確認してください。"
        case .revoked: return "購入が返金または取り消されました。"
        case .unknown: return "購入の状態を確認できていません。回線が戻ると自動で確認します。"
        }
    }

    /// 写真モードと KitChecks の固定値（実表示は savingsText）
    static let yearlyBadge = "4 か月分お得"
    static let readOnlyBadge = "閲覧専用"
    /// 0-6。アプリ内は短い表記（規約・サポートは「（iPadOS 17 では「Apple ID」）」つき。M5-29）
    static let cancelPath = "「設定」›「Apple Account」›「サブスクリプション」"
    static let paymentPath = "「設定」›「Apple Account」›「お支払いと配送先」"
}

// MARK: - AppExport (InkModel/AppExport.swift)

enum AppExport11 {
    /// 「てがきカレンダー 手書き 2026-10-17.json」: the calendar day of `exportedAt` in `calendar`.
    static func jsonFileName(exportedAt: Date, calendar: Calendar) -> String {
        "てがきカレンダー 手書き " + DayKey(exportedAt, calendar: calendar).description + ".json"
    }

    /// 「てがきカレンダー 2026年10月 月.pdf」: `PageNavigation.title` (so a day's holiday name and a
    /// week's second year are included) and `kindLabel`, made safe with `safeFileName`.
    static func pdfFileName(kind: PageKind, focus: DayKey) -> String {
        safeFileName("てがきカレンダー " + PageNavigation11.title(kind, focus: focus) + " " + kindLabel(kind) + ".pdf")
    }

    /// 月 "月" / 週 "週" / 日 "日" / 年 "年".
    static func kindLabel(_ kind: PageKind) -> String {
        switch kind {
        case .month: return "月"
        case .week: return "週"
        case .day: return "日"
        case .year: return "年"
        }
    }

    /// "/", ":" and "\" become "-"; everything else is kept.
    static func safeFileName(_ name: String) -> String {
        String(name.map { $0 == "/" || $0 == ":" || $0 == "\\" ? "-" : $0 })
    }
}

// MARK: - MonthLayoutEngine (Layout/MonthLayoutEngine.swift)

enum MonthLayoutEngine11 {
    /// "9:00" for an event starting on the day; "〜11:00" for the tail of an overnight event ending on
    /// the day; "" when the event covers the whole day (same as the web version's chipTime).
    static func timeText(for event: LayoutEvent, dayStart: Date, dayEnd: Date, calendar: Calendar) -> String {
        if event.start >= dayStart { return formatTime(event.start, calendar: calendar) }
        if event.end < dayEnd { return "〜" + formatTime(event.end, calendar: calendar) }
        return ""
    }

    /// "9:00", "13:05" (hour without a leading zero, as the web version's formatTimeJa).
    static func formatTime(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        return "\(hour):" + (minute < 10 ? "0\(minute)" : "\(minute)")
    }
}

// MARK: - TimedEventEngine (Layout/TimedEventEngine.swift)

enum TimedEventEngine11 {
    /// "9:00" (= `MonthLayoutEngine.formatTime`, web formatTimeJa).
    static func timeText(_ date: Date, calendar: Calendar = DayKey.deviceCalendar) -> String {
        MonthLayoutEngine11.formatTime(date, calendar: calendar)
    }

    /// "9:00〜10:30" (web formatTimeRangeJa).
    static func timeRangeText(start: Date, end: Date, calendar: Calendar = DayKey.deviceCalendar) -> String {
        timeText(start, calendar: calendar) + "〜" + timeText(end, calendar: calendar)
    }
}
