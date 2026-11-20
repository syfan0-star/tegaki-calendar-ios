import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4 D0b probe (docs/M7D_CONTRACT.md; the quick branch r14-q-probe): `PaperSpanTests.testWithoutNeighborInkThePDFIsTheDefaultCallsPDF`
/// failed at PaperSpanTests.swift:763 in the quick run 44649291195 (D1's code, iOS 27.2 24B8117) with "698524 bytes" against
/// "698524 bytes": `PDFPageRenderer.render(paper, page:, title: "t")` and the same call with `neighborInk: []` had the same
/// length but different bytes after `stableBytes` (which removes only /CreationDate, /ModDate and /ID). It passed in D0
/// attempt 1 on the same runtime with 1.3's code.
///
/// This probe builds the same page and paper as that test (its helpers copied from PaperSpanTests.swift:60-66, :80-90,
/// :197-224), renders both calls 4 times each, alternately (plain0, explicit0, plain1, …), and logs as `probe-pdf:` lines:
/// each render's time, size and hash (raw and after `stableBytes`) and its fonts (every /BaseFont and /FontName, with
/// the subset tags); for every pair plain_i / explicit_i the differing bytes after `stableBytes`, the first 8 runs of
/// them with their offset, ±80 bytes of context in each PDF (non-printables escaped) and where they lie (the nearest
/// "stream" / "endstream" before them, the object "N 0 obj" and its dictionary); the objects that differ, and for up to 6
/// of them the stream's raw and inflated differences (the first with ±80 bytes, and for an image the differing pixels'
/// box); plain_i against plain0 and explicit_i against explicit0; and the pages drawn as pictures, pixel against pixel.
/// The first two PDFs are attached (`keepAlways`; the quick lane keeps no xcresult, the log carries the analysis).
///
/// It is a probe: it asserts nothing and cannot fail. The class name ends in `SpanTests` (the quick lane's filter) and
/// sorts after `PaperSpanTests`, so the real test runs first, as in D0.
@MainActor
final class ProbePDFSpanTests: XCTestCase {
    /// PaperSpanTests' day: 2026-11-11, a Wednesday, 10:00.
    private let today = DayKey(year: 2026, month: 11, day: 11)
    private var now: Date { today.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600) }

    /// Records what `TransferGuard` refuses (its default stops a Debug build): PaperSpanTests.swift:29-49, copied.
    private final class Recorder {
        var lines: [String] = []
    }

    private var recorder = Recorder()
    private var savedHook: ((String) -> Void)?
    private var lines: [String] = []

    override func setUp() async throws {
        let recorder = Recorder()
        self.recorder = recorder
        savedHook = TransferGuard.onRefused
        TransferGuard.onRefused = { recorder.lines.append($0) }
    }

    override func tearDown() async throws {
        if let hook = savedHook {
            TransferGuard.onRefused = hook
        }
        let all = XCTAttachment(string: lines.joined(separator: "\n"))
        all.name = "probe-pdf.txt"
        all.lifetime = .keepAlways
        add(all)
    }

    // MARK: - Logging

    private static let clockFormat: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(identifier: "UTC")
        format.dateFormat = "HH:mm:ss.SSS"
        return format
    }()

    private static func clock() -> String { clockFormat.string(from: Date()) }

    /// One `probe-pdf:` line (cut into pieces of 900 characters: NSLog may shorten a longer one).
    private func log(_ text: String) {
        lines.append(text)
        let limit = 900
        guard text.count > limit else {
            NSLog("probe-pdf: %@", text)
            return
        }
        let pieces = stride(from: 0, to: text.count, by: limit).map { start -> String in
            let from = text.index(text.startIndex, offsetBy: start)
            let to = text.index(from, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
            return String(text[from..<to])
        }
        for (index, piece) in pieces.enumerated() {
            NSLog("probe-pdf: [%d/%d] %@", index + 1, pieces.count, piece)
        }
    }

    private static func ms(_ seconds: TimeInterval) -> String { String(format: "%.1f", seconds * 1000) }

    private static func r(_ rect: CGRect) -> String {
        String(format: "(%.1f, %.1f, %.1fx%.1f)", Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))
    }

    /// `XCTAttachment(data:uniformTypeIdentifier:)` through its Objective-C class method, so that the local type check's
    /// XCTest stand-in (tools/typecheck/XCTestStandIn.swift: only `init(string:)` and `init(screenshot:)`) needs no change.
    private static func attachment(_ data: Data, uniformTypeIdentifier: String) -> XCTAttachment? {
        let selector = NSSelectorFromString("attachmentWithData:uniformTypeIdentifier:")
        guard let type = (XCTAttachment.self as AnyObject) as? NSObjectProtocol, type.responds(to: selector) else { return nil }
        return type.perform(selector, with: data as NSData, with: uniformTypeIdentifier as NSString)?.takeUnretainedValue() as? XCTAttachment
    }

    // MARK: - The page (PaperSpanTests' helpers, copied from PaperSpanTests.swift:60-66 and :80-90: theirs are private)

    private func dayLayout(_ day: DayKey, extraBottom: CGFloat? = nil, floor: CGFloat = 0) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: extraBottom.map { [.extra: $0] } ?? [:], now: now, extraFloor: floor))
    }

    private func day(_ day: DayKey, extraBottom: CGFloat? = nil, floor: CGFloat = 0) -> PaperContent {
        .day(DayPaperContent(layout: dayLayout(day, extraBottom: extraBottom, floor: floor)))
    }

    private func line(_ from: CGPoint, _ to: CGPoint, count: Int = 12, nib: CGFloat = 3.5) -> [InkPoint] {
        (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(max(count - 1, 1))
            return InkPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t, dtMs: i * 10,
                            sizeW: nib, sizeH: nib, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
    }

    private func stroke(_ id: String, cell: CellKey, _ points: [InkPoint], t: Int = 1_791_000_000_001) -> InkStroke {
        InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, points: points)
    }

    /// The PDF bytes without what CoreGraphics derives from the clock (copied from PaperSpanTests.swift:216-224).
    private static func stableBytes(_ data: Data) -> Data {
        guard var text = String(data: data, encoding: .isoLatin1) else { return data }
        for pattern in ["/CreationDate \\(D:[^)]*\\)", "/ModDate \\(D:[^)]*\\)", "/ID \\[[^\\]]*\\]"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.data(using: .isoLatin1) ?? data
    }

    /// The first page of a PDF at 1 px per point, row 0 at the top, as RGBA bytes (copied from PaperSpanTests.swift:197-215).
    private static func picture(pdf data: Data) -> (bytes: [UInt8], width: Int, height: Int)? {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider), let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        let width = Int(box.width.rounded(.up))
        let height = Int(box.height.rounded(.up))
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.translateBy(x: -box.minX, y: -box.minY)
            ctx.drawPDFPage(page)
        }
        return (bytes, width, height)
    }

    /// Pixels whose RGB differ, their box and the largest channel difference.
    private static func pixelDifferences(_ a: (bytes: [UInt8], width: Int, height: Int), _ b: (bytes: [UInt8], width: Int, height: Int)) -> String {
        guard a.width == b.width, a.height == b.height, a.bytes.count == b.bytes.count else {
            return "sizes differ: \(a.width)x\(a.height) / \(b.width)x\(b.height)"
        }
        var count = 0, maxDelta = 0
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
        a.bytes.withUnsafeBufferPointer { pa in
            b.bytes.withUnsafeBufferPointer { pb in
                for pixel in 0..<(a.width * a.height) {
                    var delta = 0
                    for c in 0..<3 {
                        delta = max(delta, abs(Int(pa[pixel * 4 + c]) - Int(pb[pixel * 4 + c])))
                    }
                    guard delta > 0 else { continue }
                    count += 1
                    maxDelta = max(maxDelta, delta)
                    let x = pixel % a.width, y = pixel / a.width
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        return "\(a.width)x\(a.height): \(count) differing pixels, box \(count > 0 ? "x\(minX)...\(maxX) y\(minY)...\(maxY)" : "-"), max channel delta \(maxDelta)"
    }

    // MARK: - Comparing two renders

    private struct Render {
        var label: String
        var raw: Data
        var stable: [UInt8]
        var objects: [ProbePDFBytes.Object]
    }

    /// The (A, B) object byte pairs already compared in detail (by hash), and how many details are left.
    private var detailed: Set<String> = []
    private var detailsLeft = 6

    /// Byte runs after `stableBytes` (`contexts` of them with ±80 bytes of each PDF and their place), the objects that
    /// differ, and (with `details`) up to 6 objects' stream differences. Returns whether the stable bytes differ.
    @discardableResult
    private func compare(_ label: String, _ a: Render, _ b: Render, contexts: Int, details: Bool) -> Bool {
        let diff = ProbePDFBytes.regions(a.stable, b.stable)
        let lengths = a.stable.count == b.stable.count ? "" : " (lengths differ: offsets after the first difference may be shifted)"
        guard diff.count > 0 || a.stable.count != b.stable.count else {
            log("\(label): identical after stableBytes (\(a.stable.count) bytes)")
            return false
        }
        log("\(label): \(a.label) \(a.stable.count) / \(b.label) \(b.stable.count) bytes after stableBytes; \(diff.count) differing bytes in \(diff.regions.count) runs\(lengths)")
        for (index, run) in diff.regions.prefix(contexts).enumerated() {
            let from = max(0, run.lowerBound - 80)
            log("\(label): run \(index + 1) @\(run.lowerBound)..<\(run.upperBound) (\(run.count) bytes): \(ProbePDFBytes.place(run.lowerBound, in: a.stable, objects: a.objects))")
            log("\(label): run \(index + 1) \(a.label) @\(from) [\(ProbePDFBytes.escape(a.stable[from..<min(a.stable.count, run.lowerBound + 80)]))]")
            log("\(label): run \(index + 1) \(b.label) @\(from) [\(ProbePDFBytes.escape(b.stable[from..<min(b.stable.count, run.lowerBound + 80)]))]")
        }
        var differing: [(ProbePDFBytes.Object, ProbePDFBytes.Object)] = []
        var listed: [String] = []
        for object in a.objects {
            guard let other = b.objects.first(where: { $0.number == object.number }) else {
                listed.append("\(object.number)(\(ProbePDFBytes.kind(object.dictionary)), only in \(a.label))")
                continue
            }
            if Array(a.stable[object.start..<object.end]) != Array(b.stable[other.start..<other.end]) {
                differing.append((object, other))
                listed.append("\(object.number)(\(ProbePDFBytes.kind(object.dictionary)) \(object.end - object.start)/\(other.end - other.start) bytes)")
            }
        }
        for object in b.objects where !a.objects.contains(where: { $0.number == object.number }) {
            listed.append("\(object.number)(\(ProbePDFBytes.kind(object.dictionary)), only in \(b.label))")
        }
        log("\(label): differing objects \(differing.count) of \(a.objects.count)/\(b.objects.count): \(listed.joined(separator: " "))")
        guard details else { return true }
        for (objectA, objectB) in differing {
            let key = ProbePDFBytes.fnv(Array(a.stable[objectA.start..<objectA.end])) + ProbePDFBytes.fnv(Array(b.stable[objectB.start..<objectB.end]))
            if detailed.contains(key) {
                log("\(label): obj \(objectA.number): the same two versions as compared above")
                continue
            }
            guard detailsLeft > 0 else {
                log("\(label): obj \(objectA.number): no detail left (6 compared)")
                continue
            }
            detailsLeft -= 1
            detailed.insert(key)
            let start = Date()
            for line in ProbePDFBytes.compare(a.stable, objectA, b.stable, objectB) {
                log("\(label): \(line)")
            }
            log("\(label): obj \(objectA.number): compared in \(Self.ms(Date().timeIntervalSince(start))) ms")
        }
        return true
    }

    // MARK: - The probe

    func testProbeThePDFWithAndWithoutNeighborInk() {
        log("env \(Self.clock()) iOS \(UIDevice.current.systemVersion) \(UIDevice.current.model) language \(L.language)")
        // PaperSpanTests.swift:753-763: the same page and paper.
        var page = InkPage.empty(pageId: "d-2026-11-11")
        page.add(stroke("own-extra", cell: .extra, line(CGPoint(x: 40, y: 400), CGPoint(x: 400, y: 480))))
        page.add(stroke("own-grid", cell: .grid, line(CGPoint(x: 100, y: 1000), CGPoint(x: 500, y: 1100))))
        let paper = day(today, extraBottom: page.inkBottoms()[.extra])
        log("paperRect default \(Self.r(PDFPageRenderer.paperRect(paper, page: page))) neighborInk:[] \(Self.r(PDFPageRenderer.paperRect(paper, page: page, neighborInk: []))); pageSize default \(PDFPageRenderer.pageSize(paper, page: page)) neighborInk:[] \(PDFPageRenderer.pageSize(paper, page: page, neighborInk: []))")

        // 4 × each call, alternately.
        var renders: [Render] = []
        for index in 0..<4 {
            for explicit in [false, true] {
                let label = "\(explicit ? "explicit" : "plain")\(index)"
                let startClock = Self.clock()
                let t0 = Date()
                let data = explicit ? PDFPageRenderer.render(paper, page: page, title: "t", neighborInk: []) : PDFPageRenderer.render(paper, page: page, title: "t")
                let t1 = Date()
                let stable = [UInt8](Self.stableBytes(data))
                let objects = ProbePDFBytes.objects(stable)
                let raw = [UInt8](data)
                log("render \(label): start \(startClock) \(Self.ms(t1.timeIntervalSince(t0))) ms; raw \(data.count) bytes fnv \(ProbePDFBytes.fnv(raw)); stable \(stable.count) bytes fnv \(ProbePDFBytes.fnv(stable)); \(objects.count) objects; header [\(ProbePDFBytes.escape(raw.prefix(9)))]")
                log("render \(label): fonts \(ProbePDFBytes.fontNames(objects).joined(separator: "; "))")
                if let info = objects.first(where: { $0.dictionary.contains("/Producer") }) {
                    log("render \(label): info obj \(info.number): \(ProbePDFBytes.escape(info.dictionary, limit: 400))")
                }
                renders.append(Render(label: label, raw: data, stable: stable, objects: objects))
                if index == 0 {
                    if let attachment = Self.attachment(data, uniformTypeIdentifier: "com.adobe.pdf") {
                        attachment.name = "probe-pdf-\(label).pdf"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    } else {
                        log("render \(label): XCTAttachment(data:uniformTypeIdentifier:) unavailable; PDF not attached")
                    }
                }
            }
        }
        log("refused by TransferGuard: \(recorder.lines.count)")

        // The raw bytes of the first pair (what stableBytes takes out).
        let rawDiff = ProbePDFBytes.regions([UInt8](renders[0].raw), [UInt8](renders[1].raw))
        log("raw plain0/explicit0: \(rawDiff.count) differing bytes in \(rawDiff.regions.count) runs (before stableBytes)")

        // Every pair plain_i / explicit_i: the original assertion's comparison.
        var pairsDiffering: [Int] = []
        for index in 0..<4 {
            if compare("pair\(index)", renders[2 * index], renders[2 * index + 1], contexts: 8, details: true) {
                pairsDiffering.append(index)
            }
        }
        // The same call against itself: plain_i / plain0 and explicit_i / explicit0.
        var plainDiffering: [Int] = []
        var explicitDiffering: [Int] = []
        for index in 1..<4 {
            if compare("plain\(index)-vs-plain0", renders[0], renders[2 * index], contexts: 2, details: true) { plainDiffering.append(index) }
            if compare("explicit\(index)-vs-explicit0", renders[1], renders[2 * index + 1], contexts: 2, details: true) { explicitDiffering.append(index) }
        }

        // The pages as pictures.
        if let p0 = Self.picture(pdf: renders[0].raw), let e0 = Self.picture(pdf: renders[1].raw) {
            log("pixels plain0/explicit0: \(Self.pixelDifferences(p0, e0))")
            if let p1 = Self.picture(pdf: renders[2].raw) {
                log("pixels plain0/plain1: \(Self.pixelDifferences(p0, p1))")
            }
        } else {
            log("pixels: CGPDFDocument could not draw the first page")
        }

        let variants = Dictionary(grouping: renders, by: { ProbePDFBytes.fnv($0.stable) })
            .map { "\($0.key)=\($0.value.map(\.label).joined(separator: ","))" }.sorted()
        log("summary: pairs differing \(pairsDiffering) of 0...3; plain_i vs plain0 differing \(plainDiffering); explicit_i vs explicit0 differing \(explicitDiffering); \(variants.count) distinct stable variants: \(variants.joined(separator: " "))")
        log("done at \(Self.clock())")
    }
}

/// The probe's reading of a PDF's bytes (Foundation only, so it also runs in a plain macOS check): the objects
/// (number, dictionary, stream bytes by /Length), where an offset lies, the runs of differing bytes, an inflated
/// /FlateDecode stream and the font names.
private enum ProbePDFBytes {
    struct Object {
        var number: Int
        var generation: Int
        /// The offset of "N G obj".
        var start: Int
        /// Just past "endobj" (the end of the file when there is none).
        var end: Int
        /// From the header to "stream" (or to "endobj"), as Latin-1.
        var dictionary: String
        /// The stream's bytes (by /Length, direct or indirect; else up to "endstream").
        var data: Range<Int>?
    }

    static func ascii(_ text: String) -> [UInt8] { Array(text.utf8) }

    static func latin1<C: Collection>(_ bytes: C) -> String where C.Element == UInt8 {
        String(bytes.map { Character(UnicodeScalar($0)) })
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 || byte == 0x0C || byte == 0x00
    }

    private static func isDigit(_ byte: UInt8) -> Bool { byte >= 0x30 && byte <= 0x39 }

    /// The first offset in from..<to where `pattern` starts.
    static func index(of pattern: [UInt8], in bytes: [UInt8], from: Int, to: Int? = nil) -> Int? {
        let end = min(to ?? bytes.count, bytes.count)
        guard !pattern.isEmpty, from >= 0, from + pattern.count <= end else { return nil }
        return bytes.withUnsafeBufferPointer { b -> Int? in
            var i = from
            let last = end - pattern.count
            while i <= last {
                if b[i] == pattern[0] {
                    var j = 1
                    while j < pattern.count, b[i + j] == pattern[j] { j += 1 }
                    if j == pattern.count { return i }
                }
                i += 1
            }
            return nil
        }
    }

    /// The last offset before `before` where `pattern` starts; `skipAfter` leaves out a match preceded by it
    /// ("stream" that is the end of "endstream").
    static func lastIndex(of pattern: [UInt8], in bytes: [UInt8], before: Int, notPrecededBy skip: [UInt8] = []) -> Int? {
        guard !pattern.isEmpty else { return nil }
        return bytes.withUnsafeBufferPointer { b -> Int? in
            var i = min(before - 1, b.count - pattern.count)
            while i >= 0 {
                if b[i] == pattern[0] {
                    var j = 1
                    while j < pattern.count, b[i + j] == pattern[j] { j += 1 }
                    if j == pattern.count {
                        let preceded = !skip.isEmpty && i >= skip.count && Array(b[(i - skip.count)..<i]) == skip
                        if !preceded { return i }
                    }
                }
                i -= 1
            }
            return nil
        }
    }

    /// The next "N G obj" at or after `from`: its numbers, its offset and the offset after "obj".
    private static func nextHeader(_ bytes: [UInt8], from: Int) -> (number: Int, generation: Int, start: Int, body: Int)? {
        let obj = ascii(" obj")
        var i = from
        while let k = index(of: obj, in: bytes, from: i) {
            i = k + 1
            let after = k + obj.count
            if after < bytes.count, !(isSpace(bytes[after]) || bytes[after] == 0x3C || bytes[after] == 0x5B) { continue }
            var p = k - 1
            while p >= 0, isDigit(bytes[p]) { p -= 1 }
            let generationStart = p + 1
            guard generationStart < k, p >= 0, bytes[p] == 0x20 else { continue }
            p -= 1
            let numberEnd = p + 1
            while p >= 0, isDigit(bytes[p]) { p -= 1 }
            let numberStart = p + 1
            guard numberStart < numberEnd, p < 0 || isSpace(bytes[p]) else { continue }
            let number = Int(latin1(bytes[numberStart..<numberEnd])) ?? -1
            let generation = Int(latin1(bytes[generationStart..<k])) ?? -1
            return (number, generation, numberStart, after)
        }
        return nil
    }

    /// `/Length n` (direct) or `/Length n g R` (the object holding it).
    private static func length(_ dictionary: String) -> (direct: Int?, reference: Int?) {
        guard let regex = try? NSRegularExpression(pattern: "/Length\\s+(\\d+)(\\s+\\d+\\s+R)?") else { return (nil, nil) }
        let range = NSRange(dictionary.startIndex..., in: dictionary)
        guard let match = regex.firstMatch(in: dictionary, range: range),
              let first = Range(match.range(at: 1), in: dictionary), let value = Int(dictionary[first]) else { return (nil, nil) }
        return match.range(at: 2).location == NSNotFound ? (value, nil) : (nil, value)
    }

    /// Every object of the file, in order (a stream's bytes are skipped, never searched for headers).
    static func objects(_ bytes: [UInt8]) -> [Object] {
        let endobj = ascii("endobj"), stream = ascii("stream"), endstream = ascii("endstream")
        var out: [Object] = []
        var references: [Int: Int] = [:]
        var i = 0
        while let header = nextHeader(bytes, from: i) {
            let close = index(of: endobj, in: bytes, from: header.body)
            var object = Object(number: header.number, generation: header.generation, start: header.start, end: bytes.count, dictionary: "", data: nil)
            if let keyword = index(of: stream, in: bytes, from: header.body, to: close ?? bytes.count) {
                object.dictionary = latin1(bytes[header.start..<keyword])
                var dataStart = keyword + stream.count
                if dataStart < bytes.count, bytes[dataStart] == 0x0D { dataStart += 1 }
                if dataStart < bytes.count, bytes[dataStart] == 0x0A { dataStart += 1 }
                let length = length(object.dictionary)
                var stop: Int
                if let direct = length.direct, dataStart + direct <= bytes.count {
                    object.data = dataStart..<(dataStart + direct)
                    stop = index(of: endstream, in: bytes, from: dataStart + direct) ?? bytes.count
                } else {
                    stop = index(of: endstream, in: bytes, from: dataStart) ?? bytes.count
                    var dataEnd = stop
                    if dataEnd > dataStart, bytes[dataEnd - 1] == 0x0A { dataEnd -= 1 }
                    if dataEnd > dataStart, bytes[dataEnd - 1] == 0x0D { dataEnd -= 1 }
                    object.data = dataStart..<dataEnd
                    if let reference = length.reference { references[out.count] = reference }
                }
                stop = index(of: endobj, in: bytes, from: stop) ?? bytes.count
                object.end = min(bytes.count, stop + endobj.count)
            } else {
                let stop = close ?? bytes.count
                object.dictionary = latin1(bytes[header.start..<stop])
                object.end = min(bytes.count, stop + endobj.count)
            }
            out.append(object)
            i = max(object.end, header.body)
        }
        // An indirect /Length: the integer of the object it names.
        for (index, reference) in references {
            guard let holder = out.first(where: { $0.number == reference }), let data = out[index].data else { continue }
            let body = holder.dictionary.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let value = body.compactMap({ Int($0) }).first, data.lowerBound + value <= bytes.count {
                out[index].data = data.lowerBound..<(data.lowerBound + value)
            }
        }
        return out
    }

    /// Runs of differing bytes over the common length (runs closer than `gap` are one).
    static func regions(_ a: [UInt8], _ b: [UInt8], gap: Int = 16) -> (count: Int, regions: [Range<Int>]) {
        let n = min(a.count, b.count)
        var count = 0
        var regions: [Range<Int>] = []
        var current: Range<Int>?
        a.withUnsafeBufferPointer { pa in
            b.withUnsafeBufferPointer { pb in
                for i in 0..<n where pa[i] != pb[i] {
                    count += 1
                    if let run = current, i - run.upperBound <= gap {
                        current = run.lowerBound..<(i + 1)
                    } else {
                        if let run = current { regions.append(run) }
                        current = i..<(i + 1)
                    }
                }
            }
        }
        if let run = current { regions.append(run) }
        return (count, regions)
    }

    /// Printable ASCII as it is; \n \r \t \\ escaped; everything else as \xNN.
    static func escape<C: Collection>(_ bytes: C) -> String where C.Element == UInt8 {
        var out = ""
        for byte in bytes {
            switch byte {
            case 0x0A: out += "\\n"
            case 0x0D: out += "\\r"
            case 0x09: out += "\\t"
            case 0x5C: out += "\\\\"
            case 0x20...0x7E: out.append(Character(UnicodeScalar(byte)))
            default: out += String(format: "\\x%02x", byte)
            }
        }
        return out
    }

    static func escape(_ text: String, limit: Int) -> String {
        let bytes = Array(text.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) })
        let shown = escape(bytes.prefix(limit))
        return bytes.count > limit ? shown + "…(\(bytes.count) bytes)" : shown
    }

    /// Where `offset` lies: the object (and whether in its stream), the nearest "stream" / "endstream" before it.
    static func place(_ offset: Int, in bytes: [UInt8], objects: [Object]) -> String {
        let stream = lastIndex(of: ascii("stream"), in: bytes, before: offset + 1, notPrecededBy: ascii("end"))
        let endstream = lastIndex(of: ascii("endstream"), in: bytes, before: offset + 1)
        let insideByKeywords = stream != nil && (endstream == nil || stream! > endstream!)
        let keywords = "prev stream@\(stream.map(String.init) ?? "-") prev endstream@\(endstream.map(String.init) ?? "-") insideStream(byKeywords)=\(insideByKeywords)"
        guard let object = objects.first(where: { $0.start <= offset && offset < $0.end }) else {
            let trailer = lastIndex(of: ascii("trailer"), in: bytes, before: offset + 1)
            let xref = lastIndex(of: ascii("xref"), in: bytes, before: offset + 1)
            return "outside every object (prev xref@\(xref.map(String.init) ?? "-") trailer@\(trailer.map(String.init) ?? "-")); \(keywords)"
        }
        var whereText = "in the object's dictionary/body"
        if let data = object.data, data.contains(offset) {
            whereText = "in its stream at +\(offset - data.lowerBound) of \(data.count) bytes"
        } else if let data = object.data, offset >= data.upperBound {
            whereText = "after its stream (endstream/endobj)"
        }
        return "obj \(object.number) \(object.generation) @\(object.start)..<\(object.end) \(whereText); \(keywords); dict: \(escape(object.dictionary, limit: 260))"
    }

    /// A /FlateDecode stream inflated (zlib: the 2-byte header is skipped; Apple's `.zlib` is raw DEFLATE).
    static func inflate(_ data: ArraySlice<UInt8>) -> [UInt8]? {
        guard data.count > 2, data[data.startIndex] & 0x0F == 8 else { return nil }
        let body = Data(data[(data.startIndex + 2)...])
        guard let out = try? (body as NSData).decompressed(using: .zlib) else { return nil }
        return [UInt8](out as Data)
    }

    /// `/BaseFont /X` and `/FontName /X` of every object's dictionary, in the file's order.
    static func fontNames(_ objects: [Object]) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "/(BaseFont|FontName)\\s*/([^\\s/\\[\\]<>()%]+)") else { return [] }
        var out: [String] = []
        for object in objects {
            let text = object.dictionary
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) else { continue }
                out.append("obj\(object.number) /\(text[key]) /\(text[value])")
            }
        }
        return out
    }

    /// What an object is, from its dictionary (for the list of differing objects).
    static func kind(_ dictionary: String) -> String {
        let d = dictionary.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        func has(_ token: String) -> Bool { d.contains(token) }
        if has("/Subtype /Image") || has("/Subtype/Image") { return has("/SMask") ? "image+smask" : "image" }
        if has("/Type /FontDescriptor") { return "fontDescriptor" }
        if has("/Type /Font") { return "font" }
        if has("/Length1") { return "fontFile2" }
        if has("/CIDFontType0C") || has("/Type1C") || has("/OpenType") { return "fontFile3" }
        if has("/Alternate") { return "iccProfile" }
        if has("/Type /Page ") || has("/Type /Page>") { return "page" }
        if has("/Type /Pages") { return "pages" }
        if has("/Type /Catalog") { return "catalog" }
        if has("/Producer") || has("/Creator") || has("/Title") { return "info" }
        if has("/Subtype /Form") { return "form" }
        if has("/ExtGState") || has("/ProcSet") { return "resources" }
        if has("/Type /ExtGState") || has("/ca ") || has("/CA ") { return "extGState" }
        if has("/FunctionType") || has("/ShadingType") { return "shading" }
        if has("/Filter /FlateDecode") || has("/Length") { return "stream" }
        return "other"
    }

    /// FNV-1a, 64 bits, as 16 hex digits: a short name for a byte string.
    static func fnv(_ bytes: [UInt8]) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        bytes.withUnsafeBufferPointer { b in
            for byte in b {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
        }
        return String(format: "%016llx", hash)
    }

    /// An integer entry of a dictionary (`/Width 2000`).
    static func integer(_ key: String, in dictionary: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "/\(key)\\s+(\\d+)") else { return nil }
        guard let match = regex.firstMatch(in: dictionary, range: NSRange(dictionary.startIndex..., in: dictionary)),
              let range = Range(match.range(at: 1), in: dictionary) else { return nil }
        return Int(dictionary[range])
    }

    /// The lines that say how two objects with the same number differ: sizes, raw and inflated differences, the
    /// first inflated difference with ±80 bytes, and for an 8-bit image the differing pixels' box.
    static func compare(_ a: [UInt8], _ objectA: Object, _ b: [UInt8], _ objectB: Object) -> [String] {
        var lines: [String] = []
        let dictionary = objectA.dictionary
        lines.append("obj \(objectA.number): sizes A \(objectA.end - objectA.start) B \(objectB.end - objectB.start); dict A \(escape(dictionary, limit: 300))")
        if objectA.dictionary != objectB.dictionary {
            lines.append("obj \(objectA.number): dict B differs: \(escape(objectB.dictionary, limit: 300))")
        }
        guard let rangeA = objectA.data, let rangeB = objectB.data else {
            let raw = regions(Array(a[objectA.start..<objectA.end]), Array(b[objectB.start..<objectB.end]))
            lines.append("obj \(objectA.number): no stream; \(raw.count) differing bytes")
            return lines
        }
        let rawA = Array(a[rangeA]), rawB = Array(b[rangeB])
        let raw = regions(rawA, rawB)
        lines.append("obj \(objectA.number): stream A \(rawA.count) B \(rawB.count) bytes; \(raw.count) differing raw bytes in \(raw.regions.count) runs; first run \(raw.regions.first.map { "+\($0.lowerBound)..<+\($0.upperBound)" } ?? "-")")
        guard dictionary.contains("/FlateDecode") else { return lines }
        guard let inA = inflate(a[rangeA]), let inB = inflate(b[rangeB]) else {
            lines.append("obj \(objectA.number): inflate failed")
            return lines
        }
        let decoded = regions(inA, inB)
        lines.append("obj \(objectA.number): inflated A \(inA.count) B \(inB.count) bytes; \(decoded.count) differing in \(decoded.regions.count) runs")
        if let first = decoded.regions.first {
            let from = max(0, first.lowerBound - 80)
            lines.append("obj \(objectA.number): inflated A @+\(first.lowerBound) [\(escape(inA[from..<min(inA.count, first.lowerBound + 80)]))]")
            lines.append("obj \(objectA.number): inflated B @+\(first.lowerBound) [\(escape(inB[from..<min(inB.count, first.lowerBound + 80)]))]")
        }
        if dictionary.contains("/Image"), let width = integer("Width", in: dictionary), let height = integer("Height", in: dictionary),
           integer("BitsPerComponent", in: dictionary) == 8, width > 0, height > 0, inA.count == inB.count, inA.count % (width * height) == 0 {
            let components = inA.count / (width * height)
            var pixels = 0, maxDelta = 0
            var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
            inA.withUnsafeBufferPointer { pa in
                inB.withUnsafeBufferPointer { pb in
                    for pixel in 0..<(width * height) {
                        var delta = 0
                        for c in 0..<components {
                            delta = max(delta, abs(Int(pa[pixel * components + c]) - Int(pb[pixel * components + c])))
                        }
                        guard delta > 0 else { continue }
                        pixels += 1
                        maxDelta = max(maxDelta, delta)
                        let x = pixel % width, y = pixel / width
                        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
            }
            lines.append("obj \(objectA.number): image \(width)x\(height)x\(components): \(pixels) differing pixels, box \(pixels > 0 ? "x\(minX)...\(maxX) y\(minY)...\(maxY)" : "-"), max channel delta \(maxDelta)")
        }
        return lines
    }
}
