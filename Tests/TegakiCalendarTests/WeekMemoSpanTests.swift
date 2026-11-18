@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.3 (docs/M7C_CONTRACT.md §5.2, D3 (4), D15, D16, K-2, K-11 (6); the week memo's plan §4, §9.3): the week memo below
// 24:00 on the app's two paths. The Kit lays a week out with its memo only when asked (`WeekLayoutInput.freeMemo`,
// default false: the frozen tests keep 1.2.3's week); the app asks at exactly two places, the one-page path
// (`CalendarRootScreen.makePaper`) and the joined path (`SpanSession.pageLayout`). Here: those two call sites read from
// the sources, the memo's floor on a window (D16 as docs/M7C.md reads it), where a new stroke and a moved one are filed
// (`extra` from 24:00 down, `grid` above), the `grid` strokes reaching below 24:00 of the compat fixture 4, no event in
// the memo, the growth and its cap through the real canvas on one page and on three, and the two week starts' own memos.
// No real sleep: the sessions' timers wait on the bed's `sessionSleeper`, the canvas's watch on `canvasSleeper`.

@MainActor
final class WeekMemoSpanTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var canvasSleeper: TestSleeper!
    private var coordinators: [InkCanvasView.Coordinator] = []
    private var strokeClock: TimeInterval = 0

    private let w1109 = "w-2026-11-09"
    private let w1116 = "w-2026-11-16"
    private let w1123 = "w-2026-11-23"
    private let w1130 = "w-2026-11-30"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let pen = CanvasTool.ink(InkPresets.defaultPen)
    private let midnight = PaperSpec.weekGridHeight

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    override func setUp() async throws {
        bed = try SessionTestBed("WeekMemoSpanTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        canvasSleeper = TestSleeper()
        coordinators = []
        strokeClock = 0
    }

    override func tearDown() async throws {
        for coordinator in coordinators {
            coordinator.detach()
        }
        await canvasSleeper?.advance()
        coordinators = []
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    // MARK: - Helpers

    /// The one-page path's week paper (the screen's own `makePaper`).
    private func onePageWeek(_ focus: DayKey, weekStart: WeekStart = .monday, inkBottoms: [CellKey: CGFloat] = [:]) throws -> WeekPageLayout {
        let paper = CalendarRootScreen.makePaper(kind: .week, focus: focus, events: [], inkBottoms: inkBottoms, now: bed.now, holidays: .japan,
                                                 weekStart: weekStart)
        return try XCTUnwrap(paper.layout as? WeekPageLayout)
    }

    /// A pen stroke through `points` (paper or band lu), each with its own creation date (its own fingerprint).
    private func makeStroke(through points: [CGPoint], nib: CGFloat = 3.5) -> PKStroke {
        strokeClock += 1
        let controlPoints = points.enumerated().map { i, p in
            PKStrokePoint(location: p, timeOffset: TimeInterval(i) * 0.01, size: CGSize(width: nib, height: nib),
                          opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black),
                        path: PKStrokePath(controlPoints: controlPoints, creationDate: Date(timeIntervalSince1970: 1_790_000_000 + strokeClock)),
                        transform: .identity, mask: nil)
    }

    /// A short stroke centred near (x, y).
    private func shortStroke(at x: CGFloat, _ y: CGFloat) -> PKStroke {
        makeStroke(through: (0..<5).map { CGPoint(x: x - 20 + CGFloat($0) * 10, y: y + CGFloat($0 % 2)) })
    }

    /// Three band points centred at (x, y + 0.5): what `JoinedLedgerStandIn.draw` takes.
    private func short(_ x: CGFloat, _ y: CGFloat) -> [CGPoint] {
        [CGPoint(x: x - 20, y: y), CGPoint(x: x, y: y + 1), CGPoint(x: x + 20, y: y)]
    }

    /// A pen stroke of `cell` through `points` (cell-relative).
    private func inkStroke(_ id: String, cell: CellKey, _ points: [CGPoint], t: Int = 1_790_000_001_000) -> InkStroke {
        InkStroke(id: id, cell: cell, tool: .pen, color: "#1f2937", t: t, points: points.enumerated().map { i, p in
            InkPoint(x: p.x, y: p.y, dtMs: i * 8, sizeW: 3.5, sizeH: 3.5, opacity: 1, force: 0.5, azimuth: 0, altitude: 1.4)
        })
    }

    /// The extra heights of the window's pages, in order.
    private func memoHeights(_ session: SpanSession) -> [CGFloat?] {
        session.layout.pages.map { $0.cells[.extra]?.height }
    }

    /// The window's cell rect of `cell` on `pageId`.
    private func cell(_ cell: CellKey, of pageId: String, _ session: SpanSession) throws -> CGRect {
        try XCTUnwrap(session.layout.cells[SpanName.prefixed(cell, page: pageId)], "no \(cell.raw) on \(pageId)")
    }

    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    // MARK: - The source: the two call sites

    /// Swift source with every comment and the text of every string literal blanked (lengths kept; the code of a string's
    /// interpolation is kept), so a search for code finds code only.
    static func codeOnly(_ text: String) -> [Character] {
        let c = Array(text)
        var out = c
        enum Mode {
            case code(interpolation: Bool, depth: Int)
            case string(multiLine: Bool, hashes: Int)
        }
        var stack: [Mode] = [.code(interpolation: false, depth: 0)]
        func at(_ i: Int, _ s: String) -> Bool {
            let p = Array(s)
            guard i + p.count <= c.count else { return false }
            return Array(c[i..<(i + p.count)]) == p
        }
        func blank(_ from: Int, _ count: Int) {
            for k in from..<min(c.count, from + count) where c[k] != "\n" { out[k] = " " }
        }
        var i = 0
        while i < c.count {
            switch stack[stack.count - 1] {
            case .code(let interpolation, let depth):
                if at(i, "//") {
                    var j = i
                    while j < c.count, c[j] != "\n" { j += 1 }
                    blank(i, j - i)
                    i = j
                } else if at(i, "/*") {
                    var j = i + 2
                    var nesting = 1
                    while j < c.count, nesting > 0 {
                        if at(j, "/*") { nesting += 1; j += 2 } else if at(j, "*/") { nesting -= 1; j += 2 } else { j += 1 }
                    }
                    blank(i, j - i)
                    i = j
                } else if c[i] == "\"" || (c[i] == "#" && i + 1 < c.count && (c[i + 1] == "#" || c[i + 1] == "\"")) {
                    var hashes = 0
                    var j = i
                    while j < c.count, c[j] == "#" { hashes += 1; j += 1 }
                    guard j < c.count, c[j] == "\"" else { i = j; continue }
                    let multi = at(j, "\"\"\"")
                    let open = j - i + (multi ? 3 : 1)
                    blank(i, open)
                    i += open
                    stack.append(.string(multiLine: multi, hashes: hashes))
                } else if interpolation, c[i] == "(" {
                    stack[stack.count - 1] = .code(interpolation: true, depth: depth + 1)
                    i += 1
                } else if interpolation, c[i] == ")" {
                    if depth == 1 {
                        out[i] = " "
                        stack.removeLast()
                    } else {
                        stack[stack.count - 1] = .code(interpolation: true, depth: depth - 1)
                    }
                    i += 1
                } else {
                    i += 1
                }
            case .string(let multi, let hashes):
                let pounds = String(repeating: "#", count: hashes)
                if at(i, "\\" + pounds + "(") {
                    blank(i, hashes + 2)
                    i += hashes + 2
                    stack.append(.code(interpolation: true, depth: 1))
                } else if at(i, "\\" + pounds) {
                    blank(i, hashes + 2)
                    i += hashes + 2
                } else if at(i, (multi ? "\"\"\"" : "\"") + pounds) {
                    let close = (multi ? 3 : 1) + hashes
                    blank(i, close)
                    i += close
                    stack.removeLast()
                } else {
                    blank(i, 1)
                    i += 1
                }
            }
        }
        return out
    }

    /// Every `WeekLayoutInput(` call of `code` (from `codeOnly`): the text from the name to its matching ")".
    static func weekLayoutInputCalls(_ code: [Character]) -> [String] {
        let name = Array("WeekLayoutInput(")
        var calls: [String] = []
        var i = 0
        while i + name.count <= code.count {
            guard Array(code[i..<(i + name.count)]) == name else { i += 1; continue }
            if i > 0, code[i - 1].isLetter || code[i - 1].isNumber || code[i - 1] == "_" || code[i - 1] == "." {
                i += 1
                continue
            }
            var depth = 0
            var j = i + name.count - 1
            while j < code.count {
                if code[j] == "(" { depth += 1 } else if code[j] == ")" { depth -= 1; if depth == 0 { break } }
                j += 1
            }
            calls.append(String(code[i...min(j, code.count - 1)]))
            i = j + 1
        }
        return calls
    }

    /// §9.3 1 (the critics' W-10): every week the app lays out has the memo. (a) Every `.swift` of Sources/TegakiCalendar but
    /// the prototype's (`Span/SpanPrototype*.swift`) is read, each `WeekLayoutInput(` call taken from its name to the
    /// matching ")" (parentheses counted in code only: not in comments or strings), and every call passes
    /// `freeMemo: true`; there are exactly 2 (the one-page path's `makePaper` and the joined path's `pageLayout`: a third
    /// call site fails here until whoever adds it looks at it). (b) `makePaper`'s Monday and Sunday weeks have the memo.
    func testEveryAppWeekLayoutHasTheMemo() throws {
        // The reader itself: comments, strings and interpolations.
        let sample = """
        let a = WeekLayoutInput(focus: f, words: w("x)"), freeMemo: true) // WeekLayoutInput(no)
        /* WeekLayoutInput(no) */ let b = "WeekLayoutInput(no) \\(g(1))"
        let c = MyWeekLayoutInput(x)
        let d = WeekLayoutInput(focus: f,
                                extraFloor: h(2)) /* ) */
        """
        let sampleCalls = Self.weekLayoutInputCalls(Self.codeOnly(sample))
        XCTAssertEqual(sampleCalls.count, 2, "\(sampleCalls)")
        XCTAssertTrue(sampleCalls.first?.contains("freeMemo: true") ?? false)
        XCTAssertTrue(sampleCalls.last?.hasSuffix("extraFloor: h(2))") ?? false, "\(sampleCalls)")
        XCTAssertFalse(sampleCalls.last?.contains("freeMemo") ?? true)

        // (a) The app's sources.
        let root = Self.repository.appendingPathComponent("Sources/TegakiCalendar", isDirectory: true)
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL])
            .filter { $0.pathExtension == "swift" && !$0.lastPathComponent.hasPrefix("SpanPrototype") }
        XCTAssertGreaterThan(files.count, 50, "the app's sources were found (\(root.path))")
        var sites: [(file: String, call: String)] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            for call in Self.weekLayoutInputCalls(Self.codeOnly(text)) {
                sites.append((url.lastPathComponent, call))
            }
        }
        XCTAssertEqual(sites.map(\.file).sorted(), ["CalendarRootScreen.swift", "SpanSession.swift"],
                       "the two call sites of WeekLayoutInput (a new one must pass freeMemo: true and be counted here)")
        for site in sites {
            XCTAssertTrue(site.call.hasSuffix(")"), "\(site.file): the call is read to its end")
            XCTAssertTrue(site.call.contains("freeMemo: true"), "\(site.file): \(site.call)")
        }

        // (b) The one-page path's weeks of both starts.
        for (focus, start, pageId) in [(nov16, WeekStart.monday, w1116), (nov16, .sunday, "w-2026-11-15")] {
            let week = try onePageWeek(focus, weekStart: start)
            XCTAssertEqual(week.pageId, pageId)
            XCTAssertEqual(week.cells[.extra], CGRect(x: 0, y: midnight, width: 1400, height: 6000), pageId)
            XCTAssertEqual(week.size, CGSize(width: 1400, height: 7920), pageId)
            XCTAssertEqual(PaperGrowth.tail(of: week)?.key, .extra, pageId)
        }
    }

    // MARK: - D16 on the joined weeks

    /// §9.3 2, D16 as docs/M7C.md reads it (the plan's decision 22): every page of a week window has the memo; a memo line
    /// past 5,950 lu on one page makes every page of the window end at the same line (`.inkGrew`); right after a shift
    /// that takes that page out the window keeps the height (`.shift` never lowers it); once the page that came in is read
    /// (`prefetch`, `.redecide`) the window comes back to its tallest page, 6,000 lu, and the 30 s tick keeps it; erasing
    /// the line in a window brings it back too (`.inkShrank`).
    func testJoinedWeeksHaveTheMemoAndLineUp() async throws {
        let session = bed.session(.week, focus: nov16, number: 1, radius: 1)
        await session.prefetch()
        XCTAssertEqual(session.pageIds, [w1109, w1116, w1123])
        XCTAssertEqual(memoHeights(session), [6000, 6000, 6000], "every joined week has its memo")
        let ledger = JoinedLedgerStandIn(session)
        // On the left week's memo: centred 5,974 lu below 24:00 (kept, under the 6,000 lu cap), its bottom at 6,950 lu.
        let memo = try cell(.extra, of: w1109, session)
        let deep = try XCTUnwrap(ledger.draw([CGPoint(x: memo.minX + 300, y: memo.minY + 5_000), CGPoint(x: memo.minX + 310, y: memo.minY + 6_000),
                                              CGPoint(x: memo.minX + 320, y: memo.minY + 6_948.25)]))
        XCTAssertEqual(deep.cell, SpanName.prefixed(.extra, page: w1109))
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(session.page(w1109)?.inkBottoms()[.extra], 6_950)
        XCTAssertEqual(memoHeights(session), [7000, 7000, 7000], "the window ends at the same line (.inkGrew)")
        XCTAssertEqual(session.floors.weekExtra, 7000)
        XCTAssertEqual(session.floors.dayExtra, 0)
        XCTAssertEqual(session.layout.size.height, midnight + 7000)

        // A shift that takes w-11-09 out: right after it the window keeps its height.
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 1))
        XCTAssertEqual(session.pageIds, [w1116, w1123, w1130])
        XCTAssertEqual(bed.live(w1109).count, 1, "the page that left was saved")
        XCTAssertEqual(memoHeights(session), [7000, 7000, 7000], "a shift never lowers the floor")
        // The page that came in read: the window comes back to its tallest page.
        await session.prefetch()
        XCTAssertEqual(memoHeights(session), [6000, 6000, 6000], "read: .redecide, the window's tallest")
        session.contextChanged()
        XCTAssertEqual(memoHeights(session), [6000, 6000, 6000], "the 30 s tick")

        // Another window: the same line, then erased.
        let december = bed.session(.week, focus: DayKey(year: 2026, month: 12, day: 9), number: 2, radius: 1)
        await december.prefetch()
        XCTAssertEqual(december.pageIds, ["w-2026-11-30", "w-2026-12-07", "w-2026-12-14"])
        let other = JoinedLedgerStandIn(december)
        let middle = try cell(.extra, of: "w-2026-12-07", december)
        let line = try XCTUnwrap(other.draw([CGPoint(x: middle.minX + 300, y: middle.minY + 5_000), CGPoint(x: middle.minX + 310, y: middle.minY + 6_000),
                                             CGPoint(x: middle.minX + 320, y: middle.minY + 6_948.25)]))
        other.put()
        december.relayoutPages()
        XCTAssertEqual(memoHeights(december), [7000, 7000, 7000])
        XCTAssertEqual(other.erase([line.id]), [line.id])
        other.put()
        december.relayoutPages()
        XCTAssertEqual(memoHeights(december), [6000, 6000, 6000], "erased: .inkShrank")
    }

    // MARK: - Where a stroke is filed

    /// §9.3 3: a new stroke centred at y 2,500 is the memo's (`extra`), one at y 1,900 the grid's, on the one-page path (the
    /// ledger over `makePaper`'s week) and on the joined path (the owner page's prefix: the page under the centre).
    func testWeekMemoStrokeIsFiledInExtraOnBothPaths() async throws {
        let week = try onePageWeek(nov16)
        let ledger = InkLedger(page: InkPage.empty(pageId: week.pageId), layout: week)
        _ = ledger.drawing()
        let below = makeStroke(through: (0..<5).map { CGPoint(x: 680 + CGFloat($0) * 10, y: 2_500 + CGFloat($0 % 2)) })
        let low = try XCTUnwrap(ledger.applyCanvasChange(PKDrawing(strokes: [below])).added.first)
        XCTAssertEqual(low.cell, .extra)
        XCTAssertEqual(low.points.first?.y ?? 0, 2_500 - midnight, accuracy: 0.11, "cell-relative from 24:00")
        let above = makeStroke(through: (0..<5).map { CGPoint(x: 680 + CGFloat($0) * 10, y: 1_900 + CGFloat($0 % 2)) })
        let high = try XCTUnwrap(ledger.applyCanvasChange(PKDrawing(strokes: [below, above])).added.first)
        XCTAssertEqual(high.cell, .grid)
        XCTAssertEqual(high.points.first?.y ?? 0, 1_900, accuracy: 0.11)

        let session = bed.session(.week, focus: nov16, number: 1, radius: 1)
        await session.prefetch()
        let joined = JoinedLedgerStandIn(session)
        let x = try XCTUnwrap(session.origin(ofPage: w1123)) + 700
        let memo = try XCTUnwrap(joined.draw(short(x, 2_500)))
        XCTAssertEqual(memo.cell, SpanName.prefixed(.extra, page: w1123))
        let grid = try XCTUnwrap(joined.draw(short(x, 1_900)))
        XCTAssertEqual(grid.cell, SpanName.prefixed(.grid, page: w1123))
        joined.deliver()
        XCTAssertEqual(Set(session.page(w1123)?.liveStrokes.map(\.cell) ?? []), [.extra, .grid])
        XCTAssertEqual(session.saveAll(), [])
        XCTAssertEqual(Set(bed.store.load(w1123).liveStrokes.map(\.cell)), [.extra, .grid], "saved under the page's own cells")
    }

    /// §9.3 4, K-2: the lasso's move across 24:00. On the one page a `grid` stroke moved 300 lu down becomes a new stroke
    /// (a new id) in `extra`, ↶ brings the `grid` stroke back, ↷ moves it again, and moved up it is `grid` again; the
    /// selection may go down to the paper's end (7,920 lu: `LassoGeometry.clampedMoveDelta` with the layout's size, where
    /// 1.2.3's week stopped at 1,920). On the joined path a move across pages and across 24:00 lands in the other page's memo.
    func testLassoAcrossMidnightRefilesTheStroke() async throws {
        let week = try onePageWeek(nov16)
        var page = InkPage.empty(pageId: week.pageId)
        let original = inkStroke("grid-1", cell: .grid, [CGPoint(x: 600, y: 1_840), CGPoint(x: 640, y: 1_850), CGPoint(x: 680, y: 1_860)])
        page.add(original)
        let ledger = InkLedger(page: page, layout: week)
        _ = ledger.drawing()
        let down = ledger.moveStrokes(ids: ["grid-1"], by: CGVector(dx: 0, dy: 300))
        let downId = try XCTUnwrap(down.newIds.first)
        XCTAssertNotEqual(downId, "grid-1", "K-2: a new id")
        XCTAssertEqual(ledger.page.strokes[downId]?.cell, .extra, "centred below 24:00: the memo's")
        XCTAssertEqual(ledger.page.strokes[downId]?.points.first?.y ?? 0, 1_840 + 300 - midnight, accuracy: 0.11)
        XCTAssertNotNil(ledger.page.deleted["grid-1"])
        XCTAssertNotNil(ledger.undo())
        let back = ledger.page.liveStrokes
        XCTAssertEqual(back.count, 1)
        XCTAssertEqual(back.first?.cell, .grid, "↶: the grid stroke again")
        XCTAssertEqual(back.first?.points.map(\.y), original.points.map(\.y))
        XCTAssertNotNil(ledger.redo())
        let again = try XCTUnwrap(ledger.page.liveStrokes.first)
        XCTAssertEqual(again.cell, .extra)
        let up = ledger.moveStrokes(ids: [again.id], by: CGVector(dx: 0, dy: -300))
        XCTAssertEqual(up.change.added.first?.cell, .grid, "moved back up: the grid's")
        XCTAssertEqual(up.change.added.first?.points.first?.y ?? 0, 1_840, accuracy: 0.11)

        // The selection reaches the paper's end, 7,920 lu (1.2.3's week stopped it at 1,920).
        let bbox = CGRect(x: 600, y: 1_800, width: 100, height: 100)
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: bbox, dx: 0, dy: 10_000, pageSize: week.size).dy, 7_920 - 1_900, accuracy: 0.001)
        let old = WeekLayoutEngine.layout(WeekLayoutInput(focus: nov16, events: [], inkBottoms: [:], now: bed.now))
        XCTAssertEqual(LassoGeometry.clampedMoveDelta(bbox: bbox, dx: 0, dy: 10_000, pageSize: old.size).dy, 20, accuracy: 0.001)

        // The joined path: from w-11-16's grid to w-11-23's memo, one step.
        let session = bed.session(.week, focus: nov16, number: 1, radius: 1)
        await session.prefetch()
        let joined = JoinedLedgerStandIn(session)
        let x = try XCTUnwrap(session.origin(ofPage: w1116)) + 700
        let stroke = try XCTUnwrap(joined.draw(short(x, 1_850)))
        XCTAssertEqual(stroke.cell, SpanName.prefixed(.grid, page: w1116))
        let clones = joined.move([stroke.id], by: CGVector(dx: 1_400, dy: 300), group: UUID())
        XCTAssertEqual(clones.map(\.cell), [SpanName.prefixed(.extra, page: w1123)])
        joined.deliver()
        XCTAssertEqual(session.page(w1123)?.liveStrokes.map(\.cell), [.extra])
        XCTAssertEqual(session.page(w1116)?.liveStrokeCount, 0)
        XCTAssertEqual(session.page(w1116)?.deleted.count, 1)
        XCTAssertEqual(session.saveAll(), [])
    }

    /// §9.3 5 (§4.4, the compat fixture 4's w-2026-12-14): the two `grid` strokes reaching below 24:00 on the one-page path's
    /// week. (e) written across 24:00 (centred above it): drawn, its lower part over the memo, a candidate of the lasso,
    /// still `grid` (K-2), and moved 300 lu down it is the memo's. (a) centred below 24:00 (an import's or a hand-edited
    /// file's): drawn over the memo, a candidate of the lasso, `grid`, and moved it is the memo's. Whether the PDF keeps
    /// the memo for them (it does not: 1,920 lu, as 1.2.3's) is the paper's test (`WeekMemoPaperSpanTests`).
    func testGridStrokesBelowMidnightShowOverTheMemo() throws {
        let url = Self.repository.appendingPathComponent("TegakiKit/Tests/Fixtures/compat-span/w-2026-12-14.week-memo.json")
        let page = try InkPageCodec.decode(try Data(contentsOf: url))
        let acrossId = "d4a9a7dd-5ae3-487e-9dd9-728032f38f40"
        let guardId = "6e2b8d4f-5a7c-4e9b-8d1f-4b5c6d7e8f95"
        XCTAssertEqual(page.strokes[acrossId]?.cell, .grid)
        XCTAssertEqual(page.strokes[guardId]?.cell, .grid)
        let week = try onePageWeek(DayKey(year: 2026, month: 12, day: 14), inkBottoms: page.inkBottoms())
        XCTAssertEqual(week.pageId, page.pageId)
        let ledger = InkLedger(page: page, layout: week)
        XCTAssertEqual(ledger.drawing().strokes.count, 4, "the two grid strokes and the two memo strokes are drawn")

        let across = try XCTUnwrap(ledger.paperBounds(of: acrossId), "(e) is a candidate of the lasso")
        XCTAssertLessThanOrEqual(across.midY, midnight, "(e) is centred above 24:00")
        XCTAssertGreaterThan(across.maxY, midnight, "(e)'s lower part shows over the memo")
        XCTAssertLessThan(across.maxY, week.size.height)
        let guardBounds = try XCTUnwrap(ledger.paperBounds(of: guardId), "(a) is a candidate of the lasso")
        XCTAssertGreaterThan(guardBounds.minY, midnight, "(a) lies below 24:00, over the memo")
        XCTAssertEqual(week.inkCell(forCenter: CGPoint(x: guardBounds.midX, y: guardBounds.midY)), .extra,
                       "a new stroke there would be the memo's; (a) stays grid until it is moved")

        let movedAcross = ledger.moveStrokes(ids: [acrossId], by: CGVector(dx: 0, dy: 300))
        XCTAssertEqual(movedAcross.change.added.first?.cell, .extra, "(e) moved down: centred below 24:00, the memo's")
        let movedGuard = ledger.moveStrokes(ids: [guardId], by: CGVector(dx: 0, dy: 10))
        XCTAssertEqual(movedGuard.change.added.first?.cell, .extra, "(a) moved: the memo's")
        XCTAssertEqual(ledger.page.liveStrokes.filter { $0.cell == .grid }.count, 0)
        XCTAssertEqual(ledger.page.liveStrokes.filter { $0.cell == .extra }.count, 4)
    }

    // MARK: - No event in the memo

    /// §9.3 6, the plan's decisions 4 and 28: in the week memo the 予定 tool and 「予定にする」 make no event (the day's rule
    /// and toast, `startsBelowDay`: the rect's top at 24:00 or below). From 1,919.9 it is a 23:00 event; an upward drag
    /// from the memo across 24:00 is 22:00–24:00; a week without the memo (1.2.3's) never refuses. On the joined path the
    /// page under the rect decides (its plan and its id).
    func testNoEventInTheWeekMemo() async throws {
        let wednesday = DayKey(year: 2026, month: 10, day: 7)
        let monday = DayKey(year: 2026, month: 10, day: 5)
        let now = wednesday.startOfDay().addingTimeInterval(10 * 3600)
        let week = try onePageWeek(wednesday)
        XCTAssertNotNil(week.cells[.extra])
        func plan(_ layout: any PageLayout, _ rect: CGRect) -> CalendarRootScreen.NewEventPlan {
            CalendarRootScreen.newEventPlan(layout: layout, rect: rect, now: now)
        }
        // Refused: from 24:00, a tap deep in the memo, a drag that stays below, a rect as wide as the paper.
        for rect in [CGRect(x: 100, y: 1_920, width: 200, height: 100), CGRect(x: 500, y: 2_500, width: 0, height: 0),
                     CGRect(x: 100, y: 2_600, width: 100, height: -150), CGRect(x: 0, y: 1_926, width: 1_400, height: 600)] {
            XCTAssertEqual(plan(week, rect), .refusedBelowDay, "\(rect)")
            XCTAssertNotNil(week.eventRange(for: rect, now: now), "\(rect): eventRange alone would make a 23:00 event")
        }
        // Made: from 1,919.9 a 23:00 event; an upward drag across 24:00 22:00–24:00 (the Monday column).
        let justAbove = CGRect(x: 100, y: 1_919.9, width: 200, height: 100)
        XCTAssertEqual(plan(week, justAbove), .create(week.eventRange(for: justAbove, now: now)))
        XCTAssertEqual(plan(week, justAbove), .create(.timed(monday, startMinute: 23 * 60, endMinute: 24 * 60)))
        let upward = CGRect(x: 100, y: 2_000, width: 100, height: -240)
        XCTAssertEqual(plan(week, upward), .create(.timed(monday, startMinute: 22 * 60, endMinute: 24 * 60)))
        let ten = CGRect(x: 100, y: 800, width: 200, height: 100)
        XCTAssertEqual(plan(week, ten), .create(week.eventRange(for: ten, now: now)))
        // The week without the memo (the Kit's default, 1.2.3's week) never refuses.
        let old = WeekLayoutEngine.layout(WeekLayoutInput(focus: wednesday, events: [], inkBottoms: [:], now: now))
        XCTAssertNil(old.cells[.extra])
        XCTAssertNotEqual(plan(old, CGRect(x: 100, y: 1_920, width: 200, height: 100)), .refusedBelowDay)

        // The joined path: the memo of the page right of a boundary refuses, with that page's id; above 24:00 an event.
        let session = bed.session(.week, focus: nov16, number: 1, radius: 1)
        await session.prefetch()
        let origin = try XCTUnwrap(session.origin(ofPage: w1123))
        let below = CGRect(x: origin + 300, y: 2_500, width: 100, height: 100)
        let made = try XCTUnwrap(ScreenPaths.newEvent(layout: session.layout, rect: below, now: bed.now))
        XCTAssertEqual(made.pageId, w1123)
        XCTAssertEqual(made.plan, .refusedBelowDay)
        let aboveIt = try XCTUnwrap(ScreenPaths.newEvent(layout: session.layout, rect: below.offsetBy(dx: 0, dy: -1_500), now: bed.now))
        XCTAssertEqual(aboveIt.pageId, w1123)
        guard case .create(let range?) = aboveIt.plan else { return XCTFail("\(aboveIt.plan)") }
        XCTAssertEqual(DayKey(range.start), DayKey(year: 2026, month: 11, day: 24))
    }

    // MARK: - Growth through the real canvas

    /// §9.3 7: `InkCanvasSpanTests.testGrowthTestsThroughOneAndThreePageSessions`'s inputs on the week. On the one page
    /// (`makePaper`'s week, 1.2.3's canvas path) a line at 5,984 lu of the memo tells the owner once that the paper may
    /// grow and once that the memo is near its end, and the week laid out again is 6,040 lu of memo by the light path (no
    /// new drawing); a line centred at 6,098 lu is dropped with the notice. The same through a window of three weeks:
    /// every week of the window grows alike (D16), by the light path, the notice names the owner week. Without the Kit's
    /// week `tail` there would be neither notice nor light path.
    func testWeekMemoGrowsThroughOneAndThreePageCanvases() async throws {
        // The one page.
        let plain = try onePageWeek(nov16)
        let memo = try XCTUnwrap(plain.cells[.extra])
        var oneInkBounds = 0
        var oneCaps = 0
        let oneView = { (layout: WeekPageLayout, page: InkPage) in
            InkCanvasView(layout: layout, paper: .week(WeekPaperContent(layout: layout)), tool: self.pen, allowFinger: false,
                          page: .constant(page), initialScrollY: 0, onTap: { _, _ in }, onInkBoundsChanged: { oneInkBounds += 1 },
                          undoTrigger: 0, redoTrigger: 0, onGrowthCapReached: { oneCaps += 1 })
        }
        let one = InkCanvasView.Coordinator(parent: oneView(plain, InkPage.empty(pageId: plain.pageId)))
        coordinators.append(one)
        let oneContainer = InkCanvasContainerView(paperView: PaperView(content: .week(WeekPaperContent(layout: plain))))
        one.attach(oneContainer)
        oneContainer.frame = CGRect(x: 0, y: 0, width: 834, height: 951)
        oneContainer.layoutSubviews()
        await settle()
        let lowLine = makeStroke(through: (0..<5).map { CGPoint(x: 300 + CGFloat($0) * 3, y: memo.minY + 5_984 + CGFloat($0)) })
        oneContainer.canvasView.drawing = PKDrawing(strokes: [lowLine])
        one.canvasViewDrawingDidChange(oneContainer.canvasView)
        XCTAssertEqual(oneInkBounds, 1)
        XCTAssertEqual(oneCaps, 1, "5,990 leaves less than 400 lu below it: once")
        XCTAssertEqual(one.ledger.page.liveStrokes.first?.cell, .extra)
        let grown = try onePageWeek(nov16, inkBottoms: one.ledger.page.inkBottoms())
        XCTAssertEqual(grown.extra.height, 6_040, accuracy: 0.5)
        XCTAssertTrue(PaperGrowth.onlyTailHeightChanged(old: plain, new: grown))
        let oneBuilds = one.setDrawingCount
        one.update(from: oneView(grown, one.ledger.page))
        XCTAssertEqual(one.setDrawingCount, oneBuilds, "the one page's light path")
        XCTAssertEqual(oneContainer.canvasView.contentSize.height, grown.size.height * oneContainer.canvasView.zoomScale, accuracy: 0.5)
        let beyond = makeStroke(through: (0..<5).map { CGPoint(x: 500 + CGFloat($0) * 10, y: memo.minY + 6_098) }, nib: 4)
        oneContainer.canvasView.drawing = PKDrawing(strokes: oneContainer.canvasView.drawing.strokes + [beyond])
        one.canvasViewDrawingDidChange(oneContainer.canvasView)
        XCTAssertEqual(one.ledger.page.liveStrokeCount, 1, "centred past the cap: dropped")
        XCTAssertEqual(oneCaps, 2, "with the notice")

        // A window of three weeks.
        let session = bed.session(.week, focus: nov16, number: 3, radius: 1)
        await session.prefetch()
        XCTAssertEqual(session.pageIds, [w1109, w1116, w1123])
        var inkBounds = 0
        var pageCaps: [String] = []
        var oldCaps = 0
        let sleeper = canvasSleeper!
        let clockBed = bed!
        let focusLayout = try XCTUnwrap(session.layout.pages[session.focusSlot] as? WeekPageLayout)
        let view = InkCanvasView(layout: session.layout, paper: .week(WeekPaperContent(layout: focusLayout)), tool: pen, allowFinger: false,
                                 page: .constant(InkPage(pageId: session.layout.pageId)), initialScrollY: 0, onTap: { _, _ in },
                                 onInkBoundsChanged: { inkBounds += 1 }, undoTrigger: 0, redoTrigger: 0,
                                 onGrowthCapReached: { oldCaps += 1 }, span: session,
                                 sleep: { await sleeper.sleep($0) }, clock: { [weak clockBed] in clockBed?.now ?? Date(timeIntervalSince1970: 0) },
                                 onPageGrowthCapReached: { pageCaps.append($0) })
        let coordinator = InkCanvasView.Coordinator(parent: view)
        coordinators.append(coordinator)
        let container = InkCanvasContainerView(paperView: PaperView(content: view.paper), canvasView: InkBandCanvasView())
        coordinator.attach(container)
        container.frame = CGRect(x: 0, y: 0, width: 834, height: 951)
        container.layoutSubviews()
        await settle()
        let extra = try cell(.extra, of: w1116, session)
        XCTAssertEqual(extra.height, PaperSpec.growMax, accuracy: 0.01)
        let builds = coordinator.setDrawingCount
        let low = makeStroke(through: (0..<5).map { CGPoint(x: extra.minX + 300 + CGFloat($0) * 3, y: extra.minY + 5_984 + CGFloat($0)) })
        container.canvasView.drawing = PKDrawing(strokes: container.canvasView.drawing.strokes + [low])
        coordinator.canvasViewDrawingDidChange(container.canvasView)
        XCTAssertEqual(inkBounds, 1, "the owner hears of it as on the one page")
        XCTAssertEqual(pageCaps, [w1116], "as on the one page: once, naming the owner week")
        await settle()
        for id in session.pageIds {
            XCTAssertEqual(try cell(.extra, of: id, session).height, grown.extra.height, accuracy: 0.5, "\(id): the window's floor (D16)")
        }
        XCTAssertEqual(coordinator.spanAppliedWindowVersion, session.windowVersion, "the canvas took the new layout")
        XCTAssertEqual(coordinator.setDrawingCount, builds, "the light path")
        XCTAssertEqual(container.canvasView.contentSize.height, session.layout.size.height * container.canvasView.zoomScale, accuracy: 0.5)
        let dropped = makeStroke(through: (0..<5).map { CGPoint(x: extra.minX + 500 + CGFloat($0) * 10, y: extra.minY + 6_098) }, nib: 4)
        container.canvasView.drawing = PKDrawing(strokes: container.canvasView.drawing.strokes + [dropped])
        coordinator.canvasViewDrawingDidChange(container.canvasView)
        await settle()
        XCTAssertEqual(pageCaps, [w1116, w1116], "6,098: dropped, with the notice")
        XCTAssertEqual(coordinator.ledger.page.liveStrokeCount, 1)
        XCTAssertEqual(oldCaps, 0)
        XCTAssertEqual(session.page(w1116)?.liveStrokes.map(\.cell), [.extra])
    }

    // MARK: - The two week starts

    /// §9.3 8, K-11 (6): the memo is in the week's own page (`w-<Monday>` or `w-<Sunday>`), so each week start has its own.
    /// Written on the Monday start's w-2026-11-16 and saved, it is not on the Sunday start's w-2026-11-15 (whose memo is
    /// there, empty), and it is there again with the Monday start.
    func testWeekMemoBelongsToItsWeekStart() async throws {
        let monday = bed.session(.week, focus: nov16, weekStart: .monday, number: 1, radius: 1)
        await monday.prefetch()
        let ledger = JoinedLedgerStandIn(monday)
        let x = try XCTUnwrap(monday.origin(ofPage: w1116)) + 500
        let stroke = try XCTUnwrap(ledger.draw(short(x, 2_300)))
        XCTAssertEqual(stroke.cell, SpanName.prefixed(.extra, page: w1116))
        ledger.deliver()
        XCTAssertEqual(monday.saveAll(), [])
        XCTAssertEqual(bed.store.load(w1116).liveStrokes.map(\.cell), [.extra])

        let sunday = bed.session(.week, focus: nov16, weekStart: .sunday, number: 2, radius: 1)
        await sunday.prefetch()
        XCTAssertEqual(sunday.pageIds, ["w-2026-11-08", "w-2026-11-15", "w-2026-11-22"])
        XCTAssertEqual(memoHeights(sunday), [6000, 6000, 6000], "the Sunday start's weeks have their memo")
        XCTAssertTrue(sunday.pageIds.allSatisfy { sunday.page($0)?.liveStrokeCount == 0 }, "the Monday start's memo is not here")
        XCTAssertEqual(try onePageWeek(nov16, weekStart: .sunday).pageId, "w-2026-11-15")

        let again = bed.session(.week, focus: nov16, weekStart: .monday, number: 3, radius: 1)
        await again.prefetch()
        XCTAssertEqual(again.page(w1116)?.liveStrokes.map(\.cell), [.extra], "back to the Monday start: the memo is there")
        let memo = try cell(.extra, of: w1116, again)
        let centre = try XCTUnwrap(again.page(w1116)?.liveStrokes.first?.paperBounds(cellOrigin: CGPoint(x: memo.minX, y: memo.minY)))
        XCTAssertTrue(memo.contains(CGPoint(x: centre.midX, y: centre.midY)), "drawn in the memo of its own week")
    }
}
