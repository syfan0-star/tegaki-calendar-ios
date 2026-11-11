// KitChecks: the InkModel half of the checks of the joined pages of 1.3 (docs/M7C_CONTRACT.md §10.1,
// section "span ink (1.3)", role K part 2): SpanGuard (and SpanName with it), SpanComposer and PageDelta.
// main.swift calls `runSpanInkChecks()` on the line after `runSpanChecks()`; it uses main.swift's
// `section`, `check`, `checkEqual` and `Rng`, and SpanChecks.swift's `SpanFixtures`.
//
// The expectations are worked out apart from the code under test: the write form and the prefix form
// with NSRegularExpression and ASCII classes ([0-9], not \d, which also takes other digits), weekdays
// from Foundation's calendar, the pages after an edit from `InkPage.add` / `remove` applied to the real
// pages directly (what the one-page ledger does), JSON compared as bytes.
import Foundation
import CoreGraphics
import Layout
@_spi(SpanLedger) import InkModel
import Compat10
import CompatFixtures
import CompatSpanFixtures

// MARK: - Shared building blocks

enum SpanInk {
    /// §6.1's write form, ASCII digits (\\z: the end of the text, where ICU's $ would also stop before a
    /// final line break).
    static let writeForm = try! NSRegularExpression(pattern: "^(d-[0-9]{4}-[0-9]{2}-[0-9]{2}|w-[0-9]{4}-[0-9]{2}-[0-9]{2}|m1-[0-9]{4}-[0-9]{2}|y-[0-9]{4})\\z")
    /// §6.1's prefix form, ASCII digits.
    static let prefixForm = try! NSRegularExpression(pattern: "^(?:[dw]-[0-9]{4}-[0-9]{2}-[0-9]{2}|m1-[0-9]{4}-[0-9]{2}|y-[0-9]{4})\\|")

    static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The write form and, for "w-", a Monday or a Sunday by Foundation's calendar.
    static func expectedWriteForm(_ pageId: String) -> Bool {
        guard matches(writeForm, pageId) else { return false }
        guard pageId.hasPrefix("w-") else { return true }
        let parts = pageId.dropFirst(2).split(separator: "-").compactMap { Int($0) }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        guard c.isValidDate(in: SpanFixtures.utc), let date = SpanFixtures.utc.date(from: c) else { return false }
        let weekday = SpanFixtures.utc.component(.weekday, from: date) // 1 = Sunday, 2 = Monday
        return weekday == 1 || weekday == 2
    }

    /// The page in front of a name of the prefix form, by the regex.
    static func expectedPrefix(_ name: String) -> (page: String, local: String)? {
        guard matches(prefixForm, name), let bar = name.firstIndex(of: "|") else { return nil }
        return (String(name[..<bar]), String(name[name.index(after: bar)...]))
    }

    enum Expect: Equatable { case keep, strip(String), drop }

    /// §6.1 for one name of an item of `pageId` (release): another page's prefix or "span~" → drop; the
    /// page's own prefix → strip, unless what is left is empty or again a window name.
    static func expected(_ name: String, pageId: String) -> Expect {
        if let p = expectedPrefix(name) {
            guard p.page == pageId, !p.local.isEmpty, !p.local.hasPrefix("span~"), expectedPrefix(p.local) == nil else { return .drop }
            return .strip(p.local)
        }
        return name.hasPrefix("span~") ? .drop : .keep
    }

    static func isWindowName(_ name: String) -> Bool {
        expectedPrefix(name) != nil || name.hasPrefix("span~")
    }

    static func point(_ x: CGFloat, _ y: CGFloat, _ i: Int = 0) -> InkPoint {
        InkPoint(x: x, y: y, dtMs: 8 * i, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0.785, altitude: 1.2)
    }

    /// A pen stroke of three points from (x, y).
    static func stroke(_ id: String, cell: String, t: Int, x: CGFloat = 10, y: CGFloat = 20, tool: InkTool = .pen, color: String = "#1f2937") -> InkStroke {
        InkStroke(id: id, cell: CellKey(raw: cell), tool: tool, color: color, t: t, dev: "kitchecks",
                  points: (0..<3).map { point(x + CGFloat($0) * 6, y + CGFloat($0 % 2), $0) })
    }

    /// An item of a tool 1.2.3 does not know, as a newer version writes it (PLAN_PHOTO_TEXT.md:41).
    static func unknown(_ id: String, cell: String?, tool: String = "photo", t: Int) -> JSONValue {
        var object: [String: JSONValue] = ["id": .string(id), "tool": .string(tool), "t": .number(Double(t)), "dev": .string("kitchecks"),
                                           "rect": .array([.number(12), .number(34), .number(160), .number(90)])]
        if let cell = cell { object["cell"] = .string(cell) }
        if tool == "photo" { object["img"] = .string(String(repeating: "ab", count: 32)) }
        if tool == "text" { object["text"] = .string("牛乳を買う") }
        return .object(object)
    }

    static func bytes(_ page: InkPage) -> Data {
        (try? InkPageCodec.encode(page)) ?? Data()
    }

    /// The stored JSON of one stroke (or unknown item) of a page, by key; nil when it is not written.
    static func strokeJSON(_ page: InkPage, _ key: String) -> String? {
        page.jsonValue["strokes"]?[key]?.serialized()
    }
}

// MARK: - The section

func runSpanInkChecks() {
    section("span ink (1.3)")
    spanGuardPageIdChecks()
    spanGuardNameChecks()
    spanGuardRepairChecks()
    spanGuardRandomChecks()
    spanComposeChecks()
    spanDeltaChecks()
    spanSafetyNetChecks()
    spanOffPaperChecks()
    spanPDFInkChecks()
    spanComposerRandomChecks(.week, seed: 0x5BA9_C0DE_0001)
    spanComposerRandomChecks(.day, seed: 0x5BA9_C0DE_0002)
    spanCompatFixtureChecks()
}

// MARK: - --write-compat-span-fixtures [--out <folder>] (§4.2, §6.3)

/// Writes the compat-span fixtures and MANIFEST into TegakiKit/Tests/Fixtures/compat-span/ or <folder>,
/// lists each file as new, unchanged or changed, and exits without running the checks (the same as
/// --write-compat-fixtures does for compat11; main.swift calls it before any check).
func writeCompatSpanFixtures() -> Never {
    let arguments = CommandLine.arguments
    var folder = CompatSpanFixtures.committedFolder
    if let i = arguments.firstIndex(of: "--out") {
        guard i + 1 < arguments.count else {
            print("KitChecks: --out needs a folder")
            exit(2)
        }
        folder = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
    }
    do {
        let results = try CompatSpanFixtures.write(to: folder)
        for (name, result) in results {
            print("\(result.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))\(name)")
        }
        let changed = results.filter { $0.result == .changed }.count
        let new = results.filter { $0.result == .new }.count
        print("KitChecks: wrote the compat-span fixtures to \(folder.path) (\(results.count) files: \(new) new, \(changed) changed)")
        exit(0)
    } catch {
        print("KitChecks: writing the compat-span fixtures failed: \(error)")
        exit(1)
    }
}

// MARK: - SpanGuard: the page id (§6.1, K-11, §4.6 (a))

func spanGuardPageIdChecks() {
    var ids = ["d-2026-11-02", "w-2026-11-02", "w-2026-11-01", "m1-2026-11", "y-2026", "w-1969-12-29", "w-1969-12-28",
               "d-0001-01-01", "y-9999", "m1-0001-01", "d-2026-02-30", "m1-2026-13",
               "w-2026-11-03", "w-2026-11-07", "w-2026-13-45", "w-2026-02-30", "d-2026-11-2", "w-2026-11-02x", "m1-2026-1",
               "y-26", "y-20266", "W-2026-11-02", "w-\u{FF12}\u{FF10}\u{FF12}\u{FF16}-11-02", "d-\u{0662}\u{0660}\u{0662}\u{0666}-11-02",
               "span~week~0", "w-2026-11-02|grid", "", "wb-2026-11-02", "db-2026-11-02", "proto-w-2026-11-02", "x-2026",
               " d-2026-11-02", "d-2026-11-02 ", "m1-2026-11-01", "y-2026|", "d-2026-11-02\n"]
    // Every day of four weeks around the year's end and of November 2026, as a week id.
    for n in SpanFixtures.dayNumber(2026, 10, 25)...SpanFixtures.dayNumber(2026, 11, 22) { ids.append("w-" + SpanFixtures.ymd(dayNumber: n).text) }
    for n in SpanFixtures.dayNumber(2026, 12, 24)...SpanFixtures.dayNumber(2027, 1, 10) { ids.append("w-" + SpanFixtures.ymd(dayNumber: n).text) }

    for id in ids {
        let expected = SpanInk.expectedWriteForm(id)
        checkEqual(SpanGuard.isWriteForm(id), expected, "span guard: \(id.debugDescription) is\(expected ? "" : " not") of the write form")
        checkEqual(SpanGuard.checkForSave(InkPage(pageId: id)), expected ? .ok : .refused,
                   "span guard: an empty page \(id.debugDescription) is \(expected ? "saved" : "refused") (release)")
        // The prototype saves only "proto-" + the write form, and refuses every real id (§4.6 (a), D13).
        checkEqual(SpanGuard.checkForSave(InkPage(pageId: "proto-" + id), mode: .prototype), expected ? .ok : .refused,
                   "span guard: the prototype page proto-\(id.debugDescription) is \(expected ? "saved" : "refused")")
        if !id.hasPrefix("proto-") {
            checkEqual(SpanGuard.checkForSave(InkPage(pageId: id), mode: .prototype), .refused,
                       "span guard: the prototype refuses the real id \(id.debugDescription)")
        }
    }
    check(SpanGuard.isWriteForm("w-2026-11-02") && SpanGuard.isWriteForm("w-2026-11-01") && !SpanGuard.isWriteForm("w-2026-11-04"),
          "span guard: a week id is a Monday or a Sunday (K-11)")
    checkEqual(SpanGuard.checkForSave(InkPage(pageId: "proto-"), mode: .prototype), .refused, "span guard: \"proto-\" alone is refused")
    checkEqual(SpanGuard.checkForSave(InkPage(pageId: "proto-span~week~0"), mode: .prototype), .refused, "span guard: proto-span~… is refused")
    // The virtual page never saves, whatever it holds; nor does it go out (transfer).
    var virtual = InkPage(pageId: "span~week~3")
    virtual.add(SpanInk.stroke("w-2026-11-02|a", cell: "w-2026-11-02|grid", t: 5))
    checkEqual(SpanGuard.checkForSave(virtual), .refused, "span guard: the virtual page is refused (release)")
    checkEqual(SpanGuard.checkForSave(virtual, mode: .prototype), .refused, "span guard: the virtual page is refused (prototype)")
    check(!SpanGuard.checkForTransfer(virtual) && !SpanGuard.checkForTransfer(InkPage(pageId: "span~day~0")),
          "span guard: a virtual page id never goes out (import, export, PDF)")
    check(!SpanGuard.checkForTransfer(InkPage(pageId: "w-2026-11-02|grid")), "span guard: a prefixed page id never goes out")
    // A page id of a later version (F2) goes out and comes in, it is only not saved by this screen.
    for id in ["wb-2026-11-02", "db-2026-11-02", "focus-2026", "w-2026-11-03", ""] {
        check(SpanGuard.checkForTransfer(InkPage(pageId: id)), "span guard: the page id \(id.debugDescription) goes through import and export (F2)")
    }
}

// MARK: - SpanGuard and SpanName: real names pass, window names never (§6.1, §10.1)

