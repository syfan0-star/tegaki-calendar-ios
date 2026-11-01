import Foundation
import CoreGraphics

/// The zoom-scale limits of a page (M4C_CONTRACT §1.1, DESIGN §2.2 / §3.8). Since M4c the lower
/// limit is the overview (`fitAll`, D1): the zoom at which the page's overview rectangle (the month's
/// 6 rows, the week's and day's 24 hours, the whole year) fits the paper area both ways, so every
/// page opens as a thumbnail of itself and a pinch enlarges it. The M4b `readableZoom` stays as the
/// text threshold (D3) but no longer binds the zoom. Pure functions of the page kind, the overview
/// rectangle and the viewport, so the same numbers reach the canvas, the sticky header and the
/// all-day band.
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

    /// The least width the key column may take on screen for its text to be readable (pt): month
    /// 100 / week 90 / day 330 / year 150 (M4B-22: 150 is "comfortably readable"; 120 is the second
    /// candidate).
    public static func readableColumnPoints(_ kind: PageKind) -> CGFloat {
        switch kind {
        case .month: return 100
        case .week: return 90
        case .day: return 330
        case .year: return 150
        }
    }

    /// readableColumnPoints / keyColumnWidth: month 0.5 / week 0.47156… / day 0.56122… / year
    /// 1.33928…. Below it the paper's text shrinks in proportion (M4c D3); it no longer binds the zoom.
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

    /// The overview rectangle (lu, D1): the part of the paper the lower limit fits into the paper
    /// area. Month: 1400 × `MonthPageLayout.memo.minY` (the 6 rows; the memo area is reached by
    /// scrolling, M4C-12). Day: 1000 × `grid.height` (the 24 hours; the free memo area below 24:00 is
    /// reached by scrolling, 1.1 K-6, so the overview's zoom never depends on its height). Week and
    /// year: the whole paper (`layout.size`).
    public static func overviewSize(_ layout: any PageLayout) -> CGSize {
        if let month = layout as? MonthPageLayout {
            return CGSize(width: month.size.width, height: month.memo.minY)
        }
        if let day = layout as? DayPageLayout {
            return CGSize(width: day.size.width, height: day.grid.height)
        }
        return layout.size
    }

    /// min(viewport.width / overview.width, viewport.height / overview.height): the zoom at which the
    /// overview fits the paper area both ways. When `viewport.height` is not finite or not positive
    /// (the first frame, before the screen has measured the paper area) the width alone decides
    /// (viewport.width / overview.width). `readableZoom` when the width is not usable either, or
    /// when `overview` is not finite or not positive.
    public static func fitAll(_ kind: PageKind, overview: CGSize, viewport: CGSize) -> CGFloat {
        guard overview.width.isFinite, overview.width > 0, overview.height.isFinite, overview.height > 0 else { return readableZoom(kind) }
        guard viewport.width.isFinite, viewport.width > 0 else { return readableZoom(kind) }
        let byWidth = viewport.width / overview.width
        guard viewport.height.isFinite, viewport.height > 0 else { return byWidth }
        return Swift.min(byWidth, viewport.height / overview.height)
    }

    /// max(4 × fitZoom, 2 × readableZoom) — the same value as M4b's max(4 × fit, 2 × minZoom)
    /// (M4C-16). 4 × readableZoom when the width is not usable.
    public static func maxZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat {
        Swift.max(4 * fitZoom(kind, viewportWidth: viewportWidth), 2 * readableZoom(kind))
    }

    /// The three zoom scales of a page: `fit` (fit-to-width), `min` (the overview, `fitAll`) and
    /// `max` (`maxZoom`).
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

    /// fit = `fitZoom(viewport.width)`, min = `fitAll`, max = `maxZoom`. No combination makes
    /// max < min (fitAll ≤ fit ≤ 4 × fit), but max is raised to min just in case.
    public static func bounds(_ kind: PageKind, overview: CGSize, viewport: CGSize) -> Bounds {
        let minZ = fitAll(kind, overview: overview, viewport: viewport)
        let maxZ = maxZoom(kind, viewportWidth: viewport.width)
        return Bounds(
            fit: fitZoom(kind, viewportWidth: viewport.width),
            min: minZ,
            max: Swift.max(maxZ, minZ)
        )
    }

    /// A stored ratio (relative to the overview, D4) → the zoom: `bounds.clamped(ratio × bounds.min)`.
    /// `bounds.min` when the ratio is not finite or not positive.
    public static func zoom(forRatio ratio: CGFloat, bounds: Bounds) -> CGFloat {
        guard ratio.isFinite, ratio > 0 else { return bounds.min }
        return bounds.clamped(ratio * bounds.min)
    }

    /// A zoom → the ratio to store: `sanitizedRatio(zoom / bounds.min)`; 1 when `bounds.min` is not
    /// finite or not positive.
    public static func ratio(forZoom zoom: CGFloat, bounds: Bounds) -> CGFloat {
        guard bounds.min.isFinite, bounds.min > 0 else { return 1 }
        return sanitizedRatio(zoom / bounds.min)
    }

    /// The stored ratio made safe: 1 unless it is finite and 1 ≤ r ≤ `maxStoredRatio` (NaN, a
    /// negative or zero value, below 1 and far too large all become 1); 1 ± 0.001 is 1 (the overview).
    public static func sanitizedRatio(_ ratio: CGFloat) -> CGFloat {
        guard ratio.isFinite, ratio >= 1, ratio <= maxStoredRatio else { return 1 }
        if abs(ratio - 1) <= 0.001 { return 1 }
        return ratio
    }

    /// The largest ratio a page can store (M4C-9): the largest maxZoom / fitAll is the iPhone's
    /// landscape day page, 3.50 / 0.085 ≈ 41 (with a one-lane band).
    public static let maxStoredRatio: CGFloat = 64

    /// The margins that centre a paper smaller than the viewport (pt): width = left and right =
    /// (viewport.width − paper.width × zoom) / 2, height = top and bottom = (viewport.height −
    /// paper.height × zoom) / 2. A negative margin (the paper is larger) is 0; so is one computed
    /// from a value that is not finite or not positive (a negative paper side counts as 0).
    /// `paper` is always the whole paper (`layout.size`), never the overview rectangle.
    public static func centeringInsets(paper: CGSize, zoom: CGFloat, viewport: CGSize) -> CGSize {
        guard zoom.isFinite, zoom > 0 else { return .zero }
        func margin(_ side: CGFloat, _ paperSide: CGFloat) -> CGFloat {
            guard side.isFinite, side > 0, paperSide.isFinite else { return 0 }
            let scaled = Swift.max(0, paperSide) * zoom
            guard scaled.isFinite else { return 0 }
            return Swift.max(0, (side - scaled) / 2)
        }
        return CGSize(width: margin(viewport.width, paper.width), height: margin(viewport.height, paper.height))
    }

    /// The paper width (lu) that fits the viewport at `zoom`: min(paperWidth, viewportWidth / zoom).
    /// Exactly the paper's width at fit-to-width (the quotient may miss it by floating-point noise,
    /// which would leave `PageNavigation.initialScrollX` a few 1e-13 lu off 0, as in M4b's rule).
    /// 0 when the width or the zoom is not finite or not positive.
    public static func visibleWidth(_ kind: PageKind, viewportWidth: CGFloat, zoom: CGFloat) -> CGFloat {
        guard viewportWidth.isFinite, viewportWidth > 0, zoom.isFinite, zoom > 0 else { return 0 }
        let paper = paperWidth(kind)
        let visible = viewportWidth / zoom
        if visible >= paper - 1e-9 { return paper }
        return visible
    }
}

