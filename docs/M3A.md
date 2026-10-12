# M3a の実装結果（週・日・年ページ＋表示の切替＋ページごとの手書き）

[M3A_CONTRACT.md](M3A_CONTRACT.md) の契約を実装した結果のまとめです。設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 行が伸びるレイアウトの定数、§2.4〜2.7 各ページとヘッダー、§3.4 マスの鍵）。[M2.md](M2.md) の続きで、M2 で出来ていたこと（月ページ・手書き・予定の読み取り）はそのまま生きています。
ブランチ `m3a`。`main` への取り込みはリード（本人）が行います。

## 1. 作ったもの

### 1.1 TegakiKit（ローカル Swift パッケージ。Foundation だけに依存）

| ファイル | 内容 |
| --- | --- |
| `Layout/PageLayout.swift` | 4 ページ共通の形 `PageLayout`（`kind` / `pageId` / `size` / `cells` / `dateLabels` / `allDayBars` / `timedBoxes` / `nowLine`、`cell(at:)` / `inkCell(forCenter:)` / `growsWithInk` / `hit(at:)` / `band(atY:)` / `bandTop`）、`PageKind`、`PageBand`、`HitTarget`（`.timedBox` を追加）、`NowLine`、`TimedEventBox`、`PageScroll.scrollDelta`（M2 のスクロール補正を全ページに一般化） |
| `Layout/PaperSpec.swift` | 週・日・年の定数（DESIGN §2.2 と同じ数字）と `CellKey` の追加（`allday:YYYY-MM-DD` / `allday` / `grid` / `MM-DD`）。保存形式は変えていない |
| `Layout/TimedEventEngine.swift` | 時間指定の予定の重なり処理（Web 版 `layoutTimedEvents` の移植。見た目の最短 15 分、深夜をまたぐ予定は日ごとに切る）と箱の矩形 `boxFrame` |
| `Layout/LanePacking.swift` | レーンの間引き（Web 版 `allDayLaneMetrics` の移植。上限に達したときだけ） |
| `Layout/WeekLayoutEngine.swift` | 週ページ: 終日帯 `min(800, max(60, レーン×25+30, 手書き+12))` ＋ 時間軸 1920（伸びない）。帯の端は週の外へ続くと角張る。現在時刻の赤線は今日の列だけ |
| `Layout/DayLayoutEngine.swift` | 日ページ（幅 1000）: 終日帯 `min(800, max(60, レーン×24+30, 手書き+12))` ＋ 時間軸 2400。時間軸は x 72〜660、右 340 はメモ欄（罫線） |
| `Layout/YearLayoutEngine.swift` | 年ページ: 12 列 × 31 行。行の高さ `min(400, max(60, 16+レーン×18+8, 手書き+12))`（12 か月で一番多いマスに合わせる）。終日のチップはマスの右 55 %、複数日は同じレーンで日をまたいで帯でつなぐ。存在しない日（2/30 など）も斜線のマスとして持ち、書ける |
| `Layout/PageNavigation.swift` | `pageId`（"d-2026-10-04" / "w-2026-09-28" / "m1-2026-10" / "y-2026"、Web 版と同じ文字列）、表示範囲、◀ ▶ の移動、題名、初期スクロール |
| `Layout/MonthPageLayout.swift`・`MonthLayoutEngine.swift` | 月ページを `PageLayout` に適合（公開 API は維持。`scrollDelta` は `PageScroll` に委譲） |
| `KitChecks/main.swift` | 460 項目を追加して **724 項目**（Web 版 `event-layout.test.mjs` の `layoutTimedEvents` の節を全て移植、乱数 300 回を含む） |
| `Tests/LayoutTests/` | `PageLayoutTests`・`TimedEventEngineTests`・`WeekLayoutEngineTests`・`DayLayoutEngineTests`・`YearLayoutEngineTests`・`PageNavigationTests` を追加（内容は KitChecks と同じ） |

### 1.2 アプリ（Sources/TegakiCalendar）

