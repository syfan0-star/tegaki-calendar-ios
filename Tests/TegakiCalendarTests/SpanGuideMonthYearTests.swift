import Layout
import XCTest
@testable import TegakiCalendar

// 1.4.3 (docs/R1_4_3_CONTRACT.md §7.3, §13.1, §11.2 row S, 0g-33): the first-time guide's card of the joined month. Its two
// texts (「指でも書く」 off: one finger slides; on: two fingers) say that the memo band below crosses the boundary (a month's
// grid does not run on into the next table); they are in all ten languages' tables (the nine are provisional until D2). The
// card is due as the week's and the day's are — the setting on, shown joined, not seen yet, neither screenshot mode nor the
// test host — and comes once per device; a month fallen back to one page (stage 2) has none. The year's cards come with D1y:
// its expectations are read from `SpanKinds.joined.contains(.year)` (§11.2). The words are ja (the unit tests run with
// `-testLanguage ja`, as SettingsPageSectionTests reads them).

@MainActor
final class SpanGuideMonthYearTests: XCTestCase {
    // §13.1, fixed.
    private let monthOne = "前後の月が横につながりました。指で横にすべらせると、となりの月が出てきます。下のメモ欄は、月の境目をまたいで、そのまま書けます。"
    private let monthTwo = "前後の月が横につながりました。2 本指で横にすべらせると、となりの月が出てきます。下のメモ欄は、月の境目をまたいで、そのまま書けます。"
    private let keys = ["span.guide.month.oneFinger", "span.guide.month.twoFingers"]

    private var suiteNames: [String] = []

    override func setUp() async throws {
        AppSettings.defaults = newDefaults()
    }

    override func tearDown() async throws {
        AppSettings.defaults = .standard
        for name in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        suiteNames = []
    }

    private func newDefaults() -> UserDefaults {
        let name = "SpanGuideMonthYearTests-\(UUID())"
        suiteNames.append(name)
        return UserDefaults(suiteName: name) ?? .standard
    }

    private func makeModel(_ sleeper: TestSleeper, screenshot: Bool = false, testHost: Bool = false) -> SpanGuideModel {
        SpanGuideModel(screenshot: screenshot, testHost: testHost, sleep: { await sleeper.sleep($0) })
    }

