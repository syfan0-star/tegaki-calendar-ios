import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §5.2, §3.11, D17; role P1 of the week memo): the week memo's paper and PDF.
///
/// - The week paper's tints and its time column's line stop at 24:00; below it the week memo is the day's free
///   memo (the strong line at 24:00, ruled lines every 50 lu inset 20 lu, the label 「自由メモ」), drawn by the
///   one function `FreeMemoPaper` (the owner's choice Q2 A: only ruled lines).
/// - A week laid out without the memo (`WeekLayoutInput.freeMemo` left out) and the day's paper are 1.2.3's,
///   pixel for pixel, against the copies of 43fe366's `WeekPaper` and `DayPaper` at the end of this file; a
///   week with the memo draws the same 24 hours as one without.
/// - The PDF carries the week memo only with handwriting in it, the page's own or a neighbour's coming in (D17),
///   not for a grid stroke reaching below 24:00; with the memo in, the handwriting picture's scale goes down as
///   the day's has since 1.1 (the lead's decision 6 of the week memo's plan, docs/M7C.md).
/// - Joined weeks each draw their memo: the strong line meets at a boundary, the ruled lines leave 40 lu there
///   and every page has its label (the lead's decision 5 of the plan, the day's look).
@MainActor
final class WeekMemoPaperSpanTests: XCTestCase {
    /// 2026-10-07, a Wednesday: today is column 2 of the week of 10-05, whose Saturday and Sunday are
    /// columns 5 and 6; no holiday that week (10-12, the next Monday, is one).
    private let today = DayKey(year: 2026, month: 10, day: 7)
    private var now: Date { today.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600) }
    private let monday = DayKey(year: 2026, month: 10, day: 5)

    private let paperColor = (0xff, 0xfd, 0xf8) // PaperPalette.paper
    private let strongColor = (0xd7, 0xda, 0xde) // PaperPalette.lineStrong
    private let ruleColor = (0xeb, 0xe7, 0xde) // PaperPalette.rule
    private let lineColor = (0xe5, 0xe7, 0xeb) // PaperPalette.line

    // MARK: - Helpers

    private func weekLayout(_ first: DayKey, freeMemo: Bool, events: [LayoutEvent] = [], extraBottom: CGFloat? = nil, floor: CGFloat = 0,
                            weekStart: WeekStart = .monday) -> WeekPageLayout {
        WeekLayoutEngine.layout(WeekLayoutInput(focus: first, events: events, inkBottoms: extraBottom.map { [.extra: $0] } ?? [:], now: now,
                                                weekStart: weekStart, extraFloor: floor, freeMemo: freeMemo))
    }

    private func dayLayout(_ day: DayKey, events: [LayoutEvent] = [], extraBottom: CGFloat? = nil, floor: CGFloat = 0) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: day, events: events, inkBottoms: extraBottom.map { [.extra: $0] } ?? [:], now: now, extraFloor: floor))
    }

    private func timed(_ id: String, on day: DayKey, from startHour: Double, to endHour: Double) -> LayoutEvent {
        let start = day.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(startHour * 3600)
        return LayoutEvent(id: id, title: id, allDay: false, start: start, end: start.addingTimeInterval((endHour - startHour) * 3600),
                           colorHex: "#2563eb", calendarId: "c")
    }

    private func line(_ from: CGPoint, _ to: CGPoint, count: Int = 12, nib: CGFloat = 3.5) -> [InkPoint] {
        (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(max(count - 1, 1))
            return InkPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t, dtMs: i * 10,
                            sizeW: nib, sizeH: nib, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
    }

    private func stroke(_ id: String, cell: CellKey, _ points: [InkPoint], t: Int = 1_791_000_000_001) -> InkStroke {
        InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, points: points)
    }

    /// RGBA bytes, row 0 at the top.
    private struct Bitmap {
        var bytes: [UInt8]
        var width: Int
        var height: Int
        /// The paper y of row 0 and the pixels per lu (to read a pixel by paper coordinates).
        var originX: CGFloat = 0
        var originY: CGFloat = 0
        var pixelsPerLu: CGFloat = 1

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            guard x >= 0, y >= 0, x < width, y < height, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// The pixel at paper (x, y) lu (whole numbers at 1 px per lu).
        func at(_ x: CGFloat, _ y: CGFloat) -> (r: Int, g: Int, b: Int) {
            pixel(Int(((x - originX) * pixelsPerLu).rounded(.down)), Int(((y - originY) * pixelsPerLu).rounded(.down)))
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

        /// The pixels of x × y that are dark (every channel below 120: the pen's #1f2937).
        func inkPixels(x: Range<Int>, y: Range<Int>) -> Int {
            var count = 0
            for yy in y {
                for xx in x {
                    let p = pixel(xx, yy)
                    if p.r >= 0, p.r < 120, p.g < 120, p.b < 120 { count += 1 }
                }
            }
            return count
        }

        /// Are the first `rows` rows of the two bitmaps (same width) byte for byte the same?
        static func sameRows(_ a: Bitmap, _ b: Bitmap, rows: Int) -> Bool {
            guard a.width == b.width, rows <= a.height, rows <= b.height else { return false }
            let count = rows * a.width * 4
            guard count > 0 else { return true }
            return a.bytes.withUnsafeBytes { pa in
                b.bytes.withUnsafeBytes { pb in
                    memcmp(pa.baseAddress!, pb.baseAddress!, count) == 0
                }
            }
        }

        /// How many pixels of the first `rows` rows differ (for the failure message only).
        static func differences(_ a: Bitmap, _ b: Bitmap, rows: Int) -> Int {
            guard a.width == b.width else { return -1 }
            var count = 0
            for y in 0..<min(rows, a.height, b.height) {
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

    /// `rect` (paper units) of a page drawn the way `PaperView.draw` lays it: at `zoom` points per lu and `scale`
    /// pixels per point (the hairlines snapped for `scale`), on the paper colour, `rect` the dirty area.
    private func render(_ rect: CGRect, zoom: CGFloat, scale: CGFloat,
                        _ draw: (CGContext, CGRect, CGFloat, PaperView) -> Void) throws -> Bitmap {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let view = PaperView(content: .week(WeekPaperContent(layout: weekLayout(monday, freeMemo: false))))
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

    private func renderWeek(_ layout: WeekPageLayout, rect: CGRect, zoom: CGFloat = 1, scale: CGFloat = 1) throws -> Bitmap {
        try render(rect, zoom: zoom, scale: scale) { ctx, dirty, zoom, view in
            WeekPaper.draw(WeekPaperContent(layout: layout), in: ctx, dirty: dirty, zoom: zoom, view: view)
        }
    }

    private func renderDay(_ layout: DayPageLayout, rect: CGRect, zoom: CGFloat = 1, scale: CGFloat = 1) throws -> Bitmap {
        try render(rect, zoom: zoom, scale: scale) { ctx, dirty, zoom, view in
            DayPaper.draw(DayPaperContent(layout: layout), in: ctx, dirty: dirty, zoom: zoom, view: view)
        }
    }

    /// The paper view's window drawn by its own `draw` at 1 px per point.
    private func render(_ view: PaperView) throws -> Bitmap {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
            view.draw(view.bounds)
        }
        var out = bitmap(try XCTUnwrap(image.cgImage))
        out.originX = view.contentWindow.minX
        out.originY = view.contentWindow.minY
        return out
    }

    /// The first page of a PDF at 1 px per point, row 0 at the top (PaperViewTests).
    private func render(pdf data: Data) throws -> Bitmap {
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let document = try XCTUnwrap(CGPDFDocument(provider))
        let page = try XCTUnwrap(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        let width = Int(box.width.rounded(.up))
        let height = Int(box.height.rounded(.up))
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            ctx.translateBy(x: -box.minX, y: -box.minY)
            ctx.drawPDFPage(page)
        }
        return Bitmap(bytes: bytes, width: width, height: height)
    }

    // MARK: - 1. The week paper below 24:00

    /// The week of 10-05 with its memo, drawn over 1,720…2,520 lu at 1 px per lu: above 24:00 today's column (2)
    /// and the weekend's (5, 6) are tinted and the time column's line (x 64) and the column lines run; below it
    /// the paper colour, no line at x 64, the strong line at 1,920 across the width, ruled lines at 1,970 and
    /// 2,020 inset 20 lu, and the label 「自由メモ」 at (20, 1,926).
    func testWeekPaperStopsTheTintsAt24() throws {
        let layout = weekLayout(monday, freeMemo: true)
        XCTAssertEqual(layout.todayColumn, 2)
        XCTAssertEqual(layout.dateLabels.map { $0.tone != .normal }, [false, false, false, false, false, true, true], "the weekend: columns 5 and 6")
        XCTAssertEqual(layout.extra, CGRect(x: 0, y: 1920, width: 1400, height: 6000))
        XCTAssertEqual(layout.size, CGSize(width: 1400, height: 7920))
        XCTAssertEqual(FreeMemoPaper.label, "自由メモ")
        XCTAssertEqual(DayPaper.freeMemoLabel, FreeMemoPaper.label)
        let picture = try renderWeek(layout, rect: CGRect(x: 0, y: 1720, width: 1400, height: 800))
        XCTAssertEqual(picture.width, 1400)
        XCTAssertEqual(picture.height, 800)

        // Column centres: 0 (a weekday) 159, 2 (today) 541, 5 (Saturday) 1,113, 6 (Sunday) 1,304. Rows 1,780 (between
        // the hour line at 1,760 and the half hour at 1,800) and 1,995 (between the ruled lines 1,970 and 2,020).
        let plain = picture.at(159, 1780)
        XCTAssertTrue(near(plain, paperColor), "a weekday's column is paper: \(plain)")
        let todayAbove = picture.at(541, 1780)
        XCTAssertLessThan(todayAbove.r, plain.r - 5, "today is tinted above 24:00: \(todayAbove)")
        for x: CGFloat in [1113, 1304] {
            let above = picture.at(x, 1780)
            XCTAssertLessThan(above.b, plain.b - 4, "the weekend is tinted above 24:00 at x \(x): \(above)")
        }
        for x: CGFloat in [159, 541, 1113, 1304] {
            XCTAssertTrue(near(picture.at(x, 1995), paperColor), "no tint below 24:00 at x \(x): \(picture.at(x, 1995))")
            XCTAssertTrue(near(picture.at(x, 2300), paperColor), "no tint far below 24:00 at x \(x): \(picture.at(x, 2300))")
        }

        // The time column's right line (x 64) and a column line (x 254, between columns 0 and 1) stop at 24:00.
        XCTAssertTrue(near(picture.at(64, 1780), strongColor, 6), "the time column's line above 24:00: \(picture.at(64, 1780))")
        XCTAssertTrue(near(picture.at(64, 1995), paperColor), "not below: \(picture.at(64, 1995))")
        XCTAssertTrue(near(picture.at(254, 1780), lineColor, 6), "a column line above 24:00: \(picture.at(254, 1780))")
        XCTAssertTrue(near(picture.at(254, 1995), paperColor), "not below: \(picture.at(254, 1995))")

        // The strong line at 24:00 across the whole width, the gutter included.
        for x: CGFloat in [30, 541, 700, 1113, 1390] {
            XCTAssertTrue(near(picture.at(x, 1920), strongColor, 6), "24:00 at x \(x): \(picture.at(x, 1920))")
        }
        // Ruled lines every 50 lu below it, 20 lu in from both sides of the page.
        for y: CGFloat in [1970, 2020, 2470] {
            XCTAssertTrue(near(picture.at(700, y), ruleColor, 4), "a ruled line at \(y): \(picture.at(700, y))")
            XCTAssertTrue(near(picture.at(25, y), ruleColor, 4), "from x 20 at \(y): \(picture.at(25, y))")
            XCTAssertTrue(near(picture.at(1375, y), ruleColor, 4), "to x 1,380 at \(y): \(picture.at(1375, y))")
            XCTAssertTrue(near(picture.at(10, y), paperColor), "inset 20 lu on the left at \(y): \(picture.at(10, y))")
            XCTAssertTrue(near(picture.at(1390, y), paperColor), "inset 20 lu on the right at \(y): \(picture.at(1390, y))")
        }
        // 「自由メモ」 at (20, 1,926): something darker than the ruled lines in its box, nothing left of it.
        XCTAssertGreaterThan(picture.darkerPixels(x: 20..<110, y: (1926 - 1720)..<(1946 - 1720)), 20, "the label 「自由メモ」 is drawn")
        XCTAssertEqual(picture.darkerPixels(x: 0..<18, y: (1926 - 1720)..<(1946 - 1720)), 0, "nothing left of the label")

        // A week laid out without the memo (1.2.3's): the paper ends at 24:00 and draws nothing of the memo.
        let old = weekLayout(monday, freeMemo: false)
        XCTAssertEqual(old.size, CGSize(width: 1400, height: 1920))
        let oldPicture = try renderWeek(old, rect: CGRect(x: 0, y: 1720, width: 1400, height: 800))
        XCTAssertTrue(near(oldPicture.at(700, 1920), paperColor), "no strong line at 24:00: \(oldPicture.at(700, 1920))")
        XCTAssertTrue(near(oldPicture.at(700, 1970), paperColor), "no ruled line: \(oldPicture.at(700, 1970))")
        XCTAssertEqual(oldPicture.darkerPixels(x: 20..<110, y: (1926 - 1720)..<(1946 - 1720)), 0, "no label")
        XCTAssertEqual(oldPicture.at(541, 1780).r, todayAbove.r, "the same tint above 24:00")
    }

    // MARK: - 2. A week without the memo is 1.2.3's

    /// A week laid out without the memo, drawn by `WeekPaper` and by 43fe366's copy (`Frozen123WeekPaper`), is
    /// the same picture at the iPhone's overview (0.2871, 3x), the iPad's (0.5969, 2x), 1 and 2 — for today's week
    /// with an event, the next week with a holiday and a Sunday-first week, the whole paper and a part of it.
    /// The first test to hold the one-page week paper to 1.2.3 pixel for pixel. And a week with the memo draws
    /// the same 24 hours: the rows above the strong line at 24:00 are the week without it.
    func testWeekWithoutTheMemoIs1_2_3PixelForPixel() throws {
        let events = [timed("e1", on: today, from: 21, to: 23.5), timed("e2", on: DayKey(year: 2026, month: 10, day: 10), from: 9, to: 10.5)]
        let cases: [(name: String, layout: WeekPageLayout, memo: WeekPageLayout)] = [
            ("today's week", weekLayout(monday, freeMemo: false, events: events), weekLayout(monday, freeMemo: true, events: events)),
            ("a holiday", weekLayout(DayKey(year: 2026, month: 10, day: 12), freeMemo: false), weekLayout(DayKey(year: 2026, month: 10, day: 12), freeMemo: true, extraBottom: 6900)),
            ("Sunday first", weekLayout(DayKey(year: 2026, month: 10, day: 4), freeMemo: false, weekStart: .sunday),
             weekLayout(DayKey(year: 2026, month: 10, day: 4), freeMemo: true, floor: 7000, weekStart: .sunday)),
        ]
        let zooms: [(zoom: CGFloat, scale: CGFloat)] = [(0.2871, 3), (0.5969, 2), (1, 2), (2, 1)]
        for item in cases {
            XCTAssertNil(item.layout.cells[.extra], item.name)
            XCTAssertEqual(item.layout.size, CGSize(width: 1400, height: 1920), item.name)
            XCTAssertNotNil(item.memo.cells[.extra], item.name)
            let whole = CGRect(x: 0, y: 0, width: 1400, height: 1920)
            for (zoom, scale) in zooms {
                for rect in [whole, CGRect(x: 300, y: 1500, width: 700, height: 420)] {
                    let app = try renderWeek(item.layout, rect: rect, zoom: zoom, scale: scale)
                    let frozen = try render(rect, zoom: zoom, scale: scale) { ctx, dirty, zoom, view in
                        Frozen123WeekPaper.draw(WeekPaperContent(layout: item.layout), in: ctx, dirty: dirty, zoom: zoom, view: view)
                    }
                    XCTAssertEqual(app.height, frozen.height)
                    XCTAssertTrue(Bitmap.sameRows(app, frozen, rows: app.height),
                                  "\(item.name) at \(zoom) × \(scale), \(rect): \(Bitmap.differences(app, frozen, rows: app.height)) pixels differ from 1.2.3's")
                }
                // The memo's week over the 24 hours: the same rows down to the strong line (it is `scale` pixels
                // thick around row floor(1,920 × zoom × scale) + 0.5).
                let app = try renderWeek(item.memo, rect: whole, zoom: zoom, scale: scale)
                let frozen = try render(whole, zoom: zoom, scale: scale) { ctx, dirty, zoom, view in
                    Frozen123WeekPaper.draw(WeekPaperContent(layout: item.layout), in: ctx, dirty: dirty, zoom: zoom, view: view)
                }
                let rows = Int((1920 * zoom * scale).rounded(.down)) - 1
                XCTAssertTrue(Bitmap.sameRows(app, frozen, rows: rows),
                              "\(item.name) with the memo at \(zoom) × \(scale): \(Bitmap.differences(app, frozen, rows: rows)) pixels of the 24 hours differ")
            }
        }
    }

    // MARK: - 3. The day's paper is 1.2.3's

    /// The day's paper, drawn by `DayPaper` (its free memo now through `FreeMemoPaper`) and by 43fe366's copy
    /// (`Frozen123DayPaper`), is the same picture over a rectangle across 24:00 at the iPhone's overview (0.2679,
    /// 3x), the iPad's (0.4758, 2x), 1 and 2, and over the whole paper at the two overviews: today with an
    /// event before 24:00, a Sunday, a holiday, a deep free memo and a day lined up to a window's floor.
    func testDayFreeMemoIs1_2_3PixelForPixel() throws {
        let days: [(name: String, layout: DayPageLayout)] = [
            ("today", dayLayout(today, events: [timed("e1", on: today, from: 22, to: 23.75)])),
            ("Sunday", dayLayout(DayKey(year: 2026, month: 10, day: 11))),
            ("a holiday", dayLayout(DayKey(year: 2026, month: 10, day: 12))),
            ("a deep memo", dayLayout(DayKey(year: 2026, month: 10, day: 8), extraBottom: 6600)),
            ("a window's floor", dayLayout(DayKey(year: 2026, month: 10, day: 9), floor: 7000)),
        ]
        let zooms: [(zoom: CGFloat, scale: CGFloat)] = [(0.2679, 3), (0.4758, 2), (1, 2), (2, 1)]
        for item in days {
            XCTAssertNotNil(item.layout.cells[.extra], item.name)
            let across = CGRect(x: 0, y: 1800, width: 1000, height: 1400)
            for (zoom, scale) in zooms {
                var rects = [across]
                if zoom < 1 {
                    rects.append(CGRect(origin: .zero, size: item.layout.size))
                }
                for rect in rects {
                    let app = try renderDay(item.layout, rect: rect, zoom: zoom, scale: scale)
                    let frozen = try render(rect, zoom: zoom, scale: scale) { ctx, dirty, zoom, view in
                        Frozen123DayPaper.draw(DayPaperContent(layout: item.layout), in: ctx, dirty: dirty, zoom: zoom, view: view)
                    }
                    XCTAssertEqual(app.height, frozen.height)
                    XCTAssertTrue(Bitmap.sameRows(app, frozen, rows: app.height),
                                  "\(item.name) at \(zoom) × \(scale), \(rect): \(Bitmap.differences(app, frozen, rows: app.height)) pixels differ from 1.2.3's")
                }
            }
        }
    }

    // MARK: - 4. One function for both

    /// The week's memo and the day's free memo, each from its 24:00 down 600 lu at 1 px per lu, are the same
    /// pixels over x 0…980 (where both pages have ruled lines): the strong line, the rows of the ruled lines, the
    /// inset and the label's place and look. Only the right end follows the page: the week's lines run to 1,380.
    func testWeekAndDayDrawTheSameFreeMemo() throws {
        let week = weekLayout(DayKey(year: 2026, month: 10, day: 12), freeMemo: true)
        let day = dayLayout(DayKey(year: 2026, month: 10, day: 13))
        let weekPicture = try renderWeek(week, rect: CGRect(x: 0, y: 1920, width: 980, height: 600))
        let dayPicture = try renderDay(day, rect: CGRect(x: 0, y: 2400, width: 980, height: 600))
        XCTAssertEqual(weekPicture.width, 980)
        XCTAssertEqual(dayPicture.width, 980)
        XCTAssertGreaterThan(weekPicture.darkerPixels(x: 20..<110, y: 6..<26), 20, "the week's label")
        XCTAssertTrue(Bitmap.sameRows(weekPicture, dayPicture, rows: 600),
                      "the week memo is the day's free memo: \(Bitmap.differences(weekPicture, dayPicture, rows: 600)) pixels differ")
        let wide = try renderWeek(week, rect: CGRect(x: 0, y: 1920, width: 1400, height: 100))
        XCTAssertTrue(near(wide.at(1375, 1970), ruleColor, 4), "the week's ruled line runs to 1,380: \(wide.at(1375, 1970))")
        XCTAssertTrue(near(wide.at(1385, 1970), paperColor), "and stops there: \(wide.at(1385, 1970))")
        XCTAssertTrue(near(wide.at(1399, 1920), strongColor, 6), "the strong line to the page's edge: \(wide.at(1399, 1920))")
    }

    // MARK: - 5. The PDF

    /// The week's PDF (D17, the day's rule, decision 6 of the plan): without handwriting in the memo the 24 hours
    /// (1,400 × 1,920); a stroke in the memo down to 300 lu → 1,920 + 700; only a neighbour's memo stroke coming in
    /// → in, as deep as its part over the page; only a grid stroke written across 24:00 → not in; a week without
    /// the memo → its whole paper, 1.2.3's. The handwriting picture's scale over the rectangle: 2.0, about 1.81
    /// (300 lu into the memo), about 1.05 (5,500 lu).
    func testWeekPDFCarriesTheMemoOnlyWithInk() throws {
        let layout = weekLayout(monday, freeMemo: true)
        let paper = PaperContent.week(WeekPaperContent(layout: layout))
        XCTAssertEqual(PDFPageRenderer.headingHeight(paper), 76, "the title and the date row, no all-day lane")
        let gridStroke = stroke("grid", cell: .grid, line(CGPoint(x: 100, y: 1000), CGPoint(x: 500, y: 1100)))
        // Written across 24:00 with its centre above it (y 1,860…1,970: centre about 1,915): a grid stroke (§4.4).
        let acrossStroke = stroke("across", cell: .grid, line(CGPoint(x: 600, y: 1860), CGPoint(x: 700, y: 1970)))
        // In the memo, its bottom at 300 lu (296.5 + 3.5).
        let memoStroke = stroke("memo", cell: .extra, line(CGPoint(x: 100, y: 200), CGPoint(x: 500, y: 296.5), nib: 7))
        let deepStroke = stroke("deep", cell: .extra, line(CGPoint(x: 100, y: 5400), CGPoint(x: 500, y: 5496.5), nib: 7))

        var gridOnly = InkPage.empty(pageId: layout.pageId)
        gridOnly.add(gridStroke)
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: gridOnly), CGRect(x: 0, y: 0, width: 1400, height: 1920))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: InkPage.empty(pageId: layout.pageId)), CGRect(x: 0, y: 0, width: 1400, height: 1920))

        var across = gridOnly
        across.add(acrossStroke)
        XCTAssertGreaterThan(across.inkBottoms()[.grid] ?? 0, 1920, "the stroke reaches below 24:00")
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: across), CGRect(x: 0, y: 0, width: 1400, height: 1920),
                       "a grid stroke below 24:00 alone does not bring the memo in")

        var withMemo = gridOnly
        withMemo.add(memoStroke)
        XCTAssertEqual(withMemo.inkBottoms()[.extra] ?? 0, 300, accuracy: 0.001)
        let memoRect = PDFPageRenderer.paperRect(paper, page: withMemo)
        XCTAssertEqual(memoRect, CGRect(x: 0, y: 0, width: 1400, height: 1920 + 700))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: withMemo, neighborInk: []), memoRect)
        XCTAssertEqual(PDFPageRenderer.pageSize(paper, page: withMemo), CGSize(width: 1400, height: 76 + 2620))

        var deep = gridOnly
        deep.add(deepStroke)
        XCTAssertEqual(deep.inkBottoms()[.extra] ?? 0, 5500, accuracy: 0.001)
        let deepRect = PDFPageRenderer.paperRect(paper, page: deep)
        XCTAssertEqual(deepRect, CGRect(x: 0, y: 0, width: 1400, height: 1920 + 5900))

        // A neighbour's memo stroke (10-12's memo at x 1,400 in this page's coordinates) reaching back 200 lu over
        // this page at y 400: in, 401.75 → 1,100.
        let fromRight = SpanPDFInk(pageId: "w-2026-10-12", stroke: stroke("memo-12", cell: .extra, line(CGPoint(x: -200, y: 400), CGPoint(x: 300, y: 400))),
                                   cellRect: CGRect(x: 1400, y: 1920, width: 1400, height: 6000))
        XCTAssertEqual(try XCTUnwrap(PDFPageRenderer.neighborExtraBottom([fromRight], extra: layout.extra, pageWidth: 1400)), 401.75, accuracy: 0.01)
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: gridOnly, neighborInk: [fromRight]), CGRect(x: 0, y: 0, width: 1400, height: 1920 + 1100))
        // A neighbour's grid stroke is not the memo.
        let gridFromLeft = SpanPDFInk(pageId: "w-2026-09-28", stroke: stroke("grid-28", cell: .grid, line(CGPoint(x: 1300, y: 1900), CGPoint(x: 1500, y: 1990))),
                                      cellRect: CGRect(x: -1400, y: 0, width: 1400, height: 1920))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: gridOnly, neighborInk: [gridFromLeft]), CGRect(x: 0, y: 0, width: 1400, height: 1920))
        // The deeper of the page's own and the incoming.
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: deep, neighborInk: [fromRight]), deepRect)

        // A week laid out without the memo: its whole paper, as 1.2.3 (whatever the page holds).
        let old = PaperContent.week(WeekPaperContent(layout: weekLayout(monday, freeMemo: false)))
        for page in [gridOnly, across, withMemo, InkPage.empty(pageId: layout.pageId)] {
            XCTAssertEqual(PDFPageRenderer.paperRect(old, page: page), CGRect(x: 0, y: 0, width: 1400, height: 1920))
            XCTAssertEqual(PDFPageRenderer.paperRect(old, page: page, neighborInk: [fromRight]), CGRect(x: 0, y: 0, width: 1400, height: 1920))
        }

        // The PDFs: the memo's ruled lines and its stroke are in only when the memo has handwriting.
        let plain = try render(pdf: PDFPageRenderer.render(paper, page: gridOnly, title: "t"))
        XCTAssertEqual(plain.width, 1400)
        XCTAssertEqual(plain.height, 76 + 1920)
        let memoPDF = try render(pdf: PDFPageRenderer.render(paper, page: withMemo, title: "t"))
        XCTAssertEqual(memoPDF.height, 76 + 2620)
        XCTAssertGreaterThan(memoPDF.inkPixels(x: 250..<350, y: (76 + 1920 + 230)..<(76 + 1920 + 270)), 20, "the memo's stroke is drawn")
        XCTAssertGreaterThan(memoPDF.inkPixels(x: 250..<350, y: (76 + 1030)..<(76 + 1070)), 20, "the grid stroke too")
        let rule = memoPDF.pixel(700, 76 + 1970)
        XCTAssertLessThan(rule.b, paperColor.2 - 6, "a ruled line of the memo in the PDF: \(rule)")
        XCTAssertTrue(near(memoPDF.pixel(700, 76 + 1995), paperColor), "paper between the ruled lines: \(memoPDF.pixel(700, 76 + 1995))")
        let incoming = try render(pdf: PDFPageRenderer.render(paper, page: gridOnly, title: "t", neighborInk: [fromRight]))
        XCTAssertEqual(incoming.height, 76 + 3020)
        XCTAssertGreaterThan(incoming.inkPixels(x: 1210..<1395, y: (76 + 1920 + 390)..<(76 + 1920 + 410)), 50, "the incoming stroke is drawn")
        let oldPDF = try render(pdf: PDFPageRenderer.render(old, page: withMemo, title: "t"))
        XCTAssertEqual(oldPDF.height, 76 + 1920, "1.2.3's week PDF")

        // The handwriting picture over the rectangle (decision 24): 2x until the 12M-pixel limit, then lower.
        func inkScale(_ page: InkPage, _ rect: CGRect) throws -> CGFloat {
            let image = try XCTUnwrap(InkSnapshot.image(strokes: page.liveStrokes, cells: layout.cells, bounds: rect, zoom: 1, scale: PDFPageRenderer.inkScale))
            // PencilKit gives the rectangle's size in points at the scale it drew at (InkSnapshotTests): the pixels
            // across the page ÷ 1,400.
            XCTAssertEqual(image.size.width, 1400, accuracy: 1)
            return image.size.width * image.scale / 1400
        }
        XCTAssertEqual(try inkScale(gridOnly, PDFPageRenderer.paperRect(paper, page: gridOnly)), 2.0, accuracy: 0.01)
        XCTAssertEqual(try inkScale(withMemo, memoRect), 1.81, accuracy: 0.01)
        XCTAssertEqual(try inkScale(deep, deepRect), 1.05, accuracy: 0.01)
    }

    // MARK: - 6. Joined weeks

    /// Three joined weeks with their memo (10-05, 10-12, 10-19), drawn by `PaperView.drawSpan` at 1 px per lu:
    /// every page tints its own columns only above 24:00 and rules its memo; at a boundary the rows of the ruled
    /// lines are the same on both sides, the 20 lu on each side (40 lu) have no ruled line, the strong line at 24:00
    /// runs across, and every page has its own label 「自由メモ」 (decision 21 of the plan, the day's look).
    func testJoinedWeeksDrawEachMemo() throws {
        let firsts = [monday, DayKey(year: 2026, month: 10, day: 12), DayKey(year: 2026, month: 10, day: 19)]
        let pages = firsts.map { PaperContent.week(WeekPaperContent(layout: weekLayout($0, freeMemo: true))) }
        var lanes = AllDayBandLanes()
        let bands = lanes.bands(.week, days: pages.flatMap { PaperSpan.days(of: $0) }, events: [], now: now, holidays: .japan)
        let span = try XCTUnwrap(PaperSpan(pages: pages, bands: bands, focus: 1))
        XCTAssertEqual(span.size, CGSize(width: 4200, height: 7920))

        let view = PaperView(content: pages[1])
        view.span = span
        view.contentScaleFactor = 1
        view.show(visible: CGRect(x: 0, y: 1820, width: 4200, height: 400), zoom: 1, contentSize: span.size)
        XCTAssertEqual(view.contentWindow, CGRect(x: 0, y: 1620, width: 4200, height: 800))
        let picture = try render(view)

        for slot in 0..<3 {
            let x0 = CGFloat(slot) * 1400
            // Saturday (column 5) is tinted above 24:00 only, on every page.
            let above = picture.at(x0 + 1113, 1780)
            let plain = picture.at(x0 + 350, 1780)
            XCTAssertLessThan(above.b, plain.b - 4, "page \(slot): Saturday is tinted above 24:00: \(above)")
            XCTAssertTrue(near(picture.at(x0 + 1113, 1995), paperColor), "page \(slot): no tint below 24:00: \(picture.at(x0 + 1113, 1995))")
            XCTAssertTrue(near(picture.at(x0 + 64, 1995), paperColor), "page \(slot): the time column's line stops at 24:00")
            // The memo's ruled lines, and the label of each page at (x0 + 20, 1,926).
            XCTAssertTrue(near(picture.at(x0 + 700, 1970), ruleColor, 4), "page \(slot): a ruled line at 1,970")
            XCTAssertTrue(near(picture.at(x0 + 700, 2020), ruleColor, 4), "page \(slot): a ruled line at 2,020")
            let labelX = Int(x0) + 20
            XCTAssertGreaterThan(picture.darkerPixels(x: labelX..<(labelX + 90), y: (1926 - 1620)..<(1946 - 1620)), 20, "page \(slot): its label 「自由メモ」")
        }
        // Today (10-07, column 2 of the first page) is tinted on the first page only.
        XCTAssertLessThan(picture.at(541, 1780).r, picture.at(350, 1780).r - 5)
        XCTAssertTrue(near(picture.at(1400 + 541, 1780), paperColor), "10-14 is not today")

        for boundary: CGFloat in [1400, 2800] {
            // No ruled line 20 lu on each side of the boundary; the ruled lines on both sides are on the same rows.
            for y: CGFloat in [1970, 2020, 2370] {
                for x in stride(from: boundary - 20, to: boundary + 20, by: 1) {
                    XCTAssertTrue(near(picture.at(x, y), paperColor), "no ruled line at (\(x), \(y)): \(picture.at(x, y))")
                }
                XCTAssertTrue(near(picture.at(boundary - 25, y), ruleColor, 4), "left of \(boundary) at \(y): \(picture.at(boundary - 25, y))")
                XCTAssertTrue(near(picture.at(boundary + 25, y), ruleColor, 4), "right of \(boundary) at \(y): \(picture.at(boundary + 25, y))")
            }
            // The strong line at 24:00 runs across the boundary.
            for x in stride(from: boundary - 30, to: boundary + 30, by: 1) {
                XCTAssertTrue(near(picture.at(x, 1920), strongColor, 6), "the strong line at (\(x), 1,920): \(picture.at(x, 1920))")
            }
        }
        // The rows of the memo, column by column, are the same on the three pages away from the labels.
        for y in stride(from: CGFloat(1921), to: 2420, by: 1) {
            let left = picture.at(1370, y)
            XCTAssertTrue(left == picture.at(1400 + 700, y) && left == picture.at(2800 + 1370, y), "row \(y): \(left), \(picture.at(2100, y)), \(picture.at(4170, y))")
        }
    }
}

