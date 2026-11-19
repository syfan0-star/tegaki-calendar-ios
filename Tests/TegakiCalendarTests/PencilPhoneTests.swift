import Layout
import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import TegakiCalendar

// 1.4 (docs/M7D_CONTRACT.md §2.1, §4.8, §6; the owner's decision of 11/20): the app's glue of `FingerDefault` —
// `PencilPhone`. The decision's table itself is KitChecks' section "window & finger (1.4)"; here: the mark
// `allowFingerDrawingAuto` read and written in a scratch suite (who wrote today's 「指でも書く」), the first launch's default
// (1.3's lines with the mark; an update from 1.3 writes no mark), the window's watcher (a new instance of the frozen
// `InkTouchObserver` on a UIWindow) fed with stand-in touches of the Pencil, a finger and a pointer, the Pencil's lift
// turning 「指でも書く」 off end to end (the value, the mark, the guide records of the app's own value only), the hinge's
// answer and its 2-second fallback on a `TestSleeper`, the hinge being nil off the Duo (iOS 27.1 and later, not on Mac
// Catalyst), and no model name or kind of device read by the new files. Mutations (§6, `r14-q-m1`): the glue counting a
// finger as a Pencil fails `testWatcherCountsEveryTouch` and `testPencilLiftTurnsFingerOffEndToEnd`; the guide records
// always forgotten fails the latter's carried row; `personSet` not writing "person" fails `testPersonSetMarksThePerson`.

