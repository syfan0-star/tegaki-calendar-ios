// The count of docs/M7C.md's wave D text decision 11 and DECISIONS C3-m4 (the span-shots-app job of build.yml): how many
// pixels of the desk around one page are not the desk's colour when the page holds the halves of strokes drawn across
// its left boundary (`--screenshot-single-page`, the way 1.2.3 and older versions show a page written on with 1.3), so the
// lead can tell whether the App Store text needs the line "on an older version, a stroke across the boundary is cut at the
// edge of the page". The same count of the same screen without those strokes (the control, the 1.2.3 demo) must be 0:
// only then does a count above 0 come from the strokes. SpanShotsUITests.testOldVersionMargins takes the photos and prints
// their geometry; the job calls this program once per photo.
//
//   swiftc -O tools/shots/span_margin.swift -o <program>
//   <program> <photo.png> --window <w>x<h> --frame <x>,<y>,<w>,<h> --zoom <z> --ox <ox> --paper <lu> [--edge <px>]
//   <program> --self-test
//
// --window is the app's window and --frame the canvas's frame (the paper area under the heading and the all-day band,
// above the bottom toolbar), both in points as the UI test reads them; --zoom and --ox are the canvas probe's (`ox` is
// the content offset in points: negative when the page is narrower than the canvas and centred, the margin on its left);
// --paper is the page's width in lu (week 1,400, day 1,000). The photo must have the window's shape (its pixels are the
// window's points times one scale, 2 or 3; a portrait photo of a turned screen is refused). The margins are the canvas
// columns left of the page and right of it, less --edge pixels (default 2) next to the page's edge and the frame's (the
// antialiased edge), over the canvas rows less --edge at the top and the bottom. A pixel counts when one of R, G, B differs
// from the desk #ecebe6 (InkCanvasContainerView.deskColor) by more than 8 of 255. The photo is drawn without scaling into
// an 8-bit RGBA bitmap in sRGB (the simulator's PNGs are sRGB), as tools/shots/shift_pair.swift does.
// One line on the standard output:
//   left=<n> right=<n> cols=<first>-<last>|none,<first>-<last>|none rows=<first>-<last> scale=<s> size=<w>x<h>
// (pixel columns and rows, both ends included; `none` when the page reaches that side of the canvas, the margin then 0).
// Exit status: 0 = counted, 2 = the photo cannot be read, it is not the window's shape, or wrong arguments.
// --self-test checks these rules on images made in memory (and once through a PNG file), prints a line per case and exits
// 0 when every case holds, 1 otherwise. macOS with the Command Line Tools is enough (Foundation, CoreGraphics, ImageIO).

import CoreGraphics
import Foundation
import ImageIO

