import Holidays
import InkModel
import Layout
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §3.8, §3.11, §3.13, D16, D17; role P): the paper, the fixed heading, the all-day
/// band and the PDF for a window of joined weeks or days (`PaperSpan`).
///
/// - One page is 1.2.3's output: a window of one page draws the page's own paper (the same pixels); the
///   heading and the band of the page alone and of a window of one page are 43fe366's (`Frozen123StickyHeader`,
///   `Frozen123AllDayBand`, pixel for pixel, at every device's overview); the PDF without neighbour strokes is
///   the default call's and draws the page as 1.2.3 does (its 1.2.3 sizes are ExportBuilderTests').
/// - The joined paper draws each page at its slot's x, the days' free memo lined up to the window's floor.
/// - The joined heading lays every page's columns from its origin; only there does it thin out (the lead's
///   decision 4: an iPhone in landscape at the overview) and carry the month over the week's time column.
/// - The window's all-day lanes are packed over all its days, so a week-crossing event keeps its lane at the
///   boundary, and a session never lowers the lane count.
/// - The PDF draws the strokes coming in from the neighbours (D17), never with a window name, counts them for
///   the day's free memo, and its page — like the data file and the import — refuses window names.
@MainActor
final class PaperSpanTests: XCTestCase {
    /// 2026-11-11, a Wednesday: today is in the week of 11-09; no holiday from 11-04 to 11-22.
    private let today = DayKey(year: 2026, month: 11, day: 11)
    private var now: Date { today.startOfDay(in: DayKey.deviceCalendar).addingTimeInterval(10 * 3600) }

    /// Records what `TransferGuard` refuses (its default stops a Debug build).
    private final class Recorder {
        var lines: [String] = []
    }

    private var recorder = Recorder()
    private var savedHook: ((String) -> Void)?
    private var base: URL?

    override func setUp() async throws {
        let recorder = Recorder()
        self.recorder = recorder
        savedHook = TransferGuard.onRefused
        TransferGuard.onRefused = { recorder.lines.append($0) }
    }

    override func tearDown() async throws {
        if let hook = savedHook {
            TransferGuard.onRefused = hook
        }
        if let base = base {
            try? FileManager.default.removeItem(at: base)
        }
    }

    // MARK: - Helpers

