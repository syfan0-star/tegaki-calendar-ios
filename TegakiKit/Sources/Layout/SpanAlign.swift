import Foundation
import CoreGraphics

/// Lining up the bottom of the joined pages (1.3, docs/M7C_CONTRACT.md D16, §3.2, §3.8; B_DESIGN.md
/// §3.1, :288): every page of a window gets the height of its tallest last cell as a lower bound
/// (a floor), so the day's free memo below 24:00 runs on as one band. The engines take the floor as
/// an input (`DayLayoutInput.extraFloor`, `WeekLayoutInput.extraFloor`); left out it is 0 and the
/// output is today's, `==`. Since 1.1.1 every day's `extra` is 6,000 lu already, so a floor only
/// matters once a line ends past 5,950 lu (`PaperGrowth.tailHeight`). Only positions and heights
/// move; no cell changes its meaning (K-4) and nothing is stored (K-5). The week's floor waits for the
/// week memo (§5): until the week page has an `extra`, it changes nothing.
public enum SpanAlign {
    /// The floors of a window's last cells (lu): the day's `extra` and the week's (the week memo, §5).
    /// 0 is no floor.
    public struct Floors: Equatable, Sendable {
        public var dayExtra: CGFloat
        public var weekExtra: CGFloat

        public init(dayExtra: CGFloat = 0, weekExtra: CGFloat = 0) {
            self.dayExtra = dayExtra
            self.weekExtra = weekExtra
        }

        /// No floor: every page is laid out as it is today.
        public static let none = Floors()

        /// The floor of a kind's last cell (0 for the month and the year, which are not joined in 1.3).
        public func floor(for kind: PageKind) -> CGFloat {
            switch kind {
            case .day: return dayExtra
            case .week: return weekExtra
            case .month, .year: return 0
            }
        }
    }

    /// What happened to the window, which decides whether a floor may come down (B_DESIGN.md:288).
    public enum Change: Equatable, Sendable {
        /// The window moved to other pages: the floor never comes down (the rows on screen do not shrink).
        case shift
        /// A page's handwriting grew: the floor only goes up.
        case inkGrew
        /// A page's last cell shrank (erasing): the floor comes down to the tallest page of the window
        /// (P-6 A, "erase and the blank paper shrinks too").
        case inkShrank
        /// Decided again from the window alone: reopening, rotation, the end of a pinch.
        case redecide
    }

    /// The height a page's last cell has by its own handwriting (`inkBottom` cell-relative):
    /// `PaperGrowth.tailHeight`, at least 6,000 lu.
    public static func natural(inkBottom: CGFloat) -> CGFloat {
        PaperGrowth.tailHeight(inkBottom: inkBottom)
    }

    /// The floor after `change`, from the previous floor and the natural heights of the window's pages
    /// (values that are not finite or negative count as 0). `shift` and `inkGrew`: max(previous, the
    /// tallest); `inkShrank` and `redecide`: the tallest (0 for no page).
    public static func floor(previous: CGFloat, naturals: [CGFloat], change: Change) -> CGFloat {
        let tallest = naturals.reduce(CGFloat(0)) { max($0, sanitized($1)) }
        switch change {
        case .shift, .inkGrew:
            return max(sanitized(previous), tallest)
        case .inkShrank, .redecide:
            return tallest
        }
    }

    /// The day floors of a window after `change`, from the bottoms of each page's `extra` handwriting
    /// (`InkPage.inkBottoms()[.extra]`, 0 for a page without any).
    public static func dayFloors(previous: Floors, extraInkBottoms: [CGFloat], change: Change) -> Floors {
        var floors = previous
        floors.dayExtra = floor(previous: previous.dayExtra, naturals: extraInkBottoms.map(natural(inkBottom:)), change: change)
        return floors
    }

    /// A floor as the engines read it: finite and 0 or more, else 0.
    public static func sanitized(_ floor: CGFloat) -> CGFloat {
        floor.isFinite ? max(0, floor) : 0
    }
}
