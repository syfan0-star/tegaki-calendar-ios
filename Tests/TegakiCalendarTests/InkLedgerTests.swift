import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the ledger ⇄ PencilKit bridge (DESIGN.md §8.4 "Ink", M3A_CONTRACT.md §8.2):
/// a `PKStroke` keeps its fingerprint when its `transform` changes, a new stroke gets an id and the
/// cell under its centre, an erased stroke gets a tombstone, undo re-adds a clone with a fresh id,
/// a relayout moves the strokes without producing a diff; and on the week / day / year pages the
/// strokes go to the all-day band, the time grid (which never grows) or the year cell of the date
/// gutter (January, negative x), and the ledger never mixes pages.
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

    func testWeekBandStrokeBelongsToThatDaysAllDayCell() {
        let layout = makeWeekLayout()
        XCTAssertEqual(layout.pageId, "w-2026-10-05")
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()

        let wednesday = DayKey(year: 2026, month: 10, day: 7)
        guard let cell = layout.cells[.allDay(wednesday)] else { return XCTFail("no all-day cell for \(wednesday)") }
        XCTAssertEqual(cell.minY, 0, accuracy: 0.001)
        let bandStroke = makeStroke(at: CGPoint(x: cell.minX + 20, y: cell.minY + 10))
        let change = ledger.applyCanvasChange(PKDrawing(strokes: [bandStroke]))
        XCTAssertEqual(change.added.count, 1)
        guard let added = change.added.first else { return }
        XCTAssertEqual(added.cell, CellKey.allDay(wednesday))
        XCTAssertEqual(added.cell.raw, "allday:2026-10-07")
        XCTAssertEqual(added.points[0].x, 20, accuracy: 0.11)
        XCTAssertEqual(added.points[0].y, 10, accuracy: 0.11)
        XCTAssertFalse(ledger.needsMoreRoom(added), "10 lu of ink fits in a 60 lu band")

        // Writing near the bottom of the band asks the band to grow (it is a growing cell).
        let lowStroke = makeStroke(at: CGPoint(x: cell.minX + 40, y: cell.maxY - 8), creationDate: Date(timeIntervalSince1970: 1_790_000_003))
        let low = ledger.applyCanvasChange(PKDrawing(strokes: [bandStroke, lowStroke]))
        XCTAssertEqual(low.added.count, 1)
        XCTAssertTrue(low.removedIds.isEmpty)
        XCTAssertEqual(low.added.first?.cell, CellKey.allDay(wednesday))
        XCTAssertTrue(ledger.needsMoreRoom(low.added[0]))

        // The time gutter above the band (x < 64) belongs to Monday's band, with a negative x.
        let gutterStroke = makeStroke(at: CGPoint(x: 10, y: 10), creationDate: Date(timeIntervalSince1970: 1_790_000_004))
        let gutter = ledger.applyCanvasChange(PKDrawing(strokes: [bandStroke, lowStroke, gutterStroke]))
        XCTAssertEqual(gutter.added.count, 1)
        XCTAssertEqual(gutter.added.first?.cell, CellKey.allDay(DayKey(year: 2026, month: 10, day: 5)))
        XCTAssertEqual(gutter.added[0].points[0].x, 10 - PaperSpec.weekGutter, accuracy: 0.11)
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

    func testWeekBandGrowthMovesGridStrokesWithoutDiff() {
        let layout = makeWeekLayout()
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()
        guard let grid = layout.cells[.grid] else { return XCTFail("no grid cell") }
        _ = ledger.applyCanvasChange(PKDrawing(strokes: [makeStroke(at: CGPoint(x: 300, y: grid.minY + 500))]))

        // Ink down to 100 lu in Monday's band: the band becomes 112 (100 + 12), the grid moves by 52.
        let monday = DayKey(year: 2026, month: 10, day: 5)
        let taller = makeWeekLayout(inkBottoms: [.allDay(monday): 100, .grid: 5000])
        guard let newGrid = taller.cells[.grid] else { return XCTFail("no grid cell after relayout") }
        XCTAssertEqual(newGrid.minY - grid.minY, 52, accuracy: 0.001)
        XCTAssertEqual(newGrid.height, PaperSpec.weekGridHeight, accuracy: 0.001, "inkBottoms of the grid are ignored")

        let drawing = ledger.relayout(taller)
        XCTAssertEqual(drawing.strokes.count, 1)
        guard let placed = drawing.strokes.first else { return }
        XCTAssertEqual(placed.transform.ty, newGrid.minY, accuracy: 0.001)
        XCTAssertEqual(placed.path[0].location.applying(placed.transform).y, newGrid.minY + 500, accuracy: 0.11)

        ledger.bind(to: drawing)
        let change = ledger.applyCanvasChange(drawing)
        XCTAssertTrue(change.isEmpty, "relayout must not add or remove strokes")
        XCTAssertEqual(ledger.page.liveStrokes.count, 1)
        XCTAssertEqual(PageScroll.scrollDelta(old: layout, new: taller, topVisibleY: grid.minY + 10), 52, accuracy: 0.001)
        XCTAssertEqual(PageScroll.scrollDelta(old: layout, new: taller, topVisibleY: 10), 0, accuracy: 0.001)
    }

    // MARK: Day

    func testDayStrokesGoToBandOrGrid() {
        let layout = makeDayLayout()
        XCTAssertEqual(layout.pageId, "d-2026-10-07")
        let ledger = InkLedger(page: InkPage.empty(pageId: layout.pageId), layout: layout)
        _ = ledger.drawing()
        guard let band = layout.cells[.allDayDay], let grid = layout.cells[.grid] else { return XCTFail("no cells") }
        XCTAssertEqual(band.width, PaperSpec.dayWidth, accuracy: 0.001, "the band is one cell across the whole width")

        let change = ledger.applyCanvasChange(PKDrawing(strokes: [
            makeStroke(at: CGPoint(x: 900, y: 20)),                                                     // band, above the memo column
            makeStroke(at: CGPoint(x: 900, y: grid.minY + 1000), creationDate: Date(timeIntervalSince1970: 1_790_000_006)),  // memo column of the grid
            makeStroke(at: CGPoint(x: 30, y: grid.minY + 1000), creationDate: Date(timeIntervalSince1970: 1_790_000_007)),   // time gutter of the grid
        ]))
        XCTAssertEqual(change.added.count, 3)
        let cells = change.added.map { $0.cell.raw }.sorted()
        XCTAssertEqual(cells, ["allday", "grid", "grid"])
        for stroke in change.added where stroke.cell == .grid {
            XCTAssertFalse(ledger.needsMoreRoom(stroke))
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
}
