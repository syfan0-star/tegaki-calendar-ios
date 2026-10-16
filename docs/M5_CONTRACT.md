# M5 実装契約（サブスクリプション・閲覧専用モード・規約類の公開）

この文書は M5 の各担当が同時に作業するための **約束事**（公開 API・数字・文言・ファイル所有）です。[M4C_CONTRACT.md](M4C_CONTRACT.md) の続きで、M2〜M4c で決めたことはそのまま生きています（ここに書いていない API は変えません）。設計の根拠は [DESIGN.md](DESIGN.md)（§2.8 設定、§2.9 課金画面、§7 課金、§10 審査）と [PRICING.md](PRICING.md)。行番号は iOS リポジトリ main（0.5.2、92ed62c）と Web リポジトリ main（1.0.6、8de2bab）のものです。**第 2 版**（2026-10-17。第 1 版に対する 3 つの照合（codebase / storekit / legal-ux）の指摘を反映。決定の追加は §9 の M5-27〜M5-38、採らなかった指摘と理由は §9.1）。

**本人の決定（確定。再検討しない）**: サブスクリプション（買い切りではない。理由: 継続的な責任と安心。責任の範囲は規約に明記）／価格の仮説 月 300 円・年 2,400 円・14 日間無料（PRICING.md、B-7）／閲覧専用では予定の作成・編集も止める（B-4「止める」）／規約・プライバシー・サポートは既存の Web 版 Pages に置く（B-6）／日本中心・EU 除外／販売者名は戸籍上の氏名／アプリ名「てがきカレンダー」／Small Business Program に申し込む（15 %）。本人がまだやること（§6.2）: Paid Apps Agreement の同意、税務・銀行、Small Business Program の申込。App Store Connect の商品はリード（Claude）が本人の Chrome で作る（§6.1）。

**リードの決定（この契約の既定。根拠があれば直し、理由を書く）**:

- **D1 StoreKit 2 だけ**（`Product` / `Transaction` / `Transaction.currentEntitlements` / 起動時の `Transaction.updates` 監視 / 復元は `AppStore.sync()`）。サブスクリプショングループ「てがきカレンダー」1 つ、同じサービスレベルの自動更新商品 2 つ: `com.syfan0.tegakicalendar.monthly`（¥300 / 1 か月）と `com.syfan0.tegakicalendar.yearly`（¥2,400 / 1 年）。各商品に導入オファー「無料トライアル 2 週間」（資格は StoreKit が判定。アプリは `Product.SubscriptionInfo.isEligibleForIntroOffer` が true のときだけ「14 日間無料で試す」を出し、false なら価格だけ）。請求猶予期間オン。ファミリー共有オフ。日本語のローカライズ表示名と説明は §1.1（リードが App Store Connect に打ち込む）。
- **D2 権利の判定は TegakiKit の純粋な状態機械**（Foundation だけ）: 入力 = 現在の権利（商品 ID・期限・取消・導入オファーか）＋更新情報（状態・自動更新・猶予の期限）＋ now → `AccessState`（`.subscribed` / `.trial` / `.readOnly(reason)`、§1.2）。StoreKit 層（`Sources/TegakiCalendar/Store/*`）は `Transaction` と `Status` をその入力に写すだけ。UI が要るものは全部 `@MainActor` の `StoreModel` 1 つの `snapshot` から取る。最後に分かった状態を UserDefaults に控え、オフラインの起動でも権利を保つ（§1.3。控えの読み書きは S が自己完結で持ち、U には依存しない。M5-34）。更新情報が取れないとき（`renewals` が nil）は期限切れを即断せず `.readOnly(.unknown)`（保存しない）。iCloud の `Meta.trialStartedAt` は **使わない**（項目は残す。M5-4）。
- **D3 閲覧専用モード**（DESIGN §7.4 の表が出所。§3 の表が正）: できる = 全ページの閲覧、ページ移動、拡大、iCloud からの受信、設定の変更、「全て消す」。止める（購読の案内つき）= 新しく書く（PencilKit の描画認識器オフ、投げなわ／予定ツールオフ）、消す・動かす、予定の作成・編集・削除、Web 版の取り込み。ヘッダーに小さな「閲覧専用」バッジ（タップでペイウォール）。文言は §3.3。
- **D4 ペイウォール**（DESIGN §7.3 の文言が土台、審査 3.1.2 は §7.5 のチェックリスト）: 2 プラン（年額を強調。**「4 か月分お得」**。0-1）、試用の行、Apple が求める自動更新の説明文（試用資格の有無で請求時期の文を出し分ける。§4.1）、「購入を復元」、「利用規約」「プライバシーポリシー」「使用許諾契約（Apple 標準 EULA）」、「あとで」。出るとき: 初回案内の後、最初の `refresh()` が済んで **未購読と確認できたとき** に 1 回（M5-33）、止めた操作を試みたとき（1 セッション 1 回。2 回目以降はトースト）、設定 › 購入、バッジ。設定 › 購入は 現在のプラン・次回更新日（有効期限）・「サブスクリプションを管理」・「購入を復元」（§4.3）。
- **D5 規約類の公開**: L が `docs/TERMS.md` / `PRIVACY.md` / `SUPPORT.md` を「てがきカレンダー」の公開版に仕上げる（価格と試用、責任の範囲、保存場所、解約と Apple 経由の返金、連絡先 `syfan0@gmail.com`（M5-1 既定））。W が Web リポジトリの `app/terms.html` / `app/privacy.html` / `app/support.html` を既存 `privacy.html` と同じ様式で作る（ブランチ `m5-legal`。main への公開はリードが確認後に行う）。アプリは 設定 › 情報 とペイウォールから `https://syfan0-star.github.io/tegaki-calendar/app/{terms,privacy,support}.html` を開く（0-2 の綴りはこれに統一。`ios/` は廃止）。使用許諾（ライセンス）は Apple 標準 EULA のまま（M5-8）なので、その URL（`LegalLinks.appleEULA`）も規約第 1 条 2 項・ペイウォール・設定 › 情報・App Store の説明欄に入れる（審査 3.1.2(a)）。App Store Connect の Support URL / Privacy Policy URL も同じ（M6 が入力）。
- **D6 Xcode の無い開発でのテスト**: `Support/Products.storekit`（2 商品＋導入オファー）を CI のテストバンドルのリソースに入れ、`SKTestSession` で購入・期限切れ・返金を回す（§7.3）。XcodeGen のスキームにも `storeKitConfiguration` を付ける（保険）。StoreKitTest が CI で動かなければ `StoreClient` プロトコル＋偽物に退く（判定基準 §7.3.3。偽物のテストはどちらにせよ必須）。写真: `--screenshot-sheet paywall` と `--screenshot-readonly`。KitChecks に状態機械の節。役割ごとの XCTest。
- **D7 App Store Connect の手順**はリードの正確なチェックリスト（§6.1。欄の値つき）と本人の項目（§6.2）に分けて書く。¥2,400 の価格ポイントの有無は作成時に確認（無ければ ¥2,300 か ¥2,500。PRICING §2、M5-7）。
- **D8** `MARKETING_VERSION` **0.6.0**。この契約は `docs/M5_CONTRACT.md`、実装結果は `docs/M5.md`。DESIGN §2.8〜2.10・§7・§10 の注記は C。

**範囲外**（触らない）: 手書きの書き出しの実装（PDF・画像・JSON。M6 で App Store 公開前に最低限を入れる。M5-27。M5 では設定の「準備中」の行を**外し**、規約・サポートに「未提供」と書き、`GatedAction.export` を「許す」側に予約するだけ）、`Sync/*`（Meta の `trialStartedAt` も触らない）、`Paper/*`、レイアウトエンジン、ズーム、Web 版のアプリ本体（`index.html` / `js/` / `sw.js`）、App Privacy の回答と審査提出（M6）、`Transaction.beginRefundRequest`、プロモーションオファー・オファーコード、価格の国別調整。

### 0.1 偵察で見つかった食い違いの決着

| # | 内容 | 決着 |
| --- | --- | --- |
| 0-1 | タスク D4 の「2 か月分お得」は誤り（2,400 = 300 × 8。DESIGN.md に「2 か月」の記述は無い。§2.9 は「年額 2,400 円（月あたり 200 円）」のみ） | **「4 か月分お得」**（33 % 引き。月あたり 200 円）。K の `PlanText.savingsMonths` が計算し、固定文字列は写真モードだけ。C は DESIGN §2.9 の 2 に「4 か月分お得」の表示を**足す**（直す文字列は無い） |
| 0-2 | 公開 URL が `ios/` と `app/` の 2 通り | **`app/`**。`SettingsScreen.swift:40-42` の 3 定数は K の `LegalLinks` に移す（§1.5）。DESIGN 付録 B B-6 に注記（C） |
| 0-3 | ペイウォールの時機（DESIGN「初めてペンで紙に触れたとき」vs D4「初回案内の直後」） | **D4 を保ち、出す条件を厳しくする**（§4.2、M5-33）: 初回案内の後、最初の `refresh()` の完了（最長 3 秒）を待ち、未購読と確認でき・価格が取れているときだけ出す。理由: 閲覧専用では紙に何も書けないので、最初に見せるべき価値は試用の入口そのもの（0 円で 14 日）。OS のカレンダー許可は案内の最後のカードが `await model.requestAccess()` を終えてからカバーを閉じる（CalendarRootScreen 363-367）ので、許可ダイアログとは重ならない。ペンで触れたときも「止めた操作」として 1 セッション 1 回出る（Pencil のタッチだけ。指は出さない）。DESIGN §2.10 末尾・§7.4 を書き換え（C） |
| 0-4 | DESIGN §7.2 の `SubscriptionStoreView` 案 | **自前のシート**（D4）。理由: 2 プラン・試用資格・割引表示・止めた操作ごとの文言を自分で並べる。D1（StoreKit 2 だけ）とは両立。§7.2 を書き換え（C） |
| 0-5 | 規約第 3 条 4 項・第 5 条 5 項・第 8 条 2 項が「手書きの書き出し」を提供中の機能として約束 | **弱める**（§5.1）: 第 3 条 4 項「順次提供」、第 5 条 5 項から書き出しを外す、第 8 条 2 項「終了の 90 日前までに書き出しの手段を用意する」 |
| 0-6 | 解約手順の表記が 3 通り | **「設定」›「Apple Account」›「サブスクリプション」** に統一。規約・サポート・プライバシーには **「（iPadOS 17 では「Apple ID」）」を付ける**。アプリ内（`PlanText.cancelPath`、disclosure、purchaseFooter）は短い表記のまま（**意図した差**。M5-29: 字数の多いペイウォールに括弧書きを増やさない。iPadOS 17 の人は設定アプリの同じ位置に「Apple ID」があり、迷わない）。L は「設定」→ 自分の名前 → … の形を**全部**置換する（SUPPORT 70・88・95 行、PRIVACY 74 行、TERMS 48 行、§5.1） |
| 0-7 | 初回案内の枚数・順番が設計と実装で違う | 実装（カレンダーのアカウント／アクセス／ペンと指／iCloud）が正。DESIGN §2.10 の表を実装に合わせる（C）。M5 では案内の文面を変えない |
| 0-8 | 「すべての手書きを削除」vs 実装「この iPad の手書きを全て消す」 | **実装の文言**に揃える（PRIVACY §9、SUPPORT FAQ） |
| 0-9 | SUPPORT「移行ツール【準備中】」は実装済み | 手順を書く（Web 版 設定「手書きを書き出す（iPad アプリ用）」→ アプリ 設定 › データ「Web 版の手書きを取り込む」。同じファイルを二度取り込んでも二重にならない） |

## 0. 構成とファイル所有

```
TegakiKit/                                                担当 K（TegakiKit だけを触る）
  Package.swift                                           変更: product Access、target Access、testTarget AccessTests、KitChecks の依存に Access
  Sources/Access/Plan.swift                               新規: Plan / ProductIDs（§1.1）
  Sources/Access/AccessState.swift                        新規: AccessState / Subscription / Trial / ReadOnlyReason（§1.2）
  Sources/Access/AccessPolicy.swift                       新規: EntitlementInput / RenewalInput / RenewalState / AccessPolicy.resolve / reconcile（§1.2、§1.3）
  Sources/Access/AccessSnapshot.swift                     新規: AccessSnapshot / AccessCache（§1.3）
  Sources/Access/PlanText.swift                           新規: 文言と数字の純関数（§1.5）
  Sources/Access/LegalLinks.swift                         新規: 4 つの URL（§1.5。Apple 標準 EULA を含む）
  Sources/KitChecks/main.swift                            変更: 「access state (M5)」の節（§7.4）
  Tests/AccessTests/{AccessPolicyTests,AccessCacheTests,PlanTextTests}.swift   新規（§7.6）
Sources/TegakiCalendar/
  Store/StoreClient.swift                                 担当 S   新規: protocol StoreClient、StoreProduct、StorePurchaseResult（§2.1）
  Store/LiveStoreClient.swift                             担当 S   新規: StoreKit 2 の実装（§2.2）
  Store/StoreModel.swift                                  担当 S   新規: StoreModel / StoreSnapshot / PlanOffer / StorePhase / StoreMessage（§2.3）
  Store/AccessCacheStore.swift                            担当 S   新規: AccessCacheStore / UserDefaultsAccessCache（自己完結。UserDefaults とキーを自分で持つ）/ NoopAccessCache（§1.3）
  Store/StoreStrings.swift                                担当 S   新規: 失敗・結果の文言（§2.5）
  Views/PaywallSheet.swift                                担当 U   新規（§4.1）
  Views/SettingsScreen.swift                              担当 U   変更: 購入欄の実装、情報欄の URL を LegalLinks に、データ欄の「手書きを書き出す」準備中の行を外す（§4.3）
  Views/EventEditorSheet.swift                            担当 U   変更: 既定値つきの 2 引数 readOnlyNote / onSubscribe（§3.3。閲覧専用モードの脚注と「購読する」）
  Views/PageHeaderView.swift                              担当 U   変更: readOnly バッジ（§3.2）
  Views/CalendarRootScreen.swift                          担当 U   変更: StoreModel、止める操作の guard、ペイウォールの提示、閲覧専用の案内行、写真モード（§3.1、§4.2）
  Ink/InkCanvasView.swift                                 担当 U   変更（M4c の流儀では Ink/* は P だが M5 に P は居ない。触ってよい場所は **§3.1 の列挙だけ**: 新引数 2 つ、認識器 1 本、attach・syncRecognizers・update(from:)・delegate 2 メソッドの指定行。Ink/InkOverlayView.swift は触らない）
  Support/ScreenshotMode.swift                            担当 U   変更: Sheet.paywall、Config.readOnly（§7.5）
  Persistence/AppSettings.swift                           担当 U   変更: paywallShownAfterOnboardingKey だけ（§4.2。控えのキーは S の UserDefaultsAccessCache.defaultKey が持つ。M5-34）
Support/Products.storekit                                 担当 S   新規（§7.1）
Tests/TegakiCalendarTests/StoreModelTests.swift           担当 S   新規: 偽物で（§7.3.2。UserDefaultsAccessCache の往復もここ）
Tests/TegakiCalendarTests/FakeStoreClient.swift           担当 S   新規
Tests/TegakiCalendarTests/StoreKitSessionTests.swift      担当 S   新規: SKTestSession で（§7.3.1）
Tests/TegakiCalendarTests/{ScreenshotModeTests,AppSettingsTests,CalendarRootScreenTests,InkCanvasViewTests}.swift   担当 U   変更・追加（§7.6）
Tests/TegakiCalendarTests/{PaywallSheetTests,SettingsScreenTests,EventEditorSheetTests}.swift   担当 U   新規（§7.6）
docs/TERMS.md / docs/PRIVACY.md / docs/SUPPORT.md         担当 L（§5.1。iOS リポジトリ。この 3 つだけ）
Web リポジトリ（/Users/ikedamasataka/Documents/Codex/tegaki-calendar、ブランチ m5-legal）   担当 W（§5.2）
  app/terms.html / app/privacy.html / app/support.html / app/index.html   新規
  tests/app-pages.test.mjs                                新規（npm test に入る）
  tools/check-legal.mjs                                   新規（npm run check:legal。【】と「下書き」の禁止。公開前の関門）
  package.json                                            変更: scripts に check:legal を 1 行（version は 1.0.6 のまま）
  README.md                                               変更: 8 行目「プライバシーポリシー: …」の箇条書きの直後に 3 行（README に「公開ページの一覧」という節は無い。先頭の箇条書きがそれ）
project.yml / .github/workflows/build.yml / docs/M5.md / README.md / docs/DESIGN.md / docs/PRICING.md の注記   担当 C（§7.7、§8）
```

依存の向き: `TegakiCalendar` → `TegakiKit`（`Access` は Foundation だけ。`DayKit` にも依存しない）。`Store/*` → `Access`。`Views/*` → `Store/*` と `Access`。接点は次の 8 つだけで、全部この契約の形に固定します。**共有する型と純関数は全部 K に置き、S・U の新しい引数には既定値を付ける。S の最初の版は K にしか依存しない（U の `AppSettings` / `ScreenshotMode` の新しい項目を参照しない。M5-34）**。

