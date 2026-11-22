import SwiftUI
import UIKit

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.5, §4.6, §4.11, 0e-16, 0e-17, 0e-22): the grip of the open toolbar — the touch
/// zone on the bar's inner edge (120 × 16, 14 × 120 on a side bar; `ToolbarLogic.gripSize`) that moves the bar to another
/// edge. A `UIPanGestureRecognizer` on a plain UIView, because SwiftUI's drag also takes the Apple Pencil and
/// `UIGestureRecognizerRepresentable` needs iOS 18:
/// - only a finger, a trackpad or a mouse (`allowedTouchTypes` [.direct, .indirectPointer]), never the Pencil;
/// - the drag starts once the touch moved `startDistance` (10 pt) from where it came down (`onBegan`, then `onChanged`
///   with every move); a touch that ends before is nothing;
/// - the recogniser may begin only when `mayBegin()` says so (`gestureRecognizerShouldBegin`): the screen asks its
///   `PalmWatch`, which answers with the frozen palm rule `InkCanvasView.horizontalPanMayBegin`; the drag's start at
///   10 pt asks it again, and a no there forgets the touch;
/// - a new `cancelTrigger` ends a running drag (`onCancelled`): the screen raises it on a Pencil down (`PalmWatch`), on
///   `penDown()`, in the background, on a new window size and when a sheet opens (§4.6). So does the view's removal.
/// Points are in the window's coordinates (SwiftUI's `.global` space), velocities in pt/s. `onCancelled` is reported on
/// the main actor's next turn (the trigger arrives inside a SwiftUI update, which must not change the screen's state).
///
/// The view is also the grip's one VoiceOver element (§4.11): 「ツールバーを動かす」, the hint 「上下左右の端へ移せます」,
/// the identifier `toolbar.grip`, and an action 「上へ移す」「下へ移す」「左へ移す」「右へ移す」 for each of `moveTargets`
/// (`ToolbarLogic.moveTargets`), which calls `onMove` (the screen writes the edge as a drop does) and then posts
/// `.layoutChanged`. Switch Control and Full Keyboard Access use the same actions. It draws the 36 × 5 mark
/// (`ToolbarLogic.gripMarkFrame`) in `secondaryLabel` over the bar's padding of `edge`, nothing over the gap to the paper.
///
/// `edge`, `moveTargets` and `onMove` are additions to §2.1's declaration, with defaults: a call with §2.1's six
/// arguments gets a bottom grip without actions.
struct PaletteGripView: UIViewRepresentable {
    /// May a drag begin now (the palm rule)?
    var mayBegin: () -> Bool
    /// The drag started at this point (10 pt from where the touch came down).
    var onBegan: (CGPoint) -> Void
    /// The finger moved: where it is and its velocity.
    var onChanged: (CGPoint, CGVector) -> Void
    /// The finger lifted after a drag: where and how fast (`ToolbarLogic.snapEdge`).
    var onEnded: (CGPoint, CGVector) -> Void
    /// A running drag was ended without a drop (`cancelTrigger`, the system, the view's removal).
    var onCancelled: () -> Void
    /// A new value ends a running drag (the value at creation ends nothing).
    var cancelTrigger: Int
    /// The edge of the bar the grip is on: where the mark sits and which way it lies.
    var edge: PaletteEdge = .bottom
    /// The edges VoiceOver's actions move the bar to (`ToolbarLogic.moveTargets(allowed:current:)`).
    var moveTargets: [PaletteEdge] = []
    /// A VoiceOver action chose this edge.
    var onMove: (PaletteEdge) -> Void = { _ in }

    /// The distance (pt) a touch moves before the drag starts (§4.6).
    static let startDistance: CGFloat = 10
    /// The touches that move the bar: a finger, a trackpad, a mouse. Not the Apple Pencil (§4.6, MT2).
    // MUTATION MT2 (r141-q-m2 only, never merged; docs/R1_4_1_CONTRACT.md §16.7, PaletteGripTests): the grip's pan takes
    // the Apple Pencil too (was: a finger, a trackpad and a mouse only).
    static let allowedTouchTypes: [UITouch.TouchType] = [.direct, .indirectPointer, .pencil]
    /// The UI tests' handle (`PaletteMoveUITests`).
    static let identifier = "toolbar.grip"

    /// Has a touch moved far enough (`translation` from where it came down) for the drag to start?
    static func passedStart(_ translation: CGPoint) -> Bool {
        let distance = (translation.x * translation.x + translation.y * translation.y).squareRoot()
        return distance.isFinite && distance >= startDistance
    }

    func makeUIView(context: Context) -> GripView {
        let view = GripView(frame: .zero)
        view.lastCancelTrigger = cancelTrigger
        view.configure(self)
        return view
    }

