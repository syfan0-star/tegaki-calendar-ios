import UIKit
import XCTest

/// 1.3 (docs/M7C_CONTRACT.md §3.6, §3.7, §3.14, §10.3; the wave plan §3.3, §7.5): the joined week on an iPhone through
/// UIKit, PencilKit and the real SwiftUI screen — what the unit tests of `ScreenPaths` and the canvas cannot touch. A
/// finger line across the boundary keeps its points beyond its page, a slide of the paper changes the title once, ◀ ▶
/// slide on the same canvas, and the setting 「前後のページを横につなげる」 switches between one page and the joined pages.
///
/// The app runs in its screenshot mode (no onboarding, no EventKit, nothing saved; the demo month 2026-10, focus week
/// w-2026-10-05, Monday to Sunday) with `--screenshot-span on` (the joined path and its demo pages, the crossing demo
/// among them) and `--screenshot-probe`. Two invisible elements read the screen out: the canvas's probe `ink-canvas`
/// (`zoom`, the content offset `ox` / `oy` in band points, the band's `pk` / `ink` strokes) and the screen's `span.state`
/// (`ScreenPaths.stateLabel`: `path=span|one|erasing;session;kind;focus;origin` — the focus page's left edge in the band,
/// lu —`;first;pages;version;shifts;stops;hold;last=<page>:<cell>:minx=…:maxx=…`, the newest stroke of the window's
/// pages as its page keeps it). A band point (lu) is on screen at frame.minX + x · zoom − ox, frame.minY + y · zoom − oy;
/// a page's x is `origin` further in the band. Every test waits for `path=span` and for the window to settle (two reads
/// alike: the neighbours are read after the focus page) before it acts, and logs each step (`span UI:` lines).
///
/// XCUITest has no two-finger gesture (its public drags are one finger in a straight line), so a slide here is one
/// finger with 「指でも書く」 off; the two-finger slide and pinch with 「指でも書く」 on stay with the owner's TestFlight
/// check (§11.3 12, 13). An iPhone only (the UI test step's iPhone 17); elsewhere these skip.
@MainActor
final class SpanUITests: XCTestCase {
    private static let focusWeek = "w-2026-10-05"
    private static let leftWeek = "w-2026-09-28"
    private static let nextWeek = "w-2026-10-12"
    /// The week page's width (lu, `PaperSpec.weekWidth`): one page of the band.
    private static let weekWidth: CGFloat = 1400
    /// The week's hour (lu, `PaperSpec.weekHourHeight`).
    private static let weekHour: CGFloat = 80
    /// A gesture whose synthesis took longer than this (s) beyond its own length met an overloaded simulator
    /// (YearTapUITests): it is tried once more.
    private let slowGesture: TimeInterval = 2.5

    // MARK: - Tests

    /// 「指でも書く」 on, the focus week's left boundary in the middle (`--screenshot-offset-x -0.5`): one finger from
    /// Sunday 10/4's column of the left week (150 lu left of the boundary) to Monday 10/5's (190 lu right of it) at 2:00 —
    /// clear of the crossing demo, which runs from 21:00 to 6:40 across the same boundary. One stroke more on the canvas, and the
    /// window's newest stroke (`last=`) is that line in its owner's `grid` with its points beyond the page: x < 0 when the
    /// right page (10/5's week) holds it, x > 1,400 when the left one does (D15: the page of its centre, here 20 lu right
    /// of the boundary). Not cut at the boundary and not split in two.
    func testFingerLineAcrossTheBoundaryKeepsItsPointsBeyondThePage() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        let name = "line across"
        let app = launch(["--screenshot-offset-x", "-0.5"], fingerDraws: true, name)
        guard let start = waitForJoined(app, name) else { return }
        XCTAssertEqual(start.state["focus"], Self.focusWeek, "\(name): the focus week")
        let y = 2 * Self.weekHour
        let from = start.probe.screen(CGPoint(x: start.origin - 150, y: y))
        let to = start.probe.screen(CGPoint(x: start.origin + 190, y: y))
        let boundary = start.probe.screen(CGPoint(x: start.origin, y: y))
        log("\(name): the boundary at \(boundary) (the canvas's middle \(start.probe.frame.midX)); the line \(from) → \(to)")
        let inside = start.probe.frame.insetBy(dx: 4, dy: 4)
        guard inside.contains(from), inside.contains(to) else {
            return XCTFail("\(name): the line \(from) → \(to) is outside the canvas \(start.probe.frame)")
        }

