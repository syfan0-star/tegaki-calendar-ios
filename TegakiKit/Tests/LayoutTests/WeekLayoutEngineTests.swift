import XCTest
import Foundation
import CoreGraphics
import Layout

/// Week page geometry (M3A_CONTRACT §1.6, M4B_CONTRACT §2.3, DESIGN §2.2 / §2.4): the week of
/// 2026-10-05 with the screenshot-mode demo events; "today" is Wednesday 10/7 at 10:00. Since M4b
/// the paper is the 24-hour grid alone; the all-day band is `allDayBand` (drawn by the screen).
final class WeekLayoutEngineTests: XCTestCase {
    private typealias F = M3aFixtures
    private let colW = PaperSpec.weekColumnWidth
    private var demo: [LayoutEvent] { F.demo }
    private func id(_ title: String) -> String { F.demoId(title) }

    func testEmptyWeek() {
        let page = F.weekLayout([])
        XCTAssertEqual(page.pageId, "w-2026-10-05")
        XCTAssertEqual(page.kind, .week)
        XCTAssertEqual(page.days, (5...11).map { F.day(2026, 10, $0) })
        XCTAssertEqual(page.size, CGSize(width: 1400, height: 1920), "the paper is the grid alone")
        XCTAssertEqual(page.grid, CGRect(x: 0, y: 0, width: 1400, height: 1920))
        XCTAssertEqual(page.cells.count, 1)
        XCTAssertNil(page.cells[.allDay(F.day(2026, 10, 5))], "no band cell on the paper")
        XCTAssertEqual(page.cells[.grid], CGRect(x: 0, y: 0, width: 1400, height: 1920))
        XCTAssertEqual(page.columnFrame(6).maxX, 1400, accuracy: 1e-9)
        XCTAssertEqual(page.columnFrame(0), CGRect(x: 64, y: 0, width: colW, height: 1920))
        XCTAssertNil(page.column(atX: 10))
        XCTAssertEqual(page.column(atX: 64), 0)
        XCTAssertEqual(page.column(atX: 1400), 6, "x == 1400 is the last column")
        XCTAssertNil(page.column(atX: 1401))
        XCTAssertNil(page.column(atX: .nan))
        XCTAssertEqual(page.column(atX: 64 + 2 * colW), 2, "a column boundary maps to its own column")
        XCTAssertEqual(page.allDayBars.count, 0, "always empty")
        XCTAssertEqual(page.allDayBand.laneCount, 0)
        XCTAssertEqual(page.allDayBand.bars.count, 0)
        XCTAssertEqual(page.allDayBand.todayColumn, 2)
        XCTAssertEqual(page.timedBoxes.count, 0)
        XCTAssertEqual(page.dateLabels.count, 7)
        XCTAssertTrue(page.dateLabels[2].isToday)
        XCTAssertEqual(page.dateLabels[2].frame, CGRect(x: 64 + 2 * colW, y: 0, width: colW, height: 0))
        XCTAssertEqual(page.dateLabels[5].tone, .saturday)
        XCTAssertEqual(page.dateLabels[6].tone, .sundayOrHoliday)
        XCTAssertEqual(page.dateLabels[0].tone, .normal)
        XCTAssertEqual(page.dateLabels.map(\.inMonth), Array(repeating: true, count: 7))
        XCTAssertEqual(page.dateLabels.map(\.tone), page.allDayBand.tones, "the band carries the labels' tones")
        XCTAssertEqual(page.todayColumn, 2)
        XCTAssertEqual(page.nowLine, NowLine(y: 800, x0: 64 + 2 * colW, x1: 64 + 3 * colW, minute: 600))
        XCTAssertEqual(page.minutesToY(600), 800)
        XCTAssertEqual(page.minutesToY(0), 0)
    }

