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

    // MARK: M5 (M5_CONTRACT §4.2 / §7.6)

    /// The first-launch paywall flag: false until written, written back as a `Bool`, one key.
    /// `CalendarRootScreen` keeps it with `@AppStorage`; the cached access state is the Store layer's
    /// own key (`UserDefaultsAccessCache.defaultKey`, M5-34), not one of these.
    func testPaywallShownAfterOnboarding() {
        let key = AppSettings.paywallShownAfterOnboardingKey
        XCTAssertEqual(key, "paywallShownAfterOnboarding")
        XCTAssertNil(AppSettings.defaults.object(forKey: key), "nothing stored")
        XCTAssertFalse(AppSettings.defaults.bool(forKey: key), "default false")
        AppSettings.defaults.set(true, forKey: key)
        XCTAssertTrue(AppSettings.defaults.bool(forKey: key))
        AppSettings.defaults.set(false, forKey: key)
        XCTAssertFalse(AppSettings.defaults.bool(forKey: key))
        XCTAssertNotNil(AppSettings.defaults.object(forKey: key), "false is a written value, not the default")
        XCTAssertNotEqual(key, AppSettings.onboardingDoneKey)
        XCTAssertNotEqual(key, UserDefaultsAccessCache.defaultKey)
    }

    // MARK: 1.1 (M7A_CONTRACT §2.3 / §2.6 / §5.2 / §7.2)

    /// 設定 › 入力 「消しゴムで消したらペンに戻る」: on until turned off (a missing value is true,
    /// like `eraseInkAfterConvert`), and what is written is read back.
    func testEraserAutoReturnDefaultsToOn() {
        let key = AppSettings.eraserAutoReturnKey
        XCTAssertEqual(key, "eraserAutoReturn")
        XCTAssertNil(AppSettings.defaults.object(forKey: key), "nothing stored")
        XCTAssertTrue(AppSettings.eraserAutoReturn, "missing → on")
        AppSettings.eraserAutoReturn = false
        XCTAssertFalse(AppSettings.eraserAutoReturn)
        XCTAssertNotNil(AppSettings.defaults.object(forKey: key), "false is a written value, not the default")
        XCTAssertFalse(AppSettings.defaults.bool(forKey: key))
        AppSettings.eraserAutoReturn = true
        XCTAssertTrue(AppSettings.eraserAutoReturn)
        XCTAssertTrue(AppSettings.defaults.bool(forKey: key))
        // Written by `@AppStorage` (the same key in `CalendarRootScreen` and `SettingsScreen`).
        AppSettings.defaults.set(false, forKey: "eraserAutoReturn")
        XCTAssertFalse(AppSettings.eraserAutoReturn)
        AppSettings.defaults.removeObject(forKey: key)
        XCTAssertTrue(AppSettings.eraserAutoReturn, "removed → on again")
    }

    /// The collapsed toolbar and the dock's corner (§2.3): the expanded bar and the bottom left until
    /// written; an unknown corner reads as the bottom left.
    func testToolbarKeys() {
        XCTAssertEqual(AppSettings.toolbarCollapsedKey, "toolbar.collapsed")
        XCTAssertEqual(AppSettings.toolbarEdgeKey, "toolbar.collapsedEdge")
        let keys = [AppSettings.toolbarCollapsedKey, AppSettings.toolbarEdgeKey, AppSettings.eraserAutoReturnKey,
                    AppSettings.strokeBudgetNoticedKey, ToolbarPalette.penColorKey, ToolbarPalette.penWidthKey,
                    ToolbarPalette.markerColorKey, AppSettings.allowFingerKey, AppSettings.eraseInkAfterConvertKey]
        XCTAssertEqual(Set(keys).count, keys.count, "every key is its own")

        // Collapsed: false (expanded) until written.
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.toolbarCollapsedKey))
        XCTAssertFalse(AppSettings.toolbarCollapsed)
        XCTAssertEqual(ToolbarLogic.startMode(collapsedStored: AppSettings.toolbarCollapsed), .expanded)
        AppSettings.toolbarCollapsed = true
        XCTAssertTrue(AppSettings.toolbarCollapsed)
        XCTAssertTrue(AppSettings.defaults.bool(forKey: "toolbar.collapsed"), "a Bool, as `@AppStorage` reads it")
        XCTAssertEqual(ToolbarLogic.startMode(collapsedStored: AppSettings.toolbarCollapsed), .collapsed)
        AppSettings.toolbarCollapsed = false
        XCTAssertFalse(AppSettings.toolbarCollapsed)

        // Edge: leading until written; written as its raw value; anything else is leading.
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.toolbarEdgeKey))
        XCTAssertEqual(AppSettings.toolbarEdge, .leading)
        AppSettings.toolbarEdge = .trailing
        XCTAssertEqual(AppSettings.toolbarEdge, .trailing)
        XCTAssertEqual(AppSettings.defaults.string(forKey: "toolbar.collapsedEdge"), "trailing")
        AppSettings.toolbarEdge = .leading
        XCTAssertEqual(AppSettings.defaults.string(forKey: "toolbar.collapsedEdge"), "leading")
        AppSettings.defaults.set("trailing", forKey: "toolbar.collapsedEdge")
        XCTAssertEqual(AppSettings.toolbarEdge, .trailing, "as `@AppStorage` writes it")
        for unknown in ["middle", "", "TRAILING", "bottomTrailing"] {
            AppSettings.defaults.set(unknown, forKey: "toolbar.collapsedEdge")
            XCTAssertEqual(AppSettings.toolbarEdge, .leading, "\(unknown) → leading")
        }
        AppSettings.defaults.set(3, forKey: "toolbar.collapsedEdge")
        XCTAssertEqual(AppSettings.toolbarEdge, .leading, "not a string → leading")
    }

    /// The pages whose 15,000-stroke notice this device showed (§5.2, M7A-7): once per page, at most
    /// 500 ids, the oldest dropped first.
    func testStrokeBudgetNoticed() {
        let key = AppSettings.strokeBudgetNoticedKey
        XCTAssertEqual(key, "strokeBudget.noticedPages")
        XCTAssertEqual(AppSettings.strokeBudgetNoticedLimit, 500)
        XCTAssertFalse(AppSettings.strokeBudgetNoticed("m1-2026-10"))
        XCTAssertNil(AppSettings.defaults.object(forKey: key), "reading writes nothing")

        AppSettings.markStrokeBudgetNoticed("m1-2026-10")
        XCTAssertTrue(AppSettings.strokeBudgetNoticed("m1-2026-10"))
        XCTAssertFalse(AppSettings.strokeBudgetNoticed("m1-2026-11"), "per page")
        XCTAssertFalse(AppSettings.strokeBudgetNoticed("m1-2026"), "the whole id, not a prefix")
        AppSettings.markStrokeBudgetNoticed("m1-2026-10")
        XCTAssertEqual(AppSettings.defaults.stringArray(forKey: key), ["m1-2026-10"], "recorded once")

        // 500 more pages: the first one is dropped, the newest 500 stay in order.
        let more = (0..<500).map { "d-2026-01-01-\($0)" }
        for id in more {
            AppSettings.markStrokeBudgetNoticed(id)
        }
        XCTAssertFalse(AppSettings.strokeBudgetNoticed("m1-2026-10"), "the oldest is dropped")
        XCTAssertEqual(AppSettings.defaults.stringArray(forKey: key), more)
        AppSettings.markStrokeBudgetNoticed("y-2026")
        let stored = AppSettings.defaults.stringArray(forKey: key) ?? []
        XCTAssertEqual(stored.count, 500)
        XCTAssertEqual(stored.first, more[1])
        XCTAssertEqual(stored.last, "y-2026")
        XCTAssertFalse(AppSettings.strokeBudgetNoticed(more[0]))
        XCTAssertTrue(AppSettings.strokeBudgetNoticed(more[1]))
        XCTAssertTrue(AppSettings.strokeBudgetNoticed("y-2026"))

        // A value of another type on disk reads as an empty list and is replaced on the next mark.
        AppSettings.defaults.set("m1-2026-10", forKey: key)
        XCTAssertFalse(AppSettings.strokeBudgetNoticed("m1-2026-10"))
        AppSettings.markStrokeBudgetNoticed("w-2026-10-05")
        XCTAssertEqual(AppSettings.defaults.stringArray(forKey: key), ["w-2026-10-05"])
    }
}
