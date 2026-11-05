import CoreGraphics
import Foundation
import Holidays
import Layout
import XCTest

/// Holidays and words never move the paper, and the colour and the name of a day come from the
/// calendar passed (docs/M7B_CONTRACT.md D9, §5.4, §7.1, §7.2). KitChecks does the same over all the
/// pages of 2026 (G-1 to G-4); here are the samples. In this target because they read the data.
final class HolidayGeometryTests: XCTestCase {
    /// Every day of 2000–2099 is called `name` when it is given; every weekend day is a working day.
    private struct MadeUp: HolidaySource {
        let name: String?

        func entries(forYear year: Int) -> [DayKey: [HolidayEntry]] {
            guard let name, (2000...2099).contains(year) else { return [:] }
            var out: [DayKey: [HolidayEntry]] = [:]
            for m in 1...12 {
                for d in 1...DayKey.daysInMonth(year: year, month: m) {
                    out[DayKey(year: year, month: m, day: d)] = [HolidayEntry(full: name, short: name)]
                }
            }
            return out
        }

        func workdays(forYear year: Int) -> Set<DayKey> {
            var out: Set<DayKey> = []
            for m in 1...12 {
                for d in 1...DayKey.daysInMonth(year: year, month: m) {
                    let key = DayKey(year: year, month: m, day: d)
                    if key.weekday == 0 || key.weekday == 6 { out.insert(key) }
                }
            }
            return out
        }

        func note(forYear year: Int) -> HolidayYearNote? { nil }
    }

