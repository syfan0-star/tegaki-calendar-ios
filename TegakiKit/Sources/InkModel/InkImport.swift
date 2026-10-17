import Foundation

/// The import door of 設定 › データ › 「Web 版の手書きを取り込む」, now for two formats
/// (M6_CONTRACT §1.2, 0-1, 0-11): the web version's `tegaki-web-export` (`WebImport`) and the app's
/// own `tegaki-app-export` (`AppExport`, the restore of a data file).
///
/// An app export can be tens of megabytes, so it is not read as one JSON tree: `topLevelMembers`
/// finds the byte range of each top-level member with a light scan (string literals and bracket
/// depth only), `arrayElements` splits the `pages` array into one byte range per page, and each page
/// is parsed on its own (`JSONValue.parse` → `AppExport.parsePage`) inside an `autoreleasepool`. The
/// result equals `AppExport.parse(json: JSONValue.parse(data))`. The web form is small and keeps the
/// old whole-tree read (`WebImport.parse(json:)`), whose behaviour is unchanged.
public enum InkImport {
    public enum Parsed: Equatable, Sendable {
        case web(WebImport.Document)
        /// `skipped` = elements of `pages` that `AppExport.parsePage` dropped (not an object, no usable
        /// `pageId`); `pages(_:)` reports it.
        case app(AppExport.Document, skipped: Int)
    }

    /// What the import saves: `pages` to merge, `skipped` pages that were not usable, `pageCount` and
    /// whether the file was the app's own format (U picks the finished text by it, §3.6, 0-12).
    public struct Outcome: Equatable, Sendable {
        public var pages: [InkPage]
        public var skipped: Int
        public var pageCount: Int
        public var isAppExport: Bool

        public init(pages: [InkPage], skipped: Int, pageCount: Int, isAppExport: Bool) {
            self.pages = pages
            self.skipped = skipped
            self.pageCount = pageCount
            self.isAppExport = isAppExport
        }
    }

    // MARK: - Entry (§1.2)

    /// The top-level members `parse` reads itself (§1.1); any other member is only checked to be JSON.
    static let knownKeys: Set<String> = ["format", "v", "exportedAt", "app", "pages"]

    /// Dispatches on `format`. Throws `WebImport.ParseError`: not JSON → `invalidJSON`; not an object,
    /// no `format`, or a `format` that is neither of the two → `notAnExport`; `v` > 1 →
    /// `unsupportedVersion(v)`. Only the app form is read page by page (see the type comment);
    /// everything else (the web form, no `format`, another `format`, data the light scan cannot
    /// split) goes through the old whole-tree path, so for anything that is not an app export the
    /// error is exactly what `WebImport.parse(_ data:)` reports, and for an app export the result is
    /// what `AppExport.parse(json: JSONValue.parse(data))` would give (except that a version above 1
    /// is reported before the pages are looked at, §1.2 step 3).
    public static func parse(_ data: Data) throws -> Parsed {
        guard let members = topLevelMembers(data) else {
            return try parseWholeTree(data)
        }
        // No `format`, or a `format` that is not the app's: the whole-tree read decides between
        // `invalidJSON` (the file is not JSON after all) and `notAnExport`, as before M6.
        guard let formatRange = members["format"], try value(data, formatRange).stringValue == AppExport.format else {
            return try parseWholeTree(data)
        }

        let version = WebImport.versionNumber(try members["v"].map { try value(data, $0) })
        if version > AppExport.supportedVersion {
            throw WebImport.ParseError.unsupportedVersion(version)
        }
        let exportedAt = try members["exportedAt"].map { try value(data, $0) }?.stringValue ?? ""
        let app = try members["app"].map { try value(data, $0) }?.stringValue ?? ""
        // Members this version does not read are still checked to be JSON, so a broken file is
        // `invalidJSON` here as on the whole-tree path (v1 writes none; `pages` is read below).
        for (key, range) in members where !knownKeys.contains(key) {
            _ = try autoreleasepool { try value(data, range) }
        }

        var pages: [InkPage] = []
        var elementCount = 0
        if let pagesRange = members["pages"] {
            if let elements = arrayElements(data, in: pagesRange) {
                elementCount = elements.count
                pages.reserveCapacity(elements.count)
                for range in elements {
                    let page: InkPage? = try autoreleasepool {
                        AppExport.parsePage(try value(data, range))
                    }
                    if let page = page { pages.append(page) }
                }
            } else {
                // The scan cannot split `pages` (not an array, or an array with a stray comma): the
                // member alone is parsed as a tree, which decides as the whole-tree read does — not
                // JSON → `invalidJSON`, not an array → `notAnExport`, an array `JSONSerialization`
                // accepts (a trailing comma on a lenient OS) → its elements.
                guard let list = try value(data, pagesRange).arrayValue else { throw WebImport.ParseError.notAnExport }
                elementCount = list.count
                for raw in list {
                    if let page = AppExport.parsePage(raw) { pages.append(page) }
                }
            }
        }
        return .app(AppExport.Document(exportedAt: exportedAt, app: app, pages: pages), skipped: elementCount - pages.count)
    }

