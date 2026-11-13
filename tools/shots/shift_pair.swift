// The pair of photos of docs/M7C_CONTRACT.md §10.5 (`--screenshot-span-shift`, §3.12: the joined pages before and
// after a shift): with the header left out the two must be almost the same, or the span-shots job fails. Made in S5
// before those photos exist (track C; the review's C5-R3), so the step that takes them only has to call it: the rows
// to leave out are arguments (the header's height is P's, the status bar's the device's), not in this file.
//
//   swiftc -O tools/shots/shift_pair.swift -o <program>
//   <program> <before.png> <after.png> [--exclude-rows <top>-<bottom>]... [--max-strong <n>]
//   <program> --self-test
//
// Rows are the photos' pixel rows, the top one 0. <top>-<bottom> leaves out the rows from top to bottom, both
// included (the way tools/l10n/compare_shots.swift writes its bands, "y 20-42"); give it once for each band (the
// status bar, the header). A range that goes past the last row is cut there.
// The photos are drawn, without scaling, into 8-bit RGBA bitmaps in <before>'s colour space (the simulator's PNGs are
// 8-bit sRGB, so nothing is converted) and compared pixel by pixel, as compare_shots.swift and
// tools/shots/screen_ready.swift do: a pixel differs strongly when one of R, G, B, A differs by more than 32 of 255
// (the glass and the blur of two runs differ by at most 9). "Almost 0" is at most --max-strong strongly differing
// pixels in the rows compared, 0 when it is not given: weak differences pass, a stroke or a line that moved does not.
// One line on the standard output: the result, the strong pixels in the rows compared, the rows left out and, when
// some differ, the box around them ("y top-bottom x left-right", as compare_shots' bands). Exit status: 0 = almost
// the same, 1 = they differ or are not the same size, 2 = a photo cannot be read, or wrong arguments.
// --self-test checks these rules on images made in memory and written once through PNG files, prints a line per case
// and exits 0 when every case holds, 1 otherwise. macOS with the Command Line Tools is enough (Foundation,
// CoreGraphics, ImageIO).

import CoreGraphics
import Foundation
import ImageIO

enum Settings {
    /// A channel difference above this (of 255) is a strong one (tools/l10n/compare_shots.swift).
    static let strong = 32
}

/// 1234567 → "1,234,567" (the same on every Mac, whatever its region).
func grouped(_ n: Int) -> String {
    let digits = String(n.magnitude)
    var out = ""
    for (i, ch) in digits.enumerated() {
        if i > 0, (digits.count - i) % 3 == 0 { out.append(",") }
        out.append(ch)
    }
    return n < 0 ? "-" + out : out
}

