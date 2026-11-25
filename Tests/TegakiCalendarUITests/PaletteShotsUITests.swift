import UIKit
import XCTest

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §7.4, §6.1, §6.6, 0e-23, 0e-24): the new photos of 1.4.1, outside J-4's pairs (none goes into
/// the first job's `screenshots`, nor into ja-baseline.yml, §7.1). Only build.yml's span-shots-app job runs it, beside
/// SpanShotsUITests and with its variables (`TEST_RUNNER_TEGAKI_SPAN_SHOT_OUT`, `…_DEVICE`, `…_REQUESTS`; xcodebuild hands them
/// to the test runner without the prefix); anywhere else it skips itself, so ui-tests and blank-paper do not change. The
/// photos go to `<out>/palette/`, which the job uploads as the artifact palette-shots (not span-shots-app's), and the lines
/// (`palette shot:`) to `<out>/palette/lines-<device>.txt`, never to `<out>/lines/`, whose lines the job's gates count.
///
/// - ipad13: the month and the week in portrait with `--screenshot-palette top`, `left` and `right`; the month with
///   `--screenshot-hand left`; the month with `--screenshot-palette-drag right` (the look of a drag, the confirmation page
///   only); the month in landscape with the bar on the left.
/// - ipadmini: the month in portrait with the bar on the left; the week in landscape with the bar on the right, as it opens
///   and with its upright column scrolled to its end (the column is longer than the mini's landscape window).
/// - iphone (the iPhone 17): the week in portrait and in landscape with `--screenshot-hand left` (the header mirrored; the
///   toolbar 1.4's).
/// - The rework (docs/R1_4_1_CONTRACT.md §16.3.7, §16.6, §16.8): 等倍 of the week and the day, one page's width across the
///   paper's column, for the confirmation page's before and after (`--screenshot-zoom fit`): ipad13's week and day in portrait,
///   the iPhone 17's day in portrait and its joined week in landscape (`--screenshot-span on`: one week across where the cap
///   shows three). Their lines add the canvas's zoom and x and one page's width at that zoom (`across=`, pt), to be read
///   against the canvas's width; they take no edge (`ok=yes`, as the hand's photos).
/// - The second rework (docs/R1_4_1_CONTRACT.md §17.2, §17.4): the 「動かす」 button before 「しまう」, for the confirmation page —
///   ipad13's week in portrait with the bar at the bottom (`ipad13-portrait-week-move`) and with the button's choice of edges
///   open (`ipad13-portrait-week-move-menu`, `--screenshot-palette-menu`), and the mini's week in portrait with the upright bar
///   on the left (`ipadmini-portrait-week-left-move`). Their lines also need the button (`move=` its frame; `ok=no` without
///   it) and, for the menu, its 「右へ移す」 (`menu=yes`).
/// - The third rework (docs/R1_4_1_CONTRACT.md §18.3): ipad13's week in portrait with the toolbar folded
///   (`--screenshot-toolbar collapsed`) and peeked by a tap on the round button's tool mark (`ipad13-portrait-week-peek-move`:
///   the peeked bar at the bottom with 「動かす」 left of 「しまう」). Screenshot mode has no peek of its own (the
///   `--screenshot-toolbar` values are 1.1's), so the test taps. Its line also needs the tap (`peek=yes`), the button
///   (`move=`) and no grip (`grip=no`, a peek's).
/// - 1.4.2 (docs/R1_4_2_CONTRACT.md §3.4, §3.8, §3.9, §7.3, 0f-30): the pen colour panel — ipad13's week in portrait with the
///   panel open at the lit dot of the bar at the bottom, the top, the left and the right (`--screenshot-color-panel`), and on
///   the peeks at the bottom and on the left (`--screenshot-toolbar collapsed`, the round button's tool mark and the lit dot
///   tapped); the mini's week with the upright bar on the left; the iPhone 17's week with the panel and with other dots
///   (`--screenshot-pen-slots`, the six colours added). Their lines also need the panel (`panel=` its frame; `ok=no` without
///   it) or, for the dots, dot 1 read out as 茶 (`dot1=`). The panel's photo of the bottom bar is the owner's sample of the
///   twelve colours (§7.3).
/// - 1.4.2 (§3.9, §7.3): `testDarkPalettePhotos`, run by the job on ipad13 and the iPhone 17 alone, last, with the simulator in
///   dark mode (TEST_RUNNER_TEGAKI_PALETTE_DARK=1; skipped otherwise): the week with the panel open, the bar's dots with their
///   dark rims. Every other photo of this class and of the job is light.
/// The iPhone 18 Pro Max's portrait month (等倍 on the second row) and the iPhone 17's `iphone-portrait-week-zoom3` are J-4's
/// photos already (the first job), so they are not taken again here.
///
/// A landscape photo is the job's `simctl io screenshot` of the screen turned with `XCUIDevice` (SpanShotsUITests'
/// `simulatorPhoto`: iPadOS ignores `--screenshot-landscape`, and XCUIScreenshot of a turned screen is cut); a portrait one is
/// the app's screenshot. Each photo's line says how it was taken and what `palette.state` read: `ok=no` when the bar is not on
/// the edge asked for (the window did not allow it, or the app did not move it), and for the scrolled photo when the column did
/// not move (`reason=not-scrolled`, 「ペン」's frame before and after). The photos are compared by the lead, so the
/// test fails on nothing but its launches (contract §7.4: not judged automatically); the job warns on `ok=no`.
@MainActor
final class PaletteShotsUITests: XCTestCase {
    private struct Setup {
        let out: URL
        let device: String
    }