enum Desk {
    /// #ecebe6 (InkCanvasContainerView.deskColor).
    static let rgb: (Int, Int, Int) = (0xec, 0xeb, 0xe6)
    /// A channel further than this from the desk's (of 255) makes the pixel "not the desk".
    static let tolerance = 8
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

func rasterize(_ image: CGImage) -> Raster? {
    let width = image.width, height = image.height
    guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
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

/// Pixel columns or rows from `first` to `last`, both included; empty when `last < first`.
struct Span: Equatable {
    let first: Int
    let last: Int
    var isEmpty: Bool { last < first }
    var count: Int { isEmpty ? 0 : last - first + 1 }
    var text: String { isEmpty ? "none" : "\(first)-\(last)" }
}

struct Geometry {
    var window: CGSize
    var frame: CGRect
    var zoom: CGFloat
    var ox: CGFloat
    var paper: CGFloat
    var edge = 2
}

struct Margins {
    var scale: CGFloat
    var left: Span
    var right: Span
    var rows: Span
}

enum Problem: Error, Equatable {
    case shape(String)
}

/// The margins' pixel columns and the canvas's pixel rows of a photo `width` × `height`.
func margins(_ g: Geometry, width: Int, height: Int) -> Result<Margins, Problem> {
    guard g.window.width > 0, g.window.height > 0 else { return .failure(.shape("the window has no size")) }
    let sx = CGFloat(width) / g.window.width, sy = CGFloat(height) / g.window.height
    // One scale for both sides, a whole number of pixels per point (1, 2 or 3): else the photo is not the window
    // (a turned screen photographed upright, or another device's photo).
    guard abs(sx - sy) < 0.01, abs(sx - sx.rounded()) < 0.01, sx.rounded() >= 1 else {
        return .failure(.shape("the photo is \(width)x\(height), not the window \(Int(g.window.width))x\(Int(g.window.height)) times one scale"))
    }
    let s = sx.rounded()
    let paperLeft = g.frame.minX - g.ox
    let paperRight = paperLeft + g.paper * g.zoom
    let frameFirst = Int((g.frame.minX * s).rounded(.up))
    let frameLast = Int((g.frame.maxX * s).rounded(.down)) - 1
    let left = Span(first: frameFirst + g.edge,
                    last: min(frameLast, Int((paperLeft * s).rounded(.down)) - 1) - g.edge)
    let right = Span(first: max(frameFirst, Int((paperRight * s).rounded(.up))) + g.edge,
                     last: frameLast - g.edge)
    let rows = Span(first: max(0, Int((g.frame.minY * s).rounded(.up)) + g.edge),
                    last: min(height - 1, Int((g.frame.maxY * s).rounded(.down)) - 1 - g.edge))
    let clamp: (Span) -> Span = { Span(first: max(0, $0.first), last: min(width - 1, $0.last)) }
    return .success(Margins(scale: s, left: clamp(left), right: clamp(right), rows: rows))
}

/// The pixels of `columns` × `rows` that are not the desk's colour.
func notDesk(_ r: Raster, columns: Span, rows: Span) -> Int {
    guard !columns.isEmpty, !rows.isEmpty else { return 0 }
    var n = 0
    for y in rows.first...rows.last {
        for x in columns.first...columns.last {
            let i = (y * r.width + x) * 4
            if abs(Int(r.bytes[i]) - Desk.rgb.0) > Desk.tolerance || abs(Int(r.bytes[i + 1]) - Desk.rgb.1) > Desk.tolerance
                || abs(Int(r.bytes[i + 2]) - Desk.rgb.2) > Desk.tolerance {
                n += 1
            }
        }
    }
    return n
}

func line(_ r: Raster, _ m: Margins) -> String {
    let scale = m.scale == m.scale.rounded() ? String(Int(m.scale)) : String(describing: m.scale)
    return "left=\(notDesk(r, columns: m.left, rows: m.rows)) right=\(notDesk(r, columns: m.right, rows: m.rows)) "
        + "cols=\(m.left.text),\(m.right.text) rows=\(m.rows.text) scale=\(scale) size=\(r.width)x\(r.height)"
}

// MARK: - Arguments

/// "<w>x<h>" with two positive finite numbers.
func parseSize(_ text: String) -> CGSize? {
    let parts = text.split(separator: "x", omittingEmptySubsequences: false)
    guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]), w.isFinite, h.isFinite, w > 0, h > 0 else { return nil }
    return CGSize(width: w, height: h)
}

/// "<x>,<y>,<w>,<h>" with four finite numbers, the size positive.
func parseRect(_ text: String) -> CGRect? {
    let parts = text.split(separator: ",", omittingEmptySubsequences: false).map { Double($0) }
    guard parts.count == 4, let x = parts[0], let y = parts[1], let w = parts[2], let h = parts[3],
          [x, y, w, h].allSatisfy(\.isFinite), w > 0, h > 0 else { return nil }
    return CGRect(x: x, y: y, width: w, height: h)
}

/// A finite number (positive when `positive`).
func parseNumber(_ text: String, positive: Bool) -> CGFloat? {
    guard let n = Double(text), n.isFinite, !positive || n > 0 else { return nil }
    return CGFloat(n)
}

// MARK: - Self-test

func filled(_ width: Int, _ height: Int, _ rgb: (UInt8, UInt8, UInt8)) -> Raster {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for i in stride(from: 0, to: bytes.count, by: 4) {
        bytes[i] = rgb.0; bytes[i + 1] = rgb.1; bytes[i + 2] = rgb.2
    }
    return Raster(width: width, height: height, bytes: bytes)
}

func paint(_ r: inout Raster, _ x: Int, _ y: Int, _ rgb: (UInt8, UInt8, UInt8)) {
    let i = (y * r.width + x) * 4
    r.bytes[i] = rgb.0; r.bytes[i + 1] = rgb.1; r.bytes[i + 2] = rgb.2; r.bytes[i + 3] = 255
}

