# M4 実装契約（iCloud 同期、Web 版からの手書きの引っ越し）

この文書は M4 の各担当が同時に作業するための **約束事**（公開 API・データ形状・CloudKit のスキーマ・日本語の文言・ファイル所有）です。[M3B_CONTRACT.md](M3B_CONTRACT.md) の続きで、M2・M3a・M3b で決めたことはそのまま生きています（ここに書いていない API は変えません）。
設計の根拠は [DESIGN.md](DESIGN.md)（§2.8 設定画面、§2.10 初回案内、§3.4 線の id と所属マス、§3.9 保存形式、§3.10 性能、§5 同期、§6 Web 版からの移行、§8 技術構成、§9 段階計画、§10 審査）。ここに無いことは DESIGN.md に従い、DESIGN.md にも無ければ Web 版（`../tegaki-calendar/docs/SPEC.md` §2 データ形状、§3 ページ幾何、§4 B `js/ink/model.js`・D `js/data/ink-store.js`・F2、`js/google/drive.js`、`js/ui/settings.js`、`js/main.js` の settingsFlow）の流儀に合わせます。Web 版の `ink-store.js`（dirty 一覧・1.5 秒デバウンス・15 秒〜5 分の再試行・「端末内が主」）の **動き方が正** です。

本人の決定（この契約で既定にしてあるもの。再検討しない）:
- 同期は **CloudKit のプライベートデータベース**（DESIGN §5）。コンテナ `iCloud.com.syfan0.tegakicalendar`（B-5）、専用ゾーン `tegaki`、1 ページ = 1 レコード `InkPage`、本文は常に CKAsset（LZFSE 圧縮の InkPage JSON）、保存は `.ifServerRecordUnchanged` で衝突したら merge して再保存（最大 3 回）、差分取得は変更トークン、ページを開いたときはそのページだけ個別取得、サイレントプッシュ、1.5 秒デバウンス、再試行は 15 秒から倍々で 5 分まで。
- **端末内ファイルが常に主**（DESIGN §5.5）。iCloud は「ほかの端末へ届ける経路」と「バックアップ」。
- CloudKit に触る所は **1 つのプロトコル `CloudDatabase`** に閉じ込め、本物の `CKDatabase` 用と **メモリ上の偽物** を用意する。同期エンジンは偽物で CI のシミュレータ上で検査する（iCloud アカウント不要）。純粋な部分（merge・dirty の帳簿・再試行の間隔・状態ファイルの JSON・Web 版の変換）は TegakiKit。
- Web 版からの移行は DESIGN §6 のとおり（Web 版に「書き出し」、アプリに「取り込む」、変換は純粋関数、同じファイルを二度取り込んでも二重にならない）。
- **スキーマは本人が CloudKit Console で手で作って Production に配備する**（この Mac に Xcode が無く、TestFlight のビルドは Production 環境を使うため）。ゾーンはアプリが起動時に作る。
- 「この iPad の手書きを全て消す」は **iCloud のレコードも全て消す**（DESIGN §5.5）。
- 版: アプリ `MARKETING_VERSION` **0.5.0**、Web 版 **1.0.6**。

**M4 の範囲**: (1) 同期エンジンと CloudKit の接続、(2) 保存層の変更（dirty 一覧・状態ファイル・開いているページへの反映。`InkLedger.reload` の修正を含む）、(3) ヘッダーの同期の状態と設定の「同期」「データ」、(4) Web 版の「手書きを書き出す（iPad アプリ用）」と、アプリの「Web 版の手書きを取り込む」、(5) 初回案内の 4 枚目、(6) エンタイトルメント・Background Modes・プライバシーマニフェスト・CI、(7) スクリーンショットのシート 2 枚。
**範囲外**（触らない）: 課金・ペイウォール・閲覧専用（M5。`Meta.trialStartedAt` は **項目だけ** 決める）、アプリからの「手書きを書き出す」（JSON・PDF・画像。M5 以降）、設定の同期（表示するカレンダー等は端末ごと）、墓標の掃除、キャンバスの使い回し（DESIGN §3.10）、Web 版の日曜始まりページ（1.0.4 で月曜ページに写し済み。書き出しに含めない）。

## 0. 構成とファイル所有

```
TegakiKit/                                              担当 K（TegakiKit だけを触る）
  Sources/InkModel/WebImport.swift                      新規: tegaki-web-export v1 の解析と InkPage への変換（§3.1〜3.3）
  Sources/InkModel/SyncState.swift                      新規: 状態ファイルの型と JSON（§3.4）
  Sources/InkModel/SyncBackoff.swift                    新規: デバウンス・再試行の間隔の純粋な計算（§3.5）
  Sources/InkModel/InkPage.swift                        変更: contentDiffers(from:) / liveStrokeIds（§3.6）。merge は変更なし
  Sources/KitChecks/main.swift                          変更: §8.1 の 3 節を追加
  Tests/InkModelTests/WebImportTests.swift              新規（§8.1）
  Tests/InkModelTests/SyncStateTests.swift              新規（§8.1。SyncBackoff も）
  Package.swift                                         変更なし
Sources/TegakiCalendar/
  Sync/CloudDatabase.swift                              担当 S   新規: protocol CloudDatabase、CloudRecord、CloudValue、CloudZoneChanges、CloudAccountStatus、CloudError（§4.1）
  Sync/CloudKitDatabase.swift                           担当 S   新規: CKDatabase の adapter（§4.2）。CloudKit を import するのはこのファイルだけ
  Sync/InMemoryCloudDatabase.swift                      担当 S   新規: 偽物（§4.6）。テストとスクリーンショットモードと XCTest のホストが使う
  Sync/InkPageRecord.swift                              担当 S   新規: InkPage ⇄ CloudRecord、Meta レコード（§4.3）
  Sync/SyncStatus.swift                                 担当 S   新規: SyncStatus / SyncSnapshot / HeaderSync / AccountChangeChoice / ImportOutcome と画面の文言（§4.4、§6.1）
  Sync/SyncEngine.swift                                 担当 S   新規: エンジン（§4.4〜4.5）
  Persistence/InkPageStore.swift                        担当 S   変更: allPageIds()、stateFileURL（§5.1）
  Persistence/SyncStateStore.swift                      担当 S   新規: state.json の原子的な読み書き（§5.2）
  Persistence/AppSettings.swift                         担当 S   変更なし（同期の状態は state.json に持つ。UserDefaults には足さない）
  Ink/InkLedger.swift                                   担当 U   変更: reload(page:keepHistory:) が指紋表を消さない（§5.4）
  Ink/*（InkLedger 以外）、Calendar/*、Paper/*           変更なし（担当なし。InkCanvasView の外からの page の reload は M3b のまま使う）
  Views/CalendarRootScreen.swift                        担当 U   変更: SyncEngine の接続、遠隔更新の反映、取り込みの流れ、アカウント切替の問い合わせ、全消去（§5.4、§6）
  Views/PageHeaderView.swift                            担当 U   変更: 同期の状態（☁＋文言）（§6.1）
  Views/SettingsScreen.swift                            担当 U   変更: 「同期」「データ」（§6.2）
  Views/WebImportSheet.swift                            担当 U   新規: ファイル選択（UIDocumentPickerViewController の包み）、進捗、結果（§6.3）
  Views/AccountChangeDialog.swift                       担当 U   新規: 「別の iCloud アカウントです」（§6.4）
  Views/OnboardingView.swift                            担当 U   変更: 4 枚目「iCloud と手書きの保存」（§6.5）
  Support/ScreenshotMode.swift                          担当 U   変更: --screenshot-sheet sync|import（§6.6）
  Support/AppDelegate.swift                             担当 U   新規: UIApplicationDelegate（プッシュの登録と受け口、SyncEngine.shared.start()）（§6.7）
  App.swift                                             担当 U   変更: @UIApplicationDelegateAdaptor の追加だけ（§6.7）
  PrivacyInfo.xcprivacy                                 担当 C   新規: プライバシーマニフェスト（§8.4）
Tests/TegakiCalendarTests/SyncEngineTests.swift         担当 S   新規（§8.2）
Tests/TegakiCalendarTests/TestSleeper.swift             担当 S   新規: テスト用の sleep（§8.2）
Tests/TegakiCalendarTests/InkPageRecordTests.swift      担当 S   新規（§8.2）
Tests/TegakiCalendarTests/SyncStateStoreTests.swift     担当 S   新規（§8.2）
Tests/TegakiCalendarTests/CloudKitDatabaseMapTests.swift 担当 S  新規: CKError → CloudError の写像（§8.2）
Tests/TegakiCalendarTests/ScreenshotModeTests.swift     担当 U   変更（§8.3）
Tests/TegakiCalendarTests/InkLedgerTests.swift          担当 U   変更: reload の後の差分（§8.3）
Support/TegakiCalendar.entitlements                     担当 C   新規（§8.4）
project.yml / .github/workflows/build.yml / docs/M4.md / README.md   担当 C（§8.4）
../tegaki-calendar/（Web 版リポジトリ）                 担当 W（Web 版だけを触る。§7）
  js/data/ink-export.js                                 新規: 書き出しの純粋な部分（全ファイルの一覧 → ページごとに merge → JSON）
  js/google/drive.js                                    変更: listAllInkFiles()
  js/ui/settings.js                                     変更: 「データ」の節に「手書きを書き出す（iPad アプリ用）」
  js/main.js                                            変更: action 'exportInk' → exportInkFlow()
  js/config.js / sw.js / package.json                   1.0.6。sw.js の APP_FILES に js/data/ink-export.js
  tests/ink-export.test.mjs                             新規。tests/drive.test.mjs・ui-logic.test.mjs・app-shell.test.mjs は変更
  tests/fixtures/tegaki-web-export-sample.json          新規（§1.4 の見本 1。parseExport の入力・collectAll の素材）
  tests/fixtures/tegaki-web-export-expected.json        新規（§1.4 の見本 2。buildExport の期待値）
  docs/SPEC.md                                          変更: §1 の所有と §4 D に ink-export を足す
```

依存の向き: `TegakiCalendar` → `TegakiKit`（Layout, Holidays, InkModel）。`Sync/*` は `InkModel` と `Persistence/*` に依存し、`Views/*` には依存しない。`Sync/*` は `Support/ScreenshotMode.swift` の **既存 API**（`current`・`isActive`・`Config.today`。M3b のまま）を読んでよい（U が足す `Sheet` の値は S に影響しない）。`Views/*` と `Support/*` は `Sync/SyncEngine.swift`・`SyncStatus.swift` の公開 API だけを使う。
**担当 S は `Views/*`・`Support/*`・`Ink/*`・`App.swift` を触らない。担当 U は `Sync/*`・`Persistence/*` を触らない。担当 K は `TegakiKit/` だけ。担当 W は Web 版リポジトリだけ。担当 C は project.yml・entitlements・PrivacyInfo.xcprivacy・build.yml・docs/M4.md・README.md だけ。** S と U の接点は次の 7 つだけで、いずれもこの契約の形に固定します。

1. `SyncEngine.shared`・`SyncEngine.usesCloudKit`（§4.4）と `SyncEngine.screenshotDemo(now:)`（§6.6）: U は作らず、受け取るだけ。
2. `SyncEngine` の `load` / `save` / `pageOpened` / `onRemoteUpdate`（§5.3）: CalendarRootScreen の保存の経路を `InkPageStore` の直接呼び出しからこれに置き換える。
3. `SyncSnapshot`・`SyncStatus`・`HeaderSync` の文言（§6.1）: U は読んで出すだけ。
4. `syncNow()` / `eraseEverything()` / `importPages(_:progress:)` / `resolveAccountChange(_:)`（§4.4）: U が呼ぶ命令。
5. `WebImport.parse` / `WebImport.convert`（§3.1〜3.3、K）: U がファイルを読んで呼ぶ純粋関数。
6. `handleRemoteNotification(_:)` / `applicationDidBecomeActive()` / `start()`（§4.4）: U の AppDelegate / scenePhase から呼ぶ。
7. `ImportOutcome`（§4.4。メンバーワイズ init `(pagesChanged:strokesAdded:pagesSeen:)`）: U の `ScreenshotMode.importDemoOutcome` と `WebImportSheet` が使う。

K と S の接点は `SyncState`・`SeenRecord`・`SyncBackoff`・`InkPage.merge`（K）だけ。K と W の接点は **tegaki-web-export v1 の JSON**（§1.3）だけで、§1.4 の 2 つの見本（sample・expected）を両方のテストに同じ内容で置きます。

## 1. データ形式

### 1.1 状態ファイル `state.json`（端末内。担当 K が型、担当 S が読み書き）

置き場所は `Application Support/TegakiCalendar/ink/state.json`（ページのファイルと同じ場所。DESIGN §5.5）。`InkPageStore.removeAll()` は `*.json.lzfse` と `*.bak` しか消さないのでこのファイルは残ります（全消去のときはエンジンが明示的に書き換える。§5.2 で退避した `state.json.bak` は `.bak` なので全消去で消えるが、害は無い）。書き込みは一時ファイルに書いてから置き換え（`.atomic`）。

```json
{ "v": 1, "dirty": ["m1-2026-10", "w-2026-10-05"],
  "zoneToken": "YnBsaXN0MDDUAQID…", "zoneReady": true, "subscriptionReady": true,
  "account": "_0123456789abcdef0123456789abcdef", "pendingAccount": null, "pendingCloudErase": false,
  "seen": { "m1-2026-10": { "tag": "jx3pq", "sys": "YnBsaXN0MDDUAQID…" } },
  "lastSyncAt": 1760150500000, "webImportedAt": 1760150000000 }
```

| 項目 | 型 | 意味 |
| --- | --- | --- |
| `v` | Int | 形式の版。1。知らない版・知らない項目は捨てずに書き戻す（InkPage と同じ流儀） |
| `dirty` | [String] | まだ iCloud に送っていない pageId。積んだ順、重複なし |
| `zoneToken` | String? | `CKServerChangeToken` を `NSKeyedArchiver`（secure coding）で Data にして base64。無ければ null（次の取得は全件） |
| `zoneReady` / `subscriptionReady` | Bool | ゾーン `tegaki` / 購読 `tegaki-zone-changes` を作れたか。false なら次の同期で作り直す |
| `account` | String? | 最初に同期した iCloud アカウントの `userRecordID.recordName`。端末内データの持ち主（DESIGN §5.4） |
| `pendingAccount` | String? | いまサインインしているのが別のアカウントで、問い合わせ中ならその recordName |
| `pendingCloudErase` | Bool | 全消去で iCloud 側の削除が終わっていない（回線が無かった）。次の同期は取得より先に削除をやり直す |
| `seen` | {pageId: {tag, sys}} | 最後に取得または保存したサーバー版。`tag` = `CKRecord.recordChangeTag`、`sys` = `encodeSystemFields` の Data の base64（再起動後も `.ifServerRecordUnchanged` で保存できるように） |
| `lastSyncAt` | Int? | 最後に成功した同期（取得または送信）の時刻（ms） |
| `webImportedAt` | Int? | `Meta.webImportedAt` の写し（表示用。無ければ null） |

### 1.2 `Meta` レコード（iCloud。1 件だけ、recordName `"meta"`）

| フィールド | 型 | 書くとき |
| --- | --- | --- |
| `schema` | Int(64) | 1。作るときに必ず |
| `webImportedAt` | Date/Time（任意） | 「Web 版の手書きを取り込む」が成功した時刻（最新で上書き） |
| `trialStartedAt` | Date/Time（任意） | **M5 が書く**（無料試用の開始）。M4 は読み書きしない。項目だけ用意する |
| `app` | String | 最後に書いたアプリ `"ios/0.5.0/1"`（§4.3） |

Meta の保存も `.ifServerRecordUnchanged` で、衝突したら **サーバー版を読み直してから項目ごとに max**（日付は遅い方）で再保存。無ければ作る。

### 1.3 `tegaki-web-export` v1（Web 版が書き出し、アプリが読む JSON）