struct Raster {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

let rgbaInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

func loadImage(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func colourSpace(of image: CGImage) -> CGColorSpace {
    if let own = image.colorSpace, own.model == .rgb, own.supportsOutput { return own }
    return CGColorSpace(name: CGColorSpace.sRGB)!
}

func rasterize(_ image: CGImage, in space: CGColorSpace) -> Raster? {
    let width = image.width, height = image.height
    guard width > 0, height > 0 else { return nil }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
        guard let ctx = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: space, bitmapInfo: rgbaInfo) else { return false }
        ctx.interpolationQuality = .none
        ctx.setBlendMode(.copy)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return drawn ? Raster(width: width, height: height, bytes: bytes) : nil
}

/// Rows from `top` to `bottom`, both included.
struct RowRange: Equatable {
    let top: Int
    let bottom: Int
    var text: String { "y \(top)-\(bottom)" }
}

/// "<top>-<bottom>" with 0 <= top <= bottom, or nil.
func parseRows(_ text: String) -> RowRange? {
    let parts = text.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 2, let top = Int(parts[0]), let bottom = Int(parts[1]), top >= 0, bottom >= top else { return nil }
    return RowRange(top: top, bottom: bottom)
}

struct Outcome {
    var sameSize = true
    /// Rows compared (the photo's rows less the ones left out).
    var rows = 0
    /// Strongly differing pixels in the rows compared.
    var strong = 0
    /// The box around them (both ends included), when there are some.
    var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
    var box: String? { strong > 0 ? "y \(minY)-\(maxY) x \(minX)-\(maxX)" : nil }
}

func compare(_ a: Raster, _ b: Raster, excluding: [RowRange]) -> Outcome {
    var outcome = Outcome()
    guard a.width == b.width, a.height == b.height else {
        outcome.sameSize = false
        return outcome
    }
    var leftOut = [Bool](repeating: false, count: a.height)
    for range in excluding where range.top < a.height {
        for y in range.top...min(range.bottom, a.height - 1) { leftOut[y] = true }
    }
    let rowBytes = a.width * 4
    a.bytes.withUnsafeBufferPointer { pa in
        b.bytes.withUnsafeBufferPointer { pb in
            guard let ba = pa.baseAddress, let bb = pb.baseAddress else { return }
            for y in 0..<a.height where !leftOut[y] {
                outcome.rows += 1
                let start = y * rowBytes
                if memcmp(ba + start, bb + start, rowBytes) == 0 { continue }
                for x in 0..<a.width {
                    let i = start + x * 4
                    if abs(Int(pa[i]) - Int(pb[i])) > Settings.strong || abs(Int(pa[i + 1]) - Int(pb[i + 1])) > Settings.strong
                        || abs(Int(pa[i + 2]) - Int(pb[i + 2])) > Settings.strong
                        || abs(Int(pa[i + 3]) - Int(pb[i + 3])) > Settings.strong {
                        outcome.strong += 1
                        outcome.minX = min(outcome.minX, x)
                        outcome.maxX = max(outcome.maxX, x)
                        outcome.minY = min(outcome.minY, y)
                        outcome.maxY = max(outcome.maxY, y)
                    }
                }
            }
        }
    }
    return outcome
}

/// The line printed and whether the pair passes.
func verdict(_ outcome: Outcome, _ a: Raster, _ b: Raster, excluding: [RowRange], maxStrong: Int) -> (line: String, ok: Bool) {
    guard outcome.sameSize else {
        return ("DIFFER: the photos are \(a.width)x\(a.height) and \(b.width)x\(b.height)", false)
    }
    let ok = outcome.strong <= maxStrong
    var line = (ok ? "almost the same: " : "DIFFER: ")
        + "\(grouped(outcome.strong)) strongly differing pixels (at most \(grouped(maxStrong))) in \(grouped(outcome.rows)) of "
        + "\(grouped(a.height)) rows"
    line += excluding.isEmpty ? "" : " (left out: " + excluding.map(\.text).joined(separator: ", ") + ")"
    if let box = outcome.box { line += "; within \(box)" }
    return (line, ok)
}

// MARK: - Self-test

/// A white raster.
func blank(_ width: Int, _ height: Int) -> Raster {
    Raster(width: width, height: height, bytes: [UInt8](repeating: 255, count: width * height * 4))
}

/// Sets one pixel (premultiplied RGBA; an opaque colour is the same either way).
func paint(_ r: inout Raster, _ x: Int, _ y: Int, _ rgba: (UInt8, UInt8, UInt8, UInt8)) {
    let i = (y * r.width + x) * 4
    r.bytes[i] = rgba.0; r.bytes[i + 1] = rgba.1; r.bytes[i + 2] = rgba.2; r.bytes[i + 3] = rgba.3
}

func writePNG(_ r: Raster, to path: String) -> Bool {
    var bytes = r.bytes
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let image: CGImage? = bytes.withUnsafeMutableBytes { raw in
        CGContext(data: raw.baseAddress, width: r.width, height: r.height, bitsPerComponent: 8, bytesPerRow: r.width * 4,
                  space: space, bitmapInfo: rgbaInfo)?.makeImage()
    }
    guard let image,
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

func selfTest() -> Int32 {
    var failed = 0, cases = 0
    func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
        cases += 1
        if condition {
            print("ok: " + name)
        } else {
            failed += 1
            print("FAILED: " + name + (detail().isEmpty ? "" : " (" + detail() + ")"))
        }
    }
    let w = 40, h = 30
    let white = blank(w, h)

    var o = compare(white, white, excluding: [])
    check("the same photo: 0 strong pixels, all rows compared, passes at 0",
          o.strong == 0 && o.rows == h && verdict(o, white, white, excluding: [], maxStrong: 0).ok, "\(o)")

    var one = white
    paint(&one, 5, 10, (222, 255, 255, 255))  // R by 33
    o = compare(white, one, excluding: [])
    check("one pixel 33 off in R is strong", o.strong == 1 && o.box == "y 10-10 x 5-5", "\(o)")
    check("... and fails at --max-strong 0", !verdict(o, white, one, excluding: [], maxStrong: 0).ok)
    check("... and passes at --max-strong 1", verdict(o, white, one, excluding: [], maxStrong: 1).ok)

    var weak = white
    paint(&weak, 5, 10, (223, 223, 223, 255))  // 32 in each of R, G, B
    o = compare(white, weak, excluding: [])
    check("32 off in every colour is weak only and passes at 0",
          o.strong == 0 && verdict(o, white, weak, excluding: [], maxStrong: 0).ok, "\(o)")

    var opaqueBlack = white, clearBlack = white
    paint(&opaqueBlack, 7, 3, (0, 0, 0, 255))
    paint(&clearBlack, 7, 3, (0, 0, 0, 215))  // the same colour, alpha 40 lower
    o = compare(opaqueBlack, clearBlack, excluding: [])
    check("alpha alone 40 off is strong", o.strong == 1 && o.box == "y 3-3 x 7-7", "\(o)")

    o = compare(white, one, excluding: [RowRange(top: 10, bottom: 12)])
    check("a row range leaves out its top row", o.strong == 0 && o.rows == h - 3, "\(o)")
    o = compare(white, one, excluding: [RowRange(top: 8, bottom: 10)])
    check("a row range leaves out its bottom row", o.strong == 0 && o.rows == h - 3, "\(o)")
    o = compare(white, one, excluding: [RowRange(top: 11, bottom: 12), RowRange(top: 0, bottom: 9)])
    check("rows just above and below a difference leave it in", o.strong == 1 && o.rows == h - 12, "\(o)")

    var bottom = white
    paint(&bottom, 0, h - 1, (0, 0, 0, 255))
    o = compare(white, bottom, excluding: [RowRange(top: 25, bottom: 1_000)])
    check("a range past the last row is cut there", o.strong == 0 && o.rows == 25, "\(o)")
    o = compare(white, bottom, excluding: [RowRange(top: 500, bottom: 1_000)])
    check("a range wholly below the photo leaves out nothing", o.strong == 1 && o.rows == h, "\(o)")

    let turned = blank(h, w)
    o = compare(white, turned, excluding: [])
    let turnedVerdict = verdict(o, white, turned, excluding: [], maxStrong: 1_000_000)
    check("photos of another size differ, whatever --max-strong is",
          !o.sameSize && !turnedVerdict.ok && turnedVerdict.line.hasPrefix("DIFFER: the photos are 40x30 and 30x40"),
          turnedVerdict.line)

    // A stroke 2 pixels wide (rows 5-24) moved 2 pixels to the right, and a header (rows 0-3) whose title changed.
    var before = white, after = white
    for y in 5...24 {
        for x in 10...11 { paint(&before, x, y, (20, 20, 20, 255)) }
        for x in 12...13 { paint(&after, x, y, (20, 20, 20, 255)) }
    }
    for y in 0...3 { for x in 0..<w where x % 3 == 0 { paint(&after, x, y, (0, 0, 0, 255)) } }
    o = compare(before, after, excluding: [RowRange(top: 0, bottom: 3)])
    check("a stroke moved 2 pixels: 80 strong pixels within y 5-24 x 10-13", o.strong == 80 && o.box == "y 5-24 x 10-13", "\(o)")
    check("... and fails at 0", !verdict(o, before, after, excluding: [RowRange(top: 0, bottom: 3)], maxStrong: 0).ok)
    var unmoved = after
    for y in 5...24 {
        for x in 10...11 { paint(&unmoved, x, y, (20, 20, 20, 255)) }
        for x in 12...13 { paint(&unmoved, x, y, (255, 255, 255, 255)) }
    }
    o = compare(before, unmoved, excluding: [RowRange(top: 0, bottom: 3)])
    check("the stroke in place and only the header changed: passes with the header left out",
          o.strong == 0 && verdict(o, before, unmoved, excluding: [RowRange(top: 0, bottom: 3)], maxStrong: 0).ok, "\(o)")
    o = compare(before, unmoved, excluding: [])
    check("... and fails with it in (14 marks in each of 4 rows)", o.strong == 56 && o.box == "y 0-3 x 0-39", "\(o)")

    let folder = NSTemporaryDirectory() + "shift_pair-self-test-\(getpid())"
    try? FileManager.default.removeItem(atPath: folder)
    let made = (try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)) != nil
    let beforePath = folder + "/before.png", afterPath = folder + "/after.png"
    if made, writePNG(before, to: beforePath), writePNG(after, to: afterPath),
       let a = loadImage(beforePath), let b = loadImage(afterPath),
       let ra = rasterize(a, in: colourSpace(of: a)), let rb = rasterize(b, in: colourSpace(of: a)) {
        let fromFiles = compare(ra, rb, excluding: [RowRange(top: 0, bottom: 3)])
        check("through PNG files: the same 80 strong pixels and box",
              ra.bytes == before.bytes && fromFiles.strong == 80 && fromFiles.box == "y 5-24 x 10-13", "\(fromFiles)")
    } else {
        check("through PNG files: written and read again", false, folder)
    }
    let notImage = folder + "/not-an-image.png"
    FileManager.default.createFile(atPath: notImage, contents: Data("not a png".utf8))
    check("a file that is not an image cannot be read", loadImage(notImage) == nil)
    try? FileManager.default.removeItem(atPath: folder)

