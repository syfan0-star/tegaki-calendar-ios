import UIKit
import XCTest

/// 1.4.3 (docs/R1_4_3_CONTRACT.md §6.5, §12.4, §12.5, 0g-31, 0g-43): the photos of the joined months and the joined years
/// from the normal build, in screenshot mode with the joined pages' arguments. Only a job that passes where
/// to write and the device's id runs it (`TEST_RUNNER_TEGAKI_SPAN_MY_SHOT_OUT`, `TEST_RUNNER_TEGAKI_SPAN_MY_SHOT_DEVICE`:
/// ipad13, ipad11, ipadmini or iphone69; xcodebuild hands them to the test runner without the prefix): the sample photos'
/// job of the throwaway branch r143-alt (§12.5, step P) and later span-shots-my (§12.4). Anywhere else every test skips
/// itself, so the iPhone's UI test step only counts them as skipped (as `SpanShotsUITests`).
///
/// D1b-0 (§14.1): the month's sample photos of §12.5, every one on 2026-10 (the demo's focus month, its 7th a Wednesday)
/// with `--screenshot-month-tall` (the right neighbour, November, has taller rows: five all-day events on its 18th and
/// three lines in its 25th, so the three forms of the joined months differ):
/// - `testMonthForms`: the window with the focus month's right boundary in the middle (`--screenshot-offset-x 0.5`, the
///   focus month and its tall neighbour side by side), portrait on the iPad Air 11-inch, the 13-inch iPad and the 6.9-inch
///   iPhone, and the iPad Air 11-inch turned with the window at its opening (the overview, no offset). Once per variant of
///   `TEST_RUNNER_TEGAKI_SPAN_MY_VARIANTS` (`name:arguments|name:arguments`, the arguments split on spaces; the sample
///   job names the three forms there); without it once, as the build lays the months out.
/// - `testMonthZoom`: 等倍 before and after (`--screenshot-zoom fit`), turned on the four devices; portrait once on the
///   13-inch iPad (a month at 等倍 there looks as it opens). An "after" photo whose zoom is not one page's width across the
///   canvas (the probe's `zoom` × 1,400 against the canvas's width, within 1.5 pt) fails the test: it would not show 等倍.
///
/// D1b (§12.4, §12.3, 0g-31; the month's part, the year's below): the photos of the job span-shots-my, every one on
/// 2026-10 in screenshot mode with `--screenshot-span on` unless said (the plain demo: no `--screenshot-month-tall`, every
/// month's rows alike), 24 of the month (the 26 candidates of §12.4 less the three "before 等倍", which are the turned
/// overviews; open question 7 of the plan; and one more card, ja's for two fingers, review CI-1). These are what the job runs; `testMonthForms` and `testMonthZoom` above stay for
/// the sample branch r143-alt:
/// - `testMonthBands` (the four devices): portrait, the overview (`<device>-portrait-month-overview`) and the focus
///   month's left boundary in the middle with the crossing sample (`--screenshot-offset-x -0.5 --screenshot-span-crossing
///   all`, `-boundary`); turned on the 13-inch iPad, the iPad Air 11-inch and the 6.9-inch iPhone, the overview
///   (`<device>-landscape-month-overview`, the "before" of 等倍 too). Before them, in each orientation, the one page's
///   month at the same place (`--screenshot-span off`, `path=one`) is launched without a photo, and each photo's line
///   `span-my paper:` sets its canvas frame beside that one page's (§12.3: the joined month's paper area is the one page's,
///   the heading being as tall; a difference fails the test and the job's gate).
/// - `testMonthFit` (the same three devices, turned): 等倍 (`--screenshot-zoom fit`, `<device>-landscape-month-fit`); a
///   photo whose page is not the canvas's width across (the probe's zoom × 1,400 within 1.5 pt) fails the test.
/// - `testMonthShiftPair` (the iPad Air 11-inch, portrait; `SpanShotsUITests.testShiftPairs`' steps): the window opens one
///   page off and held (`--screenshot-span-shift`, a flag: §12.4's "1" is not read), "before", `span.release`, "after"
///   once `shifts=1` settled (`-month-shift-before`, `-after`). Its line `span-my shift pair:` names the rows above the
///   canvas (the status bar, the heading and the sticky month row with its label, which may differ: open question 17),
///   which the job leaves out of tools/shots/shift_pair.swift (§3.5's y correction: no strong pixel below them).
/// - `testMonthOldVersion` (the 6.9-inch iPhone and the 13-inch iPad, portrait): the old versions' view, one page with
///   the halves of the crossing sample it owns (`--screenshot-single-page --screenshot-span-crossing all`, `path=one`,
///   `-month-single`): the line cut at the paper's edge (B_DESIGN §4.3).
/// - `testMonthGuides` (the 6.9-inch iPhone, portrait): the first-time guide's card of the month for one finger
///   (`--screenshot-span-guide one`) in ja, de, fr and the doubled pseudo-language (`-AppleLanguages (en)
///   -NSDoubleLocalizedStrings YES`), each with its region's holidays and week start as SpanShotsUITests' languages
///   (`-month-guide-<ja|de|fr|pseudo>`); the narrowest screen of the job, for the texts' lengths. And ja's card for two
///   fingers (`--screenshot-span-guide two`, `-month-guide-ja-two`; review CI-1): the card an iPhone shows with
///   「指でも書く」 on, its default (§12.4's `one|two`).
/// - `testMonthDots` (the 13-inch iPad, portrait): the memo paper's dots (`--screenshot-memo-paper dots`) at the joined
///   months' boundary (`--screenshot-offset-x -0.5`, no crossing sample over the dots: `ipad13-portrait-month-dots`),
///   1.4.2's promise that the dots keep their spacing across it.
///
/// D1y (§12.4, §12.3, §5.3, §5.4, 0g-31; the year's part): 22 photos of the joined year in 29 launches (7 of them the one
/// page's year without a photo), every one on the year page of 2026 (`--screenshot-page year`; 2026-10's demo, its
/// neighbours the demo's handwriting without events) with `--screenshot-span on` unless said; with the month's 24, the job's
/// 46. No PDF of a year (§12.4 has none).
/// - `testYearBands` (the four devices): portrait, the overview (`<device>-portrait-year-overview`, the year's label 「’26」
///   over the day-number column on an iPad, none on an iPhone: §5.3) and 2026's left boundary in the middle with the
///   crossing sample (`--screenshot-offset-x -0.5 --screenshot-span-crossing all`: the 20th's two lines from 2025's
///   December into 2026, `-boundary`); turned on the 13-inch iPad, the iPad Air 11-inch and the 6.9-inch iPhone, the
///   overview (`<device>-landscape-year-overview`; the iPhone's is the cap of 3 years, P-B6 イ, opened two rows above
///   today's row: §5.4). Before them, in each orientation, the one page's year at the same place (`--screenshot-span off`,
///   `path=one`) is launched without a photo for the lines `span-my paper:` (gate 3, §12.3), as the month's.
/// - `testYearFit` (the four devices portrait, the three turned): 等倍 (`--screenshot-zoom fit`, `<device>-portrait-year-fit`,
///   `<device>-landscape-year-fit`; the iPhone's portrait is its overview, open = fit there, and its landscape one year
///   across, the cap not changing the fit: §6.4); a photo whose page is not the canvas's width across (the probe's zoom ×
///   1,400 within 1.5 pt) fails the test.
/// - `testYearOldVersion` (the 6.9-inch iPhone and the 13-inch iPad, portrait): the old versions' view, one page with the
///   half of the crossing sample it owns (`--screenshot-single-page --screenshot-span-crossing all`, `path=one`,
///   `-year-single`): 2026's line cut at the paper's left edge (B_DESIGN §4.3).
/// - `testYearGuides` (the 6.9-inch iPhone, portrait): the first-time guide's card of the year in ja, for one finger
///   (`--screenshot-span-guide one`, `-year-guide-ja`) and for two (`two`, `-year-guide-ja-two`; the month's review CI-1).
/// The fallback of §14.1's decision (the year not joined) takes these four out of the job (its `-only-testing` list and its
/// photos expected).
///
/// Each photo writes `span-my shots:` (the window, the canvas's frame, the probe's zoom, ox, oy, the paper's top in lu, one
/// page across in pt, `span.state` and the probe, last) and `span cap:` (the window's pages and top: a month has no cap, an
/// iPhone's turned year has, 3 years; the line is the record of gate 3's new state lines, §12.3), and a launch whose canvas
/// never settled is made once more (FLAKE-1 of docs/M7C.md: a photo measures, it is not a gate on behaviour). The waits
/// read once more after their deadline and count their reads (docs/R1_4_1.md :463, R1_4_2_CONTRACT §1.5). The job's PDF of
/// a joined month is PDFMonthYearTests' (`span-my-pdf-month.pdf`).
///
/// A portrait photo is the app's screenshot (XCUIScreenshot). A turned screen is photographed by the job instead
/// (`TEST_RUNNER_TEGAKI_SPAN_MY_SHOT_REQUESTS`: the test writes `<file>\n270\n` into `<name>.request`, the job's
/// `simctl io screenshot` writes the file under the output folder and answers `<name>.request.done`, "ok" or "failed"; the
/// protocol of `SpanShotsUITests.simulatorPhoto`), because XCUIScreenshot of a screen turned with `XCUIDevice` keeps the
/// portrait frame buffer. Without the job's answer the test falls back to XCUIScreenshot and says so (`photo=xcui`).
///
/// Every line is printed with `span-my shots:` and appended to `<out>/lines/<device>.txt`.
@MainActor
final class SpanMonthYearShotsUITests: XCTestCase {
    private struct Setup {
        let out: URL
        let device: String
        var isPad: Bool { device.hasPrefix("ipad") }
    }