func spanGuardNameChecks() {
    let page = "w-2026-11-02"
    let virtualNames = ["span~week~0", "span~day~12", "span~a~3", "span~", "span~month~1|x"]
    let all = SpanFixtures.realNames + SpanFixtures.prefixedNames.map(\.name) + virtualNames
    for name in all {
        checkEqual(SpanGuard.isWindowName(name), SpanInk.isWindowName(name), "span guard: \(name.debugDescription) is\(SpanInk.isWindowName(name) ? "" : " not") a window name (the regex of §6.1)")
    }

    // Every real name, in every place of a page, passes both doors untouched.
    for name in SpanFixtures.realNames {
        for role in ["stroke", "cell", "tombstone", "unknown", "unknown cell"] {
            var p = InkPage(pageId: page)
            p.strokes["clean-1"] = SpanInk.stroke("clean-1", cell: "grid", t: 1)
            switch role {
            case "stroke": p.strokes[name] = SpanInk.stroke(name, cell: "grid", t: 2)
            case "cell": p.strokes["s-1"] = SpanInk.stroke("s-1", cell: name, t: 2)
            case "tombstone": p.deleted[name] = 2
            case "unknown": p.unknownStrokes[name] = SpanInk.unknown(name, cell: "grid", tool: "text", t: 2)
            default: p.unknownStrokes["u-1"] = SpanInk.unknown("u-1", cell: name, t: 2)
            }
            check(SpanGuard.checkForTransfer(p) && SpanGuard.checkForSave(p) == .ok,
                  "span guard: the real name \(name.debugDescription) as a \(role) goes out and saves untouched")
        }
    }

    // Every prefixed and virtual name is caught in every place: stripped on its own page, dropped elsewhere.
    for (name, prefixPage, local) in SpanFixtures.prefixedNames {
        for host in [prefixPage, "d-2026-11-03"] where SpanGuard.isWriteForm(host) {
            let expect = SpanInk.expected(name, pageId: host)
            for role in ["stroke", "cell", "tombstone", "unknown"] {
                var p = InkPage(pageId: host)
                let clean = SpanInk.stroke("clean-1", cell: "grid", t: 1)
                p.strokes["clean-1"] = clean
                switch role {
                case "stroke": p.strokes[name] = SpanInk.stroke(name, cell: "grid", t: 2)
                case "cell": p.strokes["s-1"] = SpanInk.stroke("s-1", cell: name, t: 2)
                case "tombstone": p.deleted[name] = 2
                default: p.unknownStrokes[name] = SpanInk.unknown(name, cell: "grid", t: 2)
                }
                let key = role == "cell" ? "s-1" : name
                check(!SpanGuard.checkForTransfer(p), "span guard: \(name) as a \(role) on \(host) never goes out")
                guard case .repaired(let fixed, let stripped, let dropped) = SpanGuard.checkForSave(p) else {
                    check(false, "span guard: \(name) as a \(role) on \(host) is repaired")
                    continue
                }
                switch expect {
                case .strip(let rest):
                    check(stripped == [key] && dropped.isEmpty, "span guard: \(name) as a \(role) on its own page \(host) is stripped")
                    switch role {
                    case "stroke": check(fixed.strokes[rest]?.id == rest && fixed.strokes[name] == nil, "span guard: …the stroke is \(rest.debugDescription) now")
                    case "cell": check(fixed.strokes["s-1"]?.cell.raw == local, "span guard: …its cell is \(local.debugDescription) now")
                    case "tombstone": check(fixed.deleted[rest] == 2 && fixed.deleted[name] == nil, "span guard: …the tombstone is \(rest.debugDescription) now")
                    default: check(fixed.unknownStrokes[rest] != nil && fixed.unknownStrokes[name] == nil, "span guard: …the item is \(rest.debugDescription) now")
                    }
                case .drop:
                    check(dropped == [key] && stripped.isEmpty && fixed.strokes[key] == nil && fixed.deleted[key] == nil && fixed.unknownStrokes[key] == nil,
                          "span guard: \(name) as a \(role) on \(host) is dropped (\(prefixPage == host ? "nothing usable after the prefix" : "another page's name"))")
                case .keep:
                    check(false, "span guard: \(name) is a window name")
                }
                check(fixed.strokes["clean-1"] == clean && SpanInk.strokeJSON(fixed, "clean-1") == SpanInk.strokeJSON(p, "clean-1"),
                      "span guard: …and the clean stroke next to it is kept byte for byte")
            }
        }
    }
    for name in virtualNames {
        var p = InkPage(pageId: page)
        p.strokes["x"] = SpanInk.stroke("x", cell: name, t: 1)
        p.deleted[name] = 2
        check(!SpanGuard.checkForTransfer(p), "span guard: the virtual name \(name) never goes out")
        checkEqual(SpanGuard.checkForSave(p), .repaired(InkPage(pageId: page, updatedAt: 0), stripped: [], dropped: [name, "x"].sorted()),
                   "span guard: the virtual name \(name) is dropped as a cell and as a tombstone")
    }

    // A name prefixed twice, the page's own prefix first: taking it off would leave a window name (F4), so
    // the item is dropped, as a stroke key, a cell and a tombstone; the page left saves and goes out.
    var doubled = InkPage(pageId: page)
    let kept = SpanInk.stroke("clean-1", cell: "grid", t: 1)
    doubled.strokes["clean-1"] = kept
    doubled.strokes["s-1"] = SpanInk.stroke("s-1", cell: page + "|w-2026-11-09|grid", t: 2)
    let twiceKey = page + "|d-2026-11-03|y"
    doubled.strokes[twiceKey] = SpanInk.stroke(twiceKey, cell: "grid", t: 3)
    doubled.deleted[page + "|" + page + "|z"] = 4
    var onlyKept = InkPage(pageId: page)
    onlyKept.strokes["clean-1"] = kept
    checkEqual(SpanGuard.checkForSave(doubled), .repaired(onlyKept, stripped: [], dropped: ["s-1", twiceKey, page + "|" + page + "|z"].sorted()),
               "span guard: a cell, a stroke key and a tombstone prefixed twice are dropped, never stripped into a window name")
    if case .repaired(let fixedDoubled, _, _) = SpanGuard.checkForSave(doubled) {
        check(SpanGuard.checkForTransfer(fixedDoubled) && SpanGuard.checkForSave(fixedDoubled) == .ok,
              "span guard: …and the page left saves as it is and goes out")
    }

    // The alias of a long id (§3.2): stripped it starts with span~, so the guard stops it however it leaks.
    let alias = SpanName.alias(page: page, number: 7)
    for leaked in [alias, SpanName.strip(id: alias)] {
        var p = InkPage(pageId: page)
        p.strokes[leaked] = SpanInk.stroke(leaked, cell: "grid", t: 1)
        p.deleted[leaked + "-t"] = 2
        let result = SpanGuard.checkForSave(p)
        check(!SpanGuard.checkForTransfer(p), "span guard: the alias \(leaked) never goes out")
        if case .repaired(let fixed, let stripped, let dropped) = result {
            check(fixed.strokes.isEmpty && fixed.deleted.isEmpty && stripped.isEmpty && Set(dropped) == [leaked, leaked + "-t"],
                  "span guard: the alias \(leaked) (as a stroke and a tombstone) is dropped, even on its own page")
        } else {
            check(false, "span guard: the alias \(leaked) is dropped")
        }
    }
}

// MARK: - SpanGuard: only the offending items are repaired (§6.1, §10.1)

func spanGuardRepairChecks() {
    let page = "w-2026-11-02"
    let other = "w-2026-11-09"
    var p = InkPage(v: 1, pageId: page, updatedAt: 1_790_000_009_000, unknown: ["later": .object(["a": .number(1)])])
    let clean = [SpanInk.stroke("8f14e45f-ceea-467a-9e0e-5c0c1a9b6e0f", cell: "grid", t: 1_790_000_001_000, x: -300, y: 1880),
                 SpanInk.stroke("k3j2h1~w1", cell: "grid", t: 1_790_000_002_000, x: 1600, y: 99_999),
                 SpanInk.stroke("abc|def", cell: "grid", t: 1_790_000_003_000),
                 SpanInk.stroke("plain", cell: "a|b", t: 1_790_000_004_000)]
    for s in clean { p.strokes[s.id] = s }
    p.deleted["gone-1"] = 1_790_000_005_000
    p.deleted["text|1"] = 1_790_000_005_500
    p.unknownStrokes["photo|img"] = SpanInk.unknown("photo|img", cell: "grid", t: 1_790_000_006_000)
    p.unknownStrokes["tx-1"] = SpanInk.unknown("tx-1", cell: "grid", tool: "text", t: 1_790_000_006_500)
    // Leaks: the page's own prefix (a stroke, its cell, a tombstone, an unknown item), another page's,
    // span~, and an own-prefixed tombstone of a clean live stroke.
    let ownStroke = SpanInk.stroke(page + "|own-1", cell: page + "|grid", t: 1_790_000_007_000)
    p.strokes[ownStroke.id] = ownStroke
    p.strokes["own-2"] = SpanInk.stroke("own-2", cell: page + "|grid", t: 1_790_000_007_100)
    p.strokes["oth-1"] = SpanInk.stroke("oth-1", cell: other + "|grid", t: 1_790_000_007_200)
    p.strokes[other + "|oth-2"] = SpanInk.stroke(other + "|oth-2", cell: "grid", t: 1_790_000_007_300)
    p.strokes["span~a~4"] = SpanInk.stroke("span~a~4", cell: "grid", t: 1_790_000_007_400)
    p.deleted[page + "|plain"] = 1_790_000_008_000
    p.deleted[other + "|gone-2"] = 1_790_000_008_100
    p.unknownStrokes[page + "|ph-2"] = SpanInk.unknown(page + "|ph-2", cell: page + "|grid", t: 1_790_000_008_200)
    p.unknownStrokes["ph-3"] = SpanInk.unknown("ph-3", cell: "span~week~0|grid", t: 1_790_000_008_300)
    let before = p

    check(!SpanGuard.checkForTransfer(p), "span guard repair: the page with leaks does not go out as it is")
    guard case .repaired(let fixed, let stripped, let dropped) = SpanGuard.checkForSave(p) else {
        check(false, "span guard repair: the page with leaks is repaired, not refused (§6.1)")
        return
    }
    checkEqual(stripped, [page + "|own-1", page + "|ph-2", page + "|plain", "own-2"].sorted(), "span guard repair: the page's own prefixes are stripped")
    checkEqual(dropped, [other + "|gone-2", other + "|oth-2", "oth-1", "ph-3", "span~a~4"].sorted(), "span guard repair: other pages' names and span~ are dropped")
    var expected = InkPage(v: 1, pageId: page, updatedAt: 1_790_000_009_000, unknown: ["later": .object(["a": .number(1)])])
    for s in clean where s.id != "plain" { expected.strokes[s.id] = s }
    var own1 = ownStroke
    own1.id = "own-1"
    own1.cell = .grid
    expected.strokes["own-1"] = own1
    var own2 = before.strokes["own-2"]!
    own2.cell = .grid
    expected.strokes["own-2"] = own2
    expected.deleted = ["gone-1": 1_790_000_005_000, "text|1": 1_790_000_005_500, "plain": 1_790_000_008_000]
    expected.unknownStrokes["photo|img"] = before.unknownStrokes["photo|img"]
    expected.unknownStrokes["tx-1"] = before.unknownStrokes["tx-1"]
    expected.unknownStrokes["ph-2"] = SpanInk.unknown("ph-2", cell: "grid", t: 1_790_000_008_200)
    checkEqual(SpanInk.bytes(fixed), SpanInk.bytes(expected), "span guard repair: the repaired page is exactly the expected one (JSON)")
    check(fixed.v == before.v && fixed.updatedAt == before.updatedAt && fixed.unknown == before.unknown && fixed.pageId == page,
          "span guard repair: v, updatedAt, the unknown top-level items and the id are kept")
    for s in clean where s.id != "plain" {
        check(SpanInk.strokeJSON(fixed, s.id) == SpanInk.strokeJSON(before, s.id), "span guard repair: the clean stroke \(s.id) is byte for byte the same")
    }
    check(SpanInk.strokeJSON(fixed, "photo|img") == SpanInk.strokeJSON(before, "photo|img") && SpanInk.strokeJSON(fixed, "tx-1") == SpanInk.strokeJSON(before, "tx-1"),
          "span guard repair: the unknown-tool items photo and text are byte for byte the same")
    check(fixed.strokes["plain"] == nil && fixed.deleted["plain"] != nil,
          "span guard repair: a stripped tombstone of a live stroke tombstones it (the session erased it)")
    check(fixed.strokes["8f14e45f-ceea-467a-9e0e-5c0c1a9b6e0f"]?.points.first?.x == -300 && fixed.strokes["k3j2h1~w1"]?.points.first?.y == 99_999,
          "span guard repair: points outside the paper stay (§4.1)")
    checkEqual(SpanGuard.checkForSave(fixed), .ok, "span guard repair: the repaired page saves as it is")
    check(SpanGuard.checkForTransfer(fixed), "span guard repair: the repaired page goes out")

    // Two contents of one id after stripping: a tombstone wins, otherwise the merge's pick.
    var twin = InkPage(pageId: page)
    let a = SpanInk.stroke("twin", cell: "grid", t: 100)
    var b = a
    b.id = page + "|twin"
    b.cell = CellKey(raw: page + "|grid")
    twin.strokes["twin"] = a
    twin.strokes[b.id] = b
    if case .repaired(let fixedTwin, let s, _) = SpanGuard.checkForSave(twin) {
        check(fixedTwin.strokes == ["twin": a] && s == [b.id], "span guard repair: a stripped copy of a stroke that is there gives the one stroke")
    } else {
        check(false, "span guard repair: a stripped copy of a stroke that is there is repaired")
    }

    // "|" in what exists saves; "|" in what this session added does not (K-10, §6.1).
    var existing = InkPage(pageId: page)
    existing.strokes["abc|def"] = SpanInk.stroke("abc|def", cell: "grid", t: 1)
    existing.strokes["web~w1"] = SpanInk.stroke("web~w1", cell: "x|y", t: 2)
    existing.strokes["fresh"] = SpanInk.stroke("fresh", cell: "grid", t: 3)
    existing.deleted["old|1"] = 4
    existing.unknownStrokes["text|1"] = SpanInk.unknown("text|1", cell: "grid", tool: "text", t: 5)
    checkEqual(SpanGuard.checkForSave(existing), .ok, "span guard: ids and cells with a | that exist already save (import, web, hand-edited JSON, unknown tools)")
    checkEqual(SpanGuard.checkForSave(existing, added: ["fresh", "something-else"]), .ok, "span guard: an added id without a | saves")
    for (added, key) in [("abc|def", "abc|def"), ("web~w1", "web~w1"), ("old|1", "old|1"), ("text|1", "text|1")] {
        guard case .repaired(let fixedAdded, let s, let d) = SpanGuard.checkForSave(existing, added: [added]) else {
            check(false, "span guard: the added \(added) with a | (in its id or cell) is not saved")
            continue
        }
        var expectedAdded = existing
        expectedAdded.strokes[key] = nil
        expectedAdded.deleted[key] = nil
        expectedAdded.unknownStrokes[key] = nil
        check(s.isEmpty && d == [key] && SpanInk.bytes(fixedAdded) == SpanInk.bytes(expectedAdded),
              "span guard: only the added \(added) with a | (in its id or cell) is dropped, the rest saves byte for byte")
    }

    // Through the import door: a file whose ids hold a "|" goes in (transfer) and saves.
    let text = """
    {"v":1,"pageId":"\(page)","updatedAt":9,"deleted":{"del|9":9},"strokes":{\
    "id|1":{"id":"id|1","cell":"grid","tool":"pen","color":"#1f2937","t":1,"pts":[1,2,0,3,3,1,0.5,0,1.5]},\
    "sq~w1":{"id":"sq~w1","cell":"grid","tool":"marker","color":"#fde047","t":2,"pts":[-250,99999,0,18,18,1,0.5,0,1.5]},\
    "tape|2":{"id":"tape|2","cell":"grid","tool":"tape","t":3,"pts":[1,2,0,24,24,0.6,0.5,0,1.571]}}}
    """
    if let imported = try? InkPageCodec.decode(Data(text.utf8)) {
        check(imported.strokes.count == 2 && imported.unknownStrokes.count == 1, "span guard: the hand-written page reads (2 strokes, 1 unknown tool)")
        check(SpanGuard.checkForTransfer(imported) && SpanGuard.checkForSave(imported) == .ok, "span guard: the hand-written page with | in its ids goes in and saves")
        let export = AppExport.encode(AppExport.Document(exportedAt: "2026-11-12T09:00:00+09:00", app: "ios/1.3 (0)", pages: [imported]))
        if case .app(let doc, let skipped)? = try? InkImport.parse(export) {
            check(skipped == 0 && doc.pages == [imported] && doc.pages.allSatisfy { SpanGuard.checkForTransfer($0) && SpanGuard.checkForSave($0) == .ok },
                  "span guard: …and through an export and an import it is the same page and saves")
        } else {
            check(false, "span guard: the export of the hand-written page imports")
        }
    } else {
        check(false, "span guard: the hand-written page reads")
    }

    // The prototype (§4.6 (a)) composes its window with the real ids and saves each page as "proto-<id>":
    // on its page the real id's prefix is its own (stripped, as "proto-<id>|" is); another page's prefix,
    // real or prototype, is dropped. The release mode refuses the prototype's page id.
    let proto = "proto-" + page
    var pp = InkPage(pageId: proto)
    pp.strokes["a"] = SpanInk.stroke("a", cell: proto + "|grid", t: 1)
    pp.strokes["b"] = SpanInk.stroke("b", cell: page + "|grid", t: 2)
    pp.strokes["c"] = SpanInk.stroke("c", cell: "proto-w-2026-11-09|grid", t: 3)
    pp.strokes["d"] = SpanInk.stroke("d", cell: "grid", t: 4)
    pp.strokes["e"] = SpanInk.stroke("e", cell: "w-2026-11-09|grid", t: 5)
    pp.strokes[page + "|f"] = SpanInk.stroke(page + "|f", cell: page + "|grid", t: 6)
    pp.deleted[page + "|g"] = 7
    pp.deleted[page + "|" + page + "|h"] = 8
    if case .repaired(let fixedProto, let s, let d) = SpanGuard.checkForSave(pp, mode: .prototype) {
        check(s == ["a", "b", page + "|f", page + "|g"] && d == ["c", "e", page + "|" + page + "|h"]
              && fixedProto.strokes["a"]?.cell == .grid && fixedProto.strokes["b"]?.cell == .grid && fixedProto.strokes["d"] == pp.strokes["d"]
              && fixedProto.strokes["f"].map { $0.id == "f" && $0.cell == .grid } == true && fixedProto.deleted == ["g": 7],
              "span guard: on the prototype page \(proto) the window's names of \(page) and proto-\(page) are stripped, other pages' dropped")
        checkEqual(SpanGuard.checkForSave(fixedProto, mode: .prototype), .ok, "span guard: the repaired prototype page saves as it is")
    } else {
        check(false, "span guard: the prototype page with prefixes is repaired")
    }
    checkEqual(SpanGuard.checkForSave(pp), .refused, "span guard: the release mode refuses the prototype page")

    // A tombstone stripped onto a tombstone that is there keeps the later time, whichever of the two it is.
    for (plainTime, prefixedTime) in [(5, 9), (9, 5)] {
        var both = InkPage(pageId: page)
        both.deleted["plain"] = plainTime
        both.deleted[page + "|plain"] = prefixedTime
        if case .repaired(let fixedBoth, let s, let d) = SpanGuard.checkForSave(both) {
            check(fixedBoth.deleted == ["plain": 9] && s == [page + "|plain"] && d.isEmpty,
                  "span guard: plain@\(plainTime) and \(page)|plain@\(prefixedTime) give one tombstone at 9")
        } else {
            check(false, "span guard: plain@\(plainTime) and \(page)|plain@\(prefixedTime) are repaired")
        }
    }
}

// MARK: - SpanGuard: random pages (transfer ⇒ save, only the offending items change)

func spanGuardRandomChecks() {
    var rng = Rng(seed: 0x5BA9_6A2D_0013)
    let hosts = ["w-2026-11-02", "w-2026-11-01", "d-2026-11-02", "m1-2026-11", "y-2026"]
    let otherIds = ["wb-2026-11-02", "w-2026-11-03", "span~week~1", "w-2026-11-02|grid", "zz"]
    let longId = String(repeating: "L", count: 120)
    func name(_ host: String) -> String {
        switch rng.int(10) {
        case 0: return SpanName.prefixed(id: SpanFixtures.locals[rng.int(SpanFixtures.locals.count)], page: host)
        case 1: return SpanName.prefixed(id: "n\(rng.int(50))", page: SpanFixtures.pageIds[rng.int(SpanFixtures.pageIds.count)])
        case 2: return ["span~week~0", "span~a~\(rng.int(9))", "span~"][rng.int(3)]
        case 3: return ["abc|def", "|x", "x|", "photo|img", "w-2026|x"][rng.int(5)]
        case 4: return longId
        default: return SpanFixtures.realNames[rng.int(SpanFixtures.realNames.count)]
        }
    }
    var pages = 0
    var transferred = 0
    var repaired = 0
    var addedDrops = 0
    for round in 0..<400 {
        let host = round % 9 == 8 ? otherIds[rng.int(otherIds.count)] : hosts[rng.int(hosts.count)]
        var p = InkPage(v: 1 + rng.int(2), pageId: host, updatedAt: 1_790_000_000_000 + rng.int(1000))
        if rng.int(3) == 0 { p.unknown["later"] = .string("x\(rng.int(9))") }
        for i in 0..<rng.int(9) {
            let key = rng.int(4) == 0 ? "s\(i)-\(rng.int(99))" : name(host)
            guard InkStroke.isValidId(key) else { continue }
            let cell = rng.int(3) == 0 ? name(host) : ["grid", "extra", "memo", "01-20"][rng.int(4)]
            var stroke = SpanInk.stroke(key, cell: cell.isEmpty ? "grid" : cell, t: 1_790_000_000_000 + i,
                                        x: CGFloat(rng.int(200_000)) / 1 - 100_000, y: CGFloat(rng.int(9000)))
            if rng.int(6) == 0 { stroke.id = name(host) }
            p.strokes[key] = stroke
        }
        for i in 0..<rng.int(5) {
            let key = rng.int(3) == 0 ? "t\(i)" : name(host)
            if InkStroke.isValidId(key) { p.deleted[key] = 1_790_000_000_500 + i }
        }
        for i in 0..<rng.int(4) {
            let key = rng.int(3) == 0 ? "u\(i)" : name(host)
            guard InkStroke.isValidId(key) else { continue }
            p.unknownStrokes[key] = SpanInk.unknown(rng.int(5) == 0 ? name(host) : key, cell: rng.int(4) == 0 ? nil : (rng.int(2) == 0 ? name(host) : "grid"),
                                                     tool: ["photo", "text", "tape"][rng.int(3)], t: 1_790_000_000_700 + i)
        }
        pages += 1
        let addedPool = p.strokes.keys.sorted() + p.deleted.keys.sorted() + ["abc|def"]
        let added: Set<String> = rng.int(2) == 0 ? [] : Set((0..<rng.int(4)).map { _ in addedPool[rng.int(addedPool.count)] })

        // The expectations, item by item, from the regex (release).
        var expectStripped: Set<String> = []
        var expectDropped: Set<String> = []
        let writeForm = SpanInk.expectedWriteForm(host)
        func judge(_ key: String, _ names: [String], addedNames: [String]) {
            let verdicts = names.map { SpanInk.expected($0, pageId: host) }
            if verdicts.contains(.drop) { expectDropped.insert(key); return }
            let finals = zip(names, verdicts).map { name, v -> String in
                if case .strip(let rest) = v { return rest }
                return name
            }
            let isAdded = (addedNames + finals.prefix(2)).contains { added.contains($0) }
            if isAdded && finals.contains(where: { $0.contains("|") }) {
                addedDrops += 1
                expectDropped.insert(key)
                return
            }
            if verdicts.contains(where: { $0 != .keep }) { expectStripped.insert(key) }
        }
        for (key, s) in p.strokes { judge(key, [key, s.id, s.cell.raw], addedNames: [key, s.id]) }
        for key in p.deleted.keys { judge(key, [key], addedNames: [key]) }
        for (key, raw) in p.unknownStrokes {
            let names = [key] + [raw["id"]?.stringValue, raw["cell"]?.stringValue].compactMap { $0 }
            judge(key, names, addedNames: [key, raw["id"]?.stringValue ?? key])
        }

        let transfer = SpanGuard.checkForTransfer(p)
        let expectTransfer = !SpanInk.isWindowName(host) && !p.strokes.contains { SpanInk.isWindowName($0.key) || SpanInk.isWindowName($0.value.id) || SpanInk.isWindowName($0.value.cell.raw) }
            && !p.deleted.keys.contains(where: SpanInk.isWindowName)
            && !p.unknownStrokes.contains { SpanInk.isWindowName($0.key) || [$0.value["id"]?.stringValue, $0.value["cell"]?.stringValue].compactMap { $0 }.contains(where: SpanInk.isWindowName) }
        checkEqual(transfer, expectTransfer, "span guard random \(round): checkForTransfer (\(host))")
        let plain = SpanGuard.checkForSave(p)
        if transfer {
            transferred += 1
            if writeForm { checkEqual(plain, .ok, "span guard random \(round): what passes the transfer passes the save untouched") }
        }
        let result = SpanGuard.checkForSave(p, added: added)
        guard writeForm else {
            check(result == .refused && plain == .refused, "span guard random \(round): \(host) is refused (page id)")
            continue
        }
        switch result {
        case .refused:
            check(false, "span guard random \(round): a page of the write form is never refused")
        case .ok:
            check(expectStripped.isEmpty && expectDropped.isEmpty, "span guard random \(round): .ok only with nothing to repair")
        case .repaired(let fixed, let stripped, let dropped):
            repaired += 1
            checkEqual(Set(stripped), expectStripped, "span guard random \(round): the stripped items are the page's own prefixes")
            checkEqual(Set(dropped), expectDropped, "span guard random \(round): the dropped items are other pages', span~ and the added with |")
            check(SpanGuard.checkForSave(fixed, added: added) == .ok && SpanGuard.checkForTransfer(fixed),
                  "span guard random \(round): the repaired page saves as it is and goes out")
            check(fixed.pageId == p.pageId && fixed.v == p.v && fixed.updatedAt == p.updatedAt && fixed.unknown == p.unknown,
                  "span guard random \(round): the id, v, updatedAt and the unknown top-level items are kept")
            // Every other item is byte for byte the same (unless a stripped name landed on it).
            var landed: Set<String> = []
            for key in stripped {
                if let s = p.strokes[key] { landed.insert(SpanName.strip(id: key)); landed.insert(SpanName.strip(id: s.id)) }
                landed.insert(SpanName.strip(id: key))
            }
            let touched = Set(stripped).union(dropped).union(landed)
            let untouchedStrokes = Set(p.jsonValue["strokes"]?.objectValue?.keys.map { $0 } ?? []).subtracting(touched)
            check(untouchedStrokes.allSatisfy { SpanInk.strokeJSON(fixed, $0) == SpanInk.strokeJSON(p, $0) }
                  && Set(p.deleted.keys).subtracting(touched).allSatisfy { fixed.deleted[$0] == p.deleted[$0] },
                  "span guard random \(round): every item that was not repaired is byte for byte the same")
        }
    }
    check(pages >= 300 && transferred >= 50 && repaired >= 100 && addedDrops > 0,
          "span guard random: \(pages) pages (≥ 300), \(transferred) passed the transfer, \(repaired) repaired, \(addedDrops) drops of added ids with |")
}

// MARK: - SpanComposer: composing a window (§3.2, D4)

extension SpanInk {
    /// The real stroke of a window stroke, worked out apart from the composer: the prefix of the id and of
    /// the cell taken off, an alias looked up in the table.
    static func real(_ stroke: InkStroke, aliases: SpanAliases) -> (page: String, stroke: InkStroke)? {
        guard let owner = owner(of: stroke.id, aliases: aliases) else { return nil }
        var out = stroke
        out.id = owner.id
        out.cell = CellKey(raw: String(stroke.cell.raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).last ?? ""))
        return (owner.page, out)
    }

    /// (page, real id) of a window id: the alias table, else the text before and after the first "|".
    static func owner(of windowId: String, aliases: SpanAliases) -> (page: String, id: String)? {
        let parts = windowId.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], aliases.original(of: windowId) ?? parts[1])
    }

    static func page(_ id: String, _ strokes: [InkStroke] = [], deleted: [String: Int] = [:]) -> InkPage {
        var p = InkPage(pageId: id)
        for s in strokes { p.add(s) }
        for (k, t) in deleted.sorted(by: { $0.key < $1.key }) { p.remove(ids: [k], at: t) }
        return p
    }
}