```json
{ "format": "tegaki-web-export",
  "v": 1,
  "exportedAt": "2026-10-14T09:41:00.000+09:00",
  "app": "web/1.0.6",
  "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "m1-2026-10",
      "strokes": { "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5,
                           "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000000000 } },
      "deleted": {},
      "updatedAt": 1760000000000 }
  ] }
```

| 項目 | 型 | 規則 |
| --- | --- | --- |
| `format` | String | 必ず `"tegaki-web-export"`。違えば「Web 版の書き出しではない」 |
| `v` | Int | 1。2 以上は「新しい形式」として拒む（§3.1） |
| `exportedAt` | String | ISO 8601（`Date.prototype.toISOString` でなく **端末のローカル時刻＋オフセット**。表示用で、変換には使わない） |
| `app` | String | `"web/<APP_VERSION>"` |
| `includesDemo` | Bool | お試しモードの手書きを含めたか（表示用） |
| `pages` | [PageDoc] | Web 版の `PageDoc`（SPEC §2）そのもの（`serializePage` と同じ形: `strokes` は id 順、`deleted` は merge 後の墓標を id 順にそのまま）。**生きている線だけ**（墓標は取り込み側で引き継ぐ: Web で消した線は再取り込みでも iPad に戻らない）。線の無いページは入れない。pageId は `d-YYYY-MM-DD` / `w-YYYY-MM-DD`（月曜）/ `m1-YYYY-MM` / `y-YYYY` だけ（`m-YYYY-MM`・日曜の `w-` は入れない）。pageId 順 |
| `pages[].strokes[id]` | Stroke | `id`（文字列 1〜128 字）、`tool` `"pen"` \| `"highlighter"`、`color` `#rrggbb`、`size`（lu。細 2 / 中 3.5 / 太 6、蛍光ペン 18）、`pts` `[x, y, p, …]`（3 個ずつ。x, y は紙座標の lu 0.1 丸め、p は筆圧 0〜1 の 0.01 丸め）、`t`（ms） |

### 1.4 見本（2 つ。Web 版 `tests/fixtures/` と、K の KitChecks・XCTest に **同じ内容** を置く）

**見本 1 `tegaki-web-export-sample.json`**（6 ページ。K の `parse` の入力、W の `parseExport` の入力と `collectAll` の素材。わざと整列していない・対象外のページを含む）:

```json
{ "format": "tegaki-web-export", "v": 1, "exportedAt": "2026-10-14T09:41:00.000+09:00", "app": "web/1.0.6", "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "m1-2026-10", "updatedAt": 1760000002000, "deleted": {},
      "strokes": {
        "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000001000 },
        "b2": { "id": "b2", "tool": "highlighter", "color": "#fde047", "size": 18, "pts": [100, 1100, 0.5, 300, 1100, 0.5], "t": 1760000002000 } } },
    { "v": 1, "pageId": "w-2026-10-05", "updatedAt": 1760000003000, "deleted": {},
      "strokes": { "c3": { "id": "c3", "tool": "pen", "color": "#2563eb", "size": 6, "pts": [700, 720, 0.5, 760, 840, 0.5], "t": 1760000003000 } } },
    { "v": 1, "pageId": "d-2026-10-07", "updatedAt": 1760000004000, "deleted": { "zz": 1760000000500 },
      "strokes": { "d4": { "id": "d4", "tool": "pen", "color": "#1f2937", "size": 2, "pts": [100, 900, 1, 300, 1050, 1], "t": 1760000004000 } } },
    { "v": 1, "pageId": "y-2026", "updatedAt": 1760000005000, "deleted": {},
      "strokes": { "e5": { "id": "e5", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1000, 540, 0.6, 1050, 560, 0.6], "t": 1760000005000 } } },
    { "v": 1, "pageId": "m-2026-09", "updatedAt": 1760000006000, "deleted": {},
      "strokes": { "f6": { "id": "f6", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [10, 10, 0.5, 20, 20, 0.5], "t": 1760000006000 } } },
    { "v": 1, "pageId": "d-2026-10-08", "updatedAt": 0, "deleted": {}, "strokes": {} }
  ] }
```

**見本 2 `tegaki-web-export-expected.json`**（4 ページ。W の `buildExport(見本 1 の pages, app: 'web/1.0.6', exportedAt: 固定)` がこれと **同じ object** になる（`assert.deepEqual`。鍵の順は問わない）。`m-2026-09` と空ページは落ち、`pages` は pageId の文字列順 `d-` → `m1-` → `w-` → `y-`、`strokes`・`deleted` は id 順、墓標 `zz` は保たれる）:

```json
{ "format": "tegaki-web-export", "v": 1, "exportedAt": "2026-10-14T09:41:00.000+09:00", "app": "web/1.0.6", "includesDemo": false,
  "pages": [
    { "v": 1, "pageId": "d-2026-10-07", "updatedAt": 1760000004000, "deleted": { "zz": 1760000000500 },
      "strokes": { "d4": { "id": "d4", "tool": "pen", "color": "#1f2937", "size": 2, "pts": [100, 900, 1, 300, 1050, 1], "t": 1760000004000 } } },
    { "v": 1, "pageId": "m1-2026-10", "updatedAt": 1760000002000, "deleted": {},
      "strokes": {
        "a1": { "id": "a1", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [410, 360, 0.4, 450, 380, 0.6, 490, 370, 0.8], "t": 1760000001000 },
        "b2": { "id": "b2", "tool": "highlighter", "color": "#fde047", "size": 18, "pts": [100, 1100, 0.5, 300, 1100, 0.5], "t": 1760000002000 } } },
    { "v": 1, "pageId": "w-2026-10-05", "updatedAt": 1760000003000, "deleted": {},
      "strokes": { "c3": { "id": "c3", "tool": "pen", "color": "#2563eb", "size": 6, "pts": [700, 720, 0.5, 760, 840, 0.5], "t": 1760000003000 } } },
    { "v": 1, "pageId": "y-2026", "updatedAt": 1760000005000, "deleted": {},
      "strokes": { "e5": { "id": "e5", "tool": "pen", "color": "#1f2937", "size": 3.5, "pts": [1000, 540, 0.6, 1050, 560, 0.6], "t": 1760000005000 } } }
  ] }
```

変換の期待値（§3.2・§3.3 の規則を見本 1 に当てたもの。K の検査と W の検査の両方がこの数字を使う）:

| 線 | 所属マス | 相対座標（x, y） | 各点の太さ sizeW = sizeH | その他 |
| --- | --- | --- | --- | --- |
| a1（月） | `2026-10-14`（中心 (450, 370) → 行 2 列 2。グリッドは 9/28 始まり） | (10, 10), (50, 30), (90, 20) | 2.66, 3.29, 3.92（3.5 × (0.4 + 0.9p)） | force 0.4/0.6/0.8、dtMs 0/8/16、tool pen、dev `"web"` |
| b2（月のメモ欄） | `memo`（中心 y 1100 ≥ 1050） | (100, 50), (300, 50) | 18, 18 | tool marker、color `#fde047` |
| c3（週） | `grid` | (700, 720), (760, 840) | 5.1, 5.1 | color `#2563eb` |
| d4（日） | `grid` | (100, 900), (300, 1050) | 2.6, 2.6（2 × 1.3） | ページの墓標 `zz: 1760000000500` も引き継ぐ |
| e5（年） | `09-10`（中心 (1025, 550) → 月 floor(969/112) = 8 → 9 月、日 floor(550/60) + 1 = 10） | (48, 0), (98, 20)（x − 56 − 112×8 = x − 952、y − 60×9 = y − 540） | 3.29, 3.29 | |
| f6 | **飛ばす**（`m-2026-09` は日曜始まりの古い id。理由 `.legacyPageId`） | | | |
| `d-2026-10-08` | **飛ばす**（線が無い。理由 `.noStrokes`） | | | |

結果（見本 1）: `pages.count == 4`、`strokeCount == 5`、`skipped == [("m-2026-09", .legacyPageId), ("d-2026-10-08", .noStrokes)]`。全点で opacity 1、azimuth 0、altitude 1.571（π/2 を 0.001 丸め）。各 InkPage の `updatedAt` は Web の `updatedAt`（merge で max になる）。
結果（見本 2）: `pages.count == 4`、`strokeCount == 5`、`skipped == []`。見本 1 と見本 2 の `convert` の `pages` を pageId で整列して比べると **等しい**（`Conversion.pages` は文書の順なので、整列してから比べる）。

## 2. CloudKit スキーマ（本人が CloudKit Console で作る。担当 C が docs/M4.md に手順を写す）

### 2.1 コンテナ・環境・ゾーン

| 項目 | 値 |
| --- | --- |
| コンテナ | `iCloud.com.syfan0.tegakicalendar`（Apple Developer › Identifiers › iCloud Containers で作る。App ID `com.syfan0.tegakicalendar` の Capabilities に **iCloud（CloudKit、このコンテナ）** と **Push Notifications** を付け、**プロビジョニングプロファイルを作り直す**（Secrets の `BUILD_PROVISION_PROFILE_BASE64` を更新）） |
| データベース | プライベート（開発者は中身を見られない） |
| 環境 | **Development で作って「Deploy Schema Changes to Production」で Production へ**。TestFlight / App Store のビルドは Production を使う。CI のシミュレータは iCloud に一切触らない（§4.4 の `SyncEngine.shared` の分岐で保証する） |
| ゾーン | `tegaki`（`CKRecordZone.ID(zoneName: "tegaki", ownerName: CKCurrentUserDefaultName)`）。**ゾーンは Console では作れない**（利用者ごとのもの）。アプリが起動時に `CKModifyRecordZonesOperation` で作る（既にあれば成功） |
| 購読 | `CKRecordZoneSubscription(zoneID: tegaki, subscriptionID: "tegaki-zone-changes")`、`notificationInfo.shouldSendContentAvailable = true`（サイレント）。アプリが作る。Console の操作は不要。届く前提: `aps-environment` の入ったプロファイルで署名、`UIBackgroundModes` に `remote-notification`、毎起動 `registerForRemoteNotifications()`（§6.7）。届かない条件（利用者側）は docs/M4.md に書く（§8.4） |
| セキュリティロール | 既定のまま（プライベート DB は本人だけ） |

### 2.2 レコード種別（Console › Schema › Record Types で **この名前・この型のとおり** に作る）

**`InkPage`**（recordName = pageId。例 `m1-2026-10`、`w-2026-10-05`、`d-2026-10-07`、`y-2026`）

| フィールド名 | Console の型 | 中身 | インデックス |
| --- | --- | --- | --- |
| `schema` | Int(64) | `InkPage.v`（1） | 不要 |
| `updatedAt` | Date/Time | `InkPage.updatedAt`（ms → Date） | SORTABLE（任意。Console で並べ替えて見るため） |
| `strokeCount` | Int(64) | 生きている線の数 `liveStrokeCount` | 不要 |
| `doc` | Asset | `InkPageCodec.compress(InkPageCodec.encode(page))`（端末内ファイルと同じバイト列）。**小さくても常に Asset**（レコード 1 MB 制限を避ける） | （Asset に索引は付けられない） |
| `app` | String | 書いたアプリ `"ios/0.5.0/1"` | 不要 |
| `recordName`（システム） | — | — | **QUERYABLE（推奨）**。アプリは CKQuery を使わないので動作には不要だが、Console の「Query Records」でレコードを見るのに要る |

**`Meta`**（recordName = `"meta"`。1 件）

| フィールド名 | Console の型 | 中身 | インデックス |
| --- | --- | --- | --- |
| `schema` | Int(64) | 1 | 不要 |
| `webImportedAt` | Date/Time | §1.2 | 不要 |
| `trialStartedAt` | Date/Time | M5 | 不要 |
| `app` | String | `"ios/0.5.0/1"` | 不要 |
| `recordName`（システム） | — | — | QUERYABLE（推奨。同上） |

- アプリは **CKQuery を使いません**（全件の列挙は `CKFetchRecordZoneChangesOperation` をトークン無しで回す）。だから Production に配備するのは上の型と任意の索引だけで、索引を忘れてもアプリは動きます。
- フィールドの追加は後からでもできますが、**型の変更と削除はできない** ので名前と型はこのとおりに。
- Asset のファイル名は CloudKit が持ちません。adapter は `tmp/tegaki-upload/<recordName>-<UUID>.json.lzfse` に書いて `CKAsset(fileURL:)` にし、保存の完了後に消します（名前に UUID を付けるのは、同じページの連続した保存と、強制終了の残骸が混ざらないため。`start()` で `tmp/tegaki-upload/` を空にする）。取得した Asset は `fileURL` から読んで Data にします。
- **配備を忘れたときの症状**: Production にレコード種別が無いと保存・取得が `invalidArguments` / `serverRejectedRequest` 系で失敗し、設定の「同期」の footer にその文が出る（§4.5 の `configuration`。自動再試行しない）。Console で Deploy してから「今すぐ同期」。docs/M4.md にも書く。

## 3. TegakiKit の API（担当 K）

### 3.1 WebImport: 解析（`InkModel/WebImport.swift`）

```swift
public enum WebImport {
  public static let format = "tegaki-web-export"
  public static let supportedVersion = 1
  public static let deviceId = "web"                   // 取り込んだ線の dev
  public static let pointStepMs = 8                    // dtMs = 8 × 番号（DESIGN §6.4）
  public static let highlighterWidth: CGFloat = 18

  /// invalidJSON = JSON として読めない／notAnExport = format が違う・object でない／unsupportedVersion = v > 1
  public enum ParseError: Error, Equatable { case invalidJSON, notAnExport, unsupportedVersion(Int) }
  public struct Point: Equatable, Sendable { public var x: Double; public var y: Double; public var p: Double }
  public struct Stroke: Equatable, Sendable {
    public var id: String; public var tool: Tool; public var color: String; public var size: Double; public var points: [Point]; public var t: Int
    public enum Tool: String, Sendable { case pen, highlighter }
  }
  public struct Page: Equatable, Sendable { public var pageId: String; public var strokes: [Stroke] /* id 順 */; public var deleted: [String: Int]; public var updatedAt: Int }
  public struct Document: Equatable, Sendable { public var exportedAt: String?; public var app: String?; public var includesDemo: Bool; public var pages: [Page] }
  /// 寛容に読む: 壊れた線は捨てる（Web 版 deserializePage と同じ規則: id 1〜128 字、tool は 2 種、pts は 3 個ずつで
  /// 有限・|座標| ≤ 100000、p は 0〜1 に clamp・非数なら 0.5、size は非数または 0 以下なら既定（pen 3.5 / highlighter 18）・
  /// それ以外は 0.1〜200 に clamp して 0.01 丸め（Web 版 normalizeSize と同じ。size 0 は 0.1 ではなく既定になる）、
  /// 連続する同じ点は落とす、点が 1 つも無い線は捨てる）。format / v だけが throw の理由
  public static func parse(_ data: Data) throws -> Document
}
```

### 3.2 WebImport: 座標の変換（DESIGN §6.3 を数字で）

```swift
extension WebImport {
  public enum PageId: Equatable, Sendable {
    case month(YearMonth), week(DayKey), day(DayKey), year(Int)   // "m1-YYYY-MM" / "w-YYYY-MM-DD"（月曜に限る）/ "d-YYYY-MM-DD" / "y-YYYY"
    /// 上の 4 形式以外（"m-YYYY-MM"、日曜の "w-"、その他）は nil。月曜の判定は DayKey(ymd:)?.weekday == 1（純粋計算。
    /// 0 = 日曜・1 = 月曜。Web 版の getDay() === 1 と対応）。Calendar は使わない（引数も取らない）
    public static func parse(_ raw: String) -> PageId?
    public var raw: String    // 元の文字列（PageNavigation.pageId と同じ）
  }
  /// 線の外接矩形の中心（点の min/max の中点。太さは足さない）から所属マスと、そのマスの Web 座標での左上を決める。
  /// 月の日付は MonthLayout.grid(for:)（Calendar を取らない）
  public static func cell(for page: PageId, center: CGPoint) -> (cell: CellKey, origin: CGPoint)
}
```

