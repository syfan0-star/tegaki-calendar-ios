import CoreGraphics
import Foundation
import InkModel
import XCTest
@testable import TegakiCalendar

/// 1.1 (docs/M7A_CONTRACT.md §2, §7.2 T): the pure logic of the toolbar — the eraser's return to the
/// last pen (D2), the three states and their table (§2.1, D1), the toast padding and the paper's
/// clearance above the dock (0-15), the dock button's mark (§2.2), the pen the app starts with
/// (0-13), the eraser's hint (§6.2) and the kind of a tool (moved from `ToolbarView`).
final class ToolbarLogicTests: XCTestCase {
    private let redThick = CanvasTool.ink(InkStyle(tool: .pen, colorHex: "#dc2626", width: 6))
    private let yellowMarker = CanvasTool.ink(InkStyle(tool: .marker, colorHex: "#fde047", width: 18))

    // MARK: toolAfterErase (§2.4)

    func testToolAfterEraseTable() {
        let origins: [EraserOrigin?] = [nil, .toolbar, .pencil]
        let currents: [CanvasTool] = [.eraser, .lasso, .ink(ToolbarPalette.defaultPen)]
        var returned = 0
        for origin in origins {
            for erased in [0, 1, 3] {
                for setting in [false, true] {
                    for lastInk in [redThick, yellowMarker] {
                        for current in currents {
                            let result = ToolbarLogic.toolAfterErase(origin: origin, erased: erased, setting: setting,
                                                                     current: current, lastInk: lastInk)
                            let label = "origin \(String(describing: origin)) erased \(erased) setting \(setting) "
                                + "last \(lastInk) current \(current)"
                            if origin == .toolbar, erased > 0, setting, current == .eraser {
                                XCTAssertEqual(result, lastInk, label)
                                returned += 1
                            } else {
                                XCTAssertNil(result, label)
                            }
                        }
                    }
                }
            }
        }
        // Only the toolbar's eraser with 1 or 3 erased, the setting on and the eraser still chosen:
        // 2 counts × 2 last inks.
        XCTAssertEqual(returned, 4)

        // The rows of §2.4 in words.
        XCTAssertEqual(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 1, setting: true,
                                                   current: .eraser, lastInk: redThick), redThick,
                       "a red thick pen comes back red and thick")
        XCTAssertEqual(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 2, setting: true,
                                                   current: .eraser, lastInk: yellowMarker), yellowMarker,
                       "a marker comes back as the marker")
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 0, setting: true,
                                                 current: .eraser, lastInk: redThick), "nothing erased")
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: .pencil, erased: 5, setting: true,
                                                 current: .eraser, lastInk: redThick), "the Pencil's eraser stays")
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 5, setting: false,
                                                 current: .eraser, lastInk: redThick), "the setting is off")
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 5, setting: true,
                                                 current: .lasso, lastInk: redThick),
                     "the lasso was picked during the settle delay: keep it")
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 5, setting: true,
                                                 current: .eventRect, lastInk: redThick))
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: .toolbar, erased: 5, setting: true,
                                                 current: yellowMarker, lastInk: redThick),
                     "another ink was picked during the settle delay: keep it")
        XCTAssertNil(ToolbarLogic.toolAfterErase(origin: nil, erased: 5, setting: true,
                                                 current: .eraser, lastInk: redThick), "no origin recorded")
    }

    // MARK: Modes (§2.1)

    func testModeTransitions() {
        // Launch: the stored flag (a peek is never stored).
        XCTAssertEqual(ToolbarLogic.startMode(collapsedStored: false), .expanded)
        XCTAssertEqual(ToolbarLogic.startMode(collapsedStored: true), .collapsed)

        // A pen or a drawing finger on the paper.
        XCTAssertEqual(ToolbarLogic.modeAfterPenDown(.expanded), .expanded, "an expanded bar stays")
        XCTAssertEqual(ToolbarLogic.modeAfterPenDown(.peek), .collapsed, "a peek folds back")
        XCTAssertEqual(ToolbarLogic.modeAfterPenDown(.collapsed), .collapsed)

        // The table of §2.1, row by row.
        typealias Row = (ToolbarMode, ToolbarEvent, ToolbarStep)
        let rows: [Row] = [
            (.expanded, .collapseTapped, ToolbarStep(mode: .collapsed, storeCollapsed: true)),
            (.expanded, .penDown, ToolbarStep(mode: .expanded)),
            (.collapsed, .dockToolTapped, ToolbarStep(mode: .peek)),
            (.collapsed, .dockUndoTapped, ToolbarStep(mode: .collapsed)),
            (.peek, .penDown, ToolbarStep(mode: .collapsed)),
            (.peek, .collapseTapped, ToolbarStep(mode: .collapsed)),
            (.peek, .wentToBackground, ToolbarStep(mode: .collapsed)),
            (.collapsed, .pinChosen, ToolbarStep(mode: .expanded, storeCollapsed: false)),
            (.collapsed, .moveEdgeChosen, ToolbarStep(mode: .collapsed, flipsEdge: true)),
            (.expanded, .other, ToolbarStep(mode: .expanded)),
            (.collapsed, .other, ToolbarStep(mode: .collapsed)),
            (.peek, .other, ToolbarStep(mode: .peek)),
        ]
        for (mode, event, expected) in rows {
            XCTAssertEqual(ToolbarLogic.step(mode, on: event), expected, "\(mode) + \(event)")
        }

        // Everything else changes nothing: a peek is only left by touching the paper, 「しまう」 or the
        // background; the dock's events only exist while the dock is shown.
        let events: [ToolbarEvent] = [.collapseTapped, .penDown, .dockToolTapped, .dockUndoTapped,
                                      .wentToBackground, .pinChosen, .moveEdgeChosen, .other]
        for mode in [ToolbarMode.expanded, .collapsed, .peek] {
            for event in events where !rows.contains(where: { $0.0 == mode && $0.1 == event }) {
                XCTAssertEqual(ToolbarLogic.step(mode, on: event), ToolbarStep(mode: mode), "\(mode) + \(event)")
            }
        }
        // Only 「しまう」 from the expanded bar and 「ツールバーをいつも出す」 write the flag.
        var writes: [ToolbarMode: [Bool]] = [:]
        for mode in [ToolbarMode.expanded, .collapsed, .peek] {
            for event in events {
                if let value = ToolbarLogic.step(mode, on: event).storeCollapsed {
                    writes[mode, default: []].append(value)
                }
            }
        }
        XCTAssertEqual(writes, [.expanded: [true], .collapsed: [false]])
        // modeAfterPenDown is the table's pen-down row.
        for mode in [ToolbarMode.expanded, .collapsed, .peek] {
            XCTAssertEqual(ToolbarLogic.modeAfterPenDown(mode), ToolbarLogic.step(mode, on: .penDown).mode)
        }

        // The stored strings and the corner.
        XCTAssertEqual(ToolbarMode.expanded.rawValue, "expanded")
        XCTAssertEqual(ToolbarMode.collapsed.rawValue, "collapsed")
        XCTAssertEqual(ToolbarMode.peek.rawValue, "peek")
        XCTAssertEqual(ToolbarEdge.leading.rawValue, "leading")
        XCTAssertEqual(ToolbarEdge.trailing.rawValue, "trailing")
        XCTAssertEqual(ToolbarEdge.leading.opposite, .trailing)
        XCTAssertEqual(ToolbarEdge.trailing.opposite, .leading)
        XCTAssertEqual(ToolbarEdge(stored: "trailing"), .trailing)
        XCTAssertEqual(ToolbarEdge(stored: "leading"), .leading)
        XCTAssertEqual(ToolbarEdge(stored: nil), .leading)
        XCTAssertEqual(ToolbarEdge(stored: "right"), .leading)
        XCTAssertEqual(ToolbarEdge(stored: "Trailing"), .leading)
    }

    // MARK: Paddings (§2.2, 0-15)

    func testToastPaddingAndClearance() {
        XCTAssertEqual(ToolbarLogic.barHeight, 60)
        XCTAssertEqual(ToolbarLogic.pillHeight, 48)
        XCTAssertEqual(ToolbarLogic.sidePadding, 12)
        XCTAssertEqual(ToolbarLogic.bottomPadding, 6)
        XCTAssertEqual(ToolbarLogic.pillWidth, 2 + 44 + 4 + 44 + 2)
        XCTAssertEqual(ToolbarLogic.barHeight + ToolbarLogic.bottomPadding, 66, "the expanded bar pushes the paper 66 pt")

        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.expanded), 8, "as in 1.0")
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.collapsed), 62, "8 + 48 + 6")
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.peek), 74, "8 + 60 + 6")
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.collapsed),
                       8 + ToolbarLogic.pillHeight + ToolbarLogic.bottomPadding)
        XCTAssertEqual(ToolbarLogic.toastBottomPadding(.peek),
                       8 + ToolbarLogic.barHeight + ToolbarLogic.bottomPadding)

        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.expanded), 0)
        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.collapsed), 60, "48 + 6 + 6")
        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.peek), 60, "a peek never changes the canvas insets")
        XCTAssertEqual(ToolbarLogic.paperBottomClearance(.collapsed),
                       ToolbarLogic.pillHeight + ToolbarLogic.bottomPadding + 6)
    }

    // MARK: Badge (§2.2)

    func testBadgeForEveryTool() {
        let widthNames = ["細", "中", "太"]
        let diameters: [CGFloat] = [10, 14, 18]
        XCTAssertEqual(ToolbarPalette.penWidths.map(\.name), widthNames)
        for color in ToolbarPalette.penColors {
            for (index, width) in ToolbarPalette.penWidths.enumerated() {
                let badge = ToolbarLogic.badge(for: .ink(InkStyle(tool: .pen, colorHex: color.hex, width: width.width)))
                XCTAssertEqual(badge, ToolBadge(symbol: nil, colorHex: color.hex, dotDiameter: diameters[index],
                                                accessibilityValue: "ペン・\(color.name)・\(widthNames[index])"),
                               "\(color.name) \(width.name)")
            }
        }
        XCTAssertEqual(ToolbarLogic.badge(for: redThick).accessibilityValue, "ペン・赤・太")
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(ToolbarPalette.defaultPen)).accessibilityValue, "ペン・黒・中")
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(ToolbarPalette.defaultPen)).dotDiameter, 14)

        let markerNames = ["黄", "ピンク", "緑", "水色"]
        XCTAssertEqual(ToolbarPalette.markerColors.map(\.name), markerNames)
        for color in ToolbarPalette.markerColors {
            let badge = ToolbarLogic.badge(for: .ink(InkStyle(tool: .marker, colorHex: color.hex,
                                                              width: ToolbarPalette.markerWidth)))
            XCTAssertEqual(badge, ToolBadge(symbol: "highlighter", colorHex: color.hex, dotDiameter: nil,
                                            accessibilityValue: "マーカー・\(color.name)"), color.name)
        }

        XCTAssertEqual(ToolbarLogic.badge(for: .eraser),
                       ToolBadge(symbol: "eraser", colorHex: nil, dotDiameter: nil, accessibilityValue: "消しゴム"))
        XCTAssertEqual(ToolbarLogic.badge(for: .lasso),
                       ToolBadge(symbol: "lasso", colorHex: nil, dotDiameter: nil, accessibilityValue: "投げなわ"))
        XCTAssertEqual(ToolbarLogic.badge(for: .eventRect),
                       ToolBadge(symbol: "calendar.badge.plus", colorHex: nil, dotDiameter: nil, accessibilityValue: "予定"))

        // Not in the tables: 「その他の色」, and a width without a name keeps the 中 dot.
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(InkStyle(tool: .pen, colorHex: "#123456", width: 3.5))),
                       ToolBadge(symbol: nil, colorHex: "#123456", dotDiameter: 14, accessibilityValue: "ペン・その他の色・中"))
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(InkStyle(tool: .pen, colorHex: "#dc2626", width: 5))),
                       ToolBadge(symbol: nil, colorHex: "#dc2626", dotDiameter: 14, accessibilityValue: "ペン・赤"))
        XCTAssertEqual(ToolbarLogic.badge(for: .ink(InkStyle(tool: .marker, colorHex: "#000000", width: 18))),
                       ToolBadge(symbol: "highlighter", colorHex: "#000000", dotDiameter: nil,
                                 accessibilityValue: "マーカー・その他の色"))
        // The colour names, either case, and an upper-case stored colour.
        XCTAssertEqual(ToolbarPalette.colorName("#dc2626"), "赤")
        XCTAssertEqual(ToolbarPalette.colorName("#DC2626"), "赤")
        XCTAssertEqual(ToolbarPalette.colorName("#1f2937"), "黒")
        XCTAssertEqual(ToolbarPalette.colorName("#16a34a"), "緑")
        XCTAssertEqual(ToolbarPalette.colorName("#86efac"), "緑", "the marker's green")
        XCTAssertEqual(ToolbarPalette.colorName("#93c5fd"), "水色")
        XCTAssertEqual(ToolbarPalette.colorName("#ffffff"), "その他の色")
        XCTAssertEqual(ToolbarPalette.colorName("not a colour"), "その他の色")
        XCTAssertEqual(ToolbarPalette.colorName(""), "その他の色")
    }

    /// The fixed texts of the 「しまう」 button and the dock (§6.2).
    func testCollapseAndDockTexts() {
        XCTAssertEqual(ToolbarLogic.collapseTitle, "しまう")
        XCTAssertEqual(ToolbarLogic.collapseAccessibilityLabel, "ツールバーをしまう")
        XCTAssertEqual(ToolbarLogic.dockAccessibilityLabel, "ツールバーを出す")
        XCTAssertEqual(ToolbarLogic.pinTitle, "ツールバーをいつも出す")
        XCTAssertEqual(ToolbarLogic.moveEdgeTitle(from: .leading), "右下へ移す")
        XCTAssertEqual(ToolbarLogic.moveEdgeTitle(from: .trailing), "左下へ移す")
        XCTAssertEqual(ToolbarLogic.moveEdgeSymbol(from: .leading), "arrow.right.to.line")
        XCTAssertEqual(ToolbarLogic.moveEdgeSymbol(from: .trailing), "arrow.left.to.line")
        XCTAssertEqual(ToolbarLogic.dockAccessibilityHint(edge: .leading),
                       "長押しで、右下へ移すか、ツールバーをいつも出すかを選べます")
        XCTAssertEqual(ToolbarLogic.dockAccessibilityHint(edge: .trailing),
                       "長押しで、左下へ移すか、ツールバーをいつも出すかを選べます")
    }

    // MARK: rememberedPen (0-13, §2.3)

    func testRememberedPen() throws {
        let suite = "test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let black = InkStyle(tool: .pen, colorHex: "#1f2937", width: 3.5)
        XCTAssertEqual(ToolbarPalette.defaultPen, black)
        XCTAssertEqual(ToolbarPalette.penColorKey, "toolbar.penColor")
        XCTAssertEqual(ToolbarPalette.penWidthKey, "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.markerColorKey, "toolbar.markerColor")

        // Nothing stored: 黒・中.
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), black)

        // What the toolbar stores (`@AppStorage`: a String and a Double).
        defaults.set("#dc2626", forKey: "toolbar.penColor")
        defaults.set(6.0, forKey: "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), InkStyle(tool: .pen, colorHex: "#dc2626", width: 6))
        defaults.set("#7c3aed", forKey: "toolbar.penColor")
        defaults.set(2.0, forKey: "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), InkStyle(tool: .pen, colorHex: "#7c3aed", width: 2))
        // Upper case is the same colour.
        defaults.set("#DC2626", forKey: "toolbar.penColor")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults).colorHex, "#dc2626")

        // A colour or a width that is not in the tables falls back on its own.
        defaults.set("#123456", forKey: "toolbar.penColor")
        defaults.set(5.0, forKey: "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), black, "neither in the tables → 黒・中")
        defaults.set("#fde047", forKey: "toolbar.penColor")
        defaults.set(6.0, forKey: "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), InkStyle(tool: .pen, colorHex: "#1f2937", width: 6),
                       "a marker colour is not a pen colour → 黒, the width stays")
        defaults.set("#dc2626", forKey: "toolbar.penColor")
        defaults.set(18.0, forKey: "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), InkStyle(tool: .pen, colorHex: "#dc2626", width: 3.5),
                       "the marker width is not a pen width → 中, the colour stays")
        defaults.set(Double.nan, forKey: "toolbar.penWidth")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults).width, 3.5)
        defaults.set("thick", forKey: "toolbar.penWidth")
        defaults.set(42, forKey: "toolbar.penColor")
        XCTAssertEqual(ToolbarPalette.rememberedPen(defaults), black, "values of the wrong type")

        // The pen is always a pen and its kind is the pen.
        defaults.set("#2563eb", forKey: "toolbar.penColor")
        defaults.set(3.5, forKey: "toolbar.penWidth")
        let pen = ToolbarPalette.rememberedPen(defaults)
        XCTAssertEqual(pen.tool, .pen)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(pen)), .pen)
        XCTAssertEqual(ToolbarPalette.pen(colorHex: nil, width: nil), black)
    }

    // MARK: Eraser hint (§6.2)

    func testEraserHint() {
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: nil), "触れた線をまるごと消します")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: redThick), "触れた線をまるごと消します（消すとペンに戻ります）")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: .ink(ToolbarPalette.defaultPen)),
                       "触れた線をまるごと消します（消すとペンに戻ります）")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: yellowMarker), "触れた線をまるごと消します（消すとマーカーに戻ります）")
        // `lastInkTool` is always an ink; anything else gets no bracket.
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: .eraser), "触れた線をまるごと消します")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: .lasso), "触れた線をまるごと消します")
        XCTAssertEqual(ToolbarLogic.eraserHint(returnsTo: .eventRect), "触れた線をまるごと消します")
    }

    // MARK: Kind (moved from ToolbarView)

    func testKindMatchesTheToolbar() {
        XCTAssertEqual(ToolbarLogic.kind(of: .eraser), .eraser)
        XCTAssertEqual(ToolbarLogic.kind(of: .lasso), .lasso)
        XCTAssertEqual(ToolbarLogic.kind(of: .eventRect), .eventRect)
        for width in ToolbarPalette.penWidths {
            XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .pen, colorHex: "#1f2937", width: width.width))),
                           .pen, width.name)
        }
        for color in ToolbarPalette.markerColors {
            XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .marker, colorHex: color.hex,
                                                               width: ToolbarPalette.markerWidth))), .marker)
        }
        // The width decides (18 and up is the marker, 1.0's rule), not the ink type.
        XCTAssertEqual(ToolbarPalette.markerWidth, 18)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .pen, colorHex: "#1f2937", width: 18))), .marker)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .pen, colorHex: "#1f2937", width: 17.9995))), .marker)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .pen, colorHex: "#1f2937", width: 17.99))), .pen)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .pen, colorHex: "#1f2937", width: 30))), .marker)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkStyle(tool: .marker, colorHex: "#fde047", width: 6))), .pen)
        // The presets agree with the toolbar.
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkPresets.defaultPen)), .pen)
        XCTAssertEqual(ToolbarLogic.kind(of: .ink(InkPresets.defaultMarker)), .marker)
    }
}
