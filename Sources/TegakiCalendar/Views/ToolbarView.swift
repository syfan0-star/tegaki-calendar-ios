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
/// fade out; every iPhone and every iPad window at least 334 pt wide shows at least what 1.0.1
/// showed (in a narrower iPad window the end of 「予定」 fades, and at 320 pt its last 1 pt is cut).
/// The height is unchanged (44 + 8 + 8).
///
/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.8, 0e-19): `axis`. `.horizontal`, the default, is the bar above, its code
/// path and its callers unchanged. `.vertical` is the bar of a left or right placement: a 60 pt column (6 + 48 + 6) as
/// tall as its slot, the same material, corners and shadow; a ScrollView from the top with the tools, the colours as
/// 44 × 38 swatches, 細中太 (the pen only), ↶ ↷ and an icon-only 「指でも書く」, its last 12 pt fading out; 「しまう」 under a
/// divider outside the scroll. The eraser's, the lasso's and the 予定 tool's hint lines are not drawn there: they are
/// those tool buttons' VoiceOver hints. Every identifier is the same (`tool.pen`).
///
/// 1.4.1's second rework (docs/R1_4_1_CONTRACT.md §17.2): `move`, a 「動かす」 button just before 「しまう」, outside the scroll
/// after the same divider ([row | divider | 動かす | しまう] across, the same one under the other upright), with 「しまう」's face
/// (`buttonFace`: `arrow.up.and.down.and.arrow.left.and.right` over 「動かす」, 48 wide, 44 tall, nothing between the two): the
/// row is 48 pt narrower (the upright column 44 pt shorter), the bar's height the same. `PaletteMoveButtonView` lies over the
/// face and takes its touches (a tap opens the choice of edges, the `confirmationDialog` here; on the open bar a drag is the
/// grip's, on a peek it is a tap only: `drags`, §18.2) and is its one VoiceOver element. nil, the default, is the bar before
/// it: the screen passes it where `ToolbarLogic.showsMoveButton` allows, the open bar and (§18.2) the peek (every iPhone keeps 1.4's bar).
///
/// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.2–§3.10, 0f-7–0f-17, 0f-36): the pen's six dots are the dots of this device
/// (`toolbar.penSlots`, `ToolbarPalette.slots(stored:)`; the first six colours until the panel changes one), by their index
/// (`toolbar.swatch.<0…5>`, across and upright). `colorPanel` (nil, the default: 1.4.1's bar, a press of the lit dot chooses it
/// again) is the screen's panel: a tap on the lit dot, or a long press of it, opens the panel at it (`ColorPanelLogic.tap`,
/// `longPress`; `ColorPanelAnchorKey` carries the lit dot's frame to the screen), a tap on it again closes it, any other dot
/// is chosen as before. In dark mode the dots' rims are white at 0.35 (light: 1.4.1's black at 0.15, the same code).
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
    /// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.5, 0f-36): the screen's pen colour panel; nil = none (1.4.1's dots). Declared
    /// before `axis`, so a caller passes it before `axis:` (the memberwise init's order).
    var colorPanel: ColorPanelHook? = nil
    /// 1.4.1 (docs/R1_4_1_CONTRACT.md §4.8): `.vertical` for a bar on the left or the right edge.
    var axis: Axis = .horizontal
    /// 1.4.1's second rework (§17.2, §18.2): the 「動かす」 button before 「しまう」 (the open bar's and a peek's); nil = none, the bar of before.
    var move: PaletteMoveButtonView? = nil

    @AppStorage(ToolbarPalette.penColorKey) private var penColorHex: String = ToolbarPalette.penColors[0].hex
    // Double, not CGFloat: AppStorage only stores Double (CGFloat is a distinct type on 64-bit).
    @AppStorage(ToolbarPalette.penWidthKey) private var penWidth: Double = Double(ToolbarPalette.penWidths[1].width)
    @AppStorage(ToolbarPalette.markerColorKey) private var markerColorHex: String = ToolbarPalette.markerColors[0].hex
    /// 1.4.2 (§3.2, §3.11): the six dots (`ToolbarPalette.slots(stored:)`); in screenshot mode a scratch store emptied at every
    /// launch (`ToolbarPalette.slotsStore`), so neither a photo nor a UI test reads or writes this device's.
    @AppStorage(ToolbarPalette.penSlotsKey, store: ToolbarPalette.slotsStore) private var penSlotsRaw: String = ""
    /// 1.4.2 (§3.9, 0f-16): the dots' rims follow it (dark only).
    @Environment(\.colorScheme) private var colorScheme
    /// 1.4.2 (§3.5): the dot a long press just acted on, and when: the lift that ends that press (the button's own tap) is
    /// not taken as a second press (`ToolbarPalette.swallowWindow`).
    @State private var longPressed: (slot: Int, at: Date)?

    /// The six dots (§3.2).
    private var slots: [String] {
        ToolbarPalette.slots(stored: penSlotsRaw)
    }

    /// The lit dot: the one with the pen's colour (one at most: the dots never repeat).
    private var litSlot: Int? {
        slots.firstIndex(of: penStyle.colorHex)
    }

    private var kind: ToolKind {
        ToolbarLogic.kind(of: tool)
    }

    /// The remembered pen, checked against the tables exactly like the pen the app starts with
    /// (`ToolbarPalette.rememberedPen`, 0-13), so the lit swatch and width are the starting pen's.
    private var penStyle: InkStyle {
        ToolbarPalette.pen(colorHex: penColorHex, width: penWidth, slots: slots)
    }

    private var markerStyle: InkStyle {
        InkStyle(tool: .marker, colorHex: markerColorHex, width: ToolbarPalette.markerWidth)
    }

    var body: some View {
        Group {
            if axis == .vertical {
                verticalBar
            } else {
                horizontalBar
            }
        }
        // 1.4.2 (§3.5): the panel closed: a long press's lift that never came as a tap (the finger left the dot) is forgotten,
        // unless the press itself just closed it (its lift is still to come).
        .onChange(of: colorPanel?.openSlot.wrappedValue == nil) {
            if colorPanel?.openSlot.wrappedValue == nil, let pressed = longPressed,
               Date().timeIntervalSince(pressed.at) > ToolbarPalette.swallowKeptAfterClose {
                longPressed = nil
            }
        }
    }

    /// The bar of 1.4 (`axis` `.horizontal`).
    private var horizontalBar: some View {
        bar
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The scrolling row, with the 「しまう」 button outside it at the right end when asked for (§2.2). 1.4.1's second rework
    /// (§17.2): `move`'s 「動かす」 between the divider and 「しまう」, the divider's 4 pt before it and nothing after it.
    @ViewBuilder
    private var bar: some View {
        if showsCollapseButton {
            HStack(spacing: 0) {
                scrollingRow
                Divider().frame(height: 24)
                if let move {
                    moveButton(move)
                        .padding(.leading, ToolbarLogic.Row.collapseLeading)
                }
                collapseButton
                    .padding(.leading, move == nil ? ToolbarLogic.Row.collapseLeading : 0)
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
            rowLabel(label)
        }
        .padding(.horizontal, ToolbarLogic.Row.labelInset)
        .frame(minWidth: ToolbarLogic.Row.buttonMinWidth)
        .frame(height: 44)
    }

    /// The 10 pt name under a tool, 「しまう」 and 細中太 (F-12, docs/M7B_CONTRACT.md §4.4): Japanese as in 1.1
    /// (the name sets the button's width); every other language in a fixed 38 pt frame, shrinking to
    /// 0.8, so the button never widens and the row keeps what 1.1 showed.
    @ViewBuilder
    private func rowLabel(_ label: String) -> some View {
        if let width = ToolbarLogic.Row.labelFrameWidth(for: L.language) {
            Text(label)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(ToolbarLogic.Row.labelMinScale)
                .frame(width: width)
        } else {
            Text(label)
                .font(.system(size: 10))
                .lineLimit(1)
        }
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

    /// 1.4.1's second rework (§17.2): 「動かす」 with 「しまう」's face, `PaletteMoveButtonView` over it (the touches and the one
    /// VoiceOver element; the face is hidden from VoiceOver), and the choice of edges it opens: a `confirmationDialog` from
    /// the button (a popover on an iPad) titled 「ツールバーを動かす」, one button per choice (「上へ移す」…), each calling
    /// `move.onMove` (the screen's VoiceOver path, which ignores an edge no longer allowed) and then telling VoiceOver the
    /// screen changed, as the 「…へ移す」 actions do (`PaletteGripView.PanView.postLayoutChanged`, §4.11).
    private func moveButton(_ move: PaletteMoveButtonView) -> some View {
        buttonFace(symbol: PaletteMoveButtonView.symbol, label: ToolbarLogic.moveTitle)
            .foregroundStyle(Color.primary)
            .accessibilityHidden(true)
            .overlay { move }
            .confirmationDialog(ToolbarLogic.gripAccessibilityLabel, isPresented: move.menuShown, titleVisibility: .visible) {
                ForEach(move.choices, id: \.self) { edge in
                    Button(ToolbarLogic.moveToTitle(edge)) {
                        move.onMove(edge)
                        PaletteGripView.PanView.postLayoutChanged()
                    }
                }
            }
    }

    private var toolButtons: some View {
        HStack(spacing: 0) {
            toolButton(.pen, symbol: "pencil.tip", label: L.text("toolbar.tool.pen")) { tool = .ink(penStyle) }
                .accessibilityIdentifier("tool.pen")
            toolButton(.marker, symbol: "highlighter", label: L.text("toolbar.tool.marker")) { tool = .ink(markerStyle) }
            toolButton(.eraser, symbol: "eraser", label: L.text("toolbar.tool.eraser")) { tool = .eraser }
            toolButton(.lasso, symbol: "lasso", label: L.text("toolbar.tool.lasso")) { tool = .lasso }
            toolButton(.eventRect, symbol: "calendar.badge.plus", label: L.text("toolbar.tool.event")) { tool = .eventRect }
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
                // 1.4.2 (§3.2, 0f-7): by the dot's index (a colour may move between dots; `id: \.hex` could collide).
                ForEach(Array(slots.enumerated()), id: \.offset) { slot, hex in
                    swatch(penEntry(hex), selected: slot == litSlot) {
                        penDotTapped(slot)
                    }
                    .modifier(penDot(slot))
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
    /// 44 pt row (xxLarge's 16 pt would need about 43 — too close to 44 with the device's fonts).
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
                    .overlay(Circle().strokeBorder(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.15)))
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

    // MARK: - The pen's dots and the colour panel (1.4.2, docs/R1_4_2_CONTRACT.md §3.5, §3.10)

    /// A dot's colour and its name (the panel's twelve, the marker's, else 「その他の色」).
    private func penEntry(_ hex: String) -> ToolbarPalette.Entry {
        ToolbarPalette.Entry(hex: hex, name: ToolbarPalette.colorName(hex))
    }

    /// What every pen dot carries beside its button (`PenDotModifier`): its identifier, the long press, the panel's
    /// VoiceOver action and the lit dot's hint, and the lit dot's frame for the panel while its panel is open.
    private func penDot(_ slot: Int) -> PenDotModifier {
        let lit = slot == litSlot
        return PenDotModifier(slot: slot, lit: lit, hasPanel: colorPanel != nil,
                              anchored: lit && colorPanel?.openSlot.wrappedValue == slot,
                              onLongPress: { penDotLongPressed(slot) },
                              onPanelAction: { penDotPanelAction(slot) })
    }

    /// A tap on dot `slot` (§3.5): without a panel 1.4.1's (the dot is chosen); with one `ColorPanelLogic.tap`. The lift that
    /// ends a long press of the same dot is not a tap.
    private func penDotTapped(_ slot: Int) {
        if let pressed = longPressed {
            longPressed = nil
            if pressed.slot == slot, Date().timeIntervalSince(pressed.at) < ToolbarPalette.swallowWindow { return }
        }
        guard let colorPanel else {
            perform(.select(slot))
            return
        }
        perform(ColorPanelLogic.tap(slot: slot, lit: litSlot, openSlot: colorPanel.openSlot.wrappedValue))
    }

    /// A long press (0.5 s) on dot `slot` (§3.5): `ColorPanelLogic.longPress`; nothing without a panel (its lift is then the
    /// tap of 1.4.1).
    private func penDotLongPressed(_ slot: Int) {
        guard let colorPanel else { return }
        let action = ColorPanelLogic.longPress(slot: slot, lit: litSlot, openSlot: colorPanel.openSlot.wrappedValue)
        longPressed = (slot: slot, at: Date())
        perform(action)
    }

    /// VoiceOver's 「ペンの色を選ぶ」 on dot `slot` (§3.5, §3.10): that dot chosen, then its panel opened.
    private func penDotPanelAction(_ slot: Int) {
        guard let colorPanel else { return }
        if slot != litSlot { perform(.select(slot)) }
        colorPanel.openSlot.wrappedValue = slot
    }

    private func perform(_ action: ColorPanelLogic.SwatchAction) {
        switch action {
        case .select(let slot):
            if colorPanel?.openSlot.wrappedValue != nil { colorPanel?.openSlot.wrappedValue = nil }
            guard slots.indices.contains(slot) else { return }
            penColorHex = slots[slot]
            tool = .ink(penStyle)
        case .open(let slot):
            colorPanel?.openSlot.wrappedValue = slot
        case .close:
            colorPanel?.openSlot.wrappedValue = nil
        case .none:
            break
        }
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
                        rowLabel(entry.name)
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
                .accessibilityLabel(L.format("toolbar.width.spoken", entry.name))
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
            .accessibilityLabel(L.text("toolbar.undo"))

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: ToolbarLogic.Row.historyButtonWidth, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRedo)
            .accessibilityLabel(L.text("toolbar.redo"))
        }
    }

    private var fingerToggle: some View {
        Toggle(isOn: $allowFinger) {
            Label(L.text("toolbar.fingerToggle"), systemImage: "hand.draw")
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .toggleStyle(.button)
        .accessibilityHint(L.text("toolbar.fingerToggle.hint"))
    }

    // MARK: - The vertical bar (1.4.1, docs/R1_4_1_CONTRACT.md §4.8, 0e-19)

    /// The column of a side placement: 60 pt wide (the 6 on each side outside the ScrollView, §4.5), as tall as the slot
    /// offers; the scrolling column from the top, then 「しまう」 under a divider, outside the scroll (as the row's). 1.4.1's
    /// second rework (§17.2): `move`'s 「動かす」 between the divider and 「しまう」, as across.
    private var verticalBar: some View {
        VStack(spacing: 0) {
            scrollingColumn
            if showsCollapseButton {
                Divider().frame(width: ToolbarLogic.Column.dividerLength)
                if let move {
                    moveButton(move)
                        .frame(width: ToolbarLogic.Column.width)
                        .padding(.top, ToolbarLogic.Row.collapseLeading)
                }
                collapseButton
                    .frame(width: ToolbarLogic.Column.width)
                    .padding(.top, move == nil ? ToolbarLogic.Row.collapseLeading : 0)
                    .padding(.bottom, ToolbarLogic.Row.collapseTrailing)
            }
        }
        .padding(.horizontal, ToolbarLogic.Column.sidePadding)
        .frame(width: ToolbarLogic.verticalBarWidth)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    /// The row's pieces one under the other: the tools, the colours (pen and marker), 細中太 (the pen), ↶ ↷ and
    /// 「指でも書く」, with the row's paddings turned (8 above, 14 under) and its 12 pt fade at the end.
    private var scrollingColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ToolbarLogic.Row.groupSpacing) {
                verticalToolButtons
                if kind == .pen || kind == .marker {
                    Divider().frame(width: ToolbarLogic.Column.dividerLength)
                    verticalColorSwatches
                }
                if kind == .pen {
                    Divider().frame(width: ToolbarLogic.Column.dividerLength)
                    verticalWidthButtons
                }
                Divider().frame(width: ToolbarLogic.Column.dividerLength)
                verticalHistoryButtons
                Divider().frame(width: ToolbarLogic.Column.dividerLength)
                verticalFingerToggle
            }
            .frame(width: ToolbarLogic.Column.width)
            .padding(.top, ToolbarLogic.Row.paddingLeading)
            .padding(.bottom, ToolbarLogic.Row.paddingTrailing)
        }
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: ToolbarLogic.Row.fadeWidth)
            }
        }
    }

    /// The five tools with the row's faces (48 × 44, F-12's names). The hint lines the row shows for the eraser, the
    /// lasso and the 予定 tool are those buttons' VoiceOver hints here (the same strings; a line break reads as a pause).
    private var verticalToolButtons: some View {
        VStack(spacing: 0) {
            toolButton(.pen, symbol: "pencil.tip", label: L.text("toolbar.tool.pen")) { tool = .ink(penStyle) }
                .accessibilityIdentifier("tool.pen")
            toolButton(.marker, symbol: "highlighter", label: L.text("toolbar.tool.marker")) { tool = .ink(markerStyle) }
            toolButton(.eraser, symbol: "eraser", label: L.text("toolbar.tool.eraser")) { tool = .eraser }
                .accessibilityHint(ToolbarLogic.eraserBarHint(returnsTo: eraserReturnsTo))
            toolButton(.lasso, symbol: "lasso", label: L.text("toolbar.tool.lasso")) { tool = .lasso }
                .accessibilityHint(ToolbarLogic.lassoBarHint)
            toolButton(.eventRect, symbol: "calendar.badge.plus", label: L.text("toolbar.tool.event")) { tool = .eventRect }
                .accessibilityHint(ToolbarLogic.eventBarHint)
        }
        .frame(width: ToolbarLogic.Column.width)
    }

    /// The pen's six colours or the marker's four, as 44 × 38 swatches (nothing for the other tools).
    @ViewBuilder
    private var verticalColorSwatches: some View {
        switch kind {
        case .pen:
            VStack(spacing: 0) {
                // 1.4.2 (§3.2, §3.8): the same dots, presses and identifiers as across.
                ForEach(Array(slots.enumerated()), id: \.offset) { slot, hex in
                    verticalSwatch(penEntry(hex), selected: slot == litSlot) {
                        penDotTapped(slot)
                    }
                    .modifier(penDot(slot))
                }
            }
        case .marker:
            VStack(spacing: 0) {
                ForEach(ToolbarPalette.markerColors, id: \.hex) { entry in
                    verticalSwatch(entry, selected: entry.hex == markerColorHex) {
                        markerColorHex = entry.hex
                        tool = .ink(markerStyle)
                    }
                }
            }
        case .eraser, .lasso, .eventRect:
            EmptyView()
        }
    }

    /// The row's swatch (`swatch`) in a 44 × 38 cell.
    private func verticalSwatch(_ entry: ToolbarPalette.Entry, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: PaperPalette.color(hex: entry.hex)))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.15)))
                if selected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: ToolbarLogic.Column.swatchWidth, height: ToolbarLogic.Column.swatchHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 細中太 one under the other: the row's faces (`widthButtons`) as wide as the column, 44 tall.
    private var verticalWidthButtons: some View {
        VStack(spacing: 0) {
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
                        rowLabel(entry.name)
                    }
                    .frame(width: ToolbarLogic.Column.width, height: ToolbarLogic.Column.cellSide)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.format("toolbar.width.spoken", entry.name))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// ↶ over ↷, 44 × 44 each.
    private var verticalHistoryButtons: some View {
        VStack(spacing: 0) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: ToolbarLogic.Column.cellSide, height: ToolbarLogic.Column.cellSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .accessibilityLabel(L.text("toolbar.undo"))

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: ToolbarLogic.Column.cellSide, height: ToolbarLogic.Column.cellSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRedo)
            .accessibilityLabel(L.text("toolbar.redo"))
        }
    }

    /// 「指でも書く」 as its `hand.draw` mark only, 44 × 44, lit like a chosen tool while on. The Toggle's name (the
    /// label's title, read by VoiceOver and the UI tests) and its hint are the row's.
    private var verticalFingerToggle: some View {
        Toggle(isOn: $allowFinger) {
            Label(L.text("toolbar.fingerToggle"), systemImage: "hand.draw")
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .medium))
                .frame(width: ToolbarLogic.Column.cellSide, height: ToolbarLogic.Column.cellSide)
                .foregroundStyle(allowFinger ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(allowFinger ? Color.accentColor.opacity(0.14) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .accessibilityHint(L.text("toolbar.fingerToggle.hint"))
    }
}

