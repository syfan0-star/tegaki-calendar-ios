import Layout
import XCTest
@testable import TegakiCalendar

/// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §3.9, §5.5, §11.2 row S, 0g-24): the door of `EventStoreModel` a window of years reads
/// (`ScreenPaths.yearEventSource`, the screen's `events(from:to:allDayOnly: true)`), as the one-page year reads its events
/// (`reload`'s `allDayOnly: kind == .year`): the all-day events alone.
/// - In screenshot mode `allDayOnly` keeps the all-day ones of the demo month's events that touch the days [from, to): the
///   demo month cut to the days first (1.3's answer), then to the all-day events, in the same order.
/// - Left out it is false: the answer of 1.3 (`EventStoreModelSpanTests`, TESTS_1_3, reads it so), and false is the same.
/// - Nothing when the events cannot be read, either way.
///
/// What stays untested here, as at the head of EventStoreModelSpanTests: the unit test host has no calendar access and
/// EventKit cannot be faked without a seam in `EventKitService` (none was added, the contract's default), so the EventKit
/// branch — `EventKitService.events(…, allDayOnly: true, keepingEarlier: true)` asked with the visible calendars, keeping
/// only the all-day EKEvents of the window's years — runs only on a device (the owner's check list, row 7, and TestFlight).
/// `ScreenshotMode.current` is nil in the test host, so the demo month here is the month of `from` (the photos read
/// `--screenshot-month`).
@MainActor
final class EventStoreModelYearTests: XCTestCase {
    private var suiteName = ""
    private var scratch: UserDefaults!

    private let october = YearMonth(year: 2026, month: 10)

    /// The demo month's all-day events (`ScreenshotMode.demoEvents`, in the order made): the sports day (the 3rd), camping
    /// (the 4th–5th), the family trip (the 9th–13th), the four of the 16th, the business trip (the 21st–22nd), payday (the
    /// 25th) and the 7th's deadline; the other 16 are timed.
    private let allDayIds = ["demo-1", "demo-2", "demo-3", "demo-4", "demo-5", "demo-6", "demo-7", "demo-8", "demo-9", "demo-23"]