    private static let japanese = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    /// One page's width (lu) of the week and of the day (`ZoomPolicy.paperWidth`), for the 等倍 photos' `across=`.
    private static let weekWidth: CGFloat = 1400
    private static let dayWidth: CGFloat = 1000
    /// How long a photo waits after the screen has settled (s; SpanShotsUITests' `photoWait`).
    private let photoWait: TimeInterval = 1

    /// 1.4.2 (§7.3): the six colours added, on the dots of `iphone-portrait-week-pen-slots`.
    private static let addedSlots = "#92400e,#6b7280,#db2777,#0284c7,#166534,#1e40af"

    func testPalettePhotos() throws {
        let setup = try setup()
        try XCTSkipIf(ProcessInfo.processInfo.environment["TEGAKI_PALETTE_DARK"] == "1", "the dark run takes testDarkPalettePhotos only")
        defer { XCUIDevice.shared.orientation = .portrait }
        switch setup.device {
        case "ipad13":
            for page in ["month", "week"] {
                for edge in ["top", "left", "right"] {
                    shoot(setup, "ipad13-portrait-\(page)-\(edge)", .portrait, ["--screenshot-page", page, "--screenshot-palette", edge], edge: edge)
                }
            }
            shoot(setup, "ipad13-portrait-month-hand-left", .portrait, ["--screenshot-page", "month", "--screenshot-hand", "left"], edge: nil)
            shoot(setup, "ipad13-portrait-month-drag-right", .portrait, ["--screenshot-page", "month", "--screenshot-palette-drag", "right"],
                  edge: "bottom")
            shoot(setup, "ipad13-landscape-month-left", .landscapeLeft, ["--screenshot-page", "month", "--screenshot-palette", "left"], edge: "left")
            // The rework (§16.6): 等倍 of the week and the day.
            shoot(setup, "ipad13-portrait-week-fit", .portrait, ["--screenshot-page", "week", "--screenshot-zoom", "fit"], edge: nil,
                  pageWidth: Self.weekWidth)
            shoot(setup, "ipad13-portrait-day-fit", .portrait, ["--screenshot-page", "day", "--screenshot-zoom", "fit"], edge: nil,
                  pageWidth: Self.dayWidth)
            // The second rework (§17.4): 「動かす」 at the bar's right end, and its choice of edges open.
            shoot(setup, "ipad13-portrait-week-move", .portrait, ["--screenshot-page", "week", "--screenshot-palette", "bottom"],
                  edge: "bottom", move: .button)
            shoot(setup, "ipad13-portrait-week-move-menu", .portrait,
                  ["--screenshot-page", "week", "--screenshot-palette", "bottom", "--screenshot-palette-menu"], edge: "bottom", move: .menu)
            // The third rework (§18.3): the folded bar peeked from the round button, with 「動かす」 left of 「しまう」.
            shoot(setup, "ipad13-portrait-week-peek-move", .portrait,
                  ["--screenshot-page", "week", "--screenshot-palette", "bottom", "--screenshot-toolbar", "collapsed"], edge: "bottom",
                  move: .peek)
            // 1.4.2 (§7.3): the colour panel at the lit dot of every bar, and of the peeks at the bottom and on the left.
            for edge in ["bottom", "top", "left", "right"] {
                let name = edge == "bottom" ? "ipad13-portrait-week-color-panel" : "ipad13-portrait-week-\(edge)-color-panel"
                shoot(setup, name, .portrait, ["--screenshot-page", "week", "--screenshot-palette", edge, "--screenshot-color-panel"],
                      edge: edge, panel: .opened)
            }
            shoot(setup, "ipad13-portrait-week-peek-color-panel", .portrait,
                  ["--screenshot-page", "week", "--screenshot-palette", "bottom", "--screenshot-toolbar", "collapsed"], edge: "bottom",
                  panel: .peeked)
            shoot(setup, "ipad13-portrait-week-peek-left-color-panel", .portrait,
                  ["--screenshot-page", "week", "--screenshot-palette", "left", "--screenshot-toolbar", "collapsed"], edge: "left",
                  panel: .peeked)
        case "ipadmini":
            shoot(setup, "ipadmini-portrait-month-left", .portrait, ["--screenshot-page", "month", "--screenshot-palette", "left"], edge: "left")
            shoot(setup, "ipadmini-landscape-week-right", .landscapeLeft, ["--screenshot-page", "week", "--screenshot-palette", "right"],
                  edge: "right", scrolledToo: true)
            // The second rework (§17.4): 「動かす」 on the upright bar, over 「しまう」.
            shoot(setup, "ipadmini-portrait-week-left-move", .portrait, ["--screenshot-page", "week", "--screenshot-palette", "left"],
                  edge: "left", move: .button)
            // 1.4.2 (§7.3): the colour panel beside the mini's upright bar.
            shoot(setup, "ipadmini-portrait-week-left-color-panel", .portrait,
                  ["--screenshot-page", "week", "--screenshot-palette", "left", "--screenshot-color-panel"], edge: "left", panel: .opened)
        case "iphone":
            shoot(setup, "iphone-portrait-week-hand-left", .portrait, ["--screenshot-page", "week", "--screenshot-hand", "left"], edge: nil)
            shoot(setup, "iphone-landscape-week-hand-left", .landscapeLeft, ["--screenshot-page", "week", "--screenshot-hand", "left"], edge: nil)
            // The rework (§16.6): 等倍 of the day, and of the joined week in landscape (one week across, not the cap's three).
            shoot(setup, "iphone-portrait-day-fit", .portrait, ["--screenshot-page", "day", "--screenshot-zoom", "fit"], edge: nil,
                  pageWidth: Self.dayWidth)
            shoot(setup, "iphone-landscape-week-fit", .landscapeLeft,
                  ["--screenshot-page", "week", "--screenshot-span", "on", "--screenshot-zoom", "fit"], edge: nil, pageWidth: Self.weekWidth)
            // 1.4.2 (§7.3): the colour panel on the bottom bar, and the six added colours on the dots.
            shoot(setup, "iphone-portrait-week-color-panel", .portrait, ["--screenshot-page", "week", "--screenshot-color-panel"], edge: nil,
                  panel: .opened)
            shoot(setup, "iphone-portrait-week-pen-slots", .portrait, ["--screenshot-page", "week", "--screenshot-pen-slots", Self.addedSlots],
                  edge: nil, panel: .slots)
        default:
            throw XCTSkip("no palette photos on \(setup.device)")
        }
    }

