# M4c 実装契約（一覧（fitAll）を基本の状態にし、ピンチで拡大、ダブルタップでその日へ）

この文書は M4c の各担当が同時に作業するための **約束事**（公開 API・数字・文言・ファイル所有）です。[M4B_CONTRACT.md](M4B_CONTRACT.md) の続きで、M2〜M4b で決めたことはそのまま生きています（ここに書いていない API は変えません）。設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 座標系と倍率、§3.8 ズーム）。行番号は main（0.5.1、f7d8877）のものです。**第 2 版**（2026-10-16。3 つの観点（コード照合・ピンチ・UX）の所見を反映。何を変えたかは §9 の末尾）。

**きっかけ（本人の実機での指摘、2026-10-16。0.5.1 を iPhone・iPad mini・11 インチ・13 インチで試用）**: M4b の 1〜4 は問題なし。(5)「ピンチができません」。仕様変更の要望: 「日、週、月、年と、基本的に全画面にして一覧表示できるようにして下さい。そしてピンチイン、ピンチアウトで拡大縮小できるようにして、ユーザーが見やすくするようにしたい。一覧で見えないと予定の全体が掴みにくい。手書きをする場合は拡大した方が書きやすい。一覧の状態でも手書きは可能にしておく。ユーザーのそれぞれの使い方に合わせたい。ダブルタップで、週、月、年はその日に飛べるように。」

**根本原因（偵察の結果。§2.1 に file:line）**: **縮小方向について** は確定: 0.5.1 はページを開いた瞬間の倍率が `minimumZoomScale` そのもの（`InkCanvasView.swift:566-574`、`ZoomPolicy.minZoom` = 幅ぴったりか読める倍率）なので、縮小方向のピンチは `bouncesZoom`（既定 true、M4B-4）で必ず元に戻り、本人が求める「一覧（縮小）」は仕様上できない。加えて iPhone 既定の「指でも書く」＋投げなわ／予定ツールでは overlay（`InkOverlayView.swift:165-173, 185-196`）が 2 本目の指を握り、ピンチ自体が始まらない。**拡大方向** を止める経路はコードに無い（`containerDidLayout` の早期復帰 560-565、`applyPending` 439-512 は zoomScale を書かない）が、本人の「ピンチができません」は方向を言っていない。拡大まで効かなかったのなら F1（D1）では直らず、残る候補は 毎フレームの紙の全面描画（`PaperView.swift:230-241`、13 インチの月で 2 × 2 画面 ≈ 38〜77 MB の窓を毎フレーム確保 → 数 fps で「動かない」に見える = F3）と PencilKit 側の挙動（候補 5）。**本人に 1 分の確認（§9 M4C-21）を頼み、答えが来るまで F1 と F3 の両方を P の最初の版に入れる**。候補 5 は §2.3 のテストと §2.4 のログ・写真で CI が切り分ける。

**本人の決定・リードの決定（この契約で既定にしてあるもの。再検討しない。数字は根拠があれば直し、理由を書く）**:

- **D1 一覧（fitAll）が基本の状態**: どのページも初期倍率と **最小倍率** を `fitAll = min(viewW / overviewW, viewH / overviewH)` にする。一覧矩形は 月 = 6 行の格子（1400 × `memo.minY`。メモ欄はスクロールで）、週 = 24 時間の格子（1400 × 1920。終日帯は固定見出しのまま）、日 = 紙全体（1000 × 2400）、年 = 紙全体（1400 × 31 行の合計）。viewW / viewH = 実際に紙が見える領域（固定見出しと終日帯の下、ツールバーの上 = `InkCanvasContainerView.bounds`）。M4b の `readableZoom` は **文字の閾値（D3）として残す** が、倍率を縛らない。紙の幅 × 倍率 < viewW なら横に中央寄せ（`contentInset`）、高さも同様に縦に中央寄せ（**中央寄せの計算は常に紙全体 `layout.size`**。一覧矩形ではない。iPad の月は紙 1280 pt > 1180 なので縦には寄らず、メモ欄はスクロールで届く）。`maxZoom = max(4 × fitWidth, 2 × readableZoom)`（現行の `max(4 × fit, 2 × minZoom)` と同じ値）。初期スクロールは一覧（比率 1）なら左上（7:00 へのスクロール無し）、拡大中（比率 > 1）はページ切替で既存の `initialScrollY`（今 −1h ／ 7:00）と `initialScrollX` の規則。一覧矩形は手書き・予定で伸びる（月の行 175 → 1200、年の行 60 → 400）ので、**伸びたときも下限を計算し直し、一覧のままなら新しい一覧に追随する**（§1.3 の `applyBounds`）。紙の外（中央寄せの余白）は机の色で、そこに書いた線は捨てる（§1.3、M4C-25）。
- **D2 ピンチはどこでも効く**: §2.1 の縮小方向の原因 2 つ（F1・F2）を直し、性能の候補 F3 も最初の版に入れる。§2.3 の回帰テスト（0.5.1 の下限 = 幅ぴったりより下に行けること、プログラムの `zoomScale` 代入がレイアウト・更新を越えて残ること、ピンチの終端の経路（`scrollViewWillBeginZooming` → `DidEndZooming`）が clamp と比率の報告をすること）と §2.4 の CI の写真（`--screenshot-zoom` / `--screenshot-offset`、最初のレイアウト後に `scrollViewDidZoom` 以降の同期と終端の経路をピンチと共有する）で確かめる。ピンチ中（と跳ね返り中）は紙の窓を作り直さず引き伸ばす（§2.2 F3）。
- **D3 readableZoom 未満の文字は比例縮小、下限なし**（サムネイル。はみ出さない: バー・チップ・箱は lu の幾何のまま）。罫線は **画面上 1 pt のまま**（現行 `PaperText.hairline` = 1/zoom。リードの D3 は「1 device pixel」で、これは **変更提案** M4C-2。理由: 3x の iPhone で 0.33 pt は薄すぎる、M4b の写真と見た目が変わらない）。readableZoom 以上では M4b の `minPoints` の規則。M4b のクリップはそのまま。**この版の精密化**: readable 未満は「readable のときの lu を凍結して縮める」（`max(lu, minPoints / readable)`）。理由: 閾値で lu が切り替わると月のチップが 6.25 pt → 10 pt に跳ぶ（§3.1）。凍結なら readable の境目で連続で、一覧は「読める紙をそのまま縮めた絵」になる。
- **D4 倍率をページの種類ごとに覚える**（fitAll に対する比率、`UserDefaults` の `zoomRatio.<kind>`）。同じ種類の新しいページはその比率（clamp）で開く。既定 1（一覧）。ツールバーの小さな操作は **足さない**（ピンチだけ）。**回転・幅の変化の精密化（リードの「比率を保つ」からの変更提案 M4C-24）**: 一覧（比率 1）なら新しい一覧のまま、拡大中は **絶対倍率（手書きの大きさ）を保って** 新しい範囲に clamp する（0.5.1 の中央維持と同じ）。保存比率は **ピンチの終わりにだけ** 書き、回転では書き換えない（clamp で削られた分は Coordinator が目標倍率として持ち、戻したとき復元する）。理由: fitAll は日・週で高さに依存し縦横で 2.5 倍近く変わる（iPhone の日 0.2313 ↔ 0.0854）ので、比率を保つと回転のたびに手書きの大きさが変わり、さらに clamp で比率が書き換わると往復で元に戻らない（横 1.0 → 縦 clamp 1.608 = 比率 6.65 を保存 → 横に戻すと 0.568）。
- **D5 指のダブルタップ**: 週・月・年 → タップした日の日ページ（月 = マスの日、週 = 列の日（格子でも固定の終日帯でも）、年 = マスの日。メモ欄・ガター・存在しない日 = 何もしない）。単タップの挙動（バー・チップ・箱 → 編集、日付の数字 → 日ページ）はそのまま。UIKit の認識器で `tapRecognizer.require(toFail: doubleTap)`（約 0.3 秒の遅れを受け入れる）。キャンバスでは Pencil では起きない（`.direct` だけ）。**例外**: 固定の終日帯の列は SwiftUI の `TapGesture` でタッチ種別を選べないので Pencil のダブルタップでも飛ぶ（帯は書けない領域なので受け入れる。バーの `Button` が Pencil のタップで編集を開くのと同じ事情、`AllDayBandView.swift:108`）。日ページのダブルタップは何もしない（キャンバスも帯も）。投げなわ／予定ツールの間は無効。「指でも書く」オン（iPhone 既定）では PencilKit の `drawingGestureRecognizer` と同時認識にし、ダブルタップが描いた点は消す（§4.1、M4C-22）。
- **D6 固定見出しと終日帯は倍率と x に追随し続ける**（`PaperViewport.offsetX` が負になるだけ）。紙の窓はどの倍率でも動く。帯のレーン高だけはピンチ中は開始時の値で凍結し、終わりに更新する（§1.6、M4C-27）。
- **D7** `MARKETING_VERSION` **0.5.2**。この契約は `docs/M4C_CONTRACT.md`、実装結果は `docs/M4C.md`。DESIGN.md §2.2 に注記（C）。

**範囲外**（触らない）: 課金・閲覧専用（M5）、ガターの固定化（M4B-3）、倍率のツールバー操作、同期エンジン（`Sync/*`）、`InkPage`、レイアウトエンジンの幾何（`hit(at:)` は変えない。D5 は `dayAt(point:)` の **追加** で済ませる）、Web 版リポジトリ。

## 0. 構成とファイル所有

```
TegakiKit/                                              担当 K（TegakiKit だけを触る）
  Sources/Layout/ZoomPolicy.swift                       変更: overviewSize / fitAll / bounds(overview:viewport:) / 比率の補助 / 中央寄せの余白 / visibleWidth(_:viewportWidth:zoom:)（§1.1）。minZoom・fitTolerance・旧 bounds・旧 visibleWidth(_:viewportWidth:) は削除
  Sources/Layout/PageLayout.swift                       変更: 要件 dayAt(point:) と既定実装（§4.3）
  Sources/Layout/MonthPageLayout.swift                  変更: dayAt（§4.3）
  Sources/Layout/WeekLayoutEngine.swift                 変更: dayAt
  Sources/Layout/YearLayoutEngine.swift                 変更: dayAt
  Sources/Layout/DayLayoutEngine.swift                  変更: dayAt = nil（明示）
  Sources/Layout/AllDayBand.swift                       変更: AllDayBandLayout.day(atPaperX:)（§4.3）
  Sources/KitChecks/main.swift                          変更: zoom policy の節を書き換え、initial scroll x の 6 行（2966-2971）を 3 引数版に、double tap target の節を追加（§7.1）
  Tests/LayoutTests/ZoomPolicyTests.swift               変更（§7.1）
  Tests/LayoutTests/PageNavigationTests.swift           変更: 166-171 の 6 行を 3 引数版に（期待値は不変、§7.1）
  Tests/LayoutTests/{Month,Week,Year,Day}LayoutEngineTests.swift / AllDayBandTests.swift   変更: dayAt
Sources/TegakiCalendar/
  Ink/InkCanvasView.swift                               担当 P   変更: 一覧の倍率・中央寄せ・目標倍率の保持・ピンチ中の引き伸ばし・終端の経路・ダブルタップ・引数の口・NSLog・容器の背景色・余白の線の破棄（§1.3、§2.2、§2.4、§4.1）
  Ink/InkOverlayView.swift                              担当 P   変更: 指の入力を認識器へ（§2.2 F2）
  Paper/PaperView.swift                                 担当 P   変更: show(…, live:)（§2.2 F3）
  Paper/PaperText.swift                                 担当 P   変更: fontSize / gutterLabelSize の readable 引数（§3.1）
  Paper/MonthPaper.swift / WeekPaper.swift / DayPaper.swift / YearPaper.swift / TimeGridPaper.swift   担当 P   変更: readable を渡す（§3.2）
  Views/StickyHeaderView.swift                          担当 P   変更: width 0 の代替、狭い列で週の曜日の字を省く（§1.4）
  Views/CalendarRootScreen.swift                        担当 U   変更: 最初の viewport、比率の受け渡し、ダブルタップ、ピンチ中の帯の凍結、引数（§5.1）
  Views/AllDayBandView.swift                            担当 U   変更: 列のダブルタップ、laneZoom（§5.2）
  Support/ScreenshotMode.swift                          担当 U   変更: --screenshot-zoom / --screenshot-offset（§5.3）
  Persistence/AppSettings.swift                         担当 U   変更: zoomRatio（§1.5）
Tests/TegakiCalendarTests/InkCanvasViewTests.swift      担当 P   変更・追加（§2.3、§7.2）
Tests/TegakiCalendarTests/PaperTextTests.swift          担当 P   追加（§7.2）
Tests/TegakiCalendarTests/PaperViewTests.swift          担当 P   追加（§7.2）
Tests/TegakiCalendarTests/ScreenshotModeTests.swift     担当 U   追加（§7.3）
Tests/TegakiCalendarTests/AppSettingsTests.swift        担当 U   新規（§7.3）
Tests/TegakiCalendarTests/CalendarRootScreenTests.swift 担当 U   新規: paperAreaHeight（§7.3）
project.yml / .github/workflows/build.yml / docs/M4C.md / README.md / docs/DESIGN.md   担当 C（§6、§8）
```

依存の向き: `TegakiCalendar` → `TegakiKit`。P と U の接点は次の 6 つだけで、全部この契約の形に固定します。**共有する型と純関数は全部 K に置き、P 側の新しい引数には既定値を付ける**（M4b と同じ）。