    /// The pages to merge: `.web` → `WebImport.convert` (`pages`, `skipped.count`, `pageCount`);
    /// `.app` → the document's pages (`pageCount` = pages + skipped).
    public static func pages(_ parsed: Parsed) -> Outcome {
        switch parsed {
        case .web(let document):
            let conversion = WebImport.convert(document)
            return Outcome(pages: conversion.pages, skipped: conversion.skipped.count, pageCount: conversion.pageCount, isAppExport: false)
        case .app(let document, let skipped):
            return Outcome(pages: document.pages, skipped: skipped, pageCount: document.pages.count + skipped, isAppExport: true)
        }
    }

    /// The old path (the whole tree at once), for data the light scan could not split and for
    /// everything that is not an app export: the same errors as `WebImport.parse(_ data:)`, with the
    /// app form read by `AppExport.parse(json:)`.
    static func parseWholeTree(_ data: Data) throws -> Parsed {
        let json: JSONValue
        do {
            json = try JSONValue.parse(data)
        } catch {
            throw WebImport.ParseError.invalidJSON
        }
        guard let obj = json.objectValue, let format = obj["format"]?.stringValue else {
            throw WebImport.ParseError.notAnExport
        }
        switch format {
        case WebImport.format:
            return .web(try WebImport.parse(json: json))
        case AppExport.format:
            let document = try AppExport.parse(json: json)
            let elementCount = obj["pages"]?.arrayValue?.count ?? 0
            return .app(document, skipped: elementCount - document.pages.count)
        default:
            throw WebImport.ParseError.notAnExport
        }
    }

    /// One member's bytes as a JSON value (`JSONSerialization` with `.fragmentsAllowed`, so a bare
    /// string or number reads too). Not JSON → `invalidJSON`.
    static func value(_ data: Data, _ range: Range<Int>) throws -> JSONValue {
        do {
            return try JSONValue.parse(data[range])
        } catch {
            throw WebImport.ParseError.invalidJSON
        }
    }

    // MARK: - Splitting the bytes (0-11)

