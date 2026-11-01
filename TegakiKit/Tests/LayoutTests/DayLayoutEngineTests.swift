import XCTest
import Foundation
import CoreGraphics
import Layout

/// Day page geometry (M3A_CONTRACT §1.7, M4B_CONTRACT §2.3, DESIGN §2.2 / §2.5): 2026-10-07 with
/// the screenshot-mode demo events; "today" is 10/7 at 10:00. Since M4b the paper is the 24-hour
/// grid; the all-day band is `allDayBand` (drawn by the screen). Since 1.1 the free memo area
/// 「自由メモ」 (`extra`, at least 700) follows below 24:00 (M7A_CONTRACT §3.3).
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
        XCTAssertEqual(page.size, CGSize(width: 1000, height: 3100), "the 24-hour grid and the free memo area (1.1: 2400 + 700)")
        XCTAssertEqual(page.grid, CGRect(x: 0, y: 0, width: 1000, height: 2400))
        XCTAssertEqual(page.timeline, CGRect(x: 72, y: 0, width: 588, height: 2400))
        XCTAssertEqual(page.memo, CGRect(x: 660, y: 0, width: 340, height: 2400))
        XCTAssertEqual(page.cells.count, 2, "grid and extra (1.1)")
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
        XCTAssertEqual(busy.size.height, 3100, "the paper does not grow with the band")
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

    func testDayAtIsNil() {
        // M4c, M4C_CONTRACT §4.3 / D5: a double tap on the day page does nothing.
        let page = F.dayLayout(demo)
        XCTAssertNil(page.dayAt(point: CGPoint(x: 100, y: 1010)), "on a box")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 800, y: 1000)), "the memo area")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 30, y: 1000)), "the time gutter")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 0, y: 0)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: 500, y: 2399)))
        XCTAssertNil(page.dayAt(point: CGPoint(x: CGFloat.nan, y: 100)))
        XCTAssertNil(F.dayLayout([], focus: F.day(2026, 10, 8)).dayAt(point: CGPoint(x: 300, y: 300)), "another day")
        XCTAssertNil((page as any PageLayout).dayAt(point: CGPoint(x: 100, y: 1010)), "through any PageLayout")
        var rng = M3aFixtures.Rng(seed: 0x4D34_6302)
        for _ in 0..<20 {
            XCTAssertNil(page.dayAt(point: CGPoint(x: CGFloat(rng.int(1100)) - 50, y: CGFloat(rng.int(2500)) - 50)))
        }
    }

    func testCellsAndInkCells() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.cell(at: CGPoint(x: 900, y: 30)), .grid, "the memo area's top is the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 30, y: 30)), .grid, "the gutter's top is the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 900, y: 1000)), .grid, "the memo area is part of the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1000, y: 0)), .grid, "the top-right corner belongs to the grid")
        XCTAssertNil(page.cell(at: CGPoint(x: 1001, y: 60)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 100, y: 2400)), .extra, "24:00 is the free memo area (1.1)")
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: 3100)), "below the paper")
        XCTAssertNil(page.cell(at: CGPoint(x: -1, y: 100)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: -0.1)))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 30)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 900, y: 1000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 30, y: 1000)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -10, y: -10)), .grid, "negative y too")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 2000, y: 9000)), .extra, "below 24:00 → extra (1.1)")
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
        XCTAssertEqual(page.band(atY: 2400), .extra, "the free memo area's band (1.1)")
        XCTAssertNil(page.band(atY: 3100), "below the paper")
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
        XCTAssertEqual(inked.size.height, 3100, "grid ink does not grow the paper (the free memo area stays 700)")
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
        XCTAssertEqual(tomorrow.size.height, 3100)
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

    // MARK: The free memo area below 24:00 (1.1, M7A_CONTRACT §3.3)

    func testExtraCellAndBands() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.extra, CGRect(x: 0, y: 2400, width: 1000, height: 700), "at least 700 (M7A-9)")
        XCTAssertEqual(page.cells[.extra], page.extra)
        XCTAssertEqual(Set(page.cells.keys), [CellKey.grid, CellKey.extra])
        XCTAssertEqual(page.cell(at: CGPoint(x: 500, y: 2399.9)), .grid)
        XCTAssertEqual(page.cell(at: CGPoint(x: 500, y: 2400)), .extra)
        XCTAssertEqual(page.cell(at: CGPoint(x: 0, y: 3099.9)), .extra, "the bottom-left corner")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1000, y: 2500)), .extra, "the right edge")
        XCTAssertNil(page.cell(at: CGPoint(x: 500, y: 3100)), "below the paper")
        XCTAssertNil(page.cell(at: CGPoint(x: 1000.1, y: 2500)), "right of the paper")
        XCTAssertNil(page.cell(at: CGPoint(x: -0.1, y: 2500)), "left of the paper")
        XCTAssertNil(page.cell(at: CGPoint(x: 500, y: CGFloat.nan)))
        XCTAssertEqual(page.band(atY: 2399.9), .grid)
        XCTAssertEqual(page.band(atY: 2400), .extra)
        XCTAssertEqual(page.band(atY: 3099), .extra)
        XCTAssertNil(page.band(atY: 3100))
        XCTAssertEqual(page.bandTop(.grid), 0)
        XCTAssertEqual(page.bandTop(.extra), 2400, "the extra's top never moves")
        XCTAssertNil(page.bandTop(.memo))
        XCTAssertTrue(page.growsWithInk(.extra))
        XCTAssertFalse(page.growsWithInk(.grid))
        XCTAssertNil(page.hit(at: CGPoint(x: 300, y: 2500)), "the free memo area hits nothing")
        XCTAssertNil(page.dayAt(point: CGPoint(x: 300, y: 2500)), "a double tap still does nothing")
        XCTAssertFalse(CellKey.extra.raw.hasPrefix("allday"), "K-1: the name never starts with allday")
        XCTAssertEqual(CellKey.extra.raw, "extra")
        XCTAssertTrue(CellKey.extra.isExtra)
        XCTAssertFalse(CellKey.grid.isExtra)
        XCTAssertEqual(PageBand.extra.raw, "extra")
    }

    func testExtraGrowsWithInk() {
        let page = F.dayLayout(demo)
        let grown = F.dayLayout(demo, ink: [.extra: 800])
        XCTAssertEqual(grown.extra, CGRect(x: 0, y: 2400, width: 1000, height: 1500), "800 → 1,500 (PaperGrowth.tailHeight)")
        XCTAssertEqual(grown.size, CGSize(width: 1000, height: 3900))
        XCTAssertEqual(F.dayLayout(demo, ink: [.extra: 300]).extra.height, 700)
        XCTAssertEqual(F.dayLayout(demo, ink: [.extra: 301]).extra.height, 1100)
        XCTAssertEqual(F.dayLayout(demo, ink: [.extra: 5955]).extra.height, 6005, "b + 50 above 5,950")
        XCTAssertEqual(F.dayLayout(demo, ink: [.extra: .nan]).extra.height, 700)
        XCTAssertEqual(F.dayLayout(demo, ink: [.extra: -20]).extra.height, 700)
        XCTAssertEqual(F.dayLayout(demo, ink: [.grid: 9000, .allDayDay: 200, .memo: 3000]).extra.height, 700, "only .extra is read")
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: grown, topVisibleY: 2500), 0, "the extra's top does not move")
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: grown, topVisibleY: 500), 0)
        XCTAssertFalse(page.sameGeometry(as: grown), "the paper is longer")
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: page, new: grown), "only the extra's height changed")
        XCTAssertEqual(ZoomPolicy.overviewSize(grown), CGSize(width: 1000, height: 2400), "the overview stays the 24 hours (K-6)")
        XCTAssertEqual(grown.nowLine, page.nowLine)
        XCTAssertEqual(grown.timedBoxes, page.timedBoxes)
        XCTAssertEqual(PageNavigation.initialScrollY(grown, now: F.demoNow, calendar: F.tokyo), 900, "the start position is unchanged")
    }

    func testStartsBelowDay() {
        let page = F.dayLayout(demo)
        XCTAssertFalse(page.startsBelowDay(CGRect(x: 100, y: 2399.9, width: 200, height: 100)), "minY 2,399.9")
        XCTAssertTrue(page.startsBelowDay(CGRect(x: 100, y: 2400, width: 200, height: 100)), "minY 2,400")
        XCTAssertTrue(page.startsBelowDay(CGRect(x: 100, y: 2900, width: 0, height: 0)), "a tap below 24:00")
        XCTAssertFalse(page.startsBelowDay(CGRect(x: 100, y: 2500, width: 100, height: -300)), "a drag upward from extra: normalized minY 2,200")
        XCTAssertTrue(page.startsBelowDay(CGRect(x: 100, y: 2600, width: 100, height: -150)), "an upward drag that stays below 24:00")
        XCTAssertFalse(page.startsBelowDay(CGRect(x: 100, y: 1000, width: 100, height: 2000)), "a rect across 24:00")
        XCTAssertFalse(page.startsBelowDay(CGRect(x: 100, y: CGFloat.nan, width: 100, height: 100)), "NaN")
        XCTAssertFalse(page.startsBelowDay(CGRect(x: 100, y: 2500, width: CGFloat.infinity, height: 100)), "∞")
        XCTAssertFalse(page.startsBelowDay(.null))
        // eventRange(for:) is unchanged (0-4): below 24:00 it still snaps to 23:00–24:00.
        let below = page.eventRange(for: CGRect(x: 100, y: 2400, width: 200, height: 100), now: F.demoNow, calendar: F.tokyo)
        XCTAssertEqual(below, EventRange.timed(F.day(2026, 10, 7), startMinute: 1380, endMinute: 1440, calendar: F.tokyo))
        let justAbove = page.eventRange(for: CGRect(x: 100, y: 2399.9, width: 200, height: 100), now: F.demoNow, calendar: F.tokyo)
        XCTAssertEqual(justAbove, EventRange.timed(F.day(2026, 10, 7), startMinute: 1380, endMinute: 1440, calendar: F.tokyo), "a rect from 2,399.9 is a 23:00 event")
        XCTAssertEqual(page.eventRange(for: CGRect(x: 100, y: 2500, width: 100, height: -300), now: F.demoNow, calendar: F.tokyo), EventRange.timed(F.day(2026, 10, 7), startMinute: 1320, endMinute: 1440, calendar: F.tokyo), "an upward drag across 24:00")
    }

    func testInkCellBelow24IsExtra() {
        let page = F.dayLayout(demo)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: 2400)), .extra, "a centre at 24:00")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: 2399.99)), .grid, "just above 24:00 (a 23:00 stroke that reaches below stays grid)")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: 2900)), .extra)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: 20_000)), .extra, "far below the paper")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -50, y: 3000)), .extra, "beside the paper, below 24:00")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 1200, y: 100)), .grid, "beside the paper, above 24:00")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: -10)), .grid, "above the paper")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 500, y: CGFloat.nan)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: 2600)), .extra, "the x does not matter")
        var rng = M3aFixtures.Rng(seed: 0x0E47_7A11)
        for _ in 0..<50 {
            let p = CGPoint(x: CGFloat(rng.int(1400)) - 200, y: CGFloat(rng.int(4000)) - 200)
            XCTAssertEqual(page.inkCell(forCenter: p), p.y >= 2400 ? CellKey.extra : CellKey.grid, "\(p)")
        }
    }

    func testOldCellsKeepTheirRects() {
        // K-4: grid, timeline and the right memo column keep (0, 0)…2400 whatever the extra holds.
        for ink: [CellKey: CGFloat] in [[:], [.extra: 800], [.extra: 5990], [.extra: 6420]] {
            let page = F.dayLayout(demo, ink: ink)
            XCTAssertEqual(page.grid, CGRect(x: 0, y: 0, width: 1000, height: 2400), "\(ink)")
            XCTAssertEqual(page.cells[.grid], CGRect(x: 0, y: 0, width: 1000, height: 2400), "\(ink)")
            XCTAssertEqual(page.timeline, CGRect(x: 72, y: 0, width: 588, height: 2400), "\(ink)")
            XCTAssertEqual(page.memo, CGRect(x: 660, y: 0, width: 340, height: 2400), "\(ink)")
            XCTAssertEqual(page.extra.minY, 2400, "\(ink)")
            XCTAssertEqual(page.size.height, 2400 + page.extra.height, "\(ink)")
            XCTAssertEqual(page.minutesToY(1440), 2400)
        }
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