// MARK: - 43fe366's paper (the reference)

// 1.3 (docs/M7C_CONTRACT.md §5.2, D9; role P1 of the week memo): 43fe366's (1.2.3's) `WeekPaper` and `DayPaper`,
// kept here as they were so that WeekMemoPaperSpanTests can hold today's week without the memo and today's day
// against them, pixel for pixel. Copied from 43fe366's Paper/WeekPaper.swift and Paper/DayPaper.swift (the
// whole type); only the type names, `private` and these comments differ. They are the reference: never change
// them to follow the app.

/// 43fe366's `WeekPaper` (Paper/WeekPaper.swift).
private enum Frozen123WeekPaper: PaperRenderer {
    static func draw(_ content: WeekPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        let gutter = PaperSpec.weekGutter
        let width = PaperSpec.weekWidth
        let height = layout.size.height

        // 1. Column tints (today over weekend / holiday), the whole height.
        for (column, label) in layout.dateLabels.enumerated() {
            let tint: UIColor?
            if layout.todayColumn == column {
                tint = PaperPalette.todayTint
            } else if label.tone != .normal {
                tint = PaperPalette.weekendTint
            } else {
                tint = nil
            }
            guard let tint = tint else { continue }
            let frame = layout.columnFrame(column)
            let rect = CGRect(x: frame.minX, y: 0, width: frame.width, height: height)
            guard rect.intersects(dirty) else { continue }
            ctx.setFillColor(tint.cgColor)
            ctx.fill(rect)
        }

        // 2. The gutter's right line runs the whole height.
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()

        // 3. Hour grid, column lines and time labels.
        let grid = layout.grid
        let readable = ZoomPolicy.readableZoom(.week)
        TimeGridPaper.drawHourGrid(ctx, gridTop: grid.minY, hourHeight: PaperSpec.weekHourHeight, x0: gutter, x1: width,
                                   labelX: gutter - 8, labelSize: PaperText.weekTimeLabel, dirty: dirty, zoom: zoom, scale: scale,
                                   readable: readable)
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.line.cgColor)
        ctx.beginPath()
        for column in 1..<PaperSpec.weekColumns {
            let x = gutter + CGFloat(column) * PaperSpec.weekColumnWidth
            PaperText.addVertical(ctx, x: x, from: grid.minY, to: grid.maxY, zoom: zoom, scale: scale)
        }
        ctx.strokePath()

