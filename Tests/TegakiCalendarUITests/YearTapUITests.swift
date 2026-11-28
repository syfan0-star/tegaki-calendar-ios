import UIKit
import XCTest

/// 1.0.1 (docs/R1_0_1.md §5.1): on an iPhone, a real finger tap on the year page opens the day page.
/// This is the check the unit tests cannot make: the touches go through UIKit's real gesture
/// recognisers and PencilKit (with 「指でも書く」 on, the iPhone's default, PencilKit's drawing
/// recognisers take the finger too). CI runs it on an iPhone 17 simulator (build.yml, "UI tests on an
/// iPhone"); simulator taps are finger (direct) touches.
///
/// The app runs in its screenshot mode (no onboarding, no EventKit, the demo month 2026-10, nothing
/// saved) on the year page at its opening zoom (1.1.1: the size every year opens at). The cell is 3/16 — column 3,
/// row 16, a Monday with no events and no ink — tapped in its middle, which is outside 1.0's
/// 40 × 28 lu target (1.0 stays on the year page there) and inside the whole-cell target of 1.0.1.
///
/// Where the cell is on screen: x is the middle of the sticky header's 「2026年3月（月表示へ）」 button, column 3
/// (its width is 112 lu × the zoom); y comes from the canvas's probe (`--screenshot-probe`, invisible: the canvas's
/// accessibility value only), whose `zoom` and content offset `oy` put a paper point (lu) at the canvas's frame.minY +
/// y × zoom − oy on screen. The paper (1400 × 1896 lu with the demo month: row 16 grows by 36 lu for 10/16's four
/// all-day events) has row 16 at 900…996 lu, so its middle is 948 lu: ±48 lu of room, 14 pt in portrait, 5 pt in
/// landscape on the one page and 8.6 pt at the joined year's cap.
///
/// 1.4.3 (docs/R1_4_3_CONTRACT.md §11.3, 0g-52): the year joins sideways, so `YearTapSpanRerunUITests`
/// (`--screenshot-span on`, SpanRerunUITests.swift, frozen and not changed) runs these steps on a window of years. On
/// the one page the paper starts at the canvas's top (1.1.1: `oy` 0, the tap where 1.0.1 put it); the joined year in
/// landscape on an iPhone opens at its cap (3 years across, P-B6 イ) two rows above today's row (the demo's 10/7: row
/// 5's top, 240 lu below the paper's top), which the probe's `oy` takes back out. The window lines its rows up on
/// 2026's (its other years have the demo's handwriting and no events: `yearFloors`), so row 16 is 900…996 lu there too,
/// and each year of the window has its own 「…年3月（月表示へ）」 button (D1y's heading row): 2026's is the same
/// words. Row 16 is inside the canvas when 900 × zoom − oy ≥ 0 and 996 × zoom − oy < the canvas's height. After the day
/// page opened, a joined screen (`span.state` says `path=span;`) is read until `span.state` says `;kind=day;` (until
/// then it may still read the window of years), so the child reads the day window it opened; the parent's own run has
/// no `span.state` (1.2.3's arguments alone) and does not wait.
@MainActor
class YearTapUITests: XCTestCase {
    /// 1.3 (docs/M7C_CONTRACT.md §10.3, `SpanRerunUITests`): launch arguments a subclass puts after this class's own
    /// (`["--screenshot-span", "on"]`: the day page the tap opens is then on the joined path, and since 1.4.3 the year page
    /// too); none here, so these tests launch as they did (with the probe since 1.4.3). The class is not `final` for that
    /// subclass only.
    class var extraArguments: [String] { [] }

