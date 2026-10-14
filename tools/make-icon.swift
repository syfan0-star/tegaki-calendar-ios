// Renders the app icon (1024x1024, opaque PNG) with CoreGraphics only.
// usage: swift tools/make-icon.swift Sources/TegakiCalendar/Assets.xcassets/AppIcon.appiconset/icon-1024.png
// (macOS, Command Line Tools only; the single 1024 px image is enough since Xcode 14 makes every size.)
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r / 255, g / 255, b / 255, a])!
}

let S = CGFloat(size)

// 1. Paper background (soft warm gradient).
let paperTop = rgb(255, 253, 247)
let paperBottom = rgb(244, 238, 226)
let grad = CGGradient(colorsSpace: cs, colors: [paperTop, paperBottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

// 2. Calendar header band (accent blue) with two binder rings.
let bandH: CGFloat = 236
let band = CGRect(x: 0, y: S - bandH, width: S, height: bandH)
ctx.setFillColor(rgb(37, 99, 235))
ctx.fill(band)
// Subtle darker strip under the band for depth.
ctx.setFillColor(rgb(29, 78, 216))
ctx.fill(CGRect(x: 0, y: S - bandH - 10, width: S, height: 10))
// Binder rings.
ctx.setFillColor(rgb(255, 255, 255, 0.92))
for cx in [CGFloat(296), CGFloat(728)] {
    let ring = CGRect(x: cx - 40, y: S - bandH + 64, width: 80, height: 108)
    ctx.fillEllipse(in: ring.insetBy(dx: 0, dy: 0))
    ctx.setFillColor(rgb(37, 99, 235))
    ctx.fillEllipse(in: ring.insetBy(dx: 24, dy: 32))
    ctx.setFillColor(rgb(255, 255, 255, 0.92))
}

// 3. Grid (7 columns x 3 rows) under the band.
let gridTop = S - bandH - 10
let gridBottom: CGFloat = 96
let gridLeft: CGFloat = 96
let gridRight: CGFloat = S - 96
let cols = 7
let rows = 3
let colW = (gridRight - gridLeft) / CGFloat(cols)
let rowH = (gridTop - gridBottom) / CGFloat(rows)
ctx.setStrokeColor(rgb(191, 183, 168))
ctx.setLineWidth(8)
for c in 0...cols {
    let x = gridLeft + CGFloat(c) * colW
    ctx.move(to: CGPoint(x: x, y: gridBottom)); ctx.addLine(to: CGPoint(x: x, y: gridTop))
}
for r in 0...rows {
    let y = gridBottom + CGFloat(r) * rowH
    ctx.move(to: CGPoint(x: gridLeft, y: y)); ctx.addLine(to: CGPoint(x: gridRight, y: y))
}
ctx.strokePath()
// Weekend tint on the last two columns (very light).
ctx.setFillColor(rgb(37, 99, 235, 0.05))
ctx.fill(CGRect(x: gridLeft + 5 * colW, y: gridBottom, width: colW, height: gridTop - gridBottom))
ctx.setFillColor(rgb(220, 38, 38, 0.06))
ctx.fill(CGRect(x: gridLeft + 6 * colW, y: gridBottom, width: colW, height: gridTop - gridBottom))

// 4. Small "date" dots in the top-left of each cell (reads as a calendar page even when tiny).
ctx.setFillColor(rgb(120, 113, 100))
for r in 0..<rows {
    for c in 0..<cols {
        let x = gridLeft + CGFloat(c) * colW + 22
        let y = gridBottom + CGFloat(rows - r) * rowH - 40
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: 18, height: 18))
    }
}

// 5. Yellow marker swipe across the bottom row (multiply blend, like the app).
ctx.saveGState()
ctx.setBlendMode(.multiply)
ctx.setFillColor(rgb(253, 224, 71, 0.8))
let swipe = CGRect(x: gridLeft + 3.3 * colW, y: gridBottom + 0.30 * rowH, width: 3.4 * colW, height: 0.38 * rowH)
ctx.addPath(CGPath(roundedRect: swipe, cornerWidth: swipe.height / 2, cornerHeight: swipe.height / 2, transform: nil))
ctx.fillPath()
ctx.restoreGState()

// 6. Pen strokes in ink, tapered (drawn as many short round segments).
func taperedStroke(_ points: [CGPoint], from w0: CGFloat, to w1: CGFloat, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let n = points.count - 1
    for i in 0..<n {
        let t = CGFloat(i) / CGFloat(max(n - 1, 1))
        ctx.setLineWidth(w0 + (w1 - w0) * t)
        ctx.move(to: points[i]); ctx.addLine(to: points[i + 1]); ctx.strokePath()
    }
}
func bezier(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, steps: Int) -> [CGPoint] {
    (0...steps).map { i in
        let t = CGFloat(i) / CGFloat(steps), u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}
let ink = rgb(31, 41, 55)
// A hand-drawn circle around one day (middle row, 3rd column): a slightly wobbly ellipse that
// overlaps itself at the end, like a real pen stroke.
let cell = CGRect(x: gridLeft + 2 * colW, y: gridBottom + rowH, width: colW, height: rowH)
let center = CGPoint(x: cell.midX + 4, y: cell.midY - 6)
let rx: CGFloat = colW * 0.86, ry: CGFloat = rowH * 0.46
var circle: [CGPoint] = []
let steps = 120
for i in 0...steps {
    let t = CGFloat(i) / CGFloat(steps)
    let ang = -CGFloat.pi * 0.35 + t * CGFloat.pi * 2 * 1.08   // start upper-right, 1.08 turns
    let wobble = 1 + 0.035 * sin(ang * 3 + 0.8) + 0.02 * cos(ang * 5)
    let drift = CGPoint(x: 10 * t, y: -8 * t)                  // the hand drifts a little
    circle.append(CGPoint(x: center.x + rx * wobble * cos(ang) + drift.x,
                          y: center.y + ry * wobble * sin(ang) + drift.y))
}
taperedStroke(circle, from: 30, to: 46, color: ink)
// A short memo stroke (tick) in the top row, right side.
let tick1 = bezier(CGPoint(x: 700, y: 640), CGPoint(x: 720, y: 600), CGPoint(x: 735, y: 580), CGPoint(x: 752, y: 556), steps: 20)
let tick2 = bezier(CGPoint(x: 752, y: 556), CGPoint(x: 775, y: 610), CGPoint(x: 810, y: 680), CGPoint(x: 868, y: 740), steps: 30)
taperedStroke(tick1, from: 24, to: 34, color: ink)
taperedStroke(tick2, from: 34, to: 16, color: ink)

// 7. Write the PNG.
let image = ctx.makeImage()!
let url = URL(fileURLWithPath: out)
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("wrote \(out) \(image.width)x\(image.height) alpha=\(image.alphaInfo.rawValue)")
