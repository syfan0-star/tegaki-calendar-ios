import Foundation

/// The fake iCloud (M4_CONTRACT §4.6): records in memory, change tokens that are the index into a
/// change log, change tags "t1", "t2", …, and knobs to fail, pause and play "the other device". The
/// tests, the screenshot mode and the XCTest host use it; no CloudKit anywhere.
@MainActor
final class InMemoryCloudDatabase: CloudDatabase {
    enum Operation: Hashable {
        case accountStatus, userRecordName, ensureZone, ensureSubscription, fetchChanges, fetchRecords, save, delete
    }

    var status: CloudAccountStatus = .available
    var userName: String = "_user-a"
    /// recordName → the current version.
    var records: [String: CloudRecord] = [:]
    /// Names the engine deleted through `delete(names:)`.
    private(set) var deletedNames: Set<String> = []
    private(set) var subscriptionIDs: Set<String> = []
    /// True after `ensureZone`; while false, `save` / `fetch*` / `delete` throw `.zoneMissing`.
    private(set) var zoneExists = false
    /// The error the next call of that operation throws (consumed by that call).
    var failNext: [Operation: CloudError] = [:]
    /// The error every call throws while set.
    var alwaysFail: CloudError?
    /// Every call, in order.
    private(set) var calls: [Operation] = []
    /// The `namesOnly` flag of every `fetchChanges` call, in order (so a test can tell the erase's
    /// listings from the pull).
    private(set) var fetchChangesNamesOnly: [Bool] = []

    nonisolated let accountChanges: AsyncStream<Void>
    private let accountContinuation: AsyncStream<Void>.Continuation

    /// The change log: one entry per save or delete, in order; the token is the index of the last
    /// entry seen.
    private var log: [(name: String, deleted: Bool)] = []
    private var tagCounter = 0
    private var tokenExpired = false
    private var pausedOperation: Operation?
    private var pauseContinuation: CheckedContinuation<Void, Never>?

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        accountChanges = stream
        accountContinuation = continuation
    }

    // MARK: - The other device

    /// Stores `record` as another device would: a new change tag, an entry in the change log.
    @discardableResult
    func simulateRemoteSave(_ record: CloudRecord) -> CloudRecord {
        let stored = version(of: record)
        records[record.recordName] = stored
        log.append((name: record.recordName, deleted: false))
        return stored
    }

    func simulateRemoteDelete(_ name: String) {
        guard records.removeValue(forKey: name) != nil else { return }
        log.append((name: name, deleted: true))
    }

    /// Changes the account and sends `.CKAccountChanged` down the one `accountChanges` stream.
    func simulateAccountChange(status: CloudAccountStatus, userName: String) {
        self.status = status
        self.userName = userName
        accountContinuation.yield(())
    }

    /// The person deleted the app's data in the iCloud settings: the zone, its records, its
    /// history and its subscriptions are gone.
    func simulateZoneDeleted() {
        zoneExists = false
        records = [:]
        log = []
        subscriptionIDs = []
    }

    /// The next `fetchChanges(since:)` with a token throws `.changeTokenExpired`.
    func expireToken() {
        tokenExpired = true
    }

    /// The next call of `op` suspends until `resume()` (once): makes a "sending" state.
    func pause(_ op: Operation) {
        pausedOperation = op
    }

    func resume() {
        pausedOperation = nil
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    // MARK: - CloudDatabase

    func accountStatus() async throws -> CloudAccountStatus {
        try await gate(.accountStatus, needsZone: false)
        return status
    }

    func userRecordName() async throws -> String {
        try await gate(.userRecordName, needsZone: false)
        return userName
    }

    func ensureZone() async throws {
        try await gate(.ensureZone, needsZone: false)
        zoneExists = true
    }

    func ensureSubscription() async throws {
        try await gate(.ensureSubscription, needsZone: true)
        subscriptionIDs.insert(CloudKitDatabase.subscriptionID)
    }

    func fetchChanges(since token: Data?, namesOnly: Bool) async throws -> CloudZoneChanges {
        fetchChangesNamesOnly.append(namesOnly)
        try await gate(.fetchChanges, needsZone: true)
        if token != nil, tokenExpired {
            tokenExpired = false
            throw CloudError.changeTokenExpired
        }
        let since = token.flatMap(InMemoryCloudDatabase.index(fromToken:)) ?? 0
        var names: [String] = []
        var seenNames = Set<String>()
        if since < log.count {
            for entry in log[since...] where !seenNames.contains(entry.name) {
                seenNames.insert(entry.name)
                names.append(entry.name)
            }
        }
        var changed: [CloudRecord] = []
        var deleted: [String] = []
        for name in names {
            if var record = records[name] {
                if namesOnly { record.fields["doc"] = nil }
                changed.append(record)
            } else {
                deleted.append(name)
            }
        }
        return CloudZoneChanges(changed: changed, deletedNames: deleted, token: InMemoryCloudDatabase.token(forIndex: log.count))
    }

    func fetchRecords(names: [String]) async throws -> [String: CloudRecord] {
        try await gate(.fetchRecords, needsZone: true)
        var out: [String: CloudRecord] = [:]
        for name in names {
            if let record = records[name] { out[name] = record }
        }
        return out
    }

    func save(_ record: CloudRecord) async throws -> CloudRecord {
        try await gate(.save, needsZone: true)
        let current = records[record.recordName]
        if record.changeTag != nil, current == nil {
            throw CloudError.recordNotFound
        }
        if record.changeTag != current?.changeTag, let current = current {
            throw CloudError.serverRecordChanged(server: current)
        }
        let stored = version(of: record)
        records[record.recordName] = stored
        log.append((name: record.recordName, deleted: false))
        return stored
    }

    func delete(names: [String]) async throws {
        try await gate(.delete, needsZone: true)
        guard names.count <= 200 else { throw CloudError.limitExceeded }
        for name in names where records.removeValue(forKey: name) != nil {
            deletedNames.insert(name)
            log.append((name: name, deleted: true))
        }
    }

    nonisolated func subscriptionID(in userInfo: [AnyHashable: Any]) -> String? {
        userInfo["subscriptionID"] as? String
    }

    // MARK: - Private

    /// Records the call, pauses when asked, throws the planned error, checks the zone.
    private func gate(_ op: Operation, needsZone: Bool) async throws {
        calls.append(op)
        if pausedOperation == op {
            pausedOperation = nil
            await withCheckedContinuation { continuation in
                pauseContinuation = continuation
            }
        }
        if let error = failNext.removeValue(forKey: op) { throw error }
        if let error = alwaysFail { throw error }
        if needsZone, !zoneExists { throw CloudError.zoneMissing }
    }

    /// A copy of `record` with the next change tag and the matching system fields ("sys:" + tag).
    private func version(of record: CloudRecord) -> CloudRecord {
        tagCounter += 1
        var stored = record
        stored.changeTag = "t\(tagCounter)"
        stored.systemFields = Data("sys:t\(tagCounter)".utf8)
        return stored
    }

    nonisolated static func token(forIndex index: Int) -> Data {
        Data(String(index).utf8)
    }

    nonisolated static func index(fromToken token: Data) -> Int? {
        guard let text = String(data: token, encoding: .utf8), let index = Int(text), index >= 0 else { return nil }
        return index
    }
}
