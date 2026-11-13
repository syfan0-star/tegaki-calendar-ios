import Combine
import CoreGraphics
import Foundation
import Holidays
import InkModel
import Layout

// The screen's two paths (1.3, docs/M7C_CONTRACT.md §3.1, §3.5, §3.7, §3.10, §3.11, §3.15, §6.6, D2, D7, D20, D21;
// wave C's plan §2, §3, §5, §7.1 and the lead's decisions on it): which path a page opens on (`joins`, the one place
// that decides), the one-page path's page (`OnePageSession`, 1.2.3's lines) or the window of joined weeks and days
// (`SpanSession`), and every call of the screen that goes one way or the other — the saves at every boundary, the
// opening anew with the old window kept until its canvas has handed over its last strokes (`closing`), the import, the
// export and its PDF, the account's answer, 「全て消す」, the updates and deletions from iCloud, the stops of the paper
// (the title, `remember`, the rating prompt's visit, the week start's boundary, stage 2), ◀ ▶ and 「今日」, the notices
// per page, the heading paired with its window's version, and the points of the band routed to the page under them.
//
// No UIKit and no SwiftUI views (the tests drive it on its own over a live `SyncEngine`, as they drive the sessions):
// the screen (`CalendarRootScreen`) calls these and keeps only what draws. It never imports `@_spi(SpanLedger)`: the
// window's strokes are read through `SpanName` and `SpanSession.page(_:)`.
@MainActor
final class ScreenPaths: ObservableObject {
    /// The path on the screen: one page (1.2.3's canvas), the window of joined pages, or none while 「消して始める」 waits
    /// for the engine (or while the window scene is not there yet): the desk only.
    enum Path: Equatable {
        case onePage, joined, erasing
    }

    /// The device a window is sized for (`SpanSession`'s `deviceClass` and `orientation`, C3-m11).
    struct Device: Equatable {
        var deviceClass: SpanDeviceClass
        var orientation: SpanOrientation
    }

    /// What a page opens with (§7.1): the kind, the focus, the week start; for a window also the device (nil before the
    /// window scene is there: then a joined page waits on the desk, C3-m11), the paper area measured under the band
    /// and the paper's context.
    struct Opening {
        var kind: PageKind
        var focus: DayKey
        var weekStart: WeekStart
        var device: Device?
        var paperArea: CGSize?
        var context: SpanSession.PaperContext
    }

    /// What `open` did.
    enum Opened: Equatable {
        case onePage
        case joined
        /// The kind is joined but its window was too heavy (stage 2, §3.15): it opened on one page.
        case fellBack
        /// The kind is joined but the window scene is not there yet (C3-m11): the desk, until `open` is called again.
        case waiting
    }

    /// A window that was open before the screen opened anew (§3.4 (d), B_DESIGN.md:208): its canvas hands its last
    /// strokes over when SwiftUI takes it away (`detach` → the inbox), after the new window is up. It stays here until
    /// that hand-over arrived (C3-m9: `put` moves the inbox's basis off −1) and it was saved; what changed in it since
    /// the reopening reaches the path on the screen as an update.
    struct Closing {
        let session: SpanSession
        /// Its pages when it was closed: a page that differs afterwards is handed to the path on the screen.
        var pages: [String: InkPage]
        /// Its canvas had attached (a session whose canvas was never made has nothing to hand over).
        let hadCanvas: Bool
        /// The canvas's hand-over (`detach`'s put, or any later put) arrived.
        @MainActor var handedOver: Bool { session.inbox.latestBasis >= 0 }
    }

    /// The stroke budget's notice of one page (D21; `CalendarRootScreen.strokeBudgetReached`'s two toasts).
    enum StrokeNotice: Equatable {
        case many, full
    }

    /// What a stop of the paper means for the screen (§3.7, D20, C3-m6, C3-m7).
    struct Stopped: Equatable {
        /// The screen's focus on the focus page, its weekday kept (`focus(_:kind:weekStart:movedTo:)`).
        var focus: DayKey
        /// The visit that ended (the rating prompt's): nil when the focus page did not change.
        var visitEnded: SpanSession.Visit?
        /// The window became too heavy once its pages were read (stage 2): the screen opens this kind on one page.
        var fallBack: Bool
    }

    /// What 「今日」 does on the joined path (the plan §4.1, the lead's decision on the zoomed 「今日」).
    enum Today: Equatable {
        /// Far: a new window at today.
        case reopen(DayKey)
        /// Near, at the overview: slide by this many pages (`slidePages`).
        case slide(Int)
        /// Today's page is the focus, or the paper is zoomed in: bring this rect (band lu) on screen (`revealRect`).
        case reveal(CGRect)
    }

    /// The fixed heading and the band of the joined path (L8): the window of one `windowVersion` with the viewport the
    /// canvas reported for it. A version whose first page moved (a shift, a decision anew) waits for a viewport of its
    /// own; a version that did not (events, the now line, a growing cell) is used at once with the last viewport.
    struct Heading: Equatable {
        var version: Int
        var firstIndex: Int
        var span: PaperSpan
        /// nil until the canvas reported one (the screen then uses `bandViewport`).
        var viewport: PaperViewport?
    }

    /// At the overview the paper is "not zoomed in" up to this ratio (the canvas's `applyBandOpening`).
    static let overviewRatio: CGFloat = 1.0005

    // MARK: Inputs

