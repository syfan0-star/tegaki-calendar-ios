import UIKit
import XCTest

/// 1.1.1 (docs/R1_1_1.md): photos of the paper with no events and no handwriting (`--screenshot-empty`)
/// on the owner's four kinds of device, portrait and landscape, toolbar out and folded, to compare
/// before and after the fix. Only the `blank-paper` job of build.yml runs it: it passes where to write
/// and the device's name (`TEST_RUNNER_TEGAKI_SHOT_OUT`, `TEST_RUNNER_TEGAKI_SHOT_DEVICE`; xcodebuild
/// hands them to the test runner without the prefix). Anywhere else the test skips itself, so the
/// iPhone's UI test step does not change.
///
/// A UI test because an iPad cannot be turned any other way: iPadOS ignores `--screenshot-landscape`
/// and simctl cannot rotate a device (`ScreenshotMode`'s header). `XCUIDevice.orientation` turns an
/// iPhone (`YearTapUITests`); whether it turns an iPad simulator is only known from a run: the `frame`
/// of the `blank UI:` lines says so, and at worst the iPad's "landscape" files are portrait again.
///
/// It records and judges nothing about the paper. Each photo goes to the output folder and into an
/// attachment as `<device>-<portrait|landscape>-<expanded|collapsed>-<page>.png`, and its `blank UI:`
/// line reads out the canvas's probe (`InkCanvasView.Coordinator.probeValue()`): `frame` is the paper
/// area, a negative `oy` the room above the paper and a negative `ox` the room left and right of it
/// (pt, the centring margins), `ph` the paper's height (lu). 2026-12 and 2027 are the pages the owner
/// saw it on, with nothing on them yet.
///
/// Two more kinds of photo, because neither shows on those pages. `…-portrait-expanded-tall-year`
/// (`--screenshot-tall-year`, about 2,600 lu): the size from year to year; 2027 is only 1,860 lu.
/// `<iPad>-portrait-pinned-month`: the month after the folded bar's long press 「ツールバーをいつも出す」,
/// so the paper area shrinks with the paper where it was (docs/R1_1_1.md §2.3: before the fix a band
/// should stay on the iPad mini and the Air 11, `oy` about −36 and −12).
@MainActor
final class BlankPaperShotsUITests: XCTestCase {
    /// How long the photo waits after the probe has settled (s): the sticky heading follows the canvas's
    /// report on a later turn. A shot is about 12 s in all (in run 41264726309 a launch took 7.3 s and
    /// the first find 1 s).
    private let photoWait: TimeInterval = 1

    func testShots() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["TEGAKI_SHOT_OUT"], let device = env["TEGAKI_SHOT_DEVICE"] else {
            throw XCTSkip("only in the blank-paper job")
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        for orientation in [.portrait, .landscapeLeft] as [UIDeviceOrientation] {
            for toolbar in [nil, "collapsed"] as [String?] {
                // The iPhone's week too: 1.1.1 leaves room below it (docs/R1_1_1.md), and the owner is
                // asked about it.
                let pages = [("month", "2026-12"), ("year", "2027-01")] + (device == "iphone69" ? [("week", "2026-12")] : [])
                for (page, month) in pages {
                    let name = "\(device)-\(orientation == .portrait ? "portrait" : "landscape")-\(toolbar ?? "expanded")-\(page)"
                    shoot(name, out: out, orientation: orientation, toolbar: toolbar, page: page, month: month)
                }
            }
        }
        shoot("\(device)-portrait-expanded-tall-year", out: out, orientation: .portrait, toolbar: nil,
              page: "year", month: "2027-01", arguments: ["--screenshot-tall-year"])
        if device != "iphone69" {
            let name = "\(device)-portrait-pinned-month"
            shoot(name, out: out, orientation: .portrait, toolbar: "collapsed", page: "month", month: "2026-12") { app in
                self.pinToolbar(app, name)
            }
        }
    }

    // MARK: The steps

    /// One launch, one photo. A photo without a probe is still kept (the test then fails, and goes on).
    /// `step` runs once the paper has settled; the probe is read again after it.
    private func shoot(_ name: String, out: String, orientation: UIDeviceOrientation, toolbar: String?, page: String, month: String,
                       arguments: [String] = [], step: ((XCUIApplication) -> Void)? = nil) {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", month, "--screenshot-page", page,
            "--screenshot-empty", "--screenshot-probe",
        ] + arguments + (toolbar.map { ["--screenshot-toolbar", $0] } ?? [])
        app.launch()
        defer { app.terminate() }

        let canvas = app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
        var probe = canvas.waitForExistence(timeout: 30) ? settledProbe(of: canvas) : nil
        if probe != nil, let step {
            step(app)
            probe = settledProbe(of: canvas) ?? probe
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
        log("\(name) window=\(app.windows.firstMatch.frame) frame=\(probe.frame) \(read)")
    }

    /// The folded bar's long press → 「ツールバーをいつも出す」. Judges nothing: a menu it cannot find is a
    /// line of the log, and the photo is then the folded bar's.
    private func pinToolbar(_ app: XCUIApplication, _ name: String) {
        let dock = app.buttons["ツールバーを出す"]
        guard dock.waitForExistence(timeout: 5) else {
            log("\(name): no round button")
            return
        }
        dock.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.2)
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "ツールバーをいつも出す")).firstMatch
        guard item.waitForExistence(timeout: 5) else {
            log("\(name): no 「ツールバーをいつも出す」 in the menu")
            return
        }
        item.tap()
        Thread.sleep(forTimeInterval: 1) // the bar's animation; the probe's two reads wait for the rest
    }

    /// The probe once it has a zoom and two reads 0.4 s apart agree on it, the offset and the frame
    /// (`EraserAndBelowDayUITests.settledProbe`); the last read at the timeout, nil when there was none.
    private func settledProbe(of canvas: XCUIElement, timeout: TimeInterval = 10) -> (raw: String, frame: CGRect)? {
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
        print("blank UI: \(line)")
        NSLog("blank UI: %@", line)
    }
}
