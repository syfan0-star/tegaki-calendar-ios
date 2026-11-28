import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §2.1, §3.1, §11.2 row S, §11.5 MS1, MS4, MP1, 0g-8): the kinds of page that join sideways
// are one set, `SpanKinds.joined`, and every reader of it gives the answer the set gives — the path (`ScreenPaths.joins` with
// the setting on), the first-time guide (`SpanGuide.joinedKinds` and its words), 等倍 (`ZoomReset.followsFit`), the paper of
// a window page (`ScreenPaths.paper(of:)`) and the window's paper (`PaperSpan.window`). The fallback of 0g-3 takes `.year` out
// of the set alone: nothing here names the year's answer, every expectation is read from the set, so these tests pass
// unchanged with the year in (D1y) or out (0g-3).

@MainActor
final class SpanKindsTests: XCTestCase {
    private var bed: SessionTestBed!
    private var faults: [String] = []
    private var savedOnFault: ((String) -> Void)!
    private let nov16 = DayKey(year: 2026, month: 11, day: 16)

    override func setUp() async throws {
        bed = try SessionTestBed("SpanKindsTests")
        faults = []
        savedOnFault = SpanSession.onFault
        SpanSession.onFault = { [weak self] in self?.faults.append($0) }
    }

    override func tearDown() async throws {
        SpanSession.onFault = savedOnFault
        bed?.tearDown()
        bed = nil
    }

    /// The set holds the week and the day of 1.3 and the month of 1.4.3 (D1b); `ordered` is the set in the order week, day,
    /// month, year, each once, nothing outside the set.
    func testTheJoinedKindsAndTheirOrder() {
        XCTAssertTrue(SpanKinds.joined.isSuperset(of: [.week, .day, .month]), "\(SpanKinds.joined)")
        XCTAssertEqual(SpanKinds.ordered, [PageKind.week, .day, .month, .year].filter { SpanKinds.joined.contains($0) })
        XCTAssertEqual(Set(SpanKinds.ordered), SpanKinds.joined, "every kind of the set, nothing else")
        XCTAssertEqual(SpanKinds.ordered.count, SpanKinds.joined.count, "each once")
        XCTAssertEqual(Array(SpanKinds.ordered.prefix(3)), [.week, .day, .month], "the week, the day, the month first")
    }

    /// MS1, MS4: the path with the setting on, the guide's kinds and words, and 等倍 answer as the set does, for every kind
    /// (`PageKind.allCases`, so a fifth kind would be named too). The path's other conditions are the same for every kind
    /// of the set: the setting off, stage 2 and the old versions' one page keep it on one page.
    func testEveryReaderOfTheSetAgrees() {
        XCTAssertEqual(PageKind.allCases.count, 4)
        for kind in PageKind.allCases {
            let joined = SpanKinds.joined.contains(kind)
            XCTAssertEqual(ScreenPaths.joins(kind: kind, setting: true, screenshot: false, screenshotSpan: false, fallenBack: []), joined,
                           "\(kind): the path with the setting on")
            XCTAssertEqual(ScreenPaths.joins(kind: kind, setting: false, screenshot: true, screenshotSpan: true, fallenBack: []), joined,
                           "\(kind): screenshot mode's own setting (--screenshot-span on)")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: false, screenshot: false, screenshotSpan: true, fallenBack: []),
                           "\(kind): the setting off")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: false, screenshotSpan: false, fallenBack: [kind]),
                           "\(kind): stage 2")
            XCTAssertFalse(ScreenPaths.joins(kind: kind, setting: true, screenshot: true, screenshotSpan: true, singlePage: true, fallenBack: []),
                           "\(kind): --screenshot-single-page")
            XCTAssertEqual(SpanGuide.joinedKinds.contains(kind), joined, "\(kind): the guide's kinds")
            XCTAssertEqual(ZoomReset.followsFit(kind), joined, "\(kind): 等倍 is fit")
            for finger in [false, true] {
                XCTAssertEqual(SpanGuide.text(kind: kind, allowFinger: finger) != nil, joined, "\(kind): the guide's words, finger \(finger)")
                XCTAssertEqual(SpanGuide.isDue(kind: kind, setting: true, joined: true, shown: false, screenshot: false, testHost: false), joined,
                               "\(kind): the guide is due")
            }
        }
        XCTAssertEqual(SpanGuide.joinedKinds, SpanKinds.ordered)
    }

    /// MP1: the paper of a window page (`ScreenPaths.paper(of:)`, the PDF's) and the window's paper (`PaperSpan.window`, the
    /// canvas's since R3 and the heading's) are there for every kind of the set and nil for a kind outside it, on a session
    /// of each kind around 11/16 (the 11-inch iPad, portrait).
    func testThePaperOfEveryJoinedKind() async throws {
        for (number, kind) in PageKind.allCases.enumerated() {
            let joined = SpanKinds.joined.contains(kind)
            let session = bed.session(kind, focus: nov16, number: number + 1)
            await session.prefetch()
            XCTAssertEqual(session.layout.pages.count, session.pageIds.count, "\(kind)")
            let focus = session.layout.pages[session.focusSlot]
            let paper = ScreenPaths.paper(of: focus)
            XCTAssertEqual(paper != nil, joined, "\(kind): ScreenPaths.paper(of:)")
            if let paper {
                XCTAssertEqual(paper.kind, kind)
                XCTAssertEqual(paper, PaperSpan.paperContent(of: focus), "\(kind): the one place a window's paper is made")
                XCTAssertEqual(paper.layout.pageId, session.focusPageId)
            }
            let window = PaperSpan.window(for: session.layout, focus: session.focusSlot)
            XCTAssertEqual(window != nil, joined, "\(kind): PaperSpan.window")
            if let window {
                XCTAssertEqual(window.kind, kind)
                XCTAssertEqual(window.pages.map(\.layout.pageId), session.pageIds, "\(kind)")
                XCTAssertEqual(window.focus, session.focusSlot, "\(kind)")
            }
        }
        XCTAssertEqual(faults, [])
    }
}
