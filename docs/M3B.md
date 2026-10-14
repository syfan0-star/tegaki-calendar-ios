# M3b の実装結果（予定の作成・編集・削除、予定ツール、投げなわ、設定画面、iPhone の見た目）

[M3B_CONTRACT.md](M3B_CONTRACT.md) の契約を実装した結果のまとめです。設計の根拠は [DESIGN.md](DESIGN.md)（§2.7 ヘッダーとツールバー、§2.8 設定画面、§2.11 iPhone、§3.6 道具、§3.7 マスをまたぐ場合、§3.13 元に戻す、§4.3 カレンダーの選択、§4.5 予定の作成、§4.6 編集・削除）。[M3A.md](M3A.md) の続きで、M2・M3a で出来ていたこと（4 ページ・手書き・予定の読み取り）はそのまま生きています。
ブランチ `m3b`。`main` への取り込みはリード（本人）が行います。

本人の決定どおり: 誰でも作成・編集できる（閲覧専用モードは M5）、「予定にした手書きを消す」の既定はオン、月の時間指定チップは 1 日 3 件まで、15 分丸めは両端とも最寄り。

## 1. 作ったもの

### 1.1 TegakiKit（ローカル Swift パッケージ。Foundation だけに依存）

| ファイル | 内容 |
| --- | --- |
| `Layout/EventRange.swift` | `EventRange`（終日は翌 0 時が排他の end、時間指定は同じ日の中）、`EventGeometry`（Web 版 `page-geometry.js` の丸め: `roundMinutes` の 1e-9 の救済、`minutes(forY:)` の clamp、`timelineSlot`（高さ 12 lu 未満はタップ → 30 分の床から 1 時間、それ以外は両端を最寄りの 15 分、30 分未満は 1 時間、24:00 で clamp）、`normalized`）。`PageLayout` の既定実装 `eventRange(for:now:)` / `snapRect(for:)` / `previewRect(for:now:)` |
| `Layout/PageLayout.swift` | 要件に `eventRange(for:now:calendar:)`（矩形 → 予定の範囲。紙の外は一番近いマス・列に寄せる）と `snapRect(for:calendar:)`（予定の範囲 → 紙の矩形。別の週・年なら nil）を追加 |
| `Layout/MonthPageLayout.swift` | 中心のマスの終日。メモ欄（紙の下の外も）は「今日がその月なら今日、違えば 1 日」。`snapRect` はその日のマス |
| `Layout/WeekLayoutEngine.swift` | `nearestColumn(atX:)`（時刻帯と紙の外も一番近い列）。中心の列 × `timelineSlot`（y は帯の分を引く）。`snapRect` は列 × 分（翌日にかかる予定は 24:00 で切る） |
| `Layout/DayLayoutEngine.swift` | 列は常に時間軸（メモ欄・時刻帯で始めても同じ日）。`snapRect` は x 72〜660 × 分 |
| `Layout/YearLayoutEngine.swift` | 中心の月（日付帯と左の外は 1 月、右の外は 12 月）と行（上の外は 1 日、下の外は 31 日）。存在しない日はその月の最終日。`snapRect` はその日のマス |
| `InkModel/LassoGeometry.swift` | 偶奇規則の内外判定、線の点の 50 % 以上で選ぶ `strokeInLasso`（外接矩形で早く捨てる）、`closedPolygon`（縦横とも 4 lu 未満はタップ）、Ramer–Douglas–Peucker の `simplified`、`lassoPolygon`（ε 1 → 512 頂点を超えるあいだ 2, 4, 8）、`bounds` / `union`、`clampedMoveDelta`（紙から出ない。はみ出した枠は戻る向きだけ）、`snapshotLayout`（12 lu の余白、4 倍まで、480×240 に収める） |
| `InkModel/InkStroke.swift` | `paperPoints(cellOrigin:)`、`paperBounds(cellOrigin:)`（最大の太さの半分だけ広げる）、`translated(by:from:to:newCellOrigin:id:at:)`（新しい id、新しいマスの相対座標。0.1 丸めは `InkPoint`） |
| `KitChecks/main.swift` | 8 節を追加して **20240 項目**（Web 版 `page-geometry.test.mjs`・`ink-geometry.test.mjs`・`surface.test.mjs` の該当部分を全部移植。年ページは 2026 と 2028 の全日、不変条件は乱数 300 回 × 6 ページ） |
| `Tests/LayoutTests/EventRangeTests.swift`・`Tests/InkModelTests/LassoGeometryTests.swift` | 同じ内容を XCTest で（CI の `swift test`） |

