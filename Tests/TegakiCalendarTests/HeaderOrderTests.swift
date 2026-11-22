import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §3.4, §4.2, §16.2, §16.6; 0e-3, 0e-5 and 0e-13 as §16.12 reads them): the header's
// order, one pure table (`HeaderOrder.pieces(arm:hand:readOnly:)`) for every row, hand and read-only state. The right hand's
// rows are §16.2's (plan B: the title at the left end, 「‹ 今日 ›」 at the right end with 等倍 right inside it); the left
// hand's are the same rows reversed (never a right-to-left layout: inside the capsule ◀ stays before ▶, and the switch keeps
// 日週月年). The badge only on the wide row while read only, between the switch and 「＋予定」. 「‹ 今日 ›」 and 等倍 at the
// writing hand's end of every row they are on, the title at the other end. Mutation MH1 (the left hand not reversed) fails
// `testLeftHandIsTheRightHandReversed`, `testBadgeSitsBetweenTheSwitchAndAdd` (its left-hand row) and
// `testTodayAndZoomResetSitAtTheWritingHandsEnd` (tools/mutations/m1-expected.tsv on r141-q-m1, §16.7).
@MainActor
final class HeaderOrderTests: XCTestCase {
    private func pieces(_ arm: HeaderOrder.Arm, _ hand: Hand, readOnly: Bool = false) -> [HeaderPiece] {
        HeaderOrder.pieces(arm: arm, hand: hand, readOnly: readOnly)
    }

    /// §16.2's table for the right hand (plan B).
    func testRightHandRows() {
        XCTAssertEqual(pieces(.wide, .right), [.title, .picker, .add, .sync, .settings, .zoomReset, .today])
        XCTAssertEqual(pieces(.wide, .right, readOnly: true), [.title, .picker, .badge, .add, .sync, .settings, .zoomReset, .today])
        for readOnly in [false, true] {
            XCTAssertEqual(pieces(.compactFirst, .right, readOnly: readOnly), [.title, .add, .sync, .settings, .today], "\(readOnly)")
            XCTAssertEqual(pieces(.compactSecond, .right, readOnly: readOnly), [.picker, .zoomReset], "\(readOnly)")
        }
        XCTAssertEqual(HeaderOrder.Arm.allCases, [.wide, .compactFirst, .compactSecond])
        XCTAssertEqual(HeaderPiece.allCases, [.today, .zoomReset, .title, .picker, .badge, .add, .sync, .settings])
    }

    /// Every row of the left hand is the right hand's reversed (0e-13, §16.2).
    func testLeftHandIsTheRightHandReversed() {
        for arm in HeaderOrder.Arm.allCases {
            for readOnly in [false, true] {
                let right = pieces(arm, .right, readOnly: readOnly)
                XCTAssertEqual(pieces(arm, .left, readOnly: readOnly), Array(right.reversed()), "\(arm) read only \(readOnly)")
                XCTAssertNotEqual(pieces(arm, .left, readOnly: readOnly), right, "\(arm): the left hand's row is another order")
            }
        }
        XCTAssertEqual(pieces(.wide, .left), [.today, .zoomReset, .settings, .sync, .add, .picker, .title])
        XCTAssertEqual(pieces(.wide, .left, readOnly: true), [.today, .zoomReset, .settings, .sync, .add, .badge, .picker, .title])
        XCTAssertEqual(pieces(.compactFirst, .left), [.today, .settings, .sync, .add, .title])
        XCTAssertEqual(pieces(.compactSecond, .left), [.zoomReset, .picker])
    }

    /// Each piece once per header; the wide row has them all (the badge only while read only), the two compact rows
    /// together have them all but the badge (the compact rows show the notice row instead, M5-13).
    func testEveryPieceOnceAndTheBadgeOnlyOnTheWideRowWhileReadOnly() {
        for hand in Hand.allCases {
            for readOnly in [false, true] {
                let wide = pieces(.wide, hand, readOnly: readOnly)
                let compact = pieces(.compactFirst, hand, readOnly: readOnly) + pieces(.compactSecond, hand, readOnly: readOnly)
                let name = "\(hand) read only \(readOnly)"
                XCTAssertEqual(Set(wide).count, wide.count, "\(name): no piece twice on the wide row")
                XCTAssertEqual(Set(compact).count, compact.count, "\(name): no piece twice on the compact rows")
                XCTAssertEqual(Set(wide), Set(HeaderPiece.allCases).subtracting(readOnly ? [] : [HeaderPiece.badge]), name)
                XCTAssertEqual(Set(compact), Set(HeaderPiece.allCases).subtracting([HeaderPiece.badge]), name)
            }
        }
    }

