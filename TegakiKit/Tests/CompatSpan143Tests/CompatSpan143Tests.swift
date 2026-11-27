import XCTest
import Foundation
import CoreGraphics
import CryptoKit
import Compat10
import InkModel
import Layout

/// K-7 for 1.4.3 (docs/R1_4_3_CONTRACT.md §8.3, 0g-30): the compat-span-143 fixtures (TegakiKit/Tests/Fixtures/compat-span-143,
/// the month and the year joined sideways, written by the joined path of the Kit) read through the frozen 1.0 copy (Compat10)
/// and through today's InkModel. The shape of CompatSpanTests (1.3's compat-span, frozen in TESTS_1_3), in a target of its
/// own; it does not import CompatSpan143Fixtures (the code that makes the files). What it pins, written out by hand from the
/// committed files: the MANIFEST rows, each file's SHA-256 (any byte of a file fails here), and per file the stroke ids,
/// cells, point counts and x ranges, tombstones, `updatedAt` and what 1.0 draws; the y and t of each point and the colours
/// are compared between the 1.0 copy and today's InkModel reading the same bytes, so the hash table is their pin. A fixture
/// made again on purpose changes this table and tools/span/FIXTURES_1_4_3.sha256 in the same commit, with its reason in
/// docs/R1_4_3.md; KitChecks compares the files with what the Kit's maker writes, which is not independent of them.
///
/// The real old Kits (1.0, <1.1.1>, 1.2.3, 1.3) read the same files in tools/span-compat (CI's compat-v1.0 job, the step for
/// compat-span-143), the real 1.0 also through tools/compat10's RunReal and Real10LedgerTests (the Monday files, copied into
/// compat11's folder), and the 1.2.3 and 1.3 apps' ledgers in tools/span-compat/AppTests.
///
/// 8. `m1-2026-11`'s memo line reaching left into October (x −160…260). 9. The lasso's move from `m1-2026-10`'s 2026-11-01
/// to `m1-2026-11`'s 2026-11-01 (a tombstone, a copy with a new id). 10. `y-2027`'s 01-20 centred on its date column (x
/// −128…70) and `y-2026`'s 12-10 reaching past the right edge. 11. A Sunday-start month's memo line reaching right (shape
/// sunday). 12. `y-2026`'s 06-15 written 350 lu down a row the window lengthened. 13. `m1-2026-11`'s 2026-12-03 written
/// 600 lu down the last row form ア lengthened. 12 and 13: laid out from the page's own ink, as every version before 1.4.3
/// lays a page out (no floors), the row grows to the ink's bottom + 12 and holds the line.
final class CompatSpan143Tests: XCTestCase {
    // MARK: - The folder and its MANIFEST

    /// TegakiKit/Tests/Fixtures/compat-span-143 of this checkout (found from this file, no bundle resources).
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // CompatSpan143Tests/
        .deletingLastPathComponent()   // Tests/
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("compat-span-143", isDirectory: true)

    private struct Row: Equatable, CustomStringConvertible {
        let file: String
        let fixture: Int
        let shape: String
        var description: String { "\(file) \(fixture) \(shape)" }
    }

    /// The MANIFEST's rows as committed (1.4.3, D1a): fixtures 8–13, in its order.
    private static let manifest: [Row] = [
        Row(file: "m1-2026-11.memo-left.json", fixture: 8, shape: "monday"),
        Row(file: "m1-2026-10.move-source.json", fixture: 9, shape: "monday"),
        Row(file: "m1-2026-11.move-destination.json", fixture: 9, shape: "monday"),
        Row(file: "y-2026.december-right.json", fixture: 10, shape: "monday"),
        Row(file: "y-2027.date-column.json", fixture: 10, shape: "monday"),
        Row(file: "m1-2026-11.memo-sunday.json", fixture: 11, shape: "sunday"),
        Row(file: "y-2026.row-floor.json", fixture: 12, shape: "monday"),
        Row(file: "m1-2026-11.last-row.json", fixture: 13, shape: "monday"),
    ]