func spanComposeChecks() {
    let plan = SpanFixtures.plan(.week)
    let a = "w-2026-11-02", b = "w-2026-11-09", c = "w-2026-11-16"
    let longId = "web-" + String(repeating: "q", count: 116)          // 120 bytes: "<page>|" + it is 133
    let longTomb = "web-" + String(repeating: "t", count: 116)
    let longUnknown = "txt-" + String(repeating: "u", count: 113)  // 117 bytes: "<page>|" + it is 130
    var pa = SpanInk.page(a, [SpanInk.stroke("shared-1", cell: "grid", t: 1_790_000_000_001, x: -300, y: 1880),
                              SpanInk.stroke(longId, cell: "grid", t: 1_790_000_000_002)],
                          deleted: ["gone-a": 1_790_000_000_003, longTomb: 1_790_000_000_004])
    pa.unknownStrokes["ph-1"] = SpanInk.unknown("ph-1", cell: "grid", t: 1_790_000_000_005)
    pa.unknownStrokes[longUnknown] = SpanInk.unknown(longUnknown, cell: "grid", tool: "text", t: 1_790_000_000_005)
    let bandPoints = (0..<5).map { SpanInk.point(10 + CGFloat($0) * 8, 14, $0) }
    let band = InkStroke(id: "band-1", cell: .allDay(DayKey(year: 2026, month: 11, day: 11)), tool: .pen, color: "#1f2937",
                         t: 1_790_000_000_006, dev: "kitchecks", points: bandPoints)
    let pb = SpanInk.page(b, [SpanInk.stroke("shared-1", cell: "grid", t: 1_790_000_000_007, x: 1600), band])
    let sunday = SpanInk.page("w-2026-11-08", [SpanInk.stroke("sun-1", cell: "grid", t: 1_790_000_000_008)])
    let dayPage = SpanInk.page("d-2026-11-02", [SpanInk.stroke("day-1", cell: "grid", t: 1_790_000_000_009)])
    let pa2 = SpanInk.page(a, [SpanInk.stroke("a-extra", cell: "grid", t: 1_790_000_000_010)])
    let v = SpanComposer.compose([pa, pb, sunday, dayPage, InkPage(pageId: c), pa2, InkPage(pageId: "span~week~0")], plan: plan, session: 3)

    checkEqual(v.pageId, "span~week~3", "span compose: the virtual id is span~week~<session>")
    checkEqual(v.pageIds, [a, b, c], "span compose: the window's real pages, left to right")
    checkEqual(v.skippedPageIds, ["w-2026-11-08", "d-2026-11-02", "span~week~0"],
               "span compose: a Sunday week in a Monday window, a day page and the virtual id are left out (K-11)")
    checkEqual(v.migratedPageIds, [b], "span compose: the page whose old band stroke moved is named (the screen saves it)")
    let ledger = v.ledgerPage
    check(ledger.strokes[a + "|shared-1"]?.points.first?.x == -300 && ledger.strokes[b + "|shared-1"]?.points.first?.x == 1600,
          "span compose: the same raw id on two pages is two strokes (K-2)")
    check(ledger.strokes[a + "|a-extra"] != nil, "span compose: a page given twice is merged into its first place")
    let movedBand = ledger.strokes[b + "|band-1"]
    check(movedBand?.cell.raw == b + "|grid" && movedBand?.points.first?.x == 455.7 && movedBand?.points.first?.y == 14,
          "span compose: BandMigration runs per page before composing (allday:2026-11-11 → grid, x0 455.7)")
    var late = InkPage(pageId: "span~week~3")
    late.strokes[b + "|band-1"] = InkStroke(id: b + "|band-1", cell: CellKey(raw: b + "|allday:2026-11-11"), tool: .pen,
                                            color: "#1f2937", t: 1, points: bandPoints)
    check(BandMigration.migrate(late) == late, "span compose: …it must: after composing, a prefixed band cell is no band cell (BandMigration.swift:17-19)")
    check(ledger.strokes.allSatisfy { SpanName.isPrefixed($0.key) && $0.key == $0.value.id && SpanName.isPrefixed($0.value.cell.raw) && InkStroke.isValidId($0.key) }
          && ledger.deleted.keys.allSatisfy { SpanName.isPrefixed($0) && InkStroke.isValidId($0) }
          && ledger.unknownStrokes.keys.allSatisfy { SpanName.isPrefixed($0) && InkStroke.isValidId($0) },
          "span compose: every stroke, cell, tombstone and unknown item has a window name of at most 128 bytes")
    checkEqual(ledger.deleted[a + "|gone-a"], 1_790_000_000_003, "span compose: a tombstone keeps its time under its window name")
    checkEqual(ledger.unknownStrokes[a + "|ph-1"], pa.unknownStrokes["ph-1"], "span compose: an unknown-tool item keeps its object as it was")
    check(ledger.v == 1 && ledger.unknown.isEmpty && ledger.updatedAt == max(pa.updatedAt, pb.updatedAt, pa2.updatedAt),
          "span compose: v, the unknown top-level items stay with the real pages (PageSlot)")

    // The aliases of the long ids (§3.2).
    let aliasId = v.aliases.alias(of: longId, page: a)
    let aliasTomb = v.aliases.alias(of: longTomb, page: a)
    check(aliasId != nil && aliasTomb != nil && aliasId != aliasTomb, "span compose: two long ids get two aliases")
    if let aliasId = aliasId, let aliasTomb = aliasTomb {
        check(SpanName.aliasNumber(aliasId)?.page == a && v.aliases.original(of: aliasId) == longId && ledger.strokes[aliasId]?.id == aliasId,
              "span compose: the long stroke id is \(aliasId) in the window, back to its id through the table")
        check(ledger.deleted[aliasTomb] == 1_790_000_000_004 && v.aliases.original(of: aliasTomb) == longTomb,
              "span compose: the long tombstone is \(aliasTomb) in the window")
        check(aliasId.utf8.count <= 128 && SpanName.isVirtual(SpanName.strip(id: aliasId)),
              "span compose: an alias fits 128 bytes and its stripped form starts with span~")
    }
    let pc = SpanInk.page(c, [SpanInk.stroke(longId, cell: "grid", t: 1_790_000_000_011)])
    let again = SpanComposer.compose([pa, pb, pc], plan: plan, session: 3, aliases: v.aliases)
    check(again.aliases.alias(of: longId, page: a) == aliasId && again.aliases.alias(of: longTomb, page: a) == aliasTomb,
          "span compose: a window composed again with the session's table keeps every alias")
    let aliasC = again.aliases.alias(of: longId, page: c)
    check(aliasC != nil && aliasC != aliasId && SpanName.aliasNumber(aliasC ?? "")?.number == v.aliases.next,
          "span compose: the same long id on another page gets the next number, not the same alias")
    let aliasUnknown = v.aliases.alias(of: longUnknown, page: a)
    check(aliasUnknown.map { ledger.unknownStrokes[$0] == pa.unknownStrokes[longUnknown] } == true,
          "span compose: a long unknown-tool key is aliased too, its object as it was")

    // The safety net's range of a page as read (§3.4 (c)): every tombstone on its real id (the long one back
    // from its alias) and every unknown-tool item as it was (the long key included).
    let range = SpanComposer.extract(pageId: a, from: v)
    check(range.deleted == ["gone-a": 1_790_000_000_003, longTomb: 1_790_000_000_004],
          "span compose: the range gives every tombstone back on its real id, the long one through its alias")
    check(range.unknownStrokes == pa.unknownStrokes && SpanInk.strokeJSON(range, longUnknown) == SpanInk.strokeJSON(pa, longUnknown),
          "span compose: the range gives every unknown-tool item back as it was, the long key through its alias")

    // A stored name that is itself virtual stays out of the window (only broken or foreign data has one),
    // so it can never be the alias a long id of the same page gets: a stored tombstone "span~a~1" does not
    // erase the long stroke whose alias is <page>|span~a~1, in the window nor through the safety net.
    let longL = String(repeating: "L", count: 120)
    var odd = SpanInk.page(a, [SpanInk.stroke(longL, cell: "grid", t: 1_790_000_000_020)])
    odd.deleted["span~a~1"] = 500
    odd.strokes["span~a~2"] = SpanInk.stroke("span~a~2", cell: "grid", t: 1_790_000_000_021)
    odd.unknownStrokes["span~a~3"] = SpanInk.unknown("span~a~3", cell: "grid", t: 1_790_000_000_022)
    let w = SpanComposer.compose([odd], plan: plan, session: 4)
    let aliasL = w.aliases.alias(of: longL, page: a)
    check(aliasL == SpanName.alias(page: a, number: 1) && w.ledgerPage.isLive(aliasL ?? "") && w.ledgerPage.deleted.isEmpty
          && w.ledgerPage.strokes.count == 1 && w.ledgerPage.unknownStrokes.isEmpty,
          "span compose: stored span~ names stay out of the window; the long id's alias \(aliasL ?? "-") is live")
    let back = InkPage.merge(odd, SpanComposer.extract(pageId: a, from: w))
    check(back.isLive(longL) && !back.contentDiffers(from: odd), "span compose: …and the safety net leaves that page as it was")
    if case .repaired(let fixedOdd, let s, let d) = SpanGuard.checkForSave(odd) {
        check(s.isEmpty && d == ["span~a~1", "span~a~2", "span~a~3"] && fixedOdd.isLive(longL), "span compose: …and the save guard drops the stored span~ names")
    } else {
        check(false, "span compose: the save guard drops the stored span~ names")
    }

    // The Kit reads only real page ids: the prototype composes its window with them and saves each page as
    // "proto-<id>" (§4.6 (a); SpanGuard's .prototype strips the real id's prefix on it).
    let protoIds = ["proto-w-2026-11-02", "proto-w-2026-11-09"]
    checkEqual(SpanComposer.compose(protoIds.map { InkPage(pageId: $0) }, plan: plan).skippedPageIds, protoIds,
               "span compose: a prototype page id is no page of a window (the prototype composes with the real ids)")
}

