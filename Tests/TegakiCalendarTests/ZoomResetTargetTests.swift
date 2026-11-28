import CoreGraphics
import Layout
import XCTest
@testable import TegakiCalendar

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §16.3.1, §16.6; MZ4): where 等倍 goes, `ZoomReset` (pure, outside the Kit). The week and
/// the day go to fit (`ZoomPolicy.Bounds.fit`: the paper column's width ÷ 1,400 or 1,000 lu, one page exactly as wide as the
/// screen; the owner's words of 11/22), the month and the year to their opening zoom (`Bounds.open`, ratio 1) as before.
/// fit is clamped into the limits, which on every device already hold it (min ≤ open ≤ fit ≤ max); limits made by hand
/// show the clamp. On the fast path (no canvas, no simulator needed).
final class ZoomResetTargetTests: XCTestCase {
    /// The week and the day follow fit; the month and the year do not. Every kind is named.
    func testFollowsFitIsTheWeekAndTheDay() {
        XCTAssertEqual(PageKind.allCases.count, 4, "every kind below")
        XCTAssertTrue(ZoomReset.followsFit(.week))
        XCTAssertTrue(ZoomReset.followsFit(.day))
        XCTAssertTrue(ZoomReset.followsFit(.month), "1.4.3: the month follows fit")
        XCTAssertFalse(ZoomReset.followsFit(.year))
    }

    /// The 11-inch iPad's portrait paper area (834 × 955): the week goes to 834 / 1,400 = 0.5957 (its opening zoom is
    /// 955 / 1,920 = 0.4974), the day to 834 / 1,000 = 0.834 (open 955 / 2,400 = 0.3979). The year stays at its opening zoom
    /// (955 / 1,860 = 0.5134, below fit); the month on a landscape iPad (1,366 × 830) at its opening zoom 830 / 1,050 = 0.7905,
    /// not at fit 1,366 / 1,400 = 0.9757.
    func testTheWeekAndTheDayGoToFitTheMonthAndTheYearToTheirOpeningZoom() {
        let portrait = CGSize(width: 834, height: 955)
        let week = ZoomPolicy.bounds(.week, overview: ZoomPolicy.baseSize(.week), viewport: portrait)
        XCTAssertEqual(week.open, 955.0 / 1920, accuracy: 1e-9)
        XCTAssertEqual(ZoomReset.target(.week, bounds: week), 834.0 / 1400, accuracy: 1e-9, "the week: one week across")
        let day = ZoomPolicy.bounds(.day, overview: ZoomPolicy.baseSize(.day), viewport: portrait)
        XCTAssertEqual(day.open, 955.0 / 2400, accuracy: 1e-9)
        XCTAssertEqual(ZoomReset.target(.day, bounds: day), 834.0 / 1000, accuracy: 1e-9, "the day: one day across")
        let year = ZoomPolicy.bounds(.year, overview: ZoomPolicy.baseSize(.year), viewport: portrait)
        XCTAssertEqual(ZoomReset.target(.year, bounds: year), 955.0 / 1860, accuracy: 1e-9, "the year: its opening zoom")
        XCTAssertLessThan(ZoomReset.target(.year, bounds: year), year.fit - 0.05, "the year: not fit")
        let month = ZoomPolicy.bounds(.month, overview: ZoomPolicy.baseSize(.month), viewport: CGSize(width: 1366, height: 830))
        XCTAssertEqual(ZoomReset.target(.month, bounds: month), 1366.0 / 1400, accuracy: 1e-9, "1.4.3: the month: fit, one month across")
        XCTAssertEqual(month.fit, 1366.0 / 1400, accuracy: 1e-9, "the month's fit is not where it goes")
        XCTAssertEqual(month.open, 830.0 / 1050, accuracy: 1e-9, "1.4.3: the month's opening zoom is as it was")
        XCTAssertGreaterThan(ZoomReset.target(.month, bounds: month), month.open + 0.1, "1.4.3: the month: not its opening zoom")
    }

