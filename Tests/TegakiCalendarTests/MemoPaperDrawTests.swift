import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.3–§4.6, §6.1, 0f-21–0f-23): the three patterns of the memo paper on the pixels, read the
/// way the frozen PaperViewTests and WeekMemoPaperSpanTests read them (the page drawn into a bitmap, a pixel by paper
/// coordinates). Every memo area — the month's memo, the day's right column 「メモ」, the day's and the week's free memo — is
/// drawn through its page's renderer with the pattern set on the `PaperView` it draws for (the week through `WeekPaper` on a
/// week's `PaperView`, never `FreeMemoPaper.draw` directly: mutation MM5).
///
/// - Ruled: the very pixels of 1.4.1 (`Frozen141Memo`, a copy of 2e3ee75's memo drawing) at the iPhone's overview, the iPad's,
///   1 and 2 (mutation MM1: dots on the ruled paper fail here).
/// - Dots: a dot's centre on every row of the ruled lines and every column x = 30 + 50k inside the area (the month 30…1,380,
///   the day's right column 680…980, the free memo 30…980 / 30…1,380), the paper between two dots, nothing outside the area;
///   on joined days the columns go on 50 lu apart across the boundary (980 → 1,030); the PDF has them.
/// - Blank: the paper where the ruled lines were; the separator and the label stay.
/// The PDF's bytes for the three patterns and the time of the worst window are logged (`memo dots:`), not judged (§4.6).
@MainActor
final class MemoPaperDrawTests: XCTestCase {
    /// 2026-10-07, a Wednesday, 10:00: the day pages drawn are not today (no now line over the right column).
    private let today = DayKey(year: 2026, month: 10, day: 7)
    private var now: Date { today.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600) }
    private let monday = DayKey(year: 2026, month: 10, day: 5)

    private let paperColor = (0xff, 0xfd, 0xf8) // PaperPalette.paper
    private let dotColor = (0xd6, 0xcf, 0xc2) // PaperPalette.memoDot
    private let ruleColor = (0xeb, 0xe7, 0xde) // PaperPalette.rule
    private let strongColor = (0xd7, 0xda, 0xde) // PaperPalette.lineStrong

    override func tearDown() async throws {
        MemoPaperStyle.set(.ruled)
    }

    // MARK: - Layouts

    private func monthLayout() -> MonthPageLayout {
        MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 10), events: [], inkBottoms: [:], now: now))
    }

    private func monthContent() -> MonthPaperContent {
        let layout = monthLayout()
        return MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: [:])
    }

    private func dayLayout(_ day: DayKey) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: [:], now: now))
    }

    private func weekLayout(_ first: DayKey) -> WeekPageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(focus: first, events: [], inkBottoms: [:], now: now, weekStart: .monday, extraFloor: 0, freeMemo: true))
    }

    // MARK: - Bitmaps

    /// RGBA bytes, row 0 at the top, with the paper point of its pixel (0, 0) and the pixels per lu.
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

        /// The pixel just inside a dot's centre at paper (x, y): the dot is an even number of pixels wide, so its centre
        /// (`PaperText.snapDot`) lies between four pixels; this is the one right of and below it.
        func dot(_ x: CGFloat, _ y: CGFloat, zoom: CGFloat, scale: CGFloat) -> (r: Int, g: Int, b: Int) {
            let sx = PaperText.snapDot(x, diameter: MemoDots.diameter, zoom: zoom, scale: scale)
            let sy = PaperText.snapDot(y, diameter: MemoDots.diameter, zoom: zoom, scale: scale)
            return pixel(Int(((sx - originX) * pixelsPerLu + 0.25).rounded(.down)), Int(((sy - originY) * pixelsPerLu + 0.25).rounded(.down)))
        }

        /// The pixels of x × y (bitmap coordinates) whose red channel is below `threshold` (a label's glyphs).
        func darkerPixels(x: Range<Int>, y: Range<Int>, threshold: Int = 220) -> Int {
            var count = 0
            for yy in y {
                for xx in x {
                    let p = pixel(xx, yy)
                    if p.r >= 0, p.r < threshold { count += 1 }
                }
            }
            return count
        }

        /// The pixels of rows `rows` (all when nil) within `tolerance` of `colour`.
        func count(near colour: (Int, Int, Int), tolerance: Int, rows: Range<Int>? = nil) -> Int {
            var count = 0
            for yy in rows ?? 0..<height {
                for xx in 0..<width {
                    let p = pixel(xx, yy)
                    if abs(p.r - colour.0) <= tolerance, abs(p.g - colour.1) <= tolerance, abs(p.b - colour.2) <= tolerance { count += 1 }
                }
            }
            return count
        }

        /// Are the two bitmaps (same size) byte for byte the same?
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

        /// Do the columns x < `maxX` (paper lu) of the two bitmaps agree?
        static func sameLeft(_ a: Bitmap, _ b: Bitmap, below maxX: CGFloat) -> Bool {
            guard a.width == b.width, a.height == b.height else { return false }
            let columns = min(a.width, Int(((maxX - a.originX) * a.pixelsPerLu).rounded(.down)))
            for y in 0..<a.height {
                for x in 0..<columns where a.pixel(x, y) != b.pixel(x, y) {
                    return false
                }
            }
            return true
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

    /// `rect` (paper units) of a page drawn the way `PaperView.draw` lays it: at `zoom` points per lu and `scale` pixels per
    /// point, on the paper colour, `rect` the dirty area; `view` is a paper of `content` with `memoPaper` = `style`.
    private func render(_ rect: CGRect, zoom: CGFloat, scale: CGFloat, content: PaperContent, style: MemoPaperStyle,
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

    private func renderMonth(_ content: MonthPaperContent, rect: CGRect, style: MemoPaperStyle, zoom: CGFloat = 1, scale: CGFloat = 2) throws -> Bitmap {
        try render(rect, zoom: zoom, scale: scale, content: .month(content), style: style) { ctx, dirty, zoom, view in
            MonthPaper.draw(content, in: ctx, dirty: dirty, zoom: zoom, view: view)
        }
    }

    private func renderDay(_ layout: DayPageLayout, rect: CGRect, style: MemoPaperStyle, zoom: CGFloat = 1, scale: CGFloat = 2) throws -> Bitmap {
        try render(rect, zoom: zoom, scale: scale, content: .day(DayPaperContent(layout: layout)), style: style) { ctx, dirty, zoom, view in
            DayPaper.draw(DayPaperContent(layout: layout), in: ctx, dirty: dirty, zoom: zoom, view: view)
        }
    }

    /// The week through its own `PaperView` (the week's content, its `draw`, so `WeekPaper` and its memo's call run as on the
    /// screen), the window around `visible` at `zoom`, drawn at `scale` pixels per point.
    private func renderWeek(_ layout: WeekPageLayout, visible: CGRect, style: MemoPaperStyle, scale: CGFloat = 2) throws -> Bitmap {
        let view = PaperView(content: .week(WeekPaperContent(layout: layout)))
        view.memoPaper = style
        view.contentScaleFactor = scale
        view.show(visible: visible, zoom: 1, contentSize: layout.size)
        return try render(view, scale: scale)
    }

    /// The paper view's window drawn by its own `draw` at `scale` pixels per point (zoom 1: pixels per lu = `scale`).
    private func render(_ view: PaperView, scale: CGFloat) throws -> Bitmap {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
            view.draw(view.bounds)
        }
        var out = bitmap(try XCTUnwrap(image.cgImage))
        out.originX = view.contentWindow.minX
        out.originY = view.contentWindow.minY
        out.pixelsPerLu = scale
        return out
    }

    /// The first page of a PDF at `scale` pixels per point, row 0 at the top.
    private func render(pdf data: Data, scale: CGFloat) throws -> Bitmap {
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let document = try XCTUnwrap(CGPDFDocument(provider))
        let page = try XCTUnwrap(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        let width = Int((box.width * scale).rounded(.up))
        let height = Int((box.height * scale).rounded(.up))
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            // The first row of the buffer is the bitmap context's top: the PDF's top (no flip needed).
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -box.minX, y: -box.minY)
            ctx.drawPDFPage(page)
        }
        return Bitmap(bytes: bytes, width: width, height: height, pixelsPerLu: scale)
    }

    private func log(_ line: String) {
        print("memo dots: \(line)")
        NSLog("memo dots: %@", line)
    }

    // MARK: - 1. The ruled paper is 1.4.1's

    /// The zooms of the frozen paper tests: the iPhone's overview (3x), the iPad's (2x), 1 and 2.
    private let zooms: [(zoom: CGFloat, scale: CGFloat)] = [(0.2679, 3), (0.4758, 2), (1, 2), (2, 1)]

    /// The ruled pattern draws, in every memo area, exactly what 2e3ee75 (1.4.1) drew: the month's memo, the day's right
    /// column, the day's free memo and the week's (the rest of each page is not in these rectangles).
    func testRuledIsTheOldPaperPixelForPixel() throws {
        let month = monthContent()
        let memo = month.layout.memo
        let day = dayLayout(DayKey(year: 2026, month: 10, day: 8))
        let week = weekLayout(monday)
        XCTAssertEqual(day.memo.minX, 660)
        XCTAssertEqual(week.extra, CGRect(x: 0, y: 1920, width: 1400, height: 6000))
        for (zoom, scale) in zooms {
            let monthRect = CGRect(x: 0, y: memo.minY, width: 1400, height: 600)
            let app = try renderMonth(month, rect: monthRect, style: .ruled, zoom: zoom, scale: scale)
            let old = try render(monthRect, zoom: zoom, scale: scale, content: .month(month), style: .ruled) { ctx, dirty, zoom, view in
                Frozen141Memo.monthMemoArea(ctx, layout: month.layout, dirty: dirty, zoom: zoom, scale: view.contentScaleFactor)
            }
            XCTAssertTrue(Bitmap.same(app, old), "month at \(zoom) × \(scale): \(Bitmap.differences(app, old)) pixels differ from 1.4.1's")

            // The right column only (x ≥ 662: right of the timeline's line), above 24:00.
            let columnRect = CGRect(x: 662, y: 0, width: 338, height: 2390)
            let appColumn = try renderDay(day, rect: columnRect, style: .ruled, zoom: zoom, scale: scale)
            let oldColumn = try render(columnRect, zoom: zoom, scale: scale, content: .day(DayPaperContent(layout: day)), style: .ruled) { ctx, dirty, zoom, view in
                Frozen141Memo.dayMemoColumn(ctx, layout: day, dirty: dirty, zoom: zoom, scale: view.contentScaleFactor)
            }
            XCTAssertTrue(Bitmap.same(appColumn, oldColumn), "day's column at \(zoom) × \(scale): \(Bitmap.differences(appColumn, oldColumn)) pixels differ")

            let freeRect = CGRect(x: 0, y: 2400, width: 1000, height: 600)
            let appFree = try renderDay(day, rect: freeRect, style: .ruled, zoom: zoom, scale: scale)
            let oldFree = try render(freeRect, zoom: zoom, scale: scale, content: .day(DayPaperContent(layout: day)), style: .ruled) { ctx, dirty, zoom, view in
                Frozen141Memo.freeMemo(ctx, area: day.extra, dirty: dirty, zoom: zoom, scale: view.contentScaleFactor,
                                       readable: ZoomPolicy.readableZoom(.day))
            }
            XCTAssertTrue(Bitmap.same(appFree, oldFree), "day's free memo at \(zoom) × \(scale): \(Bitmap.differences(appFree, oldFree)) pixels differ")

            let weekRect = CGRect(x: 0, y: 1920, width: 1400, height: 600)
            let appWeek = try render(weekRect, zoom: zoom, scale: scale, content: .week(WeekPaperContent(layout: week)), style: .ruled) { ctx, dirty, zoom, view in
                WeekPaper.draw(WeekPaperContent(layout: week), in: ctx, dirty: dirty, zoom: zoom, view: view)
            }
            let oldWeek = try render(weekRect, zoom: zoom, scale: scale, content: .week(WeekPaperContent(layout: week)), style: .ruled) { ctx, dirty, zoom, view in
                Frozen141Memo.freeMemo(ctx, area: week.extra, dirty: dirty, zoom: zoom, scale: view.contentScaleFactor,
                                       readable: ZoomPolicy.readableZoom(.week))
            }
            XCTAssertTrue(Bitmap.same(appWeek, oldWeek), "week's memo at \(zoom) × \(scale): \(Bitmap.differences(appWeek, oldWeek)) pixels differ")
        }
    }

    /// A paper made without a pattern takes `MemoPaperStyle.current` (ruled in the tests), so the frozen tests' papers are ruled.
    func testAPaperStartsWithThePatternInForce() {
        XCTAssertEqual(PaperView(content: .month(monthContent())).memoPaper, .ruled)
        MemoPaperStyle.current = .plain
        XCTAssertEqual(PaperView(content: .month(monthContent())).memoPaper, .plain)
        MemoPaperStyle.current = .ruled
    }

    // MARK: - 2. Dots

    /// The month's memo with dots, 1 lu = 2 px: a dot at x = 30 + 50k (k = 0…27) on every row of the ruled lines, the paper
    /// between two dots and between two rows, and no dot left of 20 or right of 1,380; above the separator the page is the
    /// ruled page's.
    func testMonthDots() throws {
        let month = monthContent()
        let memo = month.layout.memo
        XCTAssertEqual(memo.height, 6000, "the memo is open to 6,000 lu (1.1.1)")
        XCTAssertEqual(MemoDots.columns(left: 0, right: 1400, inset: 20), stride(from: CGFloat(30), through: 1380, by: 50).map { $0 })
        XCTAssertEqual(MemoDots.columns(left: 0, right: 1400, inset: 20).count, 28)
        let rect = CGRect(x: 0, y: memo.minY - 40, width: 1400, height: 340)
        let dots = try renderMonth(month, rect: rect, style: .dots)
        for row in 1...5 {
            let y = memo.minY + CGFloat(row) * 50
            for x in stride(from: CGFloat(30), through: 1380, by: 50) {
                XCTAssertTrue(near(dots.dot(x, y, zoom: 1, scale: 2), dotColor), "a dot at (\(x), \(y)): \(dots.dot(x, y, zoom: 1, scale: 2))")
                if x < 1380 {
                    XCTAssertTrue(near(dots.at(x + 25, y), paperColor), "between two dots at (\(x + 25), \(y)): \(dots.at(x + 25, y))")
                }
            }
            XCTAssertTrue(near(dots.at(10, y), paperColor), "nothing left of the inset at \(y)")
            XCTAssertTrue(near(dots.at(1395, y), paperColor), "nothing right of the inset at \(y)")
            XCTAssertTrue(near(dots.at(530, y - 25), paperColor), "between two rows at \(y - 25)")
            XCTAssertTrue(near(dots.at(700, y), paperColor), "no ruled line at \(y): \(dots.at(700, y))")
        }
        XCTAssertTrue(near(dots.at(500, memo.minY), strongColor, 6), "the separator stays: \(dots.at(500, memo.minY))")
        // Above the separator (the grid's last row) the dots page is the ruled page.
        let ruled = try renderMonth(month, rect: CGRect(x: 0, y: memo.minY - 40, width: 1400, height: 39), style: .ruled)
        let dotsAbove = try renderMonth(month, rect: CGRect(x: 0, y: memo.minY - 40, width: 1400, height: 39), style: .dots)
        XCTAssertTrue(Bitmap.same(ruled, dotsAbove), "the grid above the memo does not change: \(Bitmap.differences(ruled, dotsAbove))")
        // The label 「メモ」 stays (1 lu = 1 px).
        let labels = try renderMonth(month, rect: CGRect(x: 0, y: memo.minY, width: 300, height: 40), style: .dots, scale: 1)
        XCTAssertGreaterThan(labels.darkerPixels(x: 20..<110, y: 6..<26), 20, "the label 「メモ」")
    }

    /// The day with dots: the right column's dots at 680…980 (7) on the rows of the half hours above 24:00, the free memo's at
    /// 30…980 (20) below it, the right column's columns above the free memo's; left of the right column the page is the ruled
    /// page's (the timeline does not change).
    func testDayDots() throws {
        let day = dayLayout(DayKey(year: 2026, month: 10, day: 8))
        XCTAssertEqual(MemoDots.columns(left: day.memo.minX, right: day.memo.maxX, inset: 20), [680, 730, 780, 830, 880, 930, 980])
        XCTAssertEqual(MemoDots.columns(left: 0, right: 1000, inset: 20).count, 20)
        let rect = CGRect(x: 0, y: 2200, width: 1000, height: 400)
        let dots = try renderDay(day, rect: rect, style: .dots)
        let ruled = try renderDay(day, rect: rect, style: .ruled)
        for y: CGFloat in [2250, 2300, 2350] {
            for x: CGFloat in [680, 730, 830, 980] {
                XCTAssertTrue(near(dots.dot(x, y, zoom: 1, scale: 2), dotColor), "the right column's dot at (\(x), \(y)): \(dots.dot(x, y, zoom: 1, scale: 2))")
            }
            XCTAssertTrue(near(dots.at(705, y), paperColor), "between two dots at (705, \(y))")
            XCTAssertTrue(near(dots.at(990, y), paperColor), "right of 980 at \(y)")
            XCTAssertTrue(near(dots.at(670, y), paperColor), "left of 680 at \(y): \(dots.at(670, y))")
        }
        for y: CGFloat in [2450, 2500, 2550] {
            for x: CGFloat in [30, 80, 630, 680, 980] {
                XCTAssertTrue(near(dots.dot(x, y, zoom: 1, scale: 2), dotColor), "the free memo's dot at (\(x), \(y)): \(dots.dot(x, y, zoom: 1, scale: 2))")
            }
            XCTAssertTrue(near(dots.at(55, y), paperColor), "between two dots at (55, \(y))")
            XCTAssertTrue(near(dots.at(10, y), paperColor), "nothing left of the inset at \(y)")
            XCTAssertTrue(near(dots.at(995, y), paperColor), "nothing right of the inset at \(y)")
            XCTAssertTrue(near(dots.at(500, y), paperColor), "no ruled line at \(y): \(dots.at(500, y))")
        }
        XCTAssertTrue(near(dots.at(500, 2400), strongColor, 6), "24:00's strong line stays: \(dots.at(500, 2400))")
        XCTAssertTrue(near(ruled.at(800, 2350), ruleColor, 4), "the ruled day has its line in the right column: \(ruled.at(800, 2350))")
        // Above 24:00, left of the right column, the page is the ruled page's (the timeline does not change).
        let hours = CGRect(x: 0, y: 2000, width: 1000, height: 390)
        let dotsHours = try renderDay(day, rect: hours, style: .dots)
        let ruledHours = try renderDay(day, rect: hours, style: .ruled)
        XCTAssertTrue(Bitmap.sameLeft(dotsHours, ruledHours, below: 662), "the timeline and its lines do not change")
        XCTAssertFalse(Bitmap.same(dotsHours, ruledHours), "the right column differs")
        // The labels 「メモ」 and 「自由メモ」 stay (1 lu = 1 px).
        let top = try renderDay(day, rect: CGRect(x: 660, y: 0, width: 340, height: 40), style: .dots, scale: 1)
        XCTAssertGreaterThan(top.darkerPixels(x: 20..<110, y: 6..<26), 20, "the label 「メモ」")
        let free = try renderDay(day, rect: CGRect(x: 0, y: 2400, width: 300, height: 40), style: .dots, scale: 1)
        XCTAssertGreaterThan(free.darkerPixels(x: 20..<110, y: 6..<26), 20, "the label 「自由メモ」")
    }

    /// The week's memo with dots through the week's own paper (`WeekPaper`, the memo's call with the view's pattern: MM5):
    /// 30…1,380 (28) on the rows below 24:00; above 24:00 nothing changes.
    func testWeekDotsThroughTheWeeksPaper() throws {
        let week = weekLayout(monday)
        let visible = CGRect(x: 0, y: 1820, width: 1400, height: 400)
        let dots = try renderWeek(week, visible: visible, style: .dots)
        let ruled = try renderWeek(week, visible: visible, style: .ruled)
        XCTAssertEqual(dots.originY, ruled.originY)
        for y: CGFloat in [1970, 2020, 2070] {
            for x in stride(from: CGFloat(30), through: 1380, by: 50) {
                XCTAssertTrue(near(dots.dot(x, y, zoom: 1, scale: 2), dotColor), "a dot at (\(x), \(y)): \(dots.dot(x, y, zoom: 1, scale: 2))")
            }
            XCTAssertTrue(near(dots.at(1355, y), paperColor), "between two dots at (1,355, \(y))")
            XCTAssertTrue(near(dots.at(1395, y), paperColor), "nothing right of 1,380 at \(y)")
            XCTAssertTrue(near(dots.at(700, y), paperColor), "no ruled line at \(y)")
            XCTAssertTrue(near(ruled.at(700, y), ruleColor, 4), "the ruled week has its line at \(y): \(ruled.at(700, y))")
        }
        XCTAssertTrue(near(dots.at(700, 1920), strongColor, 6), "24:00's strong line stays")
        // Above 24:00 the two pictures are the same.
        let rows = Int(((1918 - dots.originY) * dots.pixelsPerLu).rounded(.down))
        XCTAssertTrue(dots.bytes.prefix(rows * dots.width * 4) == ruled.bytes.prefix(rows * ruled.width * 4), "the hours do not change")
    }

    /// Joined days (a window of three): the free memo's columns go on 50 lu apart across the boundaries (980 → 1,030, 1,980 →
    /// 2,030), where the ruled lines leave 40 lu; each page's right column has its own dots (1,680…1,980).
    func testJoinedDaysContinueTheColumns() throws {
        let days = [DayKey(year: 2026, month: 10, day: 8), DayKey(year: 2026, month: 10, day: 9), DayKey(year: 2026, month: 10, day: 10)]
        let pages = days.map { PaperContent.day(DayPaperContent(layout: dayLayout($0))) }
        var lanes = AllDayBandLanes()
        let bands = lanes.bands(.day, days: pages.flatMap { PaperSpan.days(of: $0) }, events: [], now: now, holidays: .japan)
        let span = try XCTUnwrap(PaperSpan(pages: pages, bands: bands, focus: 1))
        XCTAssertEqual(span.size.width, 3000)
        func window(_ style: MemoPaperStyle) throws -> Bitmap {
            let view = PaperView(content: pages[1])
            view.span = span
            view.memoPaper = style
            view.contentScaleFactor = 2
            view.show(visible: CGRect(x: 700, y: 2320, width: 1600, height: 200), zoom: 1, contentSize: span.size)
            return try render(view, scale: 2)
        }
        let dots = try window(.dots)
        let ruled = try window(.ruled)
        for y: CGFloat in [2450, 2500] {
            for x: CGFloat in [930, 980, 1030, 1080, 1930, 1980, 2030, 2080] {
                XCTAssertTrue(near(dots.dot(x, y, zoom: 1, scale: 2), dotColor), "a dot at (\(x), \(y)): \(dots.dot(x, y, zoom: 1, scale: 2))")
            }
            for boundary: CGFloat in [1000, 2000] {
                XCTAssertTrue(near(dots.at(boundary + 5, y), paperColor), "between 980 and 1,030 of \(boundary) at \(y)")
                XCTAssertTrue(near(ruled.at(boundary, y), paperColor), "the ruled lines leave the boundary \(boundary) at \(y)")
            }
        }
        for x: CGFloat in [680, 980, 1680, 1980, 2680, 2980] {
            XCTAssertTrue(near(dots.dot(x, 2350, zoom: 1, scale: 2), dotColor), "the right column's dot at (\(x), 2,350)")
        }
        XCTAssertFalse(near(dots.dot(1630, 2350, zoom: 1, scale: 2), dotColor, 4), "no dot left of the second page's right column")
        XCTAssertFalse(near(dots.dot(1030, 2350, zoom: 1, scale: 2), dotColor, 4), "no dot in the second page's timeline")
    }

    // MARK: - 3. Blank

    /// Blank paper: the paper where the ruled lines were, in every memo area; the separators, 24:00's strong line and the
    /// labels stay.
    func testBlankHasNeitherLinesNorDots() throws {
        let month = monthContent()
        let memo = month.layout.memo
        let plainMonth = try renderMonth(month, rect: CGRect(x: 0, y: memo.minY, width: 1400, height: 300), style: .plain, scale: 1)
        for y in stride(from: memo.minY + 50, through: memo.minY + 250, by: 50) {
            for x: CGFloat in [30, 500, 1380] {
                XCTAssertTrue(near(plainMonth.at(x, y), paperColor), "month (\(x), \(y)): \(plainMonth.at(x, y))")
            }
        }
        XCTAssertTrue(near(plainMonth.at(500, memo.minY), strongColor, 6), "the separator stays")
        XCTAssertGreaterThan(plainMonth.darkerPixels(x: 20..<110, y: 6..<26), 20, "the label 「メモ」")
        XCTAssertEqual(plainMonth.count(near: dotColor, tolerance: 4), 0, "no dot")

        let day = dayLayout(DayKey(year: 2026, month: 10, day: 8))
        let plainDay = try renderDay(day, rect: CGRect(x: 0, y: 2200, width: 1000, height: 400), style: .plain, scale: 1)
        for y: CGFloat in [2250, 2300, 2350] {
            for x: CGFloat in [680, 800, 980] {
                XCTAssertTrue(near(plainDay.at(x, y), paperColor), "day's column (\(x), \(y)): \(plainDay.at(x, y))")
            }
        }
        for y: CGFloat in [2450, 2500, 2550] {
            for x: CGFloat in [30, 500, 980] {
                XCTAssertTrue(near(plainDay.at(x, y), paperColor), "day's free memo (\(x), \(y)): \(plainDay.at(x, y))")
            }
        }
        XCTAssertTrue(near(plainDay.at(500, 2400), strongColor, 6), "24:00's strong line stays")
        let free = try renderDay(day, rect: CGRect(x: 0, y: 2400, width: 300, height: 40), style: .plain, scale: 1)
        XCTAssertGreaterThan(free.darkerPixels(x: 20..<110, y: 6..<26), 20, "the label 「自由メモ」")

        let week = weekLayout(monday)
        let plainWeek = try renderWeek(week, visible: CGRect(x: 0, y: 1820, width: 1400, height: 400), style: .plain, scale: 1)
        for y: CGFloat in [1970, 2020] {
            for x: CGFloat in [30, 700, 1380] {
                XCTAssertTrue(near(plainWeek.at(x, y), paperColor), "week (\(x), \(y)): \(plainWeek.at(x, y))")
            }
        }
        XCTAssertTrue(near(plainWeek.at(700, 1920), strongColor, 6), "the week's strong line stays")
    }

    // MARK: - 4. The PDF, the bytes and the time

    private func memoStroke(_ id: String, cell: CellKey) -> InkStroke {
        let points = (0..<12).map { i -> InkPoint in
            let t = CGFloat(i) / 11
            return InkPoint(x: 100 + 400 * t, y: 100 + 96.5 * t, dtMs: i * 10, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5,
                            azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: 1_791_000_000_001, points: points)
    }

    /// The PDF follows the device's pattern (`PDFPageRenderer` makes its own `PaperView`, which starts with `current`): the
    /// month with handwriting in its memo and the day (whose right column is always in it) have dots only with 「ドット方眼」.
    /// The bytes of the three patterns are logged (§4.6). With `TEGAKI_MEMO_SHOT_OUT` (build.yml's memo paper step only) the
    /// month's PDF with dots is written there too (`memo-month-dots.pdf`, §7.3).
    func testPDFFollowsThePattern() throws {
        let month = monthContent()
        var monthPage = InkPage.empty(pageId: month.layout.pageId)
        monthPage.add(memoStroke("memo", cell: .memo))
        let day = dayLayout(DayKey(year: 2026, month: 10, day: 8))
        let dayPage = InkPage.empty(pageId: day.pageId)
        var bytes: [String] = []
        var monthDots: [MemoPaperStyle: Int] = [:]
        var dayDots: [MemoPaperStyle: Int] = [:]
        for style in MemoPaperStyle.allCases {
            MemoPaperStyle.current = style
            let monthPDF = PDFPageRenderer.render(.month(month), page: monthPage, title: "2026年10月")
            let dayPDF = PDFPageRenderer.render(.day(DayPaperContent(layout: day)), page: dayPage, title: "2026年10月8日")
            XCTAssertFalse(monthPDF.isEmpty)
            XCTAssertFalse(dayPDF.isEmpty)
            // build.yml's "Memo paper shots (1.4.2)" (§7.3): the month's PDF with dots, the 17th of memo-paper-shots.
            if style == .dots, let out = ProcessInfo.processInfo.environment["TEGAKI_MEMO_SHOT_OUT"], !out.isEmpty {
                try monthPDF.write(to: URL(fileURLWithPath: out).appendingPathComponent("memo-month-dots.pdf"))
                log("wrote memo-month-dots.pdf (\(monthPDF.count) bytes)")
            }
            bytes.append("\(style.rawValue) month=\(monthPDF.count) day=\(dayPDF.count)")
            let monthHeading = Int(PDFPageRenderer.headingHeight(.month(month)) * 2)
            let monthPicture = try render(pdf: monthPDF, scale: 2)
            let memoTop = monthHeading + Int((month.layout.memo.minY + 10) * 2)
            monthDots[style] = monthPicture.count(near: dotColor, tolerance: 6, rows: memoTop..<monthPicture.height)
            let dayPicture = try render(pdf: dayPDF, scale: 2)
            dayDots[style] = dayPicture.count(near: dotColor, tolerance: 6)
        }
        MemoPaperStyle.set(.ruled)
        log("pdf bytes: " + bytes.joined(separator: "; "))
        log("pdf dot pixels: month \(monthDots.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " ")), "
            + "day \(dayDots.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "))")
        // The month's memo in the PDF is 700 lu: 13 rows × 28 dots, the 4 middle pixels of each at 2 px per pt (half of them
        // are enough: the handwriting may cover some).
        XCTAssertGreaterThan(monthDots[.dots] ?? 0, 13 * 28 * 2, "the month's PDF has the dots")
        XCTAssertLessThan(monthDots[.ruled] ?? .max, 20, "no dots on the ruled month's PDF")
        XCTAssertLessThan(monthDots[.plain] ?? .max, 20, "no dots on the blank month's PDF")
        // The day's right column: 47 rows × 7 dots.
        XCTAssertGreaterThan(dayDots[.dots] ?? 0, 47 * 7 * 2, "the day's PDF has the right column's dots")
        XCTAssertLessThan(dayDots[.ruled] ?? .max, 20)
        XCTAssertLessThan(dayDots[.plain] ?? .max, 20)
    }

    /// The worst window (§4.6): the month's whole memo (6,000 lu: 119 rows × 28 = 3,332 dots) at the iPhone's overview (3x)
    /// and at the iPad's (2x), drawn once; the time is logged against the loose limit of 100 ms, not judged (the simulator on
    /// CI is slow and uneven; the memo paper's role looks again when it is over).
    func testWorstWindowTime() throws {
        let month = monthContent()
        let memo = month.layout.memo
        for (zoom, scale) in [(CGFloat(0.2679), CGFloat(3)), (0.4758, 2)] {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = true
            format.preferredRange = .standard
            var count = 0
            var dotsMs = 0.0
            var pageMs = 0.0
            let view = PaperView(content: .month(month))
            view.memoPaper = .dots
            view.contentScaleFactor = scale
            let size = CGSize(width: 1400 * zoom, height: memo.maxY * zoom)
            _ = UIGraphicsImageRenderer(size: size, format: format).image { context in
                let ctx = context.cgContext
                ctx.scaleBy(x: zoom, y: zoom)
                let dirty = CGRect(x: 0, y: 0, width: 1400, height: memo.maxY)
                let started = Date()
                count = MemoDots.draw(ctx, top: memo.minY, bottom: memo.maxY, left: 0, right: 1400, inset: 20, rowStep: 50,
                                      dirty: dirty, zoom: zoom, scale: scale)
                dotsMs = Date().timeIntervalSince(started) * 1000
                let pageStarted = Date()
                MonthPaper.draw(month, in: ctx, dirty: dirty, zoom: zoom, view: view)
                pageMs = Date().timeIntervalSince(pageStarted) * 1000
            }
            XCTAssertEqual(count, 119 * 28, "the rows 50…5,950 and the 28 columns")
            let over = dotsMs > 100 ? " (over the 100 ms limit: to be looked at)" : ""
            log("n=\(count) ms=\(String(format: "%.1f", dotsMs)) page ms=\(String(format: "%.1f", pageMs)) zoom=\(zoom) scale=\(scale)\(over)")
        }
    }
}

