# M7a 実装契約（1.1: ツールバーをしまう・消しゴムから自動でペンへ・下に伸びるメモ・日付の当たり・線の予算）

この文書は 1.1 の各担当が同時に作業するための **約束事**（公開 API・数字・文言・ファイル所有）です。[M7_PLAN.md](M7_PLAN.md) の §1.3（互換の規則 K-1〜K-9・事実 F1〜F11）、§2.3、§2.5、§2.6、§2.7、§4.2、§5（本人の答え）、§7 を実装の形にしたもので、M2〜M6 の契約と 1.0.1（[R1_0_1.md](R1_0_1.md)）で決めたことはそのまま生きています（ここに書いていない API は変えません）。材料は 3 本の偵察（道具・紙・互換。2026-10-31）です。**第 2 版**（2026-10-31）: 見直しの指摘（コード・互換・本人の目の 3 つの観点）を反映。採らなかった指摘と理由は §9.1。

**土台のコード**: 1.0.1 のブランチ `fix-iphone-year-jump` の **HEAD 857d3a1**（main a21e469 ＋ 1.0.1 の直し d3033c2・f3a6794・cb2343a「第 2 版」＋ 857d3a1「第 2 版の CI の結果」。857d3a1 は `docs/R1_0_1.md` だけの commit なので、**コードと行番号は cb2343a と同じ**。未 commit の追記は無い。2026-10-31 に `git log --oneline -3` で確かめた）。**1.1 の実装の前に main へ merge する**ので、行番号は特に断らない限りこの作業ツリーのものです（パスの `Sources/TegakiCalendar/` は省く）。merge の前に 1.0.1 側に小さな commit が足されて行がずれたら記号名で探し直し、名前が変わったら意味を変えずに 1.0.1 側の名前に合わせる。この契約が前提にする 1.0.1 の名前は cb2343a（= 857d3a1 のコード）にすべて実在する — `InkCanvasView.onTap: (CGPoint, CGFloat) -> Void`（:90）、`tapLeavesPage: (CGPoint, CGFloat) -> Bool`（:152、旧 `tapActs`）、`Coordinator.fingerTapped(atPaper:zoom:)`（:1117）・`dotStrokeIds(near:zoom:within:)`（:1145）・`removeDots(near:zoom:within:)`（:1163）・`singleTapDotWindow = 1.0`（:1112）・`clock`（:1140）、`CalendarRootScreen.tapTarget(layout:point:zoom:smallScreen:)`（:912）・`usesMinTapTarget(isPhone:width:)`（:904）・`leavesPage(_:)`（:921）・`minTapTarget`（:898）、`YearPageLayout.hit(at:minTarget:)`（`TegakiKit/Sources/Layout/YearLayoutEngine.swift:175-184`）。計画書・規約類は main（7bdc27d）、Web リポジトリは main（7f31727）。単位は特に書かない限り lu（紙の単位）。画面の pt は [M4C.md](M4C.md) §4.1 の CI 実測の一覧の倍率から計算した値。mm は iPad Pro 13 インチ 1 pt ≈ 0.19 mm、iPhone 17 1 pt ≈ 0.17 mm で換算。

**本人の決定（確定。再検討しない。2026-10-31）**: P-1 **A**（1.1 = ツールバー＋消しゴムの自動復帰＋下に伸びるメモ＋計画 §4.2 の小さな項目。指で予定を動かすのは 1.2）／P-4 **A**（「しまう」で **左下** の小さな丸ボタンに。丸ボタンには今の道具と ↶。丸ボタンから広げたときは書き始めると自動でしまう。丸ボタンの長押しで右下へ移せる。端末ごとに記憶）／P-6 **① で A**（日のページは 24 時の下にページ幅いっぱいのメモ欄。月のメモ欄と同じく、下に書くとその下にさらに白紙が続く）／P-10 **A**（広告は入れない）／P-5・P-13 は返事が無いので **推奨の A**（P-5: ツールバーで選んだ消しゴムだけ、1 本以上消して指・Pencil を離したら直前の書く道具へ戻る。Pencil のダブルタップ／スクイーズは今の切り替えのまま。設定 › 入力 でオフにできる。P-13: 年のページの左端の 1〜31 を指でタップすると、その年の **今月** のその日の日ページへ。「指でも書く」オンのときは数字の上だけ）／App Privacy は「データの収集なし」のまま／**最終の提出ボタンと実機の確認は本人**、App Store Connect の入力はリード（Claude）が本人の Chrome で行う。

**リードの決定（この契約の既定。根拠があれば直し、理由を書く）**:

- **D1 ツールバーは 3 つの状態**（§2.1）: 広げた状態（`expanded`。今のバー ＋ 右端に「しまう」）、しまった状態（`collapsed`。左下か右下に丸ボタン）、丸ボタンから一時的に広げた状態（`peek`。**紙の上に重ねて** 出し、紙に触れたらしまう）。`peek` を重ね置きにするのは、紙の領域の高さが 66 pt 変わると高さで倍率が決まる一覧（iPhone の週・日・年）が拡大・縮小し、書き始めのペンの下で紙が動くため（`ZoomPolicy.fitAll`、`TegakiKit/Sources/Layout/ZoomPolicy.swift:73-79`）。`safeAreaInset` を付け外しするのは、本人が「しまう」「ツールバーをいつも出す」を押したときだけ（倍率の追随は M4c D4 のとおり）。記憶は端末ごとの UserDefaults（iCloud に送らない）。
- **D2 消しゴムの自動復帰**（§2.4）: ツールバーで選んだ消しゴム（`EraserOrigin.toolbar`）で 1 本以上消し、指・Pencil を離して **落ち着く待ち（`settleDelay` 0.3 秒）が終わったとき** に `lastInkTool` へ戻す。続けて消した分は足し合わせて 1 回だけ戻す。待ちの間に本人が別の道具を選んでいたら戻さない。紙に触れている途中は道具を変えない（`update(from:)` の手順 3、`InkCanvasView.swift:563-576` が `canvas.tool` をすぐ変える（:572）ので、なぞっている途中のペンが書く線に変わる）。判断は純粋な関数 `ToolbarLogic.toolAfterErase`。設定 › 入力「消しゴムで消したらペンに戻る」（既定オン）。
- **D3 下に伸びるメモ**（§3）: 最後のマス（月の `memo`、日の新しいマス `extra`）の高さを **`700 + 400 × max(0, ceil((下端 − 300) / 400))`、上限 6,000、ただし常に `下端 + 50` 以上** にする。白紙は常に 400 lu 以上残る（上限の近くを除く）。計画 §2.7 の式 `max(700, ceil((b + 400) / 400) × 400)` から **直した**: 計画の式は 1 本書くだけで 700 → 800 に跳ね、写真モードのメモ欄の点（下端 64.5）でも 800 になって iPhone の月の一覧の上下の余白が 44 → 30 pt に変わる。直した式は 700 のまま始まり、「白紙が 400 lu を切ったら 400 lu 足す」という計画の意図はそのまま。日の `extra` は (0, 2400, 1000, 高さ)、最小 700（空の日の紙は 1000 × 3100）。紙の上の見出しは **「自由メモ」**（右の列の「メモ」と区別する。M7A-10）。日の一覧は 24 時間で止める（K-6）。最後のマスの高さだけが変わったときは線を作り直さず `contentSize` だけ更新する（§3.6）。上限に届いたら（新しい線を捨てたとき、または白紙をもう足せなくなったとき）「メモ欄はここまでです」を 1 回（§3.4）。
- **D4 日付の当たり**（§4）: 指の 1 回タップの規則を TegakiKit の純粋な関数 `DateTap.target` に集める。**「指でも書く」オフなら月・年の日付の的を画面上で最低 44 pt（どの画面でも）**。年は 1.0.1 のまま、小さい画面（iPhone か幅 600 pt 未満）なら「指でも書く」に関わらず 44 pt。「指でも書く」オンの月は日付の字の枠（192 × 24 lu。iPhone の一覧で 55 × 6.9 pt、高さ約 1 mm）だけ（iPhone の一覧で 44 pt にするとマスの 9 割が的になり、指で書いた「・」や濁点のような短い線で日のページへ飛ぶ。計画 §2.6 の 6 の規則）。**本人の iPhone（「指でも書く」オンが既定）では月の 1 回タップは 1.0 と変わらない** — これを本人に平易に聞く（M7A-1）。週は変えない（日付は固定見出しのボタンで既に 48 pt 以上）。年の左端の数字（P-13）は `gutterHit`。数字の上だけに絞るのは「指でも書く」オンの **大きい画面** だけ（年の日付と同じく、小さい画面では行の幅いっぱい）。
- **D5 線の予算**（§5、K-9）: 数えるのは「生きている線 ＋ 知らない tool の線」（1.0 が読むときの上限と同じ数え方、`TegakiKit/Sources/InkModel/InkPage.swift:285`）。15,000 本で 1 回だけ案内（ページごと・端末ごと）、19,000 本で新しい線を受け付けない。**1.1 は読むときの上限（`InkPage.maxStrokes`）を 20,000 から 60,000 に上げる**（保存の形式も `v` も変えない）。1.0 の端末が 20,000 本で切り詰めた版を送ってきても、1.1 の端末が和集合に戻して送り直すので、1.1 の端末に一度届いた線は失われない（§1.3、§5.1）。設定 › 情報 に「いちばん線の多いページ」と「今年の年のページ」（端末の中だけで数える。送らない。ファイルを書き換えない読み方で数える）。
- **D6 文言**（§6）: 画面の「この iPad」20 行 21 か所 → 「この端末」。iPhone で誤りになる一般的な「iPad の…」も直す（Pencil の話・Web 版の機能名「手書きを書き出す（iPad アプリ用）」は変えない。購入画面の宣伝文は本人に端末を問わない案を見せる、M7A-6）。規約類の「（iPad アプリ版）」→「（アプリ版）」、Web の HTML も同じ文に（既存の Pages の更新なので「他の Pages を公開しない」約束の範囲内）。
- **D7 互換テストは 1.0 のコードで走らせる**（§1.4、K-7）: 1.0 の InkModel をテスト専用のターゲット `Compat10` に凍結して写し、golden fixture を新しいコード（1.1 の台帳が実際に線を書く経路を含む）で作って 1.0 の写しで読む。CI では、それとは別に **本物の 1.0（a21e469）** の TegakiKit を checkout して同じ確かめを走らせ、さらに **1.0 のアプリの台帳と同期の部品** をシミュレータの単体テストで fixture に当てる（アプリのコードは写しでは確かめきれないため）。
- **D8 版と文書**: `MARKETING_VERSION` **1.1**（`project.yml:20`）。ブランチ `m7a`（1.0.1 を merge した後の main から）。この契約は `docs/M7A_CONTRACT.md`、実装結果は `docs/M7A.md`。

**範囲外**（触らない）: 指で予定を動かす（1.2）、重点欄（年・月 1.4、週 1.5）、書ける終日欄と昔の帯の手書きを戻す（1.5）、計画の紙（1.6）、iPhone Duo と Xcode 27 への移行（1.3）、広告（入れない、P-10）、`Sync/*` の同期の処理（`SyncStatus.swift` の文言だけ U が直す。`SyncEngineTests` に確かめを 1 つ足すのは可）、`InkPage` の形式と版 `v`・書き出し `tegaki-app-export` v1（K-5。読む上限の数字 `maxStrokes` は形式ではないので §5.1 で変える）、`BandMigration` の挙動、Web 版のアプリ本体（`index.html`・`js/`・`sw.js`）、PDF を A4 ごとに分けること、PKToolPicker、ツールバーの指による自由な移動（P-4 の D）、Pencil で書いている間に薄くする（P-4 の B）、写真モードでしまうボタンを隠すこと（`tool-eraser` の写真に写す必要がある）。

### 0.1 決めどころの決着

| # | 決めどころ | 決着 |
| --- | --- | --- |
| 0-1 | 計画の式は最初の 1 本で 700 → 800 | **`700 + 400k`**（D3）。b ≤ 300 で 700、≤ 700 で 1,100、…、5,600 で 5,900、その先は上限 6,000。どの b でも 1.0 の式（`b + 50`）以上 |
| 0-2 | 伸ばす合図 `needsMoreRoom` が「下端 + 50」のまま（`Ink/InkLedger.swift:321-325`） | **式を K の `PaperGrowth` 1 か所に**。台帳とエンジンが同じ関数を使う。直さないと欄 1,100 で下端 750 の線を書いても組み直しが起きない |
| 0-3 | 日の `extra` の最小 | **700**（月と同じ関数・同じ数字）。空の日でも紙は 3,100（iPhone の日の一覧 0.2233 で 24 時の下に 156 pt、13 インチ 0.4654 で 326 pt。どちらも一覧の外） |
| 0-4 | `extra` の上で予定ツール・「予定にする」 | **`eventRange` は変えない**（PageLayout の約束「nil は有限でない矩形のときだけ」、`PageLayout.swift:138-141`。nil にすると乱数の不変条件 KitChecks :1776-1849・`EventRangeTests` :435- と、24:00 ちょうどのタップ・23:00→25:00 のドラッグの確認 KitChecks :1557-1561・`EventRangeTests` :178-182 が壊れ、今作れる 23:00〜24:00 の予定も作れなくなる）。新しい純粋な関数 **`DayPageLayout.startsBelowDay(_:)`**（正規化した矩形の minY ≥ `grid.maxY`）を U が `eventRange` の前に呼び、true ならトースト「24 時の下の自由メモ欄では予定を作れません」 |
| 0-5 | 上限を超えた新しい線・上限に届いたこと | 中心が **最後のマスの上端 + 6,000 より下** なら捨てる（紙がそれより長くても。1.0 の端末から来た深い線で紙が長いとき）。案内「メモ欄はここまでです」は、①線を捨てたとき、②新しい線で最後のマスの下端が 5,600 を超えた（白紙をもう 400 足せない、`PaperGrowth.reachesCap`）とき。そのページを開いている間に 1 回 |
| 0-6 | 紙の高さだけ変わると上下の余白が古いまま（1.0 からの小さな不具合: `applyInsets` を `applyPending` が呼ばない、`Ink/InkCanvasView.swift:882-892`） | **両方の経路で `applyInsets()`**。iPhone の月の一覧でメモ欄が 1,100 になると紙は 617 pt（> 591）になり、余白 0 が正しい |
| 0-7 | 1.0.1 の年の 44 pt と計画 §4.2 の月の規則（オフのときだけ）がずれている | **D4 の規則にそろえる**（§4.1 の表）。年の iPad 全画面・オフは 1.1 で 44 pt に広がる（M7A-2、本人の確認 14b）。iPhone の「指でも書く」オンの月は 1.0 のまま（M7A-1。新機能の文は「オフのとき」に限る） |
| 0-8 | 週の日付 | **変えない**。固定見出しのボタン（`Views/StickyHeaderView.swift:99-138`、`minHeight: 48` は :132）、列の幅は iPhone 53.7・mini 87.3・11 インチ 94.9・13 インチ 111.4 pt。iPhone 横の 20.4 pt は隣と重なるので受け入れる（M4C-7 と同じ） |
| 0-9 | 年の左端の数字 | 無い日（11 月の 31・平年の 2/29）は **何もしない**（M7A-3）。紙の左の余白（x < 0）へは広げない（全部の当たり判定の「紙の外は nil」を守る）。「今月」はレイアウトに無いので画面が `now` の月を渡す。数字の上だけに絞るのは `allowFinger && !smallScreen`（iPhone の「指でも書く」オンでは行の幅いっぱい 16 × 17 pt。数字の上だけだと 16 × 8 pt で叩けない。56 lu のガターに書くことはまれ） |
| 0-10 | 「しまう」をスクロールの中の右端に足すと、13 インチ縦（ペンのとき中身 ≈ 984 pt）でも見えない | **ScrollView の外の右端に固定**（§2.2） |
| 0-11 | 丸ボタンから広げたバーの置き方 | **重ね置き**（D1）。紙の領域は変えない |
| 0-12 | しまった状態から「いつも広げた状態」へ戻る口 | **丸ボタンの長押しメニュー**（カプセル全体。道具の印でも ↶ でも長押しで出る）「右下へ移す」（または「左下へ移す」）と「ツールバーをいつも出す」（M7A-4、本人の確認 3b） |
| 0-13 | 起動時の道具が記憶した色・太さを読まない既存の不具合（`Views/CalendarRootScreen.swift:122, 232` は黒・中、ツールバーは記憶した色を光らせる `Views/ToolbarView.swift:116, 174`） | **直す**（§2.3）。丸ボタンの記号と自動復帰の「赤・太に戻る」がこれに引っかかる |
| 0-14 | 消し終わりの見分け方（PencilKit の End と変更の知らせの順番は保証されない） | 落ち着く待ちの間も数え、待ちの終わりに報告（§2.5）。取り消し・iCloud・点消し・投げなわは `isApplyingDrawing` / `isMovingSelection` の囲いで数えない |
| 0-15 | 丸ボタンとトースト・紙の左下の重なり | トーストを丸ボタンの上へ（下の余白 8 → 62）。しまっている間はキャンバスの下に 60 pt の余白を足し、紙の最下部を丸ボタンの上まで送れるようにする |
| 0-16 | 線の数え方と、20,000 本を超えたとき | `liveStrokeCount`（知らない tool を数えない、`InkPage.swift:63-65`）ではなく **`budgetCount` = 生きている線 ＋ `unknownStrokes`**。19,000 本で止めるのは自分の端末で書き足す分だけで、20,000 本を超えるきっかけ（1.0 の端末は上限なしで書ける・電波の無い所で 2 台が書き足す・取り込み）は止められない。超えたときに線を失わないための手は **1.1 の読む上限を 60,000 本に上げること**（§1.3、§5.1）。取り込みで 20,000 本を超えるページがあるときは確かめる（§5.2） |
| 0-17 | 「いちばん線の多いページ」の数え方 | 設定を開いたときに **バックグラウンドで全ページを数える**。`InkPageStore.load` は読めないファイルを `.bak` へ移すので使わず、副作用の無い `InkPageStore.peek(_:)`（伸長して JSON の `strokes` と `deleted` のキーを数えるだけ。読む上限で切り詰める前の数）を使う。数え終わるまで「数えています…」 |
| 0-18 | 互換テストの CI の 1.0 | **コミット a21e4692109e504701b507ad9c695181fdecddfd を SHA で checkout**（タグは今は無い。`v1.0` の push は公開の操作なので本人の返事を待つ、M7A-8） |
| 0-19 | 規約 第 2 条（iPhone は「補助的な利用」、`docs/TERMS.md:19-20`） | 言い回しではなく中身の変更なので §9 で本人に見せる。既定は iPad と iPhone を並べて書き直す（M7A-5） |
| 0-20 | App Store の写真（`store/`）と 1.0.1 の写真との比べ方 | 広げたツールバーには常に右端の区切りと「しまう」が付く（§2.2）ので、**ツールバーの帯（下の安全領域 ＋ 66 pt）は全部の写真で 1.0.1 と違ってよい**。比べるときはこの帯を除く（§8 の 3）。帯の外で違ってよいのは、新しい写真・設定と同期のシート・`store/ipad13/06-settings`（入力の行が増える。App Store には上げていない、M6-24）・ステータスバーの日付・日の写真の下端 3 px（24 時の区切り線）だけ。月の紙は 0-1 で同じ絵。App Store に上げてある写真（しまうボタンが写っていない）を差し替えるかは本人に聞く（M7A-11。既定は差し替えない） |
| 0-21 | 指で点を消す候補（`dotStrokeIds` は `stroke.t >= cutoff`、`InkCanvasView.swift:1145-1160`。t は書いた端末の時計） | 1.1 は月の日付・年の左端の数字でも点を消すので、時計の進んだ別の端末（1.0 を含む）から届いた直後の小さな線に墓標を付けうる。**候補は、このキャンバスの `applyCanvasChange` が自分で足した線だけ**（端末の単調な時計で記録、§4.1） |
| 0-22 | 消しゴムのまま日付を指でタップ（「指でも書く」オン） | タップの下の線が墓標付きで消え、そのままページを離れるので気付けない（墓標は 1.0 にも届く）。**移る前に、そのタップの触れ方で消した分を取り消す**（§2.4。取り消しで戻る線は新しい id の写し） |
| 0-23 | fixture の作り手と持ち主 | `TegakiKit/Tests/Fixtures/compat11/` の中でも、`screenshot-*.json` は U のテスト、`ledger-*.json` は P のテストだけが作る（持ち主もそれぞれ）。K の書き出し（`--write-compat-fixtures`）と K の fixture のテストはこの 2 種を書かない・消さない・比べない（読むのは Compat10 の確かめだけ） |

## 0. 構成とファイル所有

```
TegakiKit/                                                  担当 K（TegakiKit/・tools/compat10/・tools/typecheck/typecheck.sh の手順 6 だけ）
  Package.swift                                             変更: Compat10 / CompatFixtures / Compat10Tests、KitChecks の依存（§1.4）
  Sources/Layout/PaperSpec.swift                            変更: growStep・growMax・dayExtraMin、CellKey.extra・isExtra（§3.1）
  Sources/Layout/PaperGrowth.swift                          新規: 最後のマスの高さ・伸ばす判定・上限の判定・捨てる判定・高さだけの判定（§3.1、§3.4、§3.6）
  Sources/Layout/PageLayout.swift                           変更: PageBand.extra（§3.3）
  Sources/Layout/MonthLayoutEngine.swift                    変更: memoHeight → PaperGrowth.tailHeight（§3.2）
  Sources/Layout/MonthPageLayout.swift                      変更: hit(at:minTarget:)（§4.2）
  Sources/Layout/DayLayoutEngine.swift                      変更: extra、startsBelowDay（§3.3）
  Sources/Layout/YearLayoutEngine.swift                     変更: gutterDay / gutterHit（§4.3）
  Sources/Layout/DateTap.swift                              新規: 指の 1 回タップの規則（§4.1）
  Sources/Layout/ZoomPolicy.swift                           変更: overviewSize に日（§3.5）
  Sources/Layout/PageNavigation.swift                       変更: parse(pageId:)（§5.3）
  Sources/InkModel/InkPage.swift                            変更: maxStrokes 20,000 → 60,000 の 1 行だけ（§5.1）
  Sources/InkModel/WebImport.swift                          変更: :187 を WebImport.maxStrokesPerPage（20,000、挙動は今のまま）に（§5.1）
  Sources/InkModel/StrokeBudget.swift                       新規: K-9（§5）
  Sources/KitChecks/main.swift                              変更: 4 節と既存の数行（§7.1）、--write-compat-fixtures [--out]
  Tests/LayoutTests/*、Tests/InkModelTests/StrokeBudgetTests.swift   変更・新規（§7.2）
  Tests/Compat10/ ・ Tests/CompatFixtures/ ・ Tests/Compat10Tests/   新規（§1.4）
  Tests/Fixtures/compat11/                                  新規。K: 下の 2 種を除く全部と digests.json。screenshot-*.json は U、ledger-*.json は P（0-23）
tools/compat10/                                             担当 K   新規: 本物の 1.0 で同じ確かめを走らせる package、AppTests/Real10LedgerTests.swift、EXPECTED_MIN（§1.4）
tools/typecheck/typecheck.sh                                担当 K   変更: 手順 6（§1.4）
Sources/TegakiCalendar/
  Views/ToolbarView.swift                                   担当 T   変更: しまうボタン、消しゴムの説明、Kind を ToolbarLogic へ、rememberedPen（§2.2、§2.3）
  Views/ToolbarLogic.swift                                  担当 T   新規: 状態・純関数・記号（§2）
  Views/ToolbarDock.swift                                   担当 T   新規: 丸ボタン（§2.2）
  Persistence/AppSettings.swift                             担当 T   変更: 4 つのキー（§2.3、§2.6、§5.2）
  Ink/InkCanvasView.swift                                   担当 P   変更: 新しい 5 引数、高さだけの経路、applyInsets、消し終わり、上限と予算で捨てる、点の候補、消しゴムのタップ（§2.4、§2.5、§3、§4.1、§5.2）
  Ink/InkLedger.swift                                       担当 P   変更: needsMoreRoom を PaperGrowth へ、adopt(_:)、undoIfTopRestores(ids:)、テスト用の makeId（§2.4、§3.6、§7.2）
  Paper/DayPaper.swift                                      担当 P   変更: 24 時の下の「自由メモ」（§3.3）
  Export/PDFPageRenderer.swift                              担当 P   変更: 日の paperRect（§3.5）
  Views/CalendarRootScreen.swift                            担当 U   変更: 接続（§2.7、§3.7、§4.5、§5.2）、文言 2 か所（§6.1）
  Views/SettingsScreen.swift                                担当 U   変更: 入力の行、情報の行と脚注、文言（§2.6、§5.3、§6.1）
  Views/WebImportSheet.swift                                担当 U   変更: 20,000 本を超えるときの確かめの段（§5.2）
  Views/OnboardingView.swift / Views/AccountChangeDialog.swift / Sync/SyncStatus.swift   担当 U   変更: 文言だけ（§6.1）
  Persistence/StrokeCensus.swift                            担当 U   新規（§5.3）
  Persistence/InkPageStore.swift                            担当 U   変更: peek(_:) を足すだけ（§5.3。load・save は触らない）
  Support/ScreenshotMode.swift                              担当 U   変更: 引数 3 つと sheet `info`（§7.3）
Tests/TegakiCalendarTests/
  ToolbarLogicTests.swift（新規）/ AppSettingsTests.swift                                   担当 T
  InkCanvasViewTests.swift / InkLedgerTests.swift / PaperViewTests.swift / ExportBuilderTests.swift   担当 P
  CalendarRootScreenTests.swift / SettingsScreenTests.swift / ScreenshotModeTests.swift / SyncEngineTests.swift（文言の行と §5.1 の 1 つ）/ StrokeCensusTests.swift（新規）/ WebImportSheetTests.swift（確かめの段）   担当 U
docs/TERMS.md / docs/PRIVACY.md / docs/SUPPORT.md             担当 L（§6.3）
Web リポジトリ（/Users/ikedamasataka/Documents/Codex/tegaki-calendar、ブランチ m7a-legal）   担当 W（§6.4）
project.yml / .github/workflows/build.yml / docs/M7A.md / README.md / docs/DESIGN.md・docs/M7_PLAN.md の注記   担当 C（§7.4、§8）
```

