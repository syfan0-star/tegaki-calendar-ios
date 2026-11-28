import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §12.2, §12.4, §11.2 row S, 0g-31): screenshot mode's two arguments of the joined month,
// both off unless given — `--screenshot-span-crossing all` (`Config.spanCrossingAll`: two strokes across the memo band at the
// focus month's left boundary, one held by each page, D15) and `--screenshot-month-tall` (`Config.monthTall`: the month right of
// the photos' month has taller rows). Without them every Config, demo page and demo event is 1.4.2's (the frozen
// ScreenshotModeSpanTests' answers: the month's window pages are the one-page demo and its renamed copies, no crossing demo), so
// no photo of J-4, blank-paper, l10n-shots or the store moves. The year's sample (D1y, §5.2): with `--screenshot-span-crossing
// all` alone, one stroke on each side of the focus year's left boundary on the 20th's row; without it the year's pages are 1.4.2's.

final class ScreenshotModeMonthYearTests: XCTestCase {
    private let october = YearMonth(year: 2026, month: 10)
    /// Screenshot mode's day with `--screenshot-month 2026-10` (a Wednesday).
    private let focus = DayKey(year: 2026, month: 10, day: 7)
    private let base = ["--screenshot-mode", "--screenshot-month", "2026-10"]

    private func plan(_ weekStart: WeekStart) -> SpanPlan {
        SpanPlan(kind: .month, weekStart: weekStart, deviceClass: .iPad11, orientation: .portrait)
    }

    /// The month's window page `pageId` with the photos' defaults and the two new samples as given.
    private func monthPage(_ pageId: String, _ weekStart: WeekStart = .monday, crossingAll: Bool, monthTall: Bool,
                           empty: Bool = false) -> InkPage {
        ScreenshotMode.spanDemoPage(pageId: pageId, kind: .month, focus: focus, weekStart: weekStart, crossing: true, grown: false,
                                    empty: empty, tallYear: false, storeInk: false, weekMemo: false, crossingAll: crossingAll,
                                    monthTall: monthTall)
    }

