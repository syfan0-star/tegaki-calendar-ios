# M4b の実装結果（iPhone・iPad mini・11 インチ・13 インチで読める紙にする）

[M4B_CONTRACT.md](M4B_CONTRACT.md) の契約を実装した結果のまとめです。設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 座標系と倍率、§2.4 週、§2.5 日、§2.6 年、§2.7 ヘッダー、§2.11 iPhone、§3.4 線の id と所属マス、§3.8 ズーム）。[M4.md](M4.md) の続きで、M2〜M4 で出来ていたこと（4 ページ・手書き・予定の読み書き・投げなわ・設定画面・iCloud 同期・Web 版からの取り込み）はそのまま生きています。
ブランチ `m4b`。`main` への取り込みはリード（本人）が行います。版はアプリ **0.5.1**。

きっかけは本人の実機での指摘（2026-10-15）: iPhone と 11 インチでヘッダーの「今日」が消える、日ページの終日予定が「消えている」（紙の最上部の帯にあって初期スクロールで画面外）、iPhone で週の終日帯・月の帯・年の文字が読めない。根本原因は「文字は画面上の最小 pt を保証するが、帯・レーン・チップの高さは lu × 倍率で縮む」こと（倍率の下限が幅ぴったりなので、402 pt の iPhone で月の倍率は 0.287）。

本人の決定どおり（契約 D1〜D8）:

- **ページごとの最小倍率**（D1）: `minZoom = max(幅ぴったり, 読める倍率)`。読める倍率は「鍵になる列が読める幅」= 月 200 lu ≥ 100 pt（0.5）、週 190.857 lu ≥ 90 pt（0.4716）、日 588 lu ≥ 330 pt（0.5612）、年 112 lu ≥ 150 pt（1.3393）。幅ぴったりが読める倍率の 95 % 以上なら幅ぴったり（意味の無い数十 pt の横スクロールを作らない）。`maxZoom = max(4 × 幅ぴったり, 2 × minZoom)`。年は **全機種** で横スクロール、月・週・日は iPhone だけ。
- **固定見出しは横スクロールに追随**（D2）。左のガター（週・日の時刻ラベル、年の日番号）は紙の一部のまま。年の各マスの見出しに日番号（「7 水」）を足した。
- **週・日の終日帯を紙の外（固定見出し）へ**（D3）: Web 版と iOS の「カレンダー」と同じ。常に見える、全件をレーンに、高さはページの見える高さの 35 % で頭打ち（それ以上は帯の中で縦スクロール）、**書けない**。バーをタップで編集、列の空きをタップでその日の終日予定の作成。紙は 0:00 から始まる。帯に書いてあった手書きは読込時に `grid` へ移す（冪等、id は保つ、y はそのまま）。
- **文字は絶対にはみ出さない**（D4）: バー・チップ・箱の文字はその枠で切る。
- **ヘッダー**（D5）: iPhone の 2 段では短い題名（「10/5〜10/11」「10月7日(水)」「2026年10月」「2026年」）と 17 pt、間隔を詰める。
- **横向き**（D6）: どの幅でも `GeometryReader` の幅で決まる。
- **CI**（D7）: 4 機種で 4 ページの縦の写真。6 シートとユニットテストは 13 インチだけ。iPhone は今日が日曜の週（2026-06）と横向き 4 枚も。
- **版**（D8）: 0.5.1。

## 1. 作ったもの

### 1.1 TegakiKit（ローカル Swift パッケージ。Foundation だけに依存。担当 K）

| ファイル | 内容 |
| --- | --- |
| `Layout/ZoomPolicy.swift`（新規） | `ZoomPolicy`: `keyColumnWidth`（月 200 / 週 190.857 / 日 588 / 年 112）、`readableColumnPoints`（100 / 90 / 330 / 150）、`readableZoom`、`paperWidth`、`fitZoom`、`fitTolerance` 0.95、`minZoom`（fit ≥ 0.95 × readable なら fit、それ以外 max(fit, readable)）、`maxZoom`、`Bounds(fit:min:max:)` + `clamped`（NaN → min）、`bounds`、`visibleWidth`（minZoom で画面に入る紙の幅 lu。紙の幅を超えない）。`PaperViewport`（offsetX / zoom / width、`x(ofPaper:)`、`width(ofPaper:)`、`.zero`、`initial(_:viewportWidth:)`）: キャンバスが作って送り、固定見出しと帯が紙の x に追随するための値 |
| `Layout/PageNavigation.swift` | `initialScrollX(_:now:calendar:visibleWidth:)`（月・週: 今日の列が全部見える最小の x、年: 今年なら今月の列の左端、日: 0。紙の中に clamp）、`compactTitle(_:focus:)`（日「10月7日(水)」、週「10/5〜10/11」「9/28〜10/4」「12/28〜1/3」、月「2026年10月」、年「2026年」）。`initialScrollY` は週・日で帯の 60 lu が無くなった分だけ小さくなる（今日 10:00 → 720 / 900） |
| `Layout/AllDayBand.swift`（新規） | `AllDayBandBar`（eventId・title・colorHex・lane・startCol・endCol・continuesLeft/Right・minX/maxX lu）、`AllDayBandLayout`（kind・days・tones・paperWidth・gutter・columnMinX・columnWidth・laneCount・bars・todayColumn、`empty(kind:days:)`）、`AllDayBandEngine.week(monday:events:now:)`（`MonthLayoutEngine.packAllDayLanes` と同じ詰め方、間引き無し）/ `day(_:events:now:)`（1 予定 1 レーン）、`AllDayBandMetrics`（下限 レーン 18 / 隙間 2 / 字 11 pt、上下の余白 3 / 4、「終日」10 pt、上限 35 %。`metrics(kind:laneCount:zoom:pageHeight:)` → lane / gap / text / contentHeight / visibleHeight / scrollsInside / `laneTop(_:)`） |
| `Layout/WeekLayoutEngine.swift` / `DayLayoutEngine.swift` | 帯の廃止。`size` 固定（1400 × 1920 / 1000 × 2400）、`grid` は (0, 0, …)、`cells` は `[.grid]` だけ、`allDayBars` は常に空、`allDayBand` を持つ、`inkCell` は常に `.grid`（負の y も）、`growsWithInk` false、`hit` は箱だけ、`snapRect(終日)` は nil、`bandHeight` 削除。`WeekLayoutInput` / `DayLayoutInput` の init は不変（`inkBottoms` は読まない） |
| `Layout/PaperSpec.swift` | `weekBand*` / `dayBand*` の 8 定数を削除。`CellKey.allDay(_:)` / `.allDayDay` は残す（移し替えが読む。保存形式は不変） |
| `InkModel/BandMigration.swift`（新規） | `isBandCell`、`migrated(_:pageId:)`（週 `w-` の `allday:YYYY-MM-DD` → `.grid`、x += 64 + col × 190.857、y はそのまま。日 `d-` の `allday` → `.grid`、座標はそのまま。月・年・他のマス・墓標は対象外）、`needsMigration`、`migrate`（対象が無ければ同じ page、冪等） |
| `KitChecks/main.swift` | 新 4 節 `zoom policy (M4b)`・`initial scroll x (M4b)`・`all-day band (M4b)`・`band migration (M4b)`、`page navigation` に `compactTitle`、`paper spec` に 4 件、`week page` / `day page` / `rect → event range` の週・日を帯の無い形に。**21814 項目**（M4 の 20659 + 1155。CI の閾値は 21814 − 50 = 21764） |
| `Tests/LayoutTests/ZoomPolicyTests.swift`・`AllDayBandTests.swift`・`Tests/InkModelTests/BandMigrationTests.swift`（新規）、`WeekLayoutEngineTests`・`DayLayoutEngineTests`・`EventRangeTests`・`PageNavigationTests`（変更） | 同じ内容を XCTest で（CI の `swift test`）。`PageLayoutTests.testPaperSpecConstants` は無変更 |

