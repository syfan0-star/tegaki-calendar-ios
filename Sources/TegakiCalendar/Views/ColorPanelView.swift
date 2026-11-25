import SwiftUI
import UIKit

// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.4–§3.10, 0f-9–0f-17): the pen colours' panel. A tap on the lit dot of the toolbar
// (or a long press of it) opens a small panel of its own at that dot — not a popover (§3.4: a popover would take the first
// touch outside it, so the first stroke written while it is open would be lost, and it would count as one more thing
// presented) — with the twelve colours (`ToolbarPalette.panelColors`) on the paper's colour, 「その他の色…」 (the system's
// colour picker, a sheet of the screen's) and 「最初の色に戻す」. The pieces: the lit dot's frame (`ColorPanelAnchorKey`),
// the layer that lays the panel out and closes it when the dot moves or is gone (`ColorPanelHost`), the panel (`ColorPanelView`), what
// a choice writes (`ColorPanelStore`), the watcher that closes it on a touch outside (`ColorPanelWatch`), and the system's
// picker (`ColorPickerSheet`). The screen (`CalendarRootScreen.colorPanelLayer`) wires them.

/// The panel's words (§8.1): its spoken name and the lit dot's action 「ペンの色を選ぶ」, the lit dot's hint, and the two
/// buttons. Read once.
enum ColorPanelText {
    static let title = L.text("toolbar.colorPanel.title")
    static let hint = L.text("toolbar.colorPanel.hint")
    static let other = L.text("toolbar.colorPanel.otherColor")
    static let reset = L.text("toolbar.colorPanel.reset")
}

/// The identifiers of the panel (§3.10; the UI tests find it by them, never read out).
enum ColorPanelIdentifier {
    static let panel = "toolbar.colorPanel"
    static let other = "toolbar.colorPanel.other"
    static let reset = "toolbar.colorPanel.reset"

    /// A colour of the panel: `toolbar.colorPanel.<rrggbb>` (lower case, without the "#").
    static func color(_ hex: String) -> String {
        "toolbar.colorPanel." + (InkColors.normalized(hex) ?? hex.lowercased()).replacingOccurrences(of: "#", with: "")
    }
}

/// The lit dot's frame while its panel is open (`PenDotModifier`), for the screen's top layer (§3.4, §3.8): the dot sits in
/// the bar's ScrollView, which clips; the panel is drawn outside it. The last dot that gives one wins (a bar fading out
/// beside a new one: the new one is the later).
struct ColorPanelAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// What a choice writes (§3.7): the six dots (`toolbar.penSlots` in `ToolbarPalette.slotsStore`, only when they changed) and
/// the pen's colour (`toolbar.penColor`, as a dot of the bar writes it, screenshot mode too). The views' `@AppStorage`
/// follow. Returns the pen to write with: the chosen colour, the remembered width.
@MainActor
enum ColorPanelStore {
    /// The six dots as stored now.
    static func slots(_ store: UserDefaults = ToolbarPalette.slotsStore) -> [String] {
        ToolbarPalette.slots(stored: store.string(forKey: ToolbarPalette.penSlotsKey))
    }

    static func apply(_ choice: ColorPanelLogic.Choice, store: UserDefaults = ToolbarPalette.slotsStore,
                      defaults: UserDefaults = .standard) -> InkStyle {
        if slots(store) != choice.slots {
            store.set(ToolbarPalette.storedSlots(choice.slots), forKey: ToolbarPalette.penSlotsKey)
        }
        defaults.set(choice.pen, forKey: ToolbarPalette.penColorKey)
        let width = (defaults.object(forKey: ToolbarPalette.penWidthKey) as? NSNumber)?.doubleValue
        return ToolbarPalette.pen(colorHex: choice.pen, width: width, slots: choice.slots)
    }
}

/// The screen's top layer for the panel (§3.4, §3.6, §3.8): nothing while it is closed; open, the panel at
/// `ColorPanelLogic.placement` of the lit dot (`anchor`) on the bar's edge inside this layer (the screen inside its safe area),
/// the panel's and the dot's frames in the window's points handed to the watcher, and the panel closed when the lit dot moves
/// more than 1 pt from where it was when the panel opened (`closesOnAnchorMove`: the bar scrolled, turned or was made anew).
/// Never open with nothing drawn (D1b's review, nit 1): the panel also closes when the lit dot's frame is gone while it is
/// open (no dot lit any more: the pen's colour changed in another window, the bar made anew without it), and when no frame
/// has come 0.5 s after it opened (normally it comes the same turn or a frame or two later). The layer itself has nothing
/// to hit: only the panel takes touches.
struct ColorPanelHost: View {
    var anchor: Anchor<CGRect>?
    var openSlot: Binding<Int?>
    var edge: PaletteEdge
    var tool: Binding<CanvasTool>
    var watch: ColorPanelWatch
    var onOther: (Int) -> Void

