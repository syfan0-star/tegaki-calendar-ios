import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §3.10, §6.1, 0e-11; 1.4's 0d-44): when the width of a zoomed-in one page changes (the
/// toolbar put on a side or taken off it, 74 pt; a turn), step 4 of `containerDidLayout` keeps the paper point that was in
/// the middle of the screen in the middle. It reads that point with the size the last pass laid out (`lastLayoutSize`);
/// 1.4 read it with the new width and height and the old offset, half the change off: 37 pt sideways for the side toolbar
/// (MZ3, the two lines put back, turns these red). At the opening zoom and at the lowest zoom the paper is centred across
/// by the clamp and the top of the view keeps its paper y, as in 1.4 (the two lines change nothing there).
///
/// The canvas is built as the frozen `InkCanvasViewTests` builds it (TESTS_1_2_3: its rig is copied, the file is not
/// touched). The offsets are chosen inside the scroll range at both widths, so UIKit's own clamp when the frame changes
/// never moves them; UIKit puts offsets on the pixel grid: ± 0.5 pt.
@MainActor
final class InkCanvasWidthCentreTests: XCTestCase {
    private final class Probe {
        var ratios: [CGFloat] = []
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

    /// 10/7: 1000 lu wide (the 24 hours and the free memo area below them).
    private func makeDay() -> (layout: DayPageLayout, paper: PaperContent) {
        let layout = DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: [], inkBottoms: [:], now: now))
        return (layout, .day(DayPaperContent(layout: layout)))
    }

    @MainActor
    private struct Rig {
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let probe: Probe
        var canvas: PKCanvasView { container.canvasView }

        /// The parent's layout pass at a new size.
        func layout(width: CGFloat, height: CGFloat) {
            container.frame = CGRect(x: 0, y: 0, width: width, height: height)
            container.layoutSubviews()
        }

        /// The paper point (lu) in the middle of the screen.
        var middle: CGPoint {
            let zoom = max(canvas.zoomScale, 0.0001)
            return CGPoint(x: (canvas.contentOffset.x + container.bounds.width / 2) / zoom,
                           y: (canvas.contentOffset.y + container.bounds.height / 2) / zoom)
        }
    }

    /// A canvas wired like `makeUIView`, laid out once at `width` × `height` and settled.
    private func makeRig(layout: any PageLayout, paper: PaperContent, width: CGFloat, height: CGFloat) async -> Rig {
        let probe = Probe()
        let view = InkCanvasView(
            layout: layout,
            paper: paper,
            tool: .eraser,
            allowFinger: false,
            page: .constant(InkPage.empty(pageId: layout.pageId)),
            initialScrollY: PageNavigation.initialScrollY(layout, now: now),
            initialScrollX: PageNavigation.initialScrollX(
                layout, now: now,
                visibleWidth: ZoomPolicy.visibleWidth(layout.kind, viewportWidth: width, zoom: ZoomPolicy.readableZoom(layout.kind))
            ),
            onTap: { _, _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onZoomRatioChange: { probe.ratios.append($0) }
        )
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        let rig = Rig(coordinator: coordinator, container: container, probe: probe)
        rig.layout(width: width, height: height)
        await settle()
        probe.ratios.removeAll()
        return rig
    }

    /// The end-of-pinch path as UIKit drives it, without a pinch.
    private func pinch(_ rig: Rig, to zoom: CGFloat) async {
        rig.coordinator.scrollViewWillBeginZooming(rig.canvas, with: nil)
        rig.canvas.setZoomScale(zoom, animated: false)
        rig.coordinator.scrollViewDidEndZooming(rig.canvas, with: nil, atScale: zoom)
        await settle()
    }

    /// The paper point `point` (lu) put in the middle of the screen, as a finger leaves it.
    private func centre(_ rig: Rig, on point: CGPoint) {
        let zoom = rig.canvas.zoomScale
        rig.canvas.contentOffset = CGPoint(x: point.x * zoom - rig.container.bounds.width / 2,
                                           y: point.y * zoom - rig.container.bounds.height / 2)
        rig.coordinator.scrollViewDidScroll(rig.canvas)
    }

    /// The paper point in the middle of the screen is `point`, within 0.5 pt on the screen.
    private func assertMiddle(_ rig: Rig, _ point: CGPoint, _ step: String, line: UInt = #line) {
        let zoom = rig.canvas.zoomScale
        XCTAssertEqual(rig.middle.x * zoom, point.x * zoom, accuracy: 0.5, "\(step): across (\(rig.middle))", line: line)
        XCTAssertEqual(rig.middle.y * zoom, point.y * zoom, accuracy: 0.5, "\(step): up and down (\(rig.middle))", line: line)
    }

    private func settle() async {
        for _ in 0..<8 {
            await Task.yield()
        }
    }

    // MARK: Tests

    /// The 13-inch iPad's week zoomed in (1,032 × 1,200, the opening zoom 0.625, pinched to 1.25) with the toolbar put on a
    /// side and back (1,032 → 958 → 1,032, the height unchanged): the paper point (700, 900) stays in the middle each time.
    /// 1.4 kept the point 37 pt / 1.25 to the side of it.
    func testTheSideToolbarKeepsTheMiddleOfAZoomedInPage() async {
        let (layout, paper) = makeWeek()
        let rig = await makeRig(layout: layout, paper: paper, width: 1032, height: 1200)
        XCTAssertEqual(rig.canvas.zoomScale, 1200.0 / 1920, accuracy: 1e-4)
        await pinch(rig, to: 1.25)
        let point = CGPoint(x: 700, y: 900)
        centre(rig, on: point)
        assertMiddle(rig, point, "1,032")
        rig.layout(width: 958, height: 1200)
        XCTAssertEqual(rig.canvas.zoomScale, 1.25, accuracy: 1e-6, "the absolute zoom stays")
        assertMiddle(rig, point, "958")
        rig.layout(width: 1032, height: 1200)
        XCTAssertEqual(rig.canvas.zoomScale, 1.25, accuracy: 1e-6)
        assertMiddle(rig, point, "1,032 again")
        await settle()
        XCTAssertEqual(rig.probe.ratios.count, 1, "the pinch's report only: a change of width reports nothing")
    }

    /// The iPhone's day zoomed in (402 × 580, pinched to 1.5) turned to landscape (874 × 230) and back: the paper point
    /// (450, 1,200) stays in the middle (1.4: 236 pt across and 175 pt up and down off).
    func testATurnKeepsTheMiddleOfAZoomedInPage() async {
        let (layout, paper) = makeDay()
        let rig = await makeRig(layout: layout, paper: paper, width: 402, height: 580)
        await pinch(rig, to: 1.5)
        let point = CGPoint(x: 450, y: 1200)
        centre(rig, on: point)
        assertMiddle(rig, point, "portrait")
        rig.layout(width: 874, height: 230)
        XCTAssertEqual(rig.canvas.zoomScale, 1.5, accuracy: 1e-6, "the handwriting keeps its size")
        assertMiddle(rig, point, "landscape")
        rig.layout(width: 402, height: 580)
        XCTAssertEqual(rig.canvas.zoomScale, 1.5, accuracy: 1e-6)
        assertMiddle(rig, point, "portrait again")
    }

    /// At the opening zoom (the iPad's month, width-bound: 1,032 → 958 → 1,032, scrolled 600 pt down) and at the lowest zoom
    /// (a month whose row grew, on a landscape iPad: 1,366 → 1,292 → 1,366) the results are 1.4's: the zoom follows the new
    /// opening / lowest zoom, the paper is centred across and the top of the view stays on the same paper y.
    func testTheOpeningAndTheLowestZoomAreAsBefore() async {
        let (month, monthPaper) = makeMonth()
        let atOpen = await makeRig(layout: month, paper: monthPaper, width: 1032, height: 1200)
        atOpen.canvas.contentOffset = CGPoint(x: atOpen.canvas.contentOffset.x, y: 600)
        atOpen.coordinator.scrollViewDidScroll(atOpen.canvas)
        let top = 600 / atOpen.canvas.zoomScale
        for width in [CGFloat(958), 1032] {
            atOpen.layout(width: width, height: 1200)
            let open = min(width / 1400, 1200.0 / 1050)
            XCTAssertEqual(atOpen.canvas.zoomScale, open, accuracy: 1e-6, "\(width): the new opening zoom")
            XCTAssertEqual(atOpen.canvas.contentOffset.x, -atOpen.canvas.contentInset.left, accuracy: 0.5, "\(width): centred across")
            XCTAssertEqual(atOpen.canvas.contentOffset.y, top * open, accuracy: 0.5, "\(width): the top keeps its paper y")
        }

        let (grown, grownPaper) = makeMonth(inkBottoms: [.day(wednesday): 388])
        let atMin = await makeRig(layout: grown, paper: grownPaper, width: 1366, height: 830)
        let lowest = 830.0 / 1275
        await pinch(atMin, to: lowest)
        atMin.canvas.contentOffset = CGPoint(x: atMin.canvas.contentOffset.x, y: 200)
        atMin.coordinator.scrollViewDidScroll(atMin.canvas)
        let minTop = 200 / atMin.canvas.zoomScale
        for width in [CGFloat(1292), 1366] {
            atMin.layout(width: width, height: 830)
            XCTAssertEqual(atMin.canvas.zoomScale, lowest, accuracy: 1e-4, "\(width): still the lowest zoom")
            XCTAssertEqual(atMin.canvas.contentOffset.x, -(width - 1400 * atMin.canvas.zoomScale) / 2, accuracy: 0.5, "\(width): centred across")
            XCTAssertEqual(atMin.canvas.contentOffset.y, minTop * atMin.canvas.zoomScale, accuracy: 0.5, "\(width): the top keeps its paper y")
        }
    }
}
