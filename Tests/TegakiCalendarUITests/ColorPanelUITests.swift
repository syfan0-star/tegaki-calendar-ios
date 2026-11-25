import UIKit
import XCTest

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.4–§3.7, §3.10, §6.1, 0f-9–0f-14): the pen colour panel on the real screen of an iPhone
/// (ui-tests, iPhone 17), with the bar at the bottom in its `safeAreaInset` (that the lit dot's frame reaches the screen's top
/// layer from there is what only this test sees, §13.1's 1). One launch of the week page in screenshot mode (its dots in a
/// scratch store emptied at the launch, so the first six), 「指でも書く」 on, its steps the `color-panel UI:` lines:
///
/// 1. a long press of the lit dot (黒) opens the panel (`toolbar.colorPanel`), which stays after the lift; a tap on the header's
///    title (no button) closes it;
/// 2. a tap on the lit dot opens it, 茶 (`toolbar.colorPanel.92400e`) closes it — dot 1 (`toolbar.swatch.0`) is 茶 and lit, the
///    canvas's tool `pen:#92400e:<width>`;
/// 3. open again, 青 (dot 2's colour): dot 1 stays 茶, dot 2 lights, the tool is 青;
/// 4. 茶 chosen on the bar again, open, 「その他の色…」: the system's colour picker comes, is closed with nothing chosen, the dots
///    are the same, and the header's 「設定」 opens the settings (so `sheetIsUp` went back to false), closed with 「完了」;
/// 5. open, 「最初の色に戻す」: dot 1 is 黒 again and the tool 黒;
/// 6. open, a finger's line on the paper: the panel closes and the line is written (one more stroke), in 黒 (§3.4's first
///    reason: the first stroke is not lost);
/// 7. open, a tap on dot 2 (not lit): the panel closes and 青 is chosen;
/// 8. open on 青, a drag of the bar's row that starts on the lit dot: the dot moves and the panel closes (§3.6);
/// and back to 黒 for the next test. While the panel is open, whether the bar's other buttons are in the element tree is
/// logged (the panel is modal for VoiceOver, §13.1's 18). The dots and the panel's colours are found by their identifiers
/// (two buttons are labelled 「黒」 while the panel is open); places off the panel are tapped at frames read before it opened.
/// The waits read once more after their deadline (docs/R1_4_1.md's lesson).
@MainActor
final class ColorPanelUITests: XCTestCase {
    private static let panelId = "toolbar.colorPanel"
    private static let brown = "#92400e"
    private static let black = "#1f2937"
    private static let blue = "#2563eb"

