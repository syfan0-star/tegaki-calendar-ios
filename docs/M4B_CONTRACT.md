# M4b 実装契約（iPhone・iPad mini・11 インチ・13 インチで読める紙にする）

この文書は M4b の各担当が同時に作業するための **約束事**（公開 API・データ形状・数字・文言・ファイル所有）です。[M4_CONTRACT.md](M4_CONTRACT.md) の続きで、M2〜M4 で決めたことはそのまま生きています（ここに書いていない API は変えません）。設計の根拠は [DESIGN.md](DESIGN.md)（§2.2 座標系と倍率、§2.4 週、§2.5 日、§2.6 年、§2.7 ヘッダー、§2.11 iPhone、§3.4 線の id と所属マス、§3.5 合成し直し、§3.8 ズーム）。Web 版の固定見出しの終日帯（`../tegaki-calendar/js/views/week-view.js` buildAllDay、`day-view.js` allDayList、`styles/views.css` .sh-allday / .ad-chip）の **動き方が正** です。

この版は、初版の契約に対する 3 つの観点（コード照合・使い勝手・検証可能性）の指摘を反映したものです。何をどう変えたか・採らなかった指摘とその理由は §9 の末尾にまとめてあります。

**きっかけ（本人の実機での指摘、2026-10-15）**: (1) 対応機種は iPhone・iPad mini・iPad 11 インチ・iPad 13 インチ（縦横）。(2) iPhone と 11 インチでヘッダーの「今日」の文字が消えた（11 インチは 96dafab で直した。iPhone は CI の写真で確かめる）。(3) 日ページの終日予定が「消えている」（紙の最上部の帯にあり、初期スクロール 7:00／今−1 時間で画面外）。(4) iPhone で週の終日帯の文字が読めない、月の終日の帯が細すぎて文字がはみ出して汚い、年間の文字が読めない。年間は全機種で横スクロールして文字を大きく。

**根本原因**（リードが確定）: `PaperText.fontSize` は文字に画面上の最小 pt（`Size.minPoints / zoom`）を保証するが、帯・レーン・チップの高さは lu × 倍率で縮む（`PaperSpec`: 終日レーン 22 lu、年のレーン 16 lu…）。倍率の下限が「幅ぴったり」（DESIGN §2.2: 倍率 = 画面幅 ÷ W）なので、402 pt の iPhone で月の倍率は 0.287 → 22 lu のレーンは 6.3 pt、その上に 10 pt の文字が乗ってはみ出す。

**本人の決定・リードの決定（この契約で既定にしてあるもの。再検討しない。数字は根拠があれば直し、理由を書く）**:

- **D1 ページごとの最小倍率**: 幅ぴったりを下限にせず `minZoom = max(fitWidth, readableZoom)`。`readableZoom` は「鍵になる列が読める幅」: 月 = 日の列 200 lu ≥ 100 pt（0.5）、週 = 日の列 190.857 lu ≥ 90 pt（0.4716）、日 = 時間軸 588 lu（72…660）≥ 330 pt（0.5612）、年 = 月の列 112 lu ≥ 150 pt（1.3393）。**この版の精密化**: 幅ぴったりが readable の 95 % 以上なら幅ぴったりを採る（`fit ≥ 0.95 × readable → minZoom = fit`。13 インチの 2/3 Split View 678 pt で月が 22 pt だけ横に動く、という意味の無い横スクロールを作らないため。§1.1）。年ページは **全機種** で横スクロール（13 インチ縦 1024 pt で約 6.8 列）、月・週・日は iPhone だけ横スクロール、iPad mini（744 pt）以上の月・週・日は何も変わらない。`maxZoom = max(4 × fitWidth, 2 × minZoom)`。初期の横位置: 月・週 → 今日の列が全部見える（今日が無ければ 0）、年 → 今月の列（今年でなければ 1 月 = 0）、日 → 0（時間軸が先。メモ欄はスクロールで）。ピンチは minZoom より下に行かない。年の 150 pt の根拠: チップの字 13 lu ≥ 10 pt なら 0.77（86 pt）で足りるが、本人の「余裕を持って読める」を優先して 150（チップ 17.4 pt・曜日 20.1 pt）。120 pt（1.0714）が第 2 候補（§9 M4B-22）。DESIGN §2.11 の「要確認 B-2」（iPhone の月は 3.5 列で横スクロール）はこれで解決。
- **D2 固定見出しは横スクロールに追随する**（`StickyHeaderView` の月・週の曜日行、日の日付見出し、年の月名、D3 の終日帯）: 紙と同じ x オフセットと倍率で置き、はみ出しは切る。左のガター（週・日の時刻ラベル、年の日番号）は **紙の一部のまま**（紙と一緒に横へ動く。固定ではない）。調べた結果: 時刻ラベルは `TimeGridPaper.drawHourGrid`、年の日番号は `YearPaper` が紙に描いていて、**どちらも固定ではない**。この里程では固定化しない（§9 M4B-3）。**ただし年ページは全機種で今月の列から始まる = 日番号のガターが最初から画面外** なので、年の各マスの見出しに日番号を曜日の字の前に描く（「7 水」。§4.2。ガターの 1…31 はそのまま）。週・日で今日が金〜日のとき iPhone の時刻ラベルが画面外になるのは、写真（`iphone-portrait-week-sun.png`）で本人が判断する（§6.3、§8）。
- **D3 週・日の終日帯を紙の外（固定見出し）へ**: Web 版と iOS の「カレンダー」と同じ。常に見える、全件をレーンに（Web の `allDayRowsForRange` と同じ詰め方 = `MonthLayoutEngine.packAllDayLanes`、色と文字も同じ）、高さはレーン数で決まりページの見える高さの 35 % で頭打ち、それ以上は帯の中で縦にスクロール。**書けない**。バーをタップで編集（既存の経路）、列の空きをタップでその日の終日予定の作成シート。週・日の紙は 0:00 から始まり帯は無い（`PaperSpec.weekBand* / dayBand*` は廃止、`WeekLayoutEngine` / `DayLayoutEngine` から帯の領域が消え、`CellKey.allDay(day)` / `.allDayDay` は週・日では作られない）。**手書きの移し替え**: 読込時（冪等。両方のキー形式を永久に受け付ける）、週・日の `allday:YYYY-MM-DD` / `allday` の線は `grid` に付け替える。x は列の分だけ平行移動、**y はそのまま**（形を完全に保つ。帯の上端 = 紙の上端なので帯の線の y は元々 ≥ 0。負の y は帯でも見えていなかった。§3.1）。id は保つ（全端末が読込時に移すので iCloud の merge が収束する。既存の `compareStrokes` で `grid` が `allday…` に勝つので merge の規則は変えない §3.2）。月のメモ欄・日マスと年ページは触らない。**帰結**: 終日予定の横には書けなくなる（M3a で「紙の一部にして書ける」にした決定を Web 版の形へ戻す。本人の指摘「終日タスクが消えている」を優先）。
- **D4 文字は絶対にはみ出さない**: バー・チップ・箱の文字はその枠で切る（省略記号つき。`PaperText.drawLine` / `drawLines` が切る）。レーン・チップの高さは lu のまま（D1 で全機種の minZoom でレーン ≥ 11 pt）。`minPoints` の表を新しい minZoom で検算し、9 pt を下回る所だけ直す（検算の結果: 直す所は無い。§4.3）。
- **D5 ヘッダー**: `PageHeaderView.width` の段階（96dafab）は保つ。iPhone の 2 段（< 600 pt）で「今日」が文字で出ることを CI の写真で確かめる（D7）。**計算し直した結果、2 段目の題名に残る幅は約 67〜79 pt しか無い**（初版の 126 pt は HStack の間隔と `.bordered` の内側余白を数え落としていた）ので、compact のときは短い題名 `PageNavigation.compactTitle` を使い、間隔を詰める（§5）。ツールバーは狭い幅で横スクロールのまま。
- **D6 横向き**: どの幅でも動く（全部 `GeometryReader` の幅で決まる。機種名に依存する箇所を増やさない）。
- **D7 CI**: 4 機種で 4 ページの縦の写真（`iphone` / `ipadmini` / `ipad11` / `ipad13`）。6 シートとユニットテストは 13 インチだけ。追加の機種は 1 台ずつ起動して終わったら shutdown。横向きは iPhone だけ可能（§6.4）。iPhone はもう 1 枚、今日が日曜の週（`--screenshot-month 2026-06`。6/7 は日曜）を撮る（D2 の判断材料）。シミュレータの名前は CI の実在する名前に合わせる（`iPad Pro 13-inch (M4)` は **存在しない**。§6.1）。
- **D8** `MARKETING_VERSION` **0.5.1**。この契約は `docs/M4B_CONTRACT.md`、実装結果は `docs/M4B.md`。DESIGN.md §2.2 §2.4 §2.5 §2.6 §2.11 に短い注記（C）。

**範囲外**（触らない）: 課金・閲覧専用（M5）、ガターの固定化（UIKit の固定ガターは次の里程の候補 §9 M4B-3）、年ページの時間指定、月ページの構造、同期エンジン（`Sync/*` は一切触らない）、`InkPage`（merge の規則も変えない §3.2）、Web 版リポジトリ。

## 0. 構成とファイル所有

```
TegakiKit/                                              担当 K（TegakiKit だけを触る）
  Sources/Layout/ZoomPolicy.swift                       新規: ZoomPolicy（最小・最大倍率、5 % の許容、見える幅）と PaperViewport（§1.1）
  Sources/Layout/PageNavigation.swift                   変更: initialScrollX（§1.2）、compactTitle（§5）。initialScrollY は帯が無くなった分だけ値が変わる
  Sources/Layout/AllDayBand.swift                       新規: AllDayBandLayout / AllDayBandBar / AllDayBandEngine / AllDayBandMetrics（§2.1〜2.2）
  Sources/Layout/WeekLayoutEngine.swift                 変更: 帯の廃止、allDayBand（§2.3）
  Sources/Layout/DayLayoutEngine.swift                  変更: 同上（§2.3）
  Sources/Layout/PaperSpec.swift                        変更: weekBand* / dayBand* の 8 定数を削除（§2.4）。CellKey は不変
  Sources/InkModel/BandMigration.swift                  新規: 帯の線の移し替え（純粋関数、§3.1）
  Sources/KitChecks/main.swift                          変更: 週・日の節と rect → event range の週・日の節の修正、新 4 節（§7.1）
  Tests/LayoutTests/ZoomPolicyTests.swift               新規
  Tests/LayoutTests/AllDayBandTests.swift               新規
  Tests/LayoutTests/WeekLayoutEngineTests.swift         変更（§7.1）
  Tests/LayoutTests/DayLayoutEngineTests.swift          変更
  Tests/LayoutTests/EventRangeTests.swift               変更: 週・日の帯の前提（grid.minY 60、終日 → 帯）を直す（§7.1）
  Tests/LayoutTests/PageNavigationTests.swift           変更: initialScrollX、compactTitle
  Tests/InkModelTests/BandMigrationTests.swift          新規
Sources/TegakiCalendar/
  Paper/PaperText.swift                                 担当 P   変更: クリップ、gutterLabelSize（§4.1）
  Paper/PaperView.swift                                 担当 P   変更: PaperContent.allDayBand（§2.5）、見えている範囲の周りだけを持つ紙（§1.6）
  Paper/WeekPaper.swift / DayPaper.swift                担当 P   変更: 帯を描かない（§2.5）
  Paper/TimeGridPaper.swift                             担当 P   変更: drawBandLabel / drawAllDayBars の削除、時刻ラベルの上限（§4.1）
  Paper/MonthPaper.swift                                担当 P   変更: バー・チップの文字を枠で切る（§4.2）
  Paper/YearPaper.swift                                 担当 P   変更: 文字を枠で切る、マスの見出しに日番号（§4.2）
  Ink/InkCanvasView.swift                               担当 P   変更: 倍率の下限・上限、初期横位置、PaperViewport の通知、紙の窓（§1.3、§1.6）
  Ink/InkLedger.swift                                   担当 P   変更: init / reload で BandMigration.migrate（§3.3）
  Views/StickyHeaderView.swift                          担当 P   変更: viewport に追随する PaperRow（§1.4）
  Views/CalendarRootScreen.swift                        担当 U   変更: viewport の受け取り、帯の配置、移し替えの呼び出し（show / applyRemote / reloadShownPage）、帯のタップ、compactTitle、横向きの要求（§2.6、§3.3、§5、§6.4）
  Views/AllDayBandView.swift                            担当 U   新規: 週・日の固定の終日帯（SwiftUI、§2.2）
  Views/PageHeaderView.swift                            担当 U   変更: compact の間隔と題名の字（§5）
  Support/ScreenshotMode.swift                          担当 U   変更: 見本の線を grid に、--screenshot-landscape、先頭の注記（§2.7、§6.4）
Tests/TegakiCalendarTests/PaperTextTests.swift          担当 P   新規: クリップと時刻ラベルの上限（§7.2）
Tests/TegakiCalendarTests/PaperViewTests.swift          担当 P   新規: 紙の窓の計算（§7.2）
Tests/TegakiCalendarTests/InkCanvasViewTests.swift      担当 P   新規: レイアウト中に viewport が同期に届かないこと（§7.2）
Tests/TegakiCalendarTests/InkLedgerTests.swift          担当 P   変更: 帯のテストを grid と移し替えに（§7.2）
Tests/TegakiCalendarTests/ScreenshotModeTests.swift     担当 U   変更（§7.3）
project.yml / .github/workflows/build.yml / docs/M4B.md / README.md / docs/DESIGN.md   担当 C（§6、§8）
```

`Tests/LayoutTests/PageLayoutTests.swift` の `testPaperSpecConstants` は削除する定数を一つも参照しない（`allDayLaneStep` 25・`dayLaneStep` 24 は既にある）ので **変更なし**（K は確認だけ）。`TegakiKit/Sources/InkModel/InkPage.swift` は **触らない**（§3.2）。

依存の向き: `TegakiCalendar` → `TegakiKit`。P と U の接点は次の 7 つだけで、いずれもこの契約の形に固定します。**P と U が並行して作業できるよう、2 人が共有する型は全部 K に置き、P 側の新しい引数には既定値を付けます。**

