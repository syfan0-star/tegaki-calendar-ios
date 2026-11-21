import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.1, §4.10, §6.1, 0e-21): screenshot mode's new arguments. This file holds the hand's
// (`--screenshot-hand left|right`, track H); the toolbar's edges (`--screenshot-palette`, `--screenshot-palette-drag`, track
// S/T, D1b) join it with their own tests. An unknown value or none is nil, the other arguments read as before (the
// `--screenshot-toolbar` values of 1.1 included), and screenshot mode stores nothing: neither the hand (`layout.hand`) nor the
// round button's corner (`toolbar.collapsedEdge`) that switching the hand writes in normal use.
@MainActor
final class ScreenshotModeHandPaletteTests: XCTestCase {
    private let base = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "week"]

    func testParseHand() {
        XCTAssertNil(ScreenshotMode.parse(base)?.hand, "the right hand without the argument")
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-hand", "left"])?.hand, .left)
        XCTAssertEqual(ScreenshotMode.parse(["--screenshot-hand", "left"] + base)?.hand, .left, "anywhere in the arguments")
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-hand", "right"])?.hand, .right)
        for bad in ["", "Left", "LEFT", "l", "leading", "trailing", "both", "--screenshot-probe"] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-hand", bad])?.hand, "hand \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-hand"])?.hand, "no value")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-hand", "left"]), "never active without --screenshot-mode")
    }

    /// The hand changes nothing else: the rest of the config is the one the same arguments gave before 1.4.1, and the
    /// toolbar's values of 1.1 read as they did (ScreenshotModeTests pins them too).
    func testHandLeavesTheOtherArgumentsAlone() throws {
        let arguments = base + ["--screenshot-toolbar", "collapsed-right", "--screenshot-tool", "marker", "--screenshot-probe"]
        var plain = try XCTUnwrap(ScreenshotMode.parse(arguments))
        let left = try XCTUnwrap(ScreenshotMode.parse(arguments + ["--screenshot-hand", "left"]))
        XCTAssertEqual(left.toolbar, .collapsedRight)
        XCTAssertEqual(left.tool, .marker)
        XCTAssertTrue(left.probe)
        XCTAssertEqual(left.page, .week)
        plain.hand = .left
        // `today` is fixed by the month, so the two parses are the same value but for the hand.
        XCTAssertEqual(left, plain)
        let shots: [(String, ScreenshotMode.ToolbarShot)] = [("collapsed", .collapsed), ("collapsed-right", .collapsedRight)]
        for (value, shot) in shots {
            XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-hand", "left", "--screenshot-toolbar", value])?.toolbar, shot)
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-hand", "left", "--screenshot-toolbar", "left"])?.toolbar)
    }

    /// Screenshot mode stores nothing (§4.10): a switch of 「利き手」 there writes neither the hand nor the round button's
    /// corner, and the settings sheet opens with `--screenshot-hand` (the right hand without it), whatever is stored.
    func testScreenshotModeStoresNoHand() throws {
        let suite = "test-hand-shot-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
        }
        for hand in Hand.allCases {
            SettingsScreen.handChanged(to: hand, screenshot: true)
            XCTAssertNil(scratch.object(forKey: AppSettings.handKey), "\(hand): no layout.hand")
            XCTAssertNil(scratch.object(forKey: AppSettings.toolbarEdgeKey), "\(hand): no toolbar.collapsedEdge")
        }
        scratch.set("left", forKey: AppSettings.handKey)
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let left = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-hand", "left"]))
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: plain), .right, "the stored left hand is not read")
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: left), .left)
        scratch.set("right", forKey: AppSettings.handKey)
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: left), .left)
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: nil), .right, "normal use reads the store")
        scratch.set("left", forKey: AppSettings.handKey)
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: nil), .left)
    }
}
