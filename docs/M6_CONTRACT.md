# M6 実装契約（手書きの書き出し・App Store の審査資料・1.0 の提出準備）

この文書は M6 の各担当が同時に作業するための **約束事**（公開 API・数字・文言・ファイル所有）です。[M5_CONTRACT.md](M5_CONTRACT.md) の続きで、M2〜M5 で決めたことはそのまま生きています（ここに書いていない API は変えません）。設計の根拠は [DESIGN.md](DESIGN.md)（§2.8 設定、§3.9 保存形式、§7.4 閲覧専用、§9 段階計画、§10 審査）と [M5.md](M5.md)（§2.3 サンドボックス試験、M5-27）。行番号は iOS リポジトリ main（0.6.0、f880fa3）と Web リポジトリ main（1.0.6、a2ba79a）のものです。**第 2 版**（2026-10-17。第 1 版に偵察報告の (a)〜(f) と「決めどころ 1〜8」を反映し（決着は §0.1）、第 2 版で 3 視点のレビュー（codebase・export-assets・owner-legal）の指摘を反映。採った指摘と採らなかった指摘の理由は §9.1）。

**本人の決定（確定。再検討しない）**: App Store 公開の前に手書きの **書き出し** を入れる（規約第 8 条 2 項・第 3 条 4 項の約束。M5-27）／サブスクリプションと閲覧専用モードは M5 の実装のまま／日本中心・EU 除外／販売者名は戸籍上の氏名 **池田 雅高**／連絡先 `syfan0@gmail.com`／日本語のみ／ファミリー共有なし／**最終の提出ボタンと実機の試験は本人**、App Store Connect への入力はリード（Claude）が本人の Chrome で行う。

**リードの決定（この契約の既定。根拠があれば直し、理由を書く）**:

- **D1 書き出しは 2 種類、どちらも閲覧専用でも iPhone でも使える**（`GatedAction.export` は既に「許す」側。`Views/CalendarRootScreen.swift:24-40`）。(a) **データファイル**: この端末に保存されている手書きの **全ページ**（月・週・日・年）を 1 つの `.json` に。形式は **アプリ独自の `tegaki-app-export` v1**（§1.1）。Web 版の形式（`tegaki-web-export`）を**採らない理由**: 非可逆（点ごとの sizeW/sizeH・opacity・azimuth・altitude・dtMs、`dev`、`cell` が落ち、アプリの月・年の行は予定で伸びるので Web 固定格子に戻すと **別のマスに落ちる**。`TegakiKit/Sources/InkModel/WebImport.swift:337-342, 434-468`）。ページは `InkPage.jsonValue`（`InkPage.swift:245-260`）そのもの = 端末の保存形式（DESIGN §3.9）なので無損失。取り込み口（設定 › データ › 「Web 版の手書きを取り込む」）を **2 形式対応** にし（§1.2）、同じファイルを **復元** として取り込める（冪等: `InkPage.merge`、`SyncEngine.importPages` `Sync/SyncEngine.swift:312-342`。アプリ形式の取り込みは **ページ単位に切り分けて 1 枚ずつ解析**し、JSON の木を一度に持たない（第 2 版。大きなファイルで落ちない）。完成文は「手書きを取り込みました（N ページ・M 本）」）。ファイル名 **「てがきカレンダー 手書き YYYY-MM-DD.json」**、**整形（読める）JSON**（§1.3）。(b) **PDF**: いま表示しているページ（種類と日付）を **1 ページ**の PDF に。紙・予定・祝日・手書きは画面と同じ描画経路（`Paper/*` の `PaperRenderer`、`InkSnapshot`）。紙と予定はベクタ、手書きだけ 2x のラスタ（PencilKit にベクタ出力は無い）。見出し（曜日・日付・月名・終日帯）は紙の外の SwiftUI なので PDF では X が描く（§1.4）。ファイル名 **「てがきカレンダー 2026年10月 月.pdf」** の形。範囲（この年の 12 か月）は **入れない**（M6-1）。配布は共有シート（§2.4）。
- **D2 UI**: 設定 › データ に行 **「手書きを書き出す」**（M5 で外した「準備中」の行の場所。閲覧専用でも青いまま押せる）→ 小さなシート `ExportSheet` に 2 つの操作 **「データファイル（JSON、すべてのページ）」** と **「このページを PDF」**、各 1 行の説明、作成中の進行、完成したら共有。失敗はシートに赤字、閉じた後にトースト（エラー 6 秒）。紙の上の「…」入口は **作らない**（入口は 1 つ）。文言は §3.6 に固定（新しい文言は「この iPad」ではなく **「この端末」**。iPhone でも出る。既存の行名「この iPad の手書きを全て消す」は不変）。写真モード `--screenshot-sheet export`（13 インチ）。
- **D3 App Store の掲載写真は CI が作る**（この Mac に Xcode は無い）。Apple の現行仕様（2026-10-17 取得、第 2 版で現物を再確認。§4.1）: 「必須の表示サイズ」節は **iPhone Dynamic Island（中）（1206×2622 か 1179×2556）** と **iPad 13 インチ（2064×2752 か 2048×2732）** が各 1 枚以上。ただし同じページの「iPhone Face ID（大）」行には今も「Dynamic Island（大）の写真が無ければ必須」と書かれていて **ページ内で矛盾**している。Connect の 1.0 の画面が 6.9 インチ枠を必須扱いにしたとき CI をやり直さずに済むよう、**6.9 インチ（`iPhone 17 Pro Max`、1320×2868）も CI で撮る**（≈ 2 分。M6-2 を改訂）。上げるかは Connect の表示で決める（§6.1 の 4）。既存の **iPhone 17（1206×2622）** と **iPad Pro 13-inch (M5)（2064×2752）** で必須は満たす。CI の成果物 `screenshots` に `store/<機種>/NN-<name>.jpg`（アルファ無しの JPEG。枠なしの素の写真で可）を 13 インチ 6 枚・iPhone 5 枚・6.9 インチ 5 枚・11 インチ 4 枚（任意）置く（§4.2）。文言（サブタイトル・プロモーション・キーワード・審査メモ・説明の追記）は §4.3 に全文。
- **D4 App Store Connect のメタデータ**はリードが §6.1 の値をそのまま打つ: 主カテゴリ **仕事効率化**、副 **ライフスタイル**、年齢区分の質問票は全部「なし／いいえ」→ **4+**、App のプライバシー **「データを収集しない」**（PRIVACY 付録 B・DESIGN §10 の根拠）、App Review の連絡先（**電話番号は本人項目**。`+81` の国際形式）、デモアカウント不要、1.0 の版に TestFlight のビルドを選び、2 つのサブスクリプションを **「審査用に追加」**、輸出コンプライアンスは `ITSAppUsesNonExemptEncryption=false`（`project.yml:70`）で質問なし。**「審査へ提出」は本人**（M5.md §2.3 のサンドボックス試験の後）。
- **D5 版**: `MARKETING_VERSION` **1.0**（`project.yml:20`。Connect の版も 1.0。ビルド番号は testflight.yml の run 番号のまま `.github/workflows/testflight.yml:185`）。TestFlight のビルドは **main に merge した後** に 1 回。この契約は `docs/M6_CONTRACT.md`、実装結果は `docs/M6.md`。
- **D6 規約類の追従**: L が TERMS 第 3 条 4 項（順次提供 → 提供中）・第 5 条 5 項（閲覧専用でも書き出せる）・第 8 条 2 項（手段を用意済み）・第 9 条 5 項・要約、SUPPORT の既知の制限の行を外し FAQ「手書きを書き出すには？」を足す、PRIVACY §4 に共有シートの 1 文（§5.1。D6 の既定「変えない」からの小さな変更。理由: 手書きが端末の外へ出る経路は iCloud 以外にこれが初めてなので、5.1.1 の質問を先回りする）。W は Web リポジトリの `m6-legal` で `app/{terms,support,privacy}.html` を作り直す（commit だけ。merge はリードがビルドの出た後に。§5.2）。DESIGN §2.8・§7.4・§9・§10 と README は C。
- **D7 テスト**: 純粋な部分（文書の組み立て・整形・解析・ファイル名）は K が TegakiKit に置き KitChecks の節と XCTest を付ける。X は `ExportBuilder` の XCTest（JSON を取り込み口に通す往復、PDF が 1 ページで期待の大きさ、**大きなファイル**（≈ 25 MB）を書き出して取り込み口に通しても常駐メモリの増分がファイルの 8 倍未満）。U は `ScreenshotMode.Sheet.export`・設定の行・`ExportSheet` の純関数・取り込みの完成文の出し分け。C は CI の写真（export シート）と `store/` の成果物の確認。

**範囲外**（触らない）: 設定の同期、英語化、Mac の UI、CI の StoreKitTest 環境の修復（M5.md §3 のまま）、提出そのもの（本人）、画像（PNG）での書き出し、年間 12 か月の PDF、`Sync/*`（`store` を読むだけ。`SyncEngine` に手を入れない）、`Ink/*`（`InkSnapshot.image` を呼ぶだけ）、レイアウトエンジン、ズーム、Web 版のアプリ本体（`index.html` / `js/` / `sw.js`）、`PaperRenderer` のプロトコルの形（0-4）。

### 0.1 偵察の決めどころの決着

| # | 決めどころ | 決着 |
| --- | --- | --- |
| 0-1 | スキーマ: Web 形式は非可逆 | **アプリ独自 v1**（D1）。取り込み口は K の `InkImport.parse` が 1 回の JSON 解析で `format` を見て分岐（§1.2）。`WebImport.parse(_ data:)` の挙動（Web 形式以外は `notAnExport`）は **不変**（`WebImportTests.testOnlyFormatAndVersionThrow` :132 を守る） |
| 0-2 | 整形 JSON が無い（`JSONValue.swift:79-85`） | **K が `JSONValue.serialized(pretty:)` を足す**（§1.3）。Foundation の `JSONSerialization(.prettyPrinted)` は数値の書式（`3.0`）と `"key" : value` の形が自前の圧縮形と揃わないので使わない |
| 0-3 | 月 PDF にメモ欄を含めるか | **メモ欄に手書きがあるときだけ含める**（§1.4、M6-3）。無ければ一覧矩形（6 行。`ZoomPolicy.overviewSize` `Layout/ZoomPolicy.swift:61-66`）。理由: 「画面どおり」と「メモの手書きを落とさない」を両立し、空の 700 lu を付けない |
| 0-4 | `PaperRenderer.draw` の `view: PaperView` 引数 | **ダミーの `PaperView(content:)` を作って `contentScaleFactor = 2`**（`Paper/PaperView.swift:192` の init は internal）。4 ファイルのリファクタはしない（`PaperViewTests` も不変）。`view` は `contentScaleFactor` にしか使われない（`MonthPaper.swift:17`、`WeekPaper.swift:11`、`DayPaper.swift:11`、`YearPaper.swift:16`） |
| 0-5 | PDF の寸法と手書き | **zoom 1（1 lu = 1 pt）**。紙はベクタ、手書きは `InkSnapshot.image(strokes:cells:bounds:zoom:scale:)`（`Ink/InkSnapshot.swift:47`。透明地・12M 画素の上限つき）を `scale: 2` で貼る。**通常は 2x**（基準の大きさなら 4 ページとも 12M 画素以内: 月 1400×1750×4 = 9.8M）。紙が伸びたとき（月の行は予定・手書きで最大 1200 まで `PaperSpec.monthRowMax`、年は 31 行 × 最大 400 `yearRowMax`）は `InkSnapshot` の上限で実効 scale が自動で下がる（`InkSnapshot.swift:53-55`。最低でも全体が入る。約束は「鮮明（通常 2x）」） |
| 0-6 | 写真モードの export シート（ストアが空 `SyncEngine.swift:55`） | **選択の状態（`.choose`）をそのまま出す**（2 つのボタンと説明が写る = 審査が見る UI）。`import` のように完成状態を偽装しない |
| 0-7 | ストアに残る旧 allday マス | **書き出し前に `BandMigration.migrate`**（冪等。`Ink/InkLedger.swift:176-185` と同じ）。取り込み（復元）側も同じ |
| 0-8 | 本人項目 | 電話番号（`+81`）、著作権表記（**「2026 池田 雅高」**）、§9。6.9 インチは第 2 版で **CI が撮る**（上げるかは Connect の表示。M6-2） |
| 0-9 | 見出し（曜日・日付・月名・終日帯）が紙の外（`Views/StickyHeaderView.swift`、`Views/AllDayBandView.swift`） | **X が PDF の上部に見出し帯を描く**（§1.4 の表）。無いと週・日の PDF に日付も終日予定も出ない |
| 0-10 | 共有シートの出し方（iPad は popover の anchor が要る） | **`ShareLink`**（iOS 16+。SwiftUI が anchor を解決）。完成画面に〔共有…〕ボタン（M6-7。1 タップ増えるが、ファイル名と大きさを見てから共有でき、キャンセルしてもやり直せる） |
| 0-11 | 取り込み（復元）側のメモリ（第 2 版） | 従来の `Data` 全体 → `JSONSerialization` の木 → `JSONValue` の木 → `[InkPage]` は 3 つの表現を同時に持ち、数十 MB の書き出しで数百 MB になる。**K の `InkImport` がトップレベルの `pages` 配列をページ単位のバイト範囲に切り分け、1 枚ずつ `JSONValue.parse` → `InkPage(json:)` → `BandMigration` する**（§1.2）。`SyncEngine.importPages` は `[InkPage]` のまま（`Sync/*` は範囲外）。Web 形式は従来どおり（Web の書き出しは小さく、`WebImport.parse(_ data:)` の挙動は不変） |
| 0-12 | 復元の完成文（第 2 版） | `InkImport.Outcome.isAppExport` を **使う**: アプリ形式なら「**手書きを取り込みました**（N ページ・M 本）」、Web 形式なら従来の「Web 版の手書きを取り込みました（…）」。シート題名「Web 版の手書きを取り込む」は不変（M6-4） |
| 0-13 | PDF の「現在時刻の線」（第 2 版） | 週・日の `layout.nowLine`（赤線）は **描かない**（`render` の冒頭で値型の layout を複製して `nowLine = nil`。再レイアウトではないので「画面と同一」は崩れない）。「今日」の列の色（`todayColumn` / `isToday`）は画面のまま残す（M6-23） |
| 0-14 | tmp の後始末の時機（第 2 版） | **各書き出しの最初だけ**。シートを閉じたときには消さない（AirDrop や Mail が非同期にコピーしている途中のファイルを消す恐れ。残っても tmp は OS が掃除する） |
| 0-15 | 6.9 インチの写真（第 2 版） | Apple のページが矛盾しているので **CI で撮る**（`iPhone 17 Pro Max`。`store/iphone69/01-05.jpg`、1320×2868）。Connect の 6.9 インチ枠が必須表示なら上げ、任意なら上げない（M6-2） |

## 0. 構成とファイル所有

