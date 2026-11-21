import UIKit
import XCTest

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §4.3–§4.11, §6.1, §6.6, §9.1 D1b, 0e-14–0e-23): the open toolbar moved with a finger on its
/// grip, on the real screen of a 13-inch iPad — what the unit tests cannot see: UIKit's pan on `PaletteGripView` reaching the
/// screen, the snap to an edge, the slots laid out anew and the canvas taking the new paper area. Its lines are `palette UI:`.
///
/// - `testTheGripMovesTheBarToEveryEdge` (iPad; build.yml's blank-paper job, its step "Palette UI tests on the 13-inch iPad
///   (1.4.1)", which passes TEST_RUNNER_TEGAKI_PALETTE_UI=1 — skipped everywhere else, so ui-tests and blank-paper's photos do
///   not change; gate 1 of D1b reads that step). The week (one page) at the opening zoom, 「指でも書く」 on. The grip
///   (`toolbar.grip`, read out as 「ツールバーを動かす」) is dragged slowly and held before the lift (no flick): to the right
///   edge — `tool.pen` in the right 80 pt and 「マーカー」 under it (the upright bar) —, ↶ then takes back a stroke written
///   before the move; to the top — 「ペン」 above the sticky heading —; to the left; to the bottom — 「ペン」's top − 16 is the
///   canvas's bottom again, as on every iPhone (YearTapUITests; the bar's 8 pt over the grip's 8). Each drop changes the
///   paper area exactly once (`palette.state`'s `areas`, the count of the `toolbar: paperArea=` lines). The app runs in
///   screenshot mode (`--screenshot-palette bottom`, which also shows `palette.state`), where a drop moves the bar through the
///   screen's `@State` and never writes `toolbar.paletteEdge` (§4.10).
/// - `testThePhoneKeepsTheBottomBar` (iPhone; ui-tests): asked for the left edge, an iPhone keeps 1.4's bar at the bottom with
///   no grip (§4.3, 確かめ表 18), 「ペン」's top − 16 the canvas's bottom.
///
/// Not here (the contract's §6.1 note, form (b), and what XCUITest cannot do): the Apple Pencil never moving the bar (XCUITest
/// synthesizes finger touches only: PaletteGripTests checks the pan's touch types and its palm rule); VoiceOver's 「…へ移す」
/// (XCUITest has no call for a custom action: ScreenshotModeHandPaletteTests checks the actions' list and names, and the drop
/// they share); the edge kept over a relaunch (screenshot mode keeps it in memory only: AppSettingsTests, HandSettingTests
/// and ScreenshotModeHandPaletteTests check the store).
@MainActor
final class PaletteMoveUITests: XCTestCase {
    private static let gripIdentifier = "toolbar.grip"
    private static let stateIdentifier = "palette.state"
    private static let gripLabel = "ツールバーを動かす"
    private static let penLabel = "ペン"
    private static let markerLabel = "マーカー"
    private static let undoLabel = "元に戻す"
    private static let dayColumnSuffix = "（日表示へ）"
    /// `tool.pen` lies within this many points of the window's side on a side edge (§6.1).
    private static let sideBand: CGFloat = 80

    // MARK: Tests

