import Access
import XCTest
@testable import TegakiCalendar

/// 設定 › 購入 の純関数 (M5_CONTRACT §4.3 / §7.6): the plan line of the eight states, the date label of
/// the six states that have a date, the numeric date in ja_JP, the purchase button while read only,
/// and the footer's three branches.
@MainActor
final class SettingsScreenTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private var later: Date { now.addingTimeInterval(30 * 86_400) }

    private var activeYearly: AccessState { .subscribed(Subscription(plan: .yearly, until: later, willAutoRenew: true, inGrace: false)) }
    private var cancelledMonthly: AccessState { .subscribed(Subscription(plan: .monthly, until: later, willAutoRenew: false, inGrace: false)) }
    private var graceYearly: AccessState { .subscribed(Subscription(plan: .yearly, until: later, willAutoRenew: true, inGrace: true)) }
    private var trialMonthly: AccessState { .trial(Trial(plan: .monthly, until: later, willAutoRenew: true)) }
    private var cancelledTrial: AccessState { .trial(Trial(plan: .yearly, until: later, willAutoRenew: false)) }
    private let reasons: [ReadOnlyReason] = [.notSubscribed, .expired, .billingRetry, .revoked, .unknown]

    func testPlanText() {
        XCTAssertEqual(SettingsScreen.planText(activeYearly), "年額・有効")
        XCTAssertEqual(SettingsScreen.planText(cancelledMonthly), "月額・有効", "cancelled but inside the paid period")
        XCTAssertEqual(SettingsScreen.planText(graceYearly), "年額・請求に問題（猶予中）")
        XCTAssertEqual(SettingsScreen.planText(trialMonthly), "月額・試用中")
        XCTAssertEqual(SettingsScreen.planText(cancelledTrial), "年額・試用中")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.notSubscribed)), "未購入（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.expired)), "期限切れ（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.billingRetry)), "お支払いに問題（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.revoked)), "返金済み（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.unknown)), "確認中（閲覧専用）")
        // The same words as the kit's (one source).
        let everyState = [activeYearly, cancelledMonthly, graceYearly, trialMonthly, cancelledTrial] + reasons.map({ AccessState.readOnly($0) })
        for access in everyState {
            XCTAssertEqual(SettingsScreen.planText(access), PlanText.statusTitle(access), "\(access)")
        }
    }

    func testDateLabel() {
        XCTAssertEqual(SettingsScreen.dateLabel(activeYearly), "次回更新")
        XCTAssertEqual(SettingsScreen.dateLabel(cancelledMonthly), "有効期限")
        XCTAssertEqual(SettingsScreen.dateLabel(graceYearly), "猶予の期限")
        XCTAssertEqual(SettingsScreen.dateLabel(.subscribed(Subscription(plan: .monthly, until: later, willAutoRenew: false, inGrace: true))), "猶予の期限", "the grace wins")
        XCTAssertEqual(SettingsScreen.dateLabel(trialMonthly), "試用の終了（有料に移行）")
        XCTAssertEqual(SettingsScreen.dateLabel(cancelledTrial), "試用の終了")
        for reason in reasons {
            XCTAssertNil(SettingsScreen.dateLabel(.readOnly(reason)), "\(reason): no date row")
            XCTAssertNil(AccessState.readOnly(reason).until)
        }
        XCTAssertEqual(activeYearly.until, later, "the date row shows `access.until`")
    }

    func testDateText() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)))
        XCTAssertEqual(SettingsScreen.dateText(date, locale: Locale(identifier: "ja_JP")), "2026/10/25")
        // No time, whatever the locale (the CI runs in English).
        let english = SettingsScreen.dateText(date, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(english.contains("2026"), english)
        XCTAssertTrue(english.contains("25"), english)
        XCTAssertFalse(english.contains(":"), english)
    }

    func testPurchaseButtonTitle() {
        XCTAssertEqual(SettingsScreen.purchaseButtonTitle(.readOnly(.notSubscribed), eligible: true), "14 日間無料で試す")
        XCTAssertEqual(SettingsScreen.purchaseButtonTitle(.readOnly(.notSubscribed), eligible: false), "購読する")
        XCTAssertEqual(SettingsScreen.purchaseButtonTitle(.readOnly(.expired), eligible: false), "購読する")
        for reason in reasons {
            XCTAssertNotNil(SettingsScreen.purchaseButtonTitle(.readOnly(reason), eligible: true), "\(reason)")
        }
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(activeYearly, eligible: true))
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(cancelledMonthly, eligible: false))
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(graceYearly, eligible: true), "in grace the person can still write (M5-16)")
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(trialMonthly, eligible: true))
    }

    /// The three branches: how to cancel (subscribed / trial), the payment problem (in grace), the
    /// read-only reason and what read only still allows.
    func testPurchaseFooter() {
        let active = SettingsScreen.purchaseFooter(activeYearly)
        XCTAssertTrue(active.contains(PlanText.cancelPath), active)
        XCTAssertEqual(active, "解約は端末の\(PlanText.cancelPath)から。解約しても期間の終わりまで使えます。")
        XCTAssertEqual(SettingsScreen.purchaseFooter(cancelledMonthly), active, "cancelled inside the period: the same footer")
        XCTAssertFalse(active.contains("Apple ID"), "the short in-app path (M5-29)")

        let trial = SettingsScreen.purchaseFooter(trialMonthly)
        XCTAssertTrue(trial.contains(PlanText.cancelPath), trial)
        XCTAssertTrue(trial.hasPrefix(active), trial)
        XCTAssertTrue(trial.hasSuffix("試用中に解約すれば料金はかかりません。"), trial)
        XCTAssertEqual(SettingsScreen.purchaseFooter(cancelledTrial), trial)

        let grace = SettingsScreen.purchaseFooter(graceYearly)
        XCTAssertEqual(grace, "お支払いに問題があります。端末の\(PlanText.paymentPath)でお支払い方法を確認してください。猶予の期限までは使えます。")
        XCTAssertTrue(grace.contains(PlanText.paymentPath), grace)

        for reason in reasons {
            let text = SettingsScreen.purchaseFooter(.readOnly(reason))
            XCTAssertTrue(text.hasPrefix(PlanText.readOnlyNote(reason)), "\(reason): \(text)")
            XCTAssertTrue(text.contains("閲覧専用では、予定と手書きの閲覧、ページ移動、拡大、iCloud からの受信、この iPad の手書きを全て消す、設定の変更ができます。"), text)
            XCTAssertTrue(text.hasSuffix("新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みは購読すると使えます。"), text)
        }
        XCTAssertTrue(SettingsScreen.purchaseFooter(.readOnly(.billingRetry)).contains(PlanText.paymentPath))
        XCTAssertTrue(SettingsScreen.purchaseFooter(.readOnly(.unknown)).contains("回線が戻ると自動で確認します"))
    }

    func testPlanIsProblemAndFailure() {
        XCTAssertFalse(SettingsScreen.planIsProblem(activeYearly))
        XCTAssertFalse(SettingsScreen.planIsProblem(cancelledMonthly))
        XCTAssertTrue(SettingsScreen.planIsProblem(graceYearly), "red while in grace")
        XCTAssertFalse(SettingsScreen.planIsProblem(trialMonthly))
        XCTAssertTrue(SettingsScreen.planIsProblem(.readOnly(.billingRetry)), "red while the payment is the problem")
        for reason in reasons where reason != .billingRetry {
            XCTAssertFalse(SettingsScreen.planIsProblem(.readOnly(reason)), "\(reason)")
        }
        XCTAssertTrue(SettingsScreen.isFailure(.failed(StoreStrings.offline)))
        XCTAssertFalse(SettingsScreen.isFailure(.restored))
        XCTAssertFalse(SettingsScreen.isFailure(.nothingToRestore))
    }

    /// 設定 › 情報 opens the public pages and Apple's standard EULA (`LegalLinks`, D5 / M5-8).
    func testInfoLinks() {
        XCTAssertEqual(LegalLinks.terms.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/terms.html")
        XCTAssertEqual(LegalLinks.privacy.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/privacy.html")
        XCTAssertEqual(LegalLinks.support.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/support.html")
        XCTAssertEqual(LegalLinks.appleEULA.absoluteString, "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        XCTAssertEqual(LegalLinks.appleEULATitle, "使用許諾契約（Apple 標準 EULA）")
    }
}