```
TegakiKit/                                                担当 K（TegakiKit だけを触る）
  Sources/InkModel/JSONValue.swift                        変更: serialized(pretty:) / serializedData(pretty:)（§1.3）
  Sources/InkModel/AppExport.swift                        新規: AppExport（format・v・文書・ページ本文・ファイル名・解析）（§1.1、§2.1）
  Sources/InkModel/InkImport.swift                        新規: InkImport.parse / pages（2 形式の入口）＋ ページ単位の切り分け topLevelMembers / arrayElements（§1.2）
  Sources/InkModel/WebImport.swift                        変更: parse(json:) を切り出す（parse(_ data:) はそれを呼ぶ。挙動不変）（§1.2）
  Sources/KitChecks/main.swift                            変更: 「app export (M6)」の節（§7.1）
  Tests/InkModelTests/AppExportTests.swift                新規（§7.2）
  Tests/InkModelTests/InkImportTests.swift                新規（§7.2）
Sources/TegakiCalendar/
  Export/ExportBuilder.swift                              担当 X   新規: ExportKind / ExportResult / ExportError / ExportBuilder（§2.2）
  Export/PDFPageRenderer.swift                            担当 X   新規: 紙＋見出し＋手書き → PDF の Data（§2.3）
  Views/SettingsScreen.swift                              担当 U   変更: データ欄の行「手書きを書き出す」、脚注 exportFooter（internal）、readOnlyFooter の文言（private のまま）、新引数 onExport（§3.1）
  Views/ExportSheet.swift                                 担当 U   新規: ExportPhase / ExportSheet（§3.2）
  Views/WebImportSheet.swift                              担当 U   変更: notAnExportText の文言、WebImportPhase.done に isAppExport、resultText(_:isAppExport:)（§1.2、§3.6）
  Views/CalendarRootScreen.swift                          担当 U   変更: exportPhase、.sheet、openExport / runExport、runImport の 2 形式化、importFailureText を internal に、sheetIsUp、showScreenshotSheet(.export)（§3.3）
  Support/ScreenshotMode.swift                            担当 U   変更: Sheet.export（8 つ目）（§3.5）
Tests/TegakiCalendarTests/ExportBuilderTests.swift        担当 X   新規（§7.2）
Tests/TegakiCalendarTests/ExportSheetTests.swift          担当 U   新規（§7.2）
Tests/TegakiCalendarTests/{ScreenshotModeTests,SettingsScreenTests,CalendarRootScreenTests}.swift   担当 U   変更（§7.2）
Tests/TegakiCalendarTests/WebImportSheetTests.swift       担当 U   新規: 完成文の出し分け（§7.2。第 2 版）
docs/TERMS.md / docs/SUPPORT.md / docs/PRIVACY.md         担当 L（§5.1。この 3 つだけ）
Web リポジトリ（/Users/ikedamasataka/Documents/Codex/tegaki-calendar、ブランチ m6-legal）   担当 W（§5.2）
  app/terms.html / app/support.html / app/privacy.html    変更（L の Markdown を写す）
  tests/app-pages.test.mjs                                変更: 検査 (3)(5) に語を足し、(8) を追加
project.yml / .github/workflows/build.yml / docs/M6.md / README.md / docs/DESIGN.md の注記   担当 C（§7.3〜§7.5、§8）
```

依存の向き: `TegakiCalendar` → `TegakiKit`。`Export/*` → `InkModel`・`Layout`・`Paper/*`（描画）・`Ink/InkSnapshot`・`Persistence/InkPageStore`。`Views/*` → `Export/*`。接点は次の 7 つだけで、全部この契約の形に固定します。**共有する型と純関数は K に置き、U の新しい引数には既定値を付ける。X の最初の版は K と既存の app コードにしか依存しない（U の `ExportSheet` を参照しない）。**

1. `AppExport` / `InkImport`（§1.1〜§1.3、§2.1、K）: X が書き、U の取り込み口が読む。
2. `JSONValue.serialized(pretty:)`（§1.3、K）: `AppExport` が使う。
3. `ExportBuilder` / `ExportResult` / `ExportError`（§2.2、X）: U が `CalendarRootScreen` から呼ぶ唯一の口。
4. `PDFPageRenderer.render(_:page:title:)`（§2.3、X）: `ExportBuilder.exportPDF` が呼ぶ（U は直接呼ばない）。
5. `SettingsScreen` の新しい引数 `onExport: () -> Void = {}`（§3.1、U）。
6. `ExportSheet(phase:pageTitle:pageKind:onChoose:onClose:)`（§3.2、U）。
7. `ScreenshotMode.Sheet.export`（§3.5、U）と build.yml の写真 1 枚＋`store/`（§4.2、C）。

**担当 K は `TegakiKit/` だけ。担当 X は `Sources/TegakiCalendar/Export/*` と `Tests/TegakiCalendarTests/ExportBuilderTests.swift` だけ（`Paper/*`・`Ink/*`・`Views/*` を触らない。描画は既存の internal API を呼ぶ）。担当 U は `Views/*` の 4 ファイル・`Support/ScreenshotMode.swift`・自分のテスト。担当 L は `docs/{TERMS,SUPPORT,PRIVACY}.md` だけ。担当 W は Web リポジトリだけ（ブランチ `m6-legal`。main に push しない）。担当 C は project.yml・build.yml・docs/M6.md・README.md・DESIGN.md の注記だけ。**

## 1. 書き出しの形式

### 1.1 データファイル `tegaki-app-export` v1（K: `InkModel/AppExport.swift`）

```json
{
  "format": "tegaki-app-export",
  "v": 1,
  "exportedAt": "2026-10-17T21:03:00+09:00",
  "app": "ios/1.0 (12)",
  "pages": [
    {
      "deleted": { "3f0c…": 1760000009000 },
      "pageId": "m1-2026-10",
      "strokes": {
        "demo-stroke-wave": {
          "cell": "2026-10-14",
          "color": "#1f2937",
          "dev": "ipad-…",
          "id": "demo-stroke-wave",
          "pts": [24, 150, 0, 3.5, 3.5, 1, 0.5, 0, 1.4, 28.2, 154.3, 12, 3.5, 3.5, 1, 0.56, 0, 1.4],
          "t": 1760000000000,
          "tool": "pen"
        }
      },
      "updatedAt": 1760000000000,
      "v": 1
    }
  ]
}
```

| 項目 | 型 | 規則 |
| --- | --- | --- |
| `format` | String | 必ず `"tegaki-app-export"`。違えば取り込み口は Web 形式を試し、どちらでもなければ `notAnExport` |
| `v` | Int | 1。2 以上は `unsupportedVersion(v)`（Web 形式と同じ扱い） |
| `exportedAt` | String | ISO 8601、**端末のローカル時刻＋オフセット**、秒まで（`ISO8601DateFormatter`、`.withInternetDateTime`、`timeZone` = 端末）。表示用 |
| `app` | String | `"ios/<CFBundleShortVersionString> (<CFBundleVersion>)"`（`SettingsScreen.versionText` と同じ出所）。表示用 |
| `pages` | [Object] | 各要素は **`InkPage.jsonValue` そのもの**（`InkPage.swift:245-260`: `v`・`pageId`・`strokes`（id → 線。墓標済みは書かない）・`deleted`（id → ms）・`updatedAt`・未知の鍵の書き戻し。`unknownStrokes` も `strokes` に戻る）。`BandMigration.migrate` を通した後の形（0-7）。**順序 = `pageId` の昇順**（`InkPageStore.allPageIds()` `Persistence/InkPageStore.swift:43-56` の順）。**`liveStrokeCount == 0` かつ `deleted.isEmpty` かつ `unknownStrokes.isEmpty` のページは入れない**（空ページ）。それ以外は全部（墓標だけのページも入れる: 復元で「消した線」を消したままにするため） |
| `pages[].strokes[id]` | Object | `{ id, cell, tool("pen"\|"marker"), color "#rrggbb", t, dev?, pts: [9 数 × 点] }`（`InkStroke.jsonValue` `InkStroke.swift:161-172`。点は x, y, dtMs, sizeW, sizeH, opacity, force, azimuth, altitude。`InkModelTests.swift:83, 157` が形を固定） |

往復の規則（**X のテストが固定する**。§7.2）: 書き出した `pages[i]` を `InkPage(json:)` で読むと **元のページと `==`**（`WebImportTests.testImportedPageSurvivesTheCodec` :494 と同じ理屈。`InkPageCodec.encode` と同じ JSONValue を整形して書くだけなので、tool・color・points（0.1 / 0.01 / 0.001 丸めは保存時に済んでいる）・cell・dev・t・墓標・未知の鍵が全部戻る）。取り込み口に通すと `SyncEngine.importPages` が `InkPage.merge(local, page)` で合流し `contentDiffers` のときだけ保存する（`SyncEngine.swift:321-330`）ので、**同じファイルを二度取り込んでも二重にならず**（`merge(a, a) == a`）、**書き出した後にアプリで消した線は、取り込み直しても戻らない**（墓標が勝つ。全部を元に戻すときは 設定 › データ › 「この iPad の手書きを全て消す」（`SyncEngine.eraseEverything` → `store.removeAll()` `Sync/SyncEngine.swift:282-287`。墓標を残さない）の後に取り込む。この帰結は SUPPORT の新 FAQ に書く。§5.1）。

`dev` について（第 2 版）: 各線の `dev` は書いた端末の印（`identifierForVendor`。`Ink/InkLedger.swift:161-162`。アプリ用のランダムな識別子で、端末名やシリアル番号ではない）。書き出しでも **落とさない**。理由: (1) 往復の規則「`InkPage(json:)` で読むと元と `==`」が成り立たなくなる、(2) 同じ id の線が食い違ったときの決定的な選び方 `InkPage.compareStrokes`（`InkPage.swift:206-213`）が `dev` を比較に使うので、落とすと復元後に他の端末と選び方がずれる。共有先に端末の印が渡ることは PRIVACY §4 の新しい 1 文で伝える（§5.1、M6-16）。

```swift
// TegakiKit/Sources/InkModel/AppExport.swift（K）
public enum AppExport {
    public static let format = "tegaki-app-export"
    public static let supportedVersion = 1
    /// 書き出しの文書（解析結果でもある）。pages は BandMigration 済み・空ページ無し・pageId 順
    public struct Document: Equatable, Sendable {
        public var exportedAt: String
        public var app: String
        public var pages: [InkPage]
        public init(exportedAt: String, app: String, pages: [InkPage])
    }
    /// 「2026-10-17T21:03:00+09:00」
    public static func exportedAtText(_ date: Date, timeZone: TimeZone) -> String
    /// 書き出す価値のあるページか（liveStrokeCount > 0 || !deleted.isEmpty || !unknownStrokes.isEmpty）
    public static func isWorthExporting(_ page: InkPage) -> Bool
    /// 文書全体（小さな文書とテスト用。X は下の 3 つで流し書きする）
    public static func jsonValue(_ document: Document) -> JSONValue
    public static func encode(_ document: Document) -> Data                 // jsonValue(...).serializedData(pretty: true) + "\n"
    /// 流し書き（§2.2）: header + pageText を "," で区切って並べる + footer = encode(...) と同じバイト列
    public static func header(exportedAt: String, app: String) -> String   // "{\n  \"app\": …,\n  \"exportedAt\": …,\n  \"format\": …,\n  \"pages\": [\n"
    public static func pageText(_ page: InkPage) -> String                 // ページ 1 枚を 4 スペース字下げで整形したもの（末尾に改行なし）
    public static let pageSeparator = ",\n"
    public static let footer = "\n  ],\n  \"v\": 1\n}\n"
    /// 解析（§1.2 の入口から呼ばれる）。format が違えば notAnExport、v > 1 は unsupportedVersion。ページは InkPage(json:) で寛容に読み、
    /// pageId が空か 256 字超のページは捨てる（捨てた数は InkImport が数える）。BandMigration.migrate を通す
    public static func parse(json: JSONValue) throws -> Document            // throws WebImport.ParseError
    /// ファイル名（§1.5）
    public static func jsonFileName(exportedAt: Date, calendar: Calendar) -> String        // 「てがきカレンダー 手書き 2026-10-17.json」
    public static func pdfFileName(kind: PageKind, focus: DayKey) -> String                // 「てがきカレンダー 2026年10月 月.pdf」
    public static func kindLabel(_ kind: PageKind) -> String                                // 月 "月" / 週 "週" / 日 "日" / 年 "年"
    public static func safeFileName(_ name: String) -> String                               // "/" ":" "\\" を "-" に。他はそのまま
}
```

`header` の鍵の順は `jsonValue` の整形出力と同じ（ソート順: `app`, `exportedAt`, `format`, `pages`, `v`）。`encode(document)` と `header + pages.map(pageText).joined(separator: pageSeparator) + footer` が **バイト単位で等しい** ことを K のテストが固定する（X の流し書きが文書と同じ形になる根拠）。

### 1.2 取り込み口の 2 形式化（K: `InkModel/InkImport.swift`、`WebImport.swift`。U: `CalendarRootScreen.runImport`、`WebImportSheet.notAnExportText`）

```swift
// TegakiKit/Sources/InkModel/InkImport.swift（K）
public enum InkImport {
    public enum Parsed: Equatable, Sendable {
        case web(WebImport.Document)
        case app(AppExport.Document)
    }
    /// 入口（第 2 版: アプリ形式は JSON の木を一度に持たない）。手順:
    /// 1. members = topLevelMembers(data)。nil（object でない・壊れている）→ 従来の道: JSONValue.parse(data) が失敗なら invalidJSON、
    ///    object でない・format が無いなら notAnExport（挙動は第 1 版と同じ）
    /// 2. members["format"] のバイト範囲だけを JSONValue.parse（JSONSerialization は .fragmentsAllowed。`JSONValue.swift:57`）
    ///    - "tegaki-web-export" → JSONValue.parse(data) 全体 → WebImport.parse(json:)（従来どおり。Web の書き出しは小さい）
    ///    - "tegaki-app-export" → 3 へ
    ///    - それ以外 → notAnExport
    /// 3. members["v"] を解析（無ければ 1。WebImport.versionNumber と同じ規則）。> supportedVersion → unsupportedVersion(v)
    /// 4. exportedAt / app は範囲ごとに解析（無ければ ""）。pages = arrayElements(data, in: members["pages"])（無ければ []。配列でなければ notAnExport）
    /// 5. 各要素を autoreleasepool の中で JSONValue.parse（失敗 → invalidJSON）→ AppExport.parsePage(_:)（nil なら捨てる）→ 追加
    /// 6. .app(AppExport.Document(exportedAt:app:pages:))。skipped = 要素数 − pages.count（pages(_:) が使う）
    public static func parse(_ data: Data) throws -> Parsed                 // throws WebImport.ParseError
    /// トップレベル object の 鍵 → 値のバイト範囲。文字列リテラル（エスケープ \" と \\ を含む）と { } [ ] の深さだけを見る軽い走査。
    /// 鍵はエスケープ無しの単純な文字列だけ対応（AppExport の鍵は全部そう）。data の先頭（空白の後）が "{" でない、
    /// 閉じ括弧が合わない、鍵の後に ":" が無い、などは nil（呼び出し側が従来の道に落とす）。重複する鍵は後の方
    public static func topLevelMembers(_ data: Data) -> [String: Range<Int>]?
    /// 配列のバイト範囲 → 要素のバイト範囲（同じ走査規則。要素の前後の空白は含めない。空配列は []。配列でない・壊れていれば nil）
    public static func arrayElements(_ data: Data, in range: Range<Int>) -> [Range<Int>]?
    /// 取り込むページ: .web は WebImport.convert(doc)（pages / skipped.count / pageCount）、.app は doc.pages（skipped = parse が捨てた数、pageCount = doc.pages.count + skipped）
    public static func pages(_ parsed: Parsed) -> Outcome
    public struct Outcome: Equatable, Sendable {
        public var pages: [InkPage]
        public var skipped: Int
        public var pageCount: Int
        public var isAppExport: Bool          // U が完成文の出し分けに使う（§3.6。0-12）
    }
}
```

`AppExport`（K）に 1 枚分の解析を切り出す: **`public static func parsePage(_ json: JSONValue) -> InkPage?`**（`InkPage(json:)` で寛容に読み、`pageId` が空か 256 字超なら nil、`BandMigration.migrate` を通す）。`AppExport.parse(json:)`（文書全体。小さな文書とテスト用）はこれを各要素に呼ぶだけにし、`InkImport.parse` のページ単位の道と **同じ結果**になる（K のテスト `testStreamedParseEqualsWholeParse` が固定）。メモリ: `Data`（ファイル 1 つ分）＋ `[InkPage]`（二進表現。JSON より小さい）＋ ページ 1 枚分の `JSONValue` の木だけ。従来の「全体の木 × 2」は持たない。

