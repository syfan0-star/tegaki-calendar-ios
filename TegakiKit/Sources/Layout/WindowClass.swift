import Foundation
import CoreGraphics

/// 1.4 (docs/M7D_CONTRACT.md §2.1, §4.3, §4.4, §4.7): what the window's size decides, and only the look. Apple's guidance for the
/// iPhone Duo is to lay out by the window's size and never tell devices apart by the idiom, the size classes or the main screen;
/// the Duo's two screens and a widened iPhone Mirroring window are all just window sizes here. The input (「指でも書く」) is never
/// decided from it: on a Mac's iPhone Mirroring an iPhone without a Pencil can have a wide window too (§4.8, `FingerDefault`).
/// Pure functions of the window's size (pt, with its safe area: the root view's size), nothing else.
public enum WindowClass {
    /// The least short side (pt) of a wide window: 600, the width from which the app's header is one row
    /// (`CalendarRootScreen.compactWidth`; the app's test `testWideShortSideIsTheCompactWidth` checks the two are the same).
    /// Every iPhone's short side is 440 or less, the Duo's inner screen is estimated at 626–669 and its outer one at 466
    /// (§4.2 measures them; a measurement on the wrong side of 600 stops the work and decides it anew, §4.7).
    public static let wideShortSide: CGFloat = 600

    /// A wide window: its short side is `wideShortSide` or more. nil, a side of 0, a negative side or one that is not finite
    /// is not wide (not measured yet).
    public static func isWide(_ windowSize: CGSize?) -> Bool {
        guard let size = measured(windowSize) else { return false }
        return min(size.width, size.height) >= wideShortSide
    }

    /// The kind of page the app opens the first time (§4.3): `stored` when there is one (the page it remembers); the month on
    /// an iPad (1.3's); otherwise, once the window is measured, the month in a wide window and the week in any other. By the
    /// short side, not the width: an iPhone turned on its side the first time still opens the week, as in 1.3. nil while the
    /// window is not measured (and nothing is stored, on a phone).
    public static func openingKind(stored: PageKind?, isPad: Bool, windowSize: CGSize?) -> PageKind? {
        if let stored { return stored }
        if isPad { return .month }
        guard measured(windowSize) != nil else { return nil }
        return isWide(windowSize) ? .month : .week
    }

    /// Whether a wide window also gets the form sheet (§4.4). Decided on D1 by the inner screen's shots (the purchase sheet's
    /// EULA row and 「あとで」, the event editor's 「保存」 and 「キャンセル」 without scrolling); false until then and when the inner
    /// screen cannot be shot (road 3, the default): every phone window keeps 1.3's `.large`. 1.4 D1c: false, decided — duo.yml's
    /// run 44696154794 took road 3 (the outer screen only, 466x678, not wide); the inner screen was not shot, so neither check
    /// was made (§4.4: 内側を撮れない（道 3、既定）なら false のまま).
    public static let formSheetOnWide: Bool = false

    /// Whether a sheet is a form sheet: on an iPad, or in a wide window when `formSheetOnWide`.
    public static func usesFormSheet(isPad: Bool, windowSize: CGSize?) -> Bool {
        isPad || (formSheetOnWide && isWide(windowSize))
    }

    /// Whether the joined path's window plan caps the overview (P-B6 イ, `SpanPlan.overviewCap`; §4.7): not in a wide window.
    /// A window not measured yet caps (true, 1.3's). An iPad's plan is never `.iPhone`, so it has no cap either way
    /// (`SpanPlan.overviewCapPages`).
    public static func capsOverview(windowSize: CGSize?) -> Bool {
        !isWide(windowSize)
    }

    /// The size when both sides are finite and positive, else nil.
    private static func measured(_ size: CGSize?) -> CGSize? {
        guard let size, size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
        return size
    }

    /// The opening kind decided once (§4.3, C2): the window's size may come before `appear()` or after it, the answer is the
    /// same. Once decided it never changes, so a fold or an unfold that changes the width later never changes the kind of the
    /// page one is writing on.
    public struct Opening: Equatable, Sendable {
        /// The kind once decided (nil until then).
        public private(set) var decided: PageKind?
        private let isPad: Bool

        /// With a stored kind or on an iPad the kind is decided here.
        public init(stored: PageKind?, isPad: Bool) {
            self.isPad = isPad
            decided = WindowClass.openingKind(stored: stored, isPad: isPad, windowSize: nil)
        }

        /// The window's size (each time it is measured): decides the kind by `openingKind` while it is not decided yet;
        /// afterwards the same kind, whatever the size. nil while still undecided.
        public mutating func windowSize(_ size: CGSize?) -> PageKind? {
            if let decided { return decided }
            decided = WindowClass.openingKind(stored: nil, isPad: isPad, windowSize: size)
            return decided
        }
    }
}
