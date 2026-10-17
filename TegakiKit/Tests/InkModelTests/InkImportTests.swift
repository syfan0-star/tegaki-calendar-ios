import XCTest
import Foundation
import CoreGraphics
import InkModel

/// `InkImport` (M6_CONTRACT §1.2, 0-1, 0-11, 0-12): the two-format door, its errors (the same as
/// `WebImport.parse(_ data:)`), the outcome for the sheet, the byte scan that splits an app export
/// into pages, and the page-by-page read being equal to the whole-tree read. The same checks run in
/// KitChecks.
final class InkImportTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5, force: Double = 0.5) -> InkPoint {
        InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: CGFloat(force), azimuth: 1.5708, altitude: 0.7854)
    }

    private func stroke(_ id: String, cell: CellKey? = nil, tool: InkTool = .pen, color: String = "#1f2937", t: Int = 1_760_150_400_123, dev: String? = "ipad-1", points: [InkPoint]? = nil) -> InkStroke {
        InkStroke(id: id, cell: cell ?? .day(day(2026, 10, 4)), tool: tool, color: color, t: t, dev: dev, points: points ?? [point(10, 20), point(30.06, 40.04, dt: 16), point(50, 90, dt: 32)])
    }

    private func monthPage() -> InkPage {
        var page = InkPage.empty(pageId: "m1-2026-10")
        page.add(stroke("a", points: [point(10, 20), point(30.06, 40.04, dt: 16)]))
        page.add(stroke("b", cell: .memo, tool: .marker, color: "#FDE047", t: 7, dev: nil, points: [point(0, 100, size: 18), point(5, 120, dt: 16, size: 18)]))
        page.remove(ids: ["c"], at: 1_760_150_500_000)
        page.unknown["future"] = .object(["a": .array([.number(1), .number(2.5), .string("x"), .null, .bool(true)])])
        page.unknownStrokes["u"] = .object(["id": .string("u"), "cell": .string("memo"), "tool": .string("crayon"), "pts": .array([.number(1), .number(2)]), "wax": .bool(true)])
        return page
    }

    private func oldWeekPage() -> InkPage {
        var page = InkPage.empty(pageId: "w-2026-10-05")
        page.add(stroke("w1", cell: .allDay(day(2026, 10, 7)), points: [point(12, 40), point(17, 43, dt: 16)]))
        page.add(stroke("w2", cell: .grid, points: [point(300, 500)]))
        return page
    }

    private func tombstonePage() -> InkPage {
        var page = InkPage.empty(pageId: "d-2026-10-07")
        page.remove(ids: ["zz"], at: 1_760_000_000_500)
        return page
    }

    private func threePages() -> AppExport.Document {
        AppExport.Document(exportedAt: "2026-10-17T21:03:00+09:00", app: "ios/1.0 (12)", pages: [tombstonePage(), monthPage(), BandMigration.migrate(oldWeekPage())])
    }

    private func importError(_ s: String) -> WebImport.ParseError? {
        do {
            _ = try InkImport.parse(Data(s.utf8))
            return nil
        } catch let e as WebImport.ParseError {
            return e
        } catch {
            return nil
        }
    }

    private func webError(_ s: String) -> WebImport.ParseError? {
        do {
            _ = try WebImport.parse(Data(s.utf8))
            return nil
        } catch let e as WebImport.ParseError {
            return e
        } catch {
            return nil
        }
    }

    /// `topLevelMembers` as key → the member's text.
    private func members(_ s: String) -> [String: String]? {
        let data = Data(s.utf8)
        return InkImport.topLevelMembers(data)?.mapValues { String(decoding: data[$0], as: UTF8.self) }
    }

    /// `arrayElements` of the whole text as element texts.
    private func elements(_ s: String) -> [String]? {
        let data = Data(s.utf8)
        return InkImport.arrayElements(data, in: data.startIndex..<data.endIndex)?.map { String(decoding: data[$0], as: UTF8.self) }
    }

    // MARK: Dispatch (§1.2)

    func testParseDispatchesOnFormat() throws {
        let webData = Data(WebImportTests.sample.utf8)
        XCTAssertEqual(try InkImport.parse(webData), .web(try WebImport.parse(webData)), "the web sample → .web, the same document as WebImport.parse")
        XCTAssertEqual(try InkImport.parse(Data(WebImportTests.expected.utf8)), .web(try WebImport.parse(Data(WebImportTests.expected.utf8))))
        let doc = threePages()
        XCTAssertEqual(try InkImport.parse(AppExport.encode(doc)), .app(doc, skipped: 0), "an app export → .app")
        XCTAssertEqual(try InkImport.parse(AppExport.jsonValue(doc).serializedData()), .app(doc, skipped: 0), "the compact form too")
        XCTAssertEqual(try InkImport.parse(Data(#"{ "format": "tegaki-app-export" }"#.utf8)), .app(AppExport.Document(exportedAt: "", app: "", pages: []), skipped: 0), "a bare app export")
        XCTAssertEqual(try InkImport.parse(Data(#"{ "format": "tegaki-web-export" }"#.utf8)), .web(WebImport.Document(exportedAt: nil, app: nil, includesDemo: false, pages: [])), "a bare web export")
        XCTAssertEqual(importError(#"{ "format": "something-else", "v": 1, "pages": [] }"#), .notAnExport, "neither format")
    }

    func testErrorsMatchWebImport() {
        XCTAssertEqual(importError(#"{ "format": "something-else", "v": 1, "pages": [] }"#), .notAnExport)
        XCTAssertEqual(importError(#"{ "v": 1, "pages": [] }"#), .notAnExport, "missing format")
        XCTAssertEqual(importError(#"{ "format": 7, "pages": [] }"#), .notAnExport, "a non-string format")
        XCTAssertEqual(importError(#"[1, 2, 3]"#), .notAnExport, "an array")
        XCTAssertEqual(importError(#""tegaki-app-export""#), .notAnExport, "a bare string")
        XCTAssertEqual(importError(#"{ "format": "tegaki-web-export", "v": 2, "pages": [] }"#), .unsupportedVersion(2))
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 2, "pages": [] }"#), .unsupportedVersion(2))
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 7 }"#), .unsupportedVersion(7))
        XCTAssertNil(importError(#"{ "format": "tegaki-app-export", "v": "x" }"#), "an unusable v counts as 1")
        XCTAssertEqual(importError(#"{ "format": "tegaki-web-export", "v": 1, "pages": ["#), .invalidJSON, "truncated")
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": [ { "pageId": "m1-2026-10" "#), .invalidJSON, "a truncated app export")
        XCTAssertEqual(importError("not json at all"), .invalidJSON)
        XCTAssertEqual(importError(""), .invalidJSON)
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "pages": "x" }"#), .notAnExport, "pages that is not an array")
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "pages": [ { "pageId": "m1-2026-10", "strokes": { "a": tru } } ] }"#), .invalidJSON, "a broken page element")
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": tru }"#), .invalidJSON, "a broken v")
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "pages": [], "junk": abc }"#), .invalidJSON, "a broken member the reader does not use (as the whole-tree read)")
        XCTAssertNil(importError(#"{ "format": "tegaki-app-export", "pages": [], "junk": { "a": [1, 2] } }"#), "an unknown member that is JSON is ignored")
        XCTAssertEqual(importError(#"{ "v": 1, "junk": abc }"#), .invalidJSON, "no format and broken JSON → invalidJSON, not notAnExport (the whole-tree read decides)")
        XCTAssertEqual(importError(#"{ "format": "foo", "x": abc }"#), .invalidJSON, "another format and broken JSON → invalidJSON")
        XCTAssertEqual(importError(#"{ "format": 7, "x": abc }"#), .invalidJSON, "a non-string format and broken JSON → invalidJSON")
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "pages": abc }"#), .invalidJSON, "pages that is not JSON → invalidJSON")
        // The same type and values as WebImport.parse(_ data:) for everything that is not an app export.
        for s in [#"{ "format": "something-else", "v": 1, "pages": [] }"#, #"{ "v": 1 }"#, #"[1]"#, #""x""#, #"{ "format": "tegaki-web-export", "v": 3 }"#, #"{ "format": "tegaki-web-export", "v": 1, "pages": ["#, "{", "", "nope", #"{ "format": "tegaki-web-export" }"#, #"{ "v": 1, "junk": abc }"#, #"{ "format": "foo", "x": abc }"#, #"{ "format": 7, "x": abc }"#] {
            XCTAssertEqual(importError(s), webError(s), s.isEmpty ? "empty data" : s)
        }
    }

    // MARK: Outcome (§1.2, 0-12)

    func testPagesOutcome() throws {
        let webDocument = try WebImport.parse(Data(WebImportTests.sample.utf8))
        let conversion = WebImport.convert(webDocument)
        let outcome = InkImport.pages(.web(webDocument))
        XCTAssertEqual(outcome.pages, conversion.pages)
        XCTAssertEqual(outcome.pages.count, 4)
        XCTAssertEqual(outcome.skipped, conversion.skipped.count)
        XCTAssertEqual(outcome.skipped, 2, "legacy id, no strokes")
        XCTAssertEqual(outcome.pageCount, conversion.pageCount)
        XCTAssertEqual(outcome.pageCount, 4)
        XCTAssertFalse(outcome.isAppExport)

        let doc = threePages()
        let appOutcome = InkImport.pages(.app(doc, skipped: 2))
        XCTAssertEqual(appOutcome.pages, doc.pages)
        XCTAssertEqual(appOutcome.skipped, 2)
        XCTAssertEqual(appOutcome.pageCount, 5, "pages + skipped")
        XCTAssertTrue(appOutcome.isAppExport)
        XCTAssertEqual(InkImport.pages(.app(AppExport.Document(exportedAt: "", app: "", pages: []), skipped: 0)), InkImport.Outcome(pages: [], skipped: 0, pageCount: 0, isAppExport: true))
        XCTAssertEqual(InkImport.pages(try InkImport.parse(AppExport.encode(doc))), InkImport.Outcome(pages: doc.pages, skipped: 0, pageCount: 3, isAppExport: true), "the restore path")

        // Dropped elements are counted by parse.
        let mixed = #"{ "format": "tegaki-app-export", "v": 1, "exportedAt": "2026-10-17T21:03:00+09:00", "app": "ios/1.0 (12)", "pages": [ 5, { "pageId": "" }, \#(AppExport.pageText(monthPage())), "x", \#(AppExport.pageText(oldWeekPage())) ] }"#
        let mixedOutcome = InkImport.pages(try InkImport.parse(Data(mixed.utf8)))
        XCTAssertEqual(mixedOutcome, InkImport.Outcome(pages: [monthPage(), BandMigration.migrate(oldWeekPage())], skipped: 3, pageCount: 5, isAppExport: true))

        // Restoring merges with InkPage.merge: idempotent, tombstones win (SUPPORT FAQ).
        for page in doc.pages {
            XCTAssertEqual(InkPage.merge(page, page), page, page.pageId)
        }
        var local = monthPage()
        local.remove(ids: ["a"], at: 1_760_150_600_000)
        XCTAssertEqual(InkPage.merge(local, monthPage()).liveStrokeIds, ["b"], "a stroke erased after the export does not come back")
    }

    func testWebParseDataIsUnchanged() throws {
        for text in [WebImportTests.sample, WebImportTests.expected, #"{ "format": "tegaki-web-export" }"#, #"{ "format": "tegaki-web-export", "v": 1, "pages": [1, "x", null] }"#, #"{ "format": "tegaki-web-export", "v": 1, "pages": "x", "includesDemo": true, "app": 5 }"#] {
            let data = Data(text.utf8)
            XCTAssertEqual(try WebImport.parse(data), try WebImport.parse(json: try JSONValue.parse(data)), text)
            XCTAssertEqual(try InkImport.parse(data), .web(try WebImport.parse(data)), text)
        }
        XCTAssertEqual(try WebImport.parse(Data(WebImportTests.sample.utf8)).pages.count, 6)
        XCTAssertEqual(try WebImport.parse(Data(WebImportTests.sample.utf8)).pages.map(\.pageId), ["m1-2026-10", "w-2026-10-05", "d-2026-10-07", "y-2026", "m-2026-09", "d-2026-10-08"])
        XCTAssertThrowsError(try WebImport.parse(json: .array([.number(1)]))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .notAnExport)
        }
        XCTAssertThrowsError(try WebImport.parse(json: .object(["format": .string("tegaki-web-export"), "v": .number(2)]))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .unsupportedVersion(2))
        }
        XCTAssertThrowsError(try WebImport.parse(json: .object(["format": .string("tegaki-app-export")]))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .notAnExport, "the app format is not the web format")
        }
    }

    // MARK: The byte scan (0-11)

    func testTopLevelMembersAndArrayElements() throws {
        XCTAssertEqual(members(#"{"a":1,"b":"x","c":[1,2],"d":{"e":[]},"f":null,"g":true}"#), ["a": "1", "b": "\"x\"", "c": "[1,2]", "d": "{\"e\":[]}", "f": "null", "g": "true"], "compact")
        XCTAssertEqual(members(" \n{\n  \"a\": 1,\n  \"b\": [\n    1,\n    2\n  ],\n  \"c\": -1.5e3\n}\n"), ["a": "1", "b": "[\n    1,\n    2\n  ]", "c": "-1.5e3"], "pretty, ranges without the surrounding whitespace")
        XCTAssertEqual(members(#"{"s":"a}b]c{d[e","t":"q\"r\\","u":"\\\\","v":"\"{\"","w":"[\\\"]"}"#), ["s": #""a}b]c{d[e""#, "t": #""q\"r\\""#, "u": #""\\\\""#, "v": #""\"{\"""#, "w": #""[\\\"]""#], "brackets and escaped quotes inside strings")
        XCTAssertEqual(members(#"{"k\"ey":1,"k\\":2,"A":3}"#), ["k\"ey": "1", "k\\": "2", "A": "3"], "keys are decoded as JSON strings")
        XCTAssertEqual(members(#"{"a":1,"a":2}"#), ["a": "2"], "a repeated key keeps the later value")
        XCTAssertEqual(members("{}"), [:])
        XCTAssertEqual(members(" { } "), [:])
        XCTAssertEqual(members(#"{"p":[{"x":[[1,[2]],{"y":{}}]}],"q":{"r":{"s":[[],{}]}}}"#), ["p": #"[{"x":[[1,[2]],{"y":{}}]}]"#, "q": #"{"r":{"s":[[],{}]}}"#], "nested containers")
        XCTAssertEqual(members(#"{"a":[],"b":{},"c":""}"#), ["a": "[]", "b": "{}", "c": "\"\""], "empty array, object and string")
        XCTAssertEqual(members("{\"a\":1}\n\n"), ["a": "1"], "trailing newlines")
        XCTAssertNil(members("\u{FEFF}{\"a\":1}"), "a byte order mark is not whitespace (the whole-tree path decides)")
        XCTAssertNil(members(#"[1, 2]"#), "an array")
        XCTAssertNil(members(#""x""#), "a string")
        XCTAssertNil(members("1"), "a number")
        XCTAssertNil(members(""))
        XCTAssertNil(members("   "))
        XCTAssertNil(members(#"{"a":[1,2}"#), "a mismatched bracket")
        XCTAssertNil(members(#"{"a":{"b":1]}"#), "a mismatched brace")
        XCTAssertNil(members(#"{"a":1"#), "unclosed")
        XCTAssertNil(members(#"{"a":[1,2"#), "an unclosed array")
        XCTAssertNil(members(#"{"a":"unterminated}"#), "an unterminated string")
        XCTAssertNil(members(#"{"a" 1}"#), "no colon")
        XCTAssertNil(members(#"{"a":}"#), "no value")
        XCTAssertNil(members(#"{"a":,"b":1}"#), "a missing value before a comma")
        XCTAssertNil(members(#"{"a":1,}"#), "a trailing comma")
        XCTAssertNil(members(#"{,"a":1}"#), "a leading comma")
        XCTAssertNil(members(#"{a:1}"#), "an unquoted key")
        XCTAssertNil(members(#"{"a":1} x"#), "trailing garbage")
        XCTAssertNil(members(#"{"a":1}}"#), "an extra closer")
        XCTAssertNil(members(#"{"a":1 "b":2}"#), "members without a comma")

        XCTAssertEqual(elements("[1, 2 ,3]"), ["1", "2", "3"])
        XCTAssertEqual(elements("[]"), [])
        XCTAssertEqual(elements("[ \n ]"), [])
        XCTAssertEqual(elements("  [1]  "), ["1"], "whitespace around the array")
        XCTAssertEqual(elements("[\n    {\"a\":1},\n    {\"b\":[1,2]}\n  ]"), ["{\"a\":1}", "{\"b\":[1,2]}"], "pretty objects")
        XCTAssertEqual(elements(#"["a]b", "c,d", "e\"]", "\\"]"#), [#""a]b""#, #""c,d""#, #""e\"]""#, #""\\""#], "brackets, commas and escapes inside strings")
        XCTAssertEqual(elements(#"[[1,[2,3]],{"x":[]},[],{}]"#), ["[1,[2,3]]", #"{"x":[]}"#, "[]", "{}"], "nested and empty containers")
        XCTAssertEqual(elements("[true,false,null,-0.5e-3]"), ["true", "false", "null", "-0.5e-3"])
        XCTAssertNil(elements("1"), "a number")
        XCTAssertNil(elements(#"{"a":1}"#), "an object")
        XCTAssertNil(elements(#""x""#), "a string")
        XCTAssertNil(elements(""))
        XCTAssertNil(elements("[1,2"), "unclosed")
        XCTAssertNil(elements("[1,2}"), "a mismatched closer")
        XCTAssertNil(elements("[[1]"), "an unclosed inner array")
        XCTAssertNil(elements("[1,]"), "a trailing comma")
        XCTAssertNil(elements("[,1]"), "a leading comma")
        XCTAssertNil(elements("[1,,2]"), "a missing element")
        XCTAssertNil(elements("[1 2]"), "elements without a comma")
        XCTAssertNil(elements("[1] x"), "trailing garbage")
        XCTAssertNil(elements("[\"a]"), "an unterminated string")
        let small = Data("[1,2]".utf8)
        XCTAssertNil(InkImport.arrayElements(small, in: 0..<6), "a range past the end")
        XCTAssertEqual(InkImport.arrayElements(small, in: 0..<5)?.count, 2)
        XCTAssertNil(InkImport.arrayElements(small, in: 1..<4), "a range that does not start at [")

        // An export: the 5 members, the pages array, one range per page; a slice works the same.
        let doc = threePages()
        let data = AppExport.encode(doc)
        let found = try XCTUnwrap(InkImport.topLevelMembers(data))
        XCTAssertEqual(found.keys.sorted(), ["app", "exportedAt", "format", "pages", "v"])
        XCTAssertEqual(String(decoding: data[try XCTUnwrap(found["format"])], as: UTF8.self), "\"tegaki-app-export\"")
        XCTAssertEqual(String(decoding: data[try XCTUnwrap(found["v"])], as: UTF8.self), "1")
        XCTAssertEqual(String(decoding: data[try XCTUnwrap(found["exportedAt"])], as: UTF8.self), "\"2026-10-17T21:03:00+09:00\"")
        XCTAssertEqual(String(decoding: data[try XCTUnwrap(found["pages"])], as: UTF8.self), "[\n" + doc.pages.map(AppExport.pageText).joined(separator: ",\n") + "\n  ]")
        let pageRanges = try XCTUnwrap(InkImport.arrayElements(data, in: try XCTUnwrap(found["pages"])))
        XCTAssertEqual(pageRanges.count, 3)
        XCTAssertEqual(pageRanges.map { String(decoding: data[$0], as: UTF8.self) }, doc.pages.map { String(AppExport.pageText($0).dropFirst(4)) })
        XCTAssertEqual(try pageRanges.map { AppExport.parsePage(try JSONValue.parse(data[$0])) }, doc.pages.map { Optional($0) })
        let padded = Data("xxxx".utf8) + data
        let slice = padded[4...]
        XCTAssertEqual(slice.startIndex, 4)
        let sliceMembers = try XCTUnwrap(InkImport.topLevelMembers(slice))
        XCTAssertEqual(String(decoding: slice[try XCTUnwrap(sliceMembers["v"])], as: UTF8.self), "1", "ranges index the slice")
        XCTAssertEqual(InkImport.arrayElements(slice, in: try XCTUnwrap(sliceMembers["pages"]))?.count, 3)
        XCTAssertEqual(try InkImport.parse(slice), .app(doc, skipped: 0), "parsing a slice")
    }

    func testStreamedParseEqualsWholeParse() throws {
        let doc = threePages()
        let pretty = AppExport.encode(doc)
        let compact = AppExport.jsonValue(doc).serializedData()
        let odd = Data(("\n\n" + String(decoding: pretty, as: UTF8.self).replacingOccurrences(of: "\n", with: "\r\n") + "\t\n").utf8)
        for (name, data) in [("pretty", pretty), ("compact", compact), ("odd whitespace", odd)] {
            let streamed = try InkImport.parse(data)
            let whole = try AppExport.parse(json: try JSONValue.parse(data))
            XCTAssertEqual(streamed, .app(whole, skipped: 0), name)
            XCTAssertEqual(whole, doc, name)
        }
        // Dropped elements: the same pages, skipped = elements − pages.
        let mixed = #"{ "format": "tegaki-app-export", "v": 1, "exportedAt": "2026-10-17T21:03:00+09:00", "app": "ios/1.0 (12)", "pages": [ 5, { "pageId": "" }, \#(AppExport.pageText(monthPage())), "x", \#(AppExport.pageText(oldWeekPage())) ] }"#
        let mixedData = Data(mixed.utf8)
        let whole = try AppExport.parse(json: try JSONValue.parse(mixedData))
        XCTAssertEqual(try InkImport.parse(mixedData), .app(whole, skipped: 3))
        XCTAssertEqual(whole.pages, [monthPage(), BandMigration.migrate(oldWeekPage())], "the band page is migrated on both paths")
        // A broken page element → invalidJSON; pages that is not an array → notAnExport.
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": [ { "pageId": "m1-2026-10", "strokes": { "a": tru } } ] }"#), .invalidJSON)
        // Whether a trailing comma is JSON is JSONSerialization's call (it differs between OS versions): the
        // page-by-page read hands such an array to the whole-tree path, so the two agree either way.
        let trailing = Data(#"{ "format": "tegaki-app-export", "v": 1, "pages": [ { "pageId": "m1-2026-10" }, ] }"#.utf8)
        if let wholeJSON = try? JSONValue.parse(trailing) {
            XCTAssertEqual(try InkImport.parse(trailing), .app(try AppExport.parse(json: wholeJSON), skipped: 0), "a trailing comma JSONSerialization accepts → the same document as the whole-tree read")
        } else {
            XCTAssertEqual(importError(String(decoding: trailing, as: UTF8.self)), .invalidJSON, "a trailing comma JSONSerialization rejects → invalidJSON")
        }
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": [ { "pageId": "m1-2026-10" } { "pageId": "y-2026" } ] }"#), .invalidJSON, "elements without a comma")
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": "x" }"#), .notAnExport)
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": { "a": 1 } }"#), .notAnExport)
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": null }"#), .notAnExport)
        XCTAssertEqual(importError(#"{ "format": "tegaki-app-export", "v": 1, "pages": abc }"#), .invalidJSON, "pages that is not JSON: invalidJSON as the whole-tree read")
        XCTAssertThrowsError(try AppExport.parse(json: try JSONValue.parse(Data(#"{ "format": "tegaki-app-export", "v": 1, "pages": "x" }"#.utf8)))) { error in
            XCTAssertEqual(error as? WebImport.ParseError, .notAnExport, "the whole-tree read agrees")
        }
    }
}