`WebImport`（K、変更）: `public static func parse(json: JSONValue) throws -> Document` を切り出し、既存の `parse(_ data: Data)`（:130-156）は `JSONValue.parse` → `parse(json:)` を呼ぶだけにする。**挙動は不変**（`format` 不一致は `notAnExport`、`v > 1` は `unsupportedVersion`。`testOnlyFormatAndVersionThrow` :132 がそのまま通る）。`AppExport.parse(json:)` が捨てたページ数は `AppExport.Document` に持たせず、`InkImport.parse` が `pages` 配列の長さと `doc.pages.count` の差で数える。

U（`CalendarRootScreen.runImport` :1119-1146）: `WebImport.convert(try WebImport.parse(data))` を `InkImport.pages(try InkImport.parse(data))` に替える（`Task.detached` の中のまま）。以降（`importPhase = .importing` → `sync.importPages(outcome.pages)` → `.done(outcome, skipped:, isAppExport: outcome.isAppExport)`）。**完成文の出し分け（第 2 版、0-12）**: `WebImportPhase.done` に `isAppExport: Bool` を足し（`Views/WebImportSheet.swift:52-56`。既存の呼び出し 2 か所は `isAppExport: false` を渡す）、`WebImportSheet.resultText(_ outcome: ImportOutcome, isAppExport: Bool = false)` と `toastText(outcome:skipped:isAppExport:)` が `isAppExport == true` かつ `pagesChanged > 0` のとき **「手書きを取り込みました（N ページ・M 本）」**、それ以外は従来の文（「Web 版の手書きを取り込みました（…）」／「取り込むものはありませんでした（すべて取り込み済みです）」）。`importFailureText`（:1148）は `private static` を **`static`（internal）** にして U のテストから呼べるようにし、対応表は不変、文字列だけ `WebImportSheet.notAnExportText`（:77）を **「このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません」** に。設定の行の名前 **「Web 版の手書きを取り込む」は変えない**（W のテスト (5)、SUPPORT・README の手順が参照。復元の説明は脚注と FAQ で行う。M6-4）。取り込みは M5-15 のまま **閲覧専用では止める**（復元は購読中に行う。規約第 5 条 5 項の「できないこと」に「Web 版からの取り込み」があるのはそのまま。SUPPORT の FAQ にそう書く）。

### 1.3 整形 JSON（K: `InkModel/JSONValue.swift`）

```swift
extension JSONValue {
    /// pretty = false は従来どおり（鍵ソート・圧縮。バイト列は不変）。pretty = true:
    /// - object: "{\n" + 各鍵を 1 行（indent + 2 スペース）"\"key\": value"、鍵はソート、要素の間は ",\n"、"\n" + indent + "}"。空は "{}"
    /// - array: 要素が全部 .number（または空）なら 1 行 "[1, 2, 3]"（区切り ", "）。それ以外は object と同じく 1 要素 1 行。空は "[]"
    /// - 数値の書式は format(_:) のまま（"3"、"0.1"、非有限は null）
    public func serialized(pretty: Bool = false, indent: Int = 0) -> String
    public func serializedData(pretty: Bool = false) -> Data
}
```

理由: `pts` は 9 × 点数の数値配列なので、1 要素 1 行にすると 1 本の線が 300 行になり「読める」の逆になる。数値だけの配列を 1 行にすれば、線 1 本 = 7 行（id・cell・tool・color・t・dev・pts）。`InkPageCodec.encode`（`InkPageCodec.swift:14-17`）と `serializedData()` の既定（pretty = false）は **一切変えない**（端末のファイルと iCloud のバイト列が変わらない）。

### 1.4 PDF（X: `Export/PDFPageRenderer.swift`）

| 項目 | 値 |
| --- | --- |
| 対象 | いま表示しているページ 1 枚: `CalendarRootScreen` の `paper: PaperContent`（:110）と `page: InkPage`（:108）をそのまま渡す（再レイアウトしない。画面と同一） |
| 単位 | **zoom 1 = 1 lu = 1 pt**。文字は `PaperText.fontSize(_, zoom: 1, readable:)` で設計サイズ（月の日付 17 pt、`PaperText.swift:15-26`）。罫線 `hairline(1)` = 1 pt |
| 紙の矩形 `paperRect` | 月: メモ欄に手書きがあれば（`page.liveStrokes.contains { $0.cell.isMemo }`）`CGRect(origin: .zero, size: layout.size)`（6 行＋メモ）、無ければ `CGRect(origin: .zero, size: ZoomPolicy.overviewSize(layout))`（1400 × `memo.minY`）。週・日・年: `layout.size`（1400×1920 / 1000×2400 / 1400×(31 行 × ≥60)） |
| 見出し帯 `headingHeight`（紙の上） | 題名行 36 pt（`PageNavigation.title(kind, focus:)`（`Layout/PageNavigation.swift:68`）を 20 pt semibold、左 16 pt、`PaperPalette.ink1`）＋ ページ別の行: 月 = 曜日行 28 pt（`月 火 水 木 金 土 日` を各列の中央に 14 pt、土は `PaperPalette.blue`、日は `red`。列幅 200）／ 週 = 日付行 40 pt（`layout.dateLabels` の 7 列: 曜日 1 字＋日（1 日なら「M/1」）14 pt、祝日名があれば 10 pt を下に。色は `PaperPalette.toneColor(label.tone)`。列 x = `band.columnMinX[i]`、幅 `band.columnWidth`）＋ 終日帯（`paper.allDayBand!.laneCount` × **`laneStep(.week)` = 25 pt**（`PaperSpec.allDayLaneStep`）＋ 6 pt。0 レーンなら 0）／ 日 = 日付行 40 pt（題名に日付が入っているので「終日」ラベルだけ）＋ 終日帯（`laneCount` × **`laneStep(.day)` = 24 pt**（`PaperSpec.dayLaneStep` = 22 + 2。`Layout/PaperSpec.swift:64-66`、DESIGN §2.2「24」）＋ 6 pt）／ 年 = 月名行 28 pt（`1月`…`12月` を 12 列の中央に 14 pt。列 x = 56 + i × 112） |
| 終日帯の描き方 | `AllDayBandLayout`（`Layout/AllDayBand.swift:47-67`）の `bars` を角丸 4 pt の矩形（`colorHex`、**x = `bar.minX` … `bar.maxX`**（`AllDayBandBar` が持つ画面と同じ値。`AllDayBand.swift:24-28`。週は `weekBarInset` 3 の内側、`continuesLeft/Right` の側は 0。再計算しない）、`continuesLeft/Right` なら端を角丸にしない）、y = `lane × laneStep(kind)`、高さ `PaperSpec.allDayLane` 22、文字は `PaperPalette.readableText(on:)` 12 pt、左右 6 pt。左の `gutter` に「終日」11 pt `ink3`。`columnMinX` は日付行の列位置にだけ使う |
| 現在時刻の線（第 2 版、0-13） | **描かない**。`render` の冒頭で `stripNowLine(paper)`: 週・日なら値型の layout を複製して `nowLine = nil` にした `PaperContent` を作り、それを `WeekPaper/DayPaper.draw` に渡す（月・年は `nowLine` が常に nil なので何もしない）。「今日」の列・日の色（`todayColumn` / `isToday`）は画面のまま（M6-23）。紙の資料に「いまの時刻の赤線」が焼き付くと後日誤解を招く |
| ページの大きさ | `CGSize(width: paperRect.width, height: headingHeight + paperRect.height)` pt。余白なし。向き = 縦長（月 1400×1114 等。印刷は閲覧アプリが用紙に合わせる） |
| 描画の順 | `UIGraphicsPDFRenderer(bounds:format:)`（`format.documentInfo` = `[kCGPDFContextTitle: title, kCGPDFContextCreator: "てがきカレンダー"]`）→ `beginPage()` → 全面を `PaperPalette.paper`（`#fffdf8`）で塗る → 見出し帯（UIKit の `NSAttributedString.draw(in:)`）→ `ctx.translateBy(x: 0, y: headingHeight)` → `ctx.clip(to: paperRect)` → 紙: `MonthPaper.draw(_, in: ctx, dirty: paperRect, zoom: 1, view: dummy)`（週・日・年も同じ。`dummy = PaperView(content: paper)`、`dummy.contentScaleFactor = 2`。0-4）→ 手書き: `InkSnapshot.image(strokes: page.liveStrokes, cells: paper.layout.cells, bounds: paperRect, zoom: 1, scale: 2)` が non-nil なら `image.draw(in: paperRect)`（手書きが無ければ何も貼らない） |
| 外観 | `InkSnapshot.image` が light 外観で描く（`InkSnapshot.swift:76-82`）。紙の色は固定（DESIGN §3.2） |
| ベクタ／ラスタ | 紙・予定・見出しはベクタ（文字は埋め込みフォント）。手書きだけラスタ（PNG として埋め込まれる。`UIImage.draw` が PDF 文脈では画像 XObject になる）。**通常は 2x**。紙が伸びて 12M 画素を超えるときは `InkSnapshot` の上限で実効 scale が自動で下がる（0-5。最低でも全体が入る） |

```swift
// Sources/TegakiCalendar/Export/PDFPageRenderer.swift（X）
@MainActor
enum PDFPageRenderer {
    static let inkScale: CGFloat = 2
    static let titleHeight: CGFloat = 36
    static let labelRowHeight: CGFloat = 28      // 月の曜日行・年の月名行
    static let dateRowHeight: CGFloat = 40       // 週・日の日付行
    /// 終日帯のレーン間隔: .week → PaperSpec.allDayLaneStep（25）、.day → PaperSpec.dayLaneStep（24）。他は 0（第 2 版）
    static func laneStep(_ kind: PageKind) -> CGFloat
    static let bandPad: CGFloat = 6
    static let creator = "てがきカレンダー"
    static func paperRect(_ paper: PaperContent, page: InkPage) -> CGRect
    static func headingHeight(_ paper: PaperContent) -> CGFloat
    static func pageSize(_ paper: PaperContent, page: InkPage) -> CGSize
    /// 週・日の layout を複製して nowLine = nil にしたもの（月・年はそのまま）。純関数（第 2 版、0-13）
    static func stripNowLine(_ paper: PaperContent) -> PaperContent
    /// 1 ページの PDF。空の Data なら ExportError.renderFailed（ExportBuilder が投げる）。中で stripNowLine を通す
    static func render(_ paper: PaperContent, page: InkPage, title: String) -> Data
}
```

### 1.5 ファイル名・置き場所・後始末

| 項目 | 値 |
| --- | --- |
| JSON | **`てがきカレンダー 手書き 2026-10-17.json`**（`AppExport.jsonFileName(exportedAt:calendar:)`。日付は端末のカレンダー（`DayKey.deviceCalendar`）のその日） |
| PDF | **`てがきカレンダー <PageNavigation.title> <kindLabel>.pdf`**: 月 `てがきカレンダー 2026年10月 月.pdf`、週 `てがきカレンダー 2026年10月5日〜10月11日 週.pdf`（年またぎは title のまま `2026年12月28日〜2027年1月3日`）、日 `てがきカレンダー 2026年10月7日(水) 日.pdf`（祝日は title のまま `2026年11月3日(火) 文化の日 日.pdf`）、年 `てがきカレンダー 2026年 年.pdf`。`safeFileName` で `/` `:` `\` を `-` に（title には出ないが保険） |
| 置き場所 | `FileManager.default.temporaryDirectory.appendingPathComponent("TegakiCalendarExport", isDirectory: true)`（`ExportBuilder.defaultDirectory()`）。Documents には置かない（Files アプリに「このアプリ内」の項目を作らない。`UISupportsDocumentBrowser: false` のまま） |
| 後始末 | `ExportBuilder.cleanUp()` が **そのフォルダの中身を全部消す**。呼ぶ時機は **各書き出しの最初だけ**（前回の残り物を消す。第 2 版、0-14）。シートを閉じたときには **消さない**: iPad の共有ポップオーバーを AirDrop の転送中に外タップで閉じてから「閉じる」を押すと、`sharingd` や Mail が非同期に読んでいる途中のファイルを消す恐れがある（`ShareLink` に完了通知は無い）。残っても tmp は OS が掃除する（1 ファイル ≤ 数十 MB） |
| 書き込み | JSON: `FileManager.createFile` → `FileHandle(forWritingTo:)` に流し書き（§2.2）→ `close()`。途中で失敗したら部分ファイルを消して `writeFailed`。PDF: `Data.write(to:options: .atomic)` |

## 2. 書き出しの実装

### 2.1 K の純粋部分（`AppExport` / `InkImport` / `JSONValue`。§1.1〜§1.3 の宣言どおり）

Foundation と Layout（`PageKind` / `DayKey` / `PageNavigation.title`）だけに依存。`Calendar` は引数で受ける（`DayKey.deviceCalendar` は呼び出し側）。時計を持たない。`exportedAtText` は `ISO8601DateFormatter`（`formatOptions = [.withInternetDateTime]`、`timeZone` を引数で）。`pdfFileName` は `PageNavigation.title(kind, focus:)` を呼ぶ（`Layout` は `Holidays` に依存済みなので祝日名も入る）。

### 2.2 ExportBuilder（X: `Export/ExportBuilder.swift`）

```swift
enum ExportKind: String, Equatable, Sendable { case json, pdf }

struct ExportResult: Equatable, Sendable {
    var kind: ExportKind
    var url: URL                 // 書いたファイル（§1.5 のフォルダ）
    var fileName: String         // url.lastPathComponent
    var byteCount: Int           // 書いたバイト数
    var pageCount: Int           // JSON: 書いたページ数。PDF: 1
}

enum ExportError: Error, Equatable {
    case nothingToExport         // JSON: isWorthExporting なページが 0
    case writeFailed(String)     // ファイル作成・書き込み・close の失敗（localizedDescription）
    case renderFailed            // PDF: render が空の Data を返した
    case cancelled               // Task がキャンセルされた（シートが閉じられた）
}

