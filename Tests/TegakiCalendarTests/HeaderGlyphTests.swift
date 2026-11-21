import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §3.1, §6.1, §13.1 3): the header's symbols are ones the system has. The 等倍 button is the
// magnifying glass with a 1 and nothing else (no word, so no translation and no width test), so a name the system does not
// know would leave an empty 44 pt button. This runs on CI's simulator (iOS 27.2) only; iOS 17 is not checked (the xcode-27
// image has no iOS 17 runtime), and the symbol has been in SF Symbols since long before iOS 17 【推定】.
@MainActor
final class HeaderGlyphTests: XCTestCase {
    func testZoomResetSymbolExists() {
        XCTAssertEqual(PageHeaderView.zoomResetSymbol, "1.magnifyingglass")
        XCTAssertNotNil(UIImage(systemName: PageHeaderView.zoomResetSymbol), "the 等倍 button's symbol")
        XCTAssertEqual(PageHeaderView.zoomResetIdentifier, "header.zoomReset")
        XCTAssertEqual(PageHeaderView.zoomResetLabel, "等倍に戻す")
    }

    /// The capsule 「‹ 今日 ›」 draws ‹ › with the chevrons (never in `header.today`).
    func testCapsuleChevronsExist() {
        for name in ["chevron.left", "chevron.right"] {
            XCTAssertNotNil(UIImage(systemName: name), name)
        }
        XCTAssertEqual(L.text("header.today"), "今日", "the word alone, without ‹ ›")
    }
}
