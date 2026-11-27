import Foundation
import CoreGraphics
@_spi(SpanLedger) import InkModel
import Layout
import CompatFixtures
import CompatSpanFixtures

/// The compat-span-143 fixtures of 1.4.3 (docs/R1_4_3_CONTRACT.md §8.3, 0g-30, K-7): what the month and the year write
/// once they are joined sideways, in a folder of their own (TegakiKit/Tests/Fixtures/compat-span-143) so the folder of
/// 1.3 and its table FIXTURES_1_3 stay byte for byte. Made the way 1.3 made compat-span (docs/M7C_CONTRACT.md §4.2):
/// pages written by the joined path of the Kit — a window of real pages composed with `SpanComposer`, the ledger's steps
/// (`SpanLedgerSim`: the owner is the page of the centre's x, the cell that page's own `inkCell`, the points relative to
/// that cell), the journal turned into `PageDelta`s and applied to the real pages (`SpanSlotsSim`), the safety net,
/// `SpanGuard.checkForSave` and `InkPageCodec.encode` — so the bytes are what a joined window saves. The fixture numbers
/// go on from compat-span's 1–7:
///
/// 8. A month memo line written from the right page to the left: `m1-2026-11`'s `memo`, x −160…260 (B_DESIGN §4.1's
///    example), in a Monday window m1-2026-10 | m1-2026-11 | m1-2026-12.
/// 9. The lasso's move across the day two month tables share: a stroke on `m1-2026-10`'s 2026-11-01 (the faded day of
///    October's table) moved onto `m1-2026-11`'s 2026-11-01 — a copy with a new id on the destination, a tombstone on
///    the source, the same cell name on both pages (K-2).
/// 10. The year's date column and its owner: a line centred on 2027's date column is `y-2027`'s January cell 01-20 with x
///    −128…70 (B_DESIGN §4.1), and a line from 2026's December to the right (row 10) is `y-2026`'s 12-10, reaching past
///    the page's right edge (paper x 1,200…1,520).
/// 11. A Sunday-start month window (K-11): a memo line of `m1-2026-11` crossing into December, shape sunday in MANIFEST
///     (the page id is the same for both week starts; the memo cell is the same rectangle in both 42-day grids).
/// 12. A line written where the year's row alignment lengthened a row: `y-2026`'s 06-15, 350 lu below the cell's top.
/// 13. A line written deep in the month's lengthened last row (form ア): `m1-2026-11`'s 2026-12-03 (row 6), 600 lu below
///     the cell's top.
/// 12 and 13 show K-4 and B_DESIGN §3.1 ("on an old device the line written where the row was lengthened is seen"): a
/// version without the floors lays the page out from its own ink (the row grows to the ink's bottom + 12).
///
/// How 12 and 13 get their tall row: the floors that lengthen it in 1.4.3 (`gridFloor`, `rowFloors`, role K, step D1a)
/// are not in this tree when the fixtures are made, so the window's page is laid out with the engines' ink-bottom input
/// standing in for the floor (`rowStandIn`: the same row height a floor gives; the rows above it do not move in either
/// way, §4.1, §5.1). The saved bytes do not depend on how the row got tall: the points are stored relative to the cell,
/// whose origin is the same either way. Written once in step D1a (docs/R1_4_3.md); KitChecks compares the committed
/// files with `make()` on every run, so a maker that changed (for example one that uses K's floors) and gave other bytes
/// would fail there.
///
/// Ids come from seeds, times are 1,791,430,000,000 + n (after 1.3's fixtures, before the 1,792,000,000,000 the readers
/// use for their own edits), the layouts use `CompatFixtures.now` and Tokyo, so the bytes are the same on every run and
/// every machine. `KitChecks --write-compat-span-143-fixtures [--out <folder>]` calls `write(to:)`.
public enum CompatSpan143Fixtures {
    public typealias Shape = CompatSpanFixtures.Shape
    public typealias Entry = CompatSpanFixtures.Entry
    public typealias WriteResult = CompatSpanFixtures.WriteResult

