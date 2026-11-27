import UIKit
import XCTest

/// 1.4.3 (docs/R1_4_3_CONTRACT.md §6.5, §12.4, §12.5, 0g-31, 0g-43): the photos of the joined months (and, from D1y, the
/// joined years) from the normal build, in screenshot mode with the joined pages' arguments. Only a job that passes where
/// to write and the device's id runs it (`TEST_RUNNER_TEGAKI_SPAN_MY_SHOT_OUT`, `TEST_RUNNER_TEGAKI_SPAN_MY_SHOT_DEVICE`:
/// ipad13, ipad11, ipadmini or iphone69; xcodebuild hands them to the test runner without the prefix): the sample photos'
/// job of the throwaway branch r143-alt (§12.5, step P) and later span-shots-my (§12.4). Anywhere else every test skips
/// itself, so the iPhone's UI test step only counts them as skipped (as `SpanShotsUITests`).
///
/// D1b-0 (§14.1): the month's sample photos of §12.5, every one on 2026-10 (the demo's focus month, its 7th a Wednesday)
/// with `--screenshot-month-tall` (the right neighbour, November, has taller rows: five all-day events on its 18th and
/// three lines in its 25th, so the three forms of the joined months differ):
/// - `testMonthForms`: the window with the focus month's right boundary in the middle (`--screenshot-offset-x 0.5`, the
///   focus month and its tall neighbour side by side), portrait on the iPad Air 11-inch, the 13-inch iPad and the 6.9-inch
///   iPhone, and the iPad Air 11-inch turned with the window at its opening (the overview, no offset). Once per variant of
///   `TEST_RUNNER_TEGAKI_SPAN_MY_VARIANTS` (`name:arguments|name:arguments`, the arguments split on spaces; the sample
///   job names the three forms there); without it once, as the build lays the months out.
/// - `testMonthZoom`: 等倍 before and after (`--screenshot-zoom fit`), turned on the four devices; portrait once on the
///   13-inch iPad (a month at 等倍 there looks as it opens). An "after" photo whose zoom is not one page's width across the
///   canvas (the probe's `zoom` × 1,400 against the canvas's width, within 1.5 pt) fails the test: it would not show 等倍.
///
/// A portrait photo is the app's screenshot (XCUIScreenshot). A turned screen is photographed by the job instead
/// (`TEST_RUNNER_TEGAKI_SPAN_MY_SHOT_REQUESTS`: the test writes `<file>\n270\n` into `<name>.request`, the job's
/// `simctl io screenshot` writes the file under the output folder and answers `<name>.request.done`, "ok" or "failed"; the
/// protocol of `SpanShotsUITests.simulatorPhoto`), because XCUIScreenshot of a screen turned with `XCUIDevice` keeps the
/// portrait frame buffer. Without the job's answer the test falls back to XCUIScreenshot and says so (`photo=xcui`).
///
/// Every line is printed with `span-my shots:` and appended to `<out>/lines/<device>.txt`.
@MainActor
final class SpanMonthYearShotsUITests: XCTestCase {
    private struct Setup {
        let out: URL
        let device: String
        var isPad: Bool { device.hasPrefix("ipad") }
    }

    /// A photo written: its path under the output folder, how it was taken and its pixel width (0 when unknown).
    private struct Photo {
        let file: String
        let how: String
        let pixelWidth: Int
    }

    /// The canvas at rest: its probe, its frame and `span.state`'s fields.
    private struct Settled {
        let probe: [String: String]
        let raw: String
        let frame: CGRect
        let state: [String: String]
    }

    /// A variant of the forms' photos: its name (in the file's name; empty for none) and the launch arguments it adds.
    private struct Variant {
        let name: String
        let arguments: [String]
    }

    private static let japanese = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    /// Every photo's month: the demo's focus month with the tall right neighbour.
    private static let month = ["--screenshot-page", "month", "--screenshot-span", "on", "--screenshot-month-tall"]
    /// The page's width in lu (`ZoomPolicy.paperWidth(.month)`).
    private static let monthWidth = 1_400.0
    /// How far (pt) the canvas's width may be from the probe's zoom × 1,400 on an "after" photo.
    private static let fitTolerance = 1.5
    /// How long a photo waits after the screen has settled (s): the sticky heading follows the canvas's report on a later
    /// turn (`BlankPaperShotsUITests.photoWait`).
    private let photoWait: TimeInterval = 1

    // MARK: The tests

