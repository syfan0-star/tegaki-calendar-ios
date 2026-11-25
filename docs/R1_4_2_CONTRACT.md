# 1.4.2 実装契約（ペンの色を増やす・メモ欄の紙を選べるようにする）

> **第 1 版（2026-11-24）**: 1.4.1 を 11/24 に公開し、main（2e3ee75）にまとめた後に書いた最初の版です。
>
> **第 2 版（2026-11-24）**: 2 つの目の見直し（本人の段取りと 1.4.1 の教訓／コードとの突き合わせ）の指摘を直した版です（直した所は §14）。
>
> **本人が読む所**: すぐ下の §0（まとめ）だけで足ります。§10 の確かめ表は、TestFlight のビルドが届いたときに Claude が番号を書いて改めて渡します（今は開かなくて大丈夫です）。§1 から後は、作る人のための約束です。
>
> **この文書の決まり**: 1.4.2 の作業はこの文書に従います。元は本人の 2026-11-07 の 2 つのご依頼と、その夜の答え「ほかは全部おすすめで」（[PLAN_PEN_COLORS.md](PLAN_PEN_COLORS.md)・[PLAN_MEMO_PAPER.md](PLAN_MEMO_PAPER.md)）、[M7_PLAN.md](M7_PLAN.md) §4 の 1.4.2 の行と「次の版」の行、[R1_4_1_CONTRACT.md](R1_4_1_CONTRACT.md) §1.4 の申し送り（色の板は左右の縦のツールバーからも開く）です。2 つの計画の §5（作る側の控え）は 1.2.1（r121）のコードで書かれていて、行番号も前提も古い（凍結の表は 18 行ではなく 20 行、週のメモ・横につないだ紙・縦のツールバー・のぞきの「動かす」を知らない）。**食い違う所はこの文書が優先**です。結果と前もっての宣言は `docs/R1_4_2.md`（S0 でリードが作る）に書きます（この文書の §14 は契約の版の記録だけ）。節の形は [R1_4_1_CONTRACT.md](R1_4_1_CONTRACT.md) にそろえました。
>
> **材料**: 調べ役の地図 3 つ（ペンの色・メモ欄の紙・段取りと CI。2026-11-24 に main 2e3ee75 を読んだだけ）。**行番号は main 2e3ee75**（`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は 1.4.1 のビルド 31 の fbd1f7a と 1 バイトも同じ。`git diff --stat fbd1f7a 2e3ee75 -- …` が空）。この契約の書き手が 2026-11-24 に主な行をコードで読み直した（§14）。パスは断りが無ければ `Sources/TegakiCalendar/` からの相対、テストは `Tests/` の下。印: 【事実】はコードか記録で確かめた事、【推定】は事実から考えた事、【未確認】は確かめられなかった事、【計算】は数で出した事。決定の番号は **0f-1〜0f-38**（§12。1.4.1 の 0e-n の続き。0f-36〜0f-38 は第 2 版で足した）。

---

## 0. まとめ（本人向け）

### 0.1 1.4.2 ですること

11/7 の 2 つのご依頼（「ペンの色をもっと選択出来るようにする」「メモ欄、ドット方眼、無地も選択出来るようにする」）を、11/7 の夜のお答え「ほかは全部おすすめで」のとおりに作る版です。

**ペンの色**
- ツールバーの色の丸は、今と同じ 6 つのままです。最初の色も同じです（黒・青・赤・緑・オレンジ・紫）。
- **光っている丸（今のペンの色）をもう一度押すと（長押しでも）、その丸のそばに小さな「色の板」が出ます。**
  - 板の上には 12 色が並びます。今の 6 色と、新しい **茶・グレー・ピンク・水色・深緑・紺** です。色見本は紙と同じ白い色の上に並ぶので、書いたときと同じ見え方で選べます。
  - 「**その他の色…**」を押すと、iPad・iPhone に元からある色選びの画面が開き、どんな色でも選べます（画面の色を拾うスポイトもあります）。
  - 「**最初の色に戻す**」を押すと、6 つの丸が最初の 6 色に戻ります。
- 選ぶと、板を開いた丸がその色に替わり、ペンもその色になります。太さはそのままです。選んだ色がほかの丸にもうあるときは、その丸を選ぶだけです（同じ色の丸が 2 つにはなりません）。
- 替えた丸の色は、アプリを開き直しても覚えています。覚えるのは端末ごとです（iPad と iPhone で別々）。
- 消しゴムで消した後にペンへ戻るときも、Apple Pencil のダブルタップで戻るときも、選んだ色のまま戻ります。
- 板は、紙に書き始めたとき（**その線はちゃんと書けます**）、板の外に指や Pencil が触れたとき、色を選んだとき、ツールバーをしまったり動かしたりしたときに閉じます。
- ツールバーを上・左・右の端に置いたとき（左右では縦のツールバー）も、しまったツールバーを丸ボタンの道具の印で出したときも、同じように開きます。iPhone でも、ツールバーの上に小さな板が出ます。
- ダークモードで、黒や紺の丸がツールバーの背景に溶けて見えにくい所を直します（ダークのときだけ丸の縁を明るくします。ライトの見た目は 1 画素も変えません）。
- マーカーは今の 4 色のままです。

**メモ欄の紙**
- 設定の「祝日」のすぐ下に、**「メモ欄の紙」** を足します。押すと「**罫線**」「**ドット方眼**」「**無地**」から選ぶ画面になります（「週の始まり」と同じ形）。最初は今と同じ罫線です。
- 1 つの設定で、月のページの下のメモ欄、日のページの右の「メモ」、日と週のページの 24 時の下の「自由メモ」が、そろって変わります。横につながった週・日でも同じです。PDF も、その端末で選んだ柄で出ます。
- ドット方眼は、罫線があった高さに、横も同じ間隔で小さな点を並べます。罫線に合わせて書いた字は、点の列の上にそのまま乗ります。横につながったページの境目でも、点の間隔はそろいます。
- 無地では、線も点もありません。「メモ」「自由メモ」の字と、メモ欄の上の区切りの線は、どの柄でも残ります。
- **変わるのは紙の柄だけです。手書きは 1 本も動きません。** 罫線に戻せば、前と同じ見た目に戻ります。
- 設定は端末ごとです。購読していない（閲覧専用の）ときも選べます。

### 0.2 変わらないこと

- 書いた線の保存の形・iCloud の記録・書き出しの形は変えません。**今までの手書きは 1 本も動きません。** 前の版の端末とも今までどおり同期します。
- 新しい色で書いた線も、前の版の端末でその色で見えます（線は前から色をそのまま持っています。前の版のツールバーでは、その色を選べないだけです）。
- ツールバーの見た目（丸の数・最初の色・並び）は 1.4.1 と同じです（ダークモードの丸の縁だけ見やすくします）。紙・格子・予定の見た目も同じです（メモ欄の紙を替えたときだけ、その柄になります）。
- 1.4.1 の「‹ 今日 ›」・等倍・利き手・ツールバーを動かす は、そのままです。
- App Store の写真は撮り直しません（ツールバーと紙の見た目が変わらないため）。
- iOS 17 以上の iPad・iPhone で使えるのも同じです。データは集めません。広告もありません。値段も同じです。

### 0.3 順番と目安の日

- **月と年の横スクロールと「幅にちょうど」の等倍（11/22 のお言葉「月と年は、横スクロールができる仕様にしてから、幅が両端にくる等倍を適用します」）は、1.4.2 の次に回します（既定）。** 理由は 3 つです。
  1. 1.4.2 は 11/7 に中身が全部決まっていて、すぐ作り始められます。
  2. 小さく、手書きの保存の形を変えません。
  3. 月と年の横スクロールは、月と年を横につなげる版（1.7・1.8 の予定）と一緒に設計した方が、作り直しが少なくて済みます。月と年の版の番号と中身は、その版の約束で決めます。
  - 月と年を先にしたいときは「月と年を先に」と一言ください。
- 前の計画では 1.4.2 の時期は「2027 年 3 月末〜4 月上旬」でしたが、「進められる物は前倒し」（11/8）のとおり、年末の前（12/18 めど）の提出をねらいます。

| いつ（目安） | すること | 本人にお願いすること |
| --- | --- | --- |
| 11/24 | この約束（第 2 版）と、作る前の決めごとの記録 | このまとめを読む（返事は要りません） |
| 11/25〜11/26 | 自動の確かめの準備（版の番号・比べる元の写真） | なし |
| 11/26〜12/3 | メモ欄の紙と色の板を作り、自動の確かめを通す。わざと壊して確かめが落ちるかも見る | なし |
| 11/30〜12/5 | 新しい文の訳・サポートページ・新機能の文・審査メモ・写真 | なし |
| 12/1〜12/3 | 点の写真と 12 色の見本を、TestFlight より前に先にお見せする | 選ぶ（何も言わなければ (a)・この 12 色のまま） |
| 12/4〜12/8 | TestFlight 1.4.2（ビルド 32 以上）と確認ページ | 確かめ表（§10）、「この内容で入れてよい」 |
| 確かめ表が全部 ○ になった後 | 審査に提出（手動公開） | 「1.4.2 を審査に提出して良い」 |
| 審査が通った後 | 公開 → 本流にまとめる | 「1.4.2 を公開して良い」「まとめて良い」 |
| 12/12 | 確認ページが渡せていなければお知らせします | — |
| 12/18 | 年末の前の最後の提出日の目安（12/19〜1/4 は審査が遅れることがあるため【未確認】） | — |

- 自動の確かめは 1 回に 1 時間半ほどかかり、1 日に回せるのは数回です。直しが要れば、日が 1 日ほどずれます。進められる所は前倒しします。

### 0.4 本人にお願いすること（言葉と操作の一覧。ほかの節はここを指します）

- **確認ページ 1 回**: 色の板（下・上・左右・しまったとき・iPhone）、替えた丸、ダークのツールバー、メモ欄の 3 つの柄（月・日・週・横につながったページ・PDF）、設定の新しい行、新しい文（10 の言語）、新機能の文（16 の言語）、サポートページの変わる所（日本語・英語）、審査メモを、1 つのページで見せます。「**この内容で入れてよい**」の言葉をください。
- **写真を 2 つ、TestFlight より前（12/1〜12/3 ごろ）に先にお送りします**（11/7 の案でお約束した「見本の絵をお送りしてから決めます」のとおり。確認ページを待たずに選べるようにするためです）:
  - **ドット方眼の点の大きさと濃さ**（写真を見て 1 つだけ選べます。選ばなければ (a) のまま）。3 通りの写真（iPad Pro 13 と iPhone 18 Pro Max の、月のメモ欄と日のページ）をお見せします。
    - (a) 既定: 直径 2 pt・薄い茶がかった灰色。
    - (b) 直径 1.5 pt・(a) より少し濃い色（小さく、くっきり）。
    - (c) 直径 2.5 pt・区切りの線と同じ青みの灰色（大きく、淡い）。
    - 「(b)」のように一言ください。
  - **12 色の見本**（「紙の色の上に 12 色を並べた見本の絵」。実際の板の写真です）。青・水色・紺は近い色なので、替えたい色があれば「水色→黄土色」のように一言ください（ほかの候補: 黄土色・えんじ）。色を替えると、新しい色の名前の訳と確かめが要るので、日が数日のびます。
  - TestFlight のビルドを作り始める時までにお答えが無ければ、(a)・この 12 色のままで進めます。**確かめ表を始める前に言っていただければ、表は新しいビルドで 1 回で済みます。**
- **11/7 のお答え（§0.5）を変えたくなったら、いつでも一言ください**（作り直しになり、確かめ表のやり直す行は §9.4 でお知らせします）。
- **年齢区分の新しい問いが App Store Connect に出たときだけ、お聞きします**（答えは本人の言葉でいただきます。1.4.1 では新しい問いは 0 でした）。
- **TestFlight 1.4.2 の確かめ表**（§10）。**本人の端末でしか確かめられません。** iPhone Duo の行は「—」で構いません（Duo はお持ちでないので、自動の確かめだけで見ます）。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（無料。1.4.1 のときと同じです）。
- **言葉**: 「**この内容で入れてよい**」「**1.4.2 を審査に提出して良い**」「**1.4.2 を公開して良い**」「**まとめて良い**」（1.4.2 を本流にまとめること）。前もってまとめてもらっても構いません（1.2.4 の「三つともYes」と同じ）。**本人がご自分の端末で確かめていない版は出しません。** 審査で戻されてアプリを直したときは、前にもらった公開の言葉は使いません。

### 0.5 本人が決めなくてよいこと

- 色の板の作り方（吹き出しではなく、ツールバーのそばに重ねる板にします。紙に書き始めたときに最初の線が消えないようにするためです）、板を出す場所、閉じる決まり、6 つの丸の覚え方、壊れた記憶の直し方、「その他の色…」で選んだ色の直し方、読み上げ（VoiceOver）の言い方、メモ欄の紙を描く仕組み、点の並べ方、自動の確かめのやり方、訳の手順。どれも既定で決め、理由を §12 に書きました。
- 11/7 にお答えいただいたことは、そのとおりに作ります。もう一度お聞きすることはありません:
  - ペンの色: 丸は 6 つのまま、もう一度押すと 12 色と「その他の色…」の板。足す 6 色は茶・グレー・ピンク・水色・深緑・紺（見本を見て替えたいときだけ一言。§0.4）。マーカーは 4 色のまま。替えた丸の色は端末ごと。初めての人への画面の案内は無し。
  - メモ欄の紙: 罫線・ドット方眼・無地、全部のメモ欄に 1 つの設定、端末ごと。方眼は足さない。ドットの点は写真で選ぶ。

### 0.6 知っておいてほしいこと

- **「光っている丸をもう一度押す」は、画面に書いていない操作です。** 新機能の文とサポートページで知らせます（ほかの手書きアプリでも使われている操作です）。
- 板を開いたまま紙に書き始めると、板は閉じ、その線は書けます。指で画面のほかの所に触れたときも閉じ、触れた所のボタンなどはそのまま効きます。
- 替えた丸の色は端末ごとなので、iPad で茶にした丸は iPhone の丸には出ません。書いた線は、iCloud で色ごと iPhone に届きます。
- お手元の 4 台はどれも 1.4.2 になるので、「前の版の端末でも新しい色で見える」ことは、お手元では確かめられません。本物の 1.0 のコードで読む自動の確かめで見ます。
- 「その他の色…」で紙に近い薄い色を選ぶと、書いても見えにくくなります。止める仕組みは入れません（選んだ色を尊重します）。「最初の色に戻す」で戻せます。
- 読み上げ（VoiceOver）では、新しい色を「茶」「グレー」「深緑」「紺」と読みます。「その他の色…」で選んだ色は「その他の色」と読みます（2 つの丸に入れると、どちらも「その他の色」です）。光っている丸には「もう一度押すと、色を替えられます」と添えます。
- メモ欄の紙は端末ごとなので、iPad はドット方眼、iPhone は罫線、のように別々にできます。同じページでも端末で柄が違って見えますが、手書きは同じです。1.4.2 より前の版の端末では罫線のままです。
- 設定の「メモ欄の紙」の行は、11/7 の案のとおり「祝日」のすぐ下に出ます。
- Apple Pencil Pro の握る操作や、Pencil の設定の「カラーパレットを表示」では、色の板は開きません（今のままです。その部分は手書きの大事な所として凍結しているため）。
- Web 版（ブラウザで使う版）の色と紙は変えません（6 色・罫線のまま）。

---

## 1. 土台・決定・範囲

### 1.1 土台のコード

- 枝 `r142`。main の 2e3ee75（1.4.1 を `--no-ff` でまとめた commit）から切る。`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は **fbd1f7a（ビルド 31、1.4.1 の公開したビルド）と 1 バイトも違わない**【事実】（`git diff --stat fbd1f7a 2e3ee75 -- Sources TegakiKit Tests tools .github project.yml` が空。11/24 にこの契約の書き手が確かめた）。確かめた通しの run は **run #4 45074645599**（d416da8。コードは fbd1f7a と同じ。`docs/R1_4_1.md` の「P2〜P5」）。
- 1.4.1 は 11/24 06:55 JST に公開（READY_FOR_SALE）、Web main 1024223。main の CI の結果は記録に無い【未確認】（`docs/R1_4_1.md` の最後の行が「（…main の CI…）」のまま）。**S0 でリードが `gh run list` で 2e3ee75 の build.yml の run を探し、番号と結果を `docs/R1_4_2.md` に書く**（赤なら §9.1 の揺れの読み方で読み、本当の落ちなら D0 の前に止める）。
- 版は `MARKETING_VERSION "1.4.2"`（今は `project.yml:23` で "1.4.1"）。配る先は iOS 17.0 のまま（`project.yml:21`）、`TARGETED_DEVICE_FAMILY "1,2"`（`project.yml:22`）も変えない。ビルドの番号は testflight.yml の run 番号（`testflight.yml:295`）で、1.4.1 が 29〜31 を使ったので **32 以上**（0f-1）。
- この Mac には Xcode もシミュレータも無い（Command Line Tools だけ）。TegakiKit は `swift build` と KitChecks、アプリは `tools/typecheck/typecheck.sh [work-dir]`（Mac Catalyst。`TYPECHECK_DEFINES=DEBUG` で `#if DEBUG` も見る。`typecheck.sh:8-31`）まで。**iOS の本当のビルド・単体テスト・UI テスト・写真は GitHub Actions の CI だけ**。作る人は commit の前に typecheck を DEBUG あり・なしの 2 回通す。Xcode 27.2（27B52）・XcodeGen 2.46.0 は 1.4.1 と同じで、道具は替えない。

### 1.2 本人の依頼と決定（確定。再検討しない）

**本人の言葉（2026-11-07、そのまま）**:
1. 「てがきカレンダー、ペンの色をもっと選択出来るようにする。」
2. 「てがきカレンダー、メモ欄、ドット方眼、無地も選択出来るようにする。」

**本人の答え（2026-11-07 夜）**: 「ほかは全部おすすめで」（`docs/PLAN_PEN_COLORS.md:7`、`docs/PLAN_MEMO_PAPER.md:7`）。中身は §0.5 のとおり。**この契約での読み方**: 計画の §1〜§4（本人が読んだ所）が約束。§5（作る側の控え）は案で、この契約で直す（§3・§4 の各節に、計画と違えた所と理由を書く）。

**後から足された決まり**:
- 版の番号は 1.4.2（2026-11-21、R1_4_1_CONTRACT §0.6・`docs/M7_PLAN.md` §4）。
- 色の板は、1.4.1 の左右の端の縦のツールバーからも開けるようにする（R1_4_1_CONTRACT §1.4、`docs/M7_PLAN.md` §4 の 1.4.2 の行）。
- 1.4.1 の確かめ表で、しまったツールバーから出したバー（のぞき）にだけ部品が無くて本人が見つけられなかったことがある（R1_4_1_CONTRACT §18.1）。だから、のぞきのバーからも板を開けるようにする（`docs/PLAN_PEN_COLORS.md:178` の実機の確かめにもある）。
- 「次の版」（月と年の横スクロールと幅の等倍）と 1.4.2 の順は、1.4.2 の契約で決める（`docs/M7_PLAN.md` §4 の「次の版」の行）。→ 0f-2。

**前からの決まり（R1_4_1_CONTRACT §1.2・§9.4 と同じ）**:
- 進め方: 「予定に拘らず進める」（11/13）、「どんどん進めて」（11/20）、進められる物は前倒し（11/8）。途中で許可を取らず、既定で決めて記録し、最後にまとめて報告する。
- 本人の言葉が要るのは、確認ページ・提出・公開・main へまとめる の 4 つと、実機の確かめだけ（§0.4）。
- **本人が自分の端末で確かめていない版は出さない**。Duo の行は「—」。
- Web 版は変えない（ほかの Pages は出さない約束）。公開の日に出すのは SUPPORT の 2 ページだけ。

### 1.3 範囲

| # | 何をする | 決定 | 役 | 段 |
| --- | --- | --- | --- | --- |
| 1 | 版 1.4.2、CI の枝の配線（`r142*`）、J-4 の基準を fbd1f7a に、1.4.1 のテストの守りの表 | 0f-1・0f-27〜0f-29 | C | D0 |
| 2 | メモ欄の紙: 型と鍵、設定の行、紙への届け方（つないだ紙も）、ドット・無地の描き方、写真モード | 0f-19〜0f-23 | M・S | D1a |
| 3 | 12 色の表・6 つの丸の記憶・入口の関門と名前 | 0f-6〜0f-8 | T | D1b |
| 4 | 色の板: 開き方・板・閉じ方・選ぶ・「その他の色…」・「最初の色に戻す」・置き場所（縦のバー・のぞき・iPhone）・VoiceOver・写真モード | 0f-9〜0f-15・0f-17・0f-18 | T・S | D1b |
| 5 | ダークの縁 | 0f-16 | T | D1b |
| 6 | 互換の確かめ（1.0 のコードで色の線を読む） | 0f-24 | C | D1b |
| 7 | テスト・変異・Duo の確かめ | §6、0f-28 | 各役・C・U | D1a〜D1c |
| 8 | 13 の新しい文と訳・逆翻訳、0e-32 の訳者向けの説明、SUPPORT、新機能の文、審査メモ、文書 | 0f-25・0f-26・0f-32 | X・R・A・W・リード | D2 |
| 9 | 写真（J-4・新しい写真・ダークの写真・本人の選びの 1 組・12 色の見本） | 0f-29〜0f-31 | C・U・リード | D1〜D2 |

### 1.4 範囲外（1.4.2 ではしない。0f-5）

- 月と年の横スクロールと幅の等倍（「次の版」。0f-2）。
- マーカーの色を増やすこと（本人の 11/7 の既定。§0.4 で言葉の選び）。
- 替えた丸の色を iCloud でそろえること（同じ）。
- 初めての人への画面の案内（同じ）。
- メモ欄の紙をページごとに分けること、方眼（線のマス目）（同じ）。
- 投げなわで選んだ線の色を替えること（新しい id の写しと墓標が要り、凍結の `InkLedger.swift` に触れる。`docs/PLAN_PEN_COLORS.md` §5.1）。
- Apple Pencil の「カラーパレットを表示」・Pencil Pro の握る操作から板を出すこと（`Ink/PencilInteraction.swift:24-34` は何もせずに捨てている。このファイルは凍結の 8 行目）。
- Web 版の色と紙（`tegaki-calendar` の `js/ink/render.js:36-37` の 6 色のまま）。
- 年のページ・週と日の時間の格子（`Paper/TimeGridPaper.swift`）の紙。
- App Store の写真の撮り直し（0f-33）。
- ⌘0 などのショートカット、中国の 2027 年の祝日（M7D 0d-26）、CRA の見直し（§1.5）。

### 1.5 1.4.1 から送られたもの（0f-32）

| 残り（元） | 1.4.2 で | 役 | 確かめ |
| --- | --- | --- | --- |
| **0e-32 訳者向けの説明**（`tools/l10n/source/app-S.json` の `toolbar.grip.spoken`（:2903）・`toolbar.moveTo.*`（:3036-3075）の comment が「読み上げ」のまま。実際は「動かす」の吹き出しの題と選択肢として画面に出る。R1_4_1_CONTRACT §18.8） | **直す**（comment だけ。ja の字と jaSha1 は同じなので訳し直さない。`Localizable.xcstrings` の comment が替わるので、D2 の確かめた run より前の commit で） | X | `build.py --check`・`lint.py`・Localized bundle check |
| `tools/shots/ink_ref_xcui.tsv` から見出しの帯のタイルを除く（`docs/R1_4_1.md:292`） | **直す**（D0 の後、D1 の最初の通しの run の前）。理由と除いた行を記録に | C | ink_check が緑 |
| UI テストの `settledProbe` の待ち方（期限の後にもう 1 回読む・回数で数える。`docs/R1_4_1.md:463`） | 新しい UI テストはこの形で書く。今のテストは、揺れで同じテストが 2 回落ちたときだけ直す | U | — |
| 指でも書くとき、つまみを持ったまま書き始めるとツールバーが動く（`docs/R1_4_1.md:219`） | 記録だけ（1.4.2 では直さない） | — | — |
| `SpanGuard` の `.prototype`（凍結の 19 行目） | 残す（R1_4_1_CONTRACT §1.5） | — | — |
| ⌘0（R1_4_1_CONTRACT §1.4） | 範囲外。候補として記録 | — | — |
| 中国の 2027 年の祝日（M7D_CONTRACT §9.6・0d-26） | 範囲外。python-holidays の正式版に入ったら、その時の版で扱う（S0 で入ったかを見て記録だけ） | リード | — |
| CRA の見直し（`docs/M7_PLAN.md` §4「2027 年 12 月より前の版の契約で」） | 1.4.2 では記録だけ（データの扱いを変えない小さな版）。次の機能の版（1.5）の契約で扱う | リード | — |

---

## 2. 構成とファイル所有

1 つのファイルの持ち主は 1 つの役。commit は `git add <ファイル名>` で、持ち主のファイルだけを入れる。役の表は §9.3。

