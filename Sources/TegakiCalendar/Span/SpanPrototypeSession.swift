#if SPAN_PROTOTYPE
import Combine
import Foundation
import Holidays
import InkModel
import Layout
import QuartzCore

// The prototype's window of joined pages and where it keeps them (1.3, docs/M7C_CONTRACT.md §4.6, D12,
// D13, §3.4, §3.5): the inbox the canvas hands its deltas to, the folder and the engine of the
// prototype alone, and the session that holds the window's real pages, applies the deltas, saves with
// the prototype's guard and composes the window again. Compiled only into the prototype build
// (`SPAN_PROTOTYPE`); it goes away with the prototype (S6).
//
// Isolation (§4.6 (a)–(c), D13): everything here works on what it is given. The prototype's own
// `InkPageStore` and `SyncStateStore` live in a folder of its own under the temporary directory, the
// `SyncEngine` over them and an `InMemoryCloudDatabase` is never started (so it never pushes, pulls or
// writes a state file, SyncEngine.swift:186, :449, :1066), and nothing here names the app's shared
// engine, its store, its remote-update hook, EventKit or a page-opened fetch. The pages on file are
// "proto-<page id>"; the window is composed with the real ids (the Kit reads only those), and every save
// goes through `SpanGuard.checkForSave(…, mode: .prototype)`, which refuses any id that is not
// "proto-<id>" (§4.6 (a); PrototypeIsolationTests).

// MARK: - Inbox

/// What the prototype canvas hands its session (§3.4 (a)): the deltas of every change in the turn of the
/// change, the names among them that tell no page (§3.4 (d)), and the window as the canvas's ledger holds
/// it now (the safety net's source, §3.4 (c)). A reference type, not SwiftUI state, so the canvas may put
/// into it inside `updateUIView`. Whatever arrives is taken once, on the next main-actor turn
/// (`onArrival`), unless the session takes it before.
@MainActor
final class SpanPrototypeInbox {
    private(set) var deltas: [PageDelta] = []
    private(set) var unrouted: [String] = []
    /// The canvas's window with its ledger's page as of the last `put`; nil before the first one.
    private(set) var latestWindow: SpanVirtualPage?
    /// Called on the next turn after deltas or unrouted names arrive (once for all that arrive meanwhile).
    var onArrival: (() -> Void)?
    private var arrivalScheduled = false

    var isEmpty: Bool { deltas.isEmpty && unrouted.isEmpty }

    /// Keeps `window` as the latest, adds `deltas` and `unrouted` (in order) and schedules one arrival.
    func put(_ deltas: [PageDelta], unrouted: [String], window: SpanVirtualPage) {
        latestWindow = window
        guard !deltas.isEmpty || !unrouted.isEmpty else { return }
        self.deltas += deltas
        self.unrouted += unrouted
        guard !arrivalScheduled else { return }
        arrivalScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.arrivalScheduled = false
            if !self.isEmpty { self.onArrival?() }
        }
    }

    /// Everything that arrived, oldest first; the box is empty afterwards.
    func take() -> (deltas: [PageDelta], unrouted: [String]) {
        let out = (deltas: deltas, unrouted: unrouted)
        deltas = []
        unrouted = []
        return out
    }
}

// MARK: - Environment

/// Where the prototype keeps its pages, apart from the person's handwriting and iCloud (§4.6 (b), D13):
/// a folder of its own under the temporary directory, an `InkPageStore` and a `SyncStateStore` there
/// (named with their folder and file, never the defaults, which are the app's `ink` folder and its
/// `state.json`, SyncStateStore.swift:10), an `InMemoryCloudDatabase` and a `SyncEngine` over them that is
/// never started.
@MainActor
struct SpanPrototypeEnvironment {
    let folder: URL
    let store: InkPageStore
    let stateStore: SyncStateStore
    let database: InMemoryCloudDatabase
    let sync: SyncEngine

    /// A new folder "span-prototype-<uuid>" under `base` (the temporary directory) and everything over it.
    static func makeIsolated(base: URL = FileManager.default.temporaryDirectory) -> SpanPrototypeEnvironment {
        let folder = base.appendingPathComponent("span-prototype-" + UUID().uuidString.lowercased(), isDirectory: true)
        let store = InkPageStore(directory: folder)
        let stateStore = SyncStateStore(fileURL: folder.appendingPathComponent("state.json", isDirectory: false))
        let database = InMemoryCloudDatabase()
        let sync = SyncEngine(store: store, stateStore: stateStore, database: database)
        return SpanPrototypeEnvironment(folder: folder, store: store, stateStore: stateStore, database: database, sync: sync)
    }

