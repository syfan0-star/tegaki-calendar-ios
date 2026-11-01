import Foundation
import CoreGraphics

/// Reads a `tegaki-web-export` v1 file (the web version's "手書きを書き出す（iPad アプリ用）",
/// M4_CONTRACT §1.3) and converts its pages into `InkPage`s (DESIGN §6.3 / §6.4, M4_CONTRACT §3.1–3.3).
///
/// Everything here is a pure function: no `Calendar`, no clock, no file system. The month grid comes
/// from `MonthLayout.grid(for:)` and the Monday test from `DayKey.weekday`, so the same input gives
/// the same cells on every device.
public enum WebImport {
    public static let format = "tegaki-web-export"
    public static let supportedVersion = 1
    /// `dev` of every imported stroke.
    public static let deviceId = "web"
    /// `dtMs` of the n-th point of an imported stroke is `pointStepMs × n` (DESIGN §6.4).
    public static let pointStepMs = 8
    /// The web highlighter is always 18 lu wide.
    public static let highlighterWidth: CGFloat = 18

    /// Default stroke sizes of the web version (`DEFAULT_SIZES` in js/ink/model.js).
    public static let defaultPenSize: Double = 3.5
    public static let defaultHighlighterSize: Double = 18
    /// Stroke sizes are clamped to this range (web `MIN_SIZE` / `MAX_SIZE`).
    public static let minSize: Double = 0.1
    public static let maxSize: Double = 200
    /// Coordinates beyond this are garbage (web `MAX_COORD`).
    public static let maxCoordinate: Double = 100_000
    /// At most this many strokes are read from one web page (the cap of the reader before 1.1; 1.1
    /// raised `InkPage.maxStrokes` to 60,000 but the web import keeps its behaviour, M7A_CONTRACT §5.1).
    public static let maxStrokesPerPage = 20_000

    /// invalidJSON = not readable as JSON / notAnExport = `format` differs or the top level is not an
    /// object / unsupportedVersion = `v` > 1.
    public enum ParseError: Error, Equatable {
        case invalidJSON
        case notAnExport
        case unsupportedVersion(Int)
    }

    /// One point of a web stroke: paper coordinates (lu, 0.1 rounded) and pressure (0…1, 0.01 rounded).
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var p: Double

