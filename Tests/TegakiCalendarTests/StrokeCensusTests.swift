import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// 設定 › 情報 「いちばん線の多いページ」「今年の年のページ」 and the import check (1.1, M7A_CONTRACT
/// §5.2 / §5.3 / §7.2, 0-17): the counts of a store in a temporary folder, read with
/// `InkPageStore.peek(_:)` (before the read cap, never moving or writing a file), the row texts, the
/// cancellation, and the pages an import would take past 20,000 strokes.
@MainActor
final class StrokeCensusTests: XCTestCase {
    private var directory: URL!
    private var store: InkPageStore!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StrokeCensusTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    /// A one-point stroke (small files even for 20,000 strokes).
    private func stroke(_ id: String, cell: CellKey = .grid, t: Int = 1_760_000_001_000) -> InkStroke {
        let point = InkPoint(x: 10, y: 20, dtMs: 0, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.4)
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, points: [point])
    }

    /// A page with `count` strokes "<prefix>00000"… (and `tombstones` more ids tombstoned).
    private func page(_ pageId: String, count: Int, prefix: String = "s", tombstones: Int = 0) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for i in 0..<count {
            page.add(stroke(prefix + String(format: "%05d", i), t: 1_760_000_001_000 + i))
        }
        if tombstones > 0 {
            page.remove(ids: (0..<tombstones).map { String(format: "gone%05d", $0) }, at: 1_760_000_900_000)
        }
        return page
    }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    // MARK: - Tests

    func testLargestPageOfAStore() async throws {
        try store.save(page("m1-2026-10", count: 3, tombstones: 2))
        try store.save(page("d-2026-10-07", count: 5))
        try store.save(page("y-2026", count: 4, tombstones: 7))

        let resultRun = await StrokeCensus.run(store: store, year: 2026)

        let result = try XCTUnwrap(resultRun)
        XCTAssertEqual(result.largest, StrokeBudget.Entry(pageId: "d-2026-10-07", strokes: 5, tombstones: 0))
        XCTAssertEqual(result.year, StrokeBudget.Entry(pageId: "y-2026", strokes: 4, tombstones: 7))
        XCTAssertEqual(result.unreadable, 0)
        XCTAssertEqual(StrokeCensus.rowText(result.largest, counting: false), "日のページ（2026年10月7日）・5 本")
        XCTAssertEqual(StrokeCensus.yearRowText(result.year, year: 2026, counting: false), "年のページ（2026年）・4 本")

        // Another year: no year page of 2027 on this device.
        let otherRun = await StrokeCensus.run(store: store, year: 2027)
        let other = try XCTUnwrap(otherRun)
        XCTAssertNil(other.year)
        XCTAssertEqual(other.largest, result.largest)
        XCTAssertEqual(StrokeCensus.yearRowText(other.year, year: 2027, counting: false), "年のページ（2027年）・0 本")

        // A tie: the smaller pageId wins (StrokeBudget.largest).
        try store.save(page("m1-2026-09", count: 5))
        let tieRun = await StrokeCensus.run(store: store, year: 2026)
        let tie = try XCTUnwrap(tieRun)
        XCTAssertEqual(tie.largest?.pageId, "d-2026-10-07")

        // peek finds what load finds (live ids, tombstones), and counting wrote nothing.
        XCTAssertEqual(store.peek("m1-2026-10"), InkPageStore.Peek(strokeIds: Set(store.load("m1-2026-10").liveStrokeIds), tombstones: 2))
        XCTAssertEqual(try files(), ["d-2026-10-07.json.lzfse", "m1-2026-09.json.lzfse", "m1-2026-10.json.lzfse", "y-2026.json.lzfse"])
    }

    func testEmptyStore() async throws {
        let resultRun = await StrokeCensus.run(store: store, year: 2026)
        let result = try XCTUnwrap(resultRun)
        XCTAssertEqual(result, StrokeCensus.Result(largest: nil, year: nil, unreadable: 0))
        XCTAssertEqual(StrokeCensus.rowText(result.largest, counting: false), "まだ手書きがありません")
        XCTAssertEqual(StrokeCensus.yearRowText(result.year, year: 2026, counting: false), "年のページ（2026年）・0 本")

        // A folder that does not exist yet (nothing was ever saved) is the same.
        let missing = InkPageStore(directory: directory.appendingPathComponent("never", isDirectory: true))
        let noneRun = await StrokeCensus.run(store: missing, year: 2026)
        let none = try XCTUnwrap(noneRun)
        XCTAssertEqual(none, StrokeCensus.Result(largest: nil, year: nil, unreadable: 0))
        XCTAssertNil(missing.peek("m1-2026-10"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.directory.path), "counting creates nothing")

        // Pages with no strokes (only tombstones) are no 「いちばん線の多いページ」.
        try store.save(page("m1-2026-10", count: 0, tombstones: 3))
        let tombsRun = await StrokeCensus.run(store: store, year: 2026)
        let tombs = try XCTUnwrap(tombsRun)
        XCTAssertNil(tombs.largest)
        XCTAssertEqual(store.peek("m1-2026-10"), InkPageStore.Peek(strokeIds: [], tombstones: 3))
    }

    func testRowText() {
        XCTAssertEqual(StrokeCensus.rowText(nil, counting: true), "数えています…")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "m1-2026-10", strokes: 3, tombstones: 0), counting: true), "数えています…", "counting wins")
        XCTAssertEqual(StrokeCensus.rowText(nil, counting: false), "まだ手書きがありません")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "m1-2026-10", strokes: 3, tombstones: 0), counting: false), "月のページ（2026年10月）・3 本")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "w-2026-10-05", strokes: 12_345, tombstones: 9), counting: false), "週のページ（2026年10月5日〜10月11日）・12,345 本")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "d-2026-10-07", strokes: 1, tombstones: 0), counting: false), "日のページ（2026年10月7日）・1 本")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "y-2026", strokes: 20_000, tombstones: 0), counting: false), "年のページ（2026年）・20,000 本", "20,000 is still read whole by 1.0")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "y-2026", strokes: 20_001, tombstones: 0), counting: false), "年のページ（2026年）・20,001 本（古い版の端末では一部が表示されません）")
        // An id `PageNavigation.parse` cannot read is shown as it is.
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "wb-2026-10-05", strokes: 2, tombstones: 0), counting: false), "wb-2026-10-05・2 本")
        XCTAssertEqual(StrokeCensus.countingText, "数えています…")
        XCTAssertEqual(StrokeCensus.noInkText, "まだ手書きがありません")
        XCTAssertEqual(StrokeCensus.legacyNote, "（古い版の端末では一部が表示されません）")
    }

    func testYearRow() async throws {
        XCTAssertEqual(StrokeCensus.yearRowText(nil, year: 2026, counting: true), "数えています…")
        XCTAssertEqual(StrokeCensus.yearRowText(nil, year: 2026, counting: false), "年のページ（2026年）・0 本")
        XCTAssertEqual(StrokeCensus.yearRowText(StrokeBudget.Entry(pageId: "y-2026", strokes: 12, tombstones: 0), year: 2026, counting: false), "年のページ（2026年）・12 本")
        XCTAssertEqual(StrokeCensus.yearRowText(StrokeBudget.Entry(pageId: "y-2026", strokes: 20_500, tombstones: 0), year: 2026, counting: false), "年のページ（2026年）・20,500 本（古い版の端末では一部が表示されません）")
        XCTAssertEqual(StrokeCensus.yearPageId(2026), "y-2026")

        // Without a year page: nil (0 本); with one: its count, whatever the other pages hold.
        try store.save(page("m1-2026-10", count: 9))
        let withoutRun = await StrokeCensus.run(store: store, year: 2026)
        let without = try XCTUnwrap(withoutRun)
        XCTAssertNil(without.year)
        try store.save(page("y-2026", count: 2))
        try store.save(page("y-2025", count: 30))
        let withRun = await StrokeCensus.run(store: store, year: 2026)
        let with = try XCTUnwrap(withRun)
        XCTAssertEqual(with.year, StrokeBudget.Entry(pageId: "y-2026", strokes: 2, tombstones: 0))
        XCTAssertEqual(with.largest?.pageId, "y-2025")
        XCTAssertEqual(StrokeCensus.yearRowText(with.year, year: 2026, counting: false), "年のページ（2026年）・2 本")
    }

    /// 20,500 strokes are counted as 20,500 (the file, not a read capped at 20,000 as 1.0 would), and
    /// the row says that an old device shows only part of the page. Strokes of a tool this version
    /// does not know count too (the budget count, 0-16).
    func testCountsBeforeTheReadCap() async throws {
        var big = page("y-2026", count: 20_500)
        big.unknownStrokes["tape-1"] = .object(["id": .string("tape-1"), "tool": .string("tape"), "cell": .string("10-07"), "pts": .array([])])
        try store.save(big)
        XCTAssertEqual(big.budgetCount, 20_501)

        let peek = try XCTUnwrap(store.peek("y-2026"))
        XCTAssertEqual(peek.strokeIds.count, 20_501)
        XCTAssertTrue(peek.strokeIds.contains("tape-1"))
        XCTAssertEqual(peek.tombstones, 0)

        let resultRun = await StrokeCensus.run(store: store, year: 2026)

        let result = try XCTUnwrap(resultRun)
        XCTAssertEqual(result.largest, StrokeBudget.Entry(pageId: "y-2026", strokes: 20_501, tombstones: 0))
        XCTAssertEqual(result.year, result.largest)
        XCTAssertEqual(StrokeCensus.rowText(result.largest, counting: false), "年のページ（2026年）・20,501 本（古い版の端末では一部が表示されません）")
        XCTAssertEqual(StrokeCensus.yearRowText(result.year, year: 2026, counting: false), "年のページ（2026年）・20,501 本（古い版の端末では一部が表示されません）")

        // A JSON page in the list form of `strokes` (the web version's), written by hand: the ids of
        // the elements, minus the tombstoned ones.
        let list: JSONValue = .object([
            "v": .number(1), "pageId": .string("m1-2026-10"),
            "strokes": .array([.object(["id": .string("a")]), .object(["id": .string("b")]), .object(["id": .string("c")]), .object(["cell": .string("memo")])]),
            "deleted": .object(["b": .number(1), "z": .number(2)]),
        ])
        try InkPageCodec.compress(list.serializedData()).write(to: store.url(for: "m1-2026-10"))
        XCTAssertEqual(store.peek("m1-2026-10"), InkPageStore.Peek(strokeIds: ["a", "c"], tombstones: 2))
    }

    func testPeekDoesNotMoveAnUnreadableFile() async throws {
        try store.save(page("m1-2026-10", count: 2))
        // Not LZFSE at all, and LZFSE of something that is not a JSON object.
        let garbage = Data("this is not a page".utf8)
        try garbage.write(to: store.url(for: "d-2026-10-07"))
        let notAnObject = try InkPageCodec.compress(Data("[1, 2, 3]".utf8))
        try notAnObject.write(to: store.url(for: "w-2026-10-05"))
        let before = try files()

        XCTAssertNil(store.peek("d-2026-10-07"))
        XCTAssertNil(store.peek("w-2026-10-05"))
        XCTAssertNil(store.peek("y-2030"), "no file")
        let resultRun = await StrokeCensus.run(store: store, year: 2026)
        let result = try XCTUnwrap(resultRun)
        XCTAssertEqual(result.unreadable, 2)
        XCTAssertEqual(result.largest, StrokeBudget.Entry(pageId: "m1-2026-10", strokes: 2, tombstones: 0))

        // The files stay where they are, byte for byte, and no `.bak` appears.
        XCTAssertEqual(try files(), before)
        XCTAssertFalse(try files().contains { $0.hasSuffix(".bak") })
        XCTAssertEqual(try Data(contentsOf: store.url(for: "d-2026-10-07")), garbage)
        XCTAssertEqual(try Data(contentsOf: store.url(for: "w-2026-10-05")), notAnObject)
        // (`load` still moves a broken file aside, as before: it is not on the counting path.)
        _ = store.load("d-2026-10-07")
        XCTAssertTrue(try files().contains("d-2026-10-07.json.lzfse.bak"))
    }

    func testCancellationStops() async throws {
        for i in 0..<5 {
            try store.save(page(String(format: "d-2026-10-%02d", i + 1), count: 1 + i))
        }
        // Cancelled before it starts: nil (the sheet closed at once).
        let pages = store!
        let task = Task { () -> StrokeCensus.Result? in
            await StrokeCensus.run(store: pages, year: 2026)
        }
        task.cancel()
        let cancelled = await task.value
        XCTAssertNil(cancelled)

        // Cancelled in the middle of the pages: nil, after asking before every page.
        var asked = 0
        let stopped = StrokeCensus.count(store: store, year: 2026, isCancelled: {
            asked += 1
            return asked > 2
        })
        XCTAssertNil(stopped)
        XCTAssertEqual(asked, 3, "stops at the third page")

        // Not cancelled: every page.
        var all = 0
        let done = StrokeCensus.count(store: store, year: 2026, isCancelled: {
            all += 1
            return false
        })
        XCTAssertEqual(done?.largest, StrokeBudget.Entry(pageId: "d-2026-10-05", strokes: 5, tombstones: 0))
        XCTAssertEqual(all, 6, "once per page and once at the end")
        let finished = await StrokeCensus.run(store: store, year: 2026)
        XCTAssertEqual(finished, done)
    }

    /// The import check (§5.2): the union of the device's ids and the incoming strokes, minus the
    /// incoming tombstones, past 20,000. The same ids imported again are not counted twice.
    func testPagesOverLegacyCap() async throws {
        let id = "y-2026"
        try store.save(page(id, count: 19_990))

        // The same 19,990 again (an import of a file made on this device): 19,990, not over.
        let same = await StrokeCensus.pagesOverLegacyCap([page(id, count: 19_990)], store: store)
        XCTAssertEqual(same, [])
        // 10 new ids: 20,000 exactly, not over. 11 new ids: 20,001, over.
        var ten = page(id, count: 19_990)
        for i in 0..<10 { ten.add(stroke(String(format: "n%05d", i))) }
        XCTAssertEqual(StrokeCensus.overLegacyCap([ten], store: store), [])
        var eleven = ten
        eleven.add(stroke("n00010"))
        XCTAssertEqual(StrokeCensus.overLegacyCap([eleven], store: store), [id])
        // The incoming tombstones of the device's strokes bring it back under.
        var tombstoned = eleven
        tombstoned.remove(ids: ["s00000"], at: 1_760_000_900_000)
        XCTAssertEqual(StrokeCensus.overLegacyCap([tombstoned], store: store), [])

        // A page with no file on this device counts from nothing; several pages keep their order.
        let fresh = page("m1-2026-10", count: 20_001, prefix: "f")
        let small = page("d-2026-10-07", count: 3)
        let pages = await StrokeCensus.pagesOverLegacyCap([eleven, small, fresh], store: store)
        XCTAssertEqual(pages, [id, "m1-2026-10"])
        XCTAssertEqual(pages.map(StrokeBudget.pageLabel), ["年のページ（2026年）", "月のページ（2026年10月）"])

        // Nothing was written: the device's page is unchanged and no file was added.
        XCTAssertEqual(store.peek(id)?.strokeIds.count, 19_990)
        XCTAssertEqual(try files(), ["y-2026.json.lzfse"])
    }
}
