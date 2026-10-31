import SwiftUI
import UIKit

/// The app's own tool palette (DESIGN §3.6: PKToolPicker is not used). Pen (6 colours × 3 widths),
/// marker (4 colours), eraser, lasso, event tool (M3b contract §4.7), undo / redo, and the "draw
/// with a finger" toggle. The context area in the middle shows the pen's colours and widths, the
/// marker's colours, or a hint of at most two lines for the eraser / lasso / event tool.
///
/// The colours and widths are the web version's (js/ink/render.js). The last pen and marker styles
/// are remembered in UserDefaults so switching back from the eraser restores them. On an iPhone the
/// row scrolls horizontally (M2).
///
/// 1.1 (docs/M7A_CONTRACT.md §2.2): with `showsCollapseButton` a 「しまう」 button sits at the right
/// end, outside the scrolling row (so it stays visible when the row is wider than the screen, 0-10),
/// and `onCollapse` folds the bar into the dock button (`ToolbarDock`). The eraser's hint says where
/// it returns to (`eraserReturnsTo`, §2.4). The kind of a tool is `ToolbarLogic.kind(of:)`. Every new
/// parameter has a default, so a caller that passes none gets the 1.0.1 bar.
///
/// 1.1 (docs/M7A.md ずれ 45): the horizontal sizes are `ToolbarLogic.Row`. 「しまう」 outside the row
/// took 72.5 pt from it, so the row is packed (tools 48 with nothing between, swatches 38, 細中太 44,
/// ↶↷ 44, 6 on each side of a divider, leading 8), the hints take two lines and the row's last 12 pt
/// fade out; every device shows at least what 1.0.1 showed. The height is unchanged (44 + 8 + 8).
struct ToolbarView: View {
    @Binding var tool: CanvasTool
    @Binding var allowFinger: Bool
    var canUndo: Bool = true
    var canRedo: Bool = true
    var onUndo: () -> Void
    var onRedo: () -> Void
    /// 1.1: the 「しまう」 button at the right end (expanded and peek, §2.2). Pressable while read only.
    var showsCollapseButton: Bool = false
    var onCollapse: () -> Void = {}
    /// 1.1: the ink the eraser returns to after it erased (§2.4); nil = no bracket in the hint.
    var eraserReturnsTo: CanvasTool? = nil

    @AppStorage(ToolbarPalette.penColorKey) private var penColorHex: String = ToolbarPalette.penColors[0].hex
    // Double, not CGFloat: AppStorage only stores Double (CGFloat is a distinct type on 64-bit).
    @AppStorage(ToolbarPalette.penWidthKey) private var penWidth: Double = Double(ToolbarPalette.penWidths[1].width)
    @AppStorage(ToolbarPalette.markerColorKey) private var markerColorHex: String = ToolbarPalette.markerColors[0].hex

    private var kind: ToolKind {
        ToolbarLogic.kind(of: tool)
    }

    /// The remembered pen, checked against the tables exactly like the pen the app starts with
    /// (`ToolbarPalette.rememberedPen`, 0-13), so the lit swatch and width are the starting pen's.
    private var penStyle: InkStyle {
        ToolbarPalette.pen(colorHex: penColorHex, width: penWidth)
    }

    private var markerStyle: InkStyle {
        InkStyle(tool: .marker, colorHex: markerColorHex, width: ToolbarPalette.markerWidth)
    }

