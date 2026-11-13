import Combine
import Foundation
import Holidays
import InkModel
import Layout

// The session of the joined week and day pages (1.3, docs/M7C_CONTRACT.md §2.1, §3.4, §3.5, §3.7, §3.10,
// §3.15, D6, D7, D8, D14, D18, D20, D21; B_DESIGN.md §2.4): the window's real pages (`PageSlot`), the inbox
// the canvas hands its deltas to (`SpanInbox`), the safety net, the one save timer, the save order, the
// guard before every save, the updates and deletions from iCloud (held back while a procedure runs), the
// focus and its title, ◀ ▶ and 「今日」, the events of each page and the decision to fall back to one page.
//
// No UIKit, no SwiftUI: the session is driven by the screen and the canvas (role L) and tested on its own
// over a live `SyncEngine` (SpanSessionTests, ScreenEraseTests). The canvas takes `window` (the virtual page
// its ledger edits, through `@_spi(SpanLedger) import InkModel`), `layout` and `windowVersion`, makes every id
// with `ownerId(for:)`, puts its journal into `inbox` in the turn it changed (§3.4 (a)) and takes
// `takeHistoryPrune()` when a page leaves or empties. The screen calls `saveAll()` at every boundary (the
// background, a reopening, the export, an import, the account's 「残す」), `cancelAll()` for 「全て消す」 and
// `closeWithoutSaving()` for 「消して始める」, and routes `SyncEngine.onRemoteUpdate` / `onRemoteDelete` here.

// MARK: - PageSlot

/// One real page a session holds (§3.5, D3 の 7): what 1.2.3's screen kept for its one page — `page`,
/// `pageDirty`, `capNoticedPageId` (CalendarRootScreen.swift:154, :188, :273 of 43fe366) — once for each page of
/// a window (`SpanSession`) or for the one page (`OnePageSession`), with what the joined path adds: the ids
/// this session added (`SpanGuard`'s `added`, K-10), the marks of the save order (D8) and whether the page
/// was read yet (D6). The paper is not here: it is drawn from the page and the events by the screen
/// (`PaperContent` belongs to the view layer), and the joined path's layouts are `SpanSession.layout`.
struct PageSlot: Equatable {
    /// The page with its real id.
    var page: InkPage
    /// Changed since it was last saved (1.2.3's `pageDirty`).
    var dirty = false
    /// The page whose 「メモ欄はここまでです」 was shown while it is open (1.2.3's `capNoticedPageId`; D21: per page).
    var capNoticedPageId: String?
    /// The ids of the strokes this session's deltas added (`SpanGuard.checkForSave`'s `added`): the only items
    /// whose names may not hold a "|" at all (§6.1). Empty on the one-page path, whose canvas writes whole pages.
    var added: Set<String> = []
    /// A delta added strokes since the last save: such pages are saved first (D8).
    var addedSinceSave = false
    /// The undo groups (§4.4) whose strokes this page received / lost since its last save: a group's source
    /// page is not saved while the save of its destination failed (D8).
    var destinationGroups: Set<UUID> = []
    var sourceGroups: Set<UUID> = []
    /// Not read from the store yet: a placeholder of the window (D6), whose file is merged in when it is read.
    var unread = false

    init(page: InkPage, dirty: Bool = false, unread: Bool = false) {
        self.page = page
        self.dirty = dirty
        self.unread = unread
    }

    /// What `persist` did with one page.
    enum Persisted: Equatable {
        /// Written as it was.
        case saved
        /// Written after the guard repaired the items named (their original keys, §6.1).
        case repaired(stripped: [String], dropped: [String])
        /// Not written: the page id is not of the form this version writes (the only refusal, §6.1).
        case refused
        /// The engine's save threw (the store could not write the file); the text is the error's.
        case failed(String)

        /// The file holds the page now.
        var wrote: Bool {
            switch self {
            case .saved, .repaired: return true
            case .refused, .failed: return false
            }
        }
    }

    /// The one save of the screen, on both paths (D14, §6.1): `SpanGuard.checkForSave` (in Release too) with
    /// `added`, then `write` (the engine's `save`) with the page it allows. A repaired page is handed to
    /// `willWrite` *before* it is written, so the owner's slot holds it when the engine, inside its `save`,
    /// reports a merge with the file through `onRemoteUpdate` (SyncEngine.swift:168-175): that report then
    /// lands on the repaired page. On the one-page path the guard finds nothing to repair in any page 1.2.3 or
    /// earlier wrote (no window names exist there), so it writes exactly what 1.2.3 wrote (D3 (2)).
    @MainActor
    static func persist(_ page: InkPage, added: Set<String>, mode: SpanGuard.Mode,
                        willWrite: (InkPage) -> Void, write: (InkPage) throws -> Void) -> Persisted {
        var out = page
        var result = Persisted.saved
        switch SpanGuard.checkForSave(page, added: added, mode: mode) {
        case .ok:
            break
        case .repaired(let repaired, let stripped, let dropped):
            out = repaired
            result = .repaired(stripped: stripped, dropped: dropped)
            willWrite(repaired)
        case .refused:
            return .refused
        }
        do {
            try write(out)
        } catch {
            return .failed(error.localizedDescription)
        }
        return result
    }
}

// MARK: - SpanInbox

/// The box the canvas hands its deltas to (§3.4 (a), (d)): in the turn its ledger changed, the canvas puts
/// the journal's deltas and the names among them that reach no page (`SpanComposer.unroutedNames`), with the
/// window its ledger holds now (the safety net's source, §3.4 (c)) and the version of the session's window it
/// was loaded from (`basis`). A reference type, not SwiftUI state, so the canvas may put into it inside
/// `updateUIView`. What arrives is delivered once, on the next main-actor turn (`onArrival`, the session's
/// `drainInbox`), unless the session takes it first (every procedure starts by emptying it).
@MainActor
final class SpanInbox {
    private(set) var deltas: [PageDelta] = []
    private(set) var unrouted: [String] = []
    /// The canvas's window with its ledger's page as of the last `put`; nil before the first one.
    private(set) var latestWindow: SpanVirtualPage?
    /// The session's `windowVersion` the canvas's ledger was last loaded from (with `latestWindow`).
    private(set) var latestBasis = 0
    /// Called on the next turn after deltas or unrouted names arrive (once for all that arrive meanwhile).
    var onArrival: (() -> Void)?
    private var arrivalScheduled = false

    var isEmpty: Bool { deltas.isEmpty && unrouted.isEmpty }

