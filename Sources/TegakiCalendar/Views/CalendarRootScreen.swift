import Access
import Holidays
import InkModel
import Layout
import SwiftUI
import UIKit

/// One request to show the event sheet (M3b contract §4.5).
struct EventEditorRequest: Identifiable {
    let id = UUID()
    var mode: EventEditorMode
    var draft: EventDraft
    var calendars: [CalendarOption]
    var snapshot: UIImage?
    /// The lasso-selected strokes the event is made from (「予定にする」); empty otherwise.
    var inkIds: [String]
    /// The page the strokes belong to (they are erased only while that page is still shown).
    var pageId: String
}

/// The operations the subscription gates (M5_CONTRACT §3.1, D3): the first eleven stop while the
/// app is read only (a paywall once per session, then a toast); the other eight are always allowed
/// (`export` is M6's handwriting export, which read only allows too, M5-27 / M6_CONTRACT D1).
enum GatedAction: Equatable, CaseIterable {
    case draw, erase, moveSelection, deleteSelection, convertSelection, createEvent, editEvent, deleteEvent,
         undoRedo, overlayTool, webImport,                       // 止める（11）
         eraseAll, settings, navigate, zoom, receiveCloud, viewEvent, pencilToggle,   // 許す
         export                                                   // 許す（手書きの書き出し。M5-27、M6）。許す = 8、全部で 19

    /// Stops while the app is read only.
    var isGated: Bool {
        switch self {
        case .draw, .erase, .moveSelection, .deleteSelection, .convertSelection, .createEvent, .editEvent, .deleteEvent,
             .undoRedo, .overlayTool, .webImport:
            return true
        case .eraseAll, .settings, .navigate, .zoom, .receiveCloud, .viewEvent, .pencilToggle, .export:
            return false
        }
    }
}

/// The app's one screen (M3a contract §4.1, M3b §4.5, M4 §5.3–§6.4, M4B §2.6 / §3.3 / §5 / §6.4):
/// the header (◀ ▶, the title, the 日/週/月/年 switch, 今日, ＋予定, ☁ sync state, ⚙), the sticky
/// heading of the page, the fixed all-day band of the week / day page (`AllDayBandView`), the paper
/// with the PencilKit canvas (`InkCanvasView`, 担当 I) and the lasso menu floating over it, the
/// toolbar, the toast, and the sheets (event create / edit / view, settings, the web import's file
/// picker and progress sheet, the export sheet, the iCloud account question).
///
/// Export (M6, M6_CONTRACT §3.3): 設定 › データ › 「手書きを書き出す」 saves the shown page, closes the
/// settings and opens `ExportSheet` (`exportPhase`); a choice runs `ExportBuilder` (the JSON of every
/// stored page with its progress, or the PDF of the shown page) and the sheet ends on `.done` with a
/// `ShareLink`, or on `.failed` whose text becomes an error toast after 「閉じる」. Allowed while read
/// only. The import door (`runImport`) takes the app's own data file as well as the web export since
/// M6 (`InkImport`), and says which one it took.
///
/// Flow: `(kind, focus)` is chosen → `saveNow()` → `SyncEngine.load(pageId)` (+ `pageOpened`, which
/// fetches that one page from iCloud) → `BandMigration.migrate` (M4b: the week / day band's
/// handwriting moves onto the grid; a page that changed is saved again) → `EventStoreModel.load
/// (kind:focus:)` → the page's layout engine → `InkCanvasView(...).id(pageId)`. Ink changes are
/// saved through `SyncEngine.save` 1.5 s after the last one, before leaving the page, and when the
/// app goes to the background (the engine writes the file and sends it to iCloud 1.5 s later).
/// Events changing or the ink growing past a cell's bottom re-run the layout with fresh
/// `inkBottoms`. On the week and day pages a 30 s tick moves the now line.
///
/// Horizontal scrolling (M4b): the canvas reports its horizontal offset, zoom and width through
/// `onViewportChange` (`PaperViewport`); the sticky header and the band are placed with it, so
/// their columns stay over the paper's. Until the first report, `PaperViewport.initial` stands in.
/// The first horizontal position of a zoomed-in page is `PageNavigation.initialScrollX` (today's
/// column on the month / week page, this month's column on the year page). The compact header
/// (< 600 pt) shows `PageNavigation.compactTitle`.
///
/// Overview and zoom (M4c, M4C contract §5.1; 1.1.1, docs/R1_1_1.md): a page opens at the ratio stored
/// for its kind (`AppSettings.zoomRatio(for:)`, D4; 1 = the opening zoom `Bounds.open`, or
/// `--screenshot-zoom`), so what a page holds never changes the size it opens at, and the
/// canvas reports the ratio at the end of every pinch (`onZoomRatioChange`), which is the only time
/// it is written. The first frame's stand-in viewport is `PaperViewport.initial(_:overview:paperSize:
/// viewport:ratio:)` over the paper area measured under the band (`paperArea`; the width alone until
/// it is measured). While a pinch is in progress (`onZoomingChange`) the band's lane height is frozen
/// at the zoom the pinch started from (`frozenLaneZoom`, M4C-27). A finger double tap on the week /
/// month / year canvas (`onDoubleTap` → `layout.dayAt(point:)`) or on a week band column goes to
/// that day's page (D5); the day page ignores it.
///
/// Sync (M4): a page the engine changed from iCloud (a pull, a push conflict, an import) arrives
/// through `onRemoteUpdate` and is merged into the shown page without touching the canvas history
/// (`applyRemote`). Erasing everything and importing go through the engine. When another iCloud
/// account signs in, the engine stops with `.accountMismatch` and this screen asks (§6.4).
///
/// Events (M3b): the 予定 tool's drag or tap, 「＋予定」 and the lasso's 「予定にする」 open the create
/// sheet with the range `layout.eventRange(for:now:)` produced; a finger tap or a 予定-tool tap on a
/// bar / chip / box opens the edit sheet (read-only for a calendar that cannot be modified). The
/// sheet's `onSubmit` writes through `EventStoreModel`; a throw stays in the sheet, success closes it
/// and shows a toast. Converting handwriting erases the strokes afterwards when the sheet's
/// 「この手書きを消す」 is on (one undoable canvas command).
///
/// Subscription (M5, M5_CONTRACT §3 / §4.2): `store.snapshot.access` decides whether the app is read
/// only. The gated operations (`GatedAction`, `isAllowed`) are guarded at their entry points: the
/// canvas stops drawing and reports a Pencil touch (`onBlockedInput`), the lasso / 予定 tool cannot
/// be chosen, undo / redo are greyed, 「＋予定」 / the event tool / the editor's save and delete / the
/// web import are refused. The first refused operation of a session shows the paywall, later ones a
/// toast (`blocked`). The header shows the 「閲覧専用」 badge (a compact iPhone a notice row instead),
/// the paywall also opens after the onboarding once the first refresh confirmed there is no
/// subscription (`scheduleFirstLaunchPaywall`, M5-33), from 設定 › 購入 and from the badge. Every
/// return to the foreground refreshes the store (M5-9).
///
/// 1.1 (docs/M7A_CONTRACT.md §2.7, §3.7, §4.5, §5.2):
/// - The app starts with the remembered pen (`ToolbarPalette.rememberedPen`, 0-13).
/// - The toolbar has three states (`toolbarMode`, `ToolbarLogic`):
///   - `expanded`: the bar in the bottom safe-area inset, with 「しまう」.
///   - `collapsed`: the round `ToolbarDock` in a bottom corner, laid over the paper.
///   - `peek`: the bar laid over the paper; a pen-down folds it again.
///   The inset modifier always stays; only its content and `spacing` follow the state (the canvas
///   keeps its identity). While the dock shows, the canvas keeps 60 pt free at the bottom and the
///   toasts sit above the dock.
/// - The toolbar's eraser returns to the last pen or marker after it erased (`eraseEnded`,
///   `ToolbarLogic.toolAfterErase`).
/// - A finger's single tap follows `DateTap.target` with 「指でも書く」 and this month; the year's
///   gutter numbers open this month's day.
/// - 24:00 and below on the day page refuses a new event (`newEventPlan`).
/// - The canvas's stroke budget and the memo area's limit become toasts: once per page per device,
///   at most every 2 s, once per opened page.
/// - An import that takes a page past 20,000 strokes asks first (`WebImportPhase.confirmLarge`).
///
/// 1.1.1 (docs/R1_1_1.md):
/// - 「今日」 brings today's cell on screen on the month and year pages (`revealRect`, `revealTrigger`,
///   `PageNavigation.todayRect`); a page opened any other way starts at the top.
/// - The one-time hint that two fingers zoom (`schedulePinchHint`).
///
/// 1.2 (docs/M7B_CONTRACT.md §5.6, §10.3–§10.5):
/// - Holidays: the first launch's `HolidayChoice.migrateIfNeeded`, one calendar (`holidays` in the body,
///   `HolidayChoice.current` elsewhere), `makePaper` builds a paper from the one it is given.
/// - The week start: `@State weekStart`, not the record, makes the page id and the paper, so a switch
///   saves the old page in its old form first (`weekStartSwitch`). The canvas's identity has it too.
/// - After the first pull the pages are compared with an automatic week start once (`runWeekStartCheck`);
///   it never switches under a pen.
/// - Its toasts wait for any sheet (`WeekStartNotices`).
///
/// 1.2.1 (docs/R1_2_1.md §2): the App Store rating prompt, rarely and at a calm moment. ◀ ▶ from a page
/// the person wrote on (`move(by:)`), then 2 s of stillness on the new page, and only when `ReviewPrompt`
/// says it is due (3 days of ink, 7 days of use, once per version, 90 days apart, subscribed or in the
/// trial) and nothing is up (`reviewCanShowNow`). Never in screenshot mode, the XCTest host or a
/// sandbox-receipt build (`reviewAllowedHere`); StoreKit is asked through `ReviewRequester`.
struct CalendarRootScreen: View {
    @StateObject private var model = EventStoreModel()
    /// The sync engine (M4 contract §5.3): the one store of the pages, and the ☁ state.
    @ObservedObject private var sync = SyncEngine.shared
    /// The subscription (M5 contract §2.3, M5-22): the live StoreKit model, or the screenshot mode's
    /// demo (`--screenshot-readonly` picks the unsubscribed sample; M5-34: this screen passes it).
    @StateObject private var store = StoreModel.make(screenshotReadOnly: ScreenshotMode.current?.readOnly ?? false)
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var kind: PageKind
    @State private var focus: DayKey
    @State private var page: InkPage
    /// The page's geometry and paper content (one value: the layout is `paper.layout`).
    @State private var paper: PaperContent
    /// The instant the layout was last computed for (fixed in screenshot mode).
    @State private var now: Date
    @State private var tool: CanvasTool
    /// The last pen / marker, so the Pencil's double tap can go back to it from the eraser (and, in
    /// 1.1, the toolbar's eraser after it erased). Set in `init`: the remembered pen (0-13).
    @State private var lastInkTool: CanvasTool
    /// 1.1 (§2.4): where the current eraser came from — the toolbar's returns to `lastInkTool` after
    /// it erased, the Pencil's does not. nil until an eraser is chosen.
    @State private var eraserOrigin: EraserOrigin?
    @State private var undoTrigger = 0
    @State private var redoTrigger = 0
    @State private var canUndo = false
    @State private var canRedo = false

    @AppStorage(AppSettings.allowFingerKey) private var allowFinger = false
    @AppStorage(AppSettings.allowFingerChosenKey) private var allowFingerChosen = false
    @AppStorage(AppSettings.onboardingDoneKey) private var onboardingDone = false
    @State private var showOnboarding = false

    // 1.1 (M7A_CONTRACT §2.3 / §2.7): the toolbar's state and its memories (per device; never read
    // or written in screenshot mode, where `--screenshot-toolbar` decides).
    @AppStorage(AppSettings.toolbarCollapsedKey) private var toolbarCollapsedStored = false
    @AppStorage(AppSettings.toolbarEdgeKey) private var toolbarEdgeRaw = ToolbarEdge.leading.rawValue
    /// 設定 › 入力 「消しゴムで消したらペンに戻る」 (the same key as the settings, so a change applies at once).
    @AppStorage(AppSettings.eraserAutoReturnKey) private var eraserAutoReturn = true
    /// expanded / collapsed / peek (§2.1). Set in `init` from the stored `toolbar.collapsed`.
    @State private var toolbarMode: ToolbarMode
    /// Screenshot mode's corner of the dock button (`--screenshot-toolbar collapsed-right`); nil in
    /// normal use, where `toolbarEdgeRaw` decides.
    @State private var screenshotEdge: ToolbarEdge?
    /// The page whose 「メモ欄はここまでです」 was shown while it is open (§3.4); nil after a page change.
    @State private var capNoticedPageId: String?
    /// The last 「このページはいっぱいです」 toast (at most every 2 s, like `lastBlockedInputAt`).
    @State private var lastBudgetFullAt: Date?

    // 1.1.1 (docs/R1_1_1.md): 「今日」 and the pinch hint.
    /// What 「今日」 asks the canvas to bring on screen (paper lu); nil after any other way to a page.
    @State private var revealRect: CGRect?
    /// Bumped by 「今日」: the canvas already showing the page brings `revealRect` on screen once.
    @State private var revealTrigger = 0
    /// The hint was shown or the person pinched (per device; never written in screenshot mode).
    @AppStorage(AppSettings.pinchHintShownKey) private var pinchHintShown = false
    /// The hint's wait (`schedulePinchHint`); a newer schedule or a pinch stops it.
    @State private var pinchHintTask: Task<Void, Never>?

    // 1.2.1 (docs/R1_2_1.md §2.4): the rating prompt. Nothing but `reviewRequestTrigger` is read in the body,
    // so the others never draw the screen again.
    /// Bumped when StoreKit is asked for the rating prompt (`ReviewRequester`).
    @State private var reviewRequestTrigger = 0
    /// The pause on the new page (`scheduleReviewRequest`); a pen, a writing finger, a pinch, a finger's tap
    /// on the paper, a tool chosen on the bar, another page or the app going away stops it. A finger that
    /// only scrolls does not (the canvas does not report it; docs/R1_2_1.md §9.2).
    @State private var reviewTask: Task<Void, Never>?
    /// The person's own ink changed on the page while it has been open (`pageBinding`).
    @State private var inkChangedThisVisit = false
    /// When it last changed; nil on a page not written on since it opened.
    @State private var lastInkChangeAt: Date?
    /// When the app last came to the front (the launch, then every `.active`).
    @State private var activeSince = Date()

    // 1.2.2 (docs/R1_2_2.md §3.1, §3.8): the age range. None of these is read in the body.
    /// Apple's age range sheet may be up (`AgeRangeAsker.request`); part of `sheetIsUp`.
    @State private var ageRangeAsking = false
    /// The steps of `askAgeRangeIfDue` while they run.
    @State private var ageRangeTask: Task<Void, Never>?
    /// `scheduleFirstLaunchPaywall` has not decided yet whether the first-launch paywall shows.
    @State private var firstPaywallPending = false
    /// The wait after fresh ink (`askAgeRangeAfterInkIfWriting`).
    @State private var ageRangeInkWait: Task<Void, Never>?
    /// When the pen (or a writing finger) last touched the paper (`penDown`). `lastInkChangeAt` only changes
    /// when a stroke ends, so this keeps the sheet off a stroke that is still being written.
    @State private var ageRangePenDownAt: Date?

