import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the canvas's zoom and viewport (M4B_CONTRACT §1.3, M4C_CONTRACT §2.3, §4.1,
/// §7.2). Every page opens at the overview (`fitAll`, below fit-to-width on a height-bound page — the
/// root cause of 0.5.1's "cannot pinch out"); a programmatic `zoomScale` survives layout passes and
/// SwiftUI updates (F4: the scroll view really zooms); the end of a pinch clamps, centres, redraws
/// once and reports the ratio on the next turn; a rotation keeps the overview or the absolute zoom
/// (D4 / M4C-24); the paper window is stretched, not redrawn, while a pinch is live (F3); the viewport
/// is never delivered inside a layout pass; the double tap and the finger recogniser are wired as
/// §4.1 / §2.2 say; strokes centred outside the paper are dropped (M4C-25). 1.1 (M7A_CONTRACT §7.2):
/// a growing last cell takes the light path (no new drawing, the margins and the offset follow); the
/// end of an erasure is reported once after the settle wait; the pen's touch is reported; new strokes
/// beyond the last cell's limit or over the budget are refused (never another device's); the
/// round button's clearance; only this canvas's own strokes are a finger tap's dots; a leaving
/// eraser tap puts back what it erased.
@MainActor
final class InkCanvasViewTests: XCTestCase {
    /// Counts the deliveries of `onViewportChange`, and collects `onZoomRatioChange` / `onZoomingChange`
    /// and (1.1) `onEraseEnded`, `onPenDown`, `onStrokeBudget`, `onGrowthCapReached`, `onInkBoundsChanged`.
    private final class Probe {
        var count = 0
        var last: PaperViewport?
        var ratios: [CGFloat] = []
        var zooming: [Bool] = []
        var erased: [Int] = []
        var penDowns = 0
        var budget: [StrokeBudget.Event] = []
        var caps = 0
        var inkBounds = 0
    }

    /// Collects `onTap` (1.0.1), with the zoom and the ledger's live stroke ids at the moment of each
    /// report, and the zooms `tapLeavesPage` was asked with.
    private final class TapLog {
        weak var coordinator: InkCanvasView.Coordinator?
        var points: [CGPoint] = []
        var zooms: [CGFloat] = []
        var askedZooms: [CGFloat] = []
        var liveIds: [Set<String>] = []
    }

    /// 2026-10-07 (a Wednesday) at 10:00 in the device's time zone, like the screenshot mode.
    private let now = DayKey(year: 2026, month: 10, day: 7).startOfDay().addingTimeInterval(10 * 3600)
    private let wednesday = DayKey(year: 2026, month: 10, day: 7)

    // MARK: Fixtures