### 1.2 アプリ（Sources/TegakiCalendar）

| ファイル | 内容 |
| --- | --- |
| `Ink/InkTools.swift` | `CanvasTool` に `.lasso` / `.eventRect`（`isOverlayTool`。そのあいだ PencilKit の描画ジェスチャは無効、キャンバスの道具は直前のまま） |
| `Ink/InkLedger.swift` | `strokes(ids:)` / `paperBounds(of:)` / `paperBounds(ids:)` / `id(of:)`、`removeStrokes(ids:)`（1 操作。元に戻すと新しい id の複製で戻る）、`moveStrokes(ids:by:)`（元を墓標に、動かした複製を新しい id で足す 1 つの batch。複製の所属マスは動かした後の中心で決め直す）。`makePKStroke` は `StrokeGeometry` に出して `InkSnapshot` と共用（UIKit は import しないまま） |
| `Ink/InkOverlayView.swift` | 新規。PencilKit の上に重ねる入力ビュー。`hitTest` は Pencil（「指でも書く」なら指も）だけを取り、他は下のキャンバスへ（指のスクロール・ピンチ・タップはそのまま）。投げなわ（2 lu ごとに頂点、離したら `lassoPolygon`）、移動（枠の中を 6 pt 動かしたら始まる。選んだ線をキャンバスから外し、その絵を layer に載せて指に追従。`clampedMoveDelta` で紙から出ない。離したら `moveStrokes` → 選択は複製に移る）、予定ツール（ドラッグ中は `previewRect` の矩形を描く。離したら `onEventRect(rect, isTap: 8 lu 未満)`）。破線の枠・投げなわの線（accent `#2563eb`、1.5 pt、[6, 4]）・予定のプレビュー（半透明の青） |
| `Ink/InkCanvasView.swift` | 引数 `onSelectionChange` / `onEventRect` / `onEventPreview` / `command` / `commandTrigger` / `initialSelectionIds`。`InkSelection`（ids・紙座標の bbox・キャンバス座標の viewRect）、`CanvasCommand`（`.clearSelection` / `.deleteSelection` / `.removeStrokes`）。選択は台帳に従う（消しゴム・undo/redo・外からの reload で生きていない id を落とす）。道具が投げなわ以外に変わったとき・ページが変わったときに解除。命令はペンが離れて 300 ms 後に実行 |
| `Ink/InkSnapshot.swift` | 新規。選んだ線の画像（`render`: 白地、12 lu の余白、480×240 pt に収める、4 倍まで）と移動中の絵（`image`: 透明地、画素数 12M まで）。線は `PKDrawing.image(from:scale:)` で PencilKit 自身が描く |
| `Views/CalendarRootScreen.swift` | 予定ツールのドラッグ／タップ・「＋予定」・投げなわの「予定にする」→ 作成シート（`layout.eventRange(for:now:)`）。帯・チップ・箱のタップ（指でも予定ツールでも）→ 編集シート（変更できないカレンダーは閲覧）。シートの `onSubmit` は `EventStoreModel` に書き、成功で閉じてトースト、失敗はシートに赤字。「予定にする」で保存したあと「この手書きを消す」がオンなら `.removeStrokes`（1 操作で元に戻せる）。投げなわのメニューを選択の枠の上（入らなければ下）に置く。設定シート、トースト（3 秒・エラー 6 秒）、幅 600 pt 未満でヘッダーを 2 段に。iPhone は最初に週ページ |
| `Views/EventEditorSheet.swift`・`Views/EventEditorForm.swift` | 作成「予定を追加」／編集「予定を編集」／閲覧「予定の詳細」のシート。先頭に「書いた内容」の画像（投げなわのとき）、タイトル（placeholder「ここにペンで書くと文字になります」、iPad では Scribble の注記）、終日、開始・終了（終日は開始日・終了日）、カレンダー（作成は Picker、編集は固定）、場所、メモ、「この手書きを消す」、繰り返しの注記、削除（確認 →「この回だけ／以降すべて」）。純粋な状態 `EventEditorForm` は Web 版 `event-dialog.js` の規則（開始を動かすと長さを保つ、終了が開始以前なら +1 h、終日 ⇄ 時間指定で分を覚えておく、終日の end は翌 0 時） |
| `Views/RecurrenceScopeDialog.swift` | 「繰り返しの予定です」→「この回だけ」「以降すべて」「キャンセル」（保存と削除で文言が変わる） |
| `Views/SelectionMenuView.swift` | 「予定にする」「削除」「選択解除」のカプセル。置き場所の計算 `placement(anchor:size:bounds:)`（Web 版 placeMenu） |
| `Views/SettingsScreen.swift` | 「カレンダー」（表示するカレンダーをアカウントごとに、予定の登録先、カレンダーへのアクセスの状態と「許可する」／「設定アプリを開く」、Google カレンダーを使うには）、「入力」（指でも書く、Apple Pencil、予定にした手書きを消す）、「同期」「データ」「購入」（準備中）、「この iPad の手書きを全て消す」（2 回確認）、「情報」（利用規約・プライバシーポリシー・サポート・バージョン） |
| `Views/ToastView.swift` | 画面下のカプセル（「予定を登録しました」など。エラーは赤い枠と 6 秒） |
| `Views/PageHeaderView.swift` | 「＋予定」と ⚙ を追加、📅 のメニューは設定画面へ。幅 600 pt 未満はセグメントを 2 段目に |
| `Views/ToolbarView.swift` | 投げなわ（"lasso"）と予定（"calendar.badge.plus"）のボタンと文脈の一言（「囲んで選びます。枠の中をドラッグで動かせます」「なぞって予定を作ります。予定をタップすると編集します」） |
| `Views/EventDateText.swift` | `EventDetailSheet.swift` から分離（内容は変更なし）。`EventDetailSheet.swift` は削除 |
| `Calendar/EventDraft.swift` | `EventDraft`（シートの内容。終日の end は翌 0 時）、`EventSpan`、`EventWriteError`（日本語の文言）、`CalendarOption`（EKCalendar の薄い写し） |
| `Calendar/EventKitService.swift` | `writableCalendars`（誕生日・購読を除く）、`calendarForNewEvents`、`create` / `update` / `delete`（`EKSpan` で「この回だけ／以降すべて」）、`isRecurring` / `isEditable`、`apply(_:to:calendar:)`（終日は最終日 23:59:59 で保存。読み戻しは翌 0 時） |
| `Calendar/EventStoreModel.swift` | `calendarOptions` / `writableCalendarOptions` / `defaultCalendarId` / `setDefaultCalendarId`、`create` / `update` / `delete`（書き込み後すぐ `reload()`）、`EventDetail` に `calendarId` / `isRecurring` / `isEditable` |
| `Persistence/AppSettings.swift` | UserDefaults の鍵と既定値（`defaultCalendarId`、`eraseInkAfterConvert` 既定 true、既存の鍵） |
| `Persistence/InkPageStore.swift` | `removeAll()`（`*.json.lzfse` と `*.bak` を全部消す） |
| `Support/ScreenshotMode.swift` | `--screenshot-sheet create\|edit\|lasso\|settings`（月ページに固定）。見本のカレンダー 4 つ（全部書き込み可、「見本」）、投げなわの見本は 14 日の波線、編集の見本は「家族旅行」、作成の見本は 14 日の終日 |
| `Tests/TegakiCalendarTests/` | `InkLedgerTests`（removeStrokes・moveStrokes・行またぎ・週の帯への移動・paperBounds）、`InkSnapshotTests`（新規）、`EventEditorFormTests`（新規）、`EventKitServiceTests`（`apply` の項目・エラー文・`placement`）、`ScreenshotModeTests`（シートの引数・見本のカレンダー） |

