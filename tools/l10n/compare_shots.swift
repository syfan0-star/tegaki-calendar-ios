// J-4 of docs/M7B_CONTRACT.md (§1.3, §7.5): compares two folders of screenshots image by image, pixel by
// pixel, and writes how many pixels differ and an image that marks them.
//
//   swift tools/l10n/compare_shots.swift <基準のフォルダ> <新しいフォルダ> <出力のフォルダ>
//
// For J-4 the 基準 (reference) is the artifact `ja-baseline-<sha>` of .github/workflows/ja-baseline.yml
// (1.1 = e7b4d2f shot again with 1.2's JA_ARGS) and the 新 (new) folder is 1.2's CI artifact `screenshots`.
// Both folders are walked with their sub-folders (store/ipad13/…); the .png / .jpg / .jpeg files with the
// same relative path are compared, everything else (logs, env.txt, fixtures/*.json) is skipped, and so are
// hidden files. macOS with the Command Line Tools is enough (Foundation, CoreGraphics, ImageIO).
//
// How a pair is compared: both images are drawn, without scaling, into 8-bit RGBA bitmaps in the colour
// space of the 基準 image (the simulator's PNGs are 8-bit sRGB, so nothing is converted), and a pixel
// differs when any of R, G, B, A differs. A difference above `Settings.strong` (of 255) in some channel is
// a strong one; the weak ones are what 1.1's comparison saw from the glass and the blur (at most 9/255,
// docs/M7A.md), the strong ones what moved text gives (up to 176/255 there).
//
// Written into the output folder (it must be new or empty, and outside both input folders):
//   report.tsv              one row per image: result, size, differing pixels, strong ones, the largest
//                           difference, the bands (rows with differences, merged when closer than
//                           `Settings.bandGap` rows) and the files written for it
//   <path>.diff.png         for an image that differs: the new image faded, the weak differences blue,
//                           the strong ones red, a magenta frame around each band
//   <path>.crop-<n>.png     the largest bands at full resolution, side by side:
//                           left = 基準, middle = 新, right = the marks (at most `Settings.maxCrops`)
// The summary goes to the standard output. Exit status: 0 = every image the same and on both sides,
// 1 = something differs, is on one side only or cannot be read, 2 = wrong arguments or a file error.
// No HTML is written (an .html file written on the owner's Mac opens on the owner's screen).

import CoreGraphics
import Foundation
import ImageIO

enum Settings {
    /// A channel difference above this (of 255) is a strong one.
    static let strong = 32
    /// Rows with differences fewer than this many rows apart belong to one band.
    static let bandGap = 16
    /// Bands that get a side-by-side crop, the largest first.
    static let maxCrops = 3
    /// Room around a band in the frames and the crops (pixels).
    static let padding = 16
    /// The largest crop (pixels; a bigger band is cut from its top left corner).
    static let maxCropWidth = 1600
    static let maxCropHeight = 1200
    /// The files compared.
    static let extensions: Set<String> = ["png", "jpg", "jpeg"]
}

// MARK: - Small helpers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("compare_shots: " + message + "\n").utf8))
    exit(2)
}

func warn(_ message: String) {
    FileHandle.standardError.write(Data(("compare_shots: " + message + "\n").utf8))
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

/// The path with its symbolic links resolved, also for a folder that does not exist yet (the nearest
/// existing ancestor is resolved and the rest appended), so `/tmp/x` and `/private/tmp/x` compare equal.
func canonicalPath(_ url: URL) -> String {
    var existing = url.standardizedFileURL
    var rest: [String] = []
    while !FileManager.default.fileExists(atPath: existing.path), existing.path != "/" {
        rest.insert(existing.lastPathComponent, at: 0)
        existing.deleteLastPathComponent()
    }
    var resolved = existing.resolvingSymlinksInPath()
    for part in rest { resolved.appendPathComponent(part) }
    return resolved.standardizedFileURL.path
}

func isInside(_ path: String, _ folder: String) -> Bool {
    path == folder || path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/")
}

func isDirectory(_ path: String) -> Bool {
    var dir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &dir) && dir.boolValue
}

/// Relative path → file, for the images under `root` (sub-folders included; hidden files and folders, and
/// symbolic links, skipped).
func listImages(_ root: String) -> [String: URL] {
    guard let walker = FileManager.default.enumerator(atPath: root) else { fail("フォルダを読めません: \(root)") }
    let rootURL = URL(fileURLWithPath: root, isDirectory: true)
    var found: [String: URL] = [:]
    while let relative = walker.nextObject() as? String {
        let name = (relative as NSString).lastPathComponent
        let type = walker.fileAttributes?[.type] as? FileAttributeType
        if name.hasPrefix(".") {
            if type == .typeDirectory { walker.skipDescendants() }
            continue
        }
        guard type == .typeRegular, Settings.extensions.contains((name as NSString).pathExtension.lowercased()) else { continue }
        found[relative] = rootURL.appendingPathComponent(relative)
    }
    return found
}

