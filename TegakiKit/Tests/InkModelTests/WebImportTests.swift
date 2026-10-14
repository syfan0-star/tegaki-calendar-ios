import XCTest
import Foundation
import CoreGraphics
import InkModel

/// `WebImport` (M4_CONTRACT §1.3, §1.4, §3.1–3.3, DESIGN §6.3 / §6.4). The two samples are the
/// contract's §1.4 見本 1 / 見本 2, the same text as the web version's tests/fixtures/*.json, so both
/// sides of the hand-over agree on the format. The same checks run in KitChecks.
final class WebImportTests: XCTestCase {
    /// M4_CONTRACT §1.4 見本 1 (tests/fixtures/tegaki-web-export-sample.json).
    static let sample = #"""
{ "format": "tegaki-web-export", "v": 1, "exportedAt": "2026-10-14T09:41:00.000+09:00", "app": "web/1.0.6", "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "m1-2026-10", "updatedAt": 1760000002000, "deleted": {},
      "strokes": {
        "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000001000 },
        "b2": { "id": "b2", "tool": "highlighter", "color": "#fde047", "size": 18, "pts": [100, 1100, 0.5, 300, 1100, 0.5], "t": 1760000002000 } } },
    { "v": 1, "pageId": "w-2026-10-05", "updatedAt": 1760000003000, "deleted": {},
      "strokes": { "c3": { "id": "c3", "tool": "pen", "color": "#2563eb", "size": 6, "pts": [700, 720, 0.5, 760, 840, 0.5], "t": 1760000003000 } } },
    { "v": 1, "pageId": "d-2026-10-07", "updatedAt": 1760000004000, "deleted": { "zz": 1760000000500 },
      "strokes": { "d4": { "id": "d4", "tool": "pen", "color": "#1f2937", "size": 2, "pts": [100, 900, 1, 300, 1050, 1], "t": 1760000004000 } } },
    { "v": 1, "pageId": "y-2026", "updatedAt": 1760000005000, "deleted": {},
      "strokes": { "e5": { "id": "e5", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1000, 540, 0.6, 1050, 560, 0.6], "t": 1760000005000 } } },
    { "v": 1, "pageId": "m-2026-09", "updatedAt": 1760000006000, "deleted": {},
      "strokes": { "f6": { "id": "f6", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [10, 10, 0.5, 20, 20, 0.5], "t": 1760000006000 } } },
    { "v": 1, "pageId": "d-2026-10-08", "updatedAt": 0, "deleted": {}, "strokes": {} }
  ] }
"""#

    /// M4_CONTRACT §1.4 見本 2 (tests/fixtures/tegaki-web-export-expected.json).
    static let expected = #"""
{ "format": "tegaki-web-export", "v": 1, "exportedAt": "2026-10-14T09:41:00.000+09:00", "app": "web/1.0.6", "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "d-2026-10-07", "updatedAt": 1760000004000, "deleted": { "zz": 1760000000500 },
      "strokes": { "d4": { "id": "d4", "tool": "pen", "color": "#1f2937", "size": 2, "pts": [100, 900, 1, 300, 1050, 1], "t": 1760000004000 } } },
    { "v": 1, "pageId": "m1-2026-10", "updatedAt": 1760000002000, "deleted": {},
      "strokes": {
        "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000001000 },
        "b2": { "id": "b2", "tool": "highlighter", "color": "#fde047", "size": 18, "pts": [100, 1100, 0.5, 300, 1100, 0.5], "t": 1760000002000 } } },
    { "v": 1, "pageId": "w-2026-10-05", "updatedAt": 1760000003000, "deleted": {},
      "strokes": { "c3": { "id": "c3", "tool": "pen", "color": "#2563eb", "size": 6, "pts": [700, 720, 0.5, 760, 840, 0.5], "t": 1760000003000 } } },
    { "v": 1, "pageId": "y-2026", "updatedAt": 1760000005000, "deleted": {},
      "strokes": { "e5": { "id": "e5", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1000, 540, 0.6, 1050, 560, 0.6], "t": 1760000005000 } } }
  ] }