    func testWeekWithoutToday() {
        let page = F.weekLayout([], focus: F.day(2026, 10, 12))
        XCTAssertEqual(page.pageId, "w-2026-10-12")
        XCTAssertEqual(page.dateLabels[0].holidayName, "スポーツの日")
        XCTAssertEqual(page.dateLabels[0].tone, .sundayOrHoliday)
        XCTAssertNil(page.nowLine)
        XCTAssertNil(page.todayColumn)
        XCTAssertNil(page.allDayBand.todayColumn)
        XCTAssertEqual(page.dateLabels.filter(\.isToday).count, 0)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), 560, "no today → 7:00")
        let sunday = F.weekLayout([], focus: F.day(2026, 10, 4))
        XCTAssertEqual(sunday.pageId, "w-2026-09-28", "a Sunday focus normalizes to its Monday")
        XCTAssertEqual(sunday.days.first, F.day(2026, 9, 28))
    }

    func testAllDayBand() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.allDayBars.count, 0, "the paper has no bars")
        let band = page.allDayBand
        XCTAssertEqual(band.kind, .week)
        XCTAssertEqual(band.days, page.days)
        XCTAssertEqual(band.laneCount, 1)
        XCTAssertEqual(band.todayColumn, 2)
        XCTAssertEqual(band.gutter, 64)
        XCTAssertEqual(band.paperWidth, 1400)
        XCTAssertEqual(band.columnWidth, colW)
        XCTAssertEqual(band.columnMinX.count, 7)
        XCTAssertEqual(band.bars.map(\.title), ["キャンプ", "締切", "家族旅行"])
        let bars = Dictionary(uniqueKeysWithValues: band.bars.map { ($0.title, $0) })
        XCTAssertEqual(bars["キャンプ"]?.continuesLeft, true, "Monday, open left end")
        XCTAssertEqual(bars["キャンプ"]?.continuesRight, false)
        XCTAssertEqual(bars["キャンプ"]?.minX ?? -1, 64, accuracy: 1e-9)
        XCTAssertEqual(bars["キャンプ"]?.maxX ?? -1, 64 + colW - 3, accuracy: 1e-9)
        XCTAssertEqual(bars["締切"]?.startCol, 2, "Wednesday")
        XCTAssertEqual(bars["締切"]?.endCol, 2)
        XCTAssertEqual(bars["締切"]?.minX ?? -1, 64 + 2 * colW + 3, accuracy: 1e-9)
        XCTAssertEqual(bars["締切"]?.maxX ?? -1, 64 + 3 * colW - 3, accuracy: 1e-9)
        XCTAssertEqual(bars["締切"]?.eventId, id("締切"))
        XCTAssertEqual(bars["締切"]?.colorHex, F.demoColors[2])
        XCTAssertEqual(bars["家族旅行"]?.startCol, 4, "Friday–Sunday, open right end")
        XCTAssertEqual(bars["家族旅行"]?.endCol, 6)
        XCTAssertEqual(bars["家族旅行"]?.continuesRight, true)
        XCTAssertEqual(bars["家族旅行"]?.continuesLeft, false)
        XCTAssertEqual(bars["家族旅行"]?.minX ?? -1, 64 + 4 * colW + 3, accuracy: 1e-9)
        XCTAssertEqual(bars["家族旅行"]?.maxX ?? -1, 1400, accuracy: 1e-9)
        XCTAssertEqual(band.bars.map(\.lane), [0, 0, 0])
        XCTAssertEqual(band.tones, [.normal, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday])
        XCTAssertEqual(band, AllDayBandEngine.week(monday: F.day(2026, 10, 5), events: demo, now: F.demoNow, calendar: F.tokyo), "the page carries the engine's band")

        // Two lanes: a second event over Wednesday. The paper does not change.
        let stacked = F.weekLayout(demo + [F.allDay("x", 6, 9, title: "重なる")])
        XCTAssertEqual(stacked.allDayBand.laneCount, 2)
        let stackedBars = Dictionary(uniqueKeysWithValues: stacked.allDayBand.bars.map { ($0.title, $0) })
        XCTAssertEqual(stackedBars["重なる"]?.lane, 0, "the longer span takes lane 0")
        XCTAssertEqual(stackedBars["締切"]?.lane, 1)
        XCTAssertEqual(stacked.size.height, 1920)
        XCTAssertEqual(stacked.cells[.grid]?.minY, 0)
        XCTAssertTrue(stacked.sameGeometry(as: page), "the band does not change the paper's geometry")

        // 40 lanes: no thinning, no cap.
        var pile: [LayoutEvent] = []
        for i in 0..<40 { pile.append(F.allDay("pile\(i)", 5, 6, title: "p\(i)")) }
        let piled = F.weekLayout(pile)
        XCTAssertEqual(piled.allDayBand.laneCount, 40)
        XCTAssertEqual(piled.allDayBand.bars.count, 40)
        XCTAssertEqual(piled.allDayBand.bars.last?.lane, 39)
        XCTAssertEqual(piled.size.height, 1920)
        XCTAssertEqual(piled.allDayBars.count, 0)
    }

    func testTimedBoxes() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.timedBoxes.count, 6)
        let boxes = Dictionary(uniqueKeysWithValues: page.timedBoxes.map { ($0.eventId, $0) })
        let colX2 = 64 + 2 * colW
        let inner = colW - 8
        let w2 = (inner - 2) / 2
        assertRect(boxes[id("打合せ")]?.frame, CGRect(x: colX2 + 2, y: 801, width: w2, height: 118), "column 0 of 2 (y from 0:00)")
        assertRect(boxes[id("電話")]?.frame, CGRect(x: colX2 + 2 + w2 + 2, y: 841, width: w2, height: 38), "column 1 of 2")
        assertRect(boxes[id("歯科")]?.frame, CGRect(x: colX2 + 2, y: 1121, width: inner, height: 78), "alone")
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
        XCTAssertEqual(page.hit(at: CGPoint(x: colX2 + 10, y: 810)), .timedBox(id("打合せ")))
        XCTAssertEqual(page.hit(at: CGPoint(x: colX2 + 2 + w2 + 10, y: 850)), .timedBox(id("電話")))
        XCTAssertNil(page.hit(at: CGPoint(x: colX2 + 10, y: 10)), "the top of the paper is 0:00, not a bar")
        XCTAssertNil(page.hit(at: CGPoint(x: 70, y: 10)))
        XCTAssertNil(page.hit(at: CGPoint(x: colX2 + 10, y: 100)))
        XCTAssertNil(page.hit(at: CGPoint(x: 10, y: 10)))
        XCTAssertNil(page.hit(at: CGPoint(x: CGFloat.nan, y: 10)))
        var withBar = page
        withBar.allDayBars.append(AllDayBar(eventId: "fake-bar", frame: CGRect(x: colX2, y: 800, width: colW, height: 40), row: 0, lane: 0, continuesLeft: false, continuesRight: false, colorHex: "#000000", title: "x"))
        XCTAssertEqual(withBar.hit(at: CGPoint(x: colX2 + 10, y: 810)), .timedBox(id("打合せ")), "a box is hit")
        XCTAssertNil(withBar.hit(at: CGPoint(x: colX2 + 2 + w2 + 10, y: 835)), "a bar on the paper is never hit (the band is the screen's)")
    }

    func testCellsAndInkCells() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.cell(at: CGPoint(x: 10, y: 10)), .grid, "the gutter is part of the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1400, y: 100)), .grid)
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: 1920)))
        XCTAssertEqual(page.cell(at: CGPoint(x: 100, y: 10)), .grid, "the top of the paper is the grid")
        XCTAssertEqual(page.cell(at: CGPoint(x: 1400, y: 0)), .grid)
        XCTAssertNil(page.cell(at: CGPoint(x: -1, y: 100)))
        XCTAssertNil(page.cell(at: CGPoint(x: 100, y: -1)))
        XCTAssertNil(page.cell(at: CGPoint(x: CGFloat.nan, y: 100)))
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 10)), .grid, "gutter → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: -5, y: -5)), .grid, "above-left → grid (negative y too)")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 1500, y: 30)), .grid, "right of the paper → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 10, y: 500)), .grid, "time gutter → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 700, y: 5000)), .grid, "below the paper → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: 300, y: -40)), .grid, "above the paper → grid")
        XCTAssertEqual(page.inkCell(forCenter: CGPoint(x: CGFloat.nan, y: CGFloat.nan)), .grid, "NaN → grid")
        XCTAssertFalse(page.growsWithInk(.grid))
        XCTAssertFalse(page.growsWithInk(.allDay(F.day(2026, 10, 5))), "the former band cell")
        XCTAssertFalse(page.growsWithInk(.allDay(F.day(2026, 10, 12))))
        XCTAssertFalse(page.growsWithInk(.memo))
        XCTAssertFalse(page.growsWithInk(.allDayDay))
    }

    func testBandsAndGeometry() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(page.band(atY: 10), PageBand(raw: "grid"))
        XCTAssertEqual(page.band(atY: 0), PageBand(raw: "grid"))
        XCTAssertEqual(page.band(atY: 1919.9), PageBand(raw: "grid"))
        XCTAssertNil(page.band(atY: 1920))
        XCTAssertNil(page.band(atY: -1))
        XCTAssertNil(page.band(atY: .nan))
        XCTAssertEqual(page.bandTop(PageBand(raw: "grid")), 0)
        XCTAssertNil(page.bandTop(PageBand(raw: "allday")), "the paper has no band")
        XCTAssertNil(page.bandTop(PageBand(raw: "memo")))
        XCTAssertNil(page.bandTop(PageBand(raw: "row:0")))
        let inked = F.weekLayout(demo, ink: [.allDay(F.day(2026, 10, 6)): 68, .grid: 5000])
        XCTAssertEqual(inked.size.height, 1920, "ink does not grow the paper")
        XCTAssertEqual(inked.cells[.grid]?.minY, 0)
        XCTAssertEqual(inked, page, "ink bottoms are not read")
        XCTAssertEqual(inked.timedBoxes.first { $0.eventId == id("打合せ") }?.frame.minY, 801)
        XCTAssertEqual(inked.nowLine?.y, 800)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 100), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 10), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: inked, new: page, topVisibleY: 500), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: -5), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: inked, topVisibleY: 5000), 0)
        XCTAssertEqual(PageScroll.scrollDelta(old: page, new: F.weekLayout(demo, focus: F.day(2026, 10, 14)), topVisibleY: 700), 0)
        XCTAssertTrue(page.sameGeometry(as: inked), "ink does not change the geometry")
        XCTAssertTrue(page.sameGeometry(as: F.weekLayout(demo, now: F.october(7, 11))))
        XCTAssertFalse(page.sameGeometry(as: F.weekLayout(demo, focus: F.day(2026, 10, 14))))
        XCTAssertEqual(page, F.weekLayout(demo))
        XCTAssertNotEqual(page, F.weekLayout(demo, now: F.october(7, 11)), "the now line differs")
    }

    func testInitialScroll() {
        let page = F.weekLayout(demo)
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.demoNow, calendar: F.tokyo), 720, "today at 10:00 → 9:00")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.october(7, 0, 30), calendar: F.tokyo), 0, "early morning clamps to 0:00")
        XCTAssertEqual(PageNavigation.initialScrollY(page, now: F.october(7, 23, 59), calendar: F.tokyo), 22 * 80 + CGFloat(59) * 80 / 60, accuracy: 1e-9)
        let inked = F.weekLayout(demo, ink: [.allDay(F.day(2026, 10, 6)): 68])
        XCTAssertEqual(PageNavigation.initialScrollY(inked, now: F.demoNow, calendar: F.tokyo), 720, "ink does not move the start")
    }
}
