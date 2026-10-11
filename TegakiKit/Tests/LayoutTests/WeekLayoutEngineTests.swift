import XCTest
import Foundation
import CoreGraphics
import Layout

/// Week page geometry (M3A_CONTRACT §1.6, DESIGN §2.2 / §2.4): the week of 2026-10-05 with the
/// screenshot-mode demo events; "today" is Wednesday 10/7 at 10:00.
final class WeekLayoutEngineTests: XCTestCase {
    private typealias F = M3aFixtures
    private let colW = PaperSpec.weekColumnWidth
    private var demo: [LayoutEvent] { F.demo }
    private func id(_ title: String) -> String { F.demoId(title) }

    func testBandHeight() {
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: 1, inkBottom: 0), 60)
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: 2, inkBottom: 0), 80)
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: 0, inkBottom: 100), 112)
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: 40, inkBottom: 0), 800)
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: 0, inkBottom: 5000), 800)
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: 0, inkBottom: .nan), 60)
        XCTAssertEqual(WeekLayoutEngine.bandHeight(laneCount: -3, inkBottom: -50), 60)
    }

    func testEmptyWeek() {
        let page = F.weekLayout([])
        XCTAssertEqual(page.pageId, "w-2026-10-05")
        XCTAssertEqual(page.kind, .week)
        XCTAssertEqual(page.days, (5...11).map { F.day(2026, 10, $0) })
        XCTAssertEqual(page.size, CGSize(width: 1400, height: 1980))
        XCTAssertEqual(page.band, CGRect(x: 0, y: 0, width: 1400, height: 60))
        XCTAssertEqual(page.grid, CGRect(x: 0, y: 60, width: 1400, height: 1920))
        XCTAssertEqual(page.cells.count, 8)
        XCTAssertEqual(page.cells[.allDay(F.day(2026, 10, 5))], CGRect(x: 64, y: 0, width: colW, height: 60))
        XCTAssertEqual(page.cells[.allDay(F.day(2026, 10, 11))], CGRect(x: 64 + 6 * colW, y: 0, width: colW, height: 60))
        XCTAssertEqual(page.cells[.grid], CGRect(x: 0, y: 60, width: 1400, height: 1920))
        XCTAssertEqual(page.columnFrame(6).maxX, 1400, accuracy: 1e-9)
        XCTAssertEqual(page.columnFrame(0), CGRect(x: 64, y: 60, width: colW, height: 1920))
        XCTAssertNil(page.column(atX: 10))
        XCTAssertEqual(page.column(atX: 64), 0)
        XCTAssertEqual(page.column(atX: 1400), 6, "x == 1400 is the last column")
        XCTAssertNil(page.column(atX: 1401))
        XCTAssertNil(page.column(atX: .nan))
        XCTAssertEqual(page.column(atX: 64 + 2 * colW), 2, "a column boundary maps to its own column")
        XCTAssertEqual(page.laneCount, 0)
        XCTAssertEqual(page.laneMetrics, LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1))
        XCTAssertEqual(page.allDayBars.count, 0)
        XCTAssertEqual(page.timedBoxes.count, 0)
        XCTAssertEqual(page.dateLabels.count, 7)
        XCTAssertTrue(page.dateLabels[2].isToday)
        XCTAssertEqual(page.dateLabels[2].frame, CGRect(x: 64 + 2 * colW, y: 0, width: colW, height: 0))
        XCTAssertEqual(page.dateLabels[5].tone, .saturday)
        XCTAssertEqual(page.dateLabels[6].tone, .sundayOrHoliday)
        XCTAssertEqual(page.dateLabels[0].tone, .normal)
        XCTAssertEqual(page.dateLabels.map(\.inMonth), Array(repeating: true, count: 7))
        XCTAssertEqual(page.todayColumn, 2)
        XCTAssertEqual(page.nowLine, NowLine(y: 60 + 800, x0: 64 + 2 * colW, x1: 64 + 3 * colW, minute: 600))
        XCTAssertEqual(page.minutesToY(600), 860)
        XCTAssertEqual(page.minutesToY(0), 60)
    }

    func testWeekWithoutToday() {
        let page = F.weekLayout([], focus: F.day(2026, 10, 12))
        XCTAssertEqual(page.pageId, "w-2026-10-12")
        XCTAssertEqual(page.dateLabels[0].holidayName, "スポーツの日")
        XCTAssertEqual(page.dateLabels[0].tone, .sundayOrHoliday)
        XCTAssertNil(page.nowLine)
        XCTAssertNil(page.todayColumn)
        XCTAssertEqual(page.dateLabels.filter(\.isToday).count, 0)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), 60 + 560, "no today → 7:00")
        let sunday = F.weekLayout([], focus: F.day(2026, 10, 4))
        XCTAssertEqual(sunday.pageId, "w-2026-09-28", "a Sunday focus normalizes to its Monday")
        XCTAssertEqual(sunday.days.first, F.day(2026, 9, 28))
    }

    func testAllDayBars() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.laneCount, 1)
        XCTAssertEqual(page.band.height, 60)
        XCTAssertEqual(page.allDayBars.count, 3)
        let bars = Dictionary(uniqueKeysWithValues: page.allDayBars.map { ($0.title, $0) })
        assertRect(bars["キャンプ"]?.frame, CGRect(x: 64, y: 3, width: colW - 3, height: 22), "Monday, open left end")
        XCTAssertEqual(bars["キャンプ"]?.continuesLeft, true)
        XCTAssertEqual(bars["キャンプ"]?.continuesRight, false)
        assertRect(bars["締切"]?.frame, CGRect(x: 64 + 2 * colW + 3, y: 3, width: colW - 6, height: 22), "Wednesday")
        XCTAssertEqual(bars["締切"]?.continuesLeft, false)
        XCTAssertEqual(bars["締切"]?.continuesRight, false)
        assertRect(bars["家族旅行"]?.frame, CGRect(x: 64 + 4 * colW + 3, y: 3, width: 3 * colW - 3, height: 22), "Friday–Sunday, open right end")
        XCTAssertEqual(bars["家族旅行"]?.continuesRight, true)
        XCTAssertEqual(bars["家族旅行"]?.continuesLeft, false)
        XCTAssertEqual(page.allDayBars.map(\.lane), [0, 0, 0])
        XCTAssertEqual(page.allDayBars.map(\.row), [0, 0, 0])
        XCTAssertEqual(bars["締切"]?.eventId, id("締切"))
        XCTAssertEqual(bars["締切"]?.colorHex, F.demoColors[2])

        // Two lanes: a second event over Wednesday.
        let stacked = F.weekLayout(demo + [F.allDay("x", 6, 9, title: "重なる")])
        XCTAssertEqual(stacked.laneCount, 2)
        XCTAssertEqual(stacked.band.height, 80)
        XCTAssertEqual(stacked.cells[.grid]?.minY, 80)
        let stackedBars = Dictionary(uniqueKeysWithValues: stacked.allDayBars.map { ($0.title, $0) })
        XCTAssertEqual(stackedBars["重なる"]?.lane, 0, "the longer span takes lane 0")
        XCTAssertEqual(stackedBars["締切"]?.lane, 1)
        XCTAssertEqual(stackedBars["締切"]?.frame.minY, 3 + 25)
    }

    func testTimedBoxes() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.timedBoxes.count, 6)
        let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
        let colX2 = 64 + 2 * colW
        let inner = colW - 8
        let w2 = (inner - 2) / 2
        assertRect(boxes[id("打合せ")]?.frame, CGRect(x: colX2 + 2, y: 60 + 801, width: w2, height: 118), "column 0 of 2")
        assertRect(boxes[id("電話")]?.frame, CGRect(x: colX2 + 2 + w2 + 2, y: 60 + 841, width: w2, height: 38), "column 1 of 2")
        assertRect(boxes[id("歯科")]?.frame, CGRect(x: colX2 + 2, y: 60 + 1121, width: inner, height: 78), "alone")
        XCTAssertEqual(boxes[id("打合せ")]?.column, 0)
        XCTAssertEqual(boxes[id("打合せ")]?.columns, 2)
        XCTAssertEqual(boxes[id("電話")]?.column, 1)
        XCTAssertEqual(boxes[id("電話")]?.columns, 2)
        XCTAssertEqual(boxes[id("歯科")]?.columns, 1)
        XCTAssertEqual(boxes[id("打合せ")]?.timeText, "10:00〜11:30")
        XCTAssertEqual(boxes[id("打合せ")]?.startText, "10:00")
        XCTAssertEqual(boxes[id("打合せ")]?.title, "打合せ")
        XCTAssertEqual(boxes[id("打合せ")]?.day, F.day(2026, 10, 7))
        XCTAssertEqual(boxes[id("打合せ")]?.startMinute, 600)
        XCTAssertEqual(boxes[id("打合せ")]?.endMinute, 690)
        XCTAssertEqual(boxes[id("打合せ")]?.colorHex, F.demoColors[0])
        XCTAssertEqual(page.timedBoxes.filter(\.isPast).map(\.day), [F.day(2026, 10, 6)], "only Tuesday's 週次定例 is past at Wednesday 10:00")
        XCTAssertEqual(boxes[id("打合せ")]?.isPast, false)
        XCTAssertEqual(F.weekLayout(demo, now: F.october(11, 23)).timedBoxes.filter(\.isPast).count, 6, "everything is past on Sunday night")
        // An event ending exactly now is past.
        XCTAssertEqual(F.weekLayout(demo, now: F.october(7, 11, 30)).timedBoxes.first { $0.eventId == id("打合せ") }?.isPast, true)
    }

    func testHitTesting() {
        let page = F.weekLayout(demo)
        let colX2 = 64 + 2 * colW
        let w2 = (colW - 8 - 2) / 2
        XCTAssertEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 60 + 810)), .timedBox(id("打合せ")))
        XCTAssertEqual(page.hit(at: CGPoint(x: colX2 + 2 + w2 + 10, y: 60 + 850)), .timedBox(id("電話")))
        XCTAssertEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 10)), .allDayBar(id("締切")))
        XCTAssertEqual(page.hit(at: CGPoint(x: 70, y: 10)), .allDayBar(id("キャンプ")))
        XCTAssertNil(page.hit(at: CGPoint(x: colX2 + 10, y: 60 + 100)))
        XCTAssertNil(page.hit(at: CGPoint(x: 10, y: 10)))
        XCTAssertNil(page.hit(at: CGPoint(x: colX2 + 10, y: 40)), "below the bar inside the band")
        XCTAssertNil(page.hit(at: CGPoint(x: CGFloat.nan, y: 10)))
        var overlapping = page
        overlapping.allDayBars.append(AllDayBar(eventId: "fake-bar", frame: CGRect(x: colX2, y: 60 + 800, width: colW, height: 40), row: 0, lane: 0, continuesLeft: false, continuesRight: false, colorHex: "#000000", title: "x"))
        XCTAssertEqual(overlapping.hit(at: CGPoint(x: colX2 + 10, y: 60 + 810)), .timedBox(id("打合せ")), "a box wins over a bar at the same point")
        // Right of 打合せ's column (column 0 of 2) and above 電話 (which starts at 10:30 = grid y 840): only the bar is there.
        XCTAssertEqual(overlapping.hit(at: CGPoint(x: colX2 + 2 + w2 + 10, y: 60 + 835)), .allDayBar("fake-bar"), "the bar is hit beside the box")
    }

    func testCellsAndInkCells() {
        let page = F.weekLayout(demo)
        XCTAssertNil(page.cell(at: CGPoint(x: 10, y: 10)), "the band's gutter belongs to no cell")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1400, y: 100)), .grid)
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: 1980)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 100, y: 10)), .allDay(F.day(2026, 10, 5)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 1400, y: 10)), .allDay(F.day(2026, 10, 11)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 10, y: 60)), .grid, "the gutter is part of the grid")
        XCTAssertNil(page.cell(at: CGPoint(x: -1, y: 100)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: -1)))
        XCTAssertNil(page.cell(at: CGPoint(x: CGFloat.nan, y: 100)))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 10)), .allDay(F.day(2026, 10, 5)), "gutter → Monday's band")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -5, y: -5)), .allDay(F.day(2026, 10, 5)), "above-left → Monday's band")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 1500, y: 30)), .allDay(F.day(2026, 10, 11)), "right of the band → Sunday's band")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 500)), .grid, "time gutter → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 700, y: 5000)), .grid, "below the paper → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 300, y: 59.9)), .allDay(F.day(2026, 10, 6)))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 300, y: 60)), .grid)
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: CGFloat.nan)), .grid, "NaN → grid")
        XCTAssertTrue(page.growsWithInk(.allDay(F.day(2026, 10, 5))))
        XCTAssertTrue(page.growsWithInk(.allDay(F.day(2026, 10, 11))))
        XCTAssertFalse(page.growsWithInk(.grid))
        XCTAssertFalse(page.growsWithInk(.allDay(F.day(2026, 10, 12))), "a day outside the week")
        XCTAssertFalse(page.growsWithInk(.memo))
        XCTAssertFalse(page.growsWithInk(.allDayDay))
    }

    func testBandsAndScrollDelta() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.band(atY: 10), PageBand(raw: "allday"))
        XCTAssertEqual(page.band(atY: 60), PageBand(raw: "grid"))
        XCTAssertEqual(page.band(atY: 1979.9), PageBand(raw: "grid"))
        XCTAssertNil(page.band(atY: 1980))
        XCTAssertNil(page.band(atY: -1))
        XCTAssertEqual(page.bandTop(PageBand(raw: "allday")), 0)
        XCTAssertEqual(page.bandTop(PageBand(raw: "grid")), 60)
        XCTAssertNil(page.bandTop(PageBand(raw: "memo")))
        XCTAssertNil(page.bandTop(PageBand(raw: "row:0")))
        let inked = F.weekLayout(demo, ink: [.allDay(F.day(2026, 10, 6)): 68, .grid: 5000])
        XCTAssertEqual(inked.band.height, 80, "ink 68 + 12; grid ink is ignored")
        XCTAssertEqual(inked.size.height, 2000)
        XCTAssertEqual(inked.cells[.grid]?.minY, 80)
        XCTAssertEqual(inked.cells[.allDay(F.day(2026, 10, 6))]?.height, 80)
        XCTAssertEqual(inked.timedBoxes.first { $0.eventId == id("打合せ") }?.frame.minY, 80 + 801, "boxes move with the grid")
        XCTAssertEqual(inked.nowLine?.y, 80 + 800)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 100), 20)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 10), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: inked, new: page, topVisibleY: 500), -20)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: -5), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 5000), 0)
        XCTAssertFalse(page.sameGeometry(as: inked))
        XCTAssertTrue(page.sameGeometry(as: F.weekLayout(demo, now: F.october(7, 11))))
        XCTAssertEqual(page, F.weekLayout(demo))
        XCTAssertNotEqual(page, F.weekLayout(demo, now: F.october(7, 11)), "the now line differs")
    }

    func testThinningAtTheCap() {
        var pile: [LayoutEvent] = []
        for i in 0..<40 { pile.append(F.allDay("pile\(i)", 5, 6, title: "p\(i)")) }
        let page = F.weekLayout(pile)
        XCTAssertEqual(page.laneCount, 40)
        XCTAssertEqual(page.band.height, 800)
        XCTAssertEqual(page.laneMetrics.step, 19.25, accuracy: 1e-9)
        XCTAssertEqual(page.laneMetrics.lane, 16.25, accuracy: 1e-9)
        XCTAssertEqual(page.laneMetrics.fontScale, 16.25 / 22, accuracy: 1e-9)
        XCTAssertEqual(page.allDayBars.count, 40)
        XCTAssertEqual(page.allDayBars.last?.frame.minY ?? 0, 3 + 39 * 19.25, accuracy: 1e-9)
        XCTAssertEqual(page.allDayBars.last?.frame.maxY ?? 0, 3 + 39 * 19.25 + 16.25, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(page.allDayBars.last?.frame.maxY ?? 0, 800 - 30)
        // 30 lanes fit without thinning.
        let thirty = F.weekLayout(Array(pile.prefix(30)))
        XCTAssertEqual(thirty.band.height, 780)
        XCTAssertEqual(thirty.laneMetrics, LaneMetrics(lane: 22, step: 25, gap: 3, fontScale: 1))
    }

    func testInitialScroll() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), 60 + 720, "today at 10:00 → 9:00")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.october(7, 0, 30), calendar: F.tokyo), 60, "early morning clamps to 0:00")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.october(7, 23, 59), calendar: F.tokyo), 60 + 22 * 80 + CGFloat(59) * 80 / 60, accuracy: 1e-9)
        let inked = F.weekLayout(demo, ink: [.allDay(F.day(2026, 10, 6)): 68])
        XCTAssertEqual(PageNavigation.initialScrollY(inked, now: F.demoNow, calendar: F.tokyo), 80 + 720, "the band height is included")
    }
}
