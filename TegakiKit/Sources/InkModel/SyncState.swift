import Foundation

/// The server version of one page as last fetched or saved (M4_CONTRACT §1.1 `seen`).
public struct SeenRecord: Equatable, Sendable {
    /// `CKRecord.recordChangeTag`.
    public var changeTag: String
    /// `CKRecord.encodeSystemFields` of that version. nil: the adapter saves a fresh record and learns
    /// the real version from the conflict.
    public var systemFields: Data?

    public init(changeTag: String, systemFields: Data? = nil) {
        self.changeTag = changeTag
        self.systemFields = systemFields
    }
}

/// The sync ledger kept in `ink/state.json` (M4_CONTRACT §1.1, DESIGN §5.5): what still has to go to
/// iCloud, where the last fetch stopped, whose account the local data belongs to. Pure data; the app's
/// `SyncStateStore` reads and writes the file.
public struct SyncState: Equatable, Sendable {
    public static let currentVersion = 1
    /// The 11 keys of §1.1. Anything else is kept in `unknown` and written back.
    public static let knownKeys: Set<String> = [
        "v", "dirty", "zoneToken", "zoneReady", "subscriptionReady",
        "account", "pendingAccount", "pendingCloudErase", "seen", "lastSyncAt", "webImportedAt",
    ]

    /// Format version (1). Unknown versions are read and written back unchanged.
    public var v: Int
    /// Page ids not yet sent to iCloud, in the order they were queued, no duplicates.
    public var dirty: [String]
    /// `CKServerChangeToken`, archived. nil: the next fetch is a full one.
    public var zoneToken: Data?
    public var zoneReady: Bool
    public var subscriptionReady: Bool
    /// `userRecordID.recordName` of the account the local data belongs to.
    public var account: String?
    /// A different account is signed in and the user has not answered yet.
    public var pendingAccount: String?
    /// "Erase everything" still has to delete the iCloud records.
    public var pendingCloudErase: Bool
    public var seen: [String: SeenRecord]
    /// Last successful sync (fetch or push), ms since the epoch.
    public var lastSyncAt: Int?
    /// Copy of `Meta.webImportedAt` (display only).
    public var webImportedAt: Int?
    /// Top-level items this version does not know, written back as they were.
    public var unknown: [String: JSONValue]

    public init(
        v: Int = SyncState.currentVersion,
        dirty: [String] = [],
        zoneToken: Data? = nil,
        zoneReady: Bool = false,
        subscriptionReady: Bool = false,
        account: String? = nil,
        pendingAccount: String? = nil,
        pendingCloudErase: Bool = false,
        seen: [String: SeenRecord] = [:],
        lastSyncAt: Int? = nil,
        webImportedAt: Int? = nil,
        unknown: [String: JSONValue] = [:]
    ) {
        self.v = v
        self.dirty = SyncState.dedupe(dirty)
        self.zoneToken = zoneToken
        self.zoneReady = zoneReady
        self.subscriptionReady = subscriptionReady
        self.account = account
        self.pendingAccount = pendingAccount
        self.pendingCloudErase = pendingCloudErase
        self.seen = seen
        self.lastSyncAt = lastSyncAt
        self.webImportedAt = webImportedAt
        self.unknown = unknown
    }

    /// v 1, everything empty / false / nil.
    public static let empty = SyncState()

    // MARK: - JSON (M4_CONTRACT §1.1)

    /// Tolerant read: anything that is not an object is `empty`; duplicate `dirty` entries are
    /// dropped (first occurrence kept); broken `seen` items (not an object, no `tag`) are dropped;
    /// unknown top-level keys go to `unknown`.
    public init(json: JSONValue) {
        guard let obj = json.objectValue else {
            self = .empty
            return
        }
        let vRaw = obj["v"]?.doubleValue ?? Double(SyncState.currentVersion)
        let v = vRaw.isFinite && abs(vRaw) < 1e9 ? Int(vRaw.rounded()) : SyncState.currentVersion

        var dirty: [String] = []
        for item in obj["dirty"]?.arrayValue ?? [] {
            if let id = item.stringValue, !id.isEmpty { dirty.append(id) }
        }

        var seen: [String: SeenRecord] = [:]
        if let raw = obj["seen"]?.objectValue {
            for (pageId, value) in raw where !pageId.isEmpty {
                guard let entry = value.objectValue, let tag = entry["tag"]?.stringValue, !tag.isEmpty else { continue }
                seen[pageId] = SeenRecord(changeTag: tag, systemFields: SyncState.data(fromBase64: entry["sys"]))
            }
        }

        var unknown: [String: JSONValue] = [:]
        for (key, value) in obj where !SyncState.knownKeys.contains(key) {
            unknown[key] = value
        }

        self.init(
            v: v,
            dirty: dirty,
            zoneToken: SyncState.data(fromBase64: obj["zoneToken"]),
            zoneReady: obj["zoneReady"]?.boolValue ?? false,
            subscriptionReady: obj["subscriptionReady"]?.boolValue ?? false,
            account: SyncState.nonEmptyString(obj["account"]),
            pendingAccount: SyncState.nonEmptyString(obj["pendingAccount"]),
            pendingCloudErase: obj["pendingCloudErase"]?.boolValue ?? false,
            seen: seen,
            lastSyncAt: SyncState.time(obj["lastSyncAt"]),
            webImportedAt: SyncState.time(obj["webImportedAt"]),
            unknown: unknown
        )
    }

