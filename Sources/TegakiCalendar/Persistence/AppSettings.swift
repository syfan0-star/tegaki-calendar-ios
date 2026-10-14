import Foundation

/// The app's UserDefaults keys and defaults in one place (M3b contract §4.0). Screenshot mode never
/// reads or writes them (the callers check `ScreenshotMode.isActive`).
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
    // "toolbar.penColor" / "toolbar.penWidth" / "toolbar.markerColor" stay in ToolbarView.

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
}