    func testMonthForms() throws {
        let setup = try setup()
        let plan: [(UIDeviceOrientation, String)]
        switch setup.device {
        case "ipad11": plan = [(.portrait, "boundary"), (.landscapeLeft, "overview")]
        case "ipad13", "iphone69": plan = [(.portrait, "boundary")]
        default: throw XCTSkip("the forms' photos are taken on the iPad Air 11-inch, the 13-inch iPad and the 6.9-inch iPhone")
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        for variant in Self.variants() {
            for (orientation, view) in plan {
                let suffix = variant.name.isEmpty ? "" : "-\(variant.name)"
                let name = "\(setup.device)-\(Self.name(orientation))-month-form\(suffix)-\(view)"
                let offset = view == "boundary" ? ["--screenshot-offset-x", "0.5"] : []
                monthPhoto(setup, name: name, orientation: orientation, arguments: Self.month + offset + variant.arguments)
            }
        }
    }

    func testMonthZoom() throws {
        let setup = try setup()
        guard ["ipad13", "ipad11", "ipadmini", "iphone69"].contains(setup.device) else {
            throw XCTSkip("no fit photos on \(setup.device)")
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        // r143-alt only (§12.5; never merged): the sample job names the form of these photos too
        // (`TEST_RUNNER_TEGAKI_SPAN_MY_ZOOM_VARIANT`, one `name:arguments` piece read as the forms' variants are), so each
        // name says the device, the orientation, the form and the state: `<device>-<orientation>-month-form-<name>-zoom-<step>`.
        // Without it the names and the arguments are r143-w-b0's.
        let form = Self.variants(of: "TEGAKI_SPAN_MY_ZOOM_VARIANT").first ?? Variant(name: "", arguments: [])
        let label = form.name.isEmpty ? "month" : "month-form-\(form.name)"
        for step in ["before", "after"] {
            let zoom = step == "after" ? ["--screenshot-zoom", "fit"] : []
            monthPhoto(setup, name: "\(setup.device)-landscape-\(label)-zoom-\(step)", orientation: .landscapeLeft,
                       arguments: Self.month + zoom + form.arguments, fit: step == "after")
        }
        if setup.device == "ipad13" {
            monthPhoto(setup, name: "ipad13-portrait-\(label)-zoom-after", orientation: .portrait,
                       arguments: Self.month + ["--screenshot-zoom", "fit"] + form.arguments, fit: true)
        }
    }

    // MARK: The photos

    /// One photo of the joined month: the window open (`span.state`'s `path=span`, `kind=month`) and settled; with `fit` the
    /// zoom checked against one page's width across the canvas.
    private func monthPhoto(_ setup: Setup, name: String, orientation: UIDeviceOrientation, arguments: [String], fit: Bool = false) {
        XCUIDevice.shared.orientation = orientation
        let app = launch(arguments)
        defer { app.terminate() }
        if waitForState(app, timeout: 45, { $0["path"] == "span" && $0["kind"] == "month" }) == nil {
            XCTFail("\(name): span.state never read path=span with kind=month: \(stateLabel(app))")
        }
        let view = settled(app)
        if view == nil { XCTFail("\(name): the canvas never settled") }
        Thread.sleep(forTimeInterval: photoWait)
        let photo = takePhoto(app, setup, file: "\(name).png", turned: orientation != .portrait)
        let zoom = view?.probe["zoom"].flatMap { Double($0) } ?? 0
        let width = Double(view?.frame.width ?? 0)
        let across = zoom * Self.monthWidth
        record(setup, "span-my shots: \(name) photo=\(photo.how) window=\(Self.text(app.windows.firstMatch.frame)) "
            + "frame=\(Self.text(view?.frame ?? .zero)) zoom=\(view?.probe["zoom"] ?? "?") across=\(Self.number(across)) "
            + "state=\(stateLabel(app)) probe=\(view?.raw ?? "-")")
        if fit, abs(across - width) > Self.fitTolerance {
            XCTFail("\(name): one page is \(Self.number(across)) pt across a canvas \(Self.number(width)) pt wide: not at fit")
        }
    }

    // MARK: Taking a photo

    /// Writes `file` (a path under the output folder). Portrait: the app's screenshot. Turned: the job's simulator photo,
    /// else the app's screenshot (`photo=xcui`).
    private func takePhoto(_ app: XCUIApplication, _ setup: Setup, file: String, turned: Bool) -> Photo {
        let url = setup.out.appendingPathComponent(file)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if turned, simulatorPhoto(file) {
            let width = UIImage(contentsOfFile: url.path)?.cgImage?.width ?? 0
            return Photo(file: file, how: "simctl", pixelWidth: width)
        }
        let shot = app.screenshot()
        let png = shot.pngRepresentation
        do {
            try png.write(to: url)
        } catch {
            XCTFail("\(file): the PNG was not written: \(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = file
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
        return Photo(file: file, how: "xcui", pixelWidth: UIImage(data: png)?.cgImage?.width ?? 0)
    }

    /// Asks the job for `simctl io screenshot` of the simulator, written to `file` and stood up: a request file in
    /// `TEGAKI_SPAN_MY_SHOT_REQUESTS` (written whole, then renamed) and the job's answer `<request>.done` ("ok" or
    /// "failed"). False without the folder, or without an answer in 90 s.
    private func simulatorPhoto(_ file: String) -> Bool {
        guard let path = ProcessInfo.processInfo.environment["TEGAKI_SPAN_MY_SHOT_REQUESTS"], !path.isEmpty else { return false }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let request = folder.appendingPathComponent(file.replacingOccurrences(of: "/", with: "_") + ".request")
        let done = URL(fileURLWithPath: request.path + ".done")
        try? FileManager.default.removeItem(at: done)
        guard (try? Data("\(file)\n270\n".utf8).write(to: request, options: .atomic)) != nil else { return false }
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if let answer = try? String(contentsOf: done, encoding: .utf8) {
                try? FileManager.default.removeItem(at: done)
                return answer.hasPrefix("ok")
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        try? FileManager.default.removeItem(at: request)
        return false
    }

    // MARK: Reading the screen

    private func setup() throws -> Setup {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["TEGAKI_SPAN_MY_SHOT_OUT"], !out.isEmpty, let device = env["TEGAKI_SPAN_MY_SHOT_DEVICE"], !device.isEmpty else {
            throw XCTSkip("only in a job that takes the joined months' photos")
        }
        let folder = URL(fileURLWithPath: out, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return Setup(out: folder, device: device)
    }

    /// `TEGAKI_SPAN_MY_VARIANTS` (r143-alt: or another variable, `key`) read: `name:arguments` pieces split on "|", the
    /// arguments on spaces; a piece without a name or a ":" is left out. None (or nothing readable): one variant without a
    /// name and without arguments.
    private static func variants(of key: String = "TEGAKI_SPAN_MY_VARIANTS") -> [Variant] {
        let text = ProcessInfo.processInfo.environment[key] ?? ""
        let read: [Variant] = text.split(separator: "|").compactMap { piece in
            guard let colon = piece.firstIndex(of: ":") else { return nil }
            let name = piece[..<colon].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
            let arguments = piece[piece.index(after: colon)...].split(separator: " ").map(String.init)
            return Variant(name: name, arguments: arguments)
        }
        return read.isEmpty ? [Variant(name: "", arguments: [])] : read
    }

    /// One launch in screenshot mode on 2026-10 (the 7th, a Wednesday) with the probe, in Japanese.
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe"] + arguments + Self.japanese
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = element(app, "span.state")
        return state.exists ? state.label : "-"
    }

    /// `span.state`'s fields once `condition` holds, read every 0.4 s; nil at the timeout.
    private func waitForState(_ app: XCUIApplication, timeout: TimeInterval, _ condition: ([String: String]) -> Bool) -> [String: String]? {
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.exists {
                let read = fields(state.label)
                if condition(read) { return read }
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return nil
    }

    /// The canvas once two reads 0.5 s apart agree on the probe's zoom and offset, the canvas's frame and `span.state`'s
    /// path, window, version, hold and shifts (the window composed and its neighbours read). nil at the timeout.
    private func settled(_ app: XCUIApplication, timeout: TimeInterval = 30) -> Settled? {
        let canvas = element(app, "ink-canvas")
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        var last: Settled?
        while Date() < deadline {
            if canvas.exists, let raw = canvas.value as? String, Double(fields(raw)["zoom"] ?? "") ?? 0 > 0, state.exists {
                let frame = canvas.frame
                if frame.width > 0 {
                    let now = Settled(probe: fields(raw), raw: raw, frame: frame, state: fields(state.label))
                    if let previous = last, Self.same(previous, now) { return now }
                    last = now
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    private static func same(_ a: Settled, _ b: Settled) -> Bool {
        a.frame == b.frame
            && ["zoom", "ox", "oy", "ph"].allSatisfy { a.probe[$0] == b.probe[$0] }
            && ["path", "session", "kind", "focus", "first", "pages", "version", "hold", "shifts"].allSatisfy { a.state[$0] == b.state[$0] }
    }

    /// `key=value` pairs joined by `;` (the probe and `span.state`).
    private func fields(_ raw: String) -> [String: String] {
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        return values
    }

    // MARK: Writing

    /// A line for the job: printed and logged, and appended to `<out>/lines/<device>.txt`.
    private func record(_ setup: Setup, _ line: String) {
        print(line)
        NSLog("%@", line)
        let folder = setup.out.appendingPathComponent("lines", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(setup.device).txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }

    private static func name(_ orientation: UIDeviceOrientation) -> String {
        orientation == .portrait ? "portrait" : "landscape"
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func number(_ value: CGFloat) -> String {
        number(Double(value))
    }

    /// "x,y,w,h" with one decimal (no spaces: the job splits the lines on them).
    private static func text(_ rect: CGRect) -> String {
        [rect.minX, rect.minY, rect.width, rect.height].map { number($0) }.joined(separator: ",")
    }
}
