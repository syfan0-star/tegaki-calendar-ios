import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §3.2, §3.4, §4.2, §6.1, 0e-3, 0e-5, 0e-13): the header's order, one pure table
// (`HeaderOrder.pieces(arm:hand:readOnly:)`) for every row, hand and read-only state. The right hand's rows are §2.1's; the
// left hand's are the same rows reversed (never a right-to-left layout: inside the capsule ◀ stays before ▶, and the switch
// keeps 日週月年). The badge only on the wide row while read only, between the switch and 「＋予定」. 「‹ 今日 ›」 and 等倍 at
// the free hand's end of every row they are on. Mutation MH1 (the left hand not reversed) fails
// `testLeftHandIsTheRightHandReversed` and `testTodayAndZoomResetSitOnTheFreeHandsSide`.
@MainActor
final class HeaderOrderTests: XCTestCase {
    private func pieces(_ arm: HeaderOrder.Arm, _ hand: Hand, readOnly: Bool = false) -> [HeaderPiece] {
        HeaderOrder.pieces(arm: arm, hand: hand, readOnly: readOnly)
    }

    /// §2.1's table for the right hand.
    func testRightHandRows() {
        XCTAssertEqual(pieces(.wide, .right), [.today, .zoomReset, .title, .picker, .add, .sync, .settings])
        XCTAssertEqual(pieces(.wide, .right, readOnly: true), [.today, .zoomReset, .title, .picker, .badge, .add, .sync, .settings])
        for readOnly in [false, true] {
            XCTAssertEqual(pieces(.compactFirst, .right, readOnly: readOnly), [.today, .title, .add, .sync, .settings], "\(readOnly)")
            XCTAssertEqual(pieces(.compactSecond, .right, readOnly: readOnly), [.zoomReset, .picker], "\(readOnly)")
        }
        XCTAssertEqual(HeaderOrder.Arm.allCases, [.wide, .compactFirst, .compactSecond])
        XCTAssertEqual(HeaderPiece.allCases, [.today, .zoomReset, .title, .picker, .badge, .add, .sync, .settings])
    }

    /// Every row of the left hand is the right hand's reversed (0e-13).
    func testLeftHandIsTheRightHandReversed() {
        for arm in HeaderOrder.Arm.allCases {
            for readOnly in [false, true] {
                let right = pieces(arm, .right, readOnly: readOnly)
                XCTAssertEqual(pieces(arm, .left, readOnly: readOnly), Array(right.reversed()), "\(arm) read only \(readOnly)")
                XCTAssertNotEqual(pieces(arm, .left, readOnly: readOnly), right, "\(arm): the left hand's row is another order")
            }
        }
        XCTAssertEqual(pieces(.wide, .left), [.settings, .sync, .add, .picker, .title, .zoomReset, .today])
        XCTAssertEqual(pieces(.wide, .left, readOnly: true), [.settings, .sync, .add, .badge, .picker, .title, .zoomReset, .today])
        XCTAssertEqual(pieces(.compactFirst, .left), [.settings, .sync, .add, .title, .today])
        XCTAssertEqual(pieces(.compactSecond, .left), [.picker, .zoomReset])
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

    /// 「‹ 今日 ›」 at the free hand's end of the wide row and the compact first row, 等倍 right beside it on the wide row and
    /// at the same end of the compact second row, the title right after them; ⚙ at the other end.
    func testTodayAndZoomResetSitOnTheFreeHandsSide() {
        for hand in Hand.allCases {
            // Read from the free hand's end: the right hand's from the left, the left hand's from the right.
            func fromFreeEnd(_ arm: HeaderOrder.Arm) -> [HeaderPiece] {
                let row = pieces(arm, hand)
                return hand == .right ? row : Array(row.reversed())
            }
            XCTAssertEqual(Array(fromFreeEnd(.wide).prefix(3)), [.today, .zoomReset, .title], "\(hand): wide")
            XCTAssertEqual(fromFreeEnd(.wide).last, .settings, "\(hand): wide")
            XCTAssertEqual(Array(fromFreeEnd(.compactFirst).prefix(2)), [.today, .title], "\(hand): compact first row")
            XCTAssertEqual(fromFreeEnd(.compactFirst).last, .settings, "\(hand): compact first row")
            XCTAssertEqual(fromFreeEnd(.compactSecond), [.zoomReset, .picker], "\(hand): compact second row")
        }
        XCTAssertEqual(pieces(.wide, .right).first, .today)
        XCTAssertEqual(pieces(.wide, .left).last, .today)
        XCTAssertEqual(pieces(.compactSecond, .right).first, .zoomReset)
        XCTAssertEqual(pieces(.compactSecond, .left).last, .zoomReset)
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
