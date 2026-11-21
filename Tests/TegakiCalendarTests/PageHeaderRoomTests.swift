import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §3.1–§3.3, §6.2, 0e-2, 0e-3; rewritten from 1.4 D1d's test of the tight row, which 1.4.1
// retires): the room the compact header's first row leaves the title. The row is 「‹ 今日 ›」, the title, ＋, ☁ and ⚙ (§2.1's
// `compactFirst`); 等倍 is on the second row, beside the switch. Its fixed parts are the 12 pt side paddings, the capsule (◀
// 44, 今日 its 17 pt word with 8 pt on each side and at least 44, ▶ 44), ＋ 52, ☁ 26 and ⚙ 44 (1.4's measured sizes on iOS
// 27.2, PageHeaderView's notes) and four gaps of 4: about 297.4 pt in ja (1.4's row: 324), so every iPhone has the room of
// the longest Japanese short title (「10/24〜10/30」, 69.8 pt at the minimum scale) — 1.4's row cut it below about 394 pt.
// The iPhone Duo's outer screen (382 pt) gets 84.6, more than 1.4's tight row gave it (80), so the tight row is gone
// (§3.2; duo.yml's `DuoLayoutUITests` and `shot_checks` confirm it, D1c). The source checks read the code only, as
// OnePageRevealTests does: XCTest does not lay the header out (HeaderRoomUITests and HeaderAndPaperUITests measure it).
@MainActor
final class PageHeaderRoomTests: XCTestCase {
    /// The side paddings (`CalendarRootScreen.screenColumn`: `.padding(.horizontal, 12)`).
    private let paddings: CGFloat = 12 + 12
    /// ◀ and ▶: 44 pt targets each (`todayCapsule`).
    private let chevrons: CGFloat = 44 + 44
    /// ＋ (`.bordered`, the symbol at least 28 wide), ☁ (the symbol and 4 pt each side) and ⚙ (44): 1.4's measured sizes.
    private let add: CGFloat = 52
    private let sync: CGFloat = 26
    private let settings: CGFloat = 44
    /// The first row's four gaps (`HStack(spacing: 4)` of five pieces).
    private let gaps: CGFloat = 4 * 4
    /// The longest Japanese short title at the minimum scale (17 pt × 0.6): 「10/24〜10/30」, 69.8 pt.
    private let longestTitle: CGFloat = 70

