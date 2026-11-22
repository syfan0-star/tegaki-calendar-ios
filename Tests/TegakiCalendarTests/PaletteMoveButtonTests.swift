import Layout
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.1's second rework (docs/R1_4_1_CONTRACT.md §17.2, §17.4): the 「動かす」 button before 「しまう」, as far as XCTest reaches
/// without a device — it shows exactly where the grip does (`ToolbarLogic.showsMoveButton`, never on an iPhone, a window with
/// the bottom alone, the dock or a peek); a touch that lifts before 10 pt is a tap, one that moved 10 pt or began the drag is
/// not, a Pencil's touch is a tap when it lifts (`PaletteMoveButtonView.Press`); a tap opens the choice of edges with any touch
/// and whatever the palm rule says; the drag is the grip's (`PaletteGripView.PanView`: no Pencil, the palm rule, 10 pt, the
/// cancel trigger); the choices are the grip's actions (`ToolbarLogic.moveTargets`, never the current edge) and an edge the
/// window no longer allows does nothing; the button is one VoiceOver element (「ツールバーを動かす」, its hint, a button,
/// `toolbar.move`, the 「…へ移す」 actions, activation opens the choice); its name fits the 48 pt face in every language, so
/// the row gives up exactly 48 pt (the upright column 44) and the bar keeps its 60 pt. A real tap, drag and dialog on the
/// screen are `PaletteMoveUITests.testTheMoveButtonMovesTheBar`'s (CI's 13-inch iPad); the Apple Pencil is the owner's
/// (確かめ表 14). PaletteGripTests is unchanged and still checks the grip on the shared pan. `--screenshot-palette-menu` (the
/// photo of the open choice) is read here too.
///
/// 1.4.1's third rework (docs/R1_4_1_CONTRACT.md §18.2, §18.3, 0e-26): the button is on the peeking bar too (not on the dock,
/// an iPhone or a window with the bottom alone; the grip still only on the open bar), where it is a tap only (`drags` false:
/// the pan never begins, a finger moved 10 pt is nothing) and a choice keeps the edge and opens the bar there
/// (`paletteDropped(mode: .peek)` stores; the screen's choice path applies the table's `.placementChosen` step in one
/// transaction). Mutations MB5 (no button on a peek) and MB6 (no `(.peek, .placementChosen)` row) fail here. The real dock,
/// peek, choice and 「しまう」 are `PaletteMoveUITests.testThePeekedBarHasTheMoveButton`'s.
@MainActor
final class PaletteMoveButtonTests: XCTestCase {
    // MARK: Stand-ins (PaletteGripTests' shape, with a place)

    /// A touch with a type and a place in the window.
    private final class StandInTouch: UITouch {
        let kind: UITouch.TouchType
        var point: CGPoint

        init(_ kind: UITouch.TouchType, at point: CGPoint) {
            self.kind = kind
            self.point = point
            super.init()
        }

        override var type: UITouch.TouchType { kind }
        override func location(in view: UIView?) -> CGPoint { point }
        override func preciseLocation(in view: UIView?) -> CGPoint { point }
    }

    /// What the button reported, in order.
    private final class Log {
        var events: [String] = []
        var shown = false
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    private let four: [PaletteEdge] = [.bottom, .top, .left, .right]

    /// A button whose callbacks write to `log`, configured as the screen configures it.
    private func makeButton(_ log: Log, mayBegin: @escaping () -> Bool = { true }, allowed: [PaletteEdge]? = nil,
                            current: PaletteEdge = .bottom) -> PaletteMoveButtonView.ButtonView {
        let button = PaletteMoveButtonView.ButtonView(frame: CGRect(x: 0, y: 0, width: 48, height: 44))
        button.configure(representable(log, mayBegin: mayBegin, allowed: allowed ?? four, current: current))
        return button
    }

    private func representable(_ log: Log, mayBegin: @escaping () -> Bool = { true }, allowed: [PaletteEdge],
                               current: PaletteEdge, cancelTrigger: Int = 0, drags: Bool = true) -> PaletteMoveButtonView {
        PaletteMoveButtonView(
            mayBegin: mayBegin,
            onBegan: { log.events.append("began \(Int($0.x)),\(Int($0.y))") },
            onChanged: { point, velocity in log.events.append("changed \(Int(point.x)),\(Int(point.y)) v\(Int(velocity.dx))") },
            onEnded: { point, velocity in log.events.append("ended \(Int(point.x)),\(Int(point.y)) v\(Int(velocity.dx))") },
            onCancelled: { log.events.append("cancelled") },
            cancelTrigger: cancelTrigger,
            allowed: allowed,
            current: current,
            onMove: { log.events.append("move \($0.rawValue)") },
            menuShown: Binding(get: { log.shown }, set: { log.shown = $0 }),
            drags: drags
        )
    }

    /// One touch on the button: down at `from`, through `path`, up at the last point (or `from`).
    private func touch(_ button: PaletteMoveButtonView.ButtonView, _ type: UITouch.TouchType, from: CGPoint,
                       path: [CGPoint] = [], cancel: Bool = false) {
        let finger = StandInTouch(type, at: from)
        button.touchesBegan([finger], with: nil)
        for point in path {
            finger.point = point
            button.touchesMoved([finger], with: nil)
        }
        if cancel {
            button.touchesCancelled([finger], with: nil)
        } else {
            button.touchesEnded([finger], with: nil)
        }
    }

    // MARK: Where it shows (§17.2, MB1)

