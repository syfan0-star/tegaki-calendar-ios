import PencilKit
import SwiftUI
import UIKit

/// The ink tools the app exposes (mirrors the web version: pen / highlighter / eraser).
enum InkTool: String, CaseIterable, Identifiable {
    case pen
    case highlighter
    case eraser

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pen: return "ペン"
        case .highlighter: return "マーカー"
        case .eraser: return "消しゴム"
        }
    }

    /// The PencilKit tool for this choice. Colours and widths follow the web version's defaults
    /// and DESIGN.md §3.6 (pen 中 = 3.5, marker = 18). The eraser is the *vector* eraser: it removes
    /// a whole stroke on touch, exactly like the web version (no partial erasing).
    var pkTool: PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: UIColor(red: 0x1f / 255.0, green: 0x29 / 255.0, blue: 0x37 / 255.0, alpha: 1), width: 3.5)
        case .highlighter:
            return PKInkingTool(.marker, color: UIColor(red: 0xfd / 255.0, green: 0xe0 / 255.0, blue: 0x47 / 255.0, alpha: 1), width: 18)
        case .eraser:
            return PKEraserTool(.vector)
        }
    }
}

/// A transparent PencilKit canvas (PKCanvasView) for SwiftUI.
///
/// - `drawing` is the ink. The canvas writes every change back; setting it from outside
///   (e.g. to `PKDrawing()` for "clear") replaces the ink on screen.
/// - `tool` is the current tool. The app's own toolbar drives the canvas; Apple's PKToolPicker is
///   deliberately not used (DESIGN.md §3.6: its lasso selection cannot be read by the app).
/// - `fingerDrawingEnabled` maps to `drawingPolicy`: `.anyInput` when on, `.pencilOnly` when off
///   (the modern replacement of the deprecated `allowsFingerDrawing = false`). Fingers then scroll /
///   tap instead of drawing, so a resting palm never leaves a mark.
/// - Apple Pencil double tap / squeeze (pen ⇄ eraser, honouring Settings > Apple Pencil) is handled
///   by `PencilInteractionHandler`, attached to the canvas once in `makeUIView`.
///
/// M1 note: scrolling is disabled, so stroke coordinates are plain page coordinates of this view.
/// Anchoring strokes to day cells (so rows can grow) comes in M2 (DESIGN.md §3.3–3.5).
struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var tool: InkTool
    var fingerDrawingEnabled: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.drawing = drawing
        canvas.tool = tool.pkTool
        canvas.addInteraction(context.coordinator.pencilInteraction)
        context.coordinator.apply(self, to: canvas, isInitial: true)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.apply(self, to: canvas, isInitial: false)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        private weak var canvas: PKCanvasView?
        private let pencilHandler: PencilInteractionHandler
        /// Receives Apple Pencil double taps / squeezes. Added to the canvas in `makeUIView`.
        let pencilInteraction: UIPencilInteraction
        /// The last pen-like tool, so the eraser toggle can go back to it.
        private var lastDrawingTool: InkTool = .pen

        init(parent: CanvasView) {
            self.parent = parent
            let handler = PencilInteractionHandler()
            pencilHandler = handler
            pencilInteraction = handler.makeInteraction()
            super.init()
            handler.onSwitchEraser = { [weak self] in self?.toggleEraser() }
            // M1 has no tool history yet, so "switch to the previous tool" behaves like the eraser toggle.
            handler.onSwitchPrevious = { [weak self] in self?.toggleEraser() }
        }

        func apply(_ newParent: CanvasView, to canvas: PKCanvasView, isInitial: Bool) {
            parent = newParent
            self.canvas = canvas

            canvas.drawingPolicy = newParent.fingerDrawingEnabled ? .anyInput : .pencilOnly
            if newParent.tool != .eraser { lastDrawingTool = newParent.tool }

            // Push the drawing only when it really changed outside the canvas (e.g. "clear"),
            // never while PencilKit is reporting its own edits back to us.
            if !isInitial, canvas.drawing.dataRepresentation() != newParent.drawing.dataRepresentation() {
                canvas.drawing = newParent.drawing
            }

            canvas.tool = newParent.tool.pkTool
        }

        // MARK: PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }

        // MARK: Apple Pencil gestures

        private func toggleEraser() {
            let next: InkTool = parent.tool == .eraser ? lastDrawingTool : .eraser
            canvas?.tool = next.pkTool
            parent.tool = next
        }
    }
}
