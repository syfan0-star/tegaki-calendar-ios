import CoreGraphics
import Layout

// 1.4.1 (docs/R1_4_1_CONTRACT.md §16.3.1, §16.5; the owner's words of 11/22: 「日、週の等倍とは、最小のサイズではなく、日、週の
// 幅が、ちょうど画面両端にくるサイズのことです」): where 等倍 goes, one pure table the frozen canvas only calls (§16.4). It lives
// outside the Kit so `ZoomPolicy` stays as it is (§1.4, K-6), and reads neither SwiftUI nor UIKit, so `ZoomResetTargetTests`
// checks every kind on the fast path.

enum ZoomReset {
    /// 週・日は true（等倍 = 1 ページの幅が画面の幅にちょうど）。月・年は false（等倍 = open）。
    ///
    /// The week and the day: 等倍 is fit (`ZoomPolicy.Bounds.fit`, the paper column's width ÷ the page's 1,400 / 1,000 lu),
    /// and the canvas keeps that state through a change of width (`InkCanvasView.Coordinator.followsFit`) until a pinch. The
    /// month and the year: 等倍 is the opening zoom, as before (their sideways scrolling and fit come with a later version,
    /// the owner's words of 11/22 12:3x).
    static func followsFit(_ kind: PageKind) -> Bool {
        switch kind {
        case .week, .day: return true
        case .month, .year: return false
        }
    }

    /// 等倍の狙い: 週・日は bounds.clamped(bounds.fit)、月・年は bounds.open。
    ///
    /// Every device has min ≤ open ≤ fit ≤ max (open = min(fit, the height's), the iPhone's landscape cap is fit / 3 or
    /// fit / 5, max ≥ 4 × fit), so the clamp changes nothing there; it stays for limits made some other way.
    static func target(_ kind: PageKind, bounds: ZoomPolicy.Bounds) -> CGFloat {
        followsFit(kind) ? bounds.clamped(bounds.fit) : bounds.open
    }
}