1. `AccessState` / `Plan` / `AccessPolicy` / `AccessSnapshot`（§1.2、§1.3、K）: S が作り、U が読む。
2. `PlanText` / `LegalLinks`（§1.5、K）: U のペイウォール・設定・バッジと、W のテスト（同じ文字列）が使う。
3. `StoreModel.snapshot: StoreSnapshot`（§2.3、S）: U が読む唯一の口。`purchase(_:)` / `restore()` / `refresh(reason:)` / `awaitFirstRefresh(timeout:)` / `clearMessage()` を呼ぶ。
4. `StoreModel.make(screenshotReadOnly:)` / `StoreModel.screenshotDemo(access:eligible:)`（§2.3、S）: U が `@StateObject` で 1 つ作る（`ScreenshotMode.current?.readOnly ?? false` を U が渡す）。
5. `InkCanvasView` の新しい引数 2 つ（§3.1、U。既定値つき）: `readOnly`、`onBlockedInput`。
6. `PageHeaderView` の新しい引数 2 つ（§3.2、U。既定値つき）: `readOnly`、`onReadOnlyTap`。
7. `ScreenshotMode.Sheet.paywall` / `Config.readOnly`（§7.5、U）と build.yml の 4 枚（C）。
8. `EventEditorSheet` の新しい引数 2 つ（§3.3、U。既定値つき）: `readOnlyNote`、`onSubscribe`。

**担当 K は `TegakiKit/` だけ。担当 S は `Sources/TegakiCalendar/Store/*`・`Support/Products.storekit`・自分のテスト 3 ファイルだけ（`Views/*`・`Persistence/*` を触らない）。担当 U は `Views/*`（`EventEditorSheet.swift` の 2 引数を含む）・`Ink/InkCanvasView.swift`（§3.1 の範囲）・`Support/ScreenshotMode.swift`・`Persistence/AppSettings.swift`・自分のテスト。担当 L は `docs/{TERMS,PRIVACY,SUPPORT}.md` だけ。担当 W は Web リポジトリだけ（ブランチ `m5-legal`。main に push しない）。担当 C は project.yml・build.yml・docs/M5.md・README.md・DESIGN.md・PRICING.md の注記だけ。**

## 1. 商品と権利

### 1.1 商品（K: `Access/Plan.swift`、リード: App Store Connect §6.1）

| 項目 | 月額 | 年額 |
| --- | --- | --- |
| 製品 ID | `com.syfan0.tegakicalendar.monthly` | `com.syfan0.tegakicalendar.yearly` |
| 参照名（Connect） | `月額` | `年額` |
| 期間 | 1 か月 | 1 年 |
| 価格（JPY、税込表示） | **¥300** | **¥2,400**（価格表に無ければ ¥2,300 か ¥2,500。M5-7） |
| 導入オファー | 無料トライアル **2 週間**（新規購読者、全配信国、開始 = 作成日、終了なし） | 同じ |
| 表示名（日本語、30 字以内） | `てがきカレンダー 月額` | `てがきカレンダー 年額` |
| 説明（日本語、45 字以内） | `手書き・予定の作成・iCloud 同期が使える月額プラン` | `同じ機能の年額プラン（月あたり 200 円・4 か月分お得）` |
| ファミリー共有 | オフ（オンにすると戻せない） | オフ |

グループ: 参照名 `てがきカレンダー`、日本語の表示名 `てがきカレンダー`、App 名の表示は「App 名を使う」。月額 ⇄ 年額は同じサービスレベル（グループ内の切替は Apple が日割りと切替時期を処理。アプリは何もしない）。請求猶予期間: オン、**16 日、有料どうしの更新のみ**（M5-3 既定。無料試用 → 有料の最初の請求に失敗した人には猶予が無く、即 `.readOnly(.billingRetry)`。規約第 5 条 5 項とサポート FAQ にその例外を書く。§5.1）。

```swift
// TegakiKit/Sources/Access/Plan.swift
public enum Plan: String, Codable, CaseIterable, Sendable, Equatable {
    case monthly, yearly
    /// "com.syfan0.tegakicalendar.monthly" / ".yearly"
    public var productID: String { ProductIDs.prefix + rawValue }
    /// 月額 1、年額 12
    public var months: Int
    public init?(productID: String)                                   // 2 つ以外は nil
}
public enum ProductIDs {
    public static let prefix = "com.syfan0.tegakicalendar."
    public static let groupReferenceName = "てがきカレンダー"
    public static let all: Set<String>   // Plan.allCases.map(\.productID)
    /// 契約の価格（円）。表示には使わない（表示は StoreKit の displayPrice）。KitChecks と写真モードの固定値
    public static let contractPrice: [Plan: Decimal] = [.monthly: 300, .yearly: 2400]
    public static let trialDays = 14
}
```

### 1.2 権利の状態機械（K: `Access/AccessState.swift`、`Access/AccessPolicy.swift`）

```swift
public struct Subscription: Equatable, Codable, Sendable {
    public var plan: Plan
    /// willAutoRenew なら次回更新日、解約済みなら有効期限、猶予中なら猶予の期限
    public var until: Date
    public var willAutoRenew: Bool
    /// 支払いに失敗して請求猶予期間にいる（Apple の gracePeriodExpirationDate まで使える）
    public var inGrace: Bool
}
public struct Trial: Equatable, Codable, Sendable {
    public var plan: Plan
    public var until: Date                 // 試用の終了（willAutoRenew なら有料に移る日）
    public var willAutoRenew: Bool
}
public enum ReadOnlyReason: String, Codable, Sendable {
    case notSubscribed      // 権利が一度も無い（初回・新しい Apple Account）
    case expired            // 期限切れ（解約後、または猶予も尽きた）
    case billingRetry       // 猶予なしの請求リトライ中（Apple が再請求を試みている）
    case revoked            // 返金・取消
    case unknown            // 控えも無く StoreKit にも届かない（初回起動がオフラインなど）
}
public enum AccessState: Equatable, Codable, Sendable {
    case subscribed(Subscription)
    case trial(Trial)
    case readOnly(ReadOnlyReason)
    /// .subscribed / .trial なら true（止める操作の判定はこれだけを見る。§3.1）
    public var canEdit: Bool
    public var plan: Plan?                 // readOnly は nil
    public var until: Date?                // readOnly は nil
}

public enum RenewalState: String, Codable, Sendable {
    case subscribed, expired, inBillingRetryPeriod, inGracePeriod, revoked, unknown
}
/// Transaction 1 件の写し（S が写す。検証済みのものだけ）
public struct EntitlementInput: Equatable, Sendable {
    public var id: UInt64                  // Transaction.id（重複排除の鍵）
    public var productID: String
    public var subscriptionGroupID: String? // Transaction.subscriptionGroupID（renewals の問い合わせに使う）
    public var purchaseDate: Date
    public var expirationDate: Date?
    public var revocationDate: Date?
    /// 導入オファー（無料トライアル）で得た権利か（Transaction.offerType == .introductory、17.2 以降は offer?.type）
    public var isIntroductory: Bool
}
/// Product.SubscriptionInfo.Status 1 件の写し（検証済みの renewalInfo だけ。無ければ空配列）
public struct RenewalInput: Equatable, Sendable {
    public var productID: String           // renewalInfo.currentProductID
    public var state: RenewalState
    public var willAutoRenew: Bool
    public var gracePeriodExpirationDate: Date?
    public var renewalDate: Date?          // renewalInfo.renewalDate は **iOS 18.0 以降**（配信対象は 17.0）。17 では nil → expirationDate に落ちる
    public var autoRenewPreference: String? // 次回から切り替わる商品 ID（表示には使わない）
    /// Status.transaction（最新の Transaction。検証済みなら写す）。currentEntitlements が一時的に空でも権利を落とさないための控え
    public var latestTransaction: EntitlementInput?
}
public enum AccessPolicy {
    /// 入力から状態を 1 つ決める。順序は下の表のとおり（上から最初に当たった行）。renewals が nil = 更新情報を取得できなかった（オフラインなど）
    public static func resolve(entitlements: [EntitlementInput], renewals: [RenewalInput]?, now: Date) -> AccessState
    /// 起動時: StoreKit の結果 live と控え cached を合わせる（§1.3）
    public static func reconcile(live: AccessState, cached: AccessSnapshot?, storeReachable: Bool, now: Date) -> AccessState
}
```

`resolve` の規則（真理値表）。前処理: 候補 = `entitlements` ∪ `renewals?.compactMap(\.latestTransaction)`（`id` で重複排除。同じ id なら `entitlements` 側を採る）。E = 候補のうち `revocationDate == nil` かつ `Plan(productID:) != nil` のもので `expirationDate` が最も遅いもの（nil の期限は最も遅いとみなす）。R = `renewals` のうち `Plan(productID:) != nil` のものだけを対象にし（他は無視）、E と同じ商品 ID のもの、無ければその先頭。`renewals == nil`（取得失敗）のときは R 無しだが、2・8・13 の行は `.readOnly(.unknown)` になる（期限切れを即断しない。保存されないので次の `refresh()` で直る）:

| # | 条件 | 結果 |
| --- | --- | --- |
| 1 | 候補の中に有効な（取消でない・既知の商品の）ものが無く、取消された（`revocationDate != nil`）ものが 1 つ以上ある | `.readOnly(.revoked)`。注: `Transaction.currentEntitlements` は取消された Transaction を**返さない**ので、この行に来るのは `Transaction.updates` の写し（`StoreModel` が直近の入力として保持して渡す。§2.4）か R の `latestTransaction` だけ |
| 2 | E が無く、R も無い | `renewals != nil` → `.readOnly(.notSubscribed)`; `renewals == nil` → `.readOnly(.unknown)` |
| 3 | E が無く、R.state が `.inGracePeriod` で `gracePeriodExpirationDate > now` | `.subscribed(plan: R の商品, until: 猶予の期限, willAutoRenew: R.willAutoRenew, inGrace: true)` |
| 4 | E が無く、R.state が `.inBillingRetryPeriod` | `.readOnly(.billingRetry)` |
| 5 | E が無く、R.state が `.subscribed` で `R.renewalDate != nil && R.renewalDate! > now` | `.subscribed(plan: R の商品, until: R.renewalDate!, willAutoRenew: R.willAutoRenew, inGrace: false)`（Status は検証済みなのに `currentEntitlements` が空＝サンドボックスで頻発する一時的な空返し。権利を落とさない） |
| 6 | E が無く、R.state が `.subscribed` で `renewalDate` が nil か `≤ now` | `.readOnly(.unknown)`（矛盾した入力。保存されない。次の `refresh()` で直る） |
| 7 | E が無く、R.state が `.revoked` | `.readOnly(.revoked)`（返金の判定は実機では**この行**（と 1 の updates 経由）で起きる） |
| 8 | E が無く、R.state が `.expired` / `.unknown` / `.inGracePeriod`（猶予の期限切れ） | `.readOnly(.expired)` |
| 9 | E があり `expirationDate == nil || expirationDate > now`、`isIntroductory == true` | `.trial(plan: E の商品, until: expirationDate（nil なら now + 14 日）, willAutoRenew: R?.willAutoRenew ?? true)` |
| 10 | E があり期限内、`isIntroductory == false` | `.subscribed(plan: E の商品, until: R?.renewalDate ?? expirationDate, willAutoRenew: R?.willAutoRenew ?? true, inGrace: false)` |
| 11 | E の期限が過ぎ、R.state が `.inGracePeriod` で `gracePeriodExpirationDate > now` | 3 と同じ（`inGrace: true`、until = 猶予の期限） |
| 12 | E の期限が過ぎ、R.state が `.inBillingRetryPeriod` | `.readOnly(.billingRetry)` |
| 13 | E の期限が過ぎ、それ以外 | `renewals != nil` → `.readOnly(.expired)`; `renewals == nil` → `.readOnly(.unknown)`（猶予中かもしれないので即断しない。§1.3 の reconcile が控えの `inGrace` を優先する） |

補足: `currentEntitlements` は猶予中の Transaction も返す（期限が過ぎていても）ので 11 の行が要る。試用中に解約した人は 9 で `willAutoRenew: false`（設定の文言「試用の終了」で日付だけ出す）。月額 → 年額の切替予約（`autoRenewPreference`）は表示しない（Apple のサブスクリプション画面が見せる）。`now` は常に引数（テストで固定）。

### 1.3 控え（キャッシュ）とオフラインの規則（K: `Access/AccessSnapshot.swift`、S: `Store/AccessCacheStore.swift`、U: `AppSettings`）

```swift
public struct AccessSnapshot: Equatable, Codable, Sendable {
    public var state: AccessState
    public var savedAt: Date
}
public enum AccessCache {
    public static func encode(_ snapshot: AccessSnapshot) -> Data          // JSONEncoder、日付は .iso8601
    public static func decode(_ data: Data) -> AccessSnapshot?             // 壊れていれば nil
    /// 起動の最初の 1 フレーム用: 控えの期限を now で切り直す
    public static func stateForLaunch(cached: AccessSnapshot?, now: Date) -> AccessState
    /// 自動更新が予定されていた控えは、回線が無いまま更新日をまたいでもこの日数は書ける（M5-30）
    public static let offlineRenewalAllowanceDays = 3
}
```

`stateForLaunch`: nil → `.readOnly(.unknown)`; `.subscribed` / `.trial` で `until > now` → そのまま; `.subscribed(willAutoRenew: true, inGrace: false)` / `.trial(willAutoRenew: true)` で `until ≤ now < until + 3 日` → **そのまま**（Apple 側では更新済みのはずなので閲覧専用に落とさない。回線が戻れば `refresh()` が正す。`inGrace` と `willAutoRenew: false` には適用しない）; `.subscribed(inGrace: true)` で `until ≤ now` → `.readOnly(.billingRetry)`; それ以外の `.trial` / `.subscribed` で `until ≤ now` → `.readOnly(.expired)`; `.readOnly(r)` → そのまま。

`reconcile(live:cached:storeReachable:now:)`（上から最初に当たった行。c = `stateForLaunch(cached:now:)`）:

| # | 条件 | 結果 |
| --- | --- | --- |
| a | `storeReachable == true` | `live`（StoreKit の答えが正） |
| b | 到達不可で `live.canEdit` | `live` |
| c | 到達不可で `live == .readOnly(.revoked)` | `live`（返金は控えで覆さない） |
| d | 到達不可で `c.canEdit`（控えが有効。`inGrace` の控えも含む） | **c**（オフラインの起動・猶予中に権利を失わない。`live` が `.expired` でも控えが `inGrace` で期限内なら控え） |
| e | 到達不可で `live` が `.readOnly(.unknown | .notSubscribed)` かつ `cached != nil` | **c**（控えの理由を保つ。例: 控えが `.readOnly(.revoked)` なら「返金済み」のまま、`.expired` なら「期限切れ」） |
| f | 到達不可で `cached == nil` かつ `!live.canEdit` | `.readOnly(.unknown)`（M5-26 の「確認中」。保存されない） |
| g | それ以外 | `live` |

`storeReachable == false` = App Store への問い合わせ（`products(ids:)` か `renewals(groupID:)`）が投げた。`Transaction.currentEntitlements` は端末内の控えから答えるので実際には live に権利が残ることが多い。

UserDefaults（**S が自己完結で持つ**。M5-34: S の最初の版が U の `AppSettings` に依存すると `TegakiCalendar` ターゲットが通らないため）: `UserDefaultsAccessCache(defaults: UserDefaults = .standard, key: String = UserDefaultsAccessCache.defaultKey)`、`static let defaultKey = "accessStateCache"`（`Data`。nil で `removeObject`）。`AppSettings` には控えの項目を**作らない**（キーの重複を避ける）。写真モードは `NoopAccessCache`（読まない書かない）。保存は `StoreModel` が `snapshot.access` を変えるたびに 1 回。**保存しない**のは `.readOnly(.unknown)` のときと `storeReachable == false` のとき（到達不可の答えで有効な控えを上書きしない）。`PrivacyInfo.xcprivacy` は UserDefaults（CA92.1）を既に申告済みなので変更なし（C が確認）。

```swift
// Sources/TegakiCalendar/Store/AccessCacheStore.swift（S）
protocol AccessCacheStore: Sendable {
    func load() -> AccessSnapshot?
    func save(_ snapshot: AccessSnapshot)
}
struct UserDefaultsAccessCache: AccessCacheStore {       // defaults.data(forKey: key) / set / removeObject
    static let defaultKey = "accessStateCache"
    init(defaults: UserDefaults = .standard, key: String = UserDefaultsAccessCache.defaultKey)
}
struct NoopAccessCache: AccessCacheStore {}              // 写真モード・テスト
```

### 1.4 更新・猶予・期限切れ・復元の扱い（S が実装、K の規則で判定）