依存の向き: `TegakiCalendar` → `TegakiKit`。`Compat10` は TegakiKit のどのモジュールにも依存しない（Foundation・CoreGraphics・Compression だけ。写す元の `InkStroke.swift`・`InkPage.swift`・`BandMigration.swift` が CoreGraphics を import している）。**1 つのファイルの持ち主は 1 人**。担当 K は `TegakiKit/`（0-23 の 2 種の fixture を除く）・`tools/compat10/`・`tools/typecheck/typecheck.sh` だけ。担当 T は `Views/Toolbar*.swift`・`Persistence/AppSettings.swift`・自分のテストだけ（`CalendarRootScreen` と `SettingsScreen` を触らない）。担当 P は `Ink/*`・`Paper/DayPaper.swift`・`Export/PDFPageRenderer.swift`・`ledger-*.json`・自分のテストだけ。担当 U は上の U の行・`screenshot-*.json`・自分のテストだけ（`Ink/*`・`Paper/*`・`Views/Toolbar*.swift` を触らない）。担当 L は 3 文書だけ。担当 W は Web リポジトリだけ（push しない・merge しない）。担当 C は project.yml・build.yml・docs の注記・README だけ。CI の成果物から fixture を commit するのはリード（中身を見てから。持ち主の担当の名前で記録する）。

**接点（全部この形に固定。新しい引数には既定値を付け、既存の呼び出しが変わらずに通る）**

```swift
// ── K（TegakiKit）────────────────────────────────────────────────
// Layout/PaperSpec.swift（enum PaperSpec の中と CellKey の拡張に足す）
public static let growStep: CGFloat = 400        // 最後のマスの刻み
public static let growMax: CGFloat = 6000        // 最後のマスの上限（K-9）
public static let dayExtraMin: CGFloat = 700     // 日の extra の最小（= memoMin）
public static let extra = CellKey(raw: "extra")  // 日のページの 24 時の下（K-1: allday で始まらない）
public var isExtra: Bool { get }
// Layout/PageLayout.swift
public static let extra = PageBand(raw: "extra") // PageBand に
// Layout/PaperGrowth.swift（新規）
public enum PaperGrowth {
    public static func isTail(_ cell: CellKey) -> Bool                                    // .memo か .extra
    /// b を有限・0 以上に直し、stepped = min(growMax, 700 + 400 × max(0, ceil((b − 300) / 400)))、結果 = max(stepped, b + 50)
    public static func tailHeight(inkBottom: CGFloat) -> CGFloat
    /// 最後のマス: tailHeight(b) > cellHeight + 0.001。ほかのマス: b + 12 > cellHeight + 0.001（今の規則）
    public static func needsMoreRoom(cell: CellKey, cellHeight: CGFloat, inkBottom: CGFloat) -> Bool
    /// 白紙をもう 400 足せない: stepped(b) ≥ growMax（= b > 5,600）。b が有限でない・負なら false（§3.4）
    public static func reachesCap(inkBottom: CGFloat) -> Bool
    public enum Drop: Equatable, Sendable { case outsidePaper, beyondCap }
    /// 新しい線の中心（紙の座標）。beyondCap が先: 最後のマスがあり 0 ≤ x ≤ 幅 かつ y > tail.minY + growMax。
    /// outsidePaper: x < 0・x > 幅・y < 0・y > 高さ（M4C-25 の今の規則）。nil = 残す。有限でない点は outsidePaper
    public static func drop(center: CGPoint, in layout: any PageLayout) -> Drop?
    public static func tail(of layout: any PageLayout) -> (key: CellKey, rect: CGRect)?   // 月 memo・日 extra・他 nil
    public static func onlyTailHeightChanged(old: any PageLayout, new: any PageLayout) -> Bool  // §3.6
}
// Layout/DayLayoutEngine.swift
public var extra: CGRect                          // DayPageLayout に。init の最後の引数 extra:（呼ぶのは :210 だけ）
/// 矩形が 24 時より下で始まる: 有限で、rect.standardized.minY ≥ grid.maxY（2400）。有限でない矩形は false。
/// eventRange(for:) は変えない（§3.3、0-4）
public func startsBelowDay(_ rect: CGRect) -> Bool   // DayPageLayout に
// Layout/MonthPageLayout.swift
public func hit(at point: CGPoint, minTarget: CGFloat) -> HitTarget?                    // §4.2
// Layout/YearLayoutEngine.swift
public func gutterDay(at point: CGPoint, numberOnly: Bool) -> Int?                      // §4.3
public func gutterHit(at point: CGPoint, numberOnly: Bool, month: Int) -> HitTarget?
// Layout/DateTap.swift（新規）
public enum DateTap {
    public static let minPoints: CGFloat = 44
    public static func minTarget(kind: PageKind, zoom: CGFloat, smallScreen: Bool, allowFinger: Bool) -> CGFloat?
    public static func target(layout: any PageLayout, point: CGPoint, zoom: CGFloat,
                              smallScreen: Bool, allowFinger: Bool, currentMonth: Int) -> HitTarget?
}
// Layout/PageNavigation.swift
public static func parse(pageId: String) -> (kind: PageKind, focus: DayKey)?            // §5.3
// InkModel/InkPage.swift: public static let maxStrokes = 60_000（1.0 は 20,000。読む上限だけ。§5.1）
// InkModel/WebImport.swift: public static let maxStrokesPerPage = 20_000（:187 が使う。Web 版の取り込みの挙動は今のまま）
// InkModel/StrokeBudget.swift（新規）
public enum StrokeBudget {
    public static let noticeAt = 15_000
    public static let refuseAt = 19_000
    public static let legacyReadCap = 20_000                                               // 1.0 が読むたびに切り詰める本数（変わらない）
    public static var readCap: Int { InkPage.maxStrokes }                                  // 1.1 が読む上限 60,000
    public enum Event: Equatable, Sendable { case many(Int), full(Int) }
    public static func accepted(incoming: Int, count: Int) -> Int                          // min(incoming, max(0, refuseAt − count))
    public static func crossesNotice(from old: Int, to new: Int) -> Bool                   // old < noticeAt ≤ new
    /// 取り込み: 端末の線の id と取り込むページの線（strokes ＋ unknownStrokes）の id の和集合から、取り込む側の墓標を引いた数。
    /// legacyReadCap を超えるときだけその数、超えなければ nil（§5.2）
    public static func importExceedsLegacyCap(localIds: Set<String>, incoming: InkPage) -> Int?
    public struct Entry: Equatable, Sendable {
        public var pageId: String; public var strokes: Int; public var tombstones: Int
        public init(pageId: String, strokes: Int, tombstones: Int)
    }
    public static func largest(_ entries: [Entry]) -> Entry?                               // §5.3
    public static func pageLabel(_ pageId: String) -> String
    public static func countText(_ n: Int) -> String                                       // 「12,345 本」
}
extension InkPage { public var budgetCount: Int { get } }                                  // liveStrokeCount + unknownStrokes.count

// ── P（Ink/InkCanvasView.swift。新しい引数は tapLeavesPage の後に、この順で）──────────
var onPenDown: () -> Void = {}                                   // §2.1: ペン・書く指が紙に触れた（キャンバス・overlay）
var onEraseEnded: (_ erased: Int) -> Void = { _ in }              // §2.5
var onStrokeBudget: (StrokeBudget.Event) -> Void = { _ in }       // §5.2
var onGrowthCapReached: () -> Void = {}                          // §3.4（捨てたとき・上限に届いたとき）
var bottomClearance: CGFloat = 0                                  // §2.2: 下の inset = max(中央寄せの余白, これ)（pt）
// Coordinator（internal。§4.1）: 1.0.1 の `clock: () -> Date` を次の 2 つに置き換える
var uptime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }   // 端末の単調な時計（テストで固定する）
func noteRecentAdd(_ id: String, at time: TimeInterval)          // 自分で足した線の記録（applyCanvasChange の added から。テストも使う）
// Ink/InkLedger.swift
func adopt(_ layout: any PageLayout)                              // §3.6: 絵を作らずレイアウトだけ差し替える
func needsMoreRoom(_ stroke: InkStroke) -> Bool                   // 中身を PaperGrowth.needsMoreRoom に（growsWithInk の guard は残す）
func undoIfTopRestores(ids: Set<String>) -> PKDrawing?            // §2.4: 取り消しの山の一番上が、ちょうどその id の線を戻す op のときだけ undo
var makeId: () -> String = { InkStroke.newId() }                  // テストで id と時刻を種から決めるため（§7.2 testLedgerWritesTheCompatShapes）。
var nowMs: () -> Int = { InkLedger.wallClockMs() }                //   makeInkStroke・moveStrokes（translated の id: と at:）・perform・removeStrokes が使う。既定の動きは今と同じ

// ── T ──────────────────────────────────────────────────────────
// Views/ToolbarLogic.swift（新規）
enum ToolbarMode: String, Equatable, Sendable { case expanded, collapsed, peek }
enum ToolbarEdge: String, Equatable, Sendable { case leading, trailing }
enum EraserOrigin: Equatable, Sendable { case toolbar, pencil }
enum ToolKind: Equatable, Sendable { case pen, marker, eraser, lasso, eventRect }
struct ToolBadge: Equatable { var symbol: String?; var colorHex: String?; var dotDiameter: CGFloat?; var accessibilityValue: String }
enum ToolbarLogic {
    static let barHeight: CGFloat = 60           // 44 + 8 × 2
    static let pillHeight: CGFloat = 48
    static let sidePadding: CGFloat = 12
    static let bottomPadding: CGFloat = 6
    static func kind(of tool: CanvasTool) -> ToolKind                       // 今の ToolbarView.Kind（:25-40）を移す
    static func startMode(collapsedStored: Bool) -> ToolbarMode             // true → .collapsed、false → .expanded
    static func modeAfterPenDown(_ mode: ToolbarMode) -> ToolbarMode        // .peek → .collapsed、他はそのまま
    static func toastBottomPadding(_ mode: ToolbarMode) -> CGFloat         // expanded 8・collapsed 62・peek 74
    static func paperBottomClearance(_ mode: ToolbarMode) -> CGFloat       // expanded 0・collapsed 60・peek 60
    static func toolAfterErase(origin: EraserOrigin?, erased: Int, setting: Bool, current: CanvasTool, lastInk: CanvasTool) -> CanvasTool?
    static func eraserHint(returnsTo: CanvasTool?) -> String                // §6.2
    static func badge(for tool: CanvasTool) -> ToolBadge                    // §2.2
}
extension ToolbarPalette {
    static func rememberedPen(_ defaults: UserDefaults) -> InkStyle          // §2.3
    static func colorName(_ hex: String) -> String                           // 表に無い色は「その他の色」
}
// Views/ToolbarView.swift（新しい引数は onRedo の後に）
var showsCollapseButton: Bool = false
var onCollapse: () -> Void = {}
var eraserReturnsTo: CanvasTool? = nil                                       // 消しゴムの説明の括弧（§2.4）
// Views/ToolbarDock.swift（新規）
struct ToolbarDock: View {
    var tool: CanvasTool; var canUndo: Bool; var edge: ToolbarEdge
    var onExpand: () -> Void; var onUndo: () -> Void; var onMoveEdge: () -> Void; var onPin: () -> Void
}
// Persistence/AppSettings.swift
static let toolbarCollapsedKey = "toolbar.collapsed"        // Bool、無ければ false（広げた状態）
static let toolbarEdgeKey = "toolbar.collapsedEdge"         // "leading" / "trailing"、無い・ほかの値は leading
static let eraserAutoReturnKey = "eraserAutoReturn"         // Bool、無ければ true
static let strokeBudgetNoticedKey = "strokeBudget.noticedPages"   // [String]（案内したページ id。最大 500 件、古い方から捨てる）
static var toolbarCollapsed: Bool; static var toolbarEdge: ToolbarEdge; static var eraserAutoReturn: Bool
static func strokeBudgetNoticed(_ pageId: String) -> Bool
static func markStrokeBudgetNoticed(_ pageId: String)

// ── U ──────────────────────────────────────────────────────────
static func tapTarget(layout: any PageLayout, point: CGPoint, zoom: CGFloat,
                      smallScreen: Bool, allowFinger: Bool, currentMonth: Int) -> HitTarget?   // = DateTap.target（名前は 1.0.1 のまま）
enum StrokeCensus {                                         // Persistence/StrokeCensus.swift（新規）
    struct Result: Equatable { var largest: StrokeBudget.Entry?; var year: StrokeBudget.Entry?; var unreadable: Int }
    static func run(store: InkPageStore, year: Int) async -> Result?          // 取り消されたら nil（§5.3）
    static func demo(year: Int) -> Result
    static func rowText(_ entry: StrokeBudget.Entry?, counting: Bool) -> String   // いちばん線の多いページ
    static func yearRowText(_ entry: StrokeBudget.Entry?, year: Int, counting: Bool) -> String   // 今年の年のページ
    static func pagesOverLegacyCap(_ pages: [InkPage], store: InkPageStore) async -> [String]   // §5.2 取り込みの確かめ（pageId の一覧）
}
extension InkPageStore {                                    // Persistence/InkPageStore.swift（U が足すだけ）
    struct Peek: Equatable { var strokeIds: Set<String>; var tombstones: Int }
    /// 読む・伸長する・JSONValue にして strokes のキー（配列の形なら各要素の id）と deleted のキーを数えるだけ。
    /// InkPage を作らない（読む上限で切り詰めない）。ファイルが無い・読めないときは nil で、移さない・消さない
    func peek(_ pageId: String) -> Peek?
}
// Views/WebImportSheet.swift: WebImportPhase に case confirmLarge(pages: [String])（§5.2）
// Support/ScreenshotMode.swift: Config.toolbar: ToolbarShot?（collapsed / collapsedRight）、Config.tool: ToolShot?（eraser / marker / lasso / event）、
//                               Config.grown: Bool、Sheet.info（9 つ目）
```

## 1. データ互換（K-1〜K-9）と互換テスト（K-7）

本人は iPad と iPhone で使っている。片方が 1.0.x、もう片方が 1.1 という時期が必ずある。**どちらの端末も、相手の手書きを消したり動かしたりしてはいけない。** データの部分（`TegakiKit/Sources/InkModel`・`Sync`・`Persistence`・`Export`・`Ink/InkLedger.swift`）は 1.0 と 1.0.1 で 1 行も違わない（`InkPage.swift` の sha256 はどちらも `32f29ca4…6675`）。335aade〜a21e469 の 7 コミットもソースは同じなので、1.0 = a21e469 とみなしてよい。

### 1.1 1.0 の端末が実際にすること（計画 F1〜F11 の再確認と F12〜F14 の追加。行は 1.0.1）

| F | 事実 | 1.0.1 の行 |
| --- | --- | --- |
| F1 | 知らないマスの線は描かず、指紋表にも入れず、消された扱いにしない。消しゴム・投げなわ（候補は `cells[stroke.cell]` がある線だけ）・指の点消し・PDF も同じ | `Ink/InkLedger.swift:217-235`（:225 で continue）、`InkCanvasView.swift` の投げなわの候補と `dotStrokeIds`、`Ink/InkSnapshot.swift:25, 66`。1.0 の日のマスは `[.grid]` だけ（`DayLayoutEngine.swift:218`） |
| F2 | 知らないページ id も同期・保存・書き出し・取り込みで運ぶ | `Sync/SyncEngine.swift:136-158, 625-653`、`InkPageRecord.swift:32`、`InkPageStore.swift:30-33`、`AppExport.swift:127-132` |
| F3 | `w-` / `d-` のページの `allday` と `allday:…` だけを `grid` へ移す（`allday2`・`band`・`extra`・`focus` は動かない。実測） | `BandMigration.swift:14-19, 34, 40`。呼ぶ所は `CalendarRootScreen.swift:809, 885, 1364`、`InkLedger.swift:178, 205`、`ExportBuilder.swift:127, 182`、`AppExport.swift:131` |
| F4 | 同じ id の線が 2 つの形で出会うと t → tool → color → マス名（辞書順で大きい方）→ dev → 点。墓標は常に勝つ。`"grid" > "extra"` | `InkPage.swift:149-171, 207-225` |
| F5 | 1 ページの絵はそのページのキャンバスが丸ごと書き換える | `pageBinding` `CalendarRootScreen.swift:663-672` |
| F6 | 月のメモ欄は `max(700, 下端 + 50)`。**上限が無い** | `MonthLayoutEngine.swift:23-26`、`PaperSpec.swift:24-25`、伸ばす判定 `InkLedger.swift:321-325` |
| F7 | 「この iPad の手書きを全て消す」は端末と iCloud の全ページ（知らないページも）を消す | `SyncEngine.swift:282-306`、`InkPageStore.swift:99-108` |
| F8 | 読むたび（`init(json:)` だけ）に線は **strokes ＋ unknownStrokes の合計** 20,000 本まで（キーの辞書順で前から残す。決まっている。id は無作為な UUID なので、捨てられるのは古い線も含めた無作為な線で、墓標は付かない）、墓標は 200,000 件まで（Swift の辞書の順で、起動ごとに残る組が変わる）。`merge` には上限が無い。`SyncEngine.save`（:139）は切り詰めた `store.load` を土台に merge し、送信（:697 `var page = store.load(id)`）も切り詰めた中身を送る。同じ id の順で切るので、どの 1.0 の端末も同じ線を捨てる | `InkPage.swift:14-15, 275-279, 285, 318` |
| F9 | 保存のたびにページ全体を JSON ＋ lzfse、iCloud へは丸ごと | `InkPageStore.swift:81-87`、`InkPageCodec.swift:16-18` |
| F10 | 組み直しのたびに全部の線から PKDrawing を作り直す | `InkCanvasView.swift:650-656`（`setDrawing(ledger.relayout(...))`）、`sameGeometry` `PageLayout.swift:150-152` |
| F11 | 線の中の知らない項目は読むときに捨てる（最上位の知らない項目と知らない tool の線は残す） | `InkStroke.swift:176-203` |
| F12（新） | 1.0 は利用者が何もしなくてもページを書き直して送ることがある: 起動時に記録の無いページ（`SyncEngine.swift:191`）、zone を失ったときの全ページ（:544）、`mergeRemote` で端末にしか無い id（:641-643）、送信の衝突（:722-731）、ページを開いて `BandMigration` で中身が変わったとき（`CalendarRootScreen.swift:809-813, 1364-1368`）。**1.1 のページを表示しただけ** なら、`allday` を含まず 20,000 本以下である限り書き直さない | 同左 |
| F13（新） | 重さ（この Mac の M1・release、1 本 40 点の合成）: 1,000 本 JSON 1.59 MB / lzfse 0.15 MB / 読み込み 0.21 秒、15,000 本 23.9 MB / 2.04 MB / 3.20 秒、20,000 本 31.8 MB / 2.72 MB / 4.25 秒。ページを開く `sync.load` はメインスレッド、保存（ペンを離して 1.5 秒後）のたびに読み直して merge | `CalendarRootScreen.swift:802`、`SyncEngine.swift:139` |
| F14（新） | 墓標は消されずに増える（消しゴム、投げなわの移動 1 本につき 1 件 `InkLedger.swift:463`、指の点消し）。200,000 件を超えると残る組が起動ごとに変わり、消した線が戻りうる | 同左 |

### 1.2 守る規則 K-1〜K-9（計画 §1.3 の写し）と、この版での当てはめ

- **K-1** 新しいマス名・ページ id に `allday` で始まる名前を使わない。→ 1.1 の新しい名前は **マス `extra` だけ**（ページ id は増えない）。KitChecks と XCTest で `BandMigration.isBandCell(.extra) == false` と `!"extra".hasPrefix("allday")` を固定する。
- **K-2** 既存の線を同じ id のまま別のマスへ付け替えない。→ `grid` の線は y > 2,400 にあっても `grid` のまま（Web 版から取り込んだ深い線。`WebImport.swift:365-366` の `.day → .grid` は変えない。1.1 では `extra` の場所に重なって見えるが、消す・投げなわは今まで通り効く）。投げなわで `grid` ⇄ `extra` を動かすと新しい id ＋ 元に墓標（`InkLedger.swift:444-472`）なので守れる。ただしその結果、**24 時の下へ動かした線は 1.0 の端末から見えなくなる**（元は墓標で消え、新しい `extra` の線は描かれない）。中心が 24 時より下になる新しい線（23 時台から下へはみ出す字を含む）も同じ。§1.3 の表・SUPPORT の FAQ に書き、Compat10 の確かめで固定する。
- **K-3** 1 つのページ id に 2 枚のキャンバスで書かない。→ 1.1 はキャンバス 1 枚のまま。
- **K-4** 既存のマスの意味（マスの左上からの相対座標）を変えない。位置は動かしてよい。→ `grid`・`timeline`・`memo`（日の右の列）は (0, 0)〜2,400 のまま。月の `memo` の原点も変わらない。
- **K-5** 線に新しい項目を足さない。InkPage の `v` と `tegaki-app-export` v1 は上げない。→ 1.1 は線にもページにも項目を足さない。欄の高さは保存せず、毎回手書きの下端から計算する。
- **K-6** 伸びる紙の一覧（fitAll）の矩形は固定部分に限る。→ 月は今のまま 1400 × `memo.minY`、**日を 1000 × 2400 に**（`ZoomPolicy.overviewSize`、:61-66）。
- **K-7** 互換テストは 1.0 のコードで走らせる。→ §1.4（凍結した写し・本物の 1.0 の TegakiKit・本物の 1.0 のアプリの台帳と同期の 3 つで同じ fixture を確かめる）。
- **K-8** 1.0 の端末では新しい欄の手書きが見えない（消えてはいない）。→「このバージョンの新機能」に「両方をこの版に」の 1 行（§6.5）。SUPPORT の FAQ にも書く（§6.3。24 時の近くに書いた線・投げなわで 24 時の下へ動かした線も含める）。
- **K-9** 1 ページの線の予算。→ §5（15,000 本で案内、19,000 本で受け付けない、伸びる欄は 6,000 lu まで、情報欄に「いちばん線の多いページ」と「今年の年のページ」）。**計画の「1.0 も同じ上限で読むので、上限を上げる意味はない」は直す**: 1.0 の端末は切り詰めたまま書き戻して送るが、1.1 の端末が全部を持っていれば和集合に戻して送り直せる。上げないと、20,000 本を超えたページの線はどの端末からも墓標なしで消える（F8）。そこで 1.1 は **読む上限を 60,000 本に上げる**（保存の形式・`v` は変えないので K-5 の外。予算の 19,000 は変えない）。C が M7_PLAN §1.3 の K-9 に注記する。

