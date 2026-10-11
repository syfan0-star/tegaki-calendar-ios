import XCTest
@testable import TegakiCalendar

final class MonthLayoutTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    // MARK: DayKey

    func testWeekdays() {
        XCTAssertEqual(day(1970, 1, 1).weekday, 4, "1970-01-01 was a Thursday")
        XCTAssertEqual(day(2000, 1, 1).weekday, 6, "2000-01-01 was a Saturday")
        XCTAssertEqual(day(2026, 1, 1).weekday, 4, "2026-01-01 is a Thursday")
        XCTAssertEqual(day(2026, 10, 1).weekday, 4, "2026-10-01 is a Thursday")
        XCTAssertEqual(day(2026, 9, 28).weekday, 1, "2026-09-28 is a Monday")
        XCTAssertEqual(day(2026, 2, 1).weekday, 0, "2026-02-01 is a Sunday")
    }

    func testDayNumberRoundTripAndArithmetic() {
        XCTAssertEqual(day(1970, 1, 1).dayNumber, 0)
        XCTAssertEqual(DayKey(dayNumber: 0), day(1970, 1, 1))
        XCTAssertEqual(day(2026, 10, 1).adding(days: -3), day(2026, 9, 28))
        XCTAssertEqual(day(2026, 12, 31).adding(days: 1), day(2027, 1, 1))
        XCTAssertEqual(day(2024, 2, 28).adding(days: 1), day(2024, 2, 29), "2024 is a leap year")
        XCTAssertEqual(day(2023, 2, 28).adding(days: 1), day(2023, 3, 1))
        for n in stride(from: -20_000, through: 60_000, by: 997) {
            XCTAssertEqual(DayKey(dayNumber: n).dayNumber, n)
        }
        XCTAssertTrue(day(2026, 9, 28) < day(2026, 10, 1))
        XCTAssertEqual(day(2026, 3, 5).description, "2026-03-05")
    }

    func testDaysInMonth() {
        XCTAssertEqual(DayKey.daysInMonth(year: 2024, month: 2), 29)
        XCTAssertEqual(DayKey.daysInMonth(year: 2026, month: 2), 28)
        XCTAssertEqual(DayKey.daysInMonth(year: 2000, month: 2), 29)
        XCTAssertEqual(DayKey.daysInMonth(year: 2100, month: 2), 28)
        XCTAssertEqual(DayKey.daysInMonth(year: 2026, month: 4), 30)
        XCTAssertEqual(DayKey.daysInMonth(year: 2026, month: 12), 31)
        XCTAssertTrue(day(2026, 2, 28).isValid)
        XCTAssertFalse(day(2026, 2, 30).isValid)
    }

    func testDateBridgingUsesTheGivenCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let d = day(2026, 9, 22)
        let midnight = d.startOfDay(in: calendar)
        XCTAssertEqual(DayKey(midnight, calendar: calendar), d)
        XCTAssertEqual(DayKey(midnight.addingTimeInterval(86_399), calendar: calendar), d)
        XCTAssertEqual(DayKey(midnight.addingTimeInterval(86_400), calendar: calendar), day(2026, 9, 23))
    }

    // MARK: MonthLayout

    func testOctober2026StartsOnMondaySeptember28() {
        let grid = MonthLayout.grid(year: 2026, month: 10)
        XCTAssertEqual(grid.days.count, 42)
        XCTAssertEqual(grid.days.first, day(2026, 9, 28))
        XCTAssertEqual(grid.days[3], day(2026, 10, 1))
        XCTAssertEqual(grid.days.last, day(2026, 11, 8))
        XCTAssertEqual(grid.rowCount, 5)
        XCTAssertEqual(grid.rows.count, 5)
        XCTAssertEqual(grid.lastVisibleDay, day(2026, 11, 1))
        XCTAssertEqual(Array(grid.days.prefix(7).map(\.weekday)), [1, 2, 3, 4, 5, 6, 0], "Monday ... Sunday")
        XCTAssertTrue(grid.contains(day(2026, 10, 31)))
        XCTAssertFalse(grid.contains(day(2026, 9, 30)))
        XCTAssertEqual(MonthLayout.firstGridDay(year: 2026, month: 10), day(2026, 9, 28))
    }

    func testFebruary2026Grid() {
        let grid = MonthLayout.grid(year: 2026, month: 2)
        XCTAssertEqual(grid.days.first, day(2026, 1, 26), "Feb 1 2026 is a Sunday, so the grid starts on Mon Jan 26")
        XCTAssertEqual(grid.days[6], day(2026, 2, 1))
        XCTAssertEqual(grid.rowCount, 5)
        XCTAssertEqual(grid.rows[0], [day(2026, 1, 26), day(2026, 1, 27), day(2026, 1, 28), day(2026, 1, 29), day(2026, 1, 30), day(2026, 1, 31), day(2026, 2, 1)])
        XCTAssertEqual(grid.rows[4].first, day(2026, 2, 23))
        XCTAssertEqual(grid.rows[4].last, day(2026, 3, 1))
        XCTAssertEqual(grid.lastVisibleDay, day(2026, 3, 1))
        XCTAssertEqual(grid.days.last, day(2026, 3, 8))
        XCTAssertEqual(grid.rows.flatMap { $0 }.filter { grid.contains($0) }.count, 28)
    }

    func testRowCounts() {
        XCTAssertEqual(MonthLayout.rowCount(year: 2026, month: 10), 5)
        XCTAssertEqual(MonthLayout.rowCount(year: 2026, month: 2), 5)
        XCTAssertEqual(MonthLayout.rowCount(year: 2026, month: 3), 6, "Mar 1 2026 is a Sunday: 31 days need 6 rows")
        XCTAssertEqual(MonthLayout.rowCount(year: 2026, month: 8), 6, "Aug 1 2026 is a Saturday: 31 days need 6 rows")
        XCTAssertEqual(MonthLayout.rowCount(year: 2027, month: 2), 4, "Feb 1 2027 is a Monday: 28 days fit in 4 rows")
        XCTAssertEqual(MonthLayout.rowCount(year: 2021, month: 2), 4)
        for year in 2000...2099 {
            for month in 1...12 {
                let rows = MonthLayout.rowCount(year: year, month: month)
                XCTAssertTrue((4...6).contains(rows), "\(year)-\(month): \(rows) rows")
                let grid = MonthLayout.grid(year: year, month: month)
                XCTAssertEqual(grid.firstDay.weekday, 1, "grid must start on a Monday")
                XCTAssertTrue(grid.rows[rows - 1].contains(where: { grid.contains($0) }), "last row must contain a day of the month")
                XCTAssertFalse(grid.days[(rows * 7)...].contains(where: { grid.contains($0) }), "hidden rows must hold no day of the month")
            }
        }
    }

    func testYearMonthNavigation() {
        XCTAssertEqual(YearMonth(year: 2026, month: 12).next, YearMonth(year: 2027, month: 1))
        XCTAssertEqual(YearMonth(year: 2027, month: 1).previous, YearMonth(year: 2026, month: 12))
        XCTAssertEqual(YearMonth(year: 2026, month: 10).title, "2026年10月")
        XCTAssertEqual(YearMonth(year: 2026, month: 10).firstDay, day(2026, 10, 1))
        XCTAssertEqual(YearMonth(year: 2026, month: 2).lastDay, day(2026, 2, 28))
    }
}