        let length = hypot(to.x - from.x, to.y - from.y)
        var drawn: Snapshot?
        for attempt in 1...2 {
            waitUntilResponsive(canvasElement(in: app))
            let took = drag(in: app, from: from, to: to, velocity: 250)
            drawn = waitFor(app, timeout: 6, "\(name): the line") {
                $0.probe.pk == start.probe.pk + 1 && $0.probe.ink == start.probe.ink + 1 && $0.state["last"] != start.state["last"]
            }
            log("\(name): drew (attempt \(attempt), \(seconds(took))): \(drawn != nil ? "1 stroke more" : "NOT drawn")")
            if drawn != nil || took <= length / 250 + 0.2 + slowGesture { break }
            log("\(name): RETRY the line (the simulator was overloaded)")
        }
        keepScreenshot(app, "\(name) — after")
        guard let drawn else {
            return XCTFail("\(name): a finger stroke with the pen did not add a line (probe \(probe(app)?.raw ?? "-"); span.state \(stateLabel(app)))")
        }
        attach(drawn.stateRaw, "\(name) — span.state")
        guard let last = Newest(drawn.state["last"] ?? "-") else {
            return XCTFail("\(name): span.state has no newest stroke (\(drawn.stateRaw))")
        }
        log("\(name): the newest stroke is in \(last.pageId) \(last.cell), x \(last.minX) … \(last.maxX) of its page")
        XCTAssertTrue([Self.focusWeek, Self.leftWeek].contains(last.pageId), "\(name): one of the two weeks holds the line (\(last.pageId))")
        XCTAssertEqual(last.cell, "grid", "\(name): in the week's grid")
        if last.pageId == Self.leftWeek {
            XCTAssertGreaterThan(last.maxX, Self.weekWidth, "\(name): the left week keeps the points right of its page (\(last.minX) … \(last.maxX))")
        } else {
            XCTAssertLessThan(last.minX, 0, "\(name): the right week keeps the points left of its page (\(last.minX) … \(last.maxX))")
        }
        XCTAssertGreaterThan(last.maxX - last.minX, 250, "\(name): the whole line, not a part of it (\(last.minX) … \(last.maxX))")
    }

    /// 「指でも書く」 off, so one finger moves the paper: from 85 % to 15 % of a page's width across the middle, slowly
    /// and held at the end (no coasting). The paper stops on the next week (`stops` + 1), the title changes once to
    /// 10/12〜10/18, and stays so while the window shifts after the stop (`shifts` + 1; the title read every 0.15 s from
    /// the lift until the window settled and 1 s longer). Without a stop the title would not change; a heading paired
    /// with the wrong window version would jump a page at the shift (risk 4 of the wave plan).
    func testSlideChangesTheTitleOnce() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        let name = "slide"
        let app = launch([], fingerDraws: false, name)
        guard let start = waitForJoined(app, name) else { return }
        XCTAssertEqual(start.state["focus"], Self.focusWeek, "\(name): the focus week")
        let title = titleElement(in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 5), "\(name): the page title")
        let before = title.label
        log("\(name): the title is 「\(before)」")
        XCTAssertTrue(Self.isWeek(of: "10", "5", before), "\(name): the title of 10/5's week (「\(before)」)")

        let frame = start.probe.frame
        let page = Self.weekWidth * start.probe.zoom
        let distance = min(page * 0.7, frame.width * 0.8)
        guard distance > page * 0.55 else {
            return XCTFail("\(name): a page (\(page) pt) is too wide for one drag in the canvas \(frame)")
        }
        let from = CGPoint(x: frame.midX + distance / 2, y: frame.midY)
        let to = CGPoint(x: frame.midX - distance / 2, y: frame.midY)
        waitUntilResponsive(canvasElement(in: app))
        let took = drag(in: app, from: from, to: to, velocity: 400, hold: 0.3)
        log("\(name): moved the paper \(from) → \(to) (\(seconds(took)))")

        var titles = [before]
        var settled: Snapshot?
        var previous: Snapshot?
        var settledAt: Date?
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            let shown = title.exists ? title.label : ""
            if !shown.isEmpty, shown != titles.last { titles.append(shown) }
            if let now = snapshot(app) {
                if now.state["focus"] == Self.nextWeek, now.shifts > start.shifts, let previous, now.isAlike(previous) {
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
        keepScreenshot(app, "\(name) — after")
        log("\(name): the titles \(titles); span.state \(settled?.stateRaw ?? stateLabel(app))")
        guard let settled else {
            return XCTFail("\(name): the paper did not stop on the next week with the window shifted (span.state \(stateLabel(app)); titles \(titles))")
        }
        attach(settled.stateRaw, "\(name) — span.state")
        XCTAssertEqual(titles.count, 2, "\(name): the title changed once (\(titles))")
        XCTAssertTrue(Self.isWeek(of: "10", "12", titles.last ?? ""), "\(name): to 10/12's week (\(titles))")
        XCTAssertEqual(settled.stops, start.stops + 1, "\(name): one stop (\(start.stops) → \(settled.stops))")
        XCTAssertEqual(settled.state["session"], start.state["session"], "\(name): the same window")
    }

    /// ▶ (次の週) at the opening: the window's canvas slides one week (no new window: `session=` stays), the paper stops on
    /// 10/12's week and the window shifts after the stop (`shifts` + 1); the title is 10/12〜10/18.
    func testArrowsSlideOneWeekOnTheSameCanvas() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        let name = "arrow"
        let app = launch([], fingerDraws: true, name)
        guard let start = waitForJoined(app, name) else { return }
        XCTAssertEqual(start.state["focus"], Self.focusWeek, "\(name): the focus week")
        let next = app.buttons["次の週"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "\(name): 「次の週」")
        waitUntilResponsive(next)
        next.tap()
        log("\(name): tapped 「次の週」")
        let after = waitFor(app, timeout: 20, "\(name): the next week with the window shifted") {
            $0.state["focus"] == Self.nextWeek && $0.shifts > start.shifts
        }
        keepScreenshot(app, "\(name) — after")
        guard let after else {
            return XCTFail("\(name): the window did not move to 10/12's week and shift (span.state \(stateLabel(app)))")
        }
        attach(after.stateRaw, "\(name) — span.state")
        let title = titleElement(in: app).label
        log("\(name): the title is 「\(title)」; span.state \(after.stateRaw)")
        XCTAssertEqual(after.state["path"], "span", "\(name): still the joined path")
        XCTAssertEqual(after.state["session"], start.state["session"], "\(name): the same canvas (the session did not change)")
        XCTAssertEqual(after.shifts, start.shifts + 1, "\(name): one shift after the stop")
        XCTAssertTrue(Self.isWeek(of: "10", "12", title), "\(name): the title of 10/12's week (「\(title)」)")
    }

    /// 設定 › ページ › 「前後のページを横につなげる」 off: the week opens on one page (`path=one`, one page, the probe's
    /// `ink=` that page's strokes only: no neighbour, no crossing demo); on again: the joined window again with the same
    /// strokes as at the opening (the neighbours and the crossing demo back). The switch is screenshot mode's memory only.
    func testSettingOffIsOnePageAndOnJoinsAgain() throws {
        try skipUnlessPhone()
        continueAfterFailure = false
        let name = "setting"
        let app = launch([], fingerDraws: true, name)
        guard let joined = waitForJoined(app, name) else { return }
        XCTAssertGreaterThan(joined.pages, 1, "\(name): a window of pages (\(joined.stateRaw))")

        guard switchPageSpan(in: app, to: false, name) else { return }
        guard let one = waitFor(app, timeout: 20, "\(name): one page", until: { $0.state["path"] == "one" }) else {
            return XCTFail("\(name): the setting off did not open one page (span.state \(stateLabel(app)))")
        }
        keepScreenshot(app, "\(name) — off")
        log("\(name): off: span.state \(one.stateRaw); probe \(one.probe.raw)")
        XCTAssertEqual(one.pages, 1, "\(name): one page")
        XCTAssertEqual(one.state["focus"], Self.focusWeek, "\(name): the same week")
        XCTAssertEqual(one.probe.page, Self.focusWeek, "\(name): the canvas holds the real page")
        XCTAssertLessThan(one.probe.ink, joined.probe.ink, "\(name): one page holds fewer strokes than the window (\(one.probe.ink) < \(joined.probe.ink))")

        guard switchPageSpan(in: app, to: true, name) else { return }
        guard let again = waitFor(app, timeout: 20, "\(name): joined again", until: { $0.state["path"] == "span" && $0.state["focus"] == Self.focusWeek }) else {
            return XCTFail("\(name): the setting on did not join the pages again (span.state \(stateLabel(app)))")
        }
        keepScreenshot(app, "\(name) — on again")
        log("\(name): on again: span.state \(again.stateRaw); probe \(again.probe.raw)")
        XCTAssertEqual(again.pages, joined.pages, "\(name): the same window")
        XCTAssertEqual(again.probe.ink, joined.probe.ink, "\(name): the window's strokes as at the opening (\(again.probe.ink) == \(joined.probe.ink))")
        XCTAssertGreaterThan(again.probe.ink, one.probe.ink, "\(name): the neighbours and the crossing demo are back")
    }

    // MARK: - Launching and reading

    private func skipUnlessPhone() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the joined week's UI tests are for an iPhone")
    }

    /// The week page of 2026-10 joined, in Japanese, 「指でも書く」 as asked and already chosen (YearTapUITests).
    private func launch(_ extra: [String], fingerDraws: Bool, _ name: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week",
            "--screenshot-span", "on", "--screenshot-probe",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
            "-allowFingerDrawing", fingerDraws ? "YES" : "NO", "-allowFingerDrawingChosen", "YES",
        ] + extra
        app.launch()
        log("\(name): launched (finger \(fingerDraws ? "draws" : "moves the paper")) \(extra.joined(separator: " "))")
        return app
    }

    private func canvasElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
    }

    private func stateElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "span.state").firstMatch
    }

    private func titleElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "page.title").firstMatch
    }

    private func probe(_ app: XCUIApplication) -> SpanProbe? {
        let canvas = canvasElement(in: app)
        guard canvas.exists, let raw = canvas.value as? String else { return nil }
        return SpanProbe(raw: raw, frame: canvas.frame)
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = stateElement(in: app)
        return state.exists ? state.label : "-"
    }

    /// `span.state` and the probe now; nil while either is missing or the canvas has no zoom yet.
    private func snapshot(_ app: XCUIApplication) -> Snapshot? {
        let label = stateLabel(app)
        guard label != "-", let probe = probe(app), probe.isReady else { return nil }
        return Snapshot(stateRaw: label, probe: probe)
    }

    /// Polls (every 0.3 s, at most `timeout` s) until `until` holds on two reads in a row that agree (`isAlike`: the
    /// window settled, its neighbours read); nil (logged) otherwise.
    private func waitFor(_ app: XCUIApplication, timeout: TimeInterval, _ what: String, until: (Snapshot) -> Bool) -> Snapshot? {
        let deadline = Date().addingTimeInterval(timeout)
        var previous: Snapshot?
        var last: Snapshot?
        repeat {
            if let now = snapshot(app) {
                last = now
                if until(now), let previous, until(previous), now.isAlike(previous) { return now }
                previous = now
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        log("\(what): not within \(seconds(timeout)); span.state \(last?.stateRaw ?? "-"); probe \(last?.probe.raw ?? "-")")
        return nil
    }

    /// The canvas and the joined window, settled (`path=span`, two reads alike), after a simulator that answers
    /// quickly. Fails (with the element tree) and gives nil otherwise.
    private func waitForJoined(_ app: XCUIApplication, _ name: String) -> Snapshot? {
        let canvas = canvasElement(in: app)
        guard canvas.waitForExistence(timeout: 30) else {
            log("\(name): no 「ink-canvas」 element. Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the canvas probe (--screenshot-probe) is missing")
            return nil
        }
        log("\(name): waited \(waitUntilResponsive(canvas)) s for the app to answer quickly")
        guard let start = waitFor(app, timeout: 30, "\(name): the joined window", until: { $0.state["path"] == "span" && $0.pages > 1 }) else {
            log("\(name): Elements:\n\(app.debugDescription)")
            XCTFail("\(name): the screen did not settle on the joined path (span.state \(stateLabel(app)))")
            return nil
        }
        log("\(name): window=\(app.windows.firstMatch.frame) canvas=\(start.probe.frame) span.state \(start.stateRaw); probe \(start.probe.raw)")
        keepScreenshot(app, "\(name) — start")
        return start
    }

    /// 設定 → 「前後のページを横につなげる」 to `on` (the form is moved up until the switch is well inside the window) →
    /// 完了. False (failed) when a step did not happen.
    private func switchPageSpan(in app: XCUIApplication, to on: Bool, _ name: String) -> Bool {
        let settings = app.buttons["設定"]
        guard settings.waitForExistence(timeout: 5) else {
            XCTFail("\(name): the header's 「設定」")
            return false
        }
        waitUntilResponsive(settings)
        settings.tap()
        let done = app.buttons["完了"]
        guard done.waitForExistence(timeout: 10) else {
            XCTFail("\(name): the settings sheet did not open")
            return false
        }
        let toggle = app.descendants(matching: .any).matching(identifier: "settings.pageSpan").firstMatch
        let window = app.windows.firstMatch.frame
        for attempt in 1...10 {
            let above = toggle.exists && toggle.frame.minY <= window.minY + 120
            if toggle.exists, toggle.isHittable, !above, toggle.frame.maxY < window.maxY - 80 { break }
            // Up by 35 % of the window while the switch is below (less than the band it is looked for in, so it is not
            // passed over), down by 20 % when it went under the sheet's bar.
            let (a, b): (CGFloat, CGFloat) = above ? (0.45, 0.65) : (0.75, 0.4)
            drag(in: app, from: CGPoint(x: window.midX, y: window.minY + window.height * a),
                 to: CGPoint(x: window.midX, y: window.minY + window.height * b), velocity: 600, hold: 0.3)
            log("\(name): moved the settings \(above ? "down" : "up") (attempt \(attempt)); the switch \(toggle.exists ? "at \(toggle.frame)" : "not in the tree yet")")
        }
        guard toggle.exists, toggle.isHittable else {
            keepScreenshot(app, "\(name) — no switch")
            XCTFail("\(name): 「前後のページを横につなげる」 is not on the settings sheet")
            return false
        }
        let was = isOn(toggle)
        log("\(name): 「前後のページを横につなげる」 at \(toggle.frame) is \(was.map { $0 ? "on" : "off" } ?? "unread") (\(String(describing: toggle.value)))")
        XCTAssertEqual(was, !on, "\(name): the switch shows the path the screen is on")
        // The switch sits at the row's right end (a tap in the row's middle lands on its title).
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -36, dy: 0)).tap()
        var turned = waitUntil(timeout: 3) { self.isOn(toggle) == on } != nil
        if !turned {
            log("\(name): the tap at the switch's end did not turn it (\(String(describing: toggle.value))); tapping its middle")
            toggle.tap()
            turned = waitUntil(timeout: 3) { self.isOn(toggle) == on } != nil
        }
        keepScreenshot(app, "\(name) — the switch \(on ? "on" : "off")")
        XCTAssertTrue(turned, "\(name): the switch turned \(on ? "on" : "off") (\(String(describing: toggle.value)))")
        done.tap()
        let closed = waitUntil(timeout: 5) { !done.exists } != nil
        log("\(name): switched \(on ? "on" : "off"), the sheet \(closed ? "closed" : "is STILL UP")")
        XCTAssertTrue(closed, "\(name): 完了 closed the settings")
        return turned && closed
    }

    private func isOn(_ toggle: XCUIElement) -> Bool? {
        if let text = toggle.value as? String { return text == "1" ? true : text == "0" ? false : nil }
        if let number = toggle.value as? NSNumber { return number.boolValue }
        return nil
    }

    /// 1.2.3's ja week title, compact (「10/5〜10/11」, an iPhone in portrait) or not (「2026年10月5日〜10月11日」).
    private static func isWeek(of month: String, _ day: String, _ title: String) -> Bool {
        title.hasPrefix("\(month)/\(day)〜") || title.contains("年\(month)月\(day)日〜")
    }

    // MARK: - Gestures, waiting, logs (as EraserAndBelowDayUITests)

    /// One finger: down at `from` (screen points), 0.05 s still, to `to` at `velocity` pt/s, `hold` s still, up.
    /// Returns how long the synthesis took.
    @discardableResult
    private func drag(in app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat, hold: TimeInterval = 0.05) -> TimeInterval {
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

    /// Waits (at most `timeout` seconds) until a query of `element` answers within 1 s (a freshly booted simulator
    /// can be busy for a minute or two). Returns the seconds waited, rounded.
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

    private func attach(_ text: String, _ name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.2f s", value)
    }

    private func log(_ line: String) {
        print("span UI: \(line)")
        NSLog("span UI: %@", line)
    }
}