// MARK: - 2e3ee75's memo drawing (the reference)

// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.4, §6.1): the three places 1.4.1 (2e3ee75, the code of build 31 fbd1f7a) drew the memo areas,
// kept here as they were so that MemoPaperDrawTests can hold the ruled pattern against them, pixel for pixel: MonthPaper's
// `drawMemoArea`, the block "4. Memo area" of DayPaper's `draw`, and FreeMemoPaper's `draw` with its `ruledLines`. Copied from
// those files with only the names, the parameters the block took from `draw` and these comments changed. They are the
// reference: never change them to follow the app.
private enum Frozen141Memo {
    /// MonthPaper.drawMemoArea (its private `ruleStep` 50 and `ruleInset` 20, `readable` the month's).
    static func monthMemoArea(_ ctx: CGContext, layout: MonthPageLayout, dirty: CGRect, zoom: CGFloat, scale: CGFloat) {
        let ruleStep: CGFloat = 50
        let ruleInset: CGFloat = 20
        let readable = ZoomPolicy.readableZoom(.month)
        let memo = layout.memo
        guard memo.height > 0 else { return }
        let width = PaperSpec.monthWidth

        // Separator between the grid and the memo area (a little stronger than the grid lines).
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addHorizontal(ctx, y: memo.minY, from: 0, to: width, zoom: zoom, scale: scale)
        ctx.strokePath()

        // Faint ruled lines every 50 lu, inset 20 lu on both sides.
        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = memo.minY + ruleStep
        while y < memo.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: ruleInset, to: width - ruleInset, zoom: zoom, scale: scale)
            }
            y += ruleStep
        }
        ctx.strokePath()

        // Small 「メモ」 label at the top-left, as on the web version.
        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: ruleInset, y: memo.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine(L.text("paper.memo"), in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    /// DayPaper.draw's "4. Memo area" (`grid` is `layout.grid`, `readable` the day's).
    static func dayMemoColumn(_ ctx: CGContext, layout: DayPageLayout, dirty: CGRect, zoom: CGFloat, scale: CGFloat) {
        let grid = layout.grid
        let readable = ZoomPolicy.readableZoom(.day)
        // 4. Memo area: ruled lines every 50 lu and the 「メモ」 label (same look as the month's memo area).
        let memo = layout.memo
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = grid.minY + PaperSpec.dayRuleStep
        while y < grid.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: memo.minX + PaperSpec.dayRuleInset, to: memo.maxX - PaperSpec.dayRuleInset,
                                        zoom: zoom, scale: scale)
            }
            y += PaperSpec.dayRuleStep
        }
        ctx.strokePath()
        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: memo.minX + PaperSpec.dayRuleInset, y: grid.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine(L.text("paper.memo"), in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    /// FreeMemoPaper.draw with its ruledLines.
    static func freeMemo(_ ctx: CGContext, area: CGRect, dirty: CGRect, zoom: CGFloat, scale: CGFloat, readable: CGFloat) {
        guard area.height > 0, area.width > 0 else { return }

        ctx.setLineWidth(PaperText.hairline(zoom))
        if area.minY >= dirty.minY - 1, area.minY <= dirty.maxY + 1 {
            ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
            ctx.beginPath()
            PaperText.addHorizontal(ctx, y: area.minY, from: area.minX, to: area.maxX, zoom: zoom, scale: scale)
            ctx.strokePath()
        }

        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = area.minY + PaperSpec.dayRuleStep
        while y < area.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: area.minX + PaperSpec.dayRuleInset, to: area.maxX - PaperSpec.dayRuleInset,
                                        zoom: zoom, scale: scale)
            }
            y += PaperSpec.dayRuleStep
        }
        ctx.strokePath()

        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: area.minX + PaperSpec.dayRuleInset, y: area.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine(FreeMemoPaper.label, in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }
}