// MARK: - SpanComposer: journal → deltas → real page (§2.1, §3.4)

func spanDeltaChecks() {
    let plan = SpanFixtures.plan(.week)
    let a = "w-2026-11-02", b = "w-2026-11-09", c = "w-2026-11-16"
    let longId = "web-" + String(repeating: "q", count: 116)
    let pa = SpanInk.page(a, [SpanInk.stroke("shared-1", cell: "grid", t: 1_790_000_000_001), SpanInk.stroke(longId, cell: "grid", t: 1_790_000_000_002)])
    let pb = SpanInk.page(b, [SpanInk.stroke("shared-1", cell: "grid", t: 1_790_000_000_003)])
    let pc = InkPage(pageId: c)
    let v = SpanComposer.compose([pa, pb, pc], plan: plan, session: 1)
    guard let alias = v.aliases.alias(of: longId, page: a) else {
        check(false, "span delta: the long id has an alias")
        return
    }
    let group = UUID(uuidString: "6E6B0F3C-0A51-4D2B-9C1E-13A1C0DE0003")!
    let fresh = SpanInk.stroke(c + "|new-1", cell: c + "|grid", t: 1_790_000_001_000, x: -250)
    let bare = SpanInk.stroke("bare-1", cell: b + "|grid", t: 1_790_000_001_000)
    let virtualId = SpanInk.stroke("span~a~5", cell: b + "|grid", t: 1_790_000_001_000)
    let lost = SpanInk.stroke("lost-1", cell: "grid", t: 1_790_000_001_000)
    let entry = SpanJournalEntry(added: [fresh, bare, virtualId, lost],
                                 removed: [a + "|shared-1", alias, "zz-unknown", "span~a~9", b + "|span~a~77", a + "|"],
                                 at: 1_790_000_001_000, group: group)
    let deltas = SpanComposer.deltas(from: [entry], epoch: 4, aliases: v.aliases)
    var freshReal = fresh
    freshReal.id = "new-1"
    freshReal.cell = .grid
    checkEqual(deltas, [PageDelta(pageId: c, added: [freshReal], removed: [], at: 1_790_000_001_000, epoch: 4, group: group),
                        PageDelta(pageId: a, added: [], removed: ["shared-1", longId], at: 1_790_000_001_000, epoch: 4, group: group)],
               "span delta: one delta per page, the pages that get strokes first, real ids (an alias back to its id), nothing that tells no page")
    checkEqual(SpanComposer.unroutedNames(in: [entry], aliases: v.aliases),
               ["bare-1", "span~a~5", "lost-1", "zz-unknown", "span~a~9", b + "|span~a~77", a + "|"],
               "span delta: unroutedNames lists what the deltas left out, added and removed alike (an id made without ownerId, virtual names, an alias not in the table, an empty name)")
    let noTable = SpanComposer.deltas(from: [entry], epoch: 4, aliases: .empty)
    check(noTable.first { $0.pageId == a }?.removed == ["shared-1"] && SpanComposer.unroutedNames(in: [entry], aliases: .empty).contains(alias),
          "span delta: given an empty table by mistake, an alias is left out (never sent as span~…) and unroutedNames reports it")
    check(deltas.allSatisfy { d in d.added.allSatisfy { !SpanGuard.isWindowName($0.id) && !SpanGuard.isWindowName($0.cell.raw) } && d.removed.allSatisfy { !SpanGuard.isWindowName($0) } },
          "span delta: no delta holds a window name")
    // A move: the destination first (D8), one group.
    let move = SpanJournalEntry(added: [SpanInk.stroke(c + "|copy-1", cell: c + "|grid", t: 1_790_000_002_000)],
                                removed: [b + "|shared-1"], at: 1_790_000_002_000)
    checkEqual(SpanComposer.deltas(from: [move], epoch: 4, aliases: v.aliases).map(\.pageId), [c, b],
               "span delta: a move across pages gives the destination's delta before the source's")

    // apply: today's add / remove on the real page.
    let applied = SpanComposer.apply(deltas[0], to: pc)
    var direct = pc
    direct.add(freshReal)
    checkEqual(SpanInk.bytes(applied), SpanInk.bytes(direct), "span delta: apply is InkPage.add / remove on the page")
    checkEqual(SpanComposer.apply(deltas[0], to: applied), applied, "span delta: applying a delta twice changes nothing")
    checkEqual(SpanComposer.apply(deltas[0], to: pa), pa, "span delta: a delta of another page leaves the page alone")
    let removedA = SpanComposer.apply(deltas[1], to: pa)
    check(removedA.deleted["shared-1"] == 1_790_000_001_000 && removedA.deleted[longId] == 1_790_000_001_000 && removedA.strokes.isEmpty
          && removedA.updatedAt == 1_790_000_001_000,
          "span delta: the tombstones go on the real ids at the step's time (the long id included)")

    // An alias's erase whose delta never arrived: the safety net puts the tombstone on the long id, with its
    // time as the page's updatedAt (§3.2, §3.4 (c)).
    var erasedLong = v.ledgerPage
    erasedLong.remove(ids: [alias], at: 1_790_000_006_000)
    let net = InkPage.merge(pa, SpanComposer.extract(pageId: a, from: v.with(ledgerPage: erasedLong)))
    check(net.pageId == a && net.deleted[longId] == 1_790_000_006_000 && !net.isLive(longId) && net.isLive("shared-1") && net.updatedAt == 1_790_000_006_000,
          "span delta: an alias's erase whose delta was lost comes back on the long id through the safety net (and its time is the page's updatedAt)")

    // A stroke added and then erased (C1, DS-1). Routed by its name, both steps reach its page, by the deltas
    // and by the safety net; an id that is no window name (made with makeId, not ownerId, §3.3 1) reaches
    // it by neither, so the page never keeps a stroke the screen erased.
    for (label, id, routed) in [("an ownerId stroke", b + "|p-1", true), ("a stroke made without ownerId", "bare-2", false)] {
        let s = SpanInk.stroke(id, cell: b + "|grid", t: 1_790_000_003_000)
        var ledger = v.ledgerPage
        ledger.add(s)
        ledger.remove(ids: [id], at: 1_790_000_004_000)
        let journal = [SpanJournalEntry(added: [s], at: 1_790_000_003_000), SpanJournalEntry(removed: [id], at: 1_790_000_004_000)]
        let now = v.with(ledgerPage: ledger)
        let ds = SpanComposer.deltas(from: journal, epoch: 1, aliases: now.aliases)
        var real = pb
        for d in ds { real = SpanComposer.apply(d, to: real) }
        let rawId = SpanName.strip(id: id)
        let viaNet = InkPage.merge(pb, SpanComposer.extract(pageId: b, from: now))
        let afterBoth = InkPage.merge(real, SpanComposer.extract(pageId: b, from: now))
        check(!real.isLive(rawId) && !viaNet.isLive(rawId) && !afterBoth.isLive(rawId) && !ledger.isLive(id),
              "span delta: \(label) added and erased is not live on its page, by the deltas, by the safety net alone or by both")
        if routed {
            check(ds.count == 2 && real.deleted[rawId] == 1_790_000_004_000 && viaNet.deleted[rawId] == 1_790_000_004_000
                  && SpanComposer.unroutedNames(in: journal, aliases: now.aliases).isEmpty,
                  "span delta: \(label) is tombstoned on its page (as the page edited directly)")
        } else {
            check(ds.isEmpty && SpanInk.bytes(real) == SpanInk.bytes(pb) && SpanInk.bytes(afterBoth) == SpanInk.bytes(pb)
                  && SpanComposer.unroutedNames(in: journal, aliases: now.aliases) == [id, id],
                  "span delta: \(label) reaches its page neither added nor erased, and unroutedNames reports it twice")
        }
    }

    // Erase, ↶, erase again (DS-1): ↶ puts the stroke back as a copy with a new ownerId id, so the second
    // erase reaches the page too; every delta can be the one that is lost.
    var sim = SpanLedgerSim(virtual: v, seed: 0xC1D5_0001, firstTime: 1_790_000_005_000, dev: "kitchecks")
    let original = sim.page.strokes[a + "|shared-1"]!
    sim.erase([a + "|shared-1"])
    let undone = sim.undoCopy(original)
    if let copy = undone { sim.erase([copy.id]) }
    let steps = sim.takeJournal()
    let undoDeltas = SpanComposer.deltas(from: steps, epoch: 1, aliases: sim.virtual.aliases)
    var expected = pa
    if let copy = undone {
        expected.remove(ids: ["shared-1"], at: 1_790_000_005_000)
        var copyReal = copy
        copyReal.id = SpanName.strip(id: copy.id)
        copyReal.cell = .grid
        expected.add(copyReal)
        expected.remove(ids: [copyReal.id], at: 1_790_000_005_002)
    }
    var undoPage = pa
    for d in undoDeltas { undoPage = SpanComposer.apply(d, to: undoPage) }
    check(undone.map { SpanName.isPrefixed($0.id) } == true && undoDeltas.count == 3 && SpanComposer.unroutedNames(in: steps, aliases: sim.virtual.aliases).isEmpty
          && SpanInk.bytes(undoPage) == SpanInk.bytes(expected) && undoPage.liveStrokes.map(\.id) == [longId],
          "span delta: erase, ↶ (a copy with an ownerId id), erase: the page is the page edited directly, nothing of the stroke is live")
    for k in undoDeltas.indices {
        var partial = pa
        for (i, d) in undoDeltas.enumerated() where i != k { partial = SpanComposer.apply(d, to: partial) }
        partial = InkPage.merge(partial, SpanComposer.extract(pageId: a, from: sim.current))
        check(SpanInk.bytes(partial) == SpanInk.bytes(expected), "span delta: erase, ↶, erase without delta \(k): the safety net gives the same page")
    }
    // The same with a ↶ copy made without ownerId: the copy and its erase reach no page, and the page composed
    // again shows nothing of it (an erased stroke never comes back).
    let bareCopy = SpanInk.stroke("u-raw-1", cell: a + "|grid", t: original.t)
    let bareSteps = [SpanJournalEntry(removed: [a + "|shared-1"], at: 1_790_000_005_000), SpanJournalEntry(added: [bareCopy], at: 1_790_000_005_001),
                     SpanJournalEntry(removed: ["u-raw-1"], at: 1_790_000_005_002)]
    var barePage = pa
    for d in SpanComposer.deltas(from: bareSteps, epoch: 1, aliases: v.aliases) { barePage = SpanComposer.apply(d, to: barePage) }
    let again = SpanComposer.compose([barePage, pb, pc], plan: plan, session: 1, aliases: v.aliases)
    check(barePage.liveStrokes.map(\.id) == [longId] && barePage.deleted["u-raw-1"] == nil
          && !again.ledgerPage.strokes.keys.contains { $0.hasSuffix("u-raw-1") }
          && SpanComposer.unroutedNames(in: bareSteps, aliases: v.aliases) == ["u-raw-1", "u-raw-1"],
          "span delta: erase, ↶ with a copy made without ownerId, erase: the copy never reaches the page, so it does not come back when the window is composed again")
}

