import CoreGraphics
import Foundation
import Layout

// 1.1 (docs/M7A_CONTRACT.md §2, D1 / D2): the toolbar's three states, the eraser's return to the
// last pen, the mark of the round dock button and the paddings that depend on the state; since
// docs/M7A.md ずれ 45 also the bar's hints (whole strings of at most two lines) and the horizontal
// sizes of its row (`ToolbarLogic.Row`). Everything here is pure (no SwiftUI) so `ToolbarLogicTests`
// can check it; `ToolbarView`, `ToolbarDock` and `CalendarRootScreen` only read it.

/// The three states of the toolbar (§2.1). `expanded` is today's bar in the bottom safe-area inset
/// (it pushes the paper up by 74 pt: the bar 60, the 6 under it and the inset's spacing 8, measured
/// in docs/M7A.md:397-406; this note said 66 until 1.4.1, docs/R1_4_1_CONTRACT.md §1.5) plus the
/// 「しまう」 button; `collapsed` is the round dock button
/// in a bottom corner; `peek` is the bar laid *over* the paper after a tap on the dock button — it
/// never changes the paper area (a 74 pt change would re-zoom the overviews that fit the height,
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

/// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.3, §4.10, 0e-14, 0e-21): the edge of the screen the open toolbar sits on
/// (`toolbar.paletteEdge`: per device, one value for every orientation, never sent to iCloud). Bottom is 1.4's bar and
/// the default; top lies under the header and its notices; left and right stand the bar up (`ToolbarView(axis:
/// .vertical)`, §4.8). Which edges a window allows is `ToolbarLogic.allowedEdges`; a stored edge that is not allowed
/// shows at the bottom and is kept (`effectiveEdge`).
enum PaletteEdge: String, Equatable, Sendable, CaseIterable {
    case bottom, top, left, right

    /// The stored value: "bottom" / "top" / "left" / "right"; nil or anything else is `.bottom` (`ToolbarEdge(stored:)`'s
    /// shape).
    init(stored raw: String?) {
        self = raw.flatMap(PaletteEdge.init(rawValue:)) ?? .bottom
    }

    /// Left or right: the bar stands up there (§4.8) and narrows the paper's column by `ToolbarLogic.sideSlotWidth`.
    var isSide: Bool {
        self == .left || self == .right
    }

    /// §4.9 (0e-20): the corner of the round dock button a drop on this edge writes (`toolbar.collapsedEdge`): the left
    /// edge the bottom left, the right edge the bottom right, so 「しまう」 leaves the dock on that side; top and bottom
    /// write nothing (nil).
    var dockEdge: ToolbarEdge? {
        switch self {
        case .left:
            return .leading
        case .right:
            return .trailing
        case .bottom, .top:
            return nil
        }
    }
}

/// Where the current eraser came from (§2.4): the toolbar, or the Apple Pencil's double tap / squeeze.
/// It no longer decides the return (the owner, 2026-11-01, docs/M7A.md ずれ 49: an eraser chosen with
/// the Pencil goes back to the pen after it erased something too); kept so the screen still knows how
/// the eraser was chosen (the screenshot states, a later change of mind).
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
    /// 1.4.1 (docs/R1_4_1_CONTRACT.md §4.7, §4.11, 0e-18, 0e-22): the grip was let go, or a VoiceOver action moved the
    /// bar to another edge.
    case placementChosen
    /// Read only, rotation, a width change, another page: nothing changes.
    case other
}

/// The result of one event (§2.1): the next mode, the new value of `toolbar.collapsed` (nil = do not
/// write it) and whether `toolbar.collapsedEdge` moves to the other corner. 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.7):
/// and whether the bar's edge is written (`toolbar.paletteEdge`; never in screenshot mode, §4.10).
struct ToolbarStep: Equatable, Sendable {
    var mode: ToolbarMode
    var storeCollapsed: Bool?
    var flipsEdge: Bool
    var storesPlacement: Bool

