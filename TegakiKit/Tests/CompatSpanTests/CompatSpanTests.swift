import XCTest
import Foundation
import CoreGraphics
import Compat10
import InkModel
import Layout

/// K-7 for 1.3 (docs/M7C_CONTRACT.md §6.3, §10.2 row C): the compat-span fixtures
/// (TegakiKit/Tests/Fixtures/compat-span, written by the joined path of the Kit, §4.2) read through the
/// frozen 1.0 copy (Compat10) and through today's InkModel. A target of its own (the shape of Compat12Tests),
/// so that Compat10Tests stays byte for byte what K-7 froze. It does not import CompatSpanFixtures (the code
/// that makes the files): every expected value here — the MANIFEST rows, the stroke ids, cells, point x
/// ranges, tombstones, the unknown items' bytes, what 1.0 draws — is written out by hand from the committed
/// files, so a change of the maker or of the files shows up as a failure here.
///
/// The real old Kits (1.0, <1.1.1>, 1.2.3) read the same files in tools/span-compat (CI's compat-v1.0 job),
/// and the 1.2.3 app's ledger in tools/span-compat/AppTests/Real123LedgerTests.swift.
///
/// Fixture 4 (the week memo's `extra` and a week `grid` stroke moved below 24:00) belongs to the week memo
/// stage (§5) and is not in the folder yet: when it is added, `manifest` below and the tables get its rows.
final class CompatSpanTests: XCTestCase {
    // MARK: - The folder and its MANIFEST

    /// TegakiKit/Tests/Fixtures/compat-span of this checkout (found from this file, no bundle resources).
    private static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // CompatSpanTests/
        .deletingLastPathComponent()   // Tests/
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("compat-span", isDirectory: true)

    private struct Row: Equatable, CustomStringConvertible {
        let file: String
        let fixture: Int
        let shape: String
        var description: String { "\(file) \(fixture) \(shape)" }
    }