    /// Each committed file's SHA-256 (lower-case hex, as `shasum -a 256` prints it; the same as tools/span/FIXTURES_1_4_3.sha256).
    private static let sha256: [String: String] = [
        "m1-2026-10.move-source.json": "8206cf172924f92d05ff21898f84fd5da2c26498100f8f36ce97d3065c84ed5d",
        "m1-2026-11.last-row.json": "9cd76c59df6eb3f29e782eee245966bea5469e9d9d32b2e1782741d66b468a8e",
        "m1-2026-11.memo-left.json": "c0f95ffc3fd768440fa361b0f65d6dd6fd231fe9b57eaa8023e6d5463fde47f1",
        "m1-2026-11.memo-sunday.json": "bba7a1fe8ebeb50ef4b90b5323164067daf1f8fe8239114b945b67d7692233a6",
        "m1-2026-11.move-destination.json": "10f39b9db1b5579e357f830806a53d5c7560cd4c7fe5f46a29b7358cd1674ff0",
        "y-2026.december-right.json": "26c9cff504e5db7fb50217bacb99792348309f1ac03a194693b3587e0a0ce31d",
        "y-2026.row-floor.json": "f64b3c5087d8b82a87ae6b97256cceff27338695fa34d3565d930533f625fee6",
        "y-2027.date-column.json": "00d474d7009a33db4e81a3731fb89c03a75800b7a497e1536680a75007317cea",
    ]