    private func settle() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }

    /// §13.1: the month's two texts are in the ja table with the contract's words (「2 本指」 with its space), and every one of
    /// the ten languages has a text of its own for each, not the key and not the Japanese (the nine languages' provisional
    /// texts, D2 writes them anew); `SpanGuide.text` gives them by 「指でも書く」.
    func testTheMonthsWordsAreInEveryLanguage() {
        XCTAssertEqual(SpanGuide.text(kind: .month, allowFinger: false), monthOne)
        XCTAssertEqual(SpanGuide.text(kind: .month, allowFinger: true), monthTwo)
        XCTAssertEqual(L.value(keys[0], in: .ja), monthOne)
        XCTAssertEqual(L.value(keys[1], in: .ja), monthTwo)
        XCTAssertEqual(UILanguage.allCases.count, 10)
        for language in UILanguage.allCases {
            var texts: [String] = []
            for key in keys {
                let value = L.value(key, in: language)
                XCTAssertNotNil(value, "\(language.rawValue): \(key)")
                guard let value else { continue }
                XCTAssertFalse(value.isEmpty, "\(language.rawValue): \(key)")
                XCTAssertNotEqual(value, key, "\(language.rawValue): \(key)")
                if language != .ja {
                    XCTAssertNotEqual(value, L.value(key, in: .ja), "\(language.rawValue): \(key) is not the Japanese")
                }
                texts.append(value)
            }
            XCTAssertEqual(Set(texts).count, 2, "\(language.rawValue): one finger and two fingers differ")
        }
        for finger in [false, true] {
            XCTAssertEqual(SpanGuide.text(kind: .year, allowFinger: finger) != nil, SpanKinds.joined.contains(.year), "the year")
        }
    }

    /// §7.3: the month's card is due on the joined month — the setting on, shown joined, not seen yet, neither screenshot mode
    /// nor the test host — with the text of 「指でも書く」 as it is; it stays its 8 seconds and is then recorded for the month
    /// alone, once per device ("hint.spanGuide.month"). Screenshot mode's photo card (`showForPhoto`, `--screenshot-span-guide`)
    /// is the month's too, untimed and unrecorded.
    func testTheMonthsGuideIsDue() async throws {
        XCTAssertTrue(SpanGuide.joinedKinds.contains(.month))
        XCTAssertEqual(SpanGuide.joinedKinds, SpanKinds.ordered)
        XCTAssertTrue(SpanGuide.isDue(kind: .month, setting: true, joined: true, shown: false, screenshot: false, testHost: false))
        XCTAssertEqual(SpanGuide.isDue(kind: .year, setting: true, joined: true, shown: false, screenshot: false, testHost: false),
                       SpanKinds.joined.contains(.year), "the year")

        let sleeper = TestSleeper()
        sleeper.autoResume = true
        let model = makeModel(sleeper)
        XCTAssertTrue(model.showIfDue(.month, joined: true, allowFinger: true))
        XCTAssertEqual(model.card?.kind, .month)
        XCTAssertEqual(model.card?.text, monthTwo, "「指でも書く」 on: two fingers")
        XCTAssertEqual(model.card?.timed, true)
        XCTAssertFalse(AppSettings.spanGuideShown(.month), "not seen yet")
        await settle()
        XCTAssertNil(model.card, "gone after its 8 seconds")
        XCTAssertEqual(sleeper.recorded, [SpanGuide.duration])
        XCTAssertTrue(AppSettings.spanGuideShown(.month))
        XCTAssertEqual(AppSettings.spanGuideShownKey(.month), "hint.spanGuide.month")
        XCTAssertEqual(AppSettings.defaults.object(forKey: "hint.spanGuide.month") as? Bool, true, "recorded on this device")
        XCTAssertFalse(AppSettings.spanGuideShown(.week), "per kind")
        XCTAssertFalse(model.showIfDue(.month, joined: true, allowFinger: false), "never twice")
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false), "the week has its own")

        // Another device: one finger with 「指でも書く」 off.
        AppSettings.defaults = newDefaults()
        let otherSleeper = TestSleeper()
        otherSleeper.autoResume = true
        let other = makeModel(otherSleeper)
        XCTAssertTrue(other.showIfDue(.month, joined: true, allowFinger: false))
        XCTAssertEqual(other.card?.text, monthOne)
        other.close()
        XCTAssertTrue(AppSettings.spanGuideShown(.month), "closed at a touch: seen")

        // The photo's card.
        let photo = makeModel(TestSleeper(), screenshot: true)
        photo.showForPhoto(.month, allowFinger: false)
        XCTAssertEqual(photo.card?.text, monthOne)
        XCTAssertEqual(photo.card?.timed, false)
        let shot = try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month",
                                                       "--screenshot-span-guide", "two"]))
        XCTAssertEqual(ScreenPaths.photoGuide(shot, kind: .month, allowFinger: false), .card(allowFinger: true))
    }

    /// §3.2, §7.3: no card for the month while it is not shown joined — stage 2 sent it back to one page (`joined` false), the
    /// setting off, already seen, screenshot mode, the test host — and nothing is recorded then.
    func testNoCardForAMonthNotShownJoined() {
        XCTAssertFalse(SpanGuide.isDue(kind: .month, setting: true, joined: false, shown: false, screenshot: false, testHost: false), "stage 2")
        XCTAssertFalse(SpanGuide.isDue(kind: .month, setting: false, joined: true, shown: false, screenshot: false, testHost: false), "off")
        XCTAssertFalse(SpanGuide.isDue(kind: .month, setting: true, joined: true, shown: true, screenshot: false, testHost: false), "seen")
        XCTAssertFalse(SpanGuide.isDue(kind: .month, setting: true, joined: true, shown: false, screenshot: true, testHost: false), "screenshot mode")
        XCTAssertFalse(SpanGuide.isDue(kind: .month, setting: true, joined: true, shown: false, screenshot: false, testHost: true), "the test host")

        let sleeper = TestSleeper()
        sleeper.autoResume = true
        let model = makeModel(sleeper)
        XCTAssertFalse(model.showIfDue(.month, joined: false, allowFinger: false), "fallen back to one page (stage 2)")
        AppSettings.pageSpan = false
        XCTAssertFalse(model.showIfDue(.month, joined: true, allowFinger: true), "the setting off")
        AppSettings.pageSpan = true
        for host in [makeModel(sleeper, screenshot: true), makeModel(sleeper, testHost: true)] {
            XCTAssertFalse(host.showIfDue(.month, joined: true, allowFinger: false))
            XCTAssertNil(host.card)
        }
        XCTAssertNil(model.card)
        XCTAssertEqual(sleeper.recorded, [], "no card, no timer")
        XCTAssertFalse(AppSettings.spanGuideShown(.month), "nothing recorded")
        XCTAssertTrue(model.showIfDue(.month, joined: true, allowFinger: false), "so it comes once it is shown joined")
    }
}
