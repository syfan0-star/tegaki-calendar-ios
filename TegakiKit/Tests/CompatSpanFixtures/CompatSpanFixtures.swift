import Foundation
import CoreGraphics
import InkModel
import Layout
import CompatFixtures

/// The compat-span fixtures of 1.3 (docs/M7C_CONTRACT.md §4.2, §6.3, K-7): pages written by the joined
/// path of the Kit — a window composed with `SpanComposer`, the ledger's steps (`SpanLedgerSim`), the
/// journal turned into `PageDelta`s, applied with `InkPage.add` / `remove` to the real pages
/// (`SpanSlotsSim`), the safety net, `SpanGuard.checkForSave` and `InkPageCodec.encode` — so the bytes
/// are what 1.3 saves. S5's XCTest `testSpanSessionWritesTheCompatSpanShapes` makes them again through
/// the app's own save path (`PageSlot.persist`) and compares byte for byte (§4.2).
///
/// 1. Strokes reaching out of their page (§4.2): a Monday week 300 lu to the left (from the Sunday
///    night of the week before), a day 300 lu to the right in `grid` and in `extra`, a month 250 lu to
///    the right in a day cell and in `memo`, a year from December 288 lu to the right and January
///    below x 0. (Months and years are joined from 1.7 / 1.8; their fixtures are in from now on.)
/// 2. A lasso move across pages: a tombstone on the source page, a copy with a new id on the destination.
/// 3. Free-memo strokes crossing two days (`extra`), one owned by each day.
/// 5. A Sunday-start week (`w-<Sunday>`) reaching out on both sides.
/// 6. The day two month pages share: the same cell name on both pages, a stroke on each.
/// 7. Items of tools 1.2.3 does not know, as the photo and the text label of 1.6 will write them
///    (`"tool":"photo"` with `rect` and `img`, `"tool":"text"` with `rect` and `text`,
///    PLAN_PHOTO_TEXT.md:41, :46): hand-written JSON read the way the store reads a file, put into a
///    window with strokes written and erased by the session around them, and saved through the same path;
///    the neighbour page gets a leak of window names (its own prefix, another page's, a stripped alias)
///    that the guard repairs before the save. No fixture is hand-written JSON alone.
/// Fixture 4 (the week memo's `extra` and a week `grid` stroke moved below 24:00) belongs to the week memo
/// stage (§5); it is not made here and not in the MANIFEST yet.
///
/// Ids come from seeds, times are 1,791,000,000,000 + n, the layouts use `CompatFixtures.now` and Tokyo,
/// so the bytes are the same on every run and every machine. `KitChecks --write-compat-span-fixtures
/// [--out <folder>]` calls `write(to:)`; KitChecks compares the committed files with `make()`.
public enum CompatSpanFixtures {
    /// The shape of a file for CI (§6.3): "monday" files are copied into the compat11 folder and read by
    /// 1.0's runs there (`RunReal`, `RunFrozen`, `Real10LedgerTests`, which lay every `w-` out as a Monday
    /// week); "sunday" files (a Sunday-start week) are read by `CompatSpanTests` and `tools/span-compat`
    /// only. Pages that are not weeks are "monday" (they open the same way in every version).
    public enum Shape: String, Sendable {
        case monday, sunday
    }

    public struct Entry: Equatable, Sendable {
        public let name: String
        public let fixture: Int
        public let shape: Shape

        public init(name: String, fixture: Int, shape: Shape) {
            self.name = name
            self.fixture = fixture
            self.shape = shape
        }
    }

    public static let manifestName = "MANIFEST"
    public static let device = "fixture-1.3"
    public static let baseTime = 1_791_000_000_000

    public static let weekOverhang = "w-2026-11-02.overhang-left.json"
    public static let dayOverhang = "d-2026-11-03.overhang-right.json"
    public static let monthOverhang = "m1-2026-11.overhang-right.json"
    public static let yearOverhang = "y-2026.overhang.json"
    public static let moveSource = "w-2026-11-16.move-source.json"
    public static let moveDestination = "w-2026-11-23.move-destination.json"
    public static let extraCrossLeft = "d-2026-11-09.extra-cross.json"
    public static let extraCrossRight = "d-2026-11-10.extra-cross.json"
    public static let sundayOverhang = "w-2026-11-08.sunday-overhang.json"
    public static let overlapNovember = "m1-2026-11.overlap-day.json"
    public static let overlapDecember = "m1-2026-12.overlap-day.json"
    public static let photoText = "w-2026-11-30.photo-text.json"
    public static let photoTextNeighbor = "w-2026-12-07.photo-text-neighbor.json"