    /// The lit dot's frame when the panel opened (this layer's points).
    @State private var opened: CGRect?

    var body: some View {
        GeometryReader { proxy in
            // No dot to stand at (none lit, or not laid out yet): nothing drawn, and the two modifiers below close the panel.
            // The screen closes it when the bar folds, moves or leaves the pen (`colorPanelLayer`).
            if let slot = openSlot.wrappedValue, let anchor {
                let dot = proxy[anchor]
                let frame = ColorPanelLogic.placement(anchor: dot, edge: edge, container: CGRect(origin: .zero, size: proxy.size),
                                                      panel: ColorPanelLogic.panelSize)
                let global = proxy.frame(in: .global).origin
                ColorPanelView(slot: slot, tool: tool, onClose: { close() }, onOther: { onOther(slot) })
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .onAppear {
                        opened = dot
                        note(panel: frame, dot: dot, global: global)
                    }
                    .onDisappear { opened = nil }
                    .onChange(of: dot) {
                        if let opened, ColorPanelLogic.closesOnAnchorMove(opened: opened, now: dot) {
                            close()
                        } else {
                            note(panel: frame, dot: dot, global: global)
                        }
                    }
            }
        }
        // The lit dot's frame gone while the panel is open: closed (after any other closing the slot is nil already, and
        // `close()` writes nothing).
        .onChange(of: anchor == nil) {
            if anchor == nil { close() }
        }
        // Open and no frame yet: closed if none has come 0.5 s later (a frame that comes ends the wait: the id changes).
        .task(id: waitsForTheDot) {
            guard waitsForTheDot else { return }
            try? await Task.sleep(for: .seconds(0.5))
            if !Task.isCancelled { close() }
        }
    }

    /// Open, and no lit dot's frame to stand at.
    private var waitsForTheDot: Bool {
        openSlot.wrappedValue != nil && anchor == nil
    }

    /// The watcher's frames, in the window's points (`.global`), the same turn the panel is laid out.
    private func note(panel: CGRect, dot: CGRect, global: CGPoint) {
        watch.panelFrame = panel.offsetBy(dx: global.x, dy: global.y)
        watch.litSwatchFrame = dot.offsetBy(dx: global.x, dy: global.y)
    }

    private func close() {
        if openSlot.wrappedValue != nil { openSlot.wrappedValue = nil }
    }
}

/// The panel (§3.4): the toolbar's material, 288 × 204; on top the twelve colours in 6 × 2 cells of 44 (28 pt dots, the lit
/// one with the bar's accent ring) on the paper's colour (light in dark mode too, as the ink is seen on the paper); under
/// them 「その他の色…」 and 「最初の色に戻す」, 44 tall each, one line down to 0.8 or two, at most xLarge. VoiceOver: one
/// container 「ペンの色を選ぶ」, modal, closed by the escape gesture, its focus on the pen's colour 0.3 s after it opens
/// (on 「その他の色…」 when the pen's colour is none of the twelve).
struct ColorPanelView: View {
    var slot: Int
    var tool: Binding<CanvasTool>
    var onClose: () -> Void
    var onOther: () -> Void

    @AppStorage(ToolbarPalette.penSlotsKey, store: ToolbarPalette.slotsStore) private var penSlotsRaw: String = ""
    @AppStorage(ToolbarPalette.penColorKey) private var penColorHex: String = ToolbarPalette.penColors[0].hex
    @AppStorage(ToolbarPalette.penWidthKey) private var penWidth: Double = Double(ToolbarPalette.penWidths[1].width)
    @AccessibilityFocusState private var focused: String?

    private var slots: [String] {
        ToolbarPalette.slots(stored: penSlotsRaw)
    }

    /// The pen as the bar lights it (`ToolbarView.penStyle`).
    private var pen: InkStyle {
        ToolbarPalette.pen(colorHex: penColorHex, width: penWidth, slots: slots)
    }