1. `PaperViewport`（§1.1、**K** が `Layout/ZoomPolicy.swift` に定義）: P は `InkCanvasView.onViewportChange` で送り、U は受け取って `StickyHeaderView` と `AllDayBandView` に渡すだけ。`InkCanvasView.initialScrollX` / `onViewportChange` には既定値がある（P の変更が先に入っても U の呼び出しはそのままビルドできる）。
2. `StickyHeaderView(paper:now:viewport:onDayTap:onMonthTap:)`（§1.4、P）: `viewport` に既定値 `.zero`。U は `viewport` を 1 つ足して呼ぶ（足す前でもビルドできる）。
3. `PaperContent.allDayBand: AllDayBandLayout?`（§2.5、P。K の型が決まれば 1 行。**P が最初に出す**）: U はこれを `AllDayBandView` に渡す。
4. `AllDayBandLayout`（`tones` を含む）/ `AllDayBandMetrics`（§2.1〜2.2、K）: U の帯の全ての数字と色の出所。
5. `BandMigration.migrate(_:)`（§3.1、K）: P は台帳で、U は画面で、同じ関数を呼ぶ。
6. `ZoomPolicy`（§1.1、K）: P はキャンバスで、U は最初の `viewport` と `initialScrollX` の計算で使う。
7. `PageNavigation.compactTitle(_:focus:)`（§5、K）: U が compact のとき `PageHeaderView.title` に渡す。

**担当 P は `Views/CalendarRootScreen.swift`・`Views/AllDayBandView.swift`・`Views/PageHeaderView.swift`・`Support/*` を触らない。担当 U は `Paper/*`・`Ink/*`・`Views/StickyHeaderView.swift` を触らない。担当 K は `TegakiKit/` だけ。担当 C は project.yml・build.yml・docs/M4B.md・README.md・DESIGN.md の注記だけ。** `Sync/*`・`Persistence/*`・`Calendar/*`・`InkPage.swift` は誰も触らない。

## 1. 最小倍率と横スクロール

### 1.1 ZoomPolicy と PaperViewport（担当 K、`Layout/ZoomPolicy.swift`）

```swift
public enum ZoomPolicy {
    /// 鍵になる列の幅（lu）: 月 200 / 週 190.857… / 日 588 / 年 112
    public static func keyColumnWidth(_ kind: PageKind) -> CGFloat
    /// その列が画面で占めるべき最小の幅（pt）: 月 100 / 週 90 / 日 330 / 年 150
    public static func readableColumnPoints(_ kind: PageKind) -> CGFloat
    /// readableColumnPoints / keyColumnWidth: 月 0.5 / 週 0.47156… / 日 0.56122… / 年 1.33928…
    public static func readableZoom(_ kind: PageKind) -> CGFloat
    /// 紙の幅（lu）: 月・週・年 1400 / 日 1000（PaperSpec の値）
    public static func paperWidth(_ kind: PageKind) -> CGFloat
    /// viewportWidth / paperWidth。viewportWidth が有限でない・0 以下なら readableZoom
    public static func fitZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat
    /// 幅ぴったりが readable のこの割合以上なら幅ぴったりを採る（数十 pt だけの横スクロールを作らない）
    public static let fitTolerance: CGFloat = 0.95
    /// fit ≥ fitTolerance × readable なら fit、それ以外は max(fit, readable)
    public static func minZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat
    /// max(4 × fitZoom, 2 × minZoom)
    public static func maxZoom(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat
    public struct Bounds: Equatable, Sendable {              // 初版の `Range`。Swift.Range を隠さない名前に
        public var fit: CGFloat; public var min: CGFloat; public var max: CGFloat
        public init(fit: CGFloat, min: CGFloat, max: CGFloat)
        public func clamped(_ zoom: CGFloat) -> CGFloat          // NaN は min
    }
    public static func bounds(_ kind: PageKind, viewportWidth: CGFloat) -> Bounds
    /// minZoom で画面に入る紙の幅（lu）= viewportWidth / minZoom。紙の幅を超えない（幅ぴったりのときは紙の幅）
    public static func visibleWidth(_ kind: PageKind, viewportWidth: CGFloat) -> CGFloat
}

/// 紙の見えている範囲（pt）。固定見出しと終日帯が紙の x に追随するための値（§1.3）。
/// P（キャンバス）が作って送り、U（画面）が見出しと帯に渡す。CoreGraphics の型だけ（UIKit を import しない）
public struct PaperViewport: Equatable, Sendable {
    public var offsetX: CGFloat       // canvas.contentOffset.x（pt）
    public var zoom: CGFloat          // canvas.zoomScale
    public var width: CGFloat         // キャンバス容器の幅（pt）
    public init(offsetX: CGFloat, zoom: CGFloat, width: CGFloat)
    public static let zero = PaperViewport(offsetX: 0, zoom: 1, width: 0)
    /// 紙の x（lu）→ 容器の x（pt）: lu × zoom − offsetX
    public func x(ofPaper lu: CGFloat) -> CGFloat
    /// lu の幅 → pt: lu × zoom
    public func width(ofPaper lu: CGFloat) -> CGFloat
    /// 最初の 1 フレーム用（キャンバスの通知が来る前）: offsetX 0、zoom = minZoom(kind, viewportWidth)、width = viewportWidth
    public static func initial(_ kind: PageKind, viewportWidth: CGFloat) -> PaperViewport
}
```

`height` は持たない（帯の 35 % の基準は U が `GeometryReader` から取る §2.6。使わない値を同期しない）。

数字（縦。横は `GeometryReader` の幅がそのまま入るだけで、式は同じ。D6）:

| 機種（幅 pt） | fit 月・週・年 / 日 | minZoom 月 / 週 / 日 / 年 | minZoom で見える lu（月 / 週 / 日 / 年） |
| --- | --- | --- | --- |
| iPhone 17 縦（402） | 0.2871 / 0.402 | **0.5** / **0.4716** / **0.5612** / **1.3393** | 804（4.0 列）/ 852（ガター 64 + 4.1 列）/ 716（ガター 72 + 時間軸 588 + メモ 56）/ 300（ガター 56 + 2.2 列） |
| iPhone 16e・SE 縦（390） | 0.2786 / 0.39 | **0.5** / **0.4716** / **0.5612** / **1.3393** | 780 / 827 / 695（メモ 35）/ 291 |
| iPad mini 縦（744） | 0.5314 / 0.744 | 0.5314 / 0.5314 / 0.744 / **1.3393** | 1400 / 1400 / 1000 / 555（56 + 4.5 列） |
| iPad 11 インチ縦（834） | 0.5957 / 0.834 | 0.5957 / 0.5957 / 0.834 / **1.3393** | 1400 / 1400 / 1000 / 623（56 + 5.1 列） |
| iPad 13 インチ縦（1024） | 0.7314 / 1.024 | 0.7314 / 0.7314 / 1.024 / **1.3393** | 1400 / 1400 / 1000 / 765（56 + 6.3 列。端の列を含めて約 6.8 列） |
| 13 インチ横（1366） | 0.9757 / 1.366 | 0.9757 / 0.9757 / 1.366 / 1.3393 | 1400 / 1400 / 1000 / 1020（56 + 8.6 列） |
| 13 インチ 2/3 Split View（678） | 0.4843 / 0.678 | 0.4843（許容 5 % の内: 0.4843 ≥ 0.475）/ 0.4843 / 0.678 / **1.3393** | 1400 / 1400 / 1000 / 506 |
| 幅 690（Split View の端数） | 0.4929 / 0.69 | 0.4929 / 0.4929 / 0.69 / **1.3393** | 1400 / 1400 / 1000 / 515 |
| iPhone SE 横（667） | 0.4764 / 0.667 | 0.4764（≥ 0.475）/ 0.4764 / 0.667 / **1.3393** | 1400 / 1400 / 1000 / 498 |
| iPhone 横（812〜956: 13 mini 〜 17 Pro Max。iPhone 17 は 874） | 0.58〜0.683 / 0.812〜0.956 | fit / fit / fit / 1.3393 | 1400 / 1400 / 1000 / 606〜714 |

許容 5 % の境目: 月は fit 0.475（幅 665 pt、列 95 pt）、週 0.448（85.5 pt）、日 0.5332（313.5 pt）、年 1.2723（142 pt。幅 1781 pt 以上で、該当する機種は無い）。境目の 1 pt 下（月で幅 664）では minZoom が 0.4743 → 0.5 に跳ぶ（紙 700 pt、36 pt の横スクロール）。Split View を指で連続して動かすときだけ起きる飛びで、受け入れる（§9 M4B-23）。

`maxZoom` の例: iPhone 月 max(1.148, 1.0) = 1.148、iPhone 年 max(1.148, 2.679) = 2.679、13 インチ年 max(2.926, 2.679) = 2.926。太字が「幅ぴったりより大きい」= 横スクロールが起きる組み合わせ。紙の幅が画面幅より小さくなることは無い（minZoom ≥ fit）。

### 1.2 初期の横位置（担当 K、`PageNavigation`）

```swift
extension PageNavigation {
    /// 最初に見せる紙の x（lu。呼ぶ側が倍率を掛けて clamp する）。visibleWidth = ZoomPolicy.visibleWidth（lu）。
    /// 月: 今日が 42 日の中にあれば列 c = index % 7 の [200c, 200c + 200] が全部見える最小の x = max(0, 200c + 200 − visibleWidth)。無ければ 0
    /// 週: 今日の列 [64 + c × colW, +colW] が全部見える最小の x = max(0, 64 + (c + 1) × colW − visibleWidth)。無ければ 0
    /// 年: 今年なら今月の列の左端 56 + (m − 1) × 112、今年でなければ 0
    /// 日: 0
    /// 最後に min(x, paperWidth − visibleWidth) と max(0, …) で紙の中に収める。visibleWidth が有限でない・0 以下なら 0
    public static func initialScrollX(_ layout: any PageLayout, now: Date, calendar: Calendar = DayKey.deviceCalendar, visibleWidth: CGFloat) -> CGFloat
}
```

例（今日 = 2026-10-07 水）: iPhone 月 → 列 2 の右端 600 < 804 → 0（月〜木が見える）。日曜が今日なら 1400 − 804 = 596（木〜日）。iPhone 週 → 64 + 3 × 190.857 = 636.6 < 852 → 0。日曜が今日なら 64 + 7 × 190.857 − 852 = 548（時刻ラベルは画面外。`iphone-portrait-week-sun.png` §6.3）。iPhone 年 → min(1064, 1400 − 300.2) = 1064（10 月・11 月と 12 月の 3 分の 2。日番号のガターは左に流れて見えないが、マスの見出しに「7 水」と日番号がある §4.2）。13 インチ年 → min(1064, 635.4) = 635.4（6 月の右 83 % から 12 月まで）。iPad mini 年 → 844.5（8 月の端から 12 月）。`initialScrollY` は週・日で `grid.minY = 0` になるので 60 だけ小さくなる（今日 10:00 → 720 / 900、今日でない → 560 / 700）。

### 1.3 InkCanvasView の適用（担当 P）

```swift
struct InkCanvasView: UIViewRepresentable {
    // 既存の引数はそのまま（M3B §3.3 の順）。initialScrollY の直後に 1 つ、末尾に 1 つ足す（どちらも既定値つき）
    var initialScrollY: CGFloat
    /// 最初に見せる紙の x（lu）。PageNavigation.initialScrollX の値（× 最初の倍率、紙の中に clamp）
    var initialScrollX: CGFloat = 0
    …
    /// contentOffset.x・zoomScale・容器の幅のどれかが変わるたびに（y だけの変化では呼ばない）
    var onViewportChange: (PaperViewport) -> Void = { _ in }
}
```

`Coordinator.containerDidLayout()` を次のとおりに（他の場所は変えない）:

1. `let bounds = ZoomPolicy.bounds(appliedLayout.kind, viewportWidth: viewport.width)`。`hasInitialZoom` かつ `|bounds.min − canvas.minimumZoomScale| < 0.0005` かつ `|bounds.max − canvas.maximumZoomScale| < 0.0005` なら `syncPaperFrame()` だけで戻る（いまの `fit` の判定と同じ形。`syncPaperFrame()` が `notifyViewport()` を含むので、幅が変わっても min / max が同じ回転 — iPhone の年 1.339 → 1.339 — でも `width` が新しくなる）。
2. `wasAtMin = !hasInitialZoom || |oldZoom − oldMin| < 0.0005`。画面中央の紙座標 `centerPaper` を取る（既存）。
3. `canvas.minimumZoomScale = bounds.min`、`canvas.maximumZoomScale = bounds.max`、`newZoom = wasAtMin ? bounds.min : bounds.clamped(oldZoom)`、`contentSize = size × newZoom`。
4. 2 回目以降は中央維持（既存の式。x も y も `clampedOffset`）。**初回** は `contentOffset = clampedOffset((initialScrollX × newZoom, initialScrollY × newZoom))`（どちらも有限でなければ 0、負は 0）。
5. `hasInitialZoom = true`、`syncPaperFrame()`。

`containerDidLayout()` と `applyPending()` の本体全体を `isApplyingGeometry = true; defer { isApplyingGeometry = false }` で囲む（新しい `private var isApplyingGeometry = false`）。理由: この 2 つは SwiftUI のレイアウト・更新の中で走ることがあり（`layoutSubviews` → `containerDidLayout`、`updateUIView` → `update(from:)` → `requestApply` → `applyPending`）、その中の `canvas.zoomScale = …` / `canvas.contentOffset = …` は UIKit が **同期に** `scrollViewDidScroll` / `scrollViewDidZoom` を呼ぶ。そこから `@State` を書き換えると「Modifying state during view update」になる（既存の `notifySelection()` が常に `Task { @MainActor }` にしているのと同じ理由。InkCanvasView.swift 654〜664 行）。

`makeUIView`: `canvas.showsHorizontalScrollIndicator = true`（内容が幅より広いときだけ出る）、`canvas.isDirectionalLockEnabled = true`（縦に流しているとき横にずれない）、`alwaysBounceHorizontal` は false のまま、`bouncesZoom` は既定（true: 指を離すと minZoom に戻る。§9 M4B-4）。`contentSize.width > bounds.width` のときの横スクロールは `PKCanvasView`（UIScrollView）がそのまま行う。

