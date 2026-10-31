import CoreGraphics
import Foundation

// 1.1 (docs/M7A_CONTRACT.md §2, D1 / D2): the toolbar's three states, the eraser's return to the
// last pen, the mark of the round dock button and the paddings that depend on the state. Everything
// here is pure (no SwiftUI) so `ToolbarLogicTests` can check it; `ToolbarView`, `ToolbarDock` and
// `CalendarRootScreen` only read it.

/// The three states of the toolbar (§2.1). `expanded` is today's bar in the bottom safe-area inset
/// (it pushes the paper up by 66 pt) plus the 「しまう」 button; `collapsed` is the round dock button
/// in a bottom corner; `peek` is the bar laid *over* the paper after a tap on the dock button — it
/// never changes the paper area (a 66 pt change would re-zoom the overviews that fit the height,
/// `ZoomPolicy.fitAll`, under the pen) and folds away as soon as a pen or a drawing finger touches the
/// paper. Only `toolbar.collapsed` is remembered (per device); `peek` is never stored.
enum ToolbarMode: String, Equatable, Sendable {
    case expanded, collapsed, peek
}

/// The bottom corner of the dock button (`toolbar.collapsedEdge`, default leading = bottom left).
enum ToolbarEdge: String, Equatable, Sendable {
    case leading, trailing

    /// The stored value: "leading" / "trailing"; nil or anything else is `.leading` (§2.3).
    init(stored raw: String?) {
        self = raw.flatMap(ToolbarEdge.init(rawValue:)) ?? .leading
    }

    /// The other bottom corner (the dock's 「右下へ移す」 / 「左下へ移す」).
    var opposite: ToolbarEdge {
        self == .leading ? .trailing : .leading
    }
}

/// Where the current eraser came from (§2.4): the toolbar's eraser returns to the last pen after it
/// erased something; the Apple Pencil's double tap / squeeze keeps toggling as before.
enum EraserOrigin: Equatable, Sendable {
    case toolbar, pencil
}

/// The toolbar's idea of a tool (moved from `ToolbarView.Kind`, 1.0 `ToolbarView.swift:25-40`).
enum ToolKind: Equatable, Sendable {
    case pen, marker, eraser, lasso, eventRect
}

/// The mark of the dock button for one tool (§2.2). A pen is a filled dot (`colorHex`,
/// `dotDiameter`); a marker is the `highlighter` symbol over a bar of its colour (`symbol` and
/// `colorHex`); the eraser, the lasso and the 予定 tool are their symbols. `accessibilityValue` is
/// what VoiceOver reads after 「ツールバーを出す」 (「ペン・赤・太」).
struct ToolBadge: Equatable {
    var symbol: String?
    var colorHex: String?
    var dotDiameter: CGFloat?
    var accessibilityValue: String
}

/// What happened to the toolbar, one per row of the table in §2.1 (`ToolbarLogic.step`).
enum ToolbarEvent: Equatable, Sendable {
    /// The 「しまう」 button at the right end of the bar (expanded or peek).
    case collapseTapped
    /// `InkCanvasView.onPenDown`: a pen or a drawing finger touched the paper (any tool).
    case penDown
    /// The tool mark of the dock button.
    case dockToolTapped
    /// The ↶ of the dock button (undo only; the mode does not change).
    case dockUndoTapped
    /// `scenePhase == .background`.
    case wentToBackground
    /// The dock's long-press menu 「ツールバーをいつも出す」.
    case pinChosen
    /// The dock's long-press menu 「右下へ移す」 / 「左下へ移す」.
    case moveEdgeChosen
    /// Read only, rotation, a width change, another page: nothing changes.
    case other
}

/// The result of one event (§2.1): the next mode, the new value of `toolbar.collapsed` (nil = do not
/// write it) and whether `toolbar.collapsedEdge` moves to the other corner.
struct ToolbarStep: Equatable, Sendable {
    var mode: ToolbarMode
    var storeCollapsed: Bool?
    var flipsEdge: Bool

    init(mode: ToolbarMode, storeCollapsed: Bool? = nil, flipsEdge: Bool = false) {
        self.mode = mode
        self.storeCollapsed = storeCollapsed
        self.flipsEdge = flipsEdge
    }
}