    /// Keeps `window` (the canvas's ledger page in its window, `SpanVirtualPage.with(ledgerPage:)`) and `basis`
    /// as the latest, adds `deltas` and `unrouted` in order and schedules one arrival. A canvas that has just
    /// taken a new window puts it with no deltas, so the safety net reads from it.
    func put(_ deltas: [PageDelta], unrouted: [String], window: SpanVirtualPage, basis: Int) {
        latestWindow = window
        latestBasis = basis
        guard !deltas.isEmpty || !unrouted.isEmpty else { return }
        self.deltas += deltas
        self.unrouted += unrouted
        scheduleArrival()
    }

    /// `put` from the ledger's journal (what the canvas does after each change, §3.4 (d)): the deltas made
    /// with `SpanComposer.deltas` under `epoch` (the session's number when the canvas took its window, D7)
    /// and the window's alias table, and the names `SpanComposer.unroutedNames` finds in the same journal.
    func put(journal: [SpanJournalEntry], window: SpanVirtualPage, basis: Int, epoch: Int) {
        let made = SpanComposer.deltas(from: journal, epoch: epoch, aliases: window.aliases)
        let unrouted = SpanComposer.unroutedNames(in: journal, aliases: window.aliases)
        put(made, unrouted: unrouted, window: window, basis: basis)
    }

    /// Everything that arrived, oldest first; the box is empty afterwards.
    func take() -> (deltas: [PageDelta], unrouted: [String]) {
        let out = (deltas: deltas, unrouted: unrouted)
        deltas = []
        unrouted = []
        return out
    }

    /// Throws away what arrived and the canvas's window (`cancelAll`, `closeWithoutSaving`).
    func discard() {
        deltas = []
        unrouted = []
        latestWindow = nil
    }

    private func scheduleArrival() {
        guard !arrivalScheduled else { return }
        arrivalScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.arrivalScheduled = false
            if !self.isEmpty { self.onArrival?() }
        }
    }
}

// MARK: - SpanSession

/// One window of joined week or day pages (§3.5): its real pages by id (`PageSlot`), composed into the
/// virtual page of the canvas's ledger (`window`, `SpanComposer.compose` with the session's alias table)
/// and laid out side by side (`layout`, `SpanLayout`). A session is one kind and one week start (K-11) and
/// lives until the screen opens anew (another kind, a date tap, a far 「今日」, the setting, the week start,
/// 「全て消す」, 「消して始める」, an import, §3.1); a shift of the window keeps it (and its virtual id).
@MainActor
final class SpanSession: ObservableObject {
    /// The paper's inputs of every page of the window (the screen's `makePaper` takes the same).
    struct PaperContext {
        var now: Date
        var holidays: HolidayCalendar
        var words: LayoutWords
        var calendar: Calendar

        init(now: Date, holidays: HolidayCalendar = .japan, words: LayoutWords = .japanese, calendar: Calendar = DayKey.deviceCalendar) {
            self.now = now
            self.holidays = holidays
            self.words = words
            self.calendar = calendar
        }
    }

    /// An update or a deletion from iCloud that arrived while a procedure ran (D6).
    enum Remote: Equatable {
        case update(InkPage)
        case delete(String)

        var pageId: String {
            switch self {
            case .update(let page): return page.pageId
            case .delete(let id): return id
            }
        }
    }

    /// What ◀ ▶ and 「今日」 do (§3.6): slide the paper by `pages` page widths (the canvas animates the offset by
    /// `plan.shiftAmount(pages:zoom:)`; the window shifts when it stops), or open a new session at `focus`.
    enum Move: Equatable {
        case slide(pages: Int)
        case reopen(focus: DayKey)
    }

    /// A visit of a focus page (D20, 1.2.1's rating prompt): the page and whether the person's own ink
    /// changed while it was the focus.
    struct Visit: Equatable {
        var pageId: String
        var inkChanged = false
        var lastInkChangeAt: Date?
    }

    /// What a stop of the paper means for the screen (§3.7, D20): the focus page's first day (the title and
    /// `remember()`), and the visit that ended when the focus changed (nil when it did not).
    struct Stop: Equatable {
        var focusDay: DayKey
        var ended: Visit?
    }

    // MARK: Fixed numbers (§3.16)

    /// The save timer: the app's 1.5 s (CalendarRootScreen.swift:2520-2527 of 43fe366, D8). One per session.
    static let saveDelay: TimeInterval = 1.5
    /// EventKit answers a range of up to four years in one predicate (EventKitService.swift:126): every query
    /// of a page's events is shorter than this many days (§3.8).
    static let eventQueryMaxDays = 4 * 365

    /// A fault of the window's bookkeeping (a delta of a page not in the window or older than its page's
    /// reset, a name that tells no page, a recovery by the safety net, a page id the merge would change, a
    /// repair by the guard, a page left out of a composition): recorded, and Debug stops on it (§3.4 (c),
    /// (d), §6.1). The tests replace it to see the fault.
    static var onFault: (String) -> Void = { message in assertionFailure(message) }

    // MARK: Identity

    /// The canvas's identity (`.id(...)`, §3.1): the kind, the week start and the number of this opening.
    /// A shift never changes it.
    let id: String
    let kind: PageKind
    let weekStart: WeekStart
    /// The number of this opening (the screen counts them); also the number in the virtual page id.
    let number: Int
    let guardMode: SpanGuard.Mode
    let sync: SyncEngine
    let inbox = SpanInbox()
    /// The device the window is sized for (fixed: a class is the screen's short side, `SpanDeviceClass`).
    let deviceClass: SpanDeviceClass

    // MARK: The window

    /// The plan of the kind, the week start, the device and the orientation (`redecide` changes the orientation).
    private(set) var plan: SpanPlan
    /// The pages on each side of the focus the window was last built around (`windowRadius(...)`).
    private(set) var radius: Int
    /// The page number (`SpanPlan.index`) of the focus page. It follows the paper (`scrolled`) before the window
    /// shifts to it, so it may be off the window's middle (`needsShift`).
    @Published private(set) var focusIndex: Int
    /// The page number of the window's first page (`pageIds[0]`): set only when the window is built (the opening,
    /// a shift, a decision anew), never from the focus, so the layout is always of the window's own pages.
    private(set) var windowFirstIndex: Int
    /// The window's real page ids, left to right.
    private(set) var pageIds: [String] = []
    private(set) var slots: [String: PageSlot] = [:]
    /// The virtual page of the canvas's ledger (the virtual id "span~<kind>~<number>"; window names).
    @Published private(set) var window: SpanVirtualPage
    /// The window's pages side by side (`SpanLayout`, the same session number).
    @Published private(set) var layout: SpanLayout
    /// Moves every time `window` and `layout` are composed again (never one without the other); the canvas reloads
    /// its ledger from them (keeping its history) and puts the window into the inbox with this as its basis. Every
    /// composition empties the inbox first, so `window` holds every stroke the canvas handed over.
    @Published private(set) var windowVersion = 0
    /// The floors of the window's last cells (`SpanAlign`, D16).
    private(set) var floors = SpanAlign.Floors.none
    /// The events of each window page (§3.8), by page id.
    private(set) var events: [String: [LayoutEvent]] = [:]
    var context: PaperContext