    init(mode: ToolbarMode, storeCollapsed: Bool? = nil, flipsEdge: Bool = false, storesPlacement: Bool = false) {
        self.mode = mode
        self.storeCollapsed = storeCollapsed
        self.flipsEdge = flipsEdge
        self.storesPlacement = storesPlacement
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

    static let collapseTitle = L.text("toolbar.collapse.title")
    static let collapseAccessibilityLabel = L.text("toolbar.collapse.spoken")
    static let dockAccessibilityLabel = L.text("toolbar.dock.spoken")
    static let pinTitle = L.text("toolbar.pin")
    static let eraserHintText = L.text("toolbar.hint.eraser")
    /// The lasso's and the 予定 tool's hints as the bar shows them: two lines (M7A.md ずれ 45). Without
    /// the "\n" they are the 1.0.1 sentences. Each is one whole string (1.2 makes each one key).
    static let lassoBarHint = L.text("toolbar.hint.lasso")
    static let eventBarHint = L.text("toolbar.hint.event")

    /// The dock's menu item that moves it to the other bottom corner.
    static func moveEdgeTitle(from edge: ToolbarEdge) -> String {
        edge == .leading ? L.text("toolbar.moveEdge.toRight") : L.text("toolbar.moveEdge.toLeft")
    }

    /// The SF Symbol of that menu item.
    static func moveEdgeSymbol(from edge: ToolbarEdge) -> String {
        edge == .leading ? "arrow.right.to.line" : "arrow.left.to.line"
    }

    /// The VoiceOver hint of the dock's tool mark.
    static func dockAccessibilityHint(edge: ToolbarEdge) -> String {
        edge == .leading ? L.text("toolbar.dock.hint.toRight") : L.text("toolbar.dock.hint.toLeft")
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

    /// The tool after the canvas reported an erasure (§2.4, D2; 1.1 fix, docs/M7A.md ずれ 46: once
    /// nothing touches the paper — on the turn after the Pencil lifts, the canvas's
    /// `fingerEraseReportDelay` after a finger, on the week, month and year pages after a single tap's
    /// undo of 0-22): the last pen or marker when the current tool is still the eraser, at least one
    /// stroke was erased and the setting 「消しゴムで消したらペンに戻る」 is on — however the eraser was
    /// chosen (`origin` no longer matters: the owner, 2026-11-01, ずれ 49; before, only the toolbar's
    /// eraser returned and the Pencil's stayed); nil = leave the tool alone (also when the person picked
    /// another tool before the report).
    static func toolAfterErase(origin: EraserOrigin?, erased: Int, setting: Bool,
                               current: CanvasTool, lastInk: CanvasTool) -> CanvasTool? {
        current.isEraser && erased > 0 && setting ? lastInk : nil
    }

    /// The eraser's hint as the bar shows it (§6.2, M7A.md ずれ 45): 「触れた線をまるごと消します」, and
    /// when it will return to an ink 「（消すとペンに戻ります）」 / 「（消すとマーカーに戻ります）」 on a
    /// second line, so the bracket does not push ↶ ↷ and 「指でも書く」 out of sight. One whole string
    /// per case (1.2 makes each one key).
    static func eraserBarHint(returnsTo: CanvasTool?) -> String {
        guard let target = returnsTo else { return eraserHintText }
        switch kind(of: target) {
        case .pen:
            return L.text("toolbar.hint.eraser.toPen")
        case .marker:
            return L.text("toolbar.hint.eraser.toMarker")
        case .eraser, .lasso, .eventRect:
            return eraserHintText
        }
    }

    /// The same hint on one line (the §6.2 sentence): `eraserBarHint` without its line break. Only the
    /// Japanese tests read it (docs/M7B_CONTRACT.md §4.4): the screen and VoiceOver never do, and in a
    /// language with spaces between words the two lines would run together ("…touches(then back…").
    static func eraserHint(returnsTo: CanvasTool?) -> String {
        eraserBarHint(returnsTo: returnsTo).replacingOccurrences(of: "\n", with: "")
    }

    /// The mark of the dock button (§2.2). Colour names come from `ToolbarPalette` (「その他の色」
    /// when not in the tables); a width that is not 細 / 中 / 太 gets no name and the 中 dot.
    static func badge(for tool: CanvasTool) -> ToolBadge {
        switch tool {
        case .eraser:
            return ToolBadge(symbol: "eraser", colorHex: nil, dotDiameter: nil, accessibilityValue: L.text("toolbar.tool.eraser"))
        case .lasso:
            return ToolBadge(symbol: "lasso", colorHex: nil, dotDiameter: nil, accessibilityValue: L.text("toolbar.tool.lasso"))
        case .eventRect:
            return ToolBadge(symbol: "calendar.badge.plus", colorHex: nil, dotDiameter: nil, accessibilityValue: L.text("toolbar.tool.event"))
        case .ink(let style):
            let colorName = ToolbarPalette.colorName(style.colorHex)
            if kind(of: tool) == .marker {
                return ToolBadge(symbol: "highlighter", colorHex: style.colorHex, dotDiameter: nil,
                                 accessibilityValue: L.format("toolbar.badge.marker", colorName))
            }
            let index = ToolbarPalette.penWidths.firstIndex { abs($0.width - style.width) < 0.001 }
            var value = L.format("toolbar.badge.pen", colorName)
            var diameter = penDotDiameters[1]
            if let index = index {
                value = L.format("toolbar.badge.penWidth", colorName, ToolbarPalette.penWidths[index].name)
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
        case (.expanded, .placementChosen):
            // 1.4.1 (§4.7): only the open bar has a grip; it stays open on its new edge.
            return ToolbarStep(mode: .expanded, storesPlacement: true)
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

extension ToolbarLogic {
    /// 1.1 (docs/M7A.md ずれ 45): the horizontal sizes of the expanded and the peeking bar
    /// (`ToolbarView`). 「しまう」 outside the scrolling row (0-10) takes 1 px + 4 + 48 + 8 of the bar;
    /// the row wins it back by packing its pieces (the pen row 980.5 → 868.5 pt), so every iPhone and
    /// every iPad window at least 334 pt wide shows at least what 1.0.1 showed (11-inch with the
    /// pen: up to ↷; iPhone 17: the first colour
    /// with its ring and half of the next one, fading; 13-inch: everything). The row height
    /// (44 + 8 + 8) does not change (`barHeight`; YearTapUITests reads the top of 「ペン」).
    enum Row {
        /// The scrolling row's padding: leading 14 → 8 (the selected tool sits 8 from the bar's edge,
        /// as from its top and bottom), trailing 14 as before (≥ `fadeWidth`, so the last piece is
        /// never faded when the row is scrolled to its end).
        static let paddingLeading: CGFloat = 8
        static let paddingTrailing: CGFloat = 14
        /// The last 12 pt before 「しまう」's divider fade out, so a piece cut there reads as "more to
        /// the right" instead of being sliced by the divider.
        static let fadeWidth: CGFloat = 12
        /// Each side of a divider in the row: 10 → 6.
        static let groupSpacing: CGFloat = 6
        /// Tool buttons and 「しまう」: the label + 5 + 5, at least 48 (was 56 with 4 between; now 0).
        /// Every Japanese label fits the 48 (「マーカー」 36.9 pt at 10 pt).
        static let buttonMinWidth: CGFloat = 48
        static let labelInset: CGFloat = 5
        /// The symbol's box in those buttons: as tall as the tools' symbols at 18 pt (22, measured in
        /// the CI photos), so 「しまう」's label (chevron.down alone is 12) sits level with the others.
        static let symbolHeight: CGFloat = 22
        /// A colour swatch: 36 + 6 between → 38 with nothing between (the whole 38 × 44 is the button).
        static let swatchWidth: CGFloat = 38
        /// 細 / 中 / 太: the label + 3 + 3, at least 44 (was 40 with 4 between; now 0).
        static let widthButtonMinWidth: CGFloat = 44
        static let widthLabelInset: CGFloat = 3
        /// ↶ / ↷: 44 each (4 between → 0).
        static let historyButtonWidth: CGFloat = 44
        /// 「しまう」 after its divider: 8 → 4 before it, 8 after it as before (its right edge stays).
        static let collapseLeading: CGFloat = 4
        static let collapseTrailing: CGFloat = 8

        /// F-12 (docs/M7B_CONTRACT.md §4.4, 0-36): the frame of the 10 pt names of the five tools, of
        /// 「しまう」 and of 細中太. Japanese takes 1.1's path (nil: the name sets the width; every Japanese
        /// name fits, so nothing widens). Every other language gets a fixed 38 pt frame, so a long word
        /// never widens its button: the row is as wide as in Japanese and iPhone 17's first colour,
        /// the 11-inch's ↷ and iPad mini's 太 stay in sight.
        static func labelFrameWidth(for language: UILanguage) -> CGFloat? {
            language == .ja ? nil : 38
        }

        /// How far a name shrinks in that frame (47.5 pt at 10 pt fits; ToolbarFitTests).
        static let labelMinScale: CGFloat = 0.8
    }
}

// MARK: - 1.4.1: the bar on four edges

extension ToolbarLogic {
    // MARK: Slots (docs/R1_4_1_CONTRACT.md §2.1, §4.4, 0e-15)

    /// The slot of a left or right bar: 6 outside (`slotOuterPadding`) + the vertical bar 60 + 8 to the paper
    /// (`slotPaperGap`). The paper's column is this much narrower while the bar is open on a side.
    static let sideSlotWidth: CGFloat = 74
    /// The slot of a top bar, between the header's notices and the sticky heading: 6 above + the bar 60 + 8 to the
    /// paper (12 on each side, `sidePadding`). The paper area is the bottom bar's (the same zoom); the paper sits 74 lower.
    static let topSlotHeight: CGFloat = 74
    /// The vertical bar (§4.8): 6 + a 48 pt column + 6 (`Column`).
    static let verticalBarWidth: CGFloat = 60
    /// §4.5 (0e-16): the room above a bottom bar that has a grip. The safe-area inset's spacing is 0 then and the bar
    /// takes this explicit 8 instead of the inset's default spacing (8 in 1.4, measured), so the slot stays 74 pt (8 + 60
    /// + 6) and the grip's zone lies inside the slot; without a grip (every iPhone) the bar is 1.4's, spacing nil.
    static let expandedBottomGap: CGFloat = 8
    /// The 6 pt between a top or side bar and the screen's side of its slot (the bottom bar's `bottomPadding`).
    static let slotOuterPadding: CGFloat = 6
    /// The 8 pt between a bar and the paper (the bottom bar's `expandedBottomGap`).
    static let slotPaperGap: CGFloat = 8

    /// §4.8 (0e-19): the sizes of the vertical bar (`ToolbarView(axis: .vertical)`), the column counterpart of `Row`.
    /// The column is 48 wide; the tools keep `Row`'s 48 × 44 faces and F-12's label frame; the swatches turn to 44 × 38.
    enum Column {
        /// The bar's own padding on each side, outside its ScrollView (so the side grip's 14 pt zone never lies on it,
        /// §4.5): 60 = 6 + 48 + 6.
        static let sidePadding: CGFloat = 6
        /// The column's width: the tools' and 細中太's faces (`Row.buttonMinWidth`).
        static let width: CGFloat = 48
        /// A colour swatch: 44 wide, 38 tall (the 32 pt ring of the chosen colour fits the 38).
        static let swatchWidth: CGFloat = 44
        static let swatchHeight: CGFloat = 38
        /// ↶ ↷ and the icon-only 「指でも書く」: 44 × 44. 細中太 are 44 tall.
        static let cellSide: CGFloat = 44
        /// The length of a divider across the column.
        static let dividerLength: CGFloat = 24
    }

    // MARK: Edges (§4.3, 0e-14)

    /// The least column width (pt) for a left or right bar: the narrowed paper column then stays at 626 or more, so
    /// `smallScreen` (`usesMinTapTarget`, under 600) never flips when the bar moves to a side (the reviews' E6 / E8 / M4).
    static let sideMinColumn: CGFloat = 700
    /// The least height (pt) of the paper's column under the header (and its notices) for a left or right bar.
    static let sideMinColumnHeight: CGFloat = 460

    /// The edges the open bar may sit on, in the order [bottom, top, left, right]. The kind of device is never read here:
    /// `isPad` is the screen's `pencilPhone.isPad` (idiom-allow's line; no new idiom reading). Not an iPad (every iPhone,
    /// the Duo's inner screen too, whatever the window): the bottom only, 1.4's bar. An iPad: the bottom always; the top in
    /// a wide window (`WindowClass.isWide`: short side 600 or more); left and right as well when the `column` (pt, the
    /// screen's width for the paper) is at least `sideMinColumn` and the `paperColumnHeight` (pt, under the header) at
    /// least `sideMinColumnHeight`. A value that is not finite allows no side.
    static func allowedEdges(isPad: Bool, windowSize: CGSize?, column: CGFloat, paperColumnHeight: CGFloat) -> [PaletteEdge] {
        guard isPad, WindowClass.isWide(windowSize) else { return [.bottom] }
        // MUTATION MT1 (r141-q-m2 only, never merged; docs/R1_4_1_CONTRACT.md §16.7, ToolbarPlacementTests): the sides
        // are allowed from a column of 678 pt (was: `sideMinColumn`, 700, which itself stays 700).
        if column >= 678, paperColumnHeight >= sideMinColumnHeight {
            return [.bottom, .top, .left, .right]
        }
        return [.bottom, .top]
    }

    /// The edge the bar shows on: `stored` when the window allows it, else the bottom. `stored` itself is never
    /// rewritten by this (a rotation or a narrower window keeps it, and it comes back when allowed again, §4.10).
    static func effectiveEdge(stored: PaletteEdge, allowed: [PaletteEdge]) -> PaletteEdge {
        allowed.contains(stored) ? stored : .bottom
    }

    // MARK: The drag and the snap (§4.7, 0e-18)

    /// How far ahead the drop is carried by the finger's speed (s).
    static let snapLookAhead: CGFloat = 0.15
    /// The middle where a drop keeps the current edge: the frame inset by this share of its size on each side.
    static let snapDeadZone: CGFloat = 0.25
    /// The bar's opacity while it is being moved (it stays open in its slot; nothing is laid out again until the drop).
    static let draggedBarOpacity: Double = 0.4
    /// The puck (`PaletteDragOverlay`) rides this far above the finger.
    static let puckLift: CGFloat = 40
    /// The drop outlines (`PaletteDragOverlay`): accent at 12 % for every allowed edge, 28 % and a 2 pt border for the
    /// edge the drop would snap to.
    static let slotOutlineOpacity: Double = 0.12
    static let snapTargetOpacity: Double = 0.28
    static let snapTargetBorder: CGFloat = 2

    /// The edge a drop snaps to. `drop` and `frame` are in one coordinate space (the frame is the slots' column,
    /// `barFrame`'s); `velocity` is in pt/s. The drop is carried `snapLookAhead` s ahead by the velocity and kept inside
    /// the frame; in the middle (the frame inset by `snapDeadZone` on each side) the bar stays on `current`; elsewhere it
    /// goes to the nearest allowed edge, a tie going to `current`, then bottom, top, left, right. A velocity that is not
    /// finite counts as none; a drop or a frame that is not usable keeps `effectiveEdge(current)`.
    static func snapEdge(drop: CGPoint, velocity: CGVector, frame: CGRect, allowed: [PaletteEdge],
                         current: PaletteEdge) -> PaletteEdge {
        guard !allowed.isEmpty else { return current }
        let box = frame.standardized
        guard !box.isNull, box.minX.isFinite, box.minY.isFinite, box.width.isFinite, box.height.isFinite,
              box.width > 0, box.height > 0, drop.x.isFinite, drop.y.isFinite else {
            return effectiveEdge(stored: current, allowed: allowed)
        }
        let dx = velocity.dx.isFinite ? velocity.dx : 0
        let dy = velocity.dy.isFinite ? velocity.dy : 0
        let point = CGPoint(x: min(max(drop.x + dx * snapLookAhead, box.minX), box.maxX),
                            y: min(max(drop.y + dy * snapLookAhead, box.minY), box.maxY))
        let middle = box.insetBy(dx: box.width * snapDeadZone, dy: box.height * snapDeadZone)
        if allowed.contains(current), middle.contains(point) {
            return current
        }
        func distance(to edge: PaletteEdge) -> CGFloat {
            switch edge {
            case .bottom:
                return box.maxY - point.y
            case .top:
                return point.y - box.minY
            case .left:
                return point.x - box.minX
            case .right:
                return box.maxX - point.x
            }
        }
        var best: PaletteEdge?
        var bestDistance = CGFloat.infinity
        for edge in [current] + PaletteEdge.allCases where allowed.contains(edge) {
            let candidate = distance(to: edge)
            if candidate < bestDistance {
                best = edge
                bestDistance = candidate
            }
        }
        return best ?? effectiveEdge(stored: current, allowed: allowed)
    }

    /// Where the bar of `edge` lies inside the slots' `column` (the area under the header and its notices, down to the
    /// bottom of the safe area, full width): the drop outlines and the snap's frame. Bottom: 1.4's bar (12 on each side,
    /// 6 above the safe area, 60 tall). Top: 12 on each side, 6 under the notices. Left and right: 6 from the side and 6
    /// from the top and the bottom, 60 wide.
    static func barFrame(_ edge: PaletteEdge, in column: CGRect) -> CGRect {
        let box = column.standardized
        let wide = max(0, box.width - 2 * sidePadding)
        let tall = max(0, box.height - 2 * slotOuterPadding)
        switch edge {
        case .bottom:
            return CGRect(x: box.minX + sidePadding, y: box.maxY - bottomPadding - barHeight, width: wide, height: barHeight)
        case .top:
            return CGRect(x: box.minX + sidePadding, y: box.minY + slotOuterPadding, width: wide, height: barHeight)
        case .left:
            return CGRect(x: box.minX + slotOuterPadding, y: box.minY + slotOuterPadding, width: verticalBarWidth, height: tall)
        case .right:
            return CGRect(x: box.maxX - slotOuterPadding - verticalBarWidth, y: box.minY + slotOuterPadding,
                          width: verticalBarWidth, height: tall)
        }
    }

    // MARK: The grip (§4.5, 0e-16)

    /// The grip shows only on the open bar when the window allows two edges or more (never on the dock or a peek).
    static func showsGrip(_ mode: ToolbarMode, allowed: [PaletteEdge]) -> Bool {
        mode == .expanded && allowed.count >= 2
    }

    /// The grip's touch zone along the bar's inner edge, centred: 120 pt.
    static let gripLength: CGFloat = 120
    /// Across a top or bottom bar's inner edge: the 8 pt to the paper + the bar's own 8 pt padding.
    static let gripThickness: CGFloat = 16
    /// Across a side bar's inner edge: the 8 pt to the paper + the bar's own 6 pt padding.
    static let sideGripThickness: CGFloat = 14
    /// The grip's mark: a 36 × 5 capsule (5 × 36 on a side bar) in `secondaryLabel`, inside the bar's padding.
    static let gripMarkLength: CGFloat = 36
    static let gripMarkThickness: CGFloat = 5

    /// The grip's size: 120 × 16 on a top or bottom bar, 14 × 120 on a side bar.
    static func gripSize(for edge: PaletteEdge) -> CGSize {
        edge.isSide ? CGSize(width: sideGripThickness, height: gripLength) : CGSize(width: gripLength, height: gripThickness)
    }

    /// The grip's frame on the side of `bar` that faces the middle of the screen: the bottom bar's top edge, the top
    /// bar's bottom edge, a side bar's inner edge; half of it over the gap to the paper, the rest over the bar's padding.
    static func gripFrame(for edge: PaletteEdge, bar: CGRect) -> CGRect {
        let size = gripSize(for: edge)
        switch edge {
        case .bottom:
            return CGRect(x: bar.midX - size.width / 2, y: bar.minY - slotPaperGap, width: size.width, height: size.height)
        case .top:
            return CGRect(x: bar.midX - size.width / 2, y: bar.maxY + slotPaperGap - size.height,
                          width: size.width, height: size.height)
        case .left:
            return CGRect(x: bar.maxX + slotPaperGap - size.width, y: bar.midY - size.height / 2,
                          width: size.width, height: size.height)
        case .right:
            return CGRect(x: bar.minX - slotPaperGap, y: bar.midY - size.height / 2, width: size.width, height: size.height)
        }
    }

    /// The mark's frame inside a grip of `size` (its own coordinates): centred along the edge, and across it in the part
    /// that lies over the bar (nothing is drawn over the gap to the paper).
    static func gripMarkFrame(for edge: PaletteEdge, in size: CGSize) -> CGRect {
        switch edge {
        case .bottom, .top:
            let barPart = max(0, size.height - slotPaperGap)
            let y = edge == .bottom ? slotPaperGap + (barPart - gripMarkThickness) / 2 : (barPart - gripMarkThickness) / 2
            return CGRect(x: (size.width - gripMarkLength) / 2, y: y, width: gripMarkLength, height: gripMarkThickness)
        case .left, .right:
            let barPart = max(0, size.width - slotPaperGap)
            let x = edge == .right ? slotPaperGap + (barPart - gripMarkThickness) / 2 : (barPart - gripMarkThickness) / 2
            return CGRect(x: x, y: (size.height - gripMarkLength) / 2, width: gripMarkThickness, height: gripMarkLength)
        }
    }

    // MARK: Toasts (§4.9, 0e-20)

    /// The toast's extra inset on the bar's side: `sideSlotWidth` while the bar is open on the left or the right (the
    /// toast never lies on the vertical bar), else 0. `toastBottomPadding` is unchanged.
    static func toastSideInset(_ mode: ToolbarMode, edge: PaletteEdge) -> CGFloat {
        mode == .expanded && edge.isSide ? sideSlotWidth : 0
    }

    // MARK: VoiceOver (§4.11, 0e-22)

    /// The grip's spoken name, 「ツールバーを動かす」, and its hint, 「上下左右の端へ移せます」.
    static let gripAccessibilityLabel = L.text("toolbar.grip.spoken")
    static let gripAccessibilityHint = L.text("toolbar.grip.hint")

    /// The grip's actions: one for each allowed edge but the current one, in `allowed`'s order.
    static func moveTargets(allowed: [PaletteEdge], current: PaletteEdge) -> [PaletteEdge] {
        allowed.filter { $0 != current }
    }

    /// The name of the action that moves the bar to `edge`: 「上へ移す」「下へ移す」「左へ移す」「右へ移す」.
    static func moveToTitle(_ edge: PaletteEdge) -> String {
        switch edge {
        case .bottom:
            return L.text("toolbar.moveTo.bottom")
        case .top:
            return L.text("toolbar.moveTo.top")
        case .left:
            return L.text("toolbar.moveTo.left")
        case .right:
            return L.text("toolbar.moveTo.right")
        }
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
        return L.text("toolbar.color.unknown")
    }
}
