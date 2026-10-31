import XCTest
import Foundation
import CoreGraphics
import Layout

/// The last cell that grows downward (1.1, M7A_CONTRACT D3, §3.1, §3.4, §3.6): the month's memo area
/// and the day's free memo area below 24:00.
final class PaperGrowthTests: XCTestCase {
    private typealias F = M3aFixtures

    func testTailHeightSteps() {
        // §3.1. 5,600 → 6,000 follows the formula (5,500 → 5,900 is the last full step; see docs/M7A.md 「## K」).
        let table: [(CGFloat, CGFloat)] = [(0, 700), (300, 700), (301, 1100), (700, 1100), (701, 1500), (1100, 1500),
                                           (5500, 5900), (5600, 6000), (5601, 6000), (5950, 6000), (5990, 6040), (6420, 6470)]
        for (b, h) in table {
            XCTAssertEqual(PaperGrowth.tailHeight(inkBottom: b), h, "b \(b)")
        }
        for bad: CGFloat in [.nan, .infinity, -.infinity, -50, -0.0] {
            XCTAssertEqual(PaperGrowth.tailHeight(inkBottom: bad), 700, "b \(bad) counts as 0")
        }
        XCTAssertEqual(PaperGrowth.tailHeight(inkBottom: 64.5), 700, "the screenshot month's dot keeps 700 (0-1)")
        XCTAssertEqual(PaperSpec.growStep, 400)
        XCTAssertEqual(PaperSpec.growMax, 6000)
        XCTAssertEqual(PaperSpec.dayExtraMin, 700)
        XCTAssertEqual(PaperSpec.dayExtraMin, PaperSpec.memoMin)
        XCTAssertTrue(PaperGrowth.isTail(.memo))
        XCTAssertTrue(PaperGrowth.isTail(.extra))
        XCTAssertFalse(PaperGrowth.isTail(.grid))
        XCTAssertFalse(PaperGrowth.isTail(.day(F.day(2026, 10, 7))))
        XCTAssertFalse(PaperGrowth.isTail(CellKey(raw: "10-07")))
    }

    func testTailHeightKeepsTheOneZeroRule() {
        var previous: CGFloat = 0
        var b: CGFloat = 0
        while b <= 7000 {
            let h = PaperGrowth.tailHeight(inkBottom: b)
            XCTAssertGreaterThanOrEqual(h, b + 50, "b \(b): never below the 1.0 rule b + 50")
            XCTAssertGreaterThanOrEqual(h, 700, "b \(b)")
            if b <= 5600 {
                XCTAssertGreaterThanOrEqual(h - b, 400, "b \(b): at least 400 lu of blank paper")
                XCTAssertLessThanOrEqual(h - b, 800, "b \(b): at most 800 lu of blank paper")
            }
            if h <= 6000 && h != b + 50 && h != 6000 {
                XCTAssertEqual((h - 700).truncatingRemainder(dividingBy: 400), 0, "b \(b): 700 + 400k")
            }
            XCTAssertGreaterThanOrEqual(h, previous, "b \(b): never shrinks as b grows")
            previous = h
            b += 7.3
        }
    }

