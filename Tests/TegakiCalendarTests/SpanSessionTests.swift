@_spi(SpanLedger) import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §10.2 row S, §3.4, §3.5, §3.7, §3.8, §3.15, §6.1, §6.3, D6, D7, D8, D14, D17, D18,
// D20): `SpanSession` on its own, over a live `SyncEngine` (a temporary `InkPageStore`, `InMemoryCloudDatabase`,
// `TestSleeper` for every wait, a fixed clock), with a stand-in for the canvas's ledger on the joined path
// (`JoinedLedgerStandIn`: the window's virtual page edited as `InkLedger` edits it — owner ids, a journal of
// live removals — put into the session's inbox as the canvas will). No real sleep anywhere (§3.16); the
// cautions of `TestSleeper` (docs/R1_2_3.md §4.3) hold: one `advance()` at a time, never while the fake has an
// operation paused. The screen's own calls (its path switch, the background, the export) come with the screen
// wave; here they are the session's halves (`saveAll`, a new session).

// MARK: - The test bed (shared with ScreenEraseTests)

/// A live engine over a temporary store and the fake database, its sleeper, and a second sleeper for the
/// sessions' timers (so the engine's debounce and the session's save timer are advanced apart).
@MainActor
final class SessionTestBed {
    let directory: URL
    let store: InkPageStore
    let stateStore: SyncStateStore
    let db = InMemoryCloudDatabase()
    let engineSleeper = TestSleeper()
    let sessionSleeper = TestSleeper()
    private(set) var engine: SyncEngine!
    var now = Date(timeIntervalSince1970: 1_790_000_000)
    /// Files made immutable by `failSaves(of:)`, set back by `tearDown()`.
    private var locked: [URL] = []

    init(_ name: String) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = InkPageStore(directory: directory)
        stateStore = SyncStateStore(fileURL: store.stateFileURL)
        let sleeper = engineSleeper
        engine = SyncEngine(store: store, stateStore: stateStore, database: db,
                            clock: { [weak self] in self?.now ?? Date(timeIntervalSince1970: 1_790_000_000) },
                            sleep: { await sleeper.sleep($0) })
        let made: SyncEngine = engine
        sleeper.settle = { [weak made] in await made?.waitUntilIdle() }
    }

    func tearDown() {
        engine?.onRemoteUpdate = nil
        engine?.onRemoteDelete = nil
        for url in locked {
            try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
        }
        try? FileManager.default.removeItem(at: directory)
    }

    var status: SyncStatus { engine.snapshot.status }

    func startSynced(file: StaticString = #filePath, line: UInt = #line) async {
        engine.start()
        await engine.waitUntilIdle()
        XCTAssertEqual(status, .synced, file: file, line: line)
    }

    /// Lets the engine's 1.5 s debounce pass and its push finish.
    func flushDebounce() async {
        await engine.waitUntilIdle()
        await engineSleeper.advance()
        await engine.waitUntilIdle()
    }

    /// Lets the sessions' timers run (the save timer: 1.5 s): a timer scheduled on this turn first reaches its sleep.
    func flushSessionTimers() async {
        for _ in 0..<20 { await Task.yield() }
        await sessionSleeper.advance()
        await engine.waitUntilIdle()
    }

    /// The engine's `save` of `pageId` throws from now on: its file is made immutable, so the atomic write
    /// (a temporary file renamed over it) is refused, while reading it still works (no `.bak`).
    func failSaves(of pageId: String) throws {
        let url = store.url(for: pageId)
        if !FileManager.default.fileExists(atPath: url.path) {
            try store.save(InkPage(pageId: pageId))
        }
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
        locked.append(url)
    }

    /// `failSaves(of:)` undone.
    func allowSaves(of pageId: String) {
        let url = store.url(for: pageId)
        try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
    }

    /// A three-point pen stroke in `cell`, near (x, y) of the cell (cell-relative points).
    func stroke(_ id: String, cell: CellKey = .grid, x: CGFloat = 100, y: CGFloat = 100, t: Int = 1_790_000_001_000) -> InkStroke {
        let points = (0..<3).map { i in
            InkPoint(x: x + CGFloat(i * 5), y: y + CGFloat(i), dtMs: i * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, points: points)
    }

    func page(_ id: String, _ strokeIds: [String]) -> InkPage {
        var page = InkPage.empty(pageId: id)
        for (index, strokeId) in strokeIds.enumerated() {
            page.add(stroke(strokeId, x: 100 + CGFloat(index) * 40, t: 1_790_000_001_000 + index))
        }
        return page
    }

    /// A record as another device would send it.
    func record(_ page: InkPage) throws -> CloudRecord {
        try InkPageRecord.make(page, seen: nil)
    }

    func live(_ pageId: String) -> Set<String> {
        Set(store.load(pageId).liveStrokeIds)
    }

    /// A session of the bed's engine, its timers on `sessionSleeper`, the engine's two hooks routed to it as the
    /// screen routes them.
    func session(_ kind: PageKind = .week, focus: DayKey, weekStart: WeekStart = .monday, number: Int = 1, radius: Int? = nil,
                 deviceClass: SpanDeviceClass = .iPad11, eventSource: ((DayKey, DayKey) -> [LayoutEvent])? = nil) -> SpanSession {
        let sleeper = sessionSleeper
        let session = SpanSession(kind: kind, weekStart: weekStart, focus: focus, sync: engine, deviceClass: deviceClass,
                                  orientation: .portrait, number: number,
                                  context: SpanSession.PaperContext(now: now, calendar: SessionTestBed.tokyo), radius: radius,
                                  eventSource: eventSource,
                                  sleep: { await sleeper.sleep($0) },
                                  clock: { [weak self] in self?.now ?? Date(timeIntervalSince1970: 1_790_000_000) })
        engine.onRemoteUpdate = { [weak session] in session?.remoteUpdated($0) }
        engine.onRemoteDelete = { [weak session] in session?.remoteDeleted($0) }
        return session
    }

    static var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    /// Yields until `condition` holds (work paused inside the fake runs on the main actor too).
    func yieldUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("the condition did not hold after 10,000 yields", file: file, line: line)
    }
}

// MARK: - The canvas's ledger on the joined path, as values

/// Seeded ids as `CompatFixtures.SeededIds` makes them (TegakiKit/Tests/CompatFixtures), so the compat-span
/// fixtures come out byte for byte: xorshift, two words per id, the UUID's version and variant bits.
struct SeededIdsStandIn {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func nextUInt64() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }

    mutating func next() -> String {
        let a = nextUInt64()
        let b = nextUInt64()
        var bytes = (0..<8).map { UInt8(truncatingIfNeeded: a >> (56 - 8 * UInt64($0))) }
            + (0..<8).map { UInt8(truncatingIfNeeded: b >> (56 - 8 * UInt64($0))) }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let c = Array(hex)
        return String(c[0..<8]) + "-" + String(c[8..<12]) + "-" + String(c[12..<16]) + "-" + String(c[16..<20]) + "-" + String(c[20..<32])
    }
}

/// What the canvas's ledger does on the joined path (§3.3), as values over the session's window (the steps of
/// `SpanLedgerSim`, TegakiKit/Tests/CompatSpanFixtures): a new stroke in the cell `SpanLayout.drop` gives, with
/// the session's `ownerId`; an erase that tombstones and journals live ids only; the lasso's move (copies with
/// fresh owner ids, the originals tombstoned, one step); ↶'s copy. `put()` hands the journal to the session's
/// inbox as the canvas does (`SpanInbox.put(journal:window:basis:epoch:)`); `take()` loads the session's window
/// as the canvas does after a new `windowVersion`.
@MainActor
final class JoinedLedgerStandIn {
    let session: SpanSession
    private(set) var window: SpanVirtualPage
    /// The ledger's page (the virtual id, window names).
    var page: InkPage
    private(set) var journal: [SpanJournalEntry] = []
    private(set) var basis: Int
    private(set) var epoch: Int
    var ids: SeededIdsStandIn
    private(set) var clock: Int
    let dev: String?

    init(_ session: SpanSession, seed: UInt64 = 0x5A01_7777, firstTime: Int = 1_790_000_100_000, dev: String? = "span-test") {
        self.session = session
        window = session.window
        page = session.window.ledgerPage
        basis = session.windowVersion
        epoch = session.epoch
        ids = SeededIdsStandIn(seed: seed)
        clock = firstTime - 1
        self.dev = dev
        session.makeId = { [weak self] in self?.ids.next() ?? InkStroke.newId() }
        session.inbox.put([], unrouted: [], window: current, basis: basis)
    }