| ファイル | 内容 |
| --- | --- |
| `Views/CalendarRootScreen.swift` | M2 の `MonthPageScreen` を置き換えた唯一の画面。`kind`（日/週/月/年）と `focus`（見ている日）を状態に持ち、最後に見ていた表示と日付を UserDefaults（`lastPageKind` / `lastFocusDate`）に記憶。ページ切替前・バックグラウンド移行時に保存。ページごとに `InkCanvasView` を作り直す（`.id(pageId)`）。週・日で今日が見えているあいだ 30 秒ごとに現在時刻の線を動かし、日付が変わったら「今日」の印を移す。タップの振り分け（帯・チップ・箱 → 詳細シート、「+n件」・日付・年の曜日の字・薄いチップ → 日ページ） |
| `Views/PageHeaderView.swift` | ◀ 今日 ▶・題名・日/週/月/年 のセグメント（accessibilityLabel「日表示」など）・カレンダーのメニュー |
| `Views/StickyHeaderView.swift` | 紙の上に固定する見出し。月: 曜日の行（M2 のまま）。週: 7 日の日付見出し（曜日・日付・祝日名。タップで日ページ）。日: 日付のブロック（数字・月・曜日・祝日のバッジ）。年: 「1月」〜「12月」（タップで月ページ）。列幅は紙の比率（`FractionRow`） |
| `Views/OnboardingView.swift` | 初回案内 3 枚（`MonthPageScreen` から移動。内容は変更なし） |
| `Views/EventDetailSheet.swift` | 予定の内容（閲覧のみ）。「+n件」の一覧シート `DayEventsSheet` は日ページに置き換わったので削除 |
| `Paper/PaperView.swift` | `PaperContent`（month / week / day / year）、`PaperPalette`（Web 版 `views.css` の色）、`PaperRenderer`、紙ビュー本体。`Ink/PaperView.swift` から移動して一般化 |
| `Paper/PaperText.swift` | 文字の大きさ（Web 版 TYPE 表: lu と画面上の最小 pt）、ヘアライン、ピクセル合わせ、1 行・複数行の文字描画、角丸 |
| `Paper/MonthPaper.swift` | M2 の月ページ描画をそのまま移動（見た目は変えていない） |
| `Paper/TimeGridPaper.swift` | 週・日で共用: 時間軸の線と時刻ラベル、「終日」、終日の帯／チップ、時間指定の箱（高さに応じて 3 段階: 題名だけ／「9:00 題名」／時刻の行＋題名 2 行）、現在時刻の赤線（画面上 2 pt、倍率に依らない） |
| `Paper/WeekPaper.swift`・`DayPaper.swift`・`YearPaper.swift` | 各ページの紙（列の色、斜線、日付帯、曜日の字、祝日名、チップ、つなぎの帯、今日の枠） |
| `Ink/InkLedger.swift` | `any PageLayout` に一般化。新しい線の所属マスは `layout.inkCell(forCenter:)`（紙の外・時刻帯・年の日付帯の後始末は Layout 側）。時間軸（`grid`）に書いても再レイアウトしない。別ページの `page` / `layout` が来たら Debug では assertion、Release では無視 |
| `Ink/InkCanvasView.swift` | 倍率の最小は「画面幅 ÷ 紙の幅」（日ページは幅 1000）、初期スクロール `initialScrollY` を最初の 1 回だけ適用、スクロール補正は `PageScroll.scrollDelta`、紙だけの変化（赤線・過去の予定の薄さ）は線を触らず紙だけ描き直す |
| `Calendar/EventKitService.swift`・`EventStoreModel.swift` | 任意の日付範囲の取得 `events(from:to:calendars:allDayOnly:)`。ページの範囲（日 1 日／週 7 日／月 42 日／年 365〜366 日）を読む。年は終日の予定だけ |
| `Support/ScreenshotMode.swift` | `--screenshot-page day\|week\|month\|year`（既定 month、不正値は month）。7 日（今日）に見本の予定 4 件（終日「締切」、「打合せ」10:00〜11:30 と「電話」10:30〜11:00 で 2 列、「歯科」14:00）を追加。ページごとの見本の線（週: 水曜の帯の波線と箱の上のマーカー、日: 帯の丸とメモ欄の波線 2 本、年: 10/7 の赤丸と 2/30 の線） |
| `Tests/TegakiCalendarTests/InkLedgerTests.swift` | 週の帯・時間軸・日・年の日付帯（1 月の列に付いて x が負）・帯の伸びで時間軸の線が平行移動・別ページの reload / relayout が無視される、を追加 |
| `Tests/TegakiCalendarTests/ScreenshotModeTests.swift` | 新規: 起動引数の解析、focus が 7 日、各ページの見本の pageId とマス、7 日の見本の予定 |

