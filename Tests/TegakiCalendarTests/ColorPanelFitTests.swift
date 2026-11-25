import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.4, §3.10, §6.1, §8.1): the colour panel's words in all ten languages, measured with the
/// simulator's fonts as ToolbarFitTests measures the bar's: 「その他の色…」 and 「最初の色に戻す」 fit their 44 pt rows (264 pt
/// across, the panel's 288 less 12 on each side) at Dynamic Type's xLarge — one line, or two, at full size or down to 0.8 —;
/// the twelve colours' names and the four new spoken texts are in every language's table; the panel fits a 375 pt iPhone. A
/// row that needs two lines or 0.8 is listed in the log (`color panel fit:`).
@MainActor
final class ColorPanelFitTests: XCTestCase {
    private typealias Logic = ColorPanelLogic

    private let buttonKeys = ["toolbar.colorPanel.otherColor", "toolbar.colorPanel.reset"]
    private let spokenKeys = ["toolbar.colorPanel.title", "toolbar.colorPanel.hint", "toolbar.colorPanel.otherColor", "toolbar.colorPanel.reset"]
    private let colorKeys = ["toolbar.color.black", "toolbar.color.blue", "toolbar.color.red", "toolbar.color.green",
                             "toolbar.color.orange", "toolbar.color.purple", "toolbar.color.brown", "toolbar.color.gray",
                             "toolbar.color.pink", "toolbar.color.lightBlue", "toolbar.color.darkGreen", "toolbar.color.navy"]

    /// The rows' font at the largest size they take (`.subheadline`, at most xLarge).
    private var largest: UIFont {
        UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraLarge))
    }

    /// The lines `text` takes across `width` with `font`, and their height.
    private func wrapped(_ text: String, font: UIFont, width: CGFloat) -> (lines: Int, height: CGFloat) {
        let box = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                  options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                  attributes: [.font: font], context: nil)
        let lines = Int((box.height / font.lineHeight).rounded())
        return (lines, ceil(box.height))
    }

    func testTheButtonsFitTheirRowsInEveryLanguage() {
        let across = Logic.panelSize.width - 2 * Logic.rowTextInset
        XCTAssertEqual(across, 264)
        let full = largest
        let small = full.withSize(full.pointSize * Logic.rowTextMinScale)
        for language in UILanguage.allCases {
            for key in buttonKeys {
                let text = L.text(key, in: language)
                XCTAssertFalse(text.isEmpty, "\(language.rawValue) \(key)")
                let one = (text as NSString).size(withAttributes: [.font: full]).width
                if one <= across { continue }
                let big = wrapped(text, font: full, width: across)
                let little = wrapped(text, font: small, width: across)
                print("color panel fit: \(language.rawValue) \(key) \"\(text)\" is \(one) pt on one line at \(full.pointSize) pt: "
                      + "\(big.lines) lines (\(big.height) pt), at 0.8 \(little.lines) lines (\(little.height) pt)")
                let fits = (big.lines <= 2 && big.height <= Logic.rowHeight) || (little.lines <= 2 && little.height <= Logic.rowHeight)
                XCTAssertTrue(fits, "\(language.rawValue) \(key) \"\(text)\" does not fit two lines of the 44 pt row")
            }
        }
    }

    func testEveryNameAndSpokenTextIsInEveryLanguage() {
        for language in UILanguage.allCases {
            for key in colorKeys + spokenKeys {
                let text = L.text(key, in: language)
                XCTAssertFalse(text.isEmpty, "\(language.rawValue) \(key)")
                XCTAssertNotEqual(text, key, "\(language.rawValue) \(key) is in the table")
            }
            let names = colorKeys.map { L.text($0, in: language) }
            XCTAssertEqual(Set(names).count, 12, "\(language.rawValue): twelve names, none twice: \(names)")
        }
        XCTAssertEqual(ToolbarPalette.panelColors.map(\.name), colorKeys.map { L.text($0, in: .ja) })
        XCTAssertEqual(ColorPanelText.title, "ペンの色を選ぶ")
        XCTAssertEqual(ColorPanelText.hint, "もう一度押すと、色を替えられます")
        XCTAssertEqual(ColorPanelText.other, "その他の色…")
        XCTAssertEqual(ColorPanelText.reset, "最初の色に戻す")
        XCTAssertEqual(L.text("toolbar.color.unknown"), "その他の色", "the spoken name of a colour of 「その他の色…」 stays")
    }

    func testThePanelFitsTheSmallestPhone() {
        XCTAssertLessThanOrEqual(Logic.panelSize.width + 2 * Logic.containerInset, 375, "the 375 pt iPhone (SE, mini)")
        let container = CGRect(x: 0, y: 0, width: 375, height: 600)
        for x in stride(from: CGFloat(0), through: 337, by: 37) {
            let dot = CGRect(x: x, y: 540, width: 38, height: 44)
            let frame = Logic.placement(anchor: dot, edge: .bottom, container: container, panel: Logic.panelSize)
            XCTAssertTrue(container.insetBy(dx: 8, dy: 8).contains(frame), "a dot at \(x): \(frame)")
        }
    }

    func testTheIdentifiers() {
        XCTAssertEqual(ColorPanelIdentifier.panel, "toolbar.colorPanel")
        XCTAssertEqual(ColorPanelIdentifier.other, "toolbar.colorPanel.other")
        XCTAssertEqual(ColorPanelIdentifier.reset, "toolbar.colorPanel.reset")
        XCTAssertEqual(ColorPanelIdentifier.color("#92400E"), "toolbar.colorPanel.92400e")
        XCTAssertEqual(Set(ToolbarPalette.panelColors.map { ColorPanelIdentifier.color($0.hex) }).count, 12)
    }
}
