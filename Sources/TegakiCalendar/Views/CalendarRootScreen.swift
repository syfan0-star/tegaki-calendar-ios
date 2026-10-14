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

/// The app's one screen (M3a contract §4.1, M3b §4.5): the header (◀ 今日 ▶, the title, the
/// 日/週/月/年 switch, ＋予定, ⚙), the sticky heading of the page, the paper with the PencilKit canvas
/// (`InkCanvasView`, 担当 I) and the lasso menu floating over it, the toolbar, the toast, and the
/// sheets (event create / edit / view, settings).
///
/// Flow: `(kind, focus)` is chosen → `saveNow()` → `InkPageStore.load(pageId)` →
/// `EventStoreModel.load(kind:focus:)` → the page's layout engine → `InkCanvasView(...).id(pageId)`.
/// Ink changes are saved 1.5 s after the last one, before leaving the page, and when the app goes to
/// the background. Events changing or the ink growing past a band's bottom re-run the layout with
/// fresh `inkBottoms`. On the week and day pages a 30 s tick moves the now line.
///
/// Events (M3b): the 予定 tool's drag or tap, 「＋予定」 and the lasso's 「予定にする」 open the create
/// sheet with the range `layout.eventRange(for:now:)` produced; a finger tap or a 予定-tool tap on a
/// bar / chip / box opens the edit sheet (read-only for a calendar that cannot be modified). The
/// sheet's `onSubmit` writes through `EventStoreModel`; a throw stays in the sheet, success closes it
/// and shows a toast. Converting handwriting erases the strokes afterwards when the sheet's
/// 「この手書きを消す」 is on (one undoable canvas command).
struct CalendarRootScreen: View {
    @StateObject private var model = EventStoreModel()
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
    /// The last pen / marker, so the Pencil's double tap can go back to it from the eraser.
    @State private var lastInkTool: CanvasTool = .ink(ToolbarPalette.defaultPen)
    @State private var undoTrigger = 0
    @State private var redoTrigger = 0
    @State private var canUndo = false
    @State private var canRedo = false

    @AppStorage(AppSettings.allowFingerKey) private var allowFinger = false
    @AppStorage(AppSettings.allowFingerChosenKey) private var allowFingerChosen = false
    @AppStorage(AppSettings.onboardingDoneKey) private var onboardingDone = false
    @State private var showOnboarding = false

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

    @State private var saveTask: Task<Void, Never>?
    @State private var pageDirty = false
    @State private var saveError: String?
    @State private var appeared = false

    private let store = InkPageStore()

