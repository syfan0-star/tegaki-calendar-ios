import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// What 1.0 draws, erases and lassos (F1, K-8): only the strokes of the cells its layout has. The
/// day's `extra` below 24:00 is invisible on 1.0 and out of reach of its eraser, lasso and finger
/// dots; the month's deep memo stays visible on 1.0 (its memo area has no upper limit, F6).
final class Compat10DrawTests: XCTestCase {
    private let support = Compat10TestSupport.self
    private let extra = CellKeyV10(raw: "extra")

    func testDayExtraIsNotDrawnNorErasableOn10() throws {
        let day = try XCTUnwrap(support.page10(CompatFixtures.dayPage))
        let cells = cellsV10(pageId: day.pageId)
        XCTAssertEqual(cells, [.grid], "1.0's day page has one cell")
        let drawn = LedgerV10.drawnIds(page: day, cells: cells)
        XCTAssertEqual(drawn.count, 6)
        XCTAssertTrue(drawn.allSatisfy { day.strokes[$0]?.cell == .grid })
        XCTAssertEqual(Set(LedgerV10.lassoCandidates(page: day, cells: cells)), Set(drawn))
        XCTAssertEqual(Set(LedgerV10.dotCandidates(page: day, cells: cells)), Set(drawn))

        // Erasing everything on the 1.0 canvas tombstones the grid strokes only.
        var erased = day
        erased.remove(ids: drawn, at: CompatFixtures.baseTime + 900)
        let before = support.strokesJSON10(day)
        let after = support.strokesJSON10(erased)
        XCTAssertEqual(after.count, 8 + 1, "the 8 extra strokes and the unknown tool remain")
        for (id, json) in after { XCTAssertEqual(json, before[id], "\(id) byte for byte") }
        let raw = try JSONValueV10.parse(XCTUnwrap(support.data(CompatFixtures.dayPage)))["strokes"]?.objectValue ?? [:]
        for (id, json) in after { XCTAssertEqual(json.serialized(), raw[id]?.serialized(), "\(id) as in the file") }

        // 1.1 draws all 14 and the unknown tool stays undrawn there too.
        let page11 = try XCTUnwrap(support.page11(CompatFixtures.dayPage))
        let layout = CompatFixtures.dayLayout(CompatFixtures.dayKey, ink: page11.inkBottoms())
        XCTAssertEqual(layout.extra.height, 6005, "5,955 + 50")
        XCTAssertEqual(page11.liveStrokes.filter { layout.cells[$0.cell] != nil }.count, 14)
        for stroke in page11.liveStrokes {
            let origin = try XCTUnwrap(layout.cells[stroke.cell]?.origin)
            let bounds = try XCTUnwrap(stroke.paperBounds(cellOrigin: origin))
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            XCTAssertEqual(layout.inkCell(forCenter: center), stroke.cell, "the cell 1.1 gives the centre")
            XCTAssertNil(PaperGrowth.drop(center: center, in: layout), "1.1 would keep it")
        }
    }

    func testMonthDeepMemoIsDrawnOn10() throws {
        let month = try XCTUnwrap(support.page10(CompatFixtures.monthPage))
        let cells = cellsV10(pageId: month.pageId)
        XCTAssertEqual(cells.count, 43, "42 days and memo")
        XCTAssertEqual(LedgerV10.drawnIds(page: month, cells: cells).count, 9)
        let memo = month.strokes.values.filter { $0.cell.isMemo }
        XCTAssertEqual(memo.map(\.bottom).sorted(), [380, 790, 3190, 5590, 5990])
        let height = memoHeightV10(month.inkBottoms()[.memo] ?? 0)
        XCTAssertEqual(height, 6040)
        for stroke in memo {
            XCTAssertFalse(LedgerV10.needsMoreRoom(stroke, cellHeight: height, growsWithInk: true))
            XCTAssertLessThanOrEqual(stroke.bottom, height)
        }
        // Each stroke one by one, as it was written: 1.0's memo always fits it (b + 50 ≤ 1.1's height).
        for stroke in memo {
            XCTAssertLessThanOrEqual(memoHeightV10(stroke.bottom), PaperGrowth.tailHeight(inkBottom: stroke.bottom))
        }
        let page11 = try XCTUnwrap(support.page11(CompatFixtures.monthPage))
        let layout = CompatFixtures.monthLayout(2026, 11, ink: page11.inkBottoms())
        XCTAssertEqual(layout.memo.height, 6040, "1.1: b + 50 wins over the 6,000 cap")
        XCTAssertEqual(layout.memo.minY, 1050)
    }

