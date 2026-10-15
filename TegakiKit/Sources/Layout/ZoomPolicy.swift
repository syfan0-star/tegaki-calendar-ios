import Foundation
import CoreGraphics

/// The zoom-scale limits of a page (M4B_CONTRACT §1.1, DESIGN §2.2). Since M4b the lower limit is
/// no longer "fit the paper's width": a page whose key column would be too narrow to read keeps a
/// readable zoom and scrolls horizontally instead (the month, week and day pages on an iPhone, the
/// year page on every device). Pure functions of the page kind and the viewport width, so the same
/// numbers reach the canvas, the sticky header and the all-day band.
public enum ZoomPolicy {
    /// Width of the key column (lu): month 200 (a day), week 190.857… (a day), day 588 (the
    /// timeline, 72…660), year 112 (a month).
    public static func keyColumnWidth(_ kind: PageKind) -> CGFloat {
        switch kind {
        case .month: return PaperSpec.monthColumnWidth
        case .week: return PaperSpec.weekColumnWidth
        case .day: return PaperSpec.dayTimelineRight - PaperSpec.dayGutter
        case .year: return PaperSpec.yearColumnWidth
        }
    }

    /// The least width the key column may take on screen (pt): month 100 / week 90 / day 330 /
    /// year 150 (M4B-22: 150 is "comfortably readable"; 120 is the second candidate).
    public static func readableColumnPoints(_ kind: PageKind) -> CGFloat {
        switch kind {
        case .month: return 100
        case .week: return 90
        case .day: return 330
        case .year: return 150
        }
    }

    /// readableColumnPoints / keyColumnWidth: month 0.5 / week 0.47156… / day 0.56122… / year 1.33928…
    public static func readableZoom(_ kind: PageKind) -> CGFloat {
        readableColumnPoints(kind) / keyColumnWidth(kind)
    }

    /// The paper's width (lu, `PaperSpec`): month, week and year 1400; day 1000.
    public static func paperWidth(_ kind: PageKind) -> CGFloat {
        switch kind {
        case .month: return PaperSpec.monthWidth
        case .week: return PaperSpec.weekWidth
        case .day: return PaperSpec.dayWidth
        case .year: return PaperSpec.yearWidth
        }
    }

    /// viewportWidth / paperWidth (the zoom that fits the paper's width). `readableZoom` when the
    /// width is not finite or not positive.
    public static func fitZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat {
        guard viewportWidth.isFinite, viewportWidth > 0 else { return readableZoom(kind) }
        return viewportWidth / paperWidth(kind)
    }

    /// Fit-to-width is kept when it is at least this fraction of the readable zoom, so a Split View
    /// width a few points short of readable does not make a pointless horizontal scroll (M4B-23).
    public static let fitTolerance: CGFloat = 0.95

    /// `fit` when `fit ≥ fitTolerance × readable`, else `max(fit, readable)`. The comparison allows
    /// 1e-9 of floating-point noise so the exact boundary (a 665 pt month) counts as fit.
    public static func minZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat {
        let fit = fitZoom(kind, viewportWidth: viewportWidth)
        let readable = readableZoom(kind)
        if fit >= fitTolerance * readable - 1e-9 { return fit }
        return Swift.max(fit, readable)
    }

    /// max(4 × fitZoom, 2 × minZoom).
    public static func maxZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat {
        Swift.max(4 * fitZoom(kind, viewportWidth: viewportWidth), 2 * minZoom(kind, viewportWidth: viewportWidth))
    }

    /// The three zoom scales of a page at one viewport width.
    public struct Bounds: Equatable, Sendable {
        public var fit: CGFloat
        public var min: CGFloat
        public var max: CGFloat

        public init(fit: CGFloat, min: CGFloat, max: CGFloat) {
            self.fit = fit
            self.min = min
            self.max = max
        }

        /// `zoom` clamped to [min, max]; NaN → min.
        public func clamped(_ zoom: CGFloat) -> CGFloat {
            if zoom.isNaN { return min }
            return Swift.min(Swift.max(zoom, min), max)
        }
    }

    public static func bounds(_ kind: PageKind, viewportWidth: CGFloat) -> Bounds {
        Bounds(
            fit: fitZoom(kind, viewportWidth: viewportWidth),
            min: minZoom(kind, viewportWidth: viewportWidth),
            max: maxZoom(kind, viewportWidth: viewportWidth)
        )
    }

    /// The paper width (lu) that fits the viewport at `minZoom`: viewportWidth / minZoom, never
    /// more than the paper's width (exactly the paper's width when fit-to-width is the minimum).
    /// 0 when the width is not finite or not positive.
    public static func visibleWidth(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat {
        guard viewportWidth.isFinite, viewportWidth > 0 else { return 0 }
        let b = bounds(kind, viewportWidth: viewportWidth)
        if b.min == b.fit { return paperWidth(kind) }
        return Swift.min(paperWidth(kind), viewportWidth / b.min)
    }
}

/// The visible part of the paper (pt), so the sticky header and the all-day band can follow the
/// paper's horizontal offset and zoom (M4B_CONTRACT §1.1 / §1.3). The canvas (担当 P) makes it and
/// sends it through `InkCanvasView.onViewportChange`; the screen (担当 U) passes it to
/// `StickyHeaderView` and `AllDayBandView`. CoreGraphics types only (no UIKit). It has no height:
/// the band's 35 % cap is measured by the screen itself.
public struct PaperViewport: Equatable, Sendable {
    /// `contentOffset.x` of the canvas (pt).
    public var offsetX: CGFloat
    /// `zoomScale` of the canvas.
    public var zoom: CGFloat
    /// Width of the canvas container (pt).
    public var width: CGFloat

    public init(offsetX: CGFloat, zoom: CGFloat, width: CGFloat) {
        self.offsetX = offsetX
        self.zoom = zoom
        self.width = width
    }

    /// No viewport yet (width 0): the views substitute `initial(_:viewportWidth:)`.
    public static let zero = PaperViewport(offsetX: 0, zoom: 1, width: 0)

    /// Paper x (lu) → container x (pt): lu × zoom − offsetX.
    public func x(ofPaper lu: CGFloat) -> CGFloat {
        lu * zoom - offsetX
    }

    /// A paper width (lu) → pt: lu × zoom.
    public func width(ofPaper lu: CGFloat) -> CGFloat {
        lu * zoom
    }

    /// The viewport of the first frame (before the canvas has reported one): offset 0, the page's
    /// `ZoomPolicy.minZoom` for `viewportWidth`, and that width (0 when it is not finite or negative,
    /// so a viewport never carries NaN and `==` stays meaningful).
    public static func initial(_ kind: PageKind, viewportWidth: CGFloat) -> PaperViewport {
        let width = viewportWidth.isFinite && viewportWidth > 0 ? viewportWidth : 0
        return PaperViewport(offsetX: 0, zoom: ZoomPolicy.minZoom(kind, viewportWidth: viewportWidth), width: width)
    }
}