/// The toolbar's colours and widths (the web version's, js/ink/render.js and js/ui/toolbar.js).
enum ToolbarPalette {
    /// The remembered pen / marker (UserDefaults, per device). `rememberedPen` reads the first two.
    static let penColorKey = "toolbar.penColor"
    static let penWidthKey = "toolbar.penWidth"
    static let markerColorKey = "toolbar.markerColor"
    /// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.2, 0f-7): the six dots of this device (UserDefaults, CA92.1; never iCloud, an
    /// export or a PDF): six "#rrggbb" joined by "," (`storedSlots`), written only when the panel changes a dot or 「最初の色に
    /// 戻す」 puts them back. None: the first six colours (`slots(stored:)`).
    static let penSlotsKey = "toolbar.penSlots"

    struct Entry: Hashable {
        var hex: String
        var name: String
    }

    struct Width: Hashable {
        var width: CGFloat
        var name: String
    }

    static let penColors: [Entry] = [
        Entry(hex: "#1f2937", name: L.text("toolbar.color.black")),
        Entry(hex: "#2563eb", name: L.text("toolbar.color.blue")),
        Entry(hex: "#dc2626", name: L.text("toolbar.color.red")),
        Entry(hex: "#16a34a", name: L.text("toolbar.color.green")),
        Entry(hex: "#ea580c", name: L.text("toolbar.color.orange")),
        Entry(hex: "#7c3aed", name: L.text("toolbar.color.purple")),
    ]

