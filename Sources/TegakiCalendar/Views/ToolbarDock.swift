import SwiftUI
import UIKit

/// 1.1 (docs/M7A_CONTRACT.md §2.2, P-4 A): the collapsed toolbar — a small capsule in a bottom corner
/// with the current tool's mark and ↶. The mark sits on the corner's side (bottom left: mark, ↶;
/// bottom right: ↶, mark). Tapping the mark peeks the bar (`onExpand`); ↶ undoes like the bar's ↶
/// (`onUndo`; the caller checks `isAllowed(.undoRedo)`). A long press anywhere on the capsule opens
/// the menu 「右下へ移す」 / 「左下へ移す」 (`onMoveEdge`) and 「ツールバーをいつも出す」 (`onPin`,
/// M7A-4); VoiceOver gets the same two as actions of the mark. The caller places it with
/// `.overlay(alignment: .bottomLeading / .bottomTrailing)`, 12 pt from the side and 6 pt above the
/// bottom safe area (`ToolbarLogic.sidePadding` / `bottomPadding`).
struct ToolbarDock: View {
    var tool: CanvasTool
    var canUndo: Bool
    var edge: ToolbarEdge
    var onExpand: () -> Void
    var onUndo: () -> Void
    var onMoveEdge: () -> Void
    var onPin: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if edge == .leading {
                toolPart
                undoPart
            } else {
                undoPart
                toolPart
            }
        }
        .padding(2)
        .frame(width: ToolbarLogic.pillWidth, height: ToolbarLogic.pillHeight)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .contentShape(.contextMenuPreview, Capsule())
        .contextMenu {
            Button(action: onMoveEdge) {
                Label(ToolbarLogic.moveEdgeTitle(from: edge), systemImage: ToolbarLogic.moveEdgeSymbol(from: edge))
            }
            Button(action: onPin) {
                Label(ToolbarLogic.pinTitle, systemImage: "dock.rectangle")
            }
        }
    }

    // MARK: - Pieces

    private var badge: ToolBadge {
        ToolbarLogic.badge(for: tool)
    }

    private var toolPart: some View {
        Button(action: onExpand) {
            mark
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ToolbarLogic.dockAccessibilityLabel)
        .accessibilityValue(badge.accessibilityValue)
        .accessibilityHint(ToolbarLogic.dockAccessibilityHint(edge: edge))
        .accessibilityAction(named: ToolbarLogic.moveEdgeTitle(from: edge), onMoveEdge)
        .accessibilityAction(named: ToolbarLogic.pinTitle, onPin)
    }

    private var undoPart: some View {
        Button(action: onUndo) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canUndo)
        .accessibilityLabel("元に戻す")
    }

    /// The mark of `ToolbarLogic.badge(for:)`: a pen's dot (with a faint 1 pt ring outside it, so a
    /// light colour still shows), a marker's symbol over a bar of its colour, or the tool's symbol.
    @ViewBuilder
    private var mark: some View {
        let badge = self.badge
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
