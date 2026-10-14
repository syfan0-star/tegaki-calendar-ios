import Layout
import XCTest
@testable import TegakiCalendar

/// The pure form behind the event sheet (M3b contract §4.3, §6.3): initial values from a draft,
/// the all-day ⇄ timed conversion, duration-preserving start changes, end corrections, and the
/// validation of `draft(calendarId:)`.
final class EventEditorFormTests: XCTestCase {
    private let calendar = DayKey.deviceCalendar

    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 10, day: d) }

    private func at(_ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        day(d).startOfDay(in: calendar).addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    private func allDayDraft(_ first: Int, days: Int = 1) -> EventDraft {
        EventDraft(range: .allDay(day(first), calendar: calendar), calendarId: "cal")
            .with { $0.end = day(first).adding(days: days).startOfDay(in: calendar) }
    }

    private func timedDraft(_ d: Int, _ h0: Int, _ m0: Int, _ h1: Int, _ m1: Int) -> EventDraft {
        EventDraft(title: "", allDay: false, start: at(d, h0, m0), end: at(d, h1, m1), calendarId: "cal")
    }

    // MARK: Initial values

    func testAllDayInitialValues() {
        // One day: the exclusive end (the 15th 0:00) → the end day is the same day.
        let one = EventEditorForm(draft: allDayDraft(14), calendar: calendar)
        XCTAssertTrue(one.allDay)
        XCTAssertEqual(one.startDay, day(14))
        XCTAssertEqual(one.endDay, day(14))
        XCTAssertEqual(one.startMinute, 9 * 60)
        XCTAssertEqual(one.endMinute, 10 * 60)
        XCTAssertEqual(one.end, day(15).startOfDay(in: calendar))
        XCTAssertEqual(one.endPickerDate, day(14).startOfDay(in: calendar))

        // Three days (9th–11th, end = the 12th 0:00): the end day is the third day.
        let three = EventEditorForm(draft: allDayDraft(9, days: 3), calendar: calendar)
        XCTAssertEqual(three.startDay, day(9))
        XCTAssertEqual(three.endDay, day(11))

        // A broken draft whose end is not after the start still covers its own day.
        var broken = allDayDraft(9)
        broken.end = broken.start
        XCTAssertEqual(EventEditorForm(draft: broken, calendar: calendar).endDay, day(9))
    }

    func testTimedInitialValuesAndEndCorrection() {
        let form = EventEditorForm(draft: timedDraft(7, 10, 15, 11, 45), calendar: calendar)
        XCTAssertFalse(form.allDay)
        XCTAssertEqual(form.startDay, day(7))
        XCTAssertEqual(form.startMinute, 10 * 60 + 15)
        XCTAssertEqual(form.endDay, day(7))
        XCTAssertEqual(form.endMinute, 11 * 60 + 45)
        XCTAssertEqual(form.start, at(7, 10, 15))
        XCTAssertEqual(form.end, at(7, 11, 45))

        // end ≤ start → start + 1 h.
        let inverted = EventEditorForm(draft: timedDraft(7, 10, 0, 9, 0), calendar: calendar)
        XCTAssertEqual(inverted.end, at(7, 11, 0))
        let zero = EventEditorForm(draft: timedDraft(7, 23, 30, 23, 30), calendar: calendar)
        XCTAssertEqual(zero.endDay, day(8))
        XCTAssertEqual(zero.endMinute, 30)
    }

    // MARK: 終日 on / off

    func testSetAllDayOn() {
        // 10:00〜11:00 → the same day.
        var same = EventEditorForm(draft: timedDraft(7, 10, 0, 11, 0), calendar: calendar)
        same.setAllDay(true)
        XCTAssertTrue(same.allDay)
        XCTAssertEqual(same.startDay, day(7))
        XCTAssertEqual(same.endDay, day(7))
        // The minutes are kept for the way back.
        XCTAssertEqual(same.startMinute, 10 * 60)
        XCTAssertEqual(same.endMinute, 11 * 60)

        // 23:00〜翌 0:00 is a one-day event: the midnight end does not touch the next day.
        var midnight = EventEditorForm(draft: EventDraft(title: "", allDay: false, start: at(7, 23, 0), end: at(8, 0, 0), calendarId: "cal"), calendar: calendar)
        midnight.setAllDay(true)
        XCTAssertEqual(midnight.startDay, day(7))
        XCTAssertEqual(midnight.endDay, day(7))

        // 22:00〜翌 1:00 touches the next day.
        var overnight = EventEditorForm(draft: EventDraft(title: "", allDay: false, start: at(7, 22, 0), end: at(8, 1, 0), calendarId: "cal"), calendar: calendar)
        overnight.setAllDay(true)
        XCTAssertEqual(overnight.endDay, day(8))

        // Already all-day: nothing changes.
        var unchanged = EventEditorForm(draft: allDayDraft(14), calendar: calendar)
        let before = unchanged
        unchanged.setAllDay(true)
        XCTAssertEqual(unchanged, before)
    }

    func testSetAllDayOff() {
        // An all-day draft remembers 9:00〜10:00 and goes back to them on the start day.
        var form = EventEditorForm(draft: allDayDraft(14, days: 3), calendar: calendar)
        form.setAllDay(false)
        XCTAssertFalse(form.allDay)
        XCTAssertEqual(form.start, at(14, 9, 0))
        XCTAssertEqual(form.end, at(14, 10, 0))

        // Timed → all-day → timed restores the original minutes.
        var roundTrip = EventEditorForm(draft: timedDraft(7, 13, 30, 15, 0), calendar: calendar)
        roundTrip.setAllDay(true)
        roundTrip.setAllDay(false)
        XCTAssertEqual(roundTrip.start, at(7, 13, 30))
        XCTAssertEqual(roundTrip.end, at(7, 15, 0))

        // Remembered end ≤ start (23:30〜翌 0:30 became all-day) → start + 1 h on the way back.
        var late = EventEditorForm(draft: EventDraft(title: "", allDay: false, start: at(7, 23, 30), end: at(8, 0, 30), calendarId: "cal"), calendar: calendar)
        late.setAllDay(true)
        late.setAllDay(false)
        XCTAssertEqual(late.start, at(7, 23, 30))
        XCTAssertEqual(late.end, at(8, 0, 30))
    }

    // MARK: Start keeps the duration, end is corrected

    func testSetStartKeepsDuration() {
        // Timed, 90 minutes.
        var timed = EventEditorForm(draft: timedDraft(7, 10, 0, 11, 30), calendar: calendar)
        timed.setStart(at(9, 14, 15))
        XCTAssertEqual(timed.start, at(9, 14, 15))
        XCTAssertEqual(timed.end, at(9, 15, 45))
        // Seconds from a picker are dropped (minute-aligned).
        timed.setStart(at(9, 8, 0).addingTimeInterval(20))
        XCTAssertEqual(timed.start, at(9, 8, 0))
        XCTAssertEqual(timed.end, at(9, 9, 30))

        // All-day, three days.
        var allDay = EventEditorForm(draft: allDayDraft(9, days: 3), calendar: calendar)
        allDay.setStart(day(20).startOfDay(in: calendar))
        XCTAssertEqual(allDay.startDay, day(20))
        XCTAssertEqual(allDay.endDay, day(22))
    }

    func testSetEndCorrections() {
        var timed = EventEditorForm(draft: timedDraft(7, 10, 0, 11, 0), calendar: calendar)
        timed.setEnd(at(7, 12, 45))
        XCTAssertEqual(timed.end, at(7, 12, 45))
        // An end not after the start → start + 1 h.
        timed.setEnd(at(7, 9, 0))
        XCTAssertEqual(timed.end, at(7, 11, 0))
        timed.setEnd(at(7, 10, 0))
        XCTAssertEqual(timed.end, at(7, 11, 0))

        var allDay = EventEditorForm(draft: allDayDraft(14), calendar: calendar)
        allDay.setEnd(day(16).startOfDay(in: calendar))
        XCTAssertEqual(allDay.endDay, day(16))
        // An end day before the start day → the start day.
        allDay.setEnd(day(2).startOfDay(in: calendar))
        XCTAssertEqual(allDay.endDay, day(14))
    }

    // MARK: draft(calendarId:)

    func testDraftErrors() {
        var form = EventEditorForm(draft: timedDraft(7, 10, 0, 11, 0), calendar: calendar)
        form.title = "   "
        XCTAssertEqual(form.draft(calendarId: "cal"), .failure(.emptyTitle))

        form.title = "会議"
        form.endDay = day(7)
        form.endMinute = 9 * 60 // forced past the setters
        XCTAssertEqual(form.draft(calendarId: "cal"), .failure(.endBeforeStart))
        form.endMinute = 10 * 60
        XCTAssertEqual(form.draft(calendarId: "cal"), .failure(.endBeforeStart))

        var allDay = EventEditorForm(draft: allDayDraft(14), calendar: calendar)
        allDay.title = "旅行"
        allDay.endDay = day(13)
        XCTAssertEqual(allDay.draft(calendarId: "cal"), .failure(.endDayBeforeStart))

        XCTAssertEqual(EventFormError.emptyTitle.errorDescription, "タイトルを入力してください")
        XCTAssertEqual(EventFormError.endBeforeStart.errorDescription, "終了は開始より後にしてください")
        XCTAssertEqual(EventFormError.endDayBeforeStart.errorDescription, "終了日は開始日以降にしてください")
    }

    func testDraftValuesAndAllDayExclusiveEnd() throws {
        var allDay = EventEditorForm(draft: allDayDraft(9, days: 3), calendar: calendar)
        allDay.title = "  家族旅行 "
        allDay.location = " 箱根 "
        allDay.notes = "温泉\n\n  "
        let draft = try allDay.draft(calendarId: "family").get()
        XCTAssertEqual(draft.title, "家族旅行")
        XCTAssertEqual(draft.location, "箱根")
        XCTAssertEqual(draft.notes, "温泉")
        XCTAssertTrue(draft.allDay)
        XCTAssertEqual(draft.calendarId, "family")
        XCTAssertEqual(draft.start, day(9).startOfDay(in: calendar))
        // The inclusive end day (the 11th) becomes the exclusive next midnight (the 12th 0:00).
        XCTAssertEqual(draft.end, day(12).startOfDay(in: calendar))

        var timed = EventEditorForm(draft: timedDraft(7, 10, 0, 11, 30), calendar: calendar)
        timed.title = "打合せ"
        let timedDraft = try timed.draft(calendarId: "work").get()
        XCTAssertFalse(timedDraft.allDay)
        XCTAssertEqual(timedDraft.start, at(7, 10, 0))
        XCTAssertEqual(timedDraft.end, at(7, 11, 30))

        // A draft → form → draft round trip is the identity for a clean draft.
        let again = try EventEditorForm(draft: timedDraft, calendar: calendar).draft(calendarId: "work").get()
        XCTAssertEqual(again, timedDraft)
    }

    func testTrailingWhitespaceTrimming() {
        XCTAssertEqual(EventEditorForm.trimmingTrailingWhitespace("a b \n\t "), "a b")
        XCTAssertEqual(EventEditorForm.trimmingTrailingWhitespace("  lead"), "  lead")
        XCTAssertEqual(EventEditorForm.trimmingTrailingWhitespace("   "), "")
        XCTAssertEqual(EventEditorForm.trimmingTrailingWhitespace(""), "")
    }
}

private extension EventDraft {
    func with(_ change: (inout EventDraft) -> Void) -> EventDraft {
        var copy = self
        change(&copy)
        return copy
    }
}
