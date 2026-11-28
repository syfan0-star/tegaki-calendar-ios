import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §4.1 ア, §4.2, §4.3, §4.5, §11.2 row P, §11.5 MP2; 0g-11, 0g-13, 0g-15; role P): the joined
// months' paper on the pixels, read the way the frozen PaperViewTests and MemoPaperDrawTests read the paper (the page drawn into
// a bitmap at a known zoom and scale, a pixel by paper coordinates).
//
// - A month without floors is the one page's paper (1.4.2's), pixel for pixel: alone, as a window of one page, and as a page of
//   a joined window (but for the strong line at its edges), with the ruled lines, the dots and the blank paper.
// - A month whose 6th row a floor (`gridFloor`, ア) lengthened starts its memo — the separator, the ruled lines, the dots and the
//   label 「メモ」 — at the new `memo.minY`, exactly as the natural month starts it at its own, so a memo stroke keeps its place on
//   the lines (handwriting is kept relative to the memo's origin); the lengthened 6th row keeps today's tints (the days of the
//   next month pale, today's own tint, the grid's lines down to the separator).
// - Between two joined months a strong line stands over the grid only, never in the memo band; a window of one page has none.
//
// The months: November 2026 (Monday weeks: 10/26 … 12/6, its 6th row 11/30 and the pale 12/1 … 12/6) between October and
// December; today is 12/2, a pale day of November's table. A floor of 1,283 lu lengthens the 6th row from 175 to 408 lu.

