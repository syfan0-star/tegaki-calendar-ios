import Foundation
import InkModel

/// `InkPage` ⇄ `CloudRecord` and the `Meta` record (M4_CONTRACT §4.3, §2.2). The page body is always
/// an asset: the same bytes as the file on the device (`InkPageCodec.compress(encode(page))`).
enum InkPageRecord {
    static let recordType = "InkPage"
    static let metaRecordType = "Meta"
    static let metaRecordName = "meta"

    /// "ios/<CFBundleShortVersionString>/<CFBundleVersion>", e.g. "ios/0.5.0/1" ("ios/0/0" without a bundle).
    static var appString: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "0"
        let build = (info["CFBundleVersion"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "0"
        return "ios/\(version)/\(build)"
    }

    /// page → record. `seen` (the version last fetched or saved) supplies the change tag and the
    /// system fields, the basis of `.ifServerRecordUnchanged`.
    static func make(_ page: InkPage, seen: SeenRecord?) throws -> CloudRecord {
        let doc = try InkPageCodec.compress(try InkPageCodec.encode(page))
        let fields: [String: CloudValue] = [
            "schema": .int(Int64(page.v)),
            "updatedAt": .date(date(fromMs: page.updatedAt)),
            "strokeCount": .int(Int64(page.liveStrokeCount)),
            "doc": .asset(doc),
            "app": .string(appString),
        ]
        return CloudRecord(
            recordType: recordType,
            recordName: page.pageId,
            changeTag: seen?.changeTag,
            systemFields: seen?.systemFields,
            fields: fields
        )
    }

    /// record → page: `doc` decompressed and decoded. A JSON `pageId` that is empty or differs from
    /// the record name is replaced by the record name. Throws `InkCodecError` when `doc` is missing
    /// or broken.
    static func page(from record: CloudRecord) throws -> InkPage {
        guard case .asset(let doc)? = record.fields["doc"] else {
            throw InkCodecError.invalidJSON("the record has no doc asset")
        }
        var page = try InkPageCodec.decode(try InkPageCodec.decompress(doc))
        if page.pageId.isEmpty || page.pageId != record.recordName {
            page.pageId = record.recordName
        }
        return page
    }

    /// The version to remember after a fetch or a save; nil when the record was never saved.
    static func seen(from record: CloudRecord) -> SeenRecord? {
        guard let tag = record.changeTag else { return nil }
        return SeenRecord(changeTag: tag, systemFields: record.systemFields)
    }

    /// The `Meta` record (§1.2): `schema` 1, `app`, and the two dates only when given (to keep an
    /// existing value, copy the server's).
    static func makeMeta(webImportedAt: Date?, trialStartedAt: Date?, seen: SeenRecord?) -> CloudRecord {
        var fields: [String: CloudValue] = [
            "schema": .int(1),
            "app": .string(appString),
        ]
        if let webImportedAt = webImportedAt { fields["webImportedAt"] = .date(webImportedAt) }
        if let trialStartedAt = trialStartedAt { fields["trialStartedAt"] = .date(trialStartedAt) }
        return CloudRecord(
            recordType: metaRecordType,
            recordName: metaRecordName,
            changeTag: seen?.changeTag,
            systemFields: seen?.systemFields,
            fields: fields
        )
    }

    static func metaValues(from record: CloudRecord) -> (webImportedAt: Date?, trialStartedAt: Date?) {
        (webImportedAt: dateValue(record.fields["webImportedAt"]), trialStartedAt: dateValue(record.fields["trialStartedAt"]))
    }

    // MARK: - Helpers

    static func date(fromMs ms: Int) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000)
    }

    static func ms(from date: Date) -> Int {
        Int((date.timeIntervalSince1970 * 1000).rounded())
    }

    private static func dateValue(_ value: CloudValue?) -> Date? {
        if case .date(let date)? = value { return date }
        return nil
    }
}
