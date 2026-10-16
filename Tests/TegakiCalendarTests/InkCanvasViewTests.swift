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
/// §4.1 / §2.2 say; strokes centred outside the paper are dropped (M4C-25).
@MainActor
final class InkCanvasViewTests: XCTestCase {
    /// Counts the deliveries of `onViewportChange`, and collects `onZoomRatioChange` / `onZoomingChange`.
    private final class Probe {
        var count = 0
        var last: PaperViewport?
        var ratios: [CGFloat] = []
        var zooming: [Bool] = []
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

    /// 10/7: 1000 × 2400 lu.
    private func makeDay() -> (layout: DayPageLayout, paper: PaperContent) {
        let layout = DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: [], inkBottoms: [:], now: now))
        return (layout, .day(DayPaperContent(layout: layout)))
    }

    /// The canvas as the screen builds it. `initialScrollX` is computed for the readable zoom (it is
    /// not used at the default ratio 1; a test that needs it computes its own).
    private func makeView(layout: any PageLayout, paper: PaperContent, viewportWidth: CGFloat, probe: Probe,
                          initialZoomRatio: CGFloat = 1, initialPaperOffset: CGPoint? = nil, doubleTapEnabled: Bool = false,
                          tool: CanvasTool = .eraser, allowFinger: Bool = false, page: InkPage? = nil,
                          onZoomRatioChange: @escaping (CGFloat) -> Void = { _ in },
                          onZoomingChange: @escaping (Bool) -> Void = { _ in }) -> InkCanvasView {
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
            onTap: { _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onViewportChange: { viewport in
                probe.count += 1
                probe.last = viewport
            },
            initialZoomRatio: initialZoomRatio,
            initialPaperOffset: initialPaperOffset,
            doubleTapEnabled: doubleTapEnabled,
            onZoomRatioChange: onZoomRatioChange,
            onZoomingChange: onZoomingChange
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
                         tool: CanvasTool = .eraser, allowFinger: Bool = false, page: InkPage? = nil, clear: Bool = true) async -> Rig {
        let probe = Probe()
        let view = makeView(
            layout: layout, paper: paper, viewportWidth: width, probe: probe,
            initialZoomRatio: initialZoomRatio, initialPaperOffset: initialPaperOffset, doubleTapEnabled: doubleTapEnabled,
            tool: tool, allowFinger: allowFinger, page: page,
            onZoomRatioChange: { probe.ratios.append($0) },
            onZoomingChange: { probe.zooming.append($0) }
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
        XCTAssertEqual(canvas.contentOffset.x, -canvas.contentInset.left, accuracy: 0.01, "the top-left")
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
        XCTAssertEqual(rig.canvas.contentOffset.x, 400 * zoom, accuracy: 0.05)
        XCTAssertEqual(rig.canvas.contentOffset.y, 200 * zoom, accuracy: 0.05)
        XCTAssertEqual(rig.probe.last?.offsetX ?? 0, 400 * zoom, accuracy: 0.05, "the heading's viewport")
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
    /// dot, not a line.
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
        let near = CGPoint(x: origin.x + 103, y: origin.y + 103)
        let ids = rig.coordinator.dotStrokeIds(near: near, zoom: 0.5, within: 0.5)
        XCTAssertEqual(Set(ids), ["dot1", "dot2"])
        // 48 lu away at zoom 0.5 (24 pt): too far.
        XCTAssertEqual(rig.coordinator.dotStrokeIds(near: CGPoint(x: near.x + 60, y: near.y), zoom: 0.5, within: 0.5), [])
        // At zoom 2 the same 60 lu are 120 pt: still too far; the dots are found at the right place.
        XCTAssertEqual(Set(rig.coordinator.dotStrokeIds(near: near, zoom: 2, within: 0.5)), ["dot1", "dot2"])
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
            onTap: { _ in }, onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0,
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
        XCTAssertEqual(container.canvasView.contentOffset.x, 700 * zoom, accuracy: 0.05)
        XCTAssertEqual(container.canvasView.contentOffset.y, 0, accuracy: 0.01)
    }

    func testDefaultArgumentsOfTheNewParameters() {
        let (layout, paper) = makeMonth()
        let page = InkPage.empty(pageId: layout.pageId)
        // The M3b call shape (no initialScrollX, no onViewportChange, none of the M4c six) still builds.
        let view = InkCanvasView(
            layout: layout, paper: paper, tool: .eraser, allowFinger: false, page: .constant(page),
            initialScrollY: 0, onTap: { _ in }, onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0
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
    }
}
