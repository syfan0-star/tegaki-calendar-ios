import UIKit

/// Receives Apple Pencil double taps (iOS 12.1+) and Apple Pencil Pro squeezes (iOS 17.5+) and asks
/// its owner to toggle pen ⇄ eraser, honouring the action the person chose in
/// Settings > Apple Pencil (`UIPencilInteraction.preferredTapAction` / `preferredSqueezeAction`).
///
/// Only "Switch between current tool and eraser" and "Switch between current tool and last used"
/// are acted on; both call `onToggle` (the toolbar owner keeps the last ink style, so "last used"
/// and "eraser" come out the same while the only two kinds of tool are ink and eraser). "Off"
/// (`.ignore`) does nothing, and the palette / ink-attribute actions are left alone until the app
/// has its own tool palette (DESIGN.md §3.11).
@MainActor
final class PencilInteractionHandler: NSObject, UIPencilInteractionDelegate {
    /// Called when the gesture should toggle pen ⇄ eraser.
    var onToggle: (() -> Void)?

    /// A new interaction whose delegate is this handler. Add it to the drawing view with `addInteraction(_:)`.
    func makeInteraction() -> UIPencilInteraction {
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        return interaction
    }

    private func perform(_ action: UIPencilPreferredAction) {
        switch action {
        case .switchEraser, .switchPrevious:
            onToggle?()
        case .ignore:
            break
        default:
            // .showColorPalette / .showInkAttributes / .showContextualPalette / .runSystemShortcut:
            // not supported yet (no custom palette in M2).
            break
        }
    }

    // MARK: - UIPencilInteractionDelegate

    // iOS 12.1 – 17.4. On 17.5+ the system prefers the tap-object variant below.
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        perform(UIPencilInteraction.preferredTapAction)
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        perform(UIPencilInteraction.preferredTapAction)
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        // Act once per squeeze, when the person lets go.
        guard squeeze.phase == .ended else { return }
        perform(UIPencilInteraction.preferredSqueezeAction)
    }
}