// MARK: - Images

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

let rgbaInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

/// 8-bit RGBA, premultiplied, row 0 = the top row of the image.
struct Raster {
    let width: Int
    let height: Int
    var bytes: [UInt8]
}

/// The colour space both images of a pair are drawn in: the 基準 image's own (an RGB space a bitmap can
/// use), else sRGB.
func comparisonSpace(_ image: CGImage) -> CGColorSpace {
    if let space = image.colorSpace, space.model == .rgb, space.supportsOutput { return space }
    return CGColorSpace(name: CGColorSpace.sRGB)!
}

func rasterize(_ image: CGImage, in space: CGColorSpace) -> Raster? {
    let width = image.width, height = image.height
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

func spaceName(_ space: CGColorSpace?) -> String {
    guard let space = space else { return "なし" }
    if let name = space.name { return name as String }
    return "ICC（名前なし）"
}

func sameSpace(_ a: CGColorSpace?, _ b: CGColorSpace?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case let (x?, y?): return CFEqual(x, y)
    default: return false
    }
}

// MARK: - Comparison

struct RowSpan {
    let y: Int
    let minX: Int
    let maxX: Int
    let count: Int
}

struct Band {
    var y0: Int
    var y1: Int
    var x0: Int
    var x1: Int
    var pixels: Int
    var text: String { "y \(y0)-\(y1) x \(x0)-\(x1) (\(grouped(pixels)))" }
}

struct Difference {
    var pixels = 0
    var strong = 0
    var maxDelta = 0
    var rows: [RowSpan] = []
    /// Per pixel: 0 = the same, 1 = weak, 2 = strong. Empty when the two images are the same.
    var mask: [UInt8] = []
}

func compare(_ a: Raster, _ b: Raster) -> Difference {
    var result = Difference()
    let width = a.width, height = a.height, rowBytes = width * 4
    a.bytes.withUnsafeBufferPointer { pa in
        b.bytes.withUnsafeBufferPointer { pb in
            guard let ba = pa.baseAddress, let bb = pb.baseAddress,
                  memcmp(ba, bb, rowBytes * height) != 0 else { return }
            var mask = [UInt8](repeating: 0, count: width * height)
            for y in 0..<height {
                let start = y * rowBytes
                if memcmp(ba + start, bb + start, rowBytes) == 0 { continue }
                var minX = width, maxX = -1, count = 0
                for x in 0..<width {
                    let i = start + x * 4
                    let d0 = abs(Int(pa[i]) - Int(pb[i])), d1 = abs(Int(pa[i + 1]) - Int(pb[i + 1]))
                    let d2 = abs(Int(pa[i + 2]) - Int(pb[i + 2])), d3 = abs(Int(pa[i + 3]) - Int(pb[i + 3]))
                    let delta = max(max(d0, d1), max(d2, d3))
                    if delta == 0 { continue }
                    count += 1
                    if x < minX { minX = x }
                    maxX = x
                    if delta > result.maxDelta { result.maxDelta = delta }
                    if delta > Settings.strong {
                        result.strong += 1
                        mask[y * width + x] = 2
                    } else {
                        mask[y * width + x] = 1
                    }
                }
                result.pixels += count
                result.rows.append(RowSpan(y: y, minX: minX, maxX: maxX, count: count))
            }
            result.mask = mask
        }
    }
    return result
}

func bands(of rows: [RowSpan]) -> [Band] {
    var result: [Band] = []
    for row in rows {
        if var last = result.last, row.y - last.y1 <= Settings.bandGap {
            last.y1 = row.y
            last.x0 = min(last.x0, row.minX)
            last.x1 = max(last.x1, row.maxX)
            last.pixels += row.count
            result[result.count - 1] = last
        } else {
            result.append(Band(y0: row.y, y1: row.y, x0: row.minX, x1: row.maxX, pixels: row.count))
        }
    }
    return result
}

/// A band with room around it, inside the image (top-left origin, like the pixel rows).
func padded(_ band: Band, width: Int, height: Int) -> (x: Int, y: Int, w: Int, h: Int) {
    let x0 = max(0, band.x0 - Settings.padding), y0 = max(0, band.y0 - Settings.padding)
    let x1 = min(width - 1, band.x1 + Settings.padding), y1 = min(height - 1, band.y1 + Settings.padding)
    return (x0, y0, x1 - x0 + 1, y1 - y0 + 1)
}