### 1.3 CI（.github/workflows/build.yml）

スクリーンショットの手順を 1 回の起動から **4 回**（month → week → day → year、起動のたびに終了してから `--screenshot-page` を変えて起動）にしました。成果物 `screenshots` に `ipad-portrait-month.png`・`-week.png`・`-day.png`・`-year.png` と `app-log.txt` が入ります。他の手順（macOS で `swift build` → `KitChecks` → `swift test`、XcodeGen、シミュレータ向けビルド、シミュレータのユニットテスト）は M2 のままです。`project.yml` の `MARKETING_VERSION` は 0.3.0。

## 2. 確かめ方

### 2.1 GitHub Actions（Xcode 無しでも）

`m3a` ブランチへの push で `build` が走ります。緑なら「パッケージの検査（macOS、KitChecks 724 項目と XCTest）」「アプリのビルド（シミュレータ）」「シミュレータのテスト（InkLedgerTests・EventKitServiceTests・ScreenshotModeTests）」がすべて通っています。

成果物 `screenshots`（7 日保存）の 4 枚は、iPad Pro 13 インチのシミュレータで 2026 年 10 月 7 日（水）10:00 を「今日」として撮ったものです。見本の予定は M2 と同じ 22 件に 7 日の 4 件を足したもの。見どころ:

- `ipad-portrait-month.png`: M2 と同じ月ページ。7 日のチップが 3 件になる（行の高さは 175 のまま）。
- `ipad-portrait-week.png`: 10/5〜10/11 の週。固定見出しに 7 日の日付（7 日は青い丸）、終日帯に キャンプ（4〜5 日、月曜の左端が開く）・締切（7 日）・家族旅行（9〜13 日、日曜の右端が開く）、時間軸に 打合せ と 電話 が 2 列、歯科 が 1 列。10:00 の赤線。初期スクロールは 9:00（今日の 1 時間前）。水曜の帯に波線、打合せの箱の上にマーカー。
- `ipad-portrait-day.png`: 10 月 7 日。固定見出しに「7 10月 水曜日」、終日帯に 締切 のチップ、時間軸に 3 つの箱（2 列）、右にメモ欄と波線 2 本、帯の中に青い丸。
- `ipad-portrait-year.png`: 2026 年。12 列 × 31 行、10/7 に青い枠と赤い丸、存在しない日は斜線、終日の予定は各マスの右側のチップ（家族旅行は 9〜13 日をつなぐ帯）。初期スクロールは 5 日の行（今日の 2 行上）。

### 2.2 この Mac（Command Line Tools だけ）

```bash
cd TegakiKit
swift build            # DayKit / Holidays / Layout / InkModel / KitChecks をビルド
swift run KitChecks    # 「KitChecks: all 724 checks passed」と出れば OK
cd ..
for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done   # 構文の確認
```

XCTest は Command Line Tools に無いので、パッケージの `swift test` とアプリのテストは CI でだけ走ります。

### 2.3 iPad で（TestFlight に入ってから）

