import XCTest
import Foundation
import CoreGraphics
import Layout

/// The week start in the layouts (docs/M7B_CONTRACT.md §10, K-11). 2026-11-01 is a Sunday: the Monday
/// grid of that month is 10/26 … 12/6, the Sunday grid 11/1 … 12/12.
final class WeekStartLayoutTests: XCTestCase {
    private typealias F = M3aFixtures
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { F.day(y, m, d) }
    private let november = YearMonth(year: 2026, month: 11)
    private var now: Date { F.date(2026, 11, 4, 10) }

    private func month(_ ym: YearMonth, events: [LayoutEvent] = [], weekStart: WeekStart) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: ym, events: events, inkBottoms: [:], now: now, calendar: F.tokyo, weekStart: weekStart))
    }

    private func week(_ focus: DayKey, events: [LayoutEvent] = [], weekStart: WeekStart) -> WeekPageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: events, inkBottoms: [:], now: now, calendar: F.tokyo, weekStart: weekStart))
    }

    func testSundayMonthGrid() {
        let grid = MonthLayout.grid(for: november, weekStart: .sunday)
        XCTAssertEqual(grid.days.first, day(2026, 11, 1))
        XCTAssertEqual(grid.days.last, day(2026, 12, 12))
        XCTAssertEqual(grid.days.count, 42)
        XCTAssertEqual(grid.rowCount, 5, "11/1 is the first cell of a Sunday grid")
        XCTAssertEqual(MonthLayout.rowCount(year: 2026, month: 11), 6, "Monday: 6 rows for the same month")
        XCTAssertEqual(MonthLayout.firstGridDay(year: 2026, month: 10, weekStart: .sunday), day(2026, 9, 27))
        let page = month(november, weekStart: .sunday)
        XCTAssertEqual(page.month, november, "the 7th of the first row is always in the month")
        XCTAssertEqual(page.pageId, "m1-2026-11")
        XCTAssertEqual(page.rows.count, 6)
        XCTAssertEqual(page.cells.count, 43)
        XCTAssertEqual(page.rows[0].days[0], day(2026, 11, 1))
        XCTAssertEqual(page.cells[.day(day(2026, 11, 1))]?.minX, 0)
        XCTAssertNotNil(page.cells[.day(day(2026, 12, 12))])
        XCTAssertNil(page.cells[.day(day(2026, 10, 26))])
        XCTAssertEqual(page.size, month(november, weekStart: .monday).size, "without events the paper is the same size")
        let tones = page.dateLabels.prefix(7).map(\.tone)
        XCTAssertEqual(tones.first, .sundayOrHoliday)
        XCTAssertEqual(tones.last, .saturday)
        let range = PageNavigation.dayRange(.month, focus: day(2026, 11, 20), weekStart: .sunday)
        XCTAssertEqual(range.start, day(2026, 11, 1))
        XCTAssertEqual(range.end, day(2026, 12, 13))
    }

    func testSundayWeekPage() {
        let wednesday = day(2026, 11, 4)
        let page = week(wednesday, weekStart: .sunday)
        XCTAssertEqual(page.pageId, "w-2026-11-01")
        XCTAssertEqual(page.days, (1...7).map { day(2026, 11, $0) })
        XCTAssertEqual(page.todayColumn, 3)
        XCTAssertEqual(page.allDayBand.days, page.days)
        XCTAssertEqual(page.allDayBand.todayColumn, 3)
        XCTAssertEqual(page.dateLabels.first?.tone, .sundayOrHoliday)
        XCTAssertEqual(page.dateLabels.last?.tone, .saturday)
        XCTAssertEqual(page.dayAt(point: CGPoint(x: page.columnFrame(0).midX, y: 100)), day(2026, 11, 1))
        XCTAssertEqual(PageNavigation.pageId(.week, focus: wednesday, weekStart: .sunday), "w-2026-11-01")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: day(2026, 11, 1), weekStart: .sunday), "w-2026-11-01", "a Sunday opens its own page")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: day(2026, 11, 7), weekStart: .sunday), "w-2026-11-01")
        let range = PageNavigation.dayRange(.week, focus: wednesday, weekStart: .sunday)
        XCTAssertEqual(range.start, day(2026, 11, 1))
        XCTAssertEqual(range.end, day(2026, 11, 8))
        let parsed = PageNavigation.parse(pageId: "w-2026-11-01")
        XCTAssertEqual(parsed?.kind, .week)
        XCTAssertEqual(parsed?.focus, day(2026, 11, 1), "parse reads a Sunday id as it is")
        XCTAssertEqual(WeekStart(weekPageDate: day(2026, 11, 1)), .sunday)
        XCTAssertEqual(WeekStart(weekPageDate: day(2026, 11, 2)), .monday)
        XCTAssertNil(WeekStart(weekPageDate: day(2026, 11, 3)))
        XCTAssertEqual(PageNavigation.title(.week, focus: wednesday, weekStart: .sunday), "2026年11月1日〜11月7日")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: wednesday, weekStart: .sunday), "11/1〜11/7")
    }

    func testMondayIsTheDefault() {
        let focus = day(2026, 11, 1)
        XCTAssertEqual(PageNavigation.pageId(.week, focus: focus), "w-2026-10-26", "a Sunday belongs to the week of its Monday")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: focus), PageNavigation.pageId(.week, focus: focus, weekStart: .monday))
        XCTAssertEqual(PageNavigation.title(.week, focus: focus), "2026年10月26日〜11月1日")
        XCTAssertEqual(PageNavigation.title(.week, focus: focus), PageNavigation.title(.week, focus: focus, weekStart: .monday))
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: focus), PageNavigation.compactTitle(.week, focus: focus, weekStart: .monday))
        XCTAssertEqual(MonthLayout.grid(for: november), MonthLayout.grid(for: november, weekStart: .monday))
        let events = F.demo
        XCTAssertEqual(MonthLayoutEngine.layout(MonthLayoutInput(month: november, events: events, inkBottoms: [:], now: now, calendar: F.tokyo)), month(november, events: events, weekStart: .monday))
        XCTAssertEqual(WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: events, inkBottoms: [:], now: now, calendar: F.tokyo)), week(focus, events: events, weekStart: .monday))
        XCTAssertEqual(AllDayBandEngine.week(monday: focus, events: events, now: now, calendar: F.tokyo), AllDayBandEngine.week(firstDay: focus, weekStart: .monday, events: events, now: now, calendar: F.tokyo))
        for d in 0..<14 {
            let any = day(2026, 11, 1).adding(days: d)
            XCTAssertEqual(WeekStart.monday.column(of: any), (any.weekday + 6) % 7, "1.1's expression")
            XCTAssertEqual(WeekStart.monday.firstDay(of: any), MonthLayout.mondayOnOrBefore(any))
        }
    }

    func testBandSplitsAtSaturday() {
        // Friday 11/6 to Monday 11/9 (the all-day end is exclusive).
        let event = LayoutEvent(id: "trip", title: "trip", allDay: true, start: F.date(2026, 11, 6), end: F.date(2026, 11, 10), colorHex: "#2563eb", calendarId: "c")
        let page = month(november, events: [event], weekStart: .sunday)
        XCTAssertEqual(page.allDayBars.count, 2, "two bars on the month page")
        XCTAssertEqual(page.allDayBars.map(\.row), [0, 1])
        XCTAssertEqual(page.allDayBars.map(\.continuesRight), [true, false])
        XCTAssertEqual(page.allDayBars.map(\.continuesLeft), [false, true])
        XCTAssertEqual(page.allDayBars[0].frame.maxX + PaperSpec.cellInset, PaperSpec.monthWidth, accuracy: 1e-6, "the first ends at the right edge: Saturday")
        XCTAssertEqual(page.allDayBars[1].frame.minX - PaperSpec.cellInset, 0, accuracy: 1e-6, "the second starts at the left edge: Sunday")
        // The fixed band of the two week pages.
        let first = week(day(2026, 11, 4), events: [event], weekStart: .sunday).allDayBand
        let second = week(day(2026, 11, 8), events: [event], weekStart: .sunday).allDayBand
        XCTAssertEqual(first.bars.map { [$0.startCol, $0.endCol] }, [[5, 6]], "Friday and Saturday")
        XCTAssertEqual(first.bars.map(\.continuesRight), [true])
        XCTAssertEqual(first.bars.map(\.continuesLeft), [false])
        XCTAssertEqual(second.bars.map { [$0.startCol, $0.endCol] }, [[0, 1]], "Sunday and Monday")
        XCTAssertEqual(second.bars.map(\.continuesRight), [false])
        XCTAssertEqual(second.bars.map(\.continuesLeft), [true])
    }

    func testYearCrossingTitle() {
        let wednesday = day(2026, 12, 30)
        XCTAssertEqual(PageNavigation.title(.week, focus: wednesday, weekStart: .sunday), "2026年12月27日〜2027年1月2日")
        XCTAssertEqual(PageNavigation.compactTitle(.week, focus: wednesday, weekStart: .sunday), "12/27〜1/2")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: wednesday, weekStart: .sunday), "w-2026-12-27")
    }

    func testOnlyPaleCellsDiffer() {
        for (ym, onlyMonday, onlySunday): (YearMonth, [DayKey], [DayKey]) in [
            (YearMonth(year: 2026, month: 10), [day(2026, 11, 8)], [day(2026, 9, 27)]),
            (november, (26...31).map { day(2026, 10, $0) }, (7...12).map { day(2026, 12, $0) }),
            (YearMonth(year: 2026, month: 12), [day(2027, 1, 10)], [day(2026, 11, 29)]),
            (YearMonth(year: 2027, month: 2), [day(2027, 3, 14)], [day(2027, 1, 31)]),
        ] {
            let monday = Set(MonthLayout.grid(for: ym).days), sunday = Set(MonthLayout.grid(for: ym, weekStart: .sunday).days)
            XCTAssertEqual(monday.subtracting(sunday), Set(onlyMonday), "\(ym)")
            XCTAssertEqual(sunday.subtracting(monday), Set(onlySunday), "\(ym)")
            XCTAssertTrue(monday.symmetricDifference(sunday).allSatisfy { !ym.contains($0) }, "\(ym): no day of the month differs")
        }
    }
}