    func updateUIView(_ view: GripView, context: Context) {
        view.configure(self)
        view.apply(cancelTrigger: cancelTrigger)
    }

    /// The grip's size (`ToolbarLogic.gripSize`), whatever is proposed.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GripView, context: Context) -> CGSize? {
        ToolbarLogic.gripSize(for: edge)
    }

    static func dismantleUIView(_ view: GripView, coordinator: ()) {
        view.cancelDrag()
    }

    /// The UIKit side: the pan, its gate and the mark. Internal so the tests can drive it without SwiftUI.
    final class GripView: UIView {
        /// The grip's recogniser (on this view).
        let pan = UIPanGestureRecognizer()
        var mayBegin: () -> Bool = { false }
        var onBegan: (CGPoint) -> Void = { _ in }
        var onChanged: (CGPoint, CGVector) -> Void = { _, _ in }
        var onEnded: (CGPoint, CGVector) -> Void = { _, _ in }
        var onCancelled: () -> Void = {}
        var onMove: (PaletteEdge) -> Void = { _ in }
        /// The last `cancelTrigger` seen.
        var lastCancelTrigger = 0
        /// A drag is running: it passed `startDistance` and has not ended.
        private(set) var dragging = false
        private(set) var edge: PaletteEdge = .bottom
        private(set) var moveTargets: [PaletteEdge] = []
        private let gate = Gate()
        private let mark = UIView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            pan.addTarget(self, action: #selector(panned(_:)))
            pan.allowedTouchTypes = PaletteGripView.allowedTouchTypes.map { NSNumber(value: $0.rawValue) }
            pan.maximumNumberOfTouches = 1
            gate.grip = self
            pan.delegate = gate
            addGestureRecognizer(pan)
            mark.backgroundColor = .secondaryLabel
            mark.isUserInteractionEnabled = false
            addSubview(mark)
            isAccessibilityElement = true
            accessibilityLabel = ToolbarLogic.gripAccessibilityLabel
            accessibilityHint = ToolbarLogic.gripAccessibilityHint
            accessibilityIdentifier = PaletteGripView.identifier
        }

        required init?(coder: NSCoder) {
            nil
        }

        /// Takes the representable's closures, edge and actions.
        func configure(_ grip: PaletteGripView) {
            mayBegin = grip.mayBegin
            onBegan = grip.onBegan
            onChanged = grip.onChanged
            onEnded = grip.onEnded
            onCancelled = grip.onCancelled
            onMove = grip.onMove
            if edge != grip.edge {
                edge = grip.edge
                setNeedsLayout()
            }
            if moveTargets != grip.moveTargets {
                moveTargets = grip.moveTargets
                accessibilityCustomActions = grip.moveTargets.map { target in
                    UIAccessibilityCustomAction(name: ToolbarLogic.moveToTitle(target)) { [weak self] _ in
                        self?.moved(to: target) ?? false
                    }
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let frame = ToolbarLogic.gripMarkFrame(for: edge, in: bounds.size)
            mark.frame = frame
            mark.layer.cornerRadius = min(frame.width, frame.height) / 2
        }

        /// A VoiceOver action: the screen moves the bar, then VoiceOver is told the screen changed (on the next turn,
        /// after SwiftUI laid it out).
        @discardableResult
        func moved(to target: PaletteEdge) -> Bool {
            onMove(target)
            Task { @MainActor in
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
            return true
        }

        @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
            let velocity = recognizer.velocity(in: nil)
            handle(recognizer.state, location: recognizer.location(in: nil), translation: recognizer.translation(in: nil),
                   velocity: CGVector(dx: velocity.x, dy: velocity.y))
        }

        /// One message of the pan (internal: the tests stand in for UIKit with it). The palm rule is asked again where the
        /// drag really starts (§4.6): UIKit's pan may begin before the 10 pt (a mouse, a trackpad, a short start distance),
        /// and a Pencil that came down or lifted in between reached no running drag to cancel; then the touch is forgotten
        /// (`cancelDrag`) and nothing is reported.
        func handle(_ state: UIGestureRecognizer.State, location: CGPoint, translation: CGPoint, velocity: CGVector) {
            switch state {
            case .began, .changed:
                if !dragging {
                    guard PaletteGripView.passedStart(translation) else { return }
                    guard mayBegin() else {
                        cancelDrag()
                        return
                    }
                    dragging = true
                    onBegan(location)
                }
                onChanged(location, velocity)
            case .ended:
                guard dragging else { return }
                dragging = false
                onEnded(location, velocity)
            case .cancelled, .failed:
                guard dragging else { return }
                dragging = false
                onCancelled()
            default:
                break
            }
        }

        /// A new trigger ends a running drag; the same value does nothing.
        func apply(cancelTrigger: Int) {
            guard cancelTrigger != lastCancelTrigger else { return }
            lastCancelTrigger = cancelTrigger
            cancelDrag()
        }

        /// Ends the touch the pan holds (turning it off and on again cancels it, and a touch not yet a drag is
        /// forgotten too); a running drag reports `onCancelled` on the main actor's next turn.
        func cancelDrag() {
            let wasDragging = dragging
            dragging = false
            if pan.isEnabled {
                pan.isEnabled = false
                pan.isEnabled = true
            }
            guard wasDragging else { return }
            let report = onCancelled
            Task { @MainActor in
                report()
            }
        }
    }

    /// The pan's delegate: it may begin only when the grip's `mayBegin()` says so. (Not the view itself: UIView has a
    /// `gestureRecognizerShouldBegin(_:)` of its own, asked for other recognisers too.)
    final class Gate: NSObject, UIGestureRecognizerDelegate {
        weak var grip: GripView?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            grip?.mayBegin() ?? false
        }
    }
}

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.6, 0e-17): the Apple Pencil anywhere in the window, for the grip's palm rule.
/// A new instance of the frozen `InkTouchObserver` (the file is used as it is) on the UIWindow, recognising with every
/// other recogniser (it never begins, so it holds nothing up): a Pencil coming down counts one more `pencilsDown` and
/// calls `onPencilDown` (the screen ends a running drag), a Pencil lifting counts one less and notes the time. A finger
/// and a pointer are not counted. `mayBegin(now:)` is the canvas's own palm rule, `InkCanvasView.horizontalPanMayBegin`
/// (no drag while a Pencil touches or for `palmHold`, 0.5 s, after it lifted). The screen attaches it only while the
/// window allows two edges or more (`follow(window:allowed:)`), so an iPhone and a narrow iPad window get none — a new
/// attach path on the iPad: `PencilPhone` still attaches nothing there (1.4's 0d-39, narrowed to `PencilPhone`).
@MainActor
final class PalmWatch {
    /// A Pencil came down somewhere in the window.
    var onPencilDown: () -> Void = {}
    /// The Pencils touching now (never below 0).
    private(set) var pencilsDown = 0
    /// When the last Pencil lifted (`clock`).
    private(set) var lastPencilUp: Date?
    /// The watcher's window (nil while detached).
    private(set) weak var window: UIWindow?

