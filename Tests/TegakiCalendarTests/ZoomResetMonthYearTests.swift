import CoreGraphics
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §6.1, §6.3, §6.4, §6.5, §11.2 row S, §11.5 MS4, 0g-26): 等倍 of the month (and of the year
// once it joins) is fit, as the week's and the day's (`ZoomReset.followsFit`: the kinds of `SpanKinds.joined`), on both paths
// with the same key (`AppSettings.zoomFit(for:)`, "zoomFit.<kind>"), and screenshot mode's `--screenshot-zoom fit` reaches it.
// The opening zoom does not change. The year's expectations are read from `SpanKinds.joined.contains(.year)` (§11.2): the
// fallback of 0g-3 needs no change here. On the fast path (no canvas, no simulator needed).

final class ZoomResetMonthYearTests: XCTestCase {
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "ZoomResetMonthYearTests-\(UUID().uuidString)"
        AppSettings.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() {
        AppSettings.defaults.removePersistentDomain(forName: suiteName)
        AppSettings.defaults = .standard
        super.tearDown()
    }

    /// MS4: every kind follows fit exactly when it joins sideways or is the week or the day (`SpanKinds.joined` holds both);
    /// the month does since 1.4.3.
    func testEveryJoinedKindFollowsFit() {
        XCTAssertEqual(PageKind.allCases.count, 4, "every kind below")
        for kind in PageKind.allCases {
            XCTAssertEqual(ZoomReset.followsFit(kind), kind == .week || kind == .day || SpanKinds.joined.contains(kind), "\(kind)")
        }
        XCTAssertTrue(ZoomReset.followsFit(.week))
        XCTAssertTrue(ZoomReset.followsFit(.day))
        XCTAssertTrue(ZoomReset.followsFit(.month), "the month's 等倍 is fit (1.4.3)")
        XCTAssertEqual(ZoomReset.followsFit(.year), SpanKinds.joined.contains(.year), "the year with D1y")
    }

    /// MS4, §6.3: where 等倍 takes the month — a landscape 13-inch iPad (1,366 × 830): fit 1,366 / 1,400, above its opening zoom
    /// 830 / 1,050, which does not change; a landscape 11-inch iPad (1,210 × 640): 1,210 / 1,400; an iPhone 17 in landscape
    /// (750 × 230): 750 / 1,400; the 11-inch iPad in portrait (834 × 955), where the opening zoom is already fit: that same
    /// zoom. Limits made by hand: the clamp of fit. The year: fit once it joins (the 11-inch portrait 834 / 1,400, the iPhone's
    /// capped landscape 3 times the cap), else its opening zoom.
    func testTheMonthsTargetIsFit() {
        let wide13 = ZoomPolicy.bounds(.month, overview: ZoomPolicy.baseSize(.month), viewport: CGSize(width: 1_366, height: 830))
        XCTAssertEqual(wide13.open, 830.0 / 1_050, accuracy: 1e-9, "the opening zoom stays")
        XCTAssertEqual(wide13.fit, 1_366.0 / 1_400, accuracy: 1e-9)
        XCTAssertEqual(ZoomReset.target(.month, bounds: wide13), 1_366.0 / 1_400, accuracy: 1e-9, "one month across")
        XCTAssertGreaterThan(ZoomReset.target(.month, bounds: wide13), wide13.open + 0.1, "not the opening zoom")
        let wide11 = ZoomPolicy.bounds(.month, overview: ZoomPolicy.baseSize(.month), viewport: CGSize(width: 1_210, height: 640))
        XCTAssertEqual(ZoomReset.target(.month, bounds: wide11), 1_210.0 / 1_400, accuracy: 1e-9)
        let phone = ZoomPolicy.bounds(.month, overview: ZoomPolicy.baseSize(.month), viewport: CGSize(width: 750, height: 230))
        XCTAssertEqual(ZoomReset.target(.month, bounds: phone), 750.0 / 1_400, accuracy: 1e-9)
        XCTAssertGreaterThan(ZoomReset.target(.month, bounds: phone) / phone.open, 2, "about 2.45 times the opening zoom")
        let portrait = ZoomPolicy.bounds(.month, overview: ZoomPolicy.baseSize(.month), viewport: CGSize(width: 834, height: 955))
        XCTAssertEqual(portrait.open, portrait.fit, accuracy: 1e-9, "width-bound")
        XCTAssertEqual(ZoomReset.target(.month, bounds: portrait), 834.0 / 1_400, accuracy: 1e-9, "where open is fit: the same zoom")

        let high = ZoomPolicy.Bounds(fit: 5, open: 0.5, min: 0.4, max: 2)
        let low = ZoomPolicy.Bounds(fit: 0.1, open: 0.5, min: 0.4, max: 2)
        let notANumber = ZoomPolicy.Bounds(fit: .nan, open: 0.5, min: 0.4, max: 2)
        XCTAssertEqual(ZoomReset.target(.month, bounds: high), 2, accuracy: 1e-12)
        XCTAssertEqual(ZoomReset.target(.month, bounds: low), 0.4, accuracy: 1e-12)
        XCTAssertEqual(ZoomReset.target(.month, bounds: notANumber), 0.4, accuracy: 1e-12)

        let year = ZoomPolicy.bounds(.year, overview: ZoomPolicy.baseSize(.year), viewport: CGSize(width: 834, height: 955))
        let capped = ZoomPolicy.cappedBounds(.year, overview: ZoomPolicy.baseSize(.year), viewport: CGSize(width: 874, height: 205),
                                             maxVisiblePages: 3)
        if SpanKinds.joined.contains(.year) {
            XCTAssertEqual(ZoomReset.target(.year, bounds: year), 834.0 / 1_400, accuracy: 1e-9)
            XCTAssertEqual(ZoomReset.target(.year, bounds: capped) / capped.open, 3, accuracy: 1e-9, "3 times the cap")
            XCTAssertEqual(ZoomReset.target(.year, bounds: high), 2, accuracy: 1e-12)
        } else {
            XCTAssertEqual(ZoomReset.target(.year, bounds: year), 955.0 / 1_860, accuracy: 1e-9, "its opening zoom")
            XCTAssertEqual(ZoomReset.target(.year, bounds: capped), capped.open, accuracy: 1e-9)
            XCTAssertEqual(ZoomReset.target(.year, bounds: high), 0.5, accuracy: 1e-12)
        }
    }

    /// MS4, §6.1, §6.4: the month's state is kept on this device as the week's ("zoomFit.month", true removes the stored ratio,
    /// false removes the flag and leaves the ratio); 1.4.1's and 1.4.2's 等倍 of a month wrote ratio 1 and no flag, so a month
    /// pressed then opens at its opening zoom. The year: as `SpanKinds.joined` says.
    func testAppSettingsKeepsTheMonthsFit() {
        XCTAssertEqual(AppSettings.zoomFitKey(.month), "zoomFit.month")
        XCTAssertFalse(AppSettings.zoomFit(for: .month), "not at 等倍 until written")
        AppSettings.setZoomRatio(1, for: .month)
        XCTAssertFalse(AppSettings.zoomFit(for: .month), "1.4.2's 等倍 of a month (ratio 1, no flag): the opening zoom")
        AppSettings.setZoomRatio(1_366.0 / 1_400 / (830.0 / 1_050), for: .month)
        AppSettings.setZoomFit(true, for: .month)
        XCTAssertTrue(AppSettings.zoomFit(for: .month))
        XCTAssertEqual(AppSettings.defaults.object(forKey: "zoomFit.month") as? Bool, true)
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.zoomRatioKey(.month)), "true removes the ratio")
        XCTAssertFalse(AppSettings.zoomFit(for: .week), "one key per kind")
        // A real pinch afterwards (to 1.5 times the opening zoom): its ratio, then fit false.
        AppSettings.setZoomRatio(1.5, for: .month)
        AppSettings.setZoomFit(false, for: .month)
        XCTAssertFalse(AppSettings.zoomFit(for: .month))
        XCTAssertNil(AppSettings.defaults.object(forKey: "zoomFit.month"), "a pinch removes the flag")
        XCTAssertEqual(AppSettings.zoomRatio(for: .month), 1.5, accuracy: 1e-9, "false leaves the pinch's ratio")
        AppSettings.setZoomRatio(1, for: .month)

        AppSettings.setZoomFit(true, for: .year)
        XCTAssertEqual(AppSettings.zoomFit(for: .year), SpanKinds.joined.contains(.year), "the year")
        XCTAssertEqual(AppSettings.defaults.object(forKey: "zoomFit.year") != nil, SpanKinds.joined.contains(.year))
    }

    /// MS4, §6.5: in screenshot mode `--screenshot-zoom fit` opens the month at 等倍 whatever is stored (the memory is not read
    /// there), also the month under a sheet; without it not; in normal use the stored value. The year: as the set says.
    func testScreenshotZoomFitReachesTheMonth() throws {
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month"]
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let fit = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-zoom", "fit"]))
        XCTAssertEqual(fit.page, .month)
        for stored in [false, true] {
            XCTAssertTrue(ScreenshotMode.zoomFit(fit, kind: .month, stored: stored), "--screenshot-zoom fit, \(stored) stored")
            XCTAssertFalse(ScreenshotMode.zoomFit(plain, kind: .month, stored: stored), "without the argument, \(stored) stored")
            XCTAssertEqual(ScreenshotMode.zoomFit(nil, kind: .month, stored: stored), stored, "normal use")
            XCTAssertEqual(ScreenshotMode.zoomFit(fit, kind: .year, stored: stored), SpanKinds.joined.contains(.year), "the year")
        }
        let sheet = try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", "settings",
                                                        "--screenshot-zoom", "fit"]))
        XCTAssertEqual(sheet.page, .month)
        XCTAssertTrue(ScreenshotMode.zoomFit(sheet, kind: sheet.page, stored: false), "the month under a sheet")
    }
}