| ページ | マスの決め方 | origin（相対座標 = Web の点 − origin） |
| --- | --- | --- |
| 月 `m1-YYYY-MM` | `cy ≥ 1050` → `memo`。それ以外 `r = clamp(floor(cy / 175), 0, 5)`、`c = clamp(floor(cx / 200), 0, 6)`（紙の左・上の外は 0、右の外は 6）→ `MonthLayout.grid(for: month).days[r × 7 + c]` の `.day(…)`（42 日。月曜始まり） | 日のマス `(200c, 175r)`、メモ `(0, 1050)` |
| 週 `w-YYYY-MM-DD` | 常に `grid`（Web の週ページには終日帯が無い。アプリの `grid` マスは `(0, 帯の高さ)` から始まり幅 1400 なので相対座標は Web の座標そのもの） | `(0, 0)` |
| 日 `d-YYYY-MM-DD` | 常に `grid`（時刻帯・時間軸・メモ欄を含む幅 1000 の 1 マス） | `(0, 0)` |
| 年 `y-YYYY` | `m = clamp(floor((cx − 56) / 112), 0, 11)`（`cx < 56` の日付帯は 1 月）、`d = clamp(floor(cy / 60) + 1, 1, 31)` → `.yearDay(month: m + 1, day: d)`（存在しない 2/30 にも書ける。DESIGN §3.4） | `(56 + 112m, 60(d − 1))` |

`floor` は `(value + 1e-9)` で浮動小数の誤差を救う（M3b の `nearestColumn` と同じ）。NaN の中心は (0, 0) と見なす。

### 3.3 WebImport: 変換（DESIGN §6.4 を数字で）

```swift
extension WebImport {
  public enum SkipReason: Equatable, Sendable { case legacyPageId, unknownPageId, noStrokes }
  public struct Skipped: Equatable, Sendable { public var pageId: String; public var reason: SkipReason }
  /// pages = 文書の順で線が 1 本以上あるものだけ、strokeCount = 変換した線の総数、pageCount = pages.count
  public struct Conversion: Equatable, Sendable { public var pages: [InkPage]; public var skipped: [Skipped]; public var strokeCount: Int; public var pageCount: Int }
  /// 各点の太さ: pen は size × (0.4 + 0.9 × p)、highlighter は size（Web が 18 で固定している）。結果は InkPoint が 0.01 に丸める
  public static func nibSize(tool: Stroke.Tool, size: Double, pressure: Double) -> CGFloat
  /// 1 本の変換。id は Web のまま（isValidId でなければ nil）、cell/origin は §3.2、点は
  ///   InkPoint(x: X − origin.x, y: Y − origin.y, dtMs: 8 × 番号, sizeW: nib, sizeH: nib, opacity: 1, force: p, azimuth: 0, altitude: .pi / 2)、
  ///   tool: pen → .pen / highlighter → .marker、color はそのまま（normalizeColor で不正なら道具の既定色）、t は Web の t、dev = "web"
  public static func convert(stroke: Stroke, page: PageId) -> InkStroke?
  /// 1 ページ。pageId が §3.2 の 4 形式でなければ nil（"m-"・日曜の "w-" は .legacyPageId、他は .unknownPageId）。
  /// InkPage(pageId:)、各線を add(at: stroke.t)、deleted を墓標として引き継ぐ（remove(ids:at:) ではなく直接 deleted に入れる。線は消さない）、
  /// updatedAt = max(Web の updatedAt, 線の t の最大)。線が 0 本なら nil（.noStrokes）
  public static func convert(page: Page) -> InkPage?
  public static func convert(_ document: Document) -> Conversion
}
```

- `Calendar` は使わない（月の 42 日は `MonthLayout.grid(for:)`、月曜の判定は `DayKey.weekday`。どちらも純粋計算）。
- 同じ id の線は merge で 1 本になるので、**同じファイルを二度取り込んでも増えません**（§5.5 の `importPages` が `InkPage.merge(local, imported)` を使う）。iPad で消した線（墓標あり）は再取り込みでも戻りません。
- Web の点は「ならした通過点」で、PencilKit はこれを制御点として B スプラインを引くので線がわずかに内側を通ります（画面上 1 px 未満。DESIGN §6.4 で許容済み）。
- 時刻 `t` が 0 や不正なら `InkStroke` の init が 0 にする（`inkStart` が 1970 年になるが、指紋の衝突は `makePKStroke` が避ける）。

### 3.4 SyncState: 状態ファイルの型と JSON（`InkModel/SyncState.swift`）

```swift
public struct SeenRecord: Equatable, Sendable {
  public var changeTag: String; public var systemFields: Data?   // systemFields nil なら adapter は新規のレコードを作って保存する（衝突で学び直す）
  public init(changeTag: String, systemFields: Data? = nil)
}

public struct SyncState: Equatable, Sendable {
  public static let currentVersion = 1
  public static let knownKeys: Set<String>             // §1.1 の 11 個
  public var v: Int; public var dirty: [String]; public var zoneToken: Data?; public var zoneReady: Bool; public var subscriptionReady: Bool
  public var account: String?; public var pendingAccount: String?; public var pendingCloudErase: Bool
  public var seen: [String: SeenRecord]; public var lastSyncAt: Int?; public var webImportedAt: Int?
  public var unknown: [String: JSONValue]              // 知らない項目は書き戻す
  public static let empty: SyncState                   // v 1、全部空／false／nil
  public init(json: JSONValue)                         // 寛容に読む。object でなければ empty。dirty の重複は落とす。seen の壊れた項目は捨てる
  public var jsonValue: JSONValue                      // 鍵を整列した決定的な JSON（JSONValue.serialized）
  public var isDirty: Bool
  public mutating func markDirty(_ pageId: String)     // 無ければ末尾に足す
  public mutating func clearDirty(_ pageId: String)
  /// 別のアカウントで使い始める（手書きは残す）: account = newAccount、pendingAccount = nil、zoneToken = nil、seen = [:]、
  /// zoneReady = subscriptionReady = false、dirty = allLocalPageIds（全部送り直す）。unknown / webImportedAt は保つ
  public mutating func adoptAccount(_ newAccount: String, allLocalPageIds: [String])
  /// 全消去のあと: dirty = []、seen = [:]、zoneToken = nil、pendingCloudErase = cloudPending、webImportedAt = nil。account / zoneReady / subscriptionReady は保つ
  public mutating func resetAfterErase(cloudPending: Bool)
  /// ゾーン消失のあと（§4.5）: zoneToken = nil、seen = [:]、zoneReady = subscriptionReady = false、dirty = allLocalPageIds。account / pendingCloudErase / webImportedAt は保つ
  public mutating func resetAfterZoneLoss(allLocalPageIds: [String])
}

public enum SyncStateCodec {
  public static func encode(_ state: SyncState) throws -> Data     // JSON（圧縮しない。小さい）
  public static func decode(_ data: Data) throws -> SyncState      // JSON でなければ throw（S は throw したら empty から始め、壊れたファイルは .bak に退避）
}
```

### 3.5 SyncBackoff: 間隔の計算（`InkModel/SyncBackoff.swift`）

```swift
public struct SyncBackoff: Equatable, Sendable {
  public static let debounce: TimeInterval = 1.5          // 保存から送信まで
  public static let minimum: TimeInterval = 15; public static let maximum: TimeInterval = 300   // 最初の再試行、上限 5 分
  public static let maxConflictRetries = 3                // serverRecordChanged で merge して再保存する回数
  public static let pageFetchCooldown: TimeInterval = 30  // 同じページの個別取得を省く間隔
  public static let notificationBudget: TimeInterval = 20 // サイレントプッシュの受け口が iOS に返すまでの上限（§4.4）
  public private(set) var failures: Int; public init(failures: Int = 0)   // 連続して失敗した回数（0 から）
  /// 次の待ち時間: min(300, 15 × 2^failures) → 15, 30, 60, 120, 240, 300, 300, …
  public var nextDelay: TimeInterval
  /// サーバーが retryAfter を言ったときは max(そちら, nextDelay)
  public func nextDelay(serverHint: TimeInterval?) -> TimeInterval
  public mutating func recordFailure()                    // failures += 1（上限 30）
  public mutating func reset()                            // 成功したら 0
  public static func delay(afterFailures n: Int) -> TimeInterval
}
```

### 3.6 InkPage の追加（`InkModel/InkPage.swift`）

```swift
extension InkPage {
  /// 生きている線の id の集合と墓標の id の集合のどちらかが違えば true（Web 版 sameContent の否定）。updatedAt の違いは見ない
  public func contentDiffers(from other: InkPage) -> Bool
  public var liveStrokeIds: [String]                   // 生きている線の id（整列済み）
}
```

`InkPage.merge` は M2 のまま（可換・結合的・冪等。§5.3 の規則）。同期の「差があるか」の判定は `contentDiffers`（`==` は updatedAt や unknown の違いでも真になるため）。

## 4. Sync エンジン（担当 S）

### 4.1 プロトコル `CloudDatabase`（`Sync/CloudDatabase.swift`。CloudKit を import しない）

```swift
enum CloudValue: Equatable, Sendable { case int(Int64), string(String), date(Date), asset(Data) }
/// 1 レコードの値の写し。fields は §2.2 の名前そのまま。changeTag = サーバーが付けた版（新規は nil）、
/// systemFields = CKRecord.encodeSystemFields の結果（新規は nil。偽物は changeTag から作る）
struct CloudRecord: Equatable, Sendable {
  var recordType: String /* "InkPage" / "Meta" */; var recordName: String; var changeTag: String?; var systemFields: Data?; var fields: [String: CloudValue]
}
/// changed = 変更・追加（adapter が moreComing を全部回して 1 つにまとめる）、token = 新しい変更トークン
struct CloudZoneChanges: Equatable, Sendable { var changed: [CloudRecord]; var deletedNames: [String]; var token: Data? }
enum CloudAccountStatus: Equatable, Sendable { case available, noAccount, restricted, couldNotDetermine, temporarilyUnavailable }
enum CloudError: Error, Equatable {
  case notAuthenticated                             // CKError.notAuthenticated
  case networkUnavailable                           // .networkUnavailable / .networkFailure
  case serverRecordChanged(server: CloudRecord)     // 衝突。server が最新（CKRecordChangedErrorServerRecordKey）
  case recordNotFound                               // .unknownItem: そのレコードが無い（他端末の全消去で消えた後に古い systemFields で保存した、など）
  case zoneMissing                                  // .zoneNotFound / .userDeletedZone: ゾーンごと無い（利用者が iCloud の設定でこのアプリのデータを消した、など）
  case changeTokenExpired                           // .changeTokenExpired → トークンを捨てて全件
  case quotaExceeded                                // .quotaExceeded
  case retryLater(after: TimeInterval?)             // .zoneBusy / .serviceUnavailable / .requestRateLimited（CKErrorRetryAfterKey）/ .accountTemporarilyUnavailable（after nil）
  case limitExceeded, permissionFailure             // .limitExceeded → 半分に割る／.permissionFailure, .managedAccountRestricted
  case configuration(String)                        // 恒久的な設定の誤り: .badContainer / .missingEntitlement / .invalidArguments / .serverRejectedRequest（自動再試行しない）
  case other(String)                                // それ以外（localizedDescription）
}
protocol CloudDatabase: AnyObject {
  func accountStatus() async throws -> CloudAccountStatus
  func userRecordName() async throws -> String                   // CKContainer.userRecordID().recordName（アカウントの識別。available のときだけ呼ぶ。初回はネットが要る）
  func ensureZone() async throws                                 // ゾーン "tegaki" を作る（既にあれば成功）
  func ensureSubscription() async throws                         // CKRecordZoneSubscription "tegaki-zone-changes"（既にあれば成功。偽物は記録するだけ）
  /// CKFetchRecordZoneChangesOperation。token nil は全件。moreComing は adapter が回す。
  /// namesOnly = true なら本文（doc）を落とさない（desiredKeys = []。名前と changeTag と小さな fields だけ。全消去と消失後の確認に使う）
  func fetchChanges(since token: Data?, namesOnly: Bool) async throws -> CloudZoneChanges
  func fetchRecords(names: [String]) async throws -> [String: CloudRecord]    // CKFetchRecordsOperation。無い名前は辞書に入らない（throw しない）
  /// 1 レコードを .ifServerRecordUnchanged で保存。systemFields があればそれで CKRecord を復元して fields を書き、無ければ新規の CKRecord。
  /// 返り値は保存後の版（changeTag / systemFields 入り）。衝突は .serverRecordChanged(server:)。systemFields の指すレコードが無ければ .recordNotFound
  func save(_ record: CloudRecord) async throws -> CloudRecord
  /// CKModifyRecordsOperation(recordIDsToDelete:)。非 atomic。無い名前は成功扱い（§4.2）。1 回 200 件まで（超えたら .limitExceeded。engine が分ける）
  func delete(names: [String]) async throws
  /// サイレントプッシュの userInfo から購読 id を取り出す（本物は CKNotification、偽物は userInfo["subscriptionID"]）。該当しなければ nil
  func subscriptionID(in userInfo: [AnyHashable: Any]) -> String?
  /// .CKAccountChanged の通知。実装は `let` で 1 本だけ持ち（AsyncStream.makeStream() の continuation を保持して流す）、
  /// 何度 get しても同じストリームを返す（偽物の simulateAccountChange がエンジンの購読している 1 本に流せるように）
  var accountChanges: AsyncStream<Void> { get }
}
extension CloudDatabase { func fetchChanges(since token: Data?) async throws -> CloudZoneChanges /* namesOnly: false */ }
```

### 4.2 本物の adapter（`Sync/CloudKitDatabase.swift`。CloudKit を import する唯一のファイル）

```swift
final class CloudKitDatabase: CloudDatabase {
  static let containerIdentifier = "iCloud.com.syfan0.tegakicalendar"; static let zoneName = "tegaki"; static let subscriptionID = "tegaki-zone-changes"
  /// init では何も作らない。CKContainer(identifier:) と privateCloudDatabase は最初の呼び出し（accountStatus 等）で遅延生成する
  /// （entitlements の無いプロセスで CKContainer を作ると NSException で落ちるため。CI のシミュレータでは一度も呼ばれない。§4.4）
  init(containerIdentifier: String = CloudKitDatabase.containerIdentifier)
  static func map(_ error: Error) -> CloudError                                // CKError → CloudError（下の規則。XCTest で検査する。§8.2）
  static func encodeToken(_ token: CKServerChangeToken) -> Data?; static func decodeToken(_ data: Data) -> CKServerChangeToken?   // NSKeyedArchiver（secure）
}
```