        // 4. Timed boxes.
        TimeGridPaper.drawBoxes(ctx, boxes: layout.timedBoxes, textSize: PaperText.weekEvent, dirty: dirty, zoom: zoom, readable: readable)

        // 5. The now line, above the boxes.
        if let line = layout.nowLine, line.y >= dirty.minY - 8, line.y <= dirty.maxY + 8 {
            TimeGridPaper.drawNowLine(ctx, line: line, dotRadius: max(5, 4 / zoom), zoom: zoom)
        }
    }
}

/// 43fe366's `DayPaper` (Paper/DayPaper.swift).
private enum Frozen123DayPaper: PaperRenderer {
    static func draw(_ content: DayPaperContent, in ctx: CGContext, dirty: CGRect, zoom: CGFloat, view: PaperView) {
        let layout = content.layout
        let scale = view.contentScaleFactor
        let gutter = PaperSpec.dayGutter
        let timelineRight = PaperSpec.dayTimelineRight
        // 1.1: the 24 hours (0:00–24:00), not the whole paper.
        let height = layout.grid.maxY

        // 1. Timeline column tint (today over weekend / holiday), 0:00–24:00.
        let tint: UIColor?
        if layout.isToday {
            tint = PaperPalette.todayTintSoft
        } else if layout.dateLabels.first?.tone != .normal {
            tint = PaperPalette.weekendTintSoft
        } else {
            tint = nil
        }
        if let tint = tint {
            let rect = CGRect(x: gutter, y: 0, width: timelineRight - gutter, height: height)
            if rect.intersects(dirty) {
                ctx.setFillColor(tint.cgColor)
                ctx.fill(rect)
            }
        }

        // 2. The gutter's and the timeline's right lines run 0:00–24:00.
        ctx.setLineWidth(PaperText.hairline(zoom))
        ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
        ctx.beginPath()
        PaperText.addVertical(ctx, x: gutter, from: 0, to: height, zoom: zoom, scale: scale)
        PaperText.addVertical(ctx, x: timelineRight, from: 0, to: height, zoom: zoom, scale: scale)
        ctx.strokePath()

        // 3. Hour grid in the timeline column, labels right-aligned at x = 64.
        let grid = layout.grid
        let readable = ZoomPolicy.readableZoom(.day)
        TimeGridPaper.drawHourGrid(ctx, gridTop: grid.minY, hourHeight: PaperSpec.dayHourHeight, x0: gutter, x1: timelineRight,
                                   labelX: gutter - 8, labelSize: PaperText.dayTimeLabel, dirty: dirty, zoom: zoom, scale: scale,
                                   readable: readable)

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

        // 5. 1.1: the free memo area below 24:00 (`extra`).
        drawExtra(ctx, layout: layout, dirty: dirty, zoom: zoom, scale: scale, readable: readable)

        // 6. Timed boxes, then the now line across the timeline column.
        TimeGridPaper.drawBoxes(ctx, boxes: layout.timedBoxes, textSize: PaperText.dayEvent, dirty: dirty, zoom: zoom, readable: readable)
        if let line = layout.nowLine, line.y >= dirty.minY - 8, line.y <= dirty.maxY + 8 {
            TimeGridPaper.drawNowLine(ctx, line: line, dotRadius: max(6, 4 / zoom), zoom: zoom)
        }
    }

