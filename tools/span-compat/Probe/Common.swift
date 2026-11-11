import Foundation
import CoreGraphics
import InkModel
import Layout

// tools/span-compat (docs/M7C_CONTRACT.md §6.3, §10.4): the part of the Probe that is the same for every old
// version. It uses only the API that 1.0 (a21e469), <1.1.1> and 1.2.3 (43fe366) all have; what differs (how the
// version lays a page out, what it draws of each fixture) is in <version>/Version.swift. run.sh puts this file,
// main.swift and one Version.swift into a package that builds against that version's real TegakiKit.

var checkCount = 0
var failureCount = 0

/// One check: counted, and printed only when it fails.
func check(_ ok: Bool, _ name: @autoclosure () -> String) {
    checkCount += 1
    if !ok {
        failureCount += 1
        print("FAIL " + name())
    }
}

/// A page id as the stored form writes it. 1.0's PageNavigation has no parser, so the four forms are read here.
enum PageRef {
    case day(DayKey)
    case week(DayKey)
    case month(YearMonth)
    case year(Int)
}

func pageRef(_ pageId: String) -> PageRef? {
    if pageId.hasPrefix("d-"), let d = DayKey(ymd: String(pageId.dropFirst(2))) { return .day(d) }
    if pageId.hasPrefix("w-"), let d = DayKey(ymd: String(pageId.dropFirst(2))) { return .week(d) }
    if pageId.hasPrefix("m1-") {
        let parts = pageId.dropFirst(3).split(separator: "-", omittingEmptySubsequences: false)
        if parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) { return .month(YearMonth(year: y, month: m)) }
    }
    if pageId.hasPrefix("y-"), let y = Int(pageId.dropFirst(2)) { return .year(y) }
    return nil
}

/// The layouts are made for a fixed "now" in Tokyo, so every run lays the pages out the same way.
let tokyo: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return c
}()
let probeNow = DayKey(year: 2026, month: 11, day: 12).startOfDay(in: tokyo)

/// A time after every time in the fixtures (this version's own edits).
let later = 1_792_000_000_000

/// A cell every layout of that kind has (where this version's own stroke goes).
func ownCell(_ pageId: String) -> CellKey {
    if pageId.hasPrefix("m1-") { return .memo }
    if pageId.hasPrefix("y-") { return .yearDay(month: 1, day: 1) }
    return .grid
}

/// The MANIFEST's rows: "<file> <fixture> <monday|sunday>" after the "#" lines.
struct ManifestRow {
    let file: String
    let fixture: Int
    let shape: String
}

func readManifest(_ folder: URL) -> [ManifestRow] {
    guard let text = try? String(contentsOf: folder.appendingPathComponent("MANIFEST"), encoding: .utf8) else {
        check(false, "MANIFEST: present in \(folder.path)")
        return []
    }
    var rows: [ManifestRow] = []
    for line in text.split(separator: "\n", omittingEmptySubsequences: true) where !line.hasPrefix("#") {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3, let n = Int(parts[1]), parts[2] == "monday" || parts[2] == "sunday" else {
            check(false, "MANIFEST: \"\(line)\" is <file> <fixture> <monday|sunday>")
            continue
        }
        rows.append(ManifestRow(file: String(parts[0]), fixture: n, shape: String(parts[2])))
    }
    return rows
}