        public init(x: Double, y: Double, p: Double) {
            self.x = x
            self.y = y
            self.p = p
        }
    }

    /// One web stroke (`PageDoc.strokes[id]`, SPEC §2), already normalised.
    public struct Stroke: Equatable, Sendable {
        public var id: String
        public var tool: Tool
        /// "#rrggbb", lower case.
        public var color: String
        /// Stroke width in lu (細 2 / 中 3.5 / 太 6, highlighter 18).
        public var size: Double
        public var points: [Point]
        /// Time the stroke was written, ms since the epoch (0 when unknown).
        public var t: Int

        public enum Tool: String, Sendable {
            case pen
            case highlighter

            /// The web version's default colour for the tool.
            public var defaultColor: String {
                switch self {
                case .pen: return InkTool.pen.defaultColor
                case .highlighter: return InkTool.marker.defaultColor
                }
            }

            public var defaultSize: Double {
                switch self {
                case .pen: return WebImport.defaultPenSize
                case .highlighter: return WebImport.defaultHighlighterSize
                }
            }
        }

        public init(id: String, tool: Tool, color: String, size: Double, points: [Point], t: Int) {
            self.id = id
            self.tool = tool
            self.color = color
            self.size = size
            self.points = points
            self.t = t
        }
    }

    /// One page of the export (`PageDoc`). `strokes` is sorted by id.
    public struct Page: Equatable, Sendable {
        public var pageId: String
        public var strokes: [Stroke]
        /// Tombstones carried over from the web (id → deletion time, ms).
        public var deleted: [String: Int]
        public var updatedAt: Int

        public init(pageId: String, strokes: [Stroke], deleted: [String: Int], updatedAt: Int) {
            self.pageId = pageId
            self.strokes = strokes
            self.deleted = deleted
            self.updatedAt = updatedAt
        }
    }

    /// The whole file. `exportedAt` / `app` / `includesDemo` are for display only.
    public struct Document: Equatable, Sendable {
        public var exportedAt: String?
        public var app: String?
        public var includesDemo: Bool
        public var pages: [Page]

        public init(exportedAt: String?, app: String?, includesDemo: Bool, pages: [Page]) {
            self.exportedAt = exportedAt
            self.app = app
            self.includesDemo = includesDemo
            self.pages = pages
        }
    }

    // MARK: - Parsing (M4_CONTRACT §3.1)

    /// Tolerant read, with the web version's `deserializePage` rules: broken strokes are dropped
    /// (id 1–128 characters, tool one of the two, `pts` in triples of finite numbers with
    /// |coordinate| ≤ 100000, pressure clamped to 0…1 and 0.5 when not a number, size clamped to
    /// 0.1…200 and the tool default when not a number or ≤ 0, consecutive equal points dropped,
    /// strokes without a point dropped). Only `format` and `v` are reasons to throw.
    public static func parse(_ data: Data) throws -> Document {
        let json: JSONValue
        do {
            json = try JSONValue.parse(data)
        } catch {
            throw ParseError.invalidJSON
        }
        return try parse(json: json)
    }

    /// The same read from an already parsed tree (M6_CONTRACT §1.2: `InkImport.parse` dispatches on
    /// `format` and calls this for the web form). `format` ≠ "tegaki-web-export" or a top level that
    /// is not an object → `notAnExport`; `v` > 1 → `unsupportedVersion`. Nothing else throws.
    public static func parse(json: JSONValue) throws -> Document {
        guard let obj = json.objectValue, obj["format"]?.stringValue == format else {
            throw ParseError.notAnExport
        }
        let version = versionNumber(obj["v"])
        if version > supportedVersion {
            throw ParseError.unsupportedVersion(version)
        }
        var pages: [Page] = []
        if let rawPages = obj["pages"]?.arrayValue {
            for raw in rawPages {
                if let page = parsePage(raw) { pages.append(page) }
            }
        }
        return Document(
            exportedAt: obj["exportedAt"]?.stringValue,
            app: obj["app"]?.stringValue,
            includesDemo: obj["includesDemo"]?.boolValue ?? false,
            pages: pages
        )
    }

    /// `v` as an Int; a missing or unusable value counts as version 1 (the only version so far).
    static func versionNumber(_ value: JSONValue?) -> Int {
        guard let raw = value?.doubleValue, raw.isFinite, abs(raw) < 1e9 else { return supportedVersion }
        return Int(raw.rounded())
    }

    /// One `PageDoc`. nil when it is not an object (a missing `pageId` gives "" and is skipped later).
    static func parsePage(_ json: JSONValue) -> Page? {
        guard let obj = json.objectValue else { return nil }
        var pageId = obj["pageId"]?.stringValue ?? ""
        if pageId.count > InkPage.maxPageIdLength { pageId = "" }

        var deleted: [String: Int] = [:]
        if let raw = obj["deleted"]?.objectValue {
            for (id, value) in raw where InkStroke.isValidId(id) {
                if deleted.count >= InkPage.maxTombstones { break }
                deleted[id] = normalizeTime(value.doubleValue)
            }
        }

        var byId: [String: Stroke] = [:]
        func take(_ raw: JSONValue, fallbackId: String?) {
            guard byId.count < maxStrokesPerPage, let stroke = parseStroke(raw, fallbackId: fallbackId) else { return }
            if deleted[stroke.id] != nil { return }
            if byId[stroke.id] == nil { byId[stroke.id] = stroke }
        }
        if let rawStrokes = obj["strokes"]?.objectValue {
            for key in rawStrokes.keys.sorted() {
                take(rawStrokes[key]!, fallbackId: key)
            }
        } else if let rawList = obj["strokes"]?.arrayValue {
            for raw in rawList {
                take(raw, fallbackId: nil)
            }
        }
        let strokes = byId.keys.sorted().map { byId[$0]! }
        return Page(pageId: pageId, strokes: strokes, deleted: deleted, updatedAt: normalizeTime(obj["updatedAt"]?.doubleValue))
    }

    /// The web version's `normalizeStroke`. nil when unusable.
    static func parseStroke(_ json: JSONValue, fallbackId: String?) -> Stroke? {
        guard let obj = json.objectValue else { return nil }
        let id: String
        if let s = obj["id"]?.stringValue, InkStroke.isValidId(s) {
            id = s
        } else if let f = fallbackId, InkStroke.isValidId(f) {
            id = f
        } else {
            return nil
        }
        guard let toolName = obj["tool"]?.stringValue, let tool = Stroke.Tool(rawValue: toolName) else { return nil }
        let points = normalizePoints(obj["pts"]?.arrayValue ?? [])
        guard !points.isEmpty else { return nil }
        let color = obj["color"]?.stringValue.flatMap(InkStroke.normalizeColor) ?? tool.defaultColor
        return Stroke(
            id: id,
            tool: tool,
            color: color,
            size: normalizeSize(obj["size"]?.doubleValue, tool: tool),
            points: points,
            t: normalizeTime(obj["t"]?.doubleValue)
        )
    }

    /// The web version's `normalizeSize`: not a number or ≤ 0 → the tool default, otherwise 0.01
    /// rounded and clamped to 0.1…200 (so 0.05 → 0.1 but 0 → the default).
    public static func normalizeSize(_ size: Double?, tool: Stroke.Tool) -> Double {
        guard let s = size, s.isFinite, s > 0 else { return tool.defaultSize }
        return min(maxSize, max(minSize, round2(s)))
    }

    /// The web version's `normalizePts`: triples of (x, y, p); x and y 0.1 rounded and finite with
    /// |value| ≤ 100000, p clamped to 0…1 and 0.01 rounded (0.5 when not a number); consecutive
    /// equal points dropped; at most `InkStroke.maxPoints` points.
    public static func normalizePoints(_ raw: [JSONValue]) -> [Point] {
        var out: [Point] = []
        let count = raw.count - raw.count % 3
        var lastX = Double.nan
        var lastY = Double.nan
        var i = 0
        while i < count && out.count < InkStroke.maxPoints {
            defer { i += 3 }
            guard let rx = raw[i].doubleValue, let ry = raw[i + 1].doubleValue, rx.isFinite, ry.isFinite else { continue }
            let x = round1(rx)
            let y = round1(ry)
            guard abs(x) <= maxCoordinate, abs(y) <= maxCoordinate else { continue }
            if x == lastX && y == lastY { continue }
            let p: Double
            if let rp = raw[i + 2].doubleValue, rp.isFinite {
                p = round2(min(1, max(0, rp)))
            } else {
                p = 0.5
            }
            out.append(Point(x: x, y: y, p: p))
            lastX = x
            lastY = y
        }
        return out
    }

    /// The web version's `normalizeTime`: finite and > 0 → rounded, else 0.
    static func normalizeTime(_ value: Double?) -> Int {
        guard let v = value, v.isFinite, v > 0, v < 1e15 else { return 0 }
        return Int(v.rounded())
    }

    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 + 0 }
    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 + 0 }
}

