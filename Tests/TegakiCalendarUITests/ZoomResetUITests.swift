import UIKit
import XCTest

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §6.1, §3.6–§3.8, §16.3, §16.6, 0e-7–0e-9): 等倍 on the real screen of an iPhone (build.yml's
/// ui-tests, the iPhone 17; its steps are the `zoom-reset UI:` lines). What the canvas's unit tests cannot see: a real
/// two-finger pinch through UIKit, the header's button (`header.zoomReset`) reaching the canvas through the screen, and the
/// sticky heading following the zoom the canvas reports. The app runs in its screenshot mode (no onboarding, no EventKit,
/// nothing saved) with the canvas's probe (`--screenshot-probe`: its zoom and offset) and 「指でも書く」 off (one finger moves
/// the paper, so no pinch can write). The paper area is the canvas's frame (its width the paper's column, `vw`).
///
/// The rework (§16.3.1): 等倍 of a week or a day is one page's width across the column, fit = vw ÷ 1,400 lu (the week) or
/// vw ÷ 1,000 lu (the day); a month's or a year's is still its opening zoom.
/// - The year and the week (one page) pinched: a column of the heading gets wider; 等倍 brings the year's zoom and column
///   back (0.0005, 0.5 pt) and takes the week to the fit, its day column vw × 190.857 / 1,400 pt (a week's day column is
///   (1,400 − 64) / 7 lu, `PaperSpec`; about 1.1 pt wider than at the opening zoom on the iPhone 17, so 0.5 pt tells them
///   apart).
/// - A week opened zoomed in (`--screenshot-zoom 2`, the stored ratio's way in): 等倍 takes it to the fit, 1,400 lu × the
///   zoom = vw, the day column as above.
/// - The joined week in landscape (`--screenshot-span on`, opened at twice the cap of 3 weeks across): 等倍 shows one week
///   across (1,400 lu × the zoom = vw ± 0.5, the day column as above), not the cap; the edges of the week in the middle are
///   logged (the canvas's unit tests hold them).
/// - A day as it opens (one page): 等倍 shows one day across, 1,000 lu × the zoom = vw ± 0.5, x 0.
/// - A week opened at 等倍 (`--screenshot-zoom fit`, §16.3.7): 等倍 changes nothing (zoom and offset as they were).
///
/// 「開き直しても等倍」 is not looked at here (form (b) of §6.1's note): screenshot mode never writes the stored ratio nor
/// `zoomFit.<kind>` and always opens at `--screenshot-zoom` (1 by default), so a relaunch in it would pass whatever 等倍 did.
/// That the press reports the fit is `InkCanvasZoomResetTests`'; what the screen keeps of it is
/// `AppSettingsTests.testZoomFitReplacesTheRatio` and `ZoomFitWiringTests` (its closures).
@MainActor
final class ZoomResetUITests: XCTestCase {
    private static let resetIdentifier = "header.zoomReset"
    /// The year's month column (lu, `PaperSpec.yearColumnWidth`).
    private static let yearColumn: CGFloat = 112
    /// A week's day column (lu): (1,400 − the 64 lu time column) / 7.
    private static let weekColumn: CGFloat = (1400 - 64) / 7.0
    /// One page's width (lu): the week's and the day's (`ZoomPolicy.paperWidth`).
    private static let weekWidth: CGFloat = 1400
    private static let dayWidth: CGFloat = 1000
    private static let marchLabel = "2026年3月（月表示へ）"
    private static let dayColumnSuffix = "（日表示へ）"

    // MARK: Tests

    func testThePinchedYearGoesBackToItsOpeningZoomAndThePinchedWeekToOneWeekAcross() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        pinchAndReset("year", [], toFit: false, column: { $0.buttons[Self.marchLabel] })
        pinchAndReset("week", ["--screenshot-span", "off"], toFit: true, column: { Self.dayColumns(in: $0).firstMatch })
    }

    func testAWeekOpenedZoomedInGoesToOneWeekAcross() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let name = "opened at ratio 2"
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-span", "off",
                          "--screenshot-zoom", "2", "--screenshot-probe"], name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let zoomed = number("zoom", opened.values) else { return }
        let area = opened.frame
        let fit = area.width / Self.weekWidth
        let column = Self.dayColumns(in: app).firstMatch
        XCTAssertTrue(column.waitForExistence(timeout: 5), "\(name): a day column of the heading")
        let wide = settledFrame(of: column).width
        log("\(name): paper area=\(area) zoom=\(zoomed) fit=\(fit) column=\(column.frame) (\(Self.weekColumn) lu × zoom = \(Self.weekColumn * zoomed))")
        XCTAssertGreaterThan(zoomed, fit * 1.2, "\(name): opened zoomed in past the fit")
        guard tapReset(in: app, name) else { return }
        let zoom = zoomAfterReset(in: app, near: fit, name)
        let narrow = settledFrame(of: column).width
        log("\(name): after 等倍 zoom=\(zoom) column=\(narrow) (before \(wide))")
        XCTAssertEqual(zoom, fit, accuracy: 0.0005, "\(name): 等倍 is the fit (vw ÷ 1,400)")
        XCTAssertEqual(Self.weekWidth * zoom, area.width, accuracy: 0.5, "\(name): one week across")
        XCTAssertEqual(narrow, area.width * Self.weekColumn / Self.weekWidth, accuracy: 0.5,
                       "\(name): a day column is vw × 190.857 / 1,400")
        log("\(name): OK")
    }

    func testTheJoinedWeekInLandscapeGoesToOneWeekAcross() throws {
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
        // The cap of 3 weeks across (`ZoomPolicy.cappedBounds`: vw ÷ (3 × 1,400 lu)), the window's opening zoom here.
        let cap = area.width / (3 * Self.weekWidth)
        let fit = area.width / Self.weekWidth
        log("\(name): paper area=\(area) zoom=\(zoomed) cap=\(cap) fit=\(fit)")
        XCTAssertEqual(zoomed, 2 * cap, accuracy: 0.001, "\(name): opened at twice the cap")
        guard tapReset(in: app, name) else { return }
        let zoom = zoomAfterReset(in: app, near: fit, name)
        XCTAssertEqual(zoom, fit, accuracy: 0.0005, "\(name): 等倍 is the fit, not the cap")
        XCTAssertEqual(Self.weekWidth * zoom, area.width, accuracy: 0.5, "\(name): one week across")
        guard let column = visibleDayColumn(in: app, within: area) else {
            XCTFail("\(name): no day column of the heading inside the paper area. Elements:\n\(app.debugDescription)")
            return
        }
        let width = settledFrame(of: column).width
        log("\(name): after 等倍 zoom=\(zoom) column=\(column.label) \(column.frame)")
        XCTAssertEqual(width, area.width * Self.weekColumn / Self.weekWidth, accuracy: 0.5,
                       "\(name): a day column is vw × 190.857 / 1,400")
        logWeekEdges(in: app, within: area, zoom: zoom, name)
        log("\(name): OK")
    }

    func testAnOpenDayGoesToOneDayAcross() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let name = "open day"
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "day", "--screenshot-span", "off",
                          "--screenshot-probe"], name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let open = number("zoom", opened.values) else { return }
        let area = opened.frame
        let fit = area.width / Self.dayWidth
        log("\(name): paper area=\(area) zoom=\(open) fit=\(fit)")
        XCTAssertLessThan(open, fit / 1.2, "\(name): the day opens below the fit (its 24 hours)")
        guard tapReset(in: app, name) else { return }
        let zoom = zoomAfterReset(in: app, near: fit, name)
        let after = settledProbe(in: app, "\(name) after 等倍")
        log("\(name): after 等倍 zoom=\(zoom) ox=\(after?.values["ox"] ?? "?") oy=\(after?.values["oy"] ?? "?")")
        XCTAssertEqual(zoom, fit, accuracy: 0.0005, "\(name): 等倍 is the fit (vw ÷ 1,000)")
        XCTAssertEqual(Self.dayWidth * zoom, area.width, accuracy: 0.5, "\(name): one day across")
        if let after {
            XCTAssertEqual(number("ox", after.values) ?? -999, 0, accuracy: 0.5, "\(name): the page's left edge at the left edge")
        }
        log("\(name): OK")
    }

    func testAWeekOpenedAtTheFitStaysWhereItIs() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let name = "week opened at fit"
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-span", "off",
                          "--screenshot-zoom", "fit", "--screenshot-probe"], name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let zoom = number("zoom", opened.values) else { return }
        let area = opened.frame
        let fit = area.width / Self.weekWidth
        log("\(name): paper area=\(area) zoom=\(zoom) fit=\(fit) ox=\(opened.values["ox"] ?? "?") oy=\(opened.values["oy"] ?? "?")")
        XCTAssertEqual(zoom, fit, accuracy: 0.0005, "\(name): opened at the fit")
        guard tapReset(in: app, name) else { return }
        // Nothing is to come: wait as long as a reset takes to show, then read again.
        Thread.sleep(forTimeInterval: 2)
        guard let after = settledProbe(in: app, "\(name) after 等倍") else { return }
        log("\(name): after 等倍 zoom=\(after.values["zoom"] ?? "?") ox=\(after.values["ox"] ?? "?") oy=\(after.values["oy"] ?? "?")")
        XCTAssertEqual(number("zoom", after.values) ?? -1, zoom, accuracy: 0.0005, "\(name): the zoom as it was")
        for key in ["ox", "oy"] {
            XCTAssertEqual(number(key, after.values) ?? -999, number(key, opened.values) ?? 999, accuracy: 0.5,
                           "\(name): \(key) as it was")
        }
        log("\(name): OK")
    }

    // MARK: The steps

    /// Opens `page`, reads the opening zoom and a heading column, pinches the paper open (a second pinch only when the first
    /// did not reach the app: an overloaded simulator), then 等倍: `toFit` false (the year), the opening zoom and the column
    /// as they opened; true (the week), the fit (vw ÷ 1,400) and its day column (vw × 190.857 / 1,400).
    private func pinchAndReset(_ page: String, _ extra: [String], toFit: Bool, column find: (XCUIApplication) -> XCUIElement) {
        let name = "pinch \(page)"
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", page, "--screenshot-probe"] + extra, name)
        defer { app.terminate() }
        guard let opened = settledProbe(in: app, name), let open = number("zoom", opened.values) else { return }
        let area = opened.frame
        let column = find(app)
        guard column.waitForExistence(timeout: 5) else {
            XCTFail("\(name): no column of the heading. Elements:\n\(app.debugDescription)")
            return
        }
        let before = settledFrame(of: column).width
        // 等倍's target: the year's opening zoom and column; the week's fit and its day column.
        let target = toFit ? area.width / Self.weekWidth : open
        let targetColumn = toFit ? area.width * Self.weekColumn / Self.weekWidth : before
        log("\(name): paper area=\(area) zoom=\(open) column=\(column.frame) 等倍 zoom=\(target) column=\(targetColumn)")
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
        let zoom = zoomAfterReset(in: app, near: target, name)
        let after = settledFrame(of: column).width
        log("\(name): after 等倍 zoom=\(zoom) column=\(column.frame)")
        if toFit {
            XCTAssertEqual(zoom, target, accuracy: 0.0005, "\(name): 等倍 is the fit (vw ÷ 1,400)")
            XCTAssertEqual(after, targetColumn, accuracy: 0.5, "\(name): a day column is vw × 190.857 / 1,400")
        } else {
            XCTAssertEqual(zoom, target, accuracy: 0.0005, "\(name): back to the opening zoom")
            XCTAssertEqual(after, targetColumn, accuracy: 0.5, "\(name): the heading's column back")
        }
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

    /// Logs where the joined week's heading columns inside the paper area begin and end after 等倍 (one week across: its first
    /// day column from 64 lu × the zoom right of the area's left edge, its last one ending at the right edge). Logs only:
    /// the canvas's unit tests (`InkCanvasSpanZoomResetTests`) hold the edges; a heading column's frame is XCUI's, to the
    /// pixel.
    private func logWeekEdges(in app: XCUIApplication, within area: CGRect, zoom: CGFloat, _ name: String) {
        let columns = Self.dayColumns(in: app)
        var inside: [CGRect] = []
        for index in 0..<min(columns.count, 80) {
            let frame = columns.element(boundBy: index).frame
            if frame.width > 0, frame.minX >= area.minX - 0.5, frame.maxX <= area.maxX + 0.5 {
                inside.append(frame)
            }
        }
        let first = inside.map(\.minX).min().map { String(format: "%.1f", $0) } ?? "-"
        let last = inside.map(\.maxX).max().map { String(format: "%.1f", $0) } ?? "-"
        log("\(name): edges: \(inside.count) day columns inside, first minX=\(first) (expected \(String(format: "%.1f", area.minX + 64 * zoom))), "
            + "last maxX=\(last) (expected \(String(format: "%.1f", area.maxX)))")
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
