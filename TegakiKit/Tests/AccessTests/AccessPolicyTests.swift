import XCTest
import Foundation
import Access

/// `AccessPolicy.resolve` (M5_CONTRACT §1.2 truth table) and `reconcile` (§1.3). The same checks run in
/// KitChecks ("access state (M5)").
final class AccessPolicyTests: XCTestCase {
    /// 2025-10-09T08:53:20Z, a whole second.
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private func days(_ n: Double) -> TimeInterval { n * 86_400 }
    private var future: Date { now.addingTimeInterval(days(20)) }
    private var past: Date { now.addingTimeInterval(-days(1)) }
    private let monthlyID = Plan.monthly.productID
    private let yearlyID = Plan.yearly.productID
    private let unknownID = "com.syfan0.tegakicalendar.lifetime"

    private func ent(_ id: UInt64, _ productID: String, expires: Date?, revoked: Date? = nil, intro: Bool = false) -> EntitlementInput {
        EntitlementInput(id: id, productID: productID, subscriptionGroupID: "21700001", purchaseDate: now.addingTimeInterval(-days(10)), expirationDate: expires, revocationDate: revoked, isIntroductory: intro)
    }

    private func ren(_ productID: String, _ state: RenewalState, auto: Bool = true, grace: Date? = nil, renews: Date? = nil, latest: EntitlementInput? = nil) -> RenewalInput {
        RenewalInput(productID: productID, state: state, willAutoRenew: auto, gracePeriodExpirationDate: grace, renewalDate: renews, autoRenewPreference: nil, latestTransaction: latest)
    }

    private func resolve(_ entitlements: [EntitlementInput], _ renewals: [RenewalInput]?) -> AccessState {
        AccessPolicy.resolve(entitlements: entitlements, renewals: renewals, now: now)
    }

    private func sub(_ plan: Plan, _ until: Date, auto: Bool = true, grace: Bool = false) -> AccessState {
        .subscribed(Subscription(plan: plan, until: until, willAutoRenew: auto, inGrace: grace))
    }

    private func trial(_ plan: Plan, _ until: Date, auto: Bool = true) -> AccessState {
        .trial(Trial(plan: plan, until: until, willAutoRenew: auto))
    }

    private func reconcile(_ live: AccessState, _ cached: AccessState?, reachable: Bool) -> AccessState {
        AccessPolicy.reconcile(live: live, cached: cached.map { AccessSnapshot(state: $0, savedAt: now) }, storeReachable: reachable, now: now)
    }

    // MARK: §1.1 / §1.2 types

    func testPlanAndProductIDs() {
        XCTAssertEqual(Plan.monthly.productID, "com.syfan0.tegakicalendar.monthly")
        XCTAssertEqual(Plan.yearly.productID, "com.syfan0.tegakicalendar.yearly")
        for plan in Plan.allCases { XCTAssertEqual(Plan(productID: plan.productID), plan) }
        XCTAssertNil(Plan(productID: "com.syfan0.tegakicalendar.weekly"))
        XCTAssertNil(Plan(productID: "monthly"))
        XCTAssertNil(Plan(productID: ""))
        XCTAssertEqual(Plan.monthly.months, 1)
        XCTAssertEqual(Plan.yearly.months, 12)
        XCTAssertEqual(ProductIDs.prefix, "com.syfan0.tegakicalendar.")
        XCTAssertEqual(ProductIDs.groupReferenceName, "てがきカレンダー")
        XCTAssertEqual(ProductIDs.all, ["com.syfan0.tegakicalendar.monthly", "com.syfan0.tegakicalendar.yearly"])
        XCTAssertEqual(ProductIDs.contractPrice[.monthly], 300)
        XCTAssertEqual(ProductIDs.contractPrice[.yearly], 2400)
        XCTAssertEqual(ProductIDs.trialDays, 14)
        let paid = sub(.yearly, future)
        XCTAssertTrue(paid.canEdit)
        XCTAssertEqual(paid.plan, .yearly)
        XCTAssertEqual(paid.until, future)
        XCTAssertTrue(trial(.monthly, future).canEdit)
        XCTAssertTrue(sub(.yearly, future, grace: true).canEdit, "in grace: still writable (M5-16)")
        for reason in [ReadOnlyReason.notSubscribed, .expired, .billingRetry, .revoked, .unknown] {
            XCTAssertFalse(AccessState.readOnly(reason).canEdit)
            XCTAssertNil(AccessState.readOnly(reason).plan)
            XCTAssertNil(AccessState.readOnly(reason).until)
        }
    }