    /// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.9, §7.3): the dark photos, the job's last run on ipad13 and the iPhone 17 with the
    /// simulator in dark mode (`simctl ui … appearance dark`, light again right after): the week with the colour panel open.
    func testDarkPalettePhotos() throws {
        let setup = try setup()
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TEGAKI_PALETTE_DARK"] == "1", "only the job's dark run")
        defer { XCUIDevice.shared.orientation = .portrait }
        switch setup.device {
        case "ipad13":
            shoot(setup, "ipad13-portrait-week-dark-color-panel", .portrait,
                  ["--screenshot-page", "week", "--screenshot-palette", "bottom", "--screenshot-color-panel"], edge: "bottom", panel: .opened)
        case "iphone":
            shoot(setup, "iphone-portrait-week-dark-color-panel", .portrait, ["--screenshot-page", "week", "--screenshot-color-panel"],
                  edge: nil, panel: .opened)
        default:
            throw XCTSkip("no dark photos on \(setup.device)")
        }
    }

    // MARK: One photo

    /// What a photo of the 「動かす」 button waits for (§17.4): the button, or the button and its choice of edges open; and
    /// (§18.3) the folded bar peeked by a tap on the round button's tool mark, the button on the peek and no grip.
    private enum MoveShot {
        case button, menu, peek
    }

