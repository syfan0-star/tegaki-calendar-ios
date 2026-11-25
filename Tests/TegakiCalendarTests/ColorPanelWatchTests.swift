import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.6, §6.1, 0f-11): the window's watch of a touch outside the open colour panel
/// (`ColorPanelWatch`), as PaletteGripTests checks `PalmWatch`: a new instance of the frozen `InkTouchObserver` on the window
/// while the panel is open and off it once closed; a touch coming down outside the panel and the lit dot (the Pencil, a
/// finger, a pointer) closes it once; one inside either, or before the panel was laid out, does not; lifts never do. UIKit's
/// touches are stood in for by `touched(_:at:)` (the observer's own path hands it every touch's place in the window).
/// Fails with the watch closing on any touch without `closesOnTouch` (mutation MC6) or with `closesOnTouch` true inside the
/// panel (MC6b).
@MainActor
final class ColorPanelWatchTests: XCTestCase {
    private let panel = CGRect(x: 100, y: 500, width: 288, height: 204)
    private let dot = CGRect(x: 273, y: 718, width: 38, height: 44)

    private func makeWindow() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    }

    private func watchers(of window: UIWindow) -> [InkTouchObserver] {
        (window.gestureRecognizers ?? []).compactMap { $0 as? InkTouchObserver }
    }

    /// The watch as the screen opens the panel: on the window, its frames given by the layer the same turn.
    private func opened(_ window: UIWindow, closes: @escaping () -> Void) -> ColorPanelWatch {
        let watch = ColorPanelWatch()
        watch.onOutsideTouch = closes
        watch.panelFrame = panel
        watch.litSwatchFrame = dot
        watch.attach(to: window)
        return watch
    }

    func testItIsOnTheWindowOnlyWhileOpen() throws {
        let window = makeWindow()
        let watch = ColorPanelWatch()
        XCTAssertFalse(watch.isAttached)
        watch.attach(to: window)
        XCTAssertTrue(watch.isAttached)
        XCTAssertTrue(watch.window === window)
        let observer = try XCTUnwrap(watchers(of: window).first, "the frozen InkTouchObserver's type, on the window")
        XCTAssertEqual(watchers(of: window).count, 1)
        XCTAssertFalse(observer.cancelsTouchesInView, "it holds no touch up")
        XCTAssertFalse(observer.delaysTouchesBegan)
        XCTAssertTrue(observer.delegate?.gestureRecognizer?(observer, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()) ?? false,
                      "alongside every recogniser")
        watch.attach(to: window)
        XCTAssertEqual(watchers(of: window).count, 1, "the same window: once")
        let other = UIWindow(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
        watch.attach(to: other)
        XCTAssertTrue(watchers(of: window).isEmpty, "off the old window")
        XCTAssertEqual(watchers(of: other).count, 1)
        watch.detach()
        XCTAssertFalse(watch.isAttached)
        XCTAssertTrue(watchers(of: other).isEmpty, "closed: off the window")
        XCTAssertNil(watch.window)
        XCTAssertEqual(watch.panelFrame, .zero, "its frames forgotten")
        XCTAssertNil(watch.litSwatchFrame)
    }

    func testATouchOutsideClosesOnce() {
        for type in [UITouch.TouchType.pencil, .direct, .indirectPointer] {
            var closes = 0
            let window = makeWindow()
            let watch = opened(window) { closes += 1 }
            watch.touched(.down(type), at: CGPoint(x: 50, y: 300))
            XCTAssertEqual(closes, 1, "\(type.rawValue): a touch on the paper closes it")
            watch.touched(.down(type), at: CGPoint(x: 60, y: 320))
            XCTAssertEqual(closes, 1, "\(type.rawValue): once")
            // Opened again: armed again.
            watch.detach()
            watch.panelFrame = panel
            watch.litSwatchFrame = dot
            watch.attach(to: window)
            watch.touched(.down(type), at: CGPoint(x: 360, y: 740))
            XCTAssertEqual(closes, 2, "\(type.rawValue): the next dot, after it opened again")
            watch.detach()
        }
    }

    func testATouchInsideTheOpenPanelOrOnItsDotDoesNotClose() {
        var closes = 0
        let window = makeWindow()
        let watch = opened(window) { closes += 1 }
        // Right after it opened, its frame is the placement's (never .zero): a quick press on a colour stays.
        watch.touched(.down(.direct), at: CGPoint(x: 120, y: 520))
        watch.touched(.down(.pencil), at: CGPoint(x: 380, y: 700))
        watch.touched(.down(.indirectPointer), at: CGPoint(x: 290, y: 740))
        watch.touched(.up(.direct), at: CGPoint(x: 10, y: 10))
        watch.touched(.up(.pencil), at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(closes, 0, "inside the panel, on the lit dot, and lifts")
        watch.touched(.down(.direct), at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(closes, 1)
        watch.detach()
    }

    func testNothingClosesBeforeThePanelIsLaidOut() {
        var closes = 0
        let watch = ColorPanelWatch()
        watch.onOutsideTouch = { closes += 1 }
        watch.attach(to: makeWindow())
        watch.touched(.down(.direct), at: CGPoint(x: 200, y: 600))
        XCTAssertEqual(closes, 0, "no frame yet: a touch that may be on the panel closes nothing")
        watch.panelFrame = panel
        watch.touched(.down(.direct), at: CGPoint(x: 200, y: 600))
        XCTAssertEqual(closes, 0, "inside")
        watch.touched(.down(.direct), at: CGPoint(x: 290, y: 740))
        XCTAssertEqual(closes, 1, "without a dot frame the dot is outside")
        watch.detach()
    }

    /// The frames set before the attach stay (the layer may lay the panel out first, the same turn).
    func testTheFramesOutliveTheAttach() {
        var closes = 0
        let watch = ColorPanelWatch()
        watch.onOutsideTouch = { closes += 1 }
        watch.panelFrame = panel
        watch.litSwatchFrame = dot
        watch.attach(to: makeWindow())
        XCTAssertEqual(watch.panelFrame, panel)
        XCTAssertEqual(watch.litSwatchFrame, dot)
        watch.touched(.down(.direct), at: CGPoint(x: 200, y: 600))
        XCTAssertEqual(closes, 0)
        watch.detach()
    }
}
