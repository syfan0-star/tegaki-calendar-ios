import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

/// `InkPage` ⇄ `CloudRecord` (M4_CONTRACT §4.3, §8.2): the fields, the body being the same bytes as
/// the file, the round trip, the seen version, and the `Meta` record.
final class InkPageRecordTests: XCTestCase {
    private let pageId = "m1-2026-10"

    private func makeStroke(id: String, t: Int = 1_760_000_001_000) -> InkStroke {
        let points = (0..<4).map { i in
            InkPoint(x: CGFloat(10 + i * 5), y: CGFloat(20 + i), dtMs: i * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: .day(DayKey(year: 2026, month: 10, day: 14)), tool: .pen, color: "#1f2937", t: t, points: points)
    }

    private func makePage() -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        page.add(makeStroke(id: "a1"))
        page.add(makeStroke(id: "b2", t: 1_760_000_002_000))
        page.remove(ids: ["zz"], at: 1_760_000_000_500)
        return page
    }

    func testMakeFields() throws {
        let page = makePage()
        let record = try InkPageRecord.make(page, seen: nil)
        XCTAssertEqual(record.recordType, "InkPage")
        XCTAssertEqual(record.recordName, pageId)
        XCTAssertNil(record.changeTag)
        XCTAssertNil(record.systemFields)
        XCTAssertEqual(record.fields["schema"], .int(1))
        XCTAssertEqual(record.fields["updatedAt"], .date(Date(timeIntervalSince1970: 1_760_000_002)))
        XCTAssertEqual(record.fields["strokeCount"], .int(2))
        XCTAssertEqual(record.fields["app"], .string(InkPageRecord.appString))
        XCTAssertTrue(InkPageRecord.appString.hasPrefix("ios/"))
        XCTAssertEqual(InkPageRecord.appString.split(separator: "/").count, 3)
        XCTAssertEqual(record.fields.count, 5)
    }

    func testDocIsTheFileBytes() throws {
        let page = makePage()
        let record = try InkPageRecord.make(page, seen: nil)
        let expected = try InkPageCodec.compress(try InkPageCodec.encode(page))
        XCTAssertEqual(record.fields["doc"], .asset(expected))
        // The same bytes `InkPageStore` writes.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InkPageRecordTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = InkPageStore(directory: directory)
        try store.save(page)
        XCTAssertEqual(try Data(contentsOf: store.url(for: pageId)), expected)
    }

    func testPageRoundTrip() throws {
        let page = makePage()
        let record = try InkPageRecord.make(page, seen: nil)
        let back = try InkPageRecord.page(from: record)
        XCTAssertEqual(back, page)
        XCTAssertEqual(back.liveStrokeIds, ["a1", "b2"])
        XCTAssertEqual(back.deleted, ["zz": 1_760_000_000_500])
    }

    func testMissingOrBrokenDocThrows() throws {
        var record = try InkPageRecord.make(makePage(), seen: nil)
        record.fields["doc"] = nil
        XCTAssertThrowsError(try InkPageRecord.page(from: record)) { error in
            XCTAssertTrue(error is InkCodecError)
        }
        record.fields["doc"] = .asset(Data([1, 2, 3, 4]))
        XCTAssertThrowsError(try InkPageRecord.page(from: record)) { error in
            XCTAssertTrue(error is InkCodecError)
        }
        record.fields["doc"] = .asset(try InkPageCodec.compress(Data("[1, 2]".utf8)))
        XCTAssertThrowsError(try InkPageRecord.page(from: record)) { error in
            XCTAssertEqual(error as? InkCodecError, .notAnObject)
        }
    }

    func testEmptyOrDifferentPageIdBecomesTheRecordName() throws {
        let page = makePage()
        var record = try InkPageRecord.make(page, seen: nil)
        var json = page.jsonValue.objectValue!
        json["pageId"] = .string("")
        record.fields["doc"] = .asset(try InkPageCodec.compress(JSONValue.object(json).serializedData()))
        XCTAssertEqual(try InkPageRecord.page(from: record).pageId, pageId)

        json["pageId"] = .string("w-2026-10-05")
        record.fields["doc"] = .asset(try InkPageCodec.compress(JSONValue.object(json).serializedData()))
        let back = try InkPageRecord.page(from: record)
        XCTAssertEqual(back.pageId, pageId)
        XCTAssertEqual(back.liveStrokeIds, ["a1", "b2"])
    }