- `map(_:)` の規則: `partialFailure` は `CKPartialErrorsByItemIDKey` の中の **対象レコードの誤り** を取り出してから写す。`serverRecordChanged` は `CKRecordChangedErrorServerRecordKey` の CKRecord を `CloudRecord` にする。`retryLater` の `after` は `CKErrorRetryAfterKey`（秒）。`.unknownItem` → `.recordNotFound`、`.zoneNotFound` / `.userDeletedZone` → `.zoneMissing`、`.accountTemporarilyUnavailable` → `.retryLater(after: nil)`、`.badContainer` / `.missingEntitlement` / `.invalidArguments` / `.serverRejectedRequest` → `.configuration(localizedDescription)`。CKError でないもの（URLError 等）は `.networkUnavailable`（`URLError.notConnectedToInternet` 等）か `.other`。
- `save`: `CKModifyRecordsOperation(recordsToSave: [ck])`、`savePolicy = .ifServerRecordUnchanged`、`qualityOfService = .userInitiated`。`CloudValue.asset(data)` は `tmp/tegaki-upload/<recordName>-<UUID>.json.lzfse` に書いて `CKAsset`、完了後に消す。
- `delete(names:)`: `CKModifyRecordsOperation(recordIDsToDelete:)`、**`isAtomic = false`**（既定は専用ゾーンで true。1 件の `unknownItem` で残りが `batchRequestFailed` にならないように）。`perRecordDeleteBlock` / `partialFailure` の `CKPartialErrorsByItemIDKey` を見て、**`.unknownItem` は成功扱い**、それ以外の項目の誤りだけを最初の 1 件で throw（`map` を通す）。`names.count > 200` なら呼ぶ前に `.limitExceeded`。
- `fetchChanges`: `CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone], configurationsByRecordZoneID: [zone: config])`、`config.previousServerChangeToken`、`namesOnly` なら `config.desiredKeys = []`。`recordWasChangedBlock` で `CloudRecord` に（Asset は `fileURL` を読んで `Data`。`namesOnly` では `doc` が来ないので fields に入らない）、`recordWithIDWasDeletedBlock` で名前、`recordZoneFetchResultBlock` の token を保存。`moreComing` は中で回す。`changeTokenExpired` は `CloudError.changeTokenExpired`。
- `subscriptionID(in:)`: `(CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKRecordZoneNotification)?.subscriptionID`。
- `accountStatus`: `CKContainer.accountStatus()`。`accountChanges`: `NotificationCenter` の `.CKAccountChanged` を 1 本の `AsyncStream` に（§4.1 の約束）。
- `userRecordName`: `CKContainer.userRecordID()`。
- 本物の adapter の **往復** は実機でしか動かない（CI では `InMemoryCloudDatabase` だけ）。型検査はこの Mac の Catalyst SDK で（§8.4 のコマンド。CloudKit は SDK にある）。`map(_:)` と `subscriptionID(in:)` と `encodeToken` の型だけはシミュレータの XCTest でも検査する（§8.2）。

### 4.3 レコードの写像（`Sync/InkPageRecord.swift`）

```swift
enum InkPageRecord {
  static let recordType = "InkPage"; static let metaRecordType = "Meta"; static let metaRecordName = "meta"
  static var appString: String   // "ios/<CFBundleShortVersionString>/<CFBundleVersion>"（例 "ios/0.5.0/1"。Bundle が無いテストでは "ios/0/0"）
  /// page → CloudRecord。fields: schema = v、updatedAt = Date(ms)、strokeCount = liveStrokeCount、doc = compress(encode(page))、app。
  /// seen があれば changeTag / systemFields を写す（.ifServerRecordUnchanged の根拠）
  static func make(_ page: InkPage, seen: SeenRecord?) throws -> CloudRecord
  /// CloudRecord → page。doc を decompress → decode。JSON の pageId が空か違えば recordName にする。doc が無い・壊れている → throw InkCodecError
  static func page(from record: CloudRecord) throws -> InkPage
  static func seen(from record: CloudRecord) -> SeenRecord?          // changeTag が nil なら nil
  /// Meta: fields schema = 1、app、webImportedAt / trialStartedAt は nil なら書かない（既存の値を保つには server の値を写す）
  static func makeMeta(webImportedAt: Date?, trialStartedAt: Date?, seen: SeenRecord?) -> CloudRecord
  static func metaValues(from record: CloudRecord) -> (webImportedAt: Date?, trialStartedAt: Date?)
}
```

### 4.4 SyncEngine の公開 API

**`Sync/SyncStatus.swift`**（型と文言。U が参照する型は全部ここ。S は **これを最初に** 出す。§8.4）:

```swift
enum SyncStatus: Equatable, Sendable {
  case localOnly(LocalOnlyReason)         // iCloud を使わない（DESIGN §5.4「この iPad のみ」）
  case synced, pending, syncing           // dirty 無しで最後の往復が成功／dirty あり送信待ち（デバウンス中・再試行待ち）／往復中
  case offline                            // networkUnavailable。回線が戻れば送る
  case error(SyncErrorKind)               // 端末内には保存し続ける
  case accountMismatch                    // 別の iCloud アカウント。同期を止めて問い合わせ中
  enum LocalOnlyReason: Equatable, Sendable { case noAccount, restricted, unknown, notAuthenticated }
  enum SyncErrorKind: Equatable, Sendable { case quota, permission, server(String) }
}
struct SyncSnapshot: Equatable, Sendable { var status: SyncStatus; var lastSyncAt: Date?; var dirtyCount: Int; var webImportedAt: Date? }
/// ヘッダーの ☁ の見た目（§6.1）。isError は .error と .accountMismatch で true
struct HeaderSync: Equatable, Sendable { var text: String; var symbol: String; var isError: Bool }
enum AccountChangeChoice: Equatable { case keepInk, eraseInk, later }
/// メンバーワイズ init はこの宣言順: ImportOutcome(pagesChanged:strokesAdded:pagesSeen:)
struct ImportOutcome: Equatable, Sendable { var pagesChanged: Int; var strokesAdded: Int; var pagesSeen: Int }
extension SyncStatus { var header: HeaderSync; var settingsText: String; var settingsFooter: String; var isError: Bool }   // 文言は §6.1 の表
```

**`Sync/SyncEngine.swift`**（@MainActor、ObservableObject）:

```swift
@MainActor final class SyncEngine: ObservableObject {
  /// アプリが使う 1 つ。次の順で決める（CKContainer を作ってよいのは最後の分岐だけ）:
  ///   (a) ScreenshotMode.isActive            → screenshotDemo(now: ScreenshotMode.current!.today)（§6.6）
  ///   (b) isTestHost（XCTest のホストとして起動された） → screenshotDemo(now: Date())（不活性。DB もファイルも触らない）
  ///   (c) CommandLine.arguments に "--no-icloud"   → live(database: InMemoryCloudDatabase())（手元の保険。CI は使わない）
  ///   (d) それ以外                            → live()
  static let shared: SyncEngine
  /// NSClassFromString("XCTestCase") != nil、または環境変数 XCTestConfigurationFilePath / XCTestBundlePath / XCTestSessionIdentifier のどれかがある
  static var isTestHost: Bool
  /// (d) のときだけ true。U の AppDelegate はこれが true のときだけ registerForRemoteNotifications() を呼ぶ（§6.7）
  static var usesCloudKit: Bool
  static func live(database: any CloudDatabase = CloudKitDatabase()) -> SyncEngine   // InkPageStore()、SyncStateStore()（既定の場所）
  init(store: InkPageStore, stateStore: SyncStateStore, database: any CloudDatabase, clock: @escaping () -> Date = Date.init,
       sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) })
  @Published private(set) var snapshot: SyncSnapshot
  /// 開いているページが iCloud から変わったとき（merge 済みの新しい page）。CalendarRootScreen が §5.4 のとおり取り込む
  var onRemoteUpdate: ((InkPage) -> Void)?
  var store: InkPageStore { get }
  let database: any CloudDatabase                        // 検査用（§8.2 の 0）

  // 保存層（§5.3）
  func load(_ pageId: String) -> InkPage               // store.load（同期はしない）
  func save(_ page: InkPage) throws                     // ファイルの版と merge して store.save → dirty に積む → state を書く → 1.5 秒後に push（§4.5 の 2）
  func pageOpened(_ pageId: String)                     // そのページだけ fetchRecords（30 秒以内の再入は省く）。差があれば onRemoteUpdate
  func allLocalPageIds() -> [String]

  // 命令
  func start()                                          // 起動時に 1 回（AppDelegate.didFinishLaunching）。冪等: 2 回目以降は何もしない。§4.5 の 1
  func syncNow() async                                  // 「今すぐ同期」・前面復帰・サイレントプッシュ: デバウンスを待たずに 1 周（§4.5 の 6）
  func applicationDidBecomeActive()                     // Task { await syncNow() }
  /// database.subscriptionID(in:) == CloudKitDatabase.subscriptionID でなければ即 false。合えば syncNow() を待ち行列に積み、
  /// 最長 20 秒（SyncBackoff.notificationBudget。sleep(20) との race）で返す。true = その間に pull が 1 件以上の変更（changed か deletedNames）を取り込んだ。
  /// 同期そのものは待ち行列で続く（iOS に止められたら次の前面復帰で続きから）
  func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool
  func resolveAccountChange(_ choice: AccountChangeChoice) async
  func eraseEverything() async throws                   // 端末内を全部消し、iCloud の InkPage を全部消す（§4.5 の 10）
  func importPages(_ pages: [InkPage], progress: @escaping (_ done: Int, _ total: Int) -> Void) async throws -> ImportOutcome
  static func screenshotDemo(now: Date) -> SyncEngine   // §6.6

  // テスト用（internal。@testable で見える。§8.2）
  /// sleep の中で止まっているものを除き、待ち行列・pull・push・デバウンス・再試行の Task が全部終わるまで待つ。
  /// エンジンは「走っている仕事の数」を数え（sleep に入る前に −1、戻ったら +1）、0 になったら返る
  func waitUntilIdle() async
}
```

### 4.5 状態機械と手順（Web 版 ink-store.js の流儀）

内部の仕事は 1 本の直列な待ち行列で回します（`pull` と `push` は同時に走らない。走っている間に来た要求は `syncAgain = true` にして終わってからもう 1 周）。状態の遷移は次の表のとおり。`snapshot` は変わったときだけ発行する。

**アカウント確認**（1・6・8 が使う）: `state.account == nil`、または `pendingAccount != nil`、または status が `localOnly` / `accountMismatch` のとき（= アカウントが確定していないとき）は、**どの `syncNow` / 再試行でも必ず** `accountStatus()` → `userRecordName()` から始め、確定するまで pull / push をしない（別アカウントの端末内データと黙って混ぜない。DESIGN §5.4）。`accountStatus()`: `.available` 以外 → `.localOnly(理由)` で終わり（`noAccount` → `.noAccount`、`restricted` → `.restricted`、`couldNotDetermine` → `.unknown`。`temporarilyUnavailable` → status は変えず（初回は `.pending`）、backoff で再試行）。`userRecordName()`: `state.account` が nil → 記録。同じ → 確定。違う → `pendingAccount` に書いて `.accountMismatch` で終わり。失敗 → 下の表（`networkUnavailable` → `.offline`。dirty は積むだけ）。確定済み（`account != nil`、`pendingAccount == nil`、status がそれ以外）のときは省く（`.CKAccountChanged` が来たときだけやり直す）。

**1 周**（`syncNow` の中身。1・6・7・再試行が使う）: アカウント確認（必要なとき）→ `pendingCloudErase` なら 10 の後半を先に（終わるまで pull しない）→ `zoneReady` でなければ `ensureZone()`、`subscriptionReady` でなければ `ensureSubscription()`（失敗しても続行。次回また）→ `pull()` → `push()`。

| 番号 | きっかけ | 手順 |
| --- | --- | --- |
| 1 | `start()` | 冪等（2 回目以降は何もしない）。state を読む（壊れていれば `.bak` に退避して empty）。**`seen` にも `dirty` にも無い端末内ページ（`allLocalPageIds()`）を `dirty` に足す**（状態ファイルを失っても手書きが iCloud から漏れない）。`tmp/tegaki-upload/` を空にする。`accountChanges` を購読して 8 へ。その後「1 周」を待ち行列に積む |
| 2 | `save(page)` | `merged = InkPage.merge(store.load(page.pageId), page)`（保険: 画面の `page` が遠隔更新を取りこぼしていてもファイルにある線を消さない。墓標があるので削除は戻らない。普段は `merged` の内容 == `page`）→ `store.save(merged)`（throw はそのまま上へ: 画面が「手書きを保存できませんでした」を出す）。`merged.contentDiffers(from: page)` なら `onRemoteUpdate(merged)`（画面が追いつく）。`pageGeneration[id] += 1`、`state.markDirty`、`stateStore.save`（**失敗は throw せず記録だけ**: dirty はメモリに残るので同じセッション内は送られ、次回起動は 1 の「seen に無いページを dirty に足す」で拾う）。status が `.synced` なら `.pending`。デバウンス（下の規則）のあと `push()`。`localOnly` / `accountMismatch` のときは dirty に積むだけ（サインインしたら送る） |
| 3 | `pageOpened(pageId)` | `.synced` / `.pending` / `.offline` / `.error` のときだけ。同じ pageId を 30 秒以内に開き直したら省く。`fetchRecords([pageId])`: 無ければ何もしない。`changeTag == seen[pageId].changeTag` なら何もしない。違えば `merged = merge(local, remote)`。`merged.contentDiffers(from: local)` なら `store.save(merged)` と `onRemoteUpdate(merged)`。`merged.contentDiffers(from: remote)`（端末内にしか無い線がある）なら `markDirty`。`seen[pageId]` を更新。失敗は黙って無視（`networkUnavailable` だけ `.offline` に、`zoneMissing` は下の「ゾーン消失」） |
| 4 | `pull()` | `fetchChanges(since: zoneToken)`。各 `InkPage` レコード: `changeTag == seen[name].changeTag` なら飛ばす（自分が送ったもの）。それ以外は 3 と同じ merge（表示中のページなら `onRemoteUpdate`）。`deletedNames`（他の端末の全消去）: 端末内ファイルを消し、`seen` と `dirty` から外し、表示中なら `onRemoteUpdate(InkPage.empty(pageId:))`。`Meta` レコード: `webImportedAt` を state に写す。終わったら `zoneToken` と `lastSyncAt` を書く。`changeTokenExpired` → `zoneToken = nil`、`seen = [:]`、1 回だけやり直す。取り込んだ変更の数（changed + deletedNames のうち実際に何か変えたもの）を 7 のために数える |
| 5 | `push()` | `dirty` の写しを順に: `gen = pageGeneration[id]`、`page = store.load`、`record = InkPageRecord.make(page, seen: seen[id])`、`save`。成功 → `seen[id] = seen(from:)`、`pageGeneration[id] == gen` なら `clearDirty`、`lastSyncAt`。`.serverRecordChanged(server)` → `merged = merge(page, page(from: server))`、`store.save(merged)`、表示中なら `onRemoteUpdate`、`seen[id] = seen(from: server)` で再保存（**最大 3 回**。超えたら dirty のまま次回）。`.recordNotFound`（他端末の全消去で消えたレコードに古い `seen` で保存した）→ `seen[id] = nil` にして **新規レコードとして** 1 回だけ再保存（端末内が主なので、消された後にこの端末で書いた手書きは iCloud に戻る。向こうの端末には次の pull で新規として届く）。`.zoneMissing` → 下の「ゾーン消失」。全部送れたら `.synced`、残れば `.pending`。push の間に `save` が来て dirty が残れば（世代が進んだ）、デバウンス無しでもう 1 周（`syncAgain`）。失敗の扱いは次の表 |
| 6 | `syncNow()` | デバウンスと再試行の Task を止め、「1 周」。`localOnly` / `accountMismatch` ならアカウント確認だけ（サインイン・サインアウトの反映。確定したら続けて pull → push） |
| 7 | `handleRemoteNotification` | `database.subscriptionID(in: userInfo) == "tegaki-zone-changes"` でなければ即 false。合えば 6 を待ち行列に積み、`sleep(20)` と race: 先に 1 周が終われば「pull が 1 件以上変えたか」を返す。20 秒経てば false を返して 1 周は続行（iOS の完了ハンドラの約 30 秒の制限を守る。予算を使い切ると以後サイレントプッシュが届きにくくなる）。バックグラウンド起動では `didFinishLaunching` の `start()` が先に待ち行列に積まれ、この 1 周はその後ろ |
| 8 | `.CKAccountChanged` | アカウント確認をやり直す。サインアウト（`noAccount`）→ `.localOnly(.noAccount)`（state.account は **保つ**。同じアカウントに戻れば続きから）。同じアカウントに戻った → 「1 周」。別のアカウント → `pendingAccount` に書いて `.accountMismatch`。U は snapshot を見て §6.4 の問い合わせを出す |
| 9 | `resolveAccountChange` | `.keepInk`: `state.adoptAccount(pending, allLocalPageIds:)` → 「1 周」（全ページが dirty なので新しいアカウントへ送られ、向こうにあるものと merge される）。`.eraseInk`: `store.removeAll()` → `state = .empty` に `account = pending` → 「1 周」。`.later`: 何もしない（`.accountMismatch` のまま。次の起動でまた聞く） |
| 10 | `eraseEverything()` | デバウンス・再試行を止める。`store.removeAll()`、`state.resetAfterErase(cloudPending: true)` を先に書く。iCloud が使える状態（`synced`/`pending`/`syncing`/`offline`/`error`）なら `fetchChanges(since: nil, namesOnly: true)` を回して `recordType == "InkPage"` の名前を集め（**この結果だけ**。`seen` の鍵は足さない: 他端末が既に消した名前が混ざるため）、`delete(names:)` を **200 件ずつ**（`delete` は無い名前を成功扱いにする）。全部消せたら `pendingCloudErase = false`、`zoneToken` は削除後の `fetchChanges(since: nil, namesOnly: true)` の token（無ければ nil）、`seen = [:]`。途中で失敗 → throw（U がトーストを出す。`pendingCloudErase` が残るので次の `start`/`syncNow` で先に削除をやり直し、**それまで pull をしない**: 消したはずの線が戻らないように）。`localOnly` なら端末内だけ消して終わり |
| 11 | `importPages(pages, progress)` | 各ページ: `local = store.load`、`merged = merge(local, page)`、`merged.contentDiffers(from: local)` なら `store.save(merged)`・`markDirty`・`pagesChanged += 1`、`strokesAdded += merged.liveStrokeCount − local.liveStrokeCount`（merge で消えた線は数えない）。表示中のページなら `onRemoteUpdate(merged)`。`progress(done, total)` を毎ページ。`pagesSeen = pages.count`。最後に `webImportedAt = now` を state に書き、iCloud が使えるなら `Meta` を保存（失敗は無視。次の push で再試行はしない。表示は state の値）。`push()` をデバウンス無しで予約。ImportOutcome を返す |