```
project.yml                                         C  MARKETING_VERSION "1.4.2"（だけ）
.github/workflows/build.yml                         C  r142 の配線（§6.5）、速い道の正規表現、TESTS_1_4_1 の段、ui-tests の grep、
                                                       新しい写真の段とその数の行、ダークの写真
.github/workflows/ja-baseline.yml                   C  基準のファイルを 1.4.2 に（:124 の FILE=）
.github/workflows/duo.yml                           C  枝 r142-duo* でも走る（:38-41）
tools/l10n/ja-baseline-ref-1.4.2.txt                C  新しい。fbd1f7ab82860d00599a43a8768eaa162611b768 の 1 行
tools/span/TESTS_1_4_1.sha256                       C  新しい（0f-28。§5.5）
tools/shots/ink_ref_xcui.tsv                        C  見出しの帯のタイルを除く（§1.5）
TegakiKit/Tests/Compat10/Checks/Compat10Checks.swift  C  色の線の確かめ（§5.3。ハッシュで凍結されていない）
Sources/TegakiCalendar/Views/ToolbarView.swift      T  ToolbarPalette.panelColors・penSlotsKey、丸の id と identifier、光っている丸の動き・長押し・
                                                       VoiceOver、ダークの縁（横と縦の 2 か所）、colorPanel の引数（既定 nil）、丸の @AppStorage
Sources/TegakiCalendar/Views/ToolbarLogic.swift     T  slots(stored:)・storedSlots・pen(…slots:)・rememberedPen・colorName、ColorPanelLogic（純粋）
Sources/TegakiCalendar/Views/ColorPanelView.swift   T  新しい。板・ColorPanelAnchorKey・ColorPanelWatch・ColorPickerSheet
Sources/TegakiCalendar/Views/CalendarRootScreen.swift  S  板の状態・重ね・閉じる所・色選びのシート・sheetIsUp・写真モードの口・MemoPaperStyle の起動
Sources/TegakiCalendar/Views/SettingsScreen.swift   S  inputSections の最初に MemoPaperSettingsSection（1 行）
Sources/TegakiCalendar/Views/MemoPaperSettingsSection.swift  S  新しい
Sources/TegakiCalendar/Persistence/AppSettings.swift  S  memoPaperKey、注（penSlots は toolbar の側、0-13 と同じ）
Sources/TegakiCalendar/Support/ScreenshotMode.swift S  Config.colorPanel・penSlots・memoPaper（既定は nil・false）
Sources/TegakiCalendar/Paper/MemoPaperStyle.swift   M  新しい。enum・current・prepareAtLaunch・set・知らせ
Sources/TegakiCalendar/Paper/PaperView.swift        M  memoPaper の性質と知らせの受け、PaperPalette.memoDot
Sources/TegakiCalendar/Paper/MonthPaper.swift・DayPaper.swift・FreeMemoPaper.swift  M  柄の分かれ（罫線の道は今の字のまま）
Sources/TegakiCalendar/Paper/WeekPaper.swift        M  注だけ（:7-11 の「罫線だけ」）
Sources/TegakiCalendar/Paper/PaperText.swift        M  点を画素にそろえる口（要れば）
tools/l10n/source/app-S.json・app-U.json             X  13 の新しいキー（§8.1）と 0e-32 の comment
tools/l10n/translations/*.json（9）                  X  訳
Sources/TegakiCalendar/Resources/Localizable.xcstrings  X  build.py が作り直す（同じ commit）
docs/i18n/GLOSSARY.md                               X  色の名前 4 つ・メモ欄の紙・罫線・ドット方眼・無地・板のボタン
docs/i18n/REVIEW.md・docs/i18n/back/*.json           R  REVIEW の節 17 と、元を見ない逆翻訳
Tests/TegakiCalendarTests/（新しい 10）               各役  §6.1
Tests/TegakiCalendarUITests/（新しい 3・足す 3）       U  §6.1・§6.2
Tests/TegakiCalendarTests/ToolbarLogicTests.swift・AppSettingsTests.swift・SettingsScreenTests.swift  T・S  足すだけ（§6.2）
docs/store/*/whatsnew.txt（12 のロケールのフォルダと source-ja）・review-note.txt・README.md の表の行・PROPOSALS_1_4_2.md  A  §8.3・§8.4
docs/SUPPORT.md・SUPPORT.en.md                      W  §8.5
docs/R1_4_2.md・docs/M7_PLAN.md・docs/DESIGN.md・README.md・PLAN_PEN_COLORS.md・PLAN_MEMO_PAPER.md の頭の注  リード  記録・§8.6
```

- **変えないもの**: 凍結の表 `tools/compat10/DATA_1_1.sha256` の 20 行全部（§5.4。1.4.2 は 1 行も作り直さない）、`tools/span/TESTS_1_3.sha256`（29 行）・`TESTS_1_2_3.sha256`（8 行）・`FIXTURES_1_3.sha256`（37 行）、`tools/l10n/lint-skip.txt` の 20 件、`tools/duo/idiom-allow.txt`、TegakiKit の `Sources` 全部（KitChecks 40,826 は同じ）、compat10・compat11・compat-span の fixture と `EXPECTED_MIN`（225）、`tools/l10n/ja-baseline.tsv`（J-1。0f-25）、`ja-baseline-ref.txt`・`-1.3.txt`・`-1.4.txt`・`-1.4.1.txt`（記録として残す）、`Export/PDFPageRenderer.swift`（変えずに済む見込み。変えるなら M）、`Span/*`・`Paper/PaperSpan.swift`・TegakiKit の Layout（紙の柄はレイアウトに入れない。0f-21）。
- **画面の字で守られた所**（ピン留めのテストがソースの字を読む。§5.6）は、平らにした形で 1 字も変えない。`ToolbarView(` の呼び出しに足す引数 `colorPanel:` は、**`axis:` の前**に足す（守られた字 `axis: axis, move: paletteMoveButton )`、`PaletteMoveButtonTests.swift:537`、を保つため。§2.1・0f-36）。
- **役 L（台帳）と Y（同期）は作らない**。保存・merge・同期・墓標・台帳の行に触れる直しが要ると分かったら止めて、契約を直す。

### 2.1 接点（宣言。新しい引数には既定値を付け、省けば 1.4.1 と同じ動き）

```swift
// Views/ToolbarView.swift の enum ToolbarPalette（役 T）
//   penColors（:596-603、6 色）・markerColors（:605-610）・defaultPen（:623-625）は変えない。
static let penSlotsKey = "toolbar.penSlots"   // String。6 つの "#rrggbb" を "," でつなぐ。端末ごと（UserDefaults、CA92.1）
/// 板の 12 色。penColors の 6 色が先、次に足す 6 色（§3.1）。名前は今と同じく static の初期化で 1 回 L.text。
static let panelColors: [Entry]

// Views/ToolbarLogic.swift（役 T）
extension ToolbarPalette {
    static var defaultSlots: [String] { penColors.map(\.hex) }
    /// 保存の字から 6 つの丸（§3.2 の規則）。いつも 6 つで、重複が無い。
    static func slots(stored: String?) -> [String]
    static func storedSlots(_ slots: [String]) -> String
    /// 今の pen(colorHex:width:)（ToolbarLogic.swift:640-648）に slots を足す。丸に無い色は slots[0]。
    static func pen(colorHex: String?, width: Double?, slots: [String] = defaultSlots) -> InkStyle
    /// 今の rememberedPen（:634-637）。penSlotsKey も読む。CalendarRootScreen.swift:527 の呼び出しは変えない。
    static func rememberedPen(_ defaults: UserDefaults) -> InkStyle
    /// panelColors → markerColors → 「その他の色」（今の :651-658 の表を panelColors に）。
    static func colorName(_ hex: String) -> String
}
enum ColorPanelLogic {
    enum SwatchAction: Equatable { case select(Int), open(Int), close, none }
    /// ペンの丸の押し（§3.5 の表）。lit は光っている丸の添字、openSlot は開いている板の丸。
    static func tap(slot: Int, lit: Int?, openSlot: Int?) -> SwatchAction
    static func longPress(slot: Int, lit: Int?, openSlot: Int?) -> SwatchAction
    struct Choice: Equatable { var slots: [String]; var pen: String }
    /// 板で色を選んだ（§3.7。ほかの丸にあれば丸は変えずにその色を選ぶ）。
    static func choose(_ hex: String, slot: Int, slots: [String]) -> Choice
    /// 「最初の色に戻す」（§3.7。今のペンが丸 k にあれば、ペンは既定の k 番目）。
    static func reset(currentPen: String, slots: [String]) -> Choice
    /// 板を出す枠（§3.8）。anchor は光っている丸の枠、container は画面の安全な領域（どちらも同じ座標）。
    static func placement(anchor: CGRect, edge: PaletteEdge, container: CGRect, panel: CGSize) -> CGRect
    /// 触れが板を閉じるか（§3.6）。板の中と光っている丸の上は閉じない。
    static func closesOnTouch(at point: CGPoint, panel: CGRect, litSwatch: CGRect?) -> Bool
    /// 光っている丸が動いたら閉じるか（§3.6）。開いたときの枠と今の枠が、どれかの辺で 1 pt より違えば true。
    static func closesOnAnchorMove(opened: CGRect, now: CGRect) -> Bool
    /// 色選びの知らせを決めるか（§3.7）: continuously が true の間は決めない。
    static func commitsPick(continuously: Bool) -> Bool
    /// 丸の縁（§3.9）: ライトは (white: false, opacity: 0.15)、ダークは (white: true, opacity: 0.35)。
    static func swatchRim(dark: Bool) -> (white: Bool, opacity: Double)
}

// Views/ToolbarView.swift（役 T）
//   `var colorPanel: ColorPanelHook? = nil` を `eraserReturnsTo`（:51）と `axis`（:53）の間に宣言する（nil は 1.4.1 の動き:
//   光っている丸を押しても何も起きない）。memberwise init は宣言の順なので、呼び出しでも `axis:` の前に来る。最後に足すと、
//   守られた字 `axis: axis, move: paletteMoveButton )`（`PaletteMoveButtonTests.swift:537`。TESTS_1_4_1 に入る）が消えて落ちる（0f-36）。
//   この引数を渡さない `ToolbarFitTests.swift:178`・:181 と `PaletteMoveButtonTests.swift:624` はそのまま通る。
struct ColorPanelHook {
    var openSlot: Binding<Int?>        // 開いている板の丸（nil は閉じている）
}
//   ペンの丸の ForEach は添字を id に（横 :248、縦 :460。マーカーの :257・:469 は表が固定なので今のまま）。
//   ペンの丸に identifier "toolbar.swatch.<0…5>"（横と縦で同じ）。光っている丸は .anchorPreference(key: ColorPanelAnchorKey.self, value: .bounds)。
//   @AppStorage(ToolbarPalette.penSlotsKey) を持つ（写真モードでは保存に触れない形。§3.11）。

// Views/ColorPanelView.swift（役 T、新しい）
struct ColorPanelAnchorKey: PreferenceKey { /* Anchor<CGRect>? */ }
struct ColorPanelView: View {           // 板（§3.4）。@AppStorage で penSlotsKey と penColorKey を ToolbarView と同じ形で持つ
    var slot: Int
    var tool: Binding<CanvasTool>       // 画面の toolBinding（CalendarRootScreen.swift:2735-2750）
    var onClose: () -> Void
    var onOther: () -> Void             // 「その他の色…」: 画面がシートを出す
}
@MainActor final class ColorPanelWatch { // 凍結の InkTouchObserver の新しいインスタンスを窓に（§3.6。PalmWatch と同じ形）
    func attach(to window: UIWindow); func detach()
    var panelFrame: CGRect; var litSwatchFrame: CGRect?   // 窓の座標。開くときに placement の結果を同じ番に入れる（.zero のままにしない）
    var onOutsideTouch: () -> Void
    /// テストの口。UIKit の道では観測者の onChange から `observer.location(in: window)` を渡して呼ぶ。
    func touched(_ change: InkTouchObserver.Change, at point: CGPoint)
}
struct ColorPickerSheet: UIViewControllerRepresentable { // UIColorPickerViewController（§3.7）
    var initialHex: String
    var onPick: (String) -> Void       // InkColors.hex(of:) で sRGB の "#rrggbb" にした字（continuously == false のとき）
    var onDone: () -> Void             // Coordinator の colorPickerViewControllerDidFinish で必ず呼ぶ（× で閉じたときも）
}

// Views/CalendarRootScreen.swift（役 S）
//   @State private var colorPanelSlot: Int? = nil、@State private var colorPickerShown = false、
//   @State private var colorPickerSlot: Int? = nil（色選びで決めた色を入れる丸）、
//   @State private var colorPanelWatch = ColorPanelWatch()（`let` にしない。View の struct が作り直されるたびに別のインスタンスになり、
//   窓に付いた観測者を古いインスタンスが持ったままになる。前例 `@State private var palmWatch = PalmWatch()`、:252）。
//   toolbar(axis:)（:1128-1143）の ToolbarView( で、`eraserReturnsTo:` の後・`axis:` の前に `colorPanel: ColorPanelHook(openSlot: $colorPanelSlot),`。
//   平らにした呼び出しの終わりは `colorPanel: ColorPanelHook(openSlot: $colorPanelSlot), axis: axis, move: paletteMoveButton )` になる（0f-36）。
//   画面のいちばん外の重ねで .overlayPreferenceValue(ColorPanelAnchorKey.self) から ColorPanelView を出す（§3.4・§3.8）。重ねの入れ物は
//   `.allowsHitTesting(false)` にし、板そのものだけが触れを受ける（前例 PaletteDragLayer、:3823）。新しい .sheet・重ね・閉じる .onChange は
//   新しい関数（例 `colorPanelLayer(_:)`）にまとめる（`presented`・`watched` の鎖は型の確かめのため 3 つに分けてある、:768-770）。
//   板の開け閉めで ColorPanelWatch を付け外しする: `.onChange(of: colorPanelSlot)` で、開いたら `paletteRoom.window`（:3707-3710）に attach、閉じたら detach。
//   penDown()（:1192-1210）には何も足さない（Pencil のホバーでも呼ばれるため。§3.6）。
//   sheetIsUp（:731-734）の最後に `|| colorPickerShown`（`|| ageRangeAsking` の後。SpanGuideSeenSpanTests:276-278 を守る）。
//   .sheet(isPresented: $colorPickerShown, onDismiss:) で ColorPickerSheet。onDismiss と onDone で colorPickerShown = false・colorPickerSlot = nil（§3.7）。
//   板を閉じる処理は新しく足す別の .onChange だけ（§3.6 の一覧。sheetIsUp もその 1 つ）。`toolbarEvent`・`placePalette`・`paletteMoveChosen`・
//   `paletteMoveButtonChose`・`sheetsChanged()`（:2571-2590）の本体には書かない（§5.6）。
//   init で MemoPaperStyle.prepareAtLaunch(shot:)（WeekStartChoice.prepareAtLaunch :491 の近く）。

// Paper/MemoPaperStyle.swift（役 M、新しい）
enum MemoPaperStyle: String, CaseIterable, Sendable {
    case ruled, dots, plain
    init(stored raw: String?)          // nil・知らない字 → .ruled
    @MainActor static var current: MemoPaperStyle   // 既定 .ruled
    /// 単体テストの中では SyncEngine.isTestHost がいつも真なので、testHost: false で保存した値の枝を試せるようにする（§4.1）。
    @MainActor static func prepareAtLaunch(shot: ScreenshotMode.Config?, _ defaults: UserDefaults = AppSettings.defaults,
                                           testHost: Bool = SyncEngine.isTestHost)
    @MainActor static func set(_ style: MemoPaperStyle)   // 違えば current を替えて didChange を出す
    static let didChange: Notification.Name
}

// Paper/PaperView.swift（役 M）
//   `var memoPaper: MemoPaperStyle`（didSet で違えば setNeedsDisplay）。init(content:zoomScale:)（:207-）の形は変えず、
//   中で MemoPaperStyle.current を入れ、didChange を受ける。init では setNeedsDisplay を呼ばない。
//   `static let memoDot`（PaperPalette、:70-83 の並び）。

// Persistence/AppSettings.swift（役 S）
//   static let memoPaperKey = "paper.memoStyle"   // String。端末ごと、iCloud に送らない、isExistingUser の鍵ではない

// Support/ScreenshotMode.swift（役 S）。Config に既定値つきで足す（:268-296 の形。今までの引数の Config は同じ値）。
//   var colorPanel: Bool = false          // --screenshot-color-panel
//   var penSlots: [String]? = nil         // --screenshot-pen-slots <6 つの hex をカンマで>（読めなければ nil）
//   var memoPaper: MemoPaperStyle? = nil  // --screenshot-memo-paper ruled|dots|plain（知らない値は nil = 罫線）
```

---

## 3. ペンの色

### 3.1 12 色の表（0f-6）

- `ToolbarPalette.penColors`（`Views/ToolbarView.swift:596-603`）は**変えない**【事実: 黒 #1f2937・青 #2563eb・赤 #dc2626・緑 #16a34a・オレンジ #ea580c・紫 #7c3aed】。最初の 6 つの丸、`defaultPen`（:623-625）、`ToolbarFitTests` の 6 つの丸の式（`ToolbarFitTests.swift:67`）と縦の列の 843 pt（:161-166）の前提はそのまま。
- 新しい `ToolbarPalette.panelColors`（12）: `penColors` の 6 色、次に:

  | 名前 | キー | hex | 紙 #fffdf8 とのコントラスト【計算】 |
  | --- | --- | --- | --- |
  | 茶 | `toolbar.color.brown`（新しい） | `#92400e` | 7.0 |
  | グレー | `toolbar.color.gray`（新しい） | `#6b7280` | 4.8 |
  | ピンク | `toolbar.color.pink`（今のマーカーの名前を使う） | `#db2777` | 4.5 |
  | 水色 | `toolbar.color.lightBlue`（今のマーカーの名前を使う） | `#0284c7` | 4.0 |
  | 深緑 | `toolbar.color.darkGreen`（新しい） | `#166534` | 7.0 |
  | 紺 | `toolbar.color.navy`（新しい） | `#1e40af` | 8.6 |

  どれも線の目安 3:1 を超える。色どうしでは、水色と青が 1.26、紺と青が 1.69 で近い【計算】ので、本人に見本の写真で見せる（0f-31）。
- 凍結の `InkPresets.penColors`・`markerColors`（`Ink/InkTools.swift:49-50`）は読まない・変えない。ツールバーは今も読んでいない【事実】。
- 理由: 丸を行に足すと、11 インチで ↷、mini で「太」が押し出される（`docs/PLAN_PEN_COLORS.md` §5.1 の幅の計算）。板なら行は 1.4.1 と同じ。

### 3.2 6 つの丸の記憶（0f-7）

- 鍵 `toolbar.penSlots`（`ToolbarPalette.penSlotsKey`）。**String**（6 つの "#rrggbb" を "," でつなぐ）。`@AppStorage` は配列を持てないので、`toolbar.penColor` と同じ形で変わったことを受け取れる String にする。端末ごと（UserDefaults。`PrivacyInfo.xcprivacy:15-18` の CA92.1 で申告済み）。iCloud・書き出し・PDF に入れない。鍵が無いときは最初の 6 色。**書くのは、板で丸の色を替えたときと戻したときだけ**。
- 読み方 `slots(stored:)`:
  1. nil・空 → 最初の 6 色。
  2. "," で分けて 6 つでない → 最初の 6 色。
  3. i 番目を `InkColors.normalized`（凍結の `InkTools.swift` の中。#rgb と #rrggbb を小文字の #rrggbb に）で直す。直せない → 最初の色の i 番目。
  4. 前の丸と同じ色になる → 最初の色の i 番目。それも前の丸にあれば、`panelColors` の並びで前の丸に無い最初の色。
  - だから、いつも 6 つで重複が無い。壊れた字を読んでも書き戻さない（次に板で替えたときに正しい字になる）。
- `toolbar.penColor`（今のペンの色、`ToolbarView.swift:57`）は今のまま。光る丸は、ペンの色と同じ色の丸（重複が無いので 1 つ）。
- 丸の `ForEach` の id は添字にする（今は `id: \.hex`、横 :248・縦 :460。重複や壊れた字で id がぶつかるのを根から無くす）。マーカーの :257・:469 は表が固定なので今のまま。
- `AppSettings.swift:52-53` の注（ペンの鍵はツールバーの側）に `toolbar.penSlots` を足す。`AppSettingsTests.testToolbarKeys`（:157-163）の「鍵が全部別」の一覧に足す。
- 計画との違い: 計画 §5.2 は「6 個でない → 今の 6 色、1 個ずつ正規化」とだけ書く。重複の直し方を足した。

### 3.3 入口の関門と名前（0f-8）

- `ToolbarPalette.pen(colorHex:width:)`（`ToolbarLogic.swift:640-648`）は今、`penColors` に無い色を黒に戻す【事実】。これが**中心の変更**: `pen(colorHex:width:slots:)` にして、丸の色で調べる。丸に無い色は `slots[0]`（丸が最初の色なら黒で、今と同じ）。太さの規則は同じ。`slots` の既定値は最初の 6 色なので、今の呼び出しとテストはそのまま通る。
- 通る所は全部直す: `rememberedPen`（:634-637。`penSlotsKey` も読む。呼ぶ所 `CalendarRootScreen.swift:527` → `startState` は変えない）と、`ToolbarView.penStyle`（:68-70。「ペン」ボタン :218・:441 と丸の動作が使う）。`markerStyle`（:72-74）は表で調べていないので変えない。
- 最後のインク `lastInkTool`（`CalendarRootScreen.swift:195`）は、`tool` の onChange（:862-864）でインクの道具になるたびに替わり、色ごと持つ【事実】。だから消しゴムの後の戻り（:1217-1222 の `eraseEnded`）・Pencil の切り替え（:2095-2102）・閲覧専用（:2724-2729）は、どの色にも戻れる。直さない。
- `ToolbarPalette.colorName`（`ToolbarLogic.swift:651-658`）: `panelColors` → `markerColors` → `toolbar.color.unknown`「その他の色」。丸ボタンの値（「ペン・茶・中」など）も同じ関数なので、そのまま新しい名前になる。
- 読み替えるテスト（守られていない）: `ToolbarLogicTests.testRememberedPen`（:266-317）の「#123456 → 黒」は「丸に無い色 → 丸 1」の意味（丸が最初の色なら字はそのまま通る）。凍結の `CalendarRootScreenTests.swift:405-425` は `penColor` だけで、丸の鍵が無いので結果は同じ。

### 3.4 板（0f-10）

- 新しい `Views/ColorPanelView.swift`（T）。**吹き出し（SwiftUI の `.popover`）にしない。** 画面のいちばん上の重ね（のぞき・つまみを動かしている間の丸い印・トーストより上、シートより下）に、自前の板を描く。
- 理由（4 つ）:
  1. 吹き出しは、外に触れると閉じ、その触れを下へ渡さない【推定。UIKit の吹き出しの暗い幕の形】。板を開いたまま Pencil で書き始めると、最初の線が書けない。1.1 からののぞき（書き始めると閉じ、その線は書ける）と同じ形にしたい。
  2. 今の UI テストは、すでに光っている丸を押すことがある（`EraserAndBelowDayUITests.swift:651` の `restoreDefaultPen` が「黒」を押す）。吹き出しだと次の「太さ: 中」の押しが閉じるのに取られ、テストが落ちる。重ねた板なら、外の押しを閉じるのに取られない見込み【推定】。ただし板は `.isModal`（§3.10）なので、開いている間は板の外の要素が XCUITest の検索から消えうる【推定】。だから UI テストは板を閉じてから次を押し、丸は identifier で探す（§6.1・§6.2）。
  3. 吹き出しの中から色選びの画面を出すと、閉じたり重なったりしうる【未確認】（`docs/PLAN_PEN_COLORS.md` §5.3）。また、吹き出しは画面の「出している物」に数えられ、アカウントの問いなどのシートとぶつかる。重ねた板はぶつからない。
  4. `.popover(arrowEdge:)` は iOS 17 では向きを無視すると覚えている【未確認】。左右の縦のバーで丸の横に出す保証が無い。
- 形（T が決めて `docs/R1_4_2.md` に書く。下は目安）:
  - ツールバーと同じ素材の角丸の板。幅は 288 pt 前後（どの iPhone の幅 375 にも、外に 8 pt ずつ残して入る）。
  - 上に 12 色の格子（6 × 2、マスは 44 × 44、丸は 28 pt、縁は `Color.black.opacity(0.15)`）。格子は紙の色 #fffdf8 の角丸の面の上に置く（ダークでも白。書いたときと同じ見え方。計画 §2）。今のペンの色の丸に、ツールバーと同じアクセントの輪（2.5）。
  - 下に「その他の色…」と「最初の色に戻す」の 2 行（どちらも高さ 44）。字は 1 行、縮みは 0.8 まで。入らない言語は 2 行（高さ 44 に入る大きさ）。どちらにも入らなければ止めて契約を直す。Dynamic Type は xLarge まで（ツールバーの説明の行 `ToolbarView.swift:281-286` と同じ）。
- 板の場所は、光っている丸の枠から純粋な関数で決める（§3.8）。丸の枠は `.anchorPreference`（新しい `ColorPanelAnchorKey`）で画面へ渡し、画面の `.overlayPreferenceValue` が受ける（ツールバーの `ScrollView` の切り抜きの外に出すため）。重ねの入れ物（`GeometryReader` など）は `.allowsHitTesting(false)` にし、板そのものだけが触れを受ける（入れ物が触れを取ると、画面全体の入力が止まる。前例 `PaletteDragLayer`、`CalendarRootScreen.swift:3823`）。下のバーは `.safeAreaInset` の中身（:834-846）にあるので、その中の anchor が外の `.overlayPreferenceValue` まで届くかは【未確認】（§13.1 の 1）。D1b の最初の通しの run で、iPhone の `ColorPanelUITests`（下のバーで板が出る）がこれを見る（UI テストは速い道では走らない、`build.yml:1701`）。Sources にはまだ PreferenceKey の前例が無い【事実】。1.4.1 が見出しの高さで PreferenceKey を避けた理由（レイアウトのくり返し、R1_4_1_CONTRACT 0e-4）は、紙の大きさを変えない重ねには当たらない。
- **板は紙の領域・倍率・`toolbar: paperArea=` の値を変えない**（関門 3 で示す。§7.2）。