    func testSeenIsCopied() throws {
        let seen = SeenRecord(changeTag: "jx3pq", systemFields: Data("sys:jx3pq".utf8))
        let record = try InkPageRecord.make(makePage(), seen: seen)
        XCTAssertEqual(record.changeTag, "jx3pq")
        XCTAssertEqual(record.systemFields, Data("sys:jx3pq".utf8))
        XCTAssertEqual(InkPageRecord.seen(from: record), seen)

        let fresh = try InkPageRecord.make(makePage(), seen: nil)
        XCTAssertNil(InkPageRecord.seen(from: fresh))

        var tagOnly = fresh
        tagOnly.changeTag = "t9"
        XCTAssertEqual(InkPageRecord.seen(from: tagOnly), SeenRecord(changeTag: "t9", systemFields: nil))
    }

    func testMetaWritesOnlyTheGivenDates() {
        let bare = InkPageRecord.makeMeta(webImportedAt: nil, trialStartedAt: nil, seen: nil)
        XCTAssertEqual(bare.recordType, "Meta")
        XCTAssertEqual(bare.recordName, "meta")
        XCTAssertEqual(bare.fields["schema"], .int(1))
        XCTAssertEqual(bare.fields["app"], .string(InkPageRecord.appString))
        XCTAssertNil(bare.fields["webImportedAt"])
        XCTAssertNil(bare.fields["trialStartedAt"])
        XCTAssertEqual(bare.fields.count, 2)
        XCTAssertNil(bare.changeTag)

        let web = Date(timeIntervalSince1970: 1_760_150_000)
        let trial = Date(timeIntervalSince1970: 1_760_000_000)
        let seen = SeenRecord(changeTag: "t3", systemFields: Data("sys:t3".utf8))
        let full = InkPageRecord.makeMeta(webImportedAt: web, trialStartedAt: trial, seen: seen)
        XCTAssertEqual(full.fields["webImportedAt"], .date(web))
        XCTAssertEqual(full.fields["trialStartedAt"], .date(trial))
        XCTAssertEqual(full.changeTag, "t3")
        XCTAssertEqual(full.systemFields, Data("sys:t3".utf8))

        let webOnly = InkPageRecord.makeMeta(webImportedAt: web, trialStartedAt: nil, seen: nil)
        XCTAssertEqual(webOnly.fields["webImportedAt"], .date(web))
        XCTAssertNil(webOnly.fields["trialStartedAt"])
    }

    func testMetaValues() {
        let web = Date(timeIntervalSince1970: 1_760_150_000)
        let trial = Date(timeIntervalSince1970: 1_760_000_000)
        let full = InkPageRecord.makeMeta(webImportedAt: web, trialStartedAt: trial, seen: nil)
        let values = InkPageRecord.metaValues(from: full)
        XCTAssertEqual(values.webImportedAt, web)
        XCTAssertEqual(values.trialStartedAt, trial)

        let bare = InkPageRecord.metaValues(from: InkPageRecord.makeMeta(webImportedAt: nil, trialStartedAt: nil, seen: nil))
        XCTAssertNil(bare.webImportedAt)
        XCTAssertNil(bare.trialStartedAt)

        var odd = full
        odd.fields["webImportedAt"] = .string("2026-10-14")
        XCTAssertNil(InkPageRecord.metaValues(from: odd).webImportedAt)
        XCTAssertEqual(InkPageRecord.metaValues(from: odd).trialStartedAt, trial)
    }

    func testMillisecondHelpers() {
        let date = Date(timeIntervalSince1970: 1_760_150_500.123)
        XCTAssertEqual(InkPageRecord.ms(from: date), 1_760_150_500_123)
        XCTAssertEqual(InkPageRecord.date(fromMs: 1_760_150_500_123).timeIntervalSince1970, 1_760_150_500.123, accuracy: 0.0005)
    }
}