- **自動更新**: `Transaction.updates` に新しい Transaction が届く（§2.4）→ `finish()` → `refresh()` → `until` が延びる。アプリは何も数えない。
- **解約**: 次の `refresh()`（起動・前面復帰・更新の通知）で `willAutoRenew == false` になり、設定の行が「有効期限」に変わる。期限までは `canEdit`。期限を過ぎた最初の `refresh()` で `.readOnly(.expired)`。**前面復帰のたびに `refresh()`**（`scenePhase == .active`。既存の `scenePhaseChanged()` から呼ぶ。U）。アプリを開いたまま期限をまたいだ場合は次の前面復帰まで書けるが、Apple の判定が正なので受け入れる（M5-9）。
- **猶予**: 支払い失敗 → `.inGracePeriod`（16 日、有料どうしの更新のみ。**無料試用 → 有料の最初の請求は対象外**で、失敗すると猶予なしに `.inBillingRetryPeriod` → `.readOnly(.billingRetry)`）→ `.subscribed(inGrace: true)`。バッジは出さず、設定 › 購入 に「請求に問題（猶予中）」と「お支払い方法を確認してください」（§4.3）。猶予が尽きる → `.inBillingRetryPeriod` → `.readOnly(.billingRetry)`（文言「お支払いに問題があります」）。Apple が再請求に成功すれば `Transaction.updates` で戻る。
- **返金・取消**: `.readOnly(.revoked)`。即日。実機で届く経路は `Transaction.updates`（取消された Transaction が `revocationDate` 付きで流れる。`StoreModel` が直近の写しとして保持し次の `resolve` に渡す → 規則 1）と `renewals` の `state == .revoked`（規則 7）。`currentEntitlements` からは来ない。
- **未完了の Transaction**: 購入直後にアプリが落ちた等で `finish()` されなかったものは `start()` で `Transaction.unfinished` を 1 回走査して `finish()`（`StoreClient.finishUnfinished()`。Apple の推奨手順）。
- **復元**: 「購入を復元」→ `AppStore.sync()`（Apple Account のサインインを求めることがある）→ `refresh()`。結果の文言は §2.5。同じ Apple Account の別端末では復元を押さなくても `currentEntitlements` に出る（SUPPORT「iPad を替えたとき」）。
- **月額 ⇄ 年額の切替**: Apple のサブスクリプション画面か、ペイウォールでもう一方を購入（`purchase` はグループ内の切替として処理され、Transaction が差し替わる）。アプリは特別扱いしない。

### 1.5 文言と数字の純関数・URL（K: `Access/PlanText.swift`、`Access/LegalLinks.swift`）

```swift
public enum PlanText {
    public static func name(_ plan: Plan) -> String                 // 「月額」「年額」
    public static func perPeriod(_ plan: Plan) -> String            // 「/月」「/年」
    /// floor(yearly の月数 12 − yearly / monthly)。300 / 2400 → 4。monthly ≤ 0 や yearly ≥ 12 × monthly なら 0
    public static func savingsMonths(monthly: Decimal, yearly: Decimal) -> Int
    /// 「4 か月分お得」。0 なら nil
    public static func savingsText(months: Int) -> String?
    /// yearly / 12 を 1 円に丸める: 2400 → 200
    public static func perMonth(yearly: Decimal) -> Decimal
    /// 設定 › 購入 の「現在のプラン」の値
    public static func statusTitle(_ access: AccessState) -> String
    /// 設定 › 購入 の日付行のラベル（readOnly は nil）
    public static func dateLabel(_ access: AccessState) -> String?
    /// 閲覧専用の理由の短い説明（設定の脚注の先頭。canEdit なら nil）
    public static func readOnlyNote(_ reason: ReadOnlyReason) -> String
    public static let yearlyBadge = "4 か月分お得"                  // 写真モードと KitChecks の固定値（実表示は savingsText）
    public static let readOnlyBadge = "閲覧専用"
    public static let cancelPath = "「設定」›「Apple Account」›「サブスクリプション」"   // 0-6。アプリ内は短い表記（規約・サポートは「（iPadOS 17 では「Apple ID」）」つき。M5-29）
    public static let paymentPath = "「設定」›「Apple Account」›「お支払いと配送先」"
}
public enum LegalLinks {
    public static let base = URL(string: "https://syfan0-star.github.io/tegaki-calendar/app/")!
    public static let terms = base.appending(path: "terms.html")
    public static let privacy = base.appending(path: "privacy.html")
    public static let support = base.appending(path: "support.html")
    /// Apple 標準の使用許諾契約（M5-8。審査 3.1.2(a) が説明欄とアプリ内に求める）
    public static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let appleEULATitle = "使用許諾契約（Apple 標準 EULA）"
    public static let supportEmail = "syfan0@gmail.com"              // M5-1
}
```

`statusTitle`: `.subscribed(inGrace: false)` → 「\(name)・有効」（「年額・有効」）; `.subscribed(inGrace: true)` → 「\(name)・請求に問題（猶予中）」; `.trial` → 「\(name)・試用中」; `.readOnly(.notSubscribed)` → 「未購入（閲覧専用）」; `.expired` → 「期限切れ（閲覧専用）」; `.billingRetry` → 「お支払いに問題（閲覧専用）」; `.revoked` → 「返金済み（閲覧専用）」; `.unknown` → 「確認中（閲覧専用）」。
`dateLabel`: `.subscribed(willAutoRenew: true, inGrace: false)` → 「次回更新」; `.subscribed(willAutoRenew: false)` → 「有効期限」; `inGrace` → 「猶予の期限」; `.trial(willAutoRenew: true)` → 「試用の終了（有料に移行）」; `.trial(willAutoRenew: false)` → 「試用の終了」; `.readOnly` → nil。
`readOnlyNote`: `.notSubscribed` → 「まだ購読していません。」; `.expired` → 「サブスクリプションの期限が切れています。」; `.billingRetry` → 「お支払いに問題があります。\(paymentPath)でお支払い方法を確認してください。」; `.revoked` → 「購入が返金または取り消されました。」; `.unknown` → 「購入の状態を確認できていません。回線が戻ると自動で確認します。」。

## 2. StoreKit 層（担当 S、`Sources/TegakiCalendar/Store/*`）

### 2.1 StoreClient（`Store/StoreClient.swift`）

```swift
struct StoreProduct: Equatable, Sendable {
    var id: String
    var displayPrice: String               // StoreKit の product.displayPrice。ja_JP の ICU では記号が全角「￥」(U+FFE5) になりうる。テストは数字だけで比べる（§7.3.1）
    var price: Decimal
    var subscriptionGroupID: String?       // product.subscription?.subscriptionGroupID（renewals の問い合わせに使う。Connect が付ける番号で .storekit の値とは違う）
    var isEligibleForIntroOffer: Bool      // product.subscription?.isEligibleForIntroOffer（await）
    var introDays: Int?                    // introductoryOffer が .freeTrial なら日数（P2W → 14）。無ければ nil
    /// product.priceFormatStyle で price / 12 を整形した「¥200」（年額だけ。月額は nil）
    var perMonthDisplayPrice: String?
}
enum StorePurchaseResult: Equatable, Sendable {
    case success(EntitlementInput)         // 検証済み。finish 済み
    case pending                           // 承認待ち（Ask to Buy）
    case cancelled                         // userCancelled
    case unverified                        // VerificationResult.unverified（finish しない）
}
protocol StoreClient: Sendable {
    func products(ids: Set<String>) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> StorePurchaseResult
    func currentEntitlements() async -> [EntitlementInput]              // 検証済みだけ
    /// Product.SubscriptionInfo.status(for: groupID)（iOS 15+ の静的 API。Product を要しないのでオフライン起動でも Product.products の失敗に引きずられない）
    func renewals(groupID: String) async throws -> [RenewalInput]
    /// Transaction.updates の写し（検証済みのものを finish してから流す。取消された Transaction も revocationDate 付きで流す）。StoreModel.start() が 1 本だけ購読する
    func updates() -> AsyncStream<EntitlementInput>
    /// Transaction.unfinished を 1 回走査し、検証済みのものを finish する（start() が updates の購読の直後に 1 回呼ぶ）
    func finishUnfinished() async
    func sync() async throws                                             // AppStore.sync()
}
```

### 2.2 LiveStoreClient（`Store/LiveStoreClient.swift`、`import StoreKit`）

- `products(ids:)`: `Product.products(for: ids)` → 各 `product` について `subscription?.subscriptionGroupID` を写し、`subscription?.isEligibleForIntroOffer` を `await`、`subscription?.introductoryOffer` が `paymentMode == .freeTrial` なら `period` を日数に（`.day` × value、`.week` × 7、`.month` × 30、`.year` × 365）、年額なら `product.priceFormatStyle.format(product.price / 12)`。並び順は `Plan.allCases` の順（年額を先に並べるのは U）。
- `purchase(productID:)`: `Product.purchase()` → `.success(.verified(t))` → `await t.finish()` → `.success(写し)`; `.success(.unverified)` → `.unverified`; `.pending` → `.pending`; `.userCancelled` → `.cancelled`。`Product` は直前の `products(ids:)` の結果を `[String: Product]` に保持（無ければ取り直す）。
- `currentEntitlements()`: `for await result in Transaction.currentEntitlements` の `.verified(t)` を写す（`.unverified` は捨てて `NSLog("store: unverified entitlement %@")`）。写し: `id = t.id`、`subscriptionGroupID = t.subscriptionGroupID`、`isIntroductory`: `if #available(iOS 17.2, *) { t.offer?.type == .introductory } else { t.offerType == .introductory }`。
- `renewals(groupID:)`: `try await Product.SubscriptionInfo.status(for: groupID)` の各 `status` について `status.renewalInfo` が `.verified(info)` なら写す（`state` は `status.state` を `RenewalState` に、`.subscribed` / `.expired` / `.inBillingRetryPeriod` / `.inGracePeriod` / `.revoked`、それ以外は `.unknown`; `productID = info.currentProductID`; **`renewalDate = if #available(iOS 18.0, *) { info.renewalDate } else { nil }`**（`renewalDate` は iOS 18.0 以降の API。配信対象 17.0 でこの分岐が無いとコンパイルエラー）; `latestTransaction = status.transaction` が `.verified(t)` なら `currentEntitlements()` と同じ写し、`.unverified` なら nil）。
- `finishUnfinished()`: `for await result in Transaction.unfinished { if case .verified(let t) = result { await t.finish() } }`。
- `updates()`: `AsyncStream { continuation in let task = Task { for await result in Transaction.updates { if case .verified(let t) = result { await t.finish(); continuation.yield(写し) } } }; continuation.onTermination = { _ in task.cancel() } }`。
- `sync()`: `try await AppStore.sync()`。
- DEBUG の `NSLog("store: …")`（環境 `t.environment`（`.xcode` / `.sandbox` / `.production`）、商品数、状態）。CI のログに残る（build.yml の `log show`）。

### 2.3 StoreModel（`Store/StoreModel.swift`）

```swift
struct PlanOffer: Equatable, Sendable {
    var plan: Plan
    var displayPrice: String               // 「¥2,400」
    var price: Decimal
    var isEligibleForIntroOffer: Bool
    var introDays: Int?
    var perMonthDisplayPrice: String?      // 年額だけ 「¥200」
}
enum StorePhase: Equatable, Sendable { case idle, loadingProducts, purchasing(Plan), restoring }
/// refresh() の起点。message を触るのは .paywall（ペイウォールの「再読み込み」）だけ
enum RefreshReason: Equatable, Sendable { case automatic, paywall }
enum StoreMessage: Equatable, Sendable {
    case purchased(Plan), restored, nothingToRestore, pending, productsUnavailable, failed(String)
}
struct StoreSnapshot: Equatable, Sendable {
    var access: AccessState                // 起動直後は AccessCache.stateForLaunch
    var offers: [PlanOffer]                // 年額・月額の順（U がこの順で並べる）。空 = 価格が取れていない
    var phase: StorePhase
    var message: StoreMessage?             // U がトースト／脚注に出し、clearMessage() で消す
    var storeReachable: Bool               // 最後に App Store へ問い合わせた呼び出し（products か renewals）が成功したか
    var refreshed: Bool                    // 最初の refresh() が 1 回完了した（§4.2 の初回ペイウォールの判定に使う）
}
@MainActor final class StoreModel: ObservableObject {
    @Published private(set) var snapshot: StoreSnapshot
    init(client: any StoreClient, cache: any AccessCacheStore, now: @escaping @Sendable () -> Date = Date.init)
    /// 通常起動用: LiveStoreClient + UserDefaultsAccessCache()。ScreenshotMode.isActive なら screenshotDemo（screenshotReadOnly で状態を選ぶ。呼び出し側の U が ScreenshotMode.current?.readOnly ?? false を渡す。S は Config.readOnly を参照しない。M5-34）
    static func make(screenshotReadOnly: Bool = false) -> StoreModel
    /// 写真モード・プレビュー用: 固定の offers（StoreStrings.demoMonthlyPrice / demoYearlyPrice / demoPerMonthPrice、eligible）、client は偽物、cache は Noop。refreshed は最初から true
    static func screenshotDemo(access: AccessState, eligible: Bool = true) -> StoreModel
    /// 1 回だけ: 控え → updates の購読開始 → finishUnfinished() → refresh()。2 回目以降は何もしない
    func start()
    /// products（必要なときだけ）→ currentEntitlements() → renewals → AccessPolicy.resolve → reconcile → 保存。走行中に呼ばれたら「終了を待ってもう 1 回走る」（needsRerun。古い結果に合流しない）
    func refresh(reason: RefreshReason = .automatic) async
    /// 最初の refresh() の完了を timeout まで待つ。完了していれば true、待ちきれなければ false
    func awaitFirstRefresh(timeout: Duration) async -> Bool
    func purchase(_ plan: Plan) async       // phase .purchasing → 結果を message に。成功なら access を先に更新してから refresh()
    func restore() async                    // phase .restoring → sync() → refresh() → .restored か .nothingToRestore
    func clearMessage()
    var isReadOnly: Bool { !snapshot.access.canEdit }
}
```

写真モードの `screenshotDemo` の既定: `screenshotReadOnly == false` → `.subscribed(Subscription(plan: .yearly, until: today + 200 日, willAutoRenew: true, inGrace: false))`、true → `.readOnly(.notSubscribed)`。`today` は `ScreenshotMode.current?.today`（既存の項目。S が参照してよいのは `ScreenshotMode.isActive` と `current?.today` だけ）。固定価格は `StoreStrings.demoMonthlyPrice = "¥300"` / `demoYearlyPrice = "¥2,400"` / `demoPerMonthPrice = "¥200"`（記号は U+00A5。実機の `displayPrice` は ja_JP で全角「￥」(U+FFE5) になりうるので、写真と実機で記号が違うことを docs/M5.md に書く。`PaywallSheetTests` もこの 3 定数を使う）。

### 2.4 起動時の監視と `refresh()` の順序

1. `start()`: `snapshot.access = AccessCache.stateForLaunch(cached: cache.load(), now: now())`（最初の 1 フレームからバッジが正しい）。`updatesTask = Task { for await input in client.updates() { recentUpdates[input.id] = input; await refresh() } }`（`recentUpdates: [UInt64: EntitlementInput]` はメモリだけ。取消された Transaction を次の `resolve` に渡す経路。規則 1）。`Task { await client.finishUnfinished(); await refresh() }`。
2. `refresh(reason:)`: 走行中なら `needsRerun = true` にして現在の走行の終了を待ち、終了後にもう 1 回走る（**古い結果に合流しない**。購入シートが閉じた前面復帰の `refresh` と `purchase` 後の `refresh` が重なっても、後の方が最新を読む）。本体: `products(ids: ProductIDs.all)` は **`offers` が空か前回の成功から 1 時間以上のときだけ** 呼ぶ（`phase = .loadingProducts` は `offers` が空のときだけ。成功 → `offers`（年額→月額）、`lastProductsAt = now()`、`storeReachable = true`; 失敗 → `storeReachable = false`、`offers` はそのまま、**`reason == .paywall` のときだけ** `message = .productsUnavailable`。通常の `refresh` は `message` を触らない: 購入直後の `.purchased` や復元の `.nothingToRestore` を上書きしない）→ `entitlements = currentEntitlements()` → `groupID = entitlements.first?.subscriptionGroupID ?? 直近の products の subscriptionGroupID`（どちらも無ければ renewals は呼ばず nil）→ `renewals = try? await renewals(groupID:)`（投げたら nil、`storeReachable = false`）→ `live = AccessPolicy.resolve(entitlements: entitlements + recentUpdates.values（id で重複排除）, renewals: renewals, now: now())` → `access = AccessPolicy.reconcile(live:cached: cache.load(), storeReachable:now:)` → `access` が `.readOnly(.unknown)` でなく `storeReachable == true` なら `cache.save(AccessSnapshot(state: access, savedAt: now()))` → `phase = .idle` → `refreshed = true`。
3. 前面復帰（U が `scenePhase == .active` で `Task { await store.refresh() }`）。
4. `purchase(_:)` の `.success(input)`: `recentUpdates[input.id] = input` → **先に** `snapshot.access = AccessPolicy.resolve(entitlements: [input] + 既知, renewals: 既知, now:)`（ペイウォールが閉じた瞬間にバッジが消え、`.purchased` の文言の `.trial` 判定も正しい）→ `message = .purchased(plan)` → `await refresh()`。

### 2.5 購入の流れと文言（`Store/StoreStrings.swift`）

