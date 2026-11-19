import Foundation

/// The names of the pages joined side by side (1.3, docs/M7C_CONTRACT.md §2.1, §3.2, D4): the cells,
/// stroke ids and tombstones of a window's pages carry the page they belong to in front of their own
/// name, "<pageId>|<name>" (`w-2026-11-02|grid`), and the window itself has the virtual page id
/// "span~<kind>~<n>". Both live only in the device's memory: nothing with them is ever saved, synced,
/// exported or drawn into a PDF (§6.1; `SpanGuard` in InkModel checks it at every way out).
///
/// It lives in Layout, not InkModel, because `SpanLayout` strips the prefix and Layout cannot import
/// InkModel (TegakiKit/Package.swift; InkModel imports Layout, so `SpanGuard` and `SpanComposer` use
/// these functions too).
///
/// What counts as a prefix is the form of the page ids `PageNavigation.pageId` writes, followed by the
/// separator: `^(?:[dw]-\d{4}-\d{2}-\d{2}|m1-\d{4}-\d{2}|y-\d{4})\|` with ASCII digits (§6.1). A name
/// that merely holds a "|" somewhere (an imported or hand-edited id, a web stroke, a tool of a newer
/// version) is not prefixed, so `strip` and `split` leave it alone: K-10 forbids "|" only in the names
/// 1.3 and later make, data that exists keeps its names.
public enum SpanName {
    /// Between the page id and the page's own name. No page id holds it (K-10).
    public static let separator: Character = "|"

    /// The start of every name that exists only in a window: the virtual page id "span~<kind>~<n>" and
    /// the alias of a long stroke id "<pageId>|span~a~<n>" (its local part starts with it too).
    public static let virtualPrefix = "span~"

    /// The local part of an alias: "<pageId>|span~a~<n>" (§3.2). It starts with `virtualPrefix`, so a
    /// stripped alias that slipped past the alias table is still stopped by `SpanGuard`'s rule on
    /// "span~", and the page id in front keeps two pages' aliases apart (a bare "~<n>" would collide
    /// across pages and sessions and `InkPage.merge` would fold two strokes into one).
    public static let aliasPrefix = "span~a~"

    /// The most bytes (UTF-8) of a stroke id `InkPage.add` and `remove` accept (`InkStroke.isValidId`,
    /// `maxIdLength`); a longer one is ignored silently there, so a prefixed id longer than this gets an
    /// alias (§3.2).
    public static let idByteLimit = 128

    // MARK: Prefix

    /// "<page>|<cell>". The page is a real page id (never the virtual one); `cell` is the page's own
    /// name (prefixing a prefixed name twice is the caller's mistake: `strip` removes one prefix).
    public static func prefixed(_ cell: CellKey, page: String) -> CellKey {
        CellKey(raw: prefixed(id: cell.raw, page: page))
    }

    /// "<page>|<id>" for a stroke id, a tombstone or an unknown tool's key.
    public static func prefixed(id: String, page: String) -> String {
        page + String(separator) + id
    }

    /// (page, local) of a prefixed name, split at the first "|" (a page id never holds one, so the
    /// local part keeps any "|" of its own); nil when the name is not prefixed (`isPrefixed`).
    public static func split(_ name: String) -> (page: String, local: String)? {
        guard let length = prefixLength(name) else { return nil }
        let utf8 = name.utf8
        let pageEnd = utf8.index(utf8.startIndex, offsetBy: length)
        let localStart = utf8.index(after: pageEnd)
        guard let page = String(utf8[utf8.startIndex..<pageEnd]), let local = String(utf8[localStart...]) else { return nil }
        return (page, local)
    }

    /// The page's own name of a prefixed cell; the cell itself when it is not prefixed.
    public static func strip(_ cell: CellKey) -> CellKey {
        CellKey(raw: strip(id: cell.raw))
    }

    /// The page's own id of a prefixed stroke id; the id itself when it is not prefixed.
    public static func strip(id: String) -> String {
        split(id)?.local ?? id
    }

    /// Does the name start with a page id of the form `PageNavigation.pageId` writes and "|"? (The form
    /// only: "w-2026-13-45|grid" counts, as it does for `SpanGuard`; real data never has it.)
    public static func isPrefixed(_ name: String) -> Bool {
        prefixLength(name) != nil
    }

    /// The byte length of the page id in front of the separator, when the name is prefixed.
    private static func prefixLength(_ name: String) -> Int? {
        let bytes = Array(name.utf8.prefix(13))
        func digits(_ range: Range<Int>) -> Bool {
            range.upperBound <= bytes.count && bytes[range].allSatisfy { $0 >= 0x30 && $0 <= 0x39 }
        }
        func byte(_ i: Int, _ c: UInt8) -> Bool {
            i < bytes.count && bytes[i] == c
        }
        let bar = UInt8(ascii: "|")
        let dash = UInt8(ascii: "-")
        // d-YYYY-MM-DD| or w-YYYY-MM-DD|
        if (byte(0, UInt8(ascii: "d")) || byte(0, UInt8(ascii: "w"))), byte(1, dash), digits(2..<6), byte(6, dash),
           digits(7..<9), byte(9, dash), digits(10..<12), byte(12, bar) {
            return 12
        }
        // m1-YYYY-MM|
        if byte(0, UInt8(ascii: "m")), byte(1, UInt8(ascii: "1")), byte(2, dash), digits(3..<7), byte(7, dash),
           digits(8..<10), byte(10, bar) {
            return 10
        }
        // y-YYYY|
        if byte(0, UInt8(ascii: "y")), byte(1, dash), digits(2..<6), byte(6, bar) {
            return 6
        }
        return nil
    }

    // MARK: Virtual names

    /// Does the name start with "span~" (the virtual page id, or a stripped alias)?
    public static func isVirtual(_ name: String) -> Bool {
        name.hasPrefix(virtualPrefix)
    }

    /// "span~<kind>~<session>" (`SpanLayout.pageId`): one per session of a kind, unchanged when the
    /// window shifts (a new id would make the canvas start a new ledger, losing ↶ and the position).
    public static func virtualPageId(_ kind: PageKind, session: Int) -> String {
        virtualPrefix + kind.rawValue + "~" + String(session)
    }

    // MARK: Aliases of long ids (§3.2)

    /// Does a prefixed id need an alias (more than `idByteLimit` bytes)?
    public static func needsAlias(_ prefixedId: String) -> Bool {
        prefixedId.utf8.count > idByteLimit
    }

    /// "<page>|span~a~<number>": the in-memory name of a stroke whose prefixed id is too long. The
    /// table back to the real id belongs to `SpanComposer` (InkModel); every delta and tombstone goes out
    /// with the real id.
    public static func alias(page: String, number: Int) -> String {
        prefixed(id: aliasPrefix + String(number), page: page)
    }

    /// (page, number) of an alias made by `alias(page:number:)`; nil for every other name.
    public static func aliasNumber(_ name: String) -> (page: String, number: Int)? {
        guard let parts = split(name), parts.local.hasPrefix(aliasPrefix) else { return nil }
        let digits = parts.local.dropFirst(aliasPrefix.count)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(digits),
              String(n) == digits else { return nil }
        return (parts.page, n)
    }
}
