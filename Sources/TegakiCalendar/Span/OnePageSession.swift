import Combine
import Foundation
import InkModel
import Layout

/// The one-page path's page and its saving (1.3, docs/M7C_CONTRACT.md §2.1, §3.5, §6.6, D3 の 7, D7, D14): what
/// `CalendarRootScreen` kept for the page on the screen in 1.2.3 (`page`, `pageDirty`, `saveTask`,
/// `capNoticedPageId`, `applyRemote`, the erase, the save timer; CalendarRootScreen.swift:154, :188, :272-273,
/// :1581-1592, :1869-1889, :2147-2160, :2520-2541 of 43fe366), moved here so the tests can drive it, with the
/// same behaviour except three fixes:
/// - H1: `remoteDeleted` (another device's 「全て消す」 deleted the shown page's record) empties the page, stops its
///   save and moves `epoch` on, so the canvas is made anew and ↶ cannot bring the erased strokes back.
/// - H2: `beginEraseAndStart()` (「消して始める」, before the engine's `await`) empties the page, stops the save, moves
///   `epoch` on and pauses every save until `endEraseAndStart()` (after `reloadShownPage`), so nothing of the old
///   account reaches the new account's store.
/// - H3: `eraseAll()` and `beginEraseAndStart()` move `epoch` on: the canvas, and its ↶, are made anew.
/// The canvas's identity carries `epoch` (`canvasIdentity(base:)`), and the canvas's writes are taken only from
/// the canvas of the current identity (`canvasWrote(_:madeFor:base:)`): a `publishPage` the canvas made before it
/// was rebuilt and handed on to the next turn (InkCanvasView.swift:1478-1508) is dropped (§2.1, §6.6).
/// Every save goes through `PageSlot.persist` (`SpanGuard`, which finds nothing to repair on this path, D3 (2)).
/// No UIKit, no SwiftUI: the screen observes it (`ObservableObject`) as it observed its own `@State`.
@MainActor
final class OnePageSession: ObservableObject {
    /// The save timer: 1.5 s after the last change (1.2.3's `scheduleSave`, §3.16).
    static let saveDelay: TimeInterval = 1.5

    let sync: SyncEngine
    /// The page on the screen, its dirty mark and its 「メモ欄はここまでです」 mark.
    @Published private(set) var slot: PageSlot
    /// The screen's number (D7): moved on by 「全て消す」, 「消して始める」 and a record deletion of the shown page
    /// (H1–H3); never by an import. Part of the canvas's identity.
    @Published private(set) var epoch = 0
    /// 「消して始める」 is between its `await` and `reloadShownPage` (H2): `saveNow` and `scheduleSave` do nothing.
    private(set) var savePaused = false
    /// A save failed: the error's text (the screen's 「手書きを保存できませんでした」 alert shows it).
    var onSaveFailed: ((String) -> Void)?
    /// What the session recorded (refusals, repairs), newest last.
    private(set) var records: [String] = []

    private let sleep: @MainActor (TimeInterval) async -> Void
    private let clock: () -> Date
    private var saveTask: Task<Void, Never>?
    private var saveGeneration = 0

    /// `page` is the page the screen starts with (the screenshot mode's demo page, else an empty page of the
    /// remembered id; `show` loads it right after, as in 1.2.3).
    init(sync: SyncEngine, page: InkPage = InkPage(pageId: ""),
         sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
         clock: @escaping () -> Date = Date.init) {
        self.sync = sync
        self.sleep = sleep
        self.clock = clock
        slot = PageSlot(page: page)
    }

    /// The page on the screen (1.2.3's `page`).
    var page: InkPage { slot.page }
    /// Changed since it was last saved (1.2.3's `pageDirty`).
    var isDirty: Bool { slot.dirty }

    // MARK: The canvas

    /// The canvas's identity (`.id(...)`): the screen's `base` (the page id and the week start, 1.2) and `epoch`.
    func canvasIdentity(base: String) -> String {
        "\(base)|\(epoch)"
    }

    /// The canvas wrote its page (the screen's `pageBinding`): taken only when the canvas was made for the
    /// identity that is current now (`madeFor == canvasIdentity(base:)`) and the page is the shown one (1.2.3's
    /// gate, CalendarRootScreen.swift:1149). Then the page is dirty and the save timer starts, as in 1.2.3.
    /// True when it was taken (the screen then counts the person's own ink, 1.2.1).
    @discardableResult
    func canvasWrote(_ page: InkPage, madeFor identity: String, base: String) -> Bool {
        guard identity == canvasIdentity(base: base), page.pageId == slot.page.pageId else { return false }
        slot.page = page
        slot.dirty = true
        scheduleSave()
        return true
    }

    // MARK: Opening

    /// `show`'s part (1.2.3, CalendarRootScreen.swift:1366-1373): the loaded page goes through `BandMigration`;
    /// a page that changed is dirty and saved by the timer (M4B-11). The caller saved the old page first.
    func open(_ loaded: InkPage) {
        let migrated = BandMigration.migrate(loaded)
        slot.page = migrated
        slot.dirty = false
        if migrated != loaded {
            slot.dirty = true
            scheduleSave()
        }
    }

    /// `reloadShownPage`'s part (1.2.3, :2147-2157): the timer stops, then `open`.
    func reload(_ loaded: InkPage) {
        cancelSave()
        open(loaded)
    }