// MARK: - Page ids and cells (M4_CONTRACT §3.2, DESIGN §6.3)

extension WebImport {
    /// The four page kinds the app imports. "m-YYYY-MM" and Sunday "w-" pages (the old Sunday-start
    /// pages, copied to Monday pages by web 1.0.4) are not among them.
    public enum PageId: Equatable, Sendable {
        /// "m1-YYYY-MM"
        case month(YearMonth)
        /// "w-YYYY-MM-DD" (a Monday)
        case week(DayKey)
        /// "d-YYYY-MM-DD"
        case day(DayKey)
        /// "y-YYYY"
        case year(Int)

        /// nil for anything but the four forms above (zero padded, as the web writes them). The Monday
        /// test is `DayKey.weekday == 1` (0 = Sunday, like the web's `getDay() === 1`); no `Calendar`.
        public static func parse(_ raw: String) -> PageId? {
            if raw.hasPrefix("m1-") {
                guard let ym = yearMonth(String(raw.dropFirst(3))) else { return nil }
                return .month(ym)
            }
            if raw.hasPrefix("w-") {
                guard let d = dayKey(String(raw.dropFirst(2))), d.weekday == 1 else { return nil }
                return .week(d)
            }
            if raw.hasPrefix("d-") {
                guard let d = dayKey(String(raw.dropFirst(2))) else { return nil }
                return .day(d)
            }
            if raw.hasPrefix("y-") {
                let digits = String(raw.dropFirst(2))
                guard isDigits(digits, count: 4), let y = Int(digits) else { return nil }
                return .year(y)
            }
            return nil
        }

        /// The page id string (the same as `PageNavigation.pageId`).
        public var raw: String {
            switch self {
            case .month(let ym): return ym.inkPageId
            case .week(let d): return "w-" + d.description
            case .day(let d): return "d-" + d.description
            case .year(let y): return String(format: "y-%04d", y)
            }
        }