    /// On the open bar and the dock the button shows exactly where the grip does: the open bar of a window that allows two
    /// edges or more. Not on an iPhone (the bottom alone, whatever its window), an iPad window with the bottom alone or the
    /// dock. (The peek, §18.2, is `testTheButtonShowsOnThePeekToo`'s.)
    func testTheButtonShowsWhereTheGripShows() {
        let sets: [[PaletteEdge]] = [[], [.bottom], [.bottom, .top], four]
        for mode in [ToolbarMode.expanded, .collapsed] {
            for allowed in sets {
                XCTAssertEqual(ToolbarLogic.showsMoveButton(mode, allowed: allowed), ToolbarLogic.showsGrip(mode, allowed: allowed),
                               "\(mode) \(allowed)")
            }
        }
        XCTAssertTrue(ToolbarLogic.showsMoveButton(.expanded, allowed: four))
        XCTAssertTrue(ToolbarLogic.showsMoveButton(.expanded, allowed: [.bottom, .top]))
        XCTAssertFalse(ToolbarLogic.showsMoveButton(.expanded, allowed: [.bottom]), "one edge: no button")
        XCTAssertFalse(ToolbarLogic.showsMoveButton(.collapsed, allowed: four), "the dock: no button")
        // Every iPhone (the Pro Max on its side, the Duo's inner screen) allows the bottom alone: no button there.
        for size in [CGSize(width: 402, height: 874), CGSize(width: 956, height: 440), CGSize(width: 669, height: 951)] {
            let allowed = ToolbarLogic.allowedEdges(isPad: false, windowSize: size, column: size.width, paperColumnHeight: size.height)
            XCTAssertFalse(ToolbarLogic.showsMoveButton(.expanded, allowed: allowed), "iPhone \(size)")
        }
        // A narrow iPad window (Slide Over) has none; the 13-inch, the 11-inch and the mini upright have it.
        let slideOver = ToolbarLogic.allowedEdges(isPad: true, windowSize: CGSize(width: 375, height: 1100), column: 375,
                                                  paperColumnHeight: 900)
        XCTAssertFalse(ToolbarLogic.showsMoveButton(.expanded, allowed: slideOver))
        for size in [CGSize(width: 1032, height: 1376), CGSize(width: 834, height: 1210), CGSize(width: 744, height: 1133)] {
            let allowed = ToolbarLogic.allowedEdges(isPad: true, windowSize: size, column: size.width, paperColumnHeight: size.height - 300)
            XCTAssertTrue(ToolbarLogic.showsMoveButton(.expanded, allowed: allowed), "iPad \(size)")
        }
    }

    /// §18.2 (MB5): the peeking bar has the button too — a bar folded at the 確かめ表's row 12 and peeked from the round
    /// button had no grip and no 「動かす」 — wherever two edges or more are allowed; the dock never, an iPhone and a window
    /// with the bottom alone never. The grip stays the open bar's, and so does the button's drag (`moveButtonDrags`).
    func testTheButtonShowsOnThePeekToo() {
        XCTAssertTrue(ToolbarLogic.showsMoveButton(.peek, allowed: four), "a peek on four edges: the button")
        XCTAssertTrue(ToolbarLogic.showsMoveButton(.peek, allowed: [.bottom, .top]), "a peek on two edges: the button")
        XCTAssertFalse(ToolbarLogic.showsMoveButton(.peek, allowed: [.bottom]), "a peek in a window with the bottom alone: none")
        XCTAssertFalse(ToolbarLogic.showsMoveButton(.peek, allowed: []))
        for allowed in [[], [.bottom], [.bottom, .top], four] as [[PaletteEdge]] {
            XCTAssertFalse(ToolbarLogic.showsMoveButton(.collapsed, allowed: allowed), "the dock: no button (\(allowed))")
            XCTAssertFalse(ToolbarLogic.showsGrip(.peek, allowed: allowed), "a peek: still no grip (\(allowed))")
            XCTAssertFalse(ToolbarLogic.moveButtonDrags(.peek, allowed: allowed), "a peek: a tap only (\(allowed))")
            XCTAssertFalse(ToolbarLogic.moveButtonDrags(.collapsed, allowed: allowed))
            XCTAssertEqual(ToolbarLogic.moveButtonDrags(.expanded, allowed: allowed), ToolbarLogic.showsGrip(.expanded, allowed: allowed),
                           "the open bar's button drags where the grip does (\(allowed))")
        }
        XCTAssertTrue(ToolbarLogic.moveButtonDrags(.expanded, allowed: four))
        // Every iPhone allows the bottom alone: its peek keeps 1.4's bar.
        for size in [CGSize(width: 402, height: 874), CGSize(width: 956, height: 440), CGSize(width: 669, height: 951)] {
            let allowed = ToolbarLogic.allowedEdges(isPad: false, windowSize: size, column: size.width, paperColumnHeight: size.height)
            XCTAssertFalse(ToolbarLogic.showsMoveButton(.peek, allowed: allowed), "iPhone \(size): no button on its peek")
        }
        let ipad13 = ToolbarLogic.allowedEdges(isPad: true, windowSize: CGSize(width: 1032, height: 1376), column: 1032,
                                               paperColumnHeight: 1076)
        XCTAssertTrue(ToolbarLogic.showsMoveButton(.peek, allowed: ipad13), "the 13-inch iPad's peek has the button")
    }