func writePNG(_ r: Raster, to path: String) -> Bool {
    var bytes = r.bytes
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return false }
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
    let desk: (UInt8, UInt8, UInt8) = (0xec, 0xeb, 0xe6)
    let paperColour: (UInt8, UInt8, UInt8) = (0xfd, 0xfc, 0xf7)
    // A window of 100 × 80 pt at 2 px per pt; the canvas 0,20 100×50 pt (rows 40-139); a page of 60 pt (zoom 0.5 of 120
    // lu) centred: ox −20, the page at 20-80 pt (pixels 40-159), the margins pixels 0-39 and 160-199.
    let g = Geometry(window: CGSize(width: 100, height: 80), frame: CGRect(x: 0, y: 20, width: 100, height: 50),
                     zoom: 0.5, ox: -20, paper: 120)
    guard case .success(let m) = margins(g, width: 200, height: 160) else {
        check("the geometry of a 2x photo is read", false)
        print("self-test: \(cases) cases, \(failed) failed")
        return 1
    }
    check("scale 2 from a 200x160 photo of a 100x80 window", m.scale == 2)
    check("left margin: pixels 2-37 (2 off the frame's edge and the page's)", m.left == Span(first: 2, last: 37), m.left.text)
    check("right margin: pixels 162-197", m.right == Span(first: 162, last: 197), m.right.text)
    check("rows: the canvas's 40-139 less 2 at each end", m.rows == Span(first: 42, last: 137), m.rows.text)

    var screen = filled(200, 160, desk)
    for y in 40..<140 { for x in 40..<160 { paint(&screen, x, y, paperColour) } }
    for x in 0..<200 { for y in 0..<40 { paint(&screen, x, y, (255, 255, 255)) } }       // the heading, white
    for x in 0..<200 { for y in 140..<160 { paint(&screen, x, y, (250, 250, 250)) } }    // the toolbar
    check("the control: the page in its place, the heading and the toolbar outside the rows: 0 and 0",
          line(screen, m).hasPrefix("left=0 right=0 cols=2-37,162-197 rows=42-137 scale=2 size=200x160"), line(screen, m))

    var nearDesk = screen
    paint(&nearDesk, 10, 50, (0xec + 8, 0xeb - 8, 0xe6 + 8))
    check("8 off in every channel is still the desk", notDesk(nearDesk, columns: m.left, rows: m.rows) == 0)
    paint(&nearDesk, 11, 50, (0xec, 0xeb, 0xe6 - 9))
    check("9 off in one channel is not", notDesk(nearDesk, columns: m.left, rows: m.rows) == 1)

    var crossing = screen
    for x in 20..<40 { paint(&crossing, x, 90, (30, 30, 30)); paint(&crossing, x, 91, (30, 30, 30)) }   // a stroke into the left margin
    check("a stroke 20 px into the left margin: 18 × 2 counted (2 px at the page's edge left out), right 0",
          line(crossing, m).hasPrefix("left=36 right=0 "), line(crossing, m))
    var antialiased = screen
    for y in 40..<140 { paint(&antialiased, 39, y, (0xf4, 0xf3, 0xee)); paint(&antialiased, 160, y, (0xf4, 0xf3, 0xee)) }
    for y in 40..<140 { paint(&antialiased, 38, y, (0x90, 0x90, 0x90)); paint(&antialiased, 161, y, (0x90, 0x90, 0x90)) }
    check("the 2 columns at the page's edges are not counted", line(antialiased, m).hasPrefix("left=0 right=0 "), line(antialiased, m))
    var ruled = screen
    for x in 0..<200 { paint(&ruled, x, 40, (0, 0, 0)); paint(&ruled, x, 139, (0, 0, 0)) }
    check("the first and last rows of the canvas are not counted", line(ruled, m).hasPrefix("left=0 right=0 "), line(ruled, m))
    var below = screen
    for x in 0..<40 { paint(&below, x, 137, (0, 0, 0)) }
    check("the last row counted is 3 above the canvas's end", line(below, m).hasPrefix("left=36 right=0 "), line(below, m))

    // The page as wide as the canvas: no margin.
    let wide = Geometry(window: CGSize(width: 100, height: 80), frame: CGRect(x: 0, y: 20, width: 100, height: 50),
                        zoom: 0.5, ox: 0, paper: 200)
    if case .success(let w) = margins(wide, width: 200, height: 160) {
        check("a page as wide as the canvas: no margin on either side, 0 counted",
              w.left.isEmpty && w.right.isEmpty && line(crossing, w).hasPrefix("left=0 right=0 cols=none,none "), line(crossing, w))
    } else {
        check("a page as wide as the canvas is read", false)
    }
    // Scrolled into the page (ox > 0) and wider than the canvas: no margin either.
    let scrolled = Geometry(window: CGSize(width: 100, height: 80), frame: CGRect(x: 0, y: 20, width: 100, height: 50),
                            zoom: 1, ox: 30, paper: 300)
    if case .success(let w) = margins(scrolled, width: 200, height: 160) {
        check("a page scrolled sideways: no margin", w.left.isEmpty && w.right.isEmpty, "\(w.left.text) \(w.right.text)")
    } else {
        check("a scrolled page is read", false)
    }
    // A canvas inset from the window's left (an iPhone in landscape, frame x 31 pt), 3 px per pt.
    let inset = Geometry(window: CGSize(width: 200, height: 100), frame: CGRect(x: 31, y: 26, width: 140, height: 60),
                         zoom: 1, ox: -20, paper: 100)
    if case .success(let w) = margins(inset, width: 600, height: 300) {
        check("a frame inset from the window: the margins start at its edge (3 px per pt)",
              w.scale == 3 && w.left == Span(first: 95, last: 150) && w.right == Span(first: 455, last: 510)
                && w.rows == Span(first: 80, last: 255), "\(w.left.text) \(w.right.text) \(w.rows.text)")
    } else {
        check("an inset frame is read", false)
    }
    // A portrait photo of a turned screen, a photo of another size.
    check("a portrait photo of a landscape window is refused", (try? margins(inset, width: 300, height: 600).get()) == nil)
    check("a photo of 1.5 px per pt is refused", (try? margins(g, width: 150, height: 120).get()) == nil)
    check("a window without a size is refused",
          (try? margins(Geometry(window: .zero, frame: g.frame, zoom: 1, ox: 0, paper: 1), width: 10, height: 10).get()) == nil)

    let folder = NSTemporaryDirectory() + "span_margin-self-test-\(getpid())"
    try? FileManager.default.removeItem(atPath: folder)
    let made = (try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)) != nil
    let path = folder + "/crossing.png"
    if made, writePNG(crossing, to: path), let image = loadImage(path), let read = rasterize(image) {
        check("through a PNG file: the same count", line(read, m) == line(crossing, m), line(read, m))
    } else {
        check("through a PNG file: written and read again", false, folder)
    }
    let notImage = folder + "/not-an-image.png"
    FileManager.default.createFile(atPath: notImage, contents: Data("not a png".utf8))
    check("a file that is not an image cannot be read", loadImage(notImage) == nil)
    try? FileManager.default.removeItem(atPath: folder)

    check("--window 820x1180 is read", parseSize("820x1180") == CGSize(width: 820, height: 1180))
    check("--frame 0,110.5,1180,615.5 is read", parseRect("0,110.5,1180,615.5") == CGRect(x: 0, y: 110.5, width: 1180, height: 615.5))
    check("--ox -130.5 is read", parseNumber("-130.5", positive: false) == -130.5)
    for bad in ["", "820", "820x", "x1180", "0x10", "820x-1", "axb", "1x2x3"] {
        check("--window \"\(bad)\" is refused", parseSize(bad) == nil)
    }
    for bad in ["", "0,0,10", "0,0,0,10", "0,0,10,-1", "a,0,10,10", "0,0,10,10,1", "nan,0,10,10"] {
        check("--frame \"\(bad)\" is refused", parseRect(bad) == nil)
    }
    for bad in ["", "0", "-1", "inf", "nan", "x"] {
        check("--zoom \"\(bad)\" is refused", parseNumber(bad, positive: true) == nil)
    }

    print("self-test: \(cases) cases, \(failed) failed")
    return failed == 0 ? 0 : 1
}