    /// How often the now line is moved (M3a contract §4.1).
    static let nowTickSeconds: Double = 30
    /// Below this width the header takes two rows (M3b contract §4.6).
    static let compactWidth: CGFloat = 600

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
        // The lasso screenshot starts with the lasso tool so the preselected strokes keep their frame.
        _tool = State(initialValue: shot?.sheet == .lasso ? .lasso : .ink(ToolbarPalette.defaultPen))
        _page = State(initialValue: InkPage.empty(pageId: PageNavigation.pageId(startKind, focus: startFocus)))
        _paper = State(initialValue: Self.makePaper(kind: startKind, focus: startFocus, events: [], inkBottoms: [:], now: startNow))
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

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < Self.compactWidth
            VStack(spacing: 0) {
                PageHeaderView(
                    kind: kind,
                    title: PageNavigation.title(kind, focus: focus),
                    compact: compact,
                    onPrevious: { move(by: -1) },
                    onToday: goToday,
                    onNext: { move(by: 1) },
                    onKindChange: { show(kind: $0, focus: focus) },
                    onAddEvent: addEvent,
                    onSettings: { showSettings = true }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                accessNotice
                StickyHeaderView(
                    paper: paper,
                    now: now,
                    onDayTap: { show(kind: .day, focus: $0) },
                    onMonthTap: { show(kind: .month, focus: $0.firstDay) }
                )
                canvas
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .overlay(alignment: .bottom) {
            ZStack {
                if let toast = toast {
                    ToastView(message: toast)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toast)
        }
        .background(Color(uiColor: .systemBackground))
        .safeAreaInset(edge: .bottom) {
            ToolbarView(
                tool: $tool,
                allowFinger: $allowFinger,
                canUndo: canUndo,
                canRedo: canRedo,
                onUndo: { undoTrigger += 1 },
                onRedo: { redoTrigger += 1 }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .onAppear(perform: appear)
        .onChange(of: model.events) { relayout() }
        .onChange(of: scenePhase) { scenePhaseChanged() }
        .onChange(of: tool) {
            if case .ink = tool { lastInkTool = tool }
        }
        .task { await nowTicker() }
        .sheet(item: $editor) { request in
            editorSheet(request)
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(
                model: model,
                allowFinger: $allowFinger,
                onRequestAccess: { await model.requestAccess() },
                onEraseAllInk: eraseAllInk,
                onDone: { showSettings = false }
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                await model.requestAccess()
                onboardingDone = true
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
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

    /// The canvas (担当 I) with the lasso menu floating over it. The argument order follows
    /// M3B_CONTRACT.md §3.3 (the M3a arguments, then the M3b ones).
    private var canvas: some View {
        InkCanvasView(
            layout: layout,
            paper: paper,
            tool: tool,
            allowFinger: allowFinger,
            page: pageBinding,
            initialScrollY: PageNavigation.initialScrollY(layout, now: now),
            onTap: handleTap,
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
            initialSelectionIds: initialSelectionIds
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
        if let selection = selection, editor == nil, !showSettings, tool == .lasso {
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
            onCancel: { editor = nil }
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
            noticeRow("この iPad ではカレンダーへのアクセスが制限されています。手書きだけ使えます。", buttonTitle: nil, action: {})
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
            }
        }
        show(kind: kind, focus: focus)
        if let sheet = ScreenshotMode.current?.sheet {
            // M3b contract §5: open the requested sheet once the canvas is on screen.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                showScreenshotSheet(sheet)
            }
        }
    }

    private func scenePhaseChanged() {
        switch scenePhase {
        case .background, .inactive:
            saveNow()
        case .active:
            model.refreshStatus()
            if appeared {
                model.reload()
                relayout()
            }
        @unknown default:
            break
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
        kind = newKind
        focus = newFocus
        selection = nil
        remember()
        let id = PageNavigation.pageId(newKind, focus: newFocus)
        // Screenshot mode injects its demo strokes in memory; the store is not read or written.
        page = ScreenshotMode.isActive ? ScreenshotMode.demoPage(kind: newKind, focus: newFocus) : store.load(id)
        pageDirty = false
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

    // MARK: - Taps

    /// M3b contract §4.5: bars, chips and boxes open the edit sheet; 「+n件」, date numbers, the year's
    /// weekday letters and thin chips open the day page.
    private func handleTap(at point: CGPoint) {
        guard let hit = layout.hit(at: point) else { return }
        switch hit {
        case .allDayBar(let id), .timedChip(let id), .timedBox(let id):
            openEdit(eventId: id)
        case .moreChips(let day), .date(let day):
            show(kind: .day, focus: day)
        }
    }

    // MARK: - Canvas callbacks

    /// Apple Pencil double tap / squeeze (DESIGN §3.11): the current tool (pen, marker, lasso, event
    /// tool) ⇄ eraser; back to the last pen / marker (M3b contract §4.7).
    private func togglePencilTool() {
        if tool.isEraser {
            tool = lastInkTool
        } else {
            tool = .eraser
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
        openCreate(range: layout.eventRange(for: rect, now: now), snapshot: nil, inkIds: [])
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
        let range = layout.eventRange(for: selection.bbox, now: now)
        let strokes = selection.ids.compactMap { page.strokes[$0] }
        let snapshot = InkSnapshot.render(strokes: strokes, cells: layout.cells)
        openCreate(range: range, snapshot: snapshot, inkIds: selection.ids)
    }

    private func openCreate(range: EventRange?, snapshot: UIImage?, inkIds: [String]) {
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
        let mode: EventEditorMode = model.isEditable(eventId: eventId)
            ? .edit(eventId: eventId, recurring: model.isRecurring(eventId: eventId))
            : .readOnly(eventId: eventId)
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
            guard case .edit(let eventId, _) = request.mode else {
                editor = nil
                return
            }
            try model.delete(eventId: eventId, span: span ?? .thisEvent)
            editor = nil
            showToast("予定を削除しました")
        }
    }

    // MARK: - Settings

    /// 「この iPad の手書きを全て消す」 after both confirmations: stop the pending save, delete every
    /// page file, empty the shown page (the canvas reloads it), and say so. Screenshot mode only
    /// empties the page in memory.
    private func eraseAllInk() {
        showSettings = false
        saveTask?.cancel()
        saveTask = nil
        if !ScreenshotMode.isActive {
            do {
                try store.removeAll()
            } catch {
                showToast("手書きを消せませんでした: \(error.localizedDescription)", isError: true)
                return
            }
        }
        page = InkPage.empty(pageId: pageId)
        pageDirty = false
        selection = nil
        relayout()
        showToast("手書きを全て消しました")
    }

    // MARK: - Toast

    /// Shows `text` above the toolbar for 3 s (errors 6 s); a newer toast replaces an older one.
    private func showToast(_ text: String, isError: Bool = false) {
        let message = ToastMessage(text: text, isError: isError)
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(isError ? ToastView.errorDuration : ToastView.duration))
            if Task.isCancelled { return }
            if toast?.id == message.id { toast = nil }
        }
    }

    // MARK: - Screenshot mode (M3b contract §5)

    private func showScreenshotSheet(_ sheet: ScreenshotMode.Sheet) {
        switch sheet {
        case .create:
            let month = ScreenshotMode.current?.month ?? YearMonth(year: focus.year, month: focus.month)
            openCreate(range: .allDay(ScreenshotMode.createDemoDay(for: month)), snapshot: nil, inkIds: [])
        case .edit:
            openEdit(eventId: ScreenshotMode.editDemoEventId)
        case .lasso:
            tool = .lasso
        case .settings:
            showSettings = true
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

    /// Writes the page now if it changed since the last save.
    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard pageDirty, !ScreenshotMode.isActive else { return }
        do {
            try store.save(page)
            pageDirty = false
        } catch {
            saveError = error.localizedDescription
        }
    }
}
