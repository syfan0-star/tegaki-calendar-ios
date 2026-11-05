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
    static let accountText = L.format("onboarding.account.text", SettingsScreen.googleHowTo)
    /// The second card: why full access.
    static let accessText = L.text("onboarding.access.text")
    /// The third card: pen and finger; 1.1 adds the last sentence (the taps that open a day page).
    static let penText = L.format("onboarding.pen.text", dayPageTapText)
    /// The sentence of 1.1 at the end of the third card (§6.2).
    static let dayPageTapText = L.text("onboarding.dayPageTap")
    /// The fourth card: where the handwriting is kept.
    static let iCloudText = L.text("onboarding.icloud.text")

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                card(
                    symbol: "person.crop.circle.badge.plus",
                    title: L.text("onboarding.account.title"),
                    text: Self.accountText,
                    extra: AnyView(
                        Button(L.text("onboarding.openSettings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(.bordered)
                    )
                )
                .tag(0)

                card(
                    symbol: "lock.open",
                    title: L.text("onboarding.access.title"),
                    text: Self.accessText,
                    extra: nil
                )
                .tag(1)

                card(
                    symbol: "pencil.and.scribble",
                    title: L.text("onboarding.pen.title"),
                    text: Self.penText,
                    extra: nil
                )
                .tag(2)

                card(
                    symbol: "icloud",
                    title: L.text("onboarding.icloud.title"),
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
                    Button(L.text("onboarding.next")) {
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
                            Text(L.text("onboarding.askPermission"))
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