    // 1.2 (docs/M7B_CONTRACT.md §5.6, §10): the holidays and the week start.
    /// The holiday setting; its change sets `HolidayChoice.current` and draws the paper again.
    @AppStorage(AppSettings.holidaySettingKey) private var holidaySettingRaw = ""
    /// The week start setting. Nothing but `weekStartSettingChanged` reads it: the page ids come from
    /// `weekStart`, which changes only after the old page is saved (§10.5).
    @AppStorage(AppSettings.weekStartKey) private var weekStartRaw = ""
    /// The week start of the page on the screen.
    @State private var weekStart: WeekStart
    /// The pen touched the paper since launch: no automatic switch until the next page or return (§10.3, 4 (3)).
    @State private var penTouchedThisLaunch = false
    /// The comparison wants to switch but the person is writing: it is made again at the next `show` or `.active`.
    @State private var pendingAdoption = false
    /// The week start's toasts waiting to be seen (§10.4).
    @State private var weekStartNotices = WeekStartNotices()
    @State private var weekStartNoticeTask: Task<Void, Never>?

    // M3b: selection, sheets, commands, toast.
    @State private var selection: InkSelection?
    @State private var editor: EventEditorRequest?
    @State private var command: CanvasCommand?
    @State private var commandTrigger = 0
    @State private var showSettings = false
    @State private var toast: ToastMessage?
    @State private var toastTask: Task<Void, Never>?
    /// Measured size of the lasso menu (a guess until it has been laid out once).
    @State private var menuSize = CGSize(width: 300, height: 44)

    // M4: the web import and the account question.
    @State private var showImportPicker = false
    /// The import sheet is up while this is not nil (M4 contract §6.3).
    @State private var importPhase: WebImportPhase?
    // M6: the export (M6_CONTRACT §3.3).
    /// The export sheet is up while this is not nil (`.choose` → `.building` → `.done` / `.failed`).
    @State private var exportPhase: ExportPhase?
    /// The running export (`runExport`); cancelled if the sheet is closed while building.
    @State private var exportTask: Task<Void, Never>?
    /// 1.1 (§5.2): the file that was read while the sheet asks about its large pages (`confirmLarge`).
    @State private var pendingImport: InkImport.Outcome?
    @State private var showAccountChange = false
    /// The account question arrived while a sheet was up: ask once the sheet has closed.
    @State private var accountChangePending = false

    @State private var saveTask: Task<Void, Never>?
    @State private var pageDirty = false
    @State private var saveError: String?
    @State private var appeared = false

    // M4b: the paper's horizontal offset / zoom for the sticky header and the band, and the one-off
    // landscape request of the CI's iPhone screenshots.
    /// The canvas's last report (`onViewportChange`); `.zero` (width 0) until the first one, when
    /// `PaperViewport.initial` stands in (M4B contract §2.6).
    @State private var viewport = PaperViewport.zero
    /// `--screenshot-landscape`: the orientation was requested once (M4B contract §6.4).
    @State private var landscapeRequested = false

    // M4c: the overview (`fitAll`) needs the paper area's height; the band freezes during a pinch.
    /// The area the paper is shown in (pt): the band-and-canvas area minus the band's height at the
    /// overview (`paperAreaHeight`). `.zero` until measured, when the overview is estimated from the
    /// width alone (M4C contract §5.1, M4C-19).
    @State private var paperArea: CGSize = .zero
    /// The zoom the band's lanes are frozen at while the canvas is zooming (M4C-27); nil otherwise.
    @State private var frozenLaneZoom: CGFloat?

    // M5: the paywall and the read-only mode (M5 contract §3.1, §4.2).
    @State private var showPaywall = false
    @State private var paywallReason: PaywallReason = .settings
    /// A refused operation showed the paywall in this session; the next ones are toasts.
    @State private var blockedPaywallShownThisSession = false
    /// The paywall after the onboarding was shown, or a subscriber was found (M5-33). Stays false when
    /// the first refresh did not finish, the store was unreachable or the prices were missing.
    @AppStorage(AppSettings.paywallShownAfterOnboardingKey) private var paywallShownAfterOnboarding = false
    /// The last Pencil touch the canvas reported while read only (`blocked(.draw)` at most every 2 s).
    @State private var lastBlockedInputAt: Date?

    /// How often the now line is moved (M3a contract §4.1).
    static let nowTickSeconds: Double = 30
    /// Below this width the header takes two rows (M3b contract §4.6).
    static let compactWidth: CGFloat = 600
    /// The pause between two sheets / dialogs (SwiftUI cannot present two at once).
    static let sheetGap: Double = 0.35
    /// The zoom `paperAreaHeight` measures the band at (M4C contract §5.1 / §1.6): every week / day
    /// overview zoom of §1.2 is at most 0.6016, and below 0.667 the lanes (max(22 × zoom, 18)) and
    /// the gaps (max(3 × zoom, 2)) sit at their point minimums, so the band is exactly as tall as at
    /// `fitAll` without knowing the width.
    static let overviewBandZoom: CGFloat = 0.6
    /// M5 (M5_CONTRACT §3.3): the toast of the second and later refused operations of a session.
    static let readOnlyToast = L.text("toast.readOnly")
    /// The compact (iPhone) notice row under the header while read only (§3.2, M5-13).
    static let readOnlyNoticeText = L.text("notice.readOnly.text")
    static let readOnlyNoticeButton = L.text("notice.readOnly.button")
    /// A Pencil touch on the read-only paper is reported at most this often (§3.1).
    static let blockedInputInterval: TimeInterval = 2
    /// How long `scheduleFirstLaunchPaywall` waits for the first refresh (§4.2, M5-33).
    static let firstRefreshTimeout: Double = 3
    /// The screenshot mode's read-only toast stays this long so it is in the photo (§7.5, M5-24).
    static let screenshotReadOnlyToastDuration: TimeInterval = 20

    // 1.1 (M7A_CONTRACT §6.2): the four new toasts.
    /// A new stroke was dropped below the last cell's limit, or reached its last step (§3.4; 3 s, once
    /// while the page is open).
    static let growthCapToast = L.text("toast.growthCap")
    /// The 予定 tool or 「予定にする」 below 24:00 on the day page (§3.7, 0-4; 3 s).
    static let eventBelowDayToast = L.text("toast.eventBelowDay")
    /// The page reached 15,000 strokes (§5.2; 6 s, not an error, once per page on this device).
    static let strokeBudgetManyToast = L.format("toast.strokeBudget.many", DateText.number(StrokeBudget.noticeAt, L.language), DateText.number(StrokeBudget.refuseAt, L.language))
    /// New strokes were refused at 19,000 (§5.2; an error toast, 6 s, at most every 2 s).
    static let strokeBudgetFullToast = L.format("toast.strokeBudget.full", DateText.number(StrokeBudget.refuseAt, L.language))
    /// How long the 15,000-stroke notice stays (the error toasts' 6 s, without the error colour).
    static let strokeBudgetNoticeDuration: TimeInterval = 6

    /// 1.1.1 (docs/R1_1_1.md): the one-time hint that two fingers zoom.
    static let pinchHintToast = L.text("toast.pinchHint")
    static let pinchHintDuration: TimeInterval = 6
    /// Long enough for the first-launch paywall (`sheetGap` + `firstRefreshTimeout`) to have come up.
    static let pinchHintDelay: Double = 4

    /// 1.2 (§10.4): how long after a sheet closed a waiting toast of the week start is looked at. The next
    /// sheet comes `sheetGap` later (設定 → 書き出し, 取り込み, 購読) and the first paywall up to
    /// `sheetGap` + `firstRefreshTimeout` later (初回案内); a toast shown in that gap would be lost under it,
    /// and a page's hidden strokes would count as told about.
    static func weekStartNoticeDelay(firstPaywallDue: Bool) -> Double {
        firstPaywallDue ? pinchHintDelay : sheetGap + 0.15
    }

    /// Shown once on a device; not to someone who has already zoomed in (a stored ratio), except in a
    /// sandbox-receipt build (TestFlight, App Review), so the owner can see it; never in screenshot mode
    /// or the XCTest host.
    static func pinchHintDue(shown: Bool, hasPinched: Bool, sandbox: Bool, screenshot: Bool, testHost: Bool) -> Bool {
        !screenshot && !testHost && !shown && (!hasPinched || sandbox)
    }

    /// The tool, the last ink, the toolbar's state and the eraser's origin the screen starts with
    /// (1.1, M7A_CONTRACT §2.3 / §2.7 / §7.3).
    struct StartState: Equatable {
        var tool: CanvasTool
        var lastInkTool: CanvasTool
        var toolbarMode: ToolbarMode
        var eraserOrigin: EraserOrigin?
        /// The dock's corner in screenshot mode; nil in normal use (the stored corner decides).
        var screenshotEdge: ToolbarEdge?
    }

    /// Normal use (0-13): the remembered pen (also the last ink, so the Pencil's double tap and the
    /// eraser go back to it) and the stored `toolbar.collapsed` (a peek is never stored).
    static func startState(collapsedStored: Bool, rememberedPen: InkStyle) -> StartState {
        StartState(
            tool: .ink(rememberedPen),
            lastInkTool: .ink(rememberedPen),
            toolbarMode: ToolbarLogic.startMode(collapsedStored: collapsedStored),
            eraserOrigin: nil,
            screenshotEdge: nil
        )
    }

    /// Screenshot mode (§7.3): `ScreenshotMode.startTool` (the lasso sheet's lasso, `--screenshot-tool`,
    /// else the default pen), the default pen as the last ink (the remembered pen is never read), the
    /// eraser as the toolbar's (its note shows the return to the pen), and `--screenshot-toolbar`
    /// (collapsed bottom left / right; nil = expanded).
    static func startState(shot: ScreenshotMode.Config) -> StartState {
        StartState(
            tool: ScreenshotMode.startTool(shot),
            lastInkTool: .ink(ToolbarPalette.defaultPen),
            toolbarMode: shot.toolbar?.mode ?? .expanded,
            eraserOrigin: shot.tool?.eraserOrigin,
            screenshotEdge: shot.toolbar?.edge ?? .leading
        )
    }

    init() {
        let shot = ScreenshotMode.current
        // 1.2 (§1.4, §5.6, §10.3): decided once and written before anything reads the setting. `@AppStorage`
        // cannot be read here, so the records are read directly. Screenshot mode only knows its arguments.
        if shot == nil { HolidayChoice.migrateIfNeeded() }
        let startWeekStart = WeekStartChoice.prepareAtLaunch(shot: shot)
        _weekStart = State(initialValue: startWeekStart)
        let holidaysStarted = Date()
        let startHolidays = HolidayChoice.calendar(setting: shot?.holidays ?? HolidayChoice.setting(),
                                                   deviceRegion: Locale.current.region?.identifier,
                                                   language: L.language, store: HolidayChoice.store)
        HolidayChoice.current = startHolidays
        Self.logLaunch(holidays: startHolidays, loadingTook: Date().timeIntervalSince(holidaysStarted))
        let startNow = shot?.today ?? Date()
        let startKind: PageKind
        let startFocus: DayKey
        if let shot = shot {
            // CI screenshot mode opens the page it was asked for and never touches the memory.
            startKind = shot.page
            startFocus = shot.focus
        } else {
            let defaults = UserDefaults.standard
            // iPhones start on the week page (DESIGN §2.11); everything else on the month page.
            let fallbackKind: PageKind = UIDevice.current.userInterfaceIdiom == .phone ? .week : .month
            startKind = defaults.string(forKey: AppSettings.lastKindKey).flatMap(PageKind.init(rawValue:)) ?? fallbackKind
            startFocus = defaults.string(forKey: AppSettings.lastFocusKey).flatMap(DayKey.init(ymd:)) ?? DayKey(startNow)
        }
        _kind = State(initialValue: startKind)
        _focus = State(initialValue: startFocus)
        _now = State(initialValue: startNow)
        // 1.1 (0-13, §2.7): the remembered pen and the stored toolbar state. `@AppStorage` cannot be read
        // before every stored property is set, so `AppSettings` reads `UserDefaults.standard` directly.
        // Screenshot mode reads neither (the lasso screenshot keeps starting with the lasso, so the
        // preselected strokes keep their frame).
        let start = shot.map { Self.startState(shot: $0) }
            ?? Self.startState(collapsedStored: AppSettings.toolbarCollapsed, rememberedPen: ToolbarPalette.rememberedPen(.standard))
        _tool = State(initialValue: start.tool)
        _lastInkTool = State(initialValue: start.lastInkTool)
        _toolbarMode = State(initialValue: start.toolbarMode)
        _eraserOrigin = State(initialValue: start.eraserOrigin)
        _screenshotEdge = State(initialValue: start.screenshotEdge)
        // 1.1 (§7.3): screenshot mode starts from its demo page (`--screenshot-grown` included), so the
        // first layout is already the grown paper and `--screenshot-offset` is clamped to it. `show()`
        // loads the same page again (nothing changes, nothing is dirty).
        let startPage = shot != nil
            ? ScreenshotMode.demoPage(kind: startKind, focus: startFocus, weekStart: startWeekStart)
            : InkPage.empty(pageId: PageNavigation.pageId(startKind, focus: startFocus, weekStart: startWeekStart))
        _page = State(initialValue: startPage)
        _paper = State(initialValue: Self.makePaper(kind: startKind, focus: startFocus, events: [], inkBottoms: startPage.inkBottoms(), now: startNow,
                                                    holidays: startHolidays, weekStart: startWeekStart))
    }

    /// The launch's two lines for the CI's log (§5.3, §5.6): DEBUG builds and screenshot mode only.
    private static func logLaunch(holidays: HolidayCalendar, loadingTook seconds: TimeInterval) {
        #if !DEBUG
        guard ScreenshotMode.isActive else { return }
        #endif
        NSLog("%@", "l10n: ui=\(L.language.rawValue) locale=\(L.locale.identifier) holidays=\(holidays.id)")
        NSLog("%@", "l10n: holidays loaded \(Int((seconds * 1000).rounded())) ms")
    }

    /// The holidays the body's title uses (§5.6): from the setting, which SwiftUI watches, never from
    /// `HolidayChoice.current`, which it does not (the title would stay on the old calendar). The store
    /// keeps the file and the years, so making it again costs nothing.
    private var holidays: HolidayCalendar {
        HolidayChoice.calendar(setting: ScreenshotMode.current?.holidays ?? HolidaySetting(storageValue: holidaySettingRaw),
                               deviceRegion: Locale.current.region?.identifier,
                               language: L.language, store: HolidayChoice.store)
    }

