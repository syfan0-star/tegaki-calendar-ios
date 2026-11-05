import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// The frozen ledger under a Sunday grid (docs/M7B_CONTRACT.md §10.2, D17, K-11): a stroke on a day the
/// table does not show is not drawn, and erasing the whole paper does not erase it; a stroke on a day
/// both tables show follows its date. Nothing in `Ink/*` knows about the week start: it reads the layout.
@MainActor
final class WeekStartLedgerTests: XCTestCase {
    /// 2026-11 starts on a Sunday: 10/26–10/31 are only in the Monday table, 12/7–12/12 only in the Sunday one.
    private let november = YearMonth(year: 2026, month: 11)
    private let pageId = "m1-2026-11"
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let onlyMonday = DayKey(year: 2026, month: 10, day: 28)
    private let inBoth = DayKey(year: 2026, month: 11, day: 10)

    private func layout(_ weekStart: WeekStart) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: november, events: [], inkBottoms: [:], now: now, weekStart: weekStart))
    }

    private func stroke(_ id: String, on day: DayKey) -> InkStroke {
        let points = (0..<5).map { i in
            InkPoint(x: CGFloat(30 + i * 4), y: CGFloat(40 + i), dtMs: i * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: .day(day), tool: .pen, color: "#1f2937", t: 1_760_000_001_000, points: points)
    }

    private func page() -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        page.add(stroke("hidden", on: onlyMonday))
        page.add(stroke("shown", on: inBoth))
        return page
    }

    func testHiddenStrokeIsNotErased() {
        let sunday = layout(.sunday)
        XCTAssertNil(sunday.cells[.day(onlyMonday)], "the premise: no such cell in the Sunday table")
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: page(), weekStart: .sunday), ["hidden"])
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: page(), weekStart: .monday), [])

        let ledger = InkLedger(page: page(), layout: sunday, deviceId: "test-device")
        XCTAssertEqual(ledger.drawing().strokes.count, 1, "not drawn")

        // Erasing everything on the paper: the canvas's drawing is empty.
        let erased = ledger.applyCanvasChange(PKDrawing(strokes: []))
        XCTAssertEqual(erased.removedIds, ["shown"])
        XCTAssertNil(ledger.page.deleted["hidden"], "no tombstone")
        XCTAssertNotNil(ledger.page.strokes["hidden"])
        XCTAssertNotNil(ledger.page.deleted["shown"])

        // Back on the Monday table it is drawn again, in its place.
        let back = InkLedger(page: ledger.page, layout: layout(.monday), deviceId: "test-device")
        XCTAssertEqual(back.drawing().strokes.count, 1)
        XCTAssertEqual(back.page.liveStrokes.map(\.id), ["hidden"])
    }

    /// The cell's key is the date: the same stroke sits in the same date's cell in both tables, and the
    /// stored page does not change by being shown (K-2).
    func testStrokeFollowsItsDateWhenLayoutChanges() throws {
        let monday = layout(.monday)
        let sunday = layout(.sunday)
        let mondayCell = try XCTUnwrap(monday.cells[.day(inBoth)])
        let sundayCell = try XCTUnwrap(sunday.cells[.day(inBoth)])
        XCTAssertNotEqual(mondayCell.origin, sundayCell.origin, "the premise: the cell moved")

        var alone = InkPage.empty(pageId: pageId)
        alone.add(stroke("shown", on: inBoth))
        let onMonday = try XCTUnwrap(InkLedger(page: alone, layout: monday, deviceId: "test-device").drawing().strokes.first)
        let onSunday = try XCTUnwrap(InkLedger(page: alone, layout: sunday, deviceId: "test-device").drawing().strokes.first)
        let mondayBounds = StrokeGeometry.paperBounds(of: onMonday)
        let sundayBounds = StrokeGeometry.paperBounds(of: onSunday)
        XCTAssertEqual(mondayBounds.minX - mondayCell.minX, sundayBounds.minX - sundayCell.minX, accuracy: 0.5)
        XCTAssertEqual(mondayBounds.minY - mondayCell.minY, sundayBounds.minY - sundayCell.minY, accuracy: 0.5)

        // One ledger, moved to the other table: the same stroke, no change, the same stored page.
        let ledger = InkLedger(page: alone, layout: monday, deviceId: "test-device")
        _ = ledger.drawing()
        let moved = ledger.relayout(sunday)
        XCTAssertEqual(moved.strokes.count, 1)
        XCTAssertTrue(ledger.applyCanvasChange(moved).isEmpty)
        XCTAssertEqual(ledger.page, alone)
    }
}
