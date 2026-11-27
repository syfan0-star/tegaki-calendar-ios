import UIKit
import XCTest

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.7, §7.3, 0f-30): the photos of the memo paper's 「ドット方眼」 and 「無地」, for the lead and
/// the confirmation page (artifact `memo-paper-shots`; not J-4's `screenshots`, not blank-paper's 43, so neither changes). Only
/// the step "Memo paper shots (1.4.2)" of build.yml's blank-paper job runs it, on the 13-inch iPad and the 6.9-inch iPhone: it
/// passes where to write and the device's id (`TEST_RUNNER_TEGAKI_MEMO_SHOT_OUT`, `TEST_RUNNER_TEGAKI_MEMO_SHOT_DEVICE`;
/// xcodebuild hands them to the test runner without the prefix). Anywhere else it skips itself, so the iPhone's UI test step
/// does not change (as `BlankPaperShotsUITests`).
///
/// For each of `dots` and `plain` (`--screenshot-memo-paper`), four photos in portrait, `<device>-<pattern>-<photo>.png`:
/// - `month-memo`: the month's memo area with the grown demo (`--screenshot-grown --screenshot-offset 0,1700`, J-4's
///   `month-memo`);
/// - `day-memo`: the day's right column 「メモ」 above 24:00 and the free memo below it (`--screenshot-grown --screenshot-offset
///   0,2300`, J-4's `day-extra`);
/// - `week-memo-band`: the joined weeks' free memo across the focus week's left boundary (`--screenshot-span on
///   --screenshot-week-memo --screenshot-offset 0,1500 --screenshot-offset-x -0.5`, span-shots' `week-memo-band`);
/// - `day-band`: the joined days' boundary across 24:00 (`--screenshot-span on --screenshot-offset-x -0.5 --screenshot-offset
///   0,2200`), where the free memo's columns go on 50 lu apart.
/// 2 devices × 2 patterns × 4 = 16 photos; the month's PDF with dots is the 17th (MemoPaperDrawTests, the same step). The
/// lead looks at them; nothing here judges the paper (a missing probe fails the test, and the photo is kept).
@MainActor
final class MemoPaperShotsUITests: XCTestCase {
    /// How long the photo waits after the canvas has settled (s), as `BlankPaperShotsUITests.photoWait`.
    private let photoWait: TimeInterval = 1

    private static let photos: [(name: String, arguments: [String], joined: Bool)] = [
        ("month-memo", ["--screenshot-page", "month", "--screenshot-grown", "--screenshot-offset", "0,1700"], false),
        ("day-memo", ["--screenshot-page", "day", "--screenshot-grown", "--screenshot-offset", "0,2300"], false),
        ("week-memo-band", ["--screenshot-page", "week", "--screenshot-week-memo", "--screenshot-offset", "0,1500",
                            "--screenshot-span", "on", "--screenshot-offset-x", "-0.5"], true),
        ("day-band", ["--screenshot-page", "day", "--screenshot-span", "on", "--screenshot-offset-x", "-0.5",
                      "--screenshot-offset", "0,2200"], true),
    ]

    func testShots() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["TEGAKI_MEMO_SHOT_OUT"], let device = env["TEGAKI_MEMO_SHOT_DEVICE"] else {
            throw XCTSkip("only in the blank-paper job's memo paper step")
        }
        guard ["ipad13", "iphone69"].contains(device) else {
            throw XCTSkip("the memo paper photos are taken on the 13-inch iPad and the 6.9-inch iPhone")
        }
        XCUIDevice.shared.orientation = .portrait
        for pattern in ["dots", "plain"] {
            for photo in Self.photos {
                shoot("\(device)-\(pattern)-\(photo.name)", out: out, pattern: pattern, arguments: photo.arguments, joined: photo.joined)
            }
        }
    }

    // MARK: The steps

    /// One launch, one photo. A photo without a probe is still kept (the test then fails, and goes on).
    private func shoot(_ name: String, out: String, pattern: String, arguments: [String], joined: Bool) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe", "--screenshot-memo-paper", pattern,
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ] + arguments
        app.launch()
        defer { app.terminate() }

        let canvas = element(app, "ink-canvas")
        var state = "-"
        if joined {
            state = waitForState(app, timeout: 45) { $0.contains("path=span") } ?? stateLabel(app)
            if !state.contains("path=span") {
                XCTFail("\(name): span.state never read path=span (\(state))")
            }
        }
        let probe = canvas.waitForExistence(timeout: 30) ? settledProbe(of: canvas) : nil
        let paper = element(app, "memo-paper.state")
        let style = paper.waitForExistence(timeout: 5) ? paper.label : "-"
        if style != "style=\(pattern)" {
            XCTFail("\(name): memo-paper.state reads \(style), not style=\(pattern)")
        }
        Thread.sleep(forTimeInterval: photoWait)
        let shot = app.screenshot()
        do {
            try shot.pngRepresentation.write(to: URL(fileURLWithPath: out).appendingPathComponent("\(name).png"))
        } catch {
            log("\(name): the PNG was not written: \(error)")
            XCTFail("\(name): the PNG was not written: \(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let probe else {
            log("\(name): no probe. Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the canvas never reported a zoom")
            return
        }
        let values = Self.values(of: probe.raw)
        let read = ["zoom", "ox", "oy", "ph"].map { "\($0)=\(values[$0] ?? "?")" }.joined(separator: " ")
        log("\(name) window=\(app.windows.firstMatch.frame) frame=\(probe.frame) \(read) \(style) state=\(joined ? state : "-")")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = element(app, "span.state")
        return state.exists ? state.label : "-"
    }

    /// `span.state`'s label once `condition` holds, read every 0.4 s, and once more after the deadline (1.4.1's lesson,
    /// docs/R1_4_1.md); nil when it never held.
    private func waitForState(_ app: XCUIApplication, timeout: TimeInterval, _ condition: (String) -> Bool) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let label = stateLabel(app)
            if condition(label) { return label }
            Thread.sleep(forTimeInterval: 0.4)
        }
        let label = stateLabel(app)
        return condition(label) ? label : nil
    }

    /// The probe once it has a zoom and two reads 0.4 s apart agree on it, the offset and the frame
    /// (`BlankPaperShotsUITests.settledProbe`); the last read at the timeout, nil when there was none.
    private func settledProbe(of canvas: XCUIElement, timeout: TimeInterval = 15) -> (raw: String, frame: CGRect)? {
        let deadline = Date().addingTimeInterval(timeout)
        var last: (raw: String, frame: CGRect)?
        while Date() < deadline {
            if let raw = canvas.value as? String, Double(Self.values(of: raw)["zoom"] ?? "") ?? 0 > 0, canvas.frame.width > 0 {
                let now = (raw: raw, frame: canvas.frame)
                if let previous = last, Self.sameView(previous.raw, now.raw), previous.frame == now.frame { return now }
                last = now
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return last
    }

    private static func sameView(_ a: String, _ b: String) -> Bool {
        let (left, right) = (values(of: a), values(of: b))
        return ["zoom", "ox", "oy"].allSatisfy { left[$0] == right[$0] }
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
        print("memo-paper shots: \(line)")
        NSLog("memo-paper shots: %@", line)
    }
}
