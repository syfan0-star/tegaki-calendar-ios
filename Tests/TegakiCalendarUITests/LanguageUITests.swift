import XCTest

/// Which language iOS really picks for the app, the country of the automatic holidays and the region's
/// week start (docs/M7B_CONTRACT.md §7.3, §10.8, J-8, J-10). The app runs in its screenshot mode, whose
/// `l10n.state` element reads out "ui=<lang>;locale=<id>;holidays=<id>;week=<monday|sunday>". A `.lproj`
/// named a little wrong would give that language's people English without a word, which no other check
/// sees (`LocalizationBundleTests` looks inside the folders, not at what iOS chooses). The steps are the
/// `l10n UI:` lines of the CI's log.
@MainActor
final class LanguageUITests: XCTestCase {
    /// One launch; `languages` is the device's list, `locale` the region.
    private func launch(_ languages: [String], _ locale: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-page", "month",
            "-AppleLanguages", "(" + languages.joined(separator: ", ") + ")", "-AppleLocale", locale,
        ] + extra
        app.launch()
        log("launched (\(languages.joined(separator: ", "))) \(locale) \(extra.joined(separator: " "))")
        return app
    }

    /// "ui=en;locale=en_US;holidays=US|en;week=sunday" → its four values.
    private func state(of app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> [String: String] {
        let element = app.otherElements["l10n.state"]
        guard element.waitForExistence(timeout: 30) else {
            XCTFail("no l10n.state element", file: file, line: line)
            return [:]
        }
        XCTAssertEqual(element.identifier, "l10n.state", file: file, line: line)
        log("state: \(element.label)")
        var values: [String: String] = [:]
        for part in element.label.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 { values[String(pair[0])] = String(pair[1]) }
        }
        return values
    }

    private func penLabel(of app: XCUIApplication) -> String {
        let pen = app.buttons["tool.pen"]
        XCTAssertTrue(pen.waitForExistence(timeout: 20), "the toolbar's pen")
        return pen.label
    }

    private func titleLabel(of app: XCUIApplication) -> String {
        let title = app.descendants(matching: .any).matching(identifier: "page.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20), "the page's title")
        return title.label
    }

    private func language(_ languages: [String], _ locale: String) -> String? {
        let app = launch(languages, locale)
        defer { app.terminate() }
        return state(of: app)["ui"]
    }

    // MARK: Tests

    /// J-8: a Japanese device stays Japanese.
    func testJapaneseStaysJapanese() {
        let app = launch(["ja"], "ja_JP")
        defer { app.terminate() }
        let values = state(of: app)
        XCTAssertEqual(values["ui"], "ja")
        XCTAssertEqual(values["holidays"], "JP|ja")
        XCTAssertEqual(penLabel(of: app), "ペン")
        XCTAssertEqual(titleLabel(of: app), "2026年10月")
    }

    func testEnglish() {
        let app = launch(["en"], "en_US")
        defer { app.terminate() }
        XCTAssertEqual(state(of: app)["ui"], "en")
        XCTAssertEqual(penLabel(of: app), "Pen")
        // An iPhone's title is the compact one (§3.1, `yMMM`). The written-out "October 2026" is the
        // iPad's, which the photos show (§8, step 8). Not compared whole: ICU may choose its own space.
        let title = titleLabel(of: app)
        XCTAssertTrue(title.hasPrefix("Oct"), title)
        XCTAssertFalse(title.hasPrefix("October"), title)
        XCTAssertTrue(title.contains("2026"), title)
    }

    /// O-1: any other language is English, not Japanese, and the Buddhist year stays out (0-11).
    func testUnsupportedLanguageFallsBackToEnglish() {
        let app = launch(["th"], "th_TH")
        defer { app.terminate() }
        XCTAssertEqual(state(of: app)["ui"], "en")
        XCTAssertEqual(penLabel(of: app), "Pen")
        let title = titleLabel(of: app)
        XCTAssertTrue(title.contains("2026"), title)
        XCTAssertFalse(title.contains("2569"), title)
    }

    /// 0-1: a later language of the device's list is taken before the fallback.
    func testSecondPreferredLanguageWins() {
        XCTAssertEqual(language(["ru", "ja"], "ru_RU"), "ja")
    }

    /// 0-2: the regional variants share one `.lproj`.
    func testRegionalVariants() {
        let cases: [(String, String, String)] = [
            ("zh-HK", "zh_HK", "zh-Hant"), ("pt-PT", "pt_PT", "pt-BR"), ("es-MX", "es_MX", "es"), ("es-419", "es_419", "es"),
            ("fr-CA", "fr_CA", "fr"), ("de-CH", "de_CH", "de"), ("it-CH", "it_CH", "it"),
        ]
        for (device, locale, expected) in cases {
            XCTAssertEqual(language([device], locale), expected, device)
        }
    }

    func testRightToLeftFallsBackToEnglish() {
        XCTAssertEqual(language(["ar"], "ar_SA"), "en")
        XCTAssertEqual(language(["he"], "he_IL"), "en")
    }

    func testAutomaticHolidaysFollowTheRegion() {
        for (device, locale, expected) in [("en", "en_US", "US|en"), ("ja", "ja_JP", "JP|ja")] {
            let app = launch([device], locale, extra: ["--screenshot-holidays", "auto"])
            defer { app.terminate() }
            XCTAssertEqual(state(of: app)["holidays"], expected, locale)
        }
    }

    /// Every language by its base name: the `l10n-shots` job does not fail and the bundle test does not
    /// ask iOS, so this is the proof that each of the nine is chosen.
    func testEveryLanguageIsChosen() {
        let cases: [(String, String, String)] = [
            ("zh-Hans", "zh_CN", "zh-Hans"), ("ko", "ko_KR", "ko"), ("pt-BR", "pt_BR", "pt-BR"), ("de", "de_DE", "de"), ("fr", "fr_FR", "fr"),
            ("es", "es_ES", "es"), ("it", "it_IT", "it"), ("zh-Hant", "zh_TW", "zh-Hant"), ("en-GB", "en_GB", "en"),
        ]
        for (device, locale, expected) in cases {
            XCTAssertEqual(language([device], locale), expected, device)
        }
    }

    /// J-10, 0-44: the region's first day on iOS; Japan is Monday by the owner's decision, Egypt's
    /// Saturday reads as Monday.
    func testWeekStartFollowsTheRegion() {
        let cases: [(String, String, String)] = [("en", "en_US", "sunday"), ("en", "en_GB", "monday"), ("ja", "ja_JP", "monday"), ("en", "en_EG", "monday")]
        for (device, locale, expected) in cases {
            let app = launch([device], locale, extra: ["--screenshot-week-start", "auto"])
            defer { app.terminate() }
            XCTAssertEqual(state(of: app)["week"], expected, locale)
        }
    }

    /// 0-46: the photos do not depend on the simulator's region.
    func testWeekStartIsMondayWithoutTheArgument() {
        let app = launch(["en"], "en_US")
        defer { app.terminate() }
        XCTAssertEqual(state(of: app)["week"], "monday")
    }

    /// App Review 3.1.2 (docs/M7B_CONTRACT.md §8, step 8): on an iPhone the purchase sheet of the longest
    /// language is taller than the screen, so `PaywallSheet.content` scrolls it. Sending it to the end
    /// must reach the renewal text, restore, the terms, the privacy policy and the EULA, in German, on the
    /// screen and hittable. A person at the top of the sheet does not see them; the photo of the job
    /// `l10n-shots` only shows the top, so the two screenshots this keeps are the record of the bottom.
    func testGermanPaywallReachesItsLinks() {
        let app = launch(["de"], "de_DE", extra: ["--screenshot-sheet", "paywall"])
        defer { app.terminate() }
        let restore = app.buttons["paywall.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 30), "the purchase sheet is up")
        keepScreenshot(app, "paywall-de-top")

        let links: [(id: String, label: String)] = [
            ("paywall.restore", "Käufe wiederherstellen"),
            ("paywall.terms", "Nutzungsbedingungen des Dienstes"),
            ("paywall.privacy", "Datenschutzerklärung"),
            ("paywall.eula", "Nutzungsbedingungen (Apple Standard-EULA)"),
            ("paywall.laterBottom", "Später"),
        ]
        let buttons = links.map { app.buttons[$0.id] }
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(screen.height, 0, "the window")
        func reached(_ element: XCUIElement) -> Bool { element.isHittable && screen.contains(element.frame) }
        var drags = 0
        while drags < 6, !buttons.allSatisfy(reached) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
            drags += 1
        }
        log("paywall: \(drags) drags, window \(screen)")
        keepScreenshot(app, "paywall-de-bottom")
        for (link, button) in zip(links, buttons) {
            log("paywall: \(link.id) \"\(button.label)\" at \(button.frame) hittable=\(button.isHittable)")
            XCTAssertTrue(button.exists, link.id)
            XCTAssertEqual(button.label, link.label, link.id)
            XCTAssertTrue(button.isHittable, "\(link.id) can be tapped")
            XCTAssertTrue(screen.contains(button.frame), "\(link.id) lies on the screen: \(button.frame)")
        }
        let disclosure = app.staticTexts["paywall.disclosure"]
        log("paywall: the renewal text at \(disclosure.frame): \(disclosure.label)")
        XCTAssertTrue(disclosure.exists, "the renewal text")
        XCTAssertTrue(screen.contains(disclosure.frame), "the renewal text lies on the screen: \(disclosure.frame)")
        XCTAssertTrue(disclosure.label.hasPrefix("Das Abo verlängert sich automatisch."), disclosure.label)
    }

    // MARK: 1.4.2: l10n-shots' photos of the memo paper's row and the colour panel

    /// 1.4.2 (docs/R1_4_2_CONTRACT.md §6.2, §7.3; docs/R1_4_2.md, D1b's decision (m), sent to D2): the photos of the l10n-shots
    /// job that only XCUI can take, on its iPhone 17. The job passes the folder of its photos (`TEST_RUNNER_TEGAKI_L10N_SHOT_OUT`,
    /// its shots/l10n) and the string catalogue (`TEST_RUNNER_TEGAKI_L10N_SHOT_STRINGS`); anywhere else the test skips itself
    /// (the UI test step on the iPhone counts it as skipped). Screenshot mode, where nothing is stored, and nothing is chosen:
    /// a row and the panel are only opened (neither `MemoPaperSettingsSection.changed` nor `ColorPanelStore.apply` runs; the
    /// panel's dots live in screenshot mode's scratch store). 17 photos in 14 launches:
    ///
    /// - `<language>/iphone-portrait-sheet-settings-memo-paper.png`, the ten languages and `pseudo/` (11): 設定 › 「メモ欄の紙」
    ///   and its footnote. The settings sheet (`--screenshot-sheet settings`) is dragged until the row (`settings.memoPaper`)
    ///   lies in the upper part of the screen under the sheet's bar and its footnote above the screen's bottom, as
    ///   MemoPaperUITests moves it (`--screenshot-settings-section` keeps its one case).
    /// - `{de,fr,pseudo}/iphone-portrait-sheet-memo-paper-choices.png` (3): in the same launch, the row tapped: its own screen
    ///   with 罫線・ドット方眼・無地, none chosen.
    /// - `{de,fr,pseudo}/iphone-portrait-week-color-panel.png` (3): the week page, its lit dot (the `toolbar.swatch.<n>` that is
    ///   selected: the first at a launch in screenshot mode) tapped as ColorPanelUITests does, then the panel
    ///   (`toolbar.colorPanel`) with its twelve colours, 「その他の色…」 (`toolbar.colorPanel.other`) and 「最初の色に戻す」
    ///   (`toolbar.colorPanel.reset`).
    ///
    /// Each language with its region's holidays and week start, as the job's other photos; `pseudo/` is English with every
    /// text doubled (`-NSDoubleLocalizedStrings YES`). With the catalogue, the row's title and value, the footnote, the three
    /// choices and the panel's two rows are looked for by their words (their first characters, so the doubled words match
    /// too). A photo is written whatever a check finds; a check that failed fails the test, which is a warning of the job
    /// only. The waits read once more after their deadline. The steps are the `l10n UI:` lines.
    func testLocalizedShotsOfTheMemoPaperAndTheColourPanel() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["TEGAKI_L10N_SHOT_OUT"], !path.isEmpty else {
            throw XCTSkip("only in the l10n-shots job (TEST_RUNNER_TEGAKI_L10N_SHOT_OUT)")
        }
        let out = URL(fileURLWithPath: path, isDirectory: true)
        let catalogue = Self.shotCatalogue(environment["TEGAKI_L10N_SHOT_STRINGS"])
        log("shots: into \(out.path); the string catalogue: \(catalogue.isEmpty ? "not given, no words checked" : "\(catalogue.count) keys")")
        var written = 0
        for (language, region) in Self.shotLanguages {
            let arguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", region,
                             "--screenshot-holidays", "auto", "--screenshot-week-start", "auto"]
            written += settingsShots(out, folder: language, arguments: arguments, words: ShotWords(catalogue, language),
                                     choices: Self.chooserFolders.contains(language))
        }
        written += settingsShots(out, folder: "pseudo", arguments: Self.pseudoArguments, words: ShotWords(catalogue, "en"), choices: true)
        for (language, region) in Self.shotLanguages where Self.chooserFolders.contains(language) {
            let arguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", region,
                             "--screenshot-holidays", "auto", "--screenshot-week-start", "auto"]
            written += panelShot(out, folder: language, arguments: arguments, words: ShotWords(catalogue, language))
        }
        written += panelShot(out, folder: "pseudo", arguments: Self.pseudoArguments, words: ShotWords(catalogue, "en"))
        log("shots: \(written) photos written (\(Self.expectedShots) expected)")
        XCTAssertEqual(written, Self.expectedShots, "the photos written")
    }

    /// The ten languages with the regions of l10n-shots (`LANGS`, and Japanese in Japan).
    private static let shotLanguages: [(language: String, region: String)] = [
        ("ja", "ja_JP"), ("en", "en_US"), ("zh-Hans", "zh_CN"), ("zh-Hant", "zh_TW"), ("ko", "ko_KR"),
        ("fr", "fr_FR"), ("de", "de_DE"), ("it", "it_IT"), ("es", "es_MX"), ("pt-BR", "pt_BR"),
    ]
    /// The languages of the chooser's and the panel's photos, with `pseudo/` (§7.3: de, fr and the pseudo language).
    private static let chooserFolders: Set<String> = ["de", "fr"]
    /// l10n-shots' pseudo language: English, every text of the Bundle doubled.
    private static let pseudoArguments = ["-AppleLanguages", "(en)", "-NSDoubleLocalizedStrings", "YES"]
    /// 11 rows, 3 choosers, 3 panels.
    private static let expectedShots = 17
    /// The keys whose words the photos are checked by.
    private static let shotKeys = [
        "settings.memoPaper.title", "settings.memoPaper.footer", "settings.memoPaper.ruled", "settings.memoPaper.dots",
        "settings.memoPaper.plain", "settings.done", "toolbar.colorPanel.title", "toolbar.colorPanel.otherColor",
        "toolbar.colorPanel.reset",
    ]

    /// The words of one language, from the catalogue (nil, or no choices, without it).
    private struct ShotWords {
        /// The settings sheet's 「完了」.
        let done: String?
        let title: String?
        let footer: String?
        /// 罫線・ドット方眼・無地, or empty.
        let choices: [String]
        let panel: String?
        let other: String?
        let reset: String?

        init(_ catalogue: [String: [String: String]], _ language: String) {
            func word(_ key: String) -> String? { catalogue[key]?[language] }
            done = word("settings.done")
            title = word("settings.memoPaper.title")
            footer = word("settings.memoPaper.footer")
            let names = ["ruled", "dots", "plain"].compactMap { word("settings.memoPaper.\($0)") }
            choices = names.count == 3 ? names : []
            panel = word("toolbar.colorPanel.title")
            other = word("toolbar.colorPanel.otherColor")
            reset = word("toolbar.colorPanel.reset")
        }
    }

    /// One launch of the settings sheet: the row and its footnote, then (`choices`) the row's own screen. The photos written.
    private func settingsShots(_ out: URL, folder: String, arguments: [String], words: ShotWords, choices: Bool) -> Int {
        let name = "\(folder)/iphone-portrait-sheet-settings-memo-paper.png"
        let app = shotLaunch(["--screenshot-page", "month", "--screenshot-sheet", "settings"] + arguments)
        defer { app.terminate() }
        // The sheet's 「完了」 (by its word), or the row itself once it is in the tree; without the words, 5 s.
        let done = words.done.map { app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", $0)).firstMatch }
        let up = shotWait(done == nil ? 5 : 30) {
            app.buttons.matching(identifier: "settings.memoPaper").firstMatch.exists || (done?.exists ?? false)
        }
        if !up, done != nil { XCTFail("\(name): the settings sheet did not come") }
        let window = app.windows.firstMatch.frame
        let footer = words.footer.map { text in
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", String(text.prefix(12)))).firstMatch
        }
        // The row under the sheet's bar (its top 140 pt) and in the upper 60 % of the screen, so that its footnote (at most
        // about 130 pt, the pseudo language's) lies above the screen's bottom: checked after the photo, not waited for (a
        // footnote not found by its words would only drag the sheet back and forth).
        var row = memoRow(app, title: words.title)
        var placed = false
        for attempt in 1...12 {
            row = memoRow(app, title: words.title)
            let above = row.exists && row.frame.minY < window.minY + 140
            if row.exists, row.isHittable, !above, row.frame.maxY <= window.minY + window.height * 0.6 {
                placed = true
                break
            }
            let (from, to): (CGFloat, CGFloat) = above ? (0.45, 0.65) : (0.75, 0.45)
            shotDrag(app, from: CGPoint(x: window.midX, y: window.minY + window.height * from),
                     to: CGPoint(x: window.midX, y: window.minY + window.height * to), velocity: 600)
            log("\(name): moved the settings \(above ? "down" : "up") (attempt \(attempt)); the row "
                + "\(row.exists ? shotRect(row.frame) : "not in the tree yet")")
        }
        if !placed { row = memoRow(app, title: words.title) }
        if row.exists { _ = shotStableFrame(of: row) }
        Thread.sleep(forTimeInterval: 1)
        var written = shotPhoto(app, out, name) ? 1 : 0
        let shown = shotText(row)
        let footerFrame = footer.map { $0.exists ? shotRect($0.frame) : "-" } ?? "not checked"
        let footerShown = footer.map { $0.exists && row.exists && $0.frame.minY >= row.frame.minY && $0.frame.maxY <= window.maxY - 24 } ?? true
        log("\(name): row \(row.exists ? shotRect(row.frame) : "-") \"\(shown)\" footnote \(footerFrame) placed=\(placed) "
            + "footnote-shown=\(footer == nil ? "not checked" : "\(footerShown)") window \(shotRect(window))")
        XCTAssertTrue(placed, "\(name): the row in the upper part of the sheet (row \(shown))")
        XCTAssertTrue(footerShown, "\(name): the footnote below the row and on the screen (\(footerFrame))")
        if let title = words.title { XCTAssertTrue(shown.contains(title), "\(name): the row's title \(title): \(shown)") }
        if let ruled = words.choices.first { XCTAssertTrue(shown.contains(ruled), "\(name): the row shows \(ruled): \(shown)") }
        guard choices else { return written }

        let chooser = "\(folder)/iphone-portrait-sheet-memo-paper-choices.png"
        guard row.exists, row.isHittable else {
            XCTFail("\(chooser): the row cannot be tapped")
            return written
        }
        row.tap()
        let listed: Bool
        if words.choices.isEmpty {
            // No words to look for: the row left the screen (its list was pushed over it).
            listed = shotWait(10) { !row.exists || !row.isHittable }
        } else {
            // Each poll picks the button or the text again (a list not up yet would leave texts).
            listed = shotWait(10) { words.choices.allSatisfy { self.shotOption(app, $0).exists } }
        }
        if let first = words.choices.first, listed {
            _ = shotStableFrame(of: shotOption(app, first))
        }
        Thread.sleep(forTimeInterval: 1)
        if shotPhoto(app, out, chooser) { written += 1 }
        let frames = words.choices.map { "\($0) \(shotOption(app, $0).exists ? shotRect(shotOption(app, $0).frame) : "-")" }
        log("\(chooser): listed=\(listed) \(frames.joined(separator: ", "))")
        XCTAssertTrue(listed, "\(chooser): the row's screen with its three choices")
        return written
    }

    /// One launch of the week page: its lit dot tapped, the panel photographed. 1 when the photo was written.
    private func panelShot(_ out: URL, folder: String, arguments: [String], words: ShotWords) -> Int {
        let name = "\(folder)/iphone-portrait-week-color-panel.png"
        let app = shotLaunch(["--screenshot-page", "week"] + arguments)
        defer { app.terminate() }
        let canvas = app.descendants(matching: .any).matching(identifier: "ink-canvas").firstMatch
        if !canvas.waitForExistence(timeout: 30) { XCTFail("\(name): no canvas") }
        shotSettle(canvas)
        let l10n = app.otherElements["l10n.state"]
        let language = l10n.waitForExistence(timeout: 5) ? l10n.label : "-"
        var lit: XCUIElement?
        _ = shotWait(10) {
            lit = (0..<6).map { app.buttons["toolbar.swatch.\($0)"] }.first { $0.exists && $0.isSelected }
            return lit != nil
        }
        let window = app.windows.firstMatch.frame
        let panel = app.descendants(matching: .any).matching(identifier: "toolbar.colorPanel").firstMatch
        var opened = false
        if let lit {
            revealDot(lit, in: app, window: window, name: name)
            // Its identifier and frame read before the tap (open, the panel is modal and may hide the bar).
            log("\(name): \(language); the lit dot \(lit.identifier) \"\(lit.label)\" at \(shotRect(lit.frame))")
            Thread.sleep(forTimeInterval: 0.5)
            lit.tap()
            opened = panel.waitForExistence(timeout: 10)
            if opened { _ = shotStableFrame(of: panel) }
        } else {
            log("\(name): \(language); no lit dot")
            XCTFail("\(name): no lit dot (toolbar.swatch.0–5 selected): the pen is not the tool")
        }
        Thread.sleep(forTimeInterval: 1)
        let wrote = shotPhoto(app, out, name)
        let other = app.buttons["toolbar.colorPanel.other"]
        let reset = app.buttons["toolbar.colorPanel.reset"]
        let inside = panel.exists && window.contains(panel.frame)
        log("\(name): panel \(panel.exists ? shotRect(panel.frame) : "-") \"\(panel.exists ? panel.label : "-")\" inside=\(inside); "
            + "other \"\(other.exists ? other.label : "-")\" \(other.exists ? shotRect(other.frame) : "-"); "
            + "reset \"\(reset.exists ? reset.label : "-")\" \(reset.exists ? shotRect(reset.frame) : "-")")
        XCTAssertTrue(opened, "\(name): the lit dot opened the panel")
        XCTAssertTrue(inside, "\(name): the panel lies in the window")
        for (element, word, what) in [(other, words.other, "toolbar.colorPanel.other"), (reset, words.reset, "toolbar.colorPanel.reset")] {
            guard let word else { continue }
            let read = element.exists ? element.label : "-"
            XCTAssertTrue(read.hasPrefix(String(word.prefix(12))), "\(name): \(what) reads \(word): \(read)")
        }
        if let title = words.panel, panel.exists {
            XCTAssertTrue(panel.label.hasPrefix(String(title.prefix(12))), "\(name): the panel's name \(title): \(panel.label)")
        }
        return wrote ? 1 : 0
    }

    /// One launch in screenshot mode on 2026-10 (the 7th, a Wednesday) with the canvas's probe.
    private func shotLaunch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode", "--screenshot-month", "2026-10", "--screenshot-probe"] + arguments
        app.launch()
        log("shots: launched \(arguments.joined(separator: " "))")
        return app
    }

    /// The row: the button of its identifier, else the button whose label starts with its title (MemoPaperUITests' way).
    private func memoRow(_ app: XCUIApplication, title: String?) -> XCUIElement {
        let byId = app.buttons.matching(identifier: "settings.memoPaper").firstMatch
        guard let title, !byId.exists else { return byId }
        let byTitle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        return byTitle.exists ? byTitle : byId
    }

    /// A choice of the row's screen: a button whose label starts with it, else a text.
    private func shotOption(_ app: XCUIApplication, _ word: String) -> XCUIElement {
        let starts = NSPredicate(format: "label BEGINSWITH %@", word)
        let button = app.buttons.matching(starts).firstMatch
        if button.exists { return button }
        return app.staticTexts.matching(starts).firstMatch
    }

    /// The bar's row dragged (slowly, held before the lift) until `dot` can be tapped clear of the bar's right end
    /// (「しまう」 and its fade, about 90 pt), at most 3 times (ColorPanelUITests' `reveal`, without its Japanese label).
    private func revealDot(_ dot: XCUIElement, in app: XCUIApplication, window: CGRect, name: String) {
        for attempt in 1...3 {
            guard dot.exists else { return }
            let frame = dot.frame
            let left = window.minX + 16
            let right = window.maxX - 90
            if dot.isHittable, frame.minX >= left, frame.maxX <= right { return }
            let dx = frame.maxX > right ? -min(frame.maxX - right + 24, window.width * 0.5) : min(left - frame.minX + 24, window.width * 0.5)
            let startX = dx < 0 ? window.minX + window.width * 0.6 : window.minX + window.width * 0.2
            shotDrag(app, from: CGPoint(x: startX, y: frame.midY), to: CGPoint(x: startX + dx, y: frame.midY), velocity: 300)
            log("\(name): moved the bar's row by \(dx) pt (attempt \(attempt); the dot was at \(shotRect(frame)))")
        }
    }

    /// Writes the app's screenshot to `file` under `out` (and attaches it until the test passes). True when written.
    private func shotPhoto(_ app: XCUIApplication, _ out: URL, _ file: String) -> Bool {
        let url = out.appendingPathComponent(file)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = file
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
        let png = shot.pngRepresentation
        do {
            try png.write(to: url)
        } catch {
            XCTFail("\(file): the PNG was not written: \(error)")
            return false
        }
        log("shot: \(file) (\(png.count) bytes)")
        return true
    }

    /// The canvas's probe and frame read the same twice, 0.5 s apart (at most 15 s); it stops when the canvas left the tree.
    private func shotSettle(_ canvas: XCUIElement) {
        var last = ""
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            guard canvas.exists else { return }
            let now = "\(canvas.value as? String ?? "")|\(canvas.frame)"
            if now == last, !now.hasPrefix("|") { return }
            last = now
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// The element's frame once two reads 0.5 s apart agree (a sheet that slid in, a list that scrolled), up to 15 s.
    private func shotStableFrame(of element: XCUIElement) -> CGRect {
        var last = CGRect.null
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let frame = element.frame
            if frame == last { return frame }
            last = frame
            Thread.sleep(forTimeInterval: 0.5)
        }
        return last
    }

    /// Whether `condition` held within `seconds` (polled every 0.3 s), read once more after the deadline.
    private func shotWait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return condition()
    }

    /// One finger from `from` to `to` (screen points), 0.05 s still, then 0.3 s still at the end (no fling).
    private func shotDrag(_ app: XCUIApplication, from: CGPoint, to: CGPoint, velocity: CGFloat) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: from.x, dy: from.y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: to.x, dy: to.y)),
                   withVelocity: XCUIGestureVelocity(rawValue: velocity), thenHoldForDuration: 0.3)
    }

    /// The row's label and value, as VoiceOver reads them.
    private func shotText(_ element: XCUIElement) -> String {
        guard element.exists else { return "-" }
        return "\(element.label) \((element.value as? String) ?? "")"
    }

    /// "x,y,w,h" with one decimal.
    private func shotRect(_ rect: CGRect) -> String {
        [rect.minX, rect.minY, rect.width, rect.height].map { String(format: "%.1f", Double($0)) }.joined(separator: ",")
    }

    /// key → language → text, for `shotKeys`, from the string catalogue at `path` (Localizable.xcstrings); empty without it.
    private static func shotCatalogue(_ path: String?) -> [String: [String: String]] {
        guard let path, !path.isEmpty, let data = FileManager.default.contents(atPath: path),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else { return [:] }
        var table: [String: [String: String]] = [:]
        for key in shotKeys {
            guard let entry = strings[key] as? [String: Any], let localizations = entry["localizations"] as? [String: Any] else { continue }
            var texts: [String: String] = [:]
            for (language, value) in localizations {
                guard let unit = (value as? [String: Any])?["stringUnit"] as? [String: Any], let text = unit["value"] as? String else { continue }
                texts[language] = text
            }
            table[key] = texts
        }
        return table
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func log(_ line: String) {
        print("l10n UI: \(line)")
        NSLog("l10n UI: %@", line)
    }
}
