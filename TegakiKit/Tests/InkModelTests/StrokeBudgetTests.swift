import XCTest
import Foundation
import CoreGraphics
import InkModel

/// The stroke budget of one page (1.1, K-9, M7A_CONTRACT D5, §5): the numbers, the count (strokes of
/// an unknown tool included), the import check, the words of 設定 › 情報, and the reader of 1.1 that
/// keeps up to 60,000 strokes (1.0 keeps 20,000).
final class StrokeBudgetTests: XCTestCase {
    private func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5) -> InkPoint {
        InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: 0.5, azimuth: 1.5708, altitude: 0.7854)
    }

    private func stroke(_ id: String, cell: CellKey = CellKey(raw: "03-05")) -> InkStroke {
        InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: 1_790_000_000_000, dev: "ipad-1", points: [point(10, 20), point(30, 40, dt: 16)])
    }

    private func unknownTool(_ id: String, cell: String = "extra") -> JSONValue {
        .object(["id": .string(id), "cell": .string(cell), "tool": .string("tape"), "pts": .array([.number(1), .number(2)])])
    }

    /// A page JSON of `n` pen strokes ("s00000"…) and `u` strokes of an unknown tool ("u00000"…).
    private func bigPageJSON(strokes n: Int, unknown u: Int) -> JSONValue {
        var obj: [String: JSONValue] = [:]
        obj.reserveCapacity(n + u)
        let pts: JSONValue = .array(InkPoint.flat([point(10, 20)]).map { .number($0) })
        for i in 0..<n {
            let id = String(format: "s%05d", i)
            obj[id] = .object(["id": .string(id), "cell": .string("03-05"), "tool": .string("pen"), "color": .string("#1f2937"), "t": .number(1_790_000_000_000), "pts": pts])
        }
        for i in 0..<u {
            let id = String(format: "u%05d", i)
            obj[id] = .object(["id": .string(id), "cell": .string("03-05"), "tool": .string("tape"), "pts": pts])
        }
        return .object(["v": .number(1), "pageId": .string("y-2026"), "strokes": .object(obj), "deleted": .object([:]), "updatedAt": .number(1_790_000_000_000)])
    }

    func testBudgetCountIncludesUnknownTools() {
        XCTAssertEqual(StrokeBudget.noticeAt, 15_000)
        XCTAssertEqual(StrokeBudget.refuseAt, 19_000)
        XCTAssertEqual(StrokeBudget.legacyReadCap, 20_000)
        XCTAssertEqual(StrokeBudget.readCap, 60_000)
        XCTAssertEqual(StrokeBudget.readCap, InkPage.maxStrokes)
        XCTAssertEqual(InkPage.maxTombstones, 200_000, "unchanged")
        XCTAssertEqual(WebImport.maxStrokesPerPage, 20_000, "the web import keeps 20,000")

        var page = InkPage.empty(pageId: "d-2026-10-07")
        for i in 0..<3 { page.add(stroke("live-\(i)", cell: .grid)) }
        page.add(stroke("gone", cell: .grid))
        page.remove(ids: ["gone"], at: 1_790_000_000_500)
        page.unknownStrokes["tape-1"] = unknownTool("tape-1")
        page.unknownStrokes["tape-2"] = unknownTool("tape-2", cell: "grid")
        XCTAssertEqual(page.liveStrokeCount, 3, "liveStrokeCount does not count the unknown tool")
        XCTAssertEqual(page.budgetCount, 5, "live + unknown tool (0-16)")
        let reread = InkPage(json: page.jsonValue)
        XCTAssertEqual(reread.unknownStrokes.count, 2)
        XCTAssertEqual(reread.budgetCount, 5, "the same after a round trip")
        XCTAssertEqual(InkPage.empty(pageId: "y-2026").budgetCount, 0)
        page.remove(ids: ["tape-1"], at: 1_790_000_000_600)
        XCTAssertEqual(page.budgetCount, 4, "a tombstoned unknown stroke no longer counts")
    }

    func testAcceptedAndNotice() {
        XCTAssertEqual(StrokeBudget.accepted(incoming: 1, count: 18_999), 1)
        XCTAssertEqual(StrokeBudget.accepted(incoming: 1, count: 19_000), 0)
        XCTAssertEqual(StrokeBudget.accepted(incoming: 1, count: 19_001), 0)
        XCTAssertEqual(StrokeBudget.accepted(incoming: 2, count: 18_999), 1, "only up to 19,000")
        XCTAssertEqual(StrokeBudget.accepted(incoming: 5, count: 18_995), 5)
        XCTAssertEqual(StrokeBudget.accepted(incoming: 3, count: 0), 3)
        XCTAssertEqual(StrokeBudget.accepted(incoming: 0, count: 25_000), 0)
        XCTAssertEqual(StrokeBudget.accepted(incoming: 4, count: 25_000), 0, "a page already over the budget (from elsewhere)")
        XCTAssertEqual(StrokeBudget.accepted(incoming: -1, count: 0), 0)
        XCTAssertTrue(StrokeBudget.crossesNotice(from: 14_999, to: 15_000))
        XCTAssertTrue(StrokeBudget.crossesNotice(from: 10, to: 20_000))
        XCTAssertFalse(StrokeBudget.crossesNotice(from: 15_000, to: 15_001), "already over")
        XCTAssertFalse(StrokeBudget.crossesNotice(from: 14_999, to: 14_999))
        XCTAssertFalse(StrokeBudget.crossesNotice(from: 15_000, to: 15_000))
        XCTAssertFalse(StrokeBudget.crossesNotice(from: 16_000, to: 14_000), "going down")
        XCTAssertEqual(StrokeBudget.Event.many(15_000), .many(15_000))
        XCTAssertNotEqual(StrokeBudget.Event.many(19_000), .full(19_000))
    }

    func testLargestAndLabels() {
        let entries = [StrokeBudget.Entry(pageId: "m1-2026-10", strokes: 3, tombstones: 1),
                       StrokeBudget.Entry(pageId: "y-2026", strokes: 5, tombstones: 0),
                       StrokeBudget.Entry(pageId: "d-2026-10-07", strokes: 5, tombstones: 2)]
        XCTAssertEqual(StrokeBudget.largest(entries), entries[2], "a tie → the smaller pageId")
        XCTAssertEqual(StrokeBudget.largest(entries.reversed()), entries[2], "the order does not matter")
        XCTAssertEqual(StrokeBudget.largest([entries[0]]), entries[0])
        XCTAssertNil(StrokeBudget.largest([]))
        XCTAssertNil(StrokeBudget.largest([StrokeBudget.Entry(pageId: "y-2026", strokes: 0, tombstones: 9)]), "every page 0 → nil")
        XCTAssertEqual(StrokeBudget.pageLabel("y-2026"), "年のページ（2026年）")
        XCTAssertEqual(StrokeBudget.pageLabel("m1-2026-10"), "月のページ（2026年10月）")
        XCTAssertEqual(StrokeBudget.pageLabel("w-2026-10-05"), "週のページ（2026年10月5日〜10月11日）")
        XCTAssertEqual(StrokeBudget.pageLabel("w-2026-12-28"), "週のページ（2026年12月28日〜2027年1月3日）", "the header's week title")
        XCTAssertEqual(StrokeBudget.pageLabel("d-2026-10-07"), "日のページ（2026年10月7日）", "no weekday")
        XCTAssertEqual(StrokeBudget.pageLabel("d-2026-11-03"), "日のページ（2026年11月3日）", "no holiday name")
        XCTAssertEqual(StrokeBudget.pageLabel("wb-2026-10-05"), "wb-2026-10-05", "an id it cannot read stays as it is")
        XCTAssertEqual(StrokeBudget.pageLabel("d-2026-02-30"), "d-2026-02-30")
        XCTAssertEqual(StrokeBudget.pageLabel(""), "")
        XCTAssertEqual(StrokeBudget.countText(0), "0 本")
        XCTAssertEqual(StrokeBudget.countText(3), "3 本")
        XCTAssertEqual(StrokeBudget.countText(999), "999 本")
        XCTAssertEqual(StrokeBudget.countText(1_000), "1,000 本")
        XCTAssertEqual(StrokeBudget.countText(12_345), "12,345 本")
        XCTAssertEqual(StrokeBudget.countText(20_500), "20,500 本")
        XCTAssertEqual(StrokeBudget.countText(1_234_567), "1,234,567 本")
        XCTAssertEqual(StrokeBudget.countText(-1_234), "-1,234 本")
    }

    func testNewReaderKeepsMoreThan20000() {
        // 1.0 read at most 20,000 (strokes + unknown tools); 1.1 reads 60,000 (§5.1).
        let p20500 = InkPage(json: bigPageJSON(strokes: 20_300, unknown: 200))
        XCTAssertEqual(p20500.strokes.count, 20_300)
        XCTAssertEqual(p20500.unknownStrokes.count, 200)
        XCTAssertEqual(p20500.budgetCount, 20_500, "20,500 → 20,500")
        XCTAssertTrue(p20500.deleted.isEmpty)
        XCTAssertEqual(InkPage(json: p20500.jsonValue), p20500, "written back and read again: nothing lost")
        let p60001 = InkPage(json: bigPageJSON(strokes: 60_001, unknown: 0))
        XCTAssertEqual(p60001.strokes.count, 60_000, "60,001 → 60,000")
        XCTAssertNil(p60001.strokes["s60000"], "the last key in key order is the one left out")
        XCTAssertNotNil(p60001.strokes["s00000"])
        XCTAssertNotNil(p60001.strokes["s59999"])
        XCTAssertTrue(p60001.deleted.isEmpty, "the cap makes no tombstone")
        let mixed = InkPage(json: bigPageJSON(strokes: 59_995, unknown: 10))
        XCTAssertEqual(mixed.budgetCount, 60_000, "strokes and unknown tools share the cap")
        XCTAssertEqual(mixed.strokes.count, 59_995)
        XCTAssertEqual(mixed.unknownStrokes.count, 5)
    }

    func testImportExceedsLegacyCap() {
        let local = Set((0..<19_990).map { "a\($0)" })
        var incoming = InkPage.empty(pageId: "y-2026")
        for i in 0..<10 { incoming.add(stroke("n\(i)")) }
        XCTAssertNil(StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: incoming), "19,990 + 10 = 20,000")
        incoming.add(stroke("n10"))
        XCTAssertEqual(StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: incoming), 20_001, "19,990 + 11")
        var same = InkPage.empty(pageId: "y-2026")
        for i in 0..<40 { same.add(stroke("a\(i)")) }
        XCTAssertNil(StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: same), "the same ids count once")
        var withTombstone = incoming
        withTombstone.remove(ids: ["a0"], at: 1_790_000_000_000)
        XCTAssertNil(StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: withTombstone), "the import's tombstone takes a local stroke away")
        var tombstoneElsewhere = incoming
        tombstoneElsewhere.remove(ids: ["not-here"], at: 1_790_000_000_000)
        XCTAssertEqual(StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: tombstoneElsewhere), 20_001, "a tombstone of an id nobody has changes nothing")
        var withUnknown = incoming
        withUnknown.unknownStrokes["tape-9"] = unknownTool("tape-9")
        XCTAssertEqual(StrokeBudget.importExceedsLegacyCap(localIds: local, incoming: withUnknown), 20_002, "unknown-tool strokes count")
        XCTAssertNil(StrokeBudget.importExceedsLegacyCap(localIds: [], incoming: .empty(pageId: "y-2026")))
        let alone = InkPage(json: bigPageJSON(strokes: 20_300, unknown: 200))
        XCTAssertEqual(StrokeBudget.importExceedsLegacyCap(localIds: [], incoming: alone), 20_500, "a new page over the cap")
    }
}
