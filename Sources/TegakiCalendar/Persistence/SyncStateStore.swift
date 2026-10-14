import Foundation
import InkModel

/// On-device storage of the sync ledger (M4_CONTRACT §5.2, §1.1): `ink/state.json` next to the page
/// files, plain JSON from `SyncStateCodec`. Writes are atomic (temporary file + rename). A file that
/// cannot be read is moved aside as `.bak` and the empty state is returned, like a page file.
struct SyncStateStore: Sendable {
    let fileURL: URL

    init(fileURL: URL = InkPageStore().stateFileURL) {
        self.fileURL = fileURL
    }

    /// Missing → `.empty`. Unreadable → renamed to `.bak` (never overwriting an older backup), `.empty`.
    func load() -> SyncState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        do {
            let data = try Data(contentsOf: fileURL)
            return try SyncStateCodec.decode(data)
        } catch {
            moveAside()
            return .empty
        }
    }

    /// Writes the state atomically. The directory is created when needed.
    func save(_ state: SyncState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try SyncStateCodec.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Renames the broken file to `state.json.bak`, or `state.json.<timestamp>.bak` when that exists.
    private func moveAside() {
        let fm = FileManager.default
        var backup = fileURL.appendingPathExtension("bak")
        if fm.fileExists(atPath: backup.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            backup = fileURL.appendingPathExtension("\(stamp)").appendingPathExtension("bak")
        }
        do {
            try fm.moveItem(at: fileURL, to: backup)
        } catch {
            // Leave the broken file where it is; the next load tries again.
        }
    }
}