    var body: some View {
        bar
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The scrolling row, with the 「しまう」 button outside it at the right end when asked for (§2.2).
    @ViewBuilder
    private var bar: some View {
        if showsCollapseButton {
            HStack(spacing: 0) {
                scrollingRow
                Divider().frame(height: 24)
                collapseButton
                    .padding(.leading, ToolbarLogic.Row.collapseLeading)
                    .padding(.trailing, ToolbarLogic.Row.collapseTrailing)
            }
        } else {
            scrollingRow
        }
    }

    private var scrollingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ToolbarLogic.Row.groupSpacing) {
                toolButtons
                Divider().frame(height: 24)
                colorSwatches
                if kind == .pen {
                    Divider().frame(height: 24)
                    widthButtons
                }
                Divider().frame(height: 24)
                historyButtons
                Divider().frame(height: 24)
                fingerToggle
            }
            .padding(.leading, ToolbarLogic.Row.paddingLeading)
            .padding(.trailing, ToolbarLogic.Row.paddingTrailing)
            .padding(.vertical, 8)
        }
        // The last 12 pt before 「しまう」's divider fade out, so a piece cut there reads as "more to
        // the right" (1.0.1 cut it at the bar's round end; the divider would slice it off). Nothing
        // is drawn there when the row fits or is scrolled to its end (the trailing padding is 14).
        .mask {
            HStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: ToolbarLogic.Row.fadeWidth)
            }
        }
    }

    // MARK: - Pieces

    /// The face of the tool buttons and of 「しまう」 (ずれ 45): the symbol (18 pt) in a box as tall as the
    /// tools' symbols (22, measured in the CI photos; chevron.down alone is 12), so 「しまう」's label
    /// sits level with the tools' labels; a 10 pt label under it; as wide as the label + 5 + 5, at
    /// least 48 (the scrolling row proposes no width, so a longer label widens the button).
    private func buttonFace(symbol: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(height: ToolbarLogic.Row.symbolHeight)
            Text(label)
                .font(.system(size: 10))
                .lineLimit(1)
        }
        .padding(.horizontal, ToolbarLogic.Row.labelInset)
        .frame(minWidth: ToolbarLogic.Row.buttonMinWidth)
        .frame(height: 44)
    }

    /// 「しまう」: the same face as the tool buttons. Never disabled — folding the bar is harmless
    /// while read only.
    private var collapseButton: some View {
        Button(action: onCollapse) {
            buttonFace(symbol: "chevron.down", label: ToolbarLogic.collapseTitle)
                .foregroundStyle(Color.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ToolbarLogic.collapseAccessibilityLabel)
    }

    private var toolButtons: some View {
        HStack(spacing: 0) {
            toolButton(.pen, symbol: "pencil.tip", label: "ペン") { tool = .ink(penStyle) }
            toolButton(.marker, symbol: "highlighter", label: "マーカー") { tool = .ink(markerStyle) }
            toolButton(.eraser, symbol: "eraser", label: "消しゴム") { tool = .eraser }
            toolButton(.lasso, symbol: "lasso", label: "投げなわ") { tool = .lasso }
            toolButton(.eventRect, symbol: "calendar.badge.plus", label: "予定") { tool = .eventRect }
        }
    }

    private func toolButton(_ target: ToolKind, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        let selected = kind == target
        return Button(action: action) {
            buttonFace(symbol: symbol, label: label)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var colorSwatches: some View {
        switch kind {
        case .pen:
            HStack(spacing: 0) {
                ForEach(ToolbarPalette.penColors, id: \.hex) { entry in
                    swatch(entry, selected: entry.hex == penStyle.colorHex) {
                        penColorHex = entry.hex
                        tool = .ink(penStyle)
                    }
                }
            }
        case .marker:
            HStack(spacing: 0) {
                ForEach(ToolbarPalette.markerColors, id: \.hex) { entry in
                    swatch(entry, selected: entry.hex == markerColorHex) {
                        markerColorHex = entry.hex
                        tool = .ink(markerStyle)
                    }
                }
            }
        case .eraser:
            hint(ToolbarLogic.eraserBarHint(returnsTo: eraserReturnsTo))
        case .lasso:
            hint(ToolbarLogic.lassoBarHint)
        case .eventRect:
            hint(ToolbarLogic.eventBarHint)
        }
    }

    /// A concrete colour rather than the hierarchical `.secondary`: over the toolbar's material
    /// SwiftUI renders `.secondary` with vibrancy, which the CI simulator (software rendering) does
    /// not draw at all, so the hint was invisible in the screenshots. Two lines at most (the texts
    /// carry their "\n", ずれ 45); the size stops at xLarge (14 pt), so two lines stay inside the
    /// 44 pt row (xxLarge's 16 pt would need about 45).
    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .lineLimit(2)
            .frame(height: 44)
    }

    private func swatch(_ entry: ToolbarPalette.Entry, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: PaperPalette.color(hex: entry.hex)))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.15)))
                if selected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: ToolbarLogic.Row.swatchWidth, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var widthButtons: some View {
        HStack(spacing: 0) {
            ForEach(ToolbarPalette.penWidths, id: \.width) { entry in
                let selected = abs(entry.width - penStyle.width) < 0.001
                Button {
                    penWidth = Double(entry.width)
                    tool = .ink(penStyle)
                } label: {
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: 22, height: max(2, entry.width * 1.2))
                        Text(entry.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, ToolbarLogic.Row.widthLabelInset)
                    .frame(minWidth: ToolbarLogic.Row.widthButtonMinWidth)
                    .frame(height: 44)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("太さ: \(entry.name)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var historyButtons: some View {
        HStack(spacing: 0) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: ToolbarLogic.Row.historyButtonWidth, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .accessibilityLabel("元に戻す")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: ToolbarLogic.Row.historyButtonWidth, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRedo)
            .accessibilityLabel("やり直す")
        }
    }

    private var fingerToggle: some View {
        Toggle(isOn: $allowFinger) {
            Label("指でも書く", systemImage: "hand.draw")
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .toggleStyle(.button)
        .accessibilityHint("オンにすると指でも線が引けます。オフのときは指でスクロールとタップをします")
    }
}

/// The toolbar's colours and widths (the web version's, js/ink/render.js and js/ui/toolbar.js).
enum ToolbarPalette {
    /// The remembered pen / marker (UserDefaults, per device). `rememberedPen` reads the first two.
    static let penColorKey = "toolbar.penColor"
    static let penWidthKey = "toolbar.penWidth"
    static let markerColorKey = "toolbar.markerColor"

    struct Entry: Hashable {
        var hex: String
        var name: String
    }

    struct Width: Hashable {
        var width: CGFloat
        var name: String
    }

    static let penColors: [Entry] = [
        Entry(hex: "#1f2937", name: "黒"),
        Entry(hex: "#2563eb", name: "青"),
        Entry(hex: "#dc2626", name: "赤"),
        Entry(hex: "#16a34a", name: "緑"),
        Entry(hex: "#ea580c", name: "オレンジ"),
        Entry(hex: "#7c3aed", name: "紫"),
    ]

    static let markerColors: [Entry] = [
        Entry(hex: "#fde047", name: "黄"),
        Entry(hex: "#f9a8d4", name: "ピンク"),
        Entry(hex: "#86efac", name: "緑"),
        Entry(hex: "#93c5fd", name: "水色"),
    ]

    /// Pen widths in lu (DESIGN §3.6: 細 2 / 中 3.5 / 太 6).
    static let penWidths: [Width] = [
        Width(width: 2, name: "細"),
        Width(width: 3.5, name: "中"),
        Width(width: 6, name: "太"),
    ]

    /// Marker width in lu.
    static let markerWidth: CGFloat = 18

    /// The pen the app starts with (黒・中).
    static var defaultPen: InkStyle {
        InkStyle(tool: .pen, colorHex: penColors[0].hex, width: penWidths[1].width)
    }
}
