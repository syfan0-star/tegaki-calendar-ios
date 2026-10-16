import Layout
import XCTest
@testable import TegakiCalendar

/// The stored zoom ratio of each page kind (M4C contract §1.5 / §7.3, D4): one key per kind, 1 (the
/// overview) when nothing is stored, normalised with `ZoomPolicy.sanitizedRatio` on both sides, and
/// 1 removes the key. The tests point `AppSettings.defaults` at a scratch suite.
final class AppSettingsTests: XCTestCase {
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "test-\(UUID())"
        AppSettings.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() {
        AppSettings.defaults.removePersistentDomain(forName: suiteName)
        AppSettings.defaults = .standard
        super.tearDown()
    }

    func testZoomRatioKeys() {
        XCTAssertEqual(AppSettings.zoomRatioKey(.month), "zoomRatio.month")
        XCTAssertEqual(AppSettings.zoomRatioKey(.week), "zoomRatio.week")
        XCTAssertEqual(AppSettings.zoomRatioKey(.day), "zoomRatio.day")
        XCTAssertEqual(AppSettings.zoomRatioKey(.year), "zoomRatio.year")
        XCTAssertEqual(Set(PageKind.allCases.map(AppSettings.zoomRatioKey)).count, 4, "one key per kind")
    }

    func testMissingRatioIsTheOverview() {
        for kind in PageKind.allCases {
            XCTAssertEqual(AppSettings.zoomRatio(for: kind), 1, "\(kind)")
            XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.zoomRatioKey(kind)))
        }
    }

    func testSetAndReadPerKind() {
        AppSettings.setZoomRatio(2, for: .week)
        XCTAssertEqual(AppSettings.zoomRatio(for: .week), 2)
        XCTAssertEqual(AppSettings.defaults.double(forKey: "zoomRatio.week"), 2)
        // The other kinds are untouched (the ratio is per kind, M4C-17).
        XCTAssertEqual(AppSettings.zoomRatio(for: .month), 1)
        XCTAssertEqual(AppSettings.zoomRatio(for: .day), 1)
        XCTAssertEqual(AppSettings.zoomRatio(for: .year), 1)
        XCTAssertNil(AppSettings.defaults.object(forKey: "zoomRatio.month"))

        AppSettings.setZoomRatio(2.9257, for: .month)
        XCTAssertEqual(AppSettings.zoomRatio(for: .month), 2.9257, accuracy: 1e-9)
        XCTAssertEqual(AppSettings.zoomRatio(for: .week), 2, "still 2")

        // A new value replaces the old one.
        AppSettings.setZoomRatio(4, for: .week)
        XCTAssertEqual(AppSettings.zoomRatio(for: .week), 4)
    }

    func testTheOverviewRemovesTheKey() {
        AppSettings.setZoomRatio(2, for: .week)
        XCTAssertNotNil(AppSettings.defaults.object(forKey: "zoomRatio.week"))
        AppSettings.setZoomRatio(1, for: .week)
        XCTAssertNil(AppSettings.defaults.object(forKey: "zoomRatio.week"), "1 removes the key")
        XCTAssertEqual(AppSettings.zoomRatio(for: .week), 1)
        // 1 ± 0.001 is the overview too (`sanitizedRatio`).
        AppSettings.setZoomRatio(2, for: .day)
        AppSettings.setZoomRatio(1.0005, for: .day)
        XCTAssertNil(AppSettings.defaults.object(forKey: "zoomRatio.day"))
        XCTAssertEqual(AppSettings.zoomRatio(for: .day), 1)
    }

    func testBadValuesAreTheOverview() {
        for bad: CGFloat in [.nan, 0.5, 100, 0, -2, .infinity, 65] {
            AppSettings.setZoomRatio(2, for: .year)
            AppSettings.setZoomRatio(bad, for: .year)
            XCTAssertEqual(AppSettings.zoomRatio(for: .year), 1, "\(bad) is stored as the overview")
            XCTAssertNil(AppSettings.defaults.object(forKey: "zoomRatio.year"), "\(bad) removes the key")
        }
        // The largest ratio a page can store is kept; anything above reads as 1.
        AppSettings.setZoomRatio(ZoomPolicy.maxStoredRatio, for: .year)
        XCTAssertEqual(AppSettings.zoomRatio(for: .year), 64)
        // A stored value that is bad on disk (written by something else) reads as 1 too.
        AppSettings.defaults.set(0.5, forKey: "zoomRatio.month")
        XCTAssertEqual(AppSettings.zoomRatio(for: .month), 1)
        AppSettings.defaults.set(Double.nan, forKey: "zoomRatio.week")
        XCTAssertEqual(AppSettings.zoomRatio(for: .week), 1)
        AppSettings.defaults.set("abc", forKey: "zoomRatio.day")
        XCTAssertEqual(AppSettings.zoomRatio(for: .day), 1, "not a number → double(forKey:) 0 → 1")
        AppSettings.defaults.set(1000.0, forKey: "zoomRatio.year")
        XCTAssertEqual(AppSettings.zoomRatio(for: .year), 1)
    }
}
