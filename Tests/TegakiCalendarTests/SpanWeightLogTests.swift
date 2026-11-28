@_spi(SpanLedger) import InkModel
import Layout
import PencilKit
import SwiftUI
import UIKit
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §3.10, §11.2 row S・Z, 0g-3, 0g-25): the weight of a joined window, measured and logged,
// never judged here. No assertion reads a time: what is asserted is only the set-up of the measurement (the window's pages,
// the strokes put in, the rows they leave alone, not stage 2). The times go to the log of Build and test, one `print` line
// each (never NSLog as well), for the lead to read (0g-3's 「重い」: the year's median shift over 1,000 ms in two runs, the
// week's reference value of the same run under it):
//
//   span weight: kind=year pages=7 strokes=<n> compose=<ms> shift=<ms>     (n = 1,064, 7,000 and 19,600)
//   span weight: kind=year pages=7 strokes=<n> relayout=<ms>
//   span weight: ref=week pages=7 strokes=19600 shift=<ms>
//   span weight: kind=month pages=5 strokes=5080 compose=<ms> shift=<ms>
//   span weight: kind=month pages=5 strokes=5080 relayout=<ms>
//
// ms with one decimal (`ContinuousClock`). The session is the table's 13-inch iPad in landscape (`.iPad13`, `.landscape`: the
// simulator of the unit tests' step, build.yml's `-destination`), whose window is 7 years (V 2.19 at the year's overview, KitChecks'
// table), 7 weeks and 5 months; the canvas has that class's paper area (`SpanPlan.referenceViewport`). Each page of the window
// — and the page a shift to the right brings in — holds its strokes in the store before the session opens: 152, 1,000 or
// 2,800 a year (the owner's year page and busiest page of P-B9, and 19,600 in all, under the iPad's cap of 20,000 and a page's
// 19,000), 2,800 a week, 1,016 a month. A stroke is a pen line of 12 points (a short handwritten stroke; the compat fixtures
// average about 10), drawn inside its cell so that no row grows (its bottom + 12 under the cell's natural height).
//   - compose: the session opened and its pages read (`prefetch()`: the window composed and laid out twice, §3.3).
//   - relayout: `relayoutPages()` once (the canvas's call when ink crossed a cell's bottom).
//   - shift: the canvas (as `InkCanvasSpanTests` builds it) slides the paper by one page and the window shifts at rest
//     (`shiftIfAtRest()`: the session's shift, then the canvas takes the window and builds its drawing again,
//     `setWindowDrawing`, in the same call); the page that came in is read afterwards (not timed) before the next shift.
//     The full window of years and the week beside it: the median of three shifts (right, left, right).
// Predicted times are not asserted anywhere; 予定を読む時間 is not measured (the simulator has no calendar, §3.10).

