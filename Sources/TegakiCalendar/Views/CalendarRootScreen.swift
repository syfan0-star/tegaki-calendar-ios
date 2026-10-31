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
/// the header (◀ 今日 ▶, the title, the 日/週/月/年 switch, ＋予定, ☁ sync state, ⚙), the sticky
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
/// Overview and zoom (M4c, M4C contract §5.1): a page opens at the ratio stored for its kind
/// (`AppSettings.zoomRatio(for:)`, D4; 1 = the overview `fitAll`, or `--screenshot-zoom`) and the
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
    static let readOnlyToast = "閲覧専用です。書く・消す・予定を作るには購読が必要です"
    /// The compact (iPhone) notice row under the header while read only (§3.2, M5-13).
    static let readOnlyNoticeText = "閲覧専用です。手書きと予定の作成は購読すると使えます。"
    static let readOnlyNoticeButton = "購読する"
    /// A Pencil touch on the read-only paper is reported at most this often (§3.1).
    static let blockedInputInterval: TimeInterval = 2
    /// How long `scheduleFirstLaunchPaywall` waits for the first refresh (§4.2, M5-33).
    static let firstRefreshTimeout: Double = 3
    /// The screenshot mode's read-only toast stays this long so it is in the photo (§7.5, M5-24).
    static let screenshotReadOnlyToastDuration: TimeInterval = 20

    // 1.1 (M7A_CONTRACT §6.2): the four new toasts.
    /// A new stroke was dropped below the last cell's limit, or reached its last step (§3.4; 3 s, once
    /// while the page is open).
    static let growthCapToast = "メモ欄はここまでです"
    /// The 予定 tool or 「予定にする」 below 24:00 on the day page (§3.7, 0-4; 3 s).
    static let eventBelowDayToast = "24 時の下の自由メモ欄では予定を作れません"
    /// The page reached 15,000 strokes (§5.2; 6 s, not an error, once per page on this device).
    static let strokeBudgetManyToast = "このページに書いた線が 15,000 本を超えました。1 ページに書ける線は 19,000 本までです。"
    /// New strokes were refused at 19,000 (§5.2; an error toast, 6 s, at most every 2 s).
    static let strokeBudgetFullToast = "このページはいっぱいです（線 19,000 本）。線を消すと、また書けます。"
    /// How long the 15,000-stroke notice stays (the error toasts' 6 s, without the error colour).
    static let strokeBudgetNoticeDuration: TimeInterval = 6

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
            ? ScreenshotMode.demoPage(kind: startKind, focus: startFocus)
            : InkPage.empty(pageId: PageNavigation.pageId(startKind, focus: startFocus))
        _page = State(initialValue: startPage)
        _paper = State(initialValue: Self.makePaper(kind: startKind, focus: startFocus, events: [], inkBottoms: startPage.inkBottoms(), now: startNow))
    }

    private var pageId: String { PageNavigation.pageId(kind, focus: focus) }

    private var layout: any PageLayout { paper.layout }

    /// Screenshot mode's `lasso` sheet: the canvas selects this stroke once its zoom is known.
    private var initialSelectionIds: [String] {
        ScreenshotMode.current?.sheet == .lasso ? [ScreenshotMode.lassoDemoStrokeId] : []
    }

    private var eraseDefault: Bool {
        ScreenshotMode.isActive ? true : AppSettings.eraseInkAfterConvert
    }

    /// The ratio to the overview the shown page opens at (M4C contract §5.1): `--screenshot-zoom`
    /// in screenshot mode, else the ratio stored for the page's kind (1 = the overview).
    private var currentRatio: CGFloat {
        ScreenshotMode.current?.zoomRatio ?? AppSettings.zoomRatio(for: kind)
    }

    /// The viewport of a page's first frame, before its canvas has reported one: `currentRatio` over
    /// the overview that fits `width` × the paper area (the width alone while `paperArea` is still
    /// `.zero`), centred as the canvas will centre the paper (M4C contract §5.1).
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

    /// The zoom the page is expected to open at (`currentRatio` over the overview's bounds for
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
    private var sheetIsUp: Bool {
        showSettings || editor != nil || showImportPicker || importPhase != nil || exportPhase != nil || showOnboarding || showPaywall
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

    /// The ink the toolbar's eraser will return to (the bracket of its note, §2.4); nil otherwise.
    static func eraserReturnTarget(tool: CanvasTool, origin: EraserOrigin?, setting: Bool, lastInk: CanvasTool) -> CanvasTool? {
        tool.isEraser && origin == .toolbar && setting ? lastInk : nil
    }

    /// This month (the year gutter's day numbers open this month's day, P-13; fixed in screenshot mode).
    private var currentMonth: Int { DayKey(now).month }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < Self.compactWidth
            // The first frame of a page has no report from its canvas yet: the stored ratio over the
            // overview, centred, the same position the canvas starts from (M4B contract §2.6, M4C §5.1).
            let shownViewport = self.shownViewport(width: proxy.size.width)
            VStack(spacing: 0) {
                PageHeaderView(
                    kind: kind,
                    title: compact ? PageNavigation.compactTitle(kind, focus: focus) : PageNavigation.title(kind, focus: focus),
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
                    onReadOnlyTap: { showPaywall(reason: .badge) }
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
                scrollToInfoOnAppear: ScreenshotMode.current?.sheet == .info
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
                pageTitle: PageNavigation.title(kind, focus: focus),
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
        .alert("手書きを保存できませんでした", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
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
        guard ToolbarLogic.modeAfterPenDown(toolbarMode) != toolbarMode else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            toolbarEvent(.penDown)
        }
    }

    /// The canvas: the eraser erased `erased` strokes and the settle wait after the lift is over
    /// (§2.4 / §2.5, D2). The toolbar's eraser goes back to the last pen or marker when the setting is
    /// on; a tool the person chose during the wait stays (`toolAfterErase` is nil unless the tool is
    /// still the eraser).
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
            doubleTapEnabled: kind != .day,
            onDoubleTap: handleDoubleTap,
            onZoomRatioChange: { ratio in
                guard !ScreenshotMode.isActive else { return }
                AppSettings.setZoomRatio(ratio, for: kind)
            },
            onZoomingChange: { zooming in
                frozenLaneZoom = zooming ? shownViewport(width: viewportWidth).zoom : nil
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
        .id(pageId)
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
            noticeRow("予定を表示するにはカレンダーの読み取りを許可してください。", buttonTitle: "許可する") {
                showOnboarding = true
            }
        case .denied, .writeOnly:
            noticeRow("予定を表示するには設定でカレンダーを「フルアクセス」にしてください。", buttonTitle: "設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        case .restricted:
            noticeRow("この端末ではカレンダーへのアクセスが制限されています。手書きだけ使えます。", buttonTitle: nil, action: {})
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
            }
        )
    }

    // MARK: - Lifecycle

    private func appear() {
        guard !appeared else { return }
        appeared = true
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
        show(kind: kind, focus: focus)
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
    }

    private func scenePhaseChanged() {
        switch scenePhase {
        case .background, .inactive:
            saveNow()
            // 1.1 (§2.1): a peeking bar folds when the app goes to the background.
            if scenePhase == .background {
                toolbarEvent(.wentToBackground)
            }
        case .active:
            model.refreshStatus()
            if appeared {
                model.reload()
                relayout()
            }
            // M4 contract §5.3: one sync round on every return to the foreground (catches up what a
            // silent push did not deliver).
            sync.applicationDidBecomeActive()
            // M5 contract §1.4 / M5-9: the subscription is checked on every return to the foreground
            // (an expiry, a cancellation or a renewal shows up here, never from a timer).
            Task { await store.refresh() }
            requestLandscapeOnce()
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
        saveNow()
        let id = PageNavigation.pageId(newKind, focus: newFocus)
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
            loaded = ScreenshotMode.demoPage(kind: newKind, focus: newFocus)
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
        model.load(kind: newKind, focus: newFocus)
        relayout()
    }

    private func move(by delta: Int) {
        show(kind: kind, focus: PageNavigation.move(kind, focus: focus, by: delta))
    }

    private func goToday() {
        let today = DayKey(ScreenshotMode.current?.today ?? Date())
        show(kind: kind, focus: today)
    }

    /// Remembers the last shown page for the next launch (not in screenshot mode).
    private func remember() {
        guard !ScreenshotMode.isActive else { return }
        let defaults = UserDefaults.standard
        defaults.set(kind.rawValue, forKey: AppSettings.lastKindKey)
        defaults.set(focus.description, forKey: AppSettings.lastFocusKey)
    }

    // MARK: - Layout

    private static func makePaper(kind: PageKind, focus: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date) -> PaperContent {
        switch kind {
        case .month:
            let month = YearMonth(year: focus.year, month: focus.month)
            let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: month, events: events, inkBottoms: inkBottoms, now: now))
            return .month(MonthPaperContent(
                layout: layout,
                labels: layout.dateLabels,
                bars: layout.allDayBars,
                chips: layout.timedChips,
                holidayNames: JapaneseHolidays.names(for: MonthLayout.grid(for: month).days)
            ))
        case .week:
            let layout = WeekLayoutEngine.layout(WeekLayoutInput(focus: focus, events: events, inkBottoms: inkBottoms, now: now))
            return .week(WeekPaperContent(layout: layout))
        case .day:
            let layout = DayLayoutEngine.layout(DayLayoutInput(day: focus, events: events, inkBottoms: inkBottoms, now: now))
            return .day(DayPaperContent(layout: layout))
        case .year:
            let layout = YearLayoutEngine.layout(YearLayoutInput(year: focus.year, events: events, inkBottoms: inkBottoms, now: now))
            return .year(YearPaperContent(layout: layout, monthNames: (1...12).map { "\($0)月" }))
        }
    }

    private func relayout() {
        paper = Self.makePaper(kind: kind, focus: focus, events: model.events, inkBottoms: page.inkBottoms(), now: now)
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
            showToast("予定を登録するには、設定でカレンダーへのアクセスを許可してください", isError: true)
            return
        }
        let calendars = model.writableCalendarOptions
        guard let first = calendars.first else {
            showToast("予定を登録できるカレンダーがありません", isError: true)
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
                showToast("予定を登録しました")
            case .edit(let eventId, _):
                try model.update(eventId: eventId, with: draft, span: span ?? .thisEvent)
                editor = nil
                showToast("予定を更新しました")
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
            showToast("予定を削除しました")
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
            showToast("手書きを全て消しました")
            return
        }
        Task { @MainActor in
            do {
                try await sync.eraseEverything()
                showToast("手書きを全て消しました")
            } catch {
                showToast("iCloud の手書きを消せませんでした。この端末の分は消しました。回線が戻ったらもう一度お試しください", isError: true)
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
            importPhase = .confirmLarge(pages: large.map(StrokeBudget.pageLabel))
            return
        }
        await importPages(of: outcome)
    }

    /// `sync.importPages` with its progress, then `.done` or `.failed` (unchanged from M4 / M6).
    private func importPages(of outcome: InkImport.Outcome) async {
        importPhase = .importing(done: 0, total: outcome.pages.count)
        do {
            let imported = try await sync.importPages(outcome.pages) { done, total in
                importPhase = .importing(done: done, total: total)
            }
            importPhase = .done(imported, skipped: outcome.skipped, isAppExport: outcome.isAppExport)
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
        if case .done(let outcome, let skipped, let isAppExport) = phase {
            showToast(WebImportSheet.toastText(outcome: outcome, skipped: skipped, isAppExport: isAppExport))
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

    /// A sheet opened or closed: a waiting account question is asked once nothing is up.
    private func sheetsChanged() {
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
        Task { @MainActor in
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
    /// older one. M5-24: the screenshot mode's read-only toast passes 20 s.
    private func showToast(_ text: String, isError: Bool = false, duration: TimeInterval? = nil) {
        let message = ToastMessage(text: text, isError: isError)
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration ?? (isError ? ToastView.errorDuration : ToastView.duration)))
            if Task.isCancelled { return }
            if toast?.id == message.id { toast = nil }
        }
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
        case .settings, .sync, .info:
            // All three show the settings screen; the demo engine supplies 「同期済み」 and 「最後に同期」,
            // `info` (1.1) scrolls to 「情報」 with `StrokeCensus.demo(year:)`.
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
