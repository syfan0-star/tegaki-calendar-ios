import Access
import XCTest
@testable import TegakiCalendar

/// The paywall's words (M5_CONTRACT §4.1 / §7.6): the lead per reason and read-only reason, the CTA,
/// the trial line, the price lines, the yearly note, the price after the trial, Apple's disclosure in
/// both eligibility branches, and the three features. The prices are the screenshot mode's fixed
/// `StoreStrings.demo*` (the real sheet shows StoreKit's `displayPrice`, whose yen sign may be the
/// full-width 「￥」 on a device).
@MainActor
final class PaywallSheetTests: XCTestCase {
    private let yearly = PlanOffer(
        plan: .yearly,
        displayPrice: StoreStrings.demoYearlyPrice,
        price: 2400,
        isEligibleForIntroOffer: true,
        introDays: ProductIDs.trialDays,
        perMonthDisplayPrice: StoreStrings.demoPerMonthPrice
    )
    private let monthly = PlanOffer(
        plan: .monthly,
        displayPrice: StoreStrings.demoMonthlyPrice,
        price: 300,
        isEligibleForIntroOffer: true,
        introDays: ProductIDs.trialDays,
        perMonthDisplayPrice: nil
    )

    func testCtaTitle() {
        XCTAssertEqual(PaywallSheet.ctaTitle(eligible: true), "14 日間無料で試す")
        XCTAssertEqual(PaywallSheet.ctaTitle(eligible: false), "購入する")
    }

    func testTrialLine() {
        let eligible = PaywallSheet.trialLine(eligible: true)
        XCTAssertTrue(eligible.hasPrefix("14 日間無料でお試し。"), eligible)
        XCTAssertEqual(eligible, "14 日間無料でお試し。試用期間が終わると自動的に有料になります。試用中に解約すれば料金はかかりません。")
        XCTAssertEqual(PaywallSheet.trialLead + PaywallSheet.trialRest, eligible, "the view bolds the lead and appends the rest")
        XCTAssertEqual(PaywallSheet.trialLine(eligible: false), "無料試用の対象外です（お試しは 1 つの Apple Account につき 1 回）。")
    }

    func testPriceLine() {
        XCTAssertEqual(PaywallSheet.priceLine(yearly), "\(StoreStrings.demoYearlyPrice)/年")
        XCTAssertEqual(PaywallSheet.priceLine(monthly), "\(StoreStrings.demoMonthlyPrice)/月")
        XCTAssertEqual(PaywallSheet.priceLine(yearly), "¥2,400/年")
        XCTAssertEqual(PaywallSheet.priceLine(monthly), "¥300/月")
        // The device's string is used as it is (a full-width yen sign stays).
        var device = yearly
        device.displayPrice = "￥2,400"
        XCTAssertEqual(PaywallSheet.priceLine(device), "￥2,400/年")
    }

    func testYearlyNote() {
        let note = PaywallSheet.yearlyNote(yearly, monthly: monthly)
        XCTAssertEqual(note, "月あたり \(StoreStrings.demoPerMonthPrice)・4 か月分お得")
        XCTAssertTrue(note?.contains(StoreStrings.demoPerMonthPrice) ?? false)
        XCTAssertTrue(note?.contains("4 か月分お得") ?? false)
        XCTAssertTrue(note?.contains(PlanText.yearlyBadge) ?? false, "the same words as the photo's fixed badge")
        // Without a monthly price only the per-month part; a yearly that saves nothing: the same.
        XCTAssertEqual(PaywallSheet.yearlyNote(yearly, monthly: nil), "月あたり \(StoreStrings.demoPerMonthPrice)")
        var dear = yearly
        dear.price = 3600
        XCTAssertEqual(PaywallSheet.yearlyNote(dear, monthly: monthly), "月あたり \(StoreStrings.demoPerMonthPrice)")
        // ¥2,300 (M5-7): still 「4 か月分お得」 (2300 / 300 = 7.67 → 12 − 7.67 → 4).
        var cheaper = yearly
        cheaper.price = 2300
        XCTAssertEqual(PaywallSheet.yearlyNote(cheaper, monthly: monthly), "月あたり \(StoreStrings.demoPerMonthPrice)・4 か月分お得")
        // No per-month price from StoreKit: the savings alone; nothing at all → nil.
        var bare = yearly
        bare.perMonthDisplayPrice = nil
        XCTAssertEqual(PaywallSheet.yearlyNote(bare, monthly: monthly), "4 か月分お得")
        bare.price = 3600
        XCTAssertNil(PaywallSheet.yearlyNote(bare, monthly: monthly))
    }