**ゾーン消失**（`push` / `pull` / `pageOpened` / `fetchRecords` のどれかが `.zoneMissing`）: `state.resetAfterZoneLoss(allLocalPageIds:)`（`zoneReady = subscriptionReady = false`、`zoneToken = nil`、`seen = [:]`、`dirty = 全端末内ページ`。端末内が主なので全部送り直す。購読もゾーンと一緒に消えているので作り直す）→ `ensureZone()` → `ensureSubscription()` → `pull()` → `push()` を 1 回。それでも `.zoneMissing` → `.error(.server("zone"))`、backoff。

**デバウンスと再試行の Task**: `save` のたびに `debounceGeneration += 1`。デバウンスの Task は 1 本だけ: `sleep(1.5)` から戻ったとき世代が進んでいればもう 1 回 `sleep(1.5)`、進んでいなければ `push()`（続けて来た save は新しい Task を作らない）。再試行の Task も 1 本だけ: `sleep(backoff.nextDelay(serverHint:))` → 「1 周」。`syncNow()` / `eraseEverything()` はどちらも止める（世代を進めて Task を捨てる。止めた sleep から戻った Task は何もしない）。

失敗の扱い（`push` / `pull` / `ensureZone` / `ensureSubscription` / アカウント確認の throw。DESIGN §5.4 の表を全部含む）:

| CloudError | status | そのあと |
| --- | --- | --- |
| `networkUnavailable`（`userRecordName` を含む） | `.offline` | dirty はそのまま。`SyncBackoff` の待ち（15 s → 30 → 60 → 120 → 240 → 300 …）のあと「1 周」。成功で reset。前面復帰・`syncNow` でも即再試行。アカウントが未確定なら再試行もアカウント確認から |
| `notAuthenticated` | `.localOnly(.notAuthenticated)` | 再試行しない。前面復帰と `.CKAccountChanged` でアカウント確認からやり直す |
| `quotaExceeded` | `.error(.quota)` | 端末内には保存し続ける。自動再試行しない（`syncNow` と次の起動でだけ）。設定に「iCloud の容量が足りません」 |
| `permissionFailure` | `.error(.permission)` | 自動再試行しない |
| `configuration(m)` | `.error(.server(m))` | **自動再試行しない**（`syncNow` と次の起動でだけ）。Production にスキーマが無い・プロファイルが古い等。設定の footer に m |
| `retryLater(after)` | `.pending`（送信待ち） | `backoff.nextDelay(serverHint: after)` のあと再試行（`accountTemporarilyUnavailable` は after nil） |
| `limitExceeded` | （`delete` だけ）件数を半分にしてやり直す。1 件でも駄目なら `.error(.server)` | |
| `recordNotFound` | — | 5 のとおり `seen[id] = nil` で新規として 1 回再保存。それでも駄目なら dirty のまま `.error(.server("record"))` |
| `zoneMissing` | — | 上の「ゾーン消失」を 1 回。それでも駄目なら `.error(.server("zone"))`、backoff |
| `changeTokenExpired` | — | 4 のとおり全件からやり直し |
| `serverRecordChanged` | — | 5 のとおり merge して再保存（3 回まで） |
| `other(message)` | `.error(.server(message))` | backoff で再試行（上限 5 分）。設定の footer に message |

- デバウンスと再試行と 7 の 20 秒は全部 `sleep` を通す（テストは §8.2 の `TestSleeper` を渡す）。
- `lastSyncAt` は取得か送信が **成功したとき** だけ進める。`snapshot.dirtyCount = state.dirty.count`。
- `start()` が終わる前に `save` が来てもよい（dirty に積まれ、待ち行列の末尾で送られる）。
- エンジンは `InkPageStore` を **自分のものとして** 持つ（画面は `sync.load` / `sync.save` だけを使い、`InkPageStore` を直接触らない。§5.3）。

### 4.6 偽物 `InMemoryCloudDatabase`（`Sync/InMemoryCloudDatabase.swift`）

```swift
final class InMemoryCloudDatabase: CloudDatabase {
  var status: CloudAccountStatus = .available; var userName: String = "_user-a"
  var records: [String: CloudRecord]                  // recordName → 現在の版（changeTag は "t1", "t2", … と進む）
  private(set) var deletedNames: Set<String>; private(set) var subscriptionIDs: Set<String>
  private(set) var zoneExists: Bool                   // ensureZone で true。false の間は save / fetch* / delete が .zoneMissing
  var failNext: [Operation: CloudError]               // 次の呼び出しで投げる誤り（1 回で消える）。例 failNext[.save] = .networkUnavailable
  var alwaysFail: CloudError?
  private(set) var calls: [Operation]                 // 呼ばれた順（検査用）
  enum Operation: Equatable { case accountStatus, userRecordName, ensureZone, ensureSubscription, fetchChanges, fetchRecords, save, delete }
  /// 「別の端末」が書いたことにする: changeTag を進め、変更の履歴に積む
  func simulateRemoteSave(_ record: CloudRecord) -> CloudRecord
  func simulateRemoteDelete(_ name: String)
  func simulateAccountChange(status: CloudAccountStatus, userName: String)   // accountChanges（1 本）に流す
  func simulateZoneDeleted()                          // zoneExists = false、records / 履歴 / subscriptionIDs を空に（利用者が iCloud の設定で消した）
  func expireToken()                                  // 次の fetchChanges(since: 非 nil) を .changeTokenExpired に
  func pause(_ op: Operation)                         // 次の op の呼び出しを resume() まで止める（1 回）。「送信中」を作る（§8.2 の 5・18）
  func resume()
}
```

- 変更トークンは「履歴の番号」を `Data` にしたもの。`fetchChanges(since:)` はその番号より後の変更を返す。`namesOnly` なら各 `fields` から `doc` を抜いて返す。`systemFields` は `"sys:" + changeTag` の UTF-8（engine は opaque に扱うだけ）。
- `save`: `record.changeTag != nil` で `records[name] == nil` なら `.recordNotFound`。`record.changeTag != records[name]?.changeTag` なら `.serverRecordChanged(server: 現在の版)`。新規（`changeTag == nil`）で既にあれば同じく衝突。
- `delete(names:)`: `names.count > 200` なら `.limitExceeded`。無い名前は無視（成功）。
- `subscriptionID(in:)`: `userInfo["subscriptionID"] as? String`。
- `accountChanges` は `let` の 1 本（§4.1 の約束）。
- Asset は `CloudValue.asset(Data)` のまま持つ（ファイルにしない）。

## 5. 保存層の変更

### 5.1 `InkPageStore`（担当 S）

```swift
struct InkPageStore {
  // 既存はそのまま（init(directory:) / load / save / remove / removeAll / exists / url / fileName）
  /// directory の中の *.json.lzfse を pageId に戻した一覧（整列済み。.bak は含まない）。fileName(for:) は英数と -_. しか残さないが、
  /// pageId は元々その文字しか使わないので往復できる
  func allPageIds() -> [String]
  var stateFileURL: URL                   // 状態ファイル: directory/state.json
}
```

### 5.2 `SyncStateStore`（`Persistence/SyncStateStore.swift`、担当 S）

```swift
struct SyncStateStore {
  init(fileURL: URL = InkPageStore().stateFileURL)
  func load() -> SyncState                // 無ければ .empty。読めなければ .bak に退避して .empty（ページと同じ流儀）
  func save(_ state: SyncState) throws; func remove() throws    // SyncStateCodec.encode → .atomic
}
```

### 5.3 CalendarRootScreen の保存の経路（担当 U）

M3b の `private let store = InkPageStore()` を **`@ObservedObject private var sync = SyncEngine.shared`** に置き換える。

| 場所 | M3b | M4 |
| --- | --- | --- |
| `show(kind:focus:)` | `page = store.load(id)` | `page = sync.load(id)`、続けて `sync.pageOpened(id)`（スクリーンショットモードは demoPage のまま、`pageOpened` は呼ばない） |
| `saveNow()` | `try store.save(page)` | `try sync.save(page)`（throw は従来どおり `saveError`） |
| `eraseAllInk()` | `try store.removeAll()` | §6.2 の全消去の流れ（`await sync.eraseEverything()`） |
| `appear()` | — | `sync.onRemoteUpdate = { applyRemote($0) }`。`scenePhase == .active` で `sync.applicationDidBecomeActive()` |

### 5.4 遠隔更新を開いているページへ反映する（担当 U。履歴は保つ）

```swift
/// SyncEngine.onRemoteUpdate。表示中のページでなければ無視（エンジンがファイルは書いている）
private func applyRemote(_ updated: InkPage) {
  guard updated.pageId == pageId else { return }
  let merged = InkPage.merge(page, updated)          // ペンを離した直後の未保存の線を落とさない
  guard merged.contentDiffers(from: page) || merged.updatedAt != page.updatedAt else { return }
  page = merged                                       // Binding を通さない（dirty にしない）
  if merged.contentDiffers(from: updated) {           // 端末内にしか無い線があった → いつもの経路で保存・送信
    pageDirty = true
    scheduleSave()
  }
  relayout()
}
```

- キャンバスは M3b のまま: 外から `page` が変わると `InkCanvasView.update(from:)` が `PageSignature` の違いを見て `ledger.reload(page:keepHistory: true)` → 履歴（↶ ↷）は残る。ペンが触れている間は描画の作り直しだけ 300 ms 後まで待つ（既存の `pendingDrawing` の経路）。
- 投げなわの選択は **明示的に解除しない**（`selection = nil` は書かない）。キャンバス側の `refreshSelection`（M3b。描画の作り直しの後に呼ばれ、生きていない id を落とす）に任せる: 他端末が消した線だけ選択から外れ、残りの選択は保たれる。`CalendarRootScreen.selection` は `selectionChanged` のコールバックで追いつく。
- undo で「別の端末が消した線」を戻すと新しい id の複製になる（M2 の規則）。これは仕様。
- 同期で来た線は `inkBottoms` を変えるので `relayout()`（行が伸びる）。

**`InkLedger.reload` の修正（担当 U、`Ink/InkLedger.swift`。M4 で必須）**: M3b の `reload(page:keepHistory:)` は `fingerprintToId` と `builtIds` を空にする。ペンが紙に触れている間に遠隔更新が来ると、`update(from:)` → `reload` の後、ペンを離した瞬間の `canvasViewDrawingDidChange` → `applyCanvasChange(canvas.drawing)` が **空の指紋表** に対して差分を取り、キャンバス上の全線を「新しい線」として **新しい id で二重に足す**（`publishPage` → `sync.save` → iCloud → 全端末へ広がる。merge では消せない）。M3b では外からの reload が設定を開いている間だけだったので顕在化しなかったが、M4 ではサイレントプッシュ・前面復帰の pull が書いている最中に来る。
修正: `reload(page:keepHistory:)` は **`fingerprintToId` / `builtIds` を触らない**（この 2 つは「キャンバスがいま表示している線」の表であって page の表ではない。`drawing()` が page から作り直す）。こうすると、ペンを離したときの `applyCanvasChange` はキャンバスにある線を全部「既知」として扱い（他端末が消した線がキャンバスに残っていても既知なので復活しない）、新しく描いた 1 本だけが `added` になる。300 ms 後の `applyPending` が `drawing()` で表と画面を page に合わせる。履歴・`bind(to:)`・`relayout` は変えない。検査は §8.3。

### 5.5 dirty の帳簿の約束

「dirty に積む」のは `save`（端末内に書けたときだけ）・`importPages`・`adoptAccount`・`resetAfterZoneLoss`・`start`（`seen` に無い端末内ページ）・`pageOpened`/`pull` で「端末内にしか無い線があった」とき。「dirty から外す」のは `push` の成功（その後に同じページの `save` が無かったとき）・`pull` の `deletedNames`・全消去。世代番号: `SyncEngine` は `pageGeneration: [String: Int]` を持ち、`save` で +1、`push` は送る前の番号を控えて成功後に同じなら `clearDirty`。

## 6. 画面（担当 U）

### 6.1 ヘッダーの同期の状態（`Views/PageHeaderView.swift`、文言は `Sync/SyncStatus.swift` の S が実装）

```
幅 ≥ 600 pt:  ◀  今日  ▶   題名              [日 | 週 | 月 | 年]   ＋予定   ☁ 保存済み   ⚙
幅 < 600 pt:  ◀  今日  ▶   題名                                    ＋予定   ☁   ⚙
              [      日      |      週      |      月      |      年      ]
```

```swift
struct PageHeaderView: View {
  // M3b の引数はそのまま。sync nil なら ☁ を出さない（スクリーンショットの 4 ページでは出す）。幅 < 600 pt では symbol だけ
  var sync: HeaderSync?            // SyncStatus.header（§4.4）
  var onSyncTap: () -> Void        // 設定画面を開く（showSettings = true）
}
```

| status | header.text | header.symbol | settingsText | settingsFooter |
| --- | --- | --- | --- | --- |
| `.synced` | 保存済み | `icloud` | 同期済み | 手書きはこの iPad と、あなたの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きが見られます。 |
| `.pending` | 同期中 | `icloud` | 同期中… | 書いた手書きを iCloud へ送っています。 |
| `.syncing` | 同期中 | `arrow.triangle.2.circlepath.icloud` | 同期中… | 同上 |
| `.offline` | オフライン | `icloud.slash` | オフライン | オフラインです。手書きはこの iPad に保存され、接続が戻ると同期されます。 |
| `.localOnly(.noAccount)` | この iPad のみ | `icloud.slash` | iCloud にサインインしていません | iCloud にサインインするとほかの端末と同期できます。手書きはこの iPad の中だけに保存しています。 |
| `.localOnly(.restricted)` | この iPad のみ | `icloud.slash` | この iPad では iCloud が制限されています | 手書きはこの iPad の中だけに保存しています。 |
| `.localOnly(.unknown)` / `(.notAuthenticated)` | この iPad のみ | `icloud.slash` | iCloud を確認できません | iPad の設定で iCloud を確認してください。手書きはこの iPad の中だけに保存しています。 |
| `.error(.quota)` | エラー | `exclamationmark.icloud` | iCloud の容量が足りません | iCloud の容量が不足しているため、手書きを同期できません。この iPad には保存されています。 |
| `.error(.permission)` | エラー | `exclamationmark.icloud` | iCloud を使えません | iCloud の設定でこのアプリの利用が許可されていません。 |
| `.error(.server(m))` | エラー | `exclamationmark.icloud` | 同期に失敗しました | 手書きの同期に失敗しました。この iPad には保存されています（あとで再試行します）。\n{m} |
| `.accountMismatch` | 停止中 | `person.crop.circle.badge.exclamationmark` | 別の iCloud アカウントです | この iPad の手書きは、前に同期していた iCloud アカウントのものです。「新しいアカウントで使い始める」から選んでください。 |