    /// The top of row 16 (lu): the demo's rows 1–15 are 60 lu each.
    private let rowTop: CGFloat = 900
    /// The middle of row 16 (900…996 lu).
    private let rowMiddle: CGFloat = 948
    /// The bottom of row 16.
    private let rowBottom: CGFloat = 996
    /// Column 3's width (lu, `PaperSpec.yearColumnWidth`).
    private let columnWidth: CGFloat = 112
    /// A tap whose synthesis took longer than this (s) met an overloaded simulator (see `runJump`).
    private let slowTap: TimeInterval = 2.5

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
            // 1.4.3 (0g-52): the canvas's probe (its zoom and offset place the tap; an accessibility value only).
            "--screenshot-probe",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
            // UserDefaults' argument domain: 「指でも書く」 as asked, and already chosen (so the first
            // launch does not pick the device default over it).
            "-allowFingerDrawing", fingerDraws ? "YES" : "NO",
            "-allowFingerDrawingChosen", "YES",
        ] + Self.extraArguments
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
        guard let probe = settledProbe(in: app, name) else {
            log("\(name): no 「ink-canvas」 probe. Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the canvas probe (--screenshot-probe) is missing")
            return
        }
        // 1.4.3 (0g-52): a paper point (lu) is on screen at the canvas's frame.minY + y × zoom − oy (the probe's mapping).
        let zoom = probe.zoom
        let canvas = probe.frame
        let rowTopOnCanvas = rowTop * zoom - probe.oy
        let rowBottomOnCanvas = rowBottom * zoom - probe.oy
        let tapY = canvas.minY + rowMiddle * zoom - probe.oy
        let dy = tapY - heading.maxY
        log("\(name): window=\(app.windows.firstMatch.frame) march=\(heading) pen=\(penFrame) canvas=\(canvas) (1.0.1's "
            + "\(heading.maxY)…\(penFrame.minY - 16)) zoom=\(zoom) (the column's \(heading.width / columnWidth)) oy=\(probe.oy) row 16 at "
            + "\(rowTopOnCanvas)…\(rowBottomOnCanvas) of the canvas's \(canvas.height) tap=(\(heading.midX), \(tapY)) span.state "
            + "\(stateLabel(app)) probe \(probe.raw)")
        XCTAssertTrue(zoom > 0.05 && zoom < 0.6, "\(name): the opening zoom (\(zoom), heading \(heading))")
        XCTAssertGreaterThanOrEqual(rowTopOnCanvas, 0, "\(name): row 16's top is inside the canvas (\(rowTopOnCanvas) pt below its top; zoom \(zoom), oy \(probe.oy))")
        XCTAssertLessThan(rowBottomOnCanvas, canvas.height, "\(name): row 16 is inside the canvas (its bottom \(rowBottomOnCanvas) of \(canvas.height) pt; zoom \(zoom), oy \(probe.oy))")
        if landscape {
            XCTAssertLessThan(heading.width, heading.height, "\(name): a column narrower than the 44 pt heading row (\(heading))")
        }
        keepScreenshot(app, "\(name) — before")
        log("\(name): waited \(waitUntilResponsive(march)) s for the app to answer quickly")

        // The middle of 3/16, relative to the heading's bottom centre (`dy` from the probe). One more try only when the
        // simulator was overloaded: the tap's synthesis itself took over `slowTap` seconds (run
        // 41172398011: 7 s, against at most 1.2 s otherwise), so the touches may not have reached the
        // app as a tap. A fast tap that does not open the day page fails at once.
        let point = march.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0)).withOffset(CGVector(dx: 0, dy: dy))
        var opened = false
        for attempt in 1...2 {
            let started = Date()
            if double {
                point.doubleTap()
            } else {
                point.tap()
            }
            let took = Date().timeIntervalSince(started)
            opened = app.buttons["前の日"].waitForExistence(timeout: 6)
            log("\(name): attempt \(attempt): the \(double ? "double tap" : "tap") took \(String(format: "%.2f", took)) s; the day page \(opened ? "opened" : "did not open")")
            if opened || took <= slowTap || !app.buttons["前の年"].exists { break }
            log("\(name): RETRY (the simulator was overloaded); waited \(waitUntilResponsive(march)) s")
        }
        keepScreenshot(app, "\(name) — after")
        if !opened {
            log("\(name): the day page did not open. Elements:\n\(app.debugDescription)")
        }
        XCTAssertTrue(opened, "\(name): the day page opened")
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "3月16日")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 2), "\(name): the day page of 3/16")
        waitForTheDayWindow(app, name)
        log("\(name): OK (\(title.label))")
    }

    /// 1.4.3 (docs/R1_4_3_CONTRACT.md §11.3, 0g-52): on the joined path (`span.state` says `path=span;`) the screen is read
    /// until `span.state` says `;kind=day;`: the window of years said `path=span;` before the tap too, so the child's wait for
    /// `path=span;` (SpanRerunUITests.swift, not changed) no longer waits for the day window. Polled every 0.3 s for at most
    /// `timeout` s, read once more after the deadline and at least `reads` times (R1_4_2_CONTRACT §1.5), the reads logged.
    /// Nothing to wait for without `span.state` (1.2.3's arguments alone: the parent's own run) or on another path. It
    /// asserts nothing: the child `YearTapSpanRerunUITests` asserts the day window.
    private func waitForTheDayWindow(_ app: XCUIApplication, _ name: String, timeout: TimeInterval = 10, reads: Int = 6) {
        let state = app.descendants(matching: .any).matching(identifier: "span.state").firstMatch
        guard state.exists else {
            log("\(name): no span.state (the one page's arguments): no wait for the day window")
            return
        }
        var label = state.label
        guard label.hasPrefix("path=span;") else {
            log("\(name): span.state \(label): not the joined path, no wait for the day window")
            return
        }
        let deadline = Date().addingTimeInterval(timeout)
        var count = 1
        var pastDeadline = false
        while !label.contains(";kind=day;") {
            if pastDeadline, count >= reads { break }
            if Date() >= deadline { pastDeadline = true }
            Thread.sleep(forTimeInterval: 0.3)
            label = state.exists ? state.label : "-"
            count += 1
        }
        let day = label.contains(";kind=day;")
        log("\(name): the joined path: span.state \(day ? "reads the day window" : "does NOT read a day window") after \(count) reads: \(label)")
    }

    /// 1.4.3 (0g-52): the canvas's probe (`InkCanvasView.Coordinator.probeValue()`) once two reads 0.5 s apart agree on
    /// its zoom, offset, paper and frame; the deadline is `timeout` s, read once more after it and at least `reads` times
    /// (R1_4_2_CONTRACT §1.5). The last read when it never settled; nil without a probe with a zoom.
    private func settledProbe(in app: XCUIApplication, _ name: String, timeout: TimeInterval = 8, reads: Int = 4) -> YearTapProbe? {
        let canvas = app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
        guard canvas.waitForExistence(timeout: 10) || canvas.exists else { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        var last: YearTapProbe?
        var count = 0
        var pastDeadline = false
        while true {
            count += 1
            if let raw = canvas.value as? String {
                let now = YearTapProbe(raw: raw, frame: canvas.frame)
                if now.isReady, let previous = last, now.isAlike(previous) {
                    log("\(name): the probe settled in \(count) reads")
                    return now
                }
                last = now
            }
            if pastDeadline, count >= reads { break }
            if Date() >= deadline { pastDeadline = true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        log("\(name): the probe did not settle in \(count) reads; the last \(last?.raw ?? "-")")
        return last.flatMap { $0.isReady ? $0 : nil }
    }

    /// `span.state`'s value, `-` without it (the one page's arguments).
    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = app.descendants(matching: .any).matching(identifier: "span.state").firstMatch
        return state.exists ? state.label : "-"
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

    /// Waits (at most `timeout` seconds) until a query of `element` answers within 1 s: a freshly
    /// booted simulator can be busy for a minute or two (run 41172398011: 5–10 s per query). Returns
    /// the seconds waited, rounded.
    @discardableResult
    private func waitUntilResponsive(_ element: XCUIElement, timeout: TimeInterval = 60) -> Int {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let queried = Date()
            _ = element.frame
            if Date().timeIntervalSince(queried) < 1 { break }
            Thread.sleep(forTimeInterval: 1)
        }
        return Int(Date().timeIntervalSince(start).rounded())
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

/// 1.4.3 (0g-52): one read of the canvas's probe (`key=value` pairs joined by `;`): `zoom`, the content offset `ox` /
/// `oy` (pt) and the paper's `ph` (lu), with the canvas's frame on screen.
private struct YearTapProbe {
    let raw: String
    let frame: CGRect
    let values: [String: String]

    init(raw: String, frame: CGRect) {
        self.raw = raw
        self.frame = frame
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        self.values = values
    }

    private func number(_ key: String) -> CGFloat {
        values[key].flatMap { Double($0) }.map { CGFloat($0) } ?? 0
    }

    var zoom: CGFloat { number("zoom") }
    var oy: CGFloat { number("oy") }
    var isReady: Bool { zoom > 0 && frame.width > 0 && frame.height > 0 }

    /// The same zoom, offset and paper as `other`'s, and the same frame.
    func isAlike(_ other: YearTapProbe) -> Bool {
        frame == other.frame && ["zoom", "ox", "oy", "ph"].allSatisfy { values[$0] == other.values[$0] }
    }
}
