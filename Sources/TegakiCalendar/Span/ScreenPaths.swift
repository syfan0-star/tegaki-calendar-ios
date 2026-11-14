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
// Screenshot mode's joined pages (§3.12; C3-B1, C3-M4; the plan §4.2–§4.4, §7.3): `--screenshot-span on` opens the joined
// path (its own switch, off by default), the window's pages are the demo pages with the crossing demo,
// `--screenshot-single-page` stays on one page with the focus page's halves, `--screenshot-offset-x` /
// `--screenshot-span-shift` place the band, the shift is held until `span.release`, and `span.state` reads out the window.
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
        /// The kind is joined but 「消して始める」 waits for the engine (H2, the plan §4.4): the desk, until the page is read
        /// again after the answer (`reloadShown`).
        case erasing
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
        /// Zoomed in: bring this rect (band lu) on screen (`revealRect`).
        case reveal(CGRect)
        /// Today's page is the focus at the overview: nothing moves (1.2.3's 「今日」 on the page shown; review J7 — the
        /// screen does not know the paper's y, and a rect a whole page high would take the paper to its top).
        case stay
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
    /// Screenshot mode's arguments (`ScreenshotMode.current`; nil in normal use): the joined pages' arguments of §3.12
    /// — the window's demo pages and the crossing demo, `--screenshot-single-page`, `--screenshot-span-shift`'s hold and
    /// the element `span.state` — are read from here. Without those arguments nothing here differs from 1.2.3's photos.
    let shot: ScreenshotMode.Config?
    /// The events of a window page (`EventStoreModel.events(from:to:)`), given to every session opened.
    var eventSource: ((DayKey, DayKey) -> [LayoutEvent])?
    /// This device's setting 「前後のページを横につなげる」 (`AppSettings.pageSpan`).
    var settingOn: () -> Bool
    /// Screenshot mode's own setting (memory only, the plan §5.1): off unless `--screenshot-span on`
    /// (`ScreenshotMode.pageSpanAtLaunch`), so the photos stay 1.2.3's; then what 設定 › ページ was switched to
    /// (`ScreenshotMode.pageSpan`, which the screen copies here when the switch tells it).
    var screenshotSpan: Bool
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
    /// The one page opens coming from another path (review J5): its canvas is made anew even on the same page id, so the
    /// screen's last viewport of the one page (from before the window) is not its first frame's.
    var onOnePageAnew: (() -> Void)?
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
    /// 「全て消す」 runs and the engine has not removed the files yet: a window opened meanwhile reads empty pages (§4.4).
    /// It ends when the engine's `eraseEverything` removed them (review J4: its first part, before its first `await`, empties
    /// the store and marks the iCloud part pending; a page read after that is one written after the erase) or returned
    /// (`eraseDidFinish()`).
    private(set) var erasingStore = false
    /// `sync.state.pendingCloudErase` as 「全て消す」 began: when it was false, its turning true tells that the engine's
    /// `eraseEverything` removed the files (its `store.removeAll()` and `resetAfterErase(cloudPending: true)` come in one
    /// turn). When it was already true (an earlier erase's iCloud part still waits), the pages read empty until the end.
    private var cloudErasePendingAtErase = true
    /// A joined page waits for the window scene (`Opened.waiting`).
    private(set) var waitingForScene = false
    /// 「消して始める」 waits for the engine (H2): from before its `await` until the answer came back, a joined page opens
    /// no window (`Opened.erasing`, the desk), as the one page saves nothing then (`OnePageSession.beginEraseAndStart`).
    /// A stroke written meanwhile would otherwise be saved and sent to the new account; the one page drops it at the
    /// reload (wave A's decision 2), and the window's pages are read only after the answer (`reloadShown`).
    private(set) var eraseAndStartWaits = false
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

    // MARK: Screenshot mode's joined pages (§3.12; the lead's decisions C3-M4, C3-B1; the plan §4.2, §4.3)

    /// `--screenshot-span-shift` (C3-M4): the window's canvas is told a sheet is up (`canvasSheetOpen`), so it does not
    /// shift, from the first window until the UI test taps `span.release` (`releaseShift()`) or `shiftHoldCeiling` passed.
    @Published private(set) var shiftHeld = false
    /// The element `span.state` is on screen (`reportsState`): its counts below draw the screen again when they move.
    let reportsShotState: Bool
    /// The window's shifts so far (the versions whose first page moved; `span.state`'s `shifts=`).
    private(set) var shifts = 0
    /// The window's stops so far (`onSpanStop`; `span.state`'s `stops=`).
    private(set) var stops = 0
    /// The kind of the page on the screen (`span.state`'s `kind=` on the one-page path).
    private(set) var shownKind: PageKind?
    private var composedFirstIndex: Int?
    private var shiftHoldDone = false
    private var shiftHoldTimer: Task<Void, Never>?

    /// The safety ceiling of `--screenshot-span-shift`'s hold (C3-M4): a UI test that never taps `span.release` does not
    /// leave the window unshiftable for the rest of the run.
    static let shiftHoldCeiling: TimeInterval = 60
    /// The invisible element of the window's state for the UI tests and the photos (the plan §4.3).
    static let stateIdentifier = "span.state"
    /// The invisible element a UI test taps to release `--screenshot-span-shift`'s hold (C3-M4).
    static let releaseIdentifier = "span.release"

    init(sync: SyncEngine, onePage: OnePageSession, screenshot: Bool = ScreenshotMode.isActive,
         shot: ScreenshotMode.Config? = ScreenshotMode.current,
         settingOn: @escaping () -> Bool = { AppSettings.pageSpan }, defaults: UserDefaults = .standard,
         sleep: @escaping @MainActor (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
         clock: @escaping () -> Date = Date.init) {
        self.sync = sync
        self.onePage = onePage
        self.screenshot = screenshot
        self.shot = screenshot ? shot : nil
        self.settingOn = settingOn
        self.defaults = defaults
        self.sleep = sleep
        self.clock = clock
        screenshotSpan = screenshot && ScreenshotMode.pageSpanAtLaunch(shot)
        reportsShotState = screenshot && Self.reportsState(shot)
        engineWentToBackground = { [sync] in sync.applicationDidEnterBackground() }
    }

    // MARK: The one place that decides the path (§5.1)

    /// Whether a page of `kind` opens joined (D2, §3.1, §3.15, the plan §5.1): only a week or a day, with the setting on
    /// (in screenshot mode its own memory-only setting, off by default, and never with `--screenshot-single-page`, the
    /// old versions' view), and not a kind that fell back to one page in this run. Month and year are always one page
    /// in 1.3.
    static func joins(kind: PageKind, setting: Bool, screenshot: Bool, screenshotSpan: Bool, singlePage: Bool = false,
                      fallenBack: Set<PageKind>) -> Bool {
        guard kind == .week || kind == .day, !fallenBack.contains(kind) else { return false }
        return screenshot ? screenshotSpan && !singlePage : setting
    }

    /// The device of a window (C3-m11): an iPad by the idiom; the class and the orientation from the screen of the window's
    /// scene (`screen.bounds`, interface-oriented: the source the canvas decides its window anew from, so in Split View or
    /// Stage Manager the class is the device's and the orientation the screen's, not the window's; review J6, the plan
    /// §6 #11, §7.3); nil until the window is laid out (`windowSize`, the root view's size with its safe area) and its
    /// scene is there.
    static func device(isPad: Bool, windowSize: CGSize, screen: CGSize?) -> Device? {
        guard windowSize.width.isFinite, windowSize.height.isFinite, windowSize.width > 0, windowSize.height > 0,
              let screen, screen.width.isFinite, screen.height.isFinite, screen.width > 0, screen.height > 0 else { return nil }
        return Device(deviceClass: SpanDeviceClass(screen: windowSize, isPad: isPad), orientation: SpanOrientation(screen: windowSize)) // MUTATION ma (J6)
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
                                singlePage: shot?.singlePage ?? false, fallenBack: fallenBack)
        retire()
        shownKind = o.kind
        waitingForScene = false
        if joined {
            // MUTATION ma (J1): the gate of 「消して始める」's wait is removed.
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
        if path != .onePage {
            // Review J5: the one page comes from another path (the window, the desk), so its canvas is made anew even on
            // the same page id: it starts from `PaperViewport.initial` (the screen forgets the one page's last viewport)
            // and 「メモ欄はここまでです」 may show again, as on another page (1.2.3's `show`).
            // MUTATION ma (J5): nothing forgotten.
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
            // 1.3: `--screenshot-single-page` reads the week's or the day's demo with the halves of the crossing demo
            // the page owns (the old versions' view, §3.12); without it the demo page is 1.2.3's.
            loaded = Self.singlePageDemo(shot, o) ?? ScreenshotMode.demoPage(kind: o.kind, focus: o.focus, weekStart: o.weekStart)
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
                           eventSource: eventSource,
                           loader: { [weak self, sync, kind = o.kind, weekStart = o.weekStart] id in
                               self?.read(id, kind: kind, weekStart: weekStart) ?? sync.load(id)
                           },
                           sleep: sleep, clock: clock)
    }

    /// Where a window's page is read from (§4.4): empty while 「全て消す」 deletes the files, screenshot mode's demo page of
    /// the window (`windowDemo`; its engine returns empty pages), else the engine.
    private func read(_ pageId: String, kind: PageKind, weekStart: WeekStart) -> InkPage {
        if erasingStore { return InkPage(pageId: pageId) } // MUTATION ma (J4): empty until eraseDidFinish
        if let shot { return Self.windowDemo(shot, pageId: pageId, kind: kind, weekStart: weekStart) }
        return sync.load(pageId)
    }

    /// Screenshot mode's page `pageId` of a window (§3.12, B_DESIGN.md §5.6): `ScreenshotMode.spanDemoPage` around the
    /// photos' day (`shot.focus`, not the window's focus now: a page has the same strokes wherever the window moves),
    /// the focus page the one-page demo, a neighbour the same demo with ids of its own, the crossing demo with
    /// `--screenshot-span on` (`Config.crossingDemo`).
    static func windowDemo(_ shot: ScreenshotMode.Config, pageId: String, kind: PageKind, weekStart: WeekStart) -> InkPage {
        ScreenshotMode.spanDemoPage(pageId: pageId, kind: kind, focus: shot.focus, weekStart: weekStart, crossing: shot.crossingDemo,
                                    grown: shot.grown, empty: shot.empty, tallYear: shot.tallYear, storeInk: shot.storeInk)
    }

    /// `--screenshot-single-page` (§3.12, the old versions' view): the week's or the day's page of the one-page path with
    /// the halves of the crossing demo it owns (its line runs off its left edge, nothing comes in from the left page).
    /// nil without the argument, for a month or a year, and in normal use: the one-page path reads 1.2.3's demo page.
    static func singlePageDemo(_ shot: ScreenshotMode.Config?, _ o: Opening) -> InkPage? {
        guard let shot, shot.singlePage, o.kind == .week || o.kind == .day else { return nil }
        return ScreenshotMode.spanDemoPage(pageId: PageNavigation.pageId(o.kind, focus: o.focus, weekStart: o.weekStart), kind: o.kind,
                                           focus: shot.focus, weekStart: o.weekStart, crossing: true,
                                           grown: shot.grown, empty: shot.empty, tallYear: shot.tallYear, storeInk: shot.storeInk)
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
        shifts = 0
        stops = 0
        composedFirstIndex = nil
        session.onSaveFailed = { [weak self] _ in self?.saveFailed("") }
        session.onOwnInk = { [weak self] at in
            self?.onOwnInk?(at)
            self?.shotStateChanged()
        }
        watches = [
            session.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() },
            // `@Published` tells before the value is set; `compose` sets `layout` before `windowVersion`, so the layout
            // read here is the new version's.
            session.$windowVersion.sink { [weak self, weak session] version in
                guard let self, let session else { return }
                self.countShift(session)
                self.windowComposed(session, version: version)
            },
        ]
        holdShiftIfAsked()
    }

    // MARK: Screenshot mode's shift hold and state (C3-M4, the plan §4.2, §4.3)

    /// `--screenshot-span-shift` (C3-M4): the first window holds its shift (the canvas sees a sheet) until `releaseShift()`
    /// — the UI test's tap on `span.release` after its photo "before" — or until `shiftHoldCeiling` passed (through the
    /// injected `sleep`). Once released, no later window holds. Nothing without the argument.
    private func holdShiftIfAsked() {
        guard shot?.spanShift == true, !shiftHoldDone, !shiftHeld else { return }
        shiftHeld = true
        NSLog("%@", "span shot: hold")
        let sleep = self.sleep
        shiftHoldTimer = Task { @MainActor [weak self] in
            await sleep(Self.shiftHoldCeiling)
            guard !Task.isCancelled else { return }
            self?.endShiftHold(by: "timer")
        }
    }

    /// The UI test tapped `span.release` (C3-M4): the canvas may shift now (it checks as a sheet closes).
    func releaseShift() {
        endShiftHold(by: "tap")
    }

    private func endShiftHold(by cause: String) {
        guard shiftHeld else { return }
        shiftHoldDone = true
        shiftHeld = false
        shiftHoldTimer?.cancel()
        shiftHoldTimer = nil
        NSLog("%@", "span shot: released (\(cause))")
    }

    /// A version whose first page moved is a shift (or a decision anew) of the window: `span.state`'s `shifts=`.
    private func countShift(_ session: SpanSession) {
        guard session === span else { return }
        let first = session.layout.firstIndex
        if let last = composedFirstIndex, last != first { shifts += 1 }
        composedFirstIndex = first
    }

    /// The element `span.state` reads what changed without a published value (the window's own ink, a stop).
    private func shotStateChanged() {
        guard reportsShotState else { return }
        objectWillChange.send()
    }

    /// Whether screenshot mode shows `span.state` (the plan §4.3): with the joined pages' arguments only
    /// (`--screenshot-span on|off`, `--screenshot-single-page`, `--screenshot-span-shift`), never with 1.2.3's arguments
    /// alone, so the accessibility tree of 1.2.3's UI tests and photos is what it was.
    static func reportsState(_ shot: ScreenshotMode.Config?) -> Bool {
        guard let shot else { return false }
        return shot.span != nil || shot.singlePage || shot.spanShift
    }

    /// The value of `span.state` (the plan §4.3): `path=span|one|erasing;session=<id>;kind=<kind>;focus=<page id>;
    /// origin=<lu>;first=<page id>;pages=<n>;version=<windowVersion>;shifts=<n>;stops=<n>;hold=on|off;last=<page>:<cell>:
    /// minx=<lu>:maxx=<lu>` — the focus page's left edge in the band (0 on one page), the window's first page and its
    /// pages, and the newest stroke of the pages on the screen (its x range in its own cell, as the store keeps it; `-`
    /// when none). `-` stands for what the path does not have.
    var stateLabel: String {
        let pathName: String
        var session = "-", focus = "-", first = "-"
        var origin: CGFloat = 0
        var pages: [InkPage] = []
        var version = 0
        switch path {
        case .joined:
            pathName = "span"
            if let window = span {
                session = window.id
                focus = window.focusPageId
                origin = window.origin(ofPage: window.focusPageId) ?? 0
                first = window.pageIds.first ?? "-"
                pages = window.pageIds.compactMap { window.page($0) }
                version = window.windowVersion
            }
        case .onePage:
            pathName = "one"
            focus = onePage.page.pageId
            first = focus
            pages = [onePage.page]
        case .erasing:
            pathName = "erasing"
        }
        return [
            "path=\(pathName)",
            "session=\(session)",
            "kind=\(span?.kind.rawValue ?? shownKind?.rawValue ?? "-")",
            "focus=\(focus)",
            "origin=\(Self.stateNumber(origin))",
            "first=\(first)",
            "pages=\(path == .joined ? span?.pageIds.count ?? 0 : path == .onePage ? 1 : 0)",
            "version=\(version)",
            "shifts=\(path == .joined ? shifts : 0)",
            "stops=\(path == .joined ? stops : 0)",
            "hold=\(shiftHeld ? "on" : "off")",
            "last=\(Self.newestStroke(in: pages))",
        ].joined(separator: ";")
    }

    /// `<page>:<cell>:minx=<lu>:maxx=<lu>` of the newest live stroke of `pages` (the largest `t`, then the largest id), or `-`.
    static func newestStroke(in pages: [InkPage]) -> String {
        var newest: (pageId: String, stroke: InkStroke)?
        for page in pages {
            for stroke in page.liveStrokes {
                guard let shown = newest else {
                    newest = (page.pageId, stroke)
                    continue
                }
                if stroke.t > shown.stroke.t || (stroke.t == shown.stroke.t && stroke.id > shown.stroke.id) {
                    newest = (page.pageId, stroke)
                }
            }
        }
        guard let newest, let minX = newest.stroke.points.map(\.x).min(), let maxX = newest.stroke.points.map(\.x).max() else { return "-" }
        return "\(newest.pageId):\(newest.stroke.cell.raw):minx=\(stateNumber(minX)):maxx=\(stateNumber(maxX))"
    }

    private static func stateNumber(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
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
    /// until the engine removed the files (its task, on a later turn) or `eraseDidFinish()` (`erasingStore`).
    func eraseAll(reopen o: Opening?) {
        onePage.eraseAll()
        for c in closing {
            c.session.cancelAll()
        }
        closing = []
        erasingStore = !screenshot
        cloudErasePendingAtErase = sync.state.pendingCloudErase
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
    /// can reach the new one's store; until the answer a joined page opens no window (`eraseAndStartWaits`: another page,
    /// the kind, 「今日」 show the desk, H2); after the answer the page is read again (`reload`, a new window on the joined
    /// path) and the one page saves again. `closed` is the screen's part right after closing (the selection, the viewport,
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
            eraseAndStartWaits = true
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
            // The answer came back: the page read again below opens its window (H2).
            self?.eraseAndStartWaits = false
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
    /// identity of the canvas it is made for (`base` and the number now), and a write is taken only while that is the
    /// identity of now — the screen's base read when the write comes in (`currentBase`, as r13's 1c5eb0a read
    /// `canvasBase` in the setter: a switch of the week start moves the base of a month or a day page whose id stays) —
    /// so a canvas made before a rebuild (H1–H3) or a week start switch writes nothing (`OnePageSession.canvasWrote`);
    /// a write taken is the person's own ink (`ownInk`, 1.2.1).
    func pageBinding(base: String, currentBase: @escaping () -> String,
                     ownInk: @escaping () -> Void) -> (get: () -> InkPage, set: (InkPage) -> Void) {
        let one = onePage
        let madeFor = one.canvasIdentity(base: base)
        return (get: { one.page }, set: { newValue in
            guard one.canvasWrote(newValue, madeFor: madeFor, base: base) else { return } // MUTATION ma (T1)
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
    /// today's page already the focus at the overview → nothing (1.2.3: the same page does not move; review J7); zoomed in
    /// → bring today's column on screen from an hour before now. `viewport` is the last one reported (nil: `ratio`, the
    /// stored one), `area` the paper area. nil off the joined path.
    func today(_ day: DayKey, now: Date, viewport: PaperViewport?, area: CGSize, ratio: CGFloat) -> Today? {
        guard path == .joined, let session = span else { return nil }
        switch session.today(day) {
        case .reopen(let focus):
            return .reopen(focus)
        case .slide(let pages):
            let zoomed = Self.zoomedIn(layout: session.layout, viewport: viewport, area: area, ratio: ratio)
            if pages != 0, !zoomed { return .slide(pages) } // MUTATION ma (J7)
            let shown = viewport.flatMap { $0.width > 0 ? $0 : nil }
                ?? Self.bandViewport(layout: session.layout, focusPageId: session.focusPageId, now: now,
                                     calendar: session.context.calendar, area: area, ratio: ratio)
            guard let rect = Self.todayRect(layout: session.layout, pageId: session.plan.pageId(at: session.plan.index(containing: day)),
                                            now: now, calendar: session.context.calendar, viewport: shown, area: area)
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

    /// The rect (band lu) 「今日」 reveals on `pageId` zoomed in (§4.1): today's column (the week's, or the day page's width)
    /// from an hour before now, one screen high.
    static func todayRect(layout: SpanLayout, pageId: String, now: Date, calendar: Calendar, viewport: PaperViewport,
                          area: CGSize) -> CGRect? {
        guard let slot = layout.slot(ofPage: pageId), viewport.zoom > 0, viewport.width > 0 else { return nil }
        let page = layout.pages[slot]
        let origin = layout.origin(ofSlot: slot)
        let zoom = viewport.zoom
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
    /// switch, as at `show`, after `focusMoved` told the screen its new focus); once the window's pages are read (none of
    /// them a placeholder: a shift's pages are read after its stop), a window over the cap falls back to one page.
    func stopped(_ stop: SpanSession.Stop, focus: DayKey, kind: PageKind, weekStart: WeekStart, focusMoved: (DayKey) -> Void = { _ in },
                 boundary: () -> Void) -> Stopped {
        stops += 1
        shotStateChanged()
        let next = Self.focus(focus, kind: kind, weekStart: weekStart, movedTo: stop.focusDay)
        Self.remember(kind: kind, focus: next, screenshot: screenshot, defaults: defaults)
        focusMoved(next)
        if stop.ended != nil {
            saveCurrent()
            boundary()
        }
        var heavy = false
        // C3-m6: only on the reads' count — after the window's pages were read (its version moved since it opened, and no
        // page that came in with a shift is still a placeholder estimated from its file; review J3).
        if let session = span, session.fallsBackToOnePage, session.windowVersion != openedVersion { // MUTATION ma (J3)
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

    /// The canvas's `initialPaperOffset` of a window in screenshot mode (band lu; §3.12, the plan §7.3): with `pages`
    /// (`Config.spanOpeningOffsetX`: `--screenshot-offset-x`, else +1 with `--screenshot-span-shift`) the band x
    /// `origin(focus) + W/2 + pages·W` is in the middle of the canvas `viewportWidth` wide at `zoom` (the zoom the window
    /// is expected to open at; −0.5 puts the focus page's left boundary in the middle), y `--screenshot-offset`'s or 0;
    /// else `--screenshot-offset` with the focus page's origin added; nil without either (the canvas then opens the focus
    /// page in the middle). The canvas clamps it to the band.
    static func shotPaperOffset(layout: SpanLayout, focusPageId: String, pages: CGFloat?, offset: CGPoint?,
                                viewportWidth: CGFloat, zoom: CGFloat) -> CGPoint? {
        guard let pages, pages.isFinite, let slot = layout.slot(ofPage: focusPageId) else {
            return offset.map { bandPoint($0, layout: layout, focusPageId: focusPageId) }
        }
        let width = layout.plan.pageWidth
        let centre = layout.origin(ofSlot: slot) + width / 2 + pages * width
        let half = viewportWidth.isFinite && viewportWidth > 0 && zoom.isFinite && zoom > 0 ? viewportWidth / 2 / zoom : 0
        return CGPoint(x: centre - half, y: offset?.y ?? 0)
    }

    // MARK: Screenshot mode's guide (§3.12, §3.14)

    /// Screenshot mode's `--screenshot-span-guide` (§3.12, §3.14, the plan §4.4): the first-time guide's card of a joined
    /// week or day for its photo (`SpanGuideModel.showForPhoto`, 「指でも書く」 off for `one`, on for `two`, as it is for
    /// no value), or stage 2's notice (N-8) for `stage-two`; nil without the argument (and no card for a month or a year).
    enum PhotoGuide: Equatable {
        case card(allowFinger: Bool)
        case stageTwoNotice
    }

    /// When the first-time guide's card may come up (§3.14, review J2): nothing over the paper and nothing on its way —
    /// no sheet, not the first launch's paywall that is about to come (`firstPaywallPending`), not the account question up
    /// or waiting for a sheet to close — as the pinch hint waits (1.1.1). Else the card is recorded as shown and goes a
    /// moment later under the sheet, or stays its 8 seconds under the question, and never comes again.
    static func guideMayShow(sheetIsUp: Bool, firstPaywallPending: Bool, accountQuestion: Bool, accountChangePending: Bool) -> Bool {
        !sheetIsUp // MUTATION ma (J2)
    }

    static func photoGuide(_ shot: ScreenshotMode.Config?, kind: PageKind, allowFinger: Bool) -> PhotoGuide? {
        guard let guide = shot?.spanGuide else { return nil }
        if guide == .stageTwo { return .stageTwoNotice }
        guard SpanGuide.text(kind: kind, allowFinger: allowFinger) != nil else { return nil }
        return .card(allowFinger: guide.allowFinger(current: allowFinger))
    }

    // MARK: The band's lu, continued

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