    /// Where the opening zoom already is fit (the 18 Pro Max's portrait week, 440 × 622: open = fit = 440 / 1,400) the target is
    /// that same zoom; the day there still goes up to fit (440 / 1,000, its opening zoom 618 / 2,400 lower).
    func testWhereOpenIsFitTheTargetIsTheSameZoom() {
        let week = ZoomPolicy.bounds(.week, overview: ZoomPolicy.baseSize(.week), viewport: CGSize(width: 440, height: 622))
        XCTAssertEqual(week.open, week.fit, accuracy: 1e-9, "width-bound")
        XCTAssertEqual(ZoomReset.target(.week, bounds: week), 440.0 / 1400, accuracy: 1e-9)
        let day = ZoomPolicy.bounds(.day, overview: ZoomPolicy.baseSize(.day), viewport: CGSize(width: 440, height: 618))
        XCTAssertEqual(ZoomReset.target(.day, bounds: day), 440.0 / 1000, accuracy: 1e-9)
        XCTAssertGreaterThan(ZoomReset.target(.day, bounds: day), day.open + 0.1)
    }

    /// The iPhone in landscape on the joined path (P-B6 イ, 874 × 205): the cap raises the lowest and the opening zoom to 3
    /// weeks / 5 days across, and leaves fit; 等倍 goes to one week / one day across (3 and 5 times the cap).
    func testTheCapLeavesFit() {
        let viewport = CGSize(width: 874, height: 205)
        for (kind, pages) in [(PageKind.week, CGFloat(3)), (.day, 5)] {
            let bounds = ZoomPolicy.cappedBounds(kind, overview: ZoomPolicy.baseSize(kind), viewport: viewport, maxVisiblePages: pages)
            let cap = 874 / (pages * ZoomPolicy.paperWidth(kind))
            XCTAssertEqual(bounds.open, cap, accuracy: 1e-9, "\(kind): opens at the cap")
            XCTAssertEqual(ZoomReset.target(kind, bounds: bounds), 874 / ZoomPolicy.paperWidth(kind), accuracy: 1e-9, "\(kind): one page across")
            XCTAssertEqual(ZoomReset.target(kind, bounds: bounds) / bounds.open, pages, accuracy: 1e-9, "\(kind): \(pages) times the cap")
        }
    }

    /// Limits made by hand: a fit above max is max, below min is min, NaN is min (`Bounds.clamped`); the month and the year
    /// take `open` as it is.
    func testFitIsClampedIntoTheLimits() {
        let high = ZoomPolicy.Bounds(fit: 5, open: 0.5, min: 0.4, max: 2)
        XCTAssertEqual(ZoomReset.target(.week, bounds: high), 2, accuracy: 1e-12)
        XCTAssertEqual(ZoomReset.target(.day, bounds: high), 2, accuracy: 1e-12)
        let low = ZoomPolicy.Bounds(fit: 0.1, open: 0.5, min: 0.4, max: 2)
        XCTAssertEqual(ZoomReset.target(.week, bounds: low), 0.4, accuracy: 1e-12)
        XCTAssertEqual(ZoomReset.target(.day, bounds: low), 0.4, accuracy: 1e-12)
        let notANumber = ZoomPolicy.Bounds(fit: .nan, open: 0.5, min: 0.4, max: 2)
        XCTAssertEqual(ZoomReset.target(.week, bounds: notANumber), 0.4, accuracy: 1e-12)
        for kind in [PageKind.year] {
            XCTAssertEqual(ZoomReset.target(kind, bounds: high), 0.5, accuracy: 1e-12, "\(kind)")
            XCTAssertEqual(ZoomReset.target(kind, bounds: low), 0.5, accuracy: 1e-12, "\(kind)")
        }
        // 1.4.3 (docs/R1_4_3_CONTRACT.md §6.1, §8.5 R0m): the month's fit is clamped as the week's and the day's.
        XCTAssertEqual(ZoomReset.target(.month, bounds: high), 2, accuracy: 1e-12, "month")
        XCTAssertEqual(ZoomReset.target(.month, bounds: low), 0.4, accuracy: 1e-12, "month")
        XCTAssertEqual(ZoomReset.target(.month, bounds: notANumber), 0.4, accuracy: 1e-12, "month")
    }
}