### 3.5 開き方（0f-9）

純粋な表 `ColorPanelLogic.tap(slot:lit:openSlot:)` と `longPress(...)`（ペンの丸だけ）:

| 押した丸 | 板 | 押し | 結果 |
| --- | --- | --- | --- |
| 光っている丸 | 閉じている | 押す | その丸の板を開く（ペンは変えない） |
| 光っている丸 | 開いている | 押す | 閉じる |
| 光っている丸 | 閉じている | 長押し（0.5 秒） | 開く（指を離した後の押しで閉じない） |
| 光っていない丸 | どちらでも | 押す | 今と同じく、その丸を選ぶ（開いていれば閉じる） |
| 光っていない丸 | どちらでも | 長押し | 押すのと同じ（選ぶだけ） |

- 指・Pencil・ポインタのどれでも同じ（丸はふつうの SwiftUI のボタン。PalmWatch は使わない）。
- VoiceOver: ペンの 6 つの丸に操作「ペンの色を選ぶ」（その丸を選んで板を開く）。光っている丸に読み上げのヒント「もう一度押すと、色を替えられます」。
- マーカー・消しゴム・投げなわ・予定では開かない（マーカーの丸は今と同じ。消しゴムなどは丸を出さない。`ToolbarView.swift:243-271`・:455-479）。
- 閲覧専用でも開ける（丸の色は端末の設定で、手書きではない。害が無い）。
- 計画との違い: 計画 §2（本人が読んだ所）は「選んでいる丸をもう一度押す（または長押しする）」、§5.2 は「どの丸でも長押し」。**§2 のとおり、光っている丸の長押しだけ**にした。どの丸でも長押しにすると、下のバーに手のひらを置いたまま書いたときに色が替わるおそれがあり【推定】、iPhone では横のスクロールとぶつかりうる。光っている丸の長押しなら、手のひらで開いても色は替わらず、次に Pencil が紙に触れると閉じてその線は書ける。

### 3.6 閉じ方（0f-11）

- **ColorPanelWatch**（T）: 板が開いている間だけ、**凍結の `InkTouchObserver` の新しいインスタンス**を画面の窓（`paletteRoom.window`。PalmWatch と同じ窓、`CalendarRootScreen.swift:3712-3716`）に付ける。1.4.1 の PalmWatch（`Views/PaletteGrip.swift:272-372`）と同じ形で、ほかの認識と全部いっしょに走り、何も止めない（`InkTouchObserver.swift:30-37`）。
  - 触れが下りたとき（`.down`。Pencil・指・ポインタ）、その位置（観測者の `location(in: window)`）が板の枠の外で、光っている丸の枠の外なら、板を閉じる（`ColorPanelLogic.closesOnTouch`）。テストの口は `touched(_ change: InkTouchObserver.Change, at point: CGPoint)` で、UIKit の道では `observer.location(in: window)` を渡して呼ぶ。
  - 開くときは、`ColorPanelLogic.placement` の結果で `panelFrame` を同じ番に入れる（板の枠がまだ測られていない `.zero` のままだと、板の中の速い押しで閉じうる）。
  - **触れは止めない**。紙に書き始めた線は書け、ボタンは押せ、紙は動く。
  - 閉じたら外す。`InkTouchObserver.swift` は 1 バイトも変えない（凍結の 6 行目）。凍結の観測者は `UITouch` を渡さず、`UIGestureRecognizer.location(in:)` は追っている触れ全部の重心を返す。だから 2 本目の指が下りたときの位置は、その指の位置にならない【未確認】（§13.1 の 2）。位置の読み方が確かでないと分かったら、`ColorPanelView.swift` の中に小さな新しい認識の型を作ってよい（凍結の外）。T が決めて記録する。
  - 凍結の観測者が知らせるのは down と up だけで、動きは知らせない（`InkTouchObserver.swift:21-24`・:40-70）。光っている丸の上で始まった触れは閉じないので、そこから引き始めたスクロール（iPhone のバーの横スクロール、iPad の縦のバーのスクロール）では、ColorPanelWatch は閉じない。これは下の「光っている丸が動いた」で閉じる。
- **`penDown()` では閉じない**（第 2 版で決め直した）。`penDown()` は PencilKit の Begin で呼ばれ、Pencil のホバーでも来る（`CalendarRootScreen.swift:1199-1200`、`InkCanvasView.swift:1880-1883`・:2041-2043、M7A.md ずれ 46 ④）。ここで閉じると、ホバーの効く iPad Pro 13 で、指で開いた板へ Pencil を紙の上から近づけただけで、触れる前に板が閉じてしまう。紙や画面への本当の触れ（Pencil・指・ポインタ）は、窓に付けた ColorPanelWatch がすでに全部閉じる。`penDown()` の本体には何も足さない（「ペンが触れても画面を更新しない」約束 :1205-1209 もそのまま）。
- 画面の事でも閉じる（S）。**閉じる処理は、新しく足す別の修飾子だけに書く**（新しい関数 `colorPanelLayer(_:)` などにまとめる）:
  - `.onChange(of: sheetIsUp)`（シートが出た。`sheetsChanged()` の `if` には書かない。§5.6）。
  - `.onChange(of: scenePhase)`（アプリが前でなくなった）、`.onChange(of: windowSize)`（窓の大きさ・向きが変わった。場所を追いかけず閉じる）。
  - `.onChange(of: toolbarMode)`（しまう・のぞきがしまう・ピンで開く）、`.onChange(of: paletteEdge)`（辺が替わる）、`.onChange(of: paletteDragging)`（true になったとき。つまみや「動かす」で引き始めた）、`.onChange(of: paletteMenuShown)`（true になったとき。「動かす」の選択肢が開いた）。
  - `.onChange(of: tool)`（ペンでなくなったとき。Pencil のダブルタップで消しゴムなど）。
  - **光っている丸が動いた**（バーのスクロール・回転・バーの作り直し）: 重ね（`overlayPreferenceValue` の中）で、開いたときの光っている丸の枠を覚えておき、解いた枠が 1 pt より動いたら閉じる（`ColorPanelLogic.closesOnAnchorMove(opened:now:)`）。形（`onChange` で枠を比べるなど）は T と S が決めて記録する。
  - 色を選んだ・戻した・「その他の色…」を押した（板の中の押しなので、板の動作の中で閉じる）。
  - **`toolbarEvent`・`placePalette`・`paletteMoveChosen`・`paletteMoveButtonChose`・`sheetsChanged` の本体には書かない**。凍結の予定の `PaletteMoveButtonTests` が、これらの本体の字と数をそのまま確かめている（:509-535。`toolbarEvent(.placementChosen)` が 1 つ、`placePalette(on: edge)` が 2 つ、`{ paletteMenuShown = false }` が 2 つ、`toolbarEvent` の本体の字）。前からある `.onChange(of: scenePhase) { scenePhaseChanged() }`（:861）・`.onChange(of: tool) { … lastInkTool … }`（:862-864）・`.onChange(of: paletteEdge) { logPalette() }`（:3673）などの本体にも足さず、別の修飾子にする。
- VoiceOver: 板は `.isModal`。escape の操作（2 本指で Z）で閉じる。VoiceOver の押しは窓の触れにならないので、ColorPanelWatch では閉じない【推定】。
- 「動かす」の選択肢（1.4.1 の confirmationDialog、`ToolbarView.swift:206-213`）とは同時に出ない: 「動かす」を押す触れは板の外なので板が閉じ、選択肢が開いている間はツールバーを押せない。

### 3.7 選ぶ・「その他の色…」・「最初の色に戻す」（0f-12〜0f-14）

- **板で色を選んだ**（`choose(hex, slot: i, slots:)`）:
  - その色がほかの丸 j にある → 丸は変えず、ペンをその色に（丸 j が光る）。
  - 無い → 丸 i をその色に、ペンをその色に。
  - どちらも `tool = .ink(pen)`（太さはそのまま）、板を閉じる。書くのは `toolbar.penSlots`（変わったときだけ）と `toolbar.penColor`。
- **「その他の色…」**（0f-13）:
  - 押した順: `colorPickerSlot = slot`（板を開いた丸 i）→ 板を閉じる（`colorPanelSlot = nil`）→ `colorPickerShown = true`。画面の `.sheet(isPresented: $colorPickerShown, onDismiss:)` で `ColorPickerSheet`（`UIViewControllerRepresentable` で `UIColorPickerViewController`）を出す。`supportsAlpha = false`。`selectedColor` は丸 i の色。題（`title`）は付けない（システムの既定。新しい文を作らない）。
  - 決めるのは `colorPickerViewController(_:didSelect:continuously:)` の `continuously == false` のときと、閉じたとき（それまでの最後の候補）だけ。引いている間は UserDefaults に書かない（`ColorPanelLogic.commitsPick`）。
  - 受けた色は、すぐ凍結の `InkColors.hex(of:)`（`Ink/InkTools.swift:202-217`。ライトで解決し、0〜1 に切り詰めた sRGB の hex）で "#rrggbb" にし、**その字で `ColorPanelLogic.choose(hex, slot: colorPickerSlot ?? 0, slots:)` する**（`ColorPickerSheet` は丸の番号を持たない。丸は画面の `colorPickerSlot`）。Display P3 の鮮やかな色を選んでも、書いている間の色と、保存して開き直した後の色がずれない。
  - **閉じたときの後始末**: 色選びの × は自分で dismiss を呼ぶので、SwiftUI の `colorPickerShown` が true のまま残りうる。そうなると `sheetIsUp` が false に戻らず、`sheetsChanged()`（:2571-2590）が待たせているアカウントの問い・ピンチの案内・週の始まりの知らせ・年齢確認・案内の札が、ずっと出ない。だから Coordinator の `colorPickerViewControllerDidFinish` で必ず `onDone` を呼び、`onDone` では最後の候補でまだ決めていなければ `choose` し、`colorPickerShown = false`・`colorPickerSlot = nil` にする。`.sheet` の `onDismiss` でも同じ後始末をする（2 回目は何もしない）。
  - **スポイト**: 色選びが「出された VC」のとき、スポイトは自分を隠して画面の色を拾う。SwiftUI のシートの子として包むと、効かないか、シートごと消えることがある【未確認】（§13.1 の 4）。
  - **D1b で (a) `sheetIsUp` が戻らない、または (b) スポイトが効かない、が起きたら**、UIKit の present に替える: iPad は板があった枠（または光っている丸の枠）を `sourceRect` にした popover、iPhone は pageSheet。`colorPickerViewControllerDidFinish` と `presentationControllerDidDismiss` で `colorPickerShown = false`・`colorPickerSlot = nil` に戻す（`colorPickerShown` は出している間 true のままにし、`sheetIsUp` に数える）。T が決めて `docs/R1_4_2.md` に記録する。
  - `sheetIsUp`（:731-734）の最後に `|| colorPickerShown` を足す。アカウントの問い・ピンチの案内・週の始まりの知らせ・年齢確認は、色選びが閉じるまで待つ（`sheetsChanged()` :2571-2590 の今の道）。凍結の `SpanGuideSeenSpanTests.swift:276-278` は本体が `|| ageRangeAsking` を**含む**ことだけを見るので通る。
  - 紙に近い色を選んでも止めない（計画 §5.3。本人の選んだ色）。
- **「最初の色に戻す」**（0f-14。`reset(currentPen:slots:)`）: 6 つの丸を最初の 6 色に。今のペンの色が丸 k にあれば、ペンは最初の色の k 番目（太さはそのまま）。板を閉じる。光る丸と「ペン」ボタンで出るペンと書ける色が、いつも同じになる。`lastInkTool` は `tool` の onChange でついて来る。

### 3.8 置き場所（縦のバー・のぞき・iPhone。0f-15）

- `ColorPanelLogic.placement(anchor:edge:container:panel:)`。`edge` は今効いている辺（`ToolbarLogic.effectiveEdge`。のぞきも同じ辺に出る、R1_4_1_CONTRACT 0e-20）。`container` は画面の安全な領域。
  - 下: 板の下端 = 丸の minY − 8。横の真ん中を丸に合わせる。
  - 上: 板の上端 = 丸の maxY ＋ 8。横は同じ。
  - 左（縦のバー）: 板の左端 = 丸の maxX ＋ 8。縦の真ん中を丸に合わせる。
  - 右（縦のバー）: 板の右端 = 丸の minX − 8。縦は同じ。
  - どれも、container の内側 8 pt に入るよう寄せる。
- 出る所（全部で同じ規則。`ToolbarView(` の呼び出しは 1 つのまま、R1_4_1_CONTRACT §5.6）: 下に開いたバー（`safeAreaInset`、`CalendarRootScreen.swift:834-846`）、下ののぞき（overlay、:782-789）、上の枠（`paletteTopSlot` :3395-3410）、左右の枠（`paletteSideSlot` :3414-3433、axis `.vertical`）、上・左右ののぞき（`palettePeek` :3437-3456）。縦の丸（`verticalColorSwatches` :455-479、`verticalSwatch` :482-501）も、横の丸（`colorSwatches` :243-271、`swatch` :287-306）と同じ動き・長押し・anchor・identifier。
- iPhone はいつも下（`ToolbarLogic.allowedEdges`、`ToolbarLogic.swift:427-433`）。Duo の内側も下。iPhone のバーは横の `ScrollView` で、丸が半分隠れていても板は画面に寄せる。
- 単体テストの表（§6.1）: 402×874 の iPhone の下（いちばん左の丸・いちばん右の丸）、1032×1376 の 13 インチの下・上・左・右、744×1133 の mini の左、13 インチの下ののぞき。

### 3.9 ダークの縁（0f-16）

- 横 `ToolbarView.swift:293` と縦 :488 の丸の縁 `Color.black.opacity(0.15)` を、`colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.15)`（`@Environment(\.colorScheme)`）にする。**ライトの式は今と同じ字**なので、ライトの画素は 1.4.1 と同じ（J-4 で示す。§7.1）。
- 動的な `UIColor`（`UIColor { … }`）にはしない。色空間の違い（sRGB の黒と extendedGray の黒）で合成が 1 段ずれ、J-4 のほぼ全部の写真が変わるおそれがある【推定】。
- 値は純粋な `ColorPanelLogic.swatchRim(dark:)` に置き、ソースの字の確かめ（2 か所ともライトが `Color.black.opacity(0.15)` の字）を新しいテストで。
- 板の丸は紙の色の面の上なので、いつも黒 0.15。しまった丸ボタンの色の点（`ToolbarDock.swift:82-92`、輪は `Color.primary.opacity(0.15)` :90）は今のまま（ダークに合っている）。
- 理由: 黒 #1f2937 とダークのバー（#2c2c2e と仮定）のコントラストは 1.1、紺 1.6、茶・深緑 2.0 で溶ける【計算】。計画 §2（本人が読んだ所）に「これも直します」とある。
- ダークの写真は今の CI に 1 枚も無い【事実】（どの写真の段も `simctl ui appearance light`、例 `build.yml:979`）。palette-shots の最後にダークの 2 枚を足す（§7.3）。

### 3.10 VoiceOver と identifier（0f-17）

- 丸のラベルは `colorName`。「その他の色…」で選んだ色は「その他の色」。2 つの丸に入れると、どちらも「その他の色」と読む（計画 §2 のとおり。番号は付けない。新しい文を増やさない）。
- 光っている丸: `.isSelected`（今のまま、`ToolbarView.swift:304-305`・:499-500）、ヒント「もう一度押すと、色を替えられます」、操作「ペンの色を選ぶ」（光っていない丸にも操作だけ付ける。§3.5）。
- 板: ラベル「ペンの色を選ぶ」、`.isModal`、escape で閉じる、開いたら焦点を今の色の丸へ（`@AccessibilityFocusState`）。12 色のラベルは色の名前、今のペンの色は `.isSelected`。
- identifier（UI テストの検索に使う。読み上げられない）: ペンの丸 `toolbar.swatch.0`〜`toolbar.swatch.5`（横と縦で同じ）、板 `toolbar.colorPanel`、板の色 `toolbar.colorPanel.<rrggbb>`（# を除いた小文字）、`toolbar.colorPanel.other`、`toolbar.colorPanel.reset`。**新しい UI テストと `restoreDefaultPen` は、ラベルではなく identifier で探す**（板の 12 色も色の名前をラベルに持つので、開いている間は `app.buttons["黒"]` が 2 つに当たる）。
- スイッチコントロールとフルキーボードアクセスでも押せる（ふつうのボタン）。

### 3.11 写真モードと UI テストの切り離し（0f-18）

- `--screenshot-color-panel`（値なし）: 道具がペンのとき、最初のレイアウトの後に光っている丸の板を開く（`--screenshot-palette-menu` の開き方、`CalendarRootScreen.swift:1555-1569`、と同じ形。最大 10 秒待つ）。
- `--screenshot-pen-slots <6 つの hex をカンマで>`: 写真モードの丸（読めなければ nil = 最初の 6 色）。写真モードの始まりのペンは丸 1 の色（無ければ今と同じ黒、`ScreenshotMode.swift:180-185`）。
- **写真モードでは `toolbar.penSlots` を読まず、書かない**（丸はメモリの中。形は T が決める。候補: `@AppStorage(…, store:)` に、写真モードでは起動ごとに空にする別の suite を渡す）。UI テストは同じシミュレータで続けて走るので、丸の色が次のテストへ漏れないようにする（今のペンの色は漏れる。`EraserAndBelowDayUITests.swift:648` の注）。
- `toolbar.penColor` は今のまま（写真モードでも書く。1.4.1 と同じ動きを変えない）。
- 新しい `Config` の項目は既定値つき。今までの引数の Config は同じ値（`ScreenshotMode.swift:268-296` の形）。凍結の `ScreenshotModeTests` を書き直さず、新しいテストは新しいファイル（前例 `ScreenshotModeHandPaletteTests.swift`）。
- 色選びの画面（システムの物）は写真モードで撮らない。`Sheet` を足さない（`Sheet.allCases.count == 11` は凍結、`ScreenshotModeTests.swift:302-303`）。

---

## 4. メモ欄の紙

### 4.1 型と鍵（0f-19）

- 新しい `Paper/MemoPaperStyle.swift`（M）: `enum MemoPaperStyle { ruled, dots, plain }`。`init(stored:)` は nil・知らない字・文字列でない値を `.ruled` に。
- 鍵 `paper.memoStyle`（`AppSettings.memoPaperKey`、S）。端末ごと（UserDefaults、iCloud に送らない。`AppSettings.swift:17-19`）、書き出し・PDF の中身に入れない、`isExistingUser` の鍵ではない、移さない（無いときは罫線）。
- `MemoPaperStyle.current`（`@MainActor static`、既定 `.ruled`）。前例は `WeekStartChoice.current`（`Persistence/WeekStartChoice.swift:19`）と `HolidayChoice.current`（`HolidayChoice.swift:17`）。
- `prepareAtLaunch(shot: ScreenshotMode.Config?, _ defaults: UserDefaults = AppSettings.defaults, testHost: Bool = SyncEngine.isTestHost)`（`CalendarRootScreen.init`、`WeekStartChoice.prepareAtLaunch` :491 の近くで、`shot:` だけを渡して呼ぶ）:
  - 写真モード → `shot.memoPaper ?? .ruled`（保存した値を読まない。`--screenshot-hand` の形、`ScreenshotMode.swift:497-503`）。
  - テストのホスト（`testHost`。既定は `SyncEngine.isTestHost`、`Sync/SyncEngine.swift:32-39`）→ `.ruled`（保存した値を読まない。手元のシミュレータに残った「ドット」で、凍結の画素のテストが落ちないように）。
  - ほか → 保存した値。
  - **この「保存した値」の枝は、写真モードもテストのホストも通らないので、CI の UI テストも、そのままでは単体テストも届かない**（単体テストの中では `SyncEngine.isTestHost` がいつも真）。1.4.1 で、CI が保存した `toolbar.collapsed` を一度も通らなかったのと同じ形（R1_4_1_CONTRACT §18.1）。だから `testHost:` を引数にし、`MemoPaperStyleTests` で `testHost: false` と使い捨ての suite を渡して、保存した dots・plain・壊れた字を読むことを確かめる（§6.1、変異 MM4）。本人の確かめ表の行 15 でも、開き直して確かめる。
- `set(_:)`: `current` と違えば替えて、`MemoPaperStyle.didChange` を出す（同じなら何もしない）。

### 4.2 設定の画面（0f-20）

- 新しい `Views/MemoPaperSettingsSection.swift`（S）。`inputSections`（`SettingsScreen.swift:487-`）の**最初の要素**に置く。見た目は「祝日」の節のすぐ下（計画 §2 の「祝日の下」のとおり）。
  - 設定の `Form` の 9 つ（`SettingsScreen.swift:254-271`。凍結の `SettingsPageSectionTests.swift:127-128` がちょうど 9 つの名前を見る）は変えない。`pageSection`（凍結のテストが中を読む :206-228）にも入れない。`HolidaySettingsSection` の本体にも入れない（祝日の型の中にメモの設定を置かない）。
  - 1.4.1 の利き手も `inputSections` の中（:517-532）に置いて 9 つを守った。同じ考え。
- 形: `WeekStartSettingsSection.swift:33-56` と同じ `.pickerStyle(.navigationLink)` の Picker（題「メモ欄の紙」、選びは「罫線」「ドット方眼」「無地」）、見出しは無し、脚注 1 つ。identifier `settings.memoPaper`。計画 §2 の「週の始まりと同じ形」のとおり（利き手の `.inline` ではない）。
- 替えたとき: 写真モードの外では保存してから `MemoPaperStyle.set`。写真モードでは保存せず `set` だけ（UI テストで紙が変わるのを見るため。利き手の `handChanged(to:screenshot:)`、`SettingsScreen.swift:193-196`、と同じく保存しない）。
- 閲覧専用でも替えられる（`docs/DESIGN.md:854`「許す（8）」）。

### 4.3 紙への届け方（0f-21）

- **PaperView の性質にする**（計画 §5.2 の「content に memoStyle を足す」形にしない）。
  - `PaperView` に `var memoPaper: MemoPaperStyle`。didSet で値が違えば `setNeedsDisplay()`（中身の didSet、`PaperView.swift:172-174`、と同じ考え）。
  - `init(content:zoomScale:)`（:207-226）の形は変えない（凍結の `InkCanvasView.swift:272` が「この init だけを前提にする」、`Export/PDFPageRenderer.swift:229` も同じ形で作る）。init の中で `MemoPaperStyle.current` を入れ、`didChange` を受ける（受けたら `memoPaper = MemoPaperStyle.current`）。
  - **init では `setNeedsDisplay` を呼ばない**（凍結の `PaperViewTests` が `displayRequestCount` を数える、`PaperViewTests.swift:244-250`）。`super.init` の前に値を入れれば didSet は走らない。
  - 描く関数は `view.memoPaper` を読む（`PaperRenderer.draw` は `view` を受ける、`PaperView.swift:149-154`。つないだ窓の `drawSpan`、:370-395、も `view` を受ける）。`FreeMemoPaper.draw`（`Paper/FreeMemoPaper.swift:21`）には最後の引数 `style: MemoPaperStyle` を**既定値なし**で足し、`DayPaper.drawExtra`（`DayPaper.swift:90-94`）と週の呼び出し（`WeekPaper.swift:63`）が柄を渡す（`view.memoPaper` を描く関数の入口で読み、引数で下へ渡す。`drawExtra` は今 `view` を受けていない）。既定値を付けると、どちらかが渡し忘れても黙って通る。テストからこの関数を直接呼ぶ所は無い【事実】ので、既定値は要らない（変異 MM5）。
- 理由: **つないだ週と日**（1.3 からの既定）の紙は、凍結の `InkCanvasView.paperSpan`（`InkCanvasView.swift:2625-2637`）→ `PaperSpan.init(layout:)`（`Paper/PaperSpan.swift:49-61`）が**レイアウトだけから**作る。窓の紙を作り直す `updatePaperSpan`（:3140-3147）は、形が変わったときか新しいレイアウトを取ったときしか呼ばれない（:3087-3090）【事実】。content に柄を入れても、つないだ紙には届かず、届けても設定を替えたときに描き直されない。PaperView の性質なら、1 ページの道・つないだ窓・PDF の全部に、凍結の `InkCanvasView`・レイアウト・content・`PaperSpan` に触れずに届く。
- PDF: `PDFPageRenderer` が作る `PaperView`（:229）も init で今の柄を読むので、その端末の柄で出る。`PDFPageRenderer.swift` は変えない見込み。
- 年のページ（`YearPaper.swift`。メモ欄も罫線も無い【事実】）・週と日の時間の格子（`TimeGridPaper.swift`）には関わらない。

### 4.4 描き方（0f-22）