    /// SHA-256 of `bytes` as lower-case hex.
    private static func hex(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private func data(_ file: String) throws -> Data {
        try Data(contentsOf: Self.folder.appendingPathComponent(file))
    }

    /// The MANIFEST's rows (comment and empty lines skipped). A malformed line fails the test.
    private func manifestRows() throws -> [Row] {
        let text = try XCTUnwrap(String(data: try data("MANIFEST"), encoding: .utf8), "MANIFEST is UTF-8")
        var rows: [Row] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) where !line.hasPrefix("#") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: false)
            XCTAssertEqual(parts.count, 3, "MANIFEST line \"\(line)\": <file> <fixture> <shape>")
            guard parts.count == 3, let n = Int(parts[1]) else { continue }
            rows.append(Row(file: String(parts[0]), fixture: n, shape: String(parts[2])))
        }
        return rows
    }

    // MARK: - What each file holds (written out from the committed files)

    private struct Stroke {
        let id: String
        let cell: String
        let minX: CGFloat
        let maxX: CGFloat
        let points: Int
    }

    private struct Expected {
        let file: String
        let pageId: String
        let updatedAt: Int
        /// Live strokes, sorted by id.
        let live: [Stroke]
        let tombstones: [String: Int]
        /// What 1.0 draws (and its lasso reaches): the live strokes of the cells its layout has.
        let drawnBy10: [String]
    }

    private static let memoLeftId = "c2e7a630-adac-4690-84ed-1b25b8474647"
    private static let movedId = "0acc747c-3719-43ad-8024-84d0c29fb12a"
    private static let keptId = "8c58962a-64b8-4e9b-944f-f6f66086d784"
    private static let copyId = "c835dbde-d886-40ca-a04e-d17bccf81c0d"
    private static let decemberId = "b41c308d-c13a-45c7-9401-90877b672839"
    private static let dateColumnId = "39775398-9ed2-4c56-9087-c19ae6777a7c"
    private static let memoSundayId = "815c21e4-283f-4973-964b-14688fa99f99"
    private static let rowFloorId = "a9adb701-8bf9-421c-bb49-f1eca76a44b6"
    private static let lastRowId = "f192854d-1565-4f39-810d-44ba509c69d3"

    private static let memo: [Expected] = [
        // 8. A memo line of November reaching left into October (its centre on November's paper).
        Expected(file: "m1-2026-11.memo-left.json", pageId: "m1-2026-11", updatedAt: 1_791_430_000_800,
                 live: [Stroke(id: memoLeftId, cell: "memo", minX: -160, maxX: 260, points: 9)], tombstones: [:], drawnBy10: [memoLeftId]),
        // 11. A Sunday-start window's memo line of November reaching right into December.
        Expected(file: "m1-2026-11.memo-sunday.json", pageId: "m1-2026-11", updatedAt: 1_791_430_001_100,
                 live: [Stroke(id: memoSundayId, cell: "memo", minX: 1100, maxX: 1600, points: 9)], tombstones: [:], drawnBy10: [memoSundayId]),
    ]

    private static let move: [Expected] = [
        // 9. The source: the stroke left behind, and the moved one's tombstone at the move's time.
        Expected(file: "m1-2026-10.move-source.json", pageId: "m1-2026-10", updatedAt: 1_791_430_000_950,
                 live: [Stroke(id: keptId, cell: "2026-11-01", minX: 30, maxX: 170, points: 6)],
                 tombstones: [movedId: 1_791_430_000_950], drawnBy10: [keptId]),
        // 9. The destination: the copy with a new id, in the cell of the same name (K-2).
        Expected(file: "m1-2026-11.move-destination.json", pageId: "m1-2026-11", updatedAt: 1_791_430_000_950,
                 live: [Stroke(id: copyId, cell: "2026-11-01", minX: 30, maxX: 170, points: 6)], tombstones: [:], drawnBy10: [copyId]),
    ]

    private static let year: [Expected] = [
        // 10. December of 2026 to the right (past the page's right edge).
        Expected(file: "y-2026.december-right.json", pageId: "y-2026", updatedAt: 1_791_430_001_001,
                 live: [Stroke(id: decemberId, cell: "12-10", minX: -88, maxX: 232, points: 9)], tombstones: [:], drawnBy10: [decemberId]),
        // 10. Centred on 2027's date column: its January, x negative.
        Expected(file: "y-2027.date-column.json", pageId: "y-2027", updatedAt: 1_791_430_001_000,
                 live: [Stroke(id: dateColumnId, cell: "01-20", minX: -128, maxX: 70, points: 7)], tombstones: [:], drawnBy10: [dateColumnId]),
    ]

    private static let rows: [Expected] = [
        // 12. Deep in a year row the window lengthened.
        Expected(file: "y-2026.row-floor.json", pageId: "y-2026", updatedAt: 1_791_430_001_200,
                 live: [Stroke(id: rowFloorId, cell: "06-15", minX: 30, maxX: 90, points: 5)], tombstones: [:], drawnBy10: [rowFloorId]),
        // 13. Deep in the month's lengthened last row.
        Expected(file: "m1-2026-11.last-row.json", pageId: "m1-2026-11", updatedAt: 1_791_430_001_300,
                 live: [Stroke(id: lastRowId, cell: "2026-12-03", minX: 30, maxX: 170, points: 6)], tombstones: [:], drawnBy10: [lastRowId]),
    ]

    /// A time after every time in the fixtures (1.0's own edits below).
    private static let later = 1_792_000_000_000

    private static let tokyo: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// The page laid out as every version before 1.4.3 lays it out (no event, the page's own ink, no floor).
    private func ownInkLayout(_ page: InkPage, weekStart: WeekStart = .monday) throws -> any PageLayout {
        let parsed = try XCTUnwrap(PageNavigation.parse(pageId: page.pageId), page.pageId)
        switch parsed.kind {
        case .month:
            return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: parsed.focus.year, month: parsed.focus.month), events: [],
                                                             inkBottoms: page.inkBottoms(), now: Self.now, calendar: Self.tokyo, weekStart: weekStart))
        case .year:
            return YearLayoutEngine.layout(YearLayoutInput(year: parsed.focus.year, events: [], inkBottoms: page.inkBottoms(), now: Self.now, calendar: Self.tokyo))
        case .day, .week:
            XCTFail("\(page.pageId): compat-span-143 holds months and years only")
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    /// The stroke's bounds (± half the nib) in the paper of `layout`.
    private func bounds(_ s: InkStroke, _ layout: any PageLayout) throws -> CGRect {
        let cell = try XCTUnwrap(layout.cells[s.cell], "\(layout.pageId) has \(s.cell.raw)")
        return try XCTUnwrap(s.paperBounds(cellOrigin: cell.origin), s.id)
    }

    // MARK: - The checks of one file

    /// The file read by the frozen 1.0 copy and by today's InkModel: what it holds, the bytes each writes back, what 1.0
    /// draws and lassoes, and that 1.0's migration, merge, erase and own edit leave the rest alone.
    private func checkFile(_ e: Expected, file: StaticString = #filePath, line: UInt = #line) throws {
        let bytes = try data(e.file)
        let old = try InkPageCodecV10.decode(bytes)
        let new = try InkPageCodec.decode(bytes)
        let name = e.file

        // What the file holds, on both sides.
        XCTAssertEqual(old.pageId, e.pageId, name, file: file, line: line)
        XCTAssertEqual(new.pageId, e.pageId, name, file: file, line: line)
        XCTAssertEqual(old.updatedAt, e.updatedAt, name, file: file, line: line)
        XCTAssertEqual(new.updatedAt, e.updatedAt, name, file: file, line: line)
        XCTAssertEqual(old.v, 1, name, file: file, line: line)
        XCTAssertTrue(old.unknown.isEmpty && new.unknown.isEmpty, "\(name): no new top-level item (K-5)", file: file, line: line)
        XCTAssertTrue(old.unknownStrokes.isEmpty && new.unknownStrokes.isEmpty, "\(name): no item of an unknown tool", file: file, line: line)
        let oldLive = old.liveStrokes.sorted { $0.id < $1.id }
        let newLive = new.liveStrokes.sorted { $0.id < $1.id }
        XCTAssertEqual(oldLive.map(\.id), e.live.map(\.id), "\(name): the live strokes on 1.0", file: file, line: line)
        XCTAssertEqual(newLive.map(\.id), e.live.map(\.id), "\(name): the live strokes today", file: file, line: line)
        for (s, want) in zip(oldLive, e.live) {
            XCTAssertEqual(s.cell.raw, want.cell, "\(name) \(s.id): cell on 1.0", file: file, line: line)
            XCTAssertEqual(s.points.count, want.points, "\(name) \(s.id): no point dropped on 1.0", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).min(), want.minX, "\(name) \(s.id): left end on 1.0 (not cut)", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).max(), want.maxX, "\(name) \(s.id): right end on 1.0 (not cut)", file: file, line: line)
        }
        for (s, want) in zip(newLive, e.live) {
            XCTAssertEqual(s.cell.raw, want.cell, "\(name) \(s.id): cell today", file: file, line: line)
            XCTAssertEqual(s.points.count, want.points, "\(name) \(s.id): no point dropped today", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).min(), want.minX, "\(name) \(s.id): left end today", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).max(), want.maxX, "\(name) \(s.id): right end today", file: file, line: line)
            XCTAssertEqual(s.dev, "fixture-1.4.3", "\(name) \(s.id): written by the joined path's session", file: file, line: line)
        }
        for (a, b) in zip(oldLive, newLive) {
            XCTAssertEqual(a.points.map(\.x), b.points.map(\.x), "\(name) \(a.id): the same x on both", file: file, line: line)
            XCTAssertEqual(a.points.map(\.y), b.points.map(\.y), "\(name) \(a.id): the same y on both", file: file, line: line)
            XCTAssertEqual(a.t, b.t, name, file: file, line: line)
        }
        XCTAssertEqual(old.deleted, e.tombstones, "\(name): tombstones on 1.0", file: file, line: line)
        XCTAssertEqual(new.deleted, e.tombstones, "\(name): tombstones today", file: file, line: line)

        // The bytes each side writes back.
        XCTAssertEqual(try InkPageCodecV10.encode(old), bytes, "\(name): 1.0 writes back the same bytes", file: file, line: line)
        XCTAssertEqual(try InkPageCodec.encode(new), bytes, "\(name): today's Kit writes back the same bytes", file: file, line: line)
        XCTAssertEqual(try InkPageCodecV10.decode(InkPageCodecV10.decompress(InkPageCodecV10.compress(bytes))), old,
                       "\(name): the stored (compressed) form on 1.0", file: file, line: line)

        // What 1.0 draws and its lasso reaches: the strokes of its own cells, overhanging or not.
        let cells = cellsV10(pageId: e.pageId)
        let drawn = LedgerV10.drawnIds(page: old, cells: cells)
        XCTAssertEqual(drawn.sorted(), e.drawnBy10, "\(name): what 1.0 draws", file: file, line: line)
        XCTAssertEqual(LedgerV10.lassoCandidates(page: old, cells: cells).sorted(), e.drawnBy10, "\(name): 1.0's lasso", file: file, line: line)

        // Opening it on 1.0 moves nothing and saves nothing; merging with itself changes nothing.
        XCTAssertEqual(BandMigrationV10.migrate(old), old, name, file: file, line: line)
        XCTAssertFalse(LedgerV10.displayWouldSave(loaded: old), name, file: file, line: line)
        XCTAssertEqual(InkPageV10.merge(old, old), old, name, file: file, line: line)
        XCTAssertEqual(BandMigration.migrate(new), new, name, file: file, line: line)
        XCTAssertEqual(InkPage.merge(new, new), new, name, file: file, line: line)

        // 1.0 erases everything it draws: the other strokes stay byte for byte.
        let raw = old.jsonValue["strokes"]?.objectValue ?? [:]
        var erased = old
        erased.remove(ids: drawn, at: Self.later)
        let after = erased.jsonValue["strokes"]?.objectValue ?? [:]
        XCTAssertEqual(Set(after.keys), Set(raw.keys).subtracting(drawn), "\(name): 1.0's erase takes only what it draws", file: file, line: line)
        for (id, json) in after {
            XCTAssertEqual(json.serialized(), raw[id]?.serialized(), "\(name) \(id): kept byte for byte by 1.0's erase", file: file, line: line)
        }
        XCTAssertEqual(Set(erased.deleted.keys), Set(e.tombstones.keys).union(drawn), name, file: file, line: line)

        // A stroke 1.0 writes on another device into a cell of its own, merged both ways: nothing else changes.
        var other = InkPageV10.empty(pageId: e.pageId)
        let cell: CellKeyV10 = e.pageId.hasPrefix("m1-") ? .memo : .yearDay(month: 1, day: 1)
        XCTAssertTrue(cells.contains(cell), name, file: file, line: line)
        other.add(InkStrokeV10(id: "from-1.0", cell: cell, tool: .pen, color: "#1f2937", t: Self.later, dev: "ipad-10",
                               points: [InkPointV10(x: 40, y: 40, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5)]))
        for merged in [InkPageV10.merge(other, old), InkPageV10.merge(old, other)] {
            XCTAssertEqual(merged.liveStrokeIds.sorted(), (e.live.map(\.id) + ["from-1.0"]).sorted(), name, file: file, line: line)
            XCTAssertEqual(merged.deleted, e.tombstones, name, file: file, line: line)
            let mergedRaw = merged.jsonValue["strokes"]?.objectValue ?? [:]
            for (id, json) in raw {
                XCTAssertEqual(mergedRaw[id]?.serialized(), json.serialized(), "\(name) \(id): unchanged by 1.0's merge", file: file, line: line)
            }
        }

        // Today's save and transfer doors leave the file as it is (no window name in it).
        XCTAssertEqual(SpanGuard.checkForSave(new), .ok, name, file: file, line: line)
        XCTAssertTrue(SpanGuard.checkForTransfer(new), name, file: file, line: line)
    }

    /// The app export of `pages` written by today's Kit, read by 1.0 (the same pages, the same bytes written back) and
    /// imported again.
    private func checkExport(_ expected: [Expected], file: StaticString = #filePath, line: UInt = #line) throws {
        let pages = try expected.map { try InkPageCodec.decode(try data($0.file)) }
        let document = AppExport.Document(exportedAt: "2026-11-28T09:00:00+09:00", app: "ios/1.4.3 (0)", pages: pages)
        let bytes = AppExport.encode(document)
        let read = try AppExportV10.parse(json: JSONValueV10.parse(bytes))
        XCTAssertEqual(read.pages.map(\.pageId), expected.map(\.pageId), file: file, line: line)
        XCTAssertEqual(read.pages, try expected.map { try InkPageCodecV10.decode(try data($0.file)) }, "1.0 reads the export's pages whole", file: file, line: line)
        XCTAssertEqual(AppExportV10.encode(AppExportV10.Document(exportedAt: read.exportedAt, app: read.app, pages: read.pages)), bytes,
                       "1.0 writes the export back byte for byte", file: file, line: line)
        guard case .app(let imported, let skipped) = try InkImport.parse(bytes) else {
            return XCTFail("the export imports as an app export", file: file, line: line)
        }
        XCTAssertEqual(skipped, 0, file: file, line: line)
        XCTAssertEqual(imported.pages, pages, "today's Kit imports the same pages", file: file, line: line)
    }

    // MARK: - The tests

    /// MANIFEST ⇄ folder both ways, the hashes, the Monday rows (CI copies them into compat11's folder for the real 1.0) and
    /// the one Sunday row (read here, by KitChecks and by tools/span-compat).
    func testEveryCompatSpan143FixtureIsPresent() throws {
        let rows = try manifestRows()
        XCTAssertEqual(rows, Self.manifest, "MANIFEST lists the 8 files of fixtures 8–13")
        let all = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
        let onDisk = all.filter { $0.hasSuffix(".json") }.sorted()
        XCTAssertEqual(onDisk, rows.map(\.file).sorted(), "every *.json of the folder is in MANIFEST, and every row's file is there")
        XCTAssertEqual(Set(all).subtracting(onDisk), ["MANIFEST"], "the folder holds MANIFEST and the fixtures only")
        XCTAssertEqual(Self.sha256.keys.sorted(), rows.map(\.file).sorted(), "every MANIFEST row has its SHA-256 in `sha256`")
        for row in rows {
            let bytes = try data(row.file)
            XCTAssertFalse(bytes.isEmpty, row.file)
            XCTAssertTrue(row.file.hasPrefix(try InkPageCodec.decode(bytes).pageId + "."), "\(row.file) holds the page its name says")
            XCTAssertEqual(Self.hex(bytes), Self.sha256[row.file], "\(row.file): the committed bytes (a fixture made again changes `sha256` in the same commit)")
        }
        XCTAssertEqual(Set(rows.map(\.fixture)), [8, 9, 10, 11, 12, 13])
        XCTAssertEqual(rows.filter { $0.shape == "sunday" }.map(\.file), ["m1-2026-11.memo-sunday.json"], "one Sunday row: the Sunday-start month")
        XCTAssertEqual(rows.filter { $0.shape == "monday" }.count, 7, "7 Monday rows (the files CI copies into the compat11 folder)")
        for row in rows {
            let pageId = try InkPageCodec.decode(try data(row.file)).pageId
            XCTAssertTrue(pageId.hasPrefix("m1-") || pageId.hasPrefix("y-"), "\(row.file): a month or a year page")
            if pageId.hasPrefix("y-") { XCTAssertEqual(row.shape, "monday", "\(row.file): a year has no week start") }
        }
        // Every row has its expectations below (a new row fails here until they are written).
        let covered = (Self.memo + Self.move + Self.year + Self.rows).map(\.file)
        XCTAssertEqual(covered.sorted(), rows.map(\.file).sorted(), "every MANIFEST row is checked by one of the tests below")
        try checkExport(Self.memo + Self.move + Self.year + Self.rows)
    }

    /// Fixtures 8 and 11: the month memo across a boundary. The owner is the page of the centre's x; the points reach into
    /// the neighbour's paper (x < 0 or > 1,400 of the memo) and nothing is cut or moved on 1.0. The month's id and its memo
    /// are the same under both week starts (K-11), so the Sunday window's line is read by every version's month.
    func testMonthMemoAcrossTheBoundarySurvives() throws {
        for e in Self.memo {
            try checkFile(e)
        }
        let left = try InkPageCodec.decode(try data("m1-2026-11.memo-left.json"))
        let sunday = try InkPageCodec.decode(try data("m1-2026-11.memo-sunday.json"))
        let monday = try ownInkLayout(left)
        let leftBounds = try bounds(try XCTUnwrap(left.strokes[Self.memoLeftId]), monday)
        XCTAssertLessThan(leftBounds.minX, 0, "8 reaches left into October's paper")
        XCTAssertTrue(leftBounds.midX >= 0 && leftBounds.midX < 1400, "8 is centred on November's paper (\(leftBounds))")
        XCTAssertEqual(monday.inkCell(forCenter: CGPoint(x: leftBounds.midX, y: leftBounds.midY)), .memo)
        let sundayLayout = try ownInkLayout(sunday, weekStart: .sunday)
        XCTAssertEqual(sundayLayout.pageId, "m1-2026-11", "the Sunday start opens the same page")
        let sundayBounds = try bounds(try XCTUnwrap(sunday.strokes[Self.memoSundayId]), sundayLayout)
        XCTAssertGreaterThan(sundayBounds.maxX, 1400, "11 reaches right into December's paper")
        XCTAssertTrue(sundayBounds.midX >= 0 && sundayBounds.midX < 1400, "11 is centred on November's paper (\(sundayBounds))")
        // The memo is the same rectangle under both starts (always 6 rows of 42 days); the grids are not.
        let mondayOfSunday = try ownInkLayout(sunday, weekStart: .monday)
        XCTAssertEqual(sundayLayout.cells[.memo], mondayOfSunday.cells[.memo])
        XCTAssertEqual(sundayLayout.cells[.memo]?.minY, 1050)
        XCTAssertNotNil(sundayLayout.cells[.day(DayKey(year: 2026, month: 12, day: 12))], "the Sunday table runs to 12/12")
        XCTAssertNil(mondayOfSunday.cells[.day(DayKey(year: 2026, month: 12, day: 12))], "the Monday table ends on 12/6")
        // 1.0's month (its Monday grid and memo) has the memo cell: it draws both lines.
        XCTAssertTrue(cellsV10(pageId: "m1-2026-11").contains(.memo))
        try checkExport(Self.memo)
    }

    /// Fixture 9: the lasso's move across the day two month tables share (K-2): a copy with a new id on m1-2026-11, a
    /// tombstone on m1-2026-10 at the move's time, the cell 2026-11-01 on both pages (row 5 of October's table, row 1 of
    /// November's), never the same id on both.
    func testMoveAcrossTheSharedDaySurvives() throws {
        for e in Self.move {
            try checkFile(e)
        }
        let source = try InkPageCodecV10.decode(try data("m1-2026-10.move-source.json"))
        let destination = try InkPageCodecV10.decode(try data("m1-2026-11.move-destination.json"))
        let copy = try XCTUnwrap(destination.strokes[Self.copyId])
        XCTAssertNil(source.strokes[Self.copyId])
        XCTAssertNil(source.strokes[Self.movedId], "the moved stroke's body is gone from the source")
        XCTAssertEqual(source.deleted[Self.movedId], copy.t, "the tombstone has the move's time")
        XCTAssertTrue(Set(source.strokes.keys).isDisjoint(with: destination.strokes.keys))
        let kept = try XCTUnwrap(source.strokes[Self.keptId])
        XCTAssertEqual(copy.points.map(\.x), kept.points.map(\.x))
        XCTAssertEqual(copy.points.map(\.y), kept.points.map { $0.y - 60 }, "the copy is where the moved stroke was in its cell (60 lu above the one left behind)")
        let shared = DayKeyV10(year: 2026, month: 11, day: 1)
        XCTAssertTrue(cellsV10(pageId: "m1-2026-10").contains(.day(shared)) && cellsV10(pageId: "m1-2026-11").contains(.day(shared)),
                      "1.0's two month tables both have 2026-11-01")
        let october = try ownInkLayout(try InkPageCodec.decode(try data("m1-2026-10.move-source.json")))
        let november = try ownInkLayout(try InkPageCodec.decode(try data("m1-2026-11.move-destination.json")))
        let cell = CellKey.day(DayKey(year: 2026, month: 11, day: 1))
        XCTAssertEqual(october.cells[cell]?.origin, CGPoint(x: 1200, y: 700), "row 5, the last column of October's table")
        XCTAssertEqual(november.cells[cell]?.origin, CGPoint(x: 1200, y: 0), "row 1, the last column of November's table")
        try checkExport(Self.move)
    }

    /// Fixture 10: the year's date column belongs to January of its own year (a line centred there is y-2027's 01-20 with
    /// x < 0, 1.0's rule, B_DESIGN §4.1), and a line from December to the right is y-2026's 12-10 reaching past x 1,400.
    func testYearDateColumnAndDecemberSurvive() throws {
        for e in Self.year {
            try checkFile(e)
        }
        let column = try InkPageCodec.decode(try data("y-2027.date-column.json"))
        let columnLayout = try ownInkLayout(column)
        let columnBounds = try bounds(try XCTUnwrap(column.strokes[Self.dateColumnId]), columnLayout)
        XCTAssertTrue(columnBounds.midX >= 0 && columnBounds.midX < 56, "centred on the date column (x 0 … 56): \(columnBounds)")
        XCTAssertLessThan(columnBounds.minX, 0, "it starts on 2026's December")
        XCTAssertEqual(columnLayout.inkCell(forCenter: CGPoint(x: columnBounds.midX, y: columnBounds.midY)), .yearDay(month: 1, day: 20))
        let december = try InkPageCodec.decode(try data("y-2026.december-right.json"))
        let decemberLayout = try ownInkLayout(december)
        let decemberBounds = try bounds(try XCTUnwrap(december.strokes[Self.decemberId]), decemberLayout)
        XCTAssertGreaterThan(decemberBounds.maxX, 1400, "past the page's right edge: \(decemberBounds)")
        XCTAssertTrue(decemberBounds.midX >= 1288 && decemberBounds.midX < 1400, "centred on December's column (x 1,288 … 1,400)")
        XCTAssertEqual(decemberLayout.inkCell(forCenter: CGPoint(x: decemberBounds.midX, y: decemberBounds.midY)), .yearDay(month: 12, day: 10))
        XCTAssertTrue(cellsV10(pageId: "y-2027").contains(.yearDay(month: 1, day: 20)) && cellsV10(pageId: "y-2026").contains(.yearDay(month: 12, day: 10)))
        try checkExport(Self.year)
    }

    /// Fixtures 12 and 13: lines written where 1.4.3's window lengthened a row (the year's row alignment, the month's last
    /// row in form ア). Laid out from the page's own ink, as every version before 1.4.3 does (1 page, no floor: the row is
    /// `max(natural, ink's bottom + 12)` up to 400 / 1,200 lu), the row grows to hold the line, which is drawn by 1.0.
    func testLengthenedRowsShowWithoutTheFloors() throws {
        for e in Self.rows {
            try checkFile(e)
        }
        for (file, id, cell, natural, top, depth) in [("y-2026.row-floor.json", Self.rowFloorId, CellKey.yearDay(month: 6, day: 15), CGFloat(60), CGFloat(840), CGFloat(350)),
                                                       ("m1-2026-11.last-row.json", Self.lastRowId, CellKey.day(DayKey(year: 2026, month: 12, day: 3)), CGFloat(175), CGFloat(875), CGFloat(600))] {
            let page = try InkPageCodec.decode(try data(file))
            let stroke = try XCTUnwrap(page.strokes[id], file)
            XCTAssertEqual(stroke.cell, cell, file)
            XCTAssertEqual(stroke.points.map(\.y).min(), depth, "\(file): written \(depth) lu below the cell's top")
            let layout = try ownInkLayout(page)
            let rect = try XCTUnwrap(layout.cells[cell], file)
            let bottom = try XCTUnwrap(page.inkBottoms()[cell], file)
            XCTAssertEqual(rect.minY, top, "\(file): the rows above keep their natural height")
            XCTAssertGreaterThan(rect.height, natural, "\(file): the row is taller than its natural \(natural) lu")
            XCTAssertEqual(rect.height, bottom + 12, accuracy: 0.001, "\(file): the row is the ink's bottom + 12")
            let b = try bounds(stroke, layout)
            XCTAssertTrue(b.minY >= rect.minY && b.maxY <= rect.maxY, "\(file): the line is inside its row (\(b) in \(rect))")
            XCTAssertEqual(layout.inkCell(forCenter: CGPoint(x: b.midX, y: b.midY)), cell, "\(file): a new stroke there goes to the same cell")
            XCTAssertFalse(PaperGrowth.needsMoreRoom(cell: cell, cellHeight: rect.height, inkBottom: bottom), "\(file): opening it asks for no more room")
        }
        try checkExport(Self.rows)
    }
}
