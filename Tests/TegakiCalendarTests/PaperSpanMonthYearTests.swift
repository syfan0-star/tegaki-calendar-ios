import Holidays
import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §3.4, §3.8, §11.2 row P, §11.5 MP1; 0g-27, 0g-53; role P): the window of the session's
// layout as the canvas and the heading take it (`PaperSpan.window(for:focus:)`, which the frozen `InkCanvasView.paperSpan` calls
// since R3) and the one place a window page's paper is made (`PaperSpan.paperContent(of:)`).
//
// - Weeks and days: the window is 1.3's `init?(layout:bands:focus:)` with each page's own all-day band, `==`.
// - Months: the pages' paper alone, no band, each page at k × 1,400 lu; two windows that differ only in the separator line
//   (`memo.minY`) are not `==` (so the canvas draws the paper again when only the 6th row grew).
// - The year: a window only while `SpanKinds.joined` holds it (since D1y; the fallback of 0g-3 takes it out there): the pages'
//   paper, no band, each at k × 1,400 lu, its 31 rows lined up across the window by the session (`SpanAlign.yearFloors`); two
//   windows that differ only in a row's floor are not `==` (the canvas draws the paper again). A window of one page stays as
//   1.3 left it (`single` nil).
// - The month's `holidayNames` and the year's `monthNames` are what the one page's `CalendarRootScreen.makePaper` gives for the
//   same holidays and week start (Japan and the US, Monday and Sunday).
//
// The windows are the sessions' own (`SpanSession` over the live engine of `SessionTestBed`, as SpanSessionMonthYearTests): the
// 11-inch iPad in portrait around 11/16/2026.

