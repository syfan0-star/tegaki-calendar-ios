import Access
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

    // MARK: 1.1.1 (docs/R1_1_1.md)

    /// The pinch hint's key, and `hasPinched`: some page kind stored zoomed in. A ratio of 1 (nothing
    /// stored) is not a pinch.
    func testPinchHintKeys() {
        XCTAssertEqual(AppSettings.pinchHintShownKey, "hint.pinchShown")
        XCTAssertFalse(AppSettings.defaults.bool(forKey: AppSettings.pinchHintShownKey), "default false")
        XCTAssertFalse(AppSettings.hasPinched)
        AppSettings.setZoomRatio(1, for: .year)
        XCTAssertFalse(AppSettings.hasPinched, "1 is the opening zoom")
        for kind in PageKind.allCases {
            AppSettings.setZoomRatio(1.5, for: kind)
            XCTAssertTrue(AppSettings.hasPinched, "\(kind)")
            AppSettings.setZoomRatio(1, for: kind)
            XCTAssertFalse(AppSettings.hasPinched, "\(kind)")
        }
        // A bad value on disk reads as 1.
        AppSettings.defaults.set(0.5, forKey: "zoomRatio.month")
        XCTAssertFalse(AppSettings.hasPinched)
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
                    ToolbarPalette.markerColorKey, AppSettings.allowFingerKey, AppSettings.eraseInkAfterConvertKey,
                    AppSettings.handKey, AppSettings.paletteEdgeKey, AppSettings.zoomFitKey(.week), AppSettings.zoomFitKey(.day)]
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

    /// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.1, §4.10, §6.3, 0e-12, 0e-21): 「利き手」 and the toolbar's edge in
    /// `testToolbarKeys`'s shape: the right hand and the bottom until written, written as their raw values, and anything else
    /// (a string or not) the right hand and the bottom. Each is its own key; neither writes the round button's corner.
    func testHandAndPaletteKeys() {
        XCTAssertEqual(AppSettings.handKey, "layout.hand")
        XCTAssertFalse(AppSettings.handKey.hasPrefix("toolbar."), "the hand is not the toolbar's")

        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.handKey))
        XCTAssertEqual(AppSettings.hand, .right)
        AppSettings.hand = .left
        XCTAssertEqual(AppSettings.hand, .left)
        XCTAssertEqual(AppSettings.defaults.string(forKey: "layout.hand"), "left", "a String, as `@AppStorage` reads it")
        AppSettings.hand = .right
        XCTAssertEqual(AppSettings.defaults.string(forKey: "layout.hand"), "right")
        AppSettings.defaults.set("left", forKey: "layout.hand")
        XCTAssertEqual(AppSettings.hand, .left, "as `@AppStorage` writes it")
        for unknown in ["middle", "", "LEFT", "trailing"] {
            AppSettings.defaults.set(unknown, forKey: "layout.hand")
            XCTAssertEqual(AppSettings.hand, .right, "\(unknown) → right")
        }
        AppSettings.defaults.set(3, forKey: "layout.hand")
        XCTAssertEqual(AppSettings.hand, .right, "not a string → right")
        // The hand is its own key: writing it leaves the round button's corner alone (the settings write that one
        // themselves, once, `SettingsScreen.handChanged`).
        AppSettings.hand = .left
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.toolbarEdgeKey))
        XCTAssertEqual(AppSettings.toolbarEdge, .leading)

        // The toolbar's edge (D1b): the bottom until written; its raw value as `@AppStorage` reads it; anything else the bottom.
        XCTAssertEqual(AppSettings.paletteEdgeKey, "toolbar.paletteEdge")
        XCTAssertNotEqual(AppSettings.paletteEdgeKey, AppSettings.toolbarEdgeKey, "not the round button's corner")
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.paletteEdgeKey))
        XCTAssertEqual(AppSettings.paletteEdge, .bottom)
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.paletteEdgeKey), "reading the default writes nothing")
        for edge in PaletteEdge.allCases {
            AppSettings.paletteEdge = edge
            XCTAssertEqual(AppSettings.paletteEdge, edge)
            XCTAssertEqual(AppSettings.defaults.string(forKey: "toolbar.paletteEdge"), edge.rawValue, "a String, as `@AppStorage` reads it")
        }
        XCTAssertEqual(PaletteEdge.allCases.map(\.rawValue), ["bottom", "top", "left", "right"])
        AppSettings.defaults.set("left", forKey: "toolbar.paletteEdge")
        XCTAssertEqual(AppSettings.paletteEdge, .left, "as `@AppStorage` writes it")
        for unknown in ["middle", "", "LEFT", "leading", "trailing"] {
            AppSettings.defaults.set(unknown, forKey: "toolbar.paletteEdge")
            XCTAssertEqual(AppSettings.paletteEdge, .bottom, "\(unknown) → bottom")
        }
        AppSettings.defaults.set(2, forKey: "toolbar.paletteEdge")
        XCTAssertEqual(AppSettings.paletteEdge, .bottom, "not a string → bottom")
        // The edge leaves the hand and the corner alone (a drop on a side writes the corner itself, `paletteDropped`).
        XCTAssertEqual(AppSettings.hand, .left)
        XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.toolbarEdgeKey))
    }

    /// 1.4.1's rework (docs/R1_4_1_CONTRACT.md §16.3.4, §16.6): 等倍 of the week and the day is kept as a state, one `Bool` per
    /// kind ("zoomFit.week" / "zoomFit.day"). True writes it and removes the kind's stored ratio (after 等倍 the canvas reports
    /// the ratio of the fit to the opening zoom first, then fit true, so the flag alone says how the kind opens); false (a
    /// real pinch afterwards, its ratio already stored) removes the flag and leaves the ratio. A month or a year never keeps
    /// it (its 等倍 is ratio 1), and neither call touches its ratio. The flag is neither a pinch (`hasPinched`) nor an earlier
    /// version's key (`isExistingUser`). Mutation MS3 (true not removing the ratio, §16.7) fails here.
    func testZoomFitReplacesTheRatio() {
        XCTAssertEqual(AppSettings.zoomFitKey(.week), "zoomFit.week")
        XCTAssertEqual(AppSettings.zoomFitKey(.day), "zoomFit.day")
        XCTAssertEqual(Set(PageKind.allCases.map(AppSettings.zoomFitKey)).count, 4, "one key per kind")
        for kind in PageKind.allCases {
            XCTAssertNotEqual(AppSettings.zoomFitKey(kind), AppSettings.zoomRatioKey(kind), "\(kind)")
            XCTAssertFalse(AppSettings.zoomFit(for: kind), "\(kind): not at 等倍 until written")
            XCTAssertNil(AppSettings.defaults.object(forKey: AppSettings.zoomFitKey(kind)), "\(kind): reading writes nothing")
        }

        for kind in [PageKind.week, .day] {
            let key = AppSettings.zoomFitKey(kind)
            let ratioKey = AppSettings.zoomRatioKey(kind)
            // 等倍: the canvas reports the ratio of the fit (an iPad Pro 11's portrait week: 1.198), then fit true.
            AppSettings.setZoomRatio(1.198, for: kind)
            XCTAssertNotNil(AppSettings.defaults.object(forKey: ratioKey), "\(kind): the ratio first")
            AppSettings.setZoomFit(true, for: kind)
            XCTAssertTrue(AppSettings.zoomFit(for: kind), "\(kind)")
            XCTAssertTrue(AppSettings.defaults.bool(forKey: key), "\(kind): a Bool")
            XCTAssertNil(AppSettings.defaults.object(forKey: ratioKey), "\(kind): true removes the ratio")
            XCTAssertEqual(AppSettings.zoomRatio(for: kind), 1, "\(kind)")
            // 等倍 once more (or a page opened at it, the first layout's report): the same.
            AppSettings.setZoomRatio(1.198, for: kind)
            AppSettings.setZoomFit(true, for: kind)
            XCTAssertTrue(AppSettings.zoomFit(for: kind), "\(kind)")
            XCTAssertNil(AppSettings.defaults.object(forKey: ratioKey), "\(kind)")
            // A real pinch afterwards: its ratio, then fit false.
            AppSettings.setZoomRatio(2.5, for: kind)
            AppSettings.setZoomFit(false, for: kind)
            XCTAssertFalse(AppSettings.zoomFit(for: kind), "\(kind)")
            XCTAssertNil(AppSettings.defaults.object(forKey: key), "\(kind): false removes the key")
            XCTAssertEqual(AppSettings.zoomRatio(for: kind), 2.5, "\(kind): false leaves the ratio")
            // A pinch back to the opening zoom: ratio 1 and false remove both.
            AppSettings.setZoomRatio(1, for: kind)
            AppSettings.setZoomFit(false, for: kind)
            XCTAssertNil(AppSettings.defaults.object(forKey: key), "\(kind)")
            XCTAssertNil(AppSettings.defaults.object(forKey: ratioKey), "\(kind)")
        }
        // One key per kind.
        AppSettings.setZoomRatio(2, for: .day)
        AppSettings.setZoomFit(true, for: .week)
        XCTAssertTrue(AppSettings.zoomFit(for: .week))
        XCTAssertFalse(AppSettings.zoomFit(for: .day), "the day is its own")
        XCTAssertEqual(AppSettings.zoomRatio(for: .day), 2, "the day's ratio stays")
        AppSettings.setZoomFit(false, for: .week)
        AppSettings.setZoomRatio(1, for: .day)

        // A month or a year: never a state of its own.
        for kind in [PageKind.month, .year] {
            let key = AppSettings.zoomFitKey(kind)
            AppSettings.setZoomRatio(2, for: kind)
            AppSettings.setZoomFit(true, for: kind)
            XCTAssertFalse(AppSettings.zoomFit(for: kind), "\(kind)")
            XCTAssertNil(AppSettings.defaults.object(forKey: key), "\(kind): nothing written")
            XCTAssertEqual(AppSettings.zoomRatio(for: kind), 2, "\(kind): the ratio stays")
            AppSettings.setZoomFit(false, for: kind)
            XCTAssertEqual(AppSettings.zoomRatio(for: kind), 2, "\(kind)")
            // A flag on disk (written by something else) does not count either.
            AppSettings.defaults.set(true, forKey: key)
            XCTAssertFalse(AppSettings.zoomFit(for: kind), "\(kind): read as false")
            AppSettings.defaults.removeObject(forKey: key)
            AppSettings.setZoomRatio(1, for: kind)
        }

        // Not a pinch (1.1.1's hint is decided as before, §16.3.4) and not an earlier version's key (1.2).
        AppSettings.setZoomFit(true, for: .day)
        AppSettings.setZoomFit(true, for: .week)
        XCTAssertFalse(AppSettings.hasPinched)
        XCTAssertFalse(AppSettings.isExistingUser(AppSettings.defaults))
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

    // MARK: 1.2 (docs/M7B_CONTRACT.md §5.6, §10.3)

    func testHolidayAndWeekStartKeys() {
        XCTAssertEqual(AppSettings.holidaySettingKey, "holidays.setting")
        XCTAssertEqual(AppSettings.weekStartKey, "weekStart.setting")
        XCTAssertEqual(AppSettings.weekStartLastAutoKey, "weekStart.lastAuto")
        XCTAssertEqual(AppSettings.weekStartDataCheckedKey, "weekStart.dataChecked")
        XCTAssertEqual(AppSettings.weekStartHiddenNoticedKey, "weekStart.hiddenNoticed")
        XCTAssertFalse(AppSettings.weekStartDataChecked)
        AppSettings.weekStartDataChecked = true
        XCTAssertTrue(AppSettings.weekStartDataChecked)
    }

    /// Someone who used an earlier version: any of the three keys, and not the 1.1.1 hint alone (§1.5).
    func testExistingUserIsAnyOfTheThreeKeys() {
        XCTAssertFalse(AppSettings.isExistingUser(AppSettings.defaults))
        AppSettings.defaults.set(true, forKey: AppSettings.pinchHintShownKey)
        XCTAssertFalse(AppSettings.isExistingUser(AppSettings.defaults), "the hint says nothing")
        for key in [AppSettings.onboardingDoneKey, AppSettings.lastKindKey, AppSettings.allowFingerChosenKey] {
            AppSettings.defaults.set(true, forKey: key)
            XCTAssertTrue(AppSettings.isExistingUser(AppSettings.defaults), key)
            AppSettings.defaults.removeObject(forKey: key)
        }
    }

    /// Per page and form, oldest first, at most the same 500 as the stroke budget's notices (D17).
    func testWeekStartHiddenNoticed() {
        XCTAssertFalse(AppSettings.weekStartHiddenNoticed("m1-2026-11", .sunday))
        AppSettings.markWeekStartHiddenNoticed("m1-2026-11", .sunday)
        XCTAssertTrue(AppSettings.weekStartHiddenNoticed("m1-2026-11", .sunday))
        XCTAssertFalse(AppSettings.weekStartHiddenNoticed("m1-2026-11", .monday), "the other form is another notice")
        XCTAssertFalse(AppSettings.weekStartHiddenNoticed("m1-2026-12", .sunday))
        AppSettings.markWeekStartHiddenNoticed("m1-2026-11", .sunday)
        XCTAssertEqual(AppSettings.defaults.stringArray(forKey: AppSettings.weekStartHiddenNoticedKey)?.count, 1, "once")
        for i in 0..<(AppSettings.strokeBudgetNoticedLimit + 5) {
            AppSettings.markWeekStartHiddenNoticed("m1-page\(i)", .monday)
        }
        XCTAssertEqual(AppSettings.defaults.stringArray(forKey: AppSettings.weekStartHiddenNoticedKey)?.count, AppSettings.strokeBudgetNoticedLimit)
        XCTAssertFalse(AppSettings.weekStartHiddenNoticed("m1-2026-11", .sunday), "the oldest is dropped")
        XCTAssertTrue(AppSettings.weekStartHiddenNoticed("m1-page\(AppSettings.strokeBudgetNoticedLimit + 4)", .monday))
    }

    // MARK: 1.2.1 (docs/R1_2_1.md §2.6)

    /// The rating prompt's record: five keys, an empty record from an empty suite, what is written is read
    /// back, a day that does not read is nil, a negative count is 0, a nil field removes its key, and the
    /// review keys alone do not make an earlier user.
    func testReviewRecordKeys() {
        XCTAssertEqual([AppSettings.reviewFirstUseDayKey, AppSettings.reviewInkDaysKey, AppSettings.reviewLastInkDayKey,
                        AppSettings.reviewLastRequestVersionKey, AppSettings.reviewLastRequestDayKey],
                       ["review.firstUseDay", "review.inkDays", "review.lastInkDay", "review.lastRequestVersion", "review.lastRequestDay"])
        XCTAssertEqual(AppSettings.reviewRecord, ReviewRecord(), "nothing stored")

        let record = ReviewRecord(firstUseDay: DayKey(year: 2026, month: 11, day: 10), inkDays: 3,
                                  lastInkDay: DayKey(year: 2026, month: 11, day: 14),
                                  lastRequestVersion: "1.2.1", lastRequestDay: DayKey(year: 2026, month: 11, day: 17))
        AppSettings.reviewRecord = record
        XCTAssertEqual(AppSettings.reviewRecord, record, "written and read back")
        XCTAssertEqual(AppSettings.defaults.string(forKey: "review.firstUseDay"), "2026-11-10")
        XCTAssertEqual(AppSettings.defaults.integer(forKey: "review.inkDays"), 3)
        XCTAssertEqual(AppSettings.defaults.string(forKey: "review.lastInkDay"), "2026-11-14")
        XCTAssertEqual(AppSettings.defaults.string(forKey: "review.lastRequestVersion"), "1.2.1")
        XCTAssertEqual(AppSettings.defaults.string(forKey: "review.lastRequestDay"), "2026-11-17")

        // Values that do not read.
        AppSettings.defaults.set("2026-02-30", forKey: "review.firstUseDay")
        AppSettings.defaults.set("x", forKey: "review.lastInkDay")
        AppSettings.defaults.set(-3, forKey: "review.inkDays")
        AppSettings.defaults.set("", forKey: "review.lastRequestVersion")
        let broken = AppSettings.reviewRecord
        XCTAssertNil(broken.firstUseDay, "2026-02-30 is not a day")
        XCTAssertNil(broken.lastInkDay, "x is not a day")
        XCTAssertEqual(broken.inkDays, 0, "a negative count is 0")
        XCTAssertNil(broken.lastRequestVersion, "an empty version is none")
        XCTAssertEqual(broken.lastRequestDay, DayKey(year: 2026, month: 11, day: 17), "the other fields stay")

        // nil removes the key.
        AppSettings.reviewRecord = ReviewRecord(inkDays: -3)
        for key in ["review.firstUseDay", "review.lastInkDay", "review.lastRequestVersion", "review.lastRequestDay"] {
            XCTAssertNil(AppSettings.defaults.object(forKey: key), key)
        }
        XCTAssertEqual(AppSettings.defaults.integer(forKey: "review.inkDays"), 0, "a negative count is written as 0")

        // 1.2's test of an earlier user does not change.
        AppSettings.reviewRecord = record
        XCTAssertFalse(AppSettings.isExistingUser(AppSettings.defaults), "the review keys say nothing about an earlier version")
    }
}