| 結果 | `message` | 文言（U がトーストか脚注に） | ペイウォール |
| --- | --- | --- | --- |
| `.success` | `.purchased(plan)` | 「購読を開始しました。ありがとうございます」（試用なら「14 日間の無料試用を開始しました」= `access` が `.trial` のとき。§2.4 の 4 で `access` は `message` より先に更新される） | 閉じる |
| `.pending` | `.pending` | 「承認待ちです。承認されると自動で使えるようになります」 | 開いたまま（「あとで」で閉じられる） |
| `.cancelled` | nil | 何も出さない | 開いたまま |
| `.unverified` | `.failed(StoreStrings.unverified)` | 「購入を確認できませんでした。しばらくしてから「購入を復元」をお試しください」 | 開いたまま |
| `StoreKitError.networkError` / `URLError` | `.failed(StoreStrings.offline)` | 「App Store に接続できません。回線を確認してもう一度お試しください」 | 開いたまま |
| `StoreKitError.notAvailableInStorefront` | `.failed(StoreStrings.notAvailable)` | 「お住まいの地域ではこのプランを購入できません」 | 開いたまま |
| `StoreKitError.userCancelled` | nil | 何も出さない | 開いたまま |
| その他の `Error` | `.failed(StoreStrings.generic(error))` | 「購入できませんでした（\(error.localizedDescription)）」 | 開いたまま |
| `restore()` 成功で `canEdit` | `.restored` | 「購入を復元しました」 | 閉じる |
| `restore()` 成功で `!canEdit` | `.nothingToRestore` | 「復元できる購入がありません。購入したときと同じ Apple Account でサインインしているか確認してください」 | 開いたまま |
| `restore()` 失敗 | `.failed(…)` | 上の網羅と同じ文言 | 開いたまま |
| `products` 失敗（`refresh(reason: .paywall)` のときだけ） | `.productsUnavailable` | 「App Store から価格を取得できませんでした。回線を確認して「再読み込み」を押してください」 | 価格の代わりに「—」、CTA 無効、「再読み込み」ボタン（`offers.isEmpty` なら message の有無に関わらず出る） |

購入中（`.purchasing`）は CTA を `ProgressView` にし二重タップを防ぐ。復元中（`.restoring`）は「購入を復元」をスピナーに。

## 3. 閲覧専用モード（担当 U。InkCanvasView の 2 引数も U）

### 3.1 止める操作と仕組み

`CalendarRootScreen` に `@StateObject private var store = StoreModel.make(screenshotReadOnly: ScreenshotMode.current?.readOnly ?? false)`、`private var access: AccessState { store.snapshot.access }`、`private var readOnly: Bool { !access.canEdit }`。`SettingsScreen(...)` の呼び出し（341。既存は 1 か所だけ。Tests に `SettingsScreen(` は無い）に `store: store,` を足す（`scrollToSyncOnAppear` の次の行。§4.3）。判定の純関数（テスト用）:

```swift
enum GatedAction: Equatable, CaseIterable {
    case draw, erase, moveSelection, deleteSelection, convertSelection, createEvent, editEvent, deleteEvent,
         undoRedo, overlayTool, webImport,                       // 止める（11）
         eraseAll, settings, navigate, zoom, receiveCloud, viewEvent, pencilToggle,   // 許す
         export                                                   // 許す（将来の手書きの書き出し。M5 では使う場所が無い。M5-27 で予約）。許す = 8、全部で 19
}
extension CalendarRootScreen {
    /// 許す操作は access に依らず true。止める操作は access.canEdit
    static func isAllowed(_ action: GatedAction, access: AccessState) -> Bool
}
/// 止めた: 1 セッション 1 回はペイウォール（reason .blocked(action)）、2 回目以降はトースト（§3.3）。写真モードはトーストだけ
private func blocked(_ action: GatedAction)
```

| 操作 | 入口（file:line） | 仕組み |
| --- | --- | --- |
| 新しい線・消しゴム（Pencil・指） | `InkCanvasView` の PencilKit（`Ink/InkCanvasView.swift:416`、`516`） | **新引数 `readOnly: Bool = false`**。`canvas.drawingGestureRecognizer.isEnabled = !tool.isOverlayTool && !readOnly`（`attach` 416 行と `update(from:)` 516 行の両方。`readOnly` **だけ**が変わった（`appliedTool` が同じ）ときは `update(from:)` の `syncRecognizers()` から同じ式を当てる）。`drawingPolicy` は触らない（「描かない」値が無い）。`PKCanvasView.isUserInteractionEnabled` は **触らない**（スクロール・ピンチが死ぬ） |
| ペンで紙に触れたら案内 | 同上 | **新引数 `onBlockedInput: () -> Void = {}`** と `blockedInputRecognizer: UILongPressGestureRecognizer`（`lazy var`。`minimumPressDuration = 0`、`allowableMovement = .greatestFiniteMagnitude`、`allowedTouchTypes = [.pencil]`（指は対象外: iPhone の指スクロールで出ないように）、`cancelsTouchesInView = false`、`delegate = coordinator`、`attach` で `canvas.addGestureRecognizer`）。`isEnabled = readOnly`（`syncRecognizers()` で同期）。`.began` で `parent.onBlockedInput()`。**delegate の変更が必須**: `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)`（1117-1121 行）は現状 tap 以外に false を返すので、先頭に `if gestureRecognizer === blockedInputRecognizer || otherGestureRecognizer === blockedInputRecognizer { return true }` を足す（drawing・pan・pinch・tap と全部同時認識）。`shouldReceive touch`（1109 行）の guard は `blockedInputRecognizer` を通す（既定の true のまま）。U は `blocked(.draw)` を 2 秒に 1 回に間引く（`lastBlockedInputAt`） |
| 投げなわの移動・削除・予定にする | overlay（`Ink/InkOverlayView.swift`）、`selectionMenu(in:)` 439-461、`convertSelection()` 834 | InkCanvasView 内: `fingerRecognizer.isEnabled = tool.isOverlayTool && allowFinger && !readOnly`（`syncRecognizers()` 460 行の既存の式に `&& !readOnly`）。`overlay.isUserInteractionEnabled = tool.isOverlayTool && !readOnly` は **`overlay.tool = …` の直後**（`update(from:)` 514 行の次）に置く（InkOverlayView.swift 60 行の `tool` の didSet が `isUserInteractionEnabled = tool.isOverlayTool` で毎回上書きするため、順序を逆にすると効かない）。`readOnly` だけが変わったときも `syncRecognizers()` から同じ式を当てる。InkOverlayView.swift は触らない。U 側: 道具の Binding で投げなわ／予定を選べない（下）、`selectionMenu` は `!readOnly` のときだけ、`readOnly` に変わった瞬間に `send(.clearSelection)` |
| 予定ツール | `eventRectFinished(_:_:)` 793 | 道具の Binding で選べない。保険として関数の先頭に `guard isAllowed(.createEvent) else { blocked(.createEvent); return }`（タップで既存の予定 → `openEdit` は許す） |
| 道具の選択 | `ToolbarView(tool: $tool, …)` 317 | `tool: toolBinding`: setter で `readOnly && newValue.isOverlayTool` なら `blocked(.overlayTool)` して値を変えない。ペン・マーカーの色・太さの選択は許す（害がない）。`readOnly` になったとき `tool.isOverlayTool` なら `tool = lastInkTool` |
| 元に戻す／やり直す | `ToolbarView(onUndo:onRedo:)` 322-323 | `canUndo: canUndo && !readOnly`、`canRedo: canRedo && !readOnly`（ボタンが灰色）。`onUndo` / `onRedo` の先頭に guard（保険） |
| ＋予定 | `addEvent()` 820 → `openCreate` | `openCreate(range:snapshot:inkIds:)` 842 の **先頭**（`model.status.canRead` の guard より前）に `guard isAllowed(.createEvent) else { blocked(.createEvent); return }`。`addEvent` / `eventRectFinished` / `convertSelection` / 帯の `onColumnTap` 286 / 写真モードの `.create` を全部ここで止める |
| 予定の編集・削除 | `openEdit(eventId:)` 864、`editorSheet(_:)` 463-474、`handleSubmit` 891-926 | `openEdit`: `let mode = readOnly ? .readOnly(eventId:) : (既存の式)`（閲覧シートは開く = `.viewEvent` は許す）。`editorSheet(_:)`: `EventEditorSheet(…, readOnlyNote: readOnly ? EventEditorSheet.subscriptionNote : nil, onSubscribe: readOnly ? { editor = nil; after(sheetGap) { showPaywall(reason: .blocked(.editEvent)) } } : nil)`（§3.3。`blocked()` を通さず直接出す: 明示的なタップなので毎回出す）。`handleSubmit` の `.save` / `.delete`: `guard isAllowed(.editEvent) else { editor = nil; blocked(.editEvent); return }`（保険） |
| タップで編集 | `handleTap(at:)` 746、`AllDayBandView(onBarTap:)` 285 | 変えない（`openEdit` が閲覧になる） |
| Web 取り込み | `importWeb()` 958 | 先頭に `guard isAllowed(.webImport) else { showSettings = false; blocked(.webImport); return }`（設定を閉じてからペイウォール）。設定の行は `readOnly` のとき `.foregroundStyle(.secondary)` で残す（押せる。押すと案内） |
| 全て消す | `eraseAllInk()` 933 | **許す**（変えない） |
| Pencil ダブルタップ | `togglePencilTool()` 768 | 許す（道具が変わるだけ） |
| ページ移動・拡大・iCloud 受信・設定 | `move` / `show` / `applyRemote` / `showSettings` | 許す（変えない） |
| 初回案内・アクセスの案内 | `appear()` 549、`accessNotice` 487 | 変えない |

**InkCanvasView で触ってよい場所**（これ以外は触らない。P が居ないので U が最小限で入る）: ① 新引数 `readOnly` / `onBlockedInput`（既定値つき。`InkCanvasView` の既存引数の末尾）② `Coordinator` の `lazy var blockedInputRecognizer` ③ `attach` の 416 行前後（`drawingGestureRecognizer.isEnabled` の式と `addGestureRecognizer(blockedInputRecognizer)`）④ `syncRecognizers()` 455-464 行（`fingerRecognizer`・`blockedInputRecognizer`・`drawingGestureRecognizer`・`overlay?.isUserInteractionEnabled` の 4 つを `readOnly` 込みの式で揃える）⑤ `update(from:)` 505-526 行（`overlay?.tool = …` の直後の 1 行と 516 行の式）⑥ delegate の 1109 行と 1117-1121 行。

### 3.2 「閲覧専用」バッジ（`Views/PageHeaderView.swift`）と iPhone の案内行

```swift
struct PageHeaderView: View {
    // 既存の引数はそのまま（width の後ろに 2 つ足す。既定値つき）
    var readOnly: Bool = false
    /// バッジのタップ: ペイウォール（reason .badge）
    var onReadOnlyTap: () -> Void = {}
    /// この幅未満ではバッジは記号（lock.fill）だけ（☁ が記号だけになる幅と同じ。11 インチ縦 834 と mini 744 は記号だけ、13 インチ縦 1024 と 11 インチ横 1194 は文字つき）
    static let readOnlyTextWidth: CGFloat = syncTextWidth        // 980（M5-32。760 にすると 11 インチ縦の日ページの題名（PageHeaderView 42-44 行の注記）がさらに縮む）
}
```

- 広い行（`!compact`）: `addEventButton` の **左** に `readOnlyBadge`（`Button(action: onReadOnlyTap)`、`.buttonStyle(.bordered)`、`.tint(.orange)`、`.controlSize(.small)`、`.fixedSize()`、`.layoutPriority(1)`。中身は `Label(PlanText.readOnlyBadge, systemImage: "lock.fill").font(.footnote)`、`width < readOnlyTextWidth` なら `Image(systemName: "lock.fill")` だけ）。`accessibilityLabel` = 「閲覧専用。購読の案内を開く」。
- compact（iPhone、幅 < 600）: 1 段目に入らない（残り約 79 pt。M4B-15）ので **バッジは出さない**（`readOnlyBadge` は `!compact` だけ）。代わりに `CalendarRootScreen` が `accessNotice` の直後に `readOnlyNotice`（`noticeRow("閲覧専用です。手書きと予定の作成は購読すると使えます。", buttonTitle: "購読する") { showPaywall(reason: .badge) }`、`compact && readOnly` のとき）。iPad の広い行では案内行を出さない（バッジだけ）。
- `isError` 相当の色は使わない（閲覧専用はエラーではない）。猶予中（`inGrace`）はバッジを出さない（`canEdit` のまま）。

### 3.3 文言

| 場面 | 文言 |
| --- | --- |
| バッジ | 「閲覧専用」（記号 `lock.fill`） |
| iPhone の案内行 | 「閲覧専用です。手書きと予定の作成は購読すると使えます。」 ボタン「購読する」 |
| 止めた操作の 2 回目以降（トースト、3 秒、isError false） | 「閲覧専用です。書く・消す・予定を作るには購読が必要です」 |
| ペイウォールの先頭（reason `.blocked`、理由が `.notSubscribed` / `.expired` / `.unknown`） | 「書く・消す・予定を作るには購読が必要です。」（試用資格ありなら続けて「14 日間無料で試せます。」） |
| ペイウォールの先頭（`access == .readOnly(.billingRetry)`。reason に依らず） | 「お支払いに問題があります。\(PlanText.paymentPath)でお支払い方法を確認してください。」＋ CTA の上に〔サブスクリプションを管理〕（`.manageSubscriptionsSheet`。購入ではなく支払い方法の修正が要るので二重購入を防ぐ） |
| ペイウォールの先頭（`.readOnly(.revoked)`） | 「購入が返金または取り消されました。再び使うには購読してください。」 |
| 閲覧シート（`.readOnly(eventId:)`）の脚注（閲覧専用モードのとき） | **「予定の作成・編集は購読すると使えます。」＋ボタン「購読する」**（`EventEditorSheet.subscriptionNote`。既存の「このカレンダーは変更できません（読み取り専用）」（EventEditorSheet 164 行）はカレンダー側の権限の意味で、購読切れの人に誤った原因を伝えるため差し替える。新引数 `var readOnlyNote: String? = nil`（nil なら既存文言）、`var onSubscribe: (() -> Void)? = nil`（nil ならボタン無し）。他は触らない。M5-31） |

## 4. 購入画面と設定（担当 U）

### 4.1 PaywallSheet（`Views/PaywallSheet.swift`）

```swift
enum PaywallReason: Equatable { case firstLaunch, blocked(GatedAction), settings, badge }
struct PaywallSheet: View {
    @ObservedObject var store: StoreModel
    var reason: PaywallReason = .settings
    /// 「あとで」・スワイプ・購入成功の後
    var onClose: () -> Void
    @State private var selected: Plan = .yearly
    @Environment(\.openURL) private var openURL

    // 純関数（テスト §7.6）
    /// readOnlyReason が .billingRetry / .revoked なら reason に依らず §3.3 のその文言
    static func lead(_ reason: PaywallReason, eligible: Bool, readOnlyReason: ReadOnlyReason? = nil) -> String
    static func ctaTitle(eligible: Bool) -> String                         // 「14 日間無料で試す」 / 「購入する」
    static func trialLine(eligible: Bool) -> String
    static func priceLine(_ offer: PlanOffer) -> String                    // 「¥2,400/年」「¥300/月」
    static func yearlyNote(_ yearly: PlanOffer, monthly: PlanOffer?) -> String?   // 「月あたり ¥200・4 か月分お得」
    static func afterLine(_ offer: PlanOffer, eligible: Bool) -> String    // 「試用後は ¥2,400/年。いつでも解約できます。」 / 「¥2,400/年。自動更新です。いつでも解約できます。」
    /// 請求時期の文を試用資格で出し分ける（資格ありの人に「購入の確認時に請求」と書くと試用の行と矛盾し、3.1.2 と景表法の両方で危ない）
    static func disclosure(eligible: Bool) -> String
    static let features: [String]
}
```

並び（上から。`NavigationStack` の中、`ScrollView`、`.presentationDragIndicator(.visible)`。iPad は標準のフォームシート、iPhone は全高）:

1. 題名 **「てがきカレンダー」**（`.title.weight(.semibold)`）。
2. `lead(reason, eligible:, readOnlyReason: access の理由)`: `.billingRetry` / `.revoked` → §3.3 のその文言（reason に依らず）。それ以外: `.firstLaunch` / `.settings` / `.badge` → 「iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。」; `.blocked` → §3.3。`.billingRetry` のときは CTA の上に〔サブスクリプションを管理〕（`.bordered`。`showManage = true` → `.manageSubscriptionsSheet(isPresented: $showManage)`）。
3. `features`（`Label` 3 行）: 「手書き（ペン・マーカー・消しゴム・投げなわ）」「手書きから予定を作る。予定の作成・編集」「iCloud で iPad・iPhone と同期」。
4. プランのカード 2 枚（年額が上。選択中は `accentColor` の枠）: 左に `PlanText.name`、右に `priceLine`。年額のカードの下に `yearlyNote`（`savingsText(savingsMonths(monthly: monthly.price, yearly: yearly.price))` が nil なら「月あたり ¥200」だけ）。カードの右上に小さなタグ「おすすめ」（年額だけ）。`offers` が空なら価格は「—」と「価格を取得できません」。
5. `trialLine`: eligible → 「**14 日間無料でお試し。** 試用期間が終わると自動的に有料になります。試用中に解約すれば料金はかかりません。」; not eligible → 「無料試用の対象外です（お試しは 1 つの Apple Account につき 1 回）。」（`.footnote`、`.secondary`）。eligible は `selected` の offer の `isEligibleForIntroOffer`（グループ単位なので 2 つは同じ値になる）。
6. CTA（`.borderedProminent`、`.controlSize(.large)`、幅いっぱい）: `ctaTitle(eligible:)`。押すと `Task { await store.purchase(selected) }`。`store.snapshot.phase == .purchasing` なら `ProgressView`。`offers.isEmpty` なら無効＋その下に「再読み込み」（`Task { await store.refresh(reason: .paywall) }`。`.productsUnavailable` の文言はこの経路でだけ立つ。§2.4）。
7. `afterLine`（`.footnote`）。
8. `disclosure(eligible:)`（`.caption`、`.secondary`）: **「サブスクリプションは自動更新です。現在の期間が終わる 24 時間前までに解約しない限り、同じ期間・同じ価格で更新され、Apple Account に請求されます。\(請求時期の文)解約は端末の\(PlanText.cancelPath)からいつでもできます。解約しても、支払い済みの期間が終わるまで使えます。」** 請求時期の文: eligible → **「料金は無料試用の終了時に請求されます。」**、not eligible → **「料金は購入の確認時に請求されます。」**。
9. ボタン行（`.footnote`。2 行）: 1 行目 `HStack` 〔購入を復元〕（`Task { await store.restore() }`、復元中はスピナー）／〔利用規約〕（`openURL(LegalLinks.terms)`）／〔プライバシーポリシー〕（`LegalLinks.privacy`）。2 行目 〔使用許諾契約（Apple 標準 EULA）〕（`openURL(LegalLinks.appleEULA)`。`LegalLinks.appleEULATitle`。3.1.2(a): ライセンスは Apple 標準 EULA のままなのでアプリ内からも開ける。M5-8）。
10. 〔あとで〕（`.toolbar` の `.cancellationAction` にも、末尾の `Button("あとで")` にも。両方 `onClose`）。