    static let markerColors: [Entry] = [
        Entry(hex: "#fde047", name: L.text("toolbar.color.yellow")),
        Entry(hex: "#f9a8d4", name: L.text("toolbar.color.pink")),
        Entry(hex: "#86efac", name: L.text("toolbar.color.green")),
        Entry(hex: "#93c5fd", name: L.text("toolbar.color.lightBlue")),
    ]

    /// Pen widths in lu (DESIGN §3.6: 細 2 / 中 3.5 / 太 6).
    static let penWidths: [Width] = [
        Width(width: 2, name: L.text("toolbar.width.thin")),
        Width(width: 3.5, name: L.text("toolbar.width.medium")),
        Width(width: 6, name: L.text("toolbar.width.thick")),
    ]

    /// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.1, 0f-6): the panel's twelve — `penColors`' six, then 茶・グレー・ピンク・水色・深緑・紺
    /// (ピンク and 水色 by the marker's names). The names are read once, as above.
    static let panelColors: [Entry] = penColors + [
        Entry(hex: "#92400e", name: L.text("toolbar.color.brown")),
        Entry(hex: "#6b7280", name: L.text("toolbar.color.gray")),
        Entry(hex: "#db2777", name: L.text("toolbar.color.pink")),
        Entry(hex: "#0284c7", name: L.text("toolbar.color.lightBlue")),
        Entry(hex: "#166534", name: L.text("toolbar.color.darkGreen")),
        Entry(hex: "#1e40af", name: L.text("toolbar.color.navy")),
    ]

