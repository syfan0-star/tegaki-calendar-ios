import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// The pure parts of the EventKit bridge (contract §5): all-day end normalisation, colours, and the
/// ink colour helpers of the toolbar.
@MainActor
final class EventKitServiceTests: XCTestCase {
    private let calendar = DayKey.deviceCalendar

    private func midnight(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DayKey(year: y, month: m, day: d).startOfDay(in: calendar)
    }

    func testExclusiveAllDayEnd() {
        let start = midnight(2026, 10, 4)

        // EventKit's "end of the last day" (23:59:59) → the next midnight, exclusive.
        XCTAssertEqual(
            EventKitService.exclusiveAllDayEnd(start: start, eventEnd: midnight(2026, 10, 5).addingTimeInterval(-1)),
            midnight(2026, 10, 5)
        )
        // Three days: 10/4, 10/5, 10/6 → ends at 10/7 0:00.
        XCTAssertEqual(
            EventKitService.exclusiveAllDayEnd(start: start, eventEnd: midnight(2026, 10, 7).addingTimeInterval(-1)),
            midnight(2026, 10, 7)
        )
        // Already an exclusive midnight after the start: kept.
        XCTAssertEqual(EventKitService.exclusiveAllDayEnd(start: start, eventEnd: midnight(2026, 10, 6)), midnight(2026, 10, 6))
        // end == start (a broken event) still covers one day.
        XCTAssertEqual(EventKitService.exclusiveAllDayEnd(start: start, eventEnd: start), midnight(2026, 10, 5))
    }

    func testHexStringFromCGColor() {
        let blue = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)
        XCTAssertEqual(EventKitService.hexString(from: blue.cgColor), "#2563eb")
        XCTAssertEqual(EventKitService.hexString(from: UIColor.white.cgColor), "#ffffff")
        XCTAssertEqual(EventKitService.hexString(from: UIColor.black.cgColor), "#000000")
        XCTAssertEqual(EventKitService.hexString(from: nil), "#039be5")
    }

    func testInkColorHelpers() {
        XCTAssertEqual(InkColors.normalized("#ABC"), "#aabbcc")
        XCTAssertEqual(InkColors.normalized("#1F2937"), "#1f2937")
        XCTAssertNil(InkColors.normalized("red"))
        XCTAssertNil(InkColors.normalized("#12345"))

        let red = UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1)
        XCTAssertEqual(InkColors.hex(of: red), "#dc2626")
        XCTAssertEqual(InkColors.hex(of: InkColors.color(hex: "#fde047") ?? .black), "#fde047")
    }

    func testPaperPaletteParsesHex() {
        let parsed = PaperPalette.rgba(hex: "#2563eb")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.r ?? 0, 37 / 255, accuracy: 0.001)
        XCTAssertEqual(parsed?.g ?? 0, 99 / 255, accuracy: 0.001)
        XCTAssertEqual(parsed?.b ?? 0, 235 / 255, accuracy: 0.001)
        XCTAssertEqual(parsed?.a ?? 0, 1, accuracy: 0.001)
        XCTAssertNil(PaperPalette.rgba(hex: "not a colour"))
        // Dark text on yellow, white text on dark blue (WCAG contrast, like the web version).
        XCTAssertEqual(PaperPalette.readableText(on: "#fde047"), PaperPalette.ink1)
        XCTAssertEqual(PaperPalette.readableText(on: "#1e3a8a"), UIColor.white)
    }
}
