import XCTest
import Foundation
import CoreGraphics
import Layout

/// Day page geometry (M3A_CONTRACT §1.7, M4B_CONTRACT §2.3, DESIGN §2.2 / §2.5): 2026-10-07 with
/// the screenshot-mode demo events; "today" is 10/7 at 10:00. Since M4b the paper is the 24-hour
/// grid alone; the all-day band is `allDayBand` (drawn by the screen).
final class DayLayoutEngineTests: XCTestCase {
    private typealias F = M3aFixtures
    private var demo: [LayoutEvent] { F.demo }
    private func id(_ title: String) -> String { F.demoId(title) }

    func testGeometry() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.pageId, "d-2026-10-07")
        XCTAssertEqual(page.kind, .day)
        XCTAssertEqual(page.day, F.day(2026, 10, 7))
        XCTAssertTrue(page.isToday)
        XCTAssertEqual(page.size, CGSize(width: 1000, height: 2400), "the paper is the grid alone")
        XCTAssertEqual(page.grid, CGRect(x: 0, y: 0, width: 1000, height: 2400))
        XCTAssertEqual(page.timeline, CGRect(x: 72, y: 0, width: 588, height: 2400))
        XCTAssertEqual(page.memo, CGRect(x: 660, y: 0, width: 340, height: 2400))
        XCTAssertEqual(page.cells.count, 1)
        XCTAssertNil(page.cells[.allDayDay], "no band cell on the paper")
        XCTAssertEqual(page.cells[.grid], CGRect(x: 0, y: 0, width: 1000, height: 2400))
        XCTAssertEqual(page.allDayBars.count, 0, "always empty")
        XCTAssertEqual(page.dateLabels.count, 1)
        XCTAssertEqual(page.dateLabels[0].frame, CGRect(x: 72, y: 0, width: 588, height: 0))
        XCTAssertTrue(page.dateLabels[0].isToday)
        XCTAssertEqual(page.dateLabels[0].tone, .normal)
        XCTAssertNil(page.dateLabels[0].holidayName)
        XCTAssertTrue(page.dateLabels[0].inMonth)
        XCTAssertEqual(page.nowLine, NowLine(y: 1000, x0: 72, x1: 660, minute: 600))
        XCTAssertEqual(page.minutesToY(600), 1000)
        XCTAssertEqual(page.minutesToY(1440), 2400)
    }

    func testAllDayBand() {
        let page = F.dayLayout(demo)
        let band = page.allDayBand
        XCTAssertEqual(band.kind, .day)
        XCTAssertEqual(band.days, [F.day(2026, 10, 7)])
        XCTAssertEqual(band.tones, [.normal])
        XCTAssertEqual(band.paperWidth, 1000)
        XCTAssertEqual(band.gutter, 72)
        XCTAssertEqual(band.columnMinX, [72])
        XCTAssertEqual(band.columnWidth, 588)
        XCTAssertEqual(band.laneCount, 1)
        XCTAssertEqual(band.todayColumn, 0)
        XCTAssertEqual(band.bars.count, 1)
        XCTAssertEqual(band.bars[0].title, "締切")
        XCTAssertEqual(band.bars[0].eventId, id("締切"))
        XCTAssertEqual(band.bars[0].minX, 76, "72 + 4")
        XCTAssertEqual(band.bars[0].maxX, 648, "660 − 12")
        XCTAssertEqual(band.bars[0].lane, 0)
        XCTAssertEqual(band.bars[0].startCol, 0)
        XCTAssertEqual(band.bars[0].endCol, 0)
        XCTAssertFalse(band.bars[0].continuesLeft)
        XCTAssertFalse(band.bars[0].continuesRight)
        XCTAssertEqual(band, AllDayBandEngine.day(F.day(2026, 10, 7), events: demo, now: F.demoNow, calendar: F.tokyo), "the page carries the engine's band")

        let busy = F.dayLayout(demo + [F.allDay("a", 7, 8, title: "a"), F.allDay("b", 1, 20, title: "b")])
        XCTAssertEqual(busy.allDayBand.laneCount, 3)
        XCTAssertEqual(busy.allDayBand.bars.map(\.title), ["b", "a", "締切"], "earlier start first (b since 10/1), then title")
        XCTAssertEqual(busy.allDayBand.bars.map(\.lane), [0, 1, 2], "lane = display order")
        XCTAssertEqual(busy.allDayBand.bars.map(\.minX), [76, 76, 76])
        XCTAssertTrue(busy.allDayBand.bars[0].continuesLeft)
        XCTAssertTrue(busy.allDayBand.bars[0].continuesRight)
        XCTAssertEqual(busy.cells[.grid]?.minY, 0, "the grid stays at the top")
        XCTAssertEqual(busy.size.height, 2400, "the paper does not grow with the band")
        XCTAssertEqual(busy.nowLine?.y, 1000)
        XCTAssertTrue(busy.sameGeometry(as: page))
    }

    func testTimedBoxes() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.timedBoxes.count, 3)
        let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
        let w2 = (570.0 - 3) / 2
        assertRect(boxes[id("打合せ")]?.frame, CGRect(x: 76, y: 1001, width: w2, height: 148), "column 0 of 2 (y from 0:00)")
        assertRect(boxes[id("電話")]?.frame, CGRect(x: 76 + w2 + 3, y: 1051, width: w2, height: 48), "column 1 of 2")
        assertRect(boxes[id("歯科")]?.frame, CGRect(x: 76, y: 1401, width: 570, height: 98), "alone")
        XCTAssertEqual(boxes[id("電話")]?.columns, 2)
        XCTAssertEqual(boxes[id("電話")]?.column, 1)
        XCTAssertEqual(boxes[id("電話")]?.timeText, "10:30〜11:00")
        XCTAssertEqual(boxes[id("電話")]?.startText, "10:30")
        XCTAssertEqual(boxes[id("歯科")]?.startMinute, 840)
        XCTAssertEqual(boxes[id("歯科")]?.endMinute, 900)
        XCTAssertEqual(boxes[id("歯科")]?.day, F.day(2026, 10, 7))
        XCTAssertEqual(page.timedBoxes.filter(\.isPast).count, 0, "nothing is past at 10:00")
        XCTAssertEqual(F.dayLayout(demo, now: F.october(7, 16)).timedBoxes.filter(\.isPast).count, 3)
        XCTAssertEqual(F.dayLayout(demo, now: F.october(7, 11, 30)).timedBoxes.filter(\.isPast).map(\.title).sorted(), ["打合せ", "電話"])
        // All-day events never become boxes; a long timed event does.
        let long = F.dayLayout([F.timed("long", 6, 20, 0, 9, 0, endDay: 8, title: "長い")])
        XCTAssertEqual(long.timedBoxes.count, 1)
        XCTAssertEqual(long.timedBoxes[0].startMinute, 0)
        XCTAssertEqual(long.timedBoxes[0].endMinute, 1440)
        assertRect(long.timedBoxes[0].frame, CGRect(x: 76, y: 1, width: 570, height: 2398))
        XCTAssertEqual(long.allDayBand.laneCount, 0)
    }

    func testHitTesting() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.hit(at: CGPoint(x: 100, y: 1010)), .timedBox(id("打合せ")))
        XCTAssertEqual(page.hit(at: CGPoint(x: 400, y: 1060)), .timedBox(id("電話")))
        XCTAssertNil(page.hit(at: CGPoint(x: 100, y: 10)), "the top of the paper is 0:00, not a chip")
        XCTAssertNil(page.hit(at: CGPoint(x: 800, y: 10)))
        XCTAssertNil(page.hit(at: CGPoint(x: 800, y: 1000)), "the memo area hits nothing")
        XCTAssertNil(page.hit(at: CGPoint(x: 30, y: 1000)), "the gutter hits nothing")
        XCTAssertNil(page.hit(at: CGPoint(x: 100, y: 100)))
        var withBar = page
        withBar.allDayBars.append(AllDayBar(eventId: "fake", frame: CGRect(x: 72, y: 1000, width: 588, height: 40), row: 0, lane: 0, continuesLeft: false, continuesRight: false, colorHex: "#000000", title: "x"))
        XCTAssertEqual(withBar.hit(at: CGPoint(x: 100, y: 1010)), .timedBox(id("打合せ")), "a box is hit")
        XCTAssertNil(withBar.hit(at: CGPoint(x: 500, y: 1030)), "a bar on the paper is never hit (the band is the screen's)")
    }

    func testCellsAndInkCells() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.cell(at: CGPoint(x: 900, y: 30)), .grid, "the memo area's top is the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 30, y: 30)), .grid, "the gutter's top is the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 900, y: 1000)), .grid, "the memo area is part of the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1000, y: 0)), .grid, "the top-right corner belongs to the grid")
        XCTAssertNil(page.cell(at: CGPoint(x: 1001, y: 60)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: 2400)))
        XCTAssertNil(page.cell(at: CGPoint(x: -1, y: 100)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: -0.1)))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 30)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 1000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 30, y: 1000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -10, y: -10)), .grid, "negative y too")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 2000, y: 9000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: CGFloat.nan)), .grid)
        XCTAssertFalse(page.growsWithInk(.allDayDay), "the former band cell")
        XCTAssertFalse(page.growsWithInk(.grid))
        XCTAssertFalse(page.growsWithInk(.memo))
        XCTAssertFalse(page.growsWithInk(.allDay(F.day(2026, 10, 7))))
    }

    func testBandsAndGeometry() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.band(atY: 30), PageBand(raw: "grid"))
        XCTAssertEqual(page.band(atY: 0), PageBand(raw: "grid"))
        XCTAssertEqual(page.band(atY: 2399), PageBand(raw: "grid"))
        XCTAssertNil(page.band(atY: 2400))
        XCTAssertNil(page.band(atY: -1))
        XCTAssertEqual(page.bandTop(PageBand(raw: "grid")), 0)
        XCTAssertNil(page.bandTop(PageBand(raw: "allday")), "the paper has no band")
        XCTAssertNil(page.bandTop(PageBand(raw: "memo")))
        let busy = F.dayLayout(demo + [F.allDay("a", 7, 8, title: "a"), F.allDay("b", 1, 20, title: "b")])
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 500), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 30), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: busy, new: page, topVisibleY: 500), 0)
        XCTAssertTrue(page.sameGeometry(as: busy))
        XCTAssertTrue(page.sameGeometry(as: F.dayLayout(demo, now: F.october(7, 15))))
        XCTAssertFalse(page.sameGeometry(as: F.dayLayout(demo, focus: F.day(2026, 10, 8))))
        let inked = F.dayLayout(demo, ink: [.allDayDay: 200, .grid: 9000])
        XCTAssertEqual(inked.size.height, 2400, "ink does not grow the paper")
        XCTAssertEqual(inked.timeline.minY, 0)
        XCTAssertEqual(inked.memo.minY, 0)
        XCTAssertEqual(inked, page, "ink bottoms are not read")
        XCTAssertEqual(inked.timedBoxes.first { $0.eventId == id("打合せ") }?.frame.minY, 1001)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 100), 0)
    }

    func testOtherDays() {
        let tomorrow = F.dayLayout(demo, focus: F.day(2026, 10, 8))
        XCTAssertEqual(tomorrow.pageId, "d-2026-10-08")
        XCTAssertFalse(tomorrow.isToday)
        XCTAssertNil(tomorrow.nowLine)
        XCTAssertFalse(tomorrow.dateLabels[0].isToday)
        XCTAssertEqual(tomorrow.allDayBand.laneCount, 0)
        XCTAssertEqual(tomorrow.allDayBand.bars.count, 0)
        XCTAssertNil(tomorrow.allDayBand.todayColumn)
        XCTAssertEqual(tomorrow.timedBoxes.map(\.title), ["資料提出"])
        XCTAssertEqual(tomorrow.size.height, 2400)
        let holiday = F.dayLayout([], focus: F.day(2026, 10, 12))
        XCTAssertEqual(holiday.dateLabels[0].holidayName, "スポーツの日")
        XCTAssertEqual(holiday.dateLabels[0].tone, .sundayOrHoliday)
        XCTAssertEqual(holiday.allDayBand.tones, [.sundayOrHoliday])
        let saturday = F.dayLayout([], focus: F.day(2026, 10, 10))
        XCTAssertEqual(saturday.dateLabels[0].tone, .saturday)
        XCTAssertEqual(saturday.allDayBand.tones, [.saturday])
        let trip = F.dayLayout(demo, focus: F.day(2026, 10, 11))
        XCTAssertEqual(trip.allDayBand.bars.map(\.title), ["家族旅行"])
        XCTAssertTrue(trip.allDayBand.bars[0].continuesLeft)
        XCTAssertTrue(trip.allDayBand.bars[0].continuesRight)
        XCTAssertEqual(trip.allDayBand.tones, [.sundayOrHoliday])
    }

    func testInitialScroll() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), 900, "today at 10:00 → 9:00 (100 lu per hour)")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.october(7, 0, 10), calendar: F.tokyo), 0, "clamped to 0:00")
        let tomorrow = F.dayLayout(demo, focus: F.day(2026, 10, 8))
        XCTAssertEqual(PageNavigation.initialScrollY(tomorrow, now: F.demoNow, calendar: F.tokyo), 700, "not today → 7:00")
        let busy = F.dayLayout(demo + [F.allDay("a", 7, 8), F.allDay("b", 7, 8)])
        XCTAssertEqual(PageNavigation.initialScrollY(busy, now: F.demoNow, calendar: F.tokyo), 900, "the band does not move the start")
    }
}