- **罫線の道は今の字のまま**（呼ぶ順 `setLineWidth` → `setStrokeColor` → `beginPath` → `addHorizontal` → `strokePath` を変えない）。`switch` で分け、`.ruled` の枝に今の行をそのまま置く。3 か所を共通の部品にまとめ直すこと（計画 §5.2）は**しない**。呼ぶ順が変わると、凍結の画素のテスト（`PaperViewTests.swift:240-290` の 2,450 と 2,500 の #ebe7de、`WeekMemoPaperSpanTests.swift:364`・:399・:321・:528 の 1.2.3 と同じ画素）が落ちうる。月の private 定数（`MonthPaper.swift:11-12`、50・20）も残す。
- 分ける所（3 か所）: 月 `MonthPaper.swift:74-84`、日の右の「メモ」`DayPaper.swift:53-65`、自由メモ `FreeMemoPaper.swift:42-57`（`ruledLines`。注が「後でメモ欄の紙を変える 1 か所」と書く【事実】。日の 24 時の下と、1.3 の週のメモの両方がここを通る）。
- どの柄でも描く: 区切りの強い線（月 `MonthPaper.swift:67-72`、自由メモ `FreeMemoPaper.swift:24-30`）、見出し「メモ」「自由メモ」、日の時間の列の右の線。
- **ドット**:
  - 行は罫線と同じ y（欄の上 ＋ 50k、k ≥ 1、欄の下端より上）。最初の行は見出しの下（＋6）と重ならない。
  - 列は x = 30 ＋ 50k のうち、欄の左 ＋ 20 以上・右 − 20 以下（共通の格子）。月 30…1380 の 28 点、日の右の「メモ」680…980 の 7 点、日の自由メモ 30…980 の 20 点、週の自由メモ 30…1380 の 28 点。日のページで、右の列と 24 時の下の点の列が縦にそろう。日の右の列の点の行は、時間の目盛りの 30 分ごと（100 lu/時）と高さがそろう。
  - つないだページでは、列が 50 ずつ続く（日 980 → 1030、週 1380 → 1430。週 1,400 と日 1,000 が 50 の倍数のため）【計算】。罫線は境で 40 lu 切れる（`PaperSpan.swift:12-13`）が、点は切れない。
  - 点は 1 つのパスに入れ（`addEllipse`）、1 回で塗る。`dirty` で x と y の両方を絞る（つないだ窓では各ページの local で）。色は新しい `PaperPalette.memoDot`。
- **無地**: 罫線も点も描かない。
- `WeekPaper.swift:7-11` の注（週のメモは本人の選びで「罫線だけ」、M7C の Q2 A）を、「1.4.2 から設定 › メモ欄の紙 に従う（罫線が既定）」と直す。

### 4.5 ドットの見た目（0f-23）

- 大きさは**画面でいつも同じ**（罫線の 1 pt、`PaperText.hairline`、`PaperText.swift:61-63`、と同じ考え。直径 d pt = d / zoom lu）。PDF は 1 lu = 1 pt なので d pt。
- 中心は画素にそろえる（`PaperText.addHorizontal`、`PaperText.swift:191-195`、と同じ考え。要れば `PaperText` に点の口を足す）。
- 既定 **(a) 直径 2 pt・#d6cfc2**（計画 §5.2 の例）。選びの (b) 直径 1.5 pt・#cdc5b6（小さく濃い）、(c) 直径 2.5 pt・#d7dade（大きく、区切りの線の色）。本人が写真で選ぶ（§7.4、0f-31）。罫線と同じ #ebe7de の点は、紙 #fffdf8 の上ではほとんど見えない見込み【推定】なので候補に入れない。
- 選ばれた形は `PaperPalette.memoDot` と直径の定数を替えるだけ（コードの形は同じ）。

### 4.6 重さと PDF

- 最悪は 1 ページ 120 行 × 28 点 = 3,360 点（月・週のメモが 6,000 lu いっぱいのとき）【計算】。描くのは窓を作り直したときとズームの終わりだけ（`PaperView.swift:275-314`）で、書いている間は描かない。
- 新しいテストで、最悪の窓を描く時間をログに出す（`memo dots: n=… ms=…`。ゆるい上限 100 ms。CI のシミュレータは遅く揺れるので、上限を超えたら記録して M が見直す）。
- PDF のバイト数を 3 つの柄で計って記録する（月のメモ欄に手書きがあるとき、日の右の列。日の PDF には右の列がいつも入る、`PDFPageRenderer.swift:72-97`）。楕円で大きすぎるときは小さな四角にする（M が決めて記録）。

### 4.7 写真モード

- `--screenshot-memo-paper ruled|dots|plain`（無い・知らない値は nil = 罫線）。写真モードは保存した柄を読まず書かない。**J-4 の写真は罫線のまま**。
- `r142-alt` の枝だけ（取り込まない）: `--screenshot-dot-look a|b|c`（DEBUG だけ。§7.4）。

---

## 5. データ互換

### 5.1 保存の形（変えない）

- 新しいページ id・マス名・線の項目を作らない。`v`（`InkPage.swift:20`・:247）と書き出し `tegaki-app-export` v1 を上げない（K-5）。**1.4.2 は新しい保存の形を書かない**ので、新しい fixture は無い。
- 線の色は前から「#rrggbb」の小文字でどの色も入る【事実】（`TegakiKit/Sources/InkModel/InkStroke.swift:105-106`、作るときに正規化 :123、`normalizeColor` :140-155 は #rgb と #rrggbb ならどの色でも受ける、JSON は :166 で書き :198 で読む、投げなわの写しも色を保つ :279）。1.0 の凍結の写しも同じ字（`TegakiKit/Tests/Compat10/InkStrokeV10.swift:139-156`・:165・:197・:278）。merge は色をただの文字列として比べる（`InkPage.swift:210`）。Web 版の取り込みも正規化する（`WebImport.swift:221`）。
- 表に無い色が今も保存できる証拠【事実】: 凍結の `InkLedgerTests.testNewStrokeGetsIdAndCell`（`InkLedgerTests.swift:98-113`）が PencilKit の線を「#000000」のまま往復させる。凍結の fixture compat11 の `ledger-day.json`・`ledger-month.json` に #000000 の線がある。Web の描画は #rgb・#rgba・#rrggbb・#rrggbbaa を受ける（`render.js:45`・:164-168）。
- 新しい鍵は端末の UserDefaults の 2 つだけ（`toolbar.penSlots`・`paper.memoStyle`）。手書きのデータではなく、iCloud にも書き出しにも入らない。App Privacy（データの収集なし）も変わらない。

### 5.2 K-1〜K-11 とこの版での当てはめ

規則の正文は [M7_PLAN.md](M7_PLAN.md) §1.3。

| 規則 | 1.4.2 での当てはめ |
| --- | --- |
| K-1 `allday` で始まる名前を使わない | 新しい名前は無い |
| K-2 同じ id の線を付け替えない | 台帳のコードを変えない。投げなわの色替えは範囲外（§1.4） |
| K-3 1 つのページに 2 枚のキャンバスで書かない | キャンバスを増やさない。板は紙の上の重ねで、キャンバスではない |
| K-4 マスの意味を変えない | 変えない（紙の柄は絵だけ。マスの位置も大きさも同じ） |
| K-5 線に項目を足さない、`v`・v1 を上げない | 足さない・上げない。色は今の `color` の字に入る。InkModel の 9 ファイルは 1 バイトも変えない |
| K-6 伸びる紙の一覧は固定部分 | 変えない（`ZoomPolicy` を変えない） |
| K-7 互換テストは古い版の本物のコードで | 1.0・<1.1.1>・1.2.3・1.3 の相手をそのまま走らせ、本物の 1.0 のコードで新しい色の線を読む確かめを足す（§5.3） |
| K-8 古い端末での見え方を新機能の文に | 新しい色の線は古い端末でもその色で見え、メモ欄の紙は古い端末で罫線になるだけで、隠れる手書きは無い。新機能の文に K-8 の句は入れない（SUPPORT の「版が違うと？」に 1 文足す、§8.5） |
| K-9 線の予算 | 変えない |
| K-10 名前の文字 | 新しい名前が無い |
| K-11 週の始まりとページ | 変えない |

### 5.3 互換の相手（変えない）と、色の線の確かめ（0f-24）

- compat-v1-0（macos-26・Xcode 26.6）で、1.0（a21e469）・<1.1.1>・1.2.3（43fe366）・1.3（955fe67）の本物のコードが今の fixture を読む。1.4.1 の最後の数: compat10 **599**・失敗 0、span-compat 1.0 **274**・<1.1.1> **274**・1.2.3 **278**・1.3 **310**、`Real13LedgerTests` 5/5【事実】（`docs/R1_4_1.md:143`）。S0 で run #4 のログから数え直して `docs/R1_4_2.md` に書く。
- **足す確かめ**（C）: `TegakiKit/Tests/Compat10/Checks/Compat10Checks.swift`（FROZEN.sha256 の外。本物の 1.0 と凍結の写しの両方に写して走らせる、`tools/compat10/run.sh`）に、**コードの中で作る**新しい色の線を足す。茶 `#92400e` と「その他の色」の例 `#0a7e8c`（大文字の `#0A7E8C` と #rgb の `#0ac` も）。確かめること: JSON の往復で色の字が 1 字も変わらない（大文字・#rgb は 1.0 の正規化どおり）、merge で色が残る、1.0 の台帳の描く対象に入る（消された扱いにしない）。今の線は :164 の #1f2937 だけ【事実】。
  - 新しい fixture の JSON は置かない（`FIXTURES_1_3` は compat11・compat-span・CompatFixtures のフォルダで、表に無いファイルが増えると落ちる、`build.yml:476-492`）。
  - compat10 の数は 599 より増える。増えた数を D1b の前に `docs/R1_4_2.md` に宣言する。`EXPECTED_MIN`（225。条件は「225 以上」）は変えない。
- アプリの側（T、新しいテスト `InkColorRoundTripTests`）: Display P3 の色 → `InkColors.hex(of:)` → `InkStyle(colorHex:)` → PencilKit の線の色 → `InkColors.hex(of:)` が同じ字。茶の線を台帳で往復（凍結の `InkLedgerTests.testNewStrokeGetsIdAndCell` の作り方を写す）。

### 5.4 凍結の表（`tools/compat10/DATA_1_1.sha256`、20 行）

**1.4.2 で変えてよい行: 無い**（0f-24）。20 行とも 1 バイトも変えない（`build.yml:444-448` の `shasum -c`）。とくに次の行のファイルに触れずに作れる【事実で確かめた】:

| 行 | ファイル | 1.4.2 での使い方 |
| --- | --- | --- |
| 1 | `Ink/InkCanvasView.swift` | 使うだけ。紙は `PaperView` の性質で届く（§4.3）。`PaperView(content:)` の形（:272）を変えない |
| 5 | `Ink/InkTools.swift` | `InkColors.normalized`・`hex(of:)` を使うだけ。`InkPresets` は読まない |
| 6 | `Ink/InkTouchObserver.swift` | ColorPanelWatch が新しいインスタンスを作って使うだけ |
| 8 | `Ink/PencilInteraction.swift` | 触れない（スクイーズとパレットの設定は範囲外） |
| 2〜4・7・9〜11 | `InkLedger`・`InkOverlayView`・`InkSnapshot`・`InkTrace`・`InkPageStore`・`InkPageRecord`・`SyncEngine` | 触れない（`SyncEngine.isTestHost` を読むだけ。§4.1） |
| 12〜20 | `TegakiKit/Sources/InkModel/` の 9 ファイル | 触れない（例外なし） |

- 凍結のファイルに触れる直しが要ると分かったら、止めて契約を直す（1.4.1 の §5.4 の作り直しの手順を、その時に契約に書く）。

### 5.5 守られたテストと fixture の表

- `tools/span/TESTS_1_3.sha256`（29 行）・`TESTS_1_2_3.sha256`（8 行）・`FIXTURES_1_3.sha256`（37 行）は 1 字も変えない【事実: 行の数は 11/24 に数えた】。
- **新しい守りの表 `tools/span/TESTS_1_4_1.sha256`**（0f-28。D0 で C が作り、`build.yml` の TESTS_1_3 の段 :465 の後に同じ形の段「1.4.1 tests frozen (1.4.2)」）。1.4.1 で足した単体テストと UI テストのうち、1.4.2 で書き直す理由の無い物を入れる。候補（D0 で C が `git diff --name-status 2fb8fb1 2e3ee75 -- Tests` から確かめて表にする）: `HandSettingTests`・`HeaderGlyphTests`・`HeaderOrderTests`・`HeaderTitleTests`・`InkCanvasSpanZoomResetTests`・`InkCanvasWidthCentreTests`・`InkCanvasZoomResetTests`・`PaletteGripTests`・`PaletteMoveButtonTests`・`ScreenshotModeHandPaletteTests`・`ToolbarPlacementTests`・`ZoomFitWiringTests`・`ZoomResetTargetTests`（単体 13）、`HeaderRoomUITests`・`PaletteMoveUITests`・`ZoomResetUITests`（UI 3）。入れない物: `PaletteShotsUITests`（1.4.2 で写真の行を足す）、1.4.1 で書き直した今までのファイル（`ToolbarLogicTests` など）。
  - 理由: 1.4.2 は 1.4.1 で大きく直した `ToolbarView`・`ToolbarLogic`・`CalendarRootScreen` に触れる。1.4.1 の動き（ツールバーの辺・つまみ・「動かす」・等倍・利き手）を確かめるテストを、作る人がうっかり弱めないようにする。
  - 守りのテストが新しいコードで落ちたら、テストの側は直さない。コードを直す。テストの側が間違っていると分かったら止めて、リードが決めて記録する。
- 新しいテストは全部新しいファイル。今のファイルに足すのは、守られていない `ToolbarLogicTests`・`AppSettingsTests`・`SettingsScreenTests`・`EraserAndBelowDayUITests`・`PaletteShotsUITests`・`LanguageUITests` だけ（§6.2）。

### 5.6 画面の字で守られた所と、変えない数・形

`CalendarRootScreen.swift` の次の字は、空白を平らにした形で 1 字も変えない（ピン留めのテストがソースを読む。R1_4_1_CONTRACT §5.6 と同じ一覧に、1.4.2 で気をつける所を足した）:
- `onPenDown: { guide.close() penDown() }`、`if zooming { guide.close() pinchBegan() }`、`func joinedTap(at point: CGPoint, zoom: CGFloat, smallScreen: Bool) { reviewTask?.cancel() guide.close()` と、`guide.close()` がちょうど 3 つ（`SpanGuideSeenSpanTests.swift:262-267`）。**板を閉じる関数の名前に `guide.close()` の字を使わない**（例 `closeColorPanel()`）。
- `if sheetIsUp { guide.dismiss() } else { showSpanGuideIfCalm() }` ほか、`guide.dismiss()` がちょうど 3 つ（:269-273）。**板を閉じる処理は `sheetsChanged()` の `if` の中に書かない**。自分の `.onChange(of: sheetIsUp)` で。
- `private var sheetIsUp: Bool {` の本体（最初の `}` まで）が `|| ageRangeAsking` を含む（:276-278）。`|| colorPickerShown` はその後ろに足す。
- `allowFinger: allowFingerBinding,` がちょうど 2 つ（`CalendarRootScreen.swift` の ToolbarView と SettingsScreen の呼び出し）と、`$allowFinger` が無いこと（`PencilPhoneTests.swift:188-194`）。`ToolbarView(` の呼び出しは `toolbar(axis:)` の 1 つのまま（縦のバーとのぞきも同じ）。新しい引数 `colorPanel:` は **`axis:` の前**（`axis: axis, move: paletteMoveButton )` の字を保つ。0f-36）。
- `func joinedCanvas(_ span: SpanSession, viewportWidth: CGFloat) -> some View {` などの `ScreenPathsSpanTests.swift:1840-1855`・:1869-1875・:1932-1938 の字、`OnePageRevealTests.swift:19-38` の字。
- 1.4.1 の守りの表（§5.5）のテストが読むソースの字（`ZoomFitWiringTests`・`PaletteMoveButtonTests` などの字の確かめ）。とくに `PaletteMoveButtonTests.swift:467-537`:
  - :467-482 の `PaletteMoveButtonView(` の呼び出し・`paletteMoveButtonChose` の本体と数・ToolbarView の `move.onMove(` の字。
  - :509-535 の `paletteMoveChosen`・`placePalette` の本体、`toolbarEvent(.placementChosen)` がちょうど 1 つ、`placePalette(on: edge)` がちょうど 2 つ、`toolbarEvent` の本体の字、`.onChange(of: paletteHasMoveButton) { … }`、`{ paletteMenuShown = false }` がちょうど 2 つ、`paletteHasMoveButton`・`paletteMoveButton` の宣言。**板を閉じる処理をこれらの本体に書かない**（§3.6）。
  - :537 の `axis: axis, move: paletteMoveButton )` がちょうど 1 つ。

`SettingsScreen.swift`:
- `Form` の 9 つの並び（`SettingsPageSectionTests.swift:127-128`）と `pageSection` の中身（:206-228）。

変えない数と形:
- `ToolbarLogic.dockClearance == 60`、`paperBottomClearance`・`toastBottomPadding`、ツールバーの行と列の寸法（`ToolbarLogic.Row`・`Column`）、6 つの丸の幅。
- `StartState` の欄、`--screenshot-toolbar` の値、`toolbar: paperArea=`・`toolbar: safeArea=`・`toolbar: palette=` の行の形。
- `Sheet.allCases.count == 11`、`SettingsSection == ["page"]`（`ScreenshotModeTests.swift:302-303`、`ScreenshotModeSpanTests.swift:255`・:673-674）。設定の写真のために新しい節の名前を足さない（行までは XCUI で送って撮る）。
- `MonthPaperContent`・`WeekPaperContent`・`DayPaperContent`（`PaperView.swift:8-25`）の欄。凍結のテスト（`InkCanvasSpanTests.swift:99-100`・:506 ほか）が memberwise init で作る。
- `PaperView.init(content:zoomScale:)` の形と、init で描き直しを頼まないこと。

### 5.7 保存のバイト（関門 2）

- `InkLedgerTests.testLedgerWritesTheCompatShapes`・`ScreenshotModeTests.testDemoPagesMatchCompatFixtures`・`SpanSessionTests.testSpanSessionWritesTheCompatSpanShapes` が、作り直さずに今の fixture と 1 バイトも同じ（R1_4_1_CONTRACT §5.7 と同じ 3 つ）。D0 と、D1a・D1b の最初の通しの run で見る。違えば止める。

---

## 6. テスト

新しいテストは新しいファイル。時間を待つテストは `TestSleeper`。新しい UI テストの待ち方は「期限の後にもう 1 回読む・回数で数える」形（§1.5）。「直しが無いとどう落ちるか」は変異で確かめる（§6.4）。結果と run の番号を `docs/R1_4_2.md` に書く。

### 6.1 新しいテスト

| 役 | ファイル（新しい） | テスト | 直しが無いと（変異） |
| --- | --- | --- | --- |
| T | `PenSlotsTests.swift` | `slots(stored:)` の表（nil・空・5 つ・7 つ・壊れた字・大文字・#rgb・重複 2 つと 3 つ・全部同じ）→ いつも 6 つで重複なし。`storedSlots` の往復。`pen(colorHex:width:slots:)`: 丸にある色はその色、無い色は丸 1、太さの規則は同じ。`rememberedPen` が丸の鍵も読む（茶の丸と茶のペン → 茶）。`colorName` の 12 色・マーカー・「その他の色」 | MC1（関門が `penColors` で調べる）・MC2（重複を直さない）で落ちる |
| T | `ColorPanelLogicTests.swift` | `tap`・`longPress` の表（§3.5）。`choose`（新しい色・ほかの丸にある色）。`reset`（ペンが丸 k → 最初の色の k 番目、太さは同じ）。`placement` の表（§3.8 の 7 つ、どれも container の内側 8 に入り、丸と重ならない）。`closesOnTouch`（板の中・光っている丸・外）。`closesOnAnchorMove` の表（同じ枠・1 pt 以内・横に 2 pt・縦に 2 pt・大きさが変わる）。`commitsPick`。`swatchRim` | MC3（引いている間に決める）・MC4（辺を見ずにいつも上に出す）・MC6b（`closesOnTouch` が板の中でも真）・MC7（戻すとペンが替わらない）・MC8（丸が動いても閉じない）で落ちる |
| T | `ColorPanelWatchTests.swift`（`PaletteGripTests` の PalmWatch の確かめ方を写す。UIKit の代わりに `touched(_:at:)` を呼ぶ形） | 開いている間だけ窓に付き、閉じると外れる。外の位置の触れ（Pencil・指・ポインタ）で 1 回だけ閉じる。板の中・光っている丸の上の位置では閉じない。開いた直後（`panelFrame` は placement の結果）の板の中の触れでも閉じない。凍結の `InkTouchObserver` の型を使っている | MC6（`closesOnTouch` を呼ばずに閉じる）・MC6b で落ちる |
| T | `SwatchRimTests.swift` | `swatchRim(dark:)` の 2 つ。`ToolbarView.swift` のソースで、横と縦の 2 か所ともライトの枝が `Color.black.opacity(0.15)` の字で、ダークの枝が `swatchRim` の値 | MC5（ダークもライトと同じ）で落ちる |
| T | `ColorPanelFitTests.swift`（`ToolbarFitTests` の測り方を写す） | 板のボタンの 2 つの字が 10 の言語で板の幅に入る（1 行・縮み 0.8 まで、だめなら 2 行で高さ 44）。12 色の名前と 4 つの新しい読み上げの文が 10 の言語のバンドルにある。板が幅 375 の画面に入る | 入らない字で落ちる |
| T | `InkColorRoundTripTests.swift` | §5.3 のアプリの側（P3 の色 → sRGB の hex → 同じ字。茶の線の台帳の往復） | sRGB にしないと落ちる |
| S | `ColorPanelWiringTests.swift`（ソースの字の確かめ） | `ToolbarView(` が 1 つ、`allowFinger: allowFingerBinding,` が 2 つ、`guide.close()` が 3 つ、`guide.dismiss()` が 3 つ。平らにした `colorPanel: ColorPanelHook(openSlot: $colorPanelSlot), axis: axis, move: paletteMoveButton )` がちょうど 1 つ。`sheetIsUp` の本体が `colorPickerShown` の項を含む（`ageRangeAsking` の後）。自分の `.onChange(of: sheetIsUp)` が板を閉じ、`sheetsChanged()` の本体に板の字（`colorPanelSlot`）が無い。`penDown()`・`toolbarEvent`・`placePalette`・`paletteMoveChosen`・`paletteMoveButtonChose` の本体に `colorPanelSlot` の字が無い。`.onChange(of: colorPanelSlot)` が `colorPanelWatch` を attach・detach する。`colorPanelWatch` が `@State`。色選びの `onPick` が `colorPickerSlot` を使う | MS1（画面が板を開いても ColorPanelWatch を窓に付けない）で落ちる |
| S | `ScreenshotModeColorMemoTests.swift` | `--screenshot-color-panel`・`--screenshot-pen-slots`・`--screenshot-memo-paper` を読む。知らない値・値なしは nil・false。今までの引数の Config は同じ値。写真モードでは `toolbar.penSlots` と `paper.memoStyle` を書かない（使い捨ての suite で） | MS2（写真モードで丸を書く）・MM3（写真モードで保存した柄を読む）で落ちる |
| M | `MemoPaperStyleTests.swift` | `init(stored:)` の表、鍵 `paper.memoStyle`、`prepareAtLaunch`: 写真モード（`shot.memoPaper`、保存した値は読まない）・`testHost: true`（保存した dots があっても `.ruled`）・**`testHost: false` と使い捨ての suite で、保存した dots → `.dots`、plain → `.plain`、壊れた字・無い → `.ruled`**。`set` が違うときだけ知らせる。テストは `AppSettings.defaults`（`AppSettings.swift:137`）を使い捨ての suite に向け、tearDown で `current = .ruled` に戻す | MM3（写真モードで保存した柄を読む）・MM4（保存した値を読まない）で落ちる |
| M | `MemoPaperDrawTests.swift`（凍結の `PaperViewTests` の画素の読み方を写す） | 3 つの柄 × 月のメモ・日の右の「メモ」・日の自由メモ・週の自由メモ（週は `WeekPaper` の道、週の content の `PaperView` で描く。`FreeMemoPaper.draw` を直接呼ばない）。ドット: 点の中心（例 (30, 上 ＋ 50)）が点の色、点の間（(55, 上 ＋ 50)）が紙の色、欄の外に点が無い。無地: 罫線の y が紙の色、区切りの線と見出しは残る。罫線: 今の画素と同じ（`.ruled` で描いた絵と、柄を渡さない今の道の絵が 1 画素も同じ）。つないだ日の窓で点の列が 980 → 1030 と続く。PDF に点が出る（`renderPDF` の形）。3 つの柄の PDF のバイト数と、最悪の窓の時間をログに | MM1（罫線のときも点を描く）・MM5（`WeekPaper` が柄を渡さない）で落ちる |
| M | `MemoPaperRedrawTests.swift` | `PaperView(content:)` を作った直後の `displayRequestCount` が 0。柄を替えて知らせる → 1 ページの PaperView と、つないだ窓（`span` を持つ）の PaperView の両方が 1 回だけ描き直しを頼み、`memoPaper` が新しい柄。同じ柄の知らせでは頼まない | MM2（知らせを受けない）で落ちる |
| U | `ColorPanelUITests.swift`（ui-tests、iPhone 17。ログ `color-panel UI:`） | ペンを選ぶ → 光っている黒（`toolbar.swatch.0`）を押す → `toolbar.colorPanel` が出る → 茶を押す → 板が消え、`toolbar.swatch.0` のラベルが茶で選ばれている、キャンバスの probe の道具が `pen:#92400e:3.5`（凍結の `InkCanvasView.swift:819-823` の形）。もう一度開いて青（ほかの丸にある色）→ 丸 1 は茶のまま、丸 2 が光る。光っている丸の長押しで開く。開いて見出しの何もない所を押す → 閉じる。開いて「その他の色…」→ システムの色選びの画面が出る → 閉じる → 丸は同じ → **歯車で設定のシートが開く**（`sheetIsUp` が false に戻った証拠）。開いて「最初の色に戻す」→ 丸 1 が黒、probe が `pen:#1f2937:3.5`。**`--screenshot-page week` で開き、開いたまま紙に指で線を引く**（iPhone の既定で「指でも書く」はオン。要れば `-allowFingerDrawing YES`）→ `toolbar.colorPanel` が消え、probe の線の数が 1 増え、道具は開く前の色のまま（自前の板にした一番の理由、§3.4 の 1）。**開いたまま光っていない `toolbar.swatch.1` を押す** → 板が消え、swatch.1 が選ばれ、probe が青。**開いてから、光っている丸の上からバーを横に引く** → `toolbar.colorPanel` が消える（§3.6 の「光っている丸が動いた」）。開いている間の `app.buttons["太さ: 中"].exists` をログに出す（§3.4 の 2。結果は `docs/R1_4_2.md`）。丸と板の色は identifier で探す（§3.10） | 板が無い・最初の線が消える・閉じない |
| U | `ColorPanelPadUITests.swift`（blank-paper の iPad 13 の段。`TEST_RUNNER_TEGAKI_PALETTE_UI=1` のときだけ、ほかは `XCTSkip`。ログ `color-panel UI:`） | `--screenshot-palette left` で開く → 板の minX ≥ バーの maxX。`right` → 板の maxX ≤ バーの minX。`top` → 板の minY ≥ バーの maxY。下ののぞき（`--screenshot-toolbar collapsed` → 丸ボタンの道具の印 → 光っている丸）→ 板が出て、色を選ぶとのぞきは残る。**左ののぞき**（`--screenshot-palette left --screenshot-toolbar collapsed` → 道具の印 → 光っている丸）→ 板の minX ≥ のぞきのバーの maxX、色を選ぶとのぞきは残る（1.4.1 で本人が詰まったのは端のしまった形、R1_4_1_CONTRACT §18.1）。どれも板は画面の中 | 板が縦のバーやのぞきで出ない |
| U | `MemoPaperUITests.swift`（ui-tests、iPhone 17。ログ `memo-paper UI:`） | 設定 › メモ欄の紙（`settings.memoPaper`）の値が「罫線」→「ドット方眼」を選ぶ → 行の値が「ドット方眼」→ 画面の DEBUG の印（新しい、`memo-paper: style=` のログか見えない要素。U が決める）が `dots` → 「罫線」に戻す。写真モードで走るので保存はしない | 設定が紙へ届かない |