    private func week(_ first: DayKey, events: [LayoutEvent] = []) -> PaperContent {
        .week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: first, events: events, inkBottoms: [:], now: now))))
    }

    private func dayLayout(_ day: DayKey, extraBottom: CGFloat? = nil, floor: CGFloat = 0) -> DayPageLayout {
        DayLayoutEngine.layout(DayLayoutInput(day: day, events: [], inkBottoms: extraBottom.map { [.extra: $0] } ?? [:], now: now, extraFloor: floor))
    }

    private func day(_ day: DayKey, extraBottom: CGFloat? = nil, floor: CGFloat = 0) -> PaperContent {
        .day(DayPaperContent(layout: dayLayout(day, extraBottom: extraBottom, floor: floor)))
    }

    /// A window of `pages` with the lanes packed over all their days.
    private func span(_ pages: [PaperContent], events: [LayoutEvent] = [], focus: Int = 0) throws -> PaperSpan {
        var lanes = AllDayBandLanes()
        let bands = lanes.bands(pages[0].kind, days: pages.flatMap { PaperSpan.days(of: $0) }, events: events, now: now, holidays: .japan)
        return try XCTUnwrap(PaperSpan(pages: pages, bands: bands, focus: focus))
    }

    private func allDay(_ id: String, from first: DayKey, days: Int) -> LayoutEvent {
        LayoutEvent(id: id, title: id, allDay: true, start: first.startOfDay(in: DayKey.deviceCalendar),
                    end: first.adding(days: days).startOfDay(in: DayKey.deviceCalendar), colorHex: "#2563eb", calendarId: "c")
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

    private struct Bitmap {
        var bytes: [UInt8]
        var width: Int
        var height: Int

        func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            guard x >= 0, y >= 0, x < width, y < height, i + 2 < bytes.count else { return (-1, -1, -1) }
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// The pixels of x0..<x1 × y0..<y1 that are dark (every channel below 120: the pen's #1f2937, not
        /// the paper's lines and labels).
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

        /// The pixels of the two bitmaps' rectangles (same size) whose channels differ by more than `tolerance`.
        static func differences(_ a: Bitmap, x0: Int, _ b: Bitmap, x1: Int, width: Int, rows: Int, tolerance: Int = 0) -> Int {
            var count = 0
            for y in 0..<rows {
                for x in 0..<width {
                    let p = a.pixel(x0 + x, y)
                    let q = b.pixel(x1 + x, y)
                    if abs(p.r - q.r) > tolerance || abs(p.g - q.g) > tolerance || abs(p.b - q.b) > tolerance { count += 1 }
                }
            }
            return count
        }
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

    /// The paper view's window drawn by its own `draw` at 1 px per point.
    private func render(_ view: PaperView) throws -> Bitmap {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
            view.draw(view.bounds)
        }
        return bitmap(try XCTUnwrap(image.cgImage))
    }

    /// A SwiftUI view laid out at `width` (its own height) and drawn at 1 px per point.
    private func render<V: View>(_ view: V, width: CGFloat) throws -> Bitmap {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = 1
        return bitmap(try XCTUnwrap(renderer.cgImage, "ImageRenderer gave no picture"))
    }

    /// A SwiftUI view as the screen shows it: in a hosting controller in a window of the test host's scene
    /// (the unit tests run inside the app), drawn by `drawHierarchy` at 1 px per point. For a view holding a
    /// `ScrollView` (the all-day band), which `ImageRenderer` does not draw as the screen does.
    private func renderOnScreen<V: View>(_ view: V, size: CGSize) throws -> Bitmap {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                                  "the unit tests run inside the app: its window scene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading).ignoresSafeArea())
        host.safeAreaRegions = []
        host.view.backgroundColor = .white
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            _ = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        return bitmap(try XCTUnwrap(image.cgImage))
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

    /// The PDF bytes without what CoreGraphics derives from the clock (ExportBuilderTests).
    private static func stableBytes(_ data: Data) -> Data {
        guard var text = String(data: data, encoding: .isoLatin1) else { return data }
        for pattern in ["/CreationDate \\(D:[^)]*\\)", "/ModDate \\(D:[^)]*\\)", "/ID \\[[^\\]]*\\]"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.data(using: .isoLatin1) ?? data
    }

    // MARK: - The window (PaperSpan)

    /// A window of one page is the page alone; a window takes weeks or days of one kind, a band per page.
    func testAWindowOfOnePageIsThePageAlone() throws {
        let page = week(DayKey(year: 2026, month: 11, day: 9))
        guard case .week(let content) = page else { return XCTFail("a week") }
        let single = try XCTUnwrap(PaperSpan.single(page))
        XCTAssertFalse(single.isJoined)
        XCTAssertEqual(single.pages, [page])
        XCTAssertEqual(single.bands, [content.layout.allDayBand])
        XCTAssertEqual(single.origin(ofSlot: 0), 0)
        XCTAssertEqual(single.size, CGSize(width: 1400, height: 1920), "a week is 1,400 × 1,920 lu")
        XCTAssertNil(PaperSpan.single(.year(YearPaperContent(layout: YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: [], inkBottoms: [:], now: now)), monthNames: []))),
                     "the year is not joined in 1.3")

        let joined = try span([page, week(DayKey(year: 2026, month: 11, day: 16)), week(DayKey(year: 2026, month: 11, day: 23))], focus: 1)
        XCTAssertTrue(joined.isJoined)
        XCTAssertEqual(joined.size, CGSize(width: 3 * 1400, height: 1920))
        XCTAssertEqual(joined.origin(ofSlot: 2), 2800)
        XCTAssertEqual(joined.days.count, 21)
        XCTAssertNil(PaperSpan(pages: [page, day(today)], bands: [content.layout.allDayBand, content.layout.allDayBand], focus: 0), "one kind")
        XCTAssertNil(PaperSpan(pages: [page, page], bands: [content.layout.allDayBand], focus: 0), "a band per page")
        XCTAssertEqual(PaperSpan(pages: [page], bands: [content.layout.allDayBand], focus: 7)?.focus, 0, "the focus stays on the window")

        // From the session's SpanLayout: its pages as the paper draws them.
        let plan = SpanPlan(kind: .day, weekStart: .monday, deviceClass: .iPad11, orientation: .portrait)
        let days = [DayKey(year: 2026, month: 11, day: 10), today, DayKey(year: 2026, month: 11, day: 12)]
        let layouts = days.map { dayLayout($0) }
        let layout = SpanLayout(pages: layouts, plan: plan, firstIndex: try XCTUnwrap(plan.index(of: "d-2026-11-10")))
        let fromLayout = try XCTUnwrap(PaperSpan(layout: layout, bands: layouts.map(\.allDayBand), focus: 1))
        XCTAssertEqual(fromLayout.pages, layouts.map { PaperContent.day(DayPaperContent(layout: $0)) })
        XCTAssertEqual(fromLayout.origin(ofSlot: 2), layout.origin(ofSlot: 2))
    }

    // MARK: - The paper

    /// One page: `PaperView` with a window of that one page draws exactly the pixels of the page alone (1.2.3).
    func testAWindowOfOnePageDrawsThePagePaper() throws {
        for page in [week(DayKey(year: 2026, month: 11, day: 9)), day(today)] {
            let alone = PaperView(content: page)
            let windowed = PaperView(content: page)
            windowed.span = try XCTUnwrap(PaperSpan.single(page))
            let zoom: CGFloat = 0.5
            let contentSize = CGSize(width: page.size.width * zoom, height: page.size.height * zoom)
            for view in [alone, windowed] {
                view.contentScaleFactor = 2
                view.show(visible: CGRect(x: 0, y: 200, width: 600, height: 500), zoom: zoom, contentSize: contentSize)
            }
            XCTAssertEqual(alone.contentWindow, windowed.contentWindow)
            let a = try render(alone)
            let b = try render(windowed)
            XCTAssertEqual(a.width, b.width)
            XCTAssertEqual(a.height, b.height)
            XCTAssertTrue(a.bytes == b.bytes, "\(page.kind): the window of one page is the page's own paper")
        }
    }

    /// Two joined days: the second page is drawn at x 1,000 exactly as it is drawn alone, and the free memo of
    /// the short day runs on to the window's floor (D16) — ruled lines where it alone would end at 6,000 lu.
    func testJoinedPaperDrawsEachPageAtItsOriginAndLinesUpTheFreeMemo() throws {
        let first = DayKey(year: 2026, month: 11, day: 10)
        // The first day holds a line in its free memo down to 6,600 lu: the window's floor is 6,650.
        let floors = SpanAlign.dayFloors(previous: .none, extraInkBottoms: [6600, 0], change: .redecide)
        XCTAssertEqual(floors.dayExtra, 6650, accuracy: 0.001)
        let pages = [day(first, extraBottom: 6600, floor: floors.dayExtra), day(today, floor: floors.dayExtra)]
        let joined = try span(pages)
        XCTAssertEqual(joined.size, CGSize(width: 2000, height: 2400 + 6650), "both days end at the floor")
        guard case .day(let second) = pages[1] else { return XCTFail("a day") }
        XCTAssertEqual(second.layout.extra.height, 6650, accuracy: 0.001)

        // The top of the band: page 2 at x 1,000…2,000 against page 2 alone.
        let band = PaperView(content: pages[0])
        band.span = joined
        band.contentScaleFactor = 1
        band.show(visible: CGRect(x: 0, y: 0, width: 2000, height: 600), zoom: 1, contentSize: joined.size)
        let alone = PaperView(content: pages[1])
        alone.contentScaleFactor = 1
        alone.show(visible: CGRect(x: 0, y: 0, width: 1000, height: 600), zoom: 1, contentSize: pages[1].size)
        XCTAssertEqual(band.contentWindow, CGRect(x: 0, y: 0, width: 2000, height: 900))
        XCTAssertEqual(alone.contentWindow, CGRect(x: 0, y: 0, width: 1000, height: 900))
        let a = try render(band)
        let b = try render(alone)
        XCTAssertEqual(Bitmap.differences(a, x0: 1000, b, x1: 0, width: 1000, rows: 900), 0, "page 2 is drawn at its origin as it is alone")
        // Page 1 alone draws its own timeline tint and today's column is page 2's: they differ in the band.
        XCTAssertGreaterThan(Bitmap.differences(a, x0: 0, b, x1: 0, width: 1000, rows: 900), 0)

        // Below 8,400 lu on the second day: a ruled line of the free memo at 2,400 + 6,600 (a multiple of 50).
        band.show(visible: CGRect(x: 0, y: 8950, width: 2000, height: 100), zoom: 1, contentSize: joined.size)
        let bottom = try render(band)
        let rowOfRule = Int(9000 - band.contentWindow.minY)
        let rule = bottom.pixel(1500, rowOfRule)
        let paper = bottom.pixel(1500, rowOfRule + 25)
        XCTAssertTrue(abs(rule.r - 0xeb) <= 4 && abs(rule.g - 0xe7) <= 4 && abs(rule.b - 0xde) <= 4,
                      "the short day's free memo is ruled down to the floor: \(rule)")
        XCTAssertTrue(abs(paper.r - 0xff) <= 3 && abs(paper.g - 0xfd) <= 3 && abs(paper.b - 0xf8) <= 3, "paper between the rules: \(paper)")
    }

    // MARK: - The fixed heading

    /// One page: the heading of the page alone (span nil) and of a window of one page are 43fe366's
    /// (`Frozen123StickyHeader`), pixel for pixel — at the overview of every device, an iPhone in landscape
    /// among them (where the joined weeks thin out, decision 4: one page never does), at 0.5 and 1, scrolled
    /// and centred. Weeks with today, a holiday and a first of a month; days that are today, a holiday and a
    /// Sunday.
    func testAWindowOfOnePageKeepsThePageHeading() throws {
        let weeks = [week(DayKey(year: 2026, month: 11, day: 9)), week(DayKey(year: 2026, month: 11, day: 23)), week(DayKey(year: 2026, month: 11, day: 30))]
        let days = [day(today), day(DayKey(year: 2026, month: 11, day: 23)), day(DayKey(year: 2026, month: 11, day: 15))]
        // The overviews (ZoomPolicy): week — iPhone landscape 0.1068 (20.4 pt columns), iPad mini landscape
        // 0.2734, iPhone portrait 0.2812, iPad 11 portrait 0.4974; day — iPhone landscape 0.0854, iPhone portrait 0.2233.
        let weekZooms: [CGFloat] = [0.1068, 0.2734, 0.2812, 0.4974, 0.5, 1]
        let dayZooms: [CGFloat] = [0.0854, 0.2233, 0.5, 1]
        var compared = 0
        for (pages, zooms) in [(weeks, weekZooms), (days, dayZooms)] {
            for page in pages {
                for zoom in zooms {
                    let pageWidth = page.size.width * zoom
                    // The page alone, then centred in an iPhone's landscape width, then scrolled by 30 pt.
                    let viewports = [PaperViewport(offsetX: 0, zoom: zoom, width: pageWidth.rounded(.up)),
                                     PaperViewport(offsetX: -((874 - pageWidth) / 2).rounded(), zoom: zoom, width: 874),
                                     PaperViewport(offsetX: 30, zoom: zoom, width: 600)]
                    for viewport in viewports where viewport.width >= 1 {
                        let frozen = try render(Frozen123StickyHeader(paper: page, viewport: viewport), width: viewport.width)
                        let plain = try render(StickyHeaderView(paper: page, now: now, viewport: viewport, onDayTap: { _ in }, onMonthTap: { _ in }),
                                               width: viewport.width)
                        let windowed = try render(StickyHeaderView(paper: page, now: now, viewport: viewport, span: PaperSpan.single(page),
                                                                   onDayTap: { _ in }, onMonthTap: { _ in }), width: viewport.width)
                        let first = PaperSpan.days(of: page).first.map { "\($0.year)-\($0.month)-\($0.day)" } ?? "?"
                        let what = "\(page.kind) \(first) at \(zoom), offset \(viewport.offsetX)"
                        XCTAssertGreaterThan(frozen.height, 40, what)
                        XCTAssertEqual(plain.height, frozen.height, what)
                        XCTAssertEqual(windowed.height, frozen.height, what)
                        XCTAssertTrue(plain.bytes == frozen.bytes, "\(what): the heading of the page alone is 43fe366's")
                        XCTAssertTrue(windowed.bytes == frozen.bytes, "\(what): the heading of a window of one page is 43fe366's")
                        compared += 1
                    }
                }
            }
        }
        XCTAssertEqual(compared, 3 * 6 * 3 + 3 * 4 * 3)
    }

    /// F-9 and K-6 on the joined path: in every language the joined weeks' heading is as tall in each form —
    /// `.full` (55 pt columns), `.number` (40 pt) and `.sparse` (an iPhone in landscape, 20.4 pt) — with and
    /// without a holiday line, so a pinch across 50 or 34 pt never moves the paper area under it. pt-BR, which
    /// has the weekday over the number, keeps the weekday's line in the thin forms.
    func testThinCellsKeepTheRowHeightInEveryLanguage() throws {
        let quiet = try span([week(DayKey(year: 2026, month: 11, day: 9)), week(DayKey(year: 2026, month: 11, day: 16))])
        let holiday = try span([week(DayKey(year: 2026, month: 11, day: 16)), week(DayKey(year: 2026, month: 11, day: 23))])
        XCTAssertTrue(holiday.dateLabels(ofSlot: 1).contains { !($0.holidayName ?? "").isEmpty }, "11-23 is a holiday")
        XCTAssertTrue(PaperWords.weekColumnStacksWeekday(.ptBR), "pt-BR has the weekday over the number")
        let forms: [(points: CGFloat, form: StickyHeaderView.WeekCellForm)] = [(55, .full), (40, .number), (20.4, .sparse(every: 2))]
        for language in UILanguage.allCases {
            for (joined, name) in [(quiet, "no holiday"), (holiday, "a holiday")] {
                var heights: [Int] = []
                for (points, form) in forms {
                    let zoom = points / PaperSpec.weekColumnWidth
                    XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: PaperSpec.weekColumnWidth * zoom), form)
                    let width = (2 * PaperSpec.weekWidth * zoom).rounded(.up)
                    let row = try render(StickyHeaderView(paper: joined.pages[0], now: now, viewport: PaperViewport(offsetX: 0, zoom: zoom, width: width),
                                                          span: joined, language: language, onDayTap: { _ in }, onMonthTap: { _ in }), width: width)
                    heights.append(row.height)
                }
                let what = "\(language.rawValue), \(name)"
                XCTAssertGreaterThanOrEqual(heights[0], 48, what)
                XCTAssertEqual(Set(heights).count, 1, "\(what): .full / .number / .sparse are \(heights) pt tall")
            }
        }
    }

    /// Joined weeks: every page's columns start at its origin (the columns of `weekRow`, page after page), and
    /// the second page's day columns look exactly as the page alone with the paper scrolled by one page. Only
    /// the time column differs: the joined week carries its month there.
    func testJoinedHeaderPlacesEveryPageAtItsOrigin() throws {
        let pages = [week(DayKey(year: 2026, month: 11, day: 9)), week(DayKey(year: 2026, month: 11, day: 16))]
        let joined = try span(pages)
        let columns = StickyHeaderView.spanColumns(joined)
        XCTAssertEqual(columns.count, 16)
        XCTAssertEqual(columns.prefix(8).reduce(0, +), 1400, accuracy: 1e-9)
        XCTAssertEqual(columns[8], PaperSpec.weekGutter, "page 2 starts with its time column at x 1,400")
        let days = try span([day(DayKey(year: 2026, month: 11, day: 10)), day(today), day(DayKey(year: 2026, month: 11, day: 12))])
        XCTAssertEqual(StickyHeaderView.spanColumns(days), Array(repeating: [72, 588, 340] as [CGFloat], count: 3).flatMap { $0 })

        // At zoom 0.5 a page is 700 pt and its columns 95 pt: 1.2.3's cells (no thinning).
        let joinedRow = try render(StickyHeaderView(paper: pages[0], now: now, viewport: PaperViewport(offsetX: 0, zoom: 0.5, width: 1400), span: joined,
                                                    onDayTap: { _ in }, onMonthTap: { _ in }), width: 1400)
        let alone = try render(StickyHeaderView(paper: pages[1], now: now, viewport: PaperViewport(offsetX: 0, zoom: 0.5, width: 700),
                                                onDayTap: { _ in }, onMonthTap: { _ in }), width: 700)
        XCTAssertEqual(joinedRow.height, alone.height, "no holiday in either week: one height")
        let gutter = Int((PaperSpec.weekGutter * 0.5).rounded(.up)) + 1
        XCTAssertEqual(Bitmap.differences(joinedRow, x0: 700 + gutter, alone, x1: gutter, width: 700 - gutter, rows: alone.height, tolerance: 8), 0,
                       "page 2's day columns at its origin")
        XCTAssertGreaterThan(joinedRow.darkPixels(x: 700..<(700 + gutter - 1), y: 0..<joinedRow.height)
                             + joinedRow.darkPixels(x: 0..<(gutter - 1), y: 0..<joinedRow.height), 0,
                             "the month over the joined weeks' time columns")
        XCTAssertEqual(alone.darkPixels(x: 0..<(gutter - 1), y: 0..<alone.height), 0, "1.2.3's week has nothing over its time column")
    }

    /// Decision 4 on screen: three joined weeks at an iPhone's landscape overview (zoom 0.1068, 20 pt columns).
    /// Every other day keeps its number — today among them, counted across the weeks' boundaries — and no
    /// number reaches the middle of the columns beside it; the others show only their tint and line.
    func testJoinedHeaderThinsOutOnAnIPhoneInLandscape() throws {
        let pages = [week(DayKey(year: 2026, month: 11, day: 2)), week(DayKey(year: 2026, month: 11, day: 9)), week(DayKey(year: 2026, month: 11, day: 16))]
        let joined = try span(pages, focus: 1)
        let zoom: CGFloat = 0.1068
        let width = 3 * PaperSpec.weekWidth * zoom
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: PaperSpec.weekColumnWidth * zoom), .sparse(every: 2))
        let row = try render(StickyHeaderView(paper: pages[1], now: now, viewport: PaperViewport(offsetX: 0, zoom: zoom, width: width), span: joined,
                                              onDayTap: { _ in }, onMonthTap: { _ in }), width: width)
        /// Pixels far from the paper colour (#fffdf8): the numbers in any tone and today's capsule, not the
        /// tints (at most 0.06 of a colour) or the lines (#e5e7eb).
        func marked(_ x: Range<Int>) -> Int {
            var count = 0
            for y in 0..<row.height {
                for xx in x {
                    let p = row.pixel(xx, y)
                    if p.r >= 0, max(abs(p.r - 0xff), abs(p.g - 0xfd), abs(p.b - 0xf8)) > 60 { count += 1 }
                }
            }
            return count
        }
        var labelled = 0
        for slot in 0..<3 {
            for (index, label) in joined.dateLabels(ofSlot: slot).enumerated() {
                let center = (CGFloat(slot) * PaperSpec.weekWidth + PaperSpec.weekGutter + (CGFloat(index) + 0.5) * PaperSpec.weekColumnWidth) * zoom
                let middle = Int(center.rounded())
                if StickyHeaderView.sparseShows(label.day, every: 2, anchor: today.dayNumber) {
                    labelled += 1
                    // The number (two digits are about 22 pt wide) around the column's middle.
                    XCTAssertGreaterThan(marked((middle - 8)..<(middle + 9)), 0, "\(label.day) keeps its number")
                } else {
                    // A neighbour's number reaches about 11 pt from its own middle, today's capsule about 17:
                    // the middle of this column (20 pt away) stays clear.
                    XCTAssertEqual(marked((middle - 1)..<(middle + 2)), 0, "\(label.day) is left empty and no neighbour's number reaches its middle")
                }
            }
        }
        XCTAssertEqual(labelled, 10, "10 of the 21 days (11-03, 11-05, … 11-21), today (Wednesday 11-11) among them")
        XCTAssertTrue(StickyHeaderView.sparseShows(today, every: 2, anchor: today.dayNumber))
    }

    /// Decision 4: the forms of the joined heading by the column width (`weekCellForm`, `dayBlockForm`), the
    /// sparse days, the month over the time column and 「終日」. That one page never thins is held on screen by
    /// `testAWindowOfOnePageKeepsThePageHeading` (the views do not ask these functions for one page).
    func testThinningFormsFollowTheColumnWidth() throws {
        // The week's day columns (190.857 lu × the overview zoom): iPhone landscape 0.1068 → 20.4 pt, iPad mini
        // landscape 0.2734 → 52.2 pt, iPhone portrait 0.2812 → 53.7 pt, iPad 11 portrait 0.4974 → 94.9 pt.
        let column = { (zoom: CGFloat) in PaperSpec.weekColumnWidth * zoom }
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: column(0.1068)), .sparse(every: 2))
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: column(0.2734)), .full)
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: column(0.2812)), .full)
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: column(0.4974)), .full)
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: 40), .number)
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: 11), .sparse(every: 4))
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: 0), .full, "no viewport yet")
        XCTAssertEqual(StickyHeaderView.weekCellForm(joined: true, columnPoints: .nan), .full)
        for points: CGFloat in [5, 11, 20.4, 40, 52.2, 94.9] {
            XCTAssertEqual(StickyHeaderView.weekCellForm(joined: false, columnPoints: points), .full, "one page at \(points) pt is 1.2.3's")
        }
        // The day's time line column (588 lu × zoom): iPhone landscape 0.0854 → 50 pt, iPhone portrait 0.2233 → 131 pt.
        XCTAssertEqual(StickyHeaderView.dayBlockForm(joined: true, columnPoints: 588 * 0.0854), .number)
        XCTAssertEqual(StickyHeaderView.dayBlockForm(joined: true, columnPoints: 80), .numberAndWeekday)
        XCTAssertEqual(StickyHeaderView.dayBlockForm(joined: true, columnPoints: 588 * 0.2233), .full)
        XCTAssertEqual(StickyHeaderView.dayBlockForm(joined: false, columnPoints: 588 * 0.0854), .full, "the day alone is 1.2.3's")

        // Sparse numbers keep their places across the weeks' boundary and always show today.
        let anchor = today.dayNumber
        let sunday = DayKey(year: 2026, month: 11, day: 15)
        let monday = DayKey(year: 2026, month: 11, day: 16)
        XCTAssertTrue(StickyHeaderView.sparseShows(today, every: 2, anchor: anchor))
        XCTAssertNotEqual(StickyHeaderView.sparseShows(sunday, every: 2, anchor: anchor), StickyHeaderView.sparseShows(monday, every: 2, anchor: anchor),
                          "Sunday and the next Monday: one of the two, not both side by side")
        XCTAssertTrue(StickyHeaderView.sparseShows(DayKey(year: 2026, month: 11, day: 5), every: 2, anchor: anchor), "before today too")
        XCTAssertTrue(StickyHeaderView.sparseShows(sunday, every: 1, anchor: anchor))

        // The month over the joined week's time column (64 lu × zoom), the year for the week of January 1.
        let font = UIFont.systemFont(ofSize: StickyHeaderView.joinedGutterFontSize, weight: .semibold)
        let november = (0..<7).map { DayKey(year: 2026, month: 11, day: 9).adding(days: $0) }
        let month = DateText.monthName(11, .full, .ja)
        XCTAssertEqual(StickyHeaderView.weekGutterTitle(days: november, gutterPoints: PaperText.naturalWidth(of: month, font: font) + 4, language: .ja), month)
        XCTAssertNil(StickyHeaderView.weekGutterTitle(days: november, gutterPoints: PaperSpec.weekGutter * 0.1068, language: .ja), "an iPhone in landscape")
        let sundayFirst = (0..<7).map { DayKey(year: 2026, month: 11, day: 29).adding(days: $0) }
        XCTAssertEqual(StickyHeaderView.weekGutterTitle(days: sundayFirst, gutterPoints: 200, language: .ja), DateText.monthName(11, .full, .ja),
                       "the month of the week's first day (a Sunday-first week from November 29)")
        let newYear = (0..<7).map { DayKey(year: 2026, month: 12, day: 28).adding(days: $0) }
        XCTAssertEqual(StickyHeaderView.weekGutterTitle(days: newYear, gutterPoints: 200, language: .ja), DateText.yearTitle(2027, .ja))
        let digits = PaperText.naturalWidth(of: "2027", font: font) + 4
        if PaperText.naturalWidth(of: DateText.yearTitle(2027, .ja), font: font) + 4 > digits {
            XCTAssertEqual(StickyHeaderView.weekGutterTitle(days: newYear, gutterPoints: digits, language: .ja), "2027")
        }

        // 「終日」 in a joined page's gutter only where it fits; one page keeps 1.2.3's rule (ja even where cut).
        let narrow = PaperSpec.weekGutter * 0.1068
        XCTAssertNotNil(PaperWords.allDayLabel(widthPoints: narrow, fontSize: AllDayBandMetrics.labelPoints, .ja), "1.2.3 shows ja's word cut")
        XCTAssertNil(AllDayBandView.spanGutterLabel(widthPoints: narrow, language: .ja))
        XCTAssertEqual(AllDayBandView.spanGutterLabel(widthPoints: 64, language: .ja),
                       PaperWords.allDayLabel(widthPoints: 64, fontSize: AllDayBandMetrics.labelPoints, .ja))
    }

    // MARK: - The all-day band

    /// An event across the boundary of two weeks: packed week by week its lane swaps there (lane 1 in the
    /// first week, lane 0 in the second); packed over the window it keeps lane 1 on both pages, square where it
    /// goes on, the second page's bar at x 1,400 + 64.
    func testWindowLanesDoNotSwapAtABoundaryForAWeekCrossingEvent() throws {
        let first = DayKey(year: 2026, month: 11, day: 9)
        let second = DayKey(year: 2026, month: 11, day: 16)
        let early = allDay("early", from: DayKey(year: 2026, month: 11, day: 12), days: 3)   // Thu … Sat
        let crossing = allDay("crossing", from: DayKey(year: 2026, month: 11, day: 14), days: 4) // Sat … Tue
        let monday = allDay("monday", from: second, days: 1)
        let events = [early, crossing, monday]

        let alone1 = AllDayBandEngine.week(firstDay: first, weekStart: .monday, events: events, now: now, holidays: .japan)
        let alone2 = AllDayBandEngine.week(firstDay: second, weekStart: .monday, events: events, now: now, holidays: .japan)
        XCTAssertEqual(alone1.bars.first { $0.eventId == "crossing" }?.lane, 1)
        XCTAssertEqual(alone2.bars.first { $0.eventId == "crossing" }?.lane, 0, "packed week by week the lane swaps at the boundary")

        let joined = try span([week(first, events: events), week(second, events: events)], events: events)
        XCTAssertEqual(joined.bands.map(\.laneCount), [2, 2], "one lane count for the window")
        let left = try XCTUnwrap(joined.bands[0].bars.first { $0.eventId == "crossing" })
        let right = try XCTUnwrap(joined.bands[1].bars.first { $0.eventId == "crossing" })
        XCTAssertEqual(left.lane, right.lane, "the same lane on both sides of the boundary")
        XCTAssertEqual(left.lane, 1)
        XCTAssertTrue(left.continuesRight)
        XCTAssertTrue(right.continuesLeft)
        XCTAssertEqual(joined.bands[1].bars.first { $0.eventId == "monday" }?.lane, 0)

        let placed = AllDayBandView.placedBands(band: alone1, span: joined)
        XCTAssertEqual(placed.map(\.origin), [0, 1400])
        XCTAssertEqual(placed[0].origin + left.maxX, 1400, accuracy: 1e-9, "the left bar runs to the page's edge")
        XCTAssertEqual(placed[1].origin + right.minX, 1400 + PaperSpec.weekGutter, accuracy: 1e-9, "and goes on after the next time column")
    }

    /// The lane count is decided again when the window is laid out and never goes down in a session; a new
    /// session starts from the window alone.
    func testLaneCountNeverGoesDownInASession() throws {
        let events = [allDay("a", from: DayKey(year: 2026, month: 11, day: 10), days: 2),
                      allDay("b", from: DayKey(year: 2026, month: 11, day: 10), days: 1),
                      allDay("c", from: DayKey(year: 2026, month: 11, day: 10), days: 1)]
        let days = { (first: DayKey) in (0..<14).map { first.adding(days: $0) } }
        var lanes = AllDayBandLanes()
        let busy = lanes.bands(.week, days: days(DayKey(year: 2026, month: 11, day: 9)), events: events, now: now, holidays: .japan)
        XCTAssertEqual(busy.map(\.laneCount), [3, 3])
        XCTAssertEqual(lanes.floor, 3)
        let shifted = lanes.bands(.week, days: days(DayKey(year: 2026, month: 11, day: 23)), events: events, now: now, holidays: .japan)
        XCTAssertEqual(shifted.map(\.laneCount), [3, 3], "after a shift to quiet weeks the band keeps its lanes")
        XCTAssertTrue(shifted.allSatisfy { $0.bars.isEmpty })
        var fresh = AllDayBandLanes()
        XCTAssertEqual(fresh.bands(.week, days: days(DayKey(year: 2026, month: 11, day: 23)), events: events, now: now, holidays: .japan).map(\.laneCount), [0, 0],
                       "a new session")
        // Days: one band per day, the window's lanes.
        var dayLanes = AllDayBandLanes()
        let dayBands = dayLanes.bands(.day, days: [DayKey(year: 2026, month: 11, day: 10), today, DayKey(year: 2026, month: 11, day: 12)],
                                      events: events, now: now, holidays: .japan)
        XCTAssertEqual(dayBands.map(\.laneCount), [3, 3, 3])
        XCTAssertEqual(dayBands[1].bars.first { $0.eventId == "a" }?.lane, dayBands[0].bars.first { $0.eventId == "a" }?.lane)
    }

    /// §3.8: the session keeps its events page by page, and an event across two pages is in both lists. Put
    /// one after another, the lists give the bands of the window's own events: one bar per page for each event
    /// (one id per bar, as `ForEach(page.band.bars)` needs) and the lane count of the events themselves.
    func testPerPageEventListsPutTogetherGiveOneBarPerEvent() throws {
        let first = DayKey(year: 2026, month: 11, day: 9)
        let second = DayKey(year: 2026, month: 11, day: 16)
        let early = allDay("early", from: DayKey(year: 2026, month: 11, day: 12), days: 3)    // Thu … Sat
        let crossing = allDay("crossing", from: DayKey(year: 2026, month: 11, day: 14), days: 4) // Sat … Tue
        let monday = allDay("monday", from: second, days: 1)
        let days = (0..<14).map { first.adding(days: $0) }
        let perPage: [[LayoutEvent]] = [[early, crossing], [crossing, monday]]
        let expected = AllDayBandEngine.pages(.week, days: days, events: [early, crossing, monday], now: now, holidays: .japan)
        XCTAssertEqual(expected.map(\.laneCount), [2, 2])

        var lanes = AllDayBandLanes()
        let bands = lanes.bands(.week, days: days, events: perPage.flatMap { $0 }, now: now, holidays: .japan)
        XCTAssertEqual(bands, expected)
        XCTAssertEqual(lanes.floor, 2, "the lanes of the events, not of their copies")
        for band in bands {
            XCTAssertEqual(Set(band.bars.map(\.eventId)).count, band.bars.count, "one bar per event on a page")
        }
        XCTAssertEqual(bands.map { $0.bars.filter { $0.eventId == "crossing" }.count }, [1, 1])

        // Days: an event of three days is in the three days' lists.
        let three = allDay("three", from: DayKey(year: 2026, month: 11, day: 10), days: 3)
        var dayLanes = AllDayBandLanes()
        let dayBands = dayLanes.bands(.day, days: [DayKey(year: 2026, month: 11, day: 10), today, DayKey(year: 2026, month: 11, day: 12)],
                                      events: [three, three, three], now: now, holidays: .japan)
        XCTAssertEqual(dayBands.map(\.laneCount), [1, 1, 1])
        XCTAssertEqual(dayBands.map(\.bars.count), [1, 1, 1])

        XCTAssertEqual(AllDayBandLanes.uniqueEvents([crossing, early, crossing, monday, early]).map(\.id), ["crossing", "early", "monday"],
                       "the first of each id, in order")
    }

    /// One page: the window's band of one week or one day is the band 1.2.3 lays out for it, placed at x 0.
    func testABandOfOnePageIsThePageBand() throws {
        let events = [allDay("a", from: DayKey(year: 2026, month: 11, day: 10), days: 2), allDay("b", from: today, days: 1)]
        var lanes = AllDayBandLanes()
        let first = DayKey(year: 2026, month: 11, day: 9)
        XCTAssertEqual(lanes.bands(.week, days: (0..<7).map { first.adding(days: $0) }, events: events, now: now, holidays: .japan),
                       [AllDayBandEngine.week(firstDay: first, weekStart: .monday, events: events, now: now, holidays: .japan)])
        var dayLanes = AllDayBandLanes()
        XCTAssertEqual(dayLanes.bands(.day, days: [today], events: events, now: now, holidays: .japan),
                       [AllDayBandEngine.day(today, events: events, now: now, holidays: .japan)])
        let band = AllDayBandEngine.week(firstDay: first, weekStart: .monday, events: events, now: now, holidays: .japan)
        let alone = AllDayBandView.placedBands(band: band, span: nil)
        XCTAssertEqual(alone.count, 1)
        XCTAssertEqual(alone[0].band, band)
        XCTAssertEqual(alone[0].origin, 0)
        let single = try XCTUnwrap(PaperSpan.single(week(first, events: events)))
        let windowed = AllDayBandView.placedBands(band: band, span: single)
        XCTAssertEqual(windowed.count, 1)
        XCTAssertEqual(windowed[0].band, single.bands[0])
        XCTAssertEqual(windowed[0].origin, 0)
    }

    /// One page on screen: the band of the page alone (span nil) and of a window of one page are 43fe366's
    /// (`Frozen123AllDayBand`), pixel for pixel — a week with bars going on to both sides, today and the
    /// weekend tinted, and a day — at an iPhone's landscape overview (ja's 「終日」 cut in the narrow time
    /// column, as 1.2.3 shows it; the joined path would leave it out), centred in a wide screen, at 0.5, and
    /// with the lane zoom frozen by a pinch.
    func testTheOnePageBandIs1_2_3OnScreen() throws {
        let first = DayKey(year: 2026, month: 11, day: 9)
        let events = [allDay("from-before", from: DayKey(year: 2026, month: 11, day: 6), days: 5),   // Fri 11-06 … Tue 11-10
                      allDay("to-after", from: DayKey(year: 2026, month: 11, day: 14), days: 4),     // Sat 11-14 … Tue 11-17
                      allDay("middle", from: DayKey(year: 2026, month: 11, day: 10), days: 3)]       // Tue … Thu: a second lane
        let weekPaper = week(first, events: events)
        let dayPaper = PaperContent.day(DayPaperContent(layout: DayLayoutEngine.layout(DayLayoutInput(day: today, events: events, inkBottoms: [:], now: now))))
        let weekBand = AllDayBandEngine.week(firstDay: first, weekStart: .monday, events: events, now: now, holidays: .japan)
        let dayBand = AllDayBandEngine.day(today, events: events, now: now, holidays: .japan)
        XCTAssertEqual(weekPaper.allDayBand, weekBand)
        XCTAssertEqual(dayPaper.allDayBand, dayBand)
        XCTAssertEqual(weekBand.laneCount, 2)
        XCTAssertTrue(weekBand.bars.contains { $0.continuesLeft } && weekBand.bars.contains { $0.continuesRight })
        XCTAssertNotNil(weekBand.todayColumn)
        let cases: [(band: AllDayBandLayout, paper: PaperContent, zoom: CGFloat, laneZoom: CGFloat?, width: CGFloat, offsetX: CGFloat)] = [
            (weekBand, weekPaper, 0.1068, nil, 874, -((874 - 1400 * 0.1068) / 2).rounded()),
            (weekBand, weekPaper, 0.5, nil, 700, 0),
            (weekBand, weekPaper, 0.5, 0.3, 600, 120),
            (dayBand, dayPaper, 0.0854, nil, 874, -((874 - 1000 * 0.0854) / 2).rounded()),
            (dayBand, dayPaper, 0.5, nil, 500, 0),
        ]
        XCTAssertNotNil(PaperWords.allDayLabel(widthPoints: PaperSpec.weekGutter * 0.1068, fontSize: AllDayBandMetrics.labelPoints, .ja),
                        "1.2.3 shows ja's 「終日」 cut at an iPhone's landscape overview")
        for item in cases {
            let viewport = PaperViewport(offsetX: item.offsetX, zoom: item.zoom, width: item.width)
            let single = try XCTUnwrap(PaperSpan.single(item.paper))
            XCTAssertEqual(single.bands, [item.band])
            let height: CGFloat = 120
            let frozen = try renderOnScreen(Frozen123AllDayBand(band: item.band, viewport: viewport, pageHeight: 400, laneZoom: item.laneZoom),
                                            size: CGSize(width: item.width, height: height))
            let plain = try renderOnScreen(AllDayBandView(band: item.band, viewport: viewport, pageHeight: 400, laneZoom: item.laneZoom,
                                                          onBarTap: { _ in }, onColumnTap: { _ in }),
                                           size: CGSize(width: item.width, height: height))
            let windowed = try renderOnScreen(AllDayBandView(band: single.bands[0], viewport: viewport, pageHeight: 400, laneZoom: item.laneZoom,
                                                             span: single, onBarTap: { _ in }, onColumnTap: { _ in }),
                                              size: CGSize(width: item.width, height: height))
            let what = "\(item.band.kind) at \(item.zoom), lane zoom \(item.laneZoom.map { "\($0)" } ?? "nil"), offset \(item.offsetX)"
            // The band is drawn: the bars' blue (#2563eb) is there.
            var blue = 0
            for y in 0..<frozen.height {
                for x in 0..<frozen.width {
                    let p = frozen.pixel(x, y)
                    if abs(p.r - 0x25) <= 12, abs(p.g - 0x63) <= 12, abs(p.b - 0xeb) <= 12 { blue += 1 }
                }
            }
            XCTAssertGreaterThan(blue, 20, "\(what): the band is drawn")
            XCTAssertEqual([plain.width, plain.height, windowed.width, windowed.height], [frozen.width, frozen.height, frozen.width, frozen.height])
            XCTAssertEqual(Bitmap.differences(plain, x0: 0, frozen, x1: 0, width: frozen.width, rows: frozen.height), 0,
                           "\(what): the band of the page alone is 43fe366's")
            XCTAssertEqual(Bitmap.differences(windowed, x0: 0, frozen, x1: 0, width: frozen.width, rows: frozen.height), 0,
                           "\(what): the band of a window of one page is 43fe366's")
        }
    }

    // MARK: - The PDF

    /// 43fe366's `PDFPageRenderer.paperRect`, copied: the reference of the one-page PDF's rectangle.
    private static func frozen123PaperRect(_ paper: PaperContent, page: InkPage) -> CGRect {
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
        case .week, .year:
            return CGRect(origin: .zero, size: paper.layout.size)
        }
    }

    /// One page: without neighbour strokes (`neighborInk: []`, as the one-page path calls it, or left out) the
    /// PDF is the default call's, byte for byte; its rectangle follows 43fe366's rule (copied above) for the
    /// free memo with and without handwriting, deep handwriting and a grid stroke below 24:00; and the page's
    /// own strokes are drawn where they are. That the default call is 1.2.3's PDF in size and page is held by
    /// ExportBuilderTests (43fe366's file, unchanged: `testPDFHasOnePageAndOverviewSize`,
    /// `testDayPDFIncludesTheExtraOnlyWithInk`, `testPDFRendersEveryKind` and the others).
    func testWithoutNeighborInkThePDFIsTheDefaultCallsPDF() throws {
        var page = InkPage.empty(pageId: "d-2026-11-11")
        page.add(stroke("own-extra", cell: .extra, line(CGPoint(x: 40, y: 400), CGPoint(x: 400, y: 480))))
        page.add(stroke("own-grid", cell: .grid, line(CGPoint(x: 100, y: 1000), CGPoint(x: 500, y: 1100))))
        let paper = day(today, extraBottom: page.inkBottoms()[.extra])
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: []), PDFPageRenderer.paperRect(paper, page: page))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page), CGRect(x: 0, y: 0, width: 1000, height: 3500))
        XCTAssertEqual(PDFPageRenderer.pageSize(paper, page: page, neighborInk: []), PDFPageRenderer.pageSize(paper, page: page))
        let plain = PDFPageRenderer.render(paper, page: page, title: "t")
        let explicit = PDFPageRenderer.render(paper, page: page, title: "t", neighborInk: [])
        XCTAssertFalse(plain.isEmpty)
        XCTAssertEqual(Self.stableBytes(plain), Self.stableBytes(explicit))

        // 43fe366's rectangle for the pages of the free memo's cases, and for a week.
        var deep = InkPage.empty(pageId: "d-2026-11-11")
        deep.add(stroke("deep", cell: .extra, line(CGPoint(x: 40, y: 6300), CGPoint(x: 400, y: 6410))))
        var gridOnly = InkPage.empty(pageId: "d-2026-11-11")
        gridOnly.add(stroke("below-24", cell: .grid, line(CGPoint(x: 40, y: 2600), CGPoint(x: 400, y: 2650))))
        var erased = page
        erased.remove(ids: ["own-extra"], at: 1_791_000_000_100)
        for item in [page, deep, gridOnly, erased, InkPage.empty(pageId: "d-2026-11-11")] {
            let itemPaper = day(today, extraBottom: item.inkBottoms()[.extra])
            XCTAssertEqual(PDFPageRenderer.paperRect(itemPaper, page: item), Self.frozen123PaperRect(itemPaper, page: item), "\(item.liveStrokes.map(\.id))")
            XCTAssertEqual(PDFPageRenderer.paperRect(itemPaper, page: item, neighborInk: []), Self.frozen123PaperRect(itemPaper, page: item))
        }
        let weekPaper = week(DayKey(year: 2026, month: 11, day: 9))
        XCTAssertEqual(PDFPageRenderer.paperRect(weekPaper, page: page), Self.frozen123PaperRect(weekPaper, page: page))

        // The page's own strokes, under the 76 pt heading (no all-day event): the grid stroke around (300, 1,050),
        // the free memo's around (220, 2,400 + 440).
        let picture = try render(pdf: plain)
        XCTAssertEqual(picture.height, 76 + 3500)
        XCTAssertGreaterThan(picture.darkPixels(x: 250..<350, y: (76 + 1030)..<(76 + 1070)), 20, "the grid stroke is drawn")
        XCTAssertGreaterThan(picture.darkPixels(x: 200..<240, y: (76 + 2820)..<(76 + 2860)), 10, "the free memo's stroke is drawn")
        XCTAssertEqual(picture.darkPixels(x: 600..<990, y: (76 + 1030)..<(76 + 1070)), 0, "nothing past the grid stroke's end")
        XCTAssertTrue(recorder.lines.isEmpty, "a real page passes the door")
    }

    /// D17: the stroke of 11-11 that reaches into 11-12 is drawn on 11-12's PDF from `SpanComposer.neighborInk`
    /// — with its real id and its owner's cell, never a window name — and only the part on the paper shows.
    func testPDFDrawsNeighborInkWithoutPrefixedNames() throws {
        let plan = SpanPlan(kind: .day, weekStart: .monday, deviceClass: .iPad11, orientation: .portrait)
        let days = [DayKey(year: 2026, month: 11, day: 10), today, DayKey(year: 2026, month: 11, day: 12)]
        var middle = InkPage.empty(pageId: "d-2026-11-11")
        // Centre x 975: 11-11's stroke; its right part (x 1,000…1,300) lies over 11-12.
        middle.add(stroke("cross-11", cell: .grid, line(CGPoint(x: 650, y: 1000), CGPoint(x: 1300, y: 1000), nib: 6)))
        let pages = [InkPage.empty(pageId: "d-2026-11-10"), middle, InkPage.empty(pageId: "d-2026-11-12")]
        let virtual = SpanComposer.compose(pages, plan: plan)
        let layouts = days.map { dayLayout($0) }
        let layout = SpanLayout(pages: layouts, plan: plan, firstIndex: try XCTUnwrap(plan.index(of: "d-2026-11-10")))
        let ink = SpanComposer.neighborInk(for: "d-2026-11-12", from: virtual, layout: layout)
        XCTAssertEqual(ink.count, 1)
        let item = try XCTUnwrap(ink.first)
        XCTAssertEqual(item.pageId, "d-2026-11-11")
        XCTAssertEqual(item.stroke.id, "cross-11", "the real id")
        XCTAssertEqual(item.stroke.cell, .grid, "the owner's own cell")
        XCTAssertEqual(item.cellRect, CGRect(x: -1000, y: 0, width: 1000, height: 2400), "11-11's grid in 11-12's coordinates")
        for name in ink.flatMap({ [$0.stroke.id, $0.stroke.cell.raw] }) {
            XCTAssertFalse(SpanGuard.isWindowName(name), "\(name) is no window name")
        }

        // The one picture: the neighbour's stroke in a cell of its own, no window name anywhere.
        let picture = PDFPageRenderer.inkWithNeighbors(pages[2], cells: layouts[2].cells, neighborInk: ink)
        XCTAssertEqual(picture.strokes.map(\.id), ["cross-11"])
        let cell = try XCTUnwrap(picture.strokes.first?.cell)
        XCTAssertEqual(picture.cells[cell], item.cellRect)
        XCTAssertNil(layouts[2].cells[cell], "a cell the page does not have")
        for name in picture.strokes.flatMap({ [$0.id, $0.cell.raw] }) + picture.cells.keys.map(\.raw) {
            XCTAssertFalse(SpanGuard.isWindowName(name), "\(name) is no window name")
        }

        // The PDF of 11-12: the stroke's part x 0…300 at y 1,000 under the 76 pt heading (no all-day event).
        let paper = PaperContent.day(DayPaperContent(layout: layouts[2]))
        XCTAssertEqual(PDFPageRenderer.headingHeight(paper), 76)
        let withNeighbor = try render(pdf: PDFPageRenderer.render(paper, page: pages[2], title: "t", neighborInk: ink))
        let alone = try render(pdf: PDFPageRenderer.render(paper, page: pages[2], title: "t"))
        let rows = (76 + 990)..<(76 + 1010)
        XCTAssertGreaterThan(withNeighbor.darkPixels(x: 80..<290, y: rows), 100, "the incoming stroke is drawn")
        XCTAssertEqual(alone.darkPixels(x: 80..<290, y: rows), 0, "1.2.3's PDF of the page alone has none")
        XCTAssertEqual(withNeighbor.darkPixels(x: 320..<990, y: rows), 0, "nothing past the stroke's end")
        XCTAssertEqual(withNeighbor.width, 1000, "only the paper: no room is made for the part outside it")
        XCTAssertTrue(recorder.lines.isEmpty)
    }

    /// A neighbour stroke carrying a window name (what `SpanComposer.neighborInk` never makes) is left out of
    /// the PDF and reported; the PDF is still made.
    func testNeighborInkWithAWindowNameIsLeftOut() throws {
        let points = line(CGPoint(x: 650, y: 1000), CGPoint(x: 1300, y: 1000), nib: 6)
        let rect = CGRect(x: -1000, y: 0, width: 1000, height: 2400)
        let good = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("cross-11", cell: .grid, points), cellRect: rect)
        let prefixedId = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("d-2026-11-11|cross-11", cell: .grid, points), cellRect: rect)
        let prefixedCell = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("cross-12", cell: CellKey(raw: "d-2026-11-11|grid"), points), cellRect: rect)
        let virtualCell = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("cross-13", cell: CellKey(raw: "span~a~1"), points), cellRect: rect)
        XCTAssertEqual(TransferGuard.cleanNeighborInk([prefixedId, good, prefixedCell, virtualCell]), [good])
        XCTAssertEqual(recorder.lines.count, 3)

        recorder.lines.removeAll()
        let page = InkPage.empty(pageId: "d-2026-11-12")
        let paper = day(DayKey(year: 2026, month: 11, day: 12))
        let data = PDFPageRenderer.render(paper, page: page, title: "t", neighborInk: [prefixedId])
        XCTAssertFalse(data.isEmpty, "the PDF is still made")
        XCTAssertEqual(try render(pdf: data).darkPixels(x: 80..<290, y: (76 + 990)..<(76 + 1010)), 0, "without the stroke")
        XCTAssertEqual(recorder.lines.count, 1)
    }

    /// D17, §3.11: the day's free memo goes into the PDF when a stroke comes into it from a neighbour, as deep
    /// as that stroke's part over this page reaches; a neighbour's grid stroke does not count.
    func testDayPDFCountsIncomingFreeMemoInk() throws {
        let page = InkPage.empty(pageId: "d-2026-11-12")
        let layout = dayLayout(DayKey(year: 2026, month: 11, day: 12))
        let paper = PaperContent.day(DayPaperContent(layout: layout))
        let fromLeft = CGRect(x: -1000, y: 2400, width: 1000, height: 6000) // 11-11's extra in 11-12's coordinates
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page), CGRect(x: 0, y: 0, width: 1000, height: 2400))

        // x −300…200 over 11-12, y 300…500 in the memo: the deepest part over the page is its end (500 + 1.75).
        let shallow = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("memo-11", cell: .extra, line(CGPoint(x: 700, y: 300), CGPoint(x: 1200, y: 500))), cellRect: fromLeft)
        let bottom = try XCTUnwrap(PDFPageRenderer.neighborExtraBottom([shallow], extra: layout.extra, pageWidth: 1000))
        XCTAssertEqual(bottom, 501.75, accuracy: 0.01)
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: [shallow]), CGRect(x: 0, y: 0, width: 1000, height: 2400 + 1100))
        XCTAssertEqual(PDFPageRenderer.pageSize(paper, page: page, neighborInk: [shallow]), CGSize(width: 1000, height: 76 + 3500))

        // Deep only over its own page (y 5,000 at x −50), crossing into 11-12 at y 3,433⅓, ending at 300: the
        // part over 11-12 decides (3,435.08 → 3,900), not the whole stroke's 5,001.75 (→ 5,500).
        let deep = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("deep-11", cell: .extra, line(CGPoint(x: 950, y: 5000), CGPoint(x: 1100, y: 300), count: 2)), cellRect: fromLeft)
        let deepBottom = try XCTUnwrap(PDFPageRenderer.neighborExtraBottom([deep], extra: layout.extra, pageWidth: 1000))
        XCTAssertEqual(deepBottom, 5000 - 4700.0 / 3 + 1.75, accuracy: 0.01)
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: [deep]).height, 2400 + 3900, accuracy: 0.001)

        // From the right neighbour (its extra at x 1,000): x 900…1,400 reaches back over 11-12 by 100.
        let fromRight = SpanPDFInk(pageId: "d-2026-11-13", stroke: stroke("memo-13", cell: .extra, line(CGPoint(x: -100, y: 800), CGPoint(x: 400, y: 800))),
                                   cellRect: CGRect(x: 1000, y: 2400, width: 1000, height: 6000))
        XCTAssertEqual(try XCTUnwrap(PDFPageRenderer.neighborExtraBottom([fromRight], extra: layout.extra, pageWidth: 1000)), 801.75, accuracy: 0.01)

        // A neighbour's grid stroke is not the free memo (as the page's own grid stroke below 24:00 is not).
        let grid = SpanPDFInk(pageId: "d-2026-11-11", stroke: stroke("grid-11", cell: .grid, line(CGPoint(x: 700, y: 2600), CGPoint(x: 1200, y: 2700))),
                              cellRect: CGRect(x: -1000, y: 0, width: 1000, height: 2400))
        XCTAssertNil(PDFPageRenderer.neighborExtraBottom([grid], extra: layout.extra, pageWidth: 1000))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page, neighborInk: [grid]).height, 2400, accuracy: 0.001)

        // With the page's own free memo too: the deeper of the two.
        var own = page
        own.add(stroke("own", cell: .extra, line(CGPoint(x: 40, y: 1200), CGPoint(x: 400, y: 1300))))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: own, neighborInk: [shallow]).height,
                       2400 + PaperGrowth.exportTailHeight(inkBottom: own.inkBottoms()[.extra] ?? 0), accuracy: 0.001)
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: own, neighborInk: [deep]).height, 2400 + 3900, accuracy: 0.001)
    }

    /// D14: the PDF's page holding a window name gives no PDF (`renderFailed`), and is reported.
    func testAPDFPageWithAWindowNameIsRefused() throws {
        var page = InkPage.empty(pageId: "d-2026-11-12")
        page.add(stroke("d-2026-11-12|leak", cell: .grid, line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        let paper = day(DayKey(year: 2026, month: 11, day: 12))
        XCTAssertTrue(PDFPageRenderer.render(paper, page: page, title: "t").isEmpty)
        XCTAssertEqual(recorder.lines.count, 1)

        let base = FileManager.default.temporaryDirectory.appendingPathComponent("PaperSpanTests-\(UUID().uuidString)", isDirectory: true)
        self.base = base
        let store = InkPageStore(directory: base.appendingPathComponent("ink", isDirectory: true))
        let builder = ExportBuilder(store: store, directory: base.appendingPathComponent("export", isDirectory: true))
        XCTAssertThrowsError(try builder.exportPDF(paper: paper, page: page, kind: .day, focus: DayKey(year: 2026, month: 11, day: 12))) { error in
            XCTAssertEqual(error as? ExportError, .renderFailed)
        }
        var virtual = InkPage.empty(pageId: "span~day~1")
        virtual.add(stroke("x", cell: .grid, line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        XCTAssertTrue(PDFPageRenderer.render(paper, page: virtual, title: "t").isEmpty, "the virtual page never makes a PDF")
        XCTAssertEqual(recorder.lines.count, 3)
    }

    /// D14, §3.11: the data file leaves out a stored page holding a window name and writes the others as 1.2.3
    /// does; the import leaves such a page out, counted with the skipped pages.
    func testDataFileAndImportDoorsRefuseWindowNames() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("PaperSpanTests-\(UUID().uuidString)", isDirectory: true)
        self.base = base
        let folder = base.appendingPathComponent("ink", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = InkPageStore(directory: folder)
        var good = InkPage.empty(pageId: "d-2026-11-11")
        good.add(stroke("fine", cell: .grid, line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        var leaked = InkPage.empty(pageId: "d-2026-11-12")
        leaked.add(stroke("leak", cell: CellKey(raw: "d-2026-11-12|grid"), line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        try store.save(good)
        try store.save(leaked)
        let builder = ExportBuilder(store: store, directory: base.appendingPathComponent("export", isDirectory: true))
        let result = try await builder.exportJSON { _, _ in }
        XCTAssertEqual(result.pageCount, 1)
        let text = String(decoding: try Data(contentsOf: result.url), as: UTF8.self)
        XCTAssertTrue(text.contains("d-2026-11-11"))
        XCTAssertFalse(text.contains("d-2026-11-12"), "the page with a window name stays out of the file")
        XCTAssertEqual(recorder.lines.count, 1)
        XCTAssertTrue(recorder.lines[0].contains("d-2026-11-12"))

        recorder.lines.removeAll()
        let outcome = InkImport.Outcome(pages: [good, leaked], skipped: 1, pageCount: 3, isAppExport: true)
        let kept = TransferGuard.importable(outcome)
        XCTAssertEqual(kept.pages, [good])
        XCTAssertEqual(kept.skipped, 2, "counted with the pages the import could not use")
        XCTAssertEqual(kept.pageCount, 3)
        XCTAssertTrue(kept.isAppExport)
        XCTAssertEqual(recorder.lines.count, 1)
        let clean = InkImport.Outcome(pages: [good], skipped: 0, pageCount: 1, isAppExport: false)
        XCTAssertEqual(TransferGuard.importable(clean), clean, "a 1.2.3 file imports as before")
        XCTAssertEqual(recorder.lines.count, 1)
    }

    /// §3.11: the parse `CalendarRootScreen.runImport` makes (`InkImport.parse` → `InkImport.pages`) carries a
    /// page with a window name as it is, so the door after it is what keeps it out — a prefixed cell, a
    /// prefixed stroke id or a virtual page id; the file's other pages and a file without such names come
    /// through unchanged.
    func testTheImportDoorStopsWhatTheParseCarries() throws {
        var good = InkPage.empty(pageId: "w-2026-11-09")
        good.add(stroke("fine", cell: .grid, line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        var prefixedCell = InkPage.empty(pageId: "d-2026-11-12")
        prefixedCell.add(stroke("leak-cell", cell: CellKey(raw: "d-2026-11-12|grid"), line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        var prefixedId = InkPage.empty(pageId: "d-2026-11-13")
        prefixedId.add(stroke("d-2026-11-13|leak-id", cell: .grid, line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))
        var virtual = InkPage.empty(pageId: "span~day~3")
        virtual.add(stroke("leak-page", cell: .grid, line(CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200))))

        func parse(_ pages: [InkPage]) throws -> InkImport.Outcome {
            let data = AppExport.encode(AppExport.Document(exportedAt: "2026-11-13T09:00:00+09:00", app: "test", pages: pages))
            return InkImport.pages(try InkImport.parse(data))
        }
        let parsed = try parse([good, prefixedCell, prefixedId, virtual])
        XCTAssertEqual(parsed.pages.map(\.pageId), ["w-2026-11-09", "d-2026-11-12", "d-2026-11-13", "span~day~3"],
                       "the parse leaves the window names to the door")
        let kept = TransferGuard.importable(parsed)
        XCTAssertEqual(kept.pages.map(\.pageId), ["w-2026-11-09"])
        XCTAssertEqual(kept.skipped, parsed.skipped + 3)
        XCTAssertEqual(kept.pageCount, parsed.pageCount)
        XCTAssertEqual(recorder.lines.count, 3)

        recorder.lines.removeAll()
        let plain = try parse([good])
        XCTAssertEqual(TransferGuard.importable(plain), plain, "a file without window names is imported as 1.2.3 imports it")
        XCTAssertTrue(recorder.lines.isEmpty)
    }
}