@MainActor
final class ExportBuilder {
    /// store = SyncEngine.shared.store（`Sync/SyncEngine.swift:70`。実物のディレクトリ。テストは temporaryDirectory の InkPageStore）
    init(store: InkPageStore,
         directory: URL = ExportBuilder.defaultDirectory(),
         now: @escaping () -> Date = Date.init,
         appText: String = ExportBuilder.appText,
         calendar: Calendar = DayKey.deviceCalendar,
         timeZone: TimeZone = .current)
    static func defaultDirectory() -> URL                      // tmp/TegakiCalendarExport
    /// "ios/1.0 (12)"（Bundle.main の CFBundleShortVersionString / CFBundleVersion。無ければ "ios/—"）
    static var appText: String { get }
    /// directory の中身を全部消す（directory 自体は残す。無ければ何もしない）。失敗は無視
    func cleanUp()
    /// すべてのページ（§1.1）。手順: cleanUp → ids = store.allPageIds() → ファイル作成・header → 各 id: load → BandMigration.migrate →
    /// isWorthExporting なら pageText を追記（2 枚目以降は pageSeparator を先に）→ progress(done, total) → Task.checkCancellation →
    /// footer → close。1 枚も書かなければファイルを消して nothingToExport。ページの読み・移行・整形は Task.detached(priority: .userInitiated)
    /// の中。**detached に入る前に `let store = self.store`, `let directory = self.directory`, `let appText = self.appText`,
    /// `let exportedAt = …` と値を取り出して渡す**（`InkPageStore` / `InkPage` は Sendable。detached の中から `self` の
    /// プロパティに触らない: @MainActor の class なので strict concurrency で隔離違反になる。第 2 版）。progress は MainActor に戻して呼ぶ
    func exportJSON(progress: @escaping @MainActor (_ done: Int, _ total: Int) -> Void) async throws -> ExportResult
    /// いま開いているページ 1 枚（§1.4）。cleanUp → PDFPageRenderer.render → 空なら renderFailed → write(.atomic)。MainActor で同期
    /// （PKDrawing のラスタ化と PaperRenderer が MainActor。1 秒前後。呼び出し側が 1 フレーム以上待ってから呼ぶ。§3.3）
    func exportPDF(paper: PaperContent, page: InkPage, kind: PageKind, focus: DayKey) throws -> ExportResult
}
```

メモリの上限（DESIGN §3.10）: JSON は **ページ 1 枚ずつ** 読んで文字列にして書く（ファイル全体を `Data` や `JSONValue` に持たない。1 ページ ≤ 20,000 本、1 本 ≤ 20,000 点の上限は `InkPage.maxStrokes` / `InkStroke.maxPoints` が保証）。各ページの処理は `autoreleasepool` で囲む。PDF は `InkSnapshot.image` の 12M 画素の上限（`InkSnapshot.maxImagePixels` `InkSnapshot.swift:19, 53-55`）が働くので、月・年ページの行が伸びても画素は増えない（代わりに実効 scale が 2 未満に下がる。0-5）。取り込み（復元）側の上限は §1.2（ページ単位の解析）。

進行: JSON は 1 ページごと（`done / total`。total = `allPageIds().count`、空ページも数える）。PDF は 1 枚なので `.building(.pdf, done: 0, total: 1)` のまま（スピナー）。

取消: `ExportSheet` は作成中 `interactiveDismissDisabled` なので通常は起きない。アプリが背面に回っても続ける（数秒）。`Task` がキャンセルされたら `cancelled`（U はトーストを出さない）。

### 2.3 PDFPageRenderer（X）: §1.4 の表のとおり。`render` は `@MainActor`（`PaperRenderer.draw` と `PaperView` が MainActor）。

### 2.4 共有（U: `ExportSheet` の `.done`）

`ShareLink(item: result.url, preview: SharePreview(result.fileName, image: Image(systemName: result.kind == .pdf ? "doc.richtext" : "doc.text")))` を `Label("共有…", systemImage: "square.and.arrow.up")` の `.borderedProminent` で。ファイル URL なので「ファイルに保存」「AirDrop」「メール」「“ファイル”で開く」などが並ぶ。iPad では SwiftUI がボタンを anchor にした popover を出す（0-10）。`UIActivityViewController` の Representable は **作らない**（M6-7 を変えるときだけ）。

### 2.5 失敗・文言（U: `ExportSheet.failureText`）

| `ExportError` | シートの赤字（閉じた後は同じ文をトースト、`isError: true`、6 秒） |
| --- | --- |
| `.nothingToExport` | 「書き出す手書きがありません」 |
| `.writeFailed(s)` | 「ファイルを書けませんでした: \(s)」 |
| `.renderFailed` | 「PDF を作れませんでした」 |
| `.cancelled` | 何も出さない（シートを閉じるだけ） |
| その他の Error | 「書き出せませんでした: \(error.localizedDescription)」 |

## 3. 設定と画面（担当 U）

### 3.1 設定 › データ の行（`Views/SettingsScreen.swift`）

- 新引数 **`var onExport: () -> Void = {}`**（**`scrollToPurchaseOnAppear`（:36）の後 = 引数の最後**。既定値つき。M5 流儀）。
- `dataSection`（:378-399）の行の順: **「Web 版の手書きを取り込む」→「手書きを書き出す」→「この iPad の手書きを全て消す」**。「手書きを書き出す」は `Button(action: onExport) { Text("手書きを書き出す") }`、**常に `.tint`**（閲覧専用でも灰色にしない。`GatedAction.export` は許す側）。
- 脚注（`importFooter` :57 の後に 1 段落。**`static let`（internal。テストが読む）**）: **`static let exportFooter = "「手書きを書き出す」は、この端末に保存されている手書きを 1 つのデータファイル（JSON）にするか、いま開いているページを PDF にします。データファイルは「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。"`**。`webImportedText` はそのまま最後。
- `readOnlyFooter`（:556。`private static let` の**まま**）の「…この iPad の手書きを全て消す、設定の変更ができます。」を **「…この iPad の手書きを全て消す、手書きの書き出し、設定の変更ができます。」** に（規約第 5 条 5 項と同じ列挙。§5.1）。テストは既存の流儀どおり **`SettingsScreen.purchaseFooter(.readOnly(reason))`** 経由で中身を見る（`Tests/TegakiCalendarTests/SettingsScreenTests.swift:97-103` の `contains(...)` の文字列を新しい文に更新。第 2 版）。
- 写真用: `--screenshot-sheet export` は設定を経由しない（§3.5）ので設定側に新しいスクロール先は要らない。

### 3.2 ExportSheet（`Views/ExportSheet.swift`。`WebImportSheet` :68-185 と同じ流儀: 状態を持たず親が `phase` を駆動）

```swift
enum ExportPhase: Equatable {
    case choose                                            // 2 つのボタン
    case building(ExportKind, done: Int, total: Int)       // 進行（PDF は 0 / 1 でスピナー）
    case done(ExportResult)                                // チェック・ファイル名と大きさ・〔共有…〕〔閉じる〕
    case failed(String)                                    // 三角・赤字・〔閉じる〕
    var isInProgress: Bool                                 // .building だけ true
}

struct ExportSheet: View {
    var phase: ExportPhase
    var pageTitle: String                                  // PageNavigation.title(kind, focus:)。例「2026年10月」
    var pageKind: PageKind
    var onChoose: (ExportKind) -> Void
    var onClose: () -> Void

    static let title = "手書きを書き出す"
    static let jsonTitle = "データファイル（JSON、すべてのページ）"
    static let jsonNote = "この端末に保存されている手書きをすべて 1 つのファイルにまとめます。設定 › データ › 「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。"
    static let pdfTitle = "このページを PDF"
    /// 「いま開いているページ（2026年10月・月）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。」
    static func pdfNote(pageTitle: String, kind: PageKind) -> String
    /// .building(.json, 3, 12) → 「書き出しています… 3 / 12 ページ」、.building(.pdf, …) → 「PDF を作っています…」、他 → ""
    static func progressText(_ phase: ExportPhase) -> String
    static let doneTitle = "書き出しました"
    /// JSON 「てがきカレンダー 手書き 2026-10-17.json（12 ページ・1.2 MB）」／ PDF 「てがきカレンダー 2026年10月 月.pdf（1.2 MB）」
    static func doneText(_ result: ExportResult) -> String
    /// 1,024 未満 「512 B」、1 MB 未満 「512 KB」（整数）、それ以上 「1.2 MB」（小数 1 桁。1024 進）
    static func byteText(_ count: Int) -> String
    static let shareTitle = "共有…"
    static let closeTitle = "閉じる"
    static let nothingToExportText = "書き出す手書きがありません"
    static func writeFailedText(_ detail: String) -> String      // 「ファイルを書けませんでした: …」
    static let renderFailedText = "PDF を作れませんでした"
    static func failureText(_ error: Error) -> String?            // §2.5 の表。.cancelled は nil
}
```

並び（`NavigationStack` › `VStack(spacing: 20)`、題名は `.navigationBarTitleDisplayMode(.inline)`、`.presentationDetents([.medium])`、`.interactiveDismissDisabled(phase.isInProgress)`）:

| phase | 中身 |
| --- | --- |
| `.choose` | 2 つの大きなボタン（`.buttonStyle(.bordered)`、`.controlSize(.large)`、幅いっぱい、左寄せの `VStack`: 題名 `.body.weight(.semibold)` ＋ 説明 `.footnote` `.secondary`）。上 = JSON、下 = PDF（`pdfNote(pageTitle:kind:)`）。ツールバー `.cancellationAction` に「閉じる」 |
| `.building` | `ProgressView`（JSON は `.linear` に `done/total`、PDF は `.circular` `.large`）＋ `progressText` |
| `.done(r)` | `checkmark.circle.fill` 44 pt 緑 ＋ `doneTitle`（`.headline`）＋ `doneText(r)`（`.footnote` `.secondary`、中央）＋ `ShareLink`（§2.4）＋ 「閉じる」（`.bordered`） |
| `.failed(m)` | `exclamationmark.triangle.fill` 44 pt 赤 ＋ `m` ＋ 「閉じる」（`.borderedProminent`） |

### 3.3 CalendarRootScreen の接続（`Views/CalendarRootScreen.swift`）

- `@State private var exportPhase: ExportPhase?`、`private var exportSheetBinding: Binding<Bool>`（`importSheetBinding` と同じ形）、`@State private var exportTask: Task<Void, Never>?`。
- `sheetIsUp`（:297-299）に `|| exportPhase != nil`。
- `.sheet(isPresented: exportSheetBinding) { ExportSheet(phase: exportPhase ?? .choose, pageTitle: PageNavigation.title(kind, focus: focus), pageKind: kind, onChoose: runExport, onClose: closeExportSheet) }`（取り込みシートの `.sheet` :445 の直後）。
- 設定の `SettingsScreen(...)`（:415-437）に `onExport: openExport`。
- `openExport()`（`importWeb` :1087-1097 が手本）: `saveNow()`（いま開いているページの未保存分をストアに落とす。1.5 秒の遅延保存を待たない）→ `showSettings = false` → `sheetGap`（0.35 秒）後に `exportPhase = .choose`。`isAllowed(.export)` は常に true（guard は書かない）。
- `runExport(_ kind: ExportKind)`: `exportPhase = .building(kind, done: 0, total: kind == .pdf ? 1 : 0)` → `exportTask = Task { @MainActor in … }`: JSON は `try await builder.exportJSON { done, total in exportPhase = .building(.json, done: done, total: total) }`、PDF は **`try? await Task.sleep(for: .milliseconds(50))`（1 フレーム以上待って SwiftUI に `.building` のスピナーを描かせる。`Task.yield()` 1 回では描き終わる保証が無い。第 2 版）** → `try builder.exportPDF(paper: paper, page: page, kind: kind, focus: focus)`（MainActor で同期。1 秒前後）。成功 → `.done(result)`、失敗 → `ExportSheet.failureText(error)` が non-nil なら `.failed(text)`、nil（キャンセル）なら `exportPhase = nil`。`builder = ExportBuilder(store: sync.store)`（毎回作ってよい。状態を持たない）。
- `closeExportSheet()`: `.failed(text)` なら `exportPhase = nil` の後に `showToast(text, isError: true)`；`.done` / `.choose` なら `nil`。**閉じたときに `cleanUp()` は呼ばない**（§1.5、0-14。共有先が読み終わる前に消さない）。
- 写真モード: `showScreenshotSheet(.export)` → `exportPhase = .choose`（0-6）。

### 3.4 閲覧専用・iPhone

- 閲覧専用でも入口・両方の操作・共有が全部使える（`GatedAction.export` は `isGated == false`。`testGate` の 19 / 11 / 8 は不変）。ペイウォール・トーストは出さない。
- iPhone（compact）: 設定はフルシート、`ExportSheet` は `.medium` の detent（`WebImportSheet` と同じ）。`ShareLink` の共有シートは下から（popover ではない）。PDF の内容は iPad と同じ（紙の大きさは lu で決まるので機種に依らない）。
- 本人の実機確認（§8-6）: iPhone で JSON を AirDrop、PDF を「ファイルに保存」。

### 3.5 写真モード（`Support/ScreenshotMode.swift`、C: build.yml）

- `Sheet` に **`export`**（8 つ目。`case create, edit, lasso, settings, sync, `import`, paywall, export`）。`parse` は不変（シートがあれば月ページ）。
- `--screenshot-sheet export`（13 インチ）: 月ページの上に `ExportSheet(.choose)`。`pageTitle` は「2026年10月」。写真 `ipad13-portrait-sheet-export.png`。
- ストアは空（`SyncEngine.swift:55`）だが `.choose` しか出さないので読まない。JSON の書き出しを写真モードで実行しても `nothingToExport` になるだけ（害なし）。

### 3.6 文言一覧（固定）

| 場所 | 文 |
| --- | --- |
| 設定 › データ の行 | 手書きを書き出す |
| 設定 › データ の脚注（追加段落） | 「手書きを書き出す」は、この端末に保存されている手書きを 1 つのデータファイル（JSON）にするか、いま開いているページを PDF にします。データファイルは「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。 |
| 設定 › 購入 の `readOnlyFooter` | 閲覧専用では、予定と手書きの閲覧、ページ移動、拡大、iCloud からの受信、この iPad の手書きを全て消す、手書きの書き出し、設定の変更ができます。新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みは購読すると使えます。 |
| シートの題名 | 手書きを書き出す |
| 操作 1 | データファイル（JSON、すべてのページ） ／ この端末に保存されている手書きをすべて 1 つのファイルにまとめます。設定 › データ › 「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。 |
| 取り込みの完成文（アプリ形式。第 2 版、0-12） | 手書きを取り込みました（N ページ・M 本） ／ 2 行目（対象外があれば）従来の「K ページは対象外のため飛ばしました」 |
| 取り込みの完成文（Web 形式・取り込むものが無い） | 従来のまま: Web 版の手書きを取り込みました（N ページ・M 本） ／ 取り込むものはありませんでした（すべて取り込み済みです） |
| 操作 2 | このページを PDF ／ いま開いているページ（2026年10月・月）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。 |
| 進行 | 書き出しています… 3 / 12 ページ ／ PDF を作っています… |
| 完成 | 書き出しました ／ てがきカレンダー 手書き 2026-10-17.json（12 ページ・1.2 MB） ／ 共有… ／ 閉じる |
| 失敗 | §2.5 の表 |
| 取り込みの `notAnExportText` | このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません |

## 4. App Store の審査資料

### 4.1 掲載写真の仕様（Apple のヘルプ「スクリーンショットの仕様」、2026-10-17 取得。偵察 (d)）

| 区分 | 必須か | 受理される画素（縦） | この CI のシミュレータ |
| --- | --- | --- | --- |
| iPhone Dynamic Island（中）（6.3 / 6.1 インチ） | **必須**（「必須の表示サイズ」節。1 枚以上、最大 10） | **1206×2622**、1179×2556 | `iPhone 17`（402×874 pt @3x = **1206×2622**） |
| iPhone Dynamic Island（大）（6.9 インチ） | 表の行に「必須」は無いが、同じページの「Face ID（大）」行が「**大 DI の写真が無ければ必須**」と言う（ページ内で矛盾。2026-10-17 現物確認） | 1320×2868、1290×2796、1260×2736 | **`iPhone 17 Pro Max`（440×956 pt @3x = 1320×2868）を足す**（第 2 版。0-15、M6-2） |
| iPhone Face ID（大）（6.5 インチ） | 「大 DI が無ければ必須」 | 1284×2778、1242×2688 | 無し（6.9 を撮れば不要） |
| iPad 13 インチ | **必須**（iPad 対応アプリ。1 枚以上、最大 10） | **2064×2752**、2048×2732 | `iPad Pro 13-inch (M5)`（**2064×2752**）。build.yml が `iPad Air 13-inch` に落ちたときは 2048×2732（どちらも受理される） |
| iPad 11 インチ | 任意（無ければ 13 を縮小） | 1668×2420、1668×2388、1640×2360、1488×2266 | `iPad Pro 11-inch (M5)`（1668×2420）、`iPad mini (A17 Pro)`（1488×2266） |

縮小の流用（Apple の文面どおり。第 2 版で訂正）: 大 DI の枠が空なら **Face ID（大）の縮小**が使われ、Face ID（大）も空なら大 DI の縮小（互いに参照）。中 DI の枠が空なら Face ID（大）の縮小。11 インチが空なら 13 インチの縮小。第 1 版の「無ければ 6.3 を流用」は Apple の記述と一致しないので取り下げ。

JPEG か PNG、**アルファ（透過）不可**、RGB。`simctl io screenshot` の PNG は通常アルファ無しだが保証されないので、C が `sips -s format jpeg -s formatOptions 100` で JPEG に変換して `store/` に置く（JPEG にはアルファが無い）。各ファイルの画素を `sips -g pixelWidth -g pixelHeight` で読み、**Apple の受理値のどれかに一致**すれば可（`ipad13`: 2064x2752 **または** 2048x2732、`iphone`: 1206x2622 または 1179x2556、`iphone69`: 1320x2868 / 1290x2796 / 1260x2736、`ipad11`: 1668x2420 / 1668x2388 / 1640x2360 / 1488x2266）。違えば `::warning`（第 1 版の 1 値照合だと `iPad Air 13-inch` に落ちた run で誤警告が出る）。

### 4.2 CI が `store/` に作るもの（C: build.yml。§7.4）

| 機種 | ファイル（`shots/store/<機種>/`） | 元の写真 | 内容 |
| --- | --- | --- | --- |
| `ipad13`（2064×2752） | `01-month.jpg` | `ipad13-portrait-month.png` | 月の一覧（見本の予定と手書き） |
| | `02-week.jpg` | `ipad13-portrait-week.png` | 週 |
| | `03-day.jpg` | `ipad13-portrait-day.png` | 日 |
| | `04-year.jpg` | `ipad13-portrait-year.png` | 年 |
| | `05-paywall.jpg` | `ipad13-portrait-sheet-paywall.png` | 購入画面（価格・試用。審査 3.1.2 の提示にもなる） |
| | `06-settings.jpg` | `ipad13-portrait-sheet-settings.png` | 設定 |
| `iphone`（1206×2622） | `01-week.jpg` | `iphone-portrait-week.png` | 週（iPhone は週で開く） |
| | `02-month.jpg` | `iphone-portrait-month.png` | 月 |
| | `03-day.jpg` | `iphone-portrait-day.png` | 日 |
| | `04-year.jpg` | `iphone-portrait-year.png` | 年 |
| | `05-paywall.jpg` | **新規** `iphone-portrait-sheet-paywall.png`（`--screenshot-sheet paywall`） | 購入画面（全高シート） |
| `iphone69`（1320×2868。第 2 版、0-15） | `01-week.jpg` 〜 `04-year.jpg`、`05-paywall.jpg` | **新規** `iphone69-portrait-{week,month,day,year}.png`、`iphone69-portrait-sheet-paywall.png`（`iPhone 17 Pro Max`。build.yml の SPEC に 1 機種追加。§7.4） | iPhone と同じ 5 枚（Connect の 6.9 インチ枠が必須表示のときだけ上げる。§6.1 の 4） |
| `ipad11`（1668×2420、任意） | `01-month.jpg` 〜 `04-year.jpg` | `ipad11-portrait-month/week/day/year.png` | 4 ページ（上げるかはリードの判断。既定: 上げない。M6-8） |

掲載の順番 = ファイル名の番号。**番号は仮**: リードが §8-5 で写真を見た時点で並べ替えてよい（iPhone の週は時間軸が左端・「今日」列が右端の構図（build.yml の M4B-27 の注記）で 1 枚目としては情報が薄いかもしれないので、**月を 1 枚目にしてもよい**）。`ipad13/06-settings.jpg` は購入状態「未購読」の設定画面で審査には有用だが掲載の最後に置く価値は低い: Connect に上げず **審査メモの添付（任意）に回す**選択肢あり（M6-9 の隣、M6-24）。マーケティングの枠や文字入れは **しない**（v1 は素の写真。M6-9）。読み取り専用のトーストや `-zoom2` の写真は使わない。

### 4.3 文言（リードが Connect に打つ。字数は Connect の上限）

| 欄 | 上限 | 値 |
| --- | --- | --- |
| 名前 | 30 | てがきカレンダー（既存） |
| サブタイトル | 30 | **カレンダーの予定に Apple Pencil で手書き**（27 字。§6.1 の 1 で打つ）。退き先（審査 2.3.7: Apple の商標を含む語を Connect が拒んだら）: **「予定の上にそのまま手書きできる手帳」**（17 字。M6-25） |
| プロモーションテキスト | 170 | **iPad の「カレンダー」に入っている予定（iCloud・Google）の上に、Apple Pencil でそのまま書き込める手帳です。月・週・日・年の 4 ページ。手書きは iCloud で iPhone とも同期。14 日間無料でお試しいただけます。**（**127 字**。第 1 版の「約 110 字」は誤り） |
| キーワード | 100 字（カンマ区切り。アプリ名の語「カレンダー」は入れない） | **手書き,手帳,予定,スケジュール,Pencil,ペン,メモ,日記,週間,月間,年間,iCloud,同期,ノート,祝日,スタイラス,プランナー**（**70 字**。第 1 版の「76 字」は誤り。Connect が短い語を拒むなら M6-10 の差し替え案: **手書き,手帳アプリ,予定表,スケジュール,Pencil,ペン入力,手書きメモ,日記帳,週間予定,月間予定,年間予定,iCloud,同期,ノート,祝日,スタイラス,プランナー** = **86 字**、上限内） |
| 説明 | 4000 | 既存の説明に 1 行追加: 機能の箇条書きの「iCloud 同期」の行の後に **「手書きは 設定 › データ › 「手書きを書き出す」で、全ページのデータファイル（JSON）や開いているページの PDF として書き出せます（購読していなくても使えます）。」**。末尾の価格・EULA・サービス規約・プライバシーの 4 行（M5_CONTRACT §6.1 の 18）は不変。**Connect に入っている説明の全文はリポジトリに無い**（M5.md にも無い。第 2 版で判明）ので、**リードが §6.1 の 5 の前に Connect から全文を写し、追記後の最終形をこの表の下（「説明の全文」）と docs/M6.md に載せる**（審査 3.1.2 の中核。レビューできる形にする）。本人項目ではない（リードが Chrome で読める） |

説明の全文（追記後の最終形。**リードが §6.1 の 5 の前に Connect から写して埋める**。第 2 版時点では空）:

```
（ここに Connect の「説明」の全文。「iCloud 同期」の行の後に上の 1 行。末尾は M5 の 4 行:
価格: 月額 300 円／年額 2,400 円（税込）。14 日間無料。サブスクリプションは自動更新です。
利用規約（EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
サービス規約: https://syfan0-star.github.io/tegaki-calendar/app/terms.html
プライバシーポリシー: https://syfan0-star.github.io/tegaki-calendar/app/privacy.html）
```
| このバージョンの新機能 | 4000 | **初版には欄が無い**（Apple）。1.0.1 以降のために「初版です。」は書かない |
| 著作権 | — | **2026 池田 雅高** |
| サポート URL | — | `https://syfan0-star.github.io/tegaki-calendar/app/support.html`（既存） |
| マーケティング URL | — | 空 |
| プライバシーポリシー URL | — | `https://syfan0-star.github.io/tegaki-calendar/app/privacy.html`（既存） |

