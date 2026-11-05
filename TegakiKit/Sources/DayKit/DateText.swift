import Foundation

/// How a weekday is named (§3.3).
public enum WeekdayStyle: Sendable {
    /// The signs the contract fixed for each language (`kit.weekday.letter.*`): 日 月 …, Su Mo …,
    /// So Mo …, dom seg … Never one Latin letter (S M T W … cannot be told apart).
    case letter
    /// The short standalone names of the language (Sun, So, dim., 周日 …); ja: the sign (日).
    case short
    /// The standalone names (Sunday, Sonntag, 星期日 …); ja: 「日曜日」.
    case full
}

/// How a month is named (F-8, F-10).
public enum MonthNameStyle: Sendable {
    /// The short standalone names (Oct, Okt, oct., 10月 …); ja: 「10月」.
    case short
    /// The standalone names (October, Oktober, 10月 …); zh-Hans uses the short name (its wide name
    /// is 「十月」); ja: 「10月」.
    case full
}

/// The dates, weekdays, months, numbers and times the app shows, in each language (1.2,
/// docs/M7B_CONTRACT.md §3; D6, D7, 0-9, 0-11, 0-33).
///
/// - ja is the hand-made text of 1.1 (D6): the patterns are the ja-only keys `kit.date.ja.*` of
///   `KitStrings` filled with the numbers and the sign of the weekday (`kit.weekday.letter.*`), never
///   an ICU pattern, so the Japanese screen shows exactly what 1.1 showed (KitChecks J-3 compares
///   every date from 2000 to 2099 with the copy of 1.1 in KitChecks/Text11.swift). The exceptions are
///   `numericDate` and `numericDateTime`, which were ICU's in 1.1 and stay ICU's (0-33).
/// - The other languages use the localized templates of `DateFormatter` / `DateIntervalFormatter`
///   (§3.1 rule 3) with the language and the device's region (`UILanguage.locale(region:)`).
/// - The calendar is always Gregorian (0-11): a device set to the Japanese or the Buddhist calendar,
///   or a region whose default calendar is another (en_TH is Buddhist), still shows 2026. The
///   formatting locale carries `calendar=gregorian` too, so the patterns have no era (no "AD").
/// - The order of the weekdays comes from the caller's `WeekStart` (§10.1: `WeekStart.order`, and
///   `mondayFirst` is its Monday value); nothing here reads `Calendar.firstWeekday` or the region's
///   first day of the week (D6, §3.1 rule 5).
///
/// A `DayKey` is formatted as noon UTC of that day in a Gregorian calendar in UTC, so the text does
/// not depend on the device's time zone. Formatters are made once per pattern and locale.
public enum DateText {
    /// The weekdays of a Monday-start week, as `DayKey.weekday` (0 = Sunday): [1, 2, 3, 4, 5, 6, 0].
    /// The same value as `WeekStart.monday.order` (kept for the callers of 1.2's first part).
    public static let mondayFirst: [Int] = [1, 2, 3, 4, 5, 6, 0]

    /// The calendar for formatting: Gregorian (whatever the device's calendar), with
    /// `language.locale(region:)` and `timeZone`. Its `firstWeekday` is not used (§3.1 rule 5).
    public static func calendar(_ language: UILanguage, region: String? = Locale.current.region?.identifier, timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = language.locale(region: region)
        calendar.timeZone = timeZone
        return calendar
    }

    // MARK: - Weekdays and months

    /// The 7 names of the weekdays in `DayKey.weekday` order (index 0 = Sunday; reorder with
    /// `WeekStart.order` for a row of a week). `.letter`: the fixed signs of §3.3; `.short` and `.full`:
    /// the standalone names of the language (ja: the sign and 「日曜日」…, by hand).
    public static func weekdays(_ style: WeekdayStyle, _ language: UILanguage) -> [String] {
        switch style {
        case .letter:
            return letters(language)
        case .short:
            if language == .ja { return letters(.ja) }
            let names = Formatters.shared.symbols(formattingLocale(language, region: nil)).shortStandaloneWeekdaySymbols ?? []
            return names.count == 7 ? names : letters(language)
        case .full:
            if language == .ja {
                return letters(.ja).map { KitStrings.format("kit.date.ja.weekdayFull", .ja, [$0]) }
            }
            let names = Formatters.shared.symbols(formattingLocale(language, region: nil)).standaloneWeekdaySymbols ?? []
            return names.count == 7 ? names : letters(language)
        }
    }