`store.snapshot.message` の表示: `.purchased` / `.restored` → `onClose()` し、親がトースト（§2.5 の文言）。それ以外 → シート内の CTA の下に赤字（`.failed`）か灰字（`.pending` / `.nothingToRestore` / `.productsUnavailable`）で出し、`onDisappear` で `store.clearMessage()`。価格は **必ず `displayPrice`**（固定文字列は写真モードの `screenshotDemo` の中だけ）。

### 4.2 出るとき・閉じるとき（`CalendarRootScreen`）

- `@State private var showPaywall = false`、`@State private var paywallReason: PaywallReason = .settings`、`@State private var blockedPaywallShownThisSession = false`、`@AppStorage(AppSettings.paywallShownAfterOnboardingKey) private var paywallShownAfterOnboarding = false`（`AppSettings.paywallShownAfterOnboardingKey = "paywallShownAfterOnboarding"`、`Bool`、既定 false）。
- `sheetIsUp`（240）に `|| showPaywall` を足す。`.sheet(isPresented: $showPaywall) { PaywallSheet(store: store, reason: paywallReason, onClose: { showPaywall = false }) }`。
- `showPaywall(reason:)`: 他のシートが上がっていれば閉じて `sheetGap`（0.35 秒）後に出す（`importWeb()` と同じ流儀）。
- **初回案内の後に 1 回（未購読と確認できたときだけ。M5-33）**: `fullScreenCover` の `OnboardingView` のクロージャ（363-367）の末尾で `scheduleFirstLaunchPaywall()`。`appear()`（549-555）で案内を出さない分岐（`onboardingDone` 済み = 0.5.2 からの更新・再インストール・新しい端末、または `status != .notDetermined`）でも同じ関数。`scheduleFirstLaunchPaywall()`: `guard !ScreenshotMode.isActive, !paywallShownAfterOnboarding else { return }`; `Task { try? await Task.sleep(for: .seconds(Self.sheetGap)); let done = await store.awaitFirstRefresh(timeout: .seconds(3)); let s = store.snapshot; if done && s.access.canEdit { paywallShownAfterOnboarding = true; return }（購読者には出さない。§8-6 の 9 と整合）; guard done, !s.access.canEdit, s.storeReachable, !s.offers.isEmpty else { return }（待ちきれない・回線なし・価格が無い → 出さない。フラグは false のままで次の起動に持ち越す。価格「—」の画面を初対面にしない）; paywallShownAfterOnboarding = true; showPaywall(reason: .firstLaunch) }`。`paywallShownAfterOnboarding` を true にするのは**実際に出したとき**と**購読中と確認できたとき**だけ。`accessNotice` の「許可する」（493）で案内を再表示した場合は 2 回目にならない（キーで守る）。
- **止めた操作**: `blocked(action)`: `!blockedPaywallShownThisSession` → `blockedPaywallShownThisSession = true; showPaywall(reason: .blocked(action))`; それ以外 → `showToast(§3.3 のトースト)`。写真モード（`ScreenshotMode.isActive`）は常にトースト。
- **設定 › 購入**（§4.3）の「購読する」: `onShowPaywall` → 設定を閉じて `sheetGap` 後に `showPaywall(reason: .settings)`。
- **バッジ・案内行**: `showPaywall(reason: .badge)`。
- `start()`: `appear()` の先頭近くで `store.start()`（`scheduleFirstLaunchPaywall()` より前）。`scenePhaseChanged()`（575）の `.active` で `Task { await store.refresh() }`。
- 購入成功のトースト: `.onChange(of: store.snapshot.message)` で `.purchased` → `showToast(…)`、`.restored` → `showToast(…)`、どちらも `store.clearMessage()`（シートが閉じた後に出る）。

### 4.3 設定 › 購入 と 設定 › 情報（`Views/SettingsScreen.swift`）

新しい引数（`scrollToSyncOnAppear` の後ろ）: **`@ObservedObject var store: StoreModel`（必須。既定値は付けない。`Optional` は `@ObservedObject` にできない）**、`var onShowPaywall: () -> Void = {}`、`var scrollToPurchaseOnAppear: Bool = false`（写真用に予約。M5 では使わない）。呼び出し側は `CalendarRootScreen` 341 の 1 か所だけ（§3.1）で、Tests に `SettingsScreen(` は無いので既存のテストは壊れない。

```swift
extension SettingsScreen {
    static func planText(_ access: AccessState) -> String             // PlanText.statusTitle
    static func dateLabel(_ access: AccessState) -> String?           // PlanText.dateLabel
    static func dateText(_ date: Date, locale: Locale = .current) -> String   // Date.FormatStyle(date: .numeric, time: .omitted).locale(locale) → ja_JP で 「2026/10/25」
    static func purchaseFooter(_ access: AccessState) -> String
    static func purchaseButtonTitle(_ access: AccessState, eligible: Bool) -> String?   // readOnly: 「14 日間無料で試す」/「購読する」、それ以外 nil
}
```

`purchaseSection`（`preparingRow` 3 行を置き換え。順序は DESIGN §2.8）:

| 行 | 内容 |
| --- | --- |
| 現在のプラン | 右に `planText(access)`（`.secondary`。`.billingRetry` / `inGrace` は `Color.red`） |
| `dateLabel(access)`（nil なら行なし） | 右に `dateText(access.until!)` |
| 「購読する」/「14 日間無料で試す」（readOnly のときだけ） | `Button(purchaseButtonTitle)` → `onShowPaywall()`。eligible は `store.snapshot.offers.first?.isEligibleForIntroOffer ?? false` |
| サブスクリプションを管理 | `Button` → `showManage = true`、`.manageSubscriptionsSheet(isPresented: $showManage)`（iOS 17 の修飾子。写真モードでは何もしない）。readOnly でも押せる（解約済みの確認用） |
| 購入を復元 | `Button` → `Task { await store.restore() }`、`store.snapshot.phase == .restoring` でスピナー。結果は脚注の下に `store.snapshot.message` の文言（§2.5）を 1 行（`.failed` は赤） |

`purchaseFooter`: `canEdit && !inGrace` → 「解約は端末の\(PlanText.cancelPath)から。解約しても期間の終わりまで使えます。」（試用中はさらに「試用中に解約すれば料金はかかりません。」）; `inGrace` → 「お支払いに問題があります。端末の\(PlanText.paymentPath)でお支払い方法を確認してください。猶予の期限までは使えます。」; readOnly → `PlanText.readOnlyNote(reason)` ＋「閲覧専用では、予定と手書きの閲覧、ページ移動、拡大、iCloud からの受信、この iPad の手書きを全て消す、設定の変更ができます。新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みは購読すると使えます。」。

`infoSection`: `Link("利用規約", destination: LegalLinks.terms)` / `Link("プライバシーポリシー", destination: LegalLinks.privacy)` / `Link(LegalLinks.appleEULATitle, destination: LegalLinks.appleEULA)` / `Link("サポート", destination: LegalLinks.support)`。`SettingsScreen.termsURL` / `privacyURL` / `supportURL`（39-42）は **削除**（参照はこの 3 行だけ）。バージョン行はそのまま（「0.6.0 (N)」）。`dataSection` の「Web 版の手書きを取り込む」は §3.1 のとおり（readOnly なら灰色だが押せる）。**`dataSection` の `preparingRow("手書きを書き出す")`（368 行）は外す**（M5-27: 有料化した版に「準備中」の行が残ると審査 2.1（未完成・プレースホルダー）の指摘対象になる。提供開始時に本物の行を入れる。`preparingRow` 自体は参照が無くなるので削除）。

## 5. 規約類（担当 L: iOS リポジトリの 3 文書、担当 W: Web リポジトリの HTML）

### 5.1 L が直すこと（`docs/TERMS.md` / `PRIVACY.md` / `SUPPORT.md`。平易な日本語。「下書き」を外し公開版に）

共通: 見出しの「（下書き）」を外す。AI 注記（> **注記**: … Claude が下書き …）は **公開版から外し**、代わりに文書末尾に「作成の経緯: この文書は開発者が AI の下書きをもとに作成し、内容を確認しています。」の 1 行（M5-5 既定。専門家の確認は本人の任意 §9）。【support@example.com】→ `syfan0@gmail.com`。【氏名】→ 本人の戸籍上の氏名（**リードが L の着手前に本人に確認して渡す**。届かないうちは `【氏名】` のまま進め、W の `npm run check:legal` が `【` を禁じるので公開前の関門になる。`npm test` はこの検査を含まないので氏名が無くても緑にできる。M5-6、M5-35）。相互リンクは相対 Markdown のまま（`TERMS.md` → `PRIVACY.md`）で、W が `.html` に差し替える。最終更新は L が仕上げた日。施行日は日付を書かず **「本アプリの App Store 公開日に施行します」**（公開後に Web を直す工程を無くす。M5-36）。解約手順は全部 **「設定」›「Apple Account」›「サブスクリプション」（iPadOS 17 では「Apple ID」）**（0-6）。「設定」→ 自分の名前 → … の形は**全部**「設定」›「Apple Account」› …（iPadOS 17 では「Apple ID」）に置換（TERMS 48 行、SUPPORT 70・88・95 行、PRIVACY 74 行）。「返事はふつう 3 営業日以内」は **「ふつう 3 営業日以内を目安に」** に弱める（SUPPORT 3・24 行。個人運営で守れないと約束違反になる。M5-36）。

TERMS.md:

| 条 | 変更 |
| --- | --- |
| 要約 | 「アプリをやめるときは 90 日前にお知らせし、手書きを書き出す手段を残します」→「…90 日前にお知らせし、その時までに手書きを書き出す手段を用意します」（第 8 条 2 項と同じ時点） |
| 第 1 条 2 項 | Apple の契約の名称に続けて URL を明記し、関係を一文で: 「本アプリの使用許諾（ライセンス）は Apple の標準の使用許諾契約（Licensed Application End User License Agreement、<https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>）によります。本規約は、それに加えてサービスの内容・料金・責任の範囲を定めるものです。食い違いがある場合、Apple との関係については Apple の契約が優先します」（M5-8。審査 3.1.2 でリンク先と Connect の宣言が一致する） |
| 第 3 条 4 項 | 「日本の祝日の表示、手書きの書き出し（PDF・画像などへの保存）など」→「日本の祝日の表示、Web 版「手書きカレンダー」からの手書きの取り込み。手書きの書き出し（データファイル・PDF・画像）は**順次提供**します（提供状況は App Store の説明とサポートページに記載）」（0-5） |
| 第 5 条 1 項 | 【例…】を「月額 300 円（1 か月ごと）／年額 2,400 円（1 年ごと。月あたり 200 円）。いずれも税込。価格は App Store の表示が正です」に。「14 日間の無料試用つき（第 4 項）」 |
| 第 5 条 3 項 | 解約手順を 0-6 の表記に。「解約しても、支払い済みの期間が終わるまでは使えます」はそのまま。「期間の途中で解約しても、残りの期間分は返金されません」→「期間の途中で解約しても、原則として残りの期間分は返金されません（返金の可否は Apple が判断します）」（同じ項の「返金は Apple のルール」と矛盾しないように）。1 文を**足す**: 「本アプリのサブスクリプションの販売者は Apple（日本では iTunes 株式会社）です。購入は Apple メディアサービス利用規約（<https://www.apple.com/jp/legal/internet-services/itunes/jp/terms.html>）に基づいて行われ、特定商取引法に基づく表記はその規約に含まれる Apple の表示によります。開発者は本アプリの提供者として、本規約の範囲で責任を負います。」（M5-28。会社名と URL はリードが Connect の Paid Apps Agreement の相手方名で確認して確定する。確認までは `【Apple の販売会社名】` の置き場にせず上の表記で書き、違っていればリードが L に差し戻す） |
| 第 5 条 4 項 | 【日数】→ 14。「（1 つの Apple Account につき 1 回。以前に試用した方は購入と同時に料金がかかります）」を足す |
| 第 5 条 5 項 | 「閲覧専用」の内容を §3 の表に揃える: できる = 予定と手書きの閲覧、ページの移動と拡大、iCloud からの受信、この iPad の手書きを全て消す、設定の変更。できない = 新しく書く・消す・動かす、手書きから予定を作る、予定の作成・編集・削除、Web 版からの取り込み。「手書きの書き出しはできます」を**外し**、代わりに「現在、手書きの書き出し機能は未提供です（提供予定）。iPad のバックアップと iCloud が控えになります」（0-5、M5-27）。足す 2 文: 「購読の状態によって、開発者があなたの手書きや設定を消したり、見られなくしたりすることはありません。」「有料の期間の更新時にお支払いに問題があるときは、Apple の請求猶予期間（最長 16 日）の間は引き続き使えます（無料試用から有料に移る最初のお支払いは除きます。その場合はお支払いが確認されるまで閲覧専用になります）。」（M5-3） |
| 第 5 条 7 項 | 「アプリの設定 › 購入 › 「購入を復元」を押してください」 |
| 第 8 条 2 項 | 「終了までの間、手書きの書き出し機能を使える状態に保ちます」→「終了の 90 日前までに、手書きを書き出す手段（データファイル、または PDF・画像）を用意し、終了まで使える状態に保ちます」（この約束の裏付けは M6 の書き出しの実装（M5-27）。C が docs/M5.md に「第 8 条 2 項の根拠 = M6 の書き出し」と書く） |
| 第 9 条 5 項 | 「こまめに書き出し（第 3 条 4 項）や」→「iPad のバックアップや iCloud で控えを取っておくこと（書き出し機能の提供後はそれも）」 |
| 第 13 条 | 「開発者（販売者）」→ **「開発者（提供者）」**（販売者は Apple。M5-28）。氏名・メール・サポートページ（公開後の URL `https://syfan0-star.github.io/tegaki-calendar/app/support.html`） |
| 付則 | 「本アプリの App Store 公開日に施行します」（日付は書かない。M5-36） |

責任の範囲（本人の決定「責任の範囲を明示」）は第 4 条（データは手元だけ。開発者は閲覧・復元不可）、第 7 条（個人・最善努力・Apple/Google の仕様変更）、第 8 条（終了 90 日前）、第 9 条（故意重過失は免責しない、軽過失は直近 12 か月の支払額が上限、消費者契約法の権利は制限しない）、第 12 条（日本法）に既に書いてある。L は表現を変えず、第 9 条 4 項に「App Store のサブスクリプションの請求・更新・返金は Apple が行い、開発者はその処理に関与できません」を足す。

PRIVACY.md:

| 節 | 変更 |
| --- | --- |
| 要約・1 節 | 通信先は iCloud と App Store だけ（正しい）。1 節に 1 文足す: 「iCloud の変更を知るために Apple のプッシュ通知の仕組み（サイレント通知）を使いますが、画面に通知は表示されず、通知に内容も含まれません」（`UIBackgroundModes: remote-notification` を使っているため。設定アプリの「通知」の項目を見た人が差を感じないように） |
| 2 節の表 | 「購読の状態」の行を「購読の状態（Apple が管理。アプリは Apple から「有効か」と期限を受け取る）」に直し、1 行足す: 「購読の状態の控え（最後に確認した状態と日時）｜端末内（UserDefaults）｜見えません」（D2 のキャッシュ） |
| 5 節 | 「開発者が Apple から受け取るのは、個人を特定できない形の売上の集計だけです」はそのまま。「無料試用の資格（以前に試用したか）は Apple が判定し、アプリには「対象か否か」だけが伝わります」を足す |
| 9 節 | 「すべての手書きを削除」→「この iPad の手書きを全て消す」（0-8）。iCloud の手順の表記（74 行）を「設定」›「Apple Account」›「iCloud」›「アカウントのストレージを管理」›「てがきカレンダー」（iPadOS 17 では「Apple ID」）に（0-6 と同じ流儀） |
| 11 節 | 氏名・メール・サポートページの URL |
| 付録 A | 「Web 版のポリシー」の URL はそのまま（`https://syfan0-star.github.io/tegaki-calendar/privacy.html`） |
| 付録 B | 「プライバシーポリシーの URL」= `https://syfan0-star.github.io/tegaki-calendar/app/privacy.html`。「`project.yml` に入れてある文」の段落と「プライバシーマニフェストは Claude が用意します」の行は**開発メモなので公開版から削る**（文面自体（カレンダー権限の説明）は残す） |