### 1.3 CI（.github/workflows/build.yml）

4 ページのスクリーンショットのあとに、月ページでシートを開く 4 回の起動（`--screenshot-sheet create → edit → lasso → settings`、起動のたびに終了）を足しました。成果物 `screenshots` に M3a の 4 枚に加えて `ipad-portrait-sheet-create.png`・`-sheet-edit.png`・`-sheet-lasso.png`・`-sheet-settings.png` が入ります。`project.yml` の `MARKETING_VERSION` は 0.4.0。他の手順は M3a のままです。

## 2. 確かめ方

### 2.1 GitHub Actions（Xcode 無しでも）

`m3b` ブランチへの push で `build` が走ります。緑なら「パッケージの検査（macOS、KitChecks 20240 項目と XCTest）」「アプリのビルド（シミュレータ）」「シミュレータのテスト（InkLedgerTests・InkSnapshotTests・EventEditorFormTests・EventKitServiceTests・ScreenshotModeTests）」がすべて通っています。

成果物 `screenshots`（7 日保存）の 8 枚は、iPad Pro 13 インチのシミュレータで 2026 年 10 月 7 日（水）10:00 を「今日」として撮ったものです。M3a の 4 枚（月・週・日・年）はヘッダー右に「＋予定」と ⚙ が増えた以外は M3a のまま。シートの日付は CI の英語ロケールで「10/14/26」と出ますが、日本語の iPad では「2026/10/14」になります。M3b の 4 枚の見どころ:

