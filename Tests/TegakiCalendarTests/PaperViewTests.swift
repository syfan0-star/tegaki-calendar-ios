import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the paper's windowed backing store (M4B_CONTRACT §1.6, §7.2, M4B-25): the
/// window is at most 2 × 2 screens around the visible rect, clipped to the content; `show` moves
/// the frame without redrawing while the visible rect stays inside the window at the same zoom, and
/// makes a new window (and redraws) when it leaves it or the zoom changes.
@MainActor
final class PaperViewTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeContent() -> PaperContent {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
        return .month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: [:]))
    }

    private func assertRect(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(rect.minX, x, accuracy: 0.001, "minX " + message, file: file, line: line)
        XCTAssertEqual(rect.minY, y, accuracy: 0.001, "minY " + message, file: file, line: line)
        XCTAssertEqual(rect.width, w, accuracy: 0.001, "width " + message, file: file, line: line)
        XCTAssertEqual(rect.height, h, accuracy: 0.001, "height " + message, file: file, line: line)
    }

    // MARK: window(for:content:)

    func testWindowIsTwoByTwoScreensClippedToTheContent() {
        // The iPhone's year page at its minimum zoom, scrolled to October: (1425, 0, 402, 600) in a
        // 1875 × 2491 content → grown to (1224, −300, 804, 1200) → clipped to (1224, 0, 651, 900).
        // (M4B_CONTRACT §1.6 wrote 1200 for the height, but the grown rect reaches y = 900 and the
        // window is the plain intersection, as in the other examples below; the window never slides.)
        assertRect(PaperView.window(for: CGRect(x: 1425, y: 0, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), 1224, 0, 651, 900, "iPhone year")
        // The top-left corner: half a screen to the right and below only.
        assertRect(PaperView.window(for: CGRect(x: 0, y: 0, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), 0, 0, 603, 900, "top left")
        // An iPad at fit width: the content is exactly as wide as the viewport.
        assertRect(PaperView.window(for: CGRect(x: 0, y: 0, width: 1024, height: 700), content: CGSize(width: 1024, height: 1400)), 0, 0, 1024, 1050, "iPad fit")
        // In the middle of a tall content: the full 2 × 2 screens.
        assertRect(PaperView.window(for: CGRect(x: 300, y: 1000, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), 99, 700, 804, 1200, "middle")
        // The bottom-right corner.
        assertRect(PaperView.window(for: CGRect(x: 1473, y: 1891, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), 1272, 1591, 603, 900, "bottom right")
        // Overscroll (a negative offset while bouncing) still gives a window inside the content.
        assertRect(PaperView.window(for: CGRect(x: -50, y: -80, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), 0, 0, 553, 820, "bounce")
    }

    func testWindowIsZeroForBadInput() {
        XCTAssertEqual(PaperView.window(for: CGRect(x: CGFloat.nan, y: 0, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), .zero)
        XCTAssertEqual(PaperView.window(for: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 600), content: CGSize(width: 1875, height: 2491)), .zero)
        XCTAssertEqual(PaperView.window(for: .zero, content: CGSize(width: 1875, height: 2491)), .zero)
        XCTAssertEqual(PaperView.window(for: CGRect(x: 10, y: 10, width: 0, height: 600), content: CGSize(width: 1875, height: 2491)), .zero)
        XCTAssertEqual(PaperView.window(for: CGRect(x: 0, y: 0, width: 402, height: 600), content: .zero), .zero, "no content")
        XCTAssertEqual(PaperView.window(for: CGRect(x: 5000, y: 0, width: 402, height: 600), content: CGSize(width: 1875, height: 2491)), .zero, "entirely outside the content")
    }

    // MARK: show(visible:zoom:contentSize:)

    func testShowMovesTheFrameInsideTheWindowAndRebuildsOutsideIt() {
        let view = PaperView(content: makeContent())
        XCTAssertEqual(view.frame, .zero, "no frame before the first show")
        XCTAssertEqual(view.contentWindow, .zero)

        // The month page at zoom 0.5 (1400 × 1750 lu → 700 × 875 pt) in a 402 × 600 viewport.
        let content = CGSize(width: 700, height: 875)
        view.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: content)
        XCTAssertEqual(view.zoomScale, 0.5)
        assertRect(view.contentWindow, 0, 0, 603, 875, "first window")
        XCTAssertEqual(view.frame.size, view.contentWindow.size)
        XCTAssertEqual(view.frame.origin, .zero)
        let requests = view.displayRequestCount
        XCTAssertGreaterThan(requests, 0, "the first show draws")

        // Scrolled a little, still inside the window: the frame moves, the window and the drawing stay.
        view.show(visible: CGRect(x: 100, y: 150, width: 402, height: 600), zoom: 0.5, contentSize: content)
        assertRect(view.contentWindow, 0, 0, 603, 875, "window unchanged")
        XCTAssertEqual(view.frame.origin.x, -100, accuracy: 0.001)
        XCTAssertEqual(view.frame.origin.y, -150, accuracy: 0.001)
        XCTAssertEqual(view.frame.size, view.contentWindow.size)
        XCTAssertEqual(view.displayRequestCount, requests, "no redraw while the visible rect stays inside the window")

        // The same place again: nothing at all.
        view.show(visible: CGRect(x: 100, y: 150, width: 402, height: 600), zoom: 0.5, contentSize: content)
        XCTAssertEqual(view.displayRequestCount, requests)

        // Past the window's right edge: a new window around the visible rect, drawn once.
        view.show(visible: CGRect(x: 250, y: 150, width: 402, height: 600), zoom: 0.5, contentSize: content)
        assertRect(view.contentWindow, 49, 0, 651, 875, "new window")
        XCTAssertEqual(view.frame.size, view.contentWindow.size)
        XCTAssertEqual(view.frame.origin.x, 49 - 250, accuracy: 0.001)
        XCTAssertEqual(view.frame.origin.y, 0 - 150, accuracy: 0.001)
        XCTAssertGreaterThan(view.displayRequestCount, requests, "a new window is drawn")
        let afterMove = view.displayRequestCount

        // Back inside the new window: the frame only.
        view.show(visible: CGRect(x: 200, y: 100, width: 402, height: 600), zoom: 0.5, contentSize: content)
        assertRect(view.contentWindow, 49, 0, 651, 875, "window kept")
        XCTAssertEqual(view.frame.origin.x, 49 - 200, accuracy: 0.001)
        XCTAssertEqual(view.displayRequestCount, afterMove)

        // A different zoom: a new window even at the same place.
        view.show(visible: CGRect(x: 200, y: 100, width: 402, height: 600), zoom: 0.6, contentSize: CGSize(width: 840, height: 1050))
        XCTAssertEqual(view.zoomScale, 0.6)
        assertRect(view.contentWindow, 0, 0, 803, 1000, "window for the new zoom")
        XCTAssertEqual(view.frame.size, view.contentWindow.size)
        XCTAssertGreaterThan(view.displayRequestCount, afterMove, "a zoom change draws")
    }

    func testShowKeepsTheWindowWhileBouncingAtTheEdges() {
        let view = PaperView(content: makeContent())
        let content = CGSize(width: 700, height: 875)
        view.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: content)
        let requests = view.displayRequestCount
        // Overscroll at the top-left: the visible rect leaves the content, but what is inside the
        // content is still inside the window, so the frame just moves down and right.
        view.show(visible: CGRect(x: -30, y: -40, width: 402, height: 600), zoom: 0.5, contentSize: content)
        assertRect(view.contentWindow, 0, 0, 603, 875, "window kept while bouncing")
        XCTAssertEqual(view.frame.origin.x, 30, accuracy: 0.001)
        XCTAssertEqual(view.frame.origin.y, 40, accuracy: 0.001)
        XCTAssertEqual(view.displayRequestCount, requests)
    }

    func testContentChangeRedraws() {
        let view = PaperView(content: makeContent())
        view.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: CGSize(width: 700, height: 875))
        let requests = view.displayRequestCount
        let otherLayout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now))
        view.content = .month(MonthPaperContent(layout: otherLayout, labels: otherLayout.dateLabels, bars: [], chips: [], holidayNames: [:]))
        XCTAssertGreaterThan(view.displayRequestCount, requests)
    }
}