    public static let manifestName = "MANIFEST"
    public static let device = "fixture-1.4.3"
    public static let baseTime = 1_791_430_000_000

    public static let monthMemoLeft = "m1-2026-11.memo-left.json"
    public static let monthMoveSource = "m1-2026-10.move-source.json"
    public static let monthMoveDestination = "m1-2026-11.move-destination.json"
    public static let yearDecemberRight = "y-2026.december-right.json"
    public static let yearDateColumn = "y-2027.date-column.json"
    public static let monthMemoSunday = "m1-2026-11.memo-sunday.json"
    public static let yearRowFloor = "y-2026.row-floor.json"
    public static let monthLastRow = "m1-2026-11.last-row.json"

    /// The MANIFEST's lines, in its order.
    public static let entries: [Entry] = [
        Entry(name: monthMemoLeft, fixture: 8, shape: .monday),
        Entry(name: monthMoveSource, fixture: 9, shape: .monday),
        Entry(name: monthMoveDestination, fixture: 9, shape: .monday),
        Entry(name: yearDecemberRight, fixture: 10, shape: .monday),
        Entry(name: yearDateColumn, fixture: 10, shape: .monday),
        Entry(name: monthMemoSunday, fixture: 11, shape: .sunday),
        Entry(name: yearRowFloor, fixture: 12, shape: .monday),
        Entry(name: monthLastRow, fixture: 13, shape: .monday),
    ]

