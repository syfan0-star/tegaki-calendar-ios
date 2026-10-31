import Access
import Layout
import StoreKit
import SwiftUI
import UIKit

/// The settings sheet (M3b contract §4.8, M4 contract §6.2, M5 contract §4.3, M6 contract §3.1,
/// DESIGN §2.8): calendars (shown, default, access, Google how-to), input (finger, Pencil,
/// erase-after-convert), sync (the iCloud state, the last sync, 「今すぐ同期」, the account question),
/// data (import from the web version or the app's own data file, 「手書きを書き出す」 (M6, usable while
/// read only too), erase everything confirmed twice), purchase (the plan and its date from
/// `store.snapshot`, 「購読する」 while read only, 「サブスクリプションを管理」, 「購入を復元」 with the
/// result under the footer), and the info links (`LegalLinks`). 1.1 (M7A_CONTRACT §2.6 / §5.3 / §6.1):
/// 入力 has 「消しゴムで消したらペンに戻る」 (`AppSettings.eraserAutoReturn`), 情報 has the two stroke
/// counts of this device (`StrokeCensus`, counted in the background while the sheet is open) and a
/// footer, and the device is 「この端末」 everywhere (an iPhone too).
struct SettingsScreen: View {
    @ObservedObject var model: EventStoreModel
    @ObservedObject var sync: SyncEngine
    @Binding var allowFinger: Bool
    /// 「許可する」 while the permission is undecided.
    var onRequestAccess: () async -> Void
    /// 「今すぐ同期」 (`Task { await sync.syncNow() }`).
    var onSyncNow: () -> Void
    /// 「Web 版の手書きを取り込む」: the owner closes this sheet and shows the file picker (§6.3).
    var onImportWeb: () -> Void
    /// Called after the second confirmation; the owner empties the page and asks the engine (§6.2).
    var onEraseAllInk: () -> Void
    /// 「新しいアカウントで使い始める…」: the owner shows the account question (§6.4).
    var onResolveAccountChange: () -> Void
    var onDone: () -> Void
    /// Screenshot mode's `sync` sheet (M4 contract §6.6): scroll to the 「同期」 section once the form
    /// is on screen, because the section sits below the fold on an iPad (DESIGN §2.8 order).
    var scrollToSyncOnAppear: Bool = false
    /// M5 (M5_CONTRACT §4.3): the store behind 「購入」 (the plan, its date, 「購入を復元」, the result line).
    @ObservedObject var store: StoreModel
    /// 「購読する」/「14 日間無料で試す」: the owner closes this sheet and shows the paywall (reason .settings).
    var onShowPaywall: () -> Void = {}
    /// Reserved for a screenshot of the 「購入」 section (M5 does not use it): scroll there on appear.
    var scrollToPurchaseOnAppear: Bool = false
    /// 「手書きを書き出す」 (M6 contract §3.1): the owner closes this sheet and shows `ExportSheet`.
    /// Allowed while read only (`GatedAction.export`), so the row is never greyed.
    var onExport: () -> Void = {}
    /// Screenshot mode's `info` sheet (1.1, M7A_CONTRACT §7.3): scroll to the 「情報」 section once the
    /// form is on screen (the same way as `scrollToSyncOnAppear`).
    var scrollToInfoOnAppear: Bool = false

    @Environment(\.openURL) private var openURL
    @State private var eraseInkAfterConvert: Bool = ScreenshotMode.isActive ? true : AppSettings.eraseInkAfterConvert
    /// 1.1 (§2.6): 「消しゴムで消したらペンに戻る」, on in screenshot mode (nothing is stored there).
    @State private var eraserAutoReturn: Bool = ScreenshotMode.isActive ? true : AppSettings.eraserAutoReturn
    /// 1.1 (§5.3): the stroke counts of 情報; nil until `StrokeCensus` has counted (「数えています…」).
    @State private var census: StrokeCensus.Result?
    @State private var confirmEraseStep1 = false
    @State private var confirmEraseStep2 = false
    @State private var requestingAccess = false
    /// 「今すぐ同期」 shows a spinner for one second after the tap.
    @State private var syncingNow = false
    /// 「サブスクリプションを管理」 → `.manageSubscriptionsSheet` (M5-21).
    @State private var showManage = false