    private let clock: () -> Date
    private let simultaneous = Simultaneous()
    private var observer: InkTouchObserver?

    /// `clock`: the time of a lift (the tests pass their own).
    init(clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
    }

    /// The watcher is on a window.
    var isAttached: Bool {
        observer != nil
    }

    /// Whether the screen wants the watcher: two allowed edges or more (the grip shows only then, §4.5).
    nonisolated static func wanted(allowed: [PaletteEdge]) -> Bool {
        allowed.count >= 2
    }

    /// The watcher on `window` (again only for another window, or after `detach`).
    func attach(to window: UIWindow) {
        guard window !== self.window || observer == nil else { return }
        detach()
        self.window = window
        let observer = InkTouchObserver(target: nil, action: nil)
        observer.delegate = simultaneous
        observer.onChange = { [weak self] change in self?.touched(change) }
        window.addGestureRecognizer(observer)
        self.observer = observer
    }

    /// The watcher off its window; what was still down counts as lifted.
    func detach() {
        if let observer {
            observer.view?.removeGestureRecognizer(observer)
            self.observer = nil
            if pencilsDown > 0 {
                pencilsDown = 0
                lastPencilUp = clock()
            }
        }
        window = nil
    }

    /// The screen's one call: attached to `window` while `allowed` has two edges or more, detached otherwise (and
    /// without a window).
    func follow(window: UIWindow?, allowed: [PaletteEdge]) {
        if let window, Self.wanted(allowed: allowed) {
            attach(to: window)
        } else {
            detach()
        }
    }

    /// May the grip's drag begin at `now`? `InkCanvasView.horizontalPanMayBegin` with this window's Pencils.
    func mayBegin(now: Date) -> Bool {
        InkCanvasView.horizontalPanMayBegin(pencilsDown: pencilsDown, lastPencilUp: lastPencilUp, now: now)
    }

    /// The window's watcher saw a touch come down or lift (internal: the tests stand in for UIKit with it, as
    /// `PencilPhone.touched` does). Only the Apple Pencil counts.
    func touched(_ change: InkTouchObserver.Change) {
        switch change {
        case .down(.pencil):
            pencilsDown += 1
            onPencilDown()
        case .up(.pencil):
            pencilsDown = max(0, pencilsDown - 1)
            lastPencilUp = clock()
        default:
            break
        }
    }

    /// The watcher recognises alongside every recogniser (`PencilPhone`'s, copied: that one is private to it).
    private final class Simultaneous: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
