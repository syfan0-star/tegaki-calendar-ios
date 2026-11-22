import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §6.1, §3.6–§3.9, §16.3, §16.6, 0e-7–0e-10): 等倍 on the one page — `zoomResetTrigger`,
/// step 8 of `update(from:)` and `resetZoom()` of the canvas, and since the canvas's second re-base (§16.4) `initialFit`,
/// `onZoomFitChange` and the fit state (DATA_1_1's row 1). The canvas is built as the frozen `InkCanvasViewTests` builds it
/// (TESTS_1_2_3: that file is not touched, so its rig is copied here): the coordinator attached to a container,
/// `liveOverride` for a pinch XCTest cannot make, `pinch()` for UIKit's end-of-pinch calls, the probe's `ratios` for
/// `onZoomRatioChange` and `fits` for `onZoomFitChange`.
///
/// The month (the first nine tests, as before): a press goes back once, on the next main-actor turn (never inside the
/// update), to the opening zoom of the limits in force (`Bounds.open`, ratio 1), and reports ratio 1 once (the screen's
/// closure then removes the kind's stored ratio, 0e-10); ↶ and the lasso selection stay. A month pinched below the opening
/// zoom comes up to it, keeping the paper y in the middle of the screen. At the opening zoom nothing moves and nothing is
/// reported. Under the pen, during a pinch, while a new page waits for its drawing and before the first zoom the press is
/// dropped, never kept for later; in the settle wait after a lift it works. The value a canvas is made with does nothing.
///
/// The week and the day (§16.3, the owner's words of 11/22): a press goes to fit — one page exactly as wide as the screen,
/// no margin — keeping the paper y in the middle of the screen (a page no taller than the screen goes back to its top,
/// where it opens, with the toolbar folded too; the review of D1a), and reports the ratio fit / open and the fit state once.
/// At fit nothing moves and nothing is reported; where the opening zoom is fit already (the 18 Pro Max's portrait week) the
/// press only takes the fit state. In the fit state a change of width goes to the new fit (a turn, the toolbar on a side)
/// and a change of height keeps fit (the all-day band's second settle, a lane more); a pinch ends it. `initialFit` opens a
/// week or a day at fit (a new page in the canvas reads it again); the month does not read it.
@MainActor
final class InkCanvasZoomResetTests: XCTestCase {
    /// What the canvas told its owner.
    private final class Probe {
        var last: PaperViewport?
        var ratios: [CGFloat] = []
        /// `onZoomFitChange` (1.4.1, §16.3.3): one with each ratio.
        var fits: [Bool] = []
        var zooming: [Bool] = []
        var selections: [InkSelection?] = []
        /// What the first layout reported (`makeRig` keeps it here, then empties `ratios` and `fits`).
        var opening: (ratios: [CGFloat], fits: [Bool]) = ([], [])
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

    /// The week of 10/5 (or of `focus`): 1400 × 1920 lu.
    private func makeWeek(focus: DayKey? = nil) -> (layout: WeekPageLayout, paper: PaperContent) {
        let layout = WeekLayoutEngine.layout(WeekLayoutInput(focus: focus ?? wednesday, events: [], inkBottoms: [:], now: now))
        return (layout, .week(WeekPaperContent(layout: layout)))
    }

