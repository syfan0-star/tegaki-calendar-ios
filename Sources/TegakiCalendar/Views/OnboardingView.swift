import SwiftUI
import UIKit

/// The four first-run cards (M2 contract §6, M4 contract §6.5, DESIGN §2.10): the calendar account,
/// the full-access permission, pen vs. finger, and iCloud (where the handwriting is kept). The last
/// card's button asks the OS for calendar access; iCloud itself needs no permission dialog (the
/// private database is the person's own iCloud). 1.1 (M7A_CONTRACT §6.1 / §6.2): the cards say
/// 「この端末」 (they are shown on an iPhone too), the first card's how-to is the settings screen's
/// (`SettingsScreen.googleHowTo`), and the third card ends with the taps that open a day page.
struct OnboardingView: View {
    /// Called by the last card's button; it should request access and then dismiss this view.
    var onFinish: () async -> Void

    @Environment(\.openURL) private var openURL
    @State private var index = 0
    @State private var requesting = false

    /// The index of the last card (the one with 「許可の画面を出す」).
    static let lastIndex = 3

    /// The first card: the device's 「カレンダー」, then the same steps as the settings screen.
    static let accountText = "このアプリは、この端末の「カレンダー」に入っている予定を表示します。\n\n" + SettingsScreen.googleHowTo
    /// The second card: why full access.
    static let accessText = "次の画面で、カレンダーへの「フルアクセス」を求めます。予定を手帳のページに表示し、手書きから予定を作るためです。\n\niOS と iPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定はこの端末の中だけで扱い、開発者やほかの誰にも送りません。"
    /// The third card: pen and finger; 1.1 adds the last sentence (the taps that open a day page).
    static let penText = "Apple Pencil で紙に書きます。指はスクロール・ピンチ拡大・予定のタップに使います。手のひらが触れても線は引かれません。\n\n指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。Apple Pencil のダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作どおりにペンと消しゴムを切り替えます。\n\n" + dayPageTapText
    /// The sentence of 1.1 at the end of the third card (§6.2).
    static let dayPageTapText = "年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。"
    /// The fourth card: where the handwriting is kept.
    static let iCloudText = "手書きはこの端末と、あなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きが見られます。\n\niCloud にサインインしていないときは、この端末の中だけに保存します。iCloud の設定は要りません（この端末でサインインしていれば自動で使われます）。\n\n手書きは開発者には見えません。iCloud の容量はあなたのものを使います。"

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                card(
                    symbol: "person.crop.circle.badge.plus",
                    title: "カレンダーのアカウント",
                    text: Self.accountText,
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
                    text: Self.accessText,
                    extra: nil
                )
                .tag(1)

                card(
                    symbol: "pencil.and.scribble",
                    title: "ペンで書き、指で動かす",
                    text: Self.penText,
                    extra: nil
                )
                .tag(2)

                card(
                    symbol: "icloud",
                    title: "iCloud と手書きの保存",
                    text: Self.iCloudText,
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