    override func setUp() async throws {
        suiteName = "test-\(UUID())"
        scratch = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func day(_ d: Int, _ month: Int = 10, _ year: Int = 2026) -> DayKey {
        DayKey(year: year, month: month, day: d)
    }

    /// 1.3's screenshot branch of `events(from:to:)` (the demo month of `from`, cut to the days [from, to)), word for word.
    private func demo13(from start: DayKey, to end: DayKey) -> [LayoutEvent] {
        let from = start.startOfDay()
        let until = end.startOfDay()
        return ScreenshotMode.demoEvents(for: YearMonth(year: start.year, month: start.month)).filter { $0.start < until && $0.end > from }
    }

    /// Screenshot mode: `allDayOnly` keeps the all-day events of the days and drops every timed one — the whole demo month
    /// (its ten all-day events of 26), the week of Monday 5 October (camping from before, the family trip past the end and
    /// the 7th's deadline; not the six timed events of that week), the 7th alone (the deadline of its four), the 20th (five
    /// timed events: none) — and a window page of years (2026-01-01 … 2027-01-01, the demo month January's ten).
    func testAllDayOnlyKeepsTheAllDayEventsInScreenshotMode() throws {
        let model = EventStoreModel(defaults: scratch, screenshot: true)
        XCTAssertTrue(model.status.canRead, "screenshot mode reads its demo month")
        let demo = ScreenshotMode.demoEvents(for: october)
        XCTAssertEqual(demo.count, 26, "the demo month the expectations below are written for")
        XCTAssertEqual(demo.filter(\.allDay).map(\.id), allDayIds)

        let month = model.events(from: day(1), to: day(1, 11), allDayOnly: true)
        XCTAssertEqual(month.map(\.id), allDayIds, "the month: its all-day events, in their order")
        for event in month {
            XCTAssertTrue(event.allDay, event.id)
            XCTAssertEqual(demo.first { $0.id == event.id }, event, "the demo event as it is: \(event.id)")
        }
        let week = model.events(from: day(5), to: day(12), allDayOnly: true)
        XCTAssertEqual(week.map(\.id), ["demo-2", "demo-3", "demo-23"])
        XCTAssertEqual(model.events(from: day(5), to: day(12)).count, 9, "the week's nine with the timed ones")
        XCTAssertEqual(model.events(from: day(7), to: day(8), allDayOnly: true).map(\.id), ["demo-23"], "the 7th: its deadline alone")
        XCTAssertEqual(model.events(from: day(7), to: day(8)).count, 4)
        XCTAssertEqual(model.events(from: day(20), to: day(21), allDayOnly: true), [], "the 20th has timed events only")
        XCTAssertEqual(model.events(from: day(20), to: day(21)).count, 5)
        XCTAssertEqual(model.events(from: day(4), to: day(5), allDayOnly: true).map(\.id), ["demo-2"],
                       "the sports day ends at the 4th's 0:00: not on the 4th")

        // A window page of years: one query of its year (`SpanSession.eventQueries`), the demo month of `from` (January).
        let year = model.events(from: day(1, 1), to: day(1, 1, 2027), allDayOnly: true)
        XCTAssertEqual(year.map(\.id), allDayIds, "the year: the demo month's ten all-day events")
        XCTAssertEqual(year, ScreenshotMode.demoEvents(for: YearMonth(year: 2026, month: 1)).filter(\.allDay))
        XCTAssertEqual(model.events(from: day(1, 1), to: day(1, 1, 2027)).count, 26, "without it: all 26")
    }

    /// Left out, `allDayOnly` is false, and false gives 1.3's answer (the frozen EventStoreModelSpanTests read it): the demo
    /// month's events that touch the days, timed ones included, unchanged and in their order.
    func testLeftOutOrFalseTheAnswerIs1_3s() {
        let model = EventStoreModel(defaults: scratch, screenshot: true)
        let ranges: [(DayKey, DayKey)] = [
            (day(5), day(12)), (day(4), day(5)), (day(6), day(7)), (day(2), day(3)), (day(7), day(8)), (day(29), day(31)),
            (day(28, 9), day(5)), (day(1), day(1, 11)), (day(1, 1), day(1, 1, 2027)), (day(28, 12, 2025), day(5, 2, 2026)),
        ]
        for (from, to) in ranges {
            let old = demo13(from: from, to: to)
            XCTAssertEqual(model.events(from: from, to: to), old, "\(from) … \(to): left out")
            XCTAssertEqual(model.events(from: from, to: to, allDayOnly: false), old, "\(from) … \(to): false")
        }
        XCTAssertEqual(model.events(from: day(5), to: day(12)).filter { !$0.allDay }.count, 6, "the timed ones are kept")
    }

    /// Every range of one, two, seven and 42 days from 20 September to 10 November: `allDayOnly` is the all-day part of the
    /// same range's answer, in the same order — nothing more (no timed event), nothing less (no all-day one dropped).
    func testAllDayOnlyIsTheAllDayPartOfEveryRange() {
        let model = EventStoreModel(defaults: scratch, screenshot: true)
        var start = day(20, 9)
        var ranges = 0
        var kept = 0
        while start <= day(10, 11) {
            for length in [1, 2, 7, 42] {
                let end = start.adding(days: length)
                let all = model.events(from: start, to: end)
                let allDay = model.events(from: start, to: end, allDayOnly: true)
                XCTAssertEqual(allDay, all.filter(\.allDay), "\(start) + \(length)")
                XCTAssertFalse(allDay.contains { !$0.allDay }, "\(start) + \(length): no timed event")
                ranges += 1
                kept += allDay.count
            }
            start = start.adding(days: 1)
        }
        XCTAssertEqual(ranges, 4 * 52, "52 first days")
        XCTAssertGreaterThan(kept, 0, "some all-day event in the ranges")
    }

    /// Without read access (the test host has none) there are no events, with `allDayOnly` or without; the same days in
    /// screenshot mode have some.
    func testNothingWhenTheEventsCannotBeRead() throws {
        let model = EventStoreModel(defaults: scratch, screenshot: false)
        try XCTSkipIf(model.status.canRead, "this host can read the calendar; the test needs one that cannot (CI's simulators)")
        for allDayOnly in [false, true] {
            XCTAssertEqual(model.events(from: day(5), to: day(12), allDayOnly: allDayOnly), [], "\(allDayOnly)")
            XCTAssertEqual(model.events(from: day(1, 1), to: day(1, 1, 2027), allDayOnly: allDayOnly), [], "\(allDayOnly): a year")
        }
        model.load(kind: .year, focus: day(7), weekStart: .monday)
        XCTAssertEqual(model.events, [], "the one-page year reads none either")
        XCTAssertEqual(model.events(from: day(1, 1), to: day(1, 1, 2027), allDayOnly: true), [], "a loaded page changes nothing")
        XCTAssertFalse(EventStoreModel(defaults: scratch, screenshot: true).events(from: day(1, 1), to: day(1, 1, 2027), allDayOnly: true).isEmpty,
                       "the days have all-day events where they can be read")
    }
}
