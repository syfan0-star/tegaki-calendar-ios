# M4c の実装結果（一覧（fitAll）を基本の状態にし、ピンチで拡大、ダブルタップでその日へ）

[M4C_CONTRACT.md](M4C_CONTRACT.md) の契約を実装した結果のまとめです。設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 座標系と倍率、§3.4 線の所属マス、§3.8 ズーム）。[M4B.md](M4B.md) の続きで、M2〜M4b で出来ていたこと（4 ページ・手書き・予定の読み書き・投げなわ・設定画面・iCloud 同期・Web 版からの取り込み・4 機種で読める紙・固定の終日帯）はそのまま生きています。
ブランチ `m4c`。`main` への取り込みはリード（本人）が行います。版はアプリ **0.5.2**。

きっかけは本人の実機での指摘（2026-10-16。0.5.1 を iPhone・iPad mini・11 インチ・13 インチで試用）: 「ピンチができません」（縮小も **拡大も** 効かない）と仕様変更の要望「日、週、月、年と、基本的に全画面にして一覧表示できるようにして下さい。ピンチイン・ピンチアウトで拡大縮小。一覧の状態でも手書きは可能に。ダブルタップで、週、月、年はその日に飛べるように」。

ピンチが効かなかった原因は 4 つ重なっていました（§3）: (1) 開いた瞬間の倍率が下限そのものだったので縮小は必ず跳ね返る（仕様由来）、(2) 「指でも書く」＋投げなわ／予定ツールでは道具の層が 2 本目の指を握る、(3) ピンチ中に毎フレーム紙を全面描画していた（性能）、(4) **`PKCanvasView` の delegate を自前の Coordinator にしていたため、`UIScrollView` がズーム対象を `viewForZooming(in:)` に問い合わせても答えが無く、ピンチ自体が作られていなかった**（拡大まで効かなかった本命。本人の答え「拡大も全く効かない」で確定し、F4 として 1 コミットに隔離）。

本人の決定どおり（契約 D1〜D7）:

- **一覧（fitAll）が基本の状態**（D1）: どのページも初期倍率と最小倍率 = `fitAll = min(viewW / overviewW, viewH / overviewH)`。一覧矩形は 月 = 6 行の格子（1400 × memo.minY。メモ欄はスクロールで）、週 = 24 時間（1400 × 1920。終日帯は固定見出しのまま）、日 = 紙全体（1000 × 2400）、年 = 紙全体（1400 × 31 行）。最大 = `max(4 × 幅ぴったり, 2 × 読める倍率)`（M4b と同じ値）。紙 × 倍率が画面より小さければ机の色（#ecebe6）の余白で中央に寄せる（計算は常に紙全体）。一覧矩形が手書き・予定で伸びたら下限を計算し直し、一覧のままなら新しい一覧に追随する。余白に書いた線は捨てる（M4C-25）。iPad の月は幅ぴったりのまま（M4b と何も変わらない）。
- **ピンチはどこでも効く**（D2）: F1（下限 = 一覧）・F2（道具の指入力を認識器へ）・F3（ピンチ中は窓を引き伸ばす）・F4（`viewForZooming`）。回帰テスト（§2.3 の 13 本）と CI の写真（`--screenshot-zoom` / `--screenshot-offset`。初回のレイアウトが `scrollViewDidZoom` 以降の同期と終端の経路をピンチと共有する）で確かめる。
- **readableZoom 未満の文字は比例縮小、下限なし**（D3）: readable のときの lu を凍結して縮める（閾値で跳ばない）。罫線は画面上 1 pt のまま（M4C-2）。iPad の月・週は fitAll ≥ readable なので M4b と同じ。
- **倍率をページの種類ごとに覚える**（D4）: fitAll に対する比率を `UserDefaults` の `zoomRatio.<kind>` に（ピンチの終わりにだけ書く。既定 1 = 一覧。上限 64）。回転・幅の変化では **一覧なら新しい一覧へ、拡大中は絶対倍率（手書きの大きさ）を保って新しい範囲に clamp**（M4C-24。clamp で削られた分は目標倍率として持ち、戻したとき復元）。
- **指のダブルタップ**（D5）: 週・月・年 → タップした日の日ページ（月 = マスの日、週 = 列の日（格子でも固定の終日帯でも）、年 = マスの日。メモ欄・ガター・存在しない日・紙の外 = 何もしない）。単タップは約 0.3 秒遅れる（M4C-6）。Pencil では起きない（帯の列だけは SwiftUI の `TapGesture` なので Pencil でも飛ぶ。D5 の例外）。日ページでは何も起きない。投げなわ／予定ツールの間は無効。「指でも書く」オンで描かれる 2 点は消す（M4C-22）。
- **固定見出しと終日帯は倍率と x に追随**（D6）。帯のレーン高だけはピンチ中は開始時の値で凍結し、終わりに更新（M4C-27）。
- **版**（D7）: 0.5.2。

## 1. 作ったもの

### 1.1 TegakiKit（ローカル Swift パッケージ。Foundation だけに依存。担当 K）

| ファイル | 内容 |
| --- | --- |
| `Layout/ZoomPolicy.swift` | `overviewSize(_:)`（月 1400 × memo.minY、他は layout.size）、`fitAll(_:overview:viewport:)`（高さが不正なら幅だけ、幅も不正なら readableZoom）、`maxZoom(_:viewportWidth:)` = max(4 × fitZoom, 2 × readableZoom)、`bounds(_:overview:viewport:)`（fit / min = fitAll / max。max = Swift.max(max, min)）、`zoom(forRatio:bounds:)`、`ratio(forZoom:bounds:)`、`sanitizedRatio`（有限で 1 ≤ r ≤ 64 以外は 1、1 ± 0.001 は 1）、`maxStoredRatio` 64、`centeringInsets(paper:zoom:viewport:)`（紙全体。負・不正は 0）、`visibleWidth(_:viewportWidth:zoom:)`。**削除**: `fitTolerance`、`minZoom`、2 引数の `bounds`、2 引数の `visibleWidth`。`PaperViewport.initial(_:viewportWidth:)` は fitZoom の意味に、`initial(_:overview:paperSize:viewport:ratio:)` を追加（offsetX = −centeringInsets.width。紙が画面より狭ければ負） |
| `Layout/PageLayout.swift` ほか | 要件 `dayAt(point:)`（extension の既定は nil）。月 = `cell(at:)?.day`（月外の日も返す、メモ欄は nil）、週 = 0 ≤ y < 1920 かつ `column(atX:)`（ガターは nil、x = 1400 は日曜）、年 = `cell(at:)?.yearMonthDay` → `DayKey` の `isValid`（2/30・平年の 2/29 は nil）、日 = nil（明示）。`AllDayBandLayout.day(atPaperX:)`（ガター・紙の外・非有限は nil） |
| `KitChecks/main.swift` | 「zoom policy (M4c)」（fitAll の 9 機種 × 4 ページ、maxZoom、bounds、比率、centeringInsets、visibleWidth、PaperViewport.initial）、「double tap target (M4c)」、initial scroll x の 6 行を 3 引数版に（期待値 596 / 548 / 1064 / 635.4 / 844.5 / 0 は不変）。**22900 項目**（M4b の 21814 + 1086。CI の閾値は 22900 − 50 = 22850） |
| `Tests/LayoutTests/ZoomPolicyTests.swift`・`PageNavigationTests.swift`・`{Month,Week,Year,Day}LayoutEngineTests.swift`・`AllDayBandTests.swift` | 同じ内容を XCTest で（`testConstants` / `testOverviewSize` / `testFitAllTable` / `testBoundaryAndMaxZoom` / `testBounds` / `testRatios` / `testCenteringInsets` / `testVisibleWidths` / `testUnusableWidths` / `testPaperViewport`、`testDayAt` × 3、`testDayAtRejectsMissingDates`、`testDayAtIsNil`、`testDayAtPaperX`） |

