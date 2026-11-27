// KitChecks: the compat-span-143 fixtures of 1.4.3 (docs/R1_4_3_CONTRACT.md §8.3, 0g-30, K-7; role C), section
// "compat-span-143 (1.4.3)": the month and the year joined sideways, in TegakiKit/Tests/Fixtures/compat-span-143. The shape
// of SpanInkChecks.swift's `spanCompatFixtureChecks` (1.3's compat-span, frozen in TESTS_1_3, so this is a file of its
// own): MANIFEST and every file byte for byte what the Kit's joined path writes (`CompatSpan143Fixtures`), each file as
// today's InkModel reads it, what each holds (cells and x ranges, written out from the committed files), what each fixture
// is for (8–13), the frozen 1.0 copy file by file, Compat10Checks on compat11 with the new files, the app export through 1.0
// and back. main.swift calls `runCompatSpan143Checks()` after `runWindowFingerChecks()` and
// `writeCompatSpan143Fixtures()` for `--write-compat-span-143-fixtures [--out <folder>]` before any check.
import Foundation
import CoreGraphics
import Layout
import InkModel
import Compat10
import CompatFixtures
import CompatSpanFixtures
import CompatSpan143Fixtures

// MARK: - --write-compat-span-143-fixtures [--out <folder>] (§8.3)

/// Writes the compat-span-143 fixtures and MANIFEST into TegakiKit/Tests/Fixtures/compat-span-143/ or <folder>, lists
/// each file as new, unchanged or changed, and exits without running the checks (as --write-compat-span-fixtures does
/// for compat-span).
func writeCompatSpan143Fixtures() -> Never {
    let arguments = CommandLine.arguments
    var folder = CompatSpan143Fixtures.committedFolder
    if let i = arguments.firstIndex(of: "--out") {
        guard i + 1 < arguments.count else {
            print("KitChecks: --out needs a folder")
            exit(2)
        }
        folder = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
    }
    do {
        let results = try CompatSpan143Fixtures.write(to: folder)
        for (name, result) in results {
            print("\(result.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))\(name)")
        }
        let changed = results.filter { $0.result == .changed }.count
        let new = results.filter { $0.result == .new }.count
        print("KitChecks: wrote the compat-span-143 fixtures to \(folder.path) (\(results.count) files: \(new) new, \(changed) changed)")
        exit(0)
    } catch {
        print("KitChecks: writing the compat-span-143 fixtures failed: \(error)")
        exit(1)
    }
}

// MARK: - The checks

func runCompatSpan143Checks() {
    section("compat-span-143 (1.4.3)")
    let before = passed + failures.count
    compatSpan143Checks()
    print("   \(passed + failures.count - before) checks in this section")
}

/// The paper bounds (± half the nib) of a stroke in a one-page layout, nil when the layout has no such cell.
private func paperBounds143(_ s: InkStroke, _ layout: any PageLayout) -> CGRect? {
    guard let cell = layout.cells[s.cell] else { return nil }
    return s.paperBounds(cellOrigin: cell.origin)
}

/// The page as a version without the floors lays it out (1.4.2 and every earlier one: no event, the page's own ink).
private func ownInkLayout143(_ page: InkPage, weekStart: WeekStart = .monday) -> (any PageLayout)? {
    guard let parsed = PageNavigation.parse(pageId: page.pageId) else { return nil }
    let now = CompatFixtures.now
    let tokyo = CompatFixtures.tokyo
    switch parsed.kind {
    case .month:
        return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: parsed.focus.year, month: parsed.focus.month), events: [],
                                                         inkBottoms: page.inkBottoms(), now: now, calendar: tokyo, weekStart: weekStart))
    case .year:
        return YearLayoutEngine.layout(YearLayoutInput(year: parsed.focus.year, events: [], inkBottoms: page.inkBottoms(), now: now, calendar: tokyo))
    case .day, .week:
        return nil
    }
}

