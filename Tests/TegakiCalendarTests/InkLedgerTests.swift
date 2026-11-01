import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the ledger ⇄ PencilKit bridge (DESIGN.md §8.4 "Ink", M3A_CONTRACT.md §8.2):
/// a `PKStroke` keeps its fingerprint when its `transform` changes, a new stroke gets an id and the
/// cell under its centre, an erased stroke gets a tombstone, undo re-adds a clone with a fresh id,
/// a relayout moves the strokes without producing a diff; and on the week / day / year pages the
/// strokes go to the time grid (the one cell of the week / day paper since M4b, which never grows;
/// above it too, with a negative y) or the year cell of the date gutter (January, negative x), and
/// the ledger never mixes pages. M4 (contract §5.4, §8.3): a `reload` keeps the fingerprint map, so
/// a remote update landing while the pen is down neither duplicates the canvas's strokes nor
/// revives a stroke another device erased. M4b (M4B_CONTRACT §3.3, §7.2): the strokes of the former
/// all-day band are moved onto the grid on `init` and `reload`, with the fingerprint map kept.
/// 1.1 (M7A_CONTRACT §2.4, §3.1, §3.6, §7.2): the last cell of a page (the month's memo area, the
/// day's free memo area below 24:00, `extra`) asks for room by the 400 lu step rule of
/// `PaperGrowth`; `adopt` takes a layout without touching the fingerprints; `undoIfTopRestores` puts
/// back exactly what one eraser touch took; and the ledger's own path (`applyCanvasChange` →
/// `inkCell` → `cellRelativePoints`, `moveStrokes`) writes the shapes of the compat fixtures
/// `ledger-day.json` / `ledger-month.json` (K-7, 0-23).
@MainActor
final class InkLedgerTests: XCTestCase {
    private let month = YearMonth(year: 2026, month: 10)
    private let pageId = "m1-2026-10"
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeLayout(inkBottoms: [CellKey: CGFloat] = [:]) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(
            month: month,
            events: [],
            inkBottoms: inkBottoms,
            now: now
        ))
    }

    /// The week of Wednesday 2026-10-07 (Monday 10-05, page "w-2026-10-05").
    private func makeWeekLayout(inkBottoms: [CellKey: CGFloat] = [:]) -> WeekPageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(
            focus: DayKey(year: 2026, month: 10, day: 7),
            events: [],
            inkBottoms: inkBottoms,
            now: now
        ))
    }

    private func makeDayLayout(inkBottoms: [CellKey: CGFloat] = [:]) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(
            day: DayKey(year: 2026, month: 10, day: 7),
            events: [],
            inkBottoms: inkBottoms,
            now: now
        ))
    }

    private func makeYearLayout(inkBottoms: [CellKey: CGFloat] = [:]) -> YearPageLayout {
        YearLayoutEngine.layout(YearLayoutInput(
            year: 2026,
            events: [],
            inkBottoms: inkBottoms,
            now: now
        ))
    }

    /// A five-point pen stroke whose control points start at `origin` (paper coordinates).
    private func makeStroke(at origin: CGPoint, creationDate: Date = Date()) -> PKStroke {
        var points: [PKStrokePoint] = []
        for i in 0..<5 {
            points.append(PKStrokePoint(
                location: CGPoint(x: origin.x + CGFloat(i) * 3, y: origin.y + CGFloat(i)),
                timeOffset: TimeInterval(i) * 0.01,
                size: CGSize(width: 3.5, height: 3.5),
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ))
        }
        let path = PKStrokePath(controlPoints: points, creationDate: creationDate)
        return PKStroke(ink: PKInk(.pen, color: .black), path: path, transform: .identity, mask: nil)
    }

    // MARK: Month (M2)

    func testFingerprintDoesNotDependOnTransform() {
        let stroke = makeStroke(at: CGPoint(x: 10, y: 20))
        let moved = PKStroke(
            ink: stroke.ink,
            path: stroke.path,
            transform: CGAffineTransform(translationX: 200, y: 175),
            mask: nil
        )
        XCTAssertEqual(StrokeGeometry.fingerprint(of: stroke), StrokeGeometry.fingerprint(of: moved))
        XCTAssertNotEqual(StrokeGeometry.fingerprint(of: stroke), StrokeGeometry.fingerprint(of: makeStroke(at: CGPoint(x: 11, y: 20))))
    }

    func testNewStrokeGetsIdAndCell() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout, deviceId: "test-device")
        _ = ledger.drawing()

        let day = DayKey(year: 2026, month: 10, day: 7) // second row, Wednesday
        guard let cell = layout.cells[.day(day)] else { return XCTFail("no cell for \(day)") }
        let stroke = makeStroke(at: CGPoint(x: cell.minX + 50, y: cell.minY + 60))
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [stroke]))

        XCTAssertEqual(change.added.count, 1)
        XCTAssertTrue(change.removedIds.isEmpty)
        guard let added = change.added.first else { return }
        XCTAssertEqual(added.cell, CellKey.day(day))
        XCTAssertEqual(added.tool, InkModel.InkTool.pen)
        XCTAssertEqual(added.color, "#000000")
        XCTAssertEqual(added.dev, "test-device")
        XCTAssertEqual(added.points.count, 5)
        XCTAssertEqual(added.points[0].x, 50, accuracy: 0.11)
        XCTAssertEqual(added.points[0].y, 60, accuracy: 0.11)
        XCTAssertEqual(added.points[4].x, 62, accuracy: 0.11)
        XCTAssertEqual(added.points[4].dtMs, 40)
        XCTAssertFalse(added.id.isEmpty)
        XCTAssertEqual(ledger.page.liveStrokes.count, 1)
        XCTAssertEqual(ledger.page.liveStrokes.first?.id, added.id)
        XCTAssertTrue(ledger.canUndo)
        XCTAssertFalse(ledger.canRedo)

        // The same drawing again is not a change.
        let again = ledger.applyCanvasChange(PKDrawing(strokes: [stroke]))
        XCTAssertTrue(again.isEmpty)
    }

    func testStrokeOffThePaperGoesToTheNearestCell() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()

        // Above and left of the paper → the first cell (Monday 2026-09-28); below → the memo area.
        let aboveStroke = makeStroke(at: CGPoint(x: -30, y: -30))
        let above = ledger.applyCanvasChange(PKDrawing(strokes: [aboveStroke]))
        XCTAssertEqual(above.added.first?.cell, CellKey.day(DayKey(year: 2026, month: 9, day: 28)))
        let below = ledger.applyCanvasChange(PKDrawing(strokes: [
            aboveStroke,
            makeStroke(at: CGPoint(x: 700, y: layout.size.height + 100), creationDate: Date(timeIntervalSince1970: 1_790_000_002)),
        ]))
        XCTAssertEqual(below.added.count, 1)
        XCTAssertEqual(below.added.first?.cell, CellKey.memo)
        XCTAssertTrue(ledger.needsMoreRoom(below.added[0]), "ink below the memo area asks for more room")
    }

    func testEraseMakesTombstoneAndUndoRestoresClone() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()
        let stroke = makeStroke(at: CGPoint(x: 30, y: 40))
        let added = ledger.applyCanvasChange(PKDrawing(strokes: [stroke]))
        guard let id = added.added.first?.id else { return XCTFail("stroke was not added") }

        // The vector eraser removed the stroke: the canvas drawing is empty.
        let erased = ledger.applyCanvasChange(PKDrawing(strokes: []))
        XCTAssertEqual(erased.removedIds, [id])
        XCTAssertTrue(erased.added.isEmpty)
        XCTAssertNotNil(ledger.page.deleted[id])
        XCTAssertNil(ledger.page.strokes[id])
        XCTAssertTrue(ledger.page.liveStrokes.isEmpty)

        // Undo re-adds a clone with a new id (a tombstoned id never comes back).
        let undone = ledger.undo()
        XCTAssertNotNil(undone)
        XCTAssertEqual(undone?.strokes.count, 1)
        XCTAssertEqual(ledger.page.liveStrokes.count, 1)
        let clone = ledger.page.liveStrokes[0]
        XCTAssertNotEqual(clone.id, id)
        XCTAssertNotNil(ledger.page.deleted[id])
        XCTAssertEqual(clone.points, added.added[0].points)
        XCTAssertTrue(ledger.canRedo)

        // Redo erases the clone again.
        let redone = ledger.redo()
        XCTAssertNotNil(redone)
        XCTAssertEqual(redone?.strokes.count, 0)
        XCTAssertTrue(ledger.page.liveStrokes.isEmpty)
        XCTAssertNotNil(ledger.page.deleted[clone.id])
    }

    func testRelayoutMovesStrokesWithoutDiff() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()
        let day = DayKey(year: 2026, month: 10, day: 7)
        guard let cell = layout.cells[.day(day)] else { return XCTFail("no cell for \(day)") }
        let stroke = makeStroke(at: CGPoint(x: cell.minX + 20, y: cell.minY + 30))
        _ = ledger.applyCanvasChange(PKDrawing(strokes: [stroke]))

        // Ink in the first row makes it taller: everything below moves down by 125 lu
        // (rowHeight = max(175, 288 + 12) = 300).
        let firstRowDay = DayKey(year: 2026, month: 9, day: 29)
        let taller = makeLayout(inkBottoms: [.day(firstRowDay): 288])
        guard let newCell = taller.cells[.day(day)] else { return XCTFail("no cell after relayout") }
        XCTAssertEqual(newCell.minY - cell.minY, 125, accuracy: 0.001)

        let drawing = ledger.relayout(taller)
        XCTAssertEqual(drawing.strokes.count, 1)
        guard let placed = drawing.strokes.first else { return }
        XCTAssertEqual(placed.transform.tx, newCell.minX, accuracy: 0.001)
        XCTAssertEqual(placed.transform.ty, newCell.minY, accuracy: 0.001)
        // Control points stay cell-relative; the transform carries the cell origin.
        XCTAssertEqual(placed.path[0].location.x, 20, accuracy: 0.11)
        XCTAssertEqual(placed.path[0].location.y, 30, accuracy: 0.11)
        XCTAssertEqual(placed.path[0].location.applying(placed.transform).y, newCell.minY + 30, accuracy: 0.11)

        // What the canvas now holds is exactly what the ledger built: no diff.
        ledger.bind(to: drawing)
        let change = ledger.applyCanvasChange(drawing)
        XCTAssertTrue(change.isEmpty, "relayout must not add or remove strokes")
        XCTAssertEqual(ledger.page.liveStrokes.count, 1)
    }

    func testPageRoundTripThroughCodecKeepsStrokes() throws {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()
        _ = ledger.applyCanvasChange(PKDrawing(strokes: [
            makeStroke(at: CGPoint(x: 30, y: 40), creationDate: Date(timeIntervalSince1970: 1_790_000_000)),
            makeStroke(at: CGPoint(x: 500, y: 900), creationDate: Date(timeIntervalSince1970: 1_790_000_001)),
        ]))
        XCTAssertEqual(ledger.page.liveStrokes.count, 2)

        let data = try InkPageCodec.encode(ledger.page)
        let compressed = try InkPageCodec.compress(data)
        let decoded = try InkPageCodec.decode(try InkPageCodec.decompress(compressed))
        XCTAssertEqual(decoded.pageId, pageId)
        XCTAssertEqual(decoded.liveStrokes.count, 2)
        XCTAssertEqual(decoded, ledger.page)

        // A ledger rebuilt from the stored page draws the same strokes at the same places.
        let rebuilt = InkLedger(page: decoded, layout: layout)
        let drawing = rebuilt.drawing()
        XCTAssertEqual(drawing.strokes.count, 2)
    }

    // MARK: Week

    func testWeekStrokeAboveTheGridBelongsToTheGrid() {
        let layout = makeWeekLayout()
        XCTAssertEqual(layout.pageId, "w-2026-10-05")
        XCTAssertEqual(layout.cells.count, 1, "the week paper is one cell since M4b")
        XCTAssertNil(layout.cells[.allDay(DayKey(year: 2026, month: 10, day: 7))], "no band cell on the paper")
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()

        // Above the paper (y −10, where the band used to be): the grid, with the negative y kept.
        let aboveStroke = makeStroke(at: CGPoint(x: 64 + 2 * PaperSpec.weekColumnWidth + 20, y: -10))
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [aboveStroke]))
        XCTAssertEqual(change.added.count, 1)
        guard let added = change.added.first else { return }
        XCTAssertEqual(added.cell, CellKey.grid)
        XCTAssertEqual(added.cell.raw, "grid")
        XCTAssertEqual(added.points[0].x, 64 + 2 * PaperSpec.weekColumnWidth + 20, accuracy: 0.11)
        XCTAssertEqual(added.points[0].y, -10, accuracy: 0.11)
        XCTAssertFalse(ledger.needsMoreRoom(added), "the grid never grows")

        // The time gutter (x < 64) belongs to the grid too, with its paper x.
        let gutterStroke = makeStroke(at: CGPoint(x: 10, y: 10), creationDate: Date(timeIntervalSince1970: 1_790_000_004))
        let gutter = ledger.applyCanvasChange(PKDrawing(strokes: [aboveStroke, gutterStroke]))
        XCTAssertEqual(gutter.added.count, 1)
        XCTAssertTrue(gutter.removedIds.isEmpty)
        XCTAssertEqual(gutter.added.first?.cell, CellKey.grid)
        XCTAssertEqual(gutter.added[0].points[0].x, 10, accuracy: 0.11)
        XCTAssertEqual(gutter.added[0].points[0].y, 10, accuracy: 0.11)
        XCTAssertFalse(ledger.needsMoreRoom(gutter.added[0]))

        // The drawing places both from the paper's origin (the grid is (0, 0, 1400, 1920)).
        let drawing = ledger.drawing()
        XCTAssertEqual(drawing.strokes.count, 2)
        for pk in drawing.strokes {
            XCTAssertEqual(pk.transform.tx, 0, accuracy: 0.001)
            XCTAssertEqual(pk.transform.ty, 0, accuracy: 0.001)
        }
    }

    func testWeekGridStrokeBelongsToGridAndNeverAsksForRoom() {
        let layout = makeWeekLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()
        guard let grid = layout.cells[.grid] else { return XCTFail("no grid cell") }
        XCTAssertEqual(grid.height, PaperSpec.weekGridHeight, accuracy: 0.001)
        XCTAssertFalse(layout.growsWithInk(.grid))

        // In the middle of the grid, and right at its bottom edge (which would ask a growing cell for room).
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [
            makeStroke(at: CGPoint(x: 300, y: grid.minY + 500)),
            makeStroke(at: CGPoint(x: 300, y: grid.maxY - 3), creationDate: Date(timeIntervalSince1970: 1_790_000_005)),
        ]))
        XCTAssertEqual(change.added.count, 2)
        for stroke in change.added {
            XCTAssertEqual(stroke.cell, CellKey.grid)
            XCTAssertFalse(ledger.needsMoreRoom(stroke), "the time grid never grows")
        }
        let middle = change.added.first { $0.points[0].y < 1000 }
        XCTAssertEqual(middle?.points[0].x ?? -1, 300, accuracy: 0.11)
        XCTAssertEqual(middle?.points[0].y ?? -1, 500, accuracy: 0.11)
    }

    // MARK: Day

    func testDayStrokesAllGoToTheGrid() {
        let layout = makeDayLayout()
        XCTAssertEqual(layout.pageId, "d-2026-10-07")
        XCTAssertEqual(layout.cells.count, 2, "grid and extra (1.1: the free memo area below 24:00); no band cell since M4b")
        XCTAssertNil(layout.cells[.allDayDay], "no band cell on the paper")
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()
        guard let grid = layout.cells[.grid] else { return XCTFail("no grid cell") }
        XCTAssertEqual(grid.minY, 0, accuracy: 0.001, "the grid starts at the paper's top")
        XCTAssertEqual(grid.width, PaperSpec.dayWidth, accuracy: 0.001, "the grid is the whole width (memo area included)")

        let change = ledger.applyCanvasChange(PKDrawing(strokes: [
            makeStroke(at: CGPoint(x: 900, y: 20)),                                                     // top of the memo column
            makeStroke(at: CGPoint(x: 900, y: grid.minY + 1000), creationDate: Date(timeIntervalSince1970: 1_790_000_006)),  // memo column
            makeStroke(at: CGPoint(x: 30, y: grid.minY + 1000), creationDate: Date(timeIntervalSince1970: 1_790_000_007)),   // time gutter
        ]))
        XCTAssertEqual(change.added.count, 3)
        let cells = change.added.map { $0.cell.raw }
        XCTAssertEqual(cells, ["grid", "grid", "grid"])
        for stroke in change.added {
            XCTAssertFalse(ledger.needsMoreRoom(stroke))
        }
        let top = change.added.first { $0.points[0].y < 100 }
        XCTAssertEqual(top?.points[0].x ?? -1, 900, accuracy: 0.11)
        XCTAssertEqual(top?.points[0].y ?? -1, 20, accuracy: 0.11)
        for stroke in change.added where stroke.points[0].y > 100 {
            XCTAssertEqual(stroke.points[0].y, 1000, accuracy: 0.11)
        }
    }

    // MARK: Year

    func testYearDateGutterStrokeBelongsToJanuaryWithNegativeX() {
        let layout = makeYearLayout()
        XCTAssertEqual(layout.pageId, "y-2026")
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()

        // (10, 100) is in the date gutter (x < 56) on the row of the 2nd → "01-02", x = 10 − 56.
        let gutterStroke = makeStroke(at: CGPoint(x: 10, y: 100))
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [gutterStroke]))
        XCTAssertEqual(change.added.count, 1)
        guard let added = change.added.first else { return }
        XCTAssertEqual(added.cell, CellKey.yearDay(month: 1, day: 2))
        XCTAssertEqual(added.cell.raw, "01-02")
        guard let cell = layout.cells[added.cell] else { return XCTFail("no cell 01-02") }
        XCTAssertEqual(cell.minX, PaperSpec.yearGutter, accuracy: 0.001)
        XCTAssertEqual(added.points[0].x, 10 - PaperSpec.yearGutter, accuracy: 0.11)
        XCTAssertLessThan(added.points[0].x, 0)
        XCTAssertEqual(added.points[0].y, 100 - cell.minY, accuracy: 0.11)
        XCTAssertTrue(layout.growsWithInk(added.cell))

        // A stroke inside the October 7 cell, and one in a day that does not exist (2/30) — both stick.
        guard let oct7 = layout.cells[.yearDay(month: 10, day: 7)], let feb30 = layout.cells[.yearDay(month: 2, day: 30)] else {
            return XCTFail("missing year cells")
        }
        let more = ledger.applyCanvasChange(PKDrawing(strokes: [
            gutterStroke,
            makeStroke(at: CGPoint(x: oct7.minX + 10, y: oct7.minY + 20), creationDate: Date(timeIntervalSince1970: 1_790_000_008)),
            makeStroke(at: CGPoint(x: feb30.minX + 10, y: feb30.minY + 20), creationDate: Date(timeIntervalSince1970: 1_790_000_009)),
        ]))
        XCTAssertEqual(more.added.map { $0.cell.raw }.sorted(), ["02-30", "10-07"])
    }

    func testYearRowGrowthMovesLowerRowsWithoutDiff() {
        let layout = makeYearLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()
        guard let oct20 = layout.cells[.yearDay(month: 10, day: 20)] else { return XCTFail("no cell 10-20") }
        _ = ledger.applyCanvasChange(PKDrawing(strokes: [makeStroke(at: CGPoint(x: oct20.minX + 10, y: oct20.minY + 20))]))

        // Ink down to 100 lu in 3/16 makes the row of the 16th 112 tall (+52); the 20th moves down.
        let taller = makeYearLayout(inkBottoms: [.yearDay(month: 3, day: 16): 100])
        guard let newOct20 = taller.cells[.yearDay(month: 10, day: 20)] else { return XCTFail("no cell after relayout") }
        XCTAssertEqual(newOct20.minY - oct20.minY, 52, accuracy: 0.001)

        let drawing = ledger.relayout(taller)
        guard let placed = drawing.strokes.first else { return XCTFail("stroke was not drawn") }
        XCTAssertEqual(placed.transform.tx, newOct20.minX, accuracy: 0.001)
        XCTAssertEqual(placed.transform.ty, newOct20.minY, accuracy: 0.001)
        ledger.bind(to: drawing)
        XCTAssertTrue(ledger.applyCanvasChange(drawing).isEmpty)
    }

    // MARK: Selection ops (M3B_CONTRACT §3.2, §6.2)

    func testRemoveStrokesIsOneUndoableOp() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()
        let a = makeStroke(at: CGPoint(x: 30, y: 40), creationDate: Date(timeIntervalSince1970: 1_790_000_000))
        let b = makeStroke(at: CGPoint(x: 300, y: 400), creationDate: Date(timeIntervalSince1970: 1_790_000_001))
        let first = ledger.applyCanvasChange(PKDrawing(strokes: [a]))
        let second = ledger.applyCanvasChange(PKDrawing(strokes: [a, b]))
        guard let idA = first.added.first?.id, let idB = second.added.first?.id else { return XCTFail("strokes were not added") }
        XCTAssertEqual(ledger.strokes(ids: [idB, idA, "nope", idA]).map { $0.id }, [idB, idA], "ids order, unknown and repeated ids skipped")

        let change = ledger.removeStrokes(ids: [idA, "nope", idB])
        XCTAssertEqual(change.removedIds, [idA, idB])
        XCTAssertTrue(change.added.isEmpty)
        XCTAssertNotNil(ledger.page.deleted[idA])
        XCTAssertNotNil(ledger.page.deleted[idB])
        XCTAssertTrue(ledger.page.liveStrokes.isEmpty)
        XCTAssertTrue(ledger.strokes(ids: [idA, idB]).isEmpty)
        XCTAssertNil(ledger.paperBounds(ids: [idA, idB]))
        XCTAssertTrue(ledger.removeStrokes(ids: [idA]).isEmpty, "ids that are not live are ignored")
        XCTAssertTrue(ledger.drawing().strokes.isEmpty)
        XCTAssertFalse(ledger.canRedo)

        // One undo brings both back, as clones with fresh ids (a tombstoned id never comes back).
        XCTAssertNotNil(ledger.undo())
        let restored = ledger.page.liveStrokes
        XCTAssertEqual(restored.count, 2)
        XCTAssertFalse(restored.contains { $0.id == idA || $0.id == idB })
        XCTAssertEqual(Set(restored.map { $0.points }), Set([first.added[0].points, second.added[0].points]))
        XCTAssertEqual(ledger.drawing().strokes.count, 2)
        XCTAssertTrue(ledger.canRedo)

        // One redo removes both again.
        XCTAssertNotNil(ledger.redo())
        XCTAssertTrue(ledger.page.liveStrokes.isEmpty)
        for s in restored { XCTAssertNotNil(ledger.page.deleted[s.id]) }
    }

    func testMoveStrokesMakesClonesInOneBatchAndDecidesTheCellAgain() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()
        let day = DayKey(year: 2026, month: 10, day: 7) // row 1, Wednesday
        let target = DayKey(year: 2026, month: 10, day: 15) // one column right, one row down
        guard let cell = layout.cells[.day(day)], let targetCell = layout.cells[.day(target)] else { return XCTFail("missing cells") }
        XCTAssertEqual(targetCell.minX - cell.minX, 200, accuracy: 0.001)
        XCTAssertEqual(targetCell.minY - cell.minY, 175, accuracy: 0.001)
        let s1 = makeStroke(at: CGPoint(x: cell.minX + 50, y: cell.minY + 60))
        let s2 = makeStroke(at: CGPoint(x: cell.minX + 80, y: cell.minY + 90), creationDate: Date(timeIntervalSince1970: 1_790_000_001))
        let c1 = ledger.applyCanvasChange(PKDrawing(strokes: [s1]))
        let c2 = ledger.applyCanvasChange(PKDrawing(strokes: [s1, s2]))
        guard let id1 = c1.added.first?.id, let id2 = c2.added.first?.id else { return XCTFail("strokes were not added") }
        // Paper bounds: the control points grown by half the 3.5 nib.
        XCTAssertEqual(ledger.paperBounds(of: id1)?.minX ?? -1, cell.minX + 50 - 1.75, accuracy: 0.2)
        XCTAssertEqual(ledger.paperBounds(of: id1)?.maxY ?? -1, cell.minY + 64 + 1.75, accuracy: 0.2)
        XCTAssertEqual(ledger.paperBounds(ids: [id1, id2])?.maxX ?? -1, cell.minX + 92 + 1.75, accuracy: 0.2)

        // A zero delta and ids that are not live do nothing (no history either).
        let none = ledger.moveStrokes(ids: [id1, id2], by: .zero)
        XCTAssertTrue(none.change.isEmpty)
        XCTAssertTrue(none.newIds.isEmpty)
        let dead = ledger.moveStrokes(ids: ["nope"], by: CGVector(dx: 10, dy: 0))
        XCTAssertTrue(dead.change.isEmpty)
        XCTAssertTrue(dead.newIds.isEmpty)
        XCTAssertEqual(ledger.page.liveStrokes.count, 2)
        XCTAssertFalse(ledger.canRedo)

        // One cell right, one row down: the clones belong to the 15th, at the same place in their cell.
        let result = ledger.moveStrokes(ids: [id2, id1, "nope"], by: CGVector(dx: 200, dy: 175))
        XCTAssertEqual(result.change.added.count, 2)
        XCTAssertEqual(result.change.removedIds, [id2, id1])
        XCTAssertEqual(result.newIds, result.change.added.map { $0.id }, "newIds follow the order of ids")
        XCTAssertFalse(result.newIds.contains(id1))
        XCTAssertFalse(result.newIds.contains(id2))
        let clone2 = result.change.added[0]
        let clone1 = result.change.added[1]
        XCTAssertEqual(clone1.cell, CellKey.day(target))
        XCTAssertEqual(clone2.cell, CellKey.day(target))
        XCTAssertEqual(clone1.points.count, 5)
        XCTAssertEqual(clone1.points[0].x, 50, accuracy: 0.11)
        XCTAssertEqual(clone1.points[0].y, 60, accuracy: 0.11)
        XCTAssertEqual(clone2.points[0].x, 80, accuracy: 0.11)
        XCTAssertEqual(clone2.points[0].y, 90, accuracy: 0.11)
        XCTAssertEqual(clone1.points[4].dtMs, c1.added[0].points[4].dtMs)
        XCTAssertEqual(clone1.tool, InkModel.InkTool.pen)
        XCTAssertEqual(clone1.color, c1.added[0].color)
        XCTAssertNotNil(ledger.page.deleted[id1])
        XCTAssertNotNil(ledger.page.deleted[id2])
        XCTAssertEqual(Set(ledger.page.liveStrokes.map { $0.id }), Set(result.newIds))
        XCTAssertEqual(ledger.strokes(ids: result.newIds).map { $0.id }, result.newIds)
        XCTAssertEqual(ledger.paperBounds(ids: result.newIds)?.minX ?? -1, targetCell.minX + 50 - 1.75, accuracy: 0.2)
        XCTAssertEqual(ledger.paperBounds(ids: result.newIds)?.minY ?? -1, targetCell.minY + 60 - 1.75, accuracy: 0.2)
        XCTAssertTrue(ledger.canUndo)
        XCTAssertFalse(ledger.canRedo)

        // The drawing places the clones in the new cell.
        let drawing = ledger.drawing()
        XCTAssertEqual(drawing.strokes.count, 2)
        for pk in drawing.strokes {
            XCTAssertEqual(pk.transform.tx, targetCell.minX, accuracy: 0.001)
            XCTAssertEqual(pk.transform.ty, targetCell.minY, accuracy: 0.001)
        }

        // One undo (one batch): the clones are gone and the originals are back — as fresh ids
        // (their own ids are tombstoned) in the old cell.
        XCTAssertNotNil(ledger.undo())
        let back = ledger.page.liveStrokes
        XCTAssertEqual(back.count, 2)
        XCTAssertFalse(back.contains { $0.id == id1 || $0.id == id2 || result.newIds.contains($0.id) })
        for s in back {
            XCTAssertEqual(s.cell, CellKey.day(day))
            XCTAssertNil(ledger.page.deleted[s.id])
        }
        XCTAssertEqual(Set(back.map { $0.points }), Set([c1.added[0].points, c2.added[0].points]))
        for id in result.newIds { XCTAssertNotNil(ledger.page.deleted[id]) }
        XCTAssertTrue(ledger.canRedo)

        // One redo moves them again (fresh ids once more), on the 15th.
        XCTAssertNotNil(ledger.redo())
        let again = ledger.page.liveStrokes
        XCTAssertEqual(again.count, 2)
        for s in again {
            XCTAssertEqual(s.cell, CellKey.day(target))
            XCTAssertFalse(result.newIds.contains(s.id))
        }
        XCTAssertEqual(ledger.drawing().strokes.count, 2)
    }

    /// (The name is the contract's, M4B_CONTRACT §7.2: the "band" is the top of the paper now.)
    func testMoveAcrossTheWeekBandKeepsGridStrokesOnTheGrid() {
        let layout = makeWeekLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()
        guard let grid = layout.cells[.grid] else { return XCTFail("no grid cell") }
        XCTAssertEqual(grid.minY, 0, accuracy: 0.001)
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [makeStroke(at: CGPoint(x: 300, y: grid.minY + 500))]))
        guard let id = change.added.first?.id else { return XCTFail("stroke was not added") }

        // Down the grid: still the grid, the points moved by the delta.
        let moved = ledger.moveStrokes(ids: [id], by: CGVector(dx: 0, dy: 160))
        XCTAssertEqual(moved.newIds.count, 1)
        XCTAssertEqual(moved.change.added[0].cell, CellKey.grid)
        XCTAssertEqual(moved.change.added[0].points[0].y, 660, accuracy: 0.11)
        XCTAssertFalse(ledger.needsMoreRoom(moved.change.added[0]), "the grid never grows")

        // Up to the top of the paper (where the band used to be): still the grid, y 10.
        let up = ledger.moveStrokes(ids: moved.newIds, by: CGVector(dx: 0, dy: -660 + 10))
        XCTAssertEqual(up.change.added.count, 1)
        XCTAssertEqual(up.change.added[0].cell, CellKey.grid)
        XCTAssertEqual(up.change.added[0].points[0].x, 300, accuracy: 0.11)
        XCTAssertEqual(up.change.added[0].points[0].y, 10, accuracy: 0.11)

        // Above the paper: still the grid, with a negative y.
        let above = ledger.moveStrokes(ids: up.newIds, by: CGVector(dx: 0, dy: -40))
        XCTAssertEqual(above.change.added.count, 1)
        XCTAssertEqual(above.change.added[0].cell, CellKey.grid)
        XCTAssertEqual(above.change.added[0].points[0].y, -30, accuracy: 0.11)
        XCTAssertFalse(ledger.needsMoreRoom(above.change.added[0]))
        XCTAssertEqual(ledger.drawing().strokes.count, 1, "a stroke above the paper is still drawn (from the grid's origin)")
    }

    func testPaperBoundsIsNilForStrokesTheLayoutCannotPlace() {
        let layout = makeLayout()
        var page = InkPage.empty(pageId: pageId)
        let point = InkPoint(x: 10, y: 10, dtMs: 0, sizeW: 3, sizeH: 3, opacity: 1, force: 0.5, azimuth: 0, altitude: 1)
        let orphan = InkStroke(id: "orphan", cell: CellKey(raw: "allday:2026-10-07"), tool: .pen, color: "#000000", t: 1_790_000_000_000, points: [point])
        let memo = InkStroke(id: "memo", cell: .memo, tool: .pen, color: "#000000", t: 1_790_000_000_000, points: [point])
        page.add(orphan)
        page.add(memo)
        let ledger = InkLedger(page: page, layout: layout)
        XCTAssertNil(ledger.paperBounds(of: "orphan"), "a week cell is not on the month page")
        XCTAssertEqual(ledger.strokes(ids: ["orphan", "memo"]).map { $0.id }, ["orphan", "memo"], "still live, just not drawn")
        guard let memoCell = layout.cells[.memo] else { return XCTFail("no memo cell") }
        XCTAssertEqual(ledger.paperBounds(ids: ["orphan", "memo"])?.minX ?? -1, memoCell.minX + 10 - 1.5, accuracy: 0.001)
        XCTAssertEqual(ledger.drawing().strokes.count, 1)
    }

    // MARK: The former band's strokes (M4B_CONTRACT §3.3, §3.5, §7.2)

    /// A stored stroke with the given cell-relative points.
    private func makeInkStroke(id: String, cell: CellKey, t: Int, points: [(CGFloat, CGFloat)]) -> InkStroke {
        let pts = points.enumerated().map { i, p in
            InkPoint(x: p.0, y: p.1, dtMs: i * 16, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: "ipad-1", points: pts)
    }

    /// The sample week page of M4B_CONTRACT §3.5 in its old form (the band's cells).
    private func makeOldBandWeekPage() -> InkPage {
        var page = InkPage.empty(pageId: "w-2026-10-05")
        page.add(makeInkStroke(id: "a1", cell: .allDay(DayKey(year: 2026, month: 10, day: 7)), t: 1_760_150_400_123, points: [(12, 40), (17, 43), (22, 40)]))
        page.add(makeInkStroke(id: "a2", cell: .allDay(DayKey(year: 2026, month: 10, day: 5)), t: 1_760_150_400_200, points: [(5, -5), (10, 2)]))
        page.add(makeInkStroke(id: "a3", cell: .grid, t: 1_760_150_400_300, points: [(300, 500)]))
        page.add(makeInkStroke(id: "a4", cell: .allDay(DayKey(year: 2026, month: 10, day: 19)), t: 1_760_150_400_400, points: [(0, 0)]))
        page.add(makeInkStroke(id: "a5", cell: CellKey(raw: "allday:xx"), t: 1_760_150_400_500, points: [(1, 1)]))
        page.remove(ids: ["zz"], at: 1_760_000_000_500)
        return page
    }

    func testLedgerMigratesBandStrokesOnInitAndReload() {
        let layout = makeWeekLayout()
        let old = makeOldBandWeekPage()
        XCTAssertTrue(BandMigration.needsMigration(old))
        let colW = PaperSpec.weekColumnWidth

        // init: the page comes in migrated (the ids are kept, the band strokes are on the grid).
        let ledger = InkLedger(page: old, layout: layout)
        XCTAssertFalse(BandMigration.needsMigration(ledger.page))
        XCTAssertEqual(ledger.page.pageId, "w-2026-10-05")
        XCTAssertEqual(Set(ledger.page.liveStrokeIds), ["a1", "a2", "a3", "a4", "a5"])
        XCTAssertEqual(ledger.page.deleted, ["zz": 1_760_000_000_500], "the tombstones are untouched")
        XCTAssertEqual(ledger.page.updatedAt, old.updatedAt, "updatedAt is untouched")
        guard let a1 = ledger.page.strokes["a1"], let a2 = ledger.page.strokes["a2"] else { return XCTFail("a1 / a2 missing") }
        XCTAssertEqual(a1.cell, CellKey.grid)
        XCTAssertEqual(a1.points.count, 3)
        XCTAssertEqual(a1.points[0].x, 457.7, accuracy: 0.11, "12 + 64 + 2 × 190.857")
        XCTAssertEqual(a1.points[0].x, 12 + 64 + 2 * colW, accuracy: 0.11)
        XCTAssertEqual(a1.points[0].y, 40, accuracy: 0.11)
        XCTAssertEqual(a1.points[2].x, 22 + 64 + 2 * colW, accuracy: 0.11)
        XCTAssertEqual(a1.points[2].y, 40, accuracy: 0.11)
        XCTAssertEqual(a1.t, 1_760_150_400_123)
        XCTAssertEqual(a1.dev, "ipad-1")
        XCTAssertEqual(a2.cell, CellKey.grid)
        XCTAssertEqual(a2.points[0].x, 69, accuracy: 0.11)
        XCTAssertEqual(a2.points[0].y, -5, accuracy: 0.11, "a negative y is kept (M4B-26)")
        XCTAssertEqual(ledger.page.strokes["a3"], old.strokes["a3"], "a grid stroke is untouched")
        XCTAssertEqual(ledger.page.strokes["a4"]?.cell, CellKey.grid)
        XCTAssertEqual(ledger.page.strokes["a4"]?.points[0].x ?? -1, 64 + 6 * colW, accuracy: 0.11, "a day outside the week → column 6")
        XCTAssertEqual(ledger.page.strokes["a5"]?.cell, CellKey.grid)
        XCTAssertEqual(ledger.page.strokes["a5"]?.points[0].x ?? -1, 65, accuracy: 0.11, "a broken key → column 0")

        // All five strokes are drawn, from the grid's origin, at their migrated places.
        let drawing = ledger.drawing()
        XCTAssertEqual(drawing.strokes.count, 5)
        ledger.bind(to: drawing)
        let placedA1 = drawing.strokes.first { ledger.id(of: $0) == "a1" }
        XCTAssertNotNil(placedA1)
        XCTAssertEqual(placedA1?.transform.tx ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(placedA1?.path[0].location.applying(placedA1?.transform ?? .identity).x ?? -1, 457.7, accuracy: 0.11)
        XCTAssertEqual(placedA1?.path[0].location.applying(placedA1?.transform ?? .identity).y ?? -1, 40, accuracy: 0.11)
        XCTAssertEqual(ledger.paperBounds(of: "a1")?.minX ?? -1, 457.7 - 1.75, accuracy: 0.2)
        XCTAssertTrue(ledger.applyCanvasChange(drawing).isEmpty, "what the canvas holds is exactly what the ledger built")

        // reload with the old form again (iCloud still has it): the same result, and the
        // fingerprint map is kept, so the drawing the canvas holds is still no change.
        ledger.reload(page: old, keepHistory: true)
        XCTAssertFalse(BandMigration.needsMigration(ledger.page))
        XCTAssertEqual(ledger.page.strokes["a1"], a1)
        XCTAssertEqual(ledger.page.strokes["a2"], a2)
        XCTAssertEqual(Set(ledger.page.liveStrokeIds), ["a1", "a2", "a3", "a4", "a5"])
        XCTAssertTrue(ledger.applyCanvasChange(drawing).isEmpty, "the fingerprint map survives the reload")
        XCTAssertEqual(ledger.drawing().strokes.count, 5)

        // A page that needs no migration comes in as it is (==).
        let migrated = BandMigration.migrate(old)
        ledger.reload(page: migrated, keepHistory: true)
        XCTAssertEqual(ledger.page, migrated)
        XCTAssertEqual(ledger.page, BandMigration.migrate(ledger.page), "idempotent")
    }

    func testLedgerMigratesTheDayBandOnInit() {
        let layout = makeDayLayout()
        var old = InkPage.empty(pageId: "d-2026-10-07")
        old.add(makeInkStroke(id: "b1", cell: .allDayDay, t: 1_760_150_400_123, points: [(800, 30)]))
        old.add(makeInkStroke(id: "b2", cell: .allDayDay, t: 1_760_150_400_200, points: [(100, -20), (120, -10)]))
        old.add(makeInkStroke(id: "b3", cell: .grid, t: 1_760_150_400_300, points: [(100, 500)]))
        let ledger = InkLedger(page: old, layout: layout)
        XCTAssertFalse(BandMigration.needsMigration(ledger.page))
        XCTAssertEqual(ledger.page.strokes["b1"]?.cell, CellKey.grid)
        XCTAssertEqual(ledger.page.strokes["b1"]?.points[0].x ?? -1, 800, accuracy: 0.11, "the day band's origin was the paper's: x unchanged")
        XCTAssertEqual(ledger.page.strokes["b1"]?.points[0].y ?? -1, 30, accuracy: 0.11)
        XCTAssertEqual(ledger.page.strokes["b2"]?.cell, CellKey.grid)
        XCTAssertEqual(ledger.page.strokes["b2"]?.points[0].y ?? -1, -20, accuracy: 0.11)
        XCTAssertEqual(ledger.page.strokes["b3"], old.strokes["b3"])
        XCTAssertEqual(ledger.drawing().strokes.count, 3, "all three are on the grid and drawn")
    }

    // MARK: Pages are never mixed

    func testReloadOrRelayoutWithAnotherPageIsIgnored() {
        // Contract §2.1: a Debug build asserts; here the assertion hook is silenced to check the
        // Release behaviour (the ledger stays as it was).
        let previousHook = InkLedger.onPageMismatch
        var reports: [String] = []
        InkLedger.onPageMismatch = { reports.append($0) }
        defer { InkLedger.onPageMismatch = previousHook }

        let week = makeWeekLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: week.pageId), layout: week)
        _ = ledger.drawing()
        guard let grid = week.cells[.grid] else { return XCTFail("no grid cell") }
        let added = ledger.applyCanvasChange(PKDrawing(strokes: [makeStroke(at: CGPoint(x: 300, y: grid.minY + 500))]))
        XCTAssertEqual(added.added.count, 1)

        var other = InkPage.empty(pageId: "d-2026-10-07")
        other.add(InkStroke(cell: .grid, tool: .pen, color: "#000000", t: 1_790_000_000_000, points: [
            InkPoint(x: 1, y: 1, dtMs: 0, sizeW: 3, sizeH: 3, opacity: 1, force: 0.5, azimuth: 0, altitude: 1),
        ]))
        ledger.reload(page: other, keepHistory: false)
        XCTAssertEqual(ledger.page.pageId, "w-2026-10-05")
        XCTAssertEqual(ledger.page.liveStrokes.count, 1)
        XCTAssertEqual(ledger.page.liveStrokes.first?.id, added.added.first?.id)
        XCTAssertTrue(ledger.canUndo, "the history of the ignored reload is untouched")

        let day = makeDayLayout()
        let drawing = ledger.relayout(day)
        XCTAssertEqual(ledger.layout.pageId, "w-2026-10-05")
        XCTAssertEqual(drawing.strokes.count, 1)
        XCTAssertEqual(drawing.strokes.first?.transform.ty ?? -1, grid.minY, accuracy: 0.001, "still placed on the week grid")

        XCTAssertEqual(reports.count, 2)
    }

    // MARK: Remote updates while the pen is down (M4 contract §5.4, §8.3)

    /// A stored pen stroke (cell-relative points) with its own `t`, so its fingerprint is unique.
    private func makeInkStroke(id: String, cell: CellKey, t: Int, x: CGFloat = 20, y: CGFloat = 30) -> InkStroke {
        let points = (0..<5).map { i in
            InkPoint(
                x: x + CGFloat(i) * 3, y: y + CGFloat(i), dtMs: i * 10,
                sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2
            )
        }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: "test-device", points: points)
    }

    /// (1) A reload with a page that gained a remote stroke, then the very same drawing the canvas
    /// still holds: nothing is added (the two strokes are still known) and nothing is removed (the
    /// remote stroke is not on the canvas yet, but it was never there to be erased).
    func testReloadKeepsTheFingerprintMapSoTheSameDrawingIsNoChange() {
        let layout = makeLayout()
        let day = DayKey(year: 2026, month: 10, day: 7)
        var page = InkPage.empty(pageId: pageId)
        page.add(makeInkStroke(id: "local-a", cell: .day(day), t: 1_790_000_000_000))
        page.add(makeInkStroke(id: "local-b", cell: .day(day), t: 1_790_000_001_000, y: 60))
        let ledger = InkLedger(page: page, layout: layout)
        let drawing = ledger.drawing()
        XCTAssertEqual(drawing.strokes.count, 2)
        ledger.bind(to: drawing)

        var remote = page
        remote.add(makeInkStroke(id: "remote-c", cell: .day(day), t: 1_790_000_002_000, y: 90))
        ledger.reload(page: remote, keepHistory: true)
        XCTAssertEqual(ledger.page.liveStrokes.count, 3)

        let change = ledger.applyCanvasChange(drawing)
        XCTAssertTrue(change.added.isEmpty, "the canvas strokes are still known: nothing is re-added under a new id")
        XCTAssertTrue(change.removedIds.isEmpty, "the remote stroke is not on the canvas yet, but it is not erased either")
        XCTAssertEqual(Set(ledger.page.liveStrokeIds), ["local-a", "local-b", "remote-c"])
    }

    /// (2) A reload with a page where another device erased one stroke (and wrote another), then the
    /// pen lifts with the erased stroke still on the canvas plus one new stroke: only the new stroke
    /// is added, the erased one stays a tombstone. (3) The rebuilt drawing then has no tombstoned
    /// stroke and holds the new and the remote one.
    func testReloadWithARemoteErasureDoesNotReviveItAndOnlyTheNewStrokeIsAdded() {
        let layout = makeLayout()
        let day = DayKey(year: 2026, month: 10, day: 7)
        guard let cell = layout.cells[.day(day)] else { return XCTFail("no cell for \(day)") }
        var page = InkPage.empty(pageId: pageId)
        page.add(makeInkStroke(id: "local-a", cell: .day(day), t: 1_790_000_000_000))
        page.add(makeInkStroke(id: "local-b", cell: .day(day), t: 1_790_000_001_000, y: 60))
        let ledger = InkLedger(page: page, layout: layout)
        let drawing = ledger.drawing()
        XCTAssertEqual(drawing.strokes.count, 2)
        ledger.bind(to: drawing)

        var remote = page
        remote.remove(ids: ["local-b"], at: 1_790_000_003_000)
        remote.add(makeInkStroke(id: "remote-c", cell: .day(day), t: 1_790_000_002_000, y: 90))
        ledger.reload(page: remote, keepHistory: true)
        XCTAssertNil(ledger.page.strokes["local-b"])
        XCTAssertNotNil(ledger.page.deleted["local-b"])

        // The pen lifts: the canvas still shows local-a and local-b (not redrawn yet) plus the new stroke.
        let fresh = makeStroke(at: CGPoint(x: cell.minX + 80, y: cell.minY + 100), creationDate: Date(timeIntervalSince1970: 1_790_000_010))
        let change = ledger.applyCanvasChange(PKDrawing(strokes: drawing.strokes + [fresh]))
        XCTAssertEqual(change.added.count, 1)
        XCTAssertTrue(change.removedIds.isEmpty)
        guard let added = change.added.first else { return }
        XCTAssertEqual(added.cell, CellKey.day(day))
        XCTAssertNil(ledger.page.strokes["local-b"], "the erased stroke is not revived under its id")
        XCTAssertNotNil(ledger.page.deleted["local-b"], "its tombstone stays")
        XCTAssertEqual(Set(ledger.page.liveStrokeIds), ["local-a", "remote-c", added.id], "nothing was re-added under a new id")

        // (3) The rebuilt drawing: no tombstoned stroke; the new and the remote stroke are in it.
        let rebuilt = ledger.drawing()
        XCTAssertEqual(rebuilt.strokes.count, 3)
        ledger.bind(to: rebuilt)
        XCTAssertEqual(Set(rebuilt.strokes.compactMap { ledger.id(of: $0) }), ["local-a", "remote-c", added.id])
        XCTAssertTrue(ledger.applyCanvasChange(rebuilt).isEmpty)
    }

    // MARK: 1.1 — the growing last cell, adopt, the eraser tap's undo (M7A_CONTRACT §2.4, §3.1, §3.6)

    /// A stored pen stroke of `cell` whose lowest point, half of its 4 lu nib included, is `bottom`
    /// (cell-relative): `InkStroke.bottom == bottom`.
    private func makeStoredStroke(cell: CellKey, bottom: CGFloat, id: String = InkStroke.newId()) -> InkStroke {
        let points = [
            InkPoint(x: 100, y: bottom - 12, dtMs: 0, sizeW: 4, sizeH: 4, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571),
            InkPoint(x: 110, y: bottom - 2, dtMs: 16, sizeW: 4, sizeH: 4, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571),
        ]
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: 1_790_000_000_000, points: points)
    }

    /// 0-2: the ledger asks for room with the rule the engines grow the cells with
    /// (`PaperGrowth.needsMoreRoom`): the last cell in 400 lu steps — a memo area of 1,100 grows for a
    /// stroke down to 750 (1.0's `b + 50` = 800 would not have asked) — the month and year cells by
    /// `b + 12` as before, the day's free memo area like the month's memo area, the time grid never.
    func testNeedsMoreRoomFollowsTheStepRule() {
        // The month's memo area: 700 when empty.
        let empty = makeLayout()
        XCTAssertEqual(empty.memo.height, 700, accuracy: 0.001)
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: empty)
        XCTAssertEqual(makeStoredStroke(cell: .memo, bottom: 301).bottom, 301, accuracy: 0.001)
        XCTAssertFalse(ledger.needsMoreRoom(makeStoredStroke(cell: .memo, bottom: 300)), "b ≤ 300 fits 700")
        XCTAssertTrue(ledger.needsMoreRoom(makeStoredStroke(cell: .memo, bottom: 301)), "b 301 → 1,100")

        // Ink down to 650: 1,100. 700 still fits it; 750 asks (→ 1,500), where 1.0 asked only past 1,050.
        let grown = makeLayout(inkBottoms: [.memo: 650])
        XCTAssertEqual(grown.memo.height, 1100, accuracy: 0.001)
        let grownLedger = InkLedger(page: InkPage.empty(pageId: pageId), layout: grown)
        XCTAssertFalse(grownLedger.needsMoreRoom(makeStoredStroke(cell: .memo, bottom: 700)))
        XCTAssertTrue(grownLedger.needsMoreRoom(makeStoredStroke(cell: .memo, bottom: 750)), "0-2: 750 + 50 = 800 < 1,100, but the step rule wants 1,500")
        XCTAssertEqual(PaperGrowth.tailHeight(inkBottom: 750), 1500, accuracy: 0.001)

        // A day cell of the month: the row rule `b + 12` (the 175 lu row).
        let day = DayKey(year: 2026, month: 10, day: 7)
        guard let cell = empty.cells[.day(day)] else { return XCTFail("no cell for \(day)") }
        XCTAssertFalse(ledger.needsMoreRoom(makeStoredStroke(cell: .day(day), bottom: cell.height - 12)))
        XCTAssertTrue(ledger.needsMoreRoom(makeStoredStroke(cell: .day(day), bottom: cell.height - 11)))

        // The day page: the free memo area below 24:00 grows like the memo area; the grid never.
        let dayLayout = makeDayLayout()
        XCTAssertEqual(dayLayout.extra.height, 700, accuracy: 0.001)
        let dayLedger = InkLedger(page: InkPage.empty(pageId: dayLayout.pageId), layout: dayLayout)
        XCTAssertFalse(dayLedger.needsMoreRoom(makeStoredStroke(cell: .extra, bottom: 300)))
        XCTAssertTrue(dayLedger.needsMoreRoom(makeStoredStroke(cell: .extra, bottom: 301)))
        XCTAssertFalse(dayLedger.needsMoreRoom(makeStoredStroke(cell: .grid, bottom: 5000)), "the time grid never grows")

        // The year: the row rule, unchanged.
        let year = makeYearLayout()
        let yearLedger = InkLedger(page: InkPage.empty(pageId: year.pageId), layout: year)
        let oct7 = CellKey.yearDay(month: 10, day: 7)
        guard let yearCell = year.cells[oct7] else { return XCTFail("no cell 10-07") }
        XCTAssertFalse(yearLedger.needsMoreRoom(makeStoredStroke(cell: oct7, bottom: yearCell.height - 12)))
        XCTAssertTrue(yearLedger.needsMoreRoom(makeStoredStroke(cell: oct7, bottom: yearCell.height - 11)))
    }

    /// §3.6: `adopt` takes a layout in which only the last cell's height changed — no drawing is
    /// built, the canvas's strokes are still known (the same drawing is no change), the new height is
    /// what `needsMoreRoom` reads, the strokes are placed from the same origin. A layout of another
    /// page is ignored and reported.
    func testAdoptKeepsFingerprints() {
        let previousHook = InkLedger.onPageMismatch
        var reports: [String] = []
        InkLedger.onPageMismatch = { reports.append($0) }
        defer { InkLedger.onPageMismatch = previousHook }

        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        _ = ledger.drawing()
        let memo = layout.memo
        // Low in the memo area (bottom ≈ 495.75): the area must grow to 1,100.
        let pk = makeStroke(at: CGPoint(x: 100, y: memo.minY + 490), creationDate: Date(timeIntervalSince1970: 1_790_000_020))
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [pk]))
        guard let added = change.added.first else { return XCTFail("stroke was not added") }
        XCTAssertEqual(added.cell, CellKey.memo)
        XCTAssertTrue(ledger.needsMoreRoom(added))

        let grown = makeLayout(inkBottoms: ledger.page.inkBottoms())
        XCTAssertEqual(grown.memo.height, 1100, accuracy: 0.001)
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: layout, new: grown))
        ledger.adopt(grown)
        XCTAssertEqual(ledger.layout.cells[.memo]?.height ?? 0, 1100, accuracy: 0.001)
        XCTAssertEqual(ledger.layout.size.height, grown.size.height, accuracy: 0.001)
        XCTAssertFalse(ledger.needsMoreRoom(added), "the adopted height is read")
        XCTAssertTrue(ledger.applyCanvasChange(PKDrawing(strokes: [pk])).isEmpty, "the fingerprint map is kept")
        XCTAssertEqual(ledger.page.liveStrokeIds, [added.id])
        let drawing = ledger.drawing()
        XCTAssertEqual(drawing.strokes.count, 1)
        XCTAssertEqual(drawing.strokes.first?.transform.ty ?? -1, memo.minY, accuracy: 0.001, "the memo area did not move")

        // Another page's layout: ignored, reported once.
        ledger.adopt(makeDayLayout())
        XCTAssertEqual(ledger.layout.pageId, pageId)
        XCTAssertEqual(ledger.layout.cells[.memo]?.height ?? 0, 1100, accuracy: 0.001)
        XCTAssertEqual(reports.count, 1)
    }

    /// §2.4 (0-22): `undoIfTopRestores` undoes only an erasure of exactly `ids` — the newest op, or
    /// the newest few `.add`s of one touch the eraser reported in several changes. Anything else on
    /// top (a stroke drawn, an erasure of other strokes, more or fewer ids) is left alone. The strokes
    /// come back as clones with new ids (`makeId`); the erased ids keep their tombstones.
    func testUndoIfTopRestores() {
        let layout = makeLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: pageId), layout: layout)
        var seed = 0
        ledger.makeId = {
            seed += 1
            return "00000000-0000-4000-8000-00000000000\(seed)"
        }
        _ = ledger.drawing()
        let a = makeStroke(at: CGPoint(x: 30, y: 40), creationDate: Date(timeIntervalSince1970: 1_790_000_030))
        let b = makeStroke(at: CGPoint(x: 300, y: 400), creationDate: Date(timeIntervalSince1970: 1_790_000_031))
        let c = makeStroke(at: CGPoint(x: 600, y: 400), creationDate: Date(timeIntervalSince1970: 1_790_000_032))
        guard let strokeA = ledger.applyCanvasChange(PKDrawing(strokes: [a])).added.first,
              let strokeB = ledger.applyCanvasChange(PKDrawing(strokes: [a, b])).added.first else { return XCTFail("strokes were not added") }
        let ida = strokeA.id
        let idb = strokeB.id
        XCTAssertEqual(ida, "00000000-0000-4000-8000-000000000001", "new strokes take makeId's ids")

        XCTAssertNil(ledger.undoIfTopRestores(ids: []))
        XCTAssertNil(ledger.undoIfTopRestores(ids: [idb]), "the newest op takes b away (it was drawn); it does not put it back")
        XCTAssertEqual(ledger.page.liveStrokeIds.sorted(), [ida, idb].sorted())

        // The eraser takes b: the newest op puts back exactly b.
        let erased = ledger.applyCanvasChange(PKDrawing(strokes: [a]))
        XCTAssertEqual(erased.removedIds, [idb])
        XCTAssertNil(ledger.undoIfTopRestores(ids: [ida]), "another stroke")
        XCTAssertNil(ledger.undoIfTopRestores(ids: [ida, idb]), "more than the op puts back")
        XCTAssertEqual(ledger.page.liveStrokeIds, [ida], "nothing changed")
        guard let restored = ledger.undoIfTopRestores(ids: [idb]) else { return XCTFail("b was not put back") }
        XCTAssertEqual(restored.strokes.count, 2)
        XCTAssertEqual(ledger.page.liveStrokes.count, 2)
        XCTAssertNotNil(ledger.page.deleted[idb], "the erased id stays tombstoned")
        guard let clone = ledger.page.liveStrokes.first(where: { $0.id != ida }) else { return XCTFail("no clone") }
        XCTAssertEqual(clone.id, "00000000-0000-4000-8000-000000000003", "a clone with a new id")
        XCTAssertEqual(clone.points, strokeB.points)
        XCTAssertTrue(ledger.canRedo)

        // A stroke drawn on top: nothing.
        var canvas = restored.strokes
        canvas.append(c)
        guard let strokeC = ledger.applyCanvasChange(PKDrawing(strokes: canvas)).added.first else { return XCTFail("c was not added") }
        let idc = strokeC.id
        XCTAssertNil(ledger.undoIfTopRestores(ids: [idc]))
        XCTAssertNil(ledger.undoIfTopRestores(ids: [clone.id]))
        XCTAssertEqual(ledger.page.liveStrokes.count, 3)

        // One touch, reported in two changes (a, then c): the two `.add`s on top go back together.
        canvas.removeAll { ledger.id(of: $0) == ida }
        XCTAssertEqual(ledger.applyCanvasChange(PKDrawing(strokes: canvas)).removedIds, [ida])
        canvas.removeAll { ledger.id(of: $0) == idc }
        XCTAssertEqual(ledger.applyCanvasChange(PKDrawing(strokes: canvas)).removedIds, [idc])
        XCTAssertNil(ledger.undoIfTopRestores(ids: [ida]), "the newest op puts back c, not a")
        XCTAssertNil(ledger.undoIfTopRestores(ids: [ida, idc, clone.id]), "the clone was never erased")
        guard let both = ledger.undoIfTopRestores(ids: [ida, idc]) else { return XCTFail("a and c were not put back") }
        XCTAssertEqual(both.strokes.count, 3)
        XCTAssertEqual(ledger.page.liveStrokes.count, 3)
        XCTAssertTrue(ledger.page.isLive(clone.id), "the clone of b was not touched")
        XCTAssertFalse(ledger.page.isLive(ida))
        XCTAssertFalse(ledger.page.isLive(idc))
    }

    // MARK: 1.1 — the compat fixtures (M7A_CONTRACT §1.4, §7.2, 0-23)

    /// Ids and times from a seed: lower-case UUID shapes `<prefix>-0000-4000-8000-<n>` and
    /// `baseMs + n`, so the fixture is the same on every run.
    private final class Seed {
        private let prefix: String
        private let baseMs: Int
        private var ids = 0
        private var ms = 0

        init(prefix: String, baseMs: Int) {
            self.prefix = prefix
            self.baseMs = baseMs
        }

        func nextId() -> String {
            ids += 1
            let hex = String(ids, radix: 16)
            return prefix + "-0000-4000-8000-" + String(repeating: "0", count: max(0, 12 - hex.count)) + hex
        }

        func nextMs() -> Int {
            ms += 1
            return baseMs + ms
        }
    }

    /// A pen stroke through `points` (paper coordinates), a 3.5 lu nib, written at `creationDate`.
    private func makeStroke(through points: [CGPoint], creationDate: Date) -> PKStroke {
        let controlPoints = points.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.016, size: CGSize(width: 3.5, height: 3.5),
                          opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: controlPoints, creationDate: creationDate),
                        transform: .identity, mask: nil)
    }

    /// The keys a stroke and a page of the 1.0 format may have (K-5: 1.1 adds none).
    private static let strokeKeys: Set<String> = ["id", "cell", "tool", "color", "t", "dev", "pts"]

    /// K-1 and K-5 on a page: no cell name starts with "allday" (`BandMigration` leaves it alone),
    /// the page's keys are the known ones, every stroke's keys are 1.0's, nothing unknown is carried.
    private func assertKnownShapes(_ page: InkPage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(BandMigration.needsMigration(page), "K-1", file: file, line: line)
        XCTAssertTrue(page.unknown.isEmpty, file: file, line: line)
        XCTAssertTrue(page.unknownStrokes.isEmpty, file: file, line: line)
        guard let object = page.jsonValue.objectValue else { return XCTFail("not an object", file: file, line: line) }
        XCTAssertEqual(Set(object.keys), InkPage.knownKeys, "K-5: the page's keys", file: file, line: line)
        for (id, value) in object["strokes"]?.objectValue ?? [:] {
            let keys = Set(value.objectValue?.keys.map { $0 } ?? [])
            XCTAssertTrue(keys.isSubset(of: Self.strokeKeys), "K-5: \(id) has \(keys.subtracting(Self.strokeKeys))", file: file, line: line)
            XCTAssertFalse(BandMigration.isBandCell(CellKey(raw: value.objectValue?["cell"]?.stringValue ?? "")), "K-1: \(id)", file: file, line: line)
        }
    }

    /// The folder of the compat fixtures (`TegakiKit/Tests/Fixtures/compat11/`), found from this
    /// file's path (no bundle resources: the same way on the simulator, macOS and KitChecks).
    private static var fixtureFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TegakiCalendarTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the repository
            .appendingPathComponent("TegakiKit/Tests/Fixtures/compat11", isDirectory: true)
    }

    /// The page's stored JSON (`InkPageCodec.encode`: keys sorted, compact — the bytes a device writes
    /// and sends) must be the fixture `name` byte for byte. When the fixture is missing or differs,
    /// the JSON is written to `$TEGAKI_FIXTURE_OUT/<name>` (the CI's `shots/fixtures/`) and the test
    /// fails: the lead reads it and commits it (§8 3; the first CI is red on purpose).
    private func assertMatchesFixture(_ page: InkPage, named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let data: Data
        do {
            data = try InkPageCodec.encode(page)
        } catch {
            return XCTFail("\(name): could not encode the page: \(error)", file: file, line: line)
        }
        let url = Self.fixtureFolder.appendingPathComponent(name)
        let stored = try? Data(contentsOf: url)
        guard stored != data else { return }
        var written = "TEGAKI_FIXTURE_OUT is not set, nothing written"
        if let out = ProcessInfo.processInfo.environment["TEGAKI_FIXTURE_OUT"], !out.isEmpty {
            let folder = URL(fileURLWithPath: out, isDirectory: true)
            let target = folder.appendingPathComponent(name)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: target, options: .atomic)
                written = "wrote \(target.path)"
            } catch {
                written = "could not write \(target.path): \(error)"
            }
        }
        XCTFail("\(name): the fixture \(stored == nil ? "is missing" : "differs") at \(url.path) (\(data.count) bytes now); \(written)",
                file: file, line: line)
    }

    /// K-7 / 0-23: the app's own path writes the shapes a 1.0 device must survive. With the 1.1
    /// engines' layouts, PencilKit strokes go through `applyCanvasChange` (→ `inkCell(forCenter:)` →
    /// `StrokeGeometry.cellRelativePoints`) one at a time, as the canvas sends them, and a `grid`
    /// stroke is moved below 24:00 with `moveStrokes`; ids, times and the device id are seeded.
    /// - The day (`ledger-day.json`, d-2026-11-05): two strokes of the 23:00 hour (`grid`, one of them
    ///   reaching below 24:00 with its centre above), one crossing 24:00 with its centre below
    ///   (`extra`, a negative y), four from paper y 2,430 to 8,350 (`extra`, y − 2,400), and the
    ///   10:00 stroke moved 2,000 lu down (its id tombstoned, a clone in `extra`).
    /// - The month (`ledger-month.json`, m1-2027-01): a stroke of 1/15 and five low in the memo area
    ///   (centres 380 … 5,990 below its top), the layout adopted as the area grows.
    /// Then the cells, the cell-relative points and the 1.0 shapes are checked, and the page JSON is
    /// compared with the fixture byte for byte.
    func testLedgerWritesTheCompatShapes() {
        // The day.
        let dayLayout = DayLayoutEngine.layout(DayLayoutInput(day: DayKey(year: 2026, month: 11, day: 5), events: [], inkBottoms: [:], now: now))
        XCTAssertEqual(dayLayout.pageId, "d-2026-11-05")
        let day = InkLedger(page: InkPage.empty(pageId: dayLayout.pageId), layout: dayLayout, deviceId: "compat-ipad")
        let daySeed = Seed(prefix: "11d00000", baseMs: 1_790_100_000_000)
        day.makeId = { daySeed.nextId() }
        day.nowMs = { daySeed.nextMs() }
        _ = day.drawing()
        func line(x: CGFloat, y: CGFloat) -> [CGPoint] {
            (0..<5).map { CGPoint(x: x + CGFloat($0) * 3, y: y + CGFloat($0)) }
        }
        func upright(x: CGFloat, from y0: CGFloat, to y1: CGFloat) -> [CGPoint] {
            (0..<5).map { CGPoint(x: x + CGFloat($0), y: y0 + (y1 - y0) * CGFloat($0) / 4) }
        }
        let dayStrokes: [(name: String, points: [CGPoint], cell: CellKey)] = [
            ("23:30", line(x: 120, y: 2330), .grid),
            ("into 24:00, centre above", upright(x: 300, from: 2380, to: 2412), .grid),
            ("across 24:00, centre below", upright(x: 500, from: 2388, to: 2420), .extra),
            ("y 2,430", line(x: 100, y: 2428), .extra),
            ("y 3,100", line(x: 200, y: 3098), .extra),
            ("y 5,600", line(x: 300, y: 5598), .extra),
            ("y 8,350", line(x: 400, y: 8348), .extra),
            ("10:00 (moved below)", line(x: 700, y: 998), .grid),
        ]
        var canvas: [PKStroke] = []
        var dayIds: [String: String] = [:]
        for (index, entry) in dayStrokes.enumerated() {
            canvas.append(makeStroke(through: entry.points, creationDate: Date(timeIntervalSince1970: 1_790_100_000 + TimeInterval(index))))
            let change = day.applyCanvasChange(PKDrawing(strokes: canvas))
            XCTAssertEqual(change.added.count, 1, entry.name)
            XCTAssertTrue(change.removedIds.isEmpty, entry.name)
            guard let added = change.added.first else { continue }
            XCTAssertEqual(added.cell, entry.cell, entry.name)
            XCTAssertEqual(added.dev, "compat-ipad")
            XCTAssertEqual(added.t, 1_790_100_000_000 + index * 1000, "t comes from the stroke's creation date")
            let origin = dayLayout.cells[entry.cell]?.origin ?? .zero
            XCTAssertEqual(added.points.first?.y ?? -1, entry.points[0].y - origin.y, accuracy: 0.11, "\(entry.name): cell-relative")
            XCTAssertEqual(added.points.last?.y ?? -1, entry.points[4].y - origin.y, accuracy: 0.11, "\(entry.name): cell-relative")
            dayIds[entry.name] = added.id
        }
        XCTAssertEqual(dayLayout.cells[.extra]?.origin ?? .zero, CGPoint(x: 0, y: 2400))
        XCTAssertEqual(day.page.strokes[dayIds["across 24:00, centre below"] ?? ""]?.points.first?.y ?? 0, -12, accuracy: 0.11,
                       "an extra stroke may start above its cell")
        XCTAssertEqual(day.page.strokes[dayIds["into 24:00, centre above"] ?? ""]?.points.last?.y ?? 0, 2412, accuracy: 0.11,
                       "K-2: a grid stroke reaching below 24:00 stays grid")
        XCTAssertEqual(day.page.strokes[dayIds["y 8,350"] ?? ""]?.points.first?.y ?? 0, 5948, accuracy: 0.11)
        guard let movedId = dayIds["10:00 (moved below)"] else { return XCTFail("no 10:00 stroke") }
        let moved = day.moveStrokes(ids: [movedId], by: CGVector(dx: 0, dy: 2000))
        XCTAssertEqual(moved.change.removedIds, [movedId])
        guard let clone = moved.change.added.first else { return XCTFail("the 10:00 stroke was not moved") }
        XCTAssertEqual(clone.cell, CellKey.extra, "moved below 24:00: a new id in extra (K-2: never the same id in another cell)")
        XCTAssertNotEqual(clone.id, movedId)
        XCTAssertEqual(clone.points.first?.y ?? -1, 998 + 2000 - 2400, accuracy: 0.11)
        XCTAssertNotNil(day.page.deleted[movedId], "the original is tombstoned")
        XCTAssertEqual(day.page.liveStrokes.count, 8)
        XCTAssertEqual(day.page.liveStrokes.filter { $0.cell == .extra }.count, 6)
        XCTAssertEqual(day.page.liveStrokes.filter { $0.cell == .grid }.count, 2)
        assertKnownShapes(day.page)
        assertMatchesFixture(day.page, named: "ledger-day.json")

        // The month.
        let monthLayout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2027, month: 1), events: [], inkBottoms: [:], now: now))
        XCTAssertEqual(monthLayout.pageId, "m1-2027-01")
        let month = InkLedger(page: InkPage.empty(pageId: monthLayout.pageId), layout: monthLayout, deviceId: "compat-ipad")
        let monthSeed = Seed(prefix: "11e00000", baseMs: 1_790_200_000_000)
        month.makeId = { monthSeed.nextId() }
        month.nowMs = { monthSeed.nextMs() }
        _ = month.drawing()
        let memoTop = monthLayout.memo.minY
        let jan15 = CellKey.day(DayKey(year: 2027, month: 1, day: 15))
        guard let jan15Cell = monthLayout.cells[jan15] else { return XCTFail("no cell for 1/15") }
        var monthStrokes: [(name: String, points: [CGPoint], cell: CellKey)] = [
            ("1/15", line(x: jan15Cell.minX + 40, y: jan15Cell.minY + 60), jan15),
        ]
        for depth in [380, 790, 3190, 5590, 5990] as [CGFloat] {
            monthStrokes.append(("memo \(Int(depth))", line(x: 300, y: memoTop + depth - 2), .memo))
        }
        var monthCanvas: [PKStroke] = []
        var layout: MonthPageLayout = monthLayout
        for (index, entry) in monthStrokes.enumerated() {
            monthCanvas.append(makeStroke(through: entry.points, creationDate: Date(timeIntervalSince1970: 1_790_200_000 + TimeInterval(index))))
            let change = month.applyCanvasChange(PKDrawing(strokes: monthCanvas))
            guard let added = change.added.first else {
                XCTFail("\(entry.name) was not added")
                continue
            }
            XCTAssertEqual(added.cell, entry.cell, entry.name)
            let origin = layout.cells[entry.cell]?.origin ?? .zero
            XCTAssertEqual(added.points.first?.y ?? -1, entry.points[0].y - origin.y, accuracy: 0.11, "\(entry.name): cell-relative")
            if month.needsMoreRoom(added) {
                // What the canvas does when the owner lays the page out again: only the memo area grew.
                let grown = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2027, month: 1), events: [],
                                                                      inkBottoms: month.page.inkBottoms(), now: now))
                XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: layout, new: grown), entry.name)
                month.adopt(grown)
                layout = grown
            }
        }
        let deepest = month.page.inkBottoms()[.memo] ?? 0
        XCTAssertEqual(deepest, 5990 + 2 + 1.75, accuracy: 0.11)
        XCTAssertTrue(PaperGrowth.reachesCap(inkBottom: deepest))
        XCTAssertEqual(month.layout.cells[.memo]?.height ?? 0, PaperGrowth.tailHeight(inkBottom: deepest), accuracy: 0.001)
        XCTAssertEqual(month.layout.cells[.memo]?.minY ?? 0, memoTop, accuracy: 0.001, "the memo area never moved")
        XCTAssertEqual(month.page.liveStrokes.filter { $0.cell == .memo }.count, 5)
        assertKnownShapes(month.page)
        assertMatchesFixture(month.page, named: "ledger-month.json")
    }
}
