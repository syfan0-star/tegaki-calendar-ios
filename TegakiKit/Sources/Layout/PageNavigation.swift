import Foundation
import CoreGraphics
import Holidays

/// Page ids, visible day ranges, ◀ ▶ moves, header titles and the initial scroll position of the
/// four pages (M3A_CONTRACT §1.9; the web version's page-geometry.js pageIdFor / rangeFor / navigate).
public enum PageNavigation {
    /// 日 月 火 水 木 金 土, indexed by `DayKey.weekday` (0 = Sunday).
    public static let weekdayLetters = ["日", "月", "火", "水", "木", "金", "土"]

    /// "d-2026-10-04" / "w-2026-09-28" (the Monday of the week containing `focus`) / "m1-2026-10" /
    /// "y-2026". Same strings as the web version's pageIdFor (Monday start).
    public static func pageId(_ kind: PageKind, focus: DayKey) -> String {
        switch kind {
        case .day:
            return "d-" + focus.description
        case .week:
            return "w-" + mondayOnOrBefore(focus).description
        case .month:
            return YearMonth(year: focus.year, month: focus.month).inkPageId
        case .year:
            return String(format: "y-%04d", focus.year)
        }
    }

    /// The Monday on or before `day` (= `MonthLayout.mondayOnOrBefore`).
    public static func mondayOnOrBefore(_ day: DayKey) -> DayKey {
        MonthLayout.mondayOnOrBefore(day)
    }

    /// The days shown on the page (`end` exclusive): day → 1 day; week → 7 days from the Monday;
    /// month → the 42 days of the grid; year → Jan 1 to the next Jan 1.
    public static func dayRange(_ kind: PageKind, focus: DayKey) -> (start: DayKey, end: DayKey) {
        switch kind {
        case .day:
            return (focus, focus.adding(days: 1))
        case .week:
            let monday = mondayOnOrBefore(focus)
            return (monday, monday.adding(days: 7))
        case .month:
            let first = MonthLayout.firstGridDay(year: focus.year, month: focus.month)
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

    /// The header title (DESIGN §2.7): day 「2026年10月4日(日) 体育の日」 (the holiday name after a
    /// space, only when there is one); week 「2026年9月28日〜10月4日」 (the year on both sides when
    /// the week crosses a year, the month always on both sides); month 「2026年10月」; year 「2026年」.
    public static func title(_ kind: PageKind, focus: DayKey) -> String {
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

    /// Paper y to scroll to when a page is first shown (the caller multiplies by the zoom scale
    /// and clamps): week / day → an hour before now when today is on the page, else 7:00;
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
}
