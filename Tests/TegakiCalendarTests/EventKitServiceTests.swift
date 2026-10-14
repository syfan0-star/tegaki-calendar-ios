import EventKit
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// The pure parts of the EventKit bridge (contract §5, M3b §6.3): all-day end normalisation,
/// colours, the ink colour helpers of the toolbar, and `apply(_:to:calendar:)` (an `EKEvent` can be
/// made without calendar access; nothing is saved).
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

    // MARK: - M3b: draft → EKEvent

    private func makeStoreAndCalendar() -> (EKEventStore, EKCalendar) {
        let store = EKEventStore()
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "テスト"
        return (store, calendar)
    }

    func testApplyAllDayDraftWritesLastDayEnd() throws {
        let (store, calendar) = makeStoreAndCalendar()
        let event = EKEvent(eventStore: store)
        // The 9th–11th: the draft's end is the exclusive 12th 0:00.
        let draft = EventDraft(
            title: "  家族旅行 ",
            allDay: true,
            start: midnight(2026, 10, 9),
            end: midnight(2026, 10, 12),
            calendarId: "x",
            location: "   ",
            notes: "温泉 \n\n"
        )
        try EventKitService.apply(draft, to: event, calendar: calendar)
        XCTAssertTrue(event.isAllDay)
        XCTAssertEqual(event.title, "家族旅行")
        XCTAssertEqual(event.startDate, midnight(2026, 10, 9))
        // EventKit's shape: the last day's 23:59:59.
        XCTAssertEqual(event.endDate, midnight(2026, 10, 12).addingTimeInterval(-1))
        XCTAssertNil(event.location)
        XCTAssertEqual(event.notes, "温泉")
        XCTAssertTrue(event.calendar === calendar)
        // Reading it back gives the exclusive midnight again.
        XCTAssertEqual(EventKitService.exclusiveAllDayEnd(start: event.startDate, eventEnd: event.endDate), midnight(2026, 10, 12))
    }

    func testApplyTimedDraftKeepsInstants() throws {
        let (store, calendar) = makeStoreAndCalendar()
        let event = EKEvent(eventStore: store)
        let start = midnight(2026, 10, 7).addingTimeInterval(10 * 3600)
        let end = start.addingTimeInterval(90 * 60)
        let draft = EventDraft(title: "打合せ", allDay: false, start: start, end: end, calendarId: "x", location: " 会議室 A ", notes: "")
        try EventKitService.apply(draft, to: event, calendar: calendar)
        XCTAssertFalse(event.isAllDay)
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, end)
        XCTAssertEqual(event.location, "会議室 A")
        XCTAssertNil(event.notes)
        // An empty title is stored empty (EventKit allows it).
        try EventKitService.apply(EventDraft(title: "  ", allDay: false, start: start, end: end, calendarId: "x"), to: event, calendar: nil)
        XCTAssertEqual(event.title, "")
        XCTAssertTrue(event.calendar === calendar, "an update never changes the calendar")
    }

    func testApplyWithoutAnyCalendarThrows() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let draft = EventDraft(title: "x", allDay: false, start: midnight(2026, 10, 7), end: midnight(2026, 10, 8), calendarId: "x")
        XCTAssertThrowsError(try EventKitService.apply(draft, to: event, calendar: nil)) { error in
            XCTAssertEqual(error as? EventWriteError, .calendarNotFound)
        }
    }

    func testWriteErrorMessagesAreJapanese() {
        XCTAssertEqual(EventWriteError.noAccess.errorDescription, "カレンダーへのアクセスが許可されていません")
        XCTAssertEqual(EventWriteError.noWritableCalendar.errorDescription, "予定を登録できるカレンダーがありません")
        XCTAssertEqual(EventWriteError.calendarNotFound.errorDescription, "登録先のカレンダーが見つかりません")
        XCTAssertEqual(EventWriteError.readOnlyCalendar.errorDescription, "このカレンダーは変更できません")
        XCTAssertEqual(EventWriteError.eventNotFound.errorDescription, "予定が見つかりません（別の端末で削除されたかもしれません）")
        XCTAssertEqual(EventWriteError.invalidRange.errorDescription, "終了は開始より後にしてください")
        XCTAssertEqual(EventWriteError.failed("boom").errorDescription, "保存できませんでした: boom")
        XCTAssertEqual(EventSpan.thisEvent.ekSpan, .thisEvent)
        XCTAssertEqual(EventSpan.futureEvents.ekSpan, .futureEvents)
    }

    func testDraftFromDetailAndRange() {
        let range = EventRange.timed(DayKey(year: 2026, month: 10, day: 7), startMinute: 540, endMinute: 600, calendar: calendar)
        let fromRange = EventDraft(range: range, calendarId: "cal")
        XCTAssertEqual(fromRange.title, "")
        XCTAssertFalse(fromRange.allDay)
        XCTAssertEqual(fromRange.start, range.start)
        XCTAssertEqual(fromRange.end, range.end)
        XCTAssertEqual(fromRange.calendarId, "cal")

        let detail = EventDetail(
            id: "e@1", title: "歯医者", allDay: false,
            start: range.start, end: range.end,
            calendarId: "personal", calendarTitle: "個人", colorHex: "#e67c73",
            location: "駅前", notes: nil, url: nil, isRecurring: true, isEditable: true
        )
        let fromDetail = EventDraft(detail: detail)
        XCTAssertEqual(fromDetail.title, "歯医者")
        XCTAssertEqual(fromDetail.location, "駅前")
        XCTAssertEqual(fromDetail.notes, "")
        XCTAssertEqual(fromDetail.calendarId, "personal")
    }

    func testSelectionMenuPlacement() {
        let bounds = CGRect(x: 8, y: 8, width: 784, height: 1000)
        let size = CGSize(width: 300, height: 44)
        // Room above: 10 pt above the anchor, centred.
        let above = SelectionMenuView.placement(anchor: CGRect(x: 300, y: 400, width: 100, height: 50), size: size, bounds: bounds)
        XCTAssertEqual(above.x, 200, accuracy: 0.001)
        XCTAssertEqual(above.y, 400 - 10 - 44, accuracy: 0.001)
        // No room above: 10 pt below.
        let below = SelectionMenuView.placement(anchor: CGRect(x: 300, y: 20, width: 100, height: 50), size: size, bounds: bounds)
        XCTAssertEqual(below.y, 70 + 10, accuracy: 0.001)
        // Neither: just under the anchor's top edge, clamped inside.
        let over = SelectionMenuView.placement(anchor: CGRect(x: 300, y: 20, width: 100, height: 1200), size: size, bounds: bounds)
        XCTAssertEqual(over.y, 30, accuracy: 0.001)
        // Horizontal clamp at the edges.
        let left = SelectionMenuView.placement(anchor: CGRect(x: -100, y: 400, width: 20, height: 20), size: size, bounds: bounds)
        XCTAssertEqual(left.x, 8, accuracy: 0.001)
        let right = SelectionMenuView.placement(anchor: CGRect(x: 900, y: 400, width: 20, height: 20), size: size, bounds: bounds)
        XCTAssertEqual(right.x, 792 - 300, accuracy: 0.001)
    }
}