`notifyViewport()`: **`syncPaperFrame()` の末尾で呼ぶ**（scroll・zoom・レイアウト・`applyPending` の全部がここを通る。delegate には手を入れない）。規則は 1 つ:

```swift
private var lastViewport: PaperViewport?
private var viewportDeliveryPending = false

private func notifyViewport() {
    guard let canvas, let container else { return }
    let v = PaperViewport(offsetX: canvas.contentOffset.x, zoom: canvas.zoomScale, width: container.bounds.width)
    guard v != lastViewport else { return }                       // y だけの変化はここで落ちる
    lastViewport = v
    let byFinger = canvas.isTracking || canvas.isDragging || canvas.isDecelerating || canvas.isZooming
    if byFinger, !isApplyingGeometry, !isUpdating, !viewportDeliveryPending {
        parent.onViewportChange(v)                                // 指の動き: 同期（見出しが 1 フレームも遅れない）
    } else if !viewportDeliveryPending {                          // それ以外（レイアウト・ページ切替・プログラムからの代入）: 次のターンに最新値を 1 回
        viewportDeliveryPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.viewportDeliveryPending = false
            if let latest = self.lastViewport { self.parent.onViewportChange(latest) }
        }
    }
}
```

次のターン送りが控えている間は同期に送らない（古い値が新しい値の後に届いて見出しが戻るのを防ぐ。次のターンには `lastViewport` = 最新値が届く）。y だけが変わった scroll では送らない（iPad の月・週・日は横に動かないので縦スクロール中に SwiftUI の更新が 1 回も起きない）。

`applyPending` の `resetScroll`（別ページが同じキャンバスに来たとき）は既存どおり `hasInitialZoom = false → containerDidLayout()` で、新しい `initialScrollX` / `initialScrollY` が効く。`handleTap` / `currentSelection` / `InkOverlayView` は `contentOffset.x` を既に見ているので変更なし（調べて確認した: `InkOverlayView` の private な `contentOffset`（`scrollView?.contentOffset`）を `paperPoint(fromView:)` / `viewRect(fromPaper:)` が x ごと使っている）。

### 1.4 固定見出しの横追随（担当 P、`Views/StickyHeaderView.swift`）

```swift
struct StickyHeaderView: View {
    var paper: PaperContent
    var now: Date
    /// 紙の横オフセットと倍率（§1.1）。width 0 のときは PaperViewport.initial で置く。既定値があるので U の呼び出しが先でも後でもビルドできる
    var viewport: PaperViewport = .zero
    var onDayTap: (DayKey) -> Void
    var onMonthTap: (YearMonth) -> Void
}

/// FractionRow の置き換え: 子 i を x = (Σ_{j<i} columns[j]) × zoom − offsetX、幅 columns[i] × zoom（pt）に置く。
/// 行の幅は提案された幅（= viewport.width）、高さは一番高い子。行の外は .clipped() で切る
struct PaperRow: Layout {
    var viewport: PaperViewport
    /// 各列の幅（lu）。月 [200]×7、週 [64] + [190.857…]×7、日 [72, 588, 340]、年 [56] + [112]×12
    var columns: [CGFloat]
}
```

- 月の曜日行も `HStack` から `PaperRow` に（iPhone の月は横に動く）。見た目（フォント・色・高さ・下線）は変えない。
- `viewport.width == 0`（最初の 1 フレーム）のときは `PaperViewport.initial(kind, viewportWidth: 提案された幅)` で置く（U も同じ値で初期化する §2.6 ので、キャンバスの最初の通知で見た目は変わらない）。
- 各列の中身の最小幅: 週の日見出し（曜日 + 数字 18 pt）は列 90 pt（iPhone の minZoom）で収まる。年の月名は 150 pt。月の曜日 1 字は 100 pt。日は時間軸 330 pt。

### 1.5 回転・幅の変化

`GeometryReader` の幅が変わる → `InkCanvasContainerView.layoutSubviews` → `containerDidLayout()`（§1.3）。minZoom にいた紙は新しい minZoom に（iPhone 縦の年 1.339 → 横でも 1.339、月 0.5 → 横の fit 0.62）、拡大中の紙は中央を保って新しい範囲に clamp。横位置は `clampedOffset` で紙の中に収まる（iPhone 縦で右に寄せた月を横にすると fit に戻り x = 0）。固定見出しと帯は §1.3 の通知で次のターンに揃う（1 フレームの遅れは回転のアニメーションの中に隠れる）。`initialScrollX` は最初の 1 回だけ（回転では適用しない）。iPhone 横（高さ 402 pt）の週は、安全領域 + ヘッダー 1 段 + 固定見出し + 帯 1 レーン + ツールバーを引くと紙に約 165 pt（約 3.8 時間）しか残らず、帯の上限 35 % ≈ 66 pt で 3 レーン目から帯の中がスクロールする。仕様変更はしない（閲覧向け。M4B.md の既知の制限と §8 の確認項目に書く）。

### 1.6 紙のバッキングストア（担当 P、`Paper/PaperView.swift` と `InkCanvasView.syncPaperFrame`）

いまの `PaperView` は紙全体の大きさ（`size × zoom`）の素の `UIView` で、`draw(_:)` に全面を描く。年ページの minZoom 1.3393 では紙が 1875 × 2491 pt になり、バッキングストアは iPhone（@3x）で約 168 MB、13 インチ（@2x）で約 75 MB、iPhone の maxZoom 2.679 では約 670 MB（jetsam の危険、ピンチの毎フレーム全面を描き直す）。M4b は年ページの既定をこれにするので、**見えている範囲の周りだけを持つ** 形に変える:

```swift
@MainActor
final class PaperView: UIView {
    var content: PaperContent { didSet { setNeedsDisplay() } }
    var zoomScale: CGFloat                                   // 変わったら setNeedsDisplay（既存）
    /// このビューが持っている範囲（内容座標 = 紙 × 倍率、pt）。frame.size == window.size
    private(set) var window: CGRect = .zero
    init(content: PaperContent, zoomScale: CGFloat = 1)      // frame は .zero から（最初の show で決まる）
    /// 見えている範囲（内容座標）を伝える。window が visible を含み倍率も同じ → frame.origin だけ動かす（描き直さない）。
    /// それ以外 → window = Self.window(for: visible, content: contentSize)、frame = (window.origin − visible.origin, window.size)、setNeedsDisplay()
    func show(visible: CGRect, zoom: CGFloat, contentSize: CGSize)
    /// visible を上下左右に visible の幅・高さの半分ずつ広げ、(0, 0, content) と交差させた矩形（= 最大 2 × 2 画面）。
    /// visible が有限でない・空なら .zero
    static func window(for visible: CGRect, content: CGSize) -> CGRect
    override func draw(_ rect: CGRect)                       // translateBy(−window.origin) → scaleBy(zoom)。dirty（紙座標）= (rect + window.origin) / zoom
}
```

- `InkCanvasView.Coordinator.syncPaperFrame()`: `paperView.frame = …` の代わりに `paperView.show(visible: CGRect(origin: canvas.contentOffset, size: container.bounds.size), zoom: canvas.zoomScale, contentSize: canvas.contentSize)`。`zoomScale` の代入は既存どおり。`attach` の `contentSize = size` も既存どおり（最初の `show` で窓ができる）。`InkCanvasView.swift` 先頭の図（32 行「PaperView below: frame = (−contentOffset, layout.size × zoom)」）を直す。
- 例: iPhone 年（容器 402 × 600、内容 1875 × 2491、offset (1425, 0)）→ visible (1425, 0, 402, 600) → 広げて (1224, −300, 804, 1200) → 内容と交差 (1224, 0, 651, 1200) = window、frame.origin (−201, 0)。メモリ 651 × 1200 × 9 × 4 B ≈ 28 MB（倍率に依らず上限 ≈ 4 画面分 ≈ 39 MB、13 インチ ≈ 22 MB）。
- 動き: 横縦とも半画面動くまでは描き直しが無い（frame を動かすだけ）。半画面を超えると窓を作り直して 1 回描く（2 × 2 画面分。いまの 13 インチがピンチの毎フレーム描いている 1024 × 1400 pt と同程度）。ピンチ中は毎フレーム窓を描き直す（既存と同じ振る舞いで、量だけ有界）。
- `dirty` の間引き（既存の「dirty の外は描かない」）はそのまま効く。`didMoveToWindow` の `contentScaleFactor` も既存どおり。
- CATiledLayer にしない理由: `PaperRenderer` が `@MainActor` で `content` を別スレッドから読む形にできない（ロックとコピーが要る）。窓の方式は全部メインスレッドで、XCTest で数字が確かめられる（§7.2）。

## 2. 週・日の終日帯を固定見出しへ

### 2.1 帯のレイアウト（担当 K、`Layout/AllDayBand.swift`）

```swift
/// 週・日ページの固定の終日帯（紙の外）。x は紙座標（lu。倍率と横オフセットは表示側が掛ける）、縦はレーン番号で持ち pt は AllDayBandMetrics が決める
public struct AllDayBandBar: Equatable, Sendable, Identifiable {
    public var id: String { eventId }        // 帯の中で 1 予定 1 本
    public var eventId: String
    public var title: String
    public var colorHex: String
    public var lane: Int                     // 0 始まり
    public var startCol: Int                 // 週 0…6、日 0
    public var endCol: Int
    public var continuesLeft: Bool           // 帯の範囲より前から続く（角を角張らせる）
    public var continuesRight: Bool
    /// 紙座標の x 範囲（lu）。週: 64 + startCol × colW + 3（continuesLeft なら 0）… 64 + (endCol + 1) × colW − 3（continuesRight なら 0）。
    /// 日: 72 + 4 … 660 − 12（PaperSpec.dayChipPadLeft / dayChipPadRight）
    public var minX: CGFloat
    public var maxX: CGFloat
    public init(eventId:title:colorHex:lane:startCol:endCol:continuesLeft:continuesRight:minX:maxX:)
}

public struct AllDayBandLayout: Equatable, Sendable {
    public var kind: PageKind                // .week / .day だけ
    public var days: [DayKey]                // 7 / 1
    /// 各列の色の種類（LayoutMath.tone(of:holiday:) の結果。紙の DateLabel.tone と同じ値）。週 7 個 / 日 1 個。表示側は曜日・祝日を自分で判定しない
    public var tones: [DayTone]
    public var paperWidth: CGFloat           // 1400 / 1000
    public var gutter: CGFloat               // 64 / 72（「終日」の字の幅）
    public var columnMinX: [CGFloat]         // 週 64 + i × colW（7 個）、日 [72]
    public var columnWidth: CGFloat          // 190.857… / 588
    public var laneCount: Int
    public var bars: [AllDayBandBar]         // lane、startCol の順
    public var todayColumn: Int?             // 今日の列（色付けに使う）
    public init(kind:days:tones:paperWidth:gutter:columnMinX:columnWidth:laneCount:bars:todayColumn:)
    public static func empty(kind: PageKind, days: [DayKey]) -> AllDayBandLayout   // tones は days から計算
}

public enum AllDayBandEngine {
    /// packAllDayLanes(events, days) をそのまま帯に。間引きは無い（レーンは何本でも増え、表示側が 35 % で内側スクロール）
    public static func week(monday: DayKey, events: [LayoutEvent], now: Date, calendar: Calendar = DayKey.deviceCalendar) -> AllDayBandLayout
    /// 1 日分: 1 予定 1 レーン、eventsOnDay の順（いまの DayLayoutEngine と同じ）
    public static func day(_ day: DayKey, events: [LayoutEvent], now: Date, calendar: Calendar = DayKey.deviceCalendar) -> AllDayBandLayout
}
```

見本の週（2026-10-05〜11）: `bars` = キャンプ（lane 0, col 0…0, continuesLeft, minX 64, maxX 64 + colW − 3）、締切（lane 0, col 2…2, minX 64 + 2colW + 3, maxX 64 + 3colW − 3）、家族旅行（lane 0, col 4…6, continuesRight, minX 64 + 4colW + 3, maxX 1400）、`laneCount` 1、`tones` [.normal × 5, .saturday, .sundayOrHoliday]。見本の日（10/7）: 締切（lane 0, minX 76, maxX 648）、`tones` [.normal]。運動会（10/3 土）は **前の週** なので見本の週の帯には出ない（§8 の確認項目はこれに合わせる）。10/12（スポーツの日）の週の `tones` は [.sundayOrHoliday, .normal, .normal, .normal, .normal, .saturday, .sundayOrHoliday]。

### 2.2 帯の寸法（担当 K、同じファイル）と表示（担当 U、`Views/AllDayBandView.swift`）

```swift
/// 固定の帯の pt の寸法。レーンは lu × 倍率だが、帯は紙ではないので下限を持つ（Web 22 px、iOS カレンダー約 20 pt）
public enum AllDayBandMetrics {
    public static let minLanePoints: CGFloat = 18
    public static let minGapPoints: CGFloat = 2
    public static let minTextPoints: CGFloat = 11
    public static let topPadPoints: CGFloat = 3          // Web .sh-allday padding 3px 0 4px
    public static let bottomPadPoints: CGFloat = 4
    public static let labelPoints: CGFloat = 10          // 「終日」。Web .sh-allday-label 10px
    public static let heightCap: CGFloat = 0.35          // ページの見える高さに対する上限（Web 34vh）
    public struct Metrics: Equatable, Sendable {
        public var lane: CGFloat          // max(22 × zoom, 18)
        public var gap: CGFloat           // max(gapLu × zoom, 2)。gapLu は週 3（allDayGap）/ 日 2（dayLaneGap）
        public var text: CGFloat          // max(textLu × zoom, 11)。textLu は週 13（weekEvent）/ 日 14（dayEvent）
        public var contentHeight: CGFloat // laneCount == 0 → 0。それ以外 3 + n × lane + (n − 1) × gap + 4
        public var visibleHeight: CGFloat // min(contentHeight, floor(0.35 × pageHeight))
        public var scrollsInside: Bool    // contentHeight > visibleHeight
        public func laneTop(_ index: Int) -> CGFloat   // topPadPoints + index × (lane + gap)
    }
    /// pageHeight = 帯とキャンバスを合わせた領域の高さ（pt）。zoom・pageHeight が有限でない・0 以下なら zoom 1 / pageHeight 0 とみなす
    public static func metrics(kind: PageKind, laneCount: Int, zoom: CGFloat, pageHeight: CGFloat) -> Metrics
}
```