// MARK: - Main

func usage(_ problem: String) -> Never {
    print("cannot count: " + problem)
    print("usage: span_margin <photo.png> --window <w>x<h> --frame <x>,<y>,<w>,<h> --zoom <z> --ox <ox> --paper <lu> [--edge <px>] | --self-test")
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-test"] { exit(selfTest()) }
var photo: String?
var window: CGSize?, frame: CGRect?, zoom: CGFloat?, ox: CGFloat?, paper: CGFloat?
var edge = 2
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    let value = index + 1 < arguments.count ? arguments[index + 1] : ""
    switch argument {
    case "--window":
        guard let parsed = parseSize(value) else { usage("--window takes <w>x<h>, two positive numbers") }
        window = parsed
        index += 2
    case "--frame":
        guard let parsed = parseRect(value) else { usage("--frame takes <x>,<y>,<w>,<h>, the size positive") }
        frame = parsed
        index += 2
    case "--zoom":
        guard let parsed = parseNumber(value, positive: true) else { usage("--zoom takes a positive number") }
        zoom = parsed
        index += 2
    case "--ox":
        guard let parsed = parseNumber(value, positive: false) else { usage("--ox takes a number") }
        ox = parsed
        index += 2
    case "--paper":
        guard let parsed = parseNumber(value, positive: true) else { usage("--paper takes a positive number (lu)") }
        paper = parsed
        index += 2
    case "--edge":
        guard let n = Int(value), n >= 0 else { usage("--edge takes a whole number of 0 or more") }
        edge = n
        index += 2
    default:
        if argument.hasPrefix("--") || photo != nil { usage("unknown argument \(argument)") }
        photo = argument
        index += 1
    }
}
guard let photo else { usage("give the photo") }
guard let window, let frame, let zoom, let ox, let paper else { usage("--window, --frame, --zoom, --ox and --paper are all needed") }
guard let image = loadImage(photo), let raster = rasterize(image) else { usage("\(photo) is not an image") }
switch margins(Geometry(window: window, frame: frame, zoom: zoom, ox: ox, paper: paper, edge: edge), width: raster.width, height: raster.height) {
case .success(let m):
    print(line(raster, m))
    exit(0)
case .failure(.shape(let why)):
    usage(why)
}
