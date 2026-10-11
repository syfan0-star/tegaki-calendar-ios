import Foundation
import CoreGraphics

/// Lane height, step (lane + gap), gap and the font scale of thinned lanes.
public struct LaneMetrics: Equatable, Sendable {
    public var lane: CGFloat
    public var step: CGFloat
    public var gap: CGFloat
    /// `min(1, lane / original lane)`.
    public var fontScale: CGFloat

    public init(lane: CGFloat, step: CGFloat, gap: CGFloat, fontScale: CGFloat) {
        self.lane = lane
        self.step = step
        self.gap = gap
        self.fontScale = fontScale
    }

    /// Untouched lanes of the given height and gap.
    public static func plain(lane: CGFloat, gap: CGFloat) -> LaneMetrics {
        LaneMetrics(lane: lane, step: lane + gap, gap: gap, fontScale: 1)
    }
}

/// Lane thinning (the web version's month-view.js allDayLaneMetrics). Used only when a band or a row
/// has reached its cap.
public enum LanePacking {
    /// `laneCount` lanes of height `lane` with `gap` between them must fit into `available`
    /// (`laneCount × (lane + gap) − gap ≤ available`). When they do not, the step shrinks to
    /// `(available + gap) / laneCount`; when that step is below `3 × gap` the gap shrinks too
    /// (`gap = step / 3`, `step = available / (laneCount − 1/3)`). When they fit, nothing changes.
    public static func metrics(laneCount: Int, lane: CGFloat, gap: CGFloat, available: CGFloat) -> LaneMetrics {
        let original = max(lane, 0)
        var l = original
        var g = max(gap, 0)
        let n = CGFloat(laneCount)
        let avail = available.isFinite ? max(0, available) : 0
        if laneCount > 0 && n * (l + g) - g > avail {
            var step = (avail + g) / n
            if step < 3 * g {
                step = avail / (n - 1 / 3)
                g = step / 3
            }
            l = max(0, step - g)
        }
        let scale = original > 0 ? min(1, l / original) : 1
        return LaneMetrics(lane: l, step: l + g, gap: g, fontScale: scale)
    }
}