    let sync: SyncEngine
    let onePage: OnePageSession
    /// Screenshot mode (its engine never writes; nothing is remembered; the one-page path reads the demo page).
    let screenshot: Bool
    /// The events of a window page (`EventStoreModel.events(from:to:)`), given to every session opened.
    var eventSource: ((DayKey, DayKey) -> [LayoutEvent])?
    /// This device's setting 「前後のページを横につなげる」 (`AppSettings.pageSpan`).
    var settingOn: () -> Bool
    /// Screenshot mode's own setting (memory only, the plan §5.1): off by default, so the photos stay 1.2.3's.
    var screenshotSpan = false
    /// Screenshot mode's pages of the joined path (the wiring step's demo pages); nil reads the engine.
    var shotPage: ((String) -> InkPage)?
    /// Where `lastPageKind` / `lastFocusDate` are written at a stop (1.2.3's `remember` writes `.standard`).
    let defaults: UserDefaults

    // MARK: Hooks to the screen

    /// A save failed (once while the alert is up: `saveFailureNoticeClosed()` lets the next one through).
    var onSaveFailed: ((String) -> Void)?
    /// The person's own ink changed on the joined path (D20, 1.2.2's age range reads the time).
    var onOwnInk: ((Date) -> Void)?
    /// A kind fell back to one page for the first time on this device (N-8, once per device and kind).
    var onStageTwo: ((PageKind) -> Void)?
    /// The one-page path's page changed from a closing window's hand-over (the screen lays the paper out again).
    var onShownPageChanged: (() -> Void)?
    /// The engine hears that the app went to the background (`SyncEngine.applicationDidEnterBackground`; the tests
    /// read the order through it).
    var engineWentToBackground: () -> Void

    // MARK: State

    @Published private(set) var path: Path = .onePage
    /// The window on the screen (nil off the joined path). Its `objectWillChange` is passed on, so the screen draws the
    /// title, the heading and the band again when the focus or the window moves.
    @Published private(set) var span: SpanSession?
    @Published private(set) var heading: Heading?
    private(set) var closing: [Closing] = []
    /// The windows opened so far (the session's number).
    private(set) var openings = 0
    /// The kinds that fell back to one page in this run (stage 2): one page until the next launch or the setting's off → on.
    private(set) var fallenBack: Set<PageKind> = []
    /// 「全て消す」 runs: a window opened meanwhile reads empty pages (`eraseDidFinish()` ends it, §4.4).
    private(set) var erasingStore = false
    /// A joined page waits for the window scene (`Opened.waiting`).
    private(set) var waitingForScene = false
    /// `windowVersion` right after the window opened (stage 2 at a stop needs the reads done, C3-m6).
    private var openedVersion = 0
    /// `EventStoreModel.revision` when the events of the window were read (C3-m8).
    private var eventsRevision: Int?
    private var pendingHeading: Heading?
    private var lanes = AllDayBandLanes()
    private var watches: [AnyCancellable] = []
    private var firstViewportSeen = false
    private var lastBudgetFullAt: Date?
    private var saveFailureUp = false
    private let sleep: @MainActor (TimeInterval) async -> Void
    private let clock: () -> Date

    init(sync: SyncEngine, onePage: OnePageSession, screenshot: Bool = ScreenshotMode.isActive,
         settingOn: @escaping () -> Bool = { AppSettings.pageSpan }, defaults: UserDefaults = .standard,
         sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
         clock: @escaping () -> Date = Date.init) {
        self.sync = sync
        self.onePage = onePage
        self.screenshot = screenshot
        self.settingOn = settingOn
        self.defaults = defaults
        self.sleep = sleep
        self.clock = clock
        engineWentToBackground = { [sync] in sync.applicationDidEnterBackground() }
    }

    // MARK: The one place that decides the path (§5.1)

    /// Whether a page of `kind` opens joined (D2, §3.1, §3.15, the plan §5.1): only a week or a day, with the setting on
    /// (in screenshot mode its own memory-only setting, off by default), and not a kind that fell back to one page in
    /// this run. Month and year are always one page in 1.3.
    static func joins(kind: PageKind, setting: Bool, screenshot: Bool, screenshotSpan: Bool, fallenBack: Set<PageKind>) -> Bool {
        guard kind == .week || kind == .day, !fallenBack.contains(kind) else { return false }
        return screenshot ? screenshotSpan : setting
    }

    /// The device of a window (C3-m11): an iPad by the idiom, the class and the orientation from the window's size (the
    /// root view's size with its safe area); nil while there is no size yet (no window scene).
    static func device(isPad: Bool, windowSize: CGSize) -> Device? {
        guard windowSize.width.isFinite, windowSize.height.isFinite, windowSize.width > 0, windowSize.height > 0 else { return nil }
        return Device(deviceClass: SpanDeviceClass(screen: windowSize, isPad: isPad), orientation: SpanOrientation(screen: windowSize))
    }

    // MARK: Saving (§2 #1, #2, #8, #10, #14, #16)

    /// Every page of the path on the screen saved now (the one page's `saveNow`, the window's `saveAll`), the closing
    /// windows first. The pages that could not be saved (the window's; the one page tells through its own hook).
    @discardableResult
    func saveCurrent() -> [String] {
        drainClosing()
        switch path {
        case .joined:
            return span?.saveAll() ?? []
        case .onePage:
            onePage.saveNow()
            return []
        case .erasing:
            return []
        }
    }

    /// §2 #1: going to the background or inactive — the pages first, then what the screen does meanwhile, then (to the
    /// background) the engine's `applicationDidEnterBackground`, in 1.2.3's order.
    func sceneLeft(background: Bool, meanwhile: () -> Void = {}) {
        saveCurrent()
        meanwhile()
        if background {
            engineWentToBackground()
        }
    }

    /// `sceneLeft(background: true)` (the tests' name).
    func enterBackground() {
        sceneLeft(background: true)
    }