審査メモ（App Review に関する情報 › メモ。≤4000 バイト。DESIGN §10「2.1 審査用アカウント」「4.2」「App Privacy」の文面を 1 つに。第 2 版: 【動作確認】に「予定が無くても／iCloud 無しでも動く」の 1 文、末尾に英語の要約 8 行。経路「設定 › 入力 › 「指でも書く」」は実物の欄名どおり: `Views/SettingsScreen.swift:305-307` の `Toggle("指でも書く", …)` と `header: { Text("入力") }`。合計 ≈ 3,400 バイト（リードが Connect の字数表示で上限内を確認）:

```
ログイン・アカウント作成はありません。デモアカウントも不要です。

【動作確認】iPad の「カレンダー」アプリに予定を 2〜3 件（終日と時間指定）作ってからアプリを開くと、月・週・日・年の各ページにその予定が表示され、Apple Pencil（または 設定 › 入力 › 「指でも書く」をオンにして指）で予定の上に手書きできます。手書きをなぞって予定を作ることもできます。Google カレンダーは任意で、iPad の設定でアカウントを追加した場合に表示されます。予定が 1 件も無くても手書きはできます。iCloud にサインインしていなくても端末内だけで動きます（同期は iCloud 任意）。

【サブスクリプション】月額 300 円／年額 2,400 円、14 日間の無料トライアル（StoreKit 2。com.syfan0.tegakicalendar.monthly / .yearly）。初回案内の後に購入画面が 1 回出ます。「あとで」で閉じると閲覧専用モードになり、予定と手書きの閲覧・ページ移動・拡大・手書きの書き出しはできますが、書く・消す・予定の作成は購入の案内が出ます。購入画面はヘッダーの「閲覧専用」バッジと 設定 › 購入 からも開けます。復元は 設定 › 購入 › 「購入を復元」。利用規約（Apple 標準 EULA）・サービス規約・プライバシーポリシーへのリンクは購入画面と 設定 › 情報 にあります。

【データ】本アプリにサーバーはありません。カレンダーのデータは EventKit で端末内の予定を表示・編集するためだけに使い、端末外へ送信しません。手書きデータは端末内と利用者自身の iCloud プライベートデータベースに保存され、開発者はアクセスできません。設定 › データ › 「手書きを書き出す」で手書きを JSON または PDF にして共有シートに渡せます（利用者が選んだ先にだけ届きます）。解析・広告・第三者 SDK は含みません。

Web 版「手書きカレンダー」（PWA）とは別物で、WebView は使っていません（PencilKit・EventKit・CloudKit・StoreKit という iPadOS の部品だけで作っています）。配信は日本を中心に、EU は除外しています。日本語のみ。

サービス規約: https://syfan0-star.github.io/tegaki-calendar/app/terms.html
プライバシーポリシー: https://syfan0-star.github.io/tegaki-calendar/app/privacy.html
サポート: https://syfan0-star.github.io/tegaki-calendar/app/support.html

--- English summary for the reviewer ---
No login, no account creation, no demo account needed.
To test: add 2-3 events (one all-day, one timed) in the iPad Calendar app, then open the app. The events appear on the month / week / day / year pages and you can write on them with Apple Pencil (or a finger: Settings > 入力 > 「指でも書く」). Handwriting works with no events and without an iCloud sign-in (iCloud is optional, for sync only).
Subscriptions (StoreKit 2): monthly ¥300 (com.syfan0.tegakicalendar.monthly) / yearly ¥2,400 (.yearly), 14-day free trial. The paywall appears once after onboarding; 「あとで」 (Later) enters read-only mode: viewing, navigation, zoom and export keep working, writing / erasing / creating events show the paywall. Restore: Settings > 購入 > 「購入を復元」.
Export: Settings > データ > 「手書きを書き出す」 writes a JSON of all pages or a PDF of the current page to the system share sheet (user-chosen destination only).
No server. Calendar data is read with EventKit on the device only; handwriting stays on the device and in the user's own CloudKit private database. No analytics, ads or third-party SDKs; no data collected. Not a WebView: PencilKit, EventKit, CloudKit and StoreKit only. Japan-centric distribution (EU excluded), Japanese only.
Terms / Privacy / Support: the three URLs above.
```

**【】は審査メモ（Connect の欄）だけ**で使う。規約類（L・W）には書かない（`check:legal` が禁じる）。

### 4.4 App のプライバシー（App Privacy）の回答（PRIVACY 付録 B `docs/PRIVACY.md:94-107`、DESIGN §10）

| 質問 | 回答 | 根拠 |
| --- | --- | --- |
| このアプリ（または連携する第三者）はデータを収集しますか？ | **いいえ** | 開発者のサーバーが無い。Apple の定義: 「収集」= 端末外へ送り、要求処理より長く読める形で保持。端末内だけの処理は収集に当たらない |
| 結果のラベル | **データは収集されません** | |
| トラッキング | **いいえ** | 広告・解析 SDK 無し。`PrivacyInfo.xcprivacy` は `NSPrivacyTracking false`、収集 0、UserDefaults CA92.1 |
| iCloud（CloudKit プライベート DB） | 申告しない | 開発者が読めない利用者本人の領域（PRIVACY §2 の表）。Apple の枠組みが集めるデータは開発者の申告義務外 |
| 書き出し（共有シート） | 申告しない | 利用者が選んだ先にだけ、利用者の操作で渡る（収集ではない） |
| 審査で聞かれたときの説明 | PRIVACY 付録 B の文（`:106`）を審査メモに含めてある（§4.3） | |

### 4.5 年齢区分（2025 年版の質問票。全部「なし／いいえ」→ **4+**）

| 項目 | 回答 |
| --- | --- |
| 暴力（漫画・ファンタジー／現実的／銃器・武器） | なし |
| 性的な内容・ヌード | なし |
| 不敬な表現・下品なユーモア | なし |
| ホラー・恐怖 | なし |
| 医療・治療の情報 | なし |
| アルコール・タバコ・薬物 | なし |
| ギャンブル（疑似／現実）・コンテスト・ルートボックス | なし |
| 無制限の Web アクセス | いいえ（アプリ内にブラウザ無し。規約などのリンクは Safari で開く） |
| ユーザー生成コンテンツ（他の利用者と共有） | いいえ（手書きは本人の端末と iCloud だけ。アプリ内に共有・公開の機能は無い。共有シートは OS の機能で利用者が相手を選ぶ） |
| メッセージ・チャット | いいえ |
| 広告 | いいえ |
| 保護者による制限・年齢保証 | なし |
| Made for Kids（子ども向け） | **選ばない**（PRIVACY §8 と整合） |
| 年齢適合 URL（任意） | 空 |

### 4.6 カテゴリ・連絡先・その他

