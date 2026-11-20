// Is the demo handwriting of a CI photo all drawn? (docs/M7D_CONTRACT.md §3.5 (f); docs/M7D.md, D0b)
// In D0 (run 44632524223) photos of the image 20261119 (macOS 27.2 hosts) lacked some of their handwriting: whole
// PencilKit tiles (512 lu) not shown, the strokes all in the canvas. tools/shots/ink_retake.sh runs this after each
// photo of build.yml's and ja-baseline.yml's photo steps and of l10n-shots, and takes a short photo again.
//
//   swiftc -O tools/shots/ink_check.swift -o <program>
//   <program> ref <photo.png> <name>          prints the reference line of a complete photo (stdout)
//   <program> <photo.png> <ref.tsv> [<name>]  checks a photo against its reference line (name: the file's name by default)
//
// A reference line is "<name>\t<width>x<height>\t<top mask>\t<x>,<y>,<class>,<count>;…": per 48 px tile, the
// pixels of each ink class (dark: max(R,G,B) < 110; yellow marker: R > 200, G > 170, B < 140, R - B > 90; red: R > 170,
// G < 100, B < 100; blue: B > 170, R < 110, G < 150, B - R > 90), for tiles with at least 20 of a class. The top rows
// (the status bar) are left out. The lines are in tools/shots/ink_ref.tsv (its head says which photos they come from).
// A photo fails when the tiles whose count fell to less than half of the reference (and by at least 8) miss 30 pixels or
// more together. Exit status: 0 complete (or no reference line for this name: nothing to say), 1 handwriting missing,
// 2 the photo could not be read or has another size. One line on stdout either way; a checked photo's line has
// "<n> px short" (the pixels missing from the tiles that fell short), which tools/shots/ink_retake.sh reads.
// About 0.1 s a photo.
import Foundation
import CoreGraphics
import ImageIO

let tile = 48
func load(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}
func counts(_ image: CGImage, top: Int) -> [String: Int] {
    let w = image.width, h = image.height
    var p = [UInt8](repeating: 0, count: w * h * 4)
    p.withUnsafeMutableBytes { b in
        let ctx = CGContext(data: b.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    var out: [String: Int] = [:]
    for y in top..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let r = Int(p[i]), g = Int(p[i + 1]), b = Int(p[i + 2])
            let c: Int
            if max(r, g, b) < 110 { c = 0 }
            else if r > 200 && g > 170 && b < 140 && r - b > 90 { c = 1 }
            else if r > 170 && g < 100 && b < 100 { c = 2 }
            else if b > 170 && r < 110 && g < 150 && b - r > 90 { c = 3 }
            else { continue }
            out["\(x / tile),\(y / tile),\(c)", default: 0] += 1
        }
    }
    return out
}
func topMask(_ w: Int, _ h: Int) -> Int {
    switch (w, h) {
    case (1206, 2622): return 180          // iPhone 17
    case (1320, 2868): return 186          // iPhone 18 Pro Max / 17 Pro Max
    case (2622, 1206), (2868, 1320): return 0
    default: return 64                     // iPads
    }
}
let args = CommandLine.arguments
if args.count >= 4, args[1] == "ref" {
    guard let image = load(args[2]) else { print("ink: cannot read \(args[2])"); exit(2) }
    let top = topMask(image.width, image.height)
    let tiles = counts(image, top: top).filter { $0.value >= 20 }.sorted { $0.key < $1.key }
    print("\(args[3])\t\(image.width)x\(image.height)\t\(top)\t" + tiles.map { "\($0.key),\($0.value)" }.joined(separator: ";"))
    exit(0)
}
guard args.count >= 3 else { print("usage: ink_check <photo.png> <ref.tsv> [<name>] | ink_check ref <photo.png> <name>"); exit(2) }
let name = args.count >= 4 ? args[3] : URL(fileURLWithPath: args[1]).lastPathComponent
guard let text = try? String(contentsOfFile: args[2], encoding: .utf8) else { print("ink: no reference file"); exit(0) }
guard let line = text.split(separator: "\n").first(where: { $0.hasPrefix(name + "\t") }) else { print("ink: \(name): no reference"); exit(0) }
let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
guard fields.count == 4, let top = Int(fields[2]) else { print("ink: \(name): bad reference line"); exit(0) }
guard let image = load(args[1]) else { print("ink: \(name): cannot read the photo"); exit(2) }
guard "\(image.width)x\(image.height)" == String(fields[1]) else { print("ink: \(name): \(image.width)x\(image.height), the reference is \(fields[1])"); exit(2) }
let now = counts(image, top: top)
var missing = 0, tilesShort = 0
var box = (x0: Int.max, y0: Int.max, x1: -1, y1: -1)
for item in fields[3].split(separator: ";") {
    let v = item.split(separator: ",").compactMap { Int($0) }
    guard v.count == 4 else { continue }
    let key = "\(v[0]),\(v[1]),\(v[2])"
    let ref = v[3], got = now[key] ?? 0
    if ref - got >= 8 && got * 2 < ref {
        missing += ref - got; tilesShort += 1
        box = (min(box.x0, v[0] * tile), min(box.y0, v[1] * tile), max(box.x1, v[0] * tile + tile - 1), max(box.y1, v[1] * tile + tile - 1))
    }
}
if missing >= 30 {
    print("ink: \(name): handwriting missing (\(missing) px short in \(tilesShort) tiles, px box \(box.x0),\(box.y0)-\(box.x1),\(box.y1))")
    exit(1)
}
print("ink: \(name): complete (\(missing) px short)")
exit(0)
