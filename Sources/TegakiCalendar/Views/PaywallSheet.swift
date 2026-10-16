import Access
import StoreKit
import SwiftUI
import UIKit

/// Why the paywall is up (M5_CONTRACT §4.1): the lead sentence depends on it.
enum PaywallReason: Equatable {
    /// Once after the onboarding, when the first refresh confirmed there is no subscription (M5-33).
    case firstLaunch
    /// A gated operation was tried (once per session; later tries are a toast, §4.2).
    case blocked(GatedAction)
    /// 設定 › 購入 › 「購読する」
    case settings
    /// The 「閲覧専用」 badge, or the compact notice row under the header.
    case badge
}

/// The purchase sheet (M5_CONTRACT §4.1, D4; DESIGN §2.9 / §7.3 / §7.5; review guideline 3.1.2):
/// the app's name and one sentence, three features, the two plans (年額 on top, selected, 「おすすめ」,
/// 「月あたり ¥200・4 か月分お得」), the trial line, the CTA, the price after the trial, Apple's
/// auto-renewal disclosure (the billing moment differs with the trial eligibility), 「購入を復元」 /
/// 「利用規約」 / 「プライバシーポリシー」 / the standard EULA, and 「あとで」. Everything it shows comes from
/// `store.snapshot`; prices are always StoreKit's `displayPrice` (the fixed 「¥2,400」 lives in the
/// screenshot mode's `StoreModel.screenshotDemo` only). The words are static pure functions so
/// `PaywallSheetTests` can pin them (§7.6).
struct PaywallSheet: View {
    @ObservedObject var store: StoreModel
    var reason: PaywallReason = .settings
    /// 「あとで」・スワイプ・購入成功の後
    var onClose: () -> Void

    @State private var selected: Plan = .yearly
    /// 〔サブスクリプションを管理〕 while the payment failed (`.manageSubscriptionsSheet`, M5-21).
    @State private var showManage = false
    @Environment(\.openURL) private var openURL

    // MARK: - Words (pure; M5_CONTRACT §3.3, §4.1, §7.6)

    static let title = "てがきカレンダー"
    /// `.firstLaunch` / `.settings` / `.badge`
    static let intro = "iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。"
    /// `.blocked` (§3.3)
    static let blockedLead = "書く・消す・予定を作るには購読が必要です。"
    static let blockedTrial = "\(ProductIDs.trialDays) 日間無料で試せます。"
    /// `access == .readOnly(.billingRetry)`, whatever the reason (§3.3)
    static let billingRetryLead = "お支払いに問題があります。\(PlanText.paymentPath)でお支払い方法を確認してください。"
    /// `access == .readOnly(.revoked)` (§3.3)
    static let revokedLead = "購入が返金または取り消されました。再び使うには購読してください。"
    /// The three `Label` rows.
    static let features: [String] = [
        "手書き（ペン・マーカー・消しゴム・投げなわ）",
        "手書きから予定を作る。予定の作成・編集",
        "iCloud で iPad・iPhone と同期",
    ]
    static let featureSymbols: [String] = ["pencil.tip", "calendar.badge.plus", "icloud"]
    /// The cards' order: 年額 on top.
    static let planOrder: [Plan] = [.yearly, .monthly]
    static let recommended = "おすすめ"
    /// The price while `offers` is empty, and the note under the card.
    static let noPrice = "—"
    static let noPriceNote = "価格を取得できません"
    static let reloadTitle = "再読み込み"
    static let restoreTitle = "購入を復元"
    static let termsTitle = "利用規約"
    static let privacyTitle = "プライバシーポリシー"
    static let laterTitle = "あとで"
    static let manageTitle = "サブスクリプションを管理"
    /// The bold start of the eligible trial line.
    static let trialLead = "\(ProductIDs.trialDays) 日間無料でお試し。"
    static let trialRest = "試用期間が終わると自動的に有料になります。試用中に解約すれば料金はかかりません。"
    /// M5-17
    static let trialIneligible = "無料試用の対象外です（お試しは 1 つの Apple Account につき 1 回）。"

    /// The lead sentence. `readOnlyReason` `.billingRetry` / `.revoked` win over `reason` (§3.3).
    static func lead(_ reason: PaywallReason, eligible: Bool, readOnlyReason: ReadOnlyReason? = nil) -> String {
        switch readOnlyReason {
        case .billingRetry:
            return billingRetryLead
        case .revoked:
            return revokedLead
        case .notSubscribed, .expired, .unknown, .none:
            break
        }
        switch reason {
        case .blocked:
            return eligible ? blockedLead + blockedTrial : blockedLead
        case .firstLaunch, .settings, .badge:
            return intro
        }
    }