    /// §3.4 (0e-5): the badge between the switch and 「＋予定」 (M5_CONTRACT §3.2's 「＋予定 の左」), mirrored for the left hand.
    func testBadgeSitsBetweenTheSwitchAndAdd() throws {
        for hand in Hand.allCases {
            let row = pieces(.wide, hand, readOnly: true)
            let badge = try XCTUnwrap(row.firstIndex(of: .badge))
            let picker = try XCTUnwrap(row.firstIndex(of: .picker))
            let add = try XCTUnwrap(row.firstIndex(of: .add))
            XCTAssertEqual(badge - picker, hand == .right ? 1 : -1, "\(hand): right after the switch")
            XCTAssertEqual(add - badge, hand == .right ? 1 : -1, "\(hand): right before 「＋予定」")
        }
    }

    /// §16.2: 「‹ 今日 ›」 at the writing hand's end of the wide row and the compact first row (the right end for the right
    /// hand, the left end for the left), 等倍 right inside it on the wide row and at the same end of the compact second row,
    /// ⚙ right inside them (the owner's 「＜今日＞と等倍は右端が右利き」); the title (the date) at the other end of the wide row
    /// and the compact first row (「年月日は一番左側でいいです」), the switch at the other end of the second row.
    func testTodayAndZoomResetSitAtTheWritingHandsEnd() {
        for hand in Hand.allCases {
            for readOnly in [false, true] {
                // Read from the writing hand's end: the right hand's from the right, the left hand's from the left.
                func fromWritingEnd(_ arm: HeaderOrder.Arm) -> [HeaderPiece] {
                    let row = pieces(arm, hand, readOnly: readOnly)
                    return hand == .right ? Array(row.reversed()) : row
                }
                let name = "\(hand) read only \(readOnly)"
                XCTAssertEqual(Array(fromWritingEnd(.wide).prefix(3)), [.today, .zoomReset, .settings], "\(name): wide")
                XCTAssertEqual(fromWritingEnd(.wide).last, .title, "\(name): wide")
                XCTAssertEqual(Array(fromWritingEnd(.compactFirst).prefix(2)), [.today, .settings], "\(name): compact first row")
                XCTAssertEqual(fromWritingEnd(.compactFirst).last, .title, "\(name): compact first row")
                XCTAssertEqual(fromWritingEnd(.compactSecond), [.zoomReset, .picker], "\(name): compact second row")
            }
        }
        XCTAssertEqual(pieces(.wide, .right).last, .today)
        XCTAssertEqual(pieces(.wide, .right).first, .title)
        XCTAssertEqual(pieces(.wide, .left).first, .today)
        XCTAssertEqual(pieces(.wide, .left).last, .title)
        XCTAssertEqual(pieces(.compactFirst, .right).last, .today)
        XCTAssertEqual(pieces(.compactFirst, .left).first, .today)
        XCTAssertEqual(pieces(.compactSecond, .right).last, .zoomReset)
        XCTAssertEqual(pieces(.compactSecond, .left).first, .zoomReset)
    }

    /// What the hand never turns (§4.2): the capsule is one piece whose three buttons are ◀, 今日, ▶ in that order whatever the
    /// hand (`todayCapsule` reads no hand), the switch's segments are 日週月年, and the header has no right-to-left layout. Read
    /// from PageHeaderView.swift in code only (XCTest does not lay the header out).
    func testTheCapsuleAndTheSwitchKeepTheirOrder() throws {
        XCTAssertEqual(PageHeaderView.pickerOrder, [.day, .week, .month, .year])
        let code = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: Self.source, encoding: .utf8)))
        let capsule = try Self.body(of: "private var todayCapsule: some View {", in: code)
        let previous = try XCTUnwrap(capsule.range(of: "Button(action: onPrevious)"), capsule)
        let today = try XCTUnwrap(capsule.range(of: "Button(action: onToday)"), capsule)
        let next = try XCTUnwrap(capsule.range(of: "Button(action: onNext)"), capsule)
        XCTAssertTrue(previous.lowerBound < today.lowerBound && today.lowerBound < next.lowerBound, "◀ 今日 ▶: \(capsule)")
        XCTAssertFalse(capsule.contains("hand"), "the capsule's inside never depends on the hand")
        XCTAssertFalse(try Self.body(of: "private var kindPicker: some View {", in: code).contains("hand"))
        for word in ["layoutDirection", "flipsForRightToLeft", "semanticContentAttribute", "rightToLeft"] {
            XCTAssertFalse(code.contains(word), "PageHeaderView has no \(word)")
        }
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let source = repository.appendingPathComponent("Sources/TegakiCalendar/Views/PageHeaderView.swift")

    /// The body of the declaration of `code` whose head (to its "{") is `head`, every run of white space one space
    /// (PageHeaderRoomTests' helper).
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
