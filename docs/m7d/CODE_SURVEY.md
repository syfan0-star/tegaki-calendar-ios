# CODE_SURVEY — 1.4（Xcode 27・iPhone Duo）でコードのどこに触れるか

調べた人: コードの調べ役（2026-11-20）。読むだけ。リポジトリは変えていない。

- 調べた木: `origin/main` の 7895d40 を detached の worktree に出して読んだ。**コードは 955fe67 と 1 バイトも違わない**（`git diff --stat 955fe67 7895d40` は docs/M7C.md と 13 の whatsnew.txt だけ）。
- 行番号はすべて 7895d40 の行。M7_PLAN §6.2 の行番号は古い所がある（下の 1.1 で読み替える）。
- この Mac で `tools/typecheck/typecheck.sh` を走らせた（CLT の macOS 27.2 SDK、Swift 6.4.2、Mac Catalyst の `arm64-apple-ios17.0-macabi`）。**アプリ・テスト・Kit とも OK、警告 0**。`UIScreen.main` も警告にならなかった。ただし iOS 27.1 SDK ではない（Catalyst の SDK）ので、Xcode 27 の本当のビルドの代わりにはならない。
- Web の事実には URL と読んだ日を付けた。確かめていない所は【未確認】、計算や推定は【推定】と書く。

---

## 0. 要点（リードが最初に読む所）

1. **端末の種類で見た目を決める所は 11 か所**（下の表 1.2）。どれも凍結の 20 ファイルの外。ただし **`InkSnapshot.swift:24` の `UIScreen.main.scale` は凍結のファイルの中**。凍結を崩さずに直すなら、呼ぶ側の 2 か所（`CalendarRootScreen.swift:1935`・`:2989`）で `scale:` を渡せばよい。
2. **凍結のテスト `CalendarRootScreenTests.swift:116-128`（TESTS_1_2_3 の 8 ファイルの 1 つ）が `usesMinTapTarget(isPhone:width:)` の形と「iPhone はどの幅でも true」を固めている**。この関数の名前・引数・意味を変えると、凍結のテストの表を作り直す要がある。
3. **iPhone は週から開く（`CalendarRootScreen.swift:433`）は `init` の中で決めている**。この時はまだ窓の幅が分からない。「幅 600 以上なら月」にするには、決める時を最初の配置まで遅らせる作りに変える要がある（`UIScreen.main` で幅を取るのは Apple が止めてと言う書き方）。
4. **span plan は Duo を `.iPhone` として扱う**（`SpanPlan.swift:19-32`、`isPad` が false なら必ず `.iPhone`）。窓の大きさは iPhone の行（402 pt）から決まり、実際の紙の領域で広がる（`SpanSession.swift:416-420`）。計算では、内側の縦の日は 5 → 7 ページに広がり、横は上限（週 3・日 5）が**効くか効かないかの境目**にいる（表 3.2）。
5. **CI の `xcode-27` のイメージには `iPhone 17 Pro Max` が無い**。6.9 インチの写真（`iphone69`）を撮る 5 か所の端末の一覧は、どれも見つからずに飛ばされる。`iPad mini (A17 Pro)` は iOS 27.0 にしか無い。Duo は iOS 27.1 と 27.2 だけ。
6. **互換の相手に本物の 1.3 を足すには**、`tools/span-compat` に `v13`（`run.sh` の case・`v13/Version.swift`）と、955fe67 のアプリで走る `Real13LedgerTests.swift`、`compat-v1-0` の段 3 つ（取り出し・Probe・アプリのテスト）が要る。955fe67 の全体の SHA は `955fe678ec9f999ac45fac1b372f246e43c02f95`。
7. **中国の 2027 年の祝日は、python-holidays の今の最新版 0.109 にも dev の枝にも、まだ無い**（2026-11-20 に読んだ。下の 5.1）。

---

## 1. (a) M7_PLAN §6.2 の一覧と、アプリ全体と Kit の検索

検索した語: `UIScreen`・`userInterfaceIdiom`・`horizontalSizeClass`・`verticalSizeClass`・`UIDevice`・`isPad`・`isPhone`・`displayScale`・`nativeScale`・`interfaceOrientation`・`screen.bounds`・`connectedScenes`・`requestGeometryUpdate`・機種の寸法の数字（402・440・744・820・834・874・1024・1032・1366 ほか）。

- `horizontalSizeClass`・`verticalSizeClass`・`nativeScale` は **0 件**（アプリにも Kit にも無い）。
- 機種の寸法の数字が書いてあるコードは `SpanPlan.swift:269-276` だけ（注を除く）。

### 1.1 M7_PLAN §6.2・§2.10 の行番号の読み替え

| M7_PLAN に書いた所 | 今の行（7895d40） | 中身 |
| --- | --- | --- |
| `project.yml:18` `IPHONEOS_DEPLOYMENT_TARGET` | `project.yml:21`（ほかに `:8`・`:45`・`:147`・`:184`） | 17.0 |
| `project.yml:71-82`（全方向・`UIRequiresFullScreen`） | `project.yml:99`・`:101-110` | `UIRequiresFullScreen: false`、4 方向 |
| `CalendarRootScreen.swift:192, 319` `compactWidth` | `:319`（定義）・`:810`（使う所） | 600 pt |
| `CalendarRootScreen.swift:224` iPhone は週から | `:432-433` | `fallbackKind` |
| `CalendarRootScreen.swift:681` 指でも書くを既定オン | `:1253-1257` | `allowFinger = idiom != .pad` |
| `PaywallSheet.swift:196` | `:196`（同じ） | |
| `EventEditorSheet.swift:119, 136` | `:119`・`:136`（同じ）。ほかに `:268` | |
| `SettingsScreen.swift:107, 319` | `:111-115`・`:208`・`:456-468` | |
| `InkSnapshot.swift:24` | `:24`（同じ） | |
| `PaperView.swift:215` | `:230` | `window?.screen.scale` |

### 1.2 端末の種類・画面で見た目や既定を決めている所（全部）

「凍結」は `tools/compat10/DATA_1_1.sha256` の 20 ファイルに入るか。入るファイルは 1.4 では凍結（M7C_CONTRACT §6.4 の手順 4）。