- `ipad-portrait-sheet-create.png`: 月ページの上に「予定を追加」のシート。タイトルは空（placeholder「ここにペンで書くと文字になります」と Scribble の注記）、「終日」オン、開始日・終了日が 10 月 14 日、カレンダーは「個人」（見本の 4 つから選べる）、場所、メモ。左上「キャンセル」、右上「保存」。
- `ipad-portrait-sheet-edit.png`: 「予定を編集」のシート。タイトル「家族旅行」、終日、10 月 9 日〜10 月 13 日、カレンダー「家族」（固定）、最後に赤い「削除」。
- `ipad-portrait-sheet-lasso.png`: ツールバーで「投げなわ」が選ばれ、14 日のマスの波線が破線の角丸の枠で囲まれ、その上に「予定にする／削除／選択解除」のカプセル。ツールバーの真ん中に「囲んで選びます。枠の中をドラッグで動かせます」（色と太さの代わり）。
- `ipad-portrait-sheet-settings.png`: 「設定」のシート。「表示するカレンダー」に「見本」の下の 4 つ（仕事・家族・個人・行事、チェック付き）、「予定の登録先」、「カレンダーへのアクセス 許可されています（フルアクセス）」、「入力」「同期」「データ」「購入」「情報」（バージョン 0.4.0 (1)）。

