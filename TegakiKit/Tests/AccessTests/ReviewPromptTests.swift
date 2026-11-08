import XCTest
import Foundation
import Access
import DayKit

/// `ReviewPrompt` and `ReviewRecord`, when the app may ask for the App Store rating prompt (docs/R1_2_1.md
/// §2.3, §2.5). The same cases run in KitChecks ("review prompt (1.2.1)").
final class ReviewPromptTests: XCTestCase {
    private let first = DayKey(year: 2026, month: 11, day: 10)
    private let subscribed = AccessState.subscribed(Subscription(plan: .yearly, until: Date(timeIntervalSince1970: 1_798_000_000), willAutoRenew: true, inGrace: false))
    private let trial = AccessState.trial(Trial(plan: .monthly, until: Date(timeIntervalSince1970: 1_798_000_000), willAutoRenew: true))

    /// Ink on day 0, 1 and 4 after `first`.
    private var three: ReviewRecord {
        [0, 1, 4].reduce(ReviewRecord()) { ReviewPrompt.inkWritten($0, today: first.adding(days: $1)) }
    }

    private func due(_ record: ReviewRecord, _ offset: Int, _ version: String = "1.2.1", _ access: AccessState? = nil) -> Bool {
        ReviewPrompt.isDue(record, today: first.adding(days: offset), version: version, access: access ?? subscribed)
    }

    func testNumbers() {
        XCTAssertEqual(ReviewPrompt.inkDaysNeeded, 3)
        XCTAssertEqual(ReviewPrompt.daysSinceFirstUse, 7)
        XCTAssertEqual(ReviewPrompt.daysBetweenRequests, 90)
        XCTAssertEqual(ReviewPrompt.quietAfterInk, 3)
        XCTAssertEqual(ReviewPrompt.activeAtLeast, 60)
        XCTAssertEqual(ReviewPrompt.pauseOnNewPage, 2)
    }

    func testEmptyRecord() {
        let record = ReviewRecord()
        XCTAssertNil(record.firstUseDay)
        XCTAssertEqual(record.inkDays, 0)
        XCTAssertNil(record.lastInkDay)
        XCTAssertNil(record.lastRequestVersion)
        XCTAssertNil(record.lastRequestDay)
        XCTAssertFalse(due(record, 365), "a record with nothing is never due")
    }

    func testUsedOn() {
        XCTAssertEqual(ReviewPrompt.usedOn(ReviewRecord(), today: first), ReviewRecord(firstUseDay: first), "nil → today")
        XCTAssertEqual(ReviewPrompt.usedOn(ReviewRecord(firstUseDay: first), today: first.adding(days: 5)).firstUseDay, first, "an earlier day stays")
    }

    func testInkWritten() {
        let one = ReviewPrompt.inkWritten(ReviewRecord(), today: first)
        XCTAssertEqual(one.inkDays, 1, "the first day")
        XCTAssertEqual(one.firstUseDay, first, "ink is a use too")
        XCTAssertEqual(one.lastInkDay, first)
        XCTAssertEqual(ReviewPrompt.inkWritten(one, today: first), one, "the same day counts once")
        XCTAssertEqual(three.inkDays, 3, "three different days")
        XCTAssertEqual(three.lastInkDay, first.adding(days: 4))
        XCTAssertEqual(three.firstUseDay, first)
    }

    func testIsDue() {
        XCTAssertFalse(due(three, 6), "day 6 is too early")
        XCTAssertTrue(due(three, 7), "day 7, subscribed")
        XCTAssertTrue(due(three, 7, "1.2.1", trial), "in the trial too")
        let two = [0, 1].reduce(ReviewRecord()) { ReviewPrompt.inkWritten($0, today: first.adding(days: $1)) }
        XCTAssertFalse(due(two, 30), "two days of ink are not enough")
        XCTAssertFalse(due(ReviewRecord(inkDays: 3, lastInkDay: first.adding(days: 4)), 30), "not without a first day")
        XCTAssertFalse(due(three, -1), "not on a day before the first use (a clock set back)")
        XCTAssertFalse(due(three, 7, ""), "not without a version")
    }

    func testNotWhileReadOnly() {
        for reason in [ReadOnlyReason.notSubscribed, .expired, .billingRetry, .revoked, .unknown] {
            XCTAssertFalse(due(three, 7, "1.2.1", .readOnly(reason)), reason.rawValue)
        }
    }

    func testRequested() {
        let askedOn = first.adding(days: 7)
        let asked = ReviewPrompt.requested(three, today: askedOn, version: "1.2.1")
        XCTAssertEqual(asked.lastRequestVersion, "1.2.1")
        XCTAssertEqual(asked.lastRequestDay, askedOn)
        XCTAssertEqual(asked.inkDays, 0, "the ink counts again from zero")
        XCTAssertEqual(asked.lastInkDay, askedOn)
        XCTAssertEqual(ReviewPrompt.inkWritten(asked, today: askedOn).inkDays, 0, "ink on the day of the request does not count")
        XCTAssertEqual(asked.firstUseDay, first, "the first day stays")
        XCTAssertEqual(ReviewPrompt.requested(ReviewRecord(), today: askedOn, version: "1.2.1").firstUseDay, askedOn, "a request is a use too")
    }

    func testTheNextVersion() {
        let askedOn = first.adding(days: 7)
        let asked = ReviewPrompt.requested(three, today: askedOn, version: "1.2.1")
        let later = [1, 2, 3].reduce(asked) { ReviewPrompt.inkWritten($0, today: askedOn.adding(days: $1)) }
        XCTAssertEqual(later.inkDays, 3)
        XCTAssertFalse(due(later, 7 + 200, "1.2.1"), "never twice in one version")
        XCTAssertFalse(due(later, 7 + 89, "1.3"), "89 days after the request is too early")
        XCTAssertTrue(due(later, 7 + 90, "1.3"), "90 days after the request, in a new version")
        XCTAssertFalse(due(asked, 7 + 90, "1.3"), "not in a new version without new days of ink")
        let longAgo = ReviewRecord(firstUseDay: first.adding(days: -300), inkDays: 3, lastInkDay: first.adding(days: -2),
                                   lastRequestVersion: "1.2.1", lastRequestDay: first)
        XCTAssertFalse(due(longAgo, -1, "1.3"), "not on a day before the request (a clock set back)")
        XCTAssertTrue(due(longAgo, 90, "1.3"), "(the same record 90 days after the request)")
    }

    func testIsCalmMoment() {
        XCTAssertFalse(ReviewPrompt.isCalmMoment(leftPageWithInk: false, secondsSinceInk: 10, secondsActive: 600), "a page without ink")
        XCTAssertFalse(ReviewPrompt.isCalmMoment(leftPageWithInk: true, secondsSinceInk: nil, secondsActive: 600), "no time of the ink")
        XCTAssertFalse(ReviewPrompt.isCalmMoment(leftPageWithInk: true, secondsSinceInk: 2.9, secondsActive: 600), "2.9 s after the ink")
        XCTAssertTrue(ReviewPrompt.isCalmMoment(leftPageWithInk: true, secondsSinceInk: 3, secondsActive: 60), "3 s after the ink, 60 s in front")
        XCTAssertFalse(ReviewPrompt.isCalmMoment(leftPageWithInk: true, secondsSinceInk: 10, secondsActive: 59), "59 s in front")
    }
}
