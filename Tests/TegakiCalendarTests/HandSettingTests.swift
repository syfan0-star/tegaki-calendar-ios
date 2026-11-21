import XCTest
@testable import TegakiCalendar

// 1.4.1 (docs/R1_4_1_CONTRACT.md §2.1, §4.1, §4.2, §4.10, §6.1, 0e-12, 0e-13, 0e-21): 設定 › 入力 「利き手」. The stored
// value is a String, "right" or "left", per device (`layout.hand`); nothing, an unknown value or a value that is not a string
// reads as the right hand, and reading writes nothing (the shape of `toolbar.collapsedEdge`). The hand's corner of the
// folded toolbar's round button (`Hand.dockEdge`), and screenshot mode's hand, which never reads the store. The tests point
// `AppSettings.defaults` at a scratch suite.
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
