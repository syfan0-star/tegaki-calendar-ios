import UIKit
import XCTest

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.8, §6.1, §6.5, 0f-15): the pen colour panel beside every bar of a 13-inch iPad — the
/// upright bars on the left and the right, the bar on the top, the folded bar peeked at the bottom and on the left (where
/// the owner could not find 1.4.1's piece on a peek, R1_4_1_CONTRACT §18.1). build.yml's blank-paper job runs it in its step
/// "Palette UI tests on the 13-inch iPad (1.4.1, 1.4.2)", which passes TEST_RUNNER_TEGAKI_PALETTE_UI=1; skipped everywhere
/// else (ui-tests' iPhone has ColorPanelUITests). Screenshot mode (`--screenshot-palette`, `--screenshot-toolbar collapsed`;
/// its dots in a scratch store emptied at the launch). Its steps are the `color-panel UI:` lines.
///
/// - `testThePanelOpensBesideTheBar`: on the left, the right and the top, a tap on the lit dot opens the panel on the paper's
///   side of the bar (left: its left edge right of the bar, `tool.pen` and the dot; right: its right edge left of them; top:
///   under them), inside the window; a tap on the dot again closes it.
/// - `testThePanelOpensFromThePeeks`: folded bottom left, the round button's tool mark peeks the bar at the bottom; a tap on
///   its lit dot opens the panel above it; 茶 closes it and the peek stays (茶 on dot 1); 「最初の色に戻す」 puts 黒 back. The
///   same with the bar kept on the left: the peek on the left, the panel right of it.
@MainActor
final class ColorPanelPadUITests: XCTestCase {
    private static let panelId = "toolbar.colorPanel"
    private static let stateIdentifier = "palette.state"
    private static let dockLabel = "ツールバーを出す"