数字: iPhone 週（0.4716）1 レーン → lane 18、gap 2、text 11、高さ 25 pt。13 インチ縦（0.7314）3 レーン → lane 18（16.1 を下限で）、gap 2.19、text 11（9.5 を下限で）、高さ 3 + 54 + 4.4 + 4 = 65.4 pt。倍率 1 → 22 / 3 / 13。上限の例: iPhone 縦でページの領域が 630 pt → 220 pt → 10 レーン（3 + 180 + 18 + 4 = 205）までは全部見え、11 レーンから内側スクロール。D3 の「レーン × (22+3) lu × 倍率」に **下限（18 / 2 / 11 pt）を足した** のがこの里程の値（理由: 帯は紙でないので縮める理由が無く、iPhone の minZoom で 10.4 pt のレーンに 10 pt の字では窮屈）。

```swift
/// 週・日の固定の終日帯（M4B_CONTRACT §2.2）。固定見出しの下、キャンバスの上。書けない
struct AllDayBandView: View {
    var band: AllDayBandLayout
    var viewport: PaperViewport
    /// 帯とキャンバスを合わせた領域の高さ（pt）。上限 35 % の基準
    var pageHeight: CGFloat
    var onBarTap: (String) -> Void          // eventId → 編集
    var onColumnTap: (DayKey) -> Void       // 列の空き → その日の終日予定の作成
}
```

- `laneCount == 0` なら `EmptyView`（高さ 0、線も無し。Web の `if (rows === 0) return null` と同じ）。
- 高さ `metrics.visibleHeight`、背景 `PaperPalette.paper`、下端に 1 pt の `PaperPalette.lineStrong`（紙の帯の下線と同じ色）。中は `ScrollView(.vertical, showsIndicators: true)` に `.scrollDisabled(!metrics.scrollsInside)`、内容の高さ `metrics.contentHeight`。
- ガター: `[0, viewport.x(ofPaper: band.gutter)]` に「終日」（`labelPoints` 10 pt、`PaperPalette.ink3`、右寄せ、右の余白 6 pt、`laneTop(0)` の高さに）。紙と一緒に左に流れる（D2）。
- 列の色: `band.todayColumn == i` なら `PaperPalette.todayTint`（週）/ `todayTintSoft`（日）、そうでなく `band.tones[i]` が `.saturday` / `.sundayOrHoliday` なら `weekendTint` / `weekendTintSoft`（紙の列と同じ。今日が優先）。U は曜日や祝日を自分で判定しない。列の幅は `viewport.width(ofPaper: columnWidth)`、x は `viewport.x(ofPaper: columnMinX[i])`。各列の下に `Color.clear.contentShape(Rectangle()).onTapGesture { onColumnTap(days[i]) }`。
- バー: `x = viewport.x(ofPaper: bar.minX)`、幅 `viewport.width(ofPaper: bar.maxX − bar.minX)`、y `laneTop(bar.lane)`、高さ `metrics.lane`、角 4 pt（`continuesLeft` / `Right` の側は 0）、塗り `PaperPalette.color(hex:)`、文字 `PaperPalette.readableText(on:)`、`.font(.system(size: metrics.text, weight: .semibold))`、`.lineLimit(1)`、`.truncationMode(.tail)`、左右の余白 6 pt、`.clipped()`（D4）。`Button` で `onBarTap(eventId)`。アクセシビリティ: バー「題名（予定を編集）」、列「2026年10月7日(水) の終日予定を追加」。
- 全体を `.frame(width: viewport.width).clipped()`。帯は SwiftUI のビューなのでペンも指も紙に届かない（書けない）。ペンのタップもボタンとして効く（紙の 予定 道具のタップと同じく編集が開く）。

### 2.3 週・日のレイアウト（担当 K）

```swift
public struct WeekLayoutInput: Sendable {   // init は不変。inkBottoms は読まなくなる（時間軸は伸びない）
    public init(focus: DayKey, events: [LayoutEvent], inkBottoms: [CellKey: CGFloat], now: Date, calendar: Calendar = DayKey.deviceCalendar)
}
public struct WeekPageLayout: PageLayout, Equatable, Sendable {
    public var pageId: String
    public var days: [DayKey]
    public var size: CGSize                  // 1400 × 1920（固定）
    public var grid: CGRect                  // (0, 0, 1400, 1920)
    public var allDayBand: AllDayBandLayout  // 固定見出しの帯（紙には描かない）
    public var cells: [CellKey: CGRect]      // [.grid: grid] の 1 個
    public var allDayBars: [AllDayBar]       // 常に []（プロトコル要件。紙に帯は無い）
    public var timedBoxes: [TimedEventBox]
    public var dateLabels: [DateLabel]       // 7 個、高さ 0（不変）
    public var nowLine: NowLine?
    public var todayColumn: Int?
    public init(pageId:days:size:grid:allDayBand:cells:allDayBars:timedBoxes:dateLabels:nowLine:todayColumn:)
}
```

消えるもの: `band: CGRect`、`laneCount`、`laneMetrics`、`WeekLayoutEngine.bandHeight(laneCount:inkBottom:)`。関数の新しい意味: `columnFrame(c)` = (64 + c × colW, 0, colW, 1920)、`minutesToY(m)` = m × 80 / 60、`cell(at:)` = 紙の中なら `.grid`（ガターも）/ 外は nil、`inkCell(forCenter:)` = **常に** `.grid`（負の y も）、`growsWithInk` = 常に false、`hit(at:)` = 箱だけ、`band(atY:)` = 紙の中なら `.grid`、`bandTop(.grid)` = 0 / 他は nil、`eventRange` は不変（`grid.minY = 0` なので、いまの検査の「+ g」が「+ 0」になるだけ）、`snapRect(for: 終日)` = **nil**（紙に帯が無い。時間指定は不変）。`PageScroll.scrollDelta` は週で常に 0。

日も同じ形（完全な署名。P の `DayPaper` と K のテストが同じ順序を使う）:

```swift
public struct DayPageLayout: PageLayout, Equatable, Sendable {
    public var pageId: String
    public var day: DayKey
    public var size: CGSize                  // 1000 × 2400
    public var grid: CGRect                  // (0, 0, 1000, 2400)
    public var timeline: CGRect              // (72, 0, 588, 2400)
    public var memo: CGRect                  // (660, 0, 340, 2400)
    public var allDayBand: AllDayBandLayout
    public var cells: [CellKey: CGRect]      // [.grid: grid]
    public var allDayBars: [AllDayBar]       // 常に []
    public var timedBoxes: [TimedEventBox]
    public var dateLabels: [DateLabel]
    public var nowLine: NowLine?
    public var isToday: Bool
    public init(pageId:day:size:grid:timeline:memo:allDayBand:cells:allDayBars:timedBoxes:dateLabels:nowLine:isToday:)
}
```

（現行の順序から `band` / `laneCount` / `laneMetrics` を外し、`memo` の直後に `allDayBand`。）`inkCell` 常に `.grid`、`growsWithInk` 常に false、`snapRect(終日)` nil、`DayLayoutEngine.bandHeight` 削除。`DayLayoutInput.init` は不変。`PageBand.allDay` は型として残す（週・日はもう返さない）。

### 2.4 PaperSpec（担当 K）

削除: `weekBandBase` `weekBandMax` `weekBandTopPad` `weekBandInkMargin` `dayBandBase` `dayBandMax` `dayBandTopPad` `dayBandInkMargin`。残す（帯の x と lu のレーンに使う）: `allDayLane` 22、`allDayGap` 3、`allDayLaneStep` 25、`dayLaneGap` 2、`dayLaneStep` 24、`weekBarInset` 3、`dayChipPadLeft` 4、`dayChipPadRight` 12。`CellKey.allDay(_:)` / `.allDayDay` / `allDayDate` / `isAllDayDay` は **残す**（移し替えが読む。保存形式は不変。DESIGN §3.9）。`LanePacking` は月・年がまだ使う。

### 2.5 紙（担当 P）

- `PaperContent` に `var allDayBand: AllDayBandLayout? { 週・日は layout.allDayBand、月・年は nil }` を足す（**P が最初に出す 1 行**。U はこれで `AllDayBandView` を組み始められる）。
- `WeekPaper.draw`: 手順 2（帯の下線・「終日」・バー）を消す。ガターの縦線は 0…height のまま。列の色は 0…height のまま。`DayPaper.draw`: 同じく手順 2 を消す（ガターと時間軸の縦線は残す）。
- `TimeGridPaper.drawBandLabel` と `drawAllDayBars` を削除（使う所が無くなる）。
- `InkCanvasView` の初期縦位置は `initialScrollY` の値が変わるだけ（§1.2）。

### 2.6 画面の配線（担当 U、`CalendarRootScreen`）

```
VStack(spacing: 0)
  PageHeaderView(…)                         title は compact ? PageNavigation.compactTitle : PageNavigation.title（§5）
  accessNotice                              既存
  StickyHeaderView(paper:now:viewport:…)    viewport を足す
  GeometryReader { area in                  帯とキャンバスの領域（pageHeight = area.size.height）
    VStack(spacing: 0) {
      if let band = paper.allDayBand { AllDayBandView(band:viewport:pageHeight:onBarTap:onColumnTap:) }
      canvas                                InkCanvasView に initialScrollX / onViewportChange を足す
    }
    .frame(width: area.size.width, height: area.size.height, alignment: .top)   帯が無いときもキャンバスが領域を埋める
  }
```

- `@State private var viewport = PaperViewport.zero`。`body` の先頭で `viewport.width == 0` なら `PaperViewport.initial(kind, viewportWidth: proxy.size.width)` を使う（最初の 1 フレームの見出しの位置）。`onViewportChange: { viewport = $0 }`。
- `initialScrollX: PageNavigation.initialScrollX(layout, now: now, visibleWidth: ZoomPolicy.visibleWidth(kind, viewportWidth: proxy.size.width))`。`proxy.size.width` をそのまま使えるのは、キャンバスに横の padding が無いから（いまの配線どおり。足さない）。
- `onBarTap: openEdit(eventId:)`（既存）、`onColumnTap: { openCreate(range: .allDay($0), snapshot: nil, inkIds: []) }`（既存の `openCreate`。許可が無ければ既存のトースト）。
- `handleTap(at:)` は不変（週・日の `hit` は箱だけになる）。`relayout()` は不変（`inkBottoms` は渡すが週・日は読まない）。
- `show(kind:focus:)`・`applyRemote`・`reloadShownPage()` に §3.3 の移し替え。

### 2.7 スクリーンショットの見本（担当 U、`ScreenshotMode`）

- `weekDemoPage`: `demo-stroke-week-wave` を `cell: .grid`、点は x `12 + 64 + 2 × colW`（= 457.71…）から、y 40 ± 5 のまま（水曜の 0:00 の上端。移し替えた結果と同じ座標。見本自体は移し替えを必要としない）。`demo-stroke-week-marker` は不変。
- `dayDemoPage`: `demo-stroke-day-circle` を `cell: .grid`、中心 (800, 30) のまま（メモ列の上端）。波 2 本は不変。
- 見本の予定は **変えない**（月の行の高さと既存の検査を動かさないため）。週の帯 = キャンプ・締切・家族旅行、日の帯 = 締切。`--screenshot-month 2026-06`（§6.3 の日曜の週）は既存の仕組みのまま動く（焦点は 7 日、今日 = 6/7 10:00 日曜）。
- `--screenshot-landscape` は §6.4。ファイル先頭の注記「No landscape variant: iPadOS refuses … simctl cannot rotate」を「iPhone だけ `--screenshot-landscape` で横向き（`requestGeometryUpdate`）。iPad は多タスク対応のため不可」に直す（U）。

## 3. 手書きの移し替え

### 3.1 純粋関数（担当 K、`InkModel/BandMigration.swift`）

```swift
public enum BandMigration {
    /// "allday" または "allday:" で始まるマス
    public static func isBandCell(_ cell: CellKey) -> Bool
    /// 週ページ "w-YYYY-MM-DD"（月曜）: cell "allday:YYYY-MM-DD" → .grid。col = clamp(その日 − 月曜, 0, 6)、
    ///   x += 64 + col × 190.857…（帯のマスの origin は (64 + col × colW, 0)、grid の origin は (0, 0)）。y はそのまま
    /// 日ページ "d-YYYY-MM-DD": cell "allday" → .grid。x も y もそのまま（origin はどちらも (0, 0)）
    /// 他のページ（m1- / y-）・他のマス・墓標 → そのまま。id・t・dev・tool・color・points の個数は保つ。updatedAt は変えない
    public static func migrated(_ stroke: InkStroke, pageId: String) -> InkStroke?   // nil = 対象外（そのまま使う）
    public static func needsMigration(_ page: InkPage) -> Bool                        // 生きている線に対象があるか
    /// 対象の線だけ置き換えた新しい page。対象が無ければ page をそのまま返す（== で等しい）。冪等: migrate(migrate(p)) == migrate(p)
    public static func migrate(_ page: InkPage) -> InkPage
}
```

y を clamp しない理由: 帯のマスの上端は紙の上端（y = 0）で、帯に書いた線の y は元々 ≥ 0。負の y は帯でも紙の外で見えていなかったので、移した後も見えないままで何も失わない。線ごとに clamp すると複数の線でできた図の一部だけがずれて形が崩れる（§9 M4B-26）。点の座標は `InkPoint` の 0.1 lu 丸めのまま足し算する（`InkStroke.translated(by:…)` は id が変わるので使わない。points を直接作り直す）。`pageId` が `w-` でも月曜でないときは `DayKey(ymd:)` の日をそのまま月曜とみなす（`PageNavigation.pageId` は常に月曜を作るので起きない）。壊れた `allday:` キー（日付が読めない）は col 0。`InkPage.unknownStrokes`（未知の tool の生 JSON）に帯のマスがあっても触らない（描かれないので無害。将来その tool を知る版が読込時に同じ関数で移す）。

