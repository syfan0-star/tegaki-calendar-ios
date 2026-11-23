import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import TegakiCalendar

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.5, §4.6, §4.11, §6.1 T; 0e-16, 0e-17, 0e-22): the grip and the window's Pencil,
/// as far as XCTest reaches without a device — the pan takes a finger, a trackpad and a mouse and never the Pencil; it may
/// begin only when `mayBegin()` says so; `PalmWatch` (a new instance of the frozen `InkTouchObserver` on a UIWindow, fed
/// with stand-in touches as `PencilPhoneTests` feeds its own) answers with `InkCanvasView.horizontalPanMayBegin` (a Pencil
/// down → no; lifted 0.3 s ago → no; 0.6 s → yes; a finger counts for nothing); it is on the window only while two edges
/// or more are allowed; a Pencil down reaches the screen (`onPencilDown`), whose new `cancelTrigger` ends a running drag;
/// the drag starts after 10 pt, where the palm rule is asked again; the grip is one VoiceOver element with the move
/// actions. A real pan and a real Pencil are the device's (`PaletteMoveUITests` on CI, the owner's check table). Mutation
/// MT2 (the grip takes the Pencil) fails `testTheGripTakesNoPencil`.
@MainActor
final class PaletteGripTests: XCTestCase {
    // MARK: Stand-ins (the shape of PencilPhoneTests', which are private to that file)

    /// A touch that only has a type.
    private final class StandInTouch: UITouch {
        let kind: UITouch.TouchType

        init(_ kind: UITouch.TouchType) {
            self.kind = kind
            super.init()
        }

        override var type: UITouch.TouchType { kind }
        override func location(in view: UIView?) -> CGPoint { .zero }
        override func preciseLocation(in view: UIView?) -> CGPoint { .zero }
    }

    /// An event without coalesced touches.
    private final class StandInEvent: UIEvent {
        override func coalescedTouches(for touch: UITouch) -> [UITouch]? { nil }
    }

    /// A clock the test moves.
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    /// What a grip reported, in order.
    private final class Log {
        var events: [String] = []
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    private func makeWindow() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
    }

    /// The `InkTouchObserver`s on `window`.
    private func watchers(of window: UIWindow) -> [InkTouchObserver] {
        (window.gestureRecognizers ?? []).compactMap { $0 as? InkTouchObserver }
    }

    /// A grip whose callbacks write to `log`.
    private func makeGrip(_ log: Log, mayBegin: @escaping () -> Bool = { true }) -> PaletteGripView.GripView {
        let grip = PaletteGripView.GripView(frame: CGRect(x: 0, y: 0, width: 120, height: 16))
        grip.mayBegin = mayBegin
        grip.onBegan = { log.events.append("began \(Int($0.x)),\(Int($0.y))") }
        grip.onChanged = { point, velocity in log.events.append("changed \(Int(point.x)),\(Int(point.y)) v\(Int(velocity.dx))") }
        grip.onEnded = { point, velocity in log.events.append("ended \(Int(point.x)),\(Int(point.y)) v\(Int(velocity.dx))") }
        grip.onCancelled = { log.events.append("cancelled") }
        grip.onMove = { log.events.append("move \($0.rawValue)") }
        return grip
    }

    // MARK: The pan (§4.6)

    /// A finger, a trackpad and a mouse; never the Apple Pencil (MT2). One touch, on the grip's own view.
    func testTheGripTakesNoPencil() {
        let grip = PaletteGripView.GripView(frame: .zero)
        let types = Set(grip.pan.allowedTouchTypes.map(\.intValue))
        XCTAssertTrue(types.contains(UITouch.TouchType.direct.rawValue), "a finger")
        XCTAssertTrue(types.contains(UITouch.TouchType.indirectPointer.rawValue), "a trackpad or a mouse")
        XCTAssertFalse(types.contains(UITouch.TouchType.pencil.rawValue), "never the Apple Pencil")
        XCTAssertEqual(types.count, 2)
        XCTAssertEqual(PaletteGripView.allowedTouchTypes, [.direct, .indirectPointer])
        XCTAssertEqual(grip.pan.maximumNumberOfTouches, 1)
        XCTAssertTrue(grip.gestureRecognizers?.contains { $0 === grip.pan } ?? false, "the pan is on the grip")
        XCTAssertTrue(grip.pan.isEnabled)
    }

