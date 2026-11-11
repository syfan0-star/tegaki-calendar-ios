import Foundation
import CoreGraphics
import InkModel
import Layout

// tools/span-compat (docs/M7C_CONTRACT.md §6.3, §10.4): an old version's REAL TegakiKit reads EVERY compat-span
// fixture (TegakiKit/Tests/Fixtures/compat-span, the Monday and the Sunday shapes) and must neither lose nor
// change anything: the items and tombstones it reads, the bytes it writes back, what its layout draws and its
// lasso reaches (`InkLedger.drawing()` and the lasso's candidates: the live strokes of the cells the layout has),
// what opening, merging and its own erase and edit do, and the app export's round trip.
//
//   Probe <compat-span folder>
//
// Prints a line per file, FAIL lines, and last `span-compat <version>: N checks, F failed`; exits 1 on a failure.

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    print("usage: Probe <compat-span folder>")
    exit(2)
}
let folder = URL(fileURLWithPath: arguments[1], isDirectory: true)

// MANIFEST ⇄ folder, both ways; every row has this version's expectation.
let rows = readManifest(folder)
let onDisk = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
check(!rows.isEmpty, "MANIFEST: has rows")
check(onDisk == rows.map(\.file).sorted(), "MANIFEST ⇄ folder: every *.json is listed and every row's file is there (\(onDisk.count) files, \(rows.count) rows)")
check(Set(rows.map(\.shape)) == ["monday", "sunday"], "MANIFEST: Monday and Sunday rows")
check(Set(expectedDrawn.keys) == Set(rows.map(\.file)),
      "every MANIFEST row has this version's expectation in tools/span-compat/\(versionFolder)/Version.swift (missing: \(Set(rows.map(\.file)).subtracting(expectedDrawn.keys).sorted()), not in MANIFEST: \(Set(expectedDrawn.keys).subtracting(rows.map(\.file)).sorted()))")

