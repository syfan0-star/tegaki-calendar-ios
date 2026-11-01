import Foundation
import CoreGraphics

/// The rule of a finger's single tap on the paper (1.1, M7A_CONTRACT D4 / §4.1): what a tap at a paper
/// point means on each page, given the zoom, the screen size and 「指でも書く」. One pure function so the
/// screen's tap handler and its "does this tap leave the page?" question (the canvas asks before it
/// removes the dots the tap drew) read the same rule.
///
/// | 「指でも書く」 | small screen (iPhone, width < 600 pt) | large screen (iPad full screen) |
/// | --- | --- | --- |
/// | off | month and year 44 pt; the year's gutter: the whole row | month and year 44 pt; gutter: the whole row |
/// | on  | year 44 pt, month only the 1.0 date frame (M7A-1); gutter: the whole row | year and month the 1.0 frames; gutter: the number only |
public enum DateTap {
    /// The least on-screen size of a date's tap area (pt).
    public static let minPoints: CGFloat = 44

    /// The least size of a date's tap area in paper lu (`44 / zoom`), or nil when the page keeps the
    /// 1.0 frames: month only with 「指でも書く」 off; year on a small screen or with 「指でも書く」 off
    /// (1.0.1 kept the small screen's 44 pt whatever the setting); week and day never. nil when the zoom
    /// is not finite or not positive.
    public static func minTarget(kind: PageKind, zoom: CGFloat, smallScreen: Bool, allowFinger: Bool) -> CGFloat? {
        guard zoom.isFinite, zoom > 0 else { return nil }
        switch kind {
        case .month:
            return allowFinger ? nil : minPoints / zoom
        case .year:
            return smallScreen || !allowFinger ? minPoints / zoom : nil
        case .week, .day:
            return nil
        }
    }

    /// What a finger's single tap at `point` (paper lu) hits.
    /// - Year: ① `hit(at:)` (chips: thick → `.allDayBar`, thin → `.date`; the 40 × 28 weekday frames),
    ///   ② the gutter's day number → that day of `currentMonth` (`gutterHit`; the number only with
    ///   「指でも書く」 on a large screen, the whole row otherwise; independent of the zoom), ③ with a
    ///   `minTarget`, `hit(at:minTarget:)` (1.0.1), else nil.
    /// - Month: with a `minTarget`, `hit(at:minTarget:)`, else `hit(at:)`.
    /// - Week and day: `hit(at:)` (unchanged).
    public static func target(layout: any PageLayout, point: CGPoint, zoom: CGFloat,
                              smallScreen: Bool, allowFinger: Bool, currentMonth: Int) -> HitTarget? {
        if let year = layout as? YearPageLayout {
            if let hit = year.hit(at: point) { return hit }
            if let gutter = year.gutterHit(at: point, numberOnly: allowFinger && !smallScreen, month: currentMonth) {
                return gutter
            }
            if let min = minTarget(kind: .year, zoom: zoom, smallScreen: smallScreen, allowFinger: allowFinger) {
                return year.hit(at: point, minTarget: min)
            }
            return nil
        }
        if let month = layout as? MonthPageLayout {
            if let min = minTarget(kind: .month, zoom: zoom, smallScreen: smallScreen, allowFinger: allowFinger) {
                return month.hit(at: point, minTarget: min)
            }
            return month.hit(at: point)
        }
        return layout.hit(at: point)
    }
}
