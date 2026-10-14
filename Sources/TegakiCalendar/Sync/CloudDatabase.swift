import Foundation

/// A field value of a cloud record (M4_CONTRACT §4.1). `asset` is the bytes of a CKAsset; the real
/// adapter writes them to a temporary file for the upload and reads the downloaded file back.
enum CloudValue: Equatable, Sendable {
    case int(Int64)
    case string(String)
    case date(Date)
    case asset(Data)
}

/// A copy of one record's values. `fields` are named as in M4_CONTRACT §2.2. `changeTag` is the
/// version the server gave it (nil for a record that was never saved); `systemFields` is
/// `CKRecord.encodeSystemFields` of that version (nil for a new record; the fake derives it from
/// the change tag). The engine treats both as opaque.
struct CloudRecord: Equatable, Sendable {
    /// "InkPage" or "Meta".
    var recordType: String
    var recordName: String
    var changeTag: String?
    var systemFields: Data?
    var fields: [String: CloudValue]
}

/// The result of one zone fetch: `changed` holds added and changed records (the adapter follows
/// `moreComing` and merges everything into one result), `deletedNames` the names of deleted
/// records, `token` the new change token.
struct CloudZoneChanges: Equatable, Sendable {
    var changed: [CloudRecord]
    var deletedNames: [String]
    var token: Data?
}

enum CloudAccountStatus: Equatable, Sendable {
    case available, noAccount, restricted, couldNotDetermine, temporarilyUnavailable
}

/// The errors the engine understands (M4_CONTRACT §4.1, §4.5). The real adapter maps `CKError`
/// to these (`CloudKitDatabase.map`); the fake throws them directly.
enum CloudError: Error, Equatable {
    /// CKError.notAuthenticated.
    case notAuthenticated
    /// .networkUnavailable / .networkFailure (and URLError's connection failures).
    case networkUnavailable
    /// The save conflicted; `server` is the current version (CKRecordChangedErrorServerRecordKey).
    case serverRecordChanged(server: CloudRecord)
    /// .unknownItem: the record does not exist (saved with the system fields of a record another
    /// device erased, for example).
    case recordNotFound
    /// .zoneNotFound / .userDeletedZone: the whole zone is gone (the person deleted the app's data
    /// in the iCloud settings, for example).
    case zoneMissing
    /// .changeTokenExpired: forget the token and fetch everything.
    case changeTokenExpired
    /// .quotaExceeded.
    case quotaExceeded
    /// .zoneBusy / .serviceUnavailable / .requestRateLimited (`after` = CKErrorRetryAfterKey, seconds)
    /// / .accountTemporarilyUnavailable (`after` nil).
    case retryLater(after: TimeInterval?)
    /// .limitExceeded: the batch was too large, split it in half.
    case limitExceeded
    /// .permissionFailure / .managedAccountRestricted.
    case permissionFailure
    /// A permanent configuration mistake (.badContainer / .missingEntitlement / .invalidArguments /
    /// .serverRejectedRequest): no automatic retry.
    case configuration(String)
    /// Anything else (`localizedDescription`).
    case other(String)
}

/// Everything the engine needs from iCloud, in one protocol (M4_CONTRACT §4.1, DESIGN §5). The
/// real adapter is `CloudKitDatabase` (the only file that imports CloudKit); `InMemoryCloudDatabase`
/// is the fake that the tests, the screenshot mode and the XCTest host use.
protocol CloudDatabase: AnyObject {
    func accountStatus() async throws -> CloudAccountStatus
    /// `CKContainer.userRecordID().recordName`, the identity of the account. Only called when the
    /// status is `.available`; the first call needs the network.
    func userRecordName() async throws -> String
    /// Creates the zone "tegaki" (success when it exists already).
    func ensureZone() async throws
    /// Creates the `CKRecordZoneSubscription` "tegaki-zone-changes" (success when it exists; the fake
    /// only records it).
    func ensureSubscription() async throws
    /// `CKFetchRecordZoneChangesOperation`. `token` nil fetches everything; the adapter follows
    /// `moreComing`. `namesOnly` leaves the body (`doc`) out (`desiredKeys = []`: names, change tags
    /// and the small fields only; used by the erase and after a zone loss).
    func fetchChanges(since token: Data?, namesOnly: Bool) async throws -> CloudZoneChanges
    /// `CKFetchRecordsOperation`. Names that do not exist are simply absent (no throw).
    func fetchRecords(names: [String]) async throws -> [String: CloudRecord]
    /// Saves one record with `.ifServerRecordUnchanged`. With `systemFields` the CKRecord is restored
    /// from them and the fields written over it; without, a new CKRecord is made. Returns the saved
    /// version (change tag and system fields filled in). A conflict is `.serverRecordChanged(server:)`;
    /// a record whose system fields point at nothing is `.recordNotFound`.
    func save(_ record: CloudRecord) async throws -> CloudRecord
    /// `CKModifyRecordsOperation(recordIDsToDelete:)`, not atomic. Names that do not exist count as
    /// deleted. At most 200 names per call (`.limitExceeded` otherwise; the engine splits).
    func delete(names: [String]) async throws
    /// The subscription id inside the `userInfo` of a silent push (the real adapter asks
    /// `CKNotification`, the fake reads `userInfo["subscriptionID"]`). nil when it is not ours.
    func subscriptionID(in userInfo: [AnyHashable: Any]) -> String?
    /// `.CKAccountChanged`. One stream per database, the same object on every read (the fake's
    /// `simulateAccountChange` feeds the one the engine is consuming).
    var accountChanges: AsyncStream<Void> { get }
}

extension CloudDatabase {
    /// `fetchChanges(since:namesOnly: false)`.
    func fetchChanges(since token: Data?) async throws -> CloudZoneChanges {
        try await fetchChanges(since: token, namesOnly: false)
    }
}