### 6.2 足すテスト（守られていない今のファイル）

- `ToolbarLogicTests`: `testRememberedPen` の注を「丸に無い色 → 丸 1」に（字は替えない）。`testBadgeForEveryTool`（:196-246）に茶・その他の色の行。
- `AppSettingsTests.testToolbarKeys`（:157-163）: 「鍵が全部別」の一覧に `toolbar.penSlots` と `paper.memoStyle`。
- `SettingsScreenTests`: メモ欄の紙の文（ja）、identifier、`inputSections` の最初の要素が `MemoPaperSettingsSection`、替えると保存して `set`（写真モードでは保存しない）。MS3（写真モードで柄を保存する）で落ちる。
- `EraserAndBelowDayUITests`: `restoreDefaultPen`（:648-652）は、丸 1（`toolbar.swatch.0`、写真モードの丸は最初の 6 色なので黒）が光っていないときだけ押す（光っている丸を押すと板が開くため。余計な板を開かない）。ラベル「黒」ではなく identifier で探す（§3.10）。
- `PaletteShotsUITests`: 新しい写真の行（§7.3）。
- `LanguageUITests`（l10n-shots）: 新しい写真（§7.3）。

### 6.3 そのまま通すテスト（変えない）

- `TESTS_1_3`（29）・`TESTS_1_2_3`（8）・新しい `TESTS_1_4_1` の全部。とくに `PaperViewTests`・`WeekMemoPaperSpanTests`・`PaperSpanTests`・`PaperSpanFrozen123`（紙の画素）、`SettingsPageSectionTests`（設定の 9 つ）、`ScreenshotModeTests`・`ScreenshotModeSpanTests`（写真モードの数）、`CalendarRootScreenTests`（`rememberedPen`）、`InkCanvasViewTests`・`InkCanvasSpanTests`、`SpanGuideSeenSpanTests`、`InkLedgerTests`、KitChecks の `WeekMemoChecks`。
- `ToolbarFitTests`（6 つの丸のまま）、`PaletteMoveButtonTests.swift:624` と `ToolbarFitTests.testToolbarViewAxisSizes`（:174-196）は `ToolbarView` を既定の引数で作るので通る。
- KitChecks 40,826（閾値 40,776）、compat10（数は §5.3 で増える）、span-compat、`Real13LedgerTests`、保存のバイトの関門 2。
- 1.4.1 の数（基準。`docs/R1_4_1.md` の run #4）: 単体 **900**（飛ばし 2・失敗 0）、UI tests (iPhone) **71**（飛ばし 19・失敗 0）、同期の繰り返し 4,000、`PaletteMoveUITests` iPad 13 で 3 本、palette-shots 22 行 `ok=yes`。1.4.2 の新しいテストの分だけ増える（数は run で書く）。

### 6.4 変異（`r142-q-m1`。取り込まない）

変異を全部 1 本の枝に入れ、落ちるはずのテストの表（`tools/mutations/m1-expected.tsv`。変異の枝にだけ置く）を run の前に書く。**落ちたテストが表とちょうど同じなら ○**（表に無いテストが落ちたら理由を書く。R1_4_1_CONTRACT §6.5・§16.7 と同じ形）。UI テストは速い道では走らないので、変異は単体テストで捕まる物にする。**`m1-expected.tsv` の頭に、変異ごとの場所（ファイル:行）と書き換える字を書く**（中身があいまいだと、作り方しだいで落ちるテストが表とずれる。例: MC5 を `swatchRim` の値で作ると `ColorPanelLogicTests` も落ちる）。

| 変異 | 中身（場所と書き換え） | 落ちるはずのテスト |
| --- | --- | --- |
| MC1 | `pen(colorHex:width:slots:)` が `penColors` で調べる | `PenSlotsTests` |
| MC2 | `slots(stored:)` が重複を直さない | `PenSlotsTests` |
| MC3 | 色選びを `continuously == true` でも決める（`commitsPick` がいつも true） | `ColorPanelLogicTests` |
| MC4 | `placement` が辺を見ずにいつも丸の上に出す | `ColorPanelLogicTests` |
| MC5 | `ToolbarView.swift` の横（:293）と縦（:488）の縁で、ダークの枝をライトの字 `Color.black.opacity(0.15)` にする（`swatchRim` は変えない） | `SwatchRimTests` のみ |
| MC6 | `ColorPanelWatch` が `closesOnTouch` を呼ばずに閉じる（どの位置の down でも閉じる。`closesOnTouch` は変えない） | `ColorPanelWatchTests` のみ |
| MC6b | `ColorPanelLogic.closesOnTouch` が板の中でも true | `ColorPanelLogicTests`・`ColorPanelWatchTests` |
| MC7 | 「最初の色に戻す」でペンが替わらない | `ColorPanelLogicTests` |
| MC8 | `closesOnAnchorMove` がいつも false（丸が動いても閉じない） | `ColorPanelLogicTests` |
| MS1 | 画面が板を開いても ColorPanelWatch を窓に付けない（`.onChange(of: colorPanelSlot)` の attach の行を消す） | `ColorPanelWiringTests` |
| MS2 | 写真モードで丸を書く | `ScreenshotModeColorMemoTests` |
| MS3 | 写真モードで柄を保存する | `SettingsScreenTests` |
| MM1 | 罫線のときも点を描く | `MemoPaperDrawTests` |
| MM2 | PaperView が知らせを受けない | `MemoPaperRedrawTests` |
| MM3 | 写真モードで保存した柄を読む | `ScreenshotModeColorMemoTests`・`MemoPaperStyleTests` |
| MM4 | `prepareAtLaunch` が保存した値を読まない（`testHost` が false でもいつも `.ruled`） | `MemoPaperStyleTests` |
| MM5 | `WeekPaper.swift:63` の呼び出しが `style: .ruled` を渡す（週のメモだけ柄に従わない） | `MemoPaperDrawTests` |

### 6.5 CI の道（0f-27）

- **枝の配線（D0、C）**: `r142` の名前を足す。`branches-ignore` に `r142-duo*`（`build.yml:81-93`）、速い道 `QUICK` に `r142-quick`・`r142-q-*`・**`r142-w-*`**（:149。作る役の枝を上げても通しの run を起こさない。1.4.1 では `r141-w-*` の push が通しの run になり、別の run と実行機を取り合った、`docs/R1_4_1.md:560`）、`MUTATIONS` に `r142-q-m1`（:155）、ジョブの `if:` の速い道の字（:1701・:2141・:2506・:2994・:3487）に同じ名前（**:2141 の compat-v1.0 だけは形が違い、`(startsWith(github.ref_name, 'r142-q-') && github.ref_name != 'r142-q-m1')` の形で足す**。ほかと同じ形で足すと、変異の枝 `r142-q-m1` で compat-v1.0 が走らなくなる）、言語の写真の段に `r142`（:4153-4155）、duo.yml に `r142-duo*`（`duo.yml:38-41`）。`r13`・`r14`・`r141` の名前は残す。
- **写真を撮る枝に `q-` を付けない**: `r142-q-*` と `r142-w-*` は速い道で、写真の段とジョブが走らない。本人の選びの写真の枝は `r142-alt`、写真だけの試しの枝は `r142-shots<n>`（R1_4_1_CONTRACT §6.6 と同じ）。
- 速い道の単体テストの組（`build.yml:656-690` の一覧）に、§6.1 の新しい単体テストの組を名前で足す。
- ui-tests（iPhone 17）で `ColorPanelUITests`・`MemoPaperUITests`。grep に `color-panel UI:`・`memo-paper UI:` を足す。
- blank-paper の「Palette UI tests on the 13-inch iPad (1.4.1)」の段（:3289-3293、上限 20 分）に `ColorPanelPadUITests` を足す（段の名前に「(1.4.2)」を足す）。時間が上限に近ければ、別の段にする（C が決めて記録）。**関門 1 は、ジョブの `continue-on-error` に関わらず、この段の結果で読む**。
- D0 で `TESTS_1_4_1` の段（§5.5）。
- 理由: 新しいテストを毎回の道で走らせ、写真は通しの run だけで撮る。

---

## 7. 写真

### 7.1 J-4 の基準と違ってよい所（0f-29）

- 新しい基準 `tools/l10n/ja-baseline-ref-1.4.2.txt` = `fbd1f7ab82860d00599a43a8768eaa162611b768`（ビルド 31、1.4.1 の公開したビルド）。`ja-baseline.yml:124` の `FILE=` をこれに。`-1.4.1.txt`（2fb8fb1）・`-1.4.txt`・`-1.3.txt`・`ja-baseline-ref.txt` は記録として残す。
- J-4 の `screenshots` を撮る今の写真の段は、`build.yml` と `ja-baseline.yml` で同じ字のまま（1.4.2 はその段を変えない）。**§7.3 の新しい写真は `screenshots` に入れず別の成果物に撮り、`ja-baseline.yml` には足さない**（`compare_shots` は下のフォルダまで全部を比べ、片側だけの写真も落とす。R1_4_1_CONTRACT §7.1）。
- 比べ方は今の J-4。合否は、同じ UTC の日に撮り、2 つの env.txt の Xcode と実行環境の版が同じ組でだけ決める。run が UTC の 0:00 をまたいだら、2 つの日の基準の両方で比べる（1.4.1 の run #4 と同じ、`docs/R1_4_1.md:596-599`）。
- **D0（CI だけの commit）**: 違ってよい強い差は `ipad13-portrait-sheet-info.png` の版の字（「1.4.1 (1)」→「1.4.2 (1)」）だけ。
- **機能の commit（D1a〜D2）で違ってよい所**（D0 の前に `docs/R1_4_2.md` に書く。機種ごとの画素の行は S0' の控えの写真で測る）:
  1. `ipad13-portrait-sheet-info.png`（版の字）。
  2. `ipad13-portrait-sheet-sync.png`: 同期の節より上の帯（1.4.1 は利き手の節でこの帯の y 716–949 が変わり、前もって宣言していなかった、`docs/R1_4_1.md:224-225`。1.4.2 の新しい節は「祝日」の下でこの帯より上なので、差は 0 の見込み。それでも宣言する）。
  3. `ipad13-portrait-sheet-settings.png` と `store/ipad13/06-settings.jpg`: 「祝日」の節の終わりから下（写るのは「週の始まり」の頭までなので、差は 0 の見込み、`docs/R1_4_1.md:77`）。
  - **これ以外は強く違ってはいけない**。とくに、ツールバー（ライトの丸の縁、丸の並び）と、メモ欄の紙（写真モードは罫線）が写る全部の写真（`*-month-memo`・`*-day-extra`・日のページ・`zoom2`・`readonly`・横向き・店の JPEG）は、1.4.1 と画素が同じであること。
  - 違ってよい所は `tools/shots/shift_pair.swift --exclude-rows <行> --max-strong 0` で示す。
- 理由: 1.4.2 は既定の見た目を変えない版なので、J-4 は「ほぼ全部同じ」を強く示せる。ダークの縁とメモ欄の柄は、既定のライト・罫線では画素に出ない作りにした（§3.9・§4.4）。

### 7.2 関門 3（紙の領域）

- 既定の写真の `toolbar: paperArea=` の値の組と、span-shots-app の状態の行 71 本（`pages`・`zoom`・`ox`・`oy`・`span cap:`。時間の欄 `waited=` を除く）が、**基準の run #4（45074645599）**と同じ。`header room:` の行と `zoom: reset` の 32 行も同じ。
- 新しい写真の起動（板を開いた形・ドットの紙）の `paperArea=` は、同じ置き場所の今の値と同じ見込み（板もドットも紙の領域を変えない）。違えば止める。

### 7.3 新しい写真（J-4 の組の外。写真モード。0f-30）

- **palette-shots**（span-shots-app のジョブ、`PaletteShotsUITests`、成果物 `palette-shots`。日本語だけ）に行を足す。数は D1b の前に C が `docs/R1_4_2.md` に書き、`build.yml:4224` の「22 expected」を直す。候補:
  - ipad13 の縦の週: 下のバーで板を開いた形（`--screenshot-color-panel`）、上、左、右、下ののぞき、**左ののぞき（`ipad13-portrait-week-peek-left-color-panel`。`--screenshot-palette left --screenshot-toolbar collapsed` → 道具の印 → 光っている丸）**。
  - ipadmini の縦の週: 左で板。
  - iphone17 の縦の週: 下で板。替えた丸（`--screenshot-pen-slots` で茶・グレー・ピンク・水色・深緑・紺）。
  - **ダーク**: ipad13 の縦の週と iphone17 の縦の週を、`xcrun simctl ui <端末> appearance dark` にして撮り、すぐ `light` に戻す（そのジョブの最後。span-shots-app の 64 枚とほかの palette の写真はライトのまま）。
  - 12 色の見本（本人の Q3 の確かめ）は、ipad13 の下の板の写真をそのまま使う。
- **メモ欄の紙の写真**（新しい成果物 `memo-paper-shots`。どの段で撮るかは C が D1a で決めて記録。候補: blank-paper の 4 機種の回しに新しい UI テスト `MemoPaperShotsUITests`）: ipad13 と iphone69 の、月のメモ欄（`--screenshot-grown --screenshot-offset`）・日の右の「メモ」と自由メモ・つないだ週の自由メモ・つないだ日の境目、を `--screenshot-memo-paper dots` と `plain` で。月の PDF を 1 枚（ドット）。
- **l10n-shots**（成果物 `l10n-screenshots`）: 10 の言語の設定の「メモ欄の紙」の行と脚注（XCUI で行まで送って撮る。`SettingsSection` を足さない）。de・fr・疑似の言語の、選ぶ画面と、色の板。数は C が記録に書く（今の 63 から増える）。
- blank-paper・span-shots-app・palette-shots・memo-paper-shots・UI テストの添付は、リードが比べる（自動では落とさない。`ok=no` は警告）。
- **確認ページと D2' に使う板の写真は、リードが目で見て、仕込んだ手書きと板が写っていることを確かめる**。palette-shots の `ok=` は辺しか見ないので、1.4.1 では手書きが写る前に撮った写真がそれで通った（`iphone-landscape-week-hand-left` の撮り直し、`docs/R1_4_1.md:311`）。

### 7.4 本人の選びの写真（`r142-alt`。1 組だけ。取り込まない。0f-31）

- **写真で選ぶのは、ドット方眼の点の見た目だけ**（計画 §2 の約束「2〜3 通りの写真をお見せして選んでもらいます」）。1.4.1 のリードの調整（写真で見せる選びは少なく、ほかは言葉で既定）に合わせた。
- 使い捨ての枝 `r142-alt` に、DEBUG だけの引数 `--screenshot-dot-look a|b|c` を作る（`r142` にも main にも入れない）。枝の名前に `q-` を付けない。写真はその枝の `build.yml` に足す写真だけの段で撮り、別の成果物にする。その run は J-4・関門 3・D1〜D2 の関門の合否に数えない。run の番号と写真を `docs/R1_4_2.md` の D2' に書く。**写真は TestFlight より前に、段 D2'（§9.1）で 12 色の見本と一緒に本人へ先に送る**（計画 Q3「見本の絵をお送りしてから決めます」、`docs/PLAN_PEN_COLORS.md:68`）。
- 撮るのは ipad13 と iphone69 の、月のメモ欄と日のページ（右の「メモ」と自由メモ）を、(a)・(b)・(c) で（2 機種 × 2 ページ × 3 = 12 枚）。
- **12 色は写真の選びにしない**: palette-shots の板の写真（§7.3）を見本として見せ、替えたい色だけ言葉でもらう（§0.4）。
- 本人が (b)・(c) を選んだら、`r142` の `PaperPalette.memoDot` と直径の定数を替え、D1a の関門（メモの写真と単体テスト）をやり直す。D3 のビルドより前（D2' の答え）なら、そのビルドに入れる。後なら新しい TestFlight のビルドで渡す（やり直す確かめ表の行は §9.4）。
- **12 色の替えは重い**: 黄土色・えんじなど今のキーに無い色（`app-S.json` の `toolbar.color.*` は 10 個で、ochre などは無い）に替えると、新しいキーと 9 言語の訳・元を見ない逆翻訳・判定（REVIEW.md の節 17）と D2 の関門のやり直しになり、日が数日のびる（§9.4・§11）。

### 7.5 店の写真（0f-33）

- **撮り直さない**。ツールバーの見た目（6 つの丸・最初の色）と紙の既定（罫線）は変わらない。Connect は新しい版で前の版の写真を引き継ぐ（1.4.1 の `submit check` で ja 15 枚・ほか 20 枚と Duo 5 枚を読み戻した、`docs/R1_4_1.md:646`）。版 1.4.2 を作った後に読み戻して確かめる。

### 7.6 控え（S0'）

- 基準の run #4（45074645599）と ja-baseline の 45091842816 の 7 日の成果物は **11/30 ごろに消える**【推定】（`retention-days: 7`）。`~/.local/share/tegaki-backup/` には 1.4 の物と asc141・confirm141v4 しか無い【事実】。**D0 の前（遅くとも 11/26）に**、run #4 の `screenshots`・`ui-tests`・`l10n-screenshots`・`blank-paper`・`span-shots-app`・`span-shots-app-languages`・`palette-shots` と ja-baseline の成果物、**1.4.1 の duo run 45075275518（`r141-duo4`、d416da8）の `duo-shots`**（D1c で Duo の外側の写真を 1.4.1 と比べるため）を `~/.local/share/tegaki-backup/1.4.2/` へ控え、`unzip -t` で確かめる。関門 3 の基準（`paperArea` の組・状態の行 71 本）と、§7.1 の画素の行の測りと、確認ページの前と後に使う。

---

## 8. 文字・訳・App Store

### 8.1 アプリの新しい文（13 キー。0f-25）

| キー | 元のファイル | ja | en（案。X が GLOSSARY で決める） | 注 |
| --- | --- | --- | --- | --- |
| `toolbar.color.brown` | `app-S.json` | 茶 | Brown | 色の名前。読み上げ（色の丸・板の色・丸ボタンの値）。今の `toolbar.color.*`（:2703-2823）と同じ comment |
| `toolbar.color.gray` | `app-S.json` | グレー | Gray | 同じ |
| `toolbar.color.darkGreen` | `app-S.json` | 深緑 | Dark Green | 同じ。緑（`toolbar.color.green`）と言い分ける |
| `toolbar.color.navy` | `app-S.json` | 紺 | Navy | 同じ。青・水色と言い分ける |
| `toolbar.colorPanel.title` | `app-S.json` | ペンの色を選ぶ | Choose Pen Color | 板の読み上げの名前と、丸の VoiceOver の操作名。画面に字は出ない |
| `toolbar.colorPanel.hint` | `app-S.json` | もう一度押すと、色を替えられます | — | 光っている丸の読み上げのヒント |
| `toolbar.colorPanel.other` | `app-S.json` | その他の色… | Other Color… | 板のボタン（画面に出る）。今の `toolbar.color.unknown`「その他の色」（読み上げの名前）とは別のキー |
| `toolbar.colorPanel.reset` | `app-S.json` | 最初の色に戻す | — | 板のボタン（画面に出る）。6 つの丸を最初の 6 色に戻す |
| `settings.memoPaper.title` | `app-U.json` | メモ欄の紙 | Notes Paper | 設定の行の題（Picker の題）。GLOSSARY のメモ = Notes（:42） |
| `settings.memoPaper.ruled` | `app-U.json` | 罫線 | Lined | |
| `settings.memoPaper.dots` | `app-U.json` | ドット方眼 | Dot Grid | |
| `settings.memoPaper.plain` | `app-U.json` | 無地 | Blank | |
| `settings.memoPaper.footer` | `app-U.json` | メモ欄と自由メモの紙の柄です。手書きはそのまま残ります。この設定は端末ごとです。 | — | 計画 §2 の字（本人が読んだ字）のまま。ページの種類を並べない（後の版で欄が増えても直さずに済む） |

- ピンク・水色は今の `toolbar.color.pink`・`toolbar.color.lightBlue`（今はマーカーの名前）をそのまま使う。comment を「ペンとマーカーの色の名前」に直す必要は無い（今の comment が「ペンとマーカーの色の名前」【事実】）。
- 色選びの画面の題は付けない（新しい文を作らない。0f-13）。
- **comment だけ替える**: 0e-32 の `toolbar.grip.spoken`・`toolbar.moveTo.*`（§1.5）。
- アプリのコードに日本語の字を書かない（L-1）。新しいキーは `was` を持たない新しい文。
- **J-1（`tools/l10n/ja-baseline.tsv`）は変えない**（0f-25）。計画 `docs/PLAN_MEMO_PAPER.md:121` は「ja-baseline.tsv を更新」と書くが、J-1 は 1.1.1 の日本語の基準で、1.4.1 も新しいキーを足さなかった（R1_4_1_CONTRACT §8.1）。新しいキーは L-3（1.1.1 の行だけを見る）の外。

### 8.2 訳と逆翻訳（X・R）

- GLOSSARY を先に直す（X）: 色の名前 4 つ（茶・グレー・深緑・紺。青・水色・紺、緑・深緑を言語ごとにはっきり言い分ける）、メモ欄の紙・罫線・ドット方眼・無地（紙 :36・メモ :42・自由メモ :43 にそろえる。en は Title Case）、板のボタン 2 つ（「…」の字はその言語の省略の形）。
- 9 言語の訳（X）→ 元を見ない逆翻訳（R、`docs/i18n/back`）→ 判定の 2 役 → `docs/i18n/REVIEW.md` の**新しい節 17** を作り、× を 0 に。
- 確かめ: `lint.py`（L-1〜L-14）、`build.py --check`、`baseline.py --check`、CI の「Localized bundle check」（`build.yml:566`）、testflight の「Every word of the app in ten languages」（`testflight.yml:106`）。アプリの文は `tools/` の下にあるので、**確かめた run より前に**済ませる。
- 気をつけること: ja の字が同じだと jaSha1 も同じなので、comment だけ直した鍵（0e-32）は lint と build.py が古い訳を知らせない。訳を見直す要るかを X が判断して記録する（画面の字は替わらないので、既定は訳し直さない）。
- 言語ごとの確認表は、確認ページ 1 回の中で見せる。

### 8.3 新機能の文（16 ロケール。ja はこの文、ほかは訳。0f-26）

**案**（D2 で訳と逆翻訳。確認ページで全部の行を見せ、「この内容で入れてよい」は全部の組み合わせに効く）:

> ・ペンの色を増やしました。光っている色の丸をもう一度押すと（長押しでも）、12 色やお好きな色から選んで、その丸の色を入れ替えられます。
> ・設定に「メモ欄の紙」を足しました。メモ欄と自由メモの紙を、罫線・ドット方眼・無地から選べます。手書きはそのまま残ります。
> ・ダークモードで、ツールバーの濃い色の丸を見えやすくしました。

- ja は `docs/store/ja/whatsnew.txt`、ほかは `docs/store/source-ja/whatsnew.txt` から 11 の訳を作り、en-GB・en-AU・en-CA は en-US の、fr-CA は fr-FR の写し（`docs/store/README.md:60-64`、`locales.json`）。ja 以外は最後の行が AI の訳の断り（1.4.1 と同じ字）。4,000 字まで。
- アプリの語（「その他の色…」「メモ欄の紙」「罫線」「ドット方眼」「無地」「自由メモ」）は、その言語のアプリの訳と同じ字にする（X が写す）。無い改善は書かない。K-8 の句は入れない（§5.2）。
- 本人が 12 色を替えたときも、文は替えない（色の名前を書かないため）。SUPPORT も色の名前を並べない（§8.5）ので、色の替えで字が変わるのは審査メモの「To check」の 1 語だけ（茶を替えたとき。§8.4）。
- プロモーションテキストは新しい版で空になるので、今の文を入れ直して読み戻す。
- `docs/store/README.md` の新機能の文の表に 1.4.2 の行を足す。字の選びの組み合わせ（あれば）は `docs/store/PROPOSALS_1_4_2.md` にまとめる（`PROPOSALS_1_4_1.md` の形）。

