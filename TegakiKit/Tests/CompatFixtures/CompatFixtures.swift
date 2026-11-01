import Foundation
import CoreGraphics
import CryptoKit
import InkModel
import Layout

/// K's golden fixtures of 1.1 (M7A_CONTRACT §1.4, K-7), written by the new code: every stroke's cell
/// comes from the new layouts' `inkCell(forCenter:)` (the day page's `extra` below 24:00 included) and
/// its points are relative to that cell, as the 1.1 ledger stores them. Ids are lower-case UUIDs made
/// from a seed, times are 1,790,000,000,000 + n, so the bytes are the same on every run and every
/// machine.
///
/// The small fixtures are committed in `Tests/Fixtures/compat11/`; the large ones are made again
/// whenever they are needed and only their sha256 is committed (`digests.json`). The fixtures of P
/// (`ledger-*.json`) and U (`screenshot-*.json`) live in the same folder, but nothing here writes,
/// removes or compares them (0-23).
///
/// `KitChecks --write-compat-fixtures [--out <folder>]` calls `write(to:)`.
public enum CompatFixtures {
    public static let dayPage = "d-2026-11-02.json"
    public static let dayFrom10 = "d-2026-11-02.from10.json"
    public static let dayMoved = "d-2026-11-04.moved.json"
    public static let monthPage = "m1-2026-11.json"
    public static let monthFrom10 = "m1-2026-12.from10.json"
    public static let weekLegacy = "w-2026-11-02.legacy.json"
    public static let export11 = "export-1.1.json"
    public static let n15000 = "y-2026.n15000.json"
    public static let n20500 = "y-2026.n20500.json"
    public static let tomb200500 = "y-2026.tomb200500.json"
    public static let digests = "digests.json"
    public static let smallNames = [dayPage, dayFrom10, dayMoved, monthPage, monthFrom10, weekLegacy, export11]
    public static let largeNames = [n15000, n20500, tomb200500]

    /// t of the n-th stroke or tombstone of a fixture: 1,790,000,000,000 + n.
    public static let baseTime = 1_790_000_000_000
    /// `dev` of the strokes a 1.1 device writes in the fixtures, and of those "a 1.0 device" adds.
    public static let device11 = "fixture-1.1"
    public static let device10 = "fixture-1.0"

