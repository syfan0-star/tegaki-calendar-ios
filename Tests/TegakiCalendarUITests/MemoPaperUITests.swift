import XCTest

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.2, §6.1, 0f-20): 設定 › 「メモ欄の紙」 on the real sheet (ui-tests, iPhone 17), in screenshot
/// mode, where nothing is stored (`MemoPaperSettingsSection.changed`): the row (`settings.memoPaper`) shows 「罫線」, its own
/// screen offers 「罫線」「ドット方眼」「無地」, choosing 「ドット方眼」 puts it in the row, and after 「完了」 the papers were told
/// `dots` (`memo-paper.state`, screenshot mode's invisible element that follows the notice every `PaperView` follows); then back
/// to 「罫線」 the same way, the sheet opened again from the header's 「設定」 showing 「ドット方眼」's choice. **No proof of the
/// pixels**: those are MemoPaperDrawTests and MemoPaperRedrawTests. The steps are the `memo-paper UI:` lines.
///
/// The waits read once more after their deadline (1.4.1's lesson, docs/R1_4_1.md: a condition met just at the deadline is not a
/// failure).
@MainActor
final class MemoPaperUITests: XCTestCase {
    func testTheSettingReachesThePaper() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", "settings",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ]
        app.launch()
        defer { app.terminate() }

        let done = app.buttons["完了"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "the settings sheet")
        let state = element(app, "memo-paper.state")

        XCTAssertTrue(choose(in: app, "ドット方眼", from: "罫線", step: "1 dots"), "罫線 → ドット方眼 in the row")
        done.tap()
        XCTAssertTrue(waitUntil(timeout: 10) { !done.exists }, "完了 closed the settings")
        XCTAssertTrue(state.waitForExistence(timeout: 10), "memo-paper.state")
        let dots = waitUntil(timeout: 5) { state.label == "style=dots" }
        log("after 完了: \(state.label)")
        XCTAssertTrue(dots, "the papers were told dots: \(state.label)")

        let settings = app.buttons["設定"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "the header's 「設定」")
        settings.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the settings sheet opened again")
        XCTAssertTrue(choose(in: app, "罫線", from: "ドット方眼", step: "2 ruled"), "ドット方眼 → 罫線 in the row")
        done.tap()
        XCTAssertTrue(waitUntil(timeout: 10) { !done.exists }, "完了 closed the settings")
        let ruled = waitUntil(timeout: 5) { state.label == "style=ruled" }
        log("after 完了: \(state.label)")
        XCTAssertTrue(ruled, "the papers were told ruled: \(state.label)")
    }

    // MARK: - Steps

    /// The row moved into the sheet (dragged up while below, down while under the sheet's bar), its text holding `current`;
    /// a tap opens its screen, which lists the three; a tap on `choice` and the row holds `choice` (the list goes back by
    /// itself; if not, its back button). False (failed) when a step did not happen.
    private func choose(in app: XCUIApplication, _ choice: String, from current: String, step: String) -> Bool {
        let row = memoRow(app)
        let window = app.windows.firstMatch.frame
        for attempt in 1...12 {
            let above = row.exists && row.frame.minY <= window.minY + 120
            if row.exists, row.isHittable, !above, row.frame.maxY < window.maxY - 80 { break }
            let (a, b): (CGFloat, CGFloat) = above ? (0.45, 0.65) : (0.75, 0.45)
            drag(in: app, from: CGPoint(x: window.midX, y: window.minY + window.height * a),
                 to: CGPoint(x: window.midX, y: window.minY + window.height * b))
            log("\(step): moved the settings \(above ? "down" : "up") (attempt \(attempt)); the row \(row.exists ? "at \(row.frame)" : "not in the tree yet")")
        }
        guard row.exists, row.isHittable else {
            keepScreenshot(app, "\(step) — no row")
            XCTFail("\(step): 「メモ欄の紙」 is not on the settings sheet")
            return false
        }
        log("\(step): the row at \(row.frame): \(text(row))")
        XCTAssertTrue(text(row).contains("メモ欄の紙"), "\(step): the row's title: \(text(row))")
        XCTAssertTrue(text(row).contains(current), "\(step): the row shows \(current): \(text(row))")
        row.tap()

        // Each poll picks the button or the text again: picked once right after the tap, a list not up yet would leave texts.
        let listed = waitUntil(timeout: 10) { ["罫線", "ドット方眼", "無地"].allSatisfy { self.option(app, $0).exists } }
        keepScreenshot(app, "\(step) — the choices")
        XCTAssertTrue(listed, "\(step): the three choices are listed")
        guard listed else { return false }
        option(app, choice).tap()

        let back = waitUntil(timeout: 5) { self.memoRow(app).exists && self.memoRow(app).isHittable }
        if !back {
            // The list's back button carries the sheet's title (the header's 「設定」 is under the sheet).
            log("\(step): the list stayed; its back button 「設定」")
            app.buttons["設定"].tap()
        }
        let shown = waitUntil(timeout: 10) { self.text(self.memoRow(app)).contains(choice) }
        keepScreenshot(app, "\(step) — the row")
        log("\(step): the row now: \(text(memoRow(app)))")
        XCTAssertTrue(shown, "\(step): the row shows \(choice): \(text(memoRow(app)))")
        return shown
    }

    /// The row: the button of its identifier (only buttons: should SwiftUI give the identifier to the cell or a text inside too,
    /// the first match of any type could be one without the value), else the button whose label starts with its title.
    private func memoRow(_ app: XCUIApplication) -> XCUIElement {
        let byId = app.buttons.matching(identifier: "settings.memoPaper").firstMatch
        if byId.exists { return byId }
        return app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "メモ欄の紙")).firstMatch
    }

    /// A choice of the list: a button of that label, else a text of it.
    private func option(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let button = app.buttons[label]
        if button.exists { return button }
        return app.staticTexts[label]
    }

    /// The row's label and value, as VoiceOver reads them.
    private func text(_ element: XCUIElement) -> String {
        guard element.exists else { return "-" }
        return "\(element.label) \((element.value as? String) ?? "")"
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// One finger from `from` to `to` (screen points), 0.05 s still, then 0.3 s still at the end.
    private func drag(in app: XCUIApplication, from: CGPoint, to: CGPoint) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: from.x, dy: from.y))
        let end = origin.withOffset(CGVector(dx: to.x, dy: to.y))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: 600), thenHoldForDuration: 0.3)
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

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func log(_ line: String) {
        print("memo-paper UI: \(line)")
        NSLog("memo-paper UI: %@", line)
    }
}