1. ヘッダー右の「日 | 週 | 月 | 年」で表示を切り替えます。切り替えても見ている日は変わりません（週 → 日ならその週の中の日、年 → 月ならその月）。
2. ◀ ▶ は日なら 1 日、週なら 7 日、月なら 1 か月、年なら 1 年。「今日」で今日へ（表示は変えません）。
3. 月ページの日付の数字、年ページの曜日の字、週ページの固定見出しの日付をタップすると、その日の日ページへ。年ページの月名をタップするとその月の月ページへ。「+n件」もその日の日ページへ（M2 の一覧シートは無くなりました）。
4. 週・日ページは今日が見えていれば「今の 1 時間前」、そうでなければ 7:00 の位置で開きます。年ページは今日の行の 2 行上。
5. 週・日ページの終日帯に書くと帯が伸びます（上限 800）。時間軸に書いても伸びません（紙だから、はみ出して隣に重なります）。年ページはマスに書くとその日の行が伸びます（上限 400）。
6. 手書きはページごとに保存されます（`w-2026-10-05`・`d-2026-10-07`・`y-2026`）。アプリを開き直すと、最後に見ていた表示と日付で開きます。

## 3. 本人が見るもの

- ヘッダー: `◀ 今日 ▶ 題名 [日 | 週 | 月 | 年] 📅`。題名は 日「2026年10月7日(水)」（祝日なら「2026年10月12日(月) スポーツの日」）／週「2026年10月5日〜10月11日」（年をまたぐ週は両側に年）／月「2026年10月」／年「2026年」。
- 週ページ: 左に時刻帯（0:00〜23:00）、7 列。今日の列は薄い青、土日祝の列は薄い茶。上に終日帯（「終日」のラベル）、下に 24 時間の時間軸（1 時間 80 lu、30 分に破線）。時間指定の予定は色の箱（左の縁が濃い色、重なると列に分かれる、過ぎた予定は薄い）。今日の列に赤い現在時刻の線（左端に丸）。
- 日ページ: 幅が 1000 なので画面上はやや大きめ。左に時刻帯、時間軸は幅の 6 割、右 3〜4 割はメモ欄（罫線、「メモ」）。終日のチップは時間軸の幅いっぱい。
- 年ページ: 左に 1〜31 の日付帯、12 列。土曜は薄い青、日曜・祝日は薄い赤、今日は濃い青の背景と枠。各マスの左上に曜日の字（祝日はその下に祝日名）、右 55 % にチップ。存在しない日（2/30、4/31 など。平年の 2/29 も）は斜線。
- 固定見出し（スクロールしない、書けない）: 週は曜日＋日付（今日は青い丸、1 日は「10/1」、祝日名つき）、日は日付のブロック、年は月名（今の月は青）。
- ツールバー（下端）はどのページでも同じ。

## 4. 既知の制限・確認待ち

### 4.1 契約からの小さなずれ（意図したもの）