### 8.4 審査メモ（`docs/store/review-note.txt`。英語が主で日本語の要約、4,000 バイトまで）

- 今は 3,897 バイト【事実: `wc -c`、11/24】。「What is new in 1.4.1」の段（:3-7）を「What is new in 1.4.2」に入れ替え、日本語の要約（`--- 日本語の要約 ---` の下）の 1.4.1 の文と新機能の 4 行を 1.4.2 の物に入れ替える。**ほかの段は 1 バイトも替えない**。
- 書くこと（英語。アプリの en の字は D2 の訳に合わせる）:
  1. Pen colors: tap the selected color dot again (or touch and hold it) to open a small panel with 12 colors, “Other Color…” (the system color picker) and the reset button. The choice replaces that dot and is remembered on this device. Stroke data is unchanged (each stroke already stores its color as a hex value). To check: open a week page, tap the black dot again, choose Brown and write.
  2. Settings > Notes Paper: Lined, Dot Grid or Blank for the notes areas. Only the pattern drawn on the paper changes; handwriting does not move.
  3. Unchanged: data (App Privacy stays “Data Not Collected”), handwriting storage, purchases and the age rating.
- 「To check」の色は茶（Brown）。本人が茶を替えたときだけ、替えた色の en の名前に直し、確認ページの字もその字にする（ほかの色の替えでは審査メモは変わらない）。
- 1.4.1 の 0e-28 の教訓: 「新しい文は設定と読み上げだけ」のような言い方はしない（板のボタンの字が画面に出る）。
- 入れ替えた後のバイト数を `docs/R1_4_2.md` に書く。4,000 を超えたら英語の 1 の文を短くする（ほかの段は替えない）。英語の新しい文は元を見ずに逆翻訳する（`docs/store/README.md:94-96`）。

### 8.5 SUPPORT（日本語・英語。W。公開の日に Web へ。承認は確認ページの 1 回）

- `docs/SUPPORT.md:7`・`docs/SUPPORT.en.md:11` の最終更新の日（公開の日に、リードの段）。
- **新しい FAQ 2 つ**（「ツールバーを動かすには？」 :159-166 の後、「1 ページにどれだけ書けますか？」 :168 の前）:
  - 「**ペンの色を替えるには？**」: ペンを選ぶと色の丸が 6 つ並ぶ。光っている丸（今のペンの色）をもう一度押すと（長押しでも）色の板が開く（1.4.2 から）。12 色（今の 6 色と、新しい 6 色。**色の名前は並べない**: 本人が 12 色を替えても、確認ページで「この内容で入れてよい」をもらった字が変わらないように。§8.3）と「その他の色…」（どんな色でも）。選んだ色はその丸に入り、ペンもその色に。「最初の色に戻す」。板は書き始めたとき・外に触れたときに閉じる（書いた線は残る）。替えた丸の色は端末ごと（線の色は iCloud でほかの端末にも届く）。上・左・右の端に置いたときも、しまったツールバーを丸ボタンの道具の印で出したときも開く。紙に近い薄い色は見えにくい（戻し方）。マーカーは 4 色のまま。
  - 「**メモ欄の紙を替えるには？**」: 設定 › メモ欄の紙 で罫線・ドット方眼・無地（1.4.2 から）。月のメモ欄・日の右の「メモ」・日と週の 24 時の下の「自由メモ」がそろって変わる。PDF もその柄。変わるのは紙の柄だけで、手書きは動かない。罫線に戻せば前と同じ。端末ごと。1.4.2 より前の版の端末では罫線のまま。
- 「**iPad と iPhone で版が違うと？**」（:172-174）に 1 文: 1.4.2 で足した色で書いた線も、前の版の端末でその色で見える（前の版のツールバーではその色を選べないだけ）。メモ欄の紙は前の版の端末では罫線のまま。
- 言い方は同じページの今の呼び方にそろえる（「丸ボタンの道具の印」、R1_4_1_CONTRACT 0e-34）。
- 英語の `SUPPORT.en.md` も同じ所。新しい英文は元を見ずに逆翻訳する。
- Web: 手元の枝 `r142-legal` を Web main 1024223 から作り（D2）、公開の日に早送りで送る（1.4.1 の `r141-legal` と同じ形、`docs/R1_4_1.md:651`・:656）。公開の道具の確かめに「Web の SUPPORT 2 ページが新しい文になっている」を入れる。

### 8.6 文書（リード）

- `docs/DESIGN.md` §2.8（設定。`:259-266`）にメモ欄の紙の行、ツールバーの色の節に 6 つの丸の記憶と色の板。`:567`（Pencil のパレットは予定のまま）は替えない。
- `README.md`: 新しいファイル（`ColorPanelView.swift`・`MemoPaperStyle.swift`・`MemoPaperSettingsSection.swift`）。
- `docs/M7_PLAN.md` §4 の 1.4.2 の行: この契約の第 1 版では指し先の 1 行だけを足した。時期と出した日はリードが記録の段で直す。「次の版」の行には、0f-2 の順を記録の段で書く。
- `docs/PLAN_PEN_COLORS.md`・`docs/PLAN_MEMO_PAPER.md` の頭の注に「作る約束は R1_4_2_CONTRACT.md（§3・§4 で §5 の案を直した）」。

---

## 9. 段取り・役・出し方

### 9.1 段と目安の日（2026-11-24 時点。`docs/R1_4_2.md` に実績を書いて直す）

CI の時間の見込みは 1.4.1 と同じ: build.yml は 1 回 75〜95 分（macOS のジョブは 5 つまで同時）。build-and-test の上限 160 分、UI tests の段 40 分、blank-paper の Palette UI の段 20 分、span-shots-app 115 分。**通しの run を 2 つ同時に走らせない**（1.4.1 で同時に回したら UI tests が 40 分の上限に届いた、`docs/R1_4_1.md:479`）。

| 段 | 目安 | 中身 | 関門 |
| --- | --- | --- | --- |
| S0 | 11/24 | この契約。`docs/R1_4_2.md` の骨組みと前もっての宣言（基準の数を run #4 から数え直す、J-4 の違ってよい所、compat10・palette-shots・l10n-shots の数を足す見込み）。**main 2e3ee75 の build.yml の run を `gh run list` で探し、番号と結果を記録する**（赤なら下の揺れの読み方で読み、本当の落ちなら D0 の前に止める）。本人に §0 を平たく伝える | リードが契約を読む。main の run の番号と結果が記録にある |
| S0' | 11/24〜11/26（D0 の前） | run #4 と ja-baseline の成果物、duo run 45075275518 の `duo-shots` を控える（§7.6）。§7.1 の画素の行を控えから測る | 控えの数と大きさを記録 |
| D0 | 11/25〜11/26 | CI だけの commit（`r142`）: 枝の配線、J-4 の基準のファイル、`MARKETING_VERSION "1.4.2"`、`TESTS_1_4_1` の表と段、`ink_ref_xcui` の見出しの帯（§1.5。D0 の後の別の commit でもよい）。`Sources`・`TegakiKit/Sources`・`Tests` は fbd1f7a と同じ | 下の D0 の関門 1〜8 |
| D1a | 11/26〜11/29 | メモ欄の紙（M・S）: `MemoPaperStyle`、`PaperView` の性質、3 か所の描き分け、設定の行、写真モード、テスト、memo-paper-shots | **作る役の commit の後に 2 つの目（型とテスト／契約と実機の UIKit・SwiftUI の動き）で見直し、must を 0 にしてから `r142` へ取り込む。指摘と決めたことを `docs/R1_4_2.md` に書く**（1.4.1 の must「のぞきに『動かす』が無い」は、この見直しで見つかった、R1_4_1_CONTRACT §18.1）。凍結の紙の画素のテストがそのまま緑。新しい紙のテスト（つないだ窓の描き直しを含む）が緑。J-4 は宣言の行だけ。関門 3 が同じ。PDF のバイト数と描く時間を記録 |
| D1b | 11/26〜12/2 | ペンの色（T・S・C）: 12 色・丸の記憶・関門・板・閉じ方・その他の色・戻す・置き場所・縁・VoiceOver・写真モード・compat10 の色の線・palette-shots とダークの写真 | **D1a と同じ 2 つの目の見直し（とくに §13.1 の 1〜4: anchor・窓の観測者・吹き出し・色選びのシート）で must を 0 にしてから `r142` へ取り込み、`docs/R1_4_2.md` に書く**。新しい単体テストと `ColorPanelUITests`（iPhone）・`ColorPanelPadUITests`（iPad 13）が緑。`PaletteMoveUITests` 3 本・`TESTS_1_4_1` がそのまま。compat10 の新しい数。J-4 は宣言の行だけ（ライトのツールバーは同じ）。関門 3 が同じ。palette-shots の新しい行が `ok=yes` |
| D1c | 12/1〜12/3 | 変異（`r142-q-m1`）と Duo（duo.yml `r142-duo1`） | §6.4 の変異で落ちたテストが表とちょうど同じ。`DuoLayoutUITests` と `shot_checks` が緑（Duo のツールバーは下のバーで、1.4.1 と同じ） |
| D2 | 11/30〜12/5 | 13 キーの訳（X）・逆翻訳（R）・判定・REVIEW.md の節 17、0e-32 の comment、lint・build.py・baseline.py・バンドル。SUPPORT の日英と `r142-legal`、16 ロケールの新機能の文、審査メモ（4,000 バイト以下）、DESIGN・README・計画の頭の注。同じ UTC の日の J-4、全部の組を `shift_pair` で示す。`r142-alt` の点の写真を撮る（§7.4。送るのは D2'） | 確認ページの材料がそろう |
| D2' | 12/1〜12/3（D1b の palette-shots と `r142-alt` の写真がそろいしだい。TestFlight の前） | 点の 3 通りの写真（§7.4）と 12 色の見本（palette-shots の板の写真、§7.3）を、小さく先に本人へ送る（リードが目で写真を確かめてから、§7.3）。答えは `docs/R1_4_2.md` の「本人の言葉と選び」に写す（0f-38） | 送った日時を記録。D3 のビルドを始める時までに答えが無ければ既定（(a)・この 12 色）にする。替えの答えがあれば、そのビルドより前に入れる（12 色の替えは D2 の訳と関門のやり直し、§7.4） |
| T0 | 11/30〜12/3 | 道具の移し（0f-35）: `asc141` → `asc142`（ver・whatsnew・enter・submit・release と、Web の SUPPORT の `web141_support.py`・`release141.py` も）、`confirm141v4` → `confirm142`。guard を 1.4.2 の字と、確認ページで承認した commit に結ぶ。選びの引数は、点 a・b・c（店の文には響かない）と、12 色の替え（審査メモの「To check」の 1 語、§8.4）。控えは `~/.local/share/tegaki-backup/<日付>/asc142`・`confirm142` | 偽の Connect の試験とオフラインの試しが失敗 0。試験の数を `docs/R1_4_2.md` に記録（1.4.1 では道具を移した後に契約が変わり、提出の直前に道具が止まった、`docs/R1_4_1.md:641`） |
| V | D2 の文の commit の後（12/3〜12/5） | 通しの run 1 回（ほかの通しの run と同時に走らせない）。D2 で訳（`Localizable.xcstrings`）・0e-32 の comment・`ink_ref_xcui` を変えるので、最後の通しの run はその後でなければならない。この run の commit を **「確かめた commit」** と呼び、run の番号とともに `docs/R1_4_2.md` に書く（0f-37。1.4.1 の run #4 の役） | 全部のジョブが緑（揺れの読み方どおり）、関門 3、同じ UTC の日の J-4（宣言の行の外で強い差 0）、palette-shots・memo-paper-shots の行、Duo の run（duo.yml）も同じコードで緑。この後に `Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` を変えたら V をやり直す |
| D3 | 12/4〜12/8 | TestFlight 1.4.2（ビルド 32 以上。**確かめた commit からコードの差が空の commit で作る**。アーカイブの確かめ `iphoneos27.2`・`17.0`・`1, 2`、Connect で VALID）。確認ページ 1 つ（§0.4 の中身、確かめ表）。**確認ページの写真は、確かめた run と、同じコードの duo の run の物だけ**（1.4.1 の Duo の撮り直し、`docs/R1_4_1.md:265`）。**下書きは、本人・事実・写真の 3 つの目で見直してから渡す**（どの文にも、元のファイルの字を確かめる guard を付ける。1.4.1 の wf_88b62ac4・wf_0b09b062、`docs/R1_4_1.md:379`・:622）。確認ページの道具（`confirm142`）の偽の試験を、V の後・渡す前に通す。確認ページの最初の画面に、§10 の準備の字を同じ字で書く | 本人の「この内容で入れてよい」。D2' の選びが既定と違えば、このビルドに入っている（後から替えたときは §9.4） |
| D4 | 本人の言葉の後 | 本人の確かめ表が全部 ○ にそろい（Duo の行は「—」）、「1.4.2 を審査に提出して良い」をもらい、確かめた commit とのコードの差が空なら、Connect に版を作って提出（手動公開）。**`submit142.py check` が READY**（ビルド VALID、16 ロケール、審査メモ、写真の引き継ぎ、年齢区分 4+・新しい問い 0）。新しい問いが出たら止めて本人に聞く（答えは本人の言葉、§0.4） | 3 つがそろい、check が READY |
| D5 | 審査の後 | 審査が通り、「1.4.2 を公開して良い」「まとめて良い」の後に公開 → 公開の日に SUPPORT を Web へ → main へ `--no-ff` → main の CI を見て、**run の番号と結果を `docs/R1_4_2.md` に書く** → 本人の手元の main を `pull --ff-only` | main の CI の run の番号と結果が記録にある |
| 前ぶれ | 12/12 | D3 が渡せていなければ本人に知らせる | — |
| 決まり | 12/18 | 年末の前の最後の提出日の目安。過ぎたら 1/5〜 | — |

**D0 の関門**（全部そろって D1 へ。R1_4_1_CONTRACT §9.1 の関門 1〜8 を、基準のビルド fbd1f7a と基準の run #4 に読み替えた）:
1. 全部のジョブが緑で、数が run #4 と同じ（S0 で `docs/R1_4_2.md` に書いた数）: KitChecks 40,826（閾値 40,776）、単体 900（飛ばし 2・失敗 0）、同期の繰り返し 4,000、UI tests (iPhone) 71（飛ばし 19・失敗 0）、`PaletteMoveUITests` 3 本、compat-v1.0（compat10 599・span-compat 274/274/278/310・`Real13LedgerTests` 5/5）、l10n-shots・blank-paper・span-shots-app と言語の写真・palette-shots 22 行の数。`DATA_1_1`・`TESTS_1_3`・`TESTS_1_2_3`・`FIXTURES_1_3`・新しい `TESTS_1_4_1` の段も緑。
2. 保存のバイト（§5.7 の 3 つ）が作り直さずに同じ。
3. 関門 3（§7.2）が run #4 と同じ。
4. J-4: 強い差は `ipad13-portrait-sheet-info.png` の版の字だけ。
5. D0 の木の `Sources`・`TegakiKit/Sources`・`Tests` が fbd1f7a と同じ（`git diff fbd1f7a -- Sources TegakiKit/Sources Tests` が空）。
6. env.txt が Xcode 27.2（27B52）・XcodeGen 2.46.0・iOS 27.2（24B8117）。実行環境の版を書く。
7. 速い道（`r142-quick`・`r142-q-*`・`r142-w-*`）で速い道の組だけが走る（1 回）。
8. duo.yml が `r142-duo*` で起きる（D1c の前に 1 回。合否は D1c で読む）。

**実行機の揺れの読み方**（1.4.1 の run #4 のリードの決定と同じ形、`docs/R1_4_1.md` の「P2〜P5」）: 落ちた段は `--failed` で attempt 3 まで回し直す。落ちたテストが attempt ごとに違い、どれも別の attempt か前の run で通っているなら、実行機の重さによる揺れとしてコードを変えない。同じテストが 2 回続けて同じ形で落ちたら、本当の落ちとして直す。打ち切り（renewjob timed out・load average の cancelled）は数えない。

- 作業の木はスクラッチパッドにあり、毎日 0:00 の掃除で古いファイルが消えうる（worktree の `.git` も消えたことがある）。こまめに commit し、リードが `r142` を GitHub に上げて控えを残す。消えたら `git worktree repair` で戻す。
- Claude の週の使える量が 95% に届いたら、その週は止まる。進み具合を `docs/R1_4_2.md` に残す。

### 9.2 規模

| 部分 | 里程 | 元 |
| --- | --- | --- |
| D0（CI の配線・基準・版・守りの表） | 0.05 | 1.4.1 の D0 の実績 |
| ペンの色（12 色・丸の記憶・関門・板・閉じ方・その他の色・戻す・置き場所・縁・VoiceOver・写真モード）とテスト | 0.5〜0.65 | 計画の約 0.6 週（0.4 里程）に、自前の重ねと窓の観測者・画面のつなぎ・UI テストの切り離しの分を足した【推定】 |
| メモ欄の紙（型・設定・PaperView の性質と知らせ・3 か所・写真モード）とテスト | 0.2〜0.3 | 計画の約 0.2〜0.3 里程に、つないだ紙の道と描き直しのテストの分 |
| 互換の色の線・変異・Duo | 0.05〜0.1 | 1.4.1 の実績 |
| 訳・店の文・SUPPORT・写真・確認ページ | 0.2〜0.25 | 1.4.1 の実績 |
| **合計** | **1.0〜1.35** | 1 里程 ≈ 1.5 週だが、1.3〜1.4.1 の実績はずっと速い。**目安 2 週**。日程は CI（1 回 75〜95 分、同時の上限 5）と本人の確かめが律速 |

### 9.3 役

| 役 | 仕事 | 持ち物 |
| --- | --- | --- |
| C | CI・版・J-4 の基準・道の配線・守りの表・写真の段・`ink_ref_xcui`・compat10 の色の線 | §2 の C の行 |
| T | ツールバーの部品: `ToolbarLogic`・`ToolbarView`・`ColorPanelView`（板・観測者・色選び）・その単体テスト | §2 の T の行 |
| S | 画面と設定のつなぎ: `CalendarRootScreen`・`SettingsScreen`・`MemoPaperSettingsSection`・`AppSettings`・`ScreenshotMode`・その単体テスト | §2 の S の行 |
| M | 紙: `MemoPaperStyle`・`PaperView`・`MonthPaper`・`DayPaper`・`FreeMemoPaper`・`WeekPaper` の注・`PaperText`・その単体テスト | §2 の M の行 |
| U | UI テスト（`ColorPanelUITests`・`ColorPanelPadUITests`・`MemoPaperUITests`・`MemoPaperShotsUITests`・`PaletteShotsUITests` と `LanguageUITests` の行・`EraserAndBelowDayUITests` の 1 行） | §2 の U の行 |
| X・R | 訳・元を見ない逆翻訳・GLOSSARY・REVIEW | `tools/l10n/`・`docs/i18n/` |
| A・W | 新機能の文・審査メモ・SUPPORT | `docs/store/`・`docs/SUPPORT*.md` |
| リード | 順番・確かめ・`docs/R1_4_2.md`・Connect・確認ページ・本人への知らせ | — |

- 作る役の枝は `r142-w-<名前>`（速い道。§6.5）。作る役は push しない。リードがまとめの枝へ取り込んでから上げる。

### 9.4 出し方（本人の言葉が要る所。一覧は §0.4）

| 順 | だれ | すること | 本人の言葉 |
| --- | --- | --- | --- |
| 1 | 各役 | この契約のとおりに作り、`r142` に commit | 不要 |
| 2 | リード | `r142` を GitHub に上げ、CI が全部緑 | 不要 |
| 3 | リード | 確認ページ（§9.1 の D3。点の写真と 12 色の見本は、その前に D2' で先に送る） | 「**この内容で入れてよい**」（点の選び・12 色の替えは D2' の答え。答えが無ければ既定） |
| 4 | リード | testflight.yml を確かめた commit から走らせ、TestFlight 1.4.2 を内部のテストに配る。確かめ表（§10）を番号付きで渡す（3 と同時でよい） | 不要 |
| 5 | 本人 | 確かめ表 | 「全部○」か × の所 |
| 6 | 本人 → リード | 提出のお願い | 「**1.4.2 を審査に提出して良い**」 |
| 7 | リード | `git diff <確かめた commit> -- Sources TegakiKit Tests tools .github project.yml` が空を確かめ、Connect に版 1.4.2 を作り、16 ロケールの新機能の文・プロモーションテキスト・審査メモ・ビルドを入れて読み戻す。手動公開で提出 | — |
| 8 | 本人 → リード | 審査に通ったら公開。同じお願いで、main へまとめてよいか | 「**1.4.2 を公開して良い**」と「**まとめて良い**」 |
| 9 | リード | 公開の日に Web の SUPPORT 2 ページ、日本の App Store の表示が 1.4.2 になったことを記録。`r142` を main へ `--no-ff`、main の CI を見て run の番号と結果を書く。本人の手元の main を `pull --ff-only` | — |

- **本人の言葉の受け方**: 本人の言葉は、そのまま・時刻つきで `docs/R1_4_2.md` の「本人の言葉と選び」に写す。全角の数字や空白の違いは同じ言葉と読み、道具の `--owner` には決まった形を渡す（1.4.1 では本人が全角で「１.４.１を審査に提出して良い」と書き、リードが読み替えた、`docs/R1_4_1.md:397`・:642）。言葉はチャットの本人の発言からだけ取る。
- 公開は、本人の確かめ（5）と本人の言葉（8）の後だけ。言葉は前もってもらってもよい。**本人が自分の端末で確かめていない版は出さない**。
- × が出たら、直してビルドし直し、確かめ表の触れた行（下の決め方）と行 1 をやり直してもらう（提出の後なら審査から取り下げる）。
- **本人が既定と違う形を選んだとき、やり直してもらう確かめ表の行**（新しいビルドの番号で表を渡し直し、その行の答えがそろってから提出・公開する。ほかの行の答えは前のビルドの物を使う。D3 のビルドより前に答えをもらえれば、表は新しいビルドで 1 回で済む）: いつも行 1（版）。ほかは:
  - 点の見た目 (b)・(c): 行 14〜17。
  - 12 色の替え: 行 1・行 2（板の見た目）と、替えた色の名前が出る行（茶 2・3・4・13、紺 7・8・9、水色 11、深緑 12。グレー・ピンクの替えは行 1・2 だけ）。行の字はそのとき書き直して渡す。黄土色・えんじなど今のキーに無い色は、新しいキーと 9 言語の訳・元を見ない逆翻訳・判定と D2 の関門・V のやり直しになり、日が数日のびる（§7.4）。
  - 長押しの替え（やめる・どの丸でも）: 行 1・4・12。
  - 11/7 の既定（§0.5）を変えるお答え（作る範囲が変わるので、そのとき契約を直して行を決める）:
    - マーカーの色も増やす（既定は 4 色のまま。足すなら淡いオレンジ・淡い紫・淡いグレーの 3 色）。
    - 替えた丸の色を iPad と iPhone でそろえる（既定はそろえない。iCloud の新しい仕組みが要り、手間が 0.5 週ほど増える）。
    - 初めて使う人に「もう一度押すと色を替えられます」と画面で 1 回知らせる（既定は知らせない。新機能の文とサポートページで知らせる）。
    - メモ欄の紙を、月・日・週のメモ欄ごとに別々に選べるようにする（既定は 1 つの設定）。
    - 方眼（線のマス目）も足す（既定は足さない）。
  - 直しが凍結のファイルや保存・同期に触れたときは、全部の行。

**うまくいかなかったとき**:

| 起きたこと | すること |
| --- | --- |
| 1.4.2 が審査で断られた | 指摘を `docs/R1_4_2.md` に写す。文・審査メモだけで直せる（コードの差が空）なら、直した文を確認ページで見せて「この内容で入れてよい」をもらい直す。コードを直すなら、触れた所の D1〜D2 の関門をやり直し、新しいビルドを TestFlight へ、確かめ表の触れた行をやり直してもらう。どちらも、出し直しの前に「1.4.2 を審査に提出して良い」をもう一度もらう。前にもらった公開の言葉は使わない |
| 確かめた後に main が動いた（1.4.1 の直しの版などで） | 提出しない。基準（J-4 のファイル・関門 3 の run）を新しい main の公開したビルドとその通しの run に替え、`r142` で D0 の関門から通しの run をやり直す。新しいビルドで確かめ表を全部やり直してもらう |
| 公開の後に重い不具合が見つかった | App Store では前の版に戻せない。直した版をできるだけ早く出す（版の番号は 1.4.3。月と年の版は後ろへ送り、M7_PLAN §4 を直す）。流れは同じ。回り道（あれば）を本人に知らせる |

---

## 10. 本人の確かめ表（TestFlight 1.4.2）

**対象の版: 1.4.2（TestFlight のビルド 32 以上。番号は Claude が渡すときに書きます）**。この表は、ビルドが本人の端末に届いた後に、番号を書いて改めて渡します。**上から順に**試して、○ か × を付けてください（前の行の終わりの形が、次の行の始まりになるように並べました）。× のときは画面の写真を送ってください。

