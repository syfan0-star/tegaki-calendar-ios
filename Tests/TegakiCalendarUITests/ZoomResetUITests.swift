import UIKit
import XCTest

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §6.1, §3.6–§3.8, 0e-7–0e-9): 等倍 on the real screen of an iPhone (build.yml's ui-tests, the
/// iPhone 17; its steps are the `zoom-reset UI:` lines). What the canvas's unit tests cannot see: a real two-finger pinch
/// through UIKit, the header's button (`header.zoomReset`) reaching the canvas through the screen, and the sticky heading
/// following the zoom the canvas reports. The app runs in its screenshot mode (no onboarding, no EventKit, nothing saved)
/// with the canvas's probe (`--screenshot-probe`: its zoom and offset) and 「指でも書く」 off (one finger moves the paper,
/// so no pinch can write).
///
/// - The year and the week (one page) pinched: a column of the heading gets wider; 等倍 brings the zoom and the column
///   back (0.0005, 0.5 pt).
/// - A week opened zoomed in (`--screenshot-zoom 2`, the stored ratio's way in): 等倍 halves the zoom and the column.
/// - The joined week in landscape (`--screenshot-span on`, the cap of 3 weeks across): from twice the cap, 等倍 shows 3
///   weeks across — 1,400 lu × the zoom = a third of the paper area (`ZoomPolicy.cappedBounds`: the cap is vw / (3 × 1,400)
///   lu) — and a day column is vw × 190.857 / 4,200 pt ≈ vw / 22.006 (a week's day column is (1,400 − 64) / 7 lu,
///   `PaperSpec`), ± 0.5.
///
/// 「開き直しても等倍」 is not looked at here (the contract's §6.1 note, form (b)): screenshot mode never writes the stored
/// ratio and always opens at `--screenshot-zoom` (1 by default), so a relaunch in it would pass whatever 等倍 did. That the
/// press reports ratio 1 is `InkCanvasZoomResetTests`'; that ratio 1 removes the kind's stored ratio is
/// `AppSettingsTests.testTheOverviewRemovesTheKey` (the screen's closure is 1.4's).
@MainActor
final class ZoomResetUITests: XCTestCase {
    private static let resetIdentifier = "header.zoomReset"
    /// The year's month column (lu, `PaperSpec.yearColumnWidth`).
    private static let yearColumn: CGFloat = 112
    /// A week's day column (lu): (1,400 − the 64 lu time column) / 7.
    private static let weekColumn: CGFloat = (1400 - 64) / 7.0
    /// The capped iPhone landscape's three weeks across (lu).
    private static let threeWeeks: CGFloat = 3 * 1400
    private static let marchLabel = "2026年3月（月表示へ）"
    private static let dayColumnSuffix = "（日表示へ）"

    // MARK: Tests

    func testThePinchedYearAndWeekGoBackToTheOpeningZoom() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        pinchAndReset("year", [], column: { $0.buttons[Self.marchLabel] })
        pinchAndReset("week", ["--screenshot-span", "off"], column: { Self.dayColumns(in: $0).firstMatch })
    }

    func testAWeekOpenedZoomedInGoesBackToTheOpeningZoom() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let name = "opened at ratio 2"
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-span", "off",
                          "--screenshot-zoom", "2", "--screenshot-probe"], name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let zoomed = number("zoom", opened.values) else { return }
        let column = Self.dayColumns(in: app).firstMatch
        XCTAssertTrue(column.waitForExistence(timeout: 5), "\(name): a day column of the heading")
        let wide = settledFrame(of: column).width
        log("\(name): zoom=\(zoomed) column=\(column.frame) (\(Self.weekColumn) lu × zoom = \(Self.weekColumn * zoomed))")
        guard tapReset(in: app, name) else { return }
        let zoom = zoomAfterReset(in: app, near: zoomed / 2, name)
        let narrow = settledFrame(of: column).width
        log("\(name): after 等倍 zoom=\(zoom) column=\(narrow)")
        XCTAssertEqual(zoom, zoomed / 2, accuracy: 0.0005, "\(name): the opening zoom (ratio 1)")
        XCTAssertEqual(narrow, wide / 2, accuracy: 0.5, "\(name): the column at the opening zoom")
        log("\(name): OK")
    }

    func testTheJoinedWeekInLandscapeGoesBackToThreeWeeksAcross() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the cap is an iPhone's in landscape")
        continueAfterFailure = true
        let name = "joined week landscape"
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-span", "on",
                          "--screenshot-zoom", "2", "--screenshot-probe"], name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let zoomed = number("zoom", opened.values) else { return }
        let area = opened.frame
        let cap = area.width / Self.threeWeeks
        log("\(name): paper area=\(area) zoom=\(zoomed) cap=\(cap)")
        XCTAssertEqual(zoomed, 2 * cap, accuracy: 0.001, "\(name): opened at twice the cap")
        guard tapReset(in: app, name) else { return }
        let zoom = zoomAfterReset(in: app, near: cap, name)
        XCTAssertEqual(zoom, cap, accuracy: 0.0005, "\(name): 等倍 is the cap")
        XCTAssertEqual(1400 * zoom, area.width / 3, accuracy: 0.5, "\(name): 3 weeks across")
        guard let column = visibleDayColumn(in: app, within: area) else {
            XCTFail("\(name): no day column of the heading inside the paper area. Elements:\n\(app.debugDescription)")
            return
        }
        let width = settledFrame(of: column).width
        log("\(name): after 等倍 zoom=\(zoom) column=\(column.label) \(column.frame)")
        XCTAssertEqual(width, area.width * Self.weekColumn / Self.threeWeeks, accuracy: 0.5,
                       "\(name): a day column is vw × 190.857 / 4,200 (≈ vw / 22.006)")
        log("\(name): OK")
    }

    // MARK: The steps

    /// Opens `page`, reads the opening zoom and a heading column, pinches the paper open (a second pinch only when the first
    /// did not reach the app: an overloaded simulator), then 等倍: the zoom and the column back.
    private func pinchAndReset(_ page: String, _ extra: [String], column find: (XCUIApplication) -> XCUIElement) {
        let name = "pinch \(page)"
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", page, "--screenshot-probe"] + extra, name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let open = number("zoom", opened.values) else { return }
        let column = find(app)
        guard column.waitForExistence(timeout: 5) else {
            XCTFail("\(name): no column of the heading. Elements:\n\(app.debugDescription)")
            return
        }
        let before = settledFrame(of: column).width
        log("\(name): zoom=\(open) column=\(column.frame)")
        let canvas = canvasElement(in: app)
        var pinched = open
        for attempt in 1...2 {
            canvas.pinch(withScale: 2.5, velocity: 2)
            guard let probe = settledProbe(in: app, "\(name) attempt \(attempt)"), let zoom = number("zoom", probe.values) else { return }
            pinched = zoom
            log("\(name): attempt \(attempt): zoom=\(zoom)")
            if zoom > open * 1.2 { break }
        }
        XCTAssertGreaterThan(pinched, open * 1.2, "\(name): the pinch zoomed in")
        let wide = settledFrame(of: column).width
        log("\(name): pinched column=\(column.frame)")
        XCTAssertGreaterThan(wide, before + 1, "\(name): the heading's column grew with the paper")
        guard tapReset(in: app, name) else { return }
        let zoom = zoomAfterReset(in: app, near: open, name)
        let after = settledFrame(of: column).width
        log("\(name): after 等倍 zoom=\(zoom) column=\(column.frame)")
        XCTAssertEqual(zoom, open, accuracy: 0.0005, "\(name): back to the opening zoom")
        XCTAssertEqual(after, before, accuracy: 0.5, "\(name): the heading's column back")
        log("\(name): OK")
    }

    private func launch(_ arguments: [String], _ name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"] + arguments + [
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
            // UserDefaults' argument domain: 「指でも書く」 off, and already chosen (YearTapUITests).
            "-allowFingerDrawing", "NO", "-allowFingerDrawingChosen", "YES",
        ]
        app.launch()
        log("\(name): launched \(arguments.joined(separator: " "))")
        return app
    }

    /// Taps 等倍 (the header's `header.zoomReset`); false (and a failure) when the header has no such button.
    private func tapReset(in app: XCUIApplication, _ name: String) -> Bool {
        let reset = app.buttons[Self.resetIdentifier]
        guard reset.waitForExistence(timeout: 5) else {
            XCTFail("\(name): no \(Self.resetIdentifier). Elements:\n\(app.debugDescription)")
            return false
        }
        log("\(name): 等倍 \(reset.label) \(reset.frame)")
        reset.tap()
        return true
    }

    /// The canvas's zoom after 等倍: once it is within 0.0005 of `target` (at most 8 s) and two reads agree, or the last read.
    private func zoomAfterReset(in app: XCUIApplication, near target: CGFloat, _ name: String) -> CGFloat {
        let canvas = canvasElement(in: app)
        let deadline = Date().addingTimeInterval(8)
        var zoom: CGFloat = .nan
        while Date() < deadline {
            if let raw = canvas.value as? String, let read = number("zoom", Self.values(of: raw)) {
                zoom = read
                if abs(read - target) < 0.0005 { break }
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        if let probe = settledProbe(in: app, "\(name) after 等倍"), let settled = number("zoom", probe.values) {
            zoom = settled
        }
        return zoom
    }

    private func canvasElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
    }

    /// The week heading's day columns (their spoken name ends in 「（日表示へ）」).
    private static func dayColumns(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", dayColumnSuffix))
    }

    /// A day column of the joined heading whose whole frame lies over the paper area (the heading clips the others).
    private func visibleDayColumn(in app: XCUIApplication, within area: CGRect) -> XCUIElement? {
        let columns = Self.dayColumns(in: app)
        for index in 0..<min(columns.count, 80) {
            let column = columns.element(boundBy: index)
            let frame = column.frame
            if frame.width > 0, frame.minX >= area.minX - 0.5, frame.maxX <= area.maxX + 0.5 {
                return column
            }
        }
        return nil
    }

    /// The canvas's probe once it has a zoom and two reads 0.4 s apart agree (`HeaderAndPaperUITests`).
    private func settledProbe(in app: XCUIApplication, _ name: String, timeout: TimeInterval = 15) -> (values: [String: String], frame: CGRect)? {
        let canvas = canvasElement(in: app)
        guard canvas.waitForExistence(timeout: 30) else {
            XCTFail("\(name): no 「ink-canvas」 element")
            return nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        var last: [String: String]?
        while Date() < deadline {
            if let raw = canvas.value as? String {
                let values = Self.values(of: raw)
                if (number("zoom", values) ?? 0) > 0, canvas.frame.width > 0 {
                    if let last, ["zoom", "ox", "oy"].allSatisfy({ last[$0] == values[$0] }) {
                        log("\(name): frame=\(canvas.frame) zoom=\(values["zoom"] ?? "?") ox=\(values["ox"] ?? "?") oy=\(values["oy"] ?? "?")")
                        return (values, canvas.frame)
                    }
                    last = values
                }
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTFail("\(name): the canvas never settled (\(String(describing: last)))")
        return nil
    }

    /// The element's frame once two reads 0.5 s apart agree (at most `timeout` seconds; `YearTapUITests`).
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

    private func number(_ key: String, _ values: [String: String]) -> CGFloat? {
        values[key].flatMap(Double.init).map { CGFloat($0) }
    }

    /// The probe's `key=value` pairs, joined by `;`.
    private static func values(of raw: String) -> [String: String] {
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        return values
    }

    private func log(_ line: String) {
        print("zoom-reset UI: \(line)")
        NSLog("zoom-reset UI: %@", line)
    }
}
