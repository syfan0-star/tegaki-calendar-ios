#if SPAN_PROTOTYPE
import CryptoKit
import Foundation
import Holidays
import InkModel
import Layout
import PencilKit
import UIKit
import XCTest
@testable import TegakiCalendar

/// The prototype is kept away from the person's handwriting and iCloud by how it is built
/// (docs/M7C_CONTRACT.md §4.6 (a)–(c), D13, §10.2 row T). The four tests open the prototype as its screen
/// does (`SpanPrototypeModel` over `SpanPrototypeEnvironment.makeIsolated()`, the size of an 11-inch iPad
/// in portrait: a window of five weeks), write through the prototype canvas — one stroke across the
/// boundary of this week and the next, one on the next week — and save and close it. The whole file is
/// compiled only with `SPAN_PROTOTYPE` (the span-shots job builds a host with it and runs these four,
/// §10.6); the normal build has none of it.
///
/// In this XCTest host `SyncEngine.shared` is the inert engine (SyncEngine.swift:19-30): a call to its
/// `save` or `pageOpened` would leave no trace of its own. So the tests watch what a call would need or
/// do — the folder the app keeps its pages in, the engine and the store the prototype holds, every
/// engine reachable from it, the shared engine's state and hook, and the prototype's source.
@MainActor
final class PrototypeIsolationTests: XCTestCase {
    /// 2026-11-11 (a Wednesday), 10:00: the window is the weeks of 10/26 … 11/23, the focus the week of 11/9.
    private let now = DayKey(year: 2026, month: 11, day: 11).startOfDay().addingTimeInterval(10 * 3600)
    /// The 11-inch iPad in portrait (`SpanDeviceClass.iPad11`, `.portrait`).
    private let screen = CGSize(width: 834, height: 1194)

    // MARK: Helpers

    /// What the prototype wrote: the real ids of the focus week and the next one, and the strokes' ids.
    private struct Written {
        var focusId: String
        var nextId: String
        var crossingId: String
        var nextStrokeId: String
    }

    /// The prototype as its screen opens it, with the folder the test can look into.
    private func openPrototype() throws -> (model: SpanPrototypeModel, session: SpanPrototypeSession) {
        let model = SpanPrototypeModel(environment: SpanPrototypeEnvironment.makeIsolated(), weekStart: .monday, now: now,
                                       holidays: .japan, events: [])
        model.screenChanged(screen, isPad: true)
        let session = try XCTUnwrap(model.session)
        XCTAssertEqual(session.plan.deviceClass, .iPad11)
        XCTAssertEqual(session.plan.orientation, .portrait)
        XCTAssertEqual(session.pageIds.count, 5)
        return (model, session)
    }

    /// Writes through the prototype canvas, as the person would: a pen stroke whose bounds' centre is
    /// 15 lu left of the boundary between the focus week and the next (its points reach 30 lu into the
    /// next week), and one on the next week. The canvas hands the deltas to the session's inbox; the
    /// session saves them (`saveAll`).
    private func write(in session: SpanPrototypeSession) async throws -> Written {
        let view = SpanPrototypeCanvas(layout: session.layout, papers: session.papers, tool: .ink(InkPresets.defaultPen),
                                       allowFinger: false, window: session.window, windowVersion: session.windowVersion,
                                       inbox: session.inbox, epoch: session.epoch)
        let coordinator = SpanPrototypeCanvas.Coordinator(parent: view)
        let container = SpanPrototypeContainerView(papers: session.papers)
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: screen.width, height: 1000)
        container.layoutSubviews()
        await settle()

        let boundary = session.layout.origin(ofSlot: session.focusSlot + 1)
        let crossing = stroke(from: CGPoint(x: boundary - 60, y: 600), to: CGPoint(x: boundary + 30, y: 640))
        let onNext = stroke(from: CGPoint(x: boundary + 300, y: 700), to: CGPoint(x: boundary + 360, y: 720))
        let canvas = container.canvasView
        canvas.drawing = PKDrawing(strokes: canvas.drawing.strokes + [crossing, onNext])
        coordinator.canvasViewDrawingDidChange(canvas)
        coordinator.detach()
        await settle()

