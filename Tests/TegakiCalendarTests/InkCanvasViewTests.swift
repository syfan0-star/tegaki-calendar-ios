import InkModel
import Layout
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the canvas's viewport report (M4B_CONTRACT §1.3, §7.2): a viewport born in a
/// layout pass is never delivered synchronously (a `@State` must not change during a view update),
/// it arrives on the next main-actor turn with the page's minimum zoom and `initialScrollX`, the
/// same value is not sent twice, and a new width is reported once.
@MainActor
final class InkCanvasViewTests: XCTestCase {
    /// Counts the deliveries of `onViewportChange`.
    private final class Probe {
        var count = 0
        var last: PaperViewport?
    }

    /// 2026-10-07 (a Wednesday) at 10:00 in the device's time zone, like the screenshot mode.
    private let now = DayKey(year: 2026, month: 10, day: 7).startOfDay().addingTimeInterval(10 * 3600)

    private func makeMonth() -> (layout: MonthPageLayout, paper: PaperContent) {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
        let paper = PaperContent.month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: [:]))
        return (layout, paper)
    }

    private func makeView(layout: any PageLayout, paper: PaperContent, viewportWidth: CGFloat, probe: Probe) -> InkCanvasView {
        let page = InkPage.empty(pageId: layout.pageId)
        return InkCanvasView(
            layout: layout,
            paper: paper,
            tool: .eraser,
            allowFinger: false,
            page: .constant(page),
            initialScrollY: PageNavigation.initialScrollY(layout, now: now),
            initialScrollX: PageNavigation.initialScrollX(layout, now: now, visibleWidth: ZoomPolicy.visibleWidth(layout.kind, viewportWidth: viewportWidth)),
            onTap: { _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            onViewportChange: { viewport in
                probe.count += 1
                probe.last = viewport
            }
        )
    }

    /// Lets the queued main-actor tasks (the next-turn deliveries) run.
    private func settle() async {
        for _ in 0..<8 {
            await Task.yield()
        }
    }

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
        XCTAssertEqual(first.width, 402)
        XCTAssertEqual(first.zoom, ZoomPolicy.minZoom(.month, viewportWidth: 402), accuracy: 1e-6)
        XCTAssertEqual(first.zoom, 0.5, accuracy: 1e-6, "the month page's readable zoom on an iPhone")
        // Today (Wednesday) is in the first 4 columns, so the paper starts at x = 0.
        XCTAssertEqual(first.offsetX, 0, accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.minimumZoomScale, 0.5, accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.maximumZoomScale, ZoomPolicy.maxZoom(.month, viewportWidth: 402), accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.zoomScale, 0.5, accuracy: 1e-6)
        XCTAssertEqual(container.canvasView.contentSize.width, 700, accuracy: 0.01, "1400 lu × 0.5")
        XCTAssertEqual(container.paperView.zoomScale, 0.5, accuracy: 1e-6)
        XCTAssertEqual(container.paperView.frame.size, container.paperView.contentWindow.size)
        XCTAssertFalse(container.paperView.contentWindow.isEmpty, "the paper holds a window around the visible part")

        // The same layout again: the same viewport is not sent twice.
        container.layoutSubviews()
        await settle()
        XCTAssertEqual(probe.count, 1)

        // Rotated to 874 pt: fit-to-width is readable now (0.624 ≥ 0.5), reported once, on the next turn.
        container.frame = CGRect(x: 0, y: 0, width: 874, height: 402)
        container.layoutSubviews()
        XCTAssertEqual(probe.count, 1, "the rotation is not delivered synchronously either")
        await settle()
        XCTAssertEqual(probe.count, 2)
        guard let rotated = probe.last else { return XCTFail("no viewport after the rotation") }
        XCTAssertEqual(rotated.width, 874)
        XCTAssertEqual(rotated.zoom, ZoomPolicy.minZoom(.month, viewportWidth: 874), accuracy: 1e-6)
        XCTAssertEqual(rotated.zoom, 874 / 1400, accuracy: 1e-6)
        XCTAssertEqual(rotated.offsetX, 0, accuracy: 1e-6, "fit to width: nothing to scroll sideways")
    }

    func testInitialScrollXPutsTodaysColumnOnScreen() async {
        // Today = Sunday 2026-10-11: on a 402 pt iPhone the month shows 4 columns (804 lu), so the
        // paper starts at 1400 − 804 = 596 lu → 298 pt at zoom 0.5.
        let sunday = DayKey(year: 2026, month: 10, day: 11).startOfDay().addingTimeInterval(10 * 3600)
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: sunday))
        let paper = PaperContent.month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: [], chips: [], holidayNames: [:]))
        let probe = Probe()
        let page = InkPage.empty(pageId: layout.pageId)
        let visibleWidth = ZoomPolicy.visibleWidth(.month, viewportWidth: 402)
        let initialX = PageNavigation.initialScrollX(layout, now: sunday, visibleWidth: visibleWidth)
        XCTAssertEqual(initialX, 596, accuracy: 0.01)
        let view = InkCanvasView(
            layout: layout, paper: paper, tool: .eraser, allowFinger: false, page: .constant(page),
            initialScrollY: 0, initialScrollX: initialX,
            onTap: { _ in }, onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0,
            onViewportChange: { probe.count += 1; probe.last = $0 }
        )
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: paper))
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: 402, height: 700)
        container.layoutSubviews()
        await settle()
        XCTAssertEqual(probe.count, 1)
        XCTAssertEqual(probe.last?.offsetX ?? -1, 298, accuracy: 0.01)
        XCTAssertEqual(container.canvasView.contentOffset.x, 298, accuracy: 0.01)
        XCTAssertEqual(container.canvasView.contentOffset.y, 0, accuracy: 0.01)
    }

    func testDefaultArgumentsOfTheNewParameters() {
        let (layout, paper) = makeMonth()
        let page = InkPage.empty(pageId: layout.pageId)
        // The M3b call shape (no initialScrollX, no onViewportChange) still builds.
        let view = InkCanvasView(
            layout: layout, paper: paper, tool: .eraser, allowFinger: false, page: .constant(page),
            initialScrollY: 0, onTap: { _ in }, onInkBoundsChanged: {}, undoTrigger: 0, redoTrigger: 0
        )
        XCTAssertEqual(view.initialScrollX, 0)
        view.onViewportChange(.zero)
    }
}