    /// `Tests/Fixtures/compat11/` of this checkout (found from this file, no bundle resources).
    public static var committedFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CompatFixtures/
            .deletingLastPathComponent()   // Tests/
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("compat11", isDirectory: true)
    }

    // MARK: - The files

    /// K's small fixtures, in `smallNames` order.
    public static func make() -> [(name: String, data: Data)] {
        let day = dayPage11()
        let month = monthPage11()
        let legacy = weekLegacyPage()
        return [
            (dayPage, encode(day)),
            (dayFrom10, encode(dayFrom10Page())),
            (dayMoved, encode(dayMovedPage())),
            (monthPage, encode(month)),
            (monthFrom10, encode(monthFrom10Page())),
            (weekLegacy, encode(legacy)),
            (export11, exportData(pages: [day, month, BandMigration.migrate(legacy)])),
        ]
    }

    /// K's large fixtures (made once per process), in `largeNames` order.
    public static func makeLarge() -> [(name: String, data: Data)] {
        largeFiles
    }

    private static let largeFiles: [(name: String, data: Data)] = [
        (n15000, encode(yearPage(strokes: 15_000, unknownEvery: nil, seed: 0x1500_0001))),
        (n20500, encode(yearPage(strokes: 20_500, unknownEvery: 103, seed: 0x2050_0001))),
        (tomb200500, encode(tombstonePage(count: 200_500, seed: 0x2005_0001))),
    ]

    /// `digests.json`: `{ "<large fixture>": "<sha256 hex>", … }`, keys sorted, readable, final "\n".
    public static func digestsData() -> Data {
        var object: [String: JSONValue] = [:]
        for (name, data) in makeLarge() { object[name] = .string(sha256Hex(data)) }
        return Data((JSONValue.object(object).serialized(pretty: true) + "\n").utf8)
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public enum WriteResult: String, Sendable {
        case new, unchanged, changed
    }

    /// Writes K's small and large fixtures and `digests.json` into `folder` (made when missing) and
    /// says, per file, whether it was new, unchanged or changed. Other files are not touched.
    @discardableResult
    public static func write(to folder: URL) throws -> [(name: String, result: WriteResult)] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var out: [(name: String, result: WriteResult)] = []
        for (name, data) in make() + makeLarge() + [(digests, digestsData())] {
            let url = folder.appendingPathComponent(name)
            let old = try? Data(contentsOf: url)
            let result: WriteResult = old == nil ? .new : (old == data ? .unchanged : .changed)
            if result != .unchanged { try data.write(to: url, options: .atomic) }
            out.append((name, result))
        }
        return out
    }

    /// A folder for the checks: every committed `*.json` of `committed` (P's and U's fixtures and
    /// `digests.json` included; a large fixture lying there is not used) and K's large fixtures made
    /// again, except `skippingLarge`.
    public static func prepare(from committed: URL, into folder: URL, skippingLarge: Set<String> = []) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in try fm.contentsOfDirectory(atPath: committed.path).sorted()
        where name.hasSuffix(".json") && !largeNames.contains(name) {
            let target = folder.appendingPathComponent(name)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: committed.appendingPathComponent(name), to: target)
        }
        for (name, data) in makeLarge() where !skippingLarge.contains(name) {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
    }

    // MARK: - Building blocks (also used by Compat10Tests)

    /// Lower-case UUIDs (version 4 form) from a seed: xorshift64*.
    public struct SeededIds {
        private var state: UInt64

        public init(seed: UInt64) {
            state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
        }

        public mutating func nextUInt64() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2_685_821_657_736_338_717
        }

        public mutating func next() -> String {
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

    /// A stroke as plain values (so a test can build the same stroke with the frozen 1.0 copy).
    public struct StrokeSpec: Equatable, Sendable {
        public var id: String
        public var cell: String
        public var tool: String
        public var color: String
        public var t: Int
        public var dev: String?
        /// `InkPoint.flat` of the cell-relative points.
        public var pts: [Double]

        public init(_ stroke: InkStroke) {
            id = stroke.id
            cell = stroke.cell.raw
            tool = stroke.tool.rawValue
            color = stroke.color
            t = stroke.t
            dev = stroke.dev
            pts = InkPoint.flat(stroke.points)
        }
    }

    /// The fixed clock and calendar the layouts are made with (nothing in the cells depends on them).
    public static let now = Date(timeIntervalSince1970: 1_790_000_000)
    public static var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    public static func dayLayout(_ day: DayKey, ink: [CellKey: CGFloat] = [:]) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: ink, now: now, calendar: tokyo))
    }

    public static func monthLayout(_ year: Int, _ month: Int, ink: [CellKey: CGFloat] = [:]) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: year, month: month), events: [], inkBottoms: ink, now: now, calendar: tokyo))
    }

    public static func yearLayout(_ year: Int, ink: [CellKey: CGFloat] = [:]) -> YearPageLayout {
        YearLayoutEngine.layout(YearLayoutInput(year: year, events: [], inkBottoms: ink, now: now, calendar: tokyo))
    }

    /// Writes strokes the way the 1.1 ledger does: the paper points' bounds centre decides the cell
    /// (`layout.inkCell(forCenter:)`), the points become relative to that cell's origin.
    struct Writer {
        var page: InkPage
        var ids: SeededIds
        var n: Int
        let dev: String?

        init(pageId: String, seed: UInt64, firstTime: Int = 1, dev: String? = CompatFixtures.device11) {
            page = InkPage(pageId: pageId)
            ids = SeededIds(seed: seed)
            n = firstTime - 1
            self.dev = dev
        }

        mutating func time() -> Int {
            n += 1
            return CompatFixtures.baseTime + n
        }

        /// A stroke through `paper` (paper coordinates) in `layout`; `expect` is the cell it must land in.
        @discardableResult
        mutating func stroke(_ paper: [CGPoint], size: CGFloat, tool: InkTool = .pen, color: String = "#1f2937",
                             in layout: any PageLayout, expect: CellKey) -> InkStroke {
            let xs = paper.map(\.x)
            let ys = paper.map(\.y)
            let center = CGPoint(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
            let cell = layout.inkCell(forCenter: center)
            precondition(cell == expect, "fixture stroke at \(center) lands in \(cell.raw), not \(expect.raw)")
            let origin = layout.cells[cell]?.origin ?? .zero
            let points = paper.enumerated().map { i, p in
                InkPoint(x: p.x - origin.x, y: p.y - origin.y, dtMs: 8 * i, sizeW: size, sizeH: size,
                         opacity: 1, force: 0.5, azimuth: 0.785, altitude: 1.2)
            }
            let stroke = InkStroke(id: ids.next(), cell: cell, tool: tool, color: color, t: time(), dev: dev, points: points)
            page.add(stroke)
            return stroke
        }

        /// A tombstone of a stroke that is not on the page any more.
        mutating func tombstone() {
            page.remove(ids: [ids.next()], at: time())
        }
    }

    /// Six points along a line at paper y `y`, from x `x`.
    static func line(x: CGFloat, y: CGFloat, count: Int = 6, step: CGFloat = 8) -> [CGPoint] {
        (0..<count).map { CGPoint(x: x + CGFloat($0) * step, y: y) }
    }

    static func encode(_ page: InkPage) -> Data {
        // InkPageCodec.encode never throws (it only serializes).
        (try? InkPageCodec.encode(page)) ?? Data()
    }

    // MARK: - d-2026-11-02 (grid 6, extra 8, an unknown tool in extra, 3 tombstones)

    public static let dayKey = DayKey(year: 2026, month: 11, day: 2)

    public static func dayPage11() -> InkPage {
        let layout = dayLayout(dayKey)
        var w = Writer(pageId: layout.pageId, seed: 0xD202_6110_2001)
        // grid: y 700 … 2,350 (the 23 o'clock row included)
        for (i, y) in [700, 1030, 1360, 1690, 2020, 2350].enumerated() {
            w.stroke(line(x: 120 + CGFloat(i) * 40, y: CGFloat(y)), size: 3.5, in: layout, expect: .grid)
        }
        // extra: cell-relative y 30 … 5,950 (paper 2,430 … 8,350); the deepest one is thick (bottom 5,955)
        let extraYs: [CGFloat] = [30, 860, 1700, 2540, 3380, 4220, 5060, 5950]
        for (i, y) in extraYs.enumerated() {
            let size: CGFloat = i == extraYs.count - 1 ? 10 : 3.5
            w.stroke(line(x: 60 + CGFloat(i) * 100, y: 2400 + y), size: size, color: i % 2 == 0 ? "#1f2937" : "#dc2626",
                     in: layout, expect: .extra)
        }
        // A stroke of a tool 1.1 does not know either (a later version's "tape"), with an item of its own.
        let id = w.ids.next()
        let t = w.time()
        let pts = InkPoint.flat((0..<3).map { InkPoint(x: 200 + CGFloat($0) * 30, y: 300, dtMs: 8 * $0, sizeW: 24, sizeH: 24, opacity: 0.6, force: 0.5, azimuth: 0, altitude: 1.571) })
        w.page.unknownStrokes[id] = .object([
            "id": .string(id), "cell": .string("extra"), "tool": .string("tape"), "color": .string("#f59e0b"),
            "t": .number(Double(t)), "dev": .string(device11), "pts": .array(pts.map { .number($0) }), "width": .number(24),
        ])
        w.page.updatedAt = max(w.page.updatedAt, t)
        for _ in 0..<3 { w.tombstone() }
        return w.page
    }

    // MARK: - d-2026-11-02.from10 (a 1.0 device added 2 grid strokes and erased 1 grid stroke)

    /// What the 1.0 device did to `dayPage11()`: the strokes it added (1.0's day page has only
    /// `grid`, at the paper's origin) and the id it erased, at `at`.
    public static func dayFrom10Edit() -> (adds: [StrokeSpec], removes: [String], at: Int) {
        let base = dayPage11()
        var ids = SeededIds(seed: 0xD202_6110_2010)
        // 1.0's day layout has one cell, grid, at (0, 0): every stroke 1.0 writes goes there.
        var adds: [StrokeSpec] = []
        for (i, y) in [1200, 1600].enumerated() {
            let points = line(x: 300 + CGFloat(i) * 50, y: CGFloat(y)).enumerated().map { j, p in
                InkPoint(x: p.x, y: p.y, dtMs: 8 * j, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0.785, altitude: 1.2)
            }
            adds.append(StrokeSpec(InkStroke(id: ids.next(), cell: .grid, tool: .pen, color: "#2563eb", t: baseTime + 100 + i,
                                             dev: device10, points: points)))
        }
        let erased = base.liveStrokes.filter { $0.cell == .grid }.min { $0.t < $1.t }!.id
        return (adds, [erased], baseTime + 102)
    }

    public static func dayFrom10Page() -> InkPage {
        // Read back the way a device reads the file, then edit (InkPage of 1.1 = InkPage of 1.0 here).
        var page = InkPage(json: (try? JSONValue.parse(encode(dayPage11()))) ?? .null)
        let edit = dayFrom10Edit()
        for spec in edit.adds {
            page.add(InkStroke(id: spec.id, cell: CellKey(raw: spec.cell), tool: InkTool(rawValue: spec.tool)!, color: spec.color,
                               t: spec.t, dev: spec.dev, points: InkPoint.points(fromFlat: spec.pts)))
        }
        page.remove(ids: edit.removes, at: edit.at)
        return page
    }

    // MARK: - d-2026-11-04.moved (a grid stroke moved below 24:00 with the lasso)

    public static let movedDayKey = DayKey(year: 2026, month: 11, day: 4)

    /// The page before the move: three grid strokes (y 900, 1,500, 2,200).
    public static func dayBeforeMove() -> InkPage {
        let layout = dayLayout(movedDayKey)
        var w = Writer(pageId: layout.pageId, seed: 0xD202_6110_4001)
        for (i, y) in [900, 1500, 2200].enumerated() {
            w.stroke(line(x: 150 + CGFloat(i) * 60, y: CGFloat(y)), size: 3.5, in: layout, expect: .grid)
        }
        return w.page
    }

    /// The move: the stroke at 22 o'clock goes 600 lu down (below 24:00), as `InkLedger.moveStrokes`
    /// does it: a copy with a new id in the cell under the moved centre, the original tombstoned.
    public static func dayMove() -> (originalId: String, delta: CGVector, newId: String, at: Int) {
        let before = dayBeforeMove()
        let original = before.liveStrokes.max { $0.t < $1.t }!
        var ids = SeededIds(seed: 0xD202_6110_4002)
        return (original.id, CGVector(dx: 0, dy: 600), ids.next(), baseTime + 10)
    }

    public static func dayMovedPage() -> InkPage {
        var page = dayBeforeMove()
        let move = dayMove()
        let layout = dayLayout(movedDayKey, ink: page.inkBottoms())
        let s = page.strokes[move.originalId]!
        let origin = layout.cells[s.cell]?.origin ?? .zero
        let bounds = s.paperBounds(cellOrigin: origin) ?? CGRect(origin: origin, size: .zero)
        let moved = bounds.offsetBy(dx: move.delta.dx, dy: move.delta.dy)
        let newCell = layout.inkCell(forCenter: CGPoint(x: moved.midX, y: moved.midY))
        precondition(newCell == .extra, "the moved stroke lands in \(newCell.raw)")
        let newOrigin = layout.cells[newCell]?.origin ?? .zero
        let clone = s.translated(by: move.delta, from: origin, to: newCell, newCellOrigin: newOrigin, id: move.newId, at: move.at)
        page.remove(ids: [s.id], at: move.at)
        page.add(clone)
        return page
    }

    // MARK: - m1-2026-11 (memo bottoms 380 / 790 / 3,190 / 5,590 / 5,990, four day strokes)

    public static func monthPage11() -> InkPage {
        let layout = monthLayout(2026, 11)
        var w = Writer(pageId: layout.pageId, seed: 0x3120_2611_0001)
        // Day cells: the first Monday of the grid (October 26, outside the month), two days of
        // November and the last cell (December 6). Small strokes: the rows keep their height.
        let days = [DayKey(year: 2026, month: 10, day: 26), DayKey(year: 2026, month: 11, day: 3),
                    DayKey(year: 2026, month: 11, day: 18), DayKey(year: 2026, month: 12, day: 6)]
        for day in days {
            let rect = layout.cells[.day(day)]!
            w.stroke(line(x: rect.minX + 30, y: rect.minY + 80, count: 5), size: 3.5, in: layout, expect: .day(day))
        }
        // Memo: bottoms (point y + nib / 2) at 380, 790, 3,190, 5,590 and 5,990, cell-relative.
        let memoTop = layout.memo.minY
        for (i, bottom) in [380, 790, 3190, 5590, 5990].enumerated() {
            w.stroke(line(x: 80 + CGFloat(i) * 150, y: memoTop + CGFloat(bottom) - 2), size: 4,
                     color: i % 2 == 0 ? "#1f2937" : "#16a34a", in: layout, expect: .memo)
        }
        return w.page
    }

    // MARK: - m1-2026-12.from10 (the web import of 1.0: a memo stroke down to 6,420)

    public static func monthFrom10Page() -> InkPage {
        var ids = SeededIds(seed: 0x3120_2612_0010)
        var n = 0
        func t() -> Int { n += 1; return baseTime + n }
        func pts(_ x: Double, _ y: Double, _ count: Int) -> [WebImport.Point] {
            (0..<count).map { WebImport.Point(x: x + Double($0) * 10, y: y, p: 0.5) }
        }
        // Web paper: the memo starts at 1,050. The highlighter's nib is its size (18), so a stroke
        // at web y 7,461 ends at 6,411 + 9 = 6,420 below the memo's top; a pen stroke near the top of
        // the memo; one stroke on December 8 (row 1, column 1).
        let strokes = [
            WebImport.Stroke(id: ids.next(), tool: .highlighter, color: "#fde047", size: 18, points: pts(100, 7461, 6), t: t()),
            WebImport.Stroke(id: ids.next(), tool: .pen, color: "#1f2937", size: 3.5, points: pts(400, 1350, 5), t: t()),
            WebImport.Stroke(id: ids.next(), tool: .pen, color: "#dc2626", size: 3.5, points: pts(230, 260, 4), t: t()),
        ].sorted { $0.id < $1.id }
        let page = WebImport.Page(pageId: "m1-2026-12", strokes: strokes, deleted: [:], updatedAt: 0)
        return WebImport.convert(page: page)!
    }

    // MARK: - w-2026-11-02.legacy (a stroke of the old week band, "allday:2026-11-04", x0 10)

    public static func weekLegacyPage() -> InkPage {
        var ids = SeededIds(seed: 0x7202_6110_2001)
        let points = line(x: 10, y: 14, count: 5).enumerated().map { i, p in
            InkPoint(x: p.x, y: p.y, dtMs: 8 * i, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0.785, altitude: 1.2)
        }
        var page = InkPage(pageId: "w-2026-11-02")
        page.add(InkStroke(id: ids.next(), cell: .allDay(DayKey(year: 2026, month: 11, day: 4)), tool: .pen, color: "#1f2937",
                           t: baseTime + 1, dev: device11, points: points))
        return page
    }

    // MARK: - export-1.1 (tegaki-app-export v1: d, m1, w)

    static func exportData(pages: [InkPage]) -> Data {
        AppExport.encode(AppExport.Document(exportedAt: "2026-11-02T21:00:00+09:00", app: "ios/1.1 (1)",
                                            pages: pages.sorted { $0.pageId < $1.pageId }))
    }

    // MARK: - The large year pages

    /// `count` strokes of 2 points spread over the 372 cells of 2026 (small, the rows do not grow);
    /// every `unknownEvery`-th one (from the first) is of the unknown tool "tape".
    static func yearPage(strokes count: Int, unknownEvery: Int?, seed: UInt64) -> InkPage {
        let layout = yearLayout(2026)
        var ids = SeededIds(seed: seed)
        var page = InkPage(pageId: layout.pageId)
        var keys: [CellKey] = []
        for month in 1...12 {
            for day in 1...31 { keys.append(.yearDay(month: month, day: day)) }
        }
        for i in 0..<count {
            let key = keys[i % keys.count]
            let k = i / keys.count
            let origin = layout.cells[key]!.origin
            let x = 6 + CGFloat(k % 10) * 10
            let y = 18 + CGFloat((k / 10) % 6) * 4
            let center = CGPoint(x: origin.x + x + 2, y: origin.y + y + 0.5)
            precondition(layout.inkCell(forCenter: center) == key, "year stroke \(i) lands outside \(key.raw)")
            let id = ids.next()
            let t = baseTime + 1 + i
            if let every = unknownEvery, i % every == 0 {
                let pts: [Double] = [Double(x), Double(y), 0, 2, 2, 1, 0.5, 0, 1.571, Double(x) + 4, Double(y) + 1, 8, 2, 2, 1, 0.5, 0, 1.571]
                page.unknownStrokes[id] = .object([
                    "id": .string(id), "cell": .string(key.raw), "tool": .string("tape"), "color": .string("#f59e0b"),
                    "t": .number(Double(t)), "dev": .string(device11), "pts": .array(pts.map { .number($0) }),
                ])
                page.updatedAt = max(page.updatedAt, t)
            } else {
                let points = [
                    InkPoint(x: x, y: y, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571),
                    InkPoint(x: x + 4, y: y + 1, dtMs: 8, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571),
                ]
                page.add(InkStroke(id: id, cell: key, tool: .pen, color: "#1f2937", t: t, dev: device11, points: points))
            }
        }
        return page
    }

    /// `count` tombstones and no stroke.
    static func tombstonePage(count: Int, seed: UInt64) -> InkPage {
        var ids = SeededIds(seed: seed)
        var deleted: [String: Int] = [:]
        deleted.reserveCapacity(count)
        for i in 0..<count { deleted[ids.next()] = baseTime + 1 + i }
        return InkPage(pageId: "y-2026", deleted: deleted, updatedAt: baseTime + count)
    }
}