enum ToolbarLogic {
    /// The expanded bar: a 44 pt row with 8 pt above and below.
    static let barHeight: CGFloat = 60
    /// The dock button's capsule: 44 pt buttons inside a 2 pt padding.
    static let pillHeight: CGFloat = 48
    /// The horizontal padding of the bar and the dock (`CalendarRootScreen`).
    static let sidePadding: CGFloat = 12
    /// The padding under the bar and the dock, above the bottom safe area.
    static let bottomPadding: CGFloat = 6
    /// The capsule of the dock button: 2 + 44 + 4 + 44 + 2.
    static let pillWidth: CGFloat = 96
    /// The toast's gap above whatever is at the bottom (1.0: 8 pt above the bar).
    static let toastGap: CGFloat = 8
    /// The space kept free above the bottom of the paper while the dock is shown: 48 + 6 + 6.
    static let dockClearance: CGFloat = pillHeight + bottomPadding + 6
    /// The diameter of a pen's dot on the dock button for 細 / 中 / 太 (`ToolbarPalette.penWidths`).
    static let penDotDiameters: [CGFloat] = [10, 14, 18]

    // MARK: Texts (§6.2, fixed)

    static let collapseTitle = "しまう"
    static let collapseAccessibilityLabel = "ツールバーをしまう"
    static let dockAccessibilityLabel = "ツールバーを出す"
    static let pinTitle = "ツールバーをいつも出す"
    static let eraserHintText = "触れた線をまるごと消します"

    /// The dock's menu item that moves it to the other bottom corner.
    static func moveEdgeTitle(from edge: ToolbarEdge) -> String {
        edge == .leading ? "右下へ移す" : "左下へ移す"
    }

    /// The SF Symbol of that menu item.
    static func moveEdgeSymbol(from edge: ToolbarEdge) -> String {
        edge == .leading ? "arrow.right.to.line" : "arrow.left.to.line"
    }

    /// The VoiceOver hint of the dock's tool mark.
    static func dockAccessibilityHint(edge: ToolbarEdge) -> String {
        "長押しで、\(moveEdgeTitle(from: edge))か、ツールバーをいつも出すかを選べます"
    }

    // MARK: Tools

    /// The toolbar's kind of a tool: an ink at least as wide as the marker is the marker (the width
    /// decides, not `InkStyle.tool`; 1.0 `ToolbarView.kind`).
    static func kind(of tool: CanvasTool) -> ToolKind {
        switch tool {
        case .eraser:
            return .eraser
        case .lasso:
            return .lasso
        case .eventRect:
            return .eventRect
        case .ink(let style):
            return style.width >= ToolbarPalette.markerWidth - 0.001 ? .marker : .pen
        }
    }

    /// The tool after an eraser stroke settled (§2.4, D2): the last pen or marker when the current
    /// tool is still the eraser, the eraser was chosen on the toolbar, at least one stroke was erased
    /// and the setting 「消しゴムで消したらペンに戻る」 is on; nil = leave the tool alone (also when
    /// the person picked another tool during the settle delay).
    static func toolAfterErase(origin: EraserOrigin?, erased: Int, setting: Bool,
                               current: CanvasTool, lastInk: CanvasTool) -> CanvasTool? {
        current.isEraser && origin == .toolbar && erased > 0 && setting ? lastInk : nil
    }

    /// The eraser's hint in the bar (§6.2): 「触れた線をまるごと消します」 plus
    /// 「（消すとペンに戻ります）」 / 「（消すとマーカーに戻ります）」 when it will return to that ink.
    static func eraserHint(returnsTo: CanvasTool?) -> String {
        guard let target = returnsTo else { return eraserHintText }
        switch kind(of: target) {
        case .pen:
            return eraserHintText + "（消すとペンに戻ります）"
        case .marker:
            return eraserHintText + "（消すとマーカーに戻ります）"
        case .eraser, .lasso, .eventRect:
            return eraserHintText
        }
    }

    /// The mark of the dock button (§2.2). Colour names come from `ToolbarPalette` (「その他の色」
    /// when not in the tables); a width that is not 細 / 中 / 太 gets no name and the 中 dot.
    static func badge(for tool: CanvasTool) -> ToolBadge {
        switch tool {
        case .eraser:
            return ToolBadge(symbol: "eraser", colorHex: nil, dotDiameter: nil, accessibilityValue: "消しゴム")
        case .lasso:
            return ToolBadge(symbol: "lasso", colorHex: nil, dotDiameter: nil, accessibilityValue: "投げなわ")
        case .eventRect:
            return ToolBadge(symbol: "calendar.badge.plus", colorHex: nil, dotDiameter: nil, accessibilityValue: "予定")
        case .ink(let style):
            let colorName = ToolbarPalette.colorName(style.colorHex)
            if kind(of: tool) == .marker {
                return ToolBadge(symbol: "highlighter", colorHex: style.colorHex, dotDiameter: nil,
                                 accessibilityValue: "マーカー・" + colorName)
            }
            let index = ToolbarPalette.penWidths.firstIndex { abs($0.width - style.width) < 0.001 }
            var value = "ペン・" + colorName
            var diameter = penDotDiameters[1]
            if let index = index {
                value += "・" + ToolbarPalette.penWidths[index].name
                diameter = penDotDiameters[index]
            }
            return ToolBadge(symbol: nil, colorHex: style.colorHex, dotDiameter: diameter, accessibilityValue: value)
        }
    }