1. `ZoomPolicy`（§1.1、K）: P はキャンバスで、U は最初の viewport と `initialScrollX` の見積りで、同じ関数を呼ぶ。
2. `PaperViewport.initial(_:overview:paperSize:viewport:ratio:)`（§1.1、K）: U が最初の 1 フレームに使う。`offsetX` は中央寄せで負になりうる。
3. `InkCanvasView` の新しい引数 6 つ（§1.3、P。全部既定値つき）: `initialZoomRatio`、`initialPaperOffset`、`doubleTapEnabled`、`onDoubleTap`、`onZoomRatioChange`、`onZoomingChange`。U は足して呼ぶ（足す前でもビルドできる）。
4. `PageLayout.dayAt(point:)` / `AllDayBandLayout.day(atPaperX:)`（§4.3、K）: U がダブルタップの点を日に解決する。
5. `AppSettings.zoomRatio(for:)` / `setZoomRatio(_:for:)`（§1.5、U）: U だけが読み書きする。P は `onZoomRatioChange` で値を渡すだけ。
6. `ScreenshotMode.Config.zoomRatio` / `.offset`（§5.3、U）: U が `InkCanvasView` の `initialZoomRatio` / `initialPaperOffset` に流す。P は `ScreenshotMode` を読まない。

**担当 P は `Views/CalendarRootScreen.swift`・`Views/AllDayBandView.swift`・`Support/*`・`Persistence/*` を触らない。担当 U は `Paper/*`・`Ink/*`・`Views/StickyHeaderView.swift` を触らない。担当 K は `TegakiKit/` だけ。担当 C は project.yml・build.yml・docs/M4C.md・README.md・DESIGN.md の注記だけ。**

## 1. 一覧（fitAll）と倍率の範囲

### 1.1 ZoomPolicy と PaperViewport（担当 K、`Layout/ZoomPolicy.swift`）

```swift
public enum ZoomPolicy {
    // 不変: keyColumnWidth / readableColumnPoints / readableZoom / paperWidth / fitZoom(_:viewportWidth:) / Bounds
    // 削除: fitTolerance、minZoom(_:viewportWidth:)、bounds(_:viewportWidth:)、visibleWidth(_:viewportWidth:)
    //       （呼び出し側は全部この里程で 3 引数版に書き換える: KitChecks 2819-2845・2880・2966-2971、
    //        PageNavigationTests 166-171、InkCanvasViewTests 38・112、CalendarRootScreen 308。§7.1、§2.3、§5.1）

    /// 一覧矩形（lu、D1）: 月 1400 × MonthPageLayout.memo.minY、週・日・年 layout.size
    public static func overviewSize(_ layout: any PageLayout) -> CGSize
    /// min(viewport.width / overview.width, viewport.height / overview.height)。
    /// viewport.height が有限でない・0 以下なら幅だけ（viewport.width / overview.width）。幅も不正なら readableZoom(kind)。overview が不正なら readableZoom(kind)
    public static func fitAll(_ kind: PageKind, overview: CGSize, viewport: CGSize) -> CGFloat
    /// max(4 × fitZoom(kind, viewportWidth:), 2 × readableZoom(kind))。幅が不正なら 4 × readableZoom
    public static func maxZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat
    /// fit = fitZoom(width)、min = fitAll、max = maxZoom。max < min になる組み合わせは無い（fitAll ≤ fit ≤ 4 fit）が、念のため max = Swift.max(max, min)
    public static func bounds(_ kind: PageKind, overview: CGSize, viewport: CGSize) -> Bounds
    /// 保存比率 → 倍率: bounds.clamped(ratio × bounds.min)。ratio が有限でない・0 以下なら bounds.min
    public static func zoom(forRatio ratio: CGFloat, bounds: Bounds) -> CGFloat
    /// 倍率 → 保存比率: zoom / bounds.min を sanitizedRatio で正規化（min ≤ 0 なら 1）
    public static func ratio(forZoom zoom: CGFloat, bounds: Bounds) -> CGFloat
    /// 保存値の正規化: 有限で 1 ≤ r ≤ maxStoredRatio 以外（NaN・負・1 未満・大きすぎ）は 1。1 ± 0.001 は 1
    public static func sanitizedRatio(_ ratio: CGFloat) -> CGFloat
    public static let maxStoredRatio: CGFloat = 64      // 最大の maxZoom / fitAll は iPhone 横の日ページ 3.50 / 0.085 ≈ 41（§1.2、帯 1 レーン込み）
    /// 紙が画面より小さいときの中央寄せの余白（pt）: ((viewport.width − paper.width × zoom) / 2, (viewport.height − paper.height × zoom) / 2)。負は 0、不正は 0。
    /// paper は常に紙全体 layout.size（一覧矩形ではない。K の検査も P の applyInsets も同じ引数）
    public static func centeringInsets(paper: CGSize, zoom: CGFloat, viewport: CGSize) -> CGSize   // width = 左右、height = 上下
    /// その倍率で画面に入る紙の幅（lu）= min(paperWidth, viewportWidth / zoom)。不正は 0
    public static func visibleWidth(_ kind: PageKind, viewportWidth: CGFloat, zoom: CGFloat) -> CGFloat
}

public struct PaperViewport: Equatable, Sendable {      // 不変（offsetX / zoom / width、x(ofPaper:)、width(ofPaper:)、.zero）
    /// 幅だけから決める最初の 1 フレーム用（高さがまだ無いとき）: offsetX 0、zoom = fitZoom(kind, viewportWidth)、width
    public static func initial(_ kind: PageKind, viewportWidth: CGFloat) -> PaperViewport        // 意味が minZoom → fitZoom に変わる
    /// 高さと一覧矩形がある最初の 1 フレーム用: zoom = zoom(forRatio: ratio, bounds: bounds(kind, overview:, viewport:))、
    /// offsetX = −centeringInsets(paper: paperSize, zoom: zoom, viewport: viewport).width（paperSize = 紙全体 layout.size。紙が画面より狭ければ負）、width = viewport.width
    public static func initial(_ kind: PageKind, overview: CGSize, paperSize: CGSize, viewport: CGSize, ratio: CGFloat) -> PaperViewport
}
```

`PaperViewport` に高さは足さない（M4B-28 維持）: fitAll は純関数で、画面（U）とキャンバス（P）が同じ入力（紙の領域の大きさ、`overviewSize`）から同じ値を出す。

### 1.2 数字（縦横。viewH は推定。実測は `container.bounds.height` で、§2.4 の NSLog が CI のログに残すので C が docs/M4C.md に実数を書く）

紙の領域の高さの推定（画面の高さ − 安全領域 − ヘッダー − 固定見出し約 48 − ツールバー約 70）: 13 インチ縦 ≈ 1180 / 横 ≈ 830、11 インチ 1020 / 640、mini 950 / 550、iPhone 17 580 / 230。**週・日は終日帯の分をさらに引く**: CI の見本（10/5 の週・10/7）は帯 1 レーン（KitChecks 929 行 `laneCount == 1`: キャンプ・締切・家族旅行は重ならない）= 3 + 18 + 4 = **25 pt**。一覧の倍率では帯の高さは固定（§1.6）。下の表の週・日はこの 25 pt を引いた高さ（13 インチ 1155、11 インチ 995、mini 925、iPhone 555、横は 805 / 615 / 525 / 205）。帯が無い週・日は 25 pt 分だけ大きい。一覧矩形の高さは見本（空の紙）の値: 月 1050（175 × 6。行は予定・手書きで伸び、`memo.minY` が正）、週 1920、日 2400、年 1860（60 × 31。行は 400 まで伸びる）。**CI の見本の年は 16 日の行が 4 レーン（16 + 72 + 8 = 96 lu）で合計 1896** なので写真の年は 1860 の値より約 2 % 小さい（表の括弧）。

| 機種（幅 × 紙の領域 pt） | 月 fitAll | 週 fitAll（帯 25 込み） | 日 fitAll（帯 25 込み） | 年 fitAll（列の幅） |
| --- | --- | --- | --- | --- |
| iPhone 17 縦（402 × 580 / 555） | **0.2871**（幅。紙全体 502 pt が入り上下 39 pt） | **0.2871**（幅。555/1920 = 0.2891 より小さい。紙 551 pt、上下 2 pt） | **0.2313**（高さ。紙 231 pt 幅、左右 85 pt） | **0.2871**（幅。32 pt） |
| iPhone 390 縦（390 × 580 / 555） | 0.2786 | 0.2786 | 0.2313（231 pt 幅、左右 79） | 0.2786（31 pt） |
| iPad mini 縦（744 × 950 / 925） | 0.5314（幅。いまと同じ） | 0.4818（高さ。幅 675、左右 35） | 0.3854（幅 385、左右 179） | 0.5108（幅 715、左右 14。57 pt） |
| 11 インチ縦（834 × 1020 / 995） | 0.5957（いまと同じ） | 0.5182（幅 725、左右 54） | 0.4146（幅 415、左右 210） | 0.5484（幅 768、左右 33。61 pt） |
| 13 インチ縦（1024 × 1180 / 1155） | 0.7314（いまと同じ） | 0.6016（幅 842、左右 91） | 0.4813（幅 481、左右 271） | 0.6344（幅 888、左右 68。71 pt。見本の年 1896 なら 0.6224、幅 871、70 pt） |
| 13 インチ横（1366 × 830 / 805） | 0.7905（高さ。幅 1107、左右 130） | 0.4193（幅 587、左右 390） | 0.3354（幅 335） | 0.4462（幅 625。50 pt） |
| 11 インチ横（1210 × 640 / 615） | 0.6095（幅 853） | 0.3203（幅 448） | 0.2563（幅 256） | 0.3441（38.5 pt） |
| mini 横（1133 × 550 / 525） | 0.5238（幅 733） | 0.2734（幅 383） | 0.2188（幅 219） | 0.2957（33 pt） |
| iPhone 横（874 × 230 / 205） | 0.2190（幅 307） | 0.1068（幅 149） | 0.0854（幅 85） | 0.1237（14 pt） |

月の一覧は全機種で幅ぴったりのまま（6 行 1050 lu は幅より先に高さに当たらない）。iPad の月は **いまと何も変わらない**。iPhone 横の一覧は地図（字 1.5 pt）で、ピンチで拡大して使う（M4C-7。iPhone 縦の月・週・年も 4〜7 pt で読めない: M4C-26）。

`maxZoom`（幅だけで決まる。帯に依らない）: 月・週 = iPhone 1.1486 / mini 2.1257 / 11 インチ 2.3829 / 13 インチ 2.9257、日 = 1.608 / 2.976 / 3.336 / 4.096、年 = 2.6786 / 2.6786 / 2.6786 / 2.9257。fitAll からの比（ピンチで広がる幅）: iPhone 月・週 4.0、日 7.0、年 9.3、13 インチ 月 4.0、週 4.9、日 8.5、年 4.6。

### 1.3 InkCanvasView の適用（担当 P）

```swift
struct InkCanvasView: UIViewRepresentable {
    // 既存の引数はそのまま（M4b の順。onViewportChange の後ろに 6 つ足す。全部既定値つき）
    var onViewportChange: (PaperViewport) -> Void = { _ in }
    /// fitAll に対する比率。最初のレイアウトで 1 回だけ適用（後から変わっても再適用しない）。D4 の保存値か --screenshot-zoom
    var initialZoomRatio: CGFloat = 1
    /// 最初の左上の紙座標（lu）。nil なら §1.3 の規則（一覧 = 左上、拡大中 = initialScrollX / Y）。--screenshot-offset の口
    var initialPaperOffset: CGPoint? = nil
    /// 週・月・年で true。false なら doubleTapRecognizer は無効（単タップに遅れが出ない）
    var doubleTapEnabled: Bool = false
    /// 指のダブルタップ（紙座標 lu）。U が layout.dayAt(point:) で日にする
    var onDoubleTap: (CGPoint) -> Void = { _ in }
    /// ピンチの終わり（跳ね返りの後）に 1 回: 新しい比率（zoom / fitAll）。回転・行の伸びでは呼ばない（D4）。
    /// 必ず次の main-actor ターンに配信する（notifyViewport の次ターン経路と同じ `Task { @MainActor }`）。受け手は AppSettings にだけ書く
    var onZoomRatioChange: (CGFloat) -> Void = { _ in }
    /// ピンチの開始（scrollViewWillBeginZooming）で true、終わり（跳ね返りの後の描き直しと同時）で false。U は true の間 帯のレーン高を凍結する（§1.6）。配信は次ターン
    var onZoomingChange: (Bool) -> Void = { _ in }
}
```

`Coordinator` に足す状態: `private var lastLayoutSize: CGSize = .zero`、`private var lastBounds: ZoomPolicy.Bounds?`（§1.3 の 2 の比較相手。`lastLayoutSize` と同じ扱い）、`private var targetZoom: CGFloat?`（利用者が最後に選んだ絶対倍率。ピンチの終わりと初回で更新。回転で clamp されても保持し、戻したとき復元）、`private var needsFinalRedraw = false`、`var liveOverride: Bool? = nil`（テスト用。nil なら実値）。`private var isLive: Bool { liveOverride ?? (canvas.isZooming || canvas.isZoomBouncing) }`。

`containerDidLayout()`（549-595）を次のとおりに:

1. `guard viewport.width > 0, viewport.height > 0`（既存）。`let overview = ZoomPolicy.overviewSize(appliedLayout)`、`let bounds = ZoomPolicy.bounds(appliedLayout.kind, overview: overview, viewport: viewport)`。
2. `hasInitialZoom` かつ `lastBounds` と fit / min / max の 3 つとも 0.0005 未満の差 → `applyInsets()`; `syncPaperFrame()`; return（M4b の早期復帰。幅も高さも同じならここで終わる。iPhone の月のように高さだけ変わって縦の余白が変わる場合は `applyInsets` が拾う）。
3. **初回**（`!hasInitialZoom`）: `canvas.minimumZoomScale = bounds.min; canvas.maximumZoomScale = bounds.max`、`let zoom = ZoomPolicy.zoom(forRatio: parent.initialZoomRatio, bounds: bounds)`、**`canvas.zoomScale = zoom`**（UIKit が `scrollViewDidZoom` を同期に呼ぶ = contentSize・余白・窓・見出しの同期をピンチと共有）、`targetZoom = zoom`、`applyInsets()`、`contentSize`（既存）。`contentOffset`: `initialPaperOffset` があれば `clampedOffset(offset × zoom)`; 無ければ比率 ≤ 1.0005 なら `(−inset.width, −inset.height)`（左上）、それ以外は `clampedOffset((initialScrollX × zoom, initialScrollY × zoom))`（既存の規則）。`hasInitialZoom = true`。**その直後に `scrollViewDidEndZooming(canvas, with: nil, atScale: zoom)` を自分で 1 回呼ぶ**（写真と初回も終端の経路（余白・clamp・比率の報告）を通る。ScreenshotMode 中の比率の報告は U が捨てる §1.5）。§2.4 の NSLog を 1 行。
4. **幅が変わった**（`viewport.width != lastLayoutSize.width`。回転・Split View）: `let atOverview = abs(oldZoom − oldMin) < 0.0005`。`isLive` なら min / max だけ更新して zoomScale に触らない。そうでなければ `newZoom = atOverview ? bounds.min : bounds.clamped(targetZoom ?? oldZoom)`（一覧は一覧のまま、拡大中は絶対倍率を保つ。D4）で中央維持（既存の式。offset の clamp は 6）して `zoomScale = newZoom`。`targetZoom` は **触らない**（戻したとき復元）。`onZoomRatioChange` は **呼ばない**。
5. **高さだけ変わった**（帯が伸び縮みした、§1.6）: `applyBounds()`（下）。
6. 共通の末尾: `lastLayoutSize = viewport`、`lastBounds = bounds`、`applyInsets()`、**`isLive` でなければ** `canvas.contentOffset = clampedOffset(canvas.contentOffset)`（ピンチ中は UIKit が支点で管理している offset を上書きしない。終端で `scrollViewDidEndZooming` が 1 回 clamp する）、`syncPaperFrame()`、初回なら `applyInitialSelectionIfPending()`。

`applyBounds(_ bounds: ZoomPolicy.Bounds)`（新規。5 と `applyPending` の両方から呼ぶ共通関数）: `let atOverview = abs(canvas.zoomScale − canvas.minimumZoomScale) < 0.0005` を **先に** 取り、`canvas.minimumZoomScale = bounds.min; canvas.maximumZoomScale = bounds.max`。`isLive` なら終わり（ピンチ中は min / max の更新だけ）。そうでなければ: `atOverview` なら `zoomScale = bounds.min`（**一覧のままなら新しい一覧に追随する**。D1。一覧の倍率は 0.79 以下で帯の高さが固定なので往復しない §1.6）＋ `targetZoom = bounds.min`; それ以外で zoomScale が範囲外なら `bounds.clamped` へ代入（範囲内なら触らない。`wasAtMin` の再適用は **しない**）。`lastBounds = bounds`。

`applyPending`（439-512）の `drawingWork && geometryChanged` の分岐（499-503）に足す: `PageScroll.scrollDelta` の前に `applyBounds(ZoomPolicy.bounds(newLayout.kind, overview: ZoomPolicy.overviewSize(newLayout), viewport: container.bounds.size))`（一覧矩形が手書き・予定で伸び縮みした: 13 インチ横の月は高さ拘束（830 / 1050）なので行が伸びるたびに fitAll が下がる。これが無いと横向きの iPad で一覧のまま書いていると 6 行目が画面から出ていき、min が古いので縮めて戻すこともできない）。`resetScroll` の分岐はそのまま（`hasInitialZoom = false → containerDidLayout()`）。

`applyInsets()`（新規）: `let inset = ZoomPolicy.centeringInsets(paper: appliedLayout.size, zoom: canvas.zoomScale, viewport: container.bounds.size)`（**紙全体**。一覧矩形ではない） → `canvas.contentInset = UIEdgeInsets(top: inset.height, left: inset.width, bottom: inset.height, right: inset.width)`（違うときだけ代入。`contentInsetAdjustmentBehavior = .never`（125 行）なので手で入れてよい）。`scrollViewDidZoom`（834-841）の `contentSize` の後にも呼ぶ（ピンチ中の毎フレーム）。`clampedOffset`（641-646）は `x ∈ [−inset.left, max(−inset.left, contentSize.width + inset.right − bounds.width)]`、y も同様に。`handleTap` / overlay の `paperPoint` は `contentOffset` を見ているので負の offset でもそのまま正しい（余白のタップは負の lu → `hit` / `dayAt` が nil）。

`syncPaperFrame`（600-614）: `let live = isLive` を先に取る。**live なら 603-605 の `paperView.zoomScale = zoom` は行わず** `show(visible:zoom:contentSize:live: true)` だけを呼ぶ（§2.2 F3。これを守らないと `PaperView.zoomScale` の didSet（`PaperView.swift:173-177`）が毎フレーム `setNeedsDisplay()` し、`draw(_:)` 263-264 が新しい zoomScale で描いた窓を transform でさらに s 倍する = 二重に拡大・位置ずれした紙がピンチ中ずっと見える）。live でなければ従来どおり zoomScale を入れてから `show(…, live: false)`。

`scrollViewWillBeginZooming(_:with:)`（新規）: `deliverNextTurn { parent.onZoomingChange(true) }`、DEBUG の NSLog `zoom: begin`。

`scrollViewDidZoom`（834-841）: `contentSize`、`applyInsets()`、`syncPaperFrame()`。末尾に `if needsFinalRedraw, !isLive { needsFinalRedraw = false; finishZoom() }`（跳ね返りが終わった最初のフレームで 1 回描き直す）。

`scrollViewDidEndZooming(_:with:atScale:)`（新規実装）: `applyInsets()`。clamp は `bouncesZoom` が面倒を見ない場合だけ: `if !canvas.isZoomBouncing, zoom < canvas.minimumZoomScale − 0.0005 || zoom > canvas.maximumZoomScale + 0.0005 { canvas.zoomScale = clamp }`（アニメーション無し。UIKit 自身の bounce と二重に走らせない。ピンチ中に min が上がった §1.6 の場合にだけ効く）。`targetZoom = canvas.zoomScale`。`canvas.isZoomBouncing` なら `needsFinalRedraw = true`（描き直しは `scrollViewDidZoom` が跳ね返りの後に 1 回）＋保険として 0.4 秒後の `Task { @MainActor }` で `needsFinalRedraw && !isLive` なら同じことをする（跳ね返りの後に `DidZoom` が来ない機種があっても窓が引き伸ばしのまま残らない）; そうでなければ即 `finishZoom()`。DEBUG の NSLog `zoom: end scale=%.4f min=%.4f max=%.4f`。

`finishZoom()`（新規）: `canvas.contentOffset = clampedOffset(canvas.contentOffset)`、`syncPaperFrame()`（live でないので zoomScale を入れて `show(live: false)` を 1 回）、`deliverNextTurn { parent.onZoomRatioChange(ZoomPolicy.ratio(forZoom: canvas.zoomScale, bounds: lastBounds ?? 今の bounds)); parent.onZoomingChange(false) }`。`bouncesZoom` は既定（true）のまま（下限 = fitAll で跳ね返る）。

`deliverNextTurn`（新規）: 常に `Task { @MainActor in block() }`（`deliver` 752-760 は `isUpdating` のときだけ次ターン。比率と isZooming の報告は UIKit のデリゲートから同期に来るので、SwiftUI の状態に触る U の受け手を守るため常に次ターン）。

**余白の手書き（M4C-25）**: `canvasViewDrawingDidChange`（801-818）で、`change.added` のうち **紙座標の外接矩形の中心が紙の外**（x < 0、x > size.width、y < 0、y > size.height）の線は台帳に入れず、`isApplyingDrawing` を立てて `canvasView.drawing` からも取り除く（undo に残さない）。理由: 中央寄せの余白にも PKCanvasView は書けるが、`inkCell(forCenter:)` は紙の外を端のマスに負の相対座標で保存する（`PageLayout.swift:121-123`、`YearLayoutEngine.swift:145-152`）ので、別の倍率・Web 版では紙の外に線が出る。線が消えるのを見て利用者は「余白は紙ではない」と分かる。

**容器の背景（M4C-25）**: `InkCanvasContainerView`（174 行）の `backgroundColor` を紙色から机の色 **#ecebe6**（固定。紙は常に明るい DESIGN §3.2 と同じ理由でダークモードでも同じ）にする。`PaperView` は自分の窓を紙色で塗る（`draw(_:)` 266-267）ので紙だけが紙色になり、中央寄せの余白・overscroll・ピンチ中の窓の外（M4C-20）は机の色。

`update(from:)`（342-430）: `initialZoomRatio` / `initialPaperOffset` は読まない（初回だけ）。`doubleTapEnabled` と tool の変化で `doubleTapRecognizer.isEnabled = parent.doubleTapEnabled && !parent.tool.isOverlayTool`（§4.1）。`resetScroll`（487-492）は既存どおり `hasInitialZoom = false → containerDidLayout()` で、新しいページの `initialZoomRatio` が効く。

### 1.4 固定見出し（担当 P、`Views/StickyHeaderView.swift`）

`PaperRow`（276-317）は不変（`x(ofPaper:)` が負の offsetX で右にずれるので中央寄せに自然に揃う）。`resolved`（308-311）の width 0 の代替は `PaperViewport.initial(kind, viewportWidth:)`（意味が fitZoom になる）のまま。U は常に width > 0 の viewport（§5.1 の最初の 1 フレーム）を渡すので、この代替は attach 直後の `(0, 1, 0)` だけに効く。列の幅 × 倍率が文字より狭いときは `.clipped()` で切れる（iPhone 横の一覧: 週 20 pt、年 14 pt。既知の制限）。

**週の見出しの狭い列**（`weekDayCell` 90-110）: iPhone 縦の一覧（0.2871）で列は 54.8 pt。「水 7」は約 50 pt で入るが、月初の「10/1」（18 pt 等幅 4 桁 ≈ 55 pt ＋ 余白）は約 75 pt で切れる。`number` が「M/1」の形（月初）で、かつ `viewport.width(ofPaper: PaperSpec.weekColumnWidth) < 75` のとき、その日だけ曜日の文字（`Text(weekdayNames…)`）を省く（他の 6 日は「水 7」のまま。曜日は紙に無いので一覧で失わない）。あわせて `HStack` に `.lineLimit(1)` と `.minimumScaleFactor(0.6)`。75 pt 以上では今のまま。写真: M4C-28。

### 1.5 比率の保存（担当 U、`Persistence/AppSettings.swift`）

```swift
enum AppSettings {
    /// "zoomRatio.month" / "zoomRatio.week" / "zoomRatio.day" / "zoomRatio.year"
    static func zoomRatioKey(_ kind: PageKind) -> String
    /// 保存された fitAll に対する比率。無ければ 1。ZoomPolicy.sanitizedRatio で正規化
    static func zoomRatio(for kind: PageKind) -> CGFloat
    /// 正規化して保存。1 なら removeObject
    static func setZoomRatio(_ ratio: CGFloat, for kind: PageKind)
}
```

ScreenshotMode 中は読まない書かない（`CalendarRootScreen` が `ScreenshotMode.isActive` で分ける。既存の `remember` 572-577 と同じ流儀）。書くのは `onZoomRatioChange` のときだけ（= ピンチの終わり。毎フレームは書かない。回転では来ない）。比率はページの **種類** ごと（10 月と 11 月は同じ比率）。

### 1.6 回転・幅・高さの変化

- 幅の変化（回転・Split View）: §1.3 の 4。一覧は一覧のまま（13 インチ縦の週 0.6016 → 横 0.4193）、拡大中は絶対倍率を保って新しい範囲に clamp（D4、M4C-24）。例: 13 インチ週 縦 1.20 → 横 1.20（max 3.9 の内）。iPhone 日 横 3.45（比率 41）→ 縦 max 1.608 に clamp、`targetZoom` 3.45 は保持 → 横に戻すと 3.45。保存比率は変わらない。
- 高さだけの変化: 終日帯の高さは `max(22 × zoom, 18)` なので zoom ≤ 0.818 では倍率に依らない。**全機種の fitAll は 0.80 以下**（§1.2）なので一覧状態では帯の高さが固定され、フィードバックは起きない。zoom > 0.818 に拡大すると帯が伸びて紙の領域が縮み、高さ依存の fitAll が下がる → §1.3 の 5（`applyBounds`: min / max の更新。一覧ではないので zoom は触らない）。一覧へ戻すピンチの途中で min が上がっても `isLive` の間は触らず、`scrollViewDidEndZooming` で 1 回 clamp する。不動点（帯が固定の一覧）が必ずあるので往復しない。
- **ピンチ中の帯の揺れ（M4C-27）**: 0.818 超でピンチ中は毎フレーム帯の高さ → 容器の高さ → `PKCanvasView.frame` が変わり、スクロールビューの frame がピンチの支点をずらして揺れうる（M4b では一覧 → 拡大の経路が無かったので目立たなかった）。P が `onZoomingChange`（§1.3）で開始・終了を知らせ、U は true の間 `AllDayBandView` の `laneZoom`（§5.2）に開始時の倍率を渡して **レーン高だけ凍結** する（列の x と幅は `viewport` で追随し続ける。D6）。終わりに実値へ更新。実機で揺れなければ U 側の凍結は外してよい（引数は残す）。
- 一覧（比率 1）のときの横位置は `initialScrollX` に依らず左上。`PageNavigation.initialScrollX`（113-126）/ `initialScrollY`（132-146）は **変えない**（関数は不変。呼び出し側の `visibleWidth` だけ 3 引数版に）。U が `visibleWidth` を `ZoomPolicy.visibleWidth(kind, viewportWidth:, zoom: 見積りの倍率)` で計算し（§5.1）、P が比率 > 1 のときだけ適用する。