    /// 「メモ欄はここまでです」 for `pageId` (1.2.3's `growthCapReached`): true once while the page is open.
    func noteGrowthCap(pageId: String) -> Bool {
        guard slot.capNoticedPageId != pageId else { return false }
        slot.capNoticedPageId = pageId
        return true
    }

    /// The mark goes (1.2.3 sets `capNoticedPageId = nil` on another page and on a week start switch).
    func forgetGrowthCap() {
        slot.capNoticedPageId = nil
    }

    // MARK: Saving (1.2.3's :2520-2541)

    /// `saveNow()` 1.5 s after the last call. Nothing while saves are paused (H2).
    func scheduleSave() {
        guard !savePaused else { return }
        saveTask?.cancel()
        saveGeneration += 1
        let generation = saveGeneration
        saveTask = Task { @MainActor [weak self] in
            guard let sleep = self?.sleep else { return }
            await sleep(Self.saveDelay)
            guard let self, !Task.isCancelled, generation == self.saveGeneration else { return }
            self.saveNow()
        }
    }

    /// Writes the page now if it changed since the last save (through `PageSlot.persist`: the guard, then the
    /// engine, which queues it for iCloud). Nothing in the screenshot mode, nor while saves are paused (H2).
    func saveNow() {
        cancelSave()
        guard !savePaused, slot.dirty, !ScreenshotMode.isActive else { return }
        let outcome = PageSlot.persist(slot.page, added: slot.added, mode: .release,
                                       willWrite: { [weak self] repaired in self?.slot.page = repaired },
                                       write: { [sync] page in try sync.save(page) })
        switch outcome {
        case .saved:
            slot.dirty = false
        case .repaired(let stripped, let dropped):
            // Window names on this path can only be a leak of the joined path: recorded, and Debug stops (§6.1).
            let message = "repaired \(slot.page.pageId): stripped \(stripped.joined(separator: ",")), dropped \(dropped.joined(separator: ","))"
            record(message)
            slot.dirty = false
            SpanSession.onFault(message)
        case .refused:
            record("refused \(slot.page.pageId)")
            onSaveFailed?("")
        case .failed(let text):
            onSaveFailed?(text)
        }
    }

    private func cancelSave() {
        saveTask?.cancel()
        saveTask = nil
        saveGeneration += 1
    }

    // MARK: From outside (M4 §5.4)

    /// `SyncEngine.onRemoteUpdate` (1.2.3's `applyRemote`, :1581-1592): only the shown page; merged with the
    /// page in memory (a stroke of the last 1.5 s is not in the file yet), the band's strokes moved onto the
    /// grid; dirty and saved when this device has strokes the update lacks. True when the page changed (the
    /// screen lays the paper out again; the canvas reloads keeping its history).
    @discardableResult
    func applyRemote(_ updated: InkPage) -> Bool {
        guard updated.pageId == slot.page.pageId else { return false }
        // ペンを離した直後の未保存の線を落とさない。merge の後に帯の線を grid へ（M4B contract §3.3）
        let merged = BandMigration.migrate(InkPage.merge(slot.page, updated))
        guard merged.contentDiffers(from: slot.page) || merged.updatedAt != slot.page.updatedAt else { return false }
        slot.page = merged                                  // Binding を通さない（dirty にしない）
        if merged.contentDiffers(from: updated) {           // 端末内にしか無い線があった → いつもの経路で保存・送信
            slot.dirty = true
            scheduleSave()
        }
        return true
    }

    /// `SyncEngine.onRemoteDelete` (H1, §6.6): another device's 「全て消す」 deleted the shown page's record (the
    /// engine removed the file and gave `applyRemote` an empty page, which changed nothing). The page empties —
    /// a stroke written here since it was last sent goes too, as the erase was for every device — its save
    /// stops, and `epoch` moves on, so the canvas is made anew from the empty page and its ↶ is gone. True when
    /// it was the shown page.
    @discardableResult
    func remoteDeleted(_ pageId: String) -> Bool {
        guard pageId == slot.page.pageId else { return false }
        cancelSave()
        slot.page = InkPage.empty(pageId: pageId)
        slot.dirty = false
        epoch += 1
        return true
    }

    // MARK: Erasing (M4 §6.2, §6.4)

    /// 「この端末の手書きを全て消す」 (1.2.3's `eraseAllInk`, :1871-1874, with H3): the timer stops, the page empties
    /// and is not dirty, and `epoch` moves on (a new canvas: no ↶ brings the erased strokes back).
    func eraseAll() {
        cancelSave()
        slot.page = InkPage.empty(pageId: slot.page.pageId)
        slot.dirty = false
        epoch += 1
    }

    /// 「消して始める」, before the engine's `await` (H2): as `eraseAll`, and every save waits until
    /// `endEraseAndStart()`.
    func beginEraseAndStart() {
        eraseAll()
        savePaused = true
    }

    /// After `reloadShownPage` (H2): saves go on; a page the reload left dirty (its band migrated) is saved by
    /// the timer.
    func endEraseAndStart() {
        guard savePaused else { return }
        savePaused = false
        if slot.dirty { scheduleSave() }
    }

    private func record(_ message: String) {
        records.append(message)
        if records.count > 50 { records.removeFirst(records.count - 50) }
        #if DEBUG
        NSLog("one page session: %@", message)
        #endif
    }
}