    /// 1.4.2 (§3.10): a pen dot's identifier, `toolbar.swatch.<0…5>` (across and upright; never read out).
    static func swatchIdentifier(_ slot: Int) -> String {
        "toolbar.swatch.\(slot)"
    }

    /// 1.4.2 (§3.5): how long after a long press the lift of that press (the button's own tap on the same dot) is not a tap; and
    /// how old that long press must be for the panel's closing to forget it.
    static let swallowWindow: TimeInterval = 10
    static let swallowKeptAfterClose: TimeInterval = 0.6

    /// 1.4.2 (§3.11, 0f-18): the store of the six dots: this device's (`.standard`) in normal use; in screenshot mode a scratch
    /// suite emptied at every launch, holding `--screenshot-pen-slots` (or nothing: the first six colours), so a photo or a UI
    /// test never reads or writes `toolbar.penSlots` of the simulator and none leaks into the next (`toolbar.penColor` is
    /// written as before). Decided once, at its first read (the views' `@AppStorage`).
    static let slotsStore: UserDefaults = penSlotsStore(shot: ScreenshotMode.current)

    /// The scratch suite's name (screenshot mode's dots).
    static let screenshotSlotsSuite = "tegaki.screenshot.penSlots"

    /// `slotsStore` for `shot` (the tests pass their own suites): nil, `standard`; else the suite `suiteName`, emptied, with
    /// `shot.penSlots` written in it when the argument was given.
    static func penSlotsStore(shot: ScreenshotMode.Config?, standard: UserDefaults = .standard,
                              suiteName: String = screenshotSlotsSuite) -> UserDefaults {
        guard let shot else { return standard }
        guard let scratch = UserDefaults(suiteName: suiteName) ?? UserDefaults(suiteName: screenshotSlotsSuite) else { return standard }
        scratch.removePersistentDomain(forName: suiteName)
        if let slots = shot.penSlots {
            scratch.set(storedSlots(slots), forKey: penSlotsKey)
        }
        return scratch
    }

