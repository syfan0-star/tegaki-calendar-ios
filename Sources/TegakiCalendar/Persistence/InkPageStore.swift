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

    /// Removes a page file (used by tests and, later, by "この iPad の手書きを全て消す").
    func remove(_ pageId: String) throws {
        let fileURL = url(for: pageId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
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
