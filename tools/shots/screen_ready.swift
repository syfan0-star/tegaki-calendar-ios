// The wait of a photo step for the screen it photographs (docs/M7C_CONTRACT.md §10.5, J-4; docs/M7C.md, S3's J-4
// and the hand-offs to S5): a photo is kept once the screen holds still and is not one of the screens shown before
// it. The 13-inch iPad's sheets were taken a fixed 9 s after the launch, and once (run 43149906124) the photo of
// `--screenshot-sheet holidays` still showed the settings the picker opens from.
//
//   swiftc -O tools/shots/screen_ready.swift -o <program>
//   <program> <shot.png> <earlier.png> [<unlike.png> ...]
//
// shot: the frame just taken. earlier: a frame of the same screen taken about a second before it. unlike: photos
// of screens the shot must not be (the page before its sheet opened, the settings a picker opens from); one that
// does not exist is skipped (that photo was not taken), and one of another size counts as unlike.
//
// Two frames are drawn, without scaling, into 8-bit RGBA bitmaps in the shot's colour space (the simulator's PNGs
// are 8-bit sRGB, so nothing is converted) and compared pixel by pixel, as tools/l10n/compare_shots.swift does. A
// pixel differs strongly when one of R, G, B, A differs by more than 32 of 255 (compare_shots' `strong`; the glass
// and the blur of two runs differ by at most 9).
//   still   at most 1 pixel in 2,000 differs strongly from the earlier frame (on the 13-inch iPad, at most 2,840 of
//           5,680,128: a text cursor's blink is a few hundred; a sheet that slides in or a page that is pushed
//           moves hundreds of thousands)
//   unlike  at least 1 pixel in 1,000 (at least 5,681 on the 13-inch iPad) of the shot or of that photo differs
//           strongly from every pixel of the other up to 3 pixels away (`reach`, across and down; the larger of the
//           two counts). Since 1.3's review of the week memo: a screen a few pixels from its place is still that
//           screen. Before it, "unlike" counted the strongly differing pixels, and in run 44296486095 the frame of
//           `--screenshot-sheet holidays` was kept although it held the settings, still, a few pixels from their place,
//           the picker not yet open (32,648 pixels from the settings' photo; 1,220 without a like pixel within 3; the
//           same picture as that of run 43149906124, taken at 9 s before this tool). A
//           settled sheet keeps its distance (the picker and the other three opened from the settings: at least 23,816
//           from the settings' photo; every sheet: at least 37,015 from the month page's, the lasso's menu; runs
//           44296486095 and 44238377199), so it is taken as before, and the other one is waited for.
// One line on the standard output. Exit status: 0 = ready (still, and unlike every photo given), 1 = not yet,
// 2 = the shot or the earlier frame cannot be read, or wrong arguments. macOS with the Command Line Tools is enough
// (Foundation, CoreGraphics, ImageIO).

import CoreGraphics
import Foundation
import ImageIO

enum Settings {
    /// A channel difference above this (of 255) is a strong one (tools/l10n/compare_shots.swift).
    static let strong = 32
    /// Still: at most one strongly differing pixel in this many.
    static let stillPer = 2_000
    /// Unlike: at least one pixel in this many with no like pixel within `reach`.
    static let unlikePer = 1_000
    /// Unlike: how far (pixels, across and down) a like pixel of the other image may be (1.3's review of the week memo).
    static let reach = 3
}

func fail(_ message: String) -> Never {
    print("cannot compare: " + message)
    exit(2)
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
    var pixels: Int { width * height }
}

let rgbaInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

