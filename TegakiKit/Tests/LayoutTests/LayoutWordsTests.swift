import XCTest
import Foundation
import Layout

/// `LayoutWords` (docs/M7B_CONTRACT.md §0, §3.1 rule 4, F-5).
final class LayoutWordsTests: XCTestCase {
    func testMoreChipsPerLanguage() {
        XCTAssertEqual(LayoutWords.japanese, LayoutWords.of(.ja))
        XCTAssertEqual(LayoutWords.japanese.more(3), "+3件", "1.1's chip")
        XCTAssertEqual(LayoutWords.japanese.more(1), "+1件")
        XCTAssertEqual(LayoutWords.of(.en).more(3), "+3 more")
        XCTAssertEqual(LayoutWords.of(.de).more(3), "+3 weitere")
        for language in UILanguage.allCases {
            let words = LayoutWords.of(language)
            XCTAssertEqual(words.language, language)
            for n in [1, 2, 3, 99] {
                XCTAssertTrue(words.more(n).contains(String(n)), "\(language.rawValue) \(n): \(words.more(n))")
                XCTAssertFalse(words.more(n).contains("%"), "\(language.rawValue) \(n): \(words.more(n))")
                XCTAssertEqual(words.more(n), KitStrings.plural("kit.layout.more", language, count: n, [String(n)]))
            }
        }
    }

    func testTimeRangeSeparators() {
        for language in UILanguage.allCases {
            let words = LayoutWords.of(language)
            let dash: String
            switch language {
            case .ja: dash = "〜"
            case .ko: dash = "~"
            default: dash = "\u{2013}"
            }
            XCTAssertEqual(words.tailPrefix, dash, language.rawValue)
            XCTAssertEqual(words.tail("11:00"), dash + "11:00", language.rawValue)
            XCTAssertEqual(words.range("9:00", "10:30"), "9:00" + dash + "10:30", language.rawValue)
        }
        // The engines use them; the default is 1.1's.
        let tokyo = M3aFixtures.tokyo
        let start = M3aFixtures.date(2026, 10, 7, 9), end = M3aFixtures.date(2026, 10, 7, 10, 30)
        XCTAssertEqual(TimedEventEngine.timeRangeText(start: start, end: end, calendar: tokyo), "9:00〜10:30")
        XCTAssertEqual(TimedEventEngine.timeRangeText(start: start, end: end, calendar: tokyo, words: .of(.en)), "9:00\u{2013}10:30")
        let overnight = LayoutEvent(id: "e", title: "e", allDay: false, start: M3aFixtures.date(2026, 10, 6, 22), end: M3aFixtures.date(2026, 10, 7, 11), colorHex: "#2563eb", calendarId: "c")
        let dayStart = M3aFixtures.date(2026, 10, 7), dayEnd = M3aFixtures.date(2026, 10, 8)
        XCTAssertEqual(MonthLayoutEngine.timeText(for: overnight, dayStart: dayStart, dayEnd: dayEnd, calendar: tokyo), "〜11:00")
        XCTAssertEqual(MonthLayoutEngine.timeText(for: overnight, dayStart: dayStart, dayEnd: dayEnd, calendar: tokyo, words: .of(.ko)), "~11:00")
    }
}
