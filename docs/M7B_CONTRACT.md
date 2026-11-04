# M7b 実装契約（1.2「世界対応」: 10 の表示言語・各国の祝日・週の始まり・英語の規約と App Store の文・EU での販売）

この文書は 1.2 の各担当が同時に作業するための **約束事**（公開 API・数字・文言・ファイル所有）です。[M7_PLAN.md](M7_PLAN.md) §1.3（互換の規則 K-1〜K-9・事実 F1〜F14）と、本人が 2026-10-31 に決めた「世界対応」の 6 項目（下の O-1〜O-6。O-2 と O-4 は 2026-11-04 に置き換えた）を実装の形にしたもので、M2〜M6・1.0.1（[R1_0_1.md](R1_0_1.md)）・1.1（[M7A_CONTRACT.md](M7A_CONTRACT.md) と、[M7A.md](M7A.md) の「契約の読み替え」:475-481・ずれ 45〜49 :341-345）で決めたことはそのまま生きています（ここに書いていない API は変えません）。材料は 4 本の偵察（文字列と仕組み・紙の文字の入り方・世界の祝日・ストアと規約と CI。どれも 2026-10-31）で、第 2 版（2026-10-31）で 3 本のレビュー（iOS の実装・世界の祝日のデータ・本人の目線）の指摘を入れました。**第 3 版**（2026-11-01）。土台を 1.1 の最後の main（e7b4d2f）に移し、1.1 の後半の変更の洗い出し 2 本（2026-11-01）と本人の答え（M7B の問いと、横につなげる B の問い）を入れ、さらに第 3 版の下書きへの 2 本の見直し（実装の見直しと、本人の目線と進め方の見直し。どちらも 2026-11-01）の指摘を入れました（下の「第 3 版の変更」と「見直しで直したこと」。採らなかった案・指摘とその理由は §9.1）。**第 4 版**（2026-11-04）。本人の新しい決定 2 つ（週の始まりを選べるようにする、EU でも売る）と、先に出す 1.1.1 の取り込みを入れました（下の「第 4 版の変更」）。材料は 2 本の調べ（週の始まり・EU。どちらも 2026-11-04。本文の §10・§11 に織り込んだ）と 1.1.1 の契約の下書きの申し送りです。

**土台のコード**: `main` の **e7b4d2f**（e7b4d2f9c99dcfe4f7ba27ef9f81fe0466bf093d、2026-11-01 11:19）「1.1 を main に取り込む：ツールバーをしまう・消しゴムから自動でペンへ…」（`/Users/ikedamasataka/Documents/Codex/tegaki-calendar-ios`）。1.1（M7a）＝ TestFlight 14 で、App Store の審査中。本人の了承「取り込んでよい」（docs/M7A.md:500）で `m7a` を merge した commit で、親は 6f5ac42（1.0.1）と adc1fd4（m7a の最後）、木は adc1fd4 と同じ。第 3 版を書いた時点（2026-11-01）で、作業ツリーの追跡しているファイルは e7b4d2f と同じ（`git diff --quiet e7b4d2f`）で、未追跡の複製が 6 つある（§8 の 1、M7B-22）。第 2 版の土台だった b13fa91（m7a の途中）の後に m7a に 17 の commit（a805476〜adc1fd4）が入り、そのうち Sources と Tests を変えたのは a07c525〜e156e10 の 13（M7A.md のずれ 45〜49 の直し: ツールバーの横の寸法 `ToolbarLogic.Row` と 2 行の説明、消しゴムの数え方と報告 `InkTouchObserver`（世代の予約。Pencil は離した次の turn、指は `fingerEraseReportDelay`）、Apple Pencil の投げなわ・予定の道具 `InkPencilGestureRecognizer`、PrivacyInfo の System boot time（35F9.1）、どの消しゴムも戻る（Apple Pencil のダブルタップ・スクイーズで選んだ消しゴムも）と設定の脚注、TestFlight だけの「記録」`InkTrace`・`InkTraceSheet`（設定 › 情報 の「バージョン」の長押し）、UI テスト `EraserAndBelowDayUITests`）。**TegakiKit は b13fa91 から 1 バイトも変わっていない**（`git diff --quiet b13fa91 e7b4d2f -- TegakiKit`。ソースは 21ceba5 から同じ）。b13fa91 から行がずれたのは `SettingsScreen`・`CalendarRootScreen`・`ToolbarLogic`・`ToolbarView`・`ScreenshotMode`・`Ink/*`・`build.yml`・`project.yml`。KitChecks の閾値は 24,396（1.1 の実数 24,446 − 50、`build.yml:76-89`）。`SettingsScreen.swift` の「情報」のスクロール先 `.id(Self.infoRowId)` は「バージョン」の行 `versionRow`（:550-551。本体 :562-580、`infoRowId` のコメントと宣言 :68-72）。**1.2 の実装は main e7b4d2f から切るブランチ `m7b` で行う**。行番号は特に断らない限り e7b4d2f のもの（パスの `Sources/TegakiCalendar/` は省く）。1.1 が審査で差し戻されて main に直しが入ったら 0-39 のとおり読み替え、名前が変わったら意味を変えずに 1.1 側の名前に合わせる。Web リポジトリ（`/Users/ikedamasataka/Documents/Codex/tegaki-calendar`）は `m7a-legal`（8e1dac7。1.1 の公開日に main（今は 7f31727）へ merge される予定）。単位は特に書かない限り lu（紙の単位）。em は字の大きさに対する幅の倍率（11 lu の字で 2 em = 22 lu）。字の幅はこの Mac の SF Pro と同梱の漢字・ハングルの書体での実測で、iPhone・iPad では ±3% ずれうる。

**第 4 版の時点の事実と読み方（2026-11-04）**: 1.1 は App Store で公開中（READY_FOR_SALE。main は e7b4d2f のまま。上の段落の「審査中」は第 3 版の時点の記録）。Web の main は 8e1dac7（1.1 の `m7a-legal` は merge 済み）。**1.1.1 を 1.2 より先に出す**（ブランチ `fix-1-1-1`、Web は `r111-legal`、契約は `R1_1_1_CONTRACT.md`。`fix-1-1-1` にあるのは今、写真を撮るための commit 0（d0fdbff、2026-11-04 23:14）だけで、直しの commit はまだ無い）。1.2 の実装は途中で止まっている（済んだ役は S0・K1・S1・C1・LA、H は途中、§12.1。`wt-m7b` に未 commit の変更がある）。祝日のデータの元は python-holidays 0.107 を本人の了承で取り寄せ済み（生成は Python 3.12.16 の venv。この文書の「新しい版」はこれを指す）。**読み方**: (1) この文書の「1.1 と同じ」「1.1 の道」「1.1 の文」は、§1.5 の B11 の後は **1.1.1 の同じもの** を指す（例外は §1.5）。(2) `<1.1.1>` は 1.1.1 を main に merge した commit（§1.5）。(3) `:数字` の行番号は特に断らない限り e7b4d2f のコードの行で、1.1.1 と他の役の変更で動く。行が合わなければ関数の名前で探す。**第 4 版で足した文は行番号を使わず、節の番号と関数の名前で書いた。**

**第 4 版の変更**（第 3 版から。2026-11-04）:

- **週の始まり（O-2 の置き換え）**: 月曜と日曜から選べるようにする。今お使いの方は月曜のまま、週のページの手書きは別々に保存、月のページの手書きは日付についていく。§10 を新しく足した（型・ページの id・既定・設定・文・テスト・完了の定義）。新しい互換の規則 K-11（§1.2）。J-9・J-10（§1.3）。L-13・L-14（§2.7）。§0 の接点、D6・D15〜D17、範囲外、0-41〜0-46、§3.1 の 5、§3.2、F-8、§4.3、§5.6、§5.7、§6.2、§6.3、§7、§8 の 8・9・12 を直した。`Calendar/EventStoreModel.swift` は持ち主の無いファイルから U の物にした。
- **EU（O-4 の置き換え）**: EU 27 か国でも売る。§11 を新しく足した（公開の順・ストアのロケール 15・規約とプライバシーとサポートの文・本人の届け出の手順・リードの API の作業・確かな部分と専門家に聞く部分・他の規則・出典）。D12・D19、範囲外、0-13、0-48〜0-50、§5.5・§5.10、§6.1 の 9、§6.4〜§6.8、§7.1、§7.5、§8 の 9 の E の表・§8 の 11・§8 の 13 を直した。
- **1.1.1 の取り込みと基準の移し替え**: §1.5 を新しく足した（役 B11。手順・名前の扱い・読み替えの例外）。`DATA_1_1.sha256`・`Text11`・`ja-baseline.tsv`・`ja-baseline-ref.txt` の名前は変えない。D13・D14・D18、0-32・0-39・0-40・0-47、J-1〜J-4、§7.3、§7.5、§8 の 2・3・6 を直した。ピンチの案内の文 `toast.pinchHint` を訳の対象に足した（§6.2、§6.3）。
- **役と統合の順番**: §12 を新しく足した。済んだ役（S0・K1・S1・C1・LA）は走らせ直さない。新しい役は B11 と LA2、追加の段は K1+、検証の観点は 2 つ足す。第 3 版の統合の順番は §12.3 に記録として残した。§0 のファイル所有も更新した。
- **本人の問い**: M7B-23（日本語のページに English のリンク）・M7B-24（新しく分かった EU の負担、CRA と製造物責任）。どちらの答えでも実装は無駄にならない形にした（§9、§12.2）。
- **調べから変えた所**（理由は §9.1）: `ExportBuilder` の週の始まりは U でなく S2（1 ファイル 1 人）。`store-shots` は 11 組（en-GB と es-ES を分ける。月曜の地域なので）。`l10n-shots` の地域を fr_FR・de_DE・it_IT に。新しいキーは約 18 でなく 23（見直しで 2 つ足した）。
- **本人の確かめ**: §8 の 9 に手順 2b・4b〜4e・9b（週の始まり）と、公開の後の E の表（EU）を足した。iPhone を残す版は 1.1 から 1.1.1 に。
- **見直し**（第 4 版の下書きへの 2 本。実装の目線と、本人と EU の文の目線。どちらも 2026-11-04）: blocker と major は全部入れた。いちばん大きい直しは §10.3 の 4 で、「今お使いの方」の 2 台目や入れ直しが日曜の地域で月曜の手書きを知らせなしで見失う道と、書いている最中に切り替わって線を失う道を塞いだ。ほかは、切り替えの順番を純関数にしてテストで固定（§10.5）、トーストをシートの下で失わない（§10.4）、起動で `WeekStartChoice.current` を入れる（§5.6）、取り込みの文の形（§0）、`toast.pinchHint` の文を 1.1.1 の最終に（§1.5）、Apple の規約の URL と撤回の権利の条件（§11.3）、プライバシーの文の矛盾（P-4）、届け出の時期と止まったときの分岐（§11.1）。指摘ごとの扱いは文書の末尾（§12.5）。

**第 3 版の変更**（第 2 版から。2026-11-01。理由は各節に書いた）:

- **土台**: b13fa91 → main e7b4d2f（上の段落）。行番号・CI の段・テストの数を e7b4d2f に合わせた。J-1〜J-4 と D14 の比べる相手も e7b4d2f（0-32、0-39）。
- **ツールバーの字**（§4.4 を新しく足した。担当 S。第 2 版の末尾にあった 1.1 からの申し送りの 1〜4）: 1.1 の後半で、道具と「しまう」のボタンが名前の幅で広がる作り（`ToolbarLogic.Row`）と 2 行の説明になったので、訳語が長いと iPhone 17 のペンの最初の色（黒）・11 インチの ↷・iPad mini の太・13 インチの「指でも書く」が 1.1 より見えなくなる。ja は 1.1 の道のまま、ja 以外は名前の枠を 38 pt に固定して縮める（F-12）。「指でも書く」（F-13）と説明（F-14）の上限、元のファイルの `lines`（§2.3、L-4）、S の `ToolbarFitTests`。消しゴムの説明の 1 行の形はキーにしない。
- **凍結した Ink の日本語**（§2.5、0-37）: `Ink/InkTrace.swift` の記録のシートと `Ink/InkCanvasView.swift` の「手書きの紙」の 6 件は、例外の表に入れて訳さない（D14 でファイルを変えられない）。第 2 版の末尾の「記録のシートの文は 1.2 で訳す」は取り消し。
- **UI テスト**（§7.3、§7.5）: 1.1 の後半で入った `EraserAndBelowDayUITests`（8 本。日本語の名前で部品を探す）の起動の引数にも ja を足す（足さないと、英語のシミュレータで 8 本とも落ちる）。`XCTestStandIn.swift` には `subscript` を足さない（もうある。足すと typecheck の手順 5 が落ちる）。UI テストの段の上限を 25 → 40 分にし、ジョブの上限を 90 → 110 分にした（見直しで 99 分から直した）。
- **文字列の元**（§2.3、§2.4、§2.7）: 改行の入った値の書き方と比べ方、`lines`、C 型の表の場所（ツールバーの読み上げの「太さ: %@」が漏れていた）、例の持ち主（設定の文は U）。
- **設定の画面**（§5.7）: 1.1 の後半の `versionRow`（TestFlight の長押しの「記録」）と新しい入力の脚注に合わせ、ライセンスの行の場所と脚注の確かめ方を決めた。
- **凍結したファイルが使う名前**（§0 の接点）: 凍結したファイル（D14 の 18 ファイルと `InkCanvasViewTests`）が使う S・U・P の名前（`SyncStatus` の各 case・`SyncSnapshot`・`ImportOutcome` の形、`ScreenshotMode.current`・`Config.probe`・`Config.today`・`isActive`・`SettingsScreen.versionText`・`CalendarRootScreen.newEventPlan`、`PaperView` の口・`PaperContent` の各型の memberwise の形、`SelectionMenuView.margin`・`placement`）は変えない（`Sync/SyncEngine.swift` の分などは見直しで足した）。`ScreenshotMode.Config.holidays` は `select` の後ろ。
- **本人の答え**（§9）: M7B-3・M7B-10・M7B-17・M7B-18 は「はい」、ほかは既定で確定。python-holidays の新しい版の取り寄せ（§5.1、0-14。数字とテストの期待の一部は新しい版で測り直す）、英語のページと日本語の直しの公開（§6.5）、ストアへの入力（§6.6、§8 の 11）を、答えに合わせて書き直した。
- **新しい問い**（§9）: 新しい Python の取り寄せ（M7B-20。必要になったときだけ）、作業ツリーの複製の片付け（M7B-22。既定で進める）。英語のページは本人の答えのとおり「1.2 を出す日」に公開し、審査の間はまだ無いので 1.2 は日本語のページを指す（0-38）。英語のページを審査の前に公開する案（M7B-21）は、見直しで聞かないことにした（代償と条件は §9）。
- **版の順**（§6.8、0-27、範囲外）: B の答え（P-B1 ウ・P-B2 月）で、1.2 → 1.3 横につなげる B-1（土台 ＋ 週・日）→ 1.4 Xcode 27・iPhone Duo → 1.5 指で予定 → 1.5.1 → 1.6 B 月 → 1.7 B 年 → 1.8 重点欄 → 1.9 書ける終日欄。
- **小さな直し**: PrivacyInfo は 1.2 で変えない（§2.2）・祝日の読み込みの時間は `Date` で測る（§5.3）、ツールバーの訳の見え方の写真（§7.5 の l10n-shots に消しゴムの 4 枚、§8 の 8）、J-4 はツールバーの帯も比べる、この Mac の確かめは書類フォルダの外に取り出した木で（§8 の 1）、README・DESIGN の 1.1 の後半の分（§8 の 10）、行番号。
- 第 2 版の末尾の追記（1.1 からの申し送り・本人の答え・1.1 の最終の変更・版の順）は本文に織り込み、追記の節は消した。

**見直しで直したこと**（第 3 版の下書きへの 2 本の見直し、2026-11-01。blocker 1・major 13 は全部入れた。minor 18 も全部入れ、形を変えて入れたものとその理由は §9.1）:

- **年のページの日本語**（§4.1 の F-1・F-2）: 下書きの F-2（祝日名を 0.8 倍まで縮める）は ja にも効き、1.1 で「…」で切れていた 5 字の名前（天皇誕生日など）が全部入るようになって、日本語の年の写真がほぼ全部 1.1 と違うところだった。ja は曜日の記号と祝日名を 1.1 の道で描く。日付の数字の枠は、右端を 1.1 のままにして左へ広げる（右寄せなので、右へ広げると全部の日の数字が動く）。ja の道を F-3・F-10 にも広げ、`testJapaneseTakesTheOneOnePath` で確かめる。
- **月のページの色**（§5.4）: 月のエンジンは tone を `LayoutMath.tone` を通さずにその場で決めている（`MonthLayoutEngine.swift:97-105`）。表に 12 として足し、`workday:` の既定値をなくし（呼ぶ 5 か所が渡さないと組み立たない）、`testWorkdayToneIsNormal` の中身と G-4 の作り物の暦「W」を決めた。
- **訳の長さで切れる部品**（§4.5 を足した）: 投げなわのメニュー（F-15、S。`.fixedSize()` で右が画面の外に出る）と、見出しの切り替え・「今日」（F-16、P）の上限、それを測るテストと写真。
- **凍結したファイルが使う名前**（§0）: 凍結したファイルを「D14 の 18 ファイルと `InkCanvasViewTests`」と決め直し、`Sync/SyncEngine.swift` が使う `SyncStatus` などの名前、`Ink/InkCanvasView.swift` が使う `PaperView` の口、`InkCanvasViewTests` が使う名前を足した。§0 の表に持ち主の無いファイルは変えない。
- **紙の祝日の出どころ**（§5.6・§2.5）: `makePaper`（static）に暦を 1 つ渡し、`*LayoutInput` と月の `holidayNames` の両方に同じ値を使う。
- **進め方**（統合の順番・0-40・§8 の 6）: S の `build.py` の Kit 用の出力を最初に作り、K と H は前半で元のファイルを書いて生成してから使う。TestFlight は 1.1 と同じく `m7b` から出し、main への merge は本人の実機の確かめの後、1.1 が審査を通ってから。`store-shots.yml` は push のブランチでも走る。
- **公開物**（§6.5・0-35・0-38・§9）: Web の公開は、公開の直前に全文と URL を見せて「はい」をもらってから。日本語のページに足すのは §6.4 の 4 つだけ（英語版へのリンクは足さない）、英語は 3 ページ（`app/en/index.html` は作らない）。M7B-21 は聞かない。説明の利用規約の URL も 0-38 の規則（1.2 は日本語のページ）。
- **ストアの確認表**（§8 の 11）: 入力する物を全部（promo・サブスクリプションの表示名と説明・名前の退き先・URL・ja の新機能の文・審査メモ）載せ、説明は逆翻訳の全文に。公開の日の URL の差し替えも、そのとき聞く。
- **本人の TestFlight の確かめ**（§8 の 9）: 表の頭に版と確かめ方、渡すのは build が届いてから。iPhone を 1.1 のまま同期を確かめてから 1.2 にする順、言語を足すときに出る問いでは日本語のままを押す、線の本数（B の P-B9）、自動アップデートを戻す。期待の祝日の名前は新しい版で H が確かめ直す（0-14）。
- **版の順**（§6.8・0-27）: 2/15 の決まりを中身の名前で（番号は出す順に付くので、Duo と B-1 が入れ替わる）。M7_PLAN の「順」の文・P-12・計画の紙の節、1.4 の確かめ直しの分、B_DESIGN を写すときの読み替え、次の版の訳とストアの分、0-37 の例外の期限。
- **小さな直し**: ジョブの上限 110 分（§7.5）、J-4 の比べる相手は比べる直前にもう一度撮る（§1.3、§7.5）、設定の写真の期待（§8 の 8）、`git archive` の手順（§8 の 1）、`Package.swift` の注記とテストの依存（§2.6）、M7B-20 の聞き方と取り寄せの報告（§9、§5.1）、§8 の 8 の頭の書き方、本人の端末の OS の版（§2.1）、数と commit と行番号。

**第 2 版の変更**（第 1 版から。理由は各節に書いた）:

- **祝日の移行**（§1.4）: 初めての起動で記録が無ければ、これまでの利用者の印があれば "JP"、無ければ **"auto" を書く**。第 1 版は新しい利用者に何も書かなかったので、初回案内で `onboardingDone` が書かれた後の 2 回目の起動で、世界中の新しい利用者が日本の祝日に固定される誤りがあった。
- **祝日の渡し漏れ**（§5.4、§7.1 の G-4、L-7）: 終日帯の列の色（`AllDayBandEngine.week/day` が中で `empty(kind:days:)` を引数なしで呼んでいた）・題名・PDF のファイル名まで、祝日の暦を渡す 11 か所を表にし、渡し漏れを見つける G-4 と L-7 の Kit 側を足した。
- **祝日データ**（§5.1〜§5.3、§5.10）: 国ごとの「公式の表の最後の年」「政府の毎年の発表で決まる国か」「データの揃っている年の範囲」を index に書き、中国などの発表前の年とデータの薄い年を設定の画面で知らせる。推定の祝日は日・週・月の名前に「（推定）」の印。州・地域のコードの形（"NZ-South Canterbury" など）、UK の重複（249 ファイルに）、差の無い州、表示名、振替休日の型、読み込みの検査、並び、日本の名前の出どころを直した。州・地域のある国の「自動」は「全国共通の祝日のみ」と出す。
- **日本語の写真の比べ方**（J-4）: 1.1 の CI の写真は英語のシミュレータで撮っていて漢字が中国語の書体だったので、**1.1 の merge の commit を 1.2 と同じ日本語の引数で撮り直した写真**と比べる（`ja-baseline.yml`）。
- **設定の日時**（§3）: 日付と時刻の `DateText.numericDateTime` を足し、`numericDate` と合わせて ja は 1.1 と同じ ICU の道にした。`SettingsScreen.dateText(_:locale:)` は形を残す。
- **lint**（§2.7）: Kit に残す日本語（生成物・1.1 の公開 API の 7 つ）を列挙し、L-1 が契約どおりの実装で落ちないようにした。L-2 の例外、L-7 の照合の正規表現、L-9 の各言語の禁止語。
- **本人の了承**（§9）: 日本語の規約類の直しの公開（M7B-17）とストアへの入力（M7B-18）を「はっきり『はい』が無ければしない」に。1.1 と 1.2 の main への merge の前に本人の「はい」。1.1 から英語などの端末で使っている人の表示（M7B-19）を聞く。問いを「返事が必要」と「既定で進める」に分けた。
- **本人の確かめ**（§8）: 写真は 1 枚の確認ページにまとめて渡す、英語の画面の道に英語の名前を添える、カリフォルニア州と英語の日の写真の期待を実際のデータに合わせる、「言語」の項目が無いときの手順、TestFlight の自動アップデートを止める手順、ストアに入れる前の言語ごとの確認表。
- **小さな直し**: テストのターゲットの依存（Holidays）、`XCTestStandIn.swift` の持ち主、`Products.storekit` の場所、行番号、`l10n.state` の部品の作り方、テストで言語を渡す関数の形、`HolidayChoice.current` を画面の body で読まない、言語の選ばれ方の UI テスト 9 回、写真の二倍長の範囲、購読カレンダーの語の照らし方、ライセンスの表示の退き先。

**本人の決定（確定。再検討しない。2026-10-31。O-2 と O-4 は 2026-11-04 に本人が置き換えた）**:

- **O-1 表示の言語**: 日本語のまま、英語・簡体字中国語・繁体字中国語・韓国語・フランス語・ドイツ語・スペイン語・イタリア語・ポルトガル語を足す（合わせて 10）。**それ以外の言語の端末は英語**（日本語ではない）。右から左へ書く言語（アラビア語・ヘブライ語など）は今回は対象外。日付・月・曜日の名前は言語に従う（「10月」→「October」）。
- **O-2 週の始まりは月曜と日曜から選べる**（2026-11-04 の本人の決定。原文「世界展開時には、日曜始まりも選択出来るようにする。アメリカは日曜始まりのため」。第 3 版の「週は全言語で月曜始まりのまま」を置き換える）。**今お使いの方は月曜始まりのまま**。週のページの手書きは月曜始まりと日曜始まりで別々に保存する（切り替えると、もう一方の手書きは元に戻すまで見えないが消えない）。月のページの手書きは日付についていく。新しく使い始める方は端末の地域に合わせる（日本は月曜）。§10、K-11（§1.2）。
- **O-3 祝日は国ごと**: 既定は端末の地域。設定で別の国や「なし」に変えられる。州・地域で祝日が違う国（米・独・英・スイス・カナダ・豪・スペイン・ブラジル・インド…）は州・地域も選べる。**日本は今の確かめ済みの計算（JapaneseHolidays）のまま**。
- **O-4 EU（27 か国）でも 1.2 から売る**（2026-11-04 の本人の決定。原文「EUで販売出来るようにしたい」。第 3 版の「今は売らない」を置き換える）。EU の App Store に住所・電話番号・メールアドレスが公開されることは本人に説明して了承済み。DSA の trader の届け出の入力は本人がする。EU の配信を入れるのは、届け出が通り、1.2 が公開された後（§11.1）。届け出が間に合わなければ 1.2 を 148 か国で先に出す。App Store の文は実際の店頭に向けて書く（§6.6、§11.2）。
- **O-5 1.2 は 1.1 のすぐ後**。前の計画の 1.2（指で予定を動かす）とその後の版は 1 つずつ後ろへずらす（§6.8）。（その後の版の順は、2026-11-01 の B の答えで決め直した。§6.8、0-27）
- **O-6 訳は Claude が書き、別の Claude が日本語へ逆に訳して確かめる**。本人は他の言語を読めないので、**ネイティブの確認は無い**ことを契約・新機能の文・サポートに正直に書き、危険の減らし方を決める（§6.1）。

**本人の答え（2026-11-01。確定）**: M7B-3（英語の規約類を Pages サイトの `app/en/` に公開。公開は 1.2 を出す日）・M7B-10（python-holidays の新しい版を PyPI から取り寄せる）・M7B-17（日本語の規約類に 4 つの文を足して公開。公開は 1.2 を出す日）・M7B-18（ストアの 13 ロケールの文と写真を入れる。入れる前に訳し戻しの確認表を見せる。第 4 版で 15 ロケールになった、§9）は「はい」。ほかの M7B の問いは既定のとおり（§9）。横につなげる（B）の問いは P-B1 ウ（週・日を一番先に）・P-B2 月（iPad でいちばん使う）・P-B11 この形（B_DESIGN.md の末尾。控えは `/Users/ikedamasataka/.claude/projects/-Users-ikedamasataka-Documents-Codex/b10c2ae9-5535-4dd5-97f2-2e5ca034309a/span-backup/B_DESIGN.md`）で、1.2 の後の版の順が決まった（§6.8）。

**リードの決定（この契約の既定。根拠があれば直し、理由を書く）**:

- **D1 開発言語を英語にし、日本語の表も必ず入れる**（§2.1）。`CFBundleDevelopmentRegion` を `ja` → `en`、`options.developmentLanguage: en`、`CFBundleLocalizations` に 10 言語。偵察の実測（macOS の CFBundle、同じ部品）で、受け皿が `ja` のままだとタイ語の端末に日本語が出る。`en` にして `ja.lproj` が無いと日本の利用者に英語が出る。**両方そろって初めて O-1 を守れる**。
- **D2 キーは意味で名付ける**（`settings.input.eraserAutoReturn.title` など）。日本語の文はキーにしない。**日本語の訳文は 1.1 の文と 1 文字も変えない**（§1.3 の J-1）。
- **D3 文字列の元はファイル 1 つではなく「持ち主ごとの元のファイル」＋「言語ごとの訳のファイル」**（§2.3）。生成器 `tools/l10n/build.py` が、アプリの `Localizable.xcstrings`・`InfoPlist.xcstrings` と、TegakiKit の Swift の表 `KitStrings.generated.swift` を作る。生成物は commit し、手では直さない。
- **D4 TegakiKit は `.strings` も `.xcstrings` も `Bundle.module` も使わない**。文字は生成した Swift の表から引き、関数は `language: UILanguage` を引数で受ける（既定は `.ja` = 1.1 と同じ結果）。偵察の実測: この Mac の Command Line Tools には `xcstringstool` が無く `.xcstrings` の Kit は `swift build` が止まる。`.strings` は動くが `String(localized:bundle:locale:)` の `locale` では言語が選ばれず、選べる書き方（`LocalizedStringResource` ＋ `.atURL`）は iOS で未確認。`typecheck.sh` は `swiftc` で直接組むので `Bundle.module` が無い。Swift の表ならこの 3 つが全部起きない（§9.1）。
- **D5 埋め込みは文字列だけ**（`%@`・`%1$@`）。数は先にこちらで書式してから渡す（`%d`・`%lld` を使わない）。年が「2,026年」になる罠（偵察の実測）と、複数形の取り違えを両方なくすため。**複数形は `.one` / `.other` の 2 つのキーを自分で選ぶ**（`UILanguage.pluralCategory`）。String Catalog の複数形の仕組みは使わない。
- **D6 日本語の日付・時刻・数は 1.1 の手作りの書式をそのまま使う**（ICU の雛形に任せない。iOS と macOS で ICU の版が違いうるため）。日本語以外は DateFormatter の雛形（グレゴリオ暦に固定・言語 ＋ 端末の地域）。曜日の並びは `WeekStart.order` で作り（§10.1）、`Calendar.firstWeekday` は読まない。地域の週の始まりを読むのは `WeekStartChoice` だけ（L-14）。
- **D7 紙と予定の時刻は 1.2 では全言語で 24 時間「H:mm」**（§3.1、§4.1 の F-4）。「10 AM」（2.941 em）は時刻欄の上限 2.9 em（`PaperText.swift:35`）に入らず、上限を広げると iPhone の週の時刻の字が 9 pt を割る。12 時間表示は本人の返事しだいで後の版（M7B-9）。iOS の時刻の選び方（DatePicker）は端末の設定のまま。
- **D8 祝日は TegakiKit の `Holidays` モジュールに `HolidayCalendar` を足し、Layout の入力で渡す**（§5）。日本は `JapaneseHolidays` をそのまま使う橋（`JapanHolidayBridge`）。他の国は python-holidays から作った JSON（`TegakiKit/HolidayData/`、0.83 で **249** の国・地域（新しい版で H が数え直す、0-14）、2000〜2099 年）。データはアプリの bundle に入れ、読み込む場所は引数で渡す（`Bundle.module` を使わない。KitChecks と各テストのターゲットは、自分のファイルの `#filePath` から場所を作る。配信するモジュールには場所の関数を置かない。組み立て機のパスがアプリに入らないように）。
- **D9 祝日と言語は紙の形に一切効かない**（K-4・K-6 の延長。§1.2）。変わるのは描く字と休日の色だけ。KitChecks で、祝日の暦 4 通り・言葉 2 通り・暦の locale 3 通りで、全ページの枠がビット単位で同じことを確かめる（§7.1 の G-1〜G-3）。逆に、祝日の色と名前は渡した暦から必ず来ることを G-4 で確かめる（既定値の `.japan` が渡し忘れた所で黙って効かないように）。
- **D10 1.1 から使っている人の祝日は「日本」に固定する**（§1.4）。初めての起動で記録が無ければ、これまでの利用者には「日本」（"JP"）、新しく入れた人には「自動（端末の地域）」（"auto"）を **どちらも書く**。判定は 1 回だけで、以後は記録を読むだけ。米国に住む日本人の利用者の祝日が、更新しただけで米国の祝日に変わらないようにするため（M7B-7）。
- **D11 規約類は日本語（正本）と英語（参考訳）だけ**（§6.4）。英語版は同じ Pages サイトの `app/en/` に置く（M7B-3 は「はい」、2026-11-01。公開は 1.2 を出す日）。**英語のページが公開されて `curl -sI` で 200 を返すまでは、アプリ（`LegalLinks.englishPagesPublished`）も Connect の英語などのサポート・プライバシーポリシーの URL も説明の利用規約の URL も、英語のページを指さない**（0-38。指したまま審査に出すと、審査の間リンクが開かない）。英語のページは 1.2 を出す日に公開するので、1.2 はどの言語の画面からも日本語のページを開く（`englishPagesPublished = false`）。審査の前に公開する案（M7B-21）は聞かない（§9）。true にするのは 1.3。英語のページは `app/en/` の `terms.html`・`privacy.html`・`support.html` の 3 つ。**公開中の日本語の 3 ページの直し（§6.4 の 4 つの文）は M7B-17 の「はい」で、1.2 を出す日に公開する**（Web はそれまで 1.1 のまま。アプリの動きには響かない）。どちらも、公開の直前に公開する文と URL を本人に見せて「はい」をもらってから（§6.5）。EU の文（§11.3）は M7B-17 の「はい」の外なので、この確認で全文を見せる。
- **D12 App Store の文は 15 ロケールを足す**（§6.6、§11.2）: en-US・en-GB・en-AU・en-CA（英文は 1 つ）、zh-Hans、zh-Hant、ko、fr-FR・fr-CA（仏文は 1 つ）、de-DE、it、pt-BR、es-MX、**es-ES、pt-PT（第 4 版で足した。O-4）**。nl-NL・sv は入れない（§11.2）。主言語（日本語）は変えない（1.2 では変えられない。次の版の候補、§11.2）。
- **D13 版と文書**: `MARKETING_VERSION` **1.2**（`project.yml:20`）。ブランチ `m7b`（main e7b4d2f から。1.1.1 を §1.5 で取り込む）、Web は `m7b-legal`（1.1.1 の `r111-legal` を含む所から、§6.5）。この契約は `docs/M7B_CONTRACT.md`、実装の結果は `docs/M7B.md`。
- **D14 手書きのデータの部分は 1.1.1 から 1 行も変えない**（§1.1、§1.5。1.1.1 が `Ink/InkCanvasView.swift` を変えるので、基準は e7b4d2f から 1.1.1 へ移す）。CI の手順「Data code frozen since 1.1.1」で、データの部分のファイルの sha256 を 1.1.1 のものと照らす。対象は 18 ファイル（§1.1）。ファイル `tools/compat10/DATA_1_1.sha256` の名前は変えない（§1.5）。
- **D15 週の始まりは、Kit では入力の引数（既定 `.monday`）、アプリでは必ず渡す**（§10.1）。既定の引数で月曜の道を 1.1 のままにし、凍結したファイルと既存のテストを 1 行も変えない。アプリの渡し忘れは L-13 で、Kit の中の渡し漏れは G-5 で止める。
- **D16 週の始まりの設定は端末ごと**（iCloud に送らない。§10.4）。同期にすると、書いている最中に別の端末の操作でページが変わる。祝日・言語とそろう。
- **D17 月のページの隠れる線は、動かさない・描かない・消さない。開いたときに 1 回だけ本数を知らせる**（§10.2。シートが閉じて実際に出せたときに「案内済み」と記録する、§10.4）。写すと、切り替えただけでデータが書き換わり、戻しても元の位置に戻らない。
- **D18 1.1.1 を main から取り込んでから、1.2 の CI の最後と写真の比較をする**（§1.5）。「日本語は 1.1 と同じ」の基準は 1.1.1 に移す。
- **D19 EU の配信は 1.2 を公開した後に入れる**（§11.1）。配信の国は版と別の設定で即時に効くので、先に入れると日本語だけの版が EU に出る。

**範囲外**（触らない）: 右から左へ書く言語（アラビア語・ヘブライ語・ペルシア語・ウルドゥー語。端末がその言語なら英語で、左から右のまま出す）、10 以外の言語（タイ語・ベトナム語・ロシア語・インドネシア語など。英語で出す）、月曜と日曜のほかの週の始まり（土曜始まりなどの地域は月曜に読む、§10.3）、週の始まりの設定の同期（D16）、画面の pt-PT・es-ES の `.lproj`（0-2）、ストアの nl-NL・sv のロケール（§11.2。次の版の候補）、Web 版（日本だけ・日本語だけのまま）、和暦・仏暦など他の暦の表示（グレゴリオ暦に固定）、12 時間表示の紙（D7）、2 か国の祝日を同時に出すこと（M7B-6）、振替出勤日の字（「出勤日」の札。§5.4 では色だけ変える）、祝日データの通信での更新（アプリの更新で入れる）、手書きのデータの形式・`v`・書き出し `tegaki-app-export` v1（K-5）、`Sync/*` と `Ink/*` の処理（1.1 の後半で入った記録のシートと探りの読み上げの名前の訳を含む。§2.5 の例外）、横につなげる（1.3・1.6・1.7 へ）、iPhone Duo と Xcode 27（1.4 へ）、指で予定を動かす（1.5・1.5.1 へ）、App Store の主言語の変更、中国本土の配信をやめるかどうか（M7B-12 は既定の「今のまま」で確定）。

### 0.1 決めどころの決着

| # | 決めどころ | 決着 |
| --- | --- | --- |
| 0-1 | 受け皿の言語 | **en**（D1）。th・vi・ru・ar・he・nl・ca・gsw の端末は英語。端末の言語一覧の 2 番目以降に 10 言語のどれかがあれば、それが先に当たる（[th, en] → en、[ru, ja] → ja。実測） |
| 0-2 | 地域の違う言語 | 1 言語 1 つの `.lproj`（`ja` `en` `zh-Hans` `zh-Hant` `ko` `fr` `de` `es` `it` `pt-BR`）。実測で zh-HK・yue-Hant-HK → zh-Hant、pt-PT・pt → pt-BR、es-MX・es-419・es-ES → es、fr-CA・fr-CH → fr、de-CH → de、it-CH → it。`es-419` と `pt-PT` は置かない（置くと es-MX が es-419 に当たるなど、文が分かれる）。iOS で同じになるかは UI テストで確かめる（§7.3）。違ったら pt-PT に pt-BR の写しを足す（リードが決めて M7B.md に書く）。EU で売るようになっても（O-4）この形のまま（§11.2） |
| 0-3 | `CFBundleAllowMixedLocalizations` | **付けない**。TegakiKit は表を自分で引くので関係しない（D4） |
| 0-4 | アプリの文字の仕組み | `Localizable.xcstrings`・`InfoPlist.xcstrings`（生成物）。XcodeGen がこれを正しく組み込むか（10 の `.lproj` ができるか）は CI の「Localized bundle check」で確かめ、できなければ同じ生成器の `--format strings` で `.lproj/*.strings` に切り替える（元のファイルは同じなので文は変わらない、§2.3） |
| 0-5 | `SWIFT_EMIT_LOC_STRINGS` | **NO** にする（`project.yml:26`）。カタログの各キーは `"extractionState": "manual"`。Xcode がカタログに勝手にキーを足さないようにし、CI のビルドの後に `git diff --exit-code -- Sources/TegakiCalendar/Resources` で確かめる |
| 0-6 | Kit の関数の既定の言語 | **`.ja`**（1.1 と同じ結果）。アプリの呼び出しは必ず `language: L.language` を渡す。渡し忘れは lint L-7 が見つける（§2.7）。KitChecks と Kit のテストは今のまま日本語で通る |
| 0-7 | 数の埋め込み | **文字列だけ**（D5）。年は `String(year)`、他の数は `DateText.number(_:_:)` で書式してから。lint L-5 が `%d`・`%lld`・`%ld`・`%f` を拒む |
| 0-8 | 複数形 | `.one` / `.other` の 2 キー（D5）。ja・ko・zh は常に other（one も同じ文）、en・de・es・it は 1 だけ one、fr・pt-BR は 0 と 1 が one |
| 0-9 | 日本語の日付 | 1.1 の手作りのまま（D6）。KitChecks で 2000〜2099 年の全日付について、1.1 の写し（`Text11`）と 1 文字も違わないことを確かめる（§1.3 J-3） |
| 0-10 | 紙の時刻 | 全言語で 24 時間「H:mm」（D7）。範囲の区切りだけ言語で変える（ja「〜」、ko「~」、他「–」） |
| 0-11 | 暦 | 表示は全部グレゴリオ暦に固定（`DateText.calendar`）。`SettingsScreen.dateText` の端末の暦のまま書式する不具合（和暦の端末で「R8/10/10」、タイの仏暦で「2569」。実測。1.0 から）も直す |
| 0-12 | `DayKey.deviceCalendar` | **変えない**（ja_JP・グレゴリオ暦。日付の計算専用。変えるとページの id に響きうる）。表示用は `DateText.calendar(_:)` を別に作る |
| 0-13 | 祝日のデータ | python-holidays（Vacanza、MIT）で 2000〜2099 年、**249**（0.83 の数。新しい版で H が数え直す、0-14）の国・地域の全部を同梱（`list_supported_countries()` の 2 字の名前のうち、Foundation の `Locale.Region.isoRegions` にあるもの。別名の "UK" は GB.json と同じ中身で、選ぶ画面に「イギリス」が 2 つ並ぶので出さない。約 4.0 MB、配信時は圧縮で約 1.6 MB）。旅行中・海外に住む人のため、販売中の地域に絞らない（販売中の地域は第 3 版で 148、うち 147 にデータ。EU を入れると 175、うち 174。無いのはコソボ XKS だけ。EU の 27 か国のデータはある） |
| 0-14 | python-holidays の版 | **M7B-10 は「はい」**（2026-11-01）: H の最初の手順で、リードが PyPI から、取り寄せる日の最新の安定版のうちこの Mac の Python 3.9.6 で入るもの（pip が `Requires-Python` で選ぶ）を、依存と一緒に wheel で取り寄せ、版と hash を `requirements.txt` に固定する（§5.1）。それより新しい版でないと中国などの 2026 年の発表が入らないときだけ、M7B-20 で本人に聞く。取り寄せは 1.2 の生成のための 1 回で、毎年の更新（§5.11）はその都度聞く。0.83（この Mac に今ある版）の中国・台湾・ロシア・ベラルーシ・カザフスタン・ウズベキスタン・韓国の特別の表は 2025 年まで、ベトナムは 2024 年まで（実測）。**この契約の数字（249、件数、`lastOfficialYear`、`coverage` の見込み、例の日）は 0.83 の実測**で、H が新しい版で測り直し、M7B.md に「0.83 → 新しい版」の表で書く。テストの期待のうち版で動くもの（§7.1・§7.2 で「版で動く」と書いた所）は新しい版の値にする。**本人に見せる期待**（§8 の 8 の写真の表と §8 の 9 の手順にある祝日の名前と日: Columbus Day・Thanksgiving Day・カリフォルニア州の 10/12 が祝日なしと 11/27 の Day After Thanksgiving・ドイツの州の表示名「Bayern」・カナダの「全国共通のみ」・台湾の 10/9「國慶日（補假）」と 10/10「國慶日」・日本の英語名 Sports Day）も 0.83 の値なので、H が新しい版の HolidayData（index の `display` と各日の名前）で確かめ直し、違えば直してから本人に渡す。取り寄せた後、リードは取り寄せた物（holidays と依存の版・出どころの PyPI・ファイルの名前と大きさ・置いた場所）を本人に平易に報告する（§5.1） |
| 0-15 | 祝日の名前の言語 | 画面の言語の名前 → その国の言語（画面と同じ系統の文字のときだけ）→ 英語 → その国の言語（§5.5）。指示の「画面 → 国 → 英語」から変えた（日本語の画面でサウジアラビアにアラビア文字が出ないように）。M7B-8 は既定（この決め方）で確定（2026-11-01） |
| 0-16 | 同じ日に祝日が 2 つ | 「 · 」でつなぐ（国の祝日が先、次に州・地域の祝日。データの順） |
| 0-17 | 振替・推定の後ろ書き | データに `full`（後ろ書き付き）と `short`（後ろ書きなし）を持つ。年のマスは `short`、他（日・週・月の見出し・題名・読み上げ・PDF）は `full`。ライブラリの推定の後ろ書き「(estimated)」は名前から外し、代わりに **アプリの言語の短い印**（キー `kit.holiday.estimatedSuffix`、ja「（推定）」、en「 (est.)」、他は X が訳す）を `full` の後ろに付ける。`short` には付けない（第 2 版。アラブ首長国連邦・エジプト・パキスタン・インドネシア・マレーシア・インドのイードなどは 2026 年でも推定で、月の見え方で ±1 日ずれうるため。flags の estimated は `HolidayEntry` に残す） |
| 0-18 | 振替出勤の週末（中国の调休など） | 色だけ通常（黒）にする。字は足さない（範囲外） |
| 0-19 | 1.1 からの利用者 | 祝日を「日本」に固定（D10）。見分け方は `onboardingDone`・`lastPageKind`・`allowFingerDrawingChosen` のどれかが記録にあること。**判定は記録が無いときの 1 回だけ**: 新しい利用者にも "auto" を書くので、2 回目の起動で初回案内の `onboardingDone` があっても "JP" にならない（§1.4） |
| 0-20 | 端末の地域にデータが無い（コソボ XK など） | 「自動」は「なし」として扱い、設定の行に「（祝日のデータがありません）」。データはあるが今年が範囲の外の国（スリランカ・ウクライナなど）は 0-30。明示して選んだ国のファイルが読めないときも「なし」にし、行に同じ注記を付ける |
| 0-21 | 祝日の設定の記録 | 端末ごとの UserDefaults（iCloud に送らない。他の設定と同じ） |
| 0-22 | 購読している祝日カレンダーを最初から隠す判定（`Calendar/EventKitService.swift:75`） | 言葉の表を 10 言語に広げる（§5.8）。挙動（最初から隠すだけ。本人が出せる）は変えない |
| 0-23 | 規約類の言語 | ja（正本）と en（参考訳）だけ（D11）。en の公開は M7B-3（「はい」。1.2 を出す日。0-38） |
| 0-24 | 読み上げ（VoiceOver）の文 | 日本語の文は 1.1 のまま（YearTapUITests と、1.1 の後半で入った EraserAndBelowDayUITests が日本語の読み上げの名前で部品を探している）。他の言語は「日付 ＋ 動作」を 1 つの文として訳す（単語をつながない） |
| 0-25 | テストの言語 | アプリの単体テストは `-testLanguage ja -testRegion JP` で日本語に固定。UI テスト（YearTapUITests・EraserAndBelowDayUITests、1.1.1 の HeaderAndPaperUITests・BlankPaperShotsUITests と、LanguageUITests の日本語の起動）は起動の引数に `-AppleLanguages (ja) -AppleLocale ja_JP`。写真はすべての `simctl launch` に同じ引数（CI のシミュレータは英語なので、付けないと英語に化ける） |
| 0-26 | 写真モードの祝日 | 引数が無ければ **日本**（シミュレータの地域に左右されない）。`--screenshot-holidays auto\|none\|<国>[-<州>]` で変える |
| 0-27 | 版の順番 | **B の答え（2026-11-01）で決まった順**（その前に 1.1.1。2026-11-04 の本人の決定）: 1.2 世界対応 → **1.3 横につなげる B-1（土台 ＋ 週・日。段 0 を含む）** → 1.4 新しい開発環境と iPhone Duo（**遅くとも 2027-03-15 に提出**）→ 1.5 指で予定（週・日）→ 1.5.1 月で予定・手書きも一緒に → **1.6 横につなげる B-3（月）** → **1.7 横につなげる B-2（年）** → 1.8 重点欄（年・月）→ 1.9 書ける終日欄・今週の重点。**B-1（1.3）を 2027-02-15 までに提出できなければ、Xcode 27・iPhone Duo の版を先に出す**。そのときは Duo の版が 1.3、B-1 が 1.4 になる（App Store は前に出した版より小さい番号を受け付けないので、番号は出す順に付ける。入れ替わるのはこの 2 つだけで、1.5 指で予定 から後は変わらない。§6.8） |
| 0-28 | 州・地域のコードの形 | 国は英字 2 字（小文字も受けて大文字に）。州・地域は "-" の後ろの **1〜40 字の `[A-Za-z0-9 ]`**（"CA"・"SCT"・"C"・"9"・"02"・"971"・"6AE"・"South Canterbury"・"Augsburg"・"Forli"。0.83 の最長は 16 字、全部この形。実測）。大文字にせず、index のコードと大文字小文字を区別せずに照らしてデータの表記を返す（0.83 の 69 か国で大文字小文字だけ違うコードの衝突は無い。実測）。第 1 版の「大文字」のままだと "NZ-South Canterbury" が "SOUTH CANTERBURY" になって一致せず、何の表示もなく国全体に戻っていた |
| 0-29 | 政府の発表の前の年 | 政府が毎年の通知で休みと振替出勤日を決める国（**`notice` の国: CN・TW・VN・RU・BY・KZ・UZ**。販売中）は、ライブラリの公式の表の最後の年（`lastOfficialYear`）より後の年を「発表前の推定」として設定の行と選ぶ画面に出す。さらに **CN と VN** はその年の祝日の flags に estimated を付け（`full` に「（推定）」）、**CN** の規則で作った「（观察日）」の日（0.83 の 2026 年なら 4/6・5/4・10/5。中国の法に振替の規則は無い）は出さない。0.83 の CN の 2026 年は春節 2/16〜2/19・国慶節 10/1〜10/3 で振替出勤日 0 件、公表済みの调休とは合わない見込み（0.83 の実測。M7B-10 の「はい」で入れる新しい版に 2026 年の発表が入れば、その国の `lastOfficialYear` が上がって 2026 年は発表前でなくなる。仕組みはそのまま翌年以降に効く。入ったかを H が M7B.md に） |
| 0-30 | データの揃っている年の範囲 | gen.py が国ごとに `coverage` を index に書く: 全国の祝日の件数が「2015〜2024 年の件数の中央値の 80%」以上の年が続く範囲のうち、2020 年を含むもの（無ければ最も長いもの）。**基準を下回る年が 1 年だけで、0 件でなく、次の年が基準に戻るときは範囲を切らない**（第 4 版の見直し。スロバキアのため、§5.10）。0.83 での見込みはスリランカ until 2025、ウクライナ until 2021、ネパール・インド until 2035、サウジアラビア until 2076（H が実数を M7B.md に）。今年がその外なら設定の行と選ぶ画面に「（<年> 年以降のデータがありません）」。紙には何も出さない（D9。字を足すと枠を取り合う） |
| 0-31 | 州・地域のある国の「自動」と国全体 | 全国と差のある州・地域を 1 つ以上持つ国では、行の値に「全国共通の祝日のみ」を添える（「自動（カナダ・全国共通の祝日のみ）」「カナダ（全国共通のみ）」）。選ぶ画面の国の行の下と州の画面の先頭に「州・地域を選ぶと、その地域の祝日が加わります」。0.83 のカナダの国全体は 2026 年で New Year・Good Friday・Canada Day・Labour Day・Christmas の 5 つだけ（Thanksgiving も Victoria Day も州の分）、英国の国全体には Easter Monday と 8 月の Bank Holiday が無い（実測） |
| 0-32 | 日本語の写真の比べる相手（J-4） | 1.1.1 を main に merge した commit **`<1.1.1>`**（§1.5。第 3 版は e7b4d2f）を、1.2 と同じ `JA_ARGS` で撮り直した写真（`ja-baseline.yml`、§7.5）。1.1 と 1.1.1 の CI の写真（英語のシミュレータ。漢字が PingFang SC、日時が英語の書式）とは比べない。e7b4d2f の写真とも比べない（紙の上寄せと見出しの「今日」で全部違う） |
| 0-33 | 設定の日付と時刻 | `DateText.numericDate`（日付だけ）と `numericDateTime`（日付と時刻）。**ja は 1.1 と同じ ICU の道**（`Date.FormatStyle(date: .numeric, …)`。暦だけグレゴリオ暦に固定）。1.1 の `SettingsScreen.timeText`・`dateText` が ICU だったので、手作りにすると 0 で埋めるかどうかを決め打ちすることになり 1.1 と同じを証明できない（§3.1） |
| 0-34 | 1.1 から英語などの端末で使っている人 | 1.2 にすると表示がその言語（未対応の言語なら英語）に変わり、ホーム画面の名前も「Tegaki」になる。**既定はそのまま**（O-1 のとおり。en-US などの新機能の文の最後に日本語で戻し方を書く）。1.0 の公開は 2026-10-30 で、まだ利用者は少ない。M7B-19 は既定（そのまま）で確定（2026-11-01） |
| 0-35 | 公開物とストアへの入力 | Web の日本語の直しの公開（M7B-17）・英語のページの公開（M7B-3）・ストアのロケールの文と写真の入力（M7B-18。聞いたときは 13。es-ES・pt-PT を足して 15 になったので、この 2 つは確認表で一緒に聞く）は、**本人の「はい」をもらった**（2026-11-01）。条件: 日本語の直しと英語のページの公開は 1.2 を出す日で、**公開の直前に、公開する物の一覧（日本語の 3 ページの差分の全文（EU の文 §11.3 を含む）・英語の 3 ページの R の逆翻訳の要点・公開する URL）を本人に見せて「はい」をもらってから**（M7B-3・M7B-17 の「はい」は文がまだ無いときの了承なので。§6.5）。ストアへの入力は §8 の 11 の確認表（入力する物を全部載せる）を見せて本人が「この内容で入れてよい」と言った後。**1.2 の main への merge は、本人の実機の確かめ（§8 の 9）の後、1.1.1 が審査を通って main に入ってから、リードが本人に平易に報告して「はい」を得てから**（0-40。1.1 は 2026-11-01 の「取り込んでよい」で e7b4d2f に merge 済み）。EU の配信を入れるのも本人の「はい」の後（0-49） |
| 0-36 | ツールバーの訳語の幅 | ja は 1.1 のコードの道のまま（ボタンは名前の幅で広がる作りで、ja の名前は全部 38 pt 以内なので広がらない）。**ja 以外は名前の枠を 38 pt に固定して 0.8 倍まで縮め、ボタンを広げない**（F-12）。「指でも書く」は ja ＋ 76 pt まで（F-13）、説明は 2 行までで各行がそのキーの ja のいちばん長い行以内（F-14）。どの言語でも 1.1 で見えていた部品（iPhone 17 のペンの黒、11 インチの ↷、iPad mini の太、13 インチの行の全部）が見える（§4.4） |
| 0-37 | 凍結した Ink の日本語 | `Ink/InkTrace.swift` の記録のシート（「記録」「閉じる」「コピー」「コピーしました」と、〔コピー〕する先頭の行）と `Ink/InkCanvasView.swift` の「手書きの紙」（UI テストの `--screenshot-probe` のときだけの読み上げの名前）の 6 件は、**訳さず、例外の表に入れる**（§2.5。D14 でファイルを変えられない。記録のシートは TestFlight と審査のビルドだけで、使うのは本人だけ）。**この例外は D14 の凍結の間（1.2）だけ**。Ink を変える 1.3 の契約で、6 件をキーに移すか例外のまま残すかを決める（§6.8） |
| 0-38 | 英語のページを指す時期 | アプリ（`LegalLinks.englishPagesPublished`）と、Connect の英語などのサポート・プライバシーポリシーの URL と、**各言語の説明（`description.txt`）の利用規約の URL** は、**英語のページが公開されて 200 を返してからでないと、英語のページを指したまま審査に出さない**（自動更新の購読のアプリは、規約とプライバシーポリシーの開けるリンクが求められる。審査の間に開かないと差し戻されうる）。M7B-3 の答えのとおり英語のページは 1.2 を出す日に公開するので、**1.2 は全部日本語のページを指す**（`englishPagesPublished = false`。説明の利用規約の URL は今の日本語の `app/terms.html`。L-9 が照らす）。1.2 を出した日に英語のページを公開した後、Connect の欄で直せるものは、そのとき本人に「この URL に替えてよいか」を聞いてから替える。説明は版を出した後に直せないので、英語の規約の URL にするのは 1.3 の説明から。アプリが英語のページを開くのも 1.3 から（`englishPagesPublished = true`）。このことを M7B.md に書く。英語のページを審査の前に出す案（M7B-21）は、代償があるので聞かない（本人が自分から望んだときだけ、§9 の条件（1.1 が App Store に出た後・1.2 の TestFlight を作る前に公開。返事は K が `LegalLinks` を書く前）で行う） |
| 0-39 | 土台が動いたとき | **1.1.1 は §1.5 の手順で取り込む**（第 3 版の「1.1 が差し戻されたら」は起きなかった。1.1 は公開済み）。1.1.1 が審査で差し戻されて直しが入ったら、直しは `fix-1-1-1` で作って main に入れる（1.2 は、1.1.1 が審査を通るまで main に入れない、0-40）。そのうえで、本物の `<1.1.1>` を J-1〜J-4・D14 の基準に読み替える（§1.5 の手順の 8。`ja-baseline.yml` は撮り直す） |
| 0-40 | 1.2 の TestFlight と main への merge の順 | **TestFlight は `m7b` から出す**（`gh workflow run testflight.yml --ref m7b`。testflight.yml は main にあるので走らせられる。1.1 も `m7a` から出した、M7A.md:490）。本人が実機で確かめた後（§8 の 9）に、merge の「はい」をもらう。**merge は 1.1.1 が審査を通って main に入った後だけ**（それまで main は 1.1 か 1.1.1 のまま。差し戻しの直しは 0-39）。merge の前に走らせたい新しい workflow は、`ja-baseline.yml` と同じく push のブランチでも走るようにする（`store-shots.yml` はブランチ `store-shots`、§7.5） |
| 0-41 | 週のページの id | `w-<その週の最初の列の日>`。日付の曜日が形を決める（月曜 = 月曜始まり、日曜 = 日曜始まり）。ほかの曜日は作らない。別のページなので線を写さない（K-11、§10.2） |
| 0-42 | 月のページの id | 変えない（`m1-YYYY-MM`）。線はマスの日付についていく。片方の並びにしか無い薄いマスの線は D17（§10.2） |
| 0-43 | 週の始まりの既定 | 記録が無ければ 1 回だけ判定: `onboardingDone`・`lastPageKind`・`allowFingerDrawingChosen` のどれかがあれば "monday"、無ければ "auto"（どちらも書く）。"auto" のまま、最初の pull が終わった後に 1 回だけ端末のページと照らす: 違う形だけならその形に合わせ、両方あれば多い方に合わせ（同数か今の形が多ければ今のまま）、もう一方のページ数を 1 回知らせる。書いている最中には切り替えない（§10.3）。記録が無い・壊れた値は月曜に倒す |
| 0-44 | 「自動」の決め方 | `WeekStart.automatic`: 地域が無いか JP → 月曜、`firstDayOfWeek` が日曜 → 日曜、ほか（月・土・金）→ 月曜。起動のときだけ読み（`WeekStartChoice.launchAutomatic`）、地域の変更で結果が変わったら黙って変えずトーストで知らせる（§10.3） |
| 0-45 | 週の始まりの設定の場所 | 端末ごとの UserDefaults（D16、§10.4）。書き出しにも入れない（K-5） |
| 0-46 | 写真モードの週の始まり | 引数が無ければ **月曜**（シミュレータの地域に左右されない）。`--screenshot-week-start auto\|monday\|sunday`（§10.7） |
| 0-47 | 基準の名前 | `DATA_1_1.sha256`・`Text11`・`ja-baseline.tsv`・`ja-baseline-ref.txt` の名前は変えない。中身の基準は `<1.1.1>`（`Text11` は字が同じなので e7b4d2f のまま）。CI の段の名前は「Data code frozen since 1.1.1」（§1.5） |
| 0-48 | ストアのロケール | 15（D12、§6.6、§11.2）。nl-NL・sv は入れず、公開の日にロシアの店頭で確かめる |
| 0-49 | EU の配信を入れる時期 | 1.2 の公開の後（D19、§11.1）。届け出が間に合わなければ 1.2 を 148 か国で先に出し、通った日に入れる。入れる操作は本人の「はい」の後 |
| 0-50 | 日本語のページの English のリンク | M7B-23 の答えしだい。W は別の commit（③）に分ける（§6.5、§9） |

## 0. 構成とファイル所有

```
TegakiKit/                                                    担当 H と K（行ごと）
  Package.swift                                               K   変更: Access に "DayKit"、InkModel に "Holidays"、テストの AccessTests に "DayKit"、InkModelTests に "Holidays" の依存と、:8-9 の注記だけ（§2.6）。第 4 版で K2 がテストのターゲット Compat12Tests を 1 行足す（§10.8）
  HolidayData/                                                H   新規: <国>.json 249 個・index.json・SOURCE.json・LICENSE-python-holidays.txt・CONTRIBUTORS-python-holidays.txt（SwiftPM のターゲットの外。退き先は §2.2）
  Sources/Holidays/HolidayCalendar.swift                      H   新規: HolidayCalendar・HolidaySource・HolidayEntry・HolidayFlags・HolidayYearNote（§5.3）
  Sources/Holidays/HolidaySetting.swift                       H   新規: HolidayRegion・HolidaySetting（§5.6）
  Sources/Holidays/HolidayFile.swift                          H   新規: tegaki-holidays/1 の読み込みと検査・CountryHolidays・HolidayIndex（§5.2、§5.3）
  Sources/Holidays/HolidayStore.swift                         H   新規: 場所を受け取る読み込み係・覚えておく表（§5.3）
  Sources/Holidays/JapanHolidayBridge.swift                   H   新規: 日本（JapaneseHolidays ＋ 他言語の名前）（§5.3）
  Sources/Holidays/HolidayDataLicense.swift                   H   新規: python-holidays の LICENSE の全文の写し（ファイルが読めないときの表示用。§5.9）
  Sources/Holidays/JapaneseHolidays.swift                     —   変えない
  Sources/DayKit/UILanguage.swift                             K   新規（§2.6）
  Sources/DayKit/DateText.swift                               K   新規（§3）。K2 の頭の K1+ で注記と weekTitle の引数名（§12.1）
  Sources/DayKit/WeekStart.swift                              K2  新規（§10.1）
  Sources/DayKit/KitStrings.generated.swift                   S の生成器が書く（K も S も手で直さない。§2.3）
  Sources/Layout/LayoutWords.swift                            K   新規（§4.1 F-5、§3.1）
  Sources/Layout/LayoutEvent.swift / WeekLayoutEngine.swift / DayLayoutEngine.swift / YearLayoutEngine.swift / MonthLayoutEngine.swift / AllDayBand.swift / TimedEventEngine.swift / PageLayout.swift   K   変更: 入力に holidays・words、§5.4 の表の 12 か所（月のエンジンのその場の tone の式も `LayoutMath.tone` に）、tone に workday（既定値なし。§5.4）。K2 が週と月の入力に weekStart（§10.1）
  Sources/Layout/PageNavigation.swift                         K   変更: title・compactTitle に holidays・language（§3.2）。K2 が pageId・dayRange・title・compactTitle に weekStart（§10.1）
  Sources/Layout/MonthLayout.swift                            K2  変更: firstGridDay・rowCount・grid に weekStart（§10.1）
  Sources/Access/PlanText.swift / LegalLinks.swift            K   変更: language 引数（§2.6、§6.4）
  Sources/InkModel/StrokeBudget.swift / AppExport.swift       K   変更: 文字を返す関数だけに language 引数（§2.6）。データの関数は 1 行も変えない（D14）。K2 が pageLabel は日付から形を読み、pdfFileName に weekStart（§10.1）
  Sources/InkModel/WeekStartImpact.swift                      K2  新規（§10.1。凍結の表に入れない）
  Sources/KitChecks/main.swift                                K   変更: 新しい節を呼ぶ・閾値の説明。K2 が週の始まりの節（§10.8）
  Sources/KitChecks/Text11.swift                              K   新規: 1.1（main e7b4d2f。Kit のソースは 21ceba5 から同じ）の文字の関数の写し。以後は誰も変えない（§1.3 J-3）。1.1.1 の字も同じなので e7b4d2f のまま（§1.5）
  Sources/KitChecks/HolidayChecks.swift                       H   新規: 祝日の確かめ（main.swift から呼ぶ）と、自分の #filePath から ../../HolidayData の場所を返す関数
  Tests/HolidaysTests/WorldHolidaysTests.swift ほか・HolidayDataLocation.swift   H   新規（§7.2。HolidayDataLocation は自分の `#filePath` から ../../HolidayData の場所を返す 1 つの関数）
  Tests/HolidaysTests/HolidayGeometryTests.swift              K   新規（データの暦を使うので、Holidays と Layout に依存する HolidaysTests のターゲットに置く。LayoutTests の依存は Layout だけで、Package.swift をこれ以上変えないため。ファイルの持ち主は K、場所の関数は H の HolidayDataLocation を使う）
  Tests/LayoutTests/DateTextTests.swift・KitStringsTests.swift・LayoutWordsTests.swift   K   新規
  Tests/AccessTests/PlanTextTests.swift・LegalLinksTests.swift   K   変更・新規
  Tests/LayoutTests/WeekStartLayoutTests.swift・Tests/InkModelTests/WeekStartImpactTests.swift・Tests/Compat12Tests/   K2  新規（§10.8）
  Tests/Compat10/・Tests/CompatFixtures/・Tests/Fixtures/compat11/   —   1 バイトも変えない（K-7。§1.2）
tools/holidays/                                               H   新規: gen.py・requirements.txt（版を固定）・summarize.py（国ごとの差を日本語で）・iso_regions.swift と iso-regions.txt（Foundation の 2 字の地域の一覧、§5.1）・README.md
tools/l10n/                                                   担当 S（下の 3 つを除く）
  build.py / lint.py / baseline.py / ja-baseline.tsv / ja-exceptions.txt   S   新規（§2.3、§2.7、§1.3）
  source/app-S.json / app-U.json / app-P.json / kit-K.json / kit-H.json   S・U・P・K・H がそれぞれ持つ（キーと日本語と注釈。§2.3。kit-H は祝日の印など §5.2 の Kit のキー）
  translations/{en,zh-Hans,zh-Hant,ko,fr,de,es,it,pt-BR}.json   X
  ja-baseline-ref.txt                                         C   新規: J-4 の比べる相手の commit の 1 行（C1 は e7b4d2f9c99dcfe4f7ba27ef9f81fe0466bf093d で書いた。B11 が `<1.1.1>` に読み替える、§1.5、0-39。§7.5）
  compare_shots.swift                                         C   新規: 2 つの写真のフォルダを同じ名前ごとに 1 画素ずつ比べ、違う画素の数と違いの印の画像を書く（ImageIO。J-4。リードがこの Mac で `swift tools/l10n/compare_shots.swift <1.1> <1.2> <出力>`）
tools/compat10/DATA_1_1.sha256                                K   新規: データの部分のファイルの 1.1（e7b4d2f）の sha256（D14。18 行）。B11 が `<1.1.1>` で作り直す。名前は変えない（§1.5）
tools/weekstart-compat/                                       B11・C   新規: 古い版の本物で K-11 を確かめる材料（B11 の 1 回目が移す、§1.5 の手順 7b）と、`compat-v1.0` の段（C。§10.8）
tools/typecheck/XCTestStandIn.swift                           U   変更: LanguageUITests が使う XCUI の API のうち、無いものだけを足す（`XCUIElement.otherElements` と `XCUIElement.identifier`）。`XCUIElementQuery.subscript(key:)`（:118）と `XCUIApplication.terminate()`（:131）は既にあり、同じ形の subscript を足すと `invalid redeclaration` で typecheck の手順 5 が落ちる。e7b4d2f の版（cdf3470 で 24 行増えた）の上に足し、他は変えない
Support/Products.storekit（リポジトリ直下。project.yml:106, 119）   S   変更: en_US の localizations を足す（§6.6）
Sources/TegakiCalendar/
  Resources/Localizable.xcstrings / InfoPlist.xcstrings       S（生成器が書く。手で直さない）
  Support/L10n.swift                                          S   新規: L（§2.5）
  Views/ToolbarView.swift・ToolbarLogic.swift・ToolbarDock.swift・EventEditorSheet.swift・EventEditorForm.swift・PaywallSheet.swift・WebImportSheet.swift・ExportSheet.swift・OnboardingView.swift・AccountChangeDialog.swift・RecurrenceScopeDialog.swift・SelectionMenuView.swift・EventDateText.swift   S   文字の取り出し（動きは変えない。ただし ToolbarView・ToolbarLogic は §4.4 の F-12 の、ja 以外の名前の枠だけ変わる。SelectionMenuView は §4.5 の F-15 の訳の長さの上限だけで、`margin`・`gap`・`placement` は変えない）
  Sync/SyncStatus.swift・Store/StoreStrings.swift・Store/LiveStoreClient.swift・Calendar/EventDraft.swift・Persistence/StrokeCensus.swift・Export/ExportBuilder.swift   S   同上（ExportBuilder と Views/WebImportSheet は週の始まりの分も S2、§10.5）
  Paper/*.swift・Export/PDFPageRenderer.swift・Views/StickyHeaderView.swift・Views/AllDayBandView.swift・Views/PageHeaderView.swift   P   文字の取り出しと入れ方のきまり（§4）。週の始まりの並びと色（§10.5）
  Views/PaperWords.swift                                      P   新規（§4.1）
  Views/CalendarRootScreen.swift・Views/SettingsScreen.swift・Support/ScreenshotMode.swift・Calendar/EventKitService.swift・Persistence/AppSettings.swift・Calendar/EventStoreModel.swift（第 4 版で持ち主を U に）   U   文字の取り出し ＋ 祝日の接続（§5.6〜§5.9、§7.4）＋ 週の始まり（§10）
  Persistence/HolidayChoice.swift・Views/HolidaySettingsSection.swift・Views/HolidayPickerScreen.swift・Views/LicenseScreen.swift・Persistence/WeekStartChoice.swift・Views/WeekStartSettingsSection.swift   U   新規
  Ink/*.swift（e7b4d2f で 8 ファイル: InkCanvasView・InkLedger・InkOverlayView（Pencil の `InkPencilGestureRecognizer` :557 を含む）・InkSnapshot・InkTools・InkTouchObserver（1.1）・InkTrace（1.1。`InkTrace`・`InkTraceSheet` :47）・PencilInteraction）   —   変えない（D14。中の日本語は §2.5 の例外）
  Sync/SyncEngine.swift・Sync/InkPageRecord.swift・Persistence/InkPageStore.swift   —   変えない（D14）
  PrivacyInfo.xcprivacy                                       —   変えない（§2.2。理由の要る API を足すときだけ C が直す）
Tests/TegakiCalendarTests/
  LocalizationBundleTests.swift（新規）・L10nTests.swift（新規）・EventDateTextTests.swift（新規）・ToolbarFitTests.swift（新規、§4.4・§4.5 の F-15）と、S のファイルのテスト（ToolbarLogicTests.swift など）   S
  PaperFitTests.swift（新規。§4.5 の F-16 も）・PaperViewTests.swift   P
  HolidayChoiceTests.swift（新規）・SettingsScreenTests.swift・CalendarRootScreenTests.swift・ScreenshotModeTests.swift・EventKitServiceTests.swift・AppSettingsTests.swift・WeekStartChoiceTests.swift（新規）・WeekStartLedgerTests.swift（新規）・SyncEngineTests.swift（足すだけ）   U
  InkCanvasViewTests.swift（e7b4d2f で 3,057 行。1.1 の後半（b13fa91 から）で +1,415 −4。B11 の後は 1.1.1 のものを凍結、§1.5）   —   変えない（凍結した Ink のテスト。P の `PaperView`・`PaperContent` の各型、S の `SelectionMenuView`、U の `CalendarRootScreen.newEventPlan` を使う。§0 の接点の最後の段）
Tests/TegakiCalendarUITests/LanguageUITests.swift（新規）・YearTapUITests.swift・EraserAndBelowDayUITests.swift と 1.1.1 の HeaderAndPaperUITests.swift・BlankPaperShotsUITests.swift（この 4 つは起動の引数だけ。§7.3、§1.5）・WeekStartUITests.swift（新規。§10.8）   U
docs/i18n/GLOSSARY.md・docs/i18n/REVIEW.md                    X
docs/i18n/back/<言語>.json・docs/i18n/back/legal-en.md・docs/i18n/back/store-<ロケール>.md   R（逆翻訳。日本語の元を見ない）
docs/TERMS.md・PRIVACY.md・SUPPORT.md（直す所だけ）・docs/TERMS.en.md・PRIVACY.en.md・SUPPORT.en.md（新規）   L（第 4 版の直しは LA2、§12.1）
Web リポジトリ（/Users/ikedamasataka/Documents/Codex/tegaki-calendar、ブランチ m7b-legal）   W
docs/store/**（新規）・docs/support-replies/**（新規）     A（第 4 版の直しは LA2、§12.1）
project.yml・.github/workflows/build.yml・.github/workflows/store-shots.yml（新規）・.github/workflows/ja-baseline.yml（新規、J-4）・docs/M7B.md・README.md・docs/DESIGN.md・docs/M7_PLAN.md・docs/B_DESIGN.md（写すならリード、§6.8）   C
```

依存の向き: `TegakiCalendar` → `TegakiKit`。`Holidays` → `DayKit`（今のまま）。**`Access` → `DayKit`**（新しい依存。`UILanguage` と `KitStrings` のため。DayKit は Foundation だけなので Access の「純粋」は保たれる。typecheck.sh は DayKit を先に作るので順番は変わらない。Access は DayKit を再公開しないので、`UILanguage` を名前で使う `AccessTests` にも "DayKit" を足す、§2.6）。**`InkModel` → `Holidays` を明示**（今も `Layout` を通して見えているが、`AppExport.pdfFileName(kind:focus:holidays:language:)` が `HolidayCalendar` を受けるので、宣言していない依存に頼らない。typecheck.sh は Holidays を InkModel より先に作るので順番は変わらない）。**1 つのファイルの持ち主は 1 人**。生成物（`*.xcstrings`・`KitStrings.generated.swift`）の持ち主は S だが、書くのは `build.py` だけ。S・U・P・K・H は自分の元のファイル（`tools/l10n/source/*.json`）にだけキーを足し、X は訳のファイルだけ、R は逆翻訳のファイルだけを書く。担当 W は Web リポジトリだけ（commit だけ。push しない・merge しない）。App Store Connect への入力は A の原稿をもとにリードが本人の Chrome で行う。**入力は、本人が §8 の 11 の言語ごとの確認表を見て「この内容で入れてよい」と言った後だけ**（M7B-18 は「はい」、2026-11-01。確認表を見せてから入れる約束）。提出のボタンは本人。**凍結したファイル（D14 の 18 ファイルと、誰も変えない `InkCanvasViewTests.swift`）が使う名前は、持ち主でも変えない**（下の接点の最後の段）。**この表に持ち主の無いアプリのファイルは 1.2 で変えない**（同じ段の最後の行）。commit は `git add <ファイル名>` で行う（`git add -A`・`git add .` を使わない。この Mac の作業ツリーには未追跡の複製がある、§8 の 1）。

**接点（全部この形に固定。新しい引数には既定値を付け、既存の呼び出しと既存のテストが変わらずに通る）**

```swift
// ── K: DayKit ─────────────────────────────────────────────────────
// DayKit/UILanguage.swift（新規）
public enum UILanguage: String, CaseIterable, Sendable, Codable {
    case ja, en, zhHans = "zh-Hans", zhHant = "zh-Hant", ko, fr, de, es, it, ptBR = "pt-BR"
    /// Bundle の言語名から。"ja"→ja、"en"・"en-GB"→en、"zh-Hans"・"zh-CN"・"zh-SG"→zhHans、"zh-Hant"・"zh-TW"・"zh-HK"・"zh-MO"・
    /// "yue-Hant"→zhHant、"ko"→ko、"fr"・"fr-CA"→fr、"de"・"de-CH"→de、"es"・"es-419"・"es-MX"→es、"it"→it、"pt"・"pt-BR"・"pt-PT"→ptBR。
    /// 大文字小文字と "_" を区別しない。ほか・nil・空は en（O-1）
    public static func resolve(_ localization: String?) -> UILanguage
    /// 画面の言語 = resolve(Bundle.main.preferredLocalizations.first)（iOS は言語を変えるとアプリを終わらせるので起動中は変わらない）
    public static var current: UILanguage { get }
    /// 書式の Locale「<rawValue>_<地域>」（地域が nil・空なら言語だけ）。例 .en, "JP" → en_JP、.zhHant, "HK" → zh-Hant_HK
    public func locale(region: String? = Locale.current.region?.identifier) -> Locale
    public func pluralCategory(_ n: Int) -> PluralCategory          // 0-8
    public var isCJK: Bool { get }                                   // ja・zhHans・zhHant・ko
}
public enum PluralCategory: String, Sendable { case one, other }
// DayKit/KitStrings.generated.swift（生成物。§2.3）
public enum KitStrings {
    public static let keys: [String]
    public static func text(_ key: String, _ language: UILanguage) -> String                      // 無い言語は en、無いキーはキーそのもの
    public static func format(_ key: String, _ language: UILanguage, _ args: [String]) -> String  // %@ と %n$@ だけを置き換える（String(format:) を使わない）
    public static func plural(_ key: String, _ language: UILanguage, count: Int, _ args: [String]) -> String  // key + ".one" / ".other"
}
// DayKit/DateText.swift（新規。§3）
public enum WeekdayStyle: Sendable { case letter, short, full }
public enum MonthNameStyle: Sendable { case short, full }
public enum DateText {
    public static let mondayFirst: [Int]                              // [1, 2, 3, 4, 5, 6, 0]（DayKey.weekday の並び。= WeekStart.monday.order）
    public static func calendar(_ language: UILanguage, region: String? = Locale.current.region?.identifier, timeZone: TimeZone = .current) -> Calendar
    public static func weekdays(_ style: WeekdayStyle, _ language: UILanguage) -> [String]   // 7 個、DayKey.weekday（0 = 日曜）の順。§3.3
    public static func monthName(_ month: Int, _ style: MonthNameStyle, _ language: UILanguage) -> String
    public static func dayTitle(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String
    public static func shortDay(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String
    public static func monthTitle(_ month: YearMonth, _ language: UILanguage, compact: Bool = false, region: String? = Locale.current.region?.identifier) -> String
    public static func yearTitle(_ year: Int, _ language: UILanguage) -> String
    public static func weekTitle(first: DayKey, _ language: UILanguage, compact: Bool, region: String? = Locale.current.region?.identifier) -> String   // K1 は monday: で書いた。K2 の頭の K1+ で first: に（§12.1）
    public static func spokenDay(_ day: DayKey, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String
    public static func numericDate(_ date: Date, _ language: UILanguage, region: String? = Locale.current.region?.identifier, timeZone: TimeZone = .current) -> String       // 日付だけ（購入の日付）。0-33
    public static func numericDateTime(_ date: Date, _ language: UILanguage, region: String? = Locale.current.region?.identifier, timeZone: TimeZone = .current) -> String   // 日付と時刻（「最後に同期」「前回の取り込み」）。0-33
    public static func time(hour: Int, minute: Int) -> String         // "9:05"（全言語。D7）
    public static func number(_ n: Int, _ language: UILanguage, region: String? = Locale.current.region?.identifier) -> String
}
// YearMonth の拡張（DayKey.swift は変えない。DateText.swift の中に）
extension YearMonth { public func title(language: UILanguage) -> String }   // = DateText.monthTitle。今の title（ja）は残す
// DayKit/WeekStart.swift（新規。K2。形は §10.1）: WeekStart（case monday, sunday）・firstWeekday・order・column(of:)・firstDay(of:)・init?(weekPageDate:)・automatic(region:firstDayOfWeek:)

// ── H: Holidays ───────────────────────────────────────────────────
public struct HolidayFlags: OptionSet, Hashable, Sendable { public let rawValue: Int
    public static let estimated = HolidayFlags(rawValue: 1); public static let observed = HolidayFlags(rawValue: 2); public static let substituted = HolidayFlags(rawValue: 4) }
public struct HolidayEntry: Hashable, Sendable {
    public var full: String; public var short: String; public var flags: HolidayFlags; public var isSubdivision: Bool
    public init(full: String, short: String, flags: HolidayFlags = [], isSubdivision: Bool = false)
}
public protocol HolidaySource: Sendable {
    func entries(forYear year: Int) -> [DayKey: [HolidayEntry]]       // 国の祝日が先（州の remove を除く）、州・地域の祝日が後。どちらもデータの順のまま（並べ替えない。§5.3）
    func workdays(forYear year: Int) -> Set<DayKey>                     // 出勤日になる週末（無ければ空）
    func note(forYear year: Int) -> HolidayYearNote?                    // 0-29・0-30（日本・なしは常に nil）
}
public enum HolidayYearNote: Sendable, Equatable {
    case beforeNotice                                                   // notice の国で lastOfficialYear より後（0-29）
    case incomplete(until: Int)                                         // coverage の外（0-30。until = 範囲の最後の年）
}
public struct HolidayCalendar: Sendable, Equatable {
    public enum NameStyle: Sendable { case full, short }
    public static let japan: HolidayCalendar                            // JapaneseHolidays・日本語の名前（= 1.1）。id "JP|ja"
    public static let none: HolidayCalendar                             // id "none"
    public let id: String                                               // "<地域のコード>|<UILanguage.rawValue>" か "none"。== は id だけで比べる
    public let region: HolidayRegion?
    public init(id: String, region: HolidayRegion?, source: any HolidaySource)
    public func names(for days: [DayKey], style: NameStyle = .full) -> [DayKey: String]   // 2 つ以上は " · " でつなぐ（0-16）。full は推定の印つき（0-17）
    public func name(of day: DayKey, style: NameStyle = .full) -> String?
    public func isWorkday(_ day: DayKey) -> Bool
    public func note(forYear year: Int) -> HolidayYearNote?
}
public struct HolidayRegion: Hashable, Sendable {
    public let country: String; public let subdivision: String?        // "US" / "CA"。国は大文字、州・地域は渡された表記のまま（0-28）
    public init?(code: String)                                          // "US"・"us"・"US-CA"・"GB-SCT"・"NZ-South Canterbury"・"AR-C"・"AT-9"・"FR-971"。国は英字 2 字、州は最初の "-" の後ろの 1〜40 字の [A-Za-z0-9 ]。
                                                                        // それ以外（""・"-"・"US-"・"-CA"・"US--CA"・"J"・"JPN"・"1A"・"US-C@"）は nil
    public var code: String { get }                                     // "US-CA"
}
public enum HolidaySetting: Hashable, Sendable {
    case automatic, none, region(HolidayRegion)
    public init(storageValue: String?)                                  // "auto"・nil・空・壊れた値 → automatic、"none" → none、他 → region
    public var storageValue: String { get }                             // "auto" / "none" / "US-CA" / "NZ-South Canterbury"
    public func resolved(deviceRegion: String?, index: HolidayIndex?) -> HolidayRegion?   // automatic は端末の地域（州なし）。データに無い国は nil（0-20）。州は index.canonical で照らし直す
}
public struct HolidayIndex: Sendable {
    public struct Country: Sendable {
        public let code: String
        public let subdivisions: [Subdivision]          // 全国と差のある州・地域だけ（§5.1）。空なら州の画面を出さない
        public let renamed: [String: String]            // 旧コード → 今のコード（版を上げて改名された州。§5.11。0.83 では空）
        public let lastOfficialYear: Int?               // ライブラリの特別の表の最後の年（0-29）
        public let notice: Bool                         // 政府の毎年の通知で休みが決まる国（0-29）
        public let coverage: ClosedRange<Int>           // データの揃っている年（0-30）
    }
    public struct Subdivision: Sendable {
        public let code: String                         // データの表記（"CA"・"971"・"South Canterbury"）
        public let display: String                      // 画面に出す名前（§5.2。"Auckland"・"Nova Scotia"・"Guadeloupe"）
        public let names: [String]                      // 検索に使う別名（ライブラリの順）
        public let local: Bool                          // ISO の形でない地域（市など。"Augsburg"・"Andria"・"South Canterbury"）。州の画面で別の見出しの下へ
    }
    public let countries: [Country]
    public func country(_ code: String) -> Country?                     // 大文字小文字を区別しない
    public func canonical(_ region: HolidayRegion) -> HolidayRegion?    // 州を大文字小文字を区別せずに照らし（renamed も）、データの表記で返す。知らない州 → 国全体、知らない国 → nil
}
public final class HolidayStore: @unchecked Sendable {                 // 中で NSLock。読んだ国は覚える。年の表は国ごとに 8 年分まで
    public init(directory: URL?)                                        // nil・読めない場所でも落ちない（日本は JapaneseHolidays、他は none）
    public var index: HolidayIndex? { get }                             // 初めて読まれたときに読む（設定の画面を開いたとき。起動では読まない、§5.3）
    public func hasCountry(_ code: String) -> Bool                      // <国>.json があるか（index を読まずに。自動の決め方用）
    public func calendar(for region: HolidayRegion?, language: UILanguage) -> HolidayCalendar   // nil → none、JP → JapanHolidayBridge、他 → データ（読めなければ none）
    public func isReadable(_ region: HolidayRegion) -> Bool             // その国のファイルが読めて検査を通るか（0-20 の注記用）
}
public enum HolidayDataLicense {                                        // §5.9
    public static let mitText: String                                   // LICENSE-python-holidays.txt と 1 バイトも違わない写し（KitChecks で照らす）
    public static let contributorsURL: URL                              // https://github.com/vacanza/holidays/blob/v<版>/CONTRIBUTORS（<版> は §5.1 で固定した版）
}
// テストと KitChecks の場所: HolidaysTests の HolidayDataLocation.swift と KitChecks の HolidayChecks.swift の中の関数（どちらも自分の #filePath から ../../HolidayData）。HolidayStore には置かない

// ── K: Layout（新しい引数は既存の最後の引数 calendar: の後に、この順で）──
public struct LayoutWords: Equatable, Sendable {
    public var moreOne: String; public var moreOther: String            // "+%@件"（ja は両方同じ）
    public var tailPrefix: String                                       // "〜"（日をまたぐ予定の終わりのチップ「〜11:00」）
    public var timeRange: String                                        // "%1$@〜%2$@"
    public var language: UILanguage                                     // 複数形の規則に使う
    public static let japanese: LayoutWords                             // 1.1 と同じ字
    public static func of(_ language: UILanguage) -> LayoutWords        // KitStrings から
    public func more(_ n: Int) -> String
}
// MonthLayoutInput / WeekLayoutInput / DayLayoutInput / YearLayoutInput の init に: holidays: HolidayCalendar = .japan, words: LayoutWords = .japanese
// AllDayBandLayout.empty(kind:days:holidays: HolidayCalendar = .japan)   // tones を holidays の名前と isWorkday から
// AllDayBandEngine.week(monday:events:now:calendar:holidays: HolidayCalendar = .japan)   // 中で empty(kind: .week, days:, holidays:) にそのまま渡す（AllDayBand.swift:134, 137）
// AllDayBandEngine.week(firstDay:weekStart:events:now:calendar:holidays:) を本体にし、上の monday: の形は .monday で呼ぶだけ（§10.1。K2）
// MonthLayout.firstGridDay・rowCount・grid、MonthLayoutInput・WeekLayoutInput の init、PageNavigation.pageId・dayRange に: weekStart: WeekStart = .monday（§10.1。K2。最後の引数）
// AllDayBandEngine.day(_:events:now:calendar:holidays: HolidayCalendar = .japan)          // 同じく（:168, 169）。呼ぶ側は WeekLayoutEngine.swift:180・DayLayoutEngine.swift:186 が input.holidays を渡す
// LayoutMath.tone(of:holiday:workday: Bool)                            // workday なら .normal（§5.4）。内部の関数なので既定値を付けない（呼ぶ 5 か所が全部渡さないと組み立たない）
// MonthLayoutEngine.timeText(for:dayStart:dayEnd:calendar:words: LayoutWords = .japanese)
// TimedEventEngine.timeRangeText(start:end:calendar:words: LayoutWords = .japanese)
public static func title(_ kind: PageKind, focus: DayKey, holidays: HolidayCalendar = .japan, language: UILanguage = .ja, weekStart: WeekStart = .monday) -> String   // PageNavigation
public static func compactTitle(_ kind: PageKind, focus: DayKey, language: UILanguage = .ja, weekStart: WeekStart = .monday) -> String
// PageNavigation.weekdayLetters は ja のまま残す（= DateText.weekdays(.letter, .ja)）

// ── K: Access / InkModel（文字だけ。既定 .ja で 1.1 と同じ）────────────
// PlanText: name(_:language:)・perPeriod(_:language:)・savingsText(months:language:)・statusTitle(_:language:)・dateLabel(_:language:)・
//           readOnlyNote(_:language:)・yearlyBadge(language:)・readOnlyBadgeText(language:)・cancelPath(language:)・paymentPath(language:)
//           （今の static let yearlyBadge・readOnlyBadge・cancelPath・paymentPath は ja の値として残す）
// LegalLinks: static let englishPagesPublished（1.2 は false。英語のページは 1.2 を出す日に公開するので、true にするのは 1.3、0-38）、terms(for:published:)・privacy(for:published:)・support(for:published:)
//             （published の既定 = englishPagesPublished）、appleEULATitle(_ language:)。今の terms・privacy・support・appleEULATitle は ja として残す
// StrokeBudget: pageLabel(_:)（ja のまま。KitChecks と既存のテストの .map(StrokeBudget.pageLabel) のため）と pageLabel(_:language:)（既定なし。既定値付きの 1 つにすると .map が組み立たない）・countText(_:language:)。AppExport: jsonFileName(exportedAt:calendar:language:)・
//               pdfFileName(kind:focus:holidays:language:weekStart:)・kindLabel(_:language:)。WeekStartImpact: hiddenStrokeIds(in:weekStart:)・weekPages(_:)（§10.1。K2）

// ── S: アプリ ──────────────────────────────────────────────────────
enum L {                                                                // Support/L10n.swift
    static let language: UILanguage                                     // 起動時に UILanguage.current を 1 回だけ読む
    static var locale: Locale { get }                                   // language.locale()
    static func text(_ key: String) -> String                           // Localizable。無いキー → en.lproj の値 → キー（DEBUG と写真モードでは NSLog "l10n: missing <key>"）
    static func text(_ key: String, in language: UILanguage) -> String  // その言語の .lproj から（テストと言語の選び方の確かめだけ）
    static func format(_ key: String, _ args: String...) -> String
    static func plural(_ key: String, count: Int, _ args: String...) -> String
}
// ToolbarLogic.Row（Views/ToolbarLogic.swift。§4.4 の F-12）:
//   static func labelFrameWidth(for language: UILanguage) -> CGFloat?   // ja → nil（1.1 の道: 名前の幅で広がる）、他 → 38（枠を固定）
//   static let labelMinScale: CGFloat = 0.8                             // ja 以外の名前を縮める下限
// EventDateText（Views/EventDateText.swift。テストで言語を渡せるように）:
//   static func dayTitle(_ day: DayKey, language: UILanguage = L.language) -> String
//   static func when(start: Date, end: Date, allDay: Bool, language: UILanguage = L.language) -> String
//   （中身は全言語 DateText。ja は手作りの式なので 1.1 の 3 つの DateFormatter と同じ字。今の 1 引数・3 引数の呼び出しはそのまま通る）
// SettingsScreen（U が呼び出しを直す）: timeText(_:) → DateText.numericDateTime、dateText(_:locale:) は形を残す（§3.2）
// WebImportSheet（S2 が型と文、U が値。並行なのでこの形から変えない。§10.5）:
//   WebImportPhase.done(ImportOutcome, skipped: Int, isAppExport: Bool, otherWeekStart: WeekStart? = nil)   // 最後に足す。既定 nil で今の呼び出しとテストはそのまま通る。パターンは 4 つにする（WebImportSheet の本体・CalendarRootScreen.closeImportSheet）
//   static func toastText(outcome: ImportOutcome, skipped: Int, isAppExport: Bool = false, otherWeekStart: WeekStart? = nil) -> String   // 結果の行・飛ばした行の下に import.otherWeekStart.* の 1 行
// ── P ──
enum PaperWords {                                                       // Views/PaperWords.swift（§4.1）
    static func yearWeekday(_ weekday: Int, _ language: UILanguage) -> String
    static func monthHeaderWeekdays(_ language: UILanguage, weekStart: WeekStart) -> [String]   // weekStart の順の 7 個（§10.5）
    static func weekColumnWeekday(_ weekday: Int, columnWidth: CGFloat, _ language: UILanguage) -> String
    static func yearColumnTitles(columnWidth: CGFloat, fontSize: CGFloat, _ language: UILanguage) -> (titles: [String], scale: CGFloat?)   // nil = 1.1 と同じ（各月 0.7 まで）
    static func allDayLabel(widthPoints: CGFloat, fontSize: CGFloat, _ language: UILanguage) -> String?   // nil = 出さない（F-7）
}
// PaperText に: static func drawFittedLine(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, minScale: CGFloat, scale: CGFloat? = nil)
// ── U ──
enum HolidayChoice {                                                    // Persistence/HolidayChoice.swift
    @MainActor static var current: HolidayCalendar                      // 既定 .japan。main の外（書き出し・PDF）へ値を渡すための写し。起動と設定の変更で U が入れる。
                                                                        // 画面の body では読まない（§5.6。SwiftUI がこの変化を見ないので題名だけ古くなりうる）
    static let store: HolidayStore                                      // HolidayStore(directory: Bundle.main.url(forResource: "HolidayData", withExtension: nil))
    static func setting(_ defaults: UserDefaults = AppSettings.defaults) -> HolidaySetting
    static func migrateIfNeeded(_ defaults: UserDefaults = AppSettings.defaults)          // §1.4（記録が無いときだけ "JP" か "auto" を書く）
    static func calendar(setting: HolidaySetting, deviceRegion: String?, language: UILanguage, store: HolidayStore) -> HolidayCalendar
    static func summary(setting: HolidaySetting, deviceRegion: String?, language: UILanguage, store: HolidayStore, year: Int) -> String   // 設定の行の値（§5.7。year は今年）
}
enum WeekStartChoice {                                                  // Persistence/WeekStartChoice.swift（§10.3）
    enum Setting: String { case auto, monday, sunday }
    @MainActor static var current: WeekStart                            // 既定 .monday。main の外（書き出し・PDF）へ値を渡すための写し（HolidayChoice.current と同じ）。画面の body は @State weekStart を読む（§10.5）
    static func setting(_ defaults: UserDefaults = AppSettings.defaults) -> Setting      // 無い・壊れた値は .monday（線が動かない側に倒す）
    static func migrateIfNeeded(_ defaults: UserDefaults = AppSettings.defaults)          // 記録が無いときだけ "monday" か "auto" を書く（§10.3）
    static let launchAutomatic: WeekStart                               // 起動時に 1 回だけ Locale.current を読む（L.language と同じ。L-14 で地域の週の始まりを読むのはここだけ）
    static func resolve(_ setting: Setting) -> WeekStart                // auto → launchAutomatic。アプリはこれを呼ぶ
    static func resolve(setting: Setting, region: String?, firstDayOfWeek: Locale.Weekday) -> WeekStart   // テスト用（地域を渡す）
    @MainActor static func prepareAtLaunch(shot: ScreenshotMode.Config?, _ defaults: UserDefaults = AppSettings.defaults) -> WeekStart   // init から 1 回。migrate → 値を決める → current に入れて返す（§5.6、§10.5。写真モードは migrate せず Config.weekStart）
    static func readyToCheck(status: SyncStatus, zoneToken: Data?) -> Bool   // §10.3 の 4。.synced かつ sync.state.zoneToken != nil（pull が 1 度終わった印。lastSyncAt は push でも書かれるので印にならない）
    enum DataCheck: Equatable {                                         // §10.3 の 4 の結果
        case wait                                                       // 合わせたいが利用者が書いている。設定も dataChecked も書かず、次の show か .active でやり直す
        case finish                                                     // 週のページが無いか今の形だけ。知らせない
        case adopt(WeekStart, otherPages: Int)                          // その形に合わせる。otherPages > 0 なら、今まで見ていた形のページ数も知らせる
        case stay(otherPages: Int)                                      // 今のまま。もう一方の形のページ数を知らせる
    }
    static func dataCheck(current: WeekStart, pageIds: [String], dirtyPageId: String?, penTouched: Bool, atBoundary: Bool) -> DataCheck   // 純関数。設定が auto で dataChecked がまだのときだけ呼ぶ（§10.3 の 4）
}
enum WeekStartNotice: Equatable {                                       // Persistence/WeekStartChoice.swift（§10.4 の「トーストの出し方」）
    case hiddenInk(pageId: String, strokes: Int), adopted(WeekStart), regionChanged(WeekStart), otherForm(WeekStart, pages: Int)
}
struct WeekStartNotices {                                               // 純粋な値。画面が 1 つ持つ
    mutating func add(_ notice: WeekStartNotice)
    mutating func next(sheetIsUp: Bool, toastShowing: Bool, currentPageId: String) -> WeekStartNotice?   // 出せるときだけ 1 つ取り出す。今のページと違う hiddenInk は捨てる
}
// AppSettings: static let holidaySettingKey = "holidays.setting"（String。§5.6）。weekStartKey = "weekStart.setting"・"weekStart.lastAuto"・"weekStart.dataChecked"・"weekStart.hiddenNoticed"（§10.3）
// CalendarRootScreen: @AppStorage(AppSettings.holidaySettingKey) private var holidaySettingRaw = ""、
//   private var holidays: HolidayCalendar（holidaySettingRaw と写真モードの Config から HolidayChoice.calendar で作る計算プロパティ。body の題名はこれを使う）、
//   @AppStorage(AppSettings.weekStartKey) private var weekStartRaw = ""、@State private var weekStart: WeekStart（§10.5）、
//   @State private var penTouchedThisLaunch = false・pendingAdoption = false・weekStartNotices = WeekStartNotices()（§10.3、§10.4）、
//   static func weekStartSwitch(old:new:save:apply:reload:)（§10.5。順番だけを持つ純関数。テストから呼ぶ）、
//   static func makePaper(kind:focus:events:inkBottoms:now:holidays: HolidayCalendar, weekStart: WeekStart)（テストから呼べるよう private を外す。紙の組み立ては、渡された 1 つの暦だけを *LayoutInput と
//   月の holidayNames（:1162）の両方に使う。init は設定から作った暦、relayout は HolidayChoice.current を渡す。§5.6）
// ScreenshotMode.Config: holidays: HolidaySetting（既定 .region(JP)。1.1 の後半で増えた probe・select と 1.1.1 の empty・pinchHint の後ろに足す。
//   parse の最後の Config(…, grown:, probe:, select:)（:198）と既存のテストはそのまま通る）、Sheet.holidays（10 個目）。その後ろに weekStart: WeekStart（既定 .monday、§10.7）、Sheet.weekStart（11 個目）
// ScreenshotMode: demoEvents(for month: YearMonth, empty: Bool = ScreenshotMode.current?.empty ?? false, language: UILanguage = L.language)（1.1.1 の empty: の後ろに足す）・calendarTitle(forCalendarId:language: UILanguage = L.language)・
//   calendarOptions(language: UILanguage) を足す（今の static var calendarOptions は残し、中で L.language を渡す）。demoPage(kind:focus:grown:empty:) は言語を受けない（変えない。手書きの見本が言語に依らないことの形の上の保証）。第 4 版で 1.1.1 の empty: の後ろに weekStart: WeekStart = .monday を足す（§10.5）
// 写真モードの読み上げの部品 "l10n.state"（§7.3）: 1×1 pt の Color.clear に .accessibilityElement()・.accessibilityIdentifier("l10n.state")・.accessibilityLabel(<状態>)。
//   .hidden() と .opacity(0) は使わない（読み上げの木から消えて XCUITest で見つからない）。.allowsHitTesting(false) を付ける（UI テストの指と紙の触れ方に当たらない）

// ── 凍結したファイルが使う名前 ─────────────────────────────────────────────
//   凍結したファイル = D14 の 18 ファイル（InkModel の 7・Ink/*.swift の 8・Sync/SyncEngine.swift・Sync/InkPageRecord.swift・
//   Persistence/InkPageStore.swift、§1.1）と、誰も変えない InkCanvasViewTests.swift。これらが使う名前は、持ち主でも名前・型・case・
//   引数の形・memberwise の init の形を変えない（凍結したファイルは直せないので、変えると組み立てが落ちる）。型に項目を足すなら既定値を付ける。
//   確かめ: この Mac の typecheck.sh の手順 4（アプリ）と手順 5（テスト）、CI の組み立てで、凍結したファイルが 1 行も変えずに組み立つこと
// S: Sync/SyncStatus.swift（S は文を L に移すだけ。Sync/SyncEngine.swift が使う）: SyncStatus の 7 つの case（.localOnly(LocalOnlyReason)・.synced・
//    .pending・.syncing・.offline・.error(SyncErrorKind)・.accountMismatch）、LocalOnlyReason（.noAccount・.restricted・.unknown・.notAuthenticated）、
//    SyncErrorKind（.quota・.permission・.server(String)）、SyncSnapshot(status:lastSyncAt:dirtyCount:webImportedAt:)、
//    AccountChangeChoice（.keepInk・.eraseInk・.later）、ImportOutcome(pagesChanged:strokesAdded:pagesSeen:)。
//    SelectionMenuView.margin・SelectionMenuView.placement(anchor:size:bounds:)（InkCanvasViewTests.swift:2415-2416）
// U: ScreenshotMode.current: Config?（Ink/InkCanvasView.swift:659 が .probe を、Sync/SyncEngine.swift:20-21 が .today を読む）・
//    ScreenshotMode.isActive: Bool（Ink/InkTrace.swift:41、Sync/SyncEngine.swift:20, 45）・ScreenshotMode.Config.probe: Bool・Config.today: Date・
//    SettingsScreen.versionText: String（Ink/InkTrace.swift:33）・CalendarRootScreen.newEventPlan(layout:rect:now:) と
//    CalendarRootScreen.NewEventPlan.refusedBelowDay（InkCanvasViewTests.swift:2418, 2504）。
//    逆に SettingsScreen は凍結した InkTraceSheet(text:onDone:)・InkTrace.text・InkTrace.isAvailable を呼ぶ（:204-206・:573）。消さない
// P: PaperView(content:)（init(content:zoomScale:)）・PaperView.content の読み書き（== で比べる。Ink/InkCanvasView.swift:102, 210, 854, 1002-1003）・
//    PaperView.zoomScale（:211）・PaperView.show(visible:zoom:contentSize:live:)（:1245）・PaperView.contentWindow・displayRequestCount（InkCanvasViewTests）、
//    PaperContent の 4 つの case（.month・.week・.day・.year）、MonthPaperContent(layout:labels:bars:chips:holidayNames:)・WeekPaperContent(layout:)・
//    DayPaperContent(layout:)・YearPaperContent(layout:monthNames:)（InkCanvasViewTests.swift:62, 69, 76, 82, 849, 2304）。これらの型に足す項目には
//    既定値を付け、今の memberwise の呼び出しがそのまま通るようにする
// K: 凍結した InkModel の 7 つと Ink/* が使う Kit の名前は、§0 の接点のとおり既定値つきの引数を足すだけ（名前・型は変えない）
// 持ち主の無いアプリのファイル（App.swift・ContentView.swift・Support/AppDelegate.swift・Store/StoreModel.swift・
//    Store/AccessCacheStore.swift・Persistence/SyncStateStore.swift・Sync/CloudDatabase.swift・CloudKitDatabase.swift・InMemoryCloudDatabase.swift・
//    Views/ToastView.swift。日本語の文字列は無い。凍結したファイルが使う CloudDatabase・CloudRecord・SyncState などを定義する）は 1.2 で変えない。
//    変える要が出たら、リードが持ち主を決めて M7B.md に書く
```

## 1. データ互換（K-1〜K-9・K-11）と「日本語の利用者は 1.1.1 のまま」

本人は iPad と iPhone で使っている。片方が 1.0.x か 1.1 か 1.1.1、もう片方が 1.2、という時期が必ずある。**どちらの端末も、相手の手書きを消したり動かしたりしてはいけない。** そして **日本語の端末で使っている人には、1.2 にしても 1.1.1 と同じ画面が出なければならない**（違ってよいのは設定の「週の始まり」と「祝日」の節と「オープンソースのライセンス」の行と、今日が 31 日のときに年のマスの太字の「31」が欠けなくなること（§4.1 の F-1）だけ。今お使いの方は週も月曜始まりのまま）。

### 1.1 1.2 で変わらないもの（D14）

- 手書きのデータの部分: `TegakiKit/Sources/InkModel/{InkPage,InkStroke,InkPageCodec,BandMigration,JSONValue,WebImport,InkImport}.swift`、`Sources/TegakiCalendar/Ink/*.swift`（e7b4d2f で 8 ファイル。1.1 の後半で `InkTouchObserver.swift`・`InkTrace.swift` が増え、`InkCanvasView.swift`・`InkOverlayView.swift` は b13fa91 から変わった。`InkTrace.swift` と `InkCanvasView.swift` は画面と読み上げの日本語を持つ → §2.5 の例外）、`Sync/SyncEngine.swift`・`Sync/InkPageRecord.swift`、`Persistence/InkPageStore.swift`。K が e7b4d2f（1.1 を main に merge した commit）でこれらの sha256 を `tools/compat10/DATA_1_1.sha256` に書き（18 行。b13fa91 なら 16 行）、**B11 が `<1.1.1>` で作り直し**（§1.5）、CI の「Data code frozen since 1.1.1」で照らす。`AppExport.swift` と `StrokeBudget.swift` は文字の関数だけ変わるので表に入れず、`Compat10ExportTests`・`StrokeBudgetTests` で確かめる。この表は 1.2 の間だけの守り。1.3（B-1）は Ink と InkModel を変えるので、1.3 の契約で作り直す（B_DESIGN §13 の凍結表の更新手順）。
- マス名・線の項目・`v`・書き出しの形式。月曜の道のページ id。**1.2 は新しいマスの名前を作らない。新しいページの形は `w-<日曜>` の 1 つだけ**（日曜始まりを選んだ端末でだけできる。K-11）。
- 紙の形（マスの位置・行の高さ・タップの枠・一覧の矩形）。字の大きさは描くときだけ使い、配置の計算では一切測っていない（偵察で確認: 年のタップ枠 40 × 28 `YearLayoutEngine.swift:359`、チップの位置 50.4 / 58.6 lu :369-370、メモの字の枠 200 lu はすべて定数）。基準の紙の形は 1.1.1 のもの（§1.5）。日曜始まりの月のページでも紙の幅と 6 行 42 マスは同じ（§10.2）。
- 曜日の計算は `DayKey` の通し番号（`DayKey.swift:59-62`、`MonthLayout.swift:59`）。`Calendar.firstWeekday`・`weekOfYear`・`dateInterval(of:)` を読むコードは無いまま。週の並びは入力の `weekStart` だけで決まり（§10.1）、地域の値 `Locale.firstDayOfWeek` を読むのは `WeekStartChoice` だけ（L-14）。

### 1.2 守る規則 K-1〜K-9・K-11 と、この版での当てはめ

- **K-1**（`allday` で始まる名前を使わない）: 1.2 は新しい名前を作らない。`HolidayCalendar.id`（"JP|ja" など）は端末の中だけの値で、ページ id・マス名ではない（保存も同期もしない）。
- **K-2**（同じ id のまま別のマスへ付け替えない）: 1.2 は線を動かさない。週の始まりを切り替えても動かさない（K-11）。
- **K-3**（1 つのページに 2 枚のキャンバス）: キャンバスは 1 枚のまま。
- **K-4**（マスの意味を変えない）: 祝日・言語は枠を変えない（D9）。KitChecks の G-1〜G-3（§7.1）で固定する。週の始まりは月のマスの並びを変えるが、マスの鍵は日付のままなので線は日付についていく（K-11 の 4）。
- **K-5**（線に項目を足さない、`v` を上げない）: 何も足さない。祝日と週の始まりの設定は UserDefaults だけ。
- **K-6**（伸びる紙の一覧は固定部分）: 変えない。祝日の名前や言語で見出しが折り返して一覧の倍率が変わらないよう、見出しの字は全部 1 行（`lineLimit(1)` ＋ 縮小。§4.1 F-10）。
- **K-7**（互換テストは 1.0 のコードで）: `Compat10`・`CompatFixtures`・`Compat10Tests`・`Tests/Fixtures/compat11/`（b13fa91 で台帳 2・写真モード 6 の fixture が入り、`.gitignore` を含めて 17 ファイル。e7b4d2f でも同じ）・`tools/compat10/`（`DATA_1_1.sha256` を除く）を **1 バイトも変えない**。`Compat10FixtureTests.testFixturesAreWhatTheNewCodeWrites` と `compat-v1.0` のジョブが、作り直しをせずに緑であること（紙の形が 1.1 と同じことの証拠にもなる）。1.0.1 は データの部分が 1.0 と同じ（`InkPage.swift` の sha256 が同じ）なので、`RunReal` の 2 つ目の対象は足さない。
- **K-8**（古い版では新しい欄が見えない）: 1.2 に新しい欄は無い。ただし日曜始まりで書いた週の手書きは古い版の端末では見えない（消えない。K-11 の 7）ので、新機能の文に 1 文書く（§6.3）。祝日・言語・週の始まりの設定は端末ごとなので、新機能の文に「設定は端末ごと」と書く。
- **K-9**（線の予算）: 変えない（15,000 本で案内・19,000 本で受け付けない・読む上限 60,000 本）。案内の文だけ訳す。週の 2 つの形は別のページなので別に数える。隠れている線も月のページの予算に数える（§10.2）。
- **K-11 週の始まりとページ**（新しい規則。第 4 版で足した。`docs/M7_PLAN.md` §1.3 に入れ、以後の全部の版の契約に写す。K-10 は B の仮想ページ（1.3 の契約）に空けてある）:
  1. 週のページの id は `w-` ＋その週の最初の列の日。日付の曜日が形を決める（月曜 = 月曜始まり、日曜 = 日曜始まり）。ほかの曜日は作らない。
  2. 2 つの形は別のページ。**線を写さない・動かさない・まとめない**（K-2。週の `grid` は x が列に結び付いている）。切り替えはページを開き直すだけで、保存するものは 1 バイトも変わらない。
  3. 週の始まりの設定をページ・線・書き出しに入れない（K-5）。`v` と `tegaki-app-export` v1 は上げない。
  4. 月の id はどちらも `m1-YYYY-MM`（"m1" は歴史の名前で、並びの意味は無い）。マスの鍵は日付のままで、線は日付についていく（K-4）。片方の 42 日にしか無い日の線は、もう片方では描かない・消さない（F1）。**そのために線を動かさない。**
  5. Layout の月曜の道は既定の引数で 1.1 のまま。Web の取り込みは常に月曜の表。Web の形式の日曜 `w-` は legacy として断り続ける。アプリの形式の日曜 `w-` は受ける（F2）。
  6. 新しい週のページ（`wb-`、週のメモなど）も同じ日付の規則に従う。帯（B）はページの番号と id の往復に `weekStart` を渡し、1 つの窓に 2 つの形を混ぜない。
  7. 古い端末では日曜のページと、表に無いマスの線は見えない・消えない・壊れない（K-8）。「この端末の手書きを全て消す」（F7）では消える（全部のレコードを消すので）。

### 1.3 日本語の利用者が 1.1.1 と同じものを見ることの証明（J-1〜J-10。基準の移し替えは §1.5）

| # | 何を | どう確かめる | 持ち主 |
| --- | --- | --- | --- |
| J-1 | 画面の日本語の文が 1.1 と 1 文字も同じ | `tools/l10n/baseline.py` が 1.1 の commit のソース（テストと KitChecks を除く）から日本語を含む文字列を全部抜き出し `ja-baseline.tsv`（ファイル・行・文字列）にする（偵察の数え方で、1.1 の commit e7b4d2f は 515 個・42 ファイル。うち 6 個は凍結した Ink の文で、例外に入れる、§2.5）。各キーの `was` がこの行を指し、lint L-3 が「どの行もちょうど 1 つのキーか例外の表（`ja-exceptions.txt`、理由つき）に当たり、単純なキーの ja が元の文字列と同じ」を確かめる。部品をつないでいた文（C 型）を 1 つの文にしたキーは `composedOf` に元の行を並べ、組み上がった日本語が 1.1 の結果と同じことを S・U・P のテストで確かめる。**基準は B11 が `<1.1.1>` で作り直す**（§1.5。増えるのは `pinchHintToast` の 1 行の見込みで、キーは `toast.pinchHint`）。週の始まりと EU で増える文は 1.2 の新しい日本語で、この表の外（§6.3、§10.4） | S（lint）、各持ち主（`was`） |
| J-2 | 日本語を確かめている既存のテストが、期待の字を変えずに通る | アプリのテストは `-testLanguage ja -testRegion JP` で、Kit のテストは既定の `.ja` で。リードが `git diff <1.1.1>..HEAD -- Tests TegakiKit/Tests` の削除行に、日本語と `w-20`・`Monday`・`Sunday`・`mondayOnOrBefore`・`firstGridDay` が無いことを見る（あれば理由を M7B.md に。週の始まりで月曜の期待を変えていないことの確かめ、§10.8）。UI テストの 4 つ（YearTapUITests・EraserAndBelowDayUITests と 1.1.1 の HeaderAndPaperUITests・BlankPaperShotsUITests）は起動の引数の行を足すだけで、日本語のコメントの行（:69-70・:316-317）は書き換えない | リード |
| J-3 | Kit の文字の関数の日本語が 1.1 と同じ | `KitChecks/Text11.swift` に 1.1 の `PageNavigation.title`・`compactTitle`・`YearMonth.title`・`StrokeBudget.pageLabel`・`countText`・`PlanText` の全関数・`AppExport.jsonFileName`・`pdfFileName`・`kindLabel`・`MonthLayoutEngine.timeText(for:…)`・`formatTime`・`TimedEventEngine.timeRangeText` を名前に `11` を付けて写す（先頭に元の commit e7b4d2f と行の範囲。以後は変えない。1.1.1 は字の関数を変えないので、これが 1.1.1 の基準でもある、§1.5）。2000〜2099 年の全日付（36,525 日）× 4 種類のページ、全週、全月、全年、全部の購読の状態で、新しい関数（既定の引数、`language: .ja`、週の関数は `weekStart: .monday` を明示した呼び出しの全部）と 1 文字も違わない | K |
| J-4 | 日本語の写真が 1.1 と同じ | 1.2 の CI の日本語の写真（成果物 `screenshots`）を、**1.1.1 を main に merge した commit `<1.1.1>`（§1.5）を 1.2 と同じ `JA_ARGS`（`-AppleLanguages "(ja)" -AppleLocale ja_JP`）で撮り直した写真**（`ja-baseline.yml` の成果物 `ja-baseline-<commit の先頭 7 字>`。§12.2 の CI-0 と同じときに 1 回と、**比べる直前（1.2 の最後の CI と同じ日）にもう 1 回**走らせ、比べるのは後の方、§7.5）と、リードがこの Mac で `tools/l10n/compare_shots.swift` で 1 画素ずつ比べる（間に CI のイメージの Xcode やシミュレータの runtime が上がると字の描き方が変わって全部の写真に差が出るうえ、成果物は 30 日で消えるため）。2 つの run（撮り直した ja-baseline と 1.2 の最後の CI）の `xcodebuild -version` とシミュレータの runtime（どちらも成果物の `env.txt`）を M7B.md に書き、違えば ja-baseline を撮り直してから比べる。**e7b4d2f の写真とは比べない**（1.1.1 で紙の上寄せと見出しの「今日」が変わり、全部の写真が違う）。**1.1 と 1.1.1 の CI の最後の写真とも比べない**: それらの CI は英語のシミュレータで撮っていたので、漢字・かなの代わりの書体が中国語用（PingFang SC）になり、同期・取り込みのシートの日時も英語の書式だった（この Mac で `CTFontCreateForString` の「祝日」が `-AppleLanguages (en)` で .PingFangUITextSC、`(ja)` で .HiraKakuInterface。レビューの実測）。比べるとほぼ全部の字で違いが出て、本物の後戻りを見分けられない。実機の日本語の端末は 1.1 でもヒラギノなので、撮り直した写真の方が実機に近い。違ってよいのは `ipad13-portrait-sheet-settings.png`（週の始まりと祝日の節が増えて下がずれる）・`ipad13-portrait-sheet-info.png`（ライセンスの行）・`ipad13-portrait-sheet-holidays.png` と `ipad13-portrait-sheet-week-start.png`（1.2 だけにある）・`store/ipad13/06-settings` だけ（ステータスバーはどちらも 9:41 に固定、`build.yml:312, 519`）。**ツールバーの帯も含めて比べる**（1.1 の比べ方は帯を除いていて、ずれ 45 を見落とした。ja は §4.4 の 1.1 の道なので帯も同じはず）。`ipad13-portrait-sheet-sync.png` は同期の節が的なので変わらない見込みで、違ったら、違いが祝日の節の分だけかをリードが見て M7B.md に書く。結果と「1.1 の CI の写真は英語の環境で撮っていたので中国語の書体の漢字だった」ことを M7B.md に | C（`ja-baseline.yml`・`compare_shots.swift`）・リード（比較） |
| J-5 | 日本の祝日が 1.1 と同じ | `HolidayCalendar.japan` と、`HolidayStore.calendar(for: JP, language: .ja)` の両方で、2000〜2099 年の全日付の名前が `JapaneseHolidays.name(of:)` と同じ（1,773 日。他の日は nil） | H |
| J-6 | 紙の形が 1.1 と同じ | §7.1 の G-1〜G-3。K-7 の fixture が作り直さずに一致 | K |
| J-7 | 1.1 からの利用者の祝日が日本のまま。新しい利用者は 2 回目の起動でも自動のまま | `HolidayChoiceTests.testExistingUserKeepsJapan`・`testNewUserStaysAutomaticOnSecondLaunch`（§1.4） | U |
| J-8 | 日本語の端末で日本語が選ばれる | `LanguageUITests.testJapaneseStaysJapanese`（§7.3） | U |
| J-9 | 今お使いの方の週は月曜のまま。新しい方は 2 回目の起動でも自動のまま | `WeekStartChoiceTests.testExistingUserKeepsMonday`・`testNewUserStaysAutomaticOnSecondLaunch`（§10.3） | U |
| J-10 | 地域が日本の新しい方は月曜 | `WeekStartChoiceTests.testJapanIsMondayOnAuto`、`LanguageUITests.testWeekStartFollowsTheRegion` の (ja) ja_JP（§10.8） | U |

### 1.4 1.1 からの利用者の祝日（D10、U）

`HolidayChoice.migrateIfNeeded` を `CalendarRootScreen.init`（:302）の最初（写真モードでは呼ばない）で 1 回:

1. `holidays.setting` の記録があれば、何もしない（**判定は 1 回だけ**）。
2. 記録が無く、`onboardingDone`・`lastPageKind`・`allowFingerDrawingChosen` のどれかの記録があれば（1.0・1.1 から使っている人）`"JP"` を書く。
3. どれも無ければ（新しく入れた人）**`"auto"` を書く**。

第 1 版は 3 で何も書かなかった。新しい人は 1 回目の起動で初回案内を終えると `onboardingDone = true` が書かれる（`CalendarRootScreen.swift:660, 992`）ので、2 回目の起動で 2 に当たり、世界中の新しい利用者が何の表示もなく日本の祝日に固定されていた（O-3 に反する）。初回案内は変えない（祝日を選ぶ画面は足さない）。日本の地域の端末では「自動」も「日本」も同じ結果。テスト（U、`HolidayChoiceTests`）: `testExistingUserKeepsJapan`（3 つのキーのどれか 1 つだけでも "JP"）、`testNewUserIsAutomatic`（空の記録 → "auto"）、**`testNewUserStaysAutomaticOnSecondLaunch`**（新規として migrate → "auto" → `onboardingDone` と `lastPageKind` を書く → もう一度 migrate → "auto" のまま）、`testMigrationRunsOnce`（"none" や "US" の記録は 3 つのキーがあっても変えない）。

**言語（M7B-19。既定の (a) で確定、2026-11-01）**: (a) では言語について何も書かない（1.1 から英語などの端末で使っている人は、1.2 でその言語の表示になる。0-34）。本人が (b) を選んだときだけ、2 で "JP" を書くのと同じ時に、`UILanguage.current != .ja` ならアプリの UserDefaults の `AppleLanguages` に `["ja"]` を書く（iOS の「設定」アプリのアプリごとの言語と同じキー。次の起動から日本語、最初の 1 回は端末の言語のまま。テスト `testExistingUserKeepsJapaneseWhenAsked`）。**(b) は選ばれなかったので入れない**（このテストも足さない）。

**週の始まり**の移行は同じ考え方で §10.3。

### 1.5 1.1.1 の取り込みと基準の移し替え（第 4 版。担当 B11。ここだけは 1.1.1 の中身も書く）

本人の決定（2026-11-04）で **1.1.1 を 1.2 より先に出す**。1.1.1 の契約は `R1_1_1_CONTRACT.md`（作業中は scratchpad の `r111/` にあり、結果は `docs/R1_1_1.md` に入る見込み。ブランチ `fix-1-1-1`、Web は `r111-legal`。その §7 が 1.2 への申し送り）。今 `fix-1-1-1` にあるのは写真を撮るための commit 0（d0fdbff、2026-11-04 23:14）だけで、直しはまだ入っていない。下の「1.1.1 で変わる物」はその契約（第 2 版）と d0fdbff からの見込みで、B11 が本物で確かめる。

**1.1.1 で変わる物**: 紙の上寄せと開く倍率（`ZoomPolicy`・`InkCanvasView.Coordinator`）、回転と高さの変化で紙の上端を保つ（1.1.1 の契約 §2.2）、月のメモ欄と日の自由メモの全開（`PaperGrowth`）、PDF にメモの白紙を含めない、ピンチの案内（`CalendarRootScreen.pinchHintToast`、`AppSettings.pinchHintShownKey`）、「今日」を右へ（`PageHeaderView`）、「今日」を押すと今日の行まで送る（1.1.1 の契約 §2.6。`PageNavigation.todayRect`、`ZoomPolicy.revealOffset`、`InkCanvasView.revealRect`・`revealTrigger`、`goToday` と `show` の `revealRect`）、写真の引数 `--screenshot-empty`（d0fdbff。`ScreenshotMode.Config.empty`、`demoEvents(for:empty:)`、`demoPage(kind:focus:grown:empty:)`。`EventStoreModel.load` は変わらない）・`--screenshot-pinch-hint`（`Config.pinchHint`）、写真の offset の 4 か所、UI テスト `HeaderAndPaperUITests`・`BlankPaperShotsUITests`、ジョブ `blank-paper`、`docs/SUPPORT.md` の 3 か所。**線の id・マスの名前・ページの id・保存形式・同期の形は変えない**（1.1.1 の契約 §0。写しで compat10 361 件・失敗 0）。

**`<1.1.1>` の意味**: この契約で `<1.1.1>` は「1.1.1 を main に merge した commit」。main に入るまでは `fix-1-1-1` の先頭を「仮の `<1.1.1>`」として使い、main に入ったら本物でもう一度行う（手順の 8）。**1.2 の CI の最後と J-4 の写真の比較は、本物の `<1.1.1>` を取り込んでから**（D18）。

**いつ**: **1.1.1 の TestFlight に出した commit（または 1.1.1 の契約の全部の役が済んだ commit）ができたら**、**S2・U・P を始める前に**（`CalendarRootScreen`・`PageHeaderView`・`AppSettings`・`ScreenshotMode` がぶつかるので、早く取り込むほど衝突が少ない）。今の `fix-1-1-1` は commit 0 だけで本人の答えを待っているので、commit 0 だけで B11 を始めない（後で 1.1.1 の分の合流がもう一度要る）。K2 は B11 の前でも後でもよい（`ZoomPolicy`・`PaperGrowth` と週の関数はぶつからない見込み。ただし 1.1.1 の K は `PageNavigation`・`MonthLayoutEngine`・`DayLayoutEngine` の別の場所も変えるので、手順の 2 を見る）。それまでは **K2 と LA2 の EU の分** だけ進めてよい（§12.2）。

**B11 の手順**（読み手はリードか B11 の役。`wt-m7b` の中で。push しない）:

1. **作業の木を commit する**（リード）: 済んだ役の未 commit の成果を、役ごとのまとまりで `git add <ファイル名>` して commit する（S0・K1・S1・C1・LA・H。`git add -A` は使わない）。第 3 版の「commit は最後の C だけ」の例外で、未 commit のままでは merge できないため。
2. **merge**: 先に 1.1.1 の契約の最新の §7（1.2 への申し送り）を読み直す（この節を書いた後に直っていることがある）。`git merge --no-ff --no-edit <1.1.1>`。衝突の見込みと決め方:
   - K2 が B11 より先に済んでいるときの `TegakiKit/Sources/Layout/PageNavigation.swift`・`MonthLayoutEngine.swift`・`DayLayoutEngine.swift`（1.1.1 は末尾の `todayRect`・紙の上寄せの定数など、K2 は引数の `holidays:`・`words:`・`weekStart:`）: 両方残す。意味がぶつかったら 1.1.1 の値を基準にして K2 の引数を載せ直す。
   - `docs/SUPPORT.md`（1.1.1 は FAQ の 2 か所の直しと 1 つ足すのと最終更新、m7b は FAQ を 2 つ足すのと最終更新）: 両方の FAQ を残す。最終更新は m7b の側（1.2 の公開の前に W・LA2 が決める）。
   - `TegakiKit/Sources/KitChecks/main.swift`（1.1.1 は既存の行の期待、m7b は Summary の前に節を足す）: ぶつからない見込み。ぶつかったら両方残す。
   - `project.yml` の版: 1.1.1 の値のまま（1.2 にするのは最後の C）。
   - `.github/workflows/build.yml`: m7b はまだ変えていないので 1.1.1 のまま。C が最後に §7.5 の直しをその上に入れる。
   - 凍結した 18 ファイルと `InkCanvasViewTests.swift`: m7b は変えていないので 1.1.1 のまま。
3. **データの部分の確かめと作り直し（D14）**: `git diff --stat e7b4d2f <1.1.1> -- <18 のパス>` を見る。**変わってよいのは `Ink/InkCanvasView.swift`（開く倍率の直し）と、注記を直していれば `Ink/InkLedger.swift` だけ**。InkModel の 7・`Sync/SyncEngine.swift`・`Sync/InkPageRecord.swift`・`Persistence/InkPageStore.swift` が変わっていたら止めてリードに知らせる（1.1.1 が手書きのデータに触れたことになる）。そのうえで `tools/compat10/DATA_1_1.sha256` を K1 と同じ作り方で作り直す（`<1.1.1>` の git の中身から。パスはリポジトリの直下から、辞書順、注記の行なし、18 行）。
4. **互換の物が変わっていないことの確かめ（K-7）**: `git diff --quiet e7b4d2f <1.1.1> -- TegakiKit/Tests/Fixtures TegakiKit/Tests/Compat10 TegakiKit/Tests/CompatFixtures` が空。`tools/compat10/` は `DATA_1_1.sha256` のほかは変わらない。
5. **Text11 の確かめ（J-3）**: `Text11.swift` は **直さない**。`git diff e7b4d2f <1.1.1> -- TegakiKit/Sources/Layout/PageNavigation.swift TegakiKit/Sources/DayKit/DayKey.swift TegakiKit/Sources/InkModel/StrokeBudget.swift TegakiKit/Sources/InkModel/AppExport.swift TegakiKit/Sources/Access/PlanText.swift TegakiKit/Sources/Layout/MonthLayoutEngine.swift TegakiKit/Sources/Layout/TimedEventEngine.swift` に、写した関数の本体の差が無いことを見る（1.1.1 の契約は「字の関数は変えない」）。差があれば J-3 が落ちるので止めてリードが決める。
6. **日本語の文の基準（J-1）**: `python3 -I tools/l10n/baseline.py . --commit <1.1.1>` で `ja-baseline.tsv` を作り直し、`baseline.py` の既定の commit も `<1.1.1>` に直す（S1 の成果への追加の段。S1 を走らせ直さない）。増えるのは 1 行（`CalendarRootScreen.pinchHintToast`）の見込み。行の動いた `was`・`composedOf` を `kit-K.json`・`kit-H.json` で直す（`lint.py --only L-3,L-4` で K と H のキーに指摘が無いこと。ほかの行の失敗は、まだキーの無い役の分）。`ja-exceptions.txt` は行番号を持たないので変えない。新しいキー `toast.pinchHint` を足すのは U（`app-U.json`。`ja` は `<1.1.1>` の `CalendarRootScreen.pinchHintToast` の文をそのまま（今の値は「2 本の指を広げると拡大、つまむと縮小します」。1.1.1 の見直しで直った文で、つまむのは縮小。文をこの契約に固定しない）、`was` は新しい行）。
7. **写真の基準（J-4）**（C1 の成果への追加の段）: `tools/l10n/ja-baseline-ref.txt` を `<1.1.1>` の 40 字に。`ja-baseline.yml` の写真の手順を `<1.1.1>` の `build.yml` に合わせる（offset の 4 か所、pinch-hint の 2 枚を足す。コメントの e7b4d2f も）。走らせるのは §12.2 の CI-0 と同じとき（§7.5）。**e7b4d2f の写真とは比べない**（紙の上寄せと見出しの「今日」で全部の写真が違う）。
7b. **古い版で確かめる材料**（1 回目だけ。§10.8）: scratchpad の `m7b-v4/probe-week/` から `common.swift` と、`v10/run`・`v11/run` の `Package.swift`・`Sources/Probe/main.swift`（`common.swift` ＋ 版ごとの数行。`../TegakiKit` を読むので、checkout の中に `run/` を置く形）を `tools/weekstart-compat/` に移す（`tools/compat10` は変えない）。古い版の commit は手順の 8 の読み替えを増やさないよう、段の中で `tools/l10n/ja-baseline-ref.txt` を読む。段を足すのは C。
8. **本物の `<1.1.1>` でもう一度**: 1.1.1 が main に入ったら `git merge --no-ff --no-edit main`。木が仮の `<1.1.1>` と同じなら、`ja-baseline-ref.txt`・`baseline.py` の既定・`ja-baseline.tsv` の頭の `# commit:`・M7B.md の commit を直すだけ。審査の直しなどで木が違えば手順の 3〜7 をもう一度（0-39）。
9. **確かめ**: `swift build --package-path TegakiKit`、`swift run --package-path TegakiKit KitChecks`（N は 1.1.1 で動く。1.2 の閾値は C が最後に N − 50 で入れる）、`tools/typecheck/typecheck.sh <外の空のフォルダ>` 警告 0、`shasum -a 256 -c tools/compat10/DATA_1_1.sha256`、`python3 -I tools/l10n/baseline.py . --check`、`python3 -I tools/l10n/build.py . --check`。
10. **M7B.md に書く**: `<1.1.1>` の 40 字、手順の 3〜6 の差の結果、N の前後、衝突の始末。「基準を移した」と分かるように 1 節。

**名前の扱い**（ファイルと関数の名前は変えない。CI と契約と次の版が読むため）:

| 物 | 名前 | 中身の基準 |
| --- | --- | --- |
| `tools/compat10/DATA_1_1.sha256` | **変えない**（「1.1 系の最後の凍結」と読む） | `<1.1.1>`。基準の commit は M7B.md（ファイルに注記の行を置かない） |
| CI の段「Data code frozen since 1.1」 | **「Data code frozen since 1.1.1」に直す**（C。まだ build.yml に入っていないので最初からこの名前で入れる） | 同上 |
| `TegakiKit/Sources/KitChecks/Text11.swift`、`PageNavigation11` など | **変えない** | e7b4d2f のまま。1.1.1 は字の関数を変えないので、これが 1.1.1 の基準でもある |
| `tools/l10n/ja-baseline.tsv`・`baseline.py`・`ja-exceptions.txt` | **変えない** | `<1.1.1>`（`ja-exceptions.txt` は中身も同じ） |
| `tools/l10n/ja-baseline-ref.txt`・`ja-baseline.yml` | **変えない** | `<1.1.1>`。成果物の名前は `ja-baseline-<先頭 7 字>` なので自動で変わる |
| テストの名前 `testJapaneseMatchesTheOneOneBaseline`・`testJapaneseTakesTheOneOnePath` など | **変えない** | 読み替えるだけ |

**読み替えの例外**（「1.1 と同じ」が 1.1.1 にならない所）: K-7 の互換（`Compat10`・`RunReal` は本物の 1.0 のまま）、K-11 の古い端末の確かめ（1.0 と 1.1.1 の両方、§10.8）、`M7A*.md` の記録、第 3 版以前の変更の記録、§9.1 の理由の文。

**1.1.1 の分で 1.2 の役がすること**:

| 役 | すること |
| --- | --- |
| U | `pinchHintToast` の値を `L.text("toast.pinchHint")` に（定数の名前は残す。`CalendarRootScreenTests` が読む）。`app-U.json` にキー。`HeaderAndPaperUITests`・`BlankPaperShotsUITests` の起動の引数に `-AppleLanguages (ja) -AppleLocale ja_JP`（0-25。行を足すだけ）。`ScreenshotMode.Config.holidays`・`weekStart` は 1.1.1 の `empty`・`pinchHint` の後ろに足す。`demoPage` は 1.1.1 の `empty:` の後ろに `weekStart:`。`AppSettings` のキーは 1.1.1 の `hint.pinchShown` と並べる（`hint.pinchShown` は移行の判定に使わない） |
| P | F-16 の読み替え（§4.5 の末尾）。狭い行の並びが変わるので fr の写真を見る |
| LA2 | 1.1.1 の FAQ「拡大・縮小するには？」の英訳と、英訳の「Tap the date in the header」の直し（日本語の直しと同じ、1.0 からの間違い）。`docs/store/review-note.txt` は診断の記録の文を既に持っている（§6.6）ので足さず、「EU excluded」の文が無いことを見る |
| X・R | `toast.pinchHint` の 9 言語の訳と逆翻訳。「2 本の指で」は「ピンチ」という名詞で訳さない（§6.2）。**広げる = 拡大、つまむ = 縮小の向きを逆翻訳で確かめる**（1.1.1 の契約 §7） |
| W | `m7b-legal` を `r111-legal` を含む所から切る（§6.5） |
| C | `build.yml` は 1.1.1 の上に §7.5 を入れる。`blank-paper` のジョブは変えない。`header-paper UI:` の grep は残す。`ja-baseline.yml` を比べる直前にもう一度走らせる。`README`・`DESIGN` は 1.1.1 の図の上に足す |

**残る約束**: 1.1.1 の TestFlight・審査が先。1.2 の TestFlight と main への merge の順は 0-40。

## 2. 言語の選び方と文字列の仕組み（担当 C・S・K・X）

### 2.1 言語の選ばれ方（偵察の実測。iOS での確かめは §7.3）

| 端末の言語 | ja-JP | th-TH | th, en | ru, ja | zh-Hant-HK | pt-PT | es-MX | fr-CA | ar-SA |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 受け皿 ja のまま 10 言語を足した場合 | ja | **ja**（O-1 に反する） | en | ja | zh-Hant | pt-BR | es | fr | ja（th と同じ理由の推定） |
| **受け皿 en ＋ 10 言語（1.2）** | **ja** | **en** | en | ja | zh-Hant | pt-BR | es | fr | **en** |
| 受け皿 en、`ja.lproj` なし | **en**（日本の人に英語） | en | en | en | en | en | en | fr | en |

- 1.1 は文字をコードに直書きしているので、どの端末でも日本語が出る（`.lproj` は 1 つも無い）。
- 書式の言語は `Locale.current` に頼らず、`L.language`（= 画面が選んだ `.lproj`）と端末の地域から作る（受け皿が ja のとき、画面は ja なのに `Locale.current` が en_JP になる食い違いを実測した）。
- iOS は 2 つ以上の言語を持つアプリに「設定」アプリの言語の項目を自動で付ける。アプリの中に言語の設定は作らない（§9.1）。**ただし iOS は、端末の「優先する言語」が 1 つだけ（日本語だけ）のとき、この項目を出さないことがある**（本人の iPad・iPhone はおそらくこれ。iOS で要確認）。リードが TestFlight で項目が出る条件を確かめて M7B.md に書く。項目が無いときの手順「『設定』›『一般』›『言語と地域』›『言語を追加』で使いたい言語（例 English）を 2 番目に足す（端末の表示は 1 番目の日本語のまま。後で消せる）」を、新機能の文（§6.3）・SUPPORT の FAQ（§6.4）・§8 の 9 の手順 5 に書く。本人の端末は iPad mini（A17 Pro・iPadOS 27.2・Apple Pencil Pro）・iPad Air 11・iPad Pro 13・iPhone 18 Pro Max（M7A.md:494。OS の版が記録にあるのは iPad mini だけ）。「設定」›「アプリ」›「てがきカレンダー」›「言語」の道と項目の出る条件は、リードがこの端末の TestFlight（1.2）で確かめてから、新機能の文・SUPPORT の FAQ・§8 の 9 の手順 5 を固める。**言語を足すと、iOS はどちらの言語を優先するか（端末の表示をどちらにするか）を聞いてくることがある**。本人は日本語しか読めず、押し違えると戻す道（Settings › General › Language & Region）も英語の画面でたどることになるので、そのボタンの名前も、リードが TestFlight を渡す前に Apple のサポート記事の日本語版（公開のページを読むだけ、§6.1 の 4）で確かめて §8 の 9 の手順 5 に書く（本人には日本語のままの方を押してもらう。記事に無ければ「『日本語』と書いてある方」と書く）。

### 2.2 project.yml（C）

- `options:` に `developmentLanguage: en`。`info.properties` の `CFBundleDevelopmentRegion: en`（:62）、`CFBundleLocalizations: [ja, en, zh-Hans, zh-Hant, ko, fr, de, es, it, pt-BR]` を足す。
- `CFBundleDisplayName`（:59）と `NSCalendarsFullAccessUsageDescription`（:65）の値は日本語のまま残す（Info.plist の元の値。どの `.lproj` にも当たらない場合だけ使われ、実際には `en.lproj/InfoPlist.strings` が先に当たる）。訳は `InfoPlist.xcstrings`（S）。DESIGN §4.1・PRIVACY 付録 B と 3 か所で文をそろえる約束は日本語の文について今のまま。
- `settings.base` の `SWIFT_EMIT_LOC_STRINGS: YES`（:26）を **NO** に（0-5）。
- 祝日のデータ: アプリのターゲットの `sources` に `- path: TegakiKit/HolidayData` を `type: folder`・`buildPhase: resources` で足す（bundle の中で `HolidayData/` になる）。**退き先**: `TegakiKit/HolidayData` はローカルパッケージ（`packages: TegakiKit`）のフォルダの中にあり、`createIntermediateGroups: true`（:9）で「TegakiKit」のグループとパッケージの参照が並ぶ。Xcode がこれをどう扱うかはこの Mac では確かめられないので、CI の「Localized bundle check」で `HolidayData/` が入っていない、またはプロジェクトの生成か組み立てがこの参照で落ちたら、データをリポジトリ直下の `Resources/HolidayData/` に移す（gen.py の出力先、KitChecks とテストの `HolidayDataLocation` の場所を `../../../Resources/HolidayData` に、project.yml の path を `Resources/HolidayData` に）。決めたことを M7B.md に（C とリード）。
- **`TegakiCalendarTests` の dependencies（:121-128）に `- package: TegakiKit` / `product: Holidays` を足す**（今は Layout・InkModel・Access だけ。`HolidayChoiceTests` が `HolidaySetting`・`HolidayRegion`・`HolidayStore` を使う。Xcode 26 の明示的なモジュールの組み立てで、宣言していない import が通ることに頼らない。typecheck.sh は全部のモジュールを `-I` で見せるので、この Mac では見逃す）。
- `Resources/*.xcstrings` は `Sources/TegakiCalendar` の中なので今の `sources` で拾われる。テストのターゲットにはカタログを入れない（ホストのアプリの bundle を読む）。
- XcodeGen の版: CI は `brew install xcodegen` で毎回最新を入れる（`build.yml:105-109`）。xcstrings の組み込み（`knownRegions` の推定）は版で変わりうるので、`xcodegen --version` と生成されたプロジェクトの `knownRegions` を毎回ログに出し、M7B.md に記録する。版は固定しない（brew では古い版を選べない）。守りは「Localized bundle check」が 10 の `.lproj` を毎回確かめること（§7.5）。
- **1.1 の後半の行は残す**: `UIApplicationSupportsIndirectInputEvents: true`（:73。`InkTouchObserver` がマウス・トラックパッドの触れ方を書く触れ方として数える前提、M7A.md ずれ 46 の ⑥）と、`sources` の PrivacyInfo の注記（:42-44）。`CURRENT_PROJECT_VERSION: "1"`（:21）は変えない（`testflight.yml:185` が run の番号を入れる。1.1 は 14 なので 1.2 は 15 以降）。
- **PrivacyInfo**（`Sources/TegakiCalendar/PrivacyInfo.xcprivacy` :21-28。C）: 1.2 で変えない。UserDefaults（CA92.1）は祝日の設定 `holidays.setting` もその中。System boot time（35F9.1）は、凍結した `Ink/InkCanvasView.swift:493` の `systemUptime` のために 1.2 でも要る（472252c、ずれ 48）。1.2 の新しいコード（祝日の読み込み・`HolidayStore`・ログの時間）は、理由の申告が要る API（File timestamp・Disk space・Active keyboards・System boot time）を新しく使わない: 時間は `Date` の差で測り、ファイルの日時や空き容量を読まない。使うことになったら、C が PrivacyInfo に理由を足してから。「Localized bundle check」（§7.5）で、組み上がった .app の PrivacyInfo に CA92.1 と 35F9.1 があることも確かめる。App Privacy の「データの収集なし」は変わらない（§6.6）。

### 2.3 文字列の元・訳・生成（S が生成器、各持ち主が元、X が訳）

**元のファイル** `tools/l10n/source/<持ち主>.json`（S は `app-S.json`、U は `app-U.json`、P は `app-P.json`、K は `kit-K.json`。同じキーが 2 つのファイルにあれば生成器が止まる）:

```json
{ "owner": "U", "keys": {
  "settings.input.eraserAutoReturn.title": {
    "ja": "消しゴムで消したらペンに戻る", "target": "app",
    "comment": "設定 › 入力 のスイッチの名前。iPad と iPhone の両方",
    "where": ["Views/SettingsScreen.swift"], "was": ["Views/SettingsScreen.swift:81"],
    "maxEm": 24, "args": [], "glossary": ["消しゴム", "ペン"] } } }
```

S の例（改行の入った値。§4.4）:

```json
{ "owner": "S", "keys": {
  "toolbar.hint.eraser.toPen": {
    "ja": "触れた線をまるごと消します\n（消すとペンに戻ります）", "target": "app",
    "comment": "ツールバーの消しゴムの説明。消したらペンに戻るとき。2 行で、1 行目は toolbar.hint.eraser と同じ文",
    "where": ["Views/ToolbarLogic.swift"], "was": ["Views/ToolbarLogic.swift:176"],
    "lines": 2, "maxEm": 12.0, "args": [], "glossary": ["消しゴム", "ペン"] } } }
```

- `target`: `app`（Localizable）・`infoplist`（キーは Info.plist のキー名そのもの: `CFBundleDisplayName`・`NSCalendarsFullAccessUsageDescription`）・`kit`（KitStrings）。
- `args`: 埋め込みの意味を順に（`["日数"]`）。`maxEm`: 枠の上限があるときだけ（§4 の数字）。`fixed: true` は訳さない値（§3.3 の曜日の記号の表のように、契約が全言語の値を決めたもの。値は `fixedValues` に 10 言語分）。
- `jaOnly: true`: ja の道だけで使う Kit のキー（D6 の手作りの書式の型。`kit.date.ja.dayTitle`「%1$@年%2$@月%3$@日(%4$@)」・`kit.date.ja.shortDay`・`kit.date.ja.monthTitle`・`kit.date.ja.yearTitle`・`kit.date.ja.weekTitle`・`kit.date.ja.weekTitleCrossYear`・`kit.date.ja.weekTitleCompact` など、K が決める）。生成器は ja の表だけに書き、L-2 は他の言語を求めない。X は訳さない。
- `allowJapanese: ["…"]`: ja 以外の値に、この字に限ってかなと漢字を許す（L-2）。契約が許すのは 2 つだけ: 「手書きを書き出す（iPad アプリ用）」（Web 版の機能名。Web 版は日本語だけなので、訳の中でも括弧で添える、§6.2）と「てがきカレンダー」。
- 複数形は `<キー>.one` と `<キー>.other` を両方置く（ja・ko・zh は同じ文）。
- `lines`: 画面で出せる行の数の上限（ツールバーの説明 5 つは 2。§4.4 の F-14）。値の改行の数は全言語で `lines − 1` 以下（L-4）。`maxEm` は改行で区切った各行に当てる。
- **値の改行の書き方**: 元と訳の JSON・`Localizable.xcstrings`（JSON）・`--format strings` の `.strings` では、escape の `\n` 1 つで改行 1 つ（生の改行は書かない）。`ja-baseline.tsv` には Swift のソースの書き方のまま書く（`\n` の 2 字。TSV の 1 行に収めるため）。L-3 と `LocalizationBundleTests.testJapaneseMatchesTheOneOneBaseline` は、両方の escape（Swift の `\n`・`\t`・`\"`・`\\`・`\u{…}` と JSON の escape）をほどいてから比べる。埋め込み `\(…)` のある行は C 型として `composedOf` で比べる。改行の入った 1.1 の値は、1.1 の後半（a07c525）のツールバーの説明 4 つ（`ToolbarLogic.swift:120, 121, 176, 178`）のほか、1.0 からの `SyncStatus.swift:128`・`OnboardingView.swift:22, 24, 26, 30` と、`SettingsScreen.googleHowTo`（:76。b13fa91 から）。

**訳のファイル** `tools/l10n/translations/<言語>.json`（X。9 言語。en を含む）: `{ "language": "de", "strings": { "<キー>": { "text": "…", "jaSha1": "<訳したときの ja の sha1 の先頭 10 字>" } } }`。ja が後で変わると `jaSha1` がずれ、lint L-6 が「要確認」で止める。

**生成器** `python3 -I tools/l10n/build.py <リポジトリ>`（S）: 元と訳から次を書く（いつも同じ結果。キーは辞書順、JSON は 2 字下げ、末尾に改行）。`--check` は書かずに一致だけを見る（lint L-10）。
- `Sources/TegakiCalendar/Resources/Localizable.xcstrings`: `"sourceLanguage": "en"`、各キーに 10 言語の `stringUnit`（`"state": "translated"`）、`"extractionState": "manual"`、`comment`。
- `Sources/TegakiCalendar/Resources/InfoPlist.xcstrings`: 同じ形で 2 キー。
- `TegakiKit/Sources/DayKit/KitStrings.generated.swift`: `kit` のキーだけを、言語ごとの `[String: String]` の表（`switch language`）として。先頭に「生成物。直さない。tools/l10n/build.py」。
- `--format strings`（0-4 の退き先）: `Resources/<lproj>.lproj/Localizable.strings`・`InfoPlist.strings` を書き、カタログを消す。切り替えはリードが決める。

### 2.4 キーの付け方と書き方の規則

- 形は `^[a-z][a-zA-Z0-9]*(\.[a-z0-9][a-zA-Z0-9]*)+$`、`<画面か部品>.<場所>.<意味>`（例 `paywall.cta.trial.one`、`toast.capReached`、`sync.status.offline`、`paper.freeMemo`、`kit.plan.monthly`、`demo.event.campTrip`）。Kit のキーは `kit.` で始める。
- **日本語の値は 1.1 の文そのもの**（J-1）。直したくても 1.2 では直さない（直すなら別の版で、他の 9 言語を「要確認」にしてから）。
- 部品をつないで文を作っていた所（偵察の C 型。`PaywallSheet.swift:46, 111, 117, 123-124, 133`、`SettingsScreen.swift:124, 646-663, 672`、`PageHeaderView.swift:240-254`、`StickyHeaderView.swift:138, 177, 223`、`ToolbarLogic.swift:135, 203, 206, 209`（:135 は丸ボタンの読み上げのヒント、:203・:206・:209 は丸ボタンの読み上げの値「マーカー・<色>」「ペン・<色>・<太さ>」。1.1 の後半で動いた）、`ToolbarView.swift:265`（読み上げの名前「太さ: \(entry.name)」。b13fa91 の :231 からあり、第 2 版の表から漏れていた。ja の型は「太さ: %@」）、`StrokeCensus.swift:53`、`AllDayBandView.swift:189, 194`、`OnboardingView.swift:22`、`WebImportSheet.swift:108-109`、`PlanText.swift:49-51, 81`）は、**文全体を 1 つのキー**にして埋め込みを `%1$@`…にする。日本語の値は、つないだ結果が 1.1 と同じになる型（例 `"%1$@・%2$@"`）。ツールバーの説明 5 つ（`ToolbarLogic.swift:117, 120, 121, 176, 178`）は丸ごとの文なので C 型ではなく単純なキー（b13fa91 の消しゴムの説明は `eraserHintText` ＋「（消すとペンに戻ります）」のつなぎ（:159-169）で C 型だったが、表から漏れていた。a07c525 で丸ごとの文になった。§4.4）。
- 同じ日本語でも意味が違えば別のキー（「日」はページの種類・曜日・日付の単位で別）。
- 画面のパス（「設定」›「Apple Account」›「サブスクリプション」など）は、各言語の iOS の実際の表記に合わせる（§6.1 の 4）。

### 2.5 アプリの書き方（S・U・P）

- 画面の文は全部 `L.text("キー")`・`L.format("キー", 文字列…)`・`L.plural("キー", count: n, 文字列…)` を通す。SwiftUI は `Text(L.text("…"))`（`Text("…")` に日本語や英語の文字列を直に書かない）。キーは文字列の直書き（変数を渡すのは、`// l10n-dynamic: <接頭辞>` の注記を付け、その接頭辞の全キーが元にある場合だけ。例 色の名前 `toolbar.color.<名前>`）。
- 数の埋め込み: `L.plural("export.progress", count: total, DateText.number(done, L.language), DateText.number(total, L.language))` のように、先に書式した文字列を渡す（D5）。
- Kit の文字の関数は `language: L.language`、祝日は `holidays:`（画面の body の題名は `CalendarRootScreen` の計算プロパティ `holidays`、紙の組み立ては `makePaper` に渡す 1 つの暦（`init` では設定から作った暦、`relayout` では `HolidayChoice.current`）、書き出し・PDF は `HolidayChoice.current`。§5.6）、Layout の入力は `words: LayoutWords.of(L.language)` を必ず渡す（lint L-7）。週の始まりは `weekStart:` を必ず渡す（lint L-13、§10.5）。
- 日本語のまま残すもの（例外の表 `ja-exceptions.txt`、`パス|文字列|理由` を 1 行ずつ。`*`（そのファイルの全部）は `JapaneseHolidays.swift` だけに使う）: アプリ側は `EventKitService.swift` の判定の語（§5.8）、ログ（NSLog）の文、`ScreenshotMode` の中の識別子と、**凍結した Ink の 6 件**（D14 でファイルを変えられない。この例外は 1.2 の間だけ、0-37）: `Ink/InkTrace.swift` の「記録」（:61）・「閉じる」（:65）・「コピー」と「コピーしました」（:68）— TestFlight と審査の sandbox のレシートのビルドでだけ、設定 › 情報 の「バージョン」の長押しで開く記録のシート（App Store のビルドと写真モードでは出ない、:37-42）。同じファイルの :33 の先頭の行「てがきカレンダー \(SettingsScreen.versionText) / \(device.systemName) \(device.systemVersion) / \(device.model)」— 〔コピー〕で開発者に送る記録の 1 行目（ログと同じ扱い）。`Ink/InkCanvasView.swift` の「手書きの紙」（:663）— UI テストの `--screenshot-probe` のときだけ、紙の入れ物に付く読み上げの名前（識別子 `ink-canvas`。写真と普段の画面には無い）。英語などの TestFlight と審査の端末で、記録のシートが日本語で出ることを M7B.md に書く。Kit 側は §2.6 の列挙（`JapaneseHolidays.swift` の全部、`Plan.swift:33` の `groupReferenceName`、1.1 の公開 API の 7 つ）。写真モードの見本の予定と予定表の名前は U のキー（`demo.*`）に移す。
- ユーザー通知は無い（無音のプッシュだけ）。書き出しのファイル名は訳してよい（取り込みは中身で判定する、`InkImport`）。

### 2.6 TegakiKit の文字列（K）

- `Package.swift`: `Access` に `dependencies: ["DayKit"]`、`InkModel` に `"Holidays"`（今の `["Layout"]` に足して `["Layout", "Holidays"]`）。テストのターゲットも、名前で使うモジュールを宣言する（§2.2 のアプリのテストと同じく、宣言していない import に頼らない）: `AccessTests` に `"DayKit"`（`LegalLinksTests.testURLsPerLanguage` などが `UILanguage` を名前で使う。Access は DayKit を再公開しない）、`InkModelTests` に `"Holidays"`（`AppExportTests` が `HolidayCalendar` を名前で使うとき。InkModel が再公開するのは Layout と、その先の DayKit だけ）。:8-9 の注記「Foundation only, depends on nothing else, not even DayKit」は「Foundation and DayKit only (UILanguage, KitStrings)」の意味に直す。変えるのはこれだけ（第 4 版で K2 がテストのターゲット Compat12Tests を足す、§10.8）。
- 文字は `KitStrings.text/format/plural(…, language)` だけで引く。`KitStrings` の日本語の値は 1.1 の文そのもの（J-3）。
- 変える関数（§0 の接点）は全部、最後の引数に `language: UILanguage = .ja`（祝日の要るものは `holidays: HolidayCalendar = .japan` も）。`.ja` のときは **1.1 と同じ組み立て方**（日付は D6 の手作りの書式。ICU を通さない）を通るが、**日本語の字は直書きせず `KitStrings.text("kit.…", .ja)` から取る**（`DateText` の ja は `jaOnly` のキー `kit.date.ja.*` の型に数と曜日の記号を入れる、`LayoutWords.japanese` は `LayoutWords.of(.ja)` と同じ値、`StrokeBudget.countText` の ja は 3 桁ごとの半角「,」を自分で入れた数を `kit.budget.count.other`「%@ 本」に、`AppExport.kindLabel` は `kit.export.kind.*`）。1 文字も 1.1 と違わないことは J-3 が全範囲で確かめる。こうしないと、Kit の新しいコードの日本語が L-1 で全部失敗する。
- **Kit に直書きのまま残す日本語**（1.1 の公開 API を ja の値として残すもの。`ja-exceptions.txt` に理由「1.1 の公開 API を ja の値として残す」で、ファイル｜文字列の単位で 1 行ずつ。これ以外の Kit の日本語は L-1 で失敗）:

| ファイル | 文字列 | API |
| --- | --- | --- |
| `Access/PlanText.swift` | `4 か月分お得` | `static let yearlyBadge`（:88） |
| `Access/PlanText.swift` | `閲覧専用` | `static let readOnlyBadge`（:89） |
| `Access/PlanText.swift` | `「設定」›「Apple Account」›「サブスクリプション」` | `static let cancelPath`（:91） |
| `Access/PlanText.swift` | `「設定」›「Apple Account」›「お支払いと配送先」` | `static let paymentPath`（:92） |
| `Access/LegalLinks.swift` | `使用許諾契約（Apple 標準 EULA）` | `static let appleEULATitle`（:12） |
| `Layout/PageNavigation.swift` | `日`・`月`・`火`・`水`・`木`・`金`・`土`（7 行） | `static let weekdayLetters`（:9） |
| `DayKit/DayKey.swift` | `\(year)年\(month)月` | `YearMonth.title`（:154。DayKey.swift は変えない） |

  ほかに `Holidays/JapaneseHolidays.swift|*`（祝日のデータ）と `Access/Plan.swift` の `groupReferenceName` の字（:33。Connect の参照名で画面に出ない）。生成物 `DayKit/KitStrings.generated.swift` は L-1 の対象の外（L-2・L-10 が見る）。KitChecks（`Text11.swift` を含む）・テストも L-1 の外のまま。
- `StrokeBudget.countText(_:language:)`: ja は 1.1 のまま（3 桁ごとに半角「,」＋「 本」）、他は `DateText.number` ＋ `kit.budget.count.one/.other`（en「1 stroke」「12,345 strokes」、de「12.345 Striche」）。
- `PlanText.cancelPath(language:)`・`paymentPath(language:)`: 値は X が §6.1 の 4 の方法で決める。画面では〔サブスクリプションを管理〕ボタン（`showManageSubscriptions`）を主にする今の作りは変えない。
- `AppExport.pdfFileName(kind:focus:holidays:language:weekStart:)`（`weekStart` は §10.1）: 「<アプリ名> <title> <kindLabel>.pdf」。アプリ名は `kit.app.name`（ja「てがきカレンダー」、他は M7B-1 の英語などの名前。既定 "Tegaki"）。

### 2.7 lint（S、`tools/l10n/lint.py`。macOS の段階で走り、失敗したらジョブを落とす。この Mac でも `python3 -I tools/l10n/lint.py .`）

| # | 確かめること |
| --- | --- |
| L-1 | `Sources/TegakiCalendar` と TegakiKit の 5 モジュール（KitChecks・Compat10・CompatFixtures・テスト・**生成物 `DayKit/KitStrings.generated.swift`** は除く。生成物は L-2・L-10 が見る）の文字列（`"…"`・`"""…"""`・`#"…"#`。コメントを除いてから）に、かな・漢字・ハングル・全角の記号（U+3000-303F、U+FF00-FFEF）があれば失敗。例外は `ja-exceptions.txt`（`パス\|文字列\|理由`。`*` は `JapaneseHolidays.swift` だけ。§2.5・§2.6 の列挙のほかは足さない。足すなら契約を直す）。偵察の下書き（`/private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/b10c2ae9-5535-4dd5-97f2-2e5ca034309a/scratchpad/m7b/lint/l10n_lint.py`）を土台にする。e7b4d2f（1.1 の merge の commit、今の main）で走らせると 515 件・42 ファイル（21ceba5・b13fa91 は 509 件・40 ファイル。増えた 2 ファイルは凍結した `Ink/InkTrace.swift` の 5 件と `Ink/InkCanvasView.swift` の 1 件で、§2.5 の例外。ほかは 6 件が消えて 6 件が増えた置き換え: 設定の入力の脚注 2、ツールバーの説明 4） |
| L-2 | 全キー（`jaOnly` は ja だけ）に 10 言語の値があり、空でない。ja 以外の値に、かな（と、zh・ko 以外では漢字・ハングル）が無い。例外はキーの `allowJapanese` に書いた字だけで、契約が許すのは「手書きを書き出す（iPad アプリ用）」と「てがきカレンダー」の 2 つ（§2.3。値からその字を除いてから調べる）。`fixed` のキーは `fixedValues` と同じ |
| L-3 | J-1（`ja-baseline.tsv` の全行がキーか例外に当たる） |
| L-4 | 埋め込みの数と番号が全言語で同じ。`.one` と `.other` が対で、ja・ko・zh・zh-Hant は同じ文。`lines` のあるキーは、全言語で値の改行の数が `lines − 1` 以下（超えると画面で行が切れるので、警告でなく失敗。§2.3） |
| L-5 | `%@`・`%1$@`〜`%9$@` 以外の書式指定（`%d`・`%lld`・`%ld`・`%f`・`%s`）が無い（D5）。見るのは元と訳の値だけ（Swift のソースの `String(format:)`、例えば `Ink/InkCanvasView.swift:708, 712, 732, 1708` の探りの値や `CalendarRootScreen.swift:437` のログの数は対象外） |
| L-6 | 訳の `jaSha1` が今の ja と同じ（違えば「要確認」で失敗） |
| L-7 | **アプリのソース**で、`PageNavigation.title(`・`compactTitle(`・`PlanText.`・`StrokeBudget.pageLabel(`・`.map(StrokeBudget.pageLabel`（言語を渡せない形なので、あれば失敗。U が `CalendarRootScreen.runImport` の `large.map(StrokeBudget.pageLabel)` を `{ StrokeBudget.pageLabel($0, language: L.language) }` に直す）・`countText(`・`AppExport.pdfFileName(`・`jsonFileName(`・`kindLabel(`・`LegalLinks.terms(`・`privacy(`・`support(`・`appleEULATitle(`・`YearMonth` の `.title(`・`DateText.` の呼び出し（`time(hour:minute:)` と `mondayFirst` を除く）・`EventDateText.` に `language:` か言語の引数があり、**`PageNavigation.title(` と `AppExport.pdfFileName(` には `holidays:` もあり**、`MonthLayoutInput(`・`WeekLayoutInput(`・`DayLayoutInput(`・`YearLayoutInput(` に `holidays:` と `words:` があり、`AllDayBandLayout.empty(`・`AllDayBandEngine.` に `holidays:` がある（呼び出しが複数行でも括弧が閉じるまで読む）。**Kit のソース**（`TegakiKit/Sources/Layout`・`InkModel`。定義の行・KitChecks・テストを除く）でも、`AllDayBandEngine.week(`・`AllDayBandEngine.day(`・`AllDayBandLayout.empty(`・`PageNavigation.title(` に `holidays:`、`PageNavigation.title(`・`compactTitle(` に `language:` がある（既定値に頼って渡し忘れると日本の祝日が黙って出る。意味の確かめは G-4）。`JapaneseHolidays`・`PageNavigation.weekdayLetters` はアプリのソースに出ない。引数なしの 1.1 の値は `\.(yearlyBadge\|readOnlyBadge\|cancelPath\|paymentPath)\b(?!\s*\()` と `LegalLinks\.(terms\|privacy\|support\|appleEULATitle)\b(?!\s*\()` で照らす（引数つきの `yearlyBadge(language:` などに当たらない。表の中なので選択の縦棒を `\|` と書いた。正規表現ではただの縦棒）。`Locale(identifier: "ja_JP")` は出ない |
| L-8 | コードで使うキーが元にあり、元のキーがどこかで使われている（`l10n-dynamic` の接頭辞の分を含む） |
| L-9 | `docs/store/<ロケール>/` の字数（name 2〜30・subtitle 30・keywords 100 バイト・promo 170・description 4000・whatsnew 4000、subscriptions の表示名 2〜30・説明 45、review-note 4000）と禁止語（name・subtitle・keywords に、大文字小文字を区別せず Apple Pencil・Pencil・iPad・iPhone・iCloud・Apple と各言語の書き方「アップル」「ペンシル」「苹果」「蘋果」「애플」「아이패드」「아이폰」「펜슬」「아이클라우드」、通貨の記号と価格、「無料」「free」「gratuit」「kostenlos」「gratis」「grátis」「免费」「免費」「무료」。1.0 は 5.2.5 で差し戻された）。keywords の各語（「,」で区切る）は、ラテン文字の語なら 3 字以上、漢字・かな・ハングルの語なら 2 字以上（「日历」「手帳」「달력」は通す。1 字の語は拒む）、アプリ名の語を含まない。**URL**: 各ロケールの `description.txt` の利用規約の URL と `urls.txt` のサポート・プライバシーポリシーの URL が、`LegalLinks.englishPagesPublished` と同じ側を指す（false（1.2）なら今の日本語の `app/terms.html`・`support.html`・`privacy.html`、true なら `app/en/…`。0-38）。**価格**（第 4 版の見直し）: ja 以外の `description`・`promo`・`whatsnew`・`subscriptions` に通貨の記号とコード（¥ € $ £ JPY EUR USD GBP など）が無い（§6.6。Guidelines 2.3.1(a) の誤った価格の禁止にも関わる。EU でロケールが増えて X が新しく書く文の歯止め）。「か月分」にあたる文は lint で見つけにくいので R の確認項目（§6.1 の 3） |
| L-10 | `build.py --check`（生成物が元と訳に一致） |
| L-11 | `Resources/` に右から左の言語の `.lproj`（ar・he・fa・ur）やカタログの値が無い |
| L-12 | 各キーの `maxEm` があるとき、ラテン文字の値の **改行で区切った各行の** 字数 × 0.6 em（目安の平均の字幅）が上限を超えたら警告だけ（本当の幅は P の `PaperFitTests` と S の `ToolbarFitTests` が測る）。ツールバーの `maxEm`: 道具 5・「しまう」・細中太 3 の名前 3.8（F-12）、「指でも書く」10.5（F-13）、説明は消しゴムの 3 つ 12.0・投げなわと予定 12.9（F-14）。投げなわのメニューの 3 つ 7（目安。本当の上限は 3 つの合計、F-15）、見出しの切り替えの 4 つ 3.4・「今日」2.8（F-16） |
| L-13 | **アプリのソース**（凍結のファイルとテストを除く）の `PageNavigation.title(`・`compactTitle(`・`dayRange(`・`pageId(.week`・`pageId(kind`・`pageId(newKind`・`pageId(startKind`・`MonthLayoutInput(`・`WeekLayoutInput(`・`AllDayBandEngine.week`・`MonthLayout.grid(`・`AppExport.pdfFileName(`・`PaperWords.monthHeaderWeekdays(` に `weekStart:` がある（L-7 と同じ読み方。D15。Kit の既定の `.monday` に頼って渡し忘れると、日曜の設定でも月曜のページが開く） |
| L-14 | `firstDayOfWeek`・`firstWeekday` を読むアプリのソースは `Persistence/WeekStartChoice.swift` だけ |

## 3. 書式: 日付・曜日・月・数・時刻（担当 K、使うのは S・P・U）

### 3.1 規則

1. 暦はグレゴリオ暦に固定（`DateText.calendar`: `Calendar(identifier: .gregorian)`、`locale = language.locale(region:)`、`timeZone`）。和暦・仏暦の端末でも西暦（0-11）。
2. **ja は 1.1 の手作りの式**（D6。字は `kit.date.ja.*` の型から、§2.6）。`dayTitle`「2026年10月4日(日)」、`shortDay`「10月7日(水)」、`monthTitle`「2026年10月」（compact も同じ）、`yearTitle`「2026年」、`weekTitle`「2026年9月28日〜10月4日」（年をまたぐ週は両側に年）・compact「9/28〜10/4」、`spokenDay` = `dayTitle`、`number`「12,345」。
2a. **`numericDate`・`numericDateTime` だけは、ja も 1.1 と同じ ICU の道**（0-33）: `Date.FormatStyle(date: .numeric, time: .omitted)`（`numericDate`）・`(date: .numeric, time: .shortened)`（`numericDateTime`）、`locale` は **`Locale.current` の言語が ja ならそれ**（1.1 と同じ。端末の「24 時間表示」の設定も同じに効く）、違えば `ja_<region>`、`calendar` は `Calendar(identifier: .gregorian)`（0-11 の直し。グレゴリオ暦の端末では 1.1 と同じ字）、`timeZone`。1.1 の `SettingsScreen.timeText`（:112-115）と `dateText`（:629-633）が ICU に任せていたので、0 で埋めるかどうかを手作りで決め打ちすると 1.1 と同じを証明できない（この Mac の ICU の ja_JP は「2026/1/5 9:07」で 0 で埋めず、en_JP は「2026/01/05」、:112 のコメントは「2026/10/07」。レビューの実測）。ja 以外は同じ `.numeric` ＋ `.omitted` / `.shortened` の雛形を `language.locale(region:)` とグレゴリオ暦で。KitChecks と DateTextTests は 0 で埋めるかに依らない日（2026-10-25 12:00）だけを字で確かめ、他の日は「年・月・日の数が入っている」「`numericDate` に `:` が無い」で確かめる。
3. ja 以外は DateFormatter の `setLocalizedDateFormatFromTemplate`: `dayTitle` = `yMMMMEd`（en_US「Sun, October 4, 2026」）、`shortDay` = `MMMEd`（「Wed, Oct 7」）、`monthTitle` = `yMMMM`（「October 2026」、es「septiembre de 2026」）・compact `yMMM`、`yearTitle` = `String(year)`（区切りなし。th でも「2026」）、`weekTitle` = `DateIntervalFormatter` の `yMMMd`（「Sep 28 – Oct 4, 2026」）・compact `Md`（「9/28 – 10/4」、fr「28/09 – 04/10」）、`spokenDay` = `yMMMMEEEEd`、`numericDate`・`numericDateTime` = 2a、`number` = `NumberFormatter`（`.decimal`、de「12.345」、fr「12 345」）。zh-Hans の月の名前は `.wide` が「十月」になるので、`monthName(_, .full, .zhHans)` は `LLL`（「10月」）を使う。
4. 時刻は全言語で `time(hour:minute:)` = 「H:mm」（D7。今の `MonthLayoutEngine.formatTime` と同じ字）。範囲は `LayoutWords.timeRange`（ja「%1$@〜%2$@」、ko「%1$@~%2$@」、他「%1$@–%2$@」）、日をまたぐ予定の終わりは `tailPrefix`（ja「〜」、ko「~」、他「–」）。
5. 曜日の並び（月の見出しの 7 列・週の列）は `WeekStart.order` で作る（`DateText.mondayFirst` は `WeekStart.monday.order` と同じ値で残す）。`Calendar.firstWeekday` は読まない（ja_JP は 1、en_GB は 2、fr_CA は 1 と地域でばらばら）。地域の週の始まりを読むのは `WeekStartChoice` の `Locale.firstDayOfWeek` だけ（§10.3、L-14）。
6. ファイル名の日付「2026-10-17」（`AppExport.jsonFileName`）と、ページ id・`DayKey.description` は言語に関係しない形のまま。
7. 価格は StoreKit の `displayPrice`（店頭の国の通貨。言語ではなく App Store の国で決まる）。「/年」「月あたり」だけを訳す。「月あたり」の額は `LiveStoreClient.swift:36` の `priceFormatStyle` のまま。

### 3.2 場所ごとの 1.2

| 場所 | 1.1 | 1.2（持ち主） |
| --- | --- | --- |
| `PageNavigation.title` 日（:109-112） | 2026年10月4日(日) 体育の日 | `dayTitle` ＋ " " ＋ `holidays.name(of:)`（K） |
| 同 週（:113-119）・月・年 / `YearMonth.title`（`DayKey.swift:154`） | 2026年9月28日〜10月4日 / 2026年10月 / 2026年 | `weekTitle(first: weekStart.firstDay(of: focus), …)`（§10.1）/ `monthTitle` / `yearTitle`（K） |
| `compactTitle`（:131-140） | 10月7日(水) / 10/5〜10/11 | `shortDay` / `weekTitle(compact: true)`（K） |
| 曜日 `PageNavigation.swift:9`・`YearPaper.swift:12`・`StickyHeaderView.swift:34-35`・`PDFPageRenderer.swift:36, 217` | 日月火… | `DateText.weekdays` と `PaperWords`（§3.3、§4.1。P） |
| 「曜日」の連結 `StickyHeaderView.swift:177` | 水 + 曜日 | `weekdays(.full, …)`（ja は「水曜日」で同じ）（P） |
| 月の名前 `CalendarRootScreen.swift:1172`・`StickyHeaderView.swift:174, 208`・`PDFPageRenderer.swift:252` | \(m)月 | `PaperWords.yearColumnTitles`・`DateText.monthName`（P。:1172 は U が P の関数を呼ぶ） |
| `EventDateText.swift:7-57` | ja_JP の DateFormatter 3 つ、「終日」、「〜」 | `dayTitle(_:language:)`・`when(start:end:allDay:language:)`（§0。既定は `L.language`）。中身は全言語 `DateText.dayTitle`・`shortDay`・`time` と `LayoutWords.timeRange`、`event.allDay`（S。3 つの DateFormatter は消す。L-7 で `Locale(identifier: "ja_JP")` はアプリに残らない）。ja は DateText の手作りの式なので同じ字（`EventDateTextTests` がテストの中に置いた 1.1 の 3 つの DateFormatter の写しと比べる。`testEnglishEventText` は `language: .en` を渡して書く） |
| 予定の時刻 `MonthLayoutEngine.swift:190-202`・`TimedEventEngine.swift:146-153` | 9:00 / 〜11:00 / 9:00〜10:30 | 時刻は同じ、区切りは `words`（K） |
| 時刻の目盛り `TimeGridPaper.swift:51` | 0:00…23:00 | 変えない（D7） |
| 設定の日時 `SettingsScreen.swift:112-125`（`timeText`: 「最後に同期」と「前回の取り込み: 2026/10/14 9:41」の **日付と時刻**）・`:629-633`（`dateText`: 購入の **日付だけ**） | 端末の暦のまま（ICU） | `timeText(_:)` の中身を `DateText.numericDateTime(date, L.language)` に、`dateText` を `DateText.numericDate` に（U。0-11、0-33。第 1 版は両方を `numericDate` にしていて、同期と取り込みの時刻が消えるところだった）。**`dateText(_:locale:)` は形を残し**、中で `UILanguage.resolve(locale.identifier)` と `locale.region?.identifier` を取り出して `numericDate` を呼ぶ（既存の `SettingsScreenTests.testDateText` の ja_JP「2026/10/25」と en_US の確かめがそのまま通る、J-2）。`lastSyncText`・`webImportedText` の形も変えない |
| 数 `StrokeBudget.countText`（:103-112）・文に埋め込んだ 15,000 / 19,000 / 20,000（`CalendarRootScreen.swift:259, 261`・`SettingsScreen.swift:95`・`WebImportSheet.swift:141`） | 半角カンマ固定 | `DateText.number`（K・U・S） |
| 容量 `ExportSheet.swift:74-79` | 1.2 MB | 計算はそのまま（1024 基準）、数の書式だけ `NumberFormatter`（小数 1 桁）（S） |

### 3.3 曜日の記号（`WeekdayStyle.letter`。契約が値を決める `fixed` のキー `kit.weekday.letter.0`〜`.6`、0 = 日曜）

| 言語 | 日 月 火 水 木 金 土 の順 | 最大幅（heavy、15 lu） |
| --- | --- | --- |
| ja | 日 月 火 水 木 金 土（1.1 のまま） | — |
| zh-Hans / zh-Hant | 日 一 二 三 四 五 六（「周一」「週一」は使わない） | 0.94 em |
| ko | 일 월 화 수 목 금 토 | 0.86 em |
| en | Su Mo Tu We Th Fr Sa | 1.50 em |
| de | So Mo Di Mi Do Fr Sa | 1.47 em |
| fr | di lu ma me je ve sa | 1.47 em |
| es | do lu ma mi ju vi sá（CLDR の大文字「MA」は 1.60 em で入らない） | 1.47 em |
| it | do lu ma me gi ve sa | 1.47 em |
| pt-BR | dom seg ter qua qui sex sáb（M7B-14） | 2.11 em → 0.74 倍に縮める |

1 文字の記号（S M T W …）は使わない（fr の L M M、en の T T・S S が見分けられない）。`.short` は `shortStandaloneWeekdaySymbols`（ja は記号と同じ 1 字）、`.full` は `standaloneWeekdaySymbols`（ja「日曜日」…）。

## 4. 紙と見出しとツールバーの文字（担当 P。§4.4 のツールバーは S。1.1 の枠の数字は 1 つも変えない）

### 4.1 入れ方のきまり F-0〜F-11（全部「描く側」で処理する。**ja の絵は 1.1 と同じ**: ja は F-1 の曜日・F-2・F-3・F-7・F-8・F-10・F-11 で 1.1 のコードの道（今の枠・`drawLine`・今の修飾子）を通り、新しい描き方（`drawFittedLine`・広げた枠・分けた `Text`・足した修飾子）は ja 以外だけ。1.1 で「…」で切れていた ja の字も切れたまま。全言語に効くのは F-1 の数字の枠（右端は 1.1 と同じ）だけ）

- **F-0 共通**: `PaperText.drawFittedLine(_:in:font:color:minScale:scale:)` = 縮める率 `clamp(枠の幅 ÷ 字の幅, minScale, 1)`。`scale` を渡したら、その率を全部の字に使う（7 つの曜日・12 の月を同じ大きさにそろえる）。それでも入らなければ今の `drawLine`（`PaperText.swift:84-95`）と同じく末尾を「…」で切り、枠の外は切り取る。**字が枠に入るときは今の `drawLine` と同じ絵**。ja は、F-1 の曜日・F-2・F-3・F-7・F-8・F-10・F-11 では `drawFittedLine` も広げた枠も通らない（1.1 のコードの道。§4.1 の見出し）。
- **F-1 年のマスの曜日と日付の数字**（`YearPaper.swift:109-113`）: **曜日の記号**: ja は 1.1 の道（今の枠 21 lu（x 27、1.4 em）と `drawLine`。ja の記号は 1 em で入る）。ja 以外は、描く枠の幅を **23.4 lu（x 27 → 50.4。マスの左 45% の手書き欄の端まで）** に広げる（描く枠だけ。タップの枠・チップの位置は変えない）。記号は §3.3、全言語共通の率は `min(1, 23.4 ÷ (その言語の 7 つの記号の最大幅))`、下限 0.7。**日付の数字**（全言語）: 枠の **右端を 1.1 のまま**（`frame.minX + pad + 1.3 em`）にして、**左へ** 0.05 em 広げる（x を −0.05 em、幅を 19.5 lu（1.3 em）→ 20.25 lu（1.35 em）。左の余白 `yearPad` 3 lu の中で、今日の輪（マスの 1 lu 内側）にもかからない）。数字は右寄せ（:88-89 の注記、:110-111 の `alignment: .right`）なので、右端が同じなら今入っている数字の絵は変わらず、今日が 31 日のときの heavy の「31」（20.1 lu）が 0.6 lu 欠ける 1.0 からの小さな不具合だけが直る（写真モードの今日は 7 日なので J-4 の写真にも響かない）。**右へは広げない**: 右へ広げると全部の日の数字が 0.05 em（0.75 lu。13 インチの一覧で約 1 画素）右へ動き、日本語の年の写真が全部 1.1 と違ってしまう。J-4 で年の写真に 1 画素でも差が出たら、数字の枠は 1.1 のままに戻し（この直しは 1.2 では入れない）、M7B.md に書く。
- **F-2 年のマスの祝日名**（:114-120。枠 44.4 × 13.1 lu、11 lu、4.04 em）: `holidays.names(…, style: .short)`、1 行。**ja は 1.1 の道**（今の `drawLine` のまま、縮めない）: 1.1 で「…」になっている 8 件（5 字の天皇誕生日・憲法記念日・みどりの日・こどもの日・国民の休日と、6 字の建国記念の日・スポーツの日・勤労感謝の日。この Mac で 5 字は 4.62 em、6 字は 5.54 em）は 1.2 でも同じく「…」。0.8 倍まで縮めると 5 字の名前が全部入り、6 字の名前は小さい字で「…」になって、2026 年の名前が全部載る日本語の年の写真（ipad13・iphone・ipadmini・ipad11・iphone69 の year、year-zoom2、iphone-landscape-year、store/*/04-year）が 1.1 と違ってしまう（J-4、§1 の約束）。ja 以外は minScale 0.8（5.05 em まで）、それでも入らなければ「…」。2 行にしない（2 行目が手書き欄を覆い、それでも米国は 32〜43% しか入らない）。名前の全文は日・週・月の見出しと読み上げで見せる。
- **F-3 月のマスの祝日名**（`MonthPaper.swift:126-134`。読める倍率で 8.1〜9.0 em）: `full`、1 行。ja は 1.1 の道（今の `drawLine`。日本の名前はいちばん長い 6 字でも 5.54 em）。ja 以外は minScale 0.9、それでも入らなければ「…」。
- **F-4 時刻**: 24 時間のまま（D7）。範囲の区切り（`words`）はどれも「〜」より狭い（「9:00–10:30」5.33 em < 「9:00〜10:30」5.96 em）。
- **F-5「+n件」**（`MonthPaper.swift:189` が描く `TimedChip.title`。枠 192 × 20、8.9 em）: Layout が `words.more(n)` で作る（K）。訳の上限は「+99 …」で **7 em**（`maxEm: 7`）。en「+3 more」3.71 em、de「+3 weitere」4.70 em。
- **F-6「メモ」「自由メモ」**（`MonthPaper.swift:91`・`DayPaper.swift:70, 121`。枠 200 lu、月 21 lu・日 18.7 lu、字間 0.15 em/字）: 上限「幅 ＋ 0.15 em × 字数」が **8.0 em**（`maxEm: 8`）。いちばん長い「Freie Notizen」で 7.73 em。字間は今のまま（全言語 0.15 em）。
- **F-7「終日」**（`AllDayBandView.swift:122-131`・`PDFPageRenderer.swift:284`）: 画面は `PaperWords.allDayLabel`: 正式（`allday.label`）が `幅 − 6 pt` に 10 pt で入ればそれ、入らなければ短い形（`allday.label.short`、上限 2.4 em）、それも入らなければ出さない（読み上げでは元々読まない :130）。ja は正式「終日」1.73 em（iPhone の全幅の 12.4 pt には今も入らず、1.1 は切れて出ている。**ja は 1.1 と同じ描き方を続ける**: `language == .ja` なら今のコードの道）。PDF は 11 pt で 5.2 em（週 58）/ 6.0 em（日 66）を超える言語は短い形（fr「Toute la journée」6.54 em）。
- **F-8 月の曜日の行・年の月名の行**（`StickyHeaderView.swift:35, 52-62, 200-229`）: 月の曜日の行は `PaperWords.monthHeaderWeekdays`: CJK は記号（§3.3。ja は今の「月火水木金土日」）、ラテン文字は `.short`（最大 26.5 pt、iPhone の列 57.4 pt に入る）。並びは週の始まりのとおり（日曜始まりの ja は「日月火水木金土」）、色は列ではなく曜日で決める（土 = 青、日 = 赤。§10.5）。年の月名は ja なら今のまま（「n月」、各月 0.7 まで）。他は `MonthNameStyle.short` を共通の率 `min(1, (列の幅 − 4) ÷ 12 か月の最大幅)` で、率が 0.7 を下回れば数字「1」〜「12」。
- **F-9 週の列**（:99-139）: 列の幅 < 75 pt（`narrowWeekColumnPoints`、:97）なら記号、他は `.short`（ja はどちらも 1 字で同じ）。1 日の曜日を消すきまり（:102）と 0.6 までの縮小は今のまま。祝日 10 pt は 1 行で切る。
- **F-10 日の見出し**（:164-196）: 「10月」→ `monthName(_, .full, …)` 11 pt、「水曜日」→ `.full` 14 pt。ja 以外は、どちらにも `.lineLimit(1).minimumScaleFactor(0.8)`（今は付いていない :174-179。ja は 1.1 のコードのまま修飾子を足さない。ja の字は 1 行に収まっている）。祝日のカプセルは `layoutPriority(-1)` で先に切る。
- **F-11 ページの題名**（`PageHeaderView.swift:74-103, 155-160`）: ja は今の 1 つの文字列（`title`、1 行・0.6 まで）。他は日付（`dayTitle` など）と祝日名を別の `Text` にし、祝日名の優先度を下げて切る。縦長の iPhone は `compactTitle`（pt「qua., 30 de set.」6.65 em × 17 pt = 113 pt、0.6 倍で 68 pt）。iPad mini 縦の週の題名は、ja では 1.0.1 から「2026年10月5日～10月1…」と末尾が切れている（1.1 のリードの写真の見直し）。ja は 1.1 の道のまま直さない（J-4）。他の言語の週の題名（「Oct 5 – 11, 2026」など）は ja より短い見込みで、本人の iPad mini の英語の画面で見る（§8 の 9 の手順 5）。

### 4.2 読み上げ（P のファイルの分は P、他は S）

- 日付の読み上げは `DateText.spokenDay` ＋（祝日があれば）`", " ＋ full の名前`（ja は 1.1 の `EventDateText.dayTitle` ＋ " " ＋ 名前のまま）。
- 「（日表示へ）」「（月表示へ）」「…の終日予定を追加」「題名（予定を編集）」「前の日」などは、日付と動作をまとめた 1 つの文のキー（`header.day.spoken`「%1$@（日表示へ）」など）。前へ・次へは 4 種類 × 2 の完成した文（`PageHeaderView.swift:244-250` の「前の」＋「日」をやめる）。ja の値は 1.1 の組み上がった文と同じ（0-24）。
- 月の曜日の行（:55）に読み上げの名前を足す（`.full`）。紙そのものに読み上げの対象が無いのは 1.1 のまま（記録だけ。UI テストの `--screenshot-probe` のときだけ、紙の入れ物に「手書きの紙」の要素 `ink-canvas` がある。訳さない、§2.5 の例外）。

### 4.3 PDF（`PDFPageRenderer.swift`、P）

見出しの高さは定数のまま（:18-23, 74-87）。題名は `PageNavigation.title(…, holidays: HolidayChoice.current, language: L.language, weekStart: WeekStartChoice.current)`、曜日 :36・:217 は §3.3 と F-8（並びと色は §10.5）、月名 :252 は `monthName(.full)`（14 pt で 70 ≤ 112）、「終日」:284 は F-7、作成者 :26 は `L.text("app.name")`（ja「てがきカレンダー」。`ExportBuilderTests.swift:562` はそのまま通る）。

### 4.4 ツールバーの字（担当 S。F-12〜F-14。ja は 1.1 のコードの道のまま。J-4）

1.1 の後半（a07c525、M7A.md ずれ 45。ffb645e・d4f8e22・e156e10 で説明の注記を直した）で、ツールバーの横の寸法は `ToolbarLogic.Row`（`ToolbarLogic.swift:271-307`）に移った。道具 5 つと「しまう」のボタン（`ToolbarView.buttonFace` :117-133）は「名前（10 pt）＋ 5 ＋ 5、最小 48」、細中太（`widthButtons` :238-269）は「名前 ＋ 3 ＋ 3、最小 44」、色 38、↶↷ 44。横に流れる行は幅を提案しないので、**名前が 38 pt を超えるとそのボタンが広がる**。説明は改行の入った丸ごとの文で 2 行（`hint` :203-215。`.lineLimit(2)`・`.dynamicTypeSize(...xLarge)`、12 pt の `.caption`）、「指でも書く」（`fingerToggle` :295-303、13 pt）に `.lineLimit(1)`。日本語の名前はどれも 38 pt 以内（最長は「マーカー」「消しゴム」「投げなわ」の 36.9 pt。この Mac の実測）なので、1.1 の絵ではボタンは広がらない。

**1.1 の見える範囲が崩れる条件**（`ToolbarLogicTests.testRowWinsBackTheCollapseButton`（:335-357）の式を一般にしたもの。E = 名前で広がった分の合計）: iPhone 17 は、道具 5 つ ＋「しまう」の E が 9 pt を超えると最初の色（黒）が欠ける。iPad mini は細中太も足した E が 13 pt を超えると太が、11 インチは 15.5 pt を超えると ↷ が欠ける。13 インチは E ＋（「指でも書く」の訳 − ja）が 76.5 pt を超えると行の終わりが欠ける。ja はどれも E = 0。この Mac の CoreText（10 pt）で 38 pt を超えるふつうの語: fr Surligneur 49.5・Événement 53.4・Marqueur 46.1・Masquer 41.8、it Evidenziatore 65.3・Marcatore 48.9・Nascondi 45.1、pt-BR Marca-texto 58.6・Marcador 45.8・Borracha 43.6、es Rotulador 46.7・Marcador 45.8・Bolígrafo 43.3・Borrador 42.5、de Radierer 40.5・Ausblenden 56.6・Einklappen 52.7、en の「中」Medium 38.3。iPhone 17 の 9 pt には、fr・it・pt-BR（Marcador ＋ Borracha だけでも 13.4）・es（Bolígrafo ＋ Rotulador ＋ Borrador で 18.5）のふつうの語が入らない。だから第 2 版の末尾の申し送りの案（(a) 用語集で短い語を選ぶ・(b) lint・(c) 幅を測る XCTest）だけでは足りず、ボタンを広げない作りにする。

- **F-12 道具 5・「しまう」・細中太 3 の名前**: ja は 1.1 のコードの道のまま（名前 ＋ 10・最小 48、名前 ＋ 6・最小 44 で、長ければ広がる）。**ja 以外は名前の枠を 38 pt に固定**して `.lineLimit(1).minimumScaleFactor(0.8)`、ボタンは 48 × 44・44 × 44 のまま広げない。こうすると行の横の寸法がどの言語でも ja と同じになり、iPhone 17 の黒・11 インチの ↷・iPad mini の太が 1.1 と同じに見える。道の分け方は `ToolbarLogic.Row.labelFrameWidth(for: L.language)`（ja → nil、他 → 38）と `labelMinScale`（0.8）だけで決める（§0 の接点）。読み上げの名前は見える名前と同じキー（1.1 のまま、`.accessibilityLabel(label)`）。訳語: X はまず 10 pt で 38 pt（3.8 em）以内の語を選ぶ（L-12 の警告）。入らないときも 47.5 pt（4.75 em = 38 ÷ 0.8。0.8 倍で入る幅）まで。超えたら S の `ToolbarFitTests` が失敗にする。上の実測で言い換えが要る語: fr Événement・Surligneur、it Evidenziatore・Marcatore、pt-BR Marca-texto、de Ausblenden・Einklappen（38〜47.5 の語は縮んで入る）。英語の Pen・Marker・Eraser・Lasso・Event・Hide・Thin・Thick は 38 以内、Medium は 0.99 倍（§6.2）。
- **F-13「指でも書く」**（13 pt。`.lineLimit(1)` のまま縮めない）: 訳の幅 − ja の幅 ≤ 76 pt（同じ字体で測る）。13 インチ縦のペンの行の余裕 76.5 pt（`testRowWinsBackTheCollapseButton` の rowEnd 870.5 と、見える幅 947 から）。この Mac で ja は 60.0 pt なので、上限は約 136 pt（10.5 em）。en Draw with Finger 101.6 は入る。de Mit dem Finger zeichnen 148.8 は入らない（Mit Finger zeichnen 118.7 は入る）。
- **F-14 説明**（消しゴム・投げなわ・予定。12 pt の `.caption`）: 値の改行は 1 つまで（`lines: 2`、L-4。改行の無い訳もよい）。改行で区切った各行の幅は、**そのキーの ja の値のいちばん長い行以内**（同じ字体で測る。この Mac で、消しゴムの 3 キーは 144.0 pt（12.0 em）、投げなわと予定は 155.1 pt（12.9 em））。これで説明のある行の横の寸法も ja 以下になり、11 インチの ↶ ↷ などが 1.1 と同じかそれ以上に見える。`toolbar.hint.eraser.toPen`・`.toMarker` の 1 行目は `toolbar.hint.eraser` と同じ文にする（括弧の行が出ても 1 行目は変わらない）。iPhone では、どの言語でも説明は途中で切れる（1.1 の ja も同じ。M7A.md のずれ 45 の表の下）。長い言語で入らないときは、省略より短い言い換えを選ぶ。
- **キー**（S、`app-S.json`。どれも単純なキー）: `toolbar.hint.eraser`（:117 の `eraserHintText`）・`toolbar.hint.eraser.toPen`（:176）・`toolbar.hint.eraser.toMarker`（:178）・`toolbar.hint.lasso`（:120）・`toolbar.hint.event`（:121）。ja の値は 1.1 の文のまま（改行を含めて同じ、J-1）。b13fa91 の 1 行の説明と旧脚注で下書きした訳は使わない（X に知らせる。§6.3）。
- **消しゴムの説明の 1 行の形** `ToolbarLogic.eraserHint(returnsTo:)`（:185-187。`eraserBarHint` から改行を除いて作る）: **キーにしない。画面と読み上げでは使わない。** ja で走るテスト（`ToolbarLogicTests.testEraserHint` :294-304、`CalendarRootScreenTests.testEraserReturnTarget` :445-473）が 1.1 の 1 行の文と同じことを確かめるためだけに、今の形で残す。語の間に空白を置く言語でこれを使うと 1 行目と括弧がつながる（"…touches(then back to the pen)"）ので、S は ja 以外での呼び出しを足さない。別のキーや言語ごとの区切りは作らない（だから L-8 の「使われていないキー」も出ない）。
- **確かめ**: S の `ToolbarFitTests`（§7.2。シミュレータの UIFont で `L.text(_, in:)` の 10 言語を測る）、L-4・L-12、l10n-shots の写真（§7.5、§8 の 8）、本人の英語の画面（§8 の 9 の手順 5）。既存の `testBarHintsAreTheOneLineSentencesOnTwoLines`（:310-330。ja の字と「1 行 14 字以内」）と `testRowWinsBackTheCollapseButton` は ja で走り、期待を変えない（J-2）。

### 4.5 投げなわのメニューと見出しの切り替えの字（F-15 は S、F-16 は P。第 3 版の見直しで足した）

§4.1〜§4.4 の外にあって、訳の長さで切れたりはみ出したりしうる部品。どちらも 1.1 の寸法と作りは変えず、訳語の長さの上限と、それを測るテストと写真だけを決める（ja の値は 1.1 の文なので、ja の絵は変わらない）。

- **F-15 投げなわのメニュー**（`SelectionMenuView.swift`、S）: 「予定にする」「削除」「選択解除」を 14 pt（1 つ目は semibold）で横に並べる（各項目は記号 15 pt ＋ 間 5 ＋ 字 ＋ 左右の余白 12 ずつ、区切り 1 pt × 2。:16-56）。置くのは `CalendarRootScreen.swift:869` で `.fixedSize()`（縮みも折り返しもしない）、`placement(anchor:size:bounds:)`（:62-79）は幅が足りないと左端に寄せるだけなので、長い訳では右の項目が画面の外に出る（この Mac の見積もりで、メニューの幅は ja 約 276 pt、en「Make Event / Delete / Deselect」約 312 pt、fr「Créer un événement / Supprimer / Désélectionner」約 438 pt、de「In Termin umwandeln / Löschen / Auswahl aufheben」約 453 pt）。**上限**: 3 つの訳の字の幅の合計が、14 pt（1 つ目は semibold）で **220 pt 以下**（いちばん狭い対応機種の縦 375 pt（iOS 17 が動く iPhone SE 第 2・第 3 世代や iPhone 13 mini など）− 余白 8 × 2 − 区切り 2 − 3 ×（記号 15 ＋ 間 5 ＋ 余白 24）= 225 pt から、記号の幅の揺れの分を引いた値。iPhone 17（402 pt）なら 252 pt まで入る）。ja は 142 pt、en は 178 pt で入る。fr・de などは短い言い換えを X が選ぶ。キーは `selection.makeEvent`・`selection.delete`・`selection.deselect`（S、`app-S.json`。各 `maxEm: 7` は L-12 の目安で、本当の上限は合計）。`SelectionMenuView.margin`・`gap`・`placement` の形と、`CalendarRootScreen` の `.fixedSize()` は変えない（凍結した `InkCanvasViewTests` が `margin` と `placement` を使う、§0 の接点）。確かめ: S の `ToolbarFitTests.testSelectionMenuFitsTheNarrowestIPhone`（シミュレータの UIFont で 10 言語の 3 つの幅を測り、合計が 220 pt を超えたら失敗）と、l10n-shots の iPhone の `--screenshot-sheet lasso`（fr・de。§7.5、§8 の 8）。
- **F-16 見出しの切り替えと「今日」**（`PageHeaderView.swift`、P）: 切り替え（`kindPicker` :216-226、`.segmented`）は、iPad の 1 段の行で幅 220 pt に 4 つ（:96-98。1 つ約 54 pt）。13 pt で it「Settimana」60.9・fr「Semaine」51.9・es / pt「Semana」48.5 pt は切れうる。「今日」（:142-144、`.bordered`・`.fixedSize()`。字は既定の 17 pt）は、iPhone の 1 段目で題名の幅を削る（ja「今日」31.4 pt で題名に約 79 pt 残る、:20-23 の注記。fr「Aujourd’hui」86.2 pt だと約 24 pt しか残らない）。**上限**: 切り替えの 4 つ（`header.picker.day`・`.week`・`.month`・`.year`、P の `app-P.json`）は 13 pt の semibold で **44 pt 以内**（`maxEm: 3.4`。分割の中で字に使える幅はこの Mac では確かめられないので、写真で確かめる目安。en「Month」41.2・de「Woche」43.7 は入る。fr・es・pt・it の「週」は略した形（「Sem.」「Sett.」など）を X が選ぶ）。「今日」（`header.today`）は 17 pt で **ja の幅 ＋ 16 pt 以内**（約 47 pt、`maxEm: 2.8`。en「Today」45.7・de「Heute」45.9 は入る。fr は略した形（「Auj.」28.5 pt など）を X が選び、REVIEW.md に理由を書く）。切り替えの幅 220 pt と `fixedSize` は変えない。ほかの `fixedSize` の部品（「＋予定」・☁ の状態の字・閲覧専用の札）は広い行（760・980 pt 以上）だけに字が出て、伸びた分は題名が縮むだけ（0.6 倍まで、その後「…」）なので上限を決めない。確かめ: P の `PaperFitTests.testHeaderPickerAndTodayFit`（シミュレータの UIFont で 10 言語を測る）と、l10n-shots の 13 インチの月の写真（9 言語。§8 の 8）。**1.1.1 の読み替え**（§1.5）: 「今日」は 1.1.1 で題名の右へ動く（広い行は切り替えの右、狭い行は題名の右）。iPhone の題名に残る幅は約 81 pt、fr「Aujourd’hui」のままなら約 26 pt。上限はそのまま。狭い行の並びが変わるので fr の写真を見る。

## 5. 世界の祝日（担当 H・K・U）

### 5.1 データと生成器（H）

- 元: python-holidays（Vacanza Team と貢献者、MIT）。**版（M7B-10 は「はい」、0-14）**: H の最初の手順で、リードが PyPI から wheel を取り寄せる（`pip download --only-binary=:all:` で `holidays` と依存の全部。取り寄せる日の最新の安定版のうち、この Mac の Python 3.9.6 で入るもの。それより新しい版が要るときは M7B-20。聞くときは、取り寄せる物の出どころ・ファイルの名前・大きさ・置く場所・消し方を書く、§9）。`tools/holidays/requirements.txt` に **依存も含めた全部の版を `==` と `--hash=sha256:` で固定**し、venv には `pip install --require-hashes --no-index --find-links <取り寄せたフォルダ>` で入れる（取り寄せたフォルダはリポジトリの外。中身は data として扱い、生成器を中から走らせない）。0.83 の venv の版は `holidays==0.83`・`python-dateutil==3.0.0`（復活祭の計算に使う）・`six==1.17.0`・`tzdata==2026.6`（Python 3.9.6。`pip freeze` の実測）で、新しい版で依存が変われば書き換える。取り寄せた版・日付・各 wheel の sha256・`Requires-Python` を M7B.md に。取り寄せた後、リードは取り寄せた物（`holidays` と依存の版、出どころの PyPI、ファイルの名前と大きさ、置いた場所。消すときはそのフォルダを消すだけ）を本人に平易に報告する。種類は標準（public）だけ（任意の休み・銀行休業日・半日は入れない。例: ブラジルのカーニバルは「任意」なので出ない）。年は 2000〜2099。
- 生成: `<venv>/bin/python -I tools/holidays/gen.py TegakiKit/HolidayData`（venv はリポジトリの外。新しい版の venv はリードが作り、場所を M7B.md に。0.83 の venv は `/private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/b10c2ae9-5535-4dd5-97f2-2e5ca034309a/scratchpad/hol/venv`）。偵察の試作（`/private/tmp/claude-501/-Users-ikedamasataka-Documents-Codex/b10c2ae9-5535-4dd5-97f2-2e5ca034309a/scratchpad/m7b/holidays-proto/gen.py`）を土台に、§5.2 の `full`/`short`・推定の印の外し方・振替休日の型・`observed_label` が "%s" の国の扱い・CN の発表前の年を足す。**いつも同じ結果**（2 回作って `diff -r` が空。README の手順に必ず入れる。試作で 3 回一致を確認済み）。生成時間は約 20 秒。CI では作り直さない（CI に python-holidays は入れない）。
- **国の一覧**: `tools/holidays/iso-regions.txt`（Foundation の `Locale.Region.isoRegions` のうち 2 字の地域。`swift tools/holidays/iso_regions.swift > tools/holidays/iso-regions.txt` で 1 回作って commit）と、`list_supported_countries()` の 2 字の名前の重なりだけを出す。**249**（0.83 の数。"UK" は GB の別名で ISO の地域ではないので出ない。試作は UK.json を GB.json と同じ中身で書いていて、選ぶ画面に「イギリス」が 2 つ並んだ）。端末の地域 IC（カナリア諸島）・EA（セウタ・メリリャ）の読み替えは入れない（販売外）。
- **全国と差の無い州・地域は書かない**: add も remove も無い州・地域は、国のファイルにも index にも出さない（0.83 でノルウェーの 17 のうち 17、ブータン 19、ニカラグア 16、エルサルバドル 13、チリ 14/16、アルゼンチン 10/24 など。レビューの実測）。全部が同じ国は州の画面を出さない（韓国と同じ扱い）。記録済みの "NO-03" などは国全体として読む（`canonical`）。
- 合わせて書くもの: `index.json`（国ごとに `code`・`langs`・`ui`・`subdivisions`［`code`・`display`・`names`・`local`］・`renamed`・`lastOfficialYear`・`notice`・`coverage`［`from`・`until`］）、`SOURCE.json`（`library`・`version`・`generator` の sha256・`years`・各ファイルの sha256・**Python の版と依存の 4 つの版・各 dist-info の `RECORD` の sha256・2 つのライセンスのファイルの sha256**）、`LICENSE-python-holidays.txt`・`CONTRIBUTORS-python-holidays.txt`（venv の `holidays-<版>.dist-info/licenses/LICENSE`・`CONTRIBUTORS` から写す。全文。gen.py が写した後にバイト単位で同じことを確かめる。LICENSE の 1 行目が「see CONTRIBUTORS file」と書いているので、2 つがそろって完全な表示）。
  - `lastOfficialYear`: ライブラリの特別の表（`special_public_holidays` などの年の鍵。国のクラスとその Static のクラスの全部）の最大の年。無ければ null。0.83 では CN・TW・RU・BY・KZ・UZ・KR・SG・LK・NP が 2025、VN・AE が 2024、MY・GB が 2023（実測。新しい版で H が測り直す）。
  - `notice`: 政府の毎年の通知で休みと振替出勤日が決まる国の固定の表 `NOTICE = [BY, CN, KZ, RU, TW, UZ, VN]`（0-29）。
  - `coverage`: 0-30 の決め方。
- 大きさ（0.83 の実測、**UK を含む 250 ファイルのとき**）: 4,072,354 B、index 38,896 B、zlib で 1,586,042 B。全国の祝日 328,651 件、州・地域の差 118,122 件（「; 」でつないだ名前を分け、add と remove を数えた数）。249 ファイルにし、差の無い州を除いた後の実数は H が M7B.md に書く。
- `tools/holidays/summarize.py`（H）: 2 つの HolidayData のフォルダを比べ、国ごとの差を日本語で 1 行ずつ（「中国: 2027 年に 30 日追加」）。**必ず書き出すもの**: 消えた州・地域のコード、改名された州・地域のコード（旧 → 新。gen.py はライブラリの別名から `renamed` を作る）、全国の祝日の件数が 20% 以上変わった年、`lastOfficialYear`・`coverage` の変化。毎年の更新（§5.11）で使う。

### 5.2 ファイルの形 "tegaki-holidays/1"（1 国 1 ファイル、UTF-8、キーは辞書順、空白なし）

| 項目 | 中身 |
| --- | --- |
| `format`・`country`・`source`・`years`・`epoch` | "tegaki-holidays/1"・"US"・"python-holidays <版>"（§5.1 で固定した版）・[2000, 2099]・"2000-01-01" |
| `langs` | 名前の列の言語。`langs[0]` はその国の標準の言語（無ければ "en"） |
| `ui` | アプリの言語（ja en zh-Hans zh-Hant ko fr de es it pt-BR）→ 列の番号。その言語の名前があるものだけ |
| `names` | `[[列ごとの full]]`。振り替え休日（flags 4）はライブラリの型のまま持つ（「休息日（%s日起取代）」「Day off (substituted from %s)」「Выходной (перенесено с %s)」。0.83 で 11 か国）。`%s` は **読むときに**、入れ替えた週末の日付（`substFrom`）を列ごとの `substFmt` で埋める |
| `substFmt` | 列ごとのライブラリの日付の型（`substituted_date_format` を訳したもの）。0.83 の実測は `%m/%d/%Y`・`%d.%m.%Y`・`%d/%m/%Y`・`%Y-%m-%d`・`%Y. %m. %d.`・`%d-%m-%Y`・`%d/%m %Y` の 7 通りで、`%Y`・`%m`・`%d` 以外の指定があれば gen.py が止まる。Swift は 0 で埋めた数（`%m` → "01"）で置き換える。例: 中国 2025-02-03 の zh-Hans の full「休息日（2025-01-26日起取代）」、en の full「Day off (substituted from 01/26/2025)」 |
| `short` | `{名前の番号: [列ごとの short]}`。full と違うものだけ。振替などの後ろ書き（ライブラリの `observed_label` の型）を外した名前。**振り替え休日は、型の最初の「（」か「 (」の前**（「休息日」「Day off」「Выходной」）。それが空になる型はアプリの言語の `kit.holiday.dayOff`（kit-H.json。ja「振替の休み」、en「Day off」、zh-Hans「休息日」…）を使う |
| `flags` | 名前ごと: 1 推定（旧暦・イスラム暦と、0-29 の CN・VN の発表前の年の全部）、2 振替、4 振替休日（週末と入れ替え）。**ライブラリの推定の後ろ書き「(estimated)」などは名前から外す**（`islamic_show_estimated=False` が使える国はそれで、ほかは各言語の `estimated_label` の型を外す。印はアプリが付ける、0-17）。訳した `observed_label` が `"%s"` だけの国（0.83 で JP・BR・CH・CL・NL・RU・AW・BQ・CW・DO・GT・MO・SX・UY の 14 か国。実測）は、その型を振替の判定に使わない（型が「^(.+)$」になって全部の名前に振替の 2 が付き、例えばスイスの Neujahrstag やブラジルの Natal が「振替」になっていた） |
| `days` | `[日数, 名前の番号, …]`（2000-01-01 からの日数、日付順。同じ日に 2 つあれば 2 組、ライブラリの順のまま。ライブラリが「; 」でつないだ名前は分ける）。**CN の `lastOfficialYear` より後の年は、ライブラリの規則で作った「（观察日）」（observed）の日を書かない**（0-29） |
| `substFrom` | `[振替休日の日数, 入れ替えた週末の日数, …]` |
| `workdays` | 出勤日になる週末の日数（中国・台湾・ベトナムなど。`lastOfficialYear` より後の年は 0 件） |
| `subdivisions` | `[{code, add, addFrom, remove}]`。全国と差のある州・地域だけ（§5.1）。表示名・別名・`local` は index.json の側に |

index.json の州・地域（§5.1）:

- `display`: ライブラリの別名（`subdivisions_aliases`）を **ライブラリが書いた順のまま** 見て、略号（英大文字か数字だけの 3 字以下。"AU"・"BP"・"GP"・"GUA" など）でない最初の別名。無ければ code。例: NZ-AUK「Auckland」（別名の順は Auckland・Tāmaki-Makaurau・AU）、CA-NS「Nova Scotia」（Nova Scotia・Nouvelle-Écosse）、FR-971「Guadeloupe」（GP・GUA・Guadeloupe）。試作は別名を辞書順に並べていたので、ニュージーランドで "AU"・"BP"・"CA"、カナダの NS で英語の画面でも "Nouvelle-Écosse" が出た。
- `names`: 別名の全部（ライブラリの順。検索に使う）。
- `local`: code が ISO の形（英大文字か数字の 1〜3 字）でないもの（0.83 で DE-Augsburg、IT-Andria・Barletta・Cesena・Forli・Pesaro・Trani・Urbino、NZ-South Canterbury。実測）。州の画面で州の一覧の後ろの別の見出し「その他の地域（市など）」の下に出す（ドイツの州の一覧に市の Augsburg が混ざらないように）。

### 5.3 `HolidayCalendar` の約束（H。§0 の接点）

- `names(for:style:)` は、渡した日のうち祝日の日だけを返す。2000 年より前・2100 年以降は空（今の JapaneseHolidays と同じ）。年の表は国ごとに 8 年分まで覚える（試作の速さ: 最大の米国のファイルの初回読み込み 10 ms、年のページ 1 枚 0.04 ms、250 ファイル全部 188 ms。この Mac の release 版の値）。
- **名前の作り方**: `full` = 列の名前（振り替え休日は `%s` を `substFmt` で埋める、§5.2）＋ flags に estimated があれば `KitStrings.text("kit.holiday.estimatedSuffix", <画面の言語>)`（0-17）。`short` = §5.2 の short（印は付けない）。同じ日の 2 つ以上は「 · 」でつなぐ。
- **並び**: `entries(forYear:)` は、その日の国の祝日（州の `remove` を除いたもの）をデータの順のまま、その後に州の `add` をデータの順のまま足す。**並べ替えない**（試作は足した後に (日, 名前の番号) で並べ替えていて、名前の番号の小さい州の祝日が先に来る日があった。例 ボスニア・ヘルツェゴビナの SRP 2061-05-01「Kurban Bajram」が「Međunarodni praznik rada」より先）。
- `note(forYear:)`: `notice` の国で year > `lastOfficialYear` なら `.beforeNotice`、year が `coverage` の外なら `.incomplete(until: coverage.upperBound)`（両方なら `.incomplete`）。日本（橋）・なしは nil。
- `JapanHolidayBridge`（`HolidayStore.calendar(for: JP, language:)`）: 日付と ja の名前は `JapaneseHolidays.table(forYear:)`。**§5.5 で選ばれた列が ja のとき（日本語の画面、中国語・韓国語の画面でも 2 番目の規則で ja の列になる）は、名前も必ず `JapaneseHolidays` のもの**を使い、JP.json は ja 以外の列のときだけ使う（JP.json の ja の列は 2019 年の 2 件「天皇の即位の日」「即位礼正殿の儀が行われる日」が JapaneseHolidays と違うので、日本語の名前の出どころを 1 つにする）。ja 以外の列の名前は `JP.json` の同じ日の名前（日付は 1,773 日すべて一致を確認済みなので日付で引ける）。データに無い日（将来の特別な法律で JapaneseHolidays だけが持つ日）はその日の ja の名前。`short` = `full`。workdays は空。`note` は nil。**`.japan` は `JapanHolidayBridge(language: .ja)` と同じ結果で、データのファイルを読まない**（1.1 と同じ道、J-5）。
- 壊れた・知らないコード（"J"、"JPN"、"1A"、"US-ZZ"、"-"、"US-"、"-CA"、"US--CA"、空、コソボ）・読めないファイルでは落ちず、`.none`（州が知らないなら国全体）を返す。index が読めないときも JP だけは `resolved` も `calendar` も日本を返す（橋はデータが無くても動く）。
- **読み込むときの検査**（`HolidayFile`。どれか 1 つでも違えば、そのファイルは「読めない」として扱う。落ちない）: `format` が "tegaki-holidays/1"、`years` がちょうど 2 つ、`days` と `substFrom` と各州の `add`・`addFrom`・`remove` の長さが偶数で日数が日付順（同じ日は続けてよい）、名前の番号が全部 `names` の範囲の中、`flags` の数が `names` の数と同じ、`names` と `short` の各列の数が `langs` の数と同じ、`ui` の列の番号が範囲の中、`substFmt` の数が `langs` の数と同じ。index.json も同じく（`coverage.from ≤ until`、州の code が 0-28 の形）。試作は `"-"` を渡すと `split` の結果が空で `parts[0]` で落ち、名前の番号の範囲も見ていなかった。
- **速さと起動**: 起動（`CalendarRootScreen.init`、main）で作るのは今の設定の暦だけ。自動で端末の地域が日本以外のときは **index を読まず**、`hasCountry` で `<国>.json` の有無だけを見て決める（index の 39 KB は設定の画面を開いたときに読む）。国のファイル（米国で 216 KB）を JSONDecoder で読むのは古い iPad で数十 ms かかる見込みなので、起動のログ（DEBUG と写真モード）に祝日データを読んだ時間を `l10n: holidays loaded <ms> ms` で出し（時間は `Date` の差で測る。理由の申告が要る API を新しく使わない、§2.2 の PrivacyInfo）、CI のシミュレータの値を M7B.md に書く。目安は 50 ms。超えたら U が国のファイルを main の外で先に読み（読み終わったら `HolidayChoice.current` を入れて `relayout()`。それまでの数十 ms は祝日なしで描く。紙の形は同じなので手書きは動かない）、そうしたことを M7B.md に書く。日本（橋）はファイルを読まないので関係しない。
- `HolidayStore` は `@unchecked Sendable`（中で `NSLock`）。アプリでは 1 つだけ（`HolidayChoice.store`）。

### 5.4 Layout への渡し方（K）

- **祝日の暦を渡す所の全部**（Kit の 12 か所 ＋ アプリの 1 か所。第 3 版の見直しで、月のエンジンが tone を `LayoutMath.tone` を通さずにその場で決めている所（12）を足した。そのままだと中国などの振替出勤の週末が月のページだけ赤や青のまま残り、週・日のページと終日帯の黒と食い違う。第 1 版は 7 か所としていて、終日帯の `AllDayBandEngine.week/day` が中で `empty(kind:days:)` を引数なしで呼ぶ道が抜けていた。そのままだと `band.tones`（`AllDayBandView.swift:171` の列の色、`PDFPageRenderer.swift:271`）がどの国の設定でも日本の祝日になり、米国の週で 11/23（勤労感謝の日）の列が赤く 11/26 の Thanksgiving が赤くない、「なし」でも日本の祝日に色が付く。G-1 は tone を比べないので見つからない）:

| # | 場所（K。アプリは U） | 1.1 | 1.2 |
| --- | --- | --- | --- |
| 1 | `MonthLayoutEngine.swift:50` | `JapaneseHolidays.names(for: grid.days)` | `input.holidays.names(for:)`（full、F-3） |
| 2 | `WeekLayoutEngine.swift:184` | `JapaneseHolidays.names(for: days)` | `input.holidays.names(for:)` |
| 3 | `WeekLayoutEngine.swift:180` | `AllDayBandEngine.week(monday:events:now:calendar:)` | `…, holidays: input.holidays)` |
| 4 | `DayLayoutEngine.swift:219` | `JapaneseHolidays.name(of: day)` | `input.holidays.name(of:)` |
| 5 | `DayLayoutEngine.swift:186` | `AllDayBandEngine.day(_:events:now:calendar:)` | `…, holidays: input.holidays)` |
| 6 | `YearLayoutEngine.swift:339` | `JapaneseHolidays.names(for: allDays)` | `input.holidays.names(for:, style: .short)`（F-2） |
| 7 | `AllDayBand.swift:85` | `empty(kind:days:)` の中の `JapaneseHolidays.names` | `holidays.names(for:)` と `isWorkday` |
| 8 | `AllDayBand.swift:137` | `AllDayBandEngine.week` の中の `empty(kind: .week, days:)` | `empty(kind: .week, days:, holidays: holidays)` |
| 9 | `AllDayBand.swift:169` | `AllDayBandEngine.day` の中の `empty(kind: .day, days:)` | `empty(kind: .day, days:, holidays: holidays)` |
| 10 | `PageNavigation.swift:111` | `title` の中の `JapaneseHolidays.name(of: focus)` | `holidays.name(of:)`（`title(_:focus:holidays:language:)`） |
| 11 | `AppExport.swift:144` | `pdfFileName` の中の `PageNavigation.title(kind, focus: focus)` | `PageNavigation.title(kind, focus:, holidays: holidays, language: language)` |
| 12 | `MonthLayoutEngine.swift:97-105` | その場の式（祝日か日曜 → 赤、土曜 → 青） | `LayoutMath.tone(of: day, holiday: holiday, workday: input.holidays.isWorkday(day))` に置き換える（祝日・日曜・土曜の結果は今と同じ。ほかの 4 つと同じ関数にして workday を渡すため） |
| — | `CalendarRootScreen.swift:1162`（U） | `JapaneseHolidays.names(for: MonthLayout.grid(for: month).days)` | `makePaper` に渡した暦の `names(for:)`（`*LayoutInput` と同じ値。§5.6）。日の一覧は `MonthLayout.grid(for: month, weekStart: weekStart).days`（§10.5） |

  アプリの呼び出し（`CalendarRootScreen.swift:485, 651` の `PageNavigation.title`・`compactTitle`、`ExportBuilder.swift:181, 184` の `title`・`pdfFileName`、各 `*LayoutInput(`）は L-7 が `holidays:` と `language:` を求める。意味の確かめは G-4（§7.1）と `HolidayGeometryTests.testBandTonesFollowTheHolidays`・`testWorkdayToneIsNormal`（§7.2）。
- 色: `LayoutMath.tone(of:holiday:workday:)`（`PageLayout.swift:189`。内部の関数なので `workday:` に既定値を付けない）: この順に決める。祝日なら赤 → **`workday` なら通常**（日曜の出勤日も。中国 2024-02-04 は日曜の出勤日）→ 日曜なら赤 → 土曜なら青 → 他は通常。tone を決める所は 5 つで、全部が `holidays.isWorkday(day)` を渡す（0-18）: `MonthLayoutEngine.swift:97-105`（今はその場の式。表の 12 で置き換える）・`WeekLayoutEngine.swift:193`・`DayLayoutEngine.swift:226`・`YearLayoutEngine.swift:362`・`AllDayBand.swift:86`（`empty(kind:days:holidays:)` の中）。既定値が無いので、1 か所でも渡し忘れると組み立たない。日本・なしでは常に false なので 1.1 と同じ。確かめは `testWorkdayToneIsNormal`（§7.2）と G-4 の作り物の暦「W」（§7.1）。
- 祝日は色と名前にしか使わない（今の 4 エンジンの :96-113、:355-364、:184-195、:219-228 と同じ）。行の高さ・枠・`scrollDelta` に入れない（G-1）。

### 5.5 名前の言語（H、`HolidayStore.calendar(for:language:)`）

1. その国のデータに画面の言語の列（`ui`）があればそれ。
2. 無ければ、その国の標準の言語（`langs[0]`）が 10 言語のどれかで、画面と同じ系統の文字のとき、それ。系統: ラテン文字（en fr de es it pt）、漢字（ja zh-Hans zh-Hant）、ハングル（ko）。
3. それも無ければ英語。4. 英語も無ければ標準の言語。

例: 日本語の画面で台湾 → 國慶日、日本語の画面でドイツ → Epiphany（英語）、フランス語の画面でドイツ → ドイツ語、日本語の画面でサウジアラビア → 英語、フランス語の画面で日本 → 英語、中国語の画面で日本 → 日本語の名前（**JapaneseHolidays の名前**。zh-Hans の画面で 2019-05-01 は「即位の日」、§5.3）。10 言語の名前がそろう国は無い（英語 147、スペイン語 18、フランス語 14、ポルトガル語 7、中国語 4、ドイツ語 2、イタリア語 1、日本語 1、韓国語 1。販売中の地域（当時の 147）で数えた。H が EU を足した 174 で数え直す）。州・地域の名前は訳さない（データのまま。端末の機能に州の名前の訳は無い）。

### 5.6 設定の値と決め方（H の型、U の接続）

- 記録: `AppSettings.holidaySettingKey = "holidays.setting"`、値は `HolidaySetting.storageValue`（"auto"・"none"・"US"・"US-CA"・"GB-SCT"・"NZ-South Canterbury"・"FR-971"。州・地域はデータの表記のまま、0-28）。無い・壊れた値は自動（ただし §1.4 の移行が先に走り、記録が無い状態は 1 回目の起動の後には無くなる）。
- 決め方: `HolidayChoice.calendar(setting:deviceRegion: Locale.current.region?.identifier, language: L.language, store:)`。自動は端末の地域の国（州なし）。端末の地域が日本なら橋、それ以外は `hasCountry` が false ならなし（0-20）。この道は index を読まない（`HolidaySetting.resolved(deviceRegion:index:)` は index を読んだ後の設定の画面と `summary` で使う）。明示の州は、まず国のファイルの `subdivisions` の code と大文字小文字を区別せずに照らし、照らせなかったときだけ index を読んで `canonical`（`renamed` の読み替え）を通す。それでも知らない州は国全体。
- **画面の body では `HolidayChoice.current` を読まない**: `CalendarRootScreen` は `@AppStorage(AppSettings.holidaySettingKey) private var holidaySettingRaw = ""` を持ち、body の題名（`PageNavigation.title`・`compactTitle`、:485・:651）は、`holidaySettingRaw`（写真モードは `ScreenshotMode.Config.holidays`）から `HolidayChoice.calendar(…)` で作る計算プロパティ `holidays` を使う（`HolidayStore` が国のファイルと年の表を覚えているので、毎回作っても軽い）。`HolidayChoice.current` はただの `@MainActor static var` で SwiftUI が変化を見ないので、body で読むと `@AppStorage` の変化で body が先に評価されたときに題名だけ古い暦で作られ、紙は新しく題名は古い、という食い違いが次の描き直しまで残りうる。
- **紙の組み立ては 1 つの暦から**: `makePaper`（:1152-1174。`static` で、`init`（:339）と `relayout`（:1176-1178）から呼ばれ、同じ関数の中で `*LayoutInput`（:1156-1171）と月の `holidayNames`（:1162）を作る）に `holidays: HolidayCalendar` を 1 つ渡し、`*LayoutInput` の `holidays:` と :1162 の `names(for:)` の両方にこの同じ値を使う（`MonthPaper.swift:126` は `label.holidayName` が無い日に `content.holidayNames` を使うので、出どころが 2 つだと古い暦と新しい暦の名前が混ざりうる。`static` の `makePaper` からは計算プロパティを読めない）。`init` は `@AppStorage` を読めない（:321-324 の注記）ので、`HolidayChoice.migrateIfNeeded()`（§1.4。写真モードでは呼ばない）の後に `HolidayChoice.setting()`（既定の `AppSettings.defaults`。普段は `UserDefaults.standard`。写真モードは `Config.holidays`）から `HolidayChoice.calendar(…)` で暦を作り、`HolidayChoice.current` に入れてから `makePaper(…, holidays:)` に渡す。`relayout` は `HolidayChoice.current` を渡す。同じく `makePaper` に `weekStart: WeekStart` を 1 つ渡し、`*LayoutInput` と月の `holidayNames` の `MonthLayout.grid` の両方に同じ値を使う（`init` は `WeekStartChoice.prepareAtLaunch(shot:)` の戻り値。`prepareAtLaunch` は移行の後に決めた値を `WeekStartChoice.current` にも入れる。写真モードは移行をせず `Config.weekStart`。入れ忘れると、日曜の設定の人が起動してそのまま書き出した PDF の題名とファイル名だけが月曜の週になる。`relayout` は `@State weekStart`。§10.5）。
- `HolidayChoice.current` は **main の外へ値を渡すための写し**: U が `init` で入れ（上）、`.onChange(of: holidaySettingRaw)` で `HolidayChoice.current = holidays`（計算プロパティと同じ値）を入れてから `relayout()`（紙の形が同じなので `sameGeometry` は true で、線は作り直さない。紙の絵だけ描き直す）。`relayout` の `makePaper`・書き出し・PDF はこれを読む。写真モードでは `ScreenshotMode.Config.holidays` だけを使い、記録を読まない・書かない。
- 起動のログ（写真モードと DEBUG）: `l10n: ui=<lang> locale=<id> holidays=<HolidayCalendar.id>`。
- `HolidayChoice.current` は main で読む。main の外で紙や PDF を作る処理（書き出しなど）は、始める前に main で値を取り出して引数で渡す（`HolidayCalendar` は Sendable）。

### 5.7 設定の画面（U）

- `SettingsScreen` の「カレンダー」の節（`calendarSection` :230-。body の並びは :152-157）の **すぐ後**に週の始まりの節（§10.4）、その後（1.1 の「入力」の節 `inputSections` の前）に `HolidaySettingsSection()`。行「表示する祝日」、値 `HolidayChoice.summary(…, year: 今年)`。押すと `HolidayPickerScreen`。
- **行の値の形**（§6.3 のキー。注記は括弧の中に「・」でつなぎ、優先は データなし → 範囲の外 → 発表前 → 全国共通のみ。testSummaryTexts でこの全部を確かめる）: 「自動（日本）」「日本」「アメリカ合衆国・California」（州の表示名はデータのまま、§5.5）「なし」「自動（コソボ・祝日のデータがありません）」「自動（カナダ・全国共通の祝日のみ）」「カナダ（全国共通のみ）」「スリランカ（2026 年以降のデータがありません）」「中国（2026 年は発表前の推定）」（この 2 つの国と年は 0.83 のデータでの例。新しい版では H が測った年になる）「アメリカ合衆国（祝日のデータがありません）」（明示の国のファイルが読めないとき、0-20）。「全国共通の祝日のみ」は、全国と差のある州・地域を 1 つ以上持つ国（index の `subdivisions` が空でない国）で州を選んでいないときだけ（0-31）。
- `HolidayPickerScreen`: 先頭に「自動（この端末の地域：日本）」と「なし」、次に近道の 2 行「この端末の地域：<国>」と「日本」（端末の地域が日本なら 1 行）、次に検索の欄（「国・地域を検索」）と国・地域の一覧（index の 249。名前は `Locale(identifier: L.language.rawValue).localizedString(forRegionCode:)`、無ければコード。並びは画面の言語の `localizedStandardCompare`。日本語の画面では漢字の国名が読みの順にならないので、近道の 2 行を置く）。**検索は、画面の言語の国名・国のコード（"KR"）・英語の国名（`Locale(identifier: "en")`）のどれかに含まれれば当てる**（「かんこく」では当たらないが「korea」「KR」で当たる。記録だけ）。選んでいる行に ✓。州・地域のある国の行の下に小さく「州・地域を選ぶと、その地域の祝日が加わります」、`note(forYear: 今年)` がある国は行の下にその注記（0-29・0-30）。州・地域がある国は押すと次の画面（題名は国名）へ: 先頭に同じ一文、「国全体」、州・地域の一覧（`display`。並びは `display` の `localizedStandardCompare`。検索は `names` の全部とコードに当てる）、`local` の地域は別の見出し「その他の地域（市など）」の下。脚注「州・地域の名前は、データのままの表記（英語や現地の言葉）です。」。選ぶとすぐ記録して戻る。
- 節の脚注（§6.3 の文）。
- 「情報」の節（`infoSection` :544-）の「サポート」（:549）と「バージョン」の行 `versionRow`（:550）の間に、行「オープンソースのライセンス」→ `LicenseScreen`（`NavigationLink` で push）: 見出し「祝日データ：python-holidays（MIT ライセンス）」、本文に `HolidayData/LICENSE-python-holidays.txt` と `CONTRIBUTORS-python-holidays.txt` の全文（英語のまま。`.textSelection(.enabled)`）。**ファイルが読めなかったら**落ちず、空にもせず、`HolidayDataLicense.mitText` と「Contributors: <`HolidayDataLicense.contributorsURL`>」を出す（CI の bundle check が両方のファイルを確かめるので、普通は起きない）。**`.id(Self.infoRowId)` は `versionRow` のまま**（:551。13 インチの「情報」の写真で数の 2 行と脚注が見え、J-4 で違ってよいのは `sheet-info` だけのまま）。`versionRow`（:562-580）の長押しと記録の `.sheet`（:204-206、`showTrace` :61-62）は変えない（凍結した `InkTrace` が使う、§0 の接点）。
- 日本語以外の画面だけ、「情報」の脚注の後ろに訳についての文（`info.translationNote`。M7B-13。§6.3）。
- 設定 › 入力 の脚注（`eraserAutoReturnFooter(isPad:)` :85-89。e156e10、ずれ 49 で「どの消しゴムも戻る」の文になった。iPad「消しゴムで線を消して指や Apple Pencil を離すと、直前のペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムも同じです。」、iPhone「消しゴムで線を消して指を離すと、直前のペンかマーカーに戻ります。」）は U のキー `settings.input.eraserAutoReturn.footer.pad`・`.footer.phone`。**iPhone の値はどの言語でも Apple Pencil と iPad を書かない**（`SettingsScreenTests.testInputAndInfoTexts` :140- が ja で見ている。10 言語は新しい `testEraserFooterNeverNamesThePencilOnAnIPhone`、§7.2）。b13fa91 の文（「ツールバーで選んだ消しゴムで…Apple Pencil のダブルタップやスクイーズで選んだ消しゴムは戻りません。」）とは意味が逆なので、その文で下書きした訳は使わない。

### 5.8 購読している祝日カレンダーを隠す判定（U、`EventKitService.swift:71-77`）

`static let holidayCalendarWords = ["祝日", "holiday", "feiertag", "ferie", "festiv", "feriado", "节假日", "節假日", "假日", "공휴일"]`（**アクセントの無い小文字だけ**で書く。第 1 版の「férié」は、畳んだ題名「jours feries」に絶対に当たらない語だった。「ferie」で同じ結果）。題名と、念のため一覧の各語の **両方を** `folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)` してから、題名がどれかを含めば、購読カレンダー（`.subscription`）を最初から隠す。誕生日の扱いと「最初から隠すだけ（本人が出せる）」は今のまま。祝日の設定を「なし」にしても変えない（設定 › カレンダー で出せる）。

### 5.9 ライセンスと注意書き

- MIT の著作権表示と許諾文を全文、アプリ（§5.7）と英語のサポートページ（W）に。日本語の SUPPORT では、④「祝日の国を変えるには？」の答えの中の 1 文（「祝日のデータの出どころは python-holidays（MIT ライセンス）です。ライセンスの全文は、アプリの 設定 › 情報 ›「オープンソースのライセンス」にあります。」、§6.4。M7B-17 の ④ の「データの出どころ」の中で、公開の前に全文を見せる）。LICENSE の 1 行目が「see CONTRIBUTORS file」なので、CONTRIBUTORS も同じ所に置いて初めて完全な表示になる（アプリは全文、Web は CONTRIBUTORS の v<版> の URL。<版> は §5.1 で固定した版）。
- `HolidayDataLicense.mitText`（H）は LICENSE-python-holidays.txt と 1 バイトも違わない写し。KitChecks が照らし、2 つのファイルの sha256 が `SOURCE.json` と同じことも確かめる（CI に venv は無いので、venv の dist-info との照合は gen.py が生成のときに行う、§5.1）。
- 推定・誤りの可能性は、名前の「（推定）」の印（0-17）、設定の行の注記（0-29・0-30）、設定の脚注と規約（§6.4）で伝える。

### 5.10 データの弱い所（正直に書く。H が `docs/M7B.md` に表で。下は 0.83 の実測で、新しい版で H が測り直す）

- イスラム暦の祝日は 2077〜2081 年ごろから消える（サウジアラビア 年 13 件 → 2099 年 2 件など 39 か国。シンガポールは 2083 年）。ヒンドゥー暦はネパールが 2036 年から年 35 件 → 6 件、インドが 2036 年から 16 件 → 9 件（モーリシャスも減る）。どれも `coverage` の外として画面で知らせる（0-30）。
- スリランカは 2026 年以降 0 件（満月の祝日は政府の発表待ち。**今年から**欠ける）。ウクライナは 2022 年に 5 件、**2023 年以降 0 件**（戒厳令。第 1 版の「2025 年以降」は誤りで、試作の UA.json で確かめた）。どちらも販売中で、`coverage` の外として画面で知らせる。
- 0.83 の特別の表の最後の年: CN・TW・RU・BY・KZ・UZ・KR・SG・LK・NP が 2025、VN・AE が 2024、MY・GB が 2023 など（§5.1）。中国の 2026 年は、春節 2/16〜2/19・労働節 5/1・5/2 と規則で作った 5/4「劳动节（观察日）」・国慶節 10/1〜10/3 と 10/5「国庆节（观察日）」、振替出勤日 0 件（実測）で、公表済みの调休の日程（春節の 9 連休など。要確認）と合わない見込み。0-29 で「（观察日）」を出さず「発表前の推定」と知らせるが、本当の休みと出勤日は、M7B-10（「はい」）で入れる新しい版に入っていれば入る（入ったかを H が M7B.md に。3.9 で入る版に無ければ M7B-20）。韓国の臨時公休日も同じ。
- 2026 年でも推定のイスラム暦などの祝日は、アラブ首長国連邦・エジプト・パキスタン・インドネシア・マレーシア・インドで年 4〜9 件（マレーシアとインドネシアは旧正月も。試作の実測）。名前に「（推定）」を付ける（0-17）。
- **スロバキア（SK）の `coverage.until` が 2025 になっていた**（新しく売る国。2026 年は 11 件で基準 15 件の 80% の 12 件を下回るが、2027 年以降は 13 件で、データは 2099 年まである。今のままだと設定の行に「2026 年以降のデータがありません」と誤って出る）。H が `gen.py` の `coverage_range` を 0-30 の形（基準を下回る年が 1 年だけで、0 件でなく、次の年が基準に戻るときは切らない）に直す。今の `HolidayData`（0.107）に当てて確かめた結果（同じ計算で今の index と食い違いが 0 件なことを確かめてから）: `until` が変わるのは SK（2025 → 2099）だけ、`from` が AM（2003 → 2001）・CD（2015 → 2000）・KE（2011 → 2000）・PH（2012 → 2010）で広がる。LK（until 2026）と UA（until 2021）は今のまま止まる。EU の 27 か国で until が 2099 でないのは SK だけ。
- 販売中の地域で祝日のデータが無いのはコソボ（XKS）だけ。
- KitChecks が販売中の 174 の国・地域（EU の 27 か国を足した数。無いのはコソボだけ）の `lastOfficialYear`・`notice`・`coverage` を一覧にして書き出し、H がそれを M7B.md の表にする。

### 5.11 毎年の更新（H が手順を `tools/holidays/README.md` に）

年に 1 回（12 月ごろ、中国の调休の発表の後）と、臨時の祝日が出たときに、版を上げて作り直す（ダウンロードは毎回本人の了承を得てから。M7B-10 の「はい」は 1.2 の 1 回だけ。requirements.txt の版と hash を書き換える）→ **2 回作って `diff -r` が空**を確かめる → `summarize.py` の日本語の要約（消えた・改名された州、20% 以上変わった年、`lastOfficialYear`・`coverage` の変化）を本人とリードが読む → 改名された州は `renamed` に入っていることを確かめる（記録済みの "XX-旧コード" が何の表示もなく国全体に戻らないように）→ KitChecks（日本との一致・答えの分かっている日）→ アプリの更新として出す。

## 6. 翻訳・規約・App Store（担当 X・R・L・W・A）

### 6.1 訳の作り方と、ネイティブの確認が無いことへの対策（X・R）

**正直に書くこと**: 訳は Claude（X）が書き、別の Claude（R）が日本語の元を見ずに日本語へ逆に訳して照らす。**各言語を母語とする人の確認は無い**。本人は日本語しか読めない。このことを、この契約・`docs/i18n/REVIEW.md`・各言語の新機能の文の最後の 1 行・**各言語の説明（description）の最後の 1 文**・英語のサポートページ・設定の訳の注記（M7B-13）に書く。新機能の文は次の版で書き換わるので、店頭に残るのは説明の 1 文（第 2 版）。説明の 1 文は R の逆翻訳の対象に入れ、次の版の新機能の文の雛形にも残すことを M7B.md に書く。

危険の減らし方:
1. **短く平易な文**: 1 文 1 つの意味、慣用句・冗談・感嘆符を使わない、敬語の段は各言語の普通のアプリの丁寧さ（独 Sie、仏 vous、西・葡・伊は利用者への丁寧な二人称、韓 해요체、中 你/您 は您を使わない普通の文）。
2. **用語集を先に固める**（§6.2）: アプリ自身の言葉を言語ごとに 1 つに決め、全部の文で同じ語を使う（lint では見られないので R の照合で見る）。
3. **逆翻訳**: R は `translations/<言語>.json` の値とキーの `comment` だけを読み、`docs/i18n/back/<言語>.json` に日本語を書く。X が `REVIEW.md` に「キー・元の日本語・逆翻訳・判定（○ 同じ意味／△ 言い回しの差／× 意味の違い）・直した訳」の表を作る。照らすときに特に見ること: `toast.pinchHint` の向き（広げる = 拡大、つまむ = 縮小）、ストアの文に「か月分」にあたる語が無いこと（§6.6）。× は全部直して R がもう一度逆に訳す。△ は理由を書いて残してよい。
4. **iOS の画面の名前**（「設定」›「Apple Account」›「サブスクリプション」など）は、Apple のサポート記事の各言語版（例 support.apple.com/118428「Apple のサブスクリプションを解約する」。公開のページを読むだけ。ログインしない）の語に合わせ、URL を GLOSSARY に記録する。iOS・iPadOS 17 の「Apple ID」の書き分けも同じ。
5. **長さ**: `maxEm` のあるキーは X が守り、P の `PaperFitTests`・S の `ToolbarFitTests`（§4.4）と CI の二倍長の写真・ドイツ語の写真（§7.5）で確かめる。
6. **法律の文は英語だけ**（D11）。「日本語版が優先する」を冒頭に書く。
7. **ストアの文は事実だけ**（機能の説明。比較・最上級・約束をしない）。A の原稿も R が逆に訳す。
8. **誤訳の受け口**: サポートのメールで受け、次の版で直す（§6.7）。
9. **EU の読み手**（第 4 版）: es の画面はスペインの人も読むので、中南米だけの語を避ける。de はドイツの標準の書き方（ß を使う）、fr はフランスの書き方。ストアの pt-PT は別に書き、es-ES は es-MX から直す（§11.2）。`GLOSSARY.md` に店頭の注を書く。

### 6.2 用語集（X が `docs/i18n/GLOSSARY.md` に 9 言語分を書く。英語は契約が決める）

| 日本語 | 英語（固定） | 注 |
| --- | --- | --- |
| 手帳 | planner | アプリの説明で使う |
| 紙 | paper | 「紙を広く使えます」など |
| 日・週・月・年（ページの切り替え） | Day・Week・Month・Year | 区切りのボタン。13 pt の semibold で 44 pt 以内（F-16。fr・es・pt・it の「週」は略した形） |
| 日のページ ほか | day page / week page / month page / year page | |
| 指でも書く | Draw with Finger | ツールバーと設定。ツールバーは F-13（13 pt で ja ＋ 76 pt まで。en は 101.6 pt で入る） |
| メモ / 自由メモ | Notes / Free Notes | F-6 の長さ |
| 閲覧専用 | View Only | 札とトースト |
| ペン・マーカー・消しゴム・投げなわ・予定（道具） | Pen・Marker・Eraser・Lasso・Event | ツールバーの名前（F-12）。10 pt で 38 pt 以内を先に選ぶ（en は 18.1・33.5・30.7・28.1・26.9 pt）。X は各言語の語と 10 pt での幅を GLOSSARY に書く |
| 予定にする | Make Event | 投げなわのメニュー。「削除」「選択解除」と合わせて、14 pt で 3 つの合計 220 pt 以内（F-15） |
| しまう（ツールバー） | Hide | 読み上げ「Hide toolbar」。10 pt で 22.2 pt（F-12） |
| 元に戻す・やり直す | Undo・Redo | |
| 細・中・太（ペンの太さ） | Thin・Medium・Thick | ツールバーの名前（F-12。10 pt で 21.0・38.3・26.3 pt。Medium は 0.99 倍に縮んで入る）。読み上げ「太さ: %@」の型も X が訳す |
| ダブルタップ／スクイーズ（Apple Pencil） | double-tap / squeeze | 設定 › 入力 の脚注と Apple Pencil の行（`SettingsScreen.swift:87, 379`）・初回案内（`OnboardingView.swift:26`）で同じ語。各言語は Apple の表記（§6.1 の 4 の方法） |
| 終日 | All-day | F-7（短い形も X が決める） |
| 祝日 / 振替休日（日本のデータ） | Holidays / Substitute Holiday | 日本の名前はデータの英語名 |
| 同期 | Sync | |
| この端末 | this device | |
| 手書き / 線（本） | handwriting / stroke(s) | |
| 手書きを書き出す / Web 版の手書きを取り込む | Export Handwriting / Import from the Web Version | Web 版の機能名「手書きを書き出す（iPad アプリ用）」は訳の中でも括弧で日本語のまま添える（Web 版は日本語だけ）。そのキーに `allowJapanese: ["手書きを書き出す（iPad アプリ用）"]`（L-2） |
| このページを PDF | This Page as PDF | 書き出しのシートのボタン。§8 の 9 の手順 7 の道 |
| データ（設定の節） | Data | §8 の 9 の手順 7 の道 |
| 購読・試用・月額・年額 | subscribe / free trial / Monthly / Yearly | |
| 今日 | Today | 見出しのボタン。17 pt で ja の幅 ＋ 16 pt 以内（F-16。fr は略した形） |
| 週の始まり / 月曜・日曜 | Week Starts On / Monday・Sunday | 設定の行と切り替えの説明（§10.4）。「前後の月の日のマス」は cells for days of the previous or next month（「薄いマス」はアプリの語ではないので文に使わない） |
| 2 本の指を広げる（拡大）・つまむ（縮小） | Spread two fingers to zoom in, pinch to zoom out | ピンチの案内（1.1.1 の文 `pinchHintToast`、§1.5）。「2 本の指で」を「ピンチ」という名詞で訳さない。向き（広げる = 拡大、つまむ = 縮小）を R が逆翻訳で確かめる |
| てがきカレンダー（名前） | Tegaki（ホーム画面）/ M7B-1 の名前（ストア） | |

### 6.3 新しい日本語の文（固定。キーは各持ち主の元に）

1.1 の後半で増えた・変わった文（ツールバーの説明 4・入力の脚注 2・記録のシート 5・探りの名前 1）は 1.1 の文で、1.2 の新しい日本語ではない（J-1 の対象。ja は e7b4d2f の文）。訳すのはツールバーの説明（§4.4 の 5 キー）と入力の脚注 2（§5.7）。訳さないのは記録のシートと探りの名前（§2.5 の例外）。b13fa91 の文（1 行の説明・旧脚注）で下書きした訳は使わない。R は逆翻訳で、入力の脚注が「Apple Pencil で選んだ消しゴムも戻る」意味になっていることを REVIEW.md で確かめる。下の表と新機能の文（ja・en）は第 2 版のまま（ただし ja の新機能の 2 つ目の点に、見直しで 1 文を足した。言語を足すときに出る問いで、端末の表示を変えてしまわないため。第 4 版で週の始まりの行と、新機能の文の週の始まりの点を足した）。

| 場所（持ち主） | 文 |
| --- | --- |
| 設定の節の見出し（U） | 祝日 |
| 行（U） | 表示する祝日 |
| 行の値（U） | 自動（%@）／ %@ ／ なし ／ 自動（%1$@・%2$@）／ %1$@（%2$@）。州は「%1$@・%2$@」。注記（%2$@ に入る）は「祝日のデータがありません」「%@ 年以降のデータがありません」「%@ 年は発表前の推定」「全国共通の祝日のみ」（自動のとき）・「全国共通のみ」（国を選んだとき）。2 つ以上は「・」でつなぐ（§5.7） |
| 選ぶ画面（U） | 題名「表示する祝日」、「自動（この端末の地域：%@）」「なし」、近道「この端末の地域：%@」、検索「国・地域を検索」、見出し「国・地域」、国の行の下「州・地域を選ぶと、その地域の祝日が加わります」、州の画面「国全体」・見出し「州・地域」・見出し「その他の地域（市など）」・脚注「州・地域の名前は、データのままの表記（英語や現地の言葉）です。」 |
| 推定の印（H、`kit-H.json`） | `kit.holiday.estimatedSuffix`「（推定）」、`kit.holiday.dayOff`「振替の休み」（§5.2） |
| 節の脚注（U） | 日本の祝日は、このアプリが計算しています（内閣府の発表と照らし合わせて確かめています）。ほかの国の祝日は、公開されているデータ（python-holidays）にもとづきます。旧暦やイスラム暦の祝日など一部は推定で、「（推定）」と付けています。政府の最新の発表と違うことがあります。祝日の設定はこの端末だけに保存します。 |
| 情報の行（U） | オープンソースのライセンス。画面の見出し「祝日データ：python-holidays（MIT ライセンス）」 |
| 訳の注記（U。ja には出さない。英語の文を元に X が訳す） | en: “The translations in this app were made with AI and checked by translating them back into Japanese. No native speaker has reviewed them yet. If you find a mistake, please write to syfan0@gmail.com.” |
| 週の始まり（U・S） | §10.4 の 23 キー |
| ピンチの案内（U。1.1.1 の文なので ja は J-1 の表の中、§1.5） | `toast.pinchHint`。ja は `<1.1.1>` の `CalendarRootScreen.pinchHintToast` をそのまま（今の値は「2 本の指を広げると拡大、つまむと縮小します」）。en “Spread two fingers to zoom in, pinch to zoom out” |

**このバージョンの新機能**（ja。A が他の言語へ）:
> ・英語、中国語（簡体字・繁体字）、韓国語、フランス語、ドイツ語、スペイン語、イタリア語、ポルトガル語で表示できるようになりました。端末の言語に合わせて切り替わります（ほかの言語の端末では英語になります）。
> ・アプリだけ日本語のままにしたいときは、「設定」アプリ ›「アプリ」›「てがきカレンダー」›「言語」で日本語を選んでください（iOS・iPadOS 17 では「設定」›「てがきカレンダー」›「優先する言語」）。項目が無いときは、「設定」›「一般」›「言語と地域」で使いたい言語を追加すると出ます（追加するときに、端末の表示をどちらの言語にするか聞かれたら、今の言語のままを選んでください）。
> ・世界の国と地域の祝日を表示できるようになりました。アプリの設定 › 祝日 ›「表示する祝日」で、国（アメリカの州などの地域も）や「なし」を選べます。州・地域のある国は、州・地域を選ぶとその地域の祝日が加わります。日本の祝日はこれまでどおりです。これまでお使いの方は、日本の祝日のままです。
> ・週の始まりを月曜・日曜から選べるようになりました（設定 › 週の始まり）。これまでお使いの方は月曜始まりのままです。新しく使い始める方は端末の地域に合わせます（日本は月曜）。週のページの手書きは月曜始まりと日曜始まりで別々に保存します。切り替えると、もう一方の手書きは元に戻すまで見えませんが、消えません。月のページの手書きは日付についていきます。日曜始まりで書いた週の手書きは、古い版の端末では見えません（消えてはいません）。
> ・祝日・言語・週の始まりの設定は端末ごとです。祝日と言語を変えても、手書きは同じ位置に残ります。

他の言語の新機能の最後に 1 行（en の元）: “Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes.” 同じ 1 文を各言語の説明（description）の最後にも置く（§6.1）。

**en-US（と写しの en-GB・en-AU・en-CA）の新機能の文の最後**（M7B-19 は既定の (a) で確定。英語の 1 文と、日本語の 1 文をそのまま。L-9 は日本語を拒まない）: “The app now follows your device language. The name on the Home Screen is now “Tegaki”.” ／「これまで日本語でお使いの方へ：端末の言語が日本語以外のときは、その言語（対応していない言語は英語）で表示されるようになりました。日本語に戻すには「設定」アプリ ›「アプリ」›「てがきカレンダー」›「言語」で日本語を選んでください。」

### 6.4 規約類（L。平易な日本語。【】と「下書き」は書かない）

| 文書 | 直す・作る |
| --- | --- |
| TERMS.md 第 12 条の後 | 「あなたがお住まいの国の消費者保護の法律で、放棄できない権利は、この規約によって制限されません。」（今の :94 は「日本の法律で認められる権利」だけ） |
| TERMS.md の免責の条 | 「日本以外の祝日は公開データ（python-holidays）にもとづく参考の情報で、正確さを保証しません。」 |
| PRIVACY.md | 「祝日のデータはアプリの中に入っていて、表示のために通信することはありません。」の 1 文（データの収集は無いまま） |
| SUPPORT.md の FAQ に 2 つ | 「### 表示の言語を変えるには？」（端末の言語に従う、他の言語の端末は英語、「設定」アプリ › アプリ › てがきカレンダー › 言語。「項目が無いときは、『設定』›『一般』›『言語と地域』で使いたい言語を追加すると出ます。追加するときに、端末の表示をどちらの言語にするか聞かれたら、今の言語のままを選んでください。」の 2 文）／「### 祝日の国を変えるには？」（アプリの設定 › 祝日 ›「表示する祝日」、州・地域を選ぶとその地域の祝日が加わること、なし、データの出どころ（「祝日のデータの出どころは python-holidays（MIT ライセンス）です。ライセンスの全文は、アプリの 設定 › 情報 ›「オープンソースのライセンス」にあります。」の 1 文、§5.9）と推定の印、「発表前の推定」「データがありません」の意味、誤りの報告先）。日本語のページに足すのは、この表の 4 つ（第 12 条の後・免責の条・PRIVACY の 1 文・この FAQ の 2 つ）と、下の行の EU の文と週の始まりの FAQ だけ（English のリンクは M7B-23 の答えしだい、§6.5） |
| TERMS.en.md・PRIVACY.en.md・SUPPORT.en.md（新規） | 日本語版の英訳。冒頭「This is a translation for convenience. The Japanese version prevails.」。SUPPORT.en には連絡先、購入の復元、解約（Apple の 118428 の英語版）、返金（reportaproblem.apple.com）、書き出し、Web 版からの取り込み、祝日の国の変え方、言語の変え方、python-holidays の著作権表示と許諾文、「Support is provided by one developer in Japan. You can write in English or Japanese. Replies are prepared with the help of machine translation and may take a few business days.」 |
| 訳す元 | e7b4d2f の日本語の 3 文書（第 4 版の LA2 は、1.1.1 を取り込んだ後の 3 文書、§1.5）。`docs/SUPPORT.md:140`（「ツールバーをしまうには？」）は ffb645e で「丸ボタンの道具の印を押すと」に直った文（Web の `app/support.html` も m7a-legal 8e1dac7 で同じ）。そこから訳す |
| 逆翻訳 | R が英語の 3 文書だけを読み `docs/i18n/back/legal-en.md` に日本語を書き、L が元の日本語との食い違いを表にして REVIEW.md に足す |
| EU の文（第 4 版。LA2） | §11.3 の T-1〜T-9・P-1〜P-4・S-1〜S-6 を日本語と英語に足す。R の逆翻訳の対象。M7B-17 の「はい」の外（§6.5 の公開の直前の確認で聞く） |
| 週の始まりの文（第 4 版。LA2） | §10.4 の SUPPORT の括弧と FAQ |
| 1.1.1 の文（第 4 版。LA2） | §1.5。日本語は merge で入る。英語版に同じ直し |

確かめ: 日本語の 3 文書の価格・試用・解約の経路の文字列・連絡先・氏名は変えない（`grep -c '「設定」›「Apple Account」›「サブスクリプション」' docs/TERMS.md` が編集の前と同じ）。

### 6.5 Web（W、Web リポジトリ、ブランチ `m7b-legal`。1.1.1 の `r111-legal` が main に merge されていればその main から、まだなら `r111-legal` の先頭から切る。Web の main は今 8e1dac7 で、1.1 の `m7a-legal` は merge 済み）

- 日本語の 3 ページ（`app/terms.html`・`privacy.html`・`support.html`）を L の Markdown の直しと文字単位で一致させる（今の様式。`<script` 無し、CSP の meta そのまま）。**今の日本語の URL は永久に変えない**（1.0・1.1 のアプリが直接開く）。足すのは §6.4 の 4 つと、§11.3 の EU の文、§10.4 の週の始まりの FAQ（`hreflang` は足さない）。**English へのリンク**は M7B-23 の答えしだいで、W は別の commit（下の ③）にしておく（第 3 版は「1.2 では足さない」だったが、EU で売ると、EU の人が設定から開くページが日本語だけで行き止まりになる。§9）。
- 新規 `app/en/terms.html`・`privacy.html`・`support.html` の 3 ページ（M7B-3 で聞いたのはこの 3 つ。`app/en/index.html` は作らない。アプリも Connect も 3 つを直接開く）。`<html lang="en">`、favicon `../../icons/favicon-32.png`、同じ CSP。各ページに、日本語版の同じ文書への目に見えるリンク（「日本語版（正本）」）。`hreflang` は付けない（片側だけになるので）。
- `tools/check-legal.mjs` を `app/` の下を全部（下の階層も）見るように。英語の禁止語（`TODO`・`DRAFT`・`【`・`[`）と、埋め忘れの字（`XX`・`Month DD`。S-5、§11.1 の順 5）を足す。`tests/app-pages.test.mjs` に (10) 新規: en の 3 ページがあり、`lang="en"`・CSP・favicon・“Last updated”・連絡先・Apple EULA の URL・日本語版へのリンクを含む。第 4 版で (10) に足す: en の PRIVACY の第 12 節・第 13 節、SUPPORT の “How do I cancel a purchase in the EU?”、ja の同じ節、ja・en に「EU には配信」「not distributed in the EU」が無いこと。(1)〜(9) は ja の一覧のまま。`npm test` と `npm run check:legal` が緑。**公開の直前にリードが**、T-3・S-4・`refund.md` に書いた Apple の規約の URL を `curl -sL` で開き、本文に `right of withdrawal` があることを見る（国を選ばない `…/itunes/` は米国版に着き、この語が 0 件だった。§11.3）。
- commit だけ（push しない・merge しない）。**commit を 3 つに分ける**: ① 英語の 3 ページと `check-legal.mjs`・`tests/app-pages.test.mjs` の (10)（① だけでも `npm test`・`npm run check:legal` が緑）、② 日本語の 3 ページの直し（§6.4 の 4 つと §11.3 の EU の文と週の始まりの FAQ。S-5 の行は入れない。公開の日にリードが日付を入れて足す、§11.1 の順 5）、③ 日本語の 3 ページの上に English へのリンクを 1 つずつ（M7B-23。答えが「はい」のときだけ merge する）。**M7B-3・M7B-17 は「はい」**（2026-11-01）なので、両方を公開する。**時期**: どちらも 1.2 を App Store で公開した日（本人が手動リリースを押す日。本人が前もってリードに伝える、§12.4 の (7)）。英語のページを審査の前に出す案（M7B-21）は聞かない（本人が自分から望んだときだけ、§9 の条件で行う。そのときも ① だけを先に cherry-pick することはしない。1.1 の文が英語で先に出るため）。**公開の直前の確認**: M7B-3・M7B-17 の「はい」は、④ のよくある質問の文と英語のページがまだ書かれていないときにもらったものなので、merge の直前に、リードが公開する物の一覧（② の日本語の 3 ページの差分の全文（T-1〜T-9・P-1〜P-4・S-1〜S-6 を含む。特に **「メールは Gmail に保存し、AI の翻訳に渡すことがある」** と公に書くこと）、① の英語の 3 ページは R の逆翻訳の要点、③ を入れるならその 1 行、公開する URL）を本人に見せ、**「はい」をもらってから** merge する（main への merge と公開は実行の前に確かめる約束）。直しを求められたら直して見せ直す。merge と公開はリードが行い、`curl -sI` で URL が 200 を確かめる。公開日の merge は 1.1.1 の `r111-legal` が先、1.2 の `m7b-legal` が後（`r111-legal` は 1.1.1 を公開する日に main に入る。1.2 を出す日に入っていなければ、先に `r111-legal` の公開を本人に確かめる）。公開の順の全体は §11.1。

### 6.6 App Store（A が `docs/store/` に原稿、リードが §8 の 11 の確認表を本人に見せ、本人が「この内容で入れてよい」と言った後に Connect に入力、提出は本人）

**入力の約束**: 15 ロケールの名前（第 1 案と退き先 2 つ）・サブタイトル・キーワード・promo・説明・新機能の文、サブスクリプションの表示名と説明とグループの表示名、サポートとプライバシーポリシーの URL、審査メモと、言語ごとの写真は、公開される物か、本人の名で Apple に出す物。**M7B-18 は「はい」**（2026-11-01）で、条件は「入れる前に、言語ごとに日本語へ訳し戻した確認表を見せる」。リードは §8 の 11 の確認表（入力する物を全部載せる）を渡し、本人の「この内容で入れてよい」を受けてから入力する（直しを求められたら直して見せ直す）。確認が提出に間に合わないときは ja だけで 1.2 を出してよい（アプリの訳とストアの文は切り離せる。他の国の店頭には今の日本語の文が出る。**そのときは EU を入れない**、§11.1）。

| ロケール（Connect のコード） | 主に出る販売中の店頭 | 原稿 |
| --- | --- | --- |
| ja | 日本 | 1.2 の新機能（§6.3。提出に要る。M7B-18 の対象の外だが、本人が日本語で読んで決めるので、§8 の 11 の確認表にそのまま載せる）。**公開中の説明の「月曜始まり、日本の祝日に対応」の 1 行だけ**、「週の始まりは月曜・日曜から選べます。世界の国と地域の祝日に対応」に直す案を確認表に載せて本人に聞く（新機能の文は次の版で消えるので、説明の古い文が残り続けるため。価格の行は ja なのでそのまま） |
| en-US / en-GB / en-AU / en-CA | 米国 / 英国・シンガポール・インド・東南アジア・中東・アフリカ・ノルウェーなど（既定）と香港・台湾・韓国・ブラジル・メキシコ・スイスなど（追加）、**EU の 19 か国（既定）と残りの 8 か国（追加）** / 豪州・NZ / カナダ | en-US を書き、他の 3 つは同じ（`docs/store/locales.json` に写しの対応） |
| zh-Hans / zh-Hant / ko | 中国本土・シンガポール / 台湾・香港・マカオ / 韓国 | それぞれ |
| fr-FR / fr-CA | **フランス（既定）**・ベルギーとルクセンブルク（追加）・スイス（追加）・アフリカの 3 か国（既定） / カナダ | fr-FR をフランスの書き方で書き、fr-CA は同じ |
| de-DE / it | **ドイツ・オーストリア（既定）**・ルクセンブルク（追加）・スイス（既定） / **イタリア（既定）**・スイス（追加） | それぞれ。de は標準のドイツ語（ß を使う。`docs/store/README.md` の「ß を使わず ss」をやめる）、it は標準のイタリア語 |
| pt-BR / es-MX | ブラジル / メキシコ・中南米・米国（追加） | それぞれ |
| **es-ES / pt-PT（第 4 版で足す）** | スペイン（既定） / ポルトガル（既定） | es-ES は X が es-MX から直す。pt-PT は X が別に書く（語が多く違う）。**画面はブラジルのポルトガル語**であることを説明に正直に書く（§11.2） |

- 各ロケールのファイル: `docs/store/<コード>/name.txt`（第 1 案と退き先 2 つを 1 行ずつ。各 2〜30 字）・`subtitle.txt`（30 字）・`keywords.txt`（100 バイト）・`promo.txt`（170 字）・`description.txt`（4000 字。**利用規約の URL と Apple 標準 EULA の URL を入れる**）・`whatsnew.txt`（4000 字）・`urls.txt`（サポート URL とプライバシーポリシー URL の 2 行）。**URL は 0-38 の規則**: 1.2 は、ja も他の言語も、説明の利用規約の URL・サポート・プライバシーポリシーの URL を全部今の日本語のページにする（英語のページは 1.2 を出す日に公開するので、審査の間はまだ無い。L-9 が `englishPagesPublished` と照らす）。1.2 を出した日に英語のページを公開した後、Connect の欄でそのとき直せるもの（どれが直せるかはリードがそのとき Connect で確かめる）は、本人に「この URL に替えてよいか」を聞いて「はい」なら英語のページに替える。説明は版を出した後に直せないので、説明の利用規約の URL を英語のページにするのは 1.3 の説明から（M7B.md に書く）。
- 名前（M7B-1）: 第 1 案と退き先 2 つを各言語で用意し、Connect が重複で拒んだら順に使う（ログインしないと確かめられないため。M6-25 と同じ方式。拒まれたときは確かめなしで使うので、3 つとも §8 の 11 の確認表で本人に見せる）。英語の既定は「Tegaki Calendar」→「Tegaki: Handwritten Planner」→「Tegaki – Ink on Your Calendar」。他の言語は「Tegaki ＋ その言語の説明の語」（例 zh-Hant「Tegaki 手寫行事曆」）を A が作り、R が逆に訳す。どれにも Apple の商標を入れない（1.0 は 5.2.5 で差し戻された）。
- サブスクリプション: `docs/store/subscriptions/<コード>.json`（月額・年額の表示名 2〜30 字・説明 45 字、グループの表示名）。**他の言語では説明に価格を書かない**（今の年額の説明「月あたり 200 円・4 か月分お得」は円の額なので訳せない。日本語は今のまま、M7B-16）。「4 か月分」もユーロでは 2 か月分なので書かない（§11）。`Support/Products.storekit` に en_US の localizations を足す（S）。表示名・説明・グループの表示名は §8 の 11 の確認表に載せる。
- 審査メモ（`docs/store/review-note.txt`、1 つ、4000 字以内、英語が主で日本語の要約を添える）: UI が 10 言語になり端末の言語に従うこと（未対応は英語）、「設定」アプリの言語の項目、祝日（既定は端末の地域、設定 › 祝日、州・なし、データは同梱で通信しない → App Privacy は「収集なし」のまま）、購読の商品と価格は変わらないこと、購入画面の開き方と復元・規約・プライバシー・EULA の場所、サインイン不要。審査の端末は英語・米国の店頭の見込みなので、英語の画面で購入の流れが途切れないことを TestFlight で確かめておく（§8 の 9 の手順 6）。1.1 から、審査の端末（sandbox のレシートのビルド）では 設定 › 情報 の「バージョン」を長押しすると、開発者に送るための動作の記録（「記録」。日本語の画面。道具・ページの種類・本数・触れ方の種類と時刻だけで、書いた中身・日付・個人の情報は無い。App Store のビルドには出ない）が開くことも 1 文で書く（隠れた機能と見られないように。1.1 の審査メモには無い）。週の始まりの 1 文を足し（§10.4）、EU の文は足さない（§11.3）。4,000 字（バイト）の上限に近いので A の測り方で測る。本人の名で Apple に出す文なので、§8 の 11 の確認表に R の逆翻訳の全文と日本語の要約を載せる。
- 説明（`description.txt`）の最後の 1 文は、訳が AI によるもので母語の人の確認がまだ無いこと（§6.1。R の逆翻訳の対象）。
- 写真: 掲載写真に購入画面と価格を入れない（2.3.7）。言語別の写真は M7B-5 の既定のとおり上げる（13 インチ iPad と 6.9 インチ iPhone の 01〜04、`store-shots` のジョブで撮る。組と店頭の対応は §7.5。**es-ES・pt-PT にも必ず上げる**（上げないと日本語の写真が出る）。週の並びはその地域の新しい方が見る形、§10.7）。上げるのも §8 の 11 の確認の後（M7B-18 は「はい」）。
- 中国本土（CHN）は計測では AVAILABLE。Apple は本土での配信に ICP の登録を求める方針を出している。zh-Hans を足すと本土から見られやすくなるので M7B-12 は既定の「今のまま」で確定（何もしなければ今のまま中国本土でも配信され、Apple から登録番号を求められたら配信の国から中国本土を外せば済む。他の国には響かない）。

### 6.7 サポートの返事の流れ（A が `docs/support-replies/` に定型文、本人の手順は SUPPORT と M7B.md に）

英語などのメールが届く → 本人が Claude に「訳して」と頼む → Claude が日本語訳と要点を出す → 本人が返事の中身を日本語で決める → Claude が相手の言語の返事と逆翻訳（日本語）を付けて Gmail の **下書き** を作る → 本人が逆翻訳を読み、自分で送る（Claude は送らない）。定型文（解約・返金・復元・言語・祝日の誤り・訳の誤りと、第 4 版の「自分の情報を見せて・消して」`privacy-request.md`。`refund.md` に EU の段落、§11.3）は英文と逆翻訳の組で用意する。この流れでは本文が Claude との会話と Gmail の下書きにも残るので、問い合わせが解決したら消す（§11.3 の P-2 の約束。§12.4 の (11)）。祝日の誤りは「python-holidays に報告する／次の版で直す」の判断表を付ける。

### 6.8 版の順番の書き直し（C、`docs/M7_PLAN.md`。B の答え（2026-11-01）の順）

- **新しい順**（0-27）と、前の計画（M7_PLAN の今の §0・§4 の表）との対応:

| 新しい版 | 中身 | 前の計画での版 | 目安の時期 |
| --- | --- | --- | --- |
| 1.1.1 | 上の空白・大きさの直し・メモ欄の全開・ピンチの案内・「今日」を右へ（別の契約。2026-11-04 の本人の決定） | 新しく入る | 2026 年 11 月に提出 |
| 1.2 | 世界対応（この契約。週の始まりと EU での販売を含む） | 新しく入る | 1.1.1 の後 |
| 1.3 | 横につなげる B-1（土台 ＋ 週・日）。段 0（紙の外の点を切らない約束・はみ出す線の fixture・予定の行き先を「ページ・マス」で受ける口・取り消しの組）を含む | 前の 1.6「計画の紙」（項目 4）を B_DESIGN の形に置き換えた最初の段 | 2026 年 12 月〜2027 年 2 月（年末年始は審査が遅れうる） |
| 1.4 | 新しい開発環境（Xcode 27）と iPhone Duo（機能は足さない）。1.3 の横つなぎ（週・日）を、Xcode 27 の SDK と Duo の幅（開閉で変わる）で確かめ直す分を含む（ウでは B-1 を今の Xcode で作るので、B_DESIGN §9.2 のアの理由 3 の裏返しになる） | 前の 1.3 | **遅くとも 2027-03-15 に提出**（2027 年 4 月から Duo の写真と最新の SDK が求められる見込み、M7_PLAN §6.2） |
| 1.5 | 指で予定（週・日・メニュー・読み上げ・手のひら対策） | 前の 1.2 | 2027 年 4〜5 月 |
| 1.5.1 | 月のページで予定を動かす・手書きも一緒に | 前の 1.2.1 | 5 月 |
| 1.6 | 横につなげる B-3（月） | 前の 1.6 の続き（P-B2 が月なので年より先） | 6 月 |
| 1.7 | 横につなげる B-2（年） | 同上 | 7 月 |
| 1.8 | 重点欄（年・月。月に年の重点を表示） | 前の 1.4 | 8 月 |
| 1.9 | 書ける終日欄・今週の重点・終日帯のドラッグ | 前の 1.5 | 9〜10 月 |

- **規則**: **B-1（横につなげる・週・日）を 2027-02-15 までに提出できなければ、Xcode 27・iPhone Duo の版を先に出す**。そのときは Duo の版が 1.3、B-1 が 1.4 になる（App Store は前に出した版より小さい番号を受け付けないので、番号は出す順に付ける。入れ替わるのはこの 2 つだけで、1.5 指で予定 から後は変わらない。B-1 は Xcode 27 で作り、Duo の幅でも確かめる）。0-27 と M7_PLAN の §4 の表の注にも同じ文を、中身の名前で書く（番号だけで書くと、2 月に番号を付け直したときに本人への報告と計画が食い違う）。2/15 の判断の見積もりには、1.3 の訳・逆翻訳・15 ロケールの新機能の文・確認表の分も入れる（下の「次の版の訳とストアの分」）。B_DESIGN §8 の見本の画像と試作版は、1.2 の後、B-1 を作り始める前に本人に見てもらう。
- **C が M7_PLAN で直す所**: §0 の表と §4 の表（:503-512）に 1.2「世界対応」の行を足し、版の番号と順を上の表に合わせる（§0 の「時期（版）」の列と「全体の推奨（5 行）」の版の番号も）。§4.3〜§4.8 の見出しと本文の版の番号（§4.3 の 1.2 → 1.5、§4.4 の 1.2.1 → 1.5.1、§4.5 の 1.3 → 1.4、§4.6 の 1.4 → 1.8、§4.7 の 1.5 → 1.9、§4.8 の 1.6「計画の紙」→「横につなげる（1.3・1.6・1.7）」。節の並びは変えず、版の順は §4 の表で示す）、§3 の表の「版」の列、§2・§5・§6 の本文の版の番号（「1.2 で」→「1.5 で」など）。前の版の番号を書いた所は「（計画の第 2 版では 1.2）」のように残す。§4 の共通の「手書きのデータに触れる版（1.1・1.2・1.2.1・1.4・1.5・1.6）」（:518）は（1.1・1.3・1.5・1.5.1・1.6・1.7・1.8・1.9）に、「1.2 は 12 月 20 日ごろまでに提出したい」（:521）は「1.3 は年末年始をまたぐ（審査が遅れうる）」に。§4.6（新しい 1.8）の「本人の年のページの線の数を読んでもらう」に、1.1 の答え「今年の年のページ 155 本」（M7A.md:499）を書き添える。
- **順の文も直す**（番号の付け替えだけでは直らない所。見直しで足した）: 全体の推奨（5 行）の 3 行目（「本人がいま一番進めたい『指で予定』（11）は 1.2 で単独に」）と 5 行目（「重点欄 2・9 → 書ける終日欄 1 → 計画の紙 4 は 1.4 以降に…（順番は P-12）」、:36）を、新しい順の文にする（3 行目: 「指で予定」は 1.5、月のページは 1.5.1。5 行目: 横につなげる（B）の週・日を 1.3、月を 1.6、年を 1.7、その後に重点欄 1.8・書ける終日欄 1.9。どれも 1.0 の端末の手書きを動かさない・消さない）。§4 の「1.4 以降の順番は P-12 で変わります」（:514）と §5 の P-12 に「2026-11-01 の B の答え（P-B1 ウ・P-B2 月）で順が決まったので、P-12 は使わない」と書く。§0 の番号 4 の行（推奨の欄）・§3 の表の H の行（:482）・§4.8 の頭・§5 の P-9 に、次の 1 行を入れる:「本人の答えは B（2026-11-01）。この行・節の中身は A 案（計画の紙）のまま残し、1.3 の契約で B_DESIGN に差し替える。それまでは §4 の表と B_DESIGN.md が優先」。§4.5（新しい 1.4）の規模（約 0.8〜1）に、1.3 の横つなぎを Xcode 27・Duo で確かめ直す分を足す（数字はリードが B_DESIGN §10 から見積もる）。§4 の表の注に上の規則（2/15）を中身の名前で書く。
- **次の版の訳とストアの分**（見直しで足した）: 1.2 の後はどの版でも、新しい文の 9 言語の訳と逆翻訳、15 ロケールの新機能の文（Connect は更新のたびに各ロケールの新機能の文を求める）、§8 の 11 の確認表が要る。1.3 以降の各版の見積もりにこの分を入れ、2/15 の判断にも含める（目安はリードが 1.2 の実績から M7B.md に書く）。M7B-18 の「はい」は 1.2 の入力の分で、次の版のストアへの入力は、そのたびに確認表を見せて聞く。B の試作の枝（B_DESIGN §8.2）でも lint L-1 が走るので、試作の文をキーにするか枝だけの例外にするかを、1.3 の前に決める。
- **B の P-B9**（設定 › 情報 の 2 行「いちばん線の多いページ」「今年の年のページ」の本数を iPad と iPhone で。もう 1 台を古い版のまま使う期間）は答えが無い（1.1 でもらったのは「今年の年のページ 155 本」だけ、M7A.md:499）。B-1 は 1.2 のすぐ後の版で、窓に描ける線の数の上限の目安にこの数字が要るので、1.2 の TestFlight の確かめ（§8 の 9 の手順 13）で聞き、M7B.md と 1.3 の契約に書く。
- §1.3 の K-9 の後に「1.2 は既存の手書きのデータを変えない（M7B_CONTRACT §1）」の注記と **K-11 の全文**（§1.2）、§1.2 の表に「表示は日本語だけ → 10 言語（O-1）」「週は月曜始まりだけ → 月曜と日曜から選べる（O-2）」の行、1.2 の行に「EU でも売る（O-4）」。
- **第 4 版で足す注**（C）: B の版（1.3）に §10.6 の表のこと。1.3 の契約で「主言語を en-US に替える案」と「オランダ・スウェーデンの nl-NL・sv」（§11.2）を扱うこと。**2027 年 12 月より前の版の契約で CRA を見直すこと**（§11.6。実質的な変更をする版から文書づくりと CE マーク（EU の決まりに合うと自分で宣言する印）の自己宣言が要る見込み）。1.3 以降の確認表は 15 ロケール。
- **1.2 ではしないこと**: B_DESIGN §13 のほかの差し替え（§0 の番号 4 の行の中身・§1.2 の「1 ページ 1 キャンバス 1 台帳」・K-10・§2.4・§3 の重なり・§4.8 の中身・§5 の P-9）と、凍結した Ink の 6 件の扱い（キーに移すか例外のまま残すか、0-37）は 1.3 の契約で行う。1.2 では上の 1 行（§0 の番号 4・§3 の H・§4.8 の頭・§5 の P-9）だけ。`docs/B_DESIGN.md` を repo に入れるかはリードが決める（今は控え `/Users/ikedamasataka/.claude/projects/-Users-ikedamasataka-Documents-Codex/b10c2ae9-5535-4dd5-97f2-2e5ca034309a/span-backup/B_DESIGN.md` にしか無い。入れるなら C が本文を変えずに写し、先頭に読み替えの表を 1 つだけ足す。本文の版の番号と時期は推奨のアで書かれている（B_DESIGN:8）ので、読み替えは: B-1 週・日 1.5 → 1.3、B-3 月 1.7 → 1.6、B-2 年 1.6 → 1.7、指で予定 1.3・1.3.1 → 1.5・1.5.1、Duo 1.4 は同じ、見本の画像と試作版（「1.4 の頃」「1.4 から分けたブランチ」「1.4 の審査待ちの間（2027 年 3 月）」、§0・§12 の「2027 年 3 月ごろ」）→ 1.2 の後・B-1 を作り始める前、「1.1 のままの道」→「1.2 のままの道」。試作の TestFlight は版の番号を 1.3 にして、1.2 の審査の build と取り違えないようにする。写すのを 1.3 の契約まで待ってもよい）。

## 7. テスト・CI・写真

### 7.1 KitChecks（K が main.swift、H が HolidayChecks.swift。「compat with 1.0 (K-7)」の節の後、Summary の前に、この順）

- `section("languages (1.2)")`: `UILanguage.resolve` の 30 通り（§0 の名前と、"pt_PT"・"ZH-hant-hk"・"th"・"ar"・nil・空）、`pluralCategory` の 10 言語 × 0・1・2・5・21、`locale(region:)`、`isCJK`。
- `section("kit strings (1.2)")`: `KitStrings.keys` の全キー × 10 言語が空でない、埋め込みの数がそろう、`format` の順番（`%2$@ %1$@`）、`plural` の one/other、無いキー → キー、無い言語 → en。
- `section("date text (1.2)")`: **J-3**（`Text11` との一致。関数ごと・10 年ごとに 1 件と数える）、en_US・de_DE・fr_CH・pt_BR・zh_TW・ko_KR の見本（§3.1 の例の字）、和暦・仏暦の地域でも西暦（th_TH → 2026）、`mondayFirst`、§3.3 の表、`number`（ja 12,345・de 12.345・fr 12 345）、`yearTitle` に区切りが無い。
- `section("holidays (1.2)")`（H）: **J-5**（2000〜2099 年、年ごとに 1 件）、`JP.json` の日付が JapaneseHolidays と 1,773 日一致し名前の違いが 2 件だけ（2019-05-01「即位の日」/「天皇の即位の日」、2019-10-22「即位礼正殿の儀」/「即位礼正殿の儀が行われる日」）、橋で ja の列が選ばれたとき（ja・zh-Hans・zh-Hant・ko の画面）の名前が JapaneseHolidays と同じ（zh-Hans の画面で 2019-05-01「即位の日」）、§7.2 の答えの分かっている日、249 ファイルが読めて §5.3 の検査を通る・`SOURCE.json` の sha256 と一致・"UK" が無い、異常な入力 16 通り（第 1 版の 12 通りに `"-"`・`"US-"`・`"-CA"`・`"US--CA"`）、`HolidaySetting` の往復 12 通り（第 1 版の 8 通りに "NZ-South Canterbury"・"AR-C"・"AT-9"・"FR-971"。小文字で渡した "nz-south canterbury" も `canonical` でデータの表記に戻る）、名前の言語の例 6 通り（§5.5）、同じ日の 2 つ（韓国 2025-05-05）と州を足した日の並び（国の祝日が先。ボスニア・ヘルツェゴビナ SRP 2061-05-01）、`short`（米国 2026-07-03「Independence Day」）、workday（中国 2024-02-04 が出勤日）、振り替え休日の型（中国 2025-02-03 の zh-Hans の full「休息日（2025-01-26日起取代）」・short「休息日」、en の full「Day off (substituted from 01/26/2025)」・short「Day off」）、推定の印（版で動く: 0.83 ではアラブ首長国連邦 2026-03-20 の en の full が「Eid al-Fitr」＋印、short が「Eid al-Fitr」。新しい版でその日が推定でなくなっていれば、H が推定の付く別の日を選ぶ）、**発表前の年**（版で動く: CN の `lastOfficialYear` ＋ 1 の年（0.83 では 2026）の `note` が `.beforeNotice`、その年に規則で作った「（观察日）」の日（0.83 の 2026 年なら 10/5・5/4・4/6）が祝日でない、国慶節の 10/1 の flags に estimated。TW の `lastOfficialYear` ＋ 1 の年は `.beforeNotice` で flags はそのまま）、**範囲**（版で動く: H が新しい版で測った `coverage` の外の年（0.83 では LK の 2026 年・UA の 2023 年）が `.incomplete`、JP・US の 2026 年は nil）、**flags の振替**（observed の付く名前が全体の 50% を超える国が無い。JP.json で observed が付く名前は無いか「振替休日」だけ）、**州**（全国と差の無い州が index に無い。ノルウェーは州が 0。NZ-AUK の `display` が「Auckland」、CA-NS が「Nova Scotia」、FR-971 が「Guadeloupe」、DE-Augsburg の `local` が true）、`HolidayDataLicense.mitText` が LICENSE-python-holidays.txt と同じ、販売中の 174 の国・地域（EU の 27 か国を足した数）の `lastOfficialYear`・`notice`・`coverage` の一覧を書き出す（数えない）。
- `section("holiday geometry (1.2)")`（K）: **G-1** 2026 年の月 12・週 53・日 365・年 1 を、`.japan`・米国カリフォルニア州（en）・`.none`・作り物の暦（毎日が 40 字の祝日で、全部の週末が出勤日）で組み、全ページで tone と名前以外の全部（cells・rows・bars・chips の frame・dateLabels の frame・memo・extra・size・hit の結果を表の点で）が `.japan` とビット単位で同じ。**G-2** `LayoutWords.japanese` と `.of(.de)` で同じ（違うのはチップの字だけ）。**G-3** 入力の `calendar` の locale を en_US・de_DE、firstWeekday を 1・2・7 に変えても同じ。**G-4 渡し漏れ**（第 2 版）: 作り物の暦「X」（2000〜2099 年の毎日が祝日「X」、全部の週末が出勤日）を入力に渡して 4 種類のページ（2026 年の 11 月を含む月・週・日・年）を組み、`dateLabels` の tone と名前、`band.tones`（週と日）、年のマスの名前、`PageNavigation.title(.day, focus:, holidays: X)` の祝日名、`AppExport.pdfFileName(kind: .day, focus:, holidays: X, language: .ja)` が **全部 X から来ている**こと（名前は全部「X」、tone は全部 `.sundayOrHoliday`。`.japan` の 11/3・11/23 の名前が 1 つでも残れば失敗）。同じことを `.none` でも（名前が 1 つも無く、tone は土曜 `.saturday`・日曜 `.sundayOrHoliday`・他 `.normal`）。**作り物の暦「W」**（見直しで足した。祝日が 1 つも無く、全部の週末が出勤日）でも 4 種類のページを組み、`dateLabels` の tone と週・日の `band.tones` が全部 `.normal`（workday の渡し漏れ。X は毎日が祝日なので赤が先に決まり、これを見つけられない）。見込み +1,900〜2,200 件（W の分は除く。実数は K が M7B.md に）。
- `section("week start (1.2)")`（K2。第 4 版）: §10.8 の W-1〜W-5・G-5。
- **閾値の規則**: K が 1.2 の実数 N を docs/M7B.md に書き、C が **N − 50** を `build.yml:82-89`（KitChecks の段。数の内訳のコメントは :76-81）に入れる（1.1 の実数は b13fa91 と e7b4d2f で同じ 24,446、閾値は今 24,396。この Mac で git archive で取り出した e7b4d2f の TegakiKit は「all 24446 checks passed」・compat10 361 件、2026-11-01）。M7B-10 の新しい版で祝日の節の件数が動いても、N − 50 の規則のまま。1.1.1 の取り込みで土台の数も動くので（§1.5）、N は取り込みの後に数える。

### 7.2 XCTest（役割ごと。名前は固定）

| 担当 | ファイル | テスト |
| --- | --- | --- |
| H | `Tests/HolidaysTests/WorldHolidaysTests.swift`（新規） | `testJapanIsJapaneseHolidaysFrom2000To2099`、`testJapanDataMatchesJapaneseHolidaysDates`、`testKnownDates`（米国 2026-07-03 Independence Day (observed)・2026-11-26 Thanksgiving Day／ドイツ・バイエルン 2026-01-06 Heilige Drei Könige（全国では無し）／英国・スコットランド 2026-01-02 New Year Holiday・2026-08-03 Summer Bank Holiday／英国・イングランド 2026-08-31 Late Summer Bank Holiday／韓国 2026-02-17 설날・2026-09-25 추석（en は Chuseok）／台湾 2026-10-09 國慶日（補假）・2026-10-10 國慶日／ブラジル 2026-04-21 Tiradentes・2026-11-20 Dia Nacional de Zumbi e da Consciência Negra／ブラジル・サンパウロ 2026-07-09 Revolução Constitucionalista／スイス・チューリッヒ 2026-04-06 Ostermontag（fr は Lundi de Pâques）／中国の振替休日 2025-02-03（full「休息日（2025-01-26日起取代）」・short「休息日」）／アラブ首長国連邦 2026-03-20 Eid al-Fitr（en の full に推定の印、short に無い。版で動く: 新しい版で推定でなければ H が別の日を選ぶ）／米国・カリフォルニア州 2026-10-12 は祝日なし（全国では Columbus Day）・2026-11-27 Day After Thanksgiving）、`testSubdivisionAddsAndRemoves`（国の祝日が先、州の祝日が後の順が `HolidayEntry.isSubdivision` で守られる）、`testTwoHolidaysOnOneDayAreJoined`、`testWorkdays`、`testNoneIsEmpty`、`testBadInputNeverCrashes`（"-"・"US-"・"-CA"・"US--CA" と、§5.3 の検査に通らない作り物のファイル 8 通り）、`testSettingStorageRoundTrip`（NZ-South Canterbury・AR-C・AT-9・FR-971 を含む）、`testSubdivisionCodesAreMatchedIgnoringCase`、`testAutomaticUsesTheDeviceRegion`、`testUnknownRegionMeansNone`、`testNameLanguageRule`、`testJapanUsesJapaneseHolidaysNamesForTheJaColumn`（zh-Hans の画面で 2019-05-01「即位の日」）、`testShortNamesDropTheObservedSuffix`、`testEstimatedSuffixOnlyInFull`、`testYearNotes`（版で動く: CN の `lastOfficialYear` ＋ 1 の年が `.beforeNotice`・`coverage` の外の年（0.83 では LK 2026）が `.incomplete`・JP nil）、`testSubdivisionDisplayNames`（NZ-AUK Auckland・CA-NS Nova Scotia・FR-971 Guadeloupe）、`testEveryCountryFileParses`、`testSourceDigests`、`testStoreWithoutADirectory`。答えの分かっている日のうち新しい版で変わったものは、H が新しい版の値に直して理由を M7B.md に（日本の日は JapaneseHolidays なので変わらない） |
| K | `Tests/HolidaysTests/HolidayGeometryTests.swift`（新規。置き場所は §0） | `testPaperGeometryIgnoresHolidays`、`testPaperGeometryIgnoresWords`、`testDeviceCalendarLocaleDoesNotMoveCells`、`testWorkdayToneIsNormal`（中国（zh-Hans）の暦で、祝日でない出勤日の 2024-02-04（日曜）と 2024-05-11（土曜）が、月（2024 年 2 月・5 月）・週・日・年（2024 年）の `dateLabels` の tone と、週・日の `band.tones` で全部 `.normal`。月のエンジンの tone（§5.4 の表の 12）の渡し漏れもこれで見つかる）、**`testBandTonesFollowTheHolidays`**（米国（en）の 2026-11-23 の週と 2026-11-26 の日で `band.tones` が `dateLabels` の tone と同じで、11/26 の列が `.sundayOrHoliday`、11/23 の列が `.normal`。`.none` では `band.tones` が土曜 `.saturday`・日曜 `.sundayOrHoliday`・他 `.normal`）、`testHolidaysReachEveryPage`（G-4 の見本を XCTest でも 1 週・1 日） |
| K | `Tests/LayoutTests/DateTextTests.swift`・`KitStringsTests.swift`・`LayoutWordsTests.swift`（新規） | `testJapaneseSamplesAreTheOneOneText`（1.1 の字を直書きした 40 の見本。年をまたぐ週 3 つを含む。全範囲の一致は KitChecks の J-3。`Text11` は KitChecks の中にあり XCTest からは見えない）、`testEnglishSamples`、`testGregorianIsFixed`、`testMondayFirst`、`testWeekdayLetterTable`、`testNumbers`、`testYearHasNoGrouping`、`testEveryKeyHasTenLanguages`、`testPluralCategories`、`testFormatPlaceholders`、`testMoreChipsPerLanguage`、`testTimeRangeSeparators` |
| K | `PageNavigationTests.swift`・`Tests/AccessTests/PlanTextTests.swift`・`LegalLinksTests.swift`（新規）・`Tests/InkModelTests/StrokeBudgetTests.swift`・`AppExportTests.swift` | 既存の日本語の期待は **変えない**（J-2）。新規 `testTitlesInEnglish`、`testHolidayInTheDayTitle`（米国 2026-11-26 → "Thu, November 26, 2026 Thanksgiving Day"）、`testPlanTextInEnglish`（「/month」「/year」「Save 4 months」の型）、`testEuroSavings`（1.99 / 17.99 で 2 か月分。§11）、`testURLsPerLanguage`（published false → 全言語で今の ja の URL、true → ja 以外は `app/en/…`。th の画面は en なので en の URL）、`testCountTextInGerman`、`testPdfFileNameInEnglish` |
| S | `Tests/TegakiCalendarTests/LocalizationBundleTests.swift`（新規） | `testEveryLanguageBundleHasEveryKey`（ホストの bundle の 10 の `.lproj` で、元の全キーがキーそのものでない値を返す）、`testInfoPlistIsLocalized`（10 の `InfoPlist.strings` に 2 キー）、`testJapaneseMatchesTheOneOneBaseline`（`#filePath` から `tools/l10n/ja-baseline.tsv` と元を読み、単純なキーの ja.lproj の値が 1.1 の文字列と同じ）、`testNoRightToLeftLocalization` |
| S | `L10nTests.swift`・`EventDateTextTests.swift`（新規） | `testMissingKeyFallsBackToEnglish`、`testPluralPicksOneOrOther`、`testFormatReplacesInOrder`、`testJapaneseEventTextIsUnchanged`（2026 年の全日付 × 時刻 6 通りで 1.1 の 3 つの DateFormatter の写しと同じ）、`testEnglishEventText` |
| S | `StoreKitSessionTests.swift` に 1 本 | `testUSStorefrontPrices`（`SKTestSession` を storefront "USA"・locale en_US で: $1.99/month、$14.99/year、月あたり $1.25、4 か月分お得（floor(12 − 14.99/1.99) = 4））。CI で skip のままなら M7B.md に書く |
| S | `ToolbarFitTests.swift`（新規。シミュレータの UIFont で、`L.text(_, in:)` の 10 言語を測る。§4.4） | `testToolLabelsFitInEveryLanguage`（F-12。10 pt で 38 pt を超えた名前は一覧に出し、47.5 pt を超えたら失敗）、`testRowKeepsWhatOneOneShowedInEveryLanguage`（`testRowWinsBackTheCollapseButton` の 4 つの式を、測った幅で言語ごとに確かめる。F-12 の作りでは、言語で変わるのは 13 インチの式の「指でも書く」だけ）、`testFingerToggleFitsTheThirteenInchRow`（F-13）、`testHintsAreAtMostTwoLinesAndFit`（F-14。改行は 1 つまで、各行がそのキーの ja のいちばん長い行以内）、`testEraserHintsShareTheFirstLine`、`testJapaneseToolbarTakesTheOneOnePath`（`labelFrameWidth(for: .ja)` が nil、ほかの 9 言語は 38）、**`testSelectionMenuFitsTheNarrowestIPhone`**（§4.5 の F-15。14 pt（1 つ目は semibold）で、投げなわのメニューの 3 つの訳の幅の合計が 10 言語とも 220 pt 以下。超えた言語と幅を一覧に出して失敗）。既存の `ToolbarLogicTests` の 2 本（`testBarHintsAreTheOneLineSentencesOnTwoLines`・`testRowWinsBackTheCollapseButton`）と `CalendarRootScreenTests.testEraserReturnTarget` は期待を変えない（J-2） |
| P | `PaperFitTests.swift`（新規。シミュレータの UIKit で測る） | `testYearWeekdaysFitInEveryLanguage`（F-1。率 ≥ 0.7 で切れない）、`testMemoLabelsFit`（F-6）、`testMoreChipsFit`（F-5、+99）、`testAllDayLabelChoice`（F-7、10 言語 × 週・日 × iPhone 全幅・読める倍率・iPad 縦）、`testMonthHeaderWeekdaysFit`（F-8）、`testYearMonthTitlesScale`（F-8 の率と数字への切り替え）、`testJapaneseTakesTheOneOnePath`（ja では F-1 の曜日の記号・F-2・F-3・F-7・F-8・F-10・F-11 が 1.1 のコードの道（今の枠・`drawLine`・今の修飾子）を通り、F-1 の数字の枠の右端が 1.1 と同じ `frame.minX + pad + 1.3 em`。絵が同じことは J-4 の写真の比較で見る）、**`testHeaderPickerAndTodayFit`**（§4.5 の F-16。10 言語で、見出しの切り替えの 4 つが 13 pt の semibold で 44 pt 以内、「今日」が 17 pt で ja の幅 ＋ 16 pt 以内） |
| U | `HolidayChoiceTests.swift`（新規） | `testExistingUserKeepsJapan`（3 つのキーのどれかがあれば "JP"）、`testNewUserIsAutomatic`（"auto" が書かれる）、**`testNewUserStaysAutomaticOnSecondLaunch`**（§1.4）、`testMigrationRunsOnce`、`testSummaryTexts`（§5.7 の 10 の形。米国・California、カナダの全国共通のみ、スリランカの 2026 年、中国の 2026 年（版で動く: 年は新しい版の `coverage` の外の年と `lastOfficialYear` ＋ 1 の年にする）、読めないファイルを含む）、`testCalendarFollowsTheSetting`、`testAutomaticDoesNotReadTheIndex`（自動で端末の地域が US のとき index を読まない） |
| U | `SettingsScreenTests.swift`・`ScreenshotModeTests.swift`・`EventKitServiceTests.swift`・`CalendarRootScreenTests.swift` | 既存の期待は変えない。新規 `testHolidaySectionTexts`、`testParseHolidays`（auto・none・JP・US-CA・壊れた値 → JP）、`Sheet.allCases.count` を 11 に・rawValue の一覧の最後に `"holidays"` と `"week-start"`、**`testDemoInkIsTheSameInEveryLanguage`**（10 言語で `demoEvents(for:language:)` を作っても、見本のページ `demoPage(kind:focus:grown:)` の JSON が `screenshot-*.json` と 1 バイトも違わない。K-7）、`testDemoTitlesExistInEveryLanguage`（`demoEvents(for:language:)` と `calendarTitle(forCalendarId:language:)` を 10 言語で）、`testHolidayCalendarWords`（「日本の祝日」「US Holidays」「Feiertage in Deutschland」「Jours fériés」「대한민국 공휴일」「中国节假日」→ 隠す、「仕事」→ 隠さない）、`testHolidayChangeKeepsTheGeometry`、**`testPaperUsesOneHolidayCalendar`**（`CalendarRootScreenTests`。`makePaper(…, holidays:)` に米国（en）の暦を渡すと、月の `labels` の `holidayName` と `holidayNames` がどちらもその暦の名前で、日本の名前が 1 つも無い。§5.6）、`testTimeTextHasDateAndTime`（`SettingsScreen.timeText` に時刻がある。ja_JP で `:` を含む）、**`testEraserFooterNeverNamesThePencilOnAnIPhone`**（`SettingsScreenTests`。10 言語で、`settings.input.eraserAutoReturn.footer.phone` に「Apple Pencil」「iPad」が無く、`.footer.pad` には「Apple Pencil」がある。§5.7）、`ScreenshotModeTests.testParseProbeAndSelect`（:448-）の「他は変わらない」の比較に `holidays` と `weekStart` を 1 行ずつ足す（今の行は消さない） |
| K2・U・P・S2 | §10.8 の表 | 週の始まりのテストの全部（名前は §10.8 で固定） |

### 7.3 UI テスト（U。iPhone 17、`TegakiCalendarUITests`、ジョブを落とす）

- `YearTapUITests.swift:67-73` と、1.1 の後半（cdf3470〜5c98a19）で入った **`EraserAndBelowDayUITests.swift`（868 行・8 本）の `launchApp`（:311-323）の `app.launchArguments`（:314-319）** の両方に、`"-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"` を足す（中身は変えない。行を足すだけにして、日本語のコメントの行 :69-70・:316-317 は書き換えない。書き換えると J-2 の「削除行に日本語が無い」に引っかかる）。EraserAndBelowDayUITests は部品を日本語の名前で探している（:47-59 の「ペン」「消しゴム」「投げなわ」「予定」「ツールバーを出す」「予定にする」「消すとペンに戻ります」「自由メモ欄では予定を作れません」「保存」「キャンセル」、:73-74・:103-104・:608-609 の「赤」「黒」「太さ: 太」「太さ: 中」、:589 の「ツールバーをしまう」、:154 の「丸ボタンの値が『ペン』で始まる」）。1.2 は受け皿が en で CI のシミュレータは英語なので、足さないと 8 本とも英語の画面で動いて落ちる。このテストは J-1 の ja の値を裏から照らす: `ToolbarView.swift:265` の「太さ: %@」、消しゴムの説明の 2 行目（`toolbar.hint.eraser.toPen`）、トースト `eventBelowDayToast`（`CalendarRootScreen.swift:257`）の ja が 1 字でも 1.1 と違うと落ちる。丸ボタンの読み上げの値（「ペン・黒・中」、`ToolbarLogic.swift:203, 206, 209`）は、UI テストは先頭の「ペン」だけを見る（:154）。全部の字は `ToolbarLogicTests.testBadgeForEveryTool`（ja）が見る。**1.1.1 の `HeaderAndPaperUITests`・`BlankPaperShotsUITests` の起動の引数にも同じく足す**（「今日」「次の月」など日本語の名前で探すため、§1.5）。
- `LanguageUITests.swift`（新規）: 起動は `--screenshot-mode --screenshot-month 2026-10 --screenshot-page month` ＋ `-AppleLanguages (<言語>) -AppleLocale <地域>`。写真モードでは画面に読み上げだけの部品（`accessibilityIdentifier("l10n.state")`、名前「ui=<lang>;locale=<id>;holidays=<id>;week=<monday|sunday>」）を U が置く。作り方は §0 のとおり **1×1 pt の `Color.clear` に `.accessibilityElement()`・`.accessibilityIdentifier`・`.accessibilityLabel`**（`.hidden()` と `.opacity(0)` は読み上げの木から消えて XCUITest で見つからないので使わない）。テストは `app.otherElements["l10n.state"]` の `label` を読む。もし見つからなければ、1 pt の透明な `Text`（`staticTexts`）に替えて M7B.md に書く。ペンのボタンに `accessibilityIdentifier("tool.pen")`（S、`ToolbarView`）、題名に `"page.title"`（P、`PageHeaderView`）。LanguageUITests は手順ごとに `l10n UI:` で始まる行を出す（§7.5 の grep）。S が `tool.pen` の識別子を足した後も、YearTapUITests・EraserAndBelowDayUITests の `app.buttons["ペン"]` が見つかることを CI で確かめる（見つからなければ識別子をやめて、LanguageUITests は名前で探す。M7B.md に）。
- この Mac の typecheck.sh（手順 5）は `TegakiCalendarUITests` を `tools/typecheck/XCTestStandIn.swift` の代わりの XCUI で型だけ確かめる。今の代わりにあるのは、`XCUIElement` の `exists`・`frame`・`label`・`value`・`isSelected`・`isHittable`・`waitForExistence(timeout:)`・`coordinate(withNormalizedOffset:)`・`tap()`・`doubleTap()`・`screenshot()`・`descendants(matching:)`・`buttons`・`staticTexts`・`windows`・`scrollViews`（:97-115）、`XCUIElementQuery` の `subscript(key:)`（:118。`query["…"]` で使う。1.0.1 の cb2343a から）・`firstMatch`・`count`・`matching(_:)`・`matching(identifier:)`・`element(boundBy:)`、`XCUIApplication` の `launchArguments`・`launchEnvironment`・`launch()`・`terminate()`（:131）と、1.1 の後半（cdf3470）で入った `XCTExpectFailure`・`XCTAttachment(string:)`・`XCTestCase.wait(for:timeout:)`・`XCTestExpectation`・`XCUIGestureVelocity`・`XCUICoordinate.press` の 3 つの形（:52-95）。**無いのは `XCUIElement.otherElements` と `XCUIElement.identifier` だけ**で、U はこの 2 つを `XCUIElement`（:97-115）に足す（§0）。**同じ形の subscript は足さない**（`invalid redeclaration of 'subscript(_:)'` で手順 5 が落ちる。この Mac の `swiftc -typecheck` で確かめた）。e7b4d2f の typecheck.sh は、この Mac で全部 OK・警告 0（アプリ 59 ファイル、TegakiCalendarTests 26、UI テスト 2）。

| テスト | 起動 | 確かめること |
| --- | --- | --- |
| `testJapaneseStaysJapanese` | (ja) ja_JP | ui=ja、ペンの名前「ペン」、題名「2026年10月」、holidays=JP\|ja |
| `testEnglish` | (en) en_US | ui=en、「Pen」、題名「October 2026」 |
| `testUnsupportedLanguageFallsBackToEnglish` | (th) th_TH | **ui=en**、「Pen」、題名に「2026」があり「2569」が無い |
| `testSecondPreferredLanguageWins` | (ru, ja) ru_RU | ui=ja |
| `testRegionalVariants` | zh-HK・pt-PT・es-MX・es-419・fr-CA・de-CH・it-CH を順に | zh-Hant・pt-BR・es・es・fr・de・it（pt-PT が pt-BR にならなければ 0-2 のとおりリードが決める） |
| `testRightToLeftFallsBackToEnglish` | (ar) ar_SA、(he) he_IL | ui=en |
| `testAutomaticHolidaysFollowTheRegion` | (en) en_US と (ja) ja_JP に `--screenshot-holidays auto` | holidays=US\|en、JP\|ja |
| **`testEveryLanguageIsChosen`**（第 2 版） | (zh-Hans) zh_CN、(ko) ko_KR、(pt-BR) pt_BR、(de) de_DE、(fr) fr_FR、(es) es_ES、(it) it_IT、(zh-Hant) zh_TW、(en-GB) en_GB を順に 9 回 | ui= が順に zh-Hans・ko・pt-BR・de・fr・es・it・zh-Hant・en（`UILanguage.rawValue`）。`.lproj` の名前が少しずれる（`zh_CN`・`ko-KR` など）と、その言語の人に黙って英語が出るので、9 言語の基本の形を全部ジョブを落とすテストで確かめる（`l10n-shots` は落ちない段なので証明にならず、LocalizationBundleTests は `.lproj` の中身を見るだけで iOS がそれを選ぶかは見ない）。1 回 20 秒ほど |
| **`testWeekStartFollowsTheRegion`**（第 4 版） | (en) en_US、(en) en_GB、(ja) ja_JP、(en) en_EG に `--screenshot-week-start auto` | week= が sunday・monday・monday・monday |
| `testWeekStartIsMondayWithoutTheArgument`（第 4 版） | (en) en_US で `--screenshot-week-start` なし | week=monday |

### 7.4 写真モード（U、`Support/ScreenshotMode.swift`）

- `--screenshot-holidays auto|none|<国>[-<州>]` → `Config.holidays`（引数が無い・壊れた値は `.region(JP)`。0-26）。`Config.holidays` は 1.1 の後半（cdf3470）で増えた `probe`（:135）・`select`（:138）の後ろに足す（`parse` の最後の `Config(…, grown:, probe:, select:)`（:198）はそのまま通る）。`--screenshot-holidays` と `--screenshot-probe`・`--screenshot-select` は、組み合わせても互いに影響しない（LanguageUITests は probe を使わない）。
- `--screenshot-sheet holidays` → `Sheet.holidays`（月のページで設定を開き、祝日を選ぶ画面を押した状態。10 個目）。
- 見本の予定（:337-366 の 26 件。題名は 23 種）・予定表の名前（:246-250 の 4 つ）・出どころの名前「見本」（:265）は `demo.*` のキーへ（`ScreenshotMode` の日本語の文字列は全部で 31。`ScreenshotModeTests` が題名で探している所は、写真モードの言語が ja のときの値で探すので変わらない）。関数の形は §0（`demoEvents(for:language:)`・`calendarTitle(forCalendarId:language:)`・`calendarOptions(language:)`。既定は `L.language` で、今の呼び出しは変わらない）。上限: 年のチップ 4.2 em・月のチップ 5.7 em に入る長さ（`maxEm`）。手書きの見本（形だけの線、`demoPage(kind:focus:grown:)`）は言語を受けず、言語で変えない（K-7。`testDemoInkIsTheSameInEveryLanguage`）。
- 写真モードの日は今のまま **毎月 7 日**（`ScreenshotMode.focusDay`、:224。2026-10-07 は水曜で祝日なし）。日のページの写真の題名は、どの言語でも 10 月 7 日（en「Wed, October 7, 2026」）になる。日を変える引数は足さない（祝日の入った日の題名は `testHolidayInTheDayTitle` と月の写真の 10/12 で見る）。
- 言語は `-AppleLanguages` と `-AppleLocale` の起動の引数で決める（アプリの UserDefaults の引数の領域。シミュレータ全体を変えない）。
- `--screenshot-week-start auto|monday|sunday` → `Config.weekStart`、`--screenshot-sheet week-start` → `Sheet.weekStart`（§10.7。第 4 版）。`demoPage` に `weekStart` を渡す（§10.5。既定は月曜で `screenshot-*.json` と 1 バイトも違わない、K-7）。
- **凍結したファイルが読む名前**: U は `ScreenshotMode.current`・`ScreenshotMode.isActive`・`Config.probe`・`Config.today`・`SettingsScreen.versionText` の名前と型を変えない（`Ink/InkCanvasView.swift:659`・`Ink/InkTrace.swift:33, 41`・`Sync/SyncEngine.swift:20-21, 45` が読む。どれも D14 で直せないので、変えると組み立てが落ちる。§0 の接点）。写真モードでは `InkTrace.isAvailable` が偽なので、写真に記録のシートは出ない。

### 7.5 CI（C、`.github/workflows/build.yml` と新しい `store-shots.yml`・`ja-baseline.yml`）

| 場所 | 変更 |
| --- | --- |
| 先頭のコメント :1-28 | 1.2 の 1 文（言語の lint、データの部分の照合、日本語に固定したテスト、言語の UI テスト、`l10n-shots` のジョブ、`ja-baseline.yml`）と、まだ書かれていない 1.1 の後半の分（EraserAndBelowDayUITests と「The unit tests' repro lines」の段） |
| `build-and-test` の `timeout-minutes: 90`（:48。理由のコメント :43-47） | **90 → 110**。コメントの見積もりを 1.1 の後半と 1.2 の数で書き直す: 1.1 の 52 分・56 分の run（UI テストの段は約 4 分だった）に、1.2 で増える段 約 3 分（lint・照合・bundle check・祝日のシート・単体テスト）と、UI テストの段の上限 40 分（下の行）を当てて 56 − 4 + 3 + 40 ≈ 95 分。そこに 15 分の余裕（シミュレータの起動だけで 4 分かかった run がある、:44。ジョブの上限で切られると、後の「Upload screenshots」（`if: always()`）も走らず、J-4 の写真と UI テストの記録がまとめて失われる）。e7b4d2f の CI の実際の時間（M7A.md に無い）をリードが M7B.md の前提に書き、「その時間 − 1.1 の UI テストの段 ＋ 3 ＋ 40 ＋ 10」が 110 を超えるときはその値にする |
| KitChecks :82-89（数の内訳のコメント :76-81） | 閾値を K の実数 − 50 に（今は 24,396）。コメントの内訳に 1.2 の節を足す |
| macOS の段階（「Frozen 1.0 copy」:100-103 の後） | 新しい手順「Localization lint」: `python3 -I tools/l10n/lint.py .`。「Data code frozen since 1.1.1」: `shasum -a 256 -c tools/compat10/DATA_1_1.sha256`（ファイルの名前は変えない、§1.5） |
| 「Install XcodeGen」:105-109・「Generate the Xcode project」:111-115 | `xcodegen --version` は今も出している。生成の後に `knownRegions` を grep して出す（§2.2。M7B.md に記録） |
| 「Build for the iOS Simulator」:117-128 の後 | 「Localized bundle check」: 組み上がった `.app` に `{ja,en,zh-Hans,zh-Hant,ko,fr,de,es,it,pt-BR}.lproj/Localizable.strings`（か `.stringsdict`）と `InfoPlist.strings`、`HolidayData/JP.json`・`US.json`・`index.json`・`SOURCE.json`・`LICENSE-python-holidays.txt`・**`CONTRIBUTORS-python-holidays.txt`** があり、`HolidayData/UK.json`・`ar.lproj`・`he.lproj` が無いこと、`PrivacyInfo.xcprivacy`（`plutil -p` で読む）に `CA92.1` と `35F9.1` があること（違えば失敗。`HolidayData/` が無ければ §2.2 の退き先）。生成されたプロジェクトの `knownRegions` を表示。`git diff --exit-code -- Sources/TegakiCalendar/Resources`（0-5） |
| 「Run unit tests on the simulator」:171-184 | xcodebuild に **`-testLanguage ja -testRegion JP`**。最後の `test 2>&1 \| tee "$RUNNER_TEMP/unit-tests.log"` は残す（`set -euo pipefail` なので、失敗すれば今も段が落ちる） |
| 「The unit tests' repro lines」:186-199（1.1 の後半、eb29163） | 変えない（`repro:` と expected failure の行を 1 回ずつ出す、落ちない段） |
| 13 インチと他機種の写真の全部の `simctl launch`（:352、:364、:371、:384、:404、:529、:538） | 末尾に `-AppleLanguages "(ja)" -AppleLocale ja_JP`（変数 `JA_ARGS` で）。写真の段の最初に `xcodebuild -version` と使ったシミュレータの runtime を `shots/env.txt` に書く（成果物 `screenshots` に入る。J-4 で ja-baseline の `env.txt` と照らす、§1.3）。13 インチのシートのループ（:401）に `holidays` と `week-start` を足し、段の名前（:393）の「9 sheets」を「11 sheets」に、:411 のコメントの「22 shots」を 24 に（1.1.1 の offset の 4 か所と pinch-hint の 2 枚はそのまま。枚数は 1.1.1 の build.yml で数え直す） |
| 「UI tests on an iPhone」:609-632（段の `timeout-minutes: 25` は :610、コメントは :597-608） | `-only-testing:TegakiCalendarUITests` は今のまま（YearTapUITests・EraserAndBelowDayUITests・LanguageUITests、1.1.1 の HeaderAndPaperUITests（約 1 分）と BlankPaperShotsUITests（環境変数が無ければ skip）、第 4 版の WeekStartUITests が走る）。LanguageUITests は「Build the UI tests for an iPhone」:207 で一緒に組み立てる。段はふだん約 7 分（1.1 の後半のコメントの見込み）に LanguageUITests の約 9 分（24 回の起動）が足されて約 16 分になるので、段の上限を **25 → 40 分**にする。:632 の grep に `l10n UI:` を足す。コメント :597-608 に 1.2 の分を書く |
| 新しいジョブ `l10n-shots`（macos-26、`timeout-minutes: 75`、`build-and-test` と並行。写真の段は落とさない） | 組み立て → 13 インチ iPad と iPhone 17。9 言語（en zh-Hans zh-Hant ko fr de es it pt-BR、地域は en_US・zh_CN・zh_TW・ko_KR・fr_FR・de_DE・it_IT・es_MX・pt_BR（第 4 版。fr・de・it の主な読み手がスイスからフランス・ドイツ・イタリアに変わった）、`--screenshot-holidays auto --screenshot-week-start auto`）で 13 インチの月・日、iPhone の週・年（36 枚）。en と de で 13 インチの設定・祝日・購入のシート（6 枚）。de と fr で 13 インチと iPhone の `--screenshot-tool eraser`（4 枚。ツールバーの消しゴムの説明の 2 行と ↶ ↷、§4.4・§8 の 8）。fr と de で iPhone の `--screenshot-sheet lasso`（2 枚。投げなわのメニューの 3 つが画面の中にあるか、§4.5 の F-15・§8 の 8）。見出しの切り替えの字（F-16）は 13 インチの月の写真で見る。**週の始まり**（第 4 版）: en の 13 インチの週と iPhone の月（2 枚。en_US は日曜）、en と de の 13 インチの `--screenshot-sheet week-start`（2 枚）、日本語の日曜（`JA_ARGS` ＋ `--screenshot-week-start sunday`。13 インチと iPhone の月・週、4 枚。フォルダ `ja-sunday`）。合わせて 8 枚増えるので `timeout-minutes` を C が見直す。二倍長: `-AppleLanguages "(en)" -NSDoubleLocalizedStrings YES` で 13 インチと iPhone の月・設定・購入（6 枚）。訳し漏れ: `-NSShowNonLocalizedStrings YES` で 1 回起動し、`log show` で `l10n: missing` と非ローカライズの行を数えて Job Summary に（0 件が期待。0 でなければ警告）。**範囲**: 二倍長と訳し漏れの 2 つは Bundle から引くアプリの文字（Localizable）だけに効く。KitStrings（Swift の表）を通る字（題名・PlanText の「/年」と状態・終日・+n件・線の数・祝日の印）は伸びず記録にも出ないので、Kit の字の長さは P の `PaperFitTests` と L-12、漏れは L-2 と `KitStringsTests` で見る。成果物 `l10n-screenshots`（7 日） |
| 新しい `store-shots.yml`（`on: push` でブランチ `store-shots` だけ、と `workflow_dispatch`。matrix で 11 組） | **組と地域とロケールの対応**（第 4 版。全部 `--screenshot-holidays auto --screenshot-week-start auto`）: en（en_US。en-US・en-CA に）、en-GB（en_GB。en-GB・en-AU に）、zh-Hans（zh_CN）、zh-Hant（zh_TW）、ko（ko_KR）、fr（fr_FR。fr-FR・fr-CA に。fr-CA は日曜の地域だが同じ写真）、de（de_DE）、it（it_IT）、es（es_MX。es-MX に）、es-ES（es_ES。es-ES に）、pt-BR（pt_BR。pt-BR・pt-PT に）。組ごとに組み立て、13 インチの 01-month・02-week・03-day・04-year と 6.9 インチ iPhone の 01-week・02-month・03-day・04-year を JPEG に（今の「Store listing set」の `store()` と同じ大きさの確かめ）。**購入画面は撮らない**。成果物 `store-<組>`。workflow_dispatch は既定のブランチ（main）にある workflow しか走らせられず、1.2 は本人の確かめと 1.1 の審査の後まで main に入れない（0-40）ので、merge の前はリードが `m7b` を `store-shots` という名前で push して走らせる（`ja-baseline.yml` と同じ。§8 の 11 の確認表に間に合わせる） |
| 新しい `ja-baseline.yml`（`on: push` でブランチ `ja-baseline` だけ、と `workflow_dispatch`。workflow_dispatch は既定のブランチ（main）にある workflow しか走らせられないので、1.2 の作業中はリードが `m7b` を `ja-baseline` という名前で push して走らせる） | J-4 の比べる相手を作る: `tools/l10n/ja-baseline-ref.txt`（B11 の後は `<1.1.1>` の 1 行、§1.5）の commit を別のフォルダに checkout → xcodegen → 組み立て → build.yml の 13 インチと他機種の写真の手順と **同じ launch に 1.2 と同じ `JA_ARGS`** を付けて撮る（1.1.1 の app は `--screenshot-sheet holidays`・`week-start` を知らないので、その 2 枚は撮らない。`--screenshot-probe`・`--screenshot-select` は知っているが、写真では使わない）。成果物 `ja-baseline-<sha の先頭 7 字>`（30 日）。**2 回走らせる**: §12.2 の CI-0 と同じとき（比べる相手を早く作り、写真の手順の誤りを先に見つける）と、J-4 で比べる直前（1.2 の最後の CI と同じ日。間に macos-26 のイメージの Xcode やシミュレータの runtime が上がると字の描き方が変わるため。「Select Xcode」:58-65 は Xcode_26.6 があればそれを選ぶだけで、シミュレータは「available」の中から選ぶ）。写真の段の最初に `xcodebuild -version` と使ったシミュレータの runtime を成果物の `env.txt` に書く（build.yml の写真の段と同じ。§1.3 の J-4）。写真の手順は build.yml から写すので、どちらかを直したら両方を直す（コメントで相互に指す）。**第 4 版**: C1 は e7b4d2f の build.yml から写した。B11 が `<1.1.1>` の手順に合わせる（offset の 4 か所、pinch-hint の 2 枚、§1.5）。1 回目は CI-0（B11 の 1 回目と C の後、§12.2）に行う |
| `compat-v1.0` のジョブ（第 4 版） | 1 段足す: `tools/weekstart-compat/` の確かめ（材料は B11、§1.5 の手順 7b）を、既にある `v10` の checkout と `tools/l10n/ja-baseline-ref.txt` の commit（`<1.1.1>`）の checkout で走らせて失敗 0（§10.8）。`tools/compat10` は変えない |
| 1.1.1 の `blank-paper` のジョブ・`header-paper UI:` の grep | 変えない（§1.5） |

### 7.6 成果物

```
screenshots/（build-and-test。1.1.1 と同じ名前・同じ枚数 ＋ ipad13-portrait-sheet-holidays.png・ipad13-portrait-sheet-week-start.png。全部日本語）・env.txt（xcodebuild -version とシミュレータの runtime）
l10n-screenshots/<言語>/ipad13-portrait-{month,day}.png・iphone-portrait-{week,year}.png（9 言語 × 4 = 36）
l10n-screenshots/{en,de}/ipad13-portrait-sheet-{settings,holidays,paywall}.png（6）
l10n-screenshots/{de,fr}/{ipad13,iphone}-portrait-tool-eraser.png（4）
l10n-screenshots/{fr,de}/iphone-portrait-sheet-lasso.png（2。§4.5 の F-15）
l10n-screenshots/en/ipad13-portrait-week.png・en/iphone-portrait-month.png（2。日曜。§10.7）
l10n-screenshots/{en,de}/ipad13-portrait-sheet-week-start.png（2。§10.7）
l10n-screenshots/ja-sunday/{ipad13,iphone}-portrait-{month,week}.png（4。§10.7）
l10n-screenshots/pseudo/{ipad13,iphone}-portrait-{month,sheet-settings,sheet-paywall}.png（6）・l10n-log.txt
store-<組>/{ipad13,iphone69}/0{1..4}-*.jpg（store-shots を走らせたときだけ。11 組、§7.5）
ja-baseline-<<1.1.1> の先頭 7 字>/（ja-baseline.yml を走らせたときだけ。screenshots/ と同じ名前。sheet-holidays・sheet-week-start は無い）・env.txt
```

成果物はリードが `gh run download`（このリポジトリの CI の成果物）で取り出す。本人は GitHub を操作しないので、本人に見せる写真はリードが §8 の 8 の確認ページにまとめて渡す。

## 8. 完了の定義

1. `swift build --package-path TegakiKit && swift run --package-path TegakiKit KitChecks` が「all N checks passed」（N ≥ 閾値。この Mac と CI）。`swift test --package-path TegakiKit` が CI で緑。`tools/typecheck/typecheck.sh` が警告 0（`XCTestStandIn.swift` に LanguageUITests の分を足した上で）。`python3 -I tools/l10n/lint.py .` が緑（L-12 の警告は M7B.md に一覧）。順序: K が N を docs/M7B.md に書く → C が閾値を入れる。**この Mac の確かめは、書類フォルダの外（scratchpad など）の空のフォルダに `git archive` で取り出した木で行う**（`~/Documents` は iCloud で同期されていて、作業ツリーに未追跡の「… 2」の複製が混ざる。`tools/compat10/` の 6 つ（元と同じ中身。`Sources/RunReal/main 2.swift` などで、そのまま compat10 のパッケージを組むと main が 2 つになりうる）と、`TegakiKit/.build/` の多数。第 3 版の偵察もそうした）。`git archive` は commit の木しか取り出さないので、手順は次のとおり: commit した後なら `git archive HEAD | tar -x -C <フォルダ>`。commit の前なら `ref=$(git stash create); git archive "${ref:-HEAD}" | tar -x -C <フォルダ>`（`git stash create` は追跡しているファイルの今の中身で commit を作って名前を出すだけで、作業ツリーも stash の一覧も変えない。変更が無いときは何も出さずに終わるので `HEAD` を使う。未追跡の「… 2」の複製は入らない。この Mac で確かめた）。新しく作ったファイルは、先に `git add <ファイル名>` をしないと入らない。`typecheck.sh` の作業フォルダもリポジトリの外の空のフォルダ。
2. `compat-v1.0` のジョブが緑（`tools/weekstart-compat` の段を含む）。「Frozen 1.0 copy」「Data code frozen since 1.1.1」が緑。`git diff <1.1.1> -- TegakiKit/Tests/Fixtures TegakiKit/Tests/Compat10` が空。**基準の移し替え（§1.5）が本物の `<1.1.1>` で済んでいる**。
3. `build-and-test` が緑: 13 インチの単体テスト（日本語に固定）・iPhone の UI テスト（YearTapUITests・EraserAndBelowDayUITests（8 本）・LanguageUITests・HeaderAndPaperUITests・WeekStartUITests。`testEveryLanguageIsChosen`・`testWeekStartFollowsTheRegion` を含む）・「Localized bundle check」。日本語の写真は J-4 のとおり、**1.1.1 の merge の commit `<1.1.1>` を `JA_ARGS` で撮り直した写真（比べる直前にもう一度撮った `ja-baseline-<先頭 7 字>`。2 つの run の `env.txt` が同じこと）と、ツールバーの帯も含めて同じ**（違ってよいのは設定と情報のシート・祝日と週の始まりのシート（1.2 だけ）・`store/ipad13/06-settings`。リードが `compare_shots.swift` で比べ、違いのあった写真の名前と画素の数を M7B.md に）。1.1 と 1.1.1 の CI の写真とは比べない（0-32）。
4. `l10n-shots` が写真を全部出し、訳し漏れが 0 件（0 でなければ M7B.md に理由）。
5. `docs/i18n/REVIEW.md` で × が 0、△ に理由。法律の英文・ストアの原稿（説明の最後の 1 文を含む）も R の逆翻訳を通っている。
6. `project.yml` の `MARKETING_VERSION` が 1.2、`CFBundleDevelopmentRegion` が en。リードが testflight.yml を `--ref m7b` で 1 回走らせ（1.1 のときと同じく main からは出さない。M7A.md:490）、Connect に **1.2 (N)** が「有効」で現れる。本人の §8 の 9 が済み、1.1.1 が審査を通って main に入った後に、**リードが本人に平易に報告して「はい」を得てから** `m7b` を main に merge する（0-35、0-40）。
7. Web リポジトリの `m7b-legal` で `npm test` と `npm run check:legal` が緑。
8. **写真の確かめ（リードと本人で分ける）**:
   - **リードの仕事**: J-4 の画素の比較（上の 3）と、下の表の全部を自分で見ること。成果物は `gh run download` で取り出す（§7.6）。
   - **本人の確かめ**: 本人は GitHub を操作しないので、リードが下の写真を **1 つの確認ページ**（HTML のファイル 1 つ。写真の縮小版と、それぞれの日本語の説明、見るべき所に赤い枠の印。公開しない）にまとめて渡す。判断の言葉は、他の言語を読めなくても見た目で確かめられる形にした（「文の終わりが『…』で切れていない」「字が重なっていない」「枠からはみ出していない」「日本語の写真と手書きの位置が同じ（日曜始まりの写真では、手書きが日付についていく）」）。英語などの字の意味は、リードが確認ページに日本語で添える。確認ページは、写真と説明が全部そろってから 1 回で書く（書きかけの .html を作らない。書いた .html は本人の画面に開くので、1.1 のときは下書きの確認表（1.1 (12) の表）が先に見え、入っていた 1.0.1 (11) で全項目を試されたことがある）。ページの頭には「1.2 の CI の写真（commit <先頭 7 字>）の確認です。実機での確かめは、後で別の表（§8 の 9）でお願いします」と書く（このページは TestFlight より前に渡すので、TestFlight の番号はまだ無い。無い番号や違う版を頭に書くと、取り違えを防ぐための決まりが逆に働く。番号は §8 の 9 の表の頭に書く）。期待のうち祝日の名前と日は 0.83 の値なので、H が新しい版で確かめ直してから載せる（0-14）。

| 写真 | 見えていなければならないもの（見た目で確かめる言い方） |
| --- | --- |
| `screenshots/ipad13-portrait-month.png` ほか日本語の全部 | いつもの日本語の画面と同じ（画素が同じことはリードが J-4 で確かめ済み）。祝日は日本（10/12 スポーツの日） |
| `screenshots/ipad13-portrait-sheet-settings.png` | 「カレンダー」の節があり、シートの下の方に「週の始まり」の行が見える（1.1 のこの写真の範囲は「カレンダー」の節までで、下端に「入力」の見出しが見えていた。週の始まりと祝日の節はその前に入る。どこまで見えるかはリードが写真で確かめてここを書き直す）。値「月曜」と「表示する祝日」の値「日本」は、§8 の 9 の手順 2・2b で見る |
| `screenshots/ipad13-portrait-sheet-holidays.png` | 「自動（この端末の地域：日本）」「なし」、近道の「日本」、検索の欄、国の一覧（日本語の国名）、「日本」に ✓ |
| `l10n-screenshots/en/ipad13-portrait-month.png` | 題名「October 2026」（2026 年 10 月）、曜日の行「Sun … Sat」（日〜土。米国の新しい方は日曜始まり）、左の列が日曜で赤、右の列が土曜で青、10/12 のマスに「Columbus Day」（米国の祝日）、手書きの見本は日付についていく（日本語の写真と列が違う）、ツールバーに「Pen」（ペン）など |
| `l10n-screenshots/en/ipad13-portrait-day.png` | 題名「Wed, October 7, 2026」（2026 年 10 月 7 日 水曜。写真の日は毎月 7 日で、この日は祝日が無い。§7.4）、「Free Notes」（自由メモ）、時刻は 24 時間の「9:00」 |
| `l10n-screenshots/pt-BR/iphone-portrait-year.png` | 年のマスの曜日「seg ter …」（月 火 …）が少し小さくなって入り、字が欠けていない・「…」で切れていない。月名「jan.」（1 月）など |
| `l10n-screenshots/zh-Hant/ipad13-portrait-month.png` | 「2026年10月」、曜日「日 一 二 …」（台湾の新しい方は日曜始まり）、10/10 のマスに「國慶日」（台湾の祝日）、10/9 のマスに「國慶日（補假）」（10/10 が土曜なので、前の金曜が休み） |
| `l10n-screenshots/de/ipad13-portrait-sheet-settings.png` | ドイツ語の長い行が、文の終わりが「…」で切れずに 2 行に折り返している。字が重なっていない |
| `l10n-screenshots/pseudo/*-sheet-paywall.png` | **わざと長くした試しの写真**（英語の文を 2 回くり返して、どの言語より長くしたもの）。それでも自動更新の説明と、利用規約・プライバシーポリシーのリンクが全部見えていて、画面の外に出ていない |
| `l10n-screenshots/fr/iphone-portrait-week.png` | 終日の欄の字が短い形か、出ていない（字が重なっていない） |
| `l10n-screenshots/fr/iphone-portrait-week.png`・`it/iphone-portrait-week.png`・`pt-BR/iphone-portrait-week.png` | 下のツールバー（ペンの行）で、道具の名前が「…」で切れず、最初の色（黒）の丸が丸ごと見える（日本語の `screenshots/iphone-portrait-week.png` と同じ所まで見える） |
| `l10n-screenshots/de/ipad13-portrait-tool-eraser.png`・`fr/ipad13-portrait-tool-eraser.png` | 消しゴムの説明が 2 行で、その右に ↶ ↷ が見える（日本語の `screenshots/ipad13-portrait-tool-eraser.png` と同じ所まで） |
| `l10n-screenshots/fr/iphone-portrait-sheet-lasso.png`・`de/iphone-portrait-sheet-lasso.png` | 投げなわで囲んだ線の近くに出るメニューの 3 つ（予定にする・削除・選択解除にあたる字）が全部画面の中にあり、右端が切れていない。字が「…」で切れていない |
| `l10n-screenshots/<言語>/ipad13-portrait-month.png`（9 言語） | ツールバーの右の「指でも書く」の訳が終わりまで見え、「しまう」の手前で切れていない。右上の切り替え（日・週・月・年にあたる 4 つ）の字が「…」で切れていない |
| `l10n-screenshots/ja-sunday/ipad13-portrait-month.png` | **日曜始まりにした日本語の画面**。曜日の行が「日月火水木金土」、左の列が赤い日曜、右の列が青い土曜。手書きの見本は日付についていく |
| `l10n-screenshots/ja-sunday/ipad13-portrait-week.png` | 題名「2026年10月4日〜10月10日」、左の列が日曜（10/4）、右の列が土曜（10/10）で、色が日曜は赤・土曜は青。終日の欄の予定の帯が日と列に合っている |
| `screenshots/ipad13-portrait-sheet-week-start.png`（日本語）・`l10n-screenshots/en/`・`de/` の同じ名前 | 切り替えるときの説明が全部読める（切れていない）。日本語の文を読んで、説明したとおりか（今見えている週の手書きは戻すまで見えないが消えない、月のページの手書きは日付についていく） |

9. 本人が TestFlight（1.2）で **実機**（本人の端末: iPad mini（A17 Pro・iPadOS 27.2・Apple Pencil Pro）・iPad Air 11・iPad Pro 13・iPhone 18 Pro Max、M7A.md:494。iPad は Pencil と指、iPhone は「指でも書く」オン。どれも日本語の端末）。**表を渡す時期と表の頭**: 表は、1.2 の build が本人の端末の TestFlight に届いてから渡す（HTML にするなら §8 の 8 と同じく、用意ができてから 1 回で書く。書きかけを先に見せると、届く前の版で全部を試してしまう。1.1 (12) の表を 1.0.1 (11) で試したことがある）。表の頭に「1.2（TestFlight <番号>）で試す表です。始める前に、iPad のアプリの 設定 › 情報 の『バージョン』が 1.2 (<番号>) であることを見てください（違えば試さずに知らせてください）」と書く。英語の画面で押す所は、日本語の名前と英語の名前を並べた（〔 〕の英語は X の用語集が固まった後にリードが確かめて差し替える。§6.2 で固定の語はそのまま）。**手順 1〜8 は iPad mini で**（いちばん狭い iPad なので、英語の字の切れを見るのに向く。ほかの iPad は 1.2 にした後、いつもの見た目が 1.1 と同じかだけ見てもらえれば十分）。期待のうち祝日の名前と日（Columbus Day・Thanksgiving Day・Day After Thanksgiving・Bayern・カナダの「全国共通のみ」・Sports Day）は 0.83 での見込みで、H が新しい版の HolidayData で確かめ直してから渡す（0-14）:

| # | 端末 | 手順 | 期待 |
| --- | --- | --- | --- |
| 0 | iPhone（始める前） | TestFlight を開き、このアプリの「自動アップデート」をオフにする（手順 9・9b で iPhone を 1.1.1 のまま残すため）。iPhone のアプリの設定 › 情報 の「バージョン」が 1.1.1 であることを見る | iPhone が勝手に 1.2 にならない |
| 1 | iPad mini | TestFlight で 1.2 を入れ、アプリの設定 › 情報 の「バージョン」が 1.2 (<番号>) であることを見てから、いつものように月・週・日・年を見る | 1.1.1 と同じ見た目・同じ日本語。祝日は日本。週は月曜始まり |
| 2 | iPad mini | アプリの設定 › 祝日 | 「表示する祝日」が「日本」（これまで使っていたので日本のまま） |
| 2b | iPad mini | アプリの設定 ›「週の始まり」を見る | 値が「月曜」（これまで使っていたので月曜のまま）。節の下の文が読める |
| 3 | iPad mini | 10 月 12 日のマスに何か書いてから、「表示する祝日」で「アメリカ合衆国」を選ぶ（州は選ばず「国全体」） | 行の値が「アメリカ合衆国（全国共通のみ）」。10 月 12 日に「Columbus Day」、11 月 26 日に「Thanksgiving Day」が出る。書いた字は同じ位置に残る |
| 3b | iPad mini | 続けて、アメリカ合衆国の州の画面で「California」を選ぶ | 行の値が「アメリカ合衆国・California」。**10 月 12 日の名前が消え**（カリフォルニア州は Columbus Day を休みにしない）、11 月 27 日に「Day After Thanksgiving」が出る（州で祝日が違う例。不具合ではありません）。字は動かない |
| 4 | iPad mini | 祝日を「なし」→ もう一度「日本」 | 祝日が消え、また日本に戻る。字は動かない |
| 4b | iPad mini | 週のページに何か書く → 設定で「週の始まり」を「日曜」にする | 説明が出る（**一度読んで意味が分かるかも教えてください**）。「日曜にする」を押すと、週のページが日曜から始まり、いま書いた手書きは見えない（消えていません。不具合ではありません） |
| 4c | iPad mini | 日曜始まりの週のページに別のものを書く → 「週の始まり」を「月曜」に戻す → もう一度「日曜」→ もう一度「月曜」 | 月曜では 4b の手書き、日曜ではこの手書きが、それぞれ同じ位置に出る。もう一方は見えない。どちらも消えない。設定の節の下に「もう一方の週の始まり（…）の週のページが…ページあります」と出る |
| 4d | iPad mini | 「月曜」のまま 2026 年 11 月の月のページを開き、11/10 のマスと、前の月の日のマス（薄く出ている）の 10/28 に書く。**土曜の 11/7 から日曜の 11/8 へまたいで 1 語書く** → 「週の始まり」を「日曜」にする → 設定を閉じる | 曜日の行が「日月火水木金土」。11/10 の手書きは 11/10 のマスにある（列は変わる）。10/28 の手書きは見えず、**設定を閉じると**一度だけ「この月のページには、いまの週の始まりでは表示されない日に書いた線が n 本あります。消えていません。週の始まりを戻すと見えます。」と 6 秒ほど出る。またいで書いた 1 語は、土曜の分と日曜の分に分かれて見える（線ごとに日付のマスについていくため。不具合ではありません） |
| 4e | iPad mini | 「週の始まり」を「月曜」に戻す（ここから先は月曜で） | 10/28 の手書きが元の場所に戻る。またいで書いた 1 語も元どおりつながる。土曜から日曜へまたいで書いた線は、日曜始まりのときは紙の端からはみ出すことがあるが、消えておらず、月曜に戻すと元の形（不具合ではありません） |
| 5 | iPad mini | 「設定」アプリ ›「アプリ」›「てがきカレンダー」›「言語」で English を選ぶ。**「言語」の項目が無いとき**は、先に「設定」›「一般」›「言語と地域」›「言語を追加」で English を足す（2 番目に足す。後で消せます）。**足すと、端末の表示をどちらの言語にするかを聞かれることがあるので、日本語のままの方（〔ボタンの名前はリードが確かめて書く、§2.1〕）を押す**。間違えて端末全体が英語になったら、そのまま触らずにリードに知らせてください。→ もう一度「アプリ」›「てがきカレンダー」›「言語」→ アプリを開く | 画面が英語（October 2026、Mon、Pen、Settings など）。紙の形と手書きの位置は同じ。ツールバーの道具の名前（Pen・Marker・Eraser・Lasso・Event・Hide）が「…」で切れずに入り、ボタンの幅は日本語と同じ（太さの Thin・Medium・Thick まで見える）。消しゴム・投げなわ・予定を選ぶと説明が 2 行で読める。投げなわで囲むと出るメニュー（Make Event・Delete・Deselect など）が画面の中に収まる。週の題名の終わりが切れていないか（日本語では 1.0.1 から切れている）。祝日は日本のまま（名前は英語の Sports Day など）。**項目の名前や、項目が出る条件が新機能の文（§6.3）と違っていたら教えてください**（提出の前に文を直します） |
| 6 | iPad mini（英語のまま） | 右上の歯車〔Settings〕（設定）を開いて上から下まで見る → 〔Purchase〕（購入）の節の〔Subscribe〕（購読する）か〔Try Free for 14 Days〕（14 日間無料で試す）を押して購入の画面を開く（買わない。閉じる） | 英語の文。価格は円のまま（App Store の国で決まる）。文の終わりが「…」で切れていない。利用規約などのリンクは日本語のページが開く（英語のページは 1.2 を出す日に公開するので、1.2 は日本語のページを開きます。不具合ではありません、0-38） |
| 7 | iPad mini（英語のまま） | 歯車〔Settings〕›〔Data〕（データ）›〔Export Handwriting〕（手書きを書き出す）›〔This Page as PDF〕（このページを PDF） | ファイル名と PDF の題名が英語（「Tegaki …」） |
| 8 | iPad mini | 手順 5 と同じ所で「日本語」に戻す。手順 5 で English を足したなら、「言語と地域」から消してよい | 全部日本語に戻る |
| 9 | 両方（iPhone は 1.1.1 のまま） | **iPhone を 1.1.1 のままにして**（手順 0）、iPad mini（1.2）で書く → iPhone で開く。逆に、iPhone（1.1.1）で書く → iPad mini（1.2）で開く | 手書きは同期され、どちらでも消えない・動かない |
| 9b | 両方（iPhone は 1.1.1 のまま） | iPad mini を「日曜」にして週のページに書く → iPhone を開いて同期を待ち、月曜の週のページと月のページを見る → iPad mini を「月曜」に戻し、もう一度「日曜」→ 最後に「月曜」に戻す | iPhone の手書きはそのまま（日曜始まりの週の手書きは iPhone では見えません。古い版の決まりです）。iPad mini の日曜の手書きは消えていない |
| 10 | iPhone（18 Pro Max） | **ここで iPhone の TestFlight で 1.2 を入れる**（アプリの設定 › 情報 の「バージョン」が 1.2 (<番号>)）。手順 1〜5 と同じ（短くてよい）。最後に手順 8 と同じく日本語に戻す | 同じ（週の始まりは「月曜」のまま）。年のページの曜日が英語でも読める。英語のツールバーで最初の色（黒）の丸が見える。投げなわのメニューが画面の中に収まる。最後は全部日本語に戻る |
| 11 | 両方（どちらも 1.2） | アプリの設定 › 情報 ›「オープンソースのライセンス」 | 英語のライセンスの全文が出る |
| 12 | 両方（どちらも 1.2） | アプリの設定 › 祝日 の画面で「韓国」「ドイツ」「カナダ」を選んでみる（最後に「日本」に戻す） | ドイツは州を選べる（画面の名前はデータのままの「Bayern」（バイエルン）など）。韓国は州の画面が無い。カナダは行の値が「カナダ（全国共通のみ）」で、州を選ぶとその州の祝日が加わる |
| 13 | 両方 | アプリの設定 › 情報 の 2 行「いちばん線の多いページ」と「今年の年のページ」の本数を、いつも使う iPad と iPhone で教えてください。もう 1 台を古い版のまま使う期間があれば、それも（古い版では、ページの境目をまたいで書いた線が片方のページにしか出ません） | 次の版「横につなげる」で、隣のページに描ける線の数の目安に使う（B の P-B9、§6.8） |
| 14 | iPhone（最後に） | TestFlight で、このアプリの「自動アップデート」をオンに戻す | 次の build から自動で入る |

動きがおかしいときは、アプリの設定 › 情報 の「バージョン」を長押しして「記録」の「コピー」を押し、このチャットに貼ってください（英語の画面では 歯車〔Settings〕›〔About〕（情報）の〔Version〕（バージョン）を長押し。〔 〕の英語は用語集が固まった後にリードが差し替える。記録の画面と「コピー」のボタンは、どの言語でも日本語のまま、§2.5）。

**公開の後の確かめ（EU。E の表）**: TestFlight の表には混ぜず、§11.1 の順 9 の後に別の表として渡す。表の頭に「App Store の 1.2 と EU の店頭を確かめる表です。EU の配信を入れた後にお願いします」と書く。届け出が間に合わず EU を後で入れるときは、入れた日に渡す。ページの中の英語・ドイツ語などの字の意味と、連絡先の項目の国ごとの名前（ドイツは「Anbieter」。他の国はリードがそのときのページで確かめて書く）は、リードが表に日本語で添える。

| # | 端末 | 手順 | 期待 |
| --- | --- | --- | --- |
| E-1 | Mac | Mac の Safari で `https://apps.apple.com/de/app/id6822762089` を開く（ドイツの店頭。iPad や iPhone の Safari だと App Store アプリに飛んで日本の店頭が開くことがあるので Mac で）→ ページの下の「Anbieter」（提供者）を押して開く | ご自分の住所・電話番号・メールアドレスが出ている（了承された内容のとおりか。畳まれているので、開かないと見えません）。説明がドイツ語で、写真に日本語の文字が出ていない。App 内課金の名前が「てがきカレンダー 年額」などの日本語でない |
| E-2 | Mac | 同じく `/es/`（スペイン）・`/pt/`（ポルトガル）・`/pl/`（ポーランド） | スペイン語・ポルトガル語・英語の説明。写真に日本語の文字が出ていない。App 内課金の名前が日本語でない |
| E-3 | Mac | 同じく `/nl/`（オランダ）（順 8 でオランダとスウェーデンを待ったときは飛ばす） | 英語の説明。App 内課金の名前も英語。日本語が出ていたら教えてください（次の版で直します） |
| E-4 | iPad mini | アプリの設定 › 情報 › 利用規約とプライバシーポリシーを開く | 日本語のページに EU の条文（第 5 条の撤回の権利、第 12 条の断り、プライバシーの第 12 節・第 13 節）がある。M7B-23 が「はい」なら上に English のリンクがあり、押すと英語のページが開く |

10. docs/M7B.md・README・DESIGN の注記が更新されている（C）: DESIGN に「言語」と「祝日」の節（§2.1・§2.2・§5 の要点）、§2.8（設定 › 祝日 と情報の行）、§4.1（許可の文は 10 言語に。日本語は不変）、§9（1.2 の行）。docs/M7_PLAN.md は §6.8。docs/M7B.md に KitChecks の N、写真の比較（J-4。1.1 の CI の写真が中国語の書体だったことを含む）、LanguageUITests の結果（0-2 の pt-PT を含む）、「Localized bundle check」の結果（xcstrings か strings か、`HolidayData` の場所）、`xcodegen --version` と `knownRegions`、「言語」の項目が出る条件、祝日データを読んだ時間（ms）、REVIEW.md の要約、祝日データの弱い所（§5.10）と販売中の国の `lastOfficialYear`・`coverage` の表、本人の返事（§9）と確認の結果。README は 1.1 の後半の分も直す（:182 の「Pencil は hitTest で」を「Pencil は容器の `InkPencilGestureRecognizer` から受ける（overlay の hitTest は常に nil、ずれ 47）」に、Ink の一覧（:180-185）に `InkTouchObserver.swift`・`InkTrace.swift` の 2 行、:92 の CI の説明に EraserAndBelowDayUITests（1.1 の UI テストは YearTapUITests と合わせて 13 本）と「The unit tests' repro lines」の段）。DESIGN §9 の 1.1 の行（:910）を「e7b4d2f で main に入った（TestFlight 14、審査中）」に。DESIGN の 1.1 の注記（:417。どの消しゴムも戻る）と §2.8 の「しまう」の 48 × 44 pt（:228）は元に戻さない。docs/M7B.md には、取り寄せた python-holidays の版と 0.83 との差の表（§5.1、§5.10）と本人への報告、e7b4d2f の CI の結果（時間・EraserAndBelowDayUITests の 8 本・`repro: A17`・`B8` の値）、J-4 の 2 つの run の `xcodebuild -version` とシミュレータの runtime（§1.3）、F-1 の数字の枠（J-4 で差が出て戻したか）、英語などの TestFlight と審査の端末で「バージョン」の長押しの記録が日本語で出ること（§2.5）、`englishPagesPublished` の値（1.2 は false）と、英語の規約の URL に替えるのは 1.3 の説明からであること・公開の日に Connect の URL を替えたか（0-38）、ツールバーの L-12 の警告と `ToolbarFitTests` が 38 pt を超えたと出した名前の一覧、投げなわのメニューと見出しの字の幅（F-15・F-16 のテストが出した値）、B の P-B9 の答えと 1.3 以降の訳とストアの分の目安（§6.8）も書く。**第 4 版で足す**: README・DESIGN の週の説明（「月曜固定」の文。`grep -n "月曜"`）を K-11 に合わせ、DESIGN に「週の始まり」の節（§10 の要点）と設定の行、「EU を除く」の文（§11.3）を直す。`docs/APPLE_ENROLLMENT.md` も。docs/M7B.md に、`<1.1.1>` と基準の移し替えの結果（§1.5）、週の始まりの地域の値（iOS で測れたもの）、`tools/weekstart-compat` の結果、隠れる線のトーストの確かめ、販売中の 174 の国・地域の表、EU の届け出の日付と通るまでの日数・`contentStatuses` の値・`PATCH` が効いたか・ロシアの店頭の結果（§11.1）、CRA の報告の手順 1 行（§11.6）、M7B-23・M7B-24 の答えも書く。
11. **ストアに入れる前の、言語ごとの確認表**（M7B-18。A の原稿と R の逆翻訳と `store-shots` の写真がそろった後、Connect に入れる前）: リードが 1 つのページ（HTML のファイル 1 つ。公開しない）を作る。**入力する物を全部載せる**（載せていない物は入れない）: 言語ごとに、名前の第 1 案と退き先 2 つ（重複で拒まれたら確かめなしで順に使うので、3 つとも見せる）・サブタイトル・キーワード・promo（公開される 170 字）・説明（**R の逆翻訳の全文**。長いので畳んで開ける形）・新機能の文・サブスクリプションの月額・年額の表示名と説明とグループの表示名の **R の逆翻訳（日本語）**、サポートとプライバシーポリシーの URL と説明の中の利用規約の URL（1.2 はどれも日本語のページ、0-38）、言語ごとの写真の縮小版（購入画面と価格が無いこと）、L-9 の結果（字数・禁止語・URL）。ja の新機能の文（§6.3）と、en-US の新機能の最後の日本語の 1 文（§6.3）はそのまま日本語で載せる（本人が日本語で読んで決める）。**公開中の日本語の説明の 1 行の直しの案（§6.6 の ja の行）も載せて聞く。**審査メモ（英語。本人の名で Apple に出す文）は、R の逆翻訳の全文と、添える日本語の要約を載せる。表の頭に「en-GB・en-AU・en-CA は en-US と、fr-CA は fr-FR と同じ文です」と書く。**第 4 版: 15 ロケール**。M7B-18 を聞いたときは 13 だったので、es-ES・pt-PT は足した分だと表の頭に書く。fr-FR・de-DE・it の読み手がフランス・ドイツ・イタリアに変わったこと、pt-PT の説明に「画面はブラジルのポルトガル語」と書いたことも書く。写真は組と店頭の対応（§7.5）で載せ、週の並びの違い（米国などは日曜始まり）も書く。M7B-18 は「はい」（2026-11-01）で、確認表を見せてから入れる約束。本人がこれを見て「この内容で Connect に入れてよい」と答えてから、リードが入力する（直しを求められたら直して見せ直す）。答えが提出に間に合わなければ入力せず、ja だけで 1.2 を出してよい（§6.6）。確認ページも §8 の 8 と同じく、全部そろってから 1 回で書く。1.2 を出した日に Connect の URL を英語のページに替えるのも入力なので、そのときに「この URL に替えてよいか」を本人に聞いてから行う（§6.6）。
12. **週の始まり**: §10.10 のとおり。
13. **EU**: §11.8 のとおり（届け出が 1.2 に間に合わなければ、EU を入れる所だけ後でよい）。

## 9. 本人の決定・未決

**2026-11-04 の本人の決定**: 週の始まりを選べるようにして 1.2 に入れる（O-2）／EU（27 か国）で 1.2 と同時に売る（O-4。公開される項目は説明して了承済み。届け出の入力は本人）／1.1.1 を先に出す。

**今、本人に答えてもらう問いは 2 つ**（M7B-23・M7B-24。次の表）。

### 第 4 版で足した問い（返事をください）

| # | 内容 | 返事が無いとき |
| --- | --- | --- |
| **M7B-23** | **1.2 で EU の人が規約とプライバシーポリシーを開くと日本語のページになり、今の決まりでは英語のページへのリンクもありません。日本語の 3 ページの上に「English」へのリンクを 1 つずつ足してよいですか？**（推奨: はい。公開は今までどおり 1.2 を出す日で、アプリは変えません。別の案は、(イ) 英語のページを審査の前に公開して 1.2 のアプリもそちらを開くようにする（審査の間、日本語の正本に無い条文と、まだ出ていない機能の説明が英語で先に出ます。アプリの変更と試験が増えます）、(ウ) 今のまま 1.3 まで待つ（EU の人は 1.3 まで日本語だけ）です） | W は commit ③ に分けて作っておき、公開の直前の確認（§6.5）でもう一度聞く。答えが無ければ足さない。**(イ) を選ばれたときだけ**: K2 が `englishPagesPublished = true` と試験、説明と Connect の URL（0-38）、§8 の 9 の手順 6 の期待を直す（返事は K2 が `LegalLinks` を書く前、遅くとも 1.2 の TestFlight の前。間に合わなければ (ア)） |
| **M7B-24** | **了承していただいた住所・電話番号・メールアドレスは、EU の店頭のページに出ます。そのページは日本からも誰でも開けます（ほかのアプリで確かめました）。後から番号や住所を変える手順は Apple の説明に無く、サポートに聞くことになります（自宅を出したくなければ私書箱もできます）。そのうえで、EU で売ると負担が 2 つ増えると分かりました。** 1 つ目はサイバーレジリエンス法で、今年 9 月から、悪用された弱点が見つかったら 24 時間以内に EU の窓口へ報告します（零細企業は遅れても罰金なし）。2027 年 12 月からは、実質的に変えた版について文書づくりと CE マーク（EU の決まりに合うと自分で宣言する印）の自己宣言が要る見込みです。2 つ目は新しい製造物責任で、2026 年 12 月から、欠陥で手書きのデータを壊したときなどの責任を規約で制限できません。届け出のときには「EU 法に合う物だけを提供する」とご本人が証明します。**これを知ったうえで、予定どおり 1.2 で EU に出してよいですか？ 専門家には聞きますか？**（推奨: 予定どおり出し、1.2 を出してから 1 年以内（遅くとも 2027 年 12 月より前）に 1 回だけ専門家に §11.6 の 2・5・8 を聞く。問いはリードが英語の相談票にまとめます。別の案は、公開の前に聞く（EU は遅れますが他の国は先に出せます）、EU をやめる（O-4 を第 3 版に戻す）です） | 実装はそのまま進める（どの答えでも無駄にならない）。**届け出と、EU を入れる操作（§11.1 の順 8）は、この答えの後にする** |

### 本人に知らせること（問いにしない）

- **「1.2 と同時」は届け出が通る時期しだい**です。通るまでの日数を Apple は書いていません（報告は 2〜3 日から 41 日まで）。間に合わなければ 1.2 を 148 か国で先に出し、通った日に EU を入れます（新しい版は要りません）。ただし、**確認中は 1.2 の提出も止まる可能性があります**（未確認。利用者の報告が 1 件）。止まったら、画面の文をお伝えして Apple への問い合わせ文を下書きします（§11.1）。
- **届け出の時期を「1.1.1 を提出したらすぐ」から「1.1.1 が審査を通ったらすぐ」に変えました**（M7B-24 に答えた後で。1.1.1 の提出が今日から 1 週間済まないか、提出から 1 週間たっても通らないときは待ちません）。上の可能性があるので、1.1.1 が差し戻されたときの再提出を巻き込まないためです。代わりに EU は数日遅れることがあります。急ぐときは一言ください。提出の直後に戻せます（§11.1）。
- **月のページで、土曜と日曜にまたいで書いた言葉は、日曜始まりにすると土曜の分と日曜の分に分かれて見えます**（右端の土曜と次の行の左端の日曜に分かれます。線ごとに「中心のあるマス」についていくため）。1 本の線がまたいでいれば、紙の端からはみ出すこともあります。消えず、月曜に戻せば元どおりです。了承のときの説明には入っていませんでした（§10.2）。前後の月の日のマスの手書きも、片方の並びにしか無い日のものは戻すまで見えません（1 日が日曜の月は 6 日、ほかの月は 1 日）。切り替えの説明の文に書き、開いたときに本数を知らせます。
- **今お使いの方の 2 台目や入れ直し**は、最初は「新しい方」と判定されますが、iCloud の手書きが全部届いた後に 1 回だけ照らします。週の手書きが月曜の形だけか、月曜の形の方が多ければ月曜に合わせて知らせます。書いている途中には切り替えず、次にページを移ったときに切り替えます。届く前に別の形のページに書いていたら、そのページ数も知らせます（§10.3）。
- **設定は端末ごと**なので、iPad と iPhone で別の週の始まりにすると、週の手書きが片方に出ません。脚注と、もう一方の形のページ数の表示で知らせます（§10.4）。
- **既定の決め方**: §10.3・§10.4・§11.7 の表。自動は端末の地域に従うので、中国・韓国・台湾・ブラジル・メキシコ・ポルトガルなどは日曜になります。

2026-11-01 に本人から答えをもらった: 返事が必要な 4 つ（M7B-3・M7B-10・M7B-17・M7B-18）は「はい」、ほかは既定のとおり。下の表は、その答えを書き込んだもの（問いの文は第 2 版のまま）。第 3 版で足した問いは最後の表（M7B-20〜22。見直しで、M7B-21 は聞かずに本人の答えのままにした。M7B-20 は必要になったときだけ、M7B-22 は既定で進める）。

### 答えをもらった問い（2026-11-01、どれも「はい」）

公開・ダウンロード・ストアへの入力は、本人の了承が要る操作。この 4 つは了承をもらったので、下の条件のとおりに行う。

| # | 内容 | 本人の答え | この契約での扱い |
| --- | --- | --- | --- |
| M7B-3 | 英語の利用規約・プライバシーポリシー・サポートのページを、今と同じ Web のサイトの中（`…/app/en/`）に **新しく公開** してよいですか？（「他の Pages を公開しない」というお約束に関わります） | **はい**（公開は 1.2 を出す日） | W が作る（`app/en/` の terms・privacy・support の 3 ページ）。1.2 を出す日に、公開の直前に公開する文と URL を本人に見せて「はい」をもらってから、リードが公開する（§6.5）。審査はその前なので、1.2 のアプリと、Connect の英語などの欄と、説明の利用規約の URL は日本語のページを指す（0-38）。英語のページを審査の前に出す案（M7B-21）は聞かない |
| M7B-10 | 祝日データの元（python-holidays）の新しい版を、インターネット（PyPI）から取り寄せてよいですか？ 今この Mac にあるのは約 1 年前の版で、中国の 2026 年の振替出勤日など、その後の発表が入っていません | **はい** | H の最初の手順でリードが取り寄せる（0-14、§5.1）。この Mac の Python 3.9 で入るいちばん新しい版。数字と本人に見せる期待は新しい版で測り直す。取り寄せた後、取り寄せた物（版・出どころ・大きさ・置き場所）を本人に平易に報告する。それより新しい版が要るときだけ M7B-20 |
| M7B-17 | 利用規約・プライバシーポリシー・サポートの **今公開している日本語のページ** に、次の 4 つを足して公開してよいですか？ ①利用規約の第 12 条の後に「あなたがお住まいの国の消費者保護の法律で、放棄できない権利は、この規約によって制限されません。」 ②利用規約の免責の条に「日本以外の祝日は公開データ（python-holidays）にもとづく参考の情報で、正確さを保証しません。」 ③プライバシーポリシーに「祝日のデータはアプリの中に入っていて、表示のために通信することはありません。」 ④サポートのよくある質問に「表示の言語を変えるには？」「祝日の国を変えるには？」の 2 つ（文は §6.4） | **はい**（公開は 1.2 を出す日） | ①〜③ はこの文のまま、④ は §6.4 の形で L が書く（python-holidays の出どころの 1 文は ④ の答えの中に、§5.9）。日本語のページに足すのはこの 4 つと、第 4 版の EU の文（§11.3）と週の始まりの FAQ（どちらもこの「はい」の外なので、公開の直前の確認で全文を見せて聞く）。English のリンクは M7B-23。1.2 を出す日に、公開の直前に ④ を含む差分の全文と公開する URL を本人に見せ、「はい」をもらってからリードが公開する（§6.5） |
| M7B-18 | App Store に、英語・中国語・韓国語などの 13 のロケールの名前・説明・キーワード・新機能の文と、言語ごとの写真を入れてよいですか？ 入れる前に、言語ごとに日本語へ訳し戻した文と写真の確認表（§8 の 11）をお見せします | **はい**（入れる前に確認表を見せる） | リードが確認表（入力する物を全部載せる。名前の退き先・promo・サブスクリプション・URL・審査メモまで）を渡し、本人の「この内容で入れてよい」の後に入力する（§6.6、§8 の 11）。確認が提出に間に合わなければ ja だけで 1.2 を出してよい。この「はい」は 1.2 の入力の分で、次の版はそのたびに確認表を見せて聞く（§6.8）。**第 4 版: es-ES・pt-PT を足して 15 になったので、確認表でこの 2 つも見せて聞く** |

### 既定で確定した問い（内容。2026-11-01）

| # | 内容 | 確定（既定のとおり） |
| --- | --- | --- |
| M7B-1 | 英語・中国語・韓国語などの App Store での名前。日本語の「てがきカレンダー」は外国の人に読めないので、各言語で「Tegaki」と説明の語を組み合わせた名前にしますか？（英語は「Tegaki Calendar」。同じ名前が他のアプリに使われていたら「Tegaki: Handwritten Planner」→「Tegaki – Ink on Your Calendar」の順に試します） | **組み合わせた名前**（英語は「Tegaki Calendar」）。入力は §8 の 11 の確認の後（M7B-18 は「はい」） |
| M7B-2 | ホーム画面のアプリの名前（日本語以外の端末） | **「Tegaki」**（長いと「Tegaki Calen…」と切れるため。日本語の端末は「てがきカレンダー」のまま） |
| M7B-4 | 規約のページを英語以外（フランス語など）にも訳しますか？ カナダのケベック州ではフランス語の契約書が求められる場合があります | **訳さない**（日本語と英語だけ。危険は記録しておく） |
| M7B-5 | App Store の写真を言語ごとに撮り直して載せますか？ | **載せる**（13 インチ iPad と 6.9 インチ iPhone の 4 枚ずつ、9 言語。購入画面は入れない。他の大きさは Apple が縮めて使う。第 4 版で、週の並びの分を足して 11 組、§7.5）。上げるのは §8 の 11 の確認の後（M7B-18 は「はい」） |
| M7B-6 | 「日本の祝日」と「住んでいる国の祝日」を同時に出す（2 か国） | **1.2 では 1 か国だけ**（欲しければ後の版で） |
| M7B-7 | これまで使っている人の祝日は、端末の地域にかかわらず「日本」のままにします（決定 3 の「既定は端末の地域」の、これまでの利用者だけの例外です。新しく入れた人は端末の地域） | **日本のまま**（新しく入れた人だけ端末の地域） |
| M7B-11 | 英語などの問い合わせへの返事: Claude が訳と返事の下書き（日本語の訳つき）を作り、ご自分で読んで送る（§6.7）。サポートページに「返事は英語か日本語で、機械翻訳の助けを借りています」と書く | **この形** |
| M7B-12 | 中国本土での配信: Apple は中国本土で配信するアプリに登録番号（ICP）を求める方針です。中国語（簡体字）を足すと中国本土の人の目に触れやすくなります | **今のまま**（外すかどうかは本人。外すなら Connect の配信の国から中国本土を外すだけ）。何もしなければ今のまま中国本土でも配信されます。Apple から登録番号を求められたら、配信の国から中国本土を外せば済みます（他の国には響きません） |
| M7B-13 | 日本語以外の画面の 設定 › 情報 に「訳は AI が作り、ネイティブの確認はまだ」という文と連絡先を出す | **出す** |
| M7B-19 | 1.1 から使っている人で、端末の言語が日本語以外の人（日本に住む英語の設定の人、海外に住む人など）は、1.2 にすると表示が英語などに変わり、ホーム画面の名前も「Tegaki」になります。(a) そのまま（App Store の英語などの新機能の文の最後に、日本語で戻し方を書く）、(b) 1.1 からの人だけ日本語のままにする（アプリごとの言語の記録に日本語を入れる。後で「設定」アプリから変えられる。ただし iOS の決まりで、1.2 の最初の 1 回の起動だけは英語などで出て、2 回目から日本語） | **(a) そのまま**（決定 1「端末の言語に従う」のとおり。1.0 の公開は 10 月 30 日で、これまでの利用者はまだ少ない。(b) なら U が §1.4 の移行で、これまでの利用者で `UILanguage.current != .ja` のときだけ、アプリの UserDefaults の `AppleLanguages` に `["ja"]` を書く） |

### 既定で確定した問い（見た目と仕組みの細かいこと。2026-11-01）

| # | 内容 | 確定（既定のとおり） |
| --- | --- | --- |
| M7B-8 | 祝日の名前の言語: 画面の言語の名前が無いときは、その国の言葉（同じ種類の文字のときだけ）→ 英語の順。例: 日本語の画面でドイツを選ぶと英語の名前、サウジアラビアでもアラビア文字ではなく英語 | **この決め方** |
| M7B-9 | 紙の時刻を 12 時間（「9 AM」）にする（米国の人は 12 時間がふつう） | **1.2 は全言語 24 時間**（12 時間だと iPhone の週の時刻の字が小さくなりすぎる。欲しければ後の版で考える） |
| M7B-14 | ポルトガル語の年のページの曜日を「seg ter qua…」（少し縮める）にするか、「D S T Q Q S S」（1 字。見分けにくい）にするか | **「seg ter qua…」を縮める** |
| M7B-15 | 年のマスの祝日名は 1 行で、入らなければ「…」で切る（日本語でも今 8 件が切れています） | **1 行で切る**（2 行にすると手書きの欄が狭くなる） |
| M7B-16 | 年額の説明の「月あたり 200 円・4 か月分お得」は円の額なので、他の言語では価格を書きません。日本語の説明はそのままでよいですか？ | **日本語はそのまま**、他の言語は価格を書かない |

### 第 3 版で足した問い（今、本人に聞くものは無い）

| # | 内容 | 返事が無いとき |
| --- | --- | --- |
| M7B-21（聞かない。見直しで本人の答えのままにした） | 英語の規約類のページ（M7B-3）を、1.2 を出す日より前（審査に出す前）に公開すること | **聞かない。本人の答え（M7B-3）のとおり 1.2 を出す日に公開する**（1.2 のアプリと Connect と説明は日本語のページを指す。`englishPagesPublished = false`、0-38。英語のページをアプリから開くのは 1.3 から）。先に出すと次の代償がある: (1) 英語のページは §6.4 の 4 つを足した後の日本語の英訳なので、1.2 を出すまでの数週間、正本の日本語のページ（1.1 のまま）に無い条文（消費者保護・日本以外の祝日の免責）と、まだ出ていない機能（言語・祝日の変え方）のよくある質問が、英語でだけ公開される（冒頭は「日本語版が優先する」なのに、中身が食い違う）。(2) 1.1 がまだ出ていなければ、英語のページには Web の main にまだ無い 1.1 の文（`m7a-legal` の SUPPORT:140 など）の訳も入る。本人が自分から「英語のページを先に出したい」と言ったときだけ、この代償を平易に伝えて「はい」をもらい、1.1 が App Store に出た後・1.2 の TestFlight を作る前に、公開の直前の確認（§6.5）をしてから公開する（返事は K が `LegalLinks` を書く前、遅くとも 1.2 の TestFlight の前。間に合わなければ `englishPagesPublished = false` のまま進める） |
| M7B-20（必要になったときだけ、リードが聞く） | python-holidays の新しい版がこの Mac の Python（3.9）では入らず、3.9 で入る版に中国などの 2026 年の発表が入っていないとき: 新しい Python を、この Mac に取り寄せてよいですか？ **聞くときは、取り寄せる物の出どころ・ファイルの名前・大きさ・置く場所・消し方を書いて聞く**（python.org の公式の入れ物（.pkg）は、入れるときに管理者の確かめが出る。この Mac はターミナルの sudo が使えず、画面の Touch ID の確かめは通る見込み。管理者の確かめが要らない別の配布を `~/.local` に置くなら、その出どころを名前で書く） | **取り寄せない**（3.9 で入る版で作る。発表の入っていない年は、設定の画面に「発表前の推定」と出す、0-29） |
| M7B-22（既定で進める） | この Mac の作業フォルダに、元と 1 バイトも違わない複製のファイルが 6 つあります（`tools/compat10/` の「main 2.swift」など。10-31 にでき、iCloud の同期でできたものと見られます）。GitHub には入っていません。ゴミ箱へ移してよいですか？ | **そのまま残す**（git に入れない。この Mac の確かめは書類フォルダの外に取り出した木で行う、§8 の 1） |

### 9.1 採らなかった案と指摘

#### 第 1 版までに採らなかった案

| 案（出どころ） | 扱い | 理由 |
| --- | --- | --- |
| TegakiKit も `.lproj/Localizable.strings`・`.stringsdict` と `Bundle.module` で訳す（文字列の偵察） | 採らない（D4） | 偵察自身の実測で、`String(localized:bundle:locale:)` の `locale` では言語が選ばれず、選べる書き方は iOS で未確認。KitChecks（コマンドラインのプログラム）は言語を指定しないと英語になり、日本語の確かめが全部書き直しになる。`typecheck.sh` に `Bundle.module` が無い。生成した Swift の表なら、言語を引数で確実に選べ、この Mac・CI・typecheck で同じに動く |
| Kit は列挙型や数だけを返し、文字は全部アプリ側で作る（ストアの偵察の (i)） | 採らない | `PageNavigation.title`・`StrokeBudget.pageLabel`・`AppExport.pdfFileName`・`PlanText` を使う Kit のテストと KitChecks（日本語の確かめ数百か所）を全部アプリへ移すことになり、1.1 との一致（J-3）を Kit の中で確かめられなくなる |
| 日本語の文をキーにする | 採らない（D2） | 開発言語を en にすると訳が抜けたときに日本語が出る。本人がよく直す日本語の文がキーだと、直すたびに 9 言語の訳が宙に浮く。書き換えが要る普通の String が 509 個中約 417 個あり（第 2 版の数。e7b4d2f では 515 個で、うち 6 個は凍結した Ink の例外）、自動の翻訳対象で得をする分は 92 個だけ |
| String Catalog の複数形と `%lld` | 採らない（D5） | `%lld` は地域の区切りで「2,026年」になる（実測）。`String(localized:)` の結果を `String(format:)` に通すと複数形の情報が失われうる。Kit と同じ one/other の 2 キーにそろえる |
| 日本語も DateFormatter の雛形で作る（偵察の (d)。macOS では同じ字になった） | 採らない（D6） | iOS の ICU の版で字が変わると、日本語の利用者の画面が黙って変わる。1.1 の手作りの式を残せば、一致を KitChecks で確かめるだけで済む |
| 紙の時刻を端末の 12/24 時間の設定に従わせる | 1.2 では採らない（D7、M7B-9） | 「10 AM」が時刻欄に入らず、上限を広げると iPhone の週で 9 pt を割る |
| 見出しの各行の高さを固定値にする（紙の偵察の G-5） | 採らない | 1 行に限る（`lineLimit(1)` ＋ 縮小）だけで言語による伸びは止まり、日本語の絵は 1.1 と同じに保てる。固定値は日本語の見出しの高さを変えうる |
| 年のマスの祝日名を 2 行にする | 採らない（M7B-15） | 2 行目がマスの左 45% の手書き欄を覆い、それでも米国の名前は 32〜43% しか入らない |
| 振替出勤日に「出勤日」の札を出す（祝日の偵察 §3.2） | 1.2 では色だけ | マスに字を足すと F-2・F-3 の枠を取り合う。訳す語も増える。色だけでも土曜の青・日曜の赤の誤りは防げる |
| 祝日の名前を「画面 → その国 → 英語」で選ぶ（指示のとおり） | 変えた（0-15、M7B-8） | 日本語の画面でサウジアラビアにアラビア文字、フランス語の画面で日本に漢字とかなが出る。同じ系統の文字のときだけその国の言葉にした |
| 祝日データを lzfse で圧縮して同梱 | 採らない | App Store の配信がもともと圧縮する（約 1.6 MB）。素の JSON なら毎年の更新の差を git で読める |
| 祝日データを Swift パッケージのリソース（`Bundle.module`）にする | 採らない（D8） | typecheck と KitChecks で読み方が分かれる。場所を引数で渡せば、アプリは bundle、テストは `#filePath` で同じ関数を通る |
| 販売中の地域（148。うち 147 にデータ）のデータだけを入れる | 採らない（0-13） | 旅行中・海外に住む人が選べない。差は 1.5 MB ほど |
| pt-PT・es-419・es-ES の `.lproj` を別に置く | 採らない（0-2） | 実測でどれも近い言語に当たる。EU で売るようになっても同じ（第 3 版の理由「EU は売らない」は消した。§11.2）。es と es-419 を両方置くと es-MX が es-419 に当たり、文が 2 つに分かれる |
| アプリの中に「言語」の設定を作る | 採らない | iOS が「設定」アプリにアプリごとの言語の項目を自動で付ける。アプリの中で切り替えると、起動中の文と書式が混ざる |
| 祝日の設定を iCloud で端末間に送る | 採らない（0-21） | 他の設定と同じく端末ごと。手書きの位置に影響しないので、端末で違っても困らない |
| 「（日表示へ）」を読み上げのヒントへ移す（紙の偵察 §8） | 日本語では採らない（0-24） | 日本語の読み上げの名前が変わり、YearTapUITests も壊れる。他の言語は日付と動作を 1 つの文として訳す |
| App Store の主言語を英語に変える | 採らない（D12） | Apple の条件（その言語が前の版で審査を通っている）を 1.2 では満たせない。en-GB を入れれば受け皿は足りる（ただしオランダ・スウェーデンは未確定、§11.2。1.2 の後の版の候補） |
| 規約を 9 言語すべてに訳す | 採らない（D11、M7B-4） | ネイティブの確認が無い法律の文を増やすと、誤訳の危険だけが増える |
| `RunReal` に 1.0.1 を 2 つ目の対象として足す（M7A の予告） | 採らない（§1.2 K-7） | 1.0.1 のデータの部分は 1.0 と同じ（sha256 が同じ）。1.2 はデータの部分を変えないので、1.1 との一致は「Data code frozen since 1.1」で見る |

#### 第 2 版で採らなかった指摘・形を変えて採った指摘（2026-10-31 のレビュー 3 本から。ほかの指摘は全部そのまま採った）

| 指摘（レビュー） | 扱い | 理由 |
| --- | --- | --- |
| `XCTestStandIn.swift` に `otherElements`・`terminate()`・`identifier` などが無い（iOS） | 一部（`otherElements`・`identifier` は足す。`terminate()` と `subscript` は足さない） | `XCUIApplication.terminate()`（:131）も `XCUIElementQuery.subscript(key:)`（:118。1.0.1 から）も今の代わりの XCUI に既にある。第 2 版は subscript を足すとしていたが、足すと `invalid redeclaration` で手順 5 が落ちる（第 3 版で直した） |
| `testBandTonesFollowTheHolidays` で「`.none` では日曜以外の列が `.normal`」（iOS） | 期待を直して採った | 土曜は `.saturday`（青）。`.none` は祝日が無いだけで、曜日の色は 1.1 のまま（§7.2） |
| ja の `numericDate` の 0 で埋めるかを、本人の iPad の今の設定画面を見て決める（iOS） | 採らない（同じ指摘のもう一つの案「ja は 1.1 と同じ `Date.FormatStyle(date: .numeric, …)`」を採った） | 本人の端末を見ても 1 つの端末・1 つの iOS の版の字が分かるだけで、版が変われば変わりうる。1.1 と同じ式を通せば、同じ端末で同じ字になることが作りで保証される（0-33） |
| 二倍長の写真に Kit の字も入れる（KitStrings に DEBUG の `doubled` の切り替え）（iOS） | 採らない（同じ指摘のもう一つの案「範囲を書く」を採った） | Kit の字の長さは `PaperFitTests` と L-12、漏れは L-2 と `KitStringsTests` で見られる。切り替えを足すと Kit の関数の道が増え、J-3 の確かめが複雑になる |
| CI の XcodeGen の版を固定する（iOS） | 一部（版と `knownRegions` を記録するだけ） | brew では古い版を選べない。守りは「Localized bundle check」が 10 の `.lproj` を毎回確かめること（§2.2） |
| `HolidayStore.repositoryDirectory` を `#if DEBUG` にする（iOS） | 形を変えて採った（場所の関数を各テストのターゲットと KitChecks に移し、Kit の公開 API から外した） | typecheck.sh は `-D DEBUG` なしで Kit を組むので、`#if DEBUG` にすると HolidaysTests の型の確かめ（手順 6）が落ちる。配信するモジュールに組み立て機のパスが入らない点は同じく満たす |
| 発表前の年の CN・TW・VN の祝日に全部 estimated を付ける（祝日） | 一部（CN と VN は全部に付ける。TW と RU・BY・KZ・UZ は年の注記「発表前の推定」だけ） | 台湾の 2026 年の祝日は法の規則（週末に当たれば前後の平日を休み）で決まる日で、0.83 は 2025 年の改正（孔子誕辰・臺灣光復・行憲の 3 つ）も入っている（実測）。ロシアなども祝日の日付は法で決まり、毎年の通知で変わるのは休みの移し替えだけ。全部に「（推定）」を付けると、正しい日まで疑わしく見える。中国とベトナムは連休の長さそのものが毎年の通知で決まる |
| データの範囲の外の年を、年・月のページの脚注にも出す（祝日） | 採らない（設定の行と選ぶ画面だけに出す） | 紙に字を足すと F-2・F-3 の枠を取り合い、D9・K-6（祝日と言語で紙の形を変えない）に触れる |
| 州の表示名を「画面の言語の系統の別名 → 英語らしい別名 → 最初の別名 → code」で選ぶ（祝日） | 一部（ライブラリの順で略号を除いた最初の別名） | 別名がどの言語かはデータに書かれておらず、gen.py が確かに見分けられない。ライブラリの順は英語か現地語の正式名が先（NZ・CA・FR で確かめた。§5.2） |
| 州・地域のコードを安定した ASCII の id（NZ-STC など）に置き換える（祝日） | 採らない（同じ指摘のもう一つの案「1〜40 字を大文字小文字を区別せず照らす」を採った） | 記録の値がデータの表記と同じなら、版を上げたときの照合が簡単。0.83 の全部の州のコードが 1〜40 字の `[A-Za-z0-9 ]` に入り、大文字小文字だけの衝突も無いことを確かめた（0-28） |
| `requirements.txt` を依存も含めて hash で固定（`--require-hashes`）（祝日） | 第 3 版で全部採った（M7B-10 が「はい」になり、リードが wheel を取り寄せるときに hash を足す、§5.1） | 第 2 版では wheel が手元に無く、取り寄せはダウンロードなので本人の「はい」が要った。dist-info の `RECORD` の sha256 を `SOURCE.json` に書くこと（§5.1）も残す |
| KitChecks で LICENSE・CONTRIBUTORS を venv の dist-info とバイト単位で照らす（祝日） | 形を変えて採った（gen.py が生成のときに照らし、KitChecks は `SOURCE.json` の sha256 と `HolidayDataLicense.mitText` で照らす） | CI に venv は無い（CI では python-holidays を入れない、§5.1） |
| 英語の日の写真に祝日を入れるため `--screenshot-day` を足す（本人） | 採らない（同じ指摘のもう一つの案「期待を直す」を採った） | 写真モードの日（毎月 7 日）は「今日」の丸や予定の見本とつながっていて、変えると日本語の写真（J-4）の作り方と分かれる。祝日の入った日の題名は `testHolidayInTheDayTitle` と月の写真の 10/12 で見られる |
| 日本語の画面の国の一覧を読みの順に並べ、「かんこく」でも当たる検索（本人） | 一部（先頭の近道 2 行と、国のコード・英語の国名での検索） | 端末の機能に国名の読みが無い。読みの表を自前で持つと、249 の国名の読みを作って確かめる仕事が増える |

#### 第 3 版で採らなかった案・形を変えて採った案（2026-11-01 の洗い出し 2 本と 1.1 からの申し送りから。ほかは全部そのまま採った）

| 案（出どころ） | 扱い | 理由 |
| --- | --- | --- |
| 記録のシート（`InkTraceSheet`）を Views/ に移して訳す（洗い出し） | 採らない（0-37） | `Ink/InkTrace.swift` の sha256 が変わり、D14 の凍結を狭めることになる。記録のシートは TestFlight と審査のビルドだけで、使うのは本人（日本語）だけ |
| Views/ に訳した写しのシートを置き、設定からはそちらを開く | 採らない | 凍結したファイルに使われない型が残り、例外の表もそのまま要る。得るものは本人の使わない言語の 4 語だけ |
| ツールバーの訳語を、申し送りの (a)〜(c)（短い語・lint・幅の XCTest）だけで扱い、ボタンは名前で広がるままにする（1.1 からの申し送り 2） | 形を変えて採った（F-12: ja 以外は名前の枠を固定して縮める。(b)・(c) は L-12 と `ToolbarFitTests` として残す） | fr・it・pt-BR・es のふつうの語では、iPhone 17 の 9 pt の余裕に入らない（§4.4 の実測）。ボタンを広げなければ、どの言語でも 1.1 の見える範囲が保たれ、語の選び方は 47.5 pt の上限だけになる |
| 消しゴムの説明の 1 行の形を別のキーにするか、改行を言語ごとの区切りに置き換える（1.1 からの申し送り 3） | 採らない | 1 行の形を使うのは ja で走るテストだけ（§4.4）。キーを足すと、画面で使わないキーを 9 言語で訳すことになる |
| 説明の各行の上限を、全部のキーで ja のいちばん長い行（155 pt）にそろえる（洗い出し） | 形を変えて採った（キーごとに、そのキーの ja のいちばん長い行） | 消しゴムの説明（ja は 144 pt）が 155 pt まで伸びると、消しゴムの行が ja より 11 pt 広くなり、11 インチなどで 1.1 より見えなくなりうる。キーごとにすれば「どの行も ja 以下」が成り立つ |
| UI テストの段の上限を 25 → 35 分にする（洗い出しの 1 本） | 40 分にした（もう 1 本の案） | ふだん約 16 分の段に 2.5 倍の余裕。ジョブの上限は、見直しで 99 → 110 分にした（56 − 4 + 3 + 40 ≈ 95 分に 15 分の余裕） |
| 祝日の読み込みの時間を `ContinuousClock` で測ってもよいとする（洗い出しの 1 本） | 採らない（`Date` の差だけ） | `Date` なら、理由の申告が要る API かどうかを考えずに済む。ログは DEBUG と写真モードだけで、ms の精度で足りる |
| B_DESIGN §13 の M7_PLAN の差し替えを、1.2 で全部行う | 採らない（版の番号と順だけ、§6.8） | 中身（§1.2 の 1 ページ 1 キャンバス、K-10、§2.4 の案の比較など）は 1.3 の設計そのもので、1.3 の契約で確かめながら直す方が食い違いが出ない |
| 英語のページを本人の答えのとおり 1.2 を出す日に公開し、1.2 のアプリからも英語のページを開く（第 2 版の M7B-3 の扱い） | 採らない（0-38） | 審査は公開より前なので、その間アプリと Connect の英語のリンクが開かない（自動更新の購読のアプリは、規約とプライバシーポリシーの開けるリンクが求められる）。1.2 は日本語のページを開き、英語のページを開くのは 1.3 から |

#### 第 3 版の見直しで形を変えて採った指摘（2026-11-01 の見直し 2 本から。blocker・major は全部入れ、minor も全部入れた。下は、入れ方を指摘の案から変えたものか、足したもの）

| 指摘（見直し） | 扱い | 理由 |
| --- | --- | --- |
| M7B-21 を、代償・時期の条件・返事の期限を足した問いに直してから聞く（本人の目線。blocker） | 同じ指摘のもう一つの案「聞かずに本人の元の答えのままにする」を採った（代償・条件・期限は §9 の表に書き、本人が自分から望んだときだけ使う） | 本人は他の言語を読めず、英語のページと日本語のページの食い違いを自分で確かめる手段が無い。本人の答え（1.2 を出す日に公開）のままなら食い違う期間が無く、1.1 の文が英語で先に出ることもない。失うのは「1.2 から英語の画面で英語の規約が開く」ことだけで、1.1 と同じく日本語のページは開く |
| `app/en/index.html` を公開する物の一覧に名前を出して見せる（本人の目線） | 作らない（同じ指摘の「要らなければ作らない」） | アプリも Connect も 3 つの文書を直接開く。M7B-3 で聞いたのも 3 つのページで、4 つ目を足すと聞いていない物が増える |
| 日本語のページに English へのリンクを足したいなら、公開前の確認ではっきり聞く（本人の目線） | 第 3 版は 1.2 では足さない（聞かない）。**第 4 版で聞くことにした（M7B-23）** | M7B-17 の「はい」の範囲の外。第 3 版の理由は「足さなくても英語のページから日本語のページへは行ける」だったが、EU で売ると、EU の人が設定から開くページが日本語だけで行き止まりになる |
| 新機能の文と FAQ に「端末の表示は日本語のままにできます」を足すかを、X・L と決める（本人の目線） | 契約で決めた（ja の新機能の文と FAQ に「追加するときに、端末の表示をどちらの言語にするか聞かれたら、今の言語のままを選んでください」を足す、§6.3・§6.4） | 本人の手順 5 と同じ問いに、利用者も出会う。X・L が言語ごとに決めると文がそろわない |
| 投げなわのメニューの上限を、iPhone 17 の幅から「3 つの訳の合計 約 250 pt」にする（実装の見直し） | 目安を 220 pt にした（いちばん狭い対応機種の縦 375 pt から、§4.5 の F-15） | iOS 17 が動く iPhone SE（第 2・第 3 世代）や 13 mini などは縦 375 pt で、250 pt だと約 30 pt はみ出しうる。`minimumScaleFactor` は使わない（`.fixedSize()` の下では効かず、効かせるには U の `CalendarRootScreen` の置き方を変えることになる） |
| 月の tone の渡し漏れを、表の 1 行と `testWorkdayToneIsNormal` の中身で防ぐ（実装の見直し） | そのまま採り、加えて `LayoutMath.tone` の `workday:` の既定値をなくし、G-4 に作り物の暦「W」を足した | `LayoutMath` は Layout の内部の型で、既定値をなくしても公開 API と既存のテストに響かない。1 か所でも渡し忘れると組み立たなくなり、テストより先に見つかる |
| 年のページで、ja の道を F-1・F-2 に足す（実装の見直し） | F-3・F-10 にも広げた（§4.1 の見出し） | ja の字が今の枠に入るなら同じ絵になるはずだが、倍率や部品で入らないことがあると、1.1 は「…」、1.2 は縮める、と分かれる。ja を全部 1.1 のコードの道にしておけば、J-4 で見るまでもなく同じになる |
| F-1 の数字の枠を、右端はそのまま左へ広げる（実装の見直し） | そのまま採り、§1 の「違ってよい」に 1 つ足した | 今日が 31 日のときだけ、ja の年のマスの「31」が欠けなくなる。§1 の約束（日本語の画面は 1.1 と同じ）の例外として書いておかないと、約束と食い違う |
| `git archive $(git stash create \|\| git rev-parse HEAD)`（実装の見直し。表の中なので縦棒を `\|` と書いた） | `ref=$(git stash create); git archive "${ref:-HEAD}"` にした（§8 の 1） | `git stash create` は変更が無いと何も出さずに 0 で終わるので、`\|\|` の後が走らず、`git archive` に空の引数が渡る（この Mac で確かめた） |
| 2/15 の決まりで「Duo の版が 1.3、B-1 が 1.4 になり、後ろは 1 つずつずれる」（本人の目線） | 「入れ替わるだけで、1.5 指で予定 から後は変わらない」と書いた（0-27、§6.8） | 2 つの版の順が入れ替わるだけで、版の数は変わらない |
| §8 の 9 の手順 1〜8 を「ふだん使う iPad（Air 11）で。手順 5 だけ iPad mini でも」のように決める（本人の目線） | iPad mini に決めた | 本人がふだんどの iPad を使うかは記録に無い。mini はいちばん狭く、英語の字の切れ（週の題名・太さの名前・投げなわのメニュー）を 1 台で見られる |

#### 第 4 版で採らなかった案（2026-11-04 の調べ 2 本と、書くときに変えた所）

| 案（出どころ） | 扱い | 理由 |
| --- | --- | --- |
| 週のページに新しい接頭辞（`ws-` など）を使う（週の調べ） | 採らない | 古い端末の `PageNavigation.parse` が週のページとして読めなくなるだけで得が無い。`w-<日曜>` は古い端末で壊れないことを本物のコードで確かめた（§10.2） |
| 隠れる線を今の表のマスへ写す（新しい id ＋墓標）（週の調べ） | 採らない（D17） | 切り替えただけでデータが書き換わり、戻しても元の位置に戻らない。別の端末にも同期で伝わる |
| 月のページに 7 行目を足して隠れる日を出す（週の調べ） | 採らない | 紙の形が変わり、一覧の倍率も変わる。日曜の道だけ別の形になる |
| 隠れる線を何も知らせない（週の調べ） | 採らない | 「消えた」と思われる |
| 切り替えのときに全部の月を調べて本数を出す（週の調べ） | 採らない | `peek` は線の id しか読まないので全ページを読み直す必要があり重い。開いたときの 1 回と切り替えの文で足りる |
| 週の始まりの設定を iCloud（KVS）で同期する（週の調べ） | 採らない（D16） | 書いている最中に別の端末の操作でページが変わる。entitlement と capability を足すことになり、`SyncEngine`・`InkPageRecord` は凍結で入れられない。自動の意味も決めにくい。後の版で足せる |
| 週の始まりの実装の役を新しく立てる | 採らない（§10.9） | `PageNavigation` は K2、`CalendarRootScreen` は U、見出しは P の持ち物で、別の役にすると並行の組み立てで衝突する |
| `ExportBuilder` の週の始まりを U の仕事にする（週の調べ） | 形を変えて採った（S2） | `ExportBuilder` は §0 で S の持ち物。1 つのファイルの持ち主は 1 人。祝日と同じく U の `WeekStartChoice.current` を読むだけ |
| 公開の順「届け出 → 規約 → EU を入れる → 1.2」（作業の前提の案） | 採らない（§11.1） | 最後の 2 つが逆。配信の国は版と別の設定で即時に効くので、先に入れると日本語だけの 1.1.1 が EU に出る |
| nl-NL・sv のロケールに 1.2 から英文を入れる（EU の調べの別案） | 採らない（§11.2） | 確実だが、オランダ語の欄に英語を入れることを Apple がどう見るか確かめられず、確認表も 2 つ増える。en-GB で英語が出る見込みが高いので先に測る |
| 第 12 条を EU の人だけ居住地の法律に替える（EU の調べ） | 今は採らない（§11.6 の 2 で聞く） | 小さい直しから。T-6 で強行規定の断りを書く |
| `store-shots` を 9 組のまま、es-ES は es の写真、en-GB は en の写真で兼ねる（EU の調べ） | 形を変えて採った（11 組。§7.5） | 週の調べの「その地域の新しい方が見る並びで撮る」と合わせた。スペイン・英国・豪州は月曜、es_MX・en_US は日曜で並びが違う。fr-CA だけは日曜の地域だが、写真の枚数を増やさず fr（月曜）で兼ねる |
| `l10n-shots` の fr・de・it の地域を CH のままにする（第 3 版） | fr_FR・de_DE・it_IT に変えた | 主な読み手が変わった。どれも月曜で、祝日の期待の写真は変わらない（期待を書いた `de` の写真は設定のシートだけ） |
| `DATA_1_1.sha256`・`Text11` の名前を 1.1.1 に合わせて変える | 採らない（§1.5） | C1・K1 の成果と CI と次の版の契約が名前を読む。中身の基準だけ移し、M7B.md に書く。段の名前だけ「since 1.1.1」にする（まだ build.yml に入っていないので手間が無い） |
| `Text11` を 1.1.1 から写し直す | 採らない（§1.5） | 1.1.1 は字の関数を変えない。「以後は誰も変えない」を守る。差分を見て確かめるだけ |


## 10. 週の始まり（第 4 版。O-2、K-11。担当 K2・U・P・S2。C・X・R・LA2 にも分がある）

**本人に説明して了承をもらった内容**: 今お使いの方は月曜始まりのまま／週のページの手書きは月曜始まりと日曜始まりで別々に保存する（切り替えると、もう一方の手書きは元に戻すまで見えないが消えない）／月のページの手書きは日付についていく。この節はその実装の形。

**作れることの確かめ（2026-11-04 の調べ）**: `WeekStart` を既定の引数 `.monday` で渡す案を Kit の写しに当てると（差分 87 行）、KitChecks 25,452 件が確かめを 1 つも直さずに全部通り、InkModel の凍結 7 ファイルは 1 バイトも同じ。既定を日曜にすると FAIL が 191 行出て compat の所で止まる（既存の確かめが月曜の道の後戻りを捕まえる）。本物の 1.0（a21e469）と 1.1（e7b4d2f）の Kit で `w-<日曜>` を試すと、読む・保存の形・merge・BandMigration・書き出しと取り込みが全部無事で失敗 0。**確かめていないこと**: 1.1.1 の本物（§10.8 の C の段で）、iOS の地域の値（測ったのは Mac の ICU）、画面と同期の実動作（読んだだけ。CI の新しいテストで）。

### 10.1 型と渡し方（K2）

```swift
// TegakiKit/Sources/DayKit/WeekStart.swift（新規）
public enum WeekStart: String, CaseIterable, Sendable, Codable {
    case monday, sunday
    public var firstWeekday: Int                        // DayKey.weekday: 1 / 0
    public var order: [Int]                             // [1,2,3,4,5,6,0] / [0,1,2,3,4,5,6]
    public func column(of day: DayKey) -> Int           // (weekday − firstWeekday + 7) % 7。月曜は 1.1 の (weekday + 6) % 7 と同じ値
    public func firstDay(of day: DayKey) -> DayKey
    public init?(weekPageDate day: DayKey)              // 月曜 → .monday、日曜 → .sunday、他 → nil
    public static func automatic(region: String?, firstDayOfWeek: Locale.Weekday) -> WeekStart
    //   region が nil か "JP" → .monday、firstDayOfWeek が .sunday → .sunday、他（月・土・金）→ .monday
}
// TegakiKit/Sources/InkModel/WeekStartImpact.swift（新規。既存の InkModel は変えない。凍結の表に入れない）
public enum WeekStartImpact {
    public static func hiddenStrokeIds(in page: InkPage, weekStart: WeekStart) -> [String]    // m1- の生きた線のうち、.day のマスが今の 42 日に無いもの（§10.2）
    public static func weekPages(_ ids: [String]) -> (monday: Int, sunday: Int)               // w- の id を日付の曜日で数える（id だけ。ファイルは読まないので、線を全部消したページも数える。文は「週のページが」と書く、§10.4）
}
```

- **DayKit に置く**（DateText と Layout の両方が使う。`MonthLayout` の `@_exported` でアプリからも見える）。
- **Layout は純粋な関数のまま**: 地域も UserDefaults も読まない。`weekStart` は `holidays:` と同じくただの入力。
- **`PageLayout` の約束は変えず、レイアウトの型に項目も足さない**（凍結した `Ink/*` と `InkCanvasViewTests` が使う memberwise の形を守る）。画面が並びを知りたいときは `layout.rows[0].days`（月）・`layout.days`（週）から読む。
- **Kit は既定 `.monday`、アプリは必ず渡す**（D15）。凍結したファイルと既存のテストを通すには既定が要る。既定があるとアプリの渡し忘れが組み立ちで止まらないので、L-13 で止める。Kit の中の渡し漏れは G-5（§10.8）で止める。

**Kit で変える所**（全部最後の引数に `weekStart: WeekStart = .monday`。K2 の `holidays:`・`language:` の後）:

| 関数・型 | 直し |
| --- | --- |
| `MonthLayout.firstGridDay`・`rowCount`・`grid`（2 つ） | 引数を足す。`mondayOnOrBefore` は残す（1.1 の公開 API。呼び出しを減らすだけ） |
| `PageNavigation.pageId`・`dayRange`・`title`・`compactTitle` | 引数を足す。**`parse` は変えない**（日曜の id もそのまま読める）。`move`・`initialScrollX`・`initialScrollY` は ±7 日と配列から探すだけなので変えない |
| `WeekLayoutInput`・`WeekLayoutEngine` | init に `weekStart:`、項目 `monday` は `firstDay` に（テストは読んでいない）。ページの id と帯に渡す |
| `AllDayBandEngine.week` | `week(firstDay:weekStart:events:now:calendar:holidays:)` を本体にし、`week(monday:…)` は `.monday` で呼ぶだけで残す（既存のテストと KitChecks が使う） |
| `MonthLayoutInput`・`MonthLayoutEngine` | `weekStart:` を足し、`grid(for:)` に渡す |
| `StrokeBudget.pageLabel` の週 | **ページの日付から形を読む**（`WeekStart(weekPageDate: d) ?? .monday`）。`weekStart:` は足さない。**形は §0 のとおり 2 つ**（`pageLabel(_:)` と `pageLabel(_:language:)`。既定値付きの 1 つにすると `.map(StrokeBudget.pageLabel)` が組み立たない。テストの `.map` はそのまま `pageLabel(_:)` に当たる） |
| `AppExport.pdfFileName` | `weekStart:` を足す（週の題名がファイル名に入る。データの関数ではない） |
| `DateText.weekTitle` | 引数の名を `first:` に（K1 の成果への追加の段、§12.1 の K1+）。`mondayFirst` は残す（`WeekStart.monday.order` と同じことを確かめる） |
| 説明の注記だけ | `MonthLayout`・`MonthPageLayout`・`AllDayBand`・`WeekLayoutEngine`・`PageLayout`・`DayKey` の「Monday」の注記、`kit-K.json` の comment（値は変えない） |

`probe-week/trial.diff`（試しの差分。scratchpad）は動きを確かめるためのもので、そのまま入れない。契約の形との違いは 4 つ: `automatic` の引数（試しは `firstWeekday: Int`）／`AllDayBandEngine` の本体／`WeekLayoutInput.monday` の名前／`pdfFileName`・`WeekStartImpact`・DateText の直しが入っていない。

### 10.2 ページの id とデータ（K-11 の中身）

**週のページ**: `w-<その週の最初の列の日>`（例 `w-2026-11-01`）。週の手書きは 1 つのマス `grid` に紙の座標で入っていて x が列に結び付いているので、同じ線を別の並びで見せられない。だから別のページにする（本人の了承どおり）。新しい接頭辞（`ws-` など）は採らない（§9.1）。既存の iOS の端末に `w-<日曜>` のページは無い（`pageId` は月曜しか作らず、100 年分で確かめた。Web の取り込みは断る）。

**確かめた結果（本物のコード。2 列とも失敗 0）**:

| 試し | 1.0 | 1.1 |
| --- | --- | --- |
| `InkPage(json:)` で読んで同じページ（線 2・墓標 1） | ○ | ○ |
| 保存の形（`InkPageCodec`）の往復 | ○ | ○ |
| `BandMigration`: 動かす線なし、同じページ | ○ | ○ |
| merge: 和集合、墓標が勝つ、id は変わらない | ○ | ○ |
| 2000〜2099 年の全部の日で月曜の id しか開かない（2026-11-01 を開くと `w-2026-10-26`） | ○ | ○ |
| アプリの書き出し → 取り込み: ページがそのまま入る、skipped 0、書き戻しのバイトも同じ | ○ | ○ |
| Web の形式の日曜 `w-`: `.legacyPageId` で断る | ○ | ○ |
| 月のページ: 12/12（1.0 の表に無いマス）の線は描かれず、読む・merge・書き出しで残る | ○ | ○ |
| 月のページ: 表に無いマスの背の高い線で紙が伸びない | ○ | ○ |
| 取り込みの予算の確かめ・本数はそのページだけで数える | — | ○ |

同期と台帳は読んで確かめた（`SyncEngine` の `save`・`mergeRemote`・`cloudErase` は id の形を見ず、レコード名は pageId そのもの。ファイル名は `w-2026-11-01.json.lzfse`）。F1・F2 のとおり。

**古い端末で起きること**:

| 場面 | 1.0 / 1.0.1 | 1.1 / 1.1.1 |
| --- | --- | --- |
| 同期で届く | 保存して持っている。開かない。**見えない・消えない** | 同じ |
| 消しゴム・投げなわ | 開かないので届かない | 同じ |
| 書き出しと取り込み | そのまま運ぶ | 同じ |
| 「この端末の手書きを全て消す」（F7） | 全部のレコードを消すので **日曜のページも消える** | 同じ |
| 線の予算の案内（15,000 本） | 無い | 開かないので出ない |
| 設定 › 情報の「いちばん線の多いページ」 | 無い | 本数は正しい。**そのページが一番多いときだけ、題名が 6 日ずれる**（`w-2026-11-01` が「週のページ（2026年10月26日〜11月1日）」。直せないが害は小さい） |
| 月のページの、自分の表に無いマスの線 | 描かない・消さない（F1）。そのマスには書けない | 同じ |

**1.2 の中の扱い**:

- **書き出し（JSON）**: 設定に関係なく両方の形の全部のページを入れる（`store.allPageIds()` は id を選ばない）。**週の始まりの設定は入れない**（K-5。`v` も上げない）。戻すと線は戻るが、設定は端末のまま。
- **取り込み（アプリの形式）**: どちらの形も受ける。入れた後、今の設定と違う形の週のページがあれば結果の文に 1 文足す（§10.4 の `import.otherWeekStart.*`。文と型は S2、`WeekStartImpact.weekPages` で数えて値を渡すのは U。§0、§10.5）。
- **取り込み（Web）**: 常に月曜のページに入る（`WebImport` は凍結で、既定の月曜の表で読む）。日曜の設定の人には同じ 1 文が出る。**Web の形式の日曜 `w-` は今後も legacy として断る**（Web 1.0.4 で月曜のページへ写し済みの古い紙で、取り込むと同じ線が二重になる。アプリの日曜ページとは別物）。
- **PDF**: 今のページの絵と題名をそのまま。ファイル名の週の範囲も日曜から。
- **線の本数の案内**: ページごと（K-9）。両方の形は別に数える。**隠れている線も月のページの予算に数える**（`budgetCount` は全部の生きた線）。`pageLabel` は日付から形を読むので 1.2 では正しい（「週のページ（2026年11月1日〜11月7日）」）。案内済みの一覧（`strokeBudget.noticedPages`）も id ごとで変更なし。
- **全部消す**: F7 のとおり両方の形も隠れた線も全部消える。文は「全て消す」で意味が合うので変えない（J-1）。

**月のページ**: id は同じ `m1-YYYY-MM`（"m1" は歴史の名前で、並びの意味は無い）。線はマス相対なのでマスについていく（例: 10/11 のマスは月曜始まりで (1200, 175)、日曜始まりで (0, 350)）。紙の幅と 6 行 42 マス ＋ メモは同じ。予定と手書きの量が同じでも、行の組み合わせが変わるので行の高さは変わりうる（K-4 の範囲）。終日の帯も行で切れる位置が変わる（金〜月の予定は日曜始まりで「金・土」と「日・月」の 2 本）。

**片方の並びにしか無い日**（2000〜2099 年の 1,200 か月を計算）: **月の中の日は、どちらの並びにも必ずある**。違うのは前後の月の薄いマスだけ。1 日が日曜の月（172 か月）は **6 日**、それ以外（1,028 か月）は **1 日**。例:

| 月 | 月曜の表にだけある | 日曜の表にだけある |
| --- | --- | --- |
| 2026-10 | 11/8 | 9/27 |
| 2026-11（1 日が日曜） | 10/26〜10/31 | 12/7〜12/12 |
| 2026-12 | 2027/1/10 | 11/29 |
| 2027-02 | 3/14 | 1/31 |

各月の薄いマスの線はその月のページの線で、隣の月の同じ日とは別物（今もそう）。だから隠れた線は他のページでも見えない。

**隠れる線の扱い（D17）: 動かさない。描かない。消さない。開いたときに 1 回だけ本数を知らせる。**

- 凍結した `Ink/InkLedger`（レイアウトに無いマスの線は「描かず・消した扱いにせず」）と `Ink/InkSnapshot`（PDF も同じ）がそのまま守る。消しゴムと投げなわも届かない。凍結のコードは変えない。
- `show()` の読み込みの後で `WeekStartImpact.hiddenStrokeIds` が 1 本以上で、その「ページと形の組」でまだ案内していなければ、知らせを積む（§10.4 の `toast.weekStart.hiddenInk` と「トーストの出し方」）。設定のシートの中で切り替えたときは、シートが閉じてから出る。**記録は実際に出した時に** `weekStart.hiddenNoticed`（`strokeBudget.noticedPages` と同じく最大 500 件。端末だけ）に書く。写真モードでは出さない。
- 月曜のまま使う人には出ない（月のマスは必ず表の中に作られるので本数は 0。J-4 の写真に影響しない）。

**本人に知らせる小さなこと: 週末をまたぐ線**（§9。了承のときの説明には入っていない）: 線は 1 本ごとに「外接矩形の中心があるマス」についていく。だから土曜と日曜にまたいで書いた言葉は、日曜始まりでは **2 か所に分かれる**（右端の土曜と次の行の左端の日曜。月のページによく書く、週末の旅行の予定などで目立つ）。1 本でまたいだ矢印は、中心が土曜なら紙の右端からはみ出す（土曜が右端の列になるため）。日曜の中心で左へ伸びる線は紙の左端からはみ出す。消えず、戻せば元の形。週のページは別ページなのでこの問題は無い。手順 4d で実際に 1 語書いてもらい、FAQ にも書く（§10.4）。

### 10.3 既定と移行（U。§1.4 の `HolidayChoice` と同じ考え方）

キー（`AppSettings`。全部端末だけ）: `weekStart.setting`（"auto"・"monday"・"sunday"）、`weekStart.lastAuto`、`weekStart.dataChecked`、`weekStart.hiddenNoticed`。

`WeekStartChoice.migrateIfNeeded` を `CalendarRootScreen.init` の頭、`HolidayChoice.migrateIfNeeded` と並べて呼ぶ（写真モードでは呼ばない）:

1. 記録があれば何もしない（**判定は 1 回だけ**）。
2. `onboardingDone`・`lastPageKind`・`allowFingerDrawingChosen` のどれかがあれば **"monday"**（今お使いの方。地域に関係なく）。
3. どれも無ければ **"auto"**（2 回目の起動で 2 に当たらないよう必ず書く。§1.4 の第 1 版の誤りと同じ所）。
4. **iCloud のページに合わせる（1 回だけ）**: 判定の材料は端末の記録だけなので、今お使いの方の 2 台目や入れ直しは 3 に落ちる。米国の地域なら日曜になり、月曜のページに書いた週の手書きが消えたように見える。iPhone は週のページで始まるので（`CalendarRootScreen.init` の `fallbackKind`）、最初の pull の間や offline の間に 1 本書くと日曜のページもできる。そこで、設定が "auto" で `weekStart.dataChecked` がまだなら、**pull が 1 度終わった後に 1 回だけ** 端末のページと照らす。逆向き（日曜の人が日本の地域で入れ直す）も同じ。**書いている最中には切り替えない。黙らない。** これは本人の了承（今お使いの方は月曜のまま）を守るための道なので、下の 4 つを崩さない。

   **(1) いつ判定するか**: `WeekStartChoice.readyToCheck(status: sync.snapshot.status, zoneToken: sync.state.zoneToken)`、つまり `.synced` **かつ** `zoneToken != nil`。`.pushOnly` は pull をしないので、pull が失敗して `.offline` になった後に線の保存から push だけが成功すると、まだ月曜のページが届いていなくても `.synced` になる。その回を判定に使って `dataChecked` を立てると二度と判定しない。**`snapshot.lastSyncAt` は印にならない**（`pull` のほかに、`push` の各レコードの保存と `cloudErase` でも書かれるので、この道で nil でなくなる）。`zoneToken` を書くのは `pull`（`fetchChanges` が全部の変更を取り終えた後）と `cloudErase` だけで、`SyncEngine.state` は `private(set)` なので凍結のファイルを変えずに読める。この前提は `testPushOnlyLeavesNoZoneToken` で固定する。見る所は `syncStatusChanged()` の中と、**`appear()` の中で今の状態を 1 回**（`SyncEngine.start()` は `AppDelegate` で先に走るので、画面の `.onChange` より前に `.synced` になった回は見えない。`.accountMismatch` の見直しと同じ）。iCloud を使わない人（`.localOnly`）には `.synced` が来ないので、アプリの形式の取り込みの後にも判定する（`runImport`、§10.5）。**iCloud を使う人は最初の pull の後に `dataChecked` が立つので、その後の取り込みでは判定しない**（`import.otherWeekStart.*` の 1 文だけで知らせる）。

   **(2) どう決めるか**（純関数 `WeekStartChoice.dataCheck`。`sync.allLocalPageIds()` の `w-` を `WeekStartImpact.weekPages` で数える。ファイルは読まない。`dirtyPageId` は `pageDirty` のときの今のページの id で、まだファイルに無ければ今の形のページとして数える）:

   | ページ | 結果 | 書くもの | 知らせ |
   | --- | --- | --- | --- |
   | 週のページが無い、または今の形だけ | `.finish` | `dataChecked = true` | なし |
   | 違う形だけ | `.adopt(その形, otherPages: 0)` | その形を明示の設定に、`dataChecked = true` | `toast.weekStart.adopted.*` |
   | 両方あり、もう一方の形の方が多い | `.adopt(その形, otherPages: 今の形のページ数)` | 同じ | `adopted` と `toast.weekStart.otherForm.*`（今まで見ていた形のページ数） |
   | 両方あり、同数か今の形の方が多い | `.stay(otherPages: もう一方のページ数)` | `dataChecked = true`（設定は "auto" のまま） | `toast.weekStart.otherForm.*` |

   両方あるときに黙らない: 第 4 版の下書きの「両方の形があれば何もしない」だと、最初の pull の前に日曜のページへ 1 本書いた人は月曜の手書きを知らせなしで見失い、設定の脚注に気づくまで分からない。

   **(3) 書いている最中には切り替えない**: 合わせる操作だけが利用者の操作なしに走る。Pencil が紙に付いている間に `.id` が変わるとキャンバスが壊され、delegate が外れるので書いている線は台帳に入らず失われる。書き終えて 1.5 秒未満の線は `pageDirty` のメモリの中だけなので、切り替えの `saveNow` で別の形のページに保存され、今書いたばかりの線が画面から消える。だから `.adopt` になるときは、`pageDirty == false` **かつ** この起動で `onPenDown` が来ていない（U が `penTouchedThisLaunch` を持つ。`penDown()` は toolbar の形が変わらないと頭の guard で帰るので、**guard の前で**立てる）ときだけその場で切り替える。それ以外は `dataCheck` が `.wait` を返すので、設定も `dataChecked` も書かず `pendingAdoption = true` を持ち、**次の `show`（利用者のページ移動）か次の `.active` の入口で**（`atBoundary: true`）判定をやり直してから切り替える。`show` の入口では頭の `saveNow()` の直後に判定し、`.adopt` なら設定・`weekStart`・`WeekStartChoice.current` を入れてから新しいページの id を作る（再帰しない。後から来る `.onChange(of: weekStartRaw)` は `guard` で何もしない）。`.active` の入口では `saveNow()` の後に判定し、`.adopt` なら設定を書いて `.onChange` の同じ道（§10.5 の `weekStartSwitch`）を通る。`pendingAdoption` はメモリだけで、終了したら次の起動でまた判定する。`.finish` と `.stay` は切り替えないのでその場でよい。

   **(4) 知らせ**: `adopted`・`otherForm` は §10.4 の「トーストの出し方」で出す（初回案内とペイウォールの下で失わない）。

**読む値**: 記録が無い・壊れた値は `.monday`（線が動かない側に倒す）。

**自動の読み方**: 起動のときだけ `WeekStartChoice.launchAutomatic`（`static let`。中で `WeekStart.automatic(region: Locale.current.region?.identifier, firstDayOfWeek: Locale.current.firstDayOfWeek)`。`L.language` と同じく、起動中は変えない）を読む。アプリの全部（`CalendarRootScreen`・設定の節・`ScreenshotMode` の auto）は `WeekStartChoice.resolve(_:)` を呼び、`Locale.current.firstDayOfWeek` を自分で読まない（L-14）。前回の結果を `weekStart.lastAuto` に残し、地域の変更で結果が変わったら黙って変えず、トーストで知らせる（§10.4）。`Locale.Weekday` は iOS 16 から（最低 17 なので使える）。理由の申告が要る API ではない（§2.2）。

**地域ごとの値**（この Mac の ICU の実測。iOS で同じかは未確認。合わなければ設定で変えられる）: 日曜 = en_US・es_US・en_CA・fr_CA・es_MX・es_CO・pt_BR・pt_PT・zh_CN・zh_TW・zh_HK・zh_SG・ko_KR・he_IL・ar_SA・hi_IN・en_IN・th_TH・id_ID・en_ZA・en_SG。月曜 = en_GB・en_AU・en_NZ・en_IE・fr_FR・fr_CH・de_DE・de_AT・de_CH・it_IT・es_ES・es_AR・nl_NL・sv_SE・pl_PL・ru_RU・tr_TR・vi_VN・ar_AE。土曜 → 月曜に読む: ar_EG・fa_IR。金曜 → 月曜に読む: en_MV。ja_JP は ICU では日曜だが **本人の決めで月曜**（JP を先に判定）。`Locale.current.firstDayOfWeek` は端末の設定の上書きも反映する（この Mac の `Locale.current` は ja_JP で monday、`Locale(identifier: "ja_JP")` は sunday）。

### 10.4 設定の画面と文（U。トーストと取り込みの文は下の表の持ち主）

**端末ごと**（D16）: 同期にすると書いている最中に別の端末の操作でページが変わる。`AppSettings` のまま（祝日・言語とそろう）。弱点は「iPad と iPhone を別の設定にすると、週の手書きが片方に出ない」で、脚注・もう一方の形のページ数の表示・切り替えの文で補う。後の版で同期を足すことはできる（データの形に何も入れていないので）。

**節**: `calendarSection` の直後、`HolidaySettingsSection()` の前に節を 1 つ（新規 `Views/WeekStartSettingsSection.swift`）。行「週の始まり」、`Picker`（`.navigationLink`、今の「予定の登録先」と同じ）。値は「自動（日曜）」のように今の結果を括弧で見せる。

**切り替えるときの説明**: 実際の始まりが変わるときだけ出す（月曜 → 自動で結果が月曜なら出さない）。`Picker` の Binding で止め、`.alert` で聞いてから記録を書く。〔やめる〕は今の語のキーを使う。

**キー**（ja は 1.2 の新しい日本語で J-1 の表の外。23 キー。9 言語の訳と逆翻訳の対象。複数形は D5 の 2 キー）:

| キー（持ち主） | 日本語 | 英語 |
| --- | --- | --- |
| `settings.weekStart.title`（U） | 週の始まり | Week Starts On |
| `settings.weekStart.auto`（U） | 自動（%@） | Automatic (%@) |
| `settings.weekStart.monday` / `.sunday`（U） | 月曜 / 日曜 | Monday / Sunday |
| `settings.weekStart.footer`（U） | 自動は端末の地域に合わせます（日本は月曜）。この設定は端末ごとです。週の手書きをどの端末でも見られるように、同じ設定にしてください。 | Automatic follows your device region. This setting is per device. Use the same setting on each device to see the same week handwriting. |
| `settings.weekStart.otherPages.one` / `.other`（U。0 なら出さない） | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。切り替えると見えます。 | %2$@ week page(s) use the other week start (%1$@). Switch to see them.（one と other で文を分ける。`weekPages` は id だけを数え、線を全部消したページも入るので「手書きが」と言わない） |
| `settings.weekStart.confirm.title.sunday` / `.monday`（U） | 週の始まりを日曜にしますか？ / 週の始まりを月曜にしますか？ | Start weeks on Sunday? / Start weeks on Monday? |
| `settings.weekStart.confirm.message.sunday`（U） | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | Week pages are separate for weeks that start on Monday and weeks that start on Sunday. The week handwriting you have now stays hidden until you go back to Monday (it is not deleted). Month page handwriting moves to the cell with the same date. However, some handwriting in cells for days of the previous or next month may stay hidden until you go back (it is not deleted). |
| `settings.weekStart.confirm.message.monday`（U） | （上の文の「月曜始まりに戻すまで」を「日曜始まりに戻すまで」に） | （同じ入れ替え） |
| `settings.weekStart.confirm.ok.sunday` / `.monday`（U） | 日曜にする / 月曜にする | Use Sunday / Use Monday |
| `toast.weekStart.hiddenInk.one` / `.other`（U） | この月のページには、いまの週の始まりでは表示されない日に書いた線が %@ 本あります。消えていません。週の始まりを戻すと見えます。 | This month page has %@ stroke(s) on days the current week start does not show. They are not deleted. They come back when you switch back.（one と other で文を分ける） |
| `toast.weekStart.adopted.monday` / `.sunday`（U） | iCloud の手書きに合わせて、週の始まりを月曜にしました。設定で変えられます。 / （日曜にしました） | Week start set to Monday to match your iCloud handwriting. You can change it in Settings. / （Sunday） |
| `toast.weekStart.otherForm.one` / `.other`（U。第 4 版の見直しで足した。§10.3 の 4） | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ week page(s) use the other week start (%1$@). They are not deleted. Switch in Settings > Week Starts On to see them.（one と other で文を分ける） |
| `toast.weekStart.regionChanged.sunday` / `.monday`（U） | 端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは消えていません。 / 端末の地域に合わせて、週の始まりを月曜にしました。日曜始まりの週の手書きは消えていません。 | Week start set to Sunday to match your device region. Your Monday week handwriting is not deleted. / （Monday と Sunday を入れ替え） |
| `import.otherWeekStart.sunday` / `.monday`（S） | 取り込んだ週のページの一部は、週の始まりを日曜にすると見えます。 / （月曜にすると見えます） | Some imported week pages appear when weeks start on Sunday. / （Monday） |

英語の文は X が用語集に合わせて直してよい（意味は変えない）。用語集に「週の始まり」を足す（§6.2）。切り替えの文（`.confirm.message.*`）は本人の確かめ表（§8 の 9 の手順 4b）で読んでもらう。

**トーストの出し方**（`toast.weekStart.*` の 4 種。U。第 4 版の見直し）: 切り替えは設定のシートの中で起きる。トーストは `CalendarRootScreen` の本体の `.overlay` にあるのでシートの下になり、標準の 3 秒（`ToastView.duration`）で消える。iPhone ではほぼ隠れる。それで「案内済み」にすると、今開いている月のページでは二度と出ない。`adopted`・`regionChanged` も、最初の起動の初回案内とペイウォールの下で同じことになる。だから:

- `show()` や判定の中で直接 `showToast` しない。`WeekStartNotices` に積む（§0。純粋な値なのでテストで呼べる）。
- 出すのは `!sheetIsUp`・`!showAccountChange`・`toast == nil` の時だけ（`sheetIsUp` は設定・編集・取り込み・書き出し・初回案内・ペイウォールを含む。`showAccountChange` は含まない）。機会は 3 つ: 積んだとき、`sheetsChanged()` でシートが閉じたとき（今の頭の `guard accountChangePending` の **前で**。1.1.1 のピンチの案内と同じ形）、`.onChange(of: toast)` で前のトーストが消えたとき。購入の知らせの `guard !showSettings` が前例。
- `hiddenInk` はページの id を持ち、出すときに今のページと違えば捨てる（次に開いたときにまた判定する）。
- **`weekStart.hiddenNoticed` は実際に出した時に書く**（積んだ時には書かない）。`dataChecked` は判定が終わった時に書くので、`adopted` と `otherForm` は出す前に終了すると失われることがある（設定の脚注の `otherPages` は残る。害は小さいので記録を増やさない）。
- 表示は `strokeBudgetNoticeDuration` と同じ 6 秒（文が長く、3 秒では読めない）。`ToastView` は `lineLimit(3)` なので、10 言語で iPhone の幅に 3 行で入ることを `testWeekStartToastsFitThreeLines` で測る（入らなければ X が短くする）。写真モードでは出さない。

**アプリの外の文**（LA2。§12.1）:

- **新機能の文**: §6.3。
- **説明**（`docs/store/source-ja/description.txt`・`en-US/description.txt` の「月曜始まり」の文）: 「週の始まりは月曜・日曜から選べます。ページの時刻は 24 時間の表示です。」
- **審査メモ**（`docs/store/review-note.txt` の同じ文）: "Weeks can start on Monday or Sunday (Settings > Week Starts On). Times on the pages use the 24-hour clock in every language." ＋ What is new に 1 項目。**今 3,884 バイトで上限 4,000**。文を短くして超えないよう A の測り方で測る。
- **SUPPORT**（`docs/SUPPORT.md`・`SUPPORT.en.md` の「週はどの言語でも月曜始まり」の括弧）: 「（週の始まりは設定で選べます）」に。FAQ を 1 つ足す:
  - 日本語「### 週の手書きが見えなくなったときは？」本文「週のページの手書きは、月曜始まりと日曜始まりで別々に保存しています。設定 › 週の始まり が、その手書きを書いたときと同じかを確かめてください。設定は端末ごとなので、iPad と iPhone で同じにすると、どちらでも同じ週の手書きが見えます。切り替えても手書きは消えません。月のページの、前後の月の日のマスの手書きも、週の始まりを戻すと見えます。週末にまたいで書いた言葉は、日曜始まりでは土曜の分と日曜の分に分かれて見えます。月曜に戻すと元どおりです。」
  - 英語「### My week handwriting is gone. What should I do?」本文「Handwriting on week pages is saved separately for weeks that start on Monday and weeks that start on Sunday. Check that Settings > Week Starts On is the same as when you wrote it. This setting is per device, so use the same setting on your iPad and iPhone to see the same week handwriting. Switching never deletes handwriting. Handwriting in a month page's cells for days of the previous or next month also comes back when you switch back. Words written across a weekend appear split into a Saturday part and a Sunday part when weeks start on Sunday. They join up again when you return to Monday.」

### 10.5 画面と切り替えの順番（U・P・S2。ここを間違えるとデータの危険がある）

**切り替えの順番**（U）: `pageId` を `@AppStorage` から直接作らない。`@State weekStart` を持ち、順番は **static の純関数に切り出す**（`saveNow`・`pageBinding`・`@State` は private で、既存の単体テストは画面を組まない。画面のコードのままでは、いちばん危ない順番を自動で確かめる手段が無い）。`.onChange(of: weekStartRaw)` はこれを 1 回のターンの中で呼ぶだけ:

```swift
static func weekStartSwitch(old: WeekStart, new: WeekStart, save: () -> Void, apply: (WeekStart) -> Void, reload: () -> Void) {
    guard new != old else { return }
    save()        // 古いページを、古い形のまま保存（pageBinding の guard に捨てられないうちに）
    apply(new)    // weekStart = new; WeekStartChoice.current = new; viewport = .zero; capNoticedPageId = nil
    reload()      // show(kind: kind, focus: focus)。新しいページ・予定・紙を読み直す
}
// .onChange(of: weekStartRaw)
Self.weekStartSwitch(old: weekStart, new: WeekStartChoice.resolve(WeekStartChoice.setting()),
                     save: { saveNow() }, apply: { … }, reload: { show(kind: kind, focus: focus) })
```

`@AppStorage` を直接読むと、保存の前に `pageId` が変わって `pageBinding` の guard に捨てられる。キャンバスの `.id` に `weekStart` を入れる（ページの id と週の始まりの組）ので、月のページ（id が同じ）でもキャンバスを作り直し、取り消しの履歴は消える（隠れた線への ↶ が「何も起きない」のを防ぐ。ページを移ったときと同じ）。`.id` が変わると書いている線は失われるので、利用者の操作なしに切り替わるのは §10.3 の 4 の (3) の条件を満たすときだけ。写真モードは `Config.weekStart` だけを使い、記録を読まない・書かない（切り替えの道は §10.7）。

**起動の値**（U）: `init` は `WeekStartChoice.prepareAtLaunch(shot:)` を 1 回呼び、戻り値を `_weekStart` と `makePaper` に渡す。`prepareAtLaunch` は移行（写真モードでは呼ばない）の後に決めた値を `WeekStartChoice.current` に入れる（§5.6。写真モードは `Config.weekStart`）。切り替えの時だけ入れると、日曜の設定の人が起動してそのまま書き出した PDF の、絵は 11/1 からなのに題名とファイル名が「10月26日〜11月1日」になる（`ExportBuilder`・`PDFPageRenderer` の題名は `current` を読む。L-13 は引数があれば通るので見つけられない）。

**渡す所**（U。L-13 で漏れを止める）: `CalendarRootScreen` の `pageId`・`title`・`compactTitle`・`makePaper`（`*LayoutInput`・`holidayNames` の `MonthLayout.grid` も同じ値。§5.6）・`model.load`。`EventStoreModel.load(kind:focus:weekStart:)`（`dayRange` に渡す。**§0 の「持ち主の無いファイル」から外し、持ち主を U にした**）。`ScreenshotMode.demoPage(…, weekStart:)`（**渡さないと紙とページの id が食い違い、台帳が `onPageMismatch` で止まる**。水曜の見本の `2 × 列幅` も `weekStart.column(of:)` で）。

**見出し**（P）: `PaperWords.monthHeaderWeekdays(_:weekStart:)`。`StickyHeaderView` は 7 字の固定の並びと「列 5 が青・列 6 が赤」をやめ、並びは `layout.rows[0].days` の曜日から、色は **列ではなく曜日で**（土 = 青、日 = 赤）。`PDFPageRenderer` も同じ（並びと色）。週の列・年・日の見出しは日付の曜日から出るので変えない。

**書き出し**（S2。`ExportBuilder` は §0 で S の持ち物なので、調べの「U」から S2 に直した）: `title`・`pdfFileName` に `weekStart: WeekStartChoice.current`。

**取り込みの文**（文と型は S2、値は U。形は §0 で固定。S2 と U は並行なので、この形から変えない）: シートが受け取るのは `.done` だけで、ページの id を知っているのは U の `runImport`（`outcome.pages`）。`ImportOutcome` の形は凍結のファイルが使うので増やさない。U の順番: (1) `sync.importPages` (2) §10.3 の 4 の判定（まだのとき）(3) **その後の `weekStart`** で `WeekStartImpact.weekPages(outcome.pages.map(\.pageId))` のもう一方の形が 1 以上なら、その形を `otherWeekStart` にして `.done` を作る（合わせた後の設定で判定するので文と食い違わない。判定が `.wait` なら今の設定のまま）。`closeImportSheet` のパターンと `toastText` の呼び出しも 4 つ目を渡す。ページが 0 の `.done` と写真モードの `.done`（`importDemoOutcome`）は既定の nil のまま。

**変えない所**（月曜を前提に読むが、それで正しい）: `InkModel/WebImport`（凍結。日曜の `w-` は legacy、§10.2）・`InkModel/BandMigration`（凍結。昔の帯のマスだけを動かす。`列 = マスの日 − ページの日` なので日曜でも正しい列）・`Ink/*`・`Sync/*`・`Persistence/InkPageStore`（凍結。`pageId`・`dayRange`・`grid` を呼ばず `any PageLayout` だけを見る）・`MonthPageLayout.month`（「1 行目の 7 番目は必ずその月」は日曜始まりでも成り立つ、1,200 か月）・`dayAt`・`cell(at:)`・`eventDay`・`DateTap`・`LassoGeometry`（`days` の配列を引くだけで曜日を見ない）・`PageNavigation.move`・`initialScroll*`・色の `LayoutMath.tone`（日付の曜日から）・年と日のエンジン・`JapaneseHolidays`（第 n 月曜は祝日の規則）・`StrokeCensus`・`Text11`・`tools/compat10`・`Tests/Compat10`・`Tests/CompatFixtures`（K-7）。

**消す所**（U）: `EventKitService.events(in:calendars:)`（月の 42 日を返す薄い関数で、呼び手もテストも無い。残すと L-13 の `MonthLayout.grid(` で落ちる）。`events(from:to:calendars:)` は変えない。

### 10.6 B の設計（1.3）との関係

1 ページ 1 形なので、帯は「同じ形のページを並べるだけ」で成り立つ。**止まる所は無い**。はみ出す線は持ち主のページの中で完結し、もう一方の形のページは窓に入らないので、形をまたいで線が重なることは無い。K-10 にも触れない。次を B_DESIGN と 1.3 の契約に足す（C が `docs/M7_PLAN.md` の注に書く。§6.8）:

| B_DESIGN | 足すこと |
| --- | --- |
| §2.3 `SpanPlan`「週 = 月曜の通し番号 ÷ 7」 | `weekStart` を受ける。`⌊first.dayNumber ÷ 7⌋` はどちらの形でも連番で、逆は `n × 7 + (monday 4 / sunday 3)`（1970-01-01 が木曜で番号 0）。往復のテストを両方の形で |
| §2.4 の 11 `SpanGuard` | 正規表現は日曜の id も通るので変更なし。`sync.save` の入口の「この版の書く形」に日曜の `w-` を入れる |
| §3.2 の見出し「その週の月曜の月」と例 | 「その週の最初の日の月」に。日曜始まりの境目は土曜 → 日曜 |
| §3.7 設定の切り替え | 週の始まりの切り替えも「全部保存してから開き直す」（K-3）。`SpanSession` は形ごと。窓に 2 つの形を混ぜない（K-11 の 6） |
| §4.2 の表・§4.3 | K-11 の行。古い端末の表に「日曜のページは開かない」 |
| §11 | 月の帯と週の帯の fixture を日曜でも 1 組ずつ |

後の版への注意: 1.9 の `wb-` と「週の下のメモ」は、`w-` と同じく形ごとに別になる（K-11 の 6）。切り替えても見せたいなら日付を鍵にした別のページが要る。その版の契約で決める。

### 10.7 写真モードと写真（U・C）

- `--screenshot-week-start auto|monday|sunday` → `Config.weekStart`。**引数なし・壊れた値は `.monday`**（0-26 の祝日と同じ考え方。シミュレータの地域に左右されない）。`l10n.state` の名前に `;week=<monday|sunday>` を足す。`--screenshot-sheet week-start` → `Sheet.weekStart`（11 個目。月のページで設定を開き、切り替えの説明を出した状態）。
- **写真モードの切り替え**（第 4 版の見直し）: 写真モードは記録を読まない・書かないので `.onChange(of: weekStartRaw)` は発火しない。設定の節の Binding は、写真モードでは記録に書かず、`.alert` の確定で同じ `weekStartSwitch` を直接呼ぶ（`save` は `saveNow` の guard で何もしない。`apply` と `reload` は `@State` と `demoPage(…, weekStart:)` だけを動かす）。`WeekStartUITests` はこの道で「文と見出し」を見るだけで、**保存の証明ではない**（保存は §10.8 の `testSwitchSavesTheOldPageFirst` と `testSwitchKeepsBothForms`）。
- **J-4 の日本語の写真は引数なしで月曜なので 1.1.1 と同じ。違ってよい写真の一覧は §1.3 のとおり**（`sheet-settings`・`store/ipad13/06-settings`、1.2 だけの `sheet-holidays`・`sheet-week-start`）。
- `l10n-shots`: `--screenshot-week-start auto` を足す（地域に応じて en_US・zh_*・ko_KR・es_MX・pt_BR が日曜、fr_FR・de_DE・it_IT が月曜）。新しい写真は §7.5・§7.6（en の日曜の週と月、切り替えの説明、ja の日曜）。
- `store-shots`: 同じく `auto`。**各店頭の写真は、その地域の新しい方が見る並びで撮る**（米国などは日曜始まり。買った人が見る画面と同じ）。§8 の 11 の確認表で本人が見る。組の対応は §7.5。

### 10.8 テスト

**KitChecks**（K2。`section("week start (1.2)")`。「holiday geometry (1.2)」の後。件数は `compare` でまとめる。試しの 504,367 件をそのまま数えない。閾値は N − 50 の規則のまま）:

- **W-1 月曜の道が 1.1 と同じ**: 2000〜2099 年の全日付で、`pageId(.week)`・`dayRange(.week)`・`title(.week)`・`compactTitle(.week)` の既定の引数と `weekStart: .monday` が、`Text11` の式の写し（`(weekday + 6) % 7`）と 1 文字も同じ。1,200 か月で `MonthLayout.grid`・`rowCount`。
- **W-2 月曜のレイアウトが同じ**: 2026 年の月 12・週 53 を、見本の予定つきで既定と `.monday` で組み、ビット単位で同じ。
- **W-3 日曜の不変条件**（試しで 504,367 件・失敗 0）: 全部の月の最初のマスが日曜、月の中の全部の日が表にある、違うのは薄いマスだけ、違う数は 1 か 6、`layout.month`・`pageId`・43 マス・6 行、紙の大きさは予定なしで月曜と同じ。全部の週で id が日曜の `w-`、`days`、`tone`（列 0 が赤、列 6 が青）、今日の列、`dayAt`、帯、`parse` の往復。
- **G-5 渡し漏れ**（§7.1 の G-4 と同じ形）: `weekStart: .sunday` で月・週・帯・題名・ファイル名を組むと、中身の全部が日曜の並び。
- **W-4 K-11**: Compat10 の写しに日曜のページと表に無いマスの月のページを通す（§10.2 の表を `InkPageV10`・`BandMigrationV10`・`AppExportV10`・`WebImportV10`・`cellsV10`・`LedgerV10.drawnIds` で）。
- **W-5**: `pageLabel` の両方の形、`pdfFileName`、`WebImport.PageId.parse` が日曜を nil のまま、`WeekStart.automatic` の表（JP・US・GB・EG・MV・nil）、`hiddenStrokeIds`。
- **G-1〜G-3 は変えない**（G-3 の「入力の calendar の firstWeekday を変えても同じ」はそのまま成り立つ。週の始まりは別の入力）。

**XCTest**:

| 担当 | ファイル | テスト |
| --- | --- | --- |
| K2 | `Tests/LayoutTests/WeekStartLayoutTests.swift`（新規） | `testSundayMonthGrid`・`testSundayWeekPage`・`testMondayIsTheDefault`・`testBandSplitsAtSaturday`（金〜月で 2 本、`continuesRight`・`continuesLeft`）・`testYearCrossingTitle`（「2026年12月27日〜2027年1月2日」）・`testOnlyPaleCellsDiffer` |
| K2 | `Tests/InkModelTests/WeekStartImpactTests.swift`（新規） | `testHiddenStrokesOfTheMonth`・`testNothingHiddenOnMondayForMondayInk`・`testWeekPagesByForm`・`testSundayLabel` |
| K2 | `Tests/Compat12Tests/`（新しいテストのターゲット。`Package.swift` に 1 行。**Compat10Tests は 1 バイトも変えない**） | `testSundayWeekPageOnTheFrozen10`・`testHiddenCellStrokeSurvives10Merge`・`testExportFromNewCodeReadBy10` |
| U | `WeekStartChoiceTests.swift`（新規） | `testExistingUserKeepsMonday`（3 つのキーのどれか 1 つで、米国の地域でも）・`testNewUserIsAutomatic`・`testNewUserStaysAutomaticOnSecondLaunch`・`testMigrationRunsOnce`・`testBrokenValueReadsAsMonday`・`testJapanIsMondayOnAuto`・`testSaturdayRegionIsMonday`・`testAdoptsOnlyFormFromCloud`・`testBothFormsAdoptTheLarger`・`testBothFormsNotifyOnce`・`testPushOnlySyncedDoesNotFinishTheCheck`（`readyToCheck`: `.synced` で `zoneToken` が nil なら判定しない）・`testAdoptionWaitsWhileWriting`（`dirtyPageId` か `penTouched` で `.adopt` が `.wait` になり、`atBoundary` で決まる。未保存のページも数える。`.finish` と `.stay` は待たない）・`testExplicitSettingNeverAdopts`・`testPrepareAtLaunchSetsCurrent`（写真モードは `Config.weekStart`）・`testHiddenInkNoticeWaitsForTheSheet`（シートが上がっている間と他のトーストの間は `next` が nil、閉じたら出る、ページを移ったら捨てる）・`testWeekStartToastsFitThreeLines`（10 言語、iPhone の幅） |
| U | `CalendarRootScreenTests`・`SettingsScreenTests`・`ScreenshotModeTests`（足すだけ） | `testMakePaperSunday`・`testSwitchSavesTheOldPageFirst`（`weekStartSwitch` の呼ばれる順が save → apply → reload、同じ値なら何も呼ばれない）・`testConfirmOnlyWhenTheStartChanges`・`testOtherPagesFootnote`・`testParseWeekStart`。`Sheet.allCases.count` を 11 に |
| U | `WeekStartLedgerTests.swift`（新規。凍結の台帳を通す） | `testHiddenStrokeIsNotErased`（日曜の表の台帳で全部を消しても隠れた線に墓標が付かない）・`testStrokeFollowsItsDateWhenLayoutChanges` |
| S2 | `ExportBuilderTests`・`WebImportSheetTests`（足すだけ） | `testExportKeepsBothWeekForms`・`testSundayPDFFileName`・`testOtherFormNote`（`toastText(…otherWeekStart:)` の 1 行、nil なら 1.1 の文のまま） |
| U | `SyncEngineTests`（足すだけ） | `testSundayPageSyncsLikeAnyPage`・`testEraseEverythingRemovesBothForms`・`testSwitchKeepsBothForms`（月曜のページを保存 → 日曜のページを読む → 月曜へ戻ると線が残る）・`testPushOnlyLeavesNoZoneToken`（`failNext[.fetchChanges] = .networkUnavailable` の後に線を保存して push が成功すると、`.synced` で `lastSyncAt` は入るが `state.zoneToken` は nil。§10.3 の 4 の前提。どれも `InMemoryCloudDatabase`） |
| P | `PaperFitTests`・`PaperViewTests`（足すだけ） | `testMonthHeaderOrderAndColors`（日曜の列 0 が赤、列 6 の土が青、10 言語）・`testPDFMonthRowSunday` |

**UI テスト**（U）: `LanguageUITests` に `testWeekStartFollowsTheRegion`（(en) en_US → sunday、(en) en_GB → monday、(ja) ja_JP → monday、(en) en_EG → monday を `auto` で）と `testWeekStartIsMondayWithoutTheArgument`。切り替えの流れは新しい `WeekStartUITests.testSwitchShowsTheSentenceAndChangesTheHeader`（写真モードの中の状態だけで。文と見出しを見るだけで、保存の証明ではない、§10.7）。

**古い版の本物で確かめる段**（材料は B11、段は C）: B11 の 1 回目が `tools/weekstart-compat/`（新規。`tools/compat10` は変えない）に材料を移す（§1.5 の手順 7b）。C が `compat-v1.0` のジョブに 1 段足す: 既にある `v10` の checkout と、`tools/l10n/ja-baseline-ref.txt` の commit（`<1.1.1>`）の checkout で走らせて失敗 0。

**既存の月曜の期待が 1 つも変わらないことの確かめ方**:

1. 試し（済み）: 既定の引数の案で KitChecks が直さずに通る。凍結 7 ファイルが同じバイト。既定を日曜にすると落ちる。
2. J-2 を広げる（§1.3）: 削除行に日本語に加えて `w-20`・`Monday`・`Sunday`・`mondayOnOrBefore`・`firstGridDay` が無いことをリードが見る。
3. K-7: `testFixturesAreWhatTheNewCodeWrites`・`compat-v1.0` が作り直さずに緑。
4. W-1・W-2。
5. J-4 の 1 画素ずつの比較（帯も含む）。
6. D14 の `DATA_1_1.sha256`（`<1.1.1>` のもの）が変わらない。

アプリのソースの呼び出しは 20 か所・7 ファイル、Kit のテストは 66 か所、アプリのテストは 32 か所、KitChecks は 63 か所（`wt-m7b` の時点の数。既定が月曜なので全部そのまま通る。XCTest は CI で）。

**J との関係**: J-1 既存の文は変えない（新しいキーは表の外。SUPPORT とストアの文はアプリの外なので直す）／J-2 変えない／J-3 `Text11` は変えない、`weekStart: .monday` を明示した呼び出しとも比べる／J-4 引数なしは月曜で同じ／J-5・J-7・J-8 関係なし／J-6 G-1〜G-3 と W-2／**J-9・J-10 を足した**（§1.3）。

### 10.9 規模

合計 0.3〜0.4 里程（1.0.1 の 0.2〜0.3 より少し大きい程度）。データの形が変わらないので K-7 の作り直しは無い。K2 ＋0.1、U ＋0.15、P ＋0.03、S2 ＋0.02、X・R ＋0.02、C ＋0.03、LA2（§11 と合わせて）小、検証 1 本。**新しい実装の役は作らない**（`PageNavigation` は K2、`CalendarRootScreen` は U、見出しは P の持ち物で、別の役にすると並行の組み立てで衝突する）。

### 10.10 完了の定義（§8 の 12 と同じ）

1. §10.8 の KitChecks・XCTest・UI テスト・`tools/weekstart-compat` の段が緑。L-13・L-14 が緑。
2. 引数なしの日本語の写真が 1.1.1 と同じ（J-4）。既存の月曜の期待を変えていない（§10.8 の 2）。
3. 23 キーの 9 言語の訳と逆翻訳が REVIEW.md で × なし。新機能の文・説明・審査メモ・SUPPORT の文が §10.4・§6.3 のとおり（`grep -rniE "どの言語でも月曜始まり|週は月曜始まり|weeks start on Monday" docs/store docs/SUPPORT*.md` が 0 件。大文字小文字を区別しない。結果に残る正しい文があれば明示の例外として M7B.md に書く）。
4. 本人の実機の確かめ（§8 の 9 の手順 2b・4b・4c・4d・9b）が済んでいる。
5. 週の始まりの検証の観点（§12.1）で blocker・major が 0。

## 11. EU（27 か国）での販売（第 4 版。O-4。担当 LA2・X・R・W・C・H とリード、届け出は本人）

調べた日: 2026-11-04（Apple の画面と API は読むだけで、何も変えていない）。**これは法律の助言ではない。** 規約の案文は安全側に書いたが、§11.6 で「確かな部分」と「専門家に聞くとよい部分」を分けた。本人が了承したのは、EU の App Store に住所・電話番号・メールアドレスが公開されること。

**今の状態**（App Store Connect API の実測。GET のみ）:

| 項目 | 値 |
| --- | --- |
| 公開中の版 | 1.1（READY_FOR_SALE、手動リリース）。売り手の表示 `MASATAKA IKEDA` |
| 主言語 | `ja`。ロケールは ja だけ |
| 配信の国 | 175 のうち 148 が `available: true`。**EU 27 だけ `available: false`、`contentStatuses: [TRADER_STATUS_NOT_PROVIDED, CANNOT_SELL]`**。英・スイス・ノルウェー・アイスランドは販売中。リヒテンシュタインは一覧に無い |
| 新しい国の自動追加 | `availableInNewTerritories: true` |
| サブスクリプション | 月額 6823694491・年額 6823702487 とも APPROVED。配信の国は **175（EU 27 を含む）** |
| 無料試用 | 月額・年額とも 175 の国と地域すべてに `TWO_WEEKS / FREE_TRIAL` |

**サブスクリプションの設定は要らない**。EU の価格は基準の日本から自動で入っている（ユーロの 21 か国 1.99 / 17.99 EUR、チェコ 49 / 399 CZK、デンマーク 19 / 129 DKK、ハンガリー 999 / 6990 HUF、ポーランド 9.99 / 69.99 PLN、ルーマニア 9.99 / 79.99 RON、スウェーデン 29 / 199 SEK。月額 / 年額）。既定は自動の値のまま。手取りは付加価値税を除いて手数料 15%（ドイツ 1.42 / 12.85 EUR。Apple の 2026-10-01 からの EU の条件とも合う。CTC（5%）は App Store の外で配るアプリの分でかからない）。購入画面の「N か月分お得」は実際の価格から計算して切り捨てる（`PlanText.savingsMonths`）ので、ユーロでは「2 か月分」で嘘にならない（`PlanTextTests.testEuroSavings`、K2）。

### 11.1 公開の順番（D19）

**「届け出 → 審査 → 規約の公開 → 1.2 の公開 → EU を入れる」**。配信の国は版と別の設定で、入れたら即時に効く（全員に見えるまで最大 24 時間）。先に入れると、そのとき公開中の版（日本語だけの 1.1.1）が EU に出て、公開中の規約にも「EU には配信しません」と書いてある。

| 順 | いつ | 誰 | 何を |
| --- | --- | --- | --- |
| 1 | **M7B-24 に答えた後で、1.1.1 が審査を通ったらすぐ**（1.1.1 の提出が今日から 1 週間たっても済まないか、提出から 1 週間たっても通らないときは待たない） | 本人 | 届け出（§11.4）。通るまでの日数を Apple は書いていない（2024 年の体験談は 2〜3 日、2026 年の Apple の開発者フォーラムの報告は 10 日以上・1 か月以上・41 日）。確認中に更新の提出が止まるかは未確認（10 日以上の確認中に更新や管理に困るとの利用者の投稿が 1 件、A17）なので、1.1.1 の差し戻しの再提出を巻き込まないよう、審査を通った後にする（第 4 版の下書きは「提出したらすぐ」。代償は EU が数日遅れうること。本人が急ぐなら提出の直後に戻してよい、§9） |
| 2 | TestFlight の前まで | 役 | 1.2 に es-ES・pt-PT と規約の直し（§11.2、§11.3。LA2・X・R・W） |
| 3 | 提出の前 | リード → 本人 | §8 の 11 の確認表（15 ロケール）、「この内容で入れてよい」の後に入力 |
| 4 | 提出 | 本人 | **EU は入れないまま**審査へ（手動リリース）。審査の間、公開中の日本語のページの「EU には配信しません」と矛盾しない |
| 5 | 審査の通過後、公開の日 | リード → 本人 | リードが公開の日付を日本語と英語の 3 ページの「最終更新」に入れ、S-5 の行を日付つきで足す（1.2 が 2027 年に出ても合うよう、年も当日に決める）→ §6.5 の公開の直前の確認（§11.3 の案文を含む全文。Apple の規約の URL の確かめも）→「はい」→ Web を merge → `curl -sI` で 200 |
| 6 | 同じ日 | 本人 | 手動リリース。リードが `lookup?id=6822762089&country=jp` が 1.2 を返すのを確かめる |
| 7 | 同じ日（`country=ru` が版 1.2 を返してから） | リード | `country=ru&lang=ru_ru` の説明の言語を見る（ロシアは既定がロシア語で追加が en-GB、ロケールは足していないので、オランダ・スウェーデンと同じ条件。§11.2） |
| 8 | 届け出が通っていれば同じ日 | リード（**本人の「はい」の後**）か本人 | 英語が出ていれば **27 か国を入れる**。日本語が出ていれば **25 か国を入れ、オランダとスウェーデンは次の版まで待つ** |
| 9 | 〜24 時間 | リード → 本人 | `lookup?id=…&country=de` などが 1.2 を返す。`apps.apple.com/de/app/id6822762089` に本人の連絡先と de-DE の文。結果を本人に平易に報告（§8 の 9 の E の表） |

- **「1.2 と同時」は届け出次第**。**順 5 までに通らないとき**: 順 5〜7 はそのまま行い、順 8 だけ後にする（1.2 を 148 か国で先に出し、通った日に EU を入れる。新しい版は要らない。ストアの文を 1.2 に入れておくため）。規約の文は「EU で売っています」と言い切らない形にしてある（T-1・T-7）。
- **規約を 1.2 より先に出す理由**: 審査は前に済んでいるので、ボタンの前に出せば、1.2 が出た瞬間に古い規約が見える時間が無い。
- **ストアの確認が間に合わず ja だけで 1.2 を出すとき**（§6.6）は、EU を入れない（日本語の文と写真が EU に出るため）。確認が済んで次の版に各国語が入ってから入れる。
- **止まったとき**: 再提出のメールが来たら指示に従う。確認中のまま動かなければ Apple Developer Support へ（2024 年に電話で解決した例はあるが、2026 年の報告では電話の折り返しが選べず問い合わせに返事も無い）。これは Claude が代行できない。
- **届け出の確認中に 1.1.1 の再提出か 1.2 の提出が断られたとき**: リードが画面の文をそのまま本人に伝え、Apple Developer Support への問い合わせ文を下書きする（送るのは本人）。148 か国の 1.2 も一緒に止まるので、「1.2 を先に出す」（§11.7）の前提が崩れたことと、見込みの日数（報告は最長 41 日）を平易に報告する。実際に止まったか、何日止まったかは M7B.md に書く（§11.9 の確かめられなかったことの答えになる）。

### 11.2 ストアのロケール（D12。§6.6 の表と同じ）

| ロケール | 変更 | 店頭 | 中身 |
| --- | --- | --- | --- |
| **es-ES（新）** | 足す | スペイン（既定） | X が es-MX から直す。R が逆翻訳 |
| **pt-PT（新）** | 足す | ポルトガル（既定） | X が別に書く（語が多く違う: tela/ecrã、arquivo/ficheiro、salvar/guardar、excluir/eliminar）。**画面はブラジルのポルトガル語**であることを説明に正直に書く |
| fr-FR | 読み手が変わる | **フランス（既定）**・ベルギーとルクセンブルク（追加）・スイス（追加）・アフリカの 3 か国（既定） | フランスの書き方で |
| de-DE | 読み手が変わる | **ドイツ・オーストリア（既定）**・ルクセンブルク（追加）・スイス（既定） | **`docs/store/README.md` の「ß を使わず ss」をやめて標準のドイツ語に**（X はまだ書いていないので手戻りは無い） |
| it | 読み手が変わる | **イタリア（既定）**・スイス（追加） | 標準のイタリア語 |
| en-GB（en-US の写し） | そのまま | **EU の 19 か国の既定、残りの 8 か国の追加** | 全 27 か国で既定か追加。**写しを必ず入れる**（en-US だけだと足りない可能性が高い。下の実測） |

- 両方とも写真を上げる（es-ES は es-ES の組、pt-PT は pt-BR の組。§7.5）。上げないと日本語の写真が出る。サブスクリプションの表示名と説明も 2 つ足す。名前は第 1 案と退き先 2 つを両方に。
- ロケールは版が編集可能なときだけ足せるので、**1.2 に入れる**。後から足すなら次の版。
- 画面の言語（`.lproj`）は 10 のまま（0-2）。es-ES → es、pt-PT → pt-BR は実測どおりで、`testRegionalVariants` がそのまま確かめる。

**訳が無い言語の人に何が出るか**:

| 場所 | 結果 |
| --- | --- |
| アプリの画面 | **英語**（オランダ語・ポーランド語・スウェーデン語など。§2.1。端末の言語の 2 番目に日本語を入れている人は日本語） |
| ストア、既定が英語の 19 か国（ベルギー・ブルガリア・クロアチア・キプロス・チェコ・デンマーク・エストニア・フィンランド・ギリシャ・ハンガリー・アイルランド・ラトビア・リトアニア・ルクセンブルク・マルタ・ポーランド・ルーマニア・スロバキア・スロベニア） | **英語** |
| ストア、既定がドイツ語・フランス語・イタリア語・スペイン語・ポルトガル語の 6 か国 | その言語のロケール（1.2 で全部そろう） |
| **ストア、オランダとスウェーデン** | **未確定。英語か日本語**（下） |

**実測**（公開の iTunes lookup API。2026-11-04）: 日本語が主らしく英語の文も持つアプリ 4 本は、オランダ・スウェーデンで日本語、ベルギー・ポーランドで英語だった。`country=nl&lang=nl_nl` で日本語、`lang=en_gb` で英語。つまり **既定の言語のロケールが無い店頭は主言語に落ちる**（だから es-ES と pt-PT は要る）。広い標本（約 170 本）で、英語の文が英国と米国で同じアプリのうち 8 本がオランダで日本語、38 本が英語。英語の文が英国と米国で違う（en-GB があると分かる）24 本は、オランダで日本語が 0 本。**読み**: en-US だけのアプリはオランダで主言語に落ち、en-GB があれば英語になる、と読むと全部説明がつく。ただし外から en-GB の有無を確定できないので断定しない。本人のアプリは en-GB を入れるので、英語になる見込みが高い。

**既定の対処**（順 7・8）: 1.2 を出した日に、同じ条件のロシアの店頭で本物のアプリを確かめる。英語が出たら 27 か国を入れる。日本語が出たらオランダとスウェーデンを次の版まで待ち、次の版で `nl-NL`・`sv` のロケールに en-US と同じ英文を入れる。

**次の版の候補**: 主言語を en-US に替える（承認された言語なら主言語を替えられる、と Apple は書いている）。替えれば、訳の無い国は全部英語になり、日本は日本語の既定のまま。1.2 で en-US が承認された後にできる。1.3 の契約で扱う。

### 11.3 規約・プライバシー・サポートの文（固定の案文。LA2 が `docs/*.md`・`docs/*.en.md` に、W が Web に。R が英文を逆翻訳）

- 日本語は平易に。【】と「下書き」は書かない。§6.4 の 4 つは LA が入れ済みで、その上に足す。
- 価格・試用・解約の経路・連絡先・氏名の文字列は変えない（§6.4 の確かめのまま）。
- **日本語のページへの追加は M7B-17 の「4 つ」の外なので、§6.5 の公開の直前の確認で全文を見せて「はい」をもらう**。
- 第 11 条 2 項（変更の 30 日前の知らせ）: T-1〜T-9 は「軽微か、あなたに有利な変更」の例外に当たると読む（読みであって確かめていない。§11.6 の 9）。PRIVACY 第 10 節（大きな変更は施行前にアプリ内とサポートページでお知らせ）: アプリが集める情報の種類は変わらないので S-5 のお知らせで足りると読む（同じく読み。§11.6 の 9）。

**利用規約**（`docs/TERMS.md`・`docs/TERMS.en.md`）:

| # | 場所 | 日本語 | 英語 |
| --- | --- | --- | --- |
| T-1 | 第 1 条 3 項を置き換え | 本アプリは、App Store で配信している国と地域で使えます。どの国と地域で配信しているかは、App Store の表示のとおりです。 | The App is available in the countries and regions where it is offered on the App Store. The App Store shows which countries and regions these are. |
| T-2 | 要約の最後の文 | 日本の法律に従います（お住まいの国の消費者保護の法律で放棄できない権利は制限しません）。 | These terms follow the laws of Japan (this does not limit rights that you cannot waive under the consumer protection laws of the country where you live). |
| T-3 | 第 5 条 3 項の販売者の行の最後、「本規約の範囲で責任を負います。」の後 | EU（欧州連合）では、販売者は Apple Distribution International Ltd. で、購入はお住まいの国の Apple メディアサービス利用規約に基づいて行われます（アイルランド版: <https://www.apple.com/legal/internet-services/itunes/ie/terms.html> 。ほかの国は、そのページの Choose your country/region から選べます）。 | In the EU (European Union), the seller is Apple Distribution International Ltd., and purchases are made under the Apple Media Services Terms and Conditions for your country (Irish version: <https://www.apple.com/legal/internet-services/itunes/ie/terms.html>. For other countries, use “Choose your country/region” on that page). |
| T-4 | 第 5 条 3 項、返金の行の後に 1 行 | EU（欧州連合）にお住まいの方には、法律にもとづく撤回の権利（一定の期間内なら、理由を言わずに取り消せる権利）があります。ほかの国にも同じような権利があることがあります。期間の数え方と条件は Apple が定めていて、お住まいの国の Apple メディアサービス利用規約に書かれています。サブスクリプションでは最初の契約だけが対象で、更新のたびには使えません。デジタルの商品では、提供が始まるとこの権利がなくなることがあります。開発者はこの手続きができないので、Apple の手順に沿ってお申し込みください。 | If you live in the EU (European Union), the law gives you a right of withdrawal (a right to cancel a purchase within a set period without giving a reason). Other countries may have a similar right. Apple sets how the period is counted and the conditions, and they are in the Apple Media Services Terms and Conditions for your country. For subscriptions, this applies only to the first subscription, not to each renewal. For digital items, this right can end once the supply has started. The developer cannot carry out these steps, so please follow Apple's steps. |
| T-4b | 第 5 条 3 項の「原則として残りの期間分は返金されません」に続く括弧を置き換え | （返金の可否は Apple が判断します。お住まいの国の Apple の規約や法律に別の定めがあるときは、そちらに従います） | (Apple decides whether a refund is possible. If Apple's terms for your country or the law there say otherwise, those apply.) |
| T-5 | 第 9 条に 7 項 | 第 1 項、第 3 項、第 4 項は、消費者の方がお住まいの国の法律で持っている権利（欠陥についての権利や、製品の欠陥による損害の責任についての権利を含みます）を制限しません。 | Paragraphs 1, 3 and 4 do not limit the rights that consumers have under the laws of the country where they live, including rights about defects and rights about liability for damage caused by defective products. |
| T-6 | 第 12 条に 5 項 | EU（欧州連合）にお住まいの消費者の方には、第 1 項で日本の法律を選んでいても、お住まいの国の法律のうち契約で変えられない消費者保護の規定が適用されます。また、第 3 項にかかわらず、お住まいの国の裁判所に訴えることができます。 | If you are a consumer living in the EU (European Union), the consumer protection rules of the country where you live that cannot be changed by contract apply to you, even though paragraph 1 chooses the laws of Japan. Despite paragraph 3, you can also bring a case before the courts of the country where you live. |
| T-7 | 第 13 条に 1 行 | EU（欧州連合）で配信しているときは、EU の App Store のこのアプリのページに、開発者の住所と電話番号も表示します。 | While the App is offered in the EU (European Union), the developer's address and phone number are also shown on the App's page in the EU App Store. |
| T-8 | 英語版の冒頭の文の後（英語だけ） | なし | This does not limit rights that you cannot waive under the consumer protection laws of the country where you live. |
| T-9 | 第 3 条 4 項の頭 | 「**日本の祝日の表示**」を「**祝日の表示**」に | “**Showing the public holidays of Japan**” を “**Showing public holidays**” に |

なぜ T-6 か: EU の裁判所は、事業者の国の法律を選ぶ条項について、「その法律だけが適用される」と消費者に思わせ、居住国の強行規定の保護を知らせない条項は不公正になりうると判断した（C-191/15、2016 年）。第 12 条 4 項だけより、はっきり書いた方が安全。消費者が居住地の裁判所に訴えられることも EU の規則にある（Brussels I bis 第 18 条）。

**プライバシーポリシー**（`docs/PRIVACY.md`・`docs/PRIVACY.en.md`）:

**P-1 要約の最後に 1 文**
- 日本語: サポートにメールを送ったときの扱いは、第 12 節に書いています。
- 英語: Section 12 explains what happens when you email support.

**P-2 第 11 節の後に第 12 節（日本語）**

```text
## 12. 問い合わせのメールと、このページを開いたとき

- サポートにメールを送ると、開発者はあなたのメールアドレス、メールに書かれたお名前と本文を受け取ります。これはアプリが集める情報ではありません。開発者は、問い合わせに答えるためだけに使います。
- メールは Google の Gmail に保存されます。日本語以外のメールを読むときと返事を書くときは、本文を AI の翻訳（Anthropic の Claude）に渡すことがあります。
- メールは、問い合わせへの対応に必要な間だけ保存し、必要がなくなったら消します。
- 利用規約・プライバシーポリシー・サポートのページは GitHub Pages で公開しています。ページを開くと、GitHub が安全のためにあなたの IP アドレスを記録します。開発者はこの記録を見ることができません。ページにクッキーや解析の仕組みはありません。
```

**第 12 節（英語）**

```text
## 12. Emails to support, and opening these pages

- When you email support, the developer receives your email address, any name you write, and the text of your email. This is not information that the App collects. The developer uses it only to answer your question.
- Emails are stored in Google's Gmail. To read emails that are not in Japanese and to write replies, the developer may pass the text of your email to an AI translation service (Claude, by Anthropic).
- Emails are kept only as long as they are needed to deal with your question, and are deleted when they are no longer needed.
- The Terms of Service, Privacy Policy and Support pages are published on GitHub Pages. When you open a page, GitHub records your IP address for security. The developer cannot see this record. The pages use no cookies or analytics.
```

**P-3 第 13 節（日本語）**

```text
## 13. EU（欧州連合）、アイスランド、ノルウェー、英国、スイスにお住まいの方へ

- 第 12 節のメールの情報について、管理者（情報の扱いを決める人）は開発者です。連絡先は第 11 節のとおりです。
- この情報を扱う法律上の根拠は、問い合わせに答えるという正当な利益です（GDPR 第 6 条 1 項 f）。
- あなたには、自分の情報を見せてもらう、直してもらう、消してもらう、扱いを制限してもらう、受け取る、扱いに異議を述べる権利があります。第 11 節のメールアドレスにお知らせください。
- お住まいの国のデータ保護の機関に苦情を申し立てることができます。
- 開発者は日本にいます。メールの情報は日本と、Google と Anthropic が情報を扱う国で扱われます。日本については、欧州委員会の十分性の決定があります。Google と Anthropic が扱う国については、この決定は当てはまりません。
- メールを送るかどうかは自由です。送らなくてもアプリは使えます。送らないと、問い合わせにお答えできないだけです。
- この情報を使った自動の判断やプロファイリングはしません。
- アプリの手書き・予定・設定は開発者に届かないので、開発者はそれらを見せることも消すこともできません。消し方は第 9 節のとおりです。
- iCloud と App Store での情報の扱いは Apple が決めています。Apple のプライバシーポリシー（https://www.apple.com/legal/privacy/）をご覧ください。
```

**第 13 節（英語）**

```text
## 13. If you live in the EU (European Union), Iceland, Norway, the UK or Switzerland

- For the email information in Section 12, the controller (the person who decides how it is used) is the developer. The contact details are in Section 11.
- The legal basis for using this information is the legitimate interest in answering your question (GDPR Article 6(1)(f)).
- You have the right to see your information, have it corrected or deleted, have its use restricted, receive a copy of it, and object to its use. Please write to the email address in Section 11.
- You can make a complaint to the data protection authority of your country.
- The developer is in Japan. Your email information is handled in Japan and in the countries where Google and Anthropic handle information. For Japan, there is an adequacy decision by the European Commission. This decision does not cover the countries where Google and Anthropic handle information.
- Sending an email is up to you. You can use the App without sending one. If you do not send one, we simply cannot answer your question.
- This information is not used for automated decisions or profiling.
- Your handwriting, events and settings in the App do not reach the developer, so the developer cannot show or delete them. Section 9 explains how to delete them.
- Apple decides how information is handled in iCloud and the App Store. Please see Apple's privacy policy (https://www.apple.com/legal/privacy/).
```

**P-4 同じ文書の矛盾を直す**（P-2 は「開発者はメールアドレスと本文を受け取る」「Gmail に保存する」「Claude に渡すことがある」と書くので、今の文のままだと 1 つの公開文書の中で食い違う。§6.5 の公開の直前の確認で見せる差分に入れる。Web の見出しの `id` が変わるので、W が参照を直す）:

| 場所 | 日本語（今 → 直し） | 英語（今 → 直し） |
| --- | --- | --- |
| 第 1 節の見出し | 開発者が集める情報：ありません → **アプリが集める情報：ありません** | Information the developer collects: none → **Information the App collects: none** |
| 第 6 節の見出し | 第三者への提供：ありません → **アプリのデータの第三者への提供：ありません** | Sharing with third parties: none → **Sharing the App's data with third parties: none** |
| 第 6 節の 1 行目 | 開発者は、あなたのデータを誰にも渡しません（そもそも持っていません）。 → **アプリのデータ（手書き・予定・設定）を、開発者は誰にも渡しません（そもそも持っていません）。サポートへのメールは第 12 節のとおりです。** | The developer does not give your data to anyone (the developer does not have it in the first place). → **The developer does not give the App's data (your handwriting, events and settings) to anyone (the developer does not have it in the first place). Emails to support are covered in Section 12.** |
| 第 9 節の最後の行の後半 | 開発者にはデータがないため、開発者への削除依頼は必要ありません。 → **アプリのデータは開発者に届かないので、開発者への削除依頼は必要ありません。サポートに送ったメールを消してほしいときは、第 11 節のメールアドレスにお知らせください（第 12 節・第 13 節）。** | The developer has no data, so there is no need to ask the developer to delete it. → **The App's data does not reach the developer, so there is no need to ask the developer to delete it. If you want an email you sent to support deleted, please write to the email address in Section 11 (see Sections 12 and 13).** |

なぜこの形か: GDPR 第 13 条が求める項目（管理者・目的と根拠・受け手・移転・保存の基準・権利・苦情・任意かどうか・自動の判断）を順に埋めた。**「何も集めません」はアプリの話として正しいが、サポートのメールは本人が受け取る個人情報**で、定型の返事の流れ（§6.7）では本文が Claude を通る。隠さず書く。App Store の「データは収集されません」の申告は変えない（アプリから送られるデータは無いまま）。英国とスイスとアイスランド・ノルウェーを入れた理由: 今も売っている国で、似た法律がある。

**サポート**（`docs/SUPPORT.md`・`docs/SUPPORT.en.md`）:

| # | 場所 | 日本語 | 英語 |
| --- | --- | --- | --- |
| S-1 | 「EU（欧州連合）からの利用」の行（英語は “Use from the EU (European Union)”） | この行を消す | 同じ |
| S-2 | 既知の制限の表の「配信地域」の行（英語は “Distribution area”） | この行を消す | 同じ |
| S-3 | 「対応できないこと」の返金の行の最後 | EU（欧州連合）にお住まいの方の撤回の権利も、Apple の手続きです（下の「EU で購入を取り消すには？」）。 | The right of withdrawal for people in the EU (European Union) is also handled by Apple (see “How do I cancel a purchase in the EU?” below). |
| S-4 | よくある質問の「解約するには？」の後に新規 | 下 | 下 |
| S-5 | 「お知らせ」（**Web には公開の日にリードが日付を入れて足す**、§11.1 の順 5。W は commit に入れない。`XX` を含む commit は `check-legal` が止めるので、埋め忘れのまま公開されない。`docs/SUPPORT*.md` の原稿だけ `XX` のままにして、同じ日に直す） | 2026年XX月XX日：1.2 に合わせて、利用規約とプライバシーポリシーを更新しました。 | Month DD, 2026: We updated the Terms of Service and Privacy Policy for version 1.2. |
| S-6 | 「自分のデータを全部消すには？」の最後の行（P-4 と同じ理由） | 開発者のところには何も保存されていないので、開発者に削除を依頼する必要はありません。 → **アプリのデータは開発者のところに届かないので、開発者に削除を依頼する必要はありません。サポートに送ったメールを消してほしいときは、メールでお知らせください。** | Nothing is stored with the developer, so there is no need to ask the developer to delete anything. → **The App's data does not reach the developer, so there is no need to ask the developer to delete it. If you want an email you sent to support deleted, please let us know by email.** |

S-4 の日本語:

```text
### EU で購入を取り消すには？

EU（欧州連合）にお住まいの方には、法律にもとづく撤回の権利があります。領収書を受け取ってから 14 日以内なら、理由を言わずに最初の契約を取り消せることがあります（サブスクリプションの更新のたびには使えません）。手続きは Apple が行い、開発者はできません。

1. お住まいの国の Apple メディアサービス利用規約（アイルランド版: https://www.apple.com/legal/internet-services/itunes/ie/terms.html 。ほかの国は、そのページの Choose your country/region から選べます）の「撤回の権利」の手順に沿ってください。Apple Account の購入履歴から注文を選びます。
2. デジタルの商品では、提供が始まるとこの権利がなくなることがあります。取り消せるかどうかは Apple が判断します。
3. サブスクリプションの解約は別の手続きです（「解約するには？」）。
```

S-4 の英語:

```text
### How do I cancel a purchase in the EU?

If you live in the EU (European Union), the law gives you a right of withdrawal. Within 14 days of receiving your receipt, you may be able to cancel your first subscription without giving a reason (this does not apply to each renewal). Apple carries out this process, and the developer cannot.

1. Please follow the steps under “Right of withdrawal” in the Apple Media Services Terms and Conditions for your country (Irish version: https://www.apple.com/legal/internet-services/itunes/ie/terms.html. For other countries, use “Choose your country/region” on that page). You choose the order from the purchase history of your Apple Account.
2. For digital items, this right can end once the supply has started. Apple decides whether the purchase can be cancelled.
3. Canceling a subscription is a separate step (see “How do I cancel?”).
```

**サポートの定型文**（`docs/support-replies/`。§6.7）:

- `refund.md` に「相手が EU のときに足す段落」: “If you live in the EU, you may also be able to withdraw from your first subscription within 14 days of receiving your receipt (this does not apply to each renewal). Apple handles this as well. The steps are in the Apple Media Services Terms and Conditions for your country: https://www.apple.com/legal/internet-services/itunes/ie/terms.html (this is the Irish version; choose your country under “Choose your country/region” on that page).” と逆翻訳。相手がドイツのときはもう 1 文: “If you live in Germany, Apple's terms for Germany also cover ending a subscription early and a refund for the rest of the period, so please ask Apple Support.”（§11.6）。
- 新しく `privacy-request.md`: 「自分の情報を見せて・消して」と言われたときの返事。**対象はメール、Gmail の下書き、翻訳のために Claude に渡した会話の記録で、消せたものだけ「消した」と書く**（手書きは開発者に届かない）。§6.7 の流れでは本文が Claude との会話と下書きにも残るので、「持っているのはメールだけ」と書くと事実と違う。本人の手順を付ける: Gmail で該当のメールを削除してゴミ箱からも消す／下書きを消す／Claude の該当の会話を消す／返事に、消した物を具体的に書く。**1 か月以内に答える**（GDPR 第 12 条。専門家の確認の対象）。定型文は 6 → 7、`README.md` の一覧も。

**他の文書**（C）: `README.md`・`docs/DESIGN.md`・`docs/APPLE_ENROLLMENT.md` の「EU を除く」の記述を、本人の決定（2026-11-04）に直す（`grep -n "EU" `で探す）。古い版の記録（`M5*`・`M6*`・`M7A*`）は直さない。審査メモに EU の文は足さない（審査の間は EU を入れないので要らない。4,000 バイトの上限に近い）。

### 11.4 本人の作業（届け出。Claude は入力を代行しない。個人情報と身分証のため）

所要は 20〜30 分の見込み（待ち時間は別）。**いつ**: M7B-24 に答えた後で、1.1.1 が審査を通ったらすぐ。1.1.1 の提出が今日から 1 週間たっても済まないか、提出から 1 週間たっても通らないときは、待たずに届ける（§11.1 の順 1）。**書類の写真や個人番号はチャットに貼らないでください。困ったら画面の文言だけ教えてください。**

**用意するもの**:

| 項目 | 書き方 | 公開されるか |
| --- | --- | --- |
| 住所 | ローマ字で（都道府県は選択。体験談） | **EU の App Store に出る** |
| 電話番号 | 国番号 81、先頭の 0 を取る。SMS か音声（「Call Me」）でコードを受けられる番号 | **出る** |
| メールアドレス | コードを受けられるもの。既定はサポートと同じ syfan0@gmail.com | **出る** |
| 書類 | 氏名と住所が読める最新の物の写真か PDF。**HEIC は不可の報告あり（JPEG に）** | 出ない（Apple だけ） |

書類について（2024 年の個人の体験談。Apple の公式の一覧ではない。画面の指示を優先）: マイナンバーカードで通った例がある。**表面だけ**を出す（裏面の個人番号は出さない）。健康保険証は通らなかった。求められたのは住民票・マイナンバーカード・在留カード・写真つきの公的な身分証。住民票なら、マイナンバーと本籍が載らないものを取る。

**手順**（Apple の日本語のヘルプの画面の名前。英語のままの所もある）:

1. App Store Connect ›「ビジネス」›「契約」タブ › 下の「Compliance」›「デジタルサービス法」の横の「コンプライアンス要件を満たす」。
2. 「This is a trader account.」（trader のアカウントです）を選ぶ →「次へ」。
3. 住所・電話番号・メールアドレスを入れる。**送った後は確認中に直せない**との体験談がある。送る前に読み直す。
4. メールに届いたコード → 電話に届いたコードを入れる。コードを受けられない番号なら、画面の「手動認証」を選ぶ。
5. 書類の言語（日本語）を選び、書類を上げる。「EU 法に合う物だけを提供する」という証明を読んで同意する（M7B-24 に答えた後なので、負担は説明済みの内容です）。
6. 最後の確認の画面で全部を読み直し、**「確認」を押す**（押さないと届け出が終わりません）。
7. 同じ「契約」の画面で、**同意待ちの契約が無いか**も見る（2026-08-18 の開発者契約）。あれば内容をリードに伝えて一緒に読み、同意は本人が押す。
8. 終わったら「アプリ」›「アプリ情報」›「App Store の規制と許可」›「デジタルサービス法」が trader になっていることを見る。ラベルの URL は入れない。
9. リードに「届けました」と伝える。Account Holder のメールに届く結果（完了・再提出の依頼）も転送か要約を。

**知っておくこと**: Apple の説明は「EU の 27 か国に配信しているとき、product page に出す」で、店頭を限る言い方ではない。実測（Goodnotes 1 本、2026-11-04）: ドイツの店頭のページ（`apps.apple.com/de/...`）を日本から開くと、折りたたまれた「Anbieter」の中に電話番号があり、jp と us のページには同じ語が無かった。つまり **EU 以外の店頭には出ないが、URL を開けば日本からも誰でも見られる**（M7B-24 の頭に書いた）。後から番号や住所を変える手順は Apple の説明に無く、サポートに聞くことになる。自宅の住所を出したくなければ私書箱もできる（その関係を示す書類が要る）。DAC7（画面に並ぶ別の項目）は EU に住む開発者の分で当たらない。聞かれたら「いいえ」。**1.2 の日にやること**: 手動リリースのボタンを押す（今までどおり。前後の順は §11.1）。

### 11.5 リードの作業（API）

| やること | 方法 | 状態 |
| --- | --- | --- |
| 届け出が通ったかを見る | `GET /v2/appAvailabilities/6822762089/territoryAvailabilities?limit=200&include=territory` の `contentStatuses` から `TRADER_STATUS_NOT_PROVIDED` が消えたか。失敗の値もあるらしい（`TRADER_STATUS_VERIFICATION_FAILED`。Apple の仕様の第三者の写しで確認） | 読むだけ。**届け出の後は毎日**。`available` が勝手に true になっていたら（M5 で本人が外した設定なので入らないと読むが未確認）、1.1.1 が EU に出ているので、すぐ本人に伝えて外すか残すかを聞く |
| 15 ロケールの入力（文・写真・サブスクリプションの表示名） | `appStoreVersionLocalizations` など。§8 の 11 の確認の後 | 今の計画のまま |
| 27 か国を入れる | `PATCH /v1/territoryAvailabilities/{id}` に `available: true`。id は `{"s":"6822762089","t":"DEU"}` の base64 で、GET の結果に出る。**Apple の文書の題は「pre-order の」なので、公開済みのアプリに効くかは未確認** | **本人の「はい」の後**。まず 1 か国（マルタなど）で試し、断られたら本人に画面で頼む（「価格と配信状況」›「App の配信状況」›「管理」›「配信状況を管理」） |
| 届け出そのもの | API は見つからなかった | 本人だけ |

### 11.6 確かな部分と、専門家に聞くとよい部分

**確かな部分**（Apple の文か EU の公式の文で確かめた）: trader の届け出の項目・確認・公開。EU の販売者は Apple Distribution International Ltd.、撤回の手続きは Apple（領収書を受け取ってから 14 日、理由不要、**サブスクリプションは最初の契約の後に限る**、Apple Account の購入履歴から注文を選び「取引を撤回」、デジタル内容は本人の求めで提供が始まり権利を失うと認めると撤回できない。Apple の規約の ie・de・fr、2026-09-14 版）。**ドイツ版の I 節には、いつでも即時に解約して残りの期間の分を按分で返金してもらう権利の定めがある**（アイルランド版・フランス版の同じ節には見当たらない）。付加価値税は Apple が引いている。手数料 15%。事業者の国の法律を選ぶ条項に居住国の保護を知らせる必要があること。消費者は居住地の裁判所に訴えられること。GDPR が域外の事業者にも及ぶ場合があり、そのとき EU の代理人が原則要ること、例外が狭いこと。EU のオンライン紛争解決（ODR）の窓口は 2025-07-20 に廃止（リンクを載せなくてよい）。

**本人が専門家に聞くとよい部分**（EU の消費者法か個人情報に詳しい弁護士）:

| # | 問い | 今の扱い | なぜ気になるか |
| --- | --- | --- | --- |
| 1 | 第 9 条の免責と 12 か月分の上限は EU の消費者に効くか | T-5 で「法律の権利は制限しない」と書いた | 消費者向けの免責は EU で無効になりやすい。デジタル商品の適合性の権利（指令 2019/770）を負うのが Apple か開発者かも断定できない |
| 2 | 準拠法を EU の人だけ居住地の法律にするか | T-6 は「日本の法律＋強行規定の断り」 | **Apple の標準 EULA は EU・スイス・ノルウェー・アイスランドの市民について居住地の法律と裁判所**としている。第 1 条 2 項は「Apple との関係では Apple の契約が優先」なので、合わせる案もある |
| 3 | 第 1 条 1 項（ダウンロードで同意）、第 11 条 3 項（使い続ければ同意）は EU で有効か | 変えていない | 消費者の同意の形として弱いかもしれない |
| 4 | 「日本語版が優先」は EU の消費者に効くか。英語だけの規約はドイツ語やフランス語の人に有効か | T-8 で断りを足した。訳は増やさない（D11） | 読めない言語を正本にするのは不利に解されうる |
| 5 | GDPR 第 27 条の EU の代理人は要るか | 置かない前提 | 例外は「時々の処理」など。メールが少なければ当たりそうだが断定できない。代理人は有料のサービスがある |
| 6 | 個人の Gmail と Claude に EU の人のメールを通してよいか（処理の委託の契約、移転） | 第 12 節に書いて開示 | 開示だけで足りるか分からない。十分性の決定は日本の事業者向けで、Google と Anthropic の国の分は別。**Claude のデータ利用の設定（モデルの改善に使うか）を本人の契約で確かめる**（§12.4 の (11)） |
| 7 | 保存の期間に年数を書くべきか | 「必要な間」と基準だけ | 年数を書くと本人に定期的に消す仕事が増えるので書かなかった |
| 8 | CRA と製造物責任（下） | 調べた範囲を報告 | 特に「輸入者」「代理人」と、個人の負担 |
| 9 | T-1〜T-9 は第 11 条 2 項の 30 日前の知らせが要らない変更か。Gmail と Claude を初めて開示する直しは PRIVACY 第 10 節の「大きな変更」（施行前にアプリ内とサポートページでお知らせ）に当たるか | どちらも当たらないと読み、S-5 のお知らせだけ | 確かめていない |
| 10 | ドイツの Impressum（DDG §5）は日本の個人開発者に及ぶか | 住所は規約に書かず、App Store のページだけ（§11.7） | 当たるとは断定しない。当たるなら規約かサイトに住所が要る |

**優先**: 2 と 5 と 8。どれも 1.2 を止めるほどとは読まないが、最終判断は本人（M7B-24）。

**他の規則**:

| 規則 | 何か | 本人のアプリ | 1.2 の作業 |
| --- | --- | --- | --- |
| **サイバーレジリエンス法（CRA、規則 2024/2847）** | デジタル製品の安全の義務。委員会のガイダンス（2026-07-27）は、app store からダウンロードして端末で動くアプリは対象の製品で、商業活動として市場に出せば対象になりうる、と例に挙げる。製造者には自然人も含まれる | **EU で売ると対象になりうる** | 無し。**知らせる**（M7B-24） |
| CRA の報告（第 14 条） | **2026-09-11 から**、2027 年より前に市場に出した製品にも。実際に悪用された脆弱性と重大なインシデントを 24 時間以内に早期の警告、72 時間以内に通知。零細企業は 24 時間の期限の遅れに罰金がかからない | サーバーが無く起きにくいが、起きたら本人が ENISA の窓口に報告 | 手順を M7B.md に 1 行 |
| CRA の本体 | **2027-12-11 から**。リスク評価・技術文書・自己評価・EU 適合宣言・CE マーク・サポート期間の明示・脆弱性の扱い。モバイルアプリは既定の区分で自己評価でよい。それより前に出した製品は、その後に「実質的な変更」をしなければ本体は当たらない | 2027 年の版から関わる。**EU 域外の製造者の扱いは読み切れなかった** | 無し。**2027 年 12 月より前の版の契約で見直す**（§6.8） |
| **新しい製造物責任指令（2024/2853）** | **2026-12-09 より後に市場に出した製品**に適用。ソフトウェアも製品。データの破壊や破損も損害に入る。域外の事業者でも EU 市場の製品なら及ぶ。被害者との関係で契約で責任を制限・除外できない | 手書きのデータが消える不具合は関係しうる。第 9 条の上限は、この責任には効かない | T-5 で断り |
| **欧州アクセシビリティ法（EAA、指令 2019/882）** | 2025-06-28 から。サービスを提供する零細企業（10 人未満かつ売上か総資産が 200 万ユーロ以下）は免除 | カレンダーのアプリ自体は一覧に無い。購入の部分が e-commerce に当たるとしても免除と読む（免除の条文は二次資料で確認） | 無し |
| Apple のアクセシビリティの表示 | 今は任意で、いずれ必須（日付は見つからなかった） | 将来 | 無し |
| 撤回の機能（指令 2023/2673、2026-06-19 から） | オンラインの契約に「撤回する」機能を求める | 販売者の Apple の分と読む | 無し |
| DSA の他の条文 | 仲介サービス向け | 他人の内容を預からないので当たらないと読む | 無し |

### 11.7 既定で決めたこと（本人に報告する）

| 決めたこと | 理由 |
| --- | --- |
| ロケールは es-ES・pt-PT を足して 15。nl-NL・sv は入れない | §11.2。先に測る（オランダ語の欄に英語を入れることを Apple がどう見るか確かめられず、確認表も 2 つ増える） |
| 届け出は M7B-24 の答えの後、1.1.1 が審査を通ったらすぐ（1.1.1 の提出が今日から 1 週間済まないか、提出から 1 週間通らないなら待たない） | §11.1。第 4 版の下書きは「提出したらすぐ」だった。確認中に更新の提出が止まる報告があるので、差し戻しの再提出を巻き込まない。代償は EU が数日遅れうること。本人の一言で提出の直後に戻せる |
| 住所・メールは本人の住所と syfan0@gmail.com | 了承済み。私書箱もできることは伝える |
| ラベルの URL は入れない | 任意で、中身が無い |
| EU の価格は自動の値のまま | 基準の日本からの自動 |
| 画面の言語は 10 のまま。pt-PT は pt-BR を見せ、説明に正直に書く | 0-2 |
| 法律の文は日本語と英語だけ（D11） | 訳を増やすと確かめられない |
| 保存の期間は年数を書かない | §11.6 の 7 |
| 第 12 条は「日本の法律＋断り」。居住地の法律に替えない | 小さい直しから。§11.6 の 2 で聞く |
| 住所は規約とプライバシーポリシーに書かない。「EU の App Store のページに出す」とだけ書く | 了承は App Store の公開まで |
| 審査メモに EU を書かない | 審査の間は入れないので要らない |
| 届け出が遅れたら 1.2 は先に出す | 148 か国を待たせない（確認中に 1.2 の提出が止まったら、§11.1 の分岐） |
| プライバシーポリシーに「メールは Gmail に保存し、AI の翻訳に渡すことがある」と書く | 隠さない。公の文なので公開の直前の確認で見せる |
| 英国・スイス・ノルウェー・アイスランドもプライバシーの節の対象に入れる | 今も売っている |

### 11.8 完了の定義（§8 の 13 と同じ）

1. §11.3 の文が `docs/*.md`・`docs/*.en.md` と Web の `m7b-legal` に入り、`npm test`・`npm run check:legal` が緑。`grep -n "EU には配信\|not distributed in the EU" docs/TERMS* docs/SUPPORT*` が 0 件。
2. `docs/store/` が 15 ロケール（`locales.json`・es-ES・pt-PT のフォルダ・`store-shots` の写真の対応）で L-9 が緑。R の逆翻訳で × なし。de に「ß を使わず」が残っていない。
3. `holidayCheckSoldRegions` が 175、M7B.md の表が 174 の国・地域。
4. `docs/support-replies/` が定型文 7 つ。
5. 本人の届け出が通り（§11.5 の GET）、§11.1 の順 5〜9 が済み、結果を本人に報告した。**届け出が 1.2 に間に合わなければ 5 だけ後でよく、1.2 の完了は止めない**。
6. M7B-23・M7B-24 の答えが M7B.md にある。

### 11.9 確かめられなかったことと出典

**確かめられなかったこと**: 届け出が通るまでの公式の日数／確認中に更新の提出が止まるか／`PATCH territoryAvailabilities` が公開済みのアプリに効くか／`contentStatuses` の値の全部／en-GB があるときオランダとスウェーデンに何が出るか／EU 域外の製造者の CRA 上の扱い／2026-08-18 の開発者契約に本人が同意済みか／実機の Safari で `apps.apple.com` を開いたときの動き（E の表は Mac にした）／Apple の国を選ぶページ `ww/` の中身（生の HTML に国の一覧が無く、JavaScript で出ると読んだので、URL に使わなかった）／ドイツ版の按分返金の実際の手続き。

**実測の追記**（第 4 版の見直し。2026-11-04）: 国を選ばない `https://www.apple.com/legal/internet-services/itunes/` は United States の版を返し（HTTP 200、転送なし）、`right of withdrawal` が 0 件だった。`https://www.apple.com/legal/internet-services/itunes/ie/terms.html` は `Right of withdrawal` と `Withdraw Transaction` を含み、起算は “within fourteen (14) days from when you received your receipt”、サブスクリプションは “can only be cancelled following the initial subscription”（curl で確かめた。引用は短く）。トレーダー情報の見え方は Goodnotes 1 本で測った（§11.4）。

**出典**（読んだ日は全部 2026-11-04）:

**Apple（一次情報）**

- A1 [Manage European Union Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)（更新日の表示なし）
- A2 [同じページの日本語版](https://developer.apple.com/jp/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- A3 [New requirement for app updates in the EU（2024-10-17）](https://developer.apple.com/news/?id=yfacfeal)・[Upcoming requirement（2024-10-16 から）](https://developer.apple.com/news/upcoming-requirements/?id=10162024a)
- A4 [New requirement for apps on the App Store in the EU（2025-02-18）](https://developer.apple.com/news/?id=6agg0lja)
- A5 [App information（DSA の行）](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- A6 [Manage availability for your app on the App Store](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/)
- A7 [Set availability for In-App Purchases](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-availability-for-in-app-purchases/)
- A8 [Changes for apps in the European Union（支援のページ）](https://developer.apple.com/support/apps-in-the-eu)・[お知らせ（2026-08-18）](https://developer.apple.com/news/?id=gmws0jgp)
- A9 [Apple Newsroom（2026-08-18、発効 10-01）](https://www.apple.com/newsroom/2026/08/apple-announces-changes-for-apps-in-the-european-union/)
- A10 [Apple Media Services Terms（アイルランド、2026-09-14 更新）](https://www.apple.com/ie/legal/internet-services/itunes/ie/terms.html)
- A11 [同じ（ドイツ、2026-09-14 更新）](https://www.apple.com/legal/internet-services/itunes/de/terms.html)
- A12 [Licensed Application EULA（標準 EULA）](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
- A13 [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/)
- A14 [DAC7 の日本語のヘルプ](https://developer.apple.com/jp/help/app-store-connect/manage-compliance-information/manage-information-for-directive-on-administrative-cooperation-7th-amendment/)
- A18 [App Store localizations（国ごとの既定と追加の言語）](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations)
- A20 [Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)

**Apple の開発者フォーラム（公式のサイトだが、利用者の報告。A19 だけ Apple の技術者の回答）**

- A15 [thread 759771（2024-07）](https://developer.apple.com/forums/thread/759771): 確認できないとのメール、電話のサポートで解決
- A16 [thread 820581（2026-03）](https://developer.apple.com/forums/thread/820581): 41 日確認中。[thread 848065（2026-09）](https://developer.apple.com/forums/thread/848065): 1 か月以上
- A17 [thread 820332（2026-03）](https://developer.apple.com/forums/thread/820332): 10 日以上確認中、更新や管理に困るとの投稿
- A19 [thread 722177（2022-12）](https://developer.apple.com/forums/thread/722177): 言語の落ち方

**個人の体験談（日本語。2024 年。画面の指示を優先）**

- [beatnix（2024-03-20）](https://studio.beatnix.co.jp/diary/apple/dsa/): 個人、健康保険証は不可、マイナンバーカードで通過、2〜3 日
- [Zenn（2024-08-16）](https://zenn.dev/hsylife/articles/f29c81f88f5a7c): 確認中は訂正できない、HEIC は不可
- [micss（2024-09-02）](https://www.micss.biz/2024/09/02/7315/)・[Qiita（2024-03-22）](https://qiita.com/temoki/items/309d422ffcad651d769a): 画面の順、「Call Me」、結果は Account Holder のメールへ（法人の例）

**EU の公式の文**

- B1 [C-191/15 判決（2016-07-28）](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:62015CJ0191)
- B2 [規則 1215/2012（Brussels I bis）](https://eur-lex.europa.eu/eli/reg/2012/1215/oj/eng)
- B3 [GDPR 第 13 条（項目の一覧。読めた写し）](https://gdpr-info.eu/art-13-gdpr/)（非公式の写し。公式は EUR-Lex の 32016R0679）
- B4 [EDPB Guidelines 3/2018（域外の適用と代理人）](https://www.edpb.europa.eu/system/files/documents/files/file1/edpb_guidelines_3_2018_territorial_scope_after_public_consultation_en_1.pdf)
- B5 [ODR の廃止（委員会）](https://consumer-redress.ec.europa.eu/site-relocation_en)・[指令 2023/2673](https://eur-lex.europa.eu/eli/dir/2023/2673/oj/eng)
- B6 [十分性の決定（委員会）](https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection/adequacy-decisions_en)
- B7 [CRA のガイダンス（2026-07-27）](https://digital-strategy.ec.europa.eu/en/library/commission-publishes-new-guidance-support-timely-cyber-resilience-act-implementation)（Annex の本文を読んだ: 例 3、第 15 点、第 104〜105 点、第 210 点）・[CRA の要約](https://digital-strategy.ec.europa.eu/en/policies/cra-summary)
- B8 [報告の義務（2026-09-11 更新）](https://digital-strategy.ec.europa.eu/en/policies/cra-reporting)・[適合性の評価（2026-07-31 更新）](https://digital-strategy.ec.europa.eu/en/policies/cra-conformity-assessment)・[製造者（2026-08-14 更新）](https://digital-strategy.ec.europa.eu/en/policies/cra-manufacturers)
- B9 [指令 2024/2853（EUR-Lex）](https://eur-lex.europa.eu/eli/dir/2024/2853/oj/eng)・[委員会の説明](https://transition-pathways.europa.eu/retail/legislation/new-eu-product-liability-rules-will-apply-online-platforms-and-software-december)。第 15 条の文は[写し](https://streamlex.eu/articles/pld-en-art-15/)で確認
- B10 [EAA（委員会のページ）](https://commission.europa.eu/strategy-and-policy/policies/justice-and-fundamental-rights/disability/union-equality-strategy-rights-persons-disabilities-2021-2030/european-accessibility-act_en)。零細企業の定義と第 4 条 5 項は[二次資料](https://www.xictron.com/en/blog/accessibility-act-exemptions-microenterprises-2026/)と[理事会の発表](https://www.consilium.europa.eu/en/press/press-releases/2018/12/19/more-accessible-products-and-services-for-eu-citizens-council-approves-the-provisional-agreement-with-the-european-parliament/)で確認（EUR-Lex の条文は道具で読めなかった）

**その他**

- [GitHub Pages の説明（訪問者の IP）](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)

## 12. 役と統合の順番（第 4 版）

### 12.1 役の表

実装は第 3 版の順で途中まで進んだ。**済んだ役は走らせ直さない**。済んだ役の成果への追加の仕事は、新しい役か、ほかの役の「追加の段」として下に書いた（その役の中身を書き直させない）。

| 役 | 状態 | 第 3 版からの仕事 | 第 4 版で足す仕事 |
| --- | --- | --- | --- |
| S0 | 済み | `build.py` の Kit 用の出力 | なし |
| K1 | 済み | `Package.swift`・`UILanguage`・`kit-K.json`・`Text11`・`DateText`・`LayoutWords`・`DATA_1_1.sha256` | **K1+**（K2 の頭の段）: `DateText` の注記、`weekTitle(monday:)` を `first:` に（KitChecks の該当の呼び出しも）、`kit-K.json` の comment（値は変えない）。`DATA_1_1.sha256` の作り直しは B11 |
| S1 | 済み | `baseline.py`・`ja-baseline.tsv`・`ja-exceptions.txt`・`build.py` のアプリ用・lint の 4 つ・`L10n.swift` | なし（基準の作り直しは B11、L-13・L-14 は S2） |
| C1 | 済み | `ja-baseline.yml`・`compare_shots.swift`・`ja-baseline-ref.txt` | なし（1.1.1 への読み替えは B11） |
| LA | 済み | 規約類とストアとサポートの原稿 | なし（直しは LA2） |
| H | **途中**（作業の木に未 commit の変更がある。それを下書きとして続ける） | §5 の全部 | `HolidayChecks.swift` の `holidayCheckSoldRegions` に EU 27（AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE）を足して 175。「148」「O-4」のコメントを直す。§5.10 の表は 174 の国・地域。データは 27 か国ともある。**`gen.py` の `coverage_range` を 0-30 の形に直して作り直す**（スロバキアの誤った「データがありません」を防ぐ、§5.10） |
| **B11（新）** | 未 | — | 1.1.1 の取り込みと基準の移し替え（§1.5）。**2 回**（仮の `<1.1.1>` で S2・U・P の前に／本物の `<1.1.1>` で CI の最後の前に）。1 回目で `tools/weekstart-compat/` の材料も移す（手順 7b） |
| **LA2（新）** | 未 | — | LA の原稿の直し。X の前。**EU の分は B11 より前でも進めてよい**（docs だけ。§1.5 の「いつ」）、残りは B11 の後。**EU**: §11.3 の文（T-1〜T-9・P-1〜P-4・S-1〜S-6。Apple の規約の URL は `ie/terms.html`）、`docs/store/locales.json`（es-ES・pt-PT、fr-FR・de-DE・it の店頭）、`docs/store/README.md` の EU の文と写真の説明（「EU では売らない」「スイス」「ß を使わず ss」をやめる。es・de・fr の読み手、§6.1 の 9）、`docs/support-replies/`（`refund.md`・新しい `privacy-request.md`・`README.md`）。**週の始まり**: §10.4 の説明・審査メモ・SUPPORT の括弧と FAQ、§6.3 の新機能の文（`source-ja/whatsnew.txt`・`whatsnew.en-US.txt`・`ja/whatsnew.txt`・`en-US/whatsnew.txt`）。**1.1.1**: §1.5 の表。**英語版も同じ commit で**。審査メモは 4,000 バイトを測る |
| K2 | 未 | K の後半（§5.4 の 12 か所など） | K1+ を頭に。§10.1 の Kit の全部、§10.8 の KitChecks（W-1〜W-5・G-5）・XCTest・`Compat12Tests`、`PlanTextTests.testEuroSavings` |
| S2 | 未 | S の後半（lint の残り・F-12〜F-15 など） | L-13・L-14 と L-7・L-9 の足し（§2.7）、`WebImportSheet` と `ExportBuilder` の週の始まり（§10.5）、`WebImportPhase.done` の `otherWeekStart`・`toastText`（§0）、`import.otherWeekStart.*`、`StrokeCensus` の `pageLabel(_:language:)`、テスト |
| U | 未 | §1.4・§5.6〜§5.9・§7.3・§7.4 | §10.3〜§10.5・§10.7 の全部（`dataCheck`・`weekStartSwitch`・`prepareAtLaunch`・`WeekStartNotices`・`penTouchedThisLaunch`・`pendingAdoption`）、`Persistence/WeekStartChoice.swift`、`Views/WeekStartSettingsSection.swift`、`EventStoreModel`、**`runImport` で `otherWeekStart` の値を作って渡す・`closeImportSheet`・`large.map` の直し**（§10.5、L-7）、`EventKitService.events(in:calendars:)` を消す、テストと UI テスト、`toast.pinchHint` と 1.1.1 の分（§1.5） |
| P | 未 | §4 | `monthHeaderWeekdays`、`StickyHeaderView`・`PDFPageRenderer` の並びと色（§10.5）、テスト、F-16 の読み替え |
| X・R | 未 | 9 言語の訳と逆翻訳 | §10.4 の 23 キー、`toast.pinchHint`、用語集、**ストアの es-ES・pt-PT**（pt-PT は別に書く）、de は標準のドイツ語、fr はフランス、es の画面は中南米だけの語を避ける、§11.3 の英文の逆翻訳（`docs/i18n/back/legal-en.md`）、言い直した説明と新機能の文 |
| W | 未 | §6.5 | §11.3 の文（P-4 で変わる見出しの `id` の参照も）、commit ③（M7B-23）、(10) の検査と `check-legal` の `XX`・`Month DD` の足し、`r111-legal` を含む所から切る |
| 検証 | 未 | 4 観点（Kit とデータ・アプリ・言葉・祝日） | **観点を 2 つ足す**: 「週の始まり」（K-11・隠れる線・月曜の道の不変・切り替えの順番・移行・L-13）と「EU と規約」（§11.3 の文、15 ロケール、公開の順の文）。「言葉」の観点の「EU 専用の es-ES・pt-PT は入れない」は逆になる。「Kit とデータ」の観点の基準は `<1.1.1>` |
| FIX | 未 | 検証の直し | 同じ |
| C | 未 | §2.2・§7.5・README・DESIGN・M7_PLAN・M7B.md・commit | `build.yml` の「Data code frozen since 1.1.1」、`tools/weekstart-compat` の段（材料は B11）、`l10n-shots`・`store-shots` の引数と写真と組（§7.5）、README・DESIGN・M7_PLAN の K-11 と EU の文（§6.8、§8 の 10）、`ja-baseline.yml` の写真の手順の相互の確かめ |

**新しい実装の役は B11 と LA2 だけ**。週の始まりの実装を別の役にしないのは §10.9 の理由。

### 12.2 残りの順番（第 4 版。§12.3 の前半は済み。§12.3 と食い違えばこちら）

**前提**（リード）: この第 4 版を `wt-m7b` の `docs/M7B_CONTRACT.md` に置く。本人の答え（M7B-23・M7B-24）は待たずに進めてよい（どちらの答えでも無駄にならない形にした: English のリンクは commit ③ に分け、EU を入れる操作は §11.1 の順 8 で本人の「はい」の後）。本人が「EU をやめる」と答えたら、O-4 を第 3 版に戻し、§11 の文と es-ES・pt-PT を外す判断をリードがする。

→ **H の続き**（前の H の途中の変更を下書きとして。EU の 27 か国を足す。coverage を直す）→ **B11 の 1 回目**（§1.5。先に作業の木を役ごとに commit。1.1.1 の commit（§1.5 の「いつ」の定義）がまだ無ければ K2 と LA2 の EU の分の後へ。そこで止めて 1.1.1 を待つ）→ **K2**（K1+ → K の後半 → §10 の K の分。実数 N を M7B.md に）→ **LA2 の EU の分**（docs だけ）→ **LA2 の残り** と **S2・U・P** を並行（どれも K2・H・B11 の後）→ **元のキーを固める**（リードが「キーの凍結」を宣言。§10.4 の 23 キーと `toast.pinchHint` を含む）→ **X**（用語集 → 9 言語の訳 → ストアの文。es-ES・pt-PT を含む）→ **R**（逆翻訳。アプリ・法律（§11.3 を含む）・ストア）→ **X**（REVIEW.md、× を直す → R がもう一度）→ **W**（`r111-legal` を含む所から。commit は ①・②・③）→ **検証**（6 観点）→ **FIX** → **C**（§7.5 ほか。役ごとに commit。push しない）→ **CI-0**（リード。仮の `<1.1.1>` のまま `m7b` を push して CI を走らせる。push は `m7b` のブランチと、同じ commit を `ja-baseline` の名前でだけ。main には入れない。この Mac に XCTest は無いので、**単体テストと UI テストはここで初めて走る**。`ja-baseline.yml` の 1 回目もここ。これが無いと、1.1.1 の審査が通るまで XCTest が 1 度も走らず、検証の FIX も CI の前に終わってしまう）→ **FIX2**（CI の失敗を直す役。緑になるまで繰り返す。J と K-7 の期待は変えない）→ **B11 の 2 回目**（1.1.1 が main に入った後。§1.5 の手順の 8）→ **リード**（CI 緑 → `ja-baseline.yml` を `<1.1.1>` でもう一度走らせ（1.2 の最後の CI と同じ日）、2 つの run の `env.txt` が同じことを見る → J-4 の比較（ツールバーの帯も、§8 の 3）→ 写真の確認ページを本人に（§8 の 8）→ 本人の答え（直しがあれば直して CI からやり直す）→ testflight.yml を `--ref m7b` で走らせる → 1.2 (N) が本人の端末に届いたら §8 の 9 の表を渡す（頭に 1.2 (N)）→ 並行して `store-shots` → 言語ごとの確認表を本人に（§8 の 11。15 ロケール）→ 本人の「この内容で入れてよい」の後に、Connect が 1.2 の版を受け付けるようになってから A の原稿を入力 → 本人へ報告）→ **本人**（§8 の 9。結果をリードに）→ **リード**（本人の確かめが済み、1.1.1 が審査を通って main に入っていれば、本人に平易に報告して「はい」を得てから `m7b` を main に merge する、0-35、0-40）→ **本人**（「審査へ提出」。**EU は入れないまま**。審査を通ったら、公開（手動リリース）の日を前もってリードに伝える）→ **公開の日**: §11.1 の順 5〜9（リードが公開の直前の確認で「はい」をもらい、`r111-legal` が先に main に入っていることを確かめて `m7b-legal` を merge → 200 を確かめる → 本人が手動リリース → リードがロシアの店頭を確かめる → 届け出が通っていれば本人の「はい」の後に EU を入れる → 本人に報告）→ Connect の英語などの欄で直せるものを英語のページに替えてよいかを本人に聞き、「はい」なら替える（説明は 1.3 で、0-38）→ M7B.md に結果。

**並行して本人**: M7B-24 に答えた後で、1.1.1 が審査を通ったらすぐ届け出（§11.1 の順 1、§11.4）。リードは届け出の後、毎日 GET で状態を見る（§11.5）。

### 12.3 第 3 版の統合の順番（記録。済んだ役の定義として残す。残りは §12.2 が優先）

統合の順番: **前提**（済み: 本人の「取り込んでよい」で 1.1 を main に merge した e7b4d2f（M7A.md:500）。リードが e7b4d2f から `m7b` を切り、C が e7b4d2f9c99dcfe4f7ba27ef9f81fe0466bf093d を M7B.md と `tools/l10n/ja-baseline-ref.txt` に書く。リードは e7b4d2f の CI の結果（時間・EraserAndBelowDayUITests の 8 本・`repro: A17`・`B8` の値。M7A.md に無い）を M7B.md の前提に書く。本人に新しく聞く問いは無い（M7B-21 は聞かない。M7B-22 は既定のまま）。作業ツリーの未追跡の複製は commit に入れない）→ **リードの取り寄せ**（M7B-10。python-holidays と依存の wheel と hash、§5.1。取り寄せた物を本人に平易に報告する。3.9 で入らないときは M7B-20 を §9 の書き方で聞く）→ **S の最初**（`build.py` の Kit 用の出力だけを先に作る: `tools/l10n/source/kit-*.json` を読み、`DayKit/KitStrings.generated.swift`（§2.3 の形と `keys`）を書く。アプリ用の出力・`--check`・lint は S の前半で）→ **K の前半**（`Package.swift`（§2.6）→ `UILanguage` → `kit-K.json`（`kit.date.ja.*`・`LayoutWords` のキー・`kit.app.name` など。ja は 1.1 の文）を書いて `build.py` で生成 → `Text11` の写し（e7b4d2f）→ `DateText`（ja の道を先に、J-3 の確かめを作ってから他の言語）→ `LayoutWords` → **ここで KitChecks が今のまま全部緑であることを確かめる** → `DATA_1_1.sha256`（e7b4d2f の 18 行））と **H**（生成器（`iso-regions.txt`・`lastOfficialYear`・`notice`・`coverage`・差の無い州・表示名・振替の型・"%s" の国）→ `HolidayData`（新しい版。0.83 との差と、本人に見せる期待の確かめ直しを M7B.md に、0-14）→ `kit-H.json`（`kit.holiday.estimatedSuffix`・`kit.holiday.dayOff`）を書いて生成 → `HolidayCalendar`・`HolidaySetting`・`HolidayFile`（検査）・`HolidayStore`・`JapanHolidayBridge`・`HolidayDataLicense` → `HolidayChecks.swift` → `WorldHolidaysTests`）と **S の前半**（`baseline.py` と `ja-baseline.tsv`（e7b4d2f の 515 行）→ `build.py` のアプリ用の出力（`jaOnly`・`allowJapanese`・`lines`）→ `lint.py` の L-1（凍結した Ink の 6 件の例外を含む）・L-3・L-4・L-10 → `L10n.swift`）と **C の前半**（`ja-baseline.yml`・`compare_shots.swift`。リードが `ja-baseline` のブランチを push して e7b4d2f の写真を 1 回目に撮り、写真の手順を確かめておく）と **L・A**（原稿。L は e7b4d2f の日本語の 3 文書から）を並行（生成物の `KitStrings.generated.swift` は、最後に元を足した人が `build.py` で作り直して commit する。2 人が並行で足したら、後の人が両方の元で作り直す。L-10 が CI で一致を見る）→ **K の後半**（H の型を使って §5.4 の 12 か所・tone（`workday:` は既定値なし）・`PageNavigation`・`PlanText`・`LegalLinks`（`englishPagesPublished = false`）・`StrokeBudget`・`AppExport` → `kit-K.json` の残り → G-1〜G-4（「W」を含む）と新しい節 → XCTest → 実数 N を M7B.md に）→ **S・U・P**（K・H の後。各自の元のファイルにキー → コードを `L` に → lint の L-7・L-8 → 各自のテスト。S は §4.4 の F-12〜F-14・§4.5 の F-15 と `ToolbarFitTests`。U は移行（"auto" も書く）・`HolidayChoice`・`CalendarRootScreen` の `holidays` と `makePaper` の 1 つの暦（§5.6）・設定の画面（ライセンスの行は `versionRow` の上）・写真モード（`Config.holidays` は `select` の後ろ）・EventKit の語・`XCTestStandIn.swift`（`otherElements`・`identifier` だけ）・UI テスト（LanguageUITests と、YearTapUITests・EraserAndBelowDayUITests の起動の引数）。P は `PaperWords`・F-0〜F-11（ja は 1.1 の道）・§4.5 の F-16・PDF・`PaperFitTests`（`PaperView` の口と `PaperContent` の各型の形を保つ）。だれも凍結したファイルが使う名前を変えない、§0 の接点）→ **元のキーを固める**（リードが「キーの凍結」を宣言。以後のキーの追加は X に知らせる）→ **X**（用語集（ツールバーの語と 10 pt の幅、投げなわのメニューと見出しの字の幅、ダブルタップ／スクイーズを含む）→ 9 言語の訳 → 生成）→ **R**（逆翻訳。アプリ・法律・ストア（説明の最後の 1 文・promo・サブスクリプション・名前の退き先・審査メモを含む））→ **X**（REVIEW.md、× を直す → R がもう一度）→ **W**（L が固まってから。`m7b-legal` を 8e1dac7 か、1.1 の公開の後なら main から。commit は ① 英語の 3 ページ・② 日本語の §6.4 の 4 つに分ける）→ **C**（project.yml・build.yml（ジョブ 110 分・UI テストの段 40 分・`l10n UI:`・bundle check の PrivacyInfo・`env.txt`）・store-shots.yml（push のブランチ `store-shots` でも走る）・README と DESIGN（1.1 の後半の分も）・M7_PLAN の §6.8・M7B.md）→ **リード**（CI 緑 → `ja-baseline.yml` をもう一度走らせ（1.2 の最後の CI と同じ日）、2 つの run の `env.txt` が同じことを見る → J-4 の比較（ツールバーの帯も、§8 の 3）→ 写真の確認ページを本人に（§8 の 8。頭は CI の写真の commit）→ 本人の答え（直しがあれば直して CI からやり直す）→ testflight.yml を `--ref m7b` で走らせる（main は審査中の 1.1 のまま、0-40）→ 1.2 (N) が本人の端末に届いたら §8 の 9 の表を渡す（頭に 1.2 (N)）→ 並行して `store-shots`（`m7b` を `store-shots` の名前で push して走らせる）→ 言語ごとの確認表を本人に（§8 の 11）→ 本人の「この内容で入れてよい」の後に、Connect が 1.2 の版を受け付けるようになってから（1.1 の審査の間は新しい版を作れないことがある）A の原稿を Connect に入力 → 本人へ報告）→ **本人**（§8 の 9。結果をリードに）→ **リード**（本人の確かめが済み、1.1 が審査を通っていれば、本人に平易に報告して「はい」を得てから `m7b` を main に merge する（0-35、0-40））→ **本人**（「審査へ提出」。審査を通ったら、公開（手動リリース）の日を前もってリードに伝える）→ **リード**（公開の日に、1.1 の `m7a-legal` が先に main に入っていることを確かめ、公開する物の一覧（日本語の 3 ページの差分の全文・英語の 3 ページの R の逆翻訳の要点・公開する URL）を本人に見せて「はい」をもらってから、`m7b-legal` の ①・② を merge し、URL が 200 を確かめる（§6.5）→ Connect の英語などの欄で直せるものを英語のページに替えてよいかを本人に聞き、「はい」なら替える（説明は 1.3 で、0-38）→ M7B.md に結果）。

### 12.4 本人がやること（Claude が代行できない）

(1) **今、答えてほしい問いは 2 つ**（M7B-23: 日本語の 3 ページに English へのリンクを足してよいか／M7B-24: 新しく分かった EU の負担を知ったうえで予定どおり出すか、専門家に聞くか。§9）。M7B-20 は必要になったときにリードが聞く。M7B-21 は聞かない。M7B-22 は気になるときだけ。(2) **M7B-24 に答えた後で、1.1.1 が審査を通ったらすぐ、EU の届け出**（§11.1 の順 1、§11.4。住所・電話番号・メールアドレスの入力と書類。結果のメールをリードに）。(3) リードが渡す写真の確認ページ（§8 の 8）を見て、英語・ポルトガル語・中国語などの紙とツールバーと投げなわのメニューの見え方を、字が切れていない・重なっていない・はみ出していない・手書きが同じ位置か（日曜始まりの写真は日付についていくか）、で判断する。(4) TestFlight 1.2 が届いたら、§8 の 9 の表の頭の版と、アプリの設定 › 情報 の「バージョン」が同じことを見てから 0〜14（0 で iPhone の自動アップデートを止め、2b・4b〜4e で週の始まりを試し、5 で iPad mini の言語を英語にして見て（言語を足すときに聞かれたら日本語のままを押す）、8 で日本語に戻し、9・9b で iPhone を 1.1.1 のまま同期を見て、10 で iPhone も 1.2 にし、13 で線の本数を教え、14 で自動アップデートを戻す）。(5) 言語ごとの確認表（§8 の 11。15 ロケール）を見て、「この内容で入れてよい」かを答える（M7B-18 の「はい」の約束どおり、見てから入れる。es-ES・pt-PT はこのとき一緒に聞く）。(6) 実機の確かめの後、1.2 を main に入れる前のリードの報告に「はい」か「いいえ」を答える（1.1.1 が審査を通った後）。(7) 「審査へ提出」（EU は入れないまま）。審査を通ったら、公開する（手動リリースを押す）日を前もってリードに伝える。その日にリードが規約のページを公開するので、公開の直前にリードが見せる文（EU の文を含む）と URL に「はい」か「いいえ」を答える。(8) 公開の日に、EU の 27 か国を入れてよいかを答える（届け出が通っていれば。リードが API で入れられないときは本人が画面で）。その後の確かめ（§8 の 9 の E の表）。App Store の英語などの URL を英語のページに替えてよいかも答える。(9) 英語などの問い合わせが来たら、Claude の下書きを読んで自分で送る。(10) 1.2 を出してから 1 年以内（遅くとも CRA の本体が始まる 2027 年 12 月より前）に、できれば 1 回、専門家に §11.6 の 2・5・8 を聞く（M7B-24 の答えしだい。リードが §11.6 の問いを英語の相談票にまとめる）。もし悪用された弱点が見つかったら 24 時間以内に EU の窓口へ報告する（§11.6 の CRA。リードが手順を案内する）。(11) 問い合わせが解決したら、そのメールと下書きと、翻訳に使った Claude の会話を消す（目安。プライバシーポリシーの第 12 節の「必要がなくなったら消します」の約束。手順は `privacy-request.md`）。Claude のデータ利用の設定（モデルの改善に使うか）も 1 回見る（§11.6 の 6）。

### 12.5 第 4 版の見直しの指摘の扱い（2026-11-04 の 2 本）

見直しの 1 本目は実装の目線（`wt-m7b` の実コード・`fix-1-1-1` の d0fdbff・`R1_1_1_CONTRACT`・`B_DESIGN`・`HolidayData`）、2 本目は本人と EU の文の目線（今の規約類・ストアの原稿・Apple の一次情報）。blocker と major は全部入れた。**指摘の中で採らなかったのは、下の「採らなかった所」の列にある部分だけ**。2 本で重なった 3 つ（シートの下のトースト、両方の形で黙る所、grep）は 1 つにまとめた。

| # | 重さ | 指摘 | 扱い | 入れた所 | 採らなかった所とその理由 |
| --- | --- | --- | --- | --- | --- |
| 1-1 | blocker | 今お使いの方の月曜の手書きが知らせなしで隠れる（`.synced` の意味、両方の形で黙る、appear の見落とし） | 採った（判定の印だけ変えた） | §10.3 の 4 の (1)(2)、0-43、§9、§10.8 | **印は指摘の `lastSyncAt != nil` でなく `sync.state.zoneToken != nil` にした**。指摘の「`lastSyncAt` は pull の中だけ」はコードと違い、`push` の各レコードの保存（`SyncEngine.swift`:717）と `cloudErase`（:808）でも書かれるので、指摘の案では指摘の道そのものを防げない。`zoneToken` は `pull` と `cloudErase` だけが書く |
| 1-2 | blocker | 書いている最中に切り替わって線を失う | 採った | §10.3 の 4 の (3)、§10.8 | 無し |
| 1-3 | major | 切り替えの順番に自動の確かめが無い | 採った | §10.5、§10.7、§10.8 | 「待ちの分岐も同じ純関数に」は 2 つに分けた。順番は `weekStartSwitch`、待ちは `dataCheck`（呼ばれる時も引数も違い、1 つにすると 5 つの閉包を持つ関数になってテストが読みにくい。どちらも static の純関数） |
| 1-4・2-6 | major | トーストがシートの下で消えて「案内済み」になる | 採った | §10.2、§10.4、§8 の 9 の 4d、§10.8 | 無し。名前は `WeekStartNotices` の値にした（`pendingWeekStartToast` 1 つだと、合わせた知らせと「もう一方」が同時に来たときに片方を失う） |
| 1-5 | major | `WeekStartChoice.current` が起動で入らない | 採った | §5.6、§10.5、§0、§10.8 | テストは `testCurrentIsSetAtInit` でなく `testPrepareAtLaunchSetsCurrent`（画面の `init` をテストで呼ぶと `UIDevice` などに触る。起動の順を static に切り出す、という指摘の別案の方） |
| 1-6 | major | 取り込みの文が担当の割り当てでは作れない | 採った | §0、§10.2、§10.5、§12.1 | 無し |
| 1-7 | major | `toast.pinchHint` の文が 1.1.1 の最終と違う | 採った | §1.5 の手順 6、§6.1、§6.2、§6.3 | 無し |
| 1-8 | minor | 1.1.1 の一覧が古い、`demoEvents` の形 | 採った | 頭、§1.5、§0 | 無し |
| 1-9 | minor | L-13 が `EventKitService` で落ちる | 採った（消す方） | §10.5、§12.1 | L-13 の例外には入れない（呼び手が無いので残す理由が無い） |
| 1-10 | minor | `pageLabel` の 2 つの形、L-7 | 採った | §0、§2.7、§10.1 | 無し |
| 1-11 | minor | `resolve` と `launchAutomatic` | 採った | §0、§10.3 | 無し |
| 1-12 | minor | 順番の穴（CI、J-4 の 1 回目、compat の読み先と材料） | 採った | §12.2 の CI-0・FIX2、§1.3、§1.5、§7.5、§10.8 | 無し。J-4 の 1 回目は CI-0 と同じときに決めた |
| 1-13 | minor | 取り込みの後の判定の説明、`weekPages` が墓標だけのページも数える | 採った | §10.3 の 4 の (1)、§10.4、§10.1 | **`peek` で生きた線のあるページだけを数える案は採らない**（判定と設定を開くたびに全部の週のファイルを解凍して読むことになる。第 4 版の調べで月について同じ理由で断った。文を「週のページが」に和らげた） |
| 1-14・2-15 | minor | §10.10 の grep が当たらない | 採った | §10.10 | 無し |
| 1-15 | minor | スロバキアの `coverage` | 採った（規則を直す方） | 0-30、§5.10、§12.1 | SK だけの例外にはしない（今のデータに当てて、変わるのは SK の until と 4 か国の from だけと確かめた） |
| 1-16 | minor | 「commit がそろったら」が定義されていない | 採った | §1.5、§12.2 | 無し |
| 2-1 | major | Apple の規約の URL が米国版に着く | 採った | §11.3、§6.5、§11.9 | **国を選ぶページ `ww/` は使わない**（指摘どおり、一覧が出ることを確かめられなかった）。指摘の「そのページの上の」は位置を確かめ切れないので「そのページの」にした |
| 2-2 | major | 撤回の権利の起算と初回だけの条件 | 採った | T-4、S-4、`refund.md`、§11.6 | 無し |
| 2-3 | major | ドイツ版の按分返金 | 採った | T-4b、§11.6、`refund.md` | 無し |
| 2-4 | major | プライバシーの新しい節と古い文の矛盾 | 採った | P-4、S-6 | 無し |
| 2-5 | major | 情報開示の返事が事実と違うおそれ、消す手順が無い | 採った | §11.3、§6.7、§11.6 の 6、§12.4 の (11) | 無し |
| 2-7 | major | 届け出の確認中に 1.2 の提出が止まる場合の分岐 | 採った（**順 1 は案を示すだけでなく既定を入れ替えた**） | §11.1、§9、§11.4、§11.7、§12.2、§12.4 | 「案として本人に示す」から「既定を変えて知らせる」に変えた。待つ代償（数日）より、1.1.1 の再提出を巻き込む危険の方が大きく、問いを増やすほどの差がないため。本人の一言で戻せる |
| 2-8 | major | 住所などが日本からも見えること | 採った | M7B-24、§11.4、§11.9 | 無し |
| 2-9 | minor | 切り替えの文が読み取りにくい、「薄いマス」 | 採った | §10.4、§6.2、§8 の 9 の 4d | 本人の手順の中の「薄く出ている」は残した（画面の見た目の説明で、アプリの文ではないため） |
| 2-10 | minor | E の表 | 採った | §8 の 9 の E の表 | 無し |
| 2-11 | minor | §11.4 の手順の抜け | 採った | §11.4 | 無し |
| 2-12 | minor | 「M7B-24 に答えた後で」の条件 | 採った | §11.1、§11.4、§12.2、§12.4 | 無し |
| 2-13 | minor | 週末にまたいで書いた言葉が分かれる | 採った | §10.2、§9、§8 の 9 の 4d・4e、FAQ | 無し |
| 2-14 | minor | 両方の形で知らせない | 形を変えて採った（1-1 に合わせた） | §10.3 の 4 の (2) | 「設定を変えずに知らせるだけ」にはしない。1-1 のとおり、もう一方の方が多ければ合わせてから知らせる（今お使いの方を月曜のままにする本人の了承を優先） |
| 2-16 | minor | 公開中の日本語の説明の古い 1 行、TERMS の「日本の祝日」 | 採った | §6.6、§8 の 11、T-9 | 説明の直しは確認表で本人に聞く（公開される文なので既定で変えない） |
| 2-17 | minor | L-9 が価格を見ていない | 採った | §2.7、§6.1 | 無し |
| 2-18 | minor | S-5 の日付、`check-legal`、PRIVACY 第 10 節 | 採った（形を変えた） | §11.1 の順 5、§6.5、§11.3、§11.6 の 9 | `check-legal` に `XX` を足すと、S-5 を `XX` のまま W が commit した時点で落ちる。W は S-5 の行を Web に入れず、公開の日にリードが日付を入れて足す形にした |
| 2-19 | minor | P-3 の移転の断り、T-3 の場所 | 採った | §11.3 | 無し |
| 2-20 | minor | CRA と専門家の期限、CE マーク、Impressum | 採った | M7B-24、§6.8、§11.6、§12.4 の (10) | 無し |

