import Foundation
import CoreGraphics

/// The zoom-scale limits of a page (M4C_CONTRACT §1.1, DESIGN §2.2 / §3.8, docs/R1_1_1.md). Since
/// 1.1.1 a page opens at the zoom that fits its `baseSize` into the paper area both ways, so what a
/// page holds never changes the size it opens at; a page that holds more is reached by scrolling.
/// The lower limit is still the overview (`fitAll`, M4c D1: the page's overview rectangle, the month's
/// 6 rows, the week's and day's 24 hours, the whole year), so a pinch shows the whole page, and the
/// paper starts at the top of the paper area. The M4b `readableZoom` stays as the text threshold (D3)
/// but does not bind the zoom. Pure functions of the page kind, the overview rectangle and the
/// viewport, so the same numbers reach the canvas, the sticky header and the all-day band.
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

    /// The paper the opening zoom is computed from (1.1.1, docs/R1_1_1.md): month 1400 × 1050 (6 rows of
    /// 175), week 1400 × 1920, day 1000 × 2400, year 1400 × 1860 (31 rows of 60). What a page holds never
    /// changes it, so every month and every year opens at the same size on a device. It is the
    /// `overviewSize` of an empty page, and rows only grow, so no `overviewSize` is smaller.
    public static func baseSize(_ kind: PageKind) -> CGSize {
        switch kind {
        case .month: return CGSize(width: PaperSpec.monthWidth, height: PaperSpec.monthRowBase * CGFloat(PaperSpec.monthRows))
        case .week: return CGSize(width: PaperSpec.weekWidth, height: PaperSpec.weekGridHeight)
        case .day: return CGSize(width: PaperSpec.dayWidth, height: PaperSpec.dayGridHeight)
        case .year: return CGSize(width: PaperSpec.yearWidth, height: PaperSpec.yearRowBase * CGFloat(PaperSpec.yearRows))
        }
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
    /// rectangle (a page's overview, or its `baseSize` for the opening zoom) fits the paper area both
    /// ways. When `viewport.height` is not finite or not positive (the first frame, before the screen
    /// has measured the paper area) the width alone decides (viewport.width / overview.width).
    /// `readableZoom` when the width is not usable either, or when `overview` is not finite or not
    /// positive.
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

    /// The four zoom scales of a page: `fit` (fit-to-width), `open` (the zoom it opens at, ratio 1),
    /// `min` (the lower limit) and `max` (`maxZoom`).
    public struct Bounds: Equatable, Sendable {
        public var fit: CGFloat
        /// The zoom a page opens at (ratio 1): `fitAll` of `baseSize`.
        public var open: CGFloat
        /// The lower limit: min(open, `fitAll` of the page's overview), so a pinch shows the whole page.
        public var min: CGFloat
        public var max: CGFloat

        /// `open` nil is `min`: a page that opens at its lower limit.
        public init(fit: CGFloat, open: CGFloat? = nil, min: CGFloat, max: CGFloat) {
            self.fit = fit
            self.open = open ?? min
            self.min = min
            self.max = max
        }

        /// `zoom` clamped to [min, max]; NaN → min.
        public func clamped(_ zoom: CGFloat) -> CGFloat {
            if zoom.isNaN { return min }
            return Swift.min(Swift.max(zoom, min), max)
        }
    }

    /// fit = `fitZoom(viewport.width)`, open = `fitAll` of `baseSize`, min = min(open, `fitAll` of
    /// `overview`), max = `maxZoom`. No combination makes max < min (min ≤ fitAll ≤ fit ≤ 4 × fit), but
    /// max is raised to min just in case.
    public static func bounds(_ kind: PageKind, overview: CGSize, viewport: CGSize) -> Bounds {
        let openZ = fitAll(kind, overview: baseSize(kind), viewport: viewport)
        let minZ = Swift.min(openZ, fitAll(kind, overview: overview, viewport: viewport))
        let maxZ = maxZoom(kind, viewportWidth: viewport.width)
        return Bounds(
            fit: fitZoom(kind, viewportWidth: viewport.width),
            open: openZ,
            min: minZ,
            max: Swift.max(maxZ, minZ)
        )
    }

    /// A stored ratio (relative to the opening zoom since 1.1.1; D4) → the zoom:
    /// `bounds.clamped(ratio × bounds.open)`. `bounds.open` when the ratio is not finite or not positive.
    public static func zoom(forRatio ratio: CGFloat, bounds: Bounds) -> CGFloat {
        guard ratio.isFinite, ratio > 0 else { return bounds.open }
        return bounds.clamped(ratio * bounds.open)
    }

    /// A zoom → the ratio to store: `sanitizedRatio(zoom / bounds.open)`, so a pinch below the opening
    /// zoom is not stored (ratio 1); 1 when `bounds.open` is not finite or not positive.
    public static func ratio(forZoom zoom: CGFloat, bounds: Bounds) -> CGFloat {
        guard bounds.open.isFinite, bounds.open > 0 else { return 1 }
        return sanitizedRatio(zoom / bounds.open)
    }

    /// The stored ratio made safe: 1 unless it is finite and 1 ≤ r ≤ `maxStoredRatio` (NaN, a
    /// negative or zero value, below 1 and far too large all become 1); 1 ± 0.001 is 1 (the opening zoom).
    public static func sanitizedRatio(_ ratio: CGFloat) -> CGFloat {
        guard ratio.isFinite, ratio >= 1, ratio <= maxStoredRatio else { return 1 }
        if abs(ratio - 1) <= 0.001 { return 1 }
        return ratio
    }

    /// The largest ratio a page can store (M4C-9): the largest maxZoom / opening zoom is the iPhone's
    /// landscape day page, 3.50 / 0.085 ≈ 41 (with a one-lane band).
    public static let maxStoredRatio: CGFloat = 64

    /// The margins that centre a paper narrower than the viewport (pt): width = left and right =
    /// (viewport.width − paper.width × zoom) / 2. A negative margin (the paper is wider) is 0; so is one
    /// computed from a value that is not finite or not positive (a negative paper side counts as 0).
    /// height is always 0: since 1.1.1 the paper starts at the top of the viewport (M4C-1 was reversed,
    /// docs/R1_1_1.md: a short paper showed a band of the desk colour under the heading) and what is
    /// left stays below it.
    /// `paper` is always the whole paper (`layout.size`), never the overview rectangle.
    public static func centeringInsets(paper: CGSize, zoom: CGFloat, viewport: CGSize) -> CGSize {
        guard zoom.isFinite, zoom > 0 else { return .zero }
        func margin(_ side: CGFloat, _ paperSide: CGFloat) -> CGFloat {
            guard side.isFinite, side > 0, paperSide.isFinite else { return 0 }
            let scaled = Swift.max(0, paperSide) * zoom
            guard scaled.isFinite else { return 0 }
            return Swift.max(0, (side - scaled) / 2)
        }
        return CGSize(width: margin(viewport.width, paper.width), height: 0)
    }

    /// How far (pt) a revealed rect stays from the edge of the viewport.
    public static let revealMargin: CGFloat = 8

    /// The content offset that brings `rect` (paper lu) on screen with the least movement: `current` when
    /// it is already there, on each axis. A rect longer than the viewport lines up with its start. The
    /// caller clamps the result to the paper. Not finite or not positive → `current` (1.1.1, 「今日」,
    /// docs/R1_1_1.md).
    public static func revealOffset(rect: CGRect, zoom: CGFloat, viewport: CGSize, current: CGPoint) -> CGPoint {
        guard zoom.isFinite, zoom > 0, viewport.width > 0, viewport.height > 0,
              rect.minX.isFinite, rect.minY.isFinite, rect.width.isFinite, rect.height.isFinite else { return current }
        func axis(_ low: CGFloat, _ high: CGFloat, _ length: CGFloat, _ now: CGFloat) -> CGFloat {
            let lo = low * zoom - revealMargin
            let hi = high * zoom + revealMargin
            if hi - lo >= length || lo < now { return lo }
            if hi > now + length { return hi - length }
            return now
        }
        return CGPoint(x: axis(rect.minX, rect.maxX, viewport.width, current.x),
                       y: axis(rect.minY, rect.maxY, viewport.height, current.y))
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
