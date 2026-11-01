import XCTest
import Foundation
import CoreGraphics
import Layout

/// Year page geometry (M3A_CONTRACT §1.8, DESIGN §2.2 / §2.6): 2026 with the screenshot-mode demo
/// events; "today" is 10/7 at 10:00.
final class YearLayoutEngineTests: XCTestCase {
    private typealias F = M3aFixtures
    private var demo: [LayoutEvent] { F.demo }
    private let cellX10 = 56.0 + 9 * 112
    private func key(_ raw: String) -> CellKey { CellKey(raw: raw) }

    func testRowHeight() {
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 0), 60)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 1, inkBottom: 0), 60, "16 + 18 + 8 = 42 → base")
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 2, inkBottom: 0), 60, "16 + 36 + 8 = 60")
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 3, inkBottom: 0), 78)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 4, inkBottom: 0), 96)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 100), 112)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 40, inkBottom: 0), 400)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 5000), 400)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: .nan), 60)
    }

    func testEmptyYear() {
        let page = F.yearLayout([])
        XCTAssertEqual(page.pageId, "y-2026")
        XCTAssertEqual(page.kind, .year)
        XCTAssertEqual(page.year, 2026)
        XCTAssertEqual(page.rows.count, 31)
        XCTAssertEqual(page.cells.count, 372)
        XCTAssertEqual(page.invalidCells.map(\.raw), ["02-29", "02-30", "02-31", "04-31", "06-31", "09-31", "11-31"])
        XCTAssertEqual(F.yearLayout([], year: 2028).invalidCells.map(\.raw), ["02-30", "02-31", "04-31", "06-31", "09-31", "11-31"], "2028 has a 2/29")
        XCTAssertEqual(page.dateLabels.count, 365)
        XCTAssertEqual(F.yearLayout([], year: 2028).dateLabels.count, 366)
        XCTAssertEqual(page.size, CGSize(width: 1400, height: 1860))
        XCTAssertEqual(page.rows.map(\.frame.minY).prefix(3).map { $0 }, [0, 60, 120])
        XCTAssertEqual(page.rows.map(\.dayNumber), Array(1...31))
        XCTAssertEqual(page.rows.map(\.laneCount), Array(repeating: 0, count: 31))
        XCTAssertEqual(page.cellFrame(month: 10, day: 7), CGRect(x: 56 + 9 * 112, y: 6 * 60, width: 112, height: 60))
        XCTAssertEqual(page.cellFrame(month: 1, day: 1), CGRect(x: 56, y: 0, width: 112, height: 60))
        XCTAssertEqual(page.cellFrame(month: 2, day: 30), CGRect(x: 168, y: 29 * 60, width: 112, height: 60), "2/30 has a cell too")
        XCTAssertNil(page.cellFrame(month: 13, day: 1))
        XCTAssertNil(page.cellFrame(month: 0, day: 1))
        XCTAssertNil(page.cellFrame(month: 1, day: 32))
        XCTAssertNil(page.cellFrame(month: 1, day: 0))
        XCTAssertEqual(page.columnFrame(month: 12), CGRect(x: 56 + 11 * 112, y: 0, width: 112, height: 1860))
        XCTAssertEqual(page.columnFrame(month: 1), CGRect(x: 56, y: 0, width: 112, height: 1860))
        XCTAssertEqual(page.columnFrame(month: 12).maxX, 1400)
        XCTAssertEqual(page.chips.count, 0)
        XCTAssertEqual(page.allDayBars.count, 0)
        XCTAssertEqual(page.timedBoxes.count, 0)
        XCTAssertNil(page.nowLine)
        XCTAssertEqual(page.todayCell, key("10-07"))
        XCTAssertNil(F.yearLayout([], year: 2025).todayCell)
        XCTAssertEqual(F.yearLayout([], year: 2028).cells[key("02-29")]?.minY, 28 * 60)
    }

    func testDateLabels() {
        let page = F.yearLayout([])
        let labels = Dictionary(uniqueKeysWithValues: page.dateLabels.map { ($0.day, $0) })
        XCTAssertEqual(labels[F.day(2026, 10, 7)]?.frame, CGRect(x: 56 + 9 * 112, y: 360, width: 40, height: 28))
        XCTAssertEqual(labels[F.day(2026, 10, 7)]?.isToday, true)
        XCTAssertEqual(labels[F.day(2026, 10, 12)]?.holidayName, "スポーツの日")
        XCTAssertEqual(labels[F.day(2026, 10, 12)]?.tone, .sundayOrHoliday)
        XCTAssertEqual(labels[F.day(2026, 10, 11)]?.tone, .sundayOrHoliday)
        XCTAssertEqual(labels[F.day(2026, 10, 10)]?.tone, .saturday)
        XCTAssertEqual(labels[F.day(2026, 10, 9)]?.tone, .normal)
        XCTAssertEqual(labels[F.day(2026, 1, 1)]?.holidayName, "元日")
        XCTAssertEqual(labels[F.day(2026, 12, 31)]?.frame.minY, 30 * 60)
        XCTAssertEqual(page.dateLabels.filter(\.isToday).count, 1)
        XCTAssertEqual(page.dateLabels.map(\.inMonth), Array(repeating: true, count: 365))
        XCTAssertNil(labels[F.day(2026, 2, 29)])
        XCTAssertEqual(page.dateLabels.first?.day, F.day(2026, 1, 1), "month by month, day by day")
        XCTAssertEqual(page.dateLabels[31].day, F.day(2026, 2, 1))
    }

    func testCellsAndInkCells() {
        let page = F.yearLayout([])
        XCTAssertNil(page.cell(at: CGPoint(x: 30, y: 100)), "the day-number gutter belongs to no cell")
        XCTAssertEqual(page.cell(at: CGPoint(x: 56, y: 100)), key("01-02"))
        XCTAssertEqual(page.cell(at: CGPoint(x: 1400, y: 100)), key("12-02"), "the right edge is December")
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: 1860)))
        XCTAssertNil(page.cell(at: CGPoint(x: 1401, y: 100)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: -1)))
        XCTAssertNil(page.cell(at: CGPoint(x: CGFloat.nan, y: 100)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 56 + 112, y: 100)), key("02-02"), "a column boundary maps to its own column")
        XCTAssertEqual(page.cell(at: CGPoint(x: 200, y: 1800)), key("02-31"), "an impossible date is a cell")
        XCTAssertEqual(page.cell(at: CGPoint(x: 100, y: 1859.9)), key("01-31"))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 30, y: 100)), key("01-02"), "gutter → January")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -10, y: -10)), key("01-01"))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 1500, y: 100)), key("12-02"))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 100, y: 5000)), key("01-31"))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: 100)), key("04-02"))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: CGFloat.nan)), key("01-01"))
        XCTAssertTrue(page.growsWithInk(key("02-30")))
        XCTAssertTrue(page.growsWithInk(key("12-31")))
        XCTAssertFalse(page.growsWithInk(.memo))
        XCTAssertFalse(page.growsWithInk(.grid))
        XCTAssertFalse(page.growsWithInk(key("13-01")))
        XCTAssertEqual(page.row(atY: 0), 1)
        XCTAssertEqual(page.row(atY: 1859.9), 31)
        XCTAssertNil(page.row(atY: 1860))
        XCTAssertNil(page.row(atY: -0.1))
        XCTAssertNil(page.row(atY: .nan))
    }

    func testBandsAndHitTestingOnAnEmptyYear() {
        let page = F.yearLayout([])
        XCTAssertEqual(page.band(atY: 100), PageBand(raw: "row:2"))
        XCTAssertEqual(page.band(atY: 0), PageBand(raw: "row:1"))
        XCTAssertNil(page.band(atY: 1860))
        XCTAssertEqual(page.bandTop(PageBand(raw: "row:2")), 60)
        XCTAssertEqual(page.bandTop(PageBand(raw: "row:31")), 1800)
        XCTAssertNil(page.bandTop(PageBand(raw: "row:0")))
        XCTAssertNil(page.bandTop(PageBand(raw: "row:32")))
        XCTAssertNil(page.bandTop(PageBand(raw: "memo")))
        XCTAssertEqual(page.hit(at: CGPoint(x: 56 + 9 * 112 + 5, y: 365)), .date(F.day(2026, 10, 7)), "the weekday letter")
        XCTAssertEqual(page.hit(at: CGPoint(x: 56 + 9 * 112 + 39, y: 360 + 27)), .date(F.day(2026, 10, 7)))
        XCTAssertNil(page.hit(at: CGPoint(x: 168 + 5, y: 29 * 60 + 5)), "an impossible date has no weekday letter")
        XCTAssertNil(page.hit(at: CGPoint(x: 56 + 9 * 112 + 100, y: 400)), "empty cell")
        XCTAssertNil(page.hit(at: CGPoint(x: 20, y: 400)), "the gutter")
    }

    /// 1.0.1: the screen's finger tap on the year page (`hit(at:minTarget:)`, minTarget = 44 pt ÷
    /// zoom). At the overview the 40 × 28 weekday frame was 11.5 × 8 pt on an iPhone (the jump to
    /// the day page was lost there); the date area is now the cell's left 45 % × 28 lu, grown to
    /// 44 pt on screen and clipped to the cell. Chips keep precedence, nothing else changes.
    func testDateTargetIsAtLeast44PointsOnScreen() {
        let page = F.yearLayout([])
        let oct7 = F.day(2026, 10, 7)
        XCTAssertEqual(page.cellFrame(month: 10, day: 7), CGRect(x: 1064, y: 360, width: 112, height: 60))
        // The weekday frame alone misses the middle of the cell (the 1.0 behaviour).
        XCTAssertNil(page.hit(at: CGPoint(x: 1120, y: 390)), "the old target: the middle of the cell is outside 40 × 28")

        // (1) iPhone overviews (portrait 402 / 390 / 440 pt, landscape 0.1237): the whole cell.
        for zoom: CGFloat in [402.0 / 1400, 390.0 / 1400, 440.0 / 1400, 0.1237] {
            let target = 44 / zoom
            XCTAssertEqual(page.hit(at: CGPoint(x: 1120, y: 390), minTarget: target), .date(oct7), "zoom \(zoom): the middle of 10/7")
            XCTAssertEqual(page.hit(at: CGPoint(x: 1174, y: 418), minTarget: target), .date(oct7), "zoom \(zoom): the bottom-right of 10/7")
            XCTAssertEqual(page.hit(at: CGPoint(x: 112, y: 30), minTarget: target), .date(F.day(2026, 1, 1)), "zoom \(zoom): the middle of 1/1")
            XCTAssertEqual(page.hit(at: CGPoint(x: 1344, y: 1830), minTarget: target), .date(F.day(2026, 12, 31)), "zoom \(zoom): the middle of 12/31")
            // (5) Still nil: a date that does not exist, the gutter, outside the paper.
            XCTAssertNil(page.hit(at: CGPoint(x: 224, y: 1770), minTarget: target), "zoom \(zoom): 2/30")
            XCTAssertNil(page.hit(at: CGPoint(x: 20, y: 390), minTarget: target), "zoom \(zoom): the day-number gutter")
            XCTAssertNil(page.hit(at: CGPoint(x: 1401, y: 390), minTarget: target), "zoom \(zoom): right of the paper")
            XCTAssertNil(page.hit(at: CGPoint(x: 700, y: 1860), minTarget: target), "zoom \(zoom): below the paper")
        }

        // (2) The 13-inch overview (0.6065): 72.5 lu × the cell's 60 lu (44 × 36 pt).
        let ipad13: CGFloat = 44 / 0.6065
        XCTAssertEqual(page.hit(at: CGPoint(x: 1134, y: 410), minTarget: ipad13), .date(oct7), "70 lu from the left edge")
        XCTAssertNil(page.hit(at: CGPoint(x: 1145, y: 380), minTarget: ipad13), "81 lu is beyond 72.5 lu")

        // (3) The readable zoom (1.339): 50.4 lu (「7 水」) × 32.9 lu.
        let readable = 44 / ZoomPolicy.readableZoom(.year)
        XCTAssertEqual(page.hit(at: CGPoint(x: 1109, y: 372), minTarget: readable), .date(oct7), "the right half of 「水」")
        XCTAssertNil(page.hit(at: CGPoint(x: 1164, y: 410), minTarget: readable), "the handwriting part of the cell")
        XCTAssertNil(page.hit(at: CGPoint(x: 1109, y: 395), minTarget: readable), "35 lu is below 32.9 lu")

        // (4) 4×: back to 50.4 × 28 lu (the old frame plus the right of 「水」).
        XCTAssertEqual(page.hit(at: CGPoint(x: 1109, y: 387), minTarget: 11), .date(oct7))
        XCTAssertNil(page.hit(at: CGPoint(x: 1109, y: 389), minTarget: 11))

        // (6) A minTarget that is not a positive number: the same as `hit(at:)`.
        let probes = [CGPoint(x: 1120, y: 390), CGPoint(x: 1069, y: 365), CGPoint(x: 20, y: 390), CGPoint(x: 224, y: 1770)]
        for bad: CGFloat in [.nan, .infinity, 0, -5] {
            for p in probes {
                XCTAssertEqual(page.hit(at: p, minTarget: bad), page.hit(at: p), "minTarget \(bad) at \(p)")
            }
        }
        XCTAssertNil(page.hit(at: CGPoint(x: CGFloat.nan, y: 390), minTarget: 44 / (402.0 / 1400)), "NaN x")

        // (7) Chips first, at an iPhone's overview: a normal chip opens the event, a thin chip its day.
        let iphone: CGFloat = 44 / (402.0 / 1400)
        let demoPage = F.yearLayout(demo)
        let deadline = demoPage.chips.first { $0.title == "締切" }
        XCTAssertNotNil(deadline)
        XCTAssertEqual(demoPage.hit(at: CGPoint(x: cellX10 + 55, y: 360 + 20), minTarget: iphone), .allDayBar(deadline?.eventId ?? "?"), "a chip")
        XCTAssertEqual(demoPage.hit(at: CGPoint(x: cellX10 + 5, y: 365), minTarget: iphone), .date(oct7), "the weekday letter next to a chip")
        XCTAssertEqual(demoPage.hit(at: CGPoint(x: cellX10 + 45, y: 360 + 50), minTarget: iphone), .date(oct7), "the rest of the cell at the overview")
        var pile: [LayoutEvent] = [LayoutEvent(id: "march", title: "3月", allDay: true, start: F.date(2026, 3, 20), end: F.date(2026, 3, 21), colorHex: "#000000", calendarId: "c")]
        for i in 0..<40 { pile.append(F.allDay("pile\(i)", 20, 21, title: "p\(i)")) }
        let capped = F.yearLayout(pile)
        XCTAssertEqual(capped.hit(at: CGPoint(x: cellX10 + 55, y: capped.rows[19].frame.minY + 17), minTarget: iphone), .date(F.day(2026, 10, 20)), "a thin chip opens the day")
        XCTAssertEqual(capped.hit(at: CGPoint(x: 56 + 2 * 112 + 55, y: capped.rows[19].frame.minY + 17), minTarget: iphone), .allDayBar("march"), "a normal chip opens the event")
    }

    func testDayAtRejectsMissingDates() {
        // M4c, M4C_CONTRACT §4.3: the double tap's target is the cell's date; a date that does not
        // exist, the day-number gutter, the outside and NaN are nil.
        let page = F.yearLayout([])
        XCTAssertEqual(page.dayAt(point: CGPoint(x: cellX10 + 10, y: 6 * 60 + 10)), F.day(2026, 10, 7))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 168 + 10, y: 29 * 60 + 10)), "2/30")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 168 + 10, y: 28 * 60 + 10)), "2/29 of a common year")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 168 + 10, y: 27 * 60 + 10)), F.day(2026, 2, 28))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 56 + 3 * 112 + 5, y: 30 * 60 + 5)), "4/31")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 56 + 10 * 112 + 5, y: 30 * 60 + 5)), "11/31")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 700, y: 1859.9)), "6/31")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 1400, y: 1859.9)), F.day(2026, 12, 31), "the bottom-right cell")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 1400, y: 10)), F.day(2026, 12, 1), "x 1400 belongs to December")
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 56, y: 0)), F.day(2026, 1, 1))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 10, y: 400)), "the day-number gutter")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 55.9, y: 400)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 1401, y: 10)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 700, y: 1860)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 700, y: -0.1)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: CGFloat.nan, y: 100)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 700, y: CGFloat.nan)))
        XCTAssertEqual(page.dayAt(point: CGPoint(x: 56 + 112, y: 100)), F.day(2026, 2, 2), "a column boundary belongs to February")
        XCTAssertEqual(F.yearLayout([], year: 2028).dayAt(point: CGPoint(x: 168 + 10, y: 28 * 60 + 10)), F.day(2028, 2, 29), "a leap year")
        XCTAssertNil(F.yearLayout([], year: 2028).dayAt(point: CGPoint(x: 168 + 10, y: 29 * 60 + 10)))
        XCTAssertEqual(F.yearLayout([], year: 2027).dayAt(point: CGPoint(x: cellX10 + 10, y: 6 * 60 + 10)), F.day(2027, 10, 7))
        for m in 1...12 {
            let daysInMonth = DayKey.daysInMonth(year: 2026, month: m)
            let x = 56 + CGFloat(m - 1) * 112 + 56
            XCTAssertEqual(page.dayAt(point: CGPoint(x: x, y: CGFloat(daysInMonth - 1) * 60 + 30)), F.day(2026, m, daysInMonth), "the last day of month \(m)")
            if daysInMonth < 31 {
                XCTAssertNil(page.dayAt(point: CGPoint(x: x, y: CGFloat(daysInMonth) * 60 + 30)), "month \(m) has no day \(daysInMonth + 1)")
            }
        }
        let grown = F.yearLayout(demo) // the 16th's row is 96
        XCTAssertEqual(grown.dayAt(point: CGPoint(x: cellX10 + 55, y: grown.rows[15].frame.minY + 20)), F.day(2026, 10, 16), "on a chip")
        XCTAssertEqual(grown.dayAt(point: CGPoint(x: cellX10 + 5, y: grown.rows[16].frame.minY + 5)), F.day(2026, 10, 17), "under the grown row")
        XCTAssertEqual(grown.dayAt(point: CGPoint(x: 56 + 5, y: grown.rows[16].frame.minY + 5)), F.day(2026, 1, 17))
        var rng = M3aFixtures.Rng(seed: 0x4D34_6301)
        for _ in 0..<40 {
            let p = CGPoint(x: CGFloat(rng.int(1500)) - 50, y: CGFloat(rng.int(2000)) - 50)
            let expected = page.cell(at: p)?.yearMonthDay.flatMap { md -> DayKey? in
                let d = DayKey(year: 2026, month: md.month, day: md.day)
                return d.isValid ? d : nil
            }
            XCTAssertEqual(page.dayAt(point: p), expected, "dayAt == the valid date of cell(at:) at \(p)")
        }
        XCTAssertEqual((page as any PageLayout).dayAt(point: CGPoint(x: cellX10 + 10, y: 6 * 60 + 10)), F.day(2026, 10, 7), "dynamic dispatch through any PageLayout")
    }

    func testDemoEventsGrowRowsAndLinkChips() {
        let plain = F.yearLayout([])
        let page = F.yearLayout(demo)
        XCTAssertEqual(page.rows[15].frame.height, 96, "10/16 has 4 all-day events → 16 + 4 × 18 + 8")
        XCTAssertEqual(page.rows[15].laneCount, 4)
        XCTAssertEqual(page.rows[16].frame.minY, plain.rows[16].frame.minY + 36)
        XCTAssertEqual(page.cells[key("02-16")]?.height, 96, "February's 16th cell is as tall")
        XCTAssertEqual(page.cells[key("02-16")]?.minY, 900)
        XCTAssertEqual(page.cellFrame(month: 10, day: 7), CGRect(x: 56 + 9 * 112, y: 6 * 60, width: 112, height: 60), "10/7 stays 60 with one lane")
        XCTAssertEqual(page.size.height, 1860 + 36)
        XCTAssertEqual(page.rows[14].frame.height, 60)

        let trip = page.chips.filter { $0.title == "家族旅行" }.sorted { $0.day < $1.day }
        XCTAssertEqual(trip.count, 5)
        XCTAssertEqual(trip.map(\.day.day), [9, 10, 11, 12, 13])
        XCTAssertEqual(Set(trip.map(\.lane)).count, 1)
        XCTAssertEqual(trip[0].lane, 0)
        XCTAssertFalse(trip[0].continuesUp)
        XCTAssertTrue(trip[0].continuesDown)
        XCTAssertTrue(trip[2].continuesUp)
        XCTAssertTrue(trip[2].continuesDown)
        XCTAssertTrue(trip[4].continuesUp)
        XCTAssertFalse(trip[4].continuesDown)
        XCTAssertEqual(trip[0].linkToY, trip[1].frame.minY)
        XCTAssertEqual(trip[3].linkToY, trip[4].frame.minY)
        XCTAssertNil(trip[4].linkToY)
        assertRect(trip[0].frame, CGRect(x: cellX10 + 50.4, y: 8 * 60 + 16, width: 58.6, height: 16), "chip in the right 55 % of the cell")
        XCTAssertFalse(trip[0].isThin)
        XCTAssertEqual(trip[0].fontScale, 1)
        XCTAssertEqual(trip[0].colorHex, F.demoColors[1])
        XCTAssertEqual(trip[0].eventId, F.demoId("家族旅行"))

        let sixteenth = page.chips.filter { $0.day == F.day(2026, 10, 16) }.sorted { $0.lane < $1.lane }
        XCTAssertEqual(sixteenth.count, 4)
        XCTAssertEqual(sixteenth.map(\.lane), [0, 1, 2, 3])
        XCTAssertEqual(sixteenth.map(\.title), ["ゴミの日", "健康診断", "誕生日", "資料提出締切"], "same day and length → by title (Unicode order)")
        XCTAssertEqual(sixteenth[3].frame.minY, page.rows[15].frame.minY + 16 + 3 * 18, accuracy: 1e-9)
        XCTAssertEqual(sixteenth.map { $0.linkToY == nil }, [true, true, true, true])
        XCTAssertEqual(page.chips.filter { $0.title == "歯医者" }.count, 0, "timed events are not on the year page")
        XCTAssertEqual(page.chips.count, 16, "運動会, キャンプ×2, 家族旅行×5, the 16th×4, 出張×2, 給料日, 締切")
        let business = page.chips.filter { $0.title == "出張（大阪）" }.sorted { $0.day < $1.day }
        XCTAssertEqual(business.map(\.day.day), [21, 22])
        XCTAssertEqual(business[0].linkToY, business[1].frame.minY)
    }

    func testHitTestingBandsAndScrollWithDemoEvents() {
        let plain = F.yearLayout([])
        let page = F.yearLayout(demo)
        let deadline = page.chips.first { $0.title == "締切" }
        XCTAssertNotNil(deadline)
        XCTAssertEqual(page.hit(at: CGPoint(x: cellX10 + 55, y: 360 + 20)), .allDayBar(deadline?.eventId ?? "?"), "a chip")
        XCTAssertEqual(page.hit(at: CGPoint(x: cellX10 + 5, y: 365)), .date(F.day(2026, 10, 7)), "the weekday letter next to a chip")
        XCTAssertNil(page.hit(at: CGPoint(x: cellX10 + 45, y: 360 + 50)), "the handwriting part of the cell")
        XCTAssertEqual(page.band(atY: page.rows[16].frame.minY + 5), PageBand(raw: "row:17"))
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 1000), 36, "a point on the 17th moves down")
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 930), 0, "a point on the 16th stays")
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 100), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: plain, topVisibleY: 1800), -36)
        XCTAssertEqual(PageScroll.scrollDelta(old: plain, new: page, topVisibleY: 1860), 0, "below the paper")
        XCTAssertFalse(plain.sameGeometry(as: page))
        XCTAssertTrue(plain.sameGeometry(as: F.yearLayout([], now: F.october(20, 9))))
        XCTAssertFalse(plain.sameGeometry(as: F.yearLayout([], year: 2027)))
        XCTAssertEqual(page, F.yearLayout(demo))
    }

    func testInkGrowsRows() {
        let page = F.yearLayout([], ink: [key("03-05"): 100, key("07-05"): 150, key("02-30"): 90, key("01-01"): .nan])
        XCTAssertEqual(page.rows[4].frame.height, 162, "row 5: the deepest ink 150 + 12")
        XCTAssertEqual(page.rows[29].frame.height, 102, "an impossible date's ink grows its row too")
        XCTAssertEqual(page.rows[0].frame.height, 60, "NaN ink is ignored")
        XCTAssertEqual(page.rows[5].frame.minY, 300 + 102)
        XCTAssertEqual(page.cells[key("12-05")]?.height, 162, "every cell of the row grows")
        XCTAssertEqual(page.size.height, 1860 + 102 + 42)
        XCTAssertEqual(F.yearLayout([], ink: [key("01-01"): 5000]).rows[0].frame.height, 400, "capped at 400")
    }

    func testThinningAtTheCap() {
        var pile: [LayoutEvent] = [LayoutEvent(id: "march", title: "3月", allDay: true, start: F.date(2026, 3, 20), end: F.date(2026, 3, 21), colorHex: "#000000", calendarId: "c")]
        for i in 0..<40 { pile.append(F.allDay("pile\(i)", 20, 21, title: "p\(i)")) }
        let page = F.yearLayout(pile)
        XCTAssertEqual(page.rows[19].frame.height, 400)
        XCTAssertEqual(page.rows[19].laneCount, 40)
        let thin = page.chips.filter { $0.day == F.day(2026, 10, 20) }.sorted { $0.lane < $1.lane }
        XCTAssertEqual(thin.count, 40)
        let step = 378.0 / 40
        XCTAssertEqual(thin[1].frame.minY - thin[0].frame.minY, step, accuracy: 1e-9, "thinned step 378 / 40")
        XCTAssertEqual(thin[0].frame.height, step - 2, accuracy: 1e-9)
        XCTAssertTrue(thin.allSatisfy(\.isThin), "lanes below 12 are thin")
        XCTAssertEqual(thin[0].fontScale, (step - 2) / 16, accuracy: 1e-9)
        XCTAssertEqual(thin[39].frame.maxY, page.rows[19].frame.minY + 16 + 39 * step + step - 2, accuracy: 1e-9)
        XCTAssertEqual(thin[39].frame.maxY, page.rows[19].frame.maxY - 8, accuracy: 1e-9, "the last chip ends at the ink margin")
        let march = page.chips.first { $0.eventId == "march" }
        XCTAssertEqual(march?.frame.height, 16, "another month's chip on the same row is not thinned")
        XCTAssertEqual(march?.isThin, false)
        XCTAssertEqual(march?.fontScale, 1)
        XCTAssertEqual(march?.frame.minY, page.rows[19].frame.minY + 16)
        XCTAssertEqual(page.hit(at: CGPoint(x: cellX10 + 55, y: page.rows[19].frame.minY + 17)), .date(F.day(2026, 10, 20)), "a thin chip opens the day")
        XCTAssertEqual(page.hit(at: CGPoint(x: 56 + 2 * 112 + 55, y: page.rows[19].frame.minY + 17)), .allDayBar("march"), "a normal chip opens the event")
        // 21 lanes: the row is capped at 400 but the lanes still fit (16 + 20 × 18 + 16 = 392).
        let twentyOne = F.yearLayout((0..<21).map { F.allDay("q\($0)", 20, 21) })
        XCTAssertEqual(twentyOne.rows[19].frame.height, 400)
        XCTAssertEqual(twentyOne.chips.filter { $0.day == F.day(2026, 10, 20) }.map(\.frame.height), Array(repeating: 16, count: 21))
    }

    func testMonthSpansAndInitialScroll() {
        let spans = YearLayoutEngine.monthSpans(events: demo, year: 2026, month: 10, calendar: F.tokyo)
        XCTAssertEqual(spans.first { $0.event.title == "家族旅行" }.map { [$0.startCol, $0.endCol, $0.lane] }, [8, 12, 0])
        XCTAssertEqual(spans.filter { $0.startCol == 15 }.map(\.lane).sorted(), [0, 1, 2, 3])
        XCTAssertEqual(spans.count, 10, "the 10 all-day demo events of October")
        XCTAssertEqual(YearLayoutEngine.monthSpans(events: demo, year: 2026, month: 9, calendar: F.tokyo).count, 0)
        XCTAssertEqual(YearLayoutEngine.monthSpans(events: demo, year: 2026, month: 13, calendar: F.tokyo).count, 0)
        // An event crossing the month boundary is clipped per month.
        let crossing = [F.allDay("x", 30, 34)] // 10/30 – 11/2
        XCTAssertEqual(YearLayoutEngine.monthSpans(events: crossing, year: 2026, month: 10, calendar: F.tokyo).map { [$0.startCol, $0.endCol] }, [[29, 30]])
        XCTAssertEqual(YearLayoutEngine.monthSpans(events: crossing, year: 2026, month: 11, calendar: F.tokyo).map { [$0.startCol, $0.endCol] }, [[0, 1]])
        let crossingPage = F.yearLayout(crossing)
        let oct31 = crossingPage.chips.first { $0.day == F.day(2026, 10, 31) }
        XCTAssertEqual(oct31?.continuesDown, true)
        XCTAssertNil(oct31?.linkToY, "no link past the month's last day")
        XCTAssertEqual(crossingPage.chips.first { $0.day == F.day(2026, 11, 1) }?.continuesUp, true)

        let page = F.yearLayout(demo)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), page.rows[4].frame.minY, "today 10/7 → the row of the 5th")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.date(2026, 1, 1, 9), calendar: F.tokyo), 0)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.date(2026, 1, 2, 9), calendar: F.tokyo), 0)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.date(2026, 1, 3, 9), calendar: F.tokyo), 0)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.date(2026, 1, 4, 9), calendar: F.tokyo), 60)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.date(2025, 10, 7, 9), calendar: F.tokyo), 0, "another year")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.date(2026, 10, 31, 9), calendar: F.tokyo), page.rows[28].frame.minY)
    }

    // MARK: The left gutter's day numbers (1.1, P-13, M7A_CONTRACT §4.3)

    func testGutterDay() {
        let page = F.yearLayout([])
        // Row 15 is y 840…900 (middle 870); the number is the middle ± 14.
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 10, y: 841), numberOnly: false), 15, "the whole row")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 10, y: 841), numberOnly: true), "the row's top edge is outside the number")
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 10, y: 856), numberOnly: true), 15, "middle − 14")
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 10, y: 884), numberOnly: true), 15, "middle + 14")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 10, y: 855.99), numberOnly: true))
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 10, y: 884.01), numberOnly: true))
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 0, y: 870), numberOnly: false), 15, "x 0")
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 55.99, y: 870), numberOnly: true), 15, "x 55.99")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 56, y: 870), numberOnly: false), "x 56 is January's column")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: -0.1, y: 870), numberOnly: false), "the paper's left margin (x < 0)")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 10, y: -1), numberOnly: false), "above the paper")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 10, y: 1860), numberOnly: false), "below the paper")
        XCTAssertNil(page.gutterDay(at: CGPoint(x: CGFloat.nan, y: 870), numberOnly: false))
        XCTAssertNil(page.gutterDay(at: CGPoint(x: 10, y: CGFloat.infinity), numberOnly: false))
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 10, y: 0), numberOnly: false), 1)
        XCTAssertEqual(page.gutterDay(at: CGPoint(x: 10, y: 1859.9), numberOnly: false), 31)
        for d in 1...31 {
            let row = page.rows[d - 1].frame
            XCTAssertEqual(page.gutterDay(at: CGPoint(x: 28, y: row.midY), numberOnly: true), d, "the number \(d)")
            XCTAssertEqual(page.gutterDay(at: CGPoint(x: 28, y: row.minY), numberOnly: false), d, "the top of row \(d)")
        }
        // A grown row: its middle moves with it.
        let grown = F.yearLayout([], ink: [CellKey(raw: "03-15"): 100]) // row 15 → 112
        let row15 = grown.rows[14].frame
        XCTAssertEqual(row15.height, 112)
        XCTAssertEqual(grown.gutterDay(at: CGPoint(x: 10, y: row15.midY + 14), numberOnly: true), 15)
        XCTAssertNil(grown.gutterDay(at: CGPoint(x: 10, y: row15.minY + 2), numberOnly: true))
        XCTAssertEqual(grown.gutterDay(at: CGPoint(x: 10, y: row15.minY + 2), numberOnly: false), 15)
        // The gutter is still not a cell: double taps and hit(at:) do nothing there.
        XCTAssertNil(page.dayAt(point: CGPoint(x: 10, y: 870)))
        XCTAssertNil(page.hit(at: CGPoint(x: 10, y: 870)))
        XCTAssertNil(page.hit(at: CGPoint(x: 10, y: 870), minTarget: 153))
    }

    func testGutterHitUsesTheGivenMonth() {
        let page = F.yearLayout([])
        let p15 = CGPoint(x: 10, y: 870)
        XCTAssertEqual(page.gutterHit(at: p15, numberOnly: false, month: 10), .date(F.day(2026, 10, 15)), "this month's 15th")
        XCTAssertEqual(page.gutterHit(at: p15, numberOnly: false, month: 1), .date(F.day(2026, 1, 15)))
        XCTAssertEqual(page.gutterHit(at: p15, numberOnly: true, month: 12), .date(F.day(2026, 12, 15)))
        XCTAssertNil(page.gutterHit(at: p15, numberOnly: false, month: 0))
        XCTAssertNil(page.gutterHit(at: p15, numberOnly: false, month: 13))
        XCTAssertNil(page.gutterHit(at: CGPoint(x: 10, y: 841), numberOnly: true, month: 10), "outside the number")
        let p31 = CGPoint(x: 10, y: 30 * 60 + 30)
        XCTAssertNil(page.gutterHit(at: p31, numberOnly: false, month: 11), "11/31 does not exist: nothing happens (M7A-3)")
        XCTAssertNil(page.gutterHit(at: p31, numberOnly: false, month: 4), "4/31")
        XCTAssertEqual(page.gutterHit(at: p31, numberOnly: false, month: 12), .date(F.day(2026, 12, 31)))
        let p29 = CGPoint(x: 10, y: 28 * 60 + 30)
        let p30 = CGPoint(x: 10, y: 29 * 60 + 30)
        XCTAssertNil(page.gutterHit(at: p29, numberOnly: false, month: 2), "2026-02-29 (a common year)")
        let leap = F.yearLayout([], year: 2028)
        XCTAssertEqual(leap.gutterHit(at: p29, numberOnly: false, month: 2), .date(F.day(2028, 2, 29)), "a leap year")
        XCTAssertNil(leap.gutterHit(at: p30, numberOnly: false, month: 2), "2/30")
        XCTAssertNil(page.gutterHit(at: CGPoint(x: 100, y: 870), numberOnly: false, month: 10), "January's cell is not the gutter")
        XCTAssertNil(page.gutterHit(at: CGPoint(x: -5, y: 870), numberOnly: false, month: 10), "the left margin")
    }
}
