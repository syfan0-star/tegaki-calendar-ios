import SwiftUI

/// Entry point of the native "てがきカレンダー" app (SwiftUI app lifecycle). The UIKit delegate
/// (`AppDelegate`, M4 contract §6.7) registers for silent pushes and starts the sync engine.
@main
struct TegakiCalendarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