    func testAfterLine() {
        XCTAssertEqual(PaywallSheet.afterLine(yearly, eligible: true), "試用後は ¥2,400/年。いつでも解約できます。")
        XCTAssertEqual(PaywallSheet.afterLine(yearly, eligible: false), "¥2,400/年。自動更新です。いつでも解約できます。")
        XCTAssertEqual(PaywallSheet.afterLine(monthly, eligible: true), "試用後は ¥300/月。いつでも解約できます。")
        XCTAssertEqual(PaywallSheet.afterLine(monthly, eligible: false), "¥300/月。自動更新です。いつでも解約できます。")
    }

    /// The billing moment follows the eligibility (3.1.2 and 景表法): the eligible text never says
    /// 「購入の確認時」, the ineligible one never says 「無料試用の終了時」.
    func testDisclosure() {
        let eligible = PaywallSheet.disclosure(eligible: true)
        let ineligible = PaywallSheet.disclosure(eligible: false)
        XCTAssertTrue(eligible.contains("料金は無料試用の終了時に請求されます。"), eligible)
        XCTAssertFalse(eligible.contains("購入の確認時"), eligible)
        XCTAssertTrue(ineligible.contains("料金は購入の確認時に請求されます。"), ineligible)
        XCTAssertFalse(ineligible.contains("無料試用の終了時"), ineligible)
        for text in [eligible, ineligible] {
            XCTAssertTrue(text.contains("24 時間前"), text)
            XCTAssertTrue(text.contains("自動更新"), text)
            XCTAssertTrue(text.contains("Apple Account"), text)
            XCTAssertTrue(text.contains("サブスクリプション"), text)
            XCTAssertTrue(text.contains(PlanText.cancelPath), "the short in-app cancel path (M5-29)")
            XCTAssertFalse(text.contains("Apple ID"), "no iPadOS 17 parenthesis in the app (M5-29)")
            XCTAssertTrue(text.hasPrefix("サブスクリプションは自動更新です。"), text)
            XCTAssertTrue(text.hasSuffix("解約しても、支払い済みの期間が終わるまで使えます。"), text)
        }
    }

    func testFeatures() {
        XCTAssertEqual(PaywallSheet.features.count, 3)
        XCTAssertEqual(PaywallSheet.featureSymbols.count, PaywallSheet.features.count)
        XCTAssertEqual(PaywallSheet.features, [
            "手書き（ペン・マーカー・消しゴム・投げなわ）",
            "手書きから予定を作る。予定の作成・編集",
            "iCloud で iPad・iPhone と同期",
        ])
        XCTAssertEqual(PaywallSheet.title, "てがきカレンダー")
        XCTAssertEqual(PaywallSheet.planOrder, [.yearly, .monthly], "年額 on top")
    }

    func testLead() {
        // A refused operation: the need, plus the trial when eligible.
        let blocked = PaywallSheet.lead(.blocked(.draw), eligible: true)
        XCTAssertTrue(blocked.contains("14 日間無料"), blocked)
        XCTAssertEqual(blocked, "書く・消す・予定を作るには購読が必要です。14 日間無料で試せます。")
        XCTAssertEqual(PaywallSheet.lead(.blocked(.createEvent), eligible: false), "書く・消す・予定を作るには購読が必要です。")
        // The other reasons: the one-sentence introduction.
        for reason in [PaywallReason.firstLaunch, .settings, .badge] {
            XCTAssertEqual(PaywallSheet.lead(reason, eligible: true), "iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。", "\(reason)")
            XCTAssertEqual(PaywallSheet.lead(reason, eligible: false), PaywallSheet.intro, "\(reason)")
        }
        // The payment problem wins over every reason.
        let billing = PaywallSheet.lead(.settings, eligible: true, readOnlyReason: .billingRetry)
        XCTAssertTrue(billing.contains("お支払いに問題"), billing)
        XCTAssertTrue(billing.contains(PlanText.paymentPath), billing)
        XCTAssertEqual(PaywallSheet.lead(.blocked(.draw), eligible: true, readOnlyReason: .billingRetry), billing)
        XCTAssertEqual(PaywallSheet.lead(.badge, eligible: false, readOnlyReason: .billingRetry), billing)
        // So does a refund.
        let revoked = PaywallSheet.lead(.badge, eligible: false, readOnlyReason: .revoked)
        XCTAssertTrue(revoked.contains("返金"), revoked)
        XCTAssertEqual(revoked, "購入が返金または取り消されました。再び使うには購読してください。")
        XCTAssertEqual(PaywallSheet.lead(.blocked(.webImport), eligible: true, readOnlyReason: .revoked), revoked)
        // The other read-only reasons follow the reason.
        XCTAssertEqual(PaywallSheet.lead(.blocked(.draw), eligible: true, readOnlyReason: .expired), blocked)
        XCTAssertEqual(PaywallSheet.lead(.settings, eligible: false, readOnlyReason: .expired), PaywallSheet.intro)
        XCTAssertEqual(PaywallSheet.lead(.badge, eligible: true, readOnlyReason: .notSubscribed), PaywallSheet.intro)
        XCTAssertEqual(PaywallSheet.lead(.firstLaunch, eligible: true, readOnlyReason: .unknown), PaywallSheet.intro)
        XCTAssertEqual(PaywallSheet.lead(.blocked(.overlayTool), eligible: false, readOnlyReason: .notSubscribed), "書く・消す・予定を作るには購読が必要です。")
    }