    /// §18.2: on a peek (`drags` false) the button is a tap only. The pan's gate says no even where the palm rule says yes, so
    /// no drag begins (no callback, the pan not dragging) however far the finger goes; a finger that moved 10 pt and lifted is
    /// nothing (no drag, no tap); a still touch of a finger, a pointer or the Apple Pencil opens the choice. Back on the open
    /// bar (`drags` true) the gate is the palm rule again.
    func testThePeeksButtonIsATapOnly() throws {
        let log = Log()
        let button = PaletteMoveButtonView.ButtonView(frame: CGRect(x: 0, y: 0, width: 48, height: 44))
        button.configure(representable(log, mayBegin: { true }, allowed: four, current: .bottom, drags: false))
        let gate = try XCTUnwrap(button.pan.delegate)
        XCTAssertEqual(gate.gestureRecognizerShouldBegin?(button.pan), false, "a peek: the pan never begins")

        // A finger dragged 12 pt, then 400 pt (as UIKit would report it, had the pan begun): no drag, and no tap at the lift.
        let finger = StandInTouch(.direct, at: CGPoint(x: 900, y: 1300))
        button.touchesBegan([finger], with: nil)
        finger.point = CGPoint(x: 900, y: 1288)
        button.touchesMoved([finger], with: nil)
        button.handle(.began, location: finger.point, translation: CGPoint(x: 0, y: -12), velocity: .zero)
        XCTAssertFalse(button.dragging, "no drag at 10 pt")
        finger.point = CGPoint(x: 900, y: 900)
        button.touchesMoved([finger], with: nil)
        button.handle(.changed, location: finger.point, translation: CGPoint(x: 0, y: -400), velocity: CGVector(dx: 0, dy: -300))
        button.handle(.ended, location: finger.point, translation: CGPoint(x: 0, y: -400), velocity: CGVector(dx: 0, dy: -300))
        button.touchesEnded([finger], with: nil)
        XCTAssertFalse(button.dragging)
        XCTAssertEqual(log.events, [], "no drag callback on a peek")
        XCTAssertFalse(log.shown, "moved 10 pt: no tap either")

        // A tap opens the choice with any touch.
        for type in [UITouch.TouchType.direct, .indirectPointer, .pencil] {
            log.shown = false
            touch(button, type, from: CGPoint(x: 900, y: 1300), path: [CGPoint(x: 902, y: 1303)])
            XCTAssertTrue(log.shown, "\(type.rawValue): a tap on the peek's button opens the choice")
        }
        XCTAssertEqual(log.events, [])

        // The bar opened: the same view, configured for the open bar, drags with the palm rule again.
        button.configure(representable(log, mayBegin: { true }, allowed: four, current: .right))
        XCTAssertEqual(gate.gestureRecognizerShouldBegin?(button.pan), true, "the open bar: the palm rule")
        button.configure(representable(log, mayBegin: { false }, allowed: four, current: .right))
        XCTAssertEqual(gate.gestureRecognizerShouldBegin?(button.pan), false, "the open bar: the palm rule says no")
        XCTAssertTrue(PaletteMoveButtonView(mayBegin: { true }, onBegan: { _ in }, onChanged: { _, _ in }, onEnded: { _, _ in },
                                            onCancelled: {}, cancelTrigger: 0, allowed: four, current: .bottom, onMove: { _ in },
                                            menuShown: .constant(false)).drags, "drags by default (§17.2's button)")
    }