    /// 10/7: 1000 lu wide (the 24 hours, 2,400 lu, and the free memo area below them).
    private func makeDay() -> (layout: DayPageLayout, paper: PaperContent) {
        let layout = DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: [], inkBottoms: [:], now: now))
        return (layout, .day(DayPaperContent(layout: layout)))
    }

    /// The canvas as the screen builds it, with the press count `zoomResetTrigger` (the screen's `@State`), the toolbar's
    /// `bottomClearance` (0 expanded, 60 folded or peeking) and `initialFit` (the kind's stored fit, 1.4.1 §16.3.4).
    private func makeView(layout: any PageLayout, paper: PaperContent, viewportWidth: CGFloat, probe: Probe,
                          initialZoomRatio: CGFloat = 1, tool: CanvasTool = .eraser, page: Binding<InkPage>? = nil,
                          bottomClearance: CGFloat = 0, zoomResetTrigger: Int = 0, initialFit: Bool = false) -> InkCanvasView {
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
            zoomResetTrigger: zoomResetTrigger,
            initialFit: initialFit,
            onZoomFitChange: { probe.fits.append($0) }
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

    /// A canvas made with `zoomResetTrigger` (and `initialFit`), laid out once at `width` × `height` (unless `layOut` is false)
    /// and settled; the first layout's own report is kept in `probe.opening` and dropped from the rest, so a test collects
    /// only what it causes.
    private func makeRig(layout: any PageLayout, paper: PaperContent, width: CGFloat, height: CGFloat, initialZoomRatio: CGFloat = 1,
                         tool: CanvasTool = .eraser, page: Binding<InkPage>? = nil, bottomClearance: CGFloat = 0,
                         zoomResetTrigger: Int = 0, initialFit: Bool = false, layOut: Bool = true) async -> Rig {
        let probe = Probe()
        let make: (Int) -> InkCanvasView = { [unowned self] trigger in
            self.makeView(layout: layout, paper: paper, viewportWidth: width, probe: probe, initialZoomRatio: initialZoomRatio,
                          tool: tool, page: page, bottomClearance: bottomClearance, zoomResetTrigger: trigger, initialFit: initialFit)
        }
        let coordinator = InkCanvasView.Coordinator(parent: make(zoomResetTrigger))
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        let rig = Rig(coordinator: coordinator, container: container, probe: probe, view: make)
        if layOut {
            rig.layout(width: width, height: height)
        }
        await settle()
        probe.opening = (probe.ratios, probe.fits)
        probe.ratios.removeAll()
        probe.fits.removeAll()
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
        rig.probe.fits.removeAll()
        rig.probe.zooming.removeAll()
    }

    /// The paper scrolled to `offset` (pt), as a finger leaves it.
    private func scroll(_ rig: Rig, to offset: CGPoint) {
        rig.canvas.contentOffset = offset
        rig.coordinator.scrollViewDidScroll(rig.canvas)
    }

    /// The offset `resetZoom` puts y at on a paper taller than the screen at its target (`open`: the month's opening zoom, the
    /// week's or the day's fit): the paper y in the middle of what shows above the bottom clearance kept, clamped to the paper
    /// (§3.8 steps 1, 4 and 5; §16.3.2).
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

    /// The week's or the day's fit at a paper column `width` wide (§16.3.1): vw / W, one page exactly as wide as the column.
    private func fit(_ kind: PageKind, _ width: CGFloat) -> CGFloat {
        width / ZoomPolicy.paperWidth(kind)
    }

    /// The page is at fit for the paper column it has now: the zoom vw / W, no margin at the sides, the paper's left edge on the
    /// screen's (x 0; UIKit puts offsets on the pixel grid, ± 0.5 pt) and the content exactly as wide as the screen.
    private func assertFit(_ rig: Rig, _ kind: PageKind, _ step: String, line: UInt = #line) {
        let width = rig.container.bounds.width
        XCTAssertEqual(rig.canvas.zoomScale, fit(kind, width), accuracy: 1e-6, "\(step): fit (\(width) / \(ZoomPolicy.paperWidth(kind)))", line: line)
        XCTAssertEqual(rig.canvas.contentInset.left, 0, accuracy: 1e-9, "\(step): no margin at the left", line: line)
        XCTAssertEqual(rig.canvas.contentInset.right, 0, accuracy: 1e-9, "\(step): no margin at the right", line: line)
        XCTAssertEqual(rig.canvas.contentOffset.x, 0, accuracy: 0.5, "\(step): the paper's left edge on the screen's", line: line)
        XCTAssertEqual(rig.canvas.contentSize.width, width, accuracy: 0.5, "\(step): one page as wide as the screen", line: line)
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

    // MARK: The week and the day (§16.3)

    /// §16.3.3 (the all-day band's second settle; 1.4.1's first version ended at a fresh page's opening zoom): on the iPad's
    /// week a reset from a big zoom happens with the band tall (the paper area 1,024 × 1,100: open 1,100 / 1,920) and goes to
    /// fit (1,024 / 1,400 = 0.7314), the paper y in the middle of the screen kept. The band then shrinks and the paper area
    /// grows to 1,180 pt (open 1,180 / 1,920): fit is the width's alone, so the page stays at fit with its offset, silently —
    /// one report in all: the ratio fit / open of the tall band's area and the fit state.
    func testTheBandsSecondSettleKeepsFit() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1100)
        let open = 1100.0 / 1920
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4)
        await pinch(rig, to: 2.0)
        scroll(rig, to: CGPoint(x: 500, y: 1200))
        await settle()
        let y = expectedY(rig, layout: layout, before: rig.canvas.contentOffset.y, zoom: 2.0, open: fit(.week, 1024))
        rig.press(1)
        await settle()
        assertFit(rig, .week, "1,100")
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "the paper y in the middle of the screen kept")
        rig.layout(width: 1024, height: 1180)
        await settle()
        assertFit(rig, .week, "1,180: still fit")
        XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "1,180: the offset kept")
        XCTAssertEqual(rig.probe.ratios.count, 1, "the second settle reports nothing")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, fit(.week, 1024) / open, accuracy: 1e-3, "the ratio fit / open")
        XCTAssertEqual(rig.probe.fits, [true], "the fit state, once")
        XCTAssertEqual(rig.probe.zooming, [false])
    }

    /// §3.8's result (the review of D1a), §16.3.2: with the toolbar folded or peeking (`bottomClearance` 60) a page no taller
    /// than the screen at its target still scrolls by the clearance. The 18 Pro Max's portrait week (440 × 622: open = fit =
    /// 440 / 1,400; 1,920 lu × 0.3143 = 603 pt) goes where a fresh page opens — as wide as the screen, its top at the top —
    /// from twice that zoom scrolled to the middle and to the bottom end, reporting ratio 1 and the fit state. The iPad's
    /// week (1,024 × 1,180: fit 0.7314, 1,404 pt, taller than the screen) keeps the midY rule above the clearance, as the
    /// month does at its opening zoom.
    func testAPageNoTallerThanTheScreenGoesBackToWhereItOpens() async {
        let (layout, paper) = makeWeek()
        let fresh = await makeRig(layout: layout, paper: paper, width: 440, height: 622, bottomClearance: 60)
        let open = fresh.canvas.zoomScale
        XCTAssertEqual(open, 440.0 / 1400, accuracy: 1e-6, "open = fit (width-bound)")
        XCTAssertEqual(fresh.canvas.contentInset.bottom, 60, accuracy: 1e-9, "the folded toolbar's clearance")
        XCTAssertEqual(fresh.canvas.contentOffset.y, 0, accuracy: 0.001, "a fresh page opens at its top")
        let rig = await makeRig(layout: layout, paper: paper, width: 440, height: 622, bottomClearance: 60)
        var trigger = 0
        let end = layout.size.height * 2 * open + 60 - 622
        for (place, y) in [("the middle", end / 2), ("the bottom end", end)] {
            await pinch(rig, to: 2 * open)
            scroll(rig, to: CGPoint(x: 220, y: y))
            await settle()
            XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "\(place): scrolled")
            trigger += 1
            rig.press(trigger)
            await settle()
            assertFit(rig, .week, place)
            XCTAssertEqual(rig.canvas.contentOffset.x, fresh.canvas.contentOffset.x, accuracy: 0.5, "\(place): as it opens across")
            XCTAssertEqual(rig.canvas.contentOffset.y, fresh.canvas.contentOffset.y, accuracy: 0.5, "\(place): the top at the top, as it opens")
            XCTAssertEqual(rig.probe.ratios.last ?? 0, 1, accuracy: 1e-6, "\(place): ratio 1 (open = fit)")
            XCTAssertEqual(rig.probe.fits.last, true, "\(place): the fit state")
        }

        let tall = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180, bottomClearance: 60)
        let tallOpen = tall.canvas.zoomScale
        XCTAssertEqual(tallOpen, 1180.0 / 1920, accuracy: 1e-4)
        trigger = 0
        for (place, y) in [("the middle", CGFloat(620)), ("the bottom end", 1240)] {
            await pinch(tall, to: 2 * tallOpen)
            scroll(tall, to: CGPoint(x: 348, y: y))
            await settle()
            XCTAssertEqual(tall.canvas.contentOffset.y, y, accuracy: 0.5, "the iPad, \(place): scrolled")
            let kept = expectedY(tall, layout: layout, before: tall.canvas.contentOffset.y, zoom: 2 * tallOpen, open: fit(.week, 1024))
            trigger += 1
            tall.press(trigger)
            await settle()
            assertFit(tall, .week, "the iPad, \(place)")
            XCTAssertEqual(tall.canvas.contentOffset.y, kept, accuracy: 0.5, "the iPad, \(place): the paper y in the middle above the clearance kept")
            XCTAssertGreaterThan(tall.canvas.contentOffset.y, 60, "the iPad, \(place): not its top")
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

    /// §16.3.1, §16.3.2 (「日、週の等倍とは、最小のサイズではなく、日、週の幅が、ちょうど画面両端にくるサイズのことです」): the week (the iPad,
    /// 1,024 × 1,180) and the day (the iPhone, 402 × 536) at their opening zoom — the 24 hours on the screen, the desk showing
    /// at the sides — go to fit on one press, on the next turn: one page exactly as wide as the screen, the paper y in the
    /// middle of the screen kept, the paper redrawn and the heading following; one report: the ratio fit / open, the fit
    /// state and the end of zooming (the screen then keeps the kind's fit, §16.3.4).
    func testAtTheOpeningZoomTheWeekAndTheDayGoToFit() async {
        let (week, weekPaper) = makeWeek()
        let (day, dayPaper) = makeDay()
        let pages: [(layout: any PageLayout, paper: PaperContent, width: CGFloat, height: CGFloat)] = [
            (week, weekPaper, 1024, 1180), (day, dayPaper, 402, 536),
        ]
        for page in pages {
            let kind = page.layout.kind
            let rig = await makeRig(layout: page.layout, paper: page.paper, width: page.width, height: page.height)
            let open = rig.canvas.zoomScale
            XCTAssertEqual(open, min(fit(kind, page.width), page.height / ZoomPolicy.baseSize(kind).height), accuracy: 1e-6, "\(kind): opens at the opening zoom")
            XCTAssertGreaterThan(rig.canvas.contentInset.left, 1, "\(kind): the desk at the sides")
            let y = expectedY(rig, layout: page.layout, before: rig.canvas.contentOffset.y, zoom: open, open: fit(kind, page.width))
            rig.press(1)
            XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-9, "\(kind): never inside the SwiftUI update")
            await settle()
            assertFit(rig, kind, "\(kind)")
            XCTAssertEqual(rig.canvas.contentOffset.y, y, accuracy: 0.5, "\(kind): the paper y in the middle of the screen kept")
            XCTAssertEqual(rig.probe.ratios.count, 1, "\(kind): one report")
            XCTAssertEqual(rig.probe.ratios.first ?? 0, fit(kind, page.width) / open, accuracy: 1e-3, "\(kind): the ratio fit / open")
            XCTAssertEqual(rig.probe.fits, [true], "\(kind): the fit state")
            XCTAssertEqual(rig.probe.zooming, [false], "\(kind): the end of zooming")
            XCTAssertEqual(rig.paperView.zoomScale, fit(kind, page.width), accuracy: 1e-6, "\(kind): the paper redrawn at fit")
            XCTAssertEqual(rig.probe.last?.zoom ?? 0, fit(kind, page.width), accuracy: 1e-6, "\(kind): the heading follows")
        }
    }

    /// §16.3.2: at fit a press does nothing — the day pressed to fit and scrolled stays where it is, nothing is reported (no
    /// going back to the opening zoom: 等倍 is not a toggle); a week opened at fit (`initialFit`, already in the fit state)
    /// likewise.
    func testAtFitAPressDoesNothing() async {
        let (day, dayPaper) = makeDay()
        let rig = await makeRig(layout: day, paper: dayPaper, width: 402, height: 536)
        rig.press(1)
        await settle()
        assertFit(rig, .day, "pressed")
        scroll(rig, to: CGPoint(x: 0, y: 300))
        await settle()
        let before = rig.canvas.contentOffset
        rig.probe.ratios.removeAll()
        rig.probe.fits.removeAll()
        rig.probe.zooming.removeAll()
        rig.press(2)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, fit(.day, 402), accuracy: 1e-9, "the day: still fit")
        XCTAssertEqual(rig.canvas.contentOffset.x, before.x, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentOffset.y, before.y, accuracy: 0.001, "the day: nothing moves")
        XCTAssertEqual(rig.probe.ratios, [], "the day: nothing is reported")
        XCTAssertEqual(rig.probe.fits, [])
        XCTAssertEqual(rig.probe.zooming, [])

        let (week, weekPaper) = makeWeek()
        let opened = await makeRig(layout: week, paper: weekPaper, width: 1024, height: 1180, initialFit: true)
        assertFit(opened, .week, "opened at fit")
        let at = opened.canvas.contentOffset
        opened.press(1)
        await settle()
        XCTAssertEqual(opened.canvas.zoomScale, fit(.week, 1024), accuracy: 1e-9)
        XCTAssertEqual(opened.canvas.contentOffset.y, at.y, accuracy: 0.001, "the week: nothing moves")
        XCTAssertEqual(opened.probe.ratios, [], "the week: nothing is reported")
        XCTAssertEqual(opened.probe.fits, [])
    }

    /// §16.3.2 「採る」, §16.10: the 18 Pro Max's portrait week (440 × 622) opens at fit already (open = fit = 440 / 1,400,
    /// 1,920 lu × 0.3143 = 603 pt, no taller than the screen). A press moves nothing and only takes the fit state: one report,
    /// ratio 1 and fit, with the end of zooming; a second press does nothing at all. The state shows when the phone turns
    /// (832 × 217, the column inside the safe area): the week goes to the landscape fit (one week across, 832 / 1,400) with the
    /// paper y in the middle of the screen kept (Z2-7; without the state, 1.4's rule keeps the opening zoom, 217 / 1,920, and
    /// the top), and back in portrait to fit and its top. A turn reports nothing.
    func testTheProMaxWeekTakesTheFitStateOnly() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 440, height: 622)
        assertFit(rig, .week, "opens at fit")
        XCTAssertEqual(rig.probe.opening.fits, [false], "opened without the fit state")
        let before = rig.canvas.contentOffset
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, fit(.week, 440), accuracy: 1e-9, "nothing moves")
        XCTAssertEqual(rig.canvas.contentOffset.x, before.x, accuracy: 0.001)
        XCTAssertEqual(rig.canvas.contentOffset.y, before.y, accuracy: 0.001)
        XCTAssertEqual(rig.probe.ratios.count, 1, "the fit state taken: reported once")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6, "ratio 1")
        XCTAssertEqual(rig.probe.fits, [true])
        XCTAssertEqual(rig.probe.zooming, [false])
        rig.press(2)
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "the second press does nothing")
        XCTAssertEqual(rig.probe.fits, [true])

        let middle = (rig.canvas.contentOffset.y + 622.0 / 2) / rig.canvas.zoomScale
        rig.layout(width: 832, height: 217)
        assertFit(rig, .week, "landscape: one week across")
        XCTAssertEqual(rig.canvas.contentOffset.y, middle * fit(.week, 832) - 217.0 / 2, accuracy: 0.5, "landscape: the paper y in the middle kept (Z2-7)")
        rig.layout(width: 440, height: 622)
        assertFit(rig, .week, "portrait again")
        XCTAssertEqual(rig.canvas.contentOffset.y, 0, accuracy: 0.5, "portrait again: no taller than the screen, its top")
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "a turn reports nothing")
    }

    /// §16.3.3, §16.3.5 (Z2-6): in the fit state a change of width goes to the new fit. The 13-inch iPad's portrait week and day
    /// (1,032 wide) with the toolbar put on a side (958: the column loses the side slot's 74 pt), folded there (1,032 again,
    /// the round button's clearance 60) and opened there again (958): each time one page exactly as wide as the column.
    /// Nothing is reported (a change of width never reports; the screen keeps the fit state it was told of).
    func testFitFollowsTheSideToolbar() async {
        let (week, weekPaper) = makeWeek()
        let (day, dayPaper) = makeDay()
        let pages: [(layout: any PageLayout, paper: PaperContent, height: CGFloat)] = [(week, weekPaper, 1121), (day, dayPaper, 1117)]
        for page in pages {
            let kind = page.layout.kind
            let rig = await makeRig(layout: page.layout, paper: page.paper, width: 1032, height: page.height)
            rig.press(1)
            await settle()
            assertFit(rig, kind, "\(kind), 1,032")
            rig.layout(width: 958, height: page.height)
            assertFit(rig, kind, "\(kind), 958: the toolbar on a side")
            rig.coordinator.update(from: makeView(layout: page.layout, paper: page.paper, viewportWidth: 1032, probe: rig.probe,
                                                  bottomClearance: 60, zoomResetTrigger: 1))
            rig.layout(width: 1032, height: page.height)
            assertFit(rig, kind, "\(kind), 1,032: folded on the side")
            XCTAssertEqual(rig.canvas.contentInset.bottom, 60, accuracy: 1e-9, "\(kind): the round button's clearance")
            rig.coordinator.update(from: makeView(layout: page.layout, paper: page.paper, viewportWidth: 958, probe: rig.probe,
                                                  bottomClearance: 0, zoomResetTrigger: 1))
            rig.layout(width: 958, height: page.height)
            assertFit(rig, kind, "\(kind), 958: opened on the side again")
            await settle()
            XCTAssertEqual(rig.probe.ratios.count, 1, "\(kind): the press's report only")
            XCTAssertEqual(rig.probe.fits, [true], "\(kind)")
        }
    }

    /// §16.3.3 (Z2-6, Z2-7): the iPhone's day at fit (402 × 536: 0.402) turned to landscape (874 × 205) and back: fit each
    /// time (874 / 1,000: one day across; 0.402), with the paper point in the middle of the screen kept (15:00, 1,500 lu),
    /// as a zoomed-in page keeps it (the middle read with the size the last pass laid out, 0d-44). A turn reports nothing.
    func testATurnFollowsFit() async {
        let (day, paper) = makeDay()
        let rig = await makeRig(layout: day, paper: paper, width: 402, height: 536)
        rig.press(1)
        await settle()
        assertFit(rig, .day, "portrait")
        scroll(rig, to: CGPoint(x: 0, y: 1500 * fit(.day, 402) - 536.0 / 2))
        await settle()
        rig.layout(width: 874, height: 205)
        assertFit(rig, .day, "landscape: one day across")
        XCTAssertEqual(rig.canvas.contentOffset.y, 1500 * fit(.day, 874) - 205.0 / 2, accuracy: 0.5, "landscape: 15:00 in the middle")
        rig.layout(width: 402, height: 536)
        assertFit(rig, .day, "portrait again")
        XCTAssertEqual(rig.canvas.contentOffset.y, 1500 * fit(.day, 402) - 536.0 / 2, accuracy: 0.5, "portrait again: 15:00 in the middle")
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "a turn reports nothing")
    }

    /// §16.3.3 (Z2-8): a change of height alone (the all-day lanes, the toolbar above or below opened, folded or peeking) keeps
    /// fit — fit is the width's alone. The iPad's week at fit through 1,100, 1,205 and 1,180 pt; the 18 Pro Max's portrait
    /// week opened at fit (`initialFit`; 440 × 622, open = fit) through one lane more (597 pt: the opening zoom drops to
    /// 597 / 1,920, which 1.4's rule at the opening zoom would follow) and back. Nothing is reported.
    func testFitStaysWhenTheLanesGrowOrShrink() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 1024, height: 1180)
        rig.press(1)
        await settle()
        for height in [CGFloat(1100), 1205, 1180] {
            rig.layout(width: 1024, height: height)
            assertFit(rig, .week, "the iPad, \(height)")
        }
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "the iPad: the press's report only")

        let phone = await makeRig(layout: layout, paper: paper, width: 440, height: 622, initialFit: true)
        XCTAssertEqual(phone.probe.opening.fits, [true], "the phone: opened in the fit state")
        for height in [CGFloat(597), 622] {
            phone.layout(width: 440, height: height)
            assertFit(phone, .week, "the phone, \(height)")
        }
        XCTAssertEqual(phone.canvas.minimumZoomScale, fit(.week, 440), accuracy: 1e-6, "the phone, 622 again: open = fit")
        await settle()
        XCTAssertEqual(phone.probe.ratios, [], "the phone: nothing reported")
    }

    /// §16.3.3 (Z2-9; MZ6): a pinch ends the fit state. The iPhone's day at fit (402 × 536) pinched to 0.8: the pinch's own
    /// report is its ratio and the fit state off (the screen then keeps the ratio and forgets the fit, §16.3.4); turned to
    /// landscape (874 × 205) and back the page keeps 1.4's absolute zoom (the handwriting keeps its size), not fit.
    func testAPinchAtFitEndsTheFitState() async {
        let (day, paper) = makeDay()
        let rig = await makeRig(layout: day, paper: paper, width: 402, height: 536)
        let open = rig.canvas.zoomScale
        rig.press(1)
        await settle()
        assertFit(rig, .day, "pressed")
        XCTAssertEqual(rig.probe.fits, [true])
        rig.probe.ratios.removeAll()
        rig.probe.fits.removeAll()
        rig.probe.zooming.removeAll()
        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(0.8, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: 0.8)
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "the pinch's report")
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 0.8 / open, accuracy: 1e-3, "the pinch's ratio")
        XCTAssertEqual(rig.probe.fits, [false], "the fit state is over")
        XCTAssertEqual(rig.probe.zooming, [true, false])
        rig.layout(width: 874, height: 205)
        XCTAssertEqual(rig.canvas.zoomScale, 0.8, accuracy: 1e-6, "landscape: the absolute zoom stays (1.4), not fit 0.874")
        rig.layout(width: 402, height: 536)
        XCTAssertEqual(rig.canvas.zoomScale, 0.8, accuracy: 1e-6, "portrait again: the absolute zoom stays")
    }

    /// §16.3.4: a week or a day the screen opens with `initialFit` (the kind's stored fit) opens at fit — one page exactly as
    /// wide as the screen, x 0 — at `initialScrollY` (this week and this day hold today: an hour before now), and the first
    /// layout reports the ratio fit / open and the fit state (so the screen's stored values stay as they are). Without it
    /// the page opens at its opening zoom, as before, and reports the fit state off.
    func testInitialFitOpensAtFit() async {
        let (week, weekPaper) = makeWeek()
        let (day, dayPaper) = makeDay()
        let pages: [(layout: any PageLayout, paper: PaperContent)] = [(week, weekPaper), (day, dayPaper)]
        for page in pages {
            let kind = page.layout.kind
            let rig = await makeRig(layout: page.layout, paper: page.paper, width: 1024, height: 1180, initialFit: true)
            assertFit(rig, kind, "\(kind)")
            let scrollY = PageNavigation.initialScrollY(page.layout, now: now) * fit(kind, 1024)
            let maxY = max(0, page.layout.size.height * fit(kind, 1024) - 1180)
            XCTAssertEqual(rig.canvas.contentOffset.y, min(max(0, scrollY), maxY), accuracy: 0.5, "\(kind): at initialScrollY")
            let open = min(fit(kind, 1024), 1180 / ZoomPolicy.baseSize(kind).height)
            XCTAssertEqual(rig.probe.opening.ratios.count, 1, "\(kind): the first layout's report")
            XCTAssertEqual(rig.probe.opening.ratios.first ?? 0, fit(kind, 1024) / open, accuracy: 1e-3, "\(kind): the ratio fit / open")
            XCTAssertEqual(rig.probe.opening.fits, [true], "\(kind): the fit state")

            let plain = await makeRig(layout: page.layout, paper: page.paper, width: 1024, height: 1180)
            XCTAssertEqual(plain.canvas.zoomScale, open, accuracy: 1e-6, "\(kind): without it, the opening zoom")
            XCTAssertEqual(plain.probe.opening.fits, [false], "\(kind): without it, the fit state off")
        }
    }

    /// §16.3.4, §16.3.6: the month does not read `initialFit` — it opens at its stored ratio (2) and reports the fit state off
    /// — and its 等倍 is the opening zoom, as before (ratio 1, the fit state off); a change of width then keeps 1.4's rule (the
    /// opening zoom stays the opening zoom: 830 / 1,050 on a landscape iPad, 1,366 or 1,292 wide), not fit.
    func testTheMonthDoesNotReadInitialFit() async {
        let (month, paper) = makeMonth()
        let rig = await makeRig(layout: month, paper: paper, width: 1366, height: 830, initialZoomRatio: 2, initialFit: true)
        let open = 830.0 / 1050
        XCTAssertEqual(rig.canvas.zoomScale, 2 * open, accuracy: 1e-4, "the stored ratio, not fit")
        XCTAssertEqual(rig.probe.opening.fits, [false])
        rig.press(1)
        await settle()
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4, "等倍: the opening zoom (fit would be 1,366 / 1,400)")
        XCTAssertEqual(rig.probe.ratios.count, 1)
        XCTAssertEqual(rig.probe.ratios.first ?? 0, 1, accuracy: 1e-6)
        XCTAssertEqual(rig.probe.fits, [false], "the month has no fit state")
        rig.layout(width: 1292, height: 830)
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4, "1,292: the opening zoom stays the opening zoom, not 1,292 / 1,400")
    }

    /// §16.3.3, §16.10: on the one-page path a new page coming to the same canvas opens through step 3 again and reads
    /// `initialFit` again. After a press (the fit state), the next week arriving without it (nothing stored) opens at its
    /// opening zoom and is out of the fit state: the toolbar put on a side (958) keeps the opening zoom (1.4's rule), not
    /// fit. The week after it, arriving with it, opens at fit and follows fit back to 1,024.
    func testANewPageInTheCanvasReadsInitialFitAgain() async {
        let (week, paper) = makeWeek()
        let rig = await makeRig(layout: week, paper: paper, width: 1024, height: 1180)
        rig.press(1)
        await settle()
        assertFit(rig, .week, "pressed")
        let open = 1180.0 / 1920
        let (next, nextPaper) = makeWeek(focus: DayKey(year: 2026, month: 10, day: 14))
        XCTAssertNotEqual(next.pageId, week.pageId)
        rig.coordinator.update(from: makeView(layout: next, paper: nextPaper, viewportWidth: 1024, probe: rig.probe, zoomResetTrigger: 1))
        await settle()
        XCTAssertEqual(rig.coordinator.ledger.page.pageId, next.pageId, "the next week in the canvas")
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4, "the next week: its opening zoom")
        XCTAssertEqual(rig.probe.fits.last, false, "the next week: the fit state off")
        rig.layout(width: 958, height: 1180)
        XCTAssertEqual(rig.canvas.zoomScale, open, accuracy: 1e-4, "958: the opening zoom stays (not 958 / 1,400)")

        let (after, afterPaper) = makeWeek(focus: DayKey(year: 2026, month: 10, day: 21))
        rig.coordinator.update(from: makeView(layout: after, paper: afterPaper, viewportWidth: 958, probe: rig.probe, zoomResetTrigger: 1,
                                              initialFit: true))
        await settle()
        XCTAssertEqual(rig.coordinator.ledger.page.pageId, after.pageId, "the week after in the canvas")
        assertFit(rig, .week, "the week after: opened at fit")
        XCTAssertEqual(rig.probe.fits.last, true, "the week after: the fit state")
        rig.layout(width: 1024, height: 1180)
        assertFit(rig, .week, "the week after, 1,024: follows fit")
    }
}
