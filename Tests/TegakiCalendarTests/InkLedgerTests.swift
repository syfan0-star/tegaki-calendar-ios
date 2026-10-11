import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the ledger ⇄ PencilKit bridge (DESIGN.md §8.4 "Ink"): a `PKStroke` keeps its
/// fingerprint when its `transform` changes, a new stroke gets an id and the cell under its centre,
/// an erased stroke gets a tombstone, undo re-adds a clone with a fresh id, and a relayout moves
/// the strokes without producing a diff.
@MainActor
final class InkLedgerTests: XCTestCase {
    private let month = YearMonth(year: 2026, month: 10)
    private let pageId = "m1-2026-10"

    private func makeLayout(inkBottoms: [CellKey: CGFloat] = [:]) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(
            month: month,
            events: [],
            inkBottoms: inkBottoms,
            now: Date(timeIntervalSince1970: 1_790_000_000)
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
}
