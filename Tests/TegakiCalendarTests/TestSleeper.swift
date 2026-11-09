import Foundation

/// The `sleep` the engine tests hand to `SyncEngine` (M4_CONTRACT §8.2): records every requested
/// wait and suspends until `advance()` (or returns at once with `autoResume`), so the debounce, the
/// retries and the 20 s notification budget are checked without waiting. 1.2.3 (docs/R1_2_3.md §4):
/// `advance()` wakes the sleeps one at a time, in the order they started, and returns only when the woken
/// task is back on the main actor and counted by the engine again; between two of them the engine settles.
@MainActor
final class TestSleeper {
    /// The lengths of every `sleep`, in order.
    private(set) var recorded: [TimeInterval] = []
    /// True: record and return immediately.
    var autoResume = false
    /// Run between two woken sleeps (`makeEngine` sets it to the engine's `waitUntilIdle`).
    var settle: @MainActor () async -> Void = {}
    private var parked: [CheckedContinuation<Void, Never>] = []
    /// The one `advance()` waiting for its woken sleep to land (never two `advance()` at once).
    private var landing: CheckedContinuation<Void, Never>?

    /// How many sleeps are suspended right now.
    var waiting: Int { parked.count }

    func sleep(_ duration: TimeInterval) async {
        recorded.append(duration)
        guard !autoResume else { return }
        await withCheckedContinuation { continuation in
            parked.append(continuation)
        }
        // Back on the main actor: `advance()` goes on after this job, i.e. after the engine's `pause` has
        // counted the task again and it has queued its work (the engine's `sleep` is @MainActor).
        let landed = landing
        landing = nil
        landed?.resume()
    }

    /// Wakes every sleep suspended now, one at a time in the order they started; from the second on, the
    /// engine settles first. Not to be called from two tasks at once, nor with two or more sleeps parked
    /// while the fake has an operation paused (`settle` would wait for it).
    func advance() async {
        let batch = parked
        parked = []
        for (index, continuation) in batch.enumerated() {
            if index > 0 { await settle() }
            await withCheckedContinuation { (landed: CheckedContinuation<Void, Never>) in
                landing = landed
                continuation.resume()
            }
        }
    }
}