    /// Removes the folder with what the prototype wrote (it keeps nothing once it is closed).
    func discard() {
        try? FileManager.default.removeItem(at: folder)
    }
}

// MARK: - Window state

/// What the canvas takes when the session composed its window again (a shift, §3.6): the ledger's window,
/// its layout and papers, and the version that names them.
struct SpanPrototypeWindowState {
    let window: SpanVirtualPage
    let layout: SpanLayout
    let papers: [PaperContent]
    let windowVersion: Int
}

// MARK: - Session

/// One window of joined week pages in the prototype (the part of `SpanSession`, §3.5, that the prototype
/// needs): the window's real pages (`Slot`, by real id), composed into the ledger's virtual page
/// (`window`) and laid out side by side (`layout`, `papers`). The canvas's deltas are applied to the real
/// pages (never a page written back whole, §3.4); 1.5 s after the last one (D8, one timer per session),
/// and in `saveAll()`, the safety net takes each page's range back out of the canvas's window and merges
/// it in, then every dirty page goes to the prototype's engine as "proto-<id>" through
/// `SpanGuard.checkForSave(…, mode: .prototype)`. `rebuildWindow` composes the window again (another
/// focus, another device class or orientation); a page that leaves it is saved first, and when that
/// fails the window stays as it is (§3.6).
@MainActor
final class SpanPrototypeSession: ObservableObject {
    /// The real page of one page of the window and what the session knows of it.
    struct Slot: Equatable {
        /// The page with its real id ("w-…"); on file as "proto-<id>".
        var page: InkPage
        /// Changed since it was last saved.
        var dirty = false
        /// The ids of the strokes this session added to it (the deltas' `added`; `SpanGuard`'s `added`).
        var added: Set<String> = []
        /// A delta added strokes to it since it was last saved (saved first, D8).
        var addedSinceSave = false
    }

    /// The save timer (D8: the app's 1.5 s, CalendarRootScreen.swift:2520-2527).
    static let saveDelay: TimeInterval = 1.5

    /// A fault of the window's bookkeeping (a delta for a page not in the window or of an older number,
    /// a name that tells no page, a recovery by the safety net, a page id the merge changed): recorded,
    /// and Debug stops on it (§3.4 (c), (d)); the tests replace it to see the fault.
    static var onFault: (String) -> Void = { message in assertionFailure(message) }

    let sync: SyncEngine
    let inbox = SpanPrototypeInbox()
    let weekStart: WeekStart
    /// The number in the virtual page id ("span~week~<number>"): one per session.
    let number: Int
    let now: Date
    let holidays: HolidayCalendar
    let events: [LayoutEvent]

    private(set) var plan: SpanPlan
    /// The page number of the window's middle page (the focus).
    private(set) var focusIndex: Int
    /// The window's real page ids, left to right.
    private(set) var pageIds: [String] = []
    private(set) var slots: [String: Slot] = [:]
    /// The session's number (D7). The prototype never advances it (no 「全て消す」 there).
    private(set) var epoch = 0
    /// The session's aliases of long ids, kept across every window it composes.
    private var aliases = SpanAliases.empty
    /// The pages on each side of the focus when not the plan's (`SpanPlan.radius`): 「上限あり」 on an iPhone in
    /// landscape (P-B6 イ, B_DESIGN.md §6.2: 3 weeks visible → 7 pages). nil: the plan's.
    private(set) var radiusOverride: Int?
    /// Each window page's week as 1.2.3 lays it out (no memo): what 「1 ページずつ」 shows (the old versions'
    /// view of the same pages, §4.5).
    private(set) var plainLayouts: [String: WeekPageLayout] = [:]
    /// The height every week memo of the window has (`SpanAlign`, D16): at least 6,000 lu.
    private(set) var memoFloor: CGFloat = 0

    /// The ledger's page of the window and its layout; `windowVersion` moves each time they are composed.
    @Published private(set) var window: SpanVirtualPage
    @Published private(set) var layout: SpanLayout
    @Published private(set) var papers: [PaperContent] = []
    @Published private(set) var windowVersion = 0

    /// What the session recorded (repairs, refusals, failed saves, faults), newest last, at most 200.
    private(set) var records: [String] = []
    /// Pages written to the prototype's engine.
    private(set) var savedCount = 0
    /// Faults (see `onFault`).
    private(set) var faultCount = 0
    /// `saveAll` has run after `close()`: nothing more is applied or saved.
    private(set) var isClosed = false