    /// 1.1 (M7A_CONTRACT §3.3, M7A-10): the free memo area below 24:00 — a `lineStrong` line at its
    /// top (0…1000, like the month's line above its memo area), ruled lines every `dayRuleStep` lu
    /// over x `dayRuleInset`…1000 − `dayRuleInset` down to its bottom, and the label 「自由メモ」 at
    /// (`dayRuleInset`, top + 6) in the look of the right column's 「メモ」 (a different name, so the
    /// page does not show two 「メモ」). Only what meets `dirty`; nothing for a layout without it.
    private static func drawExtra(_ ctx: CGContext, layout: DayPageLayout, dirty: CGRect, zoom: CGFloat, scale: CGFloat, readable: CGFloat) {
        let extra = layout.extra
        guard layout.cells[.extra] != nil, extra.height > 0, extra.width > 0 else { return }

        ctx.setLineWidth(PaperText.hairline(zoom))
        if extra.minY >= dirty.minY - 1, extra.minY <= dirty.maxY + 1 {
            ctx.setStrokeColor(PaperPalette.lineStrong.cgColor)
            ctx.beginPath()
            PaperText.addHorizontal(ctx, y: extra.minY, from: extra.minX, to: extra.maxX, zoom: zoom, scale: scale)
            ctx.strokePath()
        }

        ctx.setStrokeColor(PaperPalette.rule.cgColor)
        ctx.beginPath()
        var y = extra.minY + PaperSpec.dayRuleStep
        while y < extra.maxY {
            if y >= dirty.minY - 1, y <= dirty.maxY + 1 {
                PaperText.addHorizontal(ctx, y: y, from: extra.minX + PaperSpec.dayRuleInset, to: extra.maxX - PaperSpec.dayRuleInset,
                                        zoom: zoom, scale: scale)
            }
            y += PaperSpec.dayRuleStep
        }
        ctx.strokePath()

        let labelSize = PaperText.fontSize(PaperText.memoLabel, zoom: zoom, readable: readable)
        let labelFont = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        let labelRect = CGRect(x: extra.minX + PaperSpec.dayRuleInset, y: extra.minY + 6, width: 200, height: labelFont.lineHeight + 2)
        if labelRect.intersects(dirty) {
            PaperText.drawLine(freeMemoLabel, in: labelRect, font: labelFont, color: PaperPalette.memoLabel, kern: labelSize * 0.15)
        }
    }

    /// The heading of the free memo area below 24:00 (M7A_CONTRACT §6.2).
    static let freeMemoLabel = L.text("paper.freeMemo")
}
