import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4 (docs/M7D_CONTRACT.md §4.5, §4.1 #11, §6's P row): the paper reads its scale from the display-scale trait too,
/// not only when it moves to a window (`didMoveToWindow`, kept as it was) — on iPhone Duo folding can take a window to
/// the other screen without moving it in the hierarchy (§4.9 5). The trait is changed through the view's
/// `traitOverrides` (iOS 17) and applied at once with `updateTraitsIfNeeded()`. A change that brings the scale the view
/// already has asks for no redraw, so the count `PaperViewTests` watches (`displayRequestCount`, a file of TESTS_1_3,
/// §5.5) stays as it was. 1.3's tree reads the scale in `didMoveToWindow` only: there the trait moves and the scale
/// stays the screen's, and the first test fails.
@MainActor
final class PaperViewScaleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// October 2026's month page (as `PaperViewTests` makes it).
    private func makePaper() -> PaperView {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
        return PaperView(content: .month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: [:])))
    }

    /// A window of the test host's scene (the unit tests run inside the app), 402 × 600 pt, shown above the app's own,
    /// with `paper` in its root view and given its first window of the month page at zoom 0.5 (`PaperView.show`). The
    /// caller hides it again (`hide`).
    private func host(_ paper: PaperView) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "the unit tests run inside the app: its window scene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 600)
        let root = UIViewController()
        root.view.backgroundColor = .white
        window.rootViewController = root
        window.isHidden = false
        root.view.frame = window.bounds
        root.view.addSubview(paper)
        paper.show(visible: CGRect(x: 0, y: 0, width: 402, height: 600), zoom: 0.5, contentSize: CGSize(width: 700, height: 875))
        paper.updateTraitsIfNeeded()
        root.view.layoutIfNeeded()
        return window
    }

    private func hide(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// The display scale of `paper`'s own traits set to `scale` and applied now (the registered handlers run).
    private func setDisplayScale(_ scale: CGFloat, of paper: PaperView) {
        paper.traitOverrides.displayScale = scale
        paper.updateTraitsIfNeeded()
    }

    /// The trait goes 2 → 3 (and back) in the same window: `contentScaleFactor` and the layer's `contentsScale` follow
    /// it, and a new scale asks for a redraw. Before that, the window's screen gave the scale (`didMoveToWindow`).
    func testScaleFollowsTheDisplayScaleTrait() throws {
        let paper = makePaper()
        let window = try host(paper)
        defer { hide(window) }
        XCTAssertEqual(paper.contentScaleFactor, window.screen.scale, "didMoveToWindow still reads the screen's scale")
        XCTAssertEqual(paper.layer.contentsScale, window.screen.scale)

        for scale: CGFloat in [2, 3, 2] {
            let before = paper.contentScaleFactor
            let requests = paper.displayRequestCount
            setDisplayScale(scale, of: paper)
            XCTAssertEqual(paper.traitCollection.displayScale, scale, "the override reached the paper's traits (\(scale))")
            XCTAssertEqual(paper.contentScaleFactor, scale, "contentScaleFactor follows the trait (\(before) → \(scale))")
            XCTAssertEqual(paper.layer.contentsScale, scale, "the layer's contentsScale follows the trait (\(before) → \(scale))")
            if before != scale {
                XCTAssertGreaterThan(paper.displayRequestCount, requests, "a new scale is drawn (\(before) → \(scale))")
            }
        }
    }

    /// A change of the trait to the scale the view already has asks for no redraw. That is what happens when the paper
    /// enters a window: `didMoveToWindow` reads the screen's scale, then the trait arrives with the same value. Here the
    /// scale the trait is about to bring is set first (as `didMoveToWindow` would on a 3× screen), then the trait follows.
    func testSameScaleRequestsNoDisplay() throws {
        let paper = makePaper()
        let window = try host(paper)
        defer { hide(window) }
        setDisplayScale(2, of: paper)
        XCTAssertEqual(paper.contentScaleFactor, 2)

        paper.contentScaleFactor = 3
        paper.layer.contentsScale = 3
        let requests = paper.displayRequestCount
        setDisplayScale(3, of: paper)
        XCTAssertEqual(paper.traitCollection.displayScale, 3, "the override reached the paper's traits")
        XCTAssertEqual(paper.contentScaleFactor, 3)
        XCTAssertEqual(paper.displayRequestCount, requests, "the same scale through the trait asks for no redraw")
    }

    /// A paper in no window (PDFPageRenderer's `dummy`, which sets its own scale for the hairline snapping, and the
    /// renderers' tests) keeps the scale it was given when its trait changes, as `didMoveToWindow` reads only inside a
    /// window.
    func testAPaperInNoWindowKeepsItsScale() {
        let paper = makePaper()
        paper.contentScaleFactor = 2
        let requests = paper.displayRequestCount
        setDisplayScale(3, of: paper)
        XCTAssertEqual(paper.contentScaleFactor, 2)
        XCTAssertEqual(paper.displayRequestCount, requests)
    }
}