@MainActor
final class PencilPhoneTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!
    private var savedDefaults: UserDefaults!

    private let thisDevice = "11111111-2222-3333-4444-555555555555"
    private let otherDevice = "99999999-8888-7777-6666-555555555555"

    override func setUp() async throws {
        suiteName = "PencilPhoneTests-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = suite
    }

    override func tearDown() async throws {
        AppSettings.defaults = savedDefaults
        suite?.removePersistentDomain(forName: suiteName)
        suite = nil
    }

    // MARK: Stand-ins

    /// A touch that only has a type, for the tests' calls of a recogniser's `touches…` methods (the shape of
    /// InkCanvasViewTests' `StandInTouch`, copied here: that file is in TESTS_1_2_3 and stays as it is).
    private final class StandInTouch: UITouch {
        let kind: UITouch.TouchType
        var point: CGPoint
        weak var space: UIView?

        init(_ kind: UITouch.TouchType, at point: CGPoint = .zero, in space: UIView? = nil) {
            self.kind = kind
            self.point = point
            self.space = space
            super.init()
        }

        override var type: UITouch.TouchType { kind }

        override func location(in view: UIView?) -> CGPoint {
            guard let space else { return point }
            return space.convert(point, to: view)
        }

        override func preciseLocation(in view: UIView?) -> CGPoint {
            location(in: view)
        }
    }

    /// An event without coalesced touches.
    private final class StandInEvent: UIEvent {
        override func coalescedTouches(for touch: UITouch) -> [UITouch]? { nil }
    }

    /// What a `PencilPhone` was fed and what it wrote.
    private final class Log {
        var inputs: [PencilPhone.Input] = []
        var actions: [FingerDefault.Action] = []
    }

    /// A phone's (or an iPad's) glue over the scratch suite, this device's mark `thisDevice`, the hinge as asked.
    private func makePhone(isPad: Bool = false, device: String? = nil, usesHinge: Bool = false,
                           sleeper: TestSleeper? = nil) -> (PencilPhone, Log) {
        let log = Log()
        let mark = device ?? thisDevice
        let phone = PencilPhone(isPad: isPad, defaults: suite, deviceMark: { mark }, usesHinge: usesHinge,
                                sleep: { duration in await sleeper?.sleep(duration) })
        phone.onInput = { log.inputs.append($0) }
        phone.onApply = { log.actions.append($0) }
        return (phone, log)
    }

    /// The window's watcher `attach` put on `window` (the one `InkTouchObserver` among its recognisers).
    private func watcher(of window: UIWindow, file: StaticString = #filePath, line: UInt = #line) throws -> InkTouchObserver {
        let observers = (window.gestureRecognizers ?? []).compactMap { $0 as? InkTouchObserver }
        XCTAssertEqual(observers.count, 1, "one watcher on the window", file: file, line: line)
        return try XCTUnwrap(observers.first, file: file, line: line)
    }

    private var allowFinger: Bool { suite.bool(forKey: AppSettings.allowFingerKey) }
    private var mark: String? { suite.string(forKey: PencilPhone.markKey) }

    // MARK: The mark

    /// §4.8: the mark's four readings in a scratch suite — "person" (the person's switch), this device's mark (the app on this
    /// device), none (carried over from 1.3 or earlier, or empty), another device's (moved here by a backup or a new iPhone);
    /// this device's mark not readable yet (nil) reads everything but "person" as carried.
    func testOriginReadsTheMark() {
        XCTAssertEqual(PencilPhone.markKey, "allowFingerDrawingAuto")
        XCTAssertEqual(AppSettings.allowFingerAutoKey, PencilPhone.markKey)
        XCTAssertEqual(PencilPhone.personMark, "person")
        XCTAssertEqual(PencilPhone.origin(suite, device: thisDevice), .carried, "no mark: carried over")
        suite.set("", forKey: PencilPhone.markKey)
        XCTAssertEqual(PencilPhone.origin(suite, device: thisDevice), .carried, "an empty mark: carried over")
        suite.set(thisDevice, forKey: PencilPhone.markKey)
        XCTAssertEqual(PencilPhone.origin(suite, device: thisDevice), .app, "this device's mark: the app")
        suite.set(otherDevice, forKey: PencilPhone.markKey)
        XCTAssertEqual(PencilPhone.origin(suite, device: thisDevice), .moved, "another device's mark: moved here")
        XCTAssertEqual(PencilPhone.origin(suite, device: nil), .carried, "this device's mark not readable: carried")
        suite.set("person", forKey: PencilPhone.markKey)
        XCTAssertEqual(PencilPhone.origin(suite, device: thisDevice), .person, "the person")
        XCTAssertEqual(PencilPhone.origin(suite, device: nil), .person, "the person, whatever the device")
    }

    /// §2.1, §4.8: the person's switch (the toolbar's and the settings' Binding) writes the value and the mark "person";
    /// after it the app changes nothing, not even on a Pencil's lift. Fails with `personSet` not writing "person".
    func testPersonSetMarksThePerson() throws {
        PencilPhone.personSet(false, defaults: suite)
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, "person")
        PencilPhone.personSet(true, defaults: suite)
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, "person")
        XCTAssertEqual(PencilPhone.origin(suite, device: thisDevice), .person)

        let (phone, log) = makePhone()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        phone.attach(to: window, isPad: false)
        phone.appeared(allowFinger: true, origin: PencilPhone.origin(suite, device: thisDevice))
        phone.personSwitched()
        XCTAssertEqual(phone.origin, .person)
        let observer = try watcher(of: window)
        let pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertEqual(log.actions, [], "the person's choice stays")
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, "person")
    }

    /// §2.1, §4.8 (C2, 0d-37): the first launch's default — 1.3's (「指でも書く」 on a phone, off on an iPad,
    /// `allowFingerDrawingChosen` true) with this device's mark beside it, so the app's own value reads `.app`; a launch with
    /// `allowFingerDrawingChosen` on record (an update from 1.3, or any later launch) writes nothing, so 1.3's value without a
    /// mark stays carried over; this device's mark not readable at the first launch writes no mark (carried, P only).
    func testFirstLaunchWritesTheMarkOnly() {
        var launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        XCTAssertTrue(launch.allowFinger)
        XCTAssertEqual(launch.origin, .app)
        XCTAssertTrue(suite.bool(forKey: AppSettings.allowFingerChosenKey))
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, thisDevice)
        // The next launch reads what is there.
        suite.set(false, forKey: AppSettings.allowFingerKey)
        launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        XCTAssertFalse(launch.allowFinger)
        XCTAssertEqual(launch.origin, .app)
        XCTAssertEqual(mark, thisDevice)

        // An update from 1.3: chosen and the value on record, no mark — nothing written, carried over.
        suite.removePersistentDomain(forName: suiteName)
        suite.set(true, forKey: AppSettings.allowFingerChosenKey)
        suite.set(true, forKey: AppSettings.allowFingerKey)
        launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        XCTAssertTrue(launch.allowFinger)
        XCTAssertEqual(launch.origin, .carried)
        XCTAssertNil(mark, "no mark for 1.3's value")

        // An iPad's first launch: 1.3's off, the mark as well (its FingerDefault answers nothing).
        suite.removePersistentDomain(forName: suiteName)
        launch = PencilPhone.launchDefault(suite, isPad: true, device: thisDevice)
        XCTAssertFalse(launch.allowFinger)
        XCTAssertFalse(allowFinger)
        XCTAssertTrue(suite.bool(forKey: AppSettings.allowFingerChosenKey))
        XCTAssertEqual(launch.origin, .app)

        // This device's mark not readable (before the first unlock): 1.3's default, no mark, carried.
        suite.removePersistentDomain(forName: suiteName)
        launch = PencilPhone.launchDefault(suite, isPad: false, device: nil)
        XCTAssertTrue(launch.allowFinger)
        XCTAssertEqual(launch.origin, .carried)
        XCTAssertNil(mark)
        XCTAssertTrue(suite.bool(forKey: AppSettings.allowFingerChosenKey))
    }

    /// §2.1's last line: the photos' and the UI tests' launch arguments `-allowFingerDrawingChosen NO -allowFingerDrawingAuto ""`
    /// make a first launch, though the argument domain keeps shadowing the two keys after they were written (a store that
    /// reads them so stands in for it here): 1.3's default is written and the origin is the app's (this device's mark).
    func testLaunchArgumentsBehaveAsAFirstLaunch() throws {
        let name = "PencilPhoneTests-shadowed-\(UUID().uuidString)"
        let shadowed = try XCTUnwrap(ShadowedDefaults(suiteName: name))
        defer { shadowed.removePersistentDomain(forName: name) }
        // An earlier run left the person's choice and a chosen record behind.
        shadowed.set(true, forKey: AppSettings.allowFingerChosenKey)
        shadowed.set("person", forKey: PencilPhone.markKey)
        let launch = PencilPhone.launchDefault(shadowed, isPad: false, device: thisDevice)
        XCTAssertTrue(launch.allowFinger, "1.3's default of a phone")
        XCTAssertEqual(launch.origin, .app, "the app's own value, not read back through the shadow")
        XCTAssertTrue(shadowed.bool(forKey: AppSettings.allowFingerKey))
    }

    /// The argument domain of `-allowFingerDrawingChosen NO -allowFingerDrawingAuto ""`: reads of the two keys keep giving the
    /// arguments' values whatever is written.
    private final class ShadowedDefaults: UserDefaults {
        override func object(forKey defaultName: String) -> Any? {
            switch defaultName {
            case AppSettings.allowFingerChosenKey: return false
            case PencilPhone.markKey: return ""
            default: return super.object(forKey: defaultName)
            }
        }

        override func bool(forKey defaultName: String) -> Bool {
            defaultName == AppSettings.allowFingerChosenKey ? false : super.bool(forKey: defaultName)
        }

        override func string(forKey defaultName: String) -> String? {
            defaultName == PencilPhone.markKey ? "" : super.string(forKey: defaultName)
        }
    }

    // MARK: The window's watcher (P)

    /// §4.8 (C6, C7, 0d-39): a new instance of the frozen `InkTouchObserver` on the UIWindow counts every touch of the window —
    /// the Pencil as P (`touchDown(pencil: true)` once per touch), a finger and a pointer counted but never a Pencil — and
    /// every lift, `touchesCancelled` included; `reset()` reports what is still down as lifted; it never recognises (only
    /// `.possible` or `.failed`). On an iPad nothing is attached. Fails with the glue counting a finger as a Pencil.
    func testWatcherCountsEveryTouch() throws {
        let (pad, padLog) = makePhone(isPad: true)
        let padWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
        pad.attach(to: padWindow, isPad: true)
        XCTAssertTrue((padWindow.gestureRecognizers ?? []).compactMap { $0 as? InkTouchObserver }.isEmpty, "an iPad: nothing attached")
        XCTAssertEqual(padLog.inputs, [])

        let (phone, log) = makePhone()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        phone.attach(to: window, isPad: false)
        let observer = try watcher(of: window)
        XCTAssertFalse(observer.cancelsTouchesInView)
        XCTAssertFalse(observer.delaysTouchesBegan)
        XCTAssertFalse(observer.delaysTouchesEnded)
        XCTAssertTrue(observer.delegate?.gestureRecognizer?(observer, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()) ?? false,
                      "it recognises alongside every recogniser")
        XCTAssertEqual(log.inputs, [.hinge(false)], "no hinge watched: the answer at once")
        log.inputs = []
        phone.attach(to: window, isPad: false)
        XCTAssertEqual((window.gestureRecognizers ?? []).compactMap { $0 as? InkTouchObserver }.count, 1, "the same window: once")
        XCTAssertEqual(log.inputs, [])

        let pencil = StandInTouch(.pencil)
        let finger = StandInTouch(.direct)
        let pointer = StandInTouch(.indirectPointer)
        observer.touchesBegan([pencil], with: StandInEvent())
        observer.touchesBegan([finger], with: StandInEvent())
        observer.touchesBegan([pointer], with: StandInEvent())
        XCTAssertEqual(log.inputs, [.touchDown(pencil: true), .touchDown(pencil: false), .touchDown(pencil: false)])
        observer.touchesEnded([finger], with: StandInEvent())
        observer.touchesCancelled([pointer], with: StandInEvent())
        XCTAssertTrue([UIGestureRecognizer.State.possible, .failed].contains(observer.state), "never recognised")
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertEqual(log.inputs.filter { $0 == .touchUp }.count, 3, "every lift counted: none left down")
        XCTAssertEqual(log.inputs.filter { $0 == .touchDown(pencil: true) }.count, 1, "one Pencil touch")
        XCTAssertTrue([UIGestureRecognizer.State.possible, .failed].contains(observer.state), "never recognised")

        // `reset()`: what is still down counts as lifted.
        log.inputs = []
        observer.touchesBegan([StandInTouch(.direct), StandInTouch(.pencil)], with: StandInEvent())
        observer.reset()
        XCTAssertEqual(log.inputs.filter { $0 == .touchUp }.count, 2)
        XCTAssertEqual(log.inputs.filter { if case .touchDown = $0 { return true } else { return false } }.count, 2)

        // Another window: the watcher moves, what was down counts as lifted.
        log.inputs = []
        let other = UIWindow(frame: CGRect(x: 0, y: 0, width: 669, height: 951))
        phone.attach(to: other, isPad: false)
        XCTAssertTrue((window.gestureRecognizers ?? []).compactMap { $0 as? InkTouchObserver }.isEmpty, "off the old window")
        _ = try watcher(of: other)
        XCTAssertEqual(log.inputs, [.touchesReset, .hinge(false)])
    }

    /// §4.8 (C6, F10): a Pencil touches the window and lifts — 「指でも書く」 off, the mark this device's; for the app's own
    /// value (the first launch's default) the week's and the day's guide records are forgotten (the guide shows once more), for
    /// a value carried over from 1.3 they stay. A finger still down holds it until it lifts, then it changes once. Fails with
    /// the glue counting a finger as a Pencil (the finger rows), or with the guide records always forgotten (the carried row).
    func testPencilLiftTurnsFingerOffEndToEnd() throws {
        // The app's own value: 1.4's first launch.
        AppSettings.markSpanGuideShown(.week)
        AppSettings.markSpanGuideShown(.day)
        var launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        XCTAssertEqual(launch.origin, .app)
        var (phone, log) = makePhone()
        var window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        phone.attach(to: window, isPad: false)
        phone.appeared(allowFinger: launch.allowFinger, origin: launch.origin)
        var observer = try watcher(of: window)
        let finger = StandInTouch(.direct)
        observer.touchesBegan([finger], with: StandInEvent())
        observer.touchesEnded([finger], with: StandInEvent())
        XCTAssertEqual(log.actions, [], "a finger alone is not P")
        XCTAssertTrue(allowFinger)
        var pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        XCTAssertEqual(log.actions, [], "not while the Pencil is down")
        XCTAssertTrue(allowFinger)
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertEqual(log.actions, [.turnOff(rearmGuide: true)])
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, thisDevice)
        XCTAssertEqual(phone.origin, .app)
        XCTAssertFalse(AppSettings.spanGuideShown(.week), "the guide shows once more")
        XCTAssertFalse(AppSettings.spanGuideShown(.day))
        pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertEqual(log.actions.count, 1, "once")

        // A value carried over from 1.3 (on, no mark): off at the lift, the guide records stay.
        suite.removePersistentDomain(forName: suiteName)
        suite.set(true, forKey: AppSettings.allowFingerChosenKey)
        suite.set(true, forKey: AppSettings.allowFingerKey)
        AppSettings.markSpanGuideShown(.week)
        AppSettings.markSpanGuideShown(.day)
        launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        XCTAssertEqual(launch.origin, .carried)
        (phone, log) = makePhone()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        phone.attach(to: window, isPad: false)
        phone.appeared(allowFinger: launch.allowFinger, origin: launch.origin)
        XCTAssertEqual(phone.origin, .carried, "the launch's origin")
        observer = try watcher(of: window)
        // A finger down first, the Pencil touches and lifts: nothing until the finger lifts, then once.
        let holding = StandInTouch(.direct)
        observer.touchesBegan([holding], with: StandInEvent())
        pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertEqual(log.actions, [], "a finger still down: not yet")
        XCTAssertTrue(allowFinger)
        observer.touchesEnded([holding], with: StandInEvent())
        XCTAssertEqual(log.actions, [.turnOff(rearmGuide: false)])
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, thisDevice, "the app's value on this device now")
        XCTAssertEqual(phone.origin, .app, "the app's value on this device now")
        XCTAssertTrue(AppSettings.spanGuideShown(.week), "carried over: no guide again")
        XCTAssertTrue(AppSettings.spanGuideShown(.day))
    }

    // MARK: The hinge (H)

    /// §4.8: the hinge's answer and its fallback. With no hinge watched (`usesHinge` false, the app's until §4.2 decides it) the
    /// answer is "no hinge" at once, so a Duo's off moved to a phone without a hinge is turned on again once. Watched, the
    /// first update has `hingeWait` (2 s, on the injected sleep): none in time is "no hinge"; an answer in time is the answer,
    /// and the wait then adds nothing.
    func testHingeAnswerAndItsFallback() async {
        XCTAssertFalse(PencilPhone.usesHinge, "decided by duo-shots (§4.2); until then P alone")
        XCTAssertEqual(PencilPhone.hingeWait, 2)

        // Moved here, off (a Duo's): no hinge watched → on again, the mark this device's.
        suite.set(false, forKey: AppSettings.allowFingerKey)
        suite.set(otherDevice, forKey: PencilPhone.markKey)
        var (phone, log) = makePhone()
        phone.appeared(allowFinger: false, origin: PencilPhone.origin(suite, device: thisDevice))
        XCTAssertEqual(log.actions, [], "it waits for the hinge's answer")
        phone.attach(to: UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874)), isPad: false)
        XCTAssertEqual(log.actions, [.turnOnAgain])
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, thisDevice)

        // Watched, no update in 2 s: "no hinge".
        let sleeper = TestSleeper()
        suite.set(false, forKey: AppSettings.allowFingerKey)
        suite.set(otherDevice, forKey: PencilPhone.markKey)
        (phone, log) = makePhone(sleeper: sleeper)
        phone.appeared(allowFinger: false, origin: .moved)
        phone.waitForFirstHingeUpdate()
        await settle()
        XCTAssertEqual(sleeper.recorded, [2])
        XCTAssertEqual(log.actions, [])
        await sleeper.advance()
        await settle()
        XCTAssertEqual(log.inputs.last, .hinge(false))
        XCTAssertEqual(log.actions, [.turnOnAgain])

        // Watched, an update with a hinge in time: kept off and taken over (rebind); the wait's end adds nothing.
        let second = TestSleeper()
        suite.set(false, forKey: AppSettings.allowFingerKey)
        suite.set(otherDevice, forKey: PencilPhone.markKey)
        (phone, log) = makePhone(sleeper: second)
        phone.appeared(allowFinger: false, origin: .moved)
        phone.waitForFirstHingeUpdate()
        await settle()
        phone.hingeAnswered(true)
        XCTAssertEqual(log.actions, [.rebind])
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, thisDevice)
        await second.advance()
        await settle()
        XCTAssertEqual(log.inputs.filter { if case .hinge = $0 { return true } else { return false } }, [.hinge(true)], "no fallback after an answer")
        XCTAssertEqual(log.actions, [.rebind])

        // The app's own value on a device with a hinge: off at the hinge (iPad-like from the start), the guide shows again.
        suite.removePersistentDomain(forName: suiteName)
        AppSettings.markSpanGuideShown(.week)
        let launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        (phone, log) = makePhone()
        phone.hingeAnswered(true)
        XCTAssertEqual(log.actions, [], "before appear: remembered (C2)")
        phone.appeared(allowFinger: launch.allowFinger, origin: launch.origin)
        XCTAssertEqual(log.actions, [.turnOff(rearmGuide: true)])
        XCTAssertFalse(allowFinger)
        XCTAssertFalse(AppSettings.spanGuideShown(.week))
    }

    /// §4.8, F2: off the Duo the hinge is nil — `UIHingeInteraction` (iOS 27.1 and later) on a window's root view reports a
    /// first update whose `hinge` is nil on the unit tests' simulator (iOS 27.2, not a Duo). Not on Mac Catalyst (Xcode 27.2's
    /// known issue 185924957, §3.8) and not before iOS 27.1: skipped there.
    func testHingeIsNilOffTheDuo() throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("UIHingeInteraction is not built on Mac Catalyst (§3.8)")
        #else
        guard #available(iOS 27.1, *) else { throw XCTSkip("UIHingeInteraction is iOS 27.1 and later") }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let root = UIViewController()
        window.rootViewController = root
        window.isHidden = false
        defer { window.isHidden = true }
        final class Updates {
            var hinges: [Bool] = []
        }
        let updates = Updates()
        let first = XCTestExpectation(description: "the first hinge update")
        let interaction = UIHingeInteraction { _, update in
            updates.hinges.append(update.hinge != nil)
            if updates.hinges.count == 1 { first.fulfill() }
        }
        root.view.addInteraction(interaction)
        wait(for: [first], timeout: 5)
        XCTAssertEqual(updates.hinges.first, false, "no hinge off the Duo")
        root.view.removeInteraction(interaction)
        #endif
    }

    // MARK: No model names

    /// §4.1, §4.8 (0d-36): the new files decide nothing by a model name, the main screen or the kind of device — read here
    /// from the source (a watch on the names only): PencilPhone.swift, WindowClass.swift and FingerDefault.swift.
    func testNoModelNames() throws {
        let repository = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let files = [
            "Sources/TegakiCalendar/Support/PencilPhone.swift",
            "TegakiKit/Sources/Layout/WindowClass.swift",
            "TegakiKit/Sources/Layout/FingerDefault.swift",
        ]
        let forbidden = ["utsname", "hw.machine", ".model", "UIScreen.main", "userInterfaceIdiom"]
        for file in files {
            let text = try String(contentsOf: repository.appendingPathComponent(file), encoding: .utf8)
            XCTAssertGreaterThan(text.count, 500, "\(file) was read")
            for name in forbidden {
                XCTAssertFalse(text.contains(name), "\(file) reads \(name)")
            }
        }
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }
}
