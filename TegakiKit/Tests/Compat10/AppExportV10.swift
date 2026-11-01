// a21e469 TegakiKit/Sources/InkModel/AppExport.swift:1-132  AppExportV10
import Foundation

/// The app's own export file `tegaki-app-export` v1 (M6_CONTRACT §1.1, DESIGN §3.9): every page of
/// the device's handwriting in one readable JSON file, each page being `InkPageV10.jsonValue` itself
/// (the stored form, so nothing is lost), written back through the import door as a restore.
///
/// ```
/// { "format": "tegaki-app-export", "v": 1, "exportedAt": "2026-10-17T21:03:00+09:00",
///   "app": "ios/1.0 (12)", "pages": [ <InkPageV10.jsonValue>, … ] }
/// ```
///
/// Everything here is a pure function: no clock, no file system, no `Calendar` of its own (the
/// caller passes `DayKeyV10.deviceCalendar` and `TimeZone.current`). The writer (`ExportBuilder`) does
/// not build the whole tree: it writes `header`, then `pageText` per page separated by
/// `pageSeparator`, then `footer`, and that byte sequence is exactly `encode(document)`.
public enum AppExportV10 {
    public static let format = "tegaki-app-export"
    public static let supportedVersion = 1

    /// The export document (also what `parse` returns). On the writing side `pages` are
    /// `BandMigrationV10.migrate`d, free of empty pages (`isWorthExporting`) and in `pageId` order.
    public struct Document: Equatable, Sendable {
        /// "2026-10-17T21:03:00+09:00" (display only).
        public var exportedAt: String
        /// "ios/1.0 (12)" (display only).
        public var app: String
        public var pages: [InkPageV10]

        public init(exportedAt: String, app: String, pages: [InkPageV10]) {
            self.exportedAt = exportedAt
            self.app = app
            self.pages = pages
        }
    }

    // MARK: - Writing (§1.1, §1.3)

    /// ISO 8601 with the local offset, to the second: 「2026-10-17T21:03:00+09:00」 (UTC gives 「…Z」).
    public static func exportedAtText(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// Whether the page goes into the file: a live stroke, a tombstone or an unknown stroke. A page
    /// with only tombstones is exported so a restore keeps the erased strokes erased (M6-6).
    public static func isWorthExporting(_ page: InkPageV10) -> Bool {
        page.liveStrokeCount > 0 || !page.deleted.isEmpty || !page.unknownStrokes.isEmpty
    }

    /// The whole tree: `format`, `v`, `exportedAt`, `app`, `pages` (each `InkPageV10.jsonValue`).
    public static func jsonValue(_ document: Document) -> JSONValueV10 {
        .object([
            "format": .string(format),
            "v": .number(Double(supportedVersion)),
            "exportedAt": .string(document.exportedAt),
            "app": .string(document.app),
            "pages": .array(document.pages.map(\.jsonValue)),
        ])
    }

    /// The file's bytes: `header` + the pages' `pageText` joined by `pageSeparator` + `footer`, which
    /// for one page or more is `jsonValue(document).serializedData(pretty: true)` plus a final "\n"
    /// (the tests fix both). With no page the streamed form keeps the opened `pages` array
    /// (`[\n\n  ]`, still valid JSON) where the pretty printer would write `[]`; the writer never
    /// produces that file (`nothingToExport`).
    public static func encode(_ document: Document) -> Data {
        var text = header(exportedAt: document.exportedAt, app: document.app)
        text += document.pages.map(pageText).joined(separator: pageSeparator)
        text += footer
        return Data(text.utf8)
    }

    /// `{\n  "app": …,\n  "exportedAt": …,\n  "format": "tegaki-app-export",\n  "pages": [\n`
    /// (the keys in the sorted order of the pretty printer).
    public static func header(exportedAt: String, app: String) -> String {
        var out = "{\n"
        out += "  \"app\": " + JSONValueV10.string(app).serialized() + ",\n"
        out += "  \"exportedAt\": " + JSONValueV10.string(exportedAt).serialized() + ",\n"
        out += "  \"format\": " + JSONValueV10.string(format).serialized() + ",\n"
        out += "  \"pages\": [\n"
        return out
    }

    /// One page, pretty-printed as an element of the `pages` array: every line indented by four
    /// spaces, no trailing newline.
    public static func pageText(_ page: InkPageV10) -> String {
        "    " + page.jsonValue.serialized(pretty: true, indent: 4)
    }

    public static let pageSeparator = ",\n"
    public static let footer = "\n  ],\n  \"v\": 1\n}\n"

    // MARK: - Parsing (§1.2)

    /// Reads a whole tree (small documents and tests; `InkImport.parse` reads big files page by page
    /// and gives the same result). Throws `WebImportV10.ParseError`: a top level that is not an object
    /// or whose `format` differs → `notAnExport`; `v` > 1 → `unsupportedVersion(v)`; a `pages` that is
    /// present but not an array → `notAnExport`. Pages are read with `parsePage` (an element that is
    /// not an object or has no usable `pageId` is dropped; `InkImport` counts them) in document order.
    public static func parse(json: JSONValueV10) throws -> Document {
        guard let obj = json.objectValue, obj["format"]?.stringValue == format else {
            throw WebImportV10.ParseError.notAnExport
        }
        let version = WebImportV10.versionNumber(obj["v"])
        if version > supportedVersion {
            throw WebImportV10.ParseError.unsupportedVersion(version)
        }
        var pages: [InkPageV10] = []
        if let rawPages = obj["pages"] {
            guard let list = rawPages.arrayValue else { throw WebImportV10.ParseError.notAnExport }
            for raw in list {
                if let page = parsePage(raw) { pages.append(page) }
            }
        }
        return Document(
            exportedAt: obj["exportedAt"]?.stringValue ?? "",
            app: obj["app"]?.stringValue ?? "",
            pages: pages
        )
    }

    /// One element of `pages`: `InkPageV10(json:)` (tolerant: broken strokes dropped, unknown items
    /// kept), nil when the element is not an object or its `pageId` is empty or longer than 256
    /// characters, then `BandMigrationV10.migrate` (the old all-day band cells move onto the grid, 0-7).
    public static func parsePage(_ json: JSONValueV10) -> InkPageV10? {
        guard json.objectValue != nil else { return nil }
        let page = InkPageV10(json: json)
        guard !page.pageId.isEmpty else { return nil }
        return BandMigrationV10.migrate(page)
    }
}
