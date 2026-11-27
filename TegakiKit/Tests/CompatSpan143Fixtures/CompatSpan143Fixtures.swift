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
/// How 12 and 13 get their tall row: through 1.4.3's floors, as a joined window lays its pages out when it opens
/// (`windowLayouts`: every page from its own ink without floors, the window's floors from those natural numbers with
/// `SpanAlign.yearFloors` / `SpanAlign.monthFloors(form: .memo)`, then every page with them through
/// `YearLayoutInput.rowFloors` / `MonthLayoutInput.gridFloor`). The tall row comes from a neighbour page that holds a
/// deep line in the same row (12: `y-2027`'s 03-15 to 380 lu, so row 15 is 392 on every year of the window; 13:
/// `m1-2026-12`'s 2026-12-16 to 700 lu, so its grid ends at 1,587 and November's 6th row reaches 1,587 − 875 = 712). The
/// neighbour's line is a stored stroke of its page (a line 380 or 700 lu down a row is written by growing the row stroke
/// after stroke, which the session sim does not do); only the fixture's page is saved. So the path is floors →
/// `SpanLayout.drop`/`inkCell` → `SpanLedgerSim` → saved bytes. Until the merge with role K's floors (step D1a) the maker
/// fed the fixture page's own ink-bottom input instead; the bytes are the same either way, because the points are stored
/// relative to the cell, whose origin does not move (the rows above do not move, §4.1, §5.1). KitChecks compares the
/// committed files with `make()` on every run, so a maker that gave other bytes would fail there.
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

    /// Fixture 12's row: `y-2026`'s row 15 at 392 lu (60 natural), the floor from the neighbour year `y-2027` whose row 15
    /// holds a line ending 380 lu below its top (`yearNeighbourCell`, `yearNeighbourBottom`).
    public static let yearRowCell = CellKey.yearDay(month: 6, day: 15)
    public static let yearNeighbourCell = CellKey.yearDay(month: 3, day: 15)
    public static let yearNeighbourBottom: CGFloat = 380
    /// Fixture 13's row: `m1-2026-11`'s row 6 (2026-11-30 … 2026-12-06 with the Monday start) at 712 lu (175 natural),
    /// what form ア's grid floor gives in a window whose tallest grid ends at 1,587 lu (rows 1–5 stay 175 lu each): the
    /// neighbour `m1-2026-12` has a line ending 700 lu down 2026-12-16 (its 3rd row: 712, grid 4 × 175 + 712 + 175).
    public static let monthRowCell = CellKey.day(DayKey(year: 2026, month: 12, day: 3))
    public static let monthNeighbourCell = CellKey.day(DayKey(year: 2026, month: 12, day: 16))
    public static let monthNeighbourBottom: CGFloat = 700

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

    /// The window's pages as a joined window of 1.4.3 lays them out when it opens (docs/R1_4_3_CONTRACT.md §3.3, §4.1,
    /// §5.1; no event, `CompatFixtures.now`, Tokyo): every page from its own ink (`InkPage.inkBottoms()`) without floors,
    /// the window's floors from those natural numbers (`.redecide`: a new window) — the month's by form ア
    /// (`SpanAlign.monthFloors(form: .memo)`; fixture 13 is ア's whatever `SpanAlign.monthForm` is), the year's by
    /// `SpanAlign.yearFloors` — and every page again with them. For the empty pages of 8–11 the floors are the natural
    /// rows, so nothing moves.
    static func windowLayouts(_ pages: [InkPage], weekStart: WeekStart) -> [any PageLayout] {
        let now = CompatFixtures.now
        let tokyo = CompatFixtures.tokyo
        let parsed = pages.map { page -> (kind: PageKind, focus: DayKey) in
            guard let p = PageNavigation.parse(pageId: page.pageId) else { preconditionFailure("not a page id: \(page.pageId)") }
            return p
        }
        guard let kind = parsed.first?.kind, parsed.allSatisfy({ $0.kind == kind }) else {
            preconditionFailure("a window holds pages of one kind: \(pages.map(\.pageId))")
        }
        switch kind {
        case .month:
            let inputs = zip(pages, parsed).map { page, p in
                MonthLayoutInput(month: YearMonth(year: p.focus.year, month: p.focus.month), events: [], inkBottoms: page.inkBottoms(),
                                 now: now, calendar: tokyo, weekStart: weekStart)
            }
            let naturals = inputs.map { SpanAlign.MonthNatural(MonthLayoutEngine.layout($0)) }
            let floors = SpanAlign.monthFloors(previous: .none, naturals: naturals, form: .memo, change: .redecide)
            return inputs.map { MonthLayoutEngine.layout($0.floored(by: floors)) }
        case .year:
            let inputs = zip(pages, parsed).map { page, p in
                YearLayoutInput(year: p.focus.year, events: [], inkBottoms: page.inkBottoms(), now: now, calendar: tokyo)
            }
            let floors = SpanAlign.yearFloors(previous: .none, naturalRows: inputs.map { SpanAlign.naturalRows(of: YearLayoutEngine.layout($0)) },
                                              change: .redecide)
            return inputs.map { YearLayoutEngine.layout($0.floored(by: floors)) }
        case .day, .week:
            preconditionFailure("compat-span-143 holds months and years only: \(pages.map(\.pageId))")
        }
    }

    /// A page holding one stored line in `cell` that ends `bottom` lu below the cell's top (5 points 30 … 90 lu across,
    /// nib 4 lu, every other point 6 lu higher): the neighbour that lengthens the row of 12 or 13 through the floors.
    static func neighbour(_ pageId: String, cell: CellKey, bottom: CGFloat, id: String, t: Int) -> InkPage {
        let points = (0..<5).map { i in
            InkPoint(x: CGFloat(30 + 15 * i), y: bottom - 2 - CGFloat(i % 2 == 0 ? 6 : 0), dtMs: 16 * i, sizeW: 4, sizeH: 4,
                     opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5)
        }
        var page = InkPage(pageId: pageId)
        page.add(InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: device, points: points))
        precondition(page.inkBottoms()[cell] == bottom, "the neighbour's line ends \(bottom) lu down \(cell.raw)")
        return page
    }

    /// A line of `count` points from x0 to x1 (window lu) around y, every other point 6 lu lower (compat-span's shape).
    static func line(_ x0: CGFloat, _ x1: CGFloat, y: CGFloat, count: Int = 9) -> [CGPoint] {
        (0..<count).map { i in CGPoint(x: x0 + (x1 - x0) * CGFloat(i) / CGFloat(count - 1), y: y + CGFloat(i % 2) * 6) }
    }

    struct Session {
        var sim: SpanLedgerSim
        var slots: SpanSlotsSim
        var deltas = 0

        init(_ pages: [InkPage], plan: SpanPlan, seed: UInt64, firstTime: Int) {
            let layouts = CompatSpan143Fixtures.windowLayouts(pages, weekStart: plan.weekStart)
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
        // 12. The year's lengthened row: y-2027's line 380 lu down 03-15 makes row 15 of the window 392 lu, so y-2026's row
        // 15 is 392 lu (its top at y 840); a line in June (06-15: window x 2,016 … 2,128) 350 lu below the cell's top.
        do {
            let pages = [InkPage(pageId: years[0]), InkPage(pageId: years[1]),
                         neighbour(years[2], cell: yearNeighbourCell, bottom: yearNeighbourBottom, id: "c143-0012-neighbour", t: baseTime + 1190)]
            let row = windowLayouts(pages, weekStart: .monday)[1].cells[yearRowCell]
            precondition(row == CGRect(x: 616, y: 840, width: 112, height: 392), "the floor makes y-2026's 06-15 392 lu tall (\(String(describing: row)))")
            var s = Session(pages, plan: plan(.year), seed: 0x5A01_4312, firstTime: baseTime + 1200)
            s.draw(line(2046, 2106, y: 1190, count: 5), owner: "y-2026", cell: yearRowCell, color: "#2563eb")
            s.deliver()
            keep(yearRowFloor, s, "y-2026")
            finish(s)
        }
        // 13. The month's lengthened last row (form ア): m1-2026-12's line 700 lu down 2026-12-16 ends its grid at 1,587, so
        // m1-2026-11's row 6 is 712 lu (its top at y 875); a line in 2026-12-03 (column 4: window x 2,000 … 2,200) 600 lu
        // below the cell's top.
        do {
            let pages = [InkPage(pageId: months[0]), InkPage(pageId: months[1]),
                         neighbour(months[2], cell: monthNeighbourCell, bottom: monthNeighbourBottom, id: "c143-0013-neighbour", t: baseTime + 1290)]
            let row = windowLayouts(pages, weekStart: .monday)[1].cells[monthRowCell]
            precondition(row == CGRect(x: 600, y: 875, width: 200, height: 712), "form ア's floor makes m1-2026-11's 2026-12-03 712 lu tall (\(String(describing: row)))")
            var s = Session(pages, plan: plan(.month), seed: 0x5A01_4313, firstTime: baseTime + 1300)
            s.draw(line(2030, 2170, y: 1475, count: 6), owner: "m1-2026-11", cell: monthRowCell)
            s.deliver()
            keep(monthLastRow, s, "m1-2026-11")
            finish(s)
        }

        return Made(files: entries.map { ($0.name, files[$0.name]!) }, saves: saves, recovered: recovered, deltaCount: deltaCount, cells: cells)
    }
}