### 1.3 変更ごとの 1.0 の端末での見え方

| 変更 | 新しい名前 | 1.0.x の端末で | 気をつけること |
| --- | --- | --- | --- |
| 月のメモ欄の白紙（400 lu 刻み・上限 6,000） | なし | **全部見える**。1.0 の欄は `max(700, b + 50)` で上限が無く、1.1 の欄はどの b でも `b + 50` 以上なので、1.1 で書いた一番下の線まで 1.0 で描ける（欄が最大 800 lu 短いだけ）。1.0 で組み直すと全部の線を作り直す（F10） | 1.0 や Web 版の取り込み（`WebImport.swift:359-361`。メモは上限なし）から 6,000 より下の線が来たら、1.1 はその線が見える高さ（`b + 50`）まで伸ばす。新しい線だけを 6,000 で止める（0-5） |
| 日の 24 時の下の欄（自由メモ） | `d-` ページのマス `extra` | **見えない・消せない・残る**。読む（`CellKey(raw:)` は何でも受ける）・`BandMigration` は触らない・描かない・消しゴム／投げなわ／指の点消し／「予定にする」／取り消しは届かない・保存と送信で id・マス・点が変わらない（一度読んで書き戻した JSON は元と 1 バイトも違わない。実測）・書き出しで運ぶ・1.0 の PDF には出ない。**1.0 の「全て消す」では消える**（F7。全部のページを消すため）。**1.1 で中心が 24 時より下になる線を書いたとき（23 時台から下へはみ出す字も）と、`grid` の線を投げなわで 24 時の下へ動かしたとき（新しい id の `extra` の線 ＋ 元に墓標、`InkLedger.swift:444-472`）も、その線は 1.0 の端末から見えなくなる**（消えてはいない） | 新機能の文に「両方をこの版に」（K-8）。SUPPORT の FAQ に「24 時の近くに書いた線や、投げなわで 24 時の下へ動かした線も、古い版では見えません（消えてはいません）」 |
| 1 ページの線が 20,000 本を超えたとき（予算 19,000・読む上限 60,000） | なし（数字だけ） | 1.0 は自分では上限なしで書けるが、読むたびに 20,000 本へ切り詰める（F8。捨てるのは id の辞書順で後ろの無作為な線で、墓標は付かない）。編集すると切り詰めた中身を保存・送信する。**1.1 は 60,000 本まで読むので全部を持ち続け**、1.0 から切り詰めた版が届くと `mergeRemote` が和集合を作り、遠隔の版と違うので印を付けて（`SyncEngine.swift:646` `markDirty`）送り直す。**1.1 の端末に一度届いた線は失われない**（1.0 の端末の画面では 20,000 本を超えた分が見えないまま。1.0 の端末だけで 20,000 本を超えて書いた分は、送信の前に読み直す `store.load` で切り詰められるので 1.1 にも届かない。これは 1.0 の動きで 1.1 では直せない） | 1.1 は自分では 19,000 本で止める。取り込みで 20,000 本を超えるページがあれば確かめる（§5.2）。情報欄は切り詰める前の本数を出し、20,000 本を超えたら「古い版の端末では一部が表示されません」（§5.3） |
| ツールバー・消しゴム・日付の当たり | なし（端末の UserDefaults だけ） | 影響なし | — |
| 年の左端の数字・月の日付のタップで点を消す | なし（墓標だけ。1.0.1 と同じ M4C-22 の仕組み） | 墓標なので 1.0 でも消える。**候補はこの端末のこのキャンバスで直前に書いた線だけ**（0-21）なので、相手の端末の線には墓標を付けない | F14（墓標が増える） |
| 消しゴムのまま日付を指でタップ | なし | そのタップで消した線は、移る前に取り消す（新しい id の写しとして戻る。元の id の墓標は残り、1.0 には写しが届く） | §2.4 |

### 1.4 互換テスト K-7 の形（担当 K。fixture の一部は P・U、CI の追加は C）

**パッケージ**（`TegakiKit/Package.swift` に足す）:

```swift
.target(name: "Compat10", path: "Tests/Compat10",
        exclude: ["FROZEN.sha256", "ORIGIN.sha256", "ORIGIN.ranges"]),   // 1.0 の凍結した写し。Foundation・CoreGraphics・Compression だけ。product にしない
.target(name: "CompatFixtures", dependencies: ["InkModel", "Layout"], path: "Tests/CompatFixtures"),   // 新しいコードで fixture を作る
.testTarget(name: "Compat10Tests", dependencies: ["Compat10", "CompatFixtures", "InkModel", "Layout"], path: "Tests/Compat10Tests"),
// KitChecks の依存に "Compat10" と "CompatFixtures" を足す
```

product にしないのでアプリ（`project.yml` は product だけを使う）には入らない。Compat10 は DayKit・Layout・InkModel に **依存させない**（依存すると新しい版の変更が凍結した写しに流れ込む）。`exclude` が無いと、ターゲットの中の `.sha256` などに SwiftPM が「unhandled file」の警告を出す。fixture は `#filePath` から位置を出して読む（resources・`Bundle.module` を使わない。macOS の `swift test`、KitChecks、シミュレータのアプリのテストで同じ読み方）。

**`tools/typecheck/typecheck.sh` の手順 6**（:120-145、K）: `emitmac Compat10 $(find "$REPO/TegakiKit/Tests/Compat10" -name '*.swift' | sort)`（`Checks/` も含める。今の `"$t"*.swift` は下の階層を見ないので使わない）と、InkModel の後に `emitmac CompatFixtures $(find "$REPO/TegakiKit/Tests/CompatFixtures" -name '*.swift' | sort)`。:135 のループは `Compat10`・`CompatFixtures`・`Fixtures` を飛ばし（`Fixtures` には .swift が無く、glob がそのまま swiftc に渡って失敗する）、ほかのディレクトリのファイルも `find "$t" -name '*.swift' | sort` で集める（アプリのテストの手順 :106-118 と同じ形）。

**凍結する写し**（`TegakiKit/Tests/Compat10/`。元は a21e469。型名に `V10` を付ける機械的な置き換えと import の削除のほかは変えない。**型の名前の付け方・入れ物（どの enum の中か）・public かどうかは本物と同じ**にする。RunReal で本物に別名を向けたとき、同じ呼び方で通るようにするため。以後は誰も変えない）:

| 写し | 元 | 中身 |
| --- | --- | --- |
| `JSONValueV10.swift` | `InkModel/JSONValue.swift`（252 行） | 読み込みと並べた書き出しをそのまま |
| `InkStrokeV10.swift` | `InkModel/InkStroke.swift`（299 行） | `InkPointV10`・`InkToolV10`・`InkStrokeV10`・`StrokeFingerprintV10`。`@_exported import Layout` を消す |
| `InkPageV10.swift` | `InkModel/InkPage.swift`（359 行） | 上限 20,000 / 200,000、`merge`、`compareStrokes` |
| `InkPageCodecV10.swift` / `BandMigrationV10.swift` | `InkPageCodec.swift`（85 行）/ `BandMigration.swift`（74 行） | そのまま |
| `CellKeyV10.swift` | `Layout/PaperSpec.swift:114-200` ＋ 週の定数 | `CellKeyV10`、`PaperSpecV10`（weekWidth 1400・weekGutter 64・weekColumns 7・weekColumnWidth だけ） |
| `DayKeyV10.swift` | `DayKit/DayKey.swift` の一部 | `init(year:month:day:)`・`init?(ymd:)`・`isValid`・`dayNumber`・`weekday`・`adding(days:)`・`daysInMonth` |
| `WebImportV10.swift` | `InkModel/WebImport.swift:31-35` と `:165-169`、それが使う `supportedVersion` | `public enum WebImportV10 { public enum ParseError …; static func versionNumber(_:) … }`（`versionNumber` は本物と同じく internal） |
| `AppExportV10.swift` | `InkModel/AppExport.swift:16-132` | `format`・`parse(json:)`（`WebImportV10.ParseError` を投げる）・`parsePage`・`isWorthExporting`・`encode` |
| `LedgerV10.swift` | アプリのコードを純粋な関数に写したもの | `drawnIds(page:cells:)`（`InkLedger.swift:217-235` の条件と順番。消せる線も同じ組）、`lassoCandidates`、`dotCandidates`、`needsMoreRoom`（:321-325）、`displayWouldSave(loaded:)`（`CalendarRootScreen.swift:809-813`）、`applyRemoteWouldSave`（:885-891）、`mergeRemoteOutcome(local:remote:)`（`SyncEngine.swift:633-646`）。各関数の上に元の範囲を `// a21e469 Sources/TegakiCalendar/Ink/InkLedger.swift:217-235` の形で書く（`ORIGIN.ranges` と同じ） |
| `LayoutFactsV10.swift` | 手で書いた 1.0 のレイアウトの事実 | `cellsV10(pageId:)`（日・週 `{grid}`、月は月曜始まりの 42 日 ＋ `memo`、年は 372 個の `MM-DD`）、`memoHeightV10(_ b:) = max(700, b + 50)`。**RunFrozen と Compat10Tests だけが使う**。RunReal は同じ名前の関数を本物の 1.0 の Layout から作る（下）ので、手書きが本物とずれれば RunReal と RunFrozen の結果がずれる |
| `Checks/Compat10Checks.swift` | 新規 | `public enum Compat10Checks { public static func run(fixtures: URL, report: (String, Bool) -> Void) -> (passed: Int, failed: Int) }`。下の表の確かめを全部。**V10 の名前の public な API だけを呼ぶ**（`AppExportV10.parse(json:)`・`parsePage`・`encode`・`isWorthExporting`・`WebImportV10.ParseError` など。`versionNumber` のような internal は呼ばない。RunReal では別のモジュールの本物になるため） |
| `FROZEN.sha256` | — | 上の写し（`Checks/` を除き、`LayoutFactsV10.swift` を含む）の sha256 **だけ**。`shasum -c` の形（`<sha256>  <ファイル名>`）。KitChecks・`Compat10FrozenSourceTests`・CI の「Frozen 1.0 copy」が読むのはこれだけ |
| `ORIGIN.sha256` | — | 元にしたファイル全部の a21e469 での sha256（パスはリポジトリの根から。`TegakiKit/Sources/InkModel/InkPage.swift`、`Sources/TegakiCalendar/Ink/InkLedger.swift` など）。compat-v1.0 のジョブが v10/ を取り出した後に `(cd v10 && shasum -a 256 -c ../TegakiKit/Tests/Compat10/ORIGIN.sha256)` で照合する |
| `ORIGIN.ranges` | — | 一部だけ写したものと `LedgerV10` の各関数の元の範囲。1 行に `<sha256>  <パス>:<始め>-<終わり>  <写しの名前>`（例 `… Sources/TegakiCalendar/Ink/InkLedger.swift:217-235  LedgerV10.drawnIds`）。sha256 は `git show a21e469:<パス> \| sed -n '<始め>,<終わり>p' \| shasum -a 256`。compat-v1.0 のジョブが同じ計算で照合する（範囲の書き間違いを見つける） |

**golden fixture**（`TegakiKit/Tests/Fixtures/compat11/`。K の分は `CompatFixtures.make()` が新しいレイアウトの `inkCell(forCenter:)` でマスを決める。id は種から作る小文字の UUID の形、t = 1,790,000,000,000 + n。大きいものは毎回同じに作り直し、`digests.json` に sha256 だけを入れる。作り手と持ち主は 0-23）:

| ファイル | 作り手 | 中身 | 1.0 の写しで確かめること |
| --- | --- | --- | --- |
| `d-2026-11-02.json` | K | `grid` 6 本（y 700〜2,350）、`extra` 8 本（相対 y 30〜5,950）、`extra` の知らない tool（`"tape"`）1 本、墓標 3 件 | 描く・消せる・投げなわの候補は `grid` の 6 本だけ。`extra` は 1 バイトも変わらない。付け替えなし。表示しても保存しない（`displayWouldSave == false`）。1.1 の extra の高さ 6,005（= 5,955 + 50） |
| `d-2026-11-02.from10.json` | K | 1.0 の写しで `grid` に 2 本足し、1.1 の `grid` 1 本に墓標 | 両方の順で merge して同じ。結果 `grid` 7・`extra` 8・知らない線 1。新しい `merge` と 1 バイトも違わない |
| `d-2026-11-04.moved.json` | K | `grid` の線 1 本を投げなわで 24 時の下へ動かした形（元の id に墓標、新しい id の `extra` の線。点は `InkStroke.translated` と同じ計算）、ほかに `grid` 2 本 | 1.0 の写しでは動かした線はどこにも描かれない（元は墓標、写しは知らないマス）。描くのは `grid` の 2 本だけ。`extra` の線は 1 バイトも変わらない |
| `m1-2026-11.json` | K | メモの下端 380 / 790 / 3,190 / 5,590 / 5,990、日のマス 4 本 | 1.0 のメモ 6,040 で全部描く。1.1 のメモも 6,040（`b + 50` が勝つ） |
| `m1-2026-12.from10.json` | K | 1.0 の写し（Web 版の取り込みの形）でメモの下端 6,420 | 1.1 の欄 6,470。相対 6,100 に中心がある **新しい** 線は `beyondCap` |
| `w-2026-11-02.legacy.json` | K | `allday:2026-11-04` の線 1 本（x0 = 10） | 1.0 でも新しいコードでも `grid` へ移り x0 = 455.714（10 + 64 + 2 × 190.857）、id はそのまま |
| `y-2026.n15000`（作り直し） | K | 2 点の線 15,000 本を 372 マスに | 全部残る。`budgetCount == 15,000` |
| `y-2026.n20500`（作り直し） | K | 線 20,300 本 ＋ 知らない tool 200 本 | 1.0 の写しで残るのは辞書順で前の 20,000 本（知らない線も数える）。**1.1 は全部読む**（`budgetCount == 20,500`）。1.0 の写しで読んで書き戻した JSON を 1.1 で読み、元の 1.1 のページと merge すると 20,500 本に戻り、墓標は 0 件 |
| `y-2026.tomb200500`（作り直し） | K | 墓標 200,500 件 | 残るのは 200,000 件で元の部分集合（どれが残るかは確かめない）。線 0 本 |
| `export-1.1.json` | K | `tegaki-app-export` v1、d・m1・w の 3 ページ、`app` は `"ios/1.1 (N)"` | `AppExportV10.parse` が 3 ページで各ページが上の fixture と `==`。1.0 の写しで書き出し直すと新しい `AppExport.encode` と 1 バイトも違わない |
| `ledger-day.json` / `ledger-month.json` | **P**（§7.2 `testLedgerWritesTheCompatShapes` が、アプリの台帳が線を書く本当の経路 `InkLedger.makeInkStroke` → 1.1 の `inkCell` → `StrokeGeometry.cellRelativePoints` で作る） | 日: 紙の y 2,430〜8,350 の線（`extra`）、23 時台の線（`grid`）、`grid` から 24 時の下へ動かした 1 本。月: メモ欄の深い位置の線 | 上の d-・m1- と同じ確かめ（1.0 が描くのは `grid`・日のマス・`memo` だけ、`extra` は変わらない、付け替えなし、線の項目は既知のものだけ） |
| `screenshot-{day,week,month,year}.json` ＋ `-grown` の 2 つ | **U**（§7.2 `testDemoPagesMatchCompatFixtures`） | 写真モードのお手本のページ | 上と同じ |

全部の 1.1 の fixture で、K-1（どのマス名も `BandMigrationV10.isBandCell` に当たらない。legacy を除く）と K-5（最上位の項目と線の中の項目が既知のものだけ）も確かめる。`Compat10Checks` はフォルダの `*.json`（`digests.json` を除く）を全部確かめ、`digests.json` に載っている大きな fixture が **見つからない・sha256 が違うときは失敗として数える**（飛ばさない）。P・U の fixture は、commit されるまではフォルダに無いだけ（その間は P・U のテストが赤になる、§8 の 3）。

**K の書き出し**: `swift run --package-path TegakiKit KitChecks --write-compat-fixtures [--out <フォルダ>]`（既定は `TegakiKit/Tests/Fixtures/compat11/`）。K の fixture（小さいものと大きいもの）と `digests.json` だけを書く。`screenshot-*`・`ledger-*` は書かない・消さない。`Compat10FixtureTests.testFixturesAreWhatTheNewCodeWrites` も K の分だけを比べる（`TEGAKI_UPDATE_FIXTURES=1` のときだけ書き直す）。

**本物の 1.0 の TegakiKit で走らせる**（`tools/compat10/`、K）: `Package.swift` に 2 つの実行ターゲット。

- **`RunReal`** は `.package(path: "../../v10/TegakiKit")`（a21e469 の TegakiKit）の products `InkModel`・`Layout`・`DayKit` に依存し、`Aliases.swift` と、CI がコピーする `Copied-Compat10Checks.swift`・`Copied-LedgerV10.swift` を持つ。`Aliases.swift` は、写しと同じ名前を本物に向ける別名 13 個 — `typealias JSONValueV10 = InkModel.JSONValue`、`InkPointV10 = InkModel.InkPoint`、`InkToolV10 = InkModel.InkTool`、`InkStrokeV10 = InkModel.InkStroke`、`StrokeFingerprintV10 = InkModel.StrokeFingerprint`、`InkPageV10 = InkModel.InkPage`、`InkPageCodecV10 = InkModel.InkPageCodec`、`BandMigrationV10 = InkModel.BandMigration`、`CellKeyV10 = Layout.CellKey`、`PaperSpecV10 = Layout.PaperSpec`、`DayKeyV10 = DayKit.DayKey`、`AppExportV10 = InkModel.AppExport`、`WebImportV10 = InkModel.WebImport` — と、**本物の 1.0 の Layout から作る** `cellsV10(pageId:)`（pageId を読み、a21e469 の `DayLayoutEngine`・`WeekLayoutEngine`・`MonthLayoutEngine`・`YearLayoutEngine` で予定なし・手書きなしのレイアウトを作り、その `cells.keys`）と `memoHeightV10(_:)`（= a21e469 の `MonthLayoutEngine.memoHeight(inkBottom:)`）。`LayoutFactsV10.swift` はコピーしない。
- **`RunFrozen`** は凍結した写しのコピー（`LayoutFactsV10.swift` を含む）と Checks だけ。

どちらも `compat10: N checks, F failed` を出す。CI は **両方の N が等しく、F が 0、N が `tools/compat10/EXPECTED_MIN` 以上** を確かめる（写し間違いがあれば N か F がずれる。手書きの `LayoutFactsV10` が本物とずれても F がずれる。fixture が欠ければ N が減る）。`EXPECTED_MIN` は K が自分の fixture だけで数えた N（docs/M7A.md にも書く。P・U の fixture が入ると N は増えるだけ）。`tools/compat10/.gitignore` に `Sources/*/Copied-*.swift`。`InkImport` の流し読み（1.0 で `AppExport.parse` と同じ結果になることは確かめ済み）は `RunReal` だけが本物を通す。

**本物の 1.0 のアプリの台帳と同期**（`tools/compat10/AppTests/Real10LedgerTests.swift`、K）: F1・F12・`mergeRemote` はアプリのコード（`Ink/InkLedger.swift:217-235, 268-319`、`CalendarRootScreen.swift:809-813`、`Sync/SyncEngine.swift:633-646`）にあり、`LedgerV10` は手で写したもので、RunReal も同じ写しを本物の InkModel と組み合わせるだけなので、写すときの取り違え（`drawing()` の `cells[stroke.cell]` の guard、指紋表に無い線を墓標にしないこと など）は RunReal と RunFrozen の両方で緑のまま残りうる。そこで compat-v1.0 のジョブが、このファイルを `v10/Tests/TegakiCalendarTests/` へコピーし、a21e469 の `project.yml` で xcodegen して、シミュレータで `-only-testing:TegakiCalendarTests/Real10LedgerTests` だけを走らせる。fixture のフォルダは環境変数 `TEGAKI_COMPAT_FIXTURES`（xcodebuild には `TEST_RUNNER_TEGAKI_COMPAT_FIXTURES` で渡す）。fixture ごとに、`@testable import TegakiCalendar` で:

1. 1.0 の `InkLedger(page:layout:)` に 1.0 のレイアウト（a21e469 の各エンジン、予定なし）で読み込み、`drawing().strokes.count` が 1.0 で描ける線（日なら `grid`、月なら日のマスと `memo`、年なら 372 マス）の本数と同じ。
2. `applyCanvasChange(PKDrawing())`（全部消す）の `removedIds` が、その描ける線の id だけ。その後の `ledger.page` を JSON にすると、`extra` の線と知らない tool の線が元と 1 バイトも変わらない。
3. 1.0 の `SyncEngineTests` と同じ組み立て（`InMemoryCloudDatabase`・一時フォルダの `InkPageStore`）で、fixture を遠隔に置いて取り寄せる → 端末のファイルの `extra` が変わらない。端末で `grid` に 1 本足して `save` → 送った記録の `extra` が変わらない。同じページを取り寄せ直しても dirty にならない（F12）。
4. `y-2026.n20500`: 1.0 は 20,000 本に切り詰めて保存・送信し、墓標を作らない（F8 の確認。1.1 が和集合に戻すことは `Compat10BudgetTests` と U の `SyncEngineTests` で確かめる）。

このテストだけが新しいので、最初の CI で赤なら直すのは K（1.0 のコードは直さない）。

**v1.0 のタグ**: 今のリポジトリにタグは無い。CI は SHA で取り出すのでタグは要らない。付けて GitHub に送るのは公開の操作なので、本人が「付けて」と言ったときだけリードが行う（M7A-8）。1.0.1 を出したら、その commit を `RunReal` の 2 つ目の対象に足すのは 1.2 の契約で決める。

## 2. ツールバーをしまう・消しゴムから自動でペンへ（項目 3・5。担当 T・P・U）

### 2.1 3 つの状態と移り方

| 今の状態 | きっかけ | 次の状態 | `toolbar.collapsed` |
| --- | --- | --- | --- |
| `expanded`（既定） | 右端の「しまう」 | `collapsed` | true にする |
| `expanded` | ペン・指が紙に触れた | `expanded`（しまわない。計画どおり「広げたまま使う人は広げたまま」） | — |
| `collapsed` | 丸ボタンの道具の部分（道具の印）をタップ | `peek` | 変えない |
| `collapsed` | 丸ボタンの ↶ をタップ | `collapsed`（元に戻すだけ。↷ は丸ボタンに無いので、やり直すときは道具の印でツールバーを出す） | — |
| `peek` | `onPenDown`（書く道具・消しゴム・投げなわ・予定のどれでも、ペンか書く指が紙に触れた瞬間） | `collapsed` | 変えない |
| `peek` | 「しまう」 | `collapsed` | 変えない |
| `peek` | アプリが背面へ（`scenePhase == .background`） | `collapsed` | — |
| `collapsed` | 丸ボタンの長押しメニュー「ツールバーをいつも出す」 | `expanded` | false にする |
| `collapsed` | 長押しメニュー「右下へ移す」／「左下へ移す」 | `collapsed`（反対の角） | `toolbar.collapsedEdge` を書く |
| どれでも | 閲覧専用になった・回転・幅の変化・ページの移動 | 変えない（閲覧専用では ↶ が灰色） | — |

