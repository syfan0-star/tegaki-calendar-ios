import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §6.1, §3.6–§3.9, 0e-7–0e-10): 等倍 on the one page — `zoomResetTrigger`, step 8 of
/// `update(from:)` and `resetZoomToOpen()` of the canvas (DATA_1_1's row 1, re-based in 1.4.1). The canvas is built as the
/// frozen `InkCanvasViewTests` builds it (TESTS_1_2_3: that file is not touched, so its rig is copied here): the coordinator
/// attached to a container, `liveOverride` for a pinch XCTest cannot make, `pinch()` for UIKit's end-of-pinch calls, the
/// probe's `ratios` for `onZoomRatioChange`.
///
/// A press goes back once, on the next main-actor turn (never inside the update), to the opening zoom of the limits in
/// force (`Bounds.open`, ratio 1), and reports ratio 1 once (the screen's closure then removes the kind's stored ratio,
/// 0e-10); ↶ and the lasso selection stay. A month pinched below the opening zoom comes up to it, keeping the paper y in
/// the middle of the screen; a page no taller than the screen goes back to its top, where it opens, with the toolbar
/// folded too (the review of D1a). At the opening zoom nothing moves and nothing is reported. Under the pen, during a pinch,
/// while a new page waits for its drawing and before the first zoom the press is dropped, never kept for later; in the
/// settle wait after a lift it works. The value a canvas is made with does nothing. The all-day band's second settle after
/// a reset (the paper area grows, `applyBounds` follows the new opening zoom) ends where a fresh page opens.
@MainActor
final class InkCanvasZoomResetTests: XCTestCase {
    /// What the canvas told its owner.
    private final class Probe {
        var last: PaperViewport?
        var ratios: [CGFloat] = []
        var zooming: [Bool] = []
        var selections: [InkSelection?] = []
    }

    /// The page binding of the screen: what the canvas writes back is what the next update hands it (as
    /// `InkCanvasViewTests.PageWrites`), so an update never reloads the page.
    private final class PageWrites: @unchecked Sendable {
        var page: InkPage

        init(_ page: InkPage) {
            self.page = page
        }

        var binding: Binding<InkPage> {
            Binding(get: { self.page }, set: { self.page = $0 })
        }
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