    private func requirePad() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TEGAKI_PALETTE_UI"] == "1",
                          "only in blank-paper's step \"Palette UI tests on the 13-inch iPad (1.4.1, 1.4.2)\"")
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "the iPad's bars")
    }

    func testThePanelOpensBesideTheBar() throws {
        try requirePad()
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        for edge in ["left", "right", "top"] {
            let app = launch(["--screenshot-page", "week", "--screenshot-palette", edge])
            defer { app.terminate() }
            guard waitForState(app, timeout: 30, { $0["edge"] == edge }) != nil else {
                XCTFail("\(edge): the bar never stood on \(edge): \(stateLabel(app))")
                continue
            }
            let pen = app.buttons["ペン"]
            XCTAssertTrue(pen.waitForExistence(timeout: 10), "\(edge): 「ペン」")
            guard let lit = litDot(app) else {
                XCTFail("\(edge): no lit dot")
                continue
            }
            let dotFrame = stable(lit)
            let penFrame = stable(pen)
            lit.tap()
            let panel = element(app, Self.panelId)
            guard panel.waitForExistence(timeout: 5) else {
                keepScreenshot(app, "\(edge) — no panel")
                XCTFail("\(edge): a tap on the lit dot opened no panel")
                continue
            }
            let frame = stable(panel)
            let window = app.windows.firstMatch.frame
            log("\(edge): dot \(lit.identifier) \(text(dotFrame)) pen \(text(penFrame)) panel \(text(frame)) window \(text(window))")
            keepScreenshot(app, "\(edge) — the panel")
            switch edge {
            case "left":
                XCTAssertGreaterThanOrEqual(frame.minX, max(dotFrame.maxX, penFrame.maxX) - 0.5, "left: the panel right of the bar")
            case "right":
                XCTAssertLessThanOrEqual(frame.maxX, min(dotFrame.minX, penFrame.minX) + 0.5, "right: the panel left of the bar")
            default:
                XCTAssertGreaterThanOrEqual(frame.minY, max(dotFrame.maxY, penFrame.maxY) - 0.5, "top: the panel under the bar")
            }
            XCTAssertTrue(window.contains(frame), "\(edge): the panel on the screen (\(text(frame)) in \(text(window)))")
            lit.tap()
            XCTAssertTrue(waitUntil(timeout: 5) { !panel.exists }, "\(edge): the dot's second tap closed it")
        }
    }

    func testThePanelOpensFromThePeeks() throws {
        try requirePad()
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        for edge in ["bottom", "left"] {
            let app = launch(["--screenshot-page", "week", "--screenshot-palette", edge, "--screenshot-toolbar", "collapsed"])
            defer { app.terminate() }
            let name = "peek \(edge)"
            let dock = app.buttons[Self.dockLabel]
            guard dock.waitForExistence(timeout: 30) else {
                XCTFail("\(name): no round button: \(stateLabel(app))")
                continue
            }
            dock.tap()
            let pen = app.buttons["ペン"]
            XCTAssertTrue(pen.waitForExistence(timeout: 10), "\(name): the bar peeked")
            guard let lit = waitForLitDot(app) else {
                XCTFail("\(name): no lit dot on the peek")
                continue
            }
            let dotFrame = stable(lit)
            let penFrame = stable(pen)
            lit.tap()
            let panel = element(app, Self.panelId)
            guard panel.waitForExistence(timeout: 5) else {
                keepScreenshot(app, "\(name) — no panel")
                XCTFail("\(name): a tap on the peek's lit dot opened no panel")
                continue
            }
            let frame = stable(panel)
            let window = app.windows.firstMatch.frame
            log("\(name): dot \(lit.identifier) \(text(dotFrame)) pen \(text(penFrame)) panel \(text(frame)) state \(stateLabel(app))")
            keepScreenshot(app, "\(name) — the panel")
            if edge == "left" {
                XCTAssertGreaterThanOrEqual(frame.minX, max(dotFrame.maxX, penFrame.maxX) - 0.5, "\(name): the panel right of the peek")
            } else {
                XCTAssertLessThanOrEqual(frame.maxY, dotFrame.minY + 0.5, "\(name): the panel above the dot")
            }
            XCTAssertTrue(window.contains(frame), "\(name): the panel on the screen")

            app.buttons["toolbar.colorPanel.92400e"].tap()
            XCTAssertTrue(waitUntil(timeout: 5) { !panel.exists }, "\(name): 茶 closed the panel")
            let dot0 = app.buttons["toolbar.swatch.0"]
            XCTAssertTrue(waitUntil(timeout: 5) { dot0.exists && dot0.label == "茶" && dot0.isSelected }, "\(name): 茶 on dot 1, lit")
            XCTAssertTrue(pen.exists && !dock.exists, "\(name): the peek stayed (\(pen.exists), round button \(dock.exists))")
            log("\(name): after 茶 dot 1 \(dot0.label) peek \(pen.exists) round button \(dock.exists)")

            // 黒 back for the next launch (toolbar.penColor is the simulator's).
            dot0.tap()
            XCTAssertTrue(panel.waitForExistence(timeout: 5), "\(name): open again")
            app.buttons["toolbar.colorPanel.reset"].tap()
            XCTAssertTrue(waitUntil(timeout: 5) { !panel.exists && dot0.label == "黒" }, "\(name): 黒 again")
        }
    }

    // MARK: - Steps

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + extra
        app.launch()
        log("launched \(extra.joined(separator: " "))")
        return app
    }

    /// The lit dot (`toolbar.swatch.<i>` that is selected).
    private func litDot(_ app: XCUIApplication) -> XCUIElement? {
        for index in 0..<6 {
            let dot = app.buttons["toolbar.swatch.\(index)"]
            if dot.exists, dot.isSelected { return dot }
        }
        return nil
    }

    private func waitForLitDot(_ app: XCUIApplication) -> XCUIElement? {
        var found: XCUIElement?
        _ = waitUntil(timeout: 10) {
            found = self.litDot(app)
            return found != nil
        }
        return found
    }

    /// The element's frame once two reads 0.3 s apart agree (at most 3 s: a peek slides in).
    private func stable(_ element: XCUIElement) -> CGRect {
        var last = element.frame
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            let now = element.frame
            if now == last { return now }
            last = now
        }
        return element.frame
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = element(app, Self.stateIdentifier)
        return state.exists ? state.label : "-"
    }

    /// `palette.state`'s fields once `condition` holds, read every 0.3 s; read once more at the deadline.
    private func waitForState(_ app: XCUIApplication, timeout: TimeInterval, _ condition: ([String: String]) -> Bool) -> [String: String]? {
        func read() -> [String: String]? {
            let state = element(app, Self.stateIdentifier)
            guard state.exists else { return nil }
            var values: [String: String] = [:]
            for part in state.label.split(separator: ";") {
                guard let equals = part.firstIndex(of: "=") else { continue }
                values[String(part[..<equals])] = String(part[part.index(after: equals)...])
            }
            return condition(values) ? values : nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let values = read() { return values }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return read()
    }

    /// Whether `condition` held within `timeout` (polled every 0.2 s), read once more after the deadline.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    private func text(_ rect: CGRect) -> String {
        [rect.minX, rect.minY, rect.width, rect.height].map { String(format: "%.1f", Double($0)) }.joined(separator: ",")
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func log(_ line: String) {
        print("color-panel UI: \(line)")
        NSLog("color-panel UI: %@", line)
    }
}
