// The second look of the span-shots-app job at a pair of photos before and after a shift (docs/M7C_CONTRACT.md §10.5,
// DECISIONS C3-M4) that tools/shots/shift_pair.swift found strongly different. The first W run of wave C2 (run 43596500507)
// found three of the four pairs different although nothing had moved: after a shift the band is placed again one page
// width further (week 1,400 lu, day 1,000 lu, times the zoom), which is rarely a whole number of device pixels (the iPad
// Air 11-inch's day: 383.75 pt = 767.5 px), so the paper's lines, boxes and text are drawn again at another sub-pixel
// phase. Their edges then differ by up to 224 of 255 here and there (1,579, 4,947 and 3,828 strong pixels), while the
// best whole-pixel alignment of the two photos stays (0, 0) and 4 × 4 averages differ by at most 31.
// This program tells such a re-drawing from a move: a strongly differing pixel is explained when its value in each photo
// lies within the range of the other photo's 3 × 3 pixels around it (each of R, G, B, A, give or take 32 of 255), in both
// directions: a line, a box or a glyph drawn again less than a pixel away. What is left (the residual) is what moved by
// more than a pixel, came or went: a stroke that moved 2 px, one that vanished, the paper that jumped. (A whole move of
// one pixel, 0.5 pt on an iPad, is explained too; the whole-pixel offset with the fewest strong pixels is printed so a
// reader sees one, but it does not decide.) Glyph stems of one pixel can be re-hinted outside the range: 6, 31 and 26
// pixels in that run.
//
//   swiftc -O tools/shots/shift_subpixel.swift -o <program>
//   <program> <before.png> <after.png> [--exclude-rows <top>-<bottom>]... [--max-residual <n>]
//   <program> --self-test
//
// The rows, the colour handling and the strong threshold (32 of 255) are shift_pair.swift's. One line on the standard
// output: the result, the strong pixels, the residual (at most --max-residual, default 0) with the box around it, and the
// whole-pixel offset (dx, dy within ±2) with the fewest strong pixels (printed only). Exit status: 0 = the residual is
// within the limit, 1 = it is not or the photos are not the same size, 2 = a photo cannot be read, or wrong arguments. --self-test checks the rules on images made in memory and exits 0 when every case holds.

import CoreGraphics
import Foundation
import ImageIO

enum Settings {
    /// A channel difference above this (of 255) is a strong one (shift_pair.swift, compare_shots.swift).
    static let strong = 32
    /// How far a value may lie outside the other photo's 3 × 3 range and still be explained (of 255).
    static let slack = 32
    /// The whole-pixel offsets tried for the alignment.
    static let reach = 2
}

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

struct RowRange: Equatable {
    let top: Int
    let bottom: Int
    var text: String { "y \(top)-\(bottom)" }
}

func parseRows(_ text: String) -> RowRange? {
    let parts = text.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 2, let top = Int(parts[0]), let bottom = Int(parts[1]), top >= 0, bottom >= top else { return nil }
    return RowRange(top: top, bottom: bottom)
}

struct Outcome {
    var sameSize = true
    var strong = 0
    var residual = 0
    var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
    /// The whole-pixel offset of `after` against `before` with the fewest strong pixels, and that count.
    var best = (dx: 0, dy: 0, strong: 0)
    var box: String? { residual > 0 ? "y \(minY)-\(maxY) x \(minX)-\(maxX)" : nil }
}

func isStrong(_ a: Raster, _ i: Int, _ b: Raster, _ j: Int) -> Bool {
    for c in 0..<4 where abs(Int(a.bytes[i + c]) - Int(b.bytes[j + c])) > Settings.strong { return true }
    return false
}

/// Whether `value`'s pixel at (x, y) lies, channel by channel, within the range of `other`'s 3 × 3 pixels around (x, y)
/// (the rows compared only), give or take `Settings.slack`.
func explained(_ value: Raster, by other: Raster, x: Int, y: Int, compared: [Bool]) -> Bool {
    let i = (y * value.width + x) * 4
    for c in 0..<4 {
        var low = 255, high = 0
        for yy in max(0, y - 1)...min(other.height - 1, y + 1) where compared[yy] {
            for xx in max(0, x - 1)...min(other.width - 1, x + 1) {
                let v = Int(other.bytes[(yy * other.width + xx) * 4 + c])
                low = min(low, v)
                high = max(high, v)
            }
        }
        let v = Int(value.bytes[i + c])
        if v < low - Settings.slack || v > high + Settings.slack { return false }
    }
    return true
}