"""#

    private let october = WebImport.PageId.month(YearMonth(year: 2026, month: 10))

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func doc(_ text: String) throws -> WebImport.Document { try WebImport.parse(Data(text.utf8)) }

    private func parseError(_ text: String) -> WebImport.ParseError? {
        do {
            _ = try doc(text)
            return nil
        } catch let e as WebImport.ParseError {
            return e
        } catch {
            return nil
        }
    }

    /// A one-page export around `strokes` (a JSON object or array text).
    private func exportText(pageId: String = "d-2026-10-07", strokes: String, deleted: String = "{}", updatedAt: Int = 1_760_000_004_000) -> String {
        #"{ "format": "tegaki-web-export", "v": 1, "pages": [ { "v": 1, "pageId": "\#(pageId)", "updatedAt": \#(updatedAt), "deleted": \#(deleted), "strokes": \#(strokes) } ] }"#
    }

    private func webStroke(_ id: String, tool: WebImport.Stroke.Tool = .pen, color: String = "#1f2937", size: Double = 3.5, t: Int = 1_760_000_001_000, points: [(Double, Double, Double)]) -> WebImport.Stroke {
        WebImport.Stroke(id: id, tool: tool, color: color, size: size, points: points.map { WebImport.Point(x: $0.0, y: $0.1, p: $0.2) }, t: t)
    }

    /// An iPad stroke (as the canvas would write it).
    private func ipadStroke(_ id: String, t: Int) -> InkStroke {
        let p = InkPoint(x: 10, y: 20, dtMs: 0, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 1.5708, altitude: 0.7854)
        return InkStroke(id: id, cell: .day(day(2026, 10, 4)), tool: .pen, color: "#1f2937", t: t, dev: "ipad-1", points: [p])
    }

    // MARK: Constants

    func testConstants() {
        XCTAssertEqual(WebImport.format, "tegaki-web-export")
        XCTAssertEqual(WebImport.supportedVersion, 1)
        XCTAssertEqual(WebImport.deviceId, "web")
        XCTAssertEqual(WebImport.pointStepMs, 8)
        XCTAssertEqual(WebImport.highlighterWidth, 18)
    }

    // MARK: Parsing (§3.1)

    func testSample1ParsesToSixPages() throws {
        let d = try doc(Self.sample)
        XCTAssertEqual(d.pages.count, 6)
        XCTAssertEqual(d.pages.map(\.pageId), ["m1-2026-10", "w-2026-10-05", "d-2026-10-07", "y-2026", "m-2026-09", "d-2026-10-08"], "document order is kept")
        XCTAssertEqual(d.exportedAt, "2026-10-14T09:41:00.000+09:00")
        XCTAssertEqual(d.app, "web/1.0.6")
        XCTAssertFalse(d.includesDemo)
        XCTAssertEqual(d.pages.map(\.strokes.count), [2, 1, 1, 1, 1, 0])
        let month = d.pages[0]
        XCTAssertEqual(month.strokes.map(\.id), ["a1", "b2"], "strokes sorted by id")
        XCTAssertEqual(month.updatedAt, 1_760_000_002_000)
        XCTAssertEqual(month.deleted, [:])
        let a1 = month.strokes[0]
        XCTAssertEqual(a1.tool, .pen)
        XCTAssertEqual(a1.color, "#1f2937")
        XCTAssertEqual(a1.size, 3.5)
        XCTAssertEqual(a1.t, 1_760_000_001_000)
        XCTAssertEqual(a1.points, [WebImport.Point(x: 410, y: 360, p: 0.4), WebImport.Point(x: 450, y: 380, p: 0.6), WebImport.Point(x: 490, y: 370, p: 0.8)])
        let b2 = month.strokes[1]
        XCTAssertEqual(b2.tool, .highlighter)
        XCTAssertEqual(b2.color, "#fde047")
        XCTAssertEqual(b2.size, 18)
        XCTAssertEqual(b2.points.count, 2)
        XCTAssertEqual(d.pages[2].deleted, ["zz": 1_760_000_000_500], "the tombstone is read")
        XCTAssertEqual(d.pages[2].strokes[0].size, 2)
        XCTAssertEqual(d.pages[2].strokes[0].points.map(\.p), [1, 1])
        XCTAssertEqual(d.pages[5].strokes, [])
        XCTAssertEqual(d.pages[5].updatedAt, 0)
    }

    func testSample2ParsesToFourPages() throws {
        let d = try doc(Self.sample)
        let e = try doc(Self.expected)
        XCTAssertEqual(e.pages.count, 4)
        XCTAssertEqual(e.pages.map(\.pageId), ["d-2026-10-07", "m1-2026-10", "w-2026-10-05", "y-2026"])
        XCTAssertEqual(e.pages[1], d.pages[0], "the month page reads the same from both samples")
        XCTAssertEqual(e.pages[0], d.pages[2], "the day page reads the same from both samples")
        XCTAssertEqual(e.pages[2], d.pages[1])
        XCTAssertEqual(e.pages[3], d.pages[3])
    }

    func testOnlyFormatAndVersionThrow() throws {
        XCTAssertEqual(parseError(#"{ "format": "something-else", "v": 1, "pages": [] }"#), .notAnExport)
        XCTAssertEqual(parseError(#"{ "v": 1, "pages": [] }"#), .notAnExport, "missing format")
        XCTAssertEqual(parseError(#"[1, 2, 3]"#), .notAnExport, "an array")
        XCTAssertEqual(parseError(#""tegaki-web-export""#), .notAnExport, "a bare string")
        XCTAssertEqual(parseError(#"{ "format": "tegaki-web-export", "v": 2, "pages": [] }"#), .unsupportedVersion(2))
        XCTAssertEqual(parseError(#"{ "format": "tegaki-web-export", "v": 7 }"#), .unsupportedVersion(7))
        XCTAssertEqual(parseError(#"{ "format": "tegaki-web-export", "v": 1, "pages": ["#), .invalidJSON, "truncated JSON")
        XCTAssertEqual(parseError("not json at all"), .invalidJSON)
        XCTAssertEqual(parseError(""), .invalidJSON)
        XCTAssertNil(parseError(#"{ "format": "tegaki-web-export" }"#), "a missing v counts as 1 and missing pages as none")
        XCTAssertEqual(try doc(#"{ "format": "tegaki-web-export" }"#).pages.count, 0)
        XCTAssertTrue(try doc(#"{ "format": "tegaki-web-export", "v": 1, "pages": "x", "includesDemo": true, "app": 5 }"#).includesDemo)
        XCTAssertNil(try doc(#"{ "format": "tegaki-web-export", "v": 1, "pages": "x", "app": 5 }"#).app, "a non-string app is nil")
        XCTAssertEqual(try doc(#"{ "format": "tegaki-web-export", "v": 1, "pages": [1, "x", null] }"#).pages.count, 0, "pages that are not objects are dropped")
        XCTAssertEqual(try doc(#"{ "format": "tegaki-web-export", "v": 1, "pages": [ { "strokes": {} } ] }"#).pages[0].pageId, "", "a page without pageId reads as \"\"")
    }

    func testBrokenStrokesAreDropped() throws {
        let good = ##""ok": { "id": "ok", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1, 2, 0.5, 3, 4, 0.5], "t": 5 }"##
        func ids(_ extra: String, deleted: String = "{}") throws -> [String] {
            try doc(exportText(strokes: "{ \(good), \(extra) }", deleted: deleted)).pages[0].strokes.map(\.id)
        }
        XCTAssertEqual(try ids(#""bad": { "id": "bad", "tool": "brush", "pts": [1, 2, 0.5] }"#), ["ok"], "unknown tool")
        XCTAssertEqual(try ids(#""bad": { "id": "bad", "pts": [1, 2, 0.5] }"#), ["ok"], "missing tool")
        XCTAssertEqual(try ids(#""bad": { "id": "bad", "tool": "pen", "pts": [1, 2] }"#), ["ok"], "two numbers are not a point")
        XCTAssertEqual(try ids(#""bad": { "id": "bad", "tool": "pen", "pts": [] }"#), ["ok"], "no points")
        XCTAssertEqual(try ids(#""bad": { "id": "bad", "tool": "pen" }"#), ["ok"], "missing pts")
        XCTAssertEqual(try ids(#""": { "id": "", "tool": "pen", "pts": [1, 2, 0.5] }"#), ["ok"], "empty id and empty key")
        let long = String(repeating: "x", count: 129)
        XCTAssertEqual(try ids(#""\#(long)": { "id": "\#(long)", "tool": "pen", "pts": [1, 2, 0.5] }"#), ["ok"], "129-character id")
        let max = String(repeating: "x", count: 128)
        XCTAssertEqual(try ids(#""\#(max)": { "id": "\#(max)", "tool": "pen", "pts": [1, 2, 0.5] }"#), ["ok", max], "128-character id is fine")
        XCTAssertEqual(try ids(#""key": { "tool": "pen", "pts": [1, 2, 0.5] }"#), ["key", "ok"], "a missing id falls back to the key")
        XCTAssertEqual(try ids(#""key": { "id": 7, "tool": "pen", "pts": [1, 2, 0.5] }"#), ["key", "ok"], "a non-string id falls back to the key")
        XCTAssertEqual(try ids(#""bad": 5"#), ["ok"], "a stroke that is not an object")
        XCTAssertEqual(try ids(#""gone": { "id": "gone", "tool": "pen", "pts": [1, 2, 0.5] }"#, deleted: #"{ "gone": 10 }"#), ["ok"], "a tombstoned stroke is dropped")
        XCTAssertEqual(try doc(exportText(strokes: "{ \(good) }", deleted: #"{ "": 1, "a": "x", "b": -5, "c": 1e20 }"#)).pages[0].deleted, ["a": 0, "b": 0, "c": 0], "tombstones: bad ids dropped, garbage times are 0")
        XCTAssertEqual(try doc(exportText(strokes: #"[{ "id": "l1", "tool": "pen", "pts": [1, 2, 0.5] }, { "tool": "pen", "pts": [1, 2, 0.5] }]"#)).pages[0].strokes.map(\.id), ["l1"], "an array of strokes is read (no key to fall back to)")
    }

    private func firstStroke(_ pts: String, tool: String = "pen", size: String = "3.5") throws -> WebImport.Stroke? {
        try doc(exportText(strokes: #"{ "s": { "id": "s", "tool": "\#(tool)", "size": \#(size), "pts": \#(pts) } }"#)).pages[0].strokes.first
    }

    func testPressureAndCoordinates() throws {
        XCTAssertEqual(try firstStroke("[0, 0, -1, 10, 10, 2]")?.points.map(\.p), [0, 1], "pressure clamped to 0…1")
        XCTAssertEqual(try firstStroke(#"[0, 0, "x", 10, 10, null]"#)?.points.map(\.p), [0.5, 0.5], "non-numeric pressure → 0.5")
        XCTAssertEqual(try firstStroke("[0, 0, 0.123, 10, 10, 0.456]")?.points.map(\.p), [0.12, 0.46], "pressure rounded to 0.01")
        XCTAssertEqual(try firstStroke("[0.04, 0.06, 0.5, 10.15, 10.14, 0.5]")?.points.map { [$0.x, $0.y] }, [[0, 0.1], [10.2, 10.1]], "coordinates rounded to 0.1")
        XCTAssertEqual(try firstStroke("[1, 1, 0.5, 1, 1, 0.7, 1, 1, 0.9, 2, 2, 0.5]")?.points.count, 2, "consecutive equal points are dropped")
        XCTAssertEqual(try firstStroke("[1, 1, 0.5, 2, 2, 0.5, 1, 1, 0.5]")?.points.count, 3, "a return to an earlier point is kept")
        XCTAssertEqual(try firstStroke("[1, 1, 0.5, 100001, 5, 0.5, 2, 2, 0.5]")?.points.count, 2, "|x| > 100000 is dropped")
        XCTAssertEqual(try firstStroke("[1, 1, 0.5, 5, -100000.05, 0.5, 2, 2, 0.5]")?.points.count, 2, "|y| > 100000 is dropped")
        XCTAssertEqual(try firstStroke("[1, 1, 0.5, 100000, -100000, 0.5]")?.points.count, 2, "|coordinate| = 100000 is kept")
        XCTAssertEqual(try firstStroke(#"[1, 1, 0.5, "a", 5, 0.5, 2, 2, 0.5]"#)?.points.count, 2, "a non-numeric coordinate drops the point")
        XCTAssertEqual(try firstStroke("[1, 1, 0.5, 2, 2, 0.5, 3, 3]")?.points.count, 2, "a trailing partial point is ignored")
        XCTAssertNil(try firstStroke("[100001, 1, 0.5]"), "a stroke whose only point is absurd is dropped")
    }

    func testSizeNormalization() throws {
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", size: "0.05")?.size, 0.1)
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", size: "500")?.size, 200)
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", size: "2.345")?.size, 2.35, "rounded to 0.01")
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", size: "\"x\"")?.size, 3.5, "non-numeric → pen default")
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", size: "0")?.size, 3.5, "0 → pen default, not 0.1")
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", size: "-3")?.size, 3.5, "negative → pen default")
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", tool: "highlighter", size: "null")?.size, 18)
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", tool: "highlighter", size: "0")?.size, 18)
        XCTAssertEqual(try firstStroke("[0, 0, 0.5]", tool: "highlighter", size: "12")?.size, 12, "a highlighter size is kept")
        XCTAssertEqual(WebImport.normalizeSize(nil, tool: .pen), 3.5)
        XCTAssertEqual(WebImport.normalizeSize(.infinity, tool: .highlighter), 18)
        XCTAssertEqual(WebImport.normalizeSize(6, tool: .pen), 6)
    }

    func testColourAndTime() throws {
        func stroke(_ body: String) throws -> WebImport.Stroke? {
            try doc(exportText(strokes: #"{ "s": { "id": "s", "pts": [0, 0, 0.5], \#(body) } }"#)).pages[0].strokes.first
        }
        XCTAssertEqual(try stroke(##""tool": "pen", "color": "#ABC""##)?.color, "#aabbcc", "expanded and lower-cased")
        XCTAssertEqual(try stroke(#""tool": "pen", "color": "red""#)?.color, "#1f2937", "bad colour → pen default")
        XCTAssertEqual(try stroke(#""tool": "highlighter""#)?.color, "#fde047", "missing colour → highlighter default")
        XCTAssertEqual(try stroke(#""tool": "pen", "t": -5"#)?.t, 0)
        XCTAssertEqual(try stroke(#""tool": "pen", "t": "x""#)?.t, 0)
        XCTAssertEqual(try stroke(#""tool": "pen", "t": 1760000001000.4"#)?.t, 1_760_000_001_000, "t rounded")
        XCTAssertEqual(try stroke(#""tool": "pen""#)?.t, 0, "missing t → 0")
        XCTAssertEqual(try doc(exportText(strokes: "{ \(#""s": { "id": "s", "tool": "pen", "pts": [0, 0, 0.5] }"#) }", updatedAt: -1)).pages[0].updatedAt, 0, "negative updatedAt → 0")
    }

    // MARK: PageId (§3.2)

    func testPageIdParse() {
        XCTAssertEqual(WebImport.PageId.parse("m1-2026-10"), .month(YearMonth(year: 2026, month: 10)))
        XCTAssertEqual(WebImport.PageId.parse("w-2026-10-05"), .week(day(2026, 10, 5)))
        XCTAssertEqual(WebImport.PageId.parse("d-2026-10-07"), .day(day(2026, 10, 7)))
        XCTAssertEqual(WebImport.PageId.parse("y-2026"), .year(2026))
        XCTAssertEqual(WebImport.PageId.parse("m1-2026-10")?.raw, "m1-2026-10")
        XCTAssertEqual(WebImport.PageId.parse("w-2026-10-05")?.raw, "w-2026-10-05")
        XCTAssertEqual(WebImport.PageId.parse("d-2026-10-07")?.raw, "d-2026-10-07")
        XCTAssertEqual(WebImport.PageId.parse("y-2026")?.raw, "y-2026")
        XCTAssertNil(WebImport.PageId.parse("m-2026-09"), "Sunday-start month")
        XCTAssertNil(WebImport.PageId.parse("w-2026-10-04"), "a Sunday week")
        XCTAssertNil(WebImport.PageId.parse("w-2026-10-06"), "a Tuesday week")
        XCTAssertNil(WebImport.PageId.parse("y-26"))
        XCTAssertNil(WebImport.PageId.parse(""))
        XCTAssertNil(WebImport.PageId.parse("m1-2026-13"))
        XCTAssertNil(WebImport.PageId.parse("m1-2026-1"), "unpadded month")
        XCTAssertNil(WebImport.PageId.parse("d-2026-02-30"), "impossible date")
        XCTAssertNil(WebImport.PageId.parse("d-2026-10-7"), "unpadded day")
        XCTAssertNil(WebImport.PageId.parse("x-2026"))
        XCTAssertNil(WebImport.PageId.parse("y-2026x"))
        XCTAssertNil(WebImport.PageId.parse("y-２０２６"), "full-width digits")
        XCTAssertEqual(WebImport.PageId.parse("w-2025-12-29"), .week(day(2025, 12, 29)), "a Monday across the year end")
        XCTAssertEqual(WebImport.PageId.parse("y-0999"), .year(999))
        XCTAssertEqual(WebImport.PageId.year(999).raw, "y-0999", "raw pads the year")
    }

    func testMonthCells() {
        var r = WebImport.cell(for: october, center: CGPoint(x: 450, y: 370))
        XCTAssertEqual(r.cell, .day(day(2026, 10, 14)), "a1: row 2, column 2 → 10/14")
        XCTAssertEqual(r.origin, CGPoint(x: 400, y: 350))
        r = WebImport.cell(for: october, center: CGPoint(x: 200, y: 1100))
        XCTAssertEqual(r.cell, .memo, "b2: y ≥ 1050 → memo")
        XCTAssertEqual(r.origin, CGPoint(x: 0, y: 1050))
        r = WebImport.cell(for: october, center: CGPoint(x: -5, y: -5))
        XCTAssertEqual(r.cell, .day(day(2026, 9, 28)), "outside top-left → row 0 column 0")
        XCTAssertEqual(r.origin, .zero)
        r = WebImport.cell(for: october, center: CGPoint(x: 1400, y: 1049.9))
        XCTAssertEqual(r.cell, .day(day(2026, 11, 8)), "row 5 column 6")
        XCTAssertEqual(r.origin, CGPoint(x: 1200, y: 875))
        r = WebImport.cell(for: october, center: CGPoint(x: 700, y: 1050))
        XCTAssertEqual(r.cell, .memo)
        r = WebImport.cell(for: october, center: CGPoint(x: CGFloat.nan, y: CGFloat.nan))
        XCTAssertEqual(r.cell, .day(day(2026, 9, 28)), "NaN counts as (0, 0)")
        r = WebImport.cell(for: october, center: CGPoint(x: 350, y: 175))
        XCTAssertEqual(r.cell, .day(day(2026, 10, 6)), "(350, 175) is on row 1")
        r = WebImport.cell(for: october, center: CGPoint(x: 199.9999999999, y: 174.9999999999))
        XCTAssertEqual(r.cell, .day(day(2026, 10, 6)), "1e-9 below a boundary still counts as the next cell")
        r = WebImport.cell(for: october, center: CGPoint(x: 5000, y: 100))
        XCTAssertEqual(r.cell, .day(day(2026, 10, 4)), "far right → column 6")
        r = WebImport.cell(for: .month(YearMonth(year: 2026, month: 2)), center: CGPoint(x: 100, y: 100))
        XCTAssertEqual(r.cell, .day(day(2026, 1, 26)), "February 2026 starts on Monday 1/26")
    }

    func testWeekAndDayCellsAreAlwaysGrid() {
        var r = WebImport.cell(for: .week(day(2026, 10, 5)), center: CGPoint(x: 730, y: 780))
        XCTAssertEqual(r.cell, .grid)
        XCTAssertEqual(r.origin, .zero)
        r = WebImport.cell(for: .week(day(2026, 10, 5)), center: CGPoint(x: -100, y: 99999))
        XCTAssertEqual(r.cell, .grid)
        r = WebImport.cell(for: .day(day(2026, 10, 7)), center: CGPoint(x: 200, y: 975))
        XCTAssertEqual(r.cell, .grid)
        XCTAssertEqual(r.origin, .zero)
        r = WebImport.cell(for: .day(day(2026, 10, 7)), center: CGPoint(x: 900, y: 2300))
        XCTAssertEqual(r.cell, .grid, "the day memo area too")
    }

    func testYearCells() {
        let year = WebImport.PageId.year(2026)
        var r = WebImport.cell(for: year, center: CGPoint(x: 1025, y: 550))
        XCTAssertEqual(r.cell, .yearDay(month: 9, day: 10), "e5")
        XCTAssertEqual(r.origin, CGPoint(x: 952, y: 540))
        r = WebImport.cell(for: year, center: CGPoint(x: 10, y: 30))
        XCTAssertEqual(r.cell, .yearDay(month: 1, day: 1), "the date gutter → 01-01")
        XCTAssertEqual(r.origin, CGPoint(x: 56, y: 0))
        r = WebImport.cell(for: year, center: CGPoint(x: 1399, y: 1859))
        XCTAssertEqual(r.cell, .yearDay(month: 12, day: 31))
        XCTAssertEqual(r.origin, CGPoint(x: 1288, y: 1800))
        r = WebImport.cell(for: year, center: CGPoint(x: 1399, y: 5000))
        XCTAssertEqual(r.cell, .yearDay(month: 12, day: 31), "below the paper")
        r = WebImport.cell(for: year, center: CGPoint(x: 5000, y: -50))
        XCTAssertEqual(r.cell, .yearDay(month: 12, day: 1), "right of the paper, above")
        r = WebImport.cell(for: year, center: CGPoint(x: 168 + 50, y: 1745))
        XCTAssertEqual(r.cell, .yearDay(month: 2, day: 30), "the 2/30 cell exists")
        XCTAssertEqual(r.origin, CGPoint(x: 168, y: 1740))
        r = WebImport.cell(for: year, center: CGPoint(x: 56, y: 0))
        XCTAssertEqual(r.cell, .yearDay(month: 1, day: 1))
        r = WebImport.cell(for: year, center: CGPoint(x: 168, y: 60))
        XCTAssertEqual(r.cell, .yearDay(month: 2, day: 2), "boundaries belong to the next cell")
    }

    // MARK: Conversion (§3.3)

    func testNibSize() {
        XCTAssertEqual(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0.4), 2.66, accuracy: 1e-9)
        XCTAssertEqual(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0.6), 3.29, accuracy: 1e-9)
        XCTAssertEqual(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0.8), 3.92, accuracy: 1e-9)
        XCTAssertEqual(WebImport.nibSize(tool: .pen, size: 2, pressure: 1), 2.6, accuracy: 1e-9)
        XCTAssertEqual(WebImport.nibSize(tool: .pen, size: 6, pressure: 0.5), 5.1, accuracy: 1e-9)
        XCTAssertEqual(WebImport.nibSize(tool: .pen, size: 3.5, pressure: 0), 1.4, accuracy: 1e-9)
        XCTAssertEqual(WebImport.nibSize(tool: .highlighter, size: 18, pressure: 0.5), 18)
        XCTAssertEqual(WebImport.nibSize(tool: .highlighter, size: 18, pressure: 1), 18, "pressure is ignored")
        XCTAssertEqual(WebImport.nibSize(tool: .highlighter, size: 10, pressure: 0), 10)
    }

    func testConvertStrokeHasTheContractValues() throws {
        let d = try doc(Self.sample)
        let a1 = try XCTUnwrap(WebImport.convert(stroke: d.pages[0].strokes[0], page: october))
        XCTAssertEqual(a1.id, "a1")
        XCTAssertEqual(a1.cell, .day(day(2026, 10, 14)))
        XCTAssertEqual(a1.tool, .pen)
        XCTAssertEqual(a1.color, "#1f2937")
        XCTAssertEqual(a1.t, 1_760_000_001_000)
        XCTAssertEqual(a1.dev, "web")
        XCTAssertEqual(a1.points.count, 3)
        XCTAssertEqual(a1.points.map(\.x), [10, 50, 90])
        XCTAssertEqual(a1.points.map(\.y), [10, 30, 20])
        XCTAssertEqual(a1.points.map(\.dtMs), [0, 8, 16])
        XCTAssertEqual(a1.points.map(\.sizeW), [2.66, 3.29, 3.92])
        XCTAssertEqual(a1.points.map(\.sizeH), [2.66, 3.29, 3.92])
        XCTAssertEqual(a1.points.map(\.force), [0.4, 0.6, 0.8])
        XCTAssertEqual(a1.points.map(\.opacity), [1, 1, 1])
        XCTAssertEqual(a1.points.map(\.azimuth), [0, 0, 0])
        XCTAssertEqual(a1.points.map(\.altitude), [1.571, 1.571, 1.571], "π/2 rounded to 0.001")
        XCTAssertEqual(a1.inkStart, Date(timeIntervalSince1970: 1_760_000_001))

        let b2 = try XCTUnwrap(WebImport.convert(stroke: d.pages[0].strokes[1], page: october))
        XCTAssertEqual(b2.cell, .memo)
        XCTAssertEqual(b2.tool, .marker)
        XCTAssertEqual(b2.color, "#fde047")
        XCTAssertEqual(b2.points.map(\.x), [100, 300])
        XCTAssertEqual(b2.points.map(\.y), [50, 50])
        XCTAssertEqual(b2.points.map(\.sizeW), [18, 18])
        XCTAssertEqual(b2.points.map(\.force), [0.5, 0.5])
        XCTAssertEqual(b2.t, 1_760_000_002_000)

        let c3 = try XCTUnwrap(WebImport.convert(stroke: d.pages[1].strokes[0], page: .week(day(2026, 10, 5))))
        XCTAssertEqual(c3.cell, .grid)
        XCTAssertEqual(c3.color, "#2563eb")
        XCTAssertEqual(c3.points.map(\.x), [700, 760])
        XCTAssertEqual(c3.points.map(\.y), [720, 840])
        XCTAssertEqual(c3.points.map(\.sizeW), [5.1, 5.1])
        XCTAssertEqual(c3.dev, "web")

        let d4 = try XCTUnwrap(WebImport.convert(stroke: d.pages[2].strokes[0], page: .day(day(2026, 10, 7))))
        XCTAssertEqual(d4.cell, .grid)
        XCTAssertEqual(d4.points.map(\.x), [100, 300])
        XCTAssertEqual(d4.points.map(\.y), [900, 1050])
        XCTAssertEqual(d4.points.map(\.sizeW), [2.6, 2.6])
        XCTAssertEqual(d4.points.map(\.force), [1, 1])

        let e5 = try XCTUnwrap(WebImport.convert(stroke: d.pages[3].strokes[0], page: .year(2026)))
        XCTAssertEqual(e5.cell, .yearDay(month: 9, day: 10))
        XCTAssertEqual(e5.points.map(\.x), [48, 98])
        XCTAssertEqual(e5.points.map(\.y), [0, 20])
        XCTAssertEqual(e5.points.map(\.sizeW), [3.29, 3.29])
        XCTAssertEqual(e5.t, 1_760_000_005_000)
    }

    func testConvertStrokeEdgeCases() throws {
        XCTAssertNil(WebImport.convert(stroke: webStroke("", points: [(1, 1, 0.5)]), page: october), "empty id")
        XCTAssertNil(WebImport.convert(stroke: webStroke(String(repeating: "y", count: 129), points: [(1, 1, 0.5)]), page: october), "129-character id")
        XCTAssertNil(WebImport.convert(stroke: webStroke("p", points: []), page: october), "no points")
        let odd = try XCTUnwrap(WebImport.convert(stroke: webStroke("odd", color: "nope", t: -7, points: [(1, 2, 0.5)]), page: october))
        XCTAssertEqual(odd.color, "#1f2937", "a bad colour → the tool default")
        XCTAssertEqual(odd.t, 0, "a negative t → 0")
        XCTAssertEqual(odd.points.map(\.x), [1], "a single point converts")
        let hl = try XCTUnwrap(WebImport.convert(stroke: webStroke("hl", tool: .highlighter, color: "bad", size: 18, points: [(1, 2, 0.5)]), page: october))
        XCTAssertEqual(hl.color, "#fde047")
        XCTAssertEqual(hl.tool, .marker)
        let fine = try XCTUnwrap(WebImport.convert(stroke: webStroke("fine", size: 3.5, points: [(410.04, 360.06, 0.123)]), page: october))
        XCTAssertEqual(fine.points[0].x, 10, "x rounded to 0.1 by InkPoint")
        XCTAssertEqual(fine.points[0].y, 10.1)
        XCTAssertEqual(fine.points[0].force, 0.12)
        XCTAssertEqual(fine.points[0].sizeW, 1.79, accuracy: 1e-9, "3.5 × (0.4 + 0.9 × 0.123) = 1.787 → 1.79")
        let span = try XCTUnwrap(WebImport.convert(stroke: webStroke("span", points: [(300, 400, 0.5), (580, 400, 0.5)]), page: october))
        XCTAssertEqual(span.cell, .day(day(2026, 10, 14)), "the bounding-box centre (440, 400) decides the cell, not the first point")
        XCTAssertEqual(span.points.map(\.x), [-100, 180], "points outside the cell keep their offset")
        let many = try XCTUnwrap(WebImport.convert(stroke: webStroke("many", points: (0..<50).map { (Double($0), 5, 0.5) }), page: .week(day(2026, 10, 5))))
        XCTAssertEqual(many.points.map(\.dtMs), (0..<50).map { 8 * $0 })
    }

    func testConvertSample1() throws {
        let d = try doc(Self.sample)
        let conv = WebImport.convert(d)
        XCTAssertEqual(conv.pages.count, 4)
        XCTAssertEqual(conv.pageCount, 4)
        XCTAssertEqual(conv.strokeCount, 5)
        XCTAssertEqual(conv.skipped, [WebImport.Skipped(pageId: "m-2026-09", reason: .legacyPageId), WebImport.Skipped(pageId: "d-2026-10-08", reason: .noStrokes)])
        XCTAssertEqual(conv.pages.map(\.pageId), ["m1-2026-10", "w-2026-10-05", "d-2026-10-07", "y-2026"], "document order")
        XCTAssertEqual(conv.pages.map(\.liveStrokeCount), [2, 1, 1, 1])
        XCTAssertEqual(conv.pages.map(\.updatedAt), [1_760_000_002_000, 1_760_000_003_000, 1_760_000_004_000, 1_760_000_005_000])
        XCTAssertEqual(conv.pages.map(\.v), [1, 1, 1, 1])
        XCTAssertEqual(conv.pages[2].deleted, ["zz": 1_760_000_000_500], "the day page keeps the tombstone zz")
        XCTAssertNotNil(conv.pages[2].strokes["d4"])
        XCTAssertEqual(conv.pages[0].liveStrokeIds, ["a1", "b2"])
        XCTAssertEqual(conv.pages[0].strokes["a1"], WebImport.convert(stroke: d.pages[0].strokes[0], page: october))
        XCTAssertEqual(conv.pages[3].strokes["e5"], WebImport.convert(stroke: d.pages[3].strokes[0], page: .year(2026)))
        XCTAssertTrue(conv.pages.allSatisfy { $0.strokes.values.allSatisfy { $0.dev == "web" } })
        XCTAssertTrue(conv.pages.allSatisfy { $0.unknown.isEmpty && $0.unknownStrokes.isEmpty })
        XCTAssertEqual(conv.pages[0].liveStrokes.map(\.id), ["b2", "a1"], "draw order: marker first")
    }

    func testSample2ConvertsToTheSamePages() throws {
        let conv = WebImport.convert(try doc(Self.sample))
        let conv2 = WebImport.convert(try doc(Self.expected))
        XCTAssertEqual(conv2.pages.count, 4)
        XCTAssertEqual(conv2.strokeCount, 5)
        XCTAssertEqual(conv2.skipped, [])
        XCTAssertEqual(conv2.pages.map(\.pageId), ["d-2026-10-07", "m1-2026-10", "w-2026-10-05", "y-2026"])
        XCTAssertEqual(conv.pages.sorted { $0.pageId < $1.pageId }, conv2.pages, "sorted by pageId the two conversions are equal")
        XCTAssertNotEqual(conv.pages.sorted { $0.pageId < $1.pageId }, conv.pages, "(document order differs from sorted order)")
    }

    func testImportingTwiceDoesNotDuplicate() throws {
        let conv = WebImport.convert(try doc(Self.sample))
        for page in conv.pages {
            XCTAssertEqual(InkPage.merge(page, page).liveStrokeCount, page.liveStrokeCount, page.pageId)
            XCTAssertEqual(InkPage.merge(page, page), page, page.pageId)
        }
        var local = conv.pages[0]
        local.remove(ids: ["a1"], at: 1_760_000_009_000)
        local.add(ipadStroke("ipad-stroke", t: 1_760_000_010_000))
        let again = InkPage.merge(local, conv.pages[0])
        XCTAssertEqual(again.liveStrokeIds, ["b2", "ipad-stroke"], "a1 erased on the iPad stays erased after a re-import")
        XCTAssertEqual(again.deleted["a1"], 1_760_000_009_000)
        XCTAssertEqual(again.updatedAt, 1_760_000_010_000)
        XCTAssertEqual(InkPage.merge(conv.pages[0], local), again, "commutative")
        XCTAssertEqual(InkPage.merge(again, conv.pages[0]), again, "a third import changes nothing")
        let wiped = InkPage.merge(InkPage(pageId: "d-2026-10-07", deleted: ["d4": 1]), conv.pages[2])
        XCTAssertEqual(wiped.liveStrokeCount, 0, "a tombstone wins over the imported stroke")
        XCTAssertEqual(wiped.deleted, ["d4": 1, "zz": 1_760_000_000_500])
        XCTAssertTrue(conv.pages[2].contentDiffers(from: wiped))
        XCTAssertFalse(conv.pages[2].contentDiffers(from: InkPage.merge(conv.pages[2], conv.pages[2])))
    }

    func testUpdatedAtIsTheMaxOfWebAndStrokes() throws {
        let early = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 100, points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 5))
        XCTAssertEqual(early?.updatedAt, 100, "the stroke's t when the page's is older")
        let late = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 100, points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 200))
        XCTAssertEqual(late?.updatedAt, 200, "the page's when it is later")
        let two = try XCTUnwrap(WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 100, points: [(1, 1, 0.5)]), webStroke("u", t: 300, points: [(2, 2, 0.5)])], deleted: ["s": 50], updatedAt: 200)))
        XCTAssertEqual(two.updatedAt, 300, "the latest stroke")
        XCTAssertEqual(two.deleted, ["s": 50], "web tombstones are carried over as they are")
        XCTAssertEqual(two.strokes.count, 2, "the strokes are not removed by the carried-over tombstone")
        XCTAssertEqual(two.liveStrokeIds, ["u"], "but the tombstoned one is not live")
        XCTAssertEqual(two.jsonValue["strokes"]?.objectValue?.keys.sorted(), ["u"], "and it is not written")
        let zero = WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-07", strokes: [webStroke("s", t: 0, points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 0))
        XCTAssertEqual(zero?.updatedAt, 0)
        XCTAssertEqual(zero?.strokes["s"]?.t, 0)
    }

    func testSkippedPagesAndReasons() {
        XCTAssertNil(WebImport.convert(page: WebImport.Page(pageId: "m-2026-09", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1)), "legacy id")
        XCTAssertNil(WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-08", strokes: [], deleted: ["zz": 1], updatedAt: 1)), "only tombstones")
        XCTAssertNil(WebImport.convert(page: WebImport.Page(pageId: "d-2026-10-08", strokes: [webStroke("", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1)), "only an unconvertible stroke")
        let reasons = WebImport.convert(WebImport.Document(exportedAt: nil, app: nil, includesDemo: false, pages: [
            WebImport.Page(pageId: "m-2026-09", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
            WebImport.Page(pageId: "w-2026-10-04", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
            WebImport.Page(pageId: "w-2026-10-06", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
            WebImport.Page(pageId: "", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
            WebImport.Page(pageId: "q-2026", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
            WebImport.Page(pageId: "y-2026", strokes: [], deleted: [:], updatedAt: 1),
            WebImport.Page(pageId: "y-2026", strokes: [webStroke("s", points: [(1, 1, 0.5)])], deleted: [:], updatedAt: 1),
        ]))
        XCTAssertEqual(reasons.skipped.map(\.reason), [.legacyPageId, .legacyPageId, .unknownPageId, .unknownPageId, .unknownPageId, .noStrokes], "m-, Sunday w-, Tuesday w-, empty, unknown prefix, empty page")
        XCTAssertEqual(reasons.skipped.map(\.pageId), ["m-2026-09", "w-2026-10-04", "w-2026-10-06", "", "q-2026", "y-2026"])
        XCTAssertEqual(reasons.pageCount, 1)
        XCTAssertEqual(reasons.strokeCount, 1)
        XCTAssertEqual(WebImport.convert(WebImport.Document(exportedAt: nil, app: nil, includesDemo: true, pages: [])), WebImport.Conversion(pages: [], skipped: [], strokeCount: 0, pageCount: 0))
    }

    func testImportedPageSurvivesTheCodec() throws {
        let page = WebImport.convert(try doc(Self.sample)).pages[0]
        let data = try InkPageCodec.encode(page)
        XCTAssertEqual(try InkPageCodec.decode(data), page)
        XCTAssertEqual(try InkPageCodec.decode(try InkPageCodec.decompress(try InkPageCodec.compress(data))), page)
    }
}