    /// Marker width in lu.
    static let markerWidth: CGFloat = 18

    /// The pen the app starts with (黒・中).
    static var defaultPen: InkStyle {
        InkStyle(tool: .pen, colorHex: penColors[0].hex, width: penWidths[1].width)
    }
}

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.5, 0f-36): the screen's pen colour panel as `ToolbarView` sees it: the dot whose
/// panel is open (nil: closed). The screen lays the panel out (`ColorPanelHost`) at the lit dot's frame (`ColorPanelAnchorKey`).
struct ColorPanelHook {
    var openSlot: Binding<Int?>
}

/// 1.4.2 (§3.5, §3.10): what a pen dot carries beside its button: `toolbar.swatch.<i>`; a long press (0.5 s, alongside the
/// button and the bar's scroll) where the screen has a panel; VoiceOver's action 「ペンの色を選ぶ」 on every dot and the hint
/// 「もう一度押すと、色を替えられます」 on the lit one (with a panel only); and, while its panel is open, the lit dot's frame
/// (`ColorPanelAnchorKey`).
struct PenDotModifier: ViewModifier {
    let slot: Int
    let lit: Bool
    let hasPanel: Bool
    let anchored: Bool
    let onLongPress: () -> Void
    let onPanelAction: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(ToolbarPalette.swatchIdentifier(slot))
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() }, including: hasPanel ? .all : .subviews)
            .accessibilityHint(hasPanel && lit ? Text(ColorPanelText.hint) : Text(verbatim: ""))
            .accessibilityAction(named: Text(ColorPanelText.title)) {
                if hasPanel { onPanelAction() }
            }
            .anchorPreference(key: ColorPanelAnchorKey.self, value: .bounds) { anchored ? $0 : nil }
    }
}