    private var pageId: String { PageNavigation.pageId(kind, focus: focus, weekStart: weekStart) }

    /// The canvas's identity (§10.5): the page and the week start. A month page keeps its id when the
    /// week start changes, and its canvas must still be made anew: the undo history would otherwise
    /// point at strokes that may now be hidden, and ↶ would seem to do nothing.
    private var canvasIdentity: String { "\(pageId)|\(weekStart.rawValue)" }

    private var layout: any PageLayout { paper.layout }

    /// Screenshot mode's `lasso` sheet (and the UI tests' `--screenshot-select`): the canvas selects
    /// these strokes once its zoom is known.
    private var initialSelectionIds: [String] {
        ScreenshotMode.initialSelection(ScreenshotMode.current)
    }

    private var eraseDefault: Bool {
        ScreenshotMode.isActive ? true : AppSettings.eraseInkAfterConvert
    }

    /// The ratio to the opening zoom the shown page opens at (M4C contract §5.1, 1.1.1): `--screenshot-zoom`
    /// in screenshot mode, else the ratio stored for the page's kind (1 = the opening zoom).
    private var currentRatio: CGFloat {
        ScreenshotMode.current?.zoomRatio ?? AppSettings.zoomRatio(for: kind)
    }

    /// The viewport of a page's first frame, before its canvas has reported one: `currentRatio` over
    /// the opening zoom that fits `width` × the paper area (the width alone while `paperArea` is still
    /// `.zero`), centred as the canvas will centre the paper (M4C contract §5.1, 1.1.1).
    private func initialViewport(width: CGFloat) -> PaperViewport {
        PaperViewport.initial(
            kind,
            overview: ZoomPolicy.overviewSize(layout),
            paperSize: layout.size,
            viewport: CGSize(width: width, height: paperArea.height),
            ratio: currentRatio
        )
    }

    /// The viewport the sticky header and the band are placed with: the canvas's last report, or the
    /// first-frame one for `width` until there is a report (M4B contract §2.6, M4C §5.1).
    private func shownViewport(width: CGFloat) -> PaperViewport {
        viewport.width == 0 ? initialViewport(width: width) : viewport
    }

    /// The zoom the page is expected to open at (`currentRatio` over the page's bounds for
    /// `viewportWidth` × the paper area): the estimate `initialScrollX` is computed with (M4C
    /// contract §5.1 / §1.6). The real value may differ by the band's height; the canvas applies
    /// `initialScrollX` only when the ratio is above 1.
    private func estimatedZoom(viewportWidth: CGFloat) -> CGFloat {
        ZoomPolicy.zoom(
            forRatio: currentRatio,
            bounds: ZoomPolicy.bounds(
                kind,
                overview: ZoomPolicy.overviewSize(layout),
                viewport: CGSize(width: viewportWidth, height: paperArea.height)
            )
        )
    }

    /// The height (pt) left for the paper under the band (M4C contract §5.1): `area` minus the
    /// band's visible height at the overview (`overviewBandZoom`; a band without lanes, or none, takes
    /// nothing). The estimate is exact at the overview on every device of §1.2; a page opened zoomed
    /// in past 0.818 has a taller band, which only moves the first frame's estimate (M4C-19).
    static func paperAreaHeight(area: CGFloat, band: AllDayBandLayout?, kind: PageKind) -> CGFloat {
        guard let band, band.laneCount > 0 else { return area }
        let metrics = AllDayBandMetrics.metrics(kind: kind, laneCount: band.laneCount, zoom: overviewBandZoom, pageHeight: area)
        return area - metrics.visibleHeight
    }

    /// Writes `paperArea` for the band-and-canvas area `size` (only when it changed). 1.1 (§2.2): in
    /// screenshot mode the change is logged with the window's safe area and the toolbar's state, so the
    /// CI's log shows the folded toolbar's paper area next to the expanded one.
    private func updatePaperArea(_ size: CGSize) {
        let next = CGSize(width: size.width, height: Self.paperAreaHeight(area: size.height, band: paper.allDayBand, kind: kind))
        if next != paperArea {
            paperArea = next
            logToolbarArea(next)
        }
    }

    /// Screenshot mode's `toolbar: safeArea=` and `toolbar: paperArea=` lines (§2.2). Also written once
    /// a second after the screen appeared (`appear`): at the first `onAppear` the window scene may not
    /// be connected yet, and its safe area would read zero.
    private func logToolbarArea(_ area: CGSize) {
        guard ScreenshotMode.isActive else { return }
        NSLog("%@", Self.safeAreaLogLine(Self.windowSafeArea()))
        NSLog("%@", Self.paperAreaLogLine(area, mode: toolbarMode))
    }

    /// 「toolbar: safeArea=<上>,<左>,<下>,<右>」 (pt, two decimals; §2.2).
    static func safeAreaLogLine(_ insets: UIEdgeInsets) -> String {
        "toolbar: safeArea=" + [insets.top, insets.left, insets.bottom, insets.right].map(logNumber).joined(separator: ",")
    }

    /// 「toolbar: paperArea=<幅>x<高さ> mode=<expanded|collapsed|peek>」 (pt, two decimals; §2.2).
    static func paperAreaLogLine(_ size: CGSize, mode: ToolbarMode) -> String {
        "toolbar: paperArea=\(logNumber(size.width))x\(logNumber(size.height)) mode=\(mode.rawValue)"
    }