- `peek` で道具や色を選んでもしまわない（紙に触れたときにしまう）。指でスクロール・タップしただけではしまわない（`onPenDown` は PencilKit の `canvasViewDidBeginUsingTool` と overlay の追跡の始まりだけ。「指でも書く」オフの指は届かない）。閲覧専用では描画の部品が止まっているので `onPenDown` は来ない。
- 消しゴムから自動でペンに戻ったときも状態はそのまま（`collapsed` なら丸ボタンの記号がペンに変わる）。Pencil のダブルタップで道具が変わったときも記号が変わる（DESIGN §3.11 の未実装の「1 秒トースト」の代わり）。

### 2.2 見た目と寸法（担当 T。置き場所は U）

- **広げた状態**: 今のバー（`ToolbarView.swift:50-75`。`.safeAreaInset(edge: .bottom)` に横 12・下 6、`CalendarRootScreen.swift:392-410`。高さ 60 = 44 + 8 × 2、紙を 66 pt 押し上げる）。`showsCollapseButton` が true のとき、body を `HStack(spacing: 0) { ScrollView(.horizontal) { 今の HStack }; Divider().frame(height: 24); しまうボタン.padding(.horizontal, 8) }` にし、背景・枠・影（:68-74）はこの HStack に付ける。**しまうボタンは ScrollView の外**（中身が画面より広いとき ScrollView が譲る。0-10）。**ほかの道具のボタン（:81-98）と同じ形**: `VStack(spacing: 2) { Image(systemName: "chevron.down")（18 pt・medium）; Text("しまう")（10 pt） }`、56 × 44、読み上げ「ツールバーをしまう」。本人には計画と P-4 で「しまう」と伝えてあるので、FAQ・審査メモ・新機能の文・本人の確認でも「しまう」と呼ぶ。閲覧専用でも押せる。**このボタンは広げた状態の全部の写真に写る**（0-20）。
- **丸ボタンから広げた状態（`peek`）**: 同じ `ToolbarView`（しまうボタンあり）を `.overlay(alignment: .bottom)` に横 12・下 6 で重ねる（安全領域の内側）。`.transition(.move(edge: .bottom).combined(with: .opacity))`、0.2 秒。紙の領域は変わらない。丸ボタンは隠す。
- **しまった状態（`ToolbarDock`）**: `.overlay(alignment: edge == .leading ? .bottomLeading : .bottomTrailing)` に横 12・下 6。カプセル（高さ 48、内側の余白 2、間隔 4、幅 96）に [道具 44 × 44][↶ 44 × 44]。**道具の部分を角の側** に置く（左下なら道具が左、右下なら道具が右）。背景・枠・影はツールバーと同じ（`.regularMaterial`、`Color.primary.opacity(0.08)` の枠、影 0.08・半径 8・y 2）。ホームバーに密着させない（下の余白 6 は安全領域の上）。
- **道具の記号**（`ToolbarLogic.badge(for:)`）: ペン = 色の塗りの丸（直径 細 10・中 14・太 18 pt、外側に `primary.opacity(0.15)` の 1 pt の輪。白に近い色や黄でも見える）、読み上げの値「ペン・赤・太」。マーカー = `highlighter`（primary の色、18 pt）の下に、マーカーの色で幅 22・高さ 4 pt の横棒、値「マーカー・黄」。消しゴム `eraser`「消しゴム」、投げなわ `lasso`「投げなわ」、予定 `calendar.badge.plus`「予定」。色の名前は `ToolbarPalette`（:244-258）の `name`、表に無い色は「その他の色」、表に無い太さは名前を付けない（「ペン・赤」）。
- **↶**: `arrow.uturn.backward`（18 pt）、`disabled(!canUndo)`、読み上げ「元に戻す」。押したときの扱いは今のツールバーの ↶ と同じ（`isAllowed(.undoRedo)` を U が確かめる）。
- **長押し**: **カプセル全体** に `.contextMenu`（中の 2 つのボタンはタップをそのまま受ける。本人が「丸ボタン」と思うどこを長押ししても出る）: 左下にあるとき「右下へ移す」（`arrow.right.to.line`）、右下にあるとき「左下へ移す」（`arrow.left.to.line`）、「ツールバーをいつも出す」（`dock.rectangle`）。読み上げ（道具の部分）: 名前「ツールバーを出す」、値は記号の値、ヒント「長押しで、右下へ移すか、ツールバーをいつも出すかを選べます」（右下にあるときは「左下へ」）、`accessibilityAction(named:)` で同じ 2 つ。
- **トースト**（`CalendarRootScreen.swift:380-390`）: 下の余白を `ToolbarLogic.toastBottomPadding(mode)`（広げた状態 8 = 今まで通り、しまった状態 62 = 8 + 48 + 6、`peek` 74 = 8 + 60 + 6）。iPhone では中央のトーストの横が丸ボタンにかかるため。
- **紙の下の余白**: しまった状態と `peek` では `InkCanvasView.bottomClearance = 60`（48 + 6 + 6）。P は `applyInsets`（`InkCanvasView.swift:882-892`）で下の inset を `max(中央寄せの縦の余白, bottomClearance)` にする（上・左右は今のまま）。紙の最下部（年の 31 日の行・月の最終週の月曜・日の `extra` の左下）を丸ボタンの上まで送れる。値が変わったら `update(from:)` ですぐ `applyInsets()`（線には関係しない）。
- 下の安全領域（一般的な値、未計測）は iPhone 縦 34・横 約 21（左右 約 62）・Face ID の iPad と iPad mini（A17 Pro）20 pt。U は写真モードで `toolbar: safeArea=<上,左,下,右>` と `toolbar: paperArea=<幅>x<高さ> mode=<expanded|collapsed>`（`updatePaperArea` が値を変えたとき、`CalendarRootScreen.swift:300-305`）を NSLog に出し、C が CI のログから docs/M7A.md に写す。**C は collapsed の写真の紙の領域の高さが、同じ機種・同じページの広げた状態 ＋ 66 pt（± 0.5）であることを確かめる**（`safeAreaInset` の中身が空のとき高さが本当に 0 か、の確認。§2.7）。

### 2.3 記憶・起動時の道具（担当 T、接続は U）

- 記憶: `toolbar.collapsed`（Bool、既定 false）と `toolbar.collapsedEdge`（"leading" / "trailing"、既定 leading）。`peek` は記憶しない（開き直すと `collapsed`）。端末ごと（iCloud に送らない）。写真モードでは読まない・書かない（`--screenshot-toolbar` で決める。§7.3）。
- **起動時の道具の直し（0-13）**: `ToolbarPalette.rememberedPen(_:)` は `"toolbar.penColor"` / `"toolbar.penWidth"`（`ToolbarView.swift:20-22` と同じキー・同じ既定）を読み、色が `penColors` に無い・太さが `penWidths` に無ければ既定（黒・中）。U は `init()` の `_tool`（:232。写真モードの lasso の分岐は残す）と `_lastInkTool`（:122 の既定値をやめて init で入れる）に `.ink(ToolbarPalette.rememberedPen(.standard))` を使う（写真モードでは `defaultPen`）。

### 2.4 消しゴムの自動復帰の動き（P-5 A）

| 場面 | 動き |
| --- | --- |
| ツールバーで消しゴム（`EraserOrigin.toolbar`）→ なぞって 1 本以上消す → 離す | 離して 0.3 秒後（落ち着く待ちの終わり）に `lastInkTool` へ。ペンなら色・太さもそのまま、マーカーならマーカー（直前が投げなわ・予定でも `lastInkTool` は最後のペン・マーカー。`CalendarRootScreen.swift:414-416`） |
| なぞったが何も消えなかった | 消しゴムのまま |
| 離して 0.3 秒以内にまた触れて続けて消した | 最後に離して 0.3 秒たってから 1 回だけ戻る（消えた本数は足し合わせる。途中の 1 筆が 0 本でも戻る） |
| 消して離し、0.3 秒以内に書き直し始めた（Pencil で素早く書く人） | その 1 筆は消しゴムのまま（何も書けない）。本人の確認 6b で試す。書けないと困るなら、消しゴムの待ちだけ 0.15 秒に縮めるか、`erasedSinceReport > 0` のとき `penDidLift` ですぐ戻す（続けて消すには毎回消しゴムを選び直す）のどちらかに直す（リードが決めて docs/M7A.md に書く） |
| 待ちの 0.3 秒の間に、本人がツールバーで投げなわ・予定・ペンなどを選んだ | 戻さない（本人の選んだ道具のまま。`toolAfterErase` は今の道具が消しゴムのときだけ値を返す） |
| Pencil のダブルタップ／スクイーズで消しゴム（`.pencil`） | 戻らない（今まで通り次のダブルタップで `lastInkTool`、`togglePencilTool` :953-959） |
| ツールバーの消しゴム → Pencil のダブルタップ | 今まで通り `lastInkTool` へ。そこからのダブルタップの消しゴムは `.pencil` |
| 設定「消しゴムで消したらペンに戻る」がオフ | 戻らない。説明文の括弧も出さない |
| 閲覧専用 | 消えないので何も起きない |
| ↶ で取り消し | 道具は戻ったまま、消した線だけ戻る（取り消しは数えない） |
| 「指でも書く」オンで指で消した | 同じく戻る |
| 消しゴムのまま日付を指でタップ（「指でも書く」オン、ページを移るタップ） | **そのタップの触れ方で消した線を、移る前に取り消してから** 日のページへ移る（0-22）。道具は消しゴムのまま（取り消した本数を `erasedSinceReport` から引くので戻らない）。1.0・1.0.1 では消えたまま移っていた（本人は気付けず、墓標は 1.0 にも届く） |
| 消しゴムのまま指でダブルタップ | 1.0 のまま（2 回の触れ方で消えた分は取り消さない。わざわざ 2 回叩く操作で、2 回目の触れ方だけを戻しても半端になるため） |
| ツールバーで消しゴムを押し直す（同じ値） | `.toolbar` のまま（`toolBinding` の setter は同じ値でも呼ばれる、:1471-1482） |

`ToolbarLogic.toolAfterErase(origin:erased:setting:current:lastInk:)` = `current.isEraser && origin == .toolbar && erased > 0 && setting ? lastInk : nil`（nil = 変えない）。消しゴムの説明（`ToolbarView.swift:132`）は `eraserHint(returnsTo: eraserReturnsTo)`。U は道具が消しゴムで、`eraserOrigin == .toolbar` かつ設定がオンのときだけ `eraserReturnsTo = lastInkTool` を渡す。

**消しゴムのタップの取り消し**（P、`InkCanvasView.swift`）: Coordinator に `removedSinceTouch: [String]` と `touchBeganAt: TimeInterval`（`penDidTouch` で空にし、`uptime()` を入れる。§2.5 の 2 と同じ条件で数えた消しゴムの `removedIds` を足す）と `tapTouchBeganAt: TimeInterval`（`gestureRecognizer(_:shouldReceive:)`（:1189-1192）で `tapRecognizer` が受けた指の `touch.timestamp`。`systemUptime` と同じ時計）。`fingerTapped`（:1117-1122）の先頭で、`parent.allowFinger && !parent.readOnly && parent.tool.isEraser && !removedSinceTouch.isEmpty && abs(touchBeganAt − tapTouchBeganAt) < 0.1 && parent.tapLeavesPage(point, zoom)` なら（時刻の条件で、消した触れ方がそのタップの指と同じであることを確かめる。前の触れ方で消した分は戻さない） `ledger.undoIfTopRestores(ids: Set(removedSinceTouch))`（取り消しの山の一番上が、ちょうどその id の線を戻す op のときだけ `undo()`。戻る線は今の `perform(.add)` の規則で新しい id の写し）→ 戻ったら `setDrawing`・`refreshSelection`・`publishPage`・`notifyHistory`、`erasedSinceReport = max(0, erasedSinceReport − n)`、`removedSinceTouch = []` → 今まで通り点消しの判定と `onTap`。タップは触れ方の最後に認識されるので、「最後の触れ方で消した分」がそのタップで消した分になる。

### 2.5 消し終わりの見分け方（担当 P、`InkCanvasView.swift`）

1. Coordinator に `erasedSinceReport: Int = 0`。`detach()` で 0。
2. `canvasViewDrawingDidChange`（:1232-1250）で `ledger.applyCanvasChange` の結果が空でなく、`parent.tool.isEraser && !parent.readOnly && (isUsingTool || isSettling) && change.added.isEmpty` なら `erasedSinceReport += change.removedIds.count`、`removedSinceTouch += change.removedIds`。取り消し・やり直し・iCloud の反映・線の作り直し・指の点消し（`removeDots`）・紙の外の線を捨て直すときは `isApplyingDrawing`、投げなわの移動は `isMovingSelection` の囲いで :1233 が返すので数えない。`ledger.reload` は指紋の表を残すので iCloud からの反映が「消した」に化けない（`InkLedger.swift:196-210`）。
3. `penDidLift`（:1216-1229）の待ちの Task の中（`guard … !self.isUsingTool` の後、`applyPending()` の後）で `erasedSinceReport > 0` なら値を取り出して 0 にし、`deliver { onEraseEnded(n) }`。新しい触れ方で待ちが打ち切られたら（`settleGeneration` が変わった）数は持ち越す。
4. `penDidTouch`（:1210-1214）で `removedSinceTouch = []`（§2.4）と `deliver { onPenDown() }`。投げなわ・予定の overlay の追跡（`overlay(_:isTracking:)`、:1448-1454）も `penDidTouch` / `penDidLift` を呼ぶので、ここに足せば両方に効く。
5. 条件の `isUsingTool || isSettling` があるので、テストの台（`InkCanvasViewTests.swift:69` の `makeView`）が Begin を呼ばずに `canvasViewDrawingDidChange` を直接呼ぶ既存のテストは影響を受けない（既定の道具が `.eraser` でも）。

### 2.6 設定 › 入力（キーは T、行は U）

- `SettingsScreen.swift` の入力の節（:310-336）の「指でも書く」の Section（:312-318）の **すぐ後** に新しい Section: `Toggle("消しゴムで消したらペンに戻る", isOn: $eraserAutoReturn)`、脚注は `static func eraserAutoReturnFooter(isPad: Bool) -> String`（§6.2。iPhone では 1 文目だけ、Apple Pencil の文は iPad だけ。`isPad` は :107 と同じ判定）。行は iPad・iPhone の両方に出す。
- 状態は `eraseInkAfterConvert` と同じ形: `@State private var eraserAutoReturn: Bool = ScreenshotMode.isActive ? true : AppSettings.eraserAutoReturn`（:43 の隣）、`.onChange(of: eraserAutoReturn) { guard !ScreenshotMode.isActive else { return }; AppSettings.eraserAutoReturn = eraserAutoReturn }`（:146-149 の隣）。
- `AppSettings.eraserAutoReturn` は「値が無いときは true」（`eraseInkAfterConvert` :55-62 と同じ書き方）。`CalendarRootScreen` は `@AppStorage(AppSettings.eraserAutoReturnKey) private var eraserAutoReturn = true` で読む（同じキーなので設定の変更がすぐ効く）。

### 2.7 U の接続（`CalendarRootScreen.swift`）

- 状態: `@AppStorage(AppSettings.toolbarCollapsedKey) toolbarCollapsedStored = false`、`@AppStorage(AppSettings.toolbarEdgeKey) toolbarEdgeRaw = "leading"`、`@State toolbarMode`、`@State eraserOrigin: EraserOrigin?`。`toolbarMode` の初期値は init で `_toolbarMode = State(initialValue: shot.map { 写真モードの指定 } ?? ToolbarLogic.startMode(collapsedStored: AppSettings.toolbarCollapsed))`。**init の中では、全部の stored property を初期化する前に `@AppStorage` の値（`toolbarCollapsedStored`）を読めないので、`AppSettings.toolbarCollapsed`（`UserDefaults.standard` を直接読む）を使う**。写真モードでは `@AppStorage` に書かない。
- `.safeAreaInset(edge: .bottom, spacing: toolbarMode == .expanded ? nil : 0)`（:392-410。広げた状態は今と同じ既定の間隔のまま＝写真が変わらない。中身が空のときに既定の間隔が残らないよう 0）の中身は `toolbarMode == .expanded` のときだけ `ToolbarView(…, showsCollapseButton: true, onCollapse: collapse, eraserReturnsTo: …)`（それ以外は何も置かない = 高さ 0。§2.2 のログで確かめる）。modifier そのものを `if` で付け外ししない（View の同一性が変わってキャンバスが作り直される）。`peek` の `ToolbarView` と `collapsed` の `ToolbarDock` は §2.2 の overlay。`ToolbarDock` の ↶ は今の `onUndo` と同じ処理、`canUndo: canUndo && !readOnly`。
- `canvas(viewportWidth:)`（:499-545）の `InkCanvasView` に `onPenDown: { toolbarMode = ToolbarLogic.modeAfterPenDown(toolbarMode) }`（`withAnimation(.easeInOut(duration: 0.2))`）、`onEraseEnded: eraseEnded`、`bottomClearance: ToolbarLogic.paperBottomClearance(toolbarMode)`。
- `eraseEnded(_ n:)`: `if let next = ToolbarLogic.toolAfterErase(origin: eraserOrigin, erased: n, setting: eraserAutoReturn, current: tool, lastInk: lastInkTool) { tool = next }`（`onEraseEnded` は離して 0.3 秒後に届くので、その間に本人が選んだ道具を上書きしない。`current` が消しゴムでなければ nil）。
- `toolBinding` の setter（:1471-1482）で `newValue == .eraser` なら `eraserOrigin = .toolbar`。`togglePencilTool`（:953-959）で消しゴムにしたら `eraserOrigin = .pencil`。`readOnlyChanged`（:1461-1467）は今のまま。
- `scenePhaseChanged`（:725）で `.background` なら `peek` → `collapsed`。

## 3. 下に伸びるメモ（項目 7・8。担当 K・P・U）

### 3.1 高さの式（K、`Layout/PaperGrowth.swift`）

`tailHeight(inkBottom: b)` は D3 の式（b はマス相対の手書きの下端。`InkPage.inkBottoms()` は線の太さの半分を含む、`InkStroke.swift:225-231`）。

| b | 0 | 300 | 301 | 700 | 701 | 1,100 | 5,600 | 5,601 | 5,950 | 5,990 | 6,420 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 高さ | 700 | 700 | 1,100 | 1,100 | 1,500 | 1,500 | 5,900 | 6,000 | 6,000 | 6,040 | 6,470 |

- 白紙（高さ − b）は b ≤ 5,600 で 400〜800。上限の近くでは 400 を切り、上限を超えた線が 1.0 の端末から来たときだけ `b + 50` で伸びる（1.0 の式と同じ。F6）。b が有限でない・負なら 0 とみなす。
- `needsMoreRoom(cell:cellHeight:inkBottom:)`: `isTail(cell)` なら `tailHeight(b) > cellHeight + 0.001`、ほかは `b + PaperSpec.inkPad > cellHeight + 0.001`。P の `InkLedger.needsMoreRoom`（:321-325）はこれを呼ぶ（`layout.growsWithInk` の guard は残す）。月の行（上限 1,200）・年の行（上限 400）の規則は変えない。
- `reachesCap(inkBottom: b)`: b が有限で 0 以上、`700 + 400 × max(0, ceil((b − 300) / 400)) ≥ growMax`（= b > 5,600）。この下端の線を書くと、離しても白紙はもう 400 足されない（上限の案内の 2 つ目のきっかけ、§3.4）。
- 画面上の 400 lu: 13 インチの月 0.7371 で 295 pt、mini 0.5314 で 213 pt、iPhone 0.2871 で 115 pt。6,000 lu は 13 インチで 4,423 pt（紙の領域 1,172 pt の約 3.8 画面分）。700 から上限まで白紙を足すのは 14 回ほど（13 インチの月で約 4,400 pt 下へ書き進める）。

### 3.2 月のメモ欄（K）

- `MonthLayoutEngine.memoHeight(inkBottom:)`（:23-26）の中身を `PaperGrowth.tailHeight(inkBottom:)` に（名前は残す。`PaperSpec.memoMin` / `memoInkPad` も残す）。欄の矩形 `(0, memo.minY, 1400, h)` と紙 `1400 × (行の合計 + h)` は今のまま（:162-167）。
- 一覧の矩形は 1400 × `memo.minY`（`ZoomPolicy.swift:61-64`）のまま。メモ欄が伸びても倍率は変わらない。`scrollDelta` はメモ欄の高さだけの変化で 0（`MonthLayoutEngine.swift:284-292`）。メモ欄の罫線は `memo.maxY` まで自動で伸びる（`Paper/MonthPaper.swift:61-92`。変えない）。
- 写真モードの月の点（`ScreenshotMode.swift` の `demo-stroke-dot`、下端 64.5）は 700 のまま → **月の紙の絵は 1.0.1 と同じ**（0-1。ツールバーの帯は 0-20 のとおり変わる）。

### 3.3 日の `extra`（K: `DayLayoutEngine.swift`、P: `DayPaper.swift`）

| 項目 | 1.1 |
| --- | --- |
| `DayPageLayout.extra` | `(0, 2400, 1000, h)`、h = `PaperGrowth.tailHeight(inkBottom: inkBottoms[.extra] ?? 0)`（`DayLayoutInput.inkBottoms` を読むようになる。:9-10 の説明を直す）。最小 700 |
| `size` | 1000 × (2400 + h)。`grid`・`timeline`・`memo`（右の列）は 2400 のまま（K-4） |
| `cells` | `[.grid: grid, .extra: extra]` |
| `cell(at:)` | 0 ≤ x ≤ 1000 で、0 ≤ y < 2400 → `.grid`、2400 ≤ y < size.height → `.extra`、他・有限でない → nil |
| `inkCell(forCenter:)` | 中心の y ≥ 2400 → `.extra`、それ以外（紙の上の負の y・横の外も）→ `.grid`（決して nil にしない） |
| `growsWithInk` | `cell == .extra` |
| `band(atY:)` / `bandTop` | [0, 2400) → `.grid`（0）、[2400, 高さ) → `.extra`（2400）。上端は動かないので補正 0 |
| `hit` / `dayAt` | 今のまま（予定の箱だけ／常に nil） |
| `eventRange(for:)` | **今のまま**（0-4。PageLayout の約束「nil は有限でない矩形のときだけ」、`PageLayout.swift:138-141`。24 時より下の矩形は今まで通り 23:00〜24:00 に寄せる）。`snapRect` も今のまま（時刻の範囲は 0〜24 時だけ） |
| `startsBelowDay(_:)`（新規） | 有限な矩形で `rect.standardized.minY ≥ grid.maxY`（2400）なら true。minY 2,399.9 は false、2,400 は true。有限でない矩形は false。上へ向かうドラッグ（minY が 24 時より上）は false。U が `eventRange` の前に呼ぶ（§3.7） |
| `nowLine`・開く位置（7:00 ／ 今 − 1 時間、`PageNavigation.swift:132-139`） | 変えない |