    var body: some View {
        VStack(spacing: 0) {
            grid
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider()
            row(ColorPanelText.other, identifier: ColorPanelIdentifier.other) {
                onOther()
            }
            Divider()
            row(ColorPanelText.reset, identifier: ColorPanelIdentifier.reset) {
                reset()
            }
        }
        .frame(width: ColorPanelLogic.panelSize.width, height: ColorPanelLogic.panelSize.height, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ColorPanelText.title)
        .accessibilityIdentifier(ColorPanelIdentifier.panel)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose() }
        .task {
            // Given in `onAppear`, the focus is often lost (the panel is not in the accessibility tree yet): a moment later.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            focused = ToolbarPalette.panelColors.contains { $0.hex == pen.colorHex } ? pen.colorHex : ColorPanelIdentifier.other
        }
    }

    /// The twelve on the paper's colour: the first six colours over the six added (§3.1).
    private var grid: some View {
        let colors = ToolbarPalette.panelColors
        let columns = ColorPanelLogic.columns
        return VStack(spacing: 0) {
            ForEach(0..<(colors.count / columns), id: \.self) { line in
                HStack(spacing: 0) {
                    ForEach(colors[(line * columns)..<((line + 1) * columns)], id: \.hex) { entry in
                        colorButton(entry)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: PaperPalette.paper))
        )
    }

    private func colorButton(_ entry: ToolbarPalette.Entry) -> some View {
        let selected = entry.hex == pen.colorHex
        return Button {
            choose(entry.hex)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: PaperPalette.color(hex: entry.hex)))
                    .frame(width: ColorPanelLogic.dotDiameter, height: ColorPanelLogic.dotDiameter)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.15)))
                if selected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .frame(width: ColorPanelLogic.dotDiameter + 8, height: ColorPanelLogic.dotDiameter + 8)
                }
            }
            .frame(width: ColorPanelLogic.cellSide, height: ColorPanelLogic.cellSide)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(ColorPanelIdentifier.color(entry.hex))
        .accessibilityFocused($focused, equals: entry.hex)
    }

    /// A button row: the text in the accent colour, centred, one line down to 0.8 or two, at most xLarge.
    private func row(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(Color.accentColor)
                .lineLimit(2)
                .minimumScaleFactor(ColorPanelLogic.rowTextMinScale)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ColorPanelLogic.rowTextInset)
                .frame(maxWidth: .infinity)
                .frame(height: ColorPanelLogic.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityFocused($focused, equals: identifier)
    }

    /// A colour of the panel (§3.7, `ColorPanelLogic.choose`): written, the pen takes it (its width kept), the panel closes.
    private func choose(_ hex: String) {
        let choice = ColorPanelLogic.choose(hex, slot: slot, slots: slots)
        tool.wrappedValue = .ink(ColorPanelStore.apply(choice))
        onClose()
    }

    /// 「最初の色に戻す」 (§3.7, `ColorPanelLogic.reset`): the six first colours, the pen the same dot's.
    private func reset() {
        let choice = ColorPanelLogic.reset(currentPen: pen.colorHex, slots: slots)
        tool.wrappedValue = .ink(ColorPanelStore.apply(choice))
        onClose()
    }
}

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.6, 0f-11): a touch outside the open panel closes it. A new instance of the frozen
/// `InkTouchObserver` (the file used as it is) on the screen's window while the panel is open (`attach` / `detach`, the
/// screen's `.onChange(of: colorPanelSlot)`), recognising with every other recogniser and never beginning (as `PalmWatch`):
/// it holds nothing up, so the stroke a Pencil or a finger begins on the paper is written, a button pressed works and the
/// paper moves. A touch coming down (the Pencil, a finger, a pointer) outside `panelFrame` and outside `litSwatchFrame` (both
/// in the window's points, given by `ColorPanelHost` the turn the panel is laid out) calls `onOutsideTouch` — once per attach.
/// A touch before the panel was laid out (its frame still `.zero`) closes nothing. The observer tells only that a touch came
/// down; where is read from it (`InkTouchObserver` is a `UIGestureRecognizer`): every touch it follows, each by its own
/// location (`location(ofTouch:in:)`), so a second finger is judged where it is and not at the touches' centre. All of
/// them began after the panel opened (a recogniser added later does not get the touches already down).
@MainActor
final class ColorPanelWatch {
    /// The screen closes the panel.
    var onOutsideTouch: () -> Void = {}
    /// The panel's and the lit dot's frames (the window's points).
    var panelFrame: CGRect = .zero
    var litSwatchFrame: CGRect?
    /// The watcher's window (nil while detached).
    private(set) weak var window: UIWindow?