### 1.2 紙と台帳（Sources/TegakiCalendar。担当 P）

| ファイル | 内容 |
| --- | --- |
| `Ink/InkCanvasView.swift` | 新しい引数 6 つ（`onViewportChange` の後ろ、全部既定値つき）: `initialZoomRatio`（1）、`initialPaperOffset`（nil）、`doubleTapEnabled`（false）、`onDoubleTap`、`onZoomRatioChange`、`onZoomingChange`。`containerDidLayout` は契約 §1.3 の 1〜6: 初回は min / max を入れて `canvas.zoomScale = zoom(forRatio:)`（`scrollViewDidZoom` が同期に走り、写真とピンチが同じ経路を通る）→ 中央寄せの余白（`applyInsets`。紙全体）→ contentOffset（`initialPaperOffset` × zoom / 一覧なら左上 / 拡大中は `initialScrollX,Y` × zoom）→ 自分で `scrollViewDidEndZooming` を 1 回 → DEBUG の NSLog `zoom: kind=… pinch=%d enabled=%d min max zoom fitAll ratio view overview`。幅が変わったら一覧は新しい一覧へ、拡大中は `targetZoom` を clamp して中央維持（比率は報告しない）。高さだけなら `applyBounds`（一覧のままなら追随、拡大中は min / max の更新だけ）。`applyPending` の幾何の変化でも `applyBounds`（13 インチ横の月で行が伸びると fitAll が下がる）。ピンチ中（`isLive` = isZooming ‖ isZoomBouncing）は `paperView.zoomScale` に触らず `show(live: true)` だけ、offset の clamp もしない。`scrollViewWillBeginZooming` → `onZoomingChange(true)`（次ターン）、`scrollViewDidEndZooming` → 余白・min が上がったときだけ clamp・`targetZoom`・跳ね返り中なら後で 1 回（保険 0.4 秒）、`finishZoom` → clamp・描き直し・`onZoomRatioChange(比率)` と `onZoomingChange(false)`（次ターン）。**F4**: `viewForZooming(in:)` が PKCanvasView の描画サブビュー（クラス名が "PK" で始まる最初のもの。無ければインジケータ以外の最初）を 1 度だけ選んで返す。指のダブルタップ（`.direct`、2 taps、`tapRecognizer.require(toFail:)`、`doubleTapEnabled && !tool.isOverlayTool`）→ 紙座標で `onDoubleTap`、「指でも書く」なら直前 0.5 秒の点（画面 16 pt 以内、中心 24 pt 以内）を 1 op で消す。PencilKit の `drawingGestureRecognizer` とだけ同時認識。**F2**: 容器の `fingerRecognizer`（`InkFingerGestureRecognizer`、`.direct`、`cancelsTouchesInView` false。`panGestureRecognizer` と `tapRecognizer` が `require(toFail:)`。`tool.isOverlayTool && allowFinger` のときだけ有効）。容器の背景は机の色 #ecebe6。`canvasViewDrawingDidChange` で中心が紙の外の線は台帳に入れずキャンバスからも消す（undo に残さない） |
| `Ink/InkOverlayView.swift` | **F2**: `hitTest` は Pencil だけ（指は常に nil → scroll view に届く）。`beginFinger` / `moveFinger` / `endFinger` / `cancelFinger`（従来の指の分岐と同じ）。`InkFingerGestureRecognizer`（`UIGestureRecognizer` の派生。1 本指の間は `.possible` のまま touches を overlay へ転送し、離れたら `.ended`、2 本目が触れたら `.failed` ＋ `cancelFinger`。Pencil は無視） |
| `Paper/PaperView.swift` | `show(visible:zoom:contentSize:live:)`（既定 false）。**F3**: live なら窓を作り直さず zoomScale にも触れず、`s = zoom / windowZoom` の `transform` と `center = (contentWindow.midX × s − visible.minX, contentWindow.midY × s − visible.minY)` で引き伸ばす（`windowZoom > 0 && !contentWindow.isEmpty` のときだけ。空の窓なら live false の経路）。live false は transform を `.identity` に戻し → zoomScale → 従来の窓の処理（描き直しは 1 回） |
| `Paper/PaperText.swift` | `fontSize(_:zoom:readable:)` / `gutterLabelSize(_:zoom:gutter:readable:)`（readable 既定 0 = 旧式）。readable 未満は `max(lu, minPoints / readable)`（凍結値: monthDate 24、monthChip 20、monthHoliday 18、weekEvent 21.2、weekTimeLabel 19.31（上限）、dayEvent 19.6、dayTimeLabel 18.7、年は lu のまま）。`hairline` は 1 / zoom のまま（画面上 1 pt、M4C-2） |
| `Paper/MonthPaper.swift` / `WeekPaper.swift` / `DayPaper.swift` / `YearPaper.swift` / `TimeGridPaper.swift` | すべての `fontSize` / `gutterLabelSize` に `readable: ZoomPolicy.readableZoom(kind)`（`drawHourGrid` / `drawBoxes` に `readable:` を足した）。pt 固定の余白・線・閾値は不変 |
| `Views/StickyHeaderView.swift` | 週の見出し: `narrowWeekColumnPoints` 75。月初の「M/1」の日だけ、列 × 倍率 < 75 pt なら曜日の字を省く。`HStack` に `.lineLimit(1)` + `.minimumScaleFactor(0.6)`。`PaperRow` は不変（負の offsetX で中央寄せに揃う） |
| `Tests/TegakiCalendarTests/InkCanvasViewTests.swift` | 契約 §2.3 の 13 本（名前は契約どおり）: 一覧が幅ぴったりより下に行き倍率がレイアウト・更新を越えて残ること（F4 の hard assert: `pinchGestureRecognizer` が nil でない、`viewForZooming` が nil でない、`setZoomScale` が効く、`contentSize` = 紙 × 倍率、UIKit 自身の contentSize と一致、線の `renderBounds` が紙座標のまま）、iPad の月が不変、狭い紙の中央寄せ、live 中は zoomScale に触らない、終端の経路が clamp と比率を報告、回転で一覧は一覧・拡大中は絶対倍率（clamp と復元）、高さだけの変化、一覧の高さ追随、横向きの月の行の伸びで一覧が下がる、`initialZoomRatio` / `initialPaperOffset`（clamp は比率 5 で）、ダブルタップの認識器、drawing との同時認識、`dotStrokeIds`、余白の線の破棄。既存 2 本の書き換え（fitAll 0.2871 / 回転 0.3829 / offsetX −169、比率 2 の initialScrollX = 700 lu）、既定値 6 つ |
| `PaperTextTests.swift` / `PaperViewTests.swift` | `testFontSizeBelowReadableIsFrozen`（月チップ 0.5 → 20、0.2871 → 20 = 5.74 pt、0.7314 → 13.67、readable 0 → 33.3。ガター 19.31 / 18.7）、`testLiveShowStretchesWithoutRedraw`、`testLiveShowWithoutAWindowFallsBackToADraw`、中央寄せ（負の visible）の例 |

### 1.3 画面（Sources/TegakiCalendar。担当 U）