SUPPORT.md:

| 箇所 | 変更 |
| --- | --- |
| 問い合わせ窓口 | メール `syfan0@gmail.com`。「返事はふつう 3 営業日以内」→「返事はふつう 3 営業日以内を目安に」（3・24 行。M5-36） |
| 同期しない・データを消す・iPad を替えたとき | 「設定」→ 自分の名前 →「iCloud」… を「設定」›「Apple Account」›「iCloud」…（iPadOS 17 では「Apple ID」）に（70・88・95 行。0-6） |
| 対応すること | 「購入・解約・購入の復元のやり方の案内」はそのまま。「Web 版からの引っ越し（移行ツール）」→「Web 版からの手書きの取り込みの案内」 |
| FAQ「解約するには？」 | 手順を 0-6 の表記に。「無料試用の途中で解約すれば料金はかかりません。試用期間の終わる 24 時間前までに」はそのまま |
| FAQ「無料試用が終わったら、手書きは消えますか？」 | 「予定と手書きの閲覧はそのままできます。新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みが止まるだけです。手書きの書き出しは提供開始後、閲覧専用でも使えるようにする予定です」 |
| FAQ 新規「購入を復元するには？」 | 「アプリの設定 › 購入 › 「購入を復元」。購入したときと同じ Apple Account でサインインしていることを確認してください。復元できる購入が無いと表示されたら、「設定」›「Apple Account」›「サブスクリプション」に「てがきカレンダー」があるか確認してください」 |
| FAQ 新規「支払いに問題があると表示される」 | 「カードの期限切れなどで有料の期間の更新に失敗すると、Apple が最長 16 日の猶予期間に再請求を試みます。その間は使えます。「設定」›「Apple Account」›「お支払いと配送先」（iPadOS 17 では「Apple ID」）でお支払い方法を更新してください。猶予が過ぎると閲覧専用になり、支払いが通ると元に戻ります。無料試用から有料に移る最初のお支払いに失敗した場合は猶予期間が無く、お支払いが確認されるまで閲覧専用になります」（M5-3） |
| FAQ「自分のデータを全部消すには？」 | 「すべての手書きを削除」→「この iPad の手書きを全て消す」（0-8）。「iCloud が使える状態なら iCloud の分も消え、ほかの端末からも消えます（確認が 2 回出ます）」 |
| FAQ「Web 版の手書きを iPad アプリに移したい」 | 【準備中】を手順に（0-9）: ① Web 版の設定で「手書きを書き出す（iPad アプリ用）」→ 1 つの JSON ファイルが「ファイル」アプリに入る ② アプリの 設定 › データ › 「Web 版の手書きを取り込む」でそのファイルを選ぶ ③ 月・週・日・年の 4 ページに Web 版と同じ位置で入る。同じファイルを二度取り込んでも二重にならない。Web 版で消した線は戻らない。取り込みは購読中（試用中）に行う |
| 既知の制限 | 「手書きの書き出し｜未提供（提供予定）。提供まで iPad のバックアップと iCloud が控えになります。閲覧専用でも使えるようにします」を 1 行足す（アプリの設定からは「準備中」の行を外したので、ここが唯一の案内。M5-27） |
| お知らせ | 「現在、重要なお知らせはありません。」 |

### 5.2 W が作るもの（Web リポジトリ、ブランチ `m5-legal`）

- パス: `app/terms.html`、`app/privacy.html`、`app/support.html`、`app/index.html`（3 つへのリンクだけの短い目次。「てがきカレンダー（iPad アプリ版）の文書」）。
- 様式は `privacy.html`（1-28 行）と同じ: `<!doctype html>`、`<html lang="ja">`、同じ `meta viewport`、同じ CSP（`default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:`）、`<link rel="icon" href="../icons/favicon-32.png">`（1 段深いので `../`）、同じインライン CSS（`:root` の 5 変数、`main{max-width:720px}`、h1 26 px、h2 19 px 上罫線、`.meta` 14 px、`a`、`code`）＋ `table{border-collapse:collapse;width:100%;font-size:15px} th,td{border:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}`（規約の表のため）＋ `h3{font-size:16px;margin:20px 0 6px}`。`<title>` は「利用規約 — てがきカレンダー」「プライバシーポリシー — てがきカレンダー」「サポート — てがきカレンダー」。`.meta` は「てがきカレンダー（iPad アプリ版）／最終更新：YYYY年M月D日」（L の最終更新と同じ日付）。
- 本文は L の Markdown を **そのまま** HTML に（見出し `h2`（条）・`h3`、段落、`ul`/`ol`、表は `table`。文言の改変は禁止。L の文書で引用 `>` にした部分は `<p class="meta">`）。相対リンク: `TERMS.md` → `terms.html`、`PRIVACY.md` → `privacy.html`、`SUPPORT.md` → `support.html`、`APPLE_ENROLLMENT.md` / `DESIGN.md` へのリンクは **外す**（公開文書に不要。文字だけ残す）、Web 版ポリシー → `../privacy.html`。`#` 付きのアンカーは見出しに `id` を振って残す（`id="第-5-条…"` は日本語 id で可）。
- 末尾: `<p class="meta"><a href="support.html">サポート</a> ／ <a href="terms.html">利用規約</a> ／ <a href="privacy.html">プライバシーポリシー</a> ／ <a href="../">手書きカレンダー（Web 版）</a></p>`。
- 外部リンクは `rel="noopener"`。`mailto:syfan0@gmail.com` は使ってよい（CSP の対象外）。JavaScript は書かない（CSP に `script-src` が無い = 既定で禁止）。
- `sw.js`: **変えない**。`APP_FILES` に足さない（precache の存在チェックに縛られる。同一オリジン GET は `networkFirst` が成功時に `cache.put` する（196-201 行）ので一度見ればオフラインでも出る。scope `./` に `app/` は含まれる）。既知: オフラインで**未訪問**の `app/*.html` に遷移すると `matchCache` のナビゲーション代替（171-176 行の `./` / `index.html`）で Web 版アプリの画面が出る。害は小さいので受け入れる（sw.js は変えない）。`VERSION` も `package.json` も **1.0.6 のまま**（三点一致テストは不変）。
- テスト `tests/app-pages.test.mjs`（`node --test` に拾われる名前。`npm test` が緑のこと）: (1) 4 ファイルが存在する (2) 各ページに `<html lang="ja">`、CSP の `meta`、`../icons/favicon-32.png`、`最終更新` がある (3) `terms.html` に `300 円`、`2,400 円`、`14 日`、`syfan0@gmail.com`、`privacy.html`、`support.html`、`Apple Account` がある (4) `privacy.html` に `収集`、`iCloud`、`UserDefaults`、`terms.html` がある (5) `support.html` に `syfan0@gmail.com`、`購入を復元`、`手書きを書き出す（iPad アプリ用）`、`Web 版の手書きを取り込む` がある (6) どのページにも `.md"`、`<script` が **無い** (7) `../privacy.html` が `privacy.html` と `index.html` のどれかにある。**`【`・`】`・`下書き` の禁止は `npm test` から分け**、`tools/check-legal.mjs`（`package.json` の `scripts` に `"check:legal": "node tools/check-legal.mjs"`。`app/*.html` を走査し、見つかればファイル名と行を出して exit 1）に置く。氏名（M5-6）が届くまで `m5-legal` の `npm test` を緑に保ち、公開前の関門はリードが `npm run check:legal` で踏む（M5-35）。`tests/app-shell.test.mjs` と `tools/check-imports.mjs` は不変（`app/*.html` は走査対象外）。
- `README.md`: 8 行目「- プライバシーポリシー: <…/privacy.html>」の**直後**に 3 行の箇条書き（「- iPad アプリ版の利用規約: <…/app/terms.html>」「- iPad アプリ版のプライバシーポリシー: <…/app/privacy.html>」「- iPad アプリ版のサポート: <…/app/support.html>」）。README に「公開ページの一覧」という節は無く、先頭の箇条書き（6-8 行）がそれ。
- 公開: W は `m5-legal` に commit するだけ。リードが差分を読んで main に merge（main は Pages が自動配信。max-age 600 なので 10 分以内に反映）→ `curl -sI` で 3 URL が 200 → C が DESIGN §10 の URL 欄に実値を書く。アプリの提出（M6）はこの後。

## 6. App Store Connect の手順

### 6.1 リードが本人の Chrome で行う（順番どおり。値はこの表のまま打つ）

前提: 6.2 の (1) Paid Apps Agreement が「有効」になっていること（無効のままだと商品は作れても「Missing Metadata」で止まり、サンドボックスの `Product.products(for:)` が空を返す）。

| # | 画面 | 操作と値 |
| --- | --- | --- |
| 1 | App Store Connect › マイ App › てがきカレンダー（6822762089）› 収益化 › サブスクリプション | 「サブスクリプショングループを作成」: 参照名 `てがきカレンダー` |
| 2 | グループ › ローカリゼーション | 日本語: 表示名 `てがきカレンダー`、App 名のカスタム表示 = 「App 名を使う」 |
| 3 | グループ › サブスクリプションを作成（1 つ目） | 参照名 `月額`、製品 ID `com.syfan0.tegakicalendar.monthly` |
| 4 | 月額 › 期間 | 1 か月 |
| 5 | 月額 › 配信状況 | すべての国と地域（App 側で EU を外すので、ここは全部） |
| 6 | 月額 › 価格 | 「サブスクリプションの価格を追加」: 基準の国 = 日本、価格 = **¥300**（価格表から選ぶ。他国は自動換算）。開始 = 今日 |
| 7 | 月額 › ファミリー共有 | **オンにしない** |
| 8 | 月額 › ローカリゼーション | 日本語: 表示名 `てがきカレンダー 月額`、説明 `手書き・予定の作成・iCloud 同期が使える月額プラン` |
| 9 | 月額 › 導入オファー | 「導入オファーを設定」: 国 = すべて、開始 = 今日、終了 = なし、種類 = **無料トライアル**、期間 = **2 週間**、対象 = 新規購読者 |
| 10 | 月額 › 審査情報 | スクリーンショット = CI の `ipad13-portrait-sheet-paywall.png`（2064 × 2752。640 × 920 以上ならよい）。審査メモ = 「ログイン不要。購入画面は初回案内の直後、ヘッダーの「閲覧専用」、または 設定 › 購入 から開きます。購読しなくても予定と手書きの閲覧はできます。」 |
| 11 | 月額 › 税カテゴリ | 既定（App Store ソフトウェア）のまま |
| 12 | グループ › サブスクリプションを作成（2 つ目） | 参照名 `年額`、製品 ID `com.syfan0.tegakicalendar.yearly`、期間 **1 年**、価格 **¥2,400**（無ければ ¥2,300 か ¥2,500 を選び docs/M5.md と PRICING に書く。M5-7）、ファミリー共有オフ、表示名 `てがきカレンダー 年額`、説明 `同じ機能の年額プラン（月あたり 200 円・4 か月分お得）`（¥2,300 なら「月あたり 192 円」等に直す）、導入オファー同じ、審査情報同じ |
| 13 | グループ | 2 つが同じ「サービスレベル 1」に並んでいることを確認（月額が上でも下でも可。同レベルなら切替は横移動） |
| 14 | サブスクリプション › 請求猶予期間 | オン、**16 日**、対象 = **有料のサブスクリプションの更新のみ**（M5-3） |
| 15 | App › 価格と配信状況 | App の価格 = 無料。配信する国と地域: すべて → EU の 27 か国のチェックを外す（アイルランド、イタリア、エストニア、オーストリア、オランダ、キプロス、ギリシャ、クロアチア、スウェーデン、スペイン、スロバキア、スロベニア、チェコ、デンマーク、ドイツ、ハンガリー、フィンランド、フランス、ブルガリア、ベルギー、ポーランド、ポルトガル、マルタ、ラトビア、リトアニア、ルーマニア、ルクセンブルク）。EU 外の欧州（英国・ノルウェー・スイスなど）は残してよい |
| 16 | App › App 情報 | プライバシーポリシー URL = `https://syfan0-star.github.io/tegaki-calendar/app/privacy.html`。ライセンス契約 = **Apple の標準 EULA のまま**（M5-8。自前の規約は「サービス規約」として App 内と説明欄からリンクし、規約第 1 条 2 項が標準 EULA の URL を示す） |
| 17 | App › 0.6.0 の版 › App 内課金とサブスクリプション | 2 つのサブスクリプションを版に追加（初回提出は版と一緒に審査される） |
| 18 | App › 0.6.0 の版 › 説明・サポート URL | サポート URL = `…/app/support.html`。説明の末尾に 4 行: 「価格: 月額 300 円／年額 2,400 円（税込）。14 日間無料。サブスクリプションは自動更新です。」「利用規約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/」「サービス規約: https://syfan0-star.github.io/tegaki-calendar/app/terms.html」「プライバシーポリシー: https://syfan0-star.github.io/tegaki-calendar/app/privacy.html」（審査 3.1.2(a): 標準 EULA を使う App は説明欄に標準 EULA のリンクを置く。自前の規約だけだと EULA の位置づけが曖昧で差し戻される典型） |
| 19 | ユーザとアクセス › Sandbox › テスター | 本人の指示でサンドボックス用 Apple Account を 1 つ追加（本人が用意したメール。M5-10） |

### 6.2 本人がやること（Claude が代行できない）

1. App Store Connect › 契約・税金・口座（Agreements, Tax, and Banking）› **有料 App（Paid Apps）** の契約に同意（Account Holder の操作）。
2. 同じ画面で **税務フォーム**（日本在住の個人は W-8BEN。米国の源泉徴収を避ける）と **銀行口座**（日本の口座。入金通貨 JPY）。
3. **App Store Small Business Program** の申込（Account Holder。承認は数日。承認前の売上は 30 %）。
4. サンドボックス用のメールアドレスを決める（6.1 の 19）。
5. §8 の 4（TestFlight のサンドボックス試験）。
6. §9 の決定（特に M5-6 氏名、M5-7 価格、M5-5 AI 注記）。

## 7. CI と検査

### 7.1 Products.storekit（S、`Support/Products.storekit`。Xcode 15 形式。手書きし、§7.3.1 の読み込みテストで形式を確定する。`testConfigurationLoadsBothProducts` の `SKTestSession` の init が投げたら、GitHub 上の公開リポジトリにある Xcode が書き出した実ファイルの `.storekit` を参照して鍵名を合わせる（1 回目の直しとして §7.3.3 に数える））

```json
{
  "identifier": "TegakiCalendarStore",
  "nonRenewingSubscriptions": [], "products": [],
  "settings": { "_applicationInternalID": "6822762089", "_developerTeamID": "", "_lastSynchronizedDate": 0,
                "_locale": "ja_JP", "_storefront": "JPN", "_storeKitErrors": [],
                "_askToBuyEnabled": false, "_billingGracePeriodEnabled": true, "_billingIssuesEnabled": false,
                "_failTransactionsEnabled": false, "_timeRate": 0 },
  "subscriptionGroups": [{
    "id": "21700001", "name": "てがきカレンダー",
    "localizations": [{ "locale": "ja_JP", "displayName": "てがきカレンダー", "description": "" }],
    "subscriptions": [
      { "internalID": "21700002", "subscriptionGroupID": "21700001", "productID": "com.syfan0.tegakicalendar.monthly", "referenceName": "月額", "type": "RecurringSubscription",
        "recurringSubscriptionPeriod": "P1M", "displayPrice": "300", "familyShareable": false, "groupNumber": 1,
        "introductoryOffer": { "internalID": "21700004", "paymentMode": "free", "subscriptionPeriod": "P2W" },
        "localizations": [{ "locale": "ja_JP", "displayName": "てがきカレンダー 月額", "description": "手書き・予定の作成・iCloud 同期が使える月額プラン" }],
        "adHocOffers": [], "codeOffers": [], "winbackOffers": [] },
      { "internalID": "21700003", "subscriptionGroupID": "21700001", "productID": "com.syfan0.tegakicalendar.yearly", "referenceName": "年額", "type": "RecurringSubscription",
        "recurringSubscriptionPeriod": "P1Y", "displayPrice": "2400", "familyShareable": false, "groupNumber": 1,
        "introductoryOffer": { "internalID": "21700005", "paymentMode": "free", "subscriptionPeriod": "P2W" },
        "localizations": [{ "locale": "ja_JP", "displayName": "てがきカレンダー 年額", "description": "同じ機能の年額プラン（月あたり 200 円・4 か月分お得）" }],
        "adHocOffers": [], "codeOffers": [], "winbackOffers": [] }
    ]
  }],
  "version": { "major": 3, "minor": 0 }
}
```

### 7.2 XcodeGen（C、`project.yml`）

```yaml
settings.base.MARKETING_VERSION: "0.6.0"
targets.TegakiCalendar.dependencies:        + { package: TegakiKit, product: Access }
targets.TegakiCalendar.scheme:              + storeKitConfiguration: Support/Products.storekit   # 実行時（Run）に効く。schemePathPrefix 既定 ../../ が前置される
targets.TegakiCalendarTests.sources:        + { path: Support/Products.storekit, buildPhase: resources }   # SKTestSession(configurationFileNamed:) はテストバンドルのリソースから探す
targets.TegakiCalendarTests.dependencies:   + { package: TegakiKit, product: Access }
```

