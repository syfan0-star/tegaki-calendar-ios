import SwiftUI

/// Entry point of the native "手書きカレンダー" app (SwiftUI app lifecycle).
@main
struct TegakiCalendarApp: App {
    /// Answers the supported orientations only (landscape in CI screenshot mode, otherwise all).
    @UIApplicationDelegateAdaptor(ScreenshotAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
