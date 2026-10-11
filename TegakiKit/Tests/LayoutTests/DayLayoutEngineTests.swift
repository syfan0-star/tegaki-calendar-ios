import XCTest
import Foundation
import CoreGraphics
import Layout

/// Day page geometry (M3A_CONTRACT §1.7, DESIGN §2.2 / §2.5): 2026-10-07 with the screenshot-mode
/// demo events; "today" is 10/7 at 10:00.
final class DayLayoutEngineTests: XCTestCase {
    private typealias F = M3aFixtures
    private var demo: [LayoutEvent] { F.demo }
    private func id(_ title: String) -> String { F.demoId(title) }

    func testBandHeight() {
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 3, inkBottom: 0), 102)
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 1, inkBottom: 0), 60)
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 2, inkBottom: 0), 78)
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 0, inkBottom: 100), 112)
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 40, inkBottom: 0), 800)
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 0, inkBottom: 5000), 800)
        XCTAssertEqual(DayLayoutEngine.bandHeight(laneCount: 0, inkBottom: .infinity), 60)
    }

    func testGeometry() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.pageId, "d-2026-10-07")
        XCTAssertEqual(page.kind, .day)
        XCTAssertEqual(page.day, F.day(2026, 10, 7))
        XCTAssertTrue(page.isToday)
        XCTAssertEqual(page.size, CGSize(width: 1000, height: 2460))
        XCTAssertEqual(page.band, CGRect(x: 0, y: 0, width: 1000, height: 60))
        XCTAssertEqual(page.grid, CGRect(x: 0, y: 60, width: 1000, height: 2400))
        XCTAssertEqual(page.timeline, CGRect(x: 72, y: 60, width: 588, height: 2400))
        XCTAssertEqual(page.memo, CGRect(x: 660, y: 60, width: 340, height: 2400))
        XCTAssertEqual(page.cells.count, 2)
        XCTAssertEqual(page.cells[.allDayDay], CGRect(x: 0, y: 0, width: 1000, height: 60), "the band cell spans the full width")
        XCTAssertEqual(page.cells[.grid], CGRect(x: 0, y: 60, width: 1000, height: 2400))
        XCTAssertEqual(page.laneCount, 1)
        XCTAssertEqual(page.laneMetrics, LaneMetrics(lane: 22, step: 24, gap: 2, fontScale: 1))
        XCTAssertEqual(page.dateLabels.count, 1)
        XCTAssertEqual(page.dateLabels[0].frame, CGRect(x: 72, y: 0, width: 588, height: 0))
        XCTAssertTrue(page.dateLabels[0].isToday)
        XCTAssertEqual(page.dateLabels[0].tone, .normal)
        XCTAssertNil(page.dateLabels[0].holidayName)
        XCTAssertTrue(page.dateLabels[0].inMonth)
        XCTAssertEqual(page.nowLine, NowLine(y: 60 + 1000, x0: 72, x1: 660, minute: 600))
        XCTAssertEqual(page.minutesToY(600), 1060)
        XCTAssertEqual(page.minutesToY(1440), 2460)
    }

    func testAllDayChips() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.allDayBars.count, 1)
        XCTAssertEqual(page.allDayBars[0].frame, CGRect(x: 76, y: 2, width: 572, height: 22), "inside the timeline column")
        XCTAssertEqual(page.allDayBars[0].title, "締切")
        XCTAssertEqual(page.allDayBars[0].eventId, id("締切"))
        XCTAssertEqual(page.allDayBars[0].row, 0)
        XCTAssertEqual(page.allDayBars[0].lane, 0)
        XCTAssertFalse(page.allDayBars[0].continuesLeft)
        XCTAssertFalse(page.allDayBars[0].continuesRight)

        let busy = F.dayLayout(demo + [F.allDay("a", 7, 8, title: "a"), F.allDay("b", 1, 20, title: "b")])
        XCTAssertEqual(busy.laneCount, 3)
        XCTAssertEqual(busy.band.height, 102)
        XCTAssertEqual(busy.allDayBars.map(\.title), ["b", "a", "締切"], "earlier start first (b since 10/1), then title")
        XCTAssertEqual(busy.allDayBars.map(\.lane), [0, 1, 2], "lane = display order")
        XCTAssertEqual(busy.allDayBars.map(\.frame.minY), [2, 26, 50], "chips stack by 24")
        XCTAssertEqual(busy.allDayBars.map(\.frame.height), [22, 22, 22])
        XCTAssertTrue(busy.allDayBars[0].continuesLeft)
        XCTAssertTrue(busy.allDayBars[0].continuesRight)
        XCTAssertEqual(busy.cells[.grid]?.minY, 102)
        XCTAssertEqual(busy.size.height, 2502)
        XCTAssertEqual(busy.nowLine?.y, 102 + 1000)
    }

    func testTimedBoxes() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.timedBoxes.count, 3)
        let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
        let w2 = (570.0 - 3) / 2
        assertRect(boxes[id("打合せ")]?.frame, CGRect(x: 76, y: 60 + 1001, width: w2, height: 148), "column 0 of 2")
        assertRect(boxes[id("電話")]?.frame, CGRect(x: 76 + w2 + 3, y: 60 + 1051, width: w2, height: 48), "column 1 of 2")
        assertRect(boxes[id("歯科")]?.frame, CGRect(x: 76, y: 60 + 1401, width: 570, height: 98), "alone")
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
        assertRect(long.timedBoxes[0].frame, CGRect(x: 76, y: 61, width: 570, height: 2398))
        XCTAssertEqual(long.allDayBars.count, 0)
    }

    func testHitTesting() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.hit(at: CGPoint(x: 100, y: 60 + 1010)), .timedBox(id("打合せ")))
        XCTAssertEqual(page.hit(at: CGPoint(x: 400, y: 60 + 1060)), .timedBox(id("電話")))
        XCTAssertEqual(page.hit(at: CGPoint(x: 100, y: 10)), .allDayBar(id("締切")))
        XCTAssertNil(page.hit(at: CGPoint(x: 800, y: 10)), "the memo part of the band has no chip")
        XCTAssertNil(page.hit(at: CGPoint(x: 800, y: 1000)), "the memo area hits nothing")
        XCTAssertNil(page.hit(at: CGPoint(x: 30, y: 1000)), "the gutter hits nothing")
        XCTAssertNil(page.hit(at: CGPoint(x: 100, y: 60 + 100)))
        var overlapping = page
        overlapping.allDayBars.append(AllDayBar(eventId: "fake", frame: CGRect(x: 72, y: 60 + 1000, width: 588, height: 40), row: 0, lane: 0, continuesLeft: false, continuesRight: false, colorHex: "#000000", title: "x"))
        XCTAssertEqual(overlapping.hit(at: CGPoint(x: 100, y: 60 + 1010)), .timedBox(id("打合せ")), "a box wins over a bar")
    }

    func testCellsAndInkCells() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.cell(at: CGPoint(x: 900, y: 30)), .allDayDay)
        XCTAssertEqual(page.cell(at: CGPoint(x: 30, y: 30)), .allDayDay, "the band includes the gutter")
        XCTAssertEqual(page.cell(at: CGPoint(x: 900, y: 1000)), .grid, "the memo area is part of the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1000, y: 60)), .grid, "the right edge belongs to the grid")
        XCTAssertNil(page.cell(at: CGPoint(x: 1001, y: 60)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: 2460)))
        XCTAssertNil(page.cell(at: CGPoint(x: -1, y: 100)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: -0.1)))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 30)), .allDayDay)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 1000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 30, y: 1000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -10, y: -10)), .allDayDay)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 2000, y: 9000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: CGFloat.nan)), .grid)
        XCTAssertTrue(page.growsWithInk(.allDayDay))
        XCTAssertFalse(page.growsWithInk(.grid))
        XCTAssertFalse(page.growsWithInk(.memo))
        XCTAssertFalse(page.growsWithInk(.allDay(F.day(2026, 10, 7))), "the week key is not the day band")
    }

    func testBandsScrollDeltaAndInk() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.band(atY: 30), PageBand(raw: "allday"))
        XCTAssertEqual(page.band(atY: 60), PageBand(raw: "grid"))
        XCTAssertEqual(page.band(atY: 2459), PageBand(raw: "grid"))
        XCTAssertNil(page.band(atY: 2460))
        XCTAssertNil(page.band(atY: -1))
        XCTAssertEqual(page.bandTop(PageBand(raw: "allday")), 0)
        XCTAssertEqual(page.bandTop(PageBand(raw: "grid")), 60)
        XCTAssertNil(page.bandTop(PageBand(raw: "memo")))
        let busy = F.dayLayout(demo + [F.allDay("a", 7, 8, title: "a"), F.allDay("b", 1, 20, title: "b")])
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 500), 42)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: busy, topVisibleY: 30), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: busy, new: page, topVisibleY: 500), -42)
        XCTAssertFalse(page.sameGeometry(as: busy))
        XCTAssertTrue(page.sameGeometry(as: F.dayLayout(demo, now: F.october(7, 15))))
        XCTAssertFalse(page.sameGeometry(as: F.dayLayout(demo, focus: F.day(2026, 10, 8))))
        let inked = F.dayLayout(demo, ink: [.allDayDay: 200, .grid: 9000])
        XCTAssertEqual(inked.band.height, 212, "the band grows with its ink; grid ink is ignored")
        XCTAssertEqual(inked.size.height, 2612)
        XCTAssertEqual(inked.timeline.minY, 212)
        XCTAssertEqual(inked.memo.minY, 212)
        XCTAssertEqual(inked.timedBoxes.first { $0.eventId == id("打合せ") }?.frame.minY, 212 + 1001)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 100), 152)
    }

    func testOtherDays() {
        let tomorrow = F.dayLayout(demo, focus: F.day(2026, 10, 8))
        XCTAssertEqual(tomorrow.pageId, "d-2026-10-08")
        XCTAssertFalse(tomorrow.isToday)
        XCTAssertNil(tomorrow.nowLine)
        XCTAssertFalse(tomorrow.dateLabels[0].isToday)
        XCTAssertEqual(tomorrow.allDayBars.count, 0)
        XCTAssertEqual(tomorrow.timedBoxes.map(\.title), ["資料提出"])
        XCTAssertEqual(tomorrow.size.height, 2460)
        let holiday = F.dayLayout([], focus: F.day(2026, 10, 12))
        XCTAssertEqual(holiday.dateLabels[0].holidayName, "スポーツの日")
        XCTAssertEqual(holiday.dateLabels[0].tone, .sundayOrHoliday)
        let saturday = F.dayLayout([], focus: F.day(2026, 10, 10))
        XCTAssertEqual(saturday.dateLabels[0].tone, .saturday)
        let trip = F.dayLayout(demo, focus: F.day(2026, 10, 11))
        XCTAssertEqual(trip.allDayBars.map(\.title), ["家族旅行"])
        XCTAssertTrue(trip.allDayBars[0].continuesLeft)
        XCTAssertTrue(trip.allDayBars[0].continuesRight)
    }

    func testInitialScroll() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), 60 + 900, "today at 10:00 → 9:00 (100 lu per hour)")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.october(7, 0, 10), calendar: F.tokyo), 60, "clamped to 0:00")
        let tomorrow = F.dayLayout(demo, focus: F.day(2026, 10, 8))
        XCTAssertEqual(PageNavigation.initialScrollY(tomorrow, now: F.demoNow, calendar: F.tokyo), 60 + 700, "not today → 7:00")
        let busy = F.dayLayout(demo + [F.allDay("a", 7, 8), F.allDay("b", 7, 8)])
        XCTAssertEqual(PageNavigation.initialScrollY(busy, now: F.demoNow, calendar: F.tokyo), 102 + 900, "the band height is included")
    }
}