    /// 「14 日間無料で試す」 / 「購入する」
    static func ctaTitle(eligible: Bool) -> String {
        eligible ? "\(ProductIDs.trialDays) 日間無料で試す" : "購入する"
    }

    static func trialLine(eligible: Bool) -> String {
        eligible ? trialLead + trialRest : trialIneligible
    }

    /// 「¥2,400/年」「¥300/月」
    static func priceLine(_ offer: PlanOffer) -> String {
        offer.displayPrice + PlanText.perPeriod(offer.plan)
    }

    /// 「月あたり ¥200・4 か月分お得」; 「月あたり ¥200」 alone when there is nothing to save (or no
    /// monthly price); nil when the yearly offer carries no per-month price either.
    static func yearlyNote(_ yearly: PlanOffer, monthly: PlanOffer?) -> String? {
        var parts: [String] = []
        if let perMonth = yearly.perMonthDisplayPrice {
            parts.append("月あたり \(perMonth)")
        }
        if let monthly,
           let savings = PlanText.savingsText(months: PlanText.savingsMonths(monthly: monthly.price, yearly: yearly.price)) {
            parts.append(savings)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    /// 「試用後は ¥2,400/年。いつでも解約できます。」 / 「¥2,400/年。自動更新です。いつでも解約できます。」
    static func afterLine(_ offer: PlanOffer, eligible: Bool) -> String {
        eligible
            ? "試用後は \(priceLine(offer))。いつでも解約できます。"
            : "\(priceLine(offer))。自動更新です。いつでも解約できます。"
    }

    /// Apple's auto-renewal disclosure. The billing moment is told apart by the trial eligibility:
    /// 「購入の確認時に請求」 to an eligible person would contradict the trial line (3.1.2 and 景表法).
    static func disclosure(eligible: Bool) -> String {
        let billing = eligible ? "料金は無料試用の終了時に請求されます。" : "料金は購入の確認時に請求されます。"
        return "サブスクリプションは自動更新です。現在の期間が終わる 24 時間前までに解約しない限り、同じ期間・同じ価格で更新され、Apple Account に請求されます。"
            + billing
            + "解約は端末の\(PlanText.cancelPath)からいつでもできます。解約しても、支払い済みの期間が終わるまで使えます。"
    }

    /// The note under a plan's card: the yearly's 「月あたり ¥200・4 か月分お得」, or 「価格を取得できません」
    /// while there is no offer; nothing under a priced monthly card.
    static func cardNote(_ plan: Plan, offer: PlanOffer?, monthly: PlanOffer?) -> String? {
        guard let offer else { return noPriceNote }
        return plan == .yearly ? yearlyNote(offer, monthly: monthly) : nil
    }

    /// `.purchased` / `.restored` close the sheet (the owner toasts them); everything else is shown
    /// under the CTA.
    static func showsInSheet(_ message: StoreMessage) -> Bool {
        switch message {
        case .purchased, .restored: return false
        case .nothingToRestore, .pending, .productsUnavailable, .failed: return true
        }
    }

    /// Red under the CTA.
    static func isFailure(_ message: StoreMessage) -> Bool {
        if case .failed = message { return true }
        return false
    }

    // MARK: - Derived

    private var snapshot: StoreSnapshot { store.snapshot }
    private var offers: [PlanOffer] { snapshot.offers }

    private func offer(for plan: Plan) -> PlanOffer? {
        offers.first { $0.plan == plan }
    }

    private var selectedOffer: PlanOffer? { offer(for: selected) }

    /// The selected offer's eligibility (the group's, so both plans agree). Unknown while there is
    /// no price: false, which never advertises a trial that cannot be confirmed (the CTA is
    /// disabled then anyway; 「再読み込み」 fetches the prices).
    private var eligible: Bool {
        selectedOffer?.isEligibleForIntroOffer ?? offers.first?.isEligibleForIntroOffer ?? false
    }

    private var readOnlyReason: ReadOnlyReason? {
        if case .readOnly(let reason) = snapshot.access { return reason }
        return nil
    }

    private var isBillingRetry: Bool { readOnlyReason == .billingRetry }

    private var isPurchasing: Bool {
        if case .purchasing = snapshot.phase { return true }
        return false
    }

    private var isRestoring: Bool { snapshot.phase == .restoring }
    private var isLoadingProducts: Bool { snapshot.phase == .loadingProducts }
    /// A purchase or a restore is running: no second tap anywhere.
    private var isBusy: Bool { isPurchasing || isRestoring }

    // MARK: - Body

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            // iPhone: full height. iPad: the standard form sheet.
            content.presentationDetents([.large])
        } else {
            content
        }
    }

