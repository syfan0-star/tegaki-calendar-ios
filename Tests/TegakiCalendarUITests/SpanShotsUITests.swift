import UIKit
import XCTest

/// 1.3 (docs/M7C_CONTRACT.md §10.5 (2); the wave C plan §7.6 with the lead's decisions C3-m1, C3-m3, C3-m4 and C3-M4):
/// the photos of the joined pages from the normal build (screenshot mode with the joined pages' arguments, §3.12). Only the
/// `span-shots-app` job of build.yml runs it: it passes where to write and the device's id (`TEST_RUNNER_TEGAKI_SPAN_SHOT_OUT`,
/// `TEST_RUNNER_TEGAKI_SPAN_SHOT_DEVICE`: ipad11, ipadmini, ipad13 or iphone; xcodebuild hands them to the test runner without
/// the prefix). Anywhere else every test skips itself, so the iPhone's UI test step does not change (as
/// `BlankPaperShotsUITests`).
///
/// - `testBands`: the week and the day joined, the focus page's left boundary in the middle (`--screenshot-offset-x -0.5`,
///   the crossing demo there) and the overview, portrait on every device and landscape on the iPhone (C3-m1: no iPad
///   landscape band), and the week starting on Sunday on the iPad Air 11-inch.
/// - `testShiftPairs` (C3-M4; iPad Air 11-inch and iPhone 17, week and day, one launch per pair): the band opens one page
///   off (`--screenshot-span-shift`) and the screen holds the shift (`span.state`'s `hold=on`). "Before" is taken once the
///   probe and `span.state` read the same twice (the window composed and its neighbours read), then `span.release` is
///   tapped, and "after" once `shifts=1` has settled. The job compares the two with tools/shots/shift_pair.swift: the rows
///   above the canvas (the status bar, the heading and the all-day band, C3-m3 (b)) left out, no pixel may differ strongly.
///   Whether the shift re-packed the all-day band's lanes is read from the canvas's frame (`band=same|moved`).
/// - `testOldVersionMargins` (C3-m4; wave D's text decision 11): one page (`--screenshot-single-page`, the way 1.2.3 shows
///   a page that holds the halves of strokes drawn across its left boundary) and its control (the same arguments without
///   it: 1.2.3's demo), week and day, portrait and landscape on the three iPads, and the iPhone's portrait day and its
///   landscape week and day. The job counts the pixels of the desk around the page that are not the desk's colour
///   (tools/shots/span_margin.swift; the control must count 0).
/// - `testLanguages` (iPhone 17, only with `TEST_RUNNER_TEGAKI_SPAN_SHOT_LANGUAGES=1`, which the job passes on r13 and the
///   integration branch, C3-m1): 10 languages × 6 photos — 設定 › ページ (`--screenshot-settings-section page`), the
///   first-time guide's cards of the week and the day for one and two fingers (`--screenshot-span-guide one|two`), and
///   stage 2's notice N-8 (`--screenshot-span-guide stage-two`, a toast: the photo waits for its text, read from the
///   string catalogue the job names in `TEST_RUNNER_TEGAKI_SPAN_SHOT_STRINGS`).
///
/// A portrait photo is the app's screenshot (XCUIScreenshot). A turned screen is photographed by the job instead
/// (`TEST_RUNNER_TEGAKI_SPAN_SHOT_REQUESTS`: the test writes a request, the job's `simctl io screenshot` writes the file and
/// stands it up with `sips -r 270`, as the first job does with the iPhone's landscape photos), because XCUIScreenshot of a
/// screen turned with `XCUIDevice` keeps the portrait frame buffer unturned and cut to the landscape size (blank-paper's
/// landscape photos of run 43584152837 show a third of the screen, sideways). Without the job's answer the test falls back
/// to XCUIScreenshot and says so (`photo=xcui`).
///
/// The lines the job reads (`span shift pair:`, `span margin shot:`) are appended to `<out>/lines/<device>.txt`, so an app's
/// log line written into the middle of one in xcodebuild's output (the span-shots flake of 11/13 and 11/14) cannot cut it.
/// Every line is also printed with `span-shots UI:` or its own mark.
@MainActor
final class SpanShotsUITests: XCTestCase {
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

    /// The canvas at rest: its probe (`InkCanvasView.Coordinator.probeValue()`), its frame and `span.state`'s fields.
    private struct Settled {
        let probe: [String: String]
        let raw: String
        let frame: CGRect
        let state: [String: String]
    }

