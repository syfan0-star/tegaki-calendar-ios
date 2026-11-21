import Layout
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// The toolbar's and the lasso menu's words in all ten languages (docs/M7B_CONTRACT.md §4.4, §4.5, §7.2):
/// measured with the simulator's fonts, so a translation that is too long fails here and not in the
/// person's hand. A name over 38 pt is listed in the log (it shrinks to fit); the limits fail the test.
@MainActor
final class ToolbarFitTests: XCTestCase {
    private typealias Row = ToolbarLogic.Row

    private let toolKeys = ["toolbar.tool.pen", "toolbar.tool.marker", "toolbar.tool.eraser", "toolbar.tool.lasso", "toolbar.tool.event"]
    private let collapseKey = "toolbar.collapse.title"
    private let widthKeys = ["toolbar.width.thin", "toolbar.width.medium", "toolbar.width.thick"]
    private let fingerKey = "toolbar.fingerToggle"
    private let eraserHintKeys = ["toolbar.hint.eraser", "toolbar.hint.eraser.toPen", "toolbar.hint.eraser.toMarker"]
    private let otherHintKeys = ["toolbar.hint.lasso", "toolbar.hint.event"]
    private let menuKeys = ["selection.makeEvent", "selection.delete", "selection.deselect"]

    private func width(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: weight)]).width
    }

    /// The width a name takes in the row: 38 in every language but Japanese (F-12).
    private func labelWidth(_ key: String, _ language: UILanguage) -> CGFloat {
        Row.labelFrameWidth(for: language) ?? width(L.text(key, in: language), size: 10)
    }

    private func toolButtonWidth(_ key: String, _ language: UILanguage) -> CGFloat {
        max(Row.buttonMinWidth, labelWidth(key, language) + 2 * Row.labelInset)
    }

    private func widthButtonWidth(_ key: String, _ language: UILanguage) -> CGFloat {
        max(Row.widthButtonMinWidth, labelWidth(key, language) + 2 * Row.widthLabelInset)
    }

    // MARK: F-12

    func testToolLabelsFitInEveryLanguage() {
        for language in UILanguage.allCases {
            for key in toolKeys + [collapseKey] + widthKeys {
                let text = L.text(key, in: language)
                let measured = width(text, size: 10)
                if measured > 38 {
                    print("toolbar fit: \(language.rawValue) \(key) \"\(text)\" is \(measured) pt, shrinks in the 38 pt frame")
                }
                XCTAssertLessThanOrEqual(measured, 47.5, "\(language.rawValue) \(key) \"\(text)\" does not fit 38 pt at 0.8")
            }
        }
    }

    /// `ToolbarLogicTests.testRowWinsBackTheCollapseButton`'s four formulas with the widths of each
    /// language. With F-12 only the 13-inch formula changes between languages (the finger toggle).
    func testRowKeepsWhatOneOneShowedInEveryLanguage() {
        let japaneseFinger = width(L.text(fingerKey, in: .ja), size: 13)
        let gap = 2 * Row.groupSpacing + 1
        for language in UILanguage.allCases {
            let collapse = toolButtonWidth(collapseKey, language)
            func visible(_ screen: CGFloat) -> CGFloat {
                screen - 2 * ToolbarLogic.sidePadding - (1 + Row.collapseLeading + collapse + Row.collapseTrailing)
            }
            let tools = toolKeys.reduce(CGFloat(0)) { $0 + toolButtonWidth($1, language) }
            let swatches = Row.paddingLeading + tools + gap
            let ringEnd = swatches + (Row.swatchWidth + 32) / 2
            let widths = swatches + 6 * Row.swatchWidth + gap
            let thickEnd = widths + widthKeys.reduce(CGFloat(0)) { $0 + widthButtonWidth($1, language) }
            let undo = thickEnd + gap
            let redoArrowEnd = undo + 2 * Row.historyButtonWidth - 13.5
            let finger = 108.5 + width(L.text(fingerKey, in: language), size: 13) - japaneseFinger
            let rowEnd = undo + 2 * Row.historyButtonWidth + gap + finger + Row.paddingTrailing
            let name = language.rawValue
            XCTAssertLessThanOrEqual(redoArrowEnd, visible(834) - Row.fadeWidth, "\(name): 11-inch, ↶ ↷")
            XCTAssertLessThanOrEqual(ringEnd, visible(402) - Row.fadeWidth, "\(name): iPhone 17, the first colour with its ring")
            XCTAssertLessThanOrEqual(thickEnd, visible(744) - Row.fadeWidth, "\(name): iPad mini, 細中太")
            XCTAssertLessThanOrEqual(rowEnd, visible(1032), "\(name): 13-inch, all of it")
        }
    }

    // MARK: F-13

    func testFingerToggleFitsTheThirteenInchRow() {
        let japanese = width(L.text(fingerKey, in: .ja), size: 13)
        for language in UILanguage.allCases {
            let text = L.text(fingerKey, in: language)
            XCTAssertLessThanOrEqual(width(text, size: 13) - japanese, 76, "\(language.rawValue) \"\(text)\"")
        }
    }

    // MARK: F-14

    func testHintsAreAtMostTwoLinesAndFit() {
        for key in eraserHintKeys + otherHintKeys {
            let japanese = L.text(key, in: .ja).components(separatedBy: "\n").map { width($0, size: 12) }.max() ?? 0
            for language in UILanguage.allCases {
                let text = L.text(key, in: language)
                let lines = text.components(separatedBy: "\n")
                XCTAssertLessThanOrEqual(lines.count, 2, "\(language.rawValue) \(key)")
                for line in lines {
                    XCTAssertLessThanOrEqual(width(line, size: 12), japanese + 0.01, "\(language.rawValue) \(key) \"\(line)\"")
                }
            }
        }
    }

    func testEraserHintsShareTheFirstLine() {
        for language in UILanguage.allCases {
            let first = L.text("toolbar.hint.eraser", in: language)
            for key in eraserHintKeys.dropFirst() {
                let text = L.text(key, in: language)
                XCTAssertTrue(text.hasPrefix(first), "\(language.rawValue) \(key): \"\(text)\" does not start with \"\(first)\"")
            }
        }
    }

    // MARK: The paths

    func testJapaneseToolbarTakesTheOneOnePath() {
        XCTAssertNil(Row.labelFrameWidth(for: .ja))
        for language in UILanguage.allCases where language != .ja {
            XCTAssertEqual(Row.labelFrameWidth(for: language), 38, language.rawValue)
        }
        XCTAssertEqual(Row.labelMinScale, 0.8)
        // The app runs in Japanese here, and no Japanese name widens its button (J-4).
        XCTAssertEqual(L.language, .ja)
        for key in toolKeys + [collapseKey] {
            XCTAssertEqual(toolButtonWidth(key, .ja), Row.buttonMinWidth, key)
        }
        for key in widthKeys {
            XCTAssertEqual(widthButtonWidth(key, .ja), Row.widthButtonMinWidth, key)
        }
    }

    // MARK: 1.4.1: the vertical bar (docs/R1_4_1_CONTRACT.md §4.8, §6.3)

    /// The vertical bar's column is 48 pt in every language: the five tools and 「しまう」 keep the row's faces (F-12's
    /// 38 pt names, Japanese by its width: 48 wide), 細中太 fit the 48 too, the swatches are 44 × 38 cells (the chosen
    /// colour's 32 pt ring inside), ↶ ↷ and 「指でも書く」 44 × 44. With the pen the column is about 843 pt (§4.8's
    /// estimate 830): the whole of it on an iPad upright and on the 13-inch on its side. The row's guarantees above are
    /// unchanged.
    func testVerticalColumnFitsInEveryLanguage() {
        typealias Column = ToolbarLogic.Column
        XCTAssertEqual(2 * Column.sidePadding + Column.width, ToolbarLogic.verticalBarWidth)
        XCTAssertEqual(Column.width, Row.buttonMinWidth)
        XCTAssertLessThanOrEqual(Column.swatchWidth, Column.width)
        XCTAssertLessThanOrEqual(Column.cellSide, Column.width)
        XCTAssertLessThanOrEqual(32, Column.swatchHeight, "the chosen colour's ring")
        XCTAssertLessThanOrEqual(Column.dividerLength, Column.width)
        for language in UILanguage.allCases {
            for key in toolKeys + [collapseKey] {
                XCTAssertLessThanOrEqual(toolButtonWidth(key, language), Column.width, "\(language.rawValue) \(key)")
            }
            for key in widthKeys {
                XCTAssertLessThanOrEqual(widthButtonWidth(key, language), Column.width, "\(language.rawValue) \(key)")
            }
        }

        let gap = 2 * Row.groupSpacing + 1
        // The tools, the six colours, 細中太, ↶ ↷ and 「指でも書く」, 44 (38 a colour) tall each, a divider between groups.
        let pen = Row.paddingLeading + 5 * Column.cellSide + gap + 6 * Column.swatchHeight + gap + 3 * Column.cellSide
            + gap + 2 * Column.cellSide + gap + Column.cellSide + Row.paddingTrailing
        let collapse = 1 + Row.collapseLeading + 44 + Row.collapseTrailing
        print("toolbar fit: the vertical pen column is \(pen + collapse) pt (\(pen) scrolling + \(collapse) for 「しまう」)")
        XCTAssertEqual(pen + collapse, 843)
        // The 13-inch on its side: 1032 tall, less the status bar 24, the home indicator 20, one header row 56 and the
        // slot's 6 above and under (about 920).
        XCTAssertLessThanOrEqual(pen + collapse, 1032 - 24 - 20 - 56 - 12)
    }

    /// `ToolbarView(axis:)` as the screen lays it out: `.vertical` is 60 pt wide and as tall as offered (it fills its
    /// slot); `.horizontal`, the default, is 1.4's bar, 60 pt tall (44 + 8 + 8; YearTapUITests reads its top) and as wide
    /// as offered.
    func testToolbarViewAxisSizes() {
        func size(_ axis: Axis?, tool: CanvasTool) -> CGSize {
            let view: ToolbarView
            if let axis {
                view = ToolbarView(tool: .constant(tool), allowFinger: .constant(false), onUndo: {}, onRedo: {},
                                   showsCollapseButton: true, axis: axis)
            } else {
                view = ToolbarView(tool: .constant(tool), allowFinger: .constant(false), onUndo: {}, onRedo: {},
                                   showsCollapseButton: true)
            }
            XCTAssertEqual(view.axis, axis ?? .horizontal)
            return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 700, height: 900))
        }
        for tool in [CanvasTool.ink(ToolbarPalette.defaultPen), .eraser, .lasso] {
            let vertical = size(.vertical, tool: tool)
            XCTAssertEqual(vertical.width, ToolbarLogic.verticalBarWidth, accuracy: 0.5, "\(tool)")
            XCTAssertEqual(vertical.height, 900, accuracy: 0.5, "\(tool): the slot's height")
            let horizontal = size(nil, tool: tool)
            XCTAssertEqual(horizontal.height, ToolbarLogic.barHeight, accuracy: 0.5, "\(tool)")
            XCTAssertEqual(horizontal.width, 700, accuracy: 0.5, "\(tool)")
            XCTAssertEqual(size(.horizontal, tool: tool), horizontal)
        }
    }

    // MARK: F-15

    func testSelectionMenuFitsTheNarrowestIPhone() {
        var over: [String] = []
        for language in UILanguage.allCases {
            var total: CGFloat = 0
            for (index, key) in menuKeys.enumerated() {
                total += width(L.text(key, in: language), size: 14, weight: index == 0 ? .semibold : .regular)
            }
            if total > 220 {
                over.append("\(language.rawValue) \(total) pt")
            }
        }
        XCTAssertEqual(over, [], "the three words of the lasso's menu must be at most 220 pt together")
    }
}