    /// `gestureRecognizerShouldBegin` is the grip's `mayBegin()`, asked each time.
    func testThePanAsksMayBegin() throws {
        var answer = false
        var asked = 0
        let grip = makeGrip(Log(), mayBegin: {
            asked += 1
            return answer
        })
        let gate = try XCTUnwrap(grip.pan.delegate)
        XCTAssertEqual(gate.gestureRecognizerShouldBegin?(grip.pan), false)
        answer = true
        XCTAssertEqual(gate.gestureRecognizerShouldBegin?(grip.pan), true)
        XCTAssertEqual(asked, 2)
        // A grip that was never configured begins nothing.
        let bare = PaletteGripView.GripView(frame: .zero)
        XCTAssertEqual(bare.pan.delegate?.gestureRecognizerShouldBegin?(bare.pan), false)
    }

    /// The drag starts 10 pt from where the touch came down; then every move is reported, and the lift with its speed.
    /// A touch that lifts or is cancelled before 10 pt reports nothing.
    func testTheDragStartsAfterTenPoints() {
        XCTAssertEqual(PaletteGripView.startDistance, 10)
        XCTAssertFalse(PaletteGripView.passedStart(CGPoint(x: 9.9, y: 0)))
        XCTAssertTrue(PaletteGripView.passedStart(CGPoint(x: 6, y: 8)), "6, 8: 10 pt")
        XCTAssertTrue(PaletteGripView.passedStart(CGPoint(x: 0, y: -10)))
        XCTAssertFalse(PaletteGripView.passedStart(CGPoint(x: CGFloat.nan, y: 20)))

        let log = Log()
        let grip = makeGrip(log)
        grip.handle(.began, location: CGPoint(x: 506, y: 1000), translation: CGPoint(x: 6, y: 0), velocity: .zero)
        XCTAssertEqual(log.events, [], "6 pt: not yet")
        XCTAssertFalse(grip.dragging)
        grip.handle(.changed, location: CGPoint(x: 506, y: 992), translation: CGPoint(x: 6, y: -8),
                    velocity: CGVector(dx: 30, dy: 0))
        XCTAssertTrue(grip.dragging)
        grip.handle(.changed, location: CGPoint(x: 600, y: 700), translation: CGPoint(x: 100, y: -300),
                    velocity: CGVector(dx: 50, dy: 0))
        grip.handle(.ended, location: CGPoint(x: 900, y: 500), translation: CGPoint(x: 400, y: -500),
                    velocity: CGVector(dx: 700, dy: 0))
        XCTAssertEqual(log.events, ["began 506,992", "changed 506,992 v30", "changed 600,700 v50", "ended 900,500 v700"])
        XCTAssertFalse(grip.dragging)

        log.events = []
        grip.handle(.began, location: .zero, translation: CGPoint(x: 3, y: 3), velocity: .zero)
        grip.handle(.ended, location: .zero, translation: CGPoint(x: 4, y: 4), velocity: .zero)
        grip.handle(.began, location: .zero, translation: CGPoint(x: 2, y: 0), velocity: .zero)
        grip.handle(.cancelled, location: .zero, translation: CGPoint(x: 2, y: 0), velocity: .zero)
        XCTAssertEqual(log.events, [], "a touch under 10 pt is nothing")
        // The system ends a running drag: reported at once.
        grip.handle(.began, location: CGPoint(x: 1, y: 2), translation: CGPoint(x: 0, y: 12), velocity: .zero)
        grip.handle(.cancelled, location: .zero, translation: .zero, velocity: .zero)
        XCTAssertEqual(log.events, ["began 1,2", "changed 1,2 v0", "cancelled"])
        XCTAssertFalse(grip.dragging)
        grip.handle(.failed, location: .zero, translation: .zero, velocity: .zero)
        XCTAssertEqual(log.events.count, 3, "nothing more")
    }

