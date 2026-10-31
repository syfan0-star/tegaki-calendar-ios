import UIKit
import XCTest

/// 1.0.1 (docs/R1_0_1.md §5.1): on an iPhone, a real finger tap on the year page opens the day page.
/// This is the check the unit tests cannot make: the touches go through UIKit's real gesture
/// recognisers and PencilKit (with 「指でも書く」 on, the iPhone's default, PencilKit's drawing
/// recognisers take the finger too). CI runs it on an iPhone 17 simulator (build.yml, "UI tests on an
/// iPhone"); simulator taps are finger (direct) touches.
///
/// The app runs in its screenshot mode (no onboarding, no EventKit, the demo month 2026-10, nothing
/// saved) on the year page at its overview (the whole year in view). The cell is 3/16 — column 3,
/// row 16, a Monday with no events and no ink — tapped in its middle, which is outside 1.0's
/// 40 × 28 lu target (1.0 stays on the year page there) and inside the whole-cell target of 1.0.1.
///
/// Where the cell is on screen comes from the app's own elements: the sticky header's 「3月」 button
/// is column 3 (its width is 112 lu × the zoom, its bottom is the canvas's top), the toolbar's 「ペン」
/// button is 16 pt below the canvas's bottom (the toolbar's 8 pt padding and the 8 pt inset gap),
/// and the paper (1400 × 1896 lu with the demo month: row 16 grows by 36 lu for 10/16's four all-day
/// events) is centred in the canvas. Row 16 is 900…996 lu, so its middle (948 lu) is also the
/// paper's: ±48 lu of room, 14 pt in portrait and 5 pt in landscape.
@MainActor
final class YearTapUITests: XCTestCase {
    /// The paper's height (lu) with the demo month (the CI's iPhone log: "overview=1400x1896").
    private let paperHeight: CGFloat = 1896
    /// The middle of row 16 (900…996 lu).
    private let rowMiddle: CGFloat = 948
    /// Column 3's width (lu, `PaperSpec.yearColumnWidth`).
    private let columnWidth: CGFloat = 112

    // MARK: Tests

    func testSingleFingerTapOnAYearCellOpensTheDayInPortrait() throws {
        try runJump(fingerDraws: true, landscape: false, double: false)
    }

    func testDoubleFingerTapOnAYearCellOpensTheDayInPortrait() throws {
        try runJump(fingerDraws: true, landscape: false, double: true)
    }

    func testSingleFingerTapOpensTheDayWithFingerDrawingOff() throws {
        try runJump(fingerDraws: false, landscape: false, double: false)
    }

    func testSingleFingerTapOnAYearCellOpensTheDayInLandscape() throws {
        try runJump(fingerDraws: true, landscape: true, double: false)
    }

    func testDoubleFingerTapOnAYearCellOpensTheDayInLandscape() throws {
        try runJump(fingerDraws: true, landscape: true, double: true)
    }

    // MARK: The steps

    /// Launches the year page, taps (or double-taps) the middle of 3/16 once and expects the day page
    /// of 2026-03-16 (the header's 「前の日」 button and the title 「3月16日(月)」).
    private func runJump(fingerDraws: Bool, landscape: Bool, double: Bool) throws {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        try XCTSkipIf(!isPhone, "1.0.1's UI test is for an iPhone")
        continueAfterFailure = false
        let name = "finger=\(fingerDraws ? "on" : "off") \(landscape ? "landscape" : "portrait") \(double ? "double" : "single")"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "year",
            // UserDefaults' argument domain: 「指でも書く」 as asked, and already chosen (so the first
            // launch does not pick the device default over it).
            "-allowFingerDrawing", fingerDraws ? "YES" : "NO",
            "-allowFingerDrawingChosen", "YES",
        ]
        app.launch()

        let march = app.buttons["2026年3月（月表示へ）"]
        XCTAssertTrue(march.waitForExistence(timeout: 20), "\(name): the year page's 「3月」 heading")
        XCTAssertTrue(app.buttons["前の年"].exists, "\(name): the year page is shown")
        let pen = app.buttons["ペン"]
        XCTAssertTrue(pen.waitForExistence(timeout: 5), "\(name): the toolbar's 「ペン」")
        let finger = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "指でも書く")).firstMatch
        log("\(name): 指でも書く element exists=\(finger.exists) value=\(String(describing: finger.exists ? finger.value : nil)) selected=\(finger.exists && finger.isSelected)")

        // The canvas reports its zoom after its first layout and the heading follows it.
        let heading = settledFrame(of: march)
        let penFrame = pen.frame
        let zoom = heading.width / columnWidth
        let canvasTop = heading.maxY
        let canvasBottom = penFrame.minY - 16
        let inset = max(0, (canvasBottom - canvasTop - paperHeight * zoom) / 2)
        let dy = inset + rowMiddle * zoom
        log("\(name): window=\(app.windows.firstMatch.frame) march=\(heading) pen=\(penFrame) zoom=\(zoom) canvas=\(canvasTop)…\(canvasBottom) inset=\(inset) tap=(\(heading.midX), \(canvasTop + dy))")
        XCTAssertTrue(zoom > 0.05 && zoom < 0.6, "\(name): the overview's zoom (\(zoom), heading \(heading))")
        XCTAssertGreaterThan(canvasBottom - canvasTop, paperHeight * zoom - 4, "\(name): the canvas holds the paper (\(canvasTop)…\(canvasBottom), zoom \(zoom))")
        if landscape {
            XCTAssertLessThan(heading.width, heading.height, "\(name): a column narrower than the 44 pt heading row (\(heading))")
        }
        keepScreenshot(app, "\(name) — before")

        // The middle of 3/16, relative to the heading's bottom centre.
        let point = march.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0)).withOffset(CGVector(dx: 0, dy: dy))
        if double {
            point.doubleTap()
        } else {
            point.tap()
        }

        let opened = app.buttons["前の日"].waitForExistence(timeout: 6)
        keepScreenshot(app, "\(name) — after")
        if !opened {
            log("\(name): the day page did not open. Elements:\n\(app.debugDescription)")
        }
        XCTAssertTrue(opened, "\(name): the day page opened")
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "3月16日")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 2), "\(name): the day page of 3/16")
        log("\(name): OK (\(title.label))")
    }

    /// The element's frame once two reads 0.5 s apart agree (at most `timeout` seconds).
    private func settledFrame(of element: XCUIElement, timeout: TimeInterval = 8) -> CGRect {
        var last = element.frame
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
            let now = element.frame
            if now == last, now.width > 0 { return now }
            last = now
        }
        return last
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func log(_ line: String) {
        print("year-tap UI: \(line)")
        NSLog("year-tap UI: %@", line)
    }
}
