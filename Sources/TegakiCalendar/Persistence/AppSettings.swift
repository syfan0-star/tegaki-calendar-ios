import Foundation
import Layout

/// The app's UserDefaults keys and defaults in one place (M3b contract §4.0). Screenshot mode never
/// reads or writes them (the callers check `ScreenshotMode.isActive`). M4c adds the zoom ratio of
/// each page kind (`zoomRatio.<kind>`, D4): the zoom relative to the page's opening zoom
/// (`ZoomPolicy.Bounds.open` since 1.1.1; the overview `fitAll` before), written only at the end of a
/// pinch (`InkCanvasView.onZoomRatioChange`), read when a page of that kind opens. M5 adds one flag,
/// `paywallShownAfterOnboardingKey` (M5_CONTRACT §4.2); the cached access state is kept by the Store
/// layer itself (`UserDefaultsAccessCache.defaultKey`, M5-34), not here. 1.1 (docs/M7A_CONTRACT.md
/// §2.3, §2.6, §5.2) adds four: the collapsed toolbar and its corner, the eraser's return to the pen,
/// and the pages whose 15,000-stroke notice was shown. 1.1.1 (docs/R1_1_1.md) adds one: the one-time
/// hint that two fingers zoom. 1.2 (docs/M7B_CONTRACT.md §5.6, §10.3) adds the holidays to show and the
/// week start with its three memories. All of them stay on this device (UserDefaults is not synced to
/// iCloud; D16, 0-21, 0-45).
enum AppSettings {
    /// `String?`: the `calendarIdentifier` new events go to; nil → `EKEventStore.defaultCalendarForNewEvents`.
    static let defaultCalendarIdKey = "defaultCalendarId"
    /// `Bool`, default true (the owner's decision): erase the handwriting after it became an event.
    static let eraseInkAfterConvertKey = "eraseInkAfterConvert"
    /// `Bool`, existing: iPad false, iPhone / Mac true (decided once through `allowFingerChosenKey`).
    static let allowFingerKey = "allowFingerDrawing"
    static let allowFingerChosenKey = "allowFingerDrawingChosen"
    /// Existing: the last shown page kind; missing → iPad `.month`, iPhone `.week` (DESIGN §2.11).
    static let lastKindKey = "lastPageKind"
    /// Existing: the last focus day as "YYYY-MM-DD".
    static let lastFocusKey = "lastFocusDate"
    /// Existing (`EventStoreModel.hiddenKey`).
    static let hiddenCalendarIdsKey = "hiddenCalendarIds"
    static let onboardingDoneKey = "onboardingDone"
    /// M5 (M5_CONTRACT §4.2, M5-33): `Bool`, default false. True once the first-launch paywall was
    /// actually shown after the onboarding, or once the first refresh found a subscriber (it is then
    /// never shown). Left false when the first refresh did not finish, the store was unreachable or
    /// the prices were missing, so the next launch tries again. `CalendarRootScreen` reads it with
    /// `@AppStorage`.
    static let paywallShownAfterOnboardingKey = "paywallShownAfterOnboarding"
    // "toolbar.penColor" / "toolbar.penWidth" / "toolbar.markerColor" stay with the toolbar
    // (`ToolbarPalette.penColorKey` …; `ToolbarPalette.rememberedPen` reads the pen, 0-13).