| # | file:line | 今の決め方 | Duo で起きること | 凍結 | 直し方の候補 |
| --- | --- | --- | --- | --- | --- |
| 1 | `Sources/TegakiCalendar/Views/CalendarRootScreen.swift:432-433` | `idiom == .phone` なら週から開く（初めての起動で、前の種類の記録が無いとき） | 内側でも週から開く | 外 | 幅 600 以上なら月。**`init` の中なので幅がまだ無い**。最初の配置（`GeometryReader`）で決める形にする要がある |
| 2 | `CalendarRootScreen.swift:1253-1257`（`appear()`） | `allowFinger = idiom != .pad`（注「iPhones and Macs have no Pencil」） | Duo も指でも書くがオン。Pencil は `drawingPolicy = .anyInput` で書ける（`InkCanvasView.swift:678`）ので書けなくはならない | 外 | M7_PLAN §6.2 の「初回に Pencil が触れたら 1 回だけ案内」。Pencil の触れを知る口は今は無い（`onPenDown` `InkCanvasView.swift:196` は道具の種類を言わない。Pencil を数える `InkTouchObserver` と `InkCanvasView` は凍結）。凍結の外で、画面の側に Pencil だけの認識器を足す形なら凍結を崩さない |
| 3 | `CalendarRootScreen.swift:1049`・`:2745`・`:1769-1771` | `usesMinTapTarget(isPhone:width:)` = `isPhone \|\| width < 600`（年の 44 pt の的） | 内側でも 44 pt の的 | 外。**ただしテストが凍結**（`Tests/TegakiCalendarTests/CalendarRootScreenTests.swift:116-128`、TESTS_1_2_3） | 関数の形は変えず、呼ぶ側で `isPhone:` に渡す値を変える（例: `isPhone && width < 600`）。関数を変えると凍結のテストの表の作り直しになる。内側の縦の年の一覧のマスは約 37 × 20 pt【推定】で、44 pt より小さい。的を iPad と同じにするかは決めどころ |
| 4 | `CalendarRootScreen.swift:1503`（`opening`）→ `Span/ScreenPaths.swift:265-269` → `TegakiKit/Sources/Layout/SpanPlan.swift:19-32` | `isPad` は idiom。iPhone はどの寸法でも `.iPhone` | Duo は内側も外側も `.iPhone`（§3） | 外 | 今のままでよい見込み（§3）。Duo の行を作るなら `SpanDeviceClass` に case を足し、KitChecks（`SpanChecks.swift:422-426`）と門の数（`build.yml:155-165`）が変わる |
| 5 | `Sources/TegakiCalendar/Views/PaywallSheet.swift:196-206` | `.phone` なら `.presentationDetents([.large])`、ほかは iOS 18 から `.form.fitted` | 内側でも全画面の高さ。縦横とも regular の iPhone で `.sheet` がフォームシートになるかは【未確認】 | 外 | 幅で分ける |
| 6 | `Views/EventEditorSheet.swift:135-141` | 同じく `.phone` なら `.large` | 同じ | 外 | 幅で分ける |
| 7 | `Views/EventEditorSheet.swift:119`・`:268-272` | `isPad` のときだけ「Scribble の注」（`event.scribbleNote`） | Duo では出ない。iPhone で Scribble が使えるかは【未確認】 | 外 | 能力の話なので idiom のままでもよい（決めどころ） |
| 8 | `Views/SettingsScreen.swift:111-115`・`:208`・`:456` | `isPad` で「消しゴムで戻る」の脚注を Pencil の文に | Duo では Pencil の文が出ない | 外。テスト `SettingsScreenTests.swift:136-148`（凍結ではない）が「iPhone の設定は Pencil を言わない」を固めている | 能力の話。文を変えると 9 言語の訳と逆翻訳が要る |
| 9 | `Views/SettingsScreen.swift:458-468` | `isPad` のときだけ「Apple Pencil」の行と脚注（`settings.input.pencil.footer`「iPad の『設定 › Apple Pencil』…」） | Duo では出ない | 外 | 出すなら脚注の「iPad の」を直す要がある（訳が要る）。iPhone に「設定 › Apple Pencil」があるかは【未確認】 |
| 10 | `Sources/TegakiCalendar/Ink/InkSnapshot.swift:24` | `render(..., scale: CGFloat = UIScreen.main.scale)` | 内側と外側で倍率が違えばずれる恐れ（M7_PLAN §6.2）【未確認】 | **凍結**（DATA_1_1 の 4 行目） | 既定の引数は残し、呼ぶ側 `CalendarRootScreen.swift:1935`・`:2989` で `scale:` を渡す（SwiftUI の `@Environment(\.displayScale)` など）。凍結を崩さない。`InkSnapshot.image` の呼び出しは既に倍率を渡している（`InkCanvasView.swift:2267-2268` は `traitCollection.displayScale`、`Export/PDFPageRenderer.swift:254`・`:259` は `inkScale`） |
| 11 | `Sources/TegakiCalendar/Paper/PaperView.swift:228-233` | `didMoveToWindow` で `window?.screen.scale` | 開閉で画面が替わったときに `didMoveToWindow` が来るかは【未確認】 | 外 | `traitCollectionDidChange`／`registerForTraitChanges` の `displayScale` で読み直す |

ほかに見つけた所（直さなくてよい見込み）:

- `CalendarRootScreen.swift:1489-1494` `sceneScreenSize`: つながっている場面のうち前にある物の `screen.bounds`。窓の機種と向きの元（review J6）。開閉で `screen` が替わるときに値が付いて来るかは【未確認】。
- `Ink/InkCanvasView.swift:3295`（`redecideWindow`、凍結）: `container.window?.windowScene?.screen.bounds.size`。幅が変わった後の止まりで窓を決め直す（`bandWidthChanged` `:3060-3082` で `pendingRedecide`）。開閉も幅の変化なので、この道を通る見込み【推定】。
- `CalendarRootScreen.swift:1408-1415` 写真モードの横向き（`requestGeometryUpdate`）。注（`Support/ScreenshotMode.swift:17-19`）は「iPhone だけ回る」。Duo も iPhone なので回る見込み【推定】。
- `Support/ScreenshotMode.swift:767` `SpanPlan(deviceClass: .iPad11, orientation: .portrait)`: 見本のページの id を作るだけ（index と pageId しか使わない）。端末に依らない。
- `Ink/InkCanvasView.swift:625` `identifierForVendor`（端末の id。見た目ではない）。`Ink/InkTrace.swift:32`（凍結）`UIDevice.current` の model を記録に書くだけ。`Views/AgeRangeAsker.swift:92` 年齢の確かめのシートの土台を探すだけ。
- 幅で決める所（Duo でもそのまま正しい）: `CalendarRootScreen.swift:319`・`:810`（見出し 1 段／2 段）、`Views/PageHeaderView.swift:9`・`:33`、`TegakiKit/Sources/Layout/DateTap.swift:9`（注）。
- Pencil の書く・書かないは idiom で決めていない（`InkCanvasView.swift:678` `drawingPolicy = allowFinger ? .anyInput : .pencilOnly`）。2 本指で横に動かすかも「指でも書く」で決まる（`Views/SpanGuideView.swift:27-30`）。

### 1.3 画面に出る文で iPhone／iPad を言う所（1.4 で文を変えるなら訳が要る）