    // MARK: resolve

    /// Every row of the §1.2 table with one representative input.
    func testTruthTable() {
        let activeYearly = ent(1, yearlyID, expires: future)
        let trialMonthly = ent(3, monthlyID, expires: now.addingTimeInterval(days(7)), intro: true)
        let expiredYearly = ent(4, yearlyID, expires: past)
        let revokedYearly = ent(5, yearlyID, expires: future, revoked: past)
        // 1
        XCTAssertEqual(resolve([revokedYearly], []), .readOnly(.revoked))
        // 2
        XCTAssertEqual(resolve([], []), .readOnly(.notSubscribed))
        XCTAssertEqual(resolve([], nil), .readOnly(.unknown))
        // 3
        XCTAssertEqual(resolve([], [ren(yearlyID, .inGracePeriod, grace: future)]), sub(.yearly, future, grace: true))
        // 4
        XCTAssertEqual(resolve([], [ren(yearlyID, .inBillingRetryPeriod)]), .readOnly(.billingRetry))
        // 5
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, renews: future)]), sub(.yearly, future))
        // 6
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed)]), .readOnly(.unknown))
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, renews: now)]), .readOnly(.unknown))
        // 7
        XCTAssertEqual(resolve([], [ren(yearlyID, .revoked)]), .readOnly(.revoked))
        // 8
        XCTAssertEqual(resolve([], [ren(yearlyID, .expired)]), .readOnly(.expired))
        XCTAssertEqual(resolve([], [ren(yearlyID, .unknown)]), .readOnly(.expired))
        XCTAssertEqual(resolve([], [ren(yearlyID, .inGracePeriod, grace: past)]), .readOnly(.expired))
        XCTAssertEqual(resolve([], [ren(yearlyID, .inGracePeriod)]), .readOnly(.expired))
        // 9
        XCTAssertEqual(resolve([trialMonthly], []), trial(.monthly, now.addingTimeInterval(days(7))))
        XCTAssertEqual(resolve([trialMonthly], [ren(monthlyID, .subscribed, auto: false)]), trial(.monthly, now.addingTimeInterval(days(7)), auto: false))
        XCTAssertEqual(resolve([ent(8, yearlyID, expires: nil, intro: true)], []), trial(.yearly, now.addingTimeInterval(days(14))), "no expiration → now + 14 days")
        // 10
        XCTAssertEqual(resolve([activeYearly], []), sub(.yearly, future))
        XCTAssertEqual(resolve([activeYearly], nil), sub(.yearly, future))
        XCTAssertEqual(resolve([activeYearly], [ren(yearlyID, .subscribed, renews: now.addingTimeInterval(days(21)))]), sub(.yearly, now.addingTimeInterval(days(21))), "R.renewalDate wins")
        XCTAssertEqual(resolve([activeYearly], [ren(yearlyID, .subscribed, auto: false)]), sub(.yearly, future, auto: false))
        XCTAssertEqual(resolve([ent(9, yearlyID, expires: nil)], []), sub(.yearly, .distantFuture))
        // 11
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inGracePeriod, grace: future)]), sub(.yearly, future, grace: true))
        // 12
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inBillingRetryPeriod)]), .readOnly(.billingRetry))
        // 13
        XCTAssertEqual(resolve([expiredYearly], []), .readOnly(.expired))
        XCTAssertEqual(resolve([expiredYearly], nil), .readOnly(.unknown))
        XCTAssertEqual(resolve([ent(11, yearlyID, expires: now)], []), .readOnly(.expired), "expiring exactly now is expired")
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .subscribed)]), .readOnly(.expired))
        // Unknown products are ignored on both sides.
        XCTAssertEqual(resolve([ent(6, unknownID, expires: future)], [ren(unknownID, .subscribed, renews: future)]), .readOnly(.notSubscribed))
        XCTAssertEqual(resolve([activeYearly, ent(6, unknownID, expires: nil)], [ren(unknownID, .subscribed, auto: false)]), sub(.yearly, future))
    }

    func testPicksTheLatestEntitlement() {
        let activeYearly = ent(1, yearlyID, expires: future)
        let activeMonthly = ent(2, monthlyID, expires: now.addingTimeInterval(days(5)))
        XCTAssertEqual(resolve([activeMonthly, activeYearly], []), sub(.yearly, future))
        XCTAssertEqual(resolve([activeYearly, activeMonthly], []), sub(.yearly, future))
        XCTAssertEqual(resolve([activeYearly, ent(10, monthlyID, expires: nil)], []), sub(.monthly, .distantFuture), "nil counts as the latest")
        // R follows E's product; without one, the first known status is used.
        XCTAssertEqual(resolve([activeYearly], [ren(monthlyID, .subscribed, auto: false), ren(yearlyID, .subscribed)]), sub(.yearly, future))
        XCTAssertEqual(resolve([activeMonthly], [ren(monthlyID, .subscribed, auto: false), ren(yearlyID, .subscribed)]), sub(.monthly, now.addingTimeInterval(days(5)), auto: false))
        XCTAssertEqual(resolve([activeMonthly], [ren(yearlyID, .subscribed, auto: false)]), sub(.monthly, now.addingTimeInterval(days(5)), auto: false))
    }

    func testRevokedOnly() {
        let revokedYearly = ent(5, yearlyID, expires: future, revoked: past)
        let activeMonthly = ent(2, monthlyID, expires: now.addingTimeInterval(days(5)))
        XCTAssertEqual(resolve([revokedYearly], []), .readOnly(.revoked))
        XCTAssertEqual(resolve([revokedYearly], nil), .readOnly(.revoked))
        XCTAssertEqual(resolve([revokedYearly], [ren(yearlyID, .inGracePeriod, grace: future)]), .readOnly(.revoked), "row 1 comes before row 3")
        XCTAssertEqual(resolve([revokedYearly, activeMonthly], []), sub(.monthly, now.addingTimeInterval(days(5))), "a valid one wins")
        XCTAssertEqual(resolve([ent(7, "com.other.app", expires: future, revoked: past)], []), .readOnly(.notSubscribed), "an unknown product's revocation is ignored")
        XCTAssertEqual(resolve([], [ren(yearlyID, .revoked)]), .readOnly(.revoked), "row 7")
    }

    func testGraceAfterExpiry() {
        let expiredYearly = ent(4, yearlyID, expires: past)
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inGracePeriod, grace: future)]), sub(.yearly, future, grace: true))
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inGracePeriod, auto: false, grace: future)]), sub(.yearly, future, auto: false, grace: true))
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inGracePeriod, grace: past)]), .readOnly(.expired), "grace over → row 13")
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inGracePeriod, grace: now)]), .readOnly(.expired))
        XCTAssertEqual(resolve([], [ren(monthlyID, .inGracePeriod, auto: false, grace: future)]), sub(.monthly, future, auto: false, grace: true), "row 3 carries willAutoRenew")
    }

    func testBillingRetry() {
        let expiredYearly = ent(4, yearlyID, expires: past)
        XCTAssertEqual(resolve([], [ren(yearlyID, .inBillingRetryPeriod)]), .readOnly(.billingRetry), "row 4")
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .inBillingRetryPeriod)]), .readOnly(.billingRetry), "row 12")
        XCTAssertEqual(resolve([ent(1, yearlyID, expires: future)], [ren(yearlyID, .inBillingRetryPeriod)]), sub(.yearly, future), "a current entitlement is not touched by the retry state")
    }

    func testRenewalsUnavailable() {
        let expiredYearly = ent(4, yearlyID, expires: past)
        let activeYearly = ent(1, yearlyID, expires: future)
        XCTAssertEqual(resolve([], nil), .readOnly(.unknown), "row 2")
        XCTAssertEqual(resolve([expiredYearly], nil), .readOnly(.unknown), "row 13")
        XCTAssertEqual(resolve([activeYearly], nil), sub(.yearly, future), "row 10 still works offline")
        XCTAssertEqual(resolve([ent(3, monthlyID, expires: future, intro: true)], nil), trial(.monthly, future), "row 9 still works offline")
        XCTAssertEqual(resolve([ent(5, yearlyID, expires: future, revoked: past)], nil), .readOnly(.revoked), "row 1 still works offline")
        XCTAssertEqual(resolve([], []), .readOnly(.notSubscribed), "an empty array is not nil")
        XCTAssertEqual(resolve([expiredYearly], []), .readOnly(.expired))
    }

    func testStatusOnlySubscribed() {
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, renews: future)]), sub(.yearly, future), "row 5")
        XCTAssertEqual(resolve([], [ren(monthlyID, .subscribed, auto: false, renews: future)]), sub(.monthly, future, auto: false))
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed)]), .readOnly(.unknown), "row 6: no renewalDate on iOS 17")
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, renews: past)]), .readOnly(.unknown))
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, renews: now)]), .readOnly(.unknown))
    }

    func testLatestTransactionMerge() {
        let activeYearly = ent(1, yearlyID, expires: future)
        let trialMonthly = ent(3, monthlyID, expires: now.addingTimeInterval(days(7)), intro: true)
        let expiredYearly = ent(4, yearlyID, expires: past)
        let revokedCopy = ent(1, yearlyID, expires: future, revoked: past)
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, latest: activeYearly)]), sub(.yearly, future), "latestTransaction fills an empty currentEntitlements")
        XCTAssertEqual(resolve([activeYearly], [ren(yearlyID, .subscribed, latest: revokedCopy)]), sub(.yearly, future), "same id: the entitlements side wins")
        XCTAssertEqual(resolve([], [ren(yearlyID, .subscribed, latest: revokedCopy)]), .readOnly(.revoked), "… without the entitlement the revoked copy counts")
        XCTAssertEqual(resolve([], [ren(yearlyID, .expired, latest: revokedCopy)]), .readOnly(.revoked), "row 1 before row 8")
        XCTAssertEqual(resolve([trialMonthly], [ren(monthlyID, .subscribed, latest: trialMonthly)]), trial(.monthly, now.addingTimeInterval(days(7))), "counted once")
        XCTAssertEqual(resolve([expiredYearly], [ren(yearlyID, .subscribed, latest: activeYearly)]), sub(.yearly, future), "a newer latestTransaction outranks an expired entitlement")
    }

    // MARK: reconcile (§1.3)

    func testReconcile() {
        let paid = sub(.yearly, now.addingTimeInterval(days(300)))
        let trying = trial(.monthly, now.addingTimeInterval(days(10)))
        let inGrace = sub(.monthly, future, grace: true)
        let lapsedCancelled = sub(.monthly, past, auto: false)
        // a
        XCTAssertEqual(reconcile(.readOnly(.expired), paid, reachable: true), .readOnly(.expired))
        XCTAssertEqual(reconcile(paid, nil, reachable: true), paid)
        // b
        XCTAssertEqual(reconcile(paid, .readOnly(.expired), reachable: false), paid)
        XCTAssertEqual(reconcile(trying, nil, reachable: false), trying)
        // c
        XCTAssertEqual(reconcile(.readOnly(.revoked), paid, reachable: false), .readOnly(.revoked))
        // d
        XCTAssertEqual(reconcile(.readOnly(.notSubscribed), paid, reachable: false), paid)
        XCTAssertEqual(reconcile(.readOnly(.expired), inGrace, reachable: false), inGrace, "live expired, cache in grace → cache")
        XCTAssertEqual(reconcile(.readOnly(.unknown), paid, reachable: false), paid)
        XCTAssertEqual(reconcile(.readOnly(.billingRetry), trying, reachable: false), trying)
        XCTAssertEqual(reconcile(.readOnly(.notSubscribed), sub(.yearly, past), reachable: false), sub(.yearly, past), "the 3-day allowance applies")
        // e
        XCTAssertEqual(reconcile(.readOnly(.notSubscribed), .readOnly(.revoked), reachable: false), .readOnly(.revoked))
        XCTAssertEqual(reconcile(.readOnly(.unknown), .readOnly(.expired), reachable: false), .readOnly(.expired))
        XCTAssertEqual(reconcile(.readOnly(.unknown), lapsedCancelled, reachable: false), .readOnly(.expired))
        XCTAssertEqual(reconcile(.readOnly(.notSubscribed), .readOnly(.billingRetry), reachable: false), .readOnly(.billingRetry))
        // f
        XCTAssertEqual(reconcile(.readOnly(.notSubscribed), nil, reachable: false), .readOnly(.unknown))
        XCTAssertEqual(reconcile(.readOnly(.unknown), nil, reachable: false), .readOnly(.unknown))
        XCTAssertEqual(reconcile(.readOnly(.expired), nil, reachable: false), .readOnly(.unknown))
        XCTAssertEqual(reconcile(.readOnly(.billingRetry), nil, reachable: false), .readOnly(.unknown))
        // g
        XCTAssertEqual(reconcile(.readOnly(.expired), lapsedCancelled, reachable: false), .readOnly(.expired))
        XCTAssertEqual(reconcile(.readOnly(.billingRetry), .readOnly(.expired), reachable: false), .readOnly(.billingRetry))
        XCTAssertEqual(reconcile(.readOnly(.expired), .readOnly(.revoked), reachable: false), .readOnly(.expired))
    }
}
