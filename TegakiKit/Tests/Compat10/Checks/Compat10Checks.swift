import Foundation
import CoreGraphics

/// The compatibility checks of K-7 (M7A_CONTRACT §1.4): the golden fixtures of 1.1
/// (TegakiKit/Tests/Fixtures/compat11) read, drawn, erased, merged and written back by the 1.0 rules.
///
/// Only the public API of the V10 names is called (`InkPageV10`, `AppExportV10.parse(json:)`,
/// `WebImportV10.ParseError`, …) together with `LedgerV10`, `cellsV10(pageId:)` and
/// `memoHeightV10(_:)`, so the same file runs in three places: against the frozen copy (KitChecks,
/// Compat10Tests and tools/compat10's RunFrozen) and against the real 1.0 InkModel through the
/// aliases of tools/compat10's RunReal. Both runs must report the same number of checks and no
/// failure.
///
/// Every `*.json` of the folder but `digests.json` is checked (the fixtures of P and U too, with the
/// rules that hold for every 1.1 page); K's own fixtures also get the expectations of the contract's
/// table. A large fixture listed in `digests.json` that is missing or whose sha256 differs counts as a
/// failure (it is never skipped), and so does a missing fixture of K.
public enum Compat10Checks {
    // MARK: - K's fixtures (M7A_CONTRACT §1.4)

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
    /// K's fixtures that are committed.
    public static let smallFixtures = [dayPage, dayFrom10, dayMoved, monthPage, monthFrom10, weekLegacy, export11]
    /// K's fixtures that are made again on every run; only their sha256 is committed (`digests.json`).
    public static let largeFixtures = [n15000, n20500, tomb200500]

    /// The keys of a stroke object that 1.0 reads (`InkStroke.jsonValue`, K-5).
    public static let strokeKeys: Set<String> = ["id", "cell", "tool", "color", "t", "dev", "pts"]

    /// Runs every check on the fixtures in `fixtures`. `report` is called once per check with its
    /// name and result.
    public static func run(fixtures: URL, report: (String, Bool) -> Void) -> (passed: Int, failed: Int) {
        withoutActuallyEscaping(report) { report in
            let r = Recorder(report: report)
            runAll(r, folder: fixtures)
            return (r.passed, r.failed)
        }
    }

    final class Recorder {
        let report: (String, Bool) -> Void
        var passed = 0
        var failed = 0

        init(report: @escaping (String, Bool) -> Void) {
            self.report = report
        }

        func check(_ ok: Bool, _ name: String) {
            report(name, ok)
            if ok { passed += 1 } else { failed += 1 }
        }
    }

    struct Fixture {
        let name: String
        let data: Data
        let json: JSONValueV10
        /// `InkPageV10(json:)` of a page fixture (read once), nil for an export.
        let page: InkPageV10?
    }