func compare(_ a: Raster, _ b: Raster, excluding: [RowRange]) -> Outcome {
    var outcome = Outcome()
    guard a.width == b.width, a.height == b.height else {
        outcome.sameSize = false
        return outcome
    }
    var compared = [Bool](repeating: true, count: a.height)
    for range in excluding where range.top < a.height {
        for y in range.top...min(range.bottom, a.height - 1) { compared[y] = false }
    }
    for y in 0..<a.height where compared[y] {
        for x in 0..<a.width {
            let i = (y * a.width + x) * 4
            guard isStrong(a, i, b, i) else { continue }
            outcome.strong += 1
            if explained(b, by: a, x: x, y: y, compared: compared) && explained(a, by: b, x: x, y: y, compared: compared) { continue }
            outcome.residual += 1
            outcome.minX = min(outcome.minX, x)
            outcome.maxX = max(outcome.maxX, x)
            outcome.minY = min(outcome.minY, y)
            outcome.maxY = max(outcome.maxY, y)
        }
    }
    // The alignment: the strong pixels of `after` moved by (dx, dy) against `before`, over the rows compared (every
    // fourth row and column, enough to see a move).
    var best: (dx: Int, dy: Int, strong: Int)?
    let r = Settings.reach
    for dy in -r...r {
        for dx in -r...r {
            var n = 0
            for y in stride(from: r, to: a.height - r, by: 4) where compared[y] && compared[y + dy] {
                for x in stride(from: r, to: a.width - r, by: 4) {
                    if isStrong(a, (y * a.width + x) * 4, b, ((y + dy) * b.width + x + dx) * 4) { n += 1 }
                }
            }
            if best == nil || n < best!.strong || (n == best!.strong && dx == 0 && dy == 0) { best = (dx, dy, n) }
        }
    }
    outcome.best = best ?? (0, 0, 0)
    return outcome
}

func verdict(_ o: Outcome, _ a: Raster, _ b: Raster, excluding: [RowRange], maxResidual: Int) -> (line: String, ok: Bool) {
    guard o.sameSize else {
        return ("DIFFER: the photos are \(a.width)x\(a.height) and \(b.width)x\(b.height)", false)
    }
    let ok = o.residual <= maxResidual
    var line = (ok ? "only sub-pixel: " : "DIFFER: ")
        + "\(grouped(o.strong)) strongly differing pixels, \(grouped(o.residual)) of them not explained by a re-drawing less than a "
        + "pixel away (at most \(grouped(maxResidual))); the best whole-pixel alignment dx \(o.best.dx) dy \(o.best.dy)"
    line += excluding.isEmpty ? "" : " (left out: " + excluding.map(\.text).joined(separator: ", ") + ")"
    if let box = o.box { line += "; the residual within \(box)" }
    return (line, ok)
}

// MARK: - Self-test

func blank(_ width: Int, _ height: Int) -> Raster {
    Raster(width: width, height: height, bytes: [UInt8](repeating: 255, count: width * height * 4))
}

