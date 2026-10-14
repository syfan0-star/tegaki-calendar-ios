import XCTest
import Foundation
import CoreGraphics
import InkModel

/// `SyncState` / `SyncStateCodec` (M4_CONTRACT §1.1, §3.4), `SyncBackoff` (§3.5) and the `InkPage`
/// additions for sync (§3.6). The same checks run in KitChecks.
final class SyncStateTests: XCTestCase {
    /// The §1.1 example (token and system fields shortened).
    private let example = #"""
    { "v": 1, "dirty": ["m1-2026-10", "w-2026-10-05"],
      "zoneToken": "YnBsaXN0MDDUAQID", "zoneReady": true, "subscriptionReady": true,
      "account": "_0123456789abcdef0123456789abcdef", "pendingAccount": null, "pendingCloudErase": false,
      "seen": { "m1-2026-10": { "tag": "jx3pq", "sys": "YnBsaXN0MDDUAQID" } },
      "lastSyncAt": 1760150500000, "webImportedAt": 1760150000000 }
    """#

    private func exampleState() throws -> SyncState {
        try SyncStateCodec.decode(Data(example.utf8))
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func stroke(_ id: String, t: Int = 1_760_000_001_000) -> InkStroke {
        let p = InkPoint(x: 10, y: 20, dtMs: 0, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.5708)
        return InkStroke(id: id, cell: .day(day(2026, 10, 4)), tool: .pen, color: "#1f2937", t: t, dev: "ipad-1", points: [p])
    }

    // MARK: SyncState (§3.4)

    func testEmpty() {
        let empty = SyncState.empty
        XCTAssertEqual(empty.v, 1)
        XCTAssertEqual(empty.dirty, [])
        XCTAssertNil(empty.zoneToken)
        XCTAssertFalse(empty.zoneReady)
        XCTAssertFalse(empty.subscriptionReady)
        XCTAssertNil(empty.account)
        XCTAssertNil(empty.pendingAccount)
        XCTAssertFalse(empty.pendingCloudErase)
        XCTAssertEqual(empty.seen, [:])
        XCTAssertNil(empty.lastSyncAt)
        XCTAssertNil(empty.webImportedAt)
        XCTAssertEqual(empty.unknown, [:])
        XCTAssertFalse(empty.isDirty)
        XCTAssertEqual(empty.jsonValue.serialized(), #"{"account":null,"dirty":[],"lastSyncAt":null,"pendingAccount":null,"pendingCloudErase":false,"seen":{},"subscriptionReady":false,"v":1,"webImportedAt":null,"zoneReady":false,"zoneToken":null}"#, "sorted keys")
        XCTAssertEqual(SyncState(json: empty.jsonValue), empty)
        XCTAssertEqual(SyncState(json: .object([:])), empty)
        XCTAssertEqual(SyncState(json: .array([])), empty, "a non-object reads as empty")
        XCTAssertEqual(SyncState(json: .null), empty)
        XCTAssertEqual(SyncState.currentVersion, 1)
        XCTAssertEqual(SyncState.knownKeys.count, 11)
        XCTAssertEqual(SyncState.knownKeys, ["v", "dirty", "zoneToken", "zoneReady", "subscriptionReady", "account", "pendingAccount", "pendingCloudErase", "seen", "lastSyncAt", "webImportedAt"])
    }

    func testExampleRoundTrip() throws {
        let state = try exampleState()
        XCTAssertEqual(state.v, 1)
        XCTAssertEqual(state.dirty, ["m1-2026-10", "w-2026-10-05"], "in order")
        XCTAssertEqual(state.zoneToken, Data(base64Encoded: "YnBsaXN0MDDUAQID"))
        XCTAssertTrue(state.zoneReady)
        XCTAssertTrue(state.subscriptionReady)
        XCTAssertEqual(state.account, "_0123456789abcdef0123456789abcdef")
        XCTAssertNil(state.pendingAccount)
        XCTAssertFalse(state.pendingCloudErase)
        XCTAssertEqual(state.seen, ["m1-2026-10": SeenRecord(changeTag: "jx3pq", systemFields: Data(base64Encoded: "YnBsaXN0MDDUAQID"))])
        XCTAssertEqual(state.lastSyncAt, 1_760_150_500_000)
        XCTAssertEqual(state.webImportedAt, 1_760_150_000_000)
        XCTAssertEqual(state.unknown, [:])
        XCTAssertTrue(state.isDirty)
        XCTAssertEqual(SyncState(json: state.jsonValue), state, "jsonValue → init(json:)")
        XCTAssertEqual(try SyncStateCodec.decode(try SyncStateCodec.encode(state)), state, "codec round trip")
        XCTAssertEqual(try JSONValue.parse(try SyncStateCodec.encode(state)), state.jsonValue)
        let text = String(decoding: try SyncStateCodec.encode(state), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix(#"{"account":"_0123456789abcdef0123456789abcdef","dirty":["m1-2026-10","w-2026-10-05"],"lastSyncAt":1760150500000,"#), "keys sorted, numbers plain: \(text)")
        XCTAssertTrue(text.contains(#""seen":{"m1-2026-10":{"sys":"YnBsaXN0MDDUAQID","tag":"jx3pq"}}"#), text)
        XCTAssertTrue(text.contains(#""zoneToken":"YnBsaXN0MDDUAQID""#), text)
        XCTAssertEqual(state.jsonValue["pendingAccount"], .null, "nil is written as null")
        XCTAssertEqual(SeenRecord(changeTag: "x").systemFields, nil, "SeenRecord's systemFields defaults to nil")
    }

    func testUnknownKeysAreWrittenBackAndBrokenItemsDropped() throws {
        let odd = SyncState(json: try JSONValue.parse(Data(#"""
        { "v": 3, "future": { "x": [1, 2] }, "note": "hi", "dirty": ["a", "b", "a", 5, "", "c", "b"],
          "zoneToken": "***not base64***", "zoneReady": "yes", "account": "", "pendingAccount": "_other",
          "seen": { "ok": { "tag": "t1" }, "noTag": { "sys": "AAAA" }, "emptyTag": { "tag": "" }, "notObject": "x", "badSys": { "tag": "t2", "sys": "%%%" }, "": { "tag": "t3" } },
          "lastSyncAt": -5, "webImportedAt": "soon", "pendingCloudErase": true }
        """#.utf8)))
        XCTAssertEqual(odd.v, 3, "an unknown version is kept")
        XCTAssertEqual(odd.unknown, ["future": .object(["x": .array([.number(1), .number(2)])]), "note": .string("hi")])
        XCTAssertEqual(odd.jsonValue["future"], .object(["x": .array([.number(1), .number(2)])]), "written back")
        XCTAssertEqual(odd.jsonValue["v"], .number(3))
        XCTAssertEqual(odd.dirty, ["a", "b", "c"], "duplicates, non-strings and empty ids dropped, order kept")
        XCTAssertNil(odd.zoneToken, "a token that is not base64")
        XCTAssertFalse(odd.zoneReady, "a non-bool")
        XCTAssertNil(odd.account, "an empty account")
        XCTAssertEqual(odd.pendingAccount, "_other")
        XCTAssertEqual(odd.seen.keys.sorted(), ["badSys", "ok"], "items without a tag, with an empty tag, not an object or with an empty page id are dropped")
        XCTAssertEqual(odd.seen["ok"], SeenRecord(changeTag: "t1"), "sys is optional")
        XCTAssertEqual(odd.seen["badSys"], SeenRecord(changeTag: "t2", systemFields: nil), "sys that is not base64 → nil")
        XCTAssertEqual(odd.jsonValue["seen"]?["ok"], .object(["tag": .string("t1"), "sys": .null]))
        XCTAssertNil(odd.lastSyncAt, "negative")
        XCTAssertNil(odd.webImportedAt, "non-numeric")
        XCTAssertTrue(odd.pendingCloudErase)
        XCTAssertEqual(SyncState(json: odd.jsonValue), odd, "round trip")
    }

    func testDirtyLedger() {
        var s = SyncState.empty
        s.markDirty("b")
        s.markDirty("a")
        s.markDirty("b")
        XCTAssertEqual(s.dirty, ["b", "a"], "order kept, duplicates ignored")
        s.markDirty("")
        XCTAssertEqual(s.dirty, ["b", "a"], "an empty id is ignored")
        XCTAssertTrue(s.isDirty)
        s.clearDirty("b")
        XCTAssertEqual(s.dirty, ["a"])
        s.clearDirty("zzz")
        XCTAssertEqual(s.dirty, ["a"], "clearing an unknown id is a no-op")
        s.clearDirty("a")
        XCTAssertFalse(s.isDirty)
        XCTAssertEqual(SyncState(dirty: ["x", "x", "y"]).dirty, ["x", "y"], "init dedupes")
    }

    func testAdoptAccount() throws {
        let state = try exampleState()
        var adopted = state
        adopted.unknown["keep"] = .bool(true)
        adopted.pendingAccount = "_new"
        adopted.pendingCloudErase = true
        adopted.adoptAccount("_new", allLocalPageIds: ["d-2026-10-07", "m1-2026-10", "d-2026-10-07"])
        XCTAssertEqual(adopted.account, "_new")
        XCTAssertNil(adopted.pendingAccount)
        XCTAssertNil(adopted.zoneToken)
        XCTAssertEqual(adopted.seen, [:])
        XCTAssertFalse(adopted.zoneReady)
        XCTAssertFalse(adopted.subscriptionReady)
        XCTAssertEqual(adopted.dirty, ["d-2026-10-07", "m1-2026-10"], "every local page, deduped")
        XCTAssertEqual(adopted.webImportedAt, 1_760_150_000_000, "kept")
        XCTAssertEqual(adopted.unknown["keep"], .bool(true), "kept")
        XCTAssertEqual(adopted.lastSyncAt, state.lastSyncAt, "kept")
        XCTAssertTrue(adopted.pendingCloudErase, "kept")
    }

    func testResetAfterErase() throws {
        let state = try exampleState()
        var erased = state
        erased.resetAfterErase(cloudPending: true)
        XCTAssertEqual(erased.dirty, [])
        XCTAssertEqual(erased.seen, [:])
        XCTAssertNil(erased.zoneToken)
        XCTAssertTrue(erased.pendingCloudErase)
        XCTAssertNil(erased.webImportedAt)
        XCTAssertEqual(erased.account, state.account, "kept")
        XCTAssertTrue(erased.zoneReady, "kept")
        XCTAssertTrue(erased.subscriptionReady, "kept")
        XCTAssertEqual(erased.lastSyncAt, state.lastSyncAt, "kept")
        var online = state
        online.resetAfterErase(cloudPending: false)
        XCTAssertFalse(online.pendingCloudErase)
    }

    func testResetAfterZoneLoss() throws {
        let state = try exampleState()
        var lost = state
        lost.pendingCloudErase = true
        lost.resetAfterZoneLoss(allLocalPageIds: ["y-2026", "m1-2026-10"])
        XCTAssertNil(lost.zoneToken)
        XCTAssertEqual(lost.seen, [:])
        XCTAssertFalse(lost.zoneReady)
        XCTAssertFalse(lost.subscriptionReady)
        XCTAssertEqual(lost.dirty, ["y-2026", "m1-2026-10"])
        XCTAssertEqual(lost.account, state.account, "kept")
        XCTAssertTrue(lost.pendingCloudErase, "kept")
        XCTAssertEqual(lost.webImportedAt, state.webImportedAt, "kept")
        XCTAssertNil(lost.pendingAccount, "unchanged")
    }

    func testCodecErrorsAndSortedKeys() throws {
        XCTAssertThrowsError(try SyncStateCodec.decode(Data("{ not json".utf8)))
        XCTAssertThrowsError(try SyncStateCodec.decode(Data()))
        XCTAssertEqual(try SyncStateCodec.decode(Data("[]".utf8)), .empty, "a non-object is empty")
        XCTAssertEqual(try SyncStateCodec.decode(Data("{\"v\":1}".utf8)), .empty)
        let state = try exampleState()
        XCTAssertEqual(state.jsonValue.objectValue?.keys.sorted(), ["account", "dirty", "lastSyncAt", "pendingAccount", "pendingCloudErase", "seen", "subscriptionReady", "v", "webImportedAt", "zoneReady", "zoneToken"], "every known key is written")
        let bytes = try SyncStateCodec.encode(state)
        XCTAssertEqual(bytes, try JSONValue.parse(bytes).serializedData(), "encode is already the sorted, compact form")
        var token = state
        token.zoneToken = Data([0, 1, 2, 255])
        XCTAssertEqual(token.jsonValue["zoneToken"], .string("AAEC/w=="))
        XCTAssertEqual(SyncState(json: token.jsonValue).zoneToken, Data([0, 1, 2, 255]))
    }

    // MARK: SyncBackoff (§3.5)

    func testBackoffDelays() {
        XCTAssertEqual((0...7).map { SyncBackoff.delay(afterFailures: $0) }, [15, 30, 60, 120, 240, 300, 300, 300])
        XCTAssertEqual(SyncBackoff.delay(afterFailures: -3), 15, "negative counts as 0")
        XCTAssertEqual(SyncBackoff.delay(afterFailures: 30), 300)
        XCTAssertEqual(SyncBackoff.delay(afterFailures: 1_000_000), 300, "no overflow")
    }

    func testBackoffRecordFailureAndReset() {
        var b = SyncBackoff()
        XCTAssertEqual(b.failures, 0)
        XCTAssertEqual(b.nextDelay, 15)
        b.recordFailure()
        XCTAssertEqual(b.failures, 1)
        XCTAssertEqual(b.nextDelay, 30)
        b.recordFailure()
        b.recordFailure()
        XCTAssertEqual(b.nextDelay, 120)
        XCTAssertEqual(b.nextDelay(serverHint: 600), 600, "a longer server hint wins")
        XCTAssertEqual(b.nextDelay(serverHint: 1), 120, "a shorter server hint loses")
        XCTAssertEqual(b.nextDelay(serverHint: nil), 120)
        XCTAssertEqual(SyncBackoff().nextDelay(serverHint: 600), 600)
        XCTAssertEqual(SyncBackoff().nextDelay(serverHint: 1), 15)
        XCTAssertEqual(SyncBackoff().nextDelay(serverHint: .nan), 15, "a NaN hint is ignored")
        for _ in 0..<100 { b.recordFailure() }
        XCTAssertEqual(b.failures, 30, "capped at 30")
        XCTAssertEqual(b.nextDelay, 300)
        b.reset()
        XCTAssertEqual(b.failures, 0)
        XCTAssertEqual(b.nextDelay, 15)
        XCTAssertEqual(SyncBackoff(failures: 2).nextDelay, 60)
        XCTAssertEqual(SyncBackoff(failures: 99).failures, 30)
        XCTAssertEqual(SyncBackoff(failures: -1).failures, 0)
        XCTAssertEqual(SyncBackoff(failures: 2), SyncBackoff(failures: 2))
    }

    func testBackoffConstants() {
        XCTAssertEqual(SyncBackoff.debounce, 1.5)
        XCTAssertEqual(SyncBackoff.minimum, 15)
        XCTAssertEqual(SyncBackoff.maximum, 300)
        XCTAssertEqual(SyncBackoff.maxConflictRetries, 3)
        XCTAssertEqual(SyncBackoff.pageFetchCooldown, 30)
        XCTAssertEqual(SyncBackoff.notificationBudget, 20)
    }

    // MARK: InkPage additions (§3.6)

    func testLiveStrokeIdsAndContentDiffers() {
        var a = InkPage(pageId: "m1-2026-10")
        a.add(stroke("z"))
        a.add(stroke("b"))
        a.add(stroke("m"))
        XCTAssertEqual(a.liveStrokeIds, ["b", "m", "z"], "sorted")
        var b = a
        b.updatedAt += 5
        b.unknown["x"] = .bool(true)
        XCTAssertNotEqual(a, b)
        XCTAssertFalse(a.contentDiffers(from: b), "updatedAt and unknown do not count")
        XCTAssertFalse(a.contentDiffers(from: a))
        b.remove(ids: ["m"], at: 1_760_000_002_000)
        XCTAssertEqual(b.liveStrokeIds, ["b", "z"])
        XCTAssertTrue(a.contentDiffers(from: b), "a removed stroke")
        XCTAssertTrue(b.contentDiffers(from: a), "symmetric")
        var c = a
        c.deleted["ghost"] = 1
        XCTAssertTrue(a.contentDiffers(from: c), "a tombstone for an id that is not on the page still counts")
        var d = a
        d.add(stroke("new"))
        XCTAssertTrue(a.contentDiffers(from: d), "an added stroke")
        var e = a
        e.strokes["z"] = stroke("z", t: 1)
        XCTAssertFalse(a.contentDiffers(from: e), "the strokes' contents are not compared")
        XCTAssertFalse(InkPage(pageId: "x").contentDiffers(from: InkPage(pageId: "y")), "the pageId is not compared")
        let unknownStroke = InkPage(json: .object(["pageId": .string("m1-2026-10"), "strokes": .object(["u": .object(["id": .string("u"), "tool": .string("brush"), "pts": .array([])])])]))
        XCTAssertEqual(unknownStroke.liveStrokeIds, [], "a stroke of an unknown tool is not a live stroke of this version")
        XCTAssertTrue(unknownStroke.contentDiffers(from: InkPage(pageId: "m1-2026-10")), "but it is content that differs (it is written back)")
    }
}
