import Foundation

/// The `sleep` the engine tests hand to `SyncEngine` (M4_CONTRACT §8.2): records every requested
/// wait and suspends until `advance()` (or returns at once with `autoResume`), so the debounce, the
/// retries and the 20 s notification budget are checked without waiting.
@MainActor
final class TestSleeper {
    /// The lengths of every `sleep`, in order.
    private(set) var recorded: [TimeInterval] = []
    /// True: record and return immediately.
    var autoResume = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    /// How many sleeps are suspended right now.
    var waiting: Int { continuations.count }

    func sleep(_ duration: TimeInterval) async {
        recorded.append(duration)
        guard !autoResume else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    /// Returns every suspended sleep at once.
    func advance() {
        let waiting = continuations
        continuations = []
        for continuation in waiting { continuation.resume() }
    }
}