// MARK: - SpanComposer: the safety net keeps the real page id (§3.3, §3.4 (c))

func spanSafetyNetChecks() {
    for kind in [PageKind.week, .year] {
        let plan = SpanFixtures.plan(kind)
        let focus = kind == .week ? "w-2026-11-09" : "y-2026"
        guard let n = plan.index(of: focus) else { continue }
        let ids = [plan.pageId(at: n - 1), focus, plan.pageId(at: n + 1)]
        var slot = SpanInk.page(focus, [SpanInk.stroke("s-1", cell: kind == .week ? "grid" : "01-20", t: 1_790_000_000_001)])
        slot.v = 2
        slot.unknown["later"] = .object(["k": .string("v")])
        let v = SpanComposer.compose(ids.map { $0 == focus ? slot : InkPage(pageId: $0) }, plan: plan, session: 2)
        var sim = SpanLedgerSim(virtual: v, seed: 0x5AFE_0001, firstTime: 1_790_000_100_000, dev: "kitchecks")
        let added = sim.put(cell: CellKey(raw: focus + "|" + (kind == .week ? "grid" : "12-31")), points: [SpanInk.point(5, 5), SpanInk.point(9, 9, 1)])
        sim.erase([focus + "|s-1"])
        let range = SpanComposer.extract(pageId: focus, from: sim.current)
        checkEqual(range.pageId, focus, "span safety net (\(kind)): the range of \(focus) has the real id")
        check(range.v == 2 && range.strokes.keys.sorted() == [SpanName.strip(id: added.id)] && range.deleted["s-1"] != nil,
              "span safety net (\(kind)): the range holds the page's strokes and tombstones with real ids, and its v")
        let merged = InkPage.merge(slot, range)
        check(merged.pageId == focus && merged.v == 2 && merged.unknown == slot.unknown,
              "span safety net (\(kind)): merging the range keeps the id, v and the unknown top-level items")
        // What extract must never do: a range named with the virtual id would turn the page into span~…
        checkEqual(InkPage.merge(slot, InkPage(pageId: sim.current.pageId)).pageId, sim.current.pageId,
                   "span safety net (\(kind)): (why) InkPage.merge keeps the smaller id, so span~… would win over \(focus)")
        for other in [sim.current.pageId, "w-2030-01-07", "", SpanName.prefixed(id: "x", page: focus)] {
            let none = SpanComposer.extract(pageId: other, from: sim.current)
            check(none == InkPage(pageId: "") && InkPage.merge(slot, none) == slot,
                  "span safety net (\(kind)): extract of \(other.debugDescription) (not a page of the window) is empty with the neutral id \"\"")
        }
    }
}