    private static let japanese = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    /// The languages of the guide's and the setting's photos (l10n-shots' nine and Japanese) with their regions; the region's
    /// holidays and week start follow (`--screenshot-holidays auto --screenshot-week-start auto`), as in l10n-shots.
    private static let languages: [(language: String, region: String)] = [
        ("ja", "ja_JP"), ("en", "en_US"), ("zh-Hans", "zh_CN"), ("zh-Hant", "zh_TW"), ("ko", "ko_KR"),
        ("fr", "fr_FR"), ("de", "de_DE"), ("es", "es_MX"), ("it", "it_IT"), ("pt-BR", "pt_BR"),
    ]
    /// The paper's width in lu (week 1,400, day 1,000), when the probe has no `pw`.
    private static let paperWidth = ["week": 1_400.0, "day": 1_000.0]
    /// How long a photo waits after the screen has settled (s): the sticky heading follows the canvas's report on a later
    /// turn (`BlankPaperShotsUITests.photoWait`).
    private let photoWait: TimeInterval = 1

    // MARK: The tests

    func testBands() throws {
        let setup = try setup()
        defer { XCUIDevice.shared.orientation = .portrait }
        let orientations: [UIDeviceOrientation] = setup.device == "iphone" ? [.portrait, .landscapeLeft] : [.portrait]
        for orientation in orientations {
            for kind in ["week", "day"] {
                for (variant, extra) in [("boundary", ["--screenshot-offset-x", "-0.5"]), ("overview", [String]())] {
                    band(setup, name: "\(setup.device)-\(Self.name(orientation))-\(kind)-\(variant)", orientation: orientation,
                         arguments: ["--screenshot-page", kind, "--screenshot-span", "on"] + extra)
                }
            }
        }
        if setup.device == "ipad11" {
            band(setup, name: "ipad11-portrait-week-sunday", orientation: .portrait,
                 arguments: ["--screenshot-page", "week", "--screenshot-span", "on", "--screenshot-week-start", "sunday",
                             "--screenshot-offset-x", "-0.5"])
        }
    }

    func testShiftPairs() throws {
        let setup = try setup()
        guard ["ipad11", "iphone"].contains(setup.device) else {
            throw XCTSkip("the shift pairs are taken on the iPad Air 11-inch and the iPhone 17")
        }
        XCUIDevice.shared.orientation = .portrait
        for kind in ["week", "day"] {
            shiftPair(setup, kind: kind)
        }
    }

    func testOldVersionMargins() throws {
        let setup = try setup()
        defer { XCUIDevice.shared.orientation = .portrait }
        let plan: [(UIDeviceOrientation, String)]
        if setup.isPad {
            plan = [(.portrait, "week"), (.portrait, "day"), (.landscapeLeft, "week"), (.landscapeLeft, "day")]
        } else if setup.device == "iphone" {
            plan = [(.portrait, "day"), (.landscapeLeft, "week"), (.landscapeLeft, "day")]
        } else {
            throw XCTSkip("no margin photos on \(setup.device)")
        }
        for (orientation, kind) in plan {
            for variant in ["single", "control"] {
                margin(setup, kind: kind, orientation: orientation, variant: variant)
            }
        }
    }

