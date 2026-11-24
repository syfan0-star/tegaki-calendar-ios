import XCTest
@testable import TegakiCalendar

/// 1.4.2 (docs/R1_4_2_CONTRACT.md §4.1, §6.1, 0f-19): the memo paper's type and key. The stored text is read as ruled unless it
/// is one of the three names; the key is `paper.memoStyle`; `prepareAtLaunch` takes screenshot mode's argument (never the
/// stored value), the ruled paper on a test host (never the stored value), and the stored value otherwise — the branch no CI
/// launch reaches (screenshot mode and the test host both skip it), so it is tried here with `testHost: false` and a scratch
/// suite (mutation MM4). `set` posts `didChange` only when the pattern changes.
///
/// `AppSettings.defaults` points at a scratch suite for every test, and `MemoPaperStyle.current` is the ruled paper again
/// afterwards (the frozen pixel tests of the paper draw with it).
@MainActor
final class MemoPaperStyleTests: XCTestCase {
    private var suiteName = ""
    private var scratch: UserDefaults!
    private var savedDefaults: UserDefaults = .standard

    override func setUp() async throws {
        suiteName = "test-memo-paper-\(UUID())"
        scratch = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        savedDefaults = AppSettings.defaults
        AppSettings.defaults = scratch
        MemoPaperStyle.current = .ruled
    }

    override func tearDown() async throws {
        scratch?.removePersistentDomain(forName: suiteName)
        AppSettings.defaults = savedDefaults
        // Through `set`, so every paper still alive (the host app's too) is ruled again.
        MemoPaperStyle.set(.ruled)
    }

    private func shot(_ arguments: [String]) throws -> ScreenshotMode.Config {
        try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode"] + arguments))
    }

    /// Counts the notices (a box, so the observer's block changes no captured variable).
    private final class Tally: @unchecked Sendable {
        var count = 0
    }

    /// How many `didChange` notices `body` posts (delivered at once: posted on this thread, no queue).
    private func notices(_ body: () -> Void) -> Int {
        let tally = Tally()
        let token = NotificationCenter.default.addObserver(forName: MemoPaperStyle.didChange, object: nil, queue: nil) { _ in
            tally.count += 1
        }
        body()
        NotificationCenter.default.removeObserver(token)
        return tally.count
    }

    func testTheThreePatternsAndTheKey() {
        XCTAssertEqual(MemoPaperStyle.allCases, [.ruled, .dots, .plain])
        XCTAssertEqual(MemoPaperStyle.allCases.map(\.rawValue), ["ruled", "dots", "plain"])
        XCTAssertEqual(AppSettings.memoPaperKey, "paper.memoStyle")
        XCTAssertNil(scratch.object(forKey: AppSettings.memoPaperKey), "nothing is stored until the person chooses")
    }

    /// `init(stored:)`: the three names; nil, an empty text, another spelling, an unknown name → ruled.
    func testStoredTextIsReadAsRuledUnlessItIsAName() {
        let table: [(String?, MemoPaperStyle)] = [
            (nil, .ruled), ("", .ruled), ("ruled", .ruled), ("dots", .dots), ("plain", .plain),
            ("Dots", .ruled), ("DOTS", .ruled), (" dots", .ruled), ("dot", .ruled), ("grid", .ruled), ("blank", .ruled),
            ("lined", .ruled), ("0", .ruled), ("1", .ruled),
        ]
        for (raw, style) in table {
            XCTAssertEqual(MemoPaperStyle(stored: raw), style, "\(String(describing: raw))")
        }
    }

