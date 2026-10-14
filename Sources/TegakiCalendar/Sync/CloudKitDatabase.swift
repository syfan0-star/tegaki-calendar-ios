import CloudKit
import Foundation

/// The real `CloudDatabase` on `CKContainer.privateCloudDatabase` (M4_CONTRACT §4.2, §2). This is
/// the only file that imports CloudKit. `init` creates nothing: the container is made on the first
/// call (a process without the iCloud entitlement crashes when it makes a `CKContainer`, and the
/// CI simulator never calls this class, §4.4). Asset bodies travel through
/// `tmp/tegaki-upload/<recordName>-<UUID>.json.lzfse`, removed once the save is done.
@MainActor
final class CloudKitDatabase: CloudDatabase {
    nonisolated static let containerIdentifier = "iCloud.com.syfan0.tegakicalendar"
    nonisolated static let zoneName = "tegaki"
    nonisolated static let subscriptionID = "tegaki-zone-changes"
    /// Under `FileManager.temporaryDirectory`.
    nonisolated static let uploadDirectoryName = "tegaki-upload"

    nonisolated static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    nonisolated let accountChanges: AsyncStream<Void>

    private let identifier: String
    private var containerStorage: CKContainer?

    nonisolated init(containerIdentifier: String = CloudKitDatabase.containerIdentifier) {
        identifier = containerIdentifier
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        accountChanges = stream
        // The observer lives as long as the process (the engine's database is never released), so
        // the token is not kept.
        _ = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { _ in
            continuation.yield(())
        }
    }

    /// The container, made on first use.
    private var container: CKContainer {
        if let existing = containerStorage { return existing }
        let made = CKContainer(identifier: identifier)
        containerStorage = made
        return made
    }

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    // MARK: - CloudDatabase

