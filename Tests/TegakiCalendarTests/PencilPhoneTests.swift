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
// answer and its 2-second fallback on a `TestSleeper` (a cancelled wait answering nothing, on a sleep that returns at
// cancellation; the app's own `usesHinge`, true since 1.4 D1c, changing nothing off the Duo), no update reporting a hinge off the Duo (iOS 27.1 and later, not on Mac Catalyst; no update at all and
// an update with a nil hinge both pass, CI run 44649291195), and no model name or kind of device read by the new files.
// Mutations (§6, `r14-q-m1`): the glue counting a finger as a Pencil fails `testWatcherCountsEveryTouch` and
// `testPencilLiftTurnsFingerOffEndToEnd`; the guide records always forgotten fails the latter's carried row; the screen's
// Binding (`CalendarRootScreen.allowFingerBinding`, handed to ToolbarView and SettingsScreen) not writing "person" — its
// set back to 1.3's `allowFinger = value`, or without `PencilPhone.personSet` or `personSwitched` — fails
// `testPersonSetMarksThePerson` (read from the source: XCTest does not run the screen's View, C3-M3), as `personSet` itself
// not writing "person" does; an action a lift decided written during the lift's delivery fails
// `testPencilTapOnTheSwitchStaysThePersons`; the hinge's wait answering "no hinge" when it is cancelled fails
// `testACancelledHingeWaitAnswersNothing`. A lift's action waits for the main actor's next turn (`PencilPhone.afterTheLift`),
// so the tests let it run (`settle`) before they look, "nothing" included.

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

    /// A sleep that suspends until `advance()` and, like `Task.sleep`, returns at once when its task is cancelled
    /// (`TestSleeper`, shared with the engine's tests, ignores cancellation).
    @MainActor
    private final class CancellableSleeper {
        /// The lengths of every `sleep`, in order.
        private(set) var recorded: [TimeInterval] = []
        /// How many sleeps returned because their task was cancelled.
        private(set) var cancelled = 0
        private var parked: [Int: CheckedContinuation<Void, Never>] = [:]
        private var wokenEarly: Set<Int> = []
        private var next = 0

        /// How many sleeps are suspended right now.
        var waiting: Int { parked.count }

        func sleep(_ duration: TimeInterval) async {
            recorded.append(duration)
            let id = next
            next += 1
            await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    if wokenEarly.remove(id) != nil {
                        continuation.resume()
                    } else {
                        parked[id] = continuation
                    }
                }
            } onCancel: {
                Task { @MainActor in self.wake(id, cancelled: true) }
            }
        }

        /// Wakes every sleep suspended now, in the order they started.
        func advance() async {
            for id in parked.keys.sorted() {
                wake(id, cancelled: false)
            }
            await Task.yield()
        }

        private func wake(_ id: Int, cancelled: Bool) {
            if cancelled { self.cancelled += 1 }
            if let continuation = parked.removeValue(forKey: id) {
                continuation.resume()
            } else {
                wokenEarly.insert(id)
            }
        }
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
    /// after it the app changes nothing, not even on a Pencil's lift. The Binding is the screen's (`allowFingerBinding`),
    /// read from the source in code only (comments and strings blanked, `WeekMemoSpanTests.codeOnly`; XCTest does not run
    /// the screen's View, C3-M3): its get is today's 「指でも書く」, its set `personSet` then `personSwitched`, and it is what
    /// ToolbarView and SettingsScreen get — no view gets the `@AppStorage`'s own `$allowFinger`. Fails with `personSet` not
    /// writing "person", or with the Binding's set not going through it (§6's mutation).
    func testPersonSetMarksThePerson() async throws {
        let code = try Self.screenCode()
        let binding = try Self.body(of: "private var allowFingerBinding: Binding<Bool> {", in: code)
        XCTAssertTrue(binding.hasPrefix("Binding( get: { allowFinger }, set: { value in PencilPhone.personSet(value, defaults: .standard) "
                                        + "pencilPhone.personSwitched() } )"), "the switches' Binding: \(binding)")
        XCTAssertEqual(code.components(separatedBy: "allowFinger: allowFingerBinding,").count - 1, 2,
                       "the Binding goes to ToolbarView and SettingsScreen")
        XCTAssertFalse(code.contains("$allowFinger"), "no view writes 「指でも書く」 past the person's mark")

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
        await settle()
        XCTAssertEqual(log.actions, [], "the person's choice stays")
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, "person")
    }

    /// §4.8 (本人の選びは守る, C6): a Pencil tap on the toolbar's 「指でも書く」 (a button-style Toggle: at the touch-up it reads
    /// the value and writes its opposite through the screen's Binding) is the person's. The window's watcher hears the lift
    /// first, inside `touchesEnded`; the app's turnOff waits for the main actor's next turn, and the person's switch in
    /// between (`personSet`, `personSwitched`) wins: off as tapped, the mark "person", the guide records left alone. Fails
    /// with the action written during the lift's delivery (the button then reads off and turns it on again).
    func testPencilTapOnTheSwitchStaysThePersons() async throws {
        AppSettings.markSpanGuideShown(.week)
        AppSettings.markSpanGuideShown(.day)
        let launch = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        XCTAssertEqual(launch.origin, .app)
        let (phone, log) = makePhone()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        phone.attach(to: window, isPad: false)
        phone.appeared(allowFinger: launch.allowFinger, origin: launch.origin)
        let observer = try watcher(of: window)
        let pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertTrue(allowFinger, "nothing written while the lift is delivered")
        // The Toggle's action at the same touch-up, as the screen's Binding does it.
        let tapped = !allowFinger
        PencilPhone.personSet(tapped, defaults: suite)
        phone.personSwitched()
        await settle()
        XCTAssertEqual(log.actions, [], "the person's tap wins")
        XCTAssertFalse(allowFinger, "off, as the person tapped it")
        XCTAssertEqual(mark, "person")
        XCTAssertEqual(phone.origin, .person)
        XCTAssertTrue(AppSettings.spanGuideShown(.week), "no guide again: the person chose")
        XCTAssertTrue(AppSettings.spanGuideShown(.day))

        // Without the person's tap the same lift turns it off on that next turn.
        suite.removePersistentDomain(forName: suiteName)
        let again = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        let (second, secondLog) = makePhone()
        let secondWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        second.attach(to: secondWindow, isPad: false)
        second.appeared(allowFinger: again.allowFinger, origin: again.origin)
        let secondObserver = try watcher(of: secondWindow)
        let other = StandInTouch(.pencil)
        secondObserver.touchesBegan([other], with: StandInEvent())
        secondObserver.touchesEnded([other], with: StandInEvent())
        XCTAssertEqual(secondLog.actions, [], "not yet: the lift is still being delivered")
        await settle()
        XCTAssertEqual(secondLog.actions, [.turnOff(rearmGuide: true)])
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, thisDevice)
    }

    /// §2.1, §4.8 (C2, 0d-37): the first launch's default — 1.3's (「指でも書く」 on a phone, off on an iPad,
    /// `allowFingerDrawingChosen` true) with this device's mark beside it, so the app's own value reads `.app`; a launch with
    /// `allowFingerDrawingChosen` on record (an update from 1.3, or any later launch) writes nothing, so 1.3's value without a
    /// mark stays carried over; this device's mark not readable at the first launch writes no mark (carried, P only); an
    /// iPad writes no mark (carried: §4.8, nothing on an iPad).
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

        // An iPad's first launch: 1.3's off and no mark (§4.8: nothing on an iPad; its FingerDefault answers nothing), so a
        // phone it is restored to reads the off as carried over and keeps it, as 1.3 did — never `.moved` and turned on.
        suite.removePersistentDomain(forName: suiteName)
        launch = PencilPhone.launchDefault(suite, isPad: true, device: thisDevice)
        XCTAssertFalse(launch.allowFinger)
        XCTAssertFalse(allowFinger)
        XCTAssertTrue(suite.bool(forKey: AppSettings.allowFingerChosenKey))
        XCTAssertEqual(launch.origin, .carried)
        XCTAssertNil(mark, "no mark on an iPad")
        XCTAssertEqual(PencilPhone.origin(suite, device: otherDevice), .carried, "on another device: carried over, not moved")

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
    /// 1.4.3 (review UX-5): every kind of `SpanKinds.ordered` alike, the month's record too (and the year's with D1y).
    func testPencilLiftTurnsFingerOffEndToEnd() async throws {
        // The app's own value: 1.4's first launch.
        AppSettings.markSpanGuideShown(.week)
        AppSettings.markSpanGuideShown(.day)
        AppSettings.markSpanGuideShown(.month)
        AppSettings.markSpanGuideShown(.year)
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
        await settle()
        XCTAssertEqual(log.actions, [], "a finger alone is not P")
        XCTAssertTrue(allowFinger)
        var pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        XCTAssertEqual(log.actions, [], "not while the Pencil is down")
        XCTAssertTrue(allowFinger)
        observer.touchesEnded([pencil], with: StandInEvent())
        await settle()
        XCTAssertEqual(log.actions, [.turnOff(rearmGuide: true)])
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, thisDevice)
        XCTAssertEqual(phone.origin, .app)
        XCTAssertFalse(AppSettings.spanGuideShown(.week), "the guide shows once more")
        XCTAssertFalse(AppSettings.spanGuideShown(.day))
        XCTAssertTrue(SpanKinds.ordered.contains(.month))
        for kind in [PageKind.month, .year] {
            XCTAssertEqual(AppSettings.spanGuideShown(kind), !SpanKinds.joined.contains(kind),
                           "\(kind): forgotten when it joins (the month since 1.4.3), else left as it was")
        }
        pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        observer.touchesEnded([pencil], with: StandInEvent())
        await settle()
        XCTAssertEqual(log.actions.count, 1, "once")

        // A value carried over from 1.3 (on, no mark): off at the lift, the guide records stay.
        suite.removePersistentDomain(forName: suiteName)
        suite.set(true, forKey: AppSettings.allowFingerChosenKey)
        suite.set(true, forKey: AppSettings.allowFingerKey)
        AppSettings.markSpanGuideShown(.week)
        AppSettings.markSpanGuideShown(.day)
        AppSettings.markSpanGuideShown(.month)
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
        await settle()
        XCTAssertEqual(log.actions, [], "a finger still down: not yet")
        XCTAssertTrue(allowFinger)
        observer.touchesEnded([holding], with: StandInEvent())
        await settle()
        XCTAssertEqual(log.actions, [.turnOff(rearmGuide: false)])
        XCTAssertFalse(allowFinger)
        XCTAssertEqual(mark, thisDevice, "the app's value on this device now")
        XCTAssertEqual(phone.origin, .app, "the app's value on this device now")
        XCTAssertTrue(AppSettings.spanGuideShown(.week), "carried over: no guide again")
        XCTAssertTrue(AppSettings.spanGuideShown(.day))
        XCTAssertTrue(AppSettings.spanGuideShown(.month), "carried over: the month's record stays too")
    }

    // MARK: The hinge (H)

    /// §4.8: the hinge's answer and its fallback. With no hinge watched (a phone made with `usesHinge` false here; `attach`
    /// answers the same before iOS 27.1 and on Mac Catalyst) the answer is "no hinge" at once, so a Duo's off moved to a phone
    /// without a hinge is turned on again once. Watched, the first update has `hingeWait` (2 s, on the injected sleep): none
    /// in time is "no hinge"; an answer in time is the answer, and the wait then adds nothing. Last, the app's own constant
    /// (true since 1.4 D1c, §4.2's measurement) on a window off the Duo: the app's first-launch default stays on.
    func testHingeAnswerAndItsFallback() async {
        XCTAssertTrue(PencilPhone.usesHinge, "§4.2, duo.yml run 44696154794: the Duo's outer screen hinge=closed, the iPhone 17's nil")
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

        // The app's own constant (true since 1.4 D1c) on a window off the Duo, the unit tests' simulator, as on an ordinary
        // iPhone: the hinge is watched, and whatever comes — no update within the wait, or an update without a hinge — is
        // "no hinge", so the first launch's default stays on, the mark and the guide records as they were (§4.8, F2: an
        // ordinary iPhone keeps 1.3's 「指でも書く」). A hinge reported here fails it, as it fails testHingeIsNilOffTheDuo.
        suite.removePersistentDomain(forName: suiteName)
        AppSettings.markSpanGuideShown(.week)
        let first = PencilPhone.launchDefault(suite, isPad: false, device: thisDevice)
        let watched = TestSleeper()
        (phone, log) = makePhone(usesHinge: PencilPhone.usesHinge, sleeper: watched)
        phone.appeared(allowFinger: first.allowFinger, origin: first.origin)
        phone.attach(to: UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874)), isPad: false)
        await settle()
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            XCTAssertEqual(watched.recorded, [PencilPhone.hingeWait], "the hinge watched: the wait for its first update")
        }
        #endif
        await watched.advance()
        await settle()
        let hinges = log.inputs.compactMap { input -> Bool? in
            if case .hinge(let present) = input { return present } else { return nil }
        }
        XCTAssertFalse(hinges.isEmpty, "an answer: an update, or the wait's end")
        XCTAssertFalse(hinges.contains(true), "no hinge off the Duo: \(hinges)")
        XCTAssertEqual(log.actions, [], "nothing changes off the Duo")
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, thisDevice)
        XCTAssertTrue(AppSettings.spanGuideShown(.week))
    }

    /// §2.1, §4.8: only the wait's full time is silence. A wait that another one replaces (`waitForFirstHingeUpdate`
    /// again, as `attach` does when the watchers move to another window) answers nothing; the new wait's end is the one
    /// "no hinge". The sleep here returns at once when its task is cancelled, as the app's `Task.sleep` does, so a cancelled
    /// wait read as the end of the 2 s would answer "no hinge" at once and turn a Duo's off moved here on again before the
    /// new window's hinge had its time. Fails with the wait's end read without `Task.isCancelled`.
    func testACancelledHingeWaitAnswersNothing() async {
        let sleeper = CancellableSleeper()
        suite.set(false, forKey: AppSettings.allowFingerKey)
        suite.set(otherDevice, forKey: PencilPhone.markKey)
        let log = Log()
        let device = thisDevice
        let phone = PencilPhone(isPad: false, defaults: suite, deviceMark: { device }, usesHinge: false,
                                sleep: { duration in await sleeper.sleep(duration) })
        phone.onInput = { log.inputs.append($0) }
        phone.onApply = { log.actions.append($0) }
        phone.appeared(allowFinger: false, origin: .moved)
        phone.waitForFirstHingeUpdate()
        await settle()
        XCTAssertEqual(sleeper.waiting, 1)
        phone.waitForFirstHingeUpdate()
        await settle()
        XCTAssertEqual(sleeper.recorded, [PencilPhone.hingeWait, PencilPhone.hingeWait])
        XCTAssertEqual(sleeper.cancelled, 1, "the first wait was cancelled and its sleep returned")
        XCTAssertEqual(sleeper.waiting, 1, "the second wait still waits")
        XCTAssertEqual(log.inputs.filter { if case .hinge = $0 { return true } else { return false } }, [],
                       "a cancelled wait is not 2 s of silence")
        XCTAssertEqual(log.actions, [], "still waiting for the hinge's answer")
        XCTAssertFalse(allowFinger)

        await sleeper.advance()
        await settle()
        XCTAssertEqual(log.inputs.filter { if case .hinge = $0 { return true } else { return false } }, [.hinge(false)],
                       "the second wait's end: \"no hinge\", once")
        XCTAssertEqual(log.actions, [.turnOnAgain])
        XCTAssertTrue(allowFinger)
        XCTAssertEqual(mark, thisDevice)
    }

    /// §4.8, F2: off the Duo no update ever reports a hinge. `UIHingeInteraction` (iOS 27.1 and later) on a window's root
    /// view, on the unit tests' simulator (iOS 27.2, not a Duo), is watched for 3 s (`PencilPhone.hingeWait` and more): an
    /// update with a hinge fails the test (an inverted expectation), and both things the app reads as "no hinge" pass —
    /// no update at all (`PencilPhone.waitForFirstHingeUpdate` and `ScreenshotMeasure` answer "no hinge" after 2 s) and an
    /// update whose `hinge` is nil. The first version waited for a first update (Apple's documentation: the handler is called
    /// with the initial state) and failed on CI run 44649291195 (iPad Pro 13-inch (M5), iOS 27.2 24B8117): no update came
    /// within 5 s. The updates seen are logged (`duo hinge unit:`), so the runs record which of the two the simulator does.
    /// Not on Mac Catalyst (Xcode 27.2's known issue 185924957, §3.8) and not before iOS 27.1: skipped there.
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
            var readings: [String] = []
            var waiting = true
        }
        let updates = Updates()
        let hinged = XCTestExpectation(description: "an update that reports a hinge")
        hinged.isInverted = true
        hinged.assertForOverFulfill = false
        let interaction = UIHingeInteraction { _, update in
            guard let hinge = update.hinge else {
                updates.readings.append("nil")
                return
            }
            let status: String
            switch hinge.status {
            case .closed: status = "closed"
            case .partiallyOpen: status = "partiallyOpen"
            case .fullyOpen: status = "fullyOpen"
            case .unknown: status = "unknown"
            @unknown default: status = "unknown(\(hinge.status.rawValue))"
            }
            updates.readings.append("\(status) angle=\(String(format: "%.3f", Double(hinge.angle)))")
            if updates.waiting { hinged.fulfill() }
        }
        root.view.addInteraction(interaction)
        wait(for: [hinged], timeout: 3)
        updates.waiting = false
        // What the 3 s saw, before the removal (leaving the hierarchy may send an update of its own).
        let readings = updates.readings
        root.view.removeInteraction(interaction)
        let line = "duo hinge unit: \(readings.count) update(s) in 3 s on a window's root view "
            + "(window in a scene: \(scene != nil)): [\(readings.joined(separator: ", "))]"
        print(line)
        NSLog("%@", line)
        XCTAssertTrue(readings.allSatisfy { $0 == "nil" }, "no hinge off the Duo: \(readings)")
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

    // MARK: The screen's source

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// CalendarRootScreen.swift in code only (comments and strings blanked, `WeekMemoSpanTests.codeOnly`), every run of
    /// white space one space.
    private static func screenCode() throws -> String {
        let url = repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        let code = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
        return code.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The body of the declaration of `code` whose head (to its "{") is `head` (the shape of OnePageRevealTests' helper).
    private static func body(of head: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: head), "\(head) is in CalendarRootScreen.swift")
        var depth = 1
        var end = start.upperBound
        while end < code.endIndex, depth > 0 {
            if code[end] == "{" { depth += 1 } else if code[end] == "}" { depth -= 1 }
            end = code.index(after: end)
        }
        return code[start.upperBound..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
