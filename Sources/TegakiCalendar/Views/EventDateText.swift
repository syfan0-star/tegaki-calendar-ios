import Foundation
import Layout

/// Date and time strings for the sheets and accessibility labels ("2026年10月4日(日) 9:00〜10:00",
/// "2026年10月4日(日) 終日"; en_US "Sun, October 4, 2026 9:00–10:00"). The dates are `DateText`'s, the
/// range's separator is `LayoutWords`' (docs/M7B_CONTRACT.md §3.2). In Japanese that is the same
/// text as 1.1's three DateFormatters (`EventDateTextTests`). `language` is for the tests; the app
/// uses the default.
enum EventDateText {
    /// "2026年10月4日(日)"
    static func dayTitle(_ day: DayKey, language: UILanguage = L.language) -> String {
        DateText.dayTitle(day, language)
    }

    /// Full description: all-day ("2026年10月4日(日) 終日", "…〜10月6日(火) 終日") or timed.
    static func when(start: Date, end: Date, allDay: Bool, language: UILanguage = L.language) -> String {
        let words = LayoutWords.of(language)
        let startDay = DayKey(start)
        if allDay {
            let allDayWord = language == L.language ? L.text("event.allDay") : L.text("event.allDay", in: language)
            // `end` is the exclusive next midnight: the last day is the day before it.
            let lastDay = DayKey(end.addingTimeInterval(-1))
            if lastDay <= startDay {
                return DateText.dayTitle(startDay, language) + " " + allDayWord
            }
            return words.range(DateText.dayTitle(startDay, language), DateText.shortDay(lastDay, language)) + " " + allDayWord
        }
        func dateTime(_ date: String, _ time: String) -> String {
            language == L.language
                ? L.format("event.when.dateTime", date, time)
                : KitStrings.fill(L.text("event.when.dateTime", in: language), [date, time])
        }
        let endDay = DayKey(end)
        let startText = dateTime(DateText.dayTitle(startDay, language), timeText(start))
        if startDay == endDay {
            return words.range(startText, timeText(end))
        }
        return words.range(startText, dateTime(DateText.shortDay(endDay, language), timeText(end)))
    }

    /// "9:05" on the device calendar (every language, D7).
    private static func timeText(_ date: Date) -> String {
        let parts = DayKey.deviceCalendar.dateComponents([.hour, .minute], from: date)
        return DateText.time(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