    /// The name of month 1…12: ja 「10月」 (both styles, 1.1's 「\(m)月」, any number); the other
    /// languages the standalone names (`.full` of zh-Hans is the short name 「10月」, not 「十月」);
    /// a month outside 1…12 gives the number.
    public static func monthName(_ month: Int, _ style: MonthNameStyle, _ language: UILanguage) -> String {
        if language == .ja {
            return KitStrings.format("kit.date.ja.monthName", .ja, [String(month)])
        }
        guard (1...12).contains(month) else { return String(month) }
        let formatter = Formatters.shared.symbols(formattingLocale(language, region: nil))
        let names: [String]
        switch style {
        case .short:
            names = formatter.shortStandaloneMonthSymbols ?? []
        case .full:
            names = (language == .zhHans ? formatter.shortStandaloneMonthSymbols : formatter.standaloneMonthSymbols) ?? []
        }
        return names.count == 12 ? names[month - 1] : String(month)
    }

    // MARK: - Titles

    /// The day page's date: ja 「2026年10月4日(日)」; others `yMMMMEd` (en_US "Sun, October 4, 2026").
    /// The holiday name is not part of it (the caller adds it).
    public static func dayTitle(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String {
        if language == .ja {
            return KitStrings.format("kit.date.ja.dayTitle", .ja,
                                     [String(day.year), String(day.month), String(day.day), letter(day.weekday, .ja)])
        }
        return formatted(day, template: "yMMMMEd", language, region: region)
    }

    /// A date without the weekday, for a label that only names a day (`StrokeBudget.pageLabel`):
    /// ja 「2026年10月7日」; others `yMMMMd` (en_US "October 7, 2026").
    public static func plainDay(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String {
        if language == .ja {
            return KitStrings.format("kit.date.ja.plainDay", .ja, [String(day.year), String(day.month), String(day.day)])
        }
        return formatted(day, template: "yMMMMd", language, region: region)
    }

    /// A short date: ja 「10月7日(水)」; others `MMMEd` (en_US "Wed, Oct 7").
    public static func shortDay(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String {
        if language == .ja {
            return KitStrings.format("kit.date.ja.shortDay", .ja,
                                     [String(day.month), String(day.day), letter(day.weekday, .ja)])
        }
        return formatted(day, template: "MMMEd", language, region: region)
    }

    /// The month page's title: ja 「2026年10月」 (compact too); others `yMMMM` ("October 2026",
    /// es "septiembre de 2026"), compact `yMMM` ("Oct 2026").
    public static func monthTitle(_ month: YearMonth, _ language: UILanguage, compact: Bool = false, region: String? = Locale.current.region?.identifier) -> String {
        if language == .ja {
            return KitStrings.format("kit.date.ja.monthTitle", .ja, [String(month.year), String(month.month)])
        }
        return formatted(month.firstDay, template: compact ? "yMMM" : "yMMMM", language, region: region)
    }

    /// The year page's title: ja 「2026年」; others the number with no grouping ("2026", also in
    /// the regions of other calendars).
    public static func yearTitle(_ year: Int, _ language: UILanguage) -> String {
        if language == .ja {
            return KitStrings.format("kit.date.ja.yearTitle", .ja, [String(year)])
        }
        return String(year)
    }

    /// The week from `first` to the day 6 days later (the caller passes the first day of the week,
    /// `WeekStart.firstDay(of:)`: a Monday or a Sunday). ja: 「2026年9月28日〜10月4日」, the year on both
    /// sides when the week crosses a year (「2026年12月28日〜2027年1月3日」), compact 「9/28〜10/4」
    /// (never the year); others the interval of `yMMMd` ("Sep 28 – Oct 4, 2026"), compact `Md`
    /// ("9/28 – 10/4", fr "28/09 – 04/10"; ICU adds the years when the week crosses one).
    public static func weekTitle(first: DayKey, _ language: UILanguage, compact: Bool, region: String? = Locale.current.region?.identifier) -> String {
        let last = first.adding(days: 6)
        if language == .ja {
            if compact {
                return KitStrings.format("kit.date.ja.weekTitleCompact", .ja,
                                         [String(first.month), String(first.day), String(last.month), String(last.day)])
            }
            if last.year == first.year {
                return KitStrings.format("kit.date.ja.weekTitle", .ja,
                                         [String(first.year), String(first.month), String(first.day),
                                          String(last.month), String(last.day)])
            }
            return KitStrings.format("kit.date.ja.weekTitleCrossYear", .ja,
                                     [String(first.year), String(first.month), String(first.day),
                                      String(last.year), String(last.month), String(last.day)])
        }
        let formatter = Formatters.shared.interval(template: compact ? "Md" : "yMMMd", formattingLocale(language, region: region))
        return formatter.string(from: noon(first), to: noon(last))
    }

    /// The date as it is read out (VoiceOver): ja = `dayTitle` (1.1's spoken text); others
    /// `yMMMMEEEEd` (en_US "Sunday, October 4, 2026").
    public static func spokenDay(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String {
        if language == .ja {
            return dayTitle(day, .ja, region: region)
        }
        return formatted(day, template: "yMMMMEEEEd", language, region: region)
    }

    // MARK: - Settings (0-33)

    /// The numeric date of 設定 › 購入 (no time): `Date.FormatStyle(date: .numeric, time: .omitted)`
    /// with a Gregorian calendar. ja keeps 1.1's ICU text (0-33): the device's locale when its
    /// language is Japanese (its own preferences apply, as in 1.1), otherwise ja_<region>; the other
    /// languages `language.locale(region:)`. ja_JP 「2026/10/25」, en_US "10/25/2026".
    public static func numericDate(_ date: Date, _ language: UILanguage, region: String? = Locale.current.region?.identifier, timeZone: TimeZone = .current) -> String {
        numeric(date, time: .omitted, language, region: region, timeZone: timeZone)
    }

    /// The numeric date and time of 「最後に同期」 and 「前回の取り込み」: as `numericDate` with
    /// `time: .shortened`. ja_JP 「2026/10/25 12:00」, en_US "10/25/2026, 12:00 PM".
    public static func numericDateTime(_ date: Date, _ language: UILanguage, region: String? = Locale.current.region?.identifier, timeZone: TimeZone = .current) -> String {
        numeric(date, time: .shortened, language, region: region, timeZone: timeZone)
    }

    // MARK: - Times and numbers

    /// "9:05", "13:00": the hour without a leading zero and two digits of minutes, in every language
    /// (D7; the same text as 1.1's `MonthLayoutEngine.formatTime`).
    public static func time(hour: Int, minute: Int) -> String {
        "\(hour):" + (minute < 10 ? "0\(minute)" : "\(minute)")
    }

    /// A whole number: ja grouped by three digits with a half-width comma whatever the region
    /// (1.1's 「12,345」, `StrokeBudget.countText`); others the decimal style of
    /// `language.locale(region:)` (de 12.345, fr 12 345, en 12,345).
    public static func number(_ n: Int, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String {
        if language == .ja {
            let digits = String(n.magnitude)
            var grouped = ""
            for (i, ch) in digits.enumerated() {
                if i > 0 && (digits.count - i) % 3 == 0 { grouped.append(",") }
                grouped.append(ch)
            }
            return (n < 0 ? "-" : "") + grouped
        }
        return Formatters.shared.number(language.locale(region: region)).string(from: NSNumber(value: n)) ?? String(n)
    }

    // MARK: - Private

    /// The sign of weekday 0…6 (`DayKey.weekday`).
    private static func letter(_ weekday: Int, _ language: UILanguage) -> String {
        // l10n-dynamic: kit.weekday.letter.
        KitStrings.text("kit.weekday.letter." + String(weekday), language)
    }

    private static func letters(_ language: UILanguage) -> [String] {
        (0..<7).map { letter($0, language) }
    }

    /// `language.locale(region:)` with the Gregorian calendar as its calendar, so the patterns made
    /// from a template are the Gregorian ones (no era) even where the region's calendar is another.
    private static func formattingLocale(_ language: UILanguage, region: String?) -> Locale {
        var components = Locale.Components(locale: language.locale(region: region))
        components.calendar = .gregorian
        return Locale(components: components)
    }

    /// Noon UTC of `day` in a Gregorian calendar in UTC (the calendar of the formatters).
    private static func noon(_ day: DayKey) -> Date {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = 12
        return Formatters.gregorianUTC.date(from: components)
            ?? Date(timeIntervalSince1970: Double(day.dayNumber) * 86_400 + 43_200)
    }

    private static func formatted(_ day: DayKey, template: String, _ language: UILanguage, region: String?) -> String {
        Formatters.shared.date(template: template, formattingLocale(language, region: region)).string(from: noon(day))
    }

    private static func numeric(_ date: Date, time: Date.FormatStyle.TimeStyle, _ language: UILanguage, region: String?, timeZone: TimeZone) -> String {
        let locale: Locale
        if language == .ja, Locale.current.language.languageCode == .japanese {
            locale = Locale.current
        } else {
            locale = language.locale(region: region)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        return date.formatted(Date.FormatStyle(date: .numeric, time: time, locale: locale, calendar: calendar, timeZone: timeZone))
    }
}

/// The formatters of `DateText`, made once per pattern and locale (making one costs far more than
/// using it). A configured formatter is safe to use from several threads; the lock guards the tables.
private final class Formatters: @unchecked Sendable {
    static let shared = Formatters()

    /// The calendar every `DayKey` is formatted in: Gregorian, UTC.
    static let gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private let lock = NSLock()
    private var dates: [String: DateFormatter] = [:]
    private var intervals: [String: DateIntervalFormatter] = [:]
    private var numbers: [String: NumberFormatter] = [:]
    private var symbolTables: [String: DateFormatter] = [:]

    private static func calendar(_ locale: Locale) -> Calendar {
        var calendar = gregorianUTC
        calendar.locale = locale
        return calendar
    }

    /// A date formatter from a localized template (UTC, Gregorian).
    func date(template: String, _ locale: Locale) -> DateFormatter {
        let key = template + "|" + locale.identifier
        lock.lock()
        defer { lock.unlock() }
        if let formatter = dates[key] { return formatter }
        let formatter = DateFormatter()
        formatter.locale = locale  // first: setting the locale resets the calendar
        formatter.calendar = Self.calendar(locale)
        formatter.timeZone = .gmt
        formatter.setLocalizedDateFormatFromTemplate(template)
        dates[key] = formatter
        return formatter
    }

    /// An interval formatter from a template (UTC, Gregorian).
    func interval(template: String, _ locale: Locale) -> DateIntervalFormatter {
        let key = template + "|" + locale.identifier
        lock.lock()
        defer { lock.unlock() }
        if let formatter = intervals[key] { return formatter }
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = Self.calendar(locale)
        formatter.timeZone = .gmt
        formatter.dateTemplate = template
        intervals[key] = formatter
        return formatter
    }

    /// A decimal number formatter.
    func number(_ locale: Locale) -> NumberFormatter {
        let key = locale.identifier
        lock.lock()
        defer { lock.unlock() }
        if let formatter = numbers[key] { return formatter }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        numbers[key] = formatter
        return formatter
    }

    /// A formatter whose weekday and month symbols are read (Gregorian).
    func symbols(_ locale: Locale) -> DateFormatter {
        let key = locale.identifier
        lock.lock()
        defer { lock.unlock() }
        if let formatter = symbolTables[key] { return formatter }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Self.calendar(locale)
        formatter.timeZone = .gmt
        symbolTables[key] = formatter
        return formatter
    }
}

extension YearMonth {
    /// The month's title in `language`: `DateText.monthTitle(self, language)` (ja 「2026年10月」, the
    /// same as `title`; en "October 2026"). `title` stays as the ja value of 1.1.
    public func title(language: UILanguage) -> String {
        DateText.monthTitle(self, language)
    }
}