`tools/l10n/source/app-U.json` の ja: `settings.input.eraserAutoReturn.footer.pad`（:1592）・`.phone`（:1610）、`settings.input.pencil.footer`（「iPad の『設定 › Apple Pencil』」）、`settings.input.allowFinger.footer`（「iPad と Apple Pencil で書くのに向いています」）、`settings.data.erase.warning.cloud`、`settings.data.importFooter`、`settings.calendar.google.howTo`。M7_PLAN §4.5 は「1.4 には他の機能を混ぜない」なので、文は変えない既定が合う。

### 1.4 span plan の端末の数（Kit）

| file:line | 中身 |
| --- | --- |
| `TegakiKit/Sources/Layout/SpanPlan.swift:4-7` | 注「The iPhone Duo's inner screen is 1.4's (§1.6; its row of the table is checked on the radius rule only)」 |
| `SpanPlan.swift:19-32` | `SpanDeviceClass(screen:isPad:)`。iPhone は全部 `.iPhone`。iPad は短い辺で mini（780 以下）・11（900 以下）・13 |
| `SpanPlan.swift:40-42` | `SpanOrientation(screen:)`。幅 > 高さで横 |
| `SpanPlan.swift:76-83` | `overviewCapPages`: `.iPhone` かつ横だけ、週・年 3、日 5、月 nil |
| `SpanPlan.swift:91-94` | `maxVisiblePages(viewport:)`: 向きは**紙の領域の形**で決める（画面の向きではない） |
| `SpanPlan.swift:131`・`:134-136` | 窓の線の上限 iPad 20,000・iPhone 12,000（Duo は 12,000） |
| `SpanPlan.swift:265-286` | `referenceViewport`: 機種と向きの紙の領域。iPhone 縦 402 × 540（週）・536（日）、iPhone 横 874 × 205 |
| `SpanPlan.swift:289-298` | `visiblePages`・`radius`（行の値から） |
| `SpanPlan.swift:334-336` | `flingTarget` の `viewportWidth` nil は行の幅。キャンバスは実際の幅を渡している（`InkCanvasView.swift:2176-2177`） |
| `Sources/TegakiCalendar/Span/SpanSession.swift:416-420` | `windowRadius`: 行の R と、測った紙の領域の R の大きい方 |
| `SpanSession.swift:422-429` | `fittingRadius`: 広げた窓の線の見積もりが上限を超えたら行の R に戻す |
| `SpanSession.swift:1059-1065` | `redecide(orientation:paperArea:)`: 機種は替えず向きと R だけ決め直す |
| `Span/ScreenPaths.swift:414-424` | `makeSession` は必ず `overviewCap: true` |
| `Span/ScreenPaths.swift:1017-1027` | `atCappedOverview`: 横の上限の倍率以下なら「上限ありの一覧」（今日の 1 時間前から開く・「今日」は上下だけ） |
| `TegakiKit/Sources/KitChecks/SpanChecks.swift:380-383` | Duo 内側の V（1.37・2.40・1.00・1.27）を R の規則だけで確かめる（「1.4 checks it again」） |
| `SpanChecks.swift:421-426` | 機種の分け方の確かめ（`(1032, 1376, false) → .iPhone` を含む） |
| `Persistence/AppSettings.swift:107-113`・`:289` | 倍率の比の鍵は種類ごとに 1 つ（`zoomRatio.<kind>`）。2 本の道が同じ値を使う（上限ありの決定 1） |

### 1.5 project.yml・Kit・道具の版

| file:line | 今 | 1.4 で見る所 |
| --- | --- | --- |
| `project.yml:7-8`・`:21`・`:45`・`:147`・`:184` | 配布の最低版 iOS 17.0（5 か所） | Xcode 27.1 で 17.0 のままビルド・提出できるか（M7_PLAN §4.5 の最初の手順）【未確認】 |
| `project.yml:19-20` | `SWIFT_VERSION: "5.0"`・`SWIFT_STRICT_CONCURRENCY: minimal` | Xcode 27 の Swift で 5 の言語モードが使えるか【未確認】。この Mac の Swift 6.4.2 では typecheck が通った |
| `project.yml:23-24` | `MARKETING_VERSION "1.3"`・`CURRENT_PROJECT_VERSION "1"`（TestFlight は run の番号で上書き） | "1.4" に |
| `project.yml:22`・`:117`・`:170`・`:193` | `TARGETED_DEVICE_FAMILY "1,2"` | そのまま |
| `project.yml:99-110` | `UIRequiresFullScreen: false`、iPhone も iPad も 4 方向 | Duo の内側で 2 つ並べるときに要る鍵があるか【未確認】 |
| `project.yml:129` | `-weak_framework DeclaredAgeRange` | そのまま。確かめの段 `build.yml:207-` と `testflight.yml:250-262` |
| `TegakiKit/Package.swift:1`・`:34` | tools 5.9、`.iOS(.v17), .macOS(.v14)` | そのまま見込み |
| `tools/typecheck/typecheck.sh:41` | `arm64-apple-ios17.0-macabi` | そのまま |
| `tools/span-compat/run.sh:43-50` | 作るパッケージは tools 5.9・macOS 14 | そのまま |
| `tools/compat10/Package.swift:1`・`:20`、`tools/weekstart-compat/v10/run/Package.swift`・`v11/run/Package.swift` | 同じ | そのまま |

Xcode や シミュレータの版を決め打ちしている道具は、workflow の外には無い（`tools/` を検索して 0 件。`tools/shots/span_margin.swift:298-301` の 820x1180 は自分の試験の値）。

### 1.6 CI（4 つの workflow）

**Xcode 27 の実行機の事実【Web、2026-11-20 に読んだ】**

- 表の行「Xcode 27」、ラベル `xcode-27` か `xcode-27-xlarge`、arm64、印は「preview」（issue #14404）。macOS 27 の行は無い。<https://github.com/actions/runner-images/blob/main/README.md>
- イメージ 20261104.0337.1、macOS 27.0.1。Xcode 27.2（27B52）・**27.1（27A9275、既定）**・27.0。iOS SDK 27.0・27.1・27.2。Homebrew 7.0.12、Python3 3.15.2、XcodeGen は一覧に無い。<https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md>
- シミュレータ: iOS 27.0 = iPhone 17・17e・18 Pro・18 Pro Max・Air、iPad (A16)・Air 11-inch (M4)・Air 13-inch (M4)・**mini (A17 Pro)**・Pro 11-inch (M5)・Pro 13-inch (M5)。**iOS 27.1 = iPhone Duo だけ**。iOS 27.2 = 27.0 と同じ並び（ただし mini は **(A20 Pro)**）と iPhone Duo。**iPhone 17 Pro Max はどの版にも無い**（同じ URL）。
- 今の `macos-26`（イメージ 20261102.0473.1）は Xcode 26.6 が既定、ほかは 26.x だけ。iOS 26.2・26.4・26.5 のシミュレータ（26.5 が足された）。Xcode 27 は無い。<https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md>