    /// The id of the first row of the 「同期」 section (the scroll target of `scrollToSyncOnAppear`).
    private static let syncRowId = "sync-section"
    /// The id of the first row of the 「購入」 section (`scrollToPurchaseOnAppear`).
    private static let purchaseRowId = "purchase-section"
    /// The id of the first row of the 「情報」 section (`scrollToInfoOnAppear`).
    private static let infoRowId = "info-section"

    /// The same steps as the first onboarding card (OnboardingView, DESIGN §2.10). 1.1 (§6.1): the
    /// 「設定」 app of whichever device, and the OS name of both.
    static let googleHowTo = "Google カレンダーの予定を出すには、「設定」アプリで Google アカウントを追加します。\n①「設定」→「アプリ」→「カレンダー」→「カレンダーアカウント」→「アカウントを追加」→「Google」（iOS・iPadOS 17 では「設定」→「カレンダー」→「アカウント」）\n②「カレンダー」のスイッチをオン\n③同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定の反映が早くなります。\n\niCloud カレンダーだけの人は、このままで大丈夫です。"

    // MARK: 1.1 texts (M7A_CONTRACT §2.6 / §5.3 / §6.2)

    /// 設定 › 入力: the row of the eraser's return to the pen.
    static let eraserAutoReturnTitle = "消しゴムで消したらペンに戻る"

    /// The footer of that row: the Apple Pencil sentences only on an iPad (an iPhone's settings never
    /// speak of the Pencil, like the 「Apple Pencil」 row, which only an iPad has).
    static func eraserAutoReturnFooter(isPad: Bool) -> String {
        isPad
            ? "ツールバーで選んだ消しゴムで線を消して指や Apple Pencil を離すと、直前のペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムは戻りません。"
            : "ツールバーで選んだ消しゴムで線を消して指を離すと、直前のペンかマーカーに戻ります。"
    }

    /// 設定 › 情報: the two rows of the stroke counts (values: `StrokeCensus.rowText` / `yearRowText`).
    static let largestPageTitle = "いちばん線の多いページ"
    static let yearPageTitle = "今年の年のページ"
    /// The footer of 情報.
    static let infoFooter = "線の数は、この端末に保存されているページを数えたものです（どこにも送りません）。1 ページに書ける線は 19,000 本までです。"

    /// The data section's footer (M4 contract §6.2).
    static let importFooter = "Web 版の設定で「手書きを書き出す（iPad アプリ用）」をして、そのファイルを選びます。同じファイルを二度取り込んでも手書きは二重になりません。"

    /// The data section's second paragraph (M6 contract §3.1 / §3.6): what 「手書きを書き出す」 makes,
    /// and that the data file goes back in through the import row (while subscribed).
    static let exportFooter = "「手書きを書き出す」は、この端末に保存されている手書きを 1 つのデータファイル（JSON）にするか、いま開いているページを PDF にします。データファイルは「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。"