        /// "YYYY-MM" with the digits zero padded.
        static func yearMonth(_ s: String) -> YearMonth? {
            let parts = s.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 2, isDigits(parts[0], count: 4), isDigits(parts[1], count: 2),
                  let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
            return YearMonth(year: y, month: m)
        }

        /// "YYYY-MM-DD" with the digits zero padded and the date real.
        static func dayKey(_ s: String) -> DayKey? {
            let parts = s.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3, isDigits(parts[0], count: 4), isDigits(parts[1], count: 2), isDigits(parts[2], count: 2) else { return nil }
            return DayKey(ymd: s)
        }

        static func isDigits<S: StringProtocol>(_ s: S, count: Int) -> Bool {
            s.count == count && s.allSatisfy { $0.isASCII && $0.isNumber }
        }
    }

    /// Web paper geometry (DESIGN §6.3).
    static let monthCellWidth: CGFloat = 200
    static let monthCellHeight: CGFloat = 175
    static let monthMemoTop: CGFloat = 1050
    static let yearGutter: CGFloat = 56
    static let yearColumnWidth: CGFloat = 112
    static let yearRowHeight: CGFloat = 60

    /// Decides the cell a stroke belongs to from the centre of its bounding box (the midpoint of the
    /// points' min / max, nib not added) and returns that cell's top-left corner in web coordinates
    /// (relative coordinates = web point − origin). The month's dates come from `MonthLayout.grid(for:)`.
    public static func cell(for page: PageId, center: CGPoint) -> (cell: CellKey, origin: CGPoint) {
        let cx = center.x.isFinite ? center.x : 0
        let cy = center.y.isFinite ? center.y : 0
        switch page {
        case .month(let ym):
            if cy >= monthMemoTop {
                return (.memo, CGPoint(x: 0, y: monthMemoTop))
            }
            let r = clamp(floorIndex(cy / monthCellHeight), 0, 5)
            let c = clamp(floorIndex(cx / monthCellWidth), 0, MonthLayout.columns - 1)
            let day = MonthLayout.grid(for: ym).days[r * MonthLayout.columns + c]
            return (.day(day), CGPoint(x: monthCellWidth * CGFloat(c), y: monthCellHeight * CGFloat(r)))
        case .week, .day:
            return (.grid, .zero)
        case .year:
            let m = clamp(floorIndex((cx - yearGutter) / yearColumnWidth), 0, 11)
            let d = clamp(floorIndex(cy / yearRowHeight) + 1, 1, 31)
            return (.yearDay(month: m + 1, day: d), CGPoint(x: yearGutter + yearColumnWidth * CGFloat(m), y: yearRowHeight * CGFloat(d - 1)))
        }
    }

    /// `floor(value + 1e-9)`, forgiving floating-point error (like M3b's `nearestColumn`).
    static func floorIndex(_ value: CGFloat) -> Int {
        let f = (value + 1e-9).rounded(.down)
        guard f.isFinite else { return 0 }
        if f > 1e9 { return Int(1e9) }
        if f < -1e9 { return -Int(1e9) }
        return Int(f)
    }

    static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
        min(hi, max(lo, v))
    }
}

// MARK: - Conversion (M4_CONTRACT §3.3, DESIGN §6.4)

extension WebImport {
    public enum SkipReason: Equatable, Sendable {
        /// "m-YYYY-MM" or a Sunday "w-": an old Sunday-start page (already copied to a Monday page).
        case legacyPageId
        /// Any other id the app has no page for.
        case unknownPageId
        /// No stroke survived (an empty page, or only broken strokes).
        case noStrokes
    }

    public struct Skipped: Equatable, Sendable {
        public var pageId: String
        public var reason: SkipReason

        public init(pageId: String, reason: SkipReason) {
            self.pageId = pageId
            self.reason = reason
        }
    }

    /// `pages` in document order (only pages with at least one stroke), `strokeCount` = strokes
    /// converted, `pageCount` = `pages.count`.
    public struct Conversion: Equatable, Sendable {
        public var pages: [InkPage]
        public var skipped: [Skipped]
        public var strokeCount: Int
        public var pageCount: Int

        public init(pages: [InkPage], skipped: [Skipped], strokeCount: Int, pageCount: Int) {
            self.pages = pages
            self.skipped = skipped
            self.strokeCount = strokeCount
            self.pageCount = pageCount
        }
    }