    /// 「今日」 in the capsule: its 17 pt word (the `.body` of the default text size), 8 pt on each side, at least 44.
    private func todayWidth(_ language: UILanguage = .ja) -> CGFloat {
        let word = (L.text("header.today", in: language) as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 17)]).width
        return max(44, word + 16)
    }

    /// The first row without its title.
    private func fixedWidth(_ language: UILanguage = .ja) -> CGFloat {
        paddings + chevrons + todayWidth(language) + add + sync + settings + gaps
    }

    /// The title's room in the compact first row at `width` (the column inside the safe area).
    private func room(_ width: CGFloat, _ language: UILanguage = .ja) -> CGFloat {
        width - fixedWidth(language)
    }

    /// The capsule and the row's fixed width are the contract's estimates (§3.1: the capsule about 135.4 pt in ja and
    /// 151.4 in en and de; §6.2: the row about 297.4 in ja), within the measuring's slack.
    func testFixedWidthIsTheContractsEstimate() {
        XCTAssertEqual(chevrons + todayWidth(.ja), 135.4, accuracy: 3, "the capsule in ja")
        XCTAssertEqual(fixedWidth(.ja), 297.4, accuracy: 3, "the first row's fixed parts in ja")
        XCTAssertLessThan(fixedWidth(.ja), 324, "less than 1.4's first row")
        for language in [UILanguage.en, .de] {
            XCTAssertEqual(chevrons + todayWidth(language), 151.4, accuracy: 3, "the capsule in \(language)")
        }
    }

    /// Every iPhone's compact first row has the room of the longest Japanese short title (§6.2): 375 (SE, mini), 382 (the
    /// Duo's outer screen in portrait), 393, 402 (iPhone 17, J-4) and 440 (iPhone 18 Pro Max, J-4).
    func testTheTitleHasItsRoomOnEveryIPhone() {
        for width: CGFloat in [375, 382, 390, 393, 402, 420, 430, 440] {
            XCTAssertGreaterThanOrEqual(room(width), longestTitle, "\(width) pt: \(room(width)) pt for the title")
        }
        XCTAssertGreaterThan(room(382), 80, "the Duo's outer screen: more than 1.4's tight row gave it")
    }

    /// The model's longest title, measured with the simulator's own font: every Japanese short title of 2026 and 2027
    /// (both week starts, every page kind) at the title's minimum scale (17 pt semibold × 0.6) fits the room of the
    /// narrowest iPhone (375 pt). The unit tests run in Japanese (`-testLanguage ja`), so the kanji fall back as on the
    /// owner's iPhone.
    func testLongestJapaneseShortTitleFitsTheNarrowestIPhone() {
        let font = UIFont.systemFont(ofSize: 17 * 0.6, weight: .semibold)
        func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }
        var longest: (width: CGFloat, title: String) = (0, "")
        var day = DayKey(year: 2026, month: 1, day: 1)
        let end = DayKey(year: 2028, month: 1, day: 1)
        while day < end {
            for kind in PageHeaderView.pickerOrder {
                for weekStart in [WeekStart.monday, .sunday] {
                    let title = PageNavigation.compactTitle(kind, focus: day, language: .ja, weekStart: weekStart)
                    let w = width(title)
                    if w > longest.width { longest = (w, title) }
                }
            }
            day = day.adding(days: 1)
        }
        XCTAssertGreaterThan(longest.width, 50, "the font measures (\(longest.title))")
        XCTAssertLessThanOrEqual(longest.width, room(375), "\(longest.title): \(longest.width) pt at 10.2 pt")
    }

    /// The body draws `HeaderOrder`'s rows (§2.1, §3.2): a `ForEach` over each arm's pieces with the hand and the read-only
    /// state, the second row as tall as the switch (§3.3), no spacer (the title's frame takes the room), and 1.4's tight row
    /// with its constants is gone. The screen passes the hand and 等倍 and no longer the side insets.
    func testBodyDrawsHeaderOrderWithoutTheTightRow() throws {
        let code = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: Self.source, encoding: .utf8)))
        let body = try Self.body(of: "var body: some View {", in: code)
        for arm in ["wide", "compactFirst", "compactSecond"] {
            XCTAssertTrue(body.contains("ForEach(HeaderOrder.pieces(arm: .\(arm), hand: hand, readOnly: readOnly), id: \\.self) { piece in "
                                        + "view(for: piece, in: .\(arm)) }"), "\(arm): \(body)")
        }
        XCTAssertTrue(body.contains("HStack(spacing: 6) {"), "the wide row's gap")
        XCTAssertTrue(body.contains("HStack(spacing: 4) {"), "the first row's gap")
        XCTAssertTrue(body.contains("HStack(spacing: 8) {"), "等倍 and the switch")
        XCTAssertTrue(body.contains(".fixedSize(horizontal: false, vertical: true)"), "the second row is as tall as the switch")
        XCTAssertFalse(body.contains("Spacer("), "the title's frame takes the room")
        for gone in ["usesTightRow", "tightFirstRow", "tightTitleGain", "roomyCompactWidth", "tightNavigationSpacing",
                     "tightAddEventSymbolWidth", "sideInsets"] {
            XCTAssertFalse(code.contains(gone), "PageHeaderView: \(gone) is gone")
        }
        let piece = try Self.body(of: "private func view(for piece: HeaderPiece, in arm: HeaderOrder.Arm) -> some View {", in: code)
        XCTAssertTrue(piece.contains("titleText(arm == .wide ? .title2 : .headline) .frame(maxWidth: .infinity, alignment: titleAlignment)"))
        XCTAssertTrue(piece.contains("zoomResetButton(fillsRow: arm == .compactSecond)"))
        XCTAssertTrue(piece.contains("kindPicker .frame(width: 220) .layoutPriority(1)"), "the wide row's switch is 1.4's")
        XCTAssertTrue(try Self.body(of: "private var titleAlignment: Alignment {", in: code)
            .contains("hand == .left ? .trailing : .leading"))
        let zoom = try Self.body(of: "private func zoomResetButton(fillsRow: Bool) -> some View {", in: code)
        XCTAssertTrue(zoom.contains(".frame(minWidth: 44, maxHeight: .infinity)"), "grows to the switch's height")
        XCTAssertTrue(zoom.contains(".fixedSize(horizontal: true, vertical: false)"), "never its own height")

        let screen = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: Self.screenSource, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(screen.contains("hand: hand, onZoomReset: { resetZoom() } )"), "CalendarRootScreen passes the hand and 等倍")
        XCTAssertFalse(screen.contains("sideInsets"), "the side insets are no longer passed")
        XCTAssertTrue(screen.contains("@AppStorage(AppSettings.handKey) private var handRaw = Hand.right.rawValue"))
        XCTAssertTrue(screen.contains("ScreenshotMode.hand(ScreenshotMode.current, stored: handRaw)"))
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let source = repository.appendingPathComponent("Sources/TegakiCalendar/Views/PageHeaderView.swift")
    private static let screenSource = repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")

    /// The body of the declaration of `code` whose head (to its "{") is `head`, every run of white space one space (the
    /// shape of OnePageRevealTests' helper, which is private there).
    private static func body(of head: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: head), "\(head) is in PageHeaderView.swift")
        var depth = 1
        var end = start.upperBound
        while end < code.endIndex, depth > 0 {
            if code[end] == "{" { depth += 1 } else if code[end] == "}" { depth -= 1 }
            end = code.index(after: end)
        }
        return code[start.upperBound..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
