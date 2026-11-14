import Layout
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §3.8; docs/M7C.md, the lead's decision 8 of wave C1, the last check's C1-DONE-1): the two doors
/// of `EventStoreModel` that the joined path added.
/// - `events(from:to:)` (a window page's events, `SpanSession.eventSource`): in screenshot mode the demo month's events that
///   touch the days [from, to) and no other; nothing when the events cannot be read.
/// - `detail(forEventId:among:)` (the sheet of an event of another page of the window): an event of `among` is found; with
///   the default, empty `among` the answer is 1.2.3's `detail(forEventId:)` for the same inputs.
///
/// What stays untested here: the unit test host has no calendar access and EventKit cannot be faked without a seam in
/// `EventKitService` (none was added), so the EventKit branch — the visible calendars, `EventKitService.events(…,
/// keepingEarlier: true)` keeping the EKEvents of earlier pages, and `detail`'s fields from a real EKEvent (its own title,
/// location, notes, URL, calendar title, recurrence, editability) — runs only on a device (TestFlight, §11.3). The not-
/// readable answer is the model's guard and EventKitService's own (both answer empty, so removing one alone is not seen
/// here). `ScreenshotMode.current` is nil in the test host, so the demo month here is the month of `from` (the photos
/// read `--screenshot-month`).
@MainActor
final class EventStoreModelSpanTests: XCTestCase {
    private var suiteName = ""
    private var scratch: UserDefaults!

    private let october = YearMonth(year: 2026, month: 10)
    private let september = YearMonth(year: 2026, month: 9)

    override func setUp() async throws {
        suiteName = "test-\(UUID())"
        scratch = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func day(_ d: Int, _ month: Int = 10) -> DayKey {
        DayKey(year: 2026, month: month, day: d)
    }

    private func ids(_ events: [LayoutEvent]) -> Set<String> {
        Set(events.map(\.id))
    }

    /// 1.2.3's `EventStoreModel.detail(forEventId:)` (43fe366, Calendar/EventStoreModel.swift), word for word, with the
    /// model's private `screenshot` passed in: the answer the default `among` must keep.
    private func detail123(_ model: EventStoreModel, forEventId id: String, screenshot: Bool) -> EventDetail? {
        guard let layoutEvent = model.layoutEvent(id: id) else { return nil }
        let ekEvent = model.service.event(withLayoutId: id)
        let location = ekEvent?.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = ekEvent?.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        // The sheet edits the event's own title: an untitled event stays empty there, not 「（無題）」.
        let title = ekEvent.map { ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) } ?? layoutEvent.title
        let calendarTitle: String
        if let ekTitle = ekEvent?.calendar?.title {
            calendarTitle = ekTitle
        } else if screenshot {
            calendarTitle = ScreenshotMode.calendarTitle(forCalendarId: layoutEvent.calendarId)
        } else {
            calendarTitle = ""
        }
        return EventDetail(
            id: id,
            title: title,
            allDay: layoutEvent.allDay,
            start: layoutEvent.start,
            end: layoutEvent.end,
            calendarId: layoutEvent.calendarId,
            calendarTitle: calendarTitle,
            colorHex: layoutEvent.colorHex,
            location: (location ?? "").isEmpty ? nil : location,
            notes: (notes ?? "").isEmpty ? nil : notes,
            url: ekEvent?.url,
            isRecurring: model.isRecurring(eventId: id),
            isEditable: model.isEditable(eventId: id)
        )
    }

    /// An event of another page of the window (not among the shown page's loaded events).
    private func windowEvent(id: String = "window-page-event", title: String = "隣のページの予定") -> LayoutEvent {
        let start = day(14).startOfDay().addingTimeInterval(9 * 3600)
        return LayoutEvent(id: id, title: title, allDay: false, start: start, end: start.addingTimeInterval(45 * 60),
                           colorHex: "#33b679", calendarId: "demo-family")
    }

    // MARK: - events(from:to:)