func paint(_ r: inout Raster, _ x: Int, _ y: Int, _ grey: UInt8) {
    let i = (y * r.width + x) * 4
    r.bytes[i] = grey; r.bytes[i + 1] = grey; r.bytes[i + 2] = grey; r.bytes[i + 3] = 255
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
    let w = 60, h = 40
    // A vertical line 2 px wide (columns 20-21) and a box's edge (columns 40-59 dark from row 10 to 29).
    func scene(_ lineAt: Double, boxAt: Double) -> Raster {
        var r = blank(w, h)
        for y in 0..<h {
            for x in 0..<w {
                // Coverage of the pixel [x, x+1) by the line [lineAt, lineAt+2) and by the box [boxAt, ∞) in rows 10-29.
                let line = max(0, min(Double(x + 1), lineAt + 2) - max(Double(x), lineAt))
                let box = (10...29).contains(y) ? max(0, min(1, Double(x + 1) - boxAt)) : 0
                let ink = min(1, line + box)
                paint(&r, x, y, UInt8(255 - (255 - 30) * ink))
            }
        }
        return r
    }
    let before = scene(20, boxAt: 40)
    var o = compare(before, before, excluding: [])
    check("the same photo: nothing strong, aligned at (0, 0)", o.strong == 0 && o.residual == 0 && o.best == (0, 0, 0)
          && verdict(o, before, before, excluding: [], maxResidual: 0).ok, "\(o)")

    let half = scene(20.5, boxAt: 40.5)
    o = compare(before, half, excluding: [])
    check("drawn again half a pixel to the right: 100 strong pixels, all explained, passes at 0",
          o.strong == 100 && o.residual == 0 && verdict(o, before, half, excluding: [], maxResidual: 0).ok, "\(o)")
    let one = scene(21, boxAt: 41)
    o = compare(before, one, excluding: [])
    check("moved one whole pixel: explained too (0.5 pt on an iPad), the best alignment dx 1",
          o.strong > 0 && o.residual == 0 && o.best.dx == 1 && o.best.dy == 0, "\(o)")

    let two = scene(22, boxAt: 42)
    o = compare(before, two, excluding: [])
    // Of the 200 strong pixels (4 columns × 40 rows of the line, 2 × 20 of the box's edge) the outer column of each side
    // of the line (2 × 40) and both of the box's edge columns (2 × 20, less the corners whose 3 × 3 reach the white rows)
    // are not explained: 118.
    check("moved 2 px: 118 of the 200 strong pixels not explained, the best alignment dx 2, fails at 0 and at 100",
          o.strong == 200 && o.residual == 118 && o.best.dx == 2 && o.best.dy == 0
            && !verdict(o, before, two, excluding: [], maxResidual: 0).ok && !verdict(o, before, two, excluding: [], maxResidual: 100).ok,
          "\(o)")

    var gone = before
    for y in 0..<h { for x in 18...24 { paint(&gone, x, y, 255) } }
    o = compare(before, gone, excluding: [])
    check("the line vanished: 2 × 40 pixels not explained, aligned, fails at 0, passes at 80",
          o.residual == 80 && o.box == "y 0-39 x 20-21" && !verdict(o, before, gone, excluding: [], maxResidual: 0).ok
            && verdict(o, before, gone, excluding: [], maxResidual: 80).ok, "\(o)")

    var dot = before
    paint(&dot, 5, 5, 0)
    o = compare(before, dot, excluding: [])
    check("one new dark pixel on white: 1 not explained, within y 5-5 x 5-5", o.residual == 1 && o.box == "y 5-5 x 5-5", "\(o)")
    o = compare(before, dot, excluding: [RowRange(top: 0, bottom: 7)])
    check("... and nothing with its rows left out", o.strong == 0 && o.residual == 0, "\(o)")

    let turned = blank(h, w)
    o = compare(before, turned, excluding: [])
    check("photos of another size differ", !o.sameSize && !verdict(o, before, turned, excluding: [], maxResidual: 1_000).ok)

    let folder = NSTemporaryDirectory() + "shift_subpixel-self-test-\(getpid())"
    try? FileManager.default.removeItem(atPath: folder)
    let made = (try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)) != nil
    if made, writePNG(before, to: folder + "/a.png"), writePNG(half, to: folder + "/b.png"),
       let ia = loadImage(folder + "/a.png"), let ib = loadImage(folder + "/b.png"),
       let ra = rasterize(ia, in: colourSpace(of: ia)), let rb = rasterize(ib, in: colourSpace(of: ia)) {
        let fromFiles = compare(ra, rb, excluding: [])
        let inMemory = compare(before, half, excluding: [])
        check("through PNG files: the same counts", fromFiles.strong == inMemory.strong && fromFiles.residual == 0, "\(fromFiles)")
    } else {
        check("through PNG files: written and read again", false, folder)
    }
    try? FileManager.default.removeItem(atPath: folder)

    check("--exclude-rows 0-120 is read", parseRows("0-120") == RowRange(top: 0, bottom: 120))
    for bad in ["120-0", "-1-3", "a-b", "5", ""] {
        check("--exclude-rows \"\(bad)\" is refused", parseRows(bad) == nil)
    }
    print("self-test: \(cases) cases, \(failed) failed")
    return failed == 0 ? 0 : 1
}

// MARK: - Main

func usage(_ problem: String) -> Never {
    print("cannot compare: " + problem)
    print("usage: shift_subpixel <before.png> <after.png> [--exclude-rows <top>-<bottom>]... [--max-residual <n>] | --self-test")
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-test"] { exit(selfTest()) }
var paths: [String] = []
var excluded: [RowRange] = []
var maxResidual = 0
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
    case "--max-residual":
        guard index + 1 < arguments.count, let n = Int(arguments[index + 1]), n >= 0 else {
            usage("--max-residual takes a whole number of 0 or more")
        }
        maxResidual = n
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
let result = verdict(outcome, beforeRaster, afterRaster, excluding: excluded, maxResidual: maxResidual)
print(result.line)
exit(result.ok ? 0 : 1)
