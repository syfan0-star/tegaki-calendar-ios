import SwiftUI
import UIKit

/// The four first-run cards (M2 contract §6, M4 contract §6.5, DESIGN §2.10): the calendar account,
/// the full-access permission, pen vs. finger, and iCloud (where the handwriting is kept). The last
/// card's button asks the OS for calendar access; iCloud itself needs no permission dialog (the
/// private database is the person's own iCloud).
struct OnboardingView: View {
    /// Called by the last card's button; it should request access and then dismiss this view.
    var onFinish: () async -> Void

    @Environment(\.openURL) private var openURL
    @State private var index = 0
    @State private var requesting = false

    /// The index of the last card (the one with 「許可の画面を出す」).
    static let lastIndex = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                card(
                    symbol: "person.crop.circle.badge.plus",
                    title: "カレンダーのアカウント",
                    text: "このアプリは iPad の「カレンダー」に入っている予定を表示します。\n\nGoogle カレンダーの予定を出すには、iPad の設定で Google アカウントを追加します。\n①「設定」→「アプリ」→「カレンダー」→「カレンダーアカウント」→「アカウントを追加」→「Google」（iPadOS 17 では「設定」→「カレンダー」→「アカウント」）\n②「カレンダー」のスイッチをオン\n③同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定の反映が早くなります。\n\niCloud カレンダーだけの人は、このままで大丈夫です。",
                    extra: AnyView(
                        Button("設定アプリを開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(.bordered)
                    )
                )
                .tag(0)

                card(
                    symbol: "lock.open",
                    title: "カレンダーへのアクセス",
                    text: "次の画面で、カレンダーへの「フルアクセス」を求めます。予定を手帳のページに表示し、手書きから予定を作るためです。\n\niPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定は iPad の中だけで扱い、開発者やほかの誰にも送りません。",
                    extra: nil
                )
                .tag(1)

                card(
                    symbol: "pencil.and.scribble",
                    title: "ペンで書き、指で動かす",
                    text: "Apple Pencil で紙に書きます。指はスクロール・ピンチ拡大・予定のタップに使います。手のひらが触れても線は引かれません。\n\n指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。Apple Pencil のダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作どおりにペンと消しゴムを切り替えます。",
                    extra: nil
                )
                .tag(2)

                card(
                    symbol: "icloud",
                    title: "iCloud と手書きの保存",
                    text: "手書きはこの iPad と、あなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きが見られます。\n\niCloud にサインインしていないときは、この iPad の中だけに保存します。iCloud の設定は要りません（iPad でサインインしていれば自動で使われます）。\n\n手書きは開発者には見えません。iCloud の容量はあなたのものを使います。",
                    extra: nil
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                Spacer()
                if index < Self.lastIndex {
                    Button("次へ") {
                        withAnimation { index += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        guard !requesting else { return }
                        requesting = true
                        Task { @MainActor in
                            await onFinish()
                            requesting = false
                        }
                    } label: {
                        if requesting {
                            ProgressView()
                        } else {
                            Text("許可の画面を出す")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(requesting)
                }
                Spacer()
            }
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func card(symbol: String, title: String, text: String, extra: AnyView?) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 48)
                Text(title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 520, alignment: .leading)
                if let extra = extra {
                    extra
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }
}