- `header.isError` は `.error(*)` と `.accountMismatch` で true（それ以外 false）。
- ☁ は `Button`（`.buttonStyle(.plain)`、`.font(.footnote)`、`.foregroundStyle(.secondary)`、`isError` は `.red`、accessibilityLabel 「同期: {header.text}」）。幅 < 600 pt では記号だけ。
- 1 秒に何度も変えない: `snapshot.status` の変化で描き直すだけ（エンジンが同じ値を発行しない）。

### 6.2 設定画面（`Views/SettingsScreen.swift`）

```swift
struct SettingsScreen: View {
  @ObservedObject var model: EventStoreModel; @ObservedObject var sync: SyncEngine; @Binding var allowFinger: Bool
  var onRequestAccess: () async -> Void
  var onSyncNow: () -> Void                 // Task { await sync.syncNow() }
  var onImportWeb: () -> Void               // 設定を閉じてから CalendarRootScreen がファイル選択を出す（§6.3）
  var onEraseAllInk: () -> Void             // 2 回目の確認のあと（§6.2 の全消去）
  var onResolveAccountChange: () -> Void    // §6.4 の問い合わせを出す
  var onDone: () -> Void
}
```

| Section | 行 | 動き・文言 |
| --- | --- | --- |
| 「同期」 | 「iCloud 同期」右に `status.settingsText`（`.secondary`。`isError` は赤） | footer は `status.settingsFooter` |
| | 「最後に同期」右に時刻（`lastSyncAt` を `Date.FormatStyle(date: .numeric, time: .shortened)`。日本語の iPad では「2026/10/07 9:57」、CI の英語ロケールでは「10/7/26, 9:57 AM」。nil なら「まだありません」） | |
| | ボタン「今すぐ同期」 | `onSyncNow`。`localOnly` / `accountMismatch` / `syncing` は無効。押したら 1 秒だけ `ProgressView` |
| | （`accountMismatch` のときだけ）ボタン「新しいアカウントで使い始める…」 | `onResolveAccountChange` |
| 「データ」 | 「Web 版の手書きを取り込む」 | `onImportWeb`。footer「Web 版の設定で「手書きを書き出す（iPad アプリ用）」をして、そのファイルを選びます。同じファイルを二度取り込んでも手書きは二重になりません。」＋ `webImportedAt` があれば「前回の取り込み: 2026/10/14 9:41」 |
| | 「手書きを書き出す」 | **「準備中」のまま**（M5 以降） |
| | 「この iPad の手書きを全て消す」（`.destructive`） | 1 回目 `confirmationDialog`: iCloud が使える状態なら「この iPad と iCloud に保存した手書きを全て消しますか？」、`localOnly` なら「この iPad に保存した手書きを全て消しますか？」（「消す」destructive）→ 2 回目 `alert`「本当に消しますか？」「この操作は元に戻せません。ほかの iPad や iPhone の手書きも消えます。」（localOnly では後半の文を出さない）（「全て消す」destructive／「キャンセル」）→ `onEraseAllInk` |
| 「情報」 | 「バージョン」 | 「0.5.0 (1)」 |

全消去の流れ（CalendarRootScreen）: 設定を閉じる → `saveTask` を止める → `page = InkPage.empty(pageId:)`、`pageDirty = false`、`selection = nil`、`relayout()` → `Task { try await sync.eraseEverything() }` → 成功でトースト「手書きを全て消しました」。throw → トースト（エラー）「iCloud の手書きを消せませんでした。この iPad の分は消しました。回線が戻ったらもう一度お試しください」（エンジンが次回やり直す）。スクリーンショットモードは `page` を空にするだけ。

「カレンダー」「入力」「購入」の節は M3b のまま。

### 6.3 Web 版の手書きを取り込む（`Views/WebImportSheet.swift`、流れは CalendarRootScreen）

```swift
import UniformTypeIdentifiers
/// UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText], asCopy: true) の包み
/// （「ファイル」アプリが書き出しをテキスト扱いすることがあるので .plainText も）
struct DocumentPickerView: UIViewControllerRepresentable { var onPick: (URL) -> Void; var onCancel: () -> Void }
/// reading = ファイルを読んでいる／importing = 取り込み中／done・failed = 結果
enum WebImportPhase: Equatable { case reading, importing(done: Int, total: Int), done(ImportOutcome, skipped: Int), failed(String) }
struct WebImportSheet: View { var phase: WebImportPhase; var onClose: () -> Void }
```

1. 設定「Web 版の手書きを取り込む」→ `showSettings = false` → 0.35 秒後に `showImportPicker = true`（`.sheet` で `DocumentPickerView`）。
2. `onPick(url)`: `url.startAccessingSecurityScopedResource()`、`Data(contentsOf:)`（`asCopy: true` なので tmp の複製）、`importPhase = .reading` の `WebImportSheet` を出す。
3. `WebImport.parse(data)`: `ParseError.notAnExport` → `.failed("このファイルは Web 版の書き出しではありません")`、`.unsupportedVersion(v)` → `.failed("このファイルは新しい形式です（v\(v)）。アプリを更新してください")`、`.invalidJSON` → `.failed("ファイルを読めませんでした")`。
4. `WebImport.convert(doc)` → `conversion.pages` が空なら `.done(ImportOutcome(pagesChanged: 0, strokesAdded: 0, pagesSeen: conversion.pageCount), skipped: conversion.skipped.count)`。
5. `try await sync.importPages(conversion.pages, progress:)` → `.importing(done, total)` を進める → `.done(outcome, skipped: conversion.skipped.count)`。throw → `.failed("保存できませんでした: \(error.localizedDescription)")`。
6. 結果の文言（シートの本文。閉じたあと同じ文をトーストに）:
   - `pagesChanged > 0`: 「Web 版の手書きを取り込みました（{pagesChanged} ページ・{strokesAdded} 本）」
   - `pagesChanged == 0`（全部取り込み済み）: 「取り込むものはありませんでした（すべて取り込み済みです）」
   - skipped があれば 2 行目に「{skipped} ページは対象外のため飛ばしました」（`.footnote` `.secondary`）
7. 見た目: `NavigationStack` + `VStack`。題「Web 版の手書きを取り込む」。`.reading` / `.importing` は `ProgressView(value: done, total: total)`（reading は不定）と「取り込んでいます… {done} / {total} ページ」。`.done` はチェックの記号と文言、「閉じる」。`.failed` は赤い記号と文言、「閉じる」。`interactiveDismissDisabled` は取り込み中だけ。
8. 表示中のページが取り込まれたら `onRemoteUpdate` 経由で描き直る（§5.4）。

### 6.4 アカウント切替の問い合わせ（`Views/AccountChangeDialog.swift`）

`extension View { func accountChangeDialog(isPresented: Binding<Bool>, onChoose: @escaping (AccountChangeChoice) -> Void) -> some View }`

- `confirmationDialog`。題「別の iCloud アカウントです」、message「この iPad の手書きは、前に同期していた iCloud アカウントのものです。いまサインインしているアカウントで使い始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。」
- ボタン: 「手書きを残して使い始める」→ `.keepInk`／「手書きを消して使い始める」（destructive）→ 続けて `alert`「本当に消しますか？」「この iPad の手書きを全て消して、新しいアカウントで始めます。この操作は元に戻せません。」（「消して始める」destructive／「キャンセル」→ `.later`）→ `.eraseInk`／「あとで」（cancel）→ `.later`。
- 出すとき: `sync.snapshot.status == .accountMismatch` になった最初の 1 回（`onChange(of: sync.snapshot.status)`）と、設定の「新しいアカウントで使い始める…」。シートが出ている間は出さない（閉じた後に出す）。
- `onChoose` → `Task { await sync.resolveAccountChange(choice) }`。`.keepInk` / `.eraseInk` のあと、表示中のページを `sync.load(pageId)` で読み直す（`.eraseInk` は空になる）。

### 6.5 初回案内の 4 枚目（`Views/OnboardingView.swift`。DESIGN §2.10）

4 枚目を **最後** に足し、「許可の画面を出す」のボタンは 4 枚目に移す（1〜3 枚目は「次へ」）。

- 記号 `icloud`、題「iCloud と手書きの保存」、本文「手書きはこの iPad と、あなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きが見られます。\n\niCloud にサインインしていないときは、この iPad の中だけに保存します。iCloud の設定は要りません（iPad でサインインしていれば自動で使われます）。\n\n手書きは開発者には見えません。iCloud の容量はあなたのものを使います。」
- iCloud の許可ダイアログは無い（プライベート DB は本人の iCloud なので OS の確認は出ない）。
- `index < 3` で「次へ」、`index == 3` で「許可の画面を出す」。既存の 3 枚の文面は変えない。

### 6.6 スクリーンショットモード（`Support/ScreenshotMode.swift`）

```swift
enum ScreenshotMode {
  enum Sheet: String, CaseIterable, Sendable { case create, edit, lasso, settings, sync, `import` }
  static func demoLastSyncAt(for today: Date) -> Date        // 「保存済み」の見本: today − 180 s（10:00 の 3 分前 = 9:57）
  static let importDemoOutcome = ImportOutcome(pagesChanged: 12, strokesAdded: 348, pagesSeen: 12)
}
```

| `--screenshot-sheet` | ページ | 出すもの |
| --- | --- | --- |
| `sync` | month | `SettingsScreen`（M3b の `settings` と同じ）。エンジンは `SyncEngine.screenshotDemo(now:)`: `InMemoryCloudDatabase`、`snapshot = (.synced, lastSyncAt: demoLastSyncAt(today), dirtyCount: 0, webImportedAt: nil)`。「同期」の節に「同期済み」「最後に同期 {9:57 を含む時刻}」「今すぐ同期」が見える（CI は英語ロケールなので「10/7/26, 9:57 AM」。`settings` のシートとの違いはこの節だけなので、**`settings` のシートも同じエンジンで撮る**: M3b の「準備中」は無くなる） |
| `import` | month | `WebImportSheet(phase: .done(ScreenshotMode.importDemoOutcome, skipped: 0))`（「Web 版の手書きを取り込みました（12 ページ・348 本）」） |

- `SyncEngine.shared` はスクリーンショットモードでは `screenshotDemo(now: ScreenshotMode.current!.today)`（§4.4 の (a)。S が `ScreenshotMode.isActive` を見て分ける）。`start()` は何もしない。`save` / `pageOpened` / `syncNow` は何もしない。4 ページのスクリーンショットのヘッダーにも「☁ 保存済み」が写る。
- CI は iCloud に触らない（偽物だけ）。`UIApplication.registerForRemoteNotifications()` は `SyncEngine.usesCloudKit` が true のときだけ（§6.7）。

### 6.7 App.swift と AppDelegate（`Support/AppDelegate.swift`）

```swift
final class AppDelegate: NSObject, UIApplicationDelegate {
  // didFinishLaunching: SyncEngine.usesCloudKit なら application.registerForRemoteNotifications()。SyncEngine.shared.start()（ここが唯一の呼び出し。App.swift では呼ばない）
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
  // await SyncEngine.shared.handleRemoteNotification(userInfo) ? .newData : .noData（最長 20 秒で返る。§4.4）
  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)   // 記録だけ（シミュレータでは必ず来る）
}
@main struct TegakiCalendarApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  var body: some Scene { WindowGroup { ContentView() } }
}
```

- `didRegisterForRemoteNotificationsWithDeviceToken` は不要（CloudKit の購読はトークンを使わない）。
- 通知の許可（`UNUserNotificationCenter.requestAuthorization`）は **求めない**（サイレントプッシュは許可不要）。
- サイレントプッシュでバックグラウンド起動されたときは `didFinishLaunching`（`start()`）→ `didReceiveRemoteNotification` の順に来る。`start()` の 1 周が先に待ち行列に積まれ、通知の 1 周はその後ろ（§4.5 の 7。20 秒で返る）。
- 利用者がアプリを上スワイプで終了させた端末にはサイレントプッシュは届かない。低電力モード・バックグラウンド更新オフでも届かない。iOS はサイレントプッシュを 1 時間に数回程度に絞る。どれも **前面復帰の `syncNow` で追いつく** ので動作は同じ（docs/M4.md に書く。§8.4）。

### 6.8 iPhone

- ヘッダーは §6.1 の 2 段のまま。☁ は記号だけ（タップで設定）。
- 設定・取り込み・問い合わせの文言は iPad と同じ（「この iPad」は iPhone でも「この iPad」のまま。M3b と同じ扱い）。
- `WebImportSheet` は `.presentationDetents([.medium])`。

## 7. Web 版の書き出し（担当 W。`../tegaki-calendar`）

### 7.1 画面（`js/ui/settings.js`、`js/main.js`）

- 設定シートの「データについて」の **前** に節「データ」を足す: ボタン「手書きを書き出す（iPad アプリ用）」と、チェック「お試しモードの手書きも含める」（Google モード = `auth.signedIn` のときだけ出す。初期値オフ）。注記「全ページ・全端末の手書きを 1 つのファイルにまとめて保存します。iPad では「ファイル」アプリのダウンロードに入ります。」。**`auth.signedIn` も `auth.demo` も偽**（ようこそ画面 `S.mode === 'none'` から設定を開いた）なら「データ」の節自体を出さない。
- ボタンは `finish('exportInk')` で閉じ、結果は `{ settings, action: 'exportInk', includeDemo: boolean }`。`SETTINGS_TEXT` に `data: 'データ'`、`exportInk: '手書きを書き出す（iPad アプリ用）'`、`exportIncludeDemo: 'お試しモードの手書きも含める'`、`exportHint` を足す。
- `main.js` の `settingsFlow` に `case 'exportInk': await exportInkFlow(Boolean(result.includeDemo))`。
- `exportInkFlow(includeDemo)`: トースト「手書きを集めています…」→ `collectAll({ drive: driveForInk(), kv: S.kv, demoKv: includeDemo ? await openKV({ dbName: INK_DB_NAMES.demo }) : null, onProgress })`（`driveForInk()` は main.js の既存の関数: Google モードで appdata スコープがあり `inkVerified` のときだけ `S.driveApi`、それ以外 null。`S.drive` という変数は無い）→ `buildExport({ pages, app: 'web/' + APP_VERSION, includesDemo })` → `JSON.stringify` を `Blob`（`application/json`）にして `<a download="tegaki-web-export-2026-10-14.json">` でダウンロード → トースト「手書きを書き出しました（{pages} ページ・{strokes} 本）」。ページが 0 なら「書き出す手書きがありません」。失敗は「書き出せませんでした: {message}」。オフライン（Google モードで Drive に届かない）は「オフラインのため、この端末にある分だけを書き出しました」を続けて出し、端末内の分だけで続行する。トーストは main.js の `notify(...)`（内部で `toast` を呼ぶ）経由。
- お試しモードのときはボタンだけ（Drive 無し、チェック無し）で、お試し DB の全ページを書き出す。

### 7.2 純粋な部分（`js/data/ink-export.js`、`js/google/drive.js`）

