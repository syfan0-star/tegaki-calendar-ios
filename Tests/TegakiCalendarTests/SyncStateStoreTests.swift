import InkModel
import XCTest
@testable import TegakiCalendar

/// `ink/state.json` (M4_CONTRACT §5.2, §8.2): missing → empty, save → load, a broken file is moved
/// aside as `.bak`, `remove`, and the default location next to the pages.
final class SyncStateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncStateStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var fileURL: URL {
        directory.appendingPathComponent("state.json", isDirectory: false)
    }

    func testMissingFileIsEmpty() {
        let store = SyncStateStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSaveThenLoad() throws {
        let store = SyncStateStore(fileURL: fileURL)
        var state = SyncState.empty
        state.markDirty("m1-2026-10")
        state.markDirty("w-2026-10-05")
        state.zoneToken = Data([1, 2, 3])
        state.zoneReady = true
        state.subscriptionReady = true
        state.account = "_0123"
        state.seen["m1-2026-10"] = SeenRecord(changeTag: "jx3pq", systemFields: Data([9, 8]))
        state.lastSyncAt = 1_760_150_500_000
        state.webImportedAt = 1_760_150_000_000
        try store.save(state)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(store.load(), state)
        // Plain JSON, not compressed.
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("{"))
        XCTAssertTrue(text.contains("\"dirty\":[\"m1-2026-10\",\"w-2026-10-05\"]"))
    }

    func testSaveCreatesTheDirectory() throws {
        let nested = directory.appendingPathComponent("a/b", isDirectory: true).appendingPathComponent("state.json")
        let store = SyncStateStore(fileURL: nested)
        try store.save(.empty)
        XCTAssertEqual(store.load(), .empty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func testBrokenFileIsMovedAside() throws {
        try Data("not json at all".utf8).write(to: fileURL)
        let store = SyncStateStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let backup = fileURL.appendingPathExtension("bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertEqual(try Data(contentsOf: backup), Data("not json at all".utf8))

        // A second broken file does not overwrite the first backup.
        try Data("{".utf8).write(to: fileURL)
        XCTAssertEqual(store.load(), .empty)
        XCTAssertEqual(try Data(contentsOf: backup), Data("not json at all".utf8))
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".bak") }
        XCTAssertEqual(backups.count, 2)
    }

    func testRemove() throws {
        let store = SyncStateStore(fileURL: fileURL)
        try store.remove() // nothing there: no throw
        try store.save(.empty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        try store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(store.load(), .empty)
    }

    func testDefaultLocationIsNextToThePages() {
        let store = SyncStateStore()
        XCTAssertEqual(store.fileURL, InkPageStore().stateFileURL)
        XCTAssertEqual(store.fileURL.lastPathComponent, "state.json")
        XCTAssertEqual(store.fileURL.deletingLastPathComponent(), InkPageStore().directory)
    }

    func testInkPageStoreListsItsPages() throws {
        let pages = InkPageStore(directory: directory)
        XCTAssertEqual(pages.allPageIds(), [])
        try pages.save(InkPage.empty(pageId: "w-2026-10-05"))
        try pages.save(InkPage.empty(pageId: "m1-2026-10"))
        try pages.save(InkPage.empty(pageId: "y-2026"))
        try Data([0]).write(to: directory.appendingPathComponent("d-2026-10-07.json.lzfse.bak"))
        try Data([0]).write(to: directory.appendingPathComponent("state.json"))
        XCTAssertEqual(pages.allPageIds(), ["m1-2026-10", "w-2026-10-05", "y-2026"])
        XCTAssertEqual(pages.stateFileURL, directory.appendingPathComponent("state.json", isDirectory: false))
        // `removeAll` keeps the state file.
        try pages.removeAll()
        XCTAssertEqual(pages.allPageIds(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: pages.stateFileURL.path))
    }
}