| 欄 | 値 |
| --- | --- |
| 主カテゴリ | **仕事効率化** |
| 副カテゴリ | **ライフスタイル**（M6-11） |
| App Review 連絡先 | 名前 **池田 雅高**、メール **syfan0@gmail.com**、電話 **+81 … （本人項目。国際形式。数字だけは拒まれる）** |
| サインインが必要 | いいえ |
| 添付 | なし（短い操作動画は任意。M6-12 既定: 付けない） |
| バージョンのリリース | **手動でリリース**（審査通過後に本人が公開日を決める。M6-13） |
| ライセンス契約 | Apple 標準 EULA のまま（M5-8） |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = false`（Info.plist `project.yml:70`）。Connect の質問は出ない。出たときの正直な答え（第 2 版で訂正）: 「暗号化を使用しますか」= **はい**（HTTPS・CloudKit）→「標準の暗号化（HTTPS 等）のみ／免除に該当」= **はい** → 免除。第 1 版の「いいえ（標準の暗号化のみ）」は Connect の最初の質問の意味と合わない |
| コンテンツ権利 | 第三者のコンテンツを含まない → 「いいえ」 |

## 5. 規約類（担当 L: iOS の 3 文書、担当 W: Web の HTML）

### 5.1 L が直すこと（`docs/TERMS.md` / `SUPPORT.md` / `PRIVACY.md`。平易な日本語。【】・「下書き」は書かない）

| 文書 | 行 | 今 | 直す |
| --- | --- | --- | --- |
| TERMS | :3 要約 | 「アプリをやめるときは 90 日前にお知らせし、その時までに手書きを書き出す手段を用意します。」 | 「アプリをやめるときは 90 日前にお知らせします。手書きはいつでも書き出せます。」 |
| TERMS | :7 | 最終更新：2026年10月17日 | 最終更新：**L が編集した日**（YYYY年M月D日）。施行日の文は不変 |
| TERMS | :29 第 3 条 4 項 | 「手書きの書き出し（データファイル・PDF・画像）は**順次提供**します（提供状況は App Store の説明と…に記載）。」 | 「**手書きの書き出し**（この端末に保存されている手書き全部のデータファイル（JSON）と、開いているページの PDF。設定 › データ › 「手書きを書き出す」）。」（第 2 版: 第 1 版の末尾「画像など、ほかの形式は順次提供します。」は **削る**。範囲外で予定も無い機能を規約上の約束にしてしまい、M5-27「約束を本物にする」と逆行するため。第 2 条が iPhone・Mac も対象にしているので「この iPad」ではなく「この端末」） |
| TERMS | :51 第 5 条 5 項 できること | 「…この iPad の手書きを全て消す、設定の変更。」 | 「…この iPad の手書きを全て消す、**手書きの書き出し（データファイル・PDF）**、設定の変更。」 |
| TERMS | :53 | 「現在、手書きの書き出し機能は未提供です（提供予定）。iPad のバックアップと iCloud が控えになります。」 | 「手書きの書き出しは閲覧専用でも使えます。書き出したデータファイルの取り込み（復元）は購読中に行ってください。」 |
| TERMS | :79 第 8 条 2 項 | 「終了の 90 日前までに、手書きを書き出す手段（データファイル、または PDF・画像）を用意し、終了まで使える状態に保ちます。手書きは…」 | 「手書きを書き出す手段（設定 › データ › 「手書きを書き出す」のデータファイルと PDF）は用意してあり、終了まで使える状態に保ちます。手書きは…」（続きは不変） |
| TERMS | :93 第 9 条 5 項 | 「（書き出し機能の提供後はそれも）」 | 「（「手書きを書き出す」のデータファイルも）」 |
| SUPPORT | :7 | 最終更新：2026年10月17日 | L の編集日 |
| SUPPORT | :27-33 対応すること | — | 末尾に 1 行「- 手書きの書き出し（データファイル・PDF）の案内」 |
| SUPPORT | :83 FAQ「無料試用が終わったら…」 | 「手書きの書き出しは提供開始後、閲覧専用でも使えるようにする予定です。」 | 「手書きの書き出し（設定 › データ › 「手書きを書き出す」）は閲覧専用でも使えます。」 |
| SUPPORT | :125 の後（Web 取り込み FAQ の直後） | — | 新 FAQ **「### 手書きを書き出すには？」**（第 2 版で 4 文追加）: 「アプリの 設定 › データ › 「手書きを書き出す」を押し、「データファイル（JSON、すべてのページ）」か「このページを PDF」を選びます。できあがると「共有…」から「ファイル」アプリに保存したり、AirDrop やメールで送ったりできます。書き出しは購読していなくても使えます。<br><br>**データファイル**は、この端末に保存されている手書き全部（月・週・日・年）を 1 つの JSON にしたもので、設定 › データ › 「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行ってください）。同じファイルを二度取り込んでも二重にはなりません。取り込みは「足す」方向だけです: 書き出した後にアプリで消した線は、取り込み直しても戻りません（消した記録のほうが優先されます）。全部を元に戻したいときは、設定 › データ › 「この iPad の手書きを全て消す」で消してから取り込んでください。データファイルはこのアプリに取り込み直すためのものです（中身は読めるテキスト（JSON）です。形式は開発者向けに設計書と README に載せています）。人が読める形で手元に残すには、各ページを PDF にしてください。ファイルの大きさはおおむね 200 MB（手書き数万本）までを想定しています。それより大きいと取り込みに時間がかかったり、失敗したりすることがあります。<br><br>**PDF** は、いま開いているページを 1 枚にしたものです（紙・予定・祝日・手書き。現在時刻の線は入りません）。」 |
| SUPPORT | :121 | 「手書きを書き出す（iPad アプリ用）」 | **不変**（Web 版の機能名。W のテスト (5) が要求） |
| SUPPORT | :137 既知の制限 | 「\| 手書きの書き出し \| 未提供（提供予定）。…\|」 | **行を外す** |
| PRIVACY | :7 | 2026年10月17日 | L の編集日 |
| PRIVACY | :45-49 §4 手書き | — | 末尾に 1 文「- 設定の「手書きを書き出す」で作るファイル（JSON・PDF）は、あなたが共有シートで選んだ先（「ファイル」アプリ、AirDrop、メールなど）にだけ渡ります。開発者には送られません。データファイル（JSON）には手書きの線と、どの端末で書いたかを区別する印（このアプリ用のランダムな識別子。端末の名前やシリアル番号ではありません）が入ります。」（D6。第 2 版: `dev` の 1 文を追加。§1.1） |

`grep -n "未提供\|順次提供\|提供予定\|【\|下書き" docs/TERMS.md docs/SUPPORT.md docs/PRIVACY.md` は **全部 0 行**（第 2 版: 「順次提供」も 0。第 1 版の「1 件だけ許す」は取り下げ）。価格・試用・解約の経路・連絡先・氏名は触らない。上の表の `<br><br>` は段落の切れ目（SUPPORT.md では空行）。新しい文言では「この iPad に保存されている」と書かず **「この端末に保存されている」**（既存の行名「この iPad の手書きを全て消す」の引用は不変）。

### 5.2 W が作るもの（Web リポジトリ、ブランチ `m6-legal`。main（a2ba79a）から切る）

- `app/terms.html`（:53, :80, :107, :124 と要約・`.meta` の最終更新）、`app/support.html`（:106, :151 を外す、対応すること、新 FAQ、`.meta`）、`app/privacy.html`（§4 の 1 文、`.meta`）を L の Markdown と文字単位で一致させる（M5 と同じ様式。`<script` 無し、`.md"` 無し、CSP の meta そのまま）。`app/index.html`・`sw.js`・`package.json`（1.0.6）・`README.md` は **不変**。
- `tests/app-pages.test.mjs`: (3) terms に `手書きを書き出す` を追加、(5) support に `手書きを書き出すには` を追加、**(8) 新規**: `terms.html` と `support.html` に `未提供`・`提供予定`・**`順次提供`**（第 2 版）が **無い**。(1)(2)(4)(6)(7) は不変。`npm test` 緑、`npm run check:legal` 緑（【】は審査メモだけ。§4.3）。
- commit だけ（push しない・merge しない）。リードが **TestFlight のビルド（1.0）が出た後**に差分を読んで main に merge（Pages が 10 分以内に配信）→ `curl -sI` で 3 URL が 200 → C が DESIGN §10 に「1.0 の文面に更新済み（日付）」。順番の理由: 書き出しの無いビルドが本人の iPad にある間、公開ページが「提供中」と言わないため。

## 6. App Store Connect の手順

### 6.1 リードが本人の Chrome で行う（順番どおり。値は §4 のまま打つ。前提: main に M6 が入り、testflight.yml の 1.0 ビルドが「有効」）

| # | 画面 | 操作と値 |
| --- | --- | --- |
| 1 | マイ App › てがきカレンダー（6822762089）› App 情報 | 主カテゴリ **仕事効率化**、副カテゴリ **ライフスタイル**。ローカリゼーション可能な情報 › 日本語: 名前「てがきカレンダー」（既存）、**サブタイトル「カレンダーの予定に Apple Pencil で手書き」（27 字。§4.3。Connect が拒んだら M6-25 の退き先）**。ローカリゼーションは日本語のみ。ライセンス契約は標準のまま。コンテンツ権利「第三者のコンテンツを含まない」 |
| 2 | App 情報 › 年齢区分 › 編集 | §4.5 の質問票を全部「なし／いいえ」→ 結果 **4+** を保存。Made for Kids は選ばない |
| 3 | App のプライバシー › 開始 | 「データを収集しますか？」**いいえ** → 保存 → **公開**（ラベル「データは収集されません」）。プライバシーポリシー URL は既存の値のまま |
| 4 | 1.0 提出準備中 › スクリーンショット | iPhone 6.3 インチ（Dynamic Island（中））: `store/iphone/01-05`（5 枚、§8-5 で決めた順）。iPad 13 インチ: `store/ipad13/01-05`（5 枚。`06-settings` は M6-24 の既定どおり上げず、審査メモの添付に回すか捨てる）。**6.9 インチ（Dynamic Island（大））: Connect がこの枠を必須表示にしていれば `store/iphone69/01-05` を上げる。任意表示なら上げない**（M6-2。第 2 版）。11 インチは **上げない**（M6-8。上げるなら `store/ipad11/01-04`） |
| 5 | 1.0 › プロモーションテキスト／説明／キーワード | §4.3 の値。説明は既存の文に 1 行を追加（場所は §4.3）。字数の表示が上限内であることを確認 |
| 6 | 1.0 › サポート URL／マーケティング URL／著作権 | 既存の URL のまま、マーケティングは空、著作権 **2026 池田 雅高** |
| 7 | 1.0 › ビルド | 「＋」→ TestFlight の **1.0 (N)**（N = testflight.yml の run 番号。main から出した最新）を選ぶ。輸出コンプライアンスの質問は出ない（出たら: 暗号化を使用する = **はい** → 標準の暗号化（HTTPS 等）のみ = **はい** → 免除。§4.6） |
| 8 | 1.0 › App Review に関する情報 | 連絡先: 名 雅高・姓 池田・電話 **+81 …（本人から）**・メール syfan0@gmail.com。サインインが必要: **オフ**。メモ: §4.3 の審査メモ全文。添付: なし |
| 9 | 1.0 › バージョンのリリース | **手動でリリース**（M6-13） |
| 10 | 1.0 › App 内課金とサブスクリプション | **まだ版に紐づいていない前提**（本契約の前提「NOT yet set: adding the subscriptions to the version」。第 1 版の「M5 §6.1 の 17 で追加済み」は誤り）。「＋」から 2 つ（月額・年額）を版に追加。既に紐づいていればそのまま |
| 11 | 収益化 › サブスクリプション › 月額 | 状態「提出準備中」→ **「審査用に追加」** → 「既存の提出に追加」（1.0 の提出）。年額も同じ |
| 12 | 1.0 の提出の確認画面 | 項目が **版 1.0 ＋ サブスクリプション 2 つ**、スクリーンショット・説明・年齢区分・プライバシー・連絡先が全部「完了」。**ここで止める**。「審査へ提出」は押さない |
| 13 | 本人へ報告 | 止めた画面の状態と、§6.2 の 3（提出の判断）を伝える |

価格・配信地域（148 か国、EU 除外）・プライバシーポリシー URL・サポート URL・説明の価格 4 行・有料 App 契約は **M5 で済み**（触らない）。

### 6.2 本人がやること（Claude が代行できない）

1. **電話番号**をリードに渡す（`+81` で始める国際形式。App Review の連絡先に入る。審査チームから電話が来ることは稀）。
2. TestFlight の 1.0 ビルドで **§8-6 の実機確認**（書き出しの往復・PDF・iPhone の共有）と、M5.md §2.3 の **サンドボックス試験の残り**（未実施の行）。
3. **提出の判断**: §6.1 の 12 で止まっている画面の「審査へ提出」を本人が押す（または押すように指示する）。
4. §9 のうち返事が要るもの（返事が無ければ既定）。
5. **入力後の目視**（第 2 版）: §6.1 の 13 の報告を受けたら、提出の確認画面で **販売者名（池田 雅高）・著作権（2026 池田 雅高）・連絡先（電話・メール）・サブタイトル** を本人が目で確認する（本人の氏名と連絡先が公開情報になる欄なので、リードの入力を本人が見る）。

## 7. CI と検査

### 7.1 KitChecks（K、`TegakiKit/Sources/KitChecks/main.swift`。「access state (M5)」:3729 の後に節を足す）

`section("app export (M6)")`: `exportedAtText`（JST の固定日時 → `2026-10-17T21:03:00+09:00`、UTC → `…Z`）、`isWorthExporting`（空 / 線あり / 墓標だけ / unknownStrokes だけ）、`jsonValue` の鍵 5 つ、`encode` の先頭が `{\n  "app": ` で末尾が `  "v": 1\n}\n`、`header + pageText… + footer == encode`（1 ページ・3 ページ・0 ページ）、`pageText` の往復（`JSONValue.parse(pageText)` → `InkPage(json:)` == 元）、`serialized(pretty: true)` の規則（数値配列 1 行・object 1 鍵 1 行・空 `{}` `[]`・入れ子の字下げ）と `serialized()` の不変（M5 までの固定文字列と同一）、`parse(json:)` の 3 つの throw、`InkImport.parse` の分岐（web / app / notAnExport / invalidJSON / unsupportedVersion）、`InkImport.pages` の `skipped`・`pageCount`・`isAppExport`、**`topLevelMembers` / `arrayElements` の走査**（第 2 版: 圧縮形と整形の両方、`"` `\"` `\\` `{` `[` を含む文字列、空配列、入れ子、object でない・括弧の合わない入力は nil、`parse(data)` のページ単位の結果 == `AppExport.parse(json: JSONValue.parse(data))`）、`jsonFileName`（JST 2026-10-17 23:30 = 10-17、UTC 2026-10-17 15:30 の JST = 10-18）、`pdfFileName` の 4 種（月・週・年またぎの週・日・祝日の日・年）、`safeFileName`、`kindLabel`。見込み +180〜220 件。**K が実数 N を docs/M6.md に書き、C が閾値 N − 50 を build.yml :63-69 に入れる**（今 23114 / 23064。M5-25 の流儀）。

### 7.2 XCTest（役割ごと。名前は固定）