    // MARK: State

    /// The session's number (D7): advanced by `cancelAll()` (「全て消す」) and by a record deletion of a window
    /// page (H1); never by an import or a shift. A delta made under an older number than its page's last reset
    /// is dropped.
    private(set) var epoch = 0
    /// The number at which every page was last reset (`cancelAll`), and each page's own (H1).
    private var resetAll = 0
    private var resetOf: [String: Int] = [:]
    /// The safety net leaves a page alone until the canvas took a window composed after the page was emptied
    /// from outside (H1, §6.6: the canvas's older window still holds the strokes another device erased).
    private var safetyNetFrom: [String: Int] = [:]
    /// Pages whose ↶ steps the canvas drops at its next window (`takeHistoryPrune`, §3.6, H1).
    private var historyPrune: Set<String> = []
    /// `closeWithoutSaving()` ran: nothing is applied or saved any more.
    private(set) var isClosed = false
    /// A procedure (`saveAll`, a shift, the reads) is running: updates and deletions from outside wait (D6).
    private(set) var procedureDepth = 0
    private(set) var pendingRemote: [Remote] = []
    /// The aliases of long ids, kept across every window of the session.
    private var aliases = SpanAliases.empty
    /// The visit of the focus page (D20).
    private(set) var visit: Visit
    /// What the session recorded (repairs, refusals, failed saves, dropped deltas, faults), newest last.
    private(set) var records: [String] = []
    private(set) var faultCount = 0
    /// The live strokes of the window, estimated from the file sizes for pages not read yet (D18, §3.15).
    private(set) var windowStrokeCount = 0
    /// Stage 2 (§3.15, D18): the window holds more strokes than the device's cap. The screen then shows this
    /// kind one page at a time (1.2.3's path) and says so once (§8.1 N-8); the session keeps nothing open.
    @Published private(set) var fallsBackToOnePage = false

    // MARK: Hooks

    /// The id of every stroke the ledger makes is "<owner page>|" + this (§3.3 1). Seeded in the tests.
    var makeId: () -> String = { InkStroke.newId() }
    /// A page's events for the days [start, end) (`EventKitService.events`); nil: none are read.
    var eventSource: ((DayKey, DayKey) -> [LayoutEvent])?
    /// The pages `saveAll` could not save (one notice for all of them: 1.2.3's 「手書きを保存できませんでした」).
    var onSaveFailed: (([String]) -> Void)?
    /// The person's own ink changed (a delta was applied): the screen's `lastInkChangeAt` and
    /// `noteReviewInk` (D20; 1.2.2's age range reads the time).
    var onOwnInk: ((Date) -> Void)?
    /// Just before a page goes to the engine (the save order is read from it in the tests).
    var willPersist: ((String) -> Void)?
    /// After each page the reads of `prefetch()` take (the tests deliver an update from outside there).
    var onPrefetchStep: ((String) -> Void)?

    private let sleep: @MainActor (TimeInterval) async -> Void
    private let clock: () -> Date
    private var saveGeneration = 0

    /// Opens the window around `focus` (§3.5, D6): the focus page is read now (`sync.load`, `BandMigration`; a
    /// page the migration changed is dirty and saved by the timer, as 1.2.3's `show` does), the other pages
    /// of the window are placeholders until `prefetch()` reads them (nearest first, one per turn). The window
    /// is composed at once.
    /// - `radius`: the pages on each side; nil is `windowRadius(plan:paperArea:)` of `paperArea`. A radius wider
    ///   than the plan's whose window is estimated over the device's cap before anything else is read (the focus
    ///   page by its strokes, the others by their file sizes, §3.15) is the plan's from the start (S1's lead's
    ///   decision 1), so `fallsBackToOnePage` is decided on the plan's window and the far pages are not read.
    /// - `eventSource`: a page's events for its days (the focus page's are read here, the others with their page).
    init(kind: PageKind, weekStart: WeekStart, focus: DayKey, sync: SyncEngine, guardMode: SpanGuard.Mode = .release,
         deviceClass: SpanDeviceClass = .iPad11, orientation: SpanOrientation = .portrait, number: Int = 1,
         context: PaperContext? = nil, paperArea: CGSize? = nil, radius: Int? = nil,
         eventSource: ((DayKey, DayKey) -> [LayoutEvent])? = nil,
         sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
         clock: @escaping () -> Date = Date.init) {
        let plan = SpanPlan(kind: kind, weekStart: weekStart, deviceClass: deviceClass, orientation: orientation)
        self.kind = kind
        self.weekStart = weekStart
        self.number = number
        self.guardMode = guardMode
        self.sync = sync
        self.deviceClass = deviceClass
        self.sleep = sleep
        self.clock = clock
        self.context = context ?? PaperContext(now: clock())
        self.eventSource = eventSource
        self.plan = plan
        id = "span|\(kind.rawValue)|\(weekStart.rawValue)|\(number)"
        let focusIndex = plan.index(containing: focus)
        self.focusIndex = focusIndex
        let wide = max(1, radius ?? Self.windowRadius(plan: plan, paperArea: paperArea))
        self.radius = wide
        windowFirstIndex = focusIndex - wide
        window = SpanComposer.compose([], plan: plan, session: number)
        layout = SpanLayout(pages: [], plan: plan, firstIndex: focusIndex, session: number)
        visit = Visit(pageId: plan.pageId(at: focusIndex))
        let focusId = plan.pageId(at: focusIndex)
        slots[focusId] = readSlot(focusId)
        self.radius = fittingRadius(wide, plan: plan, focus: focusIndex)
        windowFirstIndex = focusIndex - self.radius
        pageIds = Self.window(around: focusIndex, radius: self.radius).map(plan.pageId(at:))
        for id in pageIds where id != focusId {
            slots[id] = PageSlot(page: InkPage(pageId: id), unread: true)
        }
        if slots[focusId]?.dirty == true { scheduleSave() }
        countStrokes()
        compose(change: .redecide)
        inbox.onArrival = { [weak self] in self?.drainInbox() }
    }

