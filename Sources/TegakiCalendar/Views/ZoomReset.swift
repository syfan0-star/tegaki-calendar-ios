import CoreGraphics
import Layout

// 1.4.1 (docs/R1_4_1_CONTRACT.md §16.3.1, §16.5; the owner's words of 11/22: 「日、週の等倍とは、最小のサイズではなく、日、週の
// 幅が、ちょうど画面両端にくるサイズのことです」): where 等倍 goes, one pure table the frozen canvas only calls (§16.4). It lives
// outside the Kit so `ZoomPolicy` stays as it is (§1.4, K-6), and reads neither SwiftUI nor UIKit, so `ZoomResetTargetTests`
// checks every kind on the fast path.

enum ZoomReset {
    /// 週・日は true（等倍 = 1 ページの幅が画面の幅にちょうど）。1.4.3: 横につなぐ種類（SpanKinds.joined）の月・年も true。
    ///
    /// The week and the day: 等倍 is fit (`ZoomPolicy.Bounds.fit`, the paper column's width ÷ the page's 1,400 / 1,000 lu),
    /// and the canvas keeps that state through a change of width (`InkCanvasView.Coordinator.followsFit`) until a pinch.
    /// 1.4.3 (docs/R1_4_3_CONTRACT.md §6.1, 0g-26; the owner's words of 11/22 12:3x, 「月と年は、横スクロールができる仕様にして
    /// から、幅が両端にくる等倍を適用します」): a month or a year follows fit once its kind joins sideways (`SpanKinds.joined`),
    /// on both paths alike; a kind that does not join keeps the opening zoom (1.4.1's).
    static func followsFit(_ kind: PageKind) -> Bool {
        kind == .week || kind == .day || SpanKinds.joined.contains(kind)
    }

    /// 等倍の狙い: followsFit の種類は bounds.clamped(bounds.fit)、ほかは bounds.open。
    ///
    /// Every device has min ≤ open ≤ fit ≤ max (open = min(fit, the height's), the iPhone's landscape cap is fit / 3 or
    /// fit / 5, max ≥ 4 × fit), so the clamp changes nothing there; it stays for limits made some other way.
    static func target(_ kind: PageKind, bounds: ZoomPolicy.Bounds) -> CGFloat {
        followsFit(kind) ? bounds.clamped(bounds.fit) : bounds.open
    }
}
