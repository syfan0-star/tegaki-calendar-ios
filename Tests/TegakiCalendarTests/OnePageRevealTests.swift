import XCTest
@testable import TegakiCalendar

// 1.4 (docs/M7D_CONTRACT.md §1.5 (b), §6; S6's lead's decision 2 (b)): on the one-page path the two other ways the canvas is
// made anew — another device's 「全て消す」 deleting the shown page's record (`remoteDeleted`, H1) and 「消して始める」 closing the
// page before the engine's answer (`chooseAccount`'s `closed:`, H2) — forget 「今日」's 1.1.1 rect, as `show` (1.1.1) and
// `eraseAllInk` (1.3 S6) do: a rect left over would take the new canvas's first layout to a cell of the old page. The
// screen's View is not run by XCTest (C3-M3), so the lines are read from the source in code only (comments and strings
// blanked, `WeekMemoSpanTests.codeOnly`), the way ScreenPathsSpanTests.testEraseAllForgetsTheTodayRect reads `eraseAllInk`.
// Both fail on 1.3's tree (no `revealRect = nil` at CalendarRootScreen.swift:1751-1758 and :2344-2348 of 7895d40).

@MainActor
final class OnePageRevealTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// H1: another device's 「全て消す」 deleted the shown page's record; past the guard (the shown page: its canvas is made
    /// anew) the rect goes with the selection and the viewport.
    func testRemoteDeletedForgetsTheTodayRect() throws {
        let code = try Self.screenCode()
        let deleted = try Self.body(of: "private func remoteDeleted(_ deletedId: String) {", in: code)
        XCTAssertTrue(deleted.hasPrefix("guard paths.remoteDeleted(deletedId, shownPageId: pageId) else { return }"), deleted)
        XCTAssertTrue(deleted.contains(" revealRect = nil "), "another device's 「全て消す」 forgets 「今日」's rect: \(deleted)")
        let afterGuard = try XCTUnwrap(deleted.range(of: "else { return }"))
        XCTAssertNotNil(deleted.range(of: "revealRect = nil", range: afterGuard.upperBound..<deleted.endIndex),
                        "after the guard: another page's deletion leaves the shown canvas and its rect alone")
    }

    /// H2: 「消して始める」 closes the page before the engine's `await` (`ScreenPaths.chooseAccount`'s `closed:`); the rect goes
    /// with the selection and the viewport there.
    func testEraseAndStartClosedForgetsTheTodayRect() throws {
        let code = try Self.screenCode()
        let choose = try Self.body(of: "private func chooseAccount(_ choice: AccountChangeChoice) {", in: code)
        let closed = try XCTUnwrap(choose.range(of: "closed: {"), choose)
        let closedBody = choose[closed.upperBound...].prefix { $0 != "}" }
        XCTAssertTrue(closedBody.contains(" revealRect = nil "), "「消して始める」 forgets 「今日」's rect: \(closedBody)")
        XCTAssertTrue(closedBody.contains(" selection = nil "), String(closedBody))
        XCTAssertTrue(closedBody.contains(" viewport = .zero "), String(closedBody))
    }

    /// CalendarRootScreen.swift in code only (comments and strings blanked).
    private static func screenCode() throws -> String {
        let url = repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift")
        return String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
    }

    /// The body of the function of `code` whose head (to its "{") is `head`, every run of white space one space (the shape of
    /// ScreenPathsSpanTests' helper, which is private there).
    private static func body(of head: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: head), "\(head) is in CalendarRootScreen.swift")
        var depth = 1
        var end = start.upperBound
        while end < code.endIndex, depth > 0 {
            if code[end] == "{" { depth += 1 } else if code[end] == "}" { depth -= 1 }
            end = code.index(after: end)
        }
        return code[start.upperBound..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
