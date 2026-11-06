import XCTest
import Foundation
import Access
import DayKit

/// `LegalLinks` per language (docs/M7B_CONTRACT.md D11, 0-38).
final class LegalLinksTests: XCTestCase {
    private let japanese = ["https://syfan0-star.github.io/tegaki-calendar/app/terms.html",
                            "https://syfan0-star.github.io/tegaki-calendar/app/privacy.html",
                            "https://syfan0-star.github.io/tegaki-calendar/app/support.html"]
    private let english = ["https://syfan0-star.github.io/tegaki-calendar/app/en/terms.html",
                           "https://syfan0-star.github.io/tegaki-calendar/app/en/privacy.html",
                           "https://syfan0-star.github.io/tegaki-calendar/app/en/support.html"]

    private func urls(_ language: UILanguage, published: Bool) -> [String] {
        [LegalLinks.terms(for: language, published: published), LegalLinks.privacy(for: language, published: published), LegalLinks.support(for: language, published: published)].map(\.absoluteString)
    }

    func testURLsPerLanguage() {
        XCTAssertFalse(LegalLinks.englishPagesPublished, "the English pages go up on the day 1.2 is released; true from 1.3 (0-38)")
        for language in UILanguage.allCases {
            XCTAssertEqual(urls(language, published: false), japanese, language.rawValue)
            XCTAssertEqual(urls(language, published: true), language == .ja ? japanese : english, language.rawValue)
            XCTAssertEqual([LegalLinks.terms(for: language), LegalLinks.privacy(for: language), LegalLinks.support(for: language)].map(\.absoluteString), japanese, "1.2: \(language.rawValue)")
        }
        XCTAssertEqual(urls(UILanguage.resolve("th"), published: true), english, "a Thai screen is English (O-1)")
        XCTAssertEqual([LegalLinks.terms, LegalLinks.privacy, LegalLinks.support].map(\.absoluteString), japanese, "the 1.1 values stay")
    }

    func testAppleEULATitle() {
        XCTAssertEqual(LegalLinks.appleEULATitle(.ja), LegalLinks.appleEULATitle)
        XCTAssertEqual(LegalLinks.appleEULATitle(.ja), "使用許諾契約（Apple 標準 EULA）")
        for language in UILanguage.allCases where language != .ja {
            XCTAssertFalse(LegalLinks.appleEULATitle(language).isEmpty, language.rawValue)
            XCTAssertNotEqual(LegalLinks.appleEULATitle(language), LegalLinks.appleEULATitle, language.rawValue)
        }
    }
}