    private let simultaneous = Simultaneous()
    private var observer: InkTouchObserver?
    /// `onOutsideTouch` was called since the last attach.
    private var fired = false

    var isAttached: Bool {
        observer != nil
    }

    /// The watcher on `window` (again only for another window, or after `detach`); armed for one close. The frames are kept
    /// (the panel may have been laid out first, the same turn).
    func attach(to window: UIWindow) {
        fired = false
        if observer != nil, window === self.window { return }
        removeObserver()
        self.window = window
        let observer = InkTouchObserver(target: nil, action: nil)
        observer.delegate = simultaneous
        observer.onChange = { [weak self, weak observer] change in
            guard let self, let observer, case .down = change, let window = self.window else { return }
            let count = observer.numberOfTouches
            let points = count > 0 ? (0..<count).map { observer.location(ofTouch: $0, in: window) } : [observer.location(in: window)]
            for point in points {
                self.touched(change, at: point)
            }
        }
        window.addGestureRecognizer(observer)
        self.observer = observer
    }

    /// The watcher off its window; its frames forgotten.
    func detach() {
        removeObserver()
        window = nil
        panelFrame = .zero
        litSwatchFrame = nil
    }

    private func removeObserver() {
        if let observer {
            observer.view?.removeGestureRecognizer(observer)
            self.observer = nil
        }
    }

    /// A touch changed at `point` (the window's points; internal: the tests stand in for UIKit with it, as `PalmWatch.touched`
    /// does). A touch coming down outside the panel and the lit dot closes the panel, once.
    func touched(_ change: InkTouchObserver.Change, at point: CGPoint) {
        guard case .down = change, !fired, panelFrame != .zero else { return }
        guard ColorPanelLogic.closesOnTouch(at: point, panel: panelFrame, litSwatch: litSwatchFrame) else { return }
        fired = true
        onOutsideTouch()
    }

    /// The watcher recognises alongside every recogniser (`PalmWatch`'s).
    private final class Simultaneous: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §3.7, 0f-13): 「その他の色…」's system colour picker (`UIColorPickerViewController`,
/// no alpha, no title of its own: the system's), in the screen's sheet. Its colour starts at the dot's (`initialHex`). A
/// colour is taken only when the picker says it is not still moving (`ColorPanelLogic.commitsPick`), turned into this app's
/// "#rrggbb" at once (the frozen `InkColors.hex(of:)`: resolved light, sRGB, clamped), and handed to `onPick`; a candidate
/// still moving when the picker closes is taken then. `onDone` follows every close — the picker's own ×
/// (`colorPickerViewControllerDidFinish`, which dismisses the sheet behind SwiftUI's back) and the sheet going away
/// (`dismantleUIViewController`) — once, so the screen's `colorPickerShown` never stays true.
struct ColorPickerSheet: UIViewControllerRepresentable {
    var initialHex: String
    var onPick: (String) -> Void
    var onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = InkColors.color(hex: initialHex) ?? .black
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIViewController(_ picker: UIColorPickerViewController, coordinator: Coordinator) {
        // The view is going away inside SwiftUI's update: the screen hears of it on the next turn.
        Task { @MainActor in coordinator.finish() }
    }

    @MainActor
    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var parent: ColorPickerSheet
        /// The last colour the picker gave while still moving, not taken yet.
        private(set) var pending: String?
        private(set) var finished = false

        init(_ parent: ColorPickerSheet) {
            self.parent = parent
        }

        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            picked(InkColors.hex(of: color), continuously: continuously)
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            finish()
        }

        /// A colour from the picker (internal: the tests stand in for UIKit with it).
        func picked(_ hex: String?, continuously: Bool) {
            guard let hex, !finished else { return }
            if ColorPanelLogic.commitsPick(continuously: continuously) {
                pending = nil
                parent.onPick(hex)
            } else {
                pending = hex
            }
        }

        /// The picker closed: a candidate still moving is taken, then `onDone`; once.
        func finish() {
            guard !finished else { return }
            finished = true
            if let pending {
                self.pending = nil
                parent.onPick(pending)
            }
            parent.onDone()
        }
    }
}