func loadImage(_ path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
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

/// The number of strongly differing pixels of two rasters of the same size.
func strongPixels(_ a: Raster, _ b: Raster) -> Int {
    var strong = 0
    let rowBytes = a.width * 4
    a.bytes.withUnsafeBufferPointer { pa in
        b.bytes.withUnsafeBufferPointer { pb in
            guard let ba = pa.baseAddress, let bb = pb.baseAddress else { return }
            for y in 0..<a.height {
                let start = y * rowBytes
                if memcmp(ba + start, bb + start, rowBytes) == 0 { continue }
                for x in 0..<a.width {
                    let i = start + x * 4
                    if abs(Int(pa[i]) - Int(pb[i])) > Settings.strong || abs(Int(pa[i + 1]) - Int(pb[i + 1])) > Settings.strong
                        || abs(Int(pa[i + 2]) - Int(pb[i + 2])) > Settings.strong || abs(Int(pa[i + 3]) - Int(pb[i + 3])) > Settings.strong {
                        strong += 1
                    }
                }
            }
        }
    }
    return strong
}

/// The pixels of `a` that differ strongly from the pixel of `b` at the same place and from every pixel of `b` up to
/// `reach` pixels away across and down: what `a` shows and `b` has nowhere near. A screen moved by up to `reach`
/// pixels has none of them (1.3's review of the week memo).
func unmatchedPixels(_ a: Raster, _ b: Raster, reach: Int) -> Int {
    var count = 0
    let width = a.width, height = a.height
    let rowBytes = width * 4
    a.bytes.withUnsafeBufferPointer { pa in
        b.bytes.withUnsafeBufferPointer { pb in
            guard let ba = pa.baseAddress, let bb = pb.baseAddress else { return }
            func like(_ i: Int, _ j: Int) -> Bool {
                abs(Int(ba[i]) - Int(bb[j])) <= Settings.strong && abs(Int(ba[i + 1]) - Int(bb[j + 1])) <= Settings.strong
                    && abs(Int(ba[i + 2]) - Int(bb[j + 2])) <= Settings.strong && abs(Int(ba[i + 3]) - Int(bb[j + 3])) <= Settings.strong
            }
            for y in 0..<height {
                let start = y * rowBytes
                if memcmp(ba + start, bb + start, rowBytes) == 0 { continue }
                for x in 0..<width {
                    let i = start + x * 4
                    if like(i, i) { continue }
                    var found = false
                    search: for yy in max(0, y - reach)...min(height - 1, y + reach) {
                        for xx in max(0, x - reach)...min(width - 1, x + reach) where like(i, (yy * width + xx) * 4) {
                            found = true
                            break search
                        }
                    }
                    if !found { count += 1 }
                }
            }
        }
    }
    return count
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    print("usage: screen_ready <shot.png> <earlier.png> [<unlike.png> ...]")
    exit(2)
}
let shotPath = arguments[0], earlierPath = arguments[1], unlikePaths = Array(arguments.dropFirst(2))

guard let shotImage = loadImage(shotPath) else { fail("\(shotPath) is not an image") }
let space: CGColorSpace = {
    if let own = shotImage.colorSpace, own.model == .rgb, own.supportsOutput { return own }
    return CGColorSpace(name: CGColorSpace.sRGB)!
}()
guard let shot = rasterize(shotImage, in: space) else { fail("\(shotPath) cannot be drawn") }
guard let earlierImage = loadImage(earlierPath), let earlier = rasterize(earlierImage, in: space) else {
    fail("\(earlierPath) is not an image")
}

var ready = true
var parts: [String] = []
let total = grouped(shot.pixels)
if earlier.width != shot.width || earlier.height != shot.height {
    ready = false
    parts.append("moving (the earlier frame is \(earlier.width)x\(earlier.height), this one \(shot.width)x\(shot.height))")
} else {
    let changed = strongPixels(shot, earlier)
    let still = changed * Settings.stillPer <= shot.pixels
    if !still { ready = false }
    parts.append("\(still ? "still" : "moving") (\(grouped(changed)) of \(total) pixels changed since the earlier frame)")
}
for path in unlikePaths {
    let name = (path as NSString).lastPathComponent
    guard FileManager.default.fileExists(atPath: path) else {
        parts.append("no \(name) to compare with")
        continue
    }
    guard let image = loadImage(path), let other = rasterize(image, in: space) else {
        parts.append("\(name) cannot be read (skipped)")
        continue
    }
    if other.width != shot.width || other.height != shot.height {
        parts.append("unlike \(name) (\(other.width)x\(other.height))")
        continue
    }
    let differing = strongPixels(shot, other)
    let unmatched = max(unmatchedPixels(shot, other, reach: Settings.reach), unmatchedPixels(other, shot, reach: Settings.reach))
    let unlike = unmatched * Settings.unlikePer >= shot.pixels
    if !unlike { ready = false }
    parts.append("\(unlike ? "unlike" : "LIKE") \(name) (\(grouped(differing)) pixels differ, \(grouped(unmatched)) with no like pixel within \(Settings.reach))")
}
print((ready ? "ready: " : "not yet: ") + parts.joined(separator: "; "))
exit(ready ? 0 : 1)
