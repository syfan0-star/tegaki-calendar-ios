import XCTest
import Foundation
import CoreGraphics
import InkModel

/// InkPage / InkStroke / codec (M2_CONTRACT §2, DESIGN §3.9). Merge cases follow the web version's
/// tests/ink-model.test.mjs.
final class InkModelTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    private func point(_ x: Double, _ y: Double, dt: Int = 0, size: Double = 3.5, force: Double = 0.5) -> InkPoint {
        InkPoint(x: CGFloat(x), y: CGFloat(y), dtMs: dt, sizeW: CGFloat(size), sizeH: CGFloat(size), opacity: 1, force: CGFloat(force), azimuth: 1.5708, altitude: 0.7854)
    }

    private func stroke(_ id: String, cell: CellKey? = nil, tool: InkTool = .pen, color: String = "#1f2937", t: Int = 1_760_150_400_123, dev: String? = "ipad-1", points: [InkPoint]? = nil) -> InkStroke {
        InkStroke(id: id, cell: cell ?? .day(day(2026, 10, 4)), tool: tool, color: color, t: t, dev: dev, points: points ?? [point(10, 20), point(30.06, 40.04, dt: 16), point(50, 90, dt: 32)])
    }

    /// Deterministic xorshift64* generator.
    private struct Rng {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2_685_821_657_736_338_717
        }
        mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
        mutating func double() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    }

    // MARK: InkPoint / InkStroke

    func testPointRounding() {
        let p = InkPoint(x: 10.04, y: 20.06, dtMs: 5, sizeW: 3.456, sizeH: 3.454, opacity: 0.999, force: 0.123, azimuth: 1.23456, altitude: 0.98765)
        XCTAssertEqual(p.x, 10.0)
        XCTAssertEqual(p.y, 20.1)
        XCTAssertEqual(p.dtMs, 5)
        XCTAssertEqual(p.sizeW, 3.46)
        XCTAssertEqual(p.sizeH, 3.45)
        XCTAssertEqual(p.opacity, 1.0)
        XCTAssertEqual(p.force, 0.12)
        XCTAssertEqual(p.azimuth, 1.235)
        XCTAssertEqual(p.altitude, 0.988)
        XCTAssertEqual(InkPoint.points(fromFlat: InkPoint.flat([p])), [p])
        XCTAssertEqual(InkPoint.flat([p]), [10, 20.1, 5, 3.46, 3.45, 1, 0.12, 1.235, 0.988])
        XCTAssertTrue(InkPoint.points(fromFlat: [1, 2, 3]).isEmpty, "a partial point is ignored")
        XCTAssertEqual(InkPoint.points(fromFlat: [Double.nan, 2, 0, 1, 1, 1, 1, 0, 0, 5, 6, 0, 1, 1, 1, 1, 0, 0]).count, 1, "a bad point is dropped")
        XCTAssertEqual(InkPoint.points(fromFlat: [1e9, 2, 0, 1, 1, 1, 1, 0, 0]).count, 0, "absurd coordinates are dropped")
        let negativeZero = InkPoint(x: -0.04, y: -0.0, dtMs: 0, sizeW: 0, sizeH: 0, opacity: 0, force: 0, azimuth: 0, altitude: 0)
        XCTAssertEqual(negativeZero.x.sign, .plus, "no negative zero")
        XCTAssertEqual(JSONValue.number(Double(negativeZero.x)).serialized(), "0")
        let bad = InkPoint(x: .nan, y: .infinity, dtMs: 0, sizeW: .nan, sizeH: 1, opacity: 1, force: 1, azimuth: 0, altitude: 0)
        XCTAssertEqual(bad.x, 0)
        XCTAssertEqual(bad.y, 0)
        XCTAssertEqual(bad.sizeW, 0)
    }

    func testStrokeNormalization() {
        XCTAssertEqual(InkStroke.normalizeColor("#ABC"), "#aabbcc")
        XCTAssertEqual(InkStroke.normalizeColor("#1F2937"), "#1f2937")
        XCTAssertNil(InkStroke.normalizeColor("red"))
        XCTAssertNil(InkStroke.normalizeColor("#12345"))
        XCTAssertNil(InkStroke.normalizeColor("#gggggg"))
        XCTAssertEqual(stroke("x", color: "garbage").color, "#1f2937")
        XCTAssertEqual(stroke("x", tool: .marker, color: "").color, "#fde047")
        XCTAssertEqual(stroke("x", t: -5).t, 0)
        XCTAssertEqual(stroke("x", t: 1_760_150_400_123).inkStart, Date(timeIntervalSince1970: 1_760_150_400.123))
        XCTAssertTrue(InkStroke.isValidId("a"))
        XCTAssertFalse(InkStroke.isValidId(""))
        XCTAssertFalse(InkStroke.isValidId(String(repeating: "x", count: 129)))
        XCTAssertEqual(InkStroke.newId().count, 36)
        XCTAssertEqual(InkStroke.newId(), InkStroke.newId().lowercased() == InkStroke.newId() ? "" : InkStroke.newId(), "ids are random")
        XCTAssertEqual(stroke("x", points: [point(0, 90, size: 3.5), point(5, 100, size: 18)]).bottom, 109)
        XCTAssertEqual(stroke("x", points: []).bottom, 0)
    }

    func testStrokeCodableUsesTheDesignShape() throws {
        let s = stroke("a", dev: nil)
        let data = try JSONEncoder().encode(s)
        let json = try JSONValue.parse(data)
        XCTAssertEqual(json["id"], .string("a"))
        XCTAssertEqual(json["cell"], .string("2026-10-04"))
        XCTAssertEqual(json["tool"], .string("pen"))
        XCTAssertEqual(json["color"], .string("#1f2937"))
        XCTAssertEqual(json["t"], .number(1_760_150_400_123))
        XCTAssertNil(json["dev"])
        XCTAssertEqual(json["pts"]?.arrayValue?.count, 27)
        XCTAssertEqual(try JSONDecoder().decode(InkStroke.self, from: data), s)
        XCTAssertThrowsError(try JSONDecoder().decode(InkStroke.self, from: Data("{\"id\":\"a\",\"tool\":\"pen\"}".utf8)))
    }

    // MARK: InkPage editing

    func testAddRemoveLiveStrokesAndInkBottoms() {
        var page = InkPage.empty(pageId: "m1-2026-10")
        XCTAssertEqual(page.v, 1)
        XCTAssertEqual(page.pageId, "m1-2026-10")
        page.add(stroke("pen-late", t: 300))
        page.add(stroke("marker", tool: .marker, t: 500, points: [point(0, 100, size: 18), point(5, 120, size: 18)]))
        page.add(stroke("pen-early", t: 100))
        page.add(stroke("memo", cell: .memo, t: 200, points: [point(0, 50), point(10, 60.5)]))
        XCTAssertEqual(page.liveStrokes.map(\.id), ["marker", "pen-early", "memo", "pen-late"])
        XCTAssertEqual(page.liveStrokeCount, 4)
        XCTAssertEqual(page.updatedAt, 500)
        XCTAssertEqual(page.inkBottoms()[.day(day(2026, 10, 4))], 129)
        XCTAssertEqual(page.inkBottoms()[.memo], 62.25)
        XCTAssertNil(page.inkBottoms()[.day(day(2026, 10, 5))])

        page.remove(ids: ["pen-late", "ghost"], at: 900)
        XCTAssertEqual(page.liveStrokes.map(\.id), ["marker", "pen-early", "memo"])
        XCTAssertEqual(page.deleted, ["pen-late": 900, "ghost": 900])
        XCTAssertEqual(page.updatedAt, 900)
        XCTAssertFalse(page.isLive("pen-late"))
        XCTAssertTrue(page.isLive("marker"))
        page.add(stroke("pen-late", t: 1000))
        XCTAssertNil(page.strokes["pen-late"], "a tombstoned id never comes back")
        page.remove(ids: ["ghost"], at: 100)
        XCTAssertEqual(page.deleted["ghost"], 900, "an earlier removal time does not lower the tombstone")
        page.remove(ids: ["ghost"], at: 950)
        XCTAssertEqual(page.deleted["ghost"], 950)
        page.add(stroke("empty", points: []))
        XCTAssertNil(page.strokes["empty"])
        page.add(stroke(""))
        XCTAssertNil(page.strokes[""])
        page.remove(ids: [""], at: 5)
        XCTAssertNil(page.deleted[""])
        XCTAssertEqual(page.inkBottoms()[.day(day(2026, 10, 4))], 129, "removal of pen-late (bottom 91.75) does not change the max")
        page.remove(ids: ["marker"], at: 1000)
        XCTAssertEqual(page.inkBottoms()[.day(day(2026, 10, 4))], 91.75)
    }

    func testAddWithSameIdPicksDeterministically() {
        let a = stroke("s", t: 10)
        var b = a
        b.t = 11
        var p1 = InkPage.empty(pageId: "p")
        p1.add(a)
        p1.add(b)
        var p2 = InkPage.empty(pageId: "p")
        p2.add(b)
        p2.add(a)
        XCTAssertEqual(p1.strokes["s"], p2.strokes["s"])
        XCTAssertEqual(p1.strokes["s"]?.t, 11, "the greater content wins")
        XCTAssertEqual(InkPage.compareStrokes(a, b), -1)
        XCTAssertEqual(InkPage.compareStrokes(b, a), 1)
        XCTAssertEqual(InkPage.compareStrokes(a, a), 0)
    }

    // MARK: JSON codec

    func testJSONRoundTripAndShape() throws {
        var original = InkPage.empty(pageId: "m1-2026-10")
        original.add(stroke("a"))
        original.add(stroke("b", tool: .marker, color: "#FDE047", t: 7, dev: nil))
        original.remove(ids: ["c"], at: 1_760_150_500_000)
        let data = try InkPageCodec.encode(original)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("{\"deleted\":{\"c\":1760150500000},\"pageId\":\"m1-2026-10\",\"strokes\":{\"a\":{\"cell\":\"2026-10-04\",\"color\":\"#1f2937\",\"dev\":\"ipad-1\",\"id\":\"a\",\"pts\":[10,20,0,3.5,3.5,1,0.5,1.571,0.785,"), text)
        XCTAssertTrue(text.hasSuffix(",\"updatedAt\":1760150500000,\"v\":1}"), text)
        XCTAssertFalse(text.contains("\"dev\":null"))
        let decoded = try InkPageCodec.decode(data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(try InkPageCodec.encode(decoded), data, "re-encoding is byte-identical")
        // Codable goes through the same shape.
        XCTAssertEqual(try JSONDecoder().decode(InkPage.self, from: data), original)
        XCTAssertEqual(try InkPageCodec.decode(try JSONEncoder().encode(original)), original)
    }

    func testTolerantDecodeKeepsUnknownItems() throws {
        let foreign = """
        {"v":7,"pageId":"m1-2026-10","future":{"a":[1,2.5,"x",null,true]},"strokes":{
          "k":{"id":"k","cell":"2026-10-05","tool":"pen","color":"#ABC","t":10,"pts":[1,2,0,3,3,1,0.5,0,0]},
          "u":{"id":"u","cell":"memo","tool":"crayon","color":"#000000","t":11,"pts":[1,2,0,3,3,1,0.5,0,0],"wax":true},
          "broken":{"id":"broken","tool":"pen","pts":[]},
          "nocell":{"id":"nocell","tool":"pen","pts":[1,2,0,3,3,1,0.5,0,0]},
          "notool":{"id":"notool","cell":"memo","pts":[1,2,0,3,3,1,0.5,0,0]},
          "keyed":{"cell":"2026-10-06","tool":"marker","pts":[1,2,0,3,3,1,0.5,0,0]},
          "dead":{"id":"dead","cell":"2026-10-06","tool":"pen","pts":[1,2,0,3,3,1,0.5,0,0]},
          "deadunknown":{"id":"deadunknown","cell":"memo","tool":"crayon","pts":[1]},
          "junk":5
        },"deleted":{"dead":123,"deadunknown":124,"":5,"neg":-3},"updatedAt":99}
        """
        let parsed = try InkPageCodec.decode(Data(foreign.utf8))
        XCTAssertEqual(parsed.v, 7)
        XCTAssertEqual(parsed.pageId, "m1-2026-10")
        XCTAssertEqual(Set(parsed.strokes.keys), ["k", "keyed"])
        XCTAssertEqual(parsed.strokes["k"]?.color, "#aabbcc")
        XCTAssertEqual(parsed.strokes["k"]?.t, 10)
        XCTAssertEqual(parsed.strokes["keyed"]?.tool, .marker)
        XCTAssertEqual(parsed.strokes["keyed"]?.id, "keyed")
        XCTAssertEqual(parsed.unknownStrokes.keys.sorted(), ["u"])
        XCTAssertEqual(parsed.unknownStrokes["u"]?["wax"], .bool(true))
        XCTAssertEqual(parsed.unknown["future"], .object(["a": .array([.number(1), .number(2.5), .string("x"), .null, .bool(true)])]))
        XCTAssertEqual(parsed.deleted, ["dead": 123, "deadunknown": 124, "neg": 0])
        XCTAssertEqual(parsed.updatedAt, 99)
        XCTAssertEqual(parsed.liveStrokes.count, 2, "unknown strokes are not drawn")
        XCTAssertNil(parsed.inkBottoms()[.memo], "unknown strokes do not count as ink")

        let rewritten = String(decoding: try InkPageCodec.encode(parsed), as: UTF8.self)
        XCTAssertTrue(rewritten.contains("\"future\":{\"a\":[1,2.5,\"x\",null,true]}"))
        XCTAssertTrue(rewritten.contains("\"tool\":\"crayon\""))
        XCTAssertTrue(rewritten.contains("\"wax\":true"))
        XCTAssertTrue(rewritten.contains("\"v\":7"))
        XCTAssertFalse(rewritten.contains("deadunknown\":{"))
        XCTAssertEqual(try InkPageCodec.decode(Data(rewritten.utf8)), parsed, "second round trip is stable")

        // Strokes given as an array (no keys to fall back on).
        let listed = try InkPageCodec.decode(Data("{\"strokes\":[{\"id\":\"a\",\"cell\":\"memo\",\"tool\":\"pen\",\"pts\":[1,2,0,3,3,1,0.5,0,0]},{\"cell\":\"memo\",\"tool\":\"pen\",\"pts\":[1,2,0,3,3,1,0.5,0,0]}]}".utf8))
        XCTAssertEqual(listed.strokes.keys.sorted(), ["a"])
        XCTAssertEqual(listed.pageId, "")
        XCTAssertEqual(try InkPageCodec.decode(Data("{}".utf8)), InkPage.empty(pageId: ""))
        XCTAssertEqual(try InkPageCodec.decode(Data("{\"strokes\":5,\"deleted\":[1],\"v\":\"x\",\"updatedAt\":\"y\"}".utf8)), InkPage.empty(pageId: ""))
    }

    func testDecodeErrors() {
        XCTAssertThrowsError(try InkPageCodec.decode(Data("not json".utf8)))
        XCTAssertThrowsError(try InkPageCodec.decode(Data("[1,2]".utf8))) { error in
            XCTAssertEqual(error as? InkCodecError, .notAnObject)
        }
        XCTAssertThrowsError(try InkPageCodec.decode(Data()))
        XCTAssertThrowsError(try InkPageCodec.decode(Data("{\"v\":1".utf8)))
    }

    func testJSONValueSerialization() throws {
        let value: JSONValue = .object(["b": .array([.number(1), .number(2.5), .number(-0.0), .number(1e21), .string("a\"b\\c\n\u{1}"), .null, .bool(false)]), "a": .object([:])])
        let text = value.serialized()
        XCTAssertEqual(text, "{\"a\":{},\"b\":[1,2.5,0,1e+21,\"a\\\"b\\\\c\\n\\u0001\",null,false]}")
        XCTAssertEqual(try JSONValue.parse(Data(text.utf8)), value)
        XCTAssertEqual(JSONValue.format(0.1), "0.1")
        XCTAssertEqual(JSONValue.format(1760150400123), "1760150400123")
        XCTAssertEqual(JSONValue.format(.nan), "null")
        XCTAssertEqual(try JSONValue.parse(Data("[true,1,1.0,\"1\"]".utf8)), .array([.bool(true), .number(1), .number(1), .string("1")]))
        XCTAssertThrowsError(try JSONValue.parse(Data("{".utf8)))
        // Codable path.
        let encoded = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: encoded), value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: Data("[true,1,1.5,\"s\",null,{\"k\":[]}]".utf8)), .array([.bool(true), .number(1), .number(1.5), .string("s"), .null, .object(["k": .array([])])]))
    }

    // MARK: Compression

    func testCompressionRoundTrip() throws {
        var page = InkPage.empty(pageId: "m1-2026-10")
        for i in 0..<50 { page.add(stroke("s\(i)", t: 100 + i)) }
        let data = try InkPageCodec.encode(page)
        let compressed = try InkPageCodec.compress(data)
        XCTAssertFalse(compressed.isEmpty)
        XCTAssertLessThan(compressed.count, data.count, "repetitive JSON shrinks")
        XCTAssertEqual(try InkPageCodec.decompress(compressed), data)
        XCTAssertEqual(try InkPageCodec.decode(try InkPageCodec.decompress(compressed)), page)
        XCTAssertEqual(try InkPageCodec.decompress(try InkPageCodec.compress(Data())), Data())
        var big = Data()
        for i in 0..<300_000 { big.append(UInt8(truncatingIfNeeded: i &* 31)) }
        XCTAssertEqual(try InkPageCodec.decompress(try InkPageCodec.compress(big)), big, "multiple output chunks")
        XCTAssertThrowsError(try InkPageCodec.decompress(Data("definitely not lzfse".utf8)))
        XCTAssertThrowsError(try InkPageCodec.decompress(compressed.prefix(compressed.count / 2)))
    }

    // MARK: Merge

    func testMergeIsUnionMinusTombstones() {
        var a = InkPage.empty(pageId: "p")
        a.add(stroke("1", t: 100))
        a.add(stroke("2", t: 100))
        a.remove(ids: ["3"], at: 150)
        var b = InkPage.empty(pageId: "p")
        b.add(stroke("2", t: 100), at: 300)
        b.add(stroke("3", t: 100), at: 300)
        b.add(stroke("4", t: 100), at: 300)
        b.remove(ids: ["1"], at: 120)
        b.remove(ids: ["3"], at: 140)
        let m = InkPage.merge(a, b)
        XCTAssertEqual(m.strokes.keys.sorted(), ["2", "4"])
        XCTAssertEqual(m.deleted, ["1": 120, "3": 150])
        XCTAssertEqual(m.updatedAt, 300)
        XCTAssertEqual(m.pageId, "p")
        XCTAssertEqual(m, InkPage.merge(b, a))
        // pageId: "" is neutral, otherwise the smaller wins.
        XCTAssertEqual(InkPage.merge(InkPage.empty(pageId: ""), InkPage.empty(pageId: "q")).pageId, "q")
        XCTAssertEqual(InkPage.merge(InkPage.empty(pageId: "z"), InkPage.empty(pageId: "q")).pageId, "q")
        // Unknown items unite; v is the max.
        var x = InkPage.empty(pageId: "p")
        x.unknown["alpha"] = .number(1)
        x.v = 3
        var y = InkPage.empty(pageId: "p")
        y.unknown["beta"] = .string("b")
        y.unknownStrokes["u"] = .object(["id": .string("u"), "tool": .string("crayon")])
        let xy = InkPage.merge(x, y)
        XCTAssertEqual(xy.unknown, ["alpha": .number(1), "beta": .string("b")])
        XCTAssertEqual(xy.unknownStrokes.keys.sorted(), ["u"])
        XCTAssertEqual(xy.v, 3)
        // A tombstone removes an unknown stroke too.
        var z = InkPage.empty(pageId: "p")
        z.remove(ids: ["u"], at: 5)
        XCTAssertTrue(InkPage.merge(xy, z).unknownStrokes.isEmpty)
    }

    func testMergeLawsOnRandomPages() throws {
        let cells: [CellKey] = [.day(day(2026, 10, 4)), .day(day(2026, 10, 5)), .memo]
        let colors = ["#1f2937", "#dc2626", "#2563eb", "#fde047"]
        var rng = Rng(seed: 12_345)

        func randomStroke(_ id: String) -> InkStroke {
            let count = 1 + rng.int(5)
            let points = (0..<count).map { i in point(rng.double() * 200, rng.double() * 175, dt: i * 16, size: 2 + rng.double() * 16, force: rng.double()) }
            return InkStroke(id: id, cell: cells[rng.int(cells.count)], tool: rng.int(2) == 0 ? .pen : .marker, color: colors[rng.int(colors.count)], t: 1 + rng.int(1000), dev: rng.int(2) == 0 ? nil : "dev\(rng.int(3))", points: points)
        }

        func randomPage(pool: [InkStroke]) -> InkPage {
            var page = InkPage.empty(pageId: rng.int(5) == 0 ? "" : "m1-2026-10")
            for _ in 0..<rng.int(8) {
                var s = pool[rng.int(pool.count)]
                if rng.int(6) == 0 { s.t += 1 + rng.int(3) }
                page.add(s)
            }
            for _ in 0..<rng.int(4) {
                page.remove(ids: ["s\(rng.int(12))"], at: 1 + rng.int(2000))
            }
            if rng.int(3) == 0 { page.unknown["x\(rng.int(3))"] = .number(Double(rng.int(10))) }
            if rng.int(3) == 0 {
                let id = "u\(rng.int(3))"
                page.unknownStrokes[id] = .object(["id": .string(id), "cell": .string("memo"), "tool": .string("crayon"), "pts": .array([.number(Double(rng.int(9)))])])
            }
            if rng.int(5) == 0 { page.v = 1 + rng.int(3) }
            return page
        }

        for iteration in 0..<300 {
            let pool = (0..<12).map { randomStroke("s\($0)") }
            let a = randomPage(pool: pool)
            let b = randomPage(pool: pool)
            let c = randomPage(pool: pool)
            let ab = InkPage.merge(a, b)
            XCTAssertEqual(ab, InkPage.merge(b, a), "commutative #\(iteration)")
            XCTAssertEqual(InkPage.merge(ab, c), InkPage.merge(a, InkPage.merge(b, c)), "associative #\(iteration)")
            XCTAssertEqual(InkPage.merge(a, a), a, "idempotent #\(iteration)")
            XCTAssertEqual(InkPage.merge(ab, ab), ab, "idempotent (merged) #\(iteration)")
            XCTAssertEqual(InkPage.merge(ab, a), ab, "absorbs an already merged input #\(iteration)")
            XCTAssertEqual(InkPage.merge(a, InkPage.empty(pageId: "")), a, "empty page is neutral #\(iteration)")
            for id in ab.deleted.keys {
                XCTAssertNil(ab.strokes[id], "tombstoned stroke live #\(iteration)")
                XCTAssertNil(ab.unknownStrokes[id], "tombstoned unknown stroke live #\(iteration)")
            }
            XCTAssertEqual(try InkPageCodec.decode(try InkPageCodec.encode(ab)), ab, "round trip #\(iteration)")
        }
    }

    func testReplicasConvergeUnderRandomSyncOrder() {
        var rng = Rng(seed: 777)
        for round in 0..<40 {
            var replicas = [InkPage.empty(pageId: "m1-2026-10"), InkPage.empty(pageId: "m1-2026-10"), InkPage.empty(pageId: "m1-2026-10")]
            var clock = 1000
            var ever: [String] = []
            for step in 0..<60 {
                let i = rng.int(3)
                clock += 1 + rng.int(5)
                if rng.int(3) != 0 || ever.isEmpty {
                    let id = "r\(round)-\(step)"
                    replicas[i].add(stroke(id, t: clock))
                    ever.append(id)
                } else {
                    replicas[i].remove(ids: [ever[rng.int(ever.count)]], at: clock)
                }
                if rng.int(4) == 0 {
                    let j = rng.int(3)
                    replicas[i] = InkPage.merge(replicas[i], replicas[j])
                }
            }
            var all = replicas.reduce(InkPage.empty(pageId: "")) { InkPage.merge($0, $1) }
            for k in replicas.indices { replicas[k] = InkPage.merge(replicas[k], all) }
            XCTAssertEqual(replicas[0], replicas[1], "round \(round)")
            XCTAssertEqual(replicas[1], replicas[2], "round \(round)")
            all = InkPage.merge(all, replicas[1])
            XCTAssertEqual(all, replicas[0], "round \(round)")
        }
    }

    func testFingerprintEquality() {
        let d = Date(timeIntervalSince1970: 1_760_150_400.123456)
        let a = StrokeFingerprint(creationDate: d, pointCount: 12, inkType: "pen", firstX: 10.5, firstY: 20)
        let b = StrokeFingerprint(creationDate: d, pointCount: 12, inkType: "pen", firstX: 10.5, firstY: 20)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertNotEqual(a, StrokeFingerprint(creationDate: d, pointCount: 13, inkType: "pen", firstX: 10.5, firstY: 20))
        var map: [StrokeFingerprint: String] = [a: "id-a"]
        map[b] = "id-b"
        XCTAssertEqual(map.count, 1)
    }
}
