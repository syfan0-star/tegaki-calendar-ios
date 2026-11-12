import Layout
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §3.14, §3.16, §8.1, §10.2 U): 設定 › ページ and the first-time guide of the joined
/// pages. The section sits between 入力 and 同期 with the words of N-1 … N-3; 「前後のページを横につなげる」 is on until
/// the person turns it off, on this device only (`page.span`); the guide's card has the text of N-4 … N-7 for
/// the kind and 「指でも書く」, goes after 8 seconds (`TestSleeper`, no real waiting) or at a touch, comes once per
/// device and kind, and never in screenshot mode or with the setting off; N-8 is the stage-2 notice. The words
/// are ja (the unit tests run with `-testLanguage ja`). `AppSettings.defaults` points at a scratch suite.
@MainActor
final class SettingsPageSectionTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // §8.1, fixed.
    private let n1 = "ページ"
    private let n2 = "前後のページを横につなげる"
    private let n3 = "週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。"
    private let n4 = "前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。"
    private let n5 = "前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。"
    private let n6 = "前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。"
    private let n7 = "前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。"
    private let n8 = "このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。"

    /// What a closure saw (a class, so the closure need not capture a `var`).
    @MainActor
    private final class Seen {
        var kinds: [PageKind?] = []
    }

    private var suiteNames: [String] = []
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = newDefaults()
        AppSettings.defaults = defaults
    }

    override func tearDown() async throws {
        AppSettings.defaults = .standard
        for name in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        suiteNames = []
    }

    /// An empty store of its own (another device's, when a test needs two).
    private func newDefaults() -> UserDefaults {
        let name = "test-\(UUID())"
        suiteNames.append(name)
        return UserDefaults(suiteName: name) ?? .standard
    }

    private func makeModel(_ sleeper: TestSleeper, screenshot: Bool = false, testHost: Bool = false) -> SpanGuideModel {
        SpanGuideModel(screenshot: screenshot, testHost: testHost, sleep: { await sleeper.sleep($0) })
    }

    /// Until `count` sleeps are parked (the card's timer is a task of its own), at most 1,000 turns.
    private func waitForTimers(_ sleeper: TestSleeper, count: Int = 1) async {
        var turns = 0
        while sleeper.waiting < count, turns < 1_000 {
            turns += 1
            await Task.yield()
        }
    }

    /// A few turns of the main actor, for a woken timer to finish.
    private func settle() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }

    // MARK: - 設定 › ページ

    /// The sections of the sheet's `Form` in the order `body` lists them. A `Form`'s rows are cells made lazily
    /// on screen, so a unit test cannot walk them; the order is read where it is written (SettingsScreen.swift):
    /// the lines at the first level of `Form { … }`, without the comments and the arguments of a call.
    private func formSections() throws -> [String] {
        let url = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/SettingsScreen.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let lines = source.components(separatedBy: "\n")
        let open = try XCTUnwrap(lines.firstIndex { $0.trimmingCharacters(in: .whitespaces) == "Form {" }, "body has a Form")
        let indent = lines[open].prefix { $0 == " " }.count
        let close = try XCTUnwrap(lines[(open + 1)...].firstIndex { $0 == String(repeating: " ", count: indent) + "}" },
                                  "the Form's closing brace")
        let level = String(repeating: " ", count: indent + 4)
        return lines[(open + 1)..<close].compactMap { line -> String? in
            guard line.hasPrefix(level), !line.hasPrefix(level + " ") else { return nil }
            let code = line.trimmingCharacters(in: .whitespaces)
            guard !code.hasPrefix("//"), !code.hasPrefix(")") else { return nil }
            return String(code.prefix { $0.isLetter || $0.isNumber || $0 == "_" })
        }
    }

    func testPageSectionSitsBetweenInputAndSync() throws {
        let sections = try formSections()
        // 1.2.3's order with 「ページ」 right after 入力 and right before 同期; nothing else moved.
        XCTAssertEqual(sections, ["calendarSection", "WeekStartSettingsSection", "HolidaySettingsSection", "inputSections",
                                  "pageSection", "syncSection", "dataSection", "purchaseSection", "infoSection"])
        let page = try XCTUnwrap(sections.firstIndex(of: "pageSection"))
        XCTAssertEqual(sections[page - 1], "inputSections")
        XCTAssertEqual(sections[page + 1], "syncSection")
        // N-1 … N-3: the section's title, its one row and the footnote.
        XCTAssertEqual(SettingsScreen.pageSectionTitle, n1)
        XCTAssertEqual(SettingsScreen.pageSpanTitle, n2)
        XCTAssertEqual(SettingsScreen.pageSpanFooter, n3)
        XCTAssertEqual(SettingsScreen.pageSpanIdentifier, "settings.pageSpan")
    }

    func testSpanToggleDefaultsOnPerDevice() {
        XCTAssertEqual(AppSettings.pageSpanKey, "page.span")
        XCTAssertTrue(AppSettings.pageSpan, "on until the person turns it off")
        XCTAssertNil(defaults.object(forKey: "page.span"), "reading the default writes nothing")

        AppSettings.pageSpan = false
        XCTAssertFalse(AppSettings.pageSpan)
        XCTAssertEqual(defaults.object(forKey: "page.span") as? Bool, false, "kept in this device's UserDefaults")
        AppSettings.pageSpan = true
        XCTAssertTrue(AppSettings.pageSpan)
        XCTAssertEqual(defaults.object(forKey: "page.span") as? Bool, true)

        // Per device: another device's store (another suite) is not touched and reads its own default.
        AppSettings.pageSpan = false
        let other = newDefaults()
        AppSettings.defaults = other
        XCTAssertTrue(AppSettings.pageSpan, "another device is still on")
        XCTAssertNil(other.object(forKey: "page.span"))
        AppSettings.defaults = defaults
        XCTAssertFalse(AppSettings.pageSpan, "this device stays off")

        // The switch alone does not make someone an earlier user (1.2's test of the three keys).
        XCTAssertFalse(AppSettings.isExistingUser(defaults))
    }

    // MARK: - The first-time guide

    func testGuideDisappearsAfterEightSeconds() async {
        XCTAssertEqual(SpanGuide.duration, 8)
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        XCTAssertNil(model.card)

        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: false))
        XCTAssertEqual(model.card?.text, n4)
        XCTAssertEqual(model.card?.kind, .week)
        XCTAssertEqual(model.card?.timed, true)
        await waitForTimers(sleeper)
        XCTAssertEqual(sleeper.recorded, [8], "one wait of 8 seconds, through the injected sleep")
        XCTAssertEqual(sleeper.waiting, 1)
        XCTAssertNotNil(model.card, "up while the 8 seconds run")

        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card, "gone after 8 seconds")
        XCTAssertEqual(sleeper.recorded, [8], "no second wait")
    }

    func testGuideTextFollowsTheKindAndTheFingerSetting() {
        XCTAssertEqual(SpanGuide.text(kind: .week, allowFinger: false), n4, "N-4: one finger slides")
        XCTAssertEqual(SpanGuide.text(kind: .week, allowFinger: true), n5, "N-5: a finger writes, two slide")
        XCTAssertEqual(SpanGuide.text(kind: .day, allowFinger: false), n6, "N-6")
        XCTAssertEqual(SpanGuide.text(kind: .day, allowFinger: true), n7, "N-7")
        for finger in [false, true] {
            XCTAssertNil(SpanGuide.text(kind: .month, allowFinger: finger), "month is one page at a time in 1.3")
            XCTAssertNil(SpanGuide.text(kind: .year, allowFinger: finger), "year is one page at a time in 1.3")
        }
        XCTAssertEqual(SpanGuide.joinedKinds, [.week, .day])

        let sleeper = TestSleeper()
        sleeper.autoResume = true
        let model = makeModel(sleeper)
        XCTAssertTrue(model.pageOpened(.day, joined: true, allowFinger: true))
        XCTAssertEqual(model.card?.text, n7, "the card follows 「指でも書く」 as it is when the page opens")
        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: false))
        XCTAssertEqual(model.card?.text, n4)
    }

    func testGuideComesOncePerDevicePerKind() async {
        XCTAssertEqual(AppSettings.spanGuideShownKey(.week), "hint.spanGuide.week")
        XCTAssertEqual(AppSettings.spanGuideShownKey(.day), "hint.spanGuide.day")
        let sleeper = TestSleeper()
        sleeper.autoResume = true
        let model = makeModel(sleeper)

        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: false))
        XCTAssertTrue(AppSettings.spanGuideShown(.week))
        XCTAssertEqual(defaults.object(forKey: "hint.spanGuide.week") as? Bool, true, "recorded on this device")
        XCTAssertFalse(AppSettings.spanGuideShown(.day), "per kind")
        await settle()
        XCTAssertNil(model.card)
        XCTAssertFalse(model.pageOpened(.week, joined: true, allowFinger: true), "never twice for a kind")
        XCTAssertNil(model.card)
        XCTAssertFalse(makeModel(sleeper).pageOpened(.week, joined: true, allowFinger: false), "nor after a new launch")

        XCTAssertTrue(model.pageOpened(.day, joined: true, allowFinger: false), "the day has its own")
        XCTAssertEqual(model.card?.text, n6)
        XCTAssertTrue(AppSettings.spanGuideShown(.day))
        model.dismiss()
        XCTAssertFalse(model.pageOpened(.day, joined: true, allowFinger: false))

        // Another device (another store) shows both once more.
        AppSettings.defaults = newDefaults()
        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: true))
        XCTAssertEqual(model.card?.text, n5)
        XCTAssertTrue(model.pageOpened(.day, joined: true, allowFinger: true))
        XCTAssertEqual(model.card?.text, n7)
        await settle()
        XCTAssertNil(model.card)
        XCTAssertEqual(Set(sleeper.recorded), [8], "every card's wait is 8 seconds")
    }

    func testGuideIsNotShownInScreenshotModeNorWithTheSettingOff() {
        let sleeper = TestSleeper()
        sleeper.autoResume = true

        for model in [makeModel(sleeper, screenshot: true), makeModel(sleeper, testHost: true)] {
            for kind in PageKind.allCases {
                XCTAssertFalse(model.pageOpened(kind, joined: true, allowFinger: false), "\(kind)")
                XCTAssertNil(model.card)
            }
        }
        let model = makeModel(sleeper)
        for kind in PageKind.allCases {
            XCTAssertFalse(model.pageOpened(kind, joined: false, allowFinger: true), "\(kind): the setting off (or stage 2)")
        }
        XCTAssertFalse(model.pageOpened(.month, joined: true, allowFinger: false), "month is not joined in 1.3")
        XCTAssertFalse(model.pageOpened(.year, joined: true, allowFinger: false), "year is not joined in 1.3")
        XCTAssertNil(model.card)
        XCTAssertEqual(sleeper.recorded, [], "no card, no timer")
        for kind in PageKind.allCases {
            XCTAssertFalse(AppSettings.spanGuideShown(kind), "\(kind): nothing recorded")
            XCTAssertNil(defaults.object(forKey: AppSettings.spanGuideShownKey(kind)))
        }
        // Not recorded, so the guide comes once the setting is on.
        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: false))

        // The rule itself.
        XCTAssertTrue(SpanGuide.isDue(kind: .day, joined: true, shown: false, screenshot: false, testHost: false))
        XCTAssertFalse(SpanGuide.isDue(kind: .day, joined: true, shown: true, screenshot: false, testHost: false))
        XCTAssertFalse(SpanGuide.isDue(kind: .day, joined: false, shown: false, screenshot: false, testHost: false))
        XCTAssertFalse(SpanGuide.isDue(kind: .day, joined: true, shown: false, screenshot: true, testHost: false))
        XCTAssertFalse(SpanGuide.isDue(kind: .day, joined: true, shown: false, screenshot: false, testHost: true))
        XCTAssertFalse(SpanGuide.isDue(kind: .month, joined: true, shown: false, screenshot: false, testHost: false))
    }

    func testGuideGoesAtATouch() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        model.dismiss()
        XCTAssertNil(model.card, "nothing to dismiss")

        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: true))
        await waitForTimers(sleeper)
        XCTAssertNotNil(model.card)
        model.dismiss()
        XCTAssertNil(model.card, "gone at the touch, before the 8 seconds")
        // The timer of the dismissed card ends without bringing anything back.
        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card)
        XCTAssertTrue(AppSettings.spanGuideShown(.week), "a touched card counts as shown")
    }

    func testALateTimerLeavesALaterCardAlone() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        XCTAssertTrue(model.pageOpened(.week, joined: true, allowFinger: false))
        await waitForTimers(sleeper)
        model.dismiss()
        XCTAssertTrue(model.pageOpened(.day, joined: true, allowFinger: false))
        await waitForTimers(sleeper, count: 2)
        XCTAssertEqual(sleeper.waiting, 2)

        // `advance` wakes the week's timer first, then (after `settle`) the day's.
        let between = Seen()
        sleeper.settle = { between.kinds.append(model.card?.kind) }
        await sleeper.advance()
        await settle()
        XCTAssertEqual(between.kinds, [.day], "the week's timer left the day's card up")
        XCTAssertNil(model.card, "the day's own 8 seconds took it")
    }

    func testPhotoCardStaysWithoutTheRecord() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper, screenshot: true)
        model.showForPhoto(.day, allowFinger: true)
        XCTAssertEqual(model.card?.text, n7)
        XCTAssertEqual(model.card?.timed, false)
        await settle()
        XCTAssertEqual(sleeper.recorded, [], "no 8 seconds for the photo")
        XCTAssertNotNil(model.card)
        XCTAssertFalse(AppSettings.spanGuideShown(.day), "nothing recorded in screenshot mode")
        model.showForPhoto(.month, allowFinger: false)
        XCTAssertEqual(model.card?.text, n7, "no card for a kind that is not joined")
        model.dismiss()
        XCTAssertNil(model.card)
    }

    func testStageTwoNoticeIsTheContractText() {
        XCTAssertEqual(SpanGuide.stageTwoNotice, n8)
    }
}