    /// A photo written: its path under the output folder, how it was taken and its pixel width (0 when unknown).
    private struct Photo {
        let file: String
        let how: String
        let pixelWidth: Int
    }

    /// The canvas at rest: its probe, its frame and `span.state`'s fields.
    private struct Settled {
        let probe: [String: String]
        let raw: String
        let frame: CGRect
        let state: [String: String]
        /// D1b: `span.state` as read with the probe (the photos' `state=`); empty from `settled`.
        var stateRaw = ""
    }

    /// A variant of the forms' photos: its name (in the file's name; empty for none) and the launch arguments it adds.
    private struct Variant {
        let name: String
        let arguments: [String]
    }

    private static let japanese = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    /// Every photo's month: the demo's focus month with the tall right neighbour.
    private static let month = ["--screenshot-page", "month", "--screenshot-span", "on", "--screenshot-month-tall"]
    /// The page's width in lu (`ZoomPolicy.paperWidth(.month)`).
    private static let monthWidth = 1_400.0
    /// How far (pt) the canvas's width may be from the probe's zoom × 1,400 on an "after" photo.
    private static let fitTolerance = 1.5
    /// How long a photo waits after the screen has settled (s): the sticky heading follows the canvas's report on a later
    /// turn (`BlankPaperShotsUITests.photoWait`).
    private let photoWait: TimeInterval = 1