// MARK: - Output images

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
        return false
    }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

/// The new image faded onto white, a frame around each band, the differing pixels painted last (so a
/// frame clamped to the edge of the image never hides them).
func marksImage(_ new: CGImage, _ difference: Difference, _ bandList: [Band]) -> CGImage? {
    let width = new.width, height = new.height
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                              space: srgb, bitmapInfo: rgbaInfo) else { return nil }
    ctx.interpolationQuality = .none
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.setAlpha(0.3)
    ctx.draw(new, in: CGRect(x: 0, y: 0, width: width, height: height))
    ctx.setAlpha(1)
    ctx.setStrokeColor(CGColor(srgbRed: 0.9, green: 0, blue: 0.9, alpha: 1))
    ctx.setLineWidth(4)
    for band in bandList {
        let r = padded(band, width: width, height: height)
        // CoreGraphics counts y from the bottom.
        ctx.stroke(CGRect(x: r.x, y: height - r.y - r.h, width: r.w, height: r.h).insetBy(dx: 2, dy: 2))
    }
    guard let data = ctx.data else { return nil }
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for row in difference.rows {
        for x in row.minX...row.maxX {
            let kind = difference.mask[row.y * width + x]
            if kind == 0 { continue }
            let i = (row.y * width + x) * 4
            if kind == 2 {
                pixels[i] = 220; pixels[i + 1] = 0; pixels[i + 2] = 0      // strong: red
            } else {
                pixels[i] = 0; pixels[i + 1] = 110; pixels[i + 2] = 255    // weak: blue
            }
            pixels[i + 3] = 255
        }
    }
    return ctx.makeImage()
}

/// left = 基準, middle = 新, right = marks, at full resolution, for one band.
func cropImage(_ base: CGImage, _ new: CGImage, _ marks: CGImage, _ band: Band) -> CGImage? {
    let p = padded(band, width: new.width, height: new.height)
    let rect = CGRect(x: p.x, y: p.y, width: min(p.w, Settings.maxCropWidth), height: min(p.h, Settings.maxCropHeight))
    guard let a = base.cropping(to: rect), let b = new.cropping(to: rect), let m = marks.cropping(to: rect) else { return nil }
    let gap = 16, w = Int(rect.width), h = Int(rect.height)
    guard let ctx = CGContext(data: nil, width: w * 3 + gap * 2, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: rgbaInfo) else { return nil }
    ctx.interpolationQuality = .none
    ctx.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w * 3 + gap * 2, height: h))
    for (i, image) in [a, b, m].enumerated() {
        ctx.draw(image, in: CGRect(x: i * (w + gap), y: 0, width: w, height: h))
    }
    return ctx.makeImage()
}

// MARK: - One pair

struct Row {
    var path: String
    var result: String
    var size = ""
    var pixels: Int? = nil
    var strong: Int? = nil
    var maxDelta: Int? = nil
    var bands: [Band] = []
    var files: [String] = []
    var notes: [String] = []
}

func comparePair(_ path: String, _ baseURL: URL, _ newURL: URL, outRoot: URL) -> Row {
    var row = Row(path: path, result: "同じ")
    guard let base = loadImage(baseURL) else {
        row.result = "読めない"
        row.notes.append("基準の写真を読めない")
        if loadImage(newURL) == nil { row.notes.append("新の写真も読めない") }
        return row
    }
    guard let new = loadImage(newURL) else {
        row.result = "読めない"
        row.notes.append("新の写真を読めない")
        return row
    }
    row.size = "\(base.width)x\(base.height)"
    if base.width != new.width || base.height != new.height {
        row.result = "大きさが違う"
        row.size = "\(base.width)x\(base.height) → \(new.width)x\(new.height)"
        return row
    }
    let space = comparisonSpace(base)
    if !sameSpace(base.colorSpace, new.colorSpace) {
        row.notes.append("色の空間が違う（基準 \(spaceName(base.colorSpace))、新 \(spaceName(new.colorSpace))。新を基準の空間に直して比べた）")
    }
    if base.bitsPerComponent != 8 || new.bitsPerComponent != 8 {
        row.notes.append("色の深さ（基準 \(base.bitsPerComponent) bit、新 \(new.bitsPerComponent) bit）を 8 bit にして比べた")
    }
    guard let a = rasterize(base, in: space), let b = rasterize(new, in: space) else {
        row.result = "読めない"
        row.notes.append("画素にできない（\(spaceName(space))）")
        return row
    }
    let difference = compare(a, b)
    row.pixels = difference.pixels
    row.strong = difference.strong
    row.maxDelta = difference.maxDelta
    if difference.pixels == 0 { return row }
    row.result = "違う"
    row.bands = bands(of: difference.rows)
    guard let marks = marksImage(new, difference, row.bands) else {
        row.notes.append("印の画像を作れない")
        return row
    }
    let marksPath = path + ".diff.png"
    if writePNG(marks, to: outRoot.appendingPathComponent(marksPath)) {
        row.files.append(marksPath)
    } else {
        row.notes.append("印の画像を書けない")
    }
    let largest = row.bands.enumerated()
        .sorted { $0.element.pixels != $1.element.pixels ? $0.element.pixels > $1.element.pixels : $0.offset < $1.offset }
        .prefix(Settings.maxCrops)
    for (n, item) in largest.enumerated() {
        let cropPath = path + ".crop-\(n + 1).png"
        if let crop = cropImage(base, new, marks, item.element),
           writePNG(crop, to: outRoot.appendingPathComponent(cropPath)) {
            row.files.append(cropPath)
        } else {
            row.notes.append("切り抜き \(n + 1) を書けない")
        }
    }
    return row
}

