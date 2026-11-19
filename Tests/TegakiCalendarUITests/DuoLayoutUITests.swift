import UIKit
import XCTest

/// 1.4 (docs/M7D_CONTRACT.md §4.2, §4.3, §4.4, §4.8, §6's row U, §7.3): the iPhone Duo's screens through the real app —
/// the header's rows by the window's width, the joined week sliding with 「指でも書く」 as the toolbar shows it, the sheets
/// fitting, and 「指でも書く」 of a first launch following the hinge (§4.8). The app runs in its screenshot mode (no
/// onboarding, no EventKit, nothing saved; the demo month 2026-10, focus week w-2026-10-05) in Japanese.
///
/// Only on the Duo: `TEGAKI_DEVICE=duo` (xcodebuild hands `TEST_RUNNER_TEGAKI_DEVICE=duo` to the runner without its prefix;
/// duo.yml's duo-shots sets it). Anywhere else — build.yml's UI test step on the iPhone 17, an iPad — every test skips
/// (`XCTSkip`), so the count of the UI tests there leaves them out (§3.10).
///
/// The screen (§4.2's roads): road 3, the default until 11/23, is the outer screen only — the simulator starts closed and
/// nothing opens it. `TEGAKI_DUO_INNER=1` (`TEST_RUNNER_TEGAKI_DUO_INNER=1`) says the job opened the inner screen before the
/// run (roads 1 and 2): the inner screen's tests run then and the outer screen's skip, and without it the other way round.
/// Each test checks the window is on the side of `wideShortSide` (600 pt, `WindowClass.wideShortSide`) its screen should be
/// (§4.2: not wide outside, wide inside; the other side stops the work, §4.7).
///
/// What runs (duo-shots' declared number, §4.2): road 3, the outer screen: 4 — `testOuterHeaderRows`,
/// `testJoinedWeekSwipesOnDuo`, `testSheetsFitOnDuo`, `testFingerDefaultFollowsTheHinge`. Roads 1 and 2 add 4 in the run with
/// the inner screen open — `testInnerHeaderIsOneRow` and the last three on the inner screen — 8 in all.
///
/// XCUITest has no two-finger drag (its public drags are one finger in a straight line, as SpanUITests says), so the slide
/// with 「指でも書く」 on is checked as what one finger does then (it writes, the page stays); the two-finger slide stays with
/// the owner's Duo (§10). The steps are the `duo UI:` lines.
@MainActor
final class DuoLayoutUITests: XCTestCase {
    /// The Duo's two screens.
    private enum Screen: String {
        case outer, inner
    }

    /// `WindowClass.wideShortSide` (pt): the least short side of a wide window (§4.3, §4.4, §4.7).
    private static let wideShortSide: CGFloat = 600
    private static let focusWeek = "w-2026-10-05"
    private static let nextWeek = "w-2026-10-12"
    /// The week page's width (lu, `PaperSpec.weekWidth`): one page of the band.
    private static let weekWidth: CGFloat = 1400
    private static let fingerLabel = "指でも書く"
    private static let todayLabel = "今日"
    /// `header.picker.spoken`: the 日/週/月/年 switch.
    private static let pickerLabel = "表示の切替"

    /// §4.2's answers, written here before the run that checks them (§6: the expectation is decided beforehand by §4.8's
    /// rule): `PencilPhone.usesHinge`, and for each screen whether its `duo measure:` line reads a hinge (`hinge=` other than
    /// `nil`). 「指でも書く」 of a first launch is off where both hold, on elsewhere. Until D1's first duo-shots has measured
    /// them `usesHinge` is false (the Pencil-only road, §4.8), so it is on on both screens; the measured answers go here in
    /// the commit that sets `PencilPhone.usesHinge`.
    private static let usesHinge = false
    private static let hingeRead: [Screen: Bool] = [.outer: false, .inner: false]

    // MARK: - Tests

    /// The outer screen in portrait is narrower than `CalendarRootScreen.compactWidth` (600): the header's two rows, the
    /// 日/週/月/年 switch on the second row under 「今日」 (`PageHeaderView`'s compact rows).
    func testOuterHeaderRows() throws {
        try requireScreen(.outer)
        continueAfterFailure = false
        let name = "outer header"
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week"], name)
        defer { app.terminate() }
        guard let header = headerFrames(app, name) else { return }
        checkWindow(app, .outer, name)
        keepScreenshot(app, "\(name)")
        XCTAssertGreaterThanOrEqual(header.picker.minY, header.today.maxY - 0.5,
                                    "\(name): two rows, the switch \(header.picker) under 「今日」 \(header.today)")
        log("\(name): OK")
    }