    /// The top-level object's members as key → the byte range of the value (indices of `data`, so
    /// `data[range]` is the value's text without surrounding whitespace). A light scan: it follows
    /// string literals (with the escapes `\"` and `\\`) and the depth of `{ }` `[ ]`, nothing else.
    /// Keys are decoded as JSON strings. nil when the data (after whitespace) does not start with
    /// `{`, a bracket does not match or is never closed, a key is not a string, a key is not followed
    /// by `:`, a member has no value, a comma is not followed by a member, or anything but
    /// whitespace follows the closing `}` (the caller then falls back to the whole-tree parse, which
    /// reports the error). A key that occurs twice keeps the later range.
    public static func topLevelMembers(_ data: Data) -> [String: Range<Int>]? {
        let base = data.startIndex
        return data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [String: Range<Int>]? in
            let scanner = Scanner(bytes: bytes, end: bytes.count)
            var i = scanner.skipWhitespace(0)
            guard i < bytes.count, bytes[i] == Scanner.openBrace else { return nil }
            i += 1
            var members: [String: Range<Int>] = [:]
            i = scanner.skipWhitespace(i)
            guard i < bytes.count else { return nil }
            if bytes[i] == Scanner.closeBrace {
                return scanner.onlyWhitespace(from: i + 1) ? members : nil
            }
            while true {
                guard i < bytes.count, bytes[i] == Scanner.quote, let keyEnd = scanner.scanString(from: i) else { return nil }
                guard let key = try? JSONValue.parse(data[(base + i)..<(base + keyEnd)]).stringValue else { return nil }
                i = scanner.skipWhitespace(keyEnd)
                guard i < bytes.count, bytes[i] == Scanner.colon else { return nil }
                i = scanner.skipWhitespace(i + 1)
                guard let valueEnd = scanner.scanValue(from: i) else { return nil }
                members[key] = (base + i)..<(base + valueEnd)
                i = scanner.skipWhitespace(valueEnd)
                guard i < bytes.count else { return nil }
                if bytes[i] == Scanner.closeBrace {
                    return scanner.onlyWhitespace(from: i + 1) ? members : nil
                }
                guard bytes[i] == Scanner.comma else { return nil }
                i = scanner.skipWhitespace(i + 1)
            }
        }
    }

    /// The elements of the array at `range` (a range from `topLevelMembers`), each as the byte range
    /// of the element without surrounding whitespace, with the same scan rules. An empty array gives
    /// `[]`. nil when the range is not an array (does not start with `[`), a bracket does not match,
    /// an element is missing (`[1,,2]`, `[1,]`), or anything but whitespace follows the closing `]`.
    public static func arrayElements(_ data: Data, in range: Range<Int>) -> [Range<Int>]? {
        let base = data.startIndex
        guard range.lowerBound >= base, range.upperBound <= data.endIndex else { return nil }
        return data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [Range<Int>]? in
            let end = range.upperBound - base
            let scanner = Scanner(bytes: bytes, end: end)
            var i = scanner.skipWhitespace(range.lowerBound - base)
            guard i < end, bytes[i] == Scanner.openBracket else { return nil }
            i = scanner.skipWhitespace(i + 1)
            var elements: [Range<Int>] = []
            guard i < end else { return nil }
            if bytes[i] == Scanner.closeBracket {
                return scanner.onlyWhitespace(from: i + 1) ? elements : nil
            }
            while true {
                guard let valueEnd = scanner.scanValue(from: i) else { return nil }
                elements.append((base + i)..<(base + valueEnd))
                i = scanner.skipWhitespace(valueEnd)
                guard i < end else { return nil }
                if bytes[i] == Scanner.closeBracket {
                    return scanner.onlyWhitespace(from: i + 1) ? elements : nil
                }
                guard bytes[i] == Scanner.comma else { return nil }
                i = scanner.skipWhitespace(i + 1)
            }
        }
    }

    /// The byte-level scan shared by `topLevelMembers` and `arrayElements`. Offsets are into `bytes`;
    /// `end` bounds the scan. UTF-8 continuation bytes never equal `"` or `\`, so bytes suffice.
    struct Scanner {
        let bytes: UnsafeRawBufferPointer
        let end: Int

        static let quote = UInt8(ascii: "\"")
        static let backslash = UInt8(ascii: "\\")
        static let openBrace = UInt8(ascii: "{")
        static let closeBrace = UInt8(ascii: "}")
        static let openBracket = UInt8(ascii: "[")
        static let closeBracket = UInt8(ascii: "]")
        static let colon = UInt8(ascii: ":")
        static let comma = UInt8(ascii: ",")

        static func isWhitespace(_ b: UInt8) -> Bool {
            b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09
        }

        func skipWhitespace(_ from: Int) -> Int {
            var i = from
            while i < end, Scanner.isWhitespace(bytes[i]) { i += 1 }
            return i
        }

        func onlyWhitespace(from: Int) -> Bool {
            skipWhitespace(from) == end
        }

        /// `from` is at the opening quote; the index after the closing quote, nil when unterminated.
        func scanString(from: Int) -> Int? {
            var i = from + 1
            while i < end {
                let b = bytes[i]
                if b == Scanner.backslash {
                    i += 2
                } else if b == Scanner.quote {
                    return i + 1
                } else {
                    i += 1
                }
            }
            return nil
        }

        /// The index after the value starting at `from` (a string, an object or array with matching
        /// brackets, or a scalar run up to the next `,` `]` `}` or whitespace). nil when the value
        /// is empty or unterminated or a bracket does not match.
        func scanValue(from: Int) -> Int? {
            guard from < end else { return nil }
            switch bytes[from] {
            case Scanner.quote:
                return scanString(from: from)
            case Scanner.openBrace, Scanner.openBracket:
                return scanContainer(from: from)
            default:
                var i = from
                while i < end {
                    let b = bytes[i]
                    if b == Scanner.comma || b == Scanner.closeBracket || b == Scanner.closeBrace || Scanner.isWhitespace(b) { break }
                    i += 1
                }
                return i > from ? i : nil
            }
        }

        /// `from` is at `{` or `[`; the index after the matching closer.
        func scanContainer(from: Int) -> Int? {
            var closers: [UInt8] = []
            var i = from
            while i < end {
                let b = bytes[i]
                switch b {
                case Scanner.quote:
                    guard let next = scanString(from: i) else { return nil }
                    i = next
                    continue
                case Scanner.openBrace:
                    closers.append(Scanner.closeBrace)
                case Scanner.openBracket:
                    closers.append(Scanner.closeBracket)
                case Scanner.closeBrace, Scanner.closeBracket:
                    guard closers.popLast() == b else { return nil }
                    if closers.isEmpty { return i + 1 }
                default:
                    break
                }
                i += 1
            }
            return nil
        }
    }
}