`SKTestSession` は同一プロセスで StoreKit のテスト環境を作るので、`xcodebuild test` のホストアプリにスキームの `storeKitConfiguration` が効くかどうかに依らない（スキーム側は手元で Xcode を使う人のための保険）。`TegakiKit/Package.swift`（K）: `.library(name: "Access", targets: ["Access"])`、`.target(name: "Access")`（依存なし）、`.testTarget(name: "AccessTests", dependencies: ["Access"])`、`KitChecks` の依存に `"Access"`。

### 7.3 Store のテスト（S）

#### 7.3.1 StoreKitTest（`Tests/TegakiCalendarTests/StoreKitSessionTests.swift`、`import StoreKitTest`、`@MainActor`）

`setUp`: `session = try SKTestSession(configurationFileNamed: "Products")`; `session.disableDialogs = true`; `session.clearTransactions()`; `session.resetToDefaultState()`; `session.storefront = "JPN"`; `session.locale = Locale(identifier: "ja_JP")`。`StoreModel(client: LiveStoreClient(), cache: NoopAccessCache())`。`Transaction.updates` の到達に数百 ms かかるので `await waitUntil(timeout: 5) { model.snapshot.access.canEdit }`（`TestSleeper` と同じ流儀のポーリング）。

| テスト | 内容 |
| --- | --- |
| `testConfigurationLoadsBothProducts` | `products(ids: ProductIDs.all)` が 2 件、`price == 300` / `2400`、`displayPrice.filter(\.isNumber) == "300"` / `"2400"`（ja_JP の ICU は記号が全角「￥」(U+FFE5) になりうるので記号を除いて比べる）、`introDays == 14`、`perMonthDisplayPrice?.filter(\.isNumber) == "200"`（年額だけ）、`subscriptionGroupID != nil`。**形式の確定テスト**（`SKTestSession` の init が投げたら .storekit の形式が違う。§7.1 の手順） |
| `testBuyingMonthlyStartsATrial` | `session.buyProduct(identifier: Plan.monthly.productID)`（async 版）→ `refresh()` → `access == .trial(plan: .monthly, willAutoRenew: true)`、`until` が 13〜15 日後 |
| `testExpiringMakesItReadOnly` | 購入 → `session.expireSubscription(productIdentifier:)` → `refresh()` → `.readOnly(.expired)` |
| `testRefundRevokes` | 購入 → `session.refundTransaction(identifier: 最新の Transaction の id)` → `refresh()` → `.readOnly(.revoked)`。`currentEntitlements` からは来ないので、`renewals` の `state == .revoked`（規則 7）か `updates` の写し（規則 1）で通る。どちらで通ったかを docs/M5.md に書く |
| `testIneligibleAfterATrial` | 購入 → 期限切れ → `products(ids:)` の `isEligibleForIntroOffer == false`（資格はグループ単位） |
| `testUpdatesStreamTriggersRefresh` | `start()` → `session.buyProduct` → `waitUntil { canEdit }`（`refresh()` を自分で呼ばない） |
| `testRestoreAfterClearingTransactions`（任意） | `AppStore.sync()` はテスト環境でサインインを求めうるので **呼ばない**。`clearTransactions()` → `.readOnly(.notSubscribed)` → `buyProduct` → `currentEntitlements` に出る、で代える |

#### 7.3.2 偽物で（`Tests/TegakiCalendarTests/StoreModelTests.swift`、`FakeStoreClient.swift`。**StoreKitTest の可否に関わらず必須**）

`FakeStoreClient: StoreClient`（`products` の結果か `Error`、`purchase` の結果の列、`entitlements` / `renewals` の配列、`updates` の `AsyncStream.Continuation` を外から流せる、`syncCalls` の回数）と `MemoryAccessCache`。`now` は固定（`Date(timeIntervalSince1970: 1_760_000_000)`）。

| テスト | 内容 |
| --- | --- |
| `testStartShowsTheCachedStateFirst` | 控え `.subscribed(until: now + 10 日)` → `start()` の直後（`refresh` を待たず）に `canEdit`、`offers` 空 |
| `testRefreshResolvesAndSaves` | `entitlements` に年額（期限 now + 300 日、introductory false）→ `.subscribed(.yearly, willAutoRenew: true)`、`cache.saved?.state` が同じ、`offers` が年額→月額の順、`storeReachable` |
| `testOfflineKeepsACachedSubscription` | `products` が `URLError(.notConnectedToInternet)`、`entitlements` 空、控え有効 → 控えのまま、`message == .productsUnavailable`、`storeReachable == false` |
| `testOfflineWithAnExpiredCacheIsReadOnly` | 控え `until: now − 1 日` → `.readOnly(.expired)` |
| `testPurchaseSuccessClosesWithAMessage` | `.success` → `access.canEdit`（`refresh` の完了前に）、`message == .purchased(.yearly)`、`phase == .idle`、`refresh` が 1 回走った。**同時に走っていた `refresh` がある場合**（偽物の `currentEntitlements` を待たせて `purchase` を重ねる）でも最終的に `access.canEdit`（§2.4 の再走） |
| `testPurchaseWhileRefreshingDoesNotJoinStaleResult` | `refresh()` 走行中（偽物が `entitlements` 空を返す途中）に `purchase` 成功 → 完了後 `access.canEdit` かつ `message == .purchased` |
| `testPurchasePendingCancelledUnverified` | `.pending` → `.pending`; `.cancelled` → `message == nil`; `.unverified` → `.failed(StoreStrings.unverified)` |
| `testPurchaseErrorsAreMapped` | `StoreKitError.networkError` → `.failed(StoreStrings.offline)`; `.notAvailableInStorefront` → `.failed(StoreStrings.notAvailable)`; `.userCancelled` → nil |
| `testRestoreMessages` | `sync` 後に権利あり → `.restored`; なし → `.nothingToRestore`; `sync` が投げる → `.failed` |
| `testUpdatesStreamRefreshes` | `start()` → continuation に 1 件流す → `canEdit` になる |
| `testRefreshCoalesces` | 同時に 3 回 `refresh()` → `currentEntitlements` の呼び出しは 2 回（走行中の 1 回＋合流した再走 1 回）、3 つとも再走の後に返る |
| `testProductsNotRefetchedWithinAnHour` | `offers` ありで 1 時間以内に `refresh()` → `products` は呼ばれない。`now` を 61 分進めると呼ばれる |
| `testNormalRefreshKeepsMessage` | `message == .purchased` のまま `products` が投げる `refresh(reason: .automatic)` → `message` は `.purchased` のまま。`refresh(reason: .paywall)` → `.productsUnavailable` |
| `testOfflineKeepsGraceFromCache` | `products` と `renewals` が投げる、`entitlements` に期限切れ 1 件、控え `.subscribed(inGrace: true, until: now + 5 日)` → 控えのまま（reconcile d）、`cache.saved` は変わらない（到達不可では保存しない） |
| `testOfflineFirstLaunchIsUnknown` | 到達不可・控え nil・`entitlements` 空 → `.readOnly(.unknown)`、`cache.saved == nil` |
| `testOfflineKeepsRevokedFromCache` | 到達不可、`entitlements` 空、控え `.readOnly(.revoked)` → `.readOnly(.revoked)`（reconcile e） |
| `testRenewalsUnavailableDoesNotExpire` | 到達可（`products` 成功）だが `renewals` が投げる、`entitlements` に期限切れ 1 件 → `.readOnly(.unknown)`（規則 13）、保存されない |
| `testUnfinishedAreFinishedAtStart` | `start()` → 偽物の `finishUnfinishedCalls == 1` |
| `testAwaitFirstRefresh` | `start()` 前は timeout まで待って false、`refresh` 完了後は即 true、`snapshot.refreshed == true` |
| `testUpdatesCarryRevocation` | `start()` → continuation に `revocationDate` 付きを 1 件流す（`entitlements` 空・`renewals` 空）→ `.readOnly(.revoked)`（規則 1） |
| `testUserDefaultsCacheRoundTrip` | `UserDefaultsAccessCache(defaults: UserDefaults(suiteName: "test-\(UUID())")!)` で `save` → `load` が等しい、`removeObject` 相当で nil、`defaultKey == "accessStateCache"` |
| `testScreenshotDemo` | `screenshotDemo(access: .readOnly(.notSubscribed))` → `offers` が `StoreStrings.demoYearlyPrice` / `demoMonthlyPrice`、`perMonthDisplayPrice == StoreStrings.demoPerMonthPrice`、eligible、`access` が引数のとおり、`refreshed == true`、`start()` しても変わらない |

#### 7.3.3 判定基準（StoreKitTest を残すか退くか）

S の最初の push で CI を回す。`StoreKitSessionTests` が **StoreKit の環境の理由**（`SKTestSession` の init が投げる、`Product.products` が空、`buyProduct` 後 5 秒待っても Transaction が来ない）で落ちた場合、S は .storekit の形式と待ち時間を直して **もう 1 回** だけ試す。2 回目も同じ理由で赤なら: `StoreKitSessionTests` 全体を `#if STOREKIT_TEST` で囲み（既定でコンパイルしない。`project.yml` の `TegakiCalendarTests` に `SWIFT_ACTIVE_COMPILATION_CONDITIONS` を足す口は C が用意するが既定では付けない）、`Support/Products.storekit` は手元の Xcode での手動テスト用に残し、7.3.2 の偽物のテストだけで完了とする。ロジックの理由（期待値の違い）で落ちた場合は普通に直す。どちらになったかを docs/M5.md に書く（C）。

### 7.4 TegakiKit（K）: KitChecks の節と件数

| 節 | 内容 | 件数 |
| --- | --- | --- |
| `access state (M5)` 新 | `Plan`: productID 2 つ、`init?(productID:)` の往復と不正 → nil、`months`、`ProductIDs.all`、`contractPrice`、`trialDays`（≈ 10）。`AccessPolicy.resolve`: §1.2 の表 13 行 × 代表例（各行 2〜3 例: 期限ちょうど now、nil の期限、2 件の権利で遅い方を選ぶ、未知の商品 ID の権利と R を無視、取消 1 件＋有効 1 件 → 有効、`renewals` 空 vs nil（2・13 の行で `.notSubscribed`/`.expired` vs `.unknown`）、R.willAutoRenew false、R だけ `.subscribed` で renewalDate 先 → `.subscribed`（5）、renewalDate nil → `.unknown`（6）、`latestTransaction` の合流（同じ id は entitlements 側）、`latestTransaction` に取消 → `.revoked`（1））（≈ 45）。`AccessState.canEdit` / `plan` / `until`（≈ 8）。`AccessCache`: encode → decode の往復 3 状態、壊れたデータ → nil、`stateForLaunch` の 8 分岐（3 日の猶予: `until + 2 日` は canEdit、`until + 3 日` は `.expired`、`willAutoRenew: false` は即 `.expired`、`inGrace` は `.billingRetry`）（≈ 16）。`reconcile`: a〜g の 7 行 × 1〜2 例（到達可 → live、到達不可＋控え有効＋live 未購読 → 控え、**到達不可＋live `.expired`＋控え `inGrace` 有効 → 控え**、到達不可＋控え期限切れ＋live `.expired` → live、到達不可＋live subscribed → live、到達不可＋live `.revoked` → live、到達不可＋控え `.revoked`＋live `.notSubscribed` → `.revoked`、到達不可＋控え nil＋live `.notSubscribed` → `.unknown`）（≈ 10）。`PlanText`: name / perPeriod、`savingsMonths(300, 2400) == 4`、`(300, 3600) == 0`、`(0, 2400) == 0`、`(250, 2000) == 4`、`savingsText(4) == "4 か月分お得"`、`savingsText(0) == nil`、`perMonth(2400) == 200`、`perMonth(2300) == 192`、`statusTitle` 8 状態、`dateLabel` 6 状態、`readOnlyNote` 5 理由（`.billingRetry` に `paymentPath` が含まれる）、定数 4 つ（≈ 36）。`LegalLinks` の 4 URL の文字列、`appleEULATitle`、`supportEmail`（6） | **≥ 120** |
| 既存の節 | 不変 | ±0 |

合計の見込み: 22900 + 120〜140 ≈ **23020〜23040**。閾値は **K の実数 N − 50**（K が docs/M5.md に N を書く → C が build.yml に入れる。M4B-9 と同じ順序。暫定 22970）。XCTest（`TegakiKit/Tests/AccessTests`、同じ内容）: `AccessPolicyTests`（`testTruthTable`、`testPicksTheLatestEntitlement`、`testRevokedOnly`、`testGraceAfterExpiry`、`testBillingRetry`、`testRenewalsUnavailable`、`testStatusOnlySubscribed`、`testLatestTransactionMerge`、`testReconcile`）、`AccessCacheTests`（`testRoundTrip`、`testCorruptData`、`testStateForLaunch`、`testOfflineRenewalAllowance`）、`PlanTextTests`（`testSavings`、`testPerMonth`、`testTitlesAndLabels`、`testLegalLinks`）。

### 7.5 写真モード（U: `Support/ScreenshotMode.swift`、C: build.yml）

```swift
enum Sheet: String, CaseIterable, Sendable { case create, edit, lasso, settings, sync, `import`, paywall }   // 7 つ目
struct Config: Equatable, Sendable {
    …                               // 既存の 8 つ
    var readOnly: Bool = false      // --screenshot-readonly: StoreModel.screenshotDemo(access: .readOnly(.notSubscribed))
}
```

`parse`: `arguments.contains("--screenshot-readonly")`（U が `Config.readOnly` と parse の 1 行を足す。S は参照しない。M5-34）。シートと併用可（`--screenshot-sheet paywall` は月ページ。`readOnly` の有無に関わらずペイウォールは試用資格ありの見本 = disclosure は「料金は無料試用の終了時に請求されます」の分岐）。`showScreenshotSheet(.paywall)`（`CalendarRootScreen.swift:1115` の `switch`）: `paywallReason = .firstLaunch; showPaywall = true`。`--screenshot-readonly` の `appear()`: 0.5 秒後に `showToast(§3.3 のトースト)`（バッジ＋止めた操作の案内が 1 枚に写る。トーストは 3 秒なので `sleep 8` の前に消える → **写真モードの readOnly ではトーストを 20 秒に延ばす**（`ToastView.duration` は変えず `showToast` の引数 `duration:` を足す。U））。先頭の注記（5-21 行）に 2 行足す。

写真（C が build.yml に）: 13 インチ縦 `ipad13-portrait-sheet-paywall.png`（シートのループに `paywall` を足す。`sleep 9`）、`ipad13-portrait-readonly.png`（`--screenshot-mode --screenshot-month 2026-10 --screenshot-page month --screenshot-readonly`。`sleep 8`）。11 インチ縦 `ipad11-portrait-readonly.png`（`--screenshot-month 2026-10 --screenshot-page day --screenshot-readonly`。題名が最長の日ページで、記号だけのバッジ（834 < 980）と題名が共存することの確認。M5-32）。iPhone: `iphone-portrait-readonly.png`（`shoot "iphone-portrait-readonly.png" --screenshot-month 2026-10 --screenshot-page week --screenshot-readonly`。案内行の見え方）。審査用スクリーンショット（§6.1 の 10）は `ipad13-portrait-sheet-paywall.png`。

### 7.6 XCTest（役割ごと。名前は固定）