## 2. ピンチの不具合

### 2.1 根本原因（file:line）と直し方

| # | 原因 | 根拠 | 直し方 |
| --- | --- | --- | --- |
| 1（確定・仕様由来・縮小方向） | 開いた瞬間の倍率 = `minimumZoomScale`。縮小ピンチは `bouncesZoom` で必ず戻る | `InkCanvasView.swift:566`（初回 `wasAtMin` 常に true）→ 573-574 `newZoom = bounds.min`。`ZoomPolicy.swift:60-65` minZoom = max(fit, readable)。`makeUIView` 111-148 は `bouncesZoom` を触らない（既定 true） | **F1** = D1。下限を fitAll に（§1.3） |
| 2（確定・状況限定） | 「指でも書く」オン（iPhone 既定）＋投げなわ／予定ツール: overlay が 2 本目の指を握る | `InkOverlayView.swift:165-173`（`.direct` で self を返す）、185-196（2 本目は `continue`）。M3B.md:122 に既知の制限 | **F2**（§2.2） |
| 3（性能。拡大方向まで効かなかったのならこれが本命） | ピンチ中は毎フレーム新しい窓（最大 2 × 2 画面 ≈ 13 インチ @2x で 77 MB）を確保して全面描画 | `PaperView.swift:230-241`（倍率が違えば必ず新窓 + `setNeedsDisplay`）。M2 から同じ | **F3**（§2.2）。最初の版に入れる（M4C-21） |
| 4（否定） | `containerDidLayout` / `applyPending` が ZoomPolicy を再適用する | 早期復帰 560-565 は幅不変で成立。`applyPending` 439-512 は zoomScale を書かない（`resetScroll` 487-492 はページ切替のみ）。`update(from:)` 342-430 は page / geometry / paper / tool が同じなら何も queue しない | D1 で bounds が高さ・行の伸びに依存すると新しい経路が生まれる（§1.3 の `applyBounds` と §1.6 で封じる） |
| 5（低い・未検証） | PencilKit が `viewForZooming` 無しで zoom しない（`pinchGestureRecognizer` が nil） | Apple の見本は min == max で **ロック**しており、PKCanvasView 自身が zoom することが前提。DESIGN §3.8 も同じ前提。実機では M2 から一度も確認されていない（M2.md §4.2、M4B.md:210） | §2.3 の記録と §2.4 の NSLog で確定。nil だったときの代替は別里程（M4C-23） |
| 6（否定） | `isDirectionalLockEnabled` 131、`alwaysBounceHorizontal` 127、`compositingFilter` 183、`UIPencilInteraction` 136、`tapRecognizer` 238-243（動いた時点で失敗）、SwiftUI の overlay 325-329・toast 214-224（中身が無ければ当たらない） | いずれもパン・描画だけに作用 | 無し |

### 2.2 直し（担当 P）

**F1**: §1.3。

**F2 投げなわ／予定ツールの指入力を認識器へ**（`Ink/InkOverlayView.swift`、`Ink/InkCanvasView.swift`）。hit-test で overlay が指を取ると UIKit はその touch を二度と scroll view に渡せないので、指は overlay に **当てず**（`hitTest` 165-173 を Pencil だけに: `candidates.contains(.pencil) → self`、指は常に nil）、container に付けた自前の認識器で受ける:

```swift
import UIKit.UIGestureRecognizerSubclass   // touchesBegan などの override に要る

/// 1 本の指（.direct）の入力を overlay に転送する UIGestureRecognizer の派生。状態の流儀は UILongPressGestureRecognizer と同じ:
/// 1 本指の間は .possible のまま（.possible でも touchesMoved は届く）で touches を overlay へ転送し、指が離れたら .ended（= 認識。
/// require(toFail:) で待っている pan / tap はここで失敗する）、2 本目が触れたら .failed（overlay に cancelFinger。UIKit は依存が解けるまで
/// pan に touches を溜めているので、同じ接触列で pan / pinch がそのまま進む）。Pencil の touch は無視（overlay の touches* が従来どおり受ける）。
/// 動かなくても .ended（予定ツールの isTap）
@MainActor final class InkFingerGestureRecognizer: UIGestureRecognizer { /* touchesBegan / Moved / Ended / Cancelled を override */ }

extension InkOverlayView {
    func beginFinger(at view: CGPoint)      // touchesBegan の指の分岐と同じ（Pencil が活動中なら無視）
    func moveFinger(to view: CGPoint, coalesced: [CGPoint])
    func endFinger(at view: CGPoint)
    func cancelFinger()                      // cancelGesture と同じ
}
```

配線（`makeUIView`）: `container.addGestureRecognizer(coordinator.fingerRecognizer)`（`allowedTouchTypes = [.direct]`、`delegate = coordinator`、`cancelsTouchesInView = false`）。`isEnabled = tool.isOverlayTool && allowFinger`（`update(from:)` の tool / allowFinger の分岐で更新。無効な認識器は即失敗する）。`canvas.panGestureRecognizer.require(toFail: fingerRecognizer)`（1 本指の間は自前が `.possible` で pan を待たせ、指が離れた `.ended` で pan が失敗、2 本目の `.failed` で pan / pinch が進む。**touch-down で即 `.began` にしてはいけない**: 自前が認識した時点で pan はその接触列で失敗し、2 本目で自前を cancel しても pan は復活しない）。`coordinator.tapRecognizer.require(toFail: fingerRecognizer)`（hit-test ビューが PKCanvasView になるので、同じ指のタップが `tapRecognizer`（238-243）→ `onTap` → `layout.hit` にも届く。自前が有効な間はタップを渡さず、0.5.1 で overlay が飲んでいた「投げなわで余白をタップ = 選択解除」「予定ツールの isTap」だけが動く。予定ツールでバーをタップして `openEdit` が 2 回、投げなわで選択解除と編集が同時、を防ぐ）。`pinchGestureRecognizer` には require を付けない。`gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` は自前については false（§4.1 の drawing との同時認識はタップの認識器だけ）。座標は `location(in: overlay)` で従来の `paperPoint(fromView:)`。`delegate.overlay(isTracking:)` の 300 ms 待ち（`InkCanvasView.swift:920-926`）はそのまま。XCTest では touch を作れないので **実機で確かめる**（§7.4: 1 本指で投げなわ、2 本指でスクロールとピンチ、チップを指でタップしても編集が開かない）。

**F3 ピンチ中は窓を引き伸ばす**（`Paper/PaperView.swift`）:

```swift
/// live: ピンチ中・跳ね返り中（Coordinator.isLive）。窓を作り直さず zoomScale にも触らず setNeedsDisplay もせず、windowZoom で描いた窓を
/// s = zoom / windowZoom 倍に引き伸ばす: bounds.size = contentWindow.size のまま、transform = scale(s)、
/// center = (contentWindow.midX × s − visible.minX, contentWindow.midY × s − visible.minY)。
/// ただし windowZoom > 0 && !contentWindow.isEmpty のときだけ（attach 直後の空の窓では s が非有限になる）。それ以外は live false の経路に落とす。
/// live false: transform = .identity に戻し → zoomScale を更新 → 従来の処理（倍率が windowZoom と違えば新しい窓を 1 回描く）の順
func show(visible: CGRect, zoom: CGFloat, contentSize: CGSize, live: Bool = false)
```

呼び出し側の約束は §1.3 の `syncPaperFrame`（live のとき `paperView.zoomScale` に触らない）。終端は `finishZoom()` が `live: false` を 1 回（跳ね返り中は跳ね返りの後）。ピンチ中に窓の外が見えたら容器の机の色（§1.3）が出る（終了時に描き直す。既知 M4C-20）。4 倍に引き伸ばした絵はぼける（ピンチ中だけ）。PencilKit の線は PKCanvasView 自身が追随する。

### 2.3 シミュレータで再現する回帰テスト（担当 P、`Tests/TegakiCalendarTests/InkCanvasViewTests.swift`、`@MainActor`）

既存の `makeView` / `Coordinator(parent:)` / `attach` / `layoutSubviews()` / `settle()`（57-102 の形）を使う。`makeView`（38 行）の `initialScrollX` は `ZoomPolicy.visibleWidth(layout.kind, viewportWidth: viewportWidth, zoom: ZoomPolicy.readableZoom(layout.kind))` で計算する（比率 1 の既定では `initialScrollX` は使われないので値は何でもよい。使うテストは自分で計算する）。`makeView` に `onZoomRatioChange: @escaping (CGFloat) -> Void = { _ in }` と `onZoomingChange` を足す。`makeWeek()` / `makeDay()` を `makeMonth()` と同じ形で足す。

```swift
/// 根本原因 1 の再現: 0.5.1 は幅ぴったり（0.7314）が下限で、縮小ピンチはそこで跳ね返った。高さ拘束のページで下限が幅ぴったりより下にあることと、
/// プログラムの zoomScale 代入（scrollViewDidZoom → contentSize / insets / syncPaperFrame / notifyViewport）がレイアウト・更新を越えて残ることを見る
func testOverviewGoesBelowFitWidthAndSurvivesLayoutPassesAndUpdates() async {
    let (layout, paper) = makeWeek(); let probe = Probe()                         // 1400 × 1920
    let view = makeView(layout: layout, paper: paper, viewportWidth: 1024, probe: probe)
    let coordinator = InkCanvasView.Coordinator(parent: view)
    let container = InkCanvasContainerView(paperView: PaperView(content: paper))
    coordinator.attach(container)
    container.frame = CGRect(x: 0, y: 0, width: 1024, height: 1180); container.layoutSubviews(); await settle()
    let canvas = container.canvasView
    let fitWidth = ZoomPolicy.fitZoom(.week, viewportWidth: 1024)                  // 0.7314 = 0.5.1 の minZoom
    let fitAll = ZoomPolicy.fitAll(.week, overview: ZoomPolicy.overviewSize(layout), viewport: CGSize(width: 1024, height: 1180))   // 0.6146
    XCTAssertLessThan(canvas.minimumZoomScale, fitWidth, "0.5.1 ではここで止まった: 下限が幅ぴったりより下")
    XCTAssertEqual(canvas.minimumZoomScale, fitAll, accuracy: 1e-6)
    XCTAssertEqual(canvas.zoomScale, fitAll, accuracy: 1e-6, "一覧で開く")
    XCTAssertEqual(canvas.contentInset.left, (1024 - 1400 * fitAll) / 2, accuracy: 0.01)   // 81.8
    XCTAssertEqual(canvas.contentOffset.x, -canvas.contentInset.left, accuracy: 0.01, "左上")
    XCTAssertLessThan(canvas.minimumZoomScale, canvas.maximumZoomScale)
    XCTAssertTrue(canvas.isScrollEnabled); XCTAssertEqual(canvas.drawingPolicy, .pencilOnly)
    if canvas.pinchGestureRecognizer == nil { NSLog("zoom: pinchGestureRecognizer is nil (候補 5, M4C-23)") }   // 記録だけ。hard assert にしない
    canvas.setZoomScale(fitWidth, animated: false)                                  // 0.5.1 の下限へ
    canvas.setZoomScale(fitAll, animated: false)                                    // 縮小ピンチの終点
    XCTAssertEqual(canvas.zoomScale, fitAll, accuracy: 1e-6, "幅ぴったりより下に行ける")
    let target = fitAll * 2                                                         // 1.2292
    canvas.setZoomScale(target, animated: false)
    XCTAssertEqual(canvas.zoomScale, target, accuracy: 1e-6)
    container.setNeedsLayout(); container.layoutSubviews()                           // ピンチ中に毎フレーム起きる親の layout pass
    container.frame.size.height -= 30; container.layoutSubviews()                   // 帯が伸びて高さだけ変わった（§1.3 の 5）
    XCTAssertEqual(canvas.minimumZoomScale, 1150.0 / 1920, accuracy: 1e-4, "min は新しい fitAll（0.599）")
    await settle(); coordinator.update(from: view)                                  // 次ターンの viewport 配信 → SwiftUI の updateUIView
    container.layoutSubviews()
    XCTAssertEqual(canvas.zoomScale, target, accuracy: 1e-6, "レイアウト・更新を経ても倍率が残る")
    XCTAssertEqual(container.paperView.zoomScale, target, accuracy: 1e-6)
    XCTAssertEqual(probe.last?.zoom ?? 0, target, accuracy: 1e-6)
    XCTAssertEqual(canvas.contentSize.width, 1400 * target, accuracy: 0.01)
    XCTAssertEqual(canvas.contentInset.left, 0, accuracy: 0.01, "紙が画面より広い: 余白なし")
    canvas.setZoomScale(fitAll * 0.5, animated: false)                              // 下限: 新しい fitAll で止まる
    XCTAssertEqual(canvas.zoomScale, canvas.minimumZoomScale, accuracy: 1e-6)
}
```