    /// A new `cancelTrigger` ends a running drag (reported on the next turn: it comes inside a SwiftUI update) and turns
    /// the pan off and on again (UIKit cancels the touch it holds); the same value, or a new one without a drag, reports
    /// nothing. The value at creation ends nothing.
    func testCancelTriggerEndsARunningDrag() async {
        let log = Log()
        let grip = makeGrip(log)
        grip.lastCancelTrigger = 3
        grip.apply(cancelTrigger: 3)
        await settle()
        XCTAssertEqual(log.events, [], "the same value")

        grip.handle(.began, location: CGPoint(x: 10, y: 10), translation: CGPoint(x: 0, y: -20), velocity: .zero)
        XCTAssertTrue(grip.dragging)
        log.events = []
        grip.apply(cancelTrigger: 4)
        XCTAssertFalse(grip.dragging, "ended at once")
        XCTAssertTrue(grip.pan.isEnabled, "the pan is on again")
        XCTAssertEqual(log.events, [], "reported on the next turn, not inside the update")
        await settle()
        XCTAssertEqual(log.events, ["cancelled"])
        // The pan's own .cancelled after that is silent; a later move is not a drag any more.
        grip.handle(.cancelled, location: .zero, translation: .zero, velocity: .zero)
        grip.handle(.changed, location: .zero, translation: CGPoint(x: 0, y: 4), velocity: .zero)
        await settle()
        XCTAssertEqual(log.events, ["cancelled"])

        grip.apply(cancelTrigger: 5)
        await settle()
        XCTAssertEqual(log.events, ["cancelled"], "no drag: nothing to report")
        XCTAssertEqual(grip.lastCancelTrigger, 5)
        XCTAssertTrue(grip.pan.isEnabled)
    }

    // MARK: The window's Pencil (§4.6)

    /// `mayBegin(now:)` is `InkCanvasView.horizontalPanMayBegin` with the window's Pencils, fed through the frozen
    /// `InkTouchObserver` on the window: a Pencil down → no; lifted 0.3 s ago → no; 0.6 s → yes. A finger and a pointer
    /// count for nothing. Two Pencils (a palm's second contact): no until both lifted.
    func testPalmRuleFollowsTheCanvas() throws {
        let clock = Clock()
        let palm = PalmWatch(clock: { clock.now })
        let window = makeWindow()
        palm.attach(to: window)
        let observer = try XCTUnwrap(watchers(of: window).first)
        XCTAssertEqual(watchers(of: window).count, 1)
        let start = clock.now
        XCTAssertTrue(palm.mayBegin(now: start), "no Pencil yet")
        XCTAssertEqual(palm.mayBegin(now: start),
                       InkCanvasView.horizontalPanMayBegin(pencilsDown: 0, lastPencilUp: nil, now: start))

        let finger = StandInTouch(.direct)
        observer.touchesBegan([finger], with: StandInEvent())
        XCTAssertTrue(palm.mayBegin(now: start), "a finger is not a Pencil")
        let pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        XCTAssertEqual(palm.pencilsDown, 1)
        XCTAssertFalse(palm.mayBegin(now: start), "a Pencil touches")
        XCTAssertFalse(palm.mayBegin(now: start.addingTimeInterval(60)), "however long it touches")
        observer.touchesEnded([finger], with: StandInEvent())
        XCTAssertFalse(palm.mayBegin(now: start), "the finger lifted; the Pencil still touches")

        clock.now = start.addingTimeInterval(2)
        observer.touchesEnded([pencil], with: StandInEvent())
        XCTAssertEqual(palm.pencilsDown, 0)
        XCTAssertEqual(palm.lastPencilUp, clock.now)
        let up = clock.now
        XCTAssertFalse(palm.mayBegin(now: up.addingTimeInterval(0.3)), "0.3 s after the lift")
        XCTAssertTrue(palm.mayBegin(now: up.addingTimeInterval(0.6)), "0.6 s after the lift")
        XCTAssertTrue(palm.mayBegin(now: up.addingTimeInterval(-1)), "a clock set back does not hold the grip")
        for (down, lifted, offset) in [(0, true, 0.3), (0, true, 0.6), (1, true, 5), (0, false, 0), (2, true, 0.1)]
            as [(Int, Bool, TimeInterval)] {
            let now = up.addingTimeInterval(offset)
            let rule = InkCanvasView.horizontalPanMayBegin(pencilsDown: down, lastPencilUp: lifted ? up : nil, now: now)
            XCTAssertEqual(rule, down == 0 && (!lifted || offset >= InkCanvasView.palmHold), "the frozen rule, \(down) \(offset)")
        }
        XCTAssertEqual(InkCanvasView.palmHold, 0.5)

        // Two Pencils down (a second contact): held until both lifted.
        let second = StandInTouch(.pencil)
        let third = StandInTouch(.pencil)
        observer.touchesBegan([second, third], with: StandInEvent())
        XCTAssertEqual(palm.pencilsDown, 2)
        clock.now = up.addingTimeInterval(10)
        observer.touchesEnded([second], with: StandInEvent())
        XCTAssertFalse(palm.mayBegin(now: clock.now.addingTimeInterval(1)), "one still touches")
        observer.touchesCancelled([third], with: StandInEvent())
        XCTAssertTrue(palm.mayBegin(now: clock.now.addingTimeInterval(0.51)), "both lifted 0.51 s ago")
        XCTAssertFalse(palm.mayBegin(now: clock.now.addingTimeInterval(0.49)))

        // The pointer (a mouse, a trackpad) is not counted either.
        palm.touched(.down(.indirectPointer))
        XCTAssertEqual(palm.pencilsDown, 0)
        palm.detach()
    }

