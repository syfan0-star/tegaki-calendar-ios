@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import XCTest
@testable import TegakiCalendar

/// K-7 for 1.4 on the real 1.3 app (docs/M7D_CONTRACT.md §5.3 3): the ledger, the save's guard, the sync engine
/// and the joined window of the version on sale when 1.4 starts (commit 955fe678ec9f999ac45fac1b372f246e43c02f95,
/// build 26) on every compat-span fixture (TegakiKit/Tests/Fixtures/compat-span, the Monday and the Sunday shapes).
/// 1.3 rewrote the data code 1.1.1 froze (`InkLedger`, `InkCanvasView`, `SyncEngine`), so from 1.4 on the real 1.3 is
/// a partner of its own. The shape of Real123LedgerTests.swift, on what 1.3 ships:
/// - The one-page path (`testThe13LedgerDrawsOnlyItsOwnCells`, `testErasingEverythingOn13…`): each page laid out as
///   1.3's screen lays it out (`CalendarRootScreen.makePaper`: the week with its memo below 24:00, `freeMemo`), read
///   by `InkLedger(page:layout:)` and saved through `PageSlot.persist` (`SpanGuard.checkForSave`, then the write).
/// - The sync (`testSyncOn13…`): a live `SyncEngine` over a temporary `InkPageStore` and `InMemoryCloudDatabase`
///   merges each page from iCloud (`mergeRemote` through the pull and through 1.3's window fetch `pagesOpened`) and
///   saves it again through `PageSlot.persist`.
/// - The joined path (`testJoinedWindowsOn13…`), 1.3's default for the week and the day: a `SpanSession` window around
///   each week and day fixture page (Monday-start and Sunday-start weeks; the day with either week start), its pages
///   read (`prefetch`), the canvas's ledger made from the window as the canvas makes it (`ownerId` set), the window put
///   into the inbox as the canvas puts it, then closed with `saveAll()`.
/// Only the compat-span files: compat11's `from10` and `legacy` pages move their band on the way in (C10), so their
/// bytes do not come back as they were; tools/span-compat's v13 Probe and the current tree's tests read them.
///
/// It is NOT a test of the 1.4 app. CI's compat-v1.0 job takes 955fe67 out with `git archive`, copies this file into
/// its Tests/TegakiCalendarTests, generates that project and runs only
/// `-only-testing:TegakiCalendarTests/Real13LedgerTests` on the simulator, with the compat-span folder in
/// TEGAKI_COMPAT_SPAN_FIXTURES (xcodebuild: TEST_RUNNER_TEGAKI_COMPAT_SPAN_FIXTURES). It uses only what the 1.3 app and
/// its test target have (`TestSleeper` is the 1.3 test target's; no real sleep anywhere).
///
/// 1.4.3 (docs/R1_4_3_CONTRACT.md §8.3, 0g-30): the compat-span-143 folder too (TEGAKI_COMPAT_SPAN_143_FIXTURES), what the
/// month and the year write once they are joined sideways (fixtures 8–13: memo lines across a boundary, the move across
/// the shared day, the year's date column and December, lines deep in rows 1.4.3 lengthened). Month and year pages
/// only, so they go through the one-page path and the sync here, never through 1.3's joined window (week and day only).
@MainActor
final class Real13LedgerTests: XCTestCase {
    private var directory: URL!
    private var store: InkPageStore!
    private var db: InMemoryCloudDatabase!
    private var sleeper: TestSleeper!
    private var engine: SyncEngine!
    private var clock: Clock!
    /// The faults the sessions report (`SpanSession.onFault`: a repair by the guard is one) and the pages they hand to
    /// the engine (`willPersist`).
    private var faults: [String] = []
    private var persisted: [String] = []
    private var mismatches: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var savedOnPageMismatch: ((String) -> Void)!