    /// The MANIFEST's rows as committed (1.3, S1): fixtures 1–3 and 5–7, in its order.
    private static let manifest: [Row] = [
        Row(file: "d-2026-11-03.overhang-right.json", fixture: 1, shape: "monday"),
        Row(file: "m1-2026-11.overhang-right.json", fixture: 1, shape: "monday"),
        Row(file: "w-2026-11-02.overhang-left.json", fixture: 1, shape: "monday"),
        Row(file: "y-2026.overhang.json", fixture: 1, shape: "monday"),
        Row(file: "w-2026-11-16.move-source.json", fixture: 2, shape: "monday"),
        Row(file: "w-2026-11-23.move-destination.json", fixture: 2, shape: "monday"),
        Row(file: "d-2026-11-09.extra-cross.json", fixture: 3, shape: "monday"),
        Row(file: "d-2026-11-10.extra-cross.json", fixture: 3, shape: "monday"),
        Row(file: "w-2026-11-08.sunday-overhang.json", fixture: 5, shape: "sunday"),
        Row(file: "m1-2026-11.overlap-day.json", fixture: 6, shape: "monday"),
        Row(file: "m1-2026-12.overlap-day.json", fixture: 6, shape: "monday"),
        Row(file: "w-2026-11-30.photo-text.json", fixture: 7, shape: "monday"),
        Row(file: "w-2026-12-07.photo-text-neighbor.json", fixture: 7, shape: "monday"),
    ]

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
        /// Items of tools 1.2.3 does not know (fixture 7): id → the item's JSON as the file writes it.
        let unknown: [String: String]
        /// What 1.0 draws (and its lasso reaches): the live strokes of the cells its layout has.
        let drawnBy10: [String]
    }

    private static let monday: [Expected] = [
        // 1. Out of the page to the right: a day in grid and in extra (1.0 has no extra cell).
        Expected(file: "d-2026-11-03.overhang-right.json", pageId: "d-2026-11-03", updatedAt: 1_791_000_000_201,
                 live: [Stroke(id: "411a56ba-d7d4-4abc-97ec-c29745c894c9", cell: "extra", minX: 690, maxX: 1300, points: 9),
                        Stroke(id: "a1fdb04a-7cdd-4449-944c-0438b16a477f", cell: "grid", minX: 690, maxX: 1300, points: 9)],
                 tombstones: [:], unknown: [:], drawnBy10: ["a1fdb04a-7cdd-4449-944c-0438b16a477f"]),
        // 1. A month 250 lu to the right: November 8 (the last column) and the memo.
        Expected(file: "m1-2026-11.overhang-right.json", pageId: "m1-2026-11", updatedAt: 1_791_000_000_301,
                 live: [Stroke(id: "5bb08340-de00-4a13-b45d-cb0035e84b2c", cell: "memo", minX: 1140, maxX: 1650, points: 9),
                        Stroke(id: "9f569573-6770-472c-8ca7-c1bef309f262", cell: "2026-11-08", minX: -60, maxX: 450, points: 9)],
                 tombstones: [:], unknown: [:],
                 drawnBy10: ["5bb08340-de00-4a13-b45d-cb0035e84b2c", "9f569573-6770-472c-8ca7-c1bef309f262"]),
        // 1. A Monday week 300 lu to the left (from the Sunday night of the week before).
        Expected(file: "w-2026-11-02.overhang-left.json", pageId: "w-2026-11-02", updatedAt: 1_791_000_000_100,
                 live: [Stroke(id: "2f20320a-7a4a-4166-9ac0-63113c494828", cell: "grid", minX: -300, maxX: 500, points: 9)],
                 tombstones: [:], unknown: [:], drawnBy10: ["2f20320a-7a4a-4166-9ac0-63113c494828"]),
        // 1. A year: from December 20 to the right, January 20 below x 0.
        Expected(file: "y-2026.overhang.json", pageId: "y-2026", updatedAt: 1_791_000_000_401,
                 live: [Stroke(id: "3f99ebb1-cbdb-46f1-8f52-95b529778472", cell: "01-20", minX: -156, maxX: 204, points: 7),
                        Stroke(id: "ecee1f22-1a96-4cf2-952d-22761605549c", cell: "12-20", minX: -188, maxX: 400, points: 8)],
                 tombstones: [:], unknown: [:],
                 drawnBy10: ["3f99ebb1-cbdb-46f1-8f52-95b529778472", "ecee1f22-1a96-4cf2-952d-22761605549c"]),
        // 2. A lasso move across pages: a tombstone on the source (at the move's time) ...
        Expected(file: "w-2026-11-16.move-source.json", pageId: "w-2026-11-16", updatedAt: 1_791_000_000_600,
                 live: [Stroke(id: "281c8b9e-655c-4c0e-b590-1bbd3efc810f", cell: "grid", minX: 700, maxX: 900, points: 6)],
                 tombstones: ["34d2ed6d-a403-4a0f-9af0-7543bf3779b9": 1_791_000_000_600], unknown: [:],
                 drawnBy10: ["281c8b9e-655c-4c0e-b590-1bbd3efc810f"]),
        // 2. ... and a copy with a new id on the destination (K-2).
        Expected(file: "w-2026-11-23.move-destination.json", pageId: "w-2026-11-23", updatedAt: 1_791_000_000_600,
                 live: [Stroke(id: "5d24828b-07bd-42b8-8714-8123ccc5fed6", cell: "grid", minX: 300, maxX: 500, points: 6)],
                 tombstones: [:], unknown: [:], drawnBy10: ["5d24828b-07bd-42b8-8714-8123ccc5fed6"]),
        // 3. The free memo (extra) across two days, one stroke owned by each (1.0 draws neither).
        Expected(file: "d-2026-11-09.extra-cross.json", pageId: "d-2026-11-09", updatedAt: 1_791_000_000_700,
                 live: [Stroke(id: "a50950d6-9129-4fd5-8cd7-d3f175f823f3", cell: "extra", minX: 600, maxX: 1300, points: 9)],
                 tombstones: [:], unknown: [:], drawnBy10: []),
        Expected(file: "d-2026-11-10.extra-cross.json", pageId: "d-2026-11-10", updatedAt: 1_791_000_000_701,
                 live: [Stroke(id: "cea12dc5-9894-4a7d-94c8-73c9e7a7d0b8", cell: "extra", minX: -300, maxX: 600, points: 9)],
                 tombstones: [:], unknown: [:], drawnBy10: []),
        // 6. The days two month pages share: the same cell names on both pages, a stroke of its own on each.
        Expected(file: "m1-2026-11.overlap-day.json", pageId: "m1-2026-11", updatedAt: 1_791_000_000_901,
                 live: [Stroke(id: "c4fe78e3-1ae9-48c1-92a6-232e30bc069b", cell: "2026-11-30", minX: 30, maxX: 130, points: 5),
                        Stroke(id: "cf5b722f-3009-4e44-86c1-3e614b57d97a", cell: "2026-12-01", minX: 30, maxX: 130, points: 5)],
                 tombstones: [:], unknown: [:],
                 drawnBy10: ["c4fe78e3-1ae9-48c1-92a6-232e30bc069b", "cf5b722f-3009-4e44-86c1-3e614b57d97a"]),
        Expected(file: "m1-2026-12.overlap-day.json", pageId: "m1-2026-12", updatedAt: 1_791_000_000_903,
                 live: [Stroke(id: "2261ea79-3468-41a5-ba0f-11f438a55bd8", cell: "2026-11-30", minX: 30, maxX: 130, points: 5),
                        Stroke(id: "4d1f974a-c666-46f8-bd66-6f578c33a93f", cell: "2026-12-01", minX: 30, maxX: 130, points: 5)],
                 tombstones: [:], unknown: [:],
                 drawnBy10: ["2261ea79-3468-41a5-ba0f-11f438a55bd8", "4d1f974a-c666-46f8-bd66-6f578c33a93f"]),
    ]

    private static let sunday = Expected(
        file: "w-2026-11-08.sunday-overhang.json", pageId: "w-2026-11-08", updatedAt: 1_791_000_000_801,
        live: [Stroke(id: "11501ea2-5270-4dde-bf49-95e2a1c295fe", cell: "grid", minX: 900, maxX: 1700, points: 9),
               Stroke(id: "d2028d06-4576-4b61-8e65-80db09b82e97", cell: "grid", minX: -300, maxX: 500, points: 9)],
        tombstones: [:], unknown: [:],
        drawnBy10: ["11501ea2-5270-4dde-bf49-95e2a1c295fe", "d2028d06-4576-4b61-8e65-80db09b82e97"])

    private static let photoId = "9a1e5c7b-2f3d-4b6a-8e9c-1d2e3f4a5b62"
    private static let textId = "c4d8e2f6-3a5b-4c7d-9e1f-2a3b4c5d6e73"
    private static let neighborPhotoId = "5b7d9f1a-4c6e-4a8b-9d2f-3e4a5b6c7d84"

    private static let photoText: [Expected] = [
        // 7. A photo and a text label as 1.6 will write them, next to the session's ink; the hand-written pen
        // stroke was erased by the session (its tombstone). The label's rect reaches past the right edge.
        Expected(file: "w-2026-11-30.photo-text.json", pageId: "w-2026-11-30", updatedAt: 1_791_000_001_001,
                 live: [Stroke(id: "d750c2b4-7050-459b-a57d-b4f9f153e45d", cell: "grid", minX: 900, maxX: 1700, points: 9)],
                 tombstones: ["3f6c2a9e-1d4b-4e7a-8c5f-0a9b8c7d6e51": 1_791_000_001_001],
                 unknown: [
                    photoId: #"{"cell":"grid","dev":"fixture-1.6","id":"9a1e5c7b-2f3d-4b6a-8e9c-1d2e3f4a5b62","img":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","rect":[120,340,360,240],"t":1791000000002,"tool":"photo"}"#,
                    textId: #"{"cell":"grid","dev":"fixture-1.6","id":"c4d8e2f6-3a5b-4c7d-9e1f-2a3b4c5d6e73","rect":[1250,900,300,80],"t":1791000000003,"text":"牛乳を買う","tool":"text"}"#,
                 ],
                 drawnBy10: ["d750c2b4-7050-459b-a57d-b4f9f153e45d"]),
        // 7. The neighbour page: a photo whose rect starts left of the page.
        Expected(file: "w-2026-12-07.photo-text-neighbor.json", pageId: "w-2026-12-07", updatedAt: 1_791_000_001_002,
                 live: [Stroke(id: "37efb3db-ea05-4c4d-9d81-d711e9479fe1", cell: "grid", minX: 300, maxX: 600, points: 6)],
                 tombstones: [:],
                 unknown: [
                    neighborPhotoId: #"{"cell":"grid","dev":"fixture-1.6","id":"5b7d9f1a-4c6e-4a8b-9d2f-3e4a5b6c7d84","img":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","rect":[-80,1500,320,200],"t":1791000000004,"tool":"photo"}"#,
                 ],
                 drawnBy10: ["37efb3db-ea05-4c4d-9d81-d711e9479fe1"]),
    ]

    /// A time after every time in the fixtures (1.0's own edits below).
    private static let later = 1_792_000_000_000

    // MARK: - The checks of one file

    /// The file read by the frozen 1.0 copy and by today's InkModel: what it holds, the bytes each writes back,
    /// what 1.0 draws and lassoes, and that 1.0's migration, merge, erase and own edit leave the rest alone.
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
        let oldLive = old.liveStrokes.sorted { $0.id < $1.id }
        let newLive = new.liveStrokes.sorted { $0.id < $1.id }
        XCTAssertEqual(oldLive.map(\.id), e.live.map(\.id), "\(name): the live strokes on 1.0", file: file, line: line)
        XCTAssertEqual(newLive.map(\.id), e.live.map(\.id), "\(name): the live strokes on 1.3", file: file, line: line)
        for (s, want) in zip(oldLive, e.live) {
            XCTAssertEqual(s.cell.raw, want.cell, "\(name) \(s.id): cell on 1.0", file: file, line: line)
            XCTAssertEqual(s.points.count, want.points, "\(name) \(s.id): no point dropped on 1.0", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).min(), want.minX, "\(name) \(s.id): left end on 1.0 (not cut)", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).max(), want.maxX, "\(name) \(s.id): right end on 1.0 (not cut)", file: file, line: line)
        }
        for (s, want) in zip(newLive, e.live) {
            XCTAssertEqual(s.cell.raw, want.cell, "\(name) \(s.id): cell on 1.3", file: file, line: line)
            XCTAssertEqual(s.points.count, want.points, "\(name) \(s.id): no point dropped on 1.3", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).min(), want.minX, "\(name) \(s.id): left end on 1.3", file: file, line: line)
            XCTAssertEqual(s.points.map(\.x).max(), want.maxX, "\(name) \(s.id): right end on 1.3", file: file, line: line)
        }
        for (a, b) in zip(oldLive, newLive) {
            XCTAssertEqual(a.points.map(\.x), b.points.map(\.x), "\(name) \(a.id): the same x on both", file: file, line: line)
            XCTAssertEqual(a.points.map(\.y), b.points.map(\.y), "\(name) \(a.id): the same y on both", file: file, line: line)
            XCTAssertEqual(a.t, b.t, name, file: file, line: line)
        }
        XCTAssertEqual(old.deleted, e.tombstones, "\(name): tombstones on 1.0", file: file, line: line)
        XCTAssertEqual(new.deleted, e.tombstones, "\(name): tombstones on 1.3", file: file, line: line)
        XCTAssertEqual(Set(old.unknownStrokes.keys), Set(e.unknown.keys), "\(name): unknown items on 1.0", file: file, line: line)
        XCTAssertEqual(Set(new.unknownStrokes.keys), Set(e.unknown.keys), "\(name): unknown items on 1.3", file: file, line: line)
        for (id, json) in e.unknown {
            XCTAssertEqual(old.unknownStrokes[id]?.serialized(), json, "\(name) \(id): byte for byte on 1.0", file: file, line: line)
            XCTAssertEqual(new.unknownStrokes[id]?.serialized(), json, "\(name) \(id): byte for byte on 1.3", file: file, line: line)
        }

        // The bytes each side writes back.
        XCTAssertEqual(try InkPageCodecV10.encode(old), bytes, "\(name): 1.0 writes back the same bytes", file: file, line: line)
        XCTAssertEqual(try InkPageCodec.encode(new), bytes, "\(name): 1.3 writes back the same bytes", file: file, line: line)
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

        // 1.0 erases everything it draws: the other strokes and the unknown items stay byte for byte.
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
        let cell: CellKeyV10 = e.pageId.hasPrefix("m1-") ? .memo : (e.pageId.hasPrefix("y-") ? .yearDay(month: 1, day: 1) : .grid)
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

        // 1.3's save and transfer doors leave the file as it is (no window name in it).
        XCTAssertEqual(SpanGuard.checkForSave(new), .ok, name, file: file, line: line)
        XCTAssertTrue(SpanGuard.checkForTransfer(new), name, file: file, line: line)
    }

    /// The app export of `pages` written by 1.3, read by 1.0 (the same pages, the same bytes written back) and
    /// imported by 1.3 again.
    private func checkExport(_ expected: [Expected], file: StaticString = #filePath, line: UInt = #line) throws {
        let pages = try expected.map { try InkPageCodec.decode(try data($0.file)) }
        let document = AppExport.Document(exportedAt: "2026-11-12T09:00:00+09:00", app: "ios/1.3 (0)", pages: pages)
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
        XCTAssertEqual(imported.pages, pages, "1.3 imports the same pages", file: file, line: line)
    }

    // MARK: - The four tests of §10.2 (row C)

    /// MANIFEST ⇄ folder both ways, with the Monday and Sunday rows (§6.3: CI copies the Monday files into
    /// compat11's folder for the real 1.0; the Sunday one is read only here and by tools/span-compat).
    func testEveryCompatSpanFixtureIsPresent() throws {
        let rows = try manifestRows()
        XCTAssertEqual(rows, Self.manifest, "MANIFEST lists the 13 files of fixtures 1–3 and 5–7 (4 comes with the week memo, §5)")
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path).filter { $0.hasSuffix(".json") }.sorted()
        XCTAssertEqual(onDisk, rows.map(\.file).sorted(), "every *.json of the folder is in MANIFEST, and every row's file is there")
        for row in rows {
            let bytes = try data(row.file)
            XCTAssertFalse(bytes.isEmpty, row.file)
            XCTAssertTrue(row.file.hasPrefix(try InkPageCodec.decode(bytes).pageId + "."), "\(row.file) holds the page its name says")
        }
        XCTAssertEqual(Set(rows.map(\.fixture)), [1, 2, 3, 5, 6, 7])
        XCTAssertEqual(Set(rows.map(\.shape)), ["monday", "sunday"], "only the two shapes")
        XCTAssertEqual(rows.filter { $0.shape == "sunday" }.map(\.file), ["w-2026-11-08.sunday-overhang.json"], "one Sunday row: the Sunday-start week")
        XCTAssertEqual(rows.filter { $0.shape == "monday" }.count, 12, "12 Monday rows (the files CI copies into the compat11 folder)")
        // The shape follows the page: a week page of a Sunday is "sunday"; Monday weeks and the other pages "monday".
        for row in rows {
            let pageId = try InkPageCodec.decode(try data(row.file)).pageId
            if pageId.hasPrefix("w-") {
                let day = try XCTUnwrap(DayKey(ymd: String(pageId.dropFirst(2))), pageId)
                XCTAssertEqual(day.weekday == 0 ? "sunday" : "monday", row.shape, "\(row.file): \(pageId) starts on weekday \(day.weekday) (0 = Sunday)")
                XCTAssertTrue(day.weekday == 0 || day.weekday == 1, "\(pageId) is a Sunday or a Monday week")
            } else {
                XCTAssertEqual(row.shape, "monday", "\(row.file): a page that is not a week opens the same way in every version")
            }
        }
        // Every row has its expectations below (a new row, e.g. fixture 4, fails here until they are written).
        let covered = (Self.monday + [Self.sunday] + Self.photoText).map(\.file)
        XCTAssertEqual(covered.sorted(), rows.map(\.file).sorted(), "every MANIFEST row is checked by one of the tests below")
    }

    /// Fixtures 1, 2, 3 and 6 (the Monday shapes but 7): strokes reaching out of their page, the move across pages,
    /// the free memo across two days, the days two month pages share. Nothing is cut, moved or lost on 1.0.
    func testOverhangingStrokesSurviveTheFrozenCopy() throws {
        XCTAssertEqual(Self.monday.count, 10)
        for e in Self.monday {
            try checkFile(e)
        }
        // The move (K-2): the copy has a new id and was written at the move's time, the tombstone on the source too.
        let source = try InkPageCodecV10.decode(try data("w-2026-11-16.move-source.json"))
        let destination = try InkPageCodecV10.decode(try data("w-2026-11-23.move-destination.json"))
        let copy = try XCTUnwrap(destination.liveStrokes.first)
        XCTAssertNil(source.strokes[copy.id])
        XCTAssertNil(source.strokes["34d2ed6d-a403-4a0f-9af0-7543bf3779b9"], "the moved stroke's body is gone from the source")
        XCTAssertEqual(source.deleted["34d2ed6d-a403-4a0f-9af0-7543bf3779b9"], copy.t)
        // The shared days of fixture 6: one stroke per page and cell, never the same id on both pages.
        let november = try InkPageCodecV10.decode(try data("m1-2026-11.overlap-day.json"))
        let december = try InkPageCodecV10.decode(try data("m1-2026-12.overlap-day.json"))
        XCTAssertTrue(Set(november.strokes.keys).isDisjoint(with: december.strokes.keys))
        XCTAssertTrue(cellsV10(pageId: "m1-2026-11").isSuperset(of: [.day(DayKeyV10(year: 2026, month: 11, day: 30)), .day(DayKeyV10(year: 2026, month: 12, day: 1))]))
        XCTAssertTrue(cellsV10(pageId: "m1-2026-12").isSuperset(of: [.day(DayKeyV10(year: 2026, month: 11, day: 30)), .day(DayKeyV10(year: 2026, month: 12, day: 1))]))
        try checkExport(Self.monday)
    }

    /// Fixture 5: the Sunday-start week w-2026-11-08 reaching out on both sides. 1.0 never opens it (its weeks start
    /// on Monday, F2) but reads, merges, exports and writes it back unchanged; today's Kit opens it only under the
    /// Sunday start (K-11).
    func testSundayWeekOverhangSurvives() throws {
        try checkFile(Self.sunday)
        let sunday = DayKey(year: 2026, month: 11, day: 8)
        XCTAssertEqual(sunday.weekday, 0, "2026-11-08 is a Sunday")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: sunday, weekStart: .sunday), "w-2026-11-08")
        XCTAssertEqual(PageNavigation.pageId(.week, focus: sunday, weekStart: .monday), "w-2026-11-02", "the Monday start opens another page")
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let sundayLayout = WeekLayoutEngine.layout(WeekLayoutInput(focus: sunday, events: [], inkBottoms: [:], now: now, weekStart: .sunday))
        XCTAssertEqual(sundayLayout.pageId, "w-2026-11-08")
        XCTAssertEqual(Set(sundayLayout.cells.keys.map(\.raw)), ["grid"], "the Sunday week has the one grid cell, as 1.0's weeks")
        let mondayLayout = WeekLayoutEngine.layout(WeekLayoutInput(focus: sunday, events: [], inkBottoms: [:], now: now, weekStart: .monday))
        XCTAssertEqual(mondayLayout.pageId, "w-2026-11-02", "1.0's (Monday) week of that Sunday is another page: 1.0 never opens w-2026-11-08")
        // Both strokes reach out of the page: one left of the grid (from the Saturday night of the week before),
        // one past the page's right edge (into the next week's Sunday).
        let page = try InkPageCodec.decode(try data(Self.sunday.file))
        let width = sundayLayout.size.width
        XCTAssertEqual(width, 1400)
        let grid = try XCTUnwrap(sundayLayout.cells[.grid])
        let xs = page.liveStrokes.flatMap { $0.points.map(\.x) }
        XCTAssertLessThan(xs.min() ?? 0, 0, "the left stroke starts left of the grid")
        XCTAssertGreaterThan(grid.minX + (xs.max() ?? 0), width, "the right stroke ends past the page's right edge")
        // The 1.0 copy's week (any w- id has the grid cell) draws both strokes, so if a 1.0 device ever met the page
        // in an import it would neither drop nor cut them.
        XCTAssertEqual(cellsV10(pageId: "w-2026-11-08"), [.grid])
        try checkExport([Self.sunday])
    }

    /// Fixture 7: the photo and the text label of a later version (unknown tools on 1.0 and 1.3) next to the joined
    /// path's ink, on a page and its neighbour: never drawn, never lassoed, never cut or moved, byte for byte.
    func testUnknownToolItemsSurvive() throws {
        for e in Self.photoText {
            try checkFile(e)
        }
        let page = try InkPageCodecV10.decode(try data("w-2026-11-30.photo-text.json"))
        let neighbor = try InkPageCodecV10.decode(try data("w-2026-12-07.photo-text-neighbor.json"))
        // Unknown on 1.0: kept as items, with their own tools and rects; no live stroke of theirs.
        XCTAssertEqual(InkStrokeV10.toolName(of: try XCTUnwrap(page.unknownStrokes[Self.photoId])), "photo")
        XCTAssertEqual(InkStrokeV10.toolName(of: try XCTUnwrap(page.unknownStrokes[Self.textId])), "text")
        XCTAssertEqual(InkStrokeV10.toolName(of: try XCTUnwrap(neighbor.unknownStrokes[Self.neighborPhotoId])), "photo")
        XCTAssertNil(page.strokes[Self.photoId])
        XCTAssertNil(page.strokes[Self.textId])
        XCTAssertEqual(page.unknownStrokes[Self.textId]?["text"]?.stringValue, "牛乳を買う")
        XCTAssertEqual(page.unknownStrokes[Self.textId]?["rect"]?.arrayValue?.compactMap(\.doubleValue), [1250, 900, 300, 80], "past the right edge")
        XCTAssertEqual(neighbor.unknownStrokes[Self.neighborPhotoId]?["rect"]?.arrayValue?.compactMap(\.doubleValue), [-80, 1500, 320, 200], "left of the page")
        // A 1.0 device's own edit merged with the page keeps the items.
        var edited = InkPageV10.empty(pageId: "w-2026-11-30")
        edited.add(InkStrokeV10(id: "from-1.0", cell: .grid, tool: .pen, color: "#1f2937", t: Self.later, dev: "ipad-10",
                                points: [InkPointV10(x: 1, y: 2, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5)]))
        let merged = InkPageV10.merge(edited, page)
        XCTAssertEqual(Set(merged.unknownStrokes.keys), [Self.photoId, Self.textId])
        for id in [Self.photoId, Self.textId] {
            XCTAssertEqual(merged.unknownStrokes[id]?.serialized(), Self.photoText[0].unknown[id])
        }
        // Today's Kit too: the 1.3 merge of the two pages' copies with themselves and each other keeps the items.
        let new = try InkPageCodec.decode(try data("w-2026-11-30.photo-text.json"))
        var newEdited = InkPage.empty(pageId: "w-2026-11-30")
        newEdited.add(InkStroke(id: "from-1.3", cell: .grid, tool: .pen, color: "#1f2937", t: Self.later, dev: "ipad-13",
                                points: [InkPoint(x: 1, y: 2, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5)]))
        let newMerged = InkPage.merge(newEdited, new)
        for id in [Self.photoId, Self.textId] {
            XCTAssertEqual(newMerged.unknownStrokes[id]?.serialized(), Self.photoText[0].unknown[id])
        }
        try checkExport(Self.photoText)
    }
}
