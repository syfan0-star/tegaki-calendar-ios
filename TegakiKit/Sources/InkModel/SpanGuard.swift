import Foundation

/// The guard at every way out of the joined pages (1.3, docs/M7C_CONTRACT.md §2.1, §3.2, §6.1, D14;
/// B_DESIGN.md §2.4 11): the names that exist only in a window's memory — the virtual page id
/// "span~<kind>~<n>", the prefixed names "<pageId>|<name>" and the stripped alias "span~a~<n>" — never
/// reach a saved page, an import, an export or the page a PDF is drawn from. It works in Release too.
///
/// - `checkForSave` (`PageSlot.persist`, the one save of the screen, both paths): the page id must be of
///   the form this version writes, else the whole page is refused (today's 「手書きを保存できませんでした」).
///   A bad item never refuses the page (refusing would lose everything written there since, §6.1):
///   only the offending items are repaired — a prefix of the page itself is taken off (`stripped`), an
///   item named with another page's prefix or with "span~" is left out (`dropped`; its real owner gets
///   it through the deltas and the safety net) — and every other item is kept byte for byte.
/// - `checkForTransfer` (import, export, the `page:` of a PDF): only the window names, so a page of a
///   kind a newer version makes still passes (F2).
///
/// What a prefix is follows `SpanName` (the form `^(?:[dw]-\d{4}-\d{2}-\d{2}|m1-\d{4}-\d{2}|y-\d{4})\|`
/// with ASCII digits): a name that merely holds a "|" (an import, a web stroke, a newer version's tool,
/// a hand-edited JSON) is no window name. K-10 forbids "|" only in what 1.3 and later make, so the broad
/// "|" ban applies to the strokes this session added (`added`: their ids and cells) and nothing else.
///
/// Whatever passes `checkForTransfer` and has a page id of the write form passes `checkForSave`
/// untouched (`.ok`): both look at the same names (KitChecks fixes it over random pages).
public enum SpanGuard {
    /// `.release`: the app. `.prototype`: the prototype of §4.6 (`SPAN_PROTOTYPE`), whose pages are
    /// "proto-<page id>" and live in a folder of their own; it refuses every real page id (D13, §4.6 (a)).
    /// `SpanPlan`, `SpanComposer` and `SpanLayout` read only real page ids, so the prototype composes its
    /// window with them and its slot saves each page as "proto-<id>": on the page "proto-<id>" the
    /// window's names of "<id>" are the page's own (stripped, as "proto-<id>|…" is); every other page's
    /// prefix, real or "proto-", is dropped.
    public enum Mode: Sendable {
        case release, prototype
    }

    public enum SaveCheck: Sendable, Equatable {
        /// Save the page as it is.
        case ok
        /// Save this page instead: only the offending items changed. `stripped` and `dropped` are their
        /// original keys (strokes, tombstones and unknown-tool items together), sorted, each once per list
        /// (a key that is stripped in one collection and dropped in another is in both).
        case repaired(InkPage, stripped: [String], dropped: [String])
        /// The page id is not of the form this mode writes: the page is not saved (the only refusal).
        case refused
    }

    /// The start of a prototype page id (§4.6 (a)).
    public static let prototypePrefix = "proto-"

    // MARK: The page id

    /// The page ids this version writes: "d-YYYY-MM-DD", "w-YYYY-MM-DD" whose day is a Monday or a
    /// Sunday (K-11), "m1-YYYY-MM", "y-YYYY", ASCII digits (§6.1; the form, as the contract's regex: a
    /// "d-" or "m1-" date that does not exist still has the form; a "w-" day must exist to be a Monday
    /// or a Sunday).
    public static func isWriteForm(_ pageId: String) -> Bool {
        // `SpanName` reads exactly these forms in front of "|": the id is of the form when the whole of
        // "<id>|" is a prefix with nothing after it.
        guard let parts = SpanName.split(pageId + String(SpanName.separator)), parts.local.isEmpty,
              parts.page == pageId else { return false }
        if pageId.hasPrefix("w-") {
            guard let day = DayKey(ymd: String(pageId.dropFirst(2))) else { return false }
            return day.weekday == 0 || day.weekday == 1
        }
        return true
    }

    /// The page ids `mode` saves: the write form (`.release`), "proto-" + the write form (`.prototype`).
    public static func savesPageId(_ pageId: String, mode: Mode = .release) -> Bool {
        switch mode {
        case .release:
            return isWriteForm(pageId)
        case .prototype:
            return pageId.hasPrefix(prototypePrefix) && isWriteForm(String(pageId.dropFirst(prototypePrefix.count)))
        }
    }