    static func runAll(_ r: Recorder, folder: URL) {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".json") && $0 != digests }
            .sorted()
        r.check(!names.isEmpty, "fixtures: the folder has fixtures")

        // The large fixtures against digests.json.
        let digestData = try? Data(contentsOf: folder.appendingPathComponent(digests))
        let digestObject = digestData.flatMap { try? JSONValueV10.parse($0) }?.objectValue
        r.check(digestObject != nil, "digests.json: present and a JSON object")
        let listed = digestObject ?? [:]
        for large in largeFixtures {
            r.check(listed[large]?.stringValue != nil, "digests.json: lists \(large)")
        }
        for (name, value) in listed.sorted(by: { $0.key < $1.key }) {
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else {
                r.check(false, "\(name): present (listed in digests.json)")
                continue
            }
            r.check(SHA256V10Digest.hex(data) == value.stringValue, "\(name): sha256 is the one in digests.json")
        }

        // Every fixture.
        var fixtures: [String: Fixture] = [:]
        for name in names {
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
                  let json = try? JSONValueV10.parse(data) else {
                r.check(false, "\(name): readable JSON")
                continue
            }
            if json["format"]?.stringValue == AppExportV10.format {
                fixtures[name] = Fixture(name: name, data: data, json: json, page: nil)
                exportChecks(r, fixture: fixtures[name]!)
            } else {
                let page = InkPageV10(json: json)
                fixtures[name] = Fixture(name: name, data: data, json: json, page: page)
                pageChecks(r, name: name, json: json, page: page, file: data, large: largeFixtures.contains(name))
            }
        }
        for name in smallFixtures + largeFixtures where fixtures[name] == nil {
            r.check(false, "\(name): present (a fixture of K)")
        }

        dayChecks(r, fixtures)
        monthChecks(r, fixtures)
        weekChecks(r, fixtures)
        largeChecks(r, fixtures)
        exportExpectations(r, fixtures)
    }

    // MARK: - Every page (the rules that hold for every 1.1 page)

    /// The stroke objects of a page as written (object form: by key; array form: by each `id`).
    static func rawStrokes(_ json: JSONValueV10) -> [String: JSONValueV10] {
        if let object = json["strokes"]?.objectValue { return object }
        var out: [String: JSONValueV10] = [:]
        for raw in json["strokes"]?.arrayValue ?? [] {
            if let id = raw["id"]?.stringValue { out[id] = raw }
        }
        return out
    }

    /// Does the 1.0 layout of the page have this cell? Written independently of `cellsV10` (and of the
    /// real 1.0 engines that RunReal uses for it): the day and week pages know `grid`, the month page
    /// the 42 days from the Monday on or before the 1st and `memo`, the year page every "MM-DD".
    static func knownTo10(_ cell: CellKeyV10, pageId: String) -> Bool {
        if pageId.hasPrefix("d-") || pageId.hasPrefix("w-") { return cell.isGrid }
        if pageId.hasPrefix("m1-") {
            if cell.isMemo { return true }
            let parts = pageId.dropFirst(3).split(separator: "-")
            guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), let day = cell.day else { return false }
            let first = DayKeyV10(year: y, month: m, day: 1)
            let n = day.dayNumber - first.dayNumber + (first.weekday + 6) % 7
            return n >= 0 && n < 42
        }
        if pageId.hasPrefix("y-") { return cell.yearMonthDay != nil }
        return false
    }

    /// A cell 1.0 writes into on the page (a new 1.0 stroke goes there in the edit checks).
    static func editCell(pageId: String) -> CellKeyV10? {
        if pageId.hasPrefix("d-") || pageId.hasPrefix("w-") { return .grid }
        if pageId.hasPrefix("m1-") { return .memo }
        if pageId.hasPrefix("y-") { return .yearDay(month: 1, day: 1) }
        return nil
    }

    static func stroke10(id: String, cell: CellKeyV10, t: Int, x: CGFloat, y: CGFloat) -> InkStrokeV10 {
        let points = (0..<4).map { i in
            InkPointV10(x: x + CGFloat(i) * 6, y: y + CGFloat(i % 2), dtMs: i * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)
        }
        return InkStrokeV10(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, dev: "fixture-1.0", points: points)
    }

    static func strokesJSON(_ page: InkPageV10) -> [String: JSONValueV10] {
        page.jsonValue["strokes"]?.objectValue ?? [:]
    }

    /// `large`: one of K's large fixtures. The checks that copy or merge the whole page once more
    /// (erase, the same page again, an edit) are left to the small pages there; the large pages have
    /// their own checks in `largeChecks`.
    static func pageChecks(_ r: Recorder, name: String, json: JSONValueV10, page: InkPageV10, file: Data?, large: Bool) {
        let pageId = json["pageId"]?.stringValue ?? ""
        r.check(json.objectValue != nil && !pageId.isEmpty, "\(name): an ink page with a pageId")
        let object = json.objectValue ?? [:]
        let raw = rawStrokes(json)
        let rawTombstones = json["deleted"]?.objectValue?.count ?? 0
        let legacy = name.contains(".legacy.")

        // K-5: no new item on the page or in a stroke of a known tool (v stays 1).
        r.check(Set(object.keys).isSubset(of: InkPageV10.knownKeys) && json["v"]?.doubleValue == 1,
                "\(name): K-5 only the items 1.0 knows on the page, v 1")
        let knownTool = raw.values.filter { ["pen", "marker"].contains(InkStrokeV10.toolName(of: $0) ?? "") }
        r.check(knownTool.allSatisfy { Set(($0.objectValue ?? [:]).keys).isSubset(of: strokeKeys) },
                "\(name): K-5 only the items 1.0 knows in every stroke")
        // K-1: no cell starts with "allday" (only the legacy fixture has one, on purpose).
        if !legacy {
            let cells = raw.values.compactMap { $0["cell"]?.stringValue }
            r.check(!cells.contains { $0.hasPrefix("allday") || BandMigrationV10.isBandCell(CellKeyV10(raw: $0)) },
                    "\(name): K-1 no cell starts with allday")
        }

        // Reading and writing back.
        // (Above 200,000 tombstones the kept set depends on the dictionary order, F8: not compared.)
        if let file = file, !large, rawTombstones <= InkPageV10.maxTombstones {
            r.check((try? InkPageCodecV10.decode(file)) == page, "\(name): 1.0 reads the file (InkPageCodec.decode)")
        }
        let fits = raw.count <= InkPageV10.maxStrokes && rawTombstones <= InkPageV10.maxTombstones
        if fits {
            r.check(page.strokes.count + page.unknownStrokes.count == raw.count && page.deleted.count == rawTombstones,
                    "\(name): 1.0 keeps every stroke and every tombstone")
            r.check((try? InkPageCodecV10.encode(page)) == json.serializedData(),
                    "\(name): 1.0 writes it back unchanged (every stroke byte for byte)")
        }

        // Opening the page on 1.0.
        if legacy {
            r.check(BandMigrationV10.needsMigration(page) && LedgerV10.displayWouldSave(loaded: page),
                    "\(name): the old band strokes move on 1.0 and the page is saved")
        } else {
            r.check(!BandMigrationV10.needsMigration(page) && BandMigrationV10.migrate(page) == page,
                    "\(name): 1.0's band migration leaves it alone")
            r.check(!LedgerV10.displayWouldSave(loaded: page), "\(name): showing it on 1.0 does not save or send it")
        }
        let shown = legacy ? BandMigrationV10.migrate(page) : page
        let cells = cellsV10(pageId: shown.pageId)
        let drawn = LedgerV10.drawnIds(page: shown, cells: cells)
        let ownCells = shown.liveStrokes.filter { knownTo10($0.cell, pageId: shown.pageId) }.map(\.id)
        r.check(drawn.count == ownCells.count && Set(drawn) == Set(ownCells),
                "\(name): 1.0 draws the strokes of its own cells (grid, the month's days and memo, the year's cells) and no other")
        r.check(Set(LedgerV10.lassoCandidates(page: shown, cells: cells)) == Set(drawn)
                && Set(LedgerV10.dotCandidates(page: shown, cells: cells)) == Set(drawn),
                "\(name): the lasso and the finger's dots of 1.0 reach only the drawn strokes")
        guard !large else { return }

        // Erasing everything 1.0 shows.
        let drawnSet = Set(drawn)
        var erased = shown
        erased.remove(ids: drawn, at: 1_790_000_900_000)
        let before = strokesJSON(shown)
        let after = strokesJSON(erased)
        let others = before.keys.filter { !drawnSet.contains($0) }
        r.check(Set(after.keys) == Set(others) && others.allSatisfy { after[$0] == before[$0] }
                && Set(erased.deleted.keys) == Set(shown.deleted.keys).union(drawnSet),
                "\(name): erasing everything 1.0 draws leaves every other stroke as it was")
        if fits && !legacy {
            r.check(others.allSatisfy { after[$0]?.serialized() == raw[$0]?.serialized() },
                    "\(name): …and those strokes are byte for byte the ones of the file")
        }

        // The same page again from iCloud.
        let again = LedgerV10.mergeRemoteOutcome(local: shown, remote: shown)
        r.check(again.merged == shown && !again.writesFile && !again.marksDirty,
                "\(name): fetching the same page on 1.0 writes nothing and queues nothing")
        r.check(LedgerV10.applyRemoteWouldSave(page: shown, updated: shown) == nil,
                "\(name): the 1.0 screen ignores the same page from iCloud")

        // A stroke written on 1.0 into one of its own cells.
        if let cell = editCell(pageId: shown.pageId) {
            var edited = shown
            edited.add(stroke10(id: "compat10-edit-" + shown.pageId, cell: cell, t: 1_790_000_800_000, x: 30, y: 40))
            let editedJSON = strokesJSON(edited)
            r.check(editedJSON.count == before.count + 1 && before.allSatisfy { editedJSON[$0.key] == $0.value },
                    "\(name): a stroke added on 1.0 keeps every other stroke as it was")
            // The 1.1 device receives the edit: what the 1.0 merge makes of it is the edited page.
            let received = LedgerV10.mergeRemoteOutcome(local: shown, remote: edited)
            r.check(received.merged == edited && received.writesFile && !received.marksDirty,
                    "\(name): merging the 1.0 edit back gives the edited page")
        }
    }

    // MARK: - The day pages (extra below 24:00, K-2, K-8)

    static func page(_ fixtures: [String: Fixture], _ name: String) -> InkPageV10? {
        fixtures[name]?.page
    }

    static func cells(of page: InkPageV10, _ name: String) -> [String: Int] {
        var out: [String: Int] = [:]
        for s in page.strokes.values { out[s.cell.raw, default: 0] += 1 }
        for (_, raw) in page.unknownStrokes { out["unknown:" + (raw["cell"]?.stringValue ?? ""), default: 0] += 1 }
        return out
    }

    static func dayChecks(_ r: Recorder, _ fixtures: [String: Fixture]) {
        let extra = CellKeyV10(raw: "extra")
        if let day = page(fixtures, dayPage) {
            r.check(cells(of: day, dayPage) == ["grid": 6, "extra": 8, "unknown:extra": 1] && day.deleted.count == 3,
                    "\(dayPage): grid 6, extra 8, one unknown tool in extra, 3 tombstones")
            r.check(day.unknownStrokes.values.allSatisfy { InkStrokeV10.toolName(of: $0) == "tape" },
                    "\(dayPage): the unknown tool is \"tape\"")
            let drawn = LedgerV10.drawnIds(page: day, cells: cellsV10(pageId: day.pageId))
            r.check(drawn.count == 6 && drawn.allSatisfy { day.strokes[$0]?.cell == .grid },
                    "\(dayPage): 1.0 draws, erases and lassos the 6 grid strokes only")
            let extraBottom = day.inkBottoms()[extra] ?? 0
            r.check(extraBottom == 5955, "\(dayPage): the extra handwriting ends at 5,955 (1.1 gives the cell 6,005)")
            let ys = day.strokes.values.filter { $0.cell == extra }.flatMap { $0.points.map(\.y) }
            r.check(ys.min() == 30 && ys.max() == 5950, "\(dayPage): extra strokes from y 30 to 5,950 (cell-relative)")
            let gridYs = day.strokes.values.filter { $0.cell == .grid }.flatMap { $0.points.map(\.y) }
            r.check(gridYs.min() == 700 && gridYs.max() == 2350, "\(dayPage): grid strokes from y 700 to 2,350")

            if let from10 = page(fixtures, dayFrom10) {
                r.check(cells(of: from10, dayFrom10) == ["grid": 7, "extra": 8, "unknown:extra": 1] && from10.deleted.count == 4,
                        "\(dayFrom10): 1.0 added 2 grid strokes and erased 1: grid 7, extra 8, unknown 1, 4 tombstones")
                let a = InkPageV10.merge(day, from10)
                let b = InkPageV10.merge(from10, day)
                r.check(a == b && (try? InkPageCodecV10.encode(a)) == (try? InkPageCodecV10.encode(b)),
                        "\(dayFrom10): merging in either order gives the same bytes")
                r.check(cells(of: a, "merged") == ["grid": 7, "extra": 8, "unknown:extra": 1],
                        "\(dayFrom10): the merge has grid 7, extra 8 and the unknown stroke")
                let baseJSON = strokesJSON(day)
                let fromJSON = strokesJSON(from10)
                let mergedJSON = strokesJSON(a)
                let extraIds = day.strokes.values.filter { $0.cell == extra }.map(\.id) + Array(day.unknownStrokes.keys)
                r.check(extraIds.allSatisfy { fromJSON[$0] != nil && fromJSON[$0] == baseJSON[$0] && mergedJSON[$0] == baseJSON[$0] },
                        "\(dayFrom10): 1.0's edit leaves every extra stroke byte for byte")
                r.check(Set(day.strokes.keys).intersection(from10.strokes.keys).allSatisfy { day.strokes[$0]?.cell == from10.strokes[$0]?.cell },
                        "\(dayFrom10): K-2 no stroke changed its cell under the same id")
                let tombstonedNow = Set(from10.deleted.keys).subtracting(day.deleted.keys)
                r.check(tombstonedNow.count == 1 && tombstonedNow.allSatisfy { day.strokes[$0]?.cell == .grid },
                        "\(dayFrom10): the one stroke 1.0 erased was a grid stroke")
            }
        }
        if let moved = page(fixtures, dayMoved) {
            let drawn = LedgerV10.drawnIds(page: moved, cells: cellsV10(pageId: moved.pageId))
            let movedStrokes = moved.strokes.values.filter { $0.cell == extra }
            r.check(cells(of: moved, dayMoved) == ["grid": 2, "extra": 1] && moved.deleted.count == 1,
                    "\(dayMoved): grid 2, the moved copy in extra, the original tombstoned")
            r.check(drawn.count == 2 && drawn.allSatisfy { moved.strokes[$0]?.cell == .grid },
                    "\(dayMoved): 1.0 draws only the 2 grid strokes; the moved stroke is nowhere on 1.0 (K-8)")
            r.check(movedStrokes.allSatisfy { moved.deleted[$0.id] == nil } && moved.deleted.keys.allSatisfy { moved.strokes[$0] == nil },
                    "\(dayMoved): the copy has a new id and the original id is only a tombstone")
        }
    }

    // MARK: - The month pages (the memo area grows; no limit on 1.0)

    static func memoBottoms(_ page: InkPageV10) -> [CGFloat] {
        page.strokes.values.filter { $0.cell.isMemo }.map(\.bottom).sorted()
    }

    static func monthChecks(_ r: Recorder, _ fixtures: [String: Fixture]) {
        if let month = page(fixtures, monthPage) {
            let bottoms = memoBottoms(month)
            r.check(bottoms == [380, 790, 3190, 5590, 5990], "\(monthPage): memo strokes end at 380, 790, 3,190, 5,590 and 5,990")
            let dayStrokes = month.strokes.values.filter { $0.cell.day != nil }
            r.check(dayStrokes.count == 4, "\(monthPage): 4 strokes in day cells")
            let height = memoHeightV10(month.inkBottoms()[.memo] ?? 0)
            r.check(height == 6040, "\(monthPage): the 1.0 memo area is 6,040")
            r.check(month.strokes.values.filter { $0.cell.isMemo }.allSatisfy { !LedgerV10.needsMoreRoom($0, cellHeight: height, growsWithInk: true) && $0.bottom <= height },
                    "\(monthPage): every memo stroke fits the 1.0 memo area (drawn, no relayout)")
            let drawn = LedgerV10.drawnIds(page: month, cells: cellsV10(pageId: month.pageId))
            r.check(drawn.count == 9, "\(monthPage): 1.0 draws all 9 strokes")
        }
        if let from10 = page(fixtures, monthFrom10) {
            r.check(memoBottoms(from10).last == 6420, "\(monthFrom10): the deepest memo stroke (web import form) ends at 6,420")
            r.check(memoHeightV10(from10.inkBottoms()[.memo] ?? 0) == 6470, "\(monthFrom10): the 1.0 memo area is 6,470")
            r.check(from10.strokes.values.allSatisfy { $0.dev == "web" && $0.points.enumerated().allSatisfy { $0.element.dtMs == 8 * $0.offset } },
                    "\(monthFrom10): the strokes are what the web import writes (dev web, 8 ms per point)")
            let drawn = LedgerV10.drawnIds(page: from10, cells: cellsV10(pageId: from10.pageId))
            r.check(drawn.count == from10.liveStrokeCount && drawn.count >= 2, "\(monthFrom10): 1.0 draws every stroke")
        }
    }

    // MARK: - The week page's old band (BandMigration, F3)

    static func weekChecks(_ r: Recorder, _ fixtures: [String: Fixture]) {
        guard let legacy = page(fixtures, weekLegacy) else { return }
        let original = legacy.strokes.values.first
        r.check(legacy.strokes.count == 1 && original?.cell.raw == "allday:2026-11-04" && original?.points.first?.x == 10,
                "\(weekLegacy): one stroke in allday:2026-11-04 at x0 10")
        let migrated = BandMigrationV10.migrate(legacy)
        let moved = original.flatMap { migrated.strokes[$0.id] }
        let x0 = InkPointV10(x: 10 + PaperSpecV10.weekGutter + 2 * PaperSpecV10.weekColumnWidth, y: 0, dtMs: 0, sizeW: 0, sizeH: 0, opacity: 0, force: 0, azimuth: 0, altitude: 0).x
        r.check(moved?.cell == .grid && moved?.points.first?.x == x0 && x0 == 455.7 && moved?.points.first?.y == original?.points.first?.y,
                "\(weekLegacy): 1.0 moves it onto grid, x0 455.7 (10 + 64 + 2 × 190.857), y and id kept")
        r.check(BandMigrationV10.migrate(migrated) == migrated, "\(weekLegacy): the migration is idempotent")
    }

    // MARK: - The large pages (the read caps of 1.0, F8, K-9)

    static func largeChecks(_ r: Recorder, _ fixtures: [String: Fixture]) {
        if let page = fixtures[n15000]?.page {
            r.check(page.strokes.count == 15_000 && page.unknownStrokes.isEmpty && page.deleted.isEmpty,
                    "\(n15000): 1.0 keeps all 15,000 strokes")
            r.check(Set(page.strokes.values.map(\.cell)).count == 372, "\(n15000): spread over the 372 cells")
        }
        if let fixture = fixtures[n20500], let page = fixture.page {
            let raw = rawStrokes(fixture.json)
            let rawUnknown = raw.filter { InkStrokeV10.toolName(of: $0.value) == "tape" }
            r.check(raw.count == 20_500 && rawUnknown.count == 200, "\(n20500): 20,300 strokes and 200 of an unknown tool")
            let kept = Set(page.strokes.keys).union(page.unknownStrokes.keys)
            let smallest = Set(raw.keys.sorted().prefix(20_000))
            r.check(kept.count == 20_000 && kept == smallest,
                    "\(n20500): 1.0 keeps 20,000 (unknown tools counted), the smallest ids in key order")
            r.check(Set(page.unknownStrokes.keys) == smallest.intersection(rawUnknown.keys),
                    "\(n20500): the unknown-tool strokes among them are kept as they were")
            let back = (try? InkPageCodecV10.encode(page)).flatMap { try? JSONValueV10.parse($0) }
            r.check(back.map { rawStrokes($0).count } == 20_000 && back?["deleted"]?.objectValue?.isEmpty == true,
                    "\(n20500): what 1.0 writes back has 20,000 strokes and no tombstone (F8)")
            r.check(back.map { b in rawStrokes(b).allSatisfy { raw[$0.key]?.serialized() == $0.value.serialized() } } == true,
                    "\(n20500): …each of them byte for byte")
        }
        if let fixture = fixtures[tomb200500], let page = fixture.page {
            let raw = fixture.json["deleted"]?.objectValue ?? [:]
            r.check(raw.count == 200_500, "\(tomb200500): 200,500 tombstones")
            r.check(page.deleted.count == 200_000 && Set(page.deleted.keys).isSubset(of: raw.keys) && page.strokes.isEmpty,
                    "\(tomb200500): 1.0 keeps 200,000 of them (a subset) and no stroke")
            r.check(page.deleted.allSatisfy { raw[$0.key]?.doubleValue == Double($0.value) },
                    "\(tomb200500): the kept tombstones keep their times")
        }
    }

    // MARK: - The app export (tegaki-app-export v1)

    static func exportChecks(_ r: Recorder, fixture: Fixture) {
        let name = fixture.name
        let document = try? AppExportV10.parse(json: fixture.json)
        r.check(document != nil, "\(name): 1.0 reads the export")
        guard let doc = document else { return }
        r.check(AppExportV10.encode(doc) == fixture.data, "\(name): 1.0 writes the same export back byte for byte")
        r.check(doc.pages.allSatisfy(AppExportV10.isWorthExporting), "\(name): every page is worth exporting on 1.0")
        let raws = fixture.json["pages"]?.arrayValue ?? []
        r.check(raws.count == doc.pages.count, "\(name): 1.0 keeps every page")
        for (index, raw) in raws.enumerated() {
            pageChecks(r, name: "\(name)#\(raw["pageId"]?.stringValue ?? String(index))", json: raw, page: InkPageV10(json: raw), file: nil, large: false)
        }
    }

    static func exportExpectations(_ r: Recorder, _ fixtures: [String: Fixture]) {
        guard let fixture = fixtures[export11], let doc = try? AppExportV10.parse(json: fixture.json) else { return }
        r.check(doc.pages.map(\.pageId) == ["d-2026-11-02", "m1-2026-11", "w-2026-11-02"] && doc.app == "ios/1.1 (1)",
                "\(export11): d, m1 and w, written by ios/1.1 (1)")
        let expected: [InkPageV10?] = [
            fixtures[dayPage].flatMap { AppExportV10.parsePage($0.json) },
            fixtures[monthPage].flatMap { AppExportV10.parsePage($0.json) },
            fixtures[weekLegacy].flatMap { AppExportV10.parsePage($0.json) },
        ]
        r.check(doc.pages.count == 3 && zip(doc.pages, expected).allSatisfy { $0.0 == $0.1 },
                "\(export11): each page equals its fixture as 1.0 reads it (the week page migrated)")
        do {
            _ = try AppExportV10.parse(json: .object(["format": .string("tegaki-app-export"), "v": .number(2)]))
            r.check(false, "\(export11): 1.0 refuses a version 2 export (unsupportedVersion(2))")
        } catch let error as WebImportV10.ParseError {
            r.check(error == .unsupportedVersion(2), "\(export11): 1.0 refuses a version 2 export (unsupportedVersion(2))")
        } catch {
            r.check(false, "\(export11): 1.0 refuses a version 2 export (unsupportedVersion(2))")
        }
    }
}