    /// The time the engine and the sessions read; moved on between windows (the 30 s cooldown of the window fetch).
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_790_000_000)
    }

    override func setUp() async throws {
        faults = []
        persisted = []
        mismatches = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        savedOnPageMismatch = InkLedger.onPageMismatch
        InkLedger.onPageMismatch = { [weak self] in self?.mismatches.append($0) }
    }

    override func tearDown() async throws {
        SpanSession.onFault = savedOnFault
        InkLedger.onPageMismatch = savedOnPageMismatch
        engine?.onRemoteUpdate = nil
        engine?.onRemoteDelete = nil
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
        /// Every item of the file: strokes and items of tools 1.3 does not know.
        var rawItems: [String: JSONValue] { json["strokes"]?.objectValue ?? [:] }
    }

    /// What the 1.3 ledger draws of each file (the live strokes of the cells its layout has: the day's `grid` and
    /// `extra`, the week's `grid` and its memo `extra`, the month's day cells and `memo`, the year's day cells), counted
    /// from the files. The same numbers as tools/span-compat/v13/Version.swift's `expectedDrawn`. A new MANIFEST row
    /// needs its count here.
    private let drawnBy13: [String: Int] = [
        "d-2026-11-03.overhang-right.json": 2,       // grid and extra
        "m1-2026-11.overhang-right.json": 2,         // memo and the day cell 2026-11-08
        "w-2026-11-02.overhang-left.json": 1,
        "y-2026.overhang.json": 2,
        "w-2026-11-16.move-source.json": 1,
        "w-2026-11-23.move-destination.json": 1,
        "d-2026-11-09.extra-cross.json": 1,
        "d-2026-11-10.extra-cross.json": 1,
        "w-2026-12-14.week-memo.json": 4,            // the two grid strokes and the week memo's two (extra)
        "w-2026-12-21.week-memo-neighbor.json": 1,   // the week memo's one (extra)
        "w-2026-12-20.week-memo-sunday.json": 1,     // the Sunday start opens it; the week memo's one (extra)
        "w-2026-11-08.sunday-overhang.json": 2,      // the Sunday start opens it
        "m1-2026-11.overlap-day.json": 2,
        "m1-2026-12.overlap-day.json": 2,
        "w-2026-11-30.photo-text.json": 1,           // the photo and the text label are not strokes
        "w-2026-12-07.photo-text-neighbor.json": 1,
        // 1.4.3 (docs/R1_4_3_CONTRACT.md §8.3, 0g-30): compat-span-143, the month and the year joined sideways. One live
        // stroke per file, in a cell 1.3's layout has (its month laid out with the Monday start, as every month here).
        "m1-2026-11.memo-left.json": 1,              // 8: memo, x −160 … 260
        "m1-2026-10.move-source.json": 1,            // 9: the stroke left on 2026-11-01 (the moved one's tombstone is not a stroke)
        "m1-2026-11.move-destination.json": 1,       // 9: the copy on 2026-11-01
        "y-2026.december-right.json": 1,             // 10: 12-10, past the right edge
        "y-2027.date-column.json": 1,                // 10: 01-20, x −128 … 70
        "m1-2026-11.memo-sunday.json": 1,            // 11: memo (shape sunday: a Sunday-start window wrote it)
        "y-2026.row-floor.json": 1,                  // 12: 06-15, 350 lu down a row 1.4.3 lengthened
        "m1-2026-11.last-row.json": 1,               // 13: 2026-12-03, 600 lu down row 6
    ]

    /// The folder an environment variable names (xcodebuild: TEST_RUNNER_<name>).
    private func folder(_ name: String) throws -> URL {
        guard let path = ProcessInfo.processInfo.environment[name], !path.isEmpty else {
            XCTFail("\(name) is not set (xcodebuild: TEST_RUNNER_\(name))")
            throw CocoaError(.fileNoSuchFile)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// compat-span (TEGAKI_COMPAT_SPAN_FIXTURES) and, since 1.4.3, compat-span-143 (TEGAKI_COMPAT_SPAN_143_FIXTURES: the month
    /// and the year joined sideways, docs/R1_4_3_CONTRACT.md §8.3). Both are needed: every row of the expectations must be read.
    private func folders() throws -> [URL] {
        [try folder("TEGAKI_COMPAT_SPAN_FIXTURES"), try folder("TEGAKI_COMPAT_SPAN_143_FIXTURES")]
    }

    /// Every file each folder's MANIFEST lists ("<file> <fixture> <monday|sunday>" after the "#" lines), in its order,
    /// compat-span's first.
    private func fixtures() throws -> [Fixture] {
        var out: [Fixture] = []
        for url in try folders() {
            let text = try String(contentsOf: url.appendingPathComponent("MANIFEST"), encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) where !line.hasPrefix("#") {
                let parts = line.split(separator: " ")
                XCTAssertEqual(parts.count, 3, "MANIFEST line \"\(line)\"")
                guard parts.count == 3 else { continue }
                let name = String(parts[0])
                let data = try Data(contentsOf: url.appendingPathComponent(name))
                out.append(Fixture(name: name, shape: String(parts[2]), data: data, json: try JSONValue.parse(data)))
            }
        }
        XCTAssertGreaterThanOrEqual(out.count, 24, "the 16 compat-span files (S1's 13 and the week memo's 3) and compat-span-143's 8 are there")
        XCTAssertEqual(Set(out.map(\.name)).count, out.count, "no file name is in both folders")
        return out
    }

    /// The "now" of the one-page layouts (the engine's clock starts here too).
    private static let layoutNow = Date(timeIntervalSince1970: 1_790_000_000)

    private static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// The week start a 1.3 device that opens the page has set: a week page of a Sunday the Sunday start (K-11).
    private static func weekStart(of pageId: String) -> WeekStart {
        if pageId.hasPrefix("w-"), let day = DayKey(ymd: String(pageId.dropFirst(2))), day.weekday == 0 { return .sunday }
        return .monday
    }

    /// The 1.3 layout of the page as its one-page screen makes it (`CalendarRootScreen.makePaper`: no event, the page's
    /// ink bottoms, Japan's holidays; the week with its memo below 24:00).
    private func layout13(_ page: InkPage) -> (any PageLayout)? {
        guard let parsed = PageNavigation.parse(pageId: page.pageId) else { return nil }
        let paper = CalendarRootScreen.makePaper(kind: parsed.kind, focus: parsed.focus, events: [], inkBottoms: page.inkBottoms(),
                                                 now: Self.layoutNow, holidays: .japan, weekStart: Self.weekStart(of: page.pageId))
        return paper.layout
    }

    // MARK: - 0. Every row has its expectation

    func testEveryRowHasItsCount() throws {
        let all = try fixtures()
        XCTAssertEqual(Set(all.map(\.name)), Set(drawnBy13.keys),
                       "every MANIFEST row has its count in drawnBy13")
        XCTAssertEqual(all.filter { $0.shape == "sunday" }.map(\.name),
                       ["w-2026-12-20.week-memo-sunday.json", "w-2026-11-08.sunday-overhang.json", "m1-2026-11.memo-sunday.json"])
    }

    // MARK: - 1. What the 1.3 ledger draws, and its save on the one-page path

    func testThe13LedgerDrawsOnlyItsOwnCells() throws {
        for fixture in try fixtures() {
            let page = try InkPageCodec.decode(fixture.data)
            let layout = try XCTUnwrap(layout13(page), fixture.name)
            XCTAssertEqual(layout.pageId, page.pageId, "\(fixture.name): 1.3 opens this page")
            let ledger = InkLedger(page: page, layout: layout)
            XCTAssertEqual(ledger.page, page, "\(fixture.name): nothing moved on the way in (band migration)")
            XCTAssertEqual(try InkPageCodec.encode(ledger.page), fixture.data, "\(fixture.name): the ledger's page writes back the same bytes")
            let drawing = ledger.drawing()
            let drawn = drawing.strokes.compactMap { ledger.id(of: $0) }
            XCTAssertEqual(drawn.count, drawing.strokes.count, "\(fixture.name): every drawn stroke is known to the ledger")
            let own = ledger.page.liveStrokes.filter { layout.cells[$0.cell] != nil }.map(\.id)
            XCTAssertEqual(Set(drawn), Set(own), "\(fixture.name): 1.3 draws the strokes of its own cells, overhanging or not")
            XCTAssertEqual(drawn.count, drawnBy13[fixture.name], "\(fixture.name): the count written out")
            // Nothing of a tool 1.3 does not know is drawn; the items stay in the page.
            XCTAssertTrue(Set(drawn).isDisjoint(with: page.unknownStrokes.keys), fixture.name)
            for id in page.unknownStrokes.keys {
                XCTAssertNil(ledger.paperBounds(of: id), "\(fixture.name): \(id) is not a stroke the lasso can take")
            }
            for stroke in ledger.page.liveStrokes where layout.cells[stroke.cell] != nil {
                // Opening the page asks for no more room: the layout made from the page's ink already has it.
                XCTAssertFalse(ledger.needsMoreRoom(stroke), "\(fixture.name): \(stroke.id) needs no more room")
                XCTAssertNotNil(ledger.paperBounds(of: stroke.id), "\(fixture.name): \(stroke.id) has bounds (the lasso reaches it)")
            }
            if page.pageId.hasPrefix("d-") {
                XCTAssertEqual(layout.cells[.extra]?.height, 6000, "\(fixture.name): the free memo is open to 6,000 lu (1.1.1)")
            }
            if page.pageId.hasPrefix("w-") {
                XCTAssertNotNil(layout.cells[.extra], "\(fixture.name): 1.3's week has its memo below 24:00 (freeMemo)")
            }

            // 1.3's one save (both paths): the guard finds nothing to repair, and the page written is the file's.
            var written: InkPage?
            let outcome = PageSlot.persist(ledger.page, added: [], mode: .release,
                                           willWrite: { _ in XCTFail("\(fixture.name): the guard repaired the page") },
                                           write: { written = $0 })
            XCTAssertEqual(outcome, .saved, "\(fixture.name): SpanGuard.checkForSave lets the page through as it is")
            XCTAssertEqual(written, page, fixture.name)
            XCTAssertEqual(try written.map(InkPageCodec.encode), fixture.data, "\(fixture.name): the save writes the same bytes")
        }
        XCTAssertEqual(mismatches, [])
    }

    // MARK: - 2. Erasing everything on the 1.3 canvas (the one-page path)

    func testErasingEverythingOn13KeepsTheOtherItemsByteForByte() throws {
        for fixture in try fixtures() {
            let page = try InkPageCodec.decode(fixture.data)
            let layout = try XCTUnwrap(layout13(page), fixture.name)
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

    // MARK: - 3. The 1.3 sync engine

    /// The engine may outlive the test (a task still asleep in the sleeper), so nothing here holds the test.
    private func makeEngine() {
        if let previous = directory { try? FileManager.default.removeItem(at: previous) }
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Real13LedgerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        db = InMemoryCloudDatabase()
        sleeper = TestSleeper()
        clock = Clock()
        let sleeper = self.sleeper!
        let clock = self.clock!
        engine = SyncEngine(
            store: store,
            stateStore: SyncStateStore(fileURL: store.stateFileURL),
            database: db,
            clock: { clock.now },
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

    /// Wakes the engine's sleeps until none is left. 1.3's debounce sleeps again when another save came during its
    /// sleep (`scheduleDebouncedPush`: the generation moved on), so a window that saves two or more pages needs a
    /// second wake before the push; one wake left those pages dirty (r14-q-m1 run 44725911787, compat-v1.0).
    private func flushDebounce() async {
        await engine.waitUntilIdle()
        var wakes = 0
        while sleeper.waiting > 0 {
            wakes += 1
            guard wakes <= 8 else {
                XCTFail("the engine still sleeps after 8 wakes (sleeps so far: \(sleeper.recorded))")
                return
            }
            await sleeper.advance()
            await engine.waitUntilIdle()
        }
    }

    /// A record as another 1.3 device sends it: the fixture's own bytes as the page body.
    private func record(_ fixture: Fixture) throws -> CloudRecord {
        let page = try InkPageCodec.decode(fixture.data)
        return CloudRecord(
            recordType: InkPageRecord.recordType,
            recordName: fixture.pageId,
            changeTag: nil,
            systemFields: nil,
            fields: [
                "schema": .int(1),
                "updatedAt": .date(clock.now),
                "strokeCount": .int(Int64(page.liveStrokeCount)),
                "doc": .asset(try InkPageCodec.compress(fixture.data)),
                "app": .string("ios/1.3/26"),
            ]
        )
    }

    /// The JSON of a page body (a file on the device or a record's asset), without the reader's caps.
    private func rawJSON(compressed: Data) throws -> JSONValue {
        try JSONValue.parse(InkPageCodec.decompress(compressed))
    }

    private func count(_ operation: InMemoryCloudDatabase.Operation) -> Int {
        db.calls.filter { $0 == operation }.count
    }

    /// The body iCloud holds for `id` now.
    private func sentJSON(_ id: String, _ name: String) throws -> JSONValue? {
        let sent = try XCTUnwrap(db.records[id], name)
        guard case .asset(let doc)? = sent.fields["doc"] else {
            XCTFail("\(name): the record has a body")
            return nil
        }
        return try rawJSON(compressed: doc)
    }

    func testSyncOn13KeepsEveryItemAndDoesNotSendAPageBack() async throws {
        for fixture in try fixtures() {
            makeEngine()
            await startSynced()
            let id = fixture.pageId
            db.simulateRemoteSave(try record(fixture))
            await engine.syncNow()
            // The file on the device is the page another 1.3 device sent, byte for byte (every item read is written back).
            let fileURL = store.url(for: id)
            let file = try rawJSON(compressed: Data(contentsOf: fileURL))
            XCTAssertEqual(file.serialized(), fixture.json.serialized(), "\(fixture.name): the file is the page sent")
            XCTAssertFalse(engine.state.dirty.contains(id), "\(fixture.name): an identical page is not sent back")
            XCTAssertEqual(count(.save), 0, fixture.name)
            let fileBytes = try Data(contentsOf: fileURL)

            // The same page again (a new version tag), fetched by 1.3's window fetch (`pagesOpened`, the joined path's):
            // merged, nothing changes, nothing to send.
            db.simulateRemoteSave(try record(fixture))
            let fetches = count(.fetchRecords)
            engine.pagesOpened([id])
            await engine.waitUntilIdle()
            XCTAssertEqual(count(.fetchRecords), fetches + 1, "\(fixture.name): the window fetch ran")
            XCTAssertEqual(try Data(contentsOf: fileURL), fileBytes, "\(fixture.name): fetched again, the file is the same bytes")
            XCTAssertFalse(engine.state.dirty.contains(id), "\(fixture.name): fetched again, not dirty")
            XCTAssertEqual(count(.save), 0, fixture.name)

            // Saved again as it is through 1.3's one save (`PageSlot.persist`: the guard, then the engine): the same file,
            // and what goes to iCloud is the page as it came.
            let loaded = store.load(id)
            let again = PageSlot.persist(loaded, added: [], mode: .release,
                                         willWrite: { _ in XCTFail("\(fixture.name): the guard repaired the page") },
                                         write: { try self.engine.save($0) })
            XCTAssertEqual(again, .saved, "\(fixture.name): SpanGuard.checkForSave lets the page through as it is")
            XCTAssertEqual(try Data(contentsOf: fileURL), fileBytes, "\(fixture.name): saved again, the same bytes")
            await flushDebounce()
            XCTAssertEqual(try sentJSON(id, fixture.name)?.serialized(), fixture.json.serialized(), "\(fixture.name): sent as it came")
            XCTAssertFalse(engine.state.dirty.contains(id), fixture.name)

            // A stroke written on this 1.3 device into one of its own cells (one-page path), saved and sent.
            var page = store.load(id)
            let layout = try XCTUnwrap(layout13(page), fixture.name)
            let cell: CellKey = id.hasPrefix("m1-") ? .memo : (id.hasPrefix("y-") ? .yearDay(month: 1, day: 1) : .grid)
            XCTAssertNotNil(layout.cells[cell], fixture.name)
            let points = (0..<4).map { InkPoint(x: 30 + CGFloat($0) * 6, y: 40, dtMs: $0 * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571) }
            let added = InkStroke(id: "real13-\(id)", cell: cell, tool: .pen, color: "#1f2937", t: 1_792_000_000_000, dev: "real-1.3", points: points)
            page.add(added)
            let outcome = PageSlot.persist(page, added: [added.id], mode: .release,
                                           willWrite: { _ in XCTFail("\(fixture.name): the guard repaired the page") },
                                           write: { try self.engine.save($0) })
            XCTAssertEqual(outcome, .saved, fixture.name)
            await flushDebounce()
            let body = try XCTUnwrap(try sentJSON(id, fixture.name), fixture.name)
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

    // MARK: - 4. The joined path (1.3's default for the week and the day)

    /// The windows of 1.3's screen: a session per kind and week start (K-11), sized for a device and an orientation
    /// (`ScreenPaths.makeSession` passes `overviewCap: true`).
    private struct Opening {
        let kind: PageKind
        let weekStart: WeekStart
        let deviceClass: SpanDeviceClass
        let orientation: SpanOrientation
    }

    func testJoinedWindowsOn13KeepEveryPageByteForByte() async throws {
        let all = try fixtures()
        // The week and day files (one per page id) come in from iCloud, as another 1.3 device sent them.
        let joined = all.filter { $0.pageId.hasPrefix("w-") || $0.pageId.hasPrefix("d-") }
        XCTAssertEqual(Set(joined.map(\.pageId)).count, joined.count, "one week or day file per page id")
        let byPage = Dictionary(joined.map { ($0.pageId, $0) }, uniquingKeysWith: { first, _ in first })
        makeEngine()
        await startSynced()
        for fixture in joined { db.simulateRemoteSave(try record(fixture)) }
        await engine.syncNow()
        var files: [String: Data] = [:]
        for fixture in joined {
            let data = try Data(contentsOf: store.url(for: fixture.pageId))
            XCTAssertEqual(try rawJSON(compressed: data).serialized(), fixture.json.serialized(), "\(fixture.name): the file is the page sent")
            files[fixture.pageId] = data
        }
        XCTAssertEqual(engine.state.dirty, [], "nothing to send after the pull")
        XCTAssertEqual(count(.save), 0)

        let sessionSleeper = TestSleeper()
        let clock = self.clock!
        let devices: [(SpanDeviceClass, SpanOrientation)] = [(.iPad11, .portrait), (.iPhone, .landscape)]
        var number = 0
        var windows = 0
        for (deviceClass, orientation) in devices {
            var openings: [(Opening, Fixture)] = []
            for fixture in joined {
                if fixture.pageId.hasPrefix("w-") {
                    // A Monday week on a Monday-start device, a Sunday week on a Sunday-start one.
                    let start: WeekStart = fixture.shape == "sunday" ? .sunday : .monday
                    openings.append((Opening(kind: .week, weekStart: start, deviceClass: deviceClass, orientation: orientation), fixture))
                } else {
                    for start in [WeekStart.monday, .sunday] {
                        openings.append((Opening(kind: .day, weekStart: start, deviceClass: deviceClass, orientation: orientation), fixture))
                    }
                }
            }
            XCTAssertTrue(openings.contains { $0.0.kind == .week && $0.0.weekStart == .monday }, "Monday-start weeks")
            XCTAssertTrue(openings.contains { $0.0.kind == .week && $0.0.weekStart == .sunday }, "Sunday-start weeks")

            for (o, focus) in openings {
                number += 1
                clock.now = clock.now.addingTimeInterval(60) // past the 30 s cooldown: each window fetches its pages
                let what = "\(focus.name) (\(o.kind) window, \(o.weekStart) start, \(o.deviceClass) \(o.orientation))"
                let day = try XCTUnwrap(PageNavigation.parse(pageId: focus.pageId)?.focus, what)
                faults = []
                persisted = []
                let session = SpanSession(kind: o.kind, weekStart: o.weekStart, focus: day, sync: engine, deviceClass: o.deviceClass,
                                          orientation: o.orientation, number: number,
                                          context: SpanSession.PaperContext(now: clock.now, calendar: Self.tokyo), overviewCap: true,
                                          sleep: { await sessionSleeper.sleep($0) }, clock: { clock.now })
                engine.onRemoteUpdate = { [weak session] in session?.remoteUpdated($0) }
                engine.onRemoteDelete = { [weak session] in session?.remoteDeleted($0) }
                session.willPersist = { [weak self] in self?.persisted.append($0) }
                XCTAssertEqual(session.focusPageId, focus.pageId, "\(what): the window is around the page")

                // The window's pages read, and the window fetch of 1.3 (`pagesOpened`) done: nothing new comes in.
                let fetches = count(.fetchRecords)
                await session.prefetch()
                await engine.waitUntilIdle()
                XCTAssertEqual(count(.fetchRecords), fetches + 1, "\(what): the window fetch ran")
                XCTAssertFalse(session.hasUnreadPages, what)
                XCTAssertFalse(session.fallsBackToOnePage, what)
                XCTAssertGreaterThanOrEqual(session.pageIds.count, 3, "\(what): a page on each side")
                XCTAssertEqual(session.window.pageIds, session.pageIds, "\(what): every page is in the window")
                XCTAssertEqual(session.window.skippedPageIds, [], what)
                XCTAssertEqual(session.window.migratedPageIds, [], "\(what): nothing moved on the way in (band migration)")
                XCTAssertEqual(session.layout.pages.map(\.pageId), session.pageIds, what)

                // Each page as it is on file; the window holds every stroke, item and tombstone of every page.
                var live = 0, unknown = 0, tombstones = 0, expectedDrawn = 0
                for id in session.pageIds {
                    let slotPage = try XCTUnwrap(session.page(id), "\(what): \(id)")
                    if let file = byPage[id] {
                        XCTAssertEqual(slotPage, try InkPageCodec.decode(file.data), "\(what): \(id) is read as it is on file")
                        expectedDrawn += try XCTUnwrap(drawnBy13[file.name], file.name)
                    } else {
                        XCTAssertEqual(slotPage.liveStrokeCount + slotPage.unknownStrokes.count + slotPage.deleted.count, 0, "\(what): \(id) is empty")
                    }
                    XCTAssertEqual(session.slots[id]?.dirty, false, "\(what): opening the window dirties nothing (\(id))")
                    XCTAssertEqual(session.slots[id]?.added, [], what)
                    // 1.3's guard of the save on every page of the window: nothing to repair.
                    XCTAssertEqual(SpanGuard.checkForSave(slotPage, added: session.slots[id]?.added ?? [], mode: session.guardMode), .ok,
                                   "\(what): SpanGuard.checkForSave repairs nothing on \(id)")
                    let range = SpanComposer.extract(pageId: id, from: session.window)
                    XCTAssertFalse(range.contentDiffers(from: slotPage), "\(what): the window's part of \(id) is the page")
                    live += slotPage.liveStrokeCount
                    unknown += slotPage.unknownStrokes.keys.filter { slotPage.deleted[$0] == nil }.count
                    tombstones += slotPage.deleted.count
                }
                let windowPage = session.window.ledgerPage
                XCTAssertEqual(windowPage.liveStrokeCount, live, "\(what): every live stroke is in the window")
                XCTAssertEqual(windowPage.unknownStrokes.count, unknown, "\(what): every item of an unknown tool is in the window")
                XCTAssertEqual(windowPage.deleted.count, tombstones, "\(what): every tombstone is in the window")

                // The canvas's ledger on the window, as the canvas makes it: it draws exactly 1.3's strokes of each page.
                let ledger = InkLedger(page: windowPage, layout: session.layout)
                ledger.ownerId = { [weak session] cell in session?.ownerId(for: cell) ?? InkStroke.newId() }
                XCTAssertEqual(ledger.page, windowPage, "\(what): nothing moved in the ledger")
                let drawing = ledger.drawing()
                let drawn = drawing.strokes.compactMap { ledger.id(of: $0) }
                XCTAssertEqual(drawn.count, drawing.strokes.count, what)
                XCTAssertEqual(drawn.count, expectedDrawn, "\(what): the window draws what 1.3 draws of each page")
                XCTAssertEqual(Set(drawn), Set(windowPage.liveStrokes.filter { session.layout.cells[$0.cell] != nil }.map(\.id)), what)
                for stroke in windowPage.liveStrokes {
                    let owner = session.window.owner(ofStroke: stroke)
                    XCTAssertNotNil(owner, "\(what): \(stroke.id) reaches its page")
                    XCTAssertTrue(owner.map { session.pageIds.contains($0.page) } ?? false, "\(what): \(stroke.id)'s page is in the window")
                }
                // The canvas puts its window into the inbox (the safety net's source at the save).
                session.inbox.put([], unrouted: [], window: session.window.with(ledgerPage: ledger.page), basis: session.windowVersion)

                // Closed: the boundary's save writes nothing, every file stays byte for byte, nothing to send.
                XCTAssertEqual(session.saveAll(), [], what)
                XCTAssertEqual(persisted, [], "\(what): no page was dirty, none was saved")
                XCTAssertEqual(faults, [], "\(what): no fault (no repair, no recovery by the safety net)")
                XCTAssertEqual(session.records, [], what)
                for id in session.pageIds {
                    if let data = files[id] {
                        XCTAssertEqual(try Data(contentsOf: store.url(for: id)), data, "\(what): \(id) is the same bytes")
                    } else {
                        XCTAssertFalse(store.exists(id), "\(what): no file is made for the empty page \(id)")
                    }
                }
                XCTAssertEqual(engine.state.dirty, [], "\(what): nothing to send")

                // Each page saved again through the window's save (`PageSlot.persist`: the guard, then the engine): no
                // repair, the same bytes, and the page iCloud gets is the page as it came.
                let onFile = session.pageIds.filter { files[$0] != nil }
                for id in onFile { session.editSlotForTesting(id) { _ in } }
                XCTAssertEqual(session.saveAll(), [], what)
                XCTAssertEqual(Set(persisted), Set(onFile), "\(what): every page on file went through the guard")
                XCTAssertEqual(faults, [], "\(what): the guard repaired nothing")
                XCTAssertEqual(session.records, [], what)
                for id in onFile {
                    XCTAssertEqual(try Data(contentsOf: store.url(for: id)), files[id], "\(what): \(id) saved again, the same bytes")
                    XCTAssertEqual(session.slots[id]?.dirty, false, what)
                }
                await flushDebounce()
                for id in onFile {
                    XCTAssertEqual(try sentJSON(id, what)?.serialized(), byPage[id]?.json.serialized(), "\(what): \(id) is sent as it came")
                }
                XCTAssertEqual(engine.state.dirty, [], what)

                engine.onRemoteUpdate = nil
                engine.onRemoteDelete = nil
                windows += 1
            }
        }
        XCTAssertEqual(windows, 2 * (joined.filter { $0.pageId.hasPrefix("w-") }.count + 2 * joined.filter { $0.pageId.hasPrefix("d-") }.count))
        XCTAssertEqual(mismatches, [])
    }
}
