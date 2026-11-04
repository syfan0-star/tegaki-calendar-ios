import UIKit
import XCTest

/// 1.1.1 (docs/R1_1_1.md): what the unit tests cannot see on the real screen, on an iPhone (build.yml,
/// "UI tests on an iPhone"): where 「今日」 sits in SwiftUI's row of the header, whether it works there,
/// and the paper of a page with nothing on it in the real paper area. The app runs in its screenshot
/// mode (no onboarding, no EventKit, nothing saved). The steps are the `header-paper UI:` lines.
@MainActor
final class HeaderAndPaperUITests: XCTestCase {
    private static let todayLabel = "今日"
    private static let addEventLabel = "予定を追加"

    // MARK: Tests

    /// The narrow row: ◀ ▶ 題名 今日 ＋ ☁ ⚙. 「今日」 is right of ▶ and left of ＋, and it works: ▶ twice,
    /// then 「今日」 goes back to the month of the demo's today.
    func testTodayIsRightOfTheTitleInPortrait() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the narrow row is an iPhone's")
        continueAfterFailure = false
        let name = "today portrait"
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "month"], name)
        defer { app.terminate() }
        let next = app.buttons["次の月"]
        let today = app.buttons[Self.todayLabel]
        let add = app.buttons[Self.addEventLabel]
        XCTAssertTrue(today.waitForExistence(timeout: 20), "\(name): 「今日」")
        XCTAssertTrue(next.exists, "\(name): 「次の月」")
        XCTAssertTrue(add.exists, "\(name): 「予定を追加」")
        log("\(name): window=\(app.windows.firstMatch.frame) next=\(next.frame) today=\(today.frame) add=\(add.frame)")
        XCTAssertGreaterThan(today.frame.width, 20, "\(name): the label is not squeezed (\(today.frame))")
        XCTAssertLessThanOrEqual(next.frame.maxX, today.frame.minX + 0.5, "\(name): 「次の月」 is left of 「今日」")
        XCTAssertLessThanOrEqual(today.frame.maxX, add.frame.minX + 0.5, "\(name): 「今日」 is left of 「予定を追加」")

        let title = app.staticTexts.matching(NSPredicate(format: "label == %@", "2026年10月")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "\(name): the first title")
        log("\(name): title=\(title.frame)")
        XCTAssertLessThanOrEqual(title.frame.maxX, today.frame.minX + 0.5, "\(name): the title is left of 「今日」")
        next.tap()
        XCTAssertTrue(app.staticTexts["2026年11月"].waitForExistence(timeout: 5), "\(name): ▶ once")
        next.tap()
        XCTAssertTrue(app.staticTexts["2026年12月"].waitForExistence(timeout: 5), "\(name): ▶ twice")
        today.tap()
        XCTAssertTrue(app.staticTexts["2026年10月"].waitForExistence(timeout: 5), "\(name): 「今日」 goes back")
        log("\(name): OK")
    }

    /// The wide row (an iPhone in landscape, 750 pt): ◀ ▶ 題名 [日|週|月|年] 今日 ＋ ☁ ⚙. The switch by its
    /// kind, or failing that by its last segment's label (no run has shown what the system calls them, so
    /// the log says); 年 is the last segment, so both end where the switch ends.
    func testTodayIsRightOfTheSwitchInLandscape() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "an iPad's width depends on the device")
        continueAfterFailure = false
        let name = "today landscape"
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "month"], name)
        defer { app.terminate() }
        let segmented = app.segmentedControls.firstMatch
        let yearSegment = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["年表示", "年"])).firstMatch
        let today = app.buttons[Self.todayLabel]
        let add = app.buttons[Self.addEventLabel]
        XCTAssertTrue(today.waitForExistence(timeout: 20), "\(name): 「今日」")
        let picker = segmented.exists ? segmented : yearSegment
        XCTAssertTrue(picker.exists, "\(name): the switch. Elements:\n\(app.debugDescription)")
        XCTAssertTrue(add.exists, "\(name): 「予定を追加」")
        log("\(name): window=\(app.windows.firstMatch.frame) segmented=\(segmented.exists) switch=\(picker.label) \(picker.frame) today=\(today.frame) add=\(add.frame)")
        XCTAssertGreaterThan(today.frame.width, 20, "\(name): the label is not squeezed (\(today.frame))")
        XCTAssertLessThanOrEqual(picker.frame.maxX, today.frame.minX + 0.5, "\(name): the switch is left of 「今日」")
        XCTAssertLessThanOrEqual(today.frame.maxX, add.frame.minX + 0.5, "\(name): 「今日」 is left of 「予定を追加」")
        log("\(name): OK")
    }

    /// Nothing on the page: 2026-12 and 2027 start at the top of the real paper area, in portrait
    /// (before the fix, on an iPhone 17, `oy` −44 and −17). In landscape the year with the demo events
    /// (1,896 lu) and the empty one (1,860 lu) open at the same zoom, that of 1,860 lu in the paper area
    /// (before the fix 0.1097 and 0.1118).
    func testEmptyMonthAndYearStartAtTheTopAtTheSameZoom() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the table of docs/R1_1_1.md §2.2 has the iPad's in blank-paper")
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        for (page, month) in [("month", "2026-12"), ("year", "2027-01")] {
            let name = "empty \(page)"
            let app = launch(["--screenshot-month", month, "--screenshot-page", page, "--screenshot-empty", "--screenshot-probe"], name)
            defer { app.terminate() }
            guard let probe = settledProbe(in: app, name) else { continue }
            XCTAssertEqual(number("oy", probe.values) ?? -999, 0, accuracy: 0.5, "\(name): the paper starts at the top")
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        var zooms: [CGFloat] = []
        var heights: [CGFloat] = []
        for (label, arguments) in [("demo", ["--screenshot-month", "2026-10"]), ("empty", ["--screenshot-month", "2027-01", "--screenshot-empty"])] {
            let name = "landscape \(label) year"
            let app = launch(arguments + ["--screenshot-page", "year", "--screenshot-probe"], name)
            defer { app.terminate() }
            guard let probe = settledProbe(in: app, name) else { continue }
            XCTAssertEqual(number("oy", probe.values) ?? -999, 0, accuracy: 0.5, "\(name): the paper starts at the top")
            zooms.append(number("zoom", probe.values) ?? 0)
            heights.append(probe.frame.height)
        }
        guard zooms.count == 2, heights.count == 2 else { return XCTFail("the two years did not report") }
        XCTAssertEqual(zooms[0], zooms[1], accuracy: 0.0005, "the size does not change from year to year")
        XCTAssertEqual(zooms[1], heights[1] / 1860, accuracy: 0.001, "the opening zoom is that of 1,860 lu in the paper area")
    }

    // MARK: The steps

    private func launch(_ arguments: [String], _ name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"] + arguments
        app.launch()
        log("\(name): launched \(arguments.joined(separator: " "))")
        return app
    }

    /// The canvas's probe once it has a zoom and two reads 0.4 s apart agree (`BlankPaperShotsUITests`).
    private func settledProbe(in app: XCUIApplication, _ name: String, timeout: TimeInterval = 15) -> (values: [String: String], frame: CGRect)? {
        let canvas = app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
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
                        log("\(name): frame=\(canvas.frame) zoom=\(values["zoom"] ?? "?") ox=\(values["ox"] ?? "?") oy=\(values["oy"] ?? "?") ph=\(values["ph"] ?? "?")")
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
        print("header-paper UI: \(line)")
        NSLog("header-paper UI: %@", line)
    }
}