    func testNeedsMoreRoom() {
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 700, inkBottom: 300))
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 700, inkBottom: 300.5))
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 1100, inkBottom: 700))
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 1100, inkBottom: 750), "0-2: 1.0's b + 50 rule would not relayout here")
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 1500, inkBottom: 750), "a taller cell does not ask (it shrinks on the next relayout)")
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: .extra, cellHeight: 700, inkBottom: 301))
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .extra, cellHeight: 700, inkBottom: 250))
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 6000, inkBottom: 5950))
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 6000, inkBottom: 5951), "b + 50 above the cap")
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 1099.9995, inkBottom: 700), "within 0.001")
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 1099.998, inkBottom: 700))
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: 700, inkBottom: .nan))
        // Any other cell: the rule of the rows (b + 12).
        let monthDay = CellKey.day(F.day(2026, 10, 7))
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: monthDay, cellHeight: 175, inkBottom: 163))
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: monthDay, cellHeight: 175, inkBottom: 163.5))
        XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: CellKey(raw: "10-07"), cellHeight: 60, inkBottom: 48.0005))
        XCTAssertTrue(PaperGrowth.needsMoreRoom(cell: CellKey(raw: "10-07"), cellHeight: 60, inkBottom: 49))
        // The engines agree: after a relayout with the new bottom, the cell has room.
        for b: CGFloat in [0, 299, 301, 750, 2222, 5600, 5951, 6420] {
            let month = F.monthLayout([], ink: [.memo: b])
            XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .memo, cellHeight: month.memo.height, inkBottom: b), "month memo \(b)")
            let day = F.dayLayout(F.demo, ink: [.extra: b])
            XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: .extra, cellHeight: day.extra.height, inkBottom: b), "day extra \(b)")
        }
    }

    func testReachesCap() {
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: 5600))
        XCTAssertTrue(PaperGrowth.reachesCap(inkBottom: 5601))
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: 5500))
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: 0))
        XCTAssertTrue(PaperGrowth.reachesCap(inkBottom: 6420))
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: .nan))
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: .infinity))
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: -1))
        XCTAssertFalse(PaperGrowth.reachesCap(inkBottom: -6000))
        var b: CGFloat = 0
        while b <= 7000 {
            XCTAssertEqual(PaperGrowth.reachesCap(inkBottom: b), PaperGrowth.tailHeight(inkBottom: b) - b < PaperSpec.growStep, "b \(b): less than 400 lu of blank below")
            b += 7.3
        }
    }

    func testDropReasons() {
        let month = F.monthLayout([]) // 1400 × 1750, memo from 1050
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 700, y: 500), in: month), "inside")
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 0, y: 0), in: month))
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 1400, y: 1750), in: month), "the edges belong to the paper")
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: -1, y: 500), in: month), .outsidePaper)
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 1401, y: 500), in: month), .outsidePaper)
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: -1), in: month), .outsidePaper)
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1751), in: month), .outsidePaper, "below the paper, above the cap")
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1050 + 6000.5), in: month), .beyondCap, "beyondCap first")
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: -1, y: 9000), in: month), .outsidePaper, "beside the paper is never beyondCap")
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: CGFloat.nan, y: 500), in: month), .outsidePaper)
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: CGFloat.infinity), in: month), .outsidePaper)
        // A paper longer than the cap (deep strokes from a 1.0 device or the web version).
        let deep = F.monthLayout([], ink: [.memo: 6420])
        XCTAssertEqual(deep.size.height, 1050 + 6470)
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 1050 + 6100), in: deep), .beyondCap, "inside the paper but below the cap (0-5)")
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 700, y: 1050 + 5999), in: deep))
        // The day: the cap is 24:00 + 6,000.
        let day = F.dayLayout(F.demo)
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 500, y: 3000), in: day))
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 500, y: 3101), in: day), .outsidePaper)
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 500, y: 8400.5), in: day), .beyondCap)
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 500, y: 8399), in: F.dayLayout(F.demo, ink: [.extra: 6420])), "the 1.0 floor keeps the paper long")
        // Week and year have no last cell.
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 9000), in: F.weekLayout(F.demo)), .outsidePaper)
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 700, y: 1000), in: F.weekLayout(F.demo)))
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: 9000), in: F.yearLayout([])), .outsidePaper)
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 700, y: 1000), in: F.yearLayout([])))
    }

    func testOnlyTailHeightChanged() {
        let plain = F.monthLayout([])
        let grown = F.monthLayout([], ink: [.memo: 500])
        XCTAssertEqual(PaperGrowth.tail(of: plain)?.key, .memo)
        XCTAssertEqual(PaperGrowth.tail(of: plain)?.rect, plain.memo)
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: plain, new: grown), "the month's memo only")
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: grown, new: plain), "it shrinks back")
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: plain, new: plain), "nothing changed")
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: plain, new: F.monthLayout([], ink: [.day(F.day(2026, 10, 14)): 300])), "a row grew (the memo area moved)")
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: plain, new: F.monthLayout([], ink: [.day(F.day(2026, 10, 14)): 300, .memo: 500])), "a row and the memo")
        let day = F.dayLayout(F.demo)
        let tallDay = F.dayLayout(F.demo, ink: [.extra: 800])
        XCTAssertEqual(PaperGrowth.tail(of: day)?.key, .extra)
        XCTAssertEqual(PaperGrowth.tail(of: day)?.rect, day.extra)
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: day, new: tallDay), "the day's extra")
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: day, new: F.dayLayout(F.demo, focus: F.day(2026, 10, 8), ink: [.extra: 800])), "another pageId")
        var wider = tallDay
        wider.size.width = 1200
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: day, new: wider), "another width")
        var moved = tallDay
        moved.extra.origin.y = 2500
        moved.cells[.extra] = moved.extra
        moved.size.height = 2500 + moved.extra.height
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: day, new: moved), "the last cell moved")
        var longer = tallDay
        longer.size.height += 10
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: day, new: longer), "the paper does not end with the last cell")
        var otherCell = tallDay
        otherCell.cells[CellKey(raw: "zz")] = CGRect(x: 0, y: 0, width: 1, height: 1)
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: day, new: otherCell), "another set of cells")
        let week = F.weekLayout(F.demo)
        XCTAssertNil(PaperGrowth.tail(of: week))
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: week, new: week))
        let year = F.yearLayout([])
        XCTAssertNil(PaperGrowth.tail(of: year))
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: year, new: F.yearLayout([], ink: [CellKey(raw: "03-05"): 100])))
        XCTAssertFalse(PaperGrowth.onlyTailHeightChanged(old: plain, new: day), "another kind")
    }
}
