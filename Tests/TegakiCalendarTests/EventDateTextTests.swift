import Foundation
import Layout
import XCTest
@testable import TegakiCalendar

/// The event sheet's and the labels' date text (docs/M7B_CONTRACT.md §3.2, §7.2): in Japanese the same
/// characters as 1.1's three DateFormatters, kept here as the base of the comparison.
final class EventDateTextTests: XCTestCase {
    // MARK: 1.1's formatters and sentences (Views/EventDateText.swift of 1.1, unchanged)

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = DayKey.deviceCalendar
        f.timeZone = TimeZone.current
        f.dateFormat = format
        return f
    }
    private let dayFormatter = EventDateTextTests.formatter("yyyy年M月d日(E)")
    private let shortDayFormatter = EventDateTextTests.formatter("M月d日(E)")
    private let timeFormatter = EventDateTextTests.formatter("H:mm")

    private func oneOneWhen(start: Date, end: Date, allDay: Bool) -> String {
        if allDay {
            let startDay = DayKey(start)
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

    private func date(_ day: DayKey, hour: Int, minute: Int) -> Date {
        day.startOfDay().addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    // MARK: Tests

    /// Every date of 2026 × 6 times of day, the four shapes of `when` and the day title.
    func testJapaneseEventTextIsUnchanged() {
        let times = [(0, 0), (0, 5), (9, 0), (9, 7), (12, 30), (23, 59)]
        var day = DayKey(year: 2026, month: 1, day: 1)
        var compared = 0
        while day.year == 2026 {
            XCTAssertEqual(EventDateText.dayTitle(day), dayFormatter.string(from: day.startOfDay()))
            XCTAssertEqual(EventDateText.dayTitle(day, language: .ja), dayFormatter.string(from: day.startOfDay()))
            for (hour, minute) in times {
                let start = date(day, hour: hour, minute: minute)
                let sameDay = date(day, hour: min(hour + 1, 23), minute: 59)
                let nextDay = date(day.adding(days: 1), hour: 8, minute: 30)
                for end in [sameDay, nextDay] {
                    XCTAssertEqual(EventDateText.when(start: start, end: end, allDay: false), oneOneWhen(start: start, end: end, allDay: false))
                    compared += 1
                }
            }
            let midnight = day.startOfDay()
            let oneDay = day.adding(days: 1).startOfDay()
            let threeDays = day.adding(days: 3).startOfDay()
            XCTAssertEqual(EventDateText.when(start: midnight, end: oneDay, allDay: true), oneOneWhen(start: midnight, end: oneDay, allDay: true))
            XCTAssertEqual(EventDateText.when(start: midnight, end: threeDays, allDay: true), oneOneWhen(start: midnight, end: threeDays, allDay: true))
            compared += 2
            day = day.adding(days: 1)
        }
        XCTAssertEqual(compared, 365 * 14)
        // The sentences themselves, as a reader sees them.
        let sunday = DayKey(year: 2026, month: 10, day: 4)
        XCTAssertEqual(EventDateText.dayTitle(sunday), "2026年10月4日(日)")
        XCTAssertEqual(EventDateText.when(start: date(sunday, hour: 9, minute: 0), end: date(sunday, hour: 10, minute: 0), allDay: false),
                       "2026年10月4日(日) 9:00〜10:00")
        XCTAssertEqual(EventDateText.when(start: sunday.startOfDay(), end: sunday.adding(days: 3).startOfDay(), allDay: true),
                       "2026年10月4日(日)〜10月6日(火) 終日")
    }

    /// The other languages' text is built from the same pieces: DateText's dates, the range's "–".
    func testEnglishEventText() {
        let sunday = DayKey(year: 2026, month: 10, day: 4)
        let title = DateText.dayTitle(sunday, .en)
        XCTAssertEqual(EventDateText.dayTitle(sunday, language: .en), title)
        XCTAssertFalse(title.contains("年"), title)
        let allDayWord = L.text("event.allDay", in: .en)
        XCTAssertEqual(EventDateText.when(start: sunday.startOfDay(), end: sunday.adding(days: 1).startOfDay(), allDay: true, language: .en),
                       title + " " + allDayWord)
        XCTAssertEqual(EventDateText.when(start: sunday.startOfDay(), end: sunday.adding(days: 3).startOfDay(), allDay: true, language: .en),
                       title + "–" + DateText.shortDay(DayKey(year: 2026, month: 10, day: 6), .en) + " " + allDayWord)
        XCTAssertEqual(EventDateText.when(start: date(sunday, hour: 9, minute: 5), end: date(sunday, hour: 10, minute: 30), allDay: false, language: .en),
                       title + " 9:05–10:30")
        XCTAssertEqual(EventDateText.when(start: date(sunday, hour: 22, minute: 0), end: date(sunday.adding(days: 1), hour: 1, minute: 0), allDay: false, language: .en),
                       title + " 22:00–" + DateText.shortDay(sunday.adding(days: 1), .en) + " 1:00")
    }
}