    private static func logNumber(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    /// The device's safe area (the window's, without the toolbar's inset); zero before a window exists.
    private static func windowSafeArea() -> UIEdgeInsets {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets ?? .zero
    }

    /// True while any sheet or cover is up (the account question waits for them; M4 contract §6.4).
    /// 1.2.2 (docs/R1_2_2.md §3.6): Apple's age range sheet counts too.
    private var sheetIsUp: Bool {
        showSettings || editor != nil || showImportPicker || importPhase != nil || exportPhase != nil || showOnboarding || showPaywall
            || ageRangeAsking
    }

    /// M5 (M5_CONTRACT §3.1): the access state and whether the app is read only.
    private var access: AccessState { store.snapshot.access }
    private var readOnly: Bool { !access.canEdit }

    // MARK: 1.1 toolbar (M7A_CONTRACT §2)

    /// The dock button's corner: `--screenshot-toolbar` in screenshot mode, else the stored one.
    private var toolbarEdge: ToolbarEdge {
        screenshotEdge ?? ToolbarEdge(stored: toolbarEdgeRaw)
    }

    /// 「消しゴムで消したらペンに戻る」: always on in screenshot mode (the memory is not read there).
    private var eraserAutoReturnOn: Bool {
        ScreenshotMode.isActive ? true : eraserAutoReturn
    }

    /// The ink the eraser will return to (the bracket of its note, §2.4) — the toolbar's and, since the
    /// owner's decision of 2026-11-01 (ずれ 49), the Apple Pencil's double tap / squeeze too; nil otherwise.
    static func eraserReturnTarget(tool: CanvasTool, origin: EraserOrigin?, setting: Bool, lastInk: CanvasTool) -> CanvasTool? {
        tool.isEraser && setting ? lastInk : nil
    }

    /// This month (the year gutter's day numbers open this month's day, P-13; fixed in screenshot mode).
    private var currentMonth: Int { DayKey(now).month }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < Self.compactWidth
            // The first frame of a page has no report from its canvas yet: the stored ratio over the
            // opening zoom, centred, the same position the canvas starts from (M4B contract §2.6, M4C §5.1).
            let shownViewport = self.shownViewport(width: proxy.size.width)
            VStack(spacing: 0) {
                PageHeaderView(
                    kind: kind,
                    title: compact
                        ? PageNavigation.compactTitle(kind, focus: focus, language: L.language, weekStart: weekStart)
                        : PageNavigation.title(kind, focus: focus, holidays: holidays, language: L.language, weekStart: weekStart),
                    compact: compact,
                    onPrevious: { move(by: -1) },
                    onToday: goToday,
                    onNext: { move(by: 1) },
                    onKindChange: { show(kind: $0, focus: focus) },
                    onAddEvent: addEvent,
                    onSettings: { showSettings = true },
                    sync: sync.snapshot.status.header,
                    onSyncTap: { showSettings = true },
                    width: proxy.size.width,
                    readOnly: readOnly,
                    onReadOnlyTap: { showPaywall(reason: .badge) },
                    // 1.2 (F-11): outside ja the wide day title gives way at its holiday, not its date.
                    titleHoliday: !compact && kind == .day ? holidays.name(of: focus) : nil
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                accessNotice
                readOnlyNotice(compact: compact)
                StickyHeaderView(
                    paper: paper,
                    now: now,
                    viewport: shownViewport,
                    onDayTap: { show(kind: .day, focus: $0) },
                    onMonthTap: { show(kind: .month, focus: $0.firstDay) }
                )
                // The band and the canvas share this area; its height is the base of the band's
                // 35 % cap (M4B contract §2.2 / §2.6).
                GeometryReader { area in
                    VStack(spacing: 0) {
                        if let band = paper.allDayBand {
                            AllDayBandView(
                                band: band,
                                viewport: shownViewport,
                                pageHeight: area.size.height,
                                laneZoom: frozenLaneZoom,
                                onBarTap: openEdit(eventId:),
                                onColumnTap: { openCreate(range: .allDay($0), snapshot: nil, inkIds: []) },
                                onColumnDoubleTap: { day in
                                    guard kind != .day else { return }
                                    show(kind: .day, focus: day)
                                }
                            )
                        }
                        canvas(viewportWidth: proxy.size.width)
                    }
                    .frame(width: area.size.width, height: area.size.height, alignment: .top)
                    // M4C contract §5.1: the paper area under the band, the base of the overview.
                    .onAppear { updatePaperArea(area.size) }
                    .onChange(of: area.size) { updatePaperArea(area.size) }
                    .onChange(of: paper.allDayBand?.laneCount) { updatePaperArea(area.size) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // 1.1 (§2.2): the peeking bar and the dock button lie over the paper (the paper area does not
        // change), inside the safe area, 12 pt from the side and 6 pt above the bottom.
        .overlay(alignment: .bottom) {
            ZStack {
                if toolbarMode == .peek {
                    toolbar
                        .padding(.horizontal, ToolbarLogic.sidePadding)
                        .padding(.bottom, ToolbarLogic.bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toolbarMode)
        }
        .overlay(alignment: toolbarEdge == .leading ? .bottomLeading : .bottomTrailing) {
            ZStack {
                if toolbarMode == .collapsed {
                    ToolbarDock(
                        tool: tool,
                        canUndo: canUndo && !readOnly,
                        edge: toolbarEdge,
                        onExpand: { toolbarEvent(.dockToolTapped) },
                        onUndo: undo,
                        onMoveEdge: { toolbarEvent(.moveEdgeChosen) },
                        onPin: { toolbarEvent(.pinChosen) }
                    )
                    .padding(.horizontal, ToolbarLogic.sidePadding)
                    .padding(.bottom, ToolbarLogic.bottomPadding)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toolbarMode)
        }
        .overlay(alignment: .bottom) {
            ZStack {
                if let toast = toast {
                    ToastView(message: toast)
                        // 1.1 (0-15): above the dock button / the peeking bar (8 pt while expanded).
                        .padding(.bottom, ToolbarLogic.toastBottomPadding(toolbarMode))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toast)
        }
        .background(Color(uiColor: .systemBackground))
        // 1.1 (§2.7, §9.1): the modifier always stays (adding or removing it would rebuild the canvas
        // and lose its ledger, zoom and scroll); only the expanded state puts the bar in it, with the
        // default spacing as before, and the other states leave it empty with no spacing (height 0).
        .safeAreaInset(edge: .bottom, spacing: toolbarMode == .expanded ? nil : 0) {
            if toolbarMode == .expanded {
                toolbar
                    .padding(.horizontal, ToolbarLogic.sidePadding)
                    .padding(.bottom, ToolbarLogic.bottomPadding)
            }
        }
        .onAppear(perform: appear)
        .onChange(of: model.events) { relayout() }
        .onChange(of: scenePhase) { scenePhaseChanged() }
        .onChange(of: tool) {
            if case .ink = tool { lastInkTool = tool }
        }
        .onChange(of: sync.snapshot.status) { syncStatusChanged() }
        .onChange(of: sheetIsUp) { sheetsChanged() }
        // 1.2 (§5.6, §10.4, §10.5): the two settings, and the moments a waiting toast can show.
        .onChange(of: holidaySettingRaw) { holidaySettingChanged() }
        .onChange(of: weekStartRaw) { weekStartSettingChanged() }
        // 1.2.2 (docs/R1_2_2.md §3.1): a toast gone or the account question closed may be the age range's calm moment.
        .onChange(of: toast) {
            showNextWeekStartNotice()
            askAgeRangeIfDue()
        }
        .onChange(of: showAccountChange) {
            showNextWeekStartNotice()
            askAgeRangeIfDue()
        }
        // M5 (M5_CONTRACT §4.2 / §3.1): the purchase toasts, and the moment the app turns read only.
        .onChange(of: store.snapshot.message) { messageChanged() }
        .onChange(of: readOnly) { readOnlyChanged() }
        .task { await nowTicker() }
        .sheet(item: $editor) { request in
            editorSheet(request)
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(
                model: model,
                sync: sync,
                allowFinger: $allowFinger,
                onRequestAccess: { await model.requestAccess() },
                onSyncNow: { Task { await sync.syncNow() } },
                onImportWeb: importWeb,
                onEraseAllInk: eraseAllInk,
                onResolveAccountChange: resolveAccountChangeFromSettings,
                onDone: { showSettings = false },
                // The CI's `sync` screenshot scrolls to the 「同期」 section (M4 contract §6.6).
                scrollToSyncOnAppear: ScreenshotMode.current?.sheet == .sync,
                store: store,
                // 設定 › 購入 › 「購読する」: close the settings, then the paywall (M5 contract §4.2).
                onShowPaywall: {
                    showSettings = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(Self.sheetGap))
                        showPaywall(reason: .settings)
                    }
                },
                // M6 (M6_CONTRACT §3.3): 設定 › データ › 「手書きを書き出す」.
                onExport: openExport,
                // 1.1 (M7A_CONTRACT §7.3): the CI's `info` screenshot scrolls to 「情報」.
                scrollToInfoOnAppear: ScreenshotMode.current?.sheet == .info,
                // 1.2 (§10.7): nothing is stored in screenshot mode, so `.onChange` never fires there.
                onScreenshotWeekStart: { switchWeekStart(to: $0) }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(store: store, reason: paywallReason, onClose: { showPaywall = false })
        }
        .sheet(isPresented: $showImportPicker) {
            DocumentPickerView(onPick: pickedImportFile, onCancel: { showImportPicker = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: importSheetBinding) {
            // 1.1 (§5.2): 〔取り込む〕 of the large-page question imports; 〔やめる〕 is `onClose`.
            WebImportSheet(phase: importPhase ?? .reading, onClose: closeImportSheet, onConfirmLarge: confirmLargeImport)
        }
        .sheet(isPresented: exportSheetBinding) {
            ExportSheet(
                phase: exportPhase ?? .choose,
                pageTitle: PageNavigation.title(kind, focus: focus, holidays: holidays, language: L.language, weekStart: weekStart),
                pageKind: kind,
                onChoose: runExport,
                onClose: closeExportSheet
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                await model.requestAccess()
                onboardingDone = true
                showOnboarding = false
                // M5 (M5_CONTRACT §4.2): the paywall once, after the first refresh says 未購読.
                scheduleFirstLaunchPaywall()
            }
            .interactiveDismissDisabled()
        }
        .accountChangeDialog(isPresented: $showAccountChange, onChoose: chooseAccount)
        .alert(L.text("alert.saveFailed.title"), isPresented: Binding(
            get: { saveError != nil },
            // 1.2.2 (docs/R1_2_2.md §3.1): the age range step waits for this alert, so its close is a calm moment.
            set: { if !$0 { saveError = nil; askAgeRangeIfDue() } }
        )) {
            Button(L.text("alert.saveFailed.ok"), role: .cancel) { saveError = nil; askAgeRangeIfDue() }
        } message: {
            Text(saveError ?? "")
        }
        .overlay(alignment: .topLeading) { l10nState }
        // 1.2.1 (docs/R1_2_1.md §2.2): StoreKit's rating prompt when `scheduleReviewRequest` bumps the trigger.
        .modifier(ReviewRequester(trigger: reviewRequestTrigger))
    }

    /// Screenshot mode's state for the UI tests (§7.3): 1 × 1 pt, clear, read only by the accessibility
    /// tree (`.hidden()` and `.opacity(0)` would take it out of the tree), and it takes no touch.
    @ViewBuilder
    private var l10nState: some View {
        if ScreenshotMode.isActive {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("l10n.state")
                .accessibilityLabel("ui=\(L.language.rawValue);locale=\(L.locale.identifier);holidays=\(holidays.id);week=\(weekStart.rawValue)")
                .allowsHitTesting(false)
        }
    }

    // MARK: - Pieces

    /// The bar: in the bottom inset while expanded, laid over the paper while peeking (the same view,
    /// with 「しまう」 in both; §2.2). The eraser's note says where it returns to (§2.4).
    private var toolbar: some View {
        ToolbarView(
            tool: toolBinding,
            allowFinger: $allowFinger,
            // M5 (M5_CONTRACT §3.1): greyed while read only; the guards are the insurance.
            canUndo: canUndo && !readOnly,
            canRedo: canRedo && !readOnly,
            onUndo: undo,
            onRedo: redo,
            showsCollapseButton: true,
            onCollapse: { toolbarEvent(.collapseTapped) },
            eraserReturnsTo: Self.eraserReturnTarget(tool: tool, origin: eraserOrigin, setting: eraserAutoReturnOn, lastInk: lastInkTool)
        )
    }

    /// ↶ of the bar and of the dock button.
    private func undo() {
        guard isAllowed(.undoRedo) else { blocked(.undoRedo); return }
        undoTrigger += 1
    }

    /// ↷ of the bar.
    private func redo() {
        guard isAllowed(.undoRedo) else { blocked(.undoRedo); return }
        redoTrigger += 1
    }

    /// One row of the table of §2.1 (`ToolbarLogic.step`): the next mode, `toolbar.collapsed` and the
    /// corner. Screenshot mode never writes the memories (its corner is `screenshotEdge`).
    private func toolbarEvent(_ event: ToolbarEvent) {
        let step = ToolbarLogic.step(toolbarMode, on: event)
        if step.flipsEdge {
            let next = toolbarEdge.opposite
            if ScreenshotMode.isActive {
                screenshotEdge = next
            } else {
                toolbarEdgeRaw = next.rawValue
            }
        }
        if let stored = step.storeCollapsed, !ScreenshotMode.isActive {
            toolbarCollapsedStored = stored
        }
        if step.mode != toolbarMode {
            toolbarMode = step.mode
        }
    }

    /// The canvas: the pen or a writing finger touched the paper. A peeking bar folds back into the
    /// dock button (animated, 0.2 s); an expanded bar stays (§2.1). Nothing is written otherwise, so
    /// a pen-down does not update the screen.
    private func penDown() {
        // 1.2 (§10.3, 4 (3)): before the guard, which returns on nearly every touch. Nothing reads it in
        // the body, so this does not update the screen either.
        penTouchedThisLaunch = true
        // 1.2.1 (docs/R1_2_1.md §2.4): a touch on the new page stops the rating prompt's wait (a Pencil's
        // hover comes here too; it only stops the wait).
        reviewTask?.cancel()
        // 1.2.2 (docs/R1_2_2.md §3.1, §12.2): a stroke being written counts as fresh ink for the age range
        // sheet. Nothing reads it in the body either.
        ageRangePenDownAt = Date()
        guard ToolbarLogic.modeAfterPenDown(toolbarMode) != toolbarMode else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            toolbarEvent(.penDown)
        }
    }

    /// The canvas: the eraser erased `erased` strokes and nothing touches the paper any more (§2.4 /
    /// §2.5, D2). 1.1 fix (docs/M7A.md ずれ 46): the report comes on the turn after the Pencil lifts, and
    /// the canvas's `fingerEraseReportDelay` after a finger (0.5 s on the week, month and year pages —
    /// after a single tap's undo of what its own touch erased, 0-22 — and 0.3 s on the day page). The
    /// toolbar's eraser goes back to the last pen or marker when the setting is on; a tool the person
    /// chose before the report stays (`toolAfterErase` is nil unless the tool is still the eraser).
    private func eraseEnded(_ erased: Int) {
        if let next = ToolbarLogic.toolAfterErase(origin: eraserOrigin, erased: erased, setting: eraserAutoReturnOn,
                                                  current: tool, lastInk: lastInkTool) {
            tool = next
        }
    }

    /// The canvas reached the stroke budget (§5.2, K-9). `.many`: the 15,000 notice once per page on
    /// this device (screenshot mode shows it without reading or writing the memory). `.full`: the
    /// refusal as an error toast, at most every 2 s.
    private func strokeBudgetReached(_ event: StrokeBudget.Event) {
        switch event {
        case .many:
            if !ScreenshotMode.isActive {
                let id = pageId
                guard !AppSettings.strokeBudgetNoticed(id) else { return }
                AppSettings.markStrokeBudgetNoticed(id)
            }
            showToast(Self.strokeBudgetManyToast, duration: Self.strokeBudgetNoticeDuration)
        case .full:
            let now = Date()
            if let last = lastBudgetFullAt, now.timeIntervalSince(last) < Self.blockedInputInterval { return }
            lastBudgetFullAt = now
            showToast(Self.strokeBudgetFullToast, isError: true)
        }
    }

    /// The canvas dropped a stroke below the last cell's limit, or a stroke reached its last step
    /// (§3.4): 「メモ欄はここまでです」 once while this page is open (`show` forgets it on a page change).
    private func growthCapReached() {
        let id = pageId
        guard capNoticedPageId != id else { return }
        capNoticedPageId = id
        showToast(Self.growthCapToast)
    }

    /// The canvas (担当 I) with the lasso menu floating over it. The argument order follows
    /// M3B_CONTRACT.md §3.3 (the M3a arguments, then the M3b ones), M4B_CONTRACT.md §1.3
    /// (`initialScrollX` right after `initialScrollY`, then `onViewportChange`) and M4C_CONTRACT.md
    /// §1.3 (the six zoom / double-tap arguments after it). `viewportWidth` is the screen's width:
    /// the canvas has no horizontal padding, so it is the canvas's width too.
    private func canvas(viewportWidth: CGFloat) -> some View {
        // 1.0.1: an iPhone and a narrow window are small screens (the year's 44 pt date target whatever
        // 「指でも書く」 says); 1.1 (`DateTap`) also reads 「指でも書く」 and this month.
        let smallScreen = Self.usesMinTapTarget(isPhone: UIDevice.current.userInterfaceIdiom == .phone, width: viewportWidth)
        return InkCanvasView(
            layout: layout,
            paper: paper,
            tool: tool,
            allowFinger: allowFinger,
            page: pageBinding,
            initialScrollY: PageNavigation.initialScrollY(layout, now: now),
            initialScrollX: PageNavigation.initialScrollX(
                layout,
                now: now,
                visibleWidth: ZoomPolicy.visibleWidth(kind, viewportWidth: viewportWidth, zoom: estimatedZoom(viewportWidth: viewportWidth))
            ),
            onTap: { handleTap(at: $0, zoom: $1, smallScreen: smallScreen) },
            onInkBoundsChanged: inkBoundsChanged,
            undoTrigger: undoTrigger,
            redoTrigger: redoTrigger,
            onPencilToggle: togglePencilTool,
            onHistoryChanged: historyChanged,
            onSelectionChange: selectionChanged,
            onEventRect: eventRectFinished,
            onEventPreview: eventPreview,
            command: command,
            commandTrigger: commandTrigger,
            initialSelectionIds: initialSelectionIds,
            onViewportChange: { viewport = $0 },
            // M4c (M4C contract §1.3 / §5.1): the ratio the page opens at, the screenshot offset, the
            // double tap (not on the day page), the ratio of a finished pinch, the pinch in progress.
            initialZoomRatio: currentRatio,
            initialPaperOffset: ScreenshotMode.current?.offset,
            // 1.1.1: 「今日」 brings today's cell on screen.
            revealRect: revealRect,
            revealTrigger: revealTrigger,
            doubleTapEnabled: kind != .day,
            onDoubleTap: handleDoubleTap,
            onZoomRatioChange: { ratio in
                guard !ScreenshotMode.isActive else { return }
                AppSettings.setZoomRatio(ratio, for: kind)
            },
            onZoomingChange: { zooming in
                frozenLaneZoom = zooming ? shownViewport(width: viewportWidth).zoom : nil
                if zooming { pinchBegan() }
            },
            // M5 (M5_CONTRACT §3.1): no ink while read only; a Pencil touch asks for the paywall.
            readOnly: readOnly,
            onBlockedInput: blockedInput,
            // 1.0.1: a tap that opens the day page removes the dot 「指でも書く」 drew for it (1.1: with
            // the same rule as `handleTap`, so a gutter number removes its dot too).
            tapLeavesPage: {
                Self.leavesPage(Self.tapTarget(layout: layout, point: $0, zoom: $1, smallScreen: smallScreen,
                                               allowFinger: allowFinger, currentMonth: currentMonth))
            },
            // 1.1 (M7A_CONTRACT §2.7 / §3.4 / §5.2): pen-down folds a peeking bar, the eraser's end
            // returns to the pen, the budget and the memo limit become toasts, and the dock keeps
            // 60 pt free at the bottom of the paper (also while peeking, so the insets do not move).
            onPenDown: penDown,
            onEraseEnded: eraseEnded,
            onStrokeBudget: strokeBudgetReached,
            onGrowthCapReached: growthCapReached,
            bottomClearance: ToolbarLogic.paperBottomClearance(toolbarMode)
        )
        .id(canvasIdentity)
        .overlay(alignment: .topLeading) {
            GeometryReader { proxy in
                selectionMenu(in: CGRect(origin: .zero, size: proxy.size))
            }
        }
    }

    /// 「予定にする／削除／選択解除」 above the selection frame (below it when there is no room; M3b
    /// contract §4.2), hidden while a sheet is up. `bounds` is the canvas's own frame.
    @ViewBuilder
    private func selectionMenu(in bounds: CGRect) -> some View {
        if let selection = selection, editor == nil, !showSettings, tool == .lasso, !readOnly {
            let origin = SelectionMenuView.placement(
                anchor: selection.viewRect,
                size: menuSize,
                bounds: bounds.insetBy(dx: SelectionMenuView.margin, dy: SelectionMenuView.margin)
            )
            SelectionMenuView(
                onConvert: convertSelection,
                onDelete: { send(.deleteSelection) },
                onDeselect: { send(.clearSelection) }
            )
            .fixedSize()
            .background(
                GeometryReader { measured in
                    Color.clear
                        .onAppear { menuSize = measured.size }
                        .onChange(of: measured.size) { menuSize = measured.size }
                }
            )
            .offset(x: origin.x, y: origin.y)
        }
    }

    private func editorSheet(_ request: EventEditorRequest) -> some View {
        EventEditorSheet(
            mode: request.mode,
            draft: request.draft,
            calendars: request.calendars,
            snapshot: request.snapshot,
            showEraseOption: !request.inkIds.isEmpty,
            eraseDefault: eraseDefault,
            onSubmit: { result in try await handleSubmit(request, result) },
            onCancel: { editor = nil },
            // M5 (M5_CONTRACT §3.3, M5-31): the read-only sheet names the subscription as the cause and
            // offers it; an explicit tap, so the paywall opens every time (not through `blocked`).
            readOnlyNote: readOnly ? EventEditorSheet.subscriptionNote : nil,
            onSubscribe: readOnly ? {
                editor = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Self.sheetGap))
                    showPaywall(reason: .blocked(.editEvent))
                }
            } : nil
        )
    }

    /// The import sheet is presented while `importPhase` is set; swiping it away (possible only when
    /// done or failed) counts as 「閉じる」.
    private var importSheetBinding: Binding<Bool> {
        Binding(
            get: { importPhase != nil },
            set: { if !$0 { closeImportSheet() } }
        )
    }

    /// The export sheet is presented while `exportPhase` is set; swiping it away (possible only when
    /// choosing, done or failed) counts as 「閉じる」 (M6_CONTRACT §3.3).
    private var exportSheetBinding: Binding<Bool> {
        Binding(
            get: { exportPhase != nil },
            set: { if !$0 { closeExportSheet() } }
        )
    }

    /// A one-line notice while the calendar cannot be read (DESIGN §4.1).
    @ViewBuilder
    private var accessNotice: some View {
        switch model.status {
        case .fullAccess:
            EmptyView()
        case .notDetermined:
            noticeRow(L.text("notice.calendar.notDetermined"), buttonTitle: L.text("notice.calendar.notDetermined.allow")) {
                showOnboarding = true
            }
        case .denied, .writeOnly:
            noticeRow(L.text("notice.calendar.denied"), buttonTitle: L.text("notice.calendar.denied.openSettings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        case .restricted:
            noticeRow(L.text("notice.calendar.restricted"), buttonTitle: nil, action: {})
        }
    }

    private func noticeRow(_ text: String, buttonTitle: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if let buttonTitle = buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    /// The canvas writes every ink change here; writes for another page (a canvas being torn down)
    /// are ignored so they can never land in the wrong page.
    private var pageBinding: Binding<InkPage> {
        Binding(
            get: { page },
            set: { newValue in
                guard newValue.pageId == pageId else { return }
                page = newValue
                pageDirty = true
                scheduleSave()
                // 1.2.1 (docs/R1_2_1.md §2.4): only the canvas's own operations come here (writing, erasing,
                // ↶ ↷, the lasso's move and delete), not iCloud's strokes (`applyRemote`), the band's move or
                // an import, so this is the person's own ink.
                inkChangedThisVisit = true
                lastInkChangeAt = Date()
                noteReviewInk()
            }
        )
    }

    // MARK: - Lifecycle

    private func appear() {
        guard !appeared else { return }
        appeared = true
        // 1.2.1 (docs/R1_2_1.md §2.4): the rating prompt's first day of use, written once.
        noteReviewUse()
        // M5 (M5_CONTRACT §2.4 / §4.2): the cached access state first, then the store's own refresh.
        store.start()
        if !allowFingerChosen {
            // Pencil only on iPad by default; iPhones and Macs have no Pencil (DESIGN §2.1, §2.11).
            allowFingerChosen = true
            allowFinger = UIDevice.current.userInterfaceIdiom != .pad
        }
        // CI screenshot mode never shows the onboarding (and so never asks for calendar access).
        if !onboardingDone, !ScreenshotMode.isActive {
            if model.status == .notDetermined {
                showOnboarding = true
            } else {
                onboardingDone = true
                scheduleFirstLaunchPaywall()
            }
        } else {
            // 0.5.2 からの更新・再インストール・新しい端末 (M5 contract §4.2); nothing in screenshot mode.
            scheduleFirstLaunchPaywall()
        }
        // M4 contract §5.3: pages the engine changed from iCloud reach the shown page here.
        sync.onRemoteUpdate = { applyRemote($0) }
        // 1.2.3 (docs/R1_2_3.md §3; M4_CONTRACT §5.3): `.onChange(of: scenePhase)` does not report the first
        // value, so a launch that is already `.active` here tells the engine it is in the foreground now.
        if scenePhase == .active {
            sync.applicationDidBecomeActive()
        }
        // 1.2 (§10.3): a changed region never changes the week start silently.
        if !ScreenshotMode.isActive, let changed = WeekStartChoice.regionChange(automatic: WeekStartChoice.launchAutomatic) {
            weekStartNotices.add(.regionChanged(changed))
        }
        show(kind: kind, focus: focus)
        // 1.2 (§10.3, 4 (1)): the engine started in the AppDelegate; a first pull that already finished
        // is not seen by `.onChange`. (The same as `.accountMismatch` below.)
        checkWeekStartAfterPull()
        showNextWeekStartNotice()
        // The engine may already be waiting for the account answer (its first round ran before this
        // screen appeared); `onChange` only sees changes from now on.
        if sync.snapshot.status == .accountMismatch {
            presentAccountChange()
        }
        if let sheet = ScreenshotMode.current?.sheet {
            // M3b contract §5: open the requested sheet once the canvas is on screen.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                showScreenshotSheet(sheet)
            }
        }
        // M5 contract §7.5: the read-only photo shows the badge and the toast together (20 s, M5-24).
        if ScreenshotMode.current?.readOnly == true {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                showToast(Self.readOnlyToast, duration: Self.screenshotReadOnlyToastDuration)
            }
        }
        // M4B contract §6.4: the window scene may not exist yet here; `.active` tries again.
        requestLandscapeOnce()
        // 1.1 (§2.2): the toolbar's log lines once the window and the first layout are there.
        if ScreenshotMode.isActive {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                logToolbarArea(paperArea)
            }
        }
        // 1.1.1: the photos of the pinch hint (20 s, like the read-only photo); nothing else in screenshot mode.
        if ScreenshotMode.current?.pinchHint == true {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                showToast(Self.pinchHintToast, duration: Self.screenshotReadOnlyToastDuration)
            }
        }
        schedulePinchHint()
        // 1.2.2 (docs/R1_2_2.md §3.1): the age range, at the first calm moment of this launch.
        askAgeRangeIfDue()
    }

    private func scenePhaseChanged() {
        switch scenePhase {
        case .background, .inactive:
            saveNow()
            // 1.2.1 (docs/R1_2_1.md §2.4): no rating prompt for an app that is going away.
            reviewTask?.cancel()
            // 1.1 (§2.1): a peeking bar folds when the app goes to the background.
            if scenePhase == .background {
                toolbarEvent(.wentToBackground)
                // 1.2.3 (docs/R1_2_3.md §3, G3): the next round trips confirm the iCloud account first.
                sync.applicationDidEnterBackground()
            }
        case .active:
            // 1.2.1 (docs/R1_2_1.md §2.3): the rating prompt waits `ReviewPrompt.activeAtLeast` after a return.
            activeSince = Date()
            // 1.2 (§10.3, 4 (3)): a comparison that waited for the pen: a boundary, so it is decided now.
            if pendingAdoption {
                saveNow()
                if let adopted = runWeekStartCheck(atBoundary: true) { switchWeekStart(to: adopted) }
            }
            model.refreshStatus()
            if appeared {
                model.reload()
                relayout()
                // 1.1.1: a wait that found the app away left the hint for this return.
                schedulePinchHint()
            }
            // M4 contract §5.3: one sync round on every return to the foreground (catches up what a
            // silent push did not deliver).
            sync.applicationDidBecomeActive()
            // M5 contract §1.4 / M5-9: the subscription is checked on every return to the foreground
            // (an expiry, a cancellation or a renewal shows up here, never from a timer).
            Task { await store.refresh() }
            requestLandscapeOnce()
            // 1.2.2 (docs/R1_2_2.md §3.4): Apple's call never returned but its sheet is gone: stop waiting for
            // it (the task stays parked; `askedThisLaunch` is true, so this launch never asks again).
            if ageRangeAsking, AgeRangeAsker.sheetIsGone { ageRangeAsking = false }
            askAgeRangeIfDue()
        @unknown default:
            break
        }
    }

    /// `--screenshot-landscape` (M4B contract §6.4): asks the window scene for landscape once. An
    /// iPhone follows; iPadOS ignores it for a multitasking app, and the failure is only printed
    /// (it lands in the CI's app log as 「screenshot-landscape failed」). Nothing happens until a
    /// `UIWindowScene` is connected (the root view's first `onAppear` can be too early), so the
    /// request counts as made only when it was actually sent.
    private func requestLandscapeOnce() {
        guard ScreenshotMode.current?.landscape == true, !landscapeRequested else { return }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        landscapeRequested = true
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
            print("screenshot-landscape failed: \(error)")
        }
    }

    /// Moves the now line every 30 s while the page shows today (week / day) and follows the clock
    /// past midnight on every page (the 「今日」 mark moves). Nothing to do in screenshot mode.
    private func nowTicker() async {
        guard !ScreenshotMode.isActive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.nowTickSeconds))
            if Task.isCancelled { return }
            tickNow()
        }
    }

