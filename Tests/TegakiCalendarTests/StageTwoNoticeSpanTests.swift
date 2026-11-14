import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.3 (review C2-SHOTS-1; docs/M7C_CONTRACT.md §3.15, §8.1 N-8): stage 2's notice is a toast (`ToastView`, the
/// subheadline), and the longest one: in 1.2.3's three lines its de text (147 characters) ended in "…" on the iPhone 17
/// of span-shots' language photos, which XCUITest cannot tell (an element's label is the whole text). Measured here as
/// `WeekStartChoiceTests.testWeekStartToastsFitThreeLines` measures the week start's toasts: the simulator's UIFont at the
/// default text size, the layout's own lines, the toast's text as wide as the screen less 64 pt (the toast's 16 pt
/// paddings, twice on each side). N-8 has `SpanGuide.stageTwoNoticeLines` lines; it must fit them in the ten languages on
/// an iPhone 17 (402 pt) and on the narrowest iPhones iOS 17 runs on (375 pt: SE, mini; docs/M7B_CONTRACT.md F-15). An
/// iPhone with Display Zoom (320 pt) is only reported. Every other toast keeps 1.2.3's three lines.
final class StageTwoNoticeSpanTests: XCTestCase {
    private let font = UIFont.preferredFont(forTextStyle: .subheadline,
                                            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))

    /// The lines `text` takes at `width` (pt).
    private func lines(_ text: String, width: CGFloat) -> Int {
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        var count = 0
        var glyph = 0
        while glyph < manager.numberOfGlyphs {
            var range = NSRange()
            _ = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
            glyph = NSMaxRange(range)
            count += 1
        }
        return count
    }

    func testStageTwoNoticeFitsItsLinesDownToTheNarrowestIPhone() {
        var longest = 0
        for language in UILanguage.allCases {
            let text = L.text("span.stageTwo.notice", in: language)
            XCTAssertNotEqual(text, "span.stageTwo.notice", "\(language): N-8 is in the string table")
            var measured: [String] = []
            for screen in [402, 375] as [CGFloat] {
                let count = lines(text, width: screen - 64)
                longest = max(longest, count)
                measured.append("\(Int(screen)) pt \(count)")
                XCTAssertLessThanOrEqual(count, SpanGuide.stageTwoNoticeLines,
                                         "\(language): N-8 in \(count) lines at \(Int(screen)) pt, the toast has \(SpanGuide.stageTwoNoticeLines): \(text)")
            }
            measured.append("320 pt \(lines(text, width: 320 - 64))")
            print("stage two notice lines (\(language), \(text.count) characters): \(measured.joined(separator: ", "))")
        }
        // The measure itself: the text that was cut takes more than the three lines of the other toasts.
        XCTAssertGreaterThan(longest, ToastView.lineLimit, "de needs more than three lines at 402 pt (the review's photo)")
    }

    func testOtherToastsKeepThreeLines() {
        XCTAssertEqual(ToastView.lineLimit, 3)
        XCTAssertEqual(ToastMessage(text: "x").lineLimit, 3)
        XCTAssertEqual(ToastMessage(text: "x", isError: true).lineLimit, 3)
    }
}