**準備**:
- 全部の端末（iPad Pro 13・iPad Air 11・iPad mini・iPhone 18 Pro Max）に、TestFlight で 1.4.2 を入れてください。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（無料）。**「全て消す」と Apple アカウントの切り替えはお願いしません。** iPhone Duo の行は「—」にしてください。
- 始める前の形（4 台とも）:
  - 端末の画面表示は「ライト」。
  - ツールバーは**開いて下**。丸ボタンだけ（しまってある）なら、丸ボタンを**長押し**して「ツールバーをいつも出す」を押してください（ツールバーが開いたまま残ります。丸ボタンの ↶ は「元に戻す」です）。iPad で、開いたツールバーが上・左・右にあれば「動かす」→「下へ移す」。
  - ペンは 黒・中（「ペン」を押し、黒の丸が光っていなければ黒の丸を押し、「中」を押す。光っている丸を押すと色の板が開くので、開いたら画面の上の見出しの何もない所に触れて閉じてください）。
  - 設定 › メモ欄の紙 は「罫線」（最初のまま）。利き手はどちらでも構いません。
  - 設定 › 消しゴムで消したらペンに戻る は「オン」（最初のまま）。iPad の「指でも書く」は「オフ」（iPhone は行 12 のとおり）。
  - （この準備の字は、確認ページの最初の画面にも同じ字で書きます。）
- 行 2〜9 は iPad Pro 13 で続けて試します。

| # | 端末 | すること（1 文目は始まりの形） | こうなれば合格 |
| --- | --- | --- | --- |
| 1 | 全部 | 設定 › 情報 で「バージョン」を見る | 1.4.2（Claude が知らせた番号） |
| 2 | iPad Pro 13 | ツールバーは下に開いていて、ペンは黒。**Apple Pencil で**、光っている黒の丸をもう一度押す。出た板を見てから「茶」を押す。紙に書く | 黒の丸のそばに小さな板が出る（上に 12 色、下に「その他の色…」と「最初の色に戻す」）。茶を押すと板が閉じ、いちばん左の丸が茶になって光る。茶で書ける |
| 3 | iPad Pro 13 | 茶の丸が光っている。Pencil で茶の丸を押して板を開く。色を選ばずに、Pencil で紙に線を 1 本書く。もう一度板を開き、今度は**指で**、画面の上の見出しの何もない所に触れる | 書き始めると板が閉じ、その線も書ける（最初の線が消えない）。指で触れても板が閉じる |
| 4 | iPad Pro 13 | 茶の丸が光っていて、板は閉じている。**指で**茶の丸を 1 秒ほど押したままにする（長押し）。開いた板の「その他の色…」を押し、出た色選びの画面のスポイトで紙の上の色（書いた茶の線など）を拾い、続けて好きな色を選び、画面の × で閉じる。歯車を押して設定が開くのを見て、設定を閉じる。紙に書く。次に 2 つ目の青の丸を押し、またいちばん左の丸を押す | 長押しで板が開く。色選びの画面が開き、スポイトで紙の上の色を拾える（拾うとその色が選ばれる）。閉じるといちばん左の丸が最後に選んだ色になって光る。歯車で設定が開く。その色で書ける。青といちばん左の丸を行き来できる（左の丸を押しても、光っていないときは板は開かず、選ぶだけ） |
| 5 | iPad Pro 13 | いちばん左の丸（行 4 の色）が光っている。ツールバーの消しゴムで線を 1 本消す。次に Apple Pencil を 2 回たたいて消しゴムにし、もう一度 2 回たたく（Pencil の設定が「現在のツールと消しゴムの切り替え」のとき。違う設定なら後半は「—」） | 消した後、ペンは行 4 の色で戻る。2 回たたいても同じ色に戻る |
| 6 | iPad Pro 13 | ツールバーは下に開いている。「動かす」→「左へ移す」。縦のツールバーで光っている丸を指で押す。板の外（画面の上の見出しの何もない所）に指で触れて閉じる。同じことを「右へ移す」「上へ移す」でもする。最後に「動かす」→「下へ移す」 | 左では板が丸の右に、右では丸の左に、上では丸の下に出る。どれも画面からはみ出さない。外に触れると閉じる |
| 7 | iPad Pro 13 | ツールバーは下に開いている。「しまう」を押す。丸ボタンの**道具の印**を**指で**押し、出たツールバーで光っている丸（いちばん左）を**指で**押す。板で「紺」を**指で**押す。**Pencil で**紙に書く | 出たツールバーからも板が開く。いちばん左の丸が紺に替わる。書き始めるとツールバーはまたしまい、紺の線が書ける |
| 8 | iPad Pro 13 | ツールバーはしまってある。アプリを完全に閉じて開き直す（下の端から上へゆっくり指を動かして止め、てがきカレンダーの絵を上へ払う）。丸ボタンの道具の印を押し、出たツールバーで紺の丸を押して板を開き、「紫」を押す。出たツールバーの「しまう」を押す。丸ボタンを長押しして「ツールバーをいつも出す」を押す | 開き直しても、いちばん左の丸は紺で、ペンは紺で始まる（丸ボタンの色の点も紺）。紫は 6 つ目の丸にもうあるので、6 つ目の紫の丸が光り、いちばん左は紺のまま（同じ色の丸は 2 つにならない）。ツールバーは下に開いたまま残る |
| 9 | iPad Pro 13 | ツールバーは下に開いていて、6 つ目の紫が光っている。いちばん左の紺の丸を押して選び、もう一度押して板を開き、「最初の色に戻す」を押す。紙に書く | 6 つの丸が 黒・青・赤・緑・オレンジ・紫 に戻り、いちばん左の黒が光る。黒で書ける |
| 10 | iPad Air 11 | ツールバーは下に開いていて、ペンは黒。端末の 設定 › 画面表示と明るさ で「ダーク」にしてアプリに戻る。ペンの 6 つの丸を見る。光っている丸を押して板を開いて見る。見終わったら板の外に触れて閉じ、端末を「ライト」に戻す | ダークでも黒・紫の丸の縁が見え、背景に溶けない。板の色見本は白い紙の色の上に並ぶ |
| 11 | iPad mini | ツールバーは下に開いていて、ペンは黒。「動かす」→「左へ移す」。縦のツールバーで光っている黒の丸を **Pencil で**押し、「水色」を押して書く。「動かす」→「下へ移す」。水色の丸を押して板を開き、「最初の色に戻す」 | 板は丸の右に出て、画面に収まる。水色で書ける。戻すと黒 |
| 12 | iPhone 18 Pro Max | ツールバーは下、ペンは黒。光っている黒の丸を指で押す。「深緑」を押して、紙に指で書く（書けないときは、ツールバーの「指でも書く」をオンに）。次に深緑の丸を長押しして板を開き、ツールバーを指で横に動かす（スクロール）。最後に深緑の丸を押して板を開き、「最初の色に戻す」 | 小さな板がツールバーの上に出て、画面からはみ出さない。深緑で書ける。長押しでも開き、ツールバーを動かすと閉じる。戻すと、いちばん左の丸が黒に戻り、ペンも黒 |
| 13 | iPad Pro 13 と iPhone | iPad Pro 13 のペンは黒。Pro 13 で光っている黒の丸を押して「茶」を選び、週のページに茶で 1 本書く。iPhone で同じ週を開く。Pro 13 でその週を PDF にする | iPhone にも茶の線が届く（上の印は「保存済み」）。PDF でも茶 |
| 14 | iPad Pro 13 | 設定 › メモ欄の紙 は罫線。設定 › メモ欄の紙 › ドット方眼 を選んで設定を閉じる。月のページの下のメモ欄、日のページの右の「メモ」と 24 時の下の「自由メモ」、週のページの 24 時の下の「自由メモ」を順に見る。横につながった週と日で、ページの境目も見る | 罫線があった所に点が並ぶ。点は罫線と同じ高さで、横も同じ間隔。境目でも点の間隔はそろう。今までの手書きは同じ場所にある。「メモ」「自由メモ」の字と区切りの線は残る |
| 15 | iPad Pro 13 | ドット方眼のまま。月のメモ欄に 1 行書いてから、その月を PDF にする。次に、アプリを完全に閉じて開き直し（行 8 と同じやり方）、月のメモ欄を見る | PDF のメモ欄にも点が出る。開き直してもドット方眼のまま |
| 16 | iPhone と iPad Pro 13 | Pro 13 はドット方眼、iPhone は罫線のまま。iPhone で月のメモ欄を見る。iPhone で 設定 › メモ欄の紙 › 無地 にして、月と日のメモ欄を見る。Pro 13 の月のメモ欄を見る | iPhone は、替える前は罫線のまま（端末ごと）。無地では線も点も無く、「メモ」の字と区切りの線は残る。Pro 13 はドット方眼のまま |
| 17 | iPad Pro 13 と iPhone | Pro 13 はドット方眼、iPhone は無地。両方で 設定 › メモ欄の紙 › 罫線 に戻す（その後で、お好きな柄にしても構いません） | 前と同じ見た目に戻る。手書きは同じ場所 |
| 18 | iPad Air 11 と iPhone | 1.4.1 の確かめのくり返し。ツールバーは下。iPad で「動かす」→「右へ移す」→「下へ移す」。週のページで等倍（虫めがねに「1」）を押す。iPhone でも週の等倍を押す | 1.4.1 と同じ動き（右の端で縦に立ち、下に戻る。1 週の幅が画面にちょうど合う） |
| 19 | どれか 1 台 | 機内モードにして書く → 機内モードを切る。アプリを完全に閉じて開き直し（行 8 と同じやり方）、手書きのあるページ（月・週・日・年）を順に開く | 書いている間は「オフライン」、戻すと「保存済み」。開き直しても書いた線が全部見える。一部の線が欠けて見えるときは、そのページの写真を送ってください |
| 20 | iPhone Duo | — | 「—」（Duo はお持ちでないので、自動の確かめだけで見ます） |

- 確認ページで点の見た目 (b)・(c) や 12 色の替えを選んだときは、新しいビルドの番号で、§9.4 の行をやり直してもらいます。
- 試し終わった後の色の丸とメモ欄の紙は、お好きな形のまま使って構いません。

---

## 11. 危険と減らし方

| 危険 | 減らし方 |
| --- | --- |
| 自前の板の場所が、置き場所（下・上・左・右・のぞき・iPhone のスクロールしたバー）のどこかで狂う。Sources に PreferenceKey の前例が無い | 場所は純粋な関数で、7 つの形を表で固める（§3.8）。palette-shots の写真（§7.3）と iPad の UI テスト（板の枠とバーの枠）で見る。確かめ表の行 6・7・11・12 |
| 窓の観測者（ColorPanelWatch）が触れの位置を読み違える、または iPhone の窓で触れに影響する（PalmWatch は iPad の窓だけで確かめた） | 凍結の `InkTouchObserver` をそのまま使い、何も止めない形（1.1 からキャンバスで、1.4.1 から iPad の窓で使う）。板が開いている間だけ付ける。位置が確かでなければ小さな新しい型にしてよい（§3.6）。UI テストと確かめ表の行 3 |
| 光っている丸を押すと板が開くようになり、今の UI テストの「赤」「黒」の押しが板を開く | UI テストは板を閉じてから次を押し、丸は identifier で探す（§3.4 の理由 2・§3.10。板は `.isModal` なので、開いている間は外の要素が検索から消えうる）。`restoreDefaultPen` は光っていないときだけ押す（§6.2）。写真モードでは丸を書かず、次のテストへ漏らさない（§3.11） |
| 色選びの画面（UIColorPickerViewController）をシートで包んだときの × の動きや、`continuously` の届き方が iOS 17 と 27 で違う【未確認】。× で閉じても `colorPickerShown` が true のまま残り、`sheetIsUp` が戻らず、アカウントの問い・年齢確認などがずっと出ない。シートの子ではスポイトが効かない | 決める規則を純粋な関数にし（`commitsPick`）、閉じたときにも最後の候補で決める。`colorPickerViewControllerDidFinish` と `onDismiss` で必ず後始末（§3.7）。UI テストは画面が出て閉じ、その後に歯車で設定が開くことを見る。D1b で起きたら UIKit の present に替える（§3.7）。本人の確かめ表の行 4（スポイトも） |
| 光っている丸の上から始めたスクロールで板が閉じない（凍結の観測者は down と up だけを知らせる） | 光っている丸の枠が動いたら閉じる（`closesOnAnchorMove`、§3.6）。`ColorPanelLogicTests`・MC8・`ColorPanelUITests`（丸の上からバーを引く）。確かめ表の行 12 |
| `penDown()` で閉じると、Pencil のホバーの Begin で、触れる前に板が閉じる | `penDown()` では閉じない。本当の触れは ColorPanelWatch が閉じる（§3.6） |
| 閉じる処理を 1.4.1 の関数の本体に書き、守りの表のテスト（`PaletteMoveButtonTests.swift:509-537`）が落ちる | 閉じる処理は新しい `.onChange` だけ（§3.6）。`colorPanel:` は `axis:` の前（§2.1、0f-36）。`ColorPanelWiringTests` で本体に板の字が無いことを確かめる |
| 保存したメモ欄の紙を、次に開いたときに読む道を、どの自動の確かめも通らない（写真モードもテストのホストも保存した値を読まない） | `prepareAtLaunch` に `testHost:` の引数を足し、`MemoPaperStyleTests` で `testHost: false` の枝を確かめる（§4.1、MM4）。確かめ表の行 15 で開き直す |
| 本人が 12 色を替える（とくに今のキーに無い色） | 見本を TestFlight より前に送る（D2'）。新しいキーの訳・逆翻訳・判定と D2 の関門・V のやり直しで日が数日のびることを §0.4 で伝えた。SUPPORT と新機能の文は色の名前を書かない（§8.3・§8.5） |
| Display P3 の色で、書いている間と開き直した後の色がずれる | 受けた色はすぐ凍結の `hex(of:)` で sRGB の hex にし、その字からペンを作る（§3.7）。`InkColorRoundTripTests` |
| ダークの縁の直しで、ライトの画素まで 1 段ずれて J-4 のほぼ全部が変わる | ライトの式は今と同じ字のまま、動的な UIColor にしない（§3.9）。J-4 で「ツールバーは同じ」を示す（§7.1） |
| ダークの直しを写真で見せられない（CI のどの写真もライト） | palette-shots の最後にダークの 2 枚（§7.3）。確かめ表の行 10 |
| つないだ週と日（1.3 からの既定）で紙の柄が変わらない、または設定を替えても描き直されない | 柄は PaperView の性質と知らせで届ける（§4.3）。`MemoPaperRedrawTests` でつないだ窓の描き直しを確かめる。確かめ表の行 14 |
| 罫線の描き方を変えて、凍結の画素のテスト（`PaperViewTests`・`WeekMemoPaperSpanTests` の 1.2.3 と同じ画素）や J-4 のメモの写真が落ちる | 罫線の枝は今の字のまま、共通の部品にまとめない（§4.4）。写真モードは罫線に固定 |
| 手元のシミュレータに残った「ドット」や、テストの間で漏れた `current` で、凍結の画素のテストが落ちる | テストのホストでは保存した柄を読まない（§4.1）。新しいテストは使い捨ての suite と tearDown で戻す。CI のシミュレータは毎回新しい |
| `PaperView` の init で描き直しを頼み、凍結の `PaperViewTests` の数が変わる | init では頼まない、`super.init` の前に値を入れる（§4.3）。`MemoPaperRedrawTests` の 1 つ目 |
| ドットが見えにくい・濃すぎる。iPad Pro 13 の拡大（点の間が約 70 pt）と iPhone の月の一覧（約 16 pt）で見え方が大きく違う | 画面で同じ大きさにし、本人に 3 通りの写真で選んでもらう（§4.5・§7.4）。確かめ表の行 14〜16 |
| ドットの数で描くのが重い、PDF が大きくなる | 1 つのパスで 1 回、x と y で絞る。時間とバイト数を計って記録（§4.6） |
| 設定の新しい節で、設定のシートの写真が宣言していない所で変わる（1.4.1 で起きた） | §7.1 で sheet-sync・sheet-settings・店の 06 を前もって宣言。強い差が出たら止める |
| 板の字（「その他の色…」「最初の色に戻す」）がドイツ語などで板に入らない | `ColorPanelFitTests` で 10 の言語を測る。l10n-shots で de・fr・疑似の言語の板を見る |
| 青・水色・紺、緑・深緑が見分けにくい。言語によっては名前の言い分けがあいまい | 12 色の見本を確認ページで見せ、替えを言葉でもらう（§0.4）。GLOSSARY で言い分けを先に決める（§8.2） |
| 2 つの丸に「その他の色」を入れると、読み上げも UI テストのラベルも区別できない | 読み上げは計画どおり（§0.6 で伝えた）。UI テストは identifier（`toolbar.swatch.<i>`）で探す |
| 長押しと iPhone のツールバーの横スクロールがぶつかる | 長押しは光っている丸だけ。板の外から始めたスクロールは ColorPanelWatch が閉じ、光っている丸の上から始めたスクロールは丸の枠が動いて閉じる（§3.6）。確かめ表の行 12 |
| 1.4.1 で直したツールバー・画面のコードに触れて、1.4.1 の動き（辺・つまみ・「動かす」・等倍・利き手）を壊す | 1.4.1 のテストを新しい守りの表 `TESTS_1_4_1` に入れる（§5.5）。画面の字の守り（§5.6）。確かめ表の行 18 |
| 実行機の重さで打ち切りや UI テストの揺れが出て、run が半日に延びる（1.4.1 ではほぼ毎回） | 通しの run を 2 つ同時に走らせない。作る役の枝は速い道（`r142-w-*`）。揺れの読み方を決めておく（§9.1） |
| 同じ UTC の日の J-4 が組めない（日をまたぐ・環境の版が入れ替わる） | 2 つの日の基準の両方で比べる。ja-baseline と回し直しの時刻をそろえる（1.4.1 と同じ） |
| run #4 の成果物が 11/30 ごろ消え、関門 3 の基準と前の写真を失う | S0' で D0 の前に控える（§7.6） |
| 審査メモが 4,000 バイトを超える | 1.4.1 の段と入れ替え、超えたら英語の 1 を短くする（§8.4） |
| Connect と確認ページの道具が 1.4.1 の字に結び付いていて、移すと古い guard で止まるか、違う字を書く | 道具は段 T0 で 142 用に移し、元の文の字の guard を 1.4.2 の字と承認した commit に直す（0f-35、§9.1）。偽の Connect の試験を通してから使う。契約が T0 の後に変わったら、道具も直して試験をやり直す。ビルド N と commit を結ぶ道具は無いので、確かめ表の行 1 と段 V の「確かめた commit」がその代わり |
| 年末: 12/19〜1/4 は審査が遅れることがある【未確認】 | 12/18 の目安と 12/12 の前ぶれ（§9.1） |
| 作業の木が夜中の掃除で消える | こまめに commit、リードが GitHub に上げる、`worktree repair` |

---

## 12. 決めどころ（既定と理由。番号は 0f-n）