### 1.2 紙と台帳（Sources/TegakiCalendar。担当 P）

| ファイル | 内容 |
| --- | --- |
| `Paper/PaperText.swift` | `drawLine` / `drawLines` が `rect` で切る（`saveGState` / `clip` / `restoreGState`。文脈が無ければ切らずに描く）。`gutterLabelSize(_:zoom:gutter:)` = max(0, min(fontSize, (gutter − 8) / 2.9))（"23:00" がガターに入る上限。契約の 2.6 は "23:00" を 2.48 em と見積もっていたが、SF の等幅数字（medium）では 2.705 em で、1 回目の CI の iPhone の週で「10:…」と切れたので Web 版と同じ 2.9 に。iPhone の週の minZoom 0.4716 では上限が効いて 9.1 pt（≥ 9 pt）、日と iPad は 10 / 10.5 pt のまま）。`gutterLabelEms` 2.9 |
| `Paper/PaperView.swift` | `PaperContent.allDayBand`（週・日は `layout.allDayBand`、月・年は nil）。紙は **見えている範囲の周り 2 × 2 画面の窓** だけを持つ: `contentWindow`（契約の `window` は `UIView.window` と衝突するので改名）、`show(visible:zoom:contentSize:)`（窓が visible を含み倍率も同じなら frame.origin だけ動かし描き直さない）、`static window(for:content:)`、`draw` は `translateBy(−window.origin)` → `scaleBy(zoom)`。年ページの minZoom 1.339 で紙全体（1875 × 2491 pt、iPhone @3x で約 168 MB）を持たない |
| `Paper/WeekPaper.swift` / `DayPaper.swift` | 帯の下線・「終日」・バーを描かない。ガターと時間軸の縦線・列の色は 0…height のまま |
| `Paper/TimeGridPaper.swift` | `drawBandLabel` / `drawAllDayBars` を削除。時刻ラベルの大きさは `gutterLabelSize` |
| `Paper/MonthPaper.swift` | バーの文字は角丸で clip、チップは `frame` で clip（「+n件」・点・時刻・題名の全部） |
| `Paper/YearPaper.swift` | チップの文字は角丸で clip（文字の左右の余白は 0.3 em → 0.15 em。チップ 58.6 lu に 4 字の題名 52 lu が入るように。1 回目の CI では「家族…」と切れた）。各マスの見出しに **日番号**（曜日の字の前、等幅数字 semibold、同じ大きさ・色。「7 水」）。ガターの 1…31 はそのまま |
| `Ink/InkCanvasView.swift` | `initialScrollX`（既定 0）と `onViewportChange`（既定 何もしない）。`containerDidLayout` が `ZoomPolicy.bounds` で min / max を決め、minZoom にいた紙は新しい minZoom に、初回は `(initialScrollX, initialScrollY) × zoom` を紙の中に clamp。`notifyViewport` は `syncPaperFrame` の末尾から: 指の動きは同期、レイアウト・ページ切替・プログラムからの代入は次のターンに最新値を 1 回（`isApplyingGeometry` で SwiftUI の更新中に `@State` を書かない）。`showsHorizontalScrollIndicator` true、`isDirectionalLockEnabled` true、`bouncesZoom` 既定。紙は `paperView.show(...)` で窓を動かす |
| `Ink/InkLedger.swift` | `init` と `reload` で `BandMigration.migrate`（指紋表は触らない） |
| `Views/StickyHeaderView.swift` | `viewport: PaperViewport = .zero` を足し、`FractionRow` を `PaperRow`（子 i を x = Σ columns × zoom − offsetX、幅 columns[i] × zoom に置き、行の外は切る）に。月の曜日行も `PaperRow`。`viewport.width == 0`（最初の 1 フレーム）は `PaperViewport.initial` で置く |
| `Tests/TegakiCalendarTests/PaperTextTests.swift`・`PaperViewTests.swift`・`InkCanvasViewTests.swift`（新規）、`InkLedgerTests.swift`（変更） | クリップ（rect の外の画素が背景のまま）、時刻ラベルの上限、窓の計算の 3 例、`show` の 3 条件、レイアウト中に viewport が同期に届かないこと、帯の線の移し替え（`testLedgerMigratesBandStrokesOnInitAndReload`、`testWeekStrokeAboveTheGridBelongsToTheGrid`、`testDayStrokesAllGoToTheGrid`） |

### 1.3 画面（Sources/TegakiCalendar。担当 U）

