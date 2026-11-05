import Foundation
import CoreGraphics
import Holidays

/// Page ids, visible day ranges, ◀ ▶ moves, header titles and the initial scroll position of the
/// four pages (M3A_CONTRACT §1.9; the web version's page-geometry.js pageIdFor / rangeFor / navigate).
public enum PageNavigation {
    /// 日 月 火 水 木 金 土, indexed by `DayKey.weekday` (0 = Sunday).
    public static let weekdayLetters = ["日", "月", "火", "水", "木", "金", "土"]

    /// "d-2026-10-04" / "w-2026-09-28" (the first day of the week containing `focus`: a Monday or a
    /// Sunday, K-11) / "m1-2026-10" / "y-2026". With `.monday` the same strings as the web version's
    /// pageIdFor.
    public static func pageId(_ kind: PageKind, focus: DayKey, weekStart: WeekStart = .monday) -> String {
        switch kind {
        case .day:
            return "d-" + focus.description
        case .week:
            return "w-" + weekStart.firstDay(of: focus).description
        case .month:
            return YearMonth(year: focus.year, month: focus.month).inkPageId
        case .year:
            return String(format: "y-%04d", focus.year)
        }
    }

    /// The page a page id names (1.1, M7A_CONTRACT §5.3; the inverse of `pageId(_:focus:)`):
    /// "d-YYYY-MM-DD" → (.day, that day), "w-YYYY-MM-DD" → (.week, that day), "m1-YYYY-MM" →
    /// (.month, the 1st), "y-YYYY" → (.year, January 1). Only the exact forms `pageId` writes (4-digit
    /// year, 2-digit month and day, a date that exists); anything else ("wb-…", an invalid date, another
    /// spelling) → nil. The date of a week page is read as it is: a Sunday id stays that Sunday.
    public static func parse(pageId: String) -> (kind: PageKind, focus: DayKey)? {
        if pageId.hasPrefix("d-"), let d = exactDay(pageId.dropFirst(2)) {
            return (.day, d)
        }
        if pageId.hasPrefix("w-"), let d = exactDay(pageId.dropFirst(2)) {
            return (.week, d)
        }
        if pageId.hasPrefix("m1-") {
            let rest = String(pageId.dropFirst(3))
            let parts = rest.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
                  parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
                  let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
            let first = DayKey(year: y, month: m, day: 1)
            guard first.isValid, YearMonth(year: y, month: m).inkPageId == pageId else { return nil }
            return (.month, first)
        }
        if pageId.hasPrefix("y-") {
            let rest = pageId.dropFirst(2)
            guard rest.count == 4, rest.allSatisfy({ $0.isASCII && $0.isNumber }), let y = Int(rest) else { return nil }
            let first = DayKey(year: y, month: 1, day: 1)
            guard String(format: "y-%04d", y) == pageId else { return nil }
            return (.year, first)
        }
        return nil
    }