    private let sleep: @MainActor (TimeInterval) async -> Void
    private var saveGeneration = 0
    /// Where the page reads and the window's stroke count go (§4.6 測ること); nil in the tests.
    private weak var meter: SpanPrototypeMeter?
    /// 「線の数」 is filling the pages (`fill`): nothing else may write them meanwhile.
    private(set) var isFilling = false

    /// Opens the window around `focus` for `deviceClass` and `orientation`: reads each page's
    /// "proto-<id>" file through `sync` (an empty page when there is none), `BandMigration` per page
    /// (a page it changed is saved, as the app's `show` does), and composes the window.
    init(sync: SyncEngine, weekStart: WeekStart, focus: DayKey, deviceClass: SpanDeviceClass, orientation: SpanOrientation,
         now: Date, holidays: HolidayCalendar, events: [LayoutEvent], number: Int = 1, radius: Int? = nil,
         meter: SpanPrototypeMeter? = nil,
         sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }) {
        self.sync = sync
        self.meter = meter
        radiusOverride = radius
        self.weekStart = weekStart
        self.number = number
        self.now = now
        self.holidays = holidays
        self.events = events
        self.sleep = sleep
        let plan = SpanPlan(kind: .week, weekStart: weekStart, deviceClass: deviceClass, orientation: orientation)
        self.plan = plan
        focusIndex = plan.index(containing: focus)
        // Placeholders until `compose()` below (it sets both before anyone can read them).
        window = SpanComposer.compose([], plan: plan, session: number)
        layout = SpanLayout(pages: [], plan: plan, firstIndex: focusIndex, session: number)
        pageIds = Self.window(around: focusIndex, plan: plan, radius: radius).map(plan.pageId(at:))
        for id in pageIds {
            slots[id] = loadSlot(id)
        }
        compose()
        inbox.onArrival = { [weak self] in self?.drainInbox() }
    }

    /// The page id on file for a real page id: "proto-<id>".
    static func fileId(_ pageId: String) -> String {
        SpanGuard.prototypePrefix + pageId
    }

    /// The pages on each side of the focus: the override, else the plan's.
    var windowRadius: Int {
        radiusOverride ?? plan.radius
    }

    /// The page numbers of a window around `focus`: focus − r … focus + r (r the override, else the plan's).
    static func window(around focus: Int, plan: SpanPlan, radius: Int?) -> ClosedRange<Int> {
        let r = max(1, radius ?? plan.radius)
        return (focus - r)...(focus + r)
    }

    /// The slot of the focus page in the window (0 = the window's first page).
    var focusSlot: Int {
        focusIndex - layout.firstIndex
    }

    /// The focus page's first day.
    var focusDay: DayKey {
        plan.firstDay(at: focusIndex)
    }

    // MARK: Reading and composing

    /// The real page `pageId` from its "proto-<id>" file (`sync.load`: the engine's store, never started),
    /// with its real id, migrated (dirty when that changed it). The read is timed for the meter (D6: one page
    /// on the main thread, its target 16 ms).
    private func loadSlot(_ pageId: String) -> Slot {
        let started = CACurrentMediaTime()
        var page = sync.load(Self.fileId(pageId))
        page.pageId = pageId
        let migrated = BandMigration.migrate(page)
        meter?.recordLoad(seconds: CACurrentMediaTime() - started, strokes: migrated.liveStrokeCount)
        return Slot(page: migrated, dirty: migrated != page)
    }

    /// The live strokes of the window's pages.
    var windowStrokeCount: Int {
        pageIds.reduce(0) { $0 + (slots[$1]?.page.liveStrokeCount ?? 0) }
    }

    /// The window from the slots (`SpanComposer.compose` with the session's aliases) and its layout and
    /// papers (`layoutPages`); a new `windowVersion`.
    private func compose(change: SpanAlign.Change = .redecide) {
        let pages = pageIds.compactMap { slots[$0]?.page }
        let composed = SpanComposer.compose(pages, plan: plan, session: number, aliases: aliases)
        aliases = composed.aliases
        window = composed
        layoutPages(change: change)
        windowVersion += 1
        meter?.recordWindowStrokes(windowStrokeCount)
        for id in composed.skippedPageIds {
            fault("compose: \(id) left out of the window")
        }
    }

    /// Each window page's week (`WeekLayoutEngine`, as 1.2.3 lays it out: `plainLayouts`) with the week memo
    /// below 24:00 (`SpanPrototypeWeekMemoLayout`, §5.2), the memos lined up to the window's floor (`SpanAlign`,
    /// D16: the tallest memo's natural height; a shift never lowers it, erasing may), side by side
    /// (`layout`); the paper draws the plain weeks (`papers`).
    private func layoutPages(change: SpanAlign.Change) {
        let firstIndex = Self.window(around: focusIndex, plan: plan, radius: radiusOverride).lowerBound
        let words = LayoutWords.of(L.language)
        let bottoms = pageIds.map { slots[$0]?.page.inkBottoms() ?? [:] }
        memoFloor = SpanAlign.floor(previous: memoFloor, naturals: bottoms.map { SpanAlign.natural(inkBottom: $0[.extra] ?? 0) },
                                    change: change)
        var layouts: [any PageLayout] = []
        var contents: [PaperContent] = []
        var plain: [String: WeekPageLayout] = [:]
        for (offset, id) in pageIds.enumerated() {
            let week = WeekLayoutEngine.layout(WeekLayoutInput(focus: plan.firstDay(at: firstIndex + offset), events: events,
                                                               inkBottoms: bottoms[offset], now: now, holidays: holidays,
                                                               words: words, weekStart: weekStart))
            plain[id] = week
            layouts.append(SpanPrototypeWeekMemoLayout(week: week, memoHeight: memoFloor))
            contents.append(.week(WeekPaperContent(layout: week)))
        }
        plainLayouts = plain
        layout = SpanLayout(pages: layouts, plan: plan, firstIndex: firstIndex, session: number)
        papers = contents
    }

    /// The canvas said handwriting may have crossed the bottom of its cell (`onInkBoundsChanged`): the inbox is
    /// emptied and the pages laid out again — the memo grows with a line past 5,950 lu, or shrinks back when
    /// it is erased (§5.2, D16) — with the same virtual page (the canvas takes the layout alone).
    func relayoutPages() {
        guard !isClosed, !isFilling else { return }
        drainInbox()
        let tallest = pageIds.map { SpanAlign.natural(inkBottom: slots[$0]?.page.inkBottoms()[.extra] ?? 0) }.max() ?? 0
        layoutPages(change: tallest < memoFloor ? .inkShrank : .inkGrew)
    }

    // MARK: Deltas (§3.4)

    /// Applies what the inbox holds: each delta to its real page (`SpanComposer.apply`, the app's
    /// `InkPage.add` / `remove`), the page dirty and its added ids kept; a delta of another number or of a
    /// page not in the window, and a name that tells no page, are a fault (not applied). A change starts
    /// the save timer.
    func drainInbox() {
        guard !isClosed else { return }
        let taken = inbox.take()
        if !taken.unrouted.isEmpty {
            fault("unrouted names: \(taken.unrouted.joined(separator: ", "))")
        }
        var changed = false
        for delta in taken.deltas {
            guard delta.epoch == epoch else {
                fault("delta of number \(delta.epoch) in session number \(epoch): \(delta.pageId)")
                continue
            }
            guard var slot = slots[delta.pageId] else {
                fault("delta for \(delta.pageId), not in the window")
                continue
            }
            slot.page = SpanComposer.apply(delta, to: slot.page)
            slot.dirty = true
            slot.added.formUnion(delta.added.map(\.id))
            if !delta.added.isEmpty { slot.addedSinceSave = true }
            slots[delta.pageId] = slot
            changed = true
        }
        if changed { scheduleSave() }
    }

    /// One save timer per session (D8): `saveAll()` `saveDelay` after the last change.
    private func scheduleSave() {
        saveGeneration += 1
        let generation = saveGeneration
        Task { @MainActor [weak self] in
            guard let sleep = self?.sleep else { return }
            await sleep(Self.saveDelay)
            guard let self, generation == self.saveGeneration, !self.isClosed else { return }
            _ = self.saveAll()
        }
    }

    /// §3.4 (c): each page's range of the canvas's latest window, merged into its slot. A page id that
    /// the merge would change is a fault (the real id never turns into the virtual one); a merge that
    /// brings anything is a recovery (a delta went missing): the slot takes it and is dirty.
    private func safetyNet() {
        guard let latest = inbox.latestWindow else { return }
        for id in pageIds {
            guard var slot = slots[id] else { continue }
            let range = SpanComposer.extract(pageId: id, from: latest)
            guard range.pageId == id else { continue } // a window without this page: nothing to take
            let merged = InkPage.merge(slot.page, range)
            guard merged.pageId == id else {
                fault("safety net: \(id) would become \(merged.pageId)")
                continue
            }
            guard merged.contentDiffers(from: slot.page) else { continue }
            slot.page = merged
            slot.dirty = true
            slots[id] = slot
            fault("safety net recovered \(id)")
        }
    }

    // MARK: Saving

    /// Empties the inbox, runs the safety net, then saves every dirty page — the pages that got strokes
    /// first (D8), then the window's order. Returns the page ids that could not be saved (they stay dirty).
    @discardableResult
    func saveAll() -> [String] {
        guard !isClosed else { return [] }
        saveGeneration += 1 // a waiting timer has nothing left to do
        drainInbox()
        safetyNet()
        let dirty = pageIds.filter { slots[$0]?.dirty == true }
        let order = dirty.filter { slots[$0]?.addedSinceSave == true } + dirty.filter { slots[$0]?.addedSinceSave != true }
        return order.filter { !persist($0) }
    }

    /// Writes one page as "proto-<id>" after `SpanGuard.checkForSave(…, mode: .prototype)`: `.ok` as it is,
    /// `.repaired` the repaired page (recorded; the slot takes it), `.refused` nothing (recorded; never
    /// written). A failure of the engine's save is recorded too. True when the page is on file.
    private func persist(_ pageId: String) -> Bool {
        guard var slot = slots[pageId] else { return false }
        var out = slot.page
        out.pageId = Self.fileId(pageId)
        switch SpanGuard.checkForSave(out, added: slot.added, mode: .prototype) {
        case .ok:
            break
        case .repaired(let page, let stripped, let dropped):
            record("repaired \(out.pageId): stripped \(stripped.count) \(stripped.joined(separator: ",")), dropped \(dropped.count) \(dropped.joined(separator: ","))")
            out = page
        case .refused:
            record("refused \(out.pageId)")
            return false
        }
        do {
            try sync.save(out)
        } catch {
            record("save failed \(out.pageId): \(error)")
            return false
        }
        var kept = out
        kept.pageId = pageId
        slot.page = kept
        slot.dirty = false
        slot.addedSinceSave = false
        slots[pageId] = slot
        savedCount += 1
        return true
    }

    /// Saves everything (`saveAll`) and closes: nothing is applied or saved after it. Returns the page
    /// ids that could not be saved.
    @discardableResult
    func close() -> [String] {
        let failed = saveAll()
        isClosed = true
        inbox.onArrival = nil
        return failed
    }

    // MARK: Composing again (§3.6)

    /// The window around `focus` (nil: the same) for `plan` (nil: the same; the device class or the
    /// orientation changed). The inbox is emptied and the safety net run first; every page that leaves
    /// the window is saved, and when one cannot be, nothing changes (false). Then the pages that come in
    /// are read and the window composed again with the session's aliases (a new `windowVersion`; the
    /// virtual id stays).
    @discardableResult
    func rebuildWindow(focus: DayKey? = nil, plan newPlan: SpanPlan? = nil) -> Bool {
        rebuildWindow(focusIndex: focus.map((newPlan ?? plan).index(containing:)), plan: newPlan)
    }

    /// `rebuildWindow(focus:plan:)` with the focus given as a page number (`SpanPlan.index`; nil: the same) and,
    /// when `radius` is given (`.some`), a new radius override (`.some(nil)`: the plan's again).
    @discardableResult
    func rebuildWindow(focusIndex newFocus: Int?, plan newPlan: SpanPlan? = nil, radius newRadius: Int?? = nil) -> Bool {
        guard !isClosed else { return false }
        let nextPlan = newPlan ?? plan
        guard nextPlan.kind == plan.kind, nextPlan.weekStart == plan.weekStart else {
            fault("rebuild: another kind or week start (K-11: a new session)")
            return false
        }
        drainInbox()
        safetyNet()
        let nextFocus = newFocus ?? focusIndex
        let nextRadius = newRadius ?? radiusOverride
        let nextIds = Self.window(around: nextFocus, plan: nextPlan, radius: nextRadius).map(nextPlan.pageId(at:))
        let leaving = pageIds.filter { !nextIds.contains($0) }
        for id in leaving where slots[id]?.dirty == true {
            guard persist(id) else {
                record("rebuild stopped: \(Self.fileId(id)) could not be saved")
                return false
            }
        }
        for id in leaving {
            slots[id] = nil
        }
        for id in nextIds where slots[id] == nil {
            slots[id] = loadSlot(id)
        }
        // A window that only moved keeps its memo's floor (§3.2, D16); anything else decides it again.
        let moved = nextPlan == plan && nextRadius == radiusOverride
        plan = nextPlan
        radiusOverride = nextRadius
        focusIndex = nextFocus
        pageIds = nextIds
        compose(change: moved ? .shift : .redecide)
        return true
    }

    /// The window as the canvas takes it (the values a new `windowVersion` brings).
    var windowState: SpanPrototypeWindowState {
        SpanPrototypeWindowState(window: window, layout: layout, papers: papers, windowVersion: windowVersion)
    }

    /// §3.6 ずらし, the session's part: the window composed again around page `index` (`rebuildWindow`: the inbox
    /// emptied, the safety net, the pages that leave saved first, the pages that come in read). nil when a page
    /// that leaves could not be saved: nothing changed, and the canvas does not shift.
    func shift(toFocusIndex index: Int) -> SpanPrototypeWindowState? {
        guard rebuildWindow(focusIndex: index) else { return nil }
        return windowState
    }

    // MARK: 「線の数」 (§4.6 測ること)

    /// How far 「線の数」 has got: pages written and pages to write.
    struct FillProgress: Equatable {
        var done: Int
        var total: Int
    }

    /// Fills the window's pages, and one window radius of pages beyond each side (so a fling or two still
    /// finds full pages), with `windowTotal` ÷ the window's pages synthetic strokes each
    /// (`SpanPrototypeSynthetic`; 0 takes them all out): what was written in the prototype is saved first and
    /// stays (a page that could not be saved is left as it is). Each page is written as "proto-<id>" through
    /// the prototype's guard, straight to the prototype's store (the engine's save would merge the old
    /// synthetic strokes back in), the window's pages first, one per turn (`progress` after each). Then the
    /// window's pages are read again from their files (the reads the meter times) and the window composed
    /// again. The caller takes the canvas away first (its last deltas then reach `saveAll` here). false when
    /// the session is closed or already filling.
    @discardableResult
    func fill(windowTotal: Int, progress: @escaping @MainActor (FillProgress) -> Void = { _ in }) async -> Bool {
        guard !isClosed, !isFilling else { return false }
        isFilling = true
        defer { isFilling = false }
        let unsaved = Set(saveAll())
        let radius = windowRadius
        let perPage = windowTotal > 0 ? (windowTotal + pageIds.count - 1) / max(1, pageIds.count) : 0
        let reach = (focusIndex - 2 * radius)...(focusIndex + 2 * radius)
        let order = reach.sorted { abs($0 - focusIndex) < abs($1 - focusIndex) || (abs($0 - focusIndex) == abs($1 - focusIndex) && $0 < $1) }
        progress(FillProgress(done: 0, total: order.count))
        for (done, index) in order.enumerated() {
            guard !isClosed else { return false }
            let id = plan.pageId(at: index)
            guard !unsaved.contains(id) else {
                record("fill skipped \(Self.fileId(id)): not saved")
                continue
            }
            let synthetic = SpanPrototypeSynthetic.strokes(pageId: id, count: perPage, tag: windowTotal)
            var page = SpanPrototypeSynthetic.replacing(sync.load(Self.fileId(id)), with: synthetic)
            page.pageId = Self.fileId(id)
            switch SpanGuard.checkForSave(page, added: Set(synthetic.map(\.id)), mode: .prototype) {
            case .ok:
                break
            case .repaired(let repaired, let stripped, let dropped):
                record("fill repaired \(page.pageId): stripped \(stripped.count), dropped \(dropped.count)")
                page = repaired
            case .refused:
                record("fill refused \(page.pageId)")
                continue
            }
            do {
                try sync.store.save(page)
            } catch {
                record("fill failed \(page.pageId): \(error)")
            }
            progress(FillProgress(done: done + 1, total: order.count))
            // A moment for the screen to show the progress.
            await sleep(0.01)
        }
        guard !isClosed else { return false }
        for id in pageIds where !unsaved.contains(id) {
            slots[id] = loadSlot(id)
        }
        compose()
        return true
    }

    // MARK: Records

    private func record(_ message: String) {
        records.append(message)
        if records.count > 200 {
            records.removeFirst(records.count - 200)
        }
        #if DEBUG
        NSLog("span prototype: %@", message)
        #endif
    }

    private func fault(_ message: String) {
        faultCount += 1
        record("fault: " + message)
        Self.onFault(message)
    }
}
#endif