    /// `Tests/Fixtures/compat-span-143/` of this checkout (found from this file, no bundle resources).
    public static var committedFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CompatSpan143Fixtures/
            .deletingLastPathComponent()   // Tests/
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("compat-span-143", isDirectory: true)
    }

    /// `MANIFEST`: two comment lines, then "<file> <fixture> <shape>" per file (compat-span's form).
    public static func manifestData() -> Data {
        var text = "# compat-span-143 fixtures (docs/R1_4_3_CONTRACT.md §8.3, 0g-30), made by KitChecks --write-compat-span-143-fixtures.\n"
        text += "# One line per file: <file> <fixture number> <shape>; CI copies the files of shape monday into the compat11 folder.\n"
        for e in entries { text += "\(e.name) \(e.fixture) \(e.shape.rawValue)\n" }
        return Data(text.utf8)
    }

    /// The entries a MANIFEST's text lists (compat-span's reader: the form is the same).
    public static func parseManifest(_ data: Data) -> [Entry]? {
        CompatSpanFixtures.parseManifest(data)
    }

    // MARK: - The tall rows of 12 and 13

    /// Fixture 12's row: `y-2026`'s row 15 at 392 lu (60 natural), the height a floor from a neighbour year whose row 15
    /// holds a line ending 380 lu below its top gives (`rowStandIn` puts the same height through the ink-bottom input).
    public static let yearRowCell = CellKey.yearDay(month: 6, day: 15)
    public static let yearRowStandIn: CGFloat = 380
    /// Fixture 13's row: `m1-2026-11`'s row 6 (2026-11-30 … 2026-12-06 with the Monday start) at 712 lu (175 natural),
    /// what form ア's grid floor gives in a window whose tallest grid ends at 1,587 lu (rows 1–5 stay 175 lu each).
    public static let monthRowCell = CellKey.day(DayKey(year: 2026, month: 12, day: 3))
    public static let monthRowStandIn: CGFloat = 700

    // MARK: - Making them

    /// What making the fixtures gives: the files (in `entries` order) and what happened on the way.
    public struct Made: Sendable {
        public let files: [(name: String, data: Data)]
        /// `SpanGuard.checkForSave` of each file's page as it was saved.
        public let saves: [String: SpanGuard.SaveCheck]
        /// Pages the safety net had to bring something back to (empty: every delta arrived).
        public let recovered: [String]
        /// The deltas the sessions applied, in all.
        public let deltaCount: Int
        /// The window cells (the owner's prefixed names, as `drop` and the lasso's move chose them) of the live strokes the
        /// ledger held for each file's page when it was saved, by file.
        public let cells: [String: [String]]
    }

    /// The files, in `entries` order.
    public static func make() -> [(name: String, data: Data)] {
        made.files
    }

    public static var made: Made { madeOnce }

    private static let madeOnce: Made = build()

    /// Writes every fixture and `MANIFEST` into `folder` (made when missing) and says, per file, whether it was new,
    /// unchanged or changed. Other files are not touched.
    @discardableResult
    public static func write(to folder: URL) throws -> [(name: String, result: WriteResult)] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var out: [(name: String, result: WriteResult)] = []
        for (name, data) in make() + [(manifestName, manifestData())] {
            let url = folder.appendingPathComponent(name)
            let old = try? Data(contentsOf: url)
            let result: WriteResult = old == nil ? .new : (old == data ? .unchanged : .changed)
            if result != .unchanged { try data.write(to: url, options: .atomic) }
            out.append((name, result))
        }
        return out
    }

    // MARK: - The sessions

    static func plan(_ kind: PageKind, _ weekStart: WeekStart = .monday) -> SpanPlan {
        SpanPlan(kind: kind, weekStart: weekStart, deviceClass: .iPad11, orientation: .portrait)
    }

    /// The page as a window lays it out (no event, `CompatFixtures.now`, Tokyo), with `rowStandIn` as the bottom of the
    /// ink of the cells it names (fixtures 12 and 13; empty for every other page: the natural rows).
    static func layout(_ pageId: String, weekStart: WeekStart, rowStandIn: [CellKey: CGFloat]) -> any PageLayout {
        guard let parsed = PageNavigation.parse(pageId: pageId) else { preconditionFailure("not a page id: \(pageId)") }
        let now = CompatFixtures.now
        let tokyo = CompatFixtures.tokyo
        switch parsed.kind {
        case .month:
            return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: parsed.focus.year, month: parsed.focus.month), events: [],
                                                             inkBottoms: rowStandIn, now: now, calendar: tokyo, weekStart: weekStart))
        case .year:
            return YearLayoutEngine.layout(YearLayoutInput(year: parsed.focus.year, events: [], inkBottoms: rowStandIn, now: now, calendar: tokyo))
        case .day, .week:
            preconditionFailure("compat-span-143 holds months and years only: \(pageId)")
        }
    }

    /// A line of `count` points from x0 to x1 (window lu) around y, every other point 6 lu lower (compat-span's shape).
    static func line(_ x0: CGFloat, _ x1: CGFloat, y: CGFloat, count: Int = 9) -> [CGPoint] {
        (0..<count).map { i in CGPoint(x: x0 + (x1 - x0) * CGFloat(i) / CGFloat(count - 1), y: y + CGFloat(i % 2) * 6) }
    }

    struct Session {
        var sim: SpanLedgerSim
        var slots: SpanSlotsSim
        var deltas = 0

        init(_ pages: [InkPage], plan: SpanPlan, seed: UInt64, firstTime: Int, rowStandIn: [String: [CellKey: CGFloat]] = [:]) {
            let layouts = pages.map { CompatSpan143Fixtures.layout($0.pageId, weekStart: plan.weekStart, rowStandIn: rowStandIn[$0.pageId] ?? [:]) }
            precondition(layouts.map(\.pageId) == pages.map(\.pageId), "the pages lay out as themselves under the \(plan.weekStart) start")
            let window = SpanLayout(pages: layouts, plan: plan, firstIndex: plan.index(of: pages[0].pageId)!, session: 0)
            let virtual = SpanComposer.compose(pages, plan: plan, session: 0)
            precondition(virtual.pageIds == pages.map(\.pageId) && virtual.pageId == window.pageId, "the window's pages")
            sim = SpanLedgerSim(virtual: virtual, layout: window, seed: seed, firstTime: firstTime, dev: CompatSpan143Fixtures.device)
            slots = SpanSlotsSim(pages: pages)
        }

        @discardableResult
        mutating func draw(_ points: [CGPoint], owner: String, cell: CellKey, tool: InkTool = .pen, color: String = "#1f2937", size: CGFloat = 3.5) -> InkStroke {
            guard let s = sim.draw(points, size: size, tool: tool, color: color) else { preconditionFailure("a fixture stroke was dropped") }
            precondition(s.cell == SpanName.prefixed(cell, page: owner), "fixture stroke lands in \(s.cell.raw), not \(owner)|\(cell.raw)")
            return s
        }

        /// The journal to deltas to the slots, then the safety net.
        mutating func deliver() {
            let deltas = SpanComposer.deltas(from: sim.takeJournal(), epoch: 0, aliases: sim.virtual.aliases)
            self.deltas += deltas.count
            slots.deliver(deltas)
            slots.safetyNet(sim.current)
        }

        func save(_ pageId: String) -> (check: SpanGuard.SaveCheck, data: Data) {
            let saved = slots.save(pageId)
            guard let data = saved.data else { preconditionFailure("the fixture page \(pageId) was refused") }
            return (saved.check, data)
        }
    }

    static func build() -> Made {
        var files: [String: Data] = [:]
        var saves: [String: SpanGuard.SaveCheck] = [:]
        var recovered: [String] = []
        var deltaCount = 0
        var cells: [String: [String]] = [:]
        func keep(_ name: String, _ s: Session, _ pageId: String) {
            let saved = s.save(pageId)
            files[name] = saved.data
            saves[name] = saved.check
            cells[name] = s.sim.page.liveStrokes.map(\.cell.raw).filter { $0.hasPrefix(pageId + "|") }.sorted()
        }
        func finish(_ s: Session) {
            recovered += s.slots.recovered
            deltaCount += s.deltas
        }
        func empty(_ ids: [String]) -> [InkPage] { ids.map { InkPage(pageId: $0) } }
        let months = ["m1-2026-10", "m1-2026-11", "m1-2026-12"]   // m1-2026-11 at x 1,400 … 2,800 of the window
        let years = ["y-2025", "y-2026", "y-2027"]               // y-2026 at x 1,400 … 2,800, y-2027 at 2,800 … 4,200

        // 8. The month memo from the right page to the left (Monday window): memo origin (1,400, 1,050), x −160 … 260,
        // 450 lu below the memo's top; the centre x 1,450 is November's.
        do {
            var s = Session(empty(months), plan: plan(.month), seed: 0x5A01_4308, firstTime: baseTime + 800)
            s.draw(line(1240, 1660, y: 1500), owner: "m1-2026-11", cell: .memo, color: "#2563eb")
            s.deliver()
            keep(monthMemoLeft, s, "m1-2026-11")
            finish(s)
        }
        // 9. A move across the shared day: two strokes on m1-2026-10's 2026-11-01 (row 5, column 7 of October's table:
        // x 2,600 … 2,800, y 700 … 875 of the window m1-2026-09 | m1-2026-10 | m1-2026-11), saved; the next session moves
        // the first one by (1,400, −700) onto m1-2026-11's 2026-11-01 (row 1, column 7 of November's table).
        do {
            let ids = ["m1-2026-09", "m1-2026-10", "m1-2026-11"]
            var first = Session(empty(ids), plan: plan(.month), seed: 0x5A01_4309, firstTime: baseTime + 900)
            let shared = CellKey.day(DayKey(year: 2026, month: 11, day: 1))
            first.draw(line(2630, 2770, y: 760, count: 6), owner: "m1-2026-10", cell: shared)
            first.draw(line(2630, 2770, y: 820, count: 6), owner: "m1-2026-10", cell: shared, color: "#2563eb")
            first.deliver()
            let stored = first.save("m1-2026-10").data
            finish(first)
            guard let read = try? InkPageCodec.decode(stored) else { preconditionFailure("the saved page reads") }
            var s = Session([InkPage(pageId: ids[0]), read, InkPage(pageId: ids[2])], plan: plan(.month), seed: 0x5A01_430A, firstTime: baseTime + 950)
            let moving = s.sim.page.liveStrokes.min { $0.t < $1.t }!
            let copies = s.sim.move([moving.id], by: CGVector(dx: 1400, dy: -700))
            precondition(copies.count == 1 && copies[0].cell.raw == "m1-2026-11|2026-11-01", "the moved copy lands on m1-2026-11's 2026-11-01")
            s.deliver()
            keep(monthMoveDestination, s, "m1-2026-11")
            keep(monthMoveSource, s, "m1-2026-10")
            finish(s)
        }
        // 10. The year: a line centred on 2027's date column (window x 2,728 … 2,926, centre 2,827 = y-2027's x 27) goes to
        // its January, 01-20 (row 20: y 1,140 … 1,200), x −128 … 70; a line in row 10 from 2026's December to the right
        // (window x 2,600 … 2,920, centre 2,760 = y-2026's x 1,360, December) goes to y-2026's 12-10, paper x 1,200 … 1,520.
        do {
            var s = Session(empty(years), plan: plan(.year), seed: 0x5A01_4310, firstTime: baseTime + 1000)
            s.draw(line(2728, 2926, y: 1170, count: 7), owner: "y-2027", cell: .yearDay(month: 1, day: 20))
            s.draw(line(2600, 2920, y: 570), owner: "y-2026", cell: .yearDay(month: 12, day: 10), color: "#dc2626")
            s.deliver()
            keep(yearDateColumn, s, "y-2027")
            keep(yearDecemberRight, s, "y-2026")
            finish(s)
        }
        // 11. A Sunday-start month window: a memo line of m1-2026-11 crossing into December, x 1,100 … 1,600 of the memo
        // (window 2,500 … 3,000, centre 2,750: November's), 300 lu below the memo's top.
        do {
            var s = Session(empty(months), plan: plan(.month, .sunday), seed: 0x5A01_4311, firstTime: baseTime + 1100)
            s.draw(line(2500, 3000, y: 1350), owner: "m1-2026-11", cell: .memo, color: "#16a34a")
            s.deliver()
            keep(monthMemoSunday, s, "m1-2026-11")
            finish(s)
        }
        // 12. The year's lengthened row: y-2026's row 15 at 392 lu (its top at y 840); a line in June (06-15: window x
        // 2,016 … 2,128) 350 lu below the cell's top.
        do {
            var s = Session(empty(years), plan: plan(.year), seed: 0x5A01_4312, firstTime: baseTime + 1200,
                            rowStandIn: ["y-2026": [yearRowCell: yearRowStandIn]])
            s.draw(line(2046, 2106, y: 1190, count: 5), owner: "y-2026", cell: yearRowCell, color: "#2563eb")
            s.deliver()
            keep(yearRowFloor, s, "y-2026")
            finish(s)
        }
        // 13. The month's lengthened last row (form ア): m1-2026-11's row 6 at 712 lu (its top at y 875); a line in
        // 2026-12-03 (column 4: window x 2,000 … 2,200) 600 lu below the cell's top.
        do {
            var s = Session(empty(months), plan: plan(.month), seed: 0x5A01_4313, firstTime: baseTime + 1300,
                            rowStandIn: ["m1-2026-11": [monthRowCell: monthRowStandIn]])
            s.draw(line(2030, 2170, y: 1475, count: 6), owner: "m1-2026-11", cell: monthRowCell)
            s.deliver()
            keep(monthLastRow, s, "m1-2026-11")
            finish(s)
        }

        return Made(files: entries.map { ($0.name, files[$0.name]!) }, saves: saves, recovered: recovered, deltaCount: deltaCount, cells: cells)
    }
}