```js
export const EXPORT_FORMAT = 'tegaki-web-export'; export const EXPORT_VERSION = 1;
export const EXPORTABLE_ID_RE = /^(?:d-\d{4}-\d{2}-\d{2}|w-\d{4}-\d{2}-\d{2}|m1-\d{4}-\d{2}|y-\d{4})$/;
export function isExportablePageId(pageId)          // RE に合い、w- は月曜（Date の getDay() === 1）
export function exportFileName(date = new Date())   // 'tegaki-web-export-YYYY-MM-DD.json'（ローカル日付）
export function localIsoString(date)                // '2026-10-14T09:41:00.000+09:00'
export function buildExport({ pages, app, includesDemo = false, exportedAt = new Date() })
  // pages: PageDoc[]（同じ pageId は mergePages でまとめる）→ 生きている線だけ（serializePage と同じ形: strokes は id 順、
  // deleted は merge 後の墓標を id 順にそのまま。§1.3）、線の無いページと isExportablePageId でないページは落とす。
  // pages は pageId の文字列順。返り値は object（JSON.stringify は呼ぶ側）
export function parseExport(text)                   // 逆向き（検査と将来の「読み込み」用）: format / v を確かめ、各ページを deserializePage。駄目なら throw
export async function collectDrivePages(drive, { onProgress } = {})   // drive.listAllInkFiles() → page ごとに download → deserializePage → mergePages。Map<pageId, PageDoc>
export async function collectKvPages(kv)            // kv.keys('page:') → 各 'page:<id>' を deserializePage。Map
export async function collectAll({ drive = null, kv, demoKv = null, onProgress }) // 3 つを mergePages で合わせて PageDoc[]（pageId 順）
```

`drive.js` に `listAllInkFiles()` を足す: `listPageFiles` と同じ問い合わせで `q` を `appProperties has { key='schema' and value='1' }` に（全ページ・全端末。`nextPageToken` で全部回す、`MAX_PAGES` 200）。`DRIVE_METHODS`（ink-store.js）には **足さない**（ink-store は使わない。偽物の drive が壊れないように）。

### 7.3 検査（`npm test`。Node は `~/.local/node/bin`）

- `tests/ink-export.test.mjs`（新規）: `isExportablePageId`（`m1-2026-10` ○、`m-2026-09` ×、`w-2026-10-05`（月曜）○、`w-2026-10-04`（日曜）×、`y-2026` ○、`d-2026-10-07` ○、空 ×）／`exportFileName`／`localIsoString` のオフセット（TZ=Asia/Tokyo で `+09:00`）／`buildExport(見本 1 の pages, app: 'web/1.0.6', exportedAt: 固定)` が **見本 2 と同じ object** になる（`assert.deepEqual`。`m-2026-09` と空ページが落ち、pageId 順、墓標 `zz` が保たれる）／同じ pageId の 2 端末分が 1 ページに merge され、片方の墓標で消えた線は出ない（墓標は `deleted` に残る）／`parseExport(JSON.stringify(buildExport(...)))` の往復／`parseExport(見本 1)` が 6 ページに読める／`collectAll` を `createMemoryKV` と偽の drive（`listAllInkFiles` / `download`）で: Drive 2 端末 + kv + demo の merge、`includeDemo` 無しなら demo を含めない、`onProgress` の回数。
- `tests/drive.test.mjs` に `listAllInkFiles` の問い合わせ（`q`、`fields`、paging）。
- `tests/ui-logic.test.mjs` に `openSettings` の「手書きを書き出す（iPad アプリ用）」→ `{ action: 'exportInk', includeDemo }`、チェックの有無（`signedIn` のときだけ。`demo` のときは出ない）、`signedIn` も `demo` も偽なら「データ」の節が無い。
- `tests/app-shell.test.mjs`: 「version 1.0.6 everywhere」、`APP_FILES` に `js/data/ink-export.js`。
- `tests/fixtures/tegaki-web-export-sample.json`（見本 1）と `tests/fixtures/tegaki-web-export-expected.json`（見本 2）を置く（§1.4 と一字一句同じ）。

### 7.4 版の更新

`js/config.js` `APP_VERSION = '1.0.6'`、`sw.js` `VERSION = '1.0.6'`、`package.json` `"version": "1.0.6"`、`tests/app-shell.test.mjs` の文字列。`sw.js` の `APP_FILES` に `'js/data/ink-export.js'`。`docs/SPEC.md` §1 に `js/data/ink-export.js  D`、§4 D に上の API を写す。README の「設定」の説明に 1 行。

## 8. 検査

### 8.1 TegakiKit（担当 K）: `KitChecks` に 3 節を足し、同じ内容を XCTest にも置く

| 節 | 内容 | 項目数の目安 |
| --- | --- | --- |
| `web import (M4)` | `WebImport.parse`: 見本 1（§1.4）が 6 ページに読める、見本 2 が 4 ページに読める、`format` 違い → `.notAnExport`、`v: 2` → `.unsupportedVersion(2)`、壊れた JSON → `.invalidJSON`、壊れた線（tool 不明・pts 2 個・id 空・id 129 字）は落ちる、p の clamp と非数 0.5、size の clamp（0.05 → 0.1、500 → 200）と既定（非数・0・負 → pen 3.5 / highlighter 18）、連続する同じ点の除去、`|座標| > 100000` の点は落ちる／`PageId.parse`: 4 形式、`m-`・日曜 `w-`・`y-26`・空 → nil／`cell(for:center:)`: 月（§1.4 の a1 と b2、紙の外 (−5, −5) → 行 0 列 0 = 9/28、(1400, 1049.9) → 行 5 列 6 = 11/8、(700, 1050) → memo）、週・日は常に grid、年（e5、日付帯 (10, 30) → 01-01、(1399, 1859) → 12-31、(1399, 5000) → 12-31、2/30 のマスにも入る）／`nibSize`（3.5×p 0.4/0.6/0.8 = 2.66/3.29/3.92、2×1 = 2.6、6×0.5 = 5.1、highlighter は size）／`convert(stroke:)` の全属性（§1.4 の表の値）／`convert(_:)` が §1.4 の結果（見本 1: pages 4・strokeCount 5・skipped 2。見本 2: pages 4・strokeCount 5・skipped 0。両者の pages を pageId で整列して等しい）／**冪等**: `merge(convert, convert)` の生きている線の数が変わらない、iPad で消した線（墓標を足した page に merge）は戻らない／`updatedAt = max(Web, t)` | 約 160 |
| `sync state (M4)` | `SyncState.empty` の JSON、§1.1 の例の往復（`jsonValue` → `init(json:)` が同じ）、未知の項目を書き戻す、`dirty` の重複除去、`markDirty` の順序・`clearDirty`、`seen` の壊れた項目を捨てる、`adoptAccount`（dirty が全ページ、token/seen が空、webImportedAt は保つ）、`resetAfterErase`、`resetAfterZoneLoss`（account / pendingCloudErase / webImportedAt は保つ）、`SyncStateCodec` の decode が JSON でなければ throw、鍵の整列 | 約 45 |
| `sync backoff (M4)` | `delay(afterFailures:)` が 0…7 で 15, 30, 60, 120, 240, 300, 300, 300、`nextDelay(serverHint: 600)` = 600、`serverHint: 1` = 15、`recordFailure` の上限 30、`reset`、定数（1.5 / 15 / 300 / 3 / 30 / 20） | 約 20 |

`KitChecks` の合計は M3b の 20240 項目に **約 225 項目** を足したものになる（正確な数は K が実装後に docs/M4.md と README に書く。この契約は「20400 以上」を求め、CI が数字で確かめる。§8.4）。XCTest: `WebImportTests.swift`（見本 1・2 は Swift の文字列リテラルで持つ。§1.4 と一字一句同じ）、`SyncStateTests.swift`。

### 8.2 アプリ・同期（担当 S。シミュレータ、偽物の DB だけ。iCloud 不要）

**テスト用の sleep（`Tests/TegakiCalendarTests/TestSleeper.swift`）**:

```swift
@MainActor final class TestSleeper {
  private(set) var recorded: [TimeInterval]   // sleep が呼ばれた長さ（順）
  var autoResume = false                      // true なら記録して即時に返す
  var waiting: Int { get }                    // いま止まっている sleep の数
  func sleep(_ d: TimeInterval) async         // recorded.append(d) → autoResume でなければ advance() まで suspend
  func advance()                              // 止まっている sleep を全部返す（1 回で全部）
}
```

エンジンには `sleep: sleeper.sleep` を渡す。検査の基本形は「操作 → `await engine.waitUntilIdle()`（§4.4。sleep で止まっているものは待たない）→ 確かめる → `sleeper.advance()` → `waitUntilIdle()` → 確かめる」。`clock` は固定。`InMemoryCloudDatabase` と一時ディレクトリの `InkPageStore`。

`InkPageRecordTests`: `make` の fields（schema / updatedAt / strokeCount / doc / app）、`doc` が端末内ファイルと同じバイト列（`compress(encode)`）、`page(from:)` の往復、`doc` 無し → throw、JSON の pageId が空なら recordName、`seen` の写し、`makeMeta` が nil の項目を書かない、`metaValues`。
`SyncStateStoreTests`: 無ければ empty、保存 → 読む、壊れたファイルは `.bak` に退避、`remove`、既定の `fileURL` が `InkPageStore().stateFileURL`。
`CloudKitDatabaseMapTests`（`NSError(domain: CKErrorDomain, code:userInfo:)` で作れるので CloudKit の往復なしに検査できる）: `map` の全分岐（`.networkUnavailable` / `.networkFailure` → `.networkUnavailable`、`.notAuthenticated`、`.unknownItem` → `.recordNotFound`、`.zoneNotFound` / `.userDeletedZone` → `.zoneMissing`、`.changeTokenExpired`、`.quotaExceeded`、`.zoneBusy` + `CKErrorRetryAfterKey: 120` → `.retryLater(after: 120)`、`.accountTemporarilyUnavailable` → `.retryLater(after: nil)`、`.limitExceeded`、`.permissionFailure` / `.managedAccountRestricted` → `.permissionFailure`、`.badContainer` / `.missingEntitlement` / `.invalidArguments` / `.serverRejectedRequest` → `.configuration`、`.internalError` → `.other`）、`partialFailure` の `CKPartialErrorsByItemIDKey` の中の `serverRecordChanged`（`CKRecordChangedErrorServerRecordKey` の `CKRecord(recordType: "InkPage", recordID:)` が `CloudRecord` になる）と `unknownItem` の区別、`URLError.notConnectedToInternet` → `.networkUnavailable`、`subscriptionID(in: [:]) == nil`。`encodeToken` / `decodeToken` は `CKServerChangeToken` を手で作れないので検査しない（実機。§9）。

`SyncEngineTests`:

| # | 検査 | 期待 |
| --- | --- | --- |
| 0 | テストホストの `SyncEngine.shared` | `SyncEngine.isTestHost == true`、`SyncEngine.usesCloudKit == false`、`SyncEngine.shared.database is InMemoryCloudDatabase`（ホストアプリの起動で `CKContainer` が作られていない） |
| 1 | `start()` でアカウント無し | `.localOnly(.noAccount)`、DB の呼び出しは `accountStatus` だけ、`save` は dirty に積むだけ |
| 2 | `start()` で available | `userRecordName` が state.account に、`ensureZone` → `ensureSubscription` → `fetchChanges` の順、`.synced`、`lastSyncAt` が進む |
| 3 | `save` → デバウンス → push | `save` → `waitUntilIdle` → `.pending`、`recorded == [1.5]`、DB の `save` はまだ無い → `advance()` → `waitUntilIdle` → `records["m1-2026-10"]` に Asset、`seen` に tag、dirty が空、snapshot の履歴に `.pending` → `.syncing` → `.synced` |
| 4 | 連続 `save` が 1 回にまとまる | `advance()` を呼ぶ前に 5 回 `save` → `waitUntilIdle` → `recorded == [1.5]`（Task は 1 本）→ `advance()` → `waitUntilIdle` → `recorded == [1.5, 1.5]`（世代が進んでいたのでもう 1 回）→ `advance()` → `waitUntilIdle` → `calls` の `.save` は 1 回 |
| 5 | 送信中に再び `save` | `db.pause(.save)` → `save`(v1) → `advance()` → push が DB の `save` で止まる → `save`(v2) → `db.resume()` → `waitUntilIdle` → 世代が違うので dirty が残り、デバウンス無しでもう 1 回送られる（`.save` 2 回）、最後は dirty 空・`.synced` |
| 6 | 衝突 | 別端末が先に書いた（`simulateRemoteSave`）→ `.serverRecordChanged` → merge（両方の線が残る）→ 再保存 1 回で成功、端末内ファイルも merge 済み、表示中なら `onRemoteUpdate` |
| 7 | 衝突が 4 回続く | 3 回で諦めて dirty のまま、`.pending`、backoff の待ち（`recorded` の末尾が 15） |
| 8 | `pull` が別端末の線を取り込む | `simulateRemoteSave` → `syncNow()` → ファイルに merge、`onRemoteUpdate`（表示中のページだけ）、`seen` と `zoneToken` 更新 |
| 9 | 自分が送ったレコードは pull で飛ばす | tag が `seen` と同じ → `onRemoteUpdate` が呼ばれない |
| 10 | 端末内にしか無い線を pull/pageOpened が見つける | dirty に積まれ、次の push で送られる |
| 11 | `deletedNames` | 端末内ファイルが消え、表示中なら空ページで `onRemoteUpdate` |
| 12 | `changeTokenExpired` | token を捨てて全件を 1 回やり直す、結果は同じ |
| 13 | `networkUnavailable` | `failNext[.save]` → `.offline`、dirty 保持、`recorded` の末尾が 15 → `advance()` → 再試行で成功 → `.synced`。2 回失敗で 30、成功で reset |
| 14 | `quotaExceeded` | `.error(.quota)`、自動再試行しない（`recorded` に backoff が増えない）、`syncNow` で再試行 |
| 15 | `retryLater(after: 120)` | `recorded` の末尾が 120 |
| 16 | ゾーン消失 | `db.simulateZoneDeleted()` → `syncNow()` → `.zoneMissing` → `resetAfterZoneLoss`（`seen` 空、dirty が全端末内ページ、`zoneToken` nil）→ `ensureZone` → `ensureSubscription` → `fetchChanges` → 全ページが新規として送られ `.synced` |
| 17 | `pageOpened` | `fetchRecords` 1 回、30 秒以内の再入で呼ばれない、無いページで何もしない、tag が同じなら何もしない |
| 18 | `handleRemoteNotification` | `["subscriptionID": "tegaki-zone-changes"]` で `syncNow` が走り、pull が変更を取り込めば true／`[:]` で false（DB を呼ばない）／`db.pause(.fetchChanges)` で 1 周が終わらなくても `recorded` に 20 が入り、`advance()` で false が返る（その後 `resume()` で 1 周は完走する） |
| 19 | アカウント切替（別の人） | `simulateAccountChange(userName: "_user-b")` → `.accountMismatch`、`pendingAccount`、`save` しても送らない |
| 20 | `resolveAccountChange(.keepInk)` | 全ページが dirty → 新アカウントへ送られる、token/seen が空から |
| 21 | `resolveAccountChange(.eraseInk)` | 端末内が空、state が新アカウント、以後の pull で向こうの線が来る |
| 22 | サインアウト → 同じアカウントに戻る | `.localOnly(.noAccount)` → `.synced`、account は変わらない、dirty は送られる |
| 23 | `eraseEverything` | 端末内 0 件、DB の `InkPage` が全部 `delete`（201 件なら 200 + 1 の 2 回。`fetchChanges` は `namesOnly`）、`Meta` は残る、state が `resetAfterErase`。`seen` にだけある名前（他端末が消した）が混ざっていても成功 |
| 24 | `eraseEverything` の途中で回線が切れる | throw、`pendingCloudErase == true`、次の `syncNow` で削除をやり直してから pull |
| 25 | `importPages` | 2 ページ・3 本 → `ImportOutcome(pagesChanged: 2, strokesAdded: 3, pagesSeen: 2)`、dirty に 2 ページ、`Meta.webImportedAt` が書かれる、同じ入力の 2 回目は `(0, 0, 2)` |
| 26 | `importPages` の表示中ページ | `onRemoteUpdate` が merge 済みで呼ばれる |
| 27 | `screenshotDemo` | `.synced`、`lastSyncAt = now − 180`、`start`/`save`/`syncNow` が DB を呼ばない |
| 28 | `start()` 前の `save` | dirty に積まれ、`start()` の push で送られる |
| 29 | `pendingCloudErase` 中は pull しない | `fetchChanges` が delete より後にだけ呼ばれる |
| 30 | `Meta` の衝突 | サーバーの `trialStartedAt` を保ったまま `webImportedAt` だけ更新 |
| 31 | 他端末の全消去の後に古い `seen` で保存 | `records` からそのページを消して（`simulateRemoteDelete`。`seen` は残す）`save` → push → `.recordNotFound` → `seen[id] = nil` で新規として成功、`records` に戻る |
| 32 | 初回 `start` がオフライン | `failNext[.userRecordName] = .networkUnavailable` → `.offline`、`state.account == nil`、`fetchChanges` も `save` も呼ばれない → `save` → `advance()`（backoff）→ `syncNow` 相当の再試行で `userRecordName` → account が記録されてから push |
| 33 | `start()` が `seen` に無い端末内ページを dirty に足す | 状態ファイル無し・端末内 2 ページで `start()` → 2 ページが送られる |
| 34 | `stateStore.save` の失敗 | 書けない場所（読み取り専用のディレクトリ）でも `save` は throw しない、dirty はメモリに残り push される |
| 35 | `configuration` | `failNext[.save] = .configuration("x")` → `.error(.server("x"))`、自動再試行しない、`syncNow` で再試行 |
| 36 | `start()` の冪等 | 2 回呼んでも `accountStatus` は 1 回 |