### 3.2 merge の選び方（変えない）

初版は `InkPage.pickStroke` を「片方だけが帯のマスなら帯でない方」に変える予定だったが、**不要**: 既存の `compareStrokes` は t・tool・color の次に `cell.raw` を辞書順で比べ、`"grid"` は `"allday"` / `"allday:…"` より大きい（'g' > 'a'）ので、同じ id・t・tool・color の移し替え済みの線は **いまの規則でも必ず勝つ**。0.5.0 の端末の merge も同じ規則なので、0.5.0 と 0.5.1 が混在しても `grid` 形に収束する。初版の根拠「無いと古いレコードが勝って毎回移し替え直す」は誤りだった。`InkPage.swift` は触らず、この性質を §3.5 の検査で固定する（§9 M4B-12）。旧形しか知らない古いアプリ（0.5.0）は `grid` の線を 0:00 の上端に描くだけで壊れない。

### 3.3 どこで走るか（P と U。両方が同じ関数を呼ぶ。冪等なので二重に走ってよい）

| 場所 | 担当 | 何をする |
| --- | --- | --- |
| `InkLedger.init(page:layout:deviceId:)` | P | `self.page = BandMigration.migrate(page)`（page.pageId が layout のものと同じとき） |
| `InkLedger.reload(page:keepHistory:)` | P | 同上。指紋表は触らない（M4 §5.4 のまま） |
| `CalendarRootScreen.show(kind:focus:)` | U | `let loaded = ScreenshotMode.isActive ? demoPage : sync.load(id)`、`page = BandMigration.migrate(loaded)`。既存の `pageDirty = false` と `sync.pageOpened(id)` の **後で** `page != loaded` なら `pageDirty = true; scheduleSave()`（順序を逆にすると dirty が消える。スクリーンショットモードでは `saveNow` が何もしないので無害。§9 M4B-11） |
| `CalendarRootScreen.applyRemote(_:)` | U | `merged = BandMigration.migrate(InkPage.merge(page, updated))` から先は既存どおり（`contentDiffers` の判定、`pageDirty`） |
| `CalendarRootScreen.reloadShownPage()`（アカウント切替の答えの後） | U | `let loaded = sync.load(pageId); page = BandMigration.migrate(loaded); pageDirty = false` の後 `page != loaded` なら `pageDirty = true; scheduleSave()`（`show` と同じ 3 行。ここを通ると台帳は `reload` で移すが画面の `page` は旧形のままになり、`PageSignature` は id の集合しか見ないので次の手書きまで旧形が居座る） |

`SyncEngine` / `InkPageStore` / `WebImport`（Web の週・日は既に `grid`、origin (0, 0)）は触らない。保存形式は不変（`CellKey` は文字列のまま）。

### 3.4 収束の筋道

端末 A（0.5.1）が週ページを開く → 読込で移し替え → dirty → 1.5 秒後にファイル、さらに 1.5 秒後に iCloud。端末 B（0.5.1）はプッシュか前面復帰で merge（既存の `compareStrokes` で `grid` が勝つ §3.2）→ 表示は読込時に移し替え済みなので変わらない。端末 B が先に同じ線を旧形のまま持っていても、B の読込で同じ結果になる（同じ関数・同じ入力）。端末 C（0.5.0）が残っていても、その merge で `grid` が勝つので往復しない。iCloud に旧形が残っている間に A が消しゴムで消した線は id が同じなので墓標で消える。

### 3.5 検査（§7.1 の `band migration (M4b)` と `BandMigrationTests`）

見本のページ:

```
w-2026-10-05:  a1 cell allday:2026-10-07  pts (12,40) (17,43) (22,40)  → grid (457.7,40) (462.7,43) (467.7,40)   ← 12 + 64 + 2 × 190.857 = 457.714
               a2 cell allday:2026-10-05  pts (5,−5) (10,2)            → grid (69,−5) (74,2)                     ← x + 64、y はそのまま
               a3 cell grid               pts (300,500)                → 不変
               a4 cell allday:2026-10-19  pts (0,0)                    → grid (64 + 6 × 190.857, 0)              ← 週の外は col 6 に clamp
               a5 cell allday:xx          pts (1,1)                    → grid (65,1)                             ← 壊れたキーは col 0
               deleted { "zz": 1760000000500 }                         → 不変
d-2026-10-07:  b1 cell allday  pts (800,30)                            → grid (800,30)
               b2 cell allday  pts (100,−20) (120,−10)                 → grid (100,−20) (120,−10)                ← cell だけ変わる
m1-2026-10:    c1 cell allday:2026-10-07（壊れたデータ）                → 不変（月は対象外）
y-2026:        d1 cell allday                                          → 不変
```

確かめること: 各線の cell・各点の x/y（0.11 以内）・id・t・dev・tool・color・points.count が期待どおり、`updatedAt` 不変、`deleted` 不変、`needsMigration` が前 true / 後 false、`migrate` を 2 回で同じ、対象の無いページは `==`、`InkPageCodec` の往復後も同じ。**merge（規則は既存のまま）**: `InkPage.compareStrokes(a1 旧, a1 新) < 0`（'a' < 'g'。`pickStroke` を変えなくても新形が勝つ）、`merge(旧ページ, 新ページ)` と `merge(新, 旧)` が等しく生きている線が全部新形、`merge(旧, 旧)` は旧のまま、`merge(新, 新)` は新のまま、a2 のように点が同じで cell だけ違う線も新形が勝つ。

## 4. 文字のはみ出し（担当 P）

### 4.1 PaperText

```swift
enum PaperText {
    /// rect で切る（saveGState / clip(to: rect) / restoreGState。UIGraphicsGetCurrentContext が nil なら切らずに描く）。横は従来どおり省略記号
    static func drawLine(_ string: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left, kern: CGFloat = 0)
    /// 同上（高さ min(rect.height, maxLines × lineHeight) の箱で切る）
    static func drawLines(_ string: String, in rect: CGRect, font: UIFont, color: UIColor, maxLines: Int, lineHeight: CGFloat? = nil)
    /// 時刻ラベル（"0:00"…"23:00"）の大きさ: max(0, min(fontSize(size, zoom), (gutter − 8) / 2.6))。
    /// "23:00" は SF の等幅数字で約 2.48 em（数字 0.55 em × 4 + コロン 0.28 em）、ラベルの幅は gutter − 8。
    /// 週 (64 − 8) / 2.6 = 21.54 lu、日 (72 − 8) / 2.6 = 24.6 lu。
    /// §1.1 の minZoom では上限に届かない（週 10 / 0.4716 = 21.2 < 21.54、日 10.5 / 0.5612 = 18.7 < 24.6）:
    /// 効くのはピンチの跳ね返り中（minZoom より下に一瞬行く）と、将来 minZoom を下げたときの安全弁。
    /// Web 版の gutterLabelLu（(gutter − 10) / 2.9 = 18.6 lu → 8.8 px）より緩いのは、字幅を実測した分（9 pt を割らない）
    static func gutterLabelSize(_ size: Size, zoom: CGFloat, gutter: CGFloat) -> CGFloat
}
```

`TimeGridPaper.drawHourGrid` の `labelSize` の行を `gutterLabelSize(labelSize, zoom: zoom, gutter: labelX + 8)` に（呼ぶ側は `labelX = gutter − 8` を渡している）。

### 4.2 切る場所・年の日番号

| 描く所 | 変更 |
| --- | --- |
| 月のバー `MonthPaper.drawAllDayBars` | 塗った後 `ctx.saveGState(); ctx.addPath(roundedPath); ctx.clip()` で文字を描き `restoreGState`（箱と同じ）。`textRect.width > size` の条件は残す |
| 月のチップ `drawTimedChips` | チップの `frame` で clip（「+n件」・点・時刻・題名の全部） |
| 月の日付 `drawDateLabels` | `drawLine` の clip だけ（数字の箱は 28 lu、祝日名は見出しの残り幅） |
| 年のチップ `YearPaper` 手順 5 | チップの `roundedPath` で clip。`guard frame.height >= size × 0.8` は残す（薄いチップに字を書かない） |
| 年の曜日字・祝日名・日番号 | `drawLine` の clip だけ（枠はマスの左 45 % / ガター） |
| **年のマスの見出しに日番号（新規、D2）** | `YearPaper` 手順 4: 曜日の字の **前** に日番号を描く。字は `yearWeekday` と同じ大きさ（`weekdaySize`）の等幅数字 semibold、色は曜日の字と同じ（`toneColor`、今日は accent、今日は heavy）、枠 `(frame.minX + pad, frame.minY + pad, weekdaySize × 1.3, lineHeight)` に右寄せ。曜日の字の枠は `x = frame.minX + pad + weekdaySize × 1.6`（間 0.3 em）から幅 `weekdaySize × 1.4`。左 45 %（50.4 lu）に「31 水」（1.3 + 0.3 + 1.4 = 3.0 em = 45 lu）が入る。祝日名（下の行）とチップは不変。ガターの 1…31 もそのまま（13 インチ横では両方見える） |
| 週・日の箱 `drawBoxes` | 既に clip 済み。不変 |
| 時刻ラベル・「メモ」 | `drawLine` の clip だけ。「メモ」の字の位置は変えない（iPhone 縦の日ページでは右端にメモ欄が約 32 pt 覗くだけで字は見えない。§8、§9 M4B-24） |
| 固定の帯（SwiftUI） | `.lineLimit(1)` + `.clipped()`（§2.2。U） |

### 4.3 minZoom での検算（`PaperText.Size` の表。pt = max(lu × zoom, minPoints)、lu = pt / zoom）

| 寸法（lu / minPt） | iPhone（月 0.5・週 0.4716・日 0.5612・年 1.3393） | iPad mini（0.5314 / 0.744） | 11 インチ（0.5957 / 0.834） | 13 インチ（0.7314 / 1.024） | 入れ物（lu） |
| --- | --- | --- | --- | --- | --- |
| monthDate 17 / 12 | 12 pt = 24 lu | 12 pt = 22.6 | 12 pt = 20.1 | 12.4 pt = 17 | 見出し 28 ○ |
| monthChip 12.5 / 10 | 10 pt = 20 lu | 10 pt = 18.8 | 10 pt = 16.8 | 10 pt = 13.7 | レーン 22 ○、チップ 20（CJK の字の実高 0.96 em = 19.2 lu は枠の中、行送りの余白だけ clip。英小文字のディセンダ g・p・y は下端が最大 1 pt 欠ける。M4B-20） |
| monthHoliday 11 / 9 | 9 pt = 18 lu | 9 pt = 16.9 | 9 pt = 15.1 | 9 pt = 12.3 | 見出し 28 ○ |
| weekEvent 13 / 10（箱） | 10 pt = 21.2 lu | 10 pt = 18.8 | 10 pt = 16.8 | 10 pt = 13.7 | 箱は clip 済み |
| weekTimeLabel 12 / 10 | 10 pt = 21.2 lu（上限 21.54 の内。"23:00" 52.6 lu < 56 ○） | 10 pt = 18.8（46.7 < 56） | 10 pt = 16.8 | 10 pt = 13.7 | ガター 56 ○ |
| dayEvent 14 / 11 | 11 pt = 19.6 lu | 11 pt = 14.8 | 11.7 pt = 14 | 14.3 pt = 14 | 箱は clip 済み |
| dayTimeLabel 13 / 10.5 | 10.5 pt = 18.7 lu（46.4 < 64 ○） | 10.5 pt = 14.1 | 10.8 pt = 13 | 13.3 pt = 13 | ガター 64 ○ |
| memoLabel 14 / 10.5 | 10.5 pt = 18.7 lu | 10.5 pt = 14.1 | 11.7 pt = 14 | 14.3 pt = 14 | 200 lu ○ |
| yearDayNum 22 / 11 | 29.5 pt = 22 lu | 同じ | 同じ | 同じ | ガター 56 ○ |
| yearWeekday 15 / 9 | 20.1 pt = 15 lu | 同じ | 同じ | 同じ | 見出し 16 ○（日番号 + 曜日 45 lu < 50.4） |
| yearChip 13 / 8 | 17.4 pt = 13 lu | 同じ | 同じ | 同じ | レーン 16 ○（21.4 pt） |
| yearHoliday 11 / 7.5 | 14.7 pt = 11 lu | 同じ | 同じ | 同じ | 12 ○ |

結論: minZoom で 9 pt を下回る寸法は **無い**（年の `minPoints` 8 / 7.5 は届かない値になるが、将来の拡大縮小の安全弁として残す）。例外は間引き（`LaneMetrics.fontScale`）が効いたときで、年は 1 日 40 件の終日予定で 8 pt になるが、その薄いチップはタップで日ページへ行く設計（`yearThinLane`）のまま。`minPoints` は **変えない**。

## 5. ヘッダーと iPhone（担当 K と U）

**幅の計算（初版の誤りを直したもの）**: iPhone 縦（`compact`）の 1 段目は `HStack(spacing: 6)` で、固定幅の子は ◀ 44 + 「今日」（`.bordered`: 字 34 + 内側余白 ≈ 24 = 58）+ ▶ 44 + `navigationButtons` 内の間隔 12 + ＋（`.bordered`: 28 + 20 = 48）+ ☁（記号 17 + 余白 8 = 25）+ ⚙ 44 + 外側の間隔 6 × 6 = 36 + `Spacer(minLength: 4)` × 2 = 8 → **約 319 pt**。横の余白 24 を引いた 378 pt（402 pt 機）のうち題名に残るのは **約 59 pt**（390 pt 機では約 47 pt）。日の題名「2026年10月7日(水)」は `.title3` semibold で約 174 pt、`minimumScaleFactor(0.6)` でも 104 pt なので「2026年1…」と省略記号で切れ、週の「2026年10月5日〜10月11日」はさらに短くなる。「今日」自体は `fixedSize` で残るが、本人が最初に見る画面（iPhone の既定は週）で題名が汚い。初版の M4B-15 の案（0.5 と Spacer 2）でも足りない。

そこで:

- **K**: `PageNavigation.compactTitle(_ kind: PageKind, focus: DayKey) -> String` を足す（`title` は不変）。日「10月7日(水)」（祝日名なし。祝日名は紙の日付見出しに出ている）、週「10/5〜10/11」（月をまたぐ週は「9/28〜10/4」、年をまたぐ週も年は書かない「12/28〜1/3」）、月「2026年10月」、年「2026年」。
- **U**（`PageHeaderView`、compact だけ）: 1 段目の `HStack(spacing: 4)`、`Spacer(minLength: 0)`、題名は `titleText(.headline)`（17 pt semibold。`.title3` 20 pt から）。`minimumScaleFactor(0.6)` と `lineLimit(1)` はそのまま。`navigationButtons` の内側の間隔 6・ボタンの 44 pt（タップ標的）・`.bordered`・`fixedSize` は変えない。1 段のレイアウト（≥ 600）は不変。
- **U**（`CalendarRootScreen`、1 行）: `title: compact ? PageNavigation.compactTitle(kind, focus: focus) : PageNavigation.title(kind, focus: focus)`。
- 直した後の数字: 固定 ≈ 158 + 48 + 25 + 44 + 24 = 299 pt → 題名に 402 pt 機で約 79 pt、390 pt 機で約 67 pt。題名の幅（17 pt、0.6 に縮めた後）: 日「10月17日(土)」≈ 100 → 60、週「10/19〜10/25」≈ 103 → 62、月「2026年12月」≈ 91 → 55、年「2026年」≈ 55 → 33。**390 pt の機種でも切れない**（`iphone-portrait-week.png` / `-day.png` で確かめる。D7 の機種は 402 pt の iPhone 17 だが、数字は 390 pt で設計した）。
- 2 段目の `kindPicker` は幅いっぱい、ツールバーは `ToolbarView` の横スクロール（M2）のまま。横向きの iPhone（幅 ≥ 600 pt）は 1 段のレイアウトになる（`compact = false`、題名は `title`）。`syncTextWidth` 980 / `addEventTextWidth` 760 は不変（横向き iPhone では ☁ は記号、「＋予定」は「＋」）。
- `CalendarRootScreen` の機種依存は既存の 2 か所（初期ページ `.phone` → 週、`allowFinger` の既定）だけで、増やさない（D6）。iPhone の既定 `allowFinger = true`（`drawingPolicy .anyInput`）では 1 本指のドラッグが線になるので、横スクロールは **2 本指**（ツールバーの「指でも書く」を切れば 1 本指）。既定は変えない（§9 M4B-21）が、M4B.md と README に書き、§8 の実機確認に入れる。

## 6. CI の機種マトリクス（担当 C、`.github/workflows/build.yml`）

### 6.1 主機（13 インチ）の選び方を直す

CI の実機名（run 38647600906、Xcode 26.6、iOS 26.2 / 26.4 / 26.5 の 3 ランタイム）: `iPad Pro 13-inch (M5)` `iPad Pro 11-inch (M5)` `iPad mini (A17 Pro)` `iPad (A16)` `iPad Air 13-inch (M3)` `iPad Air 13-inch (M4)` `iPad Air 11-inch (M3)` `iPad Air 11-inch (M4)` `iPhone 17` `iPhone 17 Pro` `iPhone 17 Pro Max` `iPhone 17e` `iPhone Air` `iPhone 16e`。**`iPad Pro 13-inch (M4)` は無い**。既存の `Pick a simulator` は exact 一致に失敗して `ipads[0]` に落ち、たまたま JSON の先頭が 13 インチ M5 だったので動いていた（順序は保証されない）。

`Pick a simulator` を **前方一致の優先順** に: `iPad Pro 13-inch` → `iPad Air 13-inch` → `iPad` → `iPhone` の順で、各段の候補は `sorted()` した名前の最初（決定的）。exact 一致の `preferred` は消す。選ばれた名前は `Using simulator:` のログに出る（M4B.md に実際の名前を書く）。`Resolve the simulator UDID`（Booted を優先）は不変。

残りは変わらない: `Build TegakiKit` → `Run KitChecks`（閾値は **K の実数 − 50**。暫定 20750。§7.1）→ `Test TegakiKit` → XcodeGen → Simulator ビルド → Pick → ユニットテスト（13 インチ）→ UDID → Boot → Install → 4 ページ → 6 シート → **13 インチのログ収集（ここへ移す。§6.3）** → 追加の 3 機種 → Upload。

### 6.2 ファイル名

13 インチの 4 ページを `shots/ipad13-portrait-<page>.png` に、6 シートを `shots/ipad13-portrait-sheet-<sheet>.png` に改名（docs/M4.md の旧名は直さず、M4B.md に対応表を書く）。

### 6.3 追加の 3 機種（既存の「11-inch day shot」のステップを置き換える 1 ステップ）

```bash
# $APP / $BUNDLE は既存のステップと同じ求め方。PRIMARY = 13 インチの UDID（同じ機種が候補に当たっても shutdown しない）
PRIMARY="${{ steps.simudid.outputs.udid }}"
mkdir -p shots
# device-id | 第一候補（exact） | 前方一致の予備（順に）
for SPEC in "iphone|iPhone 17|iPhone 17,iPhone" \
            "ipadmini|iPad mini (A17 Pro)|iPad mini" \
            "ipad11|iPad Pro 11-inch (M5)|iPad Pro 11,iPad Air 11,iPad (A"; do
  ID="${SPEC%%|*}"; REST="${SPEC#*|}"; EXACT="${REST%%|*}"; PREFIXES="${REST#*|}"
  FOUND="$(xcrun simctl list -j devices available | SIM_EXACT="$EXACT" SIM_PREFIXES="$PREFIXES" SIM_PRIMARY="$PRIMARY" python3 -c '
import json, os, re, sys
devices = json.load(sys.stdin).get("devices", {})
def version(runtime):                                  # "…iOS-26-5" → (26, 5)
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
primary_runtime = next((r for r, items in devices.items() for d in items if d.get("udid") == os.environ["SIM_PRIMARY"]), None)
found = {}                                             # name → (udid, key)。同じ名前が 3 ランタイムにある: 13 インチと同じランタイム > iOS が新しい方
for runtime, items in devices.items():
    if "iOS" not in runtime: continue
    for d in items:
        if not (d.get("isAvailable") and d.get("name") and d.get("udid")): continue
        key = (runtime == primary_runtime, version(runtime))
        if d["name"] not in found or key > found[d["name"]][1]:
            found[d["name"]] = (d["udid"], key)
exact = os.environ["SIM_EXACT"]
if exact in found:
    print(exact + "|" + found[exact][0]); raise SystemExit
for prefix in os.environ["SIM_PREFIXES"].split(","):
    for name in sorted(found):
        if name.startswith(prefix):
            print(name + "|" + found[name][0]); raise SystemExit
print("")
' || true)"
  if [ -z "$FOUND" ]; then echo "::warning::No simulator for $ID; skipping."; continue; fi
  NAME="${FOUND%%|*}"; UDID="${FOUND##*|}"
  echo "$ID: $NAME ($UDID)"
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b || { echo "::warning::$ID ($NAME) did not boot; skipping."; continue; }
  xcrun simctl ui "$UDID" appearance light || true
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 || true
  if ! xcrun simctl install "$UDID" "$APP"; then
    echo "::warning::install failed on $ID; skipping."
    [ "$UDID" = "$PRIMARY" ] || xcrun simctl shutdown "$UDID" || true
    continue
  fi
  shoot() {  # shoot <file> <launch args…>: 1 枚撮る。失敗はこの 1 枚だけ（set -e で止めない）
    local FILE="$1"; shift
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    sleep 1
    xcrun simctl launch "$UDID" "$BUNDLE" --screenshot-mode "$@" || { echo "::warning::launch failed ($FILE)"; return 0; }
    sleep 9
    xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q tegakicalendar || echo "::warning::The app is not running after 9 s ($FILE)"
    xcrun simctl io "$UDID" screenshot "shots/$FILE" || echo "::warning::screenshot failed ($FILE)"
  }
  for PAGE in month week day year; do
    shoot "$ID-portrait-$PAGE.png" --screenshot-month 2026-10 --screenshot-page "$PAGE"
  done
  if [ "$ID" = "iphone" ]; then
    # D2 の判断材料: 6/7 は日曜 → 今日の列が右端 → 紙が右に寄り、時刻ラベルは画面外（§8）
    shoot "$ID-portrait-week-sun.png" --screenshot-month 2026-06 --screenshot-page week
    for PAGE in month week day year; do        # §6.4: iPhone だけ横向き
      shoot "$ID-landscape-$PAGE.png" --screenshot-month 2026-10 --screenshot-page "$PAGE" --screenshot-landscape
    done
  fi
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl spawn "$UDID" log show --last 6m --style compact --predicate 'process == "TegakiCalendar"' > "shots/$ID-log.txt" 2>&1 || true
  [ "$UDID" = "$PRIMARY" ] || xcrun simctl shutdown "$UDID" || true
done
ls -la shots
```

`continue-on-error: true`、`if: ${{ !cancelled() && steps.simudid.outcome == 'success' }}`（既存の 11 インチのステップと同じ）。ステップは `set -euo pipefail` で動くので、`bootstatus` / `install` / `launch` / `screenshot` の失敗は上のとおり 1 機種・1 枚だけを飛ばす。`pgrep -fl "TegakiCalendar.app/…"` は 2 台 boot 中に他の機種のプロセスに当たるので、その機種の `launchctl list` で見る。

**13 インチのログ収集**（既存の「Collect the app log and crash reports」）は追加機種の **前** に移す（`--last 8m` のままで 4 ページ・6 シートが窓に入る。追加機種の分は上のループが機種ごとに `shots/<id>-log.txt` に残す）。

時間の見積もり（実測: 11 インチの既存ステップは boot → install → 1 枚 → shutdown で 5 分 0 秒。冷えた 2 台目の boot が約 4.5 分）: 1 機種 ≈ 5.5 分、iPhone は 9 枚で ≈ 6.5 分、合計 ≈ 18 分の追加。いまの 19.5 分 → ジョブ ≈ 40 分。`timeout-minutes` を **75** に（公開リポジトリなので無料）。ジョブが 50 分を超えたら iPhone の横向き 4 枚を先に外す。追加機種の前に 13 インチを shutdown するかは C の判断（前回は 2 台同時 boot でも動いた。メモリが足りなければ shutdown する）。

### 6.4 横向き

`simctl` に回転の命令は無く、iPadOS は多タスク対応アプリ（`UIRequiresFullScreen: false`）の向きの要求（`UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))`）を **無視する**。iPhone は従う。そこで:

- `ScreenshotMode.Config` に `landscape: Bool`（起動引数 `--screenshot-landscape`。既定 false）。
- `CalendarRootScreen`（U）: `shot.landscape` なら `requestLandscapeOnce()` を **`scenePhaseChanged()` の `.active`** で呼ぶ（root view の最初の `onAppear` では `connectedScenes` に `UIWindowScene` が居ない・まだ `foregroundInactive` のことがあり黙って失敗する）。`appear()` の末尾からも呼んでよい（1 回効けばよい。`@State private var landscapeRequested = false` で 2 度目は何もしない）。中身: `UIApplication.shared.connectedScenes` の最初の `UIWindowScene` に `requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in print("screenshot-landscape failed: \(error)") }`（CI の app-log に残る。iOS 16 以降の API、配備目標 17）。
- iPhone 17 の `iphone-landscape-<page>.png` 4 枚を撮る。iPad 3 機種は撮らない（docs/M4B.md に理由を書く: 多タスク対応を外さない限り不可能。実機で本人が確かめる §8）。
- 効いたかの判定: 写真のヘッダーが **1 段**（幅 ≥ 600 → `compact = false`、題名が `title` の長い形）になっていれば横向き。縦のまま（2 段）なら `requestGeometryUpdate` が効かなかった: ステップは失敗させず、`iphone-log.txt` の `screenshot-landscape failed` を M4B.md に写し「横向きは実機のみ」と書く。
- build.yml の 149〜151 行のコメント「simctl cannot tap or rotate the device, and iPadOS refuses … so every shot is portrait」を「iPhone だけ `--screenshot-landscape` で横向き。iPad は多タスク対応のため不可」に直す（C）。

### 6.5 project.yml・docs

`MARKETING_VERSION: "0.5.1"`。`docs/M4B.md`（M4.md と同じ構成: 作ったもの／確かめ方／本人が見るもの／既知の制限）に、写真の対応表（旧名 → 新名、新 4 機種、実際に選ばれたシミュレータの名前）、各機種の minZoom と見える列数（§1.1 の表）、帯の寸法（§2.2）、移し替えの筋道（§3.4）、横向きの制限（§6.4）、KitChecks の実数、既知の制限として (a) iPhone 横向きは閲覧向け（紙に約 3.8 時間、帯は 2 レーンまで全部見える §1.5）、(b) 月のチップの英小文字のディセンダは最大 1 pt 欠ける（§4.3）、(c) 紙は半画面ごとに窓を作り直す（§1.6。速いフリックで 1 回の描き直し）、(d) 年ページの日番号のガターは横に流れる（マスの見出しに日番号 §4.2）、(e) iPhone で「指でも書く」がオンのときの横スクロールは 2 本指（§5）。README の「いま出来ていること」: 週・日の行を「上に終日の帯（固定、書けない。タップで編集、空きをタップで追加）」に、「伸びる紙」から週・日の帯を外す、「iPhone」の行に「月・週・日は横にスクロール（今日の列から）、年は全機種で横にスクロール。『指でも書く』がオンのときは 2 本指で動かす（ツールバーで切れる）」、CI の説明に 4 機種と枚数（13 インチ 10 枚 + iPad mini 4 枚 + 11 インチ 4 枚 + iPhone 縦 5 枚 + iPhone 横 4 枚 = 27 枚）、KitChecks の数。DESIGN.md: §2.2 の「表示倍率 = 画面幅 ÷ W」の直後に「（M4b: 下限は max(幅ぴったり, 読める倍率)。幅ぴったりが読める倍率の 95 % 以上ならそのまま。M4B_CONTRACT §1）」、§2.4 §2.5 の「紙の上部: 終日帯」に「（M4b: 固定見出しへ戻した。紙は 0:00 から。書けない）」、§2.6 に「（M4b: 全機種で横スクロール、月の列 150 pt 以上。マスの見出しに日番号）」、§2.11 の B-2 に「（M4b で解決: §2.2）」。1 行ずつ。