    /// The inner screen (roads 1 and 2 only) is wide: the header's one row, the switch beside 「今日」.
    func testInnerHeaderIsOneRow() throws {
        try requireScreen(.inner)
        continueAfterFailure = false
        let name = "inner header"
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week"], name)
        defer { app.terminate() }
        guard let header = headerFrames(app, name) else { return }
        checkWindow(app, .inner, name)
        keepScreenshot(app, "\(name)")
        XCTAssertLessThan(header.picker.minY, header.today.maxY, "\(name): one row (switch \(header.picker), 「今日」 \(header.today))")
        XCTAssertGreaterThan(header.picker.maxY, header.today.minY, "\(name): one row (switch \(header.picker), 「今日」 \(header.today))")
        log("\(name): OK")
    }

    /// The joined week (`--screenshot-span on`) with 「指でも書く」 pinned through UserDefaults' argument domain (the value and
    /// the mark "person", so `FingerDefault` leaves it as launched) and read back from the toolbar. Off (the Duo's default
    /// with the Pencil, §4.8): one finger 85 % of a page across the middle (at most 80 % of the canvas, slowly, held at the
    /// end) stops the paper on the next week, and the title changes once, to 10/12's week. On: the same finger writes a line
    /// (one stroke more in the canvas's probe) and the page and its title stay.
    func testJoinedWeekSwipesOnDuo() throws {
        let screen = try currentScreen()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        // 「指でも書く」 off: one finger slides the band.
        do {
            let name = "slide \(screen.rawValue) finger off"
            let app = launch(joined(fingerDraws: false), name)
            defer { app.terminate() }
            guard let start = waitForJoined(app, name) else { return }
            checkWindow(app, screen, name)
            XCTAssertEqual(fingerSwitch(app, name), false, "\(name): the toolbar shows 「指でも書く」 off")
            XCTAssertEqual(start.state["focus"], Self.focusWeek, "\(name): the focus week")
            let title = titleElement(app)
            XCTAssertTrue(title.waitForExistence(timeout: 5), "\(name): the page title")
            let before = title.label
            XCTAssertTrue(Self.isWeek(of: "10", "5", before), "\(name): the title of 10/5's week (「\(before)」)")

            let frame = start.frame
            let page = Self.weekWidth * start.zoom
            let distance = min(page * 0.85, frame.width * 0.8)
            guard distance > page * 0.62 else {
                return XCTFail("\(name): a page (\(page) pt) is too wide for one drag in the canvas \(frame)")
            }
            let from = CGPoint(x: frame.midX + distance / 2, y: frame.midY)
            let to = CGPoint(x: frame.midX - distance / 2, y: frame.midY)
            var titles = [before]
            var settled: Joined?
            for attempt in 1...2 {
                waitUntilResponsive(canvasElement(app))
                let took = drag(app, from: from, to: to, velocity: 400, hold: 0.3)
                log("\(name): moved the paper \(from) → \(to) (attempt \(attempt), \(seconds(took)); page \(Int(page)) pt)")
                settled = waitForNextWeek(app, after: start, titles: &titles, name)
                if settled != nil { break }
                // The synthesized drag can fall short (review C2-SHOTS-2): once more, only when the focus did not move.
                guard let now = joinedState(app), now.state["focus"] == Self.focusWeek, attempt == 1 else { break }
                log("\(name): the paper stopped on the same week (span.state \(now.raw)); dragging once more")
            }
            keepScreenshot(app, "\(name) — after")
            log("\(name): the titles \(titles); span.state \(settled?.raw ?? stateLabel(app))")
            guard settled != nil else {
                return XCTFail("\(name): the paper did not stop on the next week with the window shifted (span.state \(stateLabel(app)); titles \(titles))")
            }
            XCTAssertEqual(titles.count, 2, "\(name): the title changed once (\(titles))")
            XCTAssertTrue(Self.isWeek(of: "10", "12", titles.last ?? ""), "\(name): to 10/12's week (\(titles))")
        }

        // 「指でも書く」 on: one finger writes; the page stays.
        do {
            let name = "slide \(screen.rawValue) finger on"
            let app = launch(joined(fingerDraws: true), name)
            defer { app.terminate() }
            guard let start = waitForJoined(app, name) else { return }
            XCTAssertEqual(fingerSwitch(app, name), true, "\(name): the toolbar shows 「指でも書く」 on")
            let title = titleElement(app)
            XCTAssertTrue(title.waitForExistence(timeout: 5), "\(name): the page title")
            let before = title.label
            let frame = start.frame
            let from = CGPoint(x: frame.midX + frame.width * 0.2, y: frame.midY)
            let to = CGPoint(x: frame.midX - frame.width * 0.2, y: frame.midY)
            waitUntilResponsive(canvasElement(app))
            let took = drag(app, from: from, to: to, velocity: 250, hold: 0.05)
            log("\(name): one finger \(from) → \(to) (\(seconds(took)))")
            let drawn = waitUntil(timeout: 6) { (self.joinedState(app)?.pk ?? -1) == start.pk + 1 } != nil
            Thread.sleep(forTimeInterval: 2)
            keepScreenshot(app, "\(name) — after")
            let now = joinedState(app)
            log("\(name): span.state \(now?.raw ?? "-"); probe pk \(now?.pk ?? -1) (was \(start.pk)); the title 「\(title.label)」")
            XCTAssertTrue(drawn, "\(name): one finger wrote a line (pk \(start.pk) → \(now?.pk ?? -1))")
            XCTAssertEqual(now?.state["focus"], Self.focusWeek, "\(name): the page stayed")
            XCTAssertEqual(title.label, before, "\(name): the title stayed")
        }
    }