- `HitTarget` は Swift の enum に extension で case を足せないため `MonthPageLayout.swift` から `PageLayout.swift` へ移した（呼び手の import は変わらない）。
- `MonthLayoutEngine.scrollDelta` は `PageScroll.scrollDelta` に委譲するが、紙の下（y ≥ 高さ）の点だけは M2 どおりメモ欄の移動量を返す（既存テストの期待値を変えないため）。`PageScroll.scrollDelta` 自体は契約どおり紙の外で 0。
- `InkLedger` に `static var onPageMismatch`（既定は `assertionFailure`）を追加。「別ページの reload が無視される」ことを Debug のテストで確かめるための差し替え口。
- 同じキャンバスに別 pageId の `page` と `layout` が揃って来たときは `reload` ではなく `InkLedger` を作り直す（reload は pageId 不一致を assert する仕様のため。効果は `keepHistory: false` と同じ）。
- `EventKitService.events(from:to:calendars:)` に既定値付きの `allDayOnly` を追加（年ページは EKEvent の段階で時間指定を捨てる）。
- `Paper/TimeGridPaper.swift`（契約の一覧に無い）を追加して週・日の描画を共用。`ContentView.swift` は 1 行だけ変更（`CalendarRootScreen` を表示）。
- `CalendarRootScreen` の状態は `paper: PaperContent` 1 つにまとめ、`layout` はそこから導出（契約 §4.1 は別々の `@State` を書いているが private な内部構成の違い）。
- 月ページの文字の最小 pt を M2 の一律 10 pt から契約 §3.2 の TYPE 表（日付 12・チップ 10・祝日 9・メモ 10.5）にした。幅ぴったりの倍率（iPad）では同じ大きさ。
- 週・日・年の固定見出しの背景は Web 版と同じ紙色、月の曜日行だけ M2 のまま `secondarySystemBackground`。
- 年ページで同じ日・同じ長さの予定の並びは M2 と同じ Unicode の `<`（Web 版の `Intl.Collator('ja')` とは順序が異なり得る）。
- 契約に無い加算的な追加: `PageBand.row(_:)/.memo/.allDay/.grid/.rowIndex`、`LaneMetrics.plain(lane:gap:)`、`TimedEventEngine.dayMinutes`、`PageNavigation.weekdayLetters`。`YearPageLayout.cellFrame` は範囲外で nil、`columnFrame` は 1…12 に clamp。

### 4.2 実機でしか確かめられないこと

- 文字の見え方: 年ページの曜日の字・チップ・祝日名は幅ぴったりの倍率で非常に小さい（Web 版と同じ最小 pt）。日ページは幅 1000 なので他より大きめに見える。
- 現在時刻の線の 30 秒更新の描画負荷（紙だけの描き直し。幾何は変わらない）。
- 時間指定の箱の 3 段階（短い／1 行／時刻＋題名）は Web 版の px 判定を lu に換算したもの。倍率の端で段階が Web 版とずれる可能性がある。
- 固定見出しの列幅は `FractionRow` で紙の比率から出しているので、幅ぴったりの倍率でだけ紙と一致する（M2 §4.3 と同じ既知の制限）。
- ページ切替のたびにキャンバスを作り直す（`.id(pageId)`）。切替の体感（一瞬の空白）が気になれば DESIGN §3.10 の「1 枚を使い回す」を M3b 以降で。

### 4.3 動作上の注意

- 時間軸（週・日の `grid`）は伸びない。上限（週・日の帯 800、年の行 400）を超えた手書きははみ出して隣に重なる（DESIGN §2.2）。
- 週の帯の左の時刻帯（x < 64）と紙の外に書いた線は月曜（または日曜）の帯に属し、x が負になる。年の日付帯（x < 56）は 1 月の列に属する（DESIGN §3.4）。
- 年ページの上限（400）での間引きは Web 版と同じ条件（`lanes×18 − 2 > 376`）。ちょうど 21 レーンでは行は 400 に達しても間引かれない。
- ヘッダーは題名とセグメント（幅 220）を 1 段に置くので、iPhone や Split View の狭い幅では題名が縮む（iPhone 向けの 2 段化は M3b）。
- `ScreenshotModeTests` の既定月の検査は `YearMonth.current()` に依存（月をまたぐ瞬間に走れば失敗しうる。CI では実質問題なし）。
- M3b に残すもの（この段階では触らない）: 予定の作成・編集・削除、予定ツール、投げなわ、設定画面、初回案内の 4 枚化、iPhone の見た目、キャンバスの使い回し、上限を超えた月の行のレーン間引き。

### 4.4 技術的な注記

- 言語モードは Swift 5・並行性チェックは minimal のまま。UI の class は `@MainActor`。`PageLayout` は `Sendable` で `Equatable` ではない（`any PageLayout` のまま比較できないため）。具体型 4 つは `Equatable`。
- この Mac には Xcode が無いので、本番のコンパイルは CI。手元では TegakiKit の `swift build` / `KitChecks`、全ファイルの `swiftc -parse`、Catalyst SDK と XCTest のスタブに対する型検査まで。