    private func tickNow() {
        let fresh = Date()
        let dayChanged = DayKey(fresh) != DayKey(now)
        let showsNowLine = layout.nowLine != nil
        guard dayChanged || showsNowLine else { return }
        now = fresh
        relayout()
    }

    // MARK: - Navigation

    /// Saves the current page, then switches to `(newKind, newFocus)` (its ink, its events, its layout).
    private func show(kind newKind: PageKind, focus newFocus: DayKey) {
        // 1.2.1 (docs/R1_2_1.md §2.4): every page opened is a new visit; a waiting rating prompt is dropped
        // (`move(by:)` schedules again after this).
        reviewTask?.cancel()
        reviewTask = nil
        inkChangedThisVisit = false
        lastInkChangeAt = nil
        // 1.1.1: only 「今日」 brings a cell on screen (`goToday`); the other ways open at the top.
        revealRect = nil
        saveNow()
        // 1.2 (§10.3, 4 (3)): a comparison that waited for the pen, right after the save and before the new
        // page's id is made. The state is set here, so the `.onChange` that follows finds nothing to do.
        if pendingAdoption, let adopted = runWeekStartCheck(atBoundary: true) {
            weekStart = adopted
            WeekStartChoice.current = adopted
            viewport = .zero
            capNoticedPageId = nil
        }
        let id = PageNavigation.pageId(newKind, focus: newFocus, weekStart: weekStart)
        if id != pageId {
            // A new canvas reports its own viewport next turn; until then the page starts from
            // `PaperViewport.initial`, not from the previous page's offset and zoom.
            viewport = .zero
            // 1.1 (§3.4): 「メモ欄はここまでです」 may show again on the next opened page.
            capNoticedPageId = nil
        }
        frozenLaneZoom = nil
        kind = newKind
        focus = newFocus
        selection = nil
        remember()
        let loaded: InkPage
        if ScreenshotMode.isActive {
            // Screenshot mode injects its demo strokes in memory; the store is not read or written.
            loaded = ScreenshotMode.demoPage(kind: newKind, focus: newFocus, weekStart: weekStart)
        } else {
            loaded = sync.load(id)
            // M4 contract §5.3: fetch this one page from iCloud (a page written on another device
            // just before it was opened here); a change arrives through `onRemoteUpdate`.
            sync.pageOpened(id)
        }
        // M4B contract §3.3: the week / day band's handwriting moves onto the grid (idempotent; the
        // ledger does the same). A page that changed is saved and sent right away (M4B-11).
        page = BandMigration.migrate(loaded)
        pageDirty = false
        if page != loaded {
            pageDirty = true
            scheduleSave()
        }
        if !ScreenshotMode.isActive { now = Date() }
        model.load(kind: newKind, focus: newFocus, weekStart: weekStart)
        relayout()
        noticeHiddenInk()
    }

    /// ◀ ▶. 1.2.1 (docs/R1_2_1.md §2.4): the page left was written on (read before `show` starts a new
    /// visit), so the rating prompt may follow a pause on the new page.
    private func move(by delta: Int) {
        let wroteHere = inkChangedThisVisit
        let lastInk = lastInkChangeAt
        show(kind: kind, focus: PageNavigation.move(kind, focus: focus, by: delta))
        scheduleReviewRequest(leftPageWithInk: wroteHere, lastInkChangeAt: lastInk)
    }

    /// 「今日」. 1.1.1: on the month and year pages today's cell comes on screen too, since a page that
    /// holds a lot is longer than the screen (`show` loads and lays out at once, so `layout` is the
    /// page it opened; the now is `show`'s, 「今日」 in screenshot mode).
    private func goToday() {
        let today = DayKey(ScreenshotMode.current?.today ?? Date())
        show(kind: kind, focus: today)
        revealRect = PageNavigation.todayRect(layout, now: now)
        revealTrigger += 1
    }

    /// Remembers the last shown page for the next launch (not in screenshot mode).
    private func remember() {
        guard !ScreenshotMode.isActive else { return }
        let defaults = UserDefaults.standard
        defaults.set(kind.rawValue, forKey: AppSettings.lastKindKey)
        defaults.set(focus.description, forKey: AppSettings.lastFocusKey)
    }

    // MARK: - Layout