    /// The window holding what the ledger has now.
    var current: SpanVirtualPage { window.with(ledgerPage: page) }

    /// The session's window now (a new `windowVersion`): the ledger reloads it (its history is the canvas's).
    func take() {
        window = session.window
        page = session.window.ledgerPage
        basis = session.windowVersion
        epoch = session.epoch
        session.inbox.put([], unrouted: [], window: current, basis: basis)
    }

    func now() -> Int {
        clock += 1
        return clock
    }

    /// A new stroke through `points` (band lu): the centre of their bounds decides the owner and the cell.
    @discardableResult
    func draw(_ points: [CGPoint], size: CGFloat = 3.5, tool: InkTool = .pen, color: String = "#1f2937") -> InkStroke? {
        guard !points.isEmpty else { return nil }
        let layout = session.layout
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let center = CGPoint(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
        guard case .keep(let owner, let local) = layout.drop(center: center) else { return nil }
        let cell = SpanName.prefixed(local, page: owner)
        let origin = layout.cells[cell]?.origin ?? .zero
        let inkPoints = points.enumerated().map { i, p in
            InkPoint(x: p.x - origin.x, y: p.y - origin.y, dtMs: 8 * i, sizeW: size, sizeH: size, opacity: 1, force: 0.5, azimuth: 0.785, altitude: 1.2)
        }
        let t = now()
        let stroke = InkStroke(id: session.ownerId(for: cell), cell: cell, tool: tool, color: color, t: t, dev: dev, points: inkPoints)
        page.add(stroke)
        journal.append(SpanJournalEntry(added: [stroke], at: t))
        return stroke
    }

    /// A short stroke on page `pageId` near (x, y) of its `cell` (cell-relative).
    @discardableResult
    func draw(on pageId: String, cell: CellKey = .grid, x: CGFloat = 200, y: CGFloat = 300) -> InkStroke? {
        let windowCell = SpanName.prefixed(cell, page: pageId)
        guard let origin = session.layout.cells[windowCell]?.origin else { return nil }
        return draw([CGPoint(x: origin.x + x, y: origin.y + y), CGPoint(x: origin.x + x + 20, y: origin.y + y + 4),
                     CGPoint(x: origin.x + x + 40, y: origin.y + y)])
    }

    @discardableResult
    func erase(_ windowIds: [String], group: UUID? = nil) -> [String] {
        let live = windowIds.filter { page.isLive($0) }
        guard !live.isEmpty else { return [] }
        let t = now()
        page.remove(ids: live, at: t)
        journal.append(SpanJournalEntry(removed: live, at: t, group: group))
        return live
    }

    /// The lasso's move by `delta` (band lu), one step (`group`: a move across pages has one, §4.4).
    @discardableResult
    func move(_ windowIds: [String], by delta: CGVector, group: UUID? = nil) -> [InkStroke] {
        let layout = session.layout
        let originals = windowIds.compactMap { id in page.isLive(id) ? page.strokes[id] : nil }
        guard !originals.isEmpty else { return [] }
        let t = now()
        var clones: [InkStroke] = []
        for s in originals {
            let origin = layout.cells[s.cell]?.origin ?? .zero
            let bounds = s.paperBounds(cellOrigin: origin) ?? CGRect(origin: origin, size: .zero)
            let moved = bounds.offsetBy(dx: delta.dx, dy: delta.dy)
            let newCell = layout.inkCell(forCenter: CGPoint(x: moved.midX, y: moved.midY))
            let newOrigin = layout.cells[newCell]?.origin ?? .zero
            clones.append(s.translated(by: delta, from: origin, to: newCell, newCellOrigin: newOrigin, id: session.ownerId(for: newCell), at: t))
        }
        page.remove(ids: originals.map(\.id), at: t)
        for c in clones { page.add(c) }
        journal.append(SpanJournalEntry(added: clones, removed: originals.map(\.id), at: t, group: group))
        return clones
    }

    /// The journal into the session's inbox (with this ledger's window, basis and number); emptied.
    func put() {
        session.inbox.put(journal: journal, window: current, basis: basis, epoch: epoch)
        journal = []
    }

    /// `put()`, then the session takes the inbox at once (what its next turn does).
    func deliver() {
        put()
        session.drainInbox()
    }

    /// The window name of a stroke of real page `pageId` with real id `id`.
    func name(_ id: String, on pageId: String) -> String {
        SpanName.prefixed(id: id, page: pageId)
    }
}

// MARK: - The tests

@MainActor
final class SpanSessionTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!