| ファイル | 内容 |
| --- | --- |
| `Views/AllDayBandView.swift`（新規） | 週・日の固定の終日帯（固定見出しの下、キャンバスの上）。`laneCount == 0` なら何も出さない。高さは `AllDayBandMetrics.metrics(...).visibleHeight`、背景は紙の色、下端に 1 pt の線、中は縦の `ScrollView`（`scrollsInside` のときだけ動く）。ガターに「終日」（10 pt、右寄せ）、列の色（今日 → todayTint、土日祝 → weekendTint。曜日・祝日は `band.tones` から）、バー（x・幅は `viewport` で紙の x から、角 4 pt で続く側は 0、塗りは予定の色、字は読める色・`metrics.text` pt semibold・1 行・省略記号・枠で切る）。バーは `Button` → `onBarTap(eventId)`（編集）、列の空きは `onColumnTap(day)`（その日の終日予定の作成）。VoiceOver: 「題名（予定を編集）」「2026年10月7日(水) の終日予定を追加」。SwiftUI のビューなのでペンも指も紙に届かない（書けない） |
| `Views/CalendarRootScreen.swift` | `viewport` の受け取り（最初の 1 フレームは `PaperViewport.initial`）、`StickyHeaderView(viewport:)`、帯とキャンバスを `GeometryReader` の中の `VStack` に（`pageHeight` は領域の高さ）、`InkCanvasView` に `initialScrollX` / `onViewportChange`、compact の題名は `PageNavigation.compactTitle`、`show` / `applyRemote` / `reloadShownPage` で `BandMigration.migrate`（`show` と `reloadShownPage` では移した結果が読込と違えば dirty にして保存・送信）、`--screenshot-landscape` の `requestLandscapeOnce()`（`scenePhaseChanged` の `.active` と `appear()` の末尾、1 回だけ） |
| `Views/PageHeaderView.swift` | compact（幅 600 pt 未満）の 1 段目だけ `HStack(spacing: 4)`、`Spacer(minLength: 0)`、題名 `.headline`（17 pt semibold）。44 pt のボタン・`.bordered`・`fixedSize`・1 段のレイアウトは不変 |
| `Support/ScreenshotMode.swift` | 見本の線 `demo-stroke-week-wave`（週の水曜）と `demo-stroke-day-circle`（日のメモ列）を `grid` のマスで持つ（移し替えた結果と同じ座標）。`Config.landscape`（`--screenshot-landscape`）。見本の予定は不変（週の帯 = キャンプ・締切・家族旅行、日の帯 = 締切） |
| `Tests/TegakiCalendarTests/ScreenshotModeTests.swift` | 見本の線が `grid`、見本の 4 ページは移し替え不要、`--screenshot-landscape` の解析、`--screenshot-month 2026-06` の焦点 6/7（日曜） |

### 1.4 設定ファイルと CI（担当 C）

- `project.yml`: `MARKETING_VERSION` **0.5.1**（設定画面の「バージョン」とレコードの `app` が `0.5.1 (1)` / `ios/0.5.1/1` になる）。
- `.github/workflows/build.yml`:
  - `Run KitChecks` の閾値を **21764**（K の実数 21814 − 50）に。
  - `Pick a simulator` を前方一致の優先順（`iPad Pro 13-inch` → `iPad Air 13-inch` → `iPad` → `iPhone`。各段は名前を整列した最初）に。exact 一致の `iPad Pro 13-inch (M4)` は CI の Xcode 26.6 に存在しないので消した。
  - 13 インチの 4 ページと 6 シートを `ipad13-portrait-<page>.png` / `ipad13-portrait-sheet-<sheet>.png` に改名。13 インチのログ収集（`app-log.txt`、`--last 8m`）を追加機種の前に移した。
  - 既存の「11-inch day shot」のステップを、3 機種を 1 台ずつ起動するループに置き換え: `iphone`（exact `iPhone 17`、予備は前方一致 `iPhone 17` → `iPhone`）、`ipadmini`（`iPad mini (A17 Pro)`、予備 `iPad mini`）、`ipad11`（`iPad Pro 11-inch (M5)`、予備 `iPad Pro 11` → `iPad Air 11` → `iPad (A`）。同じ名前が複数のランタイムにあるときは 13 インチと同じランタイム > iOS が新しい方。各機種で 4 ページを `<id>-portrait-<page>.png`、iPhone はさらに `iphone-portrait-week-sun.png`（`--screenshot-month 2026-06`）と `iphone-landscape-<page>.png` × 4（`--screenshot-landscape`）。機種ごとに `shots/<id>-log.txt`。撮れなかった 1 枚はその 1 枚だけを失う（`::warning::` を出してジョブは落とさない）。追加機種の前に 13 インチのシミュレータを shutdown する（ランナーのメモリを次の 1 台に残す）。
  - `timeout-minutes` を 60 → **75**。
- `docs/M4B.md`（この文書）、`README.md`、`docs/DESIGN.md` の §2.2・§2.4・§2.5・§2.6・§2.11 に 1 行ずつ注記。

## 2. 確かめ方

### 2.1 GitHub Actions（Xcode 無しでも）

`m4b` ブランチへの push で `build` が走ります。緑なら「パッケージの検査（macOS、KitChecks 21814 項目と XCTest）」「アプリのビルド（シミュレータ）」「13 インチのシミュレータのテスト（`PaperTextTests`・`PaperViewTests`・`InkCanvasViewTests`・`InkLedgerTests` の差し替え分・`ScreenshotModeTests` と M4 までのテスト）」がすべて通っています。写真の手順はジョブを落としません。

成果物 `screenshots`（7 日保存）は最大 **27 枚 + ログ 4 本**（`app-log.txt` = 13 インチ、`iphone-log.txt`、`ipadmini-log.txt`、`ipad11-log.txt`）。「今日」は 2026 年 10 月 7 日（水）10:00（`-week-sun` だけ 2026 年 6 月 7 日（日）10:00）。

| 機種（CI のシミュレータの名前） | 幅（縦、pt） | 写真 |
| --- | --- | --- |
| 13 インチ iPad（`iPad Pro 13-inch (M5)`） | 1024 | `ipad13-portrait-month/week/day/year.png`、`ipad13-portrait-sheet-create/edit/lasso/settings/sync/import.png`（10 枚） |
| iPad mini（`iPad mini (A17 Pro)`） | 744 | `ipadmini-portrait-month/week/day/year.png`（4 枚） |
| 11 インチ iPad（`iPad Pro 11-inch (M5)`） | 834 | `ipad11-portrait-month/week/day/year.png`（4 枚） |
| iPhone（`iPhone 17`） | 402 | `iphone-portrait-month/week/day/year.png`、`iphone-portrait-week-sun.png`（5 枚）、`iphone-landscape-month/week/day/year.png`（4 枚。シミュレータの画面は縦のままでアプリだけが横向きになるので、CI が `sips -r 270` で起こしてから保存する。ヘッダーが 1 段なら横向きの要求が効いている。効かなかったときは縦の画面が横倒しに写る） |

M4 までの写真との対応（docs/M2.md〜M4.md の旧名はそのまま）:

