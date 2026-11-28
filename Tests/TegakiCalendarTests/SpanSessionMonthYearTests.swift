@_spi(SpanLedger) import InkModel
import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §3.3, §4.1, §4.2, §8.7, §11.2 row S, §11.5 MS6, MS7, MS8; 0g-10, 0g-11, 0g-12, 0g-16): a
// window of months lines up (`SpanSession.layoutPages` → `SpanAlign.monthFloors` in the form `SpanSession.monthForm`, ア unless
// the owner picks イ or ウ) and its floors move by the session's reading of the change: ink raises them (`.inkGrew`), an erase
// brings them to the window's own (`.inkShrank`), a window decided anew (`redecide(orientation:)`, a new session) too; every
// other `.redecide` — the pages read after a shift (`prefetch`), the events read again, the 30 s check (`contextChanged`), an
// update from outside — is read as `.shift` and never lowers them, so a tall month that left the window keeps the separator
// line where it was. The week and the day keep 1.3's reading. What is saved is cell-relative whatever the floors (§8.7).
//
// Over a live `SyncEngine` (`SessionTestBed`); the canvas is `JoinedLedgerStandIn` (its journal into the session's inbox, as
// the canvas puts it). The months: Monday weeks around 11/16/2026 on the 11-inch iPad in portrait (R = 2): 2026-09 … 2027-01.
// An empty month is six rows of 175 lu (the separator line at 1,050) and a memo of 6,000. A stored stroke at y of a day's cell
// (`SessionTestBed.stroke`: points y, y + 1, y + 2 with a 3.5 lu nib) ends at y + 3.75 for a y on the 0.1 lu grid (`InkPoint`
// rounds x and y to 0.1 lu as it is made, 1.0's data rule; every stored y here is on it), so its row is y + 15.75 lu
// (`MonthLayoutEngine.rowHeight`, the bottom + 12); a memo stroke ending at b makes the memo max(6,000, b + 50).
// Each form's expectation is written out (ア: the last row of the other months grows to the separator line; イ: every row
// lines up; ウ: nothing lines up), so a change of `SpanAlign.monthForm` keeps these tests right.
// D1y (§3.3, §5.1, 0g-21; the section at the end): a window of years lines up its 31 rows (`SpanAlign.yearFloors`) with the
// same reading of the change as the months'.