@MainActor
final class MonthPaperLineTests: XCTestCase {
    /// 2026-12-02 (a Wednesday) 10:00: today is in November's 6th row, as one of its pale days.
    private let now = DayKey(year: 2026, month: 12, day: 2).startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600)
    private let floor: CGFloat = 1_283

    private let paperColor = (0xff, 0xfd, 0xf8) // PaperPalette.paper
    private let lineColor = (0xe5, 0xe7, 0xeb) // PaperPalette.line
    private let strongColor = (0xd7, 0xda, 0xde) // PaperPalette.lineStrong
    private let ruleColor = (0xeb, 0xe7, 0xde) // PaperPalette.rule
    private let dotColor = (0xd6, 0xcf, 0xc2) // PaperPalette.memoDot

    override func tearDown() async throws {
        MemoPaperStyle.set(.ruled)
    }

    // MARK: - Layouts

    private func layout(_ month: Int, gridFloor: CGFloat = 0) -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: month), events: [], inkBottoms: [:], now: now,
                                                  gridFloor: gridFloor))
    }

    private func content(_ layout: MonthPageLayout) throws -> MonthPaperContent {
        if case .month(let content)? = PaperSpan.paperContent(of: layout) { return content }
        return try XCTUnwrap(nil as MonthPaperContent?, "a month's paper")
    }

    // MARK: - Bitmaps (MemoPaperDrawTests' reading)

    private struct Bitmap {
        var bytes: [UInt8]
        var width: Int
        var height: Int
        var originX: CGFloat = 0
        var originY: CGFloat = 0
        var pixelsPerLu: CGFloat = 1

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            guard x >= 0, y >= 0, x < width, y < height, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// The pixel at paper (x, y) lu.
        func at(_ x: CGFloat, _ y: CGFloat) -> (r: Int, g: Int, b: Int) {
            pixel(Int(((x - originX) * pixelsPerLu).rounded(.down)), Int(((y - originY) * pixelsPerLu).rounded(.down)))
        }

        /// The pixel just inside a dot's centre at paper (x, y) (MemoPaperDrawTests' `dot`).
        func dot(_ x: CGFloat, _ y: CGFloat, zoom: CGFloat, scale: CGFloat) -> (r: Int, g: Int, b: Int) {
            let sx = PaperText.snapDot(x, diameter: MemoDots.diameter, zoom: zoom, scale: scale)
            let sy = PaperText.snapDot(y, diameter: MemoDots.diameter, zoom: zoom, scale: scale)
            return pixel(Int(((sx - originX) * pixelsPerLu + 0.25).rounded(.down)), Int(((sy - originY) * pixelsPerLu + 0.25).rounded(.down)))
        }

        /// The pixels of x × y (bitmap coordinates) whose red channel is below 220 (a label's glyphs).
        func darkerPixels(x: Range<Int>, y: Range<Int>) -> Int {
            var count = 0
            for yy in y {
                for xx in x {
                    let p = pixel(xx, yy)
                    if p.r >= 0, p.r < 220 { count += 1 }
                }
            }
            return count
        }

        /// The paper y (lu) of the middle of the pixels of column `x` (paper lu) that are dark in every channel (below 120: the
        /// pen's #1f2937, not the paper's lines or label); nil without one.
        func darkMiddle(atX x: CGFloat) -> CGFloat? {
            let column = Int(((x - originX) * pixelsPerLu).rounded(.down))
            let rows = (0..<height).filter { y in
                let p = pixel(column, y)
                return p.r >= 0 && p.r < 120 && p.g < 120 && p.b < 120
            }
            guard let first = rows.first, let last = rows.last else { return nil }
            return originY + (CGFloat(first + last) / 2 + 0.5) / pixelsPerLu
        }

        /// The paper y (lu) of the first row of column `x` within `tolerance` of `colour`, from the top; nil without one.
        func firstRow(atX x: CGFloat, near colour: (Int, Int, Int), tolerance: Int) -> CGFloat? {
            let column = Int(((x - originX) * pixelsPerLu).rounded(.down))
            for y in 0..<height {
                let p = pixel(column, y)
                if abs(p.r - colour.0) <= tolerance, abs(p.g - colour.1) <= tolerance, abs(p.b - colour.2) <= tolerance {
                    return originY + (CGFloat(y) + 0.5) / pixelsPerLu
                }
            }
            return nil
        }

        static func same(_ a: Bitmap, _ b: Bitmap) -> Bool {
            a.width == b.width && a.height == b.height && a.bytes == b.bytes
        }

        /// How many pixels differ (for the failure message only).
        static func differences(_ a: Bitmap, _ b: Bitmap) -> Int {
            guard a.width == b.width, a.height == b.height else { return -1 }
            var count = 0
            for y in 0..<a.height {
                for x in 0..<a.width where a.pixel(x, y) != b.pixel(x, y) {
                    count += 1
                }
            }
            return count
        }
    }

    private func near(_ p: (r: Int, g: Int, b: Int), _ hex: (Int, Int, Int), _ tolerance: Int = 3) -> Bool {
        abs(p.r - hex.0) <= tolerance && abs(p.g - hex.1) <= tolerance && abs(p.b - hex.2) <= tolerance
    }

    private func bitmap(_ cg: CGImage) -> Bitmap {
        let width = cg.width
        let height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            // No flip: the image's top row lands in the first row of the buffer (PaperViewTests).
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return Bitmap(bytes: bytes, width: width, height: height)
    }

    /// `rect` (paper units) drawn the way `PaperView.draw` lays it: at `zoom` points per lu and `scale` pixels per point, on the
    /// paper colour, `rect` the dirty area; `view` is a paper with `memoPaper` = `style` (MemoPaperDrawTests' `render`).
    private func render(_ rect: CGRect, zoom: CGFloat = 1, scale: CGFloat = 2, style: MemoPaperStyle = .ruled, content: PaperContent,
                        _ draw: (CGContext, CGRect, CGFloat, PaperView) -> Void) throws -> Bitmap {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let view = PaperView(content: content)
        view.memoPaper = style
        view.contentScaleFactor = scale
        let size = CGSize(width: rect.width * zoom, height: rect.height * zoom)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: -rect.minX * zoom, y: -rect.minY * zoom)
            ctx.scaleBy(x: zoom, y: zoom)
            ctx.setFillColor(PaperPalette.paper.cgColor)
            ctx.fill(rect)
            draw(ctx, rect, zoom, view)
        }
        var out = bitmap(try XCTUnwrap(image.cgImage))
        out.originX = rect.minX
        out.originY = rect.minY
        out.pixelsPerLu = zoom * scale
        return out
    }

    /// `rect` of one month's paper through `MonthPaper` (the one page's renderer), with `ink` over it (`InkSnapshot`, the
    /// picture the PDF draws; the cells are the layout's).
    private func renderMonth(_ month: MonthPaperContent, _ rect: CGRect, zoom: CGFloat = 1, scale: CGFloat = 2, style: MemoPaperStyle = .ruled,
                             ink: [InkStroke] = []) throws -> Bitmap {
        try render(rect, zoom: zoom, scale: scale, style: style, content: .month(month)) { ctx, dirty, zoom, view in
            MonthPaper.draw(month, in: ctx, dirty: dirty, zoom: zoom, view: view)
            if !ink.isEmpty, let image = InkSnapshot.image(strokes: ink, cells: month.layout.cells, bounds: dirty, zoom: zoom, scale: scale) {
                image.draw(in: dirty)
            }
        }
    }

    /// `rect` of a window through `PaperView.drawSpan` (the joined paper and its boundaries).
    private func renderWindow(_ span: PaperSpan, _ rect: CGRect, zoom: CGFloat = 1, scale: CGFloat = 2, style: MemoPaperStyle = .ruled) throws -> Bitmap {
        try render(rect, zoom: zoom, scale: scale, style: style, content: span.pages[span.focus]) { ctx, dirty, zoom, view in
            PaperView.drawSpan(span, in: ctx, dirty: dirty, zoom: zoom, view: view)
        }
    }

    /// A paper view of `content` (and `span`) drawn by its own `draw`: the window around `visible` (paper lu) of a paper
    /// `paperSize` lu at `zoom`, at `scale` pixels per point.
    private func renderView(_ content: PaperContent, span: PaperSpan?, visible: CGRect, paperSize: CGSize, zoom: CGFloat, scale: CGFloat,
                            style: MemoPaperStyle) throws -> Bitmap {
        let view = PaperView(content: content)
        view.memoPaper = style
        view.span = span
        view.contentScaleFactor = scale
        view.show(visible: CGRect(x: visible.minX * zoom, y: visible.minY * zoom, width: visible.width * zoom, height: visible.height * zoom),
                  zoom: zoom, contentSize: CGSize(width: paperSize.width * zoom, height: paperSize.height * zoom))
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
            view.draw(view.bounds)
        }
        return bitmap(try XCTUnwrap(image.cgImage))
    }

    // MARK: - 1. Without floors: the one page's paper

    /// §4.1 5, §12.2: a month laid out without floors is 1.4.2's month (`==`), its window page is the one page's paper (`==`
    /// `CalendarRootScreen.makePaper`'s), and it draws the one page's pixels — alone and as a window of one page (the iPad's
    /// overview zoom 0.4758 at 2x and zoom 1 at 1x), and as the middle page of three joined months (but for the strong line
    /// along its two edges) — with the ruled lines, the dots and the blank paper.
    func testAMonthWithoutFloorsIsTheOnePagesPaper() throws {
        let natural = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now))
        XCTAssertEqual(layout(11), natural, "floors 0 are 1.4.2's month")
        XCTAssertEqual(MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: [:], now: now)
            .floored(by: .none)), natural)
        XCTAssertEqual(natural.memo.minY, 1_050)
        let onePage = CalendarRootScreen.makePaper(kind: .month, focus: DayKey(year: 2026, month: 11, day: 16), events: [], inkBottoms: [:],
                                                   now: now, holidays: .japan, weekStart: .monday)
        let page = try XCTUnwrap(PaperSpan.paperContent(of: natural))
        XCTAssertEqual(page, onePage, "the window page's paper is the one page's")
        let windowOfOne = try XCTUnwrap(PaperSpan(pages: [page], bands: [], focus: 0))
        let joined = try XCTUnwrap(PaperSpan(pages: [try XCTUnwrap(PaperSpan.paperContent(of: layout(10))), page,
                                                     try XCTUnwrap(PaperSpan.paperContent(of: layout(12)))], bands: [], focus: 1))
        guard case .month(let november) = page else { return XCTFail("a month") }

        for style in MemoPaperStyle.allCases {
            for (zoom, scale) in [(CGFloat(0.4758), CGFloat(2)), (1, 1)] {
                let visible = CGRect(x: 0, y: 0, width: 1_400, height: 1_700)
                let paper = CGSize(width: 1_400, height: 1_700)
                let alone = try renderView(onePage, span: nil, visible: visible, paperSize: paper, zoom: zoom, scale: scale, style: style)
                let window = try renderView(onePage, span: windowOfOne, visible: visible, paperSize: paper, zoom: zoom, scale: scale, style: style)
                XCTAssertTrue(Bitmap.same(alone, window),
                              "\(style) at \(zoom) × \(scale): a window of one page is the page: \(Bitmap.differences(alone, window)) pixels differ")
            }
            // The middle page of the joined window, x 1,403 … 2,797 (the strong lines at 1,400 and 2,800 are 2 lu wide at zoom 1).
            let inner = try renderWindow(joined, CGRect(x: 1_403, y: 0, width: 1_394, height: 1_700), scale: 1, style: style)
            let own = try renderMonth(november, CGRect(x: 3, y: 0, width: 1_394, height: 1_700), scale: 1, style: style)
            XCTAssertTrue(Bitmap.same(inner, own), "\(style): the joined window's page is the page: \(Bitmap.differences(inner, own)) pixels differ")
        }
    }

    // MARK: - 2. A lengthened 6th row: the memo from the new separator

    /// §4.1 ア 1, §4.2: with a floor of 1,283 lu only the 6th row grows (175 → 408 lu); the memo — its separator, its ruled lines
    /// every 50 lu, its dots, the label 「メモ」 — starts at the new `memo.minY` and is, pixel for pixel, the natural month's memo
    /// moved down (zoom 1 and 0.5 at 2x, zoom 2 at 1x), with the ruled lines, the dots and the blank paper. Where the old
    /// separator was (1,050) there is the 6th row now: no line, the grid's columns go on down to 1,283.
    func testALengthenedMonthStartsItsMemoAtTheNewSeparator() throws {
        let natural = layout(11)
        let grown = layout(11, gridFloor: floor)
        XCTAssertEqual(grown.memo.minY, floor, accuracy: 1e-9)
        XCTAssertEqual(Array(grown.rows.prefix(5).map(\.frame)), Array(natural.rows.prefix(5).map(\.frame)), "rows 1–5 stay")
        XCTAssertEqual(grown.rows[5].frame.minY, 875, accuracy: 1e-9)
        XCTAssertEqual(grown.rows[5].frame.height, floor - 875, accuracy: 1e-9)
        XCTAssertEqual(grown.memo.height, natural.memo.height, "the memo is as tall")
        XCTAssertEqual(grown.cells[.memo], grown.memo)
        let naturalContent = try content(natural)
        let grownContent = try content(grown)

        for style in MemoPaperStyle.allCases {
            for (zoom, scale) in [(CGFloat(1), CGFloat(2)), (0.5, 2), (2, 1)] {
                let before = try renderMonth(naturalContent, CGRect(x: 0, y: natural.memo.minY, width: 1_400, height: 600), zoom: zoom, scale: scale, style: style)
                let after = try renderMonth(grownContent, CGRect(x: 0, y: grown.memo.minY, width: 1_400, height: 600), zoom: zoom, scale: scale, style: style)
                XCTAssertTrue(Bitmap.same(before, after),
                              "\(style) at \(zoom) × \(scale): the memo moved down whole: \(Bitmap.differences(before, after)) pixels differ")
            }
            let around = try renderMonth(grownContent, CGRect(x: 0, y: 1_000, width: 1_400, height: 600), style: style)
            XCTAssertTrue(near(around.at(500, floor), strongColor, 6), "\(style): the separator at 1,283: \(around.at(500, floor))")
            XCTAssertTrue(near(around.at(100, 1_050), paperColor), "\(style): no line at the old separator (11/30): \(around.at(100, 1_050))")
            XCTAssertTrue(near(around.at(200, 1_200), lineColor, 6), "\(style): the grid's column line down the 6th row: \(around.at(200, 1_200))")
            for k in 1...5 {
                let y = floor + CGFloat(k) * 50
                switch style {
                case .ruled:
                    XCTAssertTrue(near(around.at(700, y), ruleColor, 4), "a ruled line at \(y): \(around.at(700, y))")
                case .dots:
                    for x in [CGFloat(30), 680, 1_380] {
                        XCTAssertTrue(near(around.dot(x, y, zoom: 1, scale: 2), dotColor), "a dot at (\(x), \(y)): \(around.dot(x, y, zoom: 1, scale: 2))")
                    }
                    XCTAssertTrue(near(around.at(705, y), paperColor), "between two dots at \(y)")
                case .plain:
                    XCTAssertTrue(near(around.at(700, y), paperColor), "blank at \(y): \(around.at(700, y))")
                }
                XCTAssertTrue(near(around.at(700, y - 25), paperColor), "\(style): between two rows at \(y - 25)")
            }
            // The label 「メモ」 at (20, 1,289) (1 lu = 1 px).
            let label = try renderMonth(grownContent, CGRect(x: 0, y: floor, width: 300, height: 40), scale: 1, style: style)
            XCTAssertGreaterThan(label.darkerPixels(x: 20..<110, y: 6..<26), 20, "\(style): the label 「メモ」 under the new separator")
            XCTAssertEqual(L.text("paper.memo"), "メモ")
        }
    }

    /// §4.1 ア 1, K-4: a memo stroke is kept relative to the memo's origin (`cells[.memo]`), so on the lengthened month it is
    /// drawn as far below the separator and as far from the ruled lines as on the natural month — 137 lu under the separator,
    /// 37 lu under the first ruled line — never between other lines.
    func testAMemoStrokeKeepsItsPlaceOnTheRuledLines() throws {
        let points = (0..<20).map { i in
            InkPoint(x: 400 + CGFloat(i) * 25, y: 137, dtMs: i * 10, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = InkStroke(id: "memo-line", cell: .memo, tool: .pen, color: "#1f2937", t: 1_791_000_000_001, points: points)
        var measured: [(stroke: CGFloat, rule: CGFloat, separator: CGFloat)] = []
        for month in [layout(11), layout(11, gridFloor: floor)] {
            let rect = CGRect(x: 0, y: month.memo.minY - 20, width: 1_400, height: 320)
            let drawn = try renderMonth(try content(month), rect, ink: [stroke])
            let line = try XCTUnwrap(drawn.darkMiddle(atX: 650), "the stroke at x 650 below \(month.memo.minY)")
            let rule = try XCTUnwrap(drawn.firstRow(atX: 1_250, near: ruleColor, tolerance: 4), "the first ruled line")
            let separator = try XCTUnwrap(drawn.firstRow(atX: 1_250, near: strongColor, tolerance: 6), "the separator")
            XCTAssertEqual(line - month.memo.minY, 137, accuracy: 1, "the stroke 137 lu under the separator")
            XCTAssertEqual(rule - month.memo.minY, 50, accuracy: 1, "the first ruled line 50 lu under it")
            XCTAssertEqual(separator, month.memo.minY, accuracy: 1)
            measured.append((line, rule, separator))
        }
        XCTAssertEqual(measured.count, 2)
        XCTAssertEqual(measured[1].stroke - measured[1].rule, measured[0].stroke - measured[0].rule, accuracy: 0.5,
                       "the stroke and the ruled lines keep their distance")
        XCTAssertEqual(measured[1].stroke - measured[1].separator, measured[0].stroke - measured[0].separator, accuracy: 0.5)
        XCTAssertEqual(measured[1].stroke - measured[0].stroke, floor - 1_050, accuracy: 0.5, "the stroke moved with the memo")
    }

    /// §4.1 ア 2, §4.5: the lengthened 6th row keeps today's drawing over its whole height: the pale days of the next month in
    /// `outTint` (12/1, Saturday 12/5), today's tint on 12/2 (a pale day: today wins), the paper on November's own 11/30, and the
    /// grid's column lines — the very colours the natural 6th row has.
    func testTheLengthenedSixthRowKeepsItsTints() throws {
        let natural = layout(11)
        let grown = layout(11, gridFloor: floor)
        let today = DayKey(year: 2026, month: 12, day: 2)
        XCTAssertEqual(grown.dateLabels.first { $0.day == today }?.isToday, true)
        XCTAssertEqual(grown.dateLabels.first { $0.day == today }?.inMonth, false)
        XCTAssertEqual(grown.cells[.day(today)]?.height ?? 0, floor - 875, accuracy: 1e-9, "the cell is the lengthened row")
        let before = try renderMonth(try content(natural), CGRect(x: 0, y: 860, width: 1_400, height: 200), scale: 1)
        // 860 … 1,320: past the separator (1,283) to the memo sample at floor + 20 (1,303), which 440 lu (to 1,300) left out.
        let after = try renderMonth(try content(grown), CGRect(x: 0, y: 860, width: 1_400, height: 460), scale: 1)
        let outTint = before.at(300, 1_000) // 12/1, pale
        let todayTint = before.at(500, 1_000) // 12/2, today
        XCTAssertFalse(near(outTint, paperColor, 2), "the pale day is tinted: \(outTint)")
        XCTAssertNotEqual(outTint.b, todayTint.b, "today's tint is not the pale one")
        for y in [CGFloat(1_000), 1_150, 1_270] {
            XCTAssertEqual(after.at(300, y).r, outTint.r, "12/1 at \(y)")
            XCTAssertEqual(after.at(300, y).g, outTint.g)
            XCTAssertEqual(after.at(300, y).b, outTint.b)
            XCTAssertEqual(after.at(1_100, y).b, outTint.b, "Saturday 12/5, pale, at \(y)")
            XCTAssertEqual(after.at(500, y).r, todayTint.r, "today 12/2 at \(y)")
            XCTAssertEqual(after.at(500, y).b, todayTint.b)
            XCTAssertTrue(near(after.at(100, y), paperColor), "11/30 at \(y): \(after.at(100, y))")
            XCTAssertTrue(near(after.at(200, y), lineColor, 6), "the column line at \(y): \(after.at(200, y))")
        }
        XCTAssertTrue(near(after.at(300, floor + 20), paperColor), "the memo below: \(after.at(300, floor + 20))")
    }

    // MARK: - 3. The strong line between two months (MP2)

    /// MP2, §4.3, 0g-13: between two joined months a strong line (`lineStrong`, 2 pt) stands from the top of the grid down to the
    /// separator — over the lengthened 6th row too — and stops there: the memo band runs on as one (paper at the boundary between
    /// the ruled lines, the dots and the label rows). Two months whose separators differ (ウ) have it down to the higher one. A
    /// window of one page has none: its pixels are the page's.
    func testTheBoundaryIsInTheGridOnlyAndAWindowOfOnePageHasNone() throws {
        let pages = try [10, 11, 12].map { try XCTUnwrap(PaperSpan.paperContent(of: layout($0, gridFloor: floor))) }
        let joined = try XCTUnwrap(PaperSpan(pages: pages, bands: [], focus: 1))
        let lines = PaperView.monthBoundaries(of: joined)
        XCTAssertEqual(lines.map(\.x), [1_400, 2_800])
        XCTAssertEqual(lines.map(\.top), [0, 0])
        for line in lines {
            XCTAssertEqual(line.bottom, floor, accuracy: 1e-9, "down to the separator, not into the memo")
        }
        let uneven = try XCTUnwrap(PaperSpan(pages: [try XCTUnwrap(PaperSpan.paperContent(of: layout(10))), pages[1]], bands: [], focus: 1))
        XCTAssertEqual(PaperView.monthBoundaries(of: uneven).map(\.bottom), [1_050], "the higher separator (ウ)")
        XCTAssertEqual(PaperView.monthBoundaries(of: try XCTUnwrap(PaperSpan(pages: [pages[1]], bands: [], focus: 0))).count, 0)

        for style in MemoPaperStyle.allCases {
            // Down to 2,400 lu: the floored memo is 1,283 … 7,283 (6,000 lu tall), and the deepest sample below is floor + 1,000
            // (2,283), which a picture 1,700 lu tall left out (`pixel` gives (-1, -1, -1) outside the bitmap).
            let drawn = try renderWindow(joined, CGRect(x: 1_300, y: 0, width: 200, height: 2_400), style: style)
            for y in [CGFloat(100), 600, 1_000, 1_270] {
                XCTAssertTrue(near(drawn.at(1_400, y), strongColor, 6), "\(style): the strong line at (1,400, \(y)): \(drawn.at(1_400, y))")
            }
            for y in [floor + 3, floor + 25, floor + 50, floor + 75, floor + 100, floor + 1_000] {
                XCTAssertTrue(near(drawn.at(1_400, y), paperColor), "\(style): no line in the memo band at \(y): \(drawn.at(1_400, y))")
            }
            XCTAssertTrue(near(drawn.at(1_360, floor + 25), paperColor), "\(style): the memo band beside it")
        }

        // A window of one page: the page's own pixels (no line at its edges).
        let one = try XCTUnwrap(PaperSpan(pages: [pages[1]], bands: [], focus: 0))
        let visible = CGRect(x: 0, y: 0, width: 1_400, height: 1_700)
        let paper = CGSize(width: 1_400, height: 1_700)
        let alone = try renderView(pages[1], span: nil, visible: visible, paperSize: paper, zoom: 1, scale: 1, style: .ruled)
        let window = try renderView(pages[1], span: one, visible: visible, paperSize: paper, zoom: 1, scale: 1, style: .ruled)
        XCTAssertTrue(Bitmap.same(alone, window), "a window of one page: \(Bitmap.differences(alone, window)) pixels differ")
    }
}