**決め打ちしている所（全部）**

| workflow | 実行機 `runs-on` | Xcode を選ぶ所 | 端末の名前 |
| --- | --- | --- | --- |
| `build.yml` build-and-test | `:79` | `:119-126`（`Xcode_26.6.app` があれば選ぶ） | `:368-398` 単体テストの端末（`iPad Pro 13-inch` で始まる物、無ければ `iPad Air 13-inch`、iPad、iPhone、最後は "iPhone 17"）、`:616-656` 13 インチの写真の端末（UDID・起動）と `:692-` の写真、`:989-992` 他の端末（`iphone|iPhone 17`・**`iphone69|iPhone 17 Pro Max|iPhone 17 Pro Max,iPhone 17 Pro,iPhone 16 Pro Max`**・**`ipadmini|iPad mini (A17 Pro)|iPad mini`**・`ipad11|iPad Pro 11-inch (M5)|…`）、`:1147-1155` 店の写真の寸法（`ipad13`・`iphone`・`iphone69`・`ipad11`） |
| `build.yml` ui-tests | `:1213` | `:1227-1228` | `:1248-1290` iPhone 17（無ければ iPhone 17 で始まる物、iPhone） |
| `build.yml` compat-v1-0 | `:1393` | `:1414-1415` | `:1576-1595`・`:1618-1637` iPad 13 の順（最後は "iPhone 17"） |
| `build.yml` l10n-shots | `:1676` | `:1692-1693` | `:1766-1767`（`ipad13|iPad Pro 13-inch (M5)`・`iphone|iPhone 17`） |
| `build.yml` blank-paper | `:1916` | `:1931-1932` | **`:1957` `-destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)"`（名前を直に書いた唯一の所）**、`:1977-1980`（`iphone69|iPhone 17 Pro Max|iPhone 17 Pro Max,iPhone 16 Pro Max`・`ipadmini|iPad mini (A17 Pro)`・`ipad11|iPad Air 11-inch (M4)`） |
| `build.yml` span-shots-app | `:2100` | `:2116-2117` | `:2189-2192`（ipad11・ipadmini・ipad13・iphone） |
| `ja-baseline.yml` | `:61` | `:128-129` | `:162-187`、`:558-561`（iphone69・ipadmini を含む）、`:690` |
| `store-shots.yml` | `:55` | `:95-96` | `:170-171`（`ipad13`・**`iphone69|iPhone 17 Pro Max`**）、`:258-264` 店の寸法（`ipad13`・`iphone69` だけ） |
| `testflight.yml` | `:49` | `:119-124` | 無し（archive。`:233-248`） |

- iOS の版（26.4 など）を決め打ちした所は無い。端末は名前と前置きで探し、版は「13 インチと同じ版 > 新しい版」で選ぶ（`build.yml:628-640`、`ja-baseline.yml:566-580`、`store-shots.yml:176-190`）。
- `env.txt` に `xcodebuild -version` と端末ごとの版を書く（`build.yml:700-719`・`:969-`、`ja-baseline.yml:293-312`・`:538-551`）。J-4 は同じ Xcode・同じ版で撮った写真どうしで比べる約束（`ja-baseline.yml:38-41`）。
- **Duo の写真を店に出すには**、寸法の表に Duo を足す要がある: `build.yml:1147-1155` と `store-shots.yml:258-264` の `accepted()`。提出の寸法は外側 1398 × 2034、内側 2007 × 2853（M7_PLAN §6.2。Apple の仕様のページ）。シミュレータの内側の写真 1878 × 2670 は縦横の比が同じ（0.7034 と 0.7035）で、`sips` で拡大する見込み【推定】。ストアの写真を Connect に上げる道具（`asc12/`）はリポジトリの外。Duo の表示の種類の名前（API の display type）は【未確認】。
- `testflight.yml` には、archive が使った SDK（`DTSDKName`）と最低版（`MinimumOSVersion`）を確かめる段が無い。ITMS-90725 の直しを機械で確かめるなら `:250-262` の「Check the archive」に足すのが自然。
- XcodeGen は毎回 `brew install xcodegen`（版を決めていない。`build.yml:264`・`:1236`・`:1566`・`:1701`・`:1940`・`:2126`、`ja-baseline.yml:137`、`store-shots.yml:104`）。Xcode 27 の形の project を作れるかは【未確認】。

### 1.7 テストが固めている「iPhone = 狭い」の前提

| file:line | 前提 | Duo のシミュレータで走らせたとき |
| --- | --- | --- |
| `Tests/TegakiCalendarTests/CalendarRootScreenTests.swift:116-128`（**凍結**） | `usesMinTapTarget(isPhone: true, width: …)` は 390〜812 で true、`compactWidth == 600` | 関数を変えなければ通る |
| `Tests/TegakiCalendarUITests/HeaderAndPaperUITests.swift:18`・`:52`・`:79` | idiom が phone なら「狭い列」「横 750 pt」 | 内側では見出しが 1 段。並びの確かめは通るかもしれないが、`:79` の年の倍率の確かめは測った紙の領域で計算するので通る見込み【推定】 |
| `Tests/TegakiCalendarUITests/YearTapUITests.swift:64-65` | phone なら走る（44 pt の的） | 的を変えると落ちる |
| `Tests/TegakiCalendarUITests/SpanUITests.swift:371-373` | phone の週のつなぎ | 窓の数を数える所があれば違う【未確認】 |
| `Tests/TegakiCalendarUITests/SpanShotsUITests.swift:95`・`:101`・`:118`・`:147`・`:160` | 端末の名前 `iphone` は横を撮り、横は上限あり（3 週・5 日）と期待 | `iphone` の枠を Duo で撮ると、内側の横は上限が効かないことがあり（§3.2）、`span cap:` の行の期待と合わない恐れ |
| `Tests/TegakiCalendarTests/SettingsScreenTests.swift:136-148` | iPhone の脚注は Pencil を言わない | 文を変えるなら直す |
| `Tests/TegakiCalendarTests/ScreenPathsSpanTests.swift:233-260` | 機種の分け方（idiom ＋ 画面） | 変えなければ通る |

---

## 2. (b) 1.3 の残り（docs/M7C.md）

### 2.1 S6 のリードの決定 2（M7C.md:1056）の 3 件

**(a) 8 キーの comment**（第 4 陣の文のリードの決定 4、M7C.md:539）。どれも「X の訳が入るまでは ja だけのキー（jaOnly…）。X は 9 言語の訳と同じ commit で jaOnly を外す」と書いてあるが、もう訳は入っている。