    func testMemoFrom10BelowTheCapStaysVisible() throws {
        let from10 = try XCTUnwrap(support.page10(CompatFixtures.monthFrom10))
        XCTAssertEqual(from10.strokes.values.filter { $0.cell.isMemo }.map(\.bottom).max(), 6420)
        XCTAssertEqual(memoHeightV10(from10.inkBottoms()[.memo] ?? 0), 6470)
        XCTAssertEqual(LedgerV10.drawnIds(page: from10, cells: cellsV10(pageId: from10.pageId)).count, from10.liveStrokeCount)

        let page11 = try XCTUnwrap(support.page11(CompatFixtures.monthFrom10))
        let layout = CompatFixtures.monthLayout(2026, 12, ink: page11.inkBottoms())
        XCTAssertEqual(layout.memo.height, 6470, "1.1 grows to b + 50 so the 1.0 line stays visible")
        let deep = try XCTUnwrap(page11.liveStrokes.first { $0.cell == .memo && $0.bottom == 6420 })
        XCTAssertLessThanOrEqual(deep.bottom, layout.memo.height)
        // A new stroke there is beyond the cap; above the cap it is kept.
        XCTAssertEqual(PaperGrowth.drop(center: CGPoint(x: 700, y: layout.memo.minY + 6100), in: layout), .beyondCap)
        XCTAssertNil(PaperGrowth.drop(center: CGPoint(x: 700, y: layout.memo.minY + 5900), in: layout))
        XCTAssertTrue(PaperGrowth.reachesCap(inkBottom: 6420))
    }

    func testGridStrokeMovedBelow24IsHiddenOn10() throws {
        let moved = try XCTUnwrap(support.page10(CompatFixtures.dayMoved))
        let move = CompatFixtures.dayMove()
        XCTAssertNotNil(moved.deleted[move.originalId], "the original id is a tombstone")
        XCTAssertNil(moved.strokes[move.originalId])
        let copy = try XCTUnwrap(moved.strokes[move.newId], "the copy has a new id")
        XCTAssertEqual(copy.cell, extra)
        let drawn = LedgerV10.drawnIds(page: moved, cells: cellsV10(pageId: moved.pageId))
        XCTAssertEqual(drawn.count, 2, "1.0 draws the two grid strokes only")
        XCTAssertFalse(drawn.contains(move.newId))

        // The copy's points are what 1.0's own `translated` gives for the same move.
        let before = try XCTUnwrap(support.to10(CompatFixtures.dayBeforeMove()))
        let original = try XCTUnwrap(before.strokes[move.originalId])
        let expected = original.translated(by: move.delta, from: .zero, to: extra, newCellOrigin: CGPoint(x: 0, y: 2400), id: move.newId, at: move.at)
        XCTAssertEqual(copy, expected)
        XCTAssertEqual(copy.points.first?.y, (original.points.first?.y ?? 0) + 600 - 2400)
        XCTAssertEqual(moved.deleted[move.originalId], move.at)

        // On 1.1 the copy is drawn below 24:00.
        let page11 = try XCTUnwrap(support.page11(CompatFixtures.dayMoved))
        let layout = CompatFixtures.dayLayout(CompatFixtures.movedDayKey, ink: page11.inkBottoms())
        XCTAssertEqual(layout.cells[.extra]?.minY, 2400)
        XCTAssertEqual(page11.liveStrokes.filter { layout.cells[$0.cell] != nil }.count, 3)
    }
}