    /// One page's paper from one calendar and one week start (§5.6): the layout's input and the month's
    /// `holidayNames` use the same `holidays` and the same grid, so old and new names cannot mix.
    static func makePaper(kind: PageKind, focus: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date,
                          holidays: HolidayCalendar, weekStart: WeekStart) -> PaperContent {
        let words = LayoutWords.of(L.language)
        switch kind {
        case .month:
            let month = YearMonth(year: focus.year, month: focus.month)
            let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: month, events: events, inkBottoms: inkBottoms, now: now,
                                                                   holidays: holidays, words: words, weekStart: weekStart))
            return .month(MonthPaperContent(
                layout: layout,
                labels: layout.dateLabels,
                bars: layout.allDayBars,
                chips: layout.timedChips,
                holidayNames: holidays.names(for: MonthLayout.grid(for: month, weekStart: weekStart).days)
            ))
        case .week:
            let layout = WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: events, inkBottoms: inkBottoms, now: now,
                                                                 holidays: holidays, words: words, weekStart: weekStart))
            return .week(WeekPaperContent(layout: layout))
        case .day:
            let layout = DayLayoutEngine.layout(DayLayoutInput(day: focus, events: events, inkBottoms: inkBottoms, now: now,
                                                               holidays: holidays, words: words))
            return .day(DayPaperContent(layout: layout))
        case .year:
            let layout = YearLayoutEngine.layout(YearLayoutInput(year: focus.year, events: events, inkBottoms: inkBottoms, now: now,
                                                                 holidays: holidays, words: words))
            return .year(YearPaperContent(layout: layout, monthNames: (1...12).map { DateText.monthName($0, .short, L.language) }))
        }
    }

    private func relayout() {
        paper = Self.makePaper(kind: kind, focus: focus, events: model.events, inkBottoms: page.inkBottoms(), now: now,
                               holidays: HolidayChoice.current, weekStart: weekStart)
    }

    // MARK: - Holidays and the week start (1.2, docs/M7B_CONTRACT.md §5.6, §10.3–§10.5)

    /// The holiday setting changed: the paper's geometry stays (`sameGeometry` keeps the strokes); only its
    /// words and colours are drawn again.
    private func holidaySettingChanged() {
        HolidayChoice.current = holidays
        relayout()
    }

    /// **The order of a switch, and it must not change** (§10.5): the old page is saved in its old form
    /// first (once `pageId` has moved, `pageBinding`'s guard throws its writes away), then the new form
    /// goes in, then the page, its events and its paper are read again. All on one turn. A pure function
    /// over its three steps so that a test can check the order; the screen's own are private.
    static func weekStartSwitch(old: WeekStart, new: WeekStart, save: () -> Void, apply: (WeekStart) -> Void, reload: () -> Void) {
        guard new != old else { return }
        save()
        apply(new)
        reload()
    }

    private func switchWeekStart(to new: WeekStart) {
        Self.weekStartSwitch(
            old: weekStart,
            new: new,
            save: { saveNow() },
            apply: { value in
                weekStart = value
                WeekStartChoice.current = value
                // The new canvas reports its own viewport next turn (`show`, for a page that changes id).
                viewport = .zero
                capNoticedPageId = nil
            },
            reload: { show(kind: kind, focus: focus) }
        )
    }

    /// The record changed (the settings, or an adoption, which has switched already: then nothing happens).
    private func weekStartSettingChanged() {
        guard !ScreenshotMode.isActive else { return }
        switchWeekStart(to: WeekStartChoice.resolve(WeekStartChoice.setting()))
    }

    /// §10.3, 4 (1): the first pull has finished, so the pages iCloud has are here to compare with.
    private func checkWeekStartAfterPull() {
        guard WeekStartChoice.readyToCheck(status: sync.snapshot.status, zoneToken: sync.state.zoneToken) else { return }
        if let adopted = runWeekStartCheck(atBoundary: false) { switchWeekStart(to: adopted) }
    }

    /// §10.3, step 4: compares the pages with an automatic week start that was not compared yet, writes
    /// what the comparison says and queues its toasts. A form to adopt is returned for the caller to
    /// switch to: `show` does so without calling itself. While the person writes (`.wait`) nothing is
    /// written: the comparison is made again at a boundary.
    @discardableResult
    private func runWeekStartCheck(atBoundary: Bool) -> WeekStart? {
        guard !ScreenshotMode.isActive,
              WeekStartChoice.needsDataCheck(setting: WeekStartChoice.setting(), dataChecked: AppSettings.weekStartDataChecked) else {
            pendingAdoption = false
            return nil
        }
        let shown = weekStart
        let other: WeekStart = shown == .monday ? .sunday : .monday
        let result = WeekStartChoice.dataCheck(current: shown, pageIds: sync.allLocalPageIds(), dirtyPageId: pageDirty ? pageId : nil,
                                               penTouched: penTouchedThisLaunch, atBoundary: atBoundary)
        var adopted: WeekStart?
        switch result {
        case .wait:
            pendingAdoption = true
            return nil
        case .finish:
            break
        case .stay(let otherPages):
            weekStartNotices.add(.otherForm(other, pages: otherPages))
        case .adopt(let form, let otherPages):
            weekStartRaw = form.rawValue
            weekStartNotices.add(.adopted(form))
            if otherPages > 0 { weekStartNotices.add(.otherForm(shown, pages: otherPages)) }
            adopted = form
        }
        AppSettings.weekStartDataChecked = true
        pendingAdoption = false
        showNextWeekStartNotice()
        return adopted
    }

    /// D17, §10.2: a month page with strokes on days the current week start does not show says so once
    /// per page and form. They are not drawn, not erased, and not moved. Marked when really shown.
    private func noticeHiddenInk() {
        guard !ScreenshotMode.isActive else { return }
        weekStartNotices.dropHiddenInk()
        let hidden = WeekStartImpact.hiddenStrokeIds(in: page, weekStart: weekStart)
        guard !hidden.isEmpty, !AppSettings.weekStartHiddenNoticed(page.pageId, weekStart) else { return }
        weekStartNotices.add(.hiddenInk(pageId: page.pageId, strokes: hidden.count))
        showNextWeekStartNotice()
    }

    /// One waiting toast of the week start, if it can be seen now (§10.4): no sheet, no account question
    /// up or on its way, no other toast. Called when one is added, when a sheet closes and when a toast
    /// goes away. 6 s: the sentences are long. Screenshot mode has none.
    private func showNextWeekStartNotice() {
        guard !ScreenshotMode.isActive, !showAccountChange, !accountChangePending,
              let notice = weekStartNotices.next(sheetIsUp: sheetIsUp, toastShowing: toast != nil, currentPageId: pageId) else { return }
        if case .hiddenInk(let id, _) = notice {
            AppSettings.markWeekStartHiddenNoticed(id, weekStart)
        }
        showToast(notice.text, duration: Self.strokeBudgetNoticeDuration)
    }

    /// A sheet closed: the waiting toast is looked at once the next sheet, if any, is up (§10.4). It then
    /// waits for that one to close.
    private func scheduleWeekStartNotice() {
        weekStartNoticeTask?.cancel()
        let delay = Self.weekStartNoticeDelay(firstPaywallDue: !paywallShownAfterOnboarding)
        weekStartNoticeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            // A cancelled sleep returns at once, so the check is needed (like `schedulePinchHint`'s).
            guard !Task.isCancelled else { return }
            showNextWeekStartNotice()
        }
    }

    /// The canvas reports that ink may have grown past a band's bottom. The relayout is deferred one
    /// turn so the page binding (written just before or after this call) is already up to date.
    private func inkBoundsChanged() {
        Task { @MainActor in
            relayout()
        }
    }

    // MARK: - Remote updates (M4 contract §5.4)

    /// `SyncEngine.onRemoteUpdate`: the engine wrote `updated` (merged with the file) for some page.
    /// Only the shown page matters here; it is merged with the page in memory (a stroke drawn in the
    /// last 1.5 s is not yet in the file) and handed to the canvas, which reloads the ledger with
    /// the history kept. The canvas's own `refreshSelection` drops the ids that died; the selection
    /// is not cleared here.
    private func applyRemote(_ updated: InkPage) {
        guard updated.pageId == pageId else { return }
        // ペンを離した直後の未保存の線を落とさない。merge の後に帯の線を grid へ（M4B contract §3.3）
        let merged = BandMigration.migrate(InkPage.merge(page, updated))
        guard merged.contentDiffers(from: page) || merged.updatedAt != page.updatedAt else { return }
        page = merged                                       // Binding を通さない（dirty にしない）
        if merged.contentDiffers(from: updated) {           // 端末内にしか無い線があった → いつもの経路で保存・送信
            pageDirty = true
            scheduleSave()
        }
        relayout()
    }

    // MARK: - Taps

    /// The smallest date target on screen (pt; 1.0.1's year page, 1.1 `DateTap.minPoints` for the month
    /// and the year).
    static let minTapTarget: CGFloat = DateTap.minPoints

    /// 1.0.1: the screens whose year page gets the 44 pt date target — an iPhone in either orientation,
    /// and any window narrower than `compactWidth` (an iPad's narrow split view, where the header takes
    /// two rows as on an iPhone). An iPad at full width keeps 1.0's target (it works there: about
    /// 24 × 17 pt at the 13-inch overview, docs/R1_0_1.md §2).
    static func usesMinTapTarget(isPhone: Bool, width: CGFloat) -> Bool {
        isPhone || width < compactWidth
    }

    /// What a finger tap at `point` (lu) does at `zoom` (1.1, M7A_CONTRACT §4.1 / §4.5, D4): exactly
    /// `DateTap.target` (the name is 1.0.1's).
    /// - With 「指でも書く」 off, the month's and the year's dates are at least 44 pt on screen.
    /// - On a small screen (`usesMinTapTarget`) the year's are 44 pt whatever the setting (1.0.1).
    /// - With 「指でも書く」 on, the month keeps 1.0's date frame (M7A-1), and so does the year on a
    ///   large screen (M7A-2: an iPad with it off gets 44 pt).
    /// - The year's left gutter number opens that day of `currentMonth` (P-13). It is the whole row,
    ///   except with 「指でも書く」 on a large screen, where only the number counts. A day this month
    ///   does not have is nothing (M7A-3).
    /// - The week and the day are `layout.hit(at:)` unchanged.
    /// - A zoom that is not a positive number leaves the month and the year at `hit(at:)` (plus the
    ///   gutter).
    static func tapTarget(layout: any PageLayout, point: CGPoint, zoom: CGFloat,
                          smallScreen: Bool, allowFinger: Bool, currentMonth: Int) -> HitTarget? {
        DateTap.target(layout: layout, point: point, zoom: zoom, smallScreen: smallScreen,
                       allowFinger: allowFinger, currentMonth: currentMonth)
    }

    /// 1.0.1: whether a tap on `target` takes the screen to another page (`handleTap`: 「+n件」 and a
    /// date open the day page; a bar, a chip or a box opens the edit sheet over this page).
    static func leavesPage(_ target: HitTarget?) -> Bool {
        switch target {
        case .moreChips, .date: return true
        case .allDayBar, .timedChip, .timedBox, nil: return false
        }
    }

    /// M3b contract §4.5: bars, chips and boxes open the edit sheet; 「+n件」, date numbers, the date
    /// areas of `tapTarget` (1.0.1 / 1.1), the year's gutter numbers and thin chips open the day page.
    /// `zoom` is the canvas's when it recognised the tap (the one `tapLeavesPage` used).
    private func handleTap(at point: CGPoint, zoom: CGFloat, smallScreen: Bool) {
        // 1.2.1 (docs/R1_2_1.md §9.2): a finger's tap on the paper stops the rating prompt's wait too. (A
        // finger that only scrolls is not reported by the canvas, one of the 18 frozen files.)
        reviewTask?.cancel()
        guard let hit = Self.tapTarget(layout: layout, point: point, zoom: zoom, smallScreen: smallScreen,
                                       allowFinger: allowFinger, currentMonth: currentMonth) else { return }
        switch hit {
        case .allDayBar(let id), .timedChip(let id), .timedBox(let id):
            openEdit(eventId: id)
        case .moreChips(let day), .date(let day):
            show(kind: .day, focus: day)
        }
    }

    /// M4C contract §5.1 (D5): a finger double tap on the week / month / year canvas goes to the day
    /// under it (`layout.dayAt(point:)`: nil on the memo area, the gutters, a date that does not exist
    /// and the centring margins). The day page never gets here (`doubleTapEnabled: false`).
    private func handleDoubleTap(at point: CGPoint) {
        guard kind != .day, let day = layout.dayAt(point: point) else { return }
        show(kind: .day, focus: day)
    }

    // MARK: - Canvas callbacks

    /// Apple Pencil double tap / squeeze (DESIGN §3.11): the current tool (pen, marker, lasso, event
    /// tool) ⇄ eraser; back to the last pen / marker (M3b contract §4.7). 1.1 (§2.4): the Pencil's
    /// eraser never returns to the pen by itself (`EraserOrigin.pencil`).
    private func togglePencilTool() {
        if tool.isEraser {
            tool = lastInkTool
        } else {
            tool = .eraser
            eraserOrigin = .pencil
        }
    }

    /// Undo / redo availability from the canvas's ledger. Applied one turn later: the canvas may
    /// report it while SwiftUI is updating views, when state must not change.
    private func historyChanged(canUndo newCanUndo: Bool, canRedo newCanRedo: Bool) {
        guard newCanUndo != canUndo || newCanRedo != canRedo else { return }
        Task { @MainActor in
            canUndo = newCanUndo
            canRedo = newCanRedo
        }
    }

    private func selectionChanged(_ newSelection: InkSelection?) {
        guard newSelection != selection else { return }
        selection = newSelection
    }

    /// The 予定 tool finished: a tap on a bar / chip / box edits that event, anything else creates one
    /// from the rect (month / year: that day all-day; week / day: the half hour under the tap, 1 h).
    private func eventRectFinished(_ rect: CGRect, _ isTap: Bool) {
        if isTap, let hit = layout.hit(at: CGPoint(x: rect.midX, y: rect.midY)) {
            switch hit {
            case .allDayBar(let id), .timedChip(let id), .timedBox(let id):
                openEdit(eventId: id)
                return
            case .moreChips, .date:
                break
            }
        }
        // M5 (M5_CONTRACT §3.1): insurance — the tool cannot be chosen while read only (a tap on an
        // existing event above still opens the read-only sheet).
        guard isAllowed(.createEvent) else { blocked(.createEvent); return }
        switch Self.newEventPlan(layout: layout, rect: rect, now: now) {
        case .refusedBelowDay:
            showToast(Self.eventBelowDayToast)
        case .create(let range):
            openCreate(range: range, snapshot: nil, inkIds: [])
        }
    }

    /// What a rect for a new event gives (1.1, M7A_CONTRACT §3.7, 0-4): on the day page a rect that
    /// starts at or below 24:00 (`DayPageLayout.startsBelowDay`, asked before `eventRange`) is refused
    /// — the screen shows `eventBelowDayToast` and opens nothing. Everything else is
    /// `layout.eventRange(for:now:)` unchanged (a day rect across 24:00, or from 2,399.9, is still a
    /// 23:00 event).
    enum NewEventPlan: Equatable {
        case refusedBelowDay
        case create(EventRange?)
    }

    static func newEventPlan(layout: any PageLayout, rect: CGRect, now: Date) -> NewEventPlan {
        if let day = layout as? DayPageLayout, day.startsBelowDay(rect) {
            return .refusedBelowDay
        }
        return .create(layout.eventRange(for: rect, now: now))
    }

    /// The 予定 tool's live preview: the rect the event made from `rect` would occupy.
    private func eventPreview(_ rect: CGRect) -> CGRect? {
        layout.previewRect(for: rect, now: now)
    }

    /// Asks the canvas to do one thing (M3b contract §3.3: a new trigger value runs `command` once).
    private func send(_ newCommand: CanvasCommand) {
        command = newCommand
        commandTrigger += 1
    }

    // MARK: - Events (M3b contract §4.5)

    /// 「＋予定」: today 9:00〜10:00 on the week / day page, today all-day on the month / year page.
    private func addEvent() {
        let today = DayKey(now)
        let range: EventRange
        switch kind {
        case .week, .day:
            range = .timed(today, startMinute: 9 * 60, endMinute: 10 * 60)
        case .month, .year:
            range = .allDay(today)
        }
        openCreate(range: range, snapshot: nil, inkIds: [])
    }

    /// Lasso → 「予定にする」: the range of the selection's bounding box, the strokes' picture on top
    /// of the sheet, and the strokes to erase after a successful save.
    private func convertSelection() {
        guard let selection = selection, !selection.ids.isEmpty else { return }
        // 1.1 (§3.7): handwriting below 24:00 on the day page does not become an event.
        guard case .create(let range) = Self.newEventPlan(layout: layout, rect: selection.bbox, now: now) else {
            showToast(Self.eventBelowDayToast)
            return
        }
        let strokes = selection.ids.compactMap { page.strokes[$0] }
        let snapshot = InkSnapshot.render(strokes: strokes, cells: layout.cells)
        openCreate(range: range, snapshot: snapshot, inkIds: selection.ids)
    }

    private func openCreate(range: EventRange?, snapshot: UIImage?, inkIds: [String]) {
        // M5 (M5_CONTRACT §3.1): every way of creating an event (＋予定, the event tool, 「予定にする」,
        // a band column, the screenshot mode's `.create`) is stopped here while read only.
        guard isAllowed(.createEvent) else { blocked(.createEvent); return }
        guard model.status.canRead else {
            showToast(L.text("toast.event.noAccess"), isError: true)
            return
        }
        let calendars = model.writableCalendarOptions
        guard let first = calendars.first else {
            showToast(L.text("toast.event.noCalendar"), isError: true)
            return
        }
        guard let range = range else { return }
        let calendarId = model.defaultCalendarId ?? first.id
        editor = EventEditorRequest(
            mode: .create,
            draft: EventDraft(range: range, calendarId: calendarId),
            calendars: calendars,
            snapshot: snapshot,
            inkIds: inkIds,
            pageId: pageId
        )
    }

    private func openEdit(eventId: String) {
        guard let detail = model.detail(forEventId: eventId) else { return }
        // M5 (M5_CONTRACT §3.1): viewing is allowed while read only; editing is not.
        let mode: EventEditorMode = readOnly
            ? .readOnly(eventId: eventId)
            : (model.isEditable(eventId: eventId)
                ? .edit(eventId: eventId, recurring: model.isRecurring(eventId: eventId))
                : .readOnly(eventId: eventId))
        let option = model.calendarOptions.first { $0.id == detail.calendarId } ?? CalendarOption(
            id: detail.calendarId,
            title: detail.calendarTitle,
            colorHex: detail.colorHex,
            sourceTitle: "",
            isWritable: detail.isEditable,
            isSubscribed: false,
            isBirthday: false
        )
        editor = EventEditorRequest(
            mode: mode,
            draft: EventDraft(detail: detail),
            calendars: [option],
            snapshot: nil,
            inkIds: [],
            pageId: pageId
        )
    }

    /// The sheet's `onSubmit`: writes through the model, closes the sheet, erases converted
    /// handwriting (when asked and the page is still the same), remembers the calendar, toasts.
    /// A throw propagates to the sheet, which shows it and stays open.
    private func handleSubmit(_ request: EventEditorRequest, _ result: EventEditorResult) async throws {
        switch result {
        case .cancel:
            editor = nil

        case .save(let draft, let span, let eraseInk):
            // M5 (M5_CONTRACT §3.1): insurance (the sheet is read only while the app is).
            guard isAllowed(.editEvent) else { blocked(.editEvent); editor = nil; return }
            switch request.mode {
            case .create:
                try model.create(draft)
                editor = nil
                model.setDefaultCalendarId(draft.calendarId)
                if !request.inkIds.isEmpty, eraseInk, request.pageId == pageId {
                    send(.removeStrokes(request.inkIds))
                } else if selection != nil {
                    send(.clearSelection)
                }
                showToast(L.text("toast.event.created"))
            case .edit(let eventId, _):
                try model.update(eventId: eventId, with: draft, span: span ?? .thisEvent)
                editor = nil
                showToast(L.text("toast.event.updated"))
            case .readOnly:
                editor = nil
            }

        case .delete(let span):
            guard isAllowed(.editEvent) else { blocked(.editEvent); editor = nil; return }
            guard case .edit(let eventId, _) = request.mode else {
                editor = nil
                return
            }
            try model.delete(eventId: eventId, span: span ?? .thisEvent)
            editor = nil
            showToast(L.text("toast.event.deleted"))
        }
    }

    // MARK: - Settings: erase everything (M4 contract §6.2)

    /// 「この端末の手書きを全て消す」 after both confirmations: close the settings, stop the pending
    /// save, empty the shown page (the canvas reloads it), then let the engine delete every page file
    /// and every iCloud record. iCloud failing leaves the local part erased and the engine retries
    /// the cloud part at the next sync. Screenshot mode only empties the page in memory.
    private func eraseAllInk() {
        showSettings = false
        saveTask?.cancel()
        saveTask = nil
        page = InkPage.empty(pageId: pageId)
        pageDirty = false
        selection = nil
        relayout()
        guard !ScreenshotMode.isActive else {
            showToast(L.text("toast.erased"))
            return
        }
        Task { @MainActor in
            do {
                try await sync.eraseEverything()
                showToast(L.text("toast.erased"))
            } catch {
                showToast(L.text("toast.eraseCloudFailed"), isError: true)
            }
        }
    }

    // MARK: - Web import (M4 contract §6.3)

    /// 「Web 版の手書きを取り込む」: close the settings, then show the file picker.
    private func importWeb() {
        // M5 (M5_CONTRACT §3.1, M5-15): the import is a feature of the paid notebook. `blocked` runs
        // while the settings are still up so the paywall waits for them to close (or the toast shows
        // once they have); then the settings close either way.
        guard isAllowed(.webImport) else { blocked(.webImport); showSettings = false; return }
        showSettings = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.sheetGap))
            showImportPicker = true
        }
    }

    /// The picker returned a file (a temporary copy): read it, then show the progress sheet and run
    /// the import.
    private func pickedImportFile(_ url: URL) {
        showImportPicker = false
        let accessed = url.startAccessingSecurityScopedResource()
        let read = Result { try Data(contentsOf: url) }
        if accessed { url.stopAccessingSecurityScopedResource() }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.sheetGap))
            importPhase = .reading
            switch read {
            case .failure:
                importPhase = .failed(WebImportSheet.invalidJSONText)
            case .success(let data):
                await runImport(data)
            }
        }
    }

    /// Parse (off the main actor: a big export takes a moment; `InkImport` reads the app's own
    /// format page by page, M6_CONTRACT §1.2) → `sync.importPages`. The finished sentence says which
    /// format it was (`isAppExport`, 0-12). 1.1 (M7A_CONTRACT §5.2): when a page would have more than
    /// 20,000 strokes on this device afterwards (`StrokeCensus.pagesOverLegacyCap`, counted off the main
    /// actor without writing anything), the sheet asks first (`confirmLarge`); the read file waits in
    /// `pendingImport`. Nothing is stopped: 1.1 shows every stroke, only an older device would not.
    private func runImport(_ data: Data) async {
        let parsed: Result<InkImport.Outcome, Error> = await Task.detached(priority: .userInitiated) {
            Result { InkImport.pages(try InkImport.parse(data)) }
        }.value
        let outcome: InkImport.Outcome
        switch parsed {
        case .failure(let error):
            importPhase = .failed(Self.importFailureText(error))
            return
        case .success(let value):
            outcome = value
        }
        let skipped = outcome.skipped
        guard !outcome.pages.isEmpty else {
            importPhase = .done(ImportOutcome(pagesChanged: 0, strokesAdded: 0, pagesSeen: outcome.pageCount), skipped: skipped, isAppExport: outcome.isAppExport)
            return
        }
        let large = await StrokeCensus.pagesOverLegacyCap(outcome.pages, store: sync.store)
        if !large.isEmpty {
            pendingImport = outcome
            importPhase = .confirmLarge(pages: large.map { StrokeBudget.pageLabel($0, language: L.language) })
            return
        }
        await importPages(of: outcome)
    }

    /// `sync.importPages` with its progress, then `.done` or `.failed`. 1.2 (§10.5), in this order: the
    /// comparison with an automatic week start (`runWeekStartCheck`: someone without iCloud gets no first
    /// pull, so an import of the app's own file is the moment), then the sentence about the other form,
    /// made with the week start after it, so the sentence and the setting agree.
    private func importPages(of outcome: InkImport.Outcome) async {
        importPhase = .importing(done: 0, total: outcome.pages.count)
        do {
            let imported = try await sync.importPages(outcome.pages) { done, total in
                importPhase = .importing(done: done, total: total)
            }
            if WeekStartChoice.checksAfterImport(status: sync.snapshot.status, zoneToken: sync.state.zoneToken, isAppExport: outcome.isAppExport),
               let adopted = runWeekStartCheck(atBoundary: false) {
                switchWeekStart(to: adopted)
            }
            let otherWeekStart = WeekStartChoice.otherForm(amongPageIds: outcome.pages.map(\.pageId), current: weekStart)
            importPhase = .done(imported, skipped: outcome.skipped, isAppExport: outcome.isAppExport, otherWeekStart: otherWeekStart)
        } catch {
            importPhase = .failed(WebImportSheet.saveFailedText(error))
        }
    }

    /// 〔取り込む〕 of the large-page question (1.1, §5.2): the file that was read is imported as usual.
    private func confirmLargeImport() {
        guard case .confirmLarge = importPhase, let outcome = pendingImport else { return }
        pendingImport = nil
        // In progress at once: the sheet can no longer be swiped away (or 〔取り込む〕 pressed again)
        // before the task below starts.
        importPhase = .importing(done: 0, total: outcome.pages.count)
        Task { @MainActor in
            await importPages(of: outcome)
        }
    }

    /// The `.failed` text of a parse error (M4 contract §6.3, step 3; `InkImport.parse` throws the
    /// same `WebImport.ParseError`, M6_CONTRACT §1.2). Internal so `CalendarRootScreenTests` can pin it.
    static func importFailureText(_ error: Error) -> String {
        switch error as? WebImport.ParseError {
        case .notAnExport:
            return WebImportSheet.notAnExportText
        case .unsupportedVersion(let version):
            return WebImportSheet.unsupportedVersionText(version)
        case .invalidJSON, .none:
            return WebImportSheet.invalidJSONText
        }
    }

    /// 「閉じる」 (or a swipe when done / failed): the result becomes a toast. 1.1 (§5.2): 〔やめる〕 of the
    /// large-page question (or a swipe) comes here too — nothing was imported and there is no toast.
    private func closeImportSheet() {
        pendingImport = nil
        guard let phase = importPhase else { return }
        importPhase = nil
        if case .done(let outcome, let skipped, let isAppExport, let otherWeekStart) = phase {
            showToast(WebImportSheet.toastText(outcome: outcome, skipped: skipped, isAppExport: isAppExport, otherWeekStart: otherWeekStart))
        }
    }

    // MARK: - Export (M6_CONTRACT §3.3)

    /// 「手書きを書き出す」: the page on the screen is saved now (its last 1.5 s go into the store the
    /// JSON reads), the settings close, then the sheet opens on its two choices. Allowed while read
    /// only (`GatedAction.export`, D1), so there is no guard.
    private func openExport() {
        saveNow()
        showSettings = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.sheetGap))
            exportPhase = .choose
        }
    }

    /// One of the two buttons: the JSON of every stored page (with its page progress) or the PDF
    /// of the shown page (after a 50 ms pause so SwiftUI draws the spinner first: the render is
    /// synchronous on the main actor, about a second). Success → `.done`; a failure with a text →
    /// `.failed`; a cancellation → the sheet just closes.
    private func runExport(_ exportKind: ExportKind) {
        exportPhase = .building(exportKind, done: 0, total: exportKind == .pdf ? 1 : 0)
        exportTask?.cancel()
        exportTask = Task { @MainActor in
            let builder = ExportBuilder(store: sync.store)
            let outcome: Result<ExportResult, Error>
            do {
                switch exportKind {
                case .json:
                    outcome = .success(try await builder.exportJSON { done, total in
                        // A late report of a cancelled export, or one after the sheet closed, must not
                        // reopen the sheet (the closure runs as part of the builder's worker task).
                        guard !Task.isCancelled, case .building = exportPhase else { return }
                        exportPhase = .building(.json, done: done, total: total)
                    })
                case .pdf:
                    try? await Task.sleep(for: .milliseconds(50))
                    try Task.checkCancellation()
                    outcome = .success(try builder.exportPDF(paper: paper, page: page, kind: kind, focus: focus))
                }
            } catch {
                outcome = .failure(error)
            }
            // Cancelled (the sheet was closed while building, or a newer export started): the sheet's
            // state belongs to whoever cancelled; nothing here may touch it.
            guard !Task.isCancelled else { return }
            switch outcome {
            case .success(let result):
                exportPhase = .done(result)
            case .failure(let error):
                if let text = ExportSheet.failureText(error) {
                    exportPhase = .failed(text)
                } else {
                    exportPhase = nil
                }
            }
        }
    }

    /// 「閉じる」 (or a swipe): a failure's text becomes an error toast (6 s). The export directory is
    /// not emptied here (0-14: the share sheet's destination may still be reading the file; the
    /// next export cleans up first).
    private func closeExportSheet() {
        guard let phase = exportPhase else { return }
        exportTask?.cancel()
        exportTask = nil
        exportPhase = nil
        if case .failed(let text) = phase {
            showToast(text, isError: true)
        }
    }

    // MARK: - Account change (M4 contract §6.4)

    /// The engine's status changed: the first time it becomes `.accountMismatch`, ask (after any
    /// sheet that is up has closed).
    private func syncStatusChanged() {
        // 1.2 (§10.3, 4 (1)): the first pull may just have finished.
        checkWeekStartAfterPull()
        guard sync.snapshot.status == .accountMismatch else { return }
        presentAccountChange()
    }

    /// 「新しいアカウントで使い始める…」 in the settings: close them, then ask.
    private func resolveAccountChangeFromSettings() {
        showSettings = false
        accountChangePending = true
    }

    private func presentAccountChange() {
        if sheetIsUp {
            accountChangePending = true
        } else {
            showAccountChange = true
        }
    }

    /// A sheet opened or closed: a waiting account question is asked once nothing is up. 1.1.1: the
    /// pinch hint waits for nothing being up too; 1.2 (§10.4): and the week start's toasts; 1.2.2
    /// (docs/R1_2_2.md §3.1): and the age range.
    private func sheetsChanged() {
        if !sheetIsUp {
            schedulePinchHint()
            scheduleWeekStartNotice()
            askAgeRangeIfDue()
        }
        guard accountChangePending, !sheetIsUp else { return }
        accountChangePending = false
        guard sync.snapshot.status == .accountMismatch else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.sheetGap))
            guard !sheetIsUp, sync.snapshot.status == .accountMismatch else { return }
            showAccountChange = true
        }
    }

    /// The answer: the engine adopts the new account (keeping or erasing the ink) or waits; the shown
    /// page is read again afterwards (empty after 「消して始める」).
    private func chooseAccount(_ choice: AccountChangeChoice) {
        if choice == .keepInk {
            saveNow() // a stroke of the last 1.5 s goes along with the rest
        }
        Task { @MainActor in
            await sync.resolveAccountChange(choice)
            // 1.2.2 (docs/R1_2_2.md §12.2): every answer, from the dialog or from the erase alert (which
            // `showAccountChange` does not cover, so the age range step may have stepped aside for it).
            askAgeRangeIfDue()
            guard choice != .later, !ScreenshotMode.isActive else { return }
            reloadShownPage()
        }
    }

    /// Reads the shown page from the engine again (after the account answer). The band migration
    /// runs here too (M4B contract §3.3): the ledger migrates on its `reload`, but the page in
    /// memory would otherwise keep the old cells until the next stroke.
    private func reloadShownPage() {
        saveTask?.cancel()
        saveTask = nil
        let loaded = sync.load(pageId)
        page = BandMigration.migrate(loaded)
        pageDirty = false
        if page != loaded {
            pageDirty = true
            scheduleSave()
        }
        relayout()
    }

    // MARK: - Subscription and read only (M5 contract §3.1, §4.2)

    /// 許す操作は access に依らず true。止める操作は access.canEdit
    static func isAllowed(_ action: GatedAction, access: AccessState) -> Bool {
        !action.isGated || access.canEdit
    }

    private func isAllowed(_ action: GatedAction) -> Bool {
        Self.isAllowed(action, access: access)
    }

    /// 止めた: 1 セッション 1 回はペイウォール（reason .blocked(action)）、2 回目以降はトースト（§3.3）。写真モードはトーストだけ
    private func blocked(_ action: GatedAction) {
        if !ScreenshotMode.isActive, !blockedPaywallShownThisSession {
            blockedPaywallShownThisSession = true
            showPaywall(reason: .blocked(action))
        } else {
            showToast(Self.readOnlyToast)
        }
    }

    /// The canvas reports a Pencil touch on the read-only paper: `blocked(.draw)` at most every 2 s.
    private func blockedInput() {
        let now = Date()
        if let last = lastBlockedInputAt, now.timeIntervalSince(last) < Self.blockedInputInterval { return }
        lastBlockedInputAt = now
        blocked(.draw)
    }

    /// Presents the paywall. Another sheet up (settings, the editor, the file picker) is closed first
    /// and the paywall follows after `sheetGap` (SwiftUI cannot present two at once; the `importWeb()`
    /// way). The reason is updated even while the paywall is already up.
    private func showPaywall(reason: PaywallReason) {
        paywallReason = reason
        guard !showPaywall else { return }
        if showSettings || editor != nil || showImportPicker {
            showSettings = false
            editor = nil
            showImportPicker = false
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.sheetGap))
                showPaywall = true
            }
        } else {
            showPaywall = true
        }
    }

    /// Once after the onboarding (and on every launch until it happened), when the first `refresh()`
    /// finishes within 3 s and says: not subscribed, store reached, prices present (M5-33). A
    /// subscriber only sets the flag. Not finished / unreachable / no prices: nothing, and the flag
    /// stays false so the next launch tries again (a 「—」 price screen is never the first meeting).
    private func scheduleFirstLaunchPaywall() {
        guard !ScreenshotMode.isActive, !paywallShownAfterOnboarding else { return }
        // 1.2.2 (docs/R1_2_2.md §3.1): the age range waits for this decision.
        firstPaywallPending = true
        Task { @MainActor in
            defer {
                firstPaywallPending = false
                askAgeRangeIfDue()
            }
            try? await Task.sleep(for: .seconds(Self.sheetGap))
            let done = await store.awaitFirstRefresh(timeout: .seconds(Self.firstRefreshTimeout))
            let s = store.snapshot
            if done && s.access.canEdit {
                paywallShownAfterOnboarding = true // a subscriber never sees it (§8-6 の 9)
                return
            }
            guard done, !s.access.canEdit, s.storeReachable, !s.offers.isEmpty else { return }
            paywallShownAfterOnboarding = true
            showPaywall(reason: .firstLaunch)
        }
    }

    /// `store.snapshot.message` changed: a purchase or a restore that succeeded becomes a toast (the
    /// paywall closes itself on the same message). The toast comes one turn later so the paywall's own
    /// `onChange` sees the message before it is cleared. While the settings are up, their footer shows
    /// the restore's result instead (cleared when they close).
    private func messageChanged() {
        guard let message = store.snapshot.message else { return }
        switch message {
        case .purchased, .restored:
            guard !showSettings else { return }
            let text = StoreStrings.text(for: message, access: access)
            Task { @MainActor in
                store.clearMessage()
                showToast(text)
            }
        case .nothingToRestore, .pending, .productsUnavailable, .failed:
            break
        }
    }

    /// The app turned read only: the lasso / 予定 tool goes back to the last pen, the selection is cleared.
    private func readOnlyChanged() {
        guard readOnly else { return }
        if tool.isOverlayTool {
            tool = lastInkTool
        }
        send(.clearSelection)
    }

    /// The toolbar's tool: while read only the lasso / 予定 tool cannot be chosen (`blocked(.overlayTool)`);
    /// the pen / marker colours and widths and the eraser may change (harmless). 1.1 (§2.4): an eraser
    /// chosen here (also when it was already the eraser) is the toolbar's, which returns to the pen.
    private var toolBinding: Binding<CanvasTool> {
        Binding(
            get: { tool },
            set: { newValue in
                // 1.2.1 (docs/R1_2_1.md §9.2): a tool chosen on the bar stops the rating prompt's wait.
                reviewTask?.cancel()
                if readOnly, newValue.isOverlayTool {
                    blocked(.overlayTool)
                    return
                }
                if newValue.isEraser {
                    eraserOrigin = .toolbar
                }
                tool = newValue
            }
        )
    }

    /// The compact (iPhone) notice row under the header while read only (§3.2, M5-13): the wide
    /// header shows the badge instead.
    @ViewBuilder
    private func readOnlyNotice(compact: Bool) -> some View {
        if compact, readOnly {
            noticeRow(Self.readOnlyNoticeText, buttonTitle: Self.readOnlyNoticeButton) {
                showPaywall(reason: .badge)
            }
        }
    }

    // MARK: - Toast

    /// Shows `text` above the toolbar for 3 s (errors 6 s, or `duration`); a newer toast replaces an
    /// older one. M5-24: the screenshot mode's read-only toast passes 20 s. The UI tests
    /// (`--screenshot-probe`) keep every toast 20 s, so a slow simulator still finds it.
    private func showToast(_ text: String, isError: Bool = false, duration: TimeInterval? = nil) {
        let message = ToastMessage(text: text, isError: isError)
        toast = message
        toastTask?.cancel()
        let shown = ScreenshotMode.current?.probe == true
            ? ScreenshotMode.probeToastDuration
            : duration ?? (isError ? ToastView.errorDuration : ToastView.duration)
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(shown))
            if Task.isCancelled { return }
            if toast?.id == message.id { toast = nil }
        }
    }

    // MARK: - The pinch hint (1.1.1, docs/R1_1_1.md)

    /// Waits `pinchHintDelay`, then shows the hint once: not over a sheet, the onboarding, the account
    /// question or another toast, and not while the app is away (it would count as shown, unseen). A wait
    /// that finds any of those leaves `pinchHintShown` false, so the next `sheetsChanged`, return to the
    /// foreground or launch waits again.
    private func schedulePinchHint() {
        guard Self.pinchHintDue(shown: pinchHintShown, hasPinched: AppSettings.hasPinched, sandbox: InkTrace.isAvailable,
                                screenshot: ScreenshotMode.isActive, testHost: SyncEngine.isTestHost) else { return }
        pinchHintTask?.cancel()
        pinchHintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.pinchHintDelay))
            // A cancelled sleep returns at once, so the check is needed (like `showToast`'s).
            guard !Task.isCancelled, UIApplication.shared.applicationState == .active, !sheetIsUp, onboardingDone, !pinchHintShown,
                  toast == nil, !showAccountChange else { return }
            pinchHintShown = true
            showToast(Self.pinchHintToast, duration: Self.pinchHintDuration)
        }
    }

    /// A real pinch began (`scrollViewWillBeginZooming`): the person knows it, the hint is never shown.
    private func pinchBegan() {
        // 1.2.1 (docs/R1_2_1.md §2.4): a pinch on the new page stops the rating prompt's wait.
        reviewTask?.cancel()
        guard !ScreenshotMode.isActive else { return }
        pinchHintShown = true
        pinchHintTask?.cancel()
        pinchHintTask = nil
    }

    // MARK: - The age range (1.2.2, docs/R1_2_2.md §3)

    /// At a calm moment of this launch (`AgeAssurance.canAskNow`), the steps of `AgeAssurance.nextStep`:
    /// read Apple's flag, and only where it says a law requires it, the system's sheet, once. Nothing in
    /// screenshot mode, the XCTest host, on a Mac or Apple Vision Pro, or on iOS 17.0–26.1. Called from
    /// `appear`, `.active`, `sheetsChanged`, the account question's close and its answer, the save-failed
    /// alert's close, a toast's change, the first-launch paywall's decision and the wait after fresh ink.
    private func askAgeRangeIfDue() {
        guard appeared, ageRangeTask == nil, !AgeRangeAsker.finished else { return }
        guard canAskAgeRangeNow else {
            askAgeRangeAfterInkIfWriting()
            return
        }
        ageRangeTask = Task { @MainActor in
            defer { ageRangeTask = nil }
            while true {
                let step = AgeAssurance.nextStep(band: AgeRangeAsker.band, signal: AgeRangeAsker.signal,
                                                 askedThisLaunch: AgeRangeAsker.askedThisLaunch,
                                                 screenshot: ScreenshotMode.isActive, testHost: SyncEngine.isTestHost,
                                                 onMac: AgeRangeAsker.onMac)
                switch step {
                case .stop:
                    AgeRangeAsker.finished = true
                    return
                case .readRegulatoryFeatures, .readEligibility:
                    AgeRangeAsker.signal = await AgeRangeAsker.read(step)
                case .requestAgeRange:
                    try? await Task.sleep(for: .seconds(AgeAssurance.settle))
                    // Something came up in the meantime (or anything is presented over the root, `anchor`):
                    // not asked; the next calm moment tries again (fresh ink has no such moment, so it looks
                    // again `quietAfterInk` later).
                    guard canAskAgeRangeNow, let anchor = AgeRangeAsker.anchor() else {
                        askAgeRangeAfterInkIfWriting()
                        return
                    }
                    AgeRangeAsker.askedThisLaunch = true
                    ageRangeAsking = true
                    await AgeRangeAsker.request(in: anchor)
                    ageRangeAsking = false
                }
            }
        }
    }

    /// Fresh ink is the one wait that no other moment ends (the pen just stops): look again `quietAfterInk`
    /// seconds later, and again while the person keeps writing. One wait at a time; the flag is not read again.
    private func askAgeRangeAfterInkIfWriting() {
        guard ageRangeInkWait == nil, ageRangeInkIsRecent else { return }
        ageRangeInkWait = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AgeAssurance.quietAfterInk))
            ageRangeInkWait = nil
            askAgeRangeIfDue()
        }
    }

    /// A stroke ended (`lastInkChangeAt`) or began (`ageRangePenDownAt`) in the last `quietAfterInk` seconds.
    /// The touch counts too, so the sheet does not come while the first stroke after a pause is being
    /// written; a single stroke longer than `quietAfterInk` is not covered (docs/R1_2_2.md §12.2).
    private var ageRangeInkIsRecent: Bool {
        let now = Date()
        func recent(_ instant: Date?) -> Bool {
            instant.map { now.timeIntervalSince($0) < AgeAssurance.quietAfterInk } ?? false
        }
        return recent(lastInkChangeAt) || recent(ageRangePenDownAt)
    }

    private var canAskAgeRangeNow: Bool {
        AgeAssurance.canAskNow(active: UIApplication.shared.applicationState == .active, onboardingDone: onboardingDone,
                               sheetIsUp: sheetIsUp, accountQuestion: showAccountChange, saveFailed: saveError != nil,
                               firstPaywallPending: firstPaywallPending, toastShowing: toast != nil,
                               inkRecently: ageRangeInkIsRecent)
    }

    // MARK: - The rating prompt (1.2.1, docs/R1_2_1.md §2)

    /// After ◀ ▶ from a page written on, a pause on the new page, then StoreKit's rating prompt when
    /// everything of §2.3 holds. Nothing in screenshot mode, the XCTest host or a sandbox build. 1.2.2
    /// (docs/R1_2_2.md §3.7): nor before this launch's age range steps are finished.
    private func scheduleReviewRequest(leftPageWithInk: Bool, lastInkChangeAt: Date?) {
        let instant = Date()
        guard reviewAllowedNow,
              AgeRangeAsker.finished,
              ReviewPrompt.isCalmMoment(leftPageWithInk: leftPageWithInk,
                                        secondsSinceInk: lastInkChangeAt.map { instant.timeIntervalSince($0) },
                                        secondsActive: instant.timeIntervalSince(activeSince)),
              ReviewPrompt.isDue(AppSettings.reviewRecord, today: DayKey(instant), version: Self.marketingVersion, access: access)
        else { return }
        reviewTask?.cancel()
        reviewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ReviewPrompt.pauseOnNewPage))
            let today = DayKey(Date())
            // A cancelled sleep returns at once, so the check is needed (like `schedulePinchHint`'s).
            guard !Task.isCancelled,
                  Self.reviewCanShowNow(active: UIApplication.shared.applicationState == .active, sheetIsUp: sheetIsUp,
                                        accountQuestion: showAccountChange, saveFailed: saveError != nil,
                                        onboardingDone: onboardingDone, toastShowing: toast != nil),
                  ReviewPrompt.isDue(AppSettings.reviewRecord, today: today, version: Self.marketingVersion, access: access)
            else { return }
            // Recorded before the call: StoreKit never says whether it showed the prompt (Apple's sample
            // does the same).
            AppSettings.reviewRecord = ReviewPrompt.requested(AppSettings.reviewRecord, today: today, version: Self.marketingVersion)
            reviewRequestTrigger += 1
        }
    }

    /// The first day of use, once (`appear`). Nothing where the prompt is never asked for.
    private func noteReviewUse() {
        guard reviewAllowedNow else { return }
        let record = AppSettings.reviewRecord
        let next = ReviewPrompt.usedOn(record, today: DayKey(Date()))
        if next != record { AppSettings.reviewRecord = next }
    }

    /// A day with the person's own ink (`pageBinding`): written only when the record changes (the first
    /// change of a day), not on every stroke.
    private func noteReviewInk() {
        guard reviewAllowedNow else { return }
        let record = AppSettings.reviewRecord
        let next = ReviewPrompt.inkWritten(record, today: DayKey(Date()))
        if next != record { AppSettings.reviewRecord = next }
    }

    /// `reviewAllowedHere` for this process.
    private var reviewAllowedNow: Bool {
        Self.reviewAllowedHere(screenshot: ScreenshotMode.isActive, testHost: SyncEngine.isTestHost, sandbox: InkTrace.isAvailable)
    }

    /// The rating prompt is asked for (and its record kept) only in an App Store build: not in screenshot
    /// mode (the CI's photos and the UI tests), not in the XCTest host, and not in a sandbox-receipt build
    /// (TestFlight, App Review, Xcode), where StoreKit shows nothing or would show it to the reviewer.
    static func reviewAllowedHere(screenshot: Bool, testHost: Bool, sandbox: Bool) -> Bool {
        !screenshot && !testHost && !sandbox
    }

    /// At the end of the pause: the app in front, no sheet (the settings, an event, the import, the export,
    /// the paywall, the onboarding), no account question, no save-failed alert (◀ ▶ saves the page it
    /// leaves, so a failure there would meet the prompt 2 s later), the onboarding done and no toast.
    static func reviewCanShowNow(active: Bool, sheetIsUp: Bool, accountQuestion: Bool, saveFailed: Bool,
                                 onboardingDone: Bool, toastShowing: Bool) -> Bool {
        active && !sheetIsUp && !accountQuestion && !saveFailed && onboardingDone && !toastShowing
    }

    /// The app's version (CFBundleShortVersionString, "1.2.1"): the prompt is asked for once per version.
    static var marketingVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    // MARK: - Screenshot mode (M3b contract §5, M4 contract §6.6)

    private func showScreenshotSheet(_ sheet: ScreenshotMode.Sheet) {
        switch sheet {
        case .create:
            let month = ScreenshotMode.current?.month ?? YearMonth(year: focus.year, month: focus.month)
            openCreate(range: .allDay(ScreenshotMode.createDemoDay(for: month)), snapshot: nil, inkIds: [])
        case .edit:
            openEdit(eventId: ScreenshotMode.editDemoEventId)
        case .lasso:
            tool = .lasso
        case .settings, .sync, .info, .holidays, .weekStart:
            // All show the settings screen; the demo engine supplies 「同期済み」 and 「最後に同期」, `info`
            // (1.1) scrolls to 「情報」 with `StrokeCensus.demo(year:)`, and the settings open the picker of
            // the holidays or the question of the week start themselves (1.2, §7.4, §10.7).
            showSettings = true
        case .`import`:
            importPhase = .done(ScreenshotMode.importDemoOutcome, skipped: 0, isAppExport: false)
        case .paywall:
            // M5 contract §7.5: the trial-eligible sample over the month page.
            paywallReason = .firstLaunch
            showPaywall = true
        case .export:
            // M6 contract §3.5 / 0-6: the two choices as the reviewer sees them (nothing is written).
            exportPhase = .choose
        }
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if Task.isCancelled { return }
            saveNow()
        }
    }

    /// Writes the page now (through the engine, which also queues it for iCloud) if it changed since
    /// the last save.
    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard pageDirty, !ScreenshotMode.isActive else { return }
        do {
            try sync.save(page)
            pageDirty = false
        } catch {
            saveError = error.localizedDescription
        }
    }
}
