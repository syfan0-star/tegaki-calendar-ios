import XCTest
import Foundation
import Access

/// `PlanText` and `LegalLinks` (M5_CONTRACT §1.5). The same checks run in KitChecks.
final class PlanTextTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private var future: Date { now.addingTimeInterval(20 * 86_400) }

    private func sub(_ plan: Plan, _ until: Date, auto: Bool = true, grace: Bool = false) -> AccessState {
        .subscribed(Subscription(plan: plan, until: until, willAutoRenew: auto, inGrace: grace))
    }

    private func trial(_ plan: Plan, _ until: Date, auto: Bool = true) -> AccessState {
        .trial(Trial(plan: plan, until: until, willAutoRenew: auto))
    }

    func testSavings() {
        XCTAssertEqual(PlanText.savingsMonths(monthly: 300, yearly: 2400), 4, "0-1: 4 か月分")
        XCTAssertEqual(PlanText.savingsMonths(monthly: 300, yearly: 3600), 0)
        XCTAssertEqual(PlanText.savingsMonths(monthly: 300, yearly: 4000), 0)
        XCTAssertEqual(PlanText.savingsMonths(monthly: 0, yearly: 2400), 0)
        XCTAssertEqual(PlanText.savingsMonths(monthly: -300, yearly: 2400), 0)
        XCTAssertEqual(PlanText.savingsMonths(monthly: 250, yearly: 2000), 4)
        XCTAssertEqual(PlanText.savingsMonths(monthly: 300, yearly: 2300), 4, "M5-7")
        XCTAssertEqual(PlanText.savingsMonths(monthly: 300, yearly: 2500), 3, "M5-7")
        XCTAssertEqual(PlanText.savingsMonths(monthly: 300, yearly: 300), 11)
        XCTAssertEqual(PlanText.savingsMonths(monthly: ProductIDs.contractPrice[.monthly]!, yearly: ProductIDs.contractPrice[.yearly]!), 4)
        XCTAssertEqual(PlanText.savingsText(months: 4), "4 か月分お得")
        XCTAssertEqual(PlanText.savingsText(months: 3), "3 か月分お得")
        XCTAssertNil(PlanText.savingsText(months: 0))
        XCTAssertNil(PlanText.savingsText(months: -1))
        XCTAssertEqual(PlanText.savingsText(months: PlanText.savingsMonths(monthly: 300, yearly: 2400)), PlanText.yearlyBadge)
        XCTAssertEqual(PlanText.yearlyBadge, "4 か月分お得")
    }

    func testPerMonth() {
        XCTAssertEqual(PlanText.perMonth(yearly: 2400), 200)
        XCTAssertEqual(PlanText.perMonth(yearly: 2300), 192)
        XCTAssertEqual(PlanText.perMonth(yearly: 2500), 208)
        XCTAssertEqual(PlanText.perMonth(yearly: 0), 0)
        XCTAssertEqual(PlanText.name(.monthly), "月額")
        XCTAssertEqual(PlanText.name(.yearly), "年額")
        XCTAssertEqual(PlanText.perPeriod(.monthly), "/月")
        XCTAssertEqual(PlanText.perPeriod(.yearly), "/年")
    }

    func testTitlesAndLabels() {
        // statusTitle: 8 states
        XCTAssertEqual(PlanText.statusTitle(sub(.yearly, future)), "年額・有効")
        XCTAssertEqual(PlanText.statusTitle(sub(.monthly, future, auto: false)), "月額・有効")
        XCTAssertEqual(PlanText.statusTitle(sub(.yearly, future, grace: true)), "年額・請求に問題（猶予中）")
        XCTAssertEqual(PlanText.statusTitle(trial(.monthly, future)), "月額・試用中")
        XCTAssertEqual(PlanText.statusTitle(.readOnly(.notSubscribed)), "未購入（閲覧専用）")
        XCTAssertEqual(PlanText.statusTitle(.readOnly(.expired)), "期限切れ（閲覧専用）")
        XCTAssertEqual(PlanText.statusTitle(.readOnly(.billingRetry)), "お支払いに問題（閲覧専用）")
        XCTAssertEqual(PlanText.statusTitle(.readOnly(.revoked)), "返金済み（閲覧専用）")
        XCTAssertEqual(PlanText.statusTitle(.readOnly(.unknown)), "確認中（閲覧専用）")
        // dateLabel: 6 states
        XCTAssertEqual(PlanText.dateLabel(sub(.yearly, future)), "次回更新")
        XCTAssertEqual(PlanText.dateLabel(sub(.yearly, future, auto: false)), "有効期限")
        XCTAssertEqual(PlanText.dateLabel(sub(.yearly, future, grace: true)), "猶予の期限")
        XCTAssertEqual(PlanText.dateLabel(sub(.yearly, future, auto: false, grace: true)), "猶予の期限", "inGrace wins")
        XCTAssertEqual(PlanText.dateLabel(trial(.monthly, future)), "試用の終了（有料に移行）")
        XCTAssertEqual(PlanText.dateLabel(trial(.monthly, future, auto: false)), "試用の終了")
        for reason in [ReadOnlyReason.notSubscribed, .expired, .billingRetry, .revoked, .unknown] {
            XCTAssertNil(PlanText.dateLabel(.readOnly(reason)))
        }
        // readOnlyNote: 5 reasons
        XCTAssertEqual(PlanText.readOnlyNote(.notSubscribed), "まだ購読していません。")
        XCTAssertEqual(PlanText.readOnlyNote(.expired), "サブスクリプションの期限が切れています。")
        XCTAssertEqual(PlanText.readOnlyNote(.billingRetry), "お支払いに問題があります。「設定」›「Apple Account」›「お支払いと配送先」でお支払い方法を確認してください。")
        XCTAssertTrue(PlanText.readOnlyNote(.billingRetry).contains(PlanText.paymentPath))
        XCTAssertEqual(PlanText.readOnlyNote(.revoked), "購入が返金または取り消されました。")
        XCTAssertEqual(PlanText.readOnlyNote(.unknown), "購入の状態を確認できていません。回線が戻ると自動で確認します。")
        // constants
        XCTAssertEqual(PlanText.readOnlyBadge, "閲覧専用")
        XCTAssertEqual(PlanText.cancelPath, "「設定」›「Apple Account」›「サブスクリプション」")
        XCTAssertEqual(PlanText.paymentPath, "「設定」›「Apple Account」›「お支払いと配送先」")
        XCTAssertFalse(PlanText.cancelPath.contains("Apple ID"), "M5-29: the in-app path stays short")
    }

    func testLegalLinks() {
        XCTAssertEqual(LegalLinks.base.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/")
        XCTAssertEqual(LegalLinks.terms.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/terms.html")
        XCTAssertEqual(LegalLinks.privacy.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/privacy.html")
        XCTAssertEqual(LegalLinks.support.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/support.html")
        XCTAssertEqual(LegalLinks.appleEULA.absoluteString, "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        XCTAssertEqual(LegalLinks.appleEULATitle, "使用許諾契約（Apple 標準 EULA）")
        XCTAssertEqual(LegalLinks.supportEmail, "syfan0@gmail.com")
        XCTAssertFalse(LegalLinks.terms.absoluteString.contains("/ios/"), "0-2: app/")
    }
}
