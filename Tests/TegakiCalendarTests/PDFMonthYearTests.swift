@_spi(SpanLedger) import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §4.7, §5.6, §9.4, §11.2 row P, §11.5 MP3; 0g-32; role P): the PDF of a joined month is its
// focus page as the screen shows it (the window page, lined up) with the strokes that come in from the neighbour months: the
// part of a neighbour's memo stroke over this page counts for the memo (`PDFPageRenderer.neighborMemoBottom`), so the
// rectangle (`paperRect`) runs down as far as the deeper of this page's memo and the incoming strokes need — 1.1.1's rule from
// the window page's own separator line. The year's PDF is its whole page, with a neighbour year's stroke over it; the year
// joins with D1y (`SpanKinds.joined`). The one page's PDF is 1.4.2's, byte for byte.
//
// With `TEGAKI_SPAN_MY_SHOT_OUT` (the span-shots-my job) the joined month's PDF is kept there as `span-my-pdf-month.pdf` (the
// shape of ScreenPathsSpanTests' `TEGAKI_SPAN_SHOT_OUT`).

@MainActor
final class PDFMonthYearTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!

    /// Records what `TransferGuard` refuses (its default stops a Debug build).
    private final class Recorder {
        var lines: [String] = []
    }

    private var recorder = Recorder()
    private var savedRefused: ((String) -> Void)?

    private let oct = "m1-2026-10"
    private let nov = "m1-2026-11"
    private let dec = "m1-2026-12"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let nov11 = DayKey(year: 2026, month: 11, day: 11)

    override func setUp() async throws {
        bed = try SessionTestBed("PDFMonthYearTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        let recorder = Recorder()
        self.recorder = recorder
        savedRefused = TransferGuard.onRefused
        TransferGuard.onRefused = { recorder.lines.append($0) }
    }

    override func tearDown() async throws {
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        XCTAssertEqual(recorder.lines, [], "every page passes the door")
        SpanSession.onFault = savedOnFault
        if let hook = savedRefused {
            TransferGuard.onRefused = hook
        }
        bed?.tearDown()
        bed = nil
    }

    // MARK: - Helpers

    /// A pen stroke of `cell` through `points` (cell-relative), 3.5 lu wide.
    private func stroke(_ id: String, cell: CellKey, _ points: [CGPoint], t: Int = 1_790_000_001_000) -> InkStroke {
        let ink = points.enumerated().map { i, p in
            InkPoint(x: p.x, y: p.y, dtMs: i * 10, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, points: ink)
    }

    /// The points of the straight line from `a` to `b`, `count` of them.
    private func line(_ a: CGPoint, _ b: CGPoint, count: Int = 12) -> [CGPoint] {
        (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    private struct Bitmap {
        var bytes: [UInt8]
        var width: Int
        var height: Int

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            guard x >= 0, y >= 0, x < width, y < height, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// The pixels of x × y that are dark in every channel (below 120: the pen's #1f2937).
        func darkPixels(x: Range<Int>, y: Range<Int>) -> Int {
            var count = 0
            for yy in y {
                for xx in x {
                    let p = pixel(xx, yy)
                    if p.r >= 0, p.r < 120, p.g < 120, p.b < 120 { count += 1 }
                }
            }
            return count
        }
    }

    /// The first page of a PDF at 1 px per point, row 0 at the top (PaperViewTests' reading).
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

    /// The PDF bytes without what CoreGraphics derives from the clock (PaperSpanTests' `stableBytes`).
    private static func stableBytes(_ data: Data) -> Data {
        guard var text = String(data: data, encoding: .isoLatin1) else { return data }
        for pattern in ["/CreationDate\\s*\\(D:[^)]*\\)", "/ModDate\\s*\\(D:[^)]*\\)", "/ID\\s*\\[[^\\]]*\\]"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.data(using: .isoLatin1) ?? data
    }

    /// 1.4.2's `PDFPageRenderer.paperRect` without neighbour strokes (57ffd0f's month, day, week and year branches, copied): the
    /// reference of the one page's PDF. Never change it to follow the app.
    private static func frozen142PaperRect(_ paper: PaperContent, page: InkPage) -> CGRect {
        switch paper {
        case .month(let content):
            let memoHasInk = page.liveStrokes.contains { $0.cell.isMemo }
            guard memoHasInk else { return CGRect(origin: .zero, size: ZoomPolicy.overviewSize(content.layout)) }
            let tail = PaperGrowth.exportTailHeight(inkBottom: page.inkBottoms()[.memo] ?? 0)
            return CGRect(x: 0, y: 0, width: content.layout.size.width, height: content.layout.memo.minY + tail)
        case .day(let content):
            let extraHasInk = page.liveStrokes.contains { $0.cell.isExtra }
            guard extraHasInk else { return CGRect(origin: .zero, size: ZoomPolicy.overviewSize(content.layout)) }
            let tail = PaperGrowth.exportTailHeight(inkBottom: page.inkBottoms()[.extra] ?? 0)
            return CGRect(x: 0, y: 0, width: content.layout.size.width, height: content.layout.grid.maxY + tail)
        case .week(let content):
            guard content.layout.cells[.extra] != nil else { return CGRect(origin: .zero, size: content.layout.size) }
            let extraHasInk = page.liveStrokes.contains { $0.cell.isExtra }
            guard extraHasInk else { return CGRect(origin: .zero, size: ZoomPolicy.overviewSize(content.layout)) }
            let tail = PaperGrowth.exportTailHeight(inkBottom: page.inkBottoms()[.extra] ?? 0)
            return CGRect(x: 0, y: 0, width: content.layout.size.width, height: content.layout.grid.maxY + tail)
        case .year:
            return CGRect(origin: .zero, size: paper.layout.size)
        }
    }

    // MARK: - The joined month's PDF (MP3)

    /// MP3, §4.7, §9.4, 0g-32: November's PDF in the window 2026-09 … 2027-01 (November is tall: a stroke 400 lu down its 11th's
    /// cell, so the others' 6th rows line up with it) holds the parts of October's and December's memo strokes over November —
    /// December's reaching 900 lu down November's memo — though November's memo has no handwriting: the rectangle runs from 0
    /// to the window page's `memo.minY` + 1.1.1's tail for the deeper part (`neighborMemoBottom`), and both strokes are drawn
    /// where they lie. Without them (the one page's call) it is the overview, 1,400 × `memo.minY`. The part of a neighbour's
    /// memo stroke left of x 0, a neighbour's grid stroke and a part that stays above the separator bring no memo in.
    /// With `TEGAKI_SPAN_MY_SHOT_OUT` the PDF is kept as `span-my-pdf-month.pdf`.
    func testAJoinedMonthsPDFDrawsTheMemoStrokesComingInFromItsNeighbours() async throws {
        // `neighborMemoBottom` alone: November's memo at 1,283, a neighbour on the left (its cells 1,400 lu to the left).
        let memo = CGRect(x: 0, y: 1_283, width: 1_400, height: 6_000)
        let leftMemo = CGRect(x: -1_400, y: 1_283, width: 1_400, height: 6_000)
        let reaching = SpanPDFInk(pageId: oct, stroke: stroke("in", cell: .memo, line(CGPoint(x: 1_100, y: 300), CGPoint(x: 1_500, y: 300))),
                                  cellRect: leftMemo)
        XCTAssertEqual(try XCTUnwrap(PDFPageRenderer.neighborMemoBottom([reaching], memo: memo, pageWidth: 1_400)), 301.75, accuracy: 1e-6)
        let short = SpanPDFInk(pageId: oct, stroke: stroke("short", cell: .memo, line(CGPoint(x: 600, y: 300), CGPoint(x: 1_200, y: 900))),
                               cellRect: leftMemo)
        XCTAssertNil(PDFPageRenderer.neighborMemoBottom([short], memo: memo, pageWidth: 1_400), "left of x 0: not over this page")
        let grid = SpanPDFInk(pageId: oct, stroke: stroke("grid", cell: .day(DayKey(year: 2026, month: 11, day: 8)),
                                                          line(CGPoint(x: 100, y: 1_000), CGPoint(x: 400, y: 1_200))),
                              cellRect: CGRect(x: -200, y: 875, width: 200, height: 408))
        XCTAssertNil(PDFPageRenderer.neighborMemoBottom([grid], memo: memo, pageWidth: 1_400), "a grid stroke does not bring the memo in")
        let higher = SpanPDFInk(pageId: oct, stroke: stroke("high", cell: .memo, line(CGPoint(x: 1_300, y: 50), CGPoint(x: 1_600, y: 80))),
                                cellRect: CGRect(x: -1_400, y: 1_050, width: 1_400, height: 6_000))
        XCTAssertNil(PDFPageRenderer.neighborMemoBottom([higher], memo: memo, pageWidth: 1_400), "over this page's grid only (ウ)")
        XCTAssertEqual(PDFPageRenderer.neighborMemoBottom([reaching, short, grid, higher], memo: memo, pageWidth: 1_400) ?? -1, 301.75, accuracy: 1e-6)

        // The session's window.
        var november = InkPage.empty(pageId: nov)
        november.add(stroke("tall", cell: .day(nov11), [CGPoint(x: 50, y: 20), CGPoint(x: 60, y: 210), CGPoint(x: 70, y: 400)]))
        var october = InkPage.empty(pageId: oct)
        october.add(stroke("oct-memo", cell: .memo, line(CGPoint(x: 1_100, y: 300), CGPoint(x: 1_600, y: 420)), t: 1_790_000_002_000))
        var december = InkPage.empty(pageId: dec)
        december.add(stroke("dec-memo", cell: .memo, line(CGPoint(x: -250, y: 300), CGPoint(x: -100, y: 900), count: 7)
            + line(CGPoint(x: -100, y: 900), CGPoint(x: 200, y: 500), count: 7).dropFirst(), t: 1_790_000_003_000))
        for page in [november, october, december] {
            try bed.store.save(page)
        }
        let session = bed.session(.month, focus: nov16)
        await session.prefetch()
        XCTAssertEqual(session.focusPageId, nov)
        let slot = try XCTUnwrap(session.layout.slot(ofPage: nov))
        let layout = try XCTUnwrap(session.layout.pages[slot] as? MonthPageLayout)
        XCTAssertEqual(layout.rows[2].frame.height, 400 + 1.75 + 12, accuracy: 0.001, "November's 3rd row holds the tall stroke")
        let paper = try XCTUnwrap(ScreenPaths.paper(of: layout), "a joined month's paper")
        XCTAssertEqual(paper, PaperSpan.paperContent(of: layout))
        let input = try XCTUnwrap(session.pdfInput(for: nov))
        XCTAssertEqual(input.page.pageId, nov)
        XCTAssertEqual(input.page.liveStrokes.map(\.cell), [.day(nov11)], "November's own stroke is in its grid, its memo is empty")
        XCTAssertEqual(Set(input.neighborInk.map(\.pageId)), [oct, dec])
        let fromDecember = try XCTUnwrap(input.neighborInk.first { $0.pageId == dec })
        let fromOctober = try XCTUnwrap(input.neighborInk.first { $0.pageId == oct })
        XCTAssertEqual(fromDecember.cellRect.minX, 1_400, accuracy: 1e-9, "December's memo starts at November's right edge")
        XCTAssertEqual(fromOctober.cellRect.maxX, 0, accuracy: 1e-9, "October's memo ends at November's left edge")

        // December's deepest point (−100, 900) of its memo lies over November (x 1,300), 1.75 lu of nib below it.
        let incoming = fromDecember.cellRect.minY + 900 + 1.75 - layout.memo.minY
        XCTAssertGreaterThan(incoming, 0)
        XCTAssertEqual(try XCTUnwrap(PDFPageRenderer.neighborMemoBottom(input.neighborInk, memo: layout.memo, pageWidth: 1_400)), incoming, accuracy: 1e-6)
        let rect = PDFPageRenderer.paperRect(paper, page: input.page, neighborInk: input.neighborInk)
        let height = min(layout.memo.minY + PaperGrowth.exportTailHeight(inkBottom: incoming), layout.size.height)
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 1_400, height: height), "down to the deeper incoming stroke's tail")
        XCTAssertGreaterThan(rect.maxY, layout.memo.minY + 900, "December's stroke is inside the rectangle")
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: input.page), CGRect(origin: .zero, size: ZoomPolicy.overviewSize(layout)),
                       "without the neighbours: the overview, as the one page's")
        XCTAssertEqual(ZoomPolicy.overviewSize(layout), CGSize(width: 1_400, height: layout.memo.minY))

        let directory = bed.directory.appendingPathComponent("pdf", isDirectory: true)
        let result = try ExportBuilder(store: bed.store, directory: directory)
            .exportPDF(paper: paper, page: input.page, kind: .month, focus: session.focusDay, neighborInk: input.neighborInk)
        XCTAssertEqual(result.kind, .pdf)
        XCTAssertEqual(result.pageCount, 1)
        let picture = try render(pdf: try Data(contentsOf: result.url))
        let heading = Int(PDFPageRenderer.headingHeight(paper))
        XCTAssertEqual(heading, 64)
        XCTAssertEqual(picture.height, heading + Int(height.rounded(.up)))
        // December's stroke at its deepest point over November. PencilKit draws a stroke as a uniform cubic B-spline of its
        // points (`PKStrokePath`, built by `StrokeGeometry.makePKStroke`), which runs through (P₋₁ + 4 P₀ + P₊₁) / 6 at each
        // inner point, not through the point itself: the V's corner (−100, 900) is drawn at (−95.8, 872.2) of December's memo
        // (with its neighbours (−125, 800) and (−50, 833.3)), x 1,304.2 of November, 27.8 lu above the point. The rectangle
        // counts the points themselves (`neighborMemoBottom`), which bound the curve.
        let decPoints = fromDecember.stroke.points
        let corner = try XCTUnwrap(decPoints.indices.dropFirst().dropLast().max { decPoints[$0].y < decPoints[$1].y })
        XCTAssertEqual(decPoints[corner].y, 900, accuracy: 1e-9, "the V's corner")
        let drawnX = (decPoints[corner - 1].x + 4 * decPoints[corner].x + decPoints[corner + 1].x) / 6
        let drawnY = (decPoints[corner - 1].y + 4 * decPoints[corner].y + decPoints[corner + 1].y) / 6
        XCTAssertEqual(fromDecember.cellRect.minX + drawnX, 1_304.17, accuracy: 0.01)
        XCTAssertEqual(drawnY, 872.22, accuracy: 0.01)
        let deepX = Int((fromDecember.cellRect.minX + drawnX).rounded())
        let deepY = heading + Int((fromDecember.cellRect.minY + drawnY).rounded())
        XCTAssertGreaterThan(picture.darkPixels(x: (deepX - 10)..<(deepX + 11), y: (deepY - 8)..<(deepY + 4)), 0, "December's stroke over November")
        // October's stroke over November's x 100 (1,500 of October's memo: y 396).
        let octY = heading + Int((fromOctober.cellRect.minY + 396).rounded())
        XCTAssertGreaterThan(picture.darkPixels(x: 90..<111, y: (octY - 6)..<(octY + 7)), 0, "October's stroke over November")
        // Nothing of either past the page's edges: the middle of the memo is blank there.
        XCTAssertEqual(picture.darkPixels(x: 500..<900, y: (deepY - 8)..<(deepY + 4)), 0)

        if let out = ProcessInfo.processInfo.environment["TEGAKI_SPAN_MY_SHOT_OUT"], !out.isEmpty {
            let folder = URL(fileURLWithPath: out, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent("span-my-pdf-month.pdf")
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: result.url, to: target)
        }
    }

    // MARK: - The year (SpanKinds)

    /// §5.6, 0g-32, §11.2 (the year's expectations from `SpanKinds.joined`): the year's PDF is its whole page with a stroke
    /// coming in from the year before (from its 12/31 over this year's date column and January): the rectangle does not
    /// change and the part over the page is drawn. A year window's page has a paper of the window (and so a PDF of its own)
    /// exactly when the year joins (D1y); until then the year's PDF is the one page's.
    func testTheYearsPDFIsItsWholePageWithTheNeighboursStroke() async throws {
        let now = bed.now
        let year = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now))
        let before = YearLayoutEngine.layout(YearLayoutInput(year: 2025, events: [], inkBottoms: [:], now: now))
        let paper = try XCTUnwrap(PaperSpan.paperContent(of: year))
        XCTAssertEqual(ScreenPaths.paper(of: year) != nil, SpanKinds.joined.contains(.year), "the year joins with D1y")
        let last = try XCTUnwrap(before.cells[.yearDay(month: 12, day: 31)])
        XCTAssertEqual(last.maxX, 1_400, accuracy: 1e-9, "12/31 is the last column")
        let cellRect = last.offsetBy(dx: -1_400, dy: 0)
        let crossing = SpanPDFInk(pageId: "y-2025", stroke: stroke("y-cross", cell: .yearDay(month: 12, day: 31),
                                                                  line(CGPoint(x: 40, y: 12), CGPoint(x: 230, y: 12))),
                                  cellRect: cellRect)
        let page = InkPage.empty(pageId: "y-2026")
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: [crossing]), CGRect(origin: .zero, size: year.size))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page), CGRect(origin: .zero, size: year.size))
        let with = try render(pdf: PDFPageRenderer.render(paper, page: page, title: "2026年", neighborInk: [crossing]))
        let without = try render(pdf: PDFPageRenderer.render(paper, page: page, title: "2026年"))
        XCTAssertEqual(with.height, without.height)
        let heading = Int(PDFPageRenderer.headingHeight(paper))
        let y = heading + Int((cellRect.minY + 12).rounded())
        // Over January's column (x 56 … 168): the stroke reaches x 118 of this page.
        XCTAssertGreaterThan(with.darkPixels(x: 70..<110, y: (y - 5)..<(y + 6)), without.darkPixels(x: 70..<110, y: (y - 5)..<(y + 6)),
                             "the part of the year before's stroke over January")

        let session = bed.session(.year, focus: nov16)
        await session.prefetch()
        let focusPage = session.layout.pages[session.focusSlot]
        XCTAssertEqual(ScreenPaths.paper(of: focusPage) != nil, SpanKinds.joined.contains(.year), "a year window page's paper")
    }

    // MARK: - The one page (1.4.2's PDF)

    /// §4.7 (1 ページの道の PDF は 1 バイトも変えない), §12.2: without neighbour strokes (left out, or `[]` as the one page calls it)
    /// the rectangle is 1.4.2's (`frozen142PaperRect`) for a month with no handwriting, with a grid stroke only, with memo
    /// strokes 100, 650 and 5,990 lu deep, for weeks with and without the memo below 24:00, a day and a year, and the PDF is the
    /// default call's, byte for byte. A neighbour stroke that does not reach over the page, or a neighbour's grid stroke, leaves
    /// the month's rectangle 1.4.2's.
    func testTheOnePagesPDFIsTheSameAsBefore() throws {
        let now = bed.now
        func month(_ page: InkPage) -> PaperContent {
            let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: YearMonth(year: 2026, month: 11), events: [], inkBottoms: page.inkBottoms(), now: now))
            return .month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: [], chips: [], holidayNames: [:]))
        }
        var pages: [(String, InkPage)] = [("empty", InkPage.empty(pageId: nov))]
        var gridOnly = InkPage.empty(pageId: nov)
        gridOnly.add(stroke("grid", cell: .day(nov11), [CGPoint(x: 50, y: 40), CGPoint(x: 90, y: 60)]))
        pages.append(("grid only", gridOnly))
        for depth in [CGFloat(100), 650, 5_990] {
            var memoPage = InkPage.empty(pageId: nov)
            memoPage.add(stroke("memo-\(Int(depth))", cell: .memo, line(CGPoint(x: 200, y: depth - 40), CGPoint(x: 700, y: depth))))
            pages.append(("memo \(Int(depth))", memoPage))
        }
        let outside = SpanPDFInk(pageId: oct, stroke: stroke("out", cell: .memo, line(CGPoint(x: 400, y: 300), CGPoint(x: 1_000, y: 600))),
                                 cellRect: CGRect(x: -1_400, y: 1_050, width: 1_400, height: 6_000))
        let neighbourGrid = SpanPDFInk(pageId: oct, stroke: stroke("grid-in", cell: .day(DayKey(year: 2026, month: 11, day: 1)),
                                                                   line(CGPoint(x: 100, y: 100), CGPoint(x: 400, y: 150))),
                                       cellRect: CGRect(x: -200, y: 0, width: 200, height: 175))
        for (name, page) in pages {
            let paper = month(page)
            let frozen = Self.frozen142PaperRect(paper, page: page)
            XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page), frozen, name)
            XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: []), frozen, name)
            XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: [outside, neighbourGrid]), frozen, "\(name): nothing comes in")
            XCTAssertEqual(PDFPageRenderer.pageSize(paper, page: page, neighborInk: []), PDFPageRenderer.pageSize(paper, page: page), name)
        }
        let memo650 = pages[3].1
        XCTAssertEqual(PDFPageRenderer.paperRect(month(memo650), page: memo650), CGRect(x: 0, y: 0, width: 1_400, height: 1_050 + 1_100))
        let plain = PDFPageRenderer.render(month(memo650), page: memo650, title: "2026年11月")
        let explicit = PDFPageRenderer.render(month(memo650), page: memo650, title: "2026年11月", neighborInk: [])
        XCTAssertFalse(plain.isEmpty)
        XCTAssertEqual(Self.stableBytes(plain), Self.stableBytes(explicit), "the one page's month PDF")

        // The other pages' rectangles stay 1.4.2's.
        var weekMemo = InkPage.empty(pageId: "w-2026-11-09")
        weekMemo.add(stroke("week-memo", cell: .extra, line(CGPoint(x: 100, y: 200), CGPoint(x: 600, y: 260))))
        var dayMemo = InkPage.empty(pageId: "d-2026-11-11")
        dayMemo.add(stroke("day-memo", cell: .extra, line(CGPoint(x: 100, y: 200), CGPoint(x: 600, y: 260))))
        let monday = DayKey(year: 2026, month: 11, day: 9)
        let cases: [(PaperContent, InkPage)] = [
            (.week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: monday, events: [], inkBottoms: weekMemo.inkBottoms(), now: now,
                                                                                    freeMemo: true)))), weekMemo),
            (.week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: monday, events: [], inkBottoms: [:], now: now,
                                                                                    freeMemo: true)))), InkPage.empty(pageId: "w-2026-11-09")),
            (.week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: monday, events: [], inkBottoms: [:], now: now)))),
             InkPage.empty(pageId: "w-2026-11-09")),
            (.day(DayPaperContent(layout: DayLayoutEngine.layout(DayLayoutInput(day: nov11, events: [], inkBottoms: dayMemo.inkBottoms(), now: now)))), dayMemo),
            (.year(YearPaperContent(layout: YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now)), monthNames: [])),
             InkPage.empty(pageId: "y-2026")),
        ]
        for (paper, page) in cases {
            XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page), Self.frozen142PaperRect(paper, page: page), "\(paper.kind)")
            XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: []), Self.frozen142PaperRect(paper, page: page), "\(paper.kind)")
        }
    }
}
