import XCTest

/// The way to switch the week start on the real screen (docs/M7B_CONTRACT.md §10.4, §10.7, §10.8), in
/// screenshot mode, where nothing is stored: the settings open with the question, its sentence says the
/// handwriting is not deleted, and after 〔日曜にする〕 the month's heading starts on Sunday. **This is
/// no proof of the saving**: that is `CalendarRootScreenTests.testSwitchSavesTheOldPageFirst` and
/// `SyncEngineTests.testSwitchKeepsBothForms`. The steps are the `week-start UI:` lines.
@MainActor
final class WeekStartUITests: XCTestCase {
    func testSwitchShowsTheSentenceAndChangesTheHeader() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", "week-start",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ]
        app.launch()
        defer { app.terminate() }

        let confirm = app.buttons["日曜にする"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30), "the question's button")
        let sentence = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "週のページは、月曜始まりと日曜始まりで別のページになります。")).firstMatch
        XCTAssertTrue(sentence.exists, "the question's sentence")
        XCTAssertTrue(sentence.label.contains("月曜始まりに戻すまで見えません（消えません）"), sentence.label)
        log("the sentence: \(sentence.label)")
        confirm.tap()

        let done = app.buttons["完了"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the settings are still up")
        done.tap()

        let state = app.otherElements["l10n.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 20), "l10n.state")
        log("state: \(state.label)")
        XCTAssertTrue(state.label.contains("week=sunday"), state.label)

        // The heading's cells go by their spoken names (§4.2: `monthRow`'s `.accessibilityLabel`), so 土曜日
        // and 日曜日, not the 土 and 日 they show; the header's switch says 日, which this does not match. The
        // one on 土曜日's row. Sunday is now left of Saturday (right of it on a Monday week).
        let saturday = app.staticTexts["土曜日"]
        XCTAssertTrue(saturday.waitForExistence(timeout: 10), "the heading's 土曜日")
        let days = app.staticTexts.matching(NSPredicate(format: "label == %@", "日曜日"))
        var sunday: CGRect?
        for index in 0..<days.count {
            let frame = days.element(boundBy: index).frame
            if abs(frame.midY - saturday.frame.midY) < 2 { sunday = frame }
        }
        log("heading: saturday=\(saturday.frame) sunday=\(String(describing: sunday))")
        guard let sunday else { return XCTFail("the heading's 日曜日") }
        XCTAssertLessThan(sunday.maxX, saturday.frame.minX, "Sunday is the first column")
    }

    private func log(_ line: String) {
        print("week-start UI: \(line)")
        NSLog("week-start UI: %@", line)
    }
}