    /// The MANIFEST's lines, in its order.
    public static let entries: [Entry] = [
        Entry(name: dayOverhang, fixture: 1, shape: .monday),
        Entry(name: monthOverhang, fixture: 1, shape: .monday),
        Entry(name: weekOverhang, fixture: 1, shape: .monday),
        Entry(name: yearOverhang, fixture: 1, shape: .monday),
        Entry(name: moveSource, fixture: 2, shape: .monday),
        Entry(name: moveDestination, fixture: 2, shape: .monday),
        Entry(name: extraCrossLeft, fixture: 3, shape: .monday),
        Entry(name: extraCrossRight, fixture: 3, shape: .monday),
        Entry(name: sundayOverhang, fixture: 5, shape: .sunday),
        Entry(name: overlapNovember, fixture: 6, shape: .monday),
        Entry(name: overlapDecember, fixture: 6, shape: .monday),
        Entry(name: photoText, fixture: 7, shape: .monday),
        Entry(name: photoTextNeighbor, fixture: 7, shape: .monday),
    ]

    /// `Tests/Fixtures/compat-span/` of this checkout (found from this file, no bundle resources).
    public static var committedFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CompatSpanFixtures/
            .deletingLastPathComponent()   // Tests/
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("compat-span", isDirectory: true)
    }

    /// `MANIFEST`: two comment lines, then "<file> <fixture> <shape>" per file.
    public static func manifestData() -> Data {
        var text = "# compat-span fixtures (docs/M7C_CONTRACT.md §4.2, §6.3), made by KitChecks --write-compat-span-fixtures.\n"
        text += "# One line per file: <file> <fixture number> <shape>; CI copies the files of shape monday into the compat11 folder.\n"
        for e in entries { text += "\(e.name) \(e.fixture) \(e.shape.rawValue)\n" }
        return Data(text.utf8)
    }

    /// The entries a MANIFEST's text lists (comment and empty lines skipped); nil when a line is malformed.
    public static func parseManifest(_ data: Data) -> [Entry]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var out: [Entry] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) where !line.hasPrefix("#") {
            let parts = line.split(separator: " ")
            guard parts.count == 3, let n = Int(parts[1]), let shape = Shape(rawValue: String(parts[2])) else { return nil }
            out.append(Entry(name: String(parts[0]), fixture: n, shape: shape))
        }
        return out
    }

    // MARK: - Making them

    /// What making the fixtures gives: the files (in `entries` order) and what happened on the way.
    public struct Made: Sendable {
        public let files: [(name: String, data: Data)]
        /// `SpanGuard.checkForSave` of each file's page as it was saved.
        public let saves: [String: SpanGuard.SaveCheck]
        /// Pages the safety net had to bring something back to (empty: every delta arrived).
        public let recovered: [String]
        /// The hand-written pages of fixture 7 as read (by page id), and their bytes.
        public let handWritten: [String: Data]
        /// The neighbour page of fixture 7 before the leak was put into it (the guard must give it back).
        public let neighborBeforeLeak: Data
        /// The deltas each session applied, in order (all sessions).
        public let deltaCount: Int
    }

    /// The files, in `entries` order.
    public static func make() -> [(name: String, data: Data)] {
        made.files
    }

    public static var made: Made { madeOnce }

    private static let madeOnce: Made = build()

    public enum WriteResult: String, Sendable {
        case new, unchanged, changed
    }

    /// Writes every fixture and `MANIFEST` into `folder` (made when missing) and says, per file, whether it
    /// was new, unchanged or changed. Other files are not touched.
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

    static func layout(_ pageId: String, weekStart: WeekStart = .monday) -> any PageLayout {
        guard let parsed = PageNavigation.parse(pageId: pageId) else { preconditionFailure("not a page id: \(pageId)") }
        let now = CompatFixtures.now
        let tokyo = CompatFixtures.tokyo
        switch parsed.kind {
        case .day:
            return DayLayoutEngine.layout(DayLayoutInput(day: parsed.focus, events: [], inkBottoms: [:], now: now, calendar: tokyo))
        case .week:
            return WeekLayoutEngine.layout(WeekLayoutInput(focus: parsed.focus, events: [], inkBottoms: [:], now: now, calendar: tokyo, weekStart: weekStart))
        case .month:
            return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: parsed.focus.year, month: parsed.focus.month), events: [], inkBottoms: [:], now: now, calendar: tokyo))
        case .year:
            return YearLayoutEngine.layout(YearLayoutInput(year: parsed.focus.year, events: [], inkBottoms: [:], now: now, calendar: tokyo))
        }
    }

    /// A line of `count` points from x0 to x1 (window lu) around y, every other point 6 lu lower.
    static func line(_ x0: CGFloat, _ x1: CGFloat, y: CGFloat, count: Int = 9) -> [CGPoint] {
        (0..<count).map { i in CGPoint(x: x0 + (x1 - x0) * CGFloat(i) / CGFloat(count - 1), y: y + CGFloat(i % 2) * 6) }
    }

    struct Session {
        var sim: SpanLedgerSim
        var slots: SpanSlotsSim
        var deltas = 0

        init(_ pages: [InkPage], plan: SpanPlan, seed: UInt64, firstTime: Int) {
            let layouts = pages.map { CompatSpanFixtures.layout($0.pageId, weekStart: plan.weekStart) }
            let window = SpanLayout(pages: layouts, plan: plan, firstIndex: plan.index(of: pages[0].pageId)!, session: 0)
            let virtual = SpanComposer.compose(pages, plan: plan, session: 0)
            precondition(virtual.pageIds == pages.map(\.pageId) && virtual.pageId == window.pageId, "the window's pages")
            sim = SpanLedgerSim(virtual: virtual, layout: window, seed: seed, firstTime: firstTime, dev: CompatSpanFixtures.device)
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
        var handWritten: [String: Data] = [:]
        var neighborBeforeLeak = Data()
        func keep(_ name: String, _ s: Session, _ pageId: String) {
            let saved = s.save(pageId)
            files[name] = saved.data
            saves[name] = saved.check
        }
        func finish(_ s: Session) {
            recovered += s.slots.recovered
            deltaCount += s.deltas
        }
        func empty(_ ids: [String]) -> [InkPage] { ids.map { InkPage(pageId: $0) } }

        // 1. Out of the page: week (Monday) to the left, from the Sunday night of the week before.
        do {
            var s = Session(empty(["w-2026-10-26", "w-2026-11-02", "w-2026-11-09"]), plan: plan(.week), seed: 0x5A01_0001, firstTime: baseTime + 100)
            s.draw(line(1100, 1900, y: 1880), owner: "w-2026-11-02", cell: .grid)
            s.deliver()
            keep(weekOverhang, s, "w-2026-11-02")
            finish(s)
        }
        // 1. Day to the right, in grid and in extra.
        do {
            var s = Session(empty(["d-2026-11-02", "d-2026-11-03", "d-2026-11-04"]), plan: plan(.day), seed: 0x5A01_0002, firstTime: baseTime + 200)
            s.draw(line(1690, 2300, y: 1000), owner: "d-2026-11-03", cell: .grid)
            s.draw(line(1690, 2300, y: 4000), owner: "d-2026-11-03", cell: .extra, color: "#dc2626")
            s.deliver()
            keep(dayOverhang, s, "d-2026-11-03")
            finish(s)
        }
        // 1. Month to the right: November 8 (the last column) and the memo.
        do {
            var s = Session(empty(["m1-2026-10", "m1-2026-11", "m1-2026-12"]), plan: plan(.month), seed: 0x5A01_0003, firstTime: baseTime + 300)
            s.draw(line(2540, 3050, y: 260), owner: "m1-2026-11", cell: .day(DayKey(year: 2026, month: 11, day: 8)))
            s.draw(line(2540, 3050, y: 1400), owner: "m1-2026-11", cell: .memo, tool: .marker, color: "#fde047", size: 18)
            s.deliver()
            keep(monthOverhang, s, "m1-2026-11")
            finish(s)
        }
        // 1. Year: from December 20 to the right, January 20 below x 0.
        do {
            var s = Session(empty(["y-2025", "y-2026", "y-2027"]), plan: plan(.year), seed: 0x5A01_0004, firstTime: baseTime + 400)
            s.draw(line(2500, 3088, y: 1170, count: 8), owner: "y-2026", cell: .yearDay(month: 12, day: 20))
            s.draw(line(1300, 1660, y: 1170, count: 7), owner: "y-2026", cell: .yearDay(month: 1, day: 20))
            s.deliver()
            keep(yearOverhang, s, "y-2026")
            finish(s)
        }
        // 2. A move across pages: two strokes written on w-11-16, saved; the next session moves one a week on.
        do {
            let ids = ["w-2026-11-09", "w-2026-11-16", "w-2026-11-23"]
            var first = Session(empty(ids), plan: plan(.week), seed: 0x5A01_0005, firstTime: baseTime + 500)
            first.draw(line(1700, 1900, y: 800, count: 6), owner: "w-2026-11-16", cell: .grid)
            first.draw(line(2100, 2300, y: 1200, count: 6), owner: "w-2026-11-16", cell: .grid, color: "#2563eb")
            first.deliver()
            let stored = first.save("w-2026-11-16").data
            finish(first)
            guard let read = try? InkPageCodec.decode(stored) else { preconditionFailure("the saved page reads") }
            var s = Session([InkPage(pageId: ids[0]), read, InkPage(pageId: ids[2])], plan: plan(.week), seed: 0x5A01_0006, firstTime: baseTime + 600)
            let moving = s.sim.page.liveStrokes.min { $0.t < $1.t }!
            let copies = s.sim.move([moving.id], by: CGVector(dx: 1400, dy: 0))
            precondition(copies.count == 1 && copies[0].cell.raw == "w-2026-11-23|grid", "the moved copy lands on w-2026-11-23")
            s.deliver()
            keep(moveDestination, s, "w-2026-11-23")
            keep(moveSource, s, "w-2026-11-16")
            finish(s)
        }
        // 3. The free memo (extra) across two days, one stroke owned by each.
        do {
            var s = Session(empty(["d-2026-11-09", "d-2026-11-10", "d-2026-11-11"]), plan: plan(.day), seed: 0x5A01_0007, firstTime: baseTime + 700)
            s.draw(line(600, 1300, y: 3500), owner: "d-2026-11-09", cell: .extra)
            s.draw(line(700, 1600, y: 5200), owner: "d-2026-11-10", cell: .extra, color: "#16a34a")
            s.deliver()
            keep(extraCrossLeft, s, "d-2026-11-09")
            keep(extraCrossRight, s, "d-2026-11-10")
            finish(s)
        }
        // 5. A Sunday-start week, out on both sides.
        do {
            var s = Session(empty(["w-2026-11-01", "w-2026-11-08", "w-2026-11-15"]), plan: plan(.week, .sunday), seed: 0x5A01_0008, firstTime: baseTime + 800)
            s.draw(line(1100, 1900, y: 1840), owner: "w-2026-11-08", cell: .grid)
            s.draw(line(2300, 3100, y: 400), owner: "w-2026-11-08", cell: .grid, color: "#dc2626")
            s.deliver()
            keep(sundayOverhang, s, "w-2026-11-08")
            finish(s)
        }
        // 6. November 30 and December 1 on both month pages.
        do {
            var s = Session(empty(["m1-2026-11", "m1-2026-12"]), plan: plan(.month), seed: 0x5A01_0009, firstTime: baseTime + 900)
            s.draw(line(230, 330, y: 960, count: 5), owner: "m1-2026-11", cell: .day(DayKey(year: 2026, month: 12, day: 1)))
            s.draw(line(30, 130, y: 940, count: 5), owner: "m1-2026-11", cell: .day(DayKey(year: 2026, month: 11, day: 30)))
            s.draw(line(1630, 1730, y: 85, count: 5), owner: "m1-2026-12", cell: .day(DayKey(year: 2026, month: 12, day: 1)), color: "#2563eb")
            s.draw(line(1430, 1530, y: 100, count: 5), owner: "m1-2026-12", cell: .day(DayKey(year: 2026, month: 11, day: 30)), color: "#2563eb")
            s.deliver()
            keep(overlapNovember, s, "m1-2026-11")
            keep(overlapDecember, s, "m1-2026-12")
            finish(s)
        }
        // 7. The photo and the text label of a later version, hand-written, in a window with the session's ink.
        do {
            let photoPage = Data(photoTextJSON.utf8)
            let neighborPage = Data(photoNeighborJSON.utf8)
            guard let read = try? InkPageCodec.decode(photoPage), let readNeighbor = try? InkPageCodec.decode(neighborPage) else {
                preconditionFailure("the hand-written pages read")
            }
            precondition(read.unknownStrokes.count == 2 && readNeighbor.unknownStrokes.count == 1, "the hand-written items are unknown tools")
            handWritten = ["w-2026-11-30": photoPage, "w-2026-12-07": neighborPage]
            var s = Session([InkPage(pageId: "w-2026-11-23"), read, readNeighbor], plan: plan(.week), seed: 0x5A01_000A, firstTime: baseTime + 1000)
            let crossing = s.draw(line(2300, 3100, y: 600), owner: "w-2026-11-30", cell: .grid)
            let handPen = "w-2026-11-30|" + handPenId
            precondition(s.sim.erase([handPen]) == [handPen], "the hand-written pen stroke is erased")
            let neighborStroke = s.draw(line(3100, 3400, y: 1000, count: 6), owner: "w-2026-12-07", cell: .grid, color: "#2563eb")
            s.deliver()
            neighborBeforeLeak = s.save("w-2026-12-07").data
            // A leak into the neighbour's slot: the page's own window names (a stroke and the photo), another
            // page's stroke and a stripped alias. The guard strips the first two and drops the others.
            s.slots.edit("w-2026-12-07") { page in
                page.strokes[neighborStroke.id] = neighborStroke
                page.unknownStrokes["w-2026-12-07|" + neighborPhotoId] = page.unknownStrokes[neighborPhotoId]
                page.strokes[crossing.id] = crossing
                page.deleted["span~a~1"] = baseTime + 1999
            }
            keep(photoText, s, "w-2026-11-30")
            keep(photoTextNeighbor, s, "w-2026-12-07")
            finish(s)
        }

        return Made(files: entries.map { ($0.name, files[$0.name]!) }, saves: saves, recovered: recovered, handWritten: handWritten,
                    neighborBeforeLeak: neighborBeforeLeak, deltaCount: deltaCount)
    }

    // MARK: - Fixture 7's hand-written pages (PLAN_PHOTO_TEXT.md:41)

    public static let handPenId = "3f6c2a9e-1d4b-4e7a-8c5f-0a9b8c7d6e51"
    public static let photoId = "9a1e5c7b-2f3d-4b6a-8e9c-1d2e3f4a5b62"
    public static let textId = "c4d8e2f6-3a5b-4c7d-9e1f-2a3b4c5d6e73"
    public static let neighborPhotoId = "5b7d9f1a-4c6e-4a8b-9d2f-3e4a5b6c7d84"
    public static let photoDigest = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    /// w-2026-11-30 as a later version (1.6) and 1.2 wrote it: a pen stroke, a photo, a text label (whose
    /// rect reaches past the page's right edge).
    public static let photoTextJSON = """
    {"v":1,"pageId":"w-2026-11-30","updatedAt":1791000000003,"deleted":{},"strokes":{\
    "\(handPenId)":{"id":"\(handPenId)","cell":"grid","tool":"pen","color":"#1f2937","t":1791000000001,"dev":"fixture-1.2",\
    "pts":[300,700,0,3.5,3.5,1,0.5,0.785,1.2,340,706,8,3.5,3.5,1,0.5,0.785,1.2,380,700,16,3.5,3.5,1,0.5,0.785,1.2]},\
    "\(photoId)":{"id":"\(photoId)","cell":"grid","tool":"photo","t":1791000000002,"dev":"fixture-1.6",\
    "rect":[120,340,360,240],"img":"\(photoDigest)"},\
    "\(textId)":{"id":"\(textId)","cell":"grid","tool":"text","t":1791000000003,"dev":"fixture-1.6",\
    "rect":[1250,900,300,80],"text":"牛乳を買う"}}}
    """

    /// w-2026-12-07 with one photo whose rect starts left of the page.
    public static let photoNeighborJSON = """
    {"v":1,"pageId":"w-2026-12-07","updatedAt":1791000000004,"deleted":{},"strokes":{\
    "\(neighborPhotoId)":{"id":"\(neighborPhotoId)","cell":"grid","tool":"photo","t":1791000000004,"dev":"fixture-1.6",\
    "rect":[-80,1500,320,200],"img":"\(photoDigest)"}}}
    """
}