    /// 1.1 (§2.3): `Bool`, default false (the expanded bar). True after 「しまう」, false again after
    /// the dock's 「ツールバーをいつも出す」. A `peek` is never stored. `CalendarRootScreen` keeps it
    /// with `@AppStorage`; its `init` reads `toolbarCollapsed` (it cannot read `@AppStorage` there).
    static let toolbarCollapsedKey = "toolbar.collapsed"
    /// 1.1 (§2.3): `String` "leading" / "trailing", the bottom corner of the dock button; missing or
    /// any other value → leading (bottom left, P-4).
    static let toolbarEdgeKey = "toolbar.collapsedEdge"
    /// 1.1 (§2.6, P-5 A): `Bool`, default true — the toolbar's eraser returns to the last pen or
    /// marker after it erased (設定 › 入力 「消しゴムで消したらペンに戻る」).
    static let eraserAutoReturnKey = "eraserAutoReturn"
    /// 1.1 (§5.2, M7A-7): `[String]`, the page ids whose 15,000-stroke notice this device showed,
    /// oldest first, at most `strokeBudgetNoticedLimit` (the oldest are dropped).
    static let strokeBudgetNoticedKey = "strokeBudget.noticedPages"
    static let strokeBudgetNoticedLimit = 500
    /// 1.1.1 (docs/R1_1_1.md): `Bool`, default false. True once the one-time pinch hint was shown, or
    /// once the person pinched (`CalendarRootScreen.pinchHintDue`). `CalendarRootScreen` keeps it with
    /// `@AppStorage`.
    static let pinchHintShownKey = "hint.pinchShown"
    /// 1.2 (§5.6): `String`, `HolidaySetting.storageValue` ("auto", "none", "US", "US-CA"). Written by
    /// `HolidayChoice.migrateIfNeeded` on the first launch of 1.2, so it is not missing after that.
    static let holidaySettingKey = "holidays.setting"
    /// 1.2 (§10.3): `String`, `WeekStartChoice.Setting` ("auto", "monday", "sunday"). Written by
    /// `WeekStartChoice.migrateIfNeeded` on the first launch of 1.2. Missing or broken reads as Monday.
    static let weekStartKey = "weekStart.setting"
    /// 1.2 (§10.3): `String` "monday" / "sunday", what "auto" gave at the last launch; a different
    /// result at this launch means the device's region changed (`toast.weekStart.regionChanged.*`).
    static let weekStartLastAutoKey = "weekStart.lastAuto"
    /// 1.2 (§10.3, step 4): `Bool`, default false. True once this device's pages were compared with the
    /// week start after the first pull (`WeekStartChoice.dataCheck`); it is never compared again.
    static let weekStartDataCheckedKey = "weekStart.dataChecked"
    /// 1.2 (§10.2, D17): `[String]`, "<page id>|<week start>" of the month pages whose hidden strokes
    /// were told about (when the toast was really shown), oldest first, at most
    /// `strokeBudgetNoticedLimit` like `strokeBudgetNoticedKey`.
    static let weekStartHiddenNoticedKey = "weekStart.hiddenNoticed"

    /// M4c (M4C contract §1.5): "zoomRatio.month" / "zoomRatio.week" / "zoomRatio.day" / "zoomRatio.year",
    /// a `Double` ≥ 1 (the zoom / the opening zoom of the last pinch on a page of that kind; absent = 1,
    /// the opening zoom; 1.1.1: a ratio stored by 1.1 reads the same, a page that holds no more than its
    /// `baseSize` opened at that zoom). One key per page kind, not per page (M4C-17).
    static func zoomRatioKey(_ kind: PageKind) -> String {
        "zoomRatio." + kind.rawValue
    }

    /// The store behind the typed accessors (tests may point it at a scratch suite).
    static var defaults: UserDefaults = .standard

    /// 1.2 (§1.4, 0-19, 0-43): someone who used an earlier version: any of the three keys is on record.
    /// `hint.pinchShown` does not count (1.1.1 writes it without the person doing anything, §1.5).
    static func isExistingUser(_ defaults: UserDefaults = AppSettings.defaults) -> Bool {
        [onboardingDoneKey, lastKindKey, allowFingerChosenKey].contains { defaults.object(forKey: $0) != nil }
    }

    static var defaultCalendarId: String? {
        get { defaults.string(forKey: defaultCalendarIdKey) }
        set {
            if let value = newValue, !value.isEmpty {
                defaults.set(value, forKey: defaultCalendarIdKey)
            } else {
                defaults.removeObject(forKey: defaultCalendarIdKey)
            }
        }
    }

    /// True until the person turns it off (`object(forKey:) == nil` counts as true).
    static var eraseInkAfterConvert: Bool {
        get {
            guard defaults.object(forKey: eraseInkAfterConvertKey) != nil else { return true }
            return defaults.bool(forKey: eraseInkAfterConvertKey)
        }
        set { defaults.set(newValue, forKey: eraseInkAfterConvertKey) }
    }

    // MARK: - Toolbar and eraser (1.1, M7A_CONTRACT §2.3 / §2.6)

    /// False (the expanded bar) until the person folds it.
    static var toolbarCollapsed: Bool {
        get { defaults.bool(forKey: toolbarCollapsedKey) }
        set { defaults.set(newValue, forKey: toolbarCollapsedKey) }
    }

    /// The dock's corner; `.leading` when nothing or an unknown value is stored.
    static var toolbarEdge: ToolbarEdge {
        get { ToolbarEdge(stored: defaults.string(forKey: toolbarEdgeKey)) }
        set { defaults.set(newValue.rawValue, forKey: toolbarEdgeKey) }
    }