さらに（全部新規。名前は固定）:

- `testOverviewLeavesIPadMonthUnchanged`: 月 1024 × 1180 → min = zoom = 0.7314（幅ぴったり。0.5.1 と同じ値）、`contentInset == .zero`（紙 1280 pt > 1180 なので縦にも寄らない）、高さ −30 でも min / zoom 不変（月は幅拘束）。
- `testOverviewCentresANarrowPaper`: 日ページ 402 × 580: zoom 0.2417、`contentInset.left` 80 ± 1、`contentOffset.x` −80、`probe.last?.offsetX` −80、`paperView.frame.origin.x` 80。
- `testSyncPaperFrameDoesNotTouchZoomScaleWhileLive`（F3 の coordinator 経由。`isZooming` は XCTest で立たないので `coordinator.liveOverride = true`）: 日 402 × 580 で窓ができた後 `liveOverride = true` → `canvas.setZoomScale(2 × fitAll)`（`scrollViewDidZoom` → `syncPaperFrame` live）→ `paperView.zoomScale` は fitAll のまま、`displayRequestCount` 不変、`paperView.transform.a == 2 ± 1e-6` → `liveOverride = nil` → `coordinator.scrollViewDidEndZooming(canvas, with: nil, atScale: 2 × fitAll)` → `paperView.zoomScale == 2 × fitAll`、`transform == .identity`、`displayRequestCount` +1。
- `testEndOfPinchPathClampsAndReportsTheRatio`（§2.4 の「終端の経路」）: (a) 日 402 × 580、`ratios` を `onZoomRatioChange` で集める。`coordinator.scrollViewWillBeginZooming(canvas, with: nil)` → `canvas.setZoomScale(2 × fitAll)` → `coordinator.scrollViewDidEndZooming(canvas, with: nil, atScale: 2 × fitAll)` → `await settle()` → `ratios == [2 ± 1e-3]`（初回の自前呼び出しの 1 は `attach` 後の `settle` で先に流しておく）、`paperView.transform == .identity`、`contentInset == .zero`（紙 483 pt > 402）、`zooming` の配信が `[true, false]`。(b) min がピンチ中に上がった（§1.6）: 週 1024 × 1150（fitAll 0.599）で `scrollViewWillBeginZooming` → `setZoomScale(0.60)` → `liveOverride = true` → `container.frame.size.height = 1180; layoutSubviews()` → `canvas.minimumZoomScale == 0.6146 ± 1e-4`、`canvas.zoomScale == 0.60`（live 中は触らない）→ `liveOverride = nil` → `scrollViewDidEndZooming(…, atScale: 0.60)` → `zoomScale == 0.6146`（min に clamp）、`contentInset.left == 81.8 ± 0.1`、`ratios.last == 1`。
- `testRotationKeepsTheOverviewAndTheAbsoluteZoom`（D4、M4C-24）: (a) 月 402 × 700 の一覧（0.2871）→ 874 × 402 → zoom = 新しい fitAll 0.3829（一覧は一覧のまま）、`ratios` は増えない。(b) 日 402 × 580 を `scrollViewWillBeginZooming` / `setZoomScale(1.0)` / `DidEndZooming` で 1.0 に（比率 4.14 が 1 回届く）→ 874 × 230（fitAll 0.0854、max 3.496）→ zoom 1.0 のまま、`ratios` 増えない → 402 × 580 に戻す → 1.0。(c) clamp と復元: 日 874 × 230 で 3.45（比率 40）→ 402 × 580（max 1.608）→ zoom 1.608、`ratios` 増えない → 874 × 230 に戻す → 3.45（`targetZoom` が復元）。
- `testHeightOnlyChangeNeverReappliesTheMinimumWhileZoomedIn`: 週 1024 × 1180 で比率 2（1.229）→ 高さ 1150 → zoom 不変、min 0.599。
- `testHeightChangeAtTheOverviewFollowsTheNewFitAll`: 週 1024 × 1180 の一覧（0.6146）→ 高さ 1150 → zoom = min = 0.599（一覧に追随）、`ratios` 増えない。
- `testMonthRowGrowthLowersTheOverviewZoomInLandscape`（`applyPending` の `applyBounds`）: 月 1366 × 830 の一覧（830 / 1050 = 0.7905）→ `inkBottoms` で 1 行を 400 lu にした layout で `coordinator.update(from: view2)`; `await settle()` → `memo.minY` 1275、`canvas.minimumZoomScale == 830 / 1275 = 0.651 ± 1e-4`、`zoomScale == 0.651`（一覧なので追随）、`probe.last?.zoom == 0.651`。同じ手順を比率 2（1.581）から始めると zoom は不変で min だけ 0.651。
- `testInitialZoomRatioAndPaperOffset`: `initialZoomRatio: 2, initialPaperOffset: (400, 200)` → zoom 2 × fitAll、offset (400 × zoom, 200 × zoom)、見出しの viewport も同じ、`ratios == [2]`（初回の自前の終端呼び出し）。`initialZoomRatio: 3` を 1024 × 1180 の月に → clamp で 2.9257。
- `testDoubleTapRecognizerSetup`: `numberOfTapsRequired == 2`、`allowedTouchTypes == [.direct]`、`doubleTapEnabled: false` → `isEnabled == false`、`tool: .lasso` → false。`fingerRecognizer.isEnabled`: `.lasso` かつ `allowFinger: true` → true、`.pen` → false、`.lasso` かつ `allowFinger: false` → false（`require(toFail:)` は公開 API で読めないので §7.4）。
- `testTapRecognizersAllowSimultaneousDrawing`（§4.1）: `coordinator.gestureRecognizer(tapRecognizer, shouldRecognizeSimultaneouslyWith: canvas.drawingGestureRecognizer) == true`、`doubleTapRecognizer` も true、`canvas.panGestureRecognizer` とは false、`fingerRecognizer` と drawing は false。
- `testDotsDrawnByTheDoubleTapAreFound`（§4.1 の純関数）: 台帳に 0.1 秒前の 2 lu の点 2 つと 10 秒前の点と 200 lu の線を入れ、`coordinator.dotStrokeIds(near: p, zoom: 0.5, within: 0.5)` が最初の 2 つだけを返す。

既存の書き換え: `testViewportIsDeliveredOnTheNextTurnNotInsideTheLayoutPass` は zoom 0.5 → fitAll（402 × 700 の月 = 0.2871）、contentSize 700 → 402、回転後 874 / 1400 → 0.3829（比率 1、offsetX −169）に。`testInitialScrollXPutsTodaysColumnOnScreen`（105-118）は比率 2 に: 112 行を `ZoomPolicy.visibleWidth(.month, viewportWidth: 402, zoom: 2 × ZoomPolicy.fitAll(.month, overview:, viewport: 402 × 580))`（= 700 lu）、`initialX == 700`（日曜 → 1400 − 700）、画面上 402 pt。

### 2.4 CI の写真での代理確認（U: 引数 / P: 適用 / C: build.yml）

- 引数: `--screenshot-zoom <fitAll に対する比>`（`Config.zoomRatio: CGFloat = 1`。有限で正でなければ 1）、`--screenshot-offset <x>,<y>`（紙の lu。`Config.offset: CGPoint? = nil`。2 つの有限な数でなければ nil）。`parse`（`ScreenshotMode.swift:44-64`）に 2 本足す。
- 適用: U が `InkCanvasView(initialZoomRatio: ScreenshotMode.current?.zoomRatio ?? AppSettings.zoomRatio(for: kind), initialPaperOffset: ScreenshotMode.current?.offset)`。P の §1.3 の 3（`canvas.zoomScale = zoom` → `scrollViewDidZoom` が同期に走り、直後に `scrollViewDidEndZooming` を自前で 1 回）。**写真が共有するのは `scrollViewDidZoom` 以降の同期（contentSize・余白・窓・見出し）と終端の経路（余白・clamp・比率）**。ピンチそのもの（`isZooming` 中の引き伸ばし、`scrollViewWillBeginZooming`）は写真に写らない: §2.3 の `testSyncPaperFrameDoesNotTouchZoomScaleWhileLive` と `testEndOfPinchPathClampsAndReportsTheRatio` が受け持つ。
- NSLog（`print` ではなく。`log show --predicate process == "TegakiCalendar"`（build.yml 257-259 / 358）に残る）: 初回レイアウトの末尾に `#if DEBUG` で 1 行 `NSLog("zoom: kind=%@ pinch=%d enabled=%d min=%.4f max=%.4f zoom=%.4f fitAll=%.4f ratio=%.3f view=%.0fx%.0f overview=%.0fx%.0f", …)`。候補 5 の判定と §1.2 の実数の出所。加えて `scrollViewWillBeginZooming` に `zoom: begin`、`scrollViewDidEndZooming` に `zoom: end scale=…`（DEBUG。TestFlight の次の版で本人の実機のログを見るときの到達確認。M4C-21）。
- 写真（§6。倍率は §1.2 の推定。**実数は `app-log.txt` の `zoom:` 行から C が M4C.md に写す**）: `ipad13-portrait-month-zoom2.png`（`--screenshot-zoom 2 --screenshot-offset 400,200`。倍率 1.4628、x 585 / y 293 pt → lu 400…1100 × 200…1007。月の列幅 200・月曜 = col 0 なので **水・木・金・土（土は半分）**、行は 10/5 週の下半分・10/12・10/19・10/26・11/2 週の上。見出しは 水〜土）、`ipad13-portrait-week-zoom2.png`（`2`、`300,700`。倍率 ≈ 1.20（帯 25 込みの fitAll 0.6016 × 2）> 0.818 なので帯のレーンが ≈ 26.5 pt に伸びる = §1.6 の経路。x 300…1151 lu → **火（途中）〜土（途中）**、8:45〜）、`ipad13-portrait-year-zoom2.png`（`2`、`1000,300`。見本の年 1896 lu で倍率 ≈ 1.245、内容 ≈ 1743 pt 幅なので x は ≈ 719 pt = 578 lu に clamp され **5 月（504…616）の右端〜12 月**。clamp を見る写真）、`iphone-portrait-week-zoom3.png`（`3`、`300,700`。倍率 0.8613（iPhone の週は帯込みでも幅拘束 0.2871）≥ readable で字は 10 pt 以上、x 258 / y 603 pt → 火〜木の 8:45 から。帯のレーン 18.9 pt）。
- 確認項目: 固定見出し（PaperRow）と帯の列線が紙の列線と 1 pt 以内で揃う、文字が readable 以上で `minPoints`、窓の端に机の色が出ない、一覧の写真（既存の 16 枚）で紙全体が入り机の色の余白で中央に寄っている、罫線は 1 pt（M4C-2）。

## 3. 文字の縮小（担当 P）

### 3.1 PaperText（`Paper/PaperText.swift`）

```swift
enum PaperText {
    /// zoom ≥ readable: max(lu, minPoints / zoom)（M4b）。zoom < readable: max(lu, minPoints / readable)（readable のときの lu を凍結。画面上は比例して縮む。下限なし）。
    /// readable 0（既定）は旧式そのもの（既存テストが通る）
    static func fontSize(_ size: Size, zoom: CGFloat, readable: CGFloat = 0) -> CGFloat
    static func gutterLabelSize(_ size: Size, zoom: CGFloat, gutter: CGFloat, readable: CGFloat = 0) -> CGFloat   // 同じ凍結の後に (gutter − 8) / 2.9 の上限
    static func hairline(_ zoom: CGFloat) -> CGFloat     // 不変: 画面上 1 pt（M4C-2。リードの D3「1 device pixel」からの変更提案）
}
```

凍結の値（lu）: monthDate 24、monthChip 20、monthHoliday 18、memoLabel 月 21 / 日 18.7、weekEvent 21.2、weekTimeLabel 19.31（上限）、dayEvent 19.6、dayTimeLabel 18.7、yearDayNum 22、yearWeekday 15、yearChip 13、yearHoliday 11（年は readable 1.339 で `minPoints` が届かないので lu のまま）。どれも readable で M4b の検算（M4B_CONTRACT §4.3）を通った寸法なので、縮めてもはみ出さない。

### 3.2 紙の呼び出し（`MonthPaper` 84・93-96・136・167、`TimeGridPaper` 42・59、`DayPaper` 60、`YearPaper` 73・88-93・121）

`fontSize(…, zoom: zoom, readable: ZoomPolicy.readableZoom(.month / .week / .day / .year))`。`drawBoxes(…, textSize:…)` に `readable: CGFloat` を足す。pt 固定の余白・線はそのまま: `padY = max(3, 1/zoom)` / `padX`（59-64）、compact の閾値 `4 / zoom`（102）、現在線 2 pt（132-143）、点 `max(5|6, 4/zoom)`、年の今日の枠 `1.5 / zoom`（68）、`linkWidth = max(2/zoom, 4)`（122）、`guard frame.height >= size × 0.8`（136）。バー・チップ・箱の枠は layout の lu なので幾何は不変（D3）。`AllDayBandMetrics` は紙の外なので pt の下限のまま（D6）。

### 3.3 fitAll での寸法（画面上の pt。縦。§1.2 の倍率で。週・日は帯 1 レーン込み）

