import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// K-7 on the real 1.0 app (docs/M7A_CONTRACT.md §1.4): the ledger and the sync engine of 1.0
/// (commit a21e4692109e504701b507ad9c695181fdecddfd) on the golden fixtures of 1.1. `LedgerV10` in
/// TegakiKit/Tests/Compat10 is a hand transcription of the app's rules, so a mistake in it would stay
/// green in RunReal and RunFrozen; this file runs the app's own code instead.
///
/// It is NOT a test of the 1.1 app. CI's compat-v1.0 job copies it into v10/Tests/TegakiCalendarTests
/// (the a21e469 checkout), generates that project and runs only
/// `-only-testing:TegakiCalendarTests/Real10LedgerTests` on the simulator, with the fixture folder in
/// TEGAKI_COMPAT_FIXTURES (xcodebuild: TEST_RUNNER_TEGAKI_COMPAT_FIXTURES). It uses only what the 1.0
/// app and its test target have (`TestSleeper` is the 1.0 test target's).
@MainActor
final class Real10LedgerTests: XCTestCase {
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
        let data: Data
        let json: JSONValue
        var pageId: String { json["pageId"]?.stringValue ?? "" }
        var rawStrokes: [String: JSONValue] { json["strokes"]?.objectValue ?? [:] }
    }

    private func folder() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["TEGAKI_COMPAT_FIXTURES"], !path.isEmpty else {
            XCTFail("TEGAKI_COMPAT_FIXTURES is not set (xcodebuild: TEST_RUNNER_TEGAKI_COMPAT_FIXTURES)")
            throw CocoaError(.fileNoSuchFile)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// The page fixtures (not digests.json, not an app export). `maxStrokes`: only pages with at most
    /// that many strokes (the ledger builds one PKStroke per stroke). Pages with more tombstones than
    /// 1.0 reads (`InkPage.maxTombstones`, y-2026.tomb200500.json) are left out too: 1.0 keeps a
    /// subset of them that depends on the dictionary order (F8), so its file can never be the fixture
    /// byte for byte; Compat10Checks (RunReal) checks that page on the real 1.0 InkModel.
    private func pages(maxStrokes: Int = 5_000) throws -> [Fixture] {
        let url = try folder()
        let names = try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { $0.hasSuffix(".json") && $0 != "digests.json" }
            .sorted()
        var out: [Fixture] = []
        for name in names {
            let data = try Data(contentsOf: url.appendingPathComponent(name))
            let json = try JSONValue.parse(data)
            guard json["format"] == nil, (json["strokes"]?.objectValue?.count ?? 0) <= maxStrokes,
                  (json["deleted"]?.objectValue?.count ?? 0) <= InkPage.maxTombstones else { continue }
            out.append(Fixture(name: name, data: data, json: json))
        }
        XCTAssertGreaterThanOrEqual(out.count, 6, "K's page fixtures are there")
        return out
    }

    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// The 1.0 layout of the page as the 1.0 screen makes it (no event, the page's ink bottoms).
    private func layout10(_ page: InkPage) -> (any PageLayout)? {
        let id = page.pageId
        let ink = page.inkBottoms()
        if id.hasPrefix("d-"), let day = DayKey(ymd: String(id.dropFirst(2))) {
            return DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: ink, now: Self.now))
        }
        if id.hasPrefix("w-"), let day = DayKey(ymd: String(id.dropFirst(2))) {
            return WeekLayoutEngine.layout(WeekLayoutInput(focus: day, events: [], inkBottoms: ink, now: Self.now))
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

    /// The cells 1.0 has, written out independently of its engines: grid on the day and week pages,
    /// the 42 days from the Monday on or before the 1st and memo on the month page, "MM-DD" on the
    /// year page.
    private func knownTo10(_ cell: CellKey, pageId: String) -> Bool {
        if pageId.hasPrefix("d-") || pageId.hasPrefix("w-") { return cell == .grid }
        if pageId.hasPrefix("m1-") {
            if cell == .memo { return true }
            let parts = pageId.dropFirst(3).split(separator: "-")
            guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), let day = cell.day else { return false }
            let first = DayKey(year: y, month: m, day: 1)
            let n = day.dayNumber - first.dayNumber + (first.weekday + 6) % 7
            return n >= 0 && n < 42
        }
        if pageId.hasPrefix("y-") { return cell.yearMonthDay != nil }
        return false
    }

    /// How many strokes 1.0 draws on K's own fixtures (M7A_CONTRACT §1.4).
    private let drawnOnK: [String: Int] = [
        "d-2026-11-02.json": 6, "d-2026-11-02.from10.json": 7, "d-2026-11-04.moved.json": 2,
        "m1-2026-11.json": 9, "m1-2026-12.from10.json": 3, "w-2026-11-02.legacy.json": 1,
    ]

    // MARK: - 1. What the 1.0 ledger draws

    func testThe10LedgerDrawsOnlyItsOwnCells() throws {
        for fixture in try pages() {
            let page = try InkPageCodec.decode(fixture.data)
            let layout = try XCTUnwrap(layout10(page), fixture.name)
            let ledger = InkLedger(page: page, layout: layout)
            let drawing = ledger.drawing()
            let drawn = drawing.strokes.compactMap { ledger.id(of: $0) }
            XCTAssertEqual(drawn.count, drawing.strokes.count, "\(fixture.name): every drawn stroke is known to the ledger")
            let own = ledger.page.liveStrokes.filter { knownTo10($0.cell, pageId: page.pageId) }.map(\.id)
            XCTAssertEqual(drawing.strokes.count, own.count, "\(fixture.name): 1.0 draws the strokes of its own cells")
            XCTAssertEqual(Set(drawn), Set(own), fixture.name)
            if let expected = drawnOnK[fixture.name] {
                XCTAssertEqual(drawing.strokes.count, expected, "\(fixture.name): the contract's count")
            }
            // Nothing of a cell 1.0 lacks is drawn (the day's extra, a later tool).
            XCTAssertFalse(drawn.contains { ledger.page.strokes[$0]?.cell.raw == "extra" }, fixture.name)
        }
    }

    // MARK: - 2. Erasing everything on the 1.0 canvas

    func testErasingEverythingOn10KeepsTheOtherStrokesByteForByte() throws {
        for fixture in try pages() {
            let page = try InkPageCodec.decode(fixture.data)
            let layout = try XCTUnwrap(layout10(page), fixture.name)
            let ledger = InkLedger(page: page, layout: layout)
            let drawing = ledger.drawing()
            let drawn = Set(drawing.strokes.compactMap { ledger.id(of: $0) })
            let change = ledger.applyCanvasChange(PKDrawing())
            XCTAssertTrue(change.added.isEmpty, fixture.name)
            XCTAssertEqual(Set(change.removedIds), drawn, "\(fixture.name): only the drawn strokes are tombstoned")
            let after = ledger.page.jsonValue["strokes"]?.objectValue ?? [:]
            let migrated = fixture.name.contains(".legacy.")
            let others = Set(fixture.rawStrokes.keys).subtracting(drawn)
            XCTAssertEqual(Set(after.keys), migrated ? [] : others, "\(fixture.name): the other strokes remain")
            if !migrated {
                for id in others {
                    XCTAssertEqual(after[id]?.serialized(), fixture.rawStrokes[id]?.serialized(), "\(fixture.name): \(id) byte for byte")
                }
            }
        }
    }

    // MARK: - 3. The 1.0 sync engine

    private func makeEngine() {
        if let previous = directory { try? FileManager.default.removeItem(at: previous) }
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Real10LedgerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        db = InMemoryCloudDatabase()
        sleeper = TestSleeper()
        let sleeper = self.sleeper!
        engine = SyncEngine(
            store: store,
            stateStore: SyncStateStore(fileURL: store.stateFileURL),
            database: db,
            clock: { Real10LedgerTests.now },
            sleep: { await sleeper.sleep($0) }
        )
    }

    private func startSynced() async {
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(engine.snapshot.status, .synced)
    }

    private func flushDebounce() async {
        await engine.waitUntilIdle()
        sleeper.advance()
        await engine.waitUntilIdle()
    }

    /// A record as the 1.1 device sends it: the fixture's own bytes as the page body.
    private func record(_ fixture: Fixture) throws -> CloudRecord {
        CloudRecord(
            recordType: InkPageRecord.recordType,
            recordName: fixture.pageId,
            changeTag: nil,
            systemFields: nil,
            fields: [
                "schema": .int(1),
                "updatedAt": .date(Self.now),
                "strokeCount": .int(Int64(fixture.rawStrokes.count)),
                "doc": .asset(try InkPageCodec.compress(fixture.data)),
                "app": .string("ios/1.1/1"),
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

    func testSyncOn10KeepsExtraAndDoesNotSendAPageBack() async throws {
        for fixture in try pages() where !fixture.name.contains(".legacy.") {
            makeEngine()
            await startSynced()
            let id = fixture.pageId
            db.simulateRemoteSave(try record(fixture))
            await engine.syncNow()
            // The file on the device is the 1.1 page, byte for byte (every item 1.0 read is written back).
            let file = try rawJSON(compressed: Data(contentsOf: store.url(for: id)))
            XCTAssertEqual(file.serialized(), fixture.json.serialized(), "\(fixture.name): the file is the 1.1 page")
            XCTAssertFalse(engine.state.dirty.contains(id), "\(fixture.name): an identical page is not sent back (F12)")
            XCTAssertEqual(savedCount(), 0, fixture.name)

            // The same page again (a new version tag): still nothing to send.
            db.simulateRemoteSave(try record(fixture))
            await engine.syncNow()
            XCTAssertFalse(engine.state.dirty.contains(id), "\(fixture.name): fetched again, not dirty")
            XCTAssertEqual(savedCount(), 0, fixture.name)

            // A stroke written on this 1.0 device into one of its own cells, saved and sent.
            var page = store.load(id)
            let layout = try XCTUnwrap(layout10(page), fixture.name)
            let cell: CellKey = id.hasPrefix("m1-") ? .memo : (id.hasPrefix("y-") ? .yearDay(month: 1, day: 1) : .grid)
            XCTAssertNotNil(layout.cells[cell], fixture.name)
            let points = (0..<4).map { InkPoint(x: 30 + CGFloat($0) * 6, y: 40, dtMs: $0 * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571) }
            let added = InkStroke(id: "real10-\(id)", cell: cell, tool: .pen, color: "#1f2937", t: 1_790_000_800_000, dev: "real-1.0", points: points)
            page.add(added)
            try engine.save(page)
            await flushDebounce()
            let sent = try XCTUnwrap(db.records[id], fixture.name)
            guard case .asset(let doc)? = sent.fields["doc"] else { return XCTFail("\(fixture.name): the record has a body") }
            let sentStrokes = try rawJSON(compressed: doc)["strokes"]?.objectValue ?? [:]
            XCTAssertEqual(sentStrokes.count, fixture.rawStrokes.count + 1, "\(fixture.name): every stroke and the new one are sent")
            for (strokeId, json) in fixture.rawStrokes {
                XCTAssertEqual(sentStrokes[strokeId]?.serialized(), json.serialized(), "\(fixture.name): \(strokeId) is sent unchanged")
            }
            XCTAssertNotNil(sentStrokes[added.id], fixture.name)
            XCTAssertFalse(engine.state.dirty.contains(id), fixture.name)
        }
    }

    // MARK: - 4. The 20,000 cap of 1.0 (F8)

    func testThe10EngineTruncatesTo20000WithoutTombstones() async throws {
        let url = try folder().appendingPathComponent("y-2026.n20500.json")
        let data = try Data(contentsOf: url)
        let json = try JSONValue.parse(data)
        let fixture = Fixture(name: "y-2026.n20500.json", data: data, json: json)
        let raw = fixture.rawStrokes
        XCTAssertEqual(raw.count, 20_500)
        let smallest = Set(raw.keys.sorted().prefix(20_000))

        makeEngine()
        await startSynced()
        db.simulateRemoteSave(try record(fixture))
        await engine.syncNow()
        let file = try rawJSON(compressed: Data(contentsOf: store.url(for: fixture.pageId)))
        let kept = file["strokes"]?.objectValue ?? [:]
        XCTAssertEqual(kept.count, 20_000, "1.0 keeps 20,000 strokes (unknown tools counted)")
        XCTAssertEqual(Set(kept.keys), smallest, "the smallest ids in key order")
        XCTAssertEqual(file["deleted"]?.objectValue?.count, 0, "no tombstone for what was dropped")
        XCTAssertFalse(engine.state.dirty.contains(fixture.pageId), "1.0 does not send its truncated page by itself")
        XCTAssertEqual(savedCount(), 0)

        // A stroke written on 1.0: it saves and sends 20,000 again (its own reader cuts the page
        // before sending), still without a tombstone.
        var page = store.load(fixture.pageId)
        XCTAssertEqual(page.strokes.count + page.unknownStrokes.count, 20_000)
        let points = [InkPoint(x: 10, y: 10, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)]
        page.add(InkStroke(id: "00000000-0000-4000-8000-000000000000", cell: .yearDay(month: 1, day: 1), tool: .pen, color: "#1f2937", t: 1_790_000_800_000, points: points))
        try engine.save(page)
        await flushDebounce()
        let sent = try XCTUnwrap(db.records[fixture.pageId])
        guard case .asset(let doc)? = sent.fields["doc"] else { return XCTFail("the record has a body") }
        let body = try rawJSON(compressed: doc)
        XCTAssertEqual(body["strokes"]?.objectValue?.count, 20_000, "1.0 sends at most 20,000")
        XCTAssertEqual(body["deleted"]?.objectValue?.count, 0, "and no tombstone")
        XCTAssertNotNil(body["strokes"]?.objectValue?["00000000-0000-4000-8000-000000000000"], "the new stroke (the smallest id) is among them")
    }
}