    /// 1.4.2 (§7.3): what a photo of the colour panel waits for: the panel opened by `--screenshot-color-panel`; on a peek, the
    /// round button's tool mark and then the lit dot tapped and the panel; or (no panel) dot 1 read out as 茶.
    private enum PanelShot {
        case opened, peeked, slots
    }

    /// One launch, one photo (two with `scrolledToo`: the upright column scrolled to its end). `edge` is the edge
    /// `palette.state` must read (waited for); nil: no `--screenshot-palette` (no state element). `pageWidth` (lu, the 等倍
    /// photos): the line also carries the canvas's zoom and x and that width at the zoom (`across=`, pt). `move` (the second
    /// rework's photos): the line also needs the 「動かす」 button (and with `.menu` its choice 「右へ移す」), waited for; with
    /// `.peek` (the third rework's) the round button's tool mark is tapped first and the line needs the tap and no grip.
    private func shoot(_ setup: Setup, _ name: String, _ orientation: UIDeviceOrientation, _ arguments: [String], edge: String?,
                       scrolledToo: Bool = false, pageWidth: CGFloat? = nil, move: MoveShot? = nil, panel: PanelShot? = nil) {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe"] + arguments + Self.japanese
        app.launch()
        defer { app.terminate() }
        let canvas = element(app, "ink-canvas")
        guard canvas.waitForExistence(timeout: 30) else {
            XCTFail("\(name): the app did not show its canvas")
            record(setup, "palette shot: device=\(setup.device) name=\(name) ok=no reason=no-canvas")
            return
        }
        var state = "-"
        var ok = true
        if let edge {
            let read = waitForState(app, timeout: 15) { $0["edge"] == edge }
            state = stateLabel(app)
            ok = read != nil
        }
        settle(canvas)
        var moveFields = ""
        if move == .peek {
            // §18.3: the round button's tool mark peeks the folded bar (the peek's 0.2 s; the waits below cover it).
            let dock = app.buttons["ツールバーを出す"]
            let tapped = dock.waitForExistence(timeout: 15)
            if tapped { dock.tap() }
            moveFields += " peek=\(tapped ? "yes" : "no")"
            ok = ok && tapped
        }
        if let move {
            let button = element(app, "toolbar.move")
            let shown = button.waitForExistence(timeout: 15)
            moveFields += " move=\(shown ? Self.text(button.frame) : "-")"
            ok = ok && shown
            if move == .menu {
                let open = app.buttons["右へ移す"].waitForExistence(timeout: 15)
                moveFields += " menu=\(open ? "yes" : "no")"
                ok = ok && open
            }
            if move == .peek {
                let grip = element(app, "toolbar.grip").exists
                moveFields += " grip=\(grip ? "yes" : "no")"
                ok = ok && !grip
            }
        }
        if let panel {
            moveFields += panelFields(app, panel, ok: &ok)
        }
        Thread.sleep(forTimeInterval: photoWait)
        let turned = orientation != .portrait
        let how = takePhoto(app, setup, file: "palette/\(name).png", turned: turned)
        record(setup, "palette shot: device=\(setup.device) name=\(name) photo=\(how) ok=\(ok ? "yes" : "no") expected=\(edge ?? "-") "
            + "window=\(Self.text(app.windows.firstMatch.frame)) canvas=\(Self.text(canvas.frame)) state=\(state)"
            + (pageWidth.map { zoomFields(canvas, pageWidth: $0) } ?? "") + moveFields)
        guard scrolledToo else { return }
        // The upright column scrolled: one slow drag from near its bottom to near its top, held before the lift. It starts
        // inside the scrolling column, 40 pt above 「しまう」, which sits under it outside the scroll (ToolbarView's
        // `verticalBar`: a press there would hold the plain button and scroll nothing); without 「しまう」, 130 pt above the
        // window's bottom (the safe area, the slot's 6 pt and 「しまう」's 57 pt section, and a margin). `ok` is the column
        // having moved with the bar still open: 「ペン」, at its top, went up (or left the tree once scrolled away).
        // The second rework (§17.2): 「動かす」 sits right over 「しまう」 outside the scroll too (a drag there would move the
        // bar), so the drag starts 40 pt above 「動かす」 when it is there (and without either, 48 pt higher for it).
        let pen = app.buttons["ペン"]
        let collapse = app.buttons["ツールバーをしまう"]
        let moveButton = element(app, "toolbar.move")
        let window = app.windows.firstMatch.frame
        let before = pen.exists ? pen.frame : nil
        if let before {
            let x = before.midX
            let above = moveButton.exists ? moveButton.frame.minY : collapse.exists ? collapse.frame.minY : nil
            let startY = above.map { $0 - 40 } ?? window.maxY - 130 - 48
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: x, dy: startY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: window.minY + 160)),
                       withVelocity: XCUIGestureVelocity(rawValue: 300), thenHoldForDuration: 0.4)
            Thread.sleep(forTimeInterval: photoWait)
        }
        let after = pen.exists ? pen.frame : nil
        var moved = false
        if let before, collapse.exists {
            moved = after.map { $0.minY < before.minY - 1 } ?? true
        }
        let scrolled = takePhoto(app, setup, file: "palette/\(name)-scrolled.png", turned: turned)
        record(setup, "palette shot: device=\(setup.device) name=\(name)-scrolled photo=\(scrolled) ok=\(moved ? "yes" : "no") "
            + "expected=\(edge ?? "-") pen-before=\(before.map { Self.text($0) } ?? "-") pen=\(after.map { Self.text($0) } ?? "-") "
            + "state=\(stateLabel(app))" + (moved ? "" : " reason=not-scrolled"))
    }

    /// 1.4.2 (§7.3): " peek=… dot=… panel=<frame>" (or " dot1=<label>" for the dots), waited for; `ok` false when it is not there.
    private func panelFields(_ app: XCUIApplication, _ shot: PanelShot, ok: inout Bool) -> String {
        var fields = ""
        if shot == .slots {
            let dot = app.buttons["toolbar.swatch.0"]
            let brown = waitFor(15) { dot.exists && dot.label == "茶" }
            fields += " dot1=\(dot.exists ? dot.label : "-")"
            ok = ok && brown
            return fields
        }
        if shot == .peeked {
            let dock = app.buttons["ツールバーを出す"]
            let tapped = dock.waitForExistence(timeout: 15)
            if tapped { dock.tap() }
            fields += " peek=\(tapped ? "yes" : "no")"
            var lit: XCUIElement?
            _ = waitFor(10) {
                lit = (0..<6).map { app.buttons["toolbar.swatch.\($0)"] }.first { $0.exists && $0.isSelected }
                return lit != nil
            }
            if let lit {
                Thread.sleep(forTimeInterval: 0.5)
                lit.tap()
            }
            fields += " dot=\(lit?.identifier ?? "-")"
            ok = ok && tapped && lit != nil
        }
        let panel = element(app, "toolbar.colorPanel")
        let shown = panel.waitForExistence(timeout: 15)
        fields += " panel=\(shown ? Self.text(panel.frame) : "-")"
        ok = ok && shown
        return fields
    }

    /// Whether `condition` held within `seconds` (polled every 0.3 s), read once more after the deadline.
    private func waitFor(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return condition()
    }

    /// The canvas's probe read the same twice, 0.5 s apart (at most 15 s): the first layout and the slots are done.
    private func settle(_ canvas: XCUIElement) {
        var last = ""
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let now = "\(canvas.value as? String ?? "")|\(canvas.frame)"
            if now == last, !now.hasPrefix("|") { return }
            last = now
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: Taking a photo (SpanShotsUITests' way)

    /// Writes `file` under the output folder: the job's simulator photo for a turned screen (else the app's screenshot,
    /// `xcui`, cut), the app's screenshot in portrait. Returns how it was taken.
    private func takePhoto(_ app: XCUIApplication, _ setup: Setup, file: String, turned: Bool) -> String {
        let url = setup.out.appendingPathComponent(file)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if turned, simulatorPhoto(file) {
            return "simctl"
        }
        let shot = app.screenshot()
        do {
            try shot.pngRepresentation.write(to: url)
        } catch {
            record(setup, "palette shot: device=\(setup.device) file=\(file) not written: \(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = file
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
        return "xcui"
    }

    /// A request to the job's `watch_photos` (`TEGAKI_SPAN_SHOT_REQUESTS`: the file under the output folder and the turn, written
    /// whole, then renamed) and its answer `<request>.done` ("ok" or "failed"). False without the folder or an answer in 90 s.
    private func simulatorPhoto(_ file: String) -> Bool {
        guard let path = ProcessInfo.processInfo.environment["TEGAKI_SPAN_SHOT_REQUESTS"], !path.isEmpty else { return false }
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
        guard let out = env["TEGAKI_SPAN_SHOT_OUT"], !out.isEmpty, let device = env["TEGAKI_SPAN_SHOT_DEVICE"], !device.isEmpty else {
            throw XCTSkip("only in the span-shots-app job")
        }
        let folder = URL(fileURLWithPath: out, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder.appendingPathComponent("palette", isDirectory: true), withIntermediateDirectories: true)
        return Setup(out: folder, device: device)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// " zoom=<z> ox=<x> across=<page width × z>" from the canvas's probe (`-` for a value it does not read out).
    private func zoomFields(_ canvas: XCUIElement, pageWidth: CGFloat) -> String {
        var values: [String: String] = [:]
        for part in (canvas.value as? String ?? "").split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        let across = values["zoom"].flatMap(Double.init).map { String(format: "%.1f", Double(pageWidth) * $0) } ?? "-"
        return " zoom=\(values["zoom"] ?? "-") ox=\(values["ox"] ?? "-") across=\(across)"
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = element(app, "palette.state")
        return state.exists ? state.label : "-"
    }

    /// `palette.state`'s fields once `condition` holds, read every 0.3 s; nil at the timeout.
    private func waitForState(_ app: XCUIApplication, timeout: TimeInterval, _ condition: ([String: String]) -> Bool) -> [String: String]? {
        let state = element(app, "palette.state")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.exists {
                var values: [String: String] = [:]
                for part in state.label.split(separator: ";") {
                    guard let equals = part.firstIndex(of: "=") else { continue }
                    values[String(part[..<equals])] = String(part[part.index(after: equals)...])
                }
                if condition(values) { return values }
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return nil
    }

    // MARK: Writing

    /// A line for the job: printed and logged, and appended to `<out>/palette/lines-<device>.txt`.
    private func record(_ setup: Setup, _ line: String) {
        print(line)
        NSLog("%@", line)
        let url = setup.out.appendingPathComponent("palette", isDirectory: true).appendingPathComponent("lines-\(setup.device).txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }

    /// "x,y,w,h" with one decimal (no spaces: the job splits the lines on them).
    private static func text(_ rect: CGRect) -> String {
        [rect.minX, rect.minY, rect.width, rect.height].map { String(format: "%.1f", Double($0)) }.joined(separator: ",")
    }
}
