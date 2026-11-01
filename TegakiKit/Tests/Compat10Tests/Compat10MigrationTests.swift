import Foundation
import XCTest
import Compat10
import CompatFixtures
import InkModel
import Layout

/// `BandMigration` of 1.0 (F3, K-1): it moves only `allday` / `allday:…` strokes of `w-` / `d-` pages
/// onto `grid`. No 1.1 page is touched by it; the old band strokes still move exactly as before.
final class Compat10MigrationTests: XCTestCase {
    private let support = Compat10TestSupport.self

    func testNoNewPageIsTouchedByBandMigration10() throws {
        XCTAssertFalse(BandMigrationV10.isBandCell(CellKeyV10(raw: CellKey.extra.raw)), "K-1: extra is no band cell on 1.0")
        XCTAssertFalse(CellKey.extra.raw.hasPrefix("allday"))
        XCTAssertFalse(BandMigration.isBandCell(.extra))
        for name in support.pageNames where !support.isLegacy(name) && !CompatFixtures.largeNames.contains(name) {
            let page = try XCTUnwrap(support.page10(name), name)
            XCTAssertFalse(BandMigrationV10.needsMigration(page), name)
            XCTAssertEqual(BandMigrationV10.migrate(page), page, name)
            XCTAssertFalse(page.strokes.values.contains { BandMigrationV10.isBandCell($0.cell) }, name)
            XCTAssertFalse(LedgerV10.displayWouldSave(loaded: page), "\(name): opening it on 1.0 saves nothing")
        }
        // A large year page and an export page as well.
        let year = try XCTUnwrap(support.page10(CompatFixtures.n15000))
        XCTAssertFalse(BandMigrationV10.needsMigration(year))
        let export = try AppExportV10.parse(json: JSONValueV10.parse(XCTUnwrap(support.data(CompatFixtures.export11))))
        XCTAssertTrue(export.pages.allSatisfy { !BandMigrationV10.needsMigration($0) })
    }

    func testLegacyBandStrokeStillMovesToGrid() throws {
        let legacy10 = try XCTUnwrap(support.page10(CompatFixtures.weekLegacy))
        let legacy11 = try XCTUnwrap(support.page11(CompatFixtures.weekLegacy))
        let original = try XCTUnwrap(legacy10.strokes.values.first)
        XCTAssertEqual(original.cell.raw, "allday:2026-11-04")
        XCTAssertEqual(original.points.first?.x, 10)
        XCTAssertTrue(LedgerV10.displayWouldSave(loaded: legacy10), "1.0 saves the page after moving the stroke")

        let moved10 = BandMigrationV10.migrate(legacy10)
        let stroke = try XCTUnwrap(moved10.strokes[original.id], "the id is kept")
        XCTAssertEqual(stroke.cell, .grid)
        XCTAssertEqual(stroke.points.first?.x, 455.7, "10 + 64 + 2 × 190.857 = 455.714, 0.1 rounded")
        XCTAssertEqual(stroke.points.map(\.y), original.points.map(\.y))
        XCTAssertEqual(stroke.t, original.t)
        XCTAssertEqual(stroke.dev, original.dev)
        XCTAssertEqual(BandMigrationV10.migrate(moved10), moved10, "idempotent")

        // The new code moves it to the same bytes.
        XCTAssertEqual(support.bytes11(BandMigration.migrate(legacy11)), support.bytes10(moved10))
        // And the two forms merge to grid on both (F4: "grid" > "allday…").
        let both10 = InkPageV10.merge(legacy10, moved10)
        XCTAssertEqual(both10.strokes[original.id]?.cell, .grid)
        let both11 = InkPage.merge(legacy11, BandMigration.migrate(legacy11))
        XCTAssertEqual(support.bytes11(both11), support.bytes10(both10))
    }
}