// MARK: - Points outside the paper are never cut or dropped (§4.1)

func spanOffPaperChecks() {
    let plan = SpanFixtures.plan(.day)
    let page = "d-2026-11-03"
    let far: [InkPoint] = [SpanInk.point(-99_999, 99_999), SpanInk.point(99_999, -99_999, 1), SpanInk.point(-0.1, 8400.1, 2), SpanInk.point(1300, 2500, 3)]
    let original = InkStroke(id: "far-1", cell: .extra, tool: .marker, color: "#fde047", t: 1_790_000_000_001, points: far)
    let slot = SpanInk.page(page, [original])
    check(slot.strokes["far-1"]?.points == far, "span off paper: the page keeps points within ±100,000 lu (InkPoint)")
    let v = SpanComposer.compose([InkPage(pageId: "d-2026-11-02"), slot, InkPage(pageId: "d-2026-11-04")], plan: plan)
    check(v.ledgerPage.strokes[page + "|far-1"]?.points == far, "span off paper: compose keeps every point")
    var sim = SpanLedgerSim(virtual: v, seed: 0x0FF0_0001, firstTime: 1_790_000_100_000, dev: "kitchecks")
    let copy = sim.put(cell: CellKey(raw: "d-2026-11-04|grid"), points: far)
    let deltas = SpanComposer.deltas(from: sim.takeJournal(), epoch: 0, aliases: v.aliases)
    check(deltas.count == 1 && deltas[0].added.first?.points == far, "span off paper: a delta keeps every point")
    let applied = SpanComposer.apply(deltas[0], to: InkPage(pageId: "d-2026-11-04"))
    check(applied.strokes[SpanName.strip(id: copy.id)]?.points == far, "span off paper: apply keeps every point")
    check(SpanComposer.extract(pageId: page, from: sim.current).strokes["far-1"]?.points == far
          && SpanComposer.extract(pageId: "d-2026-11-04", from: sim.current).strokes[SpanName.strip(id: copy.id)]?.points == far,
          "span off paper: extract keeps every point")
    checkEqual(SpanGuard.checkForSave(applied, added: [SpanName.strip(id: copy.id)]), .ok, "span off paper: the guard does not look at points")
}

// MARK: - The PDF's neighbour ink (D17)

func spanPDFInkChecks() {
    let plan = SpanFixtures.plan(.day)
    let days = [DayKey(year: 2026, month: 11, day: 2), DayKey(year: 2026, month: 11, day: 3), DayKey(year: 2026, month: 11, day: 4)]
    let layout = SpanFixtures.window(SpanFixtures.dayPages(days, events: [], now: date(2026, 11, 3, 12)), plan: plan)
    let v = SpanComposer.compose(days.map { InkPage(pageId: "d-" + $0.description) }, plan: plan)
    var sim = SpanLedgerSim(virtual: v, layout: layout, seed: 0x9DF0_0001, firstTime: 1_790_000_100_000, dev: "kitchecks")
    let line = { (x0: CGFloat, x1: CGFloat, y: CGFloat) in [CGPoint(x: x0, y: y), CGPoint(x: (x0 + x1) / 2, y: y + 4), CGPoint(x: x1, y: y)] }
    let intoNext = sim.draw(line(1690, 2300, 1000))        // centre 1995: d-11-03 (local 995), reaches d-11-04 by 300
    let intoPrevious = sim.draw(line(900, 1400, 3000))     // centre 1150: d-11-03's extra, reaches d-11-02 by 100
    let inside = sim.draw(line(1200, 1500, 1200))          // inside d-11-03
    let own = sim.draw(line(1900, 2400, 900))              // centre 2150: d-11-04 (local 150), reaches d-11-03 by 100
    // Two strokes whose bounds (points ± half the size 4) only touch the boundary x 2000: they reach
    // into no other page (the page's own strokes are drawn by the page, a neighbour's only when it enters).
    let touchesNext = sim.draw(line(1500, 1998, 1600), size: 4)   // d-11-03, bounds' right edge exactly 2000
    let touchesBack = sim.draw(line(2002, 2500, 1700), size: 4)   // d-11-04, bounds' left edge exactly 2000
    check(intoNext != nil && intoPrevious != nil && inside != nil && own != nil && touchesNext != nil && touchesBack != nil,
          "span pdf: the six strokes are kept")
    guard let a = intoNext, let b = intoPrevious, let o = own else { return }
    let next = SpanComposer.neighborInk(for: "d-2026-11-04", from: sim.current, layout: layout)
    var aReal = a
    aReal.id = SpanName.strip(id: a.id)
    aReal.cell = .grid
    checkEqual(next, [SpanPDFInk(pageId: "d-2026-11-03", stroke: aReal, cellRect: CGRect(x: -1000, y: 0, width: 1000, height: 2400))],
               "span pdf: d-11-04's PDF gets d-11-03's stroke that reaches into it, with the real id and the cell moved by −1000 (not the one that only touches the edge)")
    let previous = SpanComposer.neighborInk(for: "d-2026-11-02", from: sim.current, layout: layout)
    check(previous.count == 1 && previous[0].stroke.id == SpanName.strip(id: b.id) && previous[0].stroke.cell == .extra
          && previous[0].cellRect == CGRect(x: 1000, y: 2400, width: 1000, height: 6000),
          "span pdf: d-11-02's PDF gets d-11-03's extra stroke that reaches into it, the cell moved by +1000")
    let middle = SpanComposer.neighborInk(for: "d-2026-11-03", from: sim.current, layout: layout)
    check(middle.count == 1 && middle[0].stroke.id == SpanName.strip(id: o.id) && middle.allSatisfy { !SpanGuard.isWindowName($0.stroke.id) && !SpanGuard.isWindowName($0.stroke.cell.raw) },
          "span pdf: d-11-03's PDF gets only d-11-04's stroke that reaches back into it (its own strokes are the page's, one that only touches the edge is not)")
    check(SpanComposer.neighborInk(for: "d-2026-11-09", from: sim.current, layout: layout).isEmpty, "span pdf: a page outside the window gets nothing")
}

// MARK: - SpanComposer and PageDelta: random edits (§10.1: ≥ 300 edits, JSON equality)