| ファイル | 内容 |
| --- | --- |
| `Views/CalendarRootScreen.swift` | `paperArea`（帯を除いた紙の領域。`GeometryReader` の `onAppear` / `onChange(area.size)` とレーン数の変化で更新）、最初の 1 フレームは `PaperViewport.initial(kind, overview:, paperSize:, viewport: (幅, paperArea.height), ratio: currentRatio)`、`currentRatio = ScreenshotMode.current?.zoomRatio ?? AppSettings.zoomRatio(for: kind)`、`initialScrollX` の `visibleWidth` は 3 引数版（見積りの倍率は `zoom(forRatio:bounds:)`）、`InkCanvasView` に 6 引数（`initialZoomRatio` / `initialPaperOffset` / `doubleTapEnabled: kind != .day` / `onDoubleTap: handleDoubleTap` / `onZoomRatioChange`（ScreenshotMode 中は捨てる）/ `onZoomingChange` → `frozenLaneZoom`）、`handleDoubleTap(at:)` → `layout.dayAt(point:)` → `show(kind: .day, focus:)`、帯に `laneZoom: frozenLaneZoom` と `onColumnDoubleTap`、`show` で `frozenLaneZoom = nil`、`static paperAreaHeight(area:band:kind:)` |
| `Views/AllDayBandView.swift` | `laneZoom: CGFloat?`（レーン高・gap・字だけ。列の x と幅は viewport のまま）、`onColumnDoubleTap`。週の列は `TapGesture(count: 2).exclusively(before: TapGesture(count: 1))`（日ページの帯は `.onTapGesture` のまま）。アクセシビリティの文言は不変 |
| `Support/ScreenshotMode.swift` | `Config.zoomRatio`（`--screenshot-zoom`。有限で正以外は 1）、`Config.offset`（`--screenshot-offset x,y`。2 つの有限な数以外は nil）。シートと併用しても残る |
| `Persistence/AppSettings.swift` | `zoomRatioKey(_:)` = `zoomRatio.month` …、`zoomRatio(for:)`（無ければ 1、`sanitizedRatio`）、`setZoomRatio(_:for:)`（1 なら removeObject） |
| `Tests/TegakiCalendarTests/ScreenshotModeTests.swift`・`AppSettingsTests.swift`（新規）・`CalendarRootScreenTests.swift`（新規） | `testParseZoomAndOffset`、比率の保存（無し → 1、種類ごと、1 で key が消える、不正値 → 1、key の文字列）、`paperAreaHeight`（帯なし 1180、1 レーン 1155、3 レーン 1115） |

### 1.4 設定ファイルと CI（担当 C）

- `project.yml`: `MARKETING_VERSION` **0.5.2**。
- `.github/workflows/build.yml`:
  - `Run KitChecks` の閾値を **22850**（K の実数 22900 − 50）に。
  - 13 インチの 4 ページのステップに 3 枚: `ipad13-portrait-month-zoom2.png`（`--screenshot-zoom 2 --screenshot-offset 400,200`）、`ipad13-portrait-week-zoom2.png`（`2`、`300,700`）、`ipad13-portrait-year-zoom2.png`（`2`、`1000,300`。x は紙の右端に clamp される写真）。
  - iPhone の `shoot` に 2 枚: `iphone-portrait-week-zoom3.png`（`--screenshot-zoom 3 --screenshot-offset 300,700`）と `iphone-portrait-week-jun.png`（`--screenshot-month 2026-06 --screenshot-page week`。M4C-28: 見出しの先頭「6/1」）。
  - ログのステップの末尾に `grep 'zoom: '`（13 インチの `app-log.txt` と各機種の `<id>-log.txt`。§3 の数字の出所）。
- `docs/M4C.md`（この文書）、`README.md`、`docs/DESIGN.md` §1・§2.2・§3.4・§3.8 の注記、`docs/M4B.md` §2.3 に「M4c で上書き」の注記。
- コミットは契約の統合の順番どおり K → P（F1・F3・applyBounds・文字・ダブルタップ・余白）→ P の F2（1 コミット、M4C-4）→ P の F4（1 コミット、§2.5）→ U → C。F2・F4 はそれぞれ `git revert` で単独に戻せる。

## 2. 確かめ方

### 2.1 GitHub Actions（Xcode 無しでも）

`m4c` ブランチへの push で `build` が走ります。緑なら「パッケージの検査（macOS、KitChecks 22900 項目と XCTest）」「アプリのビルド（シミュレータ）」「13 インチのシミュレータのテスト（§7.2・§7.3 の新しいテストと M4b までのテスト）」がすべて通っています。写真の手順はジョブを落としません。

run 38900785227（1 回目、8bbf2f6）: KitChecks 22900・TegakiKit の XCTest・アプリのビルドは緑、シミュレータのテストは **164 本中 4 件が落ちた**（`InkCanvasViewTests` の 2 本で、UIKit が `contentOffset` を画素の格子に丸める分（−81.79 → −82.0、(491.67, 245.83) → (491.5, 246.0)）が許容 0.01 / 0.05 pt を超えた。契約の数字は正しく、許容を 0.5 pt に広げた。F4 の hard assert を含む他の 160 本は通った）。写真 32 枚とログ 4 本は全部撮れた。run 38907338384（2 回目、0856709。許容を直したもの）: **緑**。KitChecks 22900（閾値 22850）、TegakiKit の XCTest 191 本、シミュレータ（`iPad Pro 13-inch (M5)`）のテスト **164 本すべて**、写真 32 枚 + ログ 4 本（`iPhone 17` / `iPad mini (A17 Pro)` / `iPad Pro 11-inch (M5)`、exact 一致）。ログの `zoom: kind=` は 32 行（13 インチ 13 回 + iPhone 11 回 + mini 4 回 + 11 インチ 4 回の起動）で全部 `pinch=1 enabled=1`、`zoomingView` の行は 0。ジョブは約 36 分（13:22 → 13:58 UTC）。この文書の結果の欄はその写真とログから書いた（1 回目と同じ絵）。

成果物 `screenshots`（7 日保存）は最大 **32 枚 + ログ 4 本**。「今日」は 2026 年 10 月 7 日（水）10:00（`-week-sun` / `-week-jun` だけ 2026 年 6 月 7 日（日）10:00）。

| 機種 | 幅 × 紙の領域（縦、pt。実測は §3） | 写真 |
| --- | --- | --- |
| 13 インチ iPad（`iPad Pro 13-inch (M5)`） | 1024 | `ipad13-portrait-month/week/day/year.png`（一覧）、`ipad13-portrait-month/week/year-zoom2.png`（2 倍）、`ipad13-portrait-sheet-create/edit/lasso/settings/sync/import.png`（13 枚） |
| iPad mini（`iPad mini (A17 Pro)`） | 744 | `ipadmini-portrait-month/week/day/year.png`（4 枚） |
| 11 インチ iPad（`iPad Pro 11-inch (M5)`） | 834 | `ipad11-portrait-month/week/day/year.png`（4 枚） |
| iPhone（`iPhone 17`） | 402 | `iphone-portrait-month/week/day/year.png`、`iphone-portrait-week-sun.png`、`iphone-portrait-week-jun.png`、`iphone-portrait-week-zoom3.png`（7 枚）、`iphone-landscape-month/week/day/year.png`（4 枚） |

ログ: `app-log.txt`（13 インチ）、`iphone-log.txt`、`ipadmini-log.txt`、`ipad11-log.txt`。キャンバスの初回レイアウトが `zoom: kind=<page> pinch=<0|1> enabled=<0|1> min=… max=… zoom=… fitAll=… ratio=… view=<幅x高さ> overview=<幅x高さ>` を 1 行（DEBUG）、F4 が選んだビューを `zoom: zoomingView=…`、終端の経路を `zoom: end scale=… min=… max=…` に残す。CI のジョブのログ（「Collect the app log」と追加機種のステップ）にも同じ行が出る。