    /// §2.1: `--screenshot-span-crossing all` turns `spanCrossingAll` on (only the value `all`, exactly); `--screenshot-month-tall`
    /// is a flag. Each alone changes nothing else; neither is read without `--screenshot-mode`.
    func testTheNewArgumentsAreRead() throws {
        XCTAssertEqual(ScreenshotMode.spanCrossingAllValue, "all")
        let plain = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-page", "month", "--screenshot-span", "on"]))
        XCTAssertFalse(plain.spanCrossingAll)
        XCTAssertFalse(plain.monthTall)
        let all = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-page", "month", "--screenshot-span", "on",
                                                             "--screenshot-span-crossing", "all"]))
        XCTAssertTrue(all.spanCrossingAll)
        XCTAssertFalse(all.monthTall)
        var back = all
        back.spanCrossingAll = false
        XCTAssertEqual(back, plain, "nothing else changes")
        for other in ["ALL", "All", "none", "on", "", "all "] {
            let config = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-span-crossing", other]), other)
            XCTAssertFalse(config.spanCrossingAll, "value \(other)")
        }
        XCTAssertFalse(try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-span-crossing"])).spanCrossingAll, "no value")
        XCTAssertTrue(try XCTUnwrap(ScreenshotMode.parse(["--screenshot-span-crossing", "all"] + base)).spanCrossingAll,
                      "anywhere in the arguments")

        let tall = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-page", "month", "--screenshot-span", "on", "--screenshot-month-tall"]))
        XCTAssertTrue(tall.monthTall)
        XCTAssertFalse(tall.spanCrossingAll)
        var untall = tall
        untall.monthTall = false
        XCTAssertEqual(untall, plain, "nothing else changes")
        let both = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-month-tall", "--screenshot-span-crossing", "all"]))
        XCTAssertTrue(both.spanCrossingAll && both.monthTall)
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-span-crossing", "all", "--screenshot-month-tall"]), "never without --screenshot-mode")
    }

    /// §12.2: the Config of every argument list of 1.4.2 has both off and is the same with them given and taken out again, so
    /// a photo taken with the old arguments does not move.
    func testTheOldArgumentsGiveTheSameConfig() throws {
        let old: [[String]] = [
            [],
            ["--screenshot-page", "month"],
            ["--screenshot-page", "month", "--screenshot-span", "on"],
            ["--screenshot-page", "month", "--screenshot-span", "on", "--screenshot-offset-x", "-0.5"],
            ["--screenshot-page", "month", "--screenshot-span", "on", "--screenshot-single-page"],
            ["--screenshot-page", "month", "--screenshot-zoom", "fit", "--screenshot-probe"],
            ["--screenshot-page", "month", "--screenshot-grown", "--screenshot-memo-paper", "dots"],
            ["--screenshot-page", "week", "--screenshot-span", "on", "--screenshot-span-guide", "two", "--screenshot-week-memo"],
            ["--screenshot-page", "day", "--screenshot-span", "on", "--screenshot-span-shift", "1"],
            ["--screenshot-page", "year", "--screenshot-tall-year", "--screenshot-landscape"],
            ["--screenshot-sheet", "settings", "--screenshot-settings-section", "page"],
            ["--screenshot-week-start", "sunday", "--screenshot-holidays", "US-CA", "--screenshot-store-ink"],
            ["--screenshot-hand", "left", "--screenshot-palette", "left", "--screenshot-color-panel", "1"],
        ]
        for extra in old {
            let name = extra.joined(separator: " ")
            let config = try XCTUnwrap(ScreenshotMode.parse(base + extra), name)
            XCTAssertFalse(config.spanCrossingAll, name)
            XCTAssertFalse(config.monthTall, name)
            var given = try XCTUnwrap(ScreenshotMode.parse(base + extra + ["--screenshot-span-crossing", "all", "--screenshot-month-tall"]), name)
            XCTAssertTrue(given.spanCrossingAll && given.monthTall, name)
            given.spanCrossingAll = false
            given.monthTall = false
            XCTAssertEqual(given, config, "\(name): the same Config")
        }
        // 1.2.3's tests build `Config(page:month:today:focus:sheet:)`: both off.
        let short = ScreenshotMode.Config(page: .month, month: october, today: Date(), focus: focus, sheet: nil)
        XCTAssertFalse(short.spanCrossingAll)
        XCTAssertFalse(short.monthTall)
    }

    /// §12.2, §8.5 (the frozen ScreenshotModeSpanTests stays): without the two arguments a month's window page is what 1.4.2
    /// made — the focus page the one-page demo byte for byte, a neighbour the demo of its own month with its ids made its own,
    /// no crossing demo (`crossingDemoStrokeIds(.month)` stays empty) — on both week starts, and the defaults (no screenshot
    /// mode in the tests) are off; the demo events are 1.4.2's.
    func testWithoutThemTheMonthsSamplesAreTheFrozenOnes() {
        XCTAssertNil(ScreenshotMode.current, "the unit tests run outside screenshot mode")
        let none = ScreenshotMode.crossingDemoStrokeIds(.month)
        XCTAssertEqual(none.left + none.focus, [], "the month has no 1.3 crossing demo")
        for weekStart in WeekStart.allCases {
            let plan = plan(weekStart)
            let centre = plan.index(containing: focus)
            for offset in -2...2 {
                let id = plan.pageId(at: centre + offset)
                let page = monthPage(id, weekStart, crossingAll: false, monthTall: false)
                XCTAssertEqual(page, ScreenshotMode.spanDemoPage(pageId: id, kind: .month, focus: focus, weekStart: weekStart, crossing: true,
                                                                 grown: false, empty: false, tallYear: false, storeInk: false),
                               "\(id): the defaults are off")
                XCTAssertFalse(page.liveStrokeIds.contains { $0.hasPrefix("demo-stroke-cross-month") || $0.hasPrefix("demo-stroke-month-tall") }, id)
                let own = ScreenshotMode.demoPage(kind: .month, focus: plan.firstDay(at: centre + offset), grown: false, empty: false,
                                                  tallYear: false, weekStart: weekStart, storeInk: false)
                if offset == 0 {
                    XCTAssertEqual(page, own, "\(id): the one-page demo")
                } else {
                    XCTAssertEqual(Set(page.liveStrokeIds), Set(own.liveStrokeIds.map { ScreenshotMode.neighborDemoId($0, pageId: id) }), id)
                }
            }
        }
        XCTAssertEqual(ScreenshotMode.demoEvents(for: october, empty: false, language: .ja, storeInk: false, monthTall: false),
                       ScreenshotMode.demoEvents(for: october, empty: false, language: .ja, storeInk: false), "the demo events are 1.4.2's")
    }

    /// §2.1, §12.4, D15: with `--screenshot-span-crossing all` the page left of the photos' month and the photos' month each
    /// hold one stroke of the memo band's sample, in `memo` coordinates — the left one centred left of the boundary (−80 lu),
    /// past the left page's right edge, the focus one centred right of it (+80 lu), off the focus page's left edge — and the
    /// window lays each in its owner's memo (`SpanLayout.drop`); no other page has one, and nothing with `empty`. With
    /// `--screenshot-month-tall` the month right of it has three lines in its 25th and five all-day events on its 18th, after
    /// every other event (no id moves).
    func testTheMonthsCrossingSampleHasOneStrokeOnEachSide() throws {
        let plan = plan(.monday)
        let centre = plan.index(containing: focus)
        let ids = ScreenshotMode.monthCrossingStrokeIds
        let left = monthPage(plan.pageId(at: centre - 1), crossingAll: true, monthTall: false)
        let middle = monthPage(plan.pageId(at: centre), crossingAll: true, monthTall: false)
        XCTAssertEqual(left.pageId, "m1-2026-09")
        XCTAssertEqual(middle.pageId, "m1-2026-10")
        XCTAssertTrue(left.liveStrokeIds.contains(ids.left))
        XCTAssertFalse(left.liveStrokeIds.contains(ids.focus))
        XCTAssertTrue(middle.liveStrokeIds.contains(ids.focus))
        XCTAssertFalse(middle.liveStrokeIds.contains(ids.left))
        for offset in [-2, 1, 2] {
            let other = monthPage(plan.pageId(at: centre + offset), crossingAll: true, monthTall: false)
            XCTAssertFalse(other.liveStrokeIds.contains { $0.hasPrefix("demo-stroke-cross-month") }, "\(offset)")
        }
        let leftStroke = try XCTUnwrap(left.strokes[ids.left])
        let focusStroke = try XCTUnwrap(middle.strokes[ids.focus])
        XCTAssertEqual(leftStroke.cell, .memo)
        XCTAssertEqual(focusStroke.cell, .memo)
        func span(_ stroke: InkStroke) -> (min: CGFloat, max: CGFloat, centre: CGFloat) {
            let xs = stroke.points.map(\.x)
            let low = xs.min() ?? 0
            let high = xs.max() ?? 0
            return (low, high, (low + high) / 2)
        }
        XCTAssertEqual(span(leftStroke).centre, 1_400 - 80, accuracy: 1e-9, "left of the boundary, in the left page's own coordinates")
        XCTAssertGreaterThan(span(leftStroke).max, 1_400, "past the left page's right edge, not cut")
        XCTAssertEqual(span(focusStroke).centre, 80, accuracy: 1e-9, "right of the boundary")
        XCTAssertLessThan(span(focusStroke).min, 0, "off the focus page's left edge, not cut")

        // The window (the months laid out without events) lays each in its owner's memo.
        let words = LayoutWords.of(.ja)
        let pages: [any PageLayout] = [centre - 1, centre].map { index in
            let first = plan.firstDay(at: index)
            return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: first.year, month: first.month), events: [], inkBottoms: [:],
                                                             now: Date(timeIntervalSince1970: 1_790_000_000), words: words, weekStart: .monday))
        }
        let window = SpanLayout(pages: pages, plan: plan, firstIndex: centre - 1)
        for (stroke, owner, slot) in [(leftStroke, left.pageId, 0), (focusStroke, middle.pageId, 1)] {
            let memo = try XCTUnwrap(window.cells[SpanName.prefixed(.memo, page: owner)])
            let ys = stroke.points.map(\.y)
            let centrePoint = CGPoint(x: window.origin(ofSlot: slot) + span(stroke).centre,
                                      y: memo.minY + ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2)
            XCTAssertEqual(window.drop(center: centrePoint), .keep(page: owner, cell: .memo), stroke.id)
        }

        let empty = monthPage(plan.pageId(at: centre), crossingAll: true, monthTall: true, empty: true)
        XCTAssertEqual(empty.liveStrokeIds, [], "nothing with --screenshot-empty")
        let week = ScreenshotMode.spanDemoPage(pageId: PageNavigation.pageId(.week, focus: focus), kind: .week, focus: focus, crossing: false,
                                               grown: false, empty: false, tallYear: false, storeInk: false, weekMemo: false,
                                               crossingAll: true, monthTall: true)
        XCTAssertFalse(week.liveStrokeIds.contains { $0.hasPrefix("demo-stroke-cross-month") || $0.hasPrefix("demo-stroke-month-tall") },
                       "the month's samples are the month's")

        // --screenshot-month-tall: the month right of the photos' month.
        let right = monthPage(plan.pageId(at: centre + 1), crossingAll: false, monthTall: true)
        XCTAssertEqual(right.pageId, "m1-2026-11")
        let tallIds = ["demo-stroke-month-tall-1", "demo-stroke-month-tall-2", "demo-stroke-month-tall-3"]
        XCTAssertTrue(Set(right.liveStrokeIds).isSuperset(of: tallIds))
        for id in tallIds {
            XCTAssertEqual(right.strokes[id]?.cell, .day(DayKey(year: 2026, month: 11, day: ScreenshotMode.monthTallStrokeDay)), id)
        }
        XCTAssertFalse(monthPage(plan.pageId(at: centre), crossingAll: false, monthTall: true).liveStrokeIds.contains { tallIds.contains($0) },
                       "the photos' own month has none")
        let events = ScreenshotMode.demoEvents(for: october, empty: false, language: .ja, storeInk: false, monthTall: false)
        let tallEvents = ScreenshotMode.demoEvents(for: october, empty: false, language: .ja, storeInk: false, monthTall: true)
        XCTAssertEqual(Array(tallEvents.prefix(events.count)), events, "no id moves")
        let added = Array(tallEvents.dropFirst(events.count))
        XCTAssertEqual(added.count, 5)
        let eighteenth = DayKey(year: 2026, month: 11, day: ScreenshotMode.monthTallEventDay)
        for event in added {
            XCTAssertTrue(event.allDay, event.id)
            XCTAssertEqual(DayKey(event.start, calendar: DayKey.deviceCalendar), eighteenth, event.id)
        }
        XCTAssertEqual(added.map(\.id), (0..<5).map { "demo-\(events.count + 1 + $0)" })
    }

    // MARK: D1y — the year's sample (§5.2, §12.4)

    private func yearPlan() -> SpanPlan {
        SpanPlan(kind: .year, weekStart: .monday, deviceClass: .iPad11, orientation: .portrait)
    }

    /// The year's window page `pageId` with the photos' defaults and `--screenshot-span-crossing all` as given.
    private func yearPage(_ pageId: String, crossingAll: Bool, empty: Bool = false) -> InkPage {
        ScreenshotMode.spanDemoPage(pageId: pageId, kind: .year, focus: focus, weekStart: .monday, crossing: true, grown: false,
                                    empty: empty, tallYear: false, storeInk: false, weekMemo: false, crossingAll: crossingAll,
                                    monthTall: false)
    }

    /// §12.2, §8.5 (the frozen ScreenshotModeSpanTests stays): without `--screenshot-span-crossing all` a year's window page is
    /// what 1.4.2 made — the focus page the one-page demo byte for byte, a neighbour the demo of its own year's 10/7 with its
    /// ids made its own, no crossing sample (`crossingDemoStrokeIds(.year)` stays empty: the year's sample is not 1.3's
    /// `crossing:` demo) — and the defaults (no screenshot mode in the tests) are off.
    func testWithoutItTheYearsSamplesAreTheFrozenOnes() {
        XCTAssertNil(ScreenshotMode.current, "the unit tests run outside screenshot mode")
        let none = ScreenshotMode.crossingDemoStrokeIds(.year)
        XCTAssertEqual(none.left + none.focus, [], "the year has no 1.3 crossing demo")
        let plan = yearPlan()
        let centre = plan.index(containing: focus)
        for offset in -2...2 {
            let id = plan.pageId(at: centre + offset)
            XCTAssertEqual(id, String(format: "y-%04d", 2026 + offset))
            let page = yearPage(id, crossingAll: false)
            XCTAssertEqual(page, ScreenshotMode.spanDemoPage(pageId: id, kind: .year, focus: focus, weekStart: .monday, crossing: true,
                                                             grown: false, empty: false, tallYear: false, storeInk: false),
                           "\(id): the defaults are off")
            XCTAssertFalse(page.liveStrokeIds.contains { $0.hasPrefix("demo-stroke-cross-year") }, id)
            let own = ScreenshotMode.demoPage(kind: .year, focus: DayKey(year: 2026 + offset, month: 10, day: 7), grown: false, empty: false,
                                              tallYear: false, weekStart: .monday, storeInk: false)
            if offset == 0 {
                XCTAssertEqual(page, own, "\(id): the one-page demo")
            } else {
                XCTAssertEqual(Set(page.liveStrokeIds), Set(own.liveStrokeIds.map { ScreenshotMode.neighborDemoId($0, pageId: id) }), id)
            }
        }
    }

    /// §5.2, §12.4, D15: with `--screenshot-span-crossing all` the year left of the photos' year and the photos' year each hold
    /// one stroke on the 20th's row across the boundary, held by the page of its bounds' centre x: the left one in the left
    /// year's December (`.yearDay(12, 20)`, its cell at x 1,288), from x 1,300 to 1,440 of that year — past its right edge, not
    /// cut — centred at 1,370 (30 lu left of the boundary); the focus one in the focus year's January (`.yearDay(1, 20)`, the
    /// cell at x 56), from x −40 to 100 — off the focus year's left edge — centred at +30 in the day-number column, which
    /// January holds. The window lays each in its owner's cell (`SpanLayout.drop`); neither makes its row taller than 60 lu;
    /// no other page has one, nothing with `empty`, nothing on another kind.
    func testTheYearsCrossingSampleHasOneStrokeOnEachSide() throws {
        let plan = yearPlan()
        let centre = plan.index(containing: focus)
        let ids = ScreenshotMode.yearCrossingStrokeIds
        let left = yearPage(plan.pageId(at: centre - 1), crossingAll: true)
        let middle = yearPage(plan.pageId(at: centre), crossingAll: true)
        XCTAssertEqual(left.pageId, "y-2025")
        XCTAssertEqual(middle.pageId, "y-2026")
        XCTAssertTrue(left.liveStrokeIds.contains(ids.left))
        XCTAssertFalse(left.liveStrokeIds.contains(ids.focus))
        XCTAssertTrue(middle.liveStrokeIds.contains(ids.focus))
        XCTAssertFalse(middle.liveStrokeIds.contains(ids.left))
        for offset in [-2, 1, 2] {
            let other = yearPage(plan.pageId(at: centre + offset), crossingAll: true)
            XCTAssertFalse(other.liveStrokeIds.contains { $0.hasPrefix("demo-stroke-cross-year") }, "\(offset)")
        }
        let leftStroke = try XCTUnwrap(left.strokes[ids.left])
        let focusStroke = try XCTUnwrap(middle.strokes[ids.focus])
        XCTAssertEqual(leftStroke.cell, .yearDay(month: 12, day: ScreenshotMode.yearCrossingDay))
        XCTAssertEqual(focusStroke.cell, .yearDay(month: 1, day: ScreenshotMode.yearCrossingDay))
        XCTAssertEqual(ScreenshotMode.yearCrossingDay, 20)
        /// The stroke's x in its own page (its cell's x added) from its points' bounds.
        func span(_ stroke: InkStroke, cellX: CGFloat) -> (min: CGFloat, max: CGFloat, centre: CGFloat) {
            let xs = stroke.points.map(\.x)
            let low = (xs.min() ?? 0) + cellX
            let high = (xs.max() ?? 0) + cellX
            return (low, high, (low + high) / 2)
        }
        let december: CGFloat = 56 + 11 * 112
        let january: CGFloat = 56
        XCTAssertEqual(span(leftStroke, cellX: december).min, 1_300, accuracy: 1e-9)
        XCTAssertEqual(span(leftStroke, cellX: december).max, 1_440, accuracy: 1e-9, "past the left year's right edge, not cut")
        XCTAssertEqual(span(leftStroke, cellX: december).centre, 1_400 - 30, accuracy: 1e-9, "left of the boundary, in its own year")
        XCTAssertEqual(span(focusStroke, cellX: january).min, -40, accuracy: 1e-9, "off the focus year's left edge, not cut")
        XCTAssertEqual(span(focusStroke, cellX: january).max, 100, accuracy: 1e-9)
        XCTAssertEqual(span(focusStroke, cellX: january).centre, 30, accuracy: 1e-9, "right of the boundary, in the day-number column")
        for stroke in [leftStroke, focusStroke] {
            XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: stroke.bottom), 60, "\(stroke.id): the row stays 60 lu")
            XCTAssertLessThan(stroke.bottom, 48, stroke.id)
        }

        // The window (the two years laid out without events) lays each in its owner's cell.
        let pages: [any PageLayout] = [centre - 1, centre].map { index in
            YearLayoutEngine.layout(YearLayoutInput(year: plan.firstDay(at: index).year, events: [], inkBottoms: [:],
                                                    now: Date(timeIntervalSince1970: 1_790_000_000)))
        }
        let window = SpanLayout(pages: pages, plan: plan, firstIndex: centre - 1)
        for (stroke, owner, slot, cellX) in [(leftStroke, left.pageId, 0, december), (focusStroke, middle.pageId, 1, january)] {
            let cell = try XCTUnwrap(window.cells[SpanName.prefixed(stroke.cell, page: owner)])
            let ys = stroke.points.map(\.y)
            let centrePoint = CGPoint(x: window.origin(ofSlot: slot) + span(stroke, cellX: cellX).centre,
                                      y: cell.minY + ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2)
            XCTAssertEqual(window.drop(center: centrePoint), .keep(page: owner, cell: stroke.cell), stroke.id)
        }

        XCTAssertEqual(yearPage(plan.pageId(at: centre), crossingAll: true, empty: true).liveStrokeIds, [], "nothing with --screenshot-empty")
        for kind in [PageKind.week, .day, .month] {
            let page = ScreenshotMode.spanDemoPage(pageId: PageNavigation.pageId(kind, focus: focus), kind: kind, focus: focus, crossing: true,
                                                   grown: false, empty: false, tallYear: false, storeInk: false, weekMemo: false,
                                                   crossingAll: true, monthTall: false)
            XCTAssertFalse(page.liveStrokeIds.contains { $0.hasPrefix("demo-stroke-cross-year") }, "\(kind): the year's sample is the year's")
        }
    }
}
