import Access
import InkModel
import XCTest
@testable import TegakiCalendar

/// 設定 › 購入 の純関数 (M5_CONTRACT §4.3 / §7.6): the plan line of the eight states, the date label of
/// the six states that have a date, the numeric date in ja_JP, the purchase button while read only,
/// and the footer's three branches. M6 (M6_CONTRACT §7.2): the data section's export paragraph.
/// 1.1 (M7A_CONTRACT §7.2): 「この端末」, the row of the eraser's return to the pen with its footer on an
/// iPhone and an iPad, and the two stroke-count rows of 情報 with their footer.
@MainActor
final class SettingsScreenTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private var later: Date { now.addingTimeInterval(30 * 86_400) }

    private var activeYearly: AccessState { .subscribed(Subscription(plan: .yearly, until: later, willAutoRenew: true, inGrace: false)) }
    private var cancelledMonthly: AccessState { .subscribed(Subscription(plan: .monthly, until: later, willAutoRenew: false, inGrace: false)) }
    private var graceYearly: AccessState { .subscribed(Subscription(plan: .yearly, until: later, willAutoRenew: true, inGrace: true)) }
    private var trialMonthly: AccessState { .trial(Trial(plan: .monthly, until: later, willAutoRenew: true)) }
    private var cancelledTrial: AccessState { .trial(Trial(plan: .yearly, until: later, willAutoRenew: false)) }
    private let reasons: [ReadOnlyReason] = [.notSubscribed, .expired, .billingRetry, .revoked, .unknown]

    func testPlanText() {
        XCTAssertEqual(SettingsScreen.planText(activeYearly), "年額・有効")
        XCTAssertEqual(SettingsScreen.planText(cancelledMonthly), "月額・有効", "cancelled but inside the paid period")
        XCTAssertEqual(SettingsScreen.planText(graceYearly), "年額・請求に問題（猶予中）")
        XCTAssertEqual(SettingsScreen.planText(trialMonthly), "月額・試用中")
        XCTAssertEqual(SettingsScreen.planText(cancelledTrial), "年額・試用中")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.notSubscribed)), "未購入（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.expired)), "期限切れ（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.billingRetry)), "お支払いに問題（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.revoked)), "返金済み（閲覧専用）")
        XCTAssertEqual(SettingsScreen.planText(.readOnly(.unknown)), "確認中（閲覧専用）")
        // The same words as the kit's (one source).
        let everyState = [activeYearly, cancelledMonthly, graceYearly, trialMonthly, cancelledTrial] + reasons.map({ AccessState.readOnly($0) })
        for access in everyState {
            XCTAssertEqual(SettingsScreen.planText(access), PlanText.statusTitle(access), "\(access)")
        }
    }

    func testDateLabel() {
        XCTAssertEqual(SettingsScreen.dateLabel(activeYearly), "次回更新")
        XCTAssertEqual(SettingsScreen.dateLabel(cancelledMonthly), "有効期限")
        XCTAssertEqual(SettingsScreen.dateLabel(graceYearly), "猶予の期限")
        XCTAssertEqual(SettingsScreen.dateLabel(.subscribed(Subscription(plan: .monthly, until: later, willAutoRenew: false, inGrace: true))), "猶予の期限", "the grace wins")
        XCTAssertEqual(SettingsScreen.dateLabel(trialMonthly), "試用の終了（有料に移行）")
        XCTAssertEqual(SettingsScreen.dateLabel(cancelledTrial), "試用の終了")
        for reason in reasons {
            XCTAssertNil(SettingsScreen.dateLabel(.readOnly(reason)), "\(reason): no date row")
            XCTAssertNil(AccessState.readOnly(reason).until)
        }
        XCTAssertEqual(activeYearly.until, later, "the date row shows `access.until`")
    }

    func testDateText() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)))
        XCTAssertEqual(SettingsScreen.dateText(date, locale: Locale(identifier: "ja_JP")), "2026/10/25")
        // No time, whatever the locale (the CI runs in English).
        let english = SettingsScreen.dateText(date, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(english.contains("2026"), english)
        XCTAssertTrue(english.contains("25"), english)
        XCTAssertFalse(english.contains(":"), english)
    }

    func testPurchaseButtonTitle() {
        XCTAssertEqual(SettingsScreen.purchaseButtonTitle(.readOnly(.notSubscribed), eligible: true), "14 日間無料で試す")
        XCTAssertEqual(SettingsScreen.purchaseButtonTitle(.readOnly(.notSubscribed), eligible: false), "購読する")
        XCTAssertEqual(SettingsScreen.purchaseButtonTitle(.readOnly(.expired), eligible: false), "購読する")
        for reason in reasons {
            XCTAssertNotNil(SettingsScreen.purchaseButtonTitle(.readOnly(reason), eligible: true), "\(reason)")
        }
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(activeYearly, eligible: true))
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(cancelledMonthly, eligible: false))
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(graceYearly, eligible: true), "in grace the person can still write (M5-16)")
        XCTAssertNil(SettingsScreen.purchaseButtonTitle(trialMonthly, eligible: true))
    }

    /// The three branches: how to cancel (subscribed / trial), the payment problem (in grace), the
    /// read-only reason and what read only still allows.
    func testPurchaseFooter() {
        let active = SettingsScreen.purchaseFooter(activeYearly)
        XCTAssertTrue(active.contains(PlanText.cancelPath), active)
        XCTAssertEqual(active, "解約は端末の\(PlanText.cancelPath)から。解約しても期間の終わりまで使えます。")
        XCTAssertEqual(SettingsScreen.purchaseFooter(cancelledMonthly), active, "cancelled inside the period: the same footer")
        XCTAssertFalse(active.contains("Apple ID"), "the short in-app path (M5-29)")

        let trial = SettingsScreen.purchaseFooter(trialMonthly)
        XCTAssertTrue(trial.contains(PlanText.cancelPath), trial)
        XCTAssertTrue(trial.hasPrefix(active), trial)
        XCTAssertTrue(trial.hasSuffix("試用中に解約すれば料金はかかりません。"), trial)
        XCTAssertEqual(SettingsScreen.purchaseFooter(cancelledTrial), trial)

        let grace = SettingsScreen.purchaseFooter(graceYearly)
        XCTAssertEqual(grace, "お支払いに問題があります。端末の\(PlanText.paymentPath)でお支払い方法を確認してください。猶予の期限までは使えます。")
        XCTAssertTrue(grace.contains(PlanText.paymentPath), grace)

        for reason in reasons {
            let text = SettingsScreen.purchaseFooter(.readOnly(reason))
            XCTAssertTrue(text.hasPrefix(PlanText.readOnlyNote(reason)), "\(reason): \(text)")
            // M6 (M6_CONTRACT §3.1 / §3.6): 「手書きの書き出し」 joined the list (利用規約 第 5 条 5 項).
            // 1.1 (M7A_CONTRACT §6.1): the row's new name 「この端末の手書きを全て消す」.
            XCTAssertTrue(text.contains("閲覧専用では、予定と手書きの閲覧、ページ移動、拡大、iCloud からの受信、この端末の手書きを全て消す、手書きの書き出し、設定の変更ができます。"), text)
            XCTAssertTrue(text.hasSuffix("新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みは購読すると使えます。"), text)
        }
        XCTAssertTrue(SettingsScreen.purchaseFooter(.readOnly(.billingRetry)).contains(PlanText.paymentPath))
        XCTAssertTrue(SettingsScreen.purchaseFooter(.readOnly(.unknown)).contains("回線が戻ると自動で確認します"))
    }

    func testPlanIsProblemAndFailure() {
        XCTAssertFalse(SettingsScreen.planIsProblem(activeYearly))
        XCTAssertFalse(SettingsScreen.planIsProblem(cancelledMonthly))
        XCTAssertTrue(SettingsScreen.planIsProblem(graceYearly), "red while in grace")
        XCTAssertFalse(SettingsScreen.planIsProblem(trialMonthly))
        XCTAssertTrue(SettingsScreen.planIsProblem(.readOnly(.billingRetry)), "red while the payment is the problem")
        for reason in reasons where reason != .billingRetry {
            XCTAssertFalse(SettingsScreen.planIsProblem(.readOnly(reason)), "\(reason)")
        }
        XCTAssertTrue(SettingsScreen.isFailure(.failed(StoreStrings.offline)))
        XCTAssertFalse(SettingsScreen.isFailure(.restored))
        XCTAssertFalse(SettingsScreen.isFailure(.nothingToRestore))
    }

    /// 設定 › データ (M6_CONTRACT §3.1 / §3.6 / §7.2): the export paragraph under the import one; the
    /// new words say 「この端末」, and the import footer is unchanged.
    func testDataSectionTexts() {
        XCTAssertEqual(SettingsScreen.exportFooter, "「手書きを書き出す」は、この端末に保存されている手書きを 1 つのデータファイル（JSON）にするか、いま開いているページを PDF にします。データファイルは「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。")
        XCTAssertFalse(SettingsScreen.exportFooter.contains("iPad"))
        XCTAssertEqual(SettingsScreen.importFooter, "Web 版の設定で「手書きを書き出す（iPad アプリ用）」をして、そのファイルを選びます。同じファイルを二度取り込んでも手書きは二重になりません。")
        // The read-only footer lists the export for every reason (`readOnlyFooter` is private: through `purchaseFooter`).
        let readOnly = SettingsScreen.purchaseFooter(.readOnly(.notSubscribed))
        XCTAssertTrue(readOnly.contains("手書きの書き出し、設定の変更ができます。"), readOnly)
        XCTAssertFalse(readOnly.contains("手書きの書き出しは"), "not in the 「購読すると使えます」 half")
    }

    /// 1.1 (M7A_CONTRACT §2.6 / §5.3 / §6.2): 設定 › 入力 「消しゴムで消したらペンに戻る」 and its footer
    /// (the Apple Pencil sentences only on an iPad), 設定 › 情報 「いちばん線の多いページ」「今年の年の
    /// ページ」 with their values and the footer, and the Google how-to of both systems.
    func testInputAndInfoTexts() {
        XCTAssertEqual(SettingsScreen.eraserAutoReturnTitle, "消しゴムで消したらペンに戻る")
        let phone = SettingsScreen.eraserAutoReturnFooter(isPad: false)
        let pad = SettingsScreen.eraserAutoReturnFooter(isPad: true)
        XCTAssertEqual(phone, "消しゴムで線を消して指を離すと、直前のペンかマーカーに戻ります。")
        XCTAssertEqual(pad, "消しゴムで線を消して指や Apple Pencil を離すと、直前のペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムも同じです。")
        XCTAssertFalse(phone.contains("Apple Pencil"), "an iPhone's settings never speak of the Pencil")
        XCTAssertFalse(phone.contains("iPad"))

        XCTAssertEqual(SettingsScreen.largestPageTitle, "いちばん線の多いページ")
        XCTAssertEqual(SettingsScreen.yearPageTitle, "今年の年のページ")
        XCTAssertEqual(SettingsScreen.infoFooter, "線の数は、この端末に保存されているページを数えたものです（どこにも送りません）。1 ページに書ける線は 19,000 本までです。")
        // The values (StrokeCensus): counting, nothing, a page.
        XCTAssertEqual(StrokeCensus.rowText(nil, counting: true), "数えています…")
        XCTAssertEqual(StrokeCensus.yearRowText(nil, year: 2026, counting: true), "数えています…")
        XCTAssertEqual(StrokeCensus.rowText(nil, counting: false), "まだ手書きがありません")
        XCTAssertEqual(StrokeCensus.rowText(StrokeBudget.Entry(pageId: "m1-2026-10", strokes: 3, tombstones: 0), counting: false), "月のページ（2026年10月）・3 本")
        XCTAssertEqual(StrokeCensus.yearRowText(StrokeBudget.Entry(pageId: "y-2026", strokes: 12, tombstones: 4), year: 2026, counting: false), "年のページ（2026年）・12 本")
        XCTAssertEqual(StrokeCensus.yearRowText(nil, year: 2026, counting: false), "年のページ（2026年）・0 本")

        // 「この端末」 (§6.1); the Google how-to names the 「設定」 app and both systems.
        XCTAssertEqual(SettingsScreen.googleHowTo, "Google カレンダーの予定を出すには、「設定」アプリで Google アカウントを追加します。\n①「設定」→「アプリ」→「カレンダー」→「カレンダーアカウント」→「アカウントを追加」→「Google」（iOS・iPadOS 17 では「設定」→「カレンダー」→「アカウント」）\n②「カレンダー」のスイッチをオン\n③同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定の反映が早くなります。\n\niCloud カレンダーだけの人は、このままで大丈夫です。")
        XCTAssertTrue(OnboardingView.accountText.hasPrefix("このアプリは、この端末の「カレンダー」に入っている予定を表示します。\n\n"))
        XCTAssertTrue(OnboardingView.accountText.hasSuffix(SettingsScreen.googleHowTo), "the first card's steps are the settings screen's")
        XCTAssertTrue(OnboardingView.accessText.hasSuffix("iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定はこの端末の中だけで扱い、開発者やほかの誰にも送りません。"))
        XCTAssertTrue(OnboardingView.penText.hasSuffix("年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。"))
        XCTAssertTrue(OnboardingView.iCloudText.contains("（この端末でサインインしていれば自動で使われます）"))
        XCTAssertEqual(AccountChangeDialogModifier.message, "この端末の手書きは、前に同期していた iCloud アカウントのものです。いまサインインしているアカウントで使い始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。")
        XCTAssertEqual(AccountChangeDialogModifier.eraseMessage, "この端末の手書きを全て消して、新しいアカウントで始めます。この操作は元に戻せません。")
        for text in [SettingsScreen.googleHowTo, SettingsScreen.infoFooter, OnboardingView.accountText, OnboardingView.accessText,
                     OnboardingView.iCloudText, AccountChangeDialogModifier.message, AccountChangeDialogModifier.eraseMessage] {
            XCTAssertFalse(text.contains("この iPad"), text)
        }
        for reason in reasons {
            XCTAssertFalse(SettingsScreen.purchaseFooter(.readOnly(reason)).contains("iPad"), "\(reason)")
        }
    }

    /// 設定 › 情報 opens the public pages and Apple's standard EULA (`LegalLinks`, D5 / M5-8).
    func testInfoLinks() {
        XCTAssertEqual(LegalLinks.terms.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/terms.html")
        XCTAssertEqual(LegalLinks.privacy.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/privacy.html")
        XCTAssertEqual(LegalLinks.support.absoluteString, "https://syfan0-star.github.io/tegaki-calendar/app/support.html")
        XCTAssertEqual(LegalLinks.appleEULA.absoluteString, "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        XCTAssertEqual(LegalLinks.appleEULATitle, "使用許諾契約（Apple 標準 EULA）")
    }

    // MARK: 1.2 (docs/M7B_CONTRACT.md §3.2, §5.7, §10.4)

    /// 「最後に同期」 and 「前回の取り込み」 keep the time; the date of 購入 has none (0-33).
    func testTimeTextHasDateAndTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12, minute: 34)))
        let text = SettingsScreen.timeText(date)
        XCTAssertTrue(text.contains(":"), text)
        XCTAssertTrue(text.contains("2026"), text)
        XCTAssertEqual(SettingsScreen.lastSyncText(date), text)
        XCTAssertEqual(SettingsScreen.lastSyncText(nil), "まだありません")
        XCTAssertEqual(SettingsScreen.webImportedText(date), "前回の取り込み: " + text)
        XCTAssertNil(SettingsScreen.webImportedText(nil))
    }

    /// The new section's words in ja, the value of the row is `HolidayChoiceTests.testSummaryTexts`.
    func testHolidaySectionTexts() {
        XCTAssertEqual(L.text("settings.holidays.header"), "祝日")
        XCTAssertEqual(L.text("settings.holidays.row"), "表示する祝日")
        XCTAssertEqual(L.text("holidayPicker.title"), "表示する祝日")
        XCTAssertEqual(L.text("settings.info.licenses"), "オープンソースのライセンス")
        XCTAssertEqual(L.text("license.holidayData"), "祝日データ：python-holidays（MIT ライセンス）")
        XCTAssertEqual(L.text("settings.holidays.footer"), "日本の祝日は、このアプリが計算しています（内閣府の発表と照らし合わせて確かめています）。ほかの国の祝日は、公開されているデータ（python-holidays）にもとづきます。旧暦やイスラム暦の祝日など一部は推定で、「（推定）」と付けています。政府の最新の発表と違うことがあります。祝日の設定はこの端末だけに保存します。")
        // The note about the translations is never on a Japanese screen, and on all the others.
        XCTAssertNil(SettingsScreen.translationNote(language: .ja))
        for language in UILanguage.allCases where language != .ja {
            XCTAssertNotNil(SettingsScreen.translationNote(language: language), "\(language)")
        }
    }

    /// An iPhone's footer speaks of neither the Pencil nor the iPad in any language; an iPad's does (§5.7).
    func testEraserFooterNeverNamesThePencilOnAnIPhone() {
        for language in UILanguage.allCases {
            let phone = L.text("settings.input.eraserAutoReturn.footer.phone", in: language)
            XCTAssertFalse(phone.contains("Apple Pencil"), "\(language): \(phone)")
            XCTAssertFalse(phone.contains("iPad"), "\(language): \(phone)")
            XCTAssertTrue(L.text("settings.input.eraserAutoReturn.footer.pad", in: language).contains("Apple Pencil"), "\(language)")
        }
    }

    /// The question comes only when the first day of the week really changes (§10.4).
    func testConfirmOnlyWhenTheStartChanges() {
        typealias Setting = WeekStartChoice.Setting
        XCTAssertEqual(WeekStartSettingsSection.confirmTarget(from: .monday, to: .sunday, automatic: .monday), .sunday)
        XCTAssertEqual(WeekStartSettingsSection.confirmTarget(from: .sunday, to: .monday, automatic: .monday), .monday)
        XCTAssertNil(WeekStartSettingsSection.confirmTarget(from: .monday, to: .auto, automatic: .monday), "Monday → automatic that gives Monday")
        XCTAssertEqual(WeekStartSettingsSection.confirmTarget(from: .monday, to: .auto, automatic: .sunday), .sunday)
        XCTAssertNil(WeekStartSettingsSection.confirmTarget(from: .auto, to: .sunday, automatic: .sunday))
        XCTAssertEqual(WeekStartSettingsSection.confirmTarget(from: .auto, to: .monday, automatic: .sunday), .monday)
        for setting in Setting.allCases {
            XCTAssertNil(WeekStartSettingsSection.confirmTarget(from: setting, to: setting, automatic: .sunday), "\(setting)")
        }
        // The words, in ja.
        XCTAssertEqual(WeekStartSettingsSection.confirmTitle(.sunday), "週の始まりを日曜にしますか？")
        XCTAssertEqual(WeekStartSettingsSection.confirmTitle(.monday), "週の始まりを月曜にしますか？")
        XCTAssertEqual(WeekStartSettingsSection.confirmButton(.sunday), "日曜にする")
        XCTAssertEqual(WeekStartSettingsSection.confirmButton(.monday), "月曜にする")
        XCTAssertTrue(WeekStartSettingsSection.confirmMessage(.sunday).contains("月曜始まりに戻すまで見えません（消えません）"))
        XCTAssertTrue(WeekStartSettingsSection.confirmMessage(.monday).contains("日曜始まりに戻すまで見えません（消えません）"))
        XCTAssertEqual(WeekStartSettingsSection.automaticText(.sunday), "自動（日曜）")
    }

    /// The line under the footer counts the other form's week pages (the ids, so a page erased empty
    /// too), says nothing for none, and never counts a month page.
    func testOtherPagesFootnote() {
        let ids = ["w-2026-10-05", "w-2026-10-12", "w-2026-10-04", "m1-2026-10", "d-2026-10-07", "y-2026"]
        XCTAssertEqual(WeekStartSettingsSection.otherPagesText(current: .monday, pageIds: ids),
                       "もう一方の週の始まり（日曜）の週のページが 1 ページあります。切り替えると見えます。")
        XCTAssertEqual(WeekStartSettingsSection.otherPagesText(current: .sunday, pageIds: ids),
                       "もう一方の週の始まり（月曜）の週のページが 2 ページあります。切り替えると見えます。")
        XCTAssertNil(WeekStartSettingsSection.otherPagesText(current: .monday, pageIds: ["w-2026-10-05", "m1-2026-10"]))
        XCTAssertNil(WeekStartSettingsSection.otherPagesText(current: .sunday, pageIds: []))
    }

    // MARK: 1.4.1 (docs/R1_4_1_CONTRACT.md §4.1, §6.3, §8.1, 0e-12, 0e-13)

    /// 設定 › 入力 「利き手」's words in ja, and a footer that never speaks of the Pencil (one text for the iPad and the
    /// iPhone) in any language.
    func testHandTexts() {
        XCTAssertEqual(SettingsScreen.handHeader, "利き手")
        XCTAssertEqual(SettingsScreen.handName(.right), "右手")
        XCTAssertEqual(SettingsScreen.handName(.left), "左手")
        XCTAssertEqual(SettingsScreen.handFooter, "左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。")
        XCTAssertEqual(SettingsScreen.handIdentifier, "settings.hand")
        XCTAssertFalse(SettingsScreen.handFooter.contains("ペンシル"))
        for language in UILanguage.allCases {
            let footer = L.text("settings.hand.footer", in: language)
            for word in ["Pencil", "iPad", "iPhone"] {
                XCTAssertFalse(footer.contains(word), "\(language): \(footer)")
            }
            XCTAssertNotEqual(L.text("settings.hand.right", in: language), L.text("settings.hand.left", in: language), "\(language)")
            XCTAssertNotEqual(L.text("settings.hand.header", in: language), "settings.hand.header", "\(language): translated")
        }
    }

    /// A switch of the hand stores it for this device and puts the folded toolbar's round button in the bottom corner opposite
    /// the writing hand's palm, once (§4.1, §16.11 question 5, 0e-13; P-4): the dock's long press may move it afterwards, and
    /// the hand stays. The sheet opens with the stored hand. Mutation MS1 (no write of `toolbar.collapsedEdge`) fails here.
    func testHandChangeStoresTheHandAndTheDockCorner() throws {
        let suite = "test-hand-settings-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
        }
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: nil), .right, "the right hand until the person chooses")

        SettingsScreen.handChanged(to: .left, screenshot: false)
        XCTAssertEqual(scratch.string(forKey: "layout.hand"), "left")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "trailing", "the round button goes to the bottom right")
        XCTAssertEqual(AppSettings.toolbarEdge, .trailing)
        XCTAssertEqual(SettingsScreen.initialHand(screenshot: nil), .left, "the next sheet opens on the left hand")

        // The dock's long press (or VoiceOver) moves the button afterwards: the last one wins, the hand stays.
        AppSettings.toolbarEdge = .leading
        XCTAssertEqual(AppSettings.hand, .left)
        XCTAssertEqual(AppSettings.toolbarEdge, .leading)

        SettingsScreen.handChanged(to: .right, screenshot: false)
        XCTAssertEqual(scratch.string(forKey: "layout.hand"), "right")
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "leading", "back to the bottom left")
        SettingsScreen.handChanged(to: .left, screenshot: false)
        XCTAssertEqual(scratch.string(forKey: "toolbar.collapsedEdge"), "trailing")
    }

    /// Screenshot mode stores nothing (§4.1, §4.10): neither the hand nor the round button's corner.
    func testHandChangeInScreenshotModeStoresNothing() throws {
        let suite = "test-hand-settings-shot-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
        }
        SettingsScreen.handChanged(to: .left, screenshot: true)
        SettingsScreen.handChanged(to: .right, screenshot: true)
        XCTAssertNil(scratch.object(forKey: "layout.hand"))
        XCTAssertNil(scratch.object(forKey: "toolbar.collapsedEdge"))
    }

    /// The sheet's wiring, which a unit test cannot drive (a `Form`'s rows and `.onChange` live only on screen): the section
    /// is the last of `inputSections` (so the Form's nine elements stay 1.3's, SettingsPageSectionTests), its two rows are an
    /// inline picker bound to `hand`, `hand` starts at `initialHand`, and `body` hands every change to `handChanged`, so
    /// `testHandChangeStoresTheHandAndTheDockCorner` is what the sheet runs.
    func testHandSectionIsWiredToStore() throws {
        let url = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/SettingsScreen.swift")
        let code = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: url, encoding: .utf8)))
        let flat = code.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(flat.contains("@State private var hand: Hand = Self.initialHand(screenshot: ScreenshotMode.current)"))
        XCTAssertTrue(flat.contains(".onChange(of: hand) { Self.handChanged(to: hand, screenshot: ScreenshotMode.isActive) }"))
        XCTAssertEqual(flat.components(separatedBy: "handChanged(").count - 1, 2, "declared once and called once, from body")
        XCTAssertEqual(flat.components(separatedBy: "AppSettings.hand = ").count - 1, 1, "stored only in handChanged")

        let inputStart = try XCTUnwrap(flat.range(of: "private var inputSections: some View {"))
        let pageStart = try XCTUnwrap(flat.range(of: "private var pageSection: some View {"))
        let input = String(flat[inputStart.upperBound..<pageStart.lowerBound])
        let handSection = try XCTUnwrap(input.range(of: "Section { Picker(Self.handHeader, selection: $hand) {"), input)
        XCTAssertNil(input[handSection.upperBound...].range(of: "Section {"), "the hand's section is the last of 入力")
        let tail = String(input[handSection.lowerBound...])
        for piece in ["Text(Self.handName(.right)).tag(Hand.right)", "Text(Self.handName(.left)).tag(Hand.left)",
                      ".pickerStyle(.inline)", ".labelsHidden()", ".accessibilityIdentifier(Self.handIdentifier)",
                      "Text(Self.handHeader)", "Text(Self.handFooter)"] {
            XCTAssertTrue(tail.contains(piece), piece)
        }
    }

    // MARK: - 1.4.2: 設定 › 「メモ欄の紙」 (docs/R1_4_2_CONTRACT.md §4.2, §6.2, §8.1, 0f-20)

    /// The row's words in ja (§8.1, the words of the plan's §2 the owner read), its identifier, and the three choices in the
    /// order of the type.
    func testMemoPaperWords() {
        XCTAssertEqual(MemoPaperSettingsSection.title, "メモ欄の紙")
        XCTAssertEqual(MemoPaperSettingsSection.name(.ruled), "罫線")
        XCTAssertEqual(MemoPaperSettingsSection.name(.dots), "ドット方眼")
        XCTAssertEqual(MemoPaperSettingsSection.name(.plain), "無地")
        XCTAssertEqual(MemoPaperSettingsSection.footer, "メモ欄と自由メモの紙の柄です。手書きはそのまま残ります。この設定は端末ごとです。")
        XCTAssertEqual(MemoPaperSettingsSection.identifier, "settings.memoPaper")
        XCTAssertEqual(MemoPaperStyle.allCases.map(MemoPaperSettingsSection.name), ["罫線", "ドット方眼", "無地"])
    }

    /// A choice outside screenshot mode is stored for this device and becomes the pattern in force; in screenshot mode it only
    /// becomes the pattern in force (mutation MS3: stored there fails here).
    func testMemoPaperChangeStoresAndSets() throws {
        let suite = "test-memo-paper-settings-\(UUID())"
        let scratch = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = AppSettings.defaults
        AppSettings.defaults = scratch
        defer {
            scratch.removePersistentDomain(forName: suite)
            AppSettings.defaults = saved
            MemoPaperStyle.set(.ruled)
        }
        MemoPaperStyle.set(.ruled)
        for style in [MemoPaperStyle.dots, .plain, .ruled] {
            MemoPaperSettingsSection.changed(to: style, screenshot: false)
            XCTAssertEqual(scratch.string(forKey: AppSettings.memoPaperKey), style.rawValue, "\(style) is stored in AppSettings.defaults")
            XCTAssertEqual(MemoPaperStyle.current, style)
        }
        scratch.removeObject(forKey: AppSettings.memoPaperKey)
        for style in [MemoPaperStyle.plain, .dots, .ruled] {
            MemoPaperSettingsSection.changed(to: style, screenshot: true)
            XCTAssertNil(scratch.object(forKey: AppSettings.memoPaperKey), "\(style): screenshot mode stores nothing")
            XCTAssertEqual(MemoPaperStyle.current, style, "\(style): the paper changes in memory")
        }
    }

    /// The sheet's wiring, which a unit test cannot drive: 「メモ欄の紙」 is the first element of `inputSections` (right below
    /// 「祝日」, the Form's nine elements unchanged), and its own file is a `.navigationLink` picker over the three patterns with
    /// the identifier and the footnote, starting at the pattern in force, whose choice goes to `changed` with screenshot mode's
    /// flag (so `testMemoPaperChangeStoresAndSets` is what the sheet runs).
    func testMemoPaperSectionIsWired() throws {
        let screen = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/SettingsScreen.swift")
        let flat = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: screen, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let inputStart = try XCTUnwrap(flat.range(of: "private var inputSections: some View {"))
        let input = String(flat[inputStart.upperBound...])
        XCTAssertTrue(input.hasPrefix(" MemoPaperSettingsSection() Section { Toggle("), "the first element of inputSections: \(input.prefix(80))")
        XCTAssertEqual(flat.components(separatedBy: "MemoPaperSettingsSection()").count - 1, 1, "once")
        XCTAssertFalse(flat.contains("AppSettings.memoPaperKey"), "the screen itself stores nothing")

        let file = Self.repository.appendingPathComponent("Sources/TegakiCalendar/Views/MemoPaperSettingsSection.swift")
        let section = String(WeekMemoSpanTests.codeOnly(try String(contentsOf: file, encoding: .utf8)))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for piece in ["@State private var style: MemoPaperStyle = MemoPaperStyle.current",
                      "Picker(Self.title, selection: selection) { ForEach(MemoPaperStyle.allCases, id: \\.self) { choice in Text(Self.name(choice)).tag(choice) } }",
                      ".pickerStyle(.navigationLink)", ".accessibilityIdentifier(Self.identifier)", "} footer: { Text(Self.footer) }",
                      "Self.changed(to: next, screenshot: ScreenshotMode.isActive)",
                      "if !screenshot { defaults.set(value.rawValue, forKey: AppSettings.memoPaperKey) } MemoPaperStyle.set(value)"] {
            XCTAssertTrue(section.contains(piece), piece)
        }
        XCTAssertFalse(section.contains("header:"), "no header (§4.2)")
    }

    private static let repository = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}