### 2.2 この Mac（Command Line Tools だけ）

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 20240 checks passed」と出れば OK
cd ..
for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done   # 構文の確認
```

XCTest は Command Line Tools に無いので、パッケージの `swift test` とアプリのテストは CI でだけ走ります。

### 2.3 iPad で（TestFlight に入ってから）

1. ツールバーの「予定」を選び、週・日ページの時間軸を上から下へなぞると、吸着した青い矩形が出て、離すと「予定を追加」のシートが開きます（開始・終了は 15 分に丸め、30 分未満は 1 時間）。タップするとその半時間から 1 時間。月・年ページではマスをなぞる／タップするとその日の終日。予定の帯・チップ・箱をタップすると編集。
2. ヘッダーの「＋予定」は今日の 9:00〜10:00（週・日）か今日の終日（月・年）。
3. シートのタイトル欄は Apple Pencil で書けば文字になります（Scribble）。「保存」で iPad のカレンダーに登録され、「予定を登録しました」のトーストが出ます。登録先はシートで選べ、最後に使ったカレンダーを覚えます。
4. 「投げなわ」で手書きを囲むと破線の枠とメニュー。枠の中をドラッグで動かせます（別の日のマスへ動かすとその日の手書きになります。元に戻すは 1 回）。「削除」で消す（元に戻せます）。「予定にする」で、囲んだ手書きの画像が付いた作成シートが開き、保存すると「この手書きを消す」がオンならその手書きが消えます（元に戻せます）。
5. 予定を開いて内容を変え「保存」。繰り返しの予定は「この回だけ」か「以降すべて」を聞きます。「削除」も同じ。変更できないカレンダー（購読など）の予定は閲覧だけ。
6. ⚙ の設定画面で、表示するカレンダー（アカウントごと）、予定の登録先、カレンダーへのアクセス、指でも書く、予定にした手書きを消す、を変えられます。「この iPad の手書きを全て消す」は 2 回確認します。
7. iPhone ではヘッダーが 2 段（切替が 2 段目）、ツールバーは横にスクロール、最初は週ページ、「指でも書く」は最初からオンです。

## 3. 本人が見るもの

- ヘッダー: `◀ 今日 ▶ 題名 [日 | 週 | 月 | 年] ＋予定 ⚙`（幅 600 pt 未満では切替が 2 段目）。📅 のメニューは無くなり、設定画面の「表示するカレンダー」に移りました。
- ツールバー: ペン／マーカー／消しゴム／投げなわ／予定 ｜ 色と太さ、または一言 ｜ ↶ ↷ ｜ 指でも書く。
- 予定ツール: ドラッグ中は半透明の青い矩形（吸着済み）。離すとシート。
- 投げなわ: 破線の青い線 → 選んだ線の周りに破線の角丸の枠（6 pt 外）→ 枠の上に「予定にする／削除／選択解除」。移動中は絵が指に付いてくる。
- シート（iPad は標準のフォームシート、iPhone は全画面）: 「書いた内容」の画像 → タイトル → 終日 → 開始・終了 → カレンダー → 場所 → メモ → この手書きを消す → 削除。
- トースト: 画面下、ツールバーの上に 3 秒（エラーは赤い枠で 6 秒）。
- 設定画面: 「カレンダー」「入力」「同期」「データ」「購入」「情報」。準備中の行は薄く「準備中」。

## 4. 既知の制限・確認待ち

### 4.1 契約からの小さなずれ（意図したもの）

- `MonthPageLayout.eventDay(for:now:calendar:)` と `YearPageLayout.eventDay(for:)` を公開ヘルパーとして追加（`eventRange` の中身の純粋関数）。月ページの `cell(at:)` が外れる異常なレイアウトでも落ちないよう、その場合だけグリッド先頭の日に倒す。
- `EventGeometry.roundMinutes(540.0000001, 15)` は q と整数の差が 6.7e-9 なので 1e-9 の救済に掛からず最寄り丸めで 540（結果は同じ）。救済そのものは `540.000000001` / `539.999999999` で検査。
- `lassoPolygon` は Web 版どおり ε を 8 まで倍にして打ち切るので、極端にギザギザな投げなわでは 512 頂点を超えたまま返ることがある。
- `onSelectionChange` は常に次の main-actor ターンで届ける（スクロール・レイアウトの最中に SwiftUI の状態を変えないため。順序は保つ）。`initialSelectionIds` は最初の倍率のときに台帳が空なら次の reload のあとに再試行。
- `InkSnapshot.image`（移動中の絵）は画素数 12M の上限を設け、超えるときは倍率を下げて layer で引き伸ばす（ページ全体の選択を 4 倍ズームで動かしたときのメモリ対策）。
- `InkSelection.viewRect` は契約どおり余白なし（Web 版の screenRect は 6 px 広げている）。
- `EventEditorForm` は `calendar` を持ち、`draft(calendarId:calendar:)` の `calendar` は nil で自分のもの。`endPickerDate`（終了日 picker 用の最終日）を追加。
- `EventKitService.create` は登録先が予定を受け付けないカレンダーなら `.readOnlyCalendar`。`apply` は予定がカレンダー無しになるときだけ `.calendarNotFound`。`writableCalendarOptions` は `acceptsNewEvents`（誕生日・購読を除く）で絞る。
- `EventDetail.title` は EKEvent 自身の題名（空なら空。編集欄に「（無題）」が入らないように）。
- 「手書きを全て消す」は設定シートを閉じてから消してトーストを出す（iPhone でシートの裏に隠れないため）。失敗はトースト。
- `openCreate` は `defaultCalendarId` が nil なら最初の書き込み可能なカレンダーに倒す。`isCompact` は GeometryReader の幅からその場で求める。
- 続けて出すダイアログ（削除の確認 → 繰り返しの範囲、全消去の 1 回目 → 2 回目）は 0.35 秒置く（SwiftUI は 2 つ同時に出せない）。
- `ScreenshotMode.createDemoDay(for:)` を追加。`lasso` のときは最初から投げなわの道具で始める。
- ツールバーの一言は 1 行（44 pt の高さを保つ）。色は `.secondary` ではなく `UIColor.secondaryLabel` を直接使う（素材の上の `.secondary` は vibrancy で描かれ、CI のシミュレータでは何も写らなかった）。`DatePicker` は任意の分を受け付ける（Web 版の 5 分刻みとは違う）。

### 4.2 実機でしか確かめられないこと

- `InkOverlayView.hitTest` の Pencil／指の判別は、ヒットテスト時に `event.allTouches` が入っていることに頼っている。入っていなければ overlay は何も取らず、Pencil 専用のときに投げなわ・予定ツールが効かない。**実機で最初に確かめること**（代替は container に付ける自前の `UIGestureRecognizer`）。
- 「指でも書く」がオン（iPhone の既定）で投げなわ・予定ツールを選んでいるあいだは、2 本指のスクロール・ピンチが効かない（2 本目の接触は overlay が無視する）。スクロールはペンや消しゴムに持ち替えて行う。
- 移動中の絵は overlay の sublayer に乗算合成を付けている。Core Animation が overlay を別の group として描くと、ドラッグ中だけマーカーが乗算でなく普通の半透明に見える（確定後は戻る）。
- Scribble（ペンで欄に書く）の変換精度と、シートの欄の高さ。iPad 以外では注記を出さない。
- 投げなわの選択があるあいだ、スクロール・ズームのたびに `InkCanvasView` が再評価される（`update(from:)` は軽いが、古い iPad での負荷は未確認）。
- `EventKitServiceTests` は `EKEventStore` / `EKCalendar(for:eventStore:)` / `EKEvent(eventStore:)` をアクセス無しで作る。シミュレータが拒めば `apply` の 3 本が落ちる（保存も読み取りもしていない）。

### 4.3 動作上の注意

- 投げなわの判定は台帳に保存している制御点（`InkStroke.points`）で行う（DESIGN §3.6 の `interpolatedPoints` は使わない。PencilKit の制御点は十分に密）。
- 「予定にする」で消した手書きは ↶ で戻る（1 操作）。保存に失敗したときは消えない（シートが開いたまま赤字）。
- 作成シートを閉じても（キャンセル）選択は残る。道具を変える・ページを変える・「選択解除」で解除。
- 繰り返しの予定の「以降すべて」は EventKit の `EKSpan.futureEvents`（iPad の「カレンダー」と同じ振る舞い）。
- 設定の「同期」「データ」「購入」は準備中（M4・M5）。「情報」のリンク先は仮の URL。
- M4 以降に残すもの: CloudKit 同期、Web 版の取り込み・書き出し、課金・閲覧専用モード（B-4）、初回案内の 4 枚目、iPhone の月ページの初期倍率（B-2）、キャンバスの使い回し（DESIGN §3.10）、編集シートでのカレンダーの変更、設定画面からの予定の色の変更。

### 4.4 技術的な注記

- 言語モードは Swift 5・並行性チェックは minimal のまま。UI の class は `@MainActor`。`InkLedger.swift` と `InkTools.swift` は UIKit を import しない（Mac で型検査できる）。`InkSnapshot.swift` だけが UIKit + PencilKit。
- `EventKitService.hexString` は `nonisolated`（`CalendarOption.init(calendar:)` が非 MainActor から呼ぶ）。
- この Mac には Xcode が無いので、本番のコンパイルは CI。手元では TegakiKit の `swift build` / `KitChecks`、全ファイルの `swiftc -parse`、Catalyst SDK と XCTest のスタブに対する型検査まで。
