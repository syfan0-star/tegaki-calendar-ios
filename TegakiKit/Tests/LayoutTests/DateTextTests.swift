import XCTest
import Foundation
import Layout

/// `DateText` (docs/M7B_CONTRACT.md §3). The whole range of the Japanese text (2000–2099, J-3) is
/// compared with the copy of 1.1 in KitChecks (`Text11`, which XCTest cannot see); here are samples
/// of 1.1's text written out, and the other languages' samples of §3.1.
final class DateTextTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    /// ICU's spaces (U+00A0, U+2009 around the dash, U+202F) compared as a space.
    private func spaced(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { $0.properties.generalCategory == .spaceSeparator ? " " : $0 }))
    }

    func testJapaneseSamplesAreTheOneOneText() {
        let samples: [(String, String)] = [
            (DateText.dayTitle(day(2026, 10, 4), .ja), "2026年10月4日(日)"),
            (DateText.dayTitle(day(2026, 10, 7), .ja), "2026年10月7日(水)"),
            (DateText.dayTitle(day(2000, 1, 1), .ja), "2000年1月1日(土)"),
            (DateText.dayTitle(day(2099, 12, 31), .ja), "2099年12月31日(木)"),
            (DateText.dayTitle(day(2024, 2, 29), .ja), "2024年2月29日(木)"),
            (DateText.dayTitle(day(2026, 11, 3), .ja), "2026年11月3日(火)"),
            (DateText.dayTitle(day(2027, 1, 1), .ja), "2027年1月1日(金)"),
            (DateText.dayTitle(day(2026, 12, 28), .ja), "2026年12月28日(月)"),
            (DateText.shortDay(day(2026, 10, 7), .ja), "10月7日(水)"),
            (DateText.shortDay(day(2026, 1, 5), .ja), "1月5日(月)"),
            (DateText.shortDay(day(2026, 12, 31), .ja), "12月31日(木)"),
            (DateText.shortDay(day(2024, 2, 29), .ja), "2月29日(木)"),
            (DateText.shortDay(day(2000, 1, 1), .ja), "1月1日(土)"),
            (DateText.shortDay(day(2026, 10, 4), .ja), "10月4日(日)"),
            (DateText.monthTitle(YearMonth(year: 2026, month: 10), .ja), "2026年10月"),
            (DateText.monthTitle(YearMonth(year: 2026, month: 1), .ja), "2026年1月"),
            (DateText.monthTitle(YearMonth(year: 2000, month: 12), .ja), "2000年12月"),
            (DateText.monthTitle(YearMonth(year: 2099, month: 7), .ja), "2099年7月"),
            (DateText.monthTitle(YearMonth(year: 2026, month: 10), .ja, compact: true), "2026年10月"),
            (DateText.monthTitle(YearMonth(year: 2026, month: 1), .ja, compact: true), "2026年1月"),
            (DateText.yearTitle(2026, .ja), "2026年"),
            (DateText.yearTitle(2000, .ja), "2000年"),
            (DateText.yearTitle(2099, .ja), "2099年"),
            (DateText.weekTitle(first: day(2026, 9, 28), .ja, compact: false), "2026年9月28日〜10月4日"),
            (DateText.weekTitle(first: day(2026, 10, 5), .ja, compact: false), "2026年10月5日〜10月11日"),
            (DateText.weekTitle(first: day(2026, 11, 2), .ja, compact: false), "2026年11月2日〜11月8日"),
            (DateText.weekTitle(first: day(2026, 12, 28), .ja, compact: false), "2026年12月28日〜2027年1月3日"),
            (DateText.weekTitle(first: day(2020, 12, 28), .ja, compact: false), "2020年12月28日〜2021年1月3日"),
            (DateText.weekTitle(first: day(2031, 12, 29), .ja, compact: false), "2031年12月29日〜2032年1月4日"),
            (DateText.weekTitle(first: day(2026, 11, 1), .ja, compact: false), "2026年11月1日〜11月7日"),
            (DateText.weekTitle(first: day(2026, 9, 28), .ja, compact: true), "9/28〜10/4"),
            (DateText.weekTitle(first: day(2026, 10, 5), .ja, compact: true), "10/5〜10/11"),
            (DateText.weekTitle(first: day(2026, 12, 28), .ja, compact: true), "12/28〜1/3"),
            (DateText.weekTitle(first: day(2026, 11, 1), .ja, compact: true), "11/1〜11/7"),
            (DateText.spokenDay(day(2026, 10, 4), .ja), "2026年10月4日(日)"),
            (DateText.spokenDay(day(2000, 1, 1), .ja), "2000年1月1日(土)"),
            (DateText.weekdays(.full, .ja)[3], "水曜日"),
            (DateText.weekdays(.letter, .ja)[0], "日"),
            (DateText.monthName(10, .short, .ja), "10月"),
            (DateText.number(12_345, .ja), "12,345"),
        ]
        XCTAssertEqual(samples.count, 40)
        for (text, expected) in samples {
            XCTAssertEqual(text, expected)
        }
        XCTAssertEqual(DateText.plainDay(day(2026, 10, 7), .ja), "2026年10月7日", "no weekday (the day's label of 1.1)")
        XCTAssertEqual(YearMonth(year: 2026, month: 10).title(language: .ja), YearMonth(year: 2026, month: 10).title)
    }

    func testEnglishSamples() {
        XCTAssertEqual(spaced(DateText.dayTitle(day(2026, 10, 4), .en, region: "US")), "Sun, October 4, 2026")
        XCTAssertEqual(spaced(DateText.shortDay(day(2026, 10, 7), .en, region: "US")), "Wed, Oct 7")
        XCTAssertEqual(spaced(DateText.monthTitle(YearMonth(year: 2026, month: 10), .en, region: "US")), "October 2026")
        XCTAssertEqual(spaced(DateText.monthTitle(YearMonth(year: 2026, month: 10), .en, compact: true, region: "US")), "Oct 2026")
        XCTAssertEqual(spaced(DateText.monthTitle(YearMonth(year: 2026, month: 9), .es, region: "ES")), "septiembre de 2026")
        XCTAssertEqual(spaced(DateText.weekTitle(first: day(2026, 9, 28), .en, compact: false, region: "US")), "Sep 28 \u{2013} Oct 4, 2026")
        XCTAssertEqual(spaced(DateText.weekTitle(first: day(2026, 9, 28), .en, compact: true, region: "US")), "9/28 \u{2013} 10/4")
        XCTAssertEqual(spaced(DateText.weekTitle(first: day(2026, 9, 28), .fr, compact: true, region: "FR")), "28/09 \u{2013} 04/10")
        XCTAssertEqual(spaced(DateText.spokenDay(day(2026, 10, 4), .en, region: "US")), "Sunday, October 4, 2026")
        XCTAssertEqual(spaced(DateText.plainDay(day(2026, 10, 7), .en, region: "US")), "October 7, 2026")
        XCTAssertEqual(DateText.time(hour: 9, minute: 5), "9:05", "every language, D7")
        XCTAssertEqual(DateText.time(hour: 23, minute: 0), "23:00")
    }

    func testGregorianIsFixed() {
        for region in ["TH", "JP", "SA", "IL"] {
            XCTAssertEqual(DateText.calendar(.en, region: region).identifier, .gregorian, region)
            XCTAssertTrue(DateText.dayTitle(day(2026, 10, 4), .en, region: region).contains("2026"), region)
            XCTAssertTrue(DateText.monthTitle(YearMonth(year: 2026, month: 10), .en, region: region).contains("2026"), region)
            XCTAssertEqual(DateText.yearTitle(2026, .en), "2026", region)
        }
        XCTAssertFalse(DateText.dayTitle(day(2026, 10, 4), .en, region: "TH").contains("2569"), "no Buddhist year")
        XCTAssertFalse(DateText.dayTitle(day(2026, 10, 4), .en, region: "TH").contains("AD"), "no era")
        let date = Date(timeIntervalSince1970: 1_792_897_200) // 2026-10-25
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertTrue(DateText.numericDate(date, .en, region: "TH", timeZone: tokyo).contains("2026"))
        XCTAssertFalse(DateText.numericDate(date, .en, region: "US", timeZone: tokyo).contains(":"), "the date only")
        XCTAssertTrue(DateText.numericDateTime(date, .en, region: "US", timeZone: tokyo).contains(":"), "with the time")
    }

    func testMondayFirst() {
        XCTAssertEqual(DateText.mondayFirst, [1, 2, 3, 4, 5, 6, 0])
        XCTAssertEqual(DateText.mondayFirst, WeekStart.monday.order)
        XCTAssertEqual(DateText.mondayFirst.map { DateText.weekdays(.letter, .ja)[$0] }, ["月", "火", "水", "木", "金", "土", "日"])
        XCTAssertEqual(WeekStart.sunday.order.map { DateText.weekdays(.letter, .ja)[$0] }, ["日", "月", "火", "水", "木", "金", "土"])
    }

    func testWeekdayLetterTable() {
        let table: [(UILanguage, [String])] = [
            (.ja, ["日", "月", "火", "水", "木", "金", "土"]),
            (.zhHans, ["日", "一", "二", "三", "四", "五", "六"]),
            (.zhHant, ["日", "一", "二", "三", "四", "五", "六"]),
            (.ko, ["일", "월", "화", "수", "목", "금", "토"]),
            (.en, ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]),
            (.de, ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]),
            (.fr, ["di", "lu", "ma", "me", "je", "ve", "sa"]),
            (.es, ["do", "lu", "ma", "mi", "ju", "vi", "sá"]),
            (.it, ["do", "lu", "ma", "me", "gi", "ve", "sa"]),
            (.ptBR, ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]),
        ]
        XCTAssertEqual(table.count, UILanguage.allCases.count)
        for (language, letters) in table {
            XCTAssertEqual(DateText.weekdays(.letter, language), letters, language.rawValue)
        }
    }

    func testNumbers() {
        XCTAssertEqual(DateText.number(12_345, .ja), "12,345")
        XCTAssertEqual(DateText.number(0, .ja), "0")
        XCTAssertEqual(DateText.number(-1_000, .ja), "-1,000")
        XCTAssertEqual(spaced(DateText.number(12_345, .en, region: "US")), "12,345")
        XCTAssertEqual(spaced(DateText.number(12_345, .de, region: "DE")), "12.345")
        XCTAssertEqual(spaced(DateText.number(12_345, .fr, region: "FR")), "12 345")
    }

    func testYearHasNoGrouping() {
        for language in UILanguage.allCases where language != .ja {
            XCTAssertEqual(DateText.yearTitle(2026, language), "2026", language.rawValue)
            XCTAssertEqual(DateText.yearTitle(12_345, language), "12345", language.rawValue)
        }
        XCTAssertEqual(DateText.yearTitle(2026, .ja), "2026年")
    }
}