    func testTheGripMovesTheBarToEveryEdge() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TEGAKI_PALETTE_UI"] == "1",
                          "only in blank-paper's step \"Palette UI tests on the 13-inch iPad (1.4.1)\"")
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "the grip is an iPad's")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["--screenshot-page", "week", "--screenshot-span", "off", "--screenshot-palette", "bottom",
                          "-allowFingerDrawing", "YES", "-allowFingerDrawingChosen", "YES"])
        defer { app.terminate() }

        guard let start = waitForState(app, "launch", timeout: 30, { $0["allowed"] == "bottom,top,left,right" && $0["grip"] == "on" }) else {
            XCTFail("the 13-inch iPad never allowed the four edges with a grip: \(stateLabel(app))")
            return
        }
        log("launch: window=\(text(window(app))) state=\(stateLabel(app))")
        XCTAssertEqual(start["edge"], "bottom")
        guard let opened = settledProbe(app, "launch") else { return }
        let grip = element(app, Self.gripIdentifier)
        XCTAssertTrue(grip.waitForExistence(timeout: 10), "the grip")
        XCTAssertEqual(grip.label, Self.gripLabel, "the grip is read out as one element 「ツールバーを動かす」")
        log("grip: frame=\(text(grip.frame)) label=\(grip.label)")
        checkBottom(app, "launch", canvas: opened.frame)
        keepScreenshot(app, "bottom at launch")

        // A stroke for ↶ to take back after a move.
        let inkBefore = Int(opened.values["ink"] ?? "") ?? -1
        let canvas = opened.frame
        drag(app, from: CGPoint(x: canvas.minX + canvas.width * 0.3, y: canvas.minY + canvas.height * 0.45),
             to: CGPoint(x: canvas.minX + canvas.width * 0.55, y: canvas.minY + canvas.height * 0.5), velocity: 300)
        let written = waitForProbe(app, "the stroke", timeout: 8) { (Int($0.values["ink"] ?? "") ?? -1) == inkBefore + 1 }
        XCTAssertNotNil(written, "a finger wrote one stroke (ink \(inkBefore) → \(probe(app)?.values["ink"] ?? "?"))")

        let screen = window(app)
        // Right: the upright bar along the right side.
        move(app, to: CGPoint(x: screen.maxX - 24, y: screen.midY), expect: "right")
        let pen = app.buttons[Self.penLabel]
        let marker = app.buttons[Self.markerLabel]
        let penRight = stableFrame(pen)
        let markerRight = stableFrame(marker)
        log("right: pen=\(text(penRight)) marker=\(text(markerRight))")
        XCTAssertGreaterThanOrEqual(penRight.minX, screen.maxX - Self.sideBand, "right: 「ペン」 in the right \(Self.sideBand) pt")
        XCTAssertLessThanOrEqual(penRight.maxX, screen.maxX, "right: 「ペン」 on the screen")
        XCTAssertGreaterThanOrEqual(markerRight.minY, penRight.maxY - 0.5, "right: 「マーカー」 under 「ペン」 (upright)")
        XCTAssertEqual(markerRight.midX, penRight.midX, accuracy: 1, "right: 「マーカー」 and 「ペン」 in one column")
        keepScreenshot(app, "right")

        // ↶ on the moved bar still takes back the stroke.
        let undo = app.buttons[Self.undoLabel]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "right: ↶ on the upright bar")
        log("right: ↶ frame=\(text(undo.frame)) hittable=\(undo.isHittable)")
        undo.tap()
        let undone = waitForProbe(app, "↶", timeout: 8) { (Int($0.values["ink"] ?? "") ?? -1) == inkBefore }
        XCTAssertNotNil(undone, "right: ↶ took the stroke back (ink \(probe(app)?.values["ink"] ?? "?"), \(inkBefore) expected)")

        // Top: the bar between the notices and the sticky heading.
        move(app, to: CGPoint(x: screen.midX, y: screen.minY + screen.height * 0.1), expect: "top")
        let penTop = stableFrame(pen)
        let heading = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", Self.dayColumnSuffix)).firstMatch
        let headingFrame = heading.exists ? stableFrame(heading) : .null
        log("top: pen=\(text(penTop)) heading=\(text(headingFrame))")
        XCTAssertTrue(heading.exists, "top: a day of the sticky heading")
        XCTAssertLessThan(penTop.minY, headingFrame.minY, "top: 「ペン」 above the sticky heading")
        keepScreenshot(app, "top")

        // Left: the upright bar along the left side.
        move(app, to: CGPoint(x: screen.minX + 24, y: screen.midY), expect: "left")
        let penLeft = stableFrame(pen)
        let markerLeft = stableFrame(marker)
        log("left: pen=\(text(penLeft)) marker=\(text(markerLeft))")
        XCTAssertLessThanOrEqual(penLeft.maxX, screen.minX + Self.sideBand, "left: 「ペン」 in the left \(Self.sideBand) pt")
        XCTAssertGreaterThanOrEqual(markerLeft.minY, penLeft.maxY - 0.5, "left: 「マーカー」 under 「ペン」 (upright)")
        keepScreenshot(app, "left")

        // Bottom again: 1.4's place, the canvas's bottom 16 pt above 「ペン」.
        move(app, to: CGPoint(x: screen.midX, y: screen.maxY - 24), expect: "bottom")
        guard let back = settledProbe(app, "bottom") else { return }
        checkBottom(app, "bottom", canvas: back.frame)
        keepScreenshot(app, "bottom again")
        log("the Apple Pencil: not synthesized by XCUITest (PaletteGripTests checks the pan's touch types and the palm rule)")
        log("OK")
    }

    func testThePhoneKeepsTheBottomBar() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "ui-tests runs on an iPhone")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["--screenshot-page", "week", "--screenshot-span", "off", "--screenshot-palette", "left"])
        defer { app.terminate() }
        let state = waitForState(app, "phone", timeout: 30) { $0["edge"] != nil }
        log("phone: window=\(text(window(app))) state=\(stateLabel(app))")
        XCTAssertEqual(state?["edge"], "bottom", "an iPhone keeps the bottom, whatever it is asked")
        XCTAssertEqual(state?["stored"], "left", "the asked edge is kept, not shown")
        XCTAssertEqual(state?["allowed"], "bottom")
        XCTAssertEqual(state?["grip"], "off")
        XCTAssertFalse(element(app, Self.gripIdentifier).exists, "no grip on an iPhone")
        guard let opened = settledProbe(app, "phone") else { return }
        checkBottom(app, "phone", canvas: opened.frame)
        keepScreenshot(app, "phone")
        log("phone: OK")
    }

    // MARK: The steps

    /// Drags the grip slowly to `point` (the window's points) and holds it there before the lift, so the snap reads no flick;
    /// then waits for `palette.state` to read `edge=<expect>` and checks the paper area changed exactly once.
    private func move(_ app: XCUIApplication, to point: CGPoint, expect: String) {
        let before = fields(stateLabel(app))
        let areas = Int(before["areas"] ?? "") ?? -1
        let grip = element(app, Self.gripIdentifier)
        XCTAssertTrue(grip.waitForExistence(timeout: 5), "\(expect): the grip before the move")
        let from = stableFrame(grip)
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: from.midX, dy: from.midY))
        let end = origin.withOffset(CGVector(dx: point.x, dy: point.y))
        let started = Date()
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: 500), thenHoldForDuration: 0.4)
        let took = Date().timeIntervalSince(started)
        guard let after = waitForState(app, expect, timeout: 10, { $0["edge"] == expect && $0["drag"] == "off" }) else {
            XCTFail("\(expect): the bar did not go to the \(expect) edge (grip \(text(from)) → \(point); \(stateLabel(app)))")
            return
        }
        // The paper area settles on its new size once; read again a moment later so a second change would show.
        Thread.sleep(forTimeInterval: 1.5)
        let settled = fields(stateLabel(app))
        log("\(expect): dragged \(text(from)) → (\(Int(point.x)), \(Int(point.y))) in \(String(format: "%.2f", took)) s; "
            + "state=\(stateLabel(app)) areas \(areas) → \(settled["areas"] ?? "?")")
        XCTAssertEqual(after["stored"], expect, "\(expect): screenshot mode keeps the edge in the screen's state")
        XCTAssertEqual(Int(settled["areas"] ?? "") ?? -1, areas + 1, "\(expect): one drop changes the paper area once (\(stateLabel(app)))")
    }

    /// The bottom bar's rule of 1.4 (YearTapUITests): 「ペン」's top is 16 pt under the canvas's bottom.
    private func checkBottom(_ app: XCUIApplication, _ name: String, canvas: CGRect) {
        let pen = app.buttons[Self.penLabel]
        XCTAssertTrue(pen.waitForExistence(timeout: 5), "\(name): 「ペン」")
        let frame = stableFrame(pen)
        log("\(name): pen=\(text(frame)) canvas=\(text(canvas)) pen.minY − 16 = \(frame.minY - 16)")
        XCTAssertEqual(frame.minY - 16, canvas.maxY, accuracy: 0.5, "\(name): 「ペン」's top − 16 is the canvas's bottom")
    }

    // MARK: Launching and reading the screen

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + arguments
        app.launch()
        log("launched \(arguments.joined(separator: " "))")
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func window(_ app: XCUIApplication) -> CGRect {
        app.windows.firstMatch.frame
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = element(app, Self.stateIdentifier)
        return state.exists ? state.label : "-"
    }

    /// `palette.state`'s fields once `condition` holds, read every 0.3 s; nil (logged) at the timeout.
    private func waitForState(_ app: XCUIApplication, _ what: String, timeout: TimeInterval,
                              _ condition: ([String: String]) -> Bool) -> [String: String]? {
        let state = element(app, Self.stateIdentifier)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if state.exists {
                let read = fields(state.label)
                if condition(read) { return read }
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        log("\(what): palette.state not as expected within \(Int(timeout)) s: \(stateLabel(app))")
        return nil
    }

    /// The canvas's probe (`--screenshot-probe`): its fields and its frame.
    private struct Probe {
        let values: [String: String]
        let frame: CGRect
    }

    private func probe(_ app: XCUIApplication) -> Probe? {
        let canvas = element(app, "ink-canvas")
        guard canvas.exists, let raw = canvas.value as? String else { return nil }
        return Probe(values: fields(raw), frame: canvas.frame)
    }

    /// The probe once it has a zoom and two reads 0.5 s apart agree on the zoom, the offset and the frame; nil (failed) at 30 s.
    private func settledProbe(_ app: XCUIApplication, _ name: String) -> Probe? {
        let deadline = Date().addingTimeInterval(30)
        var last: Probe?
        while Date() < deadline {
            if let now = probe(app), (Double(now.values["zoom"] ?? "") ?? 0) > 0 {
                if let previous = last, previous.frame == now.frame,
                   ["zoom", "ox", "oy"].allSatisfy({ previous.values[$0] == now.values[$0] }) {
                    return now
                }
                last = now
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("\(name): the canvas never settled (\(probe(app).map { "\($0.values)" } ?? "no ink-canvas"))")
        return nil
    }

    /// Polls the probe every 0.2 s until `until` holds; nil (logged) at the timeout.
    private func waitForProbe(_ app: XCUIApplication, _ what: String, timeout: TimeInterval, until: (Probe) -> Bool) -> Probe? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let now = probe(app), until(now) { return now }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        log("\(what): not within \(Int(timeout)) s; probe \(probe(app).map { "\($0.values)" } ?? "-")")
        return nil
    }

    /// The element's frame once two reads 0.4 s apart agree (at most 8 s).
    private func stableFrame(_ element: XCUIElement) -> CGRect {
        var last = element.frame
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.4)
            let now = element.frame
            if now == last, now.width > 0 { return now }
            last = now
        }
        return last
    }

    /// One finger: down at `from` (the window's points), 0.05 s still, to `to` at `velocity` pt/s, 0.2 s still, up.
    private func drag(_ app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: from.x, dy: from.y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: to.x, dy: to.y)),
                   withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: 0.2)
    }

    /// `key=value` pairs joined by `;` (the probe and `palette.state`).
    private func fields(_ raw: String) -> [String: String] {
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        return values
    }

    /// "x,y,w,h" with one decimal.
    private func text(_ rect: CGRect) -> String {
        guard !rect.isNull else { return "-" }
        return [rect.minX, rect.minY, rect.width, rect.height].map { String(format: "%.1f", Double($0)) }.joined(separator: ",")
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "palette UI — \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func log(_ line: String) {
        print("palette UI: \(line)")
        NSLog("palette UI: %@", line)
    }
}