    /// The sheets on this screen (§4.4, §7.3): the event sheet (`--screenshot-sheet create`) shows 「保存」 and 「キャンセル」 on
    /// the screen and hittable without scrolling; the purchase sheet (`--screenshot-sheet paywall`) reaches its EULA row and
    /// the bottom 「あとで」 on the screen (sent up as LanguageUITests does when they are below the fold). Every phone window
    /// is `.large` while `WindowClass.formSheetOnWide` is false. On the inner screen the line `formSheetOnWide criteria`
    /// records §4.4's (a) (the EULA row and 「あとで」 without scrolling) and (b) (「保存」 and 「キャンセル」) for the lead's
    /// decision; (b) is checked, (a) only recorded (it decides the constant, it is not a fault of today's `.large`).
    func testSheetsFitOnDuo() throws {
        let screen = try currentScreen()
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        var criterionB = false
        do {
            let name = "event sheet \(screen.rawValue)"
            let app = launch(["--screenshot-month", "2026-10", "--screenshot-sheet", "create"], name)
            defer { app.terminate() }
            let save = app.buttons["保存"]
            let cancel = app.buttons["キャンセル"]
            XCTAssertTrue(save.waitForExistence(timeout: 30), "\(name): 「保存」")
            XCTAssertTrue(cancel.waitForExistence(timeout: 5), "\(name): 「キャンセル」")
            checkWindow(app, screen, name)
            let window = app.windows.firstMatch.frame
            keepScreenshot(app, name)
            log("\(name): window \(window) 保存 \(save.frame) hittable=\(save.isHittable) キャンセル \(cancel.frame) hittable=\(cancel.isHittable)")
            for (label, button) in [("保存", save), ("キャンセル", cancel)] {
                XCTAssertTrue(button.isHittable, "\(name): 「\(label)」 can be tapped")
                XCTAssertTrue(window.contains(button.frame), "\(name): 「\(label)」 lies on the screen: \(button.frame)")
            }
            criterionB = save.isHittable && cancel.isHittable && window.contains(save.frame) && window.contains(cancel.frame)
        }
        do {
            let name = "purchase sheet \(screen.rawValue)"
            let app = launch(["--screenshot-month", "2026-10", "--screenshot-sheet", "paywall"], name)
            defer { app.terminate() }
            let eula = app.buttons["paywall.eula"]
            let later = app.buttons["paywall.laterBottom"]
            XCTAssertTrue(app.buttons["paywall.restore"].waitForExistence(timeout: 30), "\(name): the purchase sheet is up")
            checkWindow(app, screen, name)
            let window = app.windows.firstMatch.frame
            func reached(_ element: XCUIElement) -> Bool { element.exists && element.isHittable && window.contains(element.frame) }
            let withoutScrolling = reached(eula) && reached(later)
            keepScreenshot(app, "\(name) — top")
            var drags = 0
            while drags < 6, !(reached(eula) && reached(later)) {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
                drags += 1
            }
            keepScreenshot(app, "\(name) — bottom")
            log("\(name): window \(window); \(drags) drags; EULA \(eula.frame) hittable=\(eula.isHittable); あとで \(later.frame) hittable=\(later.isHittable)")
            XCTAssertTrue(reached(eula), "\(name): the EULA row lies on the screen and can be tapped (\(eula.frame))")
            XCTAssertTrue(reached(later), "\(name): the bottom 「あとで」 lies on the screen and can be tapped (\(later.frame))")
            if screen == .inner {
                log("formSheetOnWide criteria: a=\(withoutScrolling ? "○" : "×") (the EULA row and 「あとで」 without scrolling) b=\(criterionB ? "○" : "×") (「保存」 and 「キャンセル」)")
            }
        }
    }