紙の絵（P、`Paper/DayPaper.swift`）: (1) :14 の `height` を **`layout.grid.maxY`** にして、時間軸の色（:26）とガター・時間軸の右の縦線（:37-38）を 24 時で止める。(2) y = 2400 に `PaperPalette.lineStrong` の横線を 0〜1000（`MonthPaper.swift:67-72` と同じ）。(3) `extra` に 50 lu ごとの罫線を x 20〜980（`PaperPalette.rule`、`dayRuleStep`・`dayRuleInset`、月のメモ欄 `MonthPaper.swift:74-84` と同じ）を `extra.maxY` まで。(4) **「自由メモ」** の字を (20, 2406)（右の列の「メモ」:62-67 と同じ字の大きさ・色・字間。同じページに「メモ」が 2 つ並ばないよう名前を変える。M7A-10）。すべて `dirty` と交わる所だけ描く。

### 3.4 上限と捨てる線（K の判定、P が使う）

- P の `dropStrokesOutsideThePaper`（:1256-1271）の残す条件を `PaperGrowth.drop(center:in: appliedLayout) == nil` に。新しい線（`ledger.id(of:) == nil`）だけが対象なのは今のまま。捨てた線に 1 本でも `.beyondCap` があれば `deliver { onGrowthCapReached() }`（1 回の呼び出しで 1 回）。
- **上限に届いたとき**（P、`canvasViewDrawingDidChange` の ⑦、§5.2）: `change.added` の中に、最後のマス（`PaperGrowth.isTail`）の線で、その線のマス相対の下端（`InkPage.inkBottoms()` と同じ、線の太さの半分を含む）が `PaperGrowth.reachesCap` を満たすものがあれば `deliver { onGrowthCapReached() }`。上限ちょうどまで紙が足されると、新しい線は捨てられずに紙の中に収まり、白紙がもう増えないだけなので、捨てたときだけでは本人に何も伝わらない（計画 §2.7「上限に届いたら 1 回だけ」）。
- U は `onGrowthCapReached` でトースト「メモ欄はここまでです」（3 秒）。同じページを開いている間は 2 回目を出さない（`@State capNoticedPageId: String?` に pageId。ページが変われば出せる）。紙の終わりに「ここまで」の線は描かない（§9.1）。
- 1.0 の端末や Web 版から来た上限より下の線は消さず、`tailHeight` の `b + 50` で見える高さまで伸びる。そこへ新しく書いた線は、紙の中でも `beyondCap` で捨てる（0-5）。
- 続きを別のページ id に分ける案（`m1-2026-10-memo2` など）は、本人が上限に届いてから考える（1.1 では作らない）。

### 3.5 一覧・スクロール・PDF（K・P）

- **K-6**: `ZoomPolicy.overviewSize`（:61-66）に `if let day = layout as? DayPageLayout { return CGSize(width: day.size.width, height: day.grid.height) }`。使う所はすべてこの関数を通る（`InkCanvasView.swift` の bounds、`CalendarRootScreen.swift` の推定倍率、`PDFPageRenderer.swift:58`）。日の一覧の倍率は変わらない（実測 iPhone 0.2233・mini 0.3642・11 インチ 0.3962・13 インチ 0.4654・iPhone 横 0.0854）。
- `centeringInsets`（:150-159）は紙全体で計算するので、日の紙が 3,100 以上になると縦の余白は 0（今も高さで決まるので 0）。横の余白（iPhone 左右 89 pt など）は今のまま。日の一覧の写真は 0:00〜24:00 のまま（下端に 24 時の区切り線が乗りうる、0-20）。日のページは 7:00 で開き、一覧は 24 時で止まるので、24 時の下に紙が続くことは画面からは分からない。新機能の文と審査メモで「日のページを下へスクロールすると」と書く（§6.5）。一覧に 24 時の下を少し覗かせるかは、CI の `day-extra` の写真と一緒に本人に聞く（M7A-10。既定は覗かせない、K-6）。
- **PDF**（P、`PDFPageRenderer.paperRect` :52-61）: 日に月と同じ分岐 — `extra` に生きている線があれば紙全体、無ければ `ZoomPolicy.overviewSize`（1000 × 2400）。週・年は今のまま。一番高いページ（倍率 1 で 1 lu = 1 pt）は 月 64 + 6 × 1,200 + 6,000 = 13,264 pt、日 76 + 帯 + 8,400、年 64 + 31 × 400 = 12,464 pt（1.0 から上限より下の線が来たときだけ超えうる）。手書きの画像は 1,200 万画素の上限で粗くなる（月のメモ 6,000 で約 1.10 px/pt、日 8,400 で約 1.20 px/pt、日 3,100 で約 1.97 px/pt。`InkSnapshot.swift:19, 47-56`）。
- JSON の書き出しは変える所なし（ページをそのまま運ぶ。K-5）。

### 3.6 `contentSize` だけ更新する経路（K の判定、P の実装）

**判定**（K、`PaperGrowth.onlyTailHeightChanged(old:new:)`）: 次が全部成り立つとき true。種類・pageId・`size.width` が同じ／`cells` のキーの集合が同じ／`tail(of:)` が両方にあり同じキー／最後のマス以外の矩形がすべて `==`／最後のマスの minX・minY・幅が同じで高さだけが違う／`size.height − tail.height` が同じ（紙の下端 = 最後のマスの下端）。月で行が伸びると `memo.minY` が動くので false（全部作り直す今の経路）。週・年は常に false。

**台帳**（P、`InkLedger.adopt(_:)`）: `layout.pageId == page.pageId` なら `self.layout = layout` だけ（違えば `onPageMismatch`。`relayout` :254-262 と同じ）。マスの原点が変わらないので PKStroke の変換も指紋の表もそのまま使える。`needsMoreRoom`・`inkCell`・`moveStrokes` が新しい高さを読むので差し替えは要る。

**キャンバス**（P、`InkCanvasView.swift`）:
1. `update(from:)` の手順 2（:546-551。`if !appliedLayout.sameGeometry` は :547-549）で、形が変わったときは `pendingDrawing` ではなく新しい `pendingGeometry = true`。ページ・取り消し・命令・取り込みは今まで通り `pendingDrawing`。**末尾の `requestApply()` の条件（:609 `if pendingDrawing || pendingPaper || !pendingCommands.isEmpty`）に `pendingGeometry` を足す**（紙の絵が変わらず形だけが変わったときに何もせず返らないため）。
2. `applyPending`（:621-703）: `geometryWork = pendingGeometry` を取り出して `pendingGeometry = false`。**:640 の `guard drawingWork || paperWork else { return }` を `guard drawingWork || paperWork || geometryWork` にする**。`!drawingWork && geometryWork && PaperGrowth.onlyTailHeightChanged(old: appliedLayout, new: parent.layout)` なら **軽い経路**: `ledger.adopt(newLayout)` → `appliedLayout = newLayout` → `canvas.contentSize = scaled(size, zoom)` → `overlay?.pageSize` → `applyInsets()` → 拡大の途中（`isLive`）でなければ `canvas.contentOffset = clampedOffset(canvas.contentOffset)`（縮んだとき紙の外を見ないため、:941-952）→ `syncPaperFrame()`。`setDrawing` も `applyBounds` も `scrollDelta` も呼ばない（一覧の矩形も帯の上端も変わらない）。NSLog `canvas: tail-only <pageId> <旧高さ>→<新高さ>`。
3. それ以外は今の経路: 軽い経路に入らなかったら `drawingWork = drawingWork || geometryWork` として、:656 の `if drawingWork`（`setDrawing(ledger.relayout(...))`）・:675 の `else if drawingWork, geometryChanged`・:691 の `if drawingWork`（選択の追随）はそのまま通す。この経路に **`applyInsets()` を足す**（0-6）。
4. 紙の絵は `paperView.content` が変われば今まで通り描き直す（見えている窓の分だけ）。
5. テストのために `setDrawingCount`（`setDrawing` が呼ばれた回数、internal、読むだけ）を Coordinator に置く。

### 3.7 U の接続

- `eventRectFinished`（:978。`eventRange` は :991）と `convertSelection`（:1022。`eventRange` は :1024、矩形は `selection.bbox`）で、**`eventRange` を呼ぶ前に** `(layout as? DayPageLayout)?.startsBelowDay(rect) == true` なら、`openCreate` を呼ばずにトースト「24 時の下の自由メモ欄では予定を作れません」（3 秒）。それ以外は今まで通り（日のページで 24 時をまたぐ矩形は 23 時台の予定になる）。
- `relayout()`（:863-865）は今のまま（`page.inkBottoms()` に `.extra` が入る）。`onGrowthCapReached` は §3.4。

## 4. 日付の当たり（項目 6 の続き・P-13。担当 K・U）

### 4.1 規則（K、`Layout/DateTap.swift`）

`DateTap.minTarget(kind:zoom:smallScreen:allowFinger:)`: zoom が有限で正でなければ nil。月は `!allowFinger` のとき `44 / zoom`。年は `smallScreen || !allowFinger` のとき `44 / zoom`。週・日は nil。

`DateTap.target(layout:point:zoom:smallScreen:allowFinger:currentMonth:)`:

| ページ | 判定の順 |
| --- | --- |
| 年 | ① `hit(at:)`（チップ: 太い → `.allDayBar`、細い → `.date`。曜日の枠 40 × 28）→ ② `gutterHit(at:numberOnly: allowFinger && !smallScreen, month: currentMonth)`（倍率に依らない。年の日付と同じく、小さい画面では「指でも書く」に関わらず行の幅いっぱい）→ ③ `minTarget` があれば `hit(at:minTarget:)`（1.0.1 の関数、`YearLayoutEngine.swift:175-184`）→ nil |
| 月 | `minTarget` があれば `hit(at:minTarget:)`（§4.2）、無ければ `hit(at:)` |
| 週・日 | `hit(at:)`（今のまま） |

| 「指でも書く」 | 小さい画面（iPhone・幅 600 pt 未満） | 大きい画面（iPad 全画面） |
| --- | --- | --- |
| オフ | 月・年とも 44 pt。年のガターは行のマス全体 | 月・年とも 44 pt（**年は 1.1 で広がる**、M7A-2）。ガターは行のマス全体 |
| オン（本人の iPhone の既定） | 年 44 pt（1.0.1 のまま）、**月は日付の字の枠だけ（1.0 のまま。M7A-1）**、ガターは **行のマス全体**（iPhone 16.1 × 17.2 pt） | 年・月とも 1.0 の枠だけ、ガターは数字の上だけ |

`smallScreen` は 1.0.1 の `CalendarRootScreen.usesMinTapTarget(isPhone:width:)` のまま。タップが日のページへ移るかは 1.0.1 の `leavesPage`（`.date`・`.moreChips` → true）のままで、「指でも書く」オンなら移る前に点を消す（`fingerTapped`、`InkCanvasView.swift:1117-1122`）。ガターの数字も `.date` なので同じく点が消える。

**点を消す候補を自分で足した線に限る**（P、0-21）: 1.0.1 の `dotStrokeIds`（:1145-1160）は `stroke.t >= cutoff` で「直近の線」を選ぶが、t は線を書いた端末の時計なので、時計が進んだ別の端末の小さな線（「。」やチェックの印）が iCloud から届いた直後なら候補になり、墓標が 1.0 の端末にも届く。1.1 では Coordinator に `recentAdds: [(at: TimeInterval, id: String)]` を持ち、`canvasViewDrawingDidChange` で `ledger.applyCanvasChange` が返した `change.added` の id を `noteRecentAdd(id, at: uptime())` で記録する（2 秒より古いものと 64 件を超えた分は捨てる。`detach()` とページが変わったときに空にする）。`dotStrokeIds(near:zoom:within:)` は名前と引数をそのままに、候補を「生きていて、`recentAdds` にあり `at ≥ uptime() − within` の線」に限る（大きさ 16 pt・距離 24 pt の条件は今のまま）。t は見ない。1.0.1 の `clock`（:1140）は `uptime` に置き換える。iCloud の反映・取り消し・取り込みは `isApplyingDrawing` の囲いで `canvasViewDrawingDidChange` に来ないので記録されない。

### 4.2 月（K、`MonthPageLayout.swift`）

`hit(at:minTarget:)`: まず `hit(at:)`（チップ → 終日のバー → 日付の枠 `(x+4, y+4, 192, 24)`、:142-155）。外れたら、`minTarget` が有限で正で `dayAt(point:)`（:165-167。月の外の日も含む。メモ欄・紙の外は nil）があるとき、そのマス `cells[.day(day)]` の左上から 幅 = マスの幅（200）× 高さ = `min(マスの高さ, max(28, minTarget))` の中なら `.date(day)`、外なら nil。

| 機種（月の一覧の倍率） | 44 pt = lu | 的の画面上の大きさ | 1.0 の日付の枠 |
| --- | --- | --- | --- |
| iPhone 縦（0.2871） | 153.3 | 57.4 × 44 pt（マス 57.4 × 50.2 の 9 割） | 55.1 × 6.9 pt |
| iPad mini（0.5314） | 82.8 | 106 × 44 | 102.0 × 12.8 |
| 11 インチ（0.5957） | 73.9 | 119 × 44 | 114.4 × 14.3 |
| 13 インチ（0.7371） | 59.7 | 147 × 44 | 141.5 × 17.7 |
| iPhone 横（0.2190） | 200.9 → マスで切る | 43.8 × 38.3（マス全体） | 42.0 × 5.3 |

的の中のチップ・バーは先に判定されるので予定の編集が開く。拡大すると的は小さくなり、`44 / zoom` が 28 を下回る倍率（約 1.57 倍以上）で日付の行（28 lu）の幅いっぱいに戻る。

### 4.3 年（K、`YearLayoutEngine.swift`）

- **1.0.1 の部分**（`hit(at:minTarget:)`）はそのまま。1.1 で変わるのは呼ぶ条件だけ（§4.1）。iPad の一覧・オフでの的: 13 インチ 44 × 36 pt、11 インチ 44 × 31、mini 44 × 29（1.0.1 の §3 の数字）。
- **ガター（P-13）** `gutterDay(at:numberOnly:)`: x と y が有限で、0 ≤ x < 56（`PaperSpec.yearGutter`）、`row(atY:)`（:128）が日 d（1〜31）を返すとき。`numberOnly` なら、その行の真ん中 ± 14（56 × 28 lu。字の大きさ 22 lu と曜日の枠の高さ 28 にそろえる）だけ。`DateTap` が `numberOnly` を true にするのは「指でも書く」オンの大きい画面だけ（P-13 の「日付の数字と同じく」を、1.0.1 で小さい画面の年の日付が「指でも書く」に関わらず 44 pt になったことに合わせて読む）。それ以外・紙の外は nil。`gutterHit(at:numberOnly:month:)` = `month` が 1〜12 で `DayKey(year: year, month: month, day: d).isValid` なら `.date(その日)`、無い日（11 月の 31・平年の 2/29〜31）は nil（M7A-3）。
- ガターの画面上の大きさ（行のマス全体 56 × 60 lu／数字の上 56 × 28 lu）: iPhone 16.1 × 17.2 ／ 16.1 × 8.0 pt、mini 26.8 × 28.7 ／ 26.8 × 13.4、11 インチ 29.1 × 31.1 ／ 29.1 × 14.5、13 インチ 34.0 × 36.4 ／ 34.0 × 17.0、iPhone 横 6.9 × 7.4 ／ 6.9 × 3.5。iPhone では数字の上だけ（16 × 8 pt、約 1.3 mm の高さ）は叩けないので、常に行全体（16 × 17 pt。行の高さがこれ以上は無い）。行は 1 つに決まるので、高さはその行より大きくしない（隣の日にならない）。iPhone でガターの 56 lu の中に字を書くことはまれなので、誤って移る心配は小さい。
- ガターに書いた線は今まで通り 1 月のマス（x はマス相対で負、`inkCell` :145-152）。ダブルタップ（`dayAt`）はガターで nil のまま。

### 4.4 週（変えない）

日付は固定見出しの `Button`（`StickyHeaderView.swift:99-138`、`minHeight: 48`、`contentShape` 全体）。縦向きは全機種で 44 pt 以上、iPhone 横の 20.4 pt は受け入れる（0-8）。「指でも書く」とも関係しない（紙の外の部品）。

### 4.5 U の接続

`CalendarRootScreen.tapTarget` を `static func tapTarget(layout:point:zoom:smallScreen:allowFinger:currentMonth:) -> HitTarget?`（中身は `DateTap.target`）にし、`handleTap`（:931）と `tapLeavesPage`（:544）の両方で `allowFinger: allowFinger, currentMonth: DayKey(now).month` を渡す（`now` は写真モードでは固定の日時）。`static let minTapTarget`（:898）は `DateTap.minPoints` を使う形に。`handleDoubleTap`（:944）・`leavesPage`（:921）・`usesMinTapTarget`（:904）は変えない。初回案内の 3 枚目の文（`OnboardingView.swift:46`）の最後に 1 文足す（§6.2）。

## 5. 線の予算（K-9。担当 K・P・U・T）

### 5.1 数字と数え方（K、`InkModel/StrokeBudget.swift`・`InkPage.swift`）

| 数 | 意味 |
| --- | --- |
| 15,000 本（`noticeAt`） | この端末で、そのページに初めて届いたとき 1 回だけ案内（ページごと・端末ごとに記憶） |
| 19,000 本（`refuseAt`） | この端末で書く新しい線を受け付けない（消す・投げなわで動かす・取り消しはできる） |
| 20,000 本（`legacyReadCap`） | 1.0 が読むたびに切り詰める本数（1.0 の端末では変わらない、F8）。1.1 はこれで切り詰めない |
| **60,000 本（`InkPage.maxStrokes`、1.1 で 20,000 から上げる。`readCap`）** | 1.1 が読むときの上限（壊れた・巨大なファイルからの守りとして残す）。保存の形式・`v`・書き出しは変えない（K-5 の外）。予算があるので自分の端末ではここまで増えない。重さは F13 の割合で約 13 秒（20,000 本を超えるのは外から来たときだけ）。Web 版の取り込み（`WebImport.swift:187`）は新しい `WebImport.maxStrokesPerPage = 20,000` を使い、挙動は今のまま |
| 200,000 件（`InkPage.maxTombstones`） | 墓標の上限（変えない。情報欄の計算でログに出す） |

数えるのは `InkPage.budgetCount = liveStrokeCount + unknownStrokes.count`（0-16）。`accepted(incoming:count:) = min(incoming, max(0, refuseAt − count))`、`crossesNotice(from:to:) = old < noticeAt && noticeAt <= new`。`importExceedsLegacyCap(localIds:incoming:)` = `|localIds ∪ incoming の strokes と unknownStrokes の id| − |その和集合のうち incoming.deleted にある id|` が `legacyReadCap` を超えればその数、超えなければ nil。

**読む上限を上げる理由**（§1.2 の K-9、§1.3）: 1.0 の端末は 20,000 本を超えたページを読むたびに id の辞書順で後ろの線を墓標なしで捨て、編集するとその中身を保存・送信する。1.1 が同じ上限で読むと 1.1 も同じ線を捨て、そのページの線はどの端末からも消える。1.1 が全部を持っていれば、1.0 から切り詰めた版が届いても `mergeRemote`（`SyncEngine.swift:633-646`）が和集合を作り、遠隔の版と違うので印を付けて送り直す。確かめは KitChecks（`InkPage(json:)` で 20,500 本 → 20,500 本、60,001 本 → キーの辞書順で前の 60,000 本）、`Compat10BudgetTests.testNewDeviceRestoresWhat10Truncated`、U の `SyncEngineTests.testMergeRemoteOfATruncatedPageMarksDirty`（§7.2）、K の `Real10LedgerTests` の 4（1.0 が切り詰める側）。

### 5.2 案内と受け付け停止・取り込み（P が判定、U が出す、T が記憶のキー）

P、`canvasViewDrawingDidChange` の順番（:1232-1250）: ① 今の guard と undoManager の掃除 → ② 紙の外・上限の線を捨てる（§3.4）→ ③ **予算で捨てる**: `before = ledger.page.budgetCount`、新しい線（`ledger.id(of:) == nil`）の本数 `n`、`ok = StrokeBudget.accepted(incoming: n, count: before)`。`ok < n` なら新しい線の後ろから `n − ok` 本をキャンバスから外し（`isApplyingDrawing` で囲む、`dropStrokesOutsideThePaper` と同じ書き方）、`deliver { onStrokeBudget(.full(before)) }` → ④ `ledger.applyCanvasChange` → ④' `change.added` の id を `noteRecentAdd`（§4.1） → ⑤ `change.added` が空でなく `crossesNotice(from: before, to: ledger.page.budgetCount)` なら `deliver { onStrokeBudget(.many(新しい数)) }` → ⑥ §2.5 の消しゴムの数と `removedSinceTouch` → ⑦ 今の `needsMoreRoom` と `onInkBoundsChanged`、§3.4 の上限に届いた知らせ。iCloud・取り込み・取り消しで 19,000 を超えても止めない（相手の線を消さない）。

U: `.many` → `AppSettings.strokeBudgetNoticed(pageId)` が false ならトースト（6 秒、エラーの色ではない）と `markStrokeBudgetNoticed`。`.full` → エラーのトースト（6 秒）、2 秒に 1 回まで（`blockedInput` と同じ間引き）。写真モードでは記憶しない。文言は §6.2。

**取り込みの確かめ**（U、`CalendarRootScreen.runImport` :1189-1215 と `WebImportSheet.swift`）: 読み終えて（`outcome.pages` が空でない）`importPhase = .importing` にする前に、`await StrokeCensus.pagesOverLegacyCap(outcome.pages, store: sync.store)`（main の外で、ページごとに `store.peek(pageId)?.strokeIds ?? []` と `StrokeBudget.importExceedsLegacyCap` を当てる）。空でなければ `importPhase = .confirmLarge(pages: その pageLabel の一覧)` にして、シートに §6.2 の文と〔取り込む〕〔やめる〕を出す。〔取り込む〕で今まで通り `sync.importPages` へ、〔やめる〕で何もせず閉じる（結果のトーストも出さない）。読み終えた中身は `@State pendingImport: InkImport.Outcome?` に持つ。取り込みそのもの（`SyncEngine.importPages`）は変えない。1.1 の端末では 20,000 本を超えても全部表示されるので、止めずに確かめるだけ。

### 5.3 設定 › 情報「いちばん線の多いページ」「今年の年のページ」（U、K の関数）