    /// "0.5.0 (1)" from the bundle.
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info?["CFBundleVersion"] as? String) ?? "—"
        return "\(short) (\(build))"
    }

    /// 「2026/10/07 9:57」 on a Japanese iPad, "10/7/26, 9:57 AM" in CI's English locale.
    static func timeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .shortened))
    }

    /// The 「最後に同期」 value: the time, or 「まだありません」.
    static func lastSyncText(_ date: Date?) -> String {
        date.map(timeText) ?? "まだありません"
    }

    /// 「前回の取り込み: 2026/10/14 9:41」 under the data footer; nil when nothing was imported yet.
    static func webImportedText(_ date: Date?) -> String? {
        date.map { "前回の取り込み: " + timeText($0) }
    }

    /// 「今すぐ同期」 is inert while there is no account to sync with or a round is running.
    static func canSyncNow(_ status: SyncStatus) -> Bool {
        switch status {
        case .localOnly, .accountMismatch, .syncing: return false
        case .synced, .pending, .offline, .error: return true
        }
    }

    /// Whether erasing also reaches iCloud (the engine deletes the records in these states; M4
    /// contract §4.5 の 10). The two confirmations say so.
    static func erasesCloud(_ status: SyncStatus) -> Bool {
        switch status {
        case .synced, .pending, .syncing, .offline, .error: return true
        case .localOnly, .accountMismatch: return false
        }
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var status: SyncStatus { sync.snapshot.status }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    calendarSection
                    inputSections
                    syncSection
                    dataSection
                    purchaseSection
                    infoSection
                }
                .navigationTitle("設定")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了", action: onDone)
                            .fontWeight(.semibold)
                    }
                }
                .confirmationDialog(eraseQuestion, isPresented: $confirmEraseStep1, titleVisibility: .visible) {
                    Button("消す", role: .destructive) {
                        // The second question is an alert; it can only appear once the dialog is gone.
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.35))
                            confirmEraseStep2 = true
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                }
                .alert("本当に消しますか？", isPresented: $confirmEraseStep2) {
                    Button("全て消す", role: .destructive, action: onEraseAllInk)
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text(eraseWarning)
                }
                .onChange(of: eraseInkAfterConvert) {
                    guard !ScreenshotMode.isActive else { return }
                    AppSettings.eraseInkAfterConvert = eraseInkAfterConvert
                }
                .onChange(of: eraserAutoReturn) {
                    guard !ScreenshotMode.isActive else { return }
                    AppSettings.eraserAutoReturn = eraserAutoReturn
                }
                .onAppear {
                    guard scrollToSyncOnAppear || scrollToPurchaseOnAppear || scrollToInfoOnAppear else { return }
                    // The list needs a layout pass before it can scroll; the row lands a little below
                    // the top so the section header stays in view.
                    let target = scrollToSyncOnAppear ? Self.syncRowId : scrollToInfoOnAppear ? Self.infoRowId : Self.purchaseRowId
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: 0.08))
                    }
                }
                // 1.1 (§5.3): count the pages while the sheet is open; closing it cancels the count.
                .task { await countStrokes() }
                .manageSubscriptionsSheet(isPresented: $showManage)
            }
        }
        // A restore's result line is for this visit only (the paywall does the same).
        .onDisappear { store.clearMessage() }
    }

    // MARK: - カレンダー

    private struct SourceGroup: Identifiable {
        var id: String { source }
        var source: String
        var calendars: [CalendarOption]
    }

    /// The calendars grouped by account (`sourceTitle`), sources and titles sorted.
    private var sourceGroups: [SourceGroup] {
        let options = model.calendarOptions
        let sources = Array(Set(options.map { $0.sourceTitle })).sorted()
        return sources.map { source in
            SourceGroup(source: source, calendars: options.filter { $0.sourceTitle == source }.sorted { $0.title < $1.title })
        }
    }

    private var calendarSection: some View {
        Section("カレンダー") {
            Text("表示するカレンダー")
                .font(.subheadline.weight(.semibold))
            if sourceGroups.isEmpty {
                Text(model.status.canRead ? "カレンダーがありません" : "カレンダーへのアクセスを許可すると、ここに一覧が出ます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sourceGroups) { group in
                    Text(group.source.isEmpty ? "その他" : group.source)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(group.calendars) { option in
                        calendarRow(option)
                    }
                }
            }
            let writable = model.writableCalendarOptions
            if !writable.isEmpty {
                Picker("予定の登録先", selection: defaultCalendarBinding(writable)) {
                    ForEach(writable) { option in
                        HStack(spacing: 8) {
                            colorDot(option.colorHex)
                            Text(option.title)
                        }
                        .tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            HStack {
                Text("カレンダーへのアクセス")
                Spacer()
                Text(accessText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            accessButton
            DisclosureGroup("Google カレンダーを使うには") {
                Text(Self.googleHowTo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("設定アプリを開く", action: openSettingsApp)
            }
        }
    }

    private func calendarRow(_ option: CalendarOption) -> some View {
        let hidden = model.isHidden(calendarId: option.id)
        return Button {
            model.setHidden(!hidden, calendarId: option.id)
        } label: {
            HStack(spacing: 10) {
                colorDot(option.colorHex)
                Text(option.title)
                    .foregroundStyle(.primary)
                Spacer()
                if !hidden {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(hidden ? "非表示" : "表示中")
        .accessibilityAddTraits(hidden ? [] : .isSelected)
    }

    private func colorDot(_ hex: String) -> some View {
        Circle()
            .fill(Color(uiColor: PaperPalette.color(hex: hex)))
            .frame(width: 10, height: 10)
    }

    private func defaultCalendarBinding(_ writable: [CalendarOption]) -> Binding<String> {
        Binding(
            get: {
                if let id = model.defaultCalendarId, writable.contains(where: { $0.id == id }) { return id }
                return writable.first?.id ?? ""
            },
            set: { model.setDefaultCalendarId($0) }
        )
    }

    private var accessText: String {
        switch model.status {
        case .fullAccess: return "許可されています（フルアクセス）"
        case .notDetermined: return "まだ許可していません"
        case .denied: return "許可されていません"
        case .writeOnly: return "追加のみ（予定を表示できません）"
        case .restricted: return "この端末では制限されています"
        }
    }

    @ViewBuilder
    private var accessButton: some View {
        switch model.status {
        case .notDetermined:
            Button {
                guard !requestingAccess else { return }
                requestingAccess = true
                Task { @MainActor in
                    await onRequestAccess()
                    requestingAccess = false
                }
            } label: {
                if requestingAccess {
                    ProgressView()
                } else {
                    Text("許可する")
                }
            }
            .disabled(requestingAccess)
        case .denied, .writeOnly:
            Button("設定アプリを開く", action: openSettingsApp)
        case .fullAccess, .restricted:
            EmptyView()
        }
    }

    // MARK: - 入力

    @ViewBuilder
    private var inputSections: some View {
        Section {
            Toggle("指でも書く", isOn: $allowFinger)
        } header: {
            Text("入力")
        } footer: {
            Text("オンにすると指でも線が引けます。オフのときは指でスクロールとタップをします。手書きは iPad と Apple Pencil で書くのに向いています")
        }
        // 1.1 (§2.6): on the iPad and the iPhone; the footer speaks of the Pencil only on an iPad.
        Section {
            Toggle(Self.eraserAutoReturnTitle, isOn: $eraserAutoReturn)
        } footer: {
            Text(Self.eraserAutoReturnFooter(isPad: isPad))
        }
        if isPad {
            Section {
                HStack {
                    Text("Apple Pencil")
                    Spacer()
                    Button("設定アプリを開く", action: openSettingsApp)
                }
            } footer: {
                Text("ダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作に従います")
            }
        }
        Section {
            Toggle("予定にした手書きを消す", isOn: $eraseInkAfterConvert)
        } footer: {
            Text("投げなわで囲んだ手書きを予定にしたあと、その手書きを消すかどうかの初期値です")
        }
    }

    // MARK: - 同期 (M4 contract §6.2)

    private var syncSection: some View {
        Section {
            HStack {
                Text("iCloud 同期")
                Spacer()
                Text(status.settingsText)
                    .foregroundStyle(status.isError ? Color.red : Color.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .id(Self.syncRowId)
            HStack {
                Text("最後に同期")
                Spacer()
                Text(Self.lastSyncText(sync.snapshot.lastSyncAt))
                    .foregroundStyle(.secondary)
            }
            Button(action: syncNow) {
                if syncingNow {
                    ProgressView()
                } else {
                    Text("今すぐ同期")
                }
            }
            .disabled(!Self.canSyncNow(status) || syncingNow)
            if status == .accountMismatch {
                Button("新しいアカウントで使い始める…", action: onResolveAccountChange)
            }
        } header: {
            Text("同期")
        } footer: {
            Text(status.settingsFooter)
        }
    }

    /// 「今すぐ同期」: one round now, and a spinner for a second so the tap is seen.
    private func syncNow() {
        guard !syncingNow else { return }
        syncingNow = true
        onSyncNow()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            syncingNow = false
        }
    }

    // MARK: - データ

    private var dataSection: some View {
        Section {
            // M5 (M5_CONTRACT §3.1): greyed while read only, but still tappable (the owner then shows
            // the paywall or a toast).
            Button(action: onImportWeb) {
                Text("Web 版の手書きを取り込む")
                    .foregroundStyle(store.isReadOnly ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            }
            // M6 (M6_CONTRACT §3.1, D1): the export is allowed while read only (`GatedAction.export`),
            // so the row keeps its tint in every access state.
            Button(action: onExport) {
                Text("手書きを書き出す")
                    .foregroundStyle(.tint)
            }
            Button("この端末の手書きを全て消す", role: .destructive) {
                confirmEraseStep1 = true
            }
        } header: {
            Text("データ")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.importFooter)
                Text(Self.exportFooter)
                if let imported = Self.webImportedText(sync.snapshot.webImportedAt) {
                    Text(imported)
                }
            }
        }
    }

    /// The first confirmation: whether iCloud's copy goes too.
    private var eraseQuestion: String {
        Self.erasesCloud(status)
            ? "この端末と iCloud に保存した手書きを全て消しますか？"
            : "この端末に保存した手書きを全て消しますか？"
    }

    /// The second confirmation's message.
    private var eraseWarning: String {
        Self.erasesCloud(status)
            ? "この操作は元に戻せません。ほかの iPad や iPhone の手書きも消えます。"
            : "この操作は元に戻せません。"
    }

    // MARK: - 購入 (M5 contract §4.3)

    private var access: AccessState { store.snapshot.access }

    /// 現在のプラン / the date row / 「購読する」 (read only) / サブスクリプションを管理 / 購入を復元, the
    /// footer (`purchaseFooter`) and the last result (`store.snapshot.message`, red when it failed).
    private var purchaseSection: some View {
        let eligible = store.snapshot.offers.first?.isEligibleForIntroOffer ?? false
        let restoring = store.snapshot.phase == .restoring
        let busy = store.snapshot.phase != .idle && store.snapshot.phase != .loadingProducts
        return Section {
            HStack {
                Text("現在のプラン")
                Spacer()
                Text(Self.planText(access))
                    .foregroundStyle(Self.planIsProblem(access) ? Color.red : Color.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .id(Self.purchaseRowId)
            if let label = Self.dateLabel(access), let until = access.until {
                HStack {
                    Text(label)
                    Spacer()
                    Text(Self.dateText(until))
                        .foregroundStyle(.secondary)
                }
            }
            if let title = Self.purchaseButtonTitle(access, eligible: eligible) {
                Button(title, action: onShowPaywall)
            }
            // Also while read only: the place to check a cancelled subscription (M5-21).
            Button("サブスクリプションを管理") {
                guard !ScreenshotMode.isActive else { return }
                showManage = true
            }
            Button(action: restore) {
                if restoring {
                    ProgressView()
                } else {
                    Text("購入を復元")
                }
            }
            .disabled(busy)
        } header: {
            Text("購入")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.purchaseFooter(access))
                if let message = store.snapshot.message {
                    Text(StoreStrings.text(for: message, access: access))
                        .foregroundStyle(Self.isFailure(message) ? Color.red : Color.secondary)
                }
            }
        }
    }

    private func restore() {
        Task { await store.restore() }
    }

    // MARK: - 情報

    private var infoSection: some View {
        Section {
            Link("利用規約", destination: LegalLinks.terms)
                .id(Self.infoRowId)
            Link("プライバシーポリシー", destination: LegalLinks.privacy)
            Link(LegalLinks.appleEULATitle, destination: LegalLinks.appleEULA)
            Link("サポート", destination: LegalLinks.support)
            HStack {
                Text("バージョン")
                Spacer()
                Text(Self.versionText)
                    .foregroundStyle(.secondary)
            }
            // 1.1 (§5.3): counted on this device, before the read cap; 「数えています…」 until done.
            countRow(Self.largestPageTitle, StrokeCensus.rowText(census?.largest, counting: census == nil))
            countRow(Self.yearPageTitle, StrokeCensus.yearRowText(census?.year, year: currentYear, counting: census == nil))
        } header: {
            Text("情報")
        } footer: {
            Text(Self.infoFooter)
        }
    }

    /// A two-line row: the title, and the value under it (footnote, secondary).
    private func countRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// The year of 「今年の年のページ」 (the fixed 「今日」 in screenshot mode).
    private var currentYear: Int {
        DayKey(ScreenshotMode.current?.today ?? Date()).year
    }

    /// Counts the pages of this device (`StrokeCensus.run`, in the background; nil when the sheet
    /// closed first, then nothing changes). Screenshot mode shows the demo pages' counts.
    private func countStrokes() async {
        if ScreenshotMode.isActive {
            census = StrokeCensus.demo(year: currentYear)
            return
        }
        guard let result = await StrokeCensus.run(store: sync.store, year: currentYear) else { return }
        census = result
    }

    private func openSettingsApp() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - 購入 の純関数 (M5 contract §4.3, §7.6)

extension SettingsScreen {
    /// 「現在のプラン」の値（`PlanText.statusTitle`）
    static func planText(_ access: AccessState) -> String {
        PlanText.statusTitle(access)
    }

    /// 日付行のラベル（readOnly は nil。`PlanText.dateLabel`）
    static func dateLabel(_ access: AccessState) -> String? {
        PlanText.dateLabel(access)
    }

    /// 「2026/10/25」 in ja_JP (numeric date, no time). `locale` is an argument so the CI's English
    /// locale can be overridden in the tests.
    static func dateText(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(locale))
    }

    /// The value of 「現在のプラン」 is red while the payment is the problem: `.billingRetry` and `inGrace`.
    static func planIsProblem(_ access: AccessState) -> Bool {
        switch access {
        case .subscribed(let subscription): return subscription.inGrace
        case .trial: return false
        case .readOnly(let reason): return reason == .billingRetry
        }
    }

    /// The footer of 「購入」: how to cancel (plus the trial's reassurance), the payment problem
    /// while in grace, or the read-only reason and what read only still allows.
    static func purchaseFooter(_ access: AccessState) -> String {
        switch access {
        case .subscribed(let subscription):
            if subscription.inGrace {
                return "お支払いに問題があります。端末の\(PlanText.paymentPath)でお支払い方法を確認してください。猶予の期限までは使えます。"
            }
            return cancelFooter
        case .trial:
            return cancelFooter + "試用中に解約すれば料金はかかりません。"
        case .readOnly(let reason):
            return PlanText.readOnlyNote(reason) + readOnlyFooter
        }
    }

    /// 「購読する」 / 「14 日間無料で試す」 while read only; nil otherwise (no row).
    static func purchaseButtonTitle(_ access: AccessState, eligible: Bool) -> String? {
        guard !access.canEdit else { return nil }
        return eligible ? "\(ProductIDs.trialDays) 日間無料で試す" : "購読する"
    }

    /// Red under the footer.
    static func isFailure(_ message: StoreMessage) -> Bool {
        if case .failed = message { return true }
        return false
    }

    private static let cancelFooter = "解約は端末の\(PlanText.cancelPath)から。解約しても期間の終わりまで使えます。"
    /// The same list as 利用規約 第 5 条 5 項 (M6_CONTRACT §3.1 / §5.1: 「手書きの書き出し」 since M6).
    private static let readOnlyFooter = "閲覧専用では、予定と手書きの閲覧、ページ移動、拡大、iCloud からの受信、この端末の手書きを全て消す、手書きの書き出し、設定の変更ができます。新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みは購読すると使えます。"
}
