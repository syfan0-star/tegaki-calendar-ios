import SwiftUI
import UIKit

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.7, 0e-18): what the screen lays over itself while the grip is dragged. Nothing
/// is laid out again during the drag (the bar stays open in its slot at `ToolbarLogic.draggedBarOpacity`); this overlay
/// takes no touch (`allowsHitTesting(false)`) and is not read by VoiceOver:
/// - for each allowed edge, the frame its bar would take (`ToolbarLogic.barFrame(_:in:)`), filled with the accent colour at
///   12 % (`slotOutlineOpacity`); the edge the drop would snap to now (`target`, `ToolbarLogic.snapEdge`) at 28 % with a
///   2 pt accent border;
/// - the puck: `ToolbarDock`'s 96 × 48 capsule (material, hairline, shadow) with the current tool's mark
///   (`ToolbarLogic.badge(for:)`, drawn as the dock draws it), centred `ToolbarLogic.puckLift` (40 pt) above the finger.
/// `finger` and `column` are in this view's own coordinates (the grip reports the window's: the screen converts); the view
/// fills what it is offered. The screen shows and hides it with its opacity only.
struct PaletteDragOverlay: View {
    /// Where the finger is.
    var finger: CGPoint
    /// The tool in use (the puck's mark).
    var tool: CanvasTool
    /// The slots' column: under the header and its notices, down to the bottom of the safe area, full width.
    var column: CGRect
    /// The edges the window allows (`ToolbarLogic.allowedEdges`).
    var allowed: [PaletteEdge]
    /// The edge the drop would snap to now.
    var target: PaletteEdge

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(PaletteEdge.allCases.filter { allowed.contains($0) }, id: \.self) { edge in
                outline(edge)
            }
            puck
                .position(x: finger.x, y: finger.y - ToolbarLogic.puckLift)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One edge's future bar.
    private func outline(_ edge: PaletteEdge) -> some View {
        let frame = ToolbarLogic.barFrame(edge, in: column)
        let isTarget = edge == target
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return shape
            .fill(Color.accentColor.opacity(isTarget ? ToolbarLogic.snapTargetOpacity : ToolbarLogic.slotOutlineOpacity))
            .overlay(shape.strokeBorder(Color.accentColor, lineWidth: ToolbarLogic.snapTargetBorder).opacity(isTarget ? 1 : 0))
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    /// The dock's capsule with the tool's mark in its middle.
    private var puck: some View {
        mark
            .frame(width: ToolbarLogic.pillWidth, height: ToolbarLogic.pillHeight)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    /// `ToolbarDock`'s mark (that one is private to the dock): a pen's dot with a faint ring, a marker's symbol over a bar
    /// of its colour, or the tool's symbol.
    @ViewBuilder
    private var mark: some View {
        let badge = ToolbarLogic.badge(for: tool)
        if let diameter = badge.dotDiameter, let hex = badge.colorHex {
            ZStack {
                Circle()
                    .fill(Color(uiColor: PaperPalette.color(hex: hex)))
                    .frame(width: diameter, height: diameter)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: diameter + 2, height: diameter + 2)
            }
        } else if let symbol = badge.symbol {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary)
                if let hex = badge.colorHex {
                    Capsule()
                        .fill(Color(uiColor: PaperPalette.color(hex: hex)))
                        .frame(width: 22, height: 4)
                }
            }
        }
    }
}
