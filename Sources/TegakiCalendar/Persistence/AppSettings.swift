import Foundation
import Layout

/// The app's UserDefaults keys and defaults in one place (M3b contract §4.0). Screenshot mode never
/// reads or writes them (the callers check `ScreenshotMode.isActive`). M4c adds the zoom ratio of
/// each page kind (`zoomRatio.<kind>`, D4): the zoom relative to the page's overview (`fitAll`),
/// written only at the end of a pinch (`InkCanvasView.onZoomRatioChange`), read when a page of
/// that kind opens. M5 adds one flag, `paywallShownAfterOnboardingKey` (M5_CONTRACT §4.2); the
/// cached access state is kept by the Store layer itself (`UserDefaultsAccessCache.defaultKey`,
/// M5-34), not here.
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
    // "toolbar.penColor" / "toolbar.penWidth" / "toolbar.markerColor" stay in ToolbarView.

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
