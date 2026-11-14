import UIKit
import XCTest

/// 1.3 (docs/M7C_CONTRACT.md §10.3; the wave plan §3.3, §7.5): 1.2.3's UI tests of the day page run again with
/// `--screenshot-span on`, so the same touches go through the joined path (the day page is a window of days side by
/// side on one canvas, B-1) instead of the one page. Each child only puts `["--screenshot-span", "on"]` after its
/// parent's launch arguments (`extraArguments`) and runs the parent's test bodies as they are; every test is listed here
/// so it is plain which run and which skip.
///
/// - `EraserAndBelowDaySpanRerunUITests`: the four day tests (B0–B3: the 予定 tool, the lasso and the preselected
///   strokes below and above 24:00). The parent maps a page's lu to the screen through `span.state`'s `origin=`, read
///   once after its canvas settled (the lead's decision C3-m10), and fails when the screen never joins. Its four month
///   tests (A1–A4) skip: the month page is one page whether the setting is on or off, so they would run 1.2.3's path a
///   second time and nothing new.
/// - `YearTapSpanRerunUITests`: all five. The year page is one page; the tap opens the day on the joined path (the
///   title and 「前の日」 are the same there), which each test then reads from `span.state` (after a landscape parent
///   with the open finding UI-1, `turnFinding`).
/// - `HeaderAndPaperUITests` has no child: its three tests are the month and the year, one page either way.
///
/// The crossing demo `--screenshot-span on` adds lies outside the parents' rectangles (the day's crossing strokes stay
/// within 252 lu of the left boundary, the parents' marks are at x ≥ 270 lu; `ScreenshotModeSpanTests` pins it).
/// XCUITest has no two-finger gesture, so the joined path's two-finger moves stay with the owner's TestFlight check
/// (§11.3 12, 13). The steps are the `span UI:` lines and the parents' own.
@MainActor
final class EraserAndBelowDaySpanRerunUITests: EraserAndBelowDayUITests {
    override class var extraArguments: [String] { ["--screenshot-span", "on"] }

    private static let monthSkip = "the month page is one page with --screenshot-span on as well (1.3 joins the week and the day only): EraserAndBelowDayUITests runs it"

    // MARK: The day page, joined (B0–B3)

    override func testEventToolBelow24ShowsTheNotice() throws {
        spanRerunLog("B0 event tool on the joined day")
        try super.testEventToolBelow24ShowsTheNotice()
    }

    override func testLassoAroundHandwritingBelow24ShowsTheNotice() throws {
        spanRerunLog("B1 lasso on the joined day")
        try super.testLassoAroundHandwritingBelow24ShowsTheNotice()
    }

    override func testPreselectedHandwritingBelow24ShowsTheNotice() throws {
        spanRerunLog("B2 preselected below 24:00 on the joined day")
        try super.testPreselectedHandwritingBelow24ShowsTheNotice()
    }

    override func testPreselectedHandwritingAbove24OpensTheCreateSheet() throws {
        spanRerunLog("B3 preselected above 24:00 on the joined day")
        try super.testPreselectedHandwritingAbove24OpensTheCreateSheet()
    }

    // MARK: The month page, one page either way (A1–A4)

    override func testToolbarEraserReturnsToTheRedThickPenAfterErasingALine() throws {
        throw XCTSkip(Self.monthSkip)
    }

    override func testToolbarEraserReturnsToThePenWhenItStartsOnTheLine() throws {
        throw XCTSkip(Self.monthSkip)
    }

    override func testEraserChosenFromTheFoldedToolbarReturnsToThePen() throws {
        throw XCTSkip(Self.monthSkip)
    }

    override func testTouchingAgainRightAfterErasingStillEndsOnThePen() throws {
        throw XCTSkip(Self.monthSkip)
    }
}

@MainActor
final class YearTapSpanRerunUITests: YearTapUITests {
    override class var extraArguments: [String] { ["--screenshot-span", "on"] }

    override func testSingleFingerTapOnAYearCellOpensTheDayInPortrait() throws {
        try rerun("finger=on portrait single") { try super.testSingleFingerTapOnAYearCellOpensTheDayInPortrait() }
    }

    override func testDoubleFingerTapOnAYearCellOpensTheDayInPortrait() throws {
        try rerun("finger=on portrait double") { try super.testDoubleFingerTapOnAYearCellOpensTheDayInPortrait() }
    }

    override func testSingleFingerTapOpensTheDayWithFingerDrawingOff() throws {
        try rerun("finger=off portrait single") { try super.testSingleFingerTapOpensTheDayWithFingerDrawingOff() }
    }

    override func testSingleFingerTapOnAYearCellOpensTheDayInLandscape() throws {
        try rerun("finger=on landscape single", turnedBack: true) { try super.testSingleFingerTapOnAYearCellOpensTheDayInLandscape() }
    }

    override func testDoubleFingerTapOnAYearCellOpensTheDayInLandscape() throws {
        try rerun("finger=on landscape double", turnedBack: true) { try super.testDoubleFingerTapOnAYearCellOpensTheDayInLandscape() }
    }

    /// The finding of run 43595078492 (C-ui, for the lead): on the iPhone's joined day page, turning the device from
    /// landscape back to portrait moved the focus two days back (3/16 → 3/14 in both landscape reruns: `span.state`
    /// `focus=d-2026-03-14;first=d-2026-03-12;shifts=1;stops=2`, same session; the portrait reruns stay on 3/16 with
    /// `shifts=0;stops=1`). The parent's title check (3/16) runs before its `defer` turns the device back, so it passes.
    private static let turnFinding = "UI-1: turning the iPhone back to portrait on the joined day page moves the focus (3/16 → 3/14, run 43595078492)"

    /// The parent's test, then (it passed: the day of 3/16 is up) the day it opened is the joined window of 3/16
    /// (`span.state`: `path=span`, `kind=day`, `focus=d-2026-03-16`), so the rerun did go from the one page of the year to
    /// the joined path. A parent that failed or skipped has stopped the test before. After a landscape parent, which
    /// turns the device back to portrait as it ends, the focus is read as an expected failure (not strict) while the
    /// finding `turnFinding` is open: the log still shows it, and nothing fails once it is fixed.
    private func rerun(_ name: String, turnedBack: Bool = false, _ parent: () throws -> Void) throws {
        spanRerunLog("year tap \(name) with --screenshot-span on")
        try parent()
        let state = XCUIApplication().descendants(matching: .any).matching(identifier: "span.state").firstMatch
        var label = state.exists ? state.label : "-"
        let deadline = Date().addingTimeInterval(10)
        while !label.hasPrefix("path=span;"), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            label = state.exists ? state.label : "-"
        }
        spanRerunLog("year tap \(name): after the tap span.state \(label)")
        XCTAssertTrue(label.hasPrefix("path=span;"), "\(name): the day page the tap opened is on the joined path (\(label))")
        XCTAssertTrue(label.contains(";kind=day;"), "\(name): a day window (\(label))")
        if turnedBack, !label.contains(";focus=d-2026-03-16;") {
            spanRerunLog("year tap \(name): \(Self.turnFinding)")
            XCTExpectFailure(Self.turnFinding, strict: false)
        }
        XCTAssertTrue(label.contains(";focus=d-2026-03-16;"), "\(name): its focus is 3/16 (\(label))")
    }
}

/// The children's own lines (the parents log with their own marks).
private func spanRerunLog(_ line: String) {
    print("span UI: rerun: \(line)")
    NSLog("span UI: rerun: %@", line)
}