func spanComposerRandomChecks(_ kind: PageKind, seed: UInt64) {
    var rng = Rng(seed: seed)
    let plan = SpanFixtures.plan(kind)
    guard let focus = plan.index(of: kind == .week ? "w-2026-11-16" : "d-2026-11-16") else { return }
    let pageIds = ((focus - 3)...(focus + 3)).map { plan.pageId(at: $0) }
    let targets = Array(pageIds[1...5])           // the edits never touch the two end pages
    let cells = kind == .week ? ["grid"] : ["grid", "extra"]
    let width = ZoomPolicy.paperWidth(kind)
    var ids = CompatFixtures.SeededIds(seed: seed ^ 0xA5A5)
    func points(_ count: Int) -> [InkPoint] {
        (0..<count).map { i in
            switch rng.int(8) {
            case 0: return SpanInk.point(CGFloat(rng.int(400)) - 400, CGFloat(rng.int(9000)), i)              // left of the page
            case 1: return SpanInk.point(width + CGFloat(rng.int(400)), CGFloat(rng.int(9000)), i)           // right of it
            case 2: return SpanInk.point(CGFloat(rng.int(199_998)) - 99_999, CGFloat(rng.int(199_998)) - 99_999, i)
            default: return SpanInk.point(CGFloat(rng.int(Int(width * 10))) / 10, CGFloat(rng.int(24000)) / 10, i)
            }
        }
    }
    var t = 1_790_200_000_000
    func next() -> Int { t += 1; return t }

    // The pages as read: strokes of every kind of id, tombstones, unknown tools, a band stroke, v 2.
    var originals: [InkPage] = []
    for (i, pageId) in pageIds.enumerated() {
        var p = InkPage(pageId: pageId)
        for j in 0..<(3 + rng.int(6)) {
            let id: String
            switch j == 0 ? 0 : rng.int(8) {
            case 0: id = "long-\(i)-\(j)-" + String(repeating: "x", count: 100 + rng.int(16))
            case 1: id = "web\(i)\(j)~w1"
            case 2: id = "old|\(i)-\(j)"
            default: id = ids.next()
            }
            p.add(InkStroke(id: id, cell: CellKey(raw: cells[rng.int(cells.count)]), tool: rng.int(4) == 0 ? .marker : .pen,
                            color: "#1f2937", t: next(), dev: "kitchecks", points: points(2 + rng.int(4))))
        }
        if i == 2 || i == 4 {
            p.add(InkStroke(id: "shared-raw-1", cell: .grid, tool: .pen, color: "#2563eb", t: next(), points: points(3)))
        }
        for _ in 0..<rng.int(3) { p.remove(ids: [rng.int(2) == 0 ? ids.next() : "long-tomb-\(i)-" + String(repeating: "y", count: 110)], at: next()) }
        if rng.int(2) == 0 || i == 3 {
            p.unknownStrokes["photo-\(i)"] = SpanInk.unknown("photo-\(i)", cell: "grid", tool: "photo", t: next())
            p.unknownStrokes["text-\(i)"] = SpanInk.unknown("text-\(i)", cell: "grid", tool: "text", t: next())
        }
        if i == 3 {
            p.v = 2
            p.unknown["later"] = .object(["n": .number(3)])
        }
        if i == 4 {
            let cell: CellKey = kind == .week ? .allDay(plan.firstDay(at: focus + 1).adding(days: 2)) : .allDayDay
            p.add(InkStroke(id: "band-\(i)", cell: cell, tool: .pen, color: "#1f2937", t: next(), points: points(3)))
        }
        originals.append(p)
    }

    let v = SpanComposer.compose(originals, plan: plan, session: 7)
    var sim = SpanLedgerSim(virtual: v, seed: seed ^ 0x5151, firstTime: t + 1000, dev: "kitchecks")
    var direct: [String: InkPage] = [:]
    for p in originals { direct[p.pageId] = BandMigration.migrate(p) }
    let slots = direct
    var erased: [InkStroke] = []
    var edits = 0
    var crossMoves = 0
    var aliasErases = 0
    func liveIds() -> [String] { sim.page.strokes.keys.filter { sim.page.isLive($0) }.sorted() }
    func addDirect(_ stroke: InkStroke) {
        guard let r = SpanInk.real(stroke, aliases: sim.virtual.aliases) else { return }
        direct[r.page]?.add(r.stroke)
    }
    func removeDirect(_ windowIds: [String], at time: Int) {
        for id in windowIds {
            guard let owner = SpanInk.owner(of: id, aliases: sim.virtual.aliases) else { continue }
            if owner.id.utf8.count > 100 { aliasErases += 1 }
            direct[owner.page]?.remove(ids: [owner.id], at: time)
        }
    }

    // One erase of a long (aliased) id for sure, then random steps.
    if let long = liveIds().first(where: { id in SpanInk.owner(of: id, aliases: sim.virtual.aliases).map { $0.id.hasPrefix("long-") && targets.contains($0.page) } == true }) {
        removeDirect(sim.erase([long]), at: sim.clock)
        edits += 1
    }
    for _ in 0..<440 {
        let live = liveIds()
        switch rng.int(10) {
        case 0, 1, 2, 3:
            let page = targets[rng.int(targets.count)]
            let s = sim.put(cell: CellKey(raw: page + "|" + cells[rng.int(cells.count)]), points: points(2 + rng.int(4)),
                            tool: rng.int(5) == 0 ? .marker : .pen, color: ["#1f2937", "#dc2626"][rng.int(2)])
            addDirect(s)
            edits += 1
        case 4, 5:
            guard !live.isEmpty else { continue }
            let id = live[rng.int(live.count)]
            guard SpanInk.owner(of: id, aliases: sim.virtual.aliases).map({ targets.contains($0.page) }) == true else { continue }
            let before = sim.page.strokes[id]!
            let gone = sim.erase([id])
            removeDirect(gone, at: sim.clock)
            if !gone.isEmpty { erased.append(before); edits += 1 }
        case 6:
            guard !live.isEmpty else { continue }
            let id = live[rng.int(live.count)]
            guard let from = SpanInk.owner(of: id, aliases: sim.virtual.aliases), targets.contains(from.page) else { continue }
            let to = targets[rng.int(targets.count)]
            let copies = sim.move([id], toCell: CellKey(raw: to + "|" + cells[rng.int(cells.count)]))
            removeDirect([id], at: sim.clock)
            copies.forEach(addDirect)
            if !copies.isEmpty { edits += 1; if to != from.page { crossMoves += 1 } }
        case 7:
            guard !erased.isEmpty else { continue }
            if let copy = sim.undoCopy(erased[rng.int(erased.count)]) { addDirect(copy); edits += 1 }
        case 8:
            let all = sim.page.strokes.keys.sorted() + sim.page.deleted.keys.sorted()
            guard all.count > 1 else { continue }
            let pick = [all[rng.int(all.count)], all[rng.int(all.count)]]
            guard pick.allSatisfy({ SpanInk.owner(of: $0, aliases: sim.virtual.aliases).map { targets.contains($0.page) } == true }) else { continue }
            let gone = sim.erase(pick)
            removeDirect(gone, at: sim.clock)
            if !gone.isEmpty { edits += 1 }
        default:
            check(sim.erase([targets[rng.int(targets.count)] + "|not-there"]).isEmpty, "span random \(kind): erasing an id that is not live journals nothing")
        }
    }

    let journal = sim.takeJournal()
    let deltas = SpanComposer.deltas(from: journal, epoch: 7, aliases: sim.virtual.aliases)
    print("   span random \(kind): \(edits) edits, \(crossMoves) moves across pages, \(aliasErases) erases of aliased ids, \(journal.count) journal steps, \(deltas.count) deltas")
    check(edits >= 300 && crossMoves >= 5 && aliasErases >= 1,
          "span random \(kind): \(edits) edits (≥ 300), \(crossMoves) moves across pages, \(aliasErases) erases of long (aliased) ids")
    check(deltas.allSatisfy { $0.epoch == 7 && targets.contains($0.pageId) }, "span random \(kind): every delta is of a page that was edited, with the session's number")
    check(SpanComposer.unroutedNames(in: journal, aliases: sim.virtual.aliases).isEmpty,
          "span random \(kind): every name of the journal tells its page (the ledger makes every id with ownerId, §3.3 1)")
    check(deltas.allSatisfy { d in d.added.allSatisfy { !SpanGuard.isWindowName($0.id) && !SpanGuard.isWindowName($0.cell.raw) && InkStroke.isValidId($0.id) } && d.removed.allSatisfy { !SpanGuard.isWindowName($0) && InkStroke.isValidId($0) } },
          "span random \(kind): no window name reaches a delta")

    func applyAll(_ list: [PageDelta]) -> [String: InkPage] {
        var out = slots
        for d in list { if let p = out[d.pageId] { out[d.pageId] = SpanComposer.apply(d, to: p) } }
        return out
    }
    func same(_ a: [String: InkPage], _ b: [String: InkPage]) -> Bool {
        pageIds.allSatisfy { SpanInk.bytes(a[$0]!) == SpanInk.bytes(b[$0]!) }
    }
    let applied = applyAll(deltas)
    for pageId in pageIds {
        checkEqual(SpanInk.bytes(applied[pageId]!), SpanInk.bytes(direct[pageId]!), "span random \(kind): \(pageId) with the deltas is the page edited directly (JSON)")
    }
    for round in 0..<3 {
        var shuffled = deltas
        for i in stride(from: shuffled.count - 1, to: 0, by: -1) { shuffled.swapAt(i, rng.int(i + 1)) }
        check(same(applyAll(shuffled), direct), "span random \(kind): the deltas in another order give the same pages (round \(round))")
    }
    check(same(applyAll(deltas + deltas), direct) && same(applyAll(deltas.flatMap { [$0, $0] }), direct),
          "span random \(kind): every delta applied twice gives the same pages")
    let current = sim.current
    for pageId in pageIds {
        let merged = InkPage.merge(applied[pageId]!, SpanComposer.extract(pageId: pageId, from: current))
        check(SpanInk.bytes(merged) == SpanInk.bytes(applied[pageId]!) && !merged.contentDiffers(from: applied[pageId]!),
              "span random \(kind): with nothing missing the safety net changes nothing on \(pageId)")
    }
    // Every delta in turn is the one that is lost (§10.1; among them the erases of aliased ids).
    for k in deltas.indices {
        var partial = applyAll(deltas.enumerated().filter { $0.offset != k }.map(\.element))
        let pageId = deltas[k].pageId
        partial[pageId] = InkPage.merge(partial[pageId]!, SpanComposer.extract(pageId: pageId, from: current))
        check(same(partial, direct), "span random \(kind): without delta \(k) the safety net's merge gives the same pages (JSON)")
    }
    for end in [pageIds[0], pageIds[6]] {
        check(!deltas.contains { $0.pageId == end } && SpanInk.bytes(applied[end]!) == SpanInk.bytes(originals.first { $0.pageId == end }!),
              "span random \(kind): the untouched page \(end) is byte for byte as it was read")
    }
    for pageId in targets {
        let page = applied[pageId]!
        let addedIds = Set(deltas.filter { $0.pageId == pageId }.flatMap { $0.added.map(\.id) })
        checkEqual(SpanGuard.checkForSave(page, added: addedIds), .ok, "span random \(kind): \(pageId) saves as it is")
        let original = originals.first { $0.pageId == pageId }!
        check(original.unknownStrokes.keys.allSatisfy { SpanInk.strokeJSON(page, $0) == SpanInk.strokeJSON(original, $0) }
              && page.v == original.v && page.unknown == original.unknown,
              "span random \(kind): \(pageId)'s unknown-tool items, v and unknown top-level items are byte for byte as read")
    }
    let shared = pageIds[2...4].filter { pageId in pageId != pageIds[3] }
    check(shared.allSatisfy { applied[$0]!.strokes["shared-raw-1"] != nil || applied[$0]!.deleted["shared-raw-1"] != nil }
          && (applied[shared[0]]!.isLive("shared-raw-1") == direct[shared[0]]!.isLive("shared-raw-1")),
          "span random \(kind): the same raw id on two pages stays two strokes (each page has its own)")
    let outside = pageIds.reduce(0) { n, id in
        n + applied[id]!.liveStrokes.filter { $0.points.contains { $0.x < 0 || $0.x > width } }.count
    }
    check(outside >= 10, "span random \(kind): \(outside) strokes with points outside their page are kept (§4.1)")
}

// MARK: - The compat-span fixtures (§4.2, §6.3, K-7)