| 旧名（M2〜M4） | 新名（M4b） |
| --- | --- |
| `ipad-portrait-month.png` … `-year.png` | `ipad13-portrait-month.png` … `-year.png` |
| `ipad-portrait-sheet-create.png` … `-sheet-import.png` | `ipad13-portrait-sheet-create.png` … `-sheet-import.png` |
| `ipad11-portrait-day.png`（96dafab で足した 1 枚） | `ipad11-portrait-day.png`（名前は同じ。4 ページの 1 枚になった） |
| `app-log.txt` | `app-log.txt`（13 インチ）+ `iphone-log.txt`・`ipadmini-log.txt`・`ipad11-log.txt` |

実際に選ばれた名前は各 run のログの `Using simulator:`（13 インチ）と `iphone: … / ipadmini: … / ipad11: …`（追加機種）に出ます（run 38752299042 では上の表の 4 つ。全部 exact 一致）。ジョブの時間は約 42 分（13 インチのテストまで 19 分、写真 23 分）。

### 2.2 この Mac（Command Line Tools だけ）

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 21814 checks passed」と出れば OK
cd ..
for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done   # 構文の確認（57 ファイル）
```

アプリ全体は Mac Catalyst SDK（`System/iOSSupport`）に対する型検査まで（[M4.md §4.4](M4.md) と同じ方法: ソースの写しで SwiftUI の `@State` を同じ形のラッパーに置き換え、`TegakiKit` を `arm64-apple-ios17.0-macabi` でビルドして `swiftc -typecheck`）。XCTest は Command Line Tools に無いので、XCTest の代役（スタブの module）に対するテストの型検査と、`ScreenshotMode` の見本を macOS のプログラムとして走らせる確認（50 項目）まで。`swift test` とシミュレータのテストは CI でだけ走ります。

### 2.3 実機で（TestFlight に入ってから。契約 §8-4）

| # | 確かめること | 期待 |
| --- | --- | --- |
| 1 | iPhone で月・週・日を横に流す（「指でも書く」がオンなら **2 本指**。縦に流すとき横にずれない） | 月は今日の列から（今日が水なら 月〜木 が見える）、週・日も同じ。縦スクロールは横にぶれない（方向ロック） |
| 2 | ピンチで縮める | minZoom より小さくならない（指を離すと戻る） |
| 3 | **年ページで最大まで拡大** | アプリが落ちない、ピンチが滑らか（紙は見えている範囲の周りしか持たない） |
| 4 | 年ページを横に流す | 月の列が 150 pt 以上で字が読める。各マスの見出しに「7 水」の形で日番号 |
| 5 | 週・日で終日予定 | 常に上の帯に見える。帯の空きをタップで「予定を追加」（その日の終日）、バーをタップで編集、帯には書けない（ペンで触れても線が出ない） |
| 6 | 帯の予定が 11 本以上（iPhone 縦） | 帯の中が縦にスクロールする（上限 35 %） |
| 7 | 回転 | 見出し・帯と紙がずれない（1 フレームの遅れは回転のアニメーションの中） |
| 8 | M4 以前に週・日の帯に書いた手書き | 0:00 の上端に出る。もう 1 台でも同じ位置（iCloud の merge で `grid` の形に収束） |
| 9 | iPad mini と 11 インチの横向き | ヘッダーが崩れない |
| 10 | iPhone で今日が金〜日のときの週・日 | 時刻ラベルが画面外（左に流せば見える）。受け入れるかは本人の判断（M4B-3） |

## 3. 本人が見るもの

### 3.1 数字（縦。横は幅が変わるだけで式は同じ）

| 機種（幅 pt） | 幅ぴったり 月・週・年 / 日 | minZoom 月 / 週 / 日 / 年 | minZoom で見える lu（月 / 週 / 日 / 年） |
| --- | --- | --- | --- |
| iPhone 17 縦（402） | 0.2871 / 0.402 | **0.5** / **0.4716** / **0.5612** / **1.3393** | 804（4.0 列）/ 852（ガター 64 + 4.1 列）/ 716（ガター 72 + 時間軸 588 + メモ 56）/ 300（ガター 56 + 2.2 列） |
| iPhone 16e・SE 縦（390） | 0.2786 / 0.39 | **0.5** / **0.4716** / **0.5612** / **1.3393** | 780 / 827 / 695（メモ 35）/ 291 |
| iPad mini 縦（744） | 0.5314 / 0.744 | 0.5314 / 0.5314 / 0.744 / **1.3393** | 1400 / 1400 / 1000 / 555（56 + 4.5 列） |
| iPad 11 インチ縦（834） | 0.5957 / 0.834 | 0.5957 / 0.5957 / 0.834 / **1.3393** | 1400 / 1400 / 1000 / 623（56 + 5.1 列） |
| iPad 13 インチ縦（1024） | 0.7314 / 1.024 | 0.7314 / 0.7314 / 1.024 / **1.3393** | 1400 / 1400 / 1000 / 765（56 + 6.3 列。端を含めて約 6.8 列） |
| 13 インチ横（1366） | 0.9757 / 1.366 | 0.9757 / 0.9757 / 1.366 / 1.3393 | 1400 / 1400 / 1000 / 1020（56 + 8.6 列） |
| 13 インチ 2/3 Split View（678） | 0.4843 / 0.678 | 0.4843（許容 5 % の内）/ 0.4843 / 0.678 / **1.3393** | 1400 / 1400 / 1000 / 506 |
| iPhone 横（812〜956。iPhone 17 は 874） | 0.58〜0.683 / 0.812〜0.956 | 幅ぴったり / 同 / 同 / 1.3393 | 1400 / 1400 / 1000 / 606〜714 |

太字が「幅ぴったりより大きい」= 横スクロールが起きる組み合わせ。初期の横位置: 月・週は今日の列が全部見える最小の x（今日 = 水なら 0、日曜なら月 596 / 週 548 lu）、年は今月の列の左端（10 月: iPhone 1064、13 インチ 635.4、iPad mini 844.5 lu）、日は 0。

帯の寸法（`AllDayBandMetrics`）: レーン max(22 lu × 倍率, 18 pt)、隙間 max(3 lu × 倍率, 2 pt)（日は 2 lu）、字 max(13 lu × 倍率, 11 pt)（日は 14 lu）、上 3 + 下 4 pt。iPhone の週 1 レーン → 18 / 2 / 11、高さ 25 pt。13 インチ縦 3 レーン → 18 / 2.19 / 11、高さ 65.4 pt。上限はページの見える高さの 35 %（iPhone 縦で領域 630 pt → 220 pt → 10 レーンまで全部見え、11 レーンから帯の中がスクロール）。

### 3.2 写真の確認表（契約 §8-3）

CI の run 38752299042（1 回目。ユニットテスト 5 件の失敗と時刻ラベルの省略記号を直した 2 回目はこの文書を含む commit の run）の成果物 27 枚を C（Claude）が全部見た結果を「結果」の列に書きました。本人が判断する項目は **太字**。

| 写真 | 見えていなければならないもの | 結果 |
| --- | --- | --- |
| `iphone-portrait-month.png` | ヘッダー 2 段で「今日」が文字で出ている。題名「2026年10月」が切れていない。曜日行が 月〜木 の 4 列（約 100 pt ずつ）で紙の列と揃う。バー: キャンプ（月 5、左が角張る）・締切（水 7）・家族旅行（月 12〜火 13、左が角張る）・出張（大阪）（水 21〜木 22）が 11 pt のレーンに 10 pt の字で収まり、はみ出しも重なりも無い。火 20 に 2 チップ＋「+3件」。10/7 に青い丸と 3 チップ。6 行とも縦に収まり、下にメモ欄の頭 | ○ 全部見えている: ヘッダー 2 段で「今日」が文字、題名「2026年10月」は切れていない、曜日行は 月〜木 の 4 列で紙の列線と揃う、キャンプ（左が角張る）・締切・家族旅行（12〜13）・出張（大阪）（21〜22）の 4 本とも字が枠の中、火 20 に 2 チップ＋「+3件」、10/7 に青い丸と 3 チップ、6 行の下にメモ欄の頭と赤い点。14 日の波線とマーカーも |
| `iphone-portrait-week.png` | 題名「10/5〜10/11」。曜日見出しの下に固定の帯: 「終日」が左、キャンプ（月・左が角張る）・締切（水）が 18 pt のレーンに 11 pt の字で読める（家族旅行は金曜の左端が約 10 pt だけ）。帯の下の紙は **9:00 のラベルから**。10:00 の 打合せ と 電話 が 2 列。水曜の列に今日の色と赤い現在線。「9:00」「10:00」が読める。見出しの列線と紙の列線が揃う | △→○ 1 回目は時刻ラベルが「10:…」「11:…」と省略記号で切れていた（M4B-10 の "23:00" の実測 2.48 em が誤りで、等幅数字では 2.705 em。上限を (gutter − 8) / 2.9 に直し、iPhone の週だけ 9.1 pt になる。2 回目で確認）。他は全部○: 題名「10/5〜10/11」、曜日見出しの下に固定の帯（「終日」・キャンプ（左が角張る）・締切・家族旅行の頭 約 10 pt）、レーン 18 pt・字 11 pt、紙は 9:00 から、打合せと電話が 2 列、水曜に今日の色と赤い現在線、見出しと紙の列線が揃う |
| `iphone-portrait-week-sun.png` | 今日 = 6/7 日曜: 紙が右に寄り（x = 548 lu）、見出しは 木〜日 の 4 列、時刻ラベルのガターは **見えない**。帯は 6 月の見本の終日予定（運動会・キャンプ・締切） | ○ 紙が右に寄り（x = 548 lu）、見出しは 水 3 の端 + 木 4〜日 7、時刻ラベルのガターは見えない。帯は 運動会（左端に尾）・キャンプ（4〜5）・締切（7）。日曜に今日の色と現在線。**この見え方を受け入れるかは本人の判断（M4B-3）** |
| `iphone-portrait-day.png` | 題名「10月7日(水)」。日付見出しの下に帯: 「終日」と 締切（約 321 pt の幅）。紙は 9:00 から、時間軸 330 pt が全部見え右に約 32 pt のメモ欄の覗き（罫線だけ）。打合せ・電話が 2 列、歯科 | ○ 題名「10月7日(水)」、日付見出しの下に帯（「終日」・締切 約 321 pt）、紙は 9:00 から、時間軸が全部見えて右に約 32 pt のメモ欄の罫線だけ、打合せ・電話が 2 列、歯科。時刻ラベル「10:00」は日のガター（64 lu = 36 pt）に収まる |
| `iphone-portrait-year.png` | 題名「2026年」。月名の行が「10月」「11月」「12月（一部）」。日番号のガターは見えないが、各マスの見出しに「1 木」「2 金」…。曜日字 20 pt、チップの字 17 pt（運動会 3 日・キャンプ 4〜5・家族旅行 9〜13 が帯でつながる）、「スポーツの日」が 12 日に読める。文字が枠の外に出ていない | ○ 題名「2026年」、月名の行は 10月（青）・11月・12月（一部）、ガターの日番号は見えず各マスの見出しに「5 月」「6 火」…、曜日字 20 pt、チップの字 17 pt、「スポーツの日」は 12 日のマスに。ただし **「家族旅行」のチップが「家族…」に切れていた**（チップ 58.6 lu に 4 字 52 lu + 余白 7.8 lu が入らない。倍率に依らない lu の問題で、M4 までは枠の外にはみ出していたのが D4 の clip で見えた。余白を 0.15 em に縮めて 2 回目で確認）。年のマスの祝日名「スポーツの日」は左 45 %（50.4 lu）に 6 字（61 lu）が入らず「スポー…」（既知の制限、月ページには全文） |
| `ipadmini-portrait-month/week/day.png` | M4 の 13 インチの写真と同じ構成（幅ぴったり）。週・日は帯が固定見出しの中にあり、紙は 9:00 から | ○ 構成は 13 インチと同じ（幅ぴったり、月は 7 列・6 行とメモ欄、日は 9:00 から・帯に 締切）。週は帯が固定見出しの中にある。ただし **週の紙は 9:00 からでなく 4:00 から**: iPad 縦では紙の高さ（1920 lu × 0.5314 = 1020 pt）が画面とほぼ同じで、紙の下端（24:00）で止まるため 9:00 までスクロールできない（M4 までの 13 インチの写真も同じ 4:30 からだった。帯が消えた分だけ 60 lu 下がった） |
| `ipadmini-portrait-year.png` | 月名が「8月（右端）9月 10月 11月 12月」。チップの字 17 pt。マスに日番号 | ○ 月名が 8月（右端）9月 10月 11月 12月、チップの字 17 pt、マスに日番号。「家族…」の切れは iPhone と同じ（2 回目で直る見込み） |
| `ipad11-portrait-day.png`（と month / week / year） | ヘッダー 1 段で「今日」が出ている（96dafab の確認）。帯に 締切 | ○ ヘッダー 1 段で「今日」が文字で出ている、題名「2026年10月7日(水)」、帯に 締切、紙は 9:00 から。month / week / year も 13 インチと同じ構成（週は 4:00 から。上と同じ理由） |
| `ipad13-portrait-year.png` | 月名が「6月（右 83 %）7月 … 12月」の約 7 列、チップ・曜日字・祝日名が読める。ガターの日番号は見えない、マスの見出しに日番号。**本人が 150 pt で「余裕を持って読める」かを決める**（列数が足りなければ 120 pt が第 2 候補、M4B-22） | ○ 月名が 6月（右 83 %）7月 … 12月 の約 7 列、チップの字 17 pt・曜日字 20 pt・祝日名「山の日」が読める、ガターの日番号は見えず、マスの見出しに日番号。10/16 の 4 件（ゴミの日・健康…・誕生日・資料…）はレーンに並ぶ。**150 pt で「余裕を持って読める」かは本人が決める（M4B-22）**。4 字以上の題名が切れる（家族…・健康…・資料…）のは列の幅でなくチップの lu の幅の問題（2 回目で余白を縮める。それでも 5 字以上は切れる） |
| `ipad13-portrait-week.png` | 帯に キャンプ・締切・家族旅行、レーン 18 pt、字 11 pt。紙は 9:00 から（帯の分 60 lu 上に動いていない）。残り 6 枚の 13 インチの写真は M4 と同じ | ○ 帯に キャンプ・締切・家族旅行、レーン 18 pt、字 11 pt。紙は 4:30 から（紙の下端で止まる。M4 と同じで、帯の分 60 lu 上に動いてはいない）。残り 6 枚の 13 インチの写真は M4 と同じ（シートの「情報」のバージョンは 0.5.1 (1)） |
| `iphone-landscape-*.png` | 撮れていれば: ヘッダー 1 段（幅 ≥ 600。これが横向きの判定）、月・週・日は幅ぴったり、年は横スクロール（10 月から）。`-week`: 紙が 3〜4 時間分見える・帯が 1 レーン全部見える。撮れていなければ「実機のみ」 | ○ 4 枚とも横向きに写った（`requestGeometryUpdate` が効いた。ヘッダー 1 段で題名は「2026年10月5日〜10月11日」の長い形）。シミュレータの画面自体は縦のままなので 1 回目の写真は 90° 回った形で撮れていた → 2 回目から CI が `sips -r 270` で起こす。月・週・日は幅ぴったり（月は 3 行、日は 10:00〜11:30）、年は横スクロール（8月の端〜12月）、週は 10:00〜13:00 の約 3 時間と帯 1 レーン全部 |

### 3.3 本人が決めること（契約 §9。返事が無ければ既定のまま）

| # | 内容 | 既定 | 見る写真 |
| --- | --- | --- | --- |
| M4B-22 | 年の列の幅: **150 pt**（1.3393。13 インチ縦 約 6.8 列・横 8.6 列・mini 4.5 列・iPhone 2.2 列）か 120 pt（1.0714。チップ 13.9 pt・祝日 11.8 pt・曜日 16.1 pt。13 インチ縦 7.9 列・横 10.9 列・mini 5.7 列・iPhone 2.9 列） | 150 | `ipad13-portrait-year.png`、`ipadmini-portrait-year.png`、`iphone-portrait-year.png`。120 にするなら `ZoomPolicy.readableColumnPoints` の年の 1 行と KitChecks / `ZoomPolicyTests` の数字 |
| M4B-3 | 週・日の時刻ラベル（と年の日番号）のガターが横スクロールで左に流れる。今日が金〜日の iPhone では最初から画面外 | この里程では紙のまま（UIKit の固定ガターは次の里程の候補） | `iphone-portrait-week-sun.png` |
| M4B-1 | 固定の帯のレーンに pt の下限（18 / 隙間 2 / 字 11） | 付ける | `iphone-portrait-week.png`・`-day.png`、`ipad13-portrait-week.png` |
| M4B-19 | 終日予定の横に書けなくなる（M3a の決定の取り消し）。帯に書いてあった手書きは 0:00 の上端へ | 受け入れる | 実機（M4 以前の手書きがある週・日） |
| M4B-21 | iPhone の「指でも書く」の既定（オン: 横スクロールは 2 本指） | オンのまま | 実機 |

## 4. 既知の制限・確認待ち

### 4.1 契約からの小さなずれ（意図したもの）

TegakiKit（K。検証者が照合済み）:

- `ZoomPolicy.minZoom` の判定 `fit ≥ 0.95 × readable` に 1e-9 の許容（665 pt の月で 665/1400 と 0.95 × 0.5 が浮動小数で同値にならない境目を契約どおり fit にする。表の数字は全て不変）。`visibleWidth` は viewportWidth が有限でない・0 以下なら 0（`initialScrollX` の規則と整合）、幅ぴったりのときは割り算でなく紙の幅そのもの。`PaperViewport.initial` は width が有限でない・負なら width 0（NaN を持つ viewport を作らない）。
- `AllDayBandLayout.empty(kind:)` は `.day` 以外（`.month` / `.year` を含む）を週の形で返す。`AllDayBandEngine.week(monday:)` は月曜でない日を月曜に正規化。`AllDayBandMetrics` に契約に無い public ヘルパー `gapLu(_:)`（週 3 / 日 2）・`textLu(_:)`（週 13 / 日 14）と `Metrics` の public メンバーワイズ init（追加のみ）。laneCount 0 のとき 0 になるのは contentHeight / visibleHeight だけで lane / gap / text は倍率だけで決まる。
- `BandMigration` の契約が無言の壊れたデータ: 週ページの `allday`（日の形）は col 0 で grid へ、日ページの `allday:YYYY-MM-DD`（週の形）は x そのままで grid へ、`w-` の日付が読めない pageId は col 0。strokes と deleted に同じ id がある異常なページでは墓標のある線は移さない。
- `PageLayoutTests.testSameGeometry` の 1 行を反転（契約は「変更なし」と書くが、ink が読まれなくなったので `sameGeometry` は true になる。§7.1 の「sameGeometry は ink で変わらない」が正）。`testPaperSpecConstants` は無変更。
- 「帯の中のドラッグは 0:00 に clamp」の検査の期待値: 週の rect(700, 0, 760, 30) は紙の上端が 0:00 になったので 0:00–0:30 に（日の rect(200, 0, 300, 20) は結果不変）。KitChecks の 10/12 の週の帯の見本を精密化（家族旅行の尾 + 10/16 の 4 件 = 5 本）。
- `PageLayout.swift` は `PageBand` / `NowLine` のドキュメントコメントだけ変更。`WeekLayoutEngine` / `DayLayoutEngine` の箱の `frame.origin.y += grid.minY`（= 0）は残してある。

紙と台帳（P。検証者が照合し、テスト名 1 つを契約の名前に戻した）:

- `PaperView` の窓の属性は契約の `window` でなく **`contentWindow`**（`UIView.window: UIWindow?` と衝突してコンパイルできない）。`static window(for:content:)` と `show(visible:zoom:contentSize:)` は契約どおり。`private(set) var displayRequestCount` と `setNeedsDisplay()` の override（回数を数えるだけ）を足し、`PaperViewTests` の「描き直さない」は `layer.needsDisplay()` でなくこの回数で見る（画面に無いビューでは layer の旗が当てにならない）。`show` の「窓が visible を含む」判定は `visible ∩ (0, 0, content)` で行う（端でバウンスしても窓を作り直さない）。visible が空・非有限のときは窓 `.zero`。
- `PaperRow` は契約の `viewport` / `columns` に加えて `kind: PageKind` を持つ（width 0 のとき `PaperViewport.initial(kind, viewportWidth: 提案された幅)` を Layout の中で計算するため）。`StickyHeaderView` の公開の署名は契約どおり。
- `InkCanvasView`: `container.onLayout = …` を `makeUIView` から `Coordinator.attach(_:)` へ移した（テストが `Context` 無しで同じ配線にできる）。`isApplyingGeometry` は `applyPending` → `containerDidLayout` の入れ子があるので前の値を保存して `defer` で戻す。
- `PaperText.gutterLabelEms = 2.6` を足した（M4B-10 の数字を一箇所に）。`MonthPaper.drawTimedChips` のクリップは `saveGState` / `clip` / `defer { restoreGState }` をループ本体に置く（「+n件」の `continue` 経路も restore する）。
- テストの追加（契約より多い分）: `InkLedgerTests.testLedgerMigratesTheDayBandOnInit`（`d-` ページ）、`InkCanvasViewTests.testInitialScrollXPutsTodaysColumnOnScreen`（日曜の月 → 596 lu → 298 pt）と `testDefaultArgumentsOfTheNewParameters`、`PaperTextTests` の文脈 nil の検査、`PaperViewTests` の中央・右下・バウンス・内容 .zero・完全に外の例。`PaperTextTests` のクリップは契約の 3 点に加えて rect の外を全画素で検査する。

画面（U。検証者が照合済み）:

- `CalendarRootScreen.show(kind:focus:)` で pageId が変わるときだけ `viewport = .zero` に戻す（次のページの最初の 1 フレームを前のページの offset / zoom で描かないため。契約は無言）。`requestLandscapeOnce()` は `UIWindowScene` が見つかって実際に送ったときだけ `landscapeRequested = true`（`appear()` の時点でシーンが無ければ `.active` で送る）。`canvas` は computed property から `canvas(viewportWidth:)` に（`initialScrollX` に `GeometryReader` の幅が要る）。
- `AllDayBandView`: 「終日」のガターの枠は `[x(ofPaper: 0), + width(ofPaper: gutter)]`（右端は契約と同一。紙と一緒に左へ流れる）で、VoiceOver からは隠す（列とバーのラベルに「終日予定」が含まれる）。バーの文字は `.clipped()` でなく `.clipShape(角丸)`（角の外にも出ない）。列の色と空きのタップ標的は帯の内側スクロールの内容の全高（レーンが多いとき下の空きも「追加」になる）。契約に無い static `barCorner` 4・`textPad` 6・`barShape`・`barLabel`・`columnLabel`。
- `ScreenshotMode.Config.landscape` は既定値 false 付き。ファイル先頭の注記は既存どおり英語。`ScreenshotModeTests` は契約 §7.3 に加えて 6 月の週の帯・4 ページ全部の移し替え恒等・波と円の座標・シート併用も見る。

統合（C。1 回目の CI の結果で直したもの）:

- `PaperTextTests.render` が画素を読むときに画像を上下に反転していて（`CGImage` を bitmap context に描くと先頭の行が上なので反転は不要）、文字を y ≈ 80 に読んで 2 本が落ちた。反転を外した（クリップ自体は正しく、1 回目の失敗の位置（13, 80）も反転の位置と一致）。
- `PaperViewTests.testWindowIsTwoByTwoScreensClippedToTheContent` の 1 例目: 契約 §1.6 の例 (1224, 0, 651, 1200) は契約自身の定義（visible を半分ずつ広げて内容と交差）では (1224, 0, 651, **900**)（広げた矩形は y −300…900 で止まる。2 例目・3 例目はこの定義どおりの数字）。実装は定義どおりなのでテストの期待値を 900 に直した（メモリの見積もりは 651 × 900 ≈ 21 MB）。
- `PaperText.gutterLabelEms` 2.6 → **2.9**（M4B-10 の実測値の誤り。上の §1.2）。`PaperTextTests` の数字を 19.31 に。
- `YearPaper` のチップの文字の余白 0.3 em → 0.15 em（上の §1.2）。
- `build.yml`: iPhone の横向きの写真を `sips -r 270` で起こす（§2.1）。
- 追加機種の前に 13 インチのシミュレータを shutdown する（契約は C の判断に委ねていた。前回の run は 2 台同時でも動いたが、ランナーのメモリを次の 1 台に残す）。
- `Pick a simulator` の最後の砦「`iPhone 17`」は残した（ステップ自体は落とさない）。
- docs/M4.md 以前の写真の名前は直していない（M4B-7。対応表は §2.1）。

### 4.2 実機でしか確かめられないこと

- ピンチの下限と戻り（`bouncesZoom`）、拡大時のメモリと滑らかさ（年ページの maxZoom 2.679 / 2.926）、横スクロールの指の感触（方向ロック・2 本指）、横のスクロールインジケータ。
- iPad の横向き（CI は iPad を回せない）。iPhone の横向きは `requestGeometryUpdate` が効いたときだけ写真に写る。
- Apple Pencil が帯に触れたときに線が出ないこと（帯は SwiftUI のビュー）、帯の中がスクロールする状態（11 レーン以上）でクリップの外のバーがタップできないこと（`ScrollView` のクリップに頼る）、列の空きが VoiceOver で要素として読まれるか。
- iCloud 越しの移し替えの収束（§4.3）。
- 固定見出し・帯と紙の列線の揃いは CI の写真で 1 pt 以内まで。浮動小数の丸めで 1 px 以内の差が出うる。

### 4.3 動作上の注意

既知の制限（契約 §6.5 の (a)〜(e)）:

- (a) **iPhone の横向きは閲覧向け**: 高さ 402 pt から安全領域・ヘッダー 1 段・固定見出し・帯 1 レーン・ツールバーを引くと紙に約 165 pt（約 3.8 時間）しか残らず、帯の上限 35 % ≈ 66 pt で 3 レーン目から帯の中がスクロールする（2 レーンまで全部見える）。
- (b) **月のチップの英小文字のディセンダ**（g・p・y）は最大 1 pt 欠ける（チップ 20 lu に 10 pt = 20 lu の字。CJK の字の実高 19.2 lu は枠の中。M4B-20）。
- (c) **紙は半画面ごとに窓を作り直す**: 見えている範囲の周り 2 × 2 画面分だけを持ち、横縦とも半画面動くまでは描き直さず、超えると 1 回描き直す（M4B-25）。速いフリックで窓の作り直しが 1 フレーム遅れ、紙の端に容器の背景（紙色）が一瞬見えることがある。ピンチ中は毎フレーム描き直す（従来どおり、量だけ有界）。
- (d) **年ページの日番号のガターは横に流れる**（全機種で今月の列から始まるので最初から画面外）。各マスの見出しに日番号「7 水」を描いて補う（13 インチ横では両方見える）。週・日の時刻ラベルも同じ（今日が金〜日の iPhone。M4B-3）。
- (e) **iPhone で「指でも書く」がオンのときの横スクロールは 2 本指**（1 本指のドラッグは線になる）。ツールバーの「指でも書く」を切れば 1 本指。既定は変えない（M4B-21）。

移し替えの筋道（契約 §3.4）: 端末 A（0.5.1）が週・日ページを開く → 読込で帯の線を `grid` に移す → 違いがあれば dirty → 1.5 秒後にファイル、さらに 1.5 秒後に iCloud。端末 B（0.5.1）はプッシュか前面復帰で merge（既存の `compareStrokes` で `grid` が `allday…` に勝つ）→ 表示は読込時に移し替え済みなので変わらない。0.5.0 の端末が残っていてもその merge で `grid` が勝つので往復しない。旧形が iCloud に残っている間に消した線は id が同じなので墓標で消える。リモートから来たページの帯の線を merge の後に移しても id が同じなら `contentDiffers` は dirty にしない（契約どおり。収束は各端末の読込側の dirty + 保存に頼る）。

横向き（契約 §6.4）: `simctl` に回転の命令は無く、iPadOS は多タスク対応アプリの向きの要求（`UIWindowScene.requestGeometryUpdate`）を無視する。iPhone は従う。そこで iPhone だけ `--screenshot-landscape` で 4 枚撮る。効いたかの判定は写真のヘッダーが 1 段（幅 ≥ 600）かどうか。iPad の横向きは実機で本人が確かめる。

そのほか:

- 終日予定の無い日・週には帯を出さない（高さ 0。M4B-2）。追加は「＋予定」か 予定 道具。ガターの「終日」のタップは何もしない（M4B-14）。
- 読込で移し替えたページはすぐ保存・送信する（M4B-11）。スクリーンショットモードでは保存が何もしないので無害。
- `minZoom` は幅 665 → 664 pt の境目で 0.475 → 0.5 に跳ぶ（Split View を指で連続して動かすときだけ。M4B-23）。
- iPhone 縦の日ページでは右端にメモ欄が約 32 pt（390 pt 機で約 20 pt）だけ覗く（時間軸 330 pt を優先。「メモ」の字はスクロールしないと見えない。M4B-24）。
- ページ切替の最初の 1 フレームは固定見出し・帯が `PaperViewport.initial`（offset 0・minZoom）で、キャンバスが `initialScrollX > 0` で始まる場合（iPhone で今日が日曜の月・週、年ページ）は次のターンの通知で揃う（契約 §1.3 / §1.5 が受け入れている 1 フレームの遅れ）。
- `initialScrollY` は週・日で 60 lu 小さくなった（今日 10:00 → 720 / 900 lu = 9:00。紙に帯が無い）。**iPad 縦の週ページは 9:00 まで行けない**: 紙の高さ 1920 lu × 倍率（mini 1020 pt、11 インチ 1144 pt、13 インチ 1404 pt）が画面の高さとほぼ同じで、紙の下端（24:00）で止まるので 4:00〜4:30 から見える（M4 までも同じ）。iPhone は紙 1920 × 0.4716 = 905 pt に対して画面が 600 pt 弱なので 9:00 から。日ページ（2400 lu）はどの機種でも 9:00 から。
- `AllDayBandEngine` の同日同長の bars の順序は題名の String 比較（Unicode スカラー順）に依る。

### 4.4 技術的な注記

- 言語モードは Swift 5・並行性チェックは minimal のまま。`PaperViewport` / `ZoomPolicy` / `AllDayBand*` / `BandMigration` は `TegakiKit`（Foundation + CoreGraphics の型だけ。UIKit を import しない）。
- `notifyViewport` の規則: y だけの変化は送らない（iPad の月・週・日は横に動かないので縦スクロール中に SwiftUI の更新が 1 回も起きない）、指の動きは同期、レイアウト・ページ切替・プログラムからの代入は次のターンに最新値を 1 回、次のターン送りが控えている間は同期に送らない。attach の直後（容器の幅がまだ 0）に `(offsetX 0, zoom 1, width 0)` が 1 回届きうるので、受け手は `width == 0` を `PaperViewport.initial` に置き換える（`CalendarRootScreen` と `StickyHeaderView` はそうしている）。
- `AllDayBandMetrics.metrics` は pageHeight が有限でない・0 以下なら 0 とみなし visibleHeight が 0 になる（`CalendarRootScreen` は `GeometryReader` の高さを渡す）。
- `InkCanvasViewTests` は `Task { @MainActor }` の次ターン配信を `await Task.yield()` × 8 で待つ（`SyncEngineTests` と同じ頼り方）。`PaperTextTests` は 20 pt bold の「I」の縦棒が rect (10, 10, 20, 10) に掛かるというグリフの描画に依存する（外側の全画素検査はクリップが正しければ必ず通る）。
- `MonthLayoutEngine.packAllDayLanes` が帯の詰め方の唯一の出所（Web 版 `allDayRowsForRange` と同じ）。
- この Mac には Xcode が無いので、本番のコンパイルは CI。手元では TegakiKit の `swift build` / `KitChecks`、全ファイルの `swiftc -parse`、アプリ全体の Catalyst SDK に対する型検査、XCTest の代役に対するテストの型検査まで（§2.2）。