    /// "YYYY-MM-DD" exactly as `DayKey.description` writes it, of a date that exists.
    private static func exactDay(_ text: Substring) -> DayKey? {
        guard text.count == 10, text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "-") }),
              let d = DayKey(ymd: String(text)), d.description == text else { return nil }
        return d
    }

    /// The Monday on or before `day` (= `MonthLayout.mondayOnOrBefore`).
    public static func mondayOnOrBefore(_ day: DayKey) -> DayKey {
        MonthLayout.mondayOnOrBefore(day)
    }

    /// The days shown on the page (`end` exclusive): day → 1 day; week → 7 days from its first day;
    /// month → the 42 days of the grid; year → Jan 1 to the next Jan 1.
    public static func dayRange(_ kind: PageKind, focus: DayKey, weekStart: WeekStart = .monday) -> (start: DayKey, end: DayKey) {
        switch kind {
        case .day:
            return (focus, focus.adding(days: 1))
        case .week:
            let first = weekStart.firstDay(of: focus)
            return (first, first.adding(days: 7))
        case .month:
            let first = MonthLayout.firstGridDay(year: focus.year, month: focus.month, weekStart: weekStart)
            return (first, first.adding(days: MonthLayout.gridDayCount))
        case .year:
            return (DayKey(year: focus.year, month: 1, day: 1), DayKey(year: focus.year + 1, month: 1, day: 1))
        }
    }

    /// The focus `delta` pages away (web navigate): day ±1 day; week ±7 days (same weekday);
    /// month ±1 month (the 1st); year ±1 year (Jan 1). A delta of 0 normalizes the month / year focus.
    public static func move(_ kind: PageKind, focus: DayKey, by delta: Int) -> DayKey {
        switch kind {
        case .day:
            return focus.adding(days: delta)
        case .week:
            return focus.adding(days: 7 * delta)
        case .month:
            let total = focus.year * 12 + (focus.month - 1) + delta
            let year = total >= 0 ? total / 12 : (total - 11) / 12
            return DayKey(year: year, month: total - year * 12 + 1, day: 1)
        case .year:
            return DayKey(year: focus.year + delta, month: 1, day: 1)
        }
    }

    /// The header title (DESIGN §2.7, §3.2 of the 1.2 contract; `DateText`): day 「2026年10月4日(日)
    /// 体育の日」 (the holiday name of `holidays` after a space, only when there is one); week
    /// 「2026年9月28日〜10月4日」 (from `weekStart`'s first day; the year on both sides when the week
    /// crosses a year, the month always on both sides); month 「2026年10月」; year 「2026年」. The
    /// defaults give 1.1's text (J-3).
    public static func title(_ kind: PageKind, focus: DayKey, holidays: HolidayCalendar = .japan, language: UILanguage = .ja, weekStart: WeekStart = .monday) -> String {
        switch kind {
        case .day:
            var text = DateText.dayTitle(focus, language)
            if let holiday = holidays.name(of: focus) { text += " " + holiday }
            return text
        case .week:
            return DateText.weekTitle(first: weekStart.firstDay(of: focus), language, compact: false)
        case .month:
            return DateText.monthTitle(YearMonth(year: focus.year, month: focus.month), language)
        case .year:
            return DateText.yearTitle(focus.year, language)
        }
    }

    /// The short title of the compact header (an iPhone in portrait, M4B_CONTRACT §5; `title` is
    /// unchanged): day 「10月7日(水)」 (no holiday name: the paper's date heading shows it); week
    /// 「10/5〜10/11」 (month/day on both sides, never the year: 「9/28〜10/4」, 「12/28〜1/3」);
    /// month 「2026年10月」; year 「2026年」. The defaults give 1.1's text (J-3).
    public static func compactTitle(_ kind: PageKind, focus: DayKey, language: UILanguage = .ja, weekStart: WeekStart = .monday) -> String {
        switch kind {
        case .day:
            return DateText.shortDay(focus, language)
        case .week:
            return DateText.weekTitle(first: weekStart.firstDay(of: focus), language, compact: true)
        case .month:
            return DateText.monthTitle(YearMonth(year: focus.year, month: focus.month), language, compact: true)
        case .year:
            return DateText.yearTitle(focus.year, language)
        }
    }

    /// Paper x to scroll to when a page is first shown (lu; the caller multiplies by the zoom scale
    /// and clamps, M4B_CONTRACT §1.2). `visibleWidth` = `ZoomPolicy.visibleWidth` (lu).
    /// Month: the smallest x that shows all of today's column c (= index % 7), `max(0, 200c + 200 −
    /// visibleWidth)`; 0 when today is not on the grid. Week: the same for today's column,
    /// `max(0, 64 + (c + 1) × colW − visibleWidth)`; 0 without today. Year: the left edge of this
    /// month's column, `56 + (m − 1) × 112`, 0 when today is not in that year. Day: 0.
    /// The result is kept inside the paper (`min(x, paperWidth − visibleWidth)`, then `max(0, …)`);
    /// 0 when `visibleWidth` is not finite or not positive.
    public static func initialScrollX(_ layout: any PageLayout, now: Date, calendar: Calendar = DayKey.deviceCalendar, visibleWidth: CGFloat) -> CGFloat {
        guard visibleWidth.isFinite, visibleWidth > 0 else { return 0 }
        let today = DayKey(now, calendar: calendar)
        var x: CGFloat = 0
        if let month = layout as? MonthPageLayout {
            if let cell = month.cells[.day(today)] { x = max(0, cell.maxX - visibleWidth) }
        } else if let week = layout as? WeekPageLayout {
            if let col = week.days.firstIndex(of: today) { x = max(0, week.columnFrame(col).maxX - visibleWidth) }
        } else if let year = layout as? YearPageLayout {
            if today.year == year.year { x = year.columnFrame(month: today.month).minX }
        }
        x = min(x, layout.size.width - visibleWidth)
        return max(0, x)
    }

    /// Paper y to scroll to when a page is first shown (the caller multiplies by the zoom scale
    /// and clamps): week / day → an hour before now when today is on the page, else 7:00 (since M4b
    /// the grid starts at the paper's top, so 10:00 today is 720 / 900, not today 560 / 700);
    /// year → the row two above today's when today is in that year, else 0; month → 0.
    public static func initialScrollY(_ layout: any PageLayout, now: Date, calendar: Calendar = DayKey.deviceCalendar) -> CGFloat {
        let today = DayKey(now, calendar: calendar)
        if let week = layout as? WeekPageLayout {
            return week.minutesToY(startMinutes(todayVisible: week.days.contains(today), now: now, calendar: calendar))
        }
        if let day = layout as? DayPageLayout {
            return day.minutesToY(startMinutes(todayVisible: day.day == today, now: now, calendar: calendar))
        }
        if let year = layout as? YearPageLayout {
            guard today.year == year.year else { return 0 }
            let index = max(0, today.day - 3)
            return index < year.rows.count ? year.rows[index].frame.minY : 0
        }
        return 0
    }

    private static func startMinutes(todayVisible: Bool, now: Date, calendar: Calendar) -> Int {
        guard todayVisible else { return 7 * 60 }
        let minute = TimedEventEngine.minutesOfDay(now, calendar: calendar) - 60
        return min(max(minute, 0), TimedEventEngine.dayMinutes)
    }

    /// 1.1.1 (docs/R1_1_1.md): the paper rect 「今日」 brings on screen: today's cell on the month and year
    /// pages; nil when today is not on the page, and on the week and day pages.
    public static func todayRect(_ layout: any PageLayout, now: Date, calendar: Calendar = DayKey.deviceCalendar) -> CGRect? {
        let today = DayKey(now, calendar: calendar)
        if let month = layout as? MonthPageLayout { return month.cells[.day(today)] }
        if let year = layout as? YearPageLayout, today.year == year.year {
            return year.cells[.yearDay(month: today.month, day: today.day)]
        }
        return nil
    }
}