func spanCompatFixtureChecks() {
    let fm = FileManager.default
    let folder = CompatSpanFixtures.committedFolder
    let made = CompatSpanFixtures.made
    typealias F = CompatSpanFixtures

    // MANIFEST and the files, byte for byte what the Kit's joined path writes.
    let manifest = try? Data(contentsOf: folder.appendingPathComponent(F.manifestName))
    checkEqual(manifest, F.manifestData(), "compat-span: MANIFEST is what the maker writes (KitChecks --write-compat-span-fixtures)")
    let listed = manifest.flatMap(F.parseManifest) ?? []
    checkEqual(listed, F.entries, "compat-span: MANIFEST lists every file with its fixture number and shape")
    checkEqual(Set(listed.map(\.fixture)), [1, 2, 3, 5, 6, 7], "compat-span: fixtures 1–3 and 5–7 (4 belongs to the week memo, §5)")
    checkEqual(listed.filter { $0.shape == .sunday }.map(\.name), [F.sundayOverhang], "compat-span: only the Sunday-start week is of shape sunday")
    let onDisk = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".json") }.sorted()
    checkEqual(onDisk, listed.map(\.name).sorted(), "compat-span: every *.json of the folder is in MANIFEST, and every listed file is there")
    for (name, data) in made.files {
        check((try? Data(contentsOf: folder.appendingPathComponent(name))) == data, "compat-span: \(name) is what the joined path of the Kit writes")
    }
    check(made.recovered.isEmpty && made.deltaCount == 22, "compat-span: \(made.deltaCount) deltas made the files; the safety net had nothing to bring back")

    // Each file as 1.3 reads it.
    var pages: [String: InkPage] = [:]
    var files: [String: Data] = [:]
    for e in listed {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(e.name)), let page = try? InkPageCodec.decode(data) else {
            check(false, "compat-span: \(e.name) reads")
            continue
        }
        pages[e.name] = page
        files[e.name] = data
        check((try? InkPageCodec.encode(page)) == data, "compat-span: \(e.name) is read and written back unchanged")
        check(SpanGuard.checkForSave(page) == .ok && SpanGuard.checkForTransfer(page), "compat-span: \(e.name) has no window name (saves and goes out as it is)")
        check(e.name.hasPrefix(page.pageId + ".") && page.v == 1 && page.unknown.isEmpty,
              "compat-span: \(e.name) holds \(page.pageId), v 1 and no new top-level item (K-5)")
        check(page.strokes.values.allSatisfy { !$0.id.contains("|") && !$0.cell.raw.contains("|") && !$0.cell.raw.contains("~") && $0.dev == F.device }
              && !page.pageId.contains("|") && !page.pageId.contains("~"),
              "compat-span: \(e.name) the strokes 1.3 wrote have no | in their ids and cells, no ~ in their cells (K-10)")
        let sunday = page.pageId.hasPrefix("w-") && SpanInk.expectedWriteForm(page.pageId)
            && SpanFixtures.utc.component(.weekday, from: SpanFixtures.utc.date(from: DateComponents(year: Int(page.pageId.dropFirst(2).prefix(4)), month: Int(page.pageId.dropFirst(7).prefix(2)), day: Int(page.pageId.suffix(2))))!) == 1
        checkEqual(e.shape == .sunday, sunday, "compat-span: \(e.name) is of shape \(e.shape.rawValue)")
    }

    // What each file holds (cell, the stroke's x from … to, cell-relative): the strokes reach out of their
    // page and nothing was cut (§4.1, §4.2).
    let expected: [(String, [(String, CGFloat, CGFloat)], Int, Int)] = [
        (F.weekOverhang, [("grid", -300, 500)], 0, 0),
        (F.dayOverhang, [("extra", 690, 1300), ("grid", 690, 1300)], 0, 0),
        (F.monthOverhang, [("2026-11-08", -60, 450), ("memo", 1140, 1650)], 0, 0),
        (F.yearOverhang, [("01-20", -156, 204), ("12-20", -188, 400)], 0, 0),
        (F.moveSource, [("grid", 700, 900)], 1, 0),
        (F.moveDestination, [("grid", 300, 500)], 0, 0),
        (F.extraCrossLeft, [("extra", 600, 1300)], 0, 0),
        (F.extraCrossRight, [("extra", -300, 600)], 0, 0),
        (F.sundayOverhang, [("grid", -300, 500), ("grid", 900, 1700)], 0, 0),
        (F.overlapNovember, [("2026-11-30", 30, 130), ("2026-12-01", 30, 130)], 0, 0),
        (F.overlapDecember, [("2026-11-30", 30, 130), ("2026-12-01", 30, 130)], 0, 0),
        (F.photoText, [("grid", 900, 1700)], 1, 2),
        (F.photoTextNeighbor, [("grid", 300, 600)], 0, 1),
    ]
    for (name, strokes, tombstones, unknown) in expected {
        guard let page = pages[name] else { continue }
        let got = page.liveStrokes.map { s in (s.cell.raw, s.points.map(\.x).min() ?? 0, s.points.map(\.x).max() ?? 0) }
            .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
        check(got.count == strokes.count && zip(got, strokes).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 && $0.2 == $1.2 }
              && page.deleted.count == tombstones && page.unknownStrokes.count == unknown,
              "compat-span: \(name) holds \(strokes.map { "\($0.0) x \($0.1)…\($0.2)" }.joined(separator: ", ")), \(tombstones) tombstone(s), \(unknown) unknown item(s) (got \(got))")
    }
    if let source = pages[F.moveSource], let destination = pages[F.moveDestination], let copy = destination.liveStrokes.first,
       let tombstone = source.deleted.first {
        check(tombstone.key != copy.id && source.strokes[tombstone.key] == nil && tombstone.value == copy.t && destination.deleted.isEmpty,
              "compat-span: the move left a tombstone on the source and a copy with a new id (written at the move's time) on the destination (K-2)")
    }
    if let november = pages[F.overlapNovember], let december = pages[F.overlapDecember] {
        check(Set(november.strokes.keys).isDisjoint(with: december.strokes.keys)
              && november.liveStrokes.contains { $0.cell.raw == "2026-12-01" } && december.liveStrokes.contains { $0.cell.raw == "2026-12-01" },
              "compat-span: the shared day 2026-12-01 has its own stroke on each month page (two cells, two ids)")
    }

    // Fixture 7: the hand-written photo and text items come out byte for byte, the session's ink around them.
    if let photo = pages[F.photoText], let neighbor = pages[F.photoTextNeighbor],
       let hand = made.handWritten["w-2026-11-30"].flatMap({ try? JSONValue.parse($0) }),
       let handNeighbor = made.handWritten["w-2026-12-07"].flatMap({ try? JSONValue.parse($0) }) {
        for id in [F.photoId, F.textId] {
            checkEqual(SpanInk.strokeJSON(photo, id), hand["strokes"]?[id]?.serialized(), "compat-span: the \(id == F.photoId ? "photo" : "text") item is byte for byte as written (fixture 7)")
        }
        checkEqual(SpanInk.strokeJSON(neighbor, F.neighborPhotoId), handNeighbor["strokes"]?[F.neighborPhotoId]?.serialized(),
                   "compat-span: the neighbour's photo item is byte for byte as written, through the guard's repair (fixture 7)")
        check(photo.deleted.keys.sorted() == [F.handPenId] && photo.liveStrokes.allSatisfy { hand["strokes"]?[$0.id] == nil }
              && neighbor.liveStrokes.allSatisfy { handNeighbor["strokes"]?[$0.id] == nil },
              "compat-span: fixture 7 is not hand-written JSON alone: the hand-written pen stroke is erased, the strokes are the session's")
        check(photo.unknownStrokes.values.contains { $0["text"]?.stringValue == "牛乳を買う" && $0["rect"]?.arrayValue?.first?.doubleValue == 1250 }
              && neighbor.unknownStrokes.values.contains { $0["rect"]?.arrayValue?.first?.doubleValue == -80 },
              "compat-span: the items' rects (one past the right edge, one left of the page) are untouched")
    }
    for e in listed where e.name != F.photoTextNeighbor {
        checkEqual(made.saves[e.name], .ok, "compat-span: \(e.name) was saved as it was (the guard found nothing)")
    }
    if case .repaired(_, let stripped, let dropped)? = made.saves[F.photoTextNeighbor] {
        check(stripped.count == 2 && stripped.contains("w-2026-12-07|" + F.neighborPhotoId) && stripped.allSatisfy { $0.hasPrefix("w-2026-12-07|") }
              && dropped.count == 2 && dropped.contains("span~a~1") && dropped.contains { $0.hasPrefix("w-2026-11-30|") }
              && files[F.photoTextNeighbor] == made.neighborBeforeLeak,
              "compat-span: the neighbour's leak (its own prefix twice, another page's stroke, a stripped alias) was repaired back to the clean page")
    } else {
        check(false, "compat-span: the neighbour's leak was repaired, not saved as it was nor refused")
    }

    // The frozen 1.0 copy, file by file (§6.3): what 1.0 reads, draws, lassoes and writes back.
    let drawnBy10: [String: Int] = [F.weekOverhang: 1, F.dayOverhang: 1, F.monthOverhang: 2, F.yearOverhang: 2, F.moveSource: 1,
                                    F.moveDestination: 1, F.extraCrossLeft: 0, F.extraCrossRight: 0, F.sundayOverhang: 2,
                                    F.overlapNovember: 2, F.overlapDecember: 2, F.photoText: 1, F.photoTextNeighbor: 1]
    for e in listed {
        guard let data = files[e.name], let new = pages[e.name], let old = try? InkPageCodecV10.decode(data) else {
            check(false, "compat-span 1.0: \(e.name) reads on 1.0")
            continue
        }
        let newJSON = new.jsonValue["strokes"]?.objectValue ?? [:]
        let oldJSON = old.jsonValue["strokes"]?.objectValue ?? [:]
        check(old.strokes.count == new.strokes.count && old.unknownStrokes.count == new.unknownStrokes.count && old.deleted == new.deleted
              && Set(oldJSON.keys) == Set(newJSON.keys) && newJSON.allSatisfy { oldJSON[$0.key]?.serialized() == $0.value.serialized() },
              "compat-span 1.0: \(e.name) the strokes, cells, coordinates, tombstones and unknown items are the same on 1.0")
        check(old.liveStrokes.allSatisfy { s in new.strokes[s.id].map { $0.cell.raw == s.cell.raw && $0.points.map(\.x) == s.points.map(\.x) && $0.points.map(\.y) == s.points.map(\.y) } == true },
              "compat-span 1.0: \(e.name) every stroke has the same cell and points on 1.0 (none cut, none moved)")
        checkEqual((try? InkPageCodecV10.encode(old)), data, "compat-span 1.0: \(e.name) 1.0 writes back the same bytes")
        let cells = cellsV10(pageId: old.pageId)
        let drawn = LedgerV10.drawnIds(page: old, cells: cells)
        checkEqual(drawn.count, drawnBy10[e.name] ?? -1, "compat-span 1.0: \(e.name) 1.0 draws the strokes of its own cells, overhanging or not")
        check(Set(LedgerV10.lassoCandidates(page: old, cells: cells)) == Set(drawn), "compat-span 1.0: \(e.name) 1.0's lasso reaches the drawn strokes")
        check(BandMigrationV10.migrate(old) == old && InkPageV10.merge(old, old) == old && !LedgerV10.displayWouldSave(loaded: old),
              "compat-span 1.0: \(e.name) 1.0's band migration and merge leave it alone, opening it saves nothing")
    }

    // The whole folder through Compat10Checks, with compat11, as CI does with the monday files (here the
    // Sunday week too: the copy lays any w- page out).
    let tmp = fm.temporaryDirectory.appendingPathComponent("KitChecks-compat-span-\(UUID().uuidString)", isDirectory: true)
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
        check(failed.isEmpty, "compat-span: Compat10Checks passes on compat11 and compat-span together (\(failed.prefix(3)))")
        for e in listed {
            let mine = names.filter { $0.hasPrefix(e.name + ":") }.count
            check(mine >= 14, "compat-span: Compat10Checks ran \(mine) checks on \(e.name) (read, write back, draw, lasso, erase, merge, a 1.0 edit)")
        }
        print("   compat10 with compat-span: \(result.passed + result.failed) checks, \(result.failed) failed")
    } catch {
        check(false, "compat-span: preparing the folder for Compat10Checks (\(error))")
    }

    // Export and import: 1.3 writes, 1.0 reads and writes the same bytes, 1.3 imports the same pages.
    let all = listed.compactMap { pages[$0.name] }
    let export = AppExport.encode(AppExport.Document(exportedAt: "2026-11-12T09:00:00+09:00", app: "ios/1.3 (0)", pages: all))
    if let json10 = try? JSONValueV10.parse(export), let doc10 = try? AppExportV10.parse(json: json10) {
        check(AppExportV10.encode(doc10) == export && doc10.pages.count == all.count
              && zip(doc10.pages, all).allSatisfy { (try? InkPageCodecV10.encode($0.0)) == (try? InkPageCodec.encode($0.1)) },
              "compat-span: 1.0 reads the export of every fixture page and writes the same bytes back")
    } else {
        check(false, "compat-span: 1.0 reads the export of the fixture pages")
    }
    if case .app(let doc, let skipped)? = try? InkImport.parse(export) {
        check(skipped == 0 && doc.pages == all && doc.pages.allSatisfy(SpanGuard.checkForTransfer),
              "compat-span: the export imports into the same pages (1.3) and every page passes the import door")
    } else {
        check(false, "compat-span: the export of the fixture pages imports")
    }
}
