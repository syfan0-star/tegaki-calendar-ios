import InkModel
import Layout
import PencilKit
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the snapshot pictures (M3B_CONTRACT.md §3.5, §6.2): `render` fits its max
/// size and never enlarges more than 4×, nothing drawable gives nil, and `pkStrokes` places the
/// strokes exactly like the canvas (transform = the cell's top-left corner).
@MainActor
final class InkSnapshotTests: XCTestCase {
    private let month = YearMonth(year: 2026, month: 10)
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeLayout() -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: month, events: [], inkBottoms: [:], now: now))
    }

    /// A straight stroke of `count` points from `from` to `to` (cell-relative lu) with a square nib.
    private func makeInkStroke(id: String = InkStroke.newId(), cell: CellKey, from: CGPoint, to: CGPoint, count: Int = 12, nib: CGFloat = 3.5, tool: InkModel.InkTool = .pen) -> InkStroke {
        var points: [InkPoint] = []
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(max(count - 1, 1))
            points.append(InkPoint(
                x: from.x + (to.x - from.x) * t,
                y: from.y + (to.y - from.y) * t,
                dtMs: i * 10,
                sizeW: nib,
                sizeH: nib,
                opacity: 1,
                force: 0.5,
                azimuth: 0,
                altitude: .pi / 2
            ))
        }
        return InkStroke(id: id, cell: cell, tool: tool, color: tool == .marker ? "#fde047" : "#1f2937", t: 1_790_000_000_000, points: points)
    }

    func testRenderOfOneStrokeFitsTheMaxSize() {
        let layout = makeLayout()
        let stroke = makeInkStroke(cell: .day(DayKey(year: 2026, month: 10, day: 7)), from: CGPoint(x: 10, y: 20), to: CGPoint(x: 310, y: 60))
        guard let image = InkSnapshot.render(strokes: [stroke], cells: layout.cells, scale: 2) else { return XCTFail("no image") }
        XCTAssertLessThanOrEqual(image.size.width, 480)
        XCTAssertLessThanOrEqual(image.size.height, 240)
        XCTAssertEqual(image.scale, 2)
        // bbox 303.5 × 43.5 (+ the nib), + 12 lu of padding on every side → 327.5 × 67.5 lu →
        // zoom = min(480 / 327.5, 240 / 67.5, 4) → 480 × 99 pt.
        guard let cell = layout.cells[stroke.cell], let bbox = stroke.paperBounds(cellOrigin: cell.origin),
              let expected = LassoGeometry.snapshotLayout(bbox: bbox) else { return XCTFail("no layout") }
        XCTAssertEqual(image.size.width, expected.size.width, accuracy: 0.5)
        XCTAssertEqual(image.size.height, expected.size.height, accuracy: 0.5)
        XCTAssertEqual(image.size.width, 480, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 99, accuracy: 0.5)

        // A smaller max size shrinks it further.
        guard let small = InkSnapshot.render(strokes: [stroke], cells: layout.cells, maxSize: CGSize(width: 200, height: 100), scale: 2) else { return XCTFail("no small image") }
        XCTAssertLessThanOrEqual(small.size.width, 200)
        XCTAssertLessThanOrEqual(small.size.height, 100)
        XCTAssertEqual(small.size.width, 200, accuracy: 0.5)
    }

    func testTinyStrokeIsEnlargedAtMostFourTimes() {
        let layout = makeLayout()
        // 2 × 2 lu of points with a 3.5 nib → bbox 5.5 × 5.5, + 24 → 29.5 lu, × 4 = 118 pt.
        let dot = makeInkStroke(cell: .memo, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 52, y: 52), count: 4)
        guard let image = InkSnapshot.render(strokes: [dot], cells: layout.cells, scale: 2) else { return XCTFail("no image") }
        XCTAssertEqual(image.size.width, 118, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 118, accuracy: 0.5)
    }

    func testRenderIsNilWithoutDrawableStrokes() {
        let layout = makeLayout()
        XCTAssertNil(InkSnapshot.render(strokes: [], cells: layout.cells, scale: 2))
        // A week band cell is not on the month page: not drawable.
        let orphan = makeInkStroke(cell: CellKey(raw: "allday:2026-10-07"), from: .zero, to: CGPoint(x: 10, y: 10))
        XCTAssertNil(InkSnapshot.render(strokes: [orphan], cells: layout.cells, scale: 2))
        // One drawable stroke next to it is enough.
        let fine = makeInkStroke(cell: .memo, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 40, y: 20))
        XCTAssertNotNil(InkSnapshot.render(strokes: [orphan, fine], cells: layout.cells, scale: 2))
    }

    func testPKStrokesAreTranslatedToTheirCells() {
        let layout = makeLayout()
        let day = DayKey(year: 2026, month: 10, day: 14)
        guard let dayCell = layout.cells[.day(day)], let memoCell = layout.cells[.memo] else { return XCTFail("missing cells") }
        XCTAssertEqual(dayCell, CGRect(x: 400, y: 350, width: 200, height: 175), "contract §1.8")
        let a = makeInkStroke(cell: .day(day), from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 30))
        let orphan = makeInkStroke(cell: CellKey(raw: "allday:2026-10-07"), from: .zero, to: CGPoint(x: 10, y: 10))
        let b = makeInkStroke(cell: .memo, from: CGPoint(x: 5, y: 5), to: CGPoint(x: 60, y: 5), tool: .marker)

        let pk = InkSnapshot.pkStrokes([a, orphan, b], cells: layout.cells)
        XCTAssertEqual(pk.count, 2, "the orphan is skipped")
        XCTAssertEqual(pk[0].transform.tx, dayCell.minX, accuracy: 0.001)
        XCTAssertEqual(pk[0].transform.ty, dayCell.minY, accuracy: 0.001)
        XCTAssertEqual(pk[1].transform.tx, memoCell.minX, accuracy: 0.001)
        XCTAssertEqual(pk[1].transform.ty, memoCell.minY, accuracy: 0.001)
        XCTAssertEqual(pk[0].path.count, 12)
        XCTAssertEqual(pk[0].path[0].location.x, 10, accuracy: 0.11, "control points stay cell-relative")
        XCTAssertEqual(pk[0].path[0].location.applying(pk[0].transform).y, dayCell.minY + 20, accuracy: 0.11)
        XCTAssertEqual(pk[0].ink.inkType, PKInkingTool.InkType.pen)
        XCTAssertEqual(pk[1].ink.inkType, PKInkingTool.InkType.marker)

        // The same conversion as the canvas: the ledger's drawing has the same transforms.
        var page = InkPage.empty(pageId: layout.pageId)
        page.add(a)
        page.add(b)
        let drawing = InkLedger(page: page, layout: layout).drawing()
        XCTAssertEqual(Set(drawing.strokes.map { $0.transform.ty }), Set(pk.map { $0.transform.ty }))
    }

    func testMoveImageCoversTheBounds() {
        let layout = makeLayout()
        let stroke = makeInkStroke(cell: .day(DayKey(year: 2026, month: 10, day: 7)), from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 60))
        guard let cell = layout.cells[stroke.cell], let bounds = stroke.paperBounds(cellOrigin: cell.origin) else { return XCTFail("no bounds") }
        guard let image = InkSnapshot.image(strokes: [stroke], cells: layout.cells, bounds: bounds, zoom: 1.5, scale: 2) else { return XCTFail("no image") }
        // PencilKit returns the rect's size in points at the given scale (zoom × screen scale).
        XCTAssertEqual(image.size.width, bounds.width, accuracy: 1)
        XCTAssertEqual(image.size.height, bounds.height, accuracy: 1)
        XCTAssertEqual(image.scale, 3, accuracy: 0.001)
        XCTAssertNil(InkSnapshot.image(strokes: [stroke], cells: layout.cells, bounds: .zero, zoom: 1, scale: 2))
        XCTAssertNil(InkSnapshot.image(strokes: [], cells: layout.cells, bounds: bounds, zoom: 1, scale: 2))

        // A huge picture is rendered at a lower scale instead of asking for hundreds of MB.
        let huge = CGRect(x: 0, y: 0, width: 1400, height: 3000)
        guard let capped = InkSnapshot.image(strokes: [stroke], cells: layout.cells, bounds: huge, zoom: 4, scale: 3) else { return XCTFail("no capped image") }
        XCTAssertLessThanOrEqual(capped.size.width * capped.scale * capped.size.height * capped.scale, InkSnapshot.maxImagePixels * 1.01)
    }
}