@MainActor
final class SpanWeightLogTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private var canvasSleeper: TestSleeper!
    private var rigs: [Rig] = []

    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    private let device = SpanDeviceClass.iPad13
    private let orientation = SpanOrientation.landscape
    /// The points of each stroke put in.
    private static let pointsPerStroke = 12

    override func setUp() async throws {
        bed = try SessionTestBed("SpanWeightLogTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
        canvasSleeper = TestSleeper()
        rigs = []
    }

    override func tearDown() async throws {
        // As `InkCanvasSpanTests`: the watches first lose their canvas, then wake and end.
        for rig in rigs {
            rig.coordinator.detach()
        }
        await canvasSleeper?.advance()
        rigs = []
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    // MARK: The rig

    @MainActor
    private struct Rig {
        let coordinator: InkCanvasView.Coordinator
        let container: InkCanvasContainerView
        let session: SpanSession
        var canvas: PKCanvasView { container.canvasView }
    }

    /// What one window weighed (ms) and its shape.
    private struct Weight {
        let pages: Int
        let strokes: Int
        let compose: Double
        let relayout: Double
        let shifts: [Double]
        /// The median of the shifts (the one shift when there is one).
        var shift: Double {
            let sorted = shifts.sorted()
            return sorted.isEmpty ? .nan : sorted[sorted.count / 2]
        }
    }

    /// The paper of one page, as the screen makes it (InkCanvasMonthYearTests' own).
    private static func paper(of layout: any PageLayout) -> PaperContent {
        if let month = layout as? MonthPageLayout {
            return .month(MonthPaperContent(layout: month, labels: month.dateLabels, bars: month.allDayBars, chips: month.timedChips,
                                            holidayNames: [:]))
        }
        if let year = layout as? YearPageLayout {
            return .year(YearPaperContent(layout: year, monthNames: (1...12).map { "\($0)" }))
        }
        if let week = layout as? WeekPageLayout { return .week(WeekPaperContent(layout: week)) }
        if let day = layout as? DayPageLayout { return .day(DayPaperContent(layout: day)) }
        fatalError("a page of the four kinds")
    }

    /// The canvas attached to its container as `makeUIView` does, laid out once in `size` and settled (the joined path of
    /// InkCanvasMonthYearTests' rig, without what these measurements do not read).
    private func attach(_ session: SpanSession, size: CGSize) async -> Rig {
        let focus = session.layout.pages[min(max(0, session.focusSlot), session.layout.pages.count - 1)]
        let sleeper = canvasSleeper!
        let bed = bed!
        let view = InkCanvasView(
            layout: session.layout,
            paper: Self.paper(of: focus),
            tool: .ink(InkPresets.defaultPen),
            allowFinger: false,
            page: .constant(InkPage(pageId: session.layout.pageId)),
            initialScrollY: 0,
            onTap: { _, _ in },
            onInkBoundsChanged: {},
            undoTrigger: 0,
            redoTrigger: 0,
            span: session,
            sleep: { await sleeper.sleep($0) },
            clock: { [weak bed] in bed?.now ?? Date(timeIntervalSince1970: 0) },
            onSpanStop: { _ in }
        )
        let coordinator = InkCanvasView.Coordinator(parent: view)
        let container = InkCanvasContainerView(paperView: PaperView(content: view.paper), canvasView: InkBandCanvasView())
        coordinator.attach(container)
        container.frame = CGRect(origin: .zero, size: size)
        container.layoutSubviews()
        await settle()
        let rig = Rig(coordinator: coordinator, container: container, session: session)
        rigs.append(rig)
        return rig
    }

    /// The queued main-actor work (the next-turn deliveries, the prefetch's turns, the window taken).
    private func settle(_ turns: Int = 24) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// Up to `turns` turns until the window has no page left to read and the canvas took the session's last window, then the
    /// work that queued behind it (the canvas's shift check, which finds the focus on the middle page), so that the next
    /// slide's shift is the one `shiftIfAtRest()` makes.
    private func settleUntilTaken(_ rig: Rig, turns: Int = 400) async {
        for _ in 0..<turns {
            if !rig.session.hasUnreadPages, rig.coordinator.spanAppliedWindowVersion == rig.session.windowVersion { break }
            await Task.yield()
        }
        await settle()
    }

    /// A rig whose measurements are done: its canvas detached and its session closed (nothing is dirty), so the next window
    /// is measured alone.
    private func release(_ rig: Rig) {
        rig.coordinator.detach()
        rig.session.closeWithoutSaving()
        rigs.removeAll { $0.coordinator === rig.coordinator }
    }

    private static func ms(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1_000_000_000_000_000
    }

    private static func text(_ ms: Double) -> String {
        String(format: "%.1f", ms)
    }

    // MARK: The pages put in

    /// The cells of page number `index` the strokes go into: a year's 366 or 365 days, a month's own days, a week's grid.
    private static func cells(_ kind: PageKind, index: Int, plan: SpanPlan) -> [CellKey] {
        let first = plan.firstDay(at: index)
        switch kind {
        case .year:
            return (1...12).flatMap { m in (1...DayKey.daysInMonth(year: first.year, month: m)).map { CellKey.yearDay(month: m, day: $0) } }
        case .month:
            return (1...DayKey.daysInMonth(year: first.year, month: first.month)).map { CellKey.day(DayKey(year: first.year, month: first.month, day: $0)) }
        case .week, .day:
            return [.grid]
        }
    }

    /// Where (cell-relative) the stroke in place `slot` of its cell starts, and its last point at x + 4 × 11, y + 2: inside
    /// the cell, its bottom + 12 under the natural row (year: x ≤ 49 + 44 of 112, bottom ≤ 36 + 2 + 1.75, + 12 = 51.75 < 60;
    /// month: x ≤ 130 + 44 of 200, bottom ≤ 120 + 3.75, + 12 = 135.75 < 175; week: anywhere in the 1,400 × 1,920 grid, which
    /// does not grow).
    private static func start(_ kind: PageKind, slot: Int) -> CGPoint {
        switch kind {
        case .year:
            return CGPoint(x: 4 + CGFloat(slot % 6) * 9, y: 4 + CGFloat((slot / 6) % 5) * 8)
        case .month:
            return CGPoint(x: 4 + CGFloat(slot % 10) * 14, y: 30 + CGFloat((slot / 10) % 10) * 10)
        case .week, .day:
            return CGPoint(x: 80 + CGFloat(slot % 24) * 52, y: 20 + CGFloat((slot / 24) % 120) * 15)
        }
    }

    /// Page `pageId` (number `index`) with `count` pen strokes of `pointsPerStroke` points, spread over its cells in turn.
    private static func heavyPage(_ pageId: String, _ kind: PageKind, index: Int, plan: SpanPlan, count: Int) -> InkPage {
        let cells = cells(kind, index: index, plan: plan)
        var page = InkPage.empty(pageId: pageId)
        for i in 0..<count {
            let origin = start(kind, slot: i / cells.count)
            let points = (0..<pointsPerStroke).map { j in
                InkPoint(x: origin.x + CGFloat(j) * 4, y: origin.y + CGFloat(j % 2) * 2, dtMs: j * 8, sizeW: 3.5, sizeH: 3.5,
                         opacity: 1, force: 0.5, azimuth: 0, altitude: .pi / 2)
            }
            page.add(InkStroke(id: "w\(i)", cell: cells[i % cells.count], tool: .pen, color: "#1f2937", t: 1_790_000_001_000 + i,
                               points: points))
        }
        return page
    }

    // MARK: The measurement

    /// The window of `kind` around `focus` with `perPage` strokes on each page, weighed: put in the store (the window's pages
    /// and the page a shift to the right brings in), opened and read (compose), laid out again (relayout), then `shifts`
    /// shifts of the canvas (right, left, right …), each timed from `shiftIfAtRest()` to its return, the page that came in read
    /// before the next. Asserted: the pages, the strokes, no row grown, not stage 2, each shift done with its drawing built.
    private func weigh(_ kind: PageKind, focus: DayKey, perPage: Int, number: Int, shifts: Int,
                       file: StaticString = #filePath, line: UInt = #line) async throws -> (weight: Weight, rig: Rig) {
        let plan = SpanPlan(kind: kind, weekStart: .monday, deviceClass: device, orientation: orientation)
        let center = plan.index(containing: focus)
        let first = center - plan.radius
        let stored = (first...(center + plan.radius + 1)).map { (index: $0, id: plan.pageId(at: $0)) }
        for page in stored {
            try bed.store.save(Self.heavyPage(page.id, kind, index: page.index, plan: plan, count: perPage))
        }
        let windowIds = stored.dropLast().map(\.id)
        let total = windowIds.count * perPage
        let clock = ContinuousClock()

        let opened = clock.now
        let session = bed.session(kind, focus: focus, number: number, deviceClass: device, orientation: orientation)
        await session.prefetch()
        let compose = Self.ms(opened.duration(to: clock.now))
        XCTAssertEqual(session.pageIds, windowIds, "\(kind): the window of the 13-inch iPad in landscape", file: file, line: line)
        XCTAssertFalse(session.hasUnreadPages, "\(kind): every page read", file: file, line: line)
        XCTAssertEqual(session.windowStrokeCount, total, "\(kind): the strokes put in", file: file, line: line)
        XCTAssertFalse(session.fallsBackToOnePage, "\(kind): \(total) strokes are not stage 2 (the iPad's cap 20,000)", file: file, line: line)
        assertNoRowGrew(session, file: file, line: line)

        let relaid = clock.now
        session.relayoutPages()
        let relayout = Self.ms(relaid.duration(to: clock.now))
        XCTAssertFalse(session.fallsBackToOnePage, file: file, line: line)
        assertNoRowGrew(session, file: file, line: line)

        let rig = await attach(session, size: SpanPlan.referenceViewport(kind, deviceClass: device, orientation: orientation))
        XCTAssertEqual(rig.canvas.drawing.strokes.count, total, "\(kind): the canvas draws every stroke of the window", file: file, line: line)
        var times: [Double] = []
        var focusIndex = center
        for k in 0..<shifts {
            let pages = k % 2 == 0 ? 1 : -1
            focusIndex += pages
            rig.canvas.contentOffset.x += CGFloat(pages) * plan.pageWidth * rig.canvas.zoomScale
            rig.coordinator.scrollViewDidScroll(rig.canvas)
            await settle()
            XCTAssertEqual(session.focusPageId, plan.pageId(at: focusIndex), "\(kind): shift \(k + 1), the focus followed", file: file, line: line)
            let builds = rig.coordinator.setDrawingCount
            let started = clock.now
            let outcome = rig.coordinator.shiftIfAtRest()
            times.append(Self.ms(started.duration(to: clock.now)))
            XCTAssertEqual(outcome, .done, "\(kind): shift \(k + 1)", file: file, line: line)
            XCTAssertGreaterThan(rig.coordinator.setDrawingCount, builds, "\(kind): shift \(k + 1) built the drawing again", file: file, line: line)
            await settleUntilTaken(rig)
            XCTAssertEqual(session.pageIds, ((focusIndex - plan.radius)...(focusIndex + plan.radius)).map(plan.pageId(at:)),
                           "\(kind): shift \(k + 1), the window", file: file, line: line)
            XCTAssertFalse(session.hasUnreadPages, "\(kind): shift \(k + 1), the page that came in was read", file: file, line: line)
            XCTAssertEqual(rig.coordinator.spanAppliedWindowVersion, session.windowVersion, file: file, line: line)
            XCTAssertEqual(session.windowStrokeCount, total, "\(kind): shift \(k + 1), the window's strokes", file: file, line: line)
            XCTAssertFalse(session.fallsBackToOnePage, "\(kind): shift \(k + 1), not stage 2", file: file, line: line)
            XCTAssertEqual(rig.canvas.drawing.strokes.count, total, file: file, line: line)
            assertNoRowGrew(session, file: file, line: line)
        }
        return (Weight(pages: windowIds.count, strokes: total, compose: compose, relayout: relayout, shifts: times), rig)
    }

    /// The strokes left every row as an empty page has it: a year 1,860 lu (31 rows of 60), a month's separator line at 1,050
    /// (6 rows of 175), a week's 24 hours of 1,920 (`ZoomPolicy.baseSize`).
    private func assertNoRowGrew(_ session: SpanSession, file: StaticString, line: UInt) {
        let base = ZoomPolicy.baseSize(session.kind)
        for page in session.layout.pages {
            XCTAssertEqual(ZoomPolicy.overviewSize(page).height, base.height, accuracy: 0.001, "\(page.pageId): no row grew", file: file, line: line)
        }
    }

    // MARK: Tests

    /// §3.10: the window of years with the owner's year page (152 strokes a page, 1,064 in all) and with 1,000 a page (7,000;
    /// the years 2033 … 2039 around 11/16/2036, so the two windows share no page): one line each and its relayout line.
    func testTheWeightOfTheLighterWindowsOfYears() async throws {
        for (perPage, focus, number) in [(152, nov16, 1), (1_000, DayKey(year: 2036, month: 11, day: 16), 2)] {
            let (weight, rig) = try await weigh(.year, focus: focus, perPage: perPage, number: number, shifts: 1)
            XCTAssertEqual(weight.pages, 7)
            XCTAssertEqual(weight.strokes, 7 * perPage)
            XCTAssertEqual(weight.shifts.count, 1)
            print("span weight: kind=year pages=\(weight.pages) strokes=\(weight.strokes) compose=\(Self.text(weight.compose)) shift=\(Self.text(weight.shift))")
            print("span weight: kind=year pages=\(weight.pages) strokes=\(weight.strokes) relayout=\(Self.text(weight.relayout))")
            release(rig)
        }
    }

    /// §3.10, 0g-3's 「重い」: the full window of years, 2,800 strokes a page (19,600), its shift the median of three; in the same
    /// test, on the same device and orientation, the window of weeks with the same 19,600 strokes (2,800 on each of its 7
    /// weeks), its shift the median of three too: the reference value that tells a slow runner from a slow year.
    func testTheWeightOfTheFullWindowOfYearsBesideTheWeek() async throws {
        let (year, yearRig) = try await weigh(.year, focus: nov16, perPage: 2_800, number: 1, shifts: 3)
        XCTAssertEqual(year.pages, 7)
        XCTAssertEqual(year.strokes, 19_600)
        XCTAssertEqual(year.shifts.count, 3)
        release(yearRig)
        let (week, weekRig) = try await weigh(.week, focus: nov16, perPage: 2_800, number: 2, shifts: 3)
        XCTAssertEqual(week.pages, 7)
        XCTAssertEqual(week.strokes, 19_600)
        XCTAssertEqual(week.shifts.count, 3)
        release(weekRig)
        print("span weight: kind=year pages=\(year.pages) strokes=\(year.strokes) compose=\(Self.text(year.compose)) shift=\(Self.text(year.shift))")
        print("span weight: kind=year pages=\(year.pages) strokes=\(year.strokes) relayout=\(Self.text(year.relayout))")
        print("span weight: ref=week pages=\(week.pages) strokes=\(week.strokes) shift=\(Self.text(week.shift))")
    }

    /// §3.10: the window of months with the owner's busiest page (1,016 strokes a page, 5,080 in all on 5 months).
    func testTheWeightOfAWindowOfMonths() async throws {
        let (weight, rig) = try await weigh(.month, focus: nov16, perPage: 1_016, number: 1, shifts: 1)
        XCTAssertEqual(weight.pages, 5)
        XCTAssertEqual(weight.strokes, 5_080)
        XCTAssertEqual(weight.shifts.count, 1)
        print("span weight: kind=month pages=\(weight.pages) strokes=\(weight.strokes) compose=\(Self.text(weight.compose)) shift=\(Self.text(weight.shift))")
        print("span weight: kind=month pages=\(weight.pages) strokes=\(weight.strokes) relayout=\(Self.text(weight.relayout))")
        release(rig)
    }
}