    /// D1b: the devices of span-shots-my, and the three it turns.
    private static let devices = ["ipad13", "ipad11", "ipadmini", "iphone69"]
    private static let turnedDevices = ["ipad13", "ipad11", "iphone69"]
    /// D1b: the joined month of the plain demo (every month's rows alike).
    private static let joinedMonth = ["--screenshot-page", "month", "--screenshot-span", "on"]
    /// D1b: the one page's month at the same place (the setting off: `path=one`, `span.state` shown).
    private static let onePageMonth = ["--screenshot-page", "month", "--screenshot-span", "off"]
    /// D1y: the joined year of the demo (2026; its neighbours the demo's handwriting without events, rows lined up on 2026's).
    private static let joinedYear = ["--screenshot-page", "year", "--screenshot-span", "on"]
    /// D1y: the one page's year at the same place.
    private static let onePageYear = ["--screenshot-page", "year", "--screenshot-span", "off"]
    /// D1y: the page's width in lu (`ZoomPolicy.paperWidth(.year)`, `PaperSpec.yearWidth`).
    private static let yearWidth = 1_400.0
    /// D1b: the focus month's left boundary in the middle with the crossing sample (§12.4).
    private static let boundary = ["--screenshot-offset-x", "-0.5", "--screenshot-span-crossing", "all"]
    /// D1b: how far (pt) a joined photo's canvas frame may be from the one page's in any of its four numbers.
    private static let paperTolerance: CGFloat = 0.5
    /// D1b: the guide's languages (SpanShotsUITests' with their regions' holidays and week start) and the doubled
    /// pseudo-language (l10n-shots' `pseudo/`), by the name in the photo's file.
    private static let guideLanguages: [(name: String, arguments: [String])] = [
        ("ja", japanese),
        ("de", ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "--screenshot-holidays", "auto", "--screenshot-week-start", "auto"]),
        ("fr", ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR", "--screenshot-holidays", "auto", "--screenshot-week-start", "auto"]),
        ("pseudo", ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-NSDoubleLocalizedStrings", "YES",
                    "--screenshot-holidays", "auto", "--screenshot-week-start", "auto"]),
    ]

    // MARK: The tests

    func testMonthForms() throws {
        let setup = try setup()
        let plan: [(UIDeviceOrientation, String)]
        switch setup.device {
        case "ipad11": plan = [(.portrait, "boundary"), (.landscapeLeft, "overview")]
        case "ipad13", "iphone69": plan = [(.portrait, "boundary")]
        default: throw XCTSkip("the forms' photos are taken on the iPad Air 11-inch, the 13-inch iPad and the 6.9-inch iPhone")
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        for variant in Self.variants() {
            for (orientation, view) in plan {
                let suffix = variant.name.isEmpty ? "" : "-\(variant.name)"
                let name = "\(setup.device)-\(Self.name(orientation))-month-form\(suffix)-\(view)"
                let offset = view == "boundary" ? ["--screenshot-offset-x", "0.5"] : []
                monthPhoto(setup, name: name, orientation: orientation, arguments: Self.month + offset + variant.arguments)
            }
        }
    }

    func testMonthZoom() throws {
        let setup = try setup()
        guard ["ipad13", "ipad11", "ipadmini", "iphone69"].contains(setup.device) else {
            throw XCTSkip("no fit photos on \(setup.device)")
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        for step in ["before", "after"] {
            let zoom = step == "after" ? ["--screenshot-zoom", "fit"] : []
            monthPhoto(setup, name: "\(setup.device)-landscape-month-zoom-\(step)", orientation: .landscapeLeft,
                       arguments: Self.month + zoom, fit: step == "after")
        }
        if setup.device == "ipad13" {
            monthPhoto(setup, name: "ipad13-portrait-month-zoom-after", orientation: .portrait,
                       arguments: Self.month + ["--screenshot-zoom", "fit"], fit: true)
        }
    }

    // MARK: The tests of span-shots-my (D1b, the month)

    func testMonthBands() throws {
        let setup = try setup()
        guard Self.devices.contains(setup.device) else { throw XCTSkip("no joined month's bands on \(setup.device)") }
        defer { XCUIDevice.shared.orientation = .portrait }
        let orientations: [UIDeviceOrientation] = Self.turnedDevices.contains(setup.device) ? [.portrait, .landscapeLeft] : [.portrait]
        for orientation in orientations {
            let one = onePage(setup, orientation: orientation)
            let prefix = "\(setup.device)-\(Self.name(orientation))-month"
            shot(setup, name: "\(prefix)-overview", orientation: orientation, arguments: Self.joinedMonth, onePage: one)
            if orientation == .portrait {
                shot(setup, name: "\(prefix)-boundary", orientation: orientation, arguments: Self.joinedMonth + Self.boundary, onePage: one)
            }
        }
    }

    func testMonthFit() throws {
        let setup = try setup()
        guard Self.turnedDevices.contains(setup.device) else { throw XCTSkip("no turned 等倍 photo of the month on \(setup.device)") }
        defer { XCUIDevice.shared.orientation = .portrait }
        shot(setup, name: "\(setup.device)-landscape-month-fit", orientation: .landscapeLeft,
             arguments: Self.joinedMonth + ["--screenshot-zoom", "fit"], fit: true)
    }

    func testMonthShiftPair() throws {
        let setup = try setup()
        guard setup.device == "ipad11" else { throw XCTSkip("the month's shift pair is taken on the iPad Air 11-inch") }
        XCUIDevice.shared.orientation = .portrait
        monthShiftPair(setup)
    }

    func testMonthOldVersion() throws {
        let setup = try setup()
        guard ["iphone69", "ipad13"].contains(setup.device) else {
            throw XCTSkip("the old versions' month is taken on the 6.9-inch iPhone and the 13-inch iPad")
        }
        shot(setup, name: "\(setup.device)-portrait-month-single", orientation: .portrait,
             arguments: ["--screenshot-page", "month", "--screenshot-single-page", "--screenshot-span-crossing", "all"], path: "one")
    }

    func testMonthGuides() throws {
        let setup = try setup()
        guard setup.device == "iphone69" else { throw XCTSkip("the month's guide cards are taken on the 6.9-inch iPhone") }
        for language in Self.guideLanguages {
            shot(setup, name: "iphone69-portrait-month-guide-\(language.name)", orientation: .portrait,
                 arguments: Self.joinedMonth + ["--screenshot-span-guide", "one"], language: language.arguments, card: true)
        }
        // Review CI-1 (§12.4 `one|two`): 「指でも書く」 on, an iPhone's default, shows the two-finger card.
        shot(setup, name: "iphone69-portrait-month-guide-ja-two", orientation: .portrait,
             arguments: Self.joinedMonth + ["--screenshot-span-guide", "two"], language: Self.japanese, card: true)
    }

    func testMonthDots() throws {
        let setup = try setup()
        guard setup.device == "ipad13" else { throw XCTSkip("the dots at the boundary are taken on the 13-inch iPad") }
        shot(setup, name: "ipad13-portrait-month-dots", orientation: .portrait,
             arguments: Self.joinedMonth + ["--screenshot-offset-x", "-0.5", "--screenshot-memo-paper", "dots"])
    }

    // MARK: The tests of span-shots-my (D1y, the year)

    func testYearBands() throws {
        let setup = try setup()
        guard Self.devices.contains(setup.device) else { throw XCTSkip("no joined year's bands on \(setup.device)") }
        defer { XCUIDevice.shared.orientation = .portrait }
        let orientations: [UIDeviceOrientation] = Self.turnedDevices.contains(setup.device) ? [.portrait, .landscapeLeft] : [.portrait]
        for orientation in orientations {
            let one = onePage(setup, orientation: orientation, kind: "year")
            let prefix = "\(setup.device)-\(Self.name(orientation))-year"
            shot(setup, name: "\(prefix)-overview", orientation: orientation, arguments: Self.joinedYear, kind: "year", onePage: one)
            if orientation == .portrait {
                shot(setup, name: "\(prefix)-boundary", orientation: orientation, arguments: Self.joinedYear + Self.boundary, kind: "year",
                     onePage: one)
            }
        }
    }

    func testYearFit() throws {
        let setup = try setup()
        guard Self.devices.contains(setup.device) else { throw XCTSkip("no 等倍 photo of the year on \(setup.device)") }
        defer { XCUIDevice.shared.orientation = .portrait }
        let orientations: [UIDeviceOrientation] = Self.turnedDevices.contains(setup.device) ? [.portrait, .landscapeLeft] : [.portrait]
        for orientation in orientations {
            shot(setup, name: "\(setup.device)-\(Self.name(orientation))-year-fit", orientation: orientation,
                 arguments: Self.joinedYear + ["--screenshot-zoom", "fit"], kind: "year", fit: true)
        }
    }

    func testYearOldVersion() throws {
        let setup = try setup()
        guard ["iphone69", "ipad13"].contains(setup.device) else {
            throw XCTSkip("the old versions' year is taken on the 6.9-inch iPhone and the 13-inch iPad")
        }
        shot(setup, name: "\(setup.device)-portrait-year-single", orientation: .portrait,
             arguments: ["--screenshot-page", "year", "--screenshot-single-page", "--screenshot-span-crossing", "all"], path: "one", kind: "year")
    }

    func testYearGuides() throws {
        let setup = try setup()
        guard setup.device == "iphone69" else { throw XCTSkip("the year's guide cards are taken on the 6.9-inch iPhone") }
        shot(setup, name: "iphone69-portrait-year-guide-ja", orientation: .portrait,
             arguments: Self.joinedYear + ["--screenshot-span-guide", "one"], kind: "year", language: Self.japanese, card: true)
        // The month's review CI-1 (§12.4 `one|two`): 「指でも書く」 on, an iPhone's default, shows the two-finger card.
        shot(setup, name: "iphone69-portrait-year-guide-ja-two", orientation: .portrait,
             arguments: Self.joinedYear + ["--screenshot-span-guide", "two"], kind: "year", language: Self.japanese, card: true)
    }

    // MARK: The photos of span-shots-my

    /// The one page's month (D1y: or year, `kind`) at `orientation` (no photo): its canvas at rest, for the joined photos'
    /// `span-my paper:` lines; launched once more when it never settled. nil (failed) when it did not settle twice.
    private func onePage(_ setup: Setup, orientation: UIDeviceOrientation, kind: String = "month") -> Settled? {
        let name = "\(setup.device)-\(Self.name(orientation))-\(kind)-one-page"
        for attempt in 1...2 {
            XCUIDevice.shared.orientation = orientation
            let app = launch(kind == "year" ? Self.onePageYear : Self.onePageMonth)
            let path = waitForStateCounted(app, timeout: 45) { $0["path"] == "one" && $0["kind"] == kind }
            let view = path == nil ? nil : settledCounted(app)
            if let view {
                record(setup, "span-my one page: \(name) attempt=\(attempt) window=\(Self.text(app.windows.firstMatch.frame)) "
                    + "frame=\(Self.text(view.frame)) zoom=\(view.probe["zoom"] ?? "?") ox=\(view.probe["ox"] ?? "?") "
                    + "oy=\(view.probe["oy"] ?? "?") state=\(stateLabel(app)) probe=\(view.raw)")
                app.terminate()
                return view
            }
            record(setup, "span-my one page: \(name) attempt=\(attempt) not settled (path \(path == nil ? "not one" : "one")); state=\(stateLabel(app))")
            app.terminate()
        }
        XCTFail("\(name): the one page's \(kind) never settled: no paper area to set the joined photos beside")
        return nil
    }

    /// One photo of span-shots-my: launched (once more when its canvas never settled), the path asked for in `span.state`
    /// with the page `kind` (the month's, D1y: or the year's; with `card` the guide's card up too), settled, taken, and its
    /// lines written: `span-my shots:`, `span cap:`, and with `onePage` the line `span-my paper:` (its canvas frame beside the
    /// one page's at the same place; a difference fails). With `fit` one page must be the canvas's width across.
    private func shot(_ setup: Setup, name: String, orientation: UIDeviceOrientation, arguments: [String], path: String = "span",
                      kind: String = "month", language: [String]? = nil, card: Bool = false, fit: Bool = false, onePage one: Settled? = nil) {
        for attempt in 1...2 {
            XCUIDevice.shared.orientation = orientation
            let app = launch(arguments, language: language)
            let state = waitForStateCounted(app, timeout: 45) { $0["path"] == path && $0["kind"] == kind }
            let guide = element(app, "span.guide")
            let cardUp = !card || guide.waitForExistence(timeout: 30) || guide.exists
            let view = state == nil ? nil : settledCounted(app)
            guard let view else {
                record(setup, "span-my shots: \(name) attempt=\(attempt) not settled (path \(state == nil ? "not \(path)" : path)); state=\(stateLabel(app))")
                app.terminate()
                if attempt == 2 { XCTFail("\(name): span.state never read path=\(path) with kind=\(kind) and a settled canvas, twice") }
                continue
            }
            Thread.sleep(forTimeInterval: photoWait)
            let photo = takePhoto(app, setup, file: "\(name).png", turned: orientation != .portrait)
            let zoom = view.probe["zoom"].flatMap { Double($0) } ?? 0
            let oy = view.probe["oy"].flatMap { Double($0) } ?? 0
            let top = zoom > 0 ? oy / zoom : 0
            let across = zoom * (kind == "year" ? Self.yearWidth : Self.monthWidth)
            let width = Double(view.frame.width)
            let pages = view.state["pages"] ?? "?"
            var extra = ""
            if card {
                extra = " card=\(guide.exists ? Self.text(guide.frame) : "gone") text=\(guide.exists ? String(guide.label.prefix(40)) : "-")"
                    .replacingOccurrences(of: "\n", with: " ")
            }
            record(setup, "span-my shots: \(name) photo=\(photo.how) attempt=\(attempt) window=\(Self.text(app.windows.firstMatch.frame)) "
                + "frame=\(Self.text(view.frame)) zoom=\(view.probe["zoom"] ?? "?") ox=\(view.probe["ox"] ?? "?") oy=\(view.probe["oy"] ?? "?") "
                + "top=\(Self.number(top)) across=\(Self.number(across)) pages=\(pages)\(extra) state=\(view.stateRaw) probe=\(view.raw)")
            record(setup, "span cap: device=\(setup.device) kind=\(name) pages=\(pages) top=\(Self.number(top))lu")
            if let one {
                let same = Self.sameFrame(view.frame, one.frame)
                record(setup, "span-my paper: device=\(setup.device) orientation=\(Self.name(orientation)) kind=\(name) "
                    + "joined=\(Self.text(view.frame)) one=\(Self.text(one.frame)) same=\(same ? "yes" : "no")")
                if !same {
                    XCTFail("\(name): the joined \(kind)'s canvas \(Self.text(view.frame)) is not the one page's \(Self.text(one.frame)) at the same place (§12.3)")
                }
            }
            if fit, abs(across - width) > Self.fitTolerance {
                XCTFail("\(name): one page is \(Self.number(across)) pt across a canvas \(Self.number(width)) pt wide: not at fit")
            }
            if card, !cardUp || !guide.exists {
                XCTFail("\(name): the guide's card span.guide was \(cardUp ? "gone before the photo" : "never up")")
            }
            app.terminate()
            return
        }
    }

    /// The month's pair before and after a shift, in one launch (`SpanShotsUITests.shiftPair`'s steps): the line
    /// `span-my shift pair:` names the rows the job leaves out (strict: everything above the canvas and one row more; loose:
    /// the status bar only), the canvas before and after (`band=same|moved`) and whether the title changed.
    private func monthShiftPair(_ setup: Setup) {
        let base = "\(setup.device)-portrait-month-shift"
        let app = launch(Self.joinedMonth + ["--screenshot-span-shift"])
        defer { app.terminate() }
        guard waitForStateCounted(app, timeout: 45, { $0["path"] == "span" && $0["kind"] == "month" && $0["hold"] == "on" }) != nil else {
            XCTFail("\(base): span.state never read path=span, kind=month with hold=on")
            record(setup, "span-my shots: \(base): no hold; state=\(stateLabel(app))")
            return
        }
        guard let before = settledCounted(app), before.state["hold"] == "on" else {
            XCTFail("\(base): the window did not settle while held")
            record(setup, "span-my shots: \(base): not settled while held; state=\(stateLabel(app))")
            return
        }
        Thread.sleep(forTimeInterval: photoWait)
        let titleBefore = element(app, "page.title").label
        let statusBottom = element(app, "span.state").frame.minY
        let first = takePhoto(app, setup, file: "\(base)-before.png", turned: false)
        // Still held and not shifted after the photo (a version may move without a shift: the now line's 30 s, C3-m5).
        let held = fields(stateLabel(app))
        if held["hold"] != "on" || held["shifts"] != before.state["shifts"] {
            XCTFail("\(base): the window shifted while 'before' was taken (hold=\(held["hold"] ?? "?"), shifts=\(held["shifts"] ?? "?"))")
        }
        // The tap releases the hold (C3-M4); the hold's 60 s ceiling releases it too, so a tap that missed only takes longer.
        let release = element(app, "span.release")
        if release.waitForExistence(timeout: 10) || release.exists {
            release.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            XCTFail("\(base): no span.release")
        }
        var released = "timer"
        if waitForStateCounted(app, timeout: 5, { $0["hold"] == "off" }) != nil { released = "tap" }
        guard waitForStateCounted(app, timeout: 75, { $0["shifts"] == "1" && $0["hold"] == "off" }) != nil,
              let after = settledCounted(app), after.state["shifts"] == "1" else {
            XCTFail("\(base): the window never shifted once (state \(stateLabel(app)))")
            record(setup, "span-my shots: \(base): no shift; state=\(stateLabel(app))")
            return
        }
        Thread.sleep(forTimeInterval: photoWait)
        let titleAfter = element(app, "page.title").label
        let second = takePhoto(app, setup, file: "\(base)-after.png", turned: false)
        let window = app.windows.firstMatch.frame
        let scale = window.width > 0 && first.pixelWidth > 0 ? CGFloat(first.pixelWidth) / window.width : 0
        let canvasTop = max(before.frame.minY, after.frame.minY)
        let strict = Int((canvasTop * scale).rounded(.up)) + 1
        let loose = max(0, Int((statusBottom * scale).rounded(.up)) - 1)
        let band = before.frame == after.frame ? "same" : "moved"
        if scale <= 0 { XCTFail("\(base): the photo's scale is unknown") }
        for (step, view) in [("before", before), ("after", after)] {
            let zoom = view.probe["zoom"].flatMap { Double($0) } ?? 0
            let top = zoom > 0 ? (view.probe["oy"].flatMap { Double($0) } ?? 0) / zoom : 0
            record(setup, "span-my shots: \(base)-\(step) photo=\(step == "before" ? first.how : second.how) window=\(Self.text(window)) "
                + "frame=\(Self.text(view.frame)) zoom=\(view.probe["zoom"] ?? "?") ox=\(view.probe["ox"] ?? "?") oy=\(view.probe["oy"] ?? "?") "
                + "top=\(Self.number(top)) across=\(Self.number(zoom * Self.monthWidth)) pages=\(view.state["pages"] ?? "?") "
                + "state=\(view.stateRaw) probe=\(view.raw)")
            record(setup, "span cap: device=\(setup.device) kind=\(base)-\(step) pages=\(view.state["pages"] ?? "?") top=\(Self.number(top))lu")
        }
        record(setup, "span-my shots: \(base) title=\(titleBefore) | \(titleAfter) before=\(before.state["version"] ?? "?") "
            + "after=\(after.state["version"] ?? "?") focus=\(before.state["focus"] ?? "?")→\(after.state["focus"] ?? "?") first=\(before.state["first"] ?? "?")→\(after.state["first"] ?? "?")")
        record(setup, "span-my shift pair: device=\(setup.device) kind=month before=\(first.file) after=\(second.file) "
            + "strict=0-\(strict) loose=0-\(loose) scale=\(Self.number(scale)) canvas=\(Self.text(before.frame))|\(Self.text(after.frame)) "
            + "band=\(band) title=\(titleBefore == titleAfter ? "same" : "changed") released=\(released)")
    }

    // MARK: The photos

    /// One photo of the joined month: the window open (`span.state`'s `path=span`, `kind=month`) and settled; with `fit` the
    /// zoom checked against one page's width across the canvas.
    private func monthPhoto(_ setup: Setup, name: String, orientation: UIDeviceOrientation, arguments: [String], fit: Bool = false) {
        XCUIDevice.shared.orientation = orientation
        let app = launch(arguments)
        defer { app.terminate() }
        if waitForState(app, timeout: 45, { $0["path"] == "span" && $0["kind"] == "month" }) == nil {
            XCTFail("\(name): span.state never read path=span with kind=month: \(stateLabel(app))")
        }
        let view = settled(app)
        if view == nil { XCTFail("\(name): the canvas never settled") }
        Thread.sleep(forTimeInterval: photoWait)
        let photo = takePhoto(app, setup, file: "\(name).png", turned: orientation != .portrait)
        let zoom = view?.probe["zoom"].flatMap { Double($0) } ?? 0
        let width = Double(view?.frame.width ?? 0)
        let across = zoom * Self.monthWidth
        record(setup, "span-my shots: \(name) photo=\(photo.how) window=\(Self.text(app.windows.firstMatch.frame)) "
            + "frame=\(Self.text(view?.frame ?? .zero)) zoom=\(view?.probe["zoom"] ?? "?") across=\(Self.number(across)) "
            + "state=\(stateLabel(app)) probe=\(view?.raw ?? "-")")
        if fit, abs(across - width) > Self.fitTolerance {
            XCTFail("\(name): one page is \(Self.number(across)) pt across a canvas \(Self.number(width)) pt wide: not at fit")
        }
    }

    // MARK: Taking a photo

    /// Writes `file` (a path under the output folder). Portrait: the app's screenshot. Turned: the job's simulator photo,
    /// else the app's screenshot (`photo=xcui`).
    private func takePhoto(_ app: XCUIApplication, _ setup: Setup, file: String, turned: Bool) -> Photo {
        let url = setup.out.appendingPathComponent(file)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if turned, simulatorPhoto(file) {
            let width = UIImage(contentsOfFile: url.path)?.cgImage?.width ?? 0
            return Photo(file: file, how: "simctl", pixelWidth: width)
        }
        let shot = app.screenshot()
        let png = shot.pngRepresentation
        do {
            try png.write(to: url)
        } catch {
            XCTFail("\(file): the PNG was not written: \(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = file
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
        return Photo(file: file, how: "xcui", pixelWidth: UIImage(data: png)?.cgImage?.width ?? 0)
    }

    /// Asks the job for `simctl io screenshot` of the simulator, written to `file` and stood up: a request file in
    /// `TEGAKI_SPAN_MY_SHOT_REQUESTS` (written whole, then renamed) and the job's answer `<request>.done` ("ok" or
    /// "failed"). False without the folder, or without an answer in 90 s.
    private func simulatorPhoto(_ file: String) -> Bool {
        guard let path = ProcessInfo.processInfo.environment["TEGAKI_SPAN_MY_SHOT_REQUESTS"], !path.isEmpty else { return false }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let request = folder.appendingPathComponent(file.replacingOccurrences(of: "/", with: "_") + ".request")
        let done = URL(fileURLWithPath: request.path + ".done")
        try? FileManager.default.removeItem(at: done)
        guard (try? Data("\(file)\n270\n".utf8).write(to: request, options: .atomic)) != nil else { return false }
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if let answer = try? String(contentsOf: done, encoding: .utf8) {
                try? FileManager.default.removeItem(at: done)
                return answer.hasPrefix("ok")
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        try? FileManager.default.removeItem(at: request)
        return false
    }

    // MARK: Reading the screen

    private func setup() throws -> Setup {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["TEGAKI_SPAN_MY_SHOT_OUT"], !out.isEmpty, let device = env["TEGAKI_SPAN_MY_SHOT_DEVICE"], !device.isEmpty else {
            throw XCTSkip("only in a job that takes the joined months' photos")
        }
        let folder = URL(fileURLWithPath: out, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return Setup(out: folder, device: device)
    }

    /// `TEGAKI_SPAN_MY_VARIANTS` read: `name:arguments` pieces split on "|", the arguments on spaces; a piece without a name
    /// or a ":" is left out. None (or nothing readable): one variant without a name and without arguments.
    private static func variants() -> [Variant] {
        let text = ProcessInfo.processInfo.environment["TEGAKI_SPAN_MY_VARIANTS"] ?? ""
        let read: [Variant] = text.split(separator: "|").compactMap { piece in
            guard let colon = piece.firstIndex(of: ":") else { return nil }
            let name = piece[..<colon].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
            let arguments = piece[piece.index(after: colon)...].split(separator: " ").map(String.init)
            return Variant(name: name, arguments: arguments)
        }
        return read.isEmpty ? [Variant(name: "", arguments: [])] : read
    }

    /// One launch in screenshot mode on 2026-10 (the 7th, a Wednesday) with the probe, in Japanese unless `language` says
    /// (D1b's guide cards).
    private func launch(_ arguments: [String], language: [String]? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe"] + arguments
            + (language ?? Self.japanese)
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func stateLabel(_ app: XCUIApplication) -> String {
        let state = element(app, "span.state")
        return state.exists ? state.label : "-"
    }

    /// `span.state`'s fields once `condition` holds, read every 0.4 s; nil at the timeout.
    private func waitForState(_ app: XCUIApplication, timeout: TimeInterval, _ condition: ([String: String]) -> Bool) -> [String: String]? {
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if state.exists {
                let read = fields(state.label)
                if condition(read) { return read }
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return nil
    }

    /// The canvas once two reads 0.5 s apart agree on the probe's zoom and offset, the canvas's frame and `span.state`'s
    /// path, window, version, hold and shifts (the window composed and its neighbours read). nil at the timeout.
    private func settled(_ app: XCUIApplication, timeout: TimeInterval = 30) -> Settled? {
        let canvas = element(app, "ink-canvas")
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        var last: Settled?
        while Date() < deadline {
            if canvas.exists, let raw = canvas.value as? String, Double(fields(raw)["zoom"] ?? "") ?? 0 > 0, state.exists {
                let frame = canvas.frame
                if frame.width > 0 {
                    let now = Settled(probe: fields(raw), raw: raw, frame: frame, state: fields(state.label))
                    if let previous = last, Self.same(previous, now) { return now }
                    last = now
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    private static func same(_ a: Settled, _ b: Settled) -> Bool {
        a.frame == b.frame
            && ["zoom", "ox", "oy", "ph"].allSatisfy { a.probe[$0] == b.probe[$0] }
            && ["path", "session", "kind", "focus", "first", "pages", "version", "hold", "shifts"].allSatisfy { a.state[$0] == b.state[$0] }
    }

    /// D1b: `span.state`'s fields once `condition` holds, read every 0.4 s; the deadline is `timeout` s, read once more after
    /// it, and at least `reads` reads in all (docs/R1_4_1.md :463, R1_4_2_CONTRACT §1.5). nil otherwise.
    private func waitForStateCounted(_ app: XCUIApplication, timeout: TimeInterval, reads: Int = 6,
                                     _ condition: ([String: String]) -> Bool) -> [String: String]? {
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        var count = 0
        var pastDeadline = false
        while true {
            count += 1
            if state.exists {
                let read = fields(state.label)
                if condition(read) { return read }
            }
            if pastDeadline, count >= reads { return nil }
            if Date() >= deadline { pastDeadline = true }
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// D1b: the canvas at rest as `settled` reads it (two reads 0.5 s apart agree on the probe's zoom, offset and height,
    /// the canvas's frame and `span.state`'s window), the deadline read once more after it and at least `reads` reads in
    /// all; nil otherwise.
    private func settledCounted(_ app: XCUIApplication, timeout: TimeInterval = 30, reads: Int = 8) -> Settled? {
        let canvas = element(app, "ink-canvas")
        let state = element(app, "span.state")
        let deadline = Date().addingTimeInterval(timeout)
        var last: Settled?
        var count = 0
        var pastDeadline = false
        while true {
            count += 1
            var now: Settled?
            if canvas.exists, let raw = canvas.value as? String, Double(fields(raw)["zoom"] ?? "") ?? 0 > 0, state.exists {
                let frame = canvas.frame
                let label = state.label
                if frame.width > 0 {
                    now = Settled(probe: fields(raw), raw: raw, frame: frame, state: fields(label), stateRaw: label)
                }
            }
            if let now, let previous = last, Self.same(previous, now) { return now }
            last = now
            if pastDeadline, count >= reads { return nil }
            if Date() >= deadline { pastDeadline = true }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// D1b: two canvas frames alike within `paperTolerance` in each of their four numbers (§12.3's paper area).
    private static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= paperTolerance && abs(a.minY - b.minY) <= paperTolerance
            && abs(a.width - b.width) <= paperTolerance && abs(a.height - b.height) <= paperTolerance
    }

    /// `key=value` pairs joined by `;` (the probe and `span.state`).
    private func fields(_ raw: String) -> [String: String] {
        var values: [String: String] = [:]
        for part in raw.split(separator: ";") {
            guard let equals = part.firstIndex(of: "=") else { continue }
            values[String(part[..<equals])] = String(part[part.index(after: equals)...])
        }
        return values
    }

    // MARK: Writing

    /// A line for the job: printed and logged, and appended to `<out>/lines/<device>.txt`.
    private func record(_ setup: Setup, _ line: String) {
        print(line)
        NSLog("%@", line)
        let folder = setup.out.appendingPathComponent("lines", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(setup.device).txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }

    private static func name(_ orientation: UIDeviceOrientation) -> String {
        orientation == .portrait ? "portrait" : "landscape"
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func number(_ value: CGFloat) -> String {
        number(Double(value))
    }

    /// "x,y,w,h" with one decimal (no spaces: the job splits the lines on them).
    private static func text(_ rect: CGRect) -> String {
        [rect.minX, rect.minY, rect.width, rect.height].map { number($0) }.joined(separator: ",")
    }
}