    private var content: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Self.title)
                        .font(.title.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(Self.lead(reason, eligible: eligible, readOnlyReason: readOnlyReason))
                    featureList
                    planCards
                    if !offers.isEmpty {
                        trialLineView
                    }
                    if isBillingRetry {
                        // Paying again would not fix a failed payment: send the person to Apple's screen.
                        manageButton
                    }
                    cta
                    if offers.isEmpty {
                        reloadButton
                    }
                    messageLine
                    if let offer = selectedOffer {
                        Text(Self.afterLine(offer, eligible: eligible))
                            .font(.footnote)
                    }
                    Text(Self.disclosure(eligible: eligible))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    linkRows
                    Button(Self.laterTitle, action: onClose)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Self.laterTitle, action: onClose)
                }
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
        }
        .presentationDragIndicator(.visible)
        .onChange(of: snapshot.message) { messageChanged() }
        .onDisappear { store.clearMessage() }
    }

    // MARK: - Pieces

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(Self.features.enumerated()), id: \.offset) { item in
                Label(item.element, systemImage: Self.featureSymbols[item.offset])
            }
        }
        .font(.subheadline)
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(Self.planOrder, id: \.self) { plan in
                planCard(plan)
            }
        }
        .padding(.top, 6) // room for the 「おすすめ」 tag above the first card
    }

    /// One plan: the name left, the price right (「—」 without a price), the note under it, the
    /// accent border while selected, the 「おすすめ」 tag on the yearly card.
    private func planCard(_ plan: Plan) -> some View {
        let offer = offer(for: plan)
        let isSelected = selected == plan
        let price = offer.map(Self.priceLine) ?? Self.noPrice
        return Button {
            selected = plan
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(PlanText.name(plan))
                        .font(.headline)
                    Spacer()
                    Text(price)
                        .font(.headline)
                }
                if let note = Self.cardNote(plan, offer: offer, monthly: self.offer(for: .monthly)) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if plan == .yearly {
                    Text(Self.recommended)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: -10, y: -9)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(PlanText.name(plan)) \(price)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var trialLineView: some View {
        if eligible {
            (Text(Self.trialLead).fontWeight(.semibold) + Text(Self.trialRest))
                .font(.footnote)
        } else {
            Text(Self.trialIneligible)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var manageButton: some View {
        Button(Self.manageTitle) {
            guard !ScreenshotMode.isActive else { return }
            showManage = true
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    /// 「14 日間無料で試す」 / 「購入する」; a spinner while purchasing; disabled without prices.
    private var cta: some View {
        Button {
            Task { await store.purchase(selected) }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(Self.ctaTitle(eligible: eligible))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 24)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(offers.isEmpty || isBusy)
    }

    /// Shown while there are no prices: `refresh(reason: .paywall)` is the one path that may set
    /// `.productsUnavailable` (§2.4).
    private var reloadButton: some View {
        Button {
            Task { await store.refresh(reason: .paywall) }
        } label: {
            Group {
                if isLoadingProducts {
                    ProgressView()
                } else {
                    Text(Self.reloadTitle)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isLoadingProducts)
    }

    /// `.failed` in red, `.pending` / `.nothingToRestore` / `.productsUnavailable` in grey (§2.5).
    @ViewBuilder
    private var messageLine: some View {
        if let message = snapshot.message, Self.showsInSheet(message) {
            Text(StoreStrings.text(for: message, access: snapshot.access))
                .font(.footnote)
                .foregroundStyle(Self.isFailure(message) ? Color.red : Color.secondary)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    /// 〔購入を復元〕／〔利用規約〕／〔プライバシーポリシー〕, then 〔使用許諾契約（Apple 標準 EULA）〕 (M5-8).
    private var linkRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    Task { await store.restore() }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(Self.restoreTitle)
                    }
                }
                .disabled(isBusy)
                Button(Self.termsTitle) { openURL(LegalLinks.terms) }
                Button(Self.privacyTitle) { openURL(LegalLinks.privacy) }
            }
            Button(LegalLinks.appleEULATitle) { openURL(LegalLinks.appleEULA) }
        }
        .font(.footnote)
        .buttonStyle(.borderless)
    }

    // MARK: - Messages

    /// A success closes the sheet; the owner shows the toast (§4.1).
    private func messageChanged() {
        guard let message = snapshot.message, !Self.showsInSheet(message) else { return }
        onClose()
    }
}