// MARK: - What the screen reads out

/// `key=value` pairs joined by `;` (the probe and `span.state`); a value may hold `=` and `:` (`last=`).
private func spanFields(_ raw: String) -> [String: String] {
    var values: [String: String] = [:]
    for part in raw.split(separator: ";") {
        guard let equals = part.firstIndex(of: "=") else { continue }
        values[String(part[..<equals])] = String(part[part.index(after: equals)...])
    }
    return values
}

/// The canvas's probe (`InkCanvasView.Coordinator.probeValue()`): on the joined path `page=` is the band's own id,
/// `ox` / `oy` and `pw` / `ph` are the band's, `pk` / `ink` the band's strokes.
private struct SpanProbe {
    let raw: String
    /// The canvas on screen.
    let frame: CGRect
    let values: [String: String]

    init(raw: String, frame: CGRect) {
        self.raw = raw
        self.frame = frame
        values = spanFields(raw)
    }

    private func number(_ key: String) -> CGFloat? {
        values[key].flatMap { Double($0) }.map { CGFloat($0) }
    }

    var page: String { values["page"] ?? "" }
    var zoom: CGFloat { number("zoom") ?? 0 }
    var offset: CGPoint { CGPoint(x: number("ox") ?? 0, y: number("oy") ?? 0) }
    var pk: Int { values["pk"].flatMap { Int($0) } ?? -1 }
    var ink: Int { values["ink"].flatMap { Int($0) } ?? -1 }
    var isReady: Bool { zoom > 0 && frame.width > 0 && frame.height > 0 }