/// SHA-256 (FIPS 180-4) in plain Swift, so the copy needs nothing but Foundation. Used for the large
/// fixtures of digests.json. Written with raw pointers and no helper calls in the rounds, so that it
/// stays fast enough in a debug build.
enum SHA256V10Digest {
    static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    static func hex(_ data: Data) -> String {
        // The message with its padding: 0x80, zeros, the bit length (big endian), a multiple of 64.
        var message = [UInt8](data)
        let bitLength = UInt64(data.count) &* 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for i in (0..<8).reversed() { message.append(UInt8(truncatingIfNeeded: bitLength >> (UInt64(i) * 8))) }

        let h = UnsafeMutablePointer<UInt32>.allocate(capacity: 8)
        let w = UnsafeMutablePointer<UInt32>.allocate(capacity: 64)
        defer { h.deallocate(); w.deallocate() }
        h[0] = 0x6a09e667; h[1] = 0xbb67ae85; h[2] = 0x3c6ef372; h[3] = 0xa54ff53a
        h[4] = 0x510e527f; h[5] = 0x9b05688c; h[6] = 0x1f83d9ab; h[7] = 0x5be0cd19
        k.withUnsafeBufferPointer { kb in
            let kp = kb.baseAddress!
            message.withUnsafeBufferPointer { mb in
                let bytes = mb.baseAddress!
                var chunk = 0
                let total = mb.count
                while chunk < total {
                    var i = 0
                    while i < 16 {
                        let j = bytes + chunk + i * 4
                        w[i] = UInt32(j[0]) << 24 | UInt32(j[1]) << 16 | UInt32(j[2]) << 8 | UInt32(j[3])
                        i += 1
                    }
                    while i < 64 {
                        let x = w[i - 15]
                        let y = w[i - 2]
                        let s0 = (x >> 7 | x << 25) ^ (x >> 18 | x << 14) ^ (x >> 3)
                        let s1 = (y >> 17 | y << 15) ^ (y >> 19 | y << 13) ^ (y >> 10)
                        w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
                        i += 1
                    }
                    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7]
                    i = 0
                    while i < 64 {
                        let s1 = (e >> 6 | e << 26) ^ (e >> 11 | e << 21) ^ (e >> 25 | e << 7)
                        let ch = (e & f) ^ (~e & g)
                        let t1 = hh &+ s1 &+ ch &+ kp[i] &+ w[i]
                        let s0 = (a >> 2 | a << 30) ^ (a >> 13 | a << 19) ^ (a >> 22 | a << 10)
                        let maj = (a & b) ^ (a & c) ^ (b & c)
                        hh = g; g = f; f = e; e = d &+ t1; d = c; c = b; b = a; a = t1 &+ s0 &+ maj
                        i += 1
                    }
                    h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
                    h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
                    chunk += 64
                }
            }
        }
        return (0..<8).map { String(format: "%08x", h[$0]) }.joined()
    }
}