- `InkPageStore.peek(_:)`（U、`Persistence/InkPageStore.swift` に足すだけ）: `load` と同じファイルを読み、`InkPageCodec.decompress` して `JSONValue` にし、`strokes`（オブジェクトならキー、配列なら各要素の `id`）のうち `deleted` に無い id の集まり（1.1 の保存では墓標の付いた線は `strokes` に残らない、`InkPage.swift:129-143`）と、`deleted` のキーの数を返す。`InkPage` は作らない（読む上限で切り詰めない）。ファイルが無い・読めない・伸長できないときは **nil を返すだけで、`.bak` へ移さない・消さない**（`load` の `moveAside` を通らない）。数えるだけの処理が、保存の途中のファイルや利用者のファイルを書き換える経路を持たないため。
- `StrokeCensus.run(store:year:)`（U、`Persistence/StrokeCensus.swift`）: `store.allPageIds()` の各ページを `peek` し、`StrokeBudget.Entry(pageId:, strokes: strokeIds.count, tombstones:)` を集め、`Result(largest: StrokeBudget.largest(entries), year: "y-<year>" の Entry（無ければ nil）, unreadable: nil だったページの数)` を返す。重い処理は `Task.detached(priority: .utility)` で走らせ、それを `withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }` で包む（`Task.detached` は `.task` の取り消しを受け継がないため）。detached の中ではページごとに `Task.isCancelled` を見て、取り消されたら nil を返す。設定を閉じると `.task` が取り消され、数えるのも止まる。NSLog `budget: largest=<id> strokes=<n> tombstones=<m> pages=<k> unreadable=<u> year=<id>:<n> maxTombstones=<id>:<m>`。写真モードでは `demo(year:)`（写真モードのお手本 4 ページから計算）。
- `StrokeBudget.largest`: strokes が最大（同数なら pageId の辞書順で小さい方）。空・全部 0 本なら nil。
- `StrokeBudget.pageLabel`: `PageNavigation.parse(pageId:)` で読めれば「年のページ（2026年）」「月のページ（2026年10月）」「週のページ（2026年10月5日〜10月11日）」（週は `PageNavigation.title(.week, focus:)` をそのまま括弧に入れる。月は両側に付く、`PageNavigation.swift:74-80`）「日のページ（2026年10月7日）」（祝日名・曜日は付けない）。読めない id はそのまま。`PageNavigation.parse`: `"d-YYYY-MM-DD"` → (.day, その日)、`"w-YYYY-MM-DD"` → (.week, その日)、`"m1-YYYY-MM"` → (.month, 1 日)、`"y-YYYY"` → (.year, 1/1)、ほか（`wb-`・日付が無効なもの）nil。`countText` は「12,345 本」（3 桁ごとに半角の「,」、ロケールに依らない）。
- `SettingsScreen` の情報の節（:492-505）の「バージョン」の行の後に 2 段の行を 2 つ: ①1 段目「いちばん線の多いページ」、2 段目（`.footnote`・`.secondary`）に `StrokeCensus.rowText(result?.largest, counting:)`（数え中「数えています…」、nil「まだ手書きがありません」、ある「月のページ（2026年10月）・3 本」）。②1 段目「今年の年のページ」、2 段目に `yearRowText(result?.year, year: DayKey(now).year, counting:)`（数え中「数えています…」、ある「年のページ（2026年）・12 本」、無い「年のページ（2026年）・0 本」）。どちらも 20,000 本を超えるときは後ろに「（古い版の端末では一部が表示されません）」。`.task` で数え始める。`Section("情報")` を `Section { … } header: { Text("情報") } footer: { Text(脚注) }` にする（脚注は §6.2）。写真モードの `info` シートでこの節までスクロールする（`scrollToSyncOnAppear` と同じ仕組み、§7.3）。本人の確認 17 は ② の数字を読む（K-9: 1.4 で年の重点欄を足す前に読む数字）。

## 6. 文言・規約類・App Store（担当 U・L・W・C）

### 6.1 画面の「この iPad」→「この端末」（U。コメントは除く）

| ファイル | 行 | 直し方 |
| --- | --- | --- |
| `Sync/SyncStatus.swift` | :73「この iPad のみ」、:93、:111、:115、:117、:119、:123、:127、:129 | 「この iPad」→「この端末」だけ（「ほかの iPad や iPhone」は両方の機種を名指ししているので残す） |
| `Sync/SyncStatus.swift` | :121 | 「「設定」アプリで iCloud を確認してください。手書きはこの端末の中だけに保存しています。」 |
| `Views/AccountChangeDialog.swift` | :21、:23 | 「この端末」 |
| `Views/CalendarRootScreen.swift` | :637、:1147 | 「この端末では…」「この端末の分は消しました」 |
| `Views/OnboardingView.swift` | :54（2 か所）と同じ文の「（iPad でサインインしていれば…）」 | 「この端末」「（この端末でサインインしていれば自動で使われます）」 |
| `Views/OnboardingView.swift` | :25 | 1 文目「このアプリは、この端末の「カレンダー」に入っている予定を表示します。」、2 文目以降は下の `googleHowTo` と同じ文 |
| `Views/OnboardingView.swift` | :38 | 「iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定はこの端末の中だけで扱い、開発者やほかの誰にも送りません。」 |
| `Views/SettingsScreen.swift` | :278 | 「この端末では制限されています」 |
| `Views/SettingsScreen.swift` | :400 行名 | **「この端末の手書きを全て消す」** |
| `Views/SettingsScreen.swift` | :419、:420 | 「この端末と iCloud に保存した手書きを全て消しますか？」「この端末に保存した手書きを全て消しますか？」 |
| `Views/SettingsScreen.swift` | :572 `readOnlyFooter` | 列挙の中の行名を「この端末の手書きを全て消す」に |
| `Views/SettingsScreen.swift` | :58 `googleHowTo` | 「Google カレンダーの予定を出すには、「設定」アプリで Google アカウントを追加します。」、括弧を「（iOS・iPadOS 17 では「設定」→「カレンダー」→「アカウント」）」に。残りは同じ |
| `project.yml` | :64（C）・`docs/PRIVACY.md:108`（L）・DESIGN §4.1（C） | 3 つそろえて「カレンダーの予定を手帳のページに表示し、手書きから予定を作るために使います。iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスをお願いしています。予定はこの端末の中だけで扱い、外部には送りません。」 |

**変えない**: `SettingsScreen.swift:317`（「手書きは iPad と Apple Pencil で書くのに向いています」— 勧めとして正しい）、`:327` と `OnboardingView.swift:46` の Apple Pencil の話（iPad の設定）、`PaywallSheet.swift:53`（両方を名指し）、`SettingsScreen.swift:61`「手書きを書き出す（iPad アプリ用）」（Web 版のボタン名）。`PaywallSheet.swift:41`（購入画面の宣伝の文「iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。」）は **本人の返事しだい**（M7A-6。既定は変えない）。「変える」なら U が :41 を「iPad・iPhone のカレンダーの上に、Apple Pencil や指で自由に書ける手帳です。」にし、`PaywallSheetTests.swift:124` の期待を同じ文に、C が DESIGN.md:769 に注記（購入画面の写真 `*-sheet-paywall`・`store/*/05-paywall` が変わるので §8 の 3 の例外に足す）。確かめ: `grep -rn 'この iPad' Sources project.yml | grep -v '//'` が 0 行。

### 6.2 新しい文言（固定）

| 場所 | 文言 |
| --- | --- |
| しまうボタン | 字「しまう」（記号 `chevron.down` の下、10 pt）、読み上げ「ツールバーをしまう」 |
| 丸ボタン | 名前「ツールバーを出す」、値「ペン・黒・中」など、ヒント「長押しで、右下へ移すか、ツールバーをいつも出すかを選べます」（右下にあるときは「左下へ移すか」） |
| 丸ボタンのメニュー | 右下へ移す ／ 左下へ移す ／ ツールバーをいつも出す |
| 消しゴムの説明 | 「触れた線をまるごと消します」、戻るときは後ろに「（消すとペンに戻ります）」か「（消すとマーカーに戻ります）」 |
| 設定 › 入力 | 行「消しゴムで消したらペンに戻る」。脚注（`eraserAutoReturnFooter(isPad:)`）: iPhone「ツールバーで選んだ消しゴムで線を消して指を離すと、直前のペンかマーカーに戻ります。」、iPad「ツールバーで選んだ消しゴムで線を消して指や Apple Pencil を離すと、直前のペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムは戻りません。」（iPhone の設定は Pencil の文を出さない、`SettingsScreen.swift:107, 319-329` と同じ考え方） |
| 上限 | メモ欄はここまでです |
| 日の extra で予定 | 24 時の下の自由メモ欄では予定を作れません |
| 日の紙の見出し | 自由メモ |
| 15,000 本 | このページに書いた線が 15,000 本を超えました。1 ページに書ける線は 19,000 本までです。 |
| 19,000 本 | このページはいっぱいです（線 19,000 本）。線を消すと、また書けます。 |
| 取り込みの確かめ（§5.2） | 見出し「線がとても多いページがあります」、本文「取り込むと、線が 20,000 本を超えるページがあります（{ページ名を「、」でつなぐ。4 つを超えたら「ほか n ページ」}）。この版では全部表示されますが、古い版の端末ではその一部が表示されません。取り込みますか？」、ボタン「取り込む」「やめる」 |
| 設定 › 情報 | 行「いちばん線の多いページ」、値「数えています…」／「まだ手書きがありません」／「月のページ（2026年10月）・3 本」。行「今年の年のページ」、値「数えています…」／「年のページ（2026年）・12 本」／「年のページ（2026年）・0 本」。20,000 本を超えるときは値の後ろに「（古い版の端末では一部が表示されません）」。脚注「線の数は、この端末に保存されているページを数えたものです（どこにも送りません）。1 ページに書ける線は 19,000 本までです。」 |
| 初回案内 3 枚目の最後 | 「年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。」 |

### 6.3 規約類（L: `docs/TERMS.md` / `PRIVACY.md` / `SUPPORT.md`。平易な日本語。【】・「下書き」は書かない）

| 文書 | 場所 | 直す |
| --- | --- | --- |
| 3 つとも | 最終更新の行 | L が編集した日（YYYY年M月D日）。施行日の文は不変 |
| PRIVACY | :1 題名 | 「てがきカレンダー プライバシーポリシー（アプリ版）」 |
| PRIVACY | :3 要約 | 「iPad・iPhone 用のアプリ「てがきカレンダー」は、…手書きと設定は、あなたの端末（iPad・iPhone）の中と、あなた自身の iCloud にだけ…予定は端末の「カレンダー」から読み書きしますが…」（ほかは不変） |
| PRIVACY | :74 | 「この端末の手書きを全て消す」 |
| PRIVACY | :93 | 「アプリ版は、Google へのログインも…Google カレンダーの予定は iOS・iPadOS を通じて…」 |
| PRIVACY | :108 付録 B | §6.1 の許可の文 |
| TERMS | :19-20 第 2 条（M7A-5） | 「1. 本アプリは **iPadOS 17 以上の iPad** と **iOS 17 以上の iPhone** で使えます。手書きには iPad と Apple Pencil の使用を推奨します（iPhone では主に指で書きます）。」「2. Mac（Apple シリコン搭載）でも開くことができますが、補助的な利用（予定や手書きの確認など）を想定したもので、iPad と同じ使い心地は保証しません。Mac には Apple Pencil がないため、手書きはトラックパッドやマウスになります。」（「Apple Pencil 向けの機能は iPad だけ」とは書かない。Apple Pencil（USB-C）に対応する iPhone Duo が出ると誤りになる、計画 §6.2） |
| TERMS | :51 | 「この端末の手書きを全て消す」 |
| TERMS | ほかの「iPad」「iPadOS」 | 端末の意味なら「端末」か「iPad・iPhone」、OS なら「iOS・iPadOS」に（:3、:27、:31、:71-73、:81、:89-90、:93「端末のバックアップ」）。**:46 は「解約は iPad の「設定」」の「iPad の」→「端末の」と、括弧の中の OS 名「（iPadOS 17 では「Apple ID」）」→「（iOS・iPadOS 17 では「Apple ID」）」の 2 か所だけ**。解約の経路の文字列「「設定」›「Apple Account」›「サブスクリプション」」と、括弧の中の「「Apple ID」」は変えない。Apple Pencil の話は iPad のまま |
| SUPPORT | :3 要約 | 「このページは、iPad・iPhone 用のアプリ「てがきカレンダー」の問い合わせ窓口と…」 |
| SUPPORT | :96、:134 | 「この端末の手書きを全て消す」 |
| SUPPORT | :102-108「iPad を替えたとき」 | 見出し「iPad や iPhone を替えたとき」、本文の「新しい iPad」「古い iPad」→「新しい端末」「古い端末」 |
| SUPPORT | :114-116「iPhone や Mac でも使えますか？」 | 「iPhone でも使えます（iOS 17 以上）。手書きは指で書きます（ツールバーの「指でも書く」）。iPad と iPhone で同じ Apple Account の iCloud を使うと、手書きが同期されます。Mac でも開けますが、補助的な利用（確認・簡単な書き込み）向けです。Mac には Apple Pencil がないので、手書きはトラックパッドやマウスになります。」 |
| SUPPORT | :118 見出し | 「Web 版の手書きをアプリに移したい」（:122 の「手書きを書き出す（iPad アプリ用）」は **不変**。Web 版の機能名） |
| SUPPORT | FAQ の末尾に 3 つ | 「### ツールバーをしまうには？」本文「ツールバーの右端の「しまう」を押すと、左下の小さな丸ボタンになります。丸ボタンの左（道具の印）を押すとツールバーが出て、紙に書き始めると自動でしまいます。丸ボタンの ↶ は「元に戻す」です。丸ボタンを長押しすると、右下へ移したり、ツールバーをいつも出しておく形に戻したりできます。この設定は端末ごとに覚えます。」／「### 1 ページにどれだけ書けますか？」本文「1 ページに書ける線は 19,000 本までです（15,000 本を超えると一度だけお知らせします）。月のメモ欄と、日のページの 24 時の下の「自由メモ」は、下に書くとその下に白紙が続きますが、長さには限りがあります（iPad の月のページでおよそ 4 画面分）。設定 › 情報 の「いちばん線の多いページ」で、今の本数を確かめられます。」／「### iPad と iPhone で版が違うと？」本文「日のページの 24 時の下の「自由メモ」は 1.1 からの機能です。1.0 のままの端末では表示されませんが、消えてはいません（その端末を新しい版にすると表示されます）。24 時の近くに書いた線や、投げなわで 24 時の下へ動かした線も、古い版では見えません（消えてはいません）。iPad と iPhone の両方を最新の版にしてお使いください。なお、古い版の端末で「手書きを全て消す」をすると、その欄の手書きも消えます。」 |

確かめ: `grep -n 'この iPad\|iPad アプリ版\|iPad アプリに' docs/TERMS.md docs/PRIVACY.md docs/SUPPORT.md` が 0 行、`grep -c '手書きを書き出す（iPad アプリ用）' docs/SUPPORT.md` が 1、`grep -c '「設定」›「Apple Account」›「サブスクリプション」' docs/TERMS.md` が編集の前と同じ。価格・試用・解約の経路（上の文字列）・連絡先・氏名は触らない（:46 の「iPad の」と括弧の OS 名だけは上の表のとおり直す）。

### 6.4 Web の HTML（W、Web リポジトリ、ブランチ `m7a-legal`。main（7f31727）から切る）

- `app/terms.html`・`app/privacy.html`・`app/support.html` を L の Markdown と文字単位で一致させる（M5・M6 と同じ様式。`<script` 無し、`.md"` 無し、CSP の meta そのまま）。`app/index.html` の :7（title）、:29（h1）、:30（meta）と各ページの `.meta` の「てがきカレンダー（iPad アプリ版）」→「てがきカレンダー（アプリ版）」、最終更新を L の日付に。
- `support.html:132` の見出しの id は新しい見出しから作り直す（`web-版の手書きを-アプリに移したい`）。古い id へのリンクがリポジトリの中に無いことを grep で確かめる（あれば直す）。:135 の「手書きを書き出す（iPad アプリ用）」は **不変**（`tests/app-pages.test.mjs:41` のテスト (5) が要求）。
- `README.md:9-11` のリンク名「iPad アプリ版の…」→「アプリ版の…」、:27 の「iPad アプリ版の「Web 版の手書きを取り込む」」→「アプリ版の…」（機能名「手書きを書き出す（iPad アプリ用）」は不変）。`package.json`（1.0.6）・Web 版のアプリ本体は不変。
- `tests/app-pages.test.mjs` に **(9) 新規**: `app/*.html` に「この iPad」と「iPad アプリ版」が **無い**、`support.html` に「1 ページにどれだけ書けますか」がある。(1)〜(8) は不変。`npm test` 緑、`npm run check:legal` 緑。
- commit だけ（push しない・merge しない）。リードが **1.1 を App Store で公開した日**（手動リリースの直後）に差分を読んで main に merge し、Pages の配信後に `curl -sI` で 4 URL が 200 を確かめる。順番の理由: 1.0.1 の利用者の画面にはまだ「この iPad の手書きを全て消す」があり、公開ページが先に「この端末の…」と言うと食い違うため。

### 6.5 App Store（リードが Connect に入力、提出は本人）

**このバージョンの新機能**:
> ・ツールバーをしまえるようになりました。ツールバーの右端の「しまう」で左下の小さな丸ボタンになり、紙を広く使えます。丸ボタンの道具の印を押すとツールバーが出て、紙に書き始めると自動でしまいます（丸ボタンの長押しで、右下へ移す・いつも出す形に戻すを選べます）。
> ・ツールバーで選んだ消しゴムで線を消して離すと、直前のペンかマーカーに自動で戻ります（設定 › 入力 で切り替えられます）。
> ・月のメモ欄は、下に書くとその下にさらに白紙が続きます。日のページを下へスクロールすると、24 時の下に新しく「自由メモ」の欄があり、ここも下へ書き足せます。
> ・「指でも書く」がオフのとき、月と年のページの日付を指でタップしやすくしました。
> ・年のページの左端の 1〜31 の数字をタップすると、その年の今月のその日のページが開きます。
> ・アプリを開き直しても、前に選んだペンの色と太さで書き始めるようにしました。
> ・iPad と iPhone の両方で使っている方は、両方をこの版にしてください（古い版では日のページの「自由メモ」が表示されません。消えてはいません）。

4 行目を「「指でも書く」がオフのとき」に限るのは、本人の iPhone の既定（オン）では月の 1 回タップが 1.0 と変わらないため（M7A-1。本人が「広げる」と答えたら、その答えに合わせて 4 行目を直す）。オフの iPad の年の的が広がること（M7A-2）もこの行に含まれる。

**審査メモ**: 「ツールバーの折りたたみ、消しゴム使用後の自動復帰、メモ欄の拡張、日付のタップ範囲の拡大を追加しました。データの扱いは変わりません（収集なし）。確認方法: 画面下のツールバーの右端の「しまう」でツールバーが左下の丸ボタンになります。日のページを下へスクロールすると、24 時の下に「自由メモ」の欄があります。」＋英語の要約「This update adds a collapsible toolbar, an automatic return from the eraser to the pen, memo areas that grow downward (including a new free memo area below 24:00 on the day page) and larger tap targets for dates. Data handling is unchanged: the app collects no data. To check: the 「しまう」 (fold) button at the right end of the toolbar folds it into a small round button at the bottom left; scroll the day page down to find the free memo area below 24:00.」。App Privacy・年齢区分・価格は変えない（掲載写真に価格を入れない、M6 §4.6 の教訓）。掲載写真の差し替えは M7A-11（既定は差し替えない）。

## 7. テスト・CI・写真

### 7.1 KitChecks（K、`TegakiKit/Sources/KitChecks/main.swift`）

- **既存の直し**（一覧。K は `PaperSpec`・`PaperGrowth`・日の `extra`・`memoHeight`・`maxStrokes` を入れた直後、既存の確認を直す前に KitChecks をこの Mac で走らせ、赤い行の一覧を docs/M7A.md に写してこの一覧と突き合わせる。一覧に無い赤があれば、直す前に理由を書く）:
  - :104 `memoHeight(inkBottom: 900)` 950 → **1,500**（:103 の 0 → 700 は不変）。
  - :335-336 月の `inked.memo.height` 950 → **1,500**、`inked.size.height` `1050 + 137 + 950` → `1050 + 137 + 1500`。
  - :1074-1080 の日: 大きさ 1000 × **3,100**、`cells.count` 1 → **2**、`grid`・`timeline`・`memo` は 2,400 のまま、`extra` = (0, 2400, 1000, 700) の行を足す。
  - :1140 `cell(at: (100, 2400))` nil → **`.extra`**（y 3,100 で nil の行を足す）。
  - :1147 `inkCell(forCenter: (2000, 9000))` `.grid` → **`.extra`**（「紙の下の線 → extra」）。
  - :1154 `band(atY: 2400)` nil → **`.extra`**（y 3,100 で nil の行を足す）。
  - :1168 `busy.size.height` 2,400 → **3,100**（帯では紙が伸びない、の意味はそのまま）。
  - :1177 `inked.size.height` 2,400 → **3,100**（`grid` の手書きでは伸びない。`extra` の最小 700）。:1180 の `inked == page` は通る（`extra` の下端が無い）。
  - :2845 は値が 1000 × 2400 のまま通る。**説明の文だけ** "overview: day = the whole paper" → "overview: day = the 24-hour grid (K-6)"。:2857 は fitZoom 用のヘルパーの値なので直さない。
  - **直さない**: :1557-1561 と :1776-1849 の `eventRange`（0-4。紙が 3,100 になっても `eventRange` を変えないので通る）、:3055-3145 の日の `centeringInsets` と `PaperViewport.initial`（大きさを数字で渡している）。
- **新しい節**（「app export (M6)」:4056 の後、Summary の前）: `section("growing paper (1.1)")`（§3.1 の表の 11 点、有限でない・負の b、`needsMoreRoom` の境目、`reachesCap` の 5,600 / 5,601 と NaN、`drop` の 4 通り（中・紙の外・上限・上限より長い紙の中の上限下）、`onlyTailHeightChanged`（月のメモだけ true・月の行 false・日の extra true・週 false・pageId 違い false・幅違い false）、日の 10 関数（§3.3 の表。`startsBelowDay` の minY 2,399.9 / 2,400 と NaN）、`overviewSize` の日、K-1（`extra` が `BandMigration.isBandCell` で false）、`scrollDelta` 0）、`section("date taps (1.1)")`（`minTarget` の 4 × 2 × 2 の表、§4.2 の 5 機種の的の端、月の外の日・メモ欄・紙の外、年の iPad オフ 44 pt、ガターの行全体と数字の上（中心 ± 14 の内と外。**小さい画面では「指でも書く」オンでも行全体**、大きい画面のオンだけ数字の上）、11 月の 31 → nil、2028 年 2 月 29 日 → `.date`、month 0・13 → nil、倍率 NaN・0・負で年は `hit(at:)` ＋ ガター、月は `hit(at:)`）、`section("stroke budget (1.1)")`（`budgetCount` が知らない tool を数える、`accepted` の境目 18,999 / 19,000 / 19,001、`crossesNotice`、`largest` の同数、`pageLabel` の 4 種（週は「〜10月11日」）と読めない id、`countText`、`PageNavigation.parse` の 4 種と無効、**`InkPage(json:)` が 20,500 本を全部読む・60,001 本はキーの辞書順で前の 60,000 本**、`importExceedsLegacyCap` の和集合・墓標・境目 20,000 / 20,001、`WebImport` の 1 ページはこれまで通り 20,000 本）、`section("compat with 1.0 (K-7)")`（`Compat10Checks.run` の結果を 1 項目ずつ数える ＋ 凍結した写しの sha256 を `FROZEN.sha256` と照合）。見込み +380〜480 件。
- 引数 `--write-compat-fixtures [--out <フォルダ>]` で `CompatFixtures` が K の fixture と `digests.json` を書く（既定は `TegakiKit/Tests/Fixtures/compat11/`。この Mac で作り直して commit できる。`screenshot-*`・`ledger-*` は書かない・消さない、0-23）。
- **閾値の規則**: K が実数 N を docs/M7A.md に書き、C が **N − 50** を build.yml :67-74 に入れる（1.0.1 の実数 23,446、今の閾値 23,336。R1_0_1.md §5）。

### 7.2 XCTest（役割ごと。名前は固定）