    /// The pages on each side of the focus (§3.6, the lead's decision 1 of S1): the plan's R, or more when the
    /// paper area measured on this screen shows more pages at the lower zoom limit (an all-day band with many
    /// lanes on an iPhone in landscape). A wider window that holds more strokes than the device's cap is the
    /// plan's R instead: before its pages are read when the estimate says so (`fittingRadius`), else once they
    /// are read (`prefetch`).
    static func windowRadius(plan: SpanPlan, paperArea: CGSize?) -> Int {
        guard let area = paperArea else { return plan.radius }
        let visible = SpanPlan.visiblePages(plan.kind, viewport: area)
        return max(plan.radius, SpanPlan.radius(forVisiblePages: visible))
    }

    /// `wide`, or the plan's R when `wide` is wider than it and the window of `wide` around `focus` is estimated
    /// over the device's cap (`estimatedStrokes(of:)`: the pages read by their strokes, the others by their file
    /// sizes, §3.15). The plan's own window is never narrowed: over the cap, that is stage 2.
    private func fittingRadius(_ wide: Int, plan: SpanPlan, focus: Int) -> Int {
        guard wide > plan.radius else { return wide }
        let ids = Self.window(around: focus, radius: wide).map(plan.pageId(at:))
        return estimatedStrokes(of: ids) > plan.strokeCap ? plan.radius : wide
    }

    /// The page numbers focus − r … focus + r.
    static func window(around focus: Int, radius: Int) -> ClosedRange<Int> {
        (focus - radius)...(focus + radius)
    }

    // MARK: What the canvas and the screen read

    /// The focus page's id and first day (the title, `PageNavigation.title(kind, focus:…)`).
    var focusPageId: String { plan.pageId(at: focusIndex) }
    var focusDay: DayKey { plan.firstDay(at: focusIndex) }
    /// The slot of the focus page in the window (0 = the window's first page; `layout.firstIndex` is
    /// `windowFirstIndex`).
    var focusSlot: Int { focusIndex - windowFirstIndex }

    /// The real page of a window page (the slot's), nil for a page not in the window.
    func page(_ pageId: String) -> InkPage? {
        slots[pageId]?.page
    }

    /// The x (lu) of a window page's left edge in the band; nil for a page not in the window.
    func origin(ofPage pageId: String) -> CGFloat? {
        layout.slot(ofPage: pageId).map(layout.origin(ofSlot:))
    }

    /// `InkLedger.ownerId` (§3.3 1): the owner page of a window cell in front of a fresh id
    /// ("<page>|<makeId()>", never longer than 128 bytes for a UUID). A cell that names no page gets a bare
    /// id, which `SpanComposer.unroutedNames` reports (§3.4 (d)).
    func ownerId(for cell: CellKey) -> String {
        let fresh = makeId()
        guard let page = SpanName.split(cell.raw)?.page else { return fresh }
        return SpanName.prefixed(id: fresh, page: page)
    }

    /// The pages whose ↶ steps the canvas drops (`InkLedger.pruneHistory(touching:)`): pages that left the
    /// window and pages another device erased (H1). Emptied by the call.
    func takeHistoryPrune() -> Set<String> {
        defer { historyPrune = [] }
        return historyPrune
    }

    /// What a PDF of `pageId` draws (D17, §3.11): the real page (`page:`; `SpanGuard.checkForTransfer` holds for
    /// it) and the strokes of the other window pages that reach into it (`neighborInk:`, real ids and cells,
    /// from the canvas's latest window, else the composed one). nil for a page not in the window. The inbox is
    /// emptied first, so the page has every delta.
    func pdfInput(for pageId: String) -> (page: InkPage, neighborInk: [SpanPDFInk])? {
        drainInbox()
        guard let page = slots[pageId]?.page else { return nil }
        let source = inbox.latestWindow ?? window
        return (page, SpanComposer.neighborInk(for: pageId, from: source, layout: layout))
    }

    /// 「メモ欄はここまでです」 for the page that owns the stroke (D21): true once while the page is in the window
    /// (the screen shows the toast), false afterwards.
    func noteGrowthCap(pageId: String) -> Bool {
        guard var slot = slots[pageId], slot.capNoticedPageId != pageId else { return false }
        slot.capNoticedPageId = pageId
        slots[pageId] = slot
        return true
    }

    // MARK: Reading (D6)

    /// The real page from the store (`sync.load`: the engine's branch for the screenshot mode and its inert
    /// engine stays), migrated (`BandMigration`, dirty when that changed it), with its events.
    private func readSlot(_ pageId: String) -> PageSlot {
        let loaded = sync.load(pageId)
        let migrated = BandMigration.migrate(loaded)
        loadEvents(of: pageId)
        return PageSlot(page: migrated, dirty: migrated != loaded)
    }

    /// Reads the window's placeholders (D6): nearest to the focus first (the left one first at the same
    /// distance), one page per turn (`Task.yield` between), each merged into what its placeholder took
    /// meanwhile; updates and deletions from outside wait until all are read. Then the inbox is emptied, the
    /// window composed once and `sync.pagesOpened` asked once for the window (§7).
    func prefetch() async {
        guard !isClosed else { return }
        let order = Self.nearestFirst(pageIds, focus: focusPageId).filter { slots[$0]?.unread == true }
        if !order.isEmpty {
            procedureDepth += 1
            for id in order {
                await Task.yield()
                guard !isClosed, slots[id]?.unread == true else { continue }
                readPlaceholder(id)
                onPrefetchStep?(id)
            }
            procedureDepth -= 1
            guard !isClosed else { return }
            countStrokes()
            compose(change: .redecide)
            applyPendingRemote()
            // The lead's decision 1 of S1: a window wider than the plan's that is over the cap goes back to it.
            if fallsBackToOnePage, radius > plan.radius {
                rebuild(around: focusIndex, plan: plan, radius: plan.radius, change: .redecide)
            }
        }
        sync.pagesOpened(pageIds)
    }

    /// A placeholder's file read now and merged with what the placeholder took meanwhile (deltas, updates).
    private func readPlaceholder(_ id: String) {
        guard var slot = slots[id], slot.unread else { return }
        let read = readSlot(id)
        let merged = InkPage.merge(read.page, slot.page)
        if merged.pageId != id {
            fault("read: \(id) would become \(merged.pageId)")
        } else {
            slot.page = merged
        }
        slot.unread = false
        slot.dirty = slot.dirty || read.dirty
        slots[id] = slot
        if read.dirty { scheduleSave() }
    }