| 寸法（lu / minPoints） | iPhone | iPad mini | 11 インチ | 13 インチ | 13 インチ横 |
| --- | --- | --- | --- | --- | --- |
| monthDate 17 / 12 | 6.9 | 12 | 12 | 12.4 | 13.4 |
| monthChip 12.5 / 10 | 5.7 | 10 | 10 | 10 | 10 |
| weekEvent 13 / 10 | 6.1 | 10 | 10 | 10 | 8.9 |
| weekTimeLabel 12 / 10（上限 19.31） | 5.5 | 9.3 | 10 | 10 | 8.1 |
| dayEvent 14 / 11 | 4.5 | 7.6 | 8.1 | 9.4 | 6.6 |
| dayTimeLabel 13 / 10.5 | 4.3 | 7.2 | 7.8 | 9.0 | 6.3 |
| yearDayNum 22 / 11 | 6.3 | 11.2 | 12.1 | 14.0（見本の年 13.7） | 9.8 |
| yearWeekday 15 / 9 | 4.3 | 7.7 | 8.2 | 9.5 | 6.7 |
| yearChip 13 / 8 | 3.7 | 6.6 | 7.1 | 8.2（見本の年 8.1） | 5.8 |
| yearHoliday 11 / 7.5 | 3.2 | 5.6 | 6.0 | 7.0 | 4.9 |

iPad の月と週（mini・11・13 インチ縦）は fitAll ≥ readable なので **いまと同じ**。iPhone の一覧は字が 4〜7 pt の地図（ピンチで読む。M4C-26）。13 インチの年の一覧（チップ 8.1 pt）は読める。

## 4. ダブルタップでその日へ

### 4.1 認識器（担当 P、`Ink/InkCanvasView.swift`）

```swift
private(set) lazy var doubleTapRecognizer: UITapGestureRecognizer = {
    let r = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    r.numberOfTapsRequired = 2
    r.numberOfTouchesRequired = 1
    r.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    r.delegate = self
    return r
}()
// makeUIView（137 行の直後）
canvas.addGestureRecognizer(coordinator.doubleTapRecognizer)
coordinator.tapRecognizer.require(toFail: coordinator.doubleTapRecognizer)
coordinator.doubleTapRecognizer.isEnabled = doubleTapEnabled && !tool.isOverlayTool
// handleTap（764-770）と同じ座標変換
@objc private func handleDoubleTap(_ r: UITapGestureRecognizer) {
    guard r.state == .ended, let canvas else { return }
    let p = r.location(in: canvas); let z = max(canvas.zoomScale, 0.0001)
    let paperPoint = CGPoint(x: p.x / z, y: p.y / z)
    if parent.allowFinger { removeDots(near: paperPoint, zoom: z) }     // M4C-22
    parent.onDoubleTap(paperPoint)
}
// gestureRecognizer(_:shouldReceive:)（772-775）を 2 本に: tapRecognizer と doubleTapRecognizer は .direct だけ
// gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:): tapRecognizer / doubleTapRecognizer と canvas.drawingGestureRecognizer の組は true。他は false
/// 直前 within 秒に台帳へ入った線のうち、紙座標の外接矩形が 画面上 16 pt（16 / zoom lu）に収まり中心が near から 24 / zoom lu 以内のもの（指のタップが描いた点）
func dotStrokeIds(near: CGPoint, zoom: CGFloat, within: TimeInterval = 0.5) -> [String]
/// dotStrokeIds を .removeStrokes で 1 op として消す（undo 可）。空なら何もしない
private func removeDots(near: CGPoint, zoom: CGFloat)
```

- PencilKit との関係: `.direct` 限定なので Pencil の線・タップには一切触れない。**「指でも書く」オン（iPhone 既定、`CalendarRootScreen.swift:442`。`drawingPolicy = .anyInput`）では PKCanvasView の `drawingGestureRecognizer` が指の touch-down で即 `.began` になる**ので、UIKit の既定の排他のままでは `.possible` の単タップ・ダブルタップが認識に移れず一度も発火しない可能性が高い（M3b から未確認）。そこで `shouldRecognizeSimultaneouslyWith` で drawing との組だけ true にする（点が描かれてもタップは認識される）。ダブルタップで日ページへ飛ぶ前に、その 2 点を台帳から 1 op で消す（M4C-22）。単タップの点（M3b からの既知）は触らない。2 本指は `numberOfTouchesRequired = 1` で失敗 → pan / pinch へ。
- 単タップの遅れ: `require(toFail:)` でバー → 編集、日付 → 日ページが約 0.3 秒遅れる（リード了承）。日ページ（`doubleTapEnabled: false`）と投げなわ／予定ツール（無効）では認識器が即失敗するので遅れない。
- 「指でも書く」オンで点が本当に描かれるか、消えるかは実機で見る（§7.4）。

### 4.2 固定の終日帯（担当 U、`Views/AllDayBandView.swift`、§5.2）と固定見出し

帯の列（79-91）: `.onTapGesture { onColumnTap(day) }` を `.gesture(TapGesture(count: 2).onEnded { onColumnDoubleTap(day) }.exclusively(before: TapGesture(count: 1).onEnded { onColumnTap(day) }))` に置き換える（`highPriorityGesture` ＋ `onTapGesture` の重ねは SwiftUI の版で単タップが先に発火する報告があり、CI では確かめられない）。**日ページの帯（`band.kind == .day`）は今のまま `.onTapGesture`**（ダブルタップは何もしない D5。同じ日ページを `show` し直す `saveNow` / `relayout` も、単タップの 0.3 秒の遅れも、日ページでは出ない）。SwiftUI の `TapGesture` はタッチ種別を選べないので帯の列は Pencil のダブルタップでも飛ぶ（D5 の例外）。バーは `Button` のまま（単タップで編集。ダブルタップは要らない）。固定見出しの週の日付は `Button` → 既に日ページ（93-124）、年の月名 → 月ページ。変えない。

### 4.3 当たり判定 API（担当 K、全部 lu の純関数）

```swift
public protocol PageLayout {   // 要件に足す（any PageLayout 経由で動的に呼べるように。extension の既定実装は nil）
    /// 指のダブルタップの飛び先。nil = 何もしない
    func dayAt(point: CGPoint) -> DayKey?
}
// MonthPageLayout: cell(at: point)?.day（127-138。6 行の格子の中なら月外の日 9/28 も返す。メモ欄 → .memo.day = nil、外・非有限 → nil）
// WeekPageLayout: point.y が 0 ≤ y < 1920 かつ column(atX:)（73-76。ガター x < 64 / x > 1400 は nil、x == 1400 は 6）→ days[col]
// YearPageLayout: cell(at:)（135-141。ガター x < 56 は nil）?.yearMonthDay → DayKey(year: year, month:, day:)、isValid（DayKey.swift:65）でなければ nil（2/30、平年の 2/29）
// DayPageLayout: nil（明示）
extension AllDayBandLayout {
    /// 帯の列 x（lu）→ その日。x < columnMinX[0]（ガター）・x > paperWidth → nil。i = min(days.count − 1, floor((x − columnMinX[0]) / columnWidth))。日ページは [72] 1 列
    public func day(atPaperX x: CGFloat) -> DayKey?
}
```

除外（nil）: 月のメモ欄、週・日の時刻ガター、年の日番号ガター、存在しない日、紙の外（中央寄せの余白 = 負の lu）、非有限。

## 5. 画面（担当 U）

### 5.1 CalendarRootScreen

- `@State private var paperArea: CGSize = .zero`（帯を除いた紙の領域。`GeometryReader { area in … }`（196-210）の `.onAppear` / `.onChange(of: area.size)` で `area.size.height − 帯の visibleHeight` を書く。帯の高さは `AllDayBandMetrics.metrics(kind:laneCount:zoom: 1 × fitAll（幅だけの見積りで可。≤ 0.818 なら固定）, pageHeight:)`）。
- 最初の 1 フレーム（168 行の `shownViewport`）: `viewport.width == 0` なら `PaperViewport.initial(kind, overview: ZoomPolicy.overviewSize(layout), paperSize: layout.size, viewport: CGSize(width: proxy.size.width, height: paperArea.height), ratio: currentRatio)`。`paperArea.height` が 0（本当の最初のフレーム）なら K の `initial` が幅だけで決める。キャンバスの実値は次のターンに届く（M4b が受け入れた 1 フレームの遅れ）。
- `currentRatio = ScreenshotMode.current?.zoomRatio ?? AppSettings.zoomRatio(for: kind)`。`canvas(…)`（297-330）に `initialZoomRatio: currentRatio`、`initialPaperOffset: ScreenshotMode.current?.offset`、`doubleTapEnabled: kind != .day`、`onDoubleTap: handleDoubleTap`、`onZoomRatioChange: { ratio in guard !ScreenshotMode.isActive else { return }; AppSettings.setZoomRatio(ratio, for: kind) }`、`onZoomingChange: { zooming in frozenLaneZoom = zooming ? shownViewport.zoom : nil }`（`@State private var frozenLaneZoom: CGFloat?`。§1.6）。
- `initialScrollX`（305-309）: `visibleWidth: ZoomPolicy.visibleWidth(kind, viewportWidth: proxy.size.width, zoom: ZoomPolicy.zoom(forRatio: currentRatio, bounds: ZoomPolicy.bounds(kind, overview:, viewport: CGSize(width: proxy.size.width, height: paperArea.height))))`。見積りと実値は帯の高さの分だけずれうる（今日の列が少し余分に見えるだけ）。
- `handleDoubleTap(at point: CGPoint)`: `guard kind != .day, let day = layout.dayAt(point: point) else { return }; show(kind: .day, focus: day)`。
- 帯: `AllDayBandView(…, laneZoom: frozenLaneZoom, onColumnDoubleTap: { day in guard kind != .day else { return }; show(kind: .day, focus: day) })`。
- `show(kind:focus:)`（527-560）: 既存どおり `viewport = .zero`、`frozenLaneZoom = nil`。同じ種類のページは `AppSettings.zoomRatio(for:)` が同じなので同じ比率で開く（D4）。
- 新規の純関数（テスト用）: `static func paperAreaHeight(area: CGFloat, band: AllDayBandLayout?, kind: PageKind) -> CGFloat`。

### 5.2 AllDayBandView

`var onColumnDoubleTap: (DayKey) -> Void = { _ in }` を足す（`onColumnTap` の直後。既定値つき）。`var laneZoom: CGFloat? = nil` を足す: `AllDayBandMetrics.metrics(kind:laneCount:zoom:pageHeight:)` に渡す倍率を `laneZoom ?? viewport.zoom` にする（レーン高・gap・字だけ。列の x と幅は `viewport` のまま）。§4.2。アクセシビリティの文言は変えない。

### 5.3 ScreenshotMode

```swift
struct Config: Equatable, Sendable {
    …                               // 既存の 6 つ
    var zoomRatio: CGFloat = 1      // --screenshot-zoom。有限で > 0 以外は 1。clamp は P（maxZoom を超える比は maxZoom）
    var offset: CGPoint? = nil      // --screenshot-offset "x,y"（lu）。解析できなければ nil
}
```

`parse`: `"--screenshot-zoom"` の次の引数を `Double` に、`"--screenshot-offset"` の次を `,` で 2 つに割って `Double` に。不正値は無視（既存の流儀）。シート（`--screenshot-sheet`）と併用したときも値は残す（月ページで効く）。先頭の注記（5-18 行）に 2 行足す。

## 6. CI（担当 C、`.github/workflows/build.yml`）

- KitChecks の閾値（53-61）: K が docs/M4C.md に実数 N を書いてから **N − 50**（暫定 21890。§7.1 の見込み 21940）。
- 13 インチの 4 ページのステップ（211-227）の `for` の後に 3 枚: `ipad13-portrait-month-zoom2.png`、`ipad13-portrait-week-zoom2.png`、`ipad13-portrait-year-zoom2.png`（§2.4 の引数。各 ≈ 10 秒）。
- iPhone の `shoot`（331-339）に 2 枚: `shoot "iphone-portrait-week-zoom3.png" --screenshot-month 2026-10 --screenshot-page week --screenshot-zoom 3 --screenshot-offset 300,700`（≈ 11 秒）、`shoot "iphone-portrait-week-jun.png" --screenshot-month 2026-06 --screenshot-page week`（M4C-28。見本の焦点は 7 日で 2026-06-07 は日曜なので 6/1〜6/7 の週になり、見出しの先頭が「6/1」）。
- ログのステップ（249-262、358）の末尾に `grep 'zoom: ' shots/app-log.txt || true`（C が M4C.md の §1.2 の実数に写す）。
- 追加時間 ≈ 55 秒。成果物は 13 インチ 13 枚 + `ipadmini` / `ipad11` 各 4 枚 + `iphone` 縦 7 枚 + `iphone-landscape` 4 枚 + ログ 4 本。
- project.yml:20 `MARKETING_VERSION: "0.5.2"`。README の「いま出来ていること」「手書き」（45 行）に一覧とピンチ、DESIGN.md:130（§2.2）と 394（§3.8）の「最小 = 幅ぴったり」を「最小 = 一覧（fitAll）、最大 = max(4 × 幅ぴったり, 2 × 読める倍率)」に。DESIGN §3.4 に「紙の外（中央寄せの余白）に書いた線は保存しない」を 1 行（M4C-25）。M4B.md:113-114 の確認表の 2 行（「minZoom より小さくならない」）は M4C.md で上書きする旨を 1 行。

## 7. 検査

### 7.1 TegakiKit（担当 K）: KitChecks の節と件数