### 8.3 アプリ・画面（担当 U）

- `ScreenshotModeTests` に追加: `--screenshot-sheet sync` / `import` が読める（不正値は nil のまま）、`demoLastSyncAt(today) == today − 180`、`importDemoOutcome` の数字、`Sheet.allCases.count == 6`。`WebImportSheet` と `AccountChangeDialog` は純粋な状態が無いので検査しない（文言はこの契約）。
- `InkLedgerTests` に追加（§5.4 の `reload` の修正）: (1) 線を 2 本持つ page で `drawing()` を作り、`reload(page: 別の線を 1 本足した page, keepHistory: true)` の直後に **同じ drawing** で `applyCanvasChange` → `added` も `removedIds` も空。(2) `reload(page: 1 本を墓標にした page, keepHistory: true)` の直後に、消えた線がキャンバスに残ったまま新しい線を 1 本足した drawing で `applyCanvasChange` → `added` は 1 本だけ、消えた線は `page.strokes` に戻らない（墓標のまま）。(3) その後 `drawing()` を作り直すと、墓標の線は無く、新しい線と遠隔の線が入っている。

### 8.4 CI・統合（担当 C）

- `project.yml`: `MARKETING_VERSION: "0.5.0"`。`targets.TegakiCalendar.settings.base` に `CODE_SIGN_ENTITLEMENTS: Support/TegakiCalendar.entitlements`。`info.properties` に `UIBackgroundModes: [remote-notification]`。`.gitignore` は変更なし（entitlements はコミットする）。
- `Support/TegakiCalendar.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.developer.icloud-container-identifiers</key> <array><string>iCloud.com.syfan0.tegakicalendar</string></array>
  <key>com.apple.developer.icloud-services</key> <array><string>CloudKit</string></array>
  <key>aps-environment</key> <string>production</string>
</dict></plist>
```

- `Sources/TegakiCalendar/PrivacyInfo.xcprivacy`（プライバシーマニフェスト。アプリは `UserDefaults`（Required Reason API）を使うので、宣言しないビルドは App Store Connect が ITMS-91053 で拒む。CloudKit 自体は対象外。`project.yml` の `sources` は `Sources/TegakiCalendar` ごとなので置くだけでリソースとして入る）:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key> <false/>
  <key>NSPrivacyTrackingDomains</key> <array/>
  <key>NSPrivacyCollectedDataTypes</key> <array/>
  <key>NSPrivacyAccessedAPITypes</key> <array><dict>
    <key>NSPrivacyAccessedAPIType</key> <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key> <array><string>CA92.1</string></array>
  </dict></array>
</dict></plist>
```

- `build.yml`: シミュレータのビルド・テストは `CODE_SIGNING_ALLOWED=NO` のまま（署名しないので entitlements は埋め込まれず、警告だけ。テストのホストアプリは §4.4 の (b) で `CKContainer` を作らない）。`Run KitChecks` のステップは出力を `tee` して数字で確かめる:

```bash
swift run --package-path TegakiKit KitChecks 2>&1 | tee kitchecks.log
N="$(grep -oE 'all [0-9]+ checks passed' kitchecks.log | grep -oE '[0-9]+' | tail -1)"
test "${N:-0}" -ge 20400
```

  シートのループを `create edit lasso settings sync import` の 6 つに。成果物に `ipad-portrait-sheet-sync.png`・`-sheet-import.png` が増える。
- `testflight.yml`: 手順は変えない。**本人が** App ID に iCloud（CloudKit、コンテナ）と Push Notifications を付けてプロファイルを作り直し、Secrets の `BUILD_PROVISION_PROFILE_BASE64` を更新する（古いプロファイルのままだと archive の署名で entitlements の不一致で失敗する）。`exportOptions` は `method: app-store-connect` のままで iCloud は Production。
- ローカル確認（この Mac）: `cd TegakiKit && swift build && swift run KitChecks`、`for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done`。`Sync/*.swift`・`Persistence/*.swift`・`Support/ScreenshotMode.swift` は **Catalyst SDK に対する型検査** ができる（2026-10-15 にこの Mac で確認済み: CloudKit・UIKit・UniformTypeIdentifiers・InkModel を使う試しのファイルと `Persistence/*.swift` が通る。`CloudKit.framework` は macOS SDK 本体に、`UIKit` / `PencilKit` は `System/iOSSupport` にある）:

```bash
SDK="$(xcrun --show-sdk-path)"
swift build --package-path TegakiKit --triple arm64-apple-ios17.0-macabi --product InkModel   # DayKit / Holidays / Layout / InkModel の .swiftmodule
MOD=TegakiKit/.build/out/Products/Debug-maccatalyst                                           # swift 6.4 の出力先（.build/debug は macOS 用）
xcrun swiftc -typecheck -swift-version 5 -sdk "$SDK" -target arm64-apple-ios17.0-macabi \
  -F "$SDK/System/iOSSupport/System/Library/Frameworks" -I "$MOD" \
  Sources/TegakiCalendar/Sync/*.swift Sources/TegakiCalendar/Persistence/*.swift Sources/TegakiCalendar/Support/ScreenshotMode.swift
```

  `Views/*`（SwiftUI）と `Tests/`（XCTest は Command Line Tools に無い）は CI のみ。S は契約の実装中にこのコマンドを通してから出す。
- 統合の順番: K（WebImport・SyncState・SyncBackoff）→ S と U と W（並行。S は **`Sync/SyncStatus.swift` の型群を最初に出す**（U の `ScreenshotMode.importDemoOutcome`・`WebImportSheet`・`PageHeaderView` がこれで型検査できる）。K の `SyncState` ができるまで `CloudDatabase`・偽物・`InkPageRecord` を先に。U は S の `SyncEngine` ができるまで `SyncSnapshot` の固定値と `SyncStatus.swift` の型で組む）→ C（entitlements・PrivacyInfo・project.yml・build.yml・docs/M4.md・README）。本番のコンパイルは CI。
- `README.md` の「いま出来ていること」（同期・取り込み・初回案内 4 枚・「まだ無いもの」から同期と取り込みを外す）と `docs/M4.md`（実装結果。M3B.md と同じ構成）は C が書く。`docs/M4.md` に必ず入れるもの: §2 に **CloudKit Console の手順**（§2 の表を写す）と **本人がやること**、「配備を忘れたときの症状」（§2.2）、「サイレントプッシュが届かないときの確認順: ① 設定 › 一般 › アプリのバックグラウンド更新がオン、② 低電力モードでない、③ アプリを上スワイプで終了していない、④ それでも前面復帰で 5 秒以内に追いつく。iOS はサイレントプッシュを 1 時間に数回程度に絞る」、「受け口は 20 秒で返す」、§9 の「シミュレータで確かめられないもの」を実機確認の表に写す。

## 9. 完了の定義

1. `swift run KitChecks` が「all N checks passed」（N ≥ 20400。CI が数字で確かめる）、`swift test` が緑。
2. CI の `build` が緑: シミュレータの XCTest（`SyncEngineTests` の 0〜36、`CloudKitDatabaseMapTests`、`InkLedgerTests` の追加分を含む）が通り、**XCTest のホストアプリが CloudKit を初期化しない**（`SyncEngineTests` の 0）、成果物に 10 枚（4 ページ＋ 6 シート）。4 ページのヘッダーに「☁ 保存済み」、`sheet-sync.png` に「同期済み／最後に同期（9:57 を含む時刻）／今すぐ同期」、`sheet-import.png` に「Web 版の手書きを取り込みました（12 ページ・348 本）」。
3. Web 版の `npm test` が緑（1.0.6）。GitHub Pages で設定の「手書きを書き出す（iPad アプリ用）」が JSON を保存できる。
4. 本人が Console でスキーマを作り Production に配備し、プロファイルを作り直して TestFlight に上げた後、**実機で**: iPad と iPhone で同じ手書きが見える（書いて 5 秒以内に相手の **前面復帰** で届く。サイレントプッシュは届けば自動で、届くことは保証しない）。機内モードで書いて「オフライン」→ 戻して「保存済み」。iCloud をサインアウトして「この iPad のみ」。Web 版で書き出したファイルを取り込み、月・週・日・年の 4 ページで Web 版と同じ位置に出る。同じファイルをもう一度取り込んで増えない。「全て消す」で両端末から消える。日本語の iPad で「最後に同期」が「2026/10/07 9:57」の形。ペンで書いている最中に相手の線が届いても線が二重にならない。
5. docs/M4.md・README が更新され、`MARKETING_VERSION` 0.5.0。

**シミュレータ（CI）で確かめられないもの**（実機だけ。docs/M4.md の確認表に写す）: 本物の `CKDatabase` の往復（保存・取得・削除・購読の作成）、`encodeToken` / `decodeToken`（`CKServerChangeToken` は手で作れない）、サイレントプッシュの配信とバックグラウンド起動、`.CKAccountChanged` の実際の通知（サインアウト・切替）、iCloud の容量不足、`userDeletedZone`（設定 › iCloud › ストレージでこのアプリのデータを消す）、Production にスキーマが無いときの誤りの文。

## 10. 本人の決定・未決

| # | 内容 | 既定（返事が無ければこうする） |
| --- | --- | --- |
| M4-1 | `Meta` に `trialStartedAt` を今から用意するか | **用意する**（M5 で型を変えられないため。M4 は書かない） |
| M4-2 | 「全て消す」でゾーンごと消す（速い・確実）か、`InkPage` だけ消す（`Meta` が残る）か | **`InkPage` だけ消す**（試用の開始日を失わないため） |
| M4-3 | 索引（`recordName` QUERYABLE、`updatedAt` SORTABLE）を Production にも配備するか | **配備する**（Console で中身を確かめられる。アプリの動作には不要） |
| M4-4 | ヘッダーの「保存済み」の文言（DESIGN §2.1 の「☁ 保存済み」か「同期済み」か） | **ヘッダー「保存済み」、設定「同期済み」**（ヘッダーは短く） |
| M4-5 | `aps-environment` を `production` 固定にするか（Debug 実機は Xcode が無いので無関係） | **production 固定** |
| M4-6 | 取り込んだ線の `dev` | **`"web"`**（端末ごとの id は Web 版の deviceId を使わない。書き出しは全端末を merge 済み） |
| M4-7 | 初回案内の 4 枚目の位置（最後） | **最後**。「許可の画面を出す」も最後に移す |
| M4-8 | 再インストール後の初回同期（全件）が終わるまでヘッダーに「同期中」を出すか | **出す**（`.syncing`） |
| M4-9 | 同じページを開き直したときの個別取得の間隔 | **30 秒** |
| M4-10 | Web 版の書き出しにお試しモードを含めるチェックの初期値 | **オフ** |
| M4-11 | エンジンの `save` を画面のデバウンス（1.5 秒）の後にさらに 1.5 秒待つ（合計 3 秒で iCloud へ） | **そのまま**（Web 版も 1.5 + α。短くしたければ画面側を 0 にする） |
| M4-12 | iPhone でヘッダーの ☁ を記号だけにする | **記号だけ** |
| M4-13 | `InkLedger.reload` の修正（§5.4）の担当 | **U**（`Ink/InkLedger.swift` と `InkLedgerTests.swift` を U の所有に足す。新しい担当 I は作らない。S は Ink/* を触らない） |
| M4-14 | サイレントプッシュの受け口が iOS に返すまでの上限 | **20 秒**（iOS の制限は約 30 秒。同期は待ち行列で続行） |
| M4-15 | Web 版の書き出しに墓標（`deleted`）を含めるか | **含める**（`serializePage` と同じ。Web で消した線が再取り込みで iPad に戻らないため。旧版の §7.2「deleted は {}」は誤りだったので直した） |
| M4-16 | `SyncEngine.save` でファイルの版と merge してから書く保険 | **入れる**（画面の `page` が遠隔更新を取りこぼしても線を消さない。普段は同じ内容。ファイルの読みが 1 回増えるが小さい） |
| M4-17 | プライバシーマニフェスト（`PrivacyInfo.xcprivacy`）を M4 で入れるか | **入れる**（`UserDefaults` の理由 CA92.1。C が entitlements と一緒に） |
| M4-18 | 他端末の全消去の後にこの端末で書いた手書き（`.recordNotFound`） | **新規として iCloud に戻す**（端末内が主。向こうの端末にも次の pull で届く） |

レビューの指摘のうち、そのまま採らず形を変えたもの（理由）:
- **指紋表の扱い（§5.4）**: 指摘の A 案「新しい page で生きている id の項目だけ残す」は採らない。他端末が消した線はキャンバスにまだ残っているので、その項目を落とすとペンを離した瞬間に「新しい線」と判定されて **消えた線が新しい id で復活** する。表を **一切触らない**（表はキャンバスの写し）のが正しく、`drawing()` の作り直しで page に揃う。B 案（`pendingReload`）は InkCanvasView の変更が大きく、InkLedgerTests で直接検査できないので採らない。
- **XCTest ホストの判定（§4.4）**: `SecTaskCopyValueForEntitlement` は iOS の公開 API に無いので使わない。`NSClassFromString("XCTestCase")` と環境変数で足り、build.yml の test ステップに環境変数や起動引数を足す必要も無い（`--no-icloud` は手元の保険として残す）。
- **`applyRemote` の選択解除（§5.4）**: 指摘の 2 案のうち「`refreshSelection` に任せる」を採った（`send(.clearSelection)` は他端末が触っていない線の選択まで外す）。
- **ヘッダーの引数（§6.1）**: タプル `(text:symbol:isError:)?` でなく構造体 `HeaderSync?` にした（`Equatable` にでき、S が文言と一緒に `SyncStatus.header` として出せる）。
- **`fetchChanges(since:namesOnly:)`（§4.1）**: プロトコルの要件は引数 2 つの 1 本にし、`namesOnly: false` の既定は extension で足した（`any CloudDatabase` の既存値引数はプロトコルに書けないため）。
- **KitChecks の閾値（§8.4）**: 正規表現でなく数字を取り出して `test -ge 20400` にした（指摘の正規表現は 20000〜20399 も通してしまう）。

本人がやること（Claude が代行できない）: (1) Developer サイトで iCloud コンテナ `iCloud.com.syfan0.tegakicalendar` を作り、App ID に iCloud と Push Notifications を付け、プロビジョニングプロファイルを作り直して Secrets を更新する。(2) CloudKit Console で §2.2 の 2 つのレコード種別と索引を Development に作り、「Deploy Schema Changes to Production」。(3) TestFlight で §9 の 4 を確かめる。(4) Web 版で「手書きを書き出す」→ iPad で取り込み、ずれが無いか見る。