    // MARK: Names

    /// Is the name one that exists only in a window: prefixed with a page id ("<pageId>|…") or virtual
    /// ("span~…")? (What `checkForTransfer` refuses and `checkForSave` repairs.)
    public static func isWindowName(_ name: String) -> Bool {
        SpanName.isPrefixed(name) || SpanName.isVirtual(name)
    }

    /// The page in front of a prefixed name and the rest; in `.prototype` "proto-<pageId>|…" too.
    static func prefixParts(_ name: String, mode: Mode) -> (page: String, local: String)? {
        if let parts = SpanName.split(name) { return parts }
        if mode == .prototype, name.hasPrefix(prototypePrefix),
           let parts = SpanName.split(String(name.dropFirst(prototypePrefix.count))) {
            return (prototypePrefix + parts.page, parts.local)
        }
        return nil
    }

    enum Verdict: Equatable {
        case keep
        case strip(String)
        case drop
    }

    /// Is `prefixPage` (the page in front of a prefixed name) the own prefix of page `pageId`? The page id
    /// itself; in `.prototype` also the real id of a "proto-<id>" page, whose window was composed with it.
    static func isOwnPrefix(_ prefixPage: String, of pageId: String, mode: Mode) -> Bool {
        if prefixPage == pageId { return true }
        return mode == .prototype && pageId.hasPrefix(prototypePrefix) && prefixPage == String(pageId.dropFirst(prototypePrefix.count))
    }

    /// One name of an item of page `pageId`: kept, stripped of the page's own prefix, or dropped (another
    /// page's prefix, "span~", or a stripped name that is still a window name or empty).
    static func verdict(_ name: String, pageId: String, mode: Mode) -> Verdict {
        if let parts = prefixParts(name, mode: mode) {
            guard isOwnPrefix(parts.page, of: pageId, mode: mode), !parts.local.isEmpty, !SpanName.isVirtual(parts.local),
                  prefixParts(parts.local, mode: mode) == nil else { return .drop }
            return .strip(parts.local)
        }
        return SpanName.isVirtual(name) ? .drop : .keep
    }

    /// Every name of a page the guard looks at: the page id; each stroke's key, id and cell; each
    /// tombstone's key; each unknown-tool item's key and its own "id" and "cell" when they are strings.
    static func names(of page: InkPage) -> [String] {
        var out: [String] = [page.pageId]
        for (key, stroke) in page.strokes {
            out.append(key)
            out.append(stroke.id)
            out.append(stroke.cell.raw)
        }
        for key in page.deleted.keys { out.append(key) }
        for (key, raw) in page.unknownStrokes {
            out.append(key)
            if let id = raw["id"]?.stringValue { out.append(id) }
            if let cell = raw["cell"]?.stringValue { out.append(cell) }
        }
        return out
    }

    // MARK: Transfer (import, export, the PDF's page)

    /// True when neither the page id nor any key, stroke id, cell or unknown item's id / cell of the page
    /// is a window name (§6.1, D14, D17). The page id's form is not looked at (a newer version's page
    /// passes, F2).
    public static func checkForTransfer(_ page: InkPage) -> Bool {
        !names(of: page).contains(where: isWindowName)
    }

    // MARK: Save