    private func makeMonth(inkBottoms: [CellKey: CGFloat] = [:]) -> (layout: MonthPageLayout, paper: PaperContent) {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: inkBottoms, now: now))
        let paper = PaperContent.month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: [:]))
        return (layout, paper)
    }

    /// The week of 10/5: 1400 × 1920 lu.
    private func makeWeek() -> (layout: WeekPageLayout, paper: PaperContent) {
        let layout = WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: [], inkBottoms: [:], now: now))
        return (layout, .week(WeekPaperContent(layout: layout)))
    }

    /// 10/7: 1000 × 3100 lu (1.1: the 24 hours, 2400, and the empty free memo area below them, 700;
    /// the overview is the 24 hours).
    private func makeDay(inkBottoms: [CellKey: CGFloat] = [:]) -> (layout: DayPageLayout, paper: PaperContent) {
        let layout = DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: [], inkBottoms: inkBottoms, now: now))
        return (layout, .day(DayPaperContent(layout: layout)))
    }

    /// 2026, no events: 1400 × 1860 lu (10/7's cell is (1064, 360, 112, 60)).
    private func makeYear() -> (layout: YearPageLayout, paper: PaperContent) {
        let layout = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
        return (layout, .year(YearPaperContent(layout: layout, monthNames: (1...12).map { "\($0)月" })))
    }

    /// The canvas as the screen builds it. `initialScrollX` is computed for the readable zoom (it is
    /// not used at the default ratio 1; a test that needs it computes its own).
    private func makeView(layout: any PageLayout, paper: PaperContent, viewportWidth: CGFloat, probe: Probe,
                          initialZoomRatio: CGFloat = 1, initialPaperOffset: CGPoint? = nil, doubleTapEnabled: Bool = false,
                          tool: CanvasTool = .eraser, allowFinger: Bool = false, page: InkPage? = nil,
                          onZoomRatioChange: @escaping (CGFloat) -> Void = { _ in },
                          onZoomingChange: @escaping (Bool) -> Void = { _ in },
                          readOnly: Bool = false,
                          onBlockedInput: @escaping () -> Void = {},
                          onTap: @escaping (CGPoint, CGFloat) -> Void = { _, _ in },
                          tapLeavesPage: @escaping (CGPoint, CGFloat) -> Bool = { _, _ in false },
                          undoTrigger: Int = 0, bottomClearance: CGFloat = 0) -> InkCanvasView {
        let page = page ?? InkPage.empty(pageId: layout.pageId)
        return InkCanvasView(
            layout: layout,
            paper: paper,
            tool: tool,
            allowFinger: allowFinger,
            page: .constant(page),
            initialScrollY: PageNavigation.initialScrollY(layout, now: now),
            initialScrollX: PageNavigation.initialScrollX(
                layout, now: now,
                visibleWidth: ZoomPolicy.visibleWidth(layout.kind, viewportWidth: viewportWidth, zoom: ZoomPolicy.readableZoom(layout.kind))
            ),
            onTap: onTap,
            onInkBoundsChanged: { probe.inkBounds += 1 },
            undoTrigger: undoTrigger,
            redoTrigger: 0,
            onViewportChange: { viewport in
                probe.count += 1
                probe.last = viewport
            },
            initialZoomRatio: initialZoomRatio,
            initialPaperOffset: initialPaperOffset,
            doubleTapEnabled: doubleTapEnabled,
            onZoomRatioChange: onZoomRatioChange,
            onZoomingChange: onZoomingChange,
            readOnly: readOnly,
            onBlockedInput: onBlockedInput,
            tapLeavesPage: tapLeavesPage,
            onPenDown: { probe.penDowns += 1 },
            onEraseEnded: { probe.erased.append($0) },
            onStrokeBudget: { probe.budget.append($0) },
            onGrowthCapReached: { probe.caps += 1 },
            bottomClearance: bottomClearance
        )
    }

    /// A canvas wired like `makeUIView` (the coordinator attached to a container), with its probe.
    @MainActor
    private struct Rig {
        let view: InkCanvasView
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let probe: Probe
        var canvas: PKCanvasView { container.canvasView }
        var paperView: PaperView { container.paperView }

        /// The parent's layout pass at a new size (rotation, Split View, the band growing).
        func layout(width: CGFloat, height: CGFloat) {
            container.frame = CGRect(x: 0, y: 0, width: width, height: height)
            container.layoutSubviews()
        }
    }

    private func attach(_ view: InkCanvasView, paper: PaperContent, probe: Probe) -> Rig {
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        return Rig(view: view, coordinator: coordinator, container: container, probe: probe)
    }

    /// A canvas laid out once at `width` × `height` and settled. The first layout's own end-of-pinch
    /// call delivers the ratio and `zooming` false on the next turn; `clear` drops them so a test
    /// collects only what it causes.
    private func makeRig(layout: any PageLayout, paper: PaperContent, width: CGFloat, height: CGFloat,
                         initialZoomRatio: CGFloat = 1, initialPaperOffset: CGPoint? = nil, doubleTapEnabled: Bool = false,
                         tool: CanvasTool = .eraser, allowFinger: Bool = false, page: InkPage? = nil, clear: Bool = true,
                         readOnly: Bool = false, onTap: @escaping (CGPoint, CGFloat) -> Void = { _, _ in },
                         tapLeavesPage: @escaping (CGPoint, CGFloat) -> Bool = { _, _ in false }) async -> Rig {
        let probe = Probe()
        let view = makeView(
            layout: layout, paper: paper, viewportWidth: width, probe: probe,
            initialZoomRatio: initialZoomRatio, initialPaperOffset: initialPaperOffset, doubleTapEnabled: doubleTapEnabled,
            tool: tool, allowFinger: allowFinger, page: page,
            onZoomRatioChange: { probe.ratios.append($0) },
            onZoomingChange: { probe.zooming.append($0) },
            readOnly: readOnly,
            onTap: onTap,
            tapLeavesPage: tapLeavesPage
        )
        let rig = attach(view, paper: paper, probe: probe)
        rig.layout(width: width, height: height)
        await settle()
        if clear {
            probe.ratios.removeAll()
            probe.zooming.removeAll()
        }
        return rig
    }

    /// The end-of-pinch path as UIKit drives it, without a pinch: will-begin, the zoom, did-end.
    private func pinch(_ rig: Rig, to zoom: CGFloat) {
        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(zoom, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: zoom)
    }

    private func fitAll(_ layout: any PageLayout, _ width: CGFloat, _ height: CGFloat) -> CGFloat {
        ZoomPolicy.fitAll(layout.kind, overview: ZoomPolicy.overviewSize(layout), viewport: CGSize(width: width, height: height))
    }

    /// A short pen stroke (5 points 3 lu apart, a 3.5 lu nib) starting at `origin` in paper coordinates.
    private func makeStroke(at origin: CGPoint) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<5 {
            points.append(PKStrokePoint(
                location: CGPoint(x: origin.x + CGFloat(i) * 3, y: origin.y + CGFloat(i)),
                timeOffset: TimeInterval(i) * 0.01,
                size: CGSize(width: 3.5, height: 3.5),
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ))
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()), transform: .identity, mask: nil)
    }

    /// A ledger stroke of `cell` with cell-relative `points` (a 3.5 lu nib), entered at `t` (ms).
    private func makeInkStroke(id: String, cell: CellKey, t: Int, points: [(CGFloat, CGFloat)]) -> InkStroke {
        let pts = points.enumerated().map { i, p in
            InkPoint(x: p.0, y: p.1, dtMs: i * 10, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)
        }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: "ipad-1", points: pts)
    }

    /// Lets the queued main-actor tasks (the next-turn deliveries) run.
    private func settle() async {
        for _ in 0..<8 {
            await Task.yield()
        }
    }

    // MARK: §2.3 — the pinch's root cause 1 and F4

    /// Root cause 1 of M4C_CONTRACT §2.1: 0.5.1 opened at fit-to-width (0.7314), which was also the
    /// lower limit, so the pinch-in bounced back. On a height-bound page the limit is now below
    /// fit-to-width, and a programmatic `zoomScale` (scrollViewDidZoom → contentSize / insets /
    /// syncPaperFrame / notifyViewport) survives layout passes and updates. F4 (§2.5): the scroll view
    /// really zooms — its pinch recogniser exists, `setZoomScale` takes effect, the content size follows
    /// and the drawing's coordinates stay paper coordinates.
    func testOverviewGoesBelowFitWidthAndSurvivesLayoutPassesAndUpdates() async {
        let (layout, paper) = makeWeek() // 1400 × 1920
        let probe = Probe()
        let view = makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe)
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: 1024, height: 1180)
        container.layoutSubviews()
        await settle()
        let canvas = container.canvasView
        let fitWidth = ZoomPolicy.fitZoom(.week, viewportWidth: 1024) // 0.7314 = 0.5.1's minZoom
        let fitAll = ZoomPolicy.fitAll(.week, overview: ZoomPolicy.overviewSize(layout), viewport: CGSize(width: 1024, height: 1180)) // 0.6146
        XCTAssertLessThan(canvas.minimumZoomScale, fitWidth, "0.5.1 stopped here: the lower limit is below fit-to-width")
        XCTAssertEqual(canvas.minimumZoomScale, fitAll, accuracy: 1e-6)
        XCTAssertEqual(canvas.zoomScale, fitAll, accuracy: 1e-6, "opens at the overview")
        XCTAssertEqual(canvas.contentInset.left, (1024 - 1400 * fitAll) / 2, accuracy: 0.01) // 81.8
        // UIKit snaps contentOffset to the pixel grid (−82.0 for −81.79 on the CI simulator): ± 0.5 pt.
        XCTAssertEqual(canvas.contentOffset.x, -canvas.contentInset.left, accuracy: 0.5, "the top-left")
        XCTAssertLessThan(canvas.minimumZoomScale, canvas.maximumZoomScale)
        XCTAssertTrue(canvas.isScrollEnabled)
        XCTAssertEqual(canvas.drawingPolicy, .pencilOnly)
        // F4 (§2.5): zooming is enabled — the limits differ and the delegate hands back a view to zoom.
        XCTAssertNotNil(canvas.pinchGestureRecognizer, "F4: PKCanvasView must offer a pinch (M4C-23 withdrawn)")
        XCTAssertNotNil(coordinator.viewForZooming(in: canvas), "F4: the canvas's drawing subview is the view to zoom")

        // A stroke on the paper: its render bounds are paper coordinates and must not change with the zoom.
        canvas.drawing = PKDrawing(strokes: [makeStroke(at: CGPoint(x: 300, y: 400))])
        guard let boundsBefore = canvas.drawing.strokes.first?.renderBounds else { return XCTFail("no stroke") }

        canvas.setZoomScale(fitWidth, animated: false) // 0.5.1's lower limit
        canvas.setZoomScale(fitAll, animated: false) // the end of a pinch-in
        XCTAssertEqual(canvas.zoomScale, fitAll, accuracy: 1e-6, "goes below fit-to-width")
        let target = fitAll * 2 // 1.2292
        canvas.setZoomScale(target, animated: false)
        XCTAssertEqual(canvas.zoomScale, target, accuracy: 1e-6, "F4: setZoomScale takes effect")
        XCTAssertEqual(canvas.contentSize.width, 1400 * target, accuracy: 0.5, "F4: the content size is paper × zoom")
        XCTAssertEqual(canvas.contentSize.height, 1920 * target, accuracy: 0.5)
        guard let fromUIKit = coordinator.contentSizeFromUIKit else { return XCTFail("scrollViewDidZoom did not run") }
        XCTAssertEqual(fromUIKit.width, 1400 * target, accuracy: 1,
                       "F4 (§2.5): UIScrollView's own contentSize (from the zooming view's frame) disagrees with paper × zoom — drop the assignment in scrollViewDidZoom")
        XCTAssertEqual(fromUIKit.height, 1920 * target, accuracy: 1)
        guard let boundsAfter = canvas.drawing.strokes.first?.renderBounds else { return XCTFail("the stroke vanished") }
        XCTAssertEqual(boundsAfter.minX, boundsBefore.minX, accuracy: 0.01, "F4: the drawing stays in paper coordinates")
        XCTAssertEqual(boundsAfter.minY, boundsBefore.minY, accuracy: 0.01)
        XCTAssertEqual(boundsAfter.width, boundsBefore.width, accuracy: 0.01)
        XCTAssertEqual(boundsAfter.height, boundsBefore.height, accuracy: 0.01)

        container.setNeedsLayout()
        container.layoutSubviews() // the parent's layout pass of every pinch frame
        container.frame.size.height -= 30
        container.layoutSubviews() // the band grew: only the height changed (§1.3 step 5)
        XCTAssertEqual(canvas.minimumZoomScale, 1150.0 / 1920, accuracy: 1e-4, "min is the new fitAll (0.599)")
        await settle()
        coordinator.update(from: view) // the next-turn viewport delivery → SwiftUI's updateUIView
        container.layoutSubviews()
        XCTAssertEqual(canvas.zoomScale, target, accuracy: 1e-6, "the zoom survives layout passes and updates")
        XCTAssertEqual(container.paperView.zoomScale, target, accuracy: 1e-6)
        XCTAssertEqual(probe.last?.zoom ?? 0, target, accuracy: 1e-6)
        XCTAssertEqual(canvas.contentSize.width, 1400 * target, accuracy: 0.01)
        XCTAssertEqual(canvas.contentInset.left, 0, accuracy: 0.01, "the paper is wider than the screen: no margin")
        canvas.setZoomScale(fitAll * 0.5, animated: false) // the lower limit: stops at the new fitAll
        XCTAssertEqual(canvas.zoomScale, canvas.minimumZoomScale, accuracy: 1e-6)
    }

    /// The iPad's month is width-bound: nothing changes from 0.5.1 (fit-to-width, no margins), and a
    /// height change leaves the limits alone.
    func testOverviewLeavesIPadMonthUnchanged() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        let fitWidth = 1024.0 / 1400
        XCTAssertEqual(rig.canvas.minimumZoomScale, fitWidth, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.zoomScale, fitWidth, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.contentInset, .zero, "1280 pt of paper in 1180 pt: no vertical margin either")
        rig.layout(width: 1024, height: 1150)
        XCTAssertEqual(rig.canvas.minimumZoomScale, fitWidth, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.zoomScale, fitWidth, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.contentInset, .zero)
    }

    /// The iPhone's day page is height-bound (0.2417): 242 pt of paper centred in 402 pt, the offset,
    /// the viewport and the paper view all carrying the 80 pt margin.
    func testOverviewCentresANarrowPaper() async {
        let (layout, paper) = makeDay()
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580)
        let zoom = fitAll(layout, 402, 580)
        XCTAssertEqual(zoom, 0.2417, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.zoomScale, zoom, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.contentInset.left, 80, accuracy: 1)
        XCTAssertEqual(rig.canvas.contentInset.right, rig.canvas.contentInset.left, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.contentOffset.x, -80, accuracy: 1)
        XCTAssertEqual(rig.probe.last?.offsetX ?? 0, -80, accuracy: 1)
        XCTAssertEqual(rig.probe.last?.zoom ?? 0, zoom, accuracy: 1e-6)
        XCTAssertEqual(rig.paperView.frame.origin.x, 80, accuracy: 1)
        XCTAssertEqual(rig.paperView.frame.origin.y, 0, accuracy: 0.01)
    }

    // MARK: §2.3 — F3 and the end of a pinch

    /// F3: while the canvas is zooming (`liveOverride`, since XCTest cannot pinch) the paper window is
    /// stretched with a transform and neither redrawn nor given the new zoom; the end of the pinch
    /// puts the transform back and redraws once.
    func testSyncPaperFrameDoesNotTouchZoomScaleWhileLive() async {
        let (layout, paper) = makeDay()
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580)
        let zoom = fitAll(layout, 402, 580)
        XCTAssertFalse(rig.paperView.contentWindow.isEmpty, "a window exists after the first layout")
        XCTAssertEqual(rig.paperView.zoomScale, zoom, accuracy: 1e-6)
        let requests = rig.paperView.displayRequestCount

        rig.coordinator.liveOverride = true
        rig.canvas.setZoomScale(2 * zoom, animated: false) // → scrollViewDidZoom → syncPaperFrame (live)
        XCTAssertEqual(rig.canvas.zoomScale, 2 * zoom, accuracy: 1e-6)
        XCTAssertEqual(rig.paperView.zoomScale, zoom, accuracy: 1e-6, "the paper's zoom is left alone while live")
        XCTAssertEqual(rig.paperView.displayRequestCount, requests, "no redraw while live")
        XCTAssertEqual(rig.paperView.transform.a, 2, accuracy: 1e-6, "the window is stretched instead")
        XCTAssertEqual(rig.paperView.transform.d, 2, accuracy: 1e-6)

        rig.coordinator.liveOverride = nil
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: 2 * zoom)
        XCTAssertEqual(rig.paperView.zoomScale, 2 * zoom, accuracy: 1e-6, "the end of the pinch gives the paper the new zoom")
        XCTAssertEqual(rig.paperView.transform, .identity)
        XCTAssertGreaterThan(rig.paperView.displayRequestCount, requests, "redrawn once at the end")
    }

    /// The end-of-pinch path (§2.4): (a) the ratio is reported once, on the next turn, with `zooming`
    /// true / false around it, the margins recomputed; (b) when the minimum rose during the pinch
    /// (§1.6) the live zoom is not touched, and `scrollViewDidEndZooming` clamps it once.
    func testEndOfPinchPathClampsAndReportsTheRatio() async {
        // (a) The iPhone's day page, pinched to twice the overview.
        let (day, dayPaper) = makeDay()
        let rig = await makeRig(layout: day, paper: dayPaper, width: 402, height: 580)
        let zoom = fitAll(day, 402, 580)
        XCTAssertEqual(rig.probe.ratios, [], "the first layout's own report was cleared")
        pinch(rig, to: 2 * zoom)
        XCTAssertEqual(rig.probe.ratios, [], "nothing is reported synchronously")
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 2, accuracy: 1e-3)
        XCTAssertEqual(rig.probe.zooming, [true, false])
        XCTAssertEqual(rig.paperView.transform, .identity)
        XCTAssertEqual(rig.canvas.contentInset, .zero, "483 pt of paper in 402 pt: no margin")
        XCTAssertEqual(rig.canvas.zoomScale, 2 * zoom, accuracy: 1e-6)

        // (b) The week at 1024 × 1150 (fitAll 0.599), pinched to 0.60; the band shrinks during the
        // pinch and the paper area grows to 1180 (fitAll 0.6146 > 0.60).
        let (week, weekPaper) = makeWeek()
        let rig2 = await makeRig(layout: week, paper: weekPaper, width: 1024, height: 1150)
        XCTAssertEqual(rig2.canvas.minimumZoomScale, 1150.0 / 1920, accuracy: 1e-4)
        rig2.coordinator.scrollViewWillBeginZooming(rig2.canvas, with: nil)
        rig2.canvas.setZoomScale(0.60, animated: false)
        rig2.coordinator.liveOverride = true
        rig2.layout(width: 1024, height: 1180)
        XCTAssertEqual(rig2.canvas.minimumZoomScale, 1180.0 / 1920, accuracy: 1e-4, "the limits follow at once")
        XCTAssertEqual(rig2.canvas.zoomScale, 0.60, accuracy: 1e-6, "the live zoom is not touched")
        rig2.coordinator.liveOverride = nil
        rig2.coordinator.scrollViewDidEndZooming(rig2.canvas, with: nil, atScale: 0.60)
        XCTAssertEqual(rig2.canvas.zoomScale, 1180.0 / 1920, accuracy: 1e-4, "clamped to the new minimum once")
        XCTAssertEqual(rig2.canvas.contentInset.left, 81.8, accuracy: 0.1)
        XCTAssertEqual(rig2.paperView.transform, .identity)
        await settle()
        XCTAssertEqual(rig2.probe.ratios.last ?? 0, 1, accuracy: 1e-6)
        XCTAssertEqual(rig2.probe.zooming, [true, false])
    }

    // MARK: §2.3 — rotation and height changes (D4 / M4C-24)

    /// (a) The overview stays the overview across a rotation; (b) a zoomed-in paper keeps its absolute
    /// zoom; (c) a clamp does not forget the chosen zoom: it comes back with the range. No ratio is
    /// reported for any of it.
    func testRotationKeepsTheOverviewAndTheAbsoluteZoom() async {
        // (a) The iPhone's month: 402 × 700 → 874 × 402.
        let (month, monthPaper) = makeMonth()
        let rigA = await makeRig(layout: month, paper: monthPaper, width: 402, height: 700)
        XCTAssertEqual(rigA.canvas.zoomScale, 0.2871, accuracy: 1e-4)
        rigA.layout(width: 874, height: 402)
        XCTAssertEqual(rigA.canvas.zoomScale, fitAll(month, 874, 402), accuracy: 1e-6, "the overview follows the new overview")
        XCTAssertEqual(rigA.canvas.zoomScale, 0.3829, accuracy: 1e-4)
        await settle()
        XCTAssertEqual(rigA.probe.ratios, [])

        // (b) The iPhone's day at 1.0 (ratio 4.14) → landscape (fitAll 0.0958, max 3.496) → back.
        let (day, dayPaper) = makeDay()
        let rigB = await makeRig(layout: day, paper: dayPaper, width: 402, height: 580)
        pinch(rigB, to: 1.0)
        await settle()
        XCTAssertEqual(rigB.probe.ratios.count, 1)
        XCTAssertEqual(rigB.probe.ratios.first ?? 0, 1 / fitAll(day, 402, 580), accuracy: 1e-3)
        XCTAssertEqual(rigB.probe.ratios.first ?? 0, 4.14, accuracy: 0.01)
        rigB.layout(width: 874, height: 230)
        XCTAssertEqual(rigB.canvas.minimumZoomScale, fitAll(day, 874, 230), accuracy: 1e-6)
        XCTAssertEqual(rigB.canvas.maximumZoomScale, ZoomPolicy.maxZoom(.day, viewportWidth: 874), accuracy: 1e-6)
        XCTAssertEqual(rigB.canvas.zoomScale, 1.0, accuracy: 1e-6, "the handwriting keeps its size")
        rigB.layout(width: 402, height: 580)
        XCTAssertEqual(rigB.canvas.zoomScale, 1.0, accuracy: 1e-6)
        await settle()
        XCTAssertEqual(rigB.probe.ratios.count, 1, "a rotation reports no ratio")

        // (c) Landscape at 3.45 (ratio ≈ 36) → portrait clamps to max 1.608 → landscape restores 3.45.
        let rigC = await makeRig(layout: day, paper: dayPaper, width: 874, height: 230)
        XCTAssertGreaterThan(rigC.canvas.maximumZoomScale, 3.45)
        pinch(rigC, to: 3.45)
        await settle()
        XCTAssertEqual(rigC.probe.ratios.count, 1)
        rigC.layout(width: 402, height: 580)
        XCTAssertEqual(rigC.canvas.maximumZoomScale, 1.608, accuracy: 1e-4)
        XCTAssertEqual(rigC.canvas.zoomScale, 1.608, accuracy: 1e-4, "clamped to the new maximum")
        rigC.layout(width: 874, height: 230)
        XCTAssertEqual(rigC.canvas.zoomScale, 3.45, accuracy: 1e-6, "the chosen zoom comes back")
        await settle()
        XCTAssertEqual(rigC.probe.ratios.count, 1, "the clamp reports no ratio")
    }

    /// A zoomed-in page whose paper area changes height: the limits follow, the zoom does not move.
    func testHeightOnlyChangeNeverReappliesTheMinimumWhileZoomedIn() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, initialZoomRatio: 2)
        let target = 2 * fitAll(layout, 1024, 1180) // 1.229
        XCTAssertEqual(rig.canvas.zoomScale, target, accuracy: 1e-6)
        rig.layout(width: 1024, height: 1150)
        XCTAssertEqual(rig.canvas.zoomScale, target, accuracy: 1e-6)
        XCTAssertEqual(rig.canvas.minimumZoomScale, 1150.0 / 1920, accuracy: 1e-4)
        await settle()
        XCTAssertEqual(rig.probe.ratios, [])
    }

    /// The overview follows the new overview when the paper area changes height (D1), silently.
    func testHeightChangeAtTheOverviewFollowsTheNewFitAll() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        XCTAssertEqual(rig.canvas.zoomScale, 1180.0 / 1920, accuracy: 1e-4)
        rig.layout(width: 1024, height: 1150)
        XCTAssertEqual(rig.canvas.minimumZoomScale, 1150.0 / 1920, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.zoomScale, rig.canvas.minimumZoomScale, accuracy: 1e-6, "still the overview")
        await settle()
        XCTAssertEqual(rig.probe.ratios, [])
        XCTAssertEqual(rig.probe.last?.zoom ?? 0, 1150.0 / 1920, accuracy: 1e-4)
    }

    /// `applyPending`'s `applyBounds`: a month row grown by ink (175 → 400 lu) lowers the overview
    /// of a height-bound landscape iPad (830 / 1050 → 830 / 1275); the overview follows, a zoomed-in
    /// paper only gets the new limits.
    func testMonthRowGrowthLowersTheOverviewZoomInLandscape() async {
        let (layout, paper) = makeMonth()
        let (grown, grownPaper) = makeMonth(inkBottoms: [.day(wednesday): 388])
        XCTAssertEqual(grown.memo.minY, 1275, accuracy: 0.01, "one row of 400 lu")
        let lowered = 830.0 / 1275 // 0.651

        // At the overview.
        let rig = await makeRig(layout: layout, paper: paper, width: 1366, height: 830)
        XCTAssertEqual(rig.canvas.zoomScale, 830.0 / 1050, accuracy: 1e-4)
        let grownView = makeView(layout: grown, paper: grownPaper, viewportWidth: 1366, probe: rig.probe,
                                 onZoomRatioChange: { [probe = rig.probe] in probe.ratios.append($0) })
        rig.coordinator.update(from: grownView)
        await settle()
        XCTAssertEqual(rig.canvas.minimumZoomScale, lowered, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.zoomScale, lowered, accuracy: 1e-4, "the overview follows")
        XCTAssertEqual(rig.probe.last?.zoom ?? 0, lowered, accuracy: 1e-4)
        XCTAssertEqual(rig.probe.ratios, [], "the overview's change is not a pinch")

        // Zoomed in (ratio 2 = 1.581): the limits only.
        let rig2 = await makeRig(layout: layout, paper: paper, width: 1366, height: 830, initialZoomRatio: 2)
        let zoomedIn = 2 * 830.0 / 1050
        XCTAssertEqual(rig2.canvas.zoomScale, zoomedIn, accuracy: 1e-4)
        let grownView2 = makeView(layout: grown, paper: grownPaper, viewportWidth: 1366, probe: rig2.probe)
        rig2.coordinator.update(from: grownView2)
        await settle()
        XCTAssertEqual(rig2.canvas.minimumZoomScale, lowered, accuracy: 1e-4)
        XCTAssertEqual(rig2.canvas.zoomScale, zoomedIn, accuracy: 1e-4, "a zoomed-in paper is not moved")
    }

    // MARK: §2.3 — the screenshot arguments

    /// `initialZoomRatio` / `initialPaperOffset` (`--screenshot-zoom` / `--screenshot-offset`): the
    /// page opens at ratio × fitAll with the paper point at the top-left, the heading gets the same
    /// viewport, and the first layout's own end-of-pinch call reports the ratio once. A ratio beyond
    /// the range is clamped to `maxZoom` (ratio 5 on the 13-inch month: 3.657 → 2.9257).
    func testInitialZoomRatioAndPaperOffset() async {
        let (week, weekPaper) = makeWeek()
        let rig = await makeRig(layout: week, paper: weekPaper, width: 1024, height: 1180,
                                initialZoomRatio: 2, initialPaperOffset: CGPoint(x: 400, y: 200), clear: false)
        let zoom = 2 * fitAll(week, 1024, 1180) // 1.2292
        XCTAssertEqual(rig.canvas.zoomScale, zoom, accuracy: 1e-6)
        // UIKit snaps contentOffset to the pixel grid ((491.5, 246.0) for (491.67, 245.83) on the CI simulator): ± 0.5 pt.
        XCTAssertEqual(rig.canvas.contentOffset.x, 400 * zoom, accuracy: 0.5)
        XCTAssertEqual(rig.canvas.contentOffset.y, 200 * zoom, accuracy: 0.5)
        XCTAssertEqual(rig.probe.last?.offsetX ?? 0, 400 * zoom, accuracy: 0.5, "the heading's viewport")
        XCTAssertEqual(rig.probe.last?.zoom ?? 0, zoom, accuracy: 1e-6)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the first layout's own end-of-pinch call")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 2, accuracy: 1e-3)
        XCTAssertEqual(rig.probe.zooming, [false])

        let (month, monthPaper) = makeMonth()
        let rig2 = await makeRig(layout: month, paper: monthPaper, width: 1024, height: 1180, initialZoomRatio: 5, clear: false)
        XCTAssertEqual(rig2.canvas.zoomScale, ZoomPolicy.maxZoom(.month, viewportWidth: 1024), accuracy: 1e-6)
        XCTAssertEqual(rig2.canvas.zoomScale, 2.9257, accuracy: 1e-4, "clamped to maxZoom")
        XCTAssertEqual(rig2.probe.ratios.first ?? 0, 2.9257 / (1024.0 / 1400), accuracy: 1e-3, "the clamped ratio (4.0) is what is reported")
    }

    // MARK: §4.1 — the recognisers

    /// The double tap: two taps of one finger, direct touches only, enabled only when the owner asks
    /// and no overlay tool is up. The finger recogniser (F2): on with an overlay tool and 「指でも書く」.
    func testDoubleTapRecognizerSetup() {
        let (layout, paper) = makeMonth()
        let probe = Probe()

        let week = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true), paper: paper, probe: probe)
        let r = week.coordinator.doubleTapRecognizer
        XCTAssertEqual(r.numberOfTapsRequired, 2)
        XCTAssertEqual(r.numberOfTouchesRequired, 1)
        XCTAssertEqual(r.allowedTouchTypes, [NSNumber(value: UITouch.TouchType.direct.rawValue)])
        XCTAssertTrue(r.isEnabled)
        XCTAssertTrue(r.view === week.canvas, "on the canvas")
        XCTAssertEqual(week.coordinator.tapRecognizer.allowedTouchTypes, [NSNumber(value: UITouch.TouchType.direct.rawValue)])
        XCTAssertFalse(week.coordinator.fingerRecognizer.isEnabled, "the eraser needs no finger recogniser")
        XCTAssertTrue(week.coordinator.fingerRecognizer.view === week.container, "on the container")

        let day = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: false), paper: paper, probe: probe)
        XCTAssertFalse(day.coordinator.doubleTapRecognizer.isEnabled)

        let lasso = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true, tool: .lasso, allowFinger: true), paper: paper, probe: probe)
        XCTAssertFalse(lasso.coordinator.doubleTapRecognizer.isEnabled, "off with an overlay tool")
        XCTAssertTrue(lasso.coordinator.fingerRecognizer.isEnabled, "the lasso takes the finger")
        XCTAssertEqual(lasso.coordinator.fingerRecognizer.allowedTouchTypes, [NSNumber(value: UITouch.TouchType.direct.rawValue)])
        XCTAssertFalse(lasso.coordinator.fingerRecognizer.cancelsTouchesInView)

        let pen = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .ink(InkPresets.defaultPen), allowFinger: true), paper: paper, probe: probe)
        XCTAssertFalse(pen.coordinator.fingerRecognizer.isEnabled, "the pen draws through PencilKit")

        let lassoPencil = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .lasso, allowFinger: false), paper: paper, probe: probe)
        XCTAssertFalse(lassoPencil.coordinator.fingerRecognizer.isEnabled, "the finger scrolls when it may not write")

        // The tool changes under the same canvas: the recognisers follow.
        lasso.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true, tool: .eraser, allowFinger: true))
        XCTAssertTrue(lasso.coordinator.doubleTapRecognizer.isEnabled)
        XCTAssertFalse(lasso.coordinator.fingerRecognizer.isEnabled)
    }

    /// With 「指でも書く」 on, PencilKit's drawing recogniser begins on the finger's touch-down: the
    /// taps run alongside it, nothing else does (§4.1).
    func testTapRecognizersAllowSimultaneousDrawing() {
        let (layout, paper) = makeMonth()
        let probe = Probe()
        let rig = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true), paper: paper, probe: probe)
        let c = rig.coordinator
        let drawing = rig.canvas.drawingGestureRecognizer
        XCTAssertTrue(c.gestureRecognizer(c.tapRecognizer, shouldRecognizeSimultaneouslyWith: drawing))
        XCTAssertTrue(c.gestureRecognizer(c.doubleTapRecognizer, shouldRecognizeSimultaneouslyWith: drawing))
        XCTAssertFalse(c.gestureRecognizer(c.tapRecognizer, shouldRecognizeSimultaneouslyWith: rig.canvas.panGestureRecognizer))
        XCTAssertFalse(c.gestureRecognizer(c.doubleTapRecognizer, shouldRecognizeSimultaneouslyWith: rig.canvas.panGestureRecognizer))
        XCTAssertFalse(c.gestureRecognizer(c.fingerRecognizer, shouldRecognizeSimultaneouslyWith: drawing))
        XCTAssertFalse(c.gestureRecognizer(c.fingerRecognizer, shouldRecognizeSimultaneouslyWith: rig.canvas.panGestureRecognizer))
    }

    /// `dotStrokeIds` (M4C-22): the strokes of the last half second whose bounds fit in 16 pt and
    /// whose centre is within 24 pt of the double tap — the two dots a finger's taps drew; not an old
    /// dot, not a line. 1.1 (0-21): "of the last half second" is what this canvas added itself
    /// (`noteRecentAdd`) by the device's monotonic clock (`uptime`, pinned here), not the strokes' `t`.
    func testDotsDrawnByTheDoubleTapAreFound() {
        let (layout, paper) = makeMonth()
        let cell = CellKey.day(wednesday)
        guard let origin = layout.cells[cell]?.origin else { return XCTFail("no cell for 10/7") }
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        var page = InkPage.empty(pageId: layout.pageId)
        page.add(makeInkStroke(id: "dot1", cell: cell, t: nowMs - 100, points: [(100, 100), (101.5, 101.5)]))
        page.add(makeInkStroke(id: "dot2", cell: cell, t: nowMs - 100, points: [(105, 104), (106.5, 105.5)]))
        page.add(makeInkStroke(id: "old", cell: cell, t: nowMs - 10_000, points: [(100, 100), (101.5, 101.5)]))
        page.add(makeInkStroke(id: "line", cell: cell, t: nowMs - 100, points: [(100, 100), (200, 100), (300, 100)]))
        let probe = Probe()
        let rig = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, page: page), paper: paper, probe: probe)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 4)
        let tapUptime: TimeInterval = 1_000
        rig.coordinator.uptime = { tapUptime }
        rig.coordinator.noteRecentAdd("old", at: tapUptime - 10)
        rig.coordinator.noteRecentAdd("dot1", at: tapUptime - 0.1)
        rig.coordinator.noteRecentAdd("dot2", at: tapUptime - 0.1)
        rig.coordinator.noteRecentAdd("line", at: tapUptime - 0.1)
        let near = CGPoint(x: origin.x + 103, y: origin.y + 103)
        let ids = rig.coordinator.dotStrokeIds(near: near, zoom: 0.5, within: 0.5)
        XCTAssertEqual(Set(ids), ["dot1", "dot2"])
        // 48 lu away at zoom 0.5 (24 pt): too far.
        XCTAssertEqual(rig.coordinator.dotStrokeIds(near: CGPoint(x: near.x + 60, y: near.y), zoom: 0.5, within: 0.5), [])
        // At zoom 2 the same 60 lu are 120 pt: still too far; the dots are found at the right place.
        XCTAssertEqual(Set(rig.coordinator.dotStrokeIds(near: near, zoom: 2, within: 0.5)), ["dot1", "dot2"])
    }

    // MARK: 1.0.1 — the single tap on an iPhone's year page

    /// A finger tap that leaves the page (`tapLeavesPage`) with 「指でも書く」 removes the dot PencilKit
    /// drew for it before `onTap` (the owner leaves the page right after), as one undoable op. The
    /// window is `singleTapDotWindow` (1 s, the double tap's is 0.5 s): with the clock pinned, a dot of
    /// 0.3 s and one of 0.8 s go, one of 1.5 s, an old dot and a line stay. Nothing is removed when the
    /// tap stays on the page (the edit sheet), without 「指でも書く」, or read only. `onTap` is called once
    /// in every case, with the zoom `tapLeavesPage` was asked with. The iPhone's conditions: 402 × 569,
    /// `.anyInput`, the year's overview (zoom 402 / 1400). 1.1 (0-21): the dots' ages are the times
    /// this canvas added them (`noteRecentAdd`, the monotonic `uptime` pinned), not their `t`.
    func testLeavingFingerTapRemovesItsDotBeforeReporting() async {
        let (layout, paper) = makeYear()
        let cell = CellKey.yearDay(month: 10, day: 7)
        XCTAssertEqual(layout.cells[cell], CGRect(x: 1064, y: 360, width: 112, height: 60))
        XCTAssertEqual(InkCanvasView.Coordinator.singleTapDotWindow, 1.0)
        let tapTime = Date()
        let tapUptime: TimeInterval = 5_000
        let nowMs = Int(tapTime.timeIntervalSince1970 * 1000)
        var page = InkPage.empty(pageId: layout.pageId)
        page.add(makeInkStroke(id: "dot", cell: cell, t: nowMs - 300, points: [(56, 30), (57.5, 31.5)]))
        page.add(makeInkStroke(id: "dot800", cell: cell, t: nowMs - 800, points: [(56, 30), (57.5, 31.5)]))
        page.add(makeInkStroke(id: "dot1500", cell: cell, t: nowMs - 1500, points: [(56, 30), (57.5, 31.5)]))
        page.add(makeInkStroke(id: "old", cell: cell, t: nowMs - 10_000, points: [(56, 30), (57.5, 31.5)]))
        page.add(makeInkStroke(id: "line", cell: cell, t: nowMs - 300, points: [(5, 40), (100, 40)]))
        let all: Set<String> = ["dot", "dot800", "dot1500", "old", "line"]
        let pen = CanvasTool.ink(InkPresets.defaultPen)
        let tap = CGPoint(x: 1120.75, y: 390.75)

        func tapRig(leaves: Bool, allowFinger: Bool = true, readOnly: Bool = false) async -> (rig: Rig, log: TapLog) {
            let log = TapLog()
            let rig = await makeRig(
                layout: layout, paper: paper, width: 402, height: 569, doubleTapEnabled: true,
                tool: pen, allowFinger: allowFinger, page: page, readOnly: readOnly,
                onTap: { point, zoom in
                    log.points.append(point)
                    log.zooms.append(zoom)
                    log.liveIds.append(Set(log.coordinator?.ledger.page.liveStrokes.map(\.id) ?? []))
                },
                tapLeavesPage: { _, zoom in
                    log.askedZooms.append(zoom)
                    return leaves
                }
            )
            log.coordinator = rig.coordinator
            // The tap happens at `tapUptime`, however long the rig took to build; the canvas added the
            // strokes that long before it (an old dot and the line too: only size and time decide).
            rig.coordinator.uptime = { tapUptime }
            rig.coordinator.noteRecentAdd("old", at: tapUptime - 10)
            rig.coordinator.noteRecentAdd("dot1500", at: tapUptime - 1.5)
            rig.coordinator.noteRecentAdd("dot800", at: tapUptime - 0.8)
            rig.coordinator.noteRecentAdd("dot", at: tapUptime - 0.3)
            rig.coordinator.noteRecentAdd("line", at: tapUptime - 0.3)
            return (rig, log)
        }

        let (rig, log) = await tapRig(leaves: true)
        XCTAssertEqual(rig.canvas.drawingPolicy, .anyInput, "「指でも書く」")
        let zoom = rig.canvas.zoomScale
        XCTAssertEqual(zoom, 402.0 / 1400, accuracy: 1e-3, "the year's overview on an iPhone")
        XCTAssertEqual(Set(rig.coordinator.ledger.page.liveStrokes.map(\.id)), all)
        XCTAssertFalse(rig.coordinator.ledger.canUndo)
        // The double tap's window would keep the 0.8 s dot; the single tap's takes it.
        XCTAssertEqual(Set(rig.coordinator.dotStrokeIds(near: tap, zoom: zoom, within: 0.5)), ["dot"])
        XCTAssertEqual(Set(rig.coordinator.dotStrokeIds(near: tap, zoom: zoom, within: InkCanvasView.Coordinator.singleTapDotWindow)), ["dot", "dot800"])
        rig.coordinator.fingerTapped(atPaper: tap, zoom: zoom)
        XCTAssertEqual(log.points, [tap], "reported once, at the point")
        XCTAssertEqual(log.zooms, [zoom], "with the canvas's zoom")
        XCTAssertEqual(log.askedZooms, [zoom], "the same zoom the owner was asked with")
        XCTAssertEqual(log.liveIds, [["dot1500", "old", "line"]], "the dots of the last second were gone before the report")
        XCTAssertEqual(Set(rig.coordinator.ledger.page.liveStrokes.map(\.id)), ["dot1500", "old", "line"])
        XCTAssertTrue(rig.coordinator.ledger.canUndo, "one undoable op (M4C-22)")

        let others: [(name: String, leaves: Bool, allowFinger: Bool, readOnly: Bool)] = [
            ("a tap that stays on the page (nothing, or the edit sheet)", false, true, false),
            ("Pencil only", true, false, false),
            ("read only", true, true, true),
        ]
        for case let (name, leaves, allowFinger, readOnly) in others {
            let (other, otherLog) = await tapRig(leaves: leaves, allowFinger: allowFinger, readOnly: readOnly)
            other.coordinator.fingerTapped(atPaper: tap, zoom: other.canvas.zoomScale)
            XCTAssertEqual(otherLog.points, [tap], name)
            XCTAssertEqual(otherLog.zooms, [other.canvas.zoomScale], name)
            XCTAssertEqual(Set(other.coordinator.ledger.page.liveStrokes.map(\.id)), all, "\(name): the dots stay")
            XCTAssertFalse(other.coordinator.ledger.canUndo, name)
        }
    }

    /// What iOS has around the finger taps on an iPhone's year page with 「指でも書く」 (`.anyInput`):
    /// every enabled recogniser inside the canvas that takes the finger (PencilKit's own) is logged
    /// ("finger-tap graph", docs/R1_0_1.md §5.2), and none of them makes a tap wait for it through the
    /// public API (overrides and delegates; a wait set up privately inside PencilKit cannot be seen
    /// here — the iPhone UI test, `YearTapUITests`, taps through the real thing). The rules are 1.0's,
    /// unchanged in 1.0.1: the taps run alongside PencilKit's public drawing recogniser only (not the
    /// others: their own delegates decide), stay exclusive of the canvas's pan / pinch and the finger
    /// recogniser (F2); the finger recogniser runs alongside nothing; the read-only report alongside
    /// everything.
    func testFingerTapGraphOnAnIPhoneYearPage() async throws {
        let (layout, paper) = makeYear()
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 569, doubleTapEnabled: true,
                                tool: .ink(InkPresets.defaultPen), allowFinger: true)
        let c = rig.coordinator
        let canvas = rig.canvas
        XCTAssertEqual(canvas.drawingPolicy, .anyInput)
        XCTAssertEqual(canvas.zoomScale, 402.0 / 1400, accuracy: 1e-3)
        let direct = NSNumber(value: UITouch.TouchType.direct.rawValue)
        func recognizers(below view: UIView) -> [UIGestureRecognizer] {
            view.subviews.flatMap { ($0.gestureRecognizers ?? []) + recognizers(below: $0) }
        }
        let fingerTaking = recognizers(below: canvas).filter { $0.isEnabled && $0.allowedTouchTypes.contains(direct) }
        XCTAssertFalse(fingerTaking.isEmpty, "PencilKit takes the finger inside the canvas with .anyInput")
        let taps: [UIGestureRecognizer] = [c.tapRecognizer, c.doubleTapRecognizer]
        for g in fingerTaking {
            let name = "\(type(of: g)) on \(g.view.map { "\(type(of: $0))" } ?? "nil")"
            for tap in taps {
                let theirSim = g.delegate?.gestureRecognizer?(g, shouldRecognizeSimultaneouslyWith: tap)
                let theirFail = g.delegate?.gestureRecognizer?(g, shouldBeRequiredToFailBy: tap)
                let ourSim = c.gestureRecognizer(tap, shouldRecognizeSimultaneouslyWith: g)
                let line = "finger-tap graph: \(name) delegate=\(g.delegate.map { "\(type(of: $0))" } ?? "nil") theirSim=\(theirSim.map { "\($0)" } ?? "nil") theirFail=\(theirFail.map { "\($0)" } ?? "nil") ourSim=\(ourSim) tap=\(tap === c.tapRecognizer ? "single" : "double") public=\(g === canvas.drawingGestureRecognizer)"
                NSLog("%@", line)
                print(line)
                XCTAssertEqual(ourSim, g === canvas.drawingGestureRecognizer, "\(name): 1.0's rule (alongside the public drawing recogniser only)")
                XCTAssertFalse(g.shouldBeRequiredToFail(by: tap), "\(name): the tap does not wait for it")
                XCTAssertNotEqual(theirFail, true, "\(name): its delegate does not make the tap wait")
                XCTAssertFalse(tap.shouldRequireFailure(of: g), "\(name): the tap does not wait for it (the tap's side)")
            }
            XCTAssertFalse(c.gestureRecognizer(c.fingerRecognizer, shouldRecognizeSimultaneouslyWith: g), "\(name): F2 stays exclusive")
        }

        let pinch = try XCTUnwrap(canvas.pinchGestureRecognizer, "F4: the canvas offers a pinch")
        for tap in taps {
            XCTAssertFalse(c.gestureRecognizer(tap, shouldRecognizeSimultaneouslyWith: canvas.panGestureRecognizer))
            XCTAssertFalse(c.gestureRecognizer(tap, shouldRecognizeSimultaneouslyWith: pinch))
            XCTAssertFalse(c.gestureRecognizer(tap, shouldRecognizeSimultaneouslyWith: c.fingerRecognizer))
            XCTAssertTrue(c.gestureRecognizer(tap, shouldRecognizeSimultaneouslyWith: canvas.drawingGestureRecognizer))
        }
        XCTAssertFalse(c.gestureRecognizer(c.fingerRecognizer, shouldRecognizeSimultaneouslyWith: canvas.drawingGestureRecognizer))
        XCTAssertFalse(c.gestureRecognizer(c.fingerRecognizer, shouldRecognizeSimultaneouslyWith: canvas.panGestureRecognizer))
        let blocked = c.blockedInputRecognizer
        for other in [canvas.drawingGestureRecognizer, canvas.panGestureRecognizer, pinch, c.tapRecognizer, c.doubleTapRecognizer, c.fingerRecognizer] + fingerTaking {
            XCTAssertTrue(c.gestureRecognizer(blocked, shouldRecognizeSimultaneouslyWith: other), "\(type(of: other))")
            XCTAssertTrue(c.gestureRecognizer(other, shouldRecognizeSimultaneouslyWith: blocked), "\(type(of: other)) (the other way round)")
        }
    }

    // MARK: M4C-25 — the centring margin is not paper

    /// A new stroke whose bounds are centred outside the paper never reaches the ledger, leaves the
    /// canvas at once and cannot be undone; one centred on the paper is kept.
    func testStrokesCentredOutsideThePaperAreDropped() async {
        let (layout, paper) = makeDay()
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580)
        XCTAssertGreaterThan(rig.canvas.contentInset.left, 70, "there is a margin to draw in")

        // Centre x ≈ −24 lu: in the left margin.
        rig.canvas.drawing = PKDrawing(strokes: [makeStroke(at: CGPoint(x: -30, y: 300))])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 0, "not in the ledger")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 0, "gone from the canvas")
        XCTAssertFalse(rig.coordinator.ledger.canUndo, "not undoable")

        // Centre (206, 302): on the paper.
        rig.canvas.drawing = PKDrawing(strokes: [makeStroke(at: CGPoint(x: 200, y: 300))])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 1)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
    }

    // MARK: M4b — the viewport report

    func testViewportIsDeliveredOnTheNextTurnNotInsideTheLayoutPass() async {
        let (layout, paper) = makeMonth()
        let probe = Probe()
        let view = makeView(layout: layout, paper: paper, viewportWidth: 402, probe: probe)
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)

        // The first layout pass of an iPhone-wide container.
        container.frame = CGRect(x: 0, y: 0, width: 402, height: 700)
        container.layoutSubviews()
        XCTAssertEqual(probe.count, 0, "nothing is delivered synchronously inside a layout pass")

        await settle()
        XCTAssertEqual(probe.count, 1, "delivered once on the next turn")
        guard let first = probe.last else { return XCTFail("no viewport") }
        let overview = fitAll(layout, 402, 700)
        XCTAssertEqual(first.width, 402)
        XCTAssertEqual(first.zoom, overview, accuracy: 1e-6)
        XCTAssertEqual(first.zoom, 0.2871, accuracy: 1e-4, "the month's overview on an iPhone: fit-to-width")
        XCTAssertEqual(first.offsetX, 0, accuracy: 0.01, "fit-to-width: no margin, the top-left")
        XCTAssertEqual(container.canvasView.minimumZoomScale, overview, accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.maximumZoomScale, ZoomPolicy.maxZoom(.month, viewportWidth: 402), accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.zoomScale, overview, accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.contentSize.width, 402, accuracy: 0.1, "1400 lu × 0.2871")
        XCTAssertEqual(container.paperView.zoomScale, overview, accuracy: 1e-6)
        XCTAssertEqual(container.paperView.frame.size, container.paperView.contentWindow.size)
        XCTAssertFalse(container.paperView.contentWindow.isEmpty, "the paper holds a window around the visible part")

        // The same layout again: the same viewport is not sent twice.
        container.layoutSubviews()
        await settle()
        XCTAssertEqual(probe.count, 1)

        // Rotated to 874 × 402: the overview is height-bound now (402 / 1050 = 0.3829), the paper
        // centred (−169 pt), reported once, on the next turn.
        container.frame = CGRect(x: 0, y: 0, width: 874, height: 402)
        container.layoutSubviews()
        XCTAssertEqual(probe.count, 1, "the rotation is not delivered synchronously either")
        await settle()
        XCTAssertEqual(probe.count, 2)
        guard let rotated = probe.last else { return XCTFail("no viewport after the rotation") }
        XCTAssertEqual(rotated.width, 874)
        XCTAssertEqual(rotated.zoom, fitAll(layout, 874, 402), accuracy: 1e-6)
        XCTAssertEqual(rotated.zoom, 0.3829, accuracy: 1e-4)
        XCTAssertEqual(rotated.offsetX, -(874 - 1400 * rotated.zoom) / 2, accuracy: 0.01)
        XCTAssertEqual(rotated.offsetX, -169, accuracy: 0.5, "centred: the margin as a negative offset")
    }

    func testInitialScrollXPutsTodaysColumnOnScreen() async {
        // Today = Sunday 2026-10-11, ratio 2 on a 402 × 580 iPhone: zoom 0.5743 shows 700 lu, so the
        // paper starts at 1400 − 700 = 700 lu → 402 pt.
        let sunday = DayKey(year: 2026, month: 10, day: 11).startOfDay().addingTimeInterval(10 * 3600)
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: sunday))
        let paper = PaperContent.month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: [], chips: [], holidayNames: [:]))
        let probe = Probe()
        let page = InkPage.empty(pageId: layout.pageId)
        let zoom = 2 * ZoomPolicy.fitAll(.month, overview: ZoomPolicy.overviewSize(layout), viewport: CGSize(width: 402, height: 580))
        XCTAssertEqual(zoom, 0.5743, accuracy: 1e-4)
        let visibleWidth = ZoomPolicy.visibleWidth(.month, viewportWidth: 402, zoom: zoom)
        XCTAssertEqual(visibleWidth, 700, accuracy: 0.01)
        let initialX = PageNavigation.initialScrollX(layout, now: sunday, visibleWidth: visibleWidth)
        XCTAssertEqual(initialX, 700, accuracy: 0.01)
        let view = InkCanvasView(
            layout: layout, paper: paper, tool: .eraser, allowFinger: false, page: .constant(page),
            initialScrollY: 0, initialScrollX: initialX,
            onTap: { _, _ in }, onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0,
            onViewportChange: { probe.count += 1; probe.last = $0 },
            initialZoomRatio: 2
        )
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: 402, height: 580)
        container.layoutSubviews()
        await settle()
        XCTAssertEqual(probe.count, 1)
        XCTAssertEqual(container.canvasView.zoomScale, zoom, accuracy: 1e-6)
        XCTAssertEqual(probe.last?.offsetX ?? -1, 700 * zoom, accuracy: 0.05)
        XCTAssertEqual(probe.last?.offsetX ?? -1, 402, accuracy: 0.1, "today's column at the right edge of the screen")
        XCTAssertEqual(container.canvasView.contentOffset.x, 700 * zoom, accuracy: 0.5) // pixel grid, as above
        XCTAssertEqual(container.canvasView.contentOffset.y, 0, accuracy: 0.01)
    }

    func testDefaultArgumentsOfTheNewParameters() {
        let (layout, paper) = makeMonth()
        let page = InkPage.empty(pageId: layout.pageId)
        // The M3b call shape (no initialScrollX, no onViewportChange, none of the M4c six) still builds.
        let view = InkCanvasView(
            layout: layout, paper: paper, tool: .eraser, allowFinger: false, page: .constant(page),
            initialScrollY: 0, onTap: { _, _ in }, onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0
        )
        XCTAssertEqual(view.initialScrollX, 0)
        view.onViewportChange(.zero)
        // M4C_CONTRACT §1.3: 1 (the overview) / nil / false / three no-ops.
        XCTAssertEqual(view.initialZoomRatio, 1)
        XCTAssertNil(view.initialPaperOffset)
        XCTAssertFalse(view.doubleTapEnabled)
        view.onDoubleTap(.zero)
        view.onZoomRatioChange(1)
        view.onZoomingChange(false)
        // M5_CONTRACT §3.1: writable, and a no-op report.
        XCTAssertFalse(view.readOnly)
        view.onBlockedInput()
        // 1.0.1: by default no tap leaves the page (no dot is ever removed); the tap reports its zoom.
        XCTAssertFalse(view.tapLeavesPage(.zero, 1))
        view.onTap(.zero, 1)
        // 1.1 (M7A_CONTRACT §0): four no-op reports and no clearance (today's CalendarRootScreen builds).
        view.onPenDown()
        view.onEraseEnded(1)
        view.onStrokeBudget(.many(StrokeBudget.noticeAt))
        view.onGrowthCapReached()
        XCTAssertEqual(view.bottomClearance, 0)
    }

    // MARK: M5 — read only (M5_CONTRACT §3.1, §7.6)

    /// Read only: PencilKit's drawing recogniser is off (with the pen and with the lasso), the
    /// Pencil-only touch report is on, the finger recogniser is off even for the lasso with 「指でも
    /// 書く」, the overlay takes no input; `update(from:)` back to writable (the tool unchanged) turns
    /// drawing on and the report off, and read only again reverses it.
    func testReadOnlyDisablesDrawingAndOverlay() {
        let (layout, paper) = makeMonth()
        let probe = Probe()
        let pen = CanvasTool.ink(InkPresets.defaultPen)

        let rig = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true, tool: pen, readOnly: true), paper: paper, probe: probe)
        let blocked = rig.coordinator.blockedInputRecognizer
        XCTAssertFalse(rig.canvas.drawingGestureRecognizer.isEnabled, "no new ink while read only")
        XCTAssertTrue(blocked.isEnabled)
        XCTAssertEqual(blocked.allowedTouchTypes, [NSNumber(value: UITouch.TouchType.pencil.rawValue)], "the Pencil only: a finger scroll never reports")
        XCTAssertEqual(blocked.minimumPressDuration, 0, "recognised at touch-down")
        XCTAssertEqual(blocked.allowableMovement, .greatestFiniteMagnitude, "never fails on movement")
        XCTAssertFalse(blocked.cancelsTouchesInView)
        XCTAssertTrue(blocked.view === rig.canvas, "on the canvas")
        XCTAssertTrue(blocked.delegate === rig.coordinator)
        XCTAssertEqual(rig.canvas.drawingPolicy, .pencilOnly, "the drawing policy is not touched")
        XCTAssertTrue(rig.canvas.isUserInteractionEnabled, "scrolling and pinching keep working")
        XCTAssertTrue(rig.coordinator.doubleTapRecognizer.isEnabled, "the double tap is not gated (navigation)")
        XCTAssertTrue(rig.coordinator.tapRecognizer.isEnabled)

        // The lasso with 「指でも書く」: nothing takes input.
        let lasso = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .lasso, allowFinger: true, readOnly: true), paper: paper, probe: probe)
        XCTAssertFalse(lasso.canvas.drawingGestureRecognizer.isEnabled, ".lasso: drawing is off anyway")
        XCTAssertFalse(lasso.coordinator.fingerRecognizer.isEnabled, "the finger recogniser is off while read only")
        XCTAssertTrue(lasso.coordinator.blockedInputRecognizer.isEnabled)
        XCTAssertFalse(lasso.container.overlayView.isUserInteractionEnabled, "the overlay takes no input while read only")

        // Back to writable under the same canvas (only `readOnly` changes).
        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true, tool: pen, readOnly: false))
        XCTAssertTrue(rig.canvas.drawingGestureRecognizer.isEnabled)
        XCTAssertFalse(blocked.isEnabled)
        // And read only again.
        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true, tool: pen, readOnly: true))
        XCTAssertFalse(rig.canvas.drawingGestureRecognizer.isEnabled)
        XCTAssertTrue(blocked.isEnabled)
        // The lasso becomes writable: the finger recogniser comes back with it.
        lasso.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .lasso, allowFinger: true, readOnly: false))
        XCTAssertTrue(lasso.coordinator.fingerRecognizer.isEnabled)
        XCTAssertFalse(lasso.coordinator.blockedInputRecognizer.isEnabled)
        XCTAssertFalse(lasso.canvas.drawingGestureRecognizer.isEnabled, ".lasso: still no PencilKit drawing")

        // A writable canvas has the recogniser attached but off.
        let writable = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: pen), paper: paper, probe: probe)
        XCTAssertFalse(writable.coordinator.blockedInputRecognizer.isEnabled)
        XCTAssertTrue(writable.coordinator.blockedInputRecognizer.view === writable.canvas)
        XCTAssertTrue(writable.canvas.drawingGestureRecognizer.isEnabled)
    }

    /// The read-only touch report runs alongside everything — drawing, pan, pinch, the taps and the
    /// finger recogniser — in both directions, while the other pairs keep their §4.1 answers.
    func testBlockedInputRecognizerRecognizesSimultaneously() async throws {
        let (layout, paper) = makeMonth()
        let probe = Probe()
        let rig = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, doubleTapEnabled: true, readOnly: true), paper: paper, probe: probe)
        // UIScrollView creates its pinch recogniser lazily, once the zoom limits differ: the first
        // layout pass sets them (the same path as the F4 assert of §4.1; CI run 38958098578 found it
        // nil on an unlaid-out canvas).
        rig.layout(width: 1024, height: 1180)
        await settle()
        let c = rig.coordinator
        let blocked = c.blockedInputRecognizer
        let pinch = try XCTUnwrap(rig.canvas.pinchGestureRecognizer, "F4: the canvas offers a pinch")
        let others: [UIGestureRecognizer] = [rig.canvas.drawingGestureRecognizer, rig.canvas.panGestureRecognizer, pinch, c.tapRecognizer, c.doubleTapRecognizer, c.fingerRecognizer]
        for other in others {
            XCTAssertTrue(c.gestureRecognizer(blocked, shouldRecognizeSimultaneouslyWith: other), "\(type(of: other))")
            XCTAssertTrue(c.gestureRecognizer(other, shouldRecognizeSimultaneouslyWith: blocked), "\(type(of: other)) (the other way round)")
        }
        // The §4.1 answers are unchanged.
        XCTAssertTrue(c.gestureRecognizer(c.tapRecognizer, shouldRecognizeSimultaneouslyWith: rig.canvas.drawingGestureRecognizer))
        XCTAssertFalse(c.gestureRecognizer(c.tapRecognizer, shouldRecognizeSimultaneouslyWith: rig.canvas.panGestureRecognizer))
        XCTAssertFalse(c.gestureRecognizer(c.fingerRecognizer, shouldRecognizeSimultaneouslyWith: rig.canvas.drawingGestureRecognizer))
    }

    /// The overlay's input follows `readOnly` without the tool changing: on with the lasso, off once
    /// read only, on again when writable (the overlay's own `tool` didSet must not win).
    func testOverlayInteractionFollowsReadOnly() {
        let (layout, paper) = makeMonth()
        let probe = Probe()
        let rig = attach(makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .lasso, allowFinger: true), paper: paper, probe: probe)
        let overlay = rig.container.overlayView
        XCTAssertTrue(overlay.isUserInteractionEnabled, ".lasso takes the pen")
        XCTAssertTrue(rig.coordinator.fingerRecognizer.isEnabled)

        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .lasso, allowFinger: true, readOnly: true))
        XCTAssertFalse(overlay.isUserInteractionEnabled, "read only: the overlay takes nothing")
        XCTAssertFalse(rig.coordinator.fingerRecognizer.isEnabled)
        XCTAssertTrue(rig.coordinator.blockedInputRecognizer.isEnabled)
        XCTAssertEqual(overlay.tool, .lasso, "the tool did not change")

        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .lasso, allowFinger: true, readOnly: false))
        XCTAssertTrue(overlay.isUserInteractionEnabled, "writable again")
        XCTAssertTrue(rig.coordinator.fingerRecognizer.isEnabled)
        XCTAssertFalse(rig.coordinator.blockedInputRecognizer.isEnabled)

        // A tool change while read only: the didSet's value is overridden right after it.
        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .eraser, allowFinger: true, readOnly: true))
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .eventRect, allowFinger: true, readOnly: true))
        XCTAssertFalse(overlay.isUserInteractionEnabled, ".eventRect while read only: still nothing")
        XCTAssertEqual(overlay.tool, .eventRect)
        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe, tool: .eventRect, allowFinger: true, readOnly: false))
        XCTAssertTrue(overlay.isUserInteractionEnabled)
    }

    // MARK: 1.1 — helpers

    /// A pen stroke through `points` (paper coordinates) with a `nib` lu nib, written now.
    private func makeStroke(through points: [CGPoint], nib: CGFloat = 3.5) -> PKStroke {
        let controlPoints = points.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: nib, height: nib),
                          opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: controlPoints, creationDate: Date()),
                        transform: .identity, mask: nil)
    }

    /// The month of October with stored strokes `ids` on 10/7 (a 60 lu line each, 30 lu apart).
    private func monthPage(strokes ids: [String]) -> InkPage {
        var page = InkPage.empty(pageId: "m1-2026-10")
        for (i, id) in ids.enumerated() {
            let y = 40 + CGFloat(i) * 30
            page.add(makeInkStroke(id: id, cell: .day(wednesday), t: 1_790_000_000_000 + i, points: [(20, y), (50, y), (80, y)]))
        }
        return page
    }

    /// `count` stored strokes in a cell no layout has: the budget counts them (`budgetCount`), the
    /// canvas never draws them (no 19,000 PKStrokes to build).
    private func budgetPage(pageId: String, count: Int) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        let point = InkPoint(x: 1, y: 1, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)
        for i in 0..<count {
            page.add(InkStroke(id: "budget-\(i)", cell: CellKey(raw: "zz-budget"), tool: .pen, color: "#1f2937",
                               t: 1_790_000_000_000 + i, points: [point]))
        }
        return page
    }

    /// The pen's touch on the canvas as PencilKit reports it (begin / end of the tool).
    private func touch(_ rig: Rig) {
        rig.coordinator.canvasViewDidBeginUsingTool(rig.canvas)
    }

    private func lift(_ rig: Rig) {
        rig.coordinator.canvasViewDidEndUsingTool(rig.canvas)
    }

    /// What PencilKit's vector eraser does: the strokes `ids` leave the canvas, then the change is reported.
    private func erase(_ ids: Set<String>, on rig: Rig) {
        let kept = rig.canvas.drawing.strokes.filter { pk in
            rig.coordinator.ledger.id(of: pk).map { !ids.contains($0) } ?? true
        }
        rig.canvas.drawing = PKDrawing(strokes: kept)
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
    }

    /// A new stroke on the canvas, reported as PencilKit reports it.
    private func draw(_ stroke: PKStroke, on rig: Rig) {
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [stroke])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
    }

    /// Past the settle wait after a lift (`settleDelay`, 0.3 s), with the deliveries run.
    private func waitPastTheSettle() async {
        try? await Task.sleep(for: .seconds(InkCanvasView.settleDelay + 0.3))
        await settle()
    }

    // MARK: 1.1 — the light path of a growing last cell (M7A_CONTRACT §3.6, 0-6)

    /// The iPhone's month (402 × 591, fit-to-width 0.2871): 1750 lu of paper are 502 pt, centred with
    /// 44 pt above and below. A stroke low in the memo area (bottom ≈ 496 lu) makes it 1,100: the
    /// layout comes back with only the memo area taller, and the canvas keeps its drawing (no
    /// `setDrawing`), the ledger adopts the layout, the content is (1050 + 1100) × zoom = 617 pt and
    /// the margins are recomputed (0-6: 0, the paper is taller than the screen now).
    func testTailOnlyGrowthKeepsTheDrawing() async {
        let (layout, paper) = makeMonth()
        XCTAssertEqual(layout.memo.minY, 1050, accuracy: 0.01)
        XCTAssertEqual(layout.memo.height, 700, accuracy: 0.01)
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 591)
        let zoom = rig.canvas.zoomScale
        XCTAssertEqual(zoom, 402.0 / 1400, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.contentInset.top, 44, accuracy: 0.5, "1750 lu × 0.2871 = 502 pt in 591: centred")
        XCTAssertEqual(rig.canvas.contentInset.bottom, 44, accuracy: 0.5)

        draw(makeStroke(at: CGPoint(x: 300, y: 1050 + 490)), on: rig)
        let page = rig.coordinator.ledger.page
        XCTAssertEqual(page.liveStrokes.first?.cell, CellKey.memo)
        XCTAssertEqual(rig.probe.inkBounds, 1, "the memo area asks for room")
        let (grown, grownPaper) = makeMonth(inkBottoms: page.inkBottoms())
        XCTAssertEqual(grown.memo.height, 1100, accuracy: 0.01)
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: layout, new: grown))

        let builds = rig.coordinator.setDrawingCount
        rig.coordinator.update(from: makeView(layout: grown, paper: grownPaper, viewportWidth: 402, probe: rig.probe, page: page))
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds, "the drawing is not rebuilt")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
        XCTAssertEqual(rig.coordinator.ledger.layout.cells[.memo]?.height ?? 0, 1100, accuracy: 0.01, "the ledger adopted the layout")
        XCTAssertEqual(rig.canvas.contentSize.height, (1050 + 1100) * zoom, accuracy: 0.5)
        XCTAssertEqual(rig.canvas.contentInset.top, 0, accuracy: 0.001, "0-6: 617 pt of paper in 591 — no margin")
        XCTAssertEqual(rig.canvas.contentInset.bottom, 0, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.zoomScale, zoom, accuracy: 1e-6, "the overview rectangle did not change")
        XCTAssertEqual(rig.paperView.content, grownPaper, "the paper got its new content")
        // What the canvas holds is still what the ledger knows.
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 1)
        XCTAssertFalse(rig.coordinator.ledger.canRedo)
    }

    /// The memo area shrinks (1,500 → 700) while the iPad's month is scrolled to its end: the light
    /// path clamps the offset to the new end (1750 × 0.7314 − 1180 = 100 pt), still without a new drawing.
    func testTailOnlyShrinkClampsTheOffset() async {
        var page = InkPage.empty(pageId: "m1-2026-10")
        page.add(makeInkStroke(id: "memo-low", cell: .memo, t: 1_790_000_000_000, points: [(100, 880), (110, 898.25)]))
        XCTAssertEqual(page.inkBottoms()[.memo] ?? 0, 900, accuracy: 0.1, "898.25 is stored as 898.3 (0.1 lu)")
        let (grown, grownPaper) = makeMonth(inkBottoms: page.inkBottoms())
        XCTAssertEqual(grown.memo.height, 1500, accuracy: 0.01)
        let rig = await makeRig(layout: grown, paper: grownPaper, width: 1024, height: 1180, page: page)
        let zoom = rig.canvas.zoomScale
        XCTAssertEqual(zoom, 1024.0 / 1400, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
        rig.canvas.contentOffset = CGPoint(x: 0, y: (1050 + 1500) * zoom - 1180)

        erase(["memo-low"], on: rig)
        XCTAssertTrue(rig.coordinator.ledger.page.liveStrokes.isEmpty)
        let (shrunk, shrunkPaper) = makeMonth(inkBottoms: rig.coordinator.ledger.page.inkBottoms())
        XCTAssertEqual(shrunk.memo.height, 700, accuracy: 0.01)
        let builds = rig.coordinator.setDrawingCount
        rig.coordinator.update(from: makeView(layout: shrunk, paper: shrunkPaper, viewportWidth: 1024, probe: rig.probe,
                                              page: rig.coordinator.ledger.page))
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds, "the light path")
        XCTAssertEqual(rig.canvas.contentSize.height, 1750 * zoom, accuracy: 0.5)
        XCTAssertEqual(rig.canvas.contentOffset.y, 1750 * zoom - 1180, accuracy: 0.5, "clamped to the new end")
        XCTAssertEqual(rig.canvas.contentInset, .zero)
    }

    /// The day's free memo area grows (700 → 1,100) and the paper's picture is handed in unchanged:
    /// the geometry alone still reaches `applyPending` (`requestApply` and its guard know
    /// `pendingGeometry`) and takes the light path. The day's overview is the 24 hours (K-6): the zoom stays.
    func testDayExtraGrowthUsesTheTailPath() async {
        let (layout, paper) = makeDay()
        XCTAssertEqual(layout.size.height, 3100, accuracy: 0.01)
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580)
        let zoom = rig.canvas.zoomScale
        XCTAssertEqual(zoom, fitAll(layout, 402, 580), accuracy: 1e-6)

        draw(makeStroke(at: CGPoint(x: 300, y: 2400 + 490)), on: rig)
        let page = rig.coordinator.ledger.page
        XCTAssertEqual(page.liveStrokes.first?.cell, CellKey.extra, "below 24:00")
        XCTAssertEqual(page.liveStrokes.first?.points.first?.y ?? -1, 490, accuracy: 0.11, "cell-relative: paper y − 2400")
        XCTAssertEqual(rig.probe.inkBounds, 1)
        let (grown, _) = makeDay(inkBottoms: page.inkBottoms())
        XCTAssertEqual(grown.extra.height, 1100, accuracy: 0.01)

        let builds = rig.coordinator.setDrawingCount
        rig.coordinator.update(from: makeView(layout: grown, paper: paper, viewportWidth: 402, probe: rig.probe, page: page))
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds, "the light path, although the paper's picture is the same")
        XCTAssertEqual(rig.canvas.contentSize.height, (2400 + 1100) * zoom, accuracy: 0.5)
        XCTAssertEqual(rig.coordinator.ledger.layout.cells[.extra]?.height ?? 0, 1100, accuracy: 0.01)
        XCTAssertEqual(rig.canvas.zoomScale, zoom, accuracy: 1e-6, "the overview is the 24 hours")
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
    }

    /// A row of the month grows (the memo area moves down): the drawing is rebuilt as before (one
    /// `setDrawing`), the content follows the new paper.
    func testRowGrowthStillRebuilds() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        guard let cell = layout.cells[.day(wednesday)] else { return XCTFail("no cell for 10/7") }
        draw(makeStroke(at: CGPoint(x: cell.minX + 50, y: cell.minY + 168)), on: rig)
        let page = rig.coordinator.ledger.page
        XCTAssertEqual(page.liveStrokes.first?.cell, CellKey.day(wednesday))
        let (grown, grownPaper) = makeMonth(inkBottoms: page.inkBottoms())
        XCTAssertGreaterThan(grown.memo.minY, layout.memo.minY, "the row grew")
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: layout, new: grown))

        let builds = rig.coordinator.setDrawingCount
        rig.coordinator.update(from: makeView(layout: grown, paper: grownPaper, viewportWidth: 1024, probe: rig.probe, page: page))
        XCTAssertEqual(rig.coordinator.setDrawingCount, builds + 1, "rebuilt: the rows below moved")
        XCTAssertEqual(rig.canvas.contentSize.height, grown.size.height * rig.canvas.zoomScale, accuracy: 0.5)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
        XCTAssertEqual(rig.coordinator.ledger.layout.cells[.memo]?.minY ?? 0, grown.memo.minY, accuracy: 0.01)
    }

    // MARK: 1.1 — the end of an erasure (M7A_CONTRACT §2.5)

    /// Begin → the eraser takes a stroke → end: `onEraseEnded(1)` once, after the settle wait (not before).
    func testEraseEndedIsReportedOnceAfterTheLift() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .eraser, page: monthPage(strokes: ["a", "b"]))
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 2)
        touch(rig)
        erase(["a"], on: rig)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokeIds, ["b"])
        lift(rig)
        await settle()
        XCTAssertEqual(rig.probe.erased, [], "not before the settle wait is over")
        await waitPastTheSettle()
        XCTAssertEqual(rig.probe.erased, [1], "once, with the count")
        await waitPastTheSettle()
        XCTAssertEqual(rig.probe.erased, [1], "only once")
    }

    /// Touches inside one settle wait add up — a touch that erased nothing in between included — and
    /// are reported once, after the last lift.
    func testErasesWithinTheSettleWindowAddUp() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .eraser,
                                page: monthPage(strokes: ["a", "b", "c"]))
        touch(rig)
        erase(["a"], on: rig)
        lift(rig)
        touch(rig) // within 0.3 s: the wait starts again, the count is carried over
        lift(rig)
        touch(rig)
        erase(["b", "c"], on: rig)
        lift(rig)
        XCTAssertTrue(rig.coordinator.ledger.page.liveStrokes.isEmpty)
        await settle()
        XCTAssertEqual(rig.probe.erased, [])
        await waitPastTheSettle()
        XCTAssertEqual(rig.probe.erased, [3], "one report for the three")
    }

    /// No report for: a touch that erased nothing; ↶ taking a stroke away while the eraser is the tool;
    /// read only; the dots a leaving finger tap removes; a stroke lost while the pen is the tool.
    func testEraseEndedIsNotReportedForNothingErasedUndoReadOnlyDotsOrPen() async {
        let (layout, paper) = makeMonth()

        // Nothing erased.
        let quiet = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .eraser, page: monthPage(strokes: ["a"]))
        touch(quiet)
        lift(quiet)
        await waitPastTheSettle()
        XCTAssertEqual(quiet.probe.erased, [], "nothing erased")

        // ↶ while the touch settles: the undo lands through `setDrawing`, not as an erasure.
        let undo = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .eraser, page: monthPage(strokes: ["a"]))
        draw(makeStroke(at: CGPoint(x: 300, y: 600)), on: undo) // drawn earlier (no touch around it): what ↶ takes away
        XCTAssertEqual(undo.coordinator.ledger.page.liveStrokes.count, 2)
        touch(undo)
        lift(undo)
        undo.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: undo.probe, tool: .eraser,
                                               page: undo.coordinator.ledger.page, undoTrigger: 1))
        await waitPastTheSettle()
        XCTAssertEqual(undo.coordinator.ledger.page.liveStrokeIds, ["a"], "↶ took the stroke away")
        XCTAssertEqual(undo.probe.erased, [], "undo")

        // Read only.
        let readOnly = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .eraser,
                                     page: monthPage(strokes: ["a"]), readOnly: true)
        touch(readOnly)
        erase(["a"], on: readOnly)
        lift(readOnly)
        await waitPastTheSettle()
        XCTAssertEqual(readOnly.probe.erased, [], "read only")

        // The dot of a leaving finger tap (removed through the ledger, one undoable op).
        var dotPage = InkPage.empty(pageId: "m1-2026-10")
        dotPage.add(makeInkStroke(id: "dot", cell: .day(wednesday), t: 1_790_000_000_000, points: [(100, 100), (101.5, 101.5)]))
        let dots = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, doubleTapEnabled: true, tool: .eraser,
                                 allowFinger: true, page: dotPage, tapLeavesPage: { _, _ in true })
        dots.coordinator.noteRecentAdd("dot", at: dots.coordinator.uptime())
        guard let origin = layout.cells[.day(wednesday)]?.origin else { return XCTFail("no cell for 10/7") }
        touch(dots)
        lift(dots)
        dots.coordinator.fingerTapped(atPaper: CGPoint(x: origin.x + 100.75, y: origin.y + 100.75), zoom: dots.canvas.zoomScale)
        XCTAssertTrue(dots.coordinator.ledger.page.liveStrokes.isEmpty, "the dot went")
        await waitPastTheSettle()
        XCTAssertEqual(dots.probe.erased, [], "dots")

        // The pen is the tool.
        let pen = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen),
                                page: monthPage(strokes: ["a"]))
        touch(pen)
        erase(["a"], on: pen)
        lift(pen)
        await waitPastTheSettle()
        XCTAssertEqual(pen.probe.erased, [], "pen")
    }

    /// §2.1: the pen's touch on the canvas and the overlay's tracking are reported at once, the lifts never.
    func testPenDownIsReported() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen))
        XCTAssertEqual(rig.probe.penDowns, 0)
        touch(rig)
        XCTAssertEqual(rig.probe.penDowns, 1, "the canvas: at once")
        lift(rig)
        XCTAssertEqual(rig.probe.penDowns, 1, "not when it lifts")
        rig.coordinator.overlay(rig.container.overlayView, isTracking: true)
        XCTAssertEqual(rig.probe.penDowns, 2, "the lasso / 予定 overlay")
        rig.coordinator.overlay(rig.container.overlayView, isTracking: false)
        await waitPastTheSettle()
        XCTAssertEqual(rig.probe.penDowns, 2)
    }

    // MARK: 1.1 — the limit of the last cell and the budget (M7A_CONTRACT §3.4, §5.2, 0-5, K-9)

    /// A memo stroke from a 1.0 device at 6,420 lu makes the paper longer than the limit (6,470): it
    /// stays and is drawn. New strokes centred more than 6,000 lu below the memo area's top are dropped
    /// there anyway — off the canvas, never in the ledger, not undoable — with one notice per change;
    /// one above the limit is kept without a notice; one off the paper is dropped without it.
    func testNewStrokesBeyondTheCapAreDropped() async {
        var page = InkPage.empty(pageId: "m1-2026-10")
        page.add(makeInkStroke(id: "from-1.0", cell: .memo, t: 1_790_000_000_000, points: [(100, 6400), (120, 6418.25)]))
        let (layout, paper) = makeMonth(inkBottoms: page.inkBottoms())
        XCTAssertEqual(layout.memo.height, 6470, accuracy: 0.1, "b + 50: the 1.0 stroke stays visible")
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen), page: page)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "the 1.0 stroke is drawn")
        let top = layout.memo.minY

        draw(makeStroke(at: CGPoint(x: 400, y: top + 6098)), on: rig)
        await settle()
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "gone from the canvas")
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokeIds, ["from-1.0"], "never in the ledger; the 1.0 stroke stays")
        XCTAssertFalse(rig.coordinator.ledger.canUndo)
        XCTAssertEqual(rig.probe.caps, 1)

        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [
            makeStroke(at: CGPoint(x: 400, y: top + 6200)),
            makeStroke(at: CGPoint(x: 600, y: top + 6300)),
        ])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
        await settle()
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
        XCTAssertEqual(rig.probe.caps, 2, "one notice for one change")

        draw(makeStroke(at: CGPoint(x: 400, y: top + 4998)), on: rig)
        await settle()
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 2, "above the limit: kept")
        XCTAssertEqual(rig.probe.caps, 2, "its bottom leaves room for another step")

        draw(makeStroke(at: CGPoint(x: -30, y: top + 6100)), on: rig)
        await settle()
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 2, "off the paper: dropped (M4C-25)")
        XCTAssertEqual(rig.probe.caps, 2, "without the notice")
    }

    /// The second trigger of 「メモ欄はここまでです」: a new memo stroke whose bottom is past 5,600 lu
    /// (no further 400 lu step fits below it) is kept and reported once; at 5,600 it is not.
    func testCapNoticeWhenTheTailReachesItsLastStep() async {
        let (layout, paper) = makeMonth(inkBottoms: [.memo: 5500])
        XCTAssertEqual(layout.memo.height, 5900, accuracy: 0.01)
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen))
        let top = layout.memo.minY

        draw(makeStroke(through: (0..<5).map { CGPoint(x: 100 + CGFloat($0) * 10, y: top + 5598) }, nib: 4), on: rig)
        await settle()
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.first?.bottom ?? 0, 5600, accuracy: 0.001)
        XCTAssertEqual(rig.probe.caps, 0, "5,600: the last step still fits")

        draw(makeStroke(through: (0..<5).map { CGPoint(x: 300 + CGFloat($0) * 10, y: top + 5599) }, nib: 4), on: rig)
        await settle()
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 2, "kept")
        XCTAssertEqual(rig.coordinator.ledger.page.inkBottoms()[.memo] ?? 0, 5601, accuracy: 0.001)
        XCTAssertEqual(rig.probe.caps, 1, "5,601: once")
    }

    /// K-9: at 19,000 strokes (in a cell no layout has, so nothing is drawn) a new stroke is taken off
    /// the canvas and `.full(19000)` is reported; at 14,999 the new one reaches 15,000 and `.many(15000)`
    /// is reported once. iCloud and ↶ are never stopped: a page brought to 19,000 from outside takes
    /// the stroke ↶ puts back (19,001).
    func testStrokesOverTheBudgetAreRefused() async {
        let (layout, paper) = makeDay()
        let pen = CanvasTool.ink(InkPresets.defaultPen)

        let full = budgetPage(pageId: layout.pageId, count: 19_000)
        XCTAssertEqual(full.budgetCount, 19_000)
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580, tool: pen, page: full)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 0, "a cell the layout lacks is not drawn")
        draw(makeStroke(at: CGPoint(x: 300, y: 600)), on: rig)
        await settle()
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 0, "taken off the canvas")
        XCTAssertEqual(rig.coordinator.ledger.page.budgetCount, 19_000)
        XCTAssertFalse(rig.coordinator.ledger.canUndo)
        XCTAssertEqual(rig.probe.budget, [.full(19_000)])

        let many = budgetPage(pageId: layout.pageId, count: 14_999)
        let rig2 = await makeRig(layout: layout, paper: paper, width: 402, height: 580, tool: pen, page: many)
        draw(makeStroke(at: CGPoint(x: 300, y: 600)), on: rig2)
        await settle()
        XCTAssertEqual(rig2.coordinator.ledger.page.budgetCount, 15_000)
        XCTAssertEqual(rig2.canvas.drawing.strokes.count, 1)
        XCTAssertEqual(rig2.probe.budget, [.many(15_000)])
        draw(makeStroke(at: CGPoint(x: 300, y: 900)), on: rig2)
        await settle()
        XCTAssertEqual(rig2.coordinator.ledger.page.budgetCount, 15_001)
        XCTAssertEqual(rig2.probe.budget, [.many(15_000)], "once")

        var near = budgetPage(pageId: layout.pageId, count: 18_998)
        near.add(makeInkStroke(id: "a", cell: .grid, t: 1_790_000_100_000, points: [(300, 600), (330, 600), (360, 600)]))
        let rig3 = await makeRig(layout: layout, paper: paper, width: 402, height: 580, tool: .eraser, page: near)
        XCTAssertEqual(rig3.canvas.drawing.strokes.count, 1)
        erase(["a"], on: rig3)
        XCTAssertEqual(rig3.coordinator.ledger.page.budgetCount, 18_998)
        var remote = rig3.coordinator.ledger.page
        let point = InkPoint(x: 1, y: 1, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)
        for i in 0..<2 {
            remote.add(InkStroke(id: "remote-\(i)", cell: CellKey(raw: "zz-budget"), tool: .pen, color: "#1f2937",
                                 t: 1_790_000_200_000 + i, points: [point]))
        }
        rig3.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 402, probe: rig3.probe, tool: .eraser, page: remote))
        XCTAssertEqual(rig3.coordinator.ledger.page.budgetCount, 19_000, "iCloud is not stopped")
        rig3.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 402, probe: rig3.probe, tool: .eraser,
                                               page: remote, undoTrigger: 1))
        await settle()
        XCTAssertEqual(rig3.coordinator.ledger.page.budgetCount, 19_001, "↶ is not stopped either")
        XCTAssertEqual(rig3.probe.budget, [])
    }

    // MARK: 1.1 — the round button's clearance (M7A_CONTRACT §2.2)

    /// The iPhone's week (1920 lu at 0.2871 = 551 pt in 580: 14.5 pt above and below): with a
    /// clearance of 60 the bottom margin is 60 at once (the others unchanged), and stays through a
    /// layout pass; a larger centring margin wins; 0 gives the centring margin back.
    func testBottomClearanceAddsToTheBottomInset() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580)
        let zoom = rig.canvas.zoomScale
        let margin = (580 - 1920 * zoom) / 2
        XCTAssertEqual(margin, 14.5, accuracy: 0.5)
        XCTAssertEqual(rig.canvas.contentInset.bottom, margin, accuracy: 0.01)

        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 402, probe: rig.probe, bottomClearance: 60))
        XCTAssertEqual(rig.canvas.contentInset.bottom, 60, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentInset.top, margin, accuracy: 0.01, "the top margin is the centring one")
        XCTAssertEqual(rig.canvas.contentInset.left, 0, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentSize.height + rig.canvas.contentInset.top + rig.canvas.contentInset.bottom - 580, 60 - margin,
                       accuracy: 0.5, "the paper's bottom can be scrolled above the button")

        // The toolbar folded: the paper area is 66 pt taller (still width-bound): max(47.4, 60).
        rig.layout(width: 402, height: 646)
        XCTAssertEqual(rig.canvas.contentInset.bottom, 60, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentInset.top, (646 - 1920 * zoom) / 2, accuracy: 0.01)
        // A centring margin larger than the clearance wins.
        rig.layout(width: 402, height: 800)
        XCTAssertEqual(rig.canvas.contentInset.bottom, (800 - 1920 * zoom) / 2, accuracy: 0.01)

        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 402, probe: rig.probe, bottomClearance: 0))
        rig.layout(width: 402, height: 580)
        XCTAssertEqual(rig.canvas.contentInset.bottom, margin, accuracy: 0.01, "the centring margin alone")
        XCTAssertEqual(rig.canvas.contentInset.top, margin, accuracy: 0.01)
    }

    // MARK: 1.1 — whose dots, and the eraser's tap (M7A_CONTRACT §2.4, §4.1, 0-21, 0-22)

    /// 0-21: a small stroke another device wrote, its clock an hour ahead (1.0.1 picked its dots by
    /// `t`), comes in from iCloud: it is drawn, but it is not a dot candidate and a leaving tap leaves
    /// it alone (no tombstone that would reach a 1.0 device). A dot this canvas drew is still taken.
    func testDotsFromAnotherDeviceAreNotCandidates() async {
        let (layout, paper) = makeYear()
        let cell = CellKey.yearDay(month: 10, day: 7)
        let tap = CGPoint(x: 1120.75, y: 390.75)
        let pen = CanvasTool.ink(InkPresets.defaultPen)
        let log = TapLog()
        let leaves: (CGPoint, CGFloat) -> Bool = { _, _ in true }
        let onTap: (CGPoint, CGFloat) -> Void = { point, _ in log.points.append(point) }
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 569, doubleTapEnabled: true, tool: pen,
                                allowFinger: true, onTap: onTap, tapLeavesPage: leaves)
        var remote = InkPage.empty(pageId: layout.pageId)
        let ahead = Int(Date().timeIntervalSince1970 * 1000) + 3_600_000
        remote.add(makeInkStroke(id: "far-dot", cell: cell, t: ahead, points: [(56, 30), (57.5, 31.5)]))
        rig.coordinator.update(from: makeView(layout: layout, paper: paper, viewportWidth: 402, probe: rig.probe, doubleTapEnabled: true,
                                              tool: pen, allowFinger: true, page: remote, onTap: onTap, tapLeavesPage: leaves))
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokeIds, ["far-dot"])
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "drawn")
        let zoom = rig.canvas.zoomScale
        XCTAssertEqual(rig.coordinator.dotStrokeIds(near: tap, zoom: zoom, within: InkCanvasView.Coordinator.singleTapDotWindow), [])
        rig.coordinator.fingerTapped(atPaper: tap, zoom: zoom)
        XCTAssertEqual(log.points, [tap])
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokeIds, ["far-dot"], "not erased")
        XCTAssertNil(rig.coordinator.ledger.page.deleted["far-dot"], "no tombstone")
        XCTAssertFalse(rig.coordinator.ledger.canUndo)

        // This canvas's own dot at the same place: found and removed by the next leaving tap.
        draw(makeStroke(through: [CGPoint(x: 1120, y: 390), CGPoint(x: 1121.5, y: 391.5)]), on: rig)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.count, 2)
        XCTAssertEqual(rig.coordinator.dotStrokeIds(near: tap, zoom: zoom, within: InkCanvasView.Coordinator.singleTapDotWindow).count, 1)
        rig.coordinator.fingerTapped(atPaper: tap, zoom: zoom)
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokeIds, ["far-dot"], "only the canvas's own dot went")
    }

    /// 0-22: with the eraser and 「指でも書く」, a finger tap on a date erases the line under it and leaves
    /// the page: what that very touch erased is put back (as a clone, a new id; the old id keeps its
    /// tombstone) before `onTap`, and the tool does not go back to the pen for it. A tap that stays on
    /// the page, read only, or a stroke an earlier touch erased: nothing is put back.
    func testEraserTapThatLeavesThePageRestoresWhatItErased() async {
        let (layout, paper) = makeYear()
        let cell = CellKey.yearDay(month: 10, day: 7)
        var page = InkPage.empty(pageId: layout.pageId)
        page.add(makeInkStroke(id: "line", cell: cell, t: 1_790_000_000_000, points: [(10, 30), (50, 30), (100, 30)]))
        let tap = CGPoint(x: 1120, y: 390)

        func eraserRig(leaves: Bool, readOnly: Bool = false) async -> (rig: Rig, log: TapLog) {
            let log = TapLog()
            let rig = await makeRig(
                layout: layout, paper: paper, width: 402, height: 569, doubleTapEnabled: true, tool: .eraser, allowFinger: true,
                page: page, readOnly: readOnly,
                onTap: { point, zoom in
                    log.points.append(point)
                    log.zooms.append(zoom)
                    log.liveIds.append(Set(log.coordinator?.ledger.page.liveStrokes.map(\.id) ?? []))
                },
                tapLeavesPage: { _, _ in leaves }
            )
            log.coordinator = rig.coordinator
            rig.coordinator.uptime = { 500 }
            return (rig, log)
        }

        let (rig, log) = await eraserRig(leaves: true)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
        touch(rig)
        erase(["line"], on: rig)
        XCTAssertTrue(rig.coordinator.ledger.page.liveStrokes.isEmpty)
        lift(rig)
        rig.coordinator.tapTouchBeganAt = 500.02 // the tap's own finger
        rig.coordinator.fingerTapped(atPaper: tap, zoom: rig.canvas.zoomScale)
        XCTAssertEqual(log.points, [tap], "reported once")
        XCTAssertEqual(log.liveIds.first?.count, 1, "put back before the report")
        XCTAssertFalse(log.liveIds.first?.contains("line") ?? true, "as a clone with a new id")
        XCTAssertNotNil(rig.coordinator.ledger.page.deleted["line"], "the old id keeps its tombstone")
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokes.first?.points, page.strokes["line"]?.points)
        XCTAssertEqual(rig.canvas.drawing.strokes.count, 1, "on the canvas again")
        await waitPastTheSettle()
        XCTAssertEqual(rig.probe.erased, [], "the tool does not go back to the pen for it")

        // A tap that stays on the page: the erasure stays (and is reported as usual).
        let (stay, _) = await eraserRig(leaves: false)
        touch(stay)
        erase(["line"], on: stay)
        lift(stay)
        stay.coordinator.tapTouchBeganAt = 500.02
        stay.coordinator.fingerTapped(atPaper: tap, zoom: stay.canvas.zoomScale)
        XCTAssertTrue(stay.coordinator.ledger.page.liveStrokes.isEmpty)
        await waitPastTheSettle()
        XCTAssertEqual(stay.probe.erased, [1])

        // Read only: nothing is put back.
        let (readOnly, _) = await eraserRig(leaves: true, readOnly: true)
        touch(readOnly)
        erase(["line"], on: readOnly)
        lift(readOnly)
        readOnly.coordinator.tapTouchBeganAt = 500.02
        readOnly.coordinator.fingerTapped(atPaper: tap, zoom: readOnly.canvas.zoomScale)
        XCTAssertTrue(readOnly.coordinator.ledger.page.liveStrokes.isEmpty, "read only")

        // An earlier touch erased it; the tap is a touch of its own a second later.
        let (earlier, earlierLog) = await eraserRig(leaves: true)
        touch(earlier)
        erase(["line"], on: earlier)
        lift(earlier)
        earlier.coordinator.tapTouchBeganAt = 501
        earlier.coordinator.fingerTapped(atPaper: tap, zoom: earlier.canvas.zoomScale)
        XCTAssertEqual(earlierLog.liveIds, [[]], "what an earlier touch erased stays erased")
        XCTAssertTrue(earlier.coordinator.ledger.page.liveStrokes.isEmpty)

        // The settle wait ended before the single tap (on the week, month and year pages the tap waits
        // about 0.3 s for the double tap to fail, M4C-6): the end of the erasure was reported and the
        // owner put the pen back. The tap still puts back what its own touch erased.
        let (late, lateLog) = await eraserRig(leaves: true)
        touch(late)
        erase(["line"], on: late)
        lift(late)
        await waitPastTheSettle()
        XCTAssertEqual(late.probe.erased, [1], "reported before the tap arrived")
        late.coordinator.update(from: makeView(
            layout: layout, paper: paper, viewportWidth: 402, probe: late.probe, doubleTapEnabled: true,
            tool: .ink(InkPresets.defaultPen), allowFinger: true, page: late.coordinator.ledger.page,
            onTap: { point, zoom in
                lateLog.points.append(point)
                lateLog.zooms.append(zoom)
                lateLog.liveIds.append(Set(lateLog.coordinator?.ledger.page.liveStrokes.map(\.id) ?? []))
            },
            tapLeavesPage: { _, _ in true }
        ))
        late.coordinator.tapTouchBeganAt = 500.02
        late.coordinator.fingerTapped(atPaper: tap, zoom: late.canvas.zoomScale)
        XCTAssertEqual(lateLog.points, [tap])
        XCTAssertEqual(lateLog.liveIds.first?.count, 1, "put back before the report, the pen already chosen")
        XCTAssertNotNil(late.coordinator.ledger.page.deleted["line"])
        XCTAssertEqual(late.canvas.drawing.strokes.count, 1)
    }

    /// 0-22 with the real timing: the tap's finger is timed when it touches down (`UITouch.timestamp`),
    /// the eraser's touch when PencilKit tells of the tool (`uptime()` at Begin), which may be well over
    /// 0.1 s later in an ordinary tap. Begin 0.15 s or 0.49 s after the touch-down: what the touch erased
    /// is still put back before `onTap`. A touch that began 0.5 s or more after the finger (not the
    /// tap's own, e.g. the Pencil while the tap waited for the double tap to fail) or more than 0.05 s
    /// before it (an earlier touch): nothing is put back.
    func testEraserTapRestoresWhenPencilKitBeginsLate() async {
        let (layout, paper) = makeYear()
        let cell = CellKey.yearDay(month: 10, day: 7)
        var page = InkPage.empty(pageId: layout.pageId)
        page.add(makeInkStroke(id: "line", cell: cell, t: 1_790_000_000_000, points: [(10, 30), (50, 30), (100, 30)]))
        let tap = CGPoint(x: 1120, y: 390)

        /// Begin at uptime 500, the eraser takes "line", lift, then the tap whose finger touched down
        /// at `fingerDown`. Returns the live ids `onTap` saw and the rig after the settle wait.
        func eraserTap(fingerDown: TimeInterval) async -> (seen: [Set<String>], rig: Rig) {
            let log = TapLog()
            let rig = await makeRig(
                layout: layout, paper: paper, width: 402, height: 569, doubleTapEnabled: true, tool: .eraser, allowFinger: true,
                page: page,
                onTap: { _, _ in
                    log.liveIds.append(Set(log.coordinator?.ledger.page.liveStrokes.map(\.id) ?? []))
                },
                tapLeavesPage: { _, _ in true }
            )
            log.coordinator = rig.coordinator
            rig.coordinator.uptime = { 500 }
            touch(rig)
            erase(["line"], on: rig)
            lift(rig)
            rig.coordinator.tapTouchBeganAt = fingerDown
            rig.coordinator.fingerTapped(atPaper: tap, zoom: rig.canvas.zoomScale)
            await waitPastTheSettle()
            return (log.liveIds, rig)
        }

        for fingerDown in [499.85, 499.51] {
            let (seen, rig) = await eraserTap(fingerDown: fingerDown)
            XCTAssertEqual(seen.count, 1, "reported once (finger down at \(fingerDown))")
            XCTAssertEqual(seen.first?.count, 1, "put back before the report (finger down at \(fingerDown))")
            XCTAssertFalse(seen.first?.contains("line") ?? true, "as a clone with a new id")
            XCTAssertNotNil(rig.coordinator.ledger.page.deleted["line"], "the old id keeps its tombstone")
            XCTAssertEqual(rig.canvas.drawing.strokes.count, 1)
            XCTAssertEqual(rig.probe.erased, [], "the tool does not go back to the pen for it")
        }
        for fingerDown in [499.5, 499.0, 500.06, 501.0] {
            let (seen, rig) = await eraserTap(fingerDown: fingerDown)
            XCTAssertEqual(seen, [[]], "not the tap's own touch (finger down at \(fingerDown)): it stays erased")
            XCTAssertTrue(rig.coordinator.ledger.page.liveStrokes.isEmpty)
            XCTAssertNotNil(rig.coordinator.ledger.page.deleted["line"])
            XCTAssertEqual(rig.probe.erased, [1], "reported as an ordinary erasure")
        }
    }
}