@MainActor
final class SpanSessionMonthYearTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!

    private let sep = "m1-2026-09"
    private let oct = "m1-2026-10"
    private let nov = "m1-2026-11"
    private let dec = "m1-2026-12"
    private let jan = "m1-2027-01"
    private let feb = "m1-2027-02"
    private let mar = "m1-2027-03"
    private let apr = "m1-2027-04"
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)
    /// November's third row (11/9–11/15).
    private let nov11 = DayKey(year: 2026, month: 11, day: 11)
    private let plainRow: CGFloat = 175
    private let plainGrid: CGFloat = 1_050

    override func setUp() async throws {
        bed = try SessionTestBed("SpanSessionMonthYearTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
    }

    override func tearDown() async throws {
        XCTAssertEqual(faults, [], "no fault of the window's bookkeeping")
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    // MARK: Helpers

    /// A month page with a stored three-point stroke for each (id, cell, y): at x 50 of a day's cell or x 300 of the memo.
    private func page(_ pageId: String, _ strokes: [(id: String, cell: CellKey, y: CGFloat)]) -> InkPage {
        var page = InkPage.empty(pageId: pageId)
        for (i, s) in strokes.enumerated() {
            page.add(bed.stroke(s.id, cell: s.cell, x: s.cell == .memo ? 300 : 50, y: s.y, t: 1_790_000_001_000 + i))
        }
        return page
    }

    /// A window of `kind` around `focus` whose pages are read, `stored` written to the store first.
    private func open(_ kind: PageKind = .month, focus: DayKey? = nil, number: Int = 1, radius: Int? = nil,
                      stored: [InkPage] = []) async throws -> SpanSession {
        for page in stored {
            try bed.store.save(page)
        }
        let session = bed.session(kind, focus: focus ?? nov16, number: number, radius: radius)
        await session.prefetch()
        return session
    }

    private func month(_ pageId: String, of session: SpanSession, file: StaticString = #filePath, line: UInt = #line) throws -> MonthPageLayout {
        let slot = try XCTUnwrap(session.layout.slot(ofPage: pageId), pageId, file: file, line: line)
        return try XCTUnwrap(session.layout.pages[slot] as? MonthPageLayout, pageId, file: file, line: line)
    }

    /// The window cell (band lu) of `cell` on `pageId`.
    private func cell(_ cell: CellKey, of pageId: String, _ session: SpanSession, file: StaticString = #filePath,
                      line: UInt = #line) throws -> CGRect {
        try XCTUnwrap(session.layout.cells[SpanName.prefixed(cell, page: pageId)], "\(pageId) \(cell)", file: file, line: line)
    }

    /// A stroke written through `cell` of `pageId` from y `top` to `bottom` (cell-relative, its centre half way): its bottom
    /// is `bottom` rounded to 0.1 lu (`InkPoint`) + 1.75 (the 3.5 lu nib).
    @discardableResult
    private func write(_ ledger: JoinedLedgerStandIn, on pageId: String, cell key: CellKey, x: CGFloat = 50, top: CGFloat, bottom: CGFloat,
                       file: StaticString = #filePath, line: UInt = #line) throws -> InkStroke {
        let rect = try cell(key, of: pageId, ledger.session, file: file, line: line)
        let stroke = try XCTUnwrap(ledger.draw([CGPoint(x: rect.minX + x, y: rect.minY + top),
                                                CGPoint(x: rect.minX + x + 10, y: rect.minY + (top + bottom) / 2),
                                                CGPoint(x: rect.minX + x + 20, y: rect.minY + bottom)]), file: file, line: line)
        XCTAssertEqual(stroke.cell, SpanName.prefixed(key, page: pageId), "the stroke is filed in its cell", file: file, line: line)
        return stroke
    }

    /// Every page of the window: the separator line (`memo.minY`) and the memo's height, as the form lines them up from the
    /// pages' natural numbers (`naturalGrid` and `naturalMemo` by page id; a page not named is a plain month).
    private func assertLinedUp(_ session: SpanSession, naturalGrid: [String: CGFloat] = [:], naturalMemo: [String: CGFloat] = [:],
                               _ what: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let grids = session.pageIds.map { naturalGrid[$0] ?? plainGrid }
        let memos = session.pageIds.map { naturalMemo[$0] ?? 6_000 }
        for (n, id) in session.pageIds.enumerated() {
            let page = try month(id, of: session, file: file, line: line)
            switch SpanSession.monthForm {
            case .memo, .rows:
                XCTAssertEqual(page.memo.minY, grids.max() ?? plainGrid, accuracy: 0.001, "\(what): \(id)'s separator line", file: file, line: line)
                XCTAssertEqual(page.memo.height, memos.max() ?? 6_000, accuracy: 0.001, "\(what): \(id)'s memo", file: file, line: line)
            case .none:
                XCTAssertEqual(page.memo.minY, grids[n], accuracy: 0.001, "\(what): \(id) as on one page (ウ)", file: file, line: line)
                XCTAssertEqual(page.memo.height, memos[n], accuracy: 0.001, "\(what): \(id) (ウ)", file: file, line: line)
            }
            XCTAssertEqual(page.size.height, page.memo.maxY, accuracy: 0.001, "\(what): \(id) ends with its memo", file: file, line: line)
        }
        XCTAssertEqual(session.layout.floors, session.floors, what, file: file, line: line)
    }

    // MARK: Lining up (MS6)

    /// MS6, §3.3 1–4, §4.1, §4.2: a window of months is laid out from its pages' natural numbers. ア: every month's separator
    /// line goes down to the tallest grid of the window by its 6th row alone (rows 1–5 do not move), and every memo is as tall
    /// as the tallest; イ: every row lines up, row by row; ウ: each month as on one page. The floors are the session's and the
    /// layout's.
    func testTheMonthsLineUpTheirSeparatorLine() async throws {
        let session = try await open(stored: [page(nov, [("tall", .day(nov11), 400)]), page(oct, [("deep", .memo, 6_000)])])
        XCTAssertEqual(session.pageIds, [sep, oct, nov, dec, jan])
        let row: CGFloat = 400 + 15.75
        let grid = 5 * plainRow + row
        let memo: CGFloat = 6_000 + 3.75 + 50
        let november = try month(nov, of: session)
        XCTAssertEqual(november.rows[2].frame.height, row, accuracy: 0.001, "November's own row")
        XCTAssertEqual(november.memo.minY, grid, accuracy: 0.001)
        try assertLinedUp(session, naturalGrid: [nov: grid], naturalMemo: [oct: memo], "opened")

        for id in session.pageIds {
            let page = try month(id, of: session)
            XCTAssertEqual(page.rows.count, 6, id)
            for r in 0..<6 {
                let natural: CGFloat = id == nov && r == 2 ? row : plainRow
                let expected: CGFloat
                switch SpanSession.monthForm {
                case .memo:
                    expected = r == 5 && id != nov ? grid - 5 * plainRow : natural
                case .rows:
                    expected = r == 2 ? row : plainRow
                case .none:
                    expected = natural
                }
                XCTAssertEqual(page.rows[r].frame.height, expected, accuracy: 0.001, "\(id) row \(r + 1)")
                XCTAssertEqual(page.rows[r].frame.width, 1_400, accuracy: 0.001)
            }
        }
        switch SpanSession.monthForm {
        case .memo:
            XCTAssertEqual(session.floors.monthGrid, grid, accuracy: 0.001)
            XCTAssertEqual(session.floors.monthMemo, memo, accuracy: 0.001)
            XCTAssertEqual(session.floors.monthRows, [])
        case .rows:
            XCTAssertEqual(session.floors.monthGrid, 0)
            XCTAssertEqual(session.floors.monthMemo, memo, accuracy: 0.001)
            XCTAssertEqual(session.floors.monthRows.count, 6)
            XCTAssertEqual(session.floors.monthRows[2], row, accuracy: 0.001)
        case .none:
            XCTAssertEqual(session.floors, .none)
        }
        XCTAssertEqual(session.floors.weekExtra, 0)
        XCTAssertEqual(session.floors.dayExtra, 0)
        XCTAssertEqual(session.floors.yearRows, [])
    }

    // MARK: The canvas's relayout (MS7)

    /// MS7, §3.3 (the relayout): a line in October's memo past 5,950 lu makes the memo about 7,000 lu — its bottom + 50,
    /// `PaperGrowth.tailHeight` (`.inkGrew`; ア and イ: every month's memo with it); erased, it comes back to 6,000
    /// (`.inkShrank`: a natural number went down).
    func testTheMemoGrowsWithInkAndComesBackWhenErased() async throws {
        let session = try await open()
        try assertLinedUp(session, "opened")
        let ledger = JoinedLedgerStandIn(session)
        // Centred 5,974.1 lu below the separator line (kept, under the 6,000 lu cap); its last point 6,948.25 is kept as
        // 6,948.3 (`InkPoint`'s 0.1 lu), so its bottom is 6,948.3 + 1.75 = 6,950.05 and the memo's natural height
        // (`MonthLayoutEngine.memoHeight`, §3.3 2) 6,950.05 + 50 = 7,000.05.
        let deep = try write(ledger, on: oct, cell: .memo, x: 300, top: 5_000, bottom: 6_948.25)
        ledger.put()
        session.relayoutPages()
        let bottom = try XCTUnwrap(session.page(oct)?.inkBottoms()[.memo])
        XCTAssertEqual(bottom, 6_950.05, accuracy: 0.001)
        let memo = MonthLayoutEngine.memoHeight(inkBottom: bottom)
        XCTAssertEqual(memo, 7_000.05, accuracy: 0.001)
        try assertLinedUp(session, naturalMemo: [oct: memo], "a memo line past 5,950 lu (.inkGrew)")
        if SpanSession.monthForm != .none {
            XCTAssertEqual(session.floors.monthMemo, memo, accuracy: 0.001)
        }
        XCTAssertEqual(ledger.erase([deep.id]), [deep.id])
        ledger.put()
        session.relayoutPages()
        try assertLinedUp(session, "erased (.inkShrank)")
        if SpanSession.monthForm != .none {
            XCTAssertEqual(session.floors.monthMemo, 6_000, accuracy: 0.001)
        }
    }

    /// §3.3, §4.1, §4.2: a line down November's 11th lengthens its row; ア: every other month's 6th row grows with it, so the
    /// separator line stays one line (their rows 1–5 do not move); イ: their 3rd row; ウ: nothing else moves. Erased, the window
    /// comes back.
    func testInkInTheGridLengthensTheOtherMonthsLastRow() async throws {
        let session = try await open()
        let ledger = JoinedLedgerStandIn(session)
        // Centred at y 170 of the 11th's cell (inside its 175 lu), its bottom at 331.75: the row is 343.75 lu.
        let line = try write(ledger, on: nov, cell: .day(nov11), top: 10, bottom: 330)
        ledger.put()
        session.relayoutPages()
        let row: CGFloat = 330 + 1.75 + 12
        XCTAssertEqual(try month(nov, of: session).rows[2].frame.height, row, accuracy: 0.001)
        let grid = 5 * plainRow + row
        try assertLinedUp(session, naturalGrid: [nov: grid], "a line in November's grid (.inkGrew)")
        for id in [sep, oct, dec, jan] {
            let page = try month(id, of: session)
            let heights = page.rows.map(\.frame.height)
            switch SpanSession.monthForm {
            case .memo:
                XCTAssertEqual(Array(heights.prefix(5)), Array(repeating: plainRow, count: 5), "\(id): rows 1–5 stay")
                XCTAssertEqual(heights[5], row, accuracy: 0.001, "\(id): the 6th row reaches the separator line")
            case .rows:
                XCTAssertEqual(heights[2], row, accuracy: 0.001, "\(id): the 3rd row lines up")
            case .none:
                XCTAssertEqual(heights, Array(repeating: plainRow, count: 6), "\(id): ウ")
            }
        }
        XCTAssertEqual(ledger.erase([line.id]), [line.id])
        ledger.put()
        session.relayoutPages()
        try assertLinedUp(session, "erased (.inkShrank)")
    }

    // MARK: Read as a shift (MS8)

    /// MS8, §3.3 (the third edition), §4.6, 0g-16: a tall November lines the window up; after a shift that takes it out, the
    /// floors stay through the shift, the reads of the pages that came in (`prefetch`), the events read again, the 30 s check
    /// (`contextChanged`) and an update from outside — each of them `.redecide`, read as `.shift` for the months — so the
    /// separator line does not rise and the lowest zoom (the window's `memo.minY`) does not come up from a sideways move.
    func testATallMonthThatLeftTheWindowKeepsTheFloors() async throws {
        let session = try await open(stored: [page(nov, [("tall", .day(nov11), 400)])])
        let grid = 5 * plainRow + 400 + 15.75
        try assertLinedUp(session, naturalGrid: [nov: grid], "opened")
        let floors = session.floors
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 3))
        XCTAssertEqual(session.pageIds, [dec, jan, feb, mar, apr])
        let kept: [String: CGFloat] = SpanSession.monthForm == .none ? [:] : Dictionary(uniqueKeysWithValues: session.pageIds.map { ($0, grid) })
        XCTAssertEqual(session.floors, floors, "the shift")
        try assertLinedUp(session, naturalGrid: kept, "the shift (.shift never lowers)")
        await session.prefetch()
        XCTAssertEqual(session.floors, floors, "the pages read after the shift")
        try assertLinedUp(session, naturalGrid: kept, "prefetch: .redecide read as .shift")
        session.reloadEvents()
        XCTAssertEqual(session.floors, floors, "the events read again")
        session.contextChanged()
        XCTAssertEqual(session.floors, floors, "the 30 s check")
        session.remoteUpdated(page(feb, [("remote", .day(DayKey(year: 2027, month: 2, day: 10)), 40)]))
        XCTAssertEqual(session.page(feb)?.liveStrokeIds, ["remote"], "the update was taken")
        XCTAssertEqual(session.floors, floors, "an update from outside")
        try assertLinedUp(session, naturalGrid: kept, "after every .redecide")
    }

    /// §3.3 (the relayout, the third edition): after the tall month left, a little ink on another month keeps the floors (the
    /// relayout compares the pages' natural numbers with the last layout's, not with the floors: `.inkGrew`), and so does a
    /// longer line still short of them; erasing that line lowers a natural number (`.inkShrank`), so the floors come down to
    /// the window's own.
    func testAfterItLittleInkKeepsTheFloorsAndAnEraseLowersThem() async throws {
        let session = try await open(stored: [page(nov, [("tall", .day(nov11), 400)])])
        let grid = 5 * plainRow + 400 + 15.75
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 3))
        await session.prefetch()
        let floors = session.floors
        let kept: [String: CGFloat] = SpanSession.monthForm == .none ? [:] : Dictionary(uniqueKeysWithValues: session.pageIds.map { ($0, grid) })
        let ledger = JoinedLedgerStandIn(session)
        try write(ledger, on: mar, cell: .day(DayKey(year: 2027, month: 3, day: 10)), top: 30, bottom: 50)
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(session.floors, floors, "a little ink on March: .inkGrew")
        try assertLinedUp(session, naturalGrid: kept, "a little ink")
        let line = try write(ledger, on: feb, cell: .day(DayKey(year: 2027, month: 2, day: 10)), top: 10, bottom: 300)
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(try month(feb, of: session).rows[1].frame.height, 300 + 1.75 + 12, accuracy: 0.001, "February's row grew")
        XCTAssertEqual(session.floors, floors, "a longer line, still short of the floors")
        XCTAssertEqual(ledger.erase([line.id]), [line.id])
        ledger.put()
        session.relayoutPages()
        try assertLinedUp(session, "erased: the window's own (.inkShrank)")
        if SpanSession.monthForm == .memo {
            XCTAssertEqual(session.floors.monthGrid, plainGrid, accuracy: 0.001)
        }
    }

    /// §3.3: the floors come down when the window is decided anew — a change of width (`redecide(orientation:)`, the canvas's
    /// after a rotation or Split View) and a new session (opening anew) start from the window's own pages.
    func testTheFloorsComeDownWhenTheWindowIsDecidedAnew() async throws {
        let session = try await open(stored: [page(nov, [("tall", .day(nov11), 400)])])
        let grid = 5 * plainRow + 400 + 15.75
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 4))
        await session.prefetch()
        XCTAssertFalse(session.pageIds.contains(nov))
        let kept: [String: CGFloat] = SpanSession.monthForm == .none ? [:] : Dictionary(uniqueKeysWithValues: session.pageIds.map { ($0, grid) })
        try assertLinedUp(session, naturalGrid: kept, "after the shift")
        XCTAssertTrue(session.redecide(orientation: .landscape))
        XCTAssertFalse(session.pageIds.contains(nov), "\(session.pageIds)")
        try assertLinedUp(session, "decided anew after a change of width")
        if SpanSession.monthForm == .memo {
            XCTAssertEqual(session.floors.monthGrid, plainGrid, accuracy: 0.001)
        }
        XCTAssertTrue(session.redecide(orientation: .portrait))
        try assertLinedUp(session, "and back")

        let anew = try await open(focus: DayKey(year: 2027, month: 3, day: 16), number: 2)
        XCTAssertFalse(anew.pageIds.contains(nov))
        try assertLinedUp(anew, "a new session")
        let again = try await open(number: 3)
        try assertLinedUp(again, naturalGrid: [nov: grid], "a new session with the tall month in it")
    }

    // MARK: The week and the day keep 1.3's reading

    /// §3.3: the week's floor comes down once the pages that came in after a shift are read (1.3's `.redecide`), as the frozen
    /// WeekMemoSpanTests says; the months' reading does not reach the week.
    func testTheWeeksKeepTheirReading() async throws {
        let w1109 = "w-2026-11-09"
        let session = try await open(.week, radius: 1)
        XCTAssertEqual(session.pageIds, [w1109, "w-2026-11-16", "w-2026-11-23"])
        let ledger = JoinedLedgerStandIn(session)
        try write(ledger, on: w1109, cell: .extra, x: 300, top: 5_000, bottom: 6_948.25)
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(session.floors.weekExtra, 7_000, accuracy: 0.5)
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 1))
        XCTAssertEqual(session.floors.weekExtra, 7_000, accuracy: 0.5, "a shift never lowers it")
        await session.prefetch()
        XCTAssertEqual(session.floors.weekExtra, 6_000, accuracy: 0.001, "read: .redecide, the window's tallest (1.3)")
        XCTAssertEqual(session.floors.monthGrid, 0)
        XCTAssertEqual(session.floors.monthMemo, 0)
    }

    /// §3.3: the same for the day's free memo below 24:00.
    func testTheDaysKeepTheirReading() async throws {
        let left = "d-2026-11-15"
        let session = try await open(.day, radius: 1)
        XCTAssertEqual(session.pageIds, [left, "d-2026-11-16", "d-2026-11-17"])
        let ledger = JoinedLedgerStandIn(session)
        try write(ledger, on: left, cell: .extra, x: 300, top: 5_000, bottom: 6_948.25)
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(session.floors.dayExtra, 7_000, accuracy: 0.5)
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 1))
        XCTAssertEqual(session.floors.dayExtra, 7_000, accuracy: 0.5, "a shift never lowers it")
        await session.prefetch()
        XCTAssertEqual(session.floors.dayExtra, 6_000, accuracy: 0.001, "read: .redecide, the window's tallest (1.3)")
        session.contextChanged()
        XCTAssertEqual(session.floors.dayExtra, 6_000, accuracy: 0.001)
    }

    // MARK: What is saved (§8.7)

    /// §8.7, K-4: what a window of months saves is relative to its cell, whatever the floors: a memo line under October's
    /// separator line (moved down by November's tall row in ア and イ) and a line in October's 6th row (lengthened in ア) are
    /// saved with the same cell-relative points as the same lines in a window with no floor (around 2027-06), in their plain
    /// cell keys, no window name in the page.
    func testWhatIsSavedIsCellRelativeWhateverTheFloors() async throws {
        let session = try await open(stored: [page(nov, [("tall", .day(nov11), 400)])])
        let nov2 = DayKey(year: 2026, month: 11, day: 2)
        XCTAssertEqual(try month(oct, of: session).rows[5].days.first, nov2, "October's 6th row is 11/2–11/8")
        let ledger = JoinedLedgerStandIn(session)
        let inMemo = try write(ledger, on: oct, cell: .memo, x: 300, top: 200, bottom: 240)
        let inRow = try write(ledger, on: oct, cell: .day(nov2), x: 60, top: 10, bottom: 150)
        ledger.deliver()
        XCTAssertEqual(session.saveAll(), [])
        let saved = bed.store.load(oct)
        XCTAssertFalse(saved.strokes.keys.contains { $0.contains("|") }, "no window name in the page")
        let memoStroke = try XCTUnwrap(saved.strokes[try XCTUnwrap(SpanName.split(inMemo.id)?.local)])
        let rowStroke = try XCTUnwrap(saved.strokes[try XCTUnwrap(SpanName.split(inRow.id)?.local)])
        XCTAssertEqual(memoStroke.cell, .memo)
        XCTAssertEqual(rowStroke.cell, .day(nov2))

        let plain = try await open(focus: DayKey(year: 2027, month: 6, day: 16), number: 2)
        let june = "m1-2027-06"
        let june2 = try month(june, of: plain).rows[5].days[0]
        let other = JoinedLedgerStandIn(plain, seed: 0x5A01_7778)
        let juneMemoLine = try write(other, on: june, cell: .memo, x: 300, top: 200, bottom: 240)
        let juneRowLine = try write(other, on: june, cell: .day(june2), x: 60, top: 10, bottom: 150)
        other.deliver()
        XCTAssertEqual(plain.saveAll(), [])
        let savedJune = bed.store.load(june)
        let juneMemo = try XCTUnwrap(savedJune.strokes[try XCTUnwrap(SpanName.split(juneMemoLine.id)?.local)])
        let juneRow = try XCTUnwrap(savedJune.strokes[try XCTUnwrap(SpanName.split(juneRowLine.id)?.local)])
        func points(_ stroke: InkStroke) -> [CGPoint] { stroke.points.map { CGPoint(x: $0.x, y: $0.y) } }
        XCTAssertEqual(points(memoStroke), points(juneMemo), "the memo line: the same points from the memo's origin")
        XCTAssertEqual(points(rowStroke), points(juneRow), "the 6th row's line: the same points from its cell's origin")
        XCTAssertEqual(points(memoStroke).map(\.y), [200, 220, 240])
        XCTAssertEqual(points(rowStroke).map(\.y), [10, 80, 150])
    }

    // MARK: D1y — the window of years (§3.3, §5.1, 0g-21)
    //
    // Five years around 2026 on the 11-inch iPad in portrait (R = 2): 2024 … 2028. A row of an empty year is 60 lu; a row's
    // natural height is `YearLayoutEngine.rowHeight` — min(400, max(60, 16 + lanes × 18 + 8, the deepest bottom of its 12
    // cells + 12)) — so a stored stroke at y of a cell (`SessionTestBed.stroke`: y, y + 1, y + 2 with a 3.5 lu nib, y on the
    // 0.1 lu grid) makes its row y + 15.75 lu, at most 400.

    private let y2024 = "y-2024"
    private let y2025 = "y-2025"
    private let y2026 = "y-2026"
    private let y2027 = "y-2027"
    private let y2028 = "y-2028"
    private let plainYearRow: CGFloat = 60

    private func year(_ pageId: String, of session: SpanSession, file: StaticString = #filePath, line: UInt = #line) throws -> YearPageLayout {
        let slot = try XCTUnwrap(session.layout.slot(ofPage: pageId), pageId, file: file, line: line)
        return try XCTUnwrap(session.layout.pages[slot] as? YearPageLayout, pageId, file: file, line: line)
    }

    /// Every year page of the window has the 31 row heights `rows` (index 0 is the 1st's row), each row's top the sum of the
    /// rows above it — the same on every page, so the same day runs on in one line — every cell at its column's x and width,
    /// and the session's floors are those rows.
    private func assertRows(_ session: SpanSession, _ rows: [CGFloat], _ what: String, file: StaticString = #filePath,
                            line: UInt = #line) throws {
        XCTAssertEqual(rows.count, 31, file: file, line: line)
        for id in session.pageIds {
            let page = try year(id, of: session, file: file, line: line)
            XCTAssertEqual(page.rows.count, 31, "\(what): \(id)", file: file, line: line)
            var top: CGFloat = 0
            for (r, row) in page.rows.enumerated() {
                XCTAssertEqual(row.frame.height, rows[r], accuracy: 0.001, "\(what): \(id) row \(r + 1)", file: file, line: line)
                XCTAssertEqual(row.frame.minY, top, accuracy: 0.001, "\(what): \(id) row \(r + 1)'s top", file: file, line: line)
                XCTAssertLessThanOrEqual(row.frame.height, 400, "\(what): \(id) row \(r + 1) under the cap", file: file, line: line)
                top += rows[r]
            }
            XCTAssertEqual(page.size.height, top, accuracy: 0.001, "\(what): \(id)'s height", file: file, line: line)
            for month in [1, 6, 12] {
                let cell = try XCTUnwrap(page.cells[.yearDay(month: month, day: 15)], "\(id) \(month)/15", file: file, line: line)
                XCTAssertEqual(cell.minX, 56 + CGFloat(month - 1) * 112, accuracy: 0.001, "\(what): \(id) \(month)'s x", file: file, line: line)
                XCTAssertEqual(cell.width, 112, accuracy: 0.001, file: file, line: line)
                XCTAssertEqual(cell.height, rows[14], accuracy: 0.001, file: file, line: line)
            }
        }
        XCTAssertEqual(session.floors.yearRows.count, 31, what, file: file, line: line)
        for (r, floor) in session.floors.yearRows.enumerated() {
            XCTAssertEqual(floor, rows[r], accuracy: 0.001, "\(what): the floor of row \(r + 1)", file: file, line: line)
        }
        XCTAssertEqual(session.layout.floors, session.floors, what, file: file, line: line)
    }

    /// The 31 rows of a plain year with `grown` rows (index 0 is the 1st's row) taller.
    private func rows(_ grown: [Int: CGFloat] = [:]) -> [CGFloat] {
        (0..<31).map { grown[$0] ?? plainYearRow }
    }

    /// MS6 for the year, §3.3 1–4, §5.1: a window of years lines up row by row — each of the 31 rows has the window's largest
    /// natural height on every year (a line on 2026's 11/20, a deep one on 2025's 3/5, one past the cap on 2027's 7/10: the
    /// 20th's row 115.75, the 5th's 265.75, the 10th's 400), so every row's top is the same on every page and no row passes
    /// 400 lu. The x and the width of every cell stay; the month's, the week's and the day's floors are 0.
    func testTheYearsLineUpTheirRows() async throws {
        let session = try await open(.year, stored: [page(y2026, [("tall", .yearDay(month: 11, day: 20), 100)]),
                                                     page(y2025, [("deep", .yearDay(month: 3, day: 5), 250)]),
                                                     page(y2027, [("capped", .yearDay(month: 7, day: 10), 600)])])
        XCTAssertEqual(session.pageIds, [y2024, y2025, y2026, y2027, y2028])
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 100 + 2 + 1.75), 115.75, accuracy: 0.001)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 250 + 2 + 1.75), 265.75, accuracy: 0.001)
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 600 + 2 + 1.75), 400, "the cap")
        let lined = rows([19: 115.75, 4: 265.75, 9: 400])
        try assertRows(session, lined, "opened")
        let own = try year(y2028, of: session)
        XCTAssertEqual(own.rows[19].frame.minY, try year(y2026, of: session).rows[19].frame.minY, "the 20th in one line across the years")
        XCTAssertEqual(session.floors.monthGrid, 0)
        XCTAssertEqual(session.floors.monthMemo, 0)
        XCTAssertEqual(session.floors.monthRows, [])
        XCTAssertEqual(session.floors.weekExtra, 0)
        XCTAssertEqual(session.floors.dayExtra, 0)
    }

    /// MS8 for the year, §3.3 (the third edition): after a shift takes the tall year (2026's 20th, 115.75) out of the window,
    /// its row stays through the shift, the pages read after it (`prefetch`), the events read again, the 30 s check
    /// (`contextChanged`) and an update from outside — each `.redecide` read as `.shift` — so no row of the years on screen
    /// shrinks from a sideways move.
    func testATallYearThatLeftTheWindowKeepsItsRows() async throws {
        let session = try await open(.year, stored: [page(y2026, [("tall", .yearDay(month: 11, day: 20), 100)])])
        let tall = rows([19: 115.75])
        try assertRows(session, tall, "opened")
        let floors = session.floors
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 3))
        XCTAssertEqual(session.pageIds, [y2027, y2028, "y-2029", "y-2030", "y-2031"])
        XCTAssertEqual(session.floors, floors, "the shift")
        try assertRows(session, tall, "the shift (.shift never lowers)")
        await session.prefetch()
        XCTAssertEqual(session.floors, floors, "the pages read after the shift")
        session.reloadEvents()
        XCTAssertEqual(session.floors, floors, "the events read again")
        session.contextChanged()
        XCTAssertEqual(session.floors, floors, "the 30 s check")
        session.remoteUpdated(page("y-2029", [("remote", .yearDay(month: 2, day: 10), 10)]))
        XCTAssertEqual(session.page("y-2029")?.liveStrokeIds, ["remote"], "the update was taken")
        XCTAssertEqual(session.floors, floors, "an update from outside")
        try assertRows(session, tall, "after every .redecide")
    }

    /// MS7 for the year, §3.3 (the relayout, the third edition): after the tall year left, a little ink on another year keeps
    /// the rows (the relayout compares the pages' natural rows with the last layout's: `.inkGrew`); a longer line on 2030's
    /// 2/10 (its bottom 91.75, the 10th's row 103.75) raises that row on every year; erased, a natural row went down
    /// (`.inkShrank`), so the rows come down to the window's own: all 60.
    func testAfterItLittleInkKeepsTheRowsAndAnEraseLowersThem() async throws {
        let session = try await open(.year, stored: [page(y2026, [("tall", .yearDay(month: 11, day: 20), 100)])])
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 3))
        await session.prefetch()
        let floors = session.floors
        let ledger = JoinedLedgerStandIn(session)
        try write(ledger, on: "y-2029", cell: .yearDay(month: 3, day: 10), top: 10, bottom: 30)
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(session.floors, floors, "a little ink on 2029: .inkGrew")
        try assertRows(session, rows([19: 115.75]), "a little ink")
        let line = try write(ledger, on: "y-2030", cell: .yearDay(month: 2, day: 10), top: 10, bottom: 90)
        ledger.put()
        session.relayoutPages()
        XCTAssertEqual(YearLayoutEngine.rowHeight(laneCount: 0, inkBottom: 90 + 1.75), 103.75, accuracy: 0.001)
        try assertRows(session, rows([19: 115.75, 9: 103.75]), "a longer line raises its row on every year")
        XCTAssertEqual(ledger.erase([line.id]), [line.id])
        ledger.put()
        session.relayoutPages()
        try assertRows(session, rows(), "erased: the window's own (.inkShrank)")
    }

    /// §3.3, §5.1: the rows come down when the window is decided anew — a change of width (`redecide(orientation:)`; the
    /// landscape window, 2027 … 2033, holds no tall year) and a new session — and a year whose all-day events are read
    /// (`prefetch` reads the other years' events: three on 2031's 11/20, three lanes, the 20th's row 16 + 3 × 18 + 8 = 78 lu)
    /// raises that row on every year (the events read: `.redecide`, read as `.shift`, which raises).
    func testTheRowsComeDownWhenDecidedAnewAndRiseWithTheAllDayEventsRead() async throws {
        let session = try await open(.year, stored: [page(y2026, [("tall", .yearDay(month: 11, day: 20), 100)])])
        XCTAssertTrue(session.shift(toFocusIndex: session.focusIndex + 4))
        await session.prefetch()
        XCTAssertEqual(session.pageIds, [y2028, "y-2029", "y-2030", "y-2031", "y-2032"])
        try assertRows(session, rows([19: 115.75]), "after the shift")
        XCTAssertTrue(session.redecide(orientation: .landscape))
        XCTAssertEqual(session.pageIds, [y2027, y2028, "y-2029", "y-2030", "y-2031", "y-2032", "y-2033"])
        try assertRows(session, rows(), "decided anew after a change of width")
        XCTAssertTrue(session.redecide(orientation: .portrait))
        try assertRows(session, rows(), "and back")
        let anew = try await open(.year, focus: DayKey(year: 2030, month: 6, day: 1), number: 2)
        try assertRows(anew, rows(), "a new session")
        let again = try await open(.year, number: 3)
        try assertRows(again, rows([19: 115.75]), "a new session with the tall year in it")

        let nov20 = DayKey(year: 2031, month: 11, day: 20)
        let events = (1...3).map { n in
            LayoutEvent(id: "all-day-\(n)", title: "all day \(n)", allDay: true, start: nov20.startOfDay(in: SessionTestBed.tokyo),
                        end: nov20.adding(days: 1).startOfDay(in: SessionTestBed.tokyo), colorHex: "#33b679", calendarId: "test")
        }
        let read = bed.session(.year, focus: DayKey(year: 2030, month: 5, day: 1), number: 4,
                               eventSource: { from, to in from <= nov20 && nov20 < to ? events : [] })
        let lanes = YearLayoutEngine.rowHeight(laneCount: 3, inkBottom: 0)
        XCTAssertEqual(lanes, 16 + 3 * 18 + 8, accuracy: 0.001)
        XCTAssertEqual(read.pageIds, [y2028, "y-2029", "y-2030", "y-2031", "y-2032"])
        try assertRows(read, rows(), "before 2031's events are read (the focus year's alone)")
        await read.prefetch()
        XCTAssertEqual(try year("y-2031", of: read).rows[19].laneCount, 3)
        try assertRows(read, rows([19: lanes]), "2031's all-day events read: its row on every year")
    }
}
