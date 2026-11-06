import InkModel
import Layout
import UIKit
import XCTest
@testable import TegakiCalendar

/// The week start's choice (docs/M7B_CONTRACT.md §10.3, §10.4, O-2, J-9, J-10): who keeps Monday, who gets
/// the region's, and the one comparison with the pages iCloud brought, which must never make handwriting
/// disappear without a word, nor switch under a pen.
@MainActor
final class WeekStartChoiceTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "test-\(UUID())"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        WeekStartChoice.current = .monday
    }

    private let mondayPages = ["w-2026-10-05", "w-2026-10-12", "w-2026-10-19"]
    private let sundayPages = ["w-2026-10-04", "w-2026-10-11"]
    private let otherPages = ["m1-2026-10", "d-2026-10-07", "y-2026"]

    private func check(_ current: WeekStart, _ ids: [String], dirty: String? = nil, pen: Bool = false, boundary: Bool = false) -> WeekStartChoice.DataCheck {
        WeekStartChoice.dataCheck(current: current, pageIds: ids, dirtyPageId: dirty, penTouched: pen, atBoundary: boundary)
    }

    // MARK: The migration (§10.3, 1 to 3)

    /// The owner's promise: whoever used an earlier version stays on Monday, even in the United States.
    func testExistingUserKeepsMonday() {
        for key in [AppSettings.onboardingDoneKey, AppSettings.lastKindKey, AppSettings.allowFingerChosenKey] {
            let name = "test-\(UUID())"
            let store = UserDefaults(suiteName: name)!
            defer { store.removePersistentDomain(forName: name) }
            store.set(true, forKey: key)
            WeekStartChoice.migrateIfNeeded(store)
            XCTAssertEqual(store.string(forKey: AppSettings.weekStartKey), "monday", key)
            XCTAssertEqual(WeekStartChoice.setting(store), .monday, key)
            XCTAssertEqual(WeekStartChoice.resolve(WeekStartChoice.setting(store)), .monday, key)
        }
    }

    func testNewUserIsAutomatic() {
        WeekStartChoice.migrateIfNeeded(defaults)
        XCTAssertEqual(defaults.string(forKey: AppSettings.weekStartKey), "auto", "written, not left missing")
        XCTAssertEqual(WeekStartChoice.setting(defaults), .auto)
    }

    func testNewUserStaysAutomaticOnSecondLaunch() {
        WeekStartChoice.migrateIfNeeded(defaults)
        defaults.set(true, forKey: AppSettings.onboardingDoneKey)
        defaults.set("week", forKey: AppSettings.lastKindKey)
        WeekStartChoice.migrateIfNeeded(defaults)
        XCTAssertEqual(defaults.string(forKey: AppSettings.weekStartKey), "auto")
    }

    func testMigrationRunsOnce() {
        defaults.set(true, forKey: AppSettings.onboardingDoneKey)
        for value in ["sunday", "auto", "monday"] {
            defaults.set(value, forKey: AppSettings.weekStartKey)
            WeekStartChoice.migrateIfNeeded(defaults)
            XCTAssertEqual(defaults.string(forKey: AppSettings.weekStartKey), value)
        }
    }

    /// Nothing on record or a value this version does not know: Monday, where strokes stay put.
    func testBrokenValueReadsAsMonday() {
        XCTAssertEqual(WeekStartChoice.setting(defaults), .monday)
        for broken in ["", "Sunday", "saturday", "1"] {
            defaults.set(broken, forKey: AppSettings.weekStartKey)
            XCTAssertEqual(WeekStartChoice.setting(defaults), .monday, broken)
        }
    }

    // MARK: Automatic (0-44)

    /// ICU says Sunday for ja_JP; the owner's decision is Monday (J-10), and no region is Monday too.
    func testJapanIsMondayOnAuto() {
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: "JP", firstDayOfWeek: .sunday), .monday)
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: "JP", firstDayOfWeek: .monday), .monday)
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: nil, firstDayOfWeek: .sunday), .monday)
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: "US", firstDayOfWeek: .sunday), .sunday)
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: "GB", firstDayOfWeek: .monday), .monday)
        // A chosen one is what it says, whatever the region.
        XCTAssertEqual(WeekStartChoice.resolve(setting: .monday, region: "US", firstDayOfWeek: .sunday), .monday)
        XCTAssertEqual(WeekStartChoice.resolve(setting: .sunday, region: "JP", firstDayOfWeek: .monday), .sunday)
        XCTAssertEqual(WeekStartChoice.resolve(.monday), .monday)
        XCTAssertEqual(WeekStartChoice.resolve(.sunday), .sunday)
        XCTAssertEqual(WeekStartChoice.resolve(.auto), WeekStartChoice.launchAutomatic)
    }

    /// Saturday and Friday regions have no page form: they read as Monday.
    func testSaturdayRegionIsMonday() {
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: "EG", firstDayOfWeek: .saturday), .monday)
        XCTAssertEqual(WeekStartChoice.resolve(setting: .auto, region: "MV", firstDayOfWeek: .friday), .monday)
    }

    /// A changed region never changes the week start silently; a chosen week start says nothing.
    func testRegionChangeIsToldOnce() {
        defaults.set("auto", forKey: AppSettings.weekStartKey)
        XCTAssertNil(WeekStartChoice.regionChange(automatic: .monday, defaults), "the first launch only remembers")
        XCTAssertNil(WeekStartChoice.regionChange(automatic: .monday, defaults))
        XCTAssertEqual(WeekStartChoice.regionChange(automatic: .sunday, defaults), .sunday)
        XCTAssertNil(WeekStartChoice.regionChange(automatic: .sunday, defaults), "once")
        defaults.set("monday", forKey: AppSettings.weekStartKey)
        XCTAssertNil(WeekStartChoice.regionChange(automatic: .monday, defaults), "chosen: remembered, not told")
        defaults.set("auto", forKey: AppSettings.weekStartKey)
        XCTAssertNil(WeekStartChoice.regionChange(automatic: .monday, defaults))
    }

    // MARK: The comparison (§10.3, step 4)

    /// Another device's handwriting of one form only: this device takes that form, both ways.
    func testAdoptsOnlyFormFromCloud() {
        XCTAssertEqual(check(.sunday, mondayPages + otherPages), .adopt(.monday, otherPages: 0))
        XCTAssertEqual(check(.monday, sundayPages + otherPages), .adopt(.sunday, otherPages: 0))
        // Nothing to compare, or the same form: no word at all.
        XCTAssertEqual(check(.monday, []), .finish)
        XCTAssertEqual(check(.sunday, otherPages), .finish)
        XCTAssertEqual(check(.monday, mondayPages), .finish)
        XCTAssertEqual(check(.sunday, sundayPages), .finish)
    }

    /// Both forms: the larger wins, and the form looked at until now is counted for its toast.
    func testBothFormsAdoptTheLarger() {
        XCTAssertEqual(check(.sunday, mondayPages + sundayPages), .adopt(.monday, otherPages: 2))
        XCTAssertEqual(check(.monday, mondayPages + sundayPages), .stay(otherPages: 2))
        // The same number stays where it is.
        let two = ["w-2026-10-05", "w-2026-10-12"]
        XCTAssertEqual(check(.monday, two + sundayPages), .stay(otherPages: 2))
        XCTAssertEqual(check(.sunday, two + sundayPages), .stay(otherPages: 2))
    }

    /// The first draft's hole: someone who wrote one stroke on a Sunday page before the first pull would
    /// have lost sight of a Monday year's handwriting without a word. Both forms always say something,
    /// and once (the screen writes `dataChecked` for every result but `.wait`).
    func testBothFormsNotifyOnce() {
        XCTAssertEqual(check(.sunday, ["w-2026-10-04"] + mondayPages), .adopt(.monday, otherPages: 1))
        XCTAssertEqual(check(.monday, sundayPages + ["w-2026-10-05", "w-2026-10-12", "w-2026-10-19"]), .stay(otherPages: 2))
        XCTAssertFalse(WeekStartChoice.needsDataCheck(setting: .auto, dataChecked: true), "once")
        XCTAssertTrue(WeekStartChoice.needsDataCheck(setting: .auto, dataChecked: false))
        var notices = WeekStartNotices()
        notices.add(.otherForm(.sunday, pages: 2))
        notices.add(.otherForm(.sunday, pages: 2))
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "x"), .otherForm(.sunday, pages: 2))
        XCTAssertNil(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "x"), "the same one is told once")
    }

    /// `.synced` after a push alone proves nothing: the other device's pages may not have arrived.
    func testPushOnlySyncedDoesNotFinishTheCheck() {
        let token = Data([1])
        XCTAssertFalse(WeekStartChoice.readyToCheck(status: .synced, zoneToken: nil))
        XCTAssertTrue(WeekStartChoice.readyToCheck(status: .synced, zoneToken: token))
        for status in [SyncStatus.pending, .syncing, .offline, .accountMismatch, .localOnly(.noAccount)] {
            XCTAssertFalse(WeekStartChoice.readyToCheck(status: status, zoneToken: token), "\(status)")
        }
        // After an import: someone without iCloud has no pull to wait for; someone with it waits for
        // the pull; a web import always lands on Monday pages and says nothing about the form.
        XCTAssertTrue(WeekStartChoice.checksAfterImport(status: .localOnly(.noAccount), zoneToken: nil, isAppExport: true))
        XCTAssertTrue(WeekStartChoice.checksAfterImport(status: .localOnly(.restricted), zoneToken: nil, isAppExport: true))
        XCTAssertFalse(WeekStartChoice.checksAfterImport(status: .localOnly(.noAccount), zoneToken: nil, isAppExport: false))
        // Passing states of someone with iCloud: like offline, they must not use up the one comparison.
        XCTAssertFalse(WeekStartChoice.checksAfterImport(status: .localOnly(.unknown), zoneToken: nil, isAppExport: true))
        XCTAssertFalse(WeekStartChoice.checksAfterImport(status: .localOnly(.notAuthenticated), zoneToken: nil, isAppExport: true))
        XCTAssertFalse(WeekStartChoice.checksAfterImport(status: .offline, zoneToken: nil, isAppExport: true))
        XCTAssertFalse(WeekStartChoice.checksAfterImport(status: .synced, zoneToken: nil, isAppExport: true))
        XCTAssertTrue(WeekStartChoice.checksAfterImport(status: .synced, zoneToken: token, isAppExport: true))
    }

    /// **A switch rebuilds the canvas and loses the stroke in progress**, and the last 1.5 s of ink would
    /// be saved to the other form's page: `.adopt` waits for a boundary while the person writes.
    func testAdoptionWaitsWhileWriting() {
        XCTAssertEqual(check(.sunday, mondayPages, dirty: "w-2026-10-04"), .wait)
        XCTAssertEqual(check(.sunday, mondayPages, pen: true), .wait)
        XCTAssertEqual(check(.sunday, mondayPages, dirty: "w-2026-10-04", pen: true), .wait)
        // At a boundary (just saved, the page is about to change) it is decided.
        XCTAssertEqual(check(.sunday, mondayPages, pen: true, boundary: true), .adopt(.monday, otherPages: 0))
        XCTAssertEqual(check(.sunday, mondayPages + sundayPages, dirty: "w-2026-10-04", pen: true, boundary: true), .adopt(.monday, otherPages: 2))
        // A page not saved yet counts as a page of its form: one stroke's page is the current form.
        XCTAssertEqual(check(.sunday, mondayPages, dirty: "w-2026-10-04", boundary: true), .adopt(.monday, otherPages: 1))
        XCTAssertEqual(check(.sunday, ["w-2026-10-05"], dirty: "w-2026-10-04", boundary: true), .stay(otherPages: 1), "one each: stays")
        XCTAssertEqual(check(.sunday, [], dirty: "w-2026-10-04"), .finish)
        // A dirty month page is no week page.
        XCTAssertEqual(check(.sunday, [], dirty: "m1-2026-10"), .finish)
        // What switches nothing never waits.
        XCTAssertEqual(check(.monday, mondayPages, dirty: "w-2026-10-05", pen: true), .finish)
        XCTAssertEqual(check(.monday, mondayPages + sundayPages, dirty: "w-2026-10-05", pen: true), .stay(otherPages: 2))
    }

    /// A chosen week start, and everyone from an earlier version, is never compared.
    func testExplicitSettingNeverAdopts() {
        XCTAssertFalse(WeekStartChoice.needsDataCheck(setting: .monday, dataChecked: false))
        XCTAssertFalse(WeekStartChoice.needsDataCheck(setting: .sunday, dataChecked: false))
        XCTAssertFalse(WeekStartChoice.needsDataCheck(setting: .monday, dataChecked: true))
    }

    /// The person's answer stands. Someone from an earlier version ("monday", `dataChecked` false) who
    /// chooses 自動 in the United States and answers 〔日曜にする〕 has Monday pages only: if the comparison
    /// still ran, the next sync would say `.adopt(.monday)` and take the answer back without being asked.
    func testChoosingAutoIsNotComparedAgain() {
        defaults.set("monday", forKey: AppSettings.weekStartKey)
        XCTAssertEqual(check(.sunday, mondayPages), .adopt(.monday, otherPages: 0), "what the comparison would do")

        WeekStartChoice.choose(.auto, defaults)
        XCTAssertEqual(defaults.string(forKey: AppSettings.weekStartKey), "auto")
        XCTAssertEqual(WeekStartChoice.setting(defaults), .auto)
        XCTAssertFalse(WeekStartChoice.needsDataCheck(setting: .auto, dataChecked: defaults.bool(forKey: AppSettings.weekStartDataCheckedKey)))

        // The other way, and any later choice.
        for setting in WeekStartChoice.Setting.allCases {
            let name = "test-\(UUID())"
            let store = UserDefaults(suiteName: name)!
            defer { store.removePersistentDomain(forName: name) }
            WeekStartChoice.migrateIfNeeded(store)
            XCTAssertTrue(WeekStartChoice.needsDataCheck(setting: WeekStartChoice.setting(store), dataChecked: store.bool(forKey: AppSettings.weekStartDataCheckedKey)), "a new person who chose nothing is compared")
            WeekStartChoice.choose(setting, store)
            XCTAssertEqual(WeekStartChoice.setting(store), setting)
            XCTAssertFalse(WeekStartChoice.needsDataCheck(setting: WeekStartChoice.setting(store), dataChecked: store.bool(forKey: AppSettings.weekStartDataCheckedKey)), "\(setting)")
        }
    }

    /// `current` is set at launch, not only at a switch: a Sunday person's first PDF would otherwise have
    /// the drawing of 11/1 under the title 10/26–11/1 (§10.5). Screenshot mode: its argument, no record.
    func testPrepareAtLaunchSetsCurrent() throws {
        defaults.set("sunday", forKey: AppSettings.weekStartKey)
        XCTAssertEqual(WeekStartChoice.prepareAtLaunch(shot: nil, defaults), .sunday)
        XCTAssertEqual(WeekStartChoice.current, .sunday)
        defaults.set("monday", forKey: AppSettings.weekStartKey)
        XCTAssertEqual(WeekStartChoice.prepareAtLaunch(shot: nil, defaults), .monday)
        XCTAssertEqual(WeekStartChoice.current, .monday)

        // The migration runs inside it.
        let name = "test-\(UUID())"
        let fresh = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { fresh.removePersistentDomain(forName: name) }
        XCTAssertEqual(WeekStartChoice.prepareAtLaunch(shot: nil, fresh), WeekStartChoice.launchAutomatic)
        XCTAssertEqual(fresh.string(forKey: AppSettings.weekStartKey), "auto")

        // Screenshot mode neither migrates nor reads.
        let shotDefaults = "test-\(UUID())"
        let untouched = try XCTUnwrap(UserDefaults(suiteName: shotDefaults))
        defer { untouched.removePersistentDomain(forName: shotDefaults) }
        var shot = try XCTUnwrap(ScreenshotMode.parse(["--screenshot-mode", "--screenshot-week-start", "sunday"]))
        XCTAssertEqual(WeekStartChoice.prepareAtLaunch(shot: shot, untouched), .sunday)
        XCTAssertEqual(WeekStartChoice.current, .sunday)
        XCTAssertNil(untouched.object(forKey: AppSettings.weekStartKey))
        shot.weekStart = .monday
        XCTAssertEqual(WeekStartChoice.prepareAtLaunch(shot: shot, untouched), .monday)
        XCTAssertEqual(WeekStartChoice.current, .monday)
    }

    /// §10.5: the import's sentence names the other form, judged with the week start after the comparison.
    func testOtherFormOfAnImport() {
        XCTAssertEqual(WeekStartChoice.otherForm(amongPageIds: mondayPages + sundayPages, current: .monday), .sunday)
        XCTAssertEqual(WeekStartChoice.otherForm(amongPageIds: mondayPages + sundayPages, current: .sunday), .monday)
        XCTAssertNil(WeekStartChoice.otherForm(amongPageIds: mondayPages + otherPages, current: .monday))
        XCTAssertNil(WeekStartChoice.otherForm(amongPageIds: sundayPages, current: .sunday))
        XCTAssertNil(WeekStartChoice.otherForm(amongPageIds: [], current: .sunday))
    }

    // MARK: The toasts (§10.4)

    /// A toast under a sheet is a toast nobody saw, and a page's hidden strokes would count as told.
    func testHiddenInkNoticeWaitsForTheSheet() {
        var notices = WeekStartNotices()
        let hidden = WeekStartNotice.hiddenInk(pageId: "m1-2026-11", strokes: 3)
        notices.add(hidden)
        XCTAssertNil(notices.next(sheetIsUp: true, toastShowing: false, currentPageId: "m1-2026-11"))
        XCTAssertNil(notices.next(sheetIsUp: false, toastShowing: true, currentPageId: "m1-2026-11"))
        XCTAssertNil(notices.next(sheetIsUp: true, toastShowing: true, currentPageId: "m1-2026-11"))
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"), hidden, "the sheet closed")
        XCTAssertNil(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"), "taken")

        // Moved to another page: dropped (it is judged again when that page opens); the next one comes.
        notices.add(hidden)
        notices.add(.adopted(.monday))
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-12"), .adopted(.monday))
        XCTAssertNil(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"))

        // In the order they came; a page's newer count replaces the older.
        notices.add(.adopted(.sunday))
        notices.add(.otherForm(.monday, pages: 2))
        notices.add(hidden)
        notices.add(.hiddenInk(pageId: "m1-2026-11", strokes: 5))
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"), .adopted(.sunday))
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"), .otherForm(.monday, pages: 2))
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"), .hiddenInk(pageId: "m1-2026-11", strokes: 5))

        // Switched back under the sheet: the month's id is the same, the count is no longer true.
        notices.add(hidden)
        notices.add(.adopted(.monday))
        notices.dropHiddenInk()
        XCTAssertEqual(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"), .adopted(.monday))
        XCTAssertNil(notices.next(sheetIsUp: false, toastShowing: false, currentPageId: "m1-2026-11"))
    }

    func testNoticeWords() {
        XCTAssertEqual(WeekStartNotice.hiddenInk(pageId: "m1-2026-11", strokes: 3).text, "この月のページには、いまの週の始まりでは表示されない日に書いた線が 3 本あります。消えていません。週の始まりを戻すと見えます。")
        XCTAssertEqual(WeekStartNotice.adopted(.monday).text, "iCloud の手書きに合わせて、週の始まりを月曜にしました。設定で変えられます。")
        XCTAssertEqual(WeekStartNotice.adopted(.sunday).text, "iCloud の手書きに合わせて、週の始まりを日曜にしました。設定で変えられます。")
        XCTAssertEqual(WeekStartNotice.regionChanged(.sunday).text, "端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは消えていません。")
        XCTAssertEqual(WeekStartNotice.regionChanged(.monday).text, "端末の地域に合わせて、週の始まりを月曜にしました。日曜始まりの週の手書きは消えていません。")
        XCTAssertEqual(WeekStartNotice.otherForm(.sunday, pages: 2).text, "もう一方の週の始まり（日曜）の週のページが 2 ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。")
    }

    /// `ToastView` has `lineLimit(3)` and the subheadline: the sentences must fit an iPhone 17's width (402
    /// pt less the toast's two 16 pt paddings on each side) in three lines in the ten languages. If not,
    /// X shortens the translation. The narrower iPhones (375 pt) are only reported: on a Mac every sentence
    /// fits there too, some within a point (it `hiddenInk.other`), which the simulator may move.
    func testWeekStartToastsFitThreeLines() {
        // The default text size, whatever the machine's setting; the larger sizes grow the toast's three
        // lines with the font, which no sentence can be short enough for.
        let font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        // The layout's own lines: a height divided by the line height would count three lines of a CJK
        // fallback font, which is taller than the system font, as four.
        func lines(_ text: String, width: CGFloat) -> Int {
            let storage = NSTextStorage(string: text, attributes: [.font: font])
            let manager = NSLayoutManager()
            storage.addLayoutManager(manager)
            let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            var count = 0
            var glyph = 0
            while glyph < manager.numberOfGlyphs {
                var range = NSRange()
                _ = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
                glyph = NSMaxRange(range)
                count += 1
            }
            return count
        }
        let plain = ["toast.weekStart.adopted.monday", "toast.weekStart.adopted.sunday",
                     "toast.weekStart.regionChanged.monday", "toast.weekStart.regionChanged.sunday"]
        for language in UILanguage.allCases {
            var sentences = plain.map { L.text($0, in: language) }
            let name = L.text("settings.weekStart.monday", in: language)
            for (form, number) in [("one", 1), ("other", 99)] {
                let count = DateText.number(number, language)
                sentences.append(KitStrings.fill(L.text("toast.weekStart.hiddenInk.\(form)", in: language), [count]))
                sentences.append(KitStrings.fill(L.text("toast.weekStart.otherForm.\(form)", in: language), [name, count]))
            }
            for sentence in sentences {
                XCTAssertLessThanOrEqual(lines(sentence, width: 402 - 64), 3, "\(language): \(sentence)")
                if lines(sentence, width: 375 - 64) > 3 {
                    print("week start toast over three lines at 375 pt (\(language)): \(sentence)")
                }
            }
        }
    }
}
