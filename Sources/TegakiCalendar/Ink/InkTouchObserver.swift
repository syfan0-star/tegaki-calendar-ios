import UIKit
import UIKit.UIGestureRecognizerSubclass

/// 1.1 fix (TestFlight build 12, 確認 4・5・6b; docs/M7A.md ずれ 46): tells the canvas's coordinator when
/// the Pencil, a finger or a pointer touches the paper and when it lifts — physically, whatever
/// PencilKit says about its tool and whenever it says it (`InkCanvasView.Coordinator.touchObserved`).
/// It lives on the `InkCanvasContainerView` and never takes part in recognition: it stays `.possible`
/// while something touches and becomes `.failed` when the last touch lifts, never `.began` or `.ended`
/// (it holds nothing up and makes nothing fail); it lets every touch through at once
/// (`cancelsTouchesInView`, `delaysTouchesBegan`, `delaysTouchesEnded` off), takes the Pencil, fingers
/// and a pointer together, prevents nothing and is prevented by nothing, and the coordinator lets it
/// run alongside every recogniser. The pointer (the review): with `UIApplicationSupportsIndirectInputEvents`
/// a mouse's or a trackpad's press on the paper is an `.indirectPointer` touch. On a Mac PencilKit draws
/// with it (and with a finger) in every drawing policy (`[0, 2, 3]`); on an iOS it is not known yet, so
/// the coordinator counts it on its own as a touch that writes whatever 「指でも書く」 says (the lead's
/// review; the safe side) and waits for it like a finger after it lifts. Tried on a real Mac Catalyst window: PencilKit erased as before with it on
/// the container, and its `up` arrived before PencilKit's end of the tool.
@MainActor
final class InkTouchObserver: UIGestureRecognizer {
    /// A touch of this type came down, or lifted (ended or cancelled).
    enum Change: Equatable {
        case down(UITouch.TouchType)
        case up(UITouch.TouchType)
    }

    /// Every change, in order: each touch is reported down once and up once.
    var onChange: (Change) -> Void = { _ in }
    /// The touches that are down, with their type.
    private var down: [ObjectIdentifier: UITouch.TouchType] = [:]

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [UITouch.TouchType.pencil, .direct, .indirectPointer].map { NSNumber(value: $0.rawValue) }
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard down[key] == nil else { continue }
            let type = touch.type
            down[key] = type
            onChange(.down(type))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        lift(touches)
    }

    /// The touches lifted; with the last one the recogniser fails, so UIKit resets it for the next.
    private func lift(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let type = down.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            onChange(.up(type))
        }
        if down.isEmpty, state == .possible {
            state = .failed
        }
    }

    /// UIKit ended the sequence some other way (the view left the window, the recogniser was turned
    /// off): what is still down is reported up, so the coordinator never waits for it.
    override func reset() {
        super.reset()
        let left = Array(down.values)
        down.removeAll()
        for type in left {
            onChange(.up(type))
        }
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}