| キー | 元（直す所） | 作られる xcstrings |
| --- | --- | --- |
| `settings.page.header` | `tools/l10n/source/app-U.json:1700` | `Sources/TegakiCalendar/Resources/Localizable.xcstrings:19805` |
| `settings.page.span` | `app-U.json:1711` | `:19871` |
| `settings.page.span.footer` | `app-U.json:1722` | `:19937` |
| `span.guide.day.oneFinger` | `app-U.json:2199` | `:22049` |
| `span.guide.day.twoFingers` | `app-U.json:2210` | `:22115` |
| `span.guide.week.oneFinger` | `app-U.json:2221` | `:22181` |
| `span.guide.week.twoFingers` | `app-U.json:2232` | `:22247` |
| `span.stageTwo.notice` | `app-U.json:2243` | `:22313` |

- 直すのは元の json。xcstrings は `tools/l10n/build.py` が作る（comment は `build.py:570-571`、`.strings` の注は `:609-612`）。CI の「Localized bundle check」が作り直しと `git diff --exit-code` を見るので、両方を同じ commit で。利用者には出ない。

**(b) 1 ページの道で H1・H2 がキャンバスを作り直すときに `revealRect` を消す**（S6-FC-3）。「全て消す」（H3）と `show` は消している（`CalendarRootScreen.swift:2051`・`:1453`）。消していないのは次の 2 か所:

- `CalendarRootScreen.swift:1751-1758` `remoteDeleted`（H1。`selection = nil`・`viewport = .zero`・`relayout()` の前に `revealRect = nil` を足す）。
- `CalendarRootScreen.swift:2344-2348` `chooseAccount` の `closed:`（H2「消して始める」。同じ）。
- どちらも凍結の外（M7C.md:1056 の「表は作り直さない」のとおり）。テストは `ScreenPathsSpanTests.testEraseAllForgetsTheTodayRect` と同じ「ソースを読む形」が先例。

**(c) 試作がまだあるように読める古い注**（S6-FC-4）

| file:line | 注 | 凍結 |
| --- | --- | --- |
| `TegakiKit/Sources/Layout/SpanPlan.swift:113` | 「the prototype may change it」（focusHysteresis） | 外 |
| `SpanPlan.swift:117` | 同じ（snapFraction） | 外 |
| `SpanPlan.swift:121-122` | 「measured in the prototype (§4.6)」（flingVelocity） | 外 |
| `SpanPlan.swift:130` | 「To be measured again in the prototype.」（windowStrokeCap） | 外 |
| `TegakiKit/Sources/Layout/WeekLayoutEngine.swift:31` | 「the frozen tests, the prototype and the old tools lay out the week…」 | 外 |
| `Sources/TegakiCalendar/Views/SpanGuideView.swift:16`・`:157` | 「not one of the numbers the prototype may change」・「the prototype's guide card, tag r13-proto-1」 | 外（:157 は来歴なので残してよい） |

- 決定 1（M7C.md:1055）で残すと決めた物: `TegakiKit/Sources/InkModel/SpanGuard.swift:25-27`・`:32`（`.prototype`）・`:46-47`（`prototypePrefix`）・`:67-73`・`:85-90`・`:102-105`。**このファイルは凍結**（DATA_1_1 の 19 行目）。使う所は KitChecks だけ（`SpanInkChecks.swift:163-179`・`:421-443`・`:703-707`）。消すと凍結の表の作り直しと KitChecks の数（`build.yml:155-165` の 39,970）の変更が要る。1.4 の契約で「残す」か「消して表を作り直す」かを決める。
- workflow の注（`build.yml:55-56`・`:1045`・`:1761`・`:2048-2049`・`:2071`・`:2327`、`ja-baseline.yml:19`・`:613`、`store-shots.yml:164`、`testflight.yml:25`、`tools/typecheck/typecheck.sh:32`）とテストの注（`ScreenPathsSpanTests.swift:1442`、`WeekMemoSpanTests.swift:231`）は「S6 で消した」と言う来歴の注で、古くはない。

### 2.2 zh のトーストの語（M7C.md:882 の 4）

- 店の文: 「24 点下方 / 24 點下方」（`docs/store/zh-Hans/whatsnew.txt:2`、`docs/store/zh-Hant/whatsnew.txt:2`。1.4 の新機能の文で書き換わる）。
- アプリ: `toast.eventBelowDay` は「24 点以下的自由备忘栏 / 24 點以下的自由備忘欄」（`tools/l10n/translations/zh-Hans.json:1728`、`zh-Hant.json:1728`、元は `tools/l10n/source/app-U.json:2362`）。
- 決定は「今はそろえない。母語の人に見てもらうときの候補」。1.4 は文を変えない版なので、そのままが既定に合う。

### 2.3 審査メモの 1 の「It」と 4（M7C.md:475）

- `docs/store/review-note.txt:4`: 「…and a stroke can cross the border. **It** is saved whole on the page holding its center…」（It が線を指すと読みにくい。△）。
- `docs/store/review-note.txt:7`: 「4. Even with the switch off, week pages now also have Free Notes below 24:00…」（語順を替えた後も △ の記録）。
- 1.4 の審査メモは「What is new in 1.4」に書き換えるので、この 2 つは消えるか直すかを書くときに決める。4,000 バイトの上限（M7C.md:475）。日本語の要約 `:30-31` も同じファイル。逆翻訳の記録は `docs/i18n/REVIEW.md`・`docs/i18n/back/store-review-note.md`。

### 2.4 「1.3 の後に残すもの」（r13 の ff4e3c4 の M7C.md の今の状態）

r13 の最後の記録の commit（ff4e3c4、docs だけ。main には無い）に 1 項ある: S6 の決定 2 の片づけ（上の 2.1）・上限ありの確かめの残り（無し）は 1.3.1 か 1.4。中国の 2027 年の祝日（§5.1）。年齢区分の 2 問（§5.2）。Xcode 27 への移行（1.4、ITMS-90725）。

---

## 3. (c) Duo の画面で span plan が何をするか

### 3.1 コードの道すじ