    /// Nib size of one point: pen → size × (0.4 + 0.9 × p) (the web's width formula), highlighter →
    /// size (the web fixes it at 18). `InkPoint` rounds the result to 0.01.
    public static func nibSize(tool: Stroke.Tool, size: Double, pressure: Double) -> CGFloat {
        switch tool {
        case .pen: return CGFloat(size * (0.4 + 0.9 * pressure))
        case .highlighter: return CGFloat(size)
        }
    }

    /// Converts one stroke: the web id is kept (nil when it is not a valid id or there is no point),
    /// the cell and origin follow `cell(for:center:)`, every point becomes
    /// `InkPoint(x − origin.x, y − origin.y, dtMs: 8 × n, nib, nib, opacity 1, force p, azimuth 0,
    /// altitude π/2)`, pen → `.pen` / highlighter → `.marker`, colour kept (the tool default when
    /// invalid), `t` kept, `dev` = "web".
    public static func convert(stroke: Stroke, page: PageId) -> InkStroke? {
        guard InkStroke.isValidId(stroke.id), let first = stroke.points.first else { return nil }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for p in stroke.points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let (cell, origin) = self.cell(for: page, center: center)
        let points = stroke.points.enumerated().map { index, p -> InkPoint in
            let nib = nibSize(tool: stroke.tool, size: stroke.size, pressure: p.p)
            return InkPoint(
                x: CGFloat(p.x) - origin.x,
                y: CGFloat(p.y) - origin.y,
                dtMs: pointStepMs * index,
                sizeW: nib,
                sizeH: nib,
                opacity: 1,
                force: CGFloat(p.p),
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let tool: InkTool
        switch stroke.tool {
        case .pen: tool = .pen
        case .highlighter: tool = .marker
        }
        return InkStroke(id: stroke.id, cell: cell, tool: tool, color: stroke.color, t: stroke.t, dev: deviceId, points: points)
    }

    /// Converts one page: nil when the page id is not one of the four forms or no stroke converts.
    /// Each stroke is `add`ed at its `t`; the web tombstones are carried over as tombstones (the
    /// strokes are not removed); `updatedAt` = max(web `updatedAt`, max stroke `t`).
    public static func convert(page: Page) -> InkPage? {
        guard let id = PageId.parse(page.pageId) else { return nil }
        var out = InkPage(pageId: page.pageId)
        var converted = 0
        for stroke in page.strokes {
            guard let s = convert(stroke: stroke, page: id) else { continue }
            let before = out.strokes.count
            out.add(s, at: stroke.t)
            if out.strokes.count > before { converted += 1 }
        }
        guard converted > 0 else { return nil }
        for (tombId, time) in page.deleted where InkStroke.isValidId(tombId) {
            let t = max(0, time)
            if let cur = out.deleted[tombId] {
                if t > cur { out.deleted[tombId] = t }
            } else {
                out.deleted[tombId] = t
            }
        }
        out.updatedAt = max(out.updatedAt, max(0, page.updatedAt))
        return out
    }

    /// Converts a whole document; skipped pages are listed with their reason, in document order.
    public static func convert(_ document: Document) -> Conversion {
        var pages: [InkPage] = []
        var skipped: [Skipped] = []
        var strokeCount = 0
        for page in document.pages {
            guard PageId.parse(page.pageId) != nil else {
                skipped.append(Skipped(pageId: page.pageId, reason: skipReason(forUnparsable: page.pageId)))
                continue
            }
            guard let converted = convert(page: page) else {
                skipped.append(Skipped(pageId: page.pageId, reason: .noStrokes))
                continue
            }
            strokeCount += converted.liveStrokeCount
            pages.append(converted)
        }
        return Conversion(pages: pages, skipped: skipped, strokeCount: strokeCount, pageCount: pages.count)
    }

    /// Why an id that `PageId.parse` rejected is skipped: the old Sunday-start forms ("m-YYYY-MM",
    /// "w-" of a Sunday) are `.legacyPageId`, everything else `.unknownPageId`.
    static func skipReason(forUnparsable raw: String) -> SkipReason {
        if raw.hasPrefix("m-"), PageId.yearMonth(String(raw.dropFirst(2))) != nil {
            return .legacyPageId
        }
        if raw.hasPrefix("w-"), let d = PageId.dayKey(String(raw.dropFirst(2))), d.weekday == 0 {
            return .legacyPageId
        }
        return .unknownPageId
    }
}
