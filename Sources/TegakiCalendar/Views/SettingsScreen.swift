import Layout
import SwiftUI
import UIKit

/// The settings sheet (M3b contract §4.8, DESIGN §2.8): calendars (shown, default, access, Google
/// how-to), input (finger, Pencil, erase-after-convert), sync and purchase (「準備中」 until M4 / M5),
/// data (erase everything, confirmed twice), and the info links.
struct SettingsScreen: View {
    @ObservedObject var model: EventStoreModel
    @Binding var allowFinger: Bool
    /// 「許可する」 while the permission is undecided.
    var onRequestAccess: () async -> Void
    /// Called after the second confirmation; the owner removes the files and empties the page.
    var onEraseAllInk: () -> Void
    var onDone: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var eraseInkAfterConvert: Bool = ScreenshotMode.isActive ? true : AppSettings.eraseInkAfterConvert
    @State private var confirmEraseStep1 = false
    @State private var confirmEraseStep2 = false
    @State private var requestingAccess = false

    /// Provisional URLs (M5 fixes them).
    static let termsURL = URL(string: "https://syfan0-star.github.io/tegaki-calendar/ios/terms.html")!
    static let privacyURL = URL(string: "https://syfan0-star.github.io/tegaki-calendar/ios/privacy.html")!
    static let supportURL = URL(string: "https://syfan0-star.github.io/tegaki-calendar/ios/support.html")!

    /// The same steps as the first onboarding card (OnboardingView, DESIGN §2.10).
    static let googleHowTo = "Google カレンダーの予定を出すには、iPad の設定で Google アカウントを追加します。\n①「設定」→「アプリ」→「カレンダー」→「カレンダーアカウント」→「アカウントを追加」→「Google」（iPadOS 17 では「設定」→「カレンダー」→「アカウント」）\n②「カレンダー」のスイッチをオン\n③同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定の反映が早くなります。\n\niCloud カレンダーだけの人は、このままで大丈夫です。"

    /// "0.4.0 (1)" from the bundle.
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info?["CFBundleVersion"] as? String) ?? "—"
        return "\(short) (\(build))"
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        NavigationStack {
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
            .confirmationDialog("この iPad に保存した手書きを全て消しますか？", isPresented: $confirmEraseStep1, titleVisibility: .visible) {
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
                Text("この操作は元に戻せません。")
            }
            .onChange(of: eraseInkAfterConvert) {
                guard !ScreenshotMode.isActive else { return }
                AppSettings.eraseInkAfterConvert = eraseInkAfterConvert
            }
        }
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
        case .restricted: return "この iPad では制限されています"
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

    // MARK: - 同期・データ・購入・情報

    private var syncSection: some View {
        Section {
            preparingRow("iCloud 同期")
        } header: {
            Text("同期")
        } footer: {
            Text("iCloud での同期は次の段階で対応します。いまは手書きをこの iPad の中だけに保存しています。")
        }
    }

    private var dataSection: some View {
        Section("データ") {
            preparingRow("Web 版の手書きを取り込む")
            preparingRow("手書きを書き出す")
            Button("この iPad の手書きを全て消す", role: .destructive) {
                confirmEraseStep1 = true
            }
        }
    }

    private var purchaseSection: some View {
        Section {
            preparingRow("現在のプラン")
            preparingRow("購入を復元")
            preparingRow("サブスクリプションの管理")
        } header: {
            Text("購入")
        } footer: {
            Text("購入は次の段階で対応します。")
        }
    }

    private var infoSection: some View {
        Section("情報") {
            Link("利用規約", destination: Self.termsURL)
            Link("プライバシーポリシー", destination: Self.privacyURL)
            Link("サポート", destination: Self.supportURL)
            HStack {
                Text("バージョン")
                Spacer()
                Text(Self.versionText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A row of a feature that comes in a later milestone: greyed, 「準備中」 on the right, inert.
    private func preparingRow(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("準備中")
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func openSettingsApp() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