var pages: [InkPage] = []
for row in rows {
    let name = row.file
    let before = (checkCount, failureCount)
    guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
          let page = try? InkPageCodec.decode(data),
          let raw = try? JSONValue.parse(data) else {
        check(false, "\(name): reads")
        continue
    }
    pages.append(page)

    // What it reads and writes back.
    check(name.hasPrefix(page.pageId + "."), "\(name): holds the page its name says (\(page.pageId))")
    check((try? InkPageCodec.encode(page)) == data, "\(name): writes back the same bytes")
    check(InkPage(json: page.jsonValue) == page, "\(name): its JSON reads back to the same page")
    check((try? InkPageCodec.decode(InkPageCodec.decompress(InkPageCodec.compress(data)))) == page, "\(name): the stored (compressed) form reads to the same page")
    let rawItems = raw["strokes"]?.objectValue ?? [:]
    check(Set(page.strokes.keys).union(page.unknownStrokes.keys) == Set(rawItems.keys) && Set(page.strokes.keys).isDisjoint(with: page.unknownStrokes.keys),
          "\(name): every item of the file is kept (\(rawItems.count) items: \(page.strokes.count) strokes, \(page.unknownStrokes.count) of unknown tools)")
    check(page.strokes.allSatisfy { $0.value.jsonValue.serialized() == rawItems[$0.key]?.serialized() },
          "\(name): every stroke as written (id, cell, tool, every point: none cut, none moved)")
    check(page.unknownStrokes.allSatisfy { $0.value.serialized() == rawItems[$0.key]?.serialized() }, "\(name): every item of an unknown tool as written")
    check(page.jsonValue["deleted"]?.serialized() == raw["deleted"]?.serialized(), "\(name): every tombstone as written (\(page.deleted.count))")
    if case .week(let first)? = pageRef(page.pageId) {
        check((first.weekday == 0) == (row.shape == "sunday"), "\(name): the MANIFEST's shape \(row.shape) is the week's (weekday \(first.weekday), 0 = Sunday)")
    } else {
        check(row.shape == "monday", "\(name): a page that is not a week is of shape monday")
    }

    // What this version's layout of the page draws and lassoes (nil: it never opens the page).
    guard let ref = pageRef(page.pageId), let expected = expectedDrawn[name] else {
        check(false, "\(name): a page id this probe knows, with an expectation")
        continue
    }
    let layout = versionLayout(ref, page: page)
    var drawn: [String] = []
    if layout.pageId == page.pageId {
        drawn = page.liveStrokes.filter { !$0.points.isEmpty && layout.cells[$0.cell] != nil }.map(\.id)
        let lasso = page.liveStrokes.filter { layout.cells[$0.cell] != nil && $0.paperBounds(cellOrigin: .zero) != nil }.map(\.id)
        check(expected == drawn.count, "\(name): opens and draws \(drawn.count) of its \(page.liveStrokeCount) live strokes (expected \(expected.map { "\($0)" } ?? "never opened"))")
        check(Set(lasso) == Set(drawn), "\(name): the lasso reaches exactly the drawn strokes")
        check(page.liveStrokes.allSatisfy { layout.cells[$0.cell] == nil || $0.paperBounds(cellOrigin: layout.cells[$0.cell]!.origin) != nil },
              "\(name): every drawn stroke has bounds on the paper (overhanging or not)")
    } else {
        check(expected == nil, "\(name): this version never opens \(page.pageId) (its page for that day is \(layout.pageId); expected \(expected.map { "\($0) drawn" } ?? "never opened"))")
    }

    // Opening it moves nothing (so nothing is saved); merging with itself changes nothing.
    check(BandMigration.migrate(page) == page, "\(name): opening it moves nothing (band migration)")
    check(InkPage.merge(page, page) == page, "\(name): merged with itself, the same page")

    // This version erases everything it draws: the other items stay byte for byte.
    var erased = page
    erased.remove(ids: drawn, at: later)
    let erasedItems = erased.jsonValue["strokes"]?.objectValue ?? [:]
    check(Set(erasedItems.keys) == Set(rawItems.keys).subtracting(drawn) && erasedItems.allSatisfy { $0.value.serialized() == rawItems[$0.key]?.serialized() },
          "\(name): erasing what it draws keeps every other item byte for byte")

    // A stroke this version writes into a cell of its own, merged both ways: nothing else changes.
    var other = InkPage.empty(pageId: page.pageId)
    let point = InkPoint(x: 40, y: 40, dtMs: 0, sizeW: 2, sizeH: 2, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5)
    other.add(InkStroke(id: "span-compat-probe", cell: ownCell(page.pageId), tool: .pen, color: "#1f2937", t: later, dev: "span-compat", points: [point]))
    for (order, merged) in [("theirs first", InkPage.merge(other, page)), ("ours first", InkPage.merge(page, other))] {
        let mergedItems = merged.jsonValue["strokes"]?.objectValue ?? [:]
        check(merged.liveStrokeCount == page.liveStrokeCount + 1 && merged.pageId == page.pageId
              && merged.jsonValue["deleted"]?.serialized() == raw["deleted"]?.serialized()
              && rawItems.allSatisfy { mergedItems[$0.key]?.serialized() == $0.value.serialized() },
              "\(name): merged with this version's own stroke (\(order)): every item and tombstone unchanged")
    }

    let opened = layout.pageId == page.pageId ? "opens it, draws \(drawn.count)/\(page.liveStrokeCount)" : "never opens it (\(layout.pageId))"
    print("\(name) [\(row.shape)]: \(opened), \(page.unknownStrokes.count) unknown, \(page.deleted.count) tombstone(s); \(checkCount - before.0) checks, \(failureCount - before.1) failed")
}

// The app export of every fixture page: imported whole by this version, written back byte for byte.
let document = AppExport.Document(exportedAt: "2026-11-12T09:00:00+09:00", app: "ios/1.3 (0)", pages: pages)
let exported = AppExport.encode(document)
if let parsed = try? InkImport.parse(exported) {
    let outcome = InkImport.pages(parsed)
    check(outcome.isAppExport && outcome.skipped == 0 && outcome.pages == pages, "export → import: the \(pages.count) pages come in whole, skipped \(outcome.skipped)")
    check(AppExport.encode(AppExport.Document(exportedAt: document.exportedAt, app: document.app, pages: outcome.pages)) == exported,
          "export → import → export: the same bytes")
} else {
    check(false, "export → import: the export of the fixture pages parses")
}

print("span-compat \(versionName): \(checkCount) checks, \(failureCount) failed")
exit(failureCount == 0 ? 0 : 1)
