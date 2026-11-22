import UIKit
import XCTest

/// 1.1.1 (docs/R1_1_1.md): what the unit tests cannot see on the real screen, on an iPhone (build.yml,
/// "UI tests on an iPhone"): where the header's pieces sit in SwiftUI's rows, whether 「今日」 works there,
/// and the paper of a page with nothing on it in the real paper area. The app runs in its screenshot
/// mode (no onboarding, no EventKit, nothing saved). The steps are the `header-paper UI:` lines.
///
/// 1.4.1 (docs/R1_4_1_CONTRACT.md §3.1–§3.4, §6.2, 0e-2 … 0e-5, 0e-13): rewritten for 1.4.1's header. The narrow rows:
/// 「‹ 今日 ›」 (◀ 今日 ▶) at the free hand's end of the first row with the title right after it, and 等倍 (`header.zoomReset`)
/// at the same end of the second row beside the switch, no taller than the switch (§3.3: the header keeps 1.4's height). The
/// wide row (an iPhone in landscape, 750 pt): ▶ ≤ 等倍 ≤ title ≤ switch ≤ ＋ ≤ ⚙. Each again with `--screenshot-hand left`:
/// the mirror, with ◀ still left of ▶.
@MainActor
final class HeaderAndPaperUITests: XCTestCase {
    private static let todayLabel = "今日"
    private static let addEventLabel = "予定を追加"
    private static let settingsLabel = "設定"
    private static let pickerLabel = "表示の切替"
    private static let zoomResetIdentifier = "header.zoomReset"
    private static let titleIdentifier = "page.title"

    // MARK: Tests

