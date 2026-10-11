import SwiftUI
import UIKit

/// The app's own tool palette (DESIGN §3.6: PKToolPicker is not used). Pen (6 colours × 3 widths),
/// marker (4 colours), eraser, undo / redo, and the "draw with a finger" toggle.
///
/// The colours and widths are the web version's (js/ink/render.js). The last pen and marker styles
/// are remembered in UserDefaults so switching back from the eraser restores them.
struct ToolbarView: View {
    @Binding var tool: CanvasTool
    @Binding var allowFinger: Bool
    var canUndo: Bool = true
    var canRedo: Bool = true
    var onUndo: () -> Void
    var onRedo: () -> Void

    @AppStorage("toolbar.penColor") private var penColorHex: String = ToolbarPalette.penColors[0].hex
    // Double, not CGFloat: AppStorage only stores Double (CGFloat is a distinct type on 64-bit).
    @AppStorage("toolbar.penWidth") private var penWidth: Double = Double(ToolbarPalette.penWidths[1].width)
    @AppStorage("toolbar.markerColor") private var markerColorHex: String = ToolbarPalette.markerColors[0].hex

    private enum Kind: Equatable {
        case pen, marker, eraser
    }

    private var kind: Kind {
        switch tool {
        case .eraser:
            return .eraser
        case .ink(let style):
            return style.width >= ToolbarPalette.markerWidth - 0.001 ? .marker : .pen
        }
    }

    private var penStyle: InkStyle {
        InkStyle(tool: .pen, colorHex: penColorHex, width: CGFloat(penWidth))
    }

    private var markerStyle: InkStyle {
        InkStyle(tool: .marker, colorHex: markerColorHex, width: ToolbarPalette.markerWidth)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Pieces

    private var toolButtons: some View {
        HStack(spacing: 4) {
            toolButton(.pen, symbol: "pencil.tip", label: "ペン") { tool = .ink(penStyle) }
            toolButton(.marker, symbol: "highlighter", label: "マーカー") { tool = .ink(markerStyle) }
            toolButton(.eraser, symbol: "eraser", label: "消しゴム") { tool = .eraser }
        }
    }

    private func toolButton(_ target: Kind, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        let selected = kind == target
        return Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 10))
            }
            .frame(width: 56, height: 44)
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var colorSwatches: some View {
        switch kind {
        case .pen:
            HStack(spacing: 6) {
                ForEach(ToolbarPalette.penColors, id: \.hex) { entry in
                    swatch(entry, selected: entry.hex == penColorHex) {
                        penColorHex = entry.hex
                        tool = .ink(penStyle)
                    }
                }
            }
        case .marker:
            HStack(spacing: 6) {
                ForEach(ToolbarPalette.markerColors, id: \.hex) { entry in
                    swatch(entry, selected: entry.hex == markerColorHex) {
                        markerColorHex = entry.hex
                        tool = .ink(markerStyle)
                    }
                }
            }
        case .eraser:
            Text("触れた線をまるごと消します")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 44)
        }
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
            .frame(width: 36, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var widthButtons: some View {
        HStack(spacing: 4) {
            ForEach(ToolbarPalette.penWidths, id: \.width) { entry in
                let selected = abs(Double(entry.width) - penWidth) < 0.001
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
                    }
                    .frame(width: 40, height: 44)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("太さ: \(entry.name)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var historyButtons: some View {
        HStack(spacing: 4) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .accessibilityLabel("元に戻す")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
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
        }
        .toggleStyle(.button)
        .accessibilityHint("オンにすると指でも線が引けます。オフのときは指でスクロールとタップをします")
    }
}

/// The toolbar's colours and widths (the web version's, js/ink/render.js and js/ui/toolbar.js).
enum ToolbarPalette {
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