### 2.2 この Mac（Command Line Tools だけ）

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 22900 checks passed」と出れば OK
cd ..
for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done   # 構文の確認（59 ファイル）
```

アプリ全体は Mac Catalyst SDK（`System/iOSSupport`）に対する型検査まで（[M4.md §4.4](M4.md) と同じ方法: ソースの写しで SwiftUI の `@State` を同じ形のラッパーに置き換え、`TegakiKit` を `arm64-apple-ios17.0-macabi` でビルドして `swiftc -typecheck`。45 ファイル）。XCTest は Command Line Tools に無いので、XCTest の代役（スタブの module）に対するテストの型検査まで（15 本のうち `SyncEngineTests` / `SyncStateStoreTests` の 2 本は `override func setUp() async throws` がスタブに無く以前から検査できない。無変更）。`swift test` とシミュレータのテストは CI でだけ走ります。

### 2.3 実機で（TestFlight に入ってから。契約 §8-4）

| # | 確かめること | 期待 |
| --- | --- | --- |
| 1 | 4 ページともピンチで縮める・広げる | 一覧（ページ全体が入る）で止まる・maxZoom（幅ぴったりの 4 倍）で止まる。拡大の途中は絵が少しぼけ、指を離すと描き直される（F3） |
| 2 | 一覧のまま書く、拡大して書く | どちらも書ける。一覧の線は拡大すると同じ場所にある |
| 3 | 指を離してから別の同じ種類のページへ（◀ ▶） | 同じ倍率で開く（種類ごとの記憶）。アプリを落として開き直しても同じ |
| 4 | 回転 | 一覧は新しい一覧のまま。拡大中は手書きの大きさが変わらず、画面に入らない分は clamp（戻すと復元） |
| 5 | 週・月・年で指のダブルタップ（マス・列・終日帯の列） | その日の日ページ。メモ欄・時刻帯・存在しない日・紙の外では何も起きない。日ページでは何も起きない |
| 6 | バー・チップ・日付の数字の単タップ | 約 0.3 秒遅れて効く（M4C-6）。日ページと投げなわ／予定ツールでは遅れない |
| 7 | Pencil のダブルタップ（紙） | 飛ばない（帯の列だけは飛ぶ。D5 の例外） |
| 8 | 「指でも書く」オン ＋ 投げなわ／予定ツール | 1 本指が道具（投げなわ・なぞって予定）、2 本指がスクロールとピンチ（F2）。チップを指でタップしても編集が開かない。ダブルタップで描かれた 2 点が消える（M4C-22） |
| 9 | 拡大（倍率 0.818 超）中の終日帯 | 帯のレーン高がピンチ中は変わらず、指を離すと更新される（M4C-27）。揺れなければ U の凍結は外してよい |
| 10 | 余白（机の色）に書く | 線が消える（M4C-25） |
| 11 | iPhone の一覧（月・週・年は 4〜7 pt の縮図、横向きは 1〜3 pt） | 受け入れるか（M4C-7 / M4C-26）。読むときはピンチ |

## 3. ピンチの診断（CI のログから）

契約 §2.1 の候補と結果:

| # | 原因 | 結果 |
| --- | --- | --- |
| 1 | 開いた瞬間の倍率 = 下限（縮小は `bouncesZoom` で戻る） | **確定・直した**（F1 = D1。下限が一覧 fitAll になり、縮小ピンチの意味は「一覧より小さくはならない」） |
| 2 | 「指でも書く」＋投げなわ／予定ツールで overlay が 2 本目の指を握る | **確定・直した**（F2。実機で確かめる §2.3-8） |
| 3 | ピンチ中の毎フレームの全面描画（13 インチの年で 77 MB） | **直した**（F3。実機で滑らかさを見る） |
| 5 | `PKCanvasView` の delegate を Coordinator にすると `viewForZooming` 無しではピンチが作られない | **実装した（F4）が、CI では一度も呼ばれなかった**: `pinch=1` は F4 と無関係に立っている（下）。無害なので残し、実機の結果で戻すか決める |

CI のログの `zoom:` 行（run 38900785227 の 13 インチ `app-log.txt`。2 回目も同じ値）:

| ページ（13 インチ、幅 1032 pt） | `pinch` | `enabled` | `min`（fitAll） | `max` | `zoom` | `view`（紙の領域） | `overview` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 月 | 1 | 1 | 0.7371 | 2.9486 | 0.7371 | 1032 × 1172 | 1400 × 1063 |
| 週 | 1 | 1 | 0.5839 | 2.9486 | 0.5839 | 1032 × 1121 | 1400 × 1920 |
| 日 | 1 | 1 | 0.4654 | 4.1280 | 0.4654 | 1032 × 1117 | 1000 × 2400 |
| 年 | 1 | 1 | 0.6065 | 2.9486 | 0.6065 | 1032 × 1150 | 1400 × 1896 |
| 月 2 倍 | 1 | 1 | 0.7371 | 2.9486 | 1.4743（ratio 2.000） | 1032 × 1172 | 1400 × 1063 |
| 週 2 倍 | 1 | 1 | 0.5799 | 2.9486 | 1.1599（ratio 2.000） | 1032 × 1114（帯が 7 pt 伸びた。§1.6 の経路） | 1400 × 1920 |
| 年 2 倍 | 1 | 1 | 0.6065 | 2.9486 | 1.2131（ratio 2.000） | 1032 × 1150 | 1400 × 1896 |

iPhone（402 pt）: 月 0.2871（view 402 × 591）、週 0.2812（402 × 540。**高さ拘束**: 週の見出しが推定より高く、紙の領域 540 < 555）、日 0.2233（402 × 536）、年 0.2871（402 × 569）、週 3 倍 0.8427（min 0.2809、view 539）、max 月・週 1.1486 / 日 1.6080 / 年 2.6786。iPad mini（744）: 0.5314 / 0.4573 / 0.3642 / 0.4784（view 928 / 878 / 874 / 907）。11 インチ（834）: 0.5957 / 0.4974 / 0.3962 / 0.5190（view 1006 / 955 / 951 / 984）。**4 機種 × 4 ページ + 4 枚の zoom、20 回の起動すべてで `pinch=1 enabled=1 min<max`**。毎回 `zoom: end scale=… min=… max=…` が初回のレイアウトの自前呼び出しで出ている（zoom 写真では scale = 2 倍 / 3 倍の値）。13 インチの `view` の幅は 1032（契約の表の 1024 は近似。`iPad Pro 13-inch (M5)` は 1032 × 1376 pt）。

**F4 は必要だったか — シミュレータでは呼ばれなかった**: ログに `zoom: zoomingView=…` も `zoom: no subview to zoom` も **1 行も無い**。つまり UIScrollView は Coordinator の `viewForZooming(in:)` を一度も呼んでいない（呼べば DEBUG で必ずどちらかを記録する）のに `pinchGestureRecognizer` は非 nil で、`zoomScale` の代入（写真）も `setZoomScale`（テスト）も効いた。`PKCanvasView` は外部の delegate を設定しても自分でズーム対象を返している（内部で delegate を仲介している）と読める。シミュレータのテストで `coordinator.viewForZooming(in: canvas)` を直接呼ぶと "PK" で始まるサブビューが返り、`contentSize` も UIKit の値と ±1 pt で一致し、`renderBounds` は不変なので、F4 は **効いていないが無害**。0.5.1 で `pinch=0` だったかは当時のログに行が無いので直接は分からないが、UIKit が問い合わせない以上 F4 の有無でピンチの有無は変わらないと考えるのが自然で、契約 §2.5 の前提（delegate が viewForZooming を持たないとピンチが作られない）は **シミュレータでは成り立たなかった**。本人の実機の「拡大も効かない」を説明する残りの候補は F3（毎フレームの全面描画で数 fps に落ち、指を離すまで何も起きないように見える）と F1（縮小側）。実機（TestFlight）で 4 ページのピンチが効けば、F4 のコミット（2f0a7f1）は戻してもよい（`git revert` が単独で当たることを確認済み）。効かなければ候補 5 の代替案（M4C-23 の (a)(b)）へ。

## 4. 本人が見るもの

### 4.1 数字（縦横。契約 §1.2 の推定。実測は §3 の `view=` から）

| 機種（幅 × 紙の領域 pt） | 月 fitAll | 週 fitAll（帯 25 込み） | 日 fitAll（帯 25 込み） | 年 fitAll |
| --- | --- | --- | --- | --- |
| iPhone 17 縦（402 × 580 / 555） | 0.2871（幅。上下 39 pt の余白） | 0.2871（幅。紙 551 pt） | 0.2313（高さ。紙 231 pt 幅、左右 85 pt） | 0.2871（列 32 pt） |
| iPad mini 縦（744 × 950 / 925） | 0.5314（幅。M4b と同じ） | 0.4818（高さ。左右 35 pt） | 0.3854（左右 179 pt） | 0.5108（列 57 pt） |
| 11 インチ縦（834 × 1020 / 995） | 0.5957（M4b と同じ） | 0.5182（左右 54 pt） | 0.4146（左右 210 pt） | 0.5484（列 61 pt） |
| 13 インチ縦（1024 × 1180 / 1155） | 0.7314（M4b と同じ） | 0.6016（左右 91 pt） | 0.4813（左右 271 pt） | 0.6344（見本の年 1896 lu なら 0.6224。列 70 pt） |
| 13 インチ横（1366 × 830 / 805） | 0.7905（高さ） | 0.4193 | 0.3354 | 0.4462 |
| iPhone 横（874 × 230 / 205） | 0.2190 | 0.1068 | 0.0854 | 0.1237 |

`maxZoom`（幅だけで決まる）: 月・週 = iPhone 1.1486 / mini 2.1257 / 11 インチ 2.3829 / 13 インチ 2.9257、日 = 1.608 / 2.976 / 3.336 / 4.096、年 = 2.6786 / 2.6786 / 2.6786 / 2.9257。

**実測（run 38900785227 の `zoom:` 行。紙の領域の高さは推定より週・日・年で 20〜60 pt 小さく、月で少し大きい）**:

| 機種（幅 × 紙の領域 pt、月 / 週 / 日 / 年） | 月 fitAll | 週 fitAll | 日 fitAll | 年 fitAll（見本の年 1896 lu） |
| --- | --- | --- | --- | --- |
| iPhone 17（402 × 591 / 540 / 536 / 569） | 0.2871（幅。紙 502 pt、上下 44 pt） | **0.2812（高さ。紙 394 pt、左右 4 pt）** | 0.2233（高さ。紙 223 pt、左右 89 pt） | 0.2871（幅。列 32 pt、上下 12 pt） |
| iPad mini（744 × 928 / 878 / 874 / 907） | 0.5314（幅） | 0.4573（紙 640 pt、左右 52 pt） | 0.3642（紙 364 pt、左右 190 pt） | 0.4784（紙 670 pt、左右 37 pt、列 54 pt） |
| 11 インチ（834 × 1006 / 955 / 951 / 984） | 0.5957（幅） | 0.4974（紙 696 pt、左右 69 pt） | 0.3962（紙 396 pt、左右 219 pt） | 0.5190（紙 727 pt、左右 54 pt、列 58 pt） |
| 13 インチ（1032 × 1172 / 1121 / 1117 / 1150） | 0.7371（幅） | 0.5839（紙 817 pt、左右 107 pt） | 0.4654（紙 465 pt、左右 283 pt） | 0.6065（紙 849 pt、左右 91 pt、列 68 pt） |

13 インチの一覧の文字（実測の倍率で）: 週は fitAll ≥ readable なので minPoints の 10 pt、日は 箱 9.1 pt・時刻 8.7 pt、年は チップ 7.9 pt・日番号 13.3 pt・祝日名 6.7 pt。

一覧での文字（画面上の pt。readable 未満は凍結して比例縮小）: 13 インチ縦 = monthDate 12.4 / monthChip 10 / weekEvent 10 / dayEvent 9.4 / dayTimeLabel 9.0 / yearDayNum 13.7 / yearChip 8.1 / yearHoliday 6.8。iPhone 縦 = 6.9 / 5.7 / 6.1 / 4.5 / 4.3 / 6.3 / 3.7 / 3.2（地図。M4C-26）。

### 4.2 写真の確認表（契約 §8-3）

CI の run 38900785227（1 回目）の成果物 32 枚 + ログ 4 本を C（Claude）が全部見た結果を「結果」の列に書きます（2 回目はテストの許容だけの変更なので写真は同じ）。見出し・帯・紙の列線の揃いは 2 倍・3 倍の写真の列の境目を原寸（@2x / @3x）で切り出して見た。本人が判断する項目は **太字**。

| 写真 | 見えていなければならないもの | 結果 |
| --- | --- | --- |
| `ipad13-portrait-month.png` | 6 行の格子が全部入り、下にメモ欄の頭。M4b の写真と同じ（幅ぴったり 0.7314。縦の余白は無い） | ○ M4b と同じ（幅ぴったり 0.7371、縦の余白なし）。6 行とメモ欄の頭、14 日の波線・20 日のマーカー・メモ欄の赤い点も同じ場所 |
| `ipad13-portrait-week.png` | 0:00〜24:00 の格子が全部入る（倍率 ≈ 0.60、紙の幅 ≈ 842 pt、左右 ≈ 91 pt の机の色の余白）。固定見出しの列線と帯の列線が紙の列と 1 pt 以内。帯は キャンプ・締切・家族旅行の 1 レーン 18 pt。字は 10 pt | ○ 0:00〜24:00 が全部入る（0.5839、紙 817 pt、左右 107 pt の机の色）。見出し・帯・紙の列線は原寸で同じ画素列。帯は 1 レーン 18 pt に キャンプ・締切・家族旅行、字 10 pt。見本の波線は水曜の 0:00〜0:30 に。「10:30 電話」の箱は「10:30 …」（M4b と同じ） |
| `ipad13-portrait-day.png` | 24 時間とメモ欄が全部入る（倍率 ≈ 0.48、幅 ≈ 481 pt、左右 ≈ 271 pt の余白）。時刻ラベル ≈ 9.0 pt、箱の字 ≈ 9.4 pt。帯に 締切 | ○ 24 時間とメモ欄（丸と波線 2 本）が全部入る（0.4654、紙 465 pt、左右 283 pt）。日付見出し「7 10月 水曜日」と帯の 締切 が時間軸の列に揃う。時刻 8.7 pt・箱 9.1 pt |
| `ipad13-portrait-year.png` | 12 か月 × 31 行が全部入る（見本の年 1896 lu → 倍率 ≈ 0.62、列 ≈ 70 pt、幅 ≈ 871 pt）。チップの字 ≈ 8.1 pt（運動会・キャンプ・家族旅行が読める）、日番号 ≈ 13.7 pt、祝日名 ≈ 6.8 pt。字が枠の外に無い | ○ 12 か月 × 31 行が全部入る（0.6065、列 68 pt、紙 849 pt、左右 91 pt）。運動会・キャンプ・家族旅行・ゴミの日・健康診断・誕生日・締切・給料日 が読める（7.9 pt）、日番号 13.3 pt、祝日名 6.7 pt。5 字以上の 資料提…・出張（…、祝日名 憲法記… は省略記号（M4b の既知の制限）。枠の外の字は無い |
| `ipad13-portrait-month-zoom2.png` | 2 倍（1.4628）の月: 水・木・金・土（土は半分）の列、10/5 の週の下半分〜11/2 の週の上が見え、曜日の見出し（水〜土）が紙の列と揃う。チップ・日付の字は M4b の minPoints 以上。横スクロールインジケータ | ○ 1.4743 で 水・木・金・土（半分）、10/5 の週の下半分（締切・打合せ…）〜11/2 の週の上。見出し 水〜土 が紙の列線と同じ画素列。チップの字 ≈ 15 pt、日付 ≈ 25 pt。14 日の波線は一覧と同じマスの中（紙と線がずれない）。横スクロールインジケータは **写っていない**（UIKit はスクロール中だけ出す。プログラムからの offset では点滅しない。不具合ではない） |
| `ipad13-portrait-week-zoom2.png` | 2 倍（≈ 1.20）の週: 帯のレーンが ≈ 26.5 pt に伸びている。火（途中）〜土（途中）、8:45〜。見出し・帯・紙の列線が揃う。見本の波線が水曜の列にある | ○ 1.1599（帯が伸びて紙の領域が 1121 → 1114 になり fitAll 0.5799 の 2 倍。§1.6 の経路が写真で起きた）。帯のレーン 25.5 pt（帯全体 32 pt）。火（途中）〜土（途中）、10:00 の線が紙の上端から 119 pt = 8:45 から。見出し・帯・紙の列線は同じ画素列。水曜 10:00 のマーカーが箱の上の同じ場所に（0:00 の波線は画面の上に外れている。時刻のガターも x 300 lu からなので画面外） |
| `ipad13-portrait-year-zoom2.png` | 2 倍（≈ 1.245）の年: 5 月の右端〜12 月（x の clamp）。チップ ≈ 16 pt。月名の見出しが列と揃う | ○ 1.2131、x は 1000 lu から 549 lu（紙の右端）に clamp され 5 月の右端〜12 月、6 日の行から。チップ ≈ 16 pt（家族旅行・ゴミの日・健康診断・誕生日 が読める）。月名の見出しが列線と同じ画素列。10/7 の今日の枠と締切 |
| `iphone-portrait-month.png` | 6 行の格子とメモ欄が全部入り上下に余白（紙 502 pt）。曜日 7 列。字は 4〜7 pt のサムネイルで、はみ出しも重なりも無い（**読めるかは M4C-26**） | ○ 6 行とメモ欄が全部入り、上下 44 pt の机の色（紙 502 pt、領域 591 pt）。曜日 7 列が紙の列と揃う。字は 4〜7 pt の縮図で、はみ出し・重なりは無い。**曜日の見出しと格子の間に 44 pt の机の色の帯が入る**（縦の中央寄せ M4C-1。上詰めにしたければ `centeringInsets` の height を 0 に）。**読めるかは本人（M4C-26）** |
| `iphone-portrait-week.png` | 24 時間が全部入る（紙 551 pt、帯込みで上下 ≈ 2 pt）。帯は固定でレーン 18 pt・字 11 pt。箱の字 6 pt。見出しは「水 7」の形のまま（列 54.8 pt） | ○ 24 時間が全部入る。実測は **高さ拘束 0.2812**（紙の領域 540 pt。週の見出しが推定より高い）で紙 394 pt、左右 4 pt。帯はレーン 18 pt・字 11 pt（キャンプ → 「キャ…」）、見出しは「月 5」…「日 11」の形で列と揃う、箱の字 6 pt、水曜 0:00 の波線。△ 帯のガターの「終日」は幅 18 pt（64 lu × 0.2812）に入らず **「…」** になる（§5.3） |
| `iphone-portrait-week-sun.png` / `-week-jun.png` | 6/1〜6/7 の週（今日 = 6/7 日曜）。一覧なので紙全体が入り、見出しの先頭「6/1」が切れずに入る（M4C-28。曜日の字は省かれる） | ○ 2 枚とも同じ絵（同じ起動引数）: 6/1〜6/7、見出しの先頭が「6/1」（曜日の字なし）で切れずに入り、他は「火 2」…「日 7」（今日の丸）。帯に 運動会（水）・キャンプ（木〜金）・締切（日）。M4b の「紙が右に寄り時刻ラベルが見えない」（M4B-3）は一覧では起きない |
| `iphone-portrait-week-zoom3.png` | 3 倍（0.8613）: 火〜木、8:45 から。打合せ・電話の字 10 pt 以上。帯のレーン ≈ 19 pt。見出しと帯が紙の列と揃う | ○ 0.8427（3 × 0.2809）で 火（途中）・水・木（途中）、8:45 から。打合せ・電話・歯科・資料提出 の字 ≥ 10 pt、帯のレーン 19 pt、見出し・帯・紙の列線は同じ画素列（原寸で確認）。水曜 10:00 のマーカーが同じ場所 |
| `iphone-portrait-day.png` | 紙 ≈ 231 pt 幅が中央（左右 ≈ 85 pt の机の色の余白）。24 時間が入る | ○ 紙 223 pt（0.2233）が中央、左右 89 pt の机の色。24 時間とメモ欄（丸・波線）が入る。日付見出しと帯の 締切 が時間軸の列に揃う。△ 「終日」は「…」（ガター 16 pt。§5.3）。時刻ラベル 4 pt |
| `iphone-portrait-year.png` | 12 か月全部（列 32 pt）が **はみ出した文字なしの** サムネイル。月名の見出し 12 個 | ○ 12 か月 × 31 行（列 32 pt、上下 12 pt の余白）、月名の見出し 12 個が列と揃う。チップ 3.7 pt は読めない縮図だが枠の外には出ない。**読めるかは本人（M4C-26）** |
| `ipadmini-portrait-*.png` / `ipad11-portrait-*.png` | 月は M4b と同じ。週・日・年は全部入る（§4.1 の余白） | ○ 月は M4b と同じ（幅ぴったり 0.5314 / 0.5957）。週は 0:00〜24:00 が全部入り（0.4573 / 0.4974、左右 52 / 69 pt）、「終日」も見え、見出し・帯・紙の列が揃う。日は 24 時間とメモ欄（0.3642 / 0.3962、左右 190 / 219 pt）。年は 31 行全部（0.4784 / 0.5190、チップ 6.2 / 6.7 pt、列 54 / 58 pt）。mini の週の題名「2026年10月5日〜10月1…」の省略は M4b から同じ（幅 744 では 1 段の長い題名） |
| `iphone-landscape-*.png` | 撮れていれば: 週は ≈ 0.11 の地図（字 1.4 pt）。見出しの字は切れる（既知 M4C-7）。崩れ・落ちが無い | ○ 4 枚とも横向きに撮れ、落ちていない。月 0.219（紙 307 pt が中央、6 行）、週 0.1068（紙 150 pt。見出しは日付の数字だけで曜日の字は切れ、帯は「キ」「締」「家族…」）、日 0.0854（紙 85 pt、帯は「…」）、年 0.1237（紙 173 pt、月名は全部「…」）。**地図として受け入れるかは本人（M4C-7）** |

### 4.3 本人が決めること（契約 §9。返事が無ければ既定のまま）

| # | 内容 | 既定 | 見る写真・場所 |
| --- | --- | --- | --- |
| M4C-26 | iPhone 縦の一覧の文字（月チップ 5.7、週の箱 6.1、年チップ 3.7 pt）。iPhone は週ページから始まるので初回起動が読めない縮図になる | 既定比率 1（一覧）のまま。代案: iPhone だけ既定比率を readable / fitAll（月 1.74・週 1.64・日 2.43、年 1）にする（U の 1 行） | `iphone-portrait-month/week/year.png` |
| M4C-7 | iPhone 横の一覧は地図（倍率 0.09〜0.22、字 1〜3 pt、見出しの字が切れる） | 受け入れる（下限に床を入れる案は「全画面で一覧」に反する） | `iphone-landscape-*.png` |
| M4C-1 | 紙が画面より短いとき縦にも中央寄せ | 寄せる（iPhone の月 39 pt、週 2 pt の上下余白） | `iphone-portrait-month.png` |
| M4C-25 | 容器の背景は机の色 #ecebe6、余白に書いた線は捨てる | この案（代案: 紙の縁に線＋影、余白の線を許す） | `ipad13-portrait-day.png`（左右 271 pt の余白） |
| M4C-2 | 罫線は画面上 1 pt（1 device pixel ではなく） | 1 pt のまま | 一覧の写真 |
| M4C-6 | ダブルタップのために単タップが約 0.3 秒遅れる | 受け入れる | 実機 |
| M4C-15 | 帯の列のダブルタップは Pencil でも飛ぶ（SwiftUI の TapGesture はタッチ種別を選べない） | 受け入れる（除外は次の里程） | 実機 |
| M4C-27 | ピンチ中の帯のレーン高の凍結 | 凍結する。実機で揺れなければ外す（引数は残す） | 実機（倍率 0.818 超） |
| M4C-14 | 倍率を一覧に戻す操作 | 足さない（ピンチで一覧まで縮めれば比率 1 が保存される） | — |

## 5. 既知の制限・確認待ち

### 5.1 契約からの小さなずれ（意図したもの）

TegakiKit（K。検証者が照合済み）:

- 契約 §2.3 の clamp の例「比率 3 を 1024 × 1180 の月に → 2.9257」は誤り（3 × 0.7314 = 2.194 は max 2.9257 の内側）。KitChecks と P のテストは比率 4・5 で clamp を見る（3 は 2.1943 で範囲内）。
- `ZoomPolicy.visibleWidth(_:viewportWidth:zoom:)` は viewportWidth / zoom が紙の幅から 1e-9 以内なら紙の幅そのものを返す（fit ぴったりの浮動小数の誤差で `initialScrollX` が 1e-13 lu ずれるのを防ぐ。期待値は不変）。`AllDayBandLayout.day(atPaperX:)` の floor に 1e-9 の許容（列の境界は自分の列）。
- `centeringInsets` は辺が非有限なら 0、0 以下なら 0 として扱う。`fitAll` / `PaperViewport.initial` も非有限・0 以下の入力を readable / 幅 0 に落とす。
- 年の「存在しない 2/29」の検査は 2026（平年）と 2028（閏年）で行う（契約の 2025 と意味は同じ）。
- KitChecks の実数 N（22900）を docs/M4C.md に書くのは C がこの文書で行った（K の担当は TegakiKit の中だけ）。

紙と台帳（P。検証者が照合済み）:

- `scrollViewDidEndZooming` の「跳ね返り中なら描き直しを後で」の判定は `canvas.isZoomBouncing` 単独でなく `isLive`（isZooming ‖ isZoomBouncing、または liveOverride）。上位集合で、UIKit がその時点でまだ isZooming を報告していても `finishZoom` の `show(live: true)` で描き直し無しのまま終わらない。0.4 秒の保険が余分な場合も拾う。
- §1.3 の 2（同じ限界なら早期復帰）は `lastLayoutSize = viewport` も記録してから戻る。`applyInsets` は 1e-6 pt 未満の余白を 0 にする（幅ぴったりの浮動小数の屑。iPad の月で `contentInset == .zero` が成り立つ）。
- `viewForZooming` の代替の選び方はクラス名に "Indicator" を含むサブビューも除く（新しい iOS のスクロールインジケータは `UIImageView` ではない）。DEBUG で選んだビューを `zoom: zoomingView=…` に記録する（契約に無い行）。契約に無い `Coordinator.contentSizeFromUIKit`（`scrollViewDidZoom` の入口で UIKit 自身の contentSize を記録）で §2.5 の「一致」をテストの hard assert にした。
- `syncPaperFrame` は live でないとき `paperView.zoomScale` を自分で入れず `PaperView.show(live: false)` が入れる（§2.2 と同じ順序: identity → zoomScale → 窓）。`applyPending` の `applyBounds` は `hasInitialZoom` かつ容器に大きさがあるときだけ（初回は `containerDidLayout` が計算する）。
- `testInitialZoomRatioAndPaperOffset` は clamp を比率 5 で見る（上の K の 1 行目）。offset の部分は週ページ（1024 × 1180、倍率 1.2292、offset (491.7, 245.8)）。初回のレイアウトの自前の `scrollViewDidEndZooming` は `onZoomingChange(false)` も 1 回配信する（U の受け手は `frozenLaneZoom = nil` にするだけ）。テストは初回の配信を流してから数える。
- `testDoubleTapRecognizerSetup` は契約の `.pen` を `.ink(InkPresets.defaultPen)` で（`CanvasTool` に `.pen` は無い）。`makeView` に契約より多い既定値つき引数と `Rig` の補助、`PencilKit` の import（`PKStroke` の見本）。§7.2 の「displayRequestCount +1」は「増えている」で検査（frame の大きさの変化で UIKit 自身の `setNeedsDisplay` も数えられる）。

画面（U。検証者が照合済み）:

- `CalendarRootScreen.paperAreaHeight` は契約の「幅だけの fitAll の見積り」でなく定数 `overviewBandZoom = 0.6` で帯の高さを測る（幅だけの見積り（13 インチ縦の週 0.7314）だと gap が 2.19 pt になり、実際の fitAll 0.6016 での帯（gap 2 pt）と 2 レーン以上でずれる。0.6 なら全機種の週・日の fitAll ≤ 0.6016 < 0.667 で実値と一致）。`CalendarRootScreenTests.testOverviewBandZoomKeepsTheBandAtItsMinimums` がこの前提を固定。
- `paperArea` は `area.size` に加えて帯のレーン数の変化でも書き直す。
- `AllDayBandView` の週の列に `.accessibilityAction { onColumnTap(day) }`（`.gesture` は VoiceOver の activate を付けないため。文言は不変）。`laneZoom` は `pageHeight` の直後に宣言。
- `ScreenshotMode` に契約に無い static ヘルパー `parseZoomRatio(_:)` / `parseOffset(_:)`。
- `CalendarRootScreenTests` は `@MainActor final class`（iOS 18 以降の SDK では View 準拠型の static メンバーも MainActor 隔離）。テスト 3 本は契約 §7.3 より多くの入力を見る（64 の保存、ディスク上の不正値、35 % の上限、"nan" / "1," など）。

統合（C）:

- `iphone-portrait-week-jun.png`（M4C-28）は起動引数が M4b の `iphone-portrait-week-sun.png` と同じ（どちらも 2026-06 の週 = 6/1〜6/7）。一覧では紙全体が入るので 2 枚は同じ絵になる。契約の枚数（iPhone 縦 7 枚）に合わせて両方撮る。次の里程で `-sun` を外してよい。
- F2 も F4 と同様に 1 コミットに隔離した（M4C-4）。間の状態（F2 無し・F4 無し）は型検査だけで CI は走らせていない（push は最終の 1 回）。
- KitChecks の閾値は契約の暫定 21890 でなく K の実数 22900 − 50 = **22850**。
- 1 回目の CI の後に P の `InkCanvasViewTests` の 4 つの許容を直した（C の変更。`contentOffset` と `probe.last?.offsetX` の比較を 0.01 / 0.05 → **0.5 pt**。UIKit が contentOffset を画素の格子に丸めるため。期待値そのものは契約どおり）。

### 5.2 実機でしか確かめられないこと

- **F4 は CI では一度も呼ばれなかった**（§3）: 実機で UIKit が Coordinator の `viewForZooming` を呼ぶ経路があるかは不明。呼ばれて PencilKit 自身の処理と二重に transform されれば線が紙からずれる。その場合は F4 のコミット（2f0a7f1）だけを戻す。
- **ピンチそのもの**: CI のログの `pinch=1` と §2.3 のテストは「ピンチが作られて `setZoomScale` が効く」まで。指の感触・ピンチ中の引き伸ばしの見た目と滑らかさ・跳ね返りの後の描き直し（0.4 秒の保険）・F4 で選んだサブビューの transform が PencilKit 自身の処理と二重にならないこと（線が紙とずれないこと）は実機。ずれたら F4 のコミットだけを戻す（ピンチは効かないまま 0.5.1 の状態）。
- F2: 投げなわ／予定ツール＋「指でも書く」のときの 1 本指の入力と 2 本指のスクロール・ピンチ（`panGestureRecognizer.require(toFail:)` と `.possible` のまま転送する流儀）、チップを指でタップしても編集が開かないこと。崩れたら F2 のコミットを戻す（既知の制限 M3B.md:122 に戻る）。
- ダブルタップの 0.3 秒の遅れの感触、「指でも書く」で点が描かれ消えること、日ページの帯でダブルタップしても何も起きないこと、帯の列の `TapGesture(count: 2).exclusively(before:)` が単タップを先に発火させないこと（SwiftUI の版による報告あり）。
- iPad の横向き（CI は iPad を回せない。一覧は一覧のまま・拡大中は手書きの大きさが変わらない）。帯が伸びる倍率（> 0.818）での往復と揺れ（M4C-27）。比率の保存（アプリを落として開き直す）。余白に書いた線が消えること。
- シミュレータのテストの前提: `canvas.subviews` が window 無しでも描画サブビューを持つこと（無ければ `viewForZooming` が nil で `testOverviewGoesBelowFitWidthAndSurvivesLayoutPassesAndUpdates` が落ちる。ログ `zoom: no subview to zoom` が目印。テスト環境の制限であって実機の不具合とは限らない）、`minimumZoomScale` を現在の zoomScale より上げても zoomScale が動かないこと（`testEndOfPinchPathClampsAndReportsTheRatio` (b)）、`PKStroke.renderBounds` が未描画でも安定なこと。

### 5.3 動作上の注意

- **iPhone の一覧は縮図**（月チップ 5.7 pt、週の箱 6.1 pt、年チップ 3.7 pt。横向きは 1〜3 pt）。読むときはピンチで拡大する。既定を変えるなら M4C-26 の代案（§4.3）。
- **iPhone 横の一覧**は見出しの字が列の幅（週 20 pt、年 14 pt）で切れる（既知 M4C-7）。
- **iPhone 縦の一覧の帯のガター「終日」は「…」になる**（週 18 pt・日 16 pt の幅に 10 pt の 2 字が入らない。M4b の 0.4716 では 30 pt あった）。帯の意味はバーの色で分かるので受け入れる。消すか小さくするなら U の `AllDayBandView` のガターの 1 行（次の里程）。
- **iPhone 縦の月は曜日の見出しと格子の間に 44 pt の机の色の帯**（縦の中央寄せ M4C-1 の見え方）。上詰めにするなら `ZoomPolicy.centeringInsets` の height を 0 にする（K の 1 行。`PaperViewport.initial` と P の `applyInsets` は同じ関数を呼ぶので他は不変）。
- **ピンチ中は窓の外が机の色**で見え、4 倍まで引き伸ばした絵はぼける（ピンチ中だけ。終了時に 1 回描き直す。M4C-20）。
- **単タップの 0.3 秒の遅れ**（週・月・年のバー・チップ・日付の数字。日ページと投げなわ／予定ツールでは無い。M4C-6）。
- **帯の列は Pencil のダブルタップでも日ページへ飛ぶ**（M4C-15。紙は飛ばない）。
- **余白に書いた線は消える**（M4C-25。「余白は紙ではない」の合図）。
- 一覧（比率 1）の初期横位置は左上（今日の列は必ず見える）。拡大中（比率 > 1）だけ M4b の `initialScrollX`（今日の列）/ `initialScrollY`（今の 1 時間前）。iPad 縦の週の一覧は 0:00〜24:00 が全部入るので、M4b の「4:00 から」の注意は一覧では無くなる（拡大中は従来どおり紙の下端で止まる）。
- 回転で clamp された倍率は `targetZoom` に残り、戻したとき復元する。保存比率はピンチの終わりにだけ書くので、回転だけでは変わらない。
- 月の一覧矩形は 6 行だけ（メモ欄はスクロールで。iPad では幅ぴったりで変わらない、iPhone では紙全体が入る）。13 インチ横の月は高さ拘束（0.7905）で、行が伸びると一覧の倍率が下がる（一覧のまま書いていれば追随する）。
- 固定見出しの最初の 1 フレームは幅だけの見積り（M4C-19。次のターンで揃う。M4b と同じ）。`paperArea` が 0 の最初のフレームでは `initialScrollX` の見積りも幅だけの bounds で計算される（契約 §5.1 が受け入れている「帯の高さ分のずれ」）。
- `onZoomingChange(true)` は次ターンに届くので、U が凍結するレーン高の倍率はピンチ開始の 1〜2 フレーム後の値になりうる（凍結の目的は満たす）。`paperAreaHeight` は kind だけの変化では再計算しない（0.6 では週・日の帯の高さが同じなので実害なし。`overviewBandZoom` を 0.667 超に変えるなら `.onChange(of: kind)` が要る）。

### 5.4 技術的な注記

- 言語モードは Swift 5・並行性チェックは minimal のまま。`ZoomPolicy` / `PaperViewport` / `dayAt` は `TegakiKit`（UIKit を import しない）。
- `PKCanvasView` のズームの仕組み（F4）: `PKCanvasView` は `UIScrollView` で、`delegate`（`PKCanvasViewDelegate: UIScrollViewDelegate`）を設定すると `UIScrollView` はズーム対象を delegate の `viewForZooming(in:)` から得る。これを実装していないと `pinchGestureRecognizer` は作られず、ピンチも `setZoomScale` も効かない。Coordinator が PKCanvasView の描画サブビューを返す。`PKCanvasView.drawing` の座標は zoom に依らず紙の座標のまま（テストで `renderBounds` が不変なことを見る）。
- `onZoomRatioChange` と `onZoomingChange` は常に次の main-actor ターンに配信（UIKit のデリゲートから同期に来るので、SwiftUI の `@State` に触る U の受け手を守る）。`notifyViewport` の規則（M4B.md §4.4）は不変。
- `bouncesZoom` は既定（true）のまま（M4C-13）: 下限が一覧なので跳ね返りは「一覧より小さくはならない」の意味。跳ね返り中も live として扱い、描き直しは跳ね返りの後に 1 回（`scrollViewDidZoom` の最初の非 live フレーム。来なければ 0.4 秒後の保険）。
- `scrollViewDidEndZooming` の clamp は `setZoomScale(animated: true)` でなく代入（UIKit の bounce と二重に走らせない。XCTest で同期に確かめられる）。ピンチ中に min が上がった（帯が伸びた）場合にだけ効く。
- `InkCanvasViewTests` の次ターン配信は `await Task.yield()` × 8 で待つ（M4b と同じ）。
- この Mac には Xcode が無いので、本番のコンパイルは CI。手元では TegakiKit の `swift build` / `KitChecks`、全ファイルの `swiftc -parse`、アプリ全体の Catalyst SDK に対する型検査、XCTest の代役に対するテストの型検査まで（§2.2）。
