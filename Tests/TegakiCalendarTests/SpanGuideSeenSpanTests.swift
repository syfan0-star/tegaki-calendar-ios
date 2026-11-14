import Layout
import XCTest
@testable import TegakiCalendar

/// 1.3 (docs/M7C_CONTRACT.md §3.14; docs/M7C.md, the lead's decision 9 of wave C1, the rest of review J2): the first-time
/// guide's card is recorded as shown for this device and kind only once the person saw it — it stayed its 8 seconds, or
/// they closed it with a touch (on the card, or the pen, a tap or a pinch on the paper: `SpanGuideModel.close`). A card
/// that a sheet or a question took away (`dismiss`: any sheet of `sheetIsUp`, 1.2.2's age range sheet among them, the
/// account question, the screen leaving the joined page) is not recorded and comes again at the next calm moment. Once
/// seen it never comes again for that kind; never in screenshot mode nor with the setting off. The 8 seconds go through
/// `TestSleeper` (no real waiting); `AppSettings.defaults` points at a scratch suite.
@MainActor
final class SpanGuideSeenSpanTests: XCTestCase {
    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// §8.1 N-4 and N-6 (ja: the unit tests run with `-testLanguage ja`).
    private let n4 = "前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。"
    private let n6 = "前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。"

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

    private func newDefaults() -> UserDefaults {
        let name = "test-\(UUID())"
        suiteNames.append(name)
        return UserDefaults(suiteName: name) ?? .standard
    }

    private func makeModel(_ sleeper: TestSleeper, screenshot: Bool = false) -> SpanGuideModel {
        SpanGuideModel(screenshot: screenshot, testHost: false, sleep: { await sleeper.sleep($0) })
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

    /// What this device holds for `kind` (nil: nothing written).
    private func stored(_ kind: PageKind) -> Bool? {
        defaults.object(forKey: AppSettings.spanGuideShownKey(kind)) as? Bool
    }

    // MARK: - The model

    /// The J2 residual: the card comes up, then a sheet comes over it (1.2.2's age range sheet is one of `sheetIsUp`'s, so the
    /// screen's `sheetsChanged` calls `dismiss`): it goes unseen and is not recorded, its old timer brings nothing back, and
    /// once nothing is up (`ScreenPaths.guideMayShow`) it comes again with 8 seconds of its own; seen then, never again.
    func testACardASheetTookAwayIsNotRecordedAndComesAgain() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)