    /// A band point (lu) on screen (pt).
    func screen(_ band: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + band.x * zoom - offset.x, y: frame.minY + band.y * zoom - offset.y)
    }
}

/// One read of `span.state` (`ScreenPaths.stateLabel`) with the probe of the same moment.
private struct Snapshot {
    let stateRaw: String
    let state: [String: String]
    let probe: SpanProbe

    init(stateRaw: String, probe: SpanProbe) {
        self.stateRaw = stateRaw
        state = spanFields(stateRaw)
        self.probe = probe
    }

    private func count(_ key: String) -> Int { state[key].flatMap { Int($0) } ?? -1 }

    /// The focus page's left edge in the band (lu); 0 on one page.
    var origin: CGFloat { state["origin"].flatMap { Double($0) }.map { CGFloat($0) } ?? 0 }
    var pages: Int { count("pages") }
    var shifts: Int { count("shifts") }
    var stops: Int { count("stops") }

    /// The same window and the same paper: `span.state` as a whole (its version moves with each page read), the
    /// probe's zoom, offset, frame and strokes.
    func isAlike(_ other: Snapshot) -> Bool {
        stateRaw == other.stateRaw && probe.zoom == other.probe.zoom && probe.offset == other.probe.offset
            && probe.frame == other.probe.frame && probe.pk == other.probe.pk && probe.ink == other.probe.ink
    }
}

/// `last=<page>:<cell>:minx=<lu>:maxx=<lu>`: the window's newest stroke, its x range in its own cell.
private struct Newest {
    let pageId: String
    let cell: String
    let minX: CGFloat
    let maxX: CGFloat

    init?(_ raw: String) {
        let parts = raw.split(separator: ":").map(String.init)
        guard parts.count >= 4, let minPart = parts.first(where: { $0.hasPrefix("minx=") }),
              let maxPart = parts.first(where: { $0.hasPrefix("maxx=") }),
              let minX = Double(minPart.dropFirst(5)), let maxX = Double(maxPart.dropFirst(5)) else { return nil }
        pageId = parts[0]
        cell = parts[1]
        self.minX = CGFloat(minX)
        self.maxX = CGFloat(maxX)
    }
}
