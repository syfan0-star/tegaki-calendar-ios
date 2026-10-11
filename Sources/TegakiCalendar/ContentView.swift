import SwiftUI

/// The app's one screen in M2: the month page (header, paper with ink, toolbar, sheets).
/// The screen draws its own header, so there is no navigation stack around it.
struct ContentView: View {
    var body: some View {
        MonthPageScreen()
    }
}
