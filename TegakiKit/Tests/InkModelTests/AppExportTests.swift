import XCTest
import Foundation
import CoreGraphics
import InkModel

/// `AppExport` and `JSONValue.serialized(pretty:)` (M6_CONTRACT §1.1, §1.3, §1.5, §7.2): the export
/// document's shape, the streamed parts that make the same bytes, the pretty-print rules, the
/// unchanged compact form, the page round trip, the parser's reasons to throw and the file names.
/// The same checks run in KitChecks.
final class AppExportTests: XCTestCase {
    private let jst = TimeZone(identifier: "Asia/Tokyo")!
    private let utc = TimeZone(identifier: "UTC")!

    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = jst
        return c
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ mi: Int, calendar: Calendar? = nil) -> Date {
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        c.hour = h
        c.minute = mi
        return (calendar ?? tokyo).date(from: c)!
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5, force: Double = 0.5) -> InkPoint {
        InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: CGFloat(force), azimuth: 1.5708, altitude: 0.7854)
    }

    private func stroke(_ id: String, cell: CellKey? = nil, tool: InkTool = .pen, color: String = "#1f2937", t: Int = 1_760_150_400_123, dev: String? = "ipad-1", points: [InkPoint]? = nil) -> InkStroke {
        InkStroke(id: id, cell: cell ?? .day(day(2026, 10, 4)), tool: tool, color: color, t: t, dev: dev, points: points ?? [point(10, 20), point(30.06, 40.04, dt: 16), point(50, 90, dt: 32)])
    }

    /// A month page with a pen, a marker without dev, a tombstone, an unknown key and an unknown stroke.
    private func monthPage() -> InkPage {
        var page = InkPage.empty(pageId: "m1-2026-10")
        page.add(stroke("a", points: [point(10, 20), point(30.06, 40.04, dt: 16)]))
        page.add(stroke("b", cell: .memo, tool: .marker, color: "#FDE047", t: 7, dev: nil, points: [point(0, 100, size: 18), point(5, 120, dt: 16, size: 18)]))
        page.remove(ids: ["c"], at: 1_760_150_500_000)
        page.unknown["future"] = .object(["a": .array([.number(1), .number(2.5), .string("x"), .null, .bool(true)])])
        page.unknownStrokes["u"] = .object(["id": .string("u"), "cell": .string("memo"), "tool": .string("crayon"), "pts": .array([.number(1), .number(2)]), "wax": .bool(true)])
        return page
    }

    /// A week page written before M4b: a stroke in the all-day band cell and one on the grid.
    private func oldWeekPage() -> InkPage {
        var page = InkPage.empty(pageId: "w-2026-10-05")
        page.add(stroke("w1", cell: .allDay(day(2026, 10, 7)), points: [point(12, 40), point(17, 43, dt: 16)]))
        page.add(stroke("w2", cell: .grid, points: [point(300, 500)]))
        return page
    }

    /// A day page with a tombstone only.
    private func tombstonePage() -> InkPage {
        var page = InkPage.empty(pageId: "d-2026-10-07")
        page.remove(ids: ["zz"], at: 1_760_000_000_500)
        return page
    }

    private func document(_ pages: [InkPage]) -> AppExport.Document {
        AppExport.Document(exportedAt: "2026-10-17T21:03:00+09:00", app: "ios/1.0 (12)", pages: pages)
    }

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    private func json(_ s: String) throws -> JSONValue { try JSONValue.parse(Data(s.utf8)) }

    private func parseError(_ s: String) -> WebImport.ParseError? {
        do {
            _ = try AppExport.parse(json: try json(s))
            return nil
        } catch let e as WebImport.ParseError {
            return e
        } catch {
            return nil
        }
    }

    // MARK: Document shape (§1.1)

    func testDocumentShapeAndKeyOrder() throws {
        XCTAssertEqual(AppExport.format, "tegaki-app-export")
        XCTAssertEqual(AppExport.supportedVersion, 1)
        XCTAssertEqual(AppExport.exportedAtText(date(2026, 10, 17, 21, 3), timeZone: jst), "2026-10-17T21:03:00+09:00")
        XCTAssertEqual(AppExport.exportedAtText(date(2026, 10, 17, 21, 3), timeZone: utc), "2026-10-17T12:03:00Z")
        XCTAssertEqual(AppExport.exportedAtText(Date(timeIntervalSince1970: 1_760_000_000.7), timeZone: utc), "2025-10-09T08:53:20Z", "to the second")

        let doc = document([tombstonePage(), monthPage(), BandMigration.migrate(oldWeekPage())])
        let value = AppExport.jsonValue(doc)
        XCTAssertEqual(value.objectValue?.keys.sorted(), ["app", "exportedAt", "format", "pages", "v"], "the 5 keys")
        XCTAssertEqual(value["format"], .string("tegaki-app-export"))
        XCTAssertEqual(value["v"], .number(1))
        XCTAssertEqual(value["exportedAt"], .string("2026-10-17T21:03:00+09:00"))
        XCTAssertEqual(value["app"], .string("ios/1.0 (12)"))
        XCTAssertEqual(value["pages"]?.arrayValue?.count, 3)
        XCTAssertEqual(value["pages"]?.arrayValue?[1], monthPage().jsonValue, "pages[i] is InkPage.jsonValue itself")
        XCTAssertEqual(value["pages"]?.arrayValue?[0], tombstonePage().jsonValue, "a tombstone-only page is written (M6-6)")

        let encoded = text(AppExport.encode(doc))
        XCTAssertTrue(encoded.hasPrefix("{\n  \"app\": \"ios/1.0 (12)\",\n  \"exportedAt\": \"2026-10-17T21:03:00+09:00\",\n  \"format\": \"tegaki-app-export\",\n  \"pages\": [\n    {\n"), encoded)
        XCTAssertTrue(encoded.hasSuffix("\n    }\n  ],\n  \"v\": 1\n}\n"), encoded)
        XCTAssertEqual(encoded, AppExport.jsonValue(doc).serialized(pretty: true) + "\n", "encode is the pretty tree plus a final newline")
        XCTAssertEqual(try AppExport.parse(json: try JSONValue.parse(AppExport.encode(doc))), doc, "and parses back to the same document")
        XCTAssertEqual(try AppExport.parse(json: try JSONValue.parse(AppExport.jsonValue(doc).serializedData())), doc, "the compact tree parses back too")
        XCTAssertEqual(AppExport.jsonValue(document([]))["pages"], .array([]))
    }

    func testEncodeEqualsStreamedParts() throws {
        XCTAssertEqual(AppExport.pageSeparator, ",\n")
        XCTAssertEqual(AppExport.footer, "\n  ],\n  \"v\": 1\n}\n")
        XCTAssertEqual(AppExport.header(exportedAt: "2026-10-17T21:03:00+09:00", app: "ios/1.0 (12)"), "{\n  \"app\": \"ios/1.0 (12)\",\n  \"exportedAt\": \"2026-10-17T21:03:00+09:00\",\n  \"format\": \"tegaki-app-export\",\n  \"pages\": [\n")
        XCTAssertEqual(AppExport.header(exportedAt: "a\"b", app: "c\\d"), "{\n  \"app\": \"c\\\\d\",\n  \"exportedAt\": \"a\\\"b\",\n  \"format\": \"tegaki-app-export\",\n  \"pages\": [\n", "the header escapes its strings")

        func streamed(_ doc: AppExport.Document) -> Data {
            Data((AppExport.header(exportedAt: doc.exportedAt, app: doc.app) + doc.pages.map(AppExport.pageText).joined(separator: AppExport.pageSeparator) + AppExport.footer).utf8)
        }
        let one = document([monthPage()])
        let three = document([tombstonePage(), monthPage(), BandMigration.migrate(oldWeekPage())])
        let none = document([])
        XCTAssertEqual(streamed(one), AppExport.encode(one), "1 page")
        XCTAssertEqual(streamed(three), AppExport.encode(three), "3 pages")
        XCTAssertEqual(streamed(none), AppExport.encode(none), "0 pages")
        XCTAssertEqual(try AppExport.parse(json: try JSONValue.parse(streamed(none))), none, "the 0-page stream is still valid JSON")

        let pageText = AppExport.pageText(monthPage())
        XCTAssertTrue(pageText.hasPrefix("    {\n"))
        XCTAssertTrue(pageText.hasSuffix("\n    }"), "no trailing newline")
        XCTAssertTrue(pageText.split(separator: "\n", omittingEmptySubsequences: false).allSatisfy { $0.hasPrefix("    ") }, "every line is indented 4 spaces")
        XCTAssertEqual(pageText, """
            {
              "deleted": {
                "c": 1760150500000
              },
              "future": {
                "a": [
                  1,
                  2.5,
                  "x",
                  null,
                  true
                ]
              },
              "pageId": "m1-2026-10",
              "strokes": {
                "a": {
                  "cell": "2026-10-04",
                  "color": "#1f2937",
                  "dev": "ipad-1",
                  "id": "a",
                  "pts": [10, 20, 0, 3.5, 3.5, 1, 0.5, 1.571, 0.785, 30.1, 40, 16, 3.5, 3.5, 1, 0.5, 1.571, 0.785],
                  "t": 1760150400123,
                  "tool": "pen"
                },
                "b": {
                  "cell": "memo",
                  "color": "#fde047",
                  "id": "b",
                  "pts": [0, 100, 0, 18, 18, 1, 0.5, 1.571, 0.785, 5, 120, 16, 18, 18, 1, 0.5, 1.571, 0.785],
                  "t": 7,
                  "tool": "marker"
                },
                "u": {
                  "cell": "memo",
                  "id": "u",
                  "pts": [1, 2],
                  "tool": "crayon",
                  "wax": true
                }
              },
              "updatedAt": 1760150500000,
              "v": 1
            }
        """)
        XCTAssertEqual(AppExport.pageText(tombstonePage()), "    {\n      \"deleted\": {\n        \"zz\": 1760000000500\n      },\n      \"pageId\": \"d-2026-10-07\",\n      \"strokes\": {},\n      \"updatedAt\": 1760000000500,\n      \"v\": 1\n    }")
    }

    // MARK: Pretty JSON (§1.3)

    func testPrettyJSONRules() throws {
        let value: JSONValue = .object([
            "b": .array([.number(1), .number(2.5), .number(-0.0), .number(1e21)]),
            "a": .object([:]),
            "c": .array([.string("x"), .number(1), .null]),
            "d": .array([]),
            "e": .object(["f": .object(["g": .array([.array([.number(1)]), .object([:])])])]),
            "s": .string("a\"b\\c\n\u{1}"),
            "n": .null,
            "t": .bool(false),
        ])
        XCTAssertEqual(value.serialized(pretty: true), """
        {
          "a": {},
          "b": [1, 2.5, 0, 1e+21],
          "c": [
            "x",
            1,
            null
          ],
          "d": [],
          "e": {
            "f": {
              "g": [
                [1],
                {}
              ]
            }
          },
          "n": null,
          "s": "a\\"b\\\\c\\n\\u0001",
          "t": false
        }
        """)
        XCTAssertEqual(try JSONValue.parse(Data(value.serialized(pretty: true).utf8)), value, "parses back")
        XCTAssertEqual(JSONValue.array([.number(1), .number(2), .number(3)]).serialized(pretty: true), "[1, 2, 3]", "a number array is one line")
        XCTAssertEqual(JSONValue.array([.number(3), .number(0.1), .number(.infinity)]).serialized(pretty: true), "[3, 0.1, null]", "numbers use format(_:)")
        XCTAssertEqual(JSONValue.array([]).serialized(pretty: true), "[]")
        XCTAssertEqual(JSONValue.object([:]).serialized(pretty: true), "{}")
        XCTAssertEqual(JSONValue.object(["n": .number(.nan)]).serialized(pretty: true), "{\n  \"n\": null\n}")
        XCTAssertEqual(JSONValue.array([.number(1), .string("x")]).serialized(pretty: true), "[\n  1,\n  \"x\"\n]", "a mixed array is one element per line")
        XCTAssertEqual(JSONValue.array([.array([.number(1)])]).serialized(pretty: true), "[\n  [1]\n]")
        XCTAssertEqual(JSONValue.object(["k": .number(1)]).serialized(pretty: true), "{\n  \"k\": 1\n}")
        XCTAssertEqual(JSONValue.object(["k": .object(["m": .number(1)])]).serialized(pretty: true, indent: 4), "{\n      \"k\": {\n        \"m\": 1\n      }\n    }", "indent 4: inner lines at 6 / 8, the closer at 4")
        XCTAssertEqual(JSONValue.array([.array([.number(1)]), .string("x")]).serialized(pretty: true, indent: 2), "[\n    [1],\n    \"x\"\n  ]")
        XCTAssertEqual(JSONValue.string("x").serialized(pretty: true), "\"x\"")
        XCTAssertEqual(JSONValue.null.serialized(pretty: true), "null")
        XCTAssertEqual(JSONValue.bool(true).serialized(pretty: true), "true")
        XCTAssertEqual(JSONValue.number(3).serialized(pretty: true), "3")
        XCTAssertEqual(value.serializedData(pretty: true), Data(value.serialized(pretty: true).utf8))
    }

    func testCompactSerializationIsUnchanged() throws {
        // The M2 fixed string (InkModelTests.testJSONValueSerialization).
        let value: JSONValue = .object(["b": .array([.number(1), .number(2.5), .number(-0.0), .number(1e21), .string("a\"b\\c\n\u{1}"), .null, .bool(false)]), "a": .object([:])])
        XCTAssertEqual(value.serialized(), "{\"a\":{},\"b\":[1,2.5,0,1e+21,\"a\\\"b\\\\c\\n\\u0001\",null,false]}")
        XCTAssertEqual(value.serialized(pretty: false), value.serialized())
        XCTAssertEqual(value.serialized(pretty: false, indent: 4), value.serialized(), "indent is ignored in the compact form")
        XCTAssertEqual(value.serializedData(), Data(value.serialized().utf8))
        XCTAssertEqual(value.serializedData(pretty: false), value.serializedData())
        // The stored page bytes (InkModelTests.testJSONRoundTripAndShape).
        var original = InkPage.empty(pageId: "m1-2026-10")
        original.add(stroke("a"))
        original.add(stroke("b", tool: .marker, color: "#FDE047", t: 7, dev: nil))
        original.remove(ids: ["c"], at: 1_760_150_500_000)
        let stored = text(try InkPageCodec.encode(original))
        XCTAssertTrue(stored.hasPrefix("{\"deleted\":{\"c\":1760150500000},\"pageId\":\"m1-2026-10\",\"strokes\":{\"a\":{\"cell\":\"2026-10-04\",\"color\":\"#1f2937\",\"dev\":\"ipad-1\",\"id\":\"a\",\"pts\":[10,20,0,3.5,3.5,1,0.5,1.571,0.785,"), stored)
        XCTAssertTrue(stored.hasSuffix(",\"updatedAt\":1760150500000,\"v\":1}"), stored)
        XCTAssertEqual(stored, original.jsonValue.serialized(), "InkPageCodec.encode is the compact form")
        XCTAssertFalse(stored.contains("\n"))
        XCTAssertFalse(stored.contains(": "))
        XCTAssertEqual(try InkPageCodec.decode(try InkPageCodec.encode(original)), original)
    }

    // MARK: Pages

    func testPageRoundTripsThroughInkPage() throws {
        let month = monthPage()
        let migrated = BandMigration.migrate(oldWeekPage())
        for page in [month, migrated, tombstonePage()] {
            let value = try JSONValue.parse(Data(AppExport.pageText(page).utf8))
            XCTAssertEqual(InkPage(json: value), page, page.pageId)
            XCTAssertEqual(AppExport.parsePage(value), page, page.pageId)
        }
        let back = InkPage(json: try JSONValue.parse(Data(AppExport.pageText(month).utf8)))
        XCTAssertEqual(back.strokes["a"]?.tool, .pen)
        XCTAssertEqual(back.strokes["a"]?.dev, "ipad-1", "dev is kept (§1.1)")
        XCTAssertEqual(back.strokes["a"]?.points, month.strokes["a"]?.points)
        XCTAssertEqual(back.strokes["b"]?.tool, .marker)
        XCTAssertEqual(back.strokes["b"]?.color, "#fde047")
        XCTAssertNil(back.strokes["b"]?.dev, "a stroke without dev stays without")
        XCTAssertEqual(back.deleted, ["c": 1_760_150_500_000], "the tombstone comes back")
        XCTAssertEqual(back.unknown["future"], month.unknown["future"], "unknown keys come back")
        XCTAssertEqual(back.unknownStrokes["u"], month.unknownStrokes["u"], "unknown strokes come back")
        XCTAssertEqual(back.updatedAt, month.updatedAt)
        XCTAssertEqual(back.v, 1)
        // Through the whole document as well.
        let doc = document([tombstonePage(), month, migrated])
        XCTAssertEqual(try AppExport.parse(json: try JSONValue.parse(AppExport.encode(doc))).pages, doc.pages)
    }

    func testIsWorthExporting() {
        XCTAssertFalse(AppExport.isWorthExporting(InkPage.empty(pageId: "m1-2026-10")))
        XCTAssertTrue(AppExport.isWorthExporting(monthPage()))
        XCTAssertTrue(AppExport.isWorthExporting(tombstonePage()), "tombstones only (M6-6)")
        XCTAssertTrue(AppExport.isWorthExporting(InkPage(pageId: "m1-2026-10", unknownStrokes: ["u": .object(["id": .string("u")])])), "unknown strokes only")
        XCTAssertFalse(AppExport.isWorthExporting(InkPage(pageId: "m1-2026-10", updatedAt: 5, unknown: ["future": .bool(true)])), "unknown top-level keys alone are not")
        var erased = monthPage()
        erased.remove(ids: ["a", "b", "u"], at: 1_760_150_600_000)
        XCTAssertEqual(erased.liveStrokeCount, 0)
        XCTAssertTrue(AppExport.isWorthExporting(erased), "the tombstones remain")
    }

    // MARK: Parsing (§1.2)

    func testParseRejectsOtherFormatsAndNewerVersions() throws {
        XCTAssertEqual(parseError(#"[1, 2]"#), .notAnExport, "not an object")
        XCTAssertEqual(parseError(#""tegaki-app-export""#), .notAnExport, "a bare string")
        XCTAssertEqual(parseError(#"{ "format": "tegaki-web-export", "v": 1, "pages": [] }"#), .notAnExport, "the web format")
        XCTAssertEqual(parseError(#"{ "format": "something-else", "v": 1 }"#), .notAnExport)
        XCTAssertEqual(parseError(#"{ "v": 1, "pages": [] }"#), .notAnExport, "missing format")
        XCTAssertEqual(parseError(#"{ "format": 1 }"#), .notAnExport, "a non-string format")
        XCTAssertEqual(parseError(#"{ "format": "tegaki-app-export", "v": 2, "pages": [] }"#), .unsupportedVersion(2))
        XCTAssertEqual(parseError(#"{ "format": "tegaki-app-export", "v": 7 }"#), .unsupportedVersion(7))
        XCTAssertEqual(parseError(#"{ "format": "tegaki-app-export", "pages": "x" }"#), .notAnExport, "pages that is not an array")
        XCTAssertNil(parseError(#"{ "format": "tegaki-app-export" }"#), "a missing v counts as 1 and missing pages as none")
        XCTAssertNil(parseError(#"{ "format": "tegaki-app-export", "v": 1.4 }"#), "v rounds")
        XCTAssertNil(parseError(#"{ "format": "tegaki-app-export", "v": "x" }"#), "an unusable v counts as 1")
        XCTAssertEqual(try AppExport.parse(json: try json(#"{ "format": "tegaki-app-export" }"#)), AppExport.Document(exportedAt: "", app: "", pages: []))
        XCTAssertEqual(try AppExport.parse(json: try json(#"{ "format": "tegaki-app-export", "exportedAt": 5, "app": null, "pages": [] }"#)), AppExport.Document(exportedAt: "", app: "", pages: []), "non-string exportedAt / app read as \"\"")
        let doc = document([tombstonePage(), monthPage()])
        XCTAssertEqual(try AppExport.parse(json: AppExport.jsonValue(doc)), doc)
        XCTAssertEqual(try AppExport.parse(json: AppExport.jsonValue(doc)).pages.map(\.pageId), ["d-2026-10-07", "m1-2026-10"], "document order is kept")
    }

    func testParseDropsPagesWithoutId() throws {
        let long = String(repeating: "x", count: 257)
        let max = String(repeating: "x", count: 256)
        let doc = try AppExport.parse(json: try json(#"{ "format": "tegaki-app-export", "v": 1, "exportedAt": "2026-10-17T21:03:00+09:00", "app": "ios/1.0 (12)", "pages": [1, "x", null, [], { "strokes": {} }, { "pageId": "" }, { "pageId": "\#(long)" }, { "pageId": "\#(max)" }, { "pageId": "m1-2026-10" }] }"#))
        XCTAssertEqual(doc.exportedAt, "2026-10-17T21:03:00+09:00")
        XCTAssertEqual(doc.app, "ios/1.0 (12)")
        XCTAssertEqual(doc.pages.map(\.pageId), [max, "m1-2026-10"], "non-objects, no pageId, an empty or 257-character pageId are dropped; 256 is kept")
        XCTAssertEqual(doc.pages[1], InkPage.empty(pageId: "m1-2026-10"))
        XCTAssertNil(AppExport.parsePage(.number(1)))
        XCTAssertNil(AppExport.parsePage(.array([])))
        XCTAssertNil(AppExport.parsePage(.object([:])))
        XCTAssertNil(AppExport.parsePage(.object(["pageId": .string("")])))
        XCTAssertNil(AppExport.parsePage(.object(["pageId": .string(long)])))
        XCTAssertEqual(AppExport.parsePage(.object(["pageId": .string("m1-2026-10")])), InkPage.empty(pageId: "m1-2026-10"))
    }

    func testParseMigratesBandCells() throws {
        let old = oldWeekPage()
        let colW = PaperSpec.weekColumnWidth
        let doc = try AppExport.parse(json: AppExport.jsonValue(document([old])))
        XCTAssertEqual(doc.pages.count, 1)
        XCTAssertEqual(doc.pages[0], BandMigration.migrate(old))
        XCTAssertEqual(doc.pages[0].strokes["w1"]?.cell, .grid, "the allday: stroke is on the grid")
        XCTAssertEqual(try XCTUnwrap(doc.pages[0].strokes["w1"]?.points.first?.x), 12 + 64 + 2 * colW, accuracy: 0.11, "x moved by the column origin")
        XCTAssertEqual(doc.pages[0].strokes["w1"]?.points.first?.y, 40, "y unchanged")
        XCTAssertEqual(doc.pages[0].strokes["w2"], old.strokes["w2"], "a grid stroke is untouched")
        XCTAssertFalse(BandMigration.needsMigration(doc.pages[0]))
        XCTAssertEqual(AppExport.parsePage(old.jsonValue), BandMigration.migrate(old))
        var oldDay = InkPage.empty(pageId: "d-2026-10-07")
        oldDay.add(stroke("b1", cell: .allDayDay, points: [point(800, 30)]))
        XCTAssertEqual(try AppExport.parse(json: AppExport.jsonValue(document([oldDay]))).pages[0].strokes["b1"]?.cell, .grid, "a day page's allday cell → grid")
        XCTAssertEqual(try AppExport.parse(json: AppExport.jsonValue(document([oldDay]))).pages[0].strokes["b1"]?.points, oldDay.strokes["b1"]?.points, "the day page's points do not move")
    }

    func testParsePageMatchesParse() throws {
        let doc = document([tombstonePage(), monthPage(), oldWeekPage()])
        let mixed = try json(#"{ "format": "tegaki-app-export", "pages": [ 5, { "pageId": "" }, \#(AppExport.pageText(monthPage())), "x", \#(AppExport.pageText(oldWeekPage())) ] }"#)
        for value in [AppExport.jsonValue(doc), try JSONValue.parse(AppExport.encode(doc)), mixed] {
            let elements = try XCTUnwrap(value["pages"]?.arrayValue)
            XCTAssertEqual(elements.compactMap(AppExport.parsePage), try AppExport.parse(json: value).pages)
        }
        XCTAssertEqual(try AppExport.parse(json: mixed).pages, [monthPage(), BandMigration.migrate(oldWeekPage())])
    }

    // MARK: File names (§1.5)

    func testFileNames() {
        XCTAssertEqual(AppExport.jsonFileName(exportedAt: date(2026, 10, 17, 23, 30), calendar: tokyo), "てがきカレンダー 手書き 2026-10-17.json")
        XCTAssertEqual(AppExport.jsonFileName(exportedAt: date(2026, 10, 17, 15, 30, calendar: utcCalendar), calendar: tokyo), "てがきカレンダー 手書き 2026-10-18.json", "UTC 15:30 is the next day in JST")
        XCTAssertEqual(AppExport.jsonFileName(exportedAt: date(2026, 10, 17, 15, 30, calendar: utcCalendar), calendar: utcCalendar), "てがきカレンダー 手書き 2026-10-17.json")
        XCTAssertEqual(AppExport.jsonFileName(exportedAt: date(2026, 1, 5, 0, 0), calendar: tokyo), "てがきカレンダー 手書き 2026-01-05.json", "zero padded")
        XCTAssertEqual(AppExport.pdfFileName(kind: .month, focus: day(2026, 10, 7)), "てがきカレンダー 2026年10月 月.pdf")
        XCTAssertEqual(AppExport.pdfFileName(kind: .week, focus: day(2026, 10, 7)), "てがきカレンダー 2026年10月5日〜10月11日 週.pdf")
        XCTAssertEqual(AppExport.pdfFileName(kind: .week, focus: day(2026, 12, 30)), "てがきカレンダー 2026年12月28日〜2027年1月3日 週.pdf", "a week across the year end")
        XCTAssertEqual(AppExport.pdfFileName(kind: .day, focus: day(2026, 10, 7)), "てがきカレンダー 2026年10月7日(水) 日.pdf")
        XCTAssertEqual(AppExport.pdfFileName(kind: .day, focus: day(2026, 11, 3)), "てがきカレンダー 2026年11月3日(火) 文化の日 日.pdf", "a holiday")
        XCTAssertEqual(AppExport.pdfFileName(kind: .year, focus: day(2026, 10, 7)), "てがきカレンダー 2026年 年.pdf")
        for kind in PageKind.allCases {
            XCTAssertEqual(AppExport.pdfFileName(kind: kind, focus: day(2026, 10, 7)), "てがきカレンダー " + PageNavigation.title(kind, focus: day(2026, 10, 7)) + " " + AppExport.kindLabel(kind) + ".pdf")
        }
        XCTAssertEqual(AppExport.kindLabel(.month), "月")
        XCTAssertEqual(AppExport.kindLabel(.week), "週")
        XCTAssertEqual(AppExport.kindLabel(.day), "日")
        XCTAssertEqual(AppExport.kindLabel(.year), "年")
        XCTAssertEqual(AppExport.safeFileName("a/b:c\\d"), "a-b-c-d")
        XCTAssertEqual(AppExport.safeFileName("//::\\\\"), "------")
        XCTAssertEqual(AppExport.safeFileName("てがきカレンダー 2026年10月 月.pdf"), "てがきカレンダー 2026年10月 月.pdf")
        XCTAssertEqual(AppExport.safeFileName("〜 ( ) . - _ 日"), "〜 ( ) . - _ 日")
        XCTAssertEqual(AppExport.safeFileName(""), "")
    }
}