        XCTAssertEqual(session.saveAll(), [], "every page saved")
        let focusId = session.pageIds[session.focusSlot]
        let nextId = session.pageIds[session.focusSlot + 1]
        let focusPage = try XCTUnwrap(session.slots[focusId]?.page)
        let nextPage = try XCTUnwrap(session.slots[nextId]?.page)
        XCTAssertEqual(focusPage.liveStrokes.count, 1, "the stroke across the boundary belongs to the page under its centre (D15)")
        XCTAssertEqual(nextPage.liveStrokes.count, 1)
        return Written(focusId: focusId, nextId: nextId, crossingId: try XCTUnwrap(focusPage.liveStrokes.first?.id),
                       nextStrokeId: try XCTUnwrap(nextPage.liveStrokes.first?.id))
    }

    /// A pen stroke of 7 points from `a` to `b` (paper lu of the band).
    private func stroke(from a: CGPoint, to b: CGPoint) -> PKStroke {
        let points = (0..<7).map { i -> PKStrokePoint in
            let f = CGFloat(i) / 6
            return PKStrokePoint(location: CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f),
                                 timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: 3.5, height: 3.5),
                                 opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()),
                        transform: .identity, mask: nil)
    }

    /// Lets the queued main-actor tasks (the inbox's arrival, the next-turn deliveries) run.
    private func settle() async {
        for _ in 0..<8 {
            await Task.yield()
        }
    }

    /// Every file under `folder` (sub-folders too) by its path in the folder ("/<name>"), with its SHA-256.
    private func fingerprint(of folder: URL) throws -> [String: String] {
        var out: [String: String] = [:]
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else { return out }
        for subpath in try fm.subpathsOfDirectory(atPath: folder.path) {
            let item = folder.appendingPathComponent(subpath)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            out["/" + subpath] = SHA256.hash(data: try Data(contentsOf: item)).map { String(format: "%02x", $0) }.joined()
        }
        return out
    }

    /// The app's own `.swift` files of the prototype (Sources/TegakiCalendar/Span/SpanPrototype*.swift), read
    /// from the repository through `#filePath` (the simulator can read the Mac's files), comments taken out.
    private func prototypeSources() throws -> [String: String] {
        let repository = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = repository.appendingPathComponent("Sources/TegakiCalendar/Span", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix("SpanPrototype") && $0.hasSuffix(".swift") }.sorted()
        XCTAssertEqual(names, ["SpanPrototypeCanvas.swift", "SpanPrototypeLedger.swift", "SpanPrototypeMeasure.swift", "SpanPrototypeMemo.swift",
                               "SpanPrototypeScreen.swift", "SpanPrototypeSession.swift", "SpanPrototypeShots.swift"])
        var out: [String: String] = [:]
        for name in names {
            let text = try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
            out[name] = text.components(separatedBy: "\n").map { line -> String in
                guard let range = line.range(of: "//") else { return line }
                return String(line[..<range.lowerBound])
            }.joined(separator: "\n")
        }
        return out
    }

    // MARK: The four tests (§10.2 row T)

    /// The folder the app keeps its handwriting in (`InkPageStore.defaultDirectory()`: every page file and
    /// `state.json`) is the same, name for name and byte for byte, before and after the prototype is opened,
    /// written in, saved and closed. The folder holds the page the prototype writes to (the week of 11/9,
    /// seeded here when the device has none, and taken away again) and a `state.json`.
    ///
    /// It fails if the prototype wrote through the app's store or engine, or through a store or a state
    /// store made with their defaults (`InkPageStore()`, `SyncStateStore()`): the week's file would hold the
    /// merged strokes (another SHA-256), a "proto-…" or another page file would appear, or `state.json` would
    /// change. The prototype's own folder holds what it wrote (it did write), and is gone after it closed.
    func testPrototypeLeavesTheRealInkFolderByteForByte() async throws {
        let real = InkPageStore()
        let realState = SyncStateStore()
        XCTAssertEqual(real.directory.standardizedFileURL, InkPageStore.defaultDirectory().standardizedFileURL)
        XCTAssertEqual(realState.fileURL.standardizedFileURL, real.stateFileURL.standardizedFileURL)
        let plan = SpanPlan(kind: .week, weekStart: .monday, deviceClass: .iPad11, orientation: .portrait)
        let focusId = plan.pageId(at: plan.index(containing: DayKey(now)))
        XCTAssertEqual(focusId, "w-2026-11-09")
        // Seeded only when missing, and only what was seeded is taken away again.
        var seededPage = false
        var seededState = false
        defer {
            if seededPage { try? real.remove(focusId) }
            if seededState { try? realState.remove() }
        }
        if !real.exists(focusId) {
            let seed = InkStroke(id: "isolation-seed", cell: .grid, tool: .pen, color: "#1f2937", t: 1_791_000_000_000,
                                 points: [InkPoint(x: 100, y: 100, dtMs: 0, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)])
            try real.save(InkPage(pageId: focusId, strokes: [seed.id: seed], updatedAt: seed.t))
            seededPage = true
        }
        if !FileManager.default.fileExists(atPath: realState.fileURL.path) {
            var state = SyncState.empty
            state.markDirty(focusId)
            try realState.save(state)
            seededState = true
        }
        let before = try fingerprint(of: real.directory)
        XCTAssertNotNil(before["/" + InkPageStore.fileName(for: focusId)])
        XCTAssertNotNil(before["/state.json"])

        let (model, session) = try openPrototype()
        let written = try await write(in: session)
        let protoStore = model.environment.store
        XCTAssertEqual(protoStore.allPageIds(), ["proto-" + written.focusId, "proto-" + written.nextId], "it wrote, in its own folder")
        XCTAssertEqual(protoStore.load("proto-" + written.focusId).liveStrokeIds, [written.crossingId])
        XCTAssertEqual(protoStore.load("proto-" + written.nextId).liveStrokeIds, [written.nextStrokeId])
        model.close()

        XCTAssertEqual(try fingerprint(of: real.directory), before, "the app's ink folder is untouched")
        XCTAssertFalse(real.load(written.focusId).isLive(written.crossingId))
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.environment.folder.path), "the prototype's folder is gone")
    }

    /// The shared engine's `save` and `pageOpened` are never called: the prototype holds an engine of its
    /// own (not `SyncEngine.shared`) over its own store and state file and an in-memory database, no engine
    /// reachable from the prototype is the shared one, its engine never reached the database (never
    /// started: no push, no fetch of an opened page), the shared engine's state is the same afterwards, and
    /// the prototype's source names neither the shared engine nor a page-opened fetch.
    ///
    /// It fails if the prototype were given the shared engine (the identity checks and the walk over the
    /// session and the model), wrote through the app's store or state file (the folder and file checks),
    /// started its engine or fetched an opened page (the database's calls), or if its code called
    /// `SyncEngine.shared`, `pageOpened` or `pagesOpened` anywhere (the source check: in this host the
    /// shared engine is inert, so such a call would leave no trace at run time).
    func testPrototypeNeverCallsSharedSaveOrPageOpened() async throws {
        let shared = SyncEngine.shared
        let stateBefore = shared.state
        let snapshotBefore = shared.snapshot
        let (model, session) = try openPrototype()
        let environment = model.environment

        XCTAssertFalse(environment.sync === shared)
        XCTAssertTrue(session.sync === environment.sync)
        XCTAssertTrue(environment.sync.store.directory.standardizedFileURL == environment.folder.standardizedFileURL)
        XCTAssertNotEqual(environment.folder.standardizedFileURL, InkPageStore.defaultDirectory().standardizedFileURL)
        XCTAssertNotEqual(environment.folder.standardizedFileURL, shared.store.directory.standardizedFileURL)
        XCTAssertTrue(environment.folder.standardizedFileURL.path.hasPrefix(FileManager.default.temporaryDirectory.standardizedFileURL.path))
        XCTAssertEqual(environment.sync.stateStore.fileURL.standardizedFileURL,
                       environment.folder.appendingPathComponent("state.json").standardizedFileURL)
        XCTAssertNotEqual(environment.sync.stateStore.fileURL.standardizedFileURL, SyncStateStore().fileURL.standardizedFileURL)
        XCTAssertTrue(environment.sync.database === environment.database)

        _ = try await write(in: session)
        XCTAssertGreaterThan(session.savedCount, 0, "the prototype saved through its own engine")
        model.close()

        // No engine reachable from the prototype (two levels deep) is the shared one.
        func engines(in value: Any, depth: Int) -> [SyncEngine] {
            var out: [SyncEngine] = []
            for child in Mirror(reflecting: value).children {
                if let engine = child.value as? SyncEngine { out.append(engine) }
                if depth > 0 { out += engines(in: child.value, depth: depth - 1) }
            }
            return out
        }
        let reachable = engines(in: model, depth: 2) + engines(in: session, depth: 2)
        XCTAssertFalse(reachable.isEmpty)
        XCTAssertFalse(reachable.contains { $0 === shared })

        XCTAssertEqual(environment.database.calls, [], "the prototype's engine never pushed, pulled or fetched an opened page")
        XCTAssertEqual(shared.state, stateBefore)
        XCTAssertEqual(shared.snapshot, snapshotBefore)

        for (name, code) in try prototypeSources() {
            for forbidden in ["SyncEngine.shared", ".shared.save", "pageOpened(", "pagesOpened(", "InkPageStore()", "SyncStateStore()",
                              "InkPageStore.defaultDirectory", "EKEventStore", "import EventKit", "EventStoreModel", "EventKitService"] {
                XCTAssertFalse(code.contains(forbidden), "\(name) uses \(forbidden)")
            }
        }
    }

    /// The shared engine's `onRemoteUpdate` (one hook, set by the calendar screen,
    /// CalendarRootScreen.swift:1190) is the same before and after: a stand-in hook installed before the
    /// prototype is opened still receives a page handed to the shared engine's hook afterwards, the
    /// prototype never called it, and the prototype's own engine has no hook either (the prototype touches
    /// no `onRemoteUpdate` at all; its source does not name it).
    ///
    /// It fails if the prototype set or cleared the shared hook (the stand-in would not receive the page:
    /// iCloud's updates would no longer reach the calendar screen), delivered a page through it (the
    /// stand-in would have been called during the run), or hooked its own engine.
    func testPrototypeLeavesOnRemoteUpdateAlone() async throws {
        let shared = SyncEngine.shared
        let original = shared.onRemoteUpdate
        defer { shared.onRemoteUpdate = original }
        var received: [String] = []
        shared.onRemoteUpdate = { received.append($0.pageId) }

        let (model, session) = try openPrototype()
        _ = try await write(in: session)
        XCTAssertNil(model.environment.sync.onRemoteUpdate)
        model.close()
        await settle()
        XCTAssertEqual(received, [], "the prototype handed nothing to the shared hook")

        shared.onRemoteUpdate?(InkPage(pageId: "w-2026-11-09"))
        XCTAssertEqual(received, ["w-2026-11-09"], "the shared hook is still the one installed before")
        for (name, code) in try prototypeSources() {
            XCTAssertFalse(code.contains("onRemoteUpdate"), "\(name) uses onRemoteUpdate")
        }
    }

    /// `SpanGuard`'s `.prototype` refuses every real page id, of every kind and both week starts, and saves
    /// only "proto-<id>" (§4.6 (a)); every file the prototype wrote is a "proto-…" page.
    ///
    /// It fails if the prototype's guard let a real id through (the session's save would then be one
    /// `checkForSave` away from writing the person's page), or if the session saved any page under a real id.
    func testPrototypeGuardRejectsRealIds() async throws {
        let stroke = InkStroke(id: "s1", cell: .grid, tool: .pen, color: "#1f2937", t: 1_791_000_000_000,
                               points: [InkPoint(x: 10, y: 10, dtMs: 0, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.571)])
        for id in ["w-2026-11-09", "w-2026-11-08", "d-2026-11-11", "m1-2026-11", "y-2026"] {
            XCTAssertTrue(SpanGuard.isWriteForm(id), id)
            let real = InkPage(pageId: id, strokes: [stroke.id: stroke], updatedAt: stroke.t)
            XCTAssertEqual(SpanGuard.checkForSave(real, mode: .prototype), .refused, id)
            XCTAssertEqual(SpanGuard.checkForSave(InkPage(pageId: id), mode: .prototype), .refused, "\(id), empty")
            var proto = real
            proto.pageId = SpanPrototypeSession.fileId(id)
            XCTAssertEqual(proto.pageId, "proto-" + id)
            XCTAssertEqual(SpanGuard.checkForSave(proto, mode: .prototype), .ok, proto.pageId)
            XCTAssertEqual(SpanGuard.checkForSave(proto, mode: .release), .refused, "the app's own guard refuses \(proto.pageId)")
        }
        for id in ["proto-span~week~1", "span~week~1", "proto-", "proto-w-2026-11-10", "x-2026"] {
            XCTAssertEqual(SpanGuard.checkForSave(InkPage(pageId: id), mode: .prototype), .refused, id)
        }

        let (model, session) = try openPrototype()
        _ = try await write(in: session)
        let ids = model.environment.store.allPageIds()
        XCTAssertFalse(ids.isEmpty)
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("proto-") && SpanGuard.isWriteForm(String($0.dropFirst("proto-".count))) }, "\(ids)")
        XCTAssertFalse(session.records.contains { $0.hasPrefix("refused") || $0.hasPrefix("repaired") }, "\(session.records)")
        model.close()
    }
}
#endif