    func testThePanelOnTheBottomBar() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "the iPhone's bottom bar (ColorPanelPadUITests has the iPad's)")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-probe",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-allowFingerDrawing", "YES", "-allowFingerDrawingChosen", "YES",
        ]
        app.launch()
        defer { app.terminate() }
        let canvas = element(app, "ink-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 30), "the canvas")
        settle(canvas)
        let dot0 = dot(app, 0)
        let dot1 = dot(app, 1)
        XCTAssertTrue(dot0.waitForExistence(timeout: 10), "toolbar.swatch.0")
        reveal(dot1, in: app)
        if !dot0.isSelected {
            log("start: dot 1 was not lit (\(dot0.label)); chosen")
            dot0.tap()
        }
        XCTAssertTrue(waitUntil(timeout: 5) { dot0.isSelected && self.toolColor(canvas) == Self.black },
                      "start: 黒 lit and the tool 黒 (\(probeTool(canvas)))")
        let title = element(app, "page.title")
        let titleFrame = title.exists ? title.frame : CGRect(x: app.windows.firstMatch.frame.midX - 20, y: 80, width: 40, height: 20)
        let dot1Frame = dot1.frame
        log("start: dot 1 \(text(dot0.frame)) \(dot0.label), dot 2 \(text(dot1Frame)) \(dot1.label), title \(text(titleFrame)), tool \(probeTool(canvas))")

        // 1. A long press opens it; it stays after the lift; a tap on the title closes it.
        dot0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.0)
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "1: the long press opened the panel")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(panel(app).exists, "1: still open after the lift")
        log("1: open at \(text(panel(app).frame)); while open: 「太さ: 中」 in the tree \(app.buttons["太さ: 中"].exists), "
            + "dot 2 \(dot1.exists), 「ペン」 \(app.buttons["ペン"].exists)")
        tap(app, at: CGPoint(x: titleFrame.midX, y: titleFrame.midY))
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "1: a tap on the title closed it")
        // The canvas is read only with the panel closed: open, it is modal and may hide what lies outside it.
        XCTAssertEqual(toolColor(canvas), Self.black, "1: opening and closing changed no pen")
        log("1: closed by the title; tool \(probeTool(canvas))")

        // 2. Open, 茶.
        dot0.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "2: a tap on the lit dot opened it")
        let brownButton = app.buttons["toolbar.colorPanel.92400e"]
        XCTAssertTrue(brownButton.waitForExistence(timeout: 5), "2: 茶 in the panel")
        log("2: panel \(text(panel(app).frame)), 茶 \(text(brownButton.frame)) \(brownButton.label)")
        brownButton.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "2: a colour closed it")
        XCTAssertTrue(waitUntil(timeout: 5) { dot0.label == "茶" && dot0.isSelected && self.toolColor(canvas) == Self.brown },
                      "2: dot 1 茶 and lit, the tool 茶 (\(dot0.label), \(dot0.isSelected), \(probeTool(canvas)))")
        log("2: dot 1 \(dot0.label) selected=\(dot0.isSelected); tool \(probeTool(canvas))")

        // 3. 青, another dot's colour: the dots stay, dot 2 lights.
        dot0.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "3: open")
        app.buttons["toolbar.colorPanel.2563eb"].tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "3: closed")
        XCTAssertTrue(waitUntil(timeout: 5) { dot1.isSelected && self.toolColor(canvas) == Self.blue }, "3: dot 2 lit, the tool 青")
        XCTAssertEqual(dot0.label, "茶", "3: dot 1 keeps 茶")
        XCTAssertEqual(dot1.label, "青")
        log("3: dot 1 \(dot0.label), dot 2 \(dot1.label) selected=\(dot1.isSelected); tool \(probeTool(canvas))")

        // 4. 「その他の色…」: the system's picker, closed with nothing chosen; then 「設定」 opens (sheetIsUp is false again).
        dot0.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { dot0.isSelected && self.toolColor(canvas) == Self.brown }, "4: 茶 chosen on the bar")
        // The header's kind switch is a segmented control of four (日・週・月・年); the picker's (Grid, Spectrum, Sliders) has
        // three. The sheet may hide the header's from the tree (a page sheet is modal for VoiceOver), so the picker is a
        // control of three, or one control more than before it.
        let switches = app.segmentedControls.count
        func pickerShown() -> Bool {
            if app.segmentedControls.count > switches { return true }
            return (0..<app.segmentedControls.count).contains { index in
                let control = app.segmentedControls.element(boundBy: index)
                return control.exists && control.buttons.count == 3
            }
        }
        dot0.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "4: open")
        app.buttons["toolbar.colorPanel.other"].tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "4: 「その他の色…」 closed the panel")
        let shown = waitUntil(timeout: 10) { pickerShown() }
        keepScreenshot(app, "4 — the system's colour picker")
        log("4: the picker \(shown ? "shown" : "not seen") (segmented controls \(switches) → \(app.segmentedControls.count)); "
            + "buttons \((0..<min(10, app.buttons.count)).map { app.buttons.element(boundBy: $0).label })")
        XCTAssertTrue(shown, "4: the system's colour picker")
        closePicker(app)
        XCTAssertTrue(waitUntil(timeout: 10) { !pickerShown() }, "4: the picker closed")
        XCTAssertTrue(waitUntil(timeout: 5) { dot0.label == "茶" && dot0.isSelected }, "4: the dots as they were")
        XCTAssertEqual(toolColor(canvas), Self.brown, "4: nothing chosen")
        let settings = app.buttons["設定"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "4: the header's 「設定」")
        settings.tap()
        let done = app.buttons["完了"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "4: the settings opened after the picker (sheetIsUp went back to false)")
        log("4: the settings opened after the picker")
        done.tap()
        XCTAssertTrue(waitUntil(timeout: 10) { !done.exists }, "4: the settings closed")

        // 5. 「最初の色に戻す」.
        dot0.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "5: open")
        app.buttons["toolbar.colorPanel.reset"].tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "5: closed")
        XCTAssertTrue(waitUntil(timeout: 5) { dot0.label == "黒" && dot0.isSelected && self.toolColor(canvas) == Self.black },
                      "5: dot 1 黒 again, the tool 黒 (\(dot0.label), \(probeTool(canvas)))")
        log("5: reset; dot 1 \(dot0.label), tool \(probeTool(canvas))")

        // 6. Open, then a finger's line on the paper: closed, and the line written in 黒.
        let before = probeInk(canvas)
        let paper = canvas.frame
        dot0.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "6: open")
        drag(app, from: CGPoint(x: paper.minX + paper.width * 0.25, y: paper.minY + paper.height * 0.3),
             to: CGPoint(x: paper.minX + paper.width * 0.6, y: paper.minY + paper.height * 0.32))
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "6: the line closed the panel")
        XCTAssertTrue(waitUntil(timeout: 8) { self.probeInk(canvas) == before + 1 },
                      "6: the line was written (ink \(before) → \(probeInk(canvas)))")
        XCTAssertEqual(toolColor(canvas), Self.black, "6: in the colour it had")
        log("6: ink \(before) → \(probeInk(canvas)); tool \(probeTool(canvas))")

        // 7. Open, a tap on dot 2 (not lit): closed, 青 chosen.
        dot0.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "7: open")
        tap(app, at: CGPoint(x: dot1Frame.midX, y: dot1Frame.midY))
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "7: a tap on dot 2 closed it")
        XCTAssertTrue(waitUntil(timeout: 5) { dot1.isSelected && self.toolColor(canvas) == Self.blue }, "7: 青 chosen (\(probeTool(canvas)))")
        log("7: dot 2 selected=\(dot1.isSelected); tool \(probeTool(canvas))")

        // 8. Open on 青, then the row dragged from the lit dot: the dot moves, the panel closes.
        let lit = dot1.frame
        dot1.tap()
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5), "8: open on dot 2")
        drag(app, from: CGPoint(x: lit.midX, y: lit.midY), to: CGPoint(x: max(app.windows.firstMatch.frame.minX + 20, lit.midX - 140), y: lit.midY))
        XCTAssertTrue(waitUntil(timeout: 5) { !self.panel(app).exists }, "8: the row moved under the panel's dot: closed")
        log("8: dot 2 \(text(lit)) → \(text(dot1.frame)); panel \(panel(app).exists ? "open" : "closed")")

        // Back to 黒 for the next test (toolbar.penColor is the simulator's).
        reveal(dot0, in: app)
        if !dot0.isSelected { dot0.tap() }
        XCTAssertTrue(waitUntil(timeout: 5) { dot0.isSelected }, "黒 again")
    }

    // MARK: - Steps

    private func dot(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        app.buttons["toolbar.swatch.\(index)"]
    }

    private func panel(_ app: XCUIApplication) -> XCUIElement {
        element(app, Self.panelId)
    }

    /// The system picker's close: its × (「閉じる」 / "Close" / 「完了」 / "Done"), else the sheet dragged down.
    private func closePicker(_ app: XCUIApplication) {
        for label in ["閉じる", "Close", "完了", "Done"] where app.buttons[label].exists {
            log("4: the picker's 「\(label)」")
            app.buttons[label].tap()
            return
        }
        let window = app.windows.firstMatch.frame
        log("4: the picker's sheet dragged down")
        drag(app, from: CGPoint(x: window.midX, y: window.minY + window.height * 0.12), to: CGPoint(x: window.midX, y: window.maxY - 40))
    }

    /// Drags the bar's row (slowly, held before the lift) until `button` lies in its visible part, left of 「しまう」 and its fade
    /// (EraserAndBelowDayUITests' way), at most 4 times.
    private func reveal(_ button: XCUIElement, in app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame
        let collapse = app.buttons["ツールバーをしまう"]
        for attempt in 1...4 {
            guard button.exists else { return }
            let right = collapse.exists ? collapse.frame.minX - 18 : screen.maxX - 28
            let left = screen.minX + 16
            let frame = button.frame
            if button.isHittable, frame.minX >= left, frame.maxX <= right { return }
            let dx = frame.maxX > right ? -min(frame.maxX - right + 24, screen.width * 0.5) : min(left - frame.minX + 24, screen.width * 0.5)
            let startX = dx < 0 ? screen.minX + screen.width * 0.6 : screen.minX + screen.width * 0.2
            drag(app, from: CGPoint(x: startX, y: frame.midY), to: CGPoint(x: startX + dx, y: frame.midY))
            log("moved the row by \(dx) pt for \(button.identifier) (attempt \(attempt), it was at \(text(frame)))")
        }
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The canvas's probe read the same twice, 0.5 s apart (at most 15 s).
    private func settle(_ canvas: XCUIElement) {
        var last = ""
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let now = "\(canvas.value as? String ?? "")|\(canvas.frame)"
            if now == last, !now.hasPrefix("|") { return }
            last = now
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func probe(_ canvas: XCUIElement) -> [String: String] {
        var values: [String: String] = [:]
        for part in (canvas.value as? String ?? "").split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        return values
    }

    /// `pen:#1f2937:3.5` (the canvas's `tool=`).
    private func probeTool(_ canvas: XCUIElement) -> String {
        probe(canvas)["tool"] ?? "-"
    }

    /// The tool's colour (its width is the simulator's remembered one).
    private func toolColor(_ canvas: XCUIElement) -> String {
        let parts = probeTool(canvas).split(separator: ":")
        return parts.count == 3 && parts[0] == "pen" ? String(parts[1]) : "-"
    }

    private func probeInk(_ canvas: XCUIElement) -> Int {
        Int(probe(canvas)["ink"] ?? "") ?? -1
    }

    private func tap(_ app: XCUIApplication, at point: CGPoint) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
    }

    /// One finger from `from` to `to` (screen points), 0.05 s still, then 0.3 s still at the end.
    private func drag(_ app: XCUIApplication, from: CGPoint, to: CGPoint) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: from.x, dy: from.y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: to.x, dy: to.y)),
                   withVelocity: XCUIGestureVelocity(rawValue: 300), thenHoldForDuration: 0.3)
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
