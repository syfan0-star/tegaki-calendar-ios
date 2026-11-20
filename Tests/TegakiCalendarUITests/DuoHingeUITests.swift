// 1.4 (docs/M7D_CONTRACT.md §4.9, §6's row U, §3.10 duo-hinge): the whole file is built only with the compilation condition
// DUO_HINGE, which duo.yml's duo-hinge job alone passes (`SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DUO_HINGE`;
// build-and-test checks that project.yml never has it). Without it this file is empty, in every other job and build.
#if DUO_HINGE
import ObjectiveC
import UIKit
import XCTest

/// 1.4 (§4.9's three checks): folding and unfolding the iPhone Duo with ink on the joined week loses no line.
/// - `testOpenWriteCloseOpenKeepsTheLine`: open → write on the week → close → open: the window's newest stroke is the same
///   line, and with the window of the same size the same strokes.
/// - `testWriteClosedThenOpenKeepsTheLine`: closed → write → open: the same.
/// - `testCloseWhileWritingKeepsTheLinesBefore`: open → write → close while a second line is being written → open: the
///   lines before are all there (the line under the finger may be dropped by the system's cancel, §4.9 3: Apple's).
///
/// The app runs in its screenshot mode (nothing saved) on the joined week (`--screenshot-span on`, `--screenshot-probe`) with
/// 「指でも書く」 pinned on (value and mark "person" in UserDefaults' argument domain), so a finger writes as the Pencil would.
/// `span.state`'s `last=` (the window's newest stroke: page, cell and x range in its page) names a line across the fold; the
/// probe's `ink` (the band's strokes) is compared only between windows of the same size (`pages`), since a fold decides the
/// window anew and the demo's neighbours come and go with it. With `--screenshot-measure` (1.4 D1b; nothing on the screen
/// changes) the app also writes its `duo measure:` lines, so duo-hinge records the inner screen's measurement that §4.2's
/// path 2 asks of it (`hinge=`, `wide=`, the window, after each fold): duo.yml reads them from the app's
/// Library/Caches/duo-measure.txt.
///
/// The hinge is driven by Xcode 27.3's `XCUIHinge` (XCUIAutomation, 187479559, [S6]), whose names this repository has not
/// read (27.3 is a beta on 11/20, and no SDK of it is on the Mac this was written on). So `HingeDriver` reaches it through the
/// Objective-C runtime: a property `hinge` (or `hingeAngle`) on `XCUIDevice.shared` or on the app, set by key-value coding
/// with the angle in radians (as `UIHinge.angle`: 0 closed, π open). Nothing here needs those symbols to build. Where no
/// such property answers, or the window does not cross 600 pt (`WindowClass.wideShortSide`) after the angle is set, the
/// tests skip and log the hinge selectors they found, so the duo-hinge run says what to write instead. The job counts a
/// result only with the 27.3 release (§3.10, §4.2 road 2); a beta's run is a record.
@MainActor
final class DuoHingeUITests: XCTestCase {
    private static let wideShortSide: CGFloat = 600

    // MARK: - Tests

    func testOpenWriteCloseOpenKeepsTheLine() throws {
        continueAfterFailure = false
        let name = "open write close open"
        let hinge = try driver(name)
        let app = launch(name)
        defer { app.terminate() }
        try fold(hinge, app, open: true, name)
        guard let start = waitForJoined(app, name), let written = writeLine(app, from: start, name) else { return }
        try fold(hinge, app, open: false, name)
        guard waitForJoined(app, "\(name) (closed)") != nil else { return }
        try fold(hinge, app, open: true, name)
        guard let after = waitForJoined(app, "\(name) (open again)") else { return }
        keepScreenshot(app, "\(name) — after")
        compare(written, after, name)
    }

    func testWriteClosedThenOpenKeepsTheLine() throws {
        continueAfterFailure = false
        let name = "write closed then open"
        let hinge = try driver(name)
        let app = launch(name)
        defer { app.terminate() }
        try fold(hinge, app, open: false, name)
        guard let start = waitForJoined(app, name), let written = writeLine(app, from: start, name) else { return }
        try fold(hinge, app, open: true, name)
        guard waitForJoined(app, "\(name) (open)") != nil else { return }
        try fold(hinge, app, open: false, name)
        guard let after = waitForJoined(app, "\(name) (closed again)") else { return }
        keepScreenshot(app, "\(name) — after")
        compare(written, after, name)
    }