    /// The narrow rows, the right hand: (◀ 今日 ▶) 題名 ＋ ☁ ⚙ over [等倍][日|週|月|年], and 「今日」 works: ▶ twice, then 「今日」
    /// goes back to the month of the demo's today.
    func testTodayLeadsTheNarrowRowInPortrait() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the narrow rows are an iPhone's")
        try checkPortrait(hand: .right)
    }

    /// The same, the left hand: ⚙ ☁ ＋ 題名 (◀ 今日 ▶) over [日|週|月|年][等倍].
    func testTodayLeadsTheNarrowRowInPortraitLeftHanded() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the narrow rows are an iPhone's")
        try checkPortrait(hand: .left)
    }

    /// The wide row (an iPhone in landscape, 750 pt), the right hand: (◀ 今日 ▶) 等倍 題名 [日|週|月|年] ＋ ☁ ⚙.
    func testTodayAndZoomLeadTheWideRowInLandscape() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "an iPad's width depends on the device")
        try checkLandscape(hand: .right)
    }

    /// The same, the left hand: ⚙ ☁ ＋ [日|週|月|年] 題名 等倍 (◀ 今日 ▶).
    func testTodayAndZoomLeadTheWideRowInLandscapeLeftHanded() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "an iPad's width depends on the device")
        try checkLandscape(hand: .left)
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

    // MARK: The checks

    private enum Hand: String {
        case right, left
    }

    /// The header's pieces once 「今日」 is there (the test stops when one is missing).
    private struct Header {
        var window: CGRect
        var previous: CGRect
        var today: CGRect
        var next: CGRect
        var zoom: CGRect
        var title: CGRect
        var titleLabel: String
        var picker: CGRect
        var add: CGRect
        var settings: CGRect
    }

    /// §6.2's narrow rows (the month page, 2026-10).
    private func checkPortrait(hand: Hand) throws {
        continueAfterFailure = false
        let name = "today portrait \(hand.rawValue)"
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "month", "--screenshot-hand", hand.rawValue], name)
        defer { app.terminate() }
        let h = try header(app, name)
        XCTAssertGreaterThan(h.today.width, 20, "\(name): the label is not squeezed (\(h.today))")
        // ◀ 今日 ▶ in this order whatever the hand.
        XCTAssertLessThanOrEqual(h.previous.maxX, h.today.minX + 0.5, "\(name): 「前の月」 is left of 「今日」")
        XCTAssertLessThanOrEqual(h.today.maxX, h.next.minX + 0.5, "\(name): 「今日」 is left of 「次の月」")
        // 等倍 on the second row, at the free hand's end, beside the switch and no taller than it (§3.3).
        XCTAssertGreaterThanOrEqual(h.zoom.minY, h.today.maxY - 0.5, "\(name): 等倍 \(h.zoom) is under 「今日」 \(h.today)")
        XCTAssertLessThanOrEqual(h.zoom.height, h.picker.height + 0.5, "\(name): 等倍 \(h.zoom) is no taller than the switch \(h.picker)")
        switch hand {
        case .right:
            XCTAssertLessThanOrEqual(h.next.maxX, h.title.minX + 0.5, "\(name): the title is right of 「次の月」")
            XCTAssertLessThanOrEqual(h.title.minX, h.next.maxX + 8, "\(name): the title right after 「次の月」")
            XCTAssertLessThanOrEqual(h.title.maxX, h.add.minX + 0.5, "\(name): the title is left of 「予定を追加」")
            XCTAssertLessThanOrEqual(h.zoom.minX, h.window.minX + 13, "\(name): 等倍 at the left end")
            XCTAssertLessThanOrEqual(h.zoom.maxX, h.picker.minX + 0.5, "\(name): 等倍 is left of the switch")
        case .left:
            XCTAssertLessThanOrEqual(h.title.maxX, h.previous.minX + 0.5, "\(name): the title is left of 「前の月」")
            XCTAssertGreaterThanOrEqual(h.title.maxX, h.previous.minX - 8, "\(name): the title right before 「前の月」")
            XCTAssertLessThanOrEqual(h.add.maxX, h.title.minX + 0.5, "\(name): 「予定を追加」 is left of the title")
            XCTAssertGreaterThanOrEqual(h.zoom.maxX, h.window.maxX - 13, "\(name): 等倍 at the right end")
            XCTAssertLessThanOrEqual(h.picker.maxX, h.zoom.minX + 0.5, "\(name): the switch is left of 等倍")
        }

        // 「今日」 works: ▶ twice, then back.
        XCTAssertEqual(h.titleLabel, "2026年10月", "\(name): the first title")
        let next = app.buttons["次の月"]
        let today = app.buttons[Self.todayLabel]
        next.tap()
        XCTAssertTrue(app.staticTexts["2026年11月"].waitForExistence(timeout: 5), "\(name): ▶ once")
        next.tap()
        XCTAssertTrue(app.staticTexts["2026年12月"].waitForExistence(timeout: 5), "\(name): ▶ twice")
        today.tap()
        XCTAssertTrue(app.staticTexts["2026年10月"].waitForExistence(timeout: 5), "\(name): 「今日」 goes back")
        log("\(name): OK")
    }

    /// §6.2's wide row (the month page, 2026-10, in landscape).
    private func checkLandscape(hand: Hand) throws {
        continueAfterFailure = false
        let name = "today landscape \(hand.rawValue)"
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "month", "--screenshot-hand", hand.rawValue], name)
        defer { app.terminate() }
        let h = try header(app, name)
        XCTAssertGreaterThan(h.today.width, 20, "\(name): the label is not squeezed (\(h.today))")
        XCTAssertLessThan(h.picker.minY, h.today.maxY, "\(name): one row (switch \(h.picker), 「今日」 \(h.today))")
        XCTAssertLessThanOrEqual(h.previous.maxX, h.today.minX + 0.5, "\(name): 「前の月」 is left of 「今日」")
        XCTAssertLessThanOrEqual(h.today.maxX, h.next.minX + 0.5, "\(name): 「今日」 is left of 「次の月」")
        // The row from left to right (each piece's maxX ≤ the next one's minX).
        let row: [(String, CGRect)]
        switch hand {
        case .right:
            row = [("次の月", h.next), ("等倍", h.zoom), ("title", h.title), ("switch", h.picker), ("予定を追加", h.add), ("設定", h.settings)]
            XCTAssertLessThanOrEqual(h.title.minX, h.zoom.maxX + 6.5, "\(name): the title right after 等倍")
        case .left:
            row = [("設定", h.settings), ("予定を追加", h.add), ("switch", h.picker), ("title", h.title), ("等倍", h.zoom), ("前の月", h.previous)]
            XCTAssertGreaterThanOrEqual(h.title.maxX, h.zoom.minX - 6.5, "\(name): the title right before 等倍")
        }
        for (left, right) in zip(row, row.dropFirst()) {
            XCTAssertLessThanOrEqual(left.1.maxX, right.1.minX + 0.5, "\(name): \(left.0) \(left.1) is left of \(right.0) \(right.1)")
        }
        log("\(name): OK")
    }

    /// The frames of the header's pieces, logged; fails (with the element tree) when one is missing. The switch is the
    /// segmented control, else the element named 「表示の切替」, else its first and last segments together.
    private func header(_ app: XCUIApplication, _ name: String) throws -> Header {
        let today = app.buttons[Self.todayLabel]
        guard today.waitForExistence(timeout: 20) else {
            throw failure("\(name): 「今日」. Elements:\n\(app.debugDescription)")
        }
        let previous = app.buttons["前の月"]
        let next = app.buttons["次の月"]
        let zoom = app.buttons.matching(identifier: Self.zoomResetIdentifier).firstMatch
        let add = app.buttons[Self.addEventLabel]
        let settings = app.buttons[Self.settingsLabel]
        let title = app.descendants(matching: .any).matching(identifier: Self.titleIdentifier).firstMatch
        for (element, label) in [(previous, "前の月"), (next, "次の月"), (zoom, Self.zoomResetIdentifier), (add, Self.addEventLabel),
                                 (settings, Self.settingsLabel), (title, Self.titleIdentifier)] where !element.exists {
            throw failure("\(name): 「\(label)」. Elements:\n\(app.debugDescription)")
        }
        guard let picker = switchFrame(app) else {
            throw failure("\(name): the switch. Elements:\n\(app.debugDescription)")
        }
        let h = Header(window: app.windows.firstMatch.frame, previous: previous.frame, today: today.frame, next: next.frame,
                       zoom: zoom.frame, title: title.frame, titleLabel: title.label, picker: picker.frame, add: add.frame,
                       settings: settings.frame)
        log("\(name): window=\(h.window) previous=\(h.previous) today=\(h.today) next=\(h.next) zoom=\(h.zoom) "
            + "title=\(h.title) \"\(h.titleLabel)\" switch=\(picker.how) \(h.picker) add=\(h.add) settings=\(h.settings)")
        return h
    }

    private func switchFrame(_ app: XCUIApplication) -> (frame: CGRect, how: String)? {
        let segmented = app.segmentedControls.firstMatch
        if segmented.exists { return (segmented.frame, "segmented") }
        let named = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.pickerLabel)).firstMatch
        if named.exists { return (named.frame, "named") }
        let day = app.buttons.matching(NSPredicate(format: "label IN %@", ["日表示", "日"])).firstMatch
        let year = app.buttons.matching(NSPredicate(format: "label IN %@", ["年表示", "年"])).firstMatch
        guard day.exists, year.exists else { return nil }
        return (day.frame.union(year.frame), "segments")
    }

    private func failure(_ message: String) -> Error {
        XCTFail(message)
        return NSError(domain: "HeaderAndPaperUITests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    // MARK: The steps

    private func launch(_ arguments: [String], _ name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"] + arguments
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
