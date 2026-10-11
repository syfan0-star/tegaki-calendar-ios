import SwiftUI

/// The app's one screen: the calendar pages (header, sticky heading, paper with ink, toolbar,
/// sheets). The screen draws its own header, so there is no navigation stack around it.
struct ContentView: View {
    var body: some View {
        CalendarRootScreen()
    }
}
