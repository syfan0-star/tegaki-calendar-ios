import StoreKit
import SwiftUI

/// 1.2.1 (docs/R1_2_1.md §2.2): asks StoreKit for the App Store rating prompt each time `trigger` grows.
/// Apple decides whether the prompt shows (at most three times in 365 days; never in a TestFlight build).
/// `CalendarRootScreen.scheduleReviewRequest` decides when to ask (§2.3); this is the only file of the
/// screen that imports StoreKit, so StoreKit's names never meet `Access`'s (`Subscription`, `Trial`) there.
struct ReviewRequester: ViewModifier {
    let trigger: Int
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onChange(of: trigger) {
            requestReview()
        }
    }
}
