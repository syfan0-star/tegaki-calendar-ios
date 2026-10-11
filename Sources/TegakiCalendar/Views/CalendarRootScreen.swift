import Holidays
import InkModel
import Layout
import SwiftUI
import UIKit

/// The app's one screen (contract §4.1, replacing M2's `MonthPageScreen`): the header (◀ 今日 ▶,
/// the title, the 日/週/月/年 switch, the calendar menu), the sticky heading of the page, the paper
/// with the PencilKit canvas (`InkCanvasView`, 担当 I), the floating toolbar, and the sheets.
///
/// Flow: `(kind, focus)` is chosen → `saveNow()` → `InkPageStore.load(pageId)` →
/// `EventStoreModel.load(kind:focus:)` → the page's layout engine → `InkCanvasView(...).id(pageId)`.
/// Ink changes are saved 1.5 s after the last one, before leaving the page, and when the app goes to
/// the background. Events changing or the ink growing past a band's bottom re-run the layout with
/// fresh `inkBottoms`. On the week and day pages a 30 s tick moves the now line (the layout's
/// geometry does not change, so the canvas only redraws the paper).
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
    @State private var tool: CanvasTool = .ink(ToolbarPalette.defaultPen)
    /// The last pen / marker, so the Pencil's double tap can go back to it from the eraser.
    @State private var lastInkTool: CanvasTool = .ink(ToolbarPalette.defaultPen)
    @State private var undoTrigger = 0
    @State private var redoTrigger = 0
    @State private var canUndo = false
    @State private var canRedo = false

    @AppStorage("allowFingerDrawing") private var allowFinger = false
    @AppStorage("allowFingerDrawingChosen") private var allowFingerChosen = false
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false

    @State private var detail: EventDetail?

    @State private var saveTask: Task<Void, Never>?
    @State private var pageDirty = false
    @State private var saveError: String?
    @State private var appeared = false

    private let store = InkPageStore()

    /// UserDefaults keys of the last shown page (contract §4.1, §6).
    static let lastKindKey = "lastPageKind"
    static let lastFocusKey = "lastFocusDate"
    /// How often the now line is moved (contract §4.1).
    static let nowTickSeconds: Double = 30

    init() {
        let startNow = ScreenshotMode.current?.today ?? Date()
        let startKind: PageKind
        let startFocus: DayKey
        if let shot = ScreenshotMode.current {
            // CI screenshot mode opens the page it was asked for and never touches the memory.
            startKind = shot.page
            startFocus = shot.focus
        } else {
            let defaults = UserDefaults.standard
            startKind = defaults.string(forKey: Self.lastKindKey).flatMap(PageKind.init(rawValue:)) ?? .month
            startFocus = defaults.string(forKey: Self.lastFocusKey).flatMap(DayKey.init(ymd:)) ?? DayKey(startNow)
        }
        _kind = State(initialValue: startKind)
        _focus = State(initialValue: startFocus)
        _now = State(initialValue: startNow)
        _page = State(initialValue: InkPage.empty(pageId: PageNavigation.pageId(startKind, focus: startFocus)))
        _paper = State(initialValue: Self.makePaper(kind: startKind, focus: startFocus, events: [], inkBottoms: [:], now: startNow))
    }

    private var pageId: String { PageNavigation.pageId(kind, focus: focus) }

    private var layout: any PageLayout { paper.layout }

    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(
                kind: kind,
                title: PageNavigation.title(kind, focus: focus),
                onPrevious: { move(by: -1) },
                onToday: goToday,
                onNext: { move(by: 1) },
                onKindChange: { show(kind: $0, focus: focus) }
            ) {
                if model.status.canRead, !model.calendars.isEmpty {
                    calendarsMenu
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            accessNotice
            StickyHeaderView(
                paper: paper,
                now: now,
                onDayTap: { show(kind: .day, focus: $0) },
                onMonthTap: { show(kind: .month, focus: $0.firstDay) }
            )
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
                onHistoryChanged: historyChanged
            )
            .id(pageId)
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
        .sheet(item: $detail) { item in
            EventDetailSheet(detail: item) { detail = nil }
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

    private var calendarsMenu: some View {
        Menu {
            Section("表示するカレンダー") {
                ForEach(model.calendars, id: \.calendarIdentifier) { calendar in
                    Button {
                        model.setHidden(!model.isHidden(calendar), calendar: calendar)
                    } label: {
                        Label(calendar.title, systemImage: model.isHidden(calendar) ? "circle" : "checkmark.circle.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "calendar")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("表示するカレンダー")
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
            // Pencil only on iPad by default; iPhones and Macs have no Pencil (DESIGN §2.1).
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
        defaults.set(kind.rawValue, forKey: Self.lastKindKey)
        defaults.set(focus.description, forKey: Self.lastFocusKey)
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

    /// Contract §4.4: bars, chips and boxes open the detail sheet; 「+n件」, date numbers, the year's
    /// weekday letters and thin chips open the day page.
    private func handleTap(at point: CGPoint) {
        guard let hit = layout.hit(at: point) else { return }
        switch hit {
        case .allDayBar(let id), .timedChip(let id), .timedBox(let id):
            if let found = model.detail(forEventId: id) {
                detail = found
            }
        case .moreChips(let day), .date(let day):
            show(kind: .day, focus: day)
        }
    }

    // MARK: - Canvas callbacks

    /// Apple Pencil double tap / squeeze (DESIGN §3.11): pen or marker ⇄ eraser.
    private func togglePencilTool() {
        if case .eraser = tool {
            tool = lastInkTool
        } else {
            lastInkTool = tool
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
