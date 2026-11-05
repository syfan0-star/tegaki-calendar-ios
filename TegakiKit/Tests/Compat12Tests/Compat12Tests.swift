import XCTest
import Foundation
import CoreGraphics
import Compat10
import InkModel
import Layout

/// K-11 against the frozen copy of 1.0 (docs/M7B_CONTRACT.md §10.2, §10.8): what the Sunday path of
/// 1.2 writes is read by the rules of 1.0 without losing or moving anything. A target of its own, so
/// that Compat10Tests stays byte for byte what K-7 froze. The real old Kits run in
/// tools/weekstart-compat (a step of CI's compat-v1.0 job).
final class Compat12Tests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func stroke(_ id: String, _ cell: CellKey, x: CGFloat = 20, t: Int = 1_780_000_000_000) -> InkStroke {
        let points = (0..<4).map { InkPoint(x: x + CGFloat($0) * 5, y: 100, dtMs: 8 * $0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5) }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: "ipad-12", points: points)
    }

    private var sundayPage: InkPage {
        var p = InkPage(pageId: PageNavigation.pageId(.week, focus: day(2026, 11, 4), weekStart: .sunday))
        p.add(stroke("s1", .grid, x: 80))
        p.add(stroke("s2", .grid, x: 1300))
        p.add(stroke("gone", .grid, x: 500))
        p.remove(ids: ["gone"], at: 1_780_000_100_000)
        return p
    }

    /// 2026-11: 12/12 is only on the Sunday grid, 10/26 only on the Monday grid (1.0's).
    private var monthPage: InkPage {
        var p = InkPage(pageId: "m1-2026-11")
        p.add(stroke("both", .day(day(2026, 11, 14))))
        p.add(stroke("sunOnly", .day(day(2026, 12, 12))))
        p.add(stroke("monOnly", .day(day(2026, 10, 26))))
        p.add(stroke("memo", .memo))
        return p
    }

    private func page10(_ page: InkPage) throws -> InkPageV10 {
        InkPageV10(json: try JSONValueV10.parse(page.jsonValue.serializedData()))
    }

    func testSundayWeekPageOnTheFrozen10() throws {
        XCTAssertEqual(sundayPage.pageId, "w-2026-11-01")
        let read = try page10(sundayPage)
        XCTAssertEqual(read.pageId, "w-2026-11-01")
        XCTAssertEqual(read.liveStrokeIds.sorted(), ["s1", "s2"])
        XCTAssertEqual(Array(read.deleted.keys), ["gone"])
        XCTAssertEqual(read.jsonValue.serialized(), sundayPage.jsonValue.serialized(), "1.0 writes the same JSON back")
        XCTAssertFalse(BandMigrationV10.needsMigration(read))
        XCTAssertEqual(BandMigrationV10.migrate(read), read, "nothing to move")
        XCTAssertEqual(try InkPageCodecV10.decode(InkPageCodec.encode(sundayPage)), read, "the stored file form")
        XCTAssertEqual(try InkPageCodec.decode(InkPageCodecV10.encode(read)), sundayPage, "and back")
        XCTAssertEqual(cellsV10(pageId: "w-2026-11-01"), [.grid])
        XCTAssertEqual(LedgerV10.drawnIds(page: read, cells: [.grid]).sorted(), ["s1", "s2"])
    }

    func testHiddenCellStrokeSurvives10Merge() throws {
        let read = try page10(monthPage)
        let cells = cellsV10(pageId: "m1-2026-11")
        XCTAssertFalse(cells.contains(.day(DayKeyV10(year: 2026, month: 12, day: 12))), "12/12 is not on 1.0's table")
        XCTAssertTrue(cells.contains(.day(DayKeyV10(year: 2026, month: 10, day: 26))))
        XCTAssertEqual(LedgerV10.drawnIds(page: read, cells: cells).sorted(), ["both", "memo", "monOnly"], "not drawn")
        XCTAssertEqual(read.liveStrokeIds.sorted(), ["both", "memo", "monOnly", "sunOnly"], "kept")
        var other = InkPageV10.empty(pageId: "m1-2026-11")
        other.add(InkStrokeV10(id: "new", cell: .memo, tool: .pen, color: "#1f2937", t: 1_781_000_000_000, dev: "ipad-10", points: [InkPointV10(x: 1, y: 2, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5)]))
        let merged = InkPageV10.merge(other, read)
        XCTAssertEqual(merged.liveStrokeIds.sorted(), ["both", "memo", "monOnly", "new", "sunOnly"], "the merge keeps the stroke 1.0 does not draw")
        XCTAssertEqual(merged.strokes["sunOnly"], read.strokes["sunOnly"], "not moved")
        XCTAssertEqual(InkPageV10.merge(read, read), read)
        // The same stroke under each grid of the new code: on the paper or not, never gone.
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: monthPage, weekStart: .monday), ["sunOnly"])
        XCTAssertEqual(WeekStartImpact.hiddenStrokeIds(in: monthPage, weekStart: .sunday), ["monOnly"])
    }

    func testExportFromNewCodeReadBy10() throws {
        let document = AppExport.Document(exportedAt: "2026-11-04T12:00:00+09:00", app: "ios/1.2 (1)", pages: [monthPage, sundayPage])
        let bytes = AppExport.encode(document)
        let read = try AppExportV10.parse(json: JSONValueV10.parse(bytes))
        XCTAssertEqual(read.pages.map(\.pageId), ["m1-2026-11", "w-2026-11-01"])
        XCTAssertEqual(read.pages, [try page10(monthPage), try page10(sundayPage)], "the pages come in whole")
        let written = AppExportV10.encode(AppExportV10.Document(exportedAt: read.exportedAt, app: read.app, pages: read.pages))
        XCTAssertEqual(written, bytes, "1.0 writes the same bytes back")
        XCTAssertEqual(try AppExport.parse(json: JSONValue.parse(written)), document, "and the new code reads them")
    }
}