/// The visible part of the paper (pt), so the sticky header and the all-day band can follow the
/// paper's horizontal offset and zoom (M4B_CONTRACT §1.1 / §1.3). The canvas (担当 P) makes it and
/// sends it through `InkCanvasView.onViewportChange`; the screen (担当 U) passes it to
/// `StickyHeaderView` and `AllDayBandView`. CoreGraphics types only (no UIKit). It has no height
/// (M4B-28): the overview is a pure function the screen and the canvas evaluate from the same
/// inputs, and the band's 35 % cap is measured by the screen itself.
public struct PaperViewport: Equatable, Sendable {
    /// `contentOffset.x` of the canvas (pt). Negative when the paper is narrower than the viewport
    /// and centred (M4c D1: the centring margin).
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

    /// No viewport yet (width 0): the views substitute `initial`.
    public static let zero = PaperViewport(offsetX: 0, zoom: 1, width: 0)

    /// Paper x (lu) → container x (pt): lu × zoom − offsetX.
    public func x(ofPaper lu: CGFloat) -> CGFloat {
        lu * zoom - offsetX
    }

    /// A paper width (lu) → pt: lu × zoom.
    public func width(ofPaper lu: CGFloat) -> CGFloat {
        lu * zoom
    }

    /// The viewport of the first frame when only the width is known (no height yet): offset 0, the
    /// page's `ZoomPolicy.fitZoom` for `viewportWidth` (fit-to-width; M4b used `minZoom`), and that
    /// width (0 when it is not finite or negative, so a viewport never carries NaN and `==` stays
    /// meaningful).
    public static func initial(_ kind: PageKind, viewportWidth: CGFloat) -> PaperViewport {
        let width = viewportWidth.isFinite && viewportWidth > 0 ? viewportWidth : 0
        return PaperViewport(offsetX: 0, zoom: ZoomPolicy.fitZoom(kind, viewportWidth: viewportWidth), width: width)
    }

    /// The viewport of the first frame when the height and the overview are known: zoom =
    /// `ZoomPolicy.zoom(forRatio: ratio, bounds: bounds(kind, overview:, viewport:))`, offsetX =
    /// −`centeringInsets(paper: paperSize, zoom:, viewport:).width` (negative when the paper is
    /// narrower than the viewport; `paperSize` is the whole paper, `layout.size`), width =
    /// `viewport.width` (0 when it is not finite or negative). A viewport height that is 0 or not
    /// finite falls back to the width alone, like `fitAll`.
    public static func initial(_ kind: PageKind, overview: CGSize, paperSize: CGSize, viewport: CGSize, ratio: CGFloat) -> PaperViewport {
        let width = viewport.width.isFinite && viewport.width > 0 ? viewport.width : 0
        let zoom = ZoomPolicy.zoom(forRatio: ratio, bounds: ZoomPolicy.bounds(kind, overview: overview, viewport: viewport))
        let inset = ZoomPolicy.centeringInsets(paper: paperSize, zoom: zoom, viewport: viewport)
        return PaperViewport(offsetX: -inset.width, zoom: zoom, width: width)
    }
}
