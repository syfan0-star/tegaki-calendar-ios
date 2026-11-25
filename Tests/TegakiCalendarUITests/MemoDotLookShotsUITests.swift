import UIKit
import XCTest

/// r142-alt only (docs/R1_4_2_CONTRACT.md §4.5, §7.4, 0f-23, 0f-31; never merged): the owner's choice photos of 「ドット方眼」's
/// dots, in the three looks of `--screenshot-dot-look a|b|c` (a Debug-only argument of this branch, `ScreenshotMode.dotLook`):
/// (a) 2 pt #d6cfc2 (r142's default), (b) 1.5 pt #cdc5b6, (c) 2.5 pt #d7dade. Only the step "The owner's choice photos
/// (r142-alt only)" of build.yml's blank-paper job runs it, on the 13-inch iPad and the 6.9-inch iPhone: it passes where to
/// write and the device's id (`TEST_RUNNER_TEGAKI_DOT_LOOK_OUT`, `TEST_RUNNER_TEGAKI_DOT_LOOK_DEVICE`; xcodebuild hands them
/// to the test runner without the prefix). Anywhere else it skips itself.
///
/// The pages and launch arguments are `MemoPaperShotsUITests`' (with `--screenshot-memo-paper dots`):
/// - `month-memo`: the month's memo area with the grown demo (`--screenshot-grown --screenshot-offset 0,1700`);
/// - `day`: the day's right column 「メモ」 above 24:00 and the free memo below it (`--screenshot-grown --screenshot-offset
///   0,2300`, `MemoPaperShotsUITests`' `day-memo`).
/// Each in the looks a, b and c, one after the other: `<device>-<page>-dots-<look>.png`, 2 × 3 = 6 photos a device, each
/// with one `dot-look shots:` line. Nothing here judges the dots (the step compares the pairs); a missing probe or a pattern
/// other than `style=dots` fails the test, and the photo is kept.
@MainActor
final class MemoDotLookShotsUITests: XCTestCase {
    /// How long the photo waits after the canvas has settled (s), as `MemoPaperShotsUITests.photoWait`.
    private let photoWait: TimeInterval = 1

    private static let photos: [(name: String, arguments: [String])] = [
        ("month-memo", ["--screenshot-page", "month", "--screenshot-grown", "--screenshot-offset", "0,1700"]),
        ("day", ["--screenshot-page", "day", "--screenshot-grown", "--screenshot-offset", "0,2300"]),
    ]

    private static let looks = ["a", "b", "c"]

    func testShots() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["TEGAKI_DOT_LOOK_OUT"], let device = env["TEGAKI_DOT_LOOK_DEVICE"] else {
            throw XCTSkip("only in the blank-paper job's choice photo step of r142-alt")
        }
        guard ["ipad13", "iphone69"].contains(device) else {
            throw XCTSkip("the choice photos are taken on the 13-inch iPad and the 6.9-inch iPhone")
        }
        XCUIDevice.shared.orientation = .portrait
        for photo in Self.photos {
            for look in Self.looks {
                shoot("\(device)-\(photo.name)-dots-\(look)", out: out, look: look, arguments: photo.arguments)
            }
        }
    }

    // MARK: The steps

    /// One launch, one photo. A photo without a probe is still kept (the test then fails, and goes on).
    private func shoot(_ name: String, out: String, look: String, arguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe", "--screenshot-memo-paper", "dots",
            "--screenshot-dot-look", look, "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ] + arguments
        app.launch()
        defer { app.terminate() }

        let canvas = element(app, "ink-canvas")
        let probe = canvas.waitForExistence(timeout: 30) ? settledProbe(of: canvas) : nil
        let paper = element(app, "memo-paper.state")
        let style = paper.waitForExistence(timeout: 5) ? paper.label : "-"
        if style != "style=dots" {
            XCTFail("\(name): memo-paper.state reads \(style), not style=dots")
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
        log("\(name) window=\(app.windows.firstMatch.frame) frame=\(probe.frame) \(read) \(style) look=\(look)")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The probe once it has a zoom and two reads 0.4 s apart agree on it, the offset and the frame
    /// (`MemoPaperShotsUITests.settledProbe`); the last read at the timeout, nil when there was none.
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
        print("dot-look shots: \(line)")
        NSLog("dot-look shots: %@", line)
    }
}