| 担当 | ファイル | テスト |
| --- | --- | --- |
| K | （全体） | 着手の直後（§7.1 と同じ時点）に、`swift test` の赤い行を最初の CI の結果から docs/M7A.md に写し、下の「直す」の一覧と突き合わせる（XCTest はこの Mac では走らない）。一覧に無い赤は直す前に理由を書く |
| K | `TegakiKit/Tests/LayoutTests/PaperGrowthTests.swift`（新規） | `testTailHeightSteps`（§3.1 の表）、`testTailHeightKeepsTheOneZeroRule`（どの b でも ≥ b + 50、b ≤ 5,600 で白紙 ≥ 400）、`testNeedsMoreRoom`、`testReachesCap`（5,600 false・5,601 true・NaN・負 false）、`testDropReasons`、`testOnlyTailHeightChanged` |
| K | `DayLayoutEngineTests.swift` | 直す: :20（大きさ 1000 × 3,100）、:24（`cells.count` 2）、:71（`busy` 3,100）、:142（y 2,400 → `.extra`）、:149（`inkCell(2000, 9000)` → `.extra`）、:162（`band(atY: 2400)` → `.extra`）、:175（「手書きで紙は伸びない」→ `grid` の手書きでは伸びない、3,100）、:193（`tomorrow` 3,100）。:21-23・:26 は不変。新規 `testExtraCellAndBands`、`testExtraGrowsWithInk`、**`testStartsBelowDay`**（minY 2,399.9 → false、2,400 → true、`extra` から上へのドラッグ（正規化で minY が 24 時より上）→ false、NaN → false、同じ矩形の `eventRange` は今のまま 23:00〜24:00）、`testInkCellBelow24IsExtra`、`testOldCellsKeepTheirRects`（K-4） |
| K | `EventRangeTests.swift` | **直さない**（:178-182 の 24 時の確かめと :435- の乱数の不変条件は、`eventRange` を変えないので紙が 3,100 になっても通る。0-4） |
| K | `MonthLayoutEngineTests.swift` | 直す: :74（`memoHeight(900)` 950 → 1,500）、:396（`inked.memo.height` 950 → 1,500）、:397（`1187 + 950` → `1187 + 1500`）。:395 は不変。新規 `testMemoGrowsInSteps`、`testHitWithMinTarget`（5 機種・チップとバーが先・月の外の日・メモ欄 nil）。`MonthLayoutTests.swift` は DayKey のテスト（`testWeekdays` など）なので触らない |
| K | `YearLayoutEngineTests.swift` | 新規 `testGutterDay`、`testGutterHitUsesTheGivenMonth`（無い日 nil・閏年）。1.0.1 の `testDateTargetIsAtLeast44PointsOnScreen` は不変 |
| K | `ZoomPolicyTests.swift` | :59 は値が 1000 × 2400 のまま通る。**説明の文だけ** "day: the whole paper" → "day: the 24-hour grid (K-6)"。:20 はヘルパーの値なので直さない |
| K | `DateTapTests.swift`（新規） | `testMinTargetRule`（§4.1 の表）、`testTargetOrderOnTheYearPage`、`testMonthTargetOnlyWhenFingerDrawingIsOff`、`testGutterIsTheWholeRowOnASmallScreen`（iPhone の倍率で「指でも書く」オンでも行全体、iPad 全画面のオンは数字の上だけ）、`testWeekAndDayAreUnchanged` |
| K | `PageNavigationTests.swift` | 新規 `testParsePageId` |
| K | `TegakiKit/Tests/InkModelTests/StrokeBudgetTests.swift`（新規） | `testBudgetCountIncludesUnknownTools`、`testAcceptedAndNotice`、`testLargestAndLabels`（週は「週のページ（2026年10月5日〜10月11日）」）、`testNewReaderKeepsMoreThan20000`（20,500 本 → 20,500 本、60,001 本 → 60,000 本）、`testImportExceedsLegacyCap` |
| K | `TegakiKit/Tests/Compat10Tests/*` | `Compat10FrozenSourceTests.testFrozenFilesMatchTheirDigests`（`FROZEN.sha256` だけ）、`Compat10FixtureTests.testFixturesAreWhatTheNewCodeWrites`（K の fixture だけ。`TEGAKI_UPDATE_FIXTURES=1` のときだけ書き直す）、`Compat10ReadTests.testEveryFixtureRoundTripsByteIdenticalThrough10`・`testNewReaderReadsWhat10Writes`・`testMissingLargeFixtureCountsAsAFailure`（一時フォルダに n20500 を置かない → failed ≥ 1）、`Compat10MigrationTests.testNoNewPageIsTouchedByBandMigration10`・`testLegacyBandStrokeStillMovesToGrid`、`Compat10MergeTests.testMergeWith10PageKeepsExtraAndMemo`・`testMergeIsByteIdenticalIn10AndNow`（種を決めたページの組 500 個。`extra`・`memo`・知らない項目を含む）、`Compat10DrawTests.testDayExtraIsNotDrawnNorErasableOn10`・`testMonthDeepMemoIsDrawnOn10`・`testMemoFrom10BelowTheCapStaysVisible`・**`testGridStrokeMovedBelow24IsHiddenOn10`**（`d-2026-11-04.moved.json`。元は墓標、写しは知らないマスで描かれない）、`Compat10SessionTests.testDisplayingANewPageOn10DoesNotRewriteIt`・`testEditingGridOn10KeepsExtra`・`testMergeRemoteOn10DoesNotMarkDirtyForAnIdenticalPage`、`Compat10BudgetTests.test15000StrokesSurvive10`・`test20000CapKeepsTheSmallestIds`・`testUnknownToolStrokesCountTowardTheCap`・`testTombstoneCapKeeps200000`・**`testNewDeviceRestoresWhat10Truncated`**（1.1 の 20,500 本 → 1.0 の写しが読んで書き戻す（20,000 本・墓標 0）→ 1.1 が読んで元と merge すると 20,500 本）・`testDecodeTimeOf15000Strokes`（`measure` で測るだけ、失敗にしない）、`Compat10ExportTests.testExport11ImportsOn10Equal` |
| T | `Tests/TegakiCalendarTests/ToolbarLogicTests.swift`（新規） | `testToolAfterEraseTable`（origin 3 × 消した数 0/1/3 × 設定 2 × 直前 ペン赤太/マーカー × **今の道具 消しゴム/投げなわ/ペン**。今の道具が消しゴムでなければ nil = 待ちの間に道具を変えたら戻さない）、`testModeTransitions`（§2.1 の表）、`testToastPaddingAndClearance`、`testBadgeForEveryTool`（6 色 × 3 太さ、4 色、消しゴム・投げなわ・予定、表に無い色）、`testRememberedPen`（保存した赤・太 → 赤・太、無い値 → 黒・中、表に無い色・太さ → 黒・中）、`testEraserHint`（nil・ペン・マーカー）、`testKindMatchesTheToolbar`（太さ 18 以上がマーカー） |
| T | `AppSettingsTests.swift` | 新規 `testEraserAutoReturnDefaultsToOn`（無い・true・false）、`testToolbarKeys`（collapsed の既定 false、edge の既定 leading、知らない値 → leading）、`testStrokeBudgetNoticed`（記録・500 件で古い方を捨てる） |
| P | `InkCanvasViewTests.swift` | 新規 `testTailOnlyGrowthKeepsTheDrawing`（月のメモに下端 500 の線 → 組み直し → `setDrawingCount` が増えない、`contentSize.height == (1050 + 1100) × zoom`、**iPhone 402 × 591 の一覧で縦の inset 44 → 0**。0-6 と軽い経路はこのテストと次のテストだけで確かめる。写真ではこの経路を通らない、§7.4）、`testTailOnlyShrinkClampsTheOffset`、`testDayExtraGrowthUsesTheTailPath`（紙の絵が同じでも形だけで軽い経路に入る＝ :609 と :640 の条件）、`testRowGrowthStillRebuilds`（月の日のマスが伸びる → `setDrawingCount` + 1。既存の横向きのテスト :455 も今の経路のまま）、`testEraseEndedIsReportedOnceAfterTheLift`（Begin → 消しゴムで 1 本消す変更 → End → `settleDelay` 後に `onEraseEnded(1)` が 1 回）、`testErasesWithinTheSettleWindowAddUp`、`testEraseEndedIsNotReportedForNothingErasedUndoReadOnlyDotsOrPen`、`testPenDownIsReported`（キャンバスと overlay）、`testNewStrokesBeyondTheCapAreDropped`（`onGrowthCapReached` 1 回、上限より長い紙の中でも捨てる）、`testCapNoticeWhenTheTailReachesItsLastStep`（メモ欄の下端 5,601 の線を足す → 捨てずに `onGrowthCapReached` 1 回。5,600 では来ない）、`testStrokesOverTheBudgetAreRefused`（**19,000 本はレイアウトに無いマス（例 `CellKey(raw: "zz-budget")`）に置く**＝ `budgetCount` には数えるが描かないので PKStroke を 19,000 本作らない。新しい 1 本だけを紙の上に足す → 外れて `.full(19000)`。14,999 本に 1 本で `.many(15000)`。取り消しでは止めない）、`testBottomClearanceAddsToTheBottomInset`、`testDotsFromAnotherDeviceAreNotCandidates`（t が 1 時間先の小さな線を `reload` で入れる → `dotStrokeIds` に出ない・`fingerTapped` で消えない）、`testEraserTapThatLeavesThePageRestoresWhatItErased`（消しゴム・「指でも書く」オン・移るタップ: そのタップで消した線が新しい id で戻ってから `onTap`、`onEraseEnded` は来ない。移らないタップ・読み取り専用・前の触れ方で消した分は戻さない）。**直す**: 1.0.1 の `testDotsDrawnByTheDoubleTapAreFound`（:571）と `testLeavingFingerTapRemovesItsDotBeforeReporting`（:602）は、点を `t` ではなく `noteRecentAdd(id, at:)` で登録し、`clock` の代わりに `uptime` を固定する形に（期待する id の組と 1 秒の窓は同じ）。既存 `testDefaultArgumentsOfTheNewParameters`（:838）に 5 行 |
| P | `InkLedgerTests.swift` | 直す: :302（日の `cells.count` 1 → 2、説明「grid と extra」）。新規 `testNeedsMoreRoomFollowsTheStepRule`、`testAdoptKeepsFingerprints`（adopt の後、同じ絵の `applyCanvasChange` が空）、`testUndoIfTopRestores`（一番上が別の op なら何もしない）、**`testLedgerWritesTheCompatShapes`**（1.1 の `DayLayoutEngine`・`MonthLayoutEngine` のレイアウトで、紙の y 2,430〜8,350 の PKStroke・23 時台の PKStroke・月のメモ欄の深い位置の PKStroke を `applyCanvasChange` に通し、`grid` の 1 本を `moveStrokes` で 24 時の下へ動かす。cell が `.extra` / `.grid` / `.memo` であること、点がマス相対（日の extra は紙の y − 2400）であること、線に新しい項目が無いことを確かめる。`makeId` と `nowMs` を種から決め、`deviceId` を固定して、ページの JSON を `Tests/Fixtures/compat11/ledger-day.json`・`ledger-month.json`（`#filePath` から）と 1 バイトずつ比べる。無い・違うときは `$TEGAKI_FIXTURE_OUT` に書いて失敗。最初の 1 回は CI の成果物から中身を見て commit する。OS の版が変わって点の丸めが変わったら、差を見て更新する） |
| P | `PaperViewTests.swift` | 新規 `testDayPaperStopsTheTimelineAt24`（週末の日の紙: (100, 2,300) は時間軸の色、(100, 2,500) は紙の色、y 2,400 に濃い線、「自由メモ」の字） |
| P | `ExportBuilderTests.swift` | `testPDFRendersEveryKind` の日の高さを「`extra` に手書きが無ければ 2,400」に、新規 `testDayPDFIncludesTheExtraOnlyWithInk` |
| U | `CalendarRootScreenTests.swift` | 1.0.1 の `testTapTargetUsesTheOnScreenMinimumOnlyOnTheYearPageOfASmallScreen`（:132）を **`testTapTargetRules`** に書き直す（§4.1 の表の 8 通り × 年・月・週・日。iPhone の倍率で年の 10/7 の真ん中 → `.date`、月の 10/14 のマスの上 40 % → オフで `.date`・オンで nil、日付の字 → どちらも `.date`、ガター 15 の行の端（数字の外）→ iPhone ではオンでも `.date(2026-10-15)`（currentMonth 10）・iPad 全画面のオンでは nil、11 月に 31 → nil）。`testTheMinimumTapTargetIsForSmallScreensOnly`（:114）は不変。新規 `testLeavesPageForGutterDates`、`testToastTexts`（§6.2 のトースト 4 つ）、`testEventBelowTheDayIsRefused`（日のページで `startsBelowDay` の矩形 → `openCreate` を呼ばずトースト、2,399.9 から始まる矩形は 23 時台の予定） |
| U | `SettingsScreenTests.swift` | :100 の期待を「この端末の手書きを全て消す」に、新規 `testInputAndInfoTexts`（入力の行と脚注の **iPhone と iPad の 2 通り**（`eraserAutoReturnFooter(isPad:)`）、情報の 2 行と脚注） |
| U | `ScreenshotModeTests.swift` | 新規 `testParseToolbarToolAndGrown`（`collapsed`・`collapsed-right`・知らない値 → nil、`eraser`・`marker`・`lasso`・`event`、`--screenshot-grown`）、**:297 の `Sheet.allCases.count` を 9 に、:298 の rawValue の一覧の最後に `"info"` を足す**、`testGrownDemoPages`（月のメモの線の下端 ≈ 1,009 → 欄 1,500、日の `extra` の線 → 欄 1,100、普段のお手本は不変）、`testDemoPagesMatchCompatFixtures`（`screenshot-*.json` と 1 バイトずつ比べ、無い・違うときは JSON を `$TEGAKI_FIXTURE_OUT` に書いて失敗。最初の 1 回は CI の成果物から Claude が中身を見て commit。作るのはこのテストだけ、0-23） |
| U | `SyncEngineTests.swift` | :150、:934、:943、:951、:954-958、:960、:961 の期待を §6.1 の文に（文言の行）。新規 `testMergeRemoteOfATruncatedPageMarksDirty`（`InMemoryCloudDatabase`: 端末に 20,500 本のページ、遠隔にその id の辞書順で前の 20,000 本だけの記録 → 取り寄せた後も端末のファイルは 20,500 本で dirty、送った記録が 20,500 本。`SyncEngine` は変えない、§5.1） |
| U | `StrokeCensusTests.swift`（新規） | `testLargestPageOfAStore`（一時フォルダの `InkPageStore` に 3 ページ）、`testEmptyStore`、`testRowText`、`testYearRow`（年のページがある・無い）、`testCountsBeforeTheReadCap`（20,500 本のページ → 20,500、後ろに「（古い版の端末では一部が表示されません）」）、`testPeekDoesNotMoveAnUnreadableFile`（壊れたファイル → nil、ファイルはそのまま、`.bak` ができない、`unreadable` 1）、`testCancellationStops`、`testPagesOverLegacyCap`（同じ id の取り込みは数えない） |
| U | `WebImportSheetTests.swift` | 新規 `testConfirmLargeTexts`（§6.2 の確かめの文、4 ページを超えたら「ほか n ページ」） |

### 7.3 写真モード（U、`Support/ScreenshotMode.swift`。`Config` :33-56、`parse` :63-95）

- `--screenshot-toolbar collapsed|collapsed-right` → `Config.toolbar`（`ToolbarShot.collapsed` / `.collapsedRight`。知らない値 → nil = 広げた状態）。
- `--screenshot-tool eraser|marker|lasso|event` → `Config.tool`（最初の道具。eraser は `EraserOrigin.toolbar` で始めるので説明に括弧が出る。`--screenshot-sheet lasso` の lasso が優先）。
- `--screenshot-grown` → `Config.grown`。お手本のページに 2 本足す: 月はメモ欄に赤の波線（`demo-stroke-memo-deep`、x0 60・y0 1,000、40 点、振れ幅 7 → 下端 ≈ 1,009 → 欄 1,500）、日は `extra` に黒の波線（`demo-stroke-day-extra`、x0 30・y0 300 → 欄 1,100）。**付けないときのお手本は 1.0.1 と 1 本も変えない**（紙の絵を変えないため。ツールバーの帯は 0-20）。
- `Sheet.info`（9 つ目）: 月のページで設定を開き、情報の節までスクロールする（`StrokeCensus.demo(year: 2026)` の値。お手本 4 ページの最大は同数 3 本で pageId の小さい日のページ → 「日のページ（2026年10月7日）・3 本」。今年の年のページはお手本の `y-2026` の本数 → 「年のページ（2026年）・n 本」。n は U が `testGrownDemoPages` の隣で固定し docs/M7A.md に書く）。
- 写真モードでは `init()`（`CalendarRootScreen.swift:212-235`）の `_page` を `ScreenshotMode.demoPage(kind:focus:)`、`_paper` をその `inkBottoms()` で作る（今は空のページと `inkBottoms: [:]`）。最初のレイアウトから伸びた紙になり、`--screenshot-offset` の clamp（最初のレイアウトだけで読む）が伸びる前の高さで決まらない。普段のお手本では紙の大きさが変わらない（月のメモの点は 700 のまま、日のマス・年のマスの線は行を伸ばさない）ので、今の写真の紙は変わらない。`appear()` → `show()` の読み込みは今のまま（同じ中身なので dirty にならない）。**このため写真モードでは §3.6 の軽い経路は通らない**（紙は最初から伸びた形で、読み直しは同じ形。iCloud の反映は signature が変わって `pendingDrawing` の重い経路）。軽い経路と 0-6 の確かめは XCTest だけ（§7.2 P）。
- 写真モードでは AppSettings のツールバー・消しゴム・案内の記録を読まない・書かない（M3b §4.0 の規則のまま）。

### 7.4 CI（C、`.github/workflows/build.yml`）

| 場所 | 変更 |
| --- | --- |
| 先頭のコメント :1-19 | 1.1 の 1 文（しまったツールバー・消しゴム・伸びたメモ・24 時の下・情報の写真、凍結した写しの確認、`compat-v1.0` のジョブ、`shots/fixtures`）、枚数を「up to 53 images + 5 logs + store/ + fixtures/」に |
| KitChecks :67-74 | 閾値を K の実数 − 50 に（コメントの数字も） |
| `swift test` の後 | 新しいステップ「Frozen 1.0 copy」: `cd TegakiKit/Tests/Compat10 && shasum -a 256 -c FROZEN.sha256`（写しの行だけなので、そのディレクトリで全部見つかる） |
| 「Run unit tests on the simulator」（:140-152） | `mkdir -p shots/fixtures` の後、xcodebuild を `TEST_RUNNER_TEGAKI_FIXTURE_OUT="$PWD/shots/fixtures" xcodebuild …` で呼ぶ（xcodebuild は `TEST_RUNNER_` の付いた環境変数だけを、接頭辞を外してシミュレータの test runner に渡す）。テストの中では `ProcessInfo.processInfo.environment["TEGAKI_FIXTURE_OUT"]`。書いた JSON は `shots/` の下なので「Upload screenshots」（:590-598、`if: always()`）が成果物に含める |
| 13 インチの 4 ページの節（:238-272、read-only の写真の後） | `shoot` 相当の 5 枚: `ipad13-portrait-toolbar-collapsed.png`（`--screenshot-page month --screenshot-toolbar collapsed`）、`-toolbar-collapsed-right.png`（`collapsed-right`）、`-tool-eraser.png`（`--screenshot-tool eraser`）、`-month-memo.png`（`--screenshot-page month --screenshot-grown --screenshot-offset 0,9999`。範囲内に収まって紙の下端が見える）、`-day-extra.png`（`--screenshot-page day --screenshot-grown --screenshot-offset 0,9999`） |
| 13 インチのシートのループ :282 | `for SHEET in create edit lasso settings sync import paywall export info`（9 つ。見出しの「8 sheets」→「9 sheets」） |
| 13 インチのログ :302 | `log show --last 8m` → **`--last 10m`**（写真が 16 枚から 22 枚に増える。:290 付近のコメントも） |
| 他機種の iPhone の節（:436-446、`if [ "$ID" = "iphone" ]` の中） | `shoot "$ID-portrait-toolbar-collapsed.png" … --screenshot-page month --screenshot-toolbar collapsed`、`"$ID-portrait-month-memo.png" … --screenshot-grown --screenshot-offset 0,9999`、`"$ID-portrait-day-extra.png" --screenshot-page day --screenshot-grown --screenshot-offset 0,9999`、横の `"$ID-landscape-month-toolbar-collapsed.png" … --screenshot-toolbar collapsed --screenshot-landscape`（横の写真を立て直すループ :448-452 に含める） |
| 他機種のログ :455 | `log show --last 6m` → **`--last 8m`**（iPhone は約 17 枚から約 21 枚に増え、40 秒の待ちと合わせて 6 分の枠ぎりぎりになる。`toolbar:`・`budget:` の行を取りこぼさないため） |
| ログの grep | `toolbar: safeArea=`、`toolbar: paperArea=`、`budget: largest=`、`canvas: tail-only`（**出なくてよい**。写真モードでは軽い経路を通らない、§7.3。出たら表示するだけ）を各ログから抜き出して表示。行の数の期待は置かない |
| 新しいジョブ `compat-v1.0`（macos-26、**`timeout-minutes: 45`**、`build` と並行） | ① `actions/checkout@v4` を 2 回（1 回目はこの commit、2 回目は `ref: a21e4692109e504701b507ad9c695181fdecddfd`・`path: v10`）。② 元の照合: `(cd v10 && shasum -a 256 -c ../TegakiKit/Tests/Compat10/ORIGIN.sha256)` と、`ORIGIN.ranges` の各行を `git -C v10 show HEAD:<パス> \| sed -n '<始め>,<終わり>p' \| shasum -a 256` で照合。③ 大きな fixture を作る: `mkdir -p "$RUNNER_TEMP/compat11" && cp TegakiKit/Tests/Fixtures/compat11/*.json "$RUNNER_TEMP/compat11/" && swift run --package-path TegakiKit KitChecks --write-compat-fixtures --out "$RUNNER_TEMP/compat11"`（K の分を書き、`digests.json` と照らし合わせる。P・U の fixture はコピーした分だけ）。④ `cp TegakiKit/Tests/Compat10/Checks/Compat10Checks.swift tools/compat10/Sources/RunReal/Copied-Compat10Checks.swift` と `LedgerV10.swift`、RunFrozen には写し全部（`LayoutFactsV10.swift` を含む）と Checks。⑤ `swift run --package-path tools/compat10 RunReal "$RUNNER_TEMP/compat11"` と `RunFrozen` → 2 つの `compat10: N checks, F failed` の N が等しく、F が 0、N ≥ `tools/compat10/EXPECTED_MIN` でなければ失敗。⑥ 1.0 のアプリ: XcodeGen を入れ、`cp tools/compat10/AppTests/Real10LedgerTests.swift v10/Tests/TegakiCalendarTests/`、`(cd v10 && xcodegen generate)`、build の「Pick a simulator」と同じ選び方で 13 インチの iPad、`TEST_RUNNER_TEGAKI_COMPAT_FIXTURES="$RUNNER_TEMP/compat11" xcodebuild test -project v10/TegakiCalendar.xcodeproj -scheme TegakiCalendar -destination … -only-testing:TegakiCalendarTests/Real10LedgerTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` |
| Store listing set（:541-588） | 手順は不変（元の写真の名前は同じ）。出来る JPEG はツールバーの帯が変わる（0-20。App Store へ差し替えるかは M7A-11） |

### 7.5 成果物（`screenshots`、7 日）

```
shots/
  ipad13-portrait-{month,week,day,year}.png / -{month,week,year}-zoom2.png / -readonly.png
  ipad13-portrait-toolbar-collapsed.png / -toolbar-collapsed-right.png / -tool-eraser.png / -month-memo.png / -day-extra.png   ← 新規（5）
  ipad13-portrait-sheet-{create,edit,lasso,settings,sync,import,paywall,export,info}.png                          ← info が新規
  ipadmini-portrait-*（4）・ipad11-portrait-*（5）・iphone69-portrait-*（5）                                         名前は不変
  iphone-portrait-{month,week,day,year}.png / -week-sun / -week-jun / -week-zoom3 / -readonly / -sheet-paywall.png
  iphone-portrait-toolbar-collapsed.png / -month-memo.png / -day-extra.png                                        ← 新規（3）
  iphone-landscape-{month,week,day,year}.png / iphone-landscape-month-toolbar-collapsed.png                       ← 新規（1）
  app-log.txt / iphone-log.txt / iphone69-log.txt / ipadmini-log.txt / ipad11-log.txt
  store/{ipad13,iphone,iphone69,ipad11}/…（20 枚、名前は不変。ツールバーの帯が変わる）・ui-tests/（1.0.1 のまま）
  fixtures/screenshot-*.json・ledger-*.json                                                                        ← 新規（テストが違いを見つけたときだけ）
```