| 担当 | ファイル | テスト |
| --- | --- | --- |
| K | `TegakiKit/Tests/InkModelTests/AppExportTests.swift` | `testDocumentShapeAndKeyOrder`、`testEncodeEqualsStreamedParts`、`testPrettyJSONRules`、`testCompactSerializationIsUnchanged`（M5 までの固定文字列）、`testPageRoundTripsThroughInkPage`（pen・marker・dev あり/なし・墓標・unknown・unknownStrokes）、`testParseRejectsOtherFormatsAndNewerVersions`、`testParseDropsPagesWithoutId`、`testParseMigratesBandCells`（`allday:` のページが `grid` に）、`testFileNames`（JSON と PDF の 6 例）、`testIsWorthExporting`、`testParsePageMatchesParse`（`parsePage` を各要素に呼んだ結果 == `parse(json:).pages`。第 2 版） |
| K | `TegakiKit/Tests/InkModelTests/InkImportTests.swift` | `testParseDispatchesOnFormat`（web サンプル（`WebImportTests.sample`）→ `.web`、app → `.app`）、`testErrorsMatchWebImport`（`invalidJSON` / `notAnExport` / `unsupportedVersion(2)` が Web 形式と同じ型・同じ値）、`testPagesOutcome`（web は `WebImport.convert` と同じ、app は skipped と pageCount と `isAppExport`）、`testWebParseDataIsUnchanged`（`WebImport.parse(_ data:)` と `parse(json:)` が同じ結果）、**`testTopLevelMembersAndArrayElements`**（圧縮形・整形・文字列の中の `{` `[` `"` `\"` `\\`・空配列・入れ子・object でない入力 → nil・括弧が合わない → nil。第 2 版）、**`testStreamedParseEqualsWholeParse`**（3 ページの文書を `InkImport.parse(data)` と `AppExport.parse(json: JSONValue.parse(data))` で解析して `==`。壊れたページ要素 → `invalidJSON`。`pages` が配列でない → `notAnExport`） |
| X | `Tests/TegakiCalendarTests/ExportBuilderTests.swift`（`InkPageStore(directory: temporaryDirectory…)`。`SyncEngineTests.swift:29-33` の流儀） | `testJSONExportWritesEveryStoredPageSorted`（月・週・日・年の 4 ページ＋空ページ 1 → 4 ページ、pageId 順、`byteCount == ファイルの大きさ`、ファイル名）、`testJSONExportMigratesBandCells`（`allday:` のページを保存しておく → 書き出しは `grid`）、`testJSONExportRoundTripsThroughImport`（書き出し → `InkImport.parse` → `.app` → 空の第 2 ストア `store2` の **`SyncEngine(store: store2, stateStore: SyncStateStore(fileURL: store2.stateFileURL), database: InMemoryCloudDatabase())`**（`stateStore:` は必須。`Sync/SyncEngine.swift:109-115`、`SyncEngineTests.swift:33-35` の形。第 2 版で訂正）に `importPages` → 各ページが元と `==`；**もう一度** importPages → `pagesChanged == 0`、`strokesAdded == 0`）、`testJSONExportReportsProgress`（done が 1…total、total = 全 id 数）、`testNothingToExport`（ストアが空／空ページだけ → `.nothingToExport`、ファイルが残らない）、`testCleanUpRemovesPreviousFiles`、**`testLargeExportImportsPageByPage`**（第 2 版、D7「大きなファイル」: 8 ページ × 1,000 本 × 50 点（≈ 25 MB の整形 JSON）をストアに保存 → `exportJSON` → `InkImport.parse` → `.app` の 8 ページが元と `==`。解析の前後で `task_info(TASK_VM_INFO)` の `phys_footprint` を読み、**増分 < ファイルの 8 倍** を `XCTAssertLessThan`（ページ単位なら ≈ 3 倍、従来の全体の木なら ≈ 20 倍なので判別できる）。所要と増分の実測を docs/M6.md に書く。CI の時間を見て大きさは 1/2 まで下げてよい）、`testPDFHasOnePageAndOverviewSize`（`PaperContent` は **自前で組む**: `MonthLayoutEngine.layout(MonthLayoutInput(month:events: ScreenshotMode.demoEvents(for:), inkBottoms:now:))` → `.month(MonthPaperContent(layout:labels: layout.dateLabels, bars: layout.allDayBars, chips: layout.timedChips, holidayNames: JapaneseHolidays.names(for: …)))`（`Tests/TegakiCalendarTests/PaperViewTests.swift:15-18` と同じ流儀。`CalendarRootScreen.makePaper` は `private static`（:803）で X からは呼べない。第 2 版）＋ `ScreenshotMode.demoPage(for: 2026-10)`（メモに点あり）→ `PDFDocument(data:)` の `pageCount == 1`、`bounds(for: .mediaBox)` = 1400 × (36 + 28 + layout.size.height)；メモの線を消したページ → 高さ = 36 + 28 + `memo.minY`）、`testPDFRendersEveryKind`（週・日・年も `WeekLayoutEngine.layout(WeekLayoutInput(...))` → `.week(WeekPaperContent(layout:))`、`DayLayoutEngine` → `.day(DayPaperContent(layout:))`、`YearLayoutEngine` → `.year(YearPaperContent(layout:monthNames:))` を直接作る。`pageCount == 1`、大きさが §1.4 の式: 週は `36 + 40 + laneCount × 25 + 6（0 レーンなら 0）+ layout.size.height`、**日は `laneCount × 24`**、年は `36 + 28 + layout.size.height`。`now` を週・日の範囲内にして `layout.nowLine != nil` を確かめたうえで、`stripNowLine(paper).layout.nowLine == nil` と、`render` の出力が `nowLine = nil` の layout から作った出力と **バイト単位で等しい**（現在時刻の線が描かれない）。第 2 版）、`testPDFFileNameAndMetadata`（`documentAttributes[.titleAttribute] == PageNavigation.title`） |
| U | `Tests/TegakiCalendarTests/ExportSheetTests.swift` | `testTexts`（title・jsonTitle・jsonNote・pdfTitle・`pdfNote("2026年10月", .month)`）、`testProgressText`（json 3/12、pdf、choose → ""）、`testDoneText`（JSON 12 ページ・1.2 MB、PDF）、`testByteText`（512 → 「512 B」、524288 → 「512 KB」、1258291 → 「1.2 MB」）、`testFailureText`（§2.5 の 5 行、`.cancelled` → nil）、`testIsInProgress` |
| U | `SettingsScreenTests.swift` | `testDataSectionTexts`（**新規**: `SettingsScreen.exportFooter` が §3.6 の文と一致）、既存 `testPurchaseFooter…`（:97-103）の `contains("閲覧専用では、…設定の変更ができます。")` を新しい列挙（「…この iPad の手書きを全て消す、手書きの書き出し、設定の変更ができます。」）に更新。`readOnlyFooter` は private のままなので **`SettingsScreen.purchaseFooter(.readOnly(.notSubscribed))` 経由**で見る（第 2 版） |
| U | `ScreenshotModeTests.swift:291-292` | `Sheet.allCases.count == 8`、raw 値の配列に `"export"`、`testParseM4Sheets` の `"export"` → `.export`（`XCTAssertNil` を外す） |
| U | `CalendarRootScreenTests.swift` | `testGate`（:66-74）は不変（19 / 11 / 8）。**新規** `testImportFailureTexts`（`CalendarRootScreen.importFailureText(_:)` を internal にしたうえで（§1.2）: `.notAnExport` → `WebImportSheet.notAnExportText` == 「このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません」、`.unsupportedVersion(2)` → `unsupportedVersionText(2)`、`.invalidJSON` と無関係な Error → `invalidJSONText`。第 1 版は既存テストのように書いていたが存在しなかった） |
| U | `WebImportSheetTests.swift`（無ければ新規） | **新規** `testResultTextByFormat`（`resultText(outcome, isAppExport: true)` → 「手書きを取り込みました（3 ページ・12 本）」、`isAppExport: false` → 「Web 版の手書きを取り込みました（3 ページ・12 本）」、`pagesChanged == 0` はどちらも「取り込むものはありませんでした（すべて取り込み済みです）」、`toastText` の 2 行目は従来どおり。第 2 版、0-12） |

### 7.3 XcodeGen（C、`project.yml`）

```yaml
settings.base.MARKETING_VERSION: "1.0"        # :20。CURRENT_PROJECT_VERSION "1" は不変（TestFlight は run 番号で上書き）
```

依存の追加は無し（`Export/*` は `Sources/TegakiCalendar` 配下で自動。`InkModel` / `Layout` は既に依存）。`PrivacyInfo.xcprivacy` 不変（書き出しは新しい API 区分に触れない。`FileManager` の tmp は申告対象外）。

### 7.4 CI（C、`.github/workflows/build.yml`）

| 場所 | 変更 |
| --- | --- |
| 先頭コメント :1-13 | 「up to 36 images + 4 logs」→ **「up to 43 images + 5 logs + store/」**、M6 の 1 文（export シート、iPhone の paywall、6.9 インチの 5 枚、store/） |
| KitChecks :59-69 | 閾値を K の実数 − 50 に（コメントの数字も） |
| 13 インチのシートのループ :273 | `for SHEET in create edit lasso settings sync import paywall export`（8 つ。見出しの「7 sheets」→「8 sheets」） |
| 他機種の SPEC :337-339（第 2 版、0-15） | `"iphone69|iPhone 17 Pro Max|iPhone 17 Pro Max,iPhone 17 Pro,iPhone 16 Pro Max"` を `iphone` の **次**に 1 行追加（接頭辞の退き先の順。`iPhone 17 Pro` に落ちたときは 6.3 インチの画素になり `sips` の照合が `::warning` を出すので分かる）。コメント :309-310 に `iphone69 (iPhone 17 Pro Max, 440 pt)` を足す。4 ページの portrait（`iphone69-portrait-{month,week,day,year}.png`）は既存のループのまま撮れる。所要 ≈ 2 分 |
| iPhone の `shoot` :397-416 | `shoot "$ID-portrait-sheet-paywall.png" --screenshot-month 2026-10 --screenshot-page month --screenshot-sheet paywall` を readonly の次に追加。**`if [ "$ID" = "iphone" ] || [ "$ID" = "iphone69" ]` で `iphone69` も paywall を撮る**（week-sun・zoom3・jun・landscape・readonly は `iphone` だけのまま）。ログは `shots/iphone69-log.txt`（5 本目） |
| 新しいステップ「Store listing set」（Upload の直前、`if: always()`、`continue-on-error: true`） | §4.2 の表のとおり `mkdir -p shots/store/{ipad13,iphone,iphone69,ipad11}` → 各行 `sips -s format jpeg -s formatOptions 100 shots/<src>.png --out shots/store/<dev>/<NN-name>.jpg`（元が無ければ `::warning` して飛ばす）→ `sips -g pixelWidth -g pixelHeight` を読み、**Apple の受理値の集合**（§4.1。`ipad13`: `2064x2752 2048x2732`、`iphone`: `1206x2622 1179x2556`、`iphone69`: `1320x2868 1290x2796 1260x2736`、`ipad11`: `1668x2420 1668x2388 1640x2360 1488x2266`）に **含まれなければ** `::warning`（第 2 版。1 値照合だと `iPad Air 13-inch` に落ちた run で誤警告）。`ls -la shots/store/*` |
| Upload :425-432 | 不変（`path: shots` に `store/` も入る） |

### 7.5 成果物の配置（`screenshots`、7 日）

```
shots/
  ipad13-portrait-{month,week,day,year}.png / -{month,week,year}-zoom2.png / -readonly.png
  ipad13-portrait-sheet-{create,edit,lasso,settings,sync,import,paywall,export}.png      ← export が新規（16 枚）
  ipadmini-portrait-{month,week,day,year}.png                                            （4）
  ipad11-portrait-{month,week,day,year}.png / -readonly.png                              （5）
  iphone-portrait-{month,week,day,year}.png / -week-sun / -week-jun / -week-zoom3 / -readonly / -sheet-paywall.png   ← sheet-paywall が新規（9）
  iphone-landscape-{month,week,day,year}.png                                             （4）
  iphone69-portrait-{month,week,day,year}.png / -sheet-paywall.png                       ← 全部新規（5。第 2 版、0-15）
  app-log.txt / iphone-log.txt / iphone69-log.txt / ipadmini-log.txt / ipad11-log.txt    ← iphone69-log が新規（5 本）
  store/ipad13/01-month.jpg … 06-settings.jpg
  store/iphone/01-week.jpg … 05-paywall.jpg
  store/iphone69/01-week.jpg … 05-paywall.jpg
  store/ipad11/01-month.jpg … 04-year.jpg
```

合計: 画像 **43 枚**（M5 の 36 ＋ export シート 1 ＋ iPhone の paywall 1 ＋ iphone69 の 5）＋ ログ 5 本 ＋ `store/` **20 枚**（6 + 5 + 5 + 4）。

## 8. 完了の定義

1. `swift run --package-path TegakiKit KitChecks` が「all N checks passed」（N ≥ 閾値。ローカルと CI）。`swift test --package-path TegakiKit`（`AppExportTests` / `InkImportTests` を含む）が CI で緑。順序: K が N を docs/M6.md に書く → C が閾値を入れる。
2. CI の `build` が緑: 13 インチのユニットテスト（§7.2 の X・U のテストと M5 までのテスト。`StoreKitSessionTests` の 7 本は skip のまま可。M5.md §3）が通り、成果物 `screenshots` に **43 枚 + ログ 5 本 + `store/` 20 枚**（§7.5。第 2 版）。X の `testLargeExportImportsPageByPage` の所要が CI で 60 秒を超えるなら大きさを 1/2 に下げて docs/M6.md に書く。
3. `project.yml` の `MARKETING_VERSION` が 1.0。main への merge 後に testflight.yml を 1 回走らせ、Connect に **1.0 (N)** が「有効」で現れる。
4. Web リポジトリ: `m6-legal` で `npm test`（(8) を含む）と `npm run check:legal` が緑。TestFlight の 1.0 が出た後にリードが merge → 3 URL が 200 → 文面に「未提供」が無い（`curl -s … | grep -c 未提供` が 0）。
5. リード（本人）が **次の写真を見て** 確かめる:

| 写真 | 見えていなければならないもの |
| --- | --- |
| `ipad13-portrait-sheet-export.png` | 月ページの上に中くらいのシート。題名「手書きを書き出す」、上に「データファイル（JSON、すべてのページ）」と説明 1 行、下に「このページを PDF」と説明「いま開いているページ（2026年10月・月）を 1 枚の PDF にします。…」、「閉じる」。文字が切れていない |
| `ipad13-portrait-sheet-settings.png` | データ欄が画面内なら 3 行（取り込む／**手書きを書き出す**／全て消す）。画面外なら可（13 インチでは下にある） |
| `iphone-portrait-sheet-paywall.png` | 全高のシートに M5 の購入画面（年額が上・「14 日間無料で試す」・EULA の行・「あとで」）。切れ無し |
| `store/ipad13/01-06`、`store/iphone/01-05`、`store/iphone69/01-05` | 元の写真と同じ内容、JPEG、画素が §4.1 の受理値のどれか（ログの `sips` の行）。ステータスバー 9:41・電池 100 %。**ここで掲載の順番を決める**（§4.2「番号は仮」。iPhone は月を 1 枚目にしてもよい） |
| `iphone69-portrait-{month,week,day,year}.png` | iPhone 17 と同じ構図が 440 pt 幅で（文字が切れていない。週の時間軸は左端） |
| 既存の 36 枚 | M5 と同じ |

6. 本人が TestFlight（1.0）で **実機**:

| # | 手順 | 期待 |
| --- | --- | --- |
| 1 | iPad で何ページかに書く → 設定 › データ › 「手書きを書き出す」→「データファイル（JSON、すべてのページ）」 | 進行「書き出しています… n / N ページ」→「書き出しました」＋ファイル名「てがきカレンダー 手書き YYYY-MM-DD.json（N ページ・… KB）」→「共有…」→「ファイル」に保存。「ファイル」アプリで開くと整形された JSON が読める（`format`・`pages`） |
| 2 | 設定 › データ › 「この iPad の手書きを全て消す」（iCloud を含めて）→ 設定 › データ › 「Web 版の手書きを取り込む」で 1 のファイル | **「手書きを取り込みました（N ページ・M 本）」**（アプリ形式の完成文。0-12）→ 全ページの手書きが **元の位置に** 戻る（色・太さ・マーカーの透け方も同じ）。もう一度取り込む → 「取り込むものはありませんでした（すべて取り込み済みです）」。おまけ: 1 のあとに線を 1 本消してから（全消去せずに）取り込む → その線は **戻らない**（墓標が勝つ。SUPPORT の FAQ の文どおり） |
| 3 | 月ページ（メモ欄に手書きあり）で「このページを PDF」→「ファイル」に保存 → 開く | 1 ページ。題名「2026年10月」、曜日行、6 行の格子＋メモ欄、予定のバーとチップ、祝日名、手書きが画面と同じ位置。拡大しても罫線と文字は鮮明（ベクタ）、手書きは鮮明（**通常 2x**。行が大きく伸びた月では少し粗くなりうる。0-5） |
| 4 | 週・日・年ページでも PDF（週・日は **今日を含む**ページで） | 週: 日付行（曜日＋日、祝日）、終日帯の予定（画面と同じ横位置）、時間軸と箱、手書き。日: 日付の題名と終日帯（レーン間隔 24）。年: 月名行と 31 行。**現在時刻の赤線は入っていない**（0-13。「今日」の列の色は画面どおり）。ファイル名が §1.5 の形 |
| 5 | 閲覧専用（サンドボックスで期限切れ、または「あとで」）で 1〜4 | 全部できる（ペイウォール・トーストが出ない）。設定 › 購入 の脚注に「手書きの書き出し」 |
| 6 | iPhone で 1 と 3 | シートが下半分、JSON を AirDrop で Mac へ、PDF を「ファイルに保存」。共有シートが下から出る |
| 7 | 手書きの無い iPad（または全部消した後）で JSON | 赤字「書き出す手書きがありません」→ 閉じる → 同じ文のトースト |
| 8 | 書き出し中に iPad をスリープ → 戻す | 続きが進んで「書き出しました」（数秒の作業） |
| 9 | 共有シートで「キャンセル」→ もう一度「共有…」 | 同じファイルをもう一度共有できる |
| 10 | M5.md §2.3 の未実施の行 | M5.md に結果を書く |