    /// `ids` ordered by their distance from `focus` in the list (the left one first at the same distance).
    static func nearestFirst(_ ids: [String], focus: String) -> [String] {
        guard let center = ids.firstIndex(of: focus) else { return ids }
        return ids.enumerated()
            .sorted { a, b in
                let da = abs(a.offset - center), db = abs(b.offset - center)
                return da != db ? da < db : a.offset < b.offset
            }
            .map(\.element)
    }

    // MARK: Events (§3.8)

    /// The queries of the days [start, end): one when it is shorter than `eventQueryMaxDays`, else in pieces.
    static func eventQueries(start: DayKey, end: DayKey) -> [(start: DayKey, end: DayKey)] {
        var out: [(start: DayKey, end: DayKey)] = []
        var from = start
        while from < end {
            let to = min(end, from.adding(days: eventQueryMaxDays - 1))
            out.append((from, to))
            from = to
        }
        return out
    }

    /// The days of a window page.
    func days(of pageId: String) -> (start: DayKey, end: DayKey)? {
        guard let index = plan.index(of: pageId) else { return nil }
        return PageNavigation.dayRange(kind, focus: plan.firstDay(at: index), weekStart: weekStart)
    }

    private func loadEvents(of pageId: String) {
        guard let source = eventSource, let range = days(of: pageId) else { return }
        events[pageId] = Self.eventQueries(start: range.start, end: range.end).flatMap { source($0.start, $0.end) }
    }

    /// Reads every window page's events again (`EKEventStoreChanged`, a calendar shown or hidden): one page at
    /// a time, the focus first (§3.8), then composes the window again (the inbox emptied first).
    func reloadEvents() {
        guard !isClosed else { return }
        for id in Self.nearestFirst(pageIds, focus: focusPageId) {
            loadEvents(of: id)
        }
        compose(change: .redecide)
    }

    /// The screen changed `context` (the 30 s now line, a new day, the holiday setting, the language; wave C's
    /// decision C3-M2): the window is composed again with it (the inbox emptied first), a new `windowVersion` the
    /// canvas takes with its paper (F4). The pages, their events and the floors stay. The screen calls this, never
    /// `relayoutPages()` or `prefetch()`, which are the canvas's (the lead's decision 6 of wave B).
    func contextChanged() {
        guard !isClosed else { return }
        compose(change: .redecide)
    }

    // MARK: Composing

    /// The inbox emptied (so the window holds every stroke the canvas handed over), the window from the slots
    /// (with the session's aliases) and its layout; a new `windowVersion`. The only place that changes `window`,
    /// `layout` and `windowVersion` after the opening.
    private func compose(change: SpanAlign.Change) {
        drainInbox()
        let pages = pageIds.compactMap { slots[$0]?.page }
        let composed = SpanComposer.compose(pages, plan: plan, session: number, aliases: aliases)
        aliases = composed.aliases
        window = composed
        for id in composed.skippedPageIds {
            fault("compose: \(id) left out of the window")
        }
        layoutPages(change: change)
        windowVersion += 1
    }

    /// Each window page laid out (`floors` from the day's free memo, D16) and joined (`layout`), from the window's
    /// first page (`windowFirstIndex`), whatever the focus.
    private func layoutPages(change: SpanAlign.Change) {
        let firstIndex = windowFirstIndex
        let bottoms = pageIds.map { slots[$0]?.page.inkBottoms() ?? [:] }
        if kind == .day {
            floors = SpanAlign.dayFloors(previous: floors, extraInkBottoms: bottoms.map { $0[.extra] ?? 0 }, change: change)
        }
        var pages: [any PageLayout] = []
        for (offset, id) in pageIds.enumerated() {
            pages.append(pageLayout(index: firstIndex + offset, pageId: id, inkBottoms: bottoms[offset]))
        }
        layout = SpanLayout(pages: pages, plan: plan, firstIndex: firstIndex, floors: floors, session: number)
    }

