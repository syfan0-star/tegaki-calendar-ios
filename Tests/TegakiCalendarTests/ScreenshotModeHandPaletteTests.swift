import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.1, §4.10, §6.1, 0e-21): screenshot mode's new arguments. This file holds the hand's
// (`--screenshot-hand left|right`, track H); the toolbar's edges (`--screenshot-palette`, `--screenshot-palette-drag`, track
// S/T, D1b) join it with their own tests. An unknown value or none is nil, the other arguments read as before (the
// `--screenshot-toolbar` values of 1.1 included), and screenshot mode stores nothing: neither the hand (`layout.hand`) nor the
// round button's corner (`toolbar.collapsedEdge`) that switching the hand writes in normal use.
// D1b (§4.7, §4.9–§4.11, 0e-18, 0e-20–0e-22): the toolbar's edge in screenshot mode starts at `--screenshot-palette` (the
// bottom without it) whatever is stored, and a drop there moves the bar without writing `toolbar.paletteEdge` (MS2); in normal
// use a drop writes the edge and, on a side, the round button's corner. With them the screen's pure pieces of the edges: the
// log line `toolbar: palette=`, the UI tests' `palette.state`, VoiceOver's actions on the grip and the outlines of a drag.
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

    // MARK: - The toolbar's edges (D1b)

    func testParsePalette() {
        XCTAssertNil(ScreenshotMode.parse(base)?.palette, "the bottom without the argument")
        XCTAssertNil(ScreenshotMode.parse(base)?.paletteDrag, "no drag without the argument")
        let edges: [(String, PaletteEdge)] = [("top", .top), ("left", .left), ("right", .right), ("bottom", .bottom)]
        for (value, edge) in edges {
            XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-palette", value])?.palette, edge, value)
            XCTAssertEqual(ScreenshotMode.parse(["--screenshot-palette", value] + base)?.palette, edge, "\(value) anywhere in the arguments")
            XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-palette-drag", value])?.paletteDrag, edge, "drag \(value)")
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-palette-drag", value])?.palette, "a drag alone keeps the bottom")
        }
        for bad in ["", "Top", "LEFT", "middle", "leading", "trailing", "collapsed", "--screenshot-probe"] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-palette", bad])?.palette, "palette \(bad)")
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-palette-drag", bad])?.paletteDrag, "drag \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-palette"])?.palette, "no value")
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-palette-drag"])?.paletteDrag, "no value")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-palette", "left"]), "never active without --screenshot-mode")
    }

    /// The edges change nothing else: the config is the one the same arguments gave before, and `--screenshot-toolbar` (1.1's
    /// values, pinned by ScreenshotModeTests) and `--screenshot-hand` read as they did beside them.
    func testPaletteLeavesTheOtherArgumentsAlone() throws {
        let arguments = base + ["--screenshot-toolbar", "collapsed-right", "--screenshot-tool", "marker", "--screenshot-hand", "left"]
        var plain = try XCTUnwrap(ScreenshotMode.parse(arguments))
        let moved = try XCTUnwrap(ScreenshotMode.parse(arguments + ["--screenshot-palette", "left", "--screenshot-palette-drag", "top"]))
        XCTAssertEqual(moved.toolbar, .collapsedRight)
        XCTAssertEqual(moved.tool, .marker)
        XCTAssertEqual(moved.hand, .left)
        plain.palette = .left
        plain.paletteDrag = .top
        XCTAssertEqual(moved, plain)
        let shots: [(String, ScreenshotMode.ToolbarShot)] = [("collapsed", .collapsed), ("collapsed-right", .collapsedRight)]
        for (value, shot) in shots {
            XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-palette", "right", "--screenshot-toolbar", value])?.toolbar, shot)
        }
        for value in ["right", "left", "top", "expanded"] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-toolbar", value])?.toolbar, "--screenshot-toolbar \(value) is not an edge")
        }
    }

    /// §4.10: the edge the screen keeps. In screenshot mode `--screenshot-palette`, the bottom without it, whatever the store
    /// says (the screen's `@State` starts with it); in normal use the store (`PaletteEdge(stored:)`).
    func testScreenshotModeNeverReadsTheStoredEdge() throws {
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let left = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-palette", "left"]))
        let dragOnly = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-palette-drag", "right"]))
        for stored in [nil, "left", "right", "top", "bottom", "other"] as [String?] {
            XCTAssertEqual(ScreenshotMode.paletteEdge(plain, stored: stored), .bottom, "\(String(describing: stored))")
            XCTAssertEqual(ScreenshotMode.paletteEdge(left, stored: stored), .left, "\(String(describing: stored))")
            XCTAssertEqual(ScreenshotMode.paletteEdge(dragOnly, stored: stored), .bottom, "\(String(describing: stored))")
        }
        XCTAssertEqual(ScreenshotMode.paletteEdge(nil, stored: nil), .bottom)
        XCTAssertEqual(ScreenshotMode.paletteEdge(nil, stored: "right"), .right)
        XCTAssertEqual(ScreenshotMode.paletteEdge(nil, stored: "Right"), .bottom)
    }

    /// §4.7, §4.9, §4.10 (MS2): a drop (or VoiceOver's 「…へ移す」) in screenshot mode moves the bar — the answer is the edge the
    /// screen keeps in its `@State`, with a side's corner for the round button — and writes neither `toolbar.paletteEdge` nor
    /// `toolbar.collapsedEdge`. In normal use the same drop writes the edge (only when it is not the stored one) and, on a side,
    /// the corner; the top and the bottom leave the corner. Only the open bar keeps a place (`storesPlacement`).
    func testADropInScreenshotModeMovesTheBarAndWritesNothing() throws {
        let suite = "test-palette-shot-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
        }
        let corners: [PaletteEdge: ToolbarEdge?] = [.bottom: nil, .top: nil, .left: .leading, .right: .trailing]
        for edge in PaletteEdge.allCases {
            let drop = CalendarRootScreen.paletteDropped(on: edge, mode: .expanded, stored: .bottom, screenshot: true)
            XCTAssertEqual(drop, CalendarRootScreen.PaletteDrop(edge: edge, dock: corners[edge] ?? nil), "screenshot mode: \(edge)")
            XCTAssertNil(scratch.object(forKey: AppSettings.paletteEdgeKey), "\(edge): no toolbar.paletteEdge in screenshot mode")
            XCTAssertNil(scratch.object(forKey: AppSettings.toolbarEdgeKey), "\(edge): no toolbar.collapsedEdge in screenshot mode")
        }
        for mode in [ToolbarMode.collapsed, .peek] {
            for screenshot in [true, false] {
                XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .left, mode: mode, stored: .bottom, screenshot: screenshot),
                               CalendarRootScreen.PaletteDrop(edge: nil, dock: nil), "\(mode): nothing is kept")
            }
        }
        XCTAssertNil(scratch.object(forKey: AppSettings.paletteEdgeKey), "nothing kept, nothing written")

        // Normal use: the same drops write.
        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .left, mode: .expanded, stored: .bottom, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: .left, dock: .leading))
        XCTAssertEqual(scratch.string(forKey: "toolbar.paletteEdge"), "left")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "leading")
        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .right, mode: .expanded, stored: .left, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: .right, dock: .trailing))
        XCTAssertEqual(scratch.string(forKey: "toolbar.paletteEdge"), "right")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "trailing")
        XCTAssertEqual(CalendarRootScreen.paletteDropped(on: .top, mode: .expanded, stored: .right, screenshot: false),
                       CalendarRootScreen.PaletteDrop(edge: .top, dock: nil))
        XCTAssertEqual(scratch.string(forKey: "toolbar.paletteEdge"), "top")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "trailing", "the top leaves the corner")
        XCTAssertEqual(AppSettings.paletteEdge, .top)
        // A drop on the stored edge writes nothing new (its value is already there).
        scratch.removeObject(forKey: AppSettings.paletteEdgeKey)
        _ = CalendarRootScreen.paletteDropped(on: .bottom, mode: .expanded, stored: .bottom, screenshot: false)
        XCTAssertNil(scratch.object(forKey: AppSettings.paletteEdgeKey), "the stored edge again: not written")
    }

    /// §4.10, §7.2: the log line beside 1.4's `toolbar: paperArea=` (whose form CalendarRootScreenTests pins), and the UI tests'
    /// `palette.state` (two decimals for the area, as the log lines).
    func testPaletteLogLineAndState() {
        XCTAssertEqual(CalendarRootScreen.paletteLogLine(.left, allowed: [.bottom, .top, .left, .right]),
                       "toolbar: palette=left allowed=bottom,top,left,right")
        XCTAssertEqual(CalendarRootScreen.paletteLogLine(.bottom, allowed: [.bottom]), "toolbar: palette=bottom allowed=bottom")
        XCTAssertEqual(CalendarRootScreen.paletteStateLabel(edge: .bottom, stored: .left, allowed: [.bottom, .top], grip: true, dragging: false,
                                                            areaChanges: 3, area: CGSize(width: 958, height: 1245.333)),
                       "edge=bottom;stored=left;allowed=bottom,top;grip=on;drag=off;areas=3;area=958.00x1245.33")
        XCTAssertEqual(CalendarRootScreen.paletteGripIdentifier, "toolbar.grip")
        XCTAssertEqual(CalendarRootScreen.paletteStateIdentifier, "palette.state")
    }

    /// §4.11 (0e-22): the grip's VoiceOver actions are every allowed edge but the one the bar is on, in `allowedEdges`' order,
    /// with T's names (§8.1); none where the bottom is the only edge (no grip there either).
    func testVoiceOverMovesToEveryOtherAllowedEdge() {
        let four: [PaletteEdge] = [.bottom, .top, .left, .right]
        XCTAssertEqual(CalendarRootScreen.paletteMoves(current: .bottom, allowed: four), [.top, .left, .right])
        XCTAssertEqual(CalendarRootScreen.paletteMoves(current: .left, allowed: four), [.bottom, .top, .right])
        XCTAssertEqual(CalendarRootScreen.paletteMoves(current: .top, allowed: [.bottom, .top]), [.bottom])
        XCTAssertEqual(CalendarRootScreen.paletteMoves(current: .bottom, allowed: [.bottom]), [])
        XCTAssertEqual(CalendarRootScreen.paletteMoveTitle(.top), "上へ移す")
        XCTAssertEqual(CalendarRootScreen.paletteMoveTitle(.bottom), "下へ移す")
        XCTAssertEqual(CalendarRootScreen.paletteMoveTitle(.left), "左へ移す")
        XCTAssertEqual(CalendarRootScreen.paletteMoveTitle(.right), "右へ移す")
    }

    /// §4.7: the outlines of a drag lie where the bar would: the bottom is 1.4's bar (12 pt from the sides, 6 above the bottom),
    /// the top 6 pt under the slots' top, a side 6 pt from its edge and 60 pt wide; only the allowed edges get one.
    func testTheOutlinesOfADrag() {
        let size = CGSize(width: 1032, height: 1332)
        let four = CalendarRootScreen.paletteSlotFrames(size: size, bodyTop: 100, allowed: [.bottom, .top, .left, .right])
        XCTAssertEqual(four[.bottom], CGRect(x: 12, y: 1266, width: 1008, height: 60))
        XCTAssertEqual(four[.top], CGRect(x: 12, y: 106, width: 1008, height: 60))
        XCTAssertEqual(four[.left], CGRect(x: 6, y: 106, width: 60, height: 1220))
        XCTAssertEqual(four[.right], CGRect(x: 966, y: 106, width: 60, height: 1220))
        let two = CalendarRootScreen.paletteSlotFrames(size: size, bodyTop: 100, allowed: [.bottom, .top])
        XCTAssertEqual(Set(two.keys), [.bottom, .top])
        XCTAssertEqual(CalendarRootScreen.paletteSlotFrames(size: size, bodyTop: 100, allowed: [.bottom]).count, 1)
    }
}
