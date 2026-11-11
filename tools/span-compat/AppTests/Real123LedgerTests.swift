import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// K-7 for 1.3 on the real 1.2.3 app (docs/M7C_CONTRACT.md §6.3, §10.4): the ledger and the sync engine of the
/// version on sale when 1.3 starts (commit 43fe36666a2120e8a23adf4fc76244151a395e6f, build 23) on every
/// compat-span fixture (TegakiKit/Tests/Fixtures/compat-span, the Monday and the Sunday shapes): strokes reaching
/// out of their page, the move across pages, the free memo across two days, the Sunday-start week, the days two
/// month pages share, the photo and the text label of a later version. The shape of
/// tools/compat10/AppTests/Real10LedgerTests.swift, on the ledger 1.2.3 ships: `PaperGrowth.needsMoreRoom`, the
/// day's `extra` open to 6,000 lu, the week start (a Sunday week is laid out with the Sunday start, as a 1.2.x
/// device set to Sunday opens it).
///
/// Fixture 4 (the week memo's `extra` on a `w-` page and a week `grid` stroke moved below 24:00) belongs to the
/// week memo stage (§5) and is not in the folder yet. When it is added to the MANIFEST, `testEveryRowHasItsCount`
/// fails until its row is written into `drawnBy123` below (1.2.3's week has no `extra` cell, so the memo's strokes
/// are kept and not drawn; the moved `grid` stroke is drawn).
///
/// It is NOT a test of the 1.3 app. CI's compat-v1.0 job takes 43fe366 out with `git archive`, copies this file
/// into its Tests/TegakiCalendarTests, generates that project and runs only
/// `-only-testing:TegakiCalendarTests/Real123LedgerTests` on the simulator, with the compat-span folder in
/// TEGAKI_COMPAT_SPAN_FIXTURES (xcodebuild: TEST_RUNNER_TEGAKI_COMPAT_SPAN_FIXTURES). It uses only what the 1.2.3
/// app and its test target have (`TestSleeper` is the 1.2.3 test target's).
@MainActor
final class Real123LedgerTests: XCTestCase {
    private var directory: URL!
    private var store: InkPageStore!
    private var db: InMemoryCloudDatabase!
    private var sleeper: TestSleeper!
    private var engine: SyncEngine!

    override func tearDown() async throws {
        engine = nil
        if let directory = directory { try? FileManager.default.removeItem(at: directory) }
    }

    // MARK: - The fixtures

    private struct Fixture {
        let name: String
        let shape: String
        let data: Data
        let json: JSONValue
        var pageId: String { json["pageId"]?.stringValue ?? "" }
        /// Every item of the file: strokes and items of tools 1.2.3 does not know.
        var rawItems: [String: JSONValue] { json["strokes"]?.objectValue ?? [:] }
    }

    /// What the 1.2.3 ledger draws of each file (the live strokes of the cells its layout has), written out from
    /// the files. A new MANIFEST row needs its count here.
    private let drawnBy123: [String: Int] = [
        "d-2026-11-03.overhang-right.json": 2,       // grid and extra
        "m1-2026-11.overhang-right.json": 2,
        "w-2026-11-02.overhang-left.json": 1,
        "y-2026.overhang.json": 2,
        "w-2026-11-16.move-source.json": 1,
        "w-2026-11-23.move-destination.json": 1,
        "d-2026-11-09.extra-cross.json": 1,
        "d-2026-11-10.extra-cross.json": 1,
        "w-2026-11-08.sunday-overhang.json": 2,      // the Sunday start opens it
        "m1-2026-11.overlap-day.json": 2,
        "m1-2026-12.overlap-day.json": 2,
        "w-2026-11-30.photo-text.json": 1,           // the photo and the text label are not strokes
        "w-2026-12-07.photo-text-neighbor.json": 1,
    ]

