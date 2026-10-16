import XCTest
@testable import TegakiCalendar

/// The read-only sheet's footnote (M5_CONTRACT §3.3 / §7.6, M5-31): the calendar's own reason when
/// nothing is passed, the subscription's when the app is read only.
@MainActor
final class EventEditorSheetTests: XCTestCase {
    func testReadOnlyFootnote() {
        XCTAssertEqual(EventEditorSheet.readOnlyFootnote(note: nil), "このカレンダーは変更できません（読み取り専用）")
        XCTAssertEqual(EventEditorSheet.readOnlyFootnote(note: EventEditorSheet.subscriptionNote), "予定の作成・編集は購読すると使えます。")
        XCTAssertEqual(EventEditorSheet.subscriptionNote, "予定の作成・編集は購読すると使えます。")
        XCTAssertEqual(EventEditorSheet.calendarReadOnlyNote, EventEditorSheet.readOnlyFootnote(note: nil))
        // Any other note is shown as it is.
        XCTAssertEqual(EventEditorSheet.readOnlyFootnote(note: "x"), "x")
    }
}
