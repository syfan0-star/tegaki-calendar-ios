import Foundation
import Layout

/// The app's UserDefaults keys and defaults in one place (M3b contract §4.0). Screenshot mode never
/// reads or writes them (the callers check `ScreenshotMode.isActive`). M4c adds the zoom ratio of
/// each page kind (`zoomRatio.<kind>`, D4): the zoom relative to the page's overview (`fitAll`),
/// written only at the end of a pinch (`InkCanvasView.onZoomRatioChange`), read when a page of
/// that kind opens. M5 adds one flag, `paywallShownAfterOnboardingKey` (M5_CONTRACT §4.2); the
/// cached access state is kept by the Store layer itself (`UserDefaultsAccessCache.defaultKey`,
/// M5-34), not here. 1.1 (docs/M7A_CONTRACT.md §2.3, §2.6, §5.2) adds four: the collapsed toolbar
/// and its corner, the eraser's return to the pen, and the pages whose 15,000-stroke notice was shown.
/// All of them stay on this device (UserDefaults is not synced to iCloud).
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

    /// M4c (M4C contract §1.5): "zoomRatio.month" / "zoomRatio.week" / "zoomRatio.day" / "zoomRatio.year",
    /// a `Double` ≥ 1 (the zoom / `fitAll` of the last pinch on a page of that kind; absent = 1, the
    /// overview). One key per page kind, not per page (M4C-17).
    static func zoomRatioKey(_ kind: PageKind) -> String {
        "zoomRatio." + kind.rawValue
    }

    /// The store behind the typed accessors (tests may point it at a scratch suite).
    static var defaults: UserDefaults = .standard

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

    // MARK: - Zoom ratio (M4C contract §1.5, D4)

    /// The stored ratio to the overview of pages of `kind`; 1 (the overview) when nothing is stored.
    /// Normalised with `ZoomPolicy.sanitizedRatio` (a value that is not finite, below 1 or above
    /// `maxStoredRatio` reads as 1).
    static func zoomRatio(for kind: PageKind) -> CGFloat {
        let key = zoomRatioKey(kind)
        guard defaults.object(forKey: key) != nil else { return 1 }
        return ZoomPolicy.sanitizedRatio(CGFloat(defaults.double(forKey: key)))
    }

    /// Stores `ratio` normalised with `ZoomPolicy.sanitizedRatio`; 1 (the overview) removes the key.
    static func setZoomRatio(_ ratio: CGFloat, for kind: PageKind) {
        let key = zoomRatioKey(kind)
        let sanitized = ZoomPolicy.sanitizedRatio(ratio)
        if sanitized == 1 {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(Double(sanitized), forKey: key)
        }
    }
}
