import XCTest
import Foundation
import CoreGraphics
import Layout

/// Page ids, ranges, ◀ ▶ moves and titles (M3A_CONTRACT §1.9). Expectations follow the web
/// version's tests/page-geometry.test.mjs (pageIdFor / rangeFor / navigate, Monday start).
final class PageNavigationTests: XCTestCase {
    private typealias F = M3aFixtures
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { F.day(y, m, d) }

    func testPageIds() {
        XCTAssertEqual(PageNavigation.pageId(.day, focus: day(2026, 10, 4)), "d-2026-10-04")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: day(2026, 10, 4)), "w-2026-09-28", "a Sunday belongs to the week of its Monday")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: day(2026, 10, 5)), "w-2026-10-05")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: day(2026, 10, 11)), "w-2026-10-05")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: day(2027, 1, 1)), "w-2026-12-28")
        XCTAssertEqual(PageNavigation.pageId(.month, focus: day(2026, 10, 31)), "m1-2026-10")
        XCTAssertEqual(PageNavigation.pageId(.month, focus: day(2027, 1, 1)), "m1-2027-01")
        XCTAssertEqual(PageNavigation.pageId(.year, focus: day(2027, 1, 1)), "y-2027")
        XCTAssertEqual(PageNavigation.pageId(.year, focus: day(2026, 12, 31)), "y-2026")
        XCTAssertEqual(PageNavigation.mondayOnOrBefore(day(2026, 10, 4)), day(2026, 9, 28))
        XCTAssertEqual(PageNavigation.mondayOnOrBefore(day(2026, 10, 5)), day(2026, 10, 5))
        // The engines use the same ids.
        XCTAssertEqual(F.weekLayout([], focus: day(2026, 10, 4)).pageId, "w-2026-09-28")
        XCTAssertEqual(F.dayLayout([], focus: day(2026, 10, 4)).pageId, "d-2026-10-04")
        XCTAssertEqual(F.yearLayout([], year: 2027).pageId, "y-2027")
        XCTAssertEqual(F.monthLayout([]).pageId, "m1-2026-10")
    }

    func testDayRanges() {
        let d = PageNavigation.dayRange(.day, focus: day(2026, 10, 7))
        XCTAssertEqual(d.start, day(2026, 10, 7))
        XCTAssertEqual(d.end, day(2026, 10, 8))
        let w = PageNavigation.dayRange(.week, focus: day(2026, 10, 7))
        XCTAssertEqual(w.start, day(2026, 10, 5))
        XCTAssertEqual(w.end, day(2026, 10, 12))
        XCTAssertEqual(w.end.dayNumber - w.start.dayNumber, 7)
        let m = PageNavigation.dayRange(.month, focus: day(2026, 10, 15))
        XCTAssertEqual(m.start, day(2026, 9, 28))
        XCTAssertEqual(m.end, day(2026, 11, 9), "exclusive end after the 42-day grid")
        XCTAssertEqual(m.end.dayNumber - m.start.dayNumber, 42)
        let y = PageNavigation.dayRange(.year, focus: day(2026, 10, 7))
        XCTAssertEqual(y.start, day(2026, 1, 1))
        XCTAssertEqual(y.end, day(2027, 1, 1))
        XCTAssertEqual(y.end.dayNumber - y.start.dayNumber, 365)
        let leap = PageNavigation.dayRange(.year, focus: day(2028, 6, 1))
        XCTAssertEqual(leap.end.dayNumber - leap.start.dayNumber, 366)
    }

    func testMove() {
        XCTAssertEqual(PageNavigation.move(.day, focus: day(2026, 10, 4), by: 1), day(2026, 10, 5))
        XCTAssertEqual(PageNavigation.move(.day, focus: day(2026, 10, 1), by: -1), day(2026, 9, 30))
        XCTAssertEqual(PageNavigation.move(.day, focus: day(2026, 10, 4), by: 0), day(2026, 10, 4))
        XCTAssertEqual(PageNavigation.move(.week, focus: day(2026, 10, 7), by: 1), day(2026, 10, 14), "same weekday")
        XCTAssertEqual(PageNavigation.move(.week, focus: day(2026, 10, 7), by: -1), day(2026, 9, 30))
        XCTAssertEqual(PageNavigation.move(.week, focus: day(2026, 12, 30), by: 1), day(2027, 1, 6))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 10, 31), by: 1), day(2026, 11, 1), "the 1st of the next month")
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 3, 31), by: -1), day(2026, 2, 1))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 12, 15), by: 1), day(2027, 1, 1))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 1, 15), by: -1), day(2025, 12, 1))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 10, 15), by: 0), day(2026, 10, 1))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 10, 15), by: -12), day(2025, 10, 1))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 10, 15), by: 15), day(2028, 1, 1))
        XCTAssertEqual(PageNavigation.move(.month, focus: day(2026, 1, 15), by: -25), day(2023, 12, 1))
        XCTAssertEqual(PageNavigation.move(.year, focus: day(2026, 10, 4), by: 1), day(2027, 1, 1))
        XCTAssertEqual(PageNavigation.move(.year, focus: day(2028, 2, 29), by: -1), day(2027, 1, 1))
        XCTAssertEqual(PageNavigation.move(.year, focus: day(2026, 10, 4), by: 0), day(2026, 1, 1))
        // Moving keeps the page id consistent with the range.
        let next = PageNavigation.move(.week, focus: day(2026, 10, 7), by: 1)
        XCTAssertEqual(PageNavigation.pageId(.week, focus: next), "w-2026-10-12")
    }

    func testTitles() {
        XCTAssertEqual(PageNavigation.title(.day, focus: day(2026, 10, 12)), "2026年10月12日(月) スポーツの日")
        XCTAssertEqual(PageNavigation.title(.day, focus: day(2026, 10, 4)), "2026年10月4日(日)")
        XCTAssertEqual(PageNavigation.title(.day, focus: day(2026, 1, 1)), "2026年1月1日(木) 元日")
        XCTAssertEqual(PageNavigation.title(.week, focus: day(2026, 10, 4)), "2026年9月28日〜10月4日")
        XCTAssertEqual(PageNavigation.title(.week, focus: day(2026, 10, 7)), "2026年10月5日〜10月11日", "the month on both sides")
        XCTAssertEqual(PageNavigation.title(.week, focus: day(2027, 1, 1)), "2026年12月28日〜2027年1月3日", "the year on both sides across a year")
        XCTAssertEqual(PageNavigation.title(.month, focus: day(2026, 10, 4)), "2026年10月")
        XCTAssertEqual(PageNavigation.title(.month, focus: day(2027, 1, 31)), "2027年1月")
        XCTAssertEqual(PageNavigation.title(.year, focus: day(2026, 10, 4)), "2026年")
        XCTAssertEqual(PageNavigation.weekdayLetters, ["日", "月", "火", "水", "木", "金", "土"])
    }

    func testInitialScrollOfTheMonthPage() {
        XCTAssertEqual(PageNavigation.initialScrollY(F.monthLayout([]), now: F.demoNow, calendar: F.tokyo), 0)
        XCTAssertEqual(PageNavigation.initialScrollY(F.monthLayout([], ink: [.memo: 900]), now: F.demoNow, calendar: F.tokyo), 0)
    }
}
