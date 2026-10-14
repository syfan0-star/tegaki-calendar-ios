import Foundation

/// The timing rules of the sync engine (M4_CONTRACT §3.5, the web version's ink-store.js): a 1.5 s
/// debounce after a save, retries from 15 s doubling up to 5 minutes. Pure arithmetic; the engine
/// owns the clock.
public struct SyncBackoff: Equatable, Sendable {
    /// Seconds from the last save to the push.
    public static let debounce: TimeInterval = 1.5
    /// First retry after a failure.
    public static let minimum: TimeInterval = 15
    /// Longest wait between retries (5 minutes).
    public static let maximum: TimeInterval = 300
    /// How often a `serverRecordChanged` save is merged and saved again before giving up until next time.
    public static let maxConflictRetries = 3
    /// The same page is not fetched individually again within this many seconds of the last fetch.
    public static let pageFetchCooldown: TimeInterval = 30
    /// The silent-push handler returns to iOS within this many seconds (M4_CONTRACT §4.4).
    public static let notificationBudget: TimeInterval = 20
    /// `failures` never grows beyond this (2^30 × 15 is far past `maximum` anyway).
    public static let maxFailures = 30

    /// Consecutive failures so far (0 after a success).
    public private(set) var failures: Int

    public init(failures: Int = 0) {
        self.failures = min(SyncBackoff.maxFailures, max(0, failures))
    }

    /// `min(300, 15 × 2^failures)`: 15, 30, 60, 120, 240, 300, 300, …
    public var nextDelay: TimeInterval {
        SyncBackoff.delay(afterFailures: failures)
    }

    /// When the server said how long to wait (`CKErrorRetryAfterKey`), the longer of the two.
    public func nextDelay(serverHint: TimeInterval?) -> TimeInterval {
        guard let hint = serverHint, hint.isFinite else { return nextDelay }
        return max(hint, nextDelay)
    }

    /// `failures += 1`, capped at 30.
    public mutating func recordFailure() {
        failures = min(SyncBackoff.maxFailures, failures + 1)
    }

    /// Back to 0 after a success.
    public mutating func reset() {
        failures = 0
    }

    /// The wait after `n` consecutive failures: `min(300, 15 × 2^n)` (n below 0 counts as 0).
    public static func delay(afterFailures n: Int) -> TimeInterval {
        let exponent = min(maxFailures, max(0, n))
        var delay = minimum
        for _ in 0..<exponent {
            delay *= 2
            if delay >= maximum { return maximum }
        }
        return min(maximum, delay)
    }
}
