import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.1, §4.2, §4.10, §6.1, 0e-12, 0e-13, 0e-21): 設定 › 入力 「利き手」. The stored
// value is a String, "right" or "left", per device (`layout.hand`); nothing, an unknown value or a value that is not a string
// reads as the right hand, and reading writes nothing (the shape of `toolbar.collapsedEdge`). The hand's corner of the
// folded toolbar's round button (`Hand.dockEdge`), and screenshot mode's hand, which never reads the store. D1b (§4.10, 0e-21)
// adds the toolbar's edge (`toolbar.paletteEdge`, `AppSettings.paletteEdge`), the bottom for nothing or anything unknown. The
// tests point `AppSettings.defaults` at a scratch suite.
final class HandSettingTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults { AppSettings.defaults }

    override func setUp() {
        super.setUp()
        suiteName = "test-hand-\(UUID())"
        AppSettings.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() {
        AppSettings.defaults.removePersistentDomain(forName: suiteName)
        AppSettings.defaults = .standard
        super.tearDown()
    }

    /// `Hand(stored:)`: "right" and "left" are themselves; nil and anything else is the right hand.
    func testStoredValues() {
        XCTAssertEqual(Hand.allCases, [.right, .left])
        XCTAssertEqual(Hand.right.rawValue, "right")
        XCTAssertEqual(Hand.left.rawValue, "left")
        XCTAssertEqual(Hand(stored: nil), .right)
        XCTAssertEqual(Hand(stored: "right"), .right)
        XCTAssertEqual(Hand(stored: "left"), .left)
        for unknown in ["", "Left", "LEFT", " left", "leading", "trailing", "both", "1"] {
            XCTAssertEqual(Hand(stored: unknown), .right, "\(unknown) → right")
        }
    }

    /// `AppSettings.hand`: the right hand until written, written as its raw value (as `@AppStorage` reads it), and
    /// anything else read back as the right hand.
    func testAccessor() {
        XCTAssertEqual(AppSettings.handKey, "layout.hand")
        XCTAssertNil(defaults.object(forKey: "layout.hand"))
        XCTAssertEqual(AppSettings.hand, .right)
        XCTAssertNil(defaults.object(forKey: "layout.hand"), "reading the default writes nothing")

        AppSettings.hand = .left
        XCTAssertEqual(AppSettings.hand, .left)
        XCTAssertEqual(defaults.string(forKey: "layout.hand"), "left")
        AppSettings.hand = .right
        XCTAssertEqual(defaults.string(forKey: "layout.hand"), "right")
        defaults.set("left", forKey: "layout.hand")
        XCTAssertEqual(AppSettings.hand, .left, "as `@AppStorage` writes it")
        for unknown in ["middle", "", "LEFT"] {
            defaults.set(unknown, forKey: "layout.hand")
            XCTAssertEqual(AppSettings.hand, .right, "\(unknown) → right")
        }
        defaults.set(3, forKey: "layout.hand")
        XCTAssertEqual(AppSettings.hand, .right, "not a string → right")
        defaults.set(true, forKey: "layout.hand")
        XCTAssertEqual(AppSettings.hand, .right, "not a string → right")
        defaults.set(["left"], forKey: "layout.hand")
        XCTAssertEqual(AppSettings.hand, .right, "not a string → right")

        // The hand alone does not make someone an earlier user (1.2's test of the three keys).
        AppSettings.hand = .left
        XCTAssertFalse(AppSettings.isExistingUser(defaults))
    }

    /// The corner the hand puts the folded toolbar's round button in once (§4.1, 0e-13): the right hand's is 1.1's default,
    /// the bottom left; the left hand's the bottom right.
    func testDockEdge() {
        XCTAssertEqual(Hand.right.dockEdge, .leading)
        XCTAssertEqual(Hand.left.dockEdge, .trailing)
        XCTAssertEqual(Hand.right.dockEdge, ToolbarEdge(stored: nil), "the right hand's corner is the default corner")
    }

    /// 1.4.1 D1b (§4.10, §6.1, 0e-21): the toolbar's edge, the other per-device key of 1.4.1, in the same shape: the bottom
    /// until written (reading writes nothing), its raw value, the bottom for anything else; it is not one of an earlier user's
    /// keys and leaves the hand alone.
    func testPaletteEdgeAccessor() {
        XCTAssertEqual(AppSettings.paletteEdgeKey, "toolbar.paletteEdge")
        XCTAssertEqual(AppSettings.paletteEdge, .bottom)
        XCTAssertNil(defaults.object(forKey: "toolbar.paletteEdge"), "reading the default writes nothing")
        AppSettings.paletteEdge = .right
        XCTAssertEqual(defaults.string(forKey: "toolbar.paletteEdge"), "right")
        XCTAssertEqual(AppSettings.paletteEdge, .right)
        for unknown in ["", "Right", "trailing", "1"] {
            defaults.set(unknown, forKey: "toolbar.paletteEdge")
            XCTAssertEqual(AppSettings.paletteEdge, .bottom, "\(unknown) → bottom")
        }
        defaults.set(["left"], forKey: "toolbar.paletteEdge")
        XCTAssertEqual(AppSettings.paletteEdge, .bottom, "not a string → bottom")
        XCTAssertFalse(AppSettings.isExistingUser(defaults), "the edge alone does not make an earlier user")
        XCTAssertNil(defaults.object(forKey: "layout.hand"), "the edge leaves the hand alone")
        XCTAssertEqual(AppSettings.hand, .right)
    }

    /// The header's hand (`ScreenshotMode.hand`, which `CalendarRootScreen` reads): the stored one in normal use; in
    /// screenshot mode `--screenshot-hand`, the right hand without it, whatever is stored (§4.10).
    func testScreenshotModeNeverReadsTheStoredHand() throws {
        XCTAssertEqual(ScreenshotMode.hand(nil, stored: nil), .right)
        XCTAssertEqual(ScreenshotMode.hand(nil, stored: "left"), .left)
        XCTAssertEqual(ScreenshotMode.hand(nil, stored: "other"), .right)
        let base = ["--screenshot-mode", "--screenshot-month", "2026-10"]
        let plain = try XCTUnwrap(ScreenshotMode.parse(base))
        let left = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-hand", "left"]))
        let right = try XCTUnwrap(ScreenshotMode.parse(base + ["--screenshot-hand", "right"]))
        for stored in [nil, "left", "right"] as [String?] {
            XCTAssertEqual(ScreenshotMode.hand(plain, stored: stored), .right, "\(String(describing: stored))")
            XCTAssertEqual(ScreenshotMode.hand(left, stored: stored), .left, "\(String(describing: stored))")
            XCTAssertEqual(ScreenshotMode.hand(right, stored: stored), .right, "\(String(describing: stored))")
        }
    }
}
