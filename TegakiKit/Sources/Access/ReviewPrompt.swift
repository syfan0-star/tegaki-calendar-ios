// 1.2.1 (docs/R1_2_1.md §2.3, §2.5): when the app may ask StoreKit for the App Store rating prompt.
// Pure: the app keeps the record in UserDefaults (`AppSettings.reviewRecord`, §2.6), counts the days
// with its own ink, and calls SwiftUI's `requestReview` only when `isDue` and `isCalmMoment` both hold
// (`CalendarRootScreen.scheduleReviewRequest`). Apple decides at the end whether the prompt shows.
import Foundation
import DayKit

/// What this device remembers for the rating prompt (five UserDefaults keys, docs/R1_2_1.md §2.6). It
/// stays on the device: it is never sent to iCloud (D16).
public struct ReviewRecord: Equatable, Sendable {
    /// The first day the app ran with this record (someone who used 1.2: 1.2.1's first launch).
    public var firstUseDay: DayKey?
    /// The days with the person's own ink since the last request (since the first use before that).
    public var inkDays: Int
    /// The last day counted in `inkDays`.
    public var lastInkDay: DayKey?
    /// The marketing version (CFBundleShortVersionString) of the last request.
    public var lastRequestVersion: String?
    /// The day of the last request.
    public var lastRequestDay: DayKey?

    public init(firstUseDay: DayKey? = nil, inkDays: Int = 0, lastInkDay: DayKey? = nil,
                lastRequestVersion: String? = nil, lastRequestDay: DayKey? = nil) {
        self.firstUseDay = firstUseDay
        self.inkDays = inkDays
        self.lastInkDay = lastInkDay
        self.lastRequestVersion = lastRequestVersion
        self.lastRequestDay = lastRequestDay
    }
}

/// The rule of the rating prompt (docs/R1_2_1.md §2.3): rarely, after real use, at a calm moment.
public enum ReviewPrompt {
    /// Days with the person's own ink since the last request.
    public static let inkDaysNeeded = 3
    /// Days from the first use to today.
    public static let daysSinceFirstUse = 7
    /// Days from the last request to today (also: once per marketing version).
    public static let daysBetweenRequests = 90
    /// Seconds from the last ink change to ◀ ▶.
    public static let quietAfterInk: TimeInterval = 3
    /// Seconds the app has been in front (never right after a launch or a return).
    public static let activeAtLeast: TimeInterval = 60
    /// Seconds of stillness on the new page before the request (Apple's sample waits 2 s).
    public static let pauseOnNewPage: Double = 2

    /// The record with its first use: `today` when none is on record, the recorded day otherwise.
    public static func usedOn(_ record: ReviewRecord, today: DayKey) -> ReviewRecord {
        guard record.firstUseDay == nil else { return record }
        var next = record
        next.firstUseDay = today
        return next
    }

    /// The person's own ink changed today: one more day when today is not counted yet (after `usedOn`).
    public static func inkWritten(_ record: ReviewRecord, today: DayKey) -> ReviewRecord {
        var next = usedOn(record, today: today)
        guard next.lastInkDay != today else { return next }
        next.inkDays += 1
        next.lastInkDay = today
        return next
    }

    /// Whether the prompt may be asked for: someone who can edit (subscribed or in the trial), a known
    /// version not asked in yet, `inkDaysNeeded` days of ink, `daysSinceFirstUse` days since the first
    /// use, and `daysBetweenRequests` days since the last request. A clock set back before the first
    /// use (or the last request) gives a negative difference, so it is not due.
    public static func isDue(_ record: ReviewRecord, today: DayKey, version: String, access: AccessState) -> Bool {
        guard access.canEdit, !version.isEmpty, record.lastRequestVersion != version,
              record.inkDays >= inkDaysNeeded,
              let first = record.firstUseDay, today.dayNumber - first.dayNumber >= daysSinceFirstUse
        else { return false }
        if let last = record.lastRequestDay, today.dayNumber - last.dayNumber < daysBetweenRequests {
            return false
        }
        return true
    }

    /// The record after a request (written before the call: StoreKit never says whether it showed the
    /// prompt): the version and the day, and the ink counted again from zero — a stroke on the same day
    /// does not count, so the next version needs `inkDaysNeeded` new days.
    public static func requested(_ record: ReviewRecord, today: DayKey, version: String) -> ReviewRecord {
        var next = usedOn(record, today: today)
        next.lastRequestVersion = version
        next.lastRequestDay = today
        next.inkDays = 0
        next.lastInkDay = today
        return next
    }

    /// The moment of ◀ ▶: the page left was written on while it was open, the last ink change was at
    /// least `quietAfterInk` ago, and the app has been in front for `activeAtLeast`.
    public static func isCalmMoment(leftPageWithInk: Bool, secondsSinceInk: TimeInterval?, secondsActive: TimeInterval) -> Bool {
        guard leftPageWithInk, let quiet = secondsSinceInk else { return false }
        return quiet >= quietAfterInk && secondsActive >= activeAtLeast
    }
}
