import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.2 (docs/R1_4_2_CONTRACT.md §2.1, §4.7, §6.1, 0f-18, 0f-19): screenshot mode's new arguments. This file holds the memo
// paper's (`--screenshot-memo-paper ruled|dots|plain`, D1a, role S); the pen colours' (`--screenshot-color-panel`,
// `--screenshot-pen-slots`, D1b) join it with their own tests. An unknown value or none is nil (the ruled paper), the other
// arguments read as before, and screenshot mode never reads or writes `paper.memoStyle`: the launch takes the argument whatever
// is stored and writes nothing (mutation MM3).
// D1b (§3.11, 0f-18): `--screenshot-color-panel` is a flag; `--screenshot-pen-slots` six colours or nil; the pen starts with
// the first dot's colour; and screenshot mode never reads or writes `toolbar.penSlots`: its dots live in a scratch store emptied
// at every launch (`ToolbarPalette.penSlotsStore`), where the panel's choices go too (mutation MS2).
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
    // MARK: - The pen colours (D1b)

    private let six = ["#92400e", "#6b7280", "#db2777", "#0284c7", "#166534", "#1e40af"]

    func testParseTheColourArguments() {
        XCTAssertFalse(ScreenshotMode.parse(base)?.colorPanel ?? true, "off without the flag")
        XCTAssertTrue(ScreenshotMode.parse(base + ["--screenshot-color-panel"])?.colorPanel ?? false)
        XCTAssertTrue(ScreenshotMode.parse(["--screenshot-color-panel"] + base)?.colorPanel ?? false, "anywhere")
        XCTAssertNil(ScreenshotMode.parse(base)?.penSlots, "the first six without the argument")
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-pen-slots", six.joined(separator: ",")])?.penSlots, six)
        XCTAssertEqual(ScreenshotMode.parse(base + ["--screenshot-pen-slots", "#92400E,#6B7280,#db2777,#0284c7,#166534,#abc"])?.penSlots,
                       ["#92400e", "#6b7280", "#db2777", "#0284c7", "#166534", "#aabbcc"], "normalized")
        for bad in ["", "#92400e", six.prefix(5).joined(separator: ","), (six + ["#000000"]).joined(separator: ","),
                    (six.prefix(5) + ["red"]).joined(separator: ","), (six.prefix(5) + ["#92400e"]).joined(separator: ","),
                    (six.prefix(5) + [""]).joined(separator: ","), "--screenshot-probe"] {
            XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-pen-slots", bad])?.penSlots, "pen slots \(bad)")
        }
        XCTAssertNil(ScreenshotMode.parse(base + ["--screenshot-pen-slots"])?.penSlots, "no value")
        XCTAssertNil(ScreenshotMode.parse(["--screenshot-color-panel"]), "never active without --screenshot-mode")
    }

    /// The colour arguments change nothing else (every earlier Config is the same value as before: off and nil by default).
    func testTheColourArgumentsLeaveTheOthersAlone() throws {
        let photos: [[String]] = [
            base,
            base + ["--screenshot-palette", "left", "--screenshot-toolbar", "collapsed"],
            base + ["--screenshot-memo-paper", "dots", "--screenshot-probe"],
            ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-sheet", "settings"],
        ]
        for arguments in photos {
            var plain = try XCTUnwrap(ScreenshotMode.parse(arguments))
            XCTAssertFalse(plain.colorPanel)
            XCTAssertNil(plain.penSlots)
            let both = try XCTUnwrap(ScreenshotMode.parse(arguments + ["--screenshot-color-panel", "--screenshot-pen-slots", six.joined(separator: ",")]))
            plain.colorPanel = true
            plain.penSlots = six
            XCTAssertEqual(both, plain, "\(arguments)")
        }
        let made = ScreenshotMode.Config(page: .month, month: YearMonth(year: 2026, month: 10), today: Date(timeIntervalSince1970: 0),
                                         focus: DayKey(year: 2026, month: 10, day: 7), sheet: nil)
        XCTAssertFalse(made.colorPanel)
        XCTAssertNil(made.penSlots)
    }

    /// The pen a screenshot starts with: the default pen, in the first dot's colour with `--screenshot-pen-slots`; the
    /// other tools as before.
    func testThePenStartsWithTheFirstDot() throws {
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        XCTAssertEqual(ScreenshotMode.startTool(plain), .ink(ToolbarPalette.defaultPen))
        let slots = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-pen-slots", six.joined(separator: ",")]))
        XCTAssertEqual(ScreenshotMode.startTool(slots), .ink(InkStyle(tool: .pen, colorHex: "#92400e", width: 3.5)))
        let marker = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-pen-slots", six.joined(separator: ","), "--screenshot-tool", "marker"]))
        XCTAssertEqual(ScreenshotMode.startTool(marker), .ink(InkPresets.defaultMarker))
        XCTAssertEqual(CalendarRootScreen.startState(shot: plain).lastInkTool, .ink(ToolbarPalette.defaultPen), "as before")
    }

    /// Screenshot mode's dots live in a scratch store, emptied at every launch (a previous photo's or UI test's dots never
    /// leak into the next), holding `--screenshot-pen-slots`; the device's `toolbar.penSlots` is never read or written there,
    /// not even by a choice in the panel (MS2). Normal use is the device's store.
    @MainActor
    func testScreenshotModeNeverTouchesTheDevicesDots() throws {
        let deviceName = "test-pen-slots-device-\(UUID())"
        let scratchName = "test-pen-slots-shot-\(UUID())"
        let device = try XCTUnwrap(UserDefaults(suiteName: deviceName))
        defer {
            device.removePersistentDomain(forName: deviceName)
            UserDefaults(suiteName: scratchName)?.removePersistentDomain(forName: scratchName)
        }
        let stored = ToolbarPalette.storedSlots(["#0a7e8c"] + ToolbarPalette.defaultSlots.dropFirst())
        device.set(stored, forKey: ToolbarPalette.penSlotsKey)

        XCTAssertTrue(ToolbarPalette.penSlotsStore(shot: nil, standard: device, suiteName: scratchName) === device, "normal use")

        // A leftover of an earlier launch in the scratch store is emptied.
        UserDefaults(suiteName: scratchName)?.set("#000000,#111111,#222222,#333333,#444444,#555555", forKey: ToolbarPalette.penSlotsKey)
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let store = ToolbarPalette.penSlotsStore(shot: plain, standard: device, suiteName: scratchName)
        XCTAssertFalse(store === device, "screenshot mode: not the device's store")
        XCTAssertNil(store.string(forKey: ToolbarPalette.penSlotsKey), "emptied at the launch")
        XCTAssertEqual(ColorPanelStore.slots(store), ToolbarPalette.defaultSlots, "the first six, whatever the device keeps")

        let given = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-pen-slots", six.joined(separator: ",")]))
        let shotStore = ToolbarPalette.penSlotsStore(shot: given, standard: device, suiteName: scratchName)
        XCTAssertEqual(ColorPanelStore.slots(shotStore), six, "--screenshot-pen-slots")

        // A choice in the panel during a photo or a UI test: the scratch store only.
        _ = ColorPanelStore.apply(ColorPanelLogic.choose("#0a7e8c", slot: 2, slots: six), store: shotStore, defaults: device)
        XCTAssertEqual(ColorPanelStore.slots(shotStore)[2], "#0a7e8c")
        XCTAssertEqual(device.string(forKey: ToolbarPalette.penSlotsKey), stored, "the device's dots untouched")
        XCTAssertEqual(device.string(forKey: ToolbarPalette.penColorKey), "#0a7e8c", "toolbar.penColor is written as before")
    }

    /// What a choice writes in normal use: the dots only when they changed, and the pen's colour; the pen it hands back keeps
    /// the remembered width. (The colours the pen is looked up in are PenSlotsTests'; only the stores are read here, so each
    /// mutation of §6.4 fails its own file.)
    @MainActor
    func testAChoiceWritesTheDotsWhenTheyChange() throws {
        let name = "test-pen-slots-apply-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(6.0, forKey: ToolbarPalette.penWidthKey)
        let first = ToolbarPalette.defaultSlots
        let same = ColorPanelStore.apply(ColorPanelLogic.choose(first[1], slot: 0, slots: first), store: defaults, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: ToolbarPalette.penSlotsKey), "another dot's colour: the dots did not change")
        XCTAssertEqual(defaults.string(forKey: ToolbarPalette.penColorKey), first[1])
        XCTAssertEqual(same.width, 6, "the width kept")
        let brown = ColorPanelStore.apply(ColorPanelLogic.choose("#92400e", slot: 0, slots: first), store: defaults, defaults: defaults)
        XCTAssertEqual(brown.width, 6)
        XCTAssertEqual(brown.tool, .pen)
        XCTAssertEqual(defaults.string(forKey: ToolbarPalette.penSlotsKey), ToolbarPalette.storedSlots(["#92400e"] + first.dropFirst()))
        XCTAssertEqual(defaults.string(forKey: ToolbarPalette.penColorKey), "#92400e")
        _ = ColorPanelStore.apply(ColorPanelLogic.Choice(slots: first, pen: first[0]), store: defaults, defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: ToolbarPalette.penSlotsKey), ToolbarPalette.storedSlots(first), "put back: written")
        XCTAssertEqual(defaults.string(forKey: ToolbarPalette.penColorKey), first[0])
        XCTAssertEqual(ColorPanelStore.slots(defaults), first)
    }
}
