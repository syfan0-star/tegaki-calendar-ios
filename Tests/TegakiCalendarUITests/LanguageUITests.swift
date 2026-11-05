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