private func compatSpan143Checks() {
    let fm = FileManager.default
    typealias F = CompatSpan143Fixtures
    let folder = F.committedFolder
    let made = F.made

    // MANIFEST and the files, byte for byte what the Kit's joined path writes.
    let manifest = try? Data(contentsOf: folder.appendingPathComponent(F.manifestName))
    checkEqual(manifest, F.manifestData(), "compat-span-143: MANIFEST is what the maker writes (KitChecks --write-compat-span-143-fixtures)")
    let listed = manifest.flatMap(F.parseManifest) ?? []
    checkEqual(listed, F.entries, "compat-span-143: MANIFEST lists every file with its fixture number and shape")
    checkEqual(Set(listed.map(\.fixture)), [8, 9, 10, 11, 12, 13], "compat-span-143: fixtures 8–13 (§8.3; compat-span has 1–7)")
    checkEqual(listed.filter { $0.shape == .sunday }.map(\.name), [F.monthMemoSunday], "compat-span-143: only the Sunday-start month (fixture 11) is of shape sunday")
    let onDisk = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
    checkEqual(onDisk, listed.map(\.name).sorted(), "compat-span-143: every *.json of the folder is in MANIFEST, and every listed file is there")
    let others = Set(((try? fm.contentsOfDirectory(atPath: folder.path)) ?? [])).subtracting(onDisk).subtracting([F.manifestName])
    check(others.isEmpty, "compat-span-143: the folder holds only MANIFEST and the fixtures (\(others.sorted()))")
    for (name, data) in made.files {
        check((try? Data(contentsOf: folder.appendingPathComponent(name))) == data, "compat-span-143: \(name) is what the joined path of the Kit writes")
    }
    check(made.recovered.isEmpty && made.deltaCount == 10, "compat-span-143: \(made.deltaCount) deltas made the files; the safety net had nothing to bring back")
    for e in listed {
        checkEqual(made.saves[e.name], .ok, "compat-span-143: \(e.name) was saved as it was (the guard found nothing)")
    }
    // CI copies the Monday files of both folders into one folder (compat11's copy): no name may be taken twice.
    let compatSpanNames = Set(CompatSpanFixtures.entries.map(\.name))
    let compat11Names = Set(CompatFixtures.smallNames + CompatFixtures.largeNames + [CompatFixtures.digests])
    check(listed.allSatisfy { !compatSpanNames.contains($0.name) && !compat11Names.contains($0.name) },
          "compat-span-143: no file has the name of a compat-span or a compat11 file (CI copies them into one folder)")

    // Each file as today's Kit reads it.
    var pages: [String: InkPage] = [:]
    var files: [String: Data] = [:]
    for e in listed {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(e.name)), let page = try? InkPageCodec.decode(data) else {
            check(false, "compat-span-143: \(e.name) reads")
            continue
        }
        pages[e.name] = page
        files[e.name] = data
        check((try? InkPageCodec.encode(page)) == data, "compat-span-143: \(e.name) is read and written back unchanged")
        check(SpanGuard.checkForSave(page) == .ok && SpanGuard.checkForTransfer(page), "compat-span-143: \(e.name) has no window name (saves and goes out as it is)")
        check(e.name.hasPrefix(page.pageId + ".") && page.v == 1 && page.unknown.isEmpty && page.unknownStrokes.isEmpty,
              "compat-span-143: \(e.name) holds \(page.pageId), v 1, no new top-level item (K-5) and no item of an unknown tool")
        check(page.strokes.values.allSatisfy { !$0.id.contains("|") && !$0.cell.raw.contains("|") && !$0.cell.raw.contains("~") && $0.dev == F.device }
              && !page.pageId.contains("|") && !page.pageId.contains("~"),
              "compat-span-143: \(e.name) every stroke is the session's (\(F.device)), no | in its id and cell, no ~ in its cell (K-10)")
        check(page.pageId.hasPrefix("m1-") || page.pageId.hasPrefix("y-"), "compat-span-143: \(e.name) is a month or a year page")
    }

    // What each file holds (cell, the stroke's x from … to, cell-relative), tombstones, unknown items.
    let expected: [(String, [(String, CGFloat, CGFloat)], Int)] = [
        (F.monthMemoLeft, [("memo", -160, 260)], 0),
        (F.monthMoveSource, [("2026-11-01", 30, 170)], 1),
        (F.monthMoveDestination, [("2026-11-01", 30, 170)], 0),
        (F.yearDecemberRight, [("12-10", -88, 232)], 0),
        (F.yearDateColumn, [("01-20", -128, 70)], 0),
        (F.monthMemoSunday, [("memo", 1100, 1600)], 0),
        (F.yearRowFloor, [("06-15", 30, 90)], 0),
        (F.monthLastRow, [("2026-12-03", 30, 170)], 0),
    ]
    checkEqual(expected.map(\.0).sorted(), listed.map(\.name).sorted(), "compat-span-143: every MANIFEST row has what it holds written out here")
    for (name, strokes, tombstones) in expected {
        guard let page = pages[name] else { continue }
        let got = page.liveStrokes.map { s in (s.cell.raw, s.points.map(\.x).min() ?? 0, s.points.map(\.x).max() ?? 0) }
            .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
        check(got.count == strokes.count && zip(got, strokes).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 && $0.2 == $1.2 } && page.deleted.count == tombstones,
              "compat-span-143: \(name) holds \(strokes.map { "\($0.0) x \($0.1)…\($0.2)" }.joined(separator: ", ")), \(tombstones) tombstone(s) (got \(got))")
        checkEqual(made.cells[name], page.liveStrokes.map { page.pageId + "|" + $0.cell.raw }.sorted(),
                   "compat-span-143: \(name) every stroke is in the cell the window filed it in (its owner's, by the centre's x)")
    }

    // 8 and 11: the month memo across a boundary, its owner the page of its centre's x (half-open, B_DESIGN §4.1).
    for (name, start, side) in [(F.monthMemoLeft, WeekStart.monday, "left"), (F.monthMemoSunday, .sunday, "right")] {
        guard let page = pages[name], let s = page.liveStrokes.first, let layout = ownInkLayout143(page, weekStart: start),
              let b = paperBounds143(s, layout) else {
            check(false, "compat-span-143: \(name) lays out with its memo")
            continue
        }
        checkEqual(layout.pageId, "m1-2026-11", "compat-span-143: \(name) opens as m1-2026-11 with the \(start) start (K-11: a month's id has no week start)")
        check(s.cell == .memo && b.midX >= 0 && b.midX < 1400 && (side == "left" ? b.minX < 0 : b.maxX > 1400),
              "compat-span-143: \(name) a memo line centred on its page, reaching out to the \(side) (\(b))")
    }
    if let page = pages[F.monthMemoSunday], let sunday = ownInkLayout143(page, weekStart: .sunday), let monday = ownInkLayout143(page, weekStart: .monday) {
        check(sunday.cells[.memo] == monday.cells[.memo] && sunday.cells[.memo]?.minY == 1050,
              "compat-span-143: fixture 11 the memo is the same rectangle under both week starts (6 rows of 42 days, memo at 1,050)")
        check(sunday.cells[.day(DayKey(year: 2026, month: 12, day: 12))] != nil && monday.cells[.day(DayKey(year: 2026, month: 12, day: 12))] == nil
              && monday.cells[.day(DayKey(year: 2026, month: 10, day: 26))] != nil && sunday.cells[.day(DayKey(year: 2026, month: 10, day: 26))] == nil,
              "compat-span-143: fixture 11 the two starts' grids differ (Sunday: 11/1 … 12/12, Monday: 10/26 … 12/6), the memo does not")
    }

    // 9: the move across the shared day (K-2): a copy with a new id on the destination, a tombstone on the source at the
    // move's time, the same cell name 2026-11-01 on both month pages, the copy's points those of the moved stroke.
    if let source = pages[F.monthMoveSource], let destination = pages[F.monthMoveDestination], let copy = destination.liveStrokes.first,
       let tombstone = source.deleted.first, let kept = source.liveStrokes.first {
        check(tombstone.key != copy.id && source.strokes[tombstone.key] == nil && tombstone.value == copy.t && destination.deleted.isEmpty
              && Set(source.strokes.keys).isDisjoint(with: destination.strokes.keys),
              "compat-span-143: fixture 9 left a tombstone on the source and a copy with a new id (written at the move's time) on the destination (K-2)")
        check(copy.cell.raw == "2026-11-01" && kept.cell.raw == "2026-11-01" && copy.points.map(\.x) == kept.points.map(\.x)
              && copy.points.map(\.y) == kept.points.map { $0.y - 60 },
              "compat-span-143: fixture 9 the copy is in m1-2026-11's 2026-11-01 at the moved stroke's place (60 lu above the stroke left behind)")
        let october = ownInkLayout143(source)
        let november = ownInkLayout143(destination)
        check(october?.cells[copy.cell]?.origin == CGPoint(x: 1200, y: 700) && november?.cells[copy.cell]?.origin == CGPoint(x: 1200, y: 0),
              "compat-span-143: fixture 9 2026-11-01 is row 5 of October's table and row 1 of November's (Monday start), two cells of the same name")
    } else {
        check(false, "compat-span-143: fixture 9 the source keeps a stroke and a tombstone, the destination has the copy")
    }

    // 10: the year's date column belongs to January of its year (x goes negative); December reaches past the right edge.
    if let page = pages[F.yearDateColumn], let s = page.liveStrokes.first, let layout = ownInkLayout143(page), let b = paperBounds143(s, layout) {
        check(b.midX >= 0 && b.midX < PaperSpec.yearGutter && s.cell == .yearDay(month: 1, day: 20) && layout.inkCell(forCenter: CGPoint(x: b.midX, y: b.midY)) == s.cell
              && s.points.map(\.x).min() == -128 && s.points.map(\.x).max() == 70,
              "compat-span-143: fixture 10 a line centred on y-2027's date column is its January's (01-20, x −128 … 70) (\(b))")
    } else {
        check(false, "compat-span-143: fixture 10 y-2027's date-column line lays out")
    }
    if let page = pages[F.yearDecemberRight], let s = page.liveStrokes.first, let layout = ownInkLayout143(page), let b = paperBounds143(s, layout) {
        check(b.maxX > 1400 && b.midX >= 1288 && b.midX < 1400 && s.cell == .yearDay(month: 12, day: 10) && layout.inkCell(forCenter: CGPoint(x: b.midX, y: b.midY)) == s.cell,
              "compat-span-143: fixture 10 a line from December to the right is y-2026's 12-10, past the page's right edge (\(b))")
    } else {
        check(false, "compat-span-143: fixture 10 y-2026's December line lays out")
    }

    // 12 and 13: written where the floors lengthened the row; a version without them lays the page out from its own ink,
    // the row grows to the ink's bottom + 12 and the line is inside its cell (K-4, B_DESIGN §3.1).
    for (name, cell, natural, depth) in [(F.yearRowFloor, F.yearRowCell, PaperSpec.yearRowBase, CGFloat(350)),
                                         (F.monthLastRow, F.monthRowCell, PaperSpec.monthRowBase, CGFloat(600))] {
        guard let page = pages[name], let s = page.liveStrokes.first, let layout = ownInkLayout143(page), let rect = layout.cells[cell],
              let b = paperBounds143(s, layout), let bottom = page.inkBottoms()[cell] else {
            check(false, "compat-span-143: \(name) lays out with its cell")
            continue
        }
        check(s.cell == cell && s.points.map(\.y).min() == depth && rect.height > natural,
              "compat-span-143: \(name) a line \(depth) lu below the top of \(cell.raw), deeper than the natural row (\(natural))")
        check(abs(rect.height - (bottom + PaperSpec.inkPad)) < 0.001 && b.minY >= rect.minY && b.maxY <= rect.maxY
              && !PaperGrowth.needsMoreRoom(cell: cell, cellHeight: rect.height, inkBottom: bottom),
              "compat-span-143: \(name) laid out from its own ink the row is the ink's bottom + 12 (\(rect.height)) and holds the line (\(b))")
    }
    if let page = pages[F.monthLastRow], let layout = ownInkLayout143(page), let row6 = layout.cells[F.monthRowCell] {
        check(row6.minY == 875 && layout.cells[.day(DayKey(year: 2026, month: 11, day: 30))]?.minY == 875,
              "compat-span-143: fixture 13 2026-12-03 is in row 6 (y 875, with 2026-11-30), the rows above it keep 175 lu")
    }
    if let page = pages[F.yearRowFloor], let layout = ownInkLayout143(page), let row = layout.cells[F.yearRowCell] {
        checkEqual(row.minY, 840, "compat-span-143: fixture 12 row 15 starts at 840 (rows 1–14 keep 60 lu)")
    }

    // The frozen 1.0 copy, file by file: what 1.0 reads, draws, lassoes and writes back (every file draws its one stroke).
    for e in listed {
        guard let data = files[e.name], let new = pages[e.name], let old = try? InkPageCodecV10.decode(data) else {
            check(false, "compat-span-143 1.0: \(e.name) reads on 1.0")
            continue
        }
        let newJSON = new.jsonValue["strokes"]?.objectValue ?? [:]
        let oldJSON = old.jsonValue["strokes"]?.objectValue ?? [:]
        check(old.strokes.count == new.strokes.count && old.unknownStrokes.isEmpty && old.deleted == new.deleted
              && Set(oldJSON.keys) == Set(newJSON.keys) && newJSON.allSatisfy { oldJSON[$0.key]?.serialized() == $0.value.serialized() },
              "compat-span-143 1.0: \(e.name) the strokes, cells, coordinates and tombstones are the same on 1.0")
        check(old.liveStrokes.allSatisfy { s in new.strokes[s.id].map { $0.cell.raw == s.cell.raw && $0.points.map(\.x) == s.points.map(\.x) && $0.points.map(\.y) == s.points.map(\.y) } == true },
              "compat-span-143 1.0: \(e.name) every stroke has the same cell and points on 1.0 (none cut, none moved)")
        checkEqual((try? InkPageCodecV10.encode(old)), data, "compat-span-143 1.0: \(e.name) 1.0 writes back the same bytes")
        let cells = cellsV10(pageId: old.pageId)
        let drawn = LedgerV10.drawnIds(page: old, cells: cells)
        checkEqual(drawn.count, 1, "compat-span-143 1.0: \(e.name) 1.0 draws its one live stroke (its cell is one of 1.0's), overhanging or not")
        check(Set(LedgerV10.lassoCandidates(page: old, cells: cells)) == Set(drawn), "compat-span-143 1.0: \(e.name) 1.0's lasso reaches the drawn strokes")
        check(BandMigrationV10.migrate(old) == old && InkPageV10.merge(old, old) == old && !LedgerV10.displayWouldSave(loaded: old),
              "compat-span-143 1.0: \(e.name) 1.0's band migration and merge leave it alone, opening it saves nothing")
    }

    // The whole folder through Compat10Checks, with compat11 (CI copies the Monday files there for the real 1.0; here the
    // Sunday month too: the copy lays any m1- page out with its Monday grid, and the memo is the same).
    let tmp = fm.temporaryDirectory.appendingPathComponent("KitChecks-compat-span-143-\(UUID().uuidString)", isDirectory: true)
    defer { try? fm.removeItem(at: tmp) }
    do {
        try CompatFixtures.prepare(from: CompatFixtures.committedFolder, into: tmp)
        for e in listed { try fm.copyItem(at: folder.appendingPathComponent(e.name), to: tmp.appendingPathComponent(e.name)) }
        var names: [String] = []
        var failed: [String] = []
        let result = Compat10Checks.run(fixtures: tmp) { name, ok in
            names.append(name)
            if !ok { failed.append(name) }
        }
        check(failed.isEmpty, "compat-span-143: Compat10Checks passes on compat11 and compat-span-143 together (\(failed.prefix(3)))")
        for e in listed {
            let mine = names.filter { $0.hasPrefix(e.name + ":") }.count
            check(mine >= 14, "compat-span-143: Compat10Checks ran \(mine) checks on \(e.name) (read, write back, draw, lasso, erase, merge, a 1.0 edit)")
        }
        print("   compat10 with compat-span-143: \(result.passed + result.failed) checks, \(result.failed) failed")
    } catch {
        check(false, "compat-span-143: preparing the folder for Compat10Checks (\(error))")
    }

    // Export and import: today's Kit writes, 1.0 reads and writes the same bytes, today's Kit imports the same pages.
    let all = listed.compactMap { pages[$0.name] }
    let export = AppExport.encode(AppExport.Document(exportedAt: "2026-11-28T09:00:00+09:00", app: "ios/1.4.3 (0)", pages: all))
    if let json10 = try? JSONValueV10.parse(export), let doc10 = try? AppExportV10.parse(json: json10) {
        check(AppExportV10.encode(doc10) == export && doc10.pages.count == all.count
              && zip(doc10.pages, all).allSatisfy { (try? InkPageCodecV10.encode($0.0)) == (try? InkPageCodec.encode($0.1)) },
              "compat-span-143: 1.0 reads the export of every fixture page and writes the same bytes back")
    } else {
        check(false, "compat-span-143: 1.0 reads the export of the fixture pages")
    }
    if case .app(let doc, let skipped)? = try? InkImport.parse(export) {
        check(skipped == 0 && doc.pages == all && doc.pages.allSatisfy(SpanGuard.checkForTransfer),
              "compat-span-143: the export imports into the same pages and every page passes the import door")
    } else {
        check(false, "compat-span-143: the export of the fixture pages imports")
    }
}