    /// Screenshot mode: the demo month's events that touch the days [from, to), unchanged, and no other; an event that ends
    /// at the first day's midnight or starts at the end's midnight is outside (the all-day ends are exclusive midnights).
    func testScreenshotEventsAreTheDemoMonthsThatTouchTheDays() throws {
        let model = EventStoreModel(defaults: scratch, screenshot: true)
        XCTAssertTrue(model.status.canRead, "screenshot mode reads its demo month")
        let demo = ScreenshotMode.demoEvents(for: october)
        XCTAssertEqual(demo.count, 26, "the demo month the expectations below are written for")

        // The week of Monday 5 October: camping (4–5, from before), the family trip (9–13, past the end), the 6th, 8th and
        // 9th's timed events and the 7th's four; not the sports day (3rd), the dentist (2nd) nor the 13th's meeting.
        let week = model.events(from: day(5), to: day(12))
        XCTAssertEqual(ids(week), ["demo-2", "demo-3", "demo-11", "demo-12", "demo-13", "demo-23", "demo-24", "demo-25", "demo-26"])
        XCTAssertEqual(week.count, 9, "each once")
        for event in week {
            XCTAssertEqual(demo.first { $0.id == event.id }, event, "the demo event as it is: \(event.id)")
        }

        XCTAssertEqual(model.events(from: day(4), to: day(5)).map(\.id), ["demo-2"],
                       "the sports day of the 3rd ends at the 4th's 0:00: not on the 4th")
        XCTAssertEqual(model.events(from: day(6), to: day(7)).map(\.id), ["demo-11"],
                       "camping ends at the 6th's 0:00: not on the 6th")
        XCTAssertEqual(model.events(from: day(2), to: day(3)).map(\.id), ["demo-10"],
                       "the sports day starts at the 3rd's 0:00: not on the 2nd")
        XCTAssertEqual(ids(model.events(from: day(7), to: day(8))), ["demo-23", "demo-24", "demo-25", "demo-26"], "the 7th")
        XCTAssertEqual(model.events(from: day(29), to: day(31)), [], "days without a demo event")

        // Only the demo month (the month of `from` without `--screenshot-month`): the week of Monday 28 September has
        // September's lunch of the 28th, not October's 3rd–4th that the week also touches.
        let crossing = model.events(from: day(28, 9), to: day(5))
        let septemberLunch = try XCTUnwrap(ScreenshotMode.demoEvents(for: september).first { $0.id == "demo-22" })
        XCTAssertEqual(crossing, [septemberLunch])
        XCTAssertNotEqual(crossing.first, demo.first { $0.id == "demo-22" }, "September's, not October's 28th")
    }

    /// Without read access (the test host has none) a window page has no events, whatever its days; the same days in
    /// screenshot mode have some. The default model is the process's mode (not screenshot mode in the test host).
    func testNoEventsWhenTheyCannotBeRead() throws {
        let model = EventStoreModel(defaults: scratch, screenshot: false)
        try XCTSkipIf(model.status.canRead, "this host can read the calendar; the test needs one that cannot (CI's simulators)")
        XCTAssertEqual(model.events(from: day(5), to: day(12)), [])
        XCTAssertEqual(model.events(from: day(1), to: day(1, 11)), [])
        model.load(kind: .week, focus: day(7), weekStart: .monday)
        XCTAssertEqual(model.events, [])
        XCTAssertEqual(model.events(from: day(5), to: day(12)), [], "a loaded page changes nothing")

        XCTAssertEqual(EventStoreModel(defaults: scratch).events(from: day(5), to: day(12)), [], "the process's mode")
        XCTAssertFalse(EventStoreModel(defaults: scratch, screenshot: true).events(from: day(5), to: day(12)).isEmpty,
                       "the days have events where they can be read")
    }

    // MARK: - detail(forEventId:among:)