    /// A first launch (`-allowFingerDrawingChosen NO`: `appear()` writes the phone's default, on, and its mark of this device)
    /// without `--screenshot-pencil-phone`: 「指でも書く」 as the toolbar shows it once the hinge had its time (§4.8; no Pencil
    /// touches a simulator, so only H can change it) is off when `usesHinge` and this screen reads a hinge, on otherwise.
    /// UserDefaults' argument domain is not given the mark (`-allowFingerDrawingAuto ""`, §2.1): an argument shadows the mark
    /// `appear()` writes, so the launch would read as carried over from 1.3 and the hinge could never turn it off.
    func testFingerDefaultFollowsTheHinge() throws {
        let screen = try currentScreen()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let name = "finger default \(screen.rawValue)"
        let expected = !(Self.usesHinge && (Self.hingeRead[screen] ?? false))
        let app = launch(["--screenshot-month", "2026-10", "--screenshot-page", "week", "-allowFingerDrawingChosen", "NO"], name)
        defer { app.terminate() }
        let toggle = fingerElement(app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 30), "\(name): the toolbar's 「指でも書く」")
        checkWindow(app, screen, name)
        // The hinge answers within 2 s of the window (`PencilPhone`'s wait) and nothing touches: read it for at least 4 s
        // and until it has held one value for 2 s, at most 10 s.
        var values: [Bool?] = []
        var last: Bool?
        let started = Date()
        var heldSince = started
        while Date().timeIntervalSince(started) < 10 {
            let value = isOn(toggle)
            if values.isEmpty || value != last {
                values.append(value)
                last = value
                heldSince = Date()
            } else if value != nil, Date().timeIntervalSince(heldSince) >= 2, Date().timeIntervalSince(started) >= 4 {
                break
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        keepScreenshot(app, name)
        log("\(name): usesHinge=\(Self.usesHinge) hingeRead=\(Self.hingeRead[screen] ?? false) expected \(expected ? "on" : "off"); read \(values.map { $0.map { $0 ? "on" : "off" } ?? "?" }) (\(String(describing: toggle.value)), selected=\(toggle.isSelected))")
        XCTAssertEqual(last, expected, "\(name): 「指でも書く」 is \(expected ? "on" : "off") (§4.8)")
    }

    // MARK: - The screen

    /// The screen this run is on; skips off the Duo.
    private func currentScreen() throws -> Screen {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TEGAKI_DEVICE"] == "duo" else {
            throw XCTSkip("the iPhone Duo's tests (TEST_RUNNER_TEGAKI_DEVICE=duo, duo.yml)")
        }
        return environment["TEGAKI_DUO_INNER"] == "1" ? .inner : .outer
    }

    /// Skips unless this run is on `screen`.
    private func requireScreen(_ screen: Screen) throws {
        let now = try currentScreen()
        guard now == screen else {
            throw XCTSkip("a test of the \(screen.rawValue) screen; this run is on the \(now.rawValue) one (TEGAKI_DUO_INNER)")
        }
    }

    /// The app's window is on its screen's side of `wideShortSide` (§4.2, §4.7): the outer screen not wide, the inner wide.
    private func checkWindow(_ app: XCUIApplication, _ screen: Screen, _ name: String) {
        let window = app.windows.firstMatch.frame
        let short = min(window.width, window.height)
        log("\(name): window \(window) (short side \(short), \(screen.rawValue) screen)")
        XCTAssertGreaterThan(short, 0, "\(name): the window")
        switch screen {
        case .outer:
            XCTAssertLessThan(short, Self.wideShortSide, "\(name): the outer screen's window is not wide (§4.2)")
        case .inner:
            XCTAssertGreaterThanOrEqual(short, Self.wideShortSide, "\(name): the inner screen's window is wide (§4.2)")
        }
    }

    // MARK: - The header and the toolbar

