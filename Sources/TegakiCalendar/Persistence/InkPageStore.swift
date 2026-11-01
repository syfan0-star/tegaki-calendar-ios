import Foundation
import InkModel

/// On-device storage of ink pages (contract §7):
/// `Application Support/TegakiCalendar/ink/<pageId>.json.lzfse` (JSON from `InkPageCodec.encode`,
/// then LZFSE). Writes are atomic (temporary file + rename). A file that cannot be read is moved
/// aside as `.bak` and an empty page is returned, so handwriting is never silently destroyed.
struct InkPageStore: Sendable {
    /// The directory holding the page files. Created on demand.
    let directory: URL

    /// - Parameter directory: where to keep the files; nil = the default under Application Support.
    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
    }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("TegakiCalendar", isDirectory: true)
            .appendingPathComponent("ink", isDirectory: true)
    }

    /// The file of a page id, e.g. ".../ink/m1-2026-10.json.lzfse".
    func url(for pageId: String) -> URL {
        directory.appendingPathComponent(Self.fileName(for: pageId), isDirectory: false)
    }

    /// `<pageId>.json.lzfse`, with anything that is not safe in a file name replaced by "_".
    static func fileName(for pageId: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let safe = String(pageId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return "\(safe.isEmpty ? "page" : safe).json.lzfse"
    }

    func exists(_ pageId: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: pageId).path)
    }

    /// The page ids of every `*.json.lzfse` in `directory`, sorted (`.bak` files are not pages).
    /// `fileName(for:)` only keeps letters, digits and `-_.`, which is all a page id ever uses, so
    /// the name round-trips (M4_CONTRACT §5.1).
    func allPageIds() -> [String] {
        let suffix = ".json.lzfse"
        guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        var ids: [String] = []
        for item in items {
            let name = item.lastPathComponent
            guard name.hasSuffix(suffix) else { continue }
            let id = String(name.dropLast(suffix.count))
            if !id.isEmpty { ids.append(id) }
        }
        return ids.sorted()
    }

    /// The sync ledger next to the pages: `directory/state.json` (M4_CONTRACT §1.1).
    var stateFileURL: URL {
        directory.appendingPathComponent("state.json", isDirectory: false)
    }

    /// Loads a page. Missing → empty page. Unreadable → the file is renamed to `.bak` (never
    /// overwriting an older backup) and an empty page is returned.
    func load(_ pageId: String) -> InkPage {
        let fileURL = url(for: pageId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return InkPage.empty(pageId: pageId)
        }
        do {
            let compressed = try Data(contentsOf: fileURL)
            let data = try InkPageCodec.decompress(compressed)
            return try InkPageCodec.decode(data)
        } catch {
            moveAside(fileURL)
            return InkPage.empty(pageId: pageId)
        }
    }

    /// Writes a page atomically. The directory is created when needed.
    func save(_ page: InkPage) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try InkPageCodec.encode(page)
        let compressed = try InkPageCodec.compress(data)
        // `.atomic` writes to a temporary file in the same directory and renames it into place.
        try compressed.write(to: url(for: page.pageId), options: [.atomic])
    }

    /// Removes a page file (used by tests).
    func remove(_ pageId: String) throws {
        let fileURL = url(for: pageId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    /// 「この端末の手書きを全て消す」 (M3b contract §4.8; 「この iPad の…」 until 1.0.1): deletes every page file (`*.json.lzfse`) and
    /// every backup (`*.bak`) in `directory`. Other files and the directory itself stay. A missing
    /// directory is nothing to do.
    func removeAll() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return }
        let items = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for item in items {
            let name = item.lastPathComponent
            guard name.hasSuffix(".json.lzfse") || name.hasSuffix(".bak") else { continue }
            try fm.removeItem(at: item)
        }
    }

    // MARK: - Private

    /// Renames a broken file to `<name>.bak`, or `<name>.<timestamp>.bak` if a backup already exists.
    private func moveAside(_ fileURL: URL) {
        let fm = FileManager.default
        var backup = fileURL.appendingPathExtension("bak")
        if fm.fileExists(atPath: backup.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            backup = fileURL.appendingPathExtension("\(stamp)").appendingPathExtension("bak")
        }
        do {
            try fm.moveItem(at: fileURL, to: backup)
        } catch {
            // Leave the broken file where it is rather than deleting it; the next load tries again.
        }
    }
}

// MARK: - Counting without reading (1.1, M7A_CONTRACT §5.3, 0-17)

extension InkPageStore {
    /// What `peek(_:)` found in a page file: the ids of its strokes that carry no tombstone (strokes
    /// of every tool, also those this version does not know) and the number of tombstones.
    struct Peek: Equatable, Sendable {
        var strokeIds: Set<String>
        var tombstones: Int
    }

    /// Reads the page file of `pageId` (the same file as `load`), decompresses it, parses the JSON and
    /// collects the keys of `strokes` (for the list form of `strokes`, the `id` of each element) that
    /// are not keys of `deleted`, and counts the keys of `deleted`. No `InkPage` is built, so nothing
    /// is cut at the read cap (`InkPage.maxStrokes`): the numbers are those of the file.
    ///
    /// Only reads: a missing file, one that cannot be read, decompressed or parsed, or JSON that is
    /// not an object gives nil, and the file stays where it is — it is never moved to `.bak` (`load`'s
    /// `moveAside` is not on this path), never rewritten, never removed. Counting must not touch a
    /// file that is being saved or that the person needs. `load` and `save` are unchanged.
    func peek(_ pageId: String) -> Peek? {
        let fileURL = url(for: pageId)
        guard let compressed = try? Data(contentsOf: fileURL),
              let data = try? InkPageCodec.decompress(compressed),
              let json = try? JSONValue.parse(data),
              let object = json.objectValue else {
            return nil
        }
        let deleted: Set<String> = object["deleted"]?.objectValue.map { Set($0.keys) } ?? []
        var ids = Set<String>()
        if let strokes = object["strokes"]?.objectValue {
            ids = Set(strokes.keys)
        } else if let list = object["strokes"]?.arrayValue {
            for item in list {
                if let id = item["id"]?.stringValue { ids.insert(id) }
            }
        }
        ids.subtract(deleted)
        return Peek(strokeIds: ids, tombstones: deleted.count)
    }
}
