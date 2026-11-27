import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §3.9, §6.1, 0f-16): the toolbar's colour dots keep 1.4.1's rim in light mode — the same code,
/// `Color.black.opacity(0.15)`, so not a pixel of a light photo changes (J-4) — and get a light rim in dark mode, where black,
/// navy, brown and dark green melt into the bar: `ColorPanelLogic.swatchRim`'s white at 0.35, in both places a dot is drawn
/// (across, `swatch`, and upright, `verticalSwatch`), chosen by the environment's `colorScheme` (not a dynamic UIColor, whose
/// colour space could shift the light rim). Read from the source in code only (`WeekMemoSpanTests.codeOnly`): the view is not
/// run by XCTest. Fails with the dark branch written as the light one (mutation MC5).
@MainActor
final class SwatchRimTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func code(_ path: String) throws -> String {
        let url = Self.repository.appendingPathComponent(path)
        return String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func count(_ text: String, in code: String) -> Int {
        code.components(separatedBy: text).count - 1
    }

    func testTheRimsValues() {
        XCTAssertEqual(ColorPanelLogic.swatchRim(dark: false).white, false)
        XCTAssertEqual(ColorPanelLogic.swatchRim(dark: false).opacity, 0.15, "1.4.1's black at 0.15")
        XCTAssertEqual(ColorPanelLogic.swatchRim(dark: true).white, true)
        XCTAssertEqual(ColorPanelLogic.swatchRim(dark: true).opacity, 0.35)
    }

    func testBothDotsOfTheBarFollowTheScheme() throws {
        let toolbar = try code("Sources/TegakiCalendar/Views/ToolbarView.swift")
        let dark = ColorPanelLogic.swatchRim(dark: true)
        let light = ColorPanelLogic.swatchRim(dark: false)
        let darkColor = "Color.\(dark.white ? "white" : "black").opacity(\(dark.opacity))"
        let lightColor = "Color.\(light.white ? "white" : "black").opacity(\(light.opacity))"
        XCTAssertEqual(lightColor, "Color.black.opacity(0.15)", "the light rim is 1.4.1's code")
        let rim = ".overlay(Circle().strokeBorder(colorScheme == .dark ? \(darkColor) : \(lightColor)))"
        XCTAssertEqual(count(rim, in: toolbar), 2, "across and upright: \(rim)")
        XCTAssertEqual(count(".overlay(Circle().strokeBorder(Color.black.opacity(0.15)))", in: toolbar), 0,
                       "no dot of the bar keeps a rim that ignores the scheme")
        XCTAssertEqual(count("@Environment(\\.colorScheme) private var colorScheme", in: toolbar), 1)
        XCTAssertEqual(count("UIColor {", in: toolbar), 0, "no dynamic UIColor")
    }

    /// The panel's dots lie on the paper's colour in both schemes: 1.4.1's black rim there.
    func testThePanelsDotsKeepTheBlackRim() throws {
        let panel = try code("Sources/TegakiCalendar/Views/ColorPanelView.swift")
        XCTAssertEqual(count(".overlay(Circle().strokeBorder(Color.black.opacity(0.15)))", in: panel), 1)
        XCTAssertEqual(count(".fill(Color(uiColor: PaperPalette.paper))", in: panel), 1, "on the paper's colour")
    }
}
