import Darwin
import InkModel
import Layout
import PDFKit
import UIKit
import XCTest
@testable import TegakiCalendar

/// Simulator tests of the export (M6_CONTRACT §2.2, §2.3, §7.2, D7): the JSON holds every stored
/// page worth exporting in `pageId` order, migrated off the old band cells, and goes back through
/// the import door unchanged (a second import changes nothing); the progress and the failures; a
/// 25 MB export is parsed page by page (the resident memory grows by far less than 8 × the file);
/// the PDF is one page of the §1.4 size for every page kind, without the current-time line, with
/// the §1.5 file name and the title in its metadata. The page files and the export directory live in
/// a temporary directory; nothing touches iCloud.
@MainActor
final class ExportBuilderTests: XCTestCase {
    private var base: URL!
    private var store: InkPageStore!
    private var exportDirectory: URL!
    private var builder: ExportBuilder!

    private let month = YearMonth(year: 2026, month: 10)
    private let wednesday = DayKey(year: 2026, month: 10, day: 7)
    /// 10:00 on 2026-10-07 (the screenshot mode's 「今日」, so the week and day pages hold today).
    private var now: Date { ScreenshotMode.todayInstant(for: month) }

    /// The export's clock and calendar are Tokyo's, so the file name and `exportedAt` do not depend
    /// on the CI's time zone: 2026-10-17 21:03 JST.
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private static var tokyoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
    private static let exportedAt = tokyoCalendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 21, minute: 3))!
    private static let exportedAtText = "2026-10-17T21:03:00+09:00"
    private static let appText = "ios/1.0 (12)"
    private static let jsonFileName = "てがきカレンダー 手書き 2026-10-17.json"

    override func setUp() async throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("ExportBuilderTests-\(UUID().uuidString)", isDirectory: true)
        let pages = base.appendingPathComponent("ink", isDirectory: true)
        try FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)
        store = InkPageStore(directory: pages)
        exportDirectory = base.appendingPathComponent("export", isDirectory: true)
        builder = ExportBuilder(store: store, directory: exportDirectory, now: { Self.exportedAt }, appText: Self.appText,
                                calendar: Self.tokyoCalendar, timeZone: Self.tokyo)
    }

    override func tearDown() async throws {
        builder = nil
        try? FileManager.default.removeItem(at: base)
    }

    // MARK: - Helpers

    private func points(from: CGPoint, to: CGPoint, count: Int = 12, nib: CGFloat = 3.5) -> [InkPoint] {
        (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(max(count - 1, 1))
            return InkPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t, dtMs: i * 10,
                            sizeW: nib, sizeH: nib, opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
    }

    /// The four demo pages (month, week, day, year) plus a stroke with `dev` and a tombstone on the
    /// month page, saved to the store together with an empty fifth page (counted, never written).
    /// Keyed by page id.
    private func saveSamplePages() throws -> [String: InkPage] {
        var monthPage = ScreenshotMode.demoPage(for: month)
        monthPage.add(InkStroke(id: "with-dev", cell: .day(wednesday), tool: .pen, color: "#2563eb", t: 1_760_000_003_000, dev: "ipad-test",
                                points: points(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 60, y: 40))))
        monthPage.remove(ids: ["erased-elsewhere"], at: 1_760_000_009_000)
        let pages = [
            monthPage,
            ScreenshotMode.demoPage(kind: .week, focus: wednesday),
            ScreenshotMode.demoPage(kind: .day, focus: wednesday),
            ScreenshotMode.demoPage(kind: .year, focus: wednesday),
        ]
        for page in pages {
            try store.save(page)
        }
        try store.save(InkPage.empty(pageId: "m1-2026-11"))
        return Dictionary(uniqueKeysWithValues: pages.map { ($0.pageId, $0) })
    }

    /// The export file as the import door reads it: the app document and the number of dropped pages.
    private func parseApp(_ data: Data, file: StaticString = #filePath, line: UInt = #line) throws -> (AppExport.Document, Int) {
        let parsed = try InkImport.parse(data)
        guard case .app(let document, let skipped) = parsed else {
            XCTFail("not an app export: \(parsed)", file: file, line: line)
            throw ExportError.renderFailed
        }
        return (document, skipped)
    }

    /// The files in the export directory, sorted; [] when the directory does not exist.
    private func exportFiles() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: exportDirectory.path)) ?? []).sorted()
    }

    private func fileSize(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.intValue ?? -1
    }

    /// The month paper as the screen builds it (`CalendarRootScreen.makePaper` is private): the
    /// screenshot mode's demo events, the page's ink bottoms, the holiday names of the grid (the
    /// engine's own, the same values `JapaneseHolidays.names(for:)` gives).
    private func monthPaper(page: InkPage) -> PaperContent {
        let layout = MonthLayoutEngine.layout(MonthLayoutInput(month: month, events: ScreenshotMode.demoEvents(for: month), inkBottoms: page.inkBottoms(), now: now))
        var holidays: [DayKey: String] = [:]
        for label in layout.dateLabels {
            if let name = label.holidayName { holidays[label.day] = name }
        }
        return .month(MonthPaperContent(layout: layout, labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: holidays))
    }

    private func weekPaper() -> PaperContent {
        .week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: ScreenshotMode.demoEvents(for: month), inkBottoms: [:], now: now))))
    }

    private func dayPaper() -> PaperContent {
        .day(DayPaperContent(layout: DayLayoutEngine.layout(DayLayoutInput(day: wednesday, events: ScreenshotMode.demoEvents(for: month), inkBottoms: [:], now: now))))
    }

    private func yearPaper(page: InkPage) -> PaperContent {
        let layout = YearLayoutEngine.layout(YearLayoutInput(year: 2026, events: ScreenshotMode.demoEvents(for: month), inkBottoms: page.inkBottoms(), now: now))
        return .year(YearPaperContent(layout: layout, monthNames: (1...12).map { "\($0)月" }))
    }

    private func mediaBox(_ data: Data, file: StaticString = #filePath, line: UInt = #line) throws -> CGRect {
        let document = try XCTUnwrap(PDFDocument(data: data), "not a PDF", file: file, line: line)
        XCTAssertEqual(document.pageCount, 1, "one page", file: file, line: line)
        let page = try XCTUnwrap(document.page(at: 0), file: file, line: line)
        return page.bounds(for: .mediaBox)
    }

    /// The PDF bytes without the fields CoreGraphics derives from the clock (`/CreationDate`,
    /// `/ModDate` and the trailer's `/ID`), so two renders of the same content compare equal
    /// whatever the second they ran in. ISO Latin 1 maps every byte to one character, so nothing
    /// else changes.
    private static func stableBytes(_ data: Data) -> Data {
        guard var text = String(data: data, encoding: .isoLatin1) else { return data }
        for pattern in ["/CreationDate \\(D:[^)]*\\)", "/ModDate \\(D:[^)]*\\)", "/ID \\[[^\\]]*\\]"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.data(using: .isoLatin1) ?? data
    }

    /// `phys_footprint` of this process (the number Xcode's memory gauge shows), in bytes.
    private static func physicalFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }

    private func assertExportThrows(_ expected: ExportError, file: StaticString = #filePath, line: UInt = #line,
                                    progress: @escaping @MainActor (Int, Int) -> Void = { _, _ in }) async {
        do {
            let result = try await builder.exportJSON(progress: progress)
            XCTFail("no error, wrote \(result.fileName)", file: file, line: line)
        } catch let error as ExportError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    // MARK: - JSON

    func testJSONExportWritesEveryStoredPageSorted() async throws {
        let saved = try saveSamplePages()
        XCTAssertEqual(store.allPageIds().count, 5, "four pages with ink and one empty page")

        let result = try await builder.exportJSON { _, _ in }
        XCTAssertEqual(result.kind, .json)
        XCTAssertEqual(result.pageCount, 4, "the empty page is not written")
        XCTAssertEqual(result.fileName, Self.jsonFileName)
        XCTAssertEqual(result.url.lastPathComponent, result.fileName)
        XCTAssertEqual(result.url.deletingLastPathComponent().standardizedFileURL.path, exportDirectory.standardizedFileURL.path)
        XCTAssertEqual(exportFiles(), [Self.jsonFileName])
        XCTAssertEqual(try fileSize(result.url), result.byteCount, "byteCount is the file's size")

        let data = try Data(contentsOf: result.url)
        XCTAssertEqual(data.count, result.byteCount)
        XCTAssertTrue(String(decoding: data.prefix(12), as: UTF8.self).hasPrefix("{\n  \"app\": "), "readable JSON (§1.3)")
        let (document, skipped) = try parseApp(data)
        XCTAssertEqual(skipped, 0)
        XCTAssertEqual(document.exportedAt, Self.exportedAtText)
        XCTAssertEqual(document.app, Self.appText)
        XCTAssertEqual(document.pages.map(\.pageId), ["d-2026-10-07", "m1-2026-10", "w-2026-10-05", "y-2026"], "pageId order, no empty page")
        for page in document.pages {
            XCTAssertEqual(page, saved[page.pageId], page.pageId)
        }
        let monthPage = try XCTUnwrap(document.pages.first { $0.pageId == "m1-2026-10" })
        XCTAssertEqual(monthPage.strokes["with-dev"]?.dev, "ipad-test", "dev survives (§1.1)")
        XCTAssertEqual(monthPage.deleted["erased-elsewhere"], 1_760_000_009_000, "the tombstone survives (M6-6)")

        // The streamed file is byte for byte the document (§1.1: header + pages + footer == encode).
        let whole = AppExport.Document(exportedAt: Self.exportedAtText, app: Self.appText, pages: document.pages)
        XCTAssertEqual(data, AppExport.encode(whole))
    }

    func testJSONExportMigratesBandCells() async throws {
        // A week page saved before M4b: a band stroke in "allday:2026-10-07" next to a grid stroke.
        var week = InkPage.empty(pageId: "w-2026-10-05")
        week.add(InkStroke(id: "band", cell: .allDay(wednesday), tool: .pen, color: "#1f2937", t: 1_760_000_000_000,
                           points: points(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 80, y: 12))))
        week.add(InkStroke(id: "grid", cell: .grid, tool: .marker, color: "#fde047", t: 1_760_000_001_000,
                           points: points(from: CGPoint(x: 500, y: 800), to: CGPoint(x: 600, y: 800))))
        try store.save(week)
        XCTAssertTrue(BandMigration.needsMigration(store.load(week.pageId)), "the store keeps the old cell")

        let result = try await builder.exportJSON { _, _ in }
        XCTAssertEqual(result.pageCount, 1)
        let data = try Data(contentsOf: result.url)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("allday:"), "no band cell in the file (0-7)")
        let (document, _) = try parseApp(data)
        let exported = try XCTUnwrap(document.pages.first)
        XCTAssertEqual(Set(exported.strokes.values.map { $0.cell }), [.grid])
        XCTAssertEqual(exported, BandMigration.migrate(week))
        XCTAssertNotEqual(exported, week)
        // The band stroke moved by Wednesday's column origin (64 + 2 × 190.857…), the grid stroke stayed.
        XCTAssertEqual(exported.strokes["band"]?.points.first?.x ?? 0, 10 + PaperSpec.weekGutter + 2 * PaperSpec.weekColumnWidth, accuracy: 0.11)
        XCTAssertEqual(exported.strokes["grid"], week.strokes["grid"])
    }

    func testJSONExportRoundTripsThroughImport() async throws {
        let saved = try saveSamplePages()
        let result = try await builder.exportJSON { _, _ in }
        let data = try Data(contentsOf: result.url)

        let parsed = try InkImport.parse(data)
        guard case .app = parsed else { return XCTFail("not the app format") }
        let outcome = InkImport.pages(parsed)
        XCTAssertTrue(outcome.isAppExport)
        XCTAssertEqual(outcome.skipped, 0)
        XCTAssertEqual(outcome.pageCount, 4)
        XCTAssertEqual(outcome.pages.count, 4)

        // An empty second store, imported into through the engine like the settings' import door.
        let directory2 = base.appendingPathComponent("ink2", isDirectory: true)
        try FileManager.default.createDirectory(at: directory2, withIntermediateDirectories: true)
        let store2 = InkPageStore(directory: directory2)
        let engine = SyncEngine(store: store2, stateStore: SyncStateStore(fileURL: store2.stateFileURL), database: InMemoryCloudDatabase())
        let first = try await engine.importPages(outcome.pages) { _, _ in }
        XCTAssertEqual(first.pagesSeen, 4)
        XCTAssertEqual(first.pagesChanged, 4)
        XCTAssertEqual(first.strokesAdded, saved.values.reduce(0) { $0 + $1.liveStrokeCount })
        XCTAssertEqual(Set(store2.allPageIds()), Set(saved.keys))
        for (pageId, original) in saved {
            XCTAssertEqual(store2.load(pageId), original, pageId)
        }

        // The same file again: nothing changes (`InkPage.merge(a, a) == a`, §1.1).
        let again = try await engine.importPages(outcome.pages) { _, _ in }
        XCTAssertEqual(again.pagesChanged, 0)
        XCTAssertEqual(again.strokesAdded, 0)
        XCTAssertEqual(again.pagesSeen, 4)
        for (pageId, original) in saved {
            XCTAssertEqual(store2.load(pageId), original, pageId)
        }
        await engine.waitUntilIdle()
    }

    func testJSONExportReportsProgress() async throws {
        try store.save(ScreenshotMode.demoPage(for: month))
        try store.save(InkPage.empty(pageId: "m1-2026-11"))
        try store.save(ScreenshotMode.demoPage(kind: .day, focus: wednesday))
        var done: [Int] = []
        var totals: [Int] = []
        let result = try await builder.exportJSON { d, t in
            done.append(d)
            totals.append(t)
        }
        XCTAssertEqual(done, [1, 2, 3], "one call per stored page, the empty one included")
        XCTAssertEqual(totals, [3, 3, 3])
        XCTAssertEqual(result.pageCount, 2)
    }

    func testNothingToExport() async throws {
        // An empty store.
        XCTAssertEqual(store.allPageIds(), [])
        await assertExportThrows(.nothingToExport)
        XCTAssertEqual(exportFiles(), [], "no file is left behind")

        // Only an empty page: counted by the progress, nothing to write.
        try store.save(InkPage.empty(pageId: "m1-2026-10"))
        var calls: [String] = []
        await assertExportThrows(.nothingToExport) { done, total in calls.append("\(done)/\(total)") }
        XCTAssertEqual(calls, ["1/1"])
        XCTAssertEqual(exportFiles(), [])
    }

    func testCleanUpRemovesPreviousFiles() async throws {
        // A missing directory is nothing to do.
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportDirectory.path))
        builder.cleanUp()
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportDirectory.path))

        // Leftovers of earlier exports go, the directory stays.
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: exportDirectory.appendingPathComponent("てがきカレンダー 手書き 2026-10-01.json"))
        try Data("old".utf8).write(to: exportDirectory.appendingPathComponent("てがきカレンダー 2026年9月 月.pdf"))
        XCTAssertEqual(exportFiles().count, 2)
        builder.cleanUp()
        XCTAssertEqual(exportFiles(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportDirectory.path))

        // Every export starts with the clean-up (0-14): one file at a time in the directory.
        let page = ScreenshotMode.demoPage(for: month)
        try store.save(page)
        let pdf = try builder.exportPDF(paper: monthPaper(page: page), page: page, kind: .month, focus: wednesday)
        XCTAssertEqual(exportFiles(), [pdf.fileName])
        let json = try await builder.exportJSON { _, _ in }
        XCTAssertEqual(exportFiles(), [json.fileName])
        let pdfAgain = try builder.exportPDF(paper: monthPaper(page: page), page: page, kind: .month, focus: wednesday)
        XCTAssertEqual(exportFiles(), [pdfAgain.fileName])
    }

    /// D7's big file: 8 pages × 1,000 strokes × 50 points (about 25 MB of readable JSON) go out and
    /// come back equal, and the import door reads them page by page: the process's resident memory
    /// grows by far less than 8 × the file (a whole JSON tree would be about 20 ×). The measured
    /// sizes and times are printed as `export-test:` for docs/M6.md.
    func testLargeExportImportsPageByPage() async throws {
        let pageIds = (1...8).map { String(format: "m1-2027-%02d", $0) }
        var originals: [String: InkPage] = [:]
        let buildStart = Date()
        for (index, pageId) in pageIds.enumerated() {
            var page = InkPage.empty(pageId: pageId)
            let day = DayKey(year: 2027, month: index + 1, day: 1)
            for s in 0..<1000 {
                let seed = CGFloat(s)
                let strokePoints = (0..<50).map { k -> InkPoint in
                    let i = CGFloat(k)
                    return InkPoint(
                        x: 12.3 + i * 3.7 + seed * 0.01, y: 20.1 + 9 * sin(i * 0.37 + seed * 0.1), dtMs: k * 8 + s % 7,
                        sizeW: 3.25 + 0.5 * sin(i * 0.2), sizeH: 3.25 + 0.5 * cos(i * 0.2), opacity: 0.95,
                        force: 0.4 + 0.3 * sin(i * 0.11 + seed), azimuth: 1.234 + 0.01 * i, altitude: 0.567 + 0.002 * i
                    )
                }
                page.add(InkStroke(id: "s-\(index)-\(s)", cell: .day(day), tool: s % 4 == 0 ? .marker : .pen,
                                   color: s % 4 == 0 ? "#fde047" : "#1f2937", t: 1_760_000_000_000 + s, dev: "ipad-test", points: strokePoints))
            }
            try store.save(page)
            originals[pageId] = page
        }
        let buildSeconds = Date().timeIntervalSince(buildStart)

        let exportStart = Date()
        let result = try await builder.exportJSON { _, _ in }
        let exportSeconds = Date().timeIntervalSince(exportStart)
        XCTAssertEqual(result.pageCount, 8)
        XCTAssertEqual(try fileSize(result.url), result.byteCount)

        let beforeLoad = try XCTUnwrap(Self.physicalFootprint())
        let data = try Data(contentsOf: result.url)
        XCTAssertEqual(data.count, result.byteCount)
        let beforeParse = try XCTUnwrap(Self.physicalFootprint())
        let parseStart = Date()
        let parsed = try InkImport.parse(data)
        let parseSeconds = Date().timeIntervalSince(parseStart)
        let afterParse = try XCTUnwrap(Self.physicalFootprint())

        guard case .app(let document, let skipped) = parsed else { return XCTFail("not the app format") }
        XCTAssertEqual(skipped, 0)
        XCTAssertEqual(document.pages.map(\.pageId), pageIds)
        for page in document.pages {
            XCTAssertEqual(page.liveStrokeCount, 1000, page.pageId)
            XCTAssertEqual(page, originals[page.pageId], page.pageId)
        }

        let parseGrowth = afterParse > beforeParse ? afterParse - beforeParse : 0
        let totalGrowth = afterParse > beforeLoad ? afterParse - beforeLoad : 0
        let size = UInt64(data.count)
        XCTAssertLessThan(parseGrowth, size * 8, "the parse holds one page's tree at a time (0-11)")
        let mb = Double(data.count) / 1_048_576
        print(String(format: "export-test: large export %d bytes (%.1f MB), 8 pages × 1000 strokes × 50 points; build %.2f s, export %.2f s, parse %.2f s",
                     data.count, mb, buildSeconds, exportSeconds, parseSeconds))
        print(String(format: "export-test: phys_footprint before load %llu, before parse %llu, after parse %llu; parse +%llu bytes (%.2f × the file), load+parse +%llu bytes (%.2f × the file)",
                     beforeLoad, beforeParse, afterParse, parseGrowth, Double(parseGrowth) / Double(data.count), totalGrowth, Double(totalGrowth) / Double(data.count)))
    }

    // MARK: - PDF

    func testPDFHasOnePageAndOverviewSize() throws {
        let page = ScreenshotMode.demoPage(for: month)
        let paper = monthPaper(page: page)
        guard case .month(let content) = paper else { return XCTFail("month paper") }
        let layout = content.layout
        XCTAssertTrue(page.liveStrokes.contains { $0.cell.isMemo }, "the demo page has a dot in the memo area")

        // With ink in the memo area: the whole paper (6 rows + memo).
        XCTAssertEqual(PDFPageRenderer.headingHeight(paper), 36 + 28)
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: page), CGRect(origin: .zero, size: layout.size))
        XCTAssertEqual(PDFPageRenderer.pageSize(paper, page: page), CGSize(width: 1400, height: 36 + 28 + layout.size.height))
        let data = PDFPageRenderer.render(paper, page: page, title: "2026年10月")
        XCTAssertFalse(data.isEmpty)
        let box = try mediaBox(data)
        XCTAssertEqual(box.width, 1400, accuracy: 0.5)
        XCTAssertEqual(box.height, 36 + 28 + layout.size.height, accuracy: 0.5)

        // Without it: the overview rectangle (M6-3), 1400 × memo.minY under the heading.
        var noMemo = page
        noMemo.remove(ids: ["demo-stroke-dot"], at: 1_760_000_010_000)
        XCTAssertFalse(noMemo.liveStrokes.contains { $0.cell.isMemo })
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: noMemo), CGRect(x: 0, y: 0, width: 1400, height: layout.memo.minY))
        XCTAssertEqual(PDFPageRenderer.paperRect(paper, page: noMemo).size, ZoomPolicy.overviewSize(layout))
        XCTAssertEqual(PDFPageRenderer.pageSize(paper, page: noMemo), CGSize(width: 1400, height: 36 + 28 + layout.memo.minY))
        let overview = PDFPageRenderer.render(paper, page: noMemo, title: "2026年10月")
        let overviewBox = try mediaBox(overview)
        XCTAssertEqual(overviewBox.width, 1400, accuracy: 0.5)
        XCTAssertEqual(overviewBox.height, 36 + 28 + layout.memo.minY, accuracy: 0.5)
        XCTAssertLessThan(overviewBox.height, box.height)
    }

    func testPDFRendersEveryKind() throws {
        XCTAssertEqual(PDFPageRenderer.laneStep(.week), 25)
        XCTAssertEqual(PDFPageRenderer.laneStep(.day), 24)
        XCTAssertEqual(PDFPageRenderer.laneStep(.month), 0)
        XCTAssertEqual(PDFPageRenderer.laneStep(.year), 0)

        // Week: the date row, the band (家族旅行 and 締切 fall in this week) and the 24 hours.
        let week = weekPaper()
        guard case .week(let weekContent) = week else { return XCTFail("week paper") }
        let weekPage = ScreenshotMode.demoPage(kind: .week, focus: wednesday)
        let weekLanes = weekContent.layout.allDayBand.laneCount
        XCTAssertGreaterThan(weekLanes, 0)
        XCTAssertNotNil(weekContent.layout.nowLine, "today is in the week")
        let weekHeight = 36 + 40 + CGFloat(weekLanes) * 25 + 6 + weekContent.layout.size.height
        XCTAssertEqual(PDFPageRenderer.headingHeight(week), 36 + 40 + CGFloat(weekLanes) * 25 + 6)
        XCTAssertEqual(PDFPageRenderer.pageSize(week, page: weekPage), CGSize(width: 1400, height: weekHeight))
        let weekData = PDFPageRenderer.render(week, page: weekPage, title: PageNavigation.title(.week, focus: wednesday))
        let weekBox = try mediaBox(weekData)
        XCTAssertEqual(weekBox.width, 1400, accuracy: 0.5)
        XCTAssertEqual(weekBox.height, weekHeight, accuracy: 0.5)

        // Day: the band's lanes are 24 apart.
        let day = dayPaper()
        guard case .day(let dayContent) = day else { return XCTFail("day paper") }
        let dayPage = ScreenshotMode.demoPage(kind: .day, focus: wednesday)
        let dayLanes = dayContent.layout.allDayBand.laneCount
        XCTAssertGreaterThan(dayLanes, 0)
        XCTAssertNotNil(dayContent.layout.nowLine, "the day is today")
        let dayHeight = 36 + 40 + CGFloat(dayLanes) * 24 + 6 + dayContent.layout.size.height
        XCTAssertEqual(PDFPageRenderer.pageSize(day, page: dayPage), CGSize(width: 1000, height: dayHeight))
        let dayData = PDFPageRenderer.render(day, page: dayPage, title: PageNavigation.title(.day, focus: wednesday))
        let dayBox = try mediaBox(dayData)
        XCTAssertEqual(dayBox.width, 1000, accuracy: 0.5)
        XCTAssertEqual(dayBox.height, dayHeight, accuracy: 0.5)

        // A week / day without an all-day event has no band at all (0 lanes → 0, not 6).
        let quietWeek = PaperContent.week(WeekPaperContent(layout: WeekLayoutEngine.layout(WeekLayoutInput(focus: DayKey(year: 2026, month: 11, day: 18), events: [], inkBottoms: [:], now: now))))
        XCTAssertEqual(PDFPageRenderer.headingHeight(quietWeek), 36 + 40)
        let quietDay = PaperContent.day(DayPaperContent(layout: DayLayoutEngine.layout(DayLayoutInput(day: DayKey(year: 2026, month: 11, day: 18), events: [], inkBottoms: [:], now: now))))
        XCTAssertEqual(PDFPageRenderer.headingHeight(quietDay), 36 + 40)

        // Year: the month-name row and the 31 rows.
        let yearPage = ScreenshotMode.demoPage(kind: .year, focus: wednesday)
        let year = yearPaper(page: yearPage)
        guard case .year(let yearContent) = year else { return XCTFail("year paper") }
        let yearHeight = 36 + 28 + yearContent.layout.size.height
        XCTAssertEqual(PDFPageRenderer.pageSize(year, page: yearPage), CGSize(width: 1400, height: yearHeight))
        let yearData = PDFPageRenderer.render(year, page: yearPage, title: "2026年")
        let yearBox = try mediaBox(yearData)
        XCTAssertEqual(yearBox.width, 1400, accuracy: 0.5)
        XCTAssertEqual(yearBox.height, yearHeight, accuracy: 0.5)

        // The current-time line is not drawn (0-13 / M6-23): `stripNowLine` empties it, and the
        // render of the live layout equals the render of the layout without a now line.
        XCTAssertNil(PDFPageRenderer.stripNowLine(week).layout.nowLine)
        XCTAssertNil(PDFPageRenderer.stripNowLine(day).layout.nowLine)
        guard case .week(let strippedWeek) = PDFPageRenderer.stripNowLine(week) else { return XCTFail("still a week") }
        XCTAssertEqual(strippedWeek.layout.todayColumn, weekContent.layout.todayColumn, "the today column stays")
        XCTAssertEqual(strippedWeek.layout.timedBoxes, weekContent.layout.timedBoxes)
        guard case .day(let strippedDay) = PDFPageRenderer.stripNowLine(day) else { return XCTFail("still a day") }
        XCTAssertTrue(strippedDay.layout.isToday, "isToday stays")
        guard case .month = PDFPageRenderer.stripNowLine(monthPaper(page: ScreenshotMode.demoPage(for: month))) else { return XCTFail("still a month") }

        var noLineWeekLayout = weekContent.layout
        noLineWeekLayout.nowLine = nil
        let noLineWeek = PDFPageRenderer.render(.week(WeekPaperContent(layout: noLineWeekLayout)), page: weekPage, title: PageNavigation.title(.week, focus: wednesday))
        XCTAssertEqual(weekData.count, noLineWeek.count)
        XCTAssertEqual(Self.stableBytes(weekData), Self.stableBytes(noLineWeek), "the week PDF ignores the now line")

        var noLineDayLayout = dayContent.layout
        noLineDayLayout.nowLine = nil
        let noLineDay = PDFPageRenderer.render(.day(DayPaperContent(layout: noLineDayLayout)), page: dayPage, title: PageNavigation.title(.day, focus: wednesday))
        XCTAssertEqual(dayData.count, noLineDay.count)
        XCTAssertEqual(Self.stableBytes(dayData), Self.stableBytes(noLineDay), "the day PDF ignores the now line")
    }

    func testPDFFileNameAndMetadata() throws {
        let page = ScreenshotMode.demoPage(for: month)
        let result = try builder.exportPDF(paper: monthPaper(page: page), page: page, kind: .month, focus: wednesday)
        XCTAssertEqual(result.kind, .pdf)
        XCTAssertEqual(result.pageCount, 1)
        XCTAssertEqual(result.fileName, "てがきカレンダー 2026年10月 月.pdf")
        XCTAssertEqual(result.fileName, AppExport.pdfFileName(kind: .month, focus: wednesday))
        XCTAssertEqual(result.url.lastPathComponent, result.fileName)
        XCTAssertEqual(result.url.deletingLastPathComponent().standardizedFileURL.path, exportDirectory.standardizedFileURL.path)
        XCTAssertEqual(try fileSize(result.url), result.byteCount)
        XCTAssertGreaterThan(result.byteCount, 0)

        let document = try XCTUnwrap(PDFDocument(url: result.url))
        XCTAssertEqual(document.pageCount, 1)
        let attributes = document.documentAttributes
        let title = (attributes?[PDFDocumentAttribute.titleAttribute] as? String) ?? (attributes?["Title"] as? String)
        XCTAssertEqual(title, PageNavigation.title(.month, focus: wednesday))
        XCTAssertEqual(title, "2026年10月")
        let creator = (attributes?[PDFDocumentAttribute.creatorAttribute] as? String) ?? (attributes?["Creator"] as? String)
        XCTAssertEqual(creator, PDFPageRenderer.creator)
        XCTAssertEqual(creator, "てがきカレンダー")

        // The other kinds' names come from the same function (K fixes its six examples).
        let weekPage = ScreenshotMode.demoPage(kind: .week, focus: wednesday)
        let week = try builder.exportPDF(paper: weekPaper(), page: weekPage, kind: .week, focus: wednesday)
        XCTAssertEqual(week.fileName, "てがきカレンダー 2026年10月5日〜10月11日 週.pdf")
        XCTAssertEqual(exportFiles(), [week.fileName], "the month PDF was cleaned up first")
        let weekDocument = try XCTUnwrap(PDFDocument(url: week.url))
        let weekTitle = (weekDocument.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String) ?? (weekDocument.documentAttributes?["Title"] as? String)
        XCTAssertEqual(weekTitle, "2026年10月5日〜10月11日")
        let dayPage = ScreenshotMode.demoPage(kind: .day, focus: wednesday)
        let day = try builder.exportPDF(paper: dayPaper(), page: dayPage, kind: .day, focus: wednesday)
        XCTAssertEqual(day.fileName, "てがきカレンダー 2026年10月7日(水) 日.pdf")
        let yearPage = ScreenshotMode.demoPage(kind: .year, focus: wednesday)
        let year = try builder.exportPDF(paper: yearPaper(page: yearPage), page: yearPage, kind: .year, focus: wednesday)
        XCTAssertEqual(year.fileName, "てがきカレンダー 2026年 年.pdf")
        XCTAssertEqual(exportFiles(), [year.fileName])
    }
}
