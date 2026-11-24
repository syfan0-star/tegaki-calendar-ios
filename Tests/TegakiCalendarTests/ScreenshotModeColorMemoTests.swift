import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §4.7, §6.1, 0f-18, 0f-19): screenshot mode's new arguments. This file holds the memo
// paper's (`--screenshot-memo-paper ruled|dots|plain`, D1a, role S); the pen colours' (`--screenshot-color-panel`,
// `--screenshot-pen-slots`, D1b) join it with their own tests. An unknown value or none is nil (the ruled paper), the other
// arguments read as before, and screenshot mode never reads or writes `paper.memoStyle`: the launch takes the argument whatever
// is stored and writes nothing (mutation MM3).
@MainActor
final class ScreenshotModeColorMemoTests: XCTestCase {
    private let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week"]

    override func tearDown() async throws {
        MemoPaperStyle.set(.ruled)
    }

    func testParseMemoPaper() {
        XCTAssertNil(ScreenshotMode.parse(base)?.memoPaper, "the ruled paper without the argument")
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-memo-paper", "dots"])?.memoPaper, .dots)
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-memo-paper", "plain"])?.memoPaper, .plain)
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-memo-paper", "ruled"])?.memoPaper, .ruled)
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-memo-paper", "dots"] + base)?.memoPaper, .dots, "anywhere in the arguments")
        for bad in ["", "Dots", "DOTS", "dot", "grid", "blank", "lined", "--screenshot-probe"] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-memo-paper", bad])?.memoPaper, "memo paper \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-memo-paper"])?.memoPaper, "no value")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-memo-paper", "dots"]), "never active without --screenshot-mode")
    }

    /// The memo paper changes nothing else: the rest of the config is the one the same arguments gave before 1.4.2 (the grown
    /// demo, the offset, the joined pages and the week memo of the memo paper's photos included), and every earlier Config is
    /// the same value as before (nil by default).
    func testMemoPaperLeavesTheOtherArgumentsAlone() throws {
        let photos: [[String]] = [
            ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month", "--screenshot-grown", "--screenshot-offset", "0,1700"],
            ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "day", "--screenshot-grown", "--screenshot-offset", "0,2300"],
            base + ["--screenshot-span", "on", "--screenshot-week-memo", "--screenshot-offset", "0,1500", "--screenshot-offset-x", "-0.5"],
            base + ["--screenshot-toolbar", "collapsed-right", "--screenshot-tool", "marker", "--screenshot-probe", "--screenshot-hand", "left"],
            base + ["--screenshot-sheet", "settings"],
        ]
        for arguments in photos {
            var plain = try XCTUnwrap(ScreenshotMode.parse(arguments))
            XCTAssertNil(plain.memoPaper, "\(arguments)")
            for style in MemoPaperStyle.allCases {
                let memo = try XCTUnwrap(ScreenshotMode.parse(arguments + ["--screenshot-memo-paper", style.rawValue]))
                plain.memoPaper = style
                // `today` is fixed by the month, so the two parses are the same value but for the memo paper.
                XCTAssertEqual(memo, plain, "\(arguments) \(style)")
            }
        }
        let made = ScreenshotMode.Config(page: .month, month: YearMonth(year: 2026, month: 10), today: Date(timeIntervalSince1970: 0),
                                         focus: DayKey(year: 2026, month: 10, day: 7), sheet: nil)
        XCTAssertNil(made.memoPaper, "the memberwise Config of the earlier tests: the ruled paper")
    }

    /// Screenshot mode never reads or writes `paper.memoStyle` (§4.7): the launch takes the argument (ruled without it)
    /// whatever is stored, on or off a test host (MM3), and writes nothing. Normal use reading the store is
    /// MemoPaperStyleTests' (MM4), and a choice in the settings storing nothing there is SettingsScreenTests' (MS3), so each
    /// mutation fails exactly the tests of §6.4's table.
    func testScreenshotModeStoresAndReadsNoMemoPaper() throws {
        let suite = "test-memo-paper-shot-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
        }
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let dots = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-memo-paper", "dots"]))
        for testHost in [false, true] {
            MemoPaperStyle.prepareAtLaunch(shot: plain, scratch, testHost: testHost)
            XCTAssertEqual(MemoPaperStyle.current, .ruled)
            MemoPaperStyle.prepareAtLaunch(shot: dots, scratch, testHost: testHost)
            XCTAssertEqual(MemoPaperStyle.current, .dots)
        }
        XCTAssertNil(scratch.object(forKey: AppSettings.memoPaperKey), "the launch writes nothing")

        scratch.set("plain", forKey: AppSettings.memoPaperKey)
        MemoPaperStyle.prepareAtLaunch(shot: plain, scratch, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .ruled, "the stored plain is not read in screenshot mode")
        MemoPaperStyle.prepareAtLaunch(shot: dots, scratch, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .dots)
    }
}