    /// The watcher is on the window only while two edges or more are allowed (the grip shows only then); once per window;
    /// off the old window when another comes; off with no window. Detached, a Pencil still down counts as lifted.
    func testPalmWatchFollowsTheAllowedEdges() {
        let palm = PalmWatch()
        let window = makeWindow()
        XCTAssertFalse(PalmWatch.wanted(allowed: [.bottom]))
        XCTAssertTrue(PalmWatch.wanted(allowed: [.bottom, .top]))
        XCTAssertTrue(PalmWatch.wanted(allowed: [.bottom, .top, .left, .right]))

        palm.follow(window: window, allowed: [.bottom])
        XCTAssertFalse(palm.isAttached)
        XCTAssertTrue(watchers(of: window).isEmpty, "one edge: no watcher (every iPhone, a narrow iPad window)")
        palm.follow(window: window, allowed: [.bottom, .top])
        XCTAssertTrue(palm.isAttached)
        XCTAssertEqual(watchers(of: window).count, 1)
        XCTAssertTrue(palm.window === window)
        palm.follow(window: window, allowed: [.bottom, .top, .left, .right])
        XCTAssertEqual(watchers(of: window).count, 1, "the same window: once")
        palm.attach(to: window)
        XCTAssertEqual(watchers(of: window).count, 1)

        let other = UIWindow(frame: CGRect(x: 0, y: 0, width: 744, height: 1133))
        palm.follow(window: other, allowed: [.bottom, .top])
        XCTAssertTrue(watchers(of: window).isEmpty, "off the old window")
        XCTAssertEqual(watchers(of: other).count, 1)

        palm.touched(.down(.pencil))
        XCTAssertEqual(palm.pencilsDown, 1)
        palm.follow(window: other, allowed: [.bottom])
        XCTAssertFalse(palm.isAttached)
        XCTAssertTrue(watchers(of: other).isEmpty, "back to one edge: off")
        XCTAssertNil(palm.window)
        XCTAssertEqual(palm.pencilsDown, 0, "what was down counts as lifted")
        XCTAssertNotNil(palm.lastPencilUp)

        palm.follow(window: other, allowed: [.bottom, .top])
        XCTAssertTrue(palm.isAttached)
        palm.follow(window: nil, allowed: [.bottom, .top])
        XCTAssertFalse(palm.isAttached, "no window: off")
        XCTAssertTrue(watchers(of: other).isEmpty)
    }