    private func makeNovember() -> (layout: MonthPageLayout, paper: PaperContent) {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now))
        let paper = PaperContent.month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: [:]))
        return (layout, paper)
    }

    /// The week of 10/5: 1400 × 1920 lu.
    private func makeWeek() -> (layout: WeekPageLayout, paper: PaperContent) {
        let layout = WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: [], inkBottoms: [:], now: now))
        return (layout, .week(WeekPaperContent(layout: layout)))
    }

    /// The canvas as the screen builds it, with the press count `zoomResetTrigger` (the screen's `@State`) and the toolbar's
    /// `bottomClearance` (0 expanded, 60 folded or peeking).
    private func makeView(layout: any PageLayout, paper: PaperContent, viewportWidth: CGFloat, probe: Probe,
                          initialZoomRatio: CGFloat = 1, tool: CanvasTool = .eraser, page: Binding<InkPage>? = nil,
                          bottomClearance: CGFloat = 0, zoomResetTrigger: Int = 0) -> InkCanvasView {
        InkCanvasView(
            layout: layout,
            paper: paper,
            tool: tool,
            allowFinger: false,
            page: page ?? .constant(InkPage.empty(pageId: layout.pageId)),
            initialScrollY: PageNavigation.initialScrollY(layout, now: now),
            initialScrollX: PageNavigation.initialScrollX(
                layout, now: now,
                visibleWidth: ZoomPolicy.visibleWidth(layout.kind, viewportWidth: viewportWidth, zoom: ZoomPolicy.readableZoom(layout.kind))
            ),
            onTap: { _, _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onSelectionChange: { probe.selections.append($0) },
            onViewportChange: { probe.last = $0 },
            initialZoomRatio: initialZoomRatio,
            onZoomRatioChange: { probe.ratios.append($0) },
            onZoomingChange: { probe.zooming.append($0) },
            bottomClearance: bottomClearance,
            zoomResetTrigger: zoomResetTrigger
        )
    }

    /// A canvas wired like `makeUIView` (the coordinator attached to a container), its probe, and its view with another press
    /// count (`view(n)`: everything else as it was made).
    @MainActor
    private struct Rig {
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let probe: Probe
        let view: (Int) -> InkCanvasView
        var canvas: PKCanvasView { container.canvasView }
        var paperView: PaperView { container.paperView }

        /// The parent's layout pass at a new size (rotation, Split View, the band growing).
        func layout(width: CGFloat, height: CGFloat) {
            container.frame = CGRect(x: 0, y: 0, width: width, height: height)
            container.layoutSubviews()
        }

        /// 等倍 pressed `trigger` times so far: the screen's SwiftUI update with that count.
        func press(_ trigger: Int) {
            coordinator.update(from: view(trigger))
        }
    }

    /// A canvas made with `zoomResetTrigger`, laid out once at `width` × `height` (unless `layOut` is false) and settled; the
    /// first layout's own report is dropped so a test collects only what it causes.
    private func makeRig(layout: any PageLayout, paper: PaperContent, width: CGFloat, height: CGFloat, initialZoomRatio: CGFloat = 1,
                         tool: CanvasTool = .eraser, page: Binding<InkPage>? = nil, bottomClearance: CGFloat = 0,
                         zoomResetTrigger: Int = 0, layOut: Bool = true) async -> Rig {
        let probe = Probe()
        let make: (Int) -> InkCanvasView = { [unowned self] trigger in
            self.makeView(layout: layout, paper: paper, viewportWidth: width, probe: probe, initialZoomRatio: initialZoomRatio,
                          tool: tool, page: page, bottomClearance: bottomClearance, zoomResetTrigger: trigger)
        }
        let coordinator = InkCanvasView.Coordinator(parent: make(zoomResetTrigger))
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        let rig = Rig(coordinator: coordinator, container: container, probe: probe, view: make)
        if layOut {
            rig.layout(width: width, height: height)
        }
        await settle()
        probe.ratios.removeAll()
        probe.zooming.removeAll()
        return rig
    }

    /// The end-of-pinch path as UIKit drives it, without a pinch: will-begin, the zoom, did-end; then its reports are
    /// delivered and dropped.
    private func pinch(_ rig: Rig, to zoom: CGFloat) async {
        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(zoom, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: zoom)
        await settle()
        rig.probe.ratios.removeAll()
        rig.probe.zooming.removeAll()
    }

    /// The paper scrolled to `offset` (pt), as a finger leaves it.
    private func scroll(_ rig: Rig, to offset: CGPoint) {
        rig.canvas.contentOffset = offset
        rig.coordinator.scrollViewDidScroll(rig.canvas)
    }

    /// The offset `resetZoomToOpen` puts y at on a paper taller than the screen at the opening zoom: the paper y in the
    /// middle of what shows above the bottom clearance kept, clamped to the paper (§3.8 steps 1, 4 and 5).
    private func expectedY(_ rig: Rig, layout: any PageLayout, before offsetY: CGFloat, zoom oldZoom: CGFloat, open: CGFloat) -> CGFloat {
        let height = rig.container.bounds.height
        let bottom = rig.canvas.contentInset.bottom
        let shown = height - bottom
        let midY = (offsetY + shown / 2) / oldZoom
        let maxY = max(0, layout.size.height * open + bottom - height)
        return min(max(0, midY * open - shown / 2), maxY)
    }

    /// The pen's touch on the canvas as PencilKit reports it (begin / end of the tool).
    private func touch(_ rig: Rig) {
        rig.coordinator.canvasViewDidBeginUsingTool(rig.canvas)
    }

    private func lift(_ rig: Rig) {
        rig.coordinator.canvasViewDidEndUsingTool(rig.canvas)
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

    /// A new stroke on the canvas, reported as PencilKit reports it.
    private func draw(_ stroke: PKStroke, on rig: Rig) {
        rig.canvas.drawing = PKDrawing(strokes: rig.canvas.drawing.strokes + [stroke])
        rig.coordinator.canvasViewDrawingDidChange(rig.canvas)
    }

    /// Lets the queued main-actor tasks (the press's turn, the next-turn deliveries) run.
    private func settle() async {
        for _ in 0..<8 {
            await Task.yield()
        }
    }

    /// Past the settle wait after a lift (`settleDelay`, 0.3 s), with the deliveries run.
    private func waitPastTheSettle() async {
        try? await Task.sleep(for: .seconds(InkCanvasView.settleDelay + 0.3))
        await settle()
    }

    // MARK: Tests

    /// §3.8: the iPad's month (1024 × 1180, width-bound: open = fit = 0.7314) with a line written on 10/7 (↶ has a step) and
    /// selected with the lasso, pinched to twice the opening zoom and scrolled: one press goes back to the opening zoom on the
    /// next turn (not inside the update), the paper centred across and the paper y in the middle of the screen kept; ratio 1
    /// is reported once with the end of zooming; the paper is redrawn at the new zoom; ↶ and the selection stay. The same
    /// count again does nothing. Without the end-of-pinch path at its end (MZ2) nothing is reported.
    func testTwiceTheOpeningZoomGoesBackOnceKeepingUndoAndTheSelection() async throws {
        let (layout, paper) = makeMonth()
        let writes = PageWrites(InkPage.empty(pageId: layout.pageId))
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .lasso, page: writes.binding)
        let open = rig.canvas.zoomScale
        XCTAssertEqual(open, 1024.0 / 1400, accuracy: 1e-6, "the month opens at fit-to-width")

        let cell = try XCTUnwrap(layout.cells[.day(wednesday)], "10/7's cell")
        draw(makeStroke(at: CGPoint(x: cell.minX + 20, y: cell.minY + 40)), on: rig)
        await settle()
        let ids = rig.coordinator.ledger.page.liveStrokeIds
        XCTAssertEqual(ids.count, 1, "the line is in the ledger")
        XCTAssertTrue(rig.coordinator.ledger.canUndo, "↶ has the line")
        let box = try XCTUnwrap(rig.coordinator.ledger.paperBounds(ids: ids)).insetBy(dx: -20, dy: -20)
        rig.coordinator.overlay(rig.container.overlayView, didFinishLasso: [
            CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY),
        ])
        await settle()
        XCTAssertEqual(rig.probe.selections.last??.ids, ids, "the line is selected")
        XCTAssertNotNil(rig.container.overlayView.selectionBBox)

        await pinch(rig, to: 2 * open)
        scroll(rig, to: CGPoint(x: 300, y: 900))
        await settle()
        let before = rig.canvas.contentOffset
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6)
        let y = expectedY(rig, layout: layout, before: before.y, zoom: 2 * open, open: open)

        rig.press(1)
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "never inside the SwiftUI update")
        XCTAssertEqual(rig.probe.ratios, [], "nothing synchronously")
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-6, "等倍: the opening zoom")
        // UIKit snaps contentOffset to the pixel grid: ± 0.5 pt (InkCanvasViewTests).
        XCTAssertEqual(rig.canvas.contentOffset.x, -rig.canvas.contentInset.left, accuracy: 0.5, "the paper centred across")
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "the paper y in the middle of the screen kept")
        XCTAssertEqual(rig.canvas.contentSize.width, layout.size.width * open, accuracy: 0.5)
        XCTAssertEqual(rig.probe.ratios.count, 1, "ratio 1 reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6)
        XCTAssertEqual(rig.probe.zooming, [false], "with the end of zooming (the screen's frozen band lanes let go)")
        XCTAssertEqual(rig.paperView.zoomScale, open, accuracy: 1e-6, "the paper is redrawn at the new zoom")
        XCTAssertEqual(rig.paperView.transform, .identity)
        XCTAssertEqual(rig.probe.last?.zoom ?? 0, open, accuracy: 1e-6, "the heading follows")
        XCTAssertTrue(rig.coordinator.ledger.canUndo, "↶ stays")
        XCTAssertEqual(rig.coordinator.ledger.page.liveStrokeIds, ids, "the line stays")
        XCTAssertEqual(rig.probe.selections.last??.ids, ids, "the selection stays")
        XCTAssertNotNil(rig.container.overlayView.selectionBBox)

        rig.press(1)
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "the same count does nothing")
    }

    /// §3.6, §3.8: a month whose row grew (10/7 to 400 lu: its overview 1,400 × 1,275) on a landscape iPad (1366 × 830) can be
    /// pinched below its opening zoom (min 830 / 1,275, open 830 / 1,050). 等倍 brings it up to the opening zoom, the paper
    /// centred across and the paper y in the middle of the screen kept (the midY rule), and reports ratio 1.
    func testAMonthPinchedBelowTheOpeningZoomComesUpToIt() async {
        let (grown, grownPaper) = makeMonth(inkBottoms: [.day(wednesday): 388])
        XCTAssertEqual(grown.memo.minY, 1275, accuracy: 0.01, "one row of 400 lu")
        let rig = await makeRig(layout: grown, paper: grownPaper, width: 1366, height: 830)
        let open = 830.0 / 1050
        let minimum = 830.0 / 1275
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.minimumZoomScale, minimum, accuracy: 1e-4)
        await pinch(rig, to: minimum)
        XCTAssertEqual(rig.canvas.zoomScale, minimum, accuracy: 1e-4, "below the opening zoom")
        scroll(rig, to: CGPoint(x: rig.canvas.contentOffset.x, y: 300))
        await settle()
        let y = expectedY(rig, layout: grown, before: rig.canvas.contentOffset.y, zoom: rig.canvas.zoomScale, open: open)

        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4, "up to the opening zoom")
        XCTAssertEqual(rig.canvas.contentOffset.x, -(1366 - 1400 * rig.canvas.zoomScale) / 2, accuracy: 0.5, "centred across")
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "the middle of the screen kept")
        XCTAssertGreaterThan(rig.canvas.contentOffset.y, 300, "the part looked at stays in view (not the top)")
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6)
    }

    /// §3.6: at the opening zoom a press does nothing — the scrolled month stays where it is, nothing is reported.
    func testAtTheOpeningZoomNothingMovesAndNothingIsReported() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        let open = rig.canvas.zoomScale
        scroll(rig, to: CGPoint(x: rig.canvas.contentOffset.x, y: 500))
        await settle()
        let before = rig.canvas.contentOffset
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-9)
        XCTAssertEqual(rig.canvas.contentOffset.x, before.x, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentOffset.y, before.y, accuracy: 0.001, "nothing moves")
        XCTAssertEqual(rig.probe.ratios, [], "nothing is reported")
        XCTAssertEqual(rig.probe.zooming, [])
    }

    /// §3.8 (0e-9): during a pinch or its bounce (`liveOverride`) a press is dropped — and not kept: when the pinch is over
    /// the zoom is still the pinch's. The next press works.
    func testDuringAPinchThePressIsDroppedNotKept() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        let open = rig.canvas.zoomScale
        await pinch(rig, to: 2 * open)
        rig.coordinator.liveOverride = true
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "dropped while live")
        rig.coordinator.liveOverride = nil
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "not kept for later")
        XCTAssertEqual(rig.probe.ratios, [])
        rig.press(2)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-6, "the next press")
        XCTAssertEqual(rig.probe.ratios.count, 1)
    }

    /// §3.8 (0e-9; MZ1): under the pen (PencilKit's tool in use) a press is dropped, and the lift does not bring it back
    /// (nor does the end of the settle wait). The next press works.
    func testUnderThePenThePressIsDroppedNotKept() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen))
        let open = rig.canvas.zoomScale
        await pinch(rig, to: 2 * open)
        touch(rig)
        XCTAssertTrue(rig.coordinator.isUsingTool)
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "never under the pen")
        lift(rig)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "not at the lift")
        await waitPastTheSettle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "nor after the settle wait")
        XCTAssertEqual(rig.probe.ratios, [])
        rig.press(2)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-6, "the next press")
    }

    /// §3.8 (0e-9): the settle wait (0.3 s after a lift) does not hold a press, as it does not hold 「今日」's reveal: 0.1 s after
    /// the lift it works.
    func testInTheSettleWaitAfterALiftThePressWorks() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen))
        let open = rig.canvas.zoomScale
        await pinch(rig, to: 2 * open)
        touch(rig)
        lift(rig)
        try? await Task.sleep(for: .seconds(0.1))
        XCTAssertFalse(rig.coordinator.isUsingTool)
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-6, "0.1 s after the lift")
        XCTAssertEqual(rig.probe.ratios.count, 1)
    }

    /// §3.8 (0e-9): a new page arrives in this canvas inside the settle wait (`resetScroll`: the canvas still shows the old
    /// page until its drawing is rebuilt). A press then is dropped — the old page is not moved, nothing is reported — and
    /// not kept: once the settle wait is over the new page opens at its own ratio (2 here), and stays there.
    func testWhileANewPageWaitsForItsDrawingThePressIsDropped() async {
        let (october, octoberPaper) = makeMonth()
        let (november, novemberPaper) = makeNovember()
        XCTAssertNotEqual(november.pageId, october.pageId)
        let rig = await makeRig(layout: october, paper: octoberPaper, width: 1024, height: 1180, tool: .ink(InkPresets.defaultPen))
        let open = rig.canvas.zoomScale
        await pinch(rig, to: 2 * open)
        touch(rig)
        lift(rig)
        func next(_ trigger: Int) -> InkCanvasView {
            makeView(layout: november, paper: novemberPaper, viewportWidth: 1024, probe: rig.probe, initialZoomRatio: 2,
                     tool: .ink(InkPresets.defaultPen), zoomResetTrigger: trigger)
        }
        rig.coordinator.update(from: next(0))
        XCTAssertEqual(rig.coordinator.ledger.page.pageId, november.pageId, "November's ledger, the drawing not yet")
        rig.coordinator.update(from: next(1))
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "the old page is not moved")
        XCTAssertEqual(rig.probe.ratios, [], "nothing reported")
        await waitPastTheSettle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "November opens at its own ratio")
        XCTAssertEqual(rig.probe.ratios.count, 1, "November's first layout only")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 2, accuracy: 1e-3)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-6, "the press was not kept")
    }

    /// §3.8 (0e-9): before the first zoom (no layout pass yet) a press is dropped; the first layout then opens the page at its
    /// ratio (2) and nothing brings it back to the opening zoom.
    func testBeforeTheFirstZoomThePressIsDropped() async {
        let (layout, paper) = makeMonth()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, initialZoomRatio: 2, layOut: false)
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.probe.ratios, [], "no zoom yet")
        rig.layout(width: 1024, height: 1180)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * 1024.0 / 1400, accuracy: 1e-6, "opened at its ratio")
        XCTAssertEqual(rig.probe.ratios.count, 1, "the first layout's own report")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 2, accuracy: 1e-3)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 2 * 1024.0 / 1400, accuracy: 1e-6, "the press was not kept")
    }

    /// §2.1, §3.7: the value a canvas is made with does nothing — the default 0, and the screen's count after earlier presses
    /// (each page of the one-page path is a new canvas made with the screen's `zoomResetTrigger` as it is). A page that opens
    /// zoomed in (its stored ratio 2) stays zoomed in through updates with that value.
    func testTheValueACanvasIsMadeWithDoesNothing() async {
        let (layout, paper) = makeMonth()
        for made in [0, 5] {
            let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, initialZoomRatio: 2, zoomResetTrigger: made)
            XCTAssertEqual(rig.canvas.zoomScale, 2 * 1024.0 / 1400, accuracy: 1e-6, "made with \(made)")
            rig.press(made)
            await settle()
            rig.press(made)
            await settle()
            XCTAssertEqual(rig.canvas.zoomScale, 2 * 1024.0 / 1400, accuracy: 1e-6, "made with \(made): still zoomed in")
            XCTAssertEqual(rig.probe.ratios, [], "made with \(made)")
            rig.press(made + 1)
            await settle()
            XCTAssertEqual(rig.canvas.zoomScale, 1024.0 / 1400, accuracy: 1e-6, "made with \(made): a press after it works")
        }
    }

    /// §3.8 (the all-day band's second settle): on the iPad's week a reset from a big zoom happens with the band tall (the
    /// paper area 1,100 pt); the band then shrinks (the screen's lanes follow the zoom) and the paper area grows to 1,180 pt:
    /// `applyBounds` takes the page from the old opening zoom to the new one with its top kept, silently. It ends exactly where
    /// a page opened fresh in 1,180 pt is: the same zoom and offset, and ratio 1 reported once in all.
    func testTheBandsSecondSettleEndsAtAFreshPagesOpeningZoom() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1100)
        XCTAssertEqual(rig.canvas.zoomScale, 1100.0 / 1920, accuracy: 1e-4)
        await pinch(rig, to: 2.0)
        scroll(rig, to: CGPoint(x: 500, y: 1200))
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, 1100.0 / 1920, accuracy: 1e-4, "the opening zoom of the tall band's area")
        rig.layout(width: 1024, height: 1180)
        await settle()
        let fresh = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        XCTAssertEqual(rig.canvas.zoomScale, fresh.canvas.zoomScale, accuracy: 1e-6, "a fresh page's opening zoom")
        XCTAssertEqual(rig.canvas.zoomScale, 1180.0 / 1920, accuracy: 1e-4)
        XCTAssertEqual(rig.canvas.contentOffset.x, fresh.canvas.contentOffset.x, accuracy: 0.5)
        XCTAssertEqual(rig.canvas.contentOffset.y, fresh.canvas.contentOffset.y, accuracy: 0.5)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the second settle reports nothing")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6)
    }

    /// §3.8's result (the review of D1a): with the toolbar folded or peeking (`bottomClearance` 60) the iPad's week (1024 ×
    /// 1180, height-bound: 1,920 lu × 0.6146 = 1,180 pt, no taller than the screen) still scrolls by the clearance at the
    /// opening zoom (y 0…60). 等倍 puts it where a fresh page opens — centred across, the top of the paper at the top — from
    /// twice the opening zoom scrolled to the middle (the midY rule left it 30 pt down) and to the bottom end (60 pt down).
    /// A longer paper (the month with its memo area) keeps the midY rule above the clearance.
    func testAPageNoTallerThanTheScreenGoesBackToWhereItOpens() async {
        let (layout, paper) = makeWeek()
        let fresh = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, bottomClearance: 60)
        let open = fresh.canvas.zoomScale
        XCTAssertEqual(open, 1180.0 / 1920, accuracy: 1e-4)
        XCTAssertEqual(fresh.canvas.contentInset.bottom, 60, accuracy: 1e-9, "the folded toolbar's clearance")
        XCTAssertEqual(fresh.canvas.contentOffset.y, 0, accuracy: 0.001, "a fresh page opens at its top")
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, bottomClearance: 60)
        var trigger = 0
        for (place, y) in [("the middle", CGFloat(620)), ("the bottom end", 1240)] {
            await pinch(rig, to: 2 * open)
            scroll(rig, to: CGPoint(x: 348, y: y))
            await settle()
            XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "\(place): scrolled")
            trigger += 1
            rig.press(trigger)
            await settle()
            XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-6, "\(place): 等倍")
            XCTAssertEqual(rig.canvas.contentOffset.x, fresh.canvas.contentOffset.x, accuracy: 0.5, "\(place): centred across, as it opens")
            XCTAssertEqual(rig.canvas.contentOffset.y, fresh.canvas.contentOffset.y, accuracy: 0.5, "\(place): the top at the top, as it opens")
            XCTAssertEqual(rig.probe.ratios.last ?? 0, 1, accuracy: 1e-6, "\(place): ratio 1")
        }

        let (month, monthPaper) = makeMonth()
        let long = await makeRig(layout: month, paper: monthPaper, width: 1024, height: 1180, bottomClearance: 60)
        let monthOpen = long.canvas.zoomScale
        await pinch(long, to: 2 * monthOpen)
        scroll(long, to: CGPoint(x: 300, y: 900))
        await settle()
        let kept = expectedY(long, layout: month, before: long.canvas.contentOffset.y, zoom: long.canvas.zoomScale, open: monthOpen)
        long.press(1)
        await settle()
        XCTAssertEqual(long.canvas.zoomScale, monthOpen, accuracy: 1e-6, "the month: 等倍")
        XCTAssertEqual(long.canvas.contentOffset.y, kept, accuracy: 0.5, "the month: the paper y in the middle above the clearance kept")
        XCTAssertGreaterThan(long.canvas.contentOffset.y, 60, "the month: not its top")
    }
}
