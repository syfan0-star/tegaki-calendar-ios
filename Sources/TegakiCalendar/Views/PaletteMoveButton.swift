import SwiftUI
import UIKit

/// 1.4.1's second rework (docs/R1_4_1_CONTRACT.md §17.2): the touch side of the open toolbar's 「動かす」 button, on an iPad's
/// window that allows two edges or more (where the grip shows, and since §18.2 on a peek too: `ToolbarLogic.showsMoveButton`).
/// `ToolbarView` draws the button's face (the face of 「しまう」, `arrow.up.and.down.and.arrow.left.and.right` over 「動かす」)
/// just before 「しまう」 and lays this view over it; the screen hands it in (`ToolbarView`'s `move:`, nil on every iPhone and
/// every window with one edge).
///
/// - A tap — a touch that lifts before it moved `PaletteGripView.startDistance` (10 pt), with a finger, a trackpad, a mouse
///   or the Apple Pencil, whatever the palm rule says (choosing moves nothing under the pen) — opens the choice of edges
///   (`menuShown`: `ToolbarView`'s `confirmationDialog`, a popover from the button on an iPad), titled 「ツールバーを動かす」,
///   one button per `choices` (`ToolbarLogic.moveTargets`, 「上へ移す」「下へ移す」「左へ移す」「右へ移す」). A choice calls
///   `onMove`, VoiceOver's path (the screen's `paletteMoveChosen`), and the screen does nothing for an edge that is no longer
///   allowed (`choice`).
/// - A drag — a finger, a trackpad or a mouse that moves 10 pt — is the grip's drag exactly: the same pan, gate, palm rule,
///   start, cancel and callbacks (`PaletteGripView.PanView`, shared, not copied). Once a drag began the touch is no tap; a
///   Pencil never drags (the pan does not take it) and is a tap when it lifts. The decision is `Press`, pure, so the tests
///   check it without UIKit.
/// - Tap and drag share one view without a `require(toFail:)`: the pan does not cancel the view's touches
///   (`cancelsTouchesInView` off), so the view follows each touch itself (`touchesBegan` … `touchesEnded`) and asks `Press`
///   at the lift. A recogniser that never sees a Pencil touch therefore cannot hold up a Pencil's tap.
/// - VoiceOver: one element, 「ツールバーを動かす」 with the hint 「上下左右の端へ移せます」, a button, the identifier
///   `toolbar.move`, the grip's 「…へ移す」 actions; activating it opens the choice. The face under it is hidden from VoiceOver.
///
/// 1.4.1's third rework (docs/R1_4_1_CONTRACT.md §18.2): the button is on the peeking bar too (`ToolbarLogic.showsMoveButton`),
/// and there it is a tap only: `drags` false (`ToolbarLogic.moveButtonDrags`, the open bar alone) keeps the pan from ever
/// beginning — its gate says no whatever the palm rule says —, so a finger that moved 10 pt and lifted is nothing (no drag,
/// no tap: `Press`), and a tap still opens the same choice with any touch. A choice there opens the bar on that edge (the
/// screen's `paletteMoveChosen`, the table's `(.peek, .placementChosen)`).
struct PaletteMoveButtonView: UIViewRepresentable {
    /// May a drag begin now (the palm rule, as the grip's)?
    var mayBegin: () -> Bool
    /// The drag started at this point (10 pt from where the touch came down).
    var onBegan: (CGPoint) -> Void
    /// The finger moved: where it is and its velocity.
    var onChanged: (CGPoint, CGVector) -> Void
    /// The finger lifted after a drag: where and how fast.
    var onEnded: (CGPoint, CGVector) -> Void
    /// A running drag was ended without a drop.
    var onCancelled: () -> Void
    /// A new value ends a running drag (the grip's trigger).
    var cancelTrigger: Int
    /// The edges the window allows and the edge the bar is on: the choices (`choices`).
    var allowed: [PaletteEdge]
    var current: PaletteEdge
    /// A choice of the dialog or a VoiceOver action chose this edge.
    var onMove: (PaletteEdge) -> Void
    /// The choice of edges is shown (the screen's state, so `--screenshot-palette-menu` can open it after the launch).
    var menuShown: Binding<Bool>
    /// §18.2: the button may drag the bar (the open bar's, `ToolbarLogic.moveButtonDrags`); false on a peek, where the pan
    /// never begins and the button is a tap only. True by default (§17.2's button).
    var drags: Bool = true

