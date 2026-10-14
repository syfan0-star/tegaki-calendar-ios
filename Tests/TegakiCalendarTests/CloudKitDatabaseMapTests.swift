import CloudKit
import XCTest
@testable import TegakiCalendar

/// `CKError` → `CloudError` (M4_CONTRACT §4.2, §8.2). The errors are made with
/// `NSError(domain: CKErrorDomain, …)`, so nothing talks to iCloud; `CKRecord` objects can be made
/// without a container. `encodeToken` / `decodeToken` need a real `CKServerChangeToken` (device only).
final class CloudKitDatabaseMapTests: XCTestCase {
    private func ckError(_ code: CKError.Code, userInfo: [String: Any] = [:]) -> NSError {
        NSError(domain: CKErrorDomain, code: code.rawValue, userInfo: userInfo)
    }

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "tegaki", ownerName: CKCurrentUserDefaultName)
    }

    func testNetwork() {
        XCTAssertEqual(CloudKitDatabase.map(ckError(.networkUnavailable)), .networkUnavailable)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.networkFailure)), .networkUnavailable)
        XCTAssertEqual(CloudKitDatabase.map(URLError(.notConnectedToInternet)), .networkUnavailable)
        XCTAssertEqual(CloudKitDatabase.map(URLError(.networkConnectionLost)), .networkUnavailable)
    }

    func testSimpleCodes() {
        XCTAssertEqual(CloudKitDatabase.map(ckError(.notAuthenticated)), .notAuthenticated)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.unknownItem)), .recordNotFound)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.zoneNotFound)), .zoneMissing)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.userDeletedZone)), .zoneMissing)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.changeTokenExpired)), .changeTokenExpired)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.quotaExceeded)), .quotaExceeded)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.limitExceeded)), .limitExceeded)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.permissionFailure)), .permissionFailure)
        XCTAssertEqual(CloudKitDatabase.map(ckError(.managedAccountRestricted)), .permissionFailure)
    }

    func testRetryLater() {
        XCTAssertEqual(CloudKitDatabase.map(ckError(.zoneBusy, userInfo: [CKErrorRetryAfterKey: 120])), .retryLater(after: 120))
        XCTAssertEqual(CloudKitDatabase.map(ckError(.serviceUnavailable, userInfo: [CKErrorRetryAfterKey: 30.5])), .retryLater(after: 30.5))
        XCTAssertEqual(CloudKitDatabase.map(ckError(.requestRateLimited)), .retryLater(after: nil))
        XCTAssertEqual(CloudKitDatabase.map(ckError(.accountTemporarilyUnavailable, userInfo: [CKErrorRetryAfterKey: 5])), .retryLater(after: nil))
    }

    func testConfiguration() {
        for code in [CKError.Code.badContainer, .missingEntitlement, .invalidArguments, .serverRejectedRequest] {
            let error = ckError(code, userInfo: [NSLocalizedDescriptionKey: "bad \(code.rawValue)"])
            XCTAssertEqual(CloudKitDatabase.map(error), .configuration("bad \(code.rawValue)"), "\(code)")
        }
    }

    func testOther() {
        let error = ckError(.internalError, userInfo: [NSLocalizedDescriptionKey: "internal"])
        XCTAssertEqual(CloudKitDatabase.map(error), .other("internal"))
        XCTAssertEqual(CloudKitDatabase.map(ckError(.assetFileNotFound)), .other(ckError(.assetFileNotFound).localizedDescription))
        struct Odd: Error {}
        if case .other = CloudKitDatabase.map(Odd()) {} else {
            XCTFail("a non-CKError is .other")
        }
        XCTAssertEqual(CloudKitDatabase.map(CloudError.quotaExceeded), .quotaExceeded)
    }

    func testServerRecordChangedCarriesTheServerRecord() {
        let server = CKRecord(recordType: "InkPage", recordID: CKRecord.ID(recordName: "m1-2026-10", zoneID: zoneID))
        server["schema"] = NSNumber(value: 1)
        server["app"] = "ios/0.5.0/1" as NSString
        let error = ckError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
        guard case .serverRecordChanged(let record) = CloudKitDatabase.map(error) else {
            return XCTFail("expected .serverRecordChanged")
        }
        XCTAssertEqual(record.recordType, "InkPage")
        XCTAssertEqual(record.recordName, "m1-2026-10")
        XCTAssertNil(record.changeTag) // never saved
        XCTAssertNotNil(record.systemFields)
        XCTAssertEqual(record.fields["schema"], .int(1))
        XCTAssertEqual(record.fields["app"], .string("ios/0.5.0/1"))
    }

    func testPartialFailureUnwrapsTheItemError() {
        let recordID = CKRecord.ID(recordName: "m1-2026-10", zoneID: zoneID)
        let server = CKRecord(recordType: "InkPage", recordID: recordID)
        let conflict = ckError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
        let partial = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: conflict]])
        guard case .serverRecordChanged(let record) = CloudKitDatabase.map(partial) else {
            return XCTFail("expected the conflict inside the partial failure")
        }
        XCTAssertEqual(record.recordName, "m1-2026-10")

        let missing = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: ckError(.unknownItem)]])
        XCTAssertEqual(CloudKitDatabase.map(missing), .recordNotFound)

        // A conflict is preferred over an unknown item when both are inside.
        let other = CKRecord.ID(recordName: "w-2026-10-05", zoneID: zoneID)
        let mixed = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [other: ckError(.unknownItem), recordID: conflict]])
        if case .serverRecordChanged = CloudKitDatabase.map(mixed) {} else {
            XCTFail("expected the conflict")
        }

        let empty = ckError(.partialFailure, userInfo: [NSLocalizedDescriptionKey: "partial"])
        XCTAssertEqual(CloudKitDatabase.map(empty), .other("partial"))
    }

    func testUnknownItemHelpers() {
        XCTAssertTrue(CloudKitDatabase.isUnknownItem(ckError(.unknownItem)))
        XCTAssertFalse(CloudKitDatabase.isUnknownItem(ckError(.zoneNotFound)))
        let recordID = CKRecord.ID(recordName: "m1-2026-10", zoneID: zoneID)
        let onlyUnknown = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: ckError(.unknownItem)]])
        XCTAssertTrue(CloudKitDatabase.isPartialFailureOfOnlyUnknownItems(onlyUnknown))
        let real = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: ckError(.quotaExceeded)]])
        XCTAssertFalse(CloudKitDatabase.isPartialFailureOfOnlyUnknownItems(real))
        XCTAssertFalse(CloudKitDatabase.isPartialFailureOfOnlyUnknownItems(ckError(.unknownItem)))
    }

    func testSubscriptionIDOfAnEmptyUserInfo() {
        let database = CloudKitDatabase()
        XCTAssertNil(database.subscriptionID(in: [:]))
        XCTAssertNil(database.subscriptionID(in: ["aps": ["content-available": 1]]))
    }

    func testConstants() {
        XCTAssertEqual(CloudKitDatabase.containerIdentifier, "iCloud.com.syfan0.tegakicalendar")
        XCTAssertEqual(CloudKitDatabase.zoneName, "tegaki")
        XCTAssertEqual(CloudKitDatabase.subscriptionID, "tegaki-zone-changes")
        XCTAssertEqual(CloudKitDatabase.zoneID, zoneID)
    }

    func testRecordConversionRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_760_000_002)
        let body = Data("hello".utf8)
        let record = CloudRecord(
            recordType: "InkPage", recordName: "m1-2026-10", changeTag: nil, systemFields: nil,
            fields: ["schema": .int(1), "updatedAt": .date(date), "strokeCount": .int(2), "doc": .asset(body), "app": .string("ios/0.5.0/1")]
        )
        let (ckRecord, files) = try CloudKitDatabase.ckRecord(from: record)
        defer { for url in files { try? FileManager.default.removeItem(at: url) } }
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].lastPathComponent.hasPrefix("m1-2026-10-"))
        XCTAssertTrue(files[0].lastPathComponent.hasSuffix(".json.lzfse"))
        XCTAssertEqual(files[0].deletingLastPathComponent().lastPathComponent, CloudKitDatabase.uploadDirectoryName)
        XCTAssertEqual(ckRecord.recordType, "InkPage")
        XCTAssertEqual(ckRecord.recordID.recordName, "m1-2026-10")
        XCTAssertEqual(ckRecord.recordID.zoneID, zoneID)

        let back = CloudKitDatabase.cloudRecord(from: ckRecord)
        XCTAssertEqual(back.recordType, "InkPage")
        XCTAssertEqual(back.recordName, "m1-2026-10")
        XCTAssertEqual(back.fields["schema"], .int(1))
        XCTAssertEqual(back.fields["strokeCount"], .int(2))
        XCTAssertEqual(back.fields["app"], .string("ios/0.5.0/1"))
        XCTAssertEqual(back.fields["doc"], .asset(body))
        if case .date(let d)? = back.fields["updatedAt"] {
            XCTAssertEqual(d.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("updatedAt is a date")
        }
        XCTAssertNotNil(back.systemFields)

        // The system fields restore a record with the same identity.
        let restored = CloudRecord(recordType: "InkPage", recordName: "m1-2026-10", changeTag: nil, systemFields: back.systemFields, fields: ["schema": .int(1)])
        let (again, more) = try CloudKitDatabase.ckRecord(from: restored)
        XCTAssertTrue(more.isEmpty)
        XCTAssertEqual(again.recordID, ckRecord.recordID)
        XCTAssertEqual(again.recordType, "InkPage")
    }

    func testClearUploadDirectory() throws {
        let url = try CloudKitDatabase.writeUploadFile(Data([1, 2, 3]), recordName: "w-2026-10-05")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        CloudKitDatabase.clearUploadDirectory()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
