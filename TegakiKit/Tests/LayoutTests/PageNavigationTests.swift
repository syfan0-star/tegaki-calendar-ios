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

    func testCompactTitle() {
        // M4b, M4B_CONTRACT §5: the iPhone's compact header.
        XCTAssertEqual(PageNavigation.compactTitle(.day, focus: day(2026, 10, 7)), "10月7日(水)")
        XCTAssertEqual(PageNavigation.compactTitle(.day, focus: day(2026, 10, 12)), "10月12日(月)", "no holiday name")
        XCTAssertEqual(PageNavigation.compactTitle(.day, focus: day(2026, 1, 1)), "1月1日(木)")
        XCTAssertEqual(PageNavigation.compactTitle(.day, focus: day(2026, 10, 17)), "10月17日(土)")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: day(2026, 10, 7)), "10/5〜10/11")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: day(2026, 10, 4)), "9/28〜10/4", "across months")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: day(2027, 1, 1)), "12/28〜1/3", "across years: no year")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: day(2026, 12, 28)), "12/28〜1/3")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: day(2026, 10, 25)), "10/19〜10/25", "from a Sunday")
        XCTAssertEqual(PageNavigation.compactTitle(.month, focus: day(2026, 10, 4)), "2026年10月")
        XCTAssertEqual(PageNavigation.compactTitle(.month, focus: day(2026, 12, 31)), "2026年12月")
        XCTAssertEqual(PageNavigation.compactTitle(.year, focus: day(2026, 10, 4)), "2026年")
        XCTAssertEqual(PageNavigation.compactTitle(.month, focus: day(2026, 10, 4)), PageNavigation.title(.month, focus: day(2026, 10, 4)))
        XCTAssertEqual(PageNavigation.compactTitle(.year, focus: day(2026, 10, 4)), PageNavigation.title(.year, focus: day(2026, 10, 4)))
    }

    func testInitialScrollX() {
        // M4b, M4B_CONTRACT §1.2: the first horizontal position (lu) for a visible width (lu).
        func sx(_ page: any PageLayout, _ now: Date, _ visible: CGFloat) -> CGFloat {
            PageNavigation.initialScrollX(page, now: now, calendar: F.tokyo, visibleWidth: visible)
        }
        let colW = F.colW
        let month = F.monthLayout([]) // October 2026: the grid is 9/28 … 11/8
        XCTAssertEqual(sx(month, F.demoNow, 804), 0, "Wednesday's column (ends at 600) fits in 804")
        XCTAssertEqual(sx(month, F.october(8), 804), 0, "Thursday's column (ends at 800) fits")
        XCTAssertEqual(sx(month, F.october(9), 804), 196, "Friday → 1000 − 804")
        XCTAssertEqual(sx(month, F.october(10), 804), 396, "Saturday → 1200 − 804")
        XCTAssertEqual(sx(month, F.october(11), 804), 596, "Sunday → 1400 − 804")
        XCTAssertEqual(sx(month, F.october(11), 780), 620, "Sunday on a 390 pt iPhone")
        XCTAssertEqual(sx(month, F.date(2026, 11, 8), 804), 596, "11/8, the grid's last cell")
        XCTAssertEqual(sx(month, F.date(2026, 9, 28), 804), 0, "9/28, the grid's first cell")
        XCTAssertEqual(sx(month, F.date(2026, 12, 25), 804), 0, "today not on the grid")
        XCTAssertEqual(sx(month, F.date(2025, 10, 11), 804), 0, "another year")
        XCTAssertEqual(sx(month, F.october(11), 1400), 0, "everything visible")
        XCTAssertEqual(sx(month, F.october(11), 2000), 0, "a viewport wider than the paper")
        XCTAssertEqual(sx(month, F.october(11), 1399), 1)
        let week = F.weekLayout([])
        XCTAssertEqual(sx(week, F.demoNow, 852), 0, "Wednesday's column (ends at 636.6) fits in 852")
        XCTAssertEqual(sx(week, F.october(8), 852), 0, "Thursday's column (ends at 827.4) fits")
        XCTAssertEqual(sx(week, F.october(9), 852), 64 + 5 * colW - 852, accuracy: 1e-9, "Friday")
        XCTAssertEqual(sx(week, F.october(10), 852), 64 + 6 * colW - 852, accuracy: 1e-9, "Saturday")
        XCTAssertEqual(sx(week, F.october(11), 852), 64 + 7 * colW - 852, accuracy: 1e-9, "Sunday")
        XCTAssertEqual(sx(week, F.october(11), 852), 548, accuracy: 0.5, "Sunday → 548 (§1.2)")
        XCTAssertEqual(sx(week, F.october(12), 852), 0, "today not in the week")
        XCTAssertEqual(sx(F.weekLayout([], focus: day(2026, 10, 12)), F.demoNow, 852), 0, "another week's page")
        XCTAssertEqual(sx(week, F.october(11), 1400), 0, "everything visible")
        XCTAssertEqual(sx(week, F.october(11), 1600), 0, "a viewport wider than the paper")
        let year = F.yearLayout([])
        XCTAssertEqual(sx(year, F.demoNow, 300.2), 1064, "October's column on an iPhone")
        XCTAssertEqual(sx(year, F.demoNow, 764.6), 1400 - 764.6, accuracy: 1e-9, "13 inch → clamped to the right edge (635.4)")
        XCTAssertEqual(sx(year, F.demoNow, 555.5), 1400 - 555.5, accuracy: 1e-9, "iPad mini → 844.5")
        XCTAssertEqual(sx(year, F.demoNow, 1400), 0, "everything visible")
        XCTAssertEqual(sx(year, F.date(2026, 1, 15), 300.2), 56, "January → the gutter's width")
        XCTAssertEqual(sx(year, F.date(2026, 2, 1), 300.2), 168, "February → 56 + 112")
        XCTAssertEqual(sx(year, F.date(2026, 12, 15), 300.2), 1400 - 300.2, accuracy: 1e-9, "December → clamped")
        XCTAssertEqual(sx(year, F.date(2026, 6, 1), 1400), 0)
        XCTAssertEqual(sx(year, F.date(2025, 10, 7), 300.2), 0, "last year")
        XCTAssertEqual(sx(year, F.date(2027, 10, 7), 300.2), 0, "next year")
        XCTAssertEqual(sx(F.yearLayout([], year: 2027), F.demoNow, 300.2), 0, "another year's page")
        let dayPage = F.dayLayout([])
        XCTAssertEqual(sx(dayPage, F.demoNow, 716), 0, "day: always 0")
        XCTAssertEqual(sx(dayPage, F.demoNow, 1000), 0)
        XCTAssertEqual(sx(dayPage, F.demoNow, 100), 0)
        XCTAssertEqual(sx(F.dayLayout([], focus: day(2026, 10, 8)), F.demoNow, 716), 0)
        for bad in [CGFloat.nan, 0, -5, .infinity] {
            XCTAssertEqual(sx(month, F.october(11), bad), 0, "month: visibleWidth \(bad)")
            XCTAssertEqual(sx(week, F.october(11), bad), 0, "week: visibleWidth \(bad)")
            XCTAssertEqual(sx(year, F.demoNow, bad), 0, "year: visibleWidth \(bad)")
            XCTAssertEqual(sx(dayPage, F.demoNow, bad), 0, "day: visibleWidth \(bad)")
        }
        XCTAssertEqual(PageNavigation.initialScrollX(dayPage, now: F.demoNow, visibleWidth: 716), 0, "the device-calendar overload")
        // With the real `ZoomPolicy.visibleWidth` of the devices.
        XCTAssertEqual(sx(month, F.october(11), ZoomPolicy.visibleWidth(.month, viewportWidth: 402)), 596, "iPhone 17 month, Sunday")
        XCTAssertEqual(sx(week, F.october(11), ZoomPolicy.visibleWidth(.week, viewportWidth: 402)), 548, accuracy: 1, "iPhone 17 week, Sunday")
        XCTAssertEqual(sx(year, F.demoNow, ZoomPolicy.visibleWidth(.year, viewportWidth: 402)), 1064, "iPhone 17 year")
        XCTAssertEqual(sx(year, F.demoNow, ZoomPolicy.visibleWidth(.year, viewportWidth: 1024)), 635.4, accuracy: 1, "13 inch year")
        XCTAssertEqual(sx(year, F.demoNow, ZoomPolicy.visibleWidth(.year, viewportWidth: 744)), 844.5, accuracy: 1, "iPad mini year")
        XCTAssertEqual(sx(month, F.october(11), ZoomPolicy.visibleWidth(.month, viewportWidth: 744)), 0, "iPad mini month: fit")
    }
}