    /// §2 #8: the export reads the store, so every page goes there first.
    func exportWillOpen() {
        saveCurrent()
    }

    /// §2 #14 (D7): before an import the window's pages are saved (the inbox emptied; the number does not move, so a
    /// stroke the canvas just handed over is never dropped). The one-page path does as 1.2.3 (nothing).
    func importWillRun() {
        guard path == .joined else { return }
        saveCurrent()
    }

    /// §2 #14: after an import the window opens anew on the store (a switch of the week start, if the import made one,
    /// has already done so). The one-page path: nothing (1.2.3's `applyRemote` took the shown page's update).
    func importDidFinish(_ o: Opening) {
        guard path == .joined else { return }
        open(o)
    }

    /// §2 #16: the page `runWeekStartCheck` treats as unsaved: the one page's when it is dirty (1.2.3); on the joined
    /// path the window is saved first and the first page that could not be is it (normally none).
    func dirtyPageForWeekStartCheck(shownPageId: String) -> String? {
        switch path {
        case .onePage:
            return onePage.isDirty ? shownPageId : nil
        case .joined:
            return saveCurrent().first
        case .erasing:
            return nil
        }
    }

    /// The save failed: one notice while it is up (the screen's alert, 「手書きを保存できませんでした」).
    private func saveFailed(_ text: String) {
        guard !saveFailureUp else { return }
        saveFailureUp = true
        onSaveFailed?(text)
    }

    /// The screen's save-failure alert closed: the next failure tells again.
    func saveFailureNoticeClosed() {
        saveFailureUp = false
    }

    // MARK: Opening (§2 #4, #13, #15, §3.1, §3.15)

    /// Opens `(kind, focus)` on its path (the one place, `joins`): the pages on the screen saved first (K-3: never the
    /// same page on two paths), the window that was open goes to `closing`, then a new window — or, when its pages are
    /// estimated over the device's cap (stage 2), this kind on one page from now on (N-8 once) — or 1.2.3's one page
    /// (the demo page in screenshot mode; else `sync.load`, `pageOpened`, `OnePageSession.open`).
    @discardableResult
    func open(_ o: Opening) -> Opened {
        saveCurrent()
        let joined = Self.joins(kind: o.kind, setting: settingOn(), screenshot: screenshot, screenshotSpan: screenshotSpan,
                                fallenBack: fallenBack)
        retire()
        waitingForScene = false
        if joined {
            guard let device = o.device else {
                waitingForScene = true
                path = .erasing
                return .waiting
            }
            let session = makeSession(o, device: device)
            if !session.fallsBackToOnePage {
                adopt(session)
                return .joined
            }
            // A page the migration changed is written; nothing else of the window was read.
            session.saveAll()
            fallBack(o.kind)
        }
        openOnePage(o)
        return joined ? .fellBack : .onePage
    }

    /// 1.2.3's `show` for the one page (CalendarRootScreen.swift:1363-1375 of r13's 1c5eb0a, the same lines).
    private func openOnePage(_ o: Opening) {
        path = .onePage
        let id = PageNavigation.pageId(o.kind, focus: o.focus, weekStart: o.weekStart)
        let loaded: InkPage
        if screenshot {
            // Screenshot mode injects its demo strokes in memory; the store is not read or written.
            loaded = ScreenshotMode.demoPage(kind: o.kind, focus: o.focus, weekStart: o.weekStart)
        } else {
            loaded = sync.load(id)
            // M4 contract §5.3: fetch this one page from iCloud (a page written on another device
            // just before it was opened here); a change arrives through `onRemoteUpdate`.
            sync.pageOpened(id)
        }
        // M4B contract §3.3: the week / day band's handwriting moves onto the grid (idempotent; the
        // ledger does the same). A page that changed is saved and sent right away (M4B-11).
        onePage.open(loaded)
    }

    private func makeSession(_ o: Opening, device: Device) -> SpanSession {
        openings += 1
        return SpanSession(kind: o.kind, weekStart: o.weekStart, focus: o.focus, sync: sync, deviceClass: device.deviceClass,
                           orientation: device.orientation, number: openings, context: o.context, paperArea: o.paperArea,
                           eventSource: eventSource, loader: { [weak self, sync] id in self?.read(id) ?? sync.load(id) },
                           sleep: sleep, clock: clock)
    }

    /// Where a window's page is read from (§4.4): empty while 「全て消す」 deletes the files, the screenshot's demo page,
    /// else the engine.
    private func read(_ pageId: String) -> InkPage {
        if erasingStore { return InkPage(pageId: pageId) }
        if let shotPage { return shotPage(pageId) }
        return sync.load(pageId)
    }