    /// A window of five Monday weeks around 11/16 (iPad 11 portrait, R = 2): 11/2 … 11/30.
    private let w1102 = "w-2026-11-02"
    private let w1109 = "w-2026-11-09"
    private let w1116 = "w-2026-11-16"
    private let w1123 = "w-2026-11-23"
    private let w1130 = "w-2026-11-30"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)

    override func setUp() async throws {
        bed = try SessionTestBed("SpanSessionTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
    }

    override func tearDown() async throws {
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    /// A week session around 11/16 whose pages are read.
    private func openWeeks(number: Int = 1) async -> SpanSession {
        let session = bed.session(.week, focus: nov16, number: number)
        await session.prefetch()
        XCTAssertEqual(session.pageIds, [w1102, w1109, w1116, w1123, w1130])
        return session
    }

    // MARK: Compat-span (§6.3)

    /// §6.3, D10: the compat-span fixtures made again through the app's own save path — the window composed by
    /// `SpanSession`, the ledger's steps (`JoinedLedgerStandIn`, the same steps and seeds as the Kit's
    /// `CompatSpanFixtures.build`), the journal to `PageDelta`s through the inbox, `InkPage.add` / `remove` on
    /// the slots, the safety net, `PageSlot.persist` (the guard, then the live engine's `save` into a
    /// temporary `InkPageStore`) — and each file compared byte for byte with the committed one. A file that
    /// differs or is missing is written to `$TEGAKI_FIXTURE_OUT/compat-span/` and the test fails.
    func testSpanSessionWritesTheCompatSpanShapes() async throws {
        let base = 1_791_000_000_000
        let dev = "fixture-1.3"
        let fixtureNow = Date(timeIntervalSince1970: 1_790_000_000)
        var written: [String: Data] = [:]
        var sessions = 0

        // One window: a new bed (a store of its own), `pages` written to it first (the pages "on file"), a session of
        // radius 1 around `focus` (the Kit's three pages), the stand-in seeded as the Kit's sim. `dx` takes the Kit's
        // window x (its first page at 0) to this window.
        func open(_ kind: PageKind, _ weekStart: WeekStart = .monday, focus: String, firstOfKit: String, stored: [InkPage],
                  seed: UInt64, firstTime: Int, in bed: SessionTestBed) async throws -> (SpanSession, JoinedLedgerStandIn, CGFloat) {
            for page in stored { try bed.store.save(page) }
            bed.now = fixtureNow
            let parsed = try XCTUnwrap(PageNavigation.parse(pageId: focus))
            let session = bed.session(kind, focus: parsed.focus, weekStart: weekStart, number: 0, radius: 1)
            await session.prefetch()
            let ledger = JoinedLedgerStandIn(session, seed: seed, firstTime: firstTime, dev: dev)
            let dx = try XCTUnwrap(session.origin(ofPage: firstOfKit))
            sessions += 1
            return (session, ledger, dx)
        }
        func line(_ x0: CGFloat, _ x1: CGFloat, y: CGFloat, count: Int = 9, dx: CGFloat) -> [CGPoint] {
            (0..<count).map { i in CGPoint(x: dx + x0 + (x1 - x0) * CGFloat(i) / CGFloat(count - 1), y: y + CGFloat(i % 2) * 6) }
        }
        func draw(_ ledger: JoinedLedgerStandIn, _ points: [CGPoint], owner: String, cell: CellKey, tool: InkTool = .pen,
                  color: String = "#1f2937", size: CGFloat = 3.5, file: StaticString = #filePath, line: UInt = #line) throws -> InkStroke {
            let s = try XCTUnwrap(ledger.draw(points, size: size, tool: tool, color: color), "a fixture stroke was dropped", file: file, line: line)
            XCTAssertEqual(s.cell, SpanName.prefixed(cell, page: owner), file: file, line: line)
            return s
        }
        func keep(_ name: String, _ pageId: String, _ bed: SessionTestBed) throws {
            let compressed = try Data(contentsOf: bed.store.url(for: pageId))
            written[name] = try InkPageCodec.decompress(compressed)
        }
        func fresh() throws -> SessionTestBed {
            bed.tearDown()
            bed = try SessionTestBed("SpanSessionCompat")
            return bed
        }

        // 1. A Monday week 300 lu to the left, from the Sunday night of the week before.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.week, focus: "w-2026-11-02", firstOfKit: "w-2026-10-26", stored: [], seed: 0x5A01_0001,
                                            firstTime: base + 100, in: b)
            _ = try draw(l, line(1100, 1900, y: 1880, dx: dx), owner: "w-2026-11-02", cell: .grid)
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("w-2026-11-02.overhang-left.json", "w-2026-11-02", b)
        }
        // 1. A day to the right, in grid and in extra.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.day, focus: "d-2026-11-03", firstOfKit: "d-2026-11-02", stored: [], seed: 0x5A01_0002,
                                            firstTime: base + 200, in: b)
            _ = try draw(l, line(1690, 2300, y: 1000, dx: dx), owner: "d-2026-11-03", cell: .grid)
            _ = try draw(l, line(1690, 2300, y: 4000, dx: dx), owner: "d-2026-11-03", cell: .extra, color: "#dc2626")
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("d-2026-11-03.overhang-right.json", "d-2026-11-03", b)
        }
        // 1. A month to the right: November 8 and the memo.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.month, focus: "m1-2026-11", firstOfKit: "m1-2026-10", stored: [], seed: 0x5A01_0003,
                                            firstTime: base + 300, in: b)
            _ = try draw(l, line(2540, 3050, y: 260, dx: dx), owner: "m1-2026-11", cell: .day(DayKey(year: 2026, month: 11, day: 8)))
            _ = try draw(l, line(2540, 3050, y: 1400, dx: dx), owner: "m1-2026-11", cell: .memo, tool: .marker, color: "#fde047", size: 18)
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("m1-2026-11.overhang-right.json", "m1-2026-11", b)
        }
        // 1. A year: from December 20 to the right, January 20 below x 0.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.year, focus: "y-2026", firstOfKit: "y-2025", stored: [], seed: 0x5A01_0004,
                                            firstTime: base + 400, in: b)
            _ = try draw(l, line(2500, 3088, y: 1170, count: 8, dx: dx), owner: "y-2026", cell: .yearDay(month: 12, day: 20))
            _ = try draw(l, line(1300, 1660, y: 1170, count: 7, dx: dx), owner: "y-2026", cell: .yearDay(month: 1, day: 20))
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("y-2026.overhang.json", "y-2026", b)
        }
        // 2. A move across pages: two strokes on w-11-16, saved; the next session moves one a week on.
        do {
            let b = try fresh()
            let (first, l1, dx1) = try await open(.week, focus: "w-2026-11-16", firstOfKit: "w-2026-11-09", stored: [], seed: 0x5A01_0005,
                                                  firstTime: base + 500, in: b)
            _ = try draw(l1, line(1700, 1900, y: 800, count: 6, dx: dx1), owner: "w-2026-11-16", cell: .grid)
            _ = try draw(l1, line(2100, 2300, y: 1200, count: 6, dx: dx1), owner: "w-2026-11-16", cell: .grid, color: "#2563eb")
            l1.deliver()
            XCTAssertEqual(first.saveAll(), [])
            let (s, l, _) = try await open(.week, focus: "w-2026-11-16", firstOfKit: "w-2026-11-09", stored: [], seed: 0x5A01_0006,
                                           firstTime: base + 600, in: b)
            let moving = try XCTUnwrap(l.page.liveStrokes.min { $0.t < $1.t })
            let copies = l.move([moving.id], by: CGVector(dx: 1400, dy: 0))
            XCTAssertEqual(copies.map(\.cell.raw), ["w-2026-11-23|grid"])
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("w-2026-11-23.move-destination.json", "w-2026-11-23", b)
            try keep("w-2026-11-16.move-source.json", "w-2026-11-16", b)
        }
        // 3. The free memo (extra) across two days, one stroke owned by each.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.day, focus: "d-2026-11-10", firstOfKit: "d-2026-11-09", stored: [], seed: 0x5A01_0007,
                                            firstTime: base + 700, in: b)
            _ = try draw(l, line(600, 1300, y: 3500, dx: dx), owner: "d-2026-11-09", cell: .extra)
            _ = try draw(l, line(700, 1600, y: 5200, dx: dx), owner: "d-2026-11-10", cell: .extra, color: "#16a34a")
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("d-2026-11-09.extra-cross.json", "d-2026-11-09", b)
            try keep("d-2026-11-10.extra-cross.json", "d-2026-11-10", b)
        }
        // 5. A Sunday-start week, out on both sides.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.week, .sunday, focus: "w-2026-11-08", firstOfKit: "w-2026-11-01", stored: [], seed: 0x5A01_0008,
                                            firstTime: base + 800, in: b)
            _ = try draw(l, line(1100, 1900, y: 1840, dx: dx), owner: "w-2026-11-08", cell: .grid)
            _ = try draw(l, line(2300, 3100, y: 400, dx: dx), owner: "w-2026-11-08", cell: .grid, color: "#dc2626")
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("w-2026-11-08.sunday-overhang.json", "w-2026-11-08", b)
        }
        // 6. November 30 and December 1 on both month pages.
        do {
            let b = try fresh()
            let (s, l, dx) = try await open(.month, focus: "m1-2026-11", firstOfKit: "m1-2026-11", stored: [], seed: 0x5A01_0009,
                                            firstTime: base + 900, in: b)
            _ = try draw(l, line(230, 330, y: 960, count: 5, dx: dx), owner: "m1-2026-11", cell: .day(DayKey(year: 2026, month: 12, day: 1)))
            _ = try draw(l, line(30, 130, y: 940, count: 5, dx: dx), owner: "m1-2026-11", cell: .day(DayKey(year: 2026, month: 11, day: 30)))
            _ = try draw(l, line(1630, 1730, y: 85, count: 5, dx: dx), owner: "m1-2026-12", cell: .day(DayKey(year: 2026, month: 12, day: 1)), color: "#2563eb")
            _ = try draw(l, line(1430, 1530, y: 100, count: 5, dx: dx), owner: "m1-2026-12", cell: .day(DayKey(year: 2026, month: 11, day: 30)), color: "#2563eb")
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            try keep("m1-2026-11.overlap-day.json", "m1-2026-11", b)
            try keep("m1-2026-12.overlap-day.json", "m1-2026-12", b)
        }
        // 7. The photo and the text label of a later version, hand-written, in a window with the session's ink.
        do {
            let b = try fresh()
            let photoPage = try InkPageCodec.decode(Data(Self.photoTextJSON.utf8))
            let neighborPage = try InkPageCodec.decode(Data(Self.photoNeighborJSON.utf8))
            XCTAssertEqual(photoPage.unknownStrokes.count, 2)
            XCTAssertEqual(neighborPage.unknownStrokes.count, 1)
            let (s, l, dx) = try await open(.week, focus: "w-2026-11-30", firstOfKit: "w-2026-11-23", stored: [photoPage, neighborPage],
                                            seed: 0x5A01_000A, firstTime: base + 1000, in: b)
            let crossing = try draw(l, line(2300, 3100, y: 600, dx: dx), owner: "w-2026-11-30", cell: .grid)
            let handPen = "w-2026-11-30|" + Self.handPenId
            XCTAssertEqual(l.erase([handPen]), [handPen])
            let neighborStroke = try draw(l, line(3100, 3400, y: 1000, count: 6, dx: dx), owner: "w-2026-12-07", cell: .grid, color: "#2563eb")
            l.deliver()
            XCTAssertEqual(s.saveAll(), [])
            let beforeLeak = try InkPageCodec.decompress(Data(contentsOf: b.store.url(for: "w-2026-12-07")))
            // A leak into the neighbour's slot: its own window names (a stroke and the photo), another page's stroke and a
            // stripped alias. The guard strips the first two and drops the others; the file stays as before the leak.
            s.editSlotForTesting("w-2026-12-07") { page in
                page.strokes[neighborStroke.id] = neighborStroke
                page.unknownStrokes["w-2026-12-07|" + Self.neighborPhotoId] = page.unknownStrokes[Self.neighborPhotoId]
                page.strokes[crossing.id] = crossing
                page.deleted["span~a~1"] = base + 1999
            }
            XCTAssertEqual(s.saveAll(), [])
            XCTAssertEqual(faults.filter { $0.hasPrefix("repaired w-2026-12-07") }.count, 1, "the guard repaired the leak once")
            try keep("w-2026-11-30.photo-text.json", "w-2026-11-30", b)
            try keep("w-2026-12-07.photo-text-neighbor.json", "w-2026-12-07", b)
            XCTAssertEqual(written["w-2026-12-07.photo-text-neighbor.json"], beforeLeak)
        }

        XCTAssertEqual(sessions, 10)
        XCTAssertEqual(faults.filter { !$0.hasPrefix("repaired w-2026-12-07") }, [], "no safety net recovery and no other fault")
        XCTAssertEqual(written.count, 13)
        let folder = Self.compatSpanFolder
        let manifest = try String(contentsOf: folder.appendingPathComponent("MANIFEST"), encoding: .utf8)
        let names = manifest.split(separator: "\n").filter { !$0.hasPrefix("#") }.compactMap { $0.split(separator: " ").first.map(String.init) }
        XCTAssertEqual(Set(names), Set(written.keys), "the MANIFEST lists the files made here")
        for name in names {
            let ours = try XCTUnwrap(written[name])
            let committed = try? Data(contentsOf: folder.appendingPathComponent(name))
            if committed != ours {
                var note = "TEGAKI_FIXTURE_OUT is not set, nothing written"
                if let out = ProcessInfo.processInfo.environment["TEGAKI_FIXTURE_OUT"], !out.isEmpty {
                    let dir = URL(fileURLWithPath: out).appendingPathComponent("compat-span", isDirectory: true)
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    try? ours.write(to: dir.appendingPathComponent(name))
                    note = "written to \(dir.path)/\(name)"
                }
                XCTFail("compat-span \(name) differs from what the session's save path writes (\(note))")
            }
        }
    }

    /// `TegakiKit/Tests/Fixtures/compat-span/` of this checkout (from this file), or `$TEGAKI_COMPAT_SPAN_DIR`.
    private static var compatSpanFolder: URL {
        if let dir = ProcessInfo.processInfo.environment["TEGAKI_COMPAT_SPAN_DIR"], !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TegakiCalendarTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // the checkout
            .appendingPathComponent("TegakiKit/Tests/Fixtures/compat-span", isDirectory: true)
    }

    // Fixture 7's hand-written pages: the same text as `CompatSpanFixtures` (PLAN_PHOTO_TEXT.md:41).
    static let handPenId = "3f6c2a9e-1d4b-4e7a-8c5f-0a9b8c7d6e51"
    static let photoId = "9a1e5c7b-2f3d-4b6a-8e9c-1d2e3f4a5b62"
    static let textId = "c4d8e2f6-3a5b-4c7d-9e1f-2a3b4c5d6e73"
    static let neighborPhotoId = "5b7d9f1a-4c6e-4a8b-9d2f-3e4a5b6c7d84"
    static let photoDigest = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    static let photoTextJSON = """
    {"v":1,"pageId":"w-2026-11-30","updatedAt":1791000000003,"deleted":{},"strokes":{\
    "\(handPenId)":{"id":"\(handPenId)","cell":"grid","tool":"pen","color":"#1f2937","t":1791000000001,"dev":"fixture-1.2",\
    "pts":[300,700,0,3.5,3.5,1,0.5,0.785,1.2,340,706,8,3.5,3.5,1,0.5,0.785,1.2,380,700,16,3.5,3.5,1,0.5,0.785,1.2]},\
    "\(photoId)":{"id":"\(photoId)","cell":"grid","tool":"photo","t":1791000000002,"dev":"fixture-1.6",\
    "rect":[120,340,360,240],"img":"\(photoDigest)"},\
    "\(textId)":{"id":"\(textId)","cell":"grid","tool":"text","t":1791000000003,"dev":"fixture-1.6",\
    "rect":[1250,900,300,80],"text":"牛乳を買う"}}}
    """

    static let photoNeighborJSON = """
    {"v":1,"pageId":"w-2026-12-07","updatedAt":1791000000004,"deleted":{},"strokes":{\
    "\(neighborPhotoId)":{"id":"\(neighborPhotoId)","cell":"grid","tool":"photo","t":1791000000004,"dev":"fixture-1.6",\
    "rect":[-80,1500,320,200],"img":"\(photoDigest)"}}}
    """

    // MARK: Saving (D8, §3.4)

    /// D8: the pages that got strokes are saved first, in the window's order; the destination of a move across
    /// pages before its source; then the pages that only lost strokes. When the destination cannot be saved,
    /// its source is not saved either (two copies rather than none) and both stay dirty.
    func testSaveOrderAddsFirstAndDestinationFirst() async throws {
        try bed.engine.save(bed.page(w1102, ["a1"]))
        try bed.engine.save(bed.page(w1109, ["b1"]))
        try bed.engine.save(bed.page(w1130, ["d1"]))
        let session = await openWeeks()
        var order: [String] = []
        session.willPersist = { order.append($0) }
        let ledger = JoinedLedgerStandIn(session)
        // 11/2 only loses a1; 11/9 gets a stroke and loses b1 to 11/30 (one group); 11/16 gets a stroke.
        ledger.erase([ledger.name("a1", on: w1102)])
        ledger.draw(on: w1109)
        let group = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let origin1109 = try XCTUnwrap(session.origin(ofPage: w1109))
        let origin1130 = try XCTUnwrap(session.origin(ofPage: w1130))
        XCTAssertEqual(ledger.move([ledger.name("b1", on: w1109)], by: CGVector(dx: origin1130 - origin1109, dy: 0), group: group).count, 1)
        ledger.draw(on: w1116)
        ledger.deliver()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(order, [w1130, w1109, w1116, w1102], "the move's destination before its source, the added pages before the rest")
        XCTAssertEqual(bed.live(w1109).count, 1)
        XCTAssertFalse(bed.live(w1109).contains("b1"))
        XCTAssertEqual(bed.live(w1130).count, 2)

        // The other way, and the destination's save fails: the source keeps the stroke in its file.
        order = []
        let back = try XCTUnwrap(session.page(w1130)?.liveStrokes.first { $0.id != "d1" })
        try bed.failSaves(of: w1102)
        let group2 = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let origin1102 = try XCTUnwrap(session.origin(ofPage: w1102))
        XCTAssertEqual(ledger.move([ledger.name(back.id, on: w1130)], by: CGVector(dx: origin1102 - origin1130, dy: 0), group: group2).count, 1)
        ledger.deliver()
        var notices: [[String]] = []
        session.onSaveFailed = { notices.append($0) }
        XCTAssertEqual(Set(session.saveAll()), [w1102, w1130])
        XCTAssertEqual(order, [w1102], "the source is not even tried once its destination failed")
        XCTAssertEqual(notices.count, 1, "one notice for every page that could not be saved")
        XCTAssertTrue(bed.live(w1130).contains(back.id), "the source's file keeps the stroke")
        XCTAssertTrue(session.records.contains { $0.contains("not saved \(w1130)") })
        bed.allowSaves(of: w1102)
        order = []
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(order, [w1102, w1130])
        XCTAssertFalse(bed.live(w1130).contains(back.id))
        XCTAssertEqual(bed.live(w1102).count, 1)
        XCTAssertEqual(faults, [])
    }

    /// §3.4 (a): every procedure starts by emptying the inbox, so a relayout lays the pages out with the strokes the
    /// canvas has just put (here a free-memo line past 5,950 lu that raises the window's floor, D16).
    func testInboxDrainsBeforeRelayout() async throws {
        let day = DayKey(year: 2026, month: 11, day: 10)
        let session = bed.session(.day, focus: day)
        await session.prefetch()
        let ledger = JoinedLedgerStandIn(session)
        let focusId = "d-2026-11-10"
        XCTAssertEqual(session.layout.pages[session.focusSlot].cells[.extra]?.height, 6000)
        // Centred 5,975 lu below the memo's top (kept: under the 6,000 lu cap), its bottom past 5,950 lu.
        let memo = try XCTUnwrap(session.layout.cells[SpanName.prefixed(.extra, page: focusId)])
        XCTAssertNotNil(ledger.draw([CGPoint(x: memo.minX + 200, y: memo.minY + 5900), CGPoint(x: memo.minX + 220, y: memo.minY + 6000),
                                     CGPoint(x: memo.minX + 240, y: memo.minY + 6050)]))
        ledger.put()
        XCTAssertNil(session.page(focusId)?.liveStrokes.first, "not delivered yet")
        session.relayoutPages()
        XCTAssertEqual(session.page(focusId)?.liveStrokeCount, 1)
        let extra = try XCTUnwrap(session.layout.pages[session.focusSlot].cells[.extra])
        XCTAssertGreaterThan(extra.height, 6000)
        for page in session.layout.pages {
            XCTAssertEqual(page.cells[.extra]?.height, extra.height, "every day of the window ends at the same line")
        }
        XCTAssertTrue(session.inbox.isEmpty)
        XCTAssertEqual(faults, [])
    }

    /// §3.4 (c): a delta that never reached the inbox (the canvas's window has the stroke) is brought back by the
    /// safety net at the save, recorded as a fault (Debug stops there), and saved.
    func testSafetyNetRecoversADroppedDelta() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        let stroke = try XCTUnwrap(ledger.draw(on: w1123))
        session.inbox.put([], unrouted: [], window: ledger.current, basis: ledger.basis) // the delta is lost
        XCTAssertEqual(session.saveAll(), [])
        let real = try XCTUnwrap(SpanName.split(stroke.id)?.local)
        XCTAssertEqual(bed.live(w1123), [real])
        XCTAssertEqual(faults, ["safety net recovered \(w1123)"])
        XCTAssertEqual(session.page(w1123)?.pageId, w1123)
    }

    /// §3.3's table (`pickPageId`): the safety net merges with the real page id, never the virtual "span~…" one
    /// ("s" < "w", "y"), for the week and the year; the files carry the real ids.
    func testSafetyNetKeepsTheRealPageId() async throws {
        for (kind, focus) in [(PageKind.week, nov16), (.year, DayKey(year: 2026, month: 1, day: 1))] {
            let session = bed.session(kind, focus: focus, number: 7)
            await session.prefetch()
            XCTAssertTrue(session.window.pageId.hasPrefix("span~"))
            let ledger = JoinedLedgerStandIn(session)
            let target = session.pageIds[0]
            let cell: CellKey = kind == .year ? .yearDay(month: 3, day: 3) : .grid
            ledger.draw(on: target, cell: cell, x: 5, y: 5)
            session.inbox.put([], unrouted: [], window: ledger.current, basis: ledger.basis)
            XCTAssertEqual(session.saveAll(), [])
            XCTAssertEqual(session.page(target)?.pageId, target)
            XCTAssertEqual(bed.live(target).count, 1)
        }
        XCTAssertFalse(bed.store.allPageIds().contains { $0.hasPrefix("span~") })
        XCTAssertEqual(faults.count, 2)
    }

    /// §3.6: a page that leaves the window is saved first; when it cannot be, the window does not shift (and the
    /// page stays dirty for the next try).
    func testFailedSaveStopsTheShift() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1102)
        ledger.put()
        try bed.failSaves(of: w1102)
        var notices: [[String]] = []
        session.onSaveFailed = { notices.append($0) }
        let version = session.windowVersion
        XCTAssertFalse(session.shift(toFocusIndex: session.focusIndex + 1))
        XCTAssertEqual(session.pageIds, [w1102, w1109, w1116, w1123, w1130])
        XCTAssertEqual(session.windowVersion, version)
        XCTAssertEqual(session.slots[w1102]?.dirty, true)
        XCTAssertEqual(notices, [[w1102]])
        bed.allowSaves(of: w1102)
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 1))
        XCTAssertEqual(session.pageIds, [w1109, w1116, w1123, w1130, "w-2026-12-07"])
        XCTAssertEqual(bed.live(w1102).count, 1)
        XCTAssertEqual(session.takeHistoryPrune(), [w1102])
        XCTAssertEqual(faults, [])
    }

    /// §3.5: going to the background saves every dirty page of the window (the screen's `scenePhaseChanged` calls
    /// `saveAll()` before `applicationDidEnterBackground`).
    func testBackgroundSavesEveryDirtyPage() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1102)
        ledger.draw(on: w1116)
        ledger.draw(on: w1130)
        ledger.put() // still in the inbox
        XCTAssertEqual(session.saveAll(), [])
        for id in [w1102, w1116, w1130] {
            XCTAssertEqual(bed.live(id).count, 1, id)
            XCTAssertEqual(session.slots[id]?.dirty, false, id)
        }
        XCTAssertFalse(bed.store.exists(w1109))
        XCTAssertEqual(Set(bed.engine.state.dirty), [w1102, w1116, w1130])
    }

    /// §3.5: the export saves every page first (`saveAll()`), then reads the store: what the window shows is what the
    /// JSON reads, page by page.
    func testExportSavesEveryPageFirst() async throws {
        try bed.engine.save(bed.page(w1109, ["old"]))
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1109)
        ledger.draw(on: w1123)
        ledger.put()
        XCTAssertEqual(session.saveAll(), [])
        for id in session.pageIds {
            let shown = try XCTUnwrap(session.page(id))
            XCTAssertEqual(bed.store.load(id).liveStrokeIds, shown.liveStrokeIds, id)
        }
        XCTAssertEqual(Set(bed.engine.allLocalPageIds()), [w1109, w1123])
    }

    /// D7, H3: after 「全て消す」 (`cancelAll`) a delta the old canvas made under the old number is dropped (recorded,
    /// not a fault), the inbox is thrown away, the pages are empty and nothing is saved.
    func testOldEpochDeltaAfterEraseAllIsDropped() async throws {
        try bed.engine.save(bed.page(w1116, ["a"]))
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1116)
        ledger.put()
        session.cancelAll()
        XCTAssertTrue(session.inbox.isEmpty)
        XCTAssertEqual(session.epoch, 1)
        ledger.draw(on: w1123)
        ledger.deliver()
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 0)
        XCTAssertEqual(session.page(w1123)?.liveStrokeCount, 0)
        XCTAssertTrue(session.records.contains { $0.hasPrefix("dropped a delta of number 0 for \(w1123)") })
        try bed.store.removeAll()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.store.allPageIds(), [])
        XCTAssertEqual(session.takeHistoryPrune(), Set(session.pageIds))
        XCTAssertEqual(faults, [])
    }

    /// D7: an import saves first (`saveAll()` empties the inbox), the engine merges the file's pages in, and the number
    /// does not move: the stroke that was only in the inbox is kept, and the canvas's next deltas still apply.
    func testImportDoesNotAdvanceTheEpoch() async throws {
        await bed.startSynced()
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.put()
        XCTAssertEqual(session.saveAll(), [])
        _ = try await bed.engine.importPages([bed.page(w1116, ["imported"]), bed.page("w-2026-10-05", ["far"])]) { _, _ in }
        XCTAssertEqual(session.epoch, 0)
        let real = try XCTUnwrap(SpanName.split(mine.id)?.local)
        XCTAssertEqual(session.page(w1116).map { Set($0.liveStrokeIds) }, [real, "imported"])
        XCTAssertEqual(bed.live(w1116), [real, "imported"])
        ledger.take()
        ledger.draw(on: w1116, x: 600)
        ledger.deliver()
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 3)
        XCTAssertNil(session.page("w-2026-10-05"))
        XCTAssertEqual(faults, [])
    }

    // MARK: From outside (§3.5, D6, H1)

    /// §3.5: an update from iCloud reaches any window page (not only the focus), the window is composed again with it
    /// (the canvas reloads), and a page outside the window is left to its file.
    func testRemoteUpdateReachesAnyWindowPage() async throws {
        await bed.startSynced()
        let session = await openWeeks()
        let version = session.windowVersion
        bed.db.simulateRemoteSave(try bed.record(bed.page(w1102, ["other"])))
        bed.db.simulateRemoteSave(try bed.record(bed.page("w-2026-12-14", ["far"])))
        await bed.engine.syncNow()
        XCTAssertEqual(session.page(w1102)?.liveStrokeIds, ["other"])
        XCTAssertGreaterThan(session.windowVersion, version)
        XCTAssertNotNil(session.window.ledgerPage.strokes[SpanName.prefixed(id: "other", page: w1102)])
        XCTAssertEqual(session.slots[w1102]?.dirty, false, "nothing of this device to send back")
        XCTAssertNil(session.page("w-2026-12-14"))
        XCTAssertEqual(bed.live("w-2026-12-14"), ["far"])
    }

    /// H1 (§6.6): another device's 「全て消す」 deletes a window page's record: the page empties (its unsaved stroke too),
    /// its ↶ goes at the canvas's next window, the number moves on, and neither the save nor the safety net (the
    /// canvas still holds the old window) brings the strokes back.
    func testRemoteDeleteEmptiesThePageAndItsUndo() async throws {
        await bed.startSynced()
        try bed.engine.save(bed.page(w1123, ["a", "b"]))
        await bed.flushDebounce()
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1123)
        ledger.put()
        bed.db.simulateRemoteDelete(w1123)
        await bed.engine.syncNow()
        XCTAssertEqual(session.page(w1123)?.liveStrokeCount, 0)
        XCTAssertEqual(session.slots[w1123]?.dirty, false)
        XCTAssertEqual(session.epoch, 1)
        XCTAssertEqual(session.takeHistoryPrune(), [w1123])
        XCTAssertTrue(session.window.ledgerPage.strokes.keys.allSatisfy { !$0.hasPrefix(w1123) })
        // The canvas has not taken the new window yet: its old one still has a, b and the new stroke.
        session.inbox.put([], unrouted: [], window: ledger.current, basis: ledger.basis)
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertFalse(bed.store.exists(w1123))
        await bed.flushDebounce()
        XCTAssertNil(bed.db.records[w1123])
        // Once the canvas took the new window, the safety net reads from it again.
        ledger.take()
        ledger.draw(on: w1123)
        ledger.deliver()
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(bed.live(w1123).count, 1)
        XCTAssertEqual(faults, [])
    }

    /// D6: the engine's `save` reports a merge with the file inside the call (SyncEngine.swift:168-175); during a
    /// shift, that report — and any other update that arrives meanwhile — waits and is applied once the shift is
    /// done, to the window after the shift.
    func testRemoteUpdateFromSaveDuringShiftIsAppliedAfterTheShift() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1102)
        ledger.put()
        // Another device's stroke reached the leaving page's file (not the session): the save merges it in.
        try bed.store.save(bed.page(w1102, ["theirs"]))
        var pendingDuringSave = -1
        var updatedDuringSave = true
        session.willPersist = { [unowned session] id in
            guard id == self.w1102 else { return }
            session.remoteUpdated(self.bed.page(self.w1123, ["late"]))
            pendingDuringSave = session.pendingRemote.count
            updatedDuringSave = session.page(self.w1123)?.isLive("late") ?? true
        }
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 1))
        XCTAssertEqual(pendingDuringSave, 1)
        XCTAssertFalse(updatedDuringSave, "not applied in the middle of the shift")
        XCTAssertEqual(session.pendingRemote, [])
        XCTAssertEqual(session.page(w1123)?.isLive("late"), true)
        XCTAssertNotNil(session.window.ledgerPage.strokes[SpanName.prefixed(id: "late", page: w1123)])
        XCTAssertNil(session.page(w1102), "the left page's own report is its file's business")
        XCTAssertTrue(bed.live(w1102).contains("theirs"))
        XCTAssertEqual(bed.live(w1102).count, 2)
        XCTAssertEqual(faults, [])
    }

    /// D6: an update that arrives between two reads of `prefetch()` waits and is applied after the last read; it is
    /// never lost to the read that follows.
    func testRemoteUpdateBetweenPrefetchStepsIsKept() async throws {
        try bed.store.save(bed.page(w1130, ["stored"]))
        let session = bed.session(.week, focus: nov16)
        XCTAssertEqual(session.slots[w1130]?.unread, true)
        var pendingInStep: [Int] = []
        session.onPrefetchStep = { [unowned session] id in
            if id == self.w1123 {
                session.remoteUpdated(self.bed.page(self.w1130, ["remote"]))
                session.remoteUpdated(self.bed.page(self.w1109, ["remote2"]))
            }
            pendingInStep.append(session.pendingRemote.count)
        }
        await session.prefetch()
        XCTAssertEqual(pendingInStep, [0, 2, 2, 2], "11/9 was read before the updates, 11/23 with them, 11/2 and 11/30 after")
        XCTAssertEqual(session.pendingRemote, [])
        XCTAssertEqual(session.page(w1130).map { Set($0.liveStrokeIds) }, ["stored", "remote"])
        XCTAssertEqual(session.page(w1109)?.liveStrokeIds, ["remote2"])
        XCTAssertNotNil(session.window.ledgerPage.strokes[SpanName.prefixed(id: "remote", page: w1130)])
        XCTAssertEqual(faults, [])
    }

    /// D6: a page still waiting for its read (a placeholder) takes the canvas's delta; a save or a shift before its read
    /// reads it first, so the page is saved with its file and the stroke, and is not left behind when it leaves.
    func testAPlaceholderWrittenBeforeItsReadIsSavedWithItsFile() async throws {
        try bed.store.save(bed.page(w1130, ["stored"]))
        let session = bed.session(.week, focus: nov16)
        XCTAssertEqual(session.slots[w1130]?.unread, true)
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1130))
        ledger.deliver()
        let real = try XCTUnwrap(SpanName.split(mine.id)?.local)
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(session.slots[w1130]?.unread, false)
        XCTAssertEqual(session.page(w1130).map { Set($0.liveStrokeIds) }, ["stored", real])
        XCTAssertEqual(bed.live(w1130), ["stored", real])
        // The same on a shift that takes a written placeholder out of the window.
        let other = bed.session(.week, focus: nov16, number: 2)
        let ledger2 = JoinedLedgerStandIn(other)
        let left = try XCTUnwrap(ledger2.draw(on: w1102))
        ledger2.put()
        XCTAssertTrue(other.shift(toFocusIndex: other.focusIndex + 1))
        XCTAssertEqual(bed.live(w1102), [try XCTUnwrap(SpanName.split(left.id)?.local)])
        XCTAssertEqual(faults, [])
    }

    /// D6, H1: a deletion from iCloud that arrives while `saveAll` runs waits; the deleted page is not written back
    /// in the same `saveAll`, and empties at its end.
    func testRemoteDeleteDuringSaveAllIsNotSavedBack() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        ledger.draw(on: w1109)
        ledger.draw(on: w1123)
        ledger.put()
        var written: [String] = []
        session.willPersist = { [unowned session] id in
            written.append(id)
            if id == self.w1109 {
                try? self.bed.store.remove(self.w1123) // the engine removed the file first
                session.remoteDeleted(self.w1123)
            }
        }
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(written, [w1109])
        XCTAssertFalse(bed.store.exists(w1123))
        XCTAssertEqual(session.page(w1123)?.liveStrokeCount, 0)
        XCTAssertEqual(session.slots[w1123]?.dirty, false)
        XCTAssertTrue(session.records.contains { $0.contains("not saved \(w1123): deleted in iCloud meanwhile") })
        XCTAssertEqual(faults, [])
    }

    /// §7: once the window's pages are read, the engine is asked once for all of them (one `fetchRecords`), and what
    /// it brings reaches the pages; after a shift only the page that came in is due (the 30 s cooldown).
    func testPagesOpenedOnceForTheWindow() async throws {
        await bed.startSynced()
        bed.db.simulateRemoteSave(try bed.record(bed.page(w1109, ["x"])))
        bed.db.simulateRemoteSave(try bed.record(bed.page(w1130, ["y"])))
        let before = bed.db.calls.filter { $0 == .fetchRecords }.count
        let session = await openWeeks()
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(bed.db.calls.filter { $0 == .fetchRecords }.count, before + 1)
        XCTAssertEqual(session.page(w1109)?.liveStrokeIds, ["x"])
        XCTAssertEqual(session.page(w1130)?.liveStrokeIds, ["y"])
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 1))
        await session.prefetch()
        await bed.engine.waitUntilIdle()
        XCTAssertEqual(bed.db.calls.filter { $0 == .fetchRecords }.count, before + 2)
        XCTAssertEqual(faults, [])
    }

    // MARK: Focus, title, ◀ ▶, 「今日」 (§3.6, §3.7)

    /// §3.7, §3.16: the focus (the title) changes only 6 % of a page past a boundary, both ways; a stop gives the
    /// focus's first day to remember.
    func testFocusHysteresisAndRemember() async throws {
        let session = await openWeeks()
        let w = session.plan.pageWidth
        let middleLeft = CGFloat(session.focusSlot) * w
        XCTAssertEqual(session.focusPageId, w1116)
        XCTAssertFalse(session.scrolled(midX: middleLeft + w + 0.05 * w), "5 % past the right boundary: still 11/16")
        XCTAssertEqual(session.focusPageId, w1116)
        XCTAssertTrue(session.scrolled(midX: middleLeft + w + 0.07 * w))
        XCTAssertEqual(session.focusPageId, w1123)
        XCTAssertFalse(session.scrolled(midX: middleLeft + w - 0.05 * w), "back 5 % over the boundary: still 11/23")
        XCTAssertTrue(session.scrolled(midX: middleLeft + w - 0.07 * w))
        XCTAssertEqual(session.focusPageId, w1116)
        let stop = session.stopped(midX: middleLeft + 1.5 * w)
        XCTAssertEqual(stop.focusDay, DayKey(year: 2026, month: 11, day: 23))
        XCTAssertTrue(session.needsShift)
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        XCTAssertFalse(session.needsShift)
        XCTAssertEqual(session.focusDay, DayKey(year: 2026, month: 11, day: 23))
    }

    /// §3.8: each page's events are read for its own days, the focus first and then the nearest; no query reaches four
    /// years (EventKit's limit), longer ranges are cut.
    func testEventsArePerPageUnderFourYears() async throws {
        var queries: [(DayKey, DayKey)] = []
        let source: (DayKey, DayKey) -> [LayoutEvent] = { start, end in
            queries.append((start, end))
            return [LayoutEvent(id: "e-\(start)", title: "e", allDay: true, start: start.startOfDay(), end: start.adding(days: 1).startOfDay(),
                                colorHex: "#ff0000", calendarId: "c")]
        }
        let session = bed.session(.week, focus: nov16, eventSource: source)
        await session.prefetch()
        let firsts = queries.map(\.0)
        XCTAssertEqual(firsts, [DayKey(year: 2026, month: 11, day: 16), DayKey(year: 2026, month: 11, day: 9),
                                DayKey(year: 2026, month: 11, day: 23), DayKey(year: 2026, month: 11, day: 2),
                                DayKey(year: 2026, month: 11, day: 30)])
        for (start, end) in queries {
            XCTAssertEqual(end, start.adding(days: 7))
        }
        for id in session.pageIds {
            let range = try XCTUnwrap(session.days(of: id))
            XCTAssertEqual(session.events[id]?.map(\.id), ["e-\(range.start)"], id)
        }
        queries = []
        session.reloadEvents()
        XCTAssertEqual(queries.first?.0, DayKey(year: 2026, month: 11, day: 16), "the focus first")
        let start = DayKey(year: 2026, month: 1, day: 1)
        let long = SpanSession.eventQueries(start: start, end: start.adding(days: 3000))
        XCTAssertEqual(long.count, 3)
        for piece in long {
            XCTAssertLessThan(piece.end.dayNumber - piece.start.dayNumber, SpanSession.eventQueryMaxDays)
        }
        XCTAssertEqual(long.first?.start, start)
        XCTAssertEqual(long.last?.end, start.adding(days: 3000))
        XCTAssertLessThan(SpanSession.eventQueryMaxDays, 4 * 365 + 1)
    }

    /// §3.6: ◀ ▶ slide one page (by the page's width at the zoom), and the shift that follows keeps the session (the
    /// canvas's identity) and its virtual id.
    func testArrowsMoveOnePage() async throws {
        let session = await openWeeks()
        XCTAssertEqual(session.move(by: 1), .slide(pages: 1))
        XCTAssertEqual(session.move(by: -1), .slide(pages: -1))
        XCTAssertEqual(session.plan.shiftAmount(pages: 1, zoom: 0.4974), 1400 * 0.4974, accuracy: 1e-9)
        let id = session.id
        let virtualId = session.window.pageId
        let w = session.plan.pageWidth
        let stop = session.stopped(midX: CGFloat(session.focusSlot + 1) * w + w / 2)
        XCTAssertEqual(stop.focusDay, DayKey(year: 2026, month: 11, day: 23))
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex))
        XCTAssertEqual(session.pageIds.first, w1109)
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.window.pageId, virtualId)
    }

    /// §3.6: 「今日」 slides when today's page is in the window, else opens anew there.
    func testTodayNearSlidesFarReopens() async throws {
        let session = await openWeeks()
        XCTAssertEqual(session.today(DayKey(year: 2026, month: 11, day: 18)), .slide(pages: 0))
        XCTAssertEqual(session.today(DayKey(year: 2026, month: 12, day: 3)), .slide(pages: 2))
        XCTAssertEqual(session.today(DayKey(year: 2026, month: 11, day: 2)), .slide(pages: -2))
        let far = DayKey(year: 2026, month: 12, day: 10)
        XCTAssertEqual(session.today(far), .reopen(focus: far))
    }

    // MARK: The guard (§6.1, D14, D17)

    /// §6.1: no window name reaches a saved page (a leak into a slot is repaired at the save), the virtual page id is
    /// never saved, and what is on file passes the transfer check (the import's and the export's) unchanged.
    func testVirtualNamesNeverReachSaveImportOrExport() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.deliver()
        session.editSlotForTesting(w1116) { page in
            page.strokes[mine.id] = mine
            page.deleted["span~a~3"] = 1
        }
        XCTAssertEqual(session.saveAll(), [])
        for id in bed.store.allPageIds() {
            let page = bed.store.load(id)
            XCTAssertTrue(SpanGuard.checkForTransfer(page), id)
            XCTAssertFalse(id.hasPrefix("span~"))
        }
        // The virtual page itself is refused at the save, and any window name at the transfer.
        let refused = PageSlot.persist(session.window.ledgerPage, added: [], mode: .release, willWrite: { _ in }, write: { _ in
            XCTFail("the virtual page reached the engine")
        })
        XCTAssertEqual(refused, .refused)
        XCTAssertFalse(SpanGuard.checkForTransfer(session.window.ledgerPage))
        XCTAssertEqual(faults.filter { $0.hasPrefix("repaired \(w1116)") }.count, 1)
    }

    /// D17, §3.11: the PDF of a page gets the real page (no window name, so the transfer check passes) and, apart,
    /// the neighbour's stroke that reaches into it, with its real id and its owner's own cell.
    func testPDFDrawsNeighborInkWithoutPrefixedNamesInThePage() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        let origin = try XCTUnwrap(session.origin(ofPage: w1123))
        // Owned by 11/16 (its centre is left of the boundary), reaching 200 lu into 11/23.
        let crossing = try XCTUnwrap(ledger.draw([CGPoint(x: origin - 300, y: 900), CGPoint(x: origin - 50, y: 905), CGPoint(x: origin + 200, y: 900)]))
        XCTAssertTrue(crossing.id.hasPrefix(w1116 + "|"))
        ledger.put()
        let pdf = try XCTUnwrap(session.pdfInput(for: w1123))
        XCTAssertEqual(pdf.page.pageId, w1123)
        XCTAssertTrue(SpanGuard.checkForTransfer(pdf.page))
        XCTAssertEqual(pdf.page.liveStrokeCount, 0)
        XCTAssertEqual(pdf.neighborInk.count, 1)
        let ink = try XCTUnwrap(pdf.neighborInk.first)
        XCTAssertEqual(ink.pageId, w1116)
        XCTAssertEqual(ink.stroke.id, SpanName.split(crossing.id)?.local)
        XCTAssertEqual(ink.stroke.cell, .grid)
        XCTAssertFalse(SpanGuard.isWindowName(ink.stroke.id))
        XCTAssertLessThan(ink.cellRect.minX, 0, "the owner's cell sits left of the page")
        XCTAssertNil(session.pdfInput(for: "w-2026-12-14"))
    }

    /// §6.1: only the offending items are repaired — the page's own prefix stripped, another page's prefix and "span~"
    /// dropped — and everything else is saved byte for byte, including an id with a "|" that this session did not
    /// make (an import's, a web stroke's); the page is never refused for it.
    func testGuardRepairsOnlyTheBadItems() async throws {
        var stored = bed.page(w1116, ["good"])
        stored.add(bed.stroke("web|kept~w1", x: 300))
        try bed.store.save(stored)
        let session = await openWeeks()
        session.editSlotForTesting(w1116) { page in
            page.strokes[w1116 + "|own"] = self.bed.stroke(w1116 + "|own", cell: SpanName.prefixed(.grid, page: self.w1116), x: 400)
            page.strokes[w1109 + "|theirs"] = self.bed.stroke(w1109 + "|theirs", cell: SpanName.prefixed(.grid, page: self.w1109), x: 500)
            page.deleted["span~a~1"] = 5
        }
        XCTAssertEqual(session.saveAll(), [])
        let saved = bed.store.load(w1116)
        XCTAssertEqual(Set(saved.liveStrokeIds), ["good", "web|kept~w1", "own"])
        XCTAssertEqual(saved.strokes["own"]?.cell, .grid)
        XCTAssertEqual(saved.strokes["good"], stored.strokes["good"])
        XCTAssertEqual(saved.strokes["web|kept~w1"], stored.strokes["web|kept~w1"])
        XCTAssertEqual(saved.deleted, [:])
        XCTAssertEqual(faults.count, 1)
        XCTAssertTrue(faults.first?.contains("stripped \(w1116)|own") == true)
        XCTAssertTrue(faults.first?.contains("dropped span~a~1,\(w1109)|theirs") == true)
    }

    // MARK: Switching (§3.1, §3.9)

    /// §3.1: switching between the two paths saves the old path's pages first, then opens the other on the same files:
    /// what the window wrote is on the one page, and what the one page wrote is in the next window.
    func testPathSwitchSavesThenReopens() async throws {
        let session = await openWeeks()
        let ledger = JoinedLedgerStandIn(session)
        let mine = try XCTUnwrap(ledger.draw(on: w1116))
        ledger.put()
        XCTAssertEqual(session.saveAll(), [])
        let one = OnePageSession(sync: bed.engine)
        one.open(bed.engine.load(w1116))
        XCTAssertEqual(one.page.liveStrokeIds, [SpanName.split(mine.id)!.local])
        var written = one.page
        written.add(bed.stroke("one-page", x: 700))
        XCTAssertTrue(one.canvasWrote(written, madeFor: one.canvasIdentity(base: "w|monday"), base: "w|monday"))
        one.saveNow()
        let next = await openWeeks(number: 2)
        XCTAssertEqual(next.page(w1116).map { Set($0.liveStrokeIds) }, [SpanName.split(mine.id)!.local, "one-page"])
        XCTAssertNotEqual(next.id, session.id)
    }

    /// §3.9, K-11: a week start switch saves the old form's window first (`CalendarRootScreen.weekStartSwitch`'s
    /// order), then a new session of the other form opens; its window has that form's pages only, and a delta of
    /// the old form never lands in it.
    func testWeekStartSwitchSavesThenReopensAndNeverMixes() async throws {
        let monday = await openWeeks()
        let ledger = JoinedLedgerStandIn(monday)
        ledger.draw(on: w1116)
        ledger.put()
        var steps: [String] = []
        var sunday: SpanSession?
        CalendarRootScreen.weekStartSwitch(old: .monday, new: .sunday,
                                           save: { steps.append("save \(monday.saveAll())") },
                                           apply: { steps.append("apply \($0.rawValue)") },
                                           reload: {
                                               steps.append("reload")
                                               sunday = self.bed.session(.week, focus: self.nov16, weekStart: .sunday, number: 2)
                                           })
        XCTAssertEqual(steps, ["save []", "apply sunday", "reload"])
        XCTAssertEqual(bed.live(w1116).count, 1)
        let other = try XCTUnwrap(sunday)
        await other.prefetch()
        XCTAssertEqual(other.pageIds, ["w-2026-11-01", "w-2026-11-08", "w-2026-11-15", "w-2026-11-22", "w-2026-11-29"])
        XCTAssertNotEqual(other.id, monday.id)
        other.deliver(SpanComposer.deltas(from: [SpanJournalEntry(added: [bed.stroke(SpanName.prefixed(id: "x", page: w1116))], at: 1)],
                                          epoch: 0, aliases: .empty), unrouted: [])
        XCTAssertEqual(faults, ["delta for \(w1116), not in the window"])
        XCTAssertTrue(other.pageIds.allSatisfy { other.page($0)?.liveStrokeCount == 0 })
    }

    // MARK: The rating prompt's visit (D20)

    /// D20: the visit is the focus page; the person's own ink while it is the focus marks it, and a stop on another
    /// page ends it (the screen's `scheduleReviewRequest(leftPageWithInk:lastInkChangeAt:)`).
    func testReviewVisitFollowsTheFocus() async throws {
        let session = await openWeeks()
        var inkAt: [Date] = []
        session.onOwnInk = { inkAt.append($0) }
        let ledger = JoinedLedgerStandIn(session)
        let w = session.plan.pageWidth
        XCTAssertNil(session.stopped(midX: CGFloat(session.focusSlot) * w + w / 2).ended, "the same page: no visit ends")
        bed.now = Date(timeIntervalSince1970: 1_790_000_500)
        ledger.draw(on: w1123)
        ledger.deliver()
        XCTAssertEqual(inkAt, [bed.now])
        XCTAssertEqual(session.visit, SpanSession.Visit(pageId: w1116, inkChanged: true, lastInkChangeAt: bed.now))
        let stop = session.stopped(midX: CGFloat(session.focusSlot + 1) * w + w / 2)
        XCTAssertEqual(stop.ended, SpanSession.Visit(pageId: w1116, inkChanged: true, lastInkChangeAt: bed.now))
        XCTAssertEqual(session.visit, SpanSession.Visit(pageId: w1123))
        let back = session.stopped(midX: CGFloat(session.focusSlot - 1) * w + w / 2)
        XCTAssertEqual(back.ended, SpanSession.Visit(pageId: w1123))
    }

    // MARK: Stage 2 (§3.15, D18)

    /// D18, §3.15: before the neighbours are read, their file sizes are counted high (0.25 KB a stroke); a window over
    /// the device's cap falls back to one page. The real count replaces the estimate once read.
    func testStageTwoFallsBackToOnePage() async throws {
        // iPhone portrait (R = 2): cap 12,000. Four neighbours of 800,000 bytes each are estimated 3,200 strokes each.
        for id in [w1102, w1109, w1123, w1130] {
            try Data(repeating: 0x41, count: 800_000).write(to: bed.store.url(for: id))
        }
        let session = bed.session(.week, focus: nov16, deviceClass: .iPhone)
        XCTAssertEqual(session.plan.strokeCap, 12_000)
        XCTAssertEqual(session.windowStrokeCount, 12_800)
        XCTAssertTrue(session.fallsBackToOnePage)
        await session.prefetch() // the files are not pages: read as empty (moved aside), 0 strokes
        XCTAssertEqual(session.windowStrokeCount, 0)
        XCTAssertFalse(session.fallsBackToOnePage)
        // A page that really holds more than the cap.
        var heavy = InkPage.empty(pageId: "w-2026-12-14")
        for n in 0..<12_001 {
            let point = InkPoint(x: CGFloat(n % 1000), y: CGFloat(n / 1000), dtMs: 0, sizeW: 1, sizeH: 1, opacity: 1, force: 0, azimuth: 0, altitude: 0)
            heavy.add(InkStroke(id: "h\(n)", cell: .grid, tool: .pen, color: "#000000", t: 1, points: [point]))
        }
        try bed.store.save(heavy)
        let other = bed.session(.week, focus: DayKey(year: 2026, month: 12, day: 14), number: 2, deviceClass: .iPhone)
        XCTAssertEqual(other.windowStrokeCount, 12_001)
        XCTAssertTrue(other.fallsBackToOnePage)
    }

    // MARK: The timer (D8, §3.16)

    /// D8, §3.16: one save timer per session, 1.5 s after the last change; earlier timers do nothing when they wake.
    func testSaveTimerIsOnePerSession() async throws {
        let session = await openWeeks()
        var saves: [String] = []
        session.willPersist = { saves.append($0) }
        let ledger = JoinedLedgerStandIn(session)
        let recorded = bed.sessionSleeper.recorded.count
        ledger.draw(on: w1109)
        ledger.deliver()
        ledger.draw(on: w1116)
        ledger.deliver()
        ledger.draw(on: w1109, x: 600)
        ledger.deliver()
        await bed.yieldUntil { bed.sessionSleeper.waiting == 3 }
        XCTAssertEqual(Array(bed.sessionSleeper.recorded.dropFirst(recorded)), [1.5, 1.5, 1.5])
        XCTAssertEqual(saves, [])
        await bed.flushSessionTimers()
        XCTAssertEqual(saves, [w1109, w1116], "one save of every dirty page, by the last timer")
        XCTAssertEqual(bed.sessionSleeper.waiting, 0)
        XCTAssertEqual(bed.live(w1109).count, 2)
        XCTAssertEqual(faults, [])
    }
}