    // MARK: Modes (§2.1)

    /// The mode at launch: the stored `toolbar.collapsed` (a `peek` is never stored, so reopening
    /// the app after a peek shows the dock again).
    static func startMode(collapsedStored: Bool) -> ToolbarMode {
        collapsedStored ? .collapsed : .expanded
    }

    /// A pen or a drawing finger touched the paper: a `peek` folds back into the dock; an expanded
    /// bar stays (「広げたまま使う人は広げたまま」).
    static func modeAfterPenDown(_ mode: ToolbarMode) -> ToolbarMode {
        step(mode, on: .penDown).mode
    }

    /// The table of §2.1. Events that cannot happen in a mode (the dock is not shown while expanded
    /// or peeking, the 「しまう」 button is not shown while collapsed) leave everything as it is.
    static func step(_ mode: ToolbarMode, on event: ToolbarEvent) -> ToolbarStep {
        switch (mode, event) {
        case (.expanded, .collapseTapped):
            return ToolbarStep(mode: .collapsed, storeCollapsed: true)
        case (.peek, .collapseTapped), (.peek, .penDown), (.peek, .wentToBackground):
            return ToolbarStep(mode: .collapsed)
        case (.collapsed, .dockToolTapped):
            return ToolbarStep(mode: .peek)
        case (.collapsed, .pinChosen):
            return ToolbarStep(mode: .expanded, storeCollapsed: false)
        case (.collapsed, .moveEdgeChosen):
            return ToolbarStep(mode: .collapsed, flipsEdge: true)
        default:
            return ToolbarStep(mode: mode)
        }
    }

    // MARK: Paddings (§2.2, 0-15)

    /// The toast's bottom padding: 8 above the bar (as in 1.0), above the dock (8 + 48 + 6) or above
    /// the peeking bar (8 + 60 + 6), so a centred toast never covers the dock on an iPhone.
    static func toastBottomPadding(_ mode: ToolbarMode) -> CGFloat {
        switch mode {
        case .expanded:
            return toastGap
        case .collapsed:
            return toastGap + pillHeight + bottomPadding
        case .peek:
            return toastGap + barHeight + bottomPadding
        }
    }

    /// `InkCanvasView.bottomClearance`: 0 while expanded (the bar is in the safe-area inset), 60 while
    /// the dock is shown — also during a peek, so peeking never changes the canvas insets.
    static func paperBottomClearance(_ mode: ToolbarMode) -> CGFloat {
        mode == .expanded ? 0 : dockClearance
    }
}

extension ToolbarPalette {
    /// The pen the app starts with (0-13, §2.3): the colour and width the toolbar remembers
    /// (`toolbar.penColor` / `toolbar.penWidth`, the same keys and defaults as `ToolbarView`). A colour
    /// that is not one of `penColors` falls back to 黒 and a width that is not one of `penWidths` to
    /// 中, each on its own (`ToolbarView` lights the same swatch and width).
    static func rememberedPen(_ defaults: UserDefaults) -> InkStyle {
        let width = (defaults.object(forKey: penWidthKey) as? NSNumber)?.doubleValue
        return pen(colorHex: defaults.string(forKey: penColorKey), width: width)
    }

    /// A pen from stored values, each checked against the tables (see `rememberedPen`).
    static func pen(colorHex: String?, width: Double?) -> InkStyle {
        let normalized = colorHex.flatMap(InkColors.normalized)
        let color = penColors.first { $0.hex == normalized } ?? penColors[0]
        let size = penWidths.first { entry in
            guard let width = width, width.isFinite else { return false }
            return abs(Double(entry.width) - width) < 0.001
        } ?? penWidths[1]
        return InkStyle(tool: .pen, colorHex: color.hex, width: size.width)
    }

    /// The name of a pen or marker colour (「赤」, 「黄」); 「その他の色」 when it is in neither table.
    static func colorName(_ hex: String) -> String {
        let normalized = InkColors.normalized(hex) ?? hex.lowercased()
        if let entry = penColors.first(where: { $0.hex == normalized })
            ?? markerColors.first(where: { $0.hex == normalized }) {
            return entry.name
        }
        return "その他の色"
    }
}