    /// True until the person turns it off (`object(forKey:) == nil` counts as true, like
    /// `eraseInkAfterConvert`).
    static var eraserAutoReturn: Bool {
        get {
            guard defaults.object(forKey: eraserAutoReturnKey) != nil else { return true }
            return defaults.bool(forKey: eraserAutoReturnKey)
        }
        set { defaults.set(newValue, forKey: eraserAutoReturnKey) }
    }

    // MARK: - Stroke budget notice (1.1, M7A_CONTRACT §5.2)

    /// Whether this device already showed the 15,000-stroke notice for `pageId`.
    static func strokeBudgetNoticed(_ pageId: String) -> Bool {
        (defaults.stringArray(forKey: strokeBudgetNoticedKey) ?? []).contains(pageId)
    }

    /// Remembers that the notice for `pageId` was shown: appended once (a page already in the list is
    /// left where it is), keeping the newest `strokeBudgetNoticedLimit` ids.
    static func markStrokeBudgetNoticed(_ pageId: String) {
        var ids = defaults.stringArray(forKey: strokeBudgetNoticedKey) ?? []
        guard !ids.contains(pageId) else { return }
        ids.append(pageId)
        if ids.count > strokeBudgetNoticedLimit {
            ids.removeFirst(ids.count - strokeBudgetNoticedLimit)
        }
        defaults.set(ids, forKey: strokeBudgetNoticedKey)
    }

    // MARK: - Week start (1.2, docs/M7B_CONTRACT.md §10.2, §10.3)

    /// True once the pages were compared with the week start after the first pull (§10.3, step 4).
    static var weekStartDataChecked: Bool {
        get { defaults.bool(forKey: weekStartDataCheckedKey) }
        set { defaults.set(newValue, forKey: weekStartDataCheckedKey) }
    }

    /// Whether the hidden strokes of the month page `pageId` were told about under `weekStart`.
    static func weekStartHiddenNoticed(_ pageId: String, _ weekStart: WeekStart) -> Bool {
        (defaults.stringArray(forKey: weekStartHiddenNoticedKey) ?? []).contains(hiddenNoticedEntry(pageId, weekStart))
    }

    /// Remembers that the toast about the page's hidden strokes was shown: appended once, keeping the
    /// newest `strokeBudgetNoticedLimit` entries (the oldest may be told about once more, harmlessly).
    static func markWeekStartHiddenNoticed(_ pageId: String, _ weekStart: WeekStart) {
        var entries = defaults.stringArray(forKey: weekStartHiddenNoticedKey) ?? []
        let entry = hiddenNoticedEntry(pageId, weekStart)
        guard !entries.contains(entry) else { return }
        entries.append(entry)
        if entries.count > strokeBudgetNoticedLimit {
            entries.removeFirst(entries.count - strokeBudgetNoticedLimit)
        }
        defaults.set(entries, forKey: weekStartHiddenNoticedKey)
    }

    private static func hiddenNoticedEntry(_ pageId: String, _ weekStart: WeekStart) -> String {
        "\(pageId)|\(weekStart.rawValue)"
    }

    // MARK: - Zoom ratio (M4C contract §1.5, D4)

    /// The stored ratio to the opening zoom of pages of `kind`; 1 (the opening zoom) when nothing is
    /// stored. Normalised with `ZoomPolicy.sanitizedRatio` (a value that is not finite, below 1 or above
    /// `maxStoredRatio` reads as 1).
    static func zoomRatio(for kind: PageKind) -> CGFloat {
        let key = zoomRatioKey(kind)
        guard defaults.object(forKey: key) != nil else { return 1 }
        return ZoomPolicy.sanitizedRatio(CGFloat(defaults.double(forKey: key)))
    }

    /// Stores `ratio` normalised with `ZoomPolicy.sanitizedRatio`; 1 (the opening zoom) removes the key.
    static func setZoomRatio(_ ratio: CGFloat, for kind: PageKind) {
        let key = zoomRatioKey(kind)
        let sanitized = ZoomPolicy.sanitizedRatio(ratio)
        if sanitized == 1 {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(Double(sanitized), forKey: key)
        }
    }

    /// 1.1.1 (docs/R1_1_1.md): this device has a page kind stored zoomed in, so the person knows the pinch.
    static var hasPinched: Bool {
        PageKind.allCases.contains { zoomRatio(for: $0) > 1 }
    }
}