// MARK: - Report

func tsvField(_ text: String) -> String {
    text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
}

func numberField(_ n: Int?) -> String {
    guard let n = n else { return "" }
    return String(n)
}

func tsv(_ rows: [Row]) -> String {
    var lines = ["写真\t結果\t大きさ\t違う画素\t強い差\t最大の差\t違いの範囲\t書いた画像\t注記"]
    for row in rows {
        var fields: [String] = [row.path, row.result, row.size]
        fields.append(numberField(row.pixels))
        fields.append(numberField(row.strong))
        fields.append(numberField(row.maxDelta))
        fields.append(row.bands.map { $0.text }.joined(separator: "; "))
        fields.append(row.files.joined(separator: " "))
        fields.append(row.notes.joined(separator: " / "))
        lines.append(fields.map(tsvField).joined(separator: "\t"))
    }
    return lines.joined(separator: "\n") + "\n"
}

/// The one-side-only files, a folder with many of them on one line (ui-tests/attachments/ of 1.2's CI).
func onlyLines(_ paths: [String]) -> [String] {
    var byFolder: [String: [String]] = [:]
    for path in paths {
        let folder = (path as NSString).deletingLastPathComponent
        byFolder[folder, default: []].append(path)
    }
    var lines: [String] = []
    for folder in byFolder.keys.sorted() {
        let files = byFolder[folder]!.sorted()
        if files.count > 5, !folder.isEmpty {
            lines.append("  \(folder)/ の \(files.count) 枚（\(files.first!) … \(files.last!)）")
        } else {
            lines.append(contentsOf: files.map { "  " + $0 })
        }
    }
    return lines
}

// MARK: - Main