    check("--exclude-rows 0-120 is read", parseRows("0-120") == RowRange(top: 0, bottom: 120))
    check("--exclude-rows 7-7 is one row", parseRows("7-7") == RowRange(top: 7, bottom: 7))
    for bad in ["120-0", "-1-3", "a-b", "5", "", "1-2-3", "3-"] {
        check("--exclude-rows \"\(bad)\" is refused", parseRows(bad) == nil)
    }

    print("self-test: \(cases) cases, \(failed) failed")
    return failed == 0 ? 0 : 1
}

// MARK: - Main

func usage(_ problem: String) -> Never {
    print("cannot compare: " + problem)
    print("usage: shift_pair <before.png> <after.png> [--exclude-rows <top>-<bottom>]... [--max-strong <n>] | --self-test")
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-test"] { exit(selfTest()) }
var paths: [String] = []
var excluded: [RowRange] = []
var maxStrong = 0
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    switch argument {
    case "--exclude-rows":
        guard index + 1 < arguments.count, let range = parseRows(arguments[index + 1]) else {
            usage("--exclude-rows takes <top>-<bottom>, two whole numbers with 0 <= top <= bottom (e.g. 0-120)")
        }
        excluded.append(range)
        index += 2
    case "--max-strong":
        guard index + 1 < arguments.count, let n = Int(arguments[index + 1]), n >= 0 else {
            usage("--max-strong takes a whole number of 0 or more")
        }
        maxStrong = n
        index += 2
    default:
        if argument.hasPrefix("--") { usage("unknown option \(argument)") }
        paths.append(argument)
        index += 1
    }
}
guard paths.count == 2 else { usage("give two photos, before and after") }

guard let beforeImage = loadImage(paths[0]) else { usage("\(paths[0]) is not an image") }
let space = colourSpace(of: beforeImage)
guard let beforeRaster = rasterize(beforeImage, in: space) else { usage("\(paths[0]) cannot be drawn") }
guard let afterImage = loadImage(paths[1]), let afterRaster = rasterize(afterImage, in: space) else {
    usage("\(paths[1]) is not an image")
}
let outcome = compare(beforeRaster, afterRaster, excluding: excluded)
let result = verdict(outcome, beforeRaster, afterRaster, excluding: excluded, maxStrong: maxStrong)
print(result.line)
exit(result.ok ? 0 : 1)
