import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §3.12, §10.2 U; B_DESIGN.md §5.6; the wave's decisions C3-B1, C3-m4, C3-m10): screenshot
/// mode's arguments of the joined pages and the demo pages of a window.
/// - Without them every Config, demo page, demo event and compat11 `screenshot-*.json` is 1.2.3's (the photos, the
///   UI tests and J-4 do not move; `ScreenshotModeTests` is left as it was, TESTS_1_2_3).
/// - A window's pages have ids of their own; the focus page is the one-page demo; the crossing demo sits on the two
///   pages of the focus page's left boundary, each stroke on the page of its centre (D15), off the rectangles of the
///   UI tests that run again on the joined path, and the focus page alone runs off its left edge only.
/// - `--screenshot-settings-section page` is the `settings` sheet at 「ページ」 (`ScreenshotMode.Sheet` keeps its 11
///   cases), and the switch of that section starts from screenshot mode's own memory.
@MainActor
final class ScreenshotModeSpanTests: XCTestCase {
    private let october = YearMonth(year: 2026, month: 10)
    /// Screenshot mode's day with `--screenshot-month 2026-10` (a Wednesday).
    private let focus = DayKey(year: 2026, month: 10, day: 7)
    private let base = ["--screenshot-mode", "--screenshot-month", "2026-10"]

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "test-\(UUID())"
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        AppSettings.defaults = defaults
    }

    override func tearDown() async throws {
        ScreenshotMode.pageSpan = ScreenshotMode.pageSpanAtLaunch(ScreenshotMode.current)
        AppSettings.defaults = .standard
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Helpers

    /// The demo page of `pageId` with the photos' defaults (no `--screenshot-grown`, `-empty`, `-tall-year`, `-store-ink`).
    private func spanPage(_ pageId: String, _ kind: PageKind, _ weekStart: WeekStart, crossing: Bool, grown: Bool = false) -> InkPage {
        ScreenshotMode.spanDemoPage(pageId: pageId, kind: kind, focus: focus, weekStart: weekStart, crossing: crossing,
                                    grown: grown, empty: false, tallYear: false, storeInk: false)
    }

    private func onePage(_ kind: PageKind, _ weekStart: WeekStart, day: DayKey? = nil, grown: Bool = false) -> InkPage {
        ScreenshotMode.demoPage(kind: kind, focus: day ?? focus, grown: grown, empty: false, tallYear: false,
                                weekStart: weekStart, storeInk: false)
    }

    private func plan(_ kind: PageKind, _ weekStart: WeekStart) -> SpanPlan {
        SpanPlan(kind: kind, weekStart: weekStart, deviceClass: .iPad11, orientation: .portrait)
    }

    /// The page laid out as a window page is (no events: only the cells matter here).
    private func layout(_ page: InkPage, index: Int, plan: SpanPlan) -> any PageLayout {
        let first = plan.firstDay(at: index)
        let now = ScreenshotMode.todayInstant(for: october)
        switch plan.kind {
        case .day:
            return DayLayoutEngine.layout(DayLayoutInput(day: first, events: [], inkBottoms: page.inkBottoms(), now: now))
        default:
            return WeekLayoutEngine.layout(WeekLayoutInput(focus: first, events: [], inkBottoms: page.inkBottoms(), now: now,
                                                           weekStart: plan.weekStart))
        }
    }

    /// The stroke's bounds (points ± half the nib) in its page's paper coordinates.
    private func bounds(_ stroke: InkStroke, in layout: any PageLayout) throws -> CGRect {
        let cell = try XCTUnwrap(layout.cells[stroke.cell], "\(stroke.id): its cell \(stroke.cell.raw) is on the page")
        return try XCTUnwrap(stroke.paperBounds(cellOrigin: cell.origin))
    }

    /// SettingsScreen.swift as written, each line trimmed.
    private func settingsLines() throws -> [String] {
        let url = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/SettingsScreen.swift")
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - §3.12: the window's demo pages

    /// The five pages around the focus (a window of radius 2) never share a stroke id: a neighbour is the demo of its own
    /// day with "-<pageId>" after every id; the focus page has the ids of the one-page demo (the same as
    /// `ScreenshotModeTests.testDemoPageIdsMatchTheNavigation`'s pages, so `--screenshot-select` finds them); every page
    /// passes the save guard as it is (no "|" in an id, a real page id).
    func testNeighborDemoIdsDifferPerPage() throws {
        let crossing = ScreenshotMode.crossingDemoStrokeIds(.week).left + ScreenshotMode.crossingDemoStrokeIds(.week).focus
            + ScreenshotMode.crossingDemoStrokeIds(.day).left + ScreenshotMode.crossingDemoStrokeIds(.day).focus
        for kind in [PageKind.week, .day] {
            for weekStart in WeekStart.allCases {
                let plan = plan(kind, weekStart)
                let centre = plan.index(containing: focus)
                let focusId = PageNavigation.pageId(kind, focus: focus, weekStart: weekStart)
                XCTAssertEqual(plan.pageId(at: centre), focusId)
                var holder: [String: String] = [:]
                for index in (centre - 2)...(centre + 2) {
                    let pageId = plan.pageId(at: index)
                    let name = "\(kind) \(weekStart) \(pageId)"
                    let page = spanPage(pageId, kind, weekStart, crossing: true, grown: true)
                    XCTAssertEqual(page.pageId, pageId, name)
                    XCTAssertTrue(page.deleted.isEmpty && page.unknown.isEmpty && page.unknownStrokes.isEmpty, name)
                    for id in page.strokes.keys {
                        XCTAssertNil(holder[id], "\(name): \(id) is on \(holder[id] ?? "") too")
                        holder[id] = pageId
                        XCTAssertFalse(id.contains("|"), "\(name): \(id) (K-10)")
                        XCTAssertTrue(InkStroke.isValidId(id), "\(name): \(id)")
                    }
                    XCTAssertEqual(SpanGuard.checkForSave(page, added: Set(page.strokes.keys)), .ok, name)

                    let own = page.strokes.values.filter { !crossing.contains($0.id) }
                    if index == centre {
                        // The focus page: the one-page demo, stroke for stroke.
                        XCTAssertEqual(Dictionary(uniqueKeysWithValues: own.map { ($0.id, $0) }), onePage(kind, weekStart, grown: true).strokes, name)
                    } else {
                        // A neighbour: the demo of its own day (the same weekday a week away), every id its own.
                        let day = focus.adding(days: (index - centre) * (kind == .week ? 7 : 1))
                        let demo = onePage(kind, weekStart, day: day, grown: true)
                        XCTAssertEqual(demo.pageId, pageId, name)
                        XCTAssertFalse(demo.liveStrokes.isEmpty, name)
                        var expected: [String: InkStroke] = [:]
                        for stroke in demo.liveStrokes {
                            var renamed = stroke
                            renamed.id = ScreenshotMode.neighborDemoId(stroke.id, pageId: pageId)
                            XCTAssertEqual(renamed.id, "\(stroke.id)-\(pageId)")
                            expected[renamed.id] = renamed
                        }
                        XCTAssertEqual(Dictionary(uniqueKeysWithValues: own.map { ($0.id, $0) }), expected, name)
                    }
                }
                // The same page asked for twice is the same page (the session may read a page again).
                XCTAssertEqual(spanPage(plan.pageId(at: centre + 1), kind, weekStart, crossing: true),
                               spanPage(plan.pageId(at: centre + 1), kind, weekStart, crossing: true))
            }
        }
        // A page id the kind does not read (another kind, the other week start's week) is an empty page of that id.
        XCTAssertEqual(spanPage("d-2026-10-07", .week, .monday, crossing: true), InkPage.empty(pageId: "d-2026-10-07"))
        XCTAssertEqual(spanPage("w-2026-10-04", .week, .monday, crossing: true), InkPage.empty(pageId: "w-2026-10-04"))
        // Month and year (one page at a time in 1.3) get no crossing demo; their focus page is the one-page demo.
        for kind in [PageKind.month, .year] {
            let id = PageNavigation.pageId(kind, focus: focus)
            XCTAssertEqual(spanPage(id, kind, .monday, crossing: true), onePage(kind, .monday), "\(kind)")
        }
    }

    /// Without a new argument nothing changes (§3.12, K-7, J-4): the Config of every argument list of 1.2.3 has the new
    /// fields off (it equals the Config of the old fields alone, the form 1.2.3's tests build), the window's focus page
    /// without the crossing demo is `demoPage` byte for byte and its JSON is compat11's `screenshot-*.json`, and the
    /// demo events are the ones the photos have shown since M3a.
    func testSpanArgumentsOffKeepTheOldShots() throws {
        let old: [[String]] = [
            [],
            ["--screenshot-page", "week"],
            ["--screenshot-page", "day", "--screenshot-zoom", "2", "--screenshot-offset", "0,2380", "--screenshot-probe"],
            ["--screenshot-page", "day", "--screenshot-grown", "--screenshot-select", "demo-stroke-day-extra"],
            ["--screenshot-page", "year", "--screenshot-landscape"],
            ["--screenshot-sheet", "settings"], ["--screenshot-sheet", "sync"], ["--screenshot-sheet", "info"],
            ["--screenshot-sheet", "week-start"], ["--screenshot-sheet", "lasso"], ["--screenshot-readonly"],
            ["--screenshot-toolbar", "collapsed-right", "--screenshot-tool", "eraser"],
            ["--screenshot-empty", "--screenshot-tall-year", "--screenshot-pinch-hint"],
            ["--screenshot-week-start", "sunday", "--screenshot-holidays", "US-CA", "--screenshot-store-ink"],
            ["--screenshot-page", "week", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP", "-allowFingerDrawing", "YES"],
        ]
        for extra in old {
            let name = extra.joined(separator: " ")
            let c = try XCTUnwrap(ScreenshotMode.parse(base + extra), name)
            // The Config of the old fields alone: every new field at its default.
            let oldFields = ScreenshotMode.Config(page: c.page, month: c.month, today: c.today, focus: c.focus, sheet: c.sheet,
                                                  landscape: c.landscape, zoomRatio: c.zoomRatio, offset: c.offset, readOnly: c.readOnly,
                                                  toolbar: c.toolbar, tool: c.tool, grown: c.grown, probe: c.probe, select: c.select,
                                                  empty: c.empty, tallYear: c.tallYear, pinchHint: c.pinchHint, holidays: c.holidays,
                                                  weekStart: c.weekStart, storeInk: c.storeInk)
            XCTAssertEqual(c, oldFields, name)
            XCTAssertNil(c.span, name)
            XCTAssertNil(c.spanOffsetX, name)
            XCTAssertFalse(c.spanShift, name)
            XCTAssertFalse(c.singlePage, name)
            XCTAssertNil(c.spanGuide, name)
            XCTAssertFalse(c.weekMemo, name)
            XCTAssertNil(c.settingsSection, name)
            XCTAssertFalse(c.joinsPages, name)
            XCTAssertFalse(c.crossingDemo, name)
            XCTAssertNil(c.spanOpeningOffsetX, name)
            XCTAssertFalse(ScreenshotMode.pageSpanAtLaunch(c), "\(name): the switch of 設定 › ページ starts off")
        }
        // 1.2.3's tests build `Config(page:month:today:focus:sheet:)` (ScreenshotModeTests :189, :357, :441, :830).
        let short = ScreenshotMode.Config(page: .week, month: october, today: Date(), focus: focus, sheet: nil)
        XCTAssertNil(short.span)
        XCTAssertFalse(short.joinsPages || short.crossingDemo || short.singlePage || short.spanShift || short.weekMemo)
        XCTAssertNil(short.spanGuide)
        XCTAssertNil(short.settingsSection)
        XCTAssertNil(ScreenshotMode.parse([]), "never active without --screenshot-mode")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-span", "on"]), "never active without --screenshot-mode")
        XCTAssertFalse(ScreenshotMode.pageSpanAtLaunch(nil), "normal use: off (never read there)")

        // The focus page of a window without the crossing demo is the one-page demo of every kind and week start.
        for kind in PageKind.allCases {
            for weekStart in WeekStart.allCases {
                for grown in [false, true] {
                    let id = PageNavigation.pageId(kind, focus: focus, weekStart: weekStart)
                    XCTAssertEqual(spanPage(id, kind, weekStart, crossing: false, grown: grown), onePage(kind, weekStart, grown: grown),
                                   "\(kind) \(weekStart) grown \(grown)")
                }
            }
        }
        // Byte for byte the JSON of compat11's `screenshot-*.json` (what `testDemoPagesMatchCompatFixtures` compares).
        let fixtures: [(name: String, kind: PageKind, grown: Bool)] = [
            ("screenshot-day", .day, false), ("screenshot-week", .week, false), ("screenshot-month", .month, false),
            ("screenshot-year", .year, false), ("screenshot-month-grown", .month, true), ("screenshot-day-grown", .day, true),
        ]
        let folder = Self.repository.appendingPathComponent("TegakiKit/Tests/Fixtures/compat11", isDirectory: true)
        for fixture in fixtures {
            let page = spanPage(PageNavigation.pageId(fixture.kind, focus: focus), fixture.kind, .monday, crossing: false, grown: fixture.grown)
            let stored = try Data(contentsOf: folder.appendingPathComponent("\(fixture.name).json", isDirectory: false))
            XCTAssertEqual(try InkPageCodec.encode(page), stored, fixture.name)
        }

        // The demo events of the photos (M2 and M3a), as they were: id, all-day, the October day, the start (minutes
        // after midnight; 0 all day), the length (minutes; days all day) and the calendar.
        let expected: [(String, Bool, Int, Int, Int, String)] = [
            ("demo-1", true, 3, 0, 1, "demo-events"), ("demo-2", true, 4, 0, 2, "demo-family"),
            ("demo-3", true, 9, 0, 5, "demo-family"), ("demo-4", true, 16, 0, 1, "demo-work"),
            ("demo-5", true, 16, 0, 1, "demo-personal"), ("demo-6", true, 16, 0, 1, "demo-family"),
            ("demo-7", true, 16, 0, 1, "demo-family"), ("demo-8", true, 21, 0, 2, "demo-work"),
            ("demo-9", true, 25, 0, 1, "demo-personal"), ("demo-10", false, 2, 600, 60, "demo-personal"),
            ("demo-11", false, 6, 600, 60, "demo-work"), ("demo-12", false, 8, 900, 30, "demo-work"),
            ("demo-13", false, 9, 840, 60, "demo-personal"), ("demo-14", false, 13, 600, 60, "demo-work"),
            ("demo-15", false, 20, 540, 15, "demo-work"), ("demo-16", false, 20, 600, 60, "demo-work"),
            ("demo-17", false, 20, 780, 30, "demo-work"), ("demo-18", false, 20, 900, 60, "demo-work"),
            ("demo-19", false, 20, 1080, 120, "demo-personal"), ("demo-20", false, 23, 1140, 120, "demo-personal"),
            ("demo-21", false, 27, 600, 60, "demo-work"), ("demo-22", false, 28, 690, 90, "demo-family"),
            ("demo-23", true, 7, 0, 1, "demo-personal"), ("demo-24", false, 7, 600, 90, "demo-work"),
            ("demo-25", false, 7, 630, 30, "demo-personal"), ("demo-26", false, 7, 840, 60, "demo-personal"),
        ]
        let events = ScreenshotMode.demoEvents(for: october, empty: false, language: .ja, storeInk: false)
        XCTAssertEqual(events.count, expected.count)
        let colours = Dictionary(uniqueKeysWithValues: ScreenshotMode.calendars(language: .ja).map { ($0.id, $0.colorHex) })
        for (event, row) in zip(events, expected) {
            let day = DayKey(event.start)
            let start = Int((event.start.timeIntervalSince(day.startOfDay()) / 60).rounded())
            let length = event.allDay ? DayKey(event.end).dayNumber - day.dayNumber : Int((event.end.timeIntervalSince(event.start) / 60).rounded())
            XCTAssertEqual(event.id, row.0)
            XCTAssertEqual(event.allDay, row.1, row.0)
            XCTAssertEqual(day, DayKey(year: 2026, month: 10, day: row.2), row.0)
            XCTAssertEqual(start, row.3, row.0)
            XCTAssertEqual(length, row.4, row.0)
            XCTAssertEqual(event.calendarId, row.5, row.0)
            XCTAssertEqual(event.colorHex, colours[row.5], row.0)
        }
        XCTAssertEqual(ScreenshotMode.Sheet.allCases.count, 11, "no new sheet (C3-B1)")
    }

    /// The six arguments of §3.12 and their broken values: a missing or unknown value is off, never a guess; none of
    /// them changes another or an old one.
    func testSpanArgumentsParse() throws {
        let week = base + ["--screenshot-page", "week"]
        let all = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-span", "on", "--screenshot-offset-x", "-0.5", "--screenshot-span-shift",
                                                             "--screenshot-single-page", "--screenshot-span-guide", "two", "--screenshot-week-memo"]))
        XCTAssertEqual(all.page, .week)
        XCTAssertNil(all.sheet)
        XCTAssertEqual(all.span, .on)
        XCTAssertEqual(all.spanOffsetX, -0.5)
        XCTAssertTrue(all.spanShift)
        XCTAssertTrue(all.singlePage)
        XCTAssertEqual(all.spanGuide, .two)
        XCTAssertTrue(all.weekMemo)
        XCTAssertNil(all.settingsSection)
        XCTAssertFalse(all.joinsPages, "--screenshot-single-page wins: one page at a time")
        XCTAssertTrue(all.crossingDemo)
        XCTAssertEqual(all.spanOpeningOffsetX, -0.5)

        // --screenshot-span on|off.
        let on = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-span", "on"]))
        XCTAssertEqual(on.span, .on)
        XCTAssertTrue(on.joinsPages)
        XCTAssertTrue(on.crossingDemo)
        XCTAssertNil(on.spanOpeningOffsetX, "the canvas opens with the focus page in the middle")
        XCTAssertTrue(ScreenshotMode.pageSpanAtLaunch(on))
        let off = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-span", "off"]))
        XCTAssertEqual(off.span, .off)
        XCTAssertFalse(off.joinsPages || off.crossingDemo || ScreenshotMode.pageSpanAtLaunch(off))
        for broken in [["--screenshot-span", "yes"], ["--screenshot-span", "ON"], ["--screenshot-span"]] {
            let c = try XCTUnwrap(ScreenshotMode.parse(week + broken))
            XCTAssertNil(c.span, broken.joined(separator: " "))
            XCTAssertFalse(c.joinsPages || c.crossingDemo, broken.joined(separator: " "))
        }

        // --screenshot-offset-x <pages>: any finite number; the old --screenshot-offset stays its own.
        for (text, value) in [("-0.5", -0.5), ("1", 1.0), ("0", 0.0), ("2.25", 2.25), ("-3", -3.0)] {
            XCTAssertEqual(ScreenshotMode.parse(week + ["--screenshot-offset-x", text])?.spanOffsetX, CGFloat(value), text)
            XCTAssertEqual(ScreenshotMode.parseSpanOffsetX(text), CGFloat(value), text)
        }
        for text in ["abc", "inf", "-inf", "nan", "", "1,2", "0.5pages"] {
            XCTAssertNil(ScreenshotMode.parse(week + ["--screenshot-offset-x", text])?.spanOffsetX, text)
            XCTAssertNil(ScreenshotMode.parseSpanOffsetX(text), text)
        }
        XCTAssertNil(ScreenshotMode.parse(week + ["--screenshot-offset-x"])?.spanOffsetX, "no value")
        let both = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-offset", "10,20", "--screenshot-offset-x", "1"]))
        XCTAssertEqual(both.offset, CGPoint(x: 10, y: 20))
        XCTAssertEqual(both.spanOffsetX, 1)
        XCTAssertNil(ScreenshotMode.parse(week + ["--screenshot-offset-x", "-0.5"])?.offset)

        // --screenshot-span-shift: the band opens one page on unless --screenshot-offset-x says where; nothing else.
        let shift = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-span", "on", "--screenshot-span-shift"]))
        XCTAssertTrue(shift.spanShift)
        XCTAssertEqual(shift.spanOpeningOffsetX, 1)
        XCTAssertEqual(ScreenshotMode.parse(week + ["--screenshot-span", "on", "--screenshot-span-shift", "--screenshot-offset-x", "-0.5"])?.spanOpeningOffsetX, -0.5)
        let shiftOnly = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-span-shift"]))
        XCTAssertNil(shiftOnly.span, "the shift alone does not join the pages")
        XCTAssertFalse(shiftOnly.joinsPages)

        // --screenshot-single-page: the old versions' view with the halves of the crossing demo, one page at a time.
        let single = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-single-page"]))
        XCTAssertTrue(single.singlePage)
        XCTAssertTrue(single.crossingDemo)
        XCTAssertFalse(single.joinsPages)
        XCTAssertFalse(ScreenshotMode.pageSpanAtLaunch(single))

        // --screenshot-span-guide [one|two|stage-two]: the value may be left out (then `auto`).
        let guides: [(String, ScreenshotMode.GuideShot)] = [("one", .one), ("two", .two), ("stage-two", .stageTwo), ("auto", .auto), ("bogus", .auto)]
        for (text, guide) in guides {
            XCTAssertEqual(ScreenshotMode.parse(week + ["--screenshot-span-guide", text])?.spanGuide, guide, text)
        }
        XCTAssertEqual(ScreenshotMode.parse(week + ["--screenshot-span-guide"])?.spanGuide, .auto, "the last argument")
        let guideThenProbe = try XCTUnwrap(ScreenshotMode.parse(week + ["--screenshot-span-guide", "--screenshot-probe"]))
        XCTAssertEqual(guideThenProbe.spanGuide, .auto, "no value: the next argument is read as its own")
        XCTAssertTrue(guideThenProbe.probe)
        XCTAssertNil(ScreenshotMode.parse(week)?.spanGuide)
        XCTAssertEqual(ScreenshotMode.GuideShot.stageTwo.rawValue, "stage-two")
        for current in [false, true] {
            XCTAssertFalse(ScreenshotMode.GuideShot.one.allowFinger(current: current), "N-4 / N-6: one finger")
            XCTAssertTrue(ScreenshotMode.GuideShot.two.allowFinger(current: current), "N-5 / N-7: two fingers")
            XCTAssertEqual(ScreenshotMode.GuideShot.auto.allowFinger(current: current), current)
            XCTAssertEqual(ScreenshotMode.GuideShot.stageTwo.allowFinger(current: current), current)
        }
        XCTAssertEqual(SpanGuide.text(kind: .week, allowFinger: ScreenshotMode.GuideShot.one.allowFinger(current: true)),
                       SpanGuide.text(kind: .week, allowFinger: false))

        // --screenshot-week-memo: parsed only.
        XCTAssertTrue(ScreenshotMode.parse(week + ["--screenshot-week-memo"])?.weekMemo ?? false)
        XCTAssertFalse(ScreenshotMode.parse(week)?.weekMemo ?? true)

        // None of them moves the page, the sheet or an old field.
        let plain = try XCTUnwrap(ScreenshotMode.parse(week))
        var withAll = all
        withAll.span = nil
        withAll.spanOffsetX = nil
        withAll.spanShift = false
        withAll.singlePage = false
        withAll.spanGuide = nil
        withAll.weekMemo = false
        XCTAssertEqual(withAll, plain)
    }

    /// `--screenshot-single-page` (the old versions' view, C3-m4): the focus page alone holds the one-page demo and only
    /// the crossing strokes it owns — the other half is on the page to its left, none on the pages further away — and
    /// those run off its LEFT edge only (the side the CI's `span margin:` line names; the left page's run off its right
    /// edge). Without the crossing demo (the control photo: no argument) no demo point is off the paper.
    func testSinglePageHoldsOnlyTheOwnerHalves() throws {
        for kind in [PageKind.week, .day] {
            for weekStart in WeekStart.allCases {
                let name = "\(kind) \(weekStart)"
                var arguments = base + ["--screenshot-page", kind.rawValue, "--screenshot-single-page"]
                if weekStart == .sunday { arguments += ["--screenshot-week-start", "sunday"] }
                let config = try XCTUnwrap(ScreenshotMode.parse(arguments))
                XCTAssertEqual(config.page, kind, name)
                XCTAssertFalse(config.joinsPages, name)
                XCTAssertTrue(config.crossingDemo, name)

                let plan = plan(kind, weekStart)
                let centre = plan.index(containing: config.focus)
                let width = ZoomPolicy.paperWidth(kind)
                let ids = ScreenshotMode.crossingDemoStrokeIds(kind)
                XCTAssertEqual(ids.left.count, 1, "\(name): one held by the left page")
                XCTAssertEqual(ids.focus.count, 1, "\(name): one held by the focus page")

                let shown = ScreenshotMode.spanDemoPage(pageId: plan.pageId(at: centre), kind: kind, focus: config.focus, weekStart: config.weekStart,
                                                        crossing: config.crossingDemo, grown: false, empty: false, tallYear: false, storeInk: false)
                let demo = onePage(kind, weekStart)
                XCTAssertEqual(Set(shown.strokes.keys), Set(demo.strokes.keys).union(ids.focus), name)
                for stroke in demo.liveStrokes {
                    XCTAssertEqual(shown.strokes[stroke.id], stroke, "\(name): the one-page demo is kept as it is")
                    XCTAssertTrue(stroke.points.allSatisfy { $0.x >= 0 && $0.x <= width }, "\(name): \(stroke.id) stays on the paper (control)")
                }
                for id in ids.focus {
                    let xs = try XCTUnwrap(shown.strokes[id], "\(name): \(id)").points.map(\.x)
                    XCTAssertLessThan(xs.min() ?? 0, -50, "\(name): \(id) runs off the focus page's left edge")
                    XCTAssertGreaterThan(xs.max() ?? 0, 100, "\(name): \(id) is mostly on the focus page")
                    XCTAssertLessThanOrEqual(xs.max() ?? .infinity, width - 100, "\(name): \(id) never reaches the right edge")
                }

                let left = spanPage(plan.pageId(at: centre - 1), kind, weekStart, crossing: true)
                for id in ids.left {
                    let xs = try XCTUnwrap(left.strokes[id], "\(name): \(id) on the left page").points.map(\.x)
                    XCTAssertGreaterThan(xs.max() ?? 0, width + 50, "\(name): \(id) runs off the left page's right edge")
                    XCTAssertGreaterThanOrEqual(xs.min() ?? -1, 100, "\(name): \(id) never reaches the left page's left edge")
                    XCTAssertNil(shown.strokes[id], "\(name): the focus page alone does not hold the left page's half")
                }
                for id in ids.focus {
                    XCTAssertNil(left.strokes[id], name)
                }
                for index in [centre - 2, centre + 1, centre + 2] {
                    let other = spanPage(plan.pageId(at: index), kind, weekStart, crossing: true)
                    XCTAssertTrue(Set(other.strokes.keys).isDisjoint(with: ids.left + ids.focus), "\(name): page \(index - centre)")
                }
                // Without the crossing demo neither page holds any of it, and `--screenshot-empty` never has ink.
                XCTAssertTrue(Set(spanPage(plan.pageId(at: centre - 1), kind, weekStart, crossing: false).strokes.keys).isDisjoint(with: ids.left), name)
                let empty = ScreenshotMode.spanDemoPage(pageId: plan.pageId(at: centre), kind: kind, focus: focus, weekStart: weekStart, crossing: true,
                                                        grown: false, empty: true, tallYear: false, storeInk: false)
                XCTAssertTrue(empty.strokes.isEmpty, name)
            }
        }
        XCTAssertTrue(ScreenshotMode.crossingDemoStrokeIds(.month) == ([], []))
        XCTAssertTrue(ScreenshotMode.crossingDemoStrokeIds(.year) == ([], []))
    }

    /// D15 in the window: every crossing stroke is on the page `SpanLayout.drop` gives a new stroke with its bounds'
    /// centre (the canvas's rule), in the same cell (the day's free memo stroke in `extra`, the rest in `grid`).
    func testCrossingSamplesAreOwnedByTheCentrePage() throws {
        for kind in [PageKind.week, .day] {
            for weekStart in WeekStart.allCases {
                let plan = plan(kind, weekStart)
                let centre = plan.index(containing: focus)
                let indices = Array((centre - 2)...(centre + 2))
                let pages = indices.map { spanPage(plan.pageId(at: $0), kind, weekStart, crossing: true) }
                let layouts = zip(indices, pages).map { layout($1, index: $0, plan: plan) }
                let band = SpanLayout(pages: layouts, plan: plan, firstIndex: indices[0])
                let ids = ScreenshotMode.crossingDemoStrokeIds(kind)
                var seen = 0
                for (slot, page) in pages.enumerated() {
                    for stroke in page.liveStrokes where (ids.left + ids.focus).contains(stroke.id) {
                        seen += 1
                        let local = try bounds(stroke, in: layouts[slot])
                        let centrePoint = CGPoint(x: local.midX + band.origin(ofSlot: slot), y: local.midY)
                        XCTAssertEqual(band.drop(center: centrePoint), .keep(page: page.pageId, cell: stroke.cell), "\(kind) \(weekStart) \(stroke.id)")
                        XCTAssertEqual(band.slot(atX: centrePoint.x), slot)
                        XCTAssertEqual(slot, ids.left.contains(stroke.id) ? 1 : 2, "\(stroke.id): the left page or the focus page")
                        // Not on the boundary's edge of D15: at least 30 lu from it.
                        XCTAssertGreaterThan(abs(centrePoint.x - band.origin(ofSlot: 2)), 30, stroke.id)
                    }
                }
                XCTAssertEqual(seen, 2, "\(kind) \(weekStart): the two crossing strokes")
                if kind == .day {
                    XCTAssertEqual(pages[1].strokes[ids.left[0]]?.cell, .extra, "the day's free memo stroke is the left day's")
                    XCTAssertEqual(pages[2].strokes[ids.focus[0]]?.cell, .grid, "the line above 24:00 is the focus day's")
                }
            }
        }
    }

    /// C3-m10: with `--screenshot-span on` the UI tests of `EraserAndBelowDayUITests` run again on the joined day page
    /// (SpanRerunUITests), so the crossing demo keeps off their rectangles (lu of the focus day): B0's drag of the event
    /// tool, B1's line and its lasso loop, and the strokes B2 and B3 select. It also touches no demo stroke of its pages.
    func testCrossingDemoKeepsOffTheParentTestsRectangles() throws {
        let extraTop = PaperSpec.dayGridHeight
        let parent: [(String, CGRect)] = [
            ("B0 the event tool's drag", CGRect(x: 300, y: extraTop + 100, width: 300, height: 150)),
            ("B1 the line", CGRect(x: 330, y: extraTop + 160 - 12, width: 340, height: 24)),
            ("B1 the lasso loop", CGRect(x: 270, y: extraTop + 80, width: 460, height: 170)),
        ]
        for kind in [PageKind.week, .day] {
            for weekStart in WeekStart.allCases {
                let plan = plan(kind, weekStart)
                let centre = plan.index(containing: focus)
                let width = ZoomPolicy.paperWidth(kind)
                let ids = ScreenshotMode.crossingDemoStrokeIds(kind)
                let focusPage = spanPage(plan.pageId(at: centre), kind, weekStart, crossing: true, grown: true)
                let leftPage = spanPage(plan.pageId(at: centre - 1), kind, weekStart, crossing: true, grown: true)
                let focusLayout = layout(focusPage, index: centre, plan: plan)
                let leftLayout = layout(leftPage, index: centre - 1, plan: plan)
                // Every stroke of the two pages in the focus page's coordinates (the left page's moved left by a page).
                var crossing: [(String, CGRect)] = []
                var demo: [(String, CGRect)] = []
                for (page, pageLayout, dx) in [(focusPage, focusLayout, CGFloat(0)), (leftPage, leftLayout, -width)] {
                    for stroke in page.liveStrokes {
                        let rect = try bounds(stroke, in: pageLayout).offsetBy(dx: dx, dy: 0)
                        if (ids.left + ids.focus).contains(stroke.id) {
                            crossing.append((stroke.id, rect))
                        } else {
                            demo.append((stroke.id, rect))
                        }
                    }
                }
                XCTAssertEqual(crossing.count, 2)
                for (id, rect) in crossing {
                    XCTAssertLessThan(abs(rect.minX), 260, "\(id): near the boundary")
                    XCTAssertLessThan(abs(rect.maxX), 260, "\(id): near the boundary")
                    for (other, demoRect) in demo {
                        XCTAssertFalse(rect.insetBy(dx: -8, dy: -8).intersects(demoRect), "\(id) meets \(other)")
                    }
                    guard kind == .day else { continue }
                    for (what, parentRect) in parent {
                        XCTAssertFalse(rect.insetBy(dx: -24, dy: -24).intersects(parentRect), "\(id) meets \(what) (\(rect), \(parentRect))")
                    }
                    // B2 and B3 select the demo's strokes by id, which keep their ids on the focus page.
                    for selected in ["demo-stroke-day-extra", "demo-stroke-day-wave1"] {
                        let selectedRect = try bounds(try XCTUnwrap(focusPage.strokes[selected], selected), in: focusLayout)
                        XCTAssertFalse(rect.insetBy(dx: -24, dy: -24).intersects(selectedRect), "\(id) meets \(selected)")
                    }
                }
            }
        }
    }

    // MARK: - 設定 › ページ (C3-B1; wave D's text decision 10)

    /// `--screenshot-settings-section page` is the `settings` sheet (on the month page, as every sheet) scrolled to
    /// 「ページ」: `ScreenshotMode.Sheet` keeps its 11 cases, another sheet asked for wins, a broken value is nothing.
    /// The sheet's `scrollToPageOnAppear` is off by default and scrolls to the section's row; the section's switch opens
    /// with screenshot mode's own memory (off unless `--screenshot-span on`, then as last switched; nothing stored).
    func testPageSheetOpensTheSettingsAtThePageSection() throws {
        let section = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-page", "week", "--screenshot-settings-section", "page"]))
        XCTAssertEqual(section.settingsSection, .page)
        XCTAssertEqual(section.sheet, .settings)
        XCTAssertEqual(section.page, .month, "a sheet sits on the month page")
        let both = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-sheet", "settings", "--screenshot-settings-section", "page"]))
        XCTAssertEqual(both.sheet, .settings)
        XCTAssertEqual(both.settingsSection, .page)
        for other in ["sync", "info", "holidays", "week-start", "paywall", "lasso", "create"] {
            let c = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-sheet", other, "--screenshot-settings-section", "page"]))
            XCTAssertEqual(c.sheet?.rawValue, other, "\(other) wins")
            XCTAssertNil(c.settingsSection, other)
        }
        for broken in [["--screenshot-settings-section", "sync"], ["--screenshot-settings-section", "Page"], ["--screenshot-settings-section"]] {
            let c = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-page", "day"] + broken))
            XCTAssertNil(c.settingsSection, broken.joined(separator: " "))
            XCTAssertNil(c.sheet, broken.joined(separator: " "))
            XCTAssertEqual(c.page, .day, broken.joined(separator: " "))
        }
        XCTAssertEqual(ScreenshotMode.Sheet.allCases.count, 11)
        XCTAssertEqual(ScreenshotMode.SettingsSection.allCases.map(\.rawValue), ["page"])

        // The sheet: a defaulted input, the row's scroll id, and the target on appear (read where it is written).
        let lines = try settingsLines()
        XCTAssertTrue(lines.contains("var scrollToPageOnAppear: Bool = false"), "off by default")
        XCTAssertTrue(lines.contains("private static let pageRowId = \"page-section\""))
        let toggle = try XCTUnwrap(lines.firstIndex(of: "Toggle(Self.pageSpanTitle, isOn: $pageSpan)"))
        XCTAssertEqual(Array(lines[(toggle + 1)...(toggle + 2)]), [".accessibilityIdentifier(Self.pageSpanIdentifier)", ".id(Self.pageRowId)"],
                       "the scroll target is the section's switch")
        XCTAssertTrue(lines.contains("guard scrollToPageOnAppear || scrollToSyncOnAppear || scrollToPurchaseOnAppear || scrollToInfoOnAppear else { return }"))
        XCTAssertTrue(lines.contains("let target = scrollToPageOnAppear ? Self.pageRowId"), "「ページ」 first")
        XCTAssertEqual(lines.filter { $0.contains("Self.pageRowId") }.count, 2, "the row and the target")

        // The switch in screenshot mode: screenshot mode's own memory, never the store.
        ScreenshotMode.pageSpan = false
        XCTAssertFalse(SettingsScreen.initialPageSpan(screenshot: true))
        var told: [Bool] = []
        SettingsScreen.pageSpanChanged(to: true, screenshot: true) { told.append($0) }
        XCTAssertEqual(told, [true])
        XCTAssertTrue(ScreenshotMode.pageSpan, "kept in memory before the owner is told")
        XCTAssertTrue(SettingsScreen.initialPageSpan(screenshot: true), "the sheet opened again shows it")
        XCTAssertNil(defaults.object(forKey: AppSettings.pageSpanKey), "nothing stored in screenshot mode")
        SettingsScreen.pageSpanChanged(to: false, screenshot: true) { told.append($0) }
        XCTAssertEqual(told, [true, false])
        XCTAssertFalse(SettingsScreen.initialPageSpan(screenshot: true))
        XCTAssertNil(defaults.object(forKey: AppSettings.pageSpanKey))
        // Outside screenshot mode the device's setting, and screenshot mode's memory is not touched.
        AppSettings.pageSpan = false
        ScreenshotMode.pageSpan = true
        XCTAssertFalse(SettingsScreen.initialPageSpan(screenshot: false))
        SettingsScreen.pageSpanChanged(to: true, screenshot: false) { told.append($0) }
        XCTAssertTrue(AppSettings.pageSpan)
        XCTAssertTrue(ScreenshotMode.pageSpan)
        // At launch: on with --screenshot-span on only.
        XCTAssertTrue(ScreenshotMode.pageSpanAtLaunch(ScreenshotMode.parse(base + ["--screenshot-span", "on", "--screenshot-settings-section", "page"])))
        XCTAssertFalse(ScreenshotMode.pageSpanAtLaunch(ScreenshotMode.parse(base + ["--screenshot-settings-section", "page"])))
    }
}
