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
import InkModel

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

    // The prototype strips its own "proto-" prefix and drops a real page's or another prototype page's.
    let proto = "proto-" + page
    var pp = InkPage(pageId: proto)
    pp.strokes["a"] = SpanInk.stroke("a", cell: proto + "|grid", t: 1)
    pp.strokes["b"] = SpanInk.stroke("b", cell: page + "|grid", t: 2)
    pp.strokes["c"] = SpanInk.stroke("c", cell: "proto-w-2026-11-09|grid", t: 3)
    pp.strokes["d"] = SpanInk.stroke("d", cell: "grid", t: 4)
    if case .repaired(let fixedProto, let s, let d) = SpanGuard.checkForSave(pp, mode: .prototype) {
        check(s == ["a"] && d == ["b", "c"] && fixedProto.strokes["a"]?.cell == .grid && fixedProto.strokes["d"] == pp.strokes["d"],
              "span guard: the prototype strips proto-<own page>| and drops a real page's and another prototype page's prefix")
    } else {
        check(false, "span guard: the prototype page with prefixes is repaired")
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