    /// An event of another page of the window is found among the others, with what the sheet shows of it; the shown page's
    /// own event comes first when an event of the same id is among the others too; an id in neither is nil.
    func testDetailFindsAnEventOfTheWindowAmongTheOthers() throws {
        let model = EventStoreModel(defaults: scratch, screenshot: true)
        model.load(kind: .day, focus: day(7), weekStart: .monday)
        XCTAssertEqual(model.events.count, 26, "screenshot mode loads the whole demo month")
        let other = windowEvent()
        XCTAssertNil(model.layoutEvent(id: other.id))

        XCTAssertNil(model.detail(forEventId: other.id), "not loaded: nil, as in 1.2.3")
        let found = try XCTUnwrap(model.detail(forEventId: other.id, among: [windowEvent(id: "x"), other]))
        XCTAssertEqual(found, EventDetail(id: other.id, title: "隣のページの予定", allDay: false, start: other.start, end: other.end,
                                          calendarId: "demo-family", calendarTitle: ScreenshotMode.calendarTitle(forCalendarId: "demo-family"),
                                          colorHex: "#33b679", location: nil, notes: nil, url: nil, isRecurring: false, isEditable: true))
        XCTAssertFalse(found.calendarTitle.isEmpty, "the demo calendar's name")
        XCTAssertEqual(model.layoutEvent(id: other.id, among: [other]), other)
        XCTAssertNil(model.detail(forEventId: "nowhere", among: [other]))

        // The shown page's event first.
        let meeting = try XCTUnwrap(model.layoutEvent(id: "demo-24"))
        let twin = windowEvent(id: "demo-24", title: "同じ id の別の予定")
        let shown = try XCTUnwrap(model.detail(forEventId: "demo-24", among: [twin]))
        XCTAssertEqual(shown.title, meeting.title)
        XCTAssertEqual(shown.start, meeting.start)
        XCTAssertEqual(shown, model.detail(forEventId: "demo-24"))
        XCTAssertEqual(model.layoutEvent(id: "demo-24", among: [twin]), meeting)

        // Without calendar access (the test host): found among the others too, with no calendar name and not editable.
        let plain = EventStoreModel(defaults: scratch, screenshot: false)
        try XCTSkipIf(plain.status.canRead, "this host can read the calendar")
        plain.load(kind: .week, focus: day(7), weekStart: .monday)
        XCTAssertNil(plain.detail(forEventId: other.id))
        XCTAssertEqual(plain.detail(forEventId: other.id, among: [other]),
                       EventDetail(id: other.id, title: "隣のページの予定", allDay: false, start: other.start, end: other.end,
                                   calendarId: "demo-family", calendarTitle: "", colorHex: "#33b679", location: nil, notes: nil,
                                   url: nil, isRecurring: false, isEditable: false))
    }

    /// The default, empty `among` answers as 1.2.3's `detail(forEventId:)` (the copy above) for every id of the loaded page,
    /// an event of the window that is not loaded and ids of nothing, in screenshot mode and outside it, before and after a
    /// page is loaded.
    func testDetailWithoutOthersIs1_2_3sAnswer() throws {
        for screenshot in [true, false] {
            let model = EventStoreModel(defaults: scratch, screenshot: screenshot)
            var asked = ["demo-1", "demo-24", "window-page-event", "nowhere", ""]
            for id in asked {
                XCTAssertNil(detail123(model, forEventId: id, screenshot: screenshot))
                XCTAssertEqual(model.detail(forEventId: id), detail123(model, forEventId: id, screenshot: screenshot))
            }
            for (kind, focus) in [(PageKind.week, day(7)), (.day, day(16)), (.month, day(1, 11)), (.year, day(7))] {
                model.load(kind: kind, focus: focus, weekStart: .monday)
                asked = model.events.map(\.id) + ["window-page-event", "nowhere", ""]
                var found = 0
                for id in asked {
                    let old = detail123(model, forEventId: id, screenshot: screenshot)
                    if old != nil { found += 1 }
                    XCTAssertEqual(model.detail(forEventId: id), old, "\(screenshot) \(kind) \(id)")
                    XCTAssertEqual(model.detail(forEventId: id, among: []), old, "\(screenshot) \(kind) \(id)")
                }
                XCTAssertEqual(found, model.events.count, "\(screenshot) \(kind)")
                if screenshot {
                    XCTAssertEqual(found, 26, "\(kind): the demo month's every event answered")
                }
            }
        }
    }
}