## 7. 検査

### 7.1 TegakiKit（担当 K）: KitChecks の節と件数

| 節 | 内容 | 件数 |
| --- | --- | --- |
| `paper spec and cell keys (M3a)` | この節は `weekBand*` / `dayBand*` を参照していない（参照は `week page` / `day page` 節の `bandHeight` と `laneMetrics`）ので削除は無し。`dayLaneStep` 24 も既にある。足すのは `weekBarInset` 3、`dayChipPadLeft` 4、`dayChipPadRight` 12、`allDayLaneStep` 25 の 4 件 | +4 |
| `week page` | size 1400 × 1920、cells.count 1、`cells[.grid]` (0,0,1400,1920)、`columnFrame(0)` の y 0、`minutesToY(600)` 800、`nowLine.y` 800、`allDayBars` 空、箱の y から 60 を引く、`hit` は箱だけ（帯の点 (colX2+10, 10) は nil）、`cell(at:)` 紙の中は全部 grid（ガター (10, 10) も grid）、`inkCell` は負の y も grid、`growsWithInk(.grid)` false、`band(atY: 10)` grid、`bandTop(.allDay)` nil、`scrollDelta` 常に 0、`sameGeometry` は ink で変わらない、間引きの検査は削除、`initialScrollY` 720 / 560 / 0、`allDayBand` の 3 本（§2.1 の値）と `todayColumn` 2、`tones` 7 個 | 約 −45 + 30 |
| `day page` | size 1000 × 2400、cells.count 1、timeline (72,0,588,2400)、memo (660,0,340,2400)、`allDayBars` 空、箱の y から 60 を引く、`hit` の帯の点は nil、`cell`/`inkCell` 全部 grid、`growsWithInk` false、`scrollDelta` 0、`initialScrollY` 900 / 700、`allDayBand` 締切 1 本（minX 76, maxX 648）、`tones` [.normal]、`busy` は `allDayBand.laneCount` 3・`bars` の順 ["b", "a", "締切"]・lane [0,1,2] | 約 −27 + 18 |
| `rect → event range: day page`（既存、1403 行〜） | `g == 0`（「帯は紙に無い」）、`eventRange` の期待値は不変（grid 相対なので `+ g` が `+ 0` になるだけ）、`snapRect(for: .allDay(10/4))` は **nil**、`busy`（終日 4 件）は `grid.minY == 0` のまま（帯で伸びない）、`busy.snapRect(9:00–10:30)` は y 900 | ±0 |
| `rect → event range: week page`（既存、1464 行〜） | `g == 0`、`snapRect(for: .allDay(10/7))` は **nil**、他は不変 | ±0 |
| `zoom policy (M4b)` 新 | `readableZoom` 4 値（1e-4）、`keyColumnWidth`、`readableColumnPoints`、`fitTolerance` 0.95、`fitZoom` / `minZoom` / `maxZoom` / `visibleWidth` を幅 375・390・402・664・665・667・678・690・744・834・1024・1133・1210・1366 × 4 ページ（§1.1 の表の値。664 の月 0.5、665 の月 0.475、678・690 の月は fit）、`bounds.clamped`（NaN → min、上下）、幅 0 / NaN / 負 → readable、minZoom ≥ fit、maxZoom ≥ 2 × minZoom かつ ≥ 4 × fit、visibleWidth ≤ paperWidth、`PaperViewport.x(ofPaper:)` / `width(ofPaper:)`（offsetX 100・zoom 0.5: x(ofPaper: 400) = 100、width(ofPaper: 200) = 100）、`PaperViewport.initial(.month, 402)` = (0, 0.5, 402)、`.zero` | ≥ 90 |
| `initial scroll x (M4b)` 新 | 月（水曜 → 0、日曜 → 596、今日の無い月 → 0、visibleWidth 1400 → 0）、週（水 → 0、日 → 548、今日無し → 0）、年（今年 10 月: 300.2 → 1064、764.6 → 635.4、1400 → 0、去年 → 0）、日 → 0、visibleWidth NaN / 0 → 0 | ≥ 30 |
| `page navigation`（既存の節に足す） | `compactTitle`: 日「10月7日(水)」（10/12 スポーツの日 → 「10月12日(月)」祝日名なし）、週「10/5〜10/11」、月またぎ「9/28〜10/4」、年またぎ「12/28〜1/3」（2026-12-28 の週）、月「2026年10月」、年「2026年」 | ≥ 8 |
| `all-day band (M4b)` 新 | 週の見本 3 本（§2.1 の全項目）、空の週 → laneCount 0・bars 空、40 本の山 → laneCount 40（間引き無し）、`columnMinX` 7 個、`todayColumn`、`tones`（10/5 の週: 10/10 → .saturday、10/11 → .sundayOrHoliday、10/12 の週 → [.sundayOrHoliday, .normal ×4, .saturday, .sundayOrHoliday]、日 10/7 → [.normal]、日 10/11 → [.sundayOrHoliday]）、`empty` の tones、日の見本・`busy`、`AllDayBandMetrics.metrics`: 週 0.4716 × 1 レーン → 18 / 2 / 11 / 25、1.0 × 1 → 22 / 3 / 13 / 29、0.7314 × 3 → 18 / 2.194 / 11 / 65.4、10 レーン 0.4716 pageHeight 630 → content 205・visible 205・scrollsInside false、11 レーン → content 225・visible 220・true、laneCount 0 → 全部 0、日の gap 2 lu（0.5612 → 2）、`laneTop(2)`、NaN の zoom → 倍率 1 | ≥ 90 |
| `band migration (M4b)` 新 | §3.5 の全部（merge は既存の規則のまま: `compareStrokes(旧, 新) < 0`、両順の merge が新形、`merge(旧, 旧)` / `merge(新, 新)` 不変） | ≥ 65 |

ランダム検査（`testSnapRectIsConsistentWithEventRange`、KitChecks の同等の節）は週・日の `eventRange` が常に時間指定を返すので **変更不要**。合計は現在の 20659 から約 −72 + ≥ 335 → **20900 以上の見込み**。正確な数 N は K が実装後に docs/M4B.md と README に書き、C はそれを見てから build.yml の `test "${N:-0}" -ge <N − 50>` にする（K の前に C が閾値を決めない。暫定値 20750）。XCTest（同じ内容）: `ZoomPolicyTests`、`AllDayBandTests`、`BandMigrationTests`、`WeekLayoutEngineTests`（`testBandHeight` / `testBandsAndScrollDelta` / `testThinningAtTheCap` を削除し `testAllDayBand` を追加、他は値を直す）、`DayLayoutEngineTests`（同様）、`EventRangeTests`（`testDayPageSnapRect` 204 行の all-day → `XCTAssertNil`、214〜218 行の busy は `grid.minY == 0`、`testWeekPage` 225 行 `g == 0`、`testWeekPageSnapRect` 273 行 all-day → nil）、`PageNavigationTests.testInitialScrollX` / `testCompactTitle`。`PageLayoutTests.testPaperSpecConstants` は変更なし。

### 7.2 アプリ・紙と台帳（担当 P。シミュレータ）

- `PaperTextTests`（新規）: (1) `gutterLabelSize` が週 0.4716 で 21.2 lu（上限の内）、週 0.3 で 21.54（上限）、日 0.5612 で 18.7、`gutter` 0 → 0（`max(0, …)`）。(2) クリップ: 100 × 100 の `UIGraphicsImageRenderer` に、`rect` (10, 10, 20, 10) に 20 pt の長い文字列を `drawLine` で描き、rect の外（例 (5, 15)、(15, 25)、(35, 15)）の画素が背景色のまま、rect の中に背景でない画素がある。`drawLines` も同様（maxLines 2、rect の下の外）。
- `PaperViewTests`（新規）: `PaperView.window(for:content:)` — visible (1425, 0, 402, 600)・content 1875 × 2491 → (1224, 0, 651, 1200)、visible (0, 0, 402, 600) → (0, 0, 603, 900)、visible が content より大きい（iPad の幅ぴったり: (0, 0, 1024, 700)、content 1024 × 1400）→ (0, 0, 1024, 1050)、NaN・空 → .zero。`show(visible:zoom:contentSize:)` — 同じ倍率で visible が窓の中に動く → `window` 不変・`frame.origin` が動く・`setNeedsDisplay` が呼ばれない（`layer.needsDisplay()` で見る）、窓の外へ → 新しい窓・`frame.size == window.size`、倍率が変わる → 新しい窓。
- `InkCanvasViewTests`（新規、`@MainActor`）: `InkCanvasView`（`onViewportChange` で回数と値を数える）→ `Coordinator(parent:)` → `InkCanvasContainerView` を `attach` → 容器の frame を 402 × 700 にして `layoutSubviews()`。直後に **回数 0**（同期に届いていない）。`await Task.yield()`（必要なら数回）の後に回数 1、値は `width 402`、`zoom == ZoomPolicy.minZoom(kind, viewportWidth: 402)`、`offsetX == initialScrollX × zoom`（月の見本・水曜なら 0）。もう 1 度 `layoutSubviews()`（同じ大きさ）→ 回数は増えない（`==` の間引き）。幅を 874 に → 次のターンに 1 回。
- `InkLedgerTests`: `testWeekBandStrokeBelongsToThatDaysAllDayCell` → `testWeekStrokeAboveTheGridBelongsToTheGrid`（y −10 の線が `.grid`、points[0].y が −10、`needsMoreRoom` false）。`testWeekBandGrowthMovesGridStrokesWithoutDiff` → 削除（紙は伸びない）。`testDayStrokesGoToBandOrGrid` → `testDayStrokesAllGoToTheGrid`（3 本とも `"grid"`）。`testMoveAcrossTheWeekBandKeepsGridStrokesOnTheGrid` → 上へ動かしても `.grid` のまま、y が負でも grid。新規 `testLedgerMigratesBandStrokesOnInitAndReload`: §3.5 の `w-2026-10-05` を `InkLedger(page:layout:)` に渡すと `ledger.page` の a1 が `.grid` の (457.7, 40)、a2 が (69, −5)、`drawing()` が 5 本、`reload(page: 旧形, keepHistory: true)` 後も同じ、`applyCanvasChange(同じ drawing)` が空（指紋表が保たれる）。
- `InkSnapshotTests.testRenderIsNilWithoutDrawableStrokes` は月のレイアウトだけ使うので不変。

### 7.3 アプリ・画面（担当 U）

- `ScreenshotModeTests.testDemoStrokesSitInTheirPagesCells`: 週 `["grid"]`、日 `["grid"]`（メモ列の条件は残す）。新規: `BandMigration.needsMigration(demoPage(.week))` と `(.day)` が false、`--screenshot-landscape` の解析（有 → true、無 → false、`Config` の他の値は不変）、`--screenshot-month 2026-06` の `focus` が 6/7・`today` が日曜。
- `AllDayBandView` / `StickyHeaderView` / `PageHeaderView` は SwiftUI なので XCTest では確かめない。写真で見る（§8）。

### 7.4 写真でしか確かめられないもの

固定見出しと帯の横の揃い（列の線が紙と一致。§1.3 の「レイアウト中に同期に送らない」が壊れていると初期位置でここがずれる）、帯の高さ・文字の大きさ、iPhone の「今日」と題名、横スクロールの初期位置、年ページの列数と日番号、文字の切れ方（省略記号が出て枠の外に無い）、ピンチの下限（実機）。

## 8. 完了の定義

1. `swift run --package-path TegakiKit KitChecks` が「all N checks passed」（N ≥ 閾値。**ローカル（この Mac）と CI の両方**）。`swift test --package-path TegakiKit` は **CI で** 緑（この Mac の Command Line Tools には XCTest が無い。Package.swift のコメントどおり）。順序: K が N を docs/M4B.md に書く → C が閾値を入れる。
2. CI の `build` が緑: 13 インチのユニットテスト（`PaperTextTests`、`PaperViewTests`、`InkCanvasViewTests`、`InkLedgerTests` の差し替え分、`ScreenshotModeTests` を含む）が通り、成果物 `screenshots` に 13 インチ 10 枚 + `ipadmini` / `ipad11` 各 4 枚 + `iphone` 縦 5 枚 + `iphone-landscape` 4 枚（撮れたとき）+ ログ 4 本。
3. リード（本人）が **次の写真を見て** 確かめる:

| 写真 | 見えていなければならないもの |
| --- | --- |
| `iphone-portrait-month.png` | ヘッダー 2 段で「今日」が文字で出ている。題名「2026年10月」が省略記号で切れていない。曜日行が 月〜木 の 4 列（約 100 pt ずつ）で紙の列と揃う（金〜日は右に流れて見えない）。見えるバー: キャンプ（月 5、左が角張る）・締切（水 7）・家族旅行（月 12〜火 13、左が角張る）・出張（大阪）（水 21〜木 22）が 11 pt の高さで、文字 10 pt が枠の中に収まり、はみ出しも重なりも無い。火 20 に 2 チップ＋「+3件」。10/7 に青い丸と 3 チップ。6 行とも縦に収まり、下にメモ欄の頭 |
| `iphone-portrait-week.png` | 題名「10/5〜10/11」が切れていない。曜日見出し（月 5…木 8 と金 9 の左端）の下に固定の帯: 「終日」が左、キャンプ（月・左が角張る）・締切（水）が 18 pt のレーンに 11 pt の字で読める（家族旅行は金曜の左端 22 lu ≈ 10 pt だけ見え、字は見えなくてよい）。帯の下の紙は **9:00 のラベルから** 始まる（帯は紙に無い）。10:00 の 打合せ と 電話 が 2 列。水曜の列に今日の色と赤い現在線。ガターの「9:00」「10:00」が省略記号でなく読める。見出しの列線と紙の列線が 1 pt 以内で揃う |
| `iphone-portrait-week-sun.png` | 今日 = 6/7 日曜: 紙が右に寄り（x = 548 lu）、見出しは 木〜日 の 4 列、時刻ラベルのガターは **見えない**（D2。本人がこの見え方を受け入れるか判断 M4B-3）。帯は 6 月の見本の終日予定 |
| `iphone-portrait-day.png` | 題名「10月7日(水)」が切れていない。日付見出しの下に帯: 「終日」と 締切（76…648 lu → 約 321 pt の幅）。紙は 9:00 から、時間軸 330 pt が全部見え右に約 32 pt のメモ欄の覗き（罫線だけ。「メモ」の字はスクロールしないと見えない。**意図どおり** M4B-24）。打合せ・電話が 2 列、歯科 |
| `iphone-portrait-year.png` | 題名「2026年」。月名の行が「10月」「11月」「12月（一部）」。日番号のガターは見えない（左に流れている。D2）が、各マスの見出しに「1 木」「2 金」… と日番号がある。各マスの曜日字 20 pt、チップの字 17 pt（運動会 3 日・キャンプ 4〜5・家族旅行 9〜13 が帯でつながる）、祝日名「スポーツの日」が 12 日に読める。文字が枠の外に出ていない |
| `ipadmini-portrait-month/week/day.png` | M4 の 13 インチの写真と同じ構成（幅ぴったり）。週・日は帯が固定見出しの中にあり、紙は 9:00 から |
| `ipadmini-portrait-year.png` | 月名が「8月（右端）9月 10月 11月 12月」。チップの字 17 pt。マスに日番号 |
| `ipad11-portrait-day.png` | ヘッダー 1 段で「今日」が出ている（96dafab の確認）。帯に 締切 |
| `ipad13-portrait-year.png` | 月名が「6月（右 83 %）7月 … 12月」の約 7 列、チップ・曜日字・祝日名が読める。ガターの日番号は見えない、マスの見出しに日番号。**本人が 150 pt で「余裕を持って読める」かを決める**（列数が足りなければ 120 pt が第 2 候補 M4B-22） |
| `ipad13-portrait-week.png` | 帯に キャンプ・締切・家族旅行、レーン 18 pt、字 11 pt。紙は 9:00 から（帯の分 60 lu 上に動いていない）。残り 6 枚の 13 インチの写真は M4 と同じ |
| `iphone-landscape-*.png` | 撮れていれば: ヘッダー 1 段（幅 ≥ 600。これが横向きの判定）、月・週・日は幅ぴったり、年は横スクロール（10 月から）。`-week`: 紙が 3〜4 時間分見える・帯が 1 レーン全部見える。撮れていなければ M4B.md に「実機のみ」 |

4. 本人が TestFlight で **実機**: iPhone で月・週・日を横に流せる（「指でも書く」がオンなら 2 本指。縦に流すとき横にずれない）、ピンチで minZoom より小さくならない、**年ページで最大まで拡大してもアプリが落ちない・ピンチが滑らか**（§1.6）、年ページが横に流れて字が読める、週・日で終日予定が常に上に見える、帯の空きをタップで「予定を追加」（その日の終日）、バーをタップで編集、帯に書けない、帯の予定が 11 本以上で帯の中が縦にスクロールする、回転しても見出しと紙がずれない、M4 以前に週・日の帯に書いた手書きが 0:00 の上端に出て、もう 1 台でも同じ位置、iPad mini と 11 インチの横向きでヘッダーが崩れない、iPhone で今日が金〜日のときの週・日ページ（時刻ラベルが画面外。左に流せば見える）。
5. docs/M4B.md・README・DESIGN の注記が更新され、`MARKETING_VERSION` 0.5.1。

**シミュレータ（CI）で確かめられないもの**（実機だけ。M4B.md の確認表に写す）: ピンチの下限と戻り、拡大時のメモリと滑らかさ、横スクロールの指の感触（方向ロック・2 本指）、iPad の横向き、Apple Pencil が帯に触れたときに線が出ないこと、iCloud 越しの移し替えの収束。

## 9. 本人の決定・未決

| # | 内容 | 既定（返事が無ければこうする） |
| --- | --- | --- |
| M4B-1 | 固定の帯のレーンに pt の下限（18 / 隙間 2 / 字 11）を付ける（D3 の式への追加） | **付ける**（iPhone で 10.4 pt のレーンは窮屈。帯は紙ではない） |
| M4B-2 | 終日予定が無い日・週の帯 | **出さない**（高さ 0。Web・iOS カレンダーと同じ。追加は「＋予定」か 予定 道具） |
| M4B-3 | 週・日の時刻ラベルと年の日番号のガターが横スクロールで流れる（D2） | **この里程では紙のまま**。年は各マスの見出しに日番号を描いて補う（§4.2）。週・日は `iphone-portrait-week-sun.png` で本人が判断。UIKit の固定ガター（`InkCanvasContainerView` に幅 gutter × zoom の `UIView` を置き `syncPaperFrame` で y と倍率を渡す）は次の里程の候補 |
| M4B-4 | ピンチの下限で跳ね返す（`bouncesZoom`） | **既定（true）**: 指を離すと minZoom に戻る |
| M4B-5 | 横のスクロールインジケータ | **出す**（紙が画面より広いときだけ出る） |
| M4B-6 | 方向ロック（`isDirectionalLockEnabled`） | **オン** |
| M4B-7 | 13 インチの写真の改名（`ipad-portrait-*` → `ipad13-portrait-*`、シートも） | **改名する**。docs/M4.md は直さず M4B.md に対応表 |
| M4B-8 | iPhone の横向きの写真（`requestGeometryUpdate`） | **撮る**（失敗してもジョブは落とさない。判定は「ヘッダーが 1 段か」） |
| M4B-9 | KitChecks の閾値 | **K の実数 − 50**（暫定 20750。初版の 20800 は見積もりとの余裕が 27 件しか無かった） |
| M4B-10 | 時刻ラベルの上限 `(gutter − 8) / 2.6` lu（Web は `(gutter − 10) / 2.9`） | **2.6**（SF の等幅数字で "23:00" を実測した値。§1.1 の minZoom では効かない安全弁） |
| M4B-11 | 読込で移し替えたページをすぐ保存・送信する（dirty）か、次の手書きまで待つか | **すぐ保存**（iCloud が早く揃う。既存の merge の規則で往復しない） |
| M4B-12 | `InkPage.pickStroke` が帯でない方を選ぶ（merge の規則の変更） | **変えない**（既存の `compareStrokes` で `grid` > `allday…`。0.5.0 と混在しても収束する。§3.2・§3.5 で検査する。初版の根拠は誤りだった） |
| M4B-13 | 見本の予定を変えて週の帯を 2 レーンにする（例: 文化祭 8〜9 日） | **変えない**（月の行の高さと既存の検査が動く。週の帯は キャンプ・締切・家族旅行、日は 締切。「運動会」は 10/3 で前の週） |
| M4B-14 | 帯の列の空きをタップで終日予定の作成（D3） | **する**。ガターの「終日」のタップは何もしない |
| M4B-15 | iPhone の題名 | **compact の短い題名 + 間隔を詰める + 17 pt**（§5）。「今日」は記号にしない。初版の「0.5 と Spacer 2」は幅が足りない |
| M4B-16 | ペンで帯に触れたとき | 何も描かない。バーなら編集が開く（ボタン） |
| M4B-17 | `WeekLayoutInput` / `DayLayoutInput` の `inkBottoms` 引数 | **残す**（読まない。U の呼び出しを変えない） |
| M4B-18 | 年の初期横位置: 今月の列を左端に（ガターの日番号は見えない）か、今月が見える最小の移動か | **左端に**（D1 の文言どおり。右端は紙の端で止める。日番号はマスの見出しに出る） |
| M4B-19 | 終日予定の横に書けなくなる（D3 の帰結。M3a の決定の取り消し） | **受け入れる**（本人の指摘「終日タスクが消えている」を優先。帯の手書きは 0:00 の上端へ） |
| M4B-20 | 月のチップ（高さ 20 lu）の字 10 pt（= 20 lu）を clip で収める | **そのまま**（CJK の字の実高 19.2 lu は枠の中。英小文字のディセンダは最大 1 pt 欠ける: 既知の制限に書く。チップを 22 に広げると月の行の高さ・既存の検査が動く） |
| M4B-21 | iPhone の「指でも書く」の既定（オン: 横スクロールは 2 本指） | **オンのまま**（M4 §6.8 の決定。README と既知の制限に 2 本指を書く。本人が実機で不便なら次の里程でオフに） |
| M4B-22 | 年の列の幅: 150 pt（1.3393。13 インチ縦 6.8 列・横 8.6 列・mini 4.5 列・iPhone 2.2 列）か 120 pt（1.0714。チップ 13.9 pt・祝日 11.8 pt・曜日 16.1 pt・行 64 pt。13 インチ縦 7.9 列・横 10.9 列・mini 5.7 列・iPhone 2.9 列）か | **150**（本人の「余裕を持って」）。`ipad13-portrait-year.png` を見て決める。差し替えは `readableColumnPoints` の 1 行と §7.1 の数字。両方の写真を CI で撮り分ける仕組みは作らない（起動引数を増やすほどの価値が無い） |
| M4B-23 | 幅ぴったりが readable の 95 % 以上なら幅ぴったり（`fitTolerance`） | **入れる**（13 インチの 2/3 Split View 678 pt・iPhone SE 横 667 pt で意味の無い横スクロールを消す。境目 665/664 pt で minZoom が 0.475 → 0.5 に跳ぶのは受け入れる） |
| M4B-24 | iPhone 縦の日ページで右端にメモ欄が約 32 pt（390 pt 機で約 20 pt）だけ覗く | **受け入れる**（時間軸 330 pt を優先。「メモ」の字を memo.minX + 8 lu に寄せて覗きの中に見せる案は、iPad の見た目も変わるので採らない。readable を幅に合わせて変える案は D6 に反する） |
| M4B-25 | 紙のバッキングストア: 見えている範囲の周り 2 × 2 画面の窓（§1.6）か CATiledLayer か | **窓**（メインスレッドだけ、XCTest で数字が確かめられる。半画面ごとに 1 回の描き直しは既知の制限に書く） |
| M4B-26 | 移し替えで負の y を 0 に揃えるか | **揃えない**（形を完全に保つ。帯の線の y は元々 ≥ 0） |
| M4B-27 | iPhone の週を今日 = 日曜でも撮る（`--screenshot-month 2026-06`） | **撮る**（1 枚 ≈ 15 秒。D2 の判断材料） |
| M4B-28 | 共有の型 `PaperViewport` を K に置く（初版は P の `CanvasViewport`） | **K に置く**（P と U が並行してビルドできる。`height` は持たない） |

**初版への指摘で採らなかったもの・一部だけ採ったもの（理由）**:

- 週の compact の題名「10月5日〜11日」（月またぎ「9月28日〜10月4日」）: 月またぎの形が 17 pt でも約 114 pt（0.6 で 68 pt）で 390 pt 機の 67 pt に入らない。「10/5〜10/11」（最長「12/28〜1/3」でも 62 pt）にした。
- 390 pt の iPhone（iPhone 16e）を CI の 5 台目にする: 1 台 ≈ 5.5 分の追加に見合わない。§5 の数字を 390 pt で設計し、402 pt の写真で確かめる。
- 年の 150 / 120 pt を CI で両方撮る: 起動引数と `ZoomPolicy` の上書き口が要る。本人が 150 の写真で決め、必要なら 1 行変えて撮り直す（M4B-22）。
- 「メモ」の字を覗きの中へ: iPad の見た目が変わる（M4B-24）。
- UIKit の固定ガター（週・日・年）: 正しい方向だが P の変更が `InkCanvasContainerView` に広がる。年はマスの日番号で補い、週・日は写真で本人が判断（M4B-3）。
- CATiledLayer: `PaperRenderer` が `@MainActor` で、`content` を別スレッドから読むにはロックが要る（M4B-25）。
- `maxZoom` に絶対上限（2.0 など）を付ける: 窓の方式でメモリが倍率に依らなくなるので不要。
- `notifyViewport` を「指由来なら同期、それ以外は Task」だけにする（`isApplyingGeometry` 無し）: `containerDidLayout` の中の `contentOffset` 代入が `scrollViewDidScroll` を同期に呼ぶ経路が残るので、フラグも要る（両方入れた）。
- ログ収集を `--last 35m` に: 追加機種のログは機種ごとに取る方が読みやすい。13 インチのログ収集を追加機種の前に移し、`--last 8m` のまま。
- `CanvasViewport.height` を残す: 使う所が無い（帯の 35 % は `GeometryReader` から）。

統合の順番: **K**（`ZoomPolicy` + `PaperViewport`・`AllDayBand`・`BandMigration`・`PageNavigation.initialScrollX` / `compactTitle`・週日の形・KitChecks の実数 N を M4B.md に）→ **P の最初の版**（`StickyHeaderView(viewport:)` の既定値つき引数、`PaperContent.allDayBand`、`InkCanvasView` の新しい引数。これだけで app はビルドできる）→ **P の残りと U（並行）**（U は K の型と P の最初の版だけに依存する）→ **C**（project.yml・build.yml の Pick / 機種ループ / timeout / 閾値 N − 50・M4B.md・README・DESIGN の注記）。本番のコンパイルは CI。ローカル確認（この Mac）: `swift build --package-path TegakiKit && swift run --package-path TegakiKit KitChecks`、`for f in $(find Sources Tests -name '*.swift'); do swiftc -parse -swift-version 5 "$f"; done`。P は M4 §8.4 の Catalyst SDK の型検査を `Paper/*.swift` と `Ink/*.swift`（UIKit・PencilKit は `System/iOSSupport` にある）に試してよい。`Views/*`（SwiftUI）と `Tests/` は CI のみ。

本人がやること（Claude が代行できない）: (1) CI の写真（§8 の表）を見て、年ページの列の幅（M4B-22）、週・日で今日が日曜のときの見え方（M4B-3）、帯の高さ（M4B-1）を判断する。(2) TestFlight で §8 の 4 を実機 4 機種（縦横）で確かめる（年ページの拡大、2 本指の横スクロールを含む）。(3) M4 以前に週・日の帯に書いた手書きが 0:00 の上端に移って困らないか見る（M4B-19）。(4) iPhone の「指でも書く」の既定を変えたいか（M4B-21）。