    /// The §1.1 object with sorted keys when serialized (`JSONValue.serialized`). nil values are
    /// written as `null`, `Data` as base64.
    public var jsonValue: JSONValue {
        var obj = unknown
        obj["v"] = .number(Double(v))
        obj["dirty"] = .array(dirty.map { .string($0) })
        obj["zoneToken"] = zoneToken.map { .string($0.base64EncodedString()) } ?? .null
        obj["zoneReady"] = .bool(zoneReady)
        obj["subscriptionReady"] = .bool(subscriptionReady)
        obj["account"] = account.map { .string($0) } ?? .null
        obj["pendingAccount"] = pendingAccount.map { .string($0) } ?? .null
        obj["pendingCloudErase"] = .bool(pendingCloudErase)
        var seenObj: [String: JSONValue] = [:]
        for (pageId, record) in seen {
            seenObj[pageId] = .object([
                "tag": .string(record.changeTag),
                "sys": record.systemFields.map { .string($0.base64EncodedString()) } ?? .null,
            ])
        }
        obj["seen"] = .object(seenObj)
        obj["lastSyncAt"] = lastSyncAt.map { .number(Double($0)) } ?? .null
        obj["webImportedAt"] = webImportedAt.map { .number(Double($0)) } ?? .null
        return .object(obj)
    }

    // MARK: - The dirty ledger (M4_CONTRACT §5.5)

    public var isDirty: Bool { !dirty.isEmpty }

    /// Queues the page unless it is queued already.
    public mutating func markDirty(_ pageId: String) {
        guard !pageId.isEmpty, !dirty.contains(pageId) else { return }
        dirty.append(pageId)
    }

    public mutating func clearDirty(_ pageId: String) {
        dirty.removeAll { $0 == pageId }
    }

    // MARK: - Transitions

    /// Starts using another iCloud account, keeping the handwriting: every local page is sent again,
    /// the token and the seen versions are forgotten, zone and subscription are made again.
    /// `unknown` and `webImportedAt` are kept.
    public mutating func adoptAccount(_ newAccount: String, allLocalPageIds: [String]) {
        account = newAccount
        pendingAccount = nil
        zoneToken = nil
        seen = [:]
        zoneReady = false
        subscriptionReady = false
        dirty = SyncState.dedupe(allLocalPageIds)
    }

    /// After "erase everything": nothing queued, nothing seen, next fetch is a full one, the cloud
    /// deletion is still pending when `cloudPending`. `account` / `zoneReady` / `subscriptionReady` are kept.
    public mutating func resetAfterErase(cloudPending: Bool) {
        dirty = []
        seen = [:]
        zoneToken = nil
        pendingCloudErase = cloudPending
        webImportedAt = nil
    }

    /// After the zone disappeared (M4_CONTRACT §4.5): every local page is sent again, token and seen
    /// versions forgotten, zone and subscription made again. `account` / `pendingCloudErase` /
    /// `webImportedAt` are kept.
    public mutating func resetAfterZoneLoss(allLocalPageIds: [String]) {
        zoneToken = nil
        seen = [:]
        zoneReady = false
        subscriptionReady = false
        dirty = SyncState.dedupe(allLocalPageIds)
    }

    // MARK: - Helpers

    /// Drops empty ids and later duplicates, keeping the order of first appearance.
    static func dedupe(_ ids: [String]) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for id in ids where !id.isEmpty && !seen.contains(id) {
            seen.insert(id)
            out.append(id)
        }
        return out
    }

    static func data(fromBase64 value: JSONValue?) -> Data? {
        guard let s = value?.stringValue, !s.isEmpty else { return nil }
        return Data(base64Encoded: s)
    }

    static func nonEmptyString(_ value: JSONValue?) -> String? {
        guard let s = value?.stringValue, !s.isEmpty else { return nil }
        return s
    }

    /// A time in ms: finite and > 0, else nil.
    static func time(_ value: JSONValue?) -> Int? {
        guard let d = value?.doubleValue, d.isFinite, d > 0, d < 1e15 else { return nil }
        return Int(d.rounded())
    }
}

/// `state.json` bytes ⇄ `SyncState`. Plain JSON, not compressed (the file is small).
public enum SyncStateCodec {
    public static func encode(_ state: SyncState) throws -> Data {
        state.jsonValue.serializedData()
    }

    /// Throws when the bytes are not JSON (`JSONValue.ParseError.invalidJSON`). JSON that is not an
    /// object decodes as `SyncState.empty`.
    public static func decode(_ data: Data) throws -> SyncState {
        SyncState(json: try JSONValue.parse(data))
    }
}
