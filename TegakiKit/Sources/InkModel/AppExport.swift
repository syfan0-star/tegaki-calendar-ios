import Foundation

/// The app's own export file `tegaki-app-export` v1 (M6_CONTRACT §1.1, DESIGN §3.9): every page of
/// the device's handwriting in one readable JSON file, each page being `InkPage.jsonValue` itself
/// (the stored form, so nothing is lost), written back through the import door as a restore.
///
/// ```
/// { "format": "tegaki-app-export", "v": 1, "exportedAt": "2026-10-17T21:03:00+09:00",
///   "app": "ios/1.0 (12)", "pages": [ <InkPage.jsonValue>, … ] }
/// ```
///
/// Everything here is a pure function: no clock, no file system, no `Calendar` of its own (the
/// caller passes `DayKey.deviceCalendar` and `TimeZone.current`). The writer (`ExportBuilder`) does
/// not build the whole tree: it writes `header`, then `pageText` per page separated by
/// `pageSeparator`, then `footer`, and that byte sequence is exactly `encode(document)`.
public enum AppExport {
    public static let format = "tegaki-app-export"
    public static let supportedVersion = 1

    /// The export document (also what `parse` returns). On the writing side `pages` are
    /// `BandMigration.migrate`d, free of empty pages (`isWorthExporting`) and in `pageId` order.
    public struct Document: Equatable, Sendable {
        /// "2026-10-17T21:03:00+09:00" (display only).
        public var exportedAt: String
        /// "ios/1.0 (12)" (display only).
        public var app: String
        public var pages: [InkPage]

        public init(exportedAt: String, app: String, pages: [InkPage]) {
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
    public static func isWorthExporting(_ page: InkPage) -> Bool {
        page.liveStrokeCount > 0 || !page.deleted.isEmpty || !page.unknownStrokes.isEmpty
    }

    /// The whole tree: `format`, `v`, `exportedAt`, `app`, `pages` (each `InkPage.jsonValue`).
    public static func jsonValue(_ document: Document) -> JSONValue {
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
        out += "  \"app\": " + JSONValue.string(app).serialized() + ",\n"
        out += "  \"exportedAt\": " + JSONValue.string(exportedAt).serialized() + ",\n"
        out += "  \"format\": " + JSONValue.string(format).serialized() + ",\n"
        out += "  \"pages\": [\n"
        return out
    }

    /// One page, pretty-printed as an element of the `pages` array: every line indented by four
    /// spaces, no trailing newline.
    public static func pageText(_ page: InkPage) -> String {
        "    " + page.jsonValue.serialized(pretty: true, indent: 4)
    }

    public static let pageSeparator = ",\n"
    public static let footer = "\n  ],\n  \"v\": 1\n}\n"

    // MARK: - Parsing (§1.2)

    /// Reads a whole tree (small documents and tests; `InkImport.parse` reads big files page by page
    /// and gives the same result). Throws `WebImport.ParseError`: a top level that is not an object
    /// or whose `format` differs → `notAnExport`; `v` > 1 → `unsupportedVersion(v)`; a `pages` that is
    /// present but not an array → `notAnExport`. Pages are read with `parsePage` (an element that is
    /// not an object or has no usable `pageId` is dropped; `InkImport` counts them) in document order.
    public static func parse(json: JSONValue) throws -> Document {
        guard let obj = json.objectValue, obj["format"]?.stringValue == format else {
            throw WebImport.ParseError.notAnExport
        }
        let version = WebImport.versionNumber(obj["v"])
        if version > supportedVersion {
            throw WebImport.ParseError.unsupportedVersion(version)
        }
        var pages: [InkPage] = []
        if let rawPages = obj["pages"] {
            guard let list = rawPages.arrayValue else { throw WebImport.ParseError.notAnExport }
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

    /// One element of `pages`: `InkPage(json:)` (tolerant: broken strokes dropped, unknown items
    /// kept), nil when the element is not an object or its `pageId` is empty or longer than 256
    /// characters, then `BandMigration.migrate` (the old all-day band cells move onto the grid, 0-7).
    public static func parsePage(_ json: JSONValue) -> InkPage? {
        guard json.objectValue != nil else { return nil }
        let page = InkPage(json: json)
        guard !page.pageId.isEmpty else { return nil }
        return BandMigration.migrate(page)
    }

    // MARK: - File names (§1.5)

    /// 「てがきカレンダー 手書き 2026-10-17.json」: the calendar day of `exportedAt` in `calendar`.
    public static func jsonFileName(exportedAt: Date, calendar: Calendar) -> String {
        "てがきカレンダー 手書き " + DayKey(exportedAt, calendar: calendar).description + ".json"
    }

    /// 「てがきカレンダー 2026年10月 月.pdf」: `PageNavigation.title` (so a day's holiday name and a
    /// week's second year are included) and `kindLabel`, made safe with `safeFileName`.
    public static func pdfFileName(kind: PageKind, focus: DayKey) -> String {
        safeFileName("てがきカレンダー " + PageNavigation.title(kind, focus: focus) + " " + kindLabel(kind) + ".pdf")
    }

    /// 月 "月" / 週 "週" / 日 "日" / 年 "年".
    public static func kindLabel(_ kind: PageKind) -> String {
        switch kind {
        case .month: return "月"
        case .week: return "週"
        case .day: return "日"
        case .year: return "年"
        }
    }

    /// "/", ":" and "\" become "-"; everything else is kept.
    public static func safeFileName(_ name: String) -> String {
        String(name.map { $0 == "/" || $0 == ":" || $0 == "\\" ? "-" : $0 })
    }
}
