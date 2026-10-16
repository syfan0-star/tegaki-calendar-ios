import XCTest
import Foundation
import Access

/// `AccessSnapshot` / `AccessCache` (M5_CONTRACT §1.3): the JSON round trip, corrupt data, and
/// `stateForLaunch` with the 3-day offline allowance (M5-30). The same checks run in KitChecks.
final class AccessCacheTests: XCTestCase {
    /// 2025-10-09T08:53:20Z, a whole second (the ISO 8601 strategy keeps whole seconds only).
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private func days(_ n: Double) -> TimeInterval { n * 86_400 }
    private var future: Date { now.addingTimeInterval(days(20)) }

    private func sub(_ plan: Plan, _ until: Date, auto: Bool = true, grace: Bool = false) -> AccessState {
        .subscribed(Subscription(plan: plan, until: until, willAutoRenew: auto, inGrace: grace))
    }

    private func trial(_ plan: Plan, _ until: Date, auto: Bool = true) -> AccessState {
        .trial(Trial(plan: plan, until: until, willAutoRenew: auto))
    }

    private func launch(_ state: AccessState?, at t: Date) -> AccessState {
        AccessCache.stateForLaunch(cached: state.map { AccessSnapshot(state: $0, savedAt: now) }, now: t)
    }

    func testRoundTrip() {
        let snapshots = [
            AccessSnapshot(state: sub(.yearly, future), savedAt: now),
            AccessSnapshot(state: trial(.monthly, now.addingTimeInterval(days(3)), auto: false), savedAt: now),
            AccessSnapshot(state: .readOnly(.revoked), savedAt: now),
            AccessSnapshot(state: sub(.monthly, future, auto: false, grace: true), savedAt: now.addingTimeInterval(-days(1))),
        ]
        for snapshot in snapshots {
            XCTAssertEqual(AccessCache.decode(AccessCache.encode(snapshot)), snapshot, "\(snapshot.state)")
        }
        let json = String(decoding: AccessCache.encode(snapshots[0]), as: UTF8.self)
        XCTAssertTrue(json.contains("\"subscribed\""), json)
        XCTAssertTrue(json.contains("\"plan\":\"yearly\""), json)
        XCTAssertTrue(json.contains("\"savedAt\":\"2025-10-09T08:53:20Z\""), "ISO 8601 dates: \(json)")
        XCTAssertTrue(json.contains("\"inGrace\":false"), json)
        for reason in [ReadOnlyReason.notSubscribed, .expired, .billingRetry, .revoked, .unknown] {
            let snapshot = AccessSnapshot(state: .readOnly(reason), savedAt: now)
            XCTAssertEqual(AccessCache.decode(AccessCache.encode(snapshot)), snapshot)
        }
    }

    func testCorruptData() {
        XCTAssertNil(AccessCache.decode(Data()))
        XCTAssertNil(AccessCache.decode(Data("not json".utf8)))
        XCTAssertNil(AccessCache.decode(Data("{}".utf8)))
        XCTAssertNil(AccessCache.decode(Data(#"{"state":{"readOnly":"expired"},"savedAt":1}"#.utf8)))
        let good = AccessCache.encode(AccessSnapshot(state: sub(.yearly, future), savedAt: now))
        XCTAssertNil(AccessCache.decode(good.dropLast()), "a truncated document")
        XCTAssertNotNil(AccessCache.decode(good))
    }

    func testStateForLaunch() {
        let paid = sub(.yearly, now.addingTimeInterval(days(300)))
        let trying = trial(.monthly, now.addingTimeInterval(days(10)))
        XCTAssertEqual(launch(nil, at: now), .readOnly(.unknown))
        XCTAssertEqual(launch(paid, at: now), paid)
        XCTAssertEqual(launch(trying, at: now), trying)
        XCTAssertEqual(launch(sub(.monthly, now, auto: false), at: now), .readOnly(.expired), "cancelled and past → expired at once")
        XCTAssertEqual(launch(sub(.monthly, now, auto: false), at: now - 1), sub(.monthly, now, auto: false))
        XCTAssertEqual(launch(sub(.monthly, now, grace: true), at: now), .readOnly(.billingRetry), "grace over → billingRetry")
        XCTAssertEqual(launch(sub(.monthly, future, grace: true), at: now), sub(.monthly, future, grace: true))
        XCTAssertEqual(launch(trial(.yearly, now, auto: false), at: now), .readOnly(.expired))
        for reason in [ReadOnlyReason.notSubscribed, .expired, .billingRetry, .revoked, .unknown] {
            XCTAssertEqual(launch(.readOnly(reason), at: now), .readOnly(reason))
        }
    }

    func testOfflineRenewalAllowance() {
        XCTAssertEqual(AccessCache.offlineRenewalAllowanceDays, 3)
        let autoRenewing = sub(.monthly, now)
        XCTAssertEqual(launch(autoRenewing, at: now), autoRenewing, "until == now → still usable")
        XCTAssertEqual(launch(autoRenewing, at: now.addingTimeInterval(days(2))), autoRenewing, "until + 2 days → still usable")
        XCTAssertEqual(launch(autoRenewing, at: now.addingTimeInterval(days(3)) - 1), autoRenewing)
        XCTAssertEqual(launch(autoRenewing, at: now.addingTimeInterval(days(3))), .readOnly(.expired), "until + 3 days → expired")
        XCTAssertEqual(launch(sub(.monthly, now, grace: true), at: now.addingTimeInterval(days(1))), .readOnly(.billingRetry), "no allowance in grace")
        XCTAssertEqual(launch(sub(.monthly, now, auto: false), at: now.addingTimeInterval(days(1))), .readOnly(.expired), "no allowance when cancelled")
        let autoTrial = trial(.yearly, now)
        XCTAssertEqual(launch(autoTrial, at: now.addingTimeInterval(days(2))), autoTrial, "a converting trial gets it too")
        XCTAssertEqual(launch(autoTrial, at: now.addingTimeInterval(days(3))), .readOnly(.expired))
        XCTAssertEqual(launch(trial(.yearly, now, auto: false), at: now.addingTimeInterval(days(1))), .readOnly(.expired))
    }
}