        XCTAssertTrue(ScreenPaths.guideMayShow(sheetIsUp: false, firstPaywallPending: false, accountQuestion: false,
                                               accountChangePending: false))
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false))
        XCTAssertEqual(model.card?.text, n4)
        await waitForTimers(sleeper)
        XCTAssertNil(stored(.week), "up, not seen yet: nothing written")

        // The age range sheet (or any sheet) comes up over it.
        XCTAssertFalse(ScreenPaths.guideMayShow(sheetIsUp: true, firstPaywallPending: false, accountQuestion: false,
                                                accountChangePending: false))
        model.dismiss()
        XCTAssertNil(model.card)
        XCTAssertFalse(AppSettings.spanGuideShown(.week), "taken away by the sheet: not seen")
        XCTAssertNil(stored(.week))
        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card, "the timer of the card taken away brings nothing back")
        XCTAssertNil(stored(.week), "nor records it")

        // The sheet is gone: the next calm moment shows it again, with 8 seconds of its own.
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false), "it comes again")
        XCTAssertEqual(model.card?.text, n4)
        await waitForTimers(sleeper)
        XCTAssertEqual(sleeper.recorded, [8, 8])
        XCTAssertNil(stored(.week))
        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card)
        XCTAssertEqual(stored(.week), true, "stayed its 8 seconds: seen, recorded")
        XCTAssertFalse(model.showIfDue(.week, joined: true, allowFinger: false), "once seen, never again")
        XCTAssertFalse(makeModel(sleeper).showIfDue(.week, joined: true, allowFinger: true), "nor after a new launch")
        XCTAssertNil(stored(.day), "per kind")
    }

    /// The account question takes the card away the same way (`onChange(of: showAccountChange)` calls `dismiss`), and a
    /// new launch before any calm moment still owes it.
    func testACardTheAccountQuestionTookAwayIsStillDueAfterANewLaunch() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        XCTAssertTrue(model.showIfDue(.day, joined: true, allowFinger: false))
        XCTAssertEqual(model.card?.text, n6)
        XCTAssertFalse(ScreenPaths.guideMayShow(sheetIsUp: false, firstPaywallPending: false, accountQuestion: true,
                                                accountChangePending: false))
        model.dismiss()
        XCTAssertNil(stored(.day))

        let next = makeModel(sleeper)
        XCTAssertTrue(next.showIfDue(.day, joined: true, allowFinger: false), "not seen: due on the next launch too")
        XCTAssertEqual(next.card?.text, n6)
        await waitForTimers(sleeper, count: 2)
        await sleeper.advance()
        await settle()
        XCTAssertEqual(stored(.day), true, "seen on the next launch")
    }

    /// The card that stayed its full 8 seconds is the one recorded; while it is up nothing is written.
    func testTheFullEightSecondsRecordTheCard() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        XCTAssertTrue(model.showIfDue(.day, joined: true, allowFinger: false))
        await waitForTimers(sleeper)
        XCTAssertEqual(sleeper.recorded, [SpanGuide.duration])
        XCTAssertNotNil(model.card)
        XCTAssertNil(stored(.day), "not while it is up")

        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card)
        XCTAssertEqual(stored(.day), true)
        XCTAssertNil(stored(.week), "only its kind")
        XCTAssertFalse(model.showIfDue(.day, joined: true, allowFinger: true))
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false), "the week has its own")
        await waitForTimers(sleeper)
        await sleeper.advance()
        await settle()
    }

    /// A touch closes the card (on the card, or the pen, a tap or a pinch on the paper: the screen calls `close`): seen.
    func testACardThePersonClosedIsRecorded() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        model.close()
        XCTAssertNil(stored(.week), "nothing up: nothing recorded")
        XCTAssertNil(stored(.day))

        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: true))
        await waitForTimers(sleeper)
        model.close()
        XCTAssertNil(model.card, "gone at the touch")
        XCTAssertEqual(stored(.week), true, "closed by the person: seen")
        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card)
        XCTAssertFalse(model.showIfDue(.week, joined: true, allowFinger: false))
        XCTAssertNil(stored(.day))
    }

    /// The photo's card (`--screenshot-span-guide`) is never recorded, closed or not; screenshot mode shows no due card.
    func testThePhotoCardIsNeverRecorded() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper, screenshot: true)
        XCTAssertFalse(model.showIfDue(.week, joined: true, allowFinger: false))
        model.showForPhoto(.week, allowFinger: false)
        XCTAssertEqual(model.card?.timed, false)
        model.close()
        XCTAssertNil(model.card)
        model.showForPhoto(.day, allowFinger: false)
        model.dismiss()
        await settle()
        XCTAssertEqual(sleeper.recorded, [])
        XCTAssertNil(stored(.week), "screenshot mode records nothing")
        XCTAssertNil(stored(.day))
    }

    /// The setting off: nothing comes, nothing is recorded, and a close then records nothing either.
    func testTheSettingOffRecordsNothing() async {
        let sleeper = TestSleeper()
        sleeper.autoResume = true
        let model = makeModel(sleeper)
        AppSettings.pageSpan = false
        for kind in PageKind.allCases {
            XCTAssertFalse(model.showIfDue(kind, joined: true, allowFinger: false), "\(kind)")
        }
        model.close()
        await settle()
        for kind in PageKind.allCases {
            XCTAssertNil(stored(kind), "\(kind)")
        }
        AppSettings.pageSpan = true
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false), "due once the setting is on")
    }

    /// A card of another kind that replaces the one up (the screen opened the day over the week's card) leaves the week
    /// unseen: the week's card comes again the next time.
    func testACardReplacedByAnotherKindIsNotRecorded() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false))
        await waitForTimers(sleeper)
        XCTAssertTrue(model.showIfDue(.day, joined: true, allowFinger: false))
        XCTAssertEqual(model.card?.kind, .day)
        await waitForTimers(sleeper, count: 2)
        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card)
        XCTAssertEqual(stored(.day), true, "the day's card stayed its 8 seconds")
        XCTAssertNil(stored(.week), "the week's card went unseen")
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false), "it comes again")
        await waitForTimers(sleeper)
        await sleeper.advance()
        await settle()
    }

    /// The card up is not shown again over itself (the screen asks at every opening and every calm moment): it keeps its
    /// serial and its one timer, and is recorded when that timer ends.
    func testTheCardUpIsNotShownAgainOverItself() async {
        let sleeper = TestSleeper()
        let model = makeModel(sleeper)
        XCTAssertTrue(model.showIfDue(.week, joined: true, allowFinger: false))
        let serial = model.card?.serial
        await waitForTimers(sleeper)
        XCTAssertFalse(model.showIfDue(.week, joined: true, allowFinger: true), "already up")
        XCTAssertEqual(model.card?.serial, serial, "the same card")
        XCTAssertEqual(model.card?.text, n4, "its own words")
        await settle()
        XCTAssertEqual(sleeper.recorded, [8], "one timer")
        XCTAssertEqual(sleeper.waiting, 1)
        await sleeper.advance()
        await settle()
        XCTAssertNil(model.card)
        XCTAssertEqual(stored(.week), true)
    }

    // MARK: - The screen's calls (read from the source, not run: the View's lines, C3-M3)

    /// Where the screen closes the card (the person's touch: `close`) and where it takes it away unseen (`dismiss`), read
    /// where they are written. A check of the source, not of the behaviour: the screen's View is not run by XCTest
    /// (C3-M3). 1.2.2's age range sheet is one of `sheetIsUp`'s sheets, so `sheetsChanged` takes the card away under it;
    /// `askAgeRangeIfDue` itself does not name the guide (decision 9 leaves the age range code as it is).
    func testTheScreenClosesAtATouchAndTakesAwayUnderASheet() throws {
        let screen = try String(contentsOf: Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/CalendarRootScreen.swift"),
                                encoding: .utf8)
        let card = try String(contentsOf: Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/SpanGuideView.swift"),
                              encoding: .utf8)
        let code = Self.flat(screen)

        // The person's touches on the joined paper.
        XCTAssertTrue(code.contains("onPenDown: { guide.close() penDown() }"), "the pen (or a finger that writes) on the paper")
        XCTAssertTrue(code.contains("if zooming { guide.close() pinchBegan() }"), "a pinch")
        XCTAssertTrue(code.contains("func joinedTap(at point: CGPoint, zoom: CGFloat, smallScreen: Bool) { reviewTask?.cancel() guide.close()"),
                      "a finger's tap")
        XCTAssertEqual(Self.count("guide.close()", in: code), 3)
        // Sheets, questions and leaving the joined page.
        XCTAssertTrue(code.contains("if sheetIsUp { guide.dismiss() } else { showSpanGuideIfCalm() }"), "a sheet")
        XCTAssertTrue(code.contains("if showAccountChange { guide.dismiss() } else { showSpanGuideIfCalm() }"), "the account question")
        XCTAssertTrue(code.contains("Task { @MainActor in showSpanGuideIfCalm() } } } else { guide.dismiss() } }"),
                      "leaving the joined page (`joinedOpened`)")
        XCTAssertEqual(Self.count("guide.dismiss()", in: code), 3)
        // 1.2.2's age range sheet is one of the sheets; its steps do not touch the guide.
        let sheetIsUp = try XCTUnwrap(code.range(of: "private var sheetIsUp: Bool {"))
        let sheetIsUpBody = code[sheetIsUp.upperBound...].prefix { $0 != "}" }
        XCTAssertTrue(sheetIsUpBody.contains("|| ageRangeAsking"), String(sheetIsUpBody))
        let ask = try XCTUnwrap(code.range(of: "private func askAgeRangeIfDue() {"))
        let askEnd = try XCTUnwrap(code.range(of: "private func askAgeRangeAfterInkIfWriting()", range: ask.upperBound..<code.endIndex))
        XCTAssertFalse(code[ask.upperBound..<askEnd.lowerBound].contains("guide"))

        // The card's own touches.
        let cardCode = Self.flat(card)
        XCTAssertTrue(cardCode.contains(".simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in model.close() }) .onTapGesture { model.close() }"))
        XCTAssertFalse(cardCode.contains("onTapGesture { model.dismiss() }"))
    }

    /// The code without its comments, every run of spaces and line breaks made one space.
    private static func flat(_ source: String) -> String {
        source.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}
