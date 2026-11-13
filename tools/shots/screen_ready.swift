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
//   unlike  at least 1 pixel in 1,000 differs strongly from that photo (at least 5,681 on the 13-inch iPad)
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
    /// Unlike: at least one strongly differing pixel in this many.
    static let unlikePer = 1_000
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
    let unlike = differing * Settings.unlikePer >= shot.pixels
    if !unlike { ready = false }
    parts.append("\(unlike ? "unlike" : "LIKE") \(name) (\(grouped(differing)) pixels differ)")
}
print((ready ? "ready: " : "not yet: ") + parts.joined(separator: "; "))
exit(ready ? 0 : 1)