1. 機種: `ScreenPaths.device`（`ScreenPaths.swift:265-269`）→ `SpanDeviceClass(screen:isPad:)`。Duo は idiom が phone なので、**内側も外側も `.iPhone`**。向きは場面の画面（`screen.bounds`）の形。
2. 行の R: iPhone の行の参考の紙（縦 402 × 540／536、横 874 × 205）から。縦は週・日とも R 2（5 ページ）、横は上限ありで週 R 3（7）・日 R 4（9）。
3. 測った紙の領域で広げる: `windowRadius`（`SpanSession.swift:416-420`）= max（行の R、測った領域の V の R）。ただし窓の線の見積もりが iPhone の上限 12,000 本を超えるなら行の R に戻す（`:422-429`）。
4. 上限: `maxVisiblePages`（`SpanPlan.swift:91-94`）は**紙の領域が横長なら**（画面が縦でも）iPhone の上限（週 3・日 5）を当てる。`ZoomPolicy.cappedBounds`（`TegakiKit/Sources/Layout/ZoomPolicy.swift:158-167`）は上限の倍率が今の最小より上のときだけ効く。
5. 開閉: 幅が変わる → `bandWidthChanged`（`InkCanvasView.swift:3060-3082`）→ 止まった後に `redecideWindow`（`:3289-`）→ `redecide`。機種は替えない（どちらも `.iPhone` なので困らない）。
6. 見出し: 幅 600 以上で 1 段（`CalendarRootScreen.swift:810`）。内側は縦横とも 1 段。外側の縦（約 466）は 2 段。外側の横（約 678）は、左右の安全域を引いた幅が 600 を超えるかで 1 段か 2 段か決まる【未確認】。

### 3.2 計算（この Mac で `ZoomPolicy`・`SpanPlan` の式をそのまま写して計算した【推定】）

画面の pt は Apple が出していない。内側は 669 × 951 か 626 × 890、外側は約 466 × 678（M7_PLAN §6.2 の推定）。紙の領域の高さは、今の機種の実測から「画面の高さ − 見出し・帯・安全域」の幅で置いた: 1 段の見出しの縦は 255〜334 pt を引く（iPad mini 縦と iPhone 17 縦の実測の差）、横は 197〜223 pt を引く（iPhone 17 横の推定と実測）、2 段の見出しの縦は 334 pt を引く。日は週より 4 pt 低い（帯の 1 レーン）。計算の写し: `docs/m7d/duo_span_calc.py`（`python3 -I` で走る。最後の 2 行は今の iPhone 17 の値と KitChecks の表の値が合うかの確かめ）。

| 画面 | 紙の領域（週） | 週: V → 窓 | 日: V → 窓 | 上限 | 24 時間が入るか |
| --- | --- | --- | --- | --- | --- |
| 内側 669 × 951 縦 | 669 × 617〜696 | 1.32〜1.49 → 5（行の R 2 のまま） | 2.32〜2.62 → **7**（行は 5、測った領域で広がる） | 効かない | 入る |
| 内側 626 × 890 縦 | 626 × 556〜635 | 1.35〜1.54 → 5 | 2.38〜2.72 → **7** | 効かない | 入る |
| 内側 951 × 669 横 | 951 × 446〜472 | 2.76〜2.92 → 7 | 4.88〜5.16 → 9 | 週は効かない。**日は 446 pt では効く（23.2 時間）、472 pt では効かない** | ほぼ入る |
| 内側 890 × 626 横 | 890 × 403〜429 | 2.85〜3.03 → 7 | 5.03〜5.35 → 9 | **週は 403 pt で効く（23.8 時間）、日はどちらも効く（22.4〜23.9 時間）** | ほぼ入る |
| 外側 466 × 678 縦（2 段） | 466 × 344 | 1.86 → 5 | 3.29 → **7**（行は 5） | 紙の領域は横長なので上限を当てるが、効かない | 入る |
| 外側 678 × 466 横 | 554〜678 × 243〜269 | 3.13〜3.83 → 7（上限 3） | 5.56〜6.81 → 9（上限 5） | **効く** | 入らない（17.6〜23.0 時間） |
| 参考: iPhone 17 横（実測 750 × 179） | | 5.75 → 7（上限 3） | 10.29 → 9（上限 5） | 効く | 約 12 時間 |

読み方:

- 窓は 5〜9 ページで、今の iPhone・iPad の範囲の中。KitChecks の Duo の行（V 1.37 → 5、2.40 → 7、`SpanChecks.swift:381-383`）とも合う。ただし **Duo の内側の縦の日の 7 ページは、行ではなく測った領域で広がって出る**。線が多くて 12,000 本の見積もりを超えると 5 ページに戻る。V が 3 より小さいので、5 ページでも 1 回のはじきで窓の端は見えない（R 2 の窓の半分は 2.5 ページ、はじいた後に見える右の端は 1 + V/2 ≦ 2.36）【推定】。
- **内側の横は、上限が「効く／効かない」の境目にいる**。境は週で紙の高さ < 0.457 × 幅、日で < 0.48 × 幅。帯のレーンが増えると紙が低くなって効き始める。効くと「上限ありの一覧」になり、今日のページは今の 1 時間前から開き、「今日」は上下だけ動く（`ScreenPaths.swift:1017-1027`、契約 §3.6）。効かないと 0:00 から開く。**同じ端末で、帯のレーンの数で開く高さが変わりうる**。上限は 874 × 205 の小さな横の画面のために決めた物なので、Duo の内側の横にも当てるかは 1.4 の決めどころ。
- 外側の横は今の iPhone 横に近く、上限がはっきり効く（約 18〜23 時間が見える）。
- 倍率の比の鍵は 2 本の道で 1 つ（`AppSettings.swift:111-113`）。上限ありの決定 1 の「横の道の倍率が 1 ページの道の約 2 倍」は iPhone 横の話で、Duo の内側では差は 1.0〜1.1 倍ほど【推定】。外側の横では 1.2〜1.5 倍ほど【推定】。

### 3.3 週のメモと一覧の倍率

- 週のメモは 24 時の下の `extra` のマス（`WeekLayoutEngine.swift:20-31`、`freeMemo` はアプリの 2 か所が true）。一覧の倍率は 24 時間の格子（1400 × 1920）で決まり、メモはスクロールで行く（`ZoomPolicy.overviewSize`）。端末で変わる所は無い。
- 1 ページの道の一覧（`ZoomPolicy.bounds`）は紙の領域だけで決まる。内側の縦の週は約 0.33〜0.36 倍で、紙の幅は約 474 pt、左右に机の色が約 97 pt ずつ【推定】。読める倍率（週 0.4716、`ZoomPolicy.readableZoom`）より小さいので、字は比例して小さくなる（今の iPad の縦の一覧と同じ扱い）。
- 横の道の窓の帯の幅: 最大倍率 × 窓のページ数。内側の横の日（9 ページ、最大倍率 max(4 × 951/1000, 2 × 0.561) ≈ 3.8）で約 34,000 pt【推定】。今の iPhone 横の日の窓 9 ページ（約 52,000 pt は上限の前の 15 ページの値、B_DESIGN §6.1）より小さい。

### 3.4 Duo で確かめていないこと