    private func folder() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["TEGAKI_COMPAT_SPAN_FIXTURES"], !path.isEmpty else {
            XCTFail("TEGAKI_COMPAT_SPAN_FIXTURES is not set (xcodebuild: TEST_RUNNER_TEGAKI_COMPAT_SPAN_FIXTURES)")
            throw CocoaError(.fileNoSuchFile)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Every file the MANIFEST lists ("<file> <fixture> <monday|sunday>" after the "#" lines), in its order.
    private func fixtures() throws -> [Fixture] {
        let url = try folder()
        let text = try String(contentsOf: url.appendingPathComponent("MANIFEST"), encoding: .utf8)
        var out: [Fixture] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) where !line.hasPrefix("#") {
            let parts = line.split(separator: " ")
            XCTAssertEqual(parts.count, 3, "MANIFEST line \"\(line)\"")
            guard parts.count == 3 else { continue }
            let name = String(parts[0])
            let data = try Data(contentsOf: url.appendingPathComponent(name))
            out.append(Fixture(name: name, shape: String(parts[2]), data: data, json: try JSONValue.parse(data)))
        }
        XCTAssertGreaterThanOrEqual(out.count, 13, "the 13 compat-span files of S1 are there")
        return out
    }

    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// The 1.2.3 layout of the page as its screen makes it (no event, the page's ink bottoms); a week page of a
    /// Sunday with the Sunday start.
    private func layout123(_ page: InkPage) -> (any PageLayout)? {
        let id = page.pageId
        let ink = page.inkBottoms()
        if id.hasPrefix("d-"), let day = DayKey(ymd: String(id.dropFirst(2))) {
            return DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: ink, now: Self.now))
        }
        if id.hasPrefix("w-"), let day = DayKey(ymd: String(id.dropFirst(2))) {
            let start: WeekStart = day.weekday == 0 ? .sunday : .monday
            return WeekLayoutEngine.layout(WeekLayoutInput(focus: day, events: [], inkBottoms: ink, now: Self.now, weekStart: start))
        }
        if id.hasPrefix("m1-") {
            let parts = id.dropFirst(3).split(separator: "-")
            guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: y, month: m), events: [], inkBottoms: ink, now: Self.now))
        }
        if id.hasPrefix("y-"), let y = Int(id.dropFirst(2)) {
            return YearLayoutEngine.layout(YearLayoutInput(year: y, events: [], inkBottoms: ink, now: Self.now))
        }
        return nil
    }

    // MARK: - 0. Every row has its expectation

    func testEveryRowHasItsCount() throws {
        let all = try fixtures()
        XCTAssertEqual(Set(all.map(\.name)), Set(drawnBy123.keys),
                       "every MANIFEST row has its count in drawnBy123 (fixture 4, the week memo, comes with §5)")
        XCTAssertEqual(all.filter { $0.shape == "sunday" }.map(\.name), ["w-2026-11-08.sunday-overhang.json"])
    }

    // MARK: - 1. What the 1.2.3 ledger draws

    func testThe123LedgerDrawsOnlyItsOwnCells() throws {
        for fixture in try fixtures() {
            let page = try InkPageCodec.decode(fixture.data)
            let layout = try XCTUnwrap(layout123(page), fixture.name)
            XCTAssertEqual(layout.pageId, page.pageId, "\(fixture.name): 1.2.3 opens this page")
            let ledger = InkLedger(page: page, layout: layout)
            XCTAssertEqual(ledger.page, page, "\(fixture.name): nothing moved on the way in (band migration)")
            let drawing = ledger.drawing()
            let drawn = drawing.strokes.compactMap { ledger.id(of: $0) }
            XCTAssertEqual(drawn.count, drawing.strokes.count, "\(fixture.name): every drawn stroke is known to the ledger")
            let own = ledger.page.liveStrokes.filter { layout.cells[$0.cell] != nil }.map(\.id)
            XCTAssertEqual(Set(drawn), Set(own), "\(fixture.name): 1.2.3 draws the strokes of its own cells, overhanging or not")
            XCTAssertEqual(drawn.count, drawnBy123[fixture.name], "\(fixture.name): the count written out")
            // Nothing of a tool 1.2.3 does not know is drawn; the items stay in the page.
            XCTAssertTrue(Set(drawn).isDisjoint(with: page.unknownStrokes.keys), fixture.name)
            for id in page.unknownStrokes.keys {
                XCTAssertNil(ledger.paperBounds(of: id), "\(fixture.name): \(id) is not a stroke the lasso can take")
            }
            for stroke in ledger.page.liveStrokes where layout.cells[stroke.cell] != nil {
                // Opening the page asks for no more room: the layout made from the page's ink already has it, so the
                // overhanging strokes start no relayout (PaperGrowth.needsMoreRoom, the ledger 1.2.3 ships).
                XCTAssertFalse(ledger.needsMoreRoom(stroke), "\(fixture.name): \(stroke.id) needs no more room")
                XCTAssertNotNil(ledger.paperBounds(of: stroke.id), "\(fixture.name): \(stroke.id) has bounds (the lasso reaches it)")
            }
            if page.pageId.hasPrefix("d-") {
                XCTAssertEqual(layout.cells[.extra]?.height, 6000, "\(fixture.name): the free memo is open to 6,000 lu (1.1.1)")
            }
        }
    }

    // MARK: - 2. Erasing everything on the 1.2.3 canvas

    func testErasingEverythingOn123KeepsTheOtherItemsByteForByte() throws {
        for fixture in try fixtures() {
            let page = try InkPageCodec.decode(fixture.data)
            let layout = try XCTUnwrap(layout123(page), fixture.name)
            let ledger = InkLedger(page: page, layout: layout)
            let drawing = ledger.drawing()
            let drawn = Set(drawing.strokes.compactMap { ledger.id(of: $0) })
            let change = ledger.applyCanvasChange(PKDrawing())
            XCTAssertTrue(change.added.isEmpty, fixture.name)
            XCTAssertEqual(Set(change.removedIds), drawn, "\(fixture.name): only the drawn strokes are tombstoned")
            let after = ledger.page.jsonValue["strokes"]?.objectValue ?? [:]
            let others = Set(fixture.rawItems.keys).subtracting(drawn)
            XCTAssertEqual(Set(after.keys), others, "\(fixture.name): the other strokes and the unknown items remain")
            for id in others {
                XCTAssertEqual(after[id]?.serialized(), fixture.rawItems[id]?.serialized(), "\(fixture.name): \(id) byte for byte")
            }
            let before = fixture.json["deleted"]?.objectValue ?? [:]
            XCTAssertEqual(Set(ledger.page.deleted.keys), Set(before.keys).union(drawn), "\(fixture.name): the old tombstones stay")
        }
    }

    // MARK: - 3. The 1.2.3 sync engine

    /// The engine may outlive the test (a task still asleep in the sleeper), so nothing here holds the test.
    private func makeEngine() {
        if let previous = directory { try? FileManager.default.removeItem(at: previous) }
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Real123LedgerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        db = InMemoryCloudDatabase()
        sleeper = TestSleeper()
        let sleeper = self.sleeper!
        engine = SyncEngine(
            store: store,
            stateStore: SyncStateStore(fileURL: store.stateFileURL),
            database: db,
            clock: { Real123LedgerTests.now },
            sleep: { await sleeper.sleep($0) }
        )
        let made: SyncEngine = engine
        sleeper.settle = { [weak made] in await made?.waitUntilIdle() }
    }

    private func startSynced() async {
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.snapshot.status, .synced)
    }

    private func flushDebounce() async {
        await engine.waitUntilIdle()
        await sleeper.advance()
        await engine.waitUntilIdle()
    }

    /// A record as the 1.3 device sends it: the fixture's own bytes as the page body.
    private func record(_ fixture: Fixture) throws -> CloudRecord {
        let page = try InkPageCodec.decode(fixture.data)
        return CloudRecord(
            recordType: InkPageRecord.recordType,
            recordName: fixture.pageId,
            changeTag: nil,
            systemFields: nil,
            fields: [
                "schema": .int(1),
                "updatedAt": .date(Self.now),
                "strokeCount": .int(Int64(page.liveStrokeCount)),
                "doc": .asset(try InkPageCodec.compress(fixture.data)),
                "app": .string("ios/1.3/0"),
            ]
        )
    }

    /// The JSON of a page body (a file on the device or a record's asset), without the reader's caps.
    private func rawJSON(compressed: Data) throws -> JSONValue {
        try JSONValue.parse(InkPageCodec.decompress(compressed))
    }

    private func savedCount() -> Int {
        db.calls.filter { $0 == .save }.count
    }

    func testSyncOn123KeepsEveryItemAndDoesNotSendAPageBack() async throws {
        for fixture in try fixtures() {
            makeEngine()
            await startSynced()
            let id = fixture.pageId
            db.simulateRemoteSave(try record(fixture))
            await engine.syncNow()
            // The file on the device is the 1.3 page, byte for byte (every item 1.2.3 read is written back).
            let file = try rawJSON(compressed: Data(contentsOf: store.url(for: id)))
            XCTAssertEqual(file.serialized(), fixture.json.serialized(), "\(fixture.name): the file is the 1.3 page")
            XCTAssertFalse(engine.state.dirty.contains(id), "\(fixture.name): an identical page is not sent back")
            XCTAssertEqual(savedCount(), 0, fixture.name)

            // The same page again (a new version tag): still nothing to send.
            db.simulateRemoteSave(try record(fixture))
            await engine.syncNow()
            XCTAssertFalse(engine.state.dirty.contains(id), "\(fixture.name): fetched again, not dirty")
            XCTAssertEqual(savedCount(), 0, fixture.name)

            // A stroke written on this 1.2.3 device into one of its own cells, saved and sent.
            var page = store.load(id)
            let layout = try XCTUnwrap(layout123(page), fixture.name)
            let cell: CellKey = id.hasPrefix("m1-") ? .memo : (id.hasPrefix("y-") ? .yearDay(month: 1, day: 1) : .grid)
            XCTAssertNotNil(layout.cells[cell], fixture.name)
            let points = (0..<4).map { InkPoint(x: 30 + CGFloat($0) * 6, y: 40, dtMs: $0 * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571) }
            let added = InkStroke(id: "real123-\(id)", cell: cell, tool: .pen, color: "#1f2937", t: 1_792_000_000_000, dev: "real-1.2.3", points: points)
            page.add(added)
            try engine.save(page)
            await flushDebounce()
            let sent = try XCTUnwrap(db.records[id], fixture.name)
            guard case .asset(let doc)? = sent.fields["doc"] else { return XCTFail("\(fixture.name): the record has a body") }
            let body = try rawJSON(compressed: doc)
            let sentItems = body["strokes"]?.objectValue ?? [:]
            XCTAssertEqual(sentItems.count, fixture.rawItems.count + 1, "\(fixture.name): every item and the new stroke are sent")
            for (itemId, json) in fixture.rawItems {
                XCTAssertEqual(sentItems[itemId]?.serialized(), json.serialized(), "\(fixture.name): \(itemId) is sent unchanged")
            }
            XCTAssertEqual(body["deleted"]?.serialized(), fixture.json["deleted"]?.serialized(), "\(fixture.name): the tombstones are sent unchanged")
            XCTAssertNotNil(sentItems[added.id], fixture.name)
            XCTAssertFalse(engine.state.dirty.contains(id), fixture.name)
        }
    }
}
