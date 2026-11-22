import UIKit
import XCTest

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §3.5, §6.1, §6.6, §16.2, 0e-6): the header's wide row measured on the real screen, which no
/// run had done (every room of it was an estimate). It writes one `header room:` line per row with the frames of ◀, 今日, ▶,
/// 等倍 (`header.zoomReset`), the title (`page.title`), the switch, ＋予定, ☁ and ⚙, and the title's room: the space the row
/// leaves the title (its frame takes it whole, `PageHeaderView`). Since §16.2 (plan B) the title starts the right hand's row
/// at its left end, leading, so the room runs from the title's left edge to its right neighbour (the switch on the wide row,
/// ＋ on the compact first row) less one gap; the pieces and gaps are the same as before §16.2, so the rooms are too (± 0.5,
/// the frames XCUI rounds to the pixel). Logs only: the lead reads the gate of D1a from the lines (the ja day title's room ≥
/// 115 pt on the iPad mini, the Air 11 and the Pro 13 in portrait; else the wide row's gap becomes 4 below 760 pt), so the
/// test fails only when the app does not show its header.
///
/// Where it runs: build.yml's blank-paper job on its four devices (`TEST_RUNNER_TEGAKI_SHOT_DEVICE`: ipad13, ipadmini, ipad11
/// = the owner's iPad Air 11-inch, iphone69), and the ui-tests job's iPhone 17. An iPad is measured in portrait (its wide
/// row); an iPhone has two rows in portrait, so it is measured there (the first row, for the record) and then turned to
/// landscape with `XCUIDevice` for its wide row. The day page of 2026-10-07 (screenshot mode's focus day), the right hand.
@MainActor
final class HeaderRoomUITests: XCTestCase {
    private static let todayLabel = "今日"
    private static let pickerLabel = "表示の切替"
    /// The rows' gaps (`PageHeaderView`: the wide row 6, the compact first row 4).
    private static let wideGap: CGFloat = 6
    private static let compactGap: CGFloat = 4

    func testHeaderRoom() throws {
        let env = ProcessInfo.processInfo.environment
        let phone = UIDevice.current.userInterfaceIdiom == .phone
        let device = env["TEGAKI_SHOT_DEVICE"] ?? (phone ? "iphone" : "ipad")
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "day",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons[Self.todayLabel].waitForExistence(timeout: 30), "\(device): the header's 「今日」")
        logRow(app, "\(device) portrait day")
        guard phone else { return }
        XCUIDevice.shared.orientation = .landscapeLeft
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let window = app.windows.firstMatch.frame
            if window.width > window.height { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        Thread.sleep(forTimeInterval: 1)
        logRow(app, "\(device) landscape day")
    }

    /// One `header room:` line: the row (`wide` when the switch is beside 「今日」, else `compact`, the first row), the frames
    /// (pt, the window's coordinates; `-` for a piece not found) and the title's room.
    private func logRow(_ app: XCUIApplication, _ name: String) {
        func frame(_ element: XCUIElement) -> CGRect? { element.exists ? element.frame : nil }
        let window = app.windows.firstMatch.frame
        let previous = frame(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "前の")).firstMatch)
        let today = frame(app.buttons[Self.todayLabel])
        let next = frame(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "次の")).firstMatch)
        let zoom = frame(app.buttons.matching(identifier: "header.zoomReset").firstMatch)
        let titleElement = app.descendants(matching: .any).matching(identifier: "page.title").firstMatch
        let title = frame(titleElement)
        let add = frame(app.buttons["予定を追加"])
        let sync = frame(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "同期")).firstMatch)
        let settings = frame(app.buttons["設定"])
        let segmented = app.segmentedControls.firstMatch
        let named = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.pickerLabel)).firstMatch
        let picker = frame(segmented) ?? frame(named)

        var row = "?"
        var room: CGFloat?
        if let today, let picker {
            if picker.minY >= today.maxY - 0.5 {
                row = "compact"
                // The first row: title ＋ ☁ ⚙ (◀ 今日 ▶); the title's room runs from its left edge to ＋.
                if let title, let add { room = add.minX - title.minX - Self.compactGap }
            } else {
                row = "wide"
                // title switch … ⚙ 等倍 (◀ 今日 ▶); the title's room runs from its left edge to the switch.
                if let title { room = picker.minX - title.minX - Self.wideGap }
            }
        }
        func text(_ rect: CGRect?) -> String {
            guard let rect else { return "-" }
            return String(format: "%.1f,%.1f,%.1f,%.1f", rect.minX, rect.minY, rect.width, rect.height)
        }
        let roomText = room.map { String(format: "%.1f", $0) } ?? "-"
        log("\(name): row=\(row) window=\(text(window)) previous=\(text(previous)) today=\(text(today)) next=\(text(next)) "
            + "zoom=\(text(zoom)) title=\(text(title)) \"\(titleElement.exists ? titleElement.label : "")\" "
            + "switch=\(text(picker)) add=\(text(add)) sync=\(text(sync)) settings=\(text(settings)) room=\(roomText)")
    }

    private func log(_ line: String) {
        print("header room: \(line)")
        NSLog("header room: %@", line)
    }
}