    /// The check of `PageSlot.persist` (§6.1). `added`: the ids of the strokes this session added to the
    /// page (the deltas' `added`), the only items whose id or cell may not hold a "|" at all (K-10).
    public static func checkForSave(_ page: InkPage, added: Set<String> = [], mode: Mode = .release) -> SaveCheck {
        guard savesPageId(page.pageId, mode: mode) else { return .refused }
        let pageId = page.pageId

        func isAdded(_ names: String...) -> Bool {
            !added.isEmpty && names.contains { added.contains($0) }
        }
        func barred(_ names: String...) -> Bool {
            names.contains { $0.contains(SpanName.separator) }
        }

        // Per collection: the keys to take out, and the stripped items to put back.
        var outStrokes: Set<String> = []
        var outTombstones: Set<String> = []
        var outUnknown: Set<String> = []
        var stripped: Set<String> = []
        var dropped: Set<String> = []
        var strippedStrokes: [(key: String, stroke: InkStroke)] = []
        var strippedTombstones: [(key: String, time: Int)] = []
        var strippedUnknown: [(key: String, raw: JSONValue)] = []

        // Strokes: the key, the id and the cell.
        for key in page.strokes.keys.sorted() {
            let stroke = page.strokes[key]!
            let verdicts = [verdict(key, pageId: pageId, mode: mode), verdict(stroke.id, pageId: pageId, mode: mode),
                            verdict(stroke.cell.raw, pageId: pageId, mode: mode)]
            if verdicts.contains(.drop) {
                outStrokes.insert(key)
                dropped.insert(key)
                continue
            }
            let finalKey = verdicts[0].name(or: key)
            let finalId = verdicts[1].name(or: stroke.id)
            let finalCell = verdicts[2].name(or: stroke.cell.raw)
            if isAdded(key, stroke.id, finalKey, finalId) && barred(finalKey, finalId, finalCell) {
                outStrokes.insert(key)
                dropped.insert(key)
                continue
            }
            if verdicts != [.keep, .keep, .keep] {
                var copy = stroke
                copy.id = finalId
                copy.cell = CellKey(raw: finalCell)
                outStrokes.insert(key)
                strippedStrokes.append((finalKey, copy))
                stripped.insert(key)
            }
        }

        // Tombstones: the key.
        for key in page.deleted.keys.sorted() {
            let v = verdict(key, pageId: pageId, mode: mode)
            if v == .drop {
                outTombstones.insert(key)
                dropped.insert(key)
                continue
            }
            let finalKey = v.name(or: key)
            if isAdded(key, finalKey) && barred(finalKey) {
                outTombstones.insert(key)
                dropped.insert(key)
                continue
            }
            if v != .keep {
                outTombstones.insert(key)
                strippedTombstones.append((finalKey, page.deleted[key]!))
                stripped.insert(key)
            }
        }

        // Strokes of an unknown tool: the key and the object's own "id" and "cell" when they are strings.
        for key in page.unknownStrokes.keys.sorted() {
            let raw = page.unknownStrokes[key]!
            let id = raw["id"]?.stringValue
            let cell = raw["cell"]?.stringValue
            let keyVerdict = verdict(key, pageId: pageId, mode: mode)
            let idVerdict = id.map { verdict($0, pageId: pageId, mode: mode) } ?? .keep
            let cellVerdict = cell.map { verdict($0, pageId: pageId, mode: mode) } ?? .keep
            if [keyVerdict, idVerdict, cellVerdict].contains(.drop) {
                outUnknown.insert(key)
                dropped.insert(key)
                continue
            }
            let finalKey = keyVerdict.name(or: key)
            let finalId = id.map { idVerdict.name(or: $0) }
            let finalCell = cell.map { cellVerdict.name(or: $0) }
            if isAdded(key, finalKey, id ?? key, finalId ?? key) && barred(finalKey, finalId ?? "", finalCell ?? "") {
                outUnknown.insert(key)
                dropped.insert(key)
                continue
            }
            if keyVerdict != .keep || idVerdict != .keep || cellVerdict != .keep {
                var object = raw.objectValue ?? [:]
                if let finalId = finalId, idVerdict != .keep { object["id"] = .string(finalId) }
                if let finalCell = finalCell, cellVerdict != .keep { object["cell"] = .string(finalCell) }
                outUnknown.insert(key)
                strippedUnknown.append((finalKey, raw.objectValue == nil ? raw : .object(object)))
                stripped.insert(key)
            }
        }

        if stripped.isEmpty && dropped.isEmpty { return .ok }

        // The page without every repaired item, then the stripped items put back with the merge's rules
        // (a tombstone wins over a stroke; two contents of one id: the deterministic pick).
        var out = page
        for key in outStrokes { out.strokes[key] = nil }
        for key in outTombstones { out.deleted[key] = nil }
        for key in outUnknown { out.unknownStrokes[key] = nil }
        for (key, time) in strippedTombstones {
            out.deleted[key] = max(out.deleted[key] ?? time, time)
            out.strokes[key] = nil
            out.unknownStrokes[key] = nil
        }
        for (key, stroke) in strippedStrokes where out.deleted[key] == nil {
            if let current = out.strokes[key] {
                out.strokes[key] = InkPage.pickStroke(current, stroke)
            } else {
                out.strokes[key] = stroke
            }
            out.unknownStrokes[key] = nil
        }
        for (key, raw) in strippedUnknown where out.deleted[key] == nil && out.strokes[key] == nil {
            if let current = out.unknownStrokes[key] {
                out.unknownStrokes[key] = InkPage.pickJSON(current, raw)
            } else {
                out.unknownStrokes[key] = raw
            }
        }
        return .repaired(out, stripped: stripped.sorted(), dropped: dropped.sorted())
    }
}

extension SpanGuard.Verdict {
    /// The name after the verdict (`.drop` never gets here).
    func name(or original: String) -> String {
        if case .strip(let local) = self { return local }
        return original
    }
}