    private let store = HolidayStore(directory: holidayDataDirectory())
    private let x = HolidayCalendar(id: "X|ja", region: nil, source: MadeUp(name: "X"))
    private let w = HolidayCalendar(id: "W|ja", region: nil, source: MadeUp(name: nil))
    private let long = HolidayCalendar(id: "long|ja", region: nil, source: MadeUp(name: String(repeating: "L", count: 40)))

    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        tokyo.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }

    private func calendar(_ code: String, _ language: UILanguage) throws -> HolidayCalendar {
        store.calendar(for: try XCTUnwrap(HolidayRegion(code: code)), language: language)
    }

    private var now: Date { date(2026, 11, 26, 10) }

    private var events: [LayoutEvent] {
        var out: [LayoutEvent] = []
        func add(_ allDay: Bool, _ start: Date, _ end: Date) {
            out.append(LayoutEvent(id: "e\(out.count)", title: "e\(out.count)", allDay: allDay, start: start, end: end, colorHex: "#2563eb", calendarId: "c"))
        }
        add(true, date(2026, 11, 5), date(2026, 11, 15))
        add(true, date(2026, 11, 14), date(2026, 11, 15))
        for h in 8..<14 { add(false, date(2026, 11, 9, h), date(2026, 11, 9, h, 45)) }
        add(false, date(2026, 11, 20, 22), date(2026, 11, 21, 8))
        add(false, date(2026, 11, 26, 9), date(2026, 11, 26, 17, 30))
        return out
    }

    private func month(_ h: HolidayCalendar = .japan, words: LayoutWords = .japanese, calendar: Calendar? = nil, year: Int = 2026, month: Int = 11) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: year, month: month), events: events, inkBottoms: [.memo: 800], now: now, calendar: calendar ?? tokyo, holidays: h, words: words))
    }

    private func week(_ h: HolidayCalendar = .japan, words: LayoutWords = .japanese, calendar: Calendar? = nil, focus: DayKey? = nil) -> WeekPageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(focus: focus ?? day(2026, 11, 26), events: events, inkBottoms: [:], now: now, calendar: calendar ?? tokyo, holidays: h, words: words))
    }

    private func dayPage(_ h: HolidayCalendar = .japan, words: LayoutWords = .japanese, calendar: Calendar? = nil, focus: DayKey? = nil) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: focus ?? day(2026, 11, 26), events: events, inkBottoms: [.extra: 500], now: now, calendar: calendar ?? tokyo, holidays: h, words: words))
    }

    private func year(_ h: HolidayCalendar = .japan, words: LayoutWords = .japanese, calendar: Calendar? = nil, year: Int = 2026) -> YearPageLayout {
        YearLayoutEngine.layout(YearLayoutInput(year: year, events: events, inkBottoms: [:], now: now, calendar: calendar ?? tokyo, holidays: h, words: words))
    }

    private func plain(_ labels: [DateLabel]) -> [DateLabel] {
        labels.map { label in
            var l = label
            l.tone = .normal
            l.holidayName = nil
            return l
        }
    }

    func testPaperGeometryIgnoresHolidays() throws {
        let others: [HolidayCalendar] = [try calendar("US-CA", .en), .none, long, x, w]
        let m0 = month(), w0 = week(), d0 = dayPage(), y0 = year()
        for h in others {
            var m = month(h), mBase = m0
            (m.dateLabels, mBase.dateLabels) = (plain(m.dateLabels), plain(mBase.dateLabels))
            XCTAssertEqual(m, mBase, h.id)
            var wk = week(h), wBase = w0
            (wk.dateLabels, wBase.dateLabels) = (plain(wk.dateLabels), plain(wBase.dateLabels))
            wk.allDayBand.tones = []
            wBase.allDayBand.tones = []
            XCTAssertEqual(wk, wBase, h.id)
            var dp = dayPage(h), dBase = d0
            (dp.dateLabels, dBase.dateLabels) = (plain(dp.dateLabels), plain(dBase.dateLabels))
            dp.allDayBand.tones = []
            dBase.allDayBand.tones = []
            XCTAssertEqual(dp, dBase, h.id)
            var yr = year(h), yBase = y0
            (yr.dateLabels, yBase.dateLabels) = (plain(yr.dateLabels), plain(yBase.dateLabels))
            XCTAssertEqual(yr, yBase, h.id)
        }
    }

    func testPaperGeometryIgnoresWords() {
        let de = LayoutWords.of(.de)
        var m = month(words: de), mBase = month()
        XCTAssertFalse(m.timedChips.filter(\.isMore).isEmpty, "the sample has a chip of 「+n件」")
        XCTAssertEqual(m.timedChips.filter(\.isMore).map(\.title), m.timedChips.filter(\.isMore).map { de.more($0.moreCount) }, "the words arrive")
        XCTAssertEqual(mBase.timedChips.filter(\.isMore).map(\.title), mBase.timedChips.filter(\.isMore).map { "+\($0.moreCount)件" })
        func blank(_ chips: [TimedChip]) -> [TimedChip] {
            chips.map { chip in
                var c = chip
                c.timeText = ""
                if c.isMore { c.title = "" }
                return c
            }
        }
        (m.timedChips, mBase.timedChips) = (blank(m.timedChips), blank(mBase.timedChips))
        XCTAssertEqual(m, mBase)
        func blank(_ boxes: [TimedEventBox]) -> [TimedEventBox] {
            boxes.map { box in
                var b = box
                b.timeText = ""
                return b
            }
        }
        var wk = week(words: de), wBase = week()
        XCTAssertTrue(wk.timedBoxes.contains { $0.timeText.contains("\u{2013}") }, "the words arrive")
        (wk.timedBoxes, wBase.timedBoxes) = (blank(wk.timedBoxes), blank(wBase.timedBoxes))
        XCTAssertEqual(wk, wBase)
        var dp = dayPage(words: de), dBase = dayPage()
        XCTAssertTrue(dp.timedBoxes.contains { $0.timeText.contains("\u{2013}") }, "the words arrive")
        (dp.timedBoxes, dBase.timedBoxes) = (blank(dp.timedBoxes), blank(dBase.timedBoxes))
        XCTAssertEqual(dp, dBase)
        XCTAssertEqual(year(words: de), year())
    }

    func testDeviceCalendarLocaleDoesNotMoveCells() {
        var calendars: [Calendar] = []
        for locale in ["en_US", "de_DE"] {
            var c = tokyo
            c.locale = Locale(identifier: locale)
            calendars.append(c)
        }
        for first in [1, 2, 7] {
            var c = tokyo
            c.firstWeekday = first
            calendars.append(c)
        }
        for c in calendars {
            XCTAssertEqual(month(calendar: c), month())
            XCTAssertEqual(week(calendar: c), week())
            XCTAssertEqual(dayPage(calendar: c), dayPage())
            XCTAssertEqual(year(calendar: c), year())
        }
    }

    func testWorkdayToneIsNormal() throws {
        let china = try calendar("CN", .zhHans)
        for working in [day(2024, 2, 4), day(2024, 5, 11)] {
            XCTAssertTrue(china.isWorkday(working), "\(working)")
            XCTAssertNil(china.name(of: working), "\(working)")
            XCTAssertEqual(month(china, year: 2024, month: working.month).dateLabels.first { $0.day == working }?.tone, .normal, "the month of \(working)")
            let weekPage = week(china, focus: working)
            XCTAssertEqual(weekPage.dateLabels.first { $0.day == working }?.tone, .normal, "the week of \(working)")
            XCTAssertEqual(weekPage.allDayBand.days.firstIndex(of: working).map { weekPage.allDayBand.tones[$0] }, .normal, "the week's band of \(working)")
            let oneDay = dayPage(china, focus: working)
            XCTAssertEqual(oneDay.dateLabels.first?.tone, .normal, "the day \(working)")
            XCTAssertEqual(oneDay.allDayBand.tones, [.normal], "the day's band \(working)")
            XCTAssertEqual(year(china, year: 2024).dateLabels.first { $0.day == working }?.tone, .normal, "the year of \(working)")
        }
        // The made-up calendar: no holiday, every weekend a working day.
        for labels in [month(w).dateLabels, week(w).dateLabels, dayPage(w).dateLabels, year(w).dateLabels] {
            XCTAssertTrue(labels.allSatisfy { $0.tone == .normal && $0.holidayName == nil })
        }
        XCTAssertTrue(week(w).allDayBand.tones.allSatisfy { $0 == .normal })
    }

    func testBandTonesFollowTheHolidays() throws {
        let us = try calendar("US", .en)
        let weekPage = week(us, focus: day(2026, 11, 23))
        XCTAssertEqual(weekPage.allDayBand.tones, weekPage.dateLabels.map(\.tone))
        XCTAssertEqual(weekPage.allDayBand.tones[weekPage.days.firstIndex(of: day(2026, 11, 26))!], .sundayOrHoliday, "Thanksgiving")
        XCTAssertEqual(weekPage.allDayBand.tones[weekPage.days.firstIndex(of: day(2026, 11, 23))!], .normal, "勤労感謝の日 is Japan's")
        let oneDay = dayPage(us, focus: day(2026, 11, 26))
        XCTAssertEqual(oneDay.allDayBand.tones, oneDay.dateLabels.map(\.tone))
        XCTAssertEqual(oneDay.allDayBand.tones, [.sundayOrHoliday])
        XCTAssertEqual(week(.japan, focus: day(2026, 11, 23)).allDayBand.tones[0], .sundayOrHoliday, "with Japan's")
        let noHolidays = week(.none, focus: day(2026, 11, 23))
        XCTAssertEqual(noHolidays.allDayBand.tones, [.normal, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday])
        XCTAssertEqual(dayPage(.none, focus: day(2026, 11, 23)).allDayBand.tones, [.normal])
    }

    func testHolidaysReachEveryPage() {
        let nov23 = day(2026, 11, 23)
        for (name, labels) in [("month", month(x).dateLabels), ("week", week(x, focus: nov23).dateLabels), ("day", dayPage(x, focus: nov23).dateLabels), ("year", year(x).dateLabels)] {
            XCTAssertTrue(labels.allSatisfy { $0.holidayName == "X" && $0.tone == .sundayOrHoliday }, name)
        }
        XCTAssertTrue(week(x, focus: nov23).allDayBand.tones.allSatisfy { $0 == .sundayOrHoliday })
        XCTAssertEqual(dayPage(x, focus: nov23).allDayBand.tones, [.sundayOrHoliday])
        XCTAssertEqual(PageNavigation.title(.day, focus: nov23, holidays: x), "2026年11月23日(月) X")
        for (name, labels) in [("month", month(.none).dateLabels), ("week", week(.none, focus: nov23).dateLabels), ("day", dayPage(.none, focus: nov23).dateLabels), ("year", year(.none).dateLabels)] {
            XCTAssertTrue(labels.allSatisfy { $0.holidayName == nil }, name)
        }
        XCTAssertEqual(PageNavigation.title(.day, focus: nov23, holidays: .none), "2026年11月23日(月)")
        XCTAssertEqual(PageNavigation.title(.day, focus: nov23), "2026年11月23日(月) 勤労感謝の日", "the default is Japan's")
        // The year's narrow cells take the short name, the others the full one (F-2, 0-17).
        let shortAndFull = HolidayCalendar(id: "two|ja", region: nil, source: TwoNames())
        XCTAssertEqual(year(shortAndFull).dateLabels.first { $0.day == day(2026, 7, 3) }?.holidayName, "Short")
        XCTAssertEqual(month(shortAndFull, month: 7).dateLabels.first { $0.day == day(2026, 7, 3) }?.holidayName, "Full (observed)")
        XCTAssertEqual(dayPage(shortAndFull, focus: day(2026, 7, 3)).dateLabels.first?.holidayName, "Full (observed)")
    }

    private struct TwoNames: HolidaySource {
        func entries(forYear year: Int) -> [DayKey: [HolidayEntry]] {
            [DayKey(year: year, month: 7, day: 3): [HolidayEntry(full: "Full (observed)", short: "Short")]]
        }
        func workdays(forYear year: Int) -> Set<DayKey> { [] }
        func note(forYear year: Int) -> HolidayYearNote? { nil }
    }

    /// In this target rather than PageNavigationTests: LayoutTests does not depend on Holidays.
    func testHolidayInTheDayTitle() throws {
        let us = try calendar("US", .en)
        let thanksgiving = day(2026, 11, 26)
        XCTAssertEqual(PageNavigation.title(.day, focus: thanksgiving, holidays: us, language: .en), DateText.dayTitle(thanksgiving, .en) + " Thanksgiving Day")
        // The date's form follows the device's region; in the US it is the contract's sample.
        func spaced(_ text: String) -> String {
            String(String.UnicodeScalarView(text.unicodeScalars.map { $0.properties.generalCategory == .spaceSeparator ? " " : $0 }))
        }
        XCTAssertEqual(spaced(DateText.dayTitle(thanksgiving, .en, region: "US")) + " " + (us.name(of: thanksgiving) ?? ""), "Thu, November 26, 2026 Thanksgiving Day")
        XCTAssertEqual(PageNavigation.title(.day, focus: day(2026, 11, 27), holidays: us, language: .en), DateText.dayTitle(day(2026, 11, 27), .en), "no holiday in the whole country")
    }
}