    private func pageLayout(index: Int, pageId: String, inkBottoms: [CellKey: CGFloat]) -> any PageLayout {
        let first = plan.firstDay(at: index)
        let pageEvents = events[pageId] ?? []
        let c = context
        switch kind {
        case .day:
            return DayLayoutEngine.layout(DayLayoutInput(day: first, events: pageEvents, inkBottoms: inkBottoms, now: c.now, calendar: c.calendar,
                                                         holidays: c.holidays, words: c.words, extraFloor: floors.dayExtra))
        case .week:
            return WeekLayoutEngine.layout(WeekLayoutInput(focus: first, events: pageEvents, inkBottoms: inkBottoms, now: c.now, calendar: c.calendar,
                                                           holidays: c.holidays, words: c.words, weekStart: weekStart, extraFloor: floors.weekExtra))
        case .month:
            return MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: first.year, month: first.month), events: pageEvents,
                                                             inkBottoms: inkBottoms, now: c.now, calendar: c.calendar, holidays: c.holidays,
                                                             words: c.words, weekStart: weekStart))
        case .year:
            return YearLayoutEngine.layout(YearLayoutInput(year: first.year, events: pageEvents, inkBottoms: inkBottoms, now: c.now,
                                                           calendar: c.calendar, holidays: c.holidays, words: c.words))
        }
    }

    /// The canvas reported that handwriting may have crossed the bottom of its cell (`onInkBoundsChanged`):
    /// the inbox is emptied and the window composed and laid out again — the day's free memo grows past
    /// 5,950 lu, or comes back when erased (D16) — with the same virtual page (a new `windowVersion` whose
    /// window holds the strokes just drawn).
    func relayoutPages() {
        guard !isClosed else { return }
        drainInbox()
        let previous = floors.floor(for: kind)
        let tallest = pageIds.map { SpanAlign.natural(inkBottom: slots[$0]?.page.inkBottoms()[.extra] ?? 0) }.max() ?? 0
        compose(change: tallest < previous ? .inkShrank : .inkGrew)
    }

    // MARK: Deltas (§3.4)

    /// Applies what the inbox holds (`deliver`). The canvas's arrivals come here on the next turn.
    func drainInbox() {
        guard !isClosed else {
            inbox.discard()
            return
        }
        let taken = inbox.take()
        guard !taken.deltas.isEmpty || !taken.unrouted.isEmpty else { return }
        deliver(taken.deltas, unrouted: taken.unrouted)
    }

    /// Applies each delta to its real page (`SpanComposer.apply`, i.e. `InkPage.add` / `remove`; a page is never
    /// written back whole, §3.4): the page is dirty, its added ids kept for the guard, its save-order marks
    /// set (D8). A delta of a page not in the window, or made under a number older than its page's last reset
    /// (D7: 「全て消す」, a deletion from another device), is not applied and is recorded; so are `unrouted`, the
    /// names of the same journal that reach no page (§3.4 (d)). A change starts the save timer. Nothing after
    /// `closeWithoutSaving()`.
    func deliver(_ deltas: [PageDelta], unrouted: [String]) {
        guard !isClosed else { return }
        if !unrouted.isEmpty {
            fault("unrouted names: \(unrouted.joined(separator: ", "))")
        }
        var changed = false
        for delta in deltas {
            guard var slot = slots[delta.pageId] else {
                fault("delta for \(delta.pageId), not in the window")
                continue
            }
            let floor = max(resetAll, resetOf[delta.pageId] ?? 0)
            guard delta.epoch >= floor, delta.epoch <= epoch else {
                record("dropped a delta of number \(delta.epoch) for \(delta.pageId) (the page was reset at \(floor))")
                continue
            }
            slot.page = SpanComposer.apply(delta, to: slot.page)
            slot.dirty = true
            slot.added.formUnion(delta.added.map(\.id))
            if !delta.added.isEmpty {
                slot.addedSinceSave = true
                if let group = delta.group { slot.destinationGroups.insert(group) }
            }
            if !delta.removed.isEmpty, let group = delta.group {
                slot.sourceGroups.insert(group)
            }
            slots[delta.pageId] = slot
            changed = true
        }
        guard changed else { return }
        let now = clock()
        visit.inkChanged = true
        visit.lastInkChangeAt = now
        onOwnInk?(now)
        scheduleSave()
    }

    /// One save timer per session (D8): `saveAll()` `saveDelay` after the last change.
    private func scheduleSave() {
        guard !isClosed else { return }
        saveGeneration += 1
        let generation = saveGeneration
        Task { @MainActor [weak self] in
            guard let sleep = self?.sleep else { return }
            await sleep(Self.saveDelay)
            guard let self, generation == self.saveGeneration, !self.isClosed else { return }
            self.saveAll()
        }
    }

    /// §3.4 (c): each window page's range of the canvas's latest window, merged into its slot (`InkPage.merge`,
    /// a union with tombstones). The range is taken with the real page id, and a merge that would change the id
    /// is a fault; a merge that brings anything is a recovery (a delta went missing): the slot takes it and is
    /// dirty. A page another device emptied is left out until the canvas took a window composed after it (H1).
    private func safetyNet() {
        guard let latest = inbox.latestWindow else { return }
        for id in pageIds {
            guard var slot = slots[id], !slot.unread else { continue }
            if let from = safetyNetFrom[id] {
                guard inbox.latestBasis >= from else { continue }
                safetyNetFrom[id] = nil
            }
            let range = SpanComposer.extract(pageId: id, from: latest)
            guard range.pageId == id else { continue }
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

    // MARK: Saving (D8)

    /// Empties the inbox, runs the safety net and saves every dirty page in the order of D8: the pages that
    /// got strokes first (the window's order among them), then the others; a page that lost strokes to a
    /// move across pages (an undo group) is saved only after the group's destination was, and not at all
    /// when that save failed (two copies rather than none). A page with a deletion from iCloud waiting is not
    /// saved (it would bring the page back). Updates and deletions that arrive meanwhile (the engine's `save`
    /// reports a merge with the file inside the call) are applied at the end. Returns the page ids that could
    /// not be saved (they stay dirty; `onSaveFailed` is told once).
    @discardableResult
    func saveAll() -> [String] {
        guard !isClosed else { return [] }
        saveGeneration += 1 // a waiting timer has nothing left to do
        procedureDepth += 1
        drainInbox()
        safetyNet()
        let failed = saveDirtyPages(pageIds)
        procedureDepth -= 1
        applyPendingRemote()
        if !failed.isEmpty { onSaveFailed?(failed) }
        return failed
    }

    /// The dirty pages among `ids`, saved in the order of D8; the ones that could not be saved.
    private func saveDirtyPages(_ ids: [String]) -> [String] {
        // A placeholder that took a delta before its read is read now: its file goes into the save (D6).
        for id in ids where slots[id]?.dirty == true && slots[id]?.unread == true {
            readPlaceholder(id)
        }
        let dirty = ids.filter { slots[$0]?.dirty == true }
        let order = dirty.filter { slots[$0]?.addedSinceSave == true } + dirty.filter { slots[$0]?.addedSinceSave != true }
        var attempted: [String: Bool] = [:]
        var inProgress: Set<String> = []
        func attempt(_ id: String) -> Bool {
            if let done = attempted[id] { return done }
            // Two moves in opposite directions point back here: the first page asked goes first.
            guard inProgress.insert(id).inserted else { return true }
            defer { inProgress.remove(id) }
            if let groups = slots[id]?.sourceGroups, !groups.isEmpty {
                for other in order where other != id && slots[other]?.destinationGroups.isDisjoint(with: groups) == false {
                    guard attempt(other) else {
                        record("not saved \(id): the destination \(other) of its move could not be saved (D8)")
                        attempted[id] = false
                        return false
                    }
                }
            }
            let ok = persist(id)
            attempted[id] = ok
            return ok
        }
        return order.filter { !attempt($0) }
    }

    /// `PageSlot.persist` of one window page: the guard, then the engine's save. A repair is recorded (and Debug
    /// stops on it); a refusal and a failure are recorded and leave the page dirty. A page with a deletion
    /// from iCloud waiting is not written.
    private func persist(_ pageId: String) -> Bool {
        guard let slot = slots[pageId] else { return false }
        if pendingRemote.contains(.delete(pageId)) {
            record("not saved \(pageId): deleted in iCloud meanwhile")
            return true
        }
        willPersist?(pageId)
        let outcome = PageSlot.persist(slot.page, added: slot.added, mode: guardMode,
                                       willWrite: { [weak self] repaired in self?.slots[pageId]?.page = repaired },
                                       write: { [sync] page in try sync.save(page) })
        switch outcome {
        case .saved:
            break
        case .repaired(let stripped, let dropped):
            fault("repaired \(pageId): stripped \(stripped.joined(separator: ",")), dropped \(dropped.joined(separator: ","))")
        case .refused:
            record("refused \(pageId)")
            return false
        case .failed(let text):
            record("save failed \(pageId): \(text)")
            return false
        }
        if var saved = slots[pageId] {
            saved.dirty = false
            saved.addedSinceSave = false
            saved.destinationGroups = []
            saved.sourceGroups = []
            slots[pageId] = saved
        }
        return true
    }

    /// 「全て消す」 (§3.5, H3): the timer stops, the inbox is thrown away, the number moves on (every delta made
    /// before is dropped), the pages empty and nothing is saved, and the safety net leaves them until the canvas
    /// took a window composed after this. The screen then opens a new session (the canvas,
    /// its ↶ with it); until it does, an update from outside merges into empty pages, never into the erased ink.
    func cancelAll() {
        saveGeneration += 1
        inbox.discard()
        epoch += 1
        resetAll = epoch
        pendingRemote = []
        for id in pageIds {
            slots[id] = PageSlot(page: InkPage(pageId: id))
        }
        historyPrune.formUnion(pageIds)
        countStrokes()
        compose(change: .inkShrank)
        // The canvas's window still holds the erased ink: the safety net waits for a window composed after this.
        for id in pageIds { safetyNetFrom[id] = windowVersion }
    }

    /// 「消して始める」 before the `await` (H2, §6.6): the slots and the inbox are thrown away and the session is
    /// closed — `saveAll()`, the timer and `deliver` do nothing any more, so no page of the old account reaches
    /// the new account's store. The screen takes the canvas away and opens a new session after
    /// `reloadShownPage`.
    func closeWithoutSaving() {
        saveGeneration += 1
        isClosed = true
        inbox.discard()
        inbox.onArrival = nil
        pendingRemote = []
        epoch += 1
        resetAll = epoch
        for id in pageIds {
            slots[id] = PageSlot(page: InkPage(pageId: id))
        }
    }

    // MARK: From outside (§3.5, D6, H1)

    /// `SyncEngine.onRemoteUpdate` for this window: during a procedure it waits (D6); otherwise a window page
    /// takes the merge (1.2.3's `applyRemote`, CalendarRootScreen.swift:1581-1592: unsaved strokes kept, the
    /// band migrated, dirty when this device has strokes the update lacks) and the window is composed again
    /// (the canvas reloads keeping its history). A page outside the window is read when it comes in.
    func remoteUpdated(_ page: InkPage) {
        guard !isClosed, slots[page.pageId] != nil else { return }
        if procedureDepth > 0 {
            enqueueRemote(.update(page))
            return
        }
        drainInbox()
        if applyUpdate(page) {
            compose(change: .redecide)
        }
    }

    /// `SyncEngine.onRemoteDelete` (H1, §6.6): another device's 「全て消す」 deleted the page's record. A window page
    /// empties (unsaved strokes of it go too: the erase was for every device), its save marks go, the number
    /// moves on so a delta made before is dropped, its ↶ steps go at the canvas's next window, and the safety
    /// net leaves it until the canvas took that window. During a procedure it waits (D6).
    func remoteDeleted(_ pageId: String) {
        guard !isClosed, slots[pageId] != nil else { return }
        if procedureDepth > 0 {
            enqueueRemote(.delete(pageId))
            return
        }
        drainInbox()
        applyDelete(pageId)
        compose(change: .inkShrank)
        safetyNetFrom[pageId] = windowVersion
    }

    /// D6: one entry per page while it is only updated (the updates merged); a deletion keeps its place in the
    /// order, so an update that came after it is applied after it.
    private func enqueueRemote(_ remote: Remote) {
        if case .update(let page) = remote, let last = pendingRemote.lastIndex(where: { $0.pageId == page.pageId }),
           case .update(let earlier) = pendingRemote[last] {
            pendingRemote[last] = .update(InkPage.merge(earlier, page))
            return
        }
        pendingRemote.append(remote)
    }

    private func applyPendingRemote() {
        guard procedureDepth == 0, !pendingRemote.isEmpty, !isClosed else { return }
        let waiting = pendingRemote
        pendingRemote = []
        drainInbox()
        var changed = false
        var deleted: [String] = []
        for remote in waiting {
            switch remote {
            case .update(let page):
                if applyUpdate(page) { changed = true }
            case .delete(let id):
                if slots[id] != nil {
                    applyDelete(id)
                    deleted.append(id)
                    changed = true
                }
            }
        }
        guard changed else { return }
        compose(change: deleted.isEmpty ? .redecide : .inkShrank)
        for id in deleted { safetyNetFrom[id] = windowVersion }
    }

    /// 1.2.3's `applyRemote` on one slot; true when the slot changed.
    private func applyUpdate(_ updated: InkPage) -> Bool {
        guard var slot = slots[updated.pageId] else { return false }
        let merged = BandMigration.migrate(InkPage.merge(slot.page, updated))
        guard merged.pageId == updated.pageId else {
            fault("update: \(updated.pageId) would become \(merged.pageId)")
            return false
        }
        guard merged.contentDiffers(from: slot.page) || merged.updatedAt != slot.page.updatedAt else { return false }
        slot.page = merged
        let localOnly = merged.contentDiffers(from: updated)
        if localOnly && !slot.unread { slot.dirty = true }
        slots[updated.pageId] = slot
        if localOnly && !slot.unread { scheduleSave() }
        countStrokes()
        return true
    }

    private func applyDelete(_ pageId: String) {
        epoch += 1
        resetOf[pageId] = epoch
        var slot = PageSlot(page: InkPage(pageId: pageId))
        slot.capNoticedPageId = slots[pageId]?.capNoticedPageId
        slots[pageId] = slot
        historyPrune.insert(pageId)
        countStrokes()
    }

    // MARK: Moving (§3.6, §3.7)

    /// The paper scrolled: the focus follows the middle of the screen (`midX`, band lu) with the hysteresis of
    /// `SpanPlan.focus` (6 % of a page), so the title does not flip over a boundary. True when it changed.
    @discardableResult
    func scrolled(midX: CGFloat) -> Bool {
        let slot = min(max(0, plan.focus(midX: midX, previous: focusSlot)), max(0, pageIds.count - 1))
        let next = windowFirstIndex + slot
        guard next != focusIndex else { return false }
        focusIndex = next
        return true
    }

    /// The paper stopped (§3.7, D20): the focus at `midX`; when it is another page than the visit's, the visit
    /// ends (the screen's rating prompt reads it, as it reads ◀ ▶'s today) and a new one starts. The screen
    /// remembers `focusDay` and asks the canvas to shift the window when the focus is off its middle.
    func stopped(midX: CGFloat) -> Stop {
        scrolled(midX: midX)
        let id = focusPageId
        guard id != visit.pageId else { return Stop(focusDay: focusDay, ended: nil) }
        let ended = visit
        visit = Visit(pageId: id)
        return Stop(focusDay: focusDay, ended: ended)
    }

    /// The focus is not the window's middle page: the canvas shifts the window (`shift(toFocusIndex: focusIndex)`)
    /// once the paper is still (§3.6).
    var needsShift: Bool {
        windowFirstIndex != focusIndex - radius
    }

    /// ◀ ▶ (§3.6): one page, slid (the window always holds the next page on each side, R ≥ 1).
    func move(by delta: Int) -> Move {
        .slide(pages: delta)
    }

    /// 「今日」 (§3.6): the page holding `day` is slid to when it is in the window, else a new session opens there
    /// (1.1.1's `revealRect` then brings today's cell on screen).
    func today(_ day: DayKey) -> Move {
        let index = plan.index(containing: day)
        guard index >= windowFirstIndex, index - windowFirstIndex < pageIds.count, pageIds.contains(plan.pageId(at: index)) else {
            return .reopen(focus: day)
        }
        return .slide(pages: index - focusIndex)
    }

    /// The window around `newFocus` (§3.6 ずらし, the session's part): the inbox emptied, the safety net, every
    /// page that leaves saved first — when one cannot be, nothing changes (false, and the canvas does not
    /// shift); the pages that come in are placeholders read by `prefetch()`; the pages that left go to the
    /// canvas's history prune; the window composed again with the same aliases (a new `windowVersion`, the
    /// virtual id kept). Updates and deletions that arrive meanwhile are applied at the end (D6).
    @discardableResult
    func shift(toFocusIndex newFocus: Int) -> Bool {
        rebuild(around: newFocus, plan: plan, radius: radius, change: .shift)
    }

    /// A rotation or a change of Split View (§3.6, the last point): when the paper stops, the canvas decides the
    /// window anew around the focus page — the plan of `orientation` (the device stays), its R or the wider one
    /// `paperArea` needs (`windowRadius`; the plan's when that is over the cap, `fittingRadius`) — with the steps
    /// of a shift: the pages that leave are saved first (when one cannot be, nothing changes and the answer is
    /// false), the pages that come in are placeholders for `prefetch()`. The session stays (its id, virtual page,
    /// number, aliases and the canvas's history), so ↶ survives the rotation.
    @discardableResult
    func redecide(orientation: SpanOrientation, paperArea: CGSize? = nil) -> Bool {
        guard !isClosed else { return false }
        drainInbox()
        let next = SpanPlan(kind: kind, weekStart: weekStart, deviceClass: deviceClass, orientation: orientation)
        let wide = max(1, Self.windowRadius(plan: next, paperArea: paperArea))
        return rebuild(around: focusIndex, plan: next, radius: fittingRadius(wide, plan: next, focus: focusIndex), change: .redecide)
    }

    /// The window of `newPlan` and `newRadius` around `newFocus`: the steps of `shift` (above), then the window's
    /// first page, the plan and the radius set together.
    @discardableResult
    private func rebuild(around newFocus: Int, plan newPlan: SpanPlan, radius newRadius: Int, change: SpanAlign.Change) -> Bool {
        guard !isClosed else { return false }
        procedureDepth += 1
        drainInbox()
        safetyNet()
        let nextIds = Self.window(around: newFocus, radius: newRadius).map(newPlan.pageId(at:))
        let leaving = pageIds.filter { !nextIds.contains($0) }
        let failed = saveDirtyPages(leaving)
        guard failed.isEmpty else {
            record("window not moved: \(failed.joined(separator: ",")) could not be saved")
            procedureDepth -= 1
            applyPendingRemote()
            onSaveFailed?(failed)
            return false
        }
        for id in leaving {
            slots[id] = nil
            events[id] = nil
            safetyNetFrom[id] = nil
        }
        historyPrune.formUnion(leaving)
        for id in nextIds where slots[id] == nil {
            slots[id] = PageSlot(page: InkPage(pageId: id), unread: true)
        }
        plan = newPlan
        radius = newRadius
        focusIndex = newFocus
        windowFirstIndex = newFocus - newRadius
        pageIds = nextIds
        countStrokes()
        compose(change: change)
        procedureDepth -= 1
        applyPendingRemote()
        return true
    }

    // MARK: Weight (§3.15, D18)

    /// The live strokes of the window: the read pages' own count, the placeholders estimated from their file
    /// sizes (`SpanPlan.estimatedStrokes`, counted high). Above the device's cap the screen falls back to one
    /// page for this kind (`fallsBackToOnePage`).
    private func countStrokes() {
        let total = estimatedStrokes(of: pageIds)
        windowStrokeCount = total
        let heavy = total > plan.strokeCap
        if heavy != fallsBackToOnePage { fallsBackToOnePage = heavy }
    }

    /// The live strokes of the pages `ids`: a read page's own count; a placeholder's, or a page the session does
    /// not hold yet, from its file size (`SpanPlan.estimatedStrokes`, counted high) and what its placeholder took.
    private func estimatedStrokes(of ids: [String]) -> Int {
        var total = 0
        for id in ids {
            if let slot = slots[id], !slot.unread {
                total += slot.page.liveStrokeCount
            } else {
                total += SpanPlan.estimatedStrokes(fileBytes: fileBytes(id)) + (slots[id]?.page.liveStrokeCount ?? 0)
            }
        }
        return total
    }

    private func fileBytes(_ pageId: String) -> Int {
        let url = sync.store.url(for: pageId)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber
        return size?.intValue ?? 0
    }

    // MARK: Records

    /// Changes a slot's page by hand: only the tests' way to put a leak of window names into a page (§6.3's
    /// fixture 7). Marks the page dirty.
    func editSlotForTesting(_ pageId: String, _ body: (inout InkPage) -> Void) {
        guard var slot = slots[pageId] else { return }
        body(&slot.page)
        slot.dirty = true
        slots[pageId] = slot
    }

    /// Tests only (B_DESIGN.md:170, §10.2 row L, the lead's decision L11 of S5): the window narrowed to the focus page
    /// alone (radius 0), so the growth tests of 1.1 run through a canvas of a one-page `SpanSession` as well as of three
    /// pages. The window is built anew with the steps of a shift (`rebuild`: the pages that leave saved first, the
    /// window composed again); true when it was. Only in a Debug build, which the tests run: a Release build does
    /// nothing here and answers false, so a window the app opens always holds a page on each side of the focus (the
    /// radius `init` and `redecide` give is never below 1; `move(by:)` relies on it). The screen never calls this.
    @discardableResult
    func narrowToOnePageForTesting() -> Bool {
        #if DEBUG
        return rebuild(around: focusIndex, plan: plan, radius: 0, change: .redecide)
        #else
        return false
        #endif
    }

    private func record(_ message: String) {
        records.append(message)
        if records.count > 200 { records.removeFirst(records.count - 200) }
        #if DEBUG
        NSLog("span session: %@", message)
        #endif
    }

    private func fault(_ message: String) {
        faultCount += 1
        record("fault: " + message)
        Self.onFault(message)
    }
}