    /// The new window is the screen's: its hooks, its changes passed on, its heading.
    private func adopt(_ session: SpanSession) {
        path = .joined
        span = session
        openedVersion = session.windowVersion
        eventsRevision = nil
        lanes = AllDayBandLanes()
        heading = nil
        pendingHeading = nil
        firstViewportSeen = false
        session.onSaveFailed = { [weak self] _ in self?.saveFailed("") }
        session.onOwnInk = { [weak self] at in self?.onOwnInk?(at) }
        watches = [
            session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() },
            // `@Published` tells before the value is set; `compose` sets `layout` before `windowVersion`, so the layout
            // read here is the new version's.
            session.$windowVersion.sink { [weak self, weak session] version in
                guard let self, let session else { return }
                self.windowComposed(session, version: version)
            },
        ]
    }

    /// The window on the screen goes to `closing` (§3.4 (d)): its pages noted, its inbox's basis set to −1 so the canvas's
    /// hand-over is seen (C3-m9), and the hand-over drains the closing windows on the turn it arrives.
    private func retire() {
        guard let old = span else { return }
        watches = []
        span = nil
        heading = nil
        pendingHeading = nil
        guard !old.isClosed else { return }
        let hadCanvas = old.inbox.latestWindow != nil
        if let latest = old.inbox.latestWindow {
            // The safety net's source stays the canvas's window; only the basis marks the reopening.
            old.inbox.put([], unrouted: [], window: latest, basis: -1)
        }
        old.inbox.onArrival = { [weak self, weak old] in
            old?.drainInbox()
            self?.drainClosing()
        }
        old.onSaveFailed = { [weak self] _ in self?.saveFailed("") }
        var pages: [String: InkPage] = [:]
        for id in old.pageIds {
            pages[id] = old.page(id)
        }
        closing.append(Closing(session: old, pages: pages, hadCanvas: hadCanvas))
    }

    /// §3.4 (d), C3-m9: each closing window takes what its inbox holds and saves; a page that changed since it closed is
    /// handed to the path on the screen as an update from outside; a window is let go once it was saved and its canvas
    /// handed over (or it never had one).
    func drainClosing() {
        guard !closing.isEmpty else { return }
        var kept: [Closing] = []
        for var c in closing {
            c.session.drainInbox()
            let failed = c.session.saveAll()
            for id in c.session.pageIds {
                guard let now = c.session.page(id), now != c.pages[id] else { continue }
                c.pages[id] = now
                passOn(now)
            }
            if !failed.isEmpty || (c.hadCanvas && !c.handedOver) {
                kept.append(c)
            }
        }
        closing = kept
    }

    /// A closing window's page reaches the path on the screen as an update (never the virtual page: slots are real).
    private func passOn(_ page: InkPage) {
        switch path {
        case .joined:
            span?.remoteUpdated(page)
        case .onePage:
            if onePage.applyRemote(page) { onShownPageChanged?() }
        case .erasing:
            break
        }
    }

    /// Stage 2 (§3.15, D18, the lead's decision 9 of wave A): the kind stays on one page in this run; N-8 once per device
    /// and kind (never in screenshot mode, where nothing is stored).
    private func fallBack(_ kind: PageKind) {
        fallenBack.insert(kind)
        guard !screenshot, !AppSettings.stageTwoNoticed(kind) else { return }
        AppSettings.markStageTwoNoticed(kind)
        onStageTwo?(kind)
    }

    /// The setting 「前後のページを横につなげる」 changed (§3.1): turning it on decides stage 2 anew. The screen then opens
    /// the page again (`open` saves the old path first).
    func settingChanged(_ on: Bool) {
        if on { fallenBack = [] }
    }

    // MARK: Erasing (§2 #11, #12, H2, H3, C3-M1)

    /// 「全て消す」 (§2 #12, H3, C3-M1): the one page empties and its canvas is made anew (1.2.3's `eraseAll`); every
    /// window — the closing ones and the one on the screen — is cancelled (its timer, its inbox, its number: the old
    /// canvas's last deltas are dropped) and let go; on the joined path a new window opens at `o` reading empty pages
    /// until `eraseDidFinish()` (the files are deleted by the engine's task on a later turn).
    func eraseAll(reopen o: Opening?) {
        onePage.eraseAll()
        for c in closing {
            c.session.cancelAll()
        }
        closing = []
        erasingStore = !screenshot
        guard path == .joined, let current = span else { return }
        current.cancelAll()
        watches = []
        span = nil
        heading = nil
        guard let o, let device = o.device else {
            path = .erasing
            waitingForScene = true
            return
        }
        adopt(makeSession(o, device: device))
    }

    /// The engine's `eraseEverything` returned (or threw): the windows read the store again.
    func eraseDidFinish() {
        erasingStore = false
    }

    /// The account's answer (§2 #10, #11; H2, H3, C3-M1), 1.2.3's order: 「残す」 saves first; 「消して始める」 closes the
    /// screen before the engine's `await` — the one page empties and pauses its saves (`beginEraseAndStart`), every window
    /// (closing ones included) is closed without saving and the joined path shows the desk — so nothing of the old account
    /// can reach the new one's store; after the answer the page is read again (`reload`, a new window on the joined path)
    /// and the one page saves again. `closed` is the screen's part right after closing (the selection, the viewport,
    /// the paper); `answered` runs after every answer. Returns the task that awaits the engine.
    @discardableResult
    func chooseAccount(_ choice: AccountChangeChoice, resolve: @escaping (AccountChangeChoice) async -> Void,
                       closed: @escaping () -> Void = {}, answered: @escaping () -> Void = {},
                       reload: @escaping () -> Void) -> Task<Void, Never> {
        if choice == .keepInk {
            saveCurrent() // a stroke of the last 1.5 s goes along with the rest
        }
        if choice == .eraseInk {
            onePage.beginEraseAndStart()
            for c in closing {
                c.session.closeWithoutSaving()
            }
            closing = []
            if let current = span {
                current.closeWithoutSaving()
                watches = []
                span = nil
                heading = nil
                path = .erasing
            }
            closed()
        }
        let screenshot = self.screenshot
        return Task { @MainActor [weak self] in
            await resolve(choice)
            answered()
            guard let self else { return }
            guard choice != .later, !screenshot else {
                if self.path == .erasing { reload() }
                self.onePage.endEraseAndStart()
                return
            }
            reload()
            self.onePage.endEraseAndStart()
        }
    }

    /// `reloadShownPage` (§2 #13): the one page read again (1.2.3: `onePage.reload(sync.load(pageId))`), or a new window.
    func reloadShown(_ o: Opening) {
        if path == .onePage {
            onePage.reload(sync.load(PageNavigation.pageId(o.kind, focus: o.focus, weekStart: o.weekStart)))
        } else {
            open(o)
        }
    }

    // MARK: From iCloud (§2 #17, #18, H1)

    /// `SyncEngine.onRemoteUpdate` (§2 #17): the one page takes it when it is the shown page (1.2.3's `applyRemote`; true:
    /// the screen lays the paper out again); the window takes it for any of its pages (its procedures hold it back, D6).
    /// A closing window does not (it is saved and let go).
    @discardableResult
    func remoteUpdated(_ page: InkPage, shownPageId: String) -> Bool {
        switch path {
        case .onePage:
            guard page.pageId == shownPageId else { return false }
            return onePage.applyRemote(page)
        case .joined:
            span?.remoteUpdated(page)
            return false
        case .erasing:
            return false
        }
    }

    /// `SyncEngine.onRemoteDelete` (§2 #18, H1): every closing window empties the page too (its last save must not write it
    /// back); the window on the screen empties it; the one page does when it is the shown page (true: the screen clears
    /// the selection and lays the paper out again; its canvas is made anew).
    @discardableResult
    func remoteDeleted(_ pageId: String, shownPageId: String) -> Bool {
        for c in closing {
            c.session.remoteDeleted(pageId)
        }
        switch path {
        case .onePage:
            guard pageId == shownPageId, onePage.remoteDeleted(pageId) else { return false }
            return true
        case .joined:
            span?.remoteDeleted(pageId)
            return false
        case .erasing:
            return false
        }
    }

    // MARK: The one page's canvas (§2.1, H1, H3; C3-M3)

    /// The one-page canvas's `page:` binding as a get / set pair (CalendarRootScreen's `pageBinding`): it keeps the
    /// identity of the canvas it is made for, so a canvas made before a rebuild (H1–H3) writes nothing
    /// (`OnePageSession.canvasWrote`); a write taken is the person's own ink (`ownInk`, 1.2.1).
    func pageBinding(base: String, ownInk: @escaping () -> Void) -> (get: () -> InkPage, set: (InkPage) -> Void) {
        let one = onePage
        let madeFor = one.canvasIdentity(base: base)
        return (get: { one.page }, set: { newValue in
            guard one.canvasWrote(newValue, madeFor: madeFor, base: base) else { return }
            ownInk()
        })
    }

    // MARK: The window's paper and heading (§3.8, L8, C3-M2, C3-m5, C3-m8)

    /// The window composed `version` (the sink of `windowVersion`): the heading's window is made from it (the bands packed
    /// over the window's days, `AllDayBandLanes` of this window), at once when its first page did not move, else once a
    /// viewport of this version arrives.
    private func windowComposed(_ session: SpanSession, version: Int) {
        guard session === span, let made = makeHeadingSpan(session) else { return }
        let first = session.layout.firstIndex
        if let shown = heading, shown.firstIndex == first {
            heading = Heading(version: version, firstIndex: first, span: made, viewport: shown.viewport)
            pendingHeading = nil
        } else if heading == nil {
            heading = Heading(version: version, firstIndex: first, span: made, viewport: nil)
        } else {
            pendingHeading = Heading(version: version, firstIndex: first, span: made, viewport: nil)
        }
    }

    private func makeHeadingSpan(_ session: SpanSession) -> PaperSpan? {
        var days: [DayKey] = []
        var events: [LayoutEvent] = []
        for id in session.pageIds {
            if let range = session.days(of: id) {
                var day = range.start
                while day < range.end {
                    days.append(day)
                    day = day.adding(days: 1)
                }
            }
            events += session.events[id] ?? []
        }
        let c = session.context
        let bands = lanes.bands(session.kind, days: days, events: events, now: c.now, calendar: c.calendar, holidays: c.holidays)
        return PaperSpan(layout: session.layout, bands: bands, focus: session.focusSlot)
    }

    /// The canvas reported its viewport (`onViewportChange`), paired with the window's version as it arrives (L8). The
    /// first one of a new window drains the closing windows on the next turn (§3.4 (d)).
    func viewportArrived(_ viewport: PaperViewport) {
        guard let session = span else { return }
        if let waiting = pendingHeading, waiting.version == session.windowVersion {
            var shown = waiting
            shown.viewport = viewport
            heading = shown
            pendingHeading = nil
        } else if var shown = heading {
            shown.viewport = viewport
            heading = shown
        }
        if !firstViewportSeen {
            firstViewportSeen = true
            Task { @MainActor [weak self] in self?.drainClosing() }
        }
    }

    /// The heading's window with the focus slot of now (the focus follows the paper between two versions).
    var headingSpan: PaperSpan? {
        guard let shown = heading, let session = span else { return nil }
        return PaperSpan(pages: shown.span.pages, bands: shown.span.bands, focus: session.focusIndex - shown.firstIndex)
    }

    /// The events of every page of the window (the sheet of an event on another page, `EventStoreModel.detail(…among:)`).
    var windowEvents: [LayoutEvent] {
        guard let session = span else { return [] }
        return session.pageIds.flatMap { session.events[$0] ?? [] }
    }

    /// The model's events were read for the page that opened (C3-m8): a later `revision` reads the window's again.
    func eventsRead(revision: Int) {
        eventsRevision = revision
    }

    /// `EventStoreModel.revision` moved (C3-m8): the window reads its events again when it rose after the opening's read.
    func eventsChanged(revision: Int) {
        guard path == .joined, let session = span else { return }
        if let read = eventsRevision, revision == read { return }
        eventsRevision = revision
        session.reloadEvents()
    }

    /// The 30 s tick (C3-m5): on the joined path the now line moves when the day changed or any page of the window has
    /// one; the window's context takes `now` and is composed again (C3-M2). True when it did.
    @discardableResult
    func nowTicked(_ now: Date, dayChanged: Bool) -> Bool {
        guard let session = span, Self.nowLineTickDue(dayChanged: dayChanged, window: session.layout) else { return false }
        session.context.now = now
        session.contextChanged()
        return true
    }

    /// C3-m5: the gate of the joined path's tick.
    static func nowLineTickDue(dayChanged: Bool, window: SpanLayout) -> Bool {
        dayChanged || window.pages.contains { $0.nowLine != nil }
    }

    /// The paper's context changed (the holidays, a return to the front's now; C3-M2): the window is composed again.
    func contextChanged(now: Date? = nil, holidays: HolidayCalendar? = nil) {
        guard let session = span else { return }
        if let now { session.context.now = now }
        if let holidays { session.context.holidays = holidays }
        session.contextChanged()
    }

    // MARK: Moving (§2 #5, #6, #7; §3.7, D20)

    /// ◀ ▶ on the joined path: slide one page (the screen bumps `slideTrigger`; the canvas waits under the pen). nil on
    /// the one-page path.
    func move(by delta: Int) -> SpanSession.Move? {
        guard path == .joined, let session = span else { return nil }
        return session.move(by: delta)
    }

    /// 「今日」 on the joined path (the plan §4.1, the lead's decision): far → a new window; near and at the overview → slide;
    /// today's page already the focus, or zoomed in → bring today on screen (at the overview the page in the middle; zoomed
    /// in today's column from an hour before now). `viewport` is the last one reported (nil: `ratio`, the stored one),
    /// `area` the paper area. nil off the joined path.
    func today(_ day: DayKey, now: Date, viewport: PaperViewport?, area: CGSize, ratio: CGFloat) -> Today? {
        guard path == .joined, let session = span else { return nil }
        switch session.today(day) {
        case .reopen(let focus):
            return .reopen(focus)
        case .slide(let pages):
            let zoomed = Self.zoomedIn(layout: session.layout, viewport: viewport, area: area, ratio: ratio)
            if pages != 0, !zoomed { return .slide(pages) }
            let shown = viewport.flatMap { $0.width > 0 ? $0 : nil }
                ?? Self.bandViewport(layout: session.layout, focusPageId: session.focusPageId, now: now,
                                     calendar: session.context.calendar, area: area, ratio: ratio)
            guard let rect = Self.todayRect(layout: session.layout, pageId: session.plan.pageId(at: session.plan.index(containing: day)),
                                            now: now, calendar: session.context.calendar, viewport: shown, area: area, zoomed: zoomed)
            else { return nil }
            return .reveal(rect)
        }
    }

    /// Whether the paper is zoomed in past the overview (the ratio of the reported zoom over the window's opening zoom;
    /// before a report, the stored ratio).
    static func zoomedIn(layout: SpanLayout, viewport: PaperViewport?, area: CGSize, ratio: CGFloat) -> Bool {
        guard let viewport, viewport.width > 0 else { return ratio > overviewRatio }
        let bounds = ZoomPolicy.bounds(layout.kind, overview: InkCanvasView.bandOverview(layout),
                                       viewport: CGSize(width: viewport.width, height: area.height))
        return ZoomPolicy.ratio(forZoom: viewport.zoom, bounds: bounds) > overviewRatio
    }

    /// The rect (band lu) 「今日」 reveals on `pageId` (§4.1): at the overview a rect whose start is the offset that puts the
    /// page in the middle (`ZoomPolicy.revealOffset` lines a rect wider than the screen up with its start); zoomed in,
    /// today's column (the week's, or the day page's width) from an hour before now, one screen high.
    static func todayRect(layout: SpanLayout, pageId: String, now: Date, calendar: Calendar, viewport: PaperViewport,
                          area: CGSize, zoomed: Bool) -> CGRect? {
        guard let slot = layout.slot(ofPage: pageId), viewport.zoom > 0, viewport.width > 0 else { return nil }
        let page = layout.pages[slot]
        let origin = layout.origin(ofSlot: slot)
        let zoom = viewport.zoom
        if !zoomed {
            let target = (origin + layout.plan.pageWidth / 2) * zoom - viewport.width / 2
            return CGRect(x: (target + ZoomPolicy.revealMargin) / zoom, y: 0, width: viewport.width / zoom, height: page.size.height)
        }
        let today = DayKey(now, calendar: calendar)
        var column = CGRect(x: origin, y: 0, width: page.size.width, height: page.size.height)
        if let week = page as? WeekPageLayout, let index = week.days.firstIndex(of: today) {
            column = week.columnFrame(index).offsetBy(dx: origin, dy: 0)
        }
        let top = PageNavigation.initialScrollY(page, now: now, calendar: calendar)
        let height = area.height > 0 ? area.height / zoom : page.size.height
        return CGRect(x: column.minX, y: top + ZoomPolicy.revealMargin / zoom, width: column.width, height: height)
    }

    /// The paper stopped on a focus page (`onSpanStop`; §3.7, D20, C3-m6, C3-m7): the screen's focus moves to it keeping
    /// its weekday and is remembered (`lastPageKind` / `lastFocusDate`, not in screenshot mode); when a visit ended, the
    /// pages are saved and the week start's boundary runs (`boundary`: `runWeekStartCheck(atBoundary: true)` and its
    /// switch, as at `show`, after `focusMoved` told the screen its new focus); once the window's pages are read, a window
    /// over the cap falls back to one page.
    func stopped(_ stop: SpanSession.Stop, focus: DayKey, kind: PageKind, weekStart: WeekStart, focusMoved: (DayKey) -> Void = { _ in },
                 boundary: () -> Void) -> Stopped {
        let next = Self.focus(focus, kind: kind, weekStart: weekStart, movedTo: stop.focusDay)
        Self.remember(kind: kind, focus: next, screenshot: screenshot, defaults: defaults)
        focusMoved(next)
        if stop.ended != nil {
            saveCurrent()
            boundary()
        }
        var heavy = false
        if let session = span, session.fallsBackToOnePage, session.windowVersion != openedVersion {
            heavy = true
            fallBack(kind)
        }
        return Stopped(focus: next, visitEnded: stop.ended, fallBack: heavy)
    }

    /// The screen's focus moved to the page whose first day is `pageFirstDay`, its weekday kept (a week moves by whole
    /// weeks); the same page keeps `focus`.
    static func focus(_ focus: DayKey, kind: PageKind, weekStart: WeekStart, movedTo pageFirstDay: DayKey) -> DayKey {
        let shown = PageNavigation.dayRange(kind, focus: focus, weekStart: weekStart)
        return focus.adding(days: pageFirstDay.dayNumber - shown.start.dayNumber)
    }

    /// 1.2.3's `remember` with its store passed in (C3-M3).
    static func remember(kind: PageKind, focus: DayKey, screenshot: Bool, defaults: UserDefaults) {
        guard !screenshot else { return }
        defaults.set(kind.rawValue, forKey: AppSettings.lastKindKey)
        defaults.set(focus.description, forKey: AppSettings.lastFocusKey)
    }

    // MARK: Week start (§2 #15, §3.9; C3-M3)

    /// 1.2's switch on both paths (`CalendarRootScreen.weekStartSwitch`, its order fixed): every page saved in its old form,
    /// the new form in, the page opened anew (a window of the new form: never two forms in one window, K-11).
    func switchWeekStart(from old: WeekStart, to new: WeekStart, apply: (WeekStart) -> Void, reopen: () -> Void) {
        CalendarRootScreen.weekStartSwitch(old: old, new: new, save: { saveCurrent() }, apply: apply, reload: reopen)
    }

    // MARK: Notices per page (D21)

    /// `onPageStrokeBudget` (D21): `.many` once per page on this device (screenshot mode shows it without the record);
    /// `.full` at most every 2 s. nil: nothing to show.
    func pageStrokeBudget(_ pageId: String, _ event: StrokeBudget.Event, now: Date) -> StrokeNotice? {
        switch event {
        case .many:
            if !screenshot {
                guard !AppSettings.strokeBudgetNoticed(pageId) else { return nil }
                AppSettings.markStrokeBudgetNoticed(pageId)
            }
            return .many
        case .full:
            if let last = lastBudgetFullAt, now.timeIntervalSince(last) < CalendarRootScreen.blockedInputInterval { return nil }
            lastBudgetFullAt = now
            return .full
        }
    }

    /// `onPageGrowthCapReached` (D21): 「メモ欄はここまでです」 once per page while it is in the window.
    func pageGrowthCap(_ pageId: String) -> Bool {
        span?.noteGrowthCap(pageId: pageId) ?? false
    }

    // MARK: The PDF (§2 #9, §3.11, D17)

    /// The PDF of the focus page on the joined path: its paper (the window's page laid out), the real page (the guard
    /// holds for it) and the strokes of the other pages that reach into it. nil on the one-page path.
    func pdfInput() -> (paper: PaperContent, page: InkPage, neighborInk: [SpanPDFInk], focus: DayKey)? {
        guard path == .joined, let session = span, let slot = session.layout.slot(ofPage: session.focusPageId),
              let paper = Self.paper(of: session.layout.pages[slot]),
              let input = session.pdfInput(for: session.focusPageId) else { return nil }
        return (paper, input.page, input.neighborInk, session.focusDay)
    }

    /// A window page as the paper draws it (weeks and days only).
    static func paper(of layout: any PageLayout) -> PaperContent? {
        if let week = layout as? WeekPageLayout { return .week(WeekPaperContent(layout: week)) }
        if let day = layout as? DayPageLayout { return .day(DayPaperContent(layout: day)) }
        return nil
    }

    /// The focus page's paper (the canvas's `paper:`, never drawn on the joined path; the PDF's).
    var focusPaper: PaperContent? {
        guard let session = span, let slot = session.layout.slot(ofPage: session.focusPageId) else { return nil }
        return Self.paper(of: session.layout.pages[slot])
    }

    // MARK: The band's lu (§2 table 2, L9, HANDOFF 6)

    /// Where a zoomed-in window opens (band lu): the focus page's `PageNavigation.initialScrollX` / `Y` with its origin
    /// added (L9).
    static func bandStart(layout: SpanLayout, focusPageId: String, now: Date, calendar: Calendar, visibleWidth: CGFloat) -> CGPoint {
        guard let slot = layout.slot(ofPage: focusPageId) else { return .zero }
        let page = layout.pages[slot]
        return CGPoint(x: layout.origin(ofSlot: slot) + PageNavigation.initialScrollX(page, now: now, calendar: calendar, visibleWidth: visibleWidth),
                       y: PageNavigation.initialScrollY(page, now: now, calendar: calendar))
    }

    /// A point of a page (`--screenshot-offset`, page lu) in the band: the focus page's origin added.
    static func bandPoint(_ point: CGPoint, layout: SpanLayout, focusPageId: String) -> CGPoint {
        CGPoint(x: point.x + (layout.slot(ofPage: focusPageId).map(layout.origin(ofSlot:)) ?? 0), y: point.y)
    }

    /// The zoom a window opens at for `area` (the paper area; its width alone while the height is 0) and the stored ratio.
    static func bandZoom(layout: SpanLayout, area: CGSize, ratio: CGFloat) -> CGFloat {
        ZoomPolicy.zoom(forRatio: ratio, bounds: ZoomPolicy.bounds(layout.kind, overview: InkCanvasView.bandOverview(layout), viewport: area))
    }

    /// The viewport of a window's first frame, before its canvas reported one (HANDOFF 6): at the overview the focus page in
    /// the middle (`offsetX = (origin + W/2)·zoom − width/2`), zoomed in at `bandStart`'s x.
    static func bandViewport(layout: SpanLayout, focusPageId: String, now: Date, calendar: Calendar, area: CGSize, ratio: CGFloat) -> PaperViewport {
        let width = area.width.isFinite && area.width > 0 ? area.width : 0
        let zoom = bandZoom(layout: layout, area: area, ratio: ratio)
        guard let slot = layout.slot(ofPage: focusPageId), width > 0 else { return PaperViewport(offsetX: 0, zoom: zoom, width: width) }
        let bounds = ZoomPolicy.bounds(layout.kind, overview: InkCanvasView.bandOverview(layout), viewport: area)
        if ZoomPolicy.ratio(forZoom: zoom, bounds: bounds) <= overviewRatio {
            return PaperViewport(offsetX: (layout.origin(ofSlot: slot) + layout.plan.pageWidth / 2) * zoom - width / 2, zoom: zoom, width: width)
        }
        let visible = ZoomPolicy.visibleWidth(layout.kind, viewportWidth: width, zoom: zoom)
        let start = bandStart(layout: layout, focusPageId: focusPageId, now: now, calendar: calendar, visibleWidth: visible)
        return PaperViewport(offsetX: start.x * zoom, zoom: zoom, width: width)
    }

    // MARK: Points of the band to the page under them (§2 table 2, HANDOFF 9)

    /// A finger's tap (band lu) as `CalendarRootScreen.tapTarget` answers it on the page under the point (its own lu).
    static func tapTarget(layout: SpanLayout, point: CGPoint, zoom: CGFloat, smallScreen: Bool, allowFinger: Bool, currentMonth: Int) -> HitTarget? {
        guard point.x.isFinite, point.y.isFinite, !layout.pages.isEmpty else { return nil }
        let slot = layout.slot(atX: point.x)
        return CalendarRootScreen.tapTarget(layout: layout.pages[slot], point: layout.localPoint(point, inSlot: slot), zoom: zoom,
                                            smallScreen: smallScreen, allowFinger: allowFinger, currentMonth: currentMonth)
    }

    /// A rect of the 予定 tool or 「予定にする」 (band lu): the page under its centre (`SpanLayout.eventTarget`, D23) and that
    /// page's `CalendarRootScreen.newEventPlan` with the rect in its lu (24:00 and below on a day page is refused).
    static func newEvent(layout: SpanLayout, rect: CGRect, now: Date) -> (plan: CalendarRootScreen.NewEventPlan, pageId: String)? {
        guard rect.minX.isFinite, rect.minY.isFinite, rect.width.isFinite, rect.height.isFinite,
              let target = layout.eventTarget(at: CGPoint(x: rect.midX, y: rect.midY)),
              let slot = layout.slot(ofPage: target.pageId) else { return nil }
        let local = rect.offsetBy(dx: -layout.origin(ofSlot: slot), dy: 0)
        return (CalendarRootScreen.newEventPlan(layout: layout.pages[slot], rect: local, now: now), target.pageId)
    }

    /// The picture of 「予定にする」 (window names): each stroke read from its real page (`SpanName.split`, `page(_:)`) and
    /// drawn in its window cell — a copy for the picture only, never saved. A name the window gave a long id
    /// (`span~a~n`) is not in its page and is left out of the picture (the plan §6 #16).
    static func selectionPicture(_ names: [String], in session: SpanSession) -> (strokes: [InkStroke], cells: [CellKey: CGRect]) {
        var strokes: [InkStroke] = []
        for name in names {
            guard let parts = SpanName.split(name), var stroke = session.page(parts.page)?.strokes[parts.local] else { continue }
            stroke.cell = SpanName.prefixed(stroke.cell, page: parts.page)
            strokes.append(stroke)
        }
        return (strokes, session.layout.cells)
    }

    /// `--screenshot-select` on the joined path: the window names of the focus page's strokes.
    static func windowSelection(_ ids: [String], focusPageId: String) -> [String] {
        ids.map { SpanName.prefixed(id: $0, page: focusPageId) }
    }

    // MARK: The sheet over the canvas (§2 table 2, C3-M3)

    /// `isSheetOpen` of the window's canvas (§3.6: no shift under a sheet): any sheet, the account question, the
    /// save-failure alert, or screenshot mode's hold of a shift.
    static func canvasSheetOpen(sheetIsUp: Bool, accountQuestion: Bool, saveFailed: Bool, shiftHeld: Bool) -> Bool {
        sheetIsUp || accountQuestion || saveFailed || shiftHeld
    }

    /// Whether the converted strokes of a request are erased after the event was made: on the one-page path while its page
    /// is still shown (1.2.3), on the joined path while the window that named them is still the screen's (the names are
    /// window names, HANDOFF 9).
    static func erasesConverted(requestPageId: String, requestSessionId: String?, shownPageId: String, sessionId: String?) -> Bool {
        if let requestSessionId {
            return requestSessionId == sessionId
        }
        return requestPageId == shownPageId
    }
}