| # | 決めどころ | 既定 | 理由（参照） |
| --- | --- | --- | --- |
| 0f-1 | 版・枝・番号 | **1.4.2**（`project.yml:23`）、ビルド 32 以上。枝 `r142`（main 2e3ee75 から。コードは fbd1f7a と同じ）。契約はこの文書、結果と前もっての宣言は `docs/R1_4_2.md` | 1.4.1 は公開済みで、Connect は大きくなる版を求める。1.4.1 が 29〜31 を使った（`docs/R1_4_1.md:618`、`testflight.yml:295`） |
| 0f-2 | 「次の版」との順 | **1.4.2 が先**。月と年の横スクロールと幅の等倍は、その次。番号と中身はその版の契約で決め、1.7・1.8（月・年の横つなぎ）と一緒に設計する | 1.4.2 は 11/7 に本人の決めがそろい、小さく、保存の形を変えない。月と年の横スクロールは横つなぎの土台と重なる（`docs/M7_PLAN.md` §4 の「次の版」の行・:526） |
| 0f-3 | 時期 | 12/18 より前の提出をねらう（§9.1）。M7_PLAN §4 の「2027 年 3 月末〜4 月上旬」はリードが記録の段で直す | 前倒しの決まり（11/8）。年末の審査の遅れ（R1_4_1_CONTRACT §0.3） |
| 0f-4 | 範囲 | 2 つのご依頼（計画 §1〜§4 のとおり）、縦のツールバーとのぞきからも板、ダークの縁、0e-32 の訳者向けの説明と `ink_ref_xcui` の見出しの帯 | 計画 §2 に縁の直しがある。R1_4_1_CONTRACT §1.4・§18.1 の申し送り。1.4.1 の 0e-32 が「次の版で直す」と約束した |
| 0f-5 | 範囲外 | §1.4 の一覧 | どれも本人の言葉の外か、凍結のファイルに触れる（`Ink/PencilInteraction.swift:24-34`、`InkLedger.swift`） |
| 0f-6 | 12 色の表 | `penColors` の 6 色は変えず、新しい `panelColors` に足す 6 色（茶 #92400e・グレー #6b7280・ピンク #db2777・水色 #0284c7・深緑 #166534・紺 #1e40af）。ピンク・水色は今の名前を使う | 計画 §5.2 の色と名前。コントラストは 4.0〜8.6【計算】。`penColors` を変えないので 6 つの丸の前提とテストがそのまま（`ToolbarView.swift:596-610`、`ToolbarFitTests.swift:67`・:161-166） |
| 0f-7 | 6 つの丸の記憶 | 鍵 `toolbar.penSlots`、String（カンマでつなぐ）、端末ごと、iCloud に送らない。壊れた字・6 つでない・重複は §3.2 の規則で直す。丸の `ForEach` の id は添字 | `@AppStorage` は配列を持てない。`id: \.hex` は重複でぶつかる（`ToolbarView.swift:248`・:460）。Q5 の既定（端末ごと） |
| 0f-8 | 入口の関門と名前 | `pen(colorHex:width:slots:)`、`rememberedPen` は丸も読む、丸に無い色は丸 1。`colorName` は 12 色 → マーカー → その他の色 | 今の関門は表に無い色を黒に戻す（`ToolbarLogic.swift:640-648`）。計画 §5.1 の「中心の変更」 |
| 0f-9 | 開き方 | 光っている丸を押す（もう一度で閉じる）、光っている丸の長押し。VoiceOver の操作とヒント。マーカーでは開かない。閲覧専用でも開く | 計画 §2（本人が読んだ所）の字。どの丸でも長押し（§5.2）は手のひらで色が替わるおそれ（§3.5） |
| 0f-10 | 板の作り | 自前の重ねた板（画面のいちばん上の重ね。anchorPreference）。吹き出し（`.popover`）にしない | 最初の線を守る・今の UI テストを止めない・シートとぶつからない・縦のバーで向きが確か（§3.4） |
| 0f-11 | 閉じ方 | 板が開いている間だけ窓に凍結の `InkTouchObserver` の新しいインスタンス（ColorPanelWatch、`@State`）。外の触れで閉じ、触れは止めない。画面の事（シート・背面・窓・ツールバーの形・道具・光っている丸が動いた）でも閉じ、閉じる処理は新しい `.onChange` だけに書く。**`penDown()` では閉じない**（第 2 版）。VoiceOver は modal と escape | 計画 §2 の「紙にペンや書く指が触れたとき、板の外を押したとき」を、線を消さずに満たす。PalmWatch と同じ形（`PaletteGrip.swift:272-372`、`CalendarRootScreen.swift:252`・:3712-3716）。`penDown()` は Pencil のホバーでも来る（:1199-1200）。観測者は動きを知らせない（`InkTouchObserver.swift:21-24`）。1.4.1 の関数の本体は守りのテストが字を読む（`PaletteMoveButtonTests.swift:509-535`） |
| 0f-12 | 選んだとき | 板を開いた丸に入れる。ほかの丸にある色なら丸は変えずにその色を選ぶ。太さはそのまま、板は閉じる | 計画 §5.2「重複を作らない」 |
| 0f-13 | 「その他の色…」 | 画面の `.sheet` で `UIColorPickerViewController`（`supportsAlpha = false`、題はシステムの既定）。丸は画面の `colorPickerSlot` に持つ。決めるのは `continuously == false` と閉じたとき。すぐ sRGB の hex にして、その字で選ぶ。`sheetIsUp` に数え、`colorPickerViewControllerDidFinish` と `onDismiss` で必ず戻す。D1b で `sheetIsUp` が戻らない・スポイトが効かないなら、UIKit の present（iPad は popover、iPhone は pageSheet）に替える | 引いている間に書かない。P3 の色のずれを防ぐ（`InkTools.swift:202-217`）。アカウントの問いなどを待たせる（`CalendarRootScreen.swift:731-734`・:2571-2590） |
| 0f-14 | 「最初の色に戻す」 | 丸を最初の 6 色に。ペンは同じ位置の最初の色（太さはそのまま） | 光る丸・「ペン」ボタン・書ける色をいつも同じにする（調べ役の危険の指摘） |
| 0f-15 | 置き場所 | 純粋な `placement`。辺ごとに丸の外側 8 pt、画面の内側 8 pt に寄せる。縦のバー・のぞき・iPhone で同じ規則。回転と窓の大きさで閉じる | R1_4_1_CONTRACT §1.4・§18.1。のぞきは今の辺（0e-20） |
| 0f-16 | ダークの縁 | `colorScheme` で分け、ライトは今の字 `Color.black.opacity(0.15)`、ダークは `Color.white.opacity(0.35)`。横と縦の 2 か所。動的な UIColor にしない | ライトの画素を 1.4.1 と同じに保ち、J-4 で示す（`ToolbarView.swift:293`・:488） |
| 0f-17 | VoiceOver と identifier | §3.10。「その他の色」に番号を付けない。identifier `toolbar.swatch.<i>`・`toolbar.colorPanel*` | 計画 §2 の読み上げの約束。新しい文を増やさない |
| 0f-18 | 写真モード（色） | `--screenshot-color-panel`・`--screenshot-pen-slots`。写真モードでは丸を読まず書かない。`toolbar.penColor` は今のまま。`Sheet` を足さない | UI テストの漏れを防ぐ（`EraserAndBelowDayUITests.swift:648`）。凍結の数（`ScreenshotModeTests.swift:302-303`） |
| 0f-19 | メモ欄の紙の型と鍵 | `MemoPaperStyle`（ruled・dots・plain）、鍵 `paper.memoStyle`、`current`、写真モードとテストのホストは保存を読まない。`prepareAtLaunch` は `testHost:` を引数に持ち（既定 `SyncEngine.isTestHost`）、単体テストで保存した値の枝を試す | 前例 `WeekStartChoice.current`・`HolidayChoice.current`。凍結の画素のテストを手元の古い値から守る（`SyncEngine.swift:32-39`）。単体テストの中では `isTestHost` がいつも真で、保存した値の枝にどの確かめも届かない（1.4.1 §18.1 と同じ形） |
| 0f-20 | 設定の置き場所と形 | `inputSections` の最初の要素（見た目は「祝日」のすぐ下）。`.navigationLink` の Picker、見出し無し、脚注。identifier `settings.memoPaper` | 計画 §2 の「祝日の下」と「週の始まりと同じ形」。凍結の `SettingsPageSectionTests.swift:127-128`（9 つ）を守る。1.4.1 の利き手と同じ考え |
| 0f-21 | 紙への届け方 | `PaperView` の性質と知らせ。描く関数が `view.memoPaper` を読む。content・レイアウト・`PaperSpan`・凍結の `InkCanvasView` は変えない | つないだ紙はレイアウトだけから作られ、形が変わらないと作り直されない（`InkCanvasView.swift:2625-2637`・:3087-3090、`PaperSpan.swift:49-61`）。計画 §5.2 の形では届かない |
| 0f-22 | 描き方 | 罫線の枝は今の字のまま、まとめ直さない。ドットは罫線と同じ行、x = 30 ＋ 50k の列。無地は描かない。区切りの線と見出しはいつも | 凍結の画素のテスト（`PaperViewTests.swift:240-290`、`WeekMemoPaperSpanTests.swift:364` ほか）。つないだ紙で点の列が続く【計算】 |
| 0f-23 | ドットの見た目 | 画面で同じ大きさ。既定 (a) 直径 2 pt・#d6cfc2。(b)・(c) は写真で選ぶ | 罫線の 1 pt と同じ考え（M4C-2）。計画 §2 の「写真で選んでもらう」約束 |
| 0f-24 | データ互換と色の線 | 保存の形・凍結の 20 行は変えない。compat10 の `Compat10Checks.swift` にコードで色の線を足す（fixture の JSON は足さない）。アプリの往復のテスト | K-5・K-7。`FIXTURES_1_3` は新しいファイルで落ちる（`build.yml:476-492`）。計画 §5.2 の「1.0 の写しで色を確かめる」 |
| 0f-25 | 新しい文と J-1 | 13 キー（§8.1）と 0e-32 の comment。J-1 は変えない。色選びの題は付けない | 計画 §5.5・§5.2 の 7〜8 件と 5 件。J-1 は 1.1.1 の基準（R1_4_1_CONTRACT §8.1） |
| 0f-26 | 店の文・審査メモ・SUPPORT | 新機能の文 3 行（§8.3）、審査メモは 1.4.1 の段の入れ替え（§8.4）、SUPPORT は新しい FAQ 2 つと 1 文（§8.5） | 1.4.1 の形。0e-28 の教訓 |
| 0f-27 | CI の道 | `r142*` の配線。作る役の枝 `r142-w-*` は速い道。写真の枝に `q-` を付けない。新しいテストを速い道と ui-tests と iPad の段に | 1.4.1 で作る役の push が通しの run を起こした（`docs/R1_4_1.md:560`）。`build.yml:81-93`・:149・:155・:1701・:2141・:2506・:2994・:3487・:4153-4155、`duo.yml:38-41` |
| 0f-28 | 1.4.1 のテストの守り | 新しい `tools/span/TESTS_1_4_1.sha256`（1.4.1 の新しいテストのうち 16 ファイルの候補、§5.5）と段 | 1.4.2 は 1.4.1 で大きく直したコードに触れる。各版がテストを守りの表に入れてきた（TESTS_1_2_3・TESTS_1_3） |
| 0f-29 | J-4 と関門 3 | 基準 `ja-baseline-ref-1.4.2.txt` = fbd1f7a、関門 3 の基準は run #4（45074645599）。違ってよいのは sheet-info の版の字と、設定のシートの組の宣言の行だけ | 1.4.2 は既定の見た目を変えない。main の CI の run は記録に無い。1.4.1 の宣言漏れ（`docs/R1_4_1.md:224-225`） |
| 0f-30 | 新しい写真 | palette-shots に板とダークの行、新しい memo-paper-shots、l10n-shots に設定と板。どれも `screenshots` の外 | `compare_shots` は覆いを持たず、片側だけの写真で落ちる（R1_4_1_CONTRACT §7.1） |
| 0f-31 | 本人の選び | 写真で選ぶのは点の見た目（3 通り、`r142-alt`）だけ。12 色は板の写真を見本にして言葉で替えをもらう。どちらも TestFlight より前に先に送る（段 D2'、0f-38）。ほかは 11/7 の既定（§0.5。変えたいときの行は §9.4） | 計画 §2 と Q3 の約束を果たし、1.4.1 のリードの調整（写真の選びは少なく）に合わせる |
| 0f-32 | 1.4.1 から送られたもの | §1.5 の表（0e-32 と `ink_ref_xcui` は直す、待ち方は新しいテストで、ほかは記録） | 1.4.1 の約束（R1_4_1_CONTRACT §18.8、`docs/R1_4_1.md:292`・:463） |
| 0f-33 | 店の写真 | 撮り直さない（Connect の引き継ぎを読み戻す） | ツールバーと紙の既定の見た目は同じ（計画 §2・§5.3）。1.4.1 で引き継ぎを確かめた（`docs/R1_4_1.md:646`） |
| 0f-34 | 確かめ表の形 | 表の頭に対象の版とビルド番号。各行の 1 文目に始まりの形。前の行の終わりが次の行の始まりになる順。Pencil の行と指の行を分ける。準備でツールバーを下に開く（しまってあれば、丸ボタンの長押しの「ツールバーをいつも出す」から。iPad で上・左・右なら「動かす」→「下へ移す」）。準備の字は確認ページの最初の画面にも書く | 1.4.1 の 0e-29・0e-30・0e-33 の教訓（しまったツールバーの罠、R1_4_1_CONTRACT §18.1）。「動かす」の選択肢には今の辺が出ない（`ToolbarLogic.moveTargets`、`ToolbarLogic.swift:610-611`）ので、下ののぞきから「下へ移す」はできず、iPhone にはそもそも「動かす」が無い（`allowedEdges` は `[.bottom]`、`showsMoveButton` は 2 辺以上、:534）。ピンは iPhone・iPad のどの辺でも開いたまま残す（`(.collapsed, .pinChosen)` → `.expanded`、:285） |
| 0f-35 | 道具の移し | 段 T0（§9.1）で、Connect の道具（`asc141`）と確認ページの道具（`confirm141v4`）を 1.4.2 用に移し、元の文の字の guard を 1.4.2 の字と承認した commit に直してから使う。偽の Connect の試験を通す（リポジトリの外。控えは `~/.local/share/tegaki-backup/<日付>/`）。提出の前に `submit142.py check` が READY（年齢区分 4+・新しい問い 0。新しい問いは本人に聞く） | 道具の選びの引数と guard が 1.4.1 の字に結び付いている（`docs/R1_4_1.md:641`）。1.4.1 では道具を移した後に契約が変わり、提出の直前に道具が止まった。年齢区分の問いは 11/20 に本人の答えが要った |
| 0f-36 | `colorPanel:` の置き場所 | `ToolbarView` の `var colorPanel: ColorPanelHook? = nil` を `eraserReturnsTo`（:51）と `axis`（:53）の間に宣言し、呼び出しでも `axis:` の前に渡す | 守りの表に入る `PaletteMoveButtonTests.swift:537` が平らにした字 `axis: axis, move: paletteMoveButton )` がちょうど 1 つあることを確かめる。最後に足すとこの字が消えて必ず落ち、守りのテストは直さない決まり（§5.5）なので直す道が無い |
| 0f-37 | 確かめた commit（段 V） | D2 の文の commit の後に通しの run を 1 回走らせ、その commit を「確かめた commit」と呼ぶ。TestFlight はその commit とコードの差が空の commit から作り、確認ページの写真はその run と同じコードの duo の run の物だけ。下書きは 3 つの目で見直してから渡す | D2 は `Localizable.xcstrings`・comment・`ink_ref_xcui` を変えるので、最後の通しの run はその後でなければならない。1.4.1 の run #4 の役。1.4.1 の Duo の撮り直し（`docs/R1_4_1.md:265`）と確認ページの見直し（:379・:622） |
| 0f-38 | 選びの写真を先に（段 D2'） | 点の 3 通りの写真と 12 色の見本を、TestFlight より前に小さく先に送る。D3 のビルドを始める時までに答えが無ければ既定 | 計画 Q3 の「見本の絵をお送りしてから決めます」（`docs/PLAN_PEN_COLORS.md:68`）。D3 の後に替えると、作り直し・通しの run・新しいビルド・確かめ表のやり直しになる |

---

## 13. 確かめていないこと・出典

### 13.1 確かめていないこと【未確認】

1. 自前の板の場所: `.anchorPreference` が、ツールバーの `ScrollView`（iPhone の横、左右の縦）の中の丸の枠を、画面の座標で正しく出すか。下のバーは `.safeAreaInset` の中身（`CalendarRootScreen.swift:834-846`）、のぞきは overlay（:782-789）にあるので、その中の anchor が外の `.overlayPreferenceValue` まで届くか。
2. ColorPanelWatch: 凍結の `InkTouchObserver` を窓に付けて、触れが下りた時に `location(in:)` で位置を読めるか。`UIGestureRecognizer.location(in:)` は追っている触れ全部の重心を返すので、2 本目の指が下りたときは、その指の位置にならない（凍結の観測者は `UITouch` を渡さない）。iPhone の窓に付けても触れに影響しないか（PalmWatch は iPad の窓だけで確かめた）。
3. 吹き出し（`.popover`）が外の触れを下へ渡さないこと（板を自前にした理由の 1 つ。iPadOS 27 の実機では見ていない）。`.popover(arrowEdge:)` の iOS 17 と 18 以後の扱い。
4. `UIColorPickerViewController` を SwiftUI のシートで包んだときの × の動き（`colorPickerShown` が true のまま残り、`sheetIsUp` が戻らないか）と、`continuously` の届き方（iOS 17〜27）。シートの子のときにスポイトが効くか（シートごと消えないか）と、拾った色の値。
5. Display P3 の色を `hex(of:)` にしたときの切り詰めの値と、書いている間の色が同じに見えるか。
6. ダークのツールバーの見え方（CI で初めてダークで撮る）。白 0.35 の縁が強すぎないか。
7. ドットの 3 つの見え方と、iPhone での描く時間・PDF のバイト数。
8. 設定のシートの写真（sheet-sync・sheet-settings・店の 06）が本当に変わらないか。
9. 板のボタンの字が 10 の言語で板に入るか（de など）。
10. 12 色の見分け（青・水色・紺）を本人がどう見るか。
11. 長押しと iPhone の横スクロールのぶつかり。手のひらでの長押し。
12. main（2e3ee75）の CI の結果（記録に無い。S0 で `gh run list` で探して記録する）。
13. run #4 の成果物が消える日時（7 日の保管。11/30 ごろ）。
14. Connect が新しい版で前の版の写真を引き継ぐか（1.4.1 では引き継いだ）。
15. 年末の審査の遅れ（12/19〜1/4）。
16. 前の版の端末で新しい色の線がその色で見えること（コードと本物の 1.0 のテストで確かめるが、本人の端末では見られない）。
17. 中国の 2027 年の祝日が python-holidays の正式版に入ったか（S0 で見る）。
18. 板を `.isModal` にしたとき、開いている間に板の外の要素が XCUITest の検索から消えるか（`ColorPanelUITests` のログで見る）。

### 13.2 出典

**調べ役の地図**（2026-11-24。main 2e3ee75 を読んだだけ。書き込みは無い）: ペンの色（色の表・丸の描き方・記憶・関門・名前・最後のインク・データ・凍結・前例・写真モード・テスト・写真）、メモ欄の紙（4 つのメモ欄と描く所・つないだ紙の道・PaperView・PDF・設定の画面・凍結のテスト・写真）、段取りと CI（基準・番号・J-4・CI の配線と段・凍結の表・訳・店の文・審査メモ・SUPPORT・本人の言葉・段・道具・確かめ表の教訓）。

**この契約の書き手がコードで読み直した行**（main 2e3ee75、11/24）: `project.yml:20-24`、`Views/ToolbarView.swift:55-75`・:200-310・:436-505・:575-630、`Views/ToolbarLogic.swift:275-285`・:420-436・:625-662、`Views/ToolbarDock.swift:82-92`、`Views/CalendarRootScreen.swift:193-196`・:253-256・:485-495・:525-528・:729-735・:860-865・:1126-1144・:1190-1212・:1555-1560・:2569-2592・:2735-2750・:3710-3717、`Views/SettingsScreen.swift:180-200`・:250-272・:480-550、`Views/HolidaySettingsSection.swift:1-42`、`Views/WeekStartSettingsSection.swift:25-60`、`Paper/PaperView.swift:1-30`・:140-230、`Paper/PaperSpan.swift:1-70`、`Paper/FreeMemoPaper.swift:1-58`、`Paper/MonthPaper.swift:1-15`・:60-95、`Paper/DayPaper.swift:48-96`、`Persistence/WeekStartChoice.swift:1-40`、`Persistence/HolidayChoice.swift:1-30`、`Persistence/AppSettings.swift:10-25`・:48-80・:128-140、`Support/ScreenshotMode.swift:180-186`・:268-300、`Ink/InkTouchObserver.swift:1-60`、`Ink/InkTools.swift:200-218`、`Views/PaletteGrip.swift:265-375`、`Sync/SyncEngine.swift:28-42`、`Export/PDFPageRenderer.swift:225-232`、`TegakiKit/Tests/Compat10/Checks/Compat10Checks.swift:164`。テスト: `SettingsPageSectionTests.swift:115-230`、`SpanGuideSeenSpanTests.swift:262-292`、`EraserAndBelowDayUITests.swift:78-90`・:640-660、`ToolbarLogicTests.swift:272-309`（`grep`）。CI と表: `build.yml:81-93`・:147-156・:442-448・:656-660・:1701・:2141・:2506・:2994・:3289-3294・:3487・:4150-4156・:4218-4228、`duo.yml:38-41`、`ja-baseline.yml:120-126`、`DATA_1_1.sha256`（20 行）、`TESTS_1_3.sha256`（29）、`TESTS_1_2_3.sha256`（8）、`FIXTURES_1_3.sha256`（37）、`EXPECTED_MIN`（225）、`ja-baseline-ref-1.4.1.txt`、`tools/typecheck/typecheck.sh:1-30`。文: `tools/l10n/source/app-S.json:2700-2720`（`grep` で :2703-2823・:2903・:3036-3075）、`docs/i18n/GLOSSARY.md`（`grep` で :36・:42・:43）、`docs/i18n/REVIEW.md`（節の見出し）、`docs/SUPPORT.md:1-12`・:140-180・:215-222、`docs/store/review-note.txt`（全部、3,897 バイト）、`docs/store/ja/whatsnew.txt`。記録: `docs/R1_4_1_CONTRACT.md`（§0〜§15 と §18.8）、`docs/R1_4_1.md:1-60`・:580-659、`docs/M7_PLAN.md:77-130`・:495-560、`docs/PLAN_PEN_COLORS.md`・`docs/PLAN_MEMO_PAPER.md`（全部）。

---

## 14. 記録

- 2026-11-24 **第 1 版**（契約の書き手。リードの指示で、調べ役の地図 3 つ（ペンの色・メモ欄の紙・段取りと CI）と、R1_4_1_CONTRACT・R1_4_1・M7_PLAN・2 つの計画を読んで書いた。リードの既定は「1.4.2 を先に、月と年の横スクロールは 1.7・1.8 と一緒に設計」）。
  - **計画（§5、r121 の控え）と違えた所**: (1) 板は吹き出しではなく自前の重ね（§3.4）。(2) 長押しは光っている丸だけ（計画 §2 の字のとおり。§5.2 の「どの丸でも」は採らない。§3.5）。(3) 閉じ方は窓の観測者で、触れを止めない（§3.6）。(4) `CalendarRootScreen.swift` は変える（計画は「変えずに済む見込み」）。(5) 6 つの丸の重複の直し方を足した（§3.2）。(6) 紙の柄は content ではなく PaperView の性質と知らせ（つないだ紙に届けるため。§4.3）。(7) 罫線は共通の部品にまとめ直さない（凍結の画素のテスト。§4.4）。(8) 設定の行は Form の最上段ではなく `inputSections` の最初（見た目は同じ「祝日の下」。§4.2）。(9) J-1（`ja-baseline.tsv`）は変えない（§8.1）。(10) 凍結の表は今 20 行（計画は 18 行）で、1 行も変えない（§5.4）。
  - **調べ役の地図と違えた所・足した所**: 地図の「吹き出しか自前か」「長押しの範囲」「閉じ方」「戻すときのペン」「丸の保存の形」「その他の色の出し方と sheetIsUp」「写真モードの丸」「ダークの縁を入れるか」「compat10 の色の線」「設定の置き場所（ア・イ・ウ）」「届け方」「点の見た目の既定」「1.4.1 のテストを守りの表に入れるか」「作る役の枝の push」を、§12 の既定に決めた。設定の置き場所は、地図の (ア)（ページの節）ではなく (ウ) の形（`inputSections` の最初）にした。計画 §2 の「祝日の下」に見た目が合い、設定のシートの同期の写真の帯に入らないため。窓の観測者は、凍結の `InkTouchObserver` を窓に付ける 1.4.1 の PalmWatch の形を写した（地図には無い案。調べ役の「触れたら閉じて、その線は書ける」の願いを満たす）。テストのホストで保存した柄を読まない決まりは、`SyncEngine.isTestHost`（`SyncEngine.swift:32-39`）を見つけて足した。
  - **コードで読み直して確かめた事**: 地図の行番号（`ToolbarView.swift`・`ToolbarLogic.swift`・`CalendarRootScreen.swift`・`SettingsScreen.swift`・`PaperView.swift`・`FreeMemoPaper.swift`・`MonthPaper.swift`・`DayPaper.swift`・`build.yml` の主な行）は、読んだ所はどれも合っていた。`git diff --stat fbd1f7a 2e3ee75 -- Sources TegakiKit Tests tools .github project.yml` は空。`fbd1f7a` の 40 字は `fbd1f7ab82860d00599a43a8768eaa162611b768`。`SpanGuideSeenSpanTests.swift:276-278` の `sheetIsUp` の確かめは「`|| ageRangeAsking` を含む」なので、後ろに足せる。`EraserAndBelowDayUITests` は守りの表の外。
  - `docs/M7_PLAN.md` §4 の 1.4.2 の行に、この契約を指す 1 行を足した（ほかの行と、その行の時期の欄は変えていない）。
- 2026-11-24 **第 2 版**（直し役。2 つの目の見直し、(1) 本人の段取りと 1.4.1 の教訓、(2) コードとの突き合わせ、の指摘を、main 2e3ee75 のコードと記録で 1 つずつ確かめて直した）。
  - **必ず直す（2）**: (1) `colorPanel:` を `ToolbarView(` の最後に足すと、守りの表に入る `PaletteMoveButtonTests.swift:537` の字 `axis: axis, move: paletteMoveButton )` が消えて必ず落ちる → `eraserReturnsTo`（:51）と `axis`（:53）の間に宣言し、`axis:` の前に渡す（§2・§2.1・§5.6・§6.1、0f-36）。(2) 確かめ表の準備と行 8 の「動かす」→「下へ移す」は、下ののぞきでは選択肢に出ず（`ToolbarLogic.moveTargets` は今の辺を除く、`ToolbarLogic.swift:610-611`）、iPhone には「動かす」が無い → 丸ボタンの長押しの「ツールバーをいつも出す」（`(.collapsed, .pinChosen)` → `.expanded`、:285）で開く（§10、0f-34）。
  - **直した方がよい（19。2 つの見直しで重なった 2 つは 1 つに数えた）**: §0.3 の提出と公開の順を D4 にそろえた。点の写真と 12 色の見本を TestFlight より前に送る段 D2'（0f-38）と、§0.4 の「1 回で済みます」の 1 文、色の替えの重さ（今のキーに無い色）。§9.4 のやり直す行（12 色は色の名前が出る行、長押しは 1・4・12）。SUPPORT は色の名前を並べない（§8.3・§8.4・§8.5）。道具の段 T0 と `submit142.py check` の年齢区分（0f-35）。確かめた commit の段 V と D3 の写真・3 つの目の見直し（0f-37）。`prepareAtLaunch` の `testHost:` と MM4、行 15 の開き直し（0f-19）。準備の設定（消しゴムで消したらペンに戻る・指でも書く）と行 6 の触れる所。左ののぞきの UI テストと写真。D1a・D1b の 2 つの目の見直しの関門。× のときの道。閉じる処理は新しい `.onChange` だけ（`PaletteMoveButtonTests.swift:509-535` が 1.4.1 の関数の本体を読む）。光っている丸が動いたら閉じる（`closesOnAnchorMove`、MC8。観測者は down と up だけ）。`penDown()` では閉じない（Pencil のホバーでも来る、`CalendarRootScreen.swift:1199-1200`）。`colorPickerSlot`。色選びの後始末（`colorPickerViewControllerDidFinish`・`onDismiss`）とスポイト、UIKit の present への切り替え。`@State` の ColorPanelWatch（前例 :252）。`ColorPanelUITests` の 3 本（開いたまま書く・光っていない丸・丸の上から引く）と設定が開く確かめ。変異の場所と字（MC5・MC6・MC6b・MS1・MM5）、`FreeMemoPaper.draw` の `style:` は既定値なし。
  - **任意（11）も直した**: 本人の言葉の受け方、`pull --ff-only`、S0 と D5 の main の CI の記録、S0' の duo-shots と板の写真を目で見ること、§0.1 のスポイトと §0.2 のダークの縁の字、§0.4 の 11/7 の選びを 1 行にまとめて §9.4 へ移したこと、行 7 の指と Pencil、`.isModal` と identifier で探すこと、`:2141` の条件の形、`touched(_:at:)`、重ねの入れ物の `.allowsHitTesting(false)` と `colorPanelLayer(_:)`・`safeAreaInset` の anchor（§13.1 の 1）。
  - **直し役が見つけて足した所**: (1) 準備の「黒の丸を押す」は、黒が光っているとき色の板を開く（1.4.2 の新しい動き）→「光っていなければ」にした。(2) 見直しの「D1b の最初の速い道で iPhone の `ColorPanelUITests` が見る」は、UI テストが速い道で走らない（`build.yml:1701`）ので「最初の通しの run で」にした。(3) 見直しの MS1 の案「ColorPanelWatch を窓に付けない → `ColorPanelWatchTests`」は、付けるのが画面（S）の `.onChange` なので、その行を消す変異にして `ColorPanelWiringTests` で捕まえる形にした。(4) 0f-35 の出典 `docs/R1_4_1.md:640` は空の行だったので :641 に直した。(5) 見直しの 2 つが別々に MM4 と呼んだ変異を、MM4（保存した値を読まない）と MM5（`WeekPaper` が柄を渡さない）に分けた。
- 2026-11-25 **第 2 版への注**（リード。D1b の取り込みの前に、D1b の 2 つの目の見直しの nit 8 から。版の番号は変えず、本文は直さずにここで読み替える。中身は `docs/R1_4_2.md` の D1b の決め (a)(b)(j)）。
  - **キーの名前**: §8.1 の表と 0f-25 のキー `toolbar.colorPanel.other` は **`toolbar.colorPanel.otherColor`** と読む（lint L-4 は `.other` で終わるキーを複数形の対の片方と読み、`toolbar.colorPanel.one` が無いと落ちる）。画面の identifier は `toolbar.colorPanel.other` のまま（§3.10）。**D2 の X・R への指示（GLOSSARY・REVIEW の節 17・逆翻訳）は、キー `toolbar.colorPanel.otherColor` で書く。**
  - **compat10 の色の確かめ（§5.3・0f-24）**: `Compat10Checks.run` の中ではなく、別の入口 `Compat10Checks.runColours` に置き、`tools/compat10` の `RunReal`・`RunFrozen` が `run` の数に足して 1 つの N を出す（KitChecks は `run` の確かめを自分の数に入れるので、40,826 のまま）。
  - **色選びの閉じ方（§2.1 の「onDismiss と onDone で colorPickerShown = false・colorPickerSlot = nil」）**: `.sheet` の `onDismiss` は `colorPickerShown` だけを戻し、`colorPickerSlot = nil` は `onDone`（`colorPickerClosed()`）だけで行う、と読む（引き下げて閉じたとき、`onDismiss` の後に決まる候補が丸 1 ではなく開いた丸に入るため）。

（結果は `docs/R1_4_2.md` に書く。ここは契約の版の記録だけ。）