    func accountStatus() async throws -> CloudAccountStatus {
        do {
            switch try await container.accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .couldNotDetermine: return .couldNotDetermine
            case .temporarilyUnavailable: return .temporarilyUnavailable
            @unknown default: return .couldNotDetermine
            }
        } catch {
            throw CloudKitDatabase.map(error)
        }
    }

    func userRecordName() async throws -> String {
        do {
            return try await container.userRecordID().recordName
        } catch {
            throw CloudKitDatabase.map(error)
        }
    }

    func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: CloudKitDatabase.zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        let database = self.database
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: CloudKitDatabase.map(error))
                }
            }
            database.add(operation)
        }
    }

    func ensureSubscription() async throws {
        let subscription = CKRecordZoneSubscription(zoneID: CloudKitDatabase.zoneID, subscriptionID: CloudKitDatabase.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        let database = self.database
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: CloudKitDatabase.map(error))
                }
            }
            database.add(operation)
        }
    }

    func fetchChanges(since token: Data?, namesOnly: Bool) async throws -> CloudZoneChanges {
        let zoneID = CloudKitDatabase.zoneID
        let database = self.database
        var previous = token.flatMap(CloudKitDatabase.decodeToken)
        var changed: [CloudRecord] = []
        var deleted: [String] = []
        var newToken: Data? = token
        // `fetchAllChanges` already follows `moreComing`; the loop is a belt for the braces.
        for _ in 0..<64 {
            let batch = ChangeBatch()
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = previous
            if namesOnly { configuration.desiredKeys = [] }
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])
            operation.fetchAllChanges = true
            operation.qualityOfService = .userInitiated
            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    batch.changed.append(CloudKitDatabase.cloudRecord(from: record))
                }
            }
            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                batch.deleted.append(recordID.recordName)
            }
            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let outcome):
                    batch.token = outcome.serverChangeToken
                    batch.moreComing = outcome.moreComing
                case .failure(let error):
                    batch.zoneError = error
                }
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.fetchRecordZoneChangesResultBlock = { result in
                    if let zoneError = batch.zoneError {
                        continuation.resume(throwing: CloudKitDatabase.map(zoneError))
                        return
                    }
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: CloudKitDatabase.map(error))
                    }
                }
                database.add(operation)
            }
            changed.append(contentsOf: batch.changed)
            deleted.append(contentsOf: batch.deleted)
            if let serverToken = batch.token {
                previous = serverToken
                newToken = CloudKitDatabase.encodeToken(serverToken)
            }
            if !batch.moreComing { break }
        }
        return CloudZoneChanges(changed: changed, deletedNames: deleted, token: newToken)
    }

    func fetchRecords(names: [String]) async throws -> [String: CloudRecord] {
        guard !names.isEmpty else { return [:] }
        let zoneID = CloudKitDatabase.zoneID
        let database = self.database
        let batch = FetchBatch()
        let operation = CKFetchRecordsOperation(recordIDs: names.map { CKRecord.ID(recordName: $0, zoneID: zoneID) })
        operation.qualityOfService = .userInitiated
        operation.perRecordResultBlock = { recordID, result in
            switch result {
            case .success(let record):
                batch.records[recordID.recordName] = CloudKitDatabase.cloudRecord(from: record)
            case .failure(let error):
                // A missing record is simply absent; anything else fails the call.
                if !CloudKitDatabase.isUnknownItem(error), batch.firstError == nil {
                    batch.firstError = error
                }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.fetchRecordsResultBlock = { result in
                if let error = batch.firstError {
                    continuation.resume(throwing: CloudKitDatabase.map(error))
                    return
                }
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if CloudKitDatabase.isPartialFailureOfOnlyUnknownItems(error) {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CloudKitDatabase.map(error))
                    }
                }
            }
            database.add(operation)
        }
        return batch.records
    }

    func save(_ record: CloudRecord) async throws -> CloudRecord {
        let (ckRecord, temporaryFiles) = try CloudKitDatabase.ckRecord(from: record)
        defer {
            for url in temporaryFiles { try? FileManager.default.removeItem(at: url) }
        }
        let database = self.database
        let batch = SaveBatch()
        let operation = CKModifyRecordsOperation(recordsToSave: [ckRecord], recordIDsToDelete: nil)
        operation.savePolicy = .ifServerRecordUnchanged
        operation.qualityOfService = .userInitiated
        operation.perRecordSaveBlock = { _, result in
            switch result {
            case .success(let saved):
                batch.saved = saved
            case .failure(let error):
                if batch.firstError == nil { batch.firstError = error }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                if let error = batch.firstError {
                    continuation.resume(throwing: CloudKitDatabase.map(error))
                    return
                }
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: CloudKitDatabase.map(error))
                }
            }
            database.add(operation)
        }
        guard let saved = batch.saved else {
            throw CloudError.other("The save returned no record")
        }
        return CloudKitDatabase.cloudRecord(from: saved)
    }

    func delete(names: [String]) async throws {
        guard names.count <= 200 else { throw CloudError.limitExceeded }
        guard !names.isEmpty else { return }
        let zoneID = CloudKitDatabase.zoneID
        let database = self.database
        let batch = SaveBatch()
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: names.map { CKRecord.ID(recordName: $0, zoneID: zoneID) })
        // Not atomic: one `.unknownItem` must not turn the rest into `batchRequestFailed`.
        operation.isAtomic = false
        operation.qualityOfService = .userInitiated
        operation.perRecordDeleteBlock = { _, result in
            if case .failure(let error) = result, !CloudKitDatabase.isUnknownItem(error), batch.firstError == nil {
                batch.firstError = error
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                if let error = batch.firstError {
                    continuation.resume(throwing: CloudKitDatabase.map(error))
                    return
                }
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if CloudKitDatabase.isPartialFailureOfOnlyUnknownItems(error) {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CloudKitDatabase.map(error))
                    }
                }
            }
            database.add(operation)
        }
    }

    nonisolated func subscriptionID(in userInfo: [AnyHashable: Any]) -> String? {
        (CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKRecordZoneNotification)?.subscriptionID
    }

    // MARK: - CKError → CloudError (M4_CONTRACT §4.2)

    nonisolated static func map(_ error: Error) -> CloudError {
        if let cloud = error as? CloudError { return cloud }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
                return .networkUnavailable
            default:
                return .other(urlError.localizedDescription)
            }
        }
        guard let ckError = error as? CKError else {
            return .other(error.localizedDescription)
        }
        switch ckError.code {
        case .partialFailure:
            // The error of the record itself is inside; prefer a conflict (it carries the server record).
            if let items = ckError.partialErrorsByItemID, !items.isEmpty {
                let errors = items.values
                if let conflict = errors.first(where: { ($0 as? CKError)?.code == .serverRecordChanged }) {
                    return map(conflict)
                }
                if let meaningful = errors.first(where: { !isUnknownItem($0) }) {
                    return map(meaningful)
                }
                if let first = errors.first { return map(first) }
            }
            return .other(ckError.localizedDescription)
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .notAuthenticated:
            return .notAuthenticated
        case .serverRecordChanged:
            if let server = ckError.serverRecord {
                return .serverRecordChanged(server: cloudRecord(from: server))
            }
            return .other(ckError.localizedDescription)
        case .unknownItem:
            return .recordNotFound
        case .zoneNotFound, .userDeletedZone:
            return .zoneMissing
        case .changeTokenExpired:
            return .changeTokenExpired
        case .quotaExceeded:
            return .quotaExceeded
        case .zoneBusy, .serviceUnavailable, .requestRateLimited:
            return .retryLater(after: retryAfter(ckError))
        case .accountTemporarilyUnavailable:
            return .retryLater(after: nil)
        case .limitExceeded:
            return .limitExceeded
        case .permissionFailure, .managedAccountRestricted:
            return .permissionFailure
        case .badContainer, .missingEntitlement, .invalidArguments, .serverRejectedRequest:
            return .configuration(ckError.localizedDescription)
        default:
            return .other(ckError.localizedDescription)
        }
    }

    /// `CKErrorRetryAfterKey` in seconds (read as an NSNumber of any kind; `retryAfterSeconds`
    /// ignores an integer value).
    nonisolated static func retryAfter(_ error: CKError) -> TimeInterval? {
        if let number = error.userInfo[CKErrorRetryAfterKey] as? NSNumber { return number.doubleValue }
        return error.retryAfterSeconds
    }

    nonisolated static func isUnknownItem(_ error: Error) -> Bool {
        (error as? CKError)?.code == .unknownItem
    }

    /// A `partialFailure` whose every item error is `.unknownItem` (a delete of names that are
    /// already gone, a fetch of names that do not exist): success for our purposes.
    nonisolated static func isPartialFailureOfOnlyUnknownItems(_ error: Error) -> Bool {
        guard let ckError = error as? CKError, ckError.code == .partialFailure,
              let items = ckError.partialErrorsByItemID, !items.isEmpty else { return false }
        return items.values.allSatisfy(isUnknownItem)
    }

    // MARK: - Tokens (NSKeyedArchiver, secure coding)

    nonisolated static func encodeToken(_ token: CKServerChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    nonisolated static func decodeToken(_ data: Data) -> CKServerChangeToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    // MARK: - CKRecord ⇄ CloudRecord

    /// A copy of the record's values. Assets are read from their `fileURL`; a missing or unreadable
    /// asset file leaves the field out (the engine then treats the record as broken).
    nonisolated static func cloudRecord(from record: CKRecord) -> CloudRecord {
        var fields: [String: CloudValue] = [:]
        for key in record.allKeys() {
            guard let value = record[key] else { continue }
            if let asset = value as? CKAsset {
                if let url = asset.fileURL, let data = try? Data(contentsOf: url) {
                    fields[key] = .asset(data)
                }
            } else if let date = value as? Date {
                fields[key] = .date(date)
            } else if let number = value as? NSNumber {
                fields[key] = .int(number.int64Value)
            } else if let string = value as? String {
                fields[key] = .string(string)
            }
        }
        return CloudRecord(
            recordType: record.recordType,
            recordName: record.recordID.recordName,
            changeTag: record.recordChangeTag,
            systemFields: encodeSystemFields(record),
            fields: fields
        )
    }

    nonisolated static func encodeSystemFields(_ record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    /// The CKRecord to save: restored from `systemFields` when present (so `.ifServerRecordUnchanged`
    /// knows the version), new otherwise. Asset bytes are written to `tmp/tegaki-upload/`; the
    /// caller removes the returned files after the save.
    nonisolated static func ckRecord(from record: CloudRecord) throws -> (CKRecord, [URL]) {
        var ckRecord: CKRecord?
        if let data = record.systemFields, let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
            unarchiver.requiresSecureCoding = true
            ckRecord = CKRecord(coder: unarchiver)
            unarchiver.finishDecoding()
        }
        let target = ckRecord ?? CKRecord(recordType: record.recordType, recordID: CKRecord.ID(recordName: record.recordName, zoneID: zoneID))
        var files: [URL] = []
        for (key, value) in record.fields {
            switch value {
            case .int(let number):
                target[key] = NSNumber(value: number)
            case .string(let string):
                target[key] = string as NSString
            case .date(let date):
                target[key] = date as NSDate
            case .asset(let data):
                let url = try writeUploadFile(data, recordName: record.recordName)
                files.append(url)
                target[key] = CKAsset(fileURL: url)
            }
        }
        return (target, files)
    }

    nonisolated static var uploadDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(uploadDirectoryName, isDirectory: true)
    }

    /// `tmp/tegaki-upload/<recordName>-<UUID>.json.lzfse` (the UUID keeps consecutive saves of one
    /// page and the leftovers of a crash apart).
    nonisolated static func writeUploadFile(_ data: Data, recordName: String) throws -> URL {
        let directory = uploadDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = InkPageStore.fileName(for: recordName).replacingOccurrences(of: ".json.lzfse", with: "")
        let url = directory.appendingPathComponent("\(name)-\(UUID().uuidString).json.lzfse", isDirectory: false)
        try data.write(to: url, options: [.atomic])
        return url
    }

    /// Empties `tmp/tegaki-upload/` (called by `SyncEngine.start()`).
    nonisolated static func clearUploadDirectory() {
        let fm = FileManager.default
        let directory = uploadDirectory
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: []) else { return }
        for item in items {
            try? fm.removeItem(at: item)
        }
    }

    // MARK: - Callback collectors (CloudKit calls the blocks one after another on its own queue)

    private final class ChangeBatch: @unchecked Sendable {
        var changed: [CloudRecord] = []
        var deleted: [String] = []
        var token: CKServerChangeToken?
        var moreComing = false
        var zoneError: Error?
    }

    private final class FetchBatch: @unchecked Sendable {
        var records: [String: CloudRecord] = [:]
        var firstError: Error?
    }

    private final class SaveBatch: @unchecked Sendable {
        var saved: CKRecord?
        var firstError: Error?
    }
}