    func testCloseWhileWritingKeepsTheLinesBefore() throws {
        continueAfterFailure = false
        let name = "close while writing"
        let hinge = try driver(name)
        let app = launch(name)
        defer { app.terminate() }
        try fold(hinge, app, open: true, name)
        guard let start = waitForJoined(app, name), let written = writeLine(app, from: start, name) else { return }
        // The second line, slow enough to be under the finger when the hinge closes (from the runtime's queue: the drag
        // holds the test's thread).
        let frame = written.frame
        let from = CGPoint(x: frame.midX - frame.width * 0.3, y: frame.midY + frame.height * 0.15)
        let to = CGPoint(x: frame.midX + frame.width * 0.3, y: frame.midY + frame.height * 0.15)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) { hinge.set(open: false) }
        drag(app, from: from, to: to, velocity: 120, hold: 0.5)
        log("\(name): the second line \(from) → \(to), the hinge closing during it")
        guard waitForWindow(app, wide: false, timeout: 15) else {
            throw XCTSkip("\(name): the window did not become narrow after the hinge was closed (\(hinge.summary))")
        }
        guard waitForJoined(app, "\(name) (closed)") != nil else { return }
        try fold(hinge, app, open: true, name)
        guard let after = waitForJoined(app, "\(name) (open again)") else { return }
        keepScreenshot(app, "\(name) — after")
        log("\(name): before \(written.raw) / \(written.probeRaw); after \(after.raw) / \(after.probeRaw)")
        if after.count("pages") == written.count("pages") {
            XCTAssertGreaterThanOrEqual(after.ink, written.ink, "\(name): every line written before the fold is in the window")
        } else {
            log("\(name): the window has \(after.count("pages")) pages, not \(written.count("pages")): the strokes are not compared")
        }
        XCTAssertEqual(after.state["focus"], written.state["focus"], "\(name): the same focus page")
    }

    // MARK: - The hinge

    /// The hinge driver, or a skip with what the runtime offers.
    private func driver(_ name: String) throws -> HingeDriver {
        let app = XCUIApplication()
        guard let driver = HingeDriver.find(in: [XCUIDevice.shared, app]) else {
            let found = HingeDriver.hingeSelectors(in: [XCUIDevice.shared, app])
            log("\(name): no hinge property; selectors with \"hinge\": \(found)")
            throw XCTSkip("no XCUIHinge property on XCUIDevice or XCUIApplication (\(found.count) selectors with \"hinge\", logged)")
        }
        log("\(name): the hinge through \(driver.summary)")
        return driver
    }

    /// Sets the hinge and waits until the window is on the side of 600 pt the screen should be; skips when it is not.
    private func fold(_ hinge: HingeDriver, _ app: XCUIApplication, open: Bool, _ name: String) throws {
        hinge.set(open: open)
        log("\(name): the hinge \(open ? "opened" : "closed")")
        guard waitForWindow(app, wide: open, timeout: 15) else {
            throw XCTSkip("\(name): the window \(app.windows.firstMatch.frame) did not become \(open ? "wide" : "narrow") (\(hinge.summary))")
        }
    }

    /// The window's short side on `wide`'s side of 600 pt within `timeout`.
    private func waitForWindow(_ app: XCUIApplication, wide: Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let frame = app.windows.firstMatch.frame
            let short = min(frame.width, frame.height)
            if short > 0, (short >= Self.wideShortSide) == wide { return true }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return false
    }

    // MARK: - Ink

    /// A finger line across 40 % of the canvas a little above its middle; the state once the window has one stroke more.
    private func writeLine(_ app: XCUIApplication, from start: Joined, _ name: String) -> Joined? {
        let frame = start.frame
        let from = CGPoint(x: frame.midX - frame.width * 0.2, y: frame.midY - frame.height * 0.1)
        let to = CGPoint(x: frame.midX + frame.width * 0.2, y: frame.midY - frame.height * 0.1)
        drag(app, from: from, to: to, velocity: 250, hold: 0.05)
        let deadline = Date().addingTimeInterval(8)
        var previous: Joined?
        repeat {
            if let now = joinedState(app), now.pk == start.pk + 1, now.state["last"] != start.state["last"],
               let previous, previous.isAlike(now) {
                log("\(name): wrote \(now.state["last"] ?? "-")")
                return now
            }
            previous = joinedState(app)
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        XCTFail("\(name): the finger line was not written (span.state \(stateLabel(app)))")
        return nil
    }

    /// The line written is the window's newest after the fold, on the same focus; with a window of the same size the same strokes.
    private func compare(_ written: Joined, _ after: Joined, _ name: String) {
        log("\(name): before \(written.raw) / \(written.probeRaw); after \(after.raw) / \(after.probeRaw)")
        XCTAssertEqual(after.state["last"], written.state["last"], "\(name): the line written is still the window's newest")
        XCTAssertEqual(after.state["focus"], written.state["focus"], "\(name): the same focus page")
        if after.count("pages") == written.count("pages") {
            XCTAssertEqual(after.ink, written.ink, "\(name): the same strokes in a window of the same size")
        } else {
            log("\(name): the window has \(after.count("pages")) pages, not \(written.count("pages")): the strokes are not compared")
        }
    }

    // MARK: - The screen (as DuoLayoutUITests)

    private func launch(_ name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-span", "on",
            "--screenshot-probe", "--screenshot-measure",
            "-allowFingerDrawing", "YES", "-allowFingerDrawingChosen", "YES", "-allowFingerDrawingAuto", "person",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ]
        app.launch()
        log("\(name): launched")
        return app
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = app.descendants(matching: .any).matching(identifier: "span.state").firstMatch
        return state.exists ? state.label : "-"
    }

    private func joinedState(_ app: XCUIApplication) -> Joined? {
        let label = stateLabel(app)
        let canvas = app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
        guard label != "-", canvas.exists, let probe = canvas.value as? String else { return nil }
        let joined = Joined(raw: label, probeRaw: probe, frame: canvas.frame)
        return joined.zoom > 0 && joined.frame.width > 0 ? joined : nil
    }

    /// The joined window settled (`path=span`, two reads alike), at most 30 s; nil (failed) otherwise.
    private func waitForJoined(_ app: XCUIApplication, _ name: String) -> Joined? {
        let deadline = Date().addingTimeInterval(30)
        var previous: Joined?
        repeat {
            if let now = joinedState(app) {
                if now.state["path"] == "span", let previous, previous.isAlike(now) {
                    log("\(name): window \(app.windows.firstMatch.frame) span.state \(now.raw)")
                    return now
                }
                previous = now
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        XCTFail("\(name): the joined window did not settle (span.state \(stateLabel(app)))")
        return nil
    }

    @discardableResult
    private func drag(_ app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat, hold: TimeInterval) -> TimeInterval {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let started = Date()
        origin.withOffset(CGVector(dx: from.x, dy: from.y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: to.x, dy: to.y)),
                   withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: hold)
        return Date().timeIntervalSince(started)
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func log(_ line: String) {
        print("duo hinge UI: \(line)")
        NSLog("duo hinge UI: %@", line)
    }
}

/// Xcode 27.3's hinge, found at run time (see `DuoHingeUITests`): the object with a key-value coded angle, and the key.
private final class HingeDriver: @unchecked Sendable {
    private let target: NSObject
    private let key: String
    let summary: String

    private init(target: NSObject, key: String, summary: String) {
        self.target = target
        self.key = key
        self.summary = summary
    }

    /// 0 closed, π open (radians, as `UIHinge.angle`).
    func set(open: Bool) {
        target.setValue(NSNumber(value: open ? Double.pi : 0), forKey: key)
    }

    /// The first of: an object's `hinge` whose class has `setAngle:`, or the object's own `setHingeAngle:`.
    static func find(in owners: [NSObject]) -> HingeDriver? {
        for owner in owners {
            if owner.responds(to: NSSelectorFromString("hinge")), let hinge = owner.value(forKey: "hinge") as? NSObject,
               hinge.responds(to: NSSelectorFromString("setAngle:")) {
                return HingeDriver(target: hinge, key: "angle", summary: "\(type(of: owner)).hinge (\(type(of: hinge))).angle")
            }
            if owner.responds(to: NSSelectorFromString("setHingeAngle:")) {
                return HingeDriver(target: owner, key: "hingeAngle", summary: "\(type(of: owner)).hingeAngle")
            }
        }
        return nil
    }

    /// Every selector with "hinge" in its name on the owners' classes and their superclasses, and on a class named
    /// XCUIHinge, for the log.
    static func hingeSelectors(in owners: [NSObject]) -> [String] {
        var classes: [AnyClass] = owners.compactMap { object_getClass($0) }
        if let named = NSClassFromString("XCUIHinge") { classes.append(named) }
        var found: [String] = []
        for start in classes {
            var current: AnyClass? = start
            while let cls = current {
                var count: UInt32 = 0
                if let methods = class_copyMethodList(cls, &count) {
                    for i in 0..<Int(count) {
                        let selector = NSStringFromSelector(method_getName(methods[i]))
                        if selector.lowercased().contains("hinge") || NSStringFromClass(cls).contains("Hinge") {
                            found.append("\(NSStringFromClass(cls)).\(selector)")
                        }
                    }
                    free(methods)
                }
                current = class_getSuperclass(cls)
                if current == NSObject.self { break }
            }
        }
        return found
    }
}

/// One read of `span.state` with the canvas's probe (as DuoLayoutUITests' `Joined`).
private struct Joined {
    let raw: String
    let probeRaw: String
    let state: [String: String]
    let probe: [String: String]
    let frame: CGRect

    init(raw: String, probeRaw: String, frame: CGRect) {
        self.raw = raw
        self.probeRaw = probeRaw
        state = Joined.fields(raw)
        probe = Joined.fields(probeRaw)
        self.frame = frame
    }

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
    var ink: Int { probe["ink"].flatMap { Int($0) } ?? -1 }

    func isAlike(_ other: Joined) -> Bool {
        raw == other.raw && frame == other.frame && ["zoom", "ox", "oy", "pk", "ink"].allSatisfy { probe[$0] == other.probe[$0] }
    }
}
#endif