func main() -> Int32 {
    let args = Array(CommandLine.arguments.dropFirst())
    let usage = "使い方: swift tools/l10n/compare_shots.swift <基準のフォルダ> <新しいフォルダ> <出力のフォルダ>"
    if args.count == 1, args[0] == "-h" || args[0] == "--help" {
        print(usage)
        print("基準と新の同じ名前の写真（.png・.jpg、下のフォルダも）を 1 画素ずつ比べ、出力のフォルダに report.tsv と印の画像を書く。")
        print("終了の状態: 0 = 全部同じ、1 = 違う・片方だけ・読めない写真がある、2 = 引数やファイルの誤り。")
        return 0
    }
    guard args.count == 3 else { fail(usage) }
    // The paths as given (made absolute) are used and printed; the resolved ones only decide whether the
    // output folder lies inside an input folder (/tmp and /private/tmp are the same place).
    let basePath = URL(fileURLWithPath: args[0]).path
    let newPath = URL(fileURLWithPath: args[1]).path
    let outPath = URL(fileURLWithPath: args[2]).path
    guard isDirectory(basePath) else { fail("基準のフォルダがありません: \(args[0])") }
    guard isDirectory(newPath) else { fail("新しいフォルダがありません: \(args[1])") }
    let outResolved = canonicalPath(URL(fileURLWithPath: outPath))
    if isInside(outResolved, canonicalPath(URL(fileURLWithPath: basePath)))
        || isInside(outResolved, canonicalPath(URL(fileURLWithPath: newPath))) {
        fail("出力のフォルダは、比べる 2 つのフォルダの外にしてください: \(args[2])")
    }
    let fm = FileManager.default
    if fm.fileExists(atPath: outPath) {
        guard isDirectory(outPath) else { fail("出力の場所がフォルダではありません: \(args[2])") }
        let entries = ((try? fm.contentsOfDirectory(atPath: outPath)) ?? []).filter { $0 != ".DS_Store" }
        guard entries.isEmpty else {
            fail("出力のフォルダが空ではありません（前の結果と混ざらないように、新しいフォルダを指定してください）: \(args[2])")
        }
    } else {
        // Only the last folder is made: a mistyped path does not leave a chain of folders somewhere else.
        let parent = (outPath as NSString).deletingLastPathComponent
        guard isDirectory(parent) else { fail("出力のフォルダの親がありません: \(parent)") }
        do {
            try fm.createDirectory(atPath: outPath, withIntermediateDirectories: false)
        } catch {
            fail("出力のフォルダを作れません: \(args[2])（\(error.localizedDescription)）")
        }
    }
    if canonicalPath(URL(fileURLWithPath: basePath)) == canonicalPath(URL(fileURLWithPath: newPath)) {
        warn("基準と新が同じフォルダです")
    }

    let baseFiles = listImages(basePath)
    let newFiles = listImages(newPath)
    if baseFiles.isEmpty && newFiles.isEmpty { fail("どちらのフォルダにも写真（.png・.jpg）がありません") }
    let outRoot = URL(fileURLWithPath: outPath, isDirectory: true)

    var rows: [Row] = []
    for path in Set(baseFiles.keys).union(newFiles.keys).sorted() {
        switch (baseFiles[path], newFiles[path]) {
        case let (base?, new?):
            let row = autoreleasepool { comparePair(path, base, new, outRoot: outRoot) }
            rows.append(row)
        case (_?, nil):
            rows.append(Row(path: path, result: "基準だけ"))
        case (nil, _?):
            rows.append(Row(path: path, result: "新だけ"))
        case (nil, nil):
            break
        }
    }

    let report = outRoot.appendingPathComponent("report.tsv")
    do {
        try tsv(rows).write(to: report, atomically: true, encoding: .utf8)
    } catch {
        fail("report.tsv を書けません: \(error.localizedDescription)")
    }

    print("基準: \(basePath)（写真 \(baseFiles.count) 枚）")
    print("新:   \(newPath)（写真 \(newFiles.count) 枚）")
    print("出力: \(outPath)")
    print("")
    let order = ["同じ", "違う", "大きさが違う", "基準だけ", "新だけ", "読めない"]
    for name in order {
        print("\(name)\t\(rows.filter { $0.result == name }.count)")
    }
    let differing = rows.filter { $0.result == "違う" }
    if !differing.isEmpty {
        print("")
        print("違う写真（違う画素・うち強い差（\(Settings.strong) を超える差）・最大の差（255 まで）・違いの範囲（y は上から、x は左からの画素））:")
        for row in differing {
            print("  \(row.path)  \(grouped(row.pixels ?? 0)) 画素（強い差 \(grouped(row.strong ?? 0))）最大 \(row.maxDelta ?? 0)")
            for band in row.bands.prefix(6) { print("      \(band.text)") }
            if row.bands.count > 6 { print("      …ほか \(row.bands.count - 6) か所（report.tsv）") }
            for note in row.notes { print("      注記: \(note)") }
        }
    }
    for name in ["大きさが違う", "読めない"] {
        let list = rows.filter { $0.result == name }
        if list.isEmpty { continue }
        print("")
        print("\(name):")
        for row in list { print("  \(row.path)  \(row.size)  \(row.notes.joined(separator: " / "))") }
    }
    for name in ["基準だけ", "新だけ"] {
        let list = rows.filter { $0.result == name }.map(\.path)
        if list.isEmpty { continue }
        print("")
        print("\(name):")
        onlyLines(list).forEach { print($0) }
    }
    let notedSame = rows.filter { $0.result == "同じ" && !$0.notes.isEmpty }
    if !notedSame.isEmpty {
        print("")
        print("同じだが注記のある写真:")
        for row in notedSame { print("  \(row.path)  \(row.notes.joined(separator: " / "))") }
    }
    print("")
    print("表: \(report.path)")
    if !differing.isEmpty {
        print("印の画像: <写真>.diff.png（新を薄くし、弱い差は青・強い差は赤、違いの範囲を紫の枠）、")
        print("          <写真>.crop-<n>.png（違いの大きい範囲の原寸。左 = 基準・中 = 新・右 = 印）")
    }
    return rows.allSatisfy { $0.result == "同じ" } ? 0 : 1
}

exit(main())