    /// A Pencil coming down anywhere in the window reaches the screen (`onPencilDown`) — a finger does not — and the
    /// screen's new `cancelTrigger` ends the drag the grip was running.
    func testAPencilDownCancelsTheDrag() async throws {
        let palm = PalmWatch()
        let window = makeWindow()
        palm.attach(to: window)
        let observer = try XCTUnwrap(watchers(of: window).first)
        let log = Log()
        let grip = makeGrip(log, mayBegin: { palm.mayBegin(now: Date()) })
        var trigger = 0
        var downs = 0
        palm.onPencilDown = {
            downs += 1
            trigger += 1
            grip.apply(cancelTrigger: trigger)
        }

        XCTAssertEqual(grip.pan.delegate?.gestureRecognizerShouldBegin?(grip.pan), true, "no Pencil: the grip may begin")
        grip.handle(.began, location: CGPoint(x: 5, y: 5), translation: CGPoint(x: 0, y: -12), velocity: .zero)
        XCTAssertTrue(grip.dragging)
        let finger = StandInTouch(.direct)
        observer.touchesBegan([finger], with: StandInEvent())
        XCTAssertEqual(downs, 0, "a second finger is not a Pencil")
        XCTAssertTrue(grip.dragging)

        let pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        XCTAssertEqual(downs, 1)
        XCTAssertFalse(grip.dragging, "the Pencil ended the drag")
        await settle()
        XCTAssertEqual(log.events, ["began 5,5", "changed 5,5 v0", "cancelled"])
        XCTAssertEqual(grip.pan.delegate?.gestureRecognizerShouldBegin?(grip.pan), false, "and the palm holds the next one")
        observer.touchesEnded([pencil, finger], with: StandInEvent())
        palm.detach()
    }

    /// The palm rule is asked again where the drag starts: UIKit's pan may begin under 10 pt (a mouse, a trackpad), and a
    /// Pencil that comes down — or lifts less than 0.5 s before — while the touch has not moved 10 pt finds no running drag
    /// to cancel (the screen's `cancelPaletteDrag` writes nothing then). At 10 pt the grip asks `mayBegin()` once more: a no
    /// forgets the touch (the pan off and on again) and reports nothing, neither a start nor a cancel.
    func testThePalmRuleIsAskedAgainWhereTheDragStarts() async throws {
        let clock = Clock()
        let palm = PalmWatch(clock: { clock.now })
        let window = makeWindow()
        palm.attach(to: window)
        let observer = try XCTUnwrap(watchers(of: window).first)
        let log = Log()
        var asked = 0
        let grip = makeGrip(log, mayBegin: {
            asked += 1
            return palm.mayBegin(now: clock.now)
        })
        var downs = 0
        // The screen's `cancelPaletteDrag`: no drag runs yet, so nothing is cancelled.
        palm.onPencilDown = { downs += 1 }

        // The pan began at 6 pt with no Pencil; then a Pencil comes down; then the touch passes 10 pt.
        XCTAssertEqual(grip.pan.delegate?.gestureRecognizerShouldBegin?(grip.pan), true, "no Pencil: the pan may begin")
        grip.handle(.began, location: CGPoint(x: 506, y: 1000), translation: CGPoint(x: 6, y: 0), velocity: .zero)
        XCTAssertFalse(grip.dragging, "6 pt: not yet")
        let pencil = StandInTouch(.pencil)
        observer.touchesBegan([pencil], with: StandInEvent())
        XCTAssertEqual(downs, 1)
        asked = 0
        grip.handle(.changed, location: CGPoint(x: 512, y: 1000), translation: CGPoint(x: 12, y: 0), velocity: CGVector(dx: 40, dy: 0))
        XCTAssertEqual(asked, 1, "asked again at 10 pt")
        XCTAssertFalse(grip.dragging, "the Pencil on the paper: no drag")
        XCTAssertTrue(grip.pan.isEnabled, "the pan is on again: turned off and on, the touch is forgotten")
        // UIKit's own cancel of that touch, and any late move, report nothing.
        grip.handle(.cancelled, location: .zero, translation: .zero, velocity: .zero)
        await settle()
        XCTAssertEqual(log.events, [], "nothing began, nothing to cancel")

        // A Pencil that lifted 0.3 s before the 10 pt: still no. 0.6 s: the drag starts as before.
        observer.touchesEnded([pencil], with: StandInEvent())
        let up = clock.now
        grip.handle(.began, location: .zero, translation: CGPoint(x: 0, y: -6), velocity: .zero)
        clock.now = up.addingTimeInterval(0.3)
        grip.handle(.changed, location: CGPoint(x: 0, y: -12), translation: CGPoint(x: 0, y: -12), velocity: .zero)
        XCTAssertFalse(grip.dragging, "lifted 0.3 s ago")
        await settle()
        XCTAssertEqual(log.events, [])
        grip.handle(.began, location: CGPoint(x: 1, y: 2), translation: CGPoint(x: 6, y: 0), velocity: .zero)
        clock.now = up.addingTimeInterval(0.6)
        grip.handle(.changed, location: CGPoint(x: 1, y: 2), translation: CGPoint(x: 12, y: 0), velocity: .zero)
        XCTAssertTrue(grip.dragging, "lifted 0.6 s ago")
        XCTAssertEqual(log.events, ["began 1,2", "changed 1,2 v0"])
        // A running drag is not asked on every move (a Pencil down ends it through the screen's `cancelTrigger`).
        asked = 0
        grip.handle(.changed, location: CGPoint(x: 1, y: 40), translation: CGPoint(x: 6, y: 38), velocity: .zero)
        XCTAssertEqual(asked, 0)
        grip.handle(.ended, location: CGPoint(x: 1, y: 40), translation: CGPoint(x: 6, y: 38), velocity: .zero)
        XCTAssertEqual(log.events, ["began 1,2", "changed 1,2 v0", "changed 1,40 v0", "ended 1,40 v0"])
        palm.detach()
    }

