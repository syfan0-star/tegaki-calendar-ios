import XCTest
import Foundation
import CoreGraphics
import InkModel

/// Moving the former all-day band's strokes onto the grid (M4B_CONTRACT §3.1 / §3.5), and the
/// unchanged merge rule that lets the moved stroke win (§3.2). The same checks run in KitChecks.
final class BandMigrationTests: XCTestCase {
    private let colW = PaperSpec.weekColumnWidth
    private let wed = DayKey(year: 2026, month: 10, day: 7)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5, force: Double = 0.5) -> InkPoint {
        InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: CGFloat(force), azimuth: 1.5708, altitude: 0.7854)
    }

    private func stroke(_ id: String, cell: CellKey, tool: InkTool = .pen, color: String = "#1f2937", t: Int = 1_760_150_400_123, dev: String? = "ipad-1", points: [InkPoint]? = nil) -> InkStroke {
        InkStroke(id: id, cell: cell, tool: tool, color: color, t: t, dev: dev, points: points ?? [point(10, 20), point(30.06, 40.04, dt: 16), point(50, 90, dt: 32)])
    }

    /// The sample week page of M4B_CONTRACT §3.5.
    private func weekPage() -> InkPage {
        var page = InkPage.empty(pageId: "w-2026-10-05")
        page.add(stroke("a1", cell: .allDay(wed), points: [point(12, 40), point(17, 43, dt: 16), point(22, 40, dt: 32)]))
        page.add(stroke("a2", cell: .allDay(day(2026, 10, 5)), tool: .marker, color: "#fde047", t: 1_760_150_400_200, dev: nil, points: [point(5, -5, size: 18), point(10, 2, dt: 16, size: 18)]))
        page.add(stroke("a3", cell: .grid, points: [point(300, 500)]))
        page.add(stroke("a4", cell: .allDay(day(2026, 10, 19)), points: [point(0, 0)]))
        page.add(stroke("a5", cell: CellKey(raw: "allday:xx"), points: [point(1, 1)]))
        page.remove(ids: ["zz"], at: 1_760_000_000_500)
        return page
    }

    /// The sample day page of §3.5.
    private func dayPage() -> InkPage {
        var page = InkPage.empty(pageId: "d-2026-10-07")
        page.add(stroke("b1", cell: .allDayDay, color: "#2563eb", points: [point(800, 30)]))
        page.add(stroke("b2", cell: .allDayDay, points: [point(100, -20), point(120, -10, dt: 16)]))
        page.add(stroke("b3", cell: .grid, points: [point(100, 500)]))
        return page
    }

    /// The stroke `id` moved onto the grid: every point's x / y as expected (0.11 lu), everything
    /// else kept.
    private func assertMoved(_ id: String, old: InkPage, new: InkPage, xs: [CGFloat], ys: [CGFloat], _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let o = old.strokes[id], let n = new.strokes[id] else {
            XCTFail("\(id) must exist before and after. \(message)", file: file, line: line)
            return
        }
        XCTAssertEqual(n.cell, .grid, "\(id) → grid", file: file, line: line)
        XCTAssertEqual(n.id, o.id, file: file, line: line)
        XCTAssertEqual(n.t, o.t, "\(id): t kept", file: file, line: line)
        XCTAssertEqual(n.dev, o.dev, "\(id): dev kept", file: file, line: line)
        XCTAssertEqual(n.tool, o.tool, "\(id): tool kept", file: file, line: line)
        XCTAssertEqual(n.color, o.color, "\(id): colour kept", file: file, line: line)
        XCTAssertEqual(n.points.count, o.points.count, "\(id): point count kept", file: file, line: line)
        XCTAssertEqual(n.points.count, xs.count, file: file, line: line)
        for (i, p) in n.points.enumerated() where i < xs.count {
            XCTAssertEqual(p.x, xs[i], accuracy: 0.11, "\(id) point \(i): x", file: file, line: line)
            XCTAssertEqual(p.y, ys[i], accuracy: 0.11, "\(id) point \(i): y", file: file, line: line)
            XCTAssertEqual(p.dtMs, o.points[i].dtMs, "\(id) point \(i): dt kept", file: file, line: line)
            XCTAssertEqual(p.sizeW, o.points[i].sizeW, "\(id) point \(i): size kept", file: file, line: line)
            XCTAssertEqual(p.force, o.points[i].force, "\(id) point \(i): force kept", file: file, line: line)
        }
    }

    func testWeekPage() throws {
        let old = weekPage()
        XCTAssertTrue(BandMigration.needsMigration(old))
        let new = BandMigration.migrate(old)
        XCTAssertFalse(BandMigration.needsMigration(new))
        XCTAssertEqual(new.pageId, "w-2026-10-05")
        XCTAssertEqual(new.updatedAt, old.updatedAt, "updatedAt unchanged")
        XCTAssertEqual(new.deleted, ["zz": 1_760_000_000_500], "tombstones unchanged")
        XCTAssertEqual(new.v, old.v)
        XCTAssertEqual(new.unknown, old.unknown)
        XCTAssertEqual(new.strokes.count, 5)
        XCTAssertEqual(new.liveStrokeIds, ["a1", "a2", "a3", "a4", "a5"], "ids kept")
        XCTAssertNotEqual(new, old)
        assertMoved("a1", old: old, new: new, xs: [12 + 64 + 2 * colW, 17 + 64 + 2 * colW, 22 + 64 + 2 * colW], ys: [40, 43, 40])
        XCTAssertEqual(new.strokes["a1"]?.points.first?.x ?? 0, 457.7, accuracy: 0.11, "12 + 64 + 2 × 190.857 = 457.714")
        assertMoved("a2", old: old, new: new, xs: [69, 74], ys: [-5, 2])
        assertMoved("a4", old: old, new: new, xs: [64 + 6 * colW], ys: [0], "a day outside the week clamps to column 6")
        assertMoved("a5", old: old, new: new, xs: [65], ys: [1], "a broken key is column 0")
        XCTAssertEqual(new.strokes["a3"], old.strokes["a3"], "a grid stroke is untouched")
        XCTAssertEqual(BandMigration.migrate(new), new, "idempotent")
        let decoded = try InkPageCodec.decode(try InkPageCodec.encode(new))
        XCTAssertEqual(decoded, new, "survives the JSON round trip")
        XCTAssertEqual(BandMigration.migrate(try InkPageCodec.decode(try InkPageCodec.encode(old))), new, "migrating the decoded old page gives the same result")
        XCTAssertFalse(BandMigration.needsMigration(decoded))
    }

    func testSingleStrokes() {
        let old = weekPage()
        let a1 = old.strokes["a1"]!
        XCTAssertNil(BandMigration.migrated(old.strokes["a3"]!, pageId: "w-2026-10-05"), "a grid stroke is not a target")
        XCTAssertNil(BandMigration.migrated(a1, pageId: "m1-2026-10"), "not on a month page")
        XCTAssertNil(BandMigration.migrated(a1, pageId: "y-2026"), "not on a year page")
        XCTAssertNil(BandMigration.migrated(a1, pageId: ""), "not without a page id")
        XCTAssertEqual(BandMigration.migrated(a1, pageId: "w-2026-10-05")?.cell, .grid)
        XCTAssertEqual(BandMigration.migrated(a1, pageId: "w-2026-10-05"), BandMigration.migrate(old).strokes["a1"])
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDay(day(2026, 10, 9)), points: [point(0, 0)]), pageId: "w-2026-10-07")?.points.first?.x ?? -1, 64 + 2 * colW, accuracy: 0.11, "a non-Monday page id: its day is the Monday")
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDay(wed), points: [point(0, 0)]), pageId: "w-xxxx")?.points.first?.x ?? -1, 64, accuracy: 0.11, "a broken week page id → column 0")
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDay(day(2026, 9, 1)), points: [point(0, 0)]), pageId: "w-2026-10-05")?.points.first?.x ?? -1, 64, accuracy: 0.11, "a day before the week → column 0")
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDay(day(2026, 10, 11)), points: [point(0, 0)]), pageId: "w-2026-10-05")?.points.first?.x ?? -1, 64 + 6 * colW, accuracy: 0.11, "Sunday → column 6")
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDayDay, points: [point(3, 4)]), pageId: "w-2026-10-05")?.points.first?.x ?? -1, 67, accuracy: 0.11, "the day key on a week page (broken data) → column 0")
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDay(wed), points: [point(3, 4)]), pageId: "d-2026-10-07")?.points.first?.x, 3, "a week key on a day page (broken data): x unchanged")
        XCTAssertEqual(BandMigration.migrated(stroke("s", cell: .allDayDay, points: [point(3, 4)]), pageId: "d-2026-10-07")?.cell, .grid)
        XCTAssertNil(BandMigration.migrated(stroke("s", cell: .memo), pageId: "d-2026-10-07"), "memo is not a band cell")
        XCTAssertNil(BandMigration.migrated(stroke("s", cell: .yearDay(month: 1, day: 1)), pageId: "w-2026-10-05"))
    }

    func testIsBandCell() {
        XCTAssertTrue(BandMigration.isBandCell(.allDayDay))
        XCTAssertTrue(BandMigration.isBandCell(.allDay(wed)))
        XCTAssertTrue(BandMigration.isBandCell(CellKey(raw: "allday:xx")))
        XCTAssertTrue(BandMigration.isBandCell(CellKey(raw: "allday:")))
        XCTAssertFalse(BandMigration.isBandCell(.grid))
        XCTAssertFalse(BandMigration.isBandCell(.memo))
        XCTAssertFalse(BandMigration.isBandCell(.day(wed)))
        XCTAssertFalse(BandMigration.isBandCell(CellKey(raw: "alldays")), "merely starts with the letters")
        XCTAssertFalse(BandMigration.isBandCell(CellKey(raw: "02-30")))
        XCTAssertFalse(BandMigration.isBandCell(CellKey(raw: "")))
    }

    func testDayPage() {
        let old = dayPage()
        XCTAssertTrue(BandMigration.needsMigration(old))
        let new = BandMigration.migrate(old)
        XCTAssertFalse(BandMigration.needsMigration(new))
        XCTAssertEqual(new.strokes["b1"]?.cell, .grid)
        XCTAssertEqual(new.strokes["b1"]?.points, old.strokes["b1"]?.points, "points unchanged")
        XCTAssertEqual(new.strokes["b1"]?.color, "#2563eb")
        XCTAssertEqual(new.strokes["b2"]?.cell, .grid)
        XCTAssertEqual(new.strokes["b2"]?.points, old.strokes["b2"]?.points, "the negative y is kept (M4B-26)")
        XCTAssertEqual(new.strokes["b2"]?.points.first?.y, -20)
        XCTAssertEqual(new.strokes["b3"], old.strokes["b3"])
        XCTAssertEqual(new.updatedAt, old.updatedAt)
        XCTAssertEqual(new.liveStrokeIds, ["b1", "b2", "b3"])
        XCTAssertEqual(BandMigration.migrate(new), new, "idempotent")
    }

    func testOtherPagesAndNothingToMove() {
        var month = InkPage.empty(pageId: "m1-2026-10")
        month.add(stroke("c1", cell: .allDay(wed), points: [point(1, 2)]))
        XCTAssertFalse(BandMigration.needsMigration(month))
        XCTAssertEqual(BandMigration.migrate(month), month, "a month page is returned as it is")
        XCTAssertEqual(BandMigration.migrate(month).strokes["c1"]?.cell, .allDay(wed))
        var year = InkPage.empty(pageId: "y-2026")
        year.add(stroke("d1", cell: .allDayDay, points: [point(1, 2)]))
        XCTAssertFalse(BandMigration.needsMigration(year))
        XCTAssertEqual(BandMigration.migrate(year), year)
        var clean = InkPage.empty(pageId: "w-2026-10-05")
        clean.add(stroke("g1", cell: .grid))
        clean.unknownStrokes["u1"] = .object(["id": .string("u1"), "cell": .string("allday:2026-10-07"), "tool": .string("crayon"), "pts": .array([.number(1)])])
        XCTAssertFalse(BandMigration.needsMigration(clean))
        XCTAssertEqual(BandMigration.migrate(clean), clean, "nothing to move → the same page")
        XCTAssertEqual(BandMigration.migrate(clean).unknownStrokes, clean.unknownStrokes, "an unknown-tool stroke in a band cell is not touched")
        let dead = InkPage(pageId: "w-2026-10-05", strokes: ["t1": stroke("t1", cell: .allDay(wed))], deleted: ["t1": 5])
        XCTAssertFalse(BandMigration.needsMigration(dead), "a tombstoned band stroke is not live")
        XCTAssertEqual(BandMigration.migrate(dead), dead)
        XCTAssertEqual(BandMigration.migrate(InkPage.empty(pageId: "w-2026-10-05")), InkPage.empty(pageId: "w-2026-10-05"))
        XCTAssertFalse(BandMigration.needsMigration(InkPage.empty(pageId: "d-2026-10-07")))
    }

    func testMergeKeepsTheMovedStrokes() {
        // The merge rule is unchanged (M4B_CONTRACT §3.2): "grid" > "allday…" in `compareStrokes`.
        let old = weekPage()
        let new = BandMigration.migrate(old)
        XCTAssertLessThan(InkPage.compareStrokes(old.strokes["a1"]!, new.strokes["a1"]!), 0, "'a' < 'g'")
        XCTAssertGreaterThan(InkPage.compareStrokes(new.strokes["a1"]!, old.strokes["a1"]!), 0)
        XCTAssertLessThan(InkPage.compareStrokes(old.strokes["a2"]!, new.strokes["a2"]!), 0, "a marker without dev")
        XCTAssertLessThan(InkPage.compareStrokes(old.strokes["a5"]!, new.strokes["a5"]!), 0, "a broken key")
        let dOld = dayPage()
        let dNew = BandMigration.migrate(dOld)
        XCTAssertLessThan(InkPage.compareStrokes(dOld.strokes["b2"]!, dNew.strokes["b2"]!), 0, "same points, only the cell differs: the new form still wins")
        let merged = InkPage.merge(old, new)
        XCTAssertEqual(merged, InkPage.merge(new, old), "commutative")
        XCTAssertEqual(merged, new, "merge(old, new) == new")
        XCTAssertTrue(merged.liveStrokes.allSatisfy { $0.cell == .grid }, "every live stroke is in the new form")
        XCTAssertEqual(merged.liveStrokes.count, 5)
        XCTAssertEqual(InkPage.merge(old, old), old)
        XCTAssertEqual(InkPage.merge(new, new), new)
        XCTAssertEqual(InkPage.merge(dOld, dNew), dNew)
        XCTAssertEqual(InkPage.merge(dNew, dOld), dNew)
        XCTAssertTrue(InkPage.merge(dOld, dNew).liveStrokes.allSatisfy { $0.cell == .grid })
        XCTAssertEqual(InkPage.merge(dOld, dOld), dOld)
        XCTAssertEqual(BandMigration.migrate(merged), merged, "a merged page needs no migration")
        XCTAssertEqual(InkPage.merge(merged, old), new, "a 0.5.0 device's copy of the old form does not come back")
        var erased = new
        erased.remove(ids: ["a1"], at: 1_760_150_500_000)
        XCTAssertNil(InkPage.merge(old, erased).strokes["a1"], "a tombstone on the moved id removes the old form too")
        XCTAssertEqual(InkPage.merge(old, erased).deleted["a1"], 1_760_150_500_000)
    }

    func testExtraIsNotABandCell() {
        // K-1 (1.1, M7A_CONTRACT §1.2): the day page's new cell "extra" never starts with "allday", so
        // no device (1.0 included) moves its strokes onto the grid.
        XCTAssertFalse(BandMigration.isBandCell(.extra))
        XCTAssertFalse("extra".hasPrefix("allday"))
        XCTAssertFalse(CellKey.extra.raw.hasPrefix("allday"))
        let deep = stroke("x1", cell: .extra, points: [point(30, 40), point(60, 5950, dt: 16)])
        XCTAssertNil(BandMigration.migrated(deep, pageId: "d-2026-10-07"))
        var page = InkPage.empty(pageId: "d-2026-10-07")
        page.add(deep)
        page.add(stroke("g1", cell: .grid, points: [point(300, 2350)]))
        XCTAssertFalse(BandMigration.needsMigration(page))
        XCTAssertEqual(BandMigration.migrate(page), page, "a 1.1 day page is left as it is")
    }
}