    func testCardNoteAndMessages() {
        XCTAssertEqual(PaywallSheet.cardNote(.yearly, offer: yearly, monthly: monthly), "月あたり ¥200・4 か月分お得")
        XCTAssertNil(PaywallSheet.cardNote(.monthly, offer: monthly, monthly: monthly), "nothing under a priced monthly card")
        XCTAssertEqual(PaywallSheet.cardNote(.yearly, offer: nil, monthly: nil), "価格を取得できません")
        XCTAssertEqual(PaywallSheet.cardNote(.monthly, offer: nil, monthly: nil), "価格を取得できません")
        XCTAssertEqual(PaywallSheet.noPrice, "—")
        // A success closes the sheet (the owner toasts it); the rest is shown under the CTA, failures in red.
        XCTAssertFalse(PaywallSheet.showsInSheet(.purchased(.yearly)))
        XCTAssertFalse(PaywallSheet.showsInSheet(.restored))
        XCTAssertTrue(PaywallSheet.showsInSheet(.pending))
        XCTAssertTrue(PaywallSheet.showsInSheet(.nothingToRestore))
        XCTAssertTrue(PaywallSheet.showsInSheet(.productsUnavailable))
        XCTAssertTrue(PaywallSheet.showsInSheet(.failed(StoreStrings.offline)))
        XCTAssertTrue(PaywallSheet.isFailure(.failed(StoreStrings.unverified)))
        XCTAssertFalse(PaywallSheet.isFailure(.pending))
        XCTAssertFalse(PaywallSheet.isFailure(.productsUnavailable))
        XCTAssertEqual(PaywallSheet.laterTitle, "あとで")
        XCTAssertEqual(PaywallSheet.restoreTitle, "購入を復元")
        XCTAssertEqual(PaywallSheet.reloadTitle, "再読み込み")
        XCTAssertEqual(PaywallSheet.manageTitle, "サブスクリプションを管理")
    }

    /// The photo's sheet (`--screenshot-sheet paywall`, §7.5): the demo offers give exactly the lines
    /// §8-5 expects, in the trial-eligible branch.
    func testScreenshotDemoFeedsTheSheet() {
        let model = StoreModel.screenshotDemo(access: .readOnly(.notSubscribed))
        let offers = model.snapshot.offers
        XCTAssertEqual(offers.map(\.plan), [.yearly, .monthly])
        XCTAssertEqual(offers.first.map(PaywallSheet.priceLine), "¥2,400/年")
        XCTAssertEqual(offers.last.map(PaywallSheet.priceLine), "¥300/月")
        XCTAssertEqual(PaywallSheet.yearlyNote(offers[0], monthly: offers[1]), "月あたり ¥200・4 か月分お得")
        XCTAssertTrue(offers.allSatisfy(\.isEligibleForIntroOffer), "the photo shows the trial branch of the disclosure")
        XCTAssertEqual(PaywallSheet.afterLine(offers[0], eligible: true), "試用後は ¥2,400/年。いつでも解約できます。")
        XCTAssertEqual(PaywallSheet.lead(.firstLaunch, eligible: true, readOnlyReason: .notSubscribed), PaywallSheet.intro)
    }
}