    /// 「今日」 and the 日/週/月/年 switch, once the header is there; nil (failed, with the element tree) otherwise.
    private func headerFrames(_ app: XCUIApplication, _ name: String) -> (today: CGRect, picker: CGRect)? {
        let today = app.buttons[Self.todayLabel]
        guard today.waitForExistence(timeout: 30) else {
            XCTFail("\(name): 「今日」. Elements:\n\(app.debugDescription)")
            return nil
        }
        let segmented = app.segmentedControls.firstMatch
        let picker = segmented.exists
            ? segmented
            : app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.pickerLabel)).firstMatch
        guard picker.exists else {
            XCTFail("\(name): the 日/週/月/年 switch. Elements:\n\(app.debugDescription)")
            return nil
        }
        log("\(name): window \(app.windows.firstMatch.frame) 今日 \(today.frame) switch \(picker.frame) (segmented \(segmented.exists))")
        return (today.frame, picker.frame)
    }

    private func fingerElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.fingerLabel)).firstMatch
    }

    /// The toolbar's 「指でも書く」 now (nil when it is not there or its state is not readable).
    private func fingerSwitch(_ app: XCUIApplication, _ name: String) -> Bool? {
        let toggle = fingerElement(app)
        guard toggle.waitForExistence(timeout: 10) else {
            XCTFail("\(name): the toolbar's 「指でも書く」")
            return nil
        }
        let value = isOn(toggle)
        log("\(name): 「指でも書く」 \(value.map { $0 ? "on" : "off" } ?? "?") (\(String(describing: toggle.value)), selected=\(toggle.isSelected))")
        return value
    }

    /// A switch's state: its value ("1" / "0", or a number) as SpanUITests reads it, else a button toggle's selection.
    private func isOn(_ toggle: XCUIElement) -> Bool? {
        guard toggle.exists else { return nil }
        if let text = toggle.value as? String, text == "1" || text == "0" { return text == "1" }
        if let number = toggle.value as? NSNumber { return number.boolValue }
        return toggle.isSelected
    }

    // MARK: - The joined week

    /// The joined week's arguments with 「指でも書く」 pinned (value and mark in the argument domain).
    private func joined(fingerDraws: Bool) -> [String] {
        ["--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-span", "on", "--screenshot-probe",
         "-allowFingerDrawing", fingerDraws ? "YES" : "NO", "-allowFingerDrawingChosen", "YES", "-allowFingerDrawingAuto", "person"]
    }

    private func canvasElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
    }

    private func titleElement(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "page.title").firstMatch
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = app.descendants(matching: .any).matching(identifier: "span.state").firstMatch
        return state.exists ? state.label : "-"
    }

    /// `span.state` (`ScreenPaths.stateLabel`) with the canvas's probe now; nil while either is missing or has no zoom.
    private func joinedState(_ app: XCUIApplication) -> Joined? {
        let label = stateLabel(app)
        let canvas = canvasElement(app)
        guard label != "-", canvas.exists, let probe = canvas.value as? String else { return nil }
        let joined = Joined(raw: label, probe: probe, frame: canvas.frame)
        return joined.zoom > 0 && joined.frame.width > 0 ? joined : nil
    }

    /// The joined window settled (`path=span`, more than one page, two reads 0.3 s apart alike), after a simulator that
    /// answers quickly; nil (failed, with the element tree) otherwise.
    private func waitForJoined(_ app: XCUIApplication, _ name: String) -> Joined? {
        let canvas = canvasElement(app)
        guard canvas.waitForExistence(timeout: 30) else {
            log("\(name): no 「ink-canvas」 element. Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the canvas probe (--screenshot-probe) is missing")
            return nil
        }
        log("\(name): waited \(waitUntilResponsive(canvas)) s for the app to answer quickly")
        let deadline = Date().addingTimeInterval(30)
        var previous: Joined?
        repeat {
            if let now = joinedState(app) {
                if now.state["path"] == "span", now.count("pages") > 1, let previous, previous.isAlike(now) {
                    log("\(name): window \(app.windows.firstMatch.frame) canvas \(now.frame) span.state \(now.raw)")
                    keepScreenshot(app, "\(name) — start")
                    return now
                }
                previous = now
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        log("\(name): Elements:\n\(app.debugDescription)")
        XCTFail("\(name): the joined window did not settle (span.state \(stateLabel(app)))")
        return nil
    }

    /// Reads the title every 0.15 s (each new one appended to `titles`) until the window settled on the next week with a
    /// shift after `start` and 1 s more, at most 20 s. The settled state, or nil.
    private func waitForNextWeek(_ app: XCUIApplication, after start: Joined, titles: inout [String], _ name: String) -> Joined? {
        let title = titleElement(app)
        var previous: Joined?
        var settled: Joined?
        var settledAt: Date?
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            let shown = title.exists ? title.label : ""
            if !shown.isEmpty, shown != titles.last { titles.append(shown) }
            if let now = joinedState(app) {
                let alike = previous.map { $0.isAlike(now) } ?? false
                if now.state["focus"] == Self.nextWeek, now.count("shifts") > start.count("shifts"), alike {
                    settled = now
                    if settledAt == nil { settledAt = Date() }
                } else {
                    settledAt = nil
                }
                previous = now
            }
            if let settledAt, Date().timeIntervalSince(settledAt) >= 1 { break }
            Thread.sleep(forTimeInterval: 0.15)
        }
        if settled == nil { log("\(name): not on the next week within 20 s; span.state \(stateLabel(app))") }
        return settledAt == nil ? nil : settled
    }

    /// 1.2.3's ja week title, compact (「10/5〜10/11」, the outer screen) or not (「2026年10月5日〜10月11日」, the inner one).
    private static func isWeek(of month: String, _ day: String, _ title: String) -> Bool {
        title.hasPrefix("\(month)/\(day)〜") || title.contains("年\(month)月\(day)日〜")
    }

    // MARK: - Launch, gestures, waiting, logs (as SpanUITests)

    private func launch(_ arguments: [String], _ name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"] + arguments + ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        log("\(name): launched \(arguments.joined(separator: " "))")
        return app
    }

    /// One finger: down at `from` (screen points), 0.05 s still, to `to` at `velocity` pt/s, `hold` s still, up. Returns
    /// how long the synthesis took.
    @discardableResult
    private func drag(_ app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat, hold: TimeInterval) -> TimeInterval {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: from.x, dy: from.y))
        let end = origin.withOffset(CGVector(dx: to.x, dy: to.y))
        let started = Date()
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: hold)
        return Date().timeIntervalSince(started)
    }

    /// Seconds until `condition` held (polled every 0.15 s), nil after `timeout`.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> TimeInterval? {
        let start = Date()
        repeat {
            if condition() { return Date().timeIntervalSince(start) }
            Thread.sleep(forTimeInterval: 0.15)
        } while Date().timeIntervalSince(start) < timeout
        return nil
    }

    /// Waits (at most `timeout` seconds) until a query of `element` answers within 1 s (a freshly booted simulator can be
    /// busy for a minute or two). Returns the seconds waited, rounded.
    @discardableResult
    private func waitUntilResponsive(_ element: XCUIElement, timeout: TimeInterval = 60) -> Int {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let queried = Date()
            _ = element.frame
            if Date().timeIntervalSince(queried) < 1 { break }
            Thread.sleep(forTimeInterval: 1)
        }
        return Int(Date().timeIntervalSince(start).rounded())
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.2f s", value)
    }

    private func log(_ line: String) {
        print("duo UI: \(line)")
        NSLog("duo UI: %@", line)
    }
}