- 開閉のときに `windowScene.screen` が替わるのか、同じ画面の `bounds` が替わるのか【未確認】。`sceneScreenSize`（`CalendarRootScreen.swift:1491-1494`）と `redecideWindow`（`InkCanvasView.swift:3295`）はどちらでも今の値を読む作り。
- iOS 27.1 SDK で、内側のステータスバーが右の端にあるときの安全域（左右か上下か）【未確認】。上の表の紙の高さはこれで変わる。
- 内側で 2 つのアプリを並べたときの窓の幅。向きは画面から取るので（review J6）、窓が細くても「縦」のまま。

---

## 4. (d) 本物の 1.3（955fe67）を互換の相手に足すのに要る物

M7C_CONTRACT §6.4（`docs/M7C_CONTRACT.md:880`）: 「1.4 以後の手書きのデータに触れる版は、本物の 1.3 を互換の相手に足す（`tools/span-compat` の Probe と、アプリの台帳のテストの両方）」。M7C.md:1057 の決定 3 も同じ。1.4 が手書きのデータのコードに触れないなら、足すかどうか自体が 1.4 の契約の決めどころになる（触れないなら「足さない」と書けば済むが、§6.4 の文は「1.4 から」と読める）。

### 4.1 今の作り

- `tools/span-compat/run.sh:21-26` 版は `v10|v11|v123` だけ。`:6-9` の注に SHA。`:38-54` で版の TegakiKit を指すパッケージを作り、`Probe/Common.swift`・`Probe/main.swift`・`<版>/Version.swift` を組んで走らせる。
- `tools/span-compat/v123/Version.swift:11-33` 版の名前・`expectedDrawn`（見本ごとの描く線の数）、`:36-53` `versionLayout`（1.2.3 の画面と同じレイアウトの作り方）。
- `tools/span-compat/Probe/Common.swift:6-8` 「1.0・<1.1.1>・1.2.3 のどれにもある API だけを使う」。
- `tools/span-compat/AppTests/Real123LedgerTests.swift`（291 行）: 43fe366 のアプリの台帳と同期のエンジン。`:54-` `drawnBy123`、`:106`・`:110` のレイアウト、`:139`・`:170` `InkLedger(page:layout:)`、`:199` `SyncEngine(`。
- `tools/span-compat/README.md:5-12`・`:27-40`・`:42-46`（手順と、見本を足すときの決まり）。
- CI `compat-v1-0`（`build.yml:1363-1388` の注、`:1389-1650` の本体）:
  - `:1540-1552` 「Take out 1.2.3 (43fe366) at v123 and v123app」（`git fetch --depth=1 origin <SHA>` → `git archive`）。
  - `:1554-1561` 「The compat-span fixtures on the real 1.0, <1.1.1> and 1.2.3 (span-compat)」（`for V in v10 v11 v123`）。
  - `:1613-1650` 「1.2.3's ledger and sync on the compat-span fixtures (Real123LedgerTests)」（ファイルを写し、`xcodegen generate`、端末を選び、`-only-testing:TegakiCalendarTests/Real123LedgerTests`）。
  - `:1395` `timeout-minutes: 45`（注 `:1384-1388` に実測。1.3 のアプリを足すと、アプリのビルドとテストの段が 1 つ増える）。

### 4.2 足す物（1 つずつ）

1. `tools/span-compat/run.sh:23-26` の case に `v13` を足し、`:6-9` の注に `955fe678ec9f999ac45fac1b372f246e43c02f95` を書く。
2. 新しい `tools/span-compat/v13/Version.swift`: `versionName = "1.3 (955fe67)"`、`versionFolder = "v13"`。`versionLayout` は **1.3 の画面と同じに `WeekLayoutInput(..., freeMemo: true)` と `DayLayoutInput` の `extraFloor`** を渡す（`WeekLayoutEngine.swift:20-31`。省くと 1.2.3 の週になり、1.3 の本当の見え方にならない）。週の始まりは v123 と同じ（日曜の `w-` は日曜始まり）。`expectedDrawn` は 1.3 の描く数で書き直す（週のメモの見本 `w-2026-12-14`・`w-2026-12-21`・`w-2026-12-20` は、1.3 では `extra` のマスがあるのでメモの線も描く。数は見本のファイルから数えて書く）。
3. 1.3 が初めて持つ物を Probe で確かめるかの決めどころ: 1.3 の Kit には `SpanComposer`・`SpanGuard`・`SpanPlan`・`SpanLayout` がある。今の Probe は「3 つの版のどれにもある API だけ」を使う（`Common.swift:6-8`）。1.3 の窓の合成（`SpanComposer`）で見本を読む確かめを足すなら、`v13` 専用の確かめを `Version.swift` の側に置く形になる。
4. 新しい `tools/span-compat/AppTests/Real13LedgerTests.swift`: `Real123LedgerTests.swift` の形で、1.3 のアプリの台帳と同期。1.3 で台帳と同期の口が変わった（S4 の 2 つの口、`ownerId`、`onRemoteDelete`、H1〜H4・G4 の直し）ので、使える API は 955fe67 の `InkLedger.swift`・`SyncEngine.swift` で確かめて書く。1.3 のテストの的にある `TestSleeper` などは 955fe67 の `Tests/TegakiCalendarTests` から使える。横の道の台帳（`InkLedgerSpanTests` が使う窓の台帳）でも読むかは決めどころ。
5. `build.yml` の `compat-v1-0` に段を足す: 「Take out 1.3 (955fe67) at v13 and v13app」（`:1540-1552` の写し）、`:1554-1561` の `for V in v10 v11 v123` に `v13`、「1.3's ledger and sync … (Real13LedgerTests)」（`:1613-1650` の写し）。`:1363-1388` の注と `timeout-minutes` の見直し。
6. `tools/span-compat/README.md` の表・走らせ方・「見本を足すとき」に v13 を足す。
7. 見本（`TegakiKit/Tests/Fixtures/compat-span`）: 1.4 が新しい保存の形を書かないなら、足す見本は無い。`tools/compat-span/EXPECTED_MIN`（月曜の見本の数 × 17 ＋ 1.2.3 の 361 = 599、`build.yml:1491-1509`）は変わらない。
8. 1.2.3 の凍結のテストの表（`tools/span/TESTS_1_2_3.sha256`、8 ファイル。`build.yml:246-259`）に当たる「1.3 の既存のテストを 1 バイトも変えない」表を 1.4 で作るかは決めどころ（D9 の 1.4 版）。凍結のデータのコードは `DATA_1_1.sha256` の 20 行のまま守る（「Data code frozen (re-based in 1.3)」`build.yml:246-249`）。

### 4.3 Xcode 27 で古い木をビルドする危険

