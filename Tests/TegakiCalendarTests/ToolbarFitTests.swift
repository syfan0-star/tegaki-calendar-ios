import Layout
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