| 節 | 内容 | 件数 |
| --- | --- | --- |
| `zoom policy (M4b)` → `zoom policy (M4c)`（2768-2910 を書き換え） | `readableZoom` / `keyColumnWidth` / `readableColumnPoints` / `paperWidth` / `fitZoom`（不変 17 件）、`overviewSize`（空の 10 月 = 1400 × 1050、週 1400 × 1920、日 1000 × 2400、空の年 1400 × 1860、busy な月は memo.minY、見本の年（10 月に見本の予定）は 1896）、`fitAll` を §1.2 の 9 行 × 4 ページ（viewport は表の値。週・日は帯込みの高さ。1e-3）＋高さ 0 / NaN → 幅だけ、幅も不正 → readable、`maxZoom` 4 機種 × 4 ページ、`bounds` の max ≥ min、`zoom(forRatio:)`（1 → min、2 → 2 min、100 → max、NaN / 0 / −1 → min）、`ratio(forZoom:)`（min → 1、max → max/min、min 未満 → 1）、`sanitizedRatio`（NaN / 0 / 0.5 / 1.0005 → 1、2 → 2、65 → 1、∞ → 1）、`centeringInsets`（**paper は紙全体**: 日 1000 × 2400 / 402 × 580 / 0.2417 → (80.1, 0)、月 1400 × 1750 / 1024 × 1180 / 0.7314 → (0, 0)、月 / 402 × 580 / 0.2871 → (0, 38.8)、週 1400 × 1920 / 1024 × 1180 / 0.6146 → (81.8, 0)、不正 → 0）、`visibleWidth(kind, viewportWidth:zoom:)`（402 / 0.5742 → 700、1024 / 0.7314 → 1400 で止まる、不正 → 0）、`PaperViewport.initial(_:viewportWidth:)` = fitZoom、`initial(_:overview:paperSize:viewport:ratio:)`（日 402 × 580 比率 1 → (−80.1, 0.2417, 402)、月 1024 × 1180 比率 2 → (0, 1.4628, 1024)、高さ 0 → 幅だけ） | 約 −80 + 150 |
| `double tap target (M4c)` 新 | 月: 10/7 のマスの中 → 10/7、9/28（月外）→ 9/28、メモ欄 → nil、x 1400 → 最後の列、外・NaN → nil。週: (64 + 2.5 colW, 100) → 10/7、ガター (10, 100) → nil、y 1920 → nil、x 1400 → 日曜。年: (56 + 9 × 112 + 10, 10 月 7 日の行) → 10/7、2 月 30 日の行 → nil、2025 の 2/29 → nil、ガター → nil。日: 常に nil。帯: 週 `day(atPaperX:)` 64 → 月、64 + 6.5 colW → 日、1400 → 日、10 → nil、1401 → nil、日ページ 72…1000 → その日、71 → nil | ≥ 60 |
| `initial scroll x (M4b)`（2966-2971） | 6 行の `ZoomPolicy.visibleWidth(kind, viewportWidth: w)` を `visibleWidth(kind, viewportWidth: w, zoom: ZoomPolicy.readableZoom(kind))`（iPhone 402 の月・週・年、13 インチと mini の年 = fit < readable の組）/ `zoom: ZoomPolicy.fitZoom(.month, viewportWidth: 744)`（mini の月）に書き換える。**期待値 596 / 548 / 1064 / 635.4 / 844.5 / 0 は不変**（旧 2 引数版が返していた値と同じ） | ±0 |
| `page navigation`・`all-day band (M4b)`・`band migration (M4b)` | 不変 | ±0 |

合計の見込み: 21814 − 80 + 210 ≈ **21940**（暫定閾値 21890。閾値は K の実数 − 50。M4B-9 と同じ順序: K → C）。XCTest（同じ内容）: `ZoomPolicyTests`（`testTableOfWidths` → `testFitAllTable`、`testVisibleWidths` / `testBoundaryAndMaxZoom` / `testBounds`（"a pinch below minZoom clamps to 0.5" → fitAll）/ `testUnusableWidths` / `testPaperViewport` / `testConstants`（`fitTolerance` を消す）を書き換え、`testRatios` / `testCenteringInsets` / `testOverviewSize` を追加）、`PageNavigationTests.testInitialScrollX` の 166-171 を KitChecks と同じ 3 引数版に（期待値不変）、`MonthLayoutEngineTests.testDayAt`、`WeekLayoutEngineTests.testDayAt`、`YearLayoutEngineTests.testDayAtRejectsMissingDates`、`DayLayoutEngineTests.testDayAtIsNil`、`AllDayBandTests.testDayAtPaperX`。`WeekLayoutEngineTests.testInitialScroll`、`YearLayoutEngineTests.testMonthSpansAndInitialScroll`、`*HitTesting*`、`EventRangeTests` は不変。

### 7.2 アプリ・紙とキャンバス（担当 P。シミュレータ）

- `InkCanvasViewTests`: §2.3 の 13 本（新規）＋既存 2 本の書き換え。`testDefaultArgumentsOfTheNewParameters` に新しい 6 引数の既定値（1 / nil / false / 何もしない × 3）を足す。
- `PaperTextTests.testFontSizeBelowReadableIsFrozen`: 月チップ zoom 0.5 → 20、0.49 → 20、0.2871 → 20（画面 5.74 pt）、0.7314 → 13.67、readable 0 → 旧式（0.3 → 33.3）。`gutterLabelSize` 週 0.2871 readable 0.4716 → 19.31、日 0.2313 → 18.7。`testGutterLabelSizeIsCappedByTheGutter` は readable 無しのまま不変。
- `PaperViewTests.testLiveShowStretchesWithoutRedraw`: 窓を 0.5 で作る → `show(…, zoom: 1.0, live: true)` → `displayRequestCount` 不変、`zoomScale` 0.5 のまま、`transform.a == 2`、`bounds.size` 不変、`center` が式どおり → `show(…, zoom: 1.0, live: false)` → `transform == .identity`、`zoomScale` 1.0、新しい窓、count +1。`testLiveShowWithoutAWindowFallsBackToADraw`: attach 直後（窓が空）に `live: true` → 窓ができて count +1、`transform == .identity`。`testShowKeepsTheWindowWhileBouncingAtTheEdges` は負の visible（中央寄せ）でも通ることを 1 例足す。
- `InkLedgerTests` / `InkSnapshotTests` 不変。余白の線の破棄（§1.3）は `InkCanvasViewTests.testStrokesCentredOutsideThePaperAreDropped`: 日 402 × 580 で `canvasView.drawing` に中心 x = −20 lu の線を入れて `canvasViewDrawingDidChange` → 台帳の件数 0、`canvasView.drawing.strokes` 0、undo 不可; 中心が紙の中なら 1。

### 7.3 アプリ・画面（担当 U）

- `ScreenshotModeTests.testParseZoomAndOffset`: `--screenshot-zoom 2` → 2、`abc` / `0` / `-1` / `inf` → 1、無し → 1；`--screenshot-offset 400,200` → (400, 200)、`400` / `a,b` / `1,2,3` → nil；他の値は不変；`--screenshot-sheet edit --screenshot-zoom 2` → zoomRatio 2 のまま月。`testParseLandscape` / `testDefaultsAndBadValues` は `Config` の既定値つきフィールドなので不変。
- `AppSettingsTests`（新規。`AppSettings.defaults = UserDefaults(suiteName: "test-\(UUID())")`）: 無し → 1、`setZoomRatio(2, for: .week)` → 2、`.month` は 1 のまま、`setZoomRatio(1, …)` で key が消える、`setZoomRatio(.nan)` / `0.5` / `100` → 1、key の文字列 4 つ。
- `CalendarRootScreenTests`（新規）: `CalendarRootScreen.paperAreaHeight(area:band:kind:)`: 帯なし 1180 → 1180、週 1 レーン 0.6 → 1180 − 25、日 1 レーン → 1180 − 25、3 レーン → 1180 − 65（3 + 54 + 4 + 2 × 2）。
- `AllDayBandView` / `StickyHeaderView` は SwiftUI なので写真で見る（§8）。日ページの帯に `TapGesture(count: 2)` が無いことは View の構造テストでは確かめられないので §7.4。

### 7.4 実機でしか確かめられないもの

ピンチそのもの（候補 5 は CI のログで、指の感触・ピンチ中の引き伸ばしの見た目と滑らかさ・跳ね返りの後の描き直しは実機）、投げなわ／予定ツール＋指でも書くのときの 1 本指の入力と 2 本指のスクロール・ピンチ、チップを指でタップしても編集が開かないこと（F2）、ダブルタップの 0.3 秒の遅れの感触と指でも書くときの点が消えること、日ページの帯でダブルタップしても何も起きないこと、iPad の横向き（回転で手書きの大きさが変わらないこと）、帯が伸びる倍率（> 0.818）での往復と揺れ（M4C-27）、比率の保存（アプリを落として開き直す）、余白に書いた線が消えること。

## 8. 完了の定義

1. `swift run --package-path TegakiKit KitChecks` が「all N checks passed」（N ≥ 閾値。ローカルと CI）。`swift test --package-path TegakiKit` は CI で緑。順序: K が N を docs/M4C.md に書く → C が閾値を入れる。
2. CI の `build` が緑: 13 インチのユニットテスト（§7.2・§7.3 を含む）が通り、成果物 `screenshots` に 13 インチ 13 枚 + `ipadmini` / `ipad11` 各 4 枚 + `iphone` 縦 7 枚 + `iphone-landscape` 4 枚（撮れたとき）+ ログ 4 本。`app-log.txt` に `zoom: kind=` が 4 ページ分あり `pinch=1 enabled=1 min<max`、zoom 写真の分に `zoom: end` がある。
3. リード（本人）が **次の写真を見て** 確かめる（倍率・pt は §1.2 の推定。≈ の実数は `zoom:` のログから C が M4C.md に書く）:

| 写真 | 見えていなければならないもの |
| --- | --- |
| `ipad13-portrait-month.png` | 6 行の格子が全部入り、下にメモ欄の頭。M4b の写真と同じ（幅ぴったり 0.7314。縦の余白は無い） |
| `ipad13-portrait-week.png` | 0:00〜24:00 の格子が全部入る（倍率 ≈ 0.60 = 帯 25 pt 込みの 1155 / 1920、紙の幅 ≈ 842 pt、左右 ≈ 91 pt の机の色の余白）。固定見出しの列線と帯の列線が紙の列と 1 pt 以内。帯は キャンプ・締切・家族旅行の 1 レーン 18 pt。字は 10 pt |
| `ipad13-portrait-day.png` | 24 時間とメモ欄が全部入る（倍率 ≈ 0.48、幅 ≈ 481 pt、左右 ≈ 271 pt の余白）。時刻ラベル ≈ 9.0 pt、箱の字 ≈ 9.4 pt。帯に 締切 |
| `ipad13-portrait-year.png` | 12 か月 × 31 行が全部入る（見本の年は 16 日の行が 4 レーンで 1896 lu → 倍率 ≈ 0.62、列 ≈ 70 pt、幅 ≈ 871 pt）。チップの字 ≈ 8.1 pt（運動会・キャンプ・家族旅行が読める）、日番号 ≈ 13.7 pt、祝日名 ≈ 6.8 pt。字が枠の外に無い |
| `ipad13-portrait-month-zoom2.png` | 2 倍（1.4628）の月: 水・木・金・土（土は半分）の列、10/5 の週の下半分〜11/2 の週の上が見え、曜日の見出し（水〜土）が紙の列と揃う。チップ・日付の字は M4b の minPoints 以上。横スクロールインジケータ |
| `ipad13-portrait-week-zoom2.png` | 2 倍（≈ 1.20）の週: 帯のレーンが ≈ 26.5 pt に伸びている。火（途中）〜土（途中）、8:45〜。見出し・帯・紙の列線が揃う |
| `ipad13-portrait-year-zoom2.png` | 2 倍（≈ 1.245）の年: 5 月の右端〜12 月（x の clamp）。チップ ≈ 16 pt。月名の見出しが列と揃う |
| `iphone-portrait-month.png` | 6 行の格子とメモ欄が全部入り上下に余白（紙 502 pt）。曜日 7 列。字は 4〜7 pt のサムネイルで、はみ出しも重なりも無い（読めるかは M4C-26） |
| `iphone-portrait-week.png` | 24 時間が全部入る（紙 551 pt、帯込みで上下 ≈ 2 pt）。帯は固定でレーン 18 pt・字 11 pt。箱の字 6 pt。見出しは「水 7」の形のまま（列 54.8 pt。曜日の字を省くのは「M/1」の形の日だけ §1.4） |
| `iphone-portrait-week-jun.png` | 6/1〜6/7 の週。見出しの先頭「6/1」が切れずに入る（§1.4、M4C-28） |
| `iphone-portrait-week-zoom3.png` | 3 倍（0.8613）: 火〜木、8:45 から。打合せ・電話の字 10 pt 以上。帯のレーン ≈ 19 pt。見出しと帯が紙の列と揃う |
| `iphone-portrait-day.png` | 紙 ≈ 231 pt 幅が中央（左右 ≈ 85 pt の机の色の余白）。24 時間が入る |
| `iphone-portrait-year.png` | 12 か月全部（列 32 pt）が **はみ出した文字なしの** サムネイル。月名の見出し 12 個 |
| `ipadmini-portrait-*.png` / `ipad11-portrait-*.png` | 月は M4b と同じ。週・日・年は全部入る（§1.2 の余白） |
| `iphone-landscape-week.png` | 撮れていれば: ≈ 0.11 の地図（字 1.4 pt）。見出しの字は切れる（既知 M4C-7）。崩れ・落ちが無い |