    /// The UI tests' handle (`PaletteMoveUITests`).
    static let identifier = "toolbar.move"
    /// The button's mark (SF Symbols).
    static let symbol = "arrow.up.and.down.and.arrow.left.and.right"

    /// The dialog's buttons and VoiceOver's actions: every allowed edge but the current one, in `allowed`'s order
    /// (`ToolbarLogic.moveTargets`, the grip's actions).
    static func choices(allowed: [PaletteEdge], current: PaletteEdge) -> [PaletteEdge] {
        // MUTATION MB4 (r141-q-m3 only, never merged; docs/R1_4_1_CONTRACT.md §17.4, PaletteMoveButtonTests): the choice of
        // edges offers the current edge too, every allowed edge in `allowed`'s order (was:
        // `ToolbarLogic.moveTargets(allowed: allowed, current: current)`; the grip's actions are unchanged).
        allowed
    }

    /// The edge a choice moves the bar to: `edge` while it is one of `choices`; nil (nothing happens) for an edge the window
    /// no longer allows — the dialog may still be showing it — and for the edge the bar is on.
    static func choice(_ edge: PaletteEdge, allowed: [PaletteEdge], current: PaletteEdge) -> PaletteEdge? {
        choices(allowed: allowed, current: current).contains(edge) ? edge : nil
    }

    /// This button's choices.
    var choices: [PaletteEdge] {
        Self.choices(allowed: allowed, current: current)
    }

    func makeUIView(context: Context) -> ButtonView {
        let view = ButtonView(frame: .zero)
        view.lastCancelTrigger = cancelTrigger
        view.configure(self)
        return view
    }

    func updateUIView(_ view: ButtonView, context: Context) {
        view.configure(self)
        view.apply(cancelTrigger: cancelTrigger)
    }