7. App Store Connect: §6.1 の 1〜12 が済み、提出の確認画面で止まっている（版 1.0 ＋ 2 商品）。**サブタイトルが入っている**（§6.1 の 1。第 2 版）。説明の全文が §4.3 と docs/M6.md に写してある。本人が 3〜6 と §6.2 の 5 を見て **「審査へ提出」を押すか決める**。
8. docs/M6.md・README・DESIGN の注記が更新されている: §2.8 データ行の M5 の注記を実装の説明に（「JSON のほか PDF・画像」→「データファイル（JSON）と PDF」。画像は書かない）、§7.4 の「（提供後。…）」を外す、§9 の M6 行に「済」、§10 の表に年齢区分・App Privacy・審査メモの「入力済み（日付）」、**§10 の「2.1 審査用アカウント」行（:852）の「短い操作動画の URL を添える」を「動画は付けない（M6-12）。差し戻されたら CI の写真を添付」に直し、審査メモの最終文（§4.3）に合わせる**（第 2 版。M6.md と DESIGN が食い違わないため）、**§3.9 の末尾に「書き出しファイル `tegaki-app-export` v1」の小節**（§1.1 の表と例。SUPPORT の FAQ「形式は設計書と README に載せています」の受け皿）、README の「まだ無いもの」（:58）から書き出しを外し、:52-55 の設定の行に「手書きを書き出す」と形式名を足す。

## 9. 本人の決定・未決

| # | 内容 | 既定（返事が無ければこうする） |
| --- | --- | --- |
| M6-1 | PDF の範囲（この年の 12 か月をまとめる） | **入れない**（1 ページ = 1 PDF。12 か月は 12 回。安い実装ではあるが、年ページの PDF がその代わりになる。要望が出たら 1.1） |
| M6-2 | iPhone 17 Pro Max（6.9 インチ）の写真 | **CI で撮る**（第 2 版で改訂。Apple のページが「Face ID（大）」行で「大 DI が無ければ必須」と言い矛盾しているため。build.yml に 1 機種 ≈ 2 分。0-15）。**Connect に上げるかは 1.0 の画面の表示で決める**: 6.9 インチ枠が必須表示なら上げる、任意なら上げない（§6.1 の 4） |
| M6-3 | 月 PDF のメモ欄 | **メモに手書きがあれば含める、無ければ 6 行だけ**（0-3） |
| M6-4 | 取り込みの行の名前「Web 版の手書きを取り込む」 | **変えない**（W のテスト・SUPPORT・README が参照。復元の説明は脚注と FAQ）。変えるなら「手書きを取り込む（Web 版・このアプリ）」と W のテスト (5) を同時に |
| M6-5 | 取り込み（復元）を閲覧専用で許すか | **許さない**（M5-15 のまま。規約第 5 条 5 項の列挙と一致。許すなら `GatedAction.webImport` を許す側に移し 11 / 8 → 10 / 9 とテスト・規約を同時に） |
| M6-6 | JSON に墓標だけのページを入れる | **入れる**（復元で消した線を消したままにする。読めるが無害） |
| M6-7 | 共有シートの出し方 | **完成画面の〔共有…〕（`ShareLink`）**。自動で `UIActivityViewController` を出すなら Representable に `popoverPresentationController.sourceView` が要る |
| M6-8 | 11 インチの写真を Connect に上げるか | **上げない**（13 インチが縮小される。上げるなら `store/ipad11/01-04`） |
| M6-9 | 写真の枠・文字入れ | **しない**（素の写真。1.1 以降に検討） |
| M6-10 | キーワードの語 | §4.3 の 17 語。Connect が 2 字の語を拒んだら「ペン,メモ,予定,手帳,同期,祝日,日記,週間,月間,年間」を「ペン入力,手書きメモ,予定表,手帳アプリ,同期,祝日,日記帳,週間予定,月間予定,年間予定」に替える |
| M6-11 | 副カテゴリ | **ライフスタイル**（代案: ビジネス） |
| M6-12 | 審査メモへの操作動画 | **付けない**（文章で足りる。差し戻されたら CI の写真を添付） |
| M6-13 | リリースの方式 | **手動**（審査通過の通知を本人が見てから公開日を決める） |
| M6-14 | 著作権表記 | **「2026 池田 雅高」** |
| M6-15 | 電話番号 | **本人項目**（`+81` 形式。無いと提出できない） |
| M6-16 | PRIVACY §4 の 1 文 | **足す**（D6。足さないなら W も privacy.html を触らない） |
| M6-17 | 整形 JSON の形 | **数値配列 1 行・object 1 鍵 1 行・2 スペース**（§1.3）。圧縮形は不変 |
| M6-18 | KitChecks の閾値 | **K の実数 − 50** |
| M6-19 | Web の merge の時機 | **TestFlight 1.0 が出た後**（§5.2） |
| M6-20 | PDF の見出し帯 | **描く**（0-9。無いと週・日の PDF に日付が無い）。文字は system font、大きさは §1.4 |
| M6-21 | 書き出し中の背面移行 | **続ける**（数秒。`beginBackgroundTask` は使わない） |
| M6-22 | 法律の専門家の確認 | 本人の任意（M5-5 のまま） |
| M6-23 | PDF の「今日」の色（週の `todayColumn`・日の `isToday`）（第 2 版） | **画面のまま残す**（現在時刻の赤線だけ外す。0-13。両方外すなら `stripNowLine` を `stripTimeMarks` にして `todayColumn = nil` / `isToday = false` も複製時に落とす。テストの式は同じ） |
| M6-24 | `store/ipad13/06-settings.jpg` の扱い（第 2 版） | **Connect には上げない**（掲載の最後に置く価値が低い）。審査メモの添付（任意）に回すか捨てる。上げるなら 6 枚目 |
| M6-25 | サブタイトルの退き先（第 2 版） | Connect が「Apple Pencil」を含む語を拒んだら **「予定の上にそのまま手書きできる手帳」**（17 字）。拒まれなければ §4.3 の 27 字 |
| M6-26 | 取り込みファイルの大きさの目安（第 2 版） | SUPPORT の FAQ に **「おおむね 200 MB（手書き数万本）まで」**。根拠: ページ単位の解析で常駐は ファイル ≈ 1 ＋ `[InkPage]` ≈ 0.5 ＋ 1 ページの木、iPad の 1 プロセスの目安 1〜2 GB の中に収まる。X の実測（§7.2）で大きく違えば数字を直す |
| M6-27 | 説明の全文（第 2 版） | **リードが §6.1 の 5 の前に Connect から写す**（§4.3「説明の全文」と docs/M6.md）。本人の返事は要らない |

### 9.1 第 2 版で採った指摘・採らなかった指摘（レビュー 3 視点）

採った指摘（全部の blocker・major と、根拠のある minor）は本文に「第 2 版」と印を付けて反映した。一覧:

| 視点 | 指摘 | 反映先 |
| --- | --- | --- |
| codebase | `testImportFailureTexts` は存在せず `importFailureText` は private | §1.2・§7.2: 新規のテスト、`importFailureText` を internal に |
| codebase | `readOnlyFooter` は private | §3.1・§7.2: `purchaseFooter(.readOnly(…))` 経由で見る。`exportFooter` は internal |
| codebase / owner-legal | `isAppExport` に使い道が無い | 0-12・§1.2・§3.6・§7.2・§8-6 の 2: 完成文「手書きを取り込みました（…）」 |
| codebase | 日ページのレーン間隔は 24 | §1.4: `laneStep(.week) = 25` / `laneStep(.day) = 24`、テストの式も kind ごと |
| codebase | 終日帯のバーの x は `bar.minX/maxX` | §1.4 |
| codebase | `SyncEngine.init` は `stateStore:` 必須 | §7.2 |
| codebase | `makePaper` は private | §7.2: `PaperContent` を自前で組む |
| codebase | 12M 画素の約束は常には成り立たない | 0-5・§1.4・§2.2・§8-6 の 3: 「鮮明（通常 2x）」 |
| codebase | `iPad Air 13-inch` に落ちると 2048×2732 | §4.1・§7.4: 受理値の集合で照合 |
| codebase | `onExport` の位置 | §3.1: `scrollToPurchaseOnAppear` の後（最後） |
| codebase | `WebImport.parse(_ data:)` は :130 | §1.2 |
| codebase | `Task.detached` の中で `self` に触ると隔離違反 | §2.2: 値を取り出して渡す |
| export-assets | 6.9 インチ: Apple のページが矛盾 | D3・0-15・§4.1・§4.2・§6.1 の 4・§7.4・§7.5・§8・M6-2: CI で撮る、上げるかは Connect の表示 |
| export-assets | 取り込み側が JSON の木を 3 つ同時に持つ | 0-11・§1.2（`topLevelMembers` / `arrayElements` / `parsePage`）・§7.1・§7.2（`testLargeExportImportsPageByPage`）・SUPPORT の目安（M6-26） |
| export-assets | 閉じたときの cleanUp が共有中のファイルを消しうる | 0-14・§1.5・§3.3: 各書き出しの最初だけ |
| export-assets | 現在時刻の線が PDF に焼き付く | 0-13・§1.4・§7.2・§8-6 の 4: `stripNowLine` |
| export-assets | `Task.yield()` 1 回ではスピナーが出ない | §2.2・§3.3: 50 ms 待つ |
| export-assets / owner-legal | 「取り込みは購読中」「消した線は戻らない」が利用者向け文面に無い | §1.1・§3.1・§3.2・§3.6・§5.1（FAQ） |
| export-assets | 審査メモが日本語だけ | §4.3: 英語の要約 8 行 |
| export-assets / owner-legal | DESIGN §10 の 2.1 行が M6-12 と食い違う | §8-8 |
| export-assets | iPhone の 1 枚目が週、設定の写真の価値 | §4.2・§8-5・M6-24: 番号は仮、設定は上げない |
| owner-legal | 第 3 条 4 項の「ほかの形式は順次提供」が新しい約束 | §5.1: 削る。grep は全部 0、W のテスト (8) に「順次提供」 |
| owner-legal | JSON はアプリが無いと読めない | §5.1（FAQ「取り込み直すためのもの。残すなら PDF」）・§8-8（DESIGN §3.9 に形式） |
| owner-legal | サブタイトルを打つ手順が無い | §6.1 の 1・§8-7・M6-25（退き先） |
| owner-legal | 「予定なし・iCloud なし」で動くことがメモに無い | §4.3 |
| owner-legal | 輸出コンプライアンスの退き先 | §4.6・§6.1 の 7 |
| owner-legal | 字数（70 / 127） | §4.3（差し替え案 86 字も） |
| owner-legal | 説明の全文がリポジトリに無い | §4.3「説明の全文」・M6-27 |
| owner-legal | 「この iPad」が iPhone でも出る | D2・§3.1・§3.2・§3.6・§5.1: 新しい文言は「この端末」 |
| owner-legal | §6.1 の 10 の前提、本人の目視 | §6.1 の 10・§6.2 の 5 |
| owner-legal | `dev` が共有先に渡る | §1.1（残す理由）・§5.1（PRIVACY の 1 文） |

採らなかった・形を変えた指摘と理由:

| 指摘 | 決着 | 理由 |
| --- | --- | --- |
| 審査メモの「設定 › 入力 › 「指でも書く」」は欄名の根拠が無い（owner-legal） | **文言はそのまま**、根拠を §4.3 に明記 | 実物の欄名が「入力」（`Views/SettingsScreen.swift:305-307` の `Toggle("指でも書く", …)` と `header: { Text("入力") }`）。指摘の「欄名が無いかもしれない」は当たらなかったが、根拠の無さは直した |
| 取り込みを「ページを 1 枚ずつ呼び出し側へ逐次渡す」形に（export-assets） | **`[InkPage]` を返す形のまま**、JSON の木だけページ単位に | `SyncEngine.importPages` は `[InkPage]` を受け、`Sync/*` は範囲外。常駐の支配項（JSON の木 × 2）は無くなるので目的は果たす。`Data` 全体は残る（ファイル 1 つ分） |
| 大きなファイルのテストを「20 ページ × 20,000 本 × 50 点（≈ 100 MB）」で（export-assets） | **8 ページ × 1,000 本 × 50 点（≈ 25 MB）**、増分 < 8 倍 | CI の 1 テストに 100 MB 超の生成と解析は重い（数分）。25 MB でもページ単位（≈ 3 倍）と全体の木（≈ 20 倍）は判別できる |
| 現在時刻の線と一緒に「今日」の色も外す（export-assets の指摘文に含意） | **線だけ外す**（M6-23） | 指摘の修正案は `nowLine = nil` だけ。「今日」の色は紙の一部で画面と同じ、資料としても「書いた日」が分かる利点がある。外すなら M6-23 |
| `isAppExport` を Outcome から外す（codebase の代案） | **使う** | 復元の完成文が「Web 版の…」のままだと利用者に伝わらない（owner-legal も同じ指摘） |
| 閉じたときの cleanUp を「次回起動時」にも（export-assets の代案） | **各書き出しの最初だけ** | 起動時の処理を増やさない。tmp は OS が掃除する |
| PRIVACY の 1 文を足さずに `dev` の理由だけ書く（owner-legal の代案） | **両方** | 落とせない理由（往復の `==`、`compareStrokes`）は §1.1 に、共有先に渡る事実は PRIVACY に |
| SUPPORT の FAQ から設計書 §3.9 にリンク（owner-legal） | **リンクしない**（文で触れるだけ） | W のテスト (6) が `.md"` へのリンクを禁じ、DESIGN に HTML 版は無い。形式は DESIGN §3.9 と README に載せる（§8-8） |

統合の順番: **K**（`JSONValue.serialized(pretty:)` → `AppExport`（`parsePage` を含む）→ `WebImport.parse(json:)` → `InkImport`（走査を含む）→ KitChecks の節 → 2 つのテスト → 実数 N を docs/M6.md に）→ **X**（`PDFPageRenderer`（`stripNowLine`・`laneStep(kind)`）→ `ExportBuilder` → `ExportBuilderTests`（大きなファイルの実測を docs/M6.md に）。K にだけ依存。この時点で `ExportBuilder` が使える）と **L**（3 文書）を並行 → **U**（`ScreenshotMode.export` → `ExportSheet` → `SettingsScreen` の行・脚注・引数 → `WebImportSheet` の文言と完成文の出し分け → `CalendarRootScreen` の接続・`runImport` の 2 形式化・`importFailureText` を internal に → テスト）→ **W**（L の文書が固まってから。`m6-legal`。`npm test` 緑）→ **C**（project.yml 1.0、build.yml、README、DESIGN の注記、docs/M6.md、CI の写真と `store/` の確認）→ **リード**（main に merge → testflight.yml → Connect に 1.0 (N) → Web の merge と URL の確認 → §6.1 の 1〜12 → 本人へ報告）→ **本人**（§6.2、§8-6、提出の判断）。

本人がやること（Claude が代行できない）: (1) 電話番号（M6-15）。(2) §9 の返事（無ければ既定）。(3) CI の写真（§8-5）を見て export シートと store/ の見え方を判断する。(4) TestFlight 1.0 で §8-6 の 1〜10（書き出しの往復・PDF・iPhone の共有・M5 の残り）。(5) 「審査へ提出」。