4. 本人が TestFlight で **実機**: 4 ページともピンチで縮む（一覧で止まる）・広がる（maxZoom で止まる）、一覧でも書ける、拡大して書ける、指を離した倍率が残り、同じ種類の別のページも同じ倍率で開く、回転しても一覧は一覧のまま・拡大中は手書きの大きさが変わらない、週・月・年の指のダブルタップでその日へ（帯の列でも）、日ページでは何も起きない、バー・日付の単タップが約 0.3 秒遅れて効く、Pencil のダブルタップで飛ばない（帯の列を除く）、「指でも書く」＋投げなわ／予定ツールで 1 本指の入力と 2 本指のスクロール・ピンチ（F2）、ピンチ中に落ちない・滑らか・跳ね返りの後に紙が描き直される（F3）、余白に書いた線が消える。
5. docs/M4C.md・README・DESIGN の注記が更新され、`MARKETING_VERSION` 0.5.2。

## 9. 本人の決定・未決

| # | 内容 | 既定（返事が無ければこうする） |
| --- | --- | --- |
| M4C-1 | 紙が画面より短いとき縦にも中央寄せ（D1） | **寄せる**（iPhone の月 39 pt、週 2 pt の上下余白。上詰めにしたければ `centeringInsets` の height を 0 にするだけ） |
| M4C-2 | 罫線は画面上 1 pt（現行 `hairline` = 1/zoom、`PaperText.swift:53-55`）か 1 device pixel（リードの D3）か。**リードの決定からの変更提案** | **1 pt のまま**（3x の iPhone の一覧で 0.33 pt は薄すぎる。M4b の写真と見た目が変わらない。§2.4 の確認項目「線は 1 pt」はこの決定に紐づく。1 device pixel にするなら `hairline` を `1 / (zoom × screen.scale)` にするだけ） |
| M4C-3 | readable 未満の文字: lu のまま（閾値で跳ぶ）か readable の lu を凍結して縮めるか | **凍結**（連続。一覧 = 読める紙の縮小。M4b の検算が転用できる） |
| M4C-4 | F2（投げなわ／予定ツールの指入力を認識器へ） | **実装する**。P の最後の作業として 1 コミットに隔離し、実機で崩れたら hitTest の変更だけ戻して既知の制限（M3B.md:122）に残す |
| M4C-5 | F3（ピンチ中・跳ね返り中の引き伸ばし） | **実装する。最初の版に入れる**（13 インチの年で毎フレーム 77 MB の確保と全面描画を避ける。拡大方向まで効かなかったのならこれが本命 M4C-21。ぼけはピンチ中だけ） |
| M4C-6 | ダブルタップで単タップが 0.3 秒遅れる | **受け入れる**（日ページと投げなわ／予定ツールでは遅れない） |
| M4C-7 | iPhone 横の一覧は地図（倍率 0.09〜0.22、字 1〜3 pt、見出しの字が切れる） | **受け入れる**（D1 の式どおり。下限に readable × 0.25 などの床を入れる案は「全画面で一覧」に反する。本人が実機で不便なら次の里程で床を足す）。iPhone 縦は M4C-26 |
| M4C-8 | `zoom:` の NSLog | **DEBUG だけ**（CI は Debug ビルド。TestFlight には出ない） |
| M4C-9 | 保存比率の上限 | **64**（最大の max/fitAll ≈ 41） |
| M4C-10 | KitChecks の閾値 | **K の実数 − 50**（見込み 21940 → 暫定 21890） |
| M4C-11 | zoom 写真の枚数 | **4 枚**（リードの 3 枚 + 週 2 倍。帯の伸びる経路を 1 枚で見る）＋ M4C-28 の 1 枚 |
| M4C-12 | 月の一覧矩形 = 6 行だけ（メモ欄は入れない） | **6 行**（iPad は幅ぴったりのまま。iPhone は紙全体が入るので結果は同じ） |
| M4C-13 | `bouncesZoom` | **true のまま**（下限が fitAll になったので跳ね返りは「一覧より小さくはならない」の意味になる。跳ね返り中も live として扱い、描き直しは跳ね返りの後に 1 回 §1.3） |
| M4C-14 | 倍率を戻す操作（設定の「表示倍率を一覧に戻す」） | **足さない**（ピンチで一覧まで縮めれば比率 1 が保存される） |
| M4C-15 | 帯の列のダブルタップ（D5） | **する**（週だけ。日ページの帯はしない）。単タップは従来どおり作成（SwiftUI が約 0.3 秒待つ）。バーは単タップで編集のまま。Pencil のダブルタップでも飛ぶ（D5 の例外。除外したければ `UIViewRepresentable` の認識器（`allowedTouchTypes = [.direct]`）で帯の列を作り直す: 次の里程） |
| M4C-16 | `maxZoom = max(4 × fit, 2 × readable)` | **この式**（現行の 2 × minZoom と同じ値。minZoom が消えるので readable で書く） |
| M4C-17 | 比率の保存の粒度（種類ごと／ページごと） | **種類ごと**（4 つの key。ページごとは key が増え続ける） |
| M4C-18 | 一覧の初期横位置 | **左上**（比率 1 なら紙全体が入るので今日の列は必ず見える。`initialScrollX` は比率 > 1 のときだけ） |
| M4C-19 | 最初の 1 フレームの見出しの倍率が高さ無しの見積り（幅だけ）になりうる | **受け入れる**（次のターンの通知で揃う。M4b と同じ扱い） |
| M4C-20 | ピンチ中に窓の外が容器の色で見える | **受け入れる**（机の色 M4C-25。終了時に 1 回描き直す。M4B-25 と同じ性質） |
| M4C-21 | **本人に 1 分の確認**: 0.5.1（手元の TestFlight）で、ペンツール・iPad（指でも書くオフ）・月ページで 2 本指を **開いた**（拡大）とき紙は大きくなったか | 答えを前文に書く。**大きくなった** → 原因 1（＋ iPhone の原因 2）で確定、F3 は性能の改善として残す。**大きくならなかった** → F3（候補 3）が本命で、§2.4 の `zoom: begin` / `end` のログを TestFlight の次の版で本人の実機から取り（設定の「ログを書き出す」は無いので Xcode のコンソール: C が手順を M4C.md に）、それでも効かなければ候補 5（M4C-23）。答えが来るまで F1 と F3 の両方を P の最初の版に入れる |
| M4C-22 | 「指でも書く」オンの指のダブルタップが描く 2 点 | **消す**（`handleDoubleTap` で直前 0.5 秒の点を 1 op で `removeStrokes`。undo 可。§4.1）。実機で点が描かれなければこの処理は何もしない。「点が 2 つ残る」を既知の制限にする案は、ダブルタップが「飛ぶ」操作として常用されるので採らない |
| M4C-23 | `pinchGestureRecognizer` が nil（PKCanvasView が zoom を提供していない）と判明したときの代替 | **別里程**。M4c はログ（§2.4 `pinch=%d`）と §2.3 の記録で確定するだけ。代替案: (a) `InkCanvasContainerView` を `UIScrollView` にして PKCanvasView を固定倍率のまま zoom view として入れる（M2 の設計案の逆）、(b) `PKCanvasView` の transform で倍率を自前管理。どちらも `PaperView` の窓・見出しの `PaperViewport` は変えない |
| M4C-24 | **回転・幅の変化（D4 の精密化。リードの「比率を保つ」からの変更提案）**: 一覧なら一覧のまま、拡大中は絶対倍率を保って clamp、保存比率はピンチの終わりだけ | **この案**（根拠は D4 の本文: fitAll が縦横で 2.5 倍変わる、clamp で比率が書き換わると往復で戻らない）。リードが「比率を保つ」に戻すなら §1.3 の 4 を `newZoom = bounds.clamped(ratio × bounds.min)` に戻し、`targetZoom` は比率で持つ |
| M4C-25 | 容器の背景（紙色のままだと中央寄せの余白が紙と見分けられない: 13 インチ縦の日は左右 271 pt の「紙に見える余白」）と、余白に書いた線 | **背景は机の色 #ecebe6、余白の線は捨てる**（§1.3。`inkCell(forCenter:)` が紙の外を端のマスに負の相対座標で保存し、別の倍率・Web 版で紙の外に出るため）。代案: (a) `PaperView` の縁に 1 pt の線＋薄い影（背景は紙色のまま）、(b) 余白の線を許して DESIGN §3.4 に明記 |
| M4C-26 | iPhone 縦の一覧の文字（月チップ 5.7、週の箱 6.1、年チップ 3.7 pt）。iPhone は既定で週ページから始まる（DESIGN §2.11）ので初回起動が読めないサムネイルになる | **既定比率 1（一覧）のまま**（本人の言葉「基本的に全画面にして一覧」と D4 の既定 1 を優先。CI の写真 `iphone-portrait-*.png` で本人が判断）。代案: iPhone だけ `AppSettings.zoomRatio` の既定を readable / fitAll（月 1.74・週 1.64・日 2.43、年 1）にする（U の 1 行。ピンチで一覧まで縮めれば 1 が保存される） |
| M4C-27 | ピンチ中（> 0.818）に帯のレーン高が毎フレーム変わり、スクロールビューの frame が変わって支点が揺れる | **凍結する**（P の `onZoomingChange` ＋ U の `laneZoom`。§1.6、§5.2）。実機で揺れなければ U 側の凍結は外す（引数は残す） |
| M4C-28 | 月初の「10/1」を含む iPhone の週の見出しが一覧で切れる（§1.4） | **月初の日だけ曜日の字を省く分岐＋ `minimumScaleFactor(0.6)`** を P が入れ、C が `iphone-portrait-week-jun.png`（`--screenshot-month 2026-06 --screenshot-page week`。6/1〜6/7）を 1 枚足す |

**第 2 版で所見をどう扱ったか**（採らなかったもの・直したものの理由）:

- 「週・日の写真の帯は 3 レーン（キャンプ・締切・家族旅行）で viewH −65 pt、iPhone の週は 0.268」（UX の所見）は **採らない**: 3 つは重ならず 1 レーン（`KitChecks/main.swift:929` `laneCount == 1`、帯 25 pt）。§1.2・§8 は 1 レーンで出し直した。iPhone の週は帯込みでも幅拘束 0.2871 のまま。
- 「`testRotationKeepsTheRatio` の後半に clamp で `onZoomRatioChange(6.65)` が 1 回呼ばれる例を書く」（コード照合の所見）は M4C-24 で **不要になった**（回転は比率を報告しない）。代わりに `testRotationKeepsTheOverviewAndTheAbsoluteZoom` の (c) が clamp と復元を見る。
- 13 インチ週 zoom2 の列: 第 1 版の「火〜木」は誤りで、1024 / 1.20 = 851 lu が x 300 から見えるので 火（途中）〜土（途中）。iPhone の zoom3（402 / 0.8613 = 467 lu → 火〜木）は正しい。
- 年の写真: 見本の年は 10 月だけに見本の予定が入り（`EventStoreModel.swift:122-124`）16 日の行が 4 レーン（96 lu）なので 1896 lu。年の数字に「見本の年」の値を併記した。
- `centeringInsets` の K の例「月 1024 × 1180 / 0.7314 → (0, 206)」は一覧矩形で計算した誤りで、紙全体なら (0, 0)。§1.1 に「paper は常に紙全体」と明記し、`PaperViewport.initial` に `paperSize:` を足した。
- 「`XCTAssertNotNil(canvas.pinchGestureRecognizer)`」は hard assert をやめて記録だけ（nil でも里程を止めない。M4C-23）。
- `scrollViewDidEndZooming` の clamp は `setZoomScale(animated: true)` ではなく代入（UIKit の bounce と二重に走らせない。XCTest で同期に確かめられる）。
- `onZoomRatioChange` と `onZoomingChange` は常に次ターン配信（UIKit のデリゲートから同期に来るので、SwiftUI の状態に触る U の受け手を守る）。

統合の順番: **K**（`ZoomPolicy` の新 API と削除、`dayAt`、KitChecks と PageNavigationTests の 6 行、KitChecks の実数 N を M4C.md に）→ **P の最初の版**（`InkCanvasView` の新 6 引数の既定値、`PaperText` の `readable` 既定値、`PaperView.show(live:)` 既定値、`InkCanvasViewTests.makeView` の `visibleWidth` 3 引数版。この時点で app がビルドできる）→ **U**（AppSettings、ScreenshotMode、CalendarRootScreen、AllDayBandView、`CalendarRootScreen.swift:308` の 3 引数版）と **P の残り**（F1 ＋ F3 → `applyBounds` → ダブルタップ → 余白と背景 → F2 の順。F2 は最後の 1 コミット）を並行 → **C**（project.yml、build.yml、docs、CI の写真とログの確認）。

本人がやること（Claude が代行できない）: (0) M4C-21 の 1 分の確認（0.5.1 で拡大のピンチは効いたか）。(1) CI の写真（§8 の表）と `zoom:` のログを見て、一覧の見え方（特に iPhone の地図 M4C-7 / M4C-26、机の色の余白 M4C-25）と 2 倍の写真の揃いを判断する。(2) TestFlight で §8 の 4 を実機 4 機種（縦横）で確かめる。ピンチが実機で初めて動くことになるので、候補 5（PencilKit が zoom しない）が残っていれば §2.4 のログの `pinch=0` で分かる。