@MainActor
final class PaperSpanMonthYearTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!

    private let nov16 = DayKey(year: 2026, month: 11, day: 16)

    override func setUp() async throws {
        bed = try SessionTestBed("PaperSpanMonthYearTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
    }

    override func tearDown() async throws {
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    // MARK: - Helpers

    /// A read window of `kind` around `focus`, its pages laid out with `holidays` and `weekStart` (the session's
    /// `PaperContext`, as `ScreenPaths` gives it).
    private func session(_ kind: PageKind, focus: DayKey? = nil, weekStart: WeekStart = .monday, holidays: HolidayCalendar = .japan,
                         number: Int = 1) async -> SpanSession {
        let sleeper = bed.sessionSleeper
        let clockBed: SessionTestBed = bed
        let made = SpanSession(kind: kind, weekStart: weekStart, focus: focus ?? nov16, sync: bed.engine, deviceClass: .iPad11,
                               orientation: .portrait, number: number,
                               context: SpanSession.PaperContext(now: bed.now, holidays: holidays, calendar: SessionTestBed.tokyo),
                               sleep: { await sleeper.sleep($0) },
                               clock: { [weak clockBed] in clockBed?.now ?? Date(timeIntervalSince1970: 1_790_000_000) })
        await made.prefetch()
        return made
    }

    /// The bundled holiday data of the repository (CalendarRootScreenTests' `worldStore`: the test host may not have the folder).
    private func american() throws -> HolidayCalendar {
        let repository = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let store = HolidayStore(directory: repository.appendingPathComponent("TegakiKit/HolidayData", isDirectory: true))
        let us = store.calendar(for: try XCTUnwrap(HolidayRegion(code: "US")), language: .en)
        XCTAssertEqual(us.id, "US|en")
        return us
    }

    private func monthLayout(_ month: Int, year: Int = 2026, gridFloor: CGFloat = 0) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: year, month: month), events: [], inkBottoms: [:], now: bed.now,
                                                  gridFloor: gridFloor))
    }

    // MARK: - Weeks and days (1.3's window)

    /// §2.1, §3.4: for weeks and days `window(for:focus:)` is the frozen canvas's 1.3 window — `init?(layout:bands:focus:)` with
    /// each page's own all-day band — `==`, and so is `InkCanvasView.paperSpan(for:focus:)` (R3's one line); the focus is kept.
    func testTheWindowOfWeeksAndDaysIsTheLayoutsWindow() async throws {
        for (number, kind) in [PageKind.week, .day].enumerated() {
            let made = await session(kind, number: 1 + number)
            let layout = made.layout
            XCTAssertGreaterThan(layout.pages.count, 1, "\(kind)")
            let bands: [AllDayBandLayout] = layout.pages.compactMap { page in
                (page as? WeekPageLayout)?.allDayBand ?? (page as? DayPageLayout)?.allDayBand
            }
            XCTAssertEqual(bands.count, layout.pages.count, "\(kind)")
            let window = try XCTUnwrap(PaperSpan.window(for: layout, focus: made.focusSlot), "\(kind)")
            XCTAssertEqual(window, PaperSpan(layout: layout, bands: bands, focus: made.focusSlot), "\(kind): 1.3's window")
            XCTAssertEqual(window, InkCanvasView.paperSpan(for: layout, focus: made.focusSlot), "\(kind): the canvas's")
            XCTAssertEqual(window.kind, kind)
            XCTAssertEqual(window.focus, made.focusSlot)
            XCTAssertEqual(window.bands, bands)
            XCTAssertEqual(PaperSpan.window(for: layout, focus: 1)?.focus, 1, "\(kind): the focus asked")
        }
    }

    // MARK: - Months

    /// §2.1, §3.4, §3.8: a window of months is the pages' paper (`paperContent(of:)` of each page), no band, page k at
    /// k × 1,400 lu (the layout's slots), as wide as the pages side by side and as tall as the tallest; its days are no band's
    /// run. 1.3's `init?(layout:bands:focus:)` still makes none for months, a band beside months makes none, and a window of
    /// two kinds or of no page is nil.
    func testTheWindowOfMonthsIsThePagesPaperWithNoBand() async throws {
        let made = await session(.month)
        let layout = made.layout
        let window = try XCTUnwrap(PaperSpan.window(for: layout, focus: made.focusSlot))
        XCTAssertEqual(window.kind, .month)
        XCTAssertEqual(window.bands, [])
        XCTAssertEqual(window.focus, made.focusSlot)
        XCTAssertEqual(window.pages.count, layout.pages.count)
        XCTAssertEqual(window.pages.count, 5, "the 11-inch iPad in portrait: five months")
        XCTAssertTrue(window.isJoined)
        XCTAssertEqual(window.pageWidth, 1_400)
        for (slot, page) in layout.pages.enumerated() {
            XCTAssertEqual(window.pages[slot], PaperSpan.paperContent(of: page), "slot \(slot)")
            XCTAssertEqual(window.pages[slot].layout.pageId, page.pageId)
            XCTAssertEqual(window.origin(ofSlot: slot), layout.origin(ofSlot: slot))
            XCTAssertEqual(window.origin(ofSlot: slot), CGFloat(slot) * 1_400)
            XCTAssertEqual(window.dateLabels(ofSlot: slot).count, 42, "slot \(slot): its table's 42 days")
        }
        XCTAssertEqual(window.size, CGSize(width: 5 * 1_400, height: layout.size.height))
        XCTAssertEqual(window.size, layout.size)
        XCTAssertEqual(window.days, [], "no band, no run of days")
        XCTAssertEqual(made.pageIds, window.pages.map(\.layout.pageId))

        XCTAssertNil(PaperSpan(layout: layout, bands: [], focus: 0), "1.3's init makes no window of months")
        let week = await session(.week, number: 2)
        let weekBand = try XCTUnwrap((week.layout.pages.first as? WeekPageLayout)?.allDayBand)
        XCTAssertNil(PaperSpan(pages: window.pages, bands: [weekBand], focus: 0), "months take no band")
        XCTAssertNotNil(PaperSpan(pages: window.pages, bands: [], focus: 0), "months pass with no band (the heading's window)")
        let weekPage = try XCTUnwrap(PaperSpan.paperContent(of: try XCTUnwrap(week.layout.pages.first)))
        XCTAssertNil(PaperSpan(pages: [window.pages[0], weekPage], bands: [], focus: 0), "one kind")
        XCTAssertNil(PaperSpan.window(for: SpanLayout(pages: [], plan: layout.plan, firstIndex: layout.firstIndex), focus: 0), "no page")
        XCTAssertNil(PaperSpan.window(for: SpanLayout(pages: [], plan: week.layout.plan, firstIndex: week.layout.firstIndex), focus: 0))
    }

    /// MP1, §3.4 (`updatePaperSpan` draws again what is not `==`): two windows of the same months that differ only in their
    /// separator line — November's natural 1,050 and the 6th row grown to 1,283 by a floor (ア) — are not `==`: rows 1–5, the
    /// cells' x and the memo's height are the same, the 6th row and `memo.minY` are not. The same layout gives `==`.
    func testTwoWindowsThatDifferOnlyInTheSeparatorAreNotEqual() async throws {
        let made = await session(.month)
        let layout = made.layout
        let slot = try XCTUnwrap(layout.slot(ofPage: "m1-2026-11"))
        let natural = try XCTUnwrap(layout.pages[slot] as? MonthPageLayout)
        XCTAssertEqual(natural.memo.minY, 1_050, accuracy: 1e-9, "an empty window: six rows of 175 lu")
        var grown = layout.pages
        grown[slot] = monthLayout(11, gridFloor: 1_283)
        let tall = try XCTUnwrap(grown[slot] as? MonthPageLayout)
        XCTAssertEqual(tall.memo.minY, 1_283, accuracy: 1e-9)
        XCTAssertEqual(Array(tall.rows.prefix(5).map(\.frame)), Array(natural.rows.prefix(5).map(\.frame)), "rows 1–5 stay")
        XCTAssertEqual(tall.rows[5].frame.height, 1_283 - 875, accuracy: 1e-9, "the 6th row reaches the floor")
        XCTAssertEqual(tall.memo.height, natural.memo.height)

        let before = try XCTUnwrap(PaperSpan.window(for: layout, focus: made.focusSlot))
        let after = try XCTUnwrap(PaperSpan.window(for: SpanLayout(pages: grown, plan: layout.plan, firstIndex: layout.firstIndex,
                                                                   floors: layout.floors, session: layout.session), focus: made.focusSlot))
        XCTAssertNotEqual(before, after, "only the separator line moved: the paper is drawn again")
        XCTAssertEqual(before.pages.count, after.pages.count)
        for index in before.pages.indices where index != slot {
            XCTAssertEqual(before.pages[index], after.pages[index], "slot \(index)")
        }
        XCTAssertEqual(before, PaperSpan.window(for: layout, focus: made.focusSlot), "the same layout: ==")
    }

    // MARK: - The year (SpanKinds)

    /// §2.1, §11.2 (the year's expectations from `SpanKinds.joined`): a window of years exists exactly when the year joins
    /// (D1y), with no band — the pages' paper, five years on the 11-inch iPad in portrait, page k at k × 1,400 lu, as wide as
    /// the pages side by side and as tall as the layout, no run of days; without the year in `SpanKinds.joined` (0g-3)
    /// `window(for:)` is nil for it, while `init?(pages:bands:focus:)` passes years with no band (the heading's window) and
    /// refuses them with one.
    func testTheYearsWindowFollowsSpanKinds() async throws {
        let made = await session(.year)
        let layout = made.layout
        XCTAssertFalse(layout.pages.isEmpty)
        let window = PaperSpan.window(for: layout, focus: made.focusSlot)
        XCTAssertEqual(window != nil, SpanKinds.joined.contains(.year), "the year joins with D1y")
        if let window {
            XCTAssertEqual(window.kind, .year)
            XCTAssertEqual(window.bands, [])
            XCTAssertEqual(window.pages, layout.pages.compactMap(PaperSpan.paperContent(of:)))
            XCTAssertEqual(window.focus, made.focusSlot)
            XCTAssertEqual(window.pages.count, 5, "the 11-inch iPad in portrait: five years")
            XCTAssertTrue(window.isJoined)
            XCTAssertEqual(window.pageWidth, 1_400)
            for slot in layout.pages.indices {
                XCTAssertEqual(window.origin(ofSlot: slot), layout.origin(ofSlot: slot))
                XCTAssertEqual(window.pages[slot].layout.pageId, layout.pages[slot].pageId)
            }
            XCTAssertEqual(window.size, layout.size)
            XCTAssertEqual(window.days, [], "no band, no run of days")
            XCTAssertEqual(made.pageIds, window.pages.map(\.layout.pageId))
        }
        let years = layout.pages.compactMap(PaperSpan.paperContent(of:))
        XCTAssertEqual(years.count, layout.pages.count)
        XCTAssertTrue(years.allSatisfy { $0.kind == .year })
        XCTAssertNotNil(PaperSpan(pages: years, bands: [], focus: 0))
        let week = await session(.week, number: 2)
        let weekBand = try XCTUnwrap((week.layout.pages.first as? WeekPageLayout)?.allDayBand)
        XCTAssertNil(PaperSpan(pages: [years[0]], bands: [weekBand], focus: 0))
    }

    /// §5.1, §3.4, MP1 (`updatePaperSpan` draws again what is not `==`): in a window of years the session lines the 31 rows up —
    /// 2026's 3/16 holds a stroke 100 lu down, so row 16 is `YearLayoutEngine.rowHeight` of its bottom on every year of the
    /// window and every row starts at the same y on every page (the same day runs on in a straight line). A page of the window
    /// is its natural layout laid out with the window's row floors. Two windows that differ only in one page's row floor —
    /// 2025 with the window's floors, and 2025 as it is alone (row 16 back at 60) — are not `==`: rows 1–16's tops, every cell's
    /// x and width and the other pages are the same, rows 17–31 are 60 − the floor higher. The same layout gives `==`.
    func testAYearWindowLinesUpItsRowsAndARowFloorRedrawsThePaper() async throws {
        var page = InkPage.empty(pageId: "y-2026")
        let points = [CGPoint(x: 20, y: 10), CGPoint(x: 40, y: 60), CGPoint(x: 60, y: 100)].enumerated().map { i, p in
            InkPoint(x: p.x, y: p.y, dtMs: i * 10, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = InkStroke(id: "y-tall", cell: .yearDay(month: 3, day: 16), tool: .pen, color: "#1f2937", t: 1_790_000_001_000, points: points)
        page.add(stroke)
        try bed.store.save(page)
        let made = await session(.year)
        let layout = made.layout
        guard SpanKinds.joined.contains(.year) else {
            XCTAssertNil(PaperSpan.window(for: layout, focus: made.focusSlot), "the year is one page (0g-3)")
            return
        }
        XCTAssertEqual(made.pageIds, ["y-2024", "y-2025", "y-2026", "y-2027", "y-2028"])
        let tall = YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: stroke.bottom)
        XCTAssertEqual(tall, 100 + 1.75 + PaperSpec.inkPad, accuracy: 1e-9, "the stroke's bottom (y + half its 3.5 lu nib) + 12")
        let window = try XCTUnwrap(PaperSpan.window(for: layout, focus: made.focusSlot))
        let years: [YearPageLayout] = window.pages.compactMap { paper in
            guard case .year(let content) = paper else { return nil }
            return content.layout
        }
        XCTAssertEqual(years.count, 5)
        let first = try XCTUnwrap(years.first)
        for year in years {
            XCTAssertEqual(year.rows.count, PaperSpec.yearRows)
            XCTAssertEqual(year.rows[15].frame.height, tall, accuracy: 1e-9, "\(year.year): row 16 takes 2026's stroke")
            for (r, row) in year.rows.enumerated() {
                XCTAssertEqual(row.frame.minY, first.rows[r].frame.minY, accuracy: 1e-9, "\(year.year): row \(r + 1) starts where 2024's does")
                XCTAssertEqual(row.frame.height, r == 15 ? tall : PaperSpec.yearRowBase, accuracy: 1e-9, "\(year.year): row \(r + 1)")
            }
            XCTAssertEqual(year.size.height, first.size.height)
            XCTAssertEqual(year.cells[.yearDay(month: 7, day: 20)]?.minY ?? -1, first.cells[.yearDay(month: 7, day: 20)]?.minY ?? -2, accuracy: 1e-9)
        }
        XCTAssertEqual(first.size.height, 30 * PaperSpec.yearRowBase + tall, accuracy: 1e-9)
        XCTAssertEqual(window.size, CGSize(width: 5 * 1_400, height: first.size.height))

        // 2025 (no handwriting) is its natural page laid out with the window's floors; alone, row 16 is 60.
        let slot = try XCTUnwrap(layout.slot(ofPage: "y-2025"))
        let c = made.context
        let input = YearLayoutInput(year: 2025, events: [], inkBottoms: [:], now: c.now, calendar: c.calendar, holidays: c.holidays, words: c.words)
        let floored = YearLayoutEngine.layout(input.floored(by: layout.floors))
        let alone = YearLayoutEngine.layout(input)
        XCTAssertEqual(PaperSpan.paperContent(of: floored), window.pages[slot], "the window page: the natural year with the window's floors")
        XCTAssertEqual(alone.rows[15].frame.height, PaperSpec.yearRowBase)
        XCTAssertEqual(Array(alone.rows.prefix(16).map(\.frame.minY)), Array(floored.rows.prefix(16).map(\.frame.minY)), "rows 1–16 start where they did")
        for r in 16..<PaperSpec.yearRows {
            XCTAssertEqual(floored.rows[r].frame.minY - alone.rows[r].frame.minY, tall - PaperSpec.yearRowBase, accuracy: 1e-9, "row \(r + 1)")
        }
        for (key, rect) in alone.cells {
            XCTAssertEqual(rect.minX, floored.cells[key]?.minX ?? -1, accuracy: 1e-9, "\(key)")
            XCTAssertEqual(rect.width, floored.cells[key]?.width ?? -1, accuracy: 1e-9, "\(key)")
        }

        var pages = layout.pages
        pages[slot] = alone
        let other = try XCTUnwrap(PaperSpan.window(for: SpanLayout(pages: pages, plan: layout.plan, firstIndex: layout.firstIndex,
                                                                   floors: layout.floors, session: layout.session), focus: made.focusSlot))
        XCTAssertNotEqual(window, other, "only 2025's row floor differs: the paper is drawn again")
        for index in window.pages.indices where index != slot {
            XCTAssertEqual(window.pages[index], other.pages[index], "slot \(index)")
        }
        XCTAssertEqual(window, PaperSpan.window(for: layout, focus: made.focusSlot), "the same layout: ==")
    }

    /// §3.4: `single` (the window of one page with its own band) stays nil for a month and a year — neither has an all-day band
    /// on either path (the frozen PaperSpanTests reads it as "the year is one page") — and gives the week's and the day's.
    func testSingleStaysNilForTheMonthAndTheYear() async throws {
        let month = try XCTUnwrap(PaperSpan.paperContent(of: monthLayout(11)))
        XCTAssertNil(PaperSpan.single(month))
        let year = try XCTUnwrap(PaperSpan.paperContent(of: YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: bed.now))))
        XCTAssertNil(PaperSpan.single(year))
        for (number, kind) in [PageKind.week, .day].enumerated() {
            let made = await session(kind, number: 1 + number)
            let page = try XCTUnwrap(PaperSpan.paperContent(of: try XCTUnwrap(made.layout.pages.first)))
            let single = try XCTUnwrap(PaperSpan.single(page), "\(kind)")
            XCTAssertFalse(single.isJoined)
            XCTAssertEqual(single.bands, [try XCTUnwrap(page.allDayBand)])
        }
    }

    // MARK: - The one place of the paper (0g-53)

    /// 0g-53, §2.1: the paper of a window page (`paperContent(of:)`, from the layout alone) holds what the one page's
    /// `CalendarRootScreen.makePaper` gives for the same holidays and week start: a month's `holidayNames` (and its labels'
    /// names) — Japan's (11/3 文化の日, 11/23 勤労感謝の日) and the US's (11/26 Thanksgiving Day), Monday and Sunday weeks, so the
    /// days of the other months in a table come with their names too — and a year's `monthNames`.
    func testThePaperIsMakePapersForTheSameHolidaysAndWeekStart() async throws {
        let us = try american()
        var number = 1
        for (holidays, name) in [(HolidayCalendar.japan, "Japan"), (us, "US")] {
            for weekStart in [WeekStart.monday, .sunday] {
                let made = await session(.month, weekStart: weekStart, holidays: holidays, number: number)
                number += 1
                let window = try XCTUnwrap(PaperSpan.window(for: made.layout, focus: made.focusSlot))
                XCTAssertEqual(window.pages.count, made.layout.pages.count)
                var named = 0
                for page in window.pages {
                    guard case .month(let content) = page else { return XCTFail("a month") }
                    let month = content.layout.month
                    guard case .month(let expected) = CalendarRootScreen.makePaper(kind: .month, focus: month.firstDay, events: [], inkBottoms: [:],
                                                                                   now: bed.now, holidays: holidays, weekStart: weekStart) else {
                        return XCTFail("makePaper's month")
                    }
                    let what = "\(name), \(weekStart), \(month.year)-\(month.month)"
                    XCTAssertEqual(content.holidayNames, expected.holidayNames, what)
                    XCTAssertEqual(content.labels.map(\.day), expected.labels.map(\.day), what)
                    XCTAssertEqual(content.labels.map(\.holidayName), expected.labels.map(\.holidayName), what)
                    XCTAssertEqual(content.layout.rows.first?.days.first, expected.layout.rows.first?.days.first, "\(what): the same table")
                    named += content.holidayNames.count
                }
                XCTAssertGreaterThan(named, 0, "\(name), \(weekStart): the window has holidays")
                let november = try XCTUnwrap(window.pages.first { $0.layout.pageId == "m1-2026-11" })
                guard case .month(let content) = november else { return XCTFail("November") }
                if holidays == .japan {
                    XCTAssertEqual(content.holidayNames[DayKey(year: 2026, month: 11, day: 3)], "文化の日")
                    XCTAssertNil(content.holidayNames[DayKey(year: 2026, month: 11, day: 26)])
                } else {
                    XCTAssertEqual(content.holidayNames[DayKey(year: 2026, month: 11, day: 26)], "Thanksgiving Day")
                    XCTAssertNil(content.holidayNames[DayKey(year: 2026, month: 11, day: 3)])
                }
            }
            // The year: the same twelve names as the one page's (the ja heading shows them, §3.8).
            let year = await session(.year, holidays: holidays, number: number)
            number += 1
            for page in year.layout.pages {
                guard case .year(let content) = PaperSpan.paperContent(of: page) else { return XCTFail("a year") }
                guard case .year(let expected) = CalendarRootScreen.makePaper(kind: .year, focus: DayKey(year: content.layout.year, month: 1, day: 1),
                                                                              events: [], inkBottoms: [:], now: bed.now, holidays: holidays,
                                                                              weekStart: .monday) else {
                    return XCTFail("makePaper's year")
                }
                XCTAssertEqual(content.monthNames, expected.monthNames, "\(name), \(content.layout.year)")
                XCTAssertEqual(content.monthNames.count, 12)
            }
        }
    }
}