// MARK: - What the screen reads out

/// One read of `span.state` (`key=value;…`, `ScreenPaths.stateLabel`) with the canvas's probe of the same moment
/// (`InkCanvasView.Coordinator.probeValue()`: `zoom`, `ox`, `oy`, `pk`, `ink`, …).
private struct Joined {
    let raw: String
    let state: [String: String]
    let probe: [String: String]
    let frame: CGRect

    init(raw: String, probe: String, frame: CGRect) {
        self.raw = raw
        state = Joined.fields(raw)
        self.probe = Joined.fields(probe)
        self.frame = frame
    }

    /// `key=value` pairs joined by `;` (a value may hold `=` and `:`).
    private static func fields(_ raw: String) -> [String: String] {
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        return values
    }

    func count(_ key: String) -> Int { state[key].flatMap { Int($0) } ?? -1 }
    var zoom: CGFloat { probe["zoom"].flatMap { Double($0) }.map { CGFloat($0) } ?? 0 }
    var pk: Int { probe["pk"].flatMap { Int($0) } ?? -1 }

    /// The same window and paper: `span.state` as a whole and the probe's zoom, offset and strokes, and the frame.
    func isAlike(_ other: Joined) -> Bool {
        raw == other.raw && frame == other.frame && ["zoom", "ox", "oy", "pk", "ink"].allSatisfy { probe[$0] == other.probe[$0] }
    }
}
