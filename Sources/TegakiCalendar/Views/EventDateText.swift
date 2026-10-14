import Foundation
import Layout

/// Japanese date/time strings for the sheets and accessibility labels
/// ("2026年10月4日(日) 9:00〜10:00", "終日"). Moved unchanged from M2's EventDetailSheet.swift.
enum EventDateText {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy年M月d日(E)"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = "M月d日(E)"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = "H:mm"
        return f
    }()

    /// "2026年10月4日(日)"
    static func dayTitle(_ day: DayKey) -> String {
        dayFormatter.string(from: day.startOfDay())
    }

    /// Full description: all-day ("2026年10月4日(日) 終日", "…〜10月6日(火) 終日") or timed.
    static func when(start: Date, end: Date, allDay: Bool) -> String {
        if allDay {
            let startDay = DayKey(start)
            // `end` is the exclusive next midnight: the last day is the day before it.
            let lastDay = DayKey(end.addingTimeInterval(-1))
            if lastDay <= startDay {
                return "\(dayFormatter.string(from: start)) 終日"
            }
            return "\(dayFormatter.string(from: start))〜\(shortDayFormatter.string(from: lastDay.startOfDay())) 終日"
        }
        let startDay = DayKey(start)
        let endDay = DayKey(end)
        let startText = "\(dayFormatter.string(from: start)) \(timeFormatter.string(from: start))"
        if startDay == endDay {
            return "\(startText)〜\(timeFormatter.string(from: end))"
        }
        return "\(startText)〜\(shortDayFormatter.string(from: end)) \(timeFormatter.string(from: end))"
    }
}
