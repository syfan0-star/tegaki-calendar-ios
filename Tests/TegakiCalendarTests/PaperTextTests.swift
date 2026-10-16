import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the paper's text helpers (M4B_CONTRACT §4.1, §7.2; M4C_CONTRACT §3.1, §7.2):
/// the time-label size is capped by the gutter's width, below the readable zoom the text keeps its
/// readable size in lu and shrinks with the paper (D3 / M4C-3), and `drawLine` / `drawLines` never
/// paint outside their rect (D4: text never leaves its bar, chip or box).
@MainActor
final class PaperTextTests: XCTestCase {
    // MARK: Font size below the readable zoom (M4c)

    func testFontSizeBelowReadableIsFrozen() {
        let readable = ZoomPolicy.readableZoom(.month) // 0.5
        // At the readable zoom the M4b rule gives 10 pt / 0.5 = 20 lu for a month chip …
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.5, readable: readable), 20, accuracy: 0.001)
        // … and below it those 20 lu are frozen: on screen the text shrinks with the paper, no floor.
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.49, readable: readable), 20, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.2871, readable: readable), 20, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.2871, readable: readable) * 0.2871, 5.74, accuracy: 0.01, "the iPhone's overview: 5.74 pt")
        // Above it the M4b rule: 10 pt / 0.7314 = 13.67 lu (the 13-inch month).
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.7314, readable: readable), 10 / 0.7314, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.7314, readable: readable), 13.67, accuracy: 0.01)
        // readable 0 (the default) is the M4b rule itself: 10 / 0.3 = 33.3 lu.
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.3), 10 / 0.3, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.monthChip, zoom: 0.3, readable: 0), 33.3, accuracy: 0.05)
        // The frozen sizes of §3.1: monthDate 24, monthHoliday 18, weekEvent 21.2, dayEvent 19.6; the
        // year's lu are above its minimum points at readable 1.339, so they stay 22 / 15 / 13 / 11.
        XCTAssertEqual(PaperText.fontSize(PaperText.monthDate, zoom: 0.1, readable: readable), 24, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.monthHoliday, zoom: 0.1, readable: readable), 18, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.weekEvent, zoom: 0.1, readable: ZoomPolicy.readableZoom(.week)), 21.2, accuracy: 0.01)
        XCTAssertEqual(PaperText.fontSize(PaperText.dayEvent, zoom: 0.1, readable: ZoomPolicy.readableZoom(.day)), 19.6, accuracy: 0.01)
        XCTAssertEqual(PaperText.fontSize(PaperText.yearDayNum, zoom: 0.5, readable: ZoomPolicy.readableZoom(.year)), 22, accuracy: 0.001)
        XCTAssertEqual(PaperText.fontSize(PaperText.yearChip, zoom: 0.5, readable: ZoomPolicy.readableZoom(.year)), 13, accuracy: 0.001)
        // Gutter labels: the frozen size is capped by the gutter the same way — the week's 21.2 lu →
        // 19.31 (the cap), the day's 18.7 lu stays under 22.07.
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.2871, gutter: PaperSpec.weekGutter, readable: ZoomPolicy.readableZoom(.week)), 19.31, accuracy: 0.01)
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.dayTimeLabel, zoom: 0.2313, gutter: PaperSpec.dayGutter, readable: ZoomPolicy.readableZoom(.day)), 18.7, accuracy: 0.05)
    }

    // MARK: Gutter label size

    func testGutterLabelSizeIsCappedByTheGutter() {
        // Week at the iPhone's minimum zoom: 10 / 0.4716 = 21.2 lu would exceed the cap
        // (64 − 8) / 2.9 = 19.31 lu (= 9.1 pt, so "10:00" at 2.705 em fits the 26.4 pt label).
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.4716, gutter: PaperSpec.weekGutter), (64 - 8) / 2.9, accuracy: 0.001)
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.4716, gutter: PaperSpec.weekGutter), 19.31, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.4716, gutter: PaperSpec.weekGutter) * 0.4716, 9, "never under 9 pt (D4)")
        // Below the minimum (the pinch's bounce): the same cap.
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.3, gutter: PaperSpec.weekGutter), 19.31, accuracy: 0.01)
        // The iPad mini's week (0.5314): 10 pt = 18.8 lu, under the cap.
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.5314, gutter: PaperSpec.weekGutter), 10 / 0.5314, accuracy: 0.01)
        // Day at the iPhone's minimum zoom: 10.5 / 0.5612 = 18.7 lu, under (72 − 8) / 2.9 = 22.07.
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.dayTimeLabel, zoom: 0.5612, gutter: PaperSpec.dayGutter), 10.5 / 0.5612, accuracy: 0.01)
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.dayTimeLabel, zoom: 0.5612, gutter: PaperSpec.dayGutter), 18.7, accuracy: 0.05)
        // At zoom 1 the lu size itself (the minimum points do not bite).
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 1, gutter: PaperSpec.weekGutter), 12, accuracy: 0.001)
        // No gutter → nothing (never negative).
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.weekTimeLabel, zoom: 0.4716, gutter: 0), 0)
        XCTAssertEqual(PaperText.gutterLabelSize(PaperText.dayTimeLabel, zoom: 0.5, gutter: 8), 0)
    }

    // MARK: Clipping

    private static let canvasSize = 100

    /// Draws into an opaque white 100 × 100 bitmap (scale 1) and returns its RGBA bytes, row 0 at
    /// the top.
    private func render(_ draw: (CGContext) -> Void) -> [UInt8] {
        let size = Self.canvasSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            draw(context.cgContext)
        }
        guard let cg = image.cgImage else { return [] }
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            // No flip: a CGImage drawn into a bitmap context lands with its first (top) row in the
            // first row of the buffer, so row 0 of `bytes` is already the top of the image. (The first
            // CI run flipped here and read the text at y ≈ 80 instead of 10.)
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        return bytes
    }

    /// True when the pixel is (still) the white background.
    private func isBackground(_ bytes: [UInt8], x: Int, y: Int) -> Bool {
        let i = (y * Self.canvasSize + x) * 4
        guard i + 2 < bytes.count else { return false }
        return bytes[i] >= 250 && bytes[i + 1] >= 250 && bytes[i + 2] >= 250
    }

    /// True when some pixel inside `rect` is not the background.
    private func hasInk(_ bytes: [UInt8], in rect: CGRect) -> Bool {
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) where !isBackground(bytes, x: x, y: y) {
                return true
            }
        }
        return false
    }

    func testDrawLineIsClippedToItsRect() {
        let rect = CGRect(x: 10, y: 10, width: 20, height: 10)
        let font = UIFont.systemFont(ofSize: 20, weight: .bold)
        let bytes = render { _ in
            // 20 pt tall letters in a 10 pt tall, 20 pt wide rect: without the clip the glyphs would
            // reach from y ≈ 3 to y ≈ 27 and, with the ellipsis, past x = 30.
            PaperText.drawLine("IIIIIIIIIIIIIIIIIIII", in: rect, font: font, color: .black)
        }
        XCTAssertEqual(bytes.count, Self.canvasSize * Self.canvasSize * 4)
        XCTAssertTrue(hasInk(bytes, in: rect), "the text is drawn inside the rect")
        XCTAssertTrue(isBackground(bytes, x: 5, y: 15), "nothing left of the rect")
        XCTAssertTrue(isBackground(bytes, x: 15, y: 25), "nothing below the rect")
        XCTAssertTrue(isBackground(bytes, x: 15, y: 5), "nothing above the rect")
        XCTAssertTrue(isBackground(bytes, x: 35, y: 15), "nothing right of the rect")
        // The whole outside, pixel by pixel.
        for y in 0..<Self.canvasSize {
            for x in 0..<Self.canvasSize where !rect.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) {
                XCTAssertTrue(isBackground(bytes, x: x, y: y), "pixel (\(x), \(y)) must stay white")
                if !isBackground(bytes, x: x, y: y) { return }
            }
        }
    }

    func testDrawLinesIsClippedToItsBox() {
        // A 60 pt tall rect but at most 2 lines of 12 pt: the box is (10, 10, 40, 24).
        let rect = CGRect(x: 10, y: 10, width: 40, height: 60)
        let box = CGRect(x: 10, y: 10, width: 40, height: 24)
        let font = UIFont.systemFont(ofSize: 16, weight: .bold)
        let bytes = render { _ in
            PaperText.drawLines("IIIIII IIIIII IIIIII IIIIII IIIIII IIIIII", in: rect, font: font, color: .black, maxLines: 2, lineHeight: 12)
        }
        XCTAssertTrue(hasInk(bytes, in: box), "the text is drawn inside the box")
        XCTAssertTrue(isBackground(bytes, x: 15, y: 40), "nothing below the box (inside the rect)")
        XCTAssertTrue(isBackground(bytes, x: 15, y: 55), "nothing further below")
        XCTAssertTrue(isBackground(bytes, x: 55, y: 15), "nothing right of the box")
        XCTAssertTrue(isBackground(bytes, x: 5, y: 15), "nothing left of the box")
        XCTAssertTrue(isBackground(bytes, x: 15, y: 5), "nothing above the box")
        for y in 0..<Self.canvasSize {
            for x in 0..<Self.canvasSize where !box.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)) {
                XCTAssertTrue(isBackground(bytes, x: x, y: y), "pixel (\(x), \(y)) must stay white")
                if !isBackground(bytes, x: x, y: y) { return }
            }
        }
    }

    func testDrawLineWithoutAContextDrawsNothingAndDoesNotCrash() {
        // No current graphics context: the clip is skipped and nothing is drawn.
        PaperText.drawLine("x", in: CGRect(x: 0, y: 0, width: 10, height: 10), font: UIFont.systemFont(ofSize: 10), color: .black)
        PaperText.drawLines("x", in: CGRect(x: 0, y: 0, width: 10, height: 10), font: UIFont.systemFont(ofSize: 10), color: .black, maxLines: 1)
    }
}