    /// §18.2 (MB6): a choice on the peek keeps the edge as a drop on the open bar does (§4.7) — the table's
    /// `(.peek, .placementChosen)` stores and opens the bar to stay —, in screenshot mode in the screen's `@State` only (the
    /// answer), in normal use in `toolbar.paletteEdge` and, on a side, the round button's corner. The dock keeps nothing.
    func testAChoiceOnThePeekKeepsTheEdge() throws {
        let suite = "test-palette-peek-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
        }
        let step = ToolbarLogic.step(.peek, on: .placementChosen)
        XCTAssertTrue(step.storesPlacement)
        XCTAssertEqual(step.mode, .expanded, "the peek opens on the edge chosen")
        XCTAssertEqual(step.storeCollapsed, false, "and stays open (toolbar.collapsed false)")

        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .right, mode: .peek, stored: .bottom, screenshot: true),
                       CalendarRootScreen.PaletteDrop(edge: .right, dock: .trailing), "screenshot mode: the screen's state")
        XCTAssertNil(scratch.object(forKey: AppSettings.paletteEdgeKey), "screenshot mode writes no toolbar.paletteEdge")
        XCTAssertNil(scratch.object(forKey: AppSettings.toolbarEdgeKey), "nor toolbar.collapsedEdge")

        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .right, mode: .peek, stored: .bottom, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: .right, dock: .trailing))
        XCTAssertEqual(scratch.string(forKey: "toolbar.paletteEdge"), "right")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "trailing", "「しまう」 leaves the dock bottom right")
        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .top, mode: .peek, stored: .right, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: .top, dock: nil))
        XCTAssertEqual(scratch.string(forKey: "toolbar.paletteEdge"), "top")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "trailing", "the top leaves the corner")
        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .left, mode: .peek, stored: .top, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: .left, dock: .leading))
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "leading")

        scratch.removeObject(forKey: AppSettings.paletteEdgeKey)
        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .right, mode: .collapsed, stored: .bottom, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: nil, dock: nil), "the dock keeps nothing")
        XCTAssertNil(scratch.object(forKey: AppSettings.paletteEdgeKey))
    }

    // MARK: Tap or drag (§17.2)

    /// `Press`: a touch that lifts before 10 pt is a tap; once it moved 10 pt it is not, even back where it came down; once a
    /// drag began it is not; a Pencil's touch is a tap when it lifts, however far it moved; a cancelled touch is nothing.
    func testTapOrDrag() {
        let start = CGPoint(x: 500, y: 1000)
        func lift(_ type: UITouch.TouchType, path: [CGPoint], end: CGPoint, drag: Bool = false) -> Bool {
            var press = PaletteMoveButtonView.Press()
            press.began(at: start, type: type)
            XCTAssertTrue(press.isTracking)
            for point in path { press.moved(to: point) }
            if drag { press.dragBegan() }
            let tap = press.ended(at: end)
            XCTAssertFalse(press.isTracking, "the press is over")
            return tap
        }
        for type in [UITouch.TouchType.direct, .indirectPointer] {
            XCTAssertTrue(lift(type, path: [], end: start), "\(type.rawValue): a still touch")
            XCTAssertTrue(lift(type, path: [CGPoint(x: 506, y: 1007)], end: CGPoint(x: 509.9, y: 1000)), "\(type.rawValue): 9.9 pt")
            XCTAssertFalse(lift(type, path: [], end: CGPoint(x: 506, y: 1008)), "\(type.rawValue): lifted 10 pt away")
            XCTAssertFalse(lift(type, path: [CGPoint(x: 500, y: 1010)], end: start), "\(type.rawValue): 10 pt and back")
            XCTAssertFalse(lift(type, path: [CGPoint(x: 503, y: 1000)], end: CGPoint(x: 503, y: 1000), drag: true),
                           "\(type.rawValue): a drag began")
        }
        XCTAssertTrue(lift(.pencil, path: [CGPoint(x: 560, y: 1000)], end: CGPoint(x: 700, y: 900)), "the Pencil: a tap when it lifts")
        XCTAssertTrue(lift(.pencil, path: [], end: start))

        var press = PaletteMoveButtonView.Press()
        XCTAssertFalse(press.ended(at: start), "no touch: no tap")
        press.dragBegan()
        XCTAssertEqual(press, PaletteMoveButtonView.Press(), "no touch: nothing noted")
        press.began(at: start, type: .direct)
        press.cancelled()
        XCTAssertFalse(press.isTracking)
        XCTAssertFalse(press.ended(at: start), "a cancelled touch is nothing")
        XCTAssertEqual(PaletteGripView.startDistance, 10)
    }

    /// A tap opens the choice of edges with a finger, a trackpad or a mouse and the Apple Pencil, also while the palm rule says
    /// no (the pan's gate is no, the choice still opens: choosing moves nothing under the pen). A touch that moved 10 pt and a
    /// cancelled touch open nothing. No drag callback is reported for a tap.
    func testATapOpensTheChoiceWithAnyTouchAndWithoutThePalmRule() throws {
        let log = Log()
        let button = makeButton(log, mayBegin: { false })
        let gate = try XCTUnwrap(button.pan.delegate)
        XCTAssertEqual(gate.gestureRecognizerShouldBegin?(button.pan), false, "the palm rule says no")
        let start = CGPoint(x: 900, y: 1300)
        for type in [UITouch.TouchType.direct, .indirectPointer, .pencil] {
            log.shown = false
            touch(button, type, from: start, path: [CGPoint(x: 903, y: 1302)])
            XCTAssertTrue(log.shown, "\(type.rawValue): a tap opens the choice")
        }
        log.shown = false
        touch(button, .direct, from: start, path: [CGPoint(x: 900, y: 1288)])
        XCTAssertFalse(log.shown, "12 pt: no tap")
        touch(button, .direct, from: start, path: [], cancel: true)
        XCTAssertFalse(log.shown, "cancelled: no tap")
        touch(button, .pencil, from: start, path: [CGPoint(x: 960, y: 1300)])
        XCTAssertTrue(log.shown, "the Pencil never drags: a tap")
        XCTAssertEqual(log.events, [], "a tap reports no drag")
    }

    /// The drag is the grip's: the shared pan takes a finger, a trackpad and a mouse, never the Pencil (MB3), one touch, asks
    /// the palm rule to begin and again at 10 pt, and reports the grip's callbacks; the touch it dragged is no tap. The pan
    /// leaves the view its touches (no `require(toFail:)`, `cancelsTouchesInView` off), so a pointer the pan began on before
    /// 10 pt and that lifted there is still a tap.
    func testTheDragIsTheGripsAndNeverATap() async throws {
        let types = Set(PaletteMoveButtonView.ButtonView(frame: .zero).pan.allowedTouchTypes.map(\.intValue))
        XCTAssertEqual(types, [UITouch.TouchType.direct.rawValue, UITouch.TouchType.indirectPointer.rawValue], "never the Pencil")
        var palm = true
        var asked = 0
        let log = Log()
        let button = makeButton(log, mayBegin: {
            asked += 1
            return palm
        })
        XCTAssertEqual(button.pan.maximumNumberOfTouches, 1)
        XCTAssertFalse(button.pan.cancelsTouchesInView, "the view keeps its touches for the tap")
        XCTAssertTrue(button.gestureRecognizers?.contains { $0 === button.pan } ?? false, "the pan is on the button")
        XCTAssertEqual(button.pan.delegate?.gestureRecognizerShouldBegin?(button.pan), true)
        XCTAssertEqual(asked, 1)
        let shared = ObjectIdentifier(PaletteGripView.PanView.self)
        XCTAssertEqual(PaletteMoveButtonView.ButtonView.superclass().map(ObjectIdentifier.init), shared, "the grip's pan, not a copy")
        XCTAssertEqual(PaletteGripView.GripView.superclass().map(ObjectIdentifier.init), shared)

        // A finger: down, 6 pt (nothing), 10 pt (the drag starts), on, up. No tap.
        let finger = StandInTouch(.direct, at: CGPoint(x: 900, y: 1300))
        button.touchesBegan([finger], with: nil)
        finger.point = CGPoint(x: 906, y: 1300)
        button.touchesMoved([finger], with: nil)
        button.handle(.began, location: finger.point, translation: CGPoint(x: 6, y: 0), velocity: .zero)
        XCTAssertFalse(button.dragging)
        finger.point = CGPoint(x: 906, y: 1292)
        button.touchesMoved([finger], with: nil)
        button.handle(.changed, location: finger.point, translation: CGPoint(x: 6, y: -8), velocity: CGVector(dx: 30, dy: 0))
        XCTAssertTrue(button.dragging)
        XCTAssertTrue(button.press.dragged, "the drag is noted on the touch")
        finger.point = CGPoint(x: 40, y: 700)
        button.touchesMoved([finger], with: nil)
        button.handle(.changed, location: finger.point, translation: CGPoint(x: -860, y: -600), velocity: CGVector(dx: -50, dy: 0))
        button.handle(.ended, location: finger.point, translation: CGPoint(x: -860, y: -600), velocity: CGVector(dx: -700, dy: 0))
        button.touchesEnded([finger], with: nil)
        XCTAssertEqual(log.events, ["began 906,1292", "changed 906,1292 v30", "changed 40,700 v-50", "ended 40,700 v-700"])
        XCTAssertFalse(log.shown, "a drag is no tap")
        XCTAssertFalse(button.dragging)

        // A mouse: UIKit's pan began at 4 pt and the button lifted at 5 pt: no drag, a tap.
        log.events = []
        let mouse = StandInTouch(.indirectPointer, at: CGPoint(x: 900, y: 1300))
        button.touchesBegan([mouse], with: nil)
        mouse.point = CGPoint(x: 904, y: 1300)
        button.touchesMoved([mouse], with: nil)
        button.handle(.began, location: mouse.point, translation: CGPoint(x: 4, y: 0), velocity: .zero)
        mouse.point = CGPoint(x: 905, y: 1300)
        button.handle(.ended, location: mouse.point, translation: CGPoint(x: 5, y: 0), velocity: .zero)
        button.touchesEnded([mouse], with: nil)
        XCTAssertEqual(log.events, [])
        XCTAssertTrue(log.shown, "lifted before 10 pt: a tap")

        // The palm rule says no at 10 pt: no drag (the pan's touch forgotten), and the touch that moved is no tap either.
        log.shown = false
        palm = false
        asked = 0
        let palmFinger = StandInTouch(.direct, at: CGPoint(x: 900, y: 1300))
        button.touchesBegan([palmFinger], with: nil)
        palmFinger.point = CGPoint(x: 900, y: 1288)
        button.touchesMoved([palmFinger], with: nil)
        button.handle(.changed, location: palmFinger.point, translation: CGPoint(x: 0, y: -12), velocity: .zero)
        XCTAssertEqual(asked, 1, "asked again at 10 pt")
        XCTAssertFalse(button.dragging)
        XCTAssertTrue(button.pan.isEnabled, "turned off and on: the touch is forgotten")
        button.touchesEnded([palmFinger], with: nil)
        await settle()
        XCTAssertEqual(log.events, [], "no drag, nothing to cancel")
        XCTAssertFalse(log.shown, "it moved 12 pt: no tap")
    }

    /// The screen's cancel trigger ends the button's running drag as it ends the grip's (reported on the next turn); the touch
    /// is no tap when it lifts. A new trigger without a drag reports nothing, and the view's removal forgets its touch.
    func testTheCancelTriggerEndsTheButtonsDrag() async {
        let log = Log()
        let button = makeButton(log)
        button.lastCancelTrigger = 2
        let finger = StandInTouch(.direct, at: CGPoint(x: 10, y: 10))
        button.touchesBegan([finger], with: nil)
        finger.point = CGPoint(x: 10, y: -10)
        button.touchesMoved([finger], with: nil)
        button.handle(.began, location: finger.point, translation: CGPoint(x: 0, y: -20), velocity: .zero)
        XCTAssertTrue(button.dragging)
        log.events = []
        button.configure(representable(log, allowed: four, current: .bottom, cancelTrigger: 3))
        button.apply(cancelTrigger: 3)
        XCTAssertFalse(button.dragging, "ended at once")
        XCTAssertTrue(button.pan.isEnabled)
        await settle()
        XCTAssertEqual(log.events, ["cancelled"])
        finger.point = CGPoint(x: 10, y: 9)
        button.touchesEnded([finger], with: nil)
        XCTAssertFalse(log.shown, "the cancelled drag's touch is no tap")
        button.apply(cancelTrigger: 4)
        await settle()
        XCTAssertEqual(log.events, ["cancelled"], "no drag: nothing to report")

        let other = StandInTouch(.direct, at: .zero)
        button.touchesBegan([other], with: nil)
        XCTAssertTrue(button.press.isTracking)
        PaletteMoveButtonView.dismantleUIView(button, coordinator: ())
        XCTAssertFalse(button.press.isTracking, "gone: no tap")
        button.touchesEnded([other], with: nil)
        XCTAssertFalse(log.shown)
    }

    // MARK: The choice of edges (§17.2, MB4)

    /// The dialog's buttons and VoiceOver's actions are the grip's actions: every allowed edge but the current one, in
    /// `allowedEdges`' order (never the current edge). A choice moves the bar only to an edge that is one of them now: an
    /// edge the window no longer allows, or the current one, does nothing.
    func testTheChoicesAreTheGripsActions() {
        let sets: [[PaletteEdge]] = [[.bottom], [.bottom, .top], four]
        for allowed in sets {
            for current in PaletteEdge.allCases {
                let choices = PaletteMoveButtonView.choices(allowed: allowed, current: current)
                XCTAssertEqual(choices, ToolbarLogic.moveTargets(allowed: allowed, current: current), "\(allowed) \(current)")
                XCTAssertFalse(choices.contains(current), "never the current edge (\(allowed) \(current))")
                for edge in PaletteEdge.allCases {
                    let expected: PaletteEdge? = allowed.contains(edge) && edge != current ? edge : nil
                    XCTAssertEqual(PaletteMoveButtonView.choice(edge, allowed: allowed, current: current), expected,
                                   "\(edge) of \(allowed) on \(current)")
                }
            }
        }
        XCTAssertEqual(PaletteMoveButtonView.choices(allowed: four, current: .bottom), [.top, .left, .right])
        XCTAssertEqual(PaletteMoveButtonView.choices(allowed: four, current: .right), [.bottom, .top, .left])
        XCTAssertEqual(PaletteMoveButtonView.choices(allowed: [.bottom, .top], current: .bottom), [.top])
        // The dialog showed 「右へ移す」, then the window narrowed to the bottom and the top: the choice does nothing.
        XCTAssertNil(PaletteMoveButtonView.choice(.right, allowed: [.bottom, .top], current: .bottom))
        XCTAssertNil(PaletteMoveButtonView.choice(.right, allowed: [.bottom], current: .bottom))
        XCTAssertEqual(PaletteMoveButtonView.choice(.right, allowed: four, current: .bottom), .right)

        let log = Log()
        let shown = representable(log, allowed: four, current: .left)
        XCTAssertEqual(shown.choices, [.bottom, .top, .right])
        XCTAssertEqual(shown.choices.map(ToolbarLogic.moveToTitle), ["下へ移す", "上へ移す", "右へ移す"])
    }

    /// The screen's wires, read from the source in code only (`WeekMemoSpanTests.codeOnly`, ZoomFitWiringTests' way; the
    /// comments name the same calls): the button's choices — its dialog's and VoiceOver's — reach `paletteMoveChosen` only
    /// through `paletteMoveButtonChose`, whose guard is `choice` with the live `paletteAllowed` and `paletteEdge`, so on the
    /// screen too a choice the window no longer allows (the dialog opened on four edges, the window narrowed to the bottom and
    /// the top, then 「右へ移す」) writes nothing. The dialog's buttons are the only caller of `move.onMove` and then tell
    /// VoiceOver the screen changed, as the 「…へ移す」 actions do (§4.11).
    func testTheScreenSendsEveryChoiceThroughTheGuard() throws {
        func code(_ path: String) throws -> String {
            let url = Self.repository.appendingPathComponent(path)
            return String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        func count(_ text: String, in code: String) -> Int {
            code.components(separatedBy: text).count - 1
        }

        let screen = try code("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        XCTAssertEqual(count("PaletteMoveButtonView(", in: screen), 1, "the screen makes one button")
        XCTAssertEqual(count("current: paletteEdge, onMove: { paletteMoveButtonChose($0) }, menuShown: $paletteMenuShown, "
                             + "drags: ToolbarLogic.moveButtonDrags(toolbarMode, allowed: paletteAllowed) )", in: screen), 1,
                       "the button's choices go to paletteMoveButtonChose; it drags only where the table says (§18.2)")
        XCTAssertEqual(count("private func paletteMoveButtonChose(_ edge: PaletteEdge) { "
                             + "if paletteMenuShown { paletteMenuShown = false } guard paletteHasMoveButton, "
                             + "let edge = PaletteMoveButtonView.choice(edge, allowed: paletteAllowed, current: paletteEdge) "
                             + "else { return } paletteMoveChosen(edge) }", in: screen), 1,
                       "the choice of edges closed, the guard: the live allowed edges and the live edge, then VoiceOver's path")
        XCTAssertEqual(count("paletteMoveButtonChose(", in: screen), 2, "declared once, called once (the button's onMove)")
        XCTAssertEqual(count("PaletteMoveButtonView.choice(", in: screen), 1)

        let toolbar = try code("Sources/TegakiCalendar/Views/ToolbarView.swift")
        XCTAssertEqual(count("Button(ToolbarLogic.moveToTitle(edge)) { move.onMove(edge) PaletteGripView.PanView.postLayoutChanged() }",
                             in: toolbar), 1, "a choice of the dialog, then .layoutChanged")
        XCTAssertEqual(count("move.onMove(", in: toolbar), 1, "the dialog's buttons are the only caller")

        let grip = try code("Sources/TegakiCalendar/Views/PaletteGrip.swift")
        XCTAssertEqual(count("func moved(to target: PaletteEdge) -> Bool { onMove(target) Self.postLayoutChanged() return true }",
                             in: grip), 1, "VoiceOver's actions post the same")
        XCTAssertEqual(count("static func postLayoutChanged() { Task { @MainActor in "
                             + "UIAccessibility.post(notification: .layoutChanged, argument: nil) } }", in: grip), 1,
                       "on the main actor's next turn, after SwiftUI laid the moved bar out")
    }

    /// §18.2 (MB6), the screen's wires in code only (as above): every choice (`paletteMoveChosen`: the button's dialog, its
    /// and the grip's VoiceOver actions) goes through `placePalette` inside one transaction without animation, and
    /// `placePalette` keeps the edge (`paletteDropped` with the live mode) and then applies the table's `.placementChosen`
    /// step (`toolbarEvent`: the step's mode, `toolbar.collapsed` outside screenshot mode) — so a choice on a peek opens the
    /// bar on its edge with the paper laid out once, and the open bar's drop stays as it was (the step changes nothing there).
    /// The choice of edges closes when the button goes (`paletteHasMoveButton`, which a peek folding changes; the grip does
    /// not change during a peek). The screen asks the table itself whether its one bar has the button (§18.1, §18.2: the
    /// open bar and the peek, `showsMoveButton`), so the grip's question coming back there (MB5 on the screen's side, which
    /// the table's own tests cannot see) fails here and not only in the blank-paper UI test.
    func testTheChoiceAppliesTheTablesStepInOneTransaction() throws {
        let url = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        let screen = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        func count(_ text: String) -> Int {
            screen.components(separatedBy: text).count - 1
        }

        XCTAssertEqual(count("private func paletteMoveChosen(_ edge: PaletteEdge) { var transaction = Transaction() "
                             + "transaction.disablesAnimations = true withTransaction(transaction) { placePalette(on: edge) } }"), 1,
                       "a choice: placePalette in one transaction without animation")
        XCTAssertEqual(count("private func placePalette(on edge: PaletteEdge) { let drop = Self.paletteDropped(on: edge, "
                             + "mode: toolbarMode, stored: paletteStored, screenshot: ScreenshotMode.isActive) "
                             + "if ScreenshotMode.isActive { if let kept = drop.edge, kept != screenshotPaletteEdge { "
                             + "screenshotPaletteEdge = kept } if let dock = drop.dock, dock != screenshotEdge { screenshotEdge = dock } } "
                             + "toolbarEvent(.placementChosen) }"), 1,
                       "the edge kept with the mode the choice was made in, then the table's step")
        XCTAssertEqual(count("toolbarEvent(.placementChosen)"), 1, "placePalette alone applies the step")
        XCTAssertEqual(count("placePalette(on: edge)"), 2, "the drop and the choice")
        XCTAssertEqual(count("withTransaction(transaction) { endPaletteDrag() placePalette(on: edge) }"), 1,
                       "the drop's transaction, as before")
        XCTAssertEqual(count("private func toolbarEvent(_ event: ToolbarEvent) { let step = ToolbarLogic.step(toolbarMode, on: event)"), 1,
                       "the table's step")
        XCTAssertEqual(count("if let stored = step.storeCollapsed, !ScreenshotMode.isActive { toolbarCollapsedStored = stored } "
                             + "if step.mode != toolbarMode { toolbarMode = step.mode } }"), 1,
                       "toolbar.collapsed outside screenshot mode, then the mode (screenshot mode: the @State only)")
        XCTAssertEqual(count(".onChange(of: paletteHasMoveButton) { if !paletteHasMoveButton, paletteMenuShown { paletteMenuShown = false } }"),
                       1, "the choice of edges goes with the button")
        XCTAssertEqual(count("{ paletteMenuShown = false }"), 2, "closed by the button's going and by a choice")
        XCTAssertEqual(count(".onChange(of: paletteHasGrip) { if !paletteHasGrip { endPaletteDrag() } }"), 1,
                       "the grip's going ends a drag only; the choice of edges goes with the button (above)")

        XCTAssertEqual(count("private var paletteHasMoveButton: Bool { ToolbarLogic.showsMoveButton(toolbarMode, allowed: paletteAllowed) }"),
                       1, "the screen asks the table: the button on the open bar and on the peek (§18.2), not where the grip shows")
        XCTAssertEqual(count("private var paletteMoveButton: PaletteMoveButtonView? { guard paletteHasMoveButton else { return nil }"),
                       1, "the button is made where it shows")
        XCTAssertEqual(count("axis: axis, move: paletteMoveButton )"), 1, "the one bar, open or peeking, gets it")
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // MARK: VoiceOver (§17.2)

    /// One element: 「ツールバーを動かす」, the hint 「上下左右の端へ移せます」, a button, `toolbar.move`, an action per choice that
    /// calls `onMove` (the screen's path), and activation opens the choice of edges.
    func testTheButtonIsOneVoiceOverElement() throws {
        let log = Log()
        let button = makeButton(log, allowed: four, current: .bottom)
        XCTAssertTrue(button.isAccessibilityElement)
        XCTAssertEqual(button.accessibilityLabel, "ツールバーを動かす")
        XCTAssertEqual(button.accessibilityLabel, ToolbarLogic.gripAccessibilityLabel)
        XCTAssertEqual(button.accessibilityHint, "上下左右の端へ移せます")
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertEqual(button.accessibilityIdentifier, "toolbar.move")
        XCTAssertEqual(PaletteMoveButtonView.identifier, "toolbar.move")
        let actions = try XCTUnwrap(button.accessibilityCustomActions)
        XCTAssertEqual(actions.map(\.name), ["上へ移す", "左へ移す", "右へ移す"])
        XCTAssertEqual(actions[1].actionHandler?(actions[1]), true)
        XCTAssertEqual(log.events, ["move left"])
        XCTAssertFalse(log.shown)
        XCTAssertTrue(button.accessibilityActivate())
        XCTAssertTrue(log.shown, "VoiceOver's double tap opens the choice")

        // On the left edge the actions follow.
        button.configure(representable(log, allowed: four, current: .left))
        XCTAssertEqual(button.accessibilityCustomActions?.map(\.name), ["下へ移す", "上へ移す", "右へ移す"])
        // Without a choice (a window back to one edge, before the button goes) no action.
        button.configure(representable(log, allowed: [.bottom], current: .bottom))
        XCTAssertEqual(button.accessibilityCustomActions?.count ?? 0, 0)
    }

    // MARK: Screenshot mode (§17.4)

    /// `--screenshot-palette-menu`, a flag without a value, asks the screen to open the choice of edges for its photo; without
    /// it the Config is the one the same arguments gave before (the edges' arguments and 1.1's `--screenshot-toolbar` included).
    func testScreenshotModeOpensTheChoiceForItsPhoto() throws {
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week", "--screenshot-palette", "bottom"]
        var plain = try XCTUnwrap(ScreenshotMode.parse(base))
        XCTAssertFalse(plain.paletteMenu, "off without the argument")
        let menu = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-palette-menu"]))
        XCTAssertTrue(menu.paletteMenu)
        XCTAssertEqual(menu.palette, .bottom)
        XCTAssertNil(menu.paletteDrag)
        XCTAssertTrue(try XCTUnwrap(ScreenshotMode.parse(["--screenshot-palette-menu"] + base)).paletteMenu, "anywhere")
        plain.paletteMenu = true
        XCTAssertEqual(menu, plain, "nothing else changes")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-palette-menu"]), "never active without --screenshot-mode")
        let other = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-palette-drag", "left", "--screenshot-toolbar", "collapsed"]))
        XCTAssertFalse(other.paletteMenu, "--screenshot-palette-drag is not the menu")
        XCTAssertEqual(other.toolbar, .collapsed)
    }

    // MARK: The face and the bar (§17.2, §17.3)

    /// The name fits the 48 pt face in every language (F-12: Japanese by its width, the others in 38 pt shrinking to 0.8, at
    /// most 47.5 pt at 10 pt), so the button is 48 wide in each and the row gives up exactly 48 pt. The mark is an SF Symbol.
    func testTheNameFitsTheFaceInEveryLanguage() {
        typealias Row = ToolbarLogic.Row
        XCTAssertEqual(L.text("toolbar.move.title", in: .ja), "動かす")
        XCTAssertEqual(L.text("toolbar.move.title", in: .en), "Move")
        XCTAssertEqual(ToolbarLogic.moveTitle, "動かす")
        for language in UILanguage.allCases {
            let text = L.text("toolbar.move.title", in: language)
            XCTAssertNotEqual(text, "toolbar.move.title", "\(language.rawValue): translated")
            let measured = (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)]).width
            print("palette move: \(language.rawValue) \"\(text)\" is \(String(format: "%.1f", Double(measured))) pt at 10 pt")
            XCTAssertLessThanOrEqual(measured, 47.5, "\(language.rawValue) \"\(text)\" does not fit 38 pt at 0.8")
            let label = Row.labelFrameWidth(for: language) ?? measured
            XCTAssertEqual(max(Row.buttonMinWidth, label + 2 * Row.labelInset), 48, "\(language.rawValue): the face is 48 wide")
        }
        XCTAssertNotNil(UIImage(systemName: PaletteMoveButtonView.symbol), PaletteMoveButtonView.symbol)
        XCTAssertEqual(PaletteMoveButtonView.symbol, "arrow.up.and.down.and.arrow.left.and.right")
    }

    /// `ToolbarView(move:)` as the screen lays it out, in a window of the test host's scene: across, the bar is still 60 pt
    /// tall and 「動かす」 (the button's view, 48 × 44) sits right before 「しまう」 (its right edge 8 + 48 pt from the bar's); upright
    /// it sits over 「しまう」 in the 48 pt column. Without `move` there is no button. The row's scroll view is 48 pt narrower with
    /// the button (printed for the 13-inch, the 11-inch and the mini, as the bar's width there: the window less 12 + 12).
    func testTheBarKeepsItsHeightAndTheButtonSitsBeforeHide() throws {
        let log = Log()
        let move = representable(log, allowed: four, current: .bottom)
        func bar(_ axis: Axis, move: PaletteMoveButtonView?) -> ToolbarView {
            ToolbarView(tool: .constant(.ink(ToolbarPalette.defaultPen)), allowFinger: .constant(false), onUndo: {}, onRedo: {},
                        showsCollapseButton: true, axis: axis, move: move)
        }
        XCTAssertNil(bar(.horizontal, move: nil).move, "nil by default: the bar of before")
        let across = UIHostingController(rootView: bar(.horizontal, move: move)).sizeThatFits(in: CGSize(width: 1008, height: 900))
        XCTAssertEqual(across.height, ToolbarLogic.barHeight, accuracy: 0.5, "the bar's height does not change")
        let upright = UIHostingController(rootView: bar(.vertical, move: move)).sizeThatFits(in: CGSize(width: 700, height: 900))
        XCTAssertEqual(upright.width, ToolbarLogic.verticalBarWidth, accuracy: 0.5)

        for (name, width) in [("13-inch", CGFloat(1032)), ("11-inch", 834), ("mini", 744)] {
            let size = CGSize(width: width - 2 * ToolbarLogic.sidePadding, height: ToolbarLogic.barHeight)
            let with = try layOut(bar(.horizontal, move: move), size: size)
            let button = try XCTUnwrap(with.button, "\(name): the button's view is in the bar")
            XCTAssertEqual(button.width, 48, accuracy: 0.5, name)
            XCTAssertEqual(button.height, 44, accuracy: 0.5, name)
            XCTAssertEqual(button.minY, 8, accuracy: 0.5, name)
            XCTAssertEqual(button.maxX, size.width - ToolbarLogic.Row.collapseTrailing - 48, accuracy: 0.5,
                           "\(name): right before 「しまう」, nothing between")
            let without = try layOut(bar(.horizontal, move: nil), size: size)
            XCTAssertNil(without.button, "\(name): no button without `move`")
            if let rowWith = with.row, let rowWithout = without.row {
                print("palette move: \(name) bar \(size.width) pt: the row \(rowWithout.width) → \(rowWith.width) pt with 「動かす」")
                XCTAssertEqual(rowWithout.width - rowWith.width, 48, accuracy: 0.5, "\(name): the row gives up 48 pt")
                XCTAssertLessThanOrEqual(rowWith.maxX, button.minX, name)
            } else {
                print("palette move: \(name): the row's scroll view was not found (\(String(describing: with.row)))")
            }
        }

        let column = try layOut(bar(.vertical, move: move), size: CGSize(width: ToolbarLogic.verticalBarWidth, height: 900))
        let upright44 = try XCTUnwrap(column.button, "upright: the button's view")
        let expected = CGRect(x: 6, y: 900 - ToolbarLogic.Row.collapseTrailing - 44 - 44, width: 48, height: 44)
        for (got, want, what) in [(upright44.minX, expected.minX, "x"), (upright44.minY, expected.minY, "y"),
                                  (upright44.width, expected.width, "width"), (upright44.height, expected.height, "height")] {
            XCTAssertEqual(got, want, accuracy: 0.5, "upright: over 「しまう」 in the column (\(what), \(upright44))")
        }
        let plainColumn = try layOut(bar(.vertical, move: nil), size: CGSize(width: ToolbarLogic.verticalBarWidth, height: 900))
        XCTAssertNil(plainColumn.button)
        if let rowWith = column.row, let rowWithout = plainColumn.row {
            print("palette move: upright column \(rowWithout.height) → \(rowWith.height) pt with 「動かす」")
            XCTAssertEqual(rowWithout.height - rowWith.height, 44, accuracy: 0.5, "the column gives up 44 pt")
        }
    }

    /// `view` laid out at `size` in a hosting controller in a window of the test host's scene (PaperSpanTests' way): the
    /// frame of the 「動かす」 button's view and of the bar's scroll view, in the view's points.
    private func layOut(_ view: ToolbarView, size: CGSize) throws -> (button: CGRect?, row: CGRect?) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "the unit tests run inside the app: its window scene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading)
            .ignoresSafeArea())
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.view.layoutIfNeeded()
        var button: CGRect?
        var row: CGRect?
        var views: [UIView] = [host.view]
        while let next = views.popLast() {
            views.append(contentsOf: next.subviews)
            if next is PaletteMoveButtonView.ButtonView {
                button = next.convert(next.bounds, to: host.view)
            } else if let scroll = next as? UIScrollView, row == nil {
                row = scroll.convert(scroll.bounds, to: host.view)
            }
        }
        return (button, row)
    }
}