    /// As large as the face it lies over.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ButtonView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: ToolbarLogic.Row.buttonMinWidth, height: 44))
    }

    static func dismantleUIView(_ view: ButtonView, coordinator: ()) {
        view.cancelDrag()
        view.forgetTouch()
    }

    /// Tap or drag (§17.2), decided without UIKit: the view reports where its touch came down and of which type, where it
    /// moved, that the drag started, and where it lifted. A tap is a touch that lifted with no drag begun and, for a finger
    /// or a pointer, never `PaletteGripView.startDistance` (10 pt) from where it came down; an Apple Pencil's touch is a tap
    /// whenever it lifts (it never drags). A cancelled touch is nothing.
    struct Press: Equatable {
        /// Where the touch came down (nil: no touch followed).
        private(set) var start: CGPoint?
        /// The touch is the Apple Pencil's.
        private(set) var pencil = false
        /// It moved 10 pt or more from `start` at some point (no tap for a finger or a pointer any more).
        private(set) var far = false
        /// The drag began during this touch (never a tap).
        private(set) var dragged = false

        /// A touch is being followed.
        var isTracking: Bool {
            start != nil
        }

        /// A touch came down at `point` (any coordinates, the same for every report of it).
        mutating func began(at point: CGPoint, type: UITouch.TouchType) {
            self = Press()
            start = point
            pencil = type == .pencil
        }

        /// The touch is at `point`.
        mutating func moved(to point: CGPoint) {
            guard let start else { return }
            if PaletteGripView.passedStart(CGPoint(x: point.x - start.x, y: point.y - start.y)) {
                far = true
            }
        }

        /// The shared pan started the drag with this touch.
        mutating func dragBegan() {
            guard start != nil else { return }
            dragged = true
        }

        /// The touch lifted at `point`: true for a tap. The press is over either way.
        mutating func ended(at point: CGPoint) -> Bool {
            guard start != nil else { return false }
            moved(to: point)
            let tap = !dragged && (pencil || !far)
            self = Press()
            return tap
        }

        /// The system ended the touch: no tap.
        mutating func cancelled() {
            self = Press()
        }
    }

    /// The UIKit side: the shared pan (`PaletteGripView.PanView`) and the touch the view follows for a tap. Internal so the
    /// tests can drive it without SwiftUI.
    final class ButtonView: PaletteGripView.PanView {
        /// A tap or VoiceOver's activation: the screen shows the choice of edges.
        var onTap: () -> Void = {}
        /// The tap-or-drag of the touch followed now.
        private(set) var press = Press()
        /// The touch followed (one at a time: the view takes no second touch).
        private weak var touch: UITouch?

        override init(frame: CGRect) {
            super.init(frame: frame)
            // The pan leaves the view its touches, so a touch the pan began on but that lifted before the drag's 10 pt (a
            // mouse, a trackpad) still reaches `touchesEnded` and is a tap; a drag is told by `dragStarted`.
            pan.cancelsTouchesInView = false
            // MUTATION MB3 (r141-q-m3 only, never merged; docs/R1_4_1_CONTRACT.md §17.4, PaletteMoveButtonTests): the button's
            // pan takes the Apple Pencil too (was: the shared pan's `PaletteGripView.allowedTouchTypes`, a finger, a trackpad
            // and a mouse; the grip's own pan is unchanged).
            pan.allowedTouchTypes = (PaletteGripView.allowedTouchTypes + [.pencil]).map { NSNumber(value: $0.rawValue) }
            isMultipleTouchEnabled = false
            isAccessibilityElement = true
            accessibilityLabel = ToolbarLogic.gripAccessibilityLabel
            accessibilityHint = ToolbarLogic.gripAccessibilityHint
            accessibilityTraits = .button
            accessibilityIdentifier = PaletteMoveButtonView.identifier
        }

        required init?(coder: NSCoder) {
            nil
        }

        /// Takes the representable's drag closures, its choices as VoiceOver's actions, and its dialog. Without `drags` (a
        /// peek, §18.2) the pan's gate is a plain no, so no drag begins there.
        func configure(_ button: PaletteMoveButtonView) {
            let mayBegin: () -> Bool = button.drags ? button.mayBegin : { false }
            takeDrag(mayBegin: mayBegin, onBegan: button.onBegan, onChanged: button.onChanged, onEnded: button.onEnded,
                     onCancelled: button.onCancelled, onMove: button.onMove, moveTargets: button.choices)
            let shown = button.menuShown
            onTap = { shown.wrappedValue = true }
        }

        override func dragStarted() {
            press.dragBegan()
        }

        /// VoiceOver's double tap (and Switch Control's, Full Keyboard Access's activation) opens the choice.
        override func accessibilityActivate() -> Bool {
            onTap()
            return true
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let first = touches.first else { return }
            // A touch still down keeps the press; one UIKit ended without telling the view does not.
            if let held = touch, held !== first, held.phase != .ended, held.phase != .cancelled { return }
            touch = first
            press.began(at: first.location(in: nil), type: first.type)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch, touches.contains(touch) else { return }
            press.moved(to: touch.location(in: nil))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch, touches.contains(touch) else { return }
            let tap = press.ended(at: touch.location(in: nil))
            self.touch = nil
            // MUTATION MB2 (r141-q-m3 only, never merged; docs/R1_4_1_CONTRACT.md §17.4, PaletteMoveButtonTests): a tap opens
            // nothing (was: `if tap { onTap() }`); `Press` still decides the tap, and VoiceOver's activation still opens the
            // choice of edges.
            _ = tap
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch, touches.contains(touch) else { return }
            press.cancelled()
            self.touch = nil
        }

        /// The view leaves the screen: the touch it followed is no tap.
        func forgetTouch() {
            press.cancelled()
            touch = nil
        }
    }
}