- **K**: §7.4 の `AccessTests` 3 ファイル。
- **S**: §7.3.1・§7.3.2。
- **U**: `ScreenshotModeTests.testParseM4Sheets` → `Sheet.allCases.count == 7`、rawValue の配列に `"paywall"`（既存の直接比較を更新）; 新規 `testParseReadOnly`（無し → false、有り → true、`--screenshot-sheet paywall --screenshot-readonly` → 月・`.paywall`・true、`--screenshot-sheet paywall` → `.paywall`）。`AppSettingsTests`（別スイート）: `paywallShownAfterOnboarding` 既定 false・書き戻し、キーの文字列 1 つ（控えのテストは S の `testUserDefaultsCacheRoundTrip`）。`CalendarRootScreenTests.testGate`: `isAllowed` を `GatedAction.allCases × [.subscribed, .trial, .readOnly(.expired)]` の 3 状態で表どおりに（止める 11 × readOnly = false、許す 8（`export` を含む）= 常に true、`GatedAction.allCases.count == 19`）。`EventEditorSheetTests`（新規）: `readOnlyFootnote(note: nil) == "このカレンダーは変更できません（読み取り専用）"`、`readOnlyFootnote(note: EventEditorSheet.subscriptionNote) == "予定の作成・編集は購読すると使えます。"`（`static func readOnlyFootnote(note: String?) -> String` を U が純関数として切り出す）。`SettingsScreenTests`（新規）: `planText` 8 状態、`dateLabel` 6 状態、`dateText(2026-10-25, locale: ja_JP) == "2026/10/25"`（CI は英語ロケールなので `locale` を渡す。§4.3 の署名）、`purchaseButtonTitle`（readOnly + eligible → 「14 日間無料で試す」、readOnly → 「購読する」、subscribed → nil）、`purchaseFooter` の 3 分岐に `PlanText.cancelPath` が含まれる。`PaywallSheetTests`（新規。価格の固定値は `StoreStrings.demo*` の 3 定数を使う）: `ctaTitle`、`trialLine`、`priceLine(年額の PlanOffer) == "\(StoreStrings.demoYearlyPrice)/年"`、`yearlyNote` に `StoreStrings.demoPerMonthPrice` と `"4 か月分お得"`、`afterLine` の 2 分岐、**`disclosure(eligible: true)` に「無料試用の終了時に請求」が含まれ「購入の確認時」が含まれない、`disclosure(eligible: false)` はその逆**、両方に 「24 時間前」「自動更新」「Apple Account」「サブスクリプション」が含まれる、`features.count == 3`、`lead(.blocked(.draw), eligible: true)` が 「14 日間無料」を含む、`lead(.settings, eligible: true, readOnlyReason: .billingRetry)` が 「お支払いに問題」と `PlanText.paymentPath` を含む、`lead(.badge, eligible: false, readOnlyReason: .revoked)` が 「返金」を含む、`readOnlyReason: .expired` は reason どおりの文言。`InkCanvasViewTests`: `testDefaultArgumentsOfTheNewParameters` に `readOnly == false` と `onBlockedInput()` を足す; 新規 `testReadOnlyDisablesDrawingAndOverlay`（`readOnly: true` → `canvas.drawingGestureRecognizer.isEnabled == false`、`.lasso` でも false、`blockedInputRecognizer.isEnabled == true`、`allowedTouchTypes == [.pencil]`、`fingerRecognizer.isEnabled == false`（`.lasso` + `allowFinger`）、`update(from:)` で `readOnly: false` に戻すと drawing が true・blocked が false）; `testBlockedInputRecognizerRecognizesSimultaneously`（delegate の `shouldRecognizeSimultaneouslyWith` が drawing・pan・pinch・tap と全部 true。両方の向き）; `testOverlayInteractionFollowsReadOnly`（`.lasso` で `overlay.isUserInteractionEnabled == true` → `readOnly: true` に `update(from:)` → false → `readOnly: false` → true。tool を変えずに readOnly だけ変える）。
- **W**: §5.2 の `tests/app-pages.test.mjs`。
- **L**: 無し（W のテストが文面の関門）。

### 7.7 CI（C、`.github/workflows/build.yml`）

- 先頭コメント 9 行目の「up to 32 images + 4 logs」→ **36 images + 4 logs**。
- KitChecks の閾値（56-65）: K の実数 − 50（暫定 22970）。コメントの数字も直す。
- シートのループ（257）: `for SHEET in create edit lasso settings sync import paywall`。
- 13 インチの 4 ページの後ろに `ipad13-portrait-readonly.png`（§7.5）。11 インチの 4 ページの後ろに `ipad11-portrait-readonly.png`（日ページ）。iPhone の `shoot` に `iphone-portrait-readonly.png`。
- ログの grep に `grep 'store: ' shots/app-log.txt || true`（`LiveStoreClient` の DEBUG ログ。写真モードは偽物なので 0 行でよい。実機のログを見るときの到達確認）。
- 追加時間 ≈ 40 秒。成果物 = 13 インチ 15 枚 + `ipadmini` 4 枚 + `ipad11` 5 枚 + `iphone` 縦 8 枚 + `iphone-landscape` 4 枚 + ログ 4 本 = **36 枚 + 4 本**。
- `project.yml` は §7.2。README（53-55 行）: 「アプリからの書き出しと購入は「準備中」」→「アプリからの書き出しは「準備中」」、「まだ無いもの（M5 以降）: 課金・閲覧専用モード、…」→「まだ無いもの（M6 以降）: アプリからの手書きの書き出し、設定の同期」、「設定画面」の行に「購入（現在のプラン・購入を復元・サブスクリプションの管理）」、新しい行「購入と閲覧専用 | 月額 300 円・年額 2,400 円・14 日間無料のサブスクリプション。購読していないときは閲覧専用（予定と手書きの閲覧、ページ移動、拡大はできる。書く・消す・予定の作成はペイウォールの案内）」。
- DESIGN の注記: §2.8 の購入欄に表示状態（有効・試用中・猶予中・閲覧専用）、§2.9 の 2 に「4 か月分お得」の表示を足す（0-1。直す文字列は無い）、§2.10 末尾（ペイウォールは案内の後、最初の確認が済んで未購読のときに 1 回。ペンで触れたときは止めた操作として 1 セッション 1 回）と表を実装に合わせる（0-7）、§7.1 の「仮」を外す、§7.2 を AccessState / StoreModel / 控え / 自前のシートに（0-4）、§7.3 に §4.1 の文言、§7.4 に D3 の表、§7.5 のチェックを埋める、§10 の URL の実値、付録 B B-6 に `app/`。PRICING §6 に「決定（2026-10-11、B-7）。M5 で実装」の 1 行。`docs/M5.md` は M4C.md と同じ構成（結果・CI の run・写真の確認表・本人の実機の結果・StoreKitTest の可否）。

## 8. 完了の定義

1. `swift run --package-path TegakiKit KitChecks` が「all N checks passed」（N ≥ 閾値。ローカルと CI）。`swift test --package-path TegakiKit`（`AccessTests` を含む）が CI で緑。順序: K が N を docs/M5.md に書く → C が閾値を入れる。
2. CI の `build` が緑: 13 インチのユニットテスト（§7.3・§7.6）が通り、成果物 `screenshots` に 35 枚 + ログ 4 本。StoreKitTest を残したか退いたかが docs/M5.md に書いてある。
3. Web リポジトリ: `m5-legal` で `npm test` が緑（`app-pages.test.mjs` を含む）。リードが merge → `curl -sI` で 3 URL が 200。DESIGN §10 に実値。
4. App Store Connect: §6.1 の 1〜18 が済み、2 商品が「送信準備完了（Ready to Submit）」（本人の Paid Apps Agreement が有効になった後）。
5. リード（本人）が **次の写真を見て** 確かめる:

| 写真 | 見えていなければならないもの |
| --- | --- |
| `ipad13-portrait-sheet-paywall.png` | 月ページの上にフォームシート。題名「てがきカレンダー」、説明 1 行、3 つの機能、年額（¥2,400/年、「月あたり ¥200・4 か月分お得」、「おすすめ」）が上で選択中、月額（¥300/月）、「14 日間無料でお試し…」、ボタン「14 日間無料で試す」、「試用後は ¥2,400/年。いつでも解約できます。」、自動更新の説明（24 時間前・Apple Account・設定の経路）、〔購入を復元〕〔利用規約〕〔プライバシーポリシー〕、〔あとで〕。文字が切れていない |
| `ipad13-portrait-readonly.png` | ヘッダーの「＋予定」の左にオレンジの「閲覧専用」バッジ（錠の記号＋文字。1024 pt ≥ 760）。下部にトースト「閲覧専用です。書く・消す・予定を作るには購読が必要です」。月ページの見本の線と予定はそのまま見える。ツールバーの ↶ ↷ が灰色 |
| `iphone-portrait-readonly.png` | ヘッダーにバッジが **無い**（2 段のまま崩れていない）。ヘッダーの下に案内行「閲覧専用です。手書きと予定の作成は購読すると使えます。」＋「購読する」。週ページが一覧で入る |
| `ipad13-portrait-sheet-settings.png` | 既存の写真。購入欄が画面外でも可（13 インチでは下にある）。崩れが無い |
| 既存の 31 枚 | M4c と同じ（購読中の見本なのでバッジ無し） |

6. 本人が TestFlight（0.6.0）で **実機**（サンドボックスの試験）:

| # | 手順 | 期待 |
| --- | --- | --- |
| 1 | iPad の「設定」›「App Store」›「サンドボックスアカウント」に §6.1 の 19 のアカウントでサインイン（本番の Apple Account はそのまま） | — |
| 2 | アプリを初めて開く（または削除して入れ直す）→ 初回案内 → 許可 | 案内の直後にペイウォール。年額が選択中、「14 日間無料で試す」 |
| 3 | 「あとで」 | 閉じる。ヘッダーに「閲覧専用」。ペンで紙に触れる → ペイウォール（1 回目）→「あとで」→ もう一度触れる → トースト。＋予定 → トースト。投げなわを選ぶ → トースト。設定 › データ › 取り込む → ペイウォール（設定が閉じて）。設定 › 購入 に「未購入（閲覧専用）」と「14 日間無料で試す」。全て消すは実行できる（確認 2 回） |
| 4 | バッジ → ペイウォール → 年額 →「14 日間無料で試す」→ サンドボックスの確認 | トースト「14 日間の無料試用を開始しました」。バッジが消え、書ける・予定を作れる。設定 › 購入 が「年額・試用中」「試用の終了（有料に移行）」（サンドボックスでは 2 週間の試用が数分に短縮される（要確認: Apple の表）） |
| 5 | 待つ（サンドボックスの更新速度は「設定」›「App Store」›「サンドボックスアカウント」›「サブスクリプションの更新速度」で変えられる） | 試用 → 有料に移ると「年額・有効」「次回更新」。1 年 = 1 時間で更新。最大 12 回更新した後に期限切れ → 閲覧専用（前面復帰で反映） |
| 6 | 設定 › 購入 › サブスクリプションを管理 → 解約 | 「有効期限」に変わる。期限までは書ける。期限後に前面復帰 → 閲覧専用、「期限切れ（閲覧専用）」 |
| 7 | 設定 › 購入 › 購入を復元 | 解約済みで期限内なら「購入を復元しました」。期限後なら「復元できる購入がありません…」 |
| 8 | 機内モードで起動（購読中） | 控えで書ける。回線を戻して前面復帰 → 状態が確認される |
| 9 | iPhone で同じサンドボックスアカウント | 自動で権利が付く（復元不要）。閲覧専用のときは案内行が出る |
| 10 | ペイウォールで月額を購入 → Apple の管理画面で年額に切替 | グループ内の切替。設定 › 購入 の表示が変わる（Apple が処理） |

7. docs/M5.md・README・DESIGN・PRICING の注記が更新され、`MARKETING_VERSION` 0.6.0。

## 9. 本人の決定・未決

| # | 内容 | 既定（返事が無ければこうする） |
| --- | --- | --- |
| M5-1 | 連絡先のメール | **`syfan0@gmail.com`**（規約第 13 条・PP 第 11 節・サポート・`LegalLinks.supportEmail`。専用アドレスにしたいときは 4 か所と W のテストを同時に直す） |
| M5-2 | 年額の割引表示 | **「4 か月分お得」**（2,400 = 300 × 8。D4 の「2 か月分」は計算違い）。「33 % お得」の併記はしない（数字が 2 つ並ぶと読みにくい） |
| M5-3 | 請求猶予期間 | **オン・16 日・有料のサブスクリプションの更新のみ**（無料試用 → 有料の最初の請求に失敗した人に 16 日の無料延長を与えない。3 日は短く、28 日は長い） |
| M5-4 | iCloud の `Meta.trialStartedAt` | **書かない・読まない。項目は残す**（CloudKit スキーマは Production 済みで害なし。StoreKit の導入オファーが試用を管理するので要らない。将来「アプリ内の無料枠」を作るときの予備） |
| M5-5 | 規約類の AI 注記 | **公開版から外し、末尾に「開発者が AI の下書きをもとに作成し、内容を確認しています」の 1 行**。法律の専門家の確認は本人の任意（費用がかかる。公開後でもよい） |
| M5-6 | 販売者の氏名の表記（第 13 条・第 11 節） | **リードが本人に漢字を確認して L に渡す**。届くまで `【氏名】` のままで、W のテスト（`【` 禁止）が公開を止める。App Store の販売者欄と同じ表記にする |
| M5-7 | ¥2,400 が価格表に無いとき | **¥2,300**（PRICING §2 の 2 択のうち安い方。「月あたり 192 円」「4 か月分お得」のまま（2,300 / 300 = 7.67 か月 → 4 か月分）。¥2,500 なら 3 か月分お得になり説明文を直す）。選んだ値を PRICING・TERMS・W のテスト・.storekit に同時に書く |
| M5-8 | ライセンス契約（EULA）: Apple 標準か自前の規約か | **Apple 標準のまま**（App Store の説明欄とペイウォールから自前の規約へリンク。規約第 1 条 2 項が Apple の契約との関係を既に書いている）。自前にするなら Connect の「ライセンス契約」に全文を貼る（日本語のみ） |
| M5-9 | 期限切れの反映の時機 | **前面復帰と起動のたびに `refresh()`**（開いたまま期限をまたぐと次の前面復帰まで書ける。タイマーで監視しない） |
| M5-10 | サンドボックス用の Apple Account | **本人が新しいメールアドレスを用意**（Gmail の `+sandbox` のようなエイリアスでも可。既存の Apple Account のメールは使えない）。リードが Connect に登録 |
| M5-11 | ペイウォールの時機（0-3） | **初回案内の直後に 1 回 ＋ 止めた操作の 1 セッション 1 回 ＋ バッジ ＋ 設定 › 購入**。「ペンで触れたら」は止めた操作に含まれる |
| M5-12 | 止めた操作の 2 回目以降の知らせ方 | **トースト**（アラートはタップで閉じる手間があり、紙に触れるたびに出ると邪魔）。写真モードは常にトースト |
| M5-13 | iPhone（compact）の閲覧専用の見せ方 | **ヘッダーの下に案内行**（1 段目に文字が入らない）。記号だけのバッジは何か分からないので出さない |
| M5-14 | 閲覧専用で「全て消す」を許す | **許す**（D3。自分のデータを消す権利。規約第 5 条 5 項とサポートにそう書く） |
| M5-15 | 閲覧専用で Web 取り込みを止める | **止める**（D3。取り込みは手帳として使う機能。設定の行は灰色で残し、押すと案内） |
| M5-16 | 猶予中（inGrace）の見せ方 | **バッジ無し・設定 › 購入 に赤字と脚注**（書ける状態なので閲覧専用の印は出さない） |
| M5-17 | 試用資格の無い人の文言 | 「無料試用の対象外です（お試しは 1 つの Apple Account につき 1 回）。」を灰字で 1 行。CTA は「購入する」 |
| M5-18 | 書き出し機能の規約上の扱い（0-5） | **「順次提供」に弱め、閲覧専用の「できる」から外す**。提供開始時に第 3 条・第 5 条 5 項を戻す |
| M5-19 | EU 除外の実装 | **App の「価格と配信状況」で 27 か国を外す**（§6.1 の 15。商品側の配信状況は全部のまま）。英国・スイス・ノルウェーは残す |
| M5-20 | Small Business Program の申込の時機 | **公開前**（承認までの売上は 30 %。承認後は概ね翌月から 15 %） |
| M5-21 | 「サブスクリプションを管理」の実装 | **`.manageSubscriptionsSheet(isPresented:)`**（iOS 17 の SwiftUI 修飾子。`AppStore.showManageSubscriptions(in:)` は `UIWindowScene` が要る） |
| M5-22 | `StoreModel` の生成場所 | **`CalendarRootScreen` の `@StateObject`**（`EventStoreModel` と同じ流儀。`App.swift` は触らない） |
| M5-23 | 試用中の `Trial` に `plan` / `willAutoRenew` を持たせる（D2 の `.trial(until)` より多い） | **持たせる**（設定の「年額・試用中」と「試用の終了（有料に移行）／試用の終了」の出し分けに要る） |
| M5-24 | 写真モードの readOnly でトーストを 20 秒に延ばす | **延ばす**（`showToast(duration:)` の引数。通常の 3 秒／6 秒は不変） |
| M5-25 | KitChecks の閾値 | **K の実数 − 50**（見込み 23000〜23020 → 暫定 22950） |
| M5-26 | 初回起動がオフラインで控えも無い（`.readOnly(.unknown)`） | **閲覧専用**（バッジあり。設定の脚注「購入の状態を確認できていません。回線が戻ると自動で確認します」。保存しないので回線が戻れば正しくなる） |

統合の順番: **K**（`Access` の 7 ファイル、Package.swift、KitChecks、AccessTests、実数 N を docs/M5.md に）→ **S の最初の版**（`StoreClient` / `StoreModel` / `AccessCacheStore` / `StoreStrings` / `Products.storekit` / 偽物のテスト。この時点で `StoreModel.make()` と `screenshotDemo` が使える）→ **U**（AppSettings → ScreenshotMode → PaywallSheet → SettingsScreen → PageHeaderView → InkCanvasView の 2 引数 → CalendarRootScreen の guard とシート → テスト）と **S の残り**（StoreKitSessionTests。§7.3.3 の判定）と **L**（3 文書）を並行 → **W**（L の文書が固まってから。`m5-legal`）→ **C**（project.yml、build.yml、README、DESIGN・PRICING の注記、docs/M5.md、CI の写真の確認）→ **リード**（Web の merge と URL の確認、App Store Connect §6.1）→ **本人**（§6.2、§8 の 6）。

本人がやること（Claude が代行できない）: (1) §6.2 の 1〜4（Paid Apps Agreement、税務、銀行、Small Business Program、サンドボックス用メール）。(2) §9 の M5-6（氏名の漢字）と M5-5・M5-7・M5-8 の返事（無ければ既定）。(3) CI の写真（§8 の 5）を見てペイウォールと閲覧専用の見え方を判断する。(4) TestFlight で §8 の 6 をサンドボックスで通す。