合計: 画像 **53 枚**（1.0.1 の 43 ＋ 13 インチ 6 ＋ iPhone 4）＋ ログ 5 本 ＋ `store/` 20 枚 ＋ `fixtures/`（0〜8 個）。

## 8. 完了の定義

1. `swift build --package-path TegakiKit && swift run --package-path TegakiKit KitChecks` が「all N checks passed」（N ≥ 閾値。この Mac と CI）。`swift test --package-path TegakiKit`（Compat10Tests を含む）が CI で緑。`tools/typecheck/typecheck.sh` が警告 0 で通る（SwiftPM の「unhandled file」の警告も 0）。順序: K が N を docs/M7A.md に書く → C が閾値を入れる。**K は着手の直後に KitChecks（この Mac）と `swift test`（最初の CI）の赤い行の一覧を docs/M7A.md に写し、§7.1・§7.2 の「直す」の一覧と突き合わせてある**（一覧に無い赤には理由が書いてある）。
2. `compat-v1.0` のジョブが緑: 元の照合（`ORIGIN.sha256`・`ORIGIN.ranges`）、大きな fixture が `digests.json` と一致、本物の 1.0 と凍結した写しで同じ N・失敗 0・N ≥ `EXPECTED_MIN`、1.0 のアプリの `Real10LedgerTests` が緑。build の「Frozen 1.0 copy」が緑。
3. CI の `build` が緑: 13 インチのユニットテスト（§7.2 の T・P・U と 1.0.1 までのテスト。`StoreKitSessionTests` の 7 本は skip のまま可）と 1.0.1 の `YearTapUITests`、成果物に **53 枚 ＋ ログ 5 本 ＋ `store/` 20 枚**。
   - **最初の CI は赤になる予定**: `ledger-*.json`（P）と `screenshot-*.json`（U）はまだ無いので、`testLedgerWritesTheCompatShapes` と `testDemoPagesMatchCompatFixtures` が失敗し、`shots/fixtures/` に JSON を書く（ユニットテストが落ちるとその後の写真の段は走らない）。リードが成果物の中身を見て（`extra`・`memo` のマス、マス相対の点、知らない項目が無いこと）commit し、2 回目の CI で緑にする。docs/M7A.md に 2 つの run の番号を書く。
   - 1.0.1 の run の写真と 1 画素ずつ比べる。**ツールバーの帯（下の安全領域 ＋ 66 pt。横向きの iPhone も同じ）は全部の写真で違ってよいので、比べるときは除く**（右端に「しまう」が増える、0-20）。帯の外で違ってよいのは、新しい写真・`ipad13-portrait-sheet-{settings,sync}.png`（文言と行）・`store/ipad13/06-settings`・ステータスバーの日付・日の写真の下端 3 px 以内だけ（M7A-6 で購入画面の文を変えたときは `*-sheet-paywall.png`・`store/*/05-paywall` も）。結果を docs/M7A.md に。
   - 写真モードのログで、collapsed の写真の `toolbar: paperArea=` の高さが、同じ機種・同じページの広げた状態 ＋ 66 pt（± 0.5）（§2.2。docs/M7A.md に）。`canvas: tail-only` の行は出なくてよい（§7.3）。
4. `project.yml` の `MARKETING_VERSION` が 1.1、:64 の許可の文が §6.1。`grep -rn 'この iPad' Sources project.yml | grep -v '//'` が 0 行。main への merge の後に testflight.yml を 1 回走らせ、Connect に **1.1 (N)** が「有効」で現れる。
5. Web リポジトリ: `m7a-legal` で `npm test`（(9) を含む）と `npm run check:legal` が緑。merge は 1.1 の公開日（§6.4）。
6. リード（本人）が **次の写真を見て** 確かめる:

| 写真 | 見えていなければならないもの |
| --- | --- |
| `ipad13-portrait-toolbar-collapsed.png` | 月の一覧。下のツールバーが無く、左下に丸ボタン（黒・中のペンの点と ↶）。紙が下まで広い（一覧は幅で決まるので倍率は同じ、メモ欄が多く見える）。丸ボタンがホームバーに重ならない |
| `ipad13-portrait-toolbar-collapsed-right.png` | 同じで丸ボタンが右下（↶ が左、道具が右） |
| `ipad13-portrait-tool-eraser.png` | 広げたツールバーで消しゴムが選ばれ、説明「触れた線をまるごと消します（消すとペンに戻ります）」。右端の区切りの外に「しまう」（下向きの矢印と字） |
| `ipad13-portrait-month-memo.png` / `iphone-portrait-month-memo.png` | 紙の下端まで送った月: 6 行目の下にメモ欄、y ≈ 1,000 の赤い波線、その下に白紙（13 インチで約 360 pt、iPhone で約 140 pt）、紙の終わり。iPhone で上下に古い余白が見えない（**見た目の確認だけ**。写真の紙は最初から伸びた形なので 0-6 の確かめにはならない。0-6 は XCTest、§7.2 P） |
| `ipad13-portrait-day-extra.png` / `iphone-portrait-day-extra.png` | 日の下端: 24 時の太い区切り線、その下に「自由メモ」の字と 50 lu ごとの罫線（ページ幅いっぱい、左右に少し空き）、黒い波線、紙の終わり。時間軸の色と縦線は 24 時で止まる。**本人に見せて M7A-10 を聞く** |
| `ipad13-portrait-sheet-info.png` | 設定の「情報」節: 「バージョン 1.1 (1)」の下に「いちばん線の多いページ」「日のページ（2026年10月7日）・3 本」、「今年の年のページ」「年のページ（2026年）・n 本」、脚注 |
| `ipad13-portrait-sheet-settings.png` | 入力の節に「消しゴムで消したらペンに戻る」（オン）と iPad の脚注（Apple Pencil の文あり）。データの行名「この端末の手書きを全て消す」（画面内なら） |
| `ipad13-portrait-sheet-sync.png` | 同期の脚注が「手書きはこの端末と、あなたの iCloud に…」 |
| `iphone-portrait-toolbar-collapsed.png` | iPhone の月の一覧、左下の丸ボタン（下の安全領域の上、6 pt 空き） |
| `iphone-landscape-month-toolbar-collapsed.png` | 横向き（立て直した絵）。丸ボタンが左の安全領域の内側、ヘッダーは 1 行 |
| 既存の 43 枚と `store/` | 3 のとおり（ツールバーの帯を除いて同じ） |

7. 本人が TestFlight（1.1）で **実機**（iPad は Pencil と指、iPhone は「指でも書く」オン）:

| # | 端末 | 手順 | 期待 |
| --- | --- | --- | --- |
| 1 | iPad | ツールバーの右端の「しまう」 | 左下に丸ボタン（今の道具の印と ↶）、紙が下まで広がる |
| 2 | iPad | アプリを終了して開き直す | しまったまま、左下 |
| 3 | iPad | 丸ボタンを長押し →「右下へ移す」→ 開き直す | 右下のまま。iPhone では別に覚えている（端末ごと） |
| 3b | iPad | 丸ボタン（↶ の側を押してもよい）を長押し →「ツールバーをいつも出す」→ 開き直す | 広げたまま、右端に「しまう」。紙に書いてもしまわない（元に戻せることの確認） |
| 4 | iPad | しまった状態で、丸ボタンの左（道具の印）をタップ → 消しゴム → 紙で 1 本消す | 紙に触れた瞬間にツールバーがしまう（紙は大きさが変わらない）。離すとペンに戻り、丸ボタンの印もペン |
| 5 | iPad | ペン（赤・太）→ 消しゴム → 1 本消して離す | 赤・太のペンに戻る |
| 6 | iPad | 消しゴムで何も無い所をなぞる | 消しゴムのまま |
| 6b | iPad（Pencil） | 消しゴムで 1 語消し、離してすぐ（一呼吸おかずに）書き直し始める | 最初の線が書ける。書けない・消しゴムのままだったら教えてください（§2.4 の直し方のどちらかにします） |
| 7 | iPad | Pencil のダブルタップで消しゴム → 1 本消す | 戻らない（もう 1 回のダブルタップでペン） |
| 8 | iPad | 設定 › 入力「消しゴムで消したらペンに戻る」をオフ → 5 | 戻らない。説明の括弧が消える |
| 9 | iPad | 赤・太を選んだまま開き直して書く | 最初の線が赤・太（1.0 では黒・中になっていた不具合の直し） |
| 10 | iPad | 月のメモ欄の下の方に書いて離す（3 回ほど、毎回少し下へ） | そのたびに下に白紙が足される |
| 10b | iPad（余裕があれば。上限は CI でも確かめる） | さらに下へ 11 回ほど書き足す（13 インチで合わせて約 4,400 pt 下まで） | 「メモ欄はここまでです」が 1 回出て、それより下には白紙が足されない |
| 11 | iPad | 日のページを下へ送る → 24 時の下に書く | 「自由メモ」の欄に書ける。書くとさらに白紙が続く。ピンチで一番小さくすると 0〜24 時が収まり、それ以上は縮まない |
| 12 | iPad | 24 時の下の手書きを投げなわ →「予定にする」 | 「24 時の下の自由メモ欄では予定を作れません」 |
| 13 | iPhone（「指でも書く」オン、いつもの設定） | 月のページで、日付の数字そのものを指で 1 回。次に、マスの空いた所を指で 1 回、続けて 2 回 | 数字の 1 回: 日のページへ（点は残らない）。空いた所の 1 回: 何も起きない（M7A-1 で「広げる」と答えたときは日のページへ）。空いた所の 2 回: 日のページへ |
| 14 | iPhone・iPad | 「指でも書く」オフで、月のマスの上の方（日付の行の近く）を指でタップ | 日のページへ |
| 14b | iPad（「指でも書く」オフ、いつもの設定） | 年のページで、日付の字のすぐ近く（字の右や下、指先ひとつ分の範囲）を指で 1 回。次に、マスの右下の空いた所を 1 回、続けて 2 回 | 字の近くの 1 回: 日のページへ（1.1 で広がった、M7A-2）。右下の 1 回: 何も起きない。2 回: 日のページへ |
| 15 | iPhone（「指でも書く」オン、いつもの設定） | 年のページの左端の「15」を指でタップ（数字の少し上や下でもよい）。11 月なら「31」も | 今月の 15 日の日のページ。「31」は何も起きない |
| 16 | iPhone | 年のマスを指で 1 回・2 回（1.0.1 の確認の続き） | 今まで通り日のページへ |
| 17 | 両方 | 設定 › 情報 | 「いちばん線の多いページ」と「今年の年のページ」に名前と本数（**「今年の年のページ」の本数を教えてください**: 1.4 で年の重点欄を足す前に読む数字、K-9） |
| 18 | 両方 | 設定・同期・初回案内の文言 | 「この iPad」がどこにも無い。iPhone の設定 › 入力 の脚注に Apple Pencil の文が無い |
| 19 | 両方 | iPhone を 1.0.1 のままにして、iPad（1.1）で日の「自由メモ」と月のメモ欄の深い所に書く → iPhone で開く → iPhone も 1.1 に | 1.0.1 では日の「自由メモ」が見えない・月の深い線は見える。1.1 にすると「自由メモ」も見える（消えていない） |
| 20 | iPhone | しまう → 丸ボタン → 色を変えて書く → 何かのトーストを出す | 書き始めでしまう。トーストが丸ボタンに重ならない |
| 20b | iPhone（しまったまま） | 離れた 2 か所を続けて消す（丸ボタン → 消しゴム → 消す → 自動でペン → また丸ボタン → 消しゴム → 消す） | 手間に感じるかどうかを教えてください（面倒なら 設定 › 入力 で自動で戻らないようにできます） |
| 21 | iPhone（「指でも書く」オン） | 消しゴムを選び、線の上に重なった年のページの日付を指で 1 回 | 日のページへ移る。年のページに戻ると、その線は消えていない |

8. docs/M7A.md・README・DESIGN の注記が更新されている（C）: DESIGN §2.7（ツールバーの 3 状態と「しまう」）、§2.2（月のメモの式・日の `extra`「自由メモ」・日の一覧は 24 時間）、§3.4（マス `extra`）、§3.6（消しゴムの自動復帰・消しゴムのタップの取り消し）、§2.8（設定 › 入力 と 情報 の行）、§3.9（読む上限 60,000 本）、§4.1（許可の文）、§9（1.1 の行）。docs/M7_PLAN.md §2.7 に「式は M7A_CONTRACT D3 で `700 + 400k` に直した」、§1.3 の K-9 に「1.1 で読む上限を 60,000 本に上げた（M7A_CONTRACT §1.2・§5.1）」、§2.6・§4.1 に「1.0.1 の結果は R1_0_1.md」の注記。docs/M7A.md に KitChecks の N、着手直後の赤い行の一覧、写真の比較、安全領域と紙の領域の実測、`compat-v1.0` の N と `EXPECTED_MIN`、fixture を commit した run、本人の確認の結果、今年の年のページの線の数。

## 9. 本人の決定・未決

返事は「M7A-1 は既定で」のように短くて大丈夫です。返事が無いときは既定で進めます。

| # | 内容 | 既定（返事が無ければこうする） |
| --- | --- | --- |
| M7A-1 | iPhone（「指でも書く」がオン。いつもの設定）の月のページは、1.1 でも、日付の小さな数字（高さ 1 mm ほど）を叩いたときだけ日のページへ移ります（マスを 2 回叩けば移るのは今まで通り。iPhone では 1.1 の「タップしやすく」は効きません）。年のページのように、マスの上の方を 1 回叩いても移るようにしますか？ そうすると、月のマスに指で「・」や濁点のような短い線を書いたとき、日のページへ移ってしまうことがあります | **今のまま**（数字だけ。新機能の文は「「指でも書く」がオフのとき」と書く。「広げる」なら 1 行の直しで年と同じ規則にでき、新機能の文と確認 13 を直す） |
| M7A-2 | iPad（「指でも書く」がオフ。いつもの設定）の年のページで、日付を 1 回叩いて移れる範囲を、日付の字（今は約 5 × 3 mm）から指先ひとつ分（約 8 × 7 mm）に広げます。字の少し外（マスの左上の角あたり）を叩いても日のページへ移るようになります。1.0.1 では iPad は 1.0 のままにしていました（確認 14b） | **広げる**（月と同じ規則） |
| M7A-3 | 年の左端の数字で、今月に無い日（11 月の 31 など） | **何もしない**（月末へは移らない） |
| M7A-4 | 丸ボタンの長押し | **メニュー**「右下へ移す」「ツールバーをいつも出す」 |
| M7A-5 | 利用規約 第 2 条（今は iPhone を「補助的な利用」と書いている） | **iPad と iPhone を並べて書き直す**（Mac だけ補助的。「Apple Pencil 向けの機能は iPad だけ」とは書かない。§6.3。直した文をお見せします） |
| M7A-6 | 購入画面の文「iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。」は iPhone でもそのまま出ます。「iPad・iPhone のカレンダーの上に、Apple Pencil や指で自由に書ける手帳です。」に変えますか？ | **変えない**（宣伝の文で、iPhone でも意味は通じる。変えると購入画面の写真と App Store の 05 番の写真も変わる） |
| M7A-7 | 15,000 本の案内 | **ページごとに端末で 1 回** |
| M7A-8 | 1.0 の commit に `v1.0` のタグを付けて GitHub に送る | **送らない**（CI は commit の番号で 1.0 を取り出す。「付けて」と言われたら送る） |
| M7A-9 | 日の 24 時の下の欄の最小の高さ | **700**（月のメモ欄と同じ。iPad の日の一覧で 24 時の下に約 330 pt） |
| M7A-10 | 日のページの 24 時の下の新しい欄の名前を「自由メモ」にします（右の列の「メモ」と区別するため）。また、日のページを一番小さくしても 24 時の下は見えないので、下に紙が続くことが分かりにくいです。CI の写真（day-extra）を見て、一覧の下に自由メモを少し覗かせたほうがよいか教えてください | **「自由メモ」、覗かせない**（一覧は 24 時間で止める、K-6。新機能の文で「日のページを下へスクロールすると」と案内する） |
| M7A-11 | 1.1 では、広げたツールバーの右端に「しまう」が増えます。App Store に載せている写真（「しまう」が写っていない）を 1.1 の写真に差し替えますか？ | **差し替えない**（ツールバーの右端が少し違うだけで、機能の説明は変わらない。差し替えるなら CI の `store/` をリードが Connect に入れる） |

統合の順番: **前提**（リード: 1.0.1 を main に merge し、main から `m7a` を切る）→ **K**（`PaperSpec`・`PaperGrowth`（`reachesCap` を含む）→ 月の `memoHeight` → 日の `extra`・`startsBelowDay` → `ZoomPolicy` → `InkPage.maxStrokes` と `WebImport.maxStrokesPerPage` → **ここで KitChecks を走らせ赤い行を docs/M7A.md に** → 月の `hit(at:minTarget:)`・年のガター → `DateTap` → `StrokeBudget`・`PageNavigation.parse` → KitChecks の既存の直しと 3 節 → XCTest → `Compat10` の写しと `FROZEN.sha256`・`ORIGIN.sha256`・`ORIGIN.ranges` → `CompatFixtures` と K の fixture → `Compat10Tests` と KitChecks の互換の節 → `tools/compat10`（RunReal の別名と本物の Layout の関数、`Real10LedgerTests`、`EXPECTED_MIN`）→ typecheck.sh の手順 6 → 実数 N を docs/M7A.md に）と **T**（`ToolbarLogic` → `AppSettings` のキー → `ToolbarView` の「しまう」と説明 → `ToolbarDock` → テスト。既存のアプリのコードにだけ依存）と **L**（3 文書）を並行 → **P**（K の後: `InkLedger.needsMoreRoom`・`adopt`・`undoIfTopRestores`・`makeId`/`nowMs` → `pendingGeometry` と軽い経路・`applyInsets` → 上限と予算で捨てる・上限の知らせ → 消し終わりと `onPenDown` → 点の候補（`recentAdds`）と消しゴムのタップ → `bottomClearance` → `DayPaper` → PDF → テスト）→ **U**（K・T・P の後: 起動時の道具 → ツールバーの 3 状態とトースト → 消しゴムの接続 → `tapTarget` → トーストの 4 文と `startsBelowDay` → 設定の入力と情報・`InkPageStore.peek`・`StrokeCensus` → 取り込みの確かめ → 「この端末」の文言 → `ScreenshotMode` → テスト）→ **W**（L が固まってから。`m7a-legal`、`npm test` 緑）→ **C**（project.yml 1.1 と許可の文、build.yml、README、DESIGN と M7_PLAN の注記、docs/M7A.md、CI の写真と比較の確認）→ **リード**（最初の CI（赤の予定）の成果物から `ledger-*`・`screenshot-*` を見て commit → 2 回目の CI 緑 → main に merge → testflight.yml → 本人に TestFlight → §6.5 を Connect に入力 → 本人へ報告）→ **本人**（§8 の 7、§9 の返事、「審査へ提出」）→ **リード**（公開の日に Web の merge と URL の確認、M7A.md に結果）。

本人がやること（Claude が代行できない）: (1) §9 の返事（無ければ既定）。(2) CI の写真（§8 の 6）を見て、しまったツールバーと伸びたメモ・自由メモの見え方を判断する（M7A-10・M7A-11）。(3) TestFlight 1.1 で §8 の 7 の 1〜21（3b・6b・10b・14b・20b を含む。10b は余裕があれば）。(4) 設定 › 情報 の「今年の年のページ」の本数を教える。(5) 「審査へ提出」と、公開の日を決める（手動リリース）。

### 9.1 採らなかった指摘（第 2 版の見直し）

見直しの指摘は 43 件（blocker 1・major 14・minor 28。観点はコード・互換・本人の目）。下の 10 件（採らない・一部だけ・2 案のどちらかを選んだもの）のほかは、指摘のとおりに直した。

| 指摘（観点・重さ） | 扱い | 理由 |
| --- | --- | --- |
| `safeAreaInset` の modifier を `if` で付け外しする案（コード・minor） | 採らない | 付け外しすると View の同一性が変わり、`InkCanvasView` が作り直されて、線の台帳・拡大・スクロールの状態を失う。代わりに `spacing` を状態で切り替え（広げた状態は今と同じ既定）、写真モードのログで紙の領域の高さを確かめる（§2.2・§2.7） |
| TERMS :46 は「括弧も変えない」（コード・minor） | 一部だけ採る | 矛盾していた確かめの文は直し、解約の経路の文字列と「Apple ID」は変えない。ただし括弧の中の OS 名「iPadOS 17」は iPhone の利用者にも当てはまるよう「iOS・iPadOS 17」にする（端末の名前の言い換えで、規約の中身は変わらない）（§6.3） |
| iPhone の「指でも書く」オンでも月の的を広げる（本人の目・major） | 既定では採らない（指摘の 2 つ目の案を採った） | 計画 §2.6 の 6 の規則（オンなら字の枠だけ）のまま。年は 1.0.1 で広げたが、月のマスは字を書く場所で、指で書く「・」や濁点の短い線がタップになって日のページへ飛ぶおそれが年より大きい。新機能の文を「オフのとき」に限り、M7A-1 を平易に聞き直し、確認 13 の期待を直した。「広げる」の返事なら `DateTap.minTarget` の月を年と同じ `smallScreen \|\| !allowFinger` にするだけで済む（点を消してから移る仕組みは既にある） |
| メモ欄の終わりに「ここまで」の線を描く（本人の目・major の中の任意の案） | 1.1 では採らない | 月のメモ欄の絵は `Paper/MonthPaper.swift`（この契約で誰も持たない）にあり、紙の終わりは紙の色の境目で見える。トーストを 2 つのきっかけで出す方は採った（§3.4） |
| 日の一覧に 24 時の下を少し覗かせる（本人の目・minor の中の任意の案） | 既定では採らない | K-6（伸びる紙の一覧は固定部分）に反し、`extra` の高さで一覧の倍率が日ごとに変わる。CI の写真と一緒に本人に聞く（M7A-10） |
| 消しゴムのタップを「ページを移る操作として扱わない」（互換・minor の 2 案の 1 つ） | 採らない（もう 1 つの案を採った） | 消しゴムを選んだまま日付で移れなくなり、本人には「叩いても動かない」に見える。そのタップで消した分を取り消してから移る（§2.4）。ダブルタップは 1.0 のまま |
| 「読む上限を上げない場合でも、取り込みで 20,000 を超えないよう止める」（互換・major の後半） | 止めずに確かめる | 読む上限を 60,000 本に上げる方を採ったので、1.1 では取り込んだ線は全部表示され、失われない。古い版で一部が見えないことだけを伝えて、本人が選ぶ（§5.2） |
| 購入画面の文を端末を問わない文にする（本人の目・minor） | 案は本人に見せるが、既定は「変えない」 | 変えると購入画面と App Store の 05 番の写真が変わり、写真の差し替え（M7A-11）と一緒に決めるべきなので、本人の返事で決める（M7A-6） |
| 写真モードでしまうボタンを隠す（コード・major の中で指摘自身が退けた案） | 採らない | `tool-eraser` の写真に「しまう」を写して確かめる必要がある（範囲外に明記） |
| 行番号の細部（コード・minor、`update(from:)` の手順 2 が :547-550、`MonthLayoutEngineTests` が :393-395） | 実際の行に合わせた | cb2343a では手順 2 の注記が :546、`if !appliedLayout.sameGeometry` が :547-549、紙の絵の判定が :550-552（契約は :546-551 と書く）。`testInkBottomsGrowRowsAndMemo` の 950 は :396、`1187 + 950` は :397（:395 の `memo.minY` 1187 は不変） |