    // MARK: VoiceOver (§4.11)

    /// The grip is one element: 「ツールバーを動かす」, its hint, the identifier `toolbar.grip`, and an action for each of
    /// `moveTargets` that calls `onMove`.
    func testTheGripIsOneVoiceOverElement() throws {
        let log = Log()
        let grip = makeGrip(log)
        XCTAssertTrue(grip.isAccessibilityElement)
        XCTAssertEqual(grip.accessibilityLabel, "ツールバーを動かす")
        XCTAssertEqual(grip.accessibilityHint, "上下左右の端へ移せます")
        XCTAssertEqual(grip.accessibilityIdentifier, "toolbar.grip")
        XCTAssertEqual(PaletteGripView.identifier, "toolbar.grip")

        grip.configure(PaletteGripView(mayBegin: { true }, onBegan: { _ in }, onChanged: { _, _ in }, onEnded: { _, _ in },
                                       onCancelled: {}, cancelTrigger: 0, edge: .left,
                                       moveTargets: [.bottom, .top, .right], onMove: { log.events.append("move \($0.rawValue)") }))
        XCTAssertEqual(grip.edge, .left)
        let actions = try XCTUnwrap(grip.accessibilityCustomActions)
        XCTAssertEqual(actions.map(\.name), ["下へ移す", "上へ移す", "右へ移す"])
        XCTAssertEqual(actions[2].actionHandler?(actions[2]), true)
        XCTAssertEqual(log.events, ["move right"])

        // §2.1's six arguments alone: a bottom grip without actions.
        let plain = PaletteGripView(mayBegin: { true }, onBegan: { _ in }, onChanged: { _, _ in }, onEnded: { _, _ in },
                                    onCancelled: {}, cancelTrigger: 0)
        XCTAssertEqual(plain.edge, .bottom)
        XCTAssertEqual(plain.moveTargets, [])
        grip.configure(plain)
        XCTAssertEqual(grip.accessibilityCustomActions?.count ?? 0, 0)
    }

    /// The mark lies along the edge over the bar's padding (`ToolbarLogic.gripMarkFrame`).
    func testTheMarkFollowsTheEdge() throws {
        let grip = PaletteGripView.GripView(frame: CGRect(origin: .zero, size: ToolbarLogic.gripSize(for: .bottom)))
        grip.setNeedsLayout()
        grip.layoutIfNeeded()
        let mark = try XCTUnwrap(grip.subviews.first)
        XCTAssertEqual(mark.frame, CGRect(x: 42, y: 9.5, width: 36, height: 5))
        XCTAssertFalse(mark.isUserInteractionEnabled)
        grip.configure(PaletteGripView(mayBegin: { true }, onBegan: { _ in }, onChanged: { _, _ in }, onEnded: { _, _ in },
                                       onCancelled: {}, cancelTrigger: 0, edge: .right))
        grip.frame = CGRect(origin: .zero, size: ToolbarLogic.gripSize(for: .right))
        grip.setNeedsLayout()
        grip.layoutIfNeeded()
        XCTAssertEqual(mark.frame, CGRect(x: 8.5, y: 42, width: 5, height: 36))
    }
}