    /// A value of another type under the key (a number, a list, a flag) is no name either: ruled.
    func testAStoredValueThatIsNotTextIsRuled() {
        for value in [3 as Any, true as Any, ["dots"] as Any, Data([1, 2]) as Any] {
            scratch.set(value, forKey: AppSettings.memoPaperKey)
            XCTAssertEqual(MemoPaperStyle(stored: scratch.string(forKey: AppSettings.memoPaperKey)), .ruled, "\(value)")
            MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false)
            XCTAssertEqual(MemoPaperStyle.current, .ruled, "\(value)")
        }
    }

    /// Outside screenshot mode and off a test host, the stored value (MM4): dots, plain, ruled; broken or missing → ruled.
    func testLaunchReadsTheStoredValue() {
        for (raw, style) in [("dots", MemoPaperStyle.dots), ("plain", .plain), ("ruled", .ruled), ("dots", .dots)] {
            scratch.set(raw, forKey: AppSettings.memoPaperKey)
            MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false)
            XCTAssertEqual(MemoPaperStyle.current, style, raw)
        }
        scratch.set("zzz", forKey: AppSettings.memoPaperKey)
        MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .ruled, "a broken value")
        scratch.set("plain", forKey: AppSettings.memoPaperKey)
        MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .plain)
        scratch.removeObject(forKey: AppSettings.memoPaperKey)
        MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .ruled, "nothing stored")
        XCTAssertNil(scratch.object(forKey: AppSettings.memoPaperKey), "the launch writes nothing (no migration)")
    }

    /// By default it reads `AppSettings.defaults` (here the scratch suite).
    func testLaunchReadsAppSettingsDefaultsByDefault() {
        scratch.set("dots", forKey: AppSettings.memoPaperKey)
        MemoPaperStyle.prepareAtLaunch(shot: nil, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .dots)
    }

    /// On a test host the stored value is not read, so a simulator that kept 「ドット方眼」 cannot change the paper's frozen
    /// pixel tests; inside XCTest the default `testHost` is `SyncEngine.isTestHost`, true.
    func testATestHostIsRuledWhateverIsStored() {
        XCTAssertTrue(SyncEngine.isTestHost)
        for raw in ["dots", "plain"] {
            scratch.set(raw, forKey: AppSettings.memoPaperKey)
            MemoPaperStyle.current = .plain
            MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: true)
            XCTAssertEqual(MemoPaperStyle.current, .ruled, raw)
            MemoPaperStyle.current = .dots
            MemoPaperStyle.prepareAtLaunch(shot: nil, scratch)
            XCTAssertEqual(MemoPaperStyle.current, .ruled, "the default is the test host: \(raw)")
        }
    }

    /// Screenshot mode takes `--screenshot-memo-paper` (ruled without it) and never reads the stored value (MM3), on or off a
    /// test host; it writes nothing.
    func testScreenshotModeTakesItsArgumentOnly() throws {
        scratch.set("dots", forKey: AppSettings.memoPaperKey)
        for testHost in [false, true] {
            MemoPaperStyle.prepareAtLaunch(shot: try shot([]), scratch, testHost: testHost)
            XCTAssertEqual(MemoPaperStyle.current, .ruled, "no argument: ruled, not the stored dots (testHost \(testHost))")
            MemoPaperStyle.prepareAtLaunch(shot: try shot(["--screenshot-memo-paper", "plain"]), scratch, testHost: testHost)
            XCTAssertEqual(MemoPaperStyle.current, .plain)
            MemoPaperStyle.prepareAtLaunch(shot: try shot(["--screenshot-memo-paper", "dots"]), scratch, testHost: testHost)
            XCTAssertEqual(MemoPaperStyle.current, .dots)
            MemoPaperStyle.prepareAtLaunch(shot: try shot(["--screenshot-memo-paper", "grid"]), scratch, testHost: testHost)
            XCTAssertEqual(MemoPaperStyle.current, .ruled, "an unknown value: ruled")
        }
        scratch.set("plain", forKey: AppSettings.memoPaperKey)
        MemoPaperStyle.prepareAtLaunch(shot: try shot(["--screenshot-page", "day"]), scratch, testHost: false)
        XCTAssertEqual(MemoPaperStyle.current, .ruled, "the stored plain is not read in screenshot mode")
        XCTAssertEqual(scratch.string(forKey: AppSettings.memoPaperKey), "plain", "and not written")
    }

    /// `set` changes `current` and tells the papers once; the same pattern again tells nothing.
    func testSetPostsOnlyWhenThePatternChanges() {
        XCTAssertEqual(MemoPaperStyle.current, .ruled)
        XCTAssertEqual(notices { MemoPaperStyle.set(.ruled) }, 0, "the same pattern")
        XCTAssertEqual(notices { MemoPaperStyle.set(.dots) }, 1)
        XCTAssertEqual(MemoPaperStyle.current, .dots)
        XCTAssertEqual(notices { MemoPaperStyle.set(.dots) }, 0)
        XCTAssertEqual(notices { MemoPaperStyle.set(.plain) }, 1)
        XCTAssertEqual(MemoPaperStyle.current, .plain)
        XCTAssertEqual(notices { MemoPaperStyle.set(.ruled) }, 1)
        XCTAssertEqual(MemoPaperStyle.current, .ruled)
        XCTAssertNil(scratch.object(forKey: AppSettings.memoPaperKey), "set stores nothing (the settings store first)")
    }

    /// The launch tells the papers when it changes the pattern (a paper made before it follows), and nothing when it does not.
    func testLaunchTellsThePapersOfAChange() {
        scratch.set("dots", forKey: AppSettings.memoPaperKey)
        XCTAssertEqual(notices { MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false) }, 1)
        XCTAssertEqual(notices { MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: false) }, 0)
        XCTAssertEqual(notices { MemoPaperStyle.prepareAtLaunch(shot: nil, scratch, testHost: true) }, 1, "back to ruled")
    }
}
