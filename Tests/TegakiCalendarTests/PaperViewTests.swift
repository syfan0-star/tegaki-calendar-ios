import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the paper's windowed backing store (M4B_CONTRACT §1.6, §7.2, M4B-25; M4C_CONTRACT
/// §2.2 F3, §7.2): the window is at most 2 × 2 screens around the visible rect, clipped to the content;
/// `show` moves the frame without redrawing while the visible rect stays inside the window at the same
/// zoom, and makes a new window (and redraws) when it leaves it or the zoom changes; while a pinch is
/// live the window is stretched with a transform instead and redrawn once at the end. 1.1
/// (M7A_CONTRACT §3.3): the day's paper stops its timeline at 24:00 and draws the free memo area
/// 「自由メモ」 below it.
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

        // A paper narrower than the viewport (M4c D1: the iPhone's day page at 0.2417, 242 pt in 402)
        // rests at a negative offset — the centring margin: the window is the whole paper, the frame
        // starts at the margin, and a vertical bounce only moves it.
        let narrow = PaperView(content: makeContent())
        let dayContent = CGSize(width: 241.67, height: 580)
        narrow.show(visible: CGRect(x: -80, y: 0, width: 402, height: 580), zoom: 0.2417, contentSize: dayContent)
        assertRect(narrow.contentWindow, 0, 0, 241.67, 580, "the whole paper")
        XCTAssertEqual(narrow.frame.origin.x, 80, accuracy: 0.001)
        XCTAssertEqual(narrow.frame.origin.y, 0, accuracy: 0.001)
        let narrowRequests = narrow.displayRequestCount
        narrow.show(visible: CGRect(x: -80, y: -40, width: 402, height: 580), zoom: 0.2417, contentSize: dayContent)
        assertRect(narrow.contentWindow, 0, 0, 241.67, 580, "window kept while bouncing in the margin")
        XCTAssertEqual(narrow.frame.origin.x, 80, accuracy: 0.001)
        XCTAssertEqual(narrow.frame.origin.y, 40, accuracy: 0.001)
        XCTAssertEqual(narrow.displayRequestCount, narrowRequests)
    }

    // MARK: show(…, live:) — M4c F3

    func testLiveShowStretchesWithoutRedraw() {
        let view = PaperView(content: makeContent())
        let content = CGSize(width: 700, height: 875)
        view.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: content)
        assertRect(view.contentWindow, 0, 0, 603, 875, "the window drawn at 0.5")
        let requests = view.displayRequestCount

        // A pinch doubled the zoom: the window is not remade, the view keeps its zoom and its bounds
        // and is stretched ×2; its centre is where the window's centre lands at the new zoom.
        let visible = CGRect(x: 100, y: 150, width: 402, height: 600)
        view.show(visible: visible, zoom: 1.0, contentSize: CGSize(width: 1400, height: 1750), live: true)
        XCTAssertEqual(view.displayRequestCount, requests, "no redraw while live")
        XCTAssertEqual(view.zoomScale, 0.5, "the zoom is left alone")
        assertRect(view.contentWindow, 0, 0, 603, 875, "window kept")
        XCTAssertEqual(view.transform.a, 2, accuracy: 1e-6)
        XCTAssertEqual(view.transform.d, 2, accuracy: 1e-6)
        XCTAssertEqual(view.bounds.size.width, 603, accuracy: 0.001)
        XCTAssertEqual(view.bounds.size.height, 875, accuracy: 0.001)
        XCTAssertEqual(view.center.x, 603 / 2 * 2 - 100, accuracy: 0.001)
        XCTAssertEqual(view.center.y, 875 / 2 * 2 - 150, accuracy: 0.001)

        // The same frame again: nothing changes.
        view.show(visible: visible, zoom: 1.0, contentSize: CGSize(width: 1400, height: 1750), live: true)
        XCTAssertEqual(view.displayRequestCount, requests)

        // The end of the pinch: the transform goes back, the zoom is taken, a new window is drawn.
        view.show(visible: visible, zoom: 1.0, contentSize: CGSize(width: 1400, height: 1750), live: false)
        XCTAssertEqual(view.transform, .identity)
        XCTAssertEqual(view.zoomScale, 1.0)
        assertRect(view.contentWindow, 0, 0, 703, 1050, "window for the new zoom")
        XCTAssertEqual(view.frame.size, view.contentWindow.size)
        XCTAssertEqual(view.frame.origin.x, -100, accuracy: 0.001)
        XCTAssertEqual(view.frame.origin.y, -150, accuracy: 0.001)
        XCTAssertGreaterThan(view.displayRequestCount, requests, "drawn once at the end")
    }

    func testLiveShowWithoutAWindowFallsBackToADraw() {
        // Right after `attach` the window is empty (s would not be finite): the live call takes the
        // ordinary path and makes the first window.
        let view = PaperView(content: makeContent())
        XCTAssertEqual(view.contentWindow, .zero)
        let requests = view.displayRequestCount
        view.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: CGSize(width: 700, height: 875), live: true)
        assertRect(view.contentWindow, 0, 0, 603, 875, "a window is made")
        XCTAssertGreaterThan(view.displayRequestCount, requests, "and drawn")
        XCTAssertEqual(view.transform, .identity)
        XCTAssertEqual(view.zoomScale, 0.5)
        XCTAssertEqual(view.frame.size, view.contentWindow.size)
    }

    func testContentChangeRedraws() {
        let view = PaperView(content: makeContent())
        view.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: CGSize(width: 700, height: 875))
        let requests = view.displayRequestCount
        let otherLayout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now))
        view.content = .month(MonthPaperContent(layout: otherLayout, labels: otherLayout.dateLabels, bars: [], chips: [], holidayNames: [:]))
        XCTAssertGreaterThan(view.displayRequestCount, requests)
    }

    // MARK: 1.1 — the day's free memo area (M7A_CONTRACT §3.3)

    /// RGBA bytes (row 0 at the top) of `rect` of the day's paper drawn by `DayPaper` at zoom 1 and
    /// scale 1 (one pixel per lu), on the paper colour as `PaperView.draw` lays it.
    private func renderDayPaper(_ content: DayPaperContent, rect: CGRect) -> (bytes: [UInt8], width: Int) {
        let width = Int(rect.width)
        let height = Int(rect.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let view = PaperView(content: .day(content))
        view.contentScaleFactor = 1
        let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: -rect.minX, y: -rect.minY)
            ctx.setFillColor(PaperPalette.paper.cgColor)
            ctx.fill(rect)
            DayPaper.draw(content, in: ctx, dirty: rect, zoom: 1, view: view)
        }
        guard let cg = image.cgImage else { return ([], width) }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            // No flip: the image's top row lands in the first row of the buffer (PaperTextTests).
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (bytes, width)
    }

    /// Weekend 2026-10-11 (a Sunday, not today): the timeline's tint and its vertical lines run to
    /// 24:00 and stop there; a strong line at y 2,400; below it the paper colour with the ruled lines
    /// and the label 「自由メモ」 at (20, 2,406). (The points are 20 lu off the contract's (100, 2,300) and
    /// (100, 2,500), which lie on the 23:00 hour line and on a ruled line.)
    func testDayPaperStopsTheTimelineAt24() {
        let sunday = DayKey(year: 2026, month: 10, day: 11)
        let layout = DayLayoutEngine.layout(DayLayoutInput(day: sunday, events: [], inkBottoms: [:], now: now))
        XCTAssertFalse(layout.isToday)
        XCTAssertNotEqual(layout.dateLabels.first?.tone, .normal, "a weekend day: the timeline is tinted")
        XCTAssertEqual(layout.extra, CGRect(x: 0, y: 2400, width: 1000, height: 700))
        XCTAssertEqual(DayPaper.freeMemoLabel, "自由メモ")
        let rect = CGRect(x: 0, y: 2200, width: 1000, height: 500)
        let (bytes, width) = renderDayPaper(DayPaperContent(layout: layout), rect: rect)
        XCTAssertEqual(bytes.count, 1000 * 500 * 4)
        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = ((y - Int(rect.minY)) * width + x) * 4
            guard i >= 0, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }
        func near(_ p: (r: Int, g: Int, b: Int), _ hex: (Int, Int, Int), _ tolerance: Int = 3) -> Bool {
            abs(p.r - hex.0) <= tolerance && abs(p.g - hex.1) <= tolerance && abs(p.b - hex.2) <= tolerance
        }
        let paperColor = (0xff, 0xfd, 0xf8) // PaperPalette.paper
        let strong = (0xd7, 0xda, 0xde) // PaperPalette.lineStrong

        // Above 24:00: the timeline (x 72…660) is tinted, the memo column (x 660…1000) is not.
        let timeline = pixel(100, 2320)
        let memoColumn = pixel(800, 2320)
        XCTAssertTrue(near(memoColumn, paperColor), "the right column is paper: \(memoColumn)")
        XCTAssertLessThan(timeline.b, memoColumn.b - 2, "the timeline is tinted above 24:00: \(timeline) vs \(memoColumn)")
        // Below 24:00: paper colour across the width, where the timeline was.
        XCTAssertTrue(near(pixel(100, 2520), paperColor), "no tint below 24:00: \(pixel(100, 2520))")
        XCTAssertTrue(near(pixel(800, 2520), paperColor))
        // The vertical lines (x 72 the gutter's, x 660 the timeline's) stop at 24:00.
        XCTAssertTrue(near(pixel(72, 2320), strong, 6), "the gutter line above 24:00: \(pixel(72, 2320))")
        XCTAssertTrue(near(pixel(660, 2320), strong, 6), "the timeline's right line above 24:00: \(pixel(660, 2320))")
        XCTAssertTrue(near(pixel(72, 2520), paperColor), "not below: \(pixel(72, 2520))")
        XCTAssertTrue(near(pixel(660, 2520), paperColor), "not below: \(pixel(660, 2520))")
        // The strong line at 24:00, across the whole width.
        XCTAssertTrue(near(pixel(30, 2400), strong, 6), "24:00 at x 30: \(pixel(30, 2400))")
        XCTAssertTrue(near(pixel(500, 2400), strong, 6), "24:00 at x 500: \(pixel(500, 2400))")
        XCTAssertTrue(near(pixel(990, 2400), strong, 6), "24:00 at x 990: \(pixel(990, 2400))")
        // A ruled line every 50 lu below it, inset 20 lu (2,450 and 2,500), not at the very edge.
        let rule = (0xeb, 0xe7, 0xde) // PaperPalette.rule
        XCTAssertTrue(near(pixel(500, 2450), rule, 4), "a ruled line at 2,450: \(pixel(500, 2450))")
        XCTAssertTrue(near(pixel(500, 2500), rule, 4), "a ruled line at 2,500: \(pixel(500, 2500))")
        XCTAssertTrue(near(pixel(10, 2450), paperColor), "inset 20 lu: \(pixel(10, 2450))")
        // 「自由メモ」 at (20, 2,406): something darker than the ruled lines in its box.
        var labelPixels = 0
        for y in 2406..<2426 {
            for x in 20..<110 {
                let p = pixel(x, y)
                if p.r < 220 { labelPixels += 1 }
            }
        }
        XCTAssertGreaterThan(labelPixels, 20, "the label 「自由メモ」 is drawn")
    }
}