    func testLanguages() throws {
        let setup = try setup()
        guard ProcessInfo.processInfo.environment["TEGAKI_SPAN_SHOT_LANGUAGES"] == "1" else {
            throw XCTSkip("the language photos are taken on r13 and the integration branch only (C3-m1)")
        }
        guard setup.device == "iphone" else { throw XCTSkip("the language photos are taken on the iPhone 17 only") }
        XCUIDevice.shared.orientation = .portrait
        let notices = stageTwoNotices()
        record(setup, "span-shots UI: the N-8 texts read from the string catalogue: \(notices.count)")
        for (language, region) in Self.languages {
            let arguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", region,
                             "--screenshot-holidays", "auto", "--screenshot-week-start", "auto"]
            let folder = "lang/\(language)"
            settingsPhoto(setup, folder: folder, language: arguments)
            for kind in ["week", "day"] {
                for fingers in ["one", "two"] {
                    guidePhoto(setup, folder: folder, language: arguments, kind: kind, fingers: fingers)
                }
            }
            stageTwoPhoto(setup, folder: folder, language: arguments, text: notices[language])
        }
    }

    // MARK: The photos

    /// One band photo: the joined path open (`path=span`) and settled.
    private func band(_ setup: Setup, name: String, orientation: UIDeviceOrientation, arguments: [String]) {
        XCUIDevice.shared.orientation = orientation
        let app = launch(arguments)
        defer { app.terminate() }
        if waitForState(app, timeout: 45, { $0["path"] == "span" }) == nil {
            XCTFail("\(name): span.state never read path=span")
        }
        let view = settled(app, withState: true)
        if view == nil { XCTFail("\(name): the canvas never settled") }
        Thread.sleep(forTimeInterval: photoWait)
        let photo = takePhoto(app, setup, file: "\(name).png", turned: orientation != .portrait)
        record(setup, "span-shots UI: \(name) photo=\(photo.how) window=\(Self.text(app.windows.firstMatch.frame)) "
            + "frame=\(Self.text(view?.frame ?? .zero)) state=\(stateLabel(app)) probe=\(view?.raw ?? "-")")
    }

    /// One pair before and after a shift (C3-M4), in one launch.
    private func shiftPair(_ setup: Setup, kind: String) {
        let base = "\(setup.device)-portrait-shift-\(kind)"
        let app = launch(["--screenshot-page", kind, "--screenshot-span", "on", "--screenshot-span-shift"])
        defer { app.terminate() }
        guard waitForState(app, timeout: 45, { $0["path"] == "span" && $0["hold"] == "on" }) != nil else {
            XCTFail("\(base): span.state never read path=span with hold=on")
            record(setup, "span-shots UI: \(base): no hold; state=\(stateLabel(app))")
            return
        }
        guard let before = settled(app, withState: true), before.state["hold"] == "on" else {
            XCTFail("\(base): the window did not settle while held")
            record(setup, "span-shots UI: \(base): not settled while held; state=\(stateLabel(app))")
            return
        }
        Thread.sleep(forTimeInterval: photoWait)
        let titleBefore = element(app, "page.title").label
        let statusBottom = element(app, "span.state").frame.minY
        let first = takePhoto(app, setup, file: "\(base)-before.png", turned: false)
        // Still held and not shifted after the photo (a version may move without a shift: the now line's 30 s, C3-m5).
        let held = fields(stateLabel(app))
        if held["hold"] != "on" || held["shifts"] != before.state["shifts"] {
            XCTFail("\(base): the window shifted while 'before' was taken (hold=\(held["hold"] ?? "?"), shifts=\(held["shifts"] ?? "?"))")
        }
        // The tap releases the hold (C3-M4); the hold's 60 s ceiling releases it too, so a tap that missed only takes longer.
        let release = element(app, "span.release")
        if release.waitForExistence(timeout: 10) {
            release.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            XCTFail("\(base): no span.release")
        }
        var released = "timer"
        if waitForState(app, timeout: 5, { $0["hold"] == "off" }) != nil { released = "tap" }
        guard waitForState(app, timeout: 75, { $0["shifts"] == "1" && $0["hold"] == "off" }) != nil,
              let after = settled(app, withState: true), after.state["shifts"] == "1" else {
            XCTFail("\(base): the window never shifted once (state \(stateLabel(app)))")
            record(setup, "span-shots UI: \(base): no shift; state=\(stateLabel(app))")
            return
        }
        Thread.sleep(forTimeInterval: photoWait)
        let titleAfter = element(app, "page.title").label
        let second = takePhoto(app, setup, file: "\(base)-after.png", turned: false)
        let window = app.windows.firstMatch.frame
        let scale = window.width > 0 && first.pixelWidth > 0 ? CGFloat(first.pixelWidth) / window.width : 0
        // The rows left out (pixels, both ends included): the strict compare everything above the canvas and one row more
        // (the status bar, the heading, the sticky heading and the all-day band, C3-m3 (b)); the loose one the status bar only.
        // Both photos' band rows when the band's height changed; the paper below then moved too, and the pair differs.
        let canvasTop = max(before.frame.minY, after.frame.minY)
        let strict = Int((canvasTop * scale).rounded(.up)) + 1
        let loose = max(0, Int((statusBottom * scale).rounded(.up)) - 1)
        let band = before.frame == after.frame ? "same" : "moved"
        if scale <= 0 { XCTFail("\(base): the photo's scale is unknown") }
        record(setup, "span-shots UI: \(base) title=\(titleBefore) | \(titleAfter) before=\(before.state["version"] ?? "?") "
            + "after=\(after.state["version"] ?? "?") focus=\(before.state["focus"] ?? "?")→\(after.state["focus"] ?? "?") first=\(before.state["first"] ?? "?")→\(after.state["first"] ?? "?")")
        record(setup, "span shift pair: device=\(setup.device) kind=\(kind) before=\(first.file) after=\(second.file) "
            + "strict=0-\(strict) loose=0-\(loose) scale=\(Self.number(scale)) canvas=\(Self.text(before.frame))|\(Self.text(after.frame)) "
            + "band=\(band) title=\(titleBefore == titleAfter ? "same" : "changed") released=\(released)")
    }

    /// One margin photo of the old versions' view (`single`) or its control.
    private func margin(_ setup: Setup, kind: String, orientation: UIDeviceOrientation, variant: String) {
        let name = "\(setup.device)-\(Self.name(orientation))-margin-\(kind)-\(variant)"
        XCUIDevice.shared.orientation = orientation
        let app = launch(["--screenshot-page", kind] + (variant == "single" ? ["--screenshot-single-page"] : []))
        defer { app.terminate() }
        if variant == "single" {
            // One page (span.state path=one, origin 0): the page itself with the halves it owns.
            if waitForState(app, timeout: 45, { $0["path"] == "one" }) == nil {
                XCTFail("\(name): span.state never read path=one")
            }
        }
        guard let view = settled(app, withState: false) else {
            XCTFail("\(name): the canvas never settled")
            record(setup, "span-shots UI: \(name): not settled")
            return
        }
        Thread.sleep(forTimeInterval: photoWait)
        let photo = takePhoto(app, setup, file: "\(name).png", turned: orientation != .portrait)
        let window = app.windows.firstMatch.frame
        let turned = orientation == .portrait ? "-" : (window.width > window.height ? "yes" : "no")
        let paper = view.probe["pw"].flatMap { Double($0) } ?? Self.paperWidth[kind] ?? 0
        record(setup, "span margin shot: device=\(setup.device) kind=\(kind) orientation=\(Self.name(orientation)) variant=\(variant) "
            + "file=\(photo.file) window=\(Self.number(window.width))x\(Self.number(window.height)) frame=\(Self.text(view.frame)) "
            + "zoom=\(view.probe["zoom"] ?? "?") ox=\(view.probe["ox"] ?? "?") paper=\(Self.number(CGFloat(paper))) photo=\(photo.how) turned=\(turned)")
    }

    /// 設定 › ページ with the switch on.
    private func settingsPhoto(_ setup: Setup, folder: String, language: [String]) {
        let name = "\(folder)/iphone-portrait-settings-page"
        let app = launch(["--screenshot-settings-section", "page", "--screenshot-span", "on"], language: language)
        defer { app.terminate() }
        let toggle = element(app, "settings.pageSpan")
        if toggle.waitForExistence(timeout: 30) {
            _ = stableFrame(of: toggle)
        } else {
            XCTFail("\(name): no switch settings.pageSpan")
        }
        Thread.sleep(forTimeInterval: photoWait)
        let photo = takePhoto(app, setup, file: "\(name).png", turned: false)
        let value = toggle.value as? String ?? "?"
        if value != "1" { XCTFail("\(name): the switch reads \(value), not on") }
        record(setup, "span-shots UI: \(name) photo=\(photo.how) switch=\(value) frame=\(Self.text(toggle.frame)) l10n=\(element(app, "l10n.state").label)")
    }

    /// The first-time guide's card (`span.guide`) over a joined week or day.
    private func guidePhoto(_ setup: Setup, folder: String, language: [String], kind: String, fingers: String) {
        let name = "\(folder)/iphone-portrait-guide-\(kind)-\(fingers)"
        let app = launch(["--screenshot-page", kind, "--screenshot-span", "on", "--screenshot-span-guide", fingers], language: language)
        defer { app.terminate() }
        if waitForState(app, timeout: 45, { $0["path"] == "span" }) == nil { XCTFail("\(name): span.state never read path=span") }
        let card = element(app, "span.guide")
        if !card.waitForExistence(timeout: 30) { XCTFail("\(name): no card span.guide") }
        _ = settled(app, withState: true)
        Thread.sleep(forTimeInterval: photoWait)
        let photo = takePhoto(app, setup, file: "\(name).png", turned: false)
        if !card.exists { XCTFail("\(name): the card went before the photo") }
        record(setup, "span-shots UI: \(name) photo=\(photo.how) card=\(Self.text(card.frame)) \(card.label.prefix(40))")
    }

    /// Stage 2's notice N-8 (a toast of 20 s): taken once its text is on the screen, and again once when it was gone after.
    private func stageTwoPhoto(_ setup: Setup, folder: String, language: [String], text: String?) {
        let name = "\(folder)/iphone-portrait-stage-two"
        for take in 1...2 {
            let app = launch(["--screenshot-page", "week", "--screenshot-span-guide", "stage-two"], language: language)
            defer { app.terminate() }
            _ = settled(app, withState: false)
            var toast: XCUIElement?
            if let text, !text.isEmpty {
                let found = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", String(text.prefix(12)))).firstMatch
                if found.waitForExistence(timeout: 20) {
                    toast = found
                } else {
                    XCTFail("\(name): the notice's text never came")
                }
            } else {
                // No text to look for (the string catalogue was not given): the toast comes 0.5 s after the canvas appeared.
                Thread.sleep(forTimeInterval: 2)
            }
            let photo = takePhoto(app, setup, file: "\(name).png", turned: false)
            let shown = toast?.exists ?? true
            record(setup, "span-shots UI: \(name) photo=\(photo.how) take=\(take) text=\(text == nil ? "not checked" : (shown ? "shown" : "gone"))")
            if shown { return }
        }
        XCTFail("\(name): the notice was gone when its photo was taken, twice")
    }

    // MARK: Taking a photo

    /// Writes `file` (a path under the output folder). Portrait: the app's screenshot. Turned: the job's simulator photo,
    /// else the app's screenshot (`photo=xcui`, cut as the class's comment says).
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

    /// Asks the job for `simctl io screenshot` of the simulator, stood up (`sips -r 270`), written to `file`: a request file
    /// in `TEGAKI_SPAN_SHOT_REQUESTS` (written whole, then renamed) and the job's answer `<request>.done` ("ok" or "failed").
    /// False without the folder, or without an answer in 90 s.
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
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return Setup(out: folder, device: device)
    }

    /// One launch in screenshot mode on 2026-10 (the 7th, a Wednesday) with the probe, in Japanese unless `language` says.
    private func launch(_ arguments: [String], language: [String]? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe"] + arguments
            + (language ?? Self.japanese)
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

    /// The canvas once two reads 0.5 s apart agree on the probe's zoom and offset, the canvas's frame and (`withState`)
    /// `span.state`'s path, window, version, hold and shifts — the "version read twice" of C3-M4. nil at the timeout.
    private func settled(_ app: XCUIApplication, withState: Bool, timeout: TimeInterval = 30) -> Settled? {
        let canvas = element(app, "ink-canvas")
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        var last: Settled?
        while Date() < deadline {
            if canvas.exists, let raw = canvas.value as? String, Double(fields(raw)["zoom"] ?? "") ?? 0 > 0 {
                let frame = canvas.frame
                let read: [String: String]? = withState ? (state.exists ? fields(state.label) : nil) : [:]
                if let read, frame.width > 0 {
                    let now = Settled(probe: fields(raw), raw: raw, frame: frame, state: read)
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
            && ["zoom", "ox", "oy"].allSatisfy { a.probe[$0] == b.probe[$0] }
            && ["path", "session", "focus", "first", "pages", "version", "hold", "shifts"].allSatisfy { a.state[$0] == b.state[$0] }
    }

    /// The element's frame once two reads 0.5 s apart agree (a sheet that slid in, a list that scrolled), up to 15 s.
    private func stableFrame(of element: XCUIElement) -> CGRect {
        var last = CGRect.null
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let frame = element.frame
            if frame == last { return frame }
            last = frame
            Thread.sleep(forTimeInterval: 0.5)
        }
        return last
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

    /// The N-8 text of each language (`span.stageTwo.notice` in the string catalogue the job names); empty without it.
    private func stageTwoNotices() -> [String: String] {
        guard let path = ProcessInfo.processInfo.environment["TEGAKI_SPAN_SHOT_STRINGS"], !path.isEmpty,
              let data = FileManager.default.contents(atPath: path),
              let catalogue = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let strings = catalogue["strings"] as? [String: Any],
              let entry = strings["span.stageTwo.notice"] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else { return [:] }
        var texts: [String: String] = [:]
        for (language, value) in localizations {
            guard let unit = (value as? [String: Any])?["stringUnit"] as? [String: Any], let text = unit["value"] as? String else { continue }
            texts[language] = text
        }
        return texts
    }

    // MARK: Writing

    /// A line for the job: printed and logged (`blank UI:`'s way), and appended to `<out>/lines/<device>.txt`.
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

    private static func number(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    /// "x,y,w,h" with one decimal (no spaces: the job splits the lines on them).
    private static func text(_ rect: CGRect) -> String {
        [rect.minX, rect.minY, rect.width, rect.height].map(number).joined(separator: ",")
    }
}