- `compat-v1-0` は、1.0（a21e469）と 1.2.3（43fe366）の**アプリ全体**を、その時の実行機の Xcode でビルドしてテストする（`:1571-1611`・`:1613-1650`）。1.4 で実行機を `xcode-27` にすると、古い木を Xcode 27 でビルドすることになる。古い木のコードは直せない（直すと本物でなくなる）。Xcode 27 で古い木が警告でなくエラーになる所があれば、この段は通らない【未確認】。955fe67 を足すときも同じ。
- 逃げ道の候補: `compat-v1-0` だけ `macos-26`（Xcode 26.6）に残す。互換の確かめは「古い版の本物のコードが新しいデータを読む」ことなので、古い版をそれが作られた Xcode でビルドする方が本物に近い。ただし `macos-26` のイメージがいつまで残るかは【未確認】（macOS 14 は 2026-11-02 に引退した。<https://github.com/actions/runner-images/blob/main/README.md>、2026-11-20 に読んだ）。

---

## 5. そのほか（コードが触れる所だけ）

### 5.1 中国の 2027 年の祝日

- 【Web、2026-11-20 に読んだ】PyPI の最新は **0.109**（<https://pypi.org/pypi/holidays/json> の `info.version`）。`holidays/countries/china.py` の特別な休みの表の最後の年は、タグ v0.109（<https://raw.githubusercontent.com/vacanza/holidays/v0.109/holidays/countries/china.py>）でも dev の枝（<https://raw.githubusercontent.com/vacanza/holidays/dev/holidays/countries/china.py>）でも **2026**。2027 の行は無い。これは取得した文を要約する道具の読みで、生の行を目で全部は確かめていない【未確認の度合いは低い】。
- 入れるときに触る所（`tools/holidays/README.md:57-70` の手順）: `tools/holidays/requirements.txt:8-13`（版と hash）、`TegakiKit/HolidayData/*.json`・`SOURCE.json`（`"version":"0.107"`）・`index.json`、`TegakiKit/Sources/Holidays/HolidayDataLicense.swift:11`・`:41`（`v0.107` の URL）、`TegakiKit/Sources/KitChecks/HolidayChecks.swift:5`・`:142`・`:155`・**`:175-190`（中国の最後の公式の年 2026 と、2027 の推定を決め打ち）**・`:220`・`:234`・`:248`・`:258`・`:271`・`:277-278`・`:368`、`TegakiKit/Tests/HolidaysTests/WorldHolidaysTests.swift:7-9`・`:113`、`tools/holidays/gen.py:97`（`PUBLISHED_AND_COMPARED`）。取り寄せは毎回本人の了承が要る（README:61 の手順 1、M7C_CONTRACT §9.3）。

### 5.2 年齢区分の新しい 2 問

- リポジトリのコードは触らない。Connect に入れる道具は `asc12/`（リポジトリの外）。M7C.md の今の状態のとおり、まだ API に無い（期限 2027-01-12）。

---

## 6. 危険の一覧（重い順）

1. **CI の端末が無い**: `xcode-27` に `iPhone 17 Pro Max` が無い → `iphone69`（6.9 インチ）の写真が全部飛ばされ、店の 6.9 インチの写真を撮れない（`build.yml:990`・`:1977`、`ja-baseline.yml:559`、`store-shots.yml:171`）。代わりの端末（iPhone 18 Pro Max など）の画素が 6.9 インチの寸法（`accepted()`）に入るかは【未確認】。`iPad mini (A17 Pro)` は 27.0 にしか無く、27.2 では A20 Pro。
2. **Xcode 27.1 と 27.2 のどちらにするか**: 27.1 は既定。Duo の Pencil は 27.2 で動くとの報道（M7_PLAN §6.2）。Xcode 27.1 で 27.2 のシミュレータが使えるかは【未確認】。27.1 だけなら Duo は 27.1 の版にしか無い。
3. **凍結のテスト**: `usesMinTapTarget(isPhone:width:)` を変えると TESTS_1_2_3 の `CalendarRootScreenTests.swift` が落ちる。呼ぶ側で値を変える形にしないと凍結の表の作り直しになる。
4. **凍結のデータのコード**: `InkSnapshot.swift`・`InkCanvasView.swift` は凍結。`UIScreen.main.scale` は呼ぶ側で逃げられるが、開閉で `InkCanvasView` の中を直す要が出たら、契約で許す所を足し、表を作り直し、互換の相手（本物の 1.3）も要る。
5. **古い木を Xcode 27 でビルド**: `compat-v1-0` が 1.0・1.2.3（と足すなら 1.3）のアプリを新しい Xcode でビルドする。通らないと互換の確かめが止まる（§4.3）。
6. **iPhone は週から開くの直しは `init` の中**: 幅が分からない時に決めている（§1.2 の 1）。作りを変える要がある。
7. **内側の横で上限が境目**: 帯のレーンの数で「上限ありの一覧」になったりならなかったりし、今日のページの開く高さが変わる（§3.2）。
8. **J-4 の基準**: 今の基準は 43fe366 を Xcode 26.6 で撮った物（`tools/l10n/ja-baseline-ref-1.3.txt`）。Xcode 27 では描画が変わる見込みで、強い差が増える。基準を 955fe67 にし、同じ Xcode 27 で撮る形（`ja-baseline.yml` の実行機と Xcode も替える）にしないと、コードの差と道具の差を分けられない。
9. **配布の最低版 iOS 17.0** を Xcode 27.1 で扱えるか【未確認】（M7_PLAN §4.5 の最初の手順）。`testflight.yml` には SDK と最低版を確かめる段が無い。
10. **Pencil の文**: Duo で Pencil の行や文を出すと、画面の文が変わり 9 言語の訳と逆翻訳が要る（§1.3）。「機能を混ぜない」と合わない。
11. 写真の時間: Duo の内側・外側を足すと写真のジョブが長くなる。外側の画面を `simctl` で撮れるか、開閉をシミュレータで試せるかは【未確認】（M7_PLAN §6.2）。
12. XcodeGen を版を決めずに brew で入れている。Xcode 27 の project の形に追いつかない版だと生成が落ちる【未確認】。

---

## 7. 確かめていないこと（まとめ）

- Duo の画面の pt、安全域、ステータスバーの位置、開閉で `screen` が替わるか、`UIScreen.main` が何を返すか。
- 縦横とも regular の iPhone で `.sheet` と `presentationDetents` がどう出るか。
- iPhone に「設定 › Apple Pencil」と Scribble があるか。
- Xcode 27.1 で iOS 17.0 を最低版にできるか。Swift 5 の言語モードが使えるか（この Mac の Swift 6.4.2 の typecheck は通った）。
- Xcode 27.1 で iOS 27.2 のシミュレータを使えるか。
- 古い木（a21e469・43fe366・955fe67）が Xcode 27 でビルドできるか。
- `iPhone 18 Pro Max` などの写真が 6.9 インチの寸法に入るか。Connect の Duo の写真の種類の名前。
- 中国の 2027 年が python-holidays に入る時期（M7C.md は「次の正式版、12/1 ごろ」と書く）。
