# 1.4.1 実装契約（「‹ 今日 ›」を右の端に（右手）・等倍に戻すボタン・利き手・ツールバーを動かす）

> **第 5 版（2026-11-22 深夜）**: 第 4 版の「動かす」は、つまみと同じく開いたツールバーにだけ出る。確かめ表の行 12 でツールバーをしまったままだと、丸いボタンで出したツールバー（のぞき）には、つまみも「動かす」も無い。本人の「つまみが無く」はこの形によく合う（§18.1）。のぞきにも「動かす」を出し、選んだ端にツールバーを開いたまま残す。作る人の決まりは新しい §18。**§18 が前の節と食い違う所は §18 が優先**。本人向けの §0.1 も直した。**第 5 版の追記（11/23）**: ビルド 31 の確認ページの下書きの見直しで、審査メモの 4 の 1 文が事実と違うこと、確かめ表の試す順と行 14・15 の字を直した（§18.8）。**その 2（11/23）**: 2 回目の見直しで、行 13 の 1 文目と SUPPORT の 1 文を「丸いボタンの道具の印」に直した（§18.8 の 0e-33〜0e-35。文書だけ）。
>
> **第 4 版（2026-11-22 夜）**: ビルド 30 の確かめで、本人から「ツールバーにつまみが無く、動かせない」と答えをもらった（§17.1）。iPad のツールバーの「しまう」の左に「動かす」ボタンを足し（押すと上・下・左・右から選べる、引いても動く）、ビルド 31 で渡す。作る人の決まりは新しい §17。**§17 が前の節と食い違う所は §17 が優先**。本人向けの §0.1 のツールバーの段も直した。
>
> **第 3 版（2026-11-22）**: 本人の 11/22 の直し（§16.1）を入れた版です。見出しの並び（右手では日付が左の端、「‹ 今日 ›」と等倍が右の端）と、日・週の等倍（1 ページの幅が画面の幅にちょうど合う大きさ）を作り直します。本人向けの §0 と確かめ表の §10 は書き直しました。作る人の決まりは新しい §16 にまとめ、**§16 が前の節と食い違う所は §16 が優先**です（読み替える節の一覧は §16.12）。§1〜§9・§11〜§13・§15 の字は第 2 版のまま残します（記録として）。ビルド 29 と 11/22 の確認ページは使いません。版の記録は §14。
>
> **本人が読む所**: すぐ下の §0（まとめ）だけで足ります。§10 の確かめ表は、TestFlight のビルドが届いたときに Claude が番号を書いて改めて渡します（今は開かなくて大丈夫です）。§1 から後は、作る人のための約束です。
>
> **この文書の決まり**: 1.4.1 の作業はこの文書に従います。元は本人の 2026-11-21 の 2 つのご依頼（§1.2）と、それを 3 つの案で設計し 2 つの審査で比べてまとめた設計（`v15/design/final.md` と `all.json`。リポジトリの外。控えは `~/.local/share/tegaki-backup/1.4.1/v15/`）です。**リードの調整（2026-11-21）が設計より優先**します: 本人に写真で選んでもらうのは 2 つだけ（§0.4・§7.5）、ほかの選びは言葉で既定を書く。**食い違う所はこの文書が優先**です。結果と前もっての宣言は `docs/R1_4_1.md` に書きます（この文書の §14 は契約の版の記録だけ）。節の形は [M7D_CONTRACT.md](M7D_CONTRACT.md) にそろえました。
>
> **材料**: 設計の調べ役のコードの地図 8 つ（見出し・等倍・利き手・設定・テスト・ツールバーのコード・Apple のパレット・批評。**批評が他と食い違う所は批評が正**）と、Apple のパレットの Web の調べ（設計の調べ役が 2026-11-21 に読んだ。§13.2）。**行番号は `r141` の 56b7031（コードはビルド 28 の 2fb8fb1 と 1 バイトも同じ）。この契約の書き手が 2026-11-21 にコードで読み直した**（§14）。印: 【事実】はコードか記録で確かめた事、【推定】は事実から考えた事、【未確認】は確かめられなかった事。決定の番号は **0e-1〜0e-25**（§12。設計の番号のまま）。

---

## 0. まとめ（本人向け）

### 0.1 1.4.1 ですること

11/21 の 2 つのご依頼（§1.2）と、11/22 の直し（「＜今日＞と等倍は右端が右利き」「日、週の等倍とは、最小のサイズではなく、日、週の幅が、ちょうど画面両端にくるサイズのことです」）を入れる版です。**11/22 にお渡ししたビルド 29 と確認ページは使いません。** 直したものを新しいビルド（30 の見込み）と新しい確認ページでお渡しします。

- **画面の上の「‹ 今日 ›」（前へ・今日・次へ）と等倍のボタンを、右の端に置きます（右利きのとき）。** 「‹ 今日 ›」がいちばん右、等倍はそのすぐ左です。年月日は左の端に出します（11/21 の「年月日は一番左側でいいです」のとおり）。日・週・月・年のどのページでも同じです。3 つのボタンは 1 つの横長の枠に並び、どれも指 1 本分の大きさがあります。
  - 1.4 と比べると、左の端にあった ◀ ▶ と、＋予定（iPhone では ＋）の左にあった「今日」が、1 つの枠になって右の端に移ります。日・週・月・年の切り替え・＋予定・☁・⚙ の並ぶ順は 1.4 と同じです。
  - ⚙（設定）は等倍のすぐ左に来ます（iPhone の縦では「‹ 今日 ›」のすぐ左）。
  - iPhone の縦（と iPad の細い窓）では上の段に場所が無いので、等倍は 2 段目（日・週・月・年の切り替え）の右の端、› の下に置きます。
- **等倍のボタン（虫めがねに「1」の印）の働き**:
  - **日と週のページ**: 押すと、1 ページ（1 日・1 週）の幅が画面の幅にちょうど合う大きさになります（iPad でツールバーを左右に置いたときは、ツールバーの横の紙の場所の幅）。指でピンチして合わせなくてすみます。横につながった日・週では、画面の真ん中にあるページの左右の端が、画面の左右の端にそろいます。
  - **月と年のページ**: 11/22 にお見せしたとおり、そのページを初めて開いたときの大きさに戻ります（月と年は次の版で考えます。§0.6）。
  - 日・週で一度等倍を押すと、その種類のページは次からも等倍（幅にちょうど）で開きます。アプリを開き直しても同じです。指でつまんで大きさを変えると、次からはその大きさで開きます。覚えるのは端末ごとです（iPad と iPhone で別々）。
  - 日・週のページを初めて開いたときの大きさは今のまま（iPad と iPhone の縦では 24 時間が見える大きさ）です。
- **設定に「利き手」を足します（右手・左手）。** 「左手」にすると:
  - 画面の上のボタンの並びが左右逆になります（「‹ 今日 ›」と等倍が左の端、年月日が右の端）。
  - しまったツールバーの丸いボタンが右下へ移ります（右手のときは今までどおり左下です。書く手の手のひらを避けるためです）。
  - **紙と書いた字は動きません。** 「◀ が左・▶ が右」と「日 週 月 年」の順も変わりません。
- **iPad では、開いたままのツールバーを上・下・左・右の端へ動かせるようにします**（ここは 11/22 の確認ページと同じです）。
  - ツールバーの「しまう」の左にある**「動かす」を押すと、上・下・左・右から選べます**。「動かす」を**指で**引いても動き、手を離すと近い端に吸い付きます（紙に近い縁の小さなつまみを引いても動きます。第 4 版、§17）。
  - **ツールバーをしまっているときも**、丸いボタンを押して出たツールバーに「動かす」があります。端を選ぶと、ツールバーはその端に開いたまま残ります（第 5 版、§18）。
  - 左右の端では縦に立ちます。
  - ツールバーは紙の上に重なりません。紙の方がその分だけ狭くなります（上の端なら、紙の大きさは下のときと同じです）。
  - **Apple Pencil では引けません**（押して選ぶことはできます）。Pencil で書いている間と、離して 0.5 秒の間は、手のひらが触れても引き始めません。
- **iPhone のツールバーは下のまま**です（Apple のメモと同じ。「動かす」もつまみもありません。iPhone Duo の開いた大きな画面でも下のままです）。
- 1.4 の記録で「次に直す」としていた小さなずれ（拡大しているときに回転すると、見ていた所が少し横にずれる）は、この版で直します（自動の確かめで問題が出なかったので、直したまま入れます）。

### 0.2 変わらないこと

- 書いた線の保存の形・iCloud の記録・書き出しの形は変えません。**今までの手書きは 1 本も動きません。** 1.4 以前の端末とも今までどおり同期します。
- 紙・格子・予定・線の見た目は 1.4 と同じです。ページを開いたときの大きさも 1.4 と同じです（日・週で等倍を一度押した後だけ、その種類は幅にちょうどの大きさで開きます）。見出しの高さを変えないので、紙の広さも変わりません（ツールバーを左右に置いたときは §0.6）。
- 見出しのボタンの数と大きさ、日付に使える幅は、11/22 の確認ページと同じです。並ぶ順だけが変わります。
- 「今日」を押したときの動き（今日のページへ。大きさはそのまま）は今のままです。等倍と今日は別のボタンです。
- ツールバーの中の並び（道具 → 色 → 細中太 → ↶↷ → 指でも書く → しまう）は、左手でも、どの端でも同じ順です。
- 「しまう」と「ツールバーをいつも出す」の働きは今のままです（丸いボタンの置き場所だけ、左手と左右の端で替わります）。
- iPhone のツールバーは 1.4 とまったく同じです。
- iOS 17 以上の iPad・iPhone で使えるのも同じです。データは集めません。広告もありません。値段も同じです。
- App Store の写真は撮り直しません（今の写真は 1.4 までの見出しのままです。撮り直すこともできます。§0.4）。

### 0.3 段取りと目安の日

| いつ（目安） | すること | 本人にお願いすること |
| --- | --- | --- |
| 11/22 | この契約の直し（第 3 版）と、作り直す前の決めごとの記録 | このまとめを読む（返事は要りません） |
| 11/22〜11/23 | 見出しの並びと日・週の等倍を作り直し、自動の確かめを全部やり直す | なし |
| 11/23〜11/24 | わざと壊して確かめが落ちるかを見る・iPhone Duo の確かめ・新しい文の訳・サポートページ・新機能の文・写真 | なし |
| 11/24 | TestFlight 1.4.1（ビルド 30 の見込み） | なし |
| 11/24〜11/25 | 新しい確認ページ | 確かめ表（§10）、見出しの並びの写真を見て選ぶ（何も言わなければ案 B のまま。§0.4）、「この内容で入れてよい」 |
| その後 | 審査に提出（手動公開） | 「1.4.1 を審査に提出して良い」 |
| 審査が通り、確かめ表の答えがそろった後 | 公開 → 本流にまとめる | 「1.4.1 を公開して良い」「まとめて良い」 |
| 12/18 | 年末の前の最後の提出日の目安（12/19〜1/4 は審査が遅れることがあるため【未確認】） | — |

- 1.4 は 11/22 に App Store で公開され、本流にまとまりました。1.4.1 はその上に作っているので、1.4 の公開を待たずに、確かめ表の答えとお言葉がそろえば提出できます。
- 自動の確かめは 1 回に 1 時間半ほどかかり、1 日に回せるのは数回です。直しが要れば、日が 1 日ほどずれます。進められる所は前倒しします。

### 0.4 本人にお願いすること（言葉と操作の一覧。ほかの節はここを指します）

- **11/22 に「全て規定通りで進めてください。」とお答えいただきました。** 次の既定のとおりに作ります（もう一度お聞きすることはありません）:
  - 右の端は「‹ 今日 ›」がいちばん端で、等倍はその内側（すぐ左）。
  - 日・週を開いたときの大きさは今のまま。等倍を一度押すと、その種類は次から等倍で開く。
  - しまったツールバーの丸いボタンは、右利きでは左下のまま。
  - iPhone の横で日・週の等倍を押すと、1 日・1 週が横いっぱい（見えるのは週で 4 時間ほど、日で 2〜3 時間）。
  - 等倍のボタンは虫めがねに「1」の印（字にはしない）。
  - 月と年の横スクロールと、幅に合わせる等倍は次の版。
- **確認ページ 1 回**: 新しい見出し（1.4 → 1.4.1 の前と後の写真）、日・週の等倍の前と後の写真、左手の写真、ツールバーを上・左・右に置いた写真、設定の新しい文、新機能の文（16 の言語）、サポートページの変わる所（日本語・英語）、審査メモを、1 つのページで見せます。「**この内容で入れてよい**」の言葉をください。
- **同じページで、写真を見て 1 つだけ選べます（選ばなければ今の既定のまま）**: 見出しの並び。
  - 既定（案 B）: 日付が左の端、⚙・等倍・「‹ 今日 ›」が右の端。
  - もう 1 つ（案 A）: ⚙ が左の端、日付は等倍のすぐ左（右寄り）。11/22 の確認ページでお見せした左手の見出しを、そのまま右手に使う形です。
  - 写真は iPad Pro 13 の縦と iPhone 18 Pro Max の縦の、週と日です。案 A にするときは「案 A」とだけ言ってください（何も言わなければ案 B のままです）。案 A を選ぶと、作り直して新しいビルドでお渡しし、確かめ表の行 1・2・3・7・12 をやり直してもらいます（行 2・3・7・12 の合格の字は、そのとき書き直してお渡しします）。確かめ表を始める前に言っていただければ、表は新しいビルドで 1 回で済みます。
- **写真は無いけれど、言ってもらえれば替えられること（既定はこの契約のとおり）**:
  - 「‹ 今日 ›」の形: 既定は 1 つの枠に 3 つのボタン。1.1 のように 3 つを離して置く形にもできます（iPhone では日付の場所が 3〜4 mm ほど減ります【推定】）。
  - 左手のときの日付の寄せ方: 既定は右の端（右手の左右逆）。左寄せ（ボタンの並びのすぐ右）にもできます。
  - ツールバーを動かしている間の見え方: 既定は、小さな丸が指について来て、開いたツールバーは薄くなってその場に残り、置ける所に枠が出ます（Apple のメモに近い形）。ツールバーごと半透明で指について来る形にもできます。
  - 左右の端のツールバー: 既定は細い 1 列（紙の幅が 1.1〜1.4 cm ほど狭くなり、縦の月は 7〜10 % ほど小さく表示されます【推定】。消しゴム・投げなわ・予定の短い説明の文は出ません）。説明の文も残す広い 2 列にもできます（紙の幅が 2.1〜2.6 cm ほど狭くなり、縦の月は 13〜18 % ほど小さくなります【推定】）。
  - iPhone のツールバー: 下のまま（Apple と同じで、iPhone Duo の開いた画面でも下です）。上にも置きたくなったら言ってください。
  - App Store の写真: 既定は今のまま（1.4 までの見出しが写っています）。16 の言語の写真を全部撮り直すこともできます。
  - どれかを替えるときは、作って確かめをやり直し、新しい TestFlight のビルドで渡します。確かめ表のどの行をやり直してもらうかは、そのときお知らせします（§9.4）。
- **TestFlight 1.4.1 の確かめ表**（§10）。**本人の端末でしか確かめられません。** 等倍の作り直しで、手書きの画面の大事な所に触れたので、表の全部の行をお願いします（ビルド 29 の確かめはお願いしません）。iPhone Duo の行は「—」で構いません（Duo はお持ちでないので、自動の確かめだけで見ます）。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（無料。1.4 のときと同じです）。
- **言葉**: 「**この内容で入れてよい**」「**1.4.1 を審査に提出して良い**」「**1.4.1 を公開して良い**」「**まとめて良い**」（1.4.1 を本流にまとめること）。前もってまとめてもらっても構いません（1.2.4 の「三つともYes」と同じ）。**本人がご自分の端末で確かめていない版は出しません。**

### 0.5 本人が決めなくてよいこと

- つまみの大きさ、吸い付きの決まり、どの広さの画面でどの端に動かせるか、縦のツールバーの細かい形、等倍を押しても何もしない時（Pencil が触れている間など）、等倍を覚える仕組み、画面を回したときやツールバーを左右へ動かしたときに等倍を合わせ直す決まり、自動の確かめのやり方、手書きの画面の大事なファイルの直し方、訳の手順。どれも既定で決め、理由を §12 と §16 に書きました。
- チャットでお伝えしたことと 11/22 のお答えは、そのとおりに作ります。もう一度お聞きすることはありません:
  - 版は 1.4.1。
  - 右利きでは「‹ 今日 ›」と等倍を右の端に置く（左利きは左の端）。年月日は左の端（左利きは右の端）。
  - 日と週の等倍は、1 ページの幅が画面の幅にちょうど合う大きさ。月と年は開いたときの大きさ。次に開く同じ種類のページも等倍で開く。
  - 左手は、上のボタンの並びと丸いボタンの置き場所だけを替え、紙は替えない。
  - iPad のツールバーは、指でつまみを動かす。iPhone は下のまま。

### 0.6 知っておいてほしいこと

- **ビルド 29 と 11/22 の確認ページは使いません。** 11/22 の確認ページの写真は前の並び（「‹ 今日 ›」が左の端）と前の等倍のままです。新しい確認ページで、直した写真をお見せします。
- **「今日」は 1.1.1（11/4）のご依頼で右側へ移しました。** 1.4.1 では ◀ ▶ と 1 つの枠にまとめ、右手では右の端に置きます（1.1.1 と同じ右側です）。3 つのボタンと等倍・⚙ が隣り合い、iPhone の縦では ⚙ と ‹ が隣り合うので、押し間違いが無いかを確かめ表の行 3 で見てもらいます。押し間違えても、設定の画面が開くか、ページが 1 つ動くか、大きさが変わるだけで、書いた線は変わりません。
- **日・週の等倍で、見た目がほとんど変わらない時があります。**
  - お手元の iPhone 18 Pro Max の縦の週は、開いたときにもう幅がちょうどなので、押しても動きません（終日の予定が多い週は、少しだけ大きくなります）。それでも等倍として覚えます。
  - iPad の日・週や iPhone の日では、押すとはっきり大きくなります。
- **等倍は、縦と横で分けて覚えません。** たとえば iPhone の縦の週で等倍を押すと（見た目は変わりません）、横にしたときの週も 1 週が横いっぱい（4 時間ほど）で開きます。
- **初めて開いたときの大きさに戻したいときは、2 本指でいちばん小さくしてください。** 次からも、初めて開いたときの大きさで開きます。等倍をもう一度押しても、いちばん小さい大きさには戻りません。
- **iPhone の横で日・週の等倍を押すと、1 日・1 週が横いっぱいになります**（お答えのとおり）。見えるのは週で 4 時間ほど、日で 2〜3 時間です（11/22 のチャットでは日も「約 4 時間」とお伝えしましたが、日はもう少し短くなります）。いちばん縮めたとき（週は 3 週、日は 5 日が横に並ぶ）は今のままです。
- **等倍（幅にちょうど）にした日・週は、画面を回しても、iPad でツールバーを左右へ動かしても、左右の端でしまっても、幅にちょうど合ったままです。** 指でつまむと、等倍ではなくなります。
- **月と年は、11/22 のお言葉（「横スクロールができる仕様にしてから、幅が両端にくる等倍を適用します」）のとおり、次の版の計画に入れます。** 1.4.1 の月と年の等倍は、開いたときの大きさのままです。
- **ツールバーを左右の端に置くと、紙の幅が 1.1〜1.4 cm ほど狭くなります。** 縦の iPad の月のページなどは、その分だけ小さく表示されます（mini で約 10 %、Pro 13 で約 7 %【推定】）。上の端なら紙の大きさは下のときと同じです（紙が少し下にずれるだけです）。
- 置いた端は端末ごとに 1 つ覚えます（縦と横で別々にはしません）。Split View の細い窓などでは下に戻り、窓を広げると元の端に戻ります。
- **「アップル純正のように」は「上下左右の 4 つの端に吸い付く」ことと受け取りました。** このアプリでは、ツールバーは 4 つの端に吸い付き、左右の端では縦に立ち、動かしている間は小さな丸い印が指について来ます。端の上の細かい位置（上寄り・下寄り）は覚えず、Pencil では動きません。
- これが Apple のメモのパレットとどこまで同じかは、Apple の文書に書いていない所があるので、「Apple と同じ」とは言いません。お手元のメモと違う所に気づいたら教えてください（任意です）。
- Pencil で書いている最中に等倍を押しても、何も起きません（書いている線を守るため）。書き終えてから押してください。
- VoiceOver は見出しを見た目の順に読みます（右手では日付から、左手では「‹ 今日 ›」から）。
- 前の計画で 1.4.1 だった「ペンの色・メモ欄の紙」は、番号を 1.4.2 に送ります。中身は同じです（ツールバーを左右に置いたときにも色を選べるようにする点だけ足します）。

---

## 1. 土台・決定・範囲

### 1.1 土台のコード

- 枝 `r141`。`r14` の 56b7031（1.4 の確かめ表の答えの記録）から切った。`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は **2fb8fb1（ビルド 28、1.4 の審査に出したビルド）と 1 バイトも違わない**【事実】（`git diff --stat 2fb8fb1 56b7031 -- Sources TegakiKit Tests tools .github project.yml` が空。11/21 に確かめた。違いは `docs/` だけで、M7D.md の記録と、店の文・審査メモ・SUPPORT の 1.4 の組み合わせ c932c30）。
- 1.4 は 11/21 15:41 に審査に提出済み（WAITING_FOR_REVIEW、手動公開）。本人の「1.4を公開して良い」「まとめて良い」は済み。公開は審査が通った後（M7D.md「1.4 を審査に提出」「本人の確かめ表の答え」）。
- 版は `MARKETING_VERSION "1.4.1"`（今は `project.yml:23` で "1.4"）。ビルドの番号は testflight の run から 29 以上（0e-1）。配る先は iOS 17.0 のまま（`project.yml:21`）、`TARGETED_DEVICE_FAMILY "1,2"`（`project.yml:22`）も変えない。
- この Mac には Xcode もシミュレータも無い（Command Line Tools だけ）。TegakiKit は `swift build` と KitChecks、アプリは `tools/typecheck/typecheck.sh`（Mac Catalyst）まで。**iOS の本当のビルド・単体テスト・UI テスト・写真は GitHub Actions の CI だけ**。Xcode は 1.4 と同じ 27.2（27B52）、XcodeGen は 2.46.0 の固定（M7D_CONTRACT §3.1・§3.3 の 4）。1.4.1 は道具を替えない。

### 1.2 本人の依頼（確定。再検討しない）と、本人に伝えたこと

**本人の言葉（2026-11-21、そのまま）**:

1. 「＜今日＞にして、左端に設置して欲しいです。年月日は一番左側でいいです。それと日、週、月、年に対応した、等倍に戻るボタン？も欲しいです。倍率を変更し、拡大、縮小したあとに、すぐに等倍に戻るボタンがあると、助かります。これらは頻繁に使いますので、変更を依頼します。また左利きのユーザーは、設定が逆の方が使いやすいので、選択できるようにしたいです。」
2. 「それと、アップル純正のように、パレットを動かせるようにしたいです。パレットをひらいたまま上下、左右に動かせると使いやすいです。」

**チャットで本人にもう伝えたこと（リード、11/21。この契約はこのとおりに作る）**:

- 版は 1.4.1。
- 「‹ 今日 ›」と等倍を左の端に、年月日をそのすぐ後に（(b) の写真も見せる）。
- 等倍は「ページを開いたときの大きさ」に戻り、次に開く同じ種類のページも等倍で開く。
- 利き手 › 左手 は、上のボタンの並びを左右逆にし、しまった丸いボタンを右下へ移す。紙は替えない。
- iPad のツールバーは、小さなつまみを指で上下左右へ動かす。左右では縦に立ち、紙に重ならずに紙を狭める。Pencil では動かない。iPhone は Apple と同じく下のまま。

**前からの決まり（M7D_CONTRACT §1.2・§9.4 と同じ）**:

- 進め方: 「予定に拘らず進める」（11/13）、「どんどん進めて」（11/20）、進められる物は前倒し（11/8）。途中で許可を取らず、既定で決めて記録し、最後にまとめて報告する。
- 本人の言葉が要るのは、確認ページ（「この内容で入れてよい」）・提出（「1.4.1 を審査に提出して良い」）・公開（「1.4.1 を公開して良い」）・main へまとめる（「まとめて良い」）と、実機の確かめだけ。
- **本人が自分の端末で確かめていない版は出さない**。Duo の行は「—」（本人は Duo も Duo に使える Pencil も持っていない。M7D.md「本人の確かめ表の答え」）。
- **1.4.1 の提出は、1.4 が公開されて `--no-ff` で main にまとまり、`r141` が main を取り込んで、確かめた木とのコードの差が空になった後**（§9.4）。
- Web 版の見出しは変えない（ほかの Pages は出さない約束。§1.4）。

### 1.3 範囲

| # | 何をする | 決定 | 役 | 段 |
| --- | --- | --- | --- | --- |
| 1 | 版 1.4.1、CI の枝の配線（`r141*`）、J-4 の基準を 2fb8fb1 に | 0e-1・0e-23・0e-24 | C | D0 |
| 2 | 見出し: 「‹ 今日 ›」の枠、等倍のボタン、並びの表 `HeaderOrder`、高さを変えない、題名と閲覧専用の印、Duo の詰めた行をやめる | 0e-2〜0e-5 | H | D1a |
| 3 | 広い行を測る（`HeaderRoomUITests`） | 0e-6 | U | D1a |
| 4 | 等倍: 凍結の `InkCanvasView` に足す行（引き金・step 8・`resetZoomToOpen`）、画面のつなぎ、覚えた倍率を忘れる | 0e-7〜0e-10 | Z・S | D1a |
| 5 | 1.4 の残り 0d-44（幅が変わったときの真ん中の読み違い）の直しと、凍結の表の 1 行目の作り直し | 0e-11、§5.4 | Z | D1a |
| 6 | 利き手: 設定・鍵・見出しの鏡・丸いボタンの角 | 0e-12・0e-13 | S・H | D1a |
| 7 | ツールバーを動かす: 動かせる辺・置き場所の枠・つまみ・手のひらの規則・吸い付き・縦のツールバー・のぞき・覚え方・VoiceOver | 0e-14〜0e-22 | T・S | D1b |
| 8 | テスト・変異・Duo の確かめ | §6、0e-3 | 各役・C・U | D1a〜D1c |
| 9 | 11 の新しい文の訳と逆翻訳、SUPPORT、新機能の文、審査メモ、文書 | §8 | X・R・A・W・リード | D2 |
| 10 | 写真（J-4・新しい写真・本人の選びの 2 組） | 0e-24、§7 | C・U・リード | D2 |

### 1.4 範囲外（1.4.1 ではしない。0e-25）

- ⌘0 などのキーボードのショートカット。アプリには今 1 つも無い【事実】（`Sources` に `keyboardShortcut`・`UIKeyCommand` が無い）。⌘0 は次の版の候補として記録する。
- 動く拡大（アニメーション）。今のコードの拡大は全部すぐに替わる形で、Reduce Motion を読む所も無い【事実】（`Sources` に `accessibilityReduceMotion`・`isReduceMotionEnabled` が無い）。等倍もすぐに替える（0e-9）。
- ツールバーを自由な位置に置くこと、辺の上の位置（上寄り・下寄り）を覚えること、書いている間の自動の最小化（Apple の Auto-minimize）、角へ運んで丸くすること。
- Pencil でツールバーを動かすこと。
- iPhone（Duo の開いた画面を含む）でツールバーを下以外に置くこと（本人の選び。§0.4・§4.3）。
- ツールバーの中身の並びを左手で逆にすること（`ToolbarFitTests.swift:55` の「左から見える物」の約束と `EraserAndBelowDayUITests.swift:630-646` の「しまう」が右の端の前提を守る）。
- Web 版（別のリポジトリ、GitHub Pages）の見出し。DESIGN は「アプリの画面は Web 版の並びに従う」と書く（`docs/DESIGN.md:212` の節）が、Web は変えない。DESIGN §2.7 に違いを書く（§8.6）。
- 見出しの Dynamic Type の上限（今も無い。1.4 と同じ）。
- App Store の写真の撮り直し（本人の選び。§0.4・§7.6）。
- ペンの色の板（1.4.2）。その板は、後で縦のツールバーからも開けること（`docs/PLAN_PEN_COLORS.md:7` の決定の申し送り）。
- 中国の 2027 年の祝日（M7D_CONTRACT §9.6・0d-26。§1.5）。

### 1.5 1.4 の残りの扱い

| 残り（元） | 1.4.1 で | 役 | 確かめ |
| --- | --- | --- | --- |
| **0d-44 1 ページの道の幅の読み違い**（`docs/M7D_CONTRACT.md:141`・`:1124`。凍結の `InkCanvasView.swift:1257-1260` は、幅が変わったとき新しい幅と古い位置を混ぜて真ん中を読む） | **直す**（0e-11）。1.4 は「次に凍結の表を作り直す版（1.4.1 の見込み）で直す」と約束した。ツールバーを左右に置くたびに幅が 74 pt 変わるので、直さないと拡大中の 1 ページの紙が約 37 pt 横にずれる。**ピン留めのテストが 1 つでも結果を変えたら戻して記録**し、確かめ表に 1 行足す | Z | `InkCanvasWidthCentreTests`（新しい）、`InkCanvasViewTests`・`InkCanvasSpanTests`・`DuoFoldTests` がそのまま緑 |
| **`SpanGuard` の `.prototype`**（凍結の 19 行目。`docs/M7D_CONTRACT.md:136`） | **残す**。19 行目は 1.4.1 でも作り直さない。決めて記録し、次に 19 行目を作り直す版へ送る（0e-11） | — | — |
| 版の番号（`docs/M7_PLAN.md:518-519`: 1.4.1 = ペンの色・メモ欄の紙、1.5 = 指で予定） | 前の 1.4.1 を **1.4.2** に送る。1.5 は指で予定のまま（0e-1）。M7_PLAN §4 の表を直す | リード | — |
| ToolbarLogic の注の「66 pt」（`ToolbarLogic.swift:11-16`。実測は 74、`docs/M7A.md:401-405`） | `ToolbarLogic.swift` を直す同じ commit で、注を 74 に直す（注だけ。動きは同じ） | T | 注だけ |
| 1.4 の Duo の店の写真（Connect の 1.4 に 16 ロケール × 5 枚、M7D.md） | 触らない（新しい版は前の版の写真を引き継ぐ【推定】。版 1.4.1 を作った後に読み戻して確かめる） | リード | 読み戻し |
| 年齢区分の 2 問 | 1.4 で済み（どちらも false で 1.4 の提出に入った。M7D.md） | — | — |
| 中国の 2027 年の祝日（M7D_CONTRACT §9.6、本人の前もっての了承 11/20） | **1.4.1 の範囲の外**。python-holidays の正式版に入ったら、M7D_CONTRACT §9.6・0d-26 のとおり扱う。どの版で出すかはその時にリードが決めて `docs/R1_4_1.md` に書く（1.4.1 に入れるなら、KitChecks の数・閾値と J-4 の宣言を足し、関門をやり直す） | — | — |
| 1.4 の J-4 の手書きの基準（`tools/shots/ink_ref.tsv`・`ink_ref_xcui.tsv`） | D1 の最初の通しの run の写真から作り直す（0e-24。見出しが変わると行の写真の中身が変わるため） | C | 撮り直しの予算 |

---

## 2. 構成とファイル所有

1 つのファイルの持ち主は 1 つの役。commit は `git add <ファイル名>` で、持ち主のファイルだけを入れる（例外は凍結の作り直しの commit だけ。§5.4）。役の表は §9.3。

```
project.yml                                         C  MARKETING_VERSION "1.4.1"（だけ）
.github/workflows/build.yml                         C  r141 の配線、速い道の正規表現（:672）、ui-tests の grep（:2013）、blank-paper の新しい段と
                                                       HeaderRoomUITests、span-shots-app の iPad の横の写真、新しい写真の段、凍結の段の名前（:438。§5.4 の commit で）
.github/workflows/ja-baseline.yml                   C  基準のファイルを 1.4.1 に（:124 の FILE=）、写真の段を build.yml と同じ字で
.github/workflows/duo.yml                           C  枝 r141-duo* でも走る（:37-41）
tools/l10n/ja-baseline-ref-1.4.1.txt                C  新しい。2fb8fb1a818a8048f38555a5cc166ad754c26acb の 1 行
tools/shots/ink_ref.tsv・ink_ref_xcui.tsv            C  D1 の最初の通しの run の写真から作り直す（run の番号を頭の注に）
Sources/TegakiCalendar/Ink/InkCanvasView.swift      Z  凍結（DATA_1_1 の 1 行目）。足す行と、0d-44 の 2 行だけ（§3.7〜§3.10・§5.4）
tools/compat10/DATA_1_1.sha256                      Z  1 行目だけを同じ commit で作り直す（§5.4）
Sources/TegakiCalendar/Views/HeaderOrder.swift      H  新しい。HeaderPiece と、arm × hand × readOnly の並びの純粋な表（§2.1）
Sources/TegakiCalendar/Views/PageHeaderView.swift   H  「‹ 今日 ›」の枠、等倍（広い行と 2 段目）、hand・onZoomReset の引数（既定つき）、題名の寄せ、
                                                       閲覧専用の印の場所、詰めた行と sideInsets をやめる、頭の注の図（§3）
Sources/TegakiCalendar/Views/ToolbarLogic.swift     T  PaletteEdge、allowedEdges・effectiveEdge・snapEdge、枠の数（74・60）、expandedBottomGap 8、toastSideInset、
                                                       ToolbarEvent.placementChosen、ToolbarStep.storesPlacement（既定 false）、注の 66 → 74（§4）
Sources/TegakiCalendar/Views/ToolbarView.swift      T  axis の引数（既定 .horizontal）と縦の形。縦では説明の行を道具のボタンの読み上げのヒントに（§4.8）
Sources/TegakiCalendar/Views/PaletteGrip.swift      T  新しい。PaletteGripView（UIViewRepresentable の pan）と PalmWatch（凍結の InkTouchObserver の新しいインスタンスを窓に）
Sources/TegakiCalendar/Views/PaletteDragOverlay.swift  T  新しい。押せない丸（puck）と、置ける所の枠
Sources/TegakiCalendar/Views/CalendarRootScreen.swift  S  等倍の @State と resetZoom（両方のキャンバスの最後の引数）、@AppStorage の hand と paletteEdge、
                                                       上の枠・左右の枠（HStack）と列の幅のつなぎ（shownViewport・pathCanvas・estimatedZoom・smallScreen）、
                                                       つまみ・動かしている状態・puck と枠、penDown() の最初の行で取り消す・scenePhase・windowSize・シート、
                                                       のぞきを今の辺に、toastSideInset、左右に置いたときの丸いボタンの角、`toolbar: palette=` の行、PalmWatch の付け外し
Sources/TegakiCalendar/Persistence/AppSettings.swift  S  handKey "layout.hand"、paletteEdgeKey "toolbar.paletteEdge"、enum Hand（init(stored:)）、読み書きの口、注
Sources/TegakiCalendar/Views/SettingsScreen.swift   S  inputSections の最後に「利き手」の Section。onChange で hand と collapsedEdge を書く（写真モードでは書かない）
Sources/TegakiCalendar/Support/ScreenshotMode.swift S  Config.hand・palette・paletteDrag（既定 nil）と --screenshot-hand・--screenshot-palette・--screenshot-palette-drag
tools/l10n/source/app-P.json・app-U.json・app-S.json  X  11 の新しいキーと header.today の comment（§8.1）
tools/l10n/translations/*.json（9）                  X  訳
Sources/TegakiCalendar/Resources/Localizable.xcstrings  X  build.py が作り直す（同じ commit）
docs/i18n/GLOSSARY.md                               X  等倍（拡大も縮小もしていないもとの大きさ）、利き手・右手・左手（性別の無い言い方）
docs/i18n/REVIEW.md・docs/i18n/back/*.json           R  1.4.1 の節と、元を見ない逆翻訳
Tests/TegakiCalendarTests/（新しい 9）               各役  §6.1
Tests/TegakiCalendarUITests/（新しい 4・書き直し 1）  U  §6.1・§6.2
Tests/TegakiCalendarTests/PageHeaderRoomTests.swift H  書き直し（ピン留めの外）
Tests/TegakiCalendarTests/AppSettingsTests.swift・SettingsScreenTests.swift  S  足すだけ
Tests/TegakiCalendarTests/ToolbarLogicTests.swift・ToolbarFitTests.swift  T  足すだけ
docs/store/*/whatsnew.txt（12 のロケールのフォルダと source-ja）・review-note.txt・README.md の表の行  A  §8.3・§8.4
docs/SUPPORT.md・SUPPORT.en.md                      W  §8.5
docs/R1_4_1.md・docs/M7_PLAN.md・docs/DESIGN.md・README.md  リード  記録・§4 の番号・§2.7/§2.8・:60/:82/:186（§8.6）
```

- **変えないもの**: 凍結の表の 2〜20 行目（`InkTouchObserver` は PalmWatch が新しいインスタンスを作って使うだけ。ファイルは 1 バイトも変えない）、`tools/span/TESTS_1_3.sha256`（29 行）・`TESTS_1_2_3.sha256`（8 行）・`FIXTURES_1_3.sha256`（37 行）のファイル、`tools/l10n/lint-skip.txt` の 20 行、`tools/duo/idiom-allow.txt`、TegakiKit の全部（`ZoomPolicy` も。KitChecks 40,826 は同じ）、compat10・compat11・compat-span の fixture と `EXPECTED_MIN`、`tools/l10n/ja-baseline.tsv`（J-1 の 516 行。1.1.1 の日本語の文で、新しいキーは足さない）、`ja-baseline-ref.txt`・`-1.3.txt`・`-1.4.txt`（記録として残す）。
- **画面の字で守られた所**（ピン留めのテストがソースの字を読む。§5.6）は、平らにした形で 1 字も変えない。新しい引数は呼び出しの最後に足し、狭めた幅は今の `viewportWidth` の引数を通す。
- **役 L（台帳）と Y（同期）は作らない**。保存・merge・同期・墓標・台帳の行に触れる直しが要ると分かったら止めて、契約を直す（§5.4）。

### 2.1 接点（宣言。新しい引数には既定値を付け、省けば 1.4 と同じ動き）

```swift
// Views/HeaderOrder.swift（役 H、新しい）。見出しの並びだけを決める純粋な表。SwiftUI も UIKit も読まない。
enum HeaderPiece: Equatable, CaseIterable {
    case today        // 「‹ 今日 ›」の枠（◀・今日・▶ の 3 つのボタン。中の順は替えない）
    case zoomReset    // 等倍（Z）
    case title, picker, badge, add, sync, settings
    // 並べ方 (b) が選ばれたときだけ `case gap`（Spacer(minLength: 0)。§3.2 の (b) の表）を足す。
}
enum HeaderOrder {
    /// 見出しの行（広い行・狭い 1 段目・狭い 2 段目）。
    enum Arm: Equatable, CaseIterable { case wide, compactFirst, compactSecond }
    /// 右手の表を返す。左手は右手の配列を逆にした物（layoutDirection は使わない）。badge は readOnly の広い行だけ。
    static func pieces(arm: Arm, hand: Hand, readOnly: Bool) -> [HeaderPiece]
}
//   右手: wide          [today][zoomReset][title][picker][badge?][add][sync][settings]
//         compactFirst  [today][title][add][sync][settings]
//         compactSecond [zoomReset][picker]

// Views/PageHeaderView.swift（役 H）
//   足す引数: `var hand: Hand = .right`、`var onZoomReset: () -> Void = {}`。
//   やめる物: `sideInsets`・`usesTightRow`・`tightFirstRow`・`tightTitleGain`・`roomyCompactWidth`・`tightNavigationSpacing`・
//            `tightAddEventSymbolWidth`（0e-3。duo.yml で確かめられなければ、計算し直した詰めた行を戻す）。
//   body は HeaderOrder.pieces の ForEach と switch で描く。部品の名前（読み上げ）と identifier は今のまま（§5.6）。
//   新しい identifier: "header.zoomReset"（等倍）。読み上げは L.text("header.zoomReset.spoken")（「等倍に戻す」）。

// Ink/InkCanvasView.swift（役 Z、凍結。§5.4 の作り直し）
/// 1.4.1（R1_4_1_CONTRACT §3.7）: 等倍。値が変わるたびに 1 回、次の main-actor のターンで、今の倍率の範囲の open（開いたときの
/// 倍率、比 1）へ戻す。戻したときは onZoomRatioChange で 1 を知らせる（最初の配置と同じ道）。0 のまま、または変わらなければ何もしない。
var zoomResetTrigger: Int = 0          // onSpanStop（:243）の後。構造体に init は無いので、呼ぶ所は全部そのまま通る
//   Coordinator: `private var lastZoomResetTrigger: Int`。init で lastRevealTrigger（:640）の隣に parent.zoomResetTrigger を入れる。
//   update(from:) の step 8（step 7 :987-993 の後）: 値が変わったら覚えて、Task { @MainActor [weak self] in self?.resetZoomToOpen() }。
//     SwiftUI の更新の中では動かさない。
//   reveal()（:1412-1417）の後に `private func resetZoomToOpen()`（§3.8 の規則）。DEBUG の NSLog "zoom: reset %.4f→%.4f"。

// Views/ToolbarLogic.swift（役 T）
enum PaletteEdge: String, Equatable, Sendable, CaseIterable {
    case bottom, top, left, right
    /// "bottom" / "top" / "left" / "right"。nil・ほかの字は .bottom（ToolbarEdge(stored:) と同じ形、ToolbarLogic.swift:26-28）。
    init(stored raw: String?)
}
extension ToolbarLogic {
    static let sideSlotWidth: CGFloat = 74     // 外 6 + 縦のバー 60 + 紙との間 8
    static let topSlotHeight: CGFloat = 74     // 上 6 + バー 60 + 紙との間 8（横は 12 ずつ）
    static let verticalBarWidth: CGFloat = 60  // 6 + 48 + 6
    static let expandedBottomGap: CGFloat = 8  // つまみのある下のバーの上の余白（safeAreaInset の間隔の代わり。§4.5）
    /// 動かせる辺。端末の種類（idiom）は自分では読まない。isPad は画面が `pencilPhone.isPad`（`CalendarRootScreen.swift:202`。
    /// idiom-allow の 2 行目の値をそのまま使い、新しい idiom の読みは作らない）を渡す。isPad が false（どの iPhone も。Duo の
    /// 内側の広い窓も）なら [bottom] だけ。iPad: 下はいつも。上は WindowClass.isWide(windowSize)。左右は isWide かつ
    /// column ≥ 700 かつ paperColumnHeight ≥ 460。並びは [bottom, top, left, right] のうち許す物（§4.3）。
    static func allowedEdges(isPad: Bool, windowSize: CGSize?, column: CGFloat, paperColumnHeight: CGFloat) -> [PaletteEdge]
    /// stored が許されていればそれ、でなければ .bottom。stored は書き換えない。
    static func effectiveEdge(stored: PaletteEdge, allowed: [PaletteEdge]) -> PaletteEdge
    /// 離した所と速さから吸い付く辺（§4.7）。
    static func snapEdge(drop: CGPoint, velocity: CGVector, frame: CGRect, allowed: [PaletteEdge], current: PaletteEdge) -> PaletteEdge
    /// 左右に開いたときだけ、その側に 74（トーストを縦のバーにかけない）。ほかは 0。
    static func toastSideInset(_ mode: ToolbarMode, edge: PaletteEdge) -> CGFloat
}
// ToolbarEvent に `case placementChosen`（つまみを離した・VoiceOver の操作）。ToolbarStep に `var storesPlacement: Bool` と、
// 今の明示の init（`ToolbarLogic.swift:82-92`。memberwise init は無い）の最後の引数 `storesPlacement: Bool = false`:
//   init(mode: ToolbarMode, storeCollapsed: Bool? = nil, flipsEdge: Bool = false, storesPlacement: Bool = false)
//   （今の呼び出しと ToolbarLogicTests の行はそのまま通る）。
// step(.expanded, .placementChosen) → ToolbarStep(mode: .expanded, storesPlacement: true)。ほかの状態では何もしない（今の default）。
// dockClearance（60）・paperBottomClearance（0/60/60）・toastBottomPadding（8/62/74）は変えない（ToolbarLogic.swift:108・:256-271）。

// Views/ToolbarView.swift（役 T）
//   `var axis: Axis = .horizontal`。.horizontal は 1.4 の道そのまま（呼ぶ所も同じ）。.vertical は §4.8 の形。identifier は全部同じ（tool.pen など）。

// Views/PaletteGrip.swift（役 T、新しい）
struct PaletteGripView: UIViewRepresentable {
    /// UIPanGestureRecognizer。allowedTouchTypes = [.direct, .indirectPointer]（指・トラックパッド・マウス。Pencil は入れない）。
    /// 10 pt 動いてから始まる。gestureRecognizerShouldBegin は mayBegin()（PalmWatch が凍結の horizontalPanMayBegin で答える）。
    var mayBegin: () -> Bool
    var onBegan: (CGPoint) -> Void
    var onChanged: (CGPoint, CGVector) -> Void
    var onEnded: (CGPoint, CGVector) -> Void
    var onCancelled: () -> Void
    var cancelTrigger: Int     // 変わったら走っているドラッグを取り消す（Pencil・penDown・背景・窓の大きさ・シート）
}
@MainActor final class PalmWatch {
    /// 凍結の InkTouchObserver（InkTouchObserver.swift:19-38）の新しいインスタンスを UIWindow に付ける（同時の認識を全部 true）。
    /// .down(.pencil) で pencilsDown + 1 と onPencilDown()、.up(.pencil) で − 1 と lastPencilUp = 今。
    func attach(to window: UIWindow)
    func detach()
    /// InkCanvasView.horizontalPanMayBegin(pencilsDown:lastPencilUp:now:)（InkCanvasView.swift:2435-2440）の答え。
    func mayBegin(now: Date) -> Bool
    var onPencilDown: () -> Void
}

// Views/PaletteDragOverlay.swift（役 T、新しい）
//   押せない（allowsHitTesting(false)）重ね物。ToolbarDock の見た目の 96×48 の丸に今の道具の印（ToolbarLogic.badge）、指の 40 pt 上。
//   許す辺ごとに、置いたときの枠の輪郭（アクセントの色 12 %）。吸い付く先は 28 % と 2 pt の縁。

// Persistence/AppSettings.swift（役 S）
enum Hand: String, Equatable, Sendable, CaseIterable {
    case right, left
    /// "right" / "left"。nil・ほかの字・文字列でない値は .right。
    init(stored raw: String?)
}
//   static let handKey = "layout.hand"            // String。端末ごと（UserDefaults、CA92.1）。iCloud に送らない。isExistingUser の鍵ではない
//   static let paletteEdgeKey = "toolbar.paletteEdge"  // String。端末ごと。向きごとに分けない
//   static var hand: Hand / static var paletteEdge: PaletteEdge（読み書きの口。toolbarEdge :160-164 と同じ形）

// Support/ScreenshotMode.swift（役 S）
//   Config に `var hand: Hand? = nil`、`var palette: PaletteEdge? = nil`、`var paletteDrag: PaletteEdge? = nil`。
//   --screenshot-hand left、--screenshot-palette top|left|right、--screenshot-palette-drag <bottom|top|left|right>（確認ページの写真だけ）。
//   知らない値・値なしは nil。--screenshot-toolbar の値（collapsed・collapsed-right）と ToolbarShot（ScreenshotMode.swift:90-107）は変えない。
//   写真モードでは hand・paletteEdge・collapsedEdge を書かない。

// Views/CalendarRootScreen.swift（役 S）
//   @State private var zoomResetTrigger = 0、func resetZoom() { zoomResetTrigger += 1 }。PageHeaderView(onZoomReset: resetZoom, hand: hand)。
//   2 つの InkCanvasView（:1107 と :2832）の最後の引数に `zoomResetTrigger: zoomResetTrigger`（:1165 の bottomClearance: の後、
//   :2900 の onSpanStop: spanStopped の後）。goToday（:1604-1627）と ScreenPaths.today は替えない。
//   @AppStorage(AppSettings.handKey)・@AppStorage(AppSettings.paletteEdgeKey)。
//   penDown()（:1042-1056）の最初の行で、走っているつまみのドラッグを取り消す（onPenDown の閉包の字は替えない。§5.6）。
//   シートが開いたときの取り消しは自分の `.onChange(of: sheetIsUp)` で（ピン留めの `sheetsChanged()` の `if` には書かない。§5.6）。
//   `ToolbarView(` の呼び出しは今の 1 つ（`toolbar`、:980-993）のまま。`toolbar` を axis を受ける形にして縦のバーもそこから（§4.8）。
//   allowedEdges には `isPad: pencilPhone.isPad` を渡す（§4.3）。写真モードの辺は画面の @State に持つ（§4.10）。
```

---

## 3. 見出しと等倍

### 3.1 見出しの部品（0e-2）

- **「‹ 今日 ›」は 1 つの枠**: `HStack(spacing: 0)` に別々の 3 つの `Button`、`.buttonStyle(.plain)`・`.foregroundStyle(.tint)`。高さ 36 pt の `Capsule` を `tertiarySystemFill` で塗り、1×18 pt の `.separator` の細い線を 2 本（幅を取らない）。
  - ◀: `Image(systemName: "chevron.left")`・`.body` の semibold・枠 44×44。読み上げは今の「前の日／週／月／年」（`PageHeaderView.swift:216` の `previousLabel(kind)`）。
  - 今日: `Text(L.text("header.today"))`・17 pt・`lineLimit(1)`・`fixedSize`・横の余白 8・最小 44×44。読み上げは今の「今日」。
  - ▶: `chevron.right`・44×44・今の「次の◯」（`:222`）。
  - 枠は `.fixedSize()` と `.layoutPriority(1)`。◀ はいつも ▶ の左。
  - 幅【推定】: ja 約 135.4 pt、en・de 約 151.4 pt（設計の計算。§3.5 で測る）。
  - **`header.today` に ‹ › の字を入れない**（L-3。de「Heute」は幅の上限まで 0.005 pt しかない【事実】: `PaperFitTests.swift:379-396` の 17 pt で ja ＋ 16.5 pt、`docs/i18n/GLOSSARY.md:193-195` の en 47.3・de 47.4 と上限 47.4）。‹ › は ◀ ▶ の記号で描く。
- **等倍（Z）**: `Image(systemName: "1.magnifyingglass")`、identifier `header.zoomReset`、読み上げ `header.zoomReset.spoken`（「等倍に戻す」）。広い行では 44×44 の的に、`tertiarySystemFill` の直径 36 pt の丸。狭い 2 段目は §3.3。
- 理由: 1.1 の離れた 3 つ（`.bordered`）より約 20〜26 pt 狭く【推定。3 つの間の間隔を 4〜6 pt と見た設計の計算で、設計の中でも 20 と 26 の 2 つの数がある。§3.5 で枠の幅を測る】、どの iPhone でも ja の一番長い短い題（「10/24〜10/30」、最小の倍率で約 70 pt、`PageHeaderRoomTests.swift:24-25`）の場所が取れる。ピン留めのテストが読む名前と identifier は同じ（`YearTapUITests.swift:84`・`:120` の「前の年」「前の日」、`SpanRerunUITests` が `YearTapUITests` を受け継ぐ、`tools/span/TESTS_1_3.sha256:27-29`）。記号は訳が要らず、幅のテストも要らない。
- 字の「等倍」は本人の選び（§0.4 の 2）。選ばれたときだけ `header.zoomReset`（`app-P.json`）を足す（§8.1）。

### 3.2 並び（0e-3）

- 並びは 1 つの純粋な表 `HeaderOrder.pieces(arm:hand:readOnly:)`（新しい `Views/HeaderOrder.swift`、§2.1）から。`PageHeaderView` は `ForEach` と `switch` で描くだけ。**左手は右手の配列を逆にした物**。`layoutDirection` は使わない（アプリに右から左の言語は無く、テストで入れない【事実】: `LocalizationBundleTests.swift:104-113`、`tools/l10n/lint.py` の L-11。`Sources`・`TegakiKit/Sources` に `layoutDirection`・`semanticContentAttribute`・`flipsForRightToLeft` が無い）。
- 広い行（列の幅 ≥ 600。`CalendarRootScreen.compactWidth`、`CalendarRootScreen.swift:339`）、`HStack(spacing: 6)`:
  - 右手: [‹今日›][Z][題名][切り替え 220、優先 1][閲覧専用の印（読み取り専用のときだけ）][＋ ／ 760 からは ＋予定][☁ ／ 980 からは ☁ と字][⚙ 44]
  - 左手: [⚙][☁][＋][印][切り替え][題名][Z][‹今日›]
- 狭い（< 600）、`VStack(spacing: 4)`:
  - 1 段目 `HStack(spacing: 4)`: 右手 [‹今日›][題名 .headline][＋ 記号 28][☁][⚙]、左手 [⚙][☁][＋][題名][‹今日›]。
  - 2 段目: 右手 [Z][切り替え maxWidth ∞]、左手 [切り替え][Z]。
- **並べ方 (b)（本人の選びの写真、§0.4 の 1・§7.5）**: `r141-alt` では DEBUG だけの写真の引数で、本人が選んだら `r141` の既定をこれに替えて、次の表で描く。左手は (a) と同じく右手の配列を逆にした物。
  - 題名は `maxWidth: .infinity` を外し、自分の幅にする（縮めるときは今の `lineLimit(1)`・`minimumScaleFactor(0.6)`・「…」。`fixedSize` にはしない。縮めなくなるため）。そのすぐ後に「‹ 今日 ›」と Z、その後ろに新しい部品 `gap`（`Spacer(minLength: 0)`。(b) にだけ使う）を置く。これで「‹ 今日 ›」が右の端へ押されない。

  | 行 | (b) 右手 | (b) 左手 |
  | --- | --- | --- |
  | 広い行（`HStack(spacing: 6)`） | [題名][‹今日›][Z][gap][切り替え 220][印?][＋][☁][⚙] | [⚙][☁][＋][印?][切り替え 220][gap][Z][‹今日›][題名] |
  | 狭い 1 段目（`HStack(spacing: 4)`） | [題名 .headline][‹今日›][gap][＋][☁][⚙] | [⚙][☁][＋][gap][‹今日›][題名] |
  | 狭い 2 段目 | [Z][切り替え maxWidth ∞]（(a) と同じ） | [切り替え][Z]（(a) と同じ） |

  - 部品は (a) より `gap` が 1 つ多いので、題名の場所は行の間隔 1 つ分（広い行 6・狭い行 4 pt）だけ少ない【推定】。§3.5 の 115 pt の関門と `PageHeaderRoomTests`（題名の場所 ≥ 70）は、その分を引いた式で測り直す。題名の寄せ（§3.4 の `.leading`・`.trailing`）は (b) には無い（題名は自分の幅で端に着く）。
  - 選ばれたら、`HeaderOrderTests` の表を (b) にし、`HeaderAndPaperUITests` の不等式を §6.2 の (b) の形に替え、D1〜D2 の関門（§3.5 の 115 pt を含む）をやり直す。
- **Duo の詰めた行をやめる**: `usesTightRow`・`tightFirstRow`・`tightTitleGain`・`roomyCompactWidth`・`tightNavigationSpacing`・`tightAddEventSymbolWidth`・`sideInsets` の 7 つ（§2.1 と同じ。`PageHeaderView.swift:93-114`・`:165-180`、`CalendarRootScreen.swift:872-874`）。新しい狭い 1 段目は、Duo の外側の 382 pt の列で題名に約 84.6 pt を残す【推定】（固定部分 ja 約 297.4 pt。1.4 の詰めた行は 80）。**duo.yml（`r141-duo*`）で確かめられたときだけ**やめる: `DuoLayoutUITests` が緑、`shot_checks` が外側で `header=2`、ログの題名の場所が 80 以上。どれかが無ければ、計算し直した詰めた行を戻す（D1c）。
- 理由: 1 つの並びの表なら、鏡をテストで固められ、日週月年や ◀ ▶ が右から左の言語のように裏返ることも無い。詰めた行は、前の 1 段目に場所が無かったからあった物（`PageHeaderView.swift:28-39` の注）。
- 参照: `PageHeaderView.swift:107-161`（今の 3 つの腕）、`:165-180`、`CalendarRootScreen.swift:857-881`、`DuoLayoutUITests.swift:57-88`、`tools/duo/shot_checks.py:18-24`。

### 3.3 見出しの高さを変えない（0e-4）

- 1 段目と広い行は 44 pt のまま。◀ ▶ ⚙ はもう 44（`PageHeaderView.swift:214`・`:220`、☁ は `:314` の minHeight 44）で、Z と枠の的も 44【事実】。
- 狭い 2 段目は `HStack(spacing: 8) { Z; 切り替え }.fixedSize(horizontal: false, vertical: true)`。Z は `.plain` の Button で、印に `.frame(minWidth: 44, maxHeight: .infinity)` を付け、`RoundedRectangle(8)` を `tertiarySystemFill` で塗る。**切り替えの高さに伸びるだけで、高さを決めない**。PreferenceKey は使わない（測るまで 0 の値が入るため）。
- **関門**: 既定の写真の `toolbar: paperArea=` の行が、1.4 の基準の run と 1 バイトも同じ（§7.2）。UI テストで `header.zoomReset` の高さ ≤ 切り替えの高さ ＋ 0.5。
- どちらかが落ちたら、先へ進む前に、Z に測った切り替えの高さの固定の枠を付ける。
- 理由: 紙の領域は、開いたときの倍率・関門 3・`SpanPlan.referenceViewport`（`TegakiKit/Sources/Layout/SpanPlan.swift:259-284`）・`DuoChecks`（`TegakiKit/Sources/KitChecks/DuoChecks.swift:96-103` の測った行）の元。紙の領域が変わらなければ、どれも計算し直さなくてよい。切り替えの高さは今まで測ったことが無い（批評）。紙の領域は `updatePaperArea`（`CalendarRootScreen.swift:600-606`）がログに書く（`:611-616`）。

### 3.4 題名と閲覧専用の印（0e-5）

- 題名は狭い行で `compactTitle`、広い行で `title`（今の `CalendarRootScreen.swift:859-861`）。祝日の分け方（F-11、`titleHoliday`、`PageHeaderView.swift:236-263`）・`lineLimit(1)`・`minimumScaleFactor(0.6)`・「…」の切り・identifier `page.title`（`:266`）・`.isHeader` は今のまま。
- 枠は `maxWidth: .infinity`、右手は `.leading` 寄せ（Z か枠のすぐ後）、左手は `.trailing` 寄せ（左手の左寄せは本人の選び、言葉だけ。§0.4）。
- **題名だけが縮む**。ボタンは全部 `fixedSize` ＋ `layoutPriority(1)`（96dafab の約束、`PageHeaderView.swift:62-68` の注）。
- 閲覧専用の印は広い行だけ、切り替えと ＋予定 の間（M5_CONTRACT §3.2 の「＋予定 の左」、`docs/M5_CONTRACT.md:482`。左手では鏡）。狭い行は今の注意の行（`readOnlyNotice`、`CalendarRootScreen.swift:883`）のまま。
- 「‹ 今日 ›」と等倍は、読み取り専用でも押せる（`GatedAction.navigate`・`.zoom` はいつも許す【事実】: `CalendarRootScreen.swift:27-42`）。
- 理由: 本人の言葉の受け取り方 (a)（§0.4 の並べ方 (a)）。日付はボタンのすぐ後に続き、ボタンは動かない。「今日」が右の組から抜けるので、印の場所を決め直す必要がある。

### 3.5 広い行を測る（0e-6）

- 広い行は今まで測ったことが無く、場所の数は全部推定（批評）。見出しを決める前に測る: 新しい `HeaderRoomUITests`（ログだけ。合否は下の関門で読む）を blank-paper の機種の回し（ipad13・ipadmini・ipad11・iphone69、`build.yml` の blank-paper の段の機種の表。blank-paper の ipad11 は本人の iPad Air 11、820 pt）と、ui-tests の iPhone 17 の横で走らせ、◀・今日・▶・Z・題名・切り替え・＋予定・☁・⚙ の枠を `header room:` の行に書く。
  - iPad は縦で測る。iphone69 は縦では 2 段の行で広い行が無いので、XCUI で横に回してから（`XCUIDevice.shared.orientation = .landscapeLeft`）広い行を測る。縦の 1 段目の場所も別の行に書く（記録だけ）。
- 推定（設計。固定部分は列の幅 760 未満で約 581.4 pt、760 以上で「＋予定」が字つきになり約 608.4 pt）: ja の題名の場所は mini の縦（744）で約 163、Air 11 の縦（820）で約 211、Pro 13 の縦で約 367、iPhone 17 の横（750）で約 169、18 Pro Max の横（956 − 2 × 62 = 832。760 以上）で約 224【推定】。
- **関門 D1a**: ja の広い日の題「2026年10月15日(木)」が、mini・Air 11・Pro 13 の縦で 115 pt 以上。足りなければ、760 未満の行の間隔を 4 にする（12 pt 増える）。
- 祝日の名前つきの ja の日の題（1 つの字。例「2026年11月23日(月) 勤労感謝の日」）は、1.4 と同じく「…」で切れる。切れたことを記録する。
- 600〜700 pt の窓（Split View の 678、Duo の内側）では、題名が小さいか切れることがある。記録するだけで、そのための形は作らない。
- 参照: `HeaderAndPaperUITests.swift:159-162`（ログの形）、`docs/M4B_CONTRACT.md:577`（狭い行の幅の計算）。

### 3.6 等倍の意味（0e-7）

- **等倍 = 比 1 = 今のキャンバスの範囲の `ZoomPolicy.Bounds.open`**。どのページもすでにこの倍率で開く（`TegakiKit/Sources/Layout/ZoomPolicy.swift:112-150`: `open` は `baseSize` の `fitAll`、`min` は min(open, 一覧の fitAll)）。`zoomScale` 1.0 ではない（本人の 440 pt の iPhone の月で開く倍率の約 3.2 倍、批評）。幅に合わせる `fit` でもない。
  - 週と日: 一覧は固定の格子なので `min == open`。等倍は拡大を戻すだけ。
  - 月と年: open より小さくつまんだページも、open まで戻す。
  - 横につながった週・日: 帯の open。iPhone の横と Duo の外側の横では上限（週 3・日 5）で、`cappedBounds`（`ZoomPolicy.swift:152-167`）が open を上げた値。
- ボタンは**いつも見えて、いつも押せる**（薄くしない・並びが動かない・キャンバスから新しい出力を取らない）。open のときに押しても何も起きない。読み取り専用でも押せる。キーボードのショートカットは付けない（⌘0 は記録）。
- 画面の側は `CalendarRootScreen`（凍結でない）: `@State private var zoomResetTrigger = 0` と `func resetZoom() { zoomResetTrigger += 1 }`。2 つの `InkCanvasView`（1 ページ `:1107`、横の道 `:2832`）の最後の引数に渡す（`:1165` の `bottomClearance:` の後、`:2900` の `onSpanStop: spanStopped` の後）。
- `goToday`（`CalendarRootScreen.swift:1604-1627`）と `ScreenPaths.today` は替えない。**今日は倍率を変えない**（`ScreenPathsSpanTests.swift:1228-1250` のピン留め）。
- 理由: 比 1 は、アプリがもう「拡大していない」として覚えている値。薄くする形は `finishZoom`・`containerDidLayout` に新しい出力が要り、足すだけの変更でなくなる。

### 3.7 キャンバスの仕組み（0e-8）

- 凍結の表の 1 行目（`InkCanvasView.swift`）だけを作り直し、**足す行**で作る（§5.4）:
  1. `var zoomResetTrigger: Int = 0` を `onSpanStop`（`:243`）の後に。注に「戻したときは onZoomRatioChange で 1 を知らせる」。今の注は直さない。
  2. Coordinator に `private var lastZoomResetTrigger: Int`。init で `lastRevealTrigger`（`:640`）の隣に入れる。
  3. `update(from:)` の step 8 を step 7（`:987-993`、`revealTrigger`）の後に。値が変わったら覚えて `Task { @MainActor [weak self] in self?.resetZoomToOpen() }`。**SwiftUI の更新の中では動かさない**。
  4. 新しい `func resetZoomToOpen()` を `reveal()`（`:1412-1417`）のすぐ後に。最後は `scrollViewDidEndZooming(canvas, with: nil, atScale: open)`（`:2126-2149`。最初の配置 `:1229` と同じ道）なので、`finishZoom`（`:1434-1445`）が次のターンに `onZoomRatioChange(1)` と `onZoomingChange(false)` を知らせる。横の道では `turnAnchor` も消し、`requestShiftCheck()`（`:3199-3212`）を呼ぶ。
  5. DEBUG の `NSLog("zoom: reset %.4f→%.4f")`。
- 足す行は約 45 行【推定】。
- **採らなかった形**: アプリの側でキャンバスを作り直す（identity や epoch を替える）。`OnePageSession` は作り直す前のキャンバスが次のターンに渡した書き込みを捨てる（`Span/OnePageSession.swift:17-19` の注。「全て消す」などのための仕組み）ので、最後の線が消えうる。↶ と選びも消える。1 ページの道では、同じページのキャンバスの identity が替わらず、何も起きない（批評）。`CanvasCommand` に足す形も凍結のファイル（`:20`・`:1126-`）を変えるので、得が無い。
- 理由: 凍結の表に触れる所が一番小さい。`revealTrigger` で確かめ済みの形。`CanvasCommand` の case も新しい出力も無く、保存・merge・同期・墓標の行に触れない。

### 3.8 等倍の規則（0e-9）

**落とす（何も貯めない。保留の印も作らない）とき**:
- `canvas`・`container`・`lastBounds` のどれかが無い、`!hasInitialZoom`（`:468`）、`isLive`（つまみの最中、`:499-503`）、`isUsingTool`（Pencil か書く指が触れている、`:445`）、`resetScroll`（`:463`）、`isMovingSelection`（`:521`）。
- 横の道で、指が帯を押さえている・引いている（`spanState?.motionOverride ?? (canvas.isTracking || canvas.isDragging)`。`isBandMoving`（`:3214-3218`）のうち、はじいた後の滑りを除いた物）。

**`isSettling` では落とさない**: 線を離して 0.3 秒の間（`settleDelay`、`:246`・`:1779-1800`）の等倍も効く。「今日」の reveal（`:987-993`）と同じ。

**先に止める物**: 横の道ではじいた滑り・矢印の滑り（`isDecelerating`・`slideTargetX`・`queuedSlidePages`）は、`bandWidthChanged`（`:3064-3070`）と同じに止める（`slideTargetX = nil`、`queuedSlidePages = 0`、`setContentOffset(今, animated: false)`）。1 ページの道ではじいた滑りは `setContentOffset(今, animated: false)` で止める。その後に戻す。
- **テストの範囲**: XCTest でははじけない。テストの口 `motionOverride`（`InkCanvasView.swift:2597-2598`）は `isTracking`・`isDragging`・`isDecelerating` の 3 つをまとめて代わるので、true にすると上の「指が押さえている」として落ちる。だから「滑りを止めてから戻す」のテストは矢印の滑り（`slideTargetX`・`queuedSlidePages`）だけで書き、はじいた滑りを止める行はテストにしない（確かめ表の行 6 で見る）。はじきだけのテストの口は凍結のファイルに足さない（§5.4 の diff の範囲を広げないため）。

**何もしない**: |zoom − open| < 0.0005（`:1250` と同じ幅）。知らせも出さない。

**戻す順**:
1. `oldZoom`・offset・`midY = (offset.y + (h − inset.bottom) / 2) / oldZoom` を読む。
2. `canvas.zoomScale = open`、`targetZoom = open`、`applyInsets()`（`:1337-1346`）。
3. x:
   - 1 ページ: `clampedOffset`（`:1396-1406`）が真ん中に置く（open ≤ fit）。
   - 横の道: `slot = band.slot(atX: (offset.x + w / 2) / oldZoom)`（`TegakiKit/Sources/Layout/SpanLayout.swift:110`）、`x = (origin(ofSlot: slot) + pageWidth / 2) · open − w / 2`（`applyBandOpening` の規則、`:3043-3049`）。
4. `y = midY · open − (h − inset.bottom) / 2`。
5. `contentOffset = clampedOffset(x, y)`、`syncPaperFrame()`。

- 結果: open で入るページは開いたときと同じに見え、長い月・年は見ていた所のあたりが残る。
- 動かさない（アニメーションしない）。コードで替える倍率は今も全部そう（批評）なので、Reduce Motion への構えは要らない。
- 終日帯の 2 度目の落ち着き（帯が縮んで `applyBounds`（`:1297-1329`）が open で上を保ってもう 1 歩）は、起きる物として、新しいページの開いたときの倍率に収まることをテストする（§6.1）。
- 理由: 「今日」と同じ守り（Pencil やつまみの最中は動かない）。貯めずに落とすので、後の関係の無い離しで等倍が動くことが無い（審査 1 の E9）。滑りを先に止めるので、押したのに黙って無視されることが無い。

### 3.9 覚えた倍率（0e-10）

- 比 1 の知らせは、今の閉包（`CalendarRootScreen.swift:1141-1144`・`:2866-2869`）から `AppSettings.setZoomRatio(1, for: kind)` に行き、`zoomRatio.<種類>` を消す【事実】（`AppSettings.swift:310-319`: 1 なら `removeObject`）。**次に開く同じ種類のページも、アプリを開き直したときも、等倍で開く**。ほかの種類は覚えたまま。
- 画面は自分では何も書かない。落とした押しは何も変えない。写真モードでは書かない（今の `guard !ScreenshotMode.isActive`）。
- `hasPinched`（`AppSettings.swift:322-324`）が false に戻ることがある。害は無い: `hint.pinchShown`（`AppSettings.swift:69`）は本当のつまみで書かれていて、ピン留めの `testPinchHintDue`（`CalendarRootScreenTests.swift:489-509`）は変わらない。
- 本人には §0.6、SUPPORT の拡大の FAQ（§8.5）、確かめ表の行 8 で伝える。
- 理由: 「すぐに等倍に戻る」の単純で一貫した意味。「このページだけ」は、戻すときに `finishZoom` の知らせを飛ばす必要があり、凍結の変更が増える（批評の design_implications）。

### 3.10 幅が変わったときの真ん中（0d-44 の直し。0e-11）

- `containerDidLayout` の step 4（幅が変わった、`InkCanvasView.swift:1245-1274`）の `centerPaper` の 2 行（`:1258`・`:1259`）で、`viewport.width`・`viewport.height` を **`lastLayoutSize.width`・`lastLayoutSize.height`**（前の大きさ）に替える。`lastLayoutSize` は step 6（`:1283`）で新しい大きさになるので、step 4 の中では前の大きさ【事実】。**今の 2 行を変える**ので、記録にその 2 行を名前で書く（§5.4）。
- **直しを残すのは、ピン留めのテストが全部そのまま通るときだけ**: `InkCanvasViewTests`（回転・開く・最小。例 `testRotationKeepsTheOverviewAndTheAbsoluteZoom`、`InkCanvasViewTests.swift:417-458`）、`InkCanvasSpanTests`（回転の真ん中）、`DuoFoldTests`。新しい `InkCanvasWidthCentreTests` も緑。
- どれかが落ちたら 2 行を戻し、0d-44 は「受けて記録」のまま。確かめ表に「拡大しているときにツールバーを左右へ動かすと、紙が約 37 pt 横にずれる（前からの動き）」の行を足す。
- `SpanGuard .prototype`（19 行目）は残す。決めて記録し、19 行目を作り直す次の版へ送る（§1.5）。
- 理由: 1.4 がこの直しを 1.4.1 に約束した（`docs/M7D_CONTRACT.md:141`・`:1124`）。左右に置くと幅の変化がふつうに起きる: 拡大中に左右に置くたびに、1 ページの紙が枠の半分（37 pt）ずれる。横の道は `layoutMid` で前から戻している（`:3051-3078`）。

---

## 4. 利き手とツールバーを動かす

### 4.1 利き手の設定（0e-12）

- 鍵 `AppSettings.handKey = "layout.hand"`、String の "right" か "left"。`enum Hand: String` に `init(stored:)`: 無い・知らない字・文字列でない値は `.right`（`ToolbarEdge(stored:)`、`ToolbarLogic.swift:26-28` と同じ形）。
- **端末ごと**（UserDefaults。理由の印は今の `CA92.1`、`Sources/TegakiCalendar/PrivacyInfo.xcprivacy:18`）。iCloud に送らない。`isExistingUser`（`AppSettings.swift:128`）の鍵ではない。移し替えの処理は要らない（無ければ右手）。
- `CalendarRootScreen` が `@AppStorage` で読み、`PageHeaderView(hand:)` に渡す（すぐ替わる）。
- 設定の画面: `SettingsScreen.inputSections`（`@ViewBuilder`、`SettingsScreen.swift:443-474`）の**最後**に新しい `Section`。ピン留めの `Form` の 9 つの並び（`SettingsPageSectionTests.swift:124-137`）、`pageSection` の行、`Sheet` の 11、`SettingsSection` の ["page"]（`ScreenshotModeSpanTests.swift:673-674`）は変えない。
  - `Picker(selection: $hand) { 右手 .tag(.right); 左手 .tag(.left) }.pickerStyle(.inline).labelsHidden()`: チェックの 2 行。
  - 見出し `settings.hand.header`、脚注 `settings.hand.footer`（iPad と iPhone で 1 つのキー。Pencil の語を入れない）、identifier `"settings.hand"`。
  - `.onChange`（写真モードでは書かない）で `layout.hand` を書き、`toolbar.collapsedEdge` を 1 回書く: 右手 → leading、左手 → trailing。
- 写真モード: `--screenshot-hand left`（`ScreenshotMode.Config.hand: Hand? = nil`）。保存しない。
- 理由: String の 2 択の形はもうある（`AppSettings.swift:56-58`・`:160-164`）。`inputSections` の中の `Section` なら、`SettingsPageSectionTests` と `ScreenshotModeSpanTests` はそのまま通る（批評の facts）。`AppSettingsTests.testToolbarKeys`（`AppSettingsTests.swift:157-192`）の形で鍵を試す。

### 4.2 左手で替わる物・替わらない物（0e-13）

**替わる物**:
1. 見出しの部品の順（どの行も。§3.2）。題名は「‹ 今日 ›」の横で右寄せ、Z は 2 段目の右の端。
2. しまった丸いボタンの角（§4.1 の 1 回の書き込み）。丸いボタンの中の並びは、もう角に従う（`ToolbarDock.swift:22-30`）。長押しと VoiceOver の操作（`ToolbarDock.swift:37-44`・`:63-64`）で後から動かせ、最後の操作が勝つ。

**替わらない物**:
- 紙（時刻の欄・日のメモの列・年の札。手書きは紙の座標 lu で共通。`TegakiKit/Sources/Layout/PaperSpec.swift:47-52` の週の時刻の欄 64 lu が左）、貼り付く見出し、終日帯、横の道の滑る向き。
- 日週月年の順、◀ が ▶ の左、山形の記号と ↶↷ の向き。
- ツールバーの中の順（道具 → … → しまう）。`ToolbarFitTests` の「左から見える物」の約束（`ToolbarFitTests.swift:55`）と、`EraserAndBelowDayUITests` の「しまう」が右の端の前提（`EraserAndBelowDayUITests.swift:630-646`）を守る。
- ツールバーの辺（利き手と別）。
- トースト・横の道の案内・投げなわのメニュー・注意・シート・確かめの画面・字の寄せ。
- VoiceOver は両方とも見た目の順に読む（左手は ⚙ から）。`sortPriority` は使わない。
- 理由: 空いている手の側に、その手で押すボタンを寄せる。紙や読む順に結びついた物は動かさない。手と辺を結ぶと、思わぬ組み合わせが出る。

### 4.3 動かせる辺（0e-14）

- 純粋な関数 `ToolbarLogic.allowedEdges(isPad:windowSize:column:paperColumnHeight:)`。端末の種類（idiom）は自分では読まず、画面が `pencilPhone.isPad`（`CalendarRootScreen.swift:202`、`tools/duo/idiom-allow.txt` の 2 行目の値）を渡す。新しい idiom の読みは作らず、`idiom-allow.txt` は変えない。
  - iPhone（`isPad` が false。Duo の外側と内側、Mac の iPhone ミラーリングの広い窓も。窓の大きさに関わらず）: 下だけ。本人に伝えた「iPhone は下のまま」（§1.2）。
  - iPad の下: いつも。
  - iPad の上: `WindowClass.isWide(windowSize)`（短い辺 ≥ 600、`TegakiKit/Sources/Layout/WindowClass.swift:15-22`）。
  - iPad の左右: `isWide`、かつ列の幅 ≥ 700、かつ見出しの下の紙の列の高さ ≥ 460。**700 の下限で、狭めた紙の列はいつも 626 以上**になり、`smallScreen`（`usesMinTapTarget`、`CalendarRootScreen.swift:1106`・`:1847-1849`: `isPhone || width < 600`）が置いた途端に替わることが無い。
- 結果【推定。`ToolbarPlacementTests` の表で固める】:
  - 本人の mini・Air 11・Pro 13: 縦も横も 4 つ全部。
  - どの iPhone も（iPhone の横（18 Pro Max の 956×440）、Duo の外側（466×678）と内側（推定 626〜669 × 951 前後、縦も横も））: 下だけ、つまみ無し。**1.4 のツールバーそのまま**。
  - 短い辺が 600 未満の iPad の窓（Slide Over、13 インチの縦の ½ の Split View（約 512）、11 インチと mini の横の ½（約 586・562）など【推定】）: 下だけ、つまみ無し。1.4 のツールバーそのまま。
  - 678 の Split View（13 インチの横の ⅔）と、13 インチの横の ½ の Split View（約 683×1032【推定】。短い辺が 600 以上、列が 700 未満）: 上と下（つまみつき。下のバーは §4.5 の間隔 0 ＋ 8 になる）。
- `PaletteEdge`（bottom・top・left・right）に `init(stored:)` → bottom。`effectiveEdge(stored:allowed:)` = 許されていれば stored、でなければ bottom。**stored はこれで書き換えない**。
- 理由: Apple のパレットも、幅の広い窓でだけ動かせ、iPhone では下に固定（WWDC19・WWDC24・HIG。§13.2）。iPhone を下だけにするのは本人に伝えた約束（§1.2）で、Duo の内側は CI で開けず（duo.yml の道 3、`docs/M7D.md:30`・`:368`、`WindowClass.swift:12-14`・`:35-39`）、本人も Duo を持たないので、だれも確かめられない形を作らない。idiom の値を今の `pencilPhone.isPad` から読むのは、`ScreenPaths.device(isPad:)`（`idiom-allow.txt` の 4 行目。Duo は .iPhone のまま）と同じ考え。700 の下限は審査の指摘（520 の下限・高さだけの規則では `smallScreen` が替わる、審査 1 の E6・E8・M4、審査 2 の E7・M4）への答え。Duo の内側の行（審査 1 の E1、審査 2 の E8）は、設計の「上と下」から「下だけ」に替えた（契約の第 2 版、§14）。

### 4.4 置き場所ごとの枠と紙の領域（0e-15）

**どの修飾子と枠もいつも付けたままにし、中身だけを替える**（付けたり外したりすると、キャンバスが作り直され、台帳・倍率・位置を失う。`CalendarRootScreen.swift:737-740` の注）。

- **開いて下**: 1.4 の `.safeAreaInset(edge: .bottom)`（`:740`）。許される辺が下だけのとき（iPhone とほかの 1 辺だけの窓）は、行・`spacing: nil`・バーが 1.4 とまったく同じ。
- **開いて上**: 下の inset は空で `spacing: 0`。`screenColumn` の中の、`readOnlyNotice`（`:883`）と `StickyHeaderView`（`:884`）の間の上の枠にバーを置く: 横 12、上 6、紙との間 8、全部で 74 pt。紙の領域は下に開いたときと同じ（同じ倍率）。紙が 74 pt 下がる。
- **開いて左・右**: 下の inset は空。`StickyHeaderView` と帯・キャンバスの `GeometryReader`（`:884-919`）を、いつも `HStack(spacing: 0) { 左の枠?; VStack; 右の枠? }` で包む。枠は幅 74（外 6 ＋ バー 60 ＋ 紙との間 8）で、見出しと注意の行の下から始まる。**見出しは全部の幅のまま**で、狭い・広いの決め方（`:852`）も同じ。
  - 列の幅（`proxy.size.width − 74`）を `shownViewport(width:)`（`:553`）・`pathCanvas(viewportWidth:)`（`:3111`）・`estimatedZoom`（`:576`）・`smallScreen`（`:1106`）に渡す。
  - キャンバスから見ると幅が 1 回変わるだけ: open なら open のまま。拡大中なら、拡大の絶対値を保ち、0e-11 で真ん中も保つ。横の道は `bandWidthChanged`（`InkCanvasView.swift:3060-`）。
- **しまった状態**: 1.4 のまま。丸いボタンは下の角、`bottomClearance = paperBottomClearance(mode)` は 0/60/60 で同じ、`dockClearance` 60（`ToolbarLogic.swift:108`・`:267-271`）。
- 理由: 1.1 から、開いたバーは紙に重ならない（`docs/M7A.md:397-406` の実測 +74）。凍結のキャンバスには下の余白しか無い（`applyInsets` は上 0・左右は真ん中・下は `bottomClearance`、`InkCanvasView.swift:1337-1346`）ので、上や横に重ねると、スクロールしても出せない紙が隠れる。
- `ToolbarLogic.swift:11-16` の注の「66 pt」は古い（実測 74）。同じ commit で 74 に直す（§1.5）。

### 4.5 つまみ（0e-16）

- **開いていて、許す辺が 2 つ以上のときだけ**、バーの画面の真ん中に向いた辺に出す（下のバーの上の辺、上のバーの下の辺、横のバーの内側の辺）。
- 見た目: 36×5 の `Capsule`、`secondaryLabel` の色。
- **当たりの範囲は、いつもその枠の中**: 下と上は 120×16 pt（紙との間 8 ＋ バーの余白 8）、横は 14×120（紙との間 8 ＋ バーの余白 6）。行のボタンと紙には重ならない。
  - **横の行では、バーの余白 8 は `ScrollView` の中**（`ToolbarView.swift:84-101`: `.padding(.vertical, 8)` が `ScrollView(.horizontal)` の中身に付く）。だから当たりの半分（bar.minY〜bar.minY ＋ 8、真ん中の 120 pt）は行の `ScrollView` に重なり、そこから始めた横のスクロールはつまみが受ける（ツールバーが動く）。行のボタンの高さ（その下の 44 pt）から始めたスクロールと、真ん中の 120 pt の外からのスクロールは変わらない。`EraserAndBelowDayUITests` の行のドラッグ（`:630-646`）はボタンの midY から引くので変わらない。行がスクロールするのは 13 インチより狭い iPad（mini・11 インチ。`ToolbarLogic.swift:278-281`）なので、確かめ表の行 15 で見る。
  - 縦のバーは新しいので、横の余白 6 を `ScrollView` の外に付け、当たりが `ScrollView` に重ならないようにする（§4.8）。
  - 当たりの範囲は `PaletteGripView`（UIView）の枠そのもの。その UIView を 120×16（横は 14×120）の大きさで置き、36×5 の印はその中に描く（下のバーの上の 8 pt の間は何も描かないので、UIView の枠で触れを受ける）。
- **つまみのある下のバー**: inset の `spacing: 0` にし、バーに `.padding(.top, ToolbarLogic.expandedBottomGap = 8)`。全部で 74 pt のまま。関門 3 で iPad で示し、`PaletteMoveUITests` で 13 インチの「ペン」の minY − 16 = キャンバスの下を確かめる（`YearTapUITests.swift:15-17`・`:85-95` の前提）。
- 丸いボタンとのぞきにはつまみを付けない。
- 理由: 8 pt の帯だけでは指に細すぎる。inset の間隔（中身の枠の外）への触れは、つまみに届く保証が無い（審査 1 の M6）。iPhone は 1 バイトも同じ。iPad の窓だけが明示の 8 を取る（J-4 の違ってよい (2)、§7.1）。

### 4.6 入力と手のひらの規則（0e-17）

- `PaletteGripView` は `UIViewRepresentable` で、`UIPanGestureRecognizer` を持つ。`allowedTouchTypes = [.direct, .indirectPointer]`（指・トラックパッド・マウス）。**Pencil は入れない**。
- 10 pt 動いてから始まる。
- `gestureRecognizerShouldBegin` は、凍結の静的な規則 `InkCanvasView.horizontalPanMayBegin(pencilsDown:lastPencilUp:now:)`（`InkCanvasView.swift:2432-2440`: Pencil が触れている、または離して 0.5 秒（`palmHold`、`:2414`）未満なら false）の答え。
- その入力は、アプリの側の新しい `PalmWatch` が作る。`PalmWatch` は**凍結の `InkTouchObserver`（ファイルは変えない、`InkTouchObserver.swift:19-38`）の新しいインスタンス**を窓に付ける（同時の認識の delegate）。許す辺が 2 つ以上のときだけ付け、そうでなければ外す。**iPad に付ける新しい道**: 今の `PencilPhone.attach` は iPad ではすぐ返る（`Support/PencilPhone.swift:138-139` の `guard !isPad`）。記録で 1.4 の 0d-39「iPad には付けない」（`docs/M7D_CONTRACT.md:1119`）を「`PencilPhone` は iPad に付けない」に狭める。
- **走っているドラッグを取り消す時**: PalmWatch の Pencil の触れ、`penDown()`（`CalendarRootScreen.swift:1042-1056`）の**最初の行**（`guard` より前）、場面が背景へ（`scenePhase`、`:754`・`:1419`）、`windowSize` の変化、シートが開く（自分の `.onChange(of: sheetIsUp)` で。ピン留めの `sheetsChanged()`（`:2384-2390`）の `if sheetIsUp { guide.dismiss() } else { … }` の中には書かない）。
- **ピン留めのソースの字は 1 字も替えない**（全部の一覧は §5.6）: `onPenDown: { guide.close() penDown() }` と `guide.close()` が 3 つ（`SpanGuideSeenSpanTests.swift:264-268`）、`guide.dismiss()` が 3 つと `sheetsChanged()` の `if`（同じテストの `:269-273`）、`joinedCanvas` の頭の字、` revealRect: paths.revealRect(revealRect, for: span), ` と ` revealRect: revealRect,` が 1 つ（`ScreenPathsSpanTests.swift:1932-1938`）。
- 理由: この手のひらの規則はアプリ自身の物（1.3 の横の道）。`onPenDown` は線の書き始めにしか来ない（`docs/M7A_CONTRACT.md:390`）ので、「onPenDown の 1 秒後」の規則は長い線を見逃す（審査 1 の E4、審査 2 の E5）。`containerDidLayout` の step 4 は `!live` でしか守られず、`!isUsingTool` では守られない（`InkCanvasView.swift:1256`）ので、書いている途中に紙を並べ直すことは避ける。

### 4.7 動かしている間と、吸い付き（0e-18）

**動かしている間は、何も並べ直さない**:
- バーは今の枠に残り、40 % の不透明さ（開いたまま。本人の「ひらいたまま」）。紙の領域は変わらない。
- `arranged`（画面の並びの外側）に重ねた押せない丸（puck、`allowsHitTesting(false)`）: `ToolbarDock` の見た目の 96×48（`ToolbarLogic.pillWidth`・`pillHeight`、`:98`・`:104`）に今の道具の印、指の 40 pt 上。
- 許す辺ごとに、置いたときの枠の輪郭（アクセントの色 12 %）。吸い付く先は 28 % と 2 pt の縁。

**吸い付き**（純粋な `ToolbarLogic.snapEdge(drop:velocity:frame:allowed:current:)`）:
- 離した所を、速さ × 0.15 秒だけ先へ進め、枠の中に収める。
- 真ん中の動かない範囲（枠を各辺 25 % 内側にした所）なら、今の辺のまま。
- そうでなければ、許す辺のうち一番近い辺。同じ距離なら今の辺、次に下・上・左・右の順。

**離した時**:
- 結果が覚えている値と違えば書く。
- 置き場所を、動かない 1 つのトランザクション（`Transaction.disablesAnimations`）で替える。キャンバスから見ると、回転と同じく大きさが 1 回変わるだけ。
- puck と輪郭は消える（不透明さだけ）。
- `ToolbarEvent.placementChosen` を `step` に: `(.expanded, .placementChosen)` → `ToolbarStep(mode: .expanded, storesPlacement: true)`（新しい欄、既定 false）。今の表（`ToolbarLogic.swift:235-250`）のほかの行は同じ。
- 理由: 1.1 の D1 の決まり（書いているペンの下で倍率を動かさない、`docs/M7A_CONTRACT.md:11`）。動かない範囲と一番近い辺の規則で、手のひらが少し引いても今の辺に戻る。1 つのトランザクションで、アニメーションの途中に `containerDidLayout` が何度も呼ばれることを避ける（審査 2 の M5）。

### 4.8 縦のツールバー（0e-19）

- `ToolbarView(axis: .vertical)`。既定の `.horizontal` は 1.4 の道と呼び出しのまま。
- **`ToolbarView(` の呼び出しは今の 1 つ（`toolbar`、`CalendarRootScreen.swift:980-993`）のまま**: `toolbar` を axis を受ける形（例 `toolbar(axis:)`）にし、縦のバーもそこから作る。2 つ目の `ToolbarView(… allowFinger: allowFingerBinding …)` を書くと、`allowFinger: allowFingerBinding,` が 3 つになり、`PencilPhoneTests.testPersonSetMarksThePerson`（`PencilPhoneTests.swift:188-194`。ちょうど 2 つ）が落ちる（§5.6）。
- 幅 60 pt（6 ＋ 48 ＋ 6）。横の余白 6 は `ScrollView` の外に付ける（§4.5）。同じ素材・角 16 pt・影（`ToolbarView.swift:57-66`）。枠の高さいっぱい。
- `ScrollView(.vertical)` を上から、終わりに 12 pt の薄れ（横の行の `fadeWidth` と同じ考え、`ToolbarView.swift:103-112`）。中身:
  - 道具 5 つ（48×44、10 pt の名前、F-12 の枠。`ToolbarLogic.Row`、`ToolbarLogic.swift:282-322`）
  - 幅 24 の区切り
  - 色（ペン 6・マーカー 4【事実】: `Ink/InkTools.swift:49-50`。マスは 44×38）
  - 細中太（ペンのときだけ、高さ 44）
  - ↶ ↷（44×44）
  - 指でも書く は、印だけの `hand.draw` の切り替え 44×44（名前「指でも書く」とヒントは今のまま、`ToolbarView.swift:312-317`）
- 区切りの下、スクロールの外に「しまう」（`chevron.down`）。
- 消しゴム・投げなわ・予定の説明の行（`ToolbarView.swift:211-216` の `hint`）は描かない。その道具のボタンの `accessibilityHint` にする。
- identifier は全部同じ（`tool.pen` など、`LanguageUITests.swift:41` が読む）。
- ペンのときの長さ約 830 pt【推定】: iPad の縦と Pro 13 の横は全部入り、mini（約 644）と Air（約 720）の横ではスクロールする。
- 理由: 細い 1 列なら紙が 74 pt しか減らない。説明の文を残す広い 2 列の形（設計の 3 つの案のうち owner 案の形、134 pt。本人の依頼ではない）は、本人への言葉の選び（§0.4）。

### 4.9 のぞき・丸いボタン・トースト（0e-20）

- 丸いボタンを押したときののぞき（peek）は、**今の辺に重ねて**出す: 下は 1.4 のまま（`CalendarRootScreen.swift:694-704`）、上は紙の列の上、左右はその側に縦で。紙の領域は変えず、覚えず、Pencil が触れた・「しまう」・背景でしまう（1.4 と同じ。`ToolbarLogic.swift:239-240`）。
- 左に置いたら `toolbar.collapsedEdge = leading`、右なら `trailing` を書く。上と下では替えない。だから左右の端から「しまう」と、その側の下の角に丸いボタンが出る。長押しで今までどおり替えられる。
- トースト: `toastBottomPadding(mode)` は 8/62/74 のまま（`ToolbarLogic.swift:256-265`）。新しい `toastSideInset` が、左右に開いているときその側に 74 を足す。
- 理由: のぞきは、バーがあった所に出す（Apple の小さくなったパレットも元の所に戻る、§13.2）。丸いボタンの角は最後の操作に従う。

### 4.10 覚え方・回転・写真モード（0e-21）

- 新しい鍵 `"toolbar.paletteEdge"`（bottom・top・left・right。無い・知らない字は bottom）。端末ごと、向きを問わず 1 つ。iCloud に送らない。
- 書くのは、離した時と VoiceOver の操作の時だけ。写真モードでは書かない。`toolbar.collapsed` の意味は同じ。
- **写真モードの辺**: 写真モードでは、離した結果（と VoiceOver の操作の結果）を画面の `@State` の辺にだけ持つ。初めの値は `--screenshot-palette`（無ければ下）。効く辺は、写真モードではこの `@State` から、ふだんは `@AppStorage(AppSettings.paletteEdgeKey)` から読む。だから写真モードで走る `PaletteMoveUITests`（`toolbar: paperArea=` の行は写真モードでしか出ない、`CalendarRootScreen.swift:611-616`）でバーは動き、`toolbar.paletteEdge` は書かれない（MS2 の守り）。左手（`--screenshot-hand`）と `collapsedEdge` も、写真モードでは同じく書かない。
- 回転・Split View・Stage Manager: 効く辺 = 許されていれば覚えた辺、でなければ下。覚えた値は残り、許されればまた戻る。走っているドラッグは取り消す。
- 新しい写真モードの引数: `--screenshot-palette top|left|right` と `--screenshot-palette-drag <辺>`（動かしている途中の見た目。確認ページだけ）。Config の欄の既定は nil。
- **変えない**: `--screenshot-toolbar` の値（`ScreenshotModeTests.swift:365-382`）、`StartState` の 5 つの欄（`CalendarRootScreen.swift:395-402`、`CalendarRootScreenTests.swift:406-428`）、`toolbar: paperArea=`・`toolbar: safeArea=` の行の形（`CalendarRootScreen.swift:629-635`、`CalendarRootScreenTests.swift:479-482`）。別の行 `toolbar: palette=<辺> allowed=<辺の並び>` を足す。
- 理由: ピン留めの `CalendarRootScreenTests` と `ScreenshotModeTests`（`TESTS_1_2_3` の 3・6 行目）がその形と値を固めている。

### 4.11 VoiceOver（0e-22）

- つまみは 1 つの要素「ツールバーを動かす」（`toolbar.grip.spoken`）、ヒント `toolbar.grip.hint`（「上下左右の端へ移せます」）。
- 今の辺のほかの許す辺ごとに、操作「上へ移す」「下へ移す」「左へ移す」「右へ移す」（`toolbar.moveTo.*`）。
- 操作は離したときと同じに辺を書き、`UIAccessibility` の `.layoutChanged` を出す。
- スイッチコントロールとフルキーボードアクセスも同じ操作を使う。
- 理由: Apple はパレットを VoiceOver で動かす方法を文書に書いていない。HIG は動かせる道を用意するよう勧める（§13.2）。丸いボタンにはもう操作がある（`ToolbarDock.swift:63-64`）。

### 4.12 Apple のパレットとの違い（本人への言い方）

- 【事実（Apple の文書。設計の調べ役が 11/21 に読んだ、§13.2）】iPad のパレットは画面のどの辺へもドラッグで動かせる。狭い幅（iPhone・Slide Over・細い Split View）では下に固定。
- 【未確認（第三者の資料・利用者の報告・記憶）】動かしている間に今の道具の丸に縮む、左右で縦に立つ、角で小さな丸として留まる、辺の上の位置（上寄りなど）を覚える。Pencil で動かせるか。
- このアプリは `PKToolPicker` を使えない（投げなわで選んだ線を読めない、「予定」の道具を足せない。`docs/DESIGN.md:225`・`:405-407`）ので、自前で作る。
- 本人には「4 つの端に吸い付く」ことと、このアプリがすること・しないことを言い、細かい所を「Apple と同じ」とは言わない。お手元のメモと違う所に気づいたら教えてもらう（任意。確かめ表の行ではない。§0.6・§11）。

---

## 5. データ互換

### 5.1 保存の形（変えない）

- 新しいページ id・マス名・線の項目を作らない。`v` と書き出し `tegaki-app-export` v1 を上げない（K-5）。**1.4.1 は新しい保存の形を書かない**ので、新しい fixture は無い。`tools/compat-span/EXPECTED_MIN`（599）と `tools/compat10/EXPECTED_MIN`（225）は変えない。
- 新しい鍵は端末の UserDefaults の 2 つだけ（`layout.hand`・`toolbar.paletteEdge`）。手書きのデータではなく、iCloud にも書き出しにも入らない。App Privacy（データの収集なし）も変わらない。

### 5.2 K-1〜K-11 とこの版での当てはめ

規則の正文は [M7_PLAN.md](M7_PLAN.md) §1.3。

| 規則 | 1.4.1 での当てはめ |
| --- | --- |
| K-1 `allday` で始まる名前を使わない | 新しい名前は無い |
| K-2 同じ id の線を付け替えない | 台帳のコードを変えない。等倍は倍率と位置だけで、線に触れない |
| K-3 1 つのページに 2 枚のキャンバスで書かない | キャンバスを作り直さない（0e-8 で identity・epoch の形を採らなかった）。置き場所の修飾子と枠はいつも付けたまま（0e-15） |
| K-4 マスの意味を変えない | 変えない（紙は左手でも同じ、0e-13） |
| K-5 線に項目を足さない、`v`・v1 を上げない | 足さない・上げない。InkModel の 9 ファイルは 1 バイトも変えない |
| K-6 伸びる紙の一覧は固定部分 | 変えない（`ZoomPolicy` を変えない） |
| K-7 互換テストは古い版の本物のコードで | 1.0・<1.1.1>・1.2.3・1.3（955fe67）の相手をそのまま走らせる（§5.3） |
| K-8 古い端末での見え方を新機能の文に | 新しい欄も形も無いので、新機能の文に K-8 の句は入れない |
| K-9 線の予算 | 変えない |
| K-10 名前の文字 | 新しい名前が無い |
| K-11 週の始まりとページ | 変えない |

### 5.3 互換の相手（変えない）

- compat-v1-0（macos-26・Xcode 26.6）で、1.0（a21e469）・1.2.3（43fe366）・1.3（955fe67）の本物のコードが今の fixture を読む。1.4 の最後の通しの run の数: compat10 599・失敗 0、span-compat 1.0 274・<1.1.1> 274・1.2.3 278・1.3 310（どれも失敗 0）、`Real13LedgerTests` 5/5【事実】（M7D.md「通しの run」）。
- 1.4.1 は凍結の 1 行目（`InkCanvasView.swift`）を作り直すので、この相手が**行の見直しの前の関門**になる（§5.4 の 4）。古い版の木は変えない。

### 5.4 凍結の表（`tools/compat10/DATA_1_1.sha256`、20 行）

**1.4.1 で変えてよい行: 1 行目だけ**（0e-8・0e-11）。2〜20 行目は変えない。`lint-skip.txt` も同じ 20 行（今 20 行【事実】）。

| 行 | ファイル | 1.4.1 |
| --- | --- | --- |
| 1 | `Ink/InkCanvasView.swift` | **作り直す**。足す行（入力 `zoomResetTrigger`、`lastZoomResetTrigger` の宣言と `:640` の隣の初期化、`:987-993` の後の step 8、`:1412-1417` の後の `resetZoomToOpen()`、DEBUG の NSLog）と、`:1258`・`:1259` の `centerPaper` の 2 行（0d-44）だけ |
| 2〜5 | `InkLedger`・`InkOverlayView`・`InkSnapshot`・`InkTools` | 変えない |
| 6 | `Ink/InkTouchObserver.swift` | 変えない（PalmWatch が新しいインスタンスを作って使うだけ） |
| 7〜11 | `InkTrace`・`PencilInteraction`・`InkPageStore`・`InkPageRecord`・`SyncEngine` | 変えない |
| 12〜20 | `TegakiKit/Sources/InkModel/` の 9 ファイル | **変えない（例外なし）**。19 行目 `SpanGuard` の `.prototype` は残す（0e-11） |

**作り直しの手順**（M7D_CONTRACT §5.4 の 3〜6 の形。D1a の 1 つの commit）:
1. 同じ commit で表の 1 行目を書き直す。
2. 手元で `lint-skip.txt` からそのファイルを一時的に外して `lint.py` が OK、元の 20 行に戻す。
3. `docs/R1_4_1.md` に: commit・足した全部の行・変えた step 4 の 2 行・1 ページの道と横の道のどちらが通るか・理由・その行を通る既存のテストの名前。
4. **行の見直しの前に緑**: 互換の相手（本物の 1.3 の `Real13LedgerTests`・span-compat v13・compat10 599）、保存のバイトの関門 2（§5.7）、`TESTS_1_3` と `TESTS_1_2_3` がそのまま、J-4。
5. リードがその diff を 1 行ずつ見て、`docs/R1_4_1.md` に「リードの決定」として書く。本人には最後の報告で知らせる。
6. 同じ commit で `build.yml:438` の段の名前を「Data code frozen (re-based in 1.4.1)」にする（C の 1 行。この commit だけ 2 役のファイルが入る）。

- **diff の範囲**: 上の足す行と 2 行だけ。`CanvasCommand` の case、新しい出力、保存・merge・同期・墓標・台帳の行は無い。今の注も直さない。
- 0d-44 の 2 行は、ピン留めのテストが 1 つでも結果を変えたら戻し、0d-44 は「受けて記録」のまま（§3.10）。

### 5.5 守られたテストと fixture の表（変えない）

- `tools/span/TESTS_1_3.sha256`（29 行）・`TESTS_1_2_3.sha256`（8 行）・`FIXTURES_1_3.sha256`（37 行）は 1 字も変えない【事実: 行の数は 11/21 に数えた】。中身の例: `InkCanvasViewTests`・`CalendarRootScreenTests`・`ScreenshotModeTests`（`TESTS_1_2_3` の 3・4・6 行目）、`InkCanvasSpanTests`・`ScreenPathsSpanTests`・`ScreenshotModeSpanTests`・`SettingsPageSectionTests`・`SpanGuideSeenSpanTests`・`SpanUITests`・`SpanShotsUITests`・`SpanRerunUITests`（`TESTS_1_3`）。
- 新しいテストは全部新しいファイル。今のファイルに足すのは、守られていない `AppSettingsTests`・`SettingsScreenTests`・`ToolbarLogicTests`・`ToolbarFitTests` だけ。書き直すのは守られていない `HeaderAndPaperUITests`・`PageHeaderRoomTests` だけ（§6.2）。
- 守られたテストが新しいコードで落ちたら、テストの側は直さない。コードを直す（0d-44 の 2 行なら戻す）。

### 5.6 画面の字で守られた所と、変えない数・形

`CalendarRootScreen.swift` の次の字は、空白を平らにした形で 1 字も変えない（ピン留めのテストがソースを読む）:
- `onPenDown: { guide.close() penDown() }`、`if zooming { guide.close() pinchBegan() }`、`func joinedTap(at point: CGPoint, zoom: CGFloat, smallScreen: Bool) { reviewTask?.cancel() guide.close()` の頭と、`guide.close()` がちょうど 3 つ（`SpanGuideSeenSpanTests.swift:264-268`）。
- `if sheetIsUp { guide.dismiss() } else { showSpanGuideIfCalm() }`、`if showAccountChange { guide.dismiss() } else { showSpanGuideIfCalm() }`、`Task { @MainActor in showSpanGuideIfCalm() } } } else { guide.dismiss() } }` と、`guide.dismiss()` がちょうど 3 つ（`SpanGuideSeenSpanTests.swift:269-273`。`TESTS_1_3` の 19 行目で守られる）。**§4.6 のシートが開いたときのドラッグの取り消しは、`sheetsChanged()`（`CalendarRootScreen.swift:2384-2390`）の `if` の中に書かない**。自分の `.onChange(of: sheetIsUp)` か、その `if` の外の行で。
- `allowFinger: allowFingerBinding,` がちょうど 2 つ（ToolbarView と SettingsScreen、`CalendarRootScreen.swift:931`・`:983`）と、`$allowFinger` が無いこと（`PencilPhoneTests.swift:188-194`。`TESTS_1_3` の外だが、§5.5 で書き直してよいテストに入らない）。縦のバーは今の `toolbar` から axis の引数で作り、`ToolbarView(` の呼び出しは 1 つのまま（§4.8）。
- `func joinedCanvas(_ span: SpanSession, viewportWidth: CGFloat) -> some View {`、` revealRect: paths.revealRect(revealRect, for: span), `、` revealRect: revealRect,` がちょうど 1 つ（`ScreenPathsSpanTests.swift:1932-1938`）。
- `eraseAllInk` の本体の頭 `showSettings = false paths.eraseAll(reopen: opening(kind: kind, focus: focus))` と、その中の ` revealRect = nil `、`show(kind:focus:)` の本体の ` revealRect = nil `（`ScreenPathsSpanTests.swift:1869-1875`）。
- `ScreenPathsSpanTests.swift:1840-1855` の 15 の配線の字。
- `OnePageRevealTests` が読む `remoteDeleted` と `chooseAccount` の `closed:` の中身（`OnePageRevealTests.swift:19-38`）。
- 新しい `zoomResetTrigger` の引数は各呼び出しの最後。狭めた幅は今の `viewportWidth` の引数を通す。

変えない数と形:
- `ToolbarLogic.dockClearance == 60`（`InkCanvasSpanTests.swift:1222-1223` が読む）、しまった・のぞきの `bottomClearance` 60。
- `StartState` の 5 つの欄の memberwise init、`--screenshot-toolbar` の値、`toolbar: paperArea=…`・`toolbar: safeArea=…` の形。
- 設定の `Form` の 9 つ、`Sheet.allCases.count == 11`、`SettingsSection == ["page"]`。
- `ScreenPaths.today` の意味、`hasPinched` と `pinchHintDue` の規則。
- 名前「今日」「前の◯／次の◯」（日週月年）「予定を追加」「設定」「表示の切替」と identifier `page.title`。

### 5.7 保存のバイト（関門 2）

- `InkLedgerTests.testLedgerWritesTheCompatShapes`・`ScreenshotModeTests.testDemoPagesMatchCompatFixtures`・`SpanSessionTests.testSpanSessionWritesTheCompatSpanShapes` が、作り直さずに今の fixture と 1 バイトも同じ（M7D_CONTRACT §5.6 と同じ 3 つ）。D0 と、凍結の作り直しの commit の run で見る。違えば止める。

---

## 6. テスト

新しいテストは新しいファイル。時間を待つテストは `TestSleeper`。「直しが無いとどう落ちるか」は、直しを入れる前の木（D0 の木）か、変異で確かめる。アプリと UI の変異は 1 本の枝 `r141-q-m1` にまとめ、1 回の run で落ちたテストの名前で見分ける（§6.5）。結果と run の番号を `docs/R1_4_1.md` に書く。

### 6.1 新しいテスト

| 役 | ファイル（新しい） | テスト | 直しが無いと（変異） |
| --- | --- | --- | --- |
| H | `HeaderOrderTests.swift` | arm × hand × readOnly の全部の組。左手は右手の逆。枠の中で ◀ が ▶ より前、日週月年は替わらない。印は切り替えと ＋ の間。Z はどの行でも空いている手の側 | 型が無い。MH1（左手を逆にしない）で落ちる |
| H | `HeaderGlyphTests.swift` | `UIImage(systemName: "1.magnifyingglass") != nil`（CI の iOS 27.2 のシミュレータだけで走る。iOS 17 では確かめない、§13.1 の 3） | 記号が無い OS で落ちる |
| Z | `InkCanvasZoomResetTests.swift`（凍結の `InkCanvasViewTests` の作り方を写す: `liveOverride`・`pinch()`・`probe.ratios`） | 2 倍 → open、比 1 を 1 回だけ知らせ、`canUndo` と選びが残る。open より小さく伸びた月 → open、midY の規則。open のとき: 動かず知らせも無い。live・`isUsingTool`・`resetScroll`・最初の倍率の前は落とす。**離して 0.1 秒（`isSettling`）でも効く**。作った時の既定 0 では動かない。終日帯の落ち着きが新しいページの開いた倍率に収まる | MZ1（`!isUsingTool` を外す）、MZ2（`scrollViewDidEndZooming` の知らせを飛ばす）で落ちる |
| Z | `InkCanvasSpanZoomResetTests.swift` | 横の道で拡大 → 画面の真ん中のページが真ん中に来て、ずらしの確かめが頼まれる。矢印の滑り（`slideTargetX`・`queuedSlidePages`）は止めてから戻す。`motionOverride = true`（指で押さえている・引いている）の間は落とす。はじいた滑りの止めはテストにしない（XCTest ははじけない。§3.8。確かめ表の行 6）。iPhone の横の上限 → 上限（週 3・日 5）。`turnAnchor` が消える | 型と step 8 が無い |
| Z | `InkCanvasWidthCentreTests.swift`（0d-44） | 拡大した 1 ページで 1032 → 958 → 1032 と 402 → 874 のとき、画面の真ん中の紙の点が 0.5 pt 以内で同じ。open と最小では 1.4 と同じ結果 | MZ3（2 行を戻す）で落ちる |
| T | `ToolbarPlacementTests.swift` | `allowedEdges` の表: `isPad: false` の 402×874・874×402・440×956・956×440・466×678・678×466・669×951・951×669（Duo の内側の縦と横）・1032×1376（大きな窓でも）→ 下だけ。`isPad: true` の 744×1133・1133×744・820×1180・1180×820・1032×1376・1376×1032 → 4 つ、678×1024・683×1032（13 インチの横の ½）→ 上と下、320×1024・512×1376・586×820 → 下。`snapEdge` の表（動かない範囲・はじき・許さない辺・同じ距離）。`effectiveEdge`。`step(.expanded, .placementChosen)` が覚える、ほかの状態は同じ。枠 74 と `expandedBottomGap` 8。`toastBottomPadding` 8/62/74 と `paperBottomClearance` 0/60/60 が同じ。`toastSideInset` 74 | MT1（678 で左右を許す）で落ちる |
| T | `PaletteGripTests.swift` | `allowedTouchTypes` に `.direct`・`.indirectPointer` があり `.pencil` が無い。始まりが `horizontalPanMayBegin` に従う（Pencil が触れている → false、離して 0.3 秒 → false、0.6 秒 → true）。PalmWatch は許す辺が 2 つ以上のときだけ付き、そうでなければ外れる。Pencil の触れでドラッグが取り消される | MT2（つまみが `.pencil` を許す）で落ちる |
| S | `HandSettingTests.swift` と `AppSettingsTests.testHandAndPaletteKeys`（`testToolbarKeys` の形） | 無い・知らない字・文字列でない値は右手・下。書いた値の字 | 型が無い |
| S | `ScreenshotModeHandPaletteTests.swift` | `--screenshot-hand left`・`--screenshot-palette top|left|right`・`--screenshot-palette-drag` を読む。知らない値は nil。`--screenshot-toolbar` の読みは同じ。写真モードでは辺を書かない。**写真モードで離すと見える辺は替わり、鍵は書かれない**（写真モードの辺の初めの値が `--screenshot-palette`、無ければ下。書く口が写真モードで `toolbar.paletteEdge` を書かないこと。§4.10） | MS2（写真モードで辺を書く）で落ちる |
| U | `ZoomResetUITests.swift`（ui-tests、iPhone 17。ログ `zoom-reset UI:`） | 年・週をつまんで拡大 → 貼り付く見出しの列の幅が増える。`header.zoomReset` を押す → 幅が 0.5 pt 以内で戻る。開き直しても等倍。横につながった週の横で等倍 → 3 週が横に並ぶ（列の幅 = vw × 190.857 / 4200 ≈ vw / 22.006、± 0.5。上限は時刻の欄つきの 1400 lu の週の紙 3 枚が横に入る倍率 vw / 4200（`ZoomPolicy.swift:158-166`）、列は (1400 − 64) / 7 = 190.857 lu（`PaperSpec.swift:47-52`）。または probe の倍率で 1400 × 倍率 = vw / 3 を見る） | 等倍が無い |
| U | `PaletteMoveUITests.swift`（blank-paper の新しい iPad 13 の段。ログ `palette UI:`。`TEST_RUNNER_TEGAKI_PALETTE_UI=1` のときだけ、ほかは `XCTSkip`） | `toolbar.grip` を右の端へ → `tool.pen` が右の 80 pt に入り、`tool.marker` が `tool.pen` の下（縦）。上へ → `tool.pen.minY` が貼り付く見出しの minY より上。左へ。下へ → 「ペン」.minY − 16 == キャンバスの下。移した後も ↶ が押せる。開き直しても辺が残る（形は下の注）。1 回の離しで `toolbar: paperArea=` が 1 回だけ変わる。写真モードで走るので、離した辺は画面の `@State` に入り、鍵は書かれない（§4.10） | つまみが無い |
| U | `PaletteShotsUITests.swift` | iPad の横の写真（XCUI の回転と `simctl io screenshot`、§7.4） | — |
| U | `HeaderRoomUITests.swift` | `header room:` の枠を ipad13・ipadmini・ipad11・iphone69（blank-paper）と iPhone 17 の横（ui-tests）で書く（§3.5） | ログだけ。合否は D1a の関門 |

- **契約の書き手の注（設計の食い違い。D1a・D1b の前に U と S が決めて `docs/R1_4_1.md` に書く）**: 写真モードでは倍率（`CalendarRootScreen.swift:1141-1143` の `guard !ScreenshotMode.isActive`）も辺（0e-21）も書かず（辺は画面の `@State` にだけ持つ、§4.10）、`toolbar: paperArea=` の行は写真モードでしか出ない（`:611-616`）。だから 2 つの「開き直しても」の確かめは、写真モードの中ではいつも通ってしまうか、通らない。形の候補: (a) 開き直しだけを写真モードの外の起動（UserDefaults の引数の領域で初めての案内とペイウォールを閉じた形）にする、(b) 開き直しの確かめを UI テストから外し、書くことと読むことを単体テスト（`AppSettingsTests`・`HandSettingTests`・`ToolbarPlacementTests`・`ScreenshotModeHandPaletteTests`）に任せる。紙の領域の 1 回の変化は写真モードの起動で見る。

### 6.2 書き直すテスト（守られていない）

- **`HeaderAndPaperUITests`**（iPhone 17、ui-tests。ログ `header-paper UI:`。今は 1.1.1 の並び、`HeaderAndPaperUITests.swift:15-72`）:
  - 縦・右手: 前の月.maxX ≤ 今日.minX、今日.maxX ≤ 次の月.minX。次の月.maxX ≤ 題名.minX ≤ 次の月.maxX ＋ 8。題名.maxX ≤ 予定を追加.minX。`header.zoomReset.minY` ≥ 今日.maxY、その minX ≤ 13、maxX ≤ 切り替えの minX。等倍の高さ ≤ 切り替えの高さ ＋ 0.5。▶▶ の後に今日で 2026年10月に戻る。
  - 横の広い行: ▶ ≤ 等倍 ≤ 題名 ≤ 切り替え ≤ ＋ ≤ ⚙。
  - 両方を `--screenshot-hand left` でも: 鏡の不等式、◀ は ▶ の左のまま。
  - **並べ方 (b) が選ばれたとき**（§3.2 の (b) の表）は上の 3 つをこれに替える: 縦・右手: 題名.maxX ≤ 前の月.minX ≤ 題名.maxX ＋ 8（題名のすぐ後）、前の月.maxX ≤ 今日.minX、今日.maxX ≤ 次の月.minX、次の月.maxX ≤ 予定を追加.minX。等倍は (a) と同じ（2 段目の左、minX ≤ 13、高さ ≤ 切り替え ＋ 0.5）。横の広い行: 題名 ≤ 前の月 ≤ 今日 ≤ 次の月 ≤ 等倍 ≤ 切り替え ≤ ＋ ≤ ⚙（どれも前の maxX ≤ 次の minX）で、題名.maxX ≤ 前の月.minX ≤ 題名.maxX ＋ 6.5。左手は鏡（◀ は ▶ の左のまま）。
- **`PageHeaderRoomTests`**（速い道）: 狭い 1 段目の固定の幅を測った部品から計算し直す（ja 約 297.4【推定】。今は 324、`PageHeaderRoomTests.swift:21-23`）。375・382・393・402・440 で題名の場所 ≥ 70（ja）。body が `HeaderOrder` で描くことのソースの確かめ。詰めた行が無いこと。

### 6.3 足すテスト（守られていない今のファイル）

- `AppSettingsTests`: `testHandAndPaletteKeys`（§6.1）。`testToolbarKeys` の「鍵が全部別」の一覧（`AppSettingsTests.swift:160-163`）に 2 つの鍵を足す。
- `SettingsScreenTests`: 利き手の文（ja）、脚注に Pencil の語が無い、替えると `layout.hand` と `toolbar.collapsedEdge` を書く、写真モードでは何も書かない。MS1（`collapsedEdge` を書かない）で落ちる。
- `ToolbarLogicTests`: `PaletteEdge(stored:)`、`placementChosen` の行。
- `ToolbarFitTests`: 縦の列の道具の名前（38 pt の規則）と 44×38 の色のマスが 10 の言語で入る。横の行の約束は同じ。

### 6.4 そのまま通すテスト（変えない）

- `TESTS_1_3`（29）と `TESTS_1_2_3`（8）の全部。とくに `InkCanvasViewTests`・`InkCanvasSpanTests`・`CalendarRootScreenTests`・`ScreenshotModeTests`・`SettingsPageSectionTests`・`ScreenshotModeSpanTests`・`ScreenPathsSpanTests`・`SpanGuideSeenSpanTests`・`SpanUITests`・`SpanShotsUITests`・`SpanRerunUITests`（`YearTapUITests`・`EraserAndBelowDayUITests` を通る）。
- `OnePageRevealTests`・`PaperFitTests`・`DuoFoldTests`・`DuoLayoutUITests`（duo.yml の `r141-duo1`、`shot_checks` の外側 `header=2`・内側 1、題名の場所 ≥ 80 をログに）。
- KitChecks 40,826（閾値 40,776）、compat10、span-compat、`Real13LedgerTests`、保存のバイトの関門 2。
- 1.4 の数（基準。`docs/R1_4_1.md` の前もっての宣言）: 単体 781（飛ばし 2・失敗 0）、UI 58（飛ばし 15、走った 43、失敗 0）、同期の繰り返し 4,000。1.4.1 の新しいテストの分だけ増える（数は run で書く）。

### 6.5 変異（`r141-q-m1`。取り込まない）

各変異は、名前を挙げたテストを赤にすること。**表に無いテストは落ちないこと**（落ちたら理由を書く。M7D.md「M1」と同じ形）。

| 変異 | 中身 | 落ちるはずのテスト |
| --- | --- | --- |
| MZ1 | `resetZoomToOpen` の `!isUsingTool` の守りを外す | `InkCanvasZoomResetTests` |
| MZ2 | 最後の `scrollViewDidEndZooming` の知らせを飛ばす | `InkCanvasZoomResetTests` |
| MZ3 | 0d-44 の 2 行を戻す（直しを残したときだけ） | `InkCanvasWidthCentreTests` |
| MH1 | 左手の並びを逆にしない | `HeaderOrderTests` |
| MT1 | `allowedEdges` が 678 で左右を許す | `ToolbarPlacementTests` |
| MT2 | つまみが `.pencil` を許す | `PaletteGripTests` |
| MS1 | 利き手を替えても `collapsedEdge` を書かない | `SettingsScreenTests` |
| MS2 | 写真モードで辺を書く | `ScreenshotModeHandPaletteTests` |

### 6.6 CI の道（0e-23）

- 枝の配線: `r141` の名前を足す。速い道 `QUICK` に `r141-quick`・`r141-q-*`（`build.yml:143`）、`MUTATIONS` に `r141-q-m1`（`:149`）、言語の写真の段に `r141`（`:4019-4021`）、`branches-ignore` に `r141-duo*`（`:81-87`）、duo.yml に `r141-duo*`（`duo.yml:37-41`）。ほかの段の `if:` の速い道の字（`:1687`・`:2120`・`:2485`・`:2969`・`:3377`）にも同じに足す。`r13`・`r14` の名前は残す（M7D_CONTRACT §3.10 と同じ）。
- **写真を撮る枝に `r141-q-` を使わない**: `r141-q-*` は速い道で、build-and-test の写真の段（`env.QUICK != 'true'`、56b7031 の `build.yml:835`・`:853`・`:873`・`:919`）と、ui-tests・l10n・blank-paper・span-shots-app のジョブ（同じく `:1687`・`:2485`・`:2969`・`:3377` の `if:`。D0 の配線で `r141-q-*` も外れる）が走らない。`build.yml` に `workflow_dispatch` は無く、`ja-baseline.yml` は基準の commit を撮る。だから本人の選びの写真の枝は `r141-alt`（§7.5）、D1b の「写真だけの 1 回の試しの枝」も `r141-shots<n>` のように `q-` の付かない名前にする。どちらも通しの run（QUICK・MUTATIONS・言語の写真・`branches-ignore`・ja-baseline のどれにも当たらない）で、その run は J-4・関門 3 の合否に数えない。
- 速い道の単体テストの正規表現（`build.yml:672`）に `HeaderOrderTests`・`ToolbarPlacementTests`・`InkCanvasZoomResetTests`・`InkCanvasSpanZoomResetTests`・`InkCanvasWidthCentreTests`・`HandSettingTests`・`PaletteGripTests` を足す。
- ui-tests（iPhone 17 だけ、`build.yml:1990`）で `HeaderAndPaperUITests` と `ZoomResetUITests`。`:2013` の grep に `zoom-reset UI:` を足す。
- **iPad の UI テストの道を作る**: blank-paper（`build.yml:2967-`、`continue-on-error: true`）に新しい段「Palette UI tests on the 13-inch iPad (1.4.1)」、上限 20 分。`PaletteMoveUITests` だけを `TEST_RUNNER_TEGAKI_PALETTE_UI=1` で走らせ、`palette UI:` を grep し、テストが落ちたら段を落とす。**関門 1 は、ジョブの `continue-on-error` に関わらず、この段の結果で読む**。
- `HeaderRoomUITests` を blank-paper の機種の回しに足す。
- iPad の横のツールバーの写真は、span-shots-app の XCUI の回転と `simctl io screenshot`（`watch_photos`、`build.yml:3337-3340`・`:3591`）だけで撮る。`--screenshot-landscape` は使わない（iPadOS は向きの求めを無視する、`build.yml:911-914`）。
- 「Data code frozen」の段の名前は §5.4 の commit で直す。
- 理由: 今は iPad の UI テストの道が無い（ui-tests は iPhone だけ。審査 2 の E1・M1）。

---

## 7. 写真

### 7.1 J-4 の基準と違ってよい所（0e-24）

- 新しい基準 `tools/l10n/ja-baseline-ref-1.4.1.txt` = `2fb8fb1a818a8048f38555a5cc166ad754c26acb`（ビルド 28）。`ja-baseline.yml:124` の `FILE=` をこれに。今の `-1.4.txt`（955fe67）・`-1.3.txt`・`ja-baseline-ref.txt` は記録として残す。
- J-4 の `screenshots` を撮る今の写真の段は、`build.yml` と `ja-baseline.yml` で同じ字のまま（1.4.1 はその段を変えない。変えるときは両方を同じ字で）。**§7.4 の新しい写真は `screenshots` に入れず、別の成果物に撮り、`ja-baseline.yml` には足さない**: `compare_shots` は下のフォルダまで全部の画像を比べ、片側だけの画像や強い差で 1 を返す（`compare_shots.swift:8-10`・`:26-27`）。基準の 2fb8fb1 は知らない写真の引数を読まず既定の形を撮るので、足すと全面の強い差になる。前例: 1.3 の新しい写真は span-shots-app、1.4 の Duo の写真は duo.yml に分けた（`docs/M7C.md:856`・`docs/M7D_CONTRACT.md:437`）。
- 比べ方は今の J-4（`tools/l10n/compare_shots.swift`）。合否は、同じ UTC の日に撮り、2 つの env.txt の Xcode と実行環境の版が同じ組でだけ決める（M7D_CONTRACT §3.5）。
- **D0（CI だけの commit）**: 違ってよい強い差は `ipad13-portrait-sheet-info.png` の版の字（「1.4 (1)」→「1.4.1 (1)」）だけ。
- **機能の commit（D1a〜D2）で違ってよい所**は、D0 の前に `docs/R1_4_1.md` に書く。機種ごとの画素の行は 1.4 の写真から測って書く:
  1. どの写真も: 0 行目から見出しの下（`StickyHeaderView` の minY）まで。組ごとに `tools/shots/shift_pair.swift --exclude-rows 0-<見出しの下の px> --max-strong 0` で示す（`shift_pair.swift:1-23`: 除く行は引数、強い差 = R・G・B・A のどれかが 32 を超える）。
  2. ツールバーを開いた iPad の写真: さらにバーの上の帯（つまみ）、bar.minY − 8 pt から bar.minY ＋ 8 pt。
  3. `sheet-info`（版の字）。
  4. 設定のシートの写真と `store/ipad13/06-settings.jpg`: 入力の節の終わりから下（利き手の節が入るため）。
  - これ以外は強く違ってはいけない。**iPhone のツールバーは同じ**であること。
- 理由: `compare_shots` には覆いが無い。行を除いた確かめで見出しの下を全部見て、見出しの帯は人が切り抜きで見る（§7.3）。

### 7.2 関門 3（紙の領域）

- 既定の写真の `toolbar: paperArea=` の行が、1.4 の基準の run（44853713800、r14 6093deb。コードは 2fb8fb1 と同じ）と同じ。span-shots-app の状態の行 71 本（`pages`・`zoom`・`ox`・`oy`・`span cap:`）も同じ。だから `SpanPlan.referenceViewport` と `DuoChecks` は計算し直さない。
- 新しい写真（上・左・右に置いた形）は基準に無いので、この関門に入れない（新しい物として見る）。

### 7.3 見出しの切り抜き（役ごと。1.4 の関門 7 の組 3 の形）

- どの機種も（iPhone 17、6.9 インチ（18 Pro Max）、mini、11 インチ、13 インチ、Duo の外側）の見出しを切り抜き、部品が全部見えて押せる形か（◀・今日・▶・等倍・題名・日週月年・＋／＋予定・☁・⚙・閲覧専用の印）をリードが ○ か × で `docs/R1_4_1.md` に書く。前と後の切り抜きを確認ページに載せる。
- 11 インチは 2 つある: J-4 の `ipad11-portrait-*.png`（と店の `store/ipad11`）は build-and-test の `ipad11` で **iPad Pro 11（834 pt）**（56b7031 の `build.yml:230`・`:1292`）。本人の **iPad Air 11（820 pt）** の見出しは、`ipad11` が Air の blank-paper か span-shots-app の写真（同じく `:3052`・`:3143`）から切り抜く。`docs/R1_4_1.md` の表ではこの 2 つを分けて書く。
- J-4 は見出しの帯の差を許すので、**見出しの中の悪化は、この切り抜きの確かめでしか捕まらない**（§11）。

### 7.4 新しい写真（J-4 の組の外。写真モード）

- 撮る所: `screenshots` の外の新しい成果物（名前と、撮る段（blank-paper の新しい iPad 13 の段・span-shots-app・ui-tests の添付のどれか）は C が決めて `docs/R1_4_1.md` の D1b に書く）。`ja-baseline.yml` には足さない（§7.1）。下の l10n-shots の写真は今の `l10n-screenshots` の成果物。
- ipad13 の縦の月と週を `--screenshot-palette top`・`left`・`right` で。
- ipadmini の縦の月を左で。
- ipad13 の縦の月を `--screenshot-hand left` で。
- iphone17 の縦の週と横の週を左手で。
- iphone69 の縦の月（2 段目の等倍）。
- 今の `iphone-portrait-week-zoom3` は 2 段目の等倍が写る（J-4 の組の中。見出しの帯）。
- ipad13 の縦の月を `--screenshot-palette-drag right` で（確認ページだけ）。
- **iPad の横**は span-shots-app の XCUI の回転と `simctl io screenshot`（`watch_photos`）だけ: mini の横の週を右に（スクロールした列）、13 インチの横の月を左に。
- l10n-shots: de・fr・疑似の言語の見出し（枠 ＋ 等倍）と、10 の言語の設定の入力の節。
- blank-paper（43 枚）・span-shots-app（64 枚 ＋ 言語 60 枚）・UI テストの添付は、リードが比べる（自動では落とさない）。

### 7.5 本人の選びの写真（`r141-alt`。2 つだけ。取り込まない）

- **リードの調整（11/21）**: 写真で見せる選びは 2 つだけ。
  - (A) 見出しの並べ方: (a) 既定と (b) 日付が先（§3.2 の (b) の表）。iPad Pro 13 の縦と iPhone 18 Pro Max の縦の、週と日。
  - (B) 等倍のボタンの見た目: 虫めがねの 1（既定）と「等倍」の字。iPad と iPhone の見出し。
- この 2 つの別の形だけを、使い捨ての枝 `r141-alt` に、**DEBUG だけの写真モードの引数**で作る（`r141` にも main にも入れない）。
  - 枝の名前に `q-` を付けない。`r141-q-*` は速い道で、写真の段と写真のジョブが走らない（§6.6）。`r141-alt` は通しの run になる。
  - 写真は、その枝の `build.yml` に足す写真だけの段で撮り、別の成果物にする（その段も取り込まない）。
  - その run は J-4・関門 3・D1〜D2 の関門の合否に数えない。run の番号と写真を `docs/R1_4_1.md` の D2 に書く。
- ほかの 6 つ（3 つ離した「‹ 今日 ›」・左手の題名の左寄せ・動かしている間の見え方・2 列の横のツールバー・iPhone の上のツールバー・店の写真の撮り直し）は、確認ページに言葉で既定とともに書く。本人が求めたら作り、D1〜D2 の関門をやり直す。
- 本人が既定と違う形を選んだら: `r141` に作り、D1〜D2 の関門をやり直し、新しい TestFlight のビルドで渡す（やり直す確かめ表の行は §9.4）。「等倍」の字が選ばれたら `header.zoomReset`（`app-P.json`）を足す（§8.1）。

### 7.6 店の写真

- **撮り直さない**（既定。1.1.1・1.4 の 0d-24 と同じ）。本人に「店の写真は前の見出しのまま」と伝え、選べるようにする（§0.4）。撮り直すときは 16 ロケールの組・13 インチ・6.9 インチ・6.3 インチ・Duo と、ja の新しい組（store-shots の言語の組は 11 で、ja はその中に無い。ja の店の写真は Connect に入っている物のまま。`docs/store/README.md:109`、批評）。そのときだけ store-duo を走らせる。
- Connect は新しい版で前の版の写真を引き継ぐ【推定】。版 1.4.1 を作った後に読み戻して確かめる。

### 7.7 控え（S0'）

- 1.4 の最後の run（build.yml 44853713800・ja-baseline 44861649226）の 7 日の成果物（screenshots・ui-tests・span-shots-app・l10n・blank-paper・ja-baseline）は **11/28 ごろに消える**【推定】（`retention-days: 7`）。D0 の前に（遅くとも 11/22。`docs/R1_4_1.md` の画素の行はこの控えから測る）`~/.local/share/tegaki-backup/1.4.1/` へ控える（前と後の確認ページと関門 3 に使う）。`~/.local/share/tegaki-backup/1.4/artifacts-44853713800/` には `span-shots-app` と `span-shots-app-languages` の 2 つ（58 MB）がもうある【事実、11/21】。

---

## 8. 文字・訳・App Store

### 8.1 アプリの新しい文（11 キー）

| キー | 元のファイル | ja | en（案） | 注 |
| --- | --- | --- | --- | --- |
| `header.zoomReset.spoken` | `app-P.json` | 等倍に戻す | Reset Zoom | 虫めがねの 1 のボタンの読み上げ。comment: 等倍 = 拡大も縮小もしていないもとの大きさ（ページを初めて開いたときの大きさ。覚えた拡大ではない） |
| `settings.hand.header` | `app-U.json` | 利き手 | Dominant Hand | GLOSSARY で性別の無い right-hand / left-hand の形 |
| `settings.hand.right` | `app-U.json` | 右手 | Right Hand | |
| `settings.hand.left` | `app-U.json` | 左手 | Left Hand | |
| `settings.hand.footer` | `app-U.json` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | — | Pencil の語を入れない（iPad と iPhone で 1 つ） |
| `toolbar.grip.spoken` | `app-S.json` | ツールバーを動かす | — | |
| `toolbar.grip.hint` | `app-S.json` | 上下左右の端へ移せます | — | |
| `toolbar.moveTo.top` | `app-S.json` | 上へ移す | — | |
| `toolbar.moveTo.bottom` | `app-S.json` | 下へ移す | — | |
| `toolbar.moveTo.left` | `app-S.json` | 左へ移す | — | |
| `toolbar.moveTo.right` | `app-S.json` | 右へ移す | — | |

- **comment だけ替える**: `header.today`（`tools/l10n/source/app-P.json:431-446`）。「空いている手の側の端の ‹ 今日 › の真ん中の部品」に。ja は同じなので jaSha1（574cd4fb79、批評）は替わらず、訳し直さない。`was` は `Views/PageHeaderView.swift:156` のまま（J-1 の行、`tools/l10n/ja-baseline.tsv:225`。L-3 は `was` を 1.1 の行で引く、`tools/l10n/lint.py:248-270`。行を今の「今日」の行へ動かすと lint と CI の「Localized bundle check」が落ちる。作り直さない）。`where` も `Views/PageHeaderView.swift` のまま（行番号は無い）。替えるのは `comment` だけ。
- 上の表の 11 キーとも、ファイルの持ち主は役 X（§2）。「元のファイル」の列は文の元の JSON で、役の字（§9.3）ではない。
- **本人が「等倍」の字を選んだときだけ**: `header.zoomReset`（`app-P.json`）、ja「等倍」と `maxEm`。9 言語の訳・元を見ない逆翻訳・`HeaderFitTests`（17 pt で ja ＋ 16.5 pt 以内、13 pt の semibold で 44.5 pt 以内、10 の言語）が要る。en に「Fit」は使わない（意味が違う）。
- J-1（`tools/l10n/ja-baseline.tsv`、516 行の 1.1.1 の日本語）は変えない。新しいキーは `was` を持たない新しい文（L-3 は 1.1.1 の行だけを見る、`lint.py:19-26`）。アプリのコードに日本語の字を書かない（L-1）。

### 8.2 訳と逆翻訳（X・R）

- GLOSSARY を先に直す（等倍 = 拡大も縮小もしていないもとの大きさ（初めて開いたときの大きさ）、利き手・右手・左手を性別の無い形で。de・fr・es・it・pt-BR は性別の付く形になりやすい）→ 9 言語の訳（X）→ 元を見ない逆翻訳（R、`docs/i18n/back`）→ 判定の 2 役 → `REVIEW.md` の × を 0 に。
- 確かめ: `lint.py`（L-1〜L-14）、`build.py --check`、`baseline.py --check`、CI の「Localized bundle check」、testflight の「Every word of the app in ten languages」。
- 言語ごとの確認表は、確認ページ 1 回の中で見せる。

### 8.3 新機能の文（16 ロケール。ja はこの文、ほかは訳。最後の行は AI の訳の断り（ja 以外）、1.4 と同じ字）

**案**（D2 で訳と逆翻訳。確認ページで全部の行を見せ、「この内容で入れてよい」は全部の組み合わせに効く）:

> ・画面の上の「‹ 今日 ›」を左の端に移し、日付をそのすぐ右に並べました。
> ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。
> ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。
> ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。

- 並べ方 (b) が選ばれたら 1 行目を次に替える（案は D2 で 2 つとも訳す）:
  > ・画面の上の「‹ 今日 ›」を、左の端の日付のすぐ右に移しました。
- 「等倍」の字が選ばれても 2 行目は同じ（ボタンの見た目を書かないため）。
- 「指でも書く」などのアプリの語は、各言語のアプリの訳と同じ字にする（X が写す）。無い改善は書かない（R1_2_2.md:694）。K-8 の句は入れない（§5.2）。4,000 字まで。en-GB・en-AU・en-CA は en-US の写し、fr-CA は fr-FR の写し（`docs/store/locales.json`）。
- プロモーションテキストは新しい版で空になるので、今の文を入れ直して読み戻す。
- `docs/store/README.md` の新機能の文の表に 1.4.1 の行を足す。

### 8.4 審査メモ（`docs/store/review-note.txt`。英語が主で日本語の要約、4,000 バイトまで）

- 今は 3,964 バイト（ファイル。Connect に入れた字は 3,963、M7D.md）。「What is new in 1.4」の段を「What is new in 1.4.1」に入れ替える。ほかの段（ログイン不要・言語・データの扱い）はそのまま。
- 書くこと: (1) 見出しの並び（‹ Today › と 1× のボタンが左、設定で左手にすると逆）。並べ方 (b) が選ばれたら「the date at the far left, with ‹ Today › and the 1× button right after it」。「等倍」の字が選ばれたら、1× の代わりにそのボタンの en の字（D2 の訳。「Fit」は使わない）で書く。(2) 1× は各ページの拡大も縮小もしていないもとの大きさ（初めて開いたときの大きさ）に戻す（その種類の覚えた拡大も忘れる）。(3) iPad ではツールバーの小さなつまみを指で 4 つの端へ動かせる（Pencil では動かない。iPhone は、Duo の開いた画面を含めて下のまま）。(4) 新しい画面の文は設定と読み上げだけ。データの扱い（App Privacy は「データの収集なし」）・保存・購入・年齢区分は変わらない。確かめ方: iPad で週のページを開き、つまみを右の端へ引く。
- 入れ替えた後のバイト数を `docs/R1_4_1.md` に書く（4,000 を超えたら古い段を短くする）。

### 8.5 SUPPORT（日本語・英語。W。公開の日に Web へ。承認は確認ページの 1 回）

- `docs/SUPPORT.md:7` の最終更新の日（公開の日に）。
- `:64` の「画面の上の「今日」を押すと今日に戻れます」は、位置の語が無いので字はそのまま使える【事実】。左の端の「‹ 今日 ›」と言い直すかは W が決める。
- `:119`「画面下のツールバーで切り替えてください」: 上や左右に置いた iPad では下ではないので、「ツールバーで切り替えてください」にする。
- `:145-147`「ツールバーをしまうには？」: 「ツールバーの右端の「しまう」」に「（左右に置いたときは下の端）」を足し、「左下の小さな丸ボタン」に、左手と左右に置いたときの角を足す。
- `:149-151`「拡大・縮小するには？」: 等倍のボタンと、「その種類のページの覚えた拡大も忘れる」ことを足す。「月と年のページは…同じ大きさで開きます」に、ツールバーを左右に置いたときはその分だけ小さく開くことを一言足す。
- **等倍のボタンの言い方**: 既定は「虫めがねに「1」の印のボタン（等倍）」、「等倍」の字が選ばれたら「「等倍」のボタン」。場所は並べ方 (a) なら「左上の「‹ 今日 ›」のとなり」、(b) なら「左上の日付の右、「‹ 今日 ›」のとなり」（iPhone の縦はどちらも「2 段目の左」）。D2 で 4 つの組の言い方を日英で用意し、確認ページでは選ばれた組を見せる。
- 新しい FAQ 2 つ: 「左手で使うには？」（設定 › 利き手）と「ツールバーを動かすには？」（iPad、指でつまみ、4 つの端、Pencil では動かない、iPhone は下のまま、狭い窓では下）。
- 英語の `SUPPORT.en.md` も同じ所。公開のスクリプトの確かめに「Web の SUPPORT 2 ページが新しい文になっている」を入れる（1.4 の `release14.py web` の形）。

### 8.6 文書

- `docs/DESIGN.md` §2.7（`:212` の「今日（1.1.1 で右側へ）」を 1.4.1 の並びに。Web 版と違うことも書く）と §2.8（設定に利き手）。
- `README.md:60`（4 つのページの行の「右」）・`:82`（iPhone の行）・`:186`（`PageHeaderView.swift` の説明）と、新しいファイル（`HeaderOrder.swift`・`PaletteGrip.swift`・`PaletteDragOverlay.swift`）。
- `docs/M7_PLAN.md` §4 の表: 1.4.1 をこの版に、前の 1.4.1（ペンの色・メモ欄の紙）を 1.4.2 に。§4 の頭に「1.4.1 の約束は R1_4_1_CONTRACT.md」。

---

## 9. 段取り・役・出し方

### 9.1 段と目安の日（2026-11-21 時点。`docs/R1_4_1.md` に実績を書いて直す）

CI の時間の見込みは 1.4 と同じ: build.yml は 1 回 75〜95 分（6 つのジョブのうち 5 つが同時、同時の上限 5）。ほかの workflow は build.yml の後に 1 つずつ。blank-paper（ジョブ 80 分・写真の段 70 分の上限、`build.yml:2972`・`:3146`）と span-shots-app（ジョブ 110 分、`:3380`）は新しい段と写真で長くなる。

| 段 | 目安 | 中身 | 関門 |
| --- | --- | --- | --- |
| S0 | 11/21〜11/22 | この契約。`docs/R1_4_1.md` の前もっての宣言（J-4 の違ってよい所と機種ごとの画素の行・凍結の作り直しの計画・基準の数）。本人に §0.6 のことを平たく伝える | リードが契約を読む |
| S0' | 11/22（D0 の前） | 1.4 の最後の run の 7 日の成果物を控える（11/28 ごろ消える）。`docs/R1_4_1.md` の機種ごとの画素の行は、この控えから測って D0 の前に書く | 控えの数と大きさを記録 |
| D0 | 11/22〜11/24 | CI だけの commit（`r141`）: 枝の配線 `r141*`、J-4 の基準のファイル、`MARKETING_VERSION "1.4.1"`、道の名前。`Sources`・`TegakiKit/Sources`・`Tests` は 2fb8fb1 と同じ | 下の D0 の関門 1〜8 |
| D1a | 11/23〜11/28 | 見出し・等倍・利き手と、キャンバスの作り直し: `HeaderOrder`、`PageHeaderView` の書き直し、設定の Section、写真モードの引数、`InkCanvasView` の足す行と 0d-44、`DATA_1_1` の 1 行目 | `header room:` を測った・ja の広い日の題 ≥ 115（mini・Air 11・Pro 13 の縦。でなければ間隔 4）。紙の領域が同じで等倍の高さの確かめ。速い道と全部の単体テスト。`TESTS_1_3`・`TESTS_1_2_3` がそのまま、互換の相手・保存のバイト・画面の字が緑。リードが凍結の diff を 1 行ずつ見た。0d-44 の 2 行は、ピン留めのテストが全部そのまま緑のときだけ残す |
| D1b | 11/26〜12/2 | ツールバー: 枠・つまみ・PalmWatch・縦の `ToolbarView`・吸い付き・今の辺ののぞき・丸いボタンの角・VoiceOver の操作・覚え方・blank-paper の iPad 13 の段・span-shots-app の横の写真 | `PaletteMoveUITests` が iPad 13 で緑。「ペン」.minY − 16 が iPhone（`YearTapUITests`）と iPad 13 で成り立つ。下の既定で関門 3 が同じ。blank-paper と span-shots-app が時間の上限に収まる（でなければ別のツールバーのジョブか、写真だけの 1 回の試しの枝。枝の名前に `q-` を付けない、§6.6） |
| D1c | 11/29〜12/3 | 変異（`r141-q-m1`）と Duo（duo.yml `r141-duo1`） | §6.5 の変異が全部それぞれのテストを赤にする。`DuoLayoutUITests` と `shot_checks` が緑、外側の題名の場所 ≥ 80 をログに。でなければ計算し直した詰めた行を戻す |
| D2 | 11/30〜12/6 | 11 キーの訳（X）・逆翻訳（R）・判定・REVIEW.md、lint・build.py・baseline.py・バンドル。SUPPORT の日英、16 ロケールの新機能の文、審査メモ（4,000 バイト以下）、DESIGN・README・M7_PLAN。`ink_ref`・`ink_ref_xcui` の作り直し。同じ UTC の日の J-4、全部の組を `shift_pair` で示す、見出しの切り抜きを役ごとに。`r141-alt` の 2 組の写真（§7.5） | 確認ページがそろう |
| D3 | 12/5〜12/12 | TestFlight 1.4.1（ビルド 29 以上。アーカイブの確かめ `iphoneos27.2`・`17.0`・`1, 2`、Connect で VALID）。確認ページ 1 つ: 変わる所、2 つの選びの写真と既定、言葉の選び 6 つ、見出しの前と後の切り抜き、SUPPORT、新機能の文、審査メモ、確かめ表 | 本人の「この内容で入れてよい」と選びの答え。既定と違う選びは作って D1〜D2 の関門をやり直し、新しい TestFlight のビルドで |
| D4 | 1.4 の公開の後 | 1.4 が公開され `--no-ff` で main へまとまり、`r141` が main を取り込んで確かめた木とのコードの差が空になり、本人が「1.4.1 を審査に提出して良い」と言った後に提出。手動公開 | 3 つがそろう |
| D5 | 審査の後 | 審査が通り、本人の確かめ表がそろい（Duo の行は「—」）、本人が「1.4.1 を公開して良い」「まとめて良い」と言った後に公開 → main へ `--no-ff` → 公開の日に SUPPORT を Web へ | — |
| 前ぶれ | 12/10 | D3 が渡せていなければ本人に知らせる | — |
| 決まり | 12/18 | 年末の前の最後の提出日の目安。過ぎたら 1/5〜 | — |

**D0 の関門**（全部そろって D1 へ。設計の「関門 1〜8」を、道具を替えない 1.4.1 に合わせた形。M7D_CONTRACT §3.3 の 5（testflight）・6（duo-probe）・7（SDK の差の地図）は 1.4.1 の D0 には要らないので、5〜8 を替えた）:
1. 全部のジョブが緑: KitChecks 40,826（閾値 40,776）、単体テスト 781（飛ばし 2・失敗 0）、同期の繰り返し 4,000、UI テスト 43 本が走って失敗 0、compat-v1.0（compat10 599・span-compat 274/274/278/310・`Real13LedgerTests` 5/5）、l10n-shots 63 枚、blank-paper 43 枚、span-shots-app 64 枚と言語の 60 枚。`DATA_1_1`・`TESTS_1_3`・`TESTS_1_2_3`・`FIXTURES_1_3` の段も緑。
2. 保存のバイト（§5.7 の 3 つ）が作り直さずに同じ。
3. 関門 3: `toolbar: paperArea=` の値の組と状態の行 71 本が 1.4 の基準の run と同じ（§7.2）。
4. J-4: 強い差は `ipad13-portrait-sheet-info.png` の版の字だけ。
5. D0 の木の `Sources`・`TegakiKit/Sources`・`Tests` が 2fb8fb1 と同じ（`git diff 2fb8fb1 -- Sources TegakiKit/Sources Tests` が空）。
6. env.txt が Xcode 27.2（27B52）・XcodeGen 2.46.0。実行環境の版を書く。
7. 速い道（`r141-quick`）と変異の枝の配線が効く（`r141-q-*` で速い道の組だけが走る。1 回）。
8. duo.yml が `r141-duo*` で起きる（D1c の前に 1 回。合否は D1c で読む）。

- 作業の木はスクラッチパッドにあり、毎日 0:00 の掃除で古いファイルが消えうる。こまめに commit し、リードが `r141` を GitHub に上げて控えを残す。
- Claude の週の使える量が 95% に届いたら、その週は止まる。進み具合を `docs/R1_4_1.md` に残す。

### 9.2 規模

| 部分 | 里程 | 元 |
| --- | --- | --- |
| D0（CI の配線・基準・版） | 0.05 | M7D の D0 の実績 |
| 見出し（並びの表・枠・等倍のボタン・測り）とテスト | 0.25〜0.3 | 設計 |
| 等倍（凍結の作り直し・規則・0d-44）とテスト | 0.2〜0.25 | 設計 |
| 利き手とテスト | 0.1 | 設計 |
| ツールバーを動かす（枠・つまみ・PalmWatch・縦の形・吸い付き・のぞき・VoiceOver・iPad の UI テストの道）とテスト | 0.6〜0.8 | `docs/M7_PLAN.md:221-222`（1.1 の計画で縦のバー 0.7・指で動かす 1.0）。この契約は自由な位置でなく 4 つの端なので、その間 |
| 訳・店・SUPPORT・写真・確認ページ | 0.2〜0.25 | 1.4 の実績 |
| **合計** | **1.4〜1.75** | 1 里程 ≈ 1.5 週だが、1.3・1.4 の実績はずっと速い。**目安 3 週**（設計。審査 2 の M13「2 週は楽観」を受けた）。日程は CI（1 回 75〜95 分、同時の上限 5）・本人の確かめ・1.4 の審査が律速 |

### 9.3 役

| 役 | 仕事 | 持ち物 |
| --- | --- | --- |
| C | CI・版・J-4 の基準・道の配線・iPad の UI テストの段・写真の段・`ink_ref` | §2 の C の行 |
| H | 見出し: `HeaderOrder`・`PageHeaderView`・その単体テスト | §2 の H の行 |
| Z | 等倍とキャンバス: `InkCanvasView` の作り直し・`DATA_1_1` の 1 行目・キャンバスのテスト | §2 の Z の行 |
| T | ツールバーの部品: `ToolbarLogic`・`ToolbarView`・`PaletteGrip`・`PaletteDragOverlay`・その単体テスト | §2 の T の行 |
| S | 画面と設定のつなぎ: `CalendarRootScreen`・`AppSettings`・`SettingsScreen`・`ScreenshotMode`・その単体テスト | §2 の S の行 |
| U | UI テスト（`HeaderAndPaperUITests`・`ZoomResetUITests`・`PaletteMoveUITests`・`PaletteShotsUITests`・`HeaderRoomUITests`） | §2 の U の行 |
| X・R | 訳・元を見ない逆翻訳・GLOSSARY・REVIEW | `tools/l10n/`・`docs/i18n/` |
| A・W | 新機能の文・審査メモ・SUPPORT | `docs/store/`・`docs/SUPPORT*.md` |
| リード | 順番・確かめ・凍結の diff の 1 行ずつの見直し・`docs/R1_4_1.md`・Connect・本人への知らせ | — |

### 9.4 出し方（本人の言葉が要る所。一覧は §0.4）

| 順 | だれ | すること | 本人の言葉 |
| --- | --- | --- | --- |
| 1 | 各役 | この契約のとおりに作り、`r141` に commit | 不要 |
| 2 | リード | `r141` を GitHub に上げ、CI が全部緑 | 不要 |
| 3 | リード | 確認ページ（§9.1 の D3） | 「**この内容で入れてよい**」と、2 つの選び（答えが無ければ既定） |
| 4 | リード | testflight.yml を `r141` で走らせ、TestFlight 1.4.1 を内部のテストに配る。確かめ表（§10）を番号付きで渡す（3 と同時でよい） | 不要 |
| 5 | 本人 | 確かめ表 | 「全部○」か × の所 |
| 6 | リード | 1.4 の公開（審査が通った後、本人の言葉は 11/21 に済み）→ `r14` を main へ `--no-ff` → `r141` に main を取り込み、`git diff <確かめた commit> -- Sources TegakiKit Tests tools .github project.yml` が空 | 不要（1.4 の分は済み） |
| 7 | 本人 → リード | 提出のお願い | 「**1.4.1 を審査に提出して良い**」 |
| 8 | リード | Connect に版 1.4.1 を作り、16 ロケールの新機能の文・プロモーションテキスト・審査メモ・ビルドを入れて読み戻す。手動公開で提出 | — |
| 9 | 本人 → リード | 審査に通ったら公開。同じお願いで、main へまとめてよいか | 「**1.4.1 を公開して良い**」と「**まとめて良い**」 |
| 10 | リード | 公開の後、Web の SUPPORT 2 ページ、日本の App Store の表示が 1.4.1 になったことを記録。`r141` を main へ `--no-ff`、main の CI を見る。本人の手元の main を `pull --ff-only` | — |

- 公開は、本人の確かめ（5）と本人の言葉（9）の後だけ。言葉は前もってもらってもよい（1.2.4 の「三つともYes」、1.4 の「両方ともYes」）。**本人が自分の端末で確かめていない版は出さない**。
- × が出たら、直してビルドし直し、確かめ直す（提出の後なら審査から取り下げる）。
- **本人が既定と違う形を選んだとき、やり直してもらう確かめ表の行**（新しいビルドの番号で表を渡し直し、その行の答えがそろってから提出・公開する。ほかの行の答えは前のビルドの物を使う）: いつも行 1（版）。ほかは選びごとに:
  - 並べ方 (b)・「等倍」の字・3 つ離した「‹ 今日 ›」: 行 2・3・4・7・12。
  - 左手の題名の左寄せ: 行 12。
  - 動かしている間の見え方: 行 13・14。
  - 横の 2 列のツールバー: 行 13〜17。
  - iPhone の上のツールバー: 行 18（書き直して渡す）と行 12（iPhone）。
  - 店の写真の撮り直し: 行は無し（確認ページで写真を見てもらう）。
  - 直しが凍結のキャンバス（`InkCanvasView.swift`）や保存・同期に触れたときは、全部の行。
- 1.4 が審査で戻されたら、`r14` を直して出し直し、`r141` をその上に載せ直す（§11。下の表の 2 つ目）。

**うまくいかなかったとき**:

| 起きたこと | すること |
| --- | --- |
| 1.4.1 が審査で断られた | 指摘を `docs/R1_4_1.md` に写す。文・審査メモだけで直せる（コードの差が空）なら、直した文を確認ページで見せて「この内容で入れてよい」をもらい直す。コードを直すなら、触れた所の D1〜D2 の関門をやり直し、新しいビルドを TestFlight へ、確かめ表の触れた行（上の決め方）をやり直してもらう。どちらも、出し直しの前に「1.4.1 を審査に提出して良い」をもう一度もらう |
| 1.4 が直されて main に入り、`r141` が main を取り込んだ後、`git diff <確かめた commit> -- Sources TegakiKit Tests tools .github project.yml` が空でない（D4 の続き） | 提出しない。J-4 の基準（2fb8fb1、`ja-baseline-ref-1.4.1.txt`）と関門 3 の基準の run（44853713800）を、公開した 1.4 の commit とその通しの run に替える（基準の替えと理由を `docs/R1_4_1.md` に）。`r141` で D0 の関門から通しの run をやり直し、差に触れる D1〜D2 の関門もやり直す。新しいビルドを TestFlight へ、確かめ表を新しいビルドで全部やり直してもらってから、「1.4.1 を審査に提出して良い」をもらう |
| 公開の後に重い不具合が見つかった | App Store では前の版に戻せない。直した版をできるだけ早く出す（版の番号は 1.4.1 の次。そのときペンの色の版はさらに後へ送り、M7_PLAN §4 を直す）。直し・TestFlight・本人の確かめ・「この内容で入れてよい」・提出・公開・まとめの言葉の流れは同じ。直すまでの間の回り道（あれば）を本人に知らせる |

---

## 10. 本人の確かめ表（TestFlight 1.4.1）

**対象の版: 1.4.1（TestFlight のビルド 30 の見込み。番号は Claude が渡すときに書きます）**。11/22 のビルド 29 の表は使いません。この表は、ビルドが本人の端末に届いた後に、番号を書いて改めて渡します。上から順に ○ か ×。× のときは画面の写真を送ってください。等倍の作り直しで手書きの画面の大事な所に触れたので、全部の行をお願いします。

**準備**: 全部の端末（iPad Pro 13・iPad Air 11・iPad mini・iPhone 18 Pro Max）に、TestFlight で 1.4.1 を入れてください。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（無料）。**「全て消す」と Apple アカウントの切り替えはお願いしません。** iPhone Duo の行は「—」にしてください。ビルド 29 でツールバーを上や左右へ動かしていたときは、下に戻してから始めてください（行 4 の大きさの違いが見やすくなります）。

| # | 端末 | すること | こうなれば合格 |
| --- | --- | --- | --- |
| 1 | 全部 | ⚙（設定）› 情報 で「バージョン」を見る | 1.4.1（30）。作り直しで番号が変わったときは、Claude が知らせた番号 |
| 2 | iPad mini と iPad Pro 13 | 日・週・月・年のページを順に開く（縦と横）。mini の縦で、祝日のある日のページ（例: 2026年11月23日）も開く | 日付が左上の端、「‹ 今日 ›」が右上の端で、等倍はそのすぐ左。祝日の名前は「…」で切れることがあります |
| 3 | iPad Air 11 と iPhone | ‹ と › で 1 ページずつ動かし、今日で戻る。ふつうのページと、横につながった週・日の両方で。iPhone の縦では、⚙ と ‹ を交互に 5 回ずつ押す（設定が開いたら閉じてから次へ。等倍は押さない） | 1 ページずつ動き、今日で今日に戻る。⚙ では設定が開き、‹ ではページが 1 つ戻る（ねらったボタンだけが効く）。押しにくければ × にして、どう押しにくいかを教えてください |
| 4 | iPad Air 11 | 縦で、日と週のそれぞれを、2 本指でいちばん小さくしてから（24 時間が全部見える大きさ）等倍を押す。次に 2 本指で拡大してから、もう一度等倍を押す。月と年は、2 本指で拡大してから等倍を押す | 日と週は、どちらから押しても、1 ページ（1 日・1 週）の左右の端が画面の左右の端にちょうどそろう（紙の外の色も、隣のページも見えない）。いちばん小さい大きさから押したときは、はっきり大きくなる。月と年は、初めて開いたときの大きさに戻る |
| 5 | iPad Pro 13 | 予定の多い月を横にして、または年のページを、つまんで小さくしてから等倍を押す | 初めて開いたときの大きさに戻る |
| 6 | iPad Air 11 | 横につながった週か日で拡大し、横に動かしてから等倍を押す。もう一度拡大し、指で横にはじいて、紙が滑っている間に等倍を押す。その後 ‹ と › で動かす | 真ん中のページ 1 つ（1 週・1 日）の幅が画面の幅にちょうど合い、上の題名がそのページの日付。滑っている間に押したときも、滑りが止まって同じになる。‹ › で動かしても、ページの左右の端が画面の端にそろったまま |
| 7 | iPhone 18 Pro Max | 縦と横で見出しを見る。横で、横につながった週と日を開いて見てから、等倍を押す | 縦でも横でも、日付が左の端、「‹ 今日 ›」が右の端。等倍は、縦では 2 段目の右（› の下）、横では「‹ 今日 ›」のすぐ左。開いたとき（等倍を押す前）の紙の大きさと位置は 1.4 と同じ（拡大していなければ、週は 3 週・日は 5 日が横に並ぶ）。等倍を押すと 1 週・1 日が横いっぱい（見えるのは週で 4 時間ほど、日で 2〜3 時間）。※この iPhone で先に週や日の等倍を押していたときは、週と日のそれぞれで 2 本指でいちばん縮めてから、別の週・日を開き直すと、押す前の形で開きます |
| 8 | iPad mini か iPad Pro 13（行 4 で等倍を押していない iPad。iPhone の縦の週は、等倍でも見た目が変わらないため） | 先に月のページで拡大しておく → 週のページで等倍を押す → 別の週を開く → アプリを完全に閉じて開き直す（下の端から上へゆっくり指を動かして止め、てがきカレンダーの絵を上へ払う）→ 週と月を開く → 週を 2 本指で少し拡大してから、別の週を開く | 週は等倍（1 週の幅が画面にちょうど）で開く。月は拡大したまま。週を指で拡大した後は、次の週もその大きさで開く |
| 9 | iPad | 先に 2 本指で拡大しておく。Pencil で書いている最中に、もう片方の手の指で等倍を押す。書き終えてすぐもう一度押す | 書いている最中は何も起きず、線は切れない。書き終えた後に押すと、大きさが変わる（日・週は幅にちょうど、月・年は初めて開いたときの大きさ） |
| 10 | iPad | 等倍とツールバーの移動の後に、↶ と投げなわで選んだ線を動かす | どちらも今までどおり使える |
| 11 | iPad | 拡大したまま、縦 → 横 → 縦に回す。次に週で等倍を押し、もう一度 縦 → 横 → 縦に回す | 見ていた所が真ん中に残る（1.4 の横へのずれが無い）。等倍の週は、回しても 1 週の幅が画面にちょうど合ったまま |
| 12 | iPad と iPhone | 設定 › 利き手 › 左手 にして、見出しと紙と丸いボタン（ツールバーをしまう）を見る。右手に戻す | 見出しが左右逆（「‹ 今日 ›」と等倍が左の端、日付が右の端。iPhone の縦では等倍が 2 段目の左の端）。◀ は ▶ の左のまま、日週月年の順も同じ。紙はそのまま。しまった丸いボタンが右下。右手で全部元に戻る。iPad と iPhone で別々に覚える |
| 13 | iPad | ツールバーを開いたまま、小さなつまみを指でつかみ、上・左・右・下へ順に動かす。次に週で等倍を押し、ツールバーを左と右へ動かす | その端に吸い付く。左右では縦に立つ。紙が 1 回だけ並び直る。等倍の週は、ツールバーを左右へ動かしても、1 週の左右の端が、ツールバーの横の紙の場所の左右の端にそろったまま（紙の外の色が見えない） |
| 14 | iPad | つまみのすぐそばで Pencil で書く。Pencil でつまみを引いてみる | ツールバーは動かない |
| 15 | iPad | ツールバーを左か右に置き、道具・色・細中太・↶↷・指でも書く・しまう を全部使う。mini と Air の横では、縦に並んだツールバーを指でスクロールする。下に戻して、mini で道具の並びを指で横にスクロールする | 全部使える。スクロールで下の部品が出る。下の並びも横に動く（つまみの真上から始めたときだけ、ツールバーが動きます） |
| 16 | iPad | 端に置いたままアプリを閉じて開き直す。回す。Split View で細い窓にし、また広げる | 開き直しても回しても同じ端。細い窓では下、広げると元の端 |
| 17 | iPad | 左か右の端で「しまう」を押す。丸いボタンを押す。Pencil で書き始める | 丸いボタンはその側の下の角。押すとその側にツールバーが出る。書き始めるとまたしまう |
| 18 | iPhone | ツールバーを見る | つまみが無く、1.4 とまったく同じ |
| 19 | 全部 | 1.4 の確かめのくり返し: 見出し以外のページとシート（予定を作る・設定）を見る。iPhone を横にして週と日を 2 本指でいちばん縮める。年のページで日付をタップする | 見出し以外は 1.4 と同じ見た目。週は 3 週、日は 5 日が横に並ぶ。その日のページが開く |
| 20 | iPad と iPhone | iPad で、等倍とツールバーの移動の後に書き足す。iPhone でそのページを開く | 書き足した線が届く。上の印は「保存済み」 |
| 21 | どれか 1 台 | 機内モードにして書く → 機内モードを切る。アプリを完全に閉じて開き直し（行 8 と同じやり方）、手書きのあるページ（月・週・日・年）を順に開く | 書いている間は「オフライン」、戻すと「保存済み」。開き直しても書いた線が全部見える。一部の線が欠けて見えるときは、そのページの写真を送ってください |
| 22 | iPhone Duo | — | 「—」（Duo はお持ちでないので、自動の確かめだけで見ます） |

- 確認ページで見出しの並びの案 A（⚙ が左の端）を選んだときは、新しいビルドの番号で、行 1・2・3・7・12 をやり直してもらいます（行 2・3・7・12 の合格の字は、そのとき書き直してお渡しします）。

---

## 11. 危険と減らし方

| 危険 | 減らし方 |
| --- | --- |
| 凍結の `InkCanvasView.swift` を 1.3 から初めて変える（`DATA_1_1` の 1 行目）。等倍が横の道で見ていた所を取り違える（UI-1 の類）。0d-44 の直しが今の全部の機種の拡大中の回転を変える | 足す行と名前を挙げた 2 行だけ（§5.4）。新しい等倍と幅の真ん中のテスト、変異、互換の相手とバイトの確かめ、ピン留めのテストがそのまま、リードの 1 行ずつの見直し。ピン留めのテストが落ちたら 0d-44 を戻して記録 |
| 広い行の幅は推定。600〜700 pt の窓（678 の Split View、Duo の内側）と、祝日の名前つきの ja の日の題で、日付が小さいか切れる | `HeaderRoomUITests` で測る。本人の iPad で 115 pt 以上の関門と、間隔 4 の逃げ道（§3.5）。切れは記録 |
| 2 段目の等倍の高さが、測ったことの無い切り替えの高さに依る。高ければ全部の紙の領域・開いた倍率・J-4 の写真が動く | 紙の領域が同じ関門と高さの確かめ（§3.3）。逃げ道は固定の枠 |
| 横のツールバーで紙が 74 pt 狭くなる。幅で決まるページ（iPad の縦の月）は置いたときに小さく並び直る。本人は縦では上を好むかもしれない。覚える辺は端末に 1 つで、向きごとではない | §0.6 で伝えた。確かめ表 13・16 |
| iPad の開いた下のバーが、inset の暗黙の間隔から明示の 8 pt に替わる | 関門 3 で CI の iPad の 74 を示す。Mac（Designed for iPad）は測っていない【未確認】。iPhone は Duo の内側も含めて下だけで、1.4 と同じ（§4.3） |
| iPad の窓に付ける受け身の `InkTouchObserver`（PalmWatch）は新しい。1.4 の 0d-39 は iPad に付けなかった | ファイルは変えない（1.3 からキャンバスで使う形）。許す辺が 2 つ以上のときだけ付ける。iPad の窓と PencilKit への影響は CI と確かめ表 13・14 だけで見る |
| つまみが小さい（120×16 pt）指だけの部品。HIG は Pencil で届く操作を好む。本人が Pencil で試したり、つまみを見つけられなかったりする | VoiceOver の操作、SUPPORT の FAQ（§8.5）、確かめ表 13・14 |
| Apple の細かい動き（丸に縮む・左右で縦・辺の位置を覚える・Pencil で動かす）は報告と記憶で、Apple の文書ではない | 本人には「4 つの端に吸い付く」ことと、このアプリがすること・しないことだけを言い、「Apple と同じ」とは言わない（§0.6・§4.12） |
| 縦のツールバーは消しゴム・投げなわ・予定の説明の行を隠す（読み上げのヒントだけ）。消しゴムの「ペンに戻る」の説明を見逃すかもしれない | 言葉の選び（2 列の形）を §0.4 で示した |
| Pencil が触れている間の等倍は貯めずに落とす。左手で線の途中に押しても何も見えない | 確かめ表 9 と §0.6 で伝えた |
| 週・日の終日帯のある高い拡大から等倍にすると、帯が縮んで `applyBounds` がもう 1 歩小さく動き、跳んだように見えうる | 収まることをテストする（§6.1）。確かめ表 4・6 で見る |
| CI の容量: blank-paper（ジョブ 80 分、写真の段は過去に 46 分）と span-shots-app（約 46〜66 分）に新しい段と写真が乗る。古い手書きの基準で撮り直すと予算を食う | `ink_ref` を先に作り直す（§1.5）。上限を超えたら別のジョブか、写真だけの 1 回の試しの枝（D1b の関門） |
| J-4 は全部の見出しの帯の差を許す。見出しの中の悪化は切り抜きの確かめだけで捕まる | 機種ごとの切り抜きを役ごとに ○ × で書き、確認ページに前と後（§7.3） |
| Duo の詰めた行をやめる。Duo の内側と外側は duo.yml だけで見る（本人は Duo を持っていない） | duo.yml の関門で示せなければ、計算し直した詰めた行を戻す（§3.2、D1c） |
| 左手で VoiceOver が見出しを逆に読む（⚙ から）。見出しに Dynamic Type の上限が無く、大きな字で固定の大きさのボタンがはみ出しうる（1.4 と同じ） | §0.6 で伝えた。上限は範囲外（§1.4） |
| ご依頼は本人の 1.1.1 の並べ替えを戻す。その理由は記録に無い。「‹ 今日 ›」の隣り合う 44 pt の的で押し間違いが戻るかもしれない | §0.6 で伝え、確かめ表 3 で見る。3 つ離した形を言葉の選びに（§0.4） |
| 1.4 はまだ審査中。1.4 が断られると `r141` を載せ直す | 提出は 1.4 の公開と main へのまとめの後（§9.4）。取り込んだ後のコードの差が空でなければ、基準を替えて D0 からやり直す（§9.4 の「うまくいかなかったとき」）。前の 1.4.1（ペンの色・メモ欄の紙）は 1.4.2 へ送り、その色の板は縦のツールバーからも開けるようにする（§1.4） |
| アプリの見出しとツールバーが、DESIGN が「従う」と書く Web 版からさらに離れる | Web は変えない（ほかの Pages は出さない）。DESIGN §2.7 に書く（§8.6） |
| de・fr・es・it・pt-BR で利き手の語が性別の付く形になりうる | X が訳す前に GLOSSARY で right-hand / left-hand の形を決める（§8.2） |
| Connect で、1.4 の審査中に 1.4.1 のビルドを TestFlight に上げられるか、版 1.4.1 の入れ物をいつ作れるか【推定】 | TestFlight は新しい版の番号のビルドを受ける見込み。入れ物は 1.4 の公開の後に作る（§9.4 の 8）。断られたら D3 を 1.4 の公開の後にずらし、本人に知らせる |
| 1.4 の成果物が 11/28 ごろ消え、前と後の写真と関門 3 の基準を失う | S0' で D0 の前に控える（§7.7） |
| 作業の木が夜中の掃除で消える | こまめに commit、リードが GitHub に上げる |
| Claude の週の使える量の上限 | 3 週の目安と 12/18 の余裕。`docs/R1_4_1.md` に進み具合 |

---

## 12. 決めどころ（既定と理由。番号は 0e-n）

| # | 決めどころ | 既定 | 理由（参照） |
| --- | --- | --- | --- |
| 0e-1 | 版 | **1.4.1**（`project.yml:23`）、ビルド 29 以上。枝 `r141`（`r14` から。コードは 2fb8fb1 と同じ）。M7_PLAN §4 の前の 1.4.1 を 1.4.2 に、1.5 は指で予定のまま。契約は M7D の 16 節の形、結果と前もっての宣言は `docs/R1_4_1.md`。提出は 1.4 の公開と `--no-ff` のまとめと、`r141` の取り込みと木の確かめの後 | 1.4 は審査中で、Connect は大きくなる版を求める。1.4 は凍結の表を作り直す版を 1.4.1 と名指していた（0d-44・SpanGuard。`docs/M7_PLAN.md:518-519`、`docs/M7D_CONTRACT.md:136`・`:141`） |
| 0e-2 | 見出しの部品 | 「‹ 今日 ›」は 1 つの枠（Capsule 36 pt・3 つの Button・44×44 の的・2 本の細い線）。ja 約 135.4、en・de 約 151.4【推定】。`header.today` に ‹ › を入れない。等倍は `1.magnifyingglass`、identifier `header.zoomReset`、読み上げ `header.zoomReset.spoken` | 1.1 の離れた 3 つより約 20〜26 pt 狭く【推定。§3.1】、どの iPhone でも ja の一番長い短い題に 70 pt。ピン留めのテストが読む名前と identifier は同じ。記号は訳も幅のテストも要らない（`PageHeaderView.swift:205-234`、`app-P.json:431-446`、`PaperFitTests.swift:379-396`、`YearTapUITests.swift:80-122`、`TESTS_1_3.sha256:27-29`） |
| 0e-3 | 並び | 純粋な表 `HeaderOrder.pieces(arm:hand:readOnly:)`。左手は右手の逆。`layoutDirection` を使わない。広い行は `HStack(spacing: 6)`、狭い行は 1 段目と 2 段目（§3.2）。並べ方 (b) は §3.2 の (b) の表（`r141-alt` の写真、選ばれたら既定に）。Duo の詰めた行（§2.1 の 7 つ）は duo.yml で示せたときだけやめる | 1 つの並びの表なら鏡をテストで固められ、日週月年や ◀ ▶ が裏返らない。詰めた行は前の行に場所が無かったため（`PageHeaderView.swift:107-161`・`:165-180`、`CalendarRootScreen.swift:857-881`、`DuoLayoutUITests.swift:57-88`、`shot_checks.py:18-24`、`LocalizationBundleTests.swift:104-113`） |
| 0e-4 | 見出しの高さ | 1 段目と広い行は 44 のまま。2 段目は `HStack(spacing: 8){Z, 切り替え}.fixedSize(horizontal: false, vertical: true)`、Z は `maxHeight: .infinity`。関門: 紙の領域の行が 1.4 と同じ、Z の高さ ≤ 切り替え ＋ 0.5。落ちたら固定の枠 | 紙の領域は開いた倍率・関門 3・`SpanPlan.referenceViewport`・`DuoChecks` の元。変わらなければ計算し直さなくてよい（`docs/M7D_CONTRACT.md:408-411`、`SpanPlan.swift:259-284`、`DuoChecks.swift:96-103`、`CalendarRootScreen.swift:600-616`） |
| 0e-5 | 題名と印 | 狭い行 `compactTitle`・広い行 `title`、F-11 と縮みと「…」と `page.title` は同じ。右手は `.leading`、左手は `.trailing`。縮むのは題名だけ。閲覧専用の印は広い行の切り替えと ＋予定 の間。狭い行は注意の行。「‹ 今日 ›」と等倍は読み取り専用でも押せる | 本人の言葉の受け取り方 (a)（並べ方 (a)）。「今日」が右から抜けるので印の場所が要る（`PageHeaderView.swift:15-18`・`:62-68`、`docs/M5_CONTRACT.md:482-484`、`CalendarRootScreen.swift:24-43`） |
| 0e-6 | 広い行を測る | `HeaderRoomUITests`（ログだけ）を blank-paper の 4 機種と iPhone 17 の横で。関門 D1a: ja の広い日の題 ≥ 115（mini・Air 11・Pro 13 の縦）。逃げ道は 760 未満で間隔 4。祝日つきの ja の日の題の切れと、600〜700 の窓は記録 | 広い行は測ったことが無く、数は全部推定（`HeaderAndPaperUITests.swift:159-162`、`build.yml` の blank-paper の機種の表、`docs/M4B_CONTRACT.md:577`） |
| 0e-7 | 等倍の意味 | 比 1 = 今の範囲の `Bounds.open`。週・日は拡大を戻すだけ、月・年は open より小さい物も戻す、横の道は帯の open（上限があれば上限）。いつも見えて押せる。open で押しても何もしない。読み取り専用でも押せる。ショートカットは無し。画面は `zoomResetTrigger` と `resetZoom()`、両方のキャンバスの最後の引数。今日と `ScreenPaths.today` は替えない | 比 1 はアプリが「拡大していない」として覚えている値。薄くする形は新しい出力が要る。`ScreenPaths.today` はピン留め（`ZoomPolicy.swift:112-167`、`CalendarRootScreen.swift:1107`・`:1165`・`:2832`・`:2900`、`ScreenPathsSpanTests.swift:1228-1250`） |
| 0e-8 | キャンバスの仕組み | 凍結の 1 行目だけを作り直し、足す行で: 入力 `zoomResetTrigger`（`:243` の後）、`lastZoomResetTrigger`（`:640` の隣）、step 8（`:987-993` の後、次のターン）、`resetZoomToOpen()`（`:1412-1417` の後、`scrollViewDidEndZooming` で終える）、DEBUG の NSLog。約 45 行。キャンバスをアプリの側で作り直す形は採らない | 凍結の表に触れる所が一番小さく、`revealTrigger` で確かめ済みの形。`CanvasCommand` も新しい出力も無く、保存・merge・同期・墓標の行に触れない。作り直しは最後の線・↶・選びを失い、1 ページの道では何も起きない（`InkCanvasView.swift:243`・`:640`・`:987-993`・`:1229`・`:2126-2149`・`:1434-1445`、`OnePageSession.swift:17-19`） |
| 0e-9 | 等倍の規則 | 落とす: 無い・最初の倍率の前・live・`isUsingTool`・`resetScroll`・`isMovingSelection`・横の道で指が押さえている。`isSettling` では落とさない。滑りは先に止める。差が 0.0005 未満なら何もしない。戻す順（§3.8）。動かさない | 今日の守りと同じ（ペンやつまみの最中は動かない）。落とすので後で勝手に動かない。止めるので押しが黙って無視されない（`InkCanvasView.swift:986-993`・`:1779-1800`・`:3043-3049`・`:3060-3078`・`:3199-3218`・`:1297-1329`） |
| 0e-10 | 覚えた倍率 | 比 1 の知らせが `setZoomRatio(1)` で `zoomRatio.<種類>` を消す。次の同じ種類と次の起動は等倍。画面は自分で書かない。写真モードでは書かない。`hasPinched` が false に戻るのは害が無い。本人には SUPPORT と確かめ表で | 「すぐに等倍に戻る」の単純で一貫した意味。「このページだけ」は凍結の変更が増える（`AppSettings.swift:298-324`、`CalendarRootScreen.swift:1141-1144`・`:2866-2869`、`CalendarRootScreenTests.swift:489-509`） |
| 0e-11 | 0d-44 と SpanGuard | 同じ作り直しで 0d-44 を直す: step 4 の `centerPaper` の 2 行で `lastLayoutSize` を読む（今の 2 行を変える。記録に名前を書く）。ピン留めのテストが全部そのままで `InkCanvasWidthCentreTests` が緑のときだけ残す。落ちたら戻して記録、確かめ表に行を足す。`SpanGuard .prototype`（19 行目）は残し、19 行目を作り直す次の版へ送る | 1.4 がこの直しを 1.4.1 に約束した。左右のツールバーで幅の変化がふつうになり、直さないと拡大中に置くたびに 37 pt ずれる。横の道は `layoutMid` で前から戻している（`InkCanvasView.swift:1245-1274`、`docs/M7D_CONTRACT.md:136`・`:141`・`:1124`、`DATA_1_1.sha256:19`、`InkCanvasViewTests.swift:417-458`） |
| 0e-12 | 利き手の設定 | 鍵 `layout.hand`（"right"・"left"、無い・知らない字は右手）。端末ごと、iCloud に送らない、`isExistingUser` の鍵でない。`@AppStorage` で読む。`inputSections` の最後に `Section`（チェックの 2 行、見出し・脚注・identifier `settings.hand`）。`.onChange` で手と `collapsedEdge` を 1 回書く（写真モードでは書かない）。写真モード `--screenshot-hand left` | String の 2 択の形はもうある。`inputSections` の中なら `SettingsPageSectionTests` と `ScreenshotModeSpanTests` がそのまま通る（`AppSettings.swift:56-58`・`:160-164`、`SettingsScreen.swift:443-474`、`SettingsPageSectionTests.swift:124-137`、`ScreenshotModeSpanTests.swift:673-685`、`AppSettingsTests.swift:157-192`） |
| 0e-13 | 左手で替わる物 | 替わる: 見出しの順（題名は右寄せ、Z は 2 段目の右）と、丸いボタンの角（1 回の書き込み。後は長押しと VoiceOver で、最後が勝つ）。替わらない: 紙・貼り付く見出し・終日帯・滑る向き、日週月年の順・◀ ▶・記号、ツールバーの中の順、ツールバーの辺、トーストほか。VoiceOver は見た目の順 | 空いた手の側にその手のボタンを。紙や読む順に結びつく物は動かさない。手と辺を結ぶと思わぬ組み合わせが出る（`ToolbarDock.swift:22-30`・`:63-64`、`PaperSpec.swift:47-52`、`ToolbarFitTests.swift:55`、`EraserAndBelowDayUITests.swift:630-646`） |
| 0e-14 | 動かせる辺 | 純粋な `allowedEdges(isPad:windowSize:column:paperColumnHeight:)`。idiom を自分では読まず、画面が `pencilPhone.isPad`（idiom-allow の 2 行目の値）を渡す。iPhone（Duo を含む）は窓の大きさに関わらず下だけ。iPad: 下はいつも、上は `isWide`、左右は `isWide` かつ列 ≥ 700 かつ紙の列の高さ ≥ 460。`PaletteEdge(stored:)` → 下。`effectiveEdge` は覚えた値を書き換えない | Apple と同じく広い窓でだけ、iPhone は下に固定。本人に伝えた「iPhone は下のまま」。Duo の内側は CI で開けず本人も持たないので、確かめられない形を作らない（第 2 版で設計の「Duo の内側の縦は上と下」から替えた）。700 の下限で `smallScreen` が替わらない（列 ≥ 626）（`WindowClass.swift:12-22`・`:35-39`、`CalendarRootScreen.swift:202`・`:1106`・`:1847-1849`・`:2950-2953`、`tools/duo/idiom-allow.txt`、`docs/M7D.md:30`・`:368`） |
| 0e-15 | 置き場所の枠と紙の領域 | 修飾子と枠はいつも付けたまま。下は 1.4 の inset（1 辺だけの窓では同じ）。上は注意の行と貼り付く見出しの間の 74 の枠（紙の領域は下と同じ）。左右は貼り付く見出しとキャンバスを `HStack` で包む 74 の枠、見出しは全幅、列の幅を 4 つのつなぎへ。しまった状態は 1.4 | 1.1 から開いたバーは紙に重ならない。凍結のキャンバスには下の余白しか無いので、上や横に重ねると出せない紙が隠れる（`CalendarRootScreen.swift:737-743`・`:851-925`、`InkCanvasView.swift:1337-1346`、`ToolbarLogic.swift:252-271`、`docs/M7A.md:397-406`、`InkCanvasSpanTests.swift:1218-1223`） |
| 0e-16 | つまみ | 開いて許す辺が 2 つ以上のときだけ、真ん中に向いた辺に 36×5。当たりは枠の中（上下 120×16、横 14×120）。つまみのある下のバーは inset の間隔 0 ＋ 上の余白 8（74 のまま）。丸いボタンとのぞきには無い | 8 pt の帯だけでは細すぎ、inset の間隔への触れは届く保証が無い。iPhone は 1 バイトも同じ（`CalendarRootScreen.swift:737-743`、`YearTapUITests.swift:15-17`、`EraserAndBelowDayUITests.swift:612-646`、`ToolbarLogic.swift:274-322`） |
| 0e-17 | 入力と手のひら | `PaletteGripView`（pan、`[.direct, .indirectPointer]`、10 pt で開始）。始まりは凍結の `horizontalPanMayBegin`。入力は新しい `PalmWatch`（凍結の `InkTouchObserver` の新しいインスタンスを窓に。許す辺が 2 つ以上のときだけ）。iPad に付ける新しい道で、0d-39 を `PencilPhone` に狭める。取り消し: Pencil の触れ・`penDown()` の最初の行・背景・窓の大きさ・シート。ピン留めの字はそのまま | アプリ自身の手のひらの規則。`onPenDown` は書き始めだけなので「1 秒後」は長い線を見逃す（`InkCanvasView.swift:2412-2440`、`InkTouchObserver.swift:19-38`、`PencilPhone.swift:132-148`、`docs/M7D_CONTRACT.md:1119`、`CalendarRootScreen.swift:1042-1056`、`SpanGuideSeenSpanTests.swift:264-268`、`ScreenPathsSpanTests.swift:1932-1938`） |
| 0e-18 | 動かしている間と吸い付き | 並べ直さない: バーは 40 % で残る、押せない puck（96×48、指の 40 pt 上）、許す辺の輪郭（12 %・先は 28 % と 2 pt）。吸い付き: 速さ × 0.15 秒先へ、真ん中 25 % の範囲なら今の辺、ほかは一番近い辺（同じなら今・下・上・左・右）。離した時: 違えば書く、動かない 1 つのトランザクション、puck と輪郭は消える。`placementChosen` と `storesPlacement` | 1.1 の D1（書くペンの下で倍率を動かさない）。動かない範囲で手のひらの引きは今の辺に戻る。1 つのトランザクションで `containerDidLayout` が何度も呼ばれない（`ToolbarLogic.swift:221-250`、`docs/M7A_CONTRACT.md:11`、`ToolbarDock.swift:4-65`） |
| 0e-19 | 縦のツールバー | `ToolbarView(axis: .vertical)`、既定の横は 1.4 のまま。幅 60、縦の `ScrollView`（道具 5・区切り・色・細中太・↶↷・印だけの指でも書く）、外に「しまう」。説明の行は読み上げのヒントに。identifier は同じ。ペンで約 830 pt【推定】 | 細い 1 列で紙の減りを 74 に。2 列（134）は言葉の選び（`ToolbarView.swift:57-113`・`:190-232`、`DuoLayoutUITests.swift:323-331`、`LanguageUITests.swift:41-42`） |
| 0e-20 | のぞき・丸いボタン・トースト | のぞきは今の辺に重ねる（覚えない、Pencil・しまう・背景でしまう）。左に置けば `collapsedEdge = leading`、右なら trailing、上下は替えない。`toastBottomPadding` は同じ、左右に開いているときだけ `toastSideInset` 74 | のぞきはバーがあった所に（Apple も元の所に戻す）。丸いボタンの角は最後の操作に従う（`CalendarRootScreen.swift:690-735`、`ToolbarLogic.swift:252-271`、`ToolbarDock.swift:22-30`） |
| 0e-21 | 覚え方と写真 | 鍵 `toolbar.paletteEdge`（無い・知らない字は下）、端末に 1 つ、iCloud に送らない。書くのは離した時と VoiceOver の時だけ、写真モードでは書かない（写真モードでは離した辺を画面の `@State` にだけ持ち、初めの値は `--screenshot-palette`。§4.10）。回転・Split View: 効く辺は許されれば覚えた辺、でなければ下。新しい引数 `--screenshot-palette`・`--screenshot-palette-drag`。`--screenshot-toolbar`・`StartState`・ログの形は同じ、別の行 `toolbar: palette=` | ピン留めの `CalendarRootScreenTests` と `ScreenshotModeTests` が形と値を固める（`CalendarRootScreenTests.swift:406-428`、`ScreenshotModeTests.swift:365-382`、`ScreenshotMode.swift:90-107`） |
| 0e-22 | VoiceOver | つまみは 1 つの要素「ツールバーを動かす」とヒント。許す辺ごとの操作「上へ／下へ／左へ／右へ移す」。操作は離したときと同じに書き、`.layoutChanged` を出す。スイッチコントロールとフルキーボードアクセスも同じ | Apple は VoiceOver でパレットを動かす方法を書いていない。HIG は動かせる道を勧める（`ToolbarDock.swift:63-64`） |
| 0e-23 | CI の道 | 枝の配線 `r141*`（QUICK・MUTATIONS・言語の写真・`branches-ignore`・duo.yml）。写真を撮る枝（`r141-alt`・写真だけの試し）は `q-` の外（§6.6）。`:672` の正規表現に 7 つのクラス。ui-tests に `HeaderAndPaperUITests`・`ZoomResetUITests`、`:2013` に `zoom-reset UI:`。blank-paper に iPad 13 のツールバーの UI テストの段（20 分、`palette UI:`、段の結果を関門 1 で読む）と `HeaderRoomUITests`。iPad の横の写真は XCUI の回転と `simctl io screenshot` だけ。凍結の段の名前を 1.4.1 に | iPad の UI テストの道が今は無く、iPadOS は `--screenshot-landscape` を無視する（`build.yml:672`・`:1990`・`:2013`・`:2967-2975`・`:911-914`・`:3337-3340`・`:3591`・`:438`、`duo.yml:37-41`） |
| 0e-24 | J-4 | 新しい基準 `ja-baseline-ref-1.4.1.txt` = 2fb8fb1。D0 は `sheet-info` だけ。機能の commit の違ってよい所は D0 の前に `docs/R1_4_1.md` に、機種ごとの画素の行を 1.4 の写真から測って（見出しの帯・iPad のつまみの帯・`sheet-info`・設定の入力の節から下）。関門 3: 紙の領域の行が 1.4 と同じ。見出しの切り抜きを役ごとに。`ink_ref`・`ink_ref_xcui` を D1 の最初の通しの run から作り直す。店の写真は既定で撮り直さない。§7.4 の新しい写真は `screenshots` の外の成果物で、`ja-baseline.yml` に足さない。**本人の選びの写真は 2 組だけ（リードの調整、`r141-alt`）** | `compare_shots` に覆いは無い。行を除いた確かめで見出しの下を全部、見出しの帯は人が見る（`shift_pair.swift:1-23`、`ja-baseline.yml:124`、`docs/M7D_CONTRACT.md:431-469`、`ink_check.swift:9-20`、`docs/M7D_CONTRACT.md:1104`） |
| 0e-25 | 範囲外 | ⌘0 などのショートカット、動く拡大、自由な位置・辺の上の位置・自動の最小化・角で丸く、Pencil で動かす、iPhone の下以外（本人の選び）、ツールバーの中の鏡、Web 版の見出し、見出しの Dynamic Type の上限、店の写真の撮り直し（本人の選び）、ペンの色の板（1.4.2。縦のバーからも開くこと） | どれも本人の言葉の外で、危険と確かめ表の行を増やすだけ（`docs/PLAN_PEN_COLORS.md:7`、`docs/DESIGN.md:212`） |

---

## 13. 確かめていないこと・出典

### 13.1 確かめていないこと【未確認】

1. 「‹ 今日 ›」の枠の幅（ja 約 135.4・en と de 約 151.4）、狭い 1 段目の固定の幅（ja 約 297.4）、広い行の題名の場所（§3.5）。どれも設計の計算で、測っていない。
2. 狭い 2 段目の切り替えの高さ（今まで測ったことが無い）。
3. `1.magnifyingglass` が iOS 17〜27 の全部で出るか。iOS 27.2 で在ることは `HeaderGlyphTests` で見る（CI のシミュレータは 27.2 だけ）。iOS 17 は、`xcode-27` の環境に iOS 17 の実行環境が無いので確かめられない（`docs/M7D_CONTRACT.md:792`）。SF Symbols の古い版（14 以上）から在る記号なので出る見込み【推定】。「Apple が実際の大きさに使う印」というのも【推定】。
4. Apple のパレットの細かい動き: 動かしている間に丸に縮む、左右で縦、角で丸、辺の上の位置、Pencil で動くか（第三者の資料・利用者の報告・記憶。§13.2）。VoiceOver で動かす方法は Apple の文書に見当たらない。
5. PalmWatch（窓の `InkTouchObserver`）が iPad の PencilKit・手のひら・横の道に影響しないか。CI のシミュレータでは Pencil の触れを作れない（M7D_CONTRACT §13.1 の 16）。
6. 120×16 pt のつまみに指が確実に届くか。
7. Mac（Designed for iPad）での、下のバーの明示の 8 pt と 74 pt（iPhone は Duo の内側も含めて下だけで 1.4 と同じ。§4.3）。
8. iPad の横の写真を、span-shots-app の XCUI の回転で、ツールバーの置き場所つきで撮れるか。
9. blank-paper と span-shots-app が、新しい段と写真で時間の上限に収まるか。
10. Duo の外側の新しい狭い 1 段目の題名の場所（推定 84.6）。duo.yml で測る。
11. 1.4 の審査の結果（断られたら `r141` を載せ直す）。
12. 1.4 の審査中に、版 1.4.1 のビルドを TestFlight に上げられるか（新しい版の番号のビルドは受ける見込み【推定】）。版 1.4.1 の入れ物を Connect に作れるのは 1.4 の公開の後か【推定】。Connect が新しい版で前の版の写真（Duo を含む）を引き継ぐか【推定】。
13. 本人が 1.1.1 で「今日」を右へ移した理由（`docs/R1_1_1.md:19-23`。理由は書かれていない。本人だけが答えられる）。
14. de・fr・es・it・pt-BR の性別の無い「右手・左手」の言い方。
15. Web 版（別のリポジトリ）の見出しとツールバーの今の形（読んでいない）。
16. 「‹ 今日 ›」の枠の中の隣り合う 44 pt の的で押し間違いが出るか（本人の確かめ表 3）。
17. 年末の審査の遅れ（12/19〜1/4）。
18. 1.4 の成果物の消える日時（7 日の保管。11/28 ごろ）。
19. 「開き直しても等倍」「開き直しても辺が残る」の UI テストの形（写真モードでは倍率も辺も書かない。§6.1 の注）。

### 13.2 出典

**コード・記録**（この契約の書き手が 2026-11-21 に `r141` 56b7031 で読んだ。行番号は本文のとおり）: `PageHeaderView.swift`・`CalendarRootScreen.swift`・`InkCanvasView.swift`・`ZoomPolicy.swift`・`SpanLayout.swift`・`AppSettings.swift`・`OnePageSession.swift`・`SettingsScreen.swift`・`ToolbarLogic.swift`・`ToolbarDock.swift`・`ToolbarView.swift`・`InkTouchObserver.swift`・`PencilPhone.swift`・`WindowClass.swift`・`PaperSpec.swift`・`SpanPlan.swift`・`DuoChecks.swift`・`ScreenshotMode.swift`・`InkTools.swift`・`PrivacyInfo.xcprivacy`、テスト（`HeaderAndPaperUITests`・`PageHeaderRoomTests`・`YearTapUITests`・`EraserAndBelowDayUITests`・`DuoLayoutUITests`・`InkCanvasViewTests`・`CalendarRootScreenTests`・`ScreenshotModeTests`・`ScreenshotModeSpanTests`・`SettingsPageSectionTests`・`SpanGuideSeenSpanTests`・`ScreenPathsSpanTests`・`OnePageRevealTests`・`InkCanvasSpanTests`・`AppSettingsTests`・`ToolbarFitTests`・`PaperFitTests`・`LocalizationBundleTests`・`LanguageUITests`）、`build.yml`・`ja-baseline.yml`・`duo.yml`、`tools/compat10/DATA_1_1.sha256`・`tools/span/*.sha256`・`tools/l10n/lint-skip.txt`・`lint.py`・`baseline.py`・`source/app-P.json`、`tools/shots/shift_pair.swift`・`ink_check.swift`・`tools/duo/shot_checks.py`、`docs/M7D.md`・`M7D_CONTRACT.md`・`M7_PLAN.md`・`M7A.md`・`M7A_CONTRACT.md`・`M5_CONTRACT.md`・`M4B_CONTRACT.md`・`M3B_CONTRACT.md`・`R1_1_1.md`・`DESIGN.md`・`PLAN_PEN_COLORS.md`・`SUPPORT.md`・`README.md`・`i18n/GLOSSARY.md`・`store/README.md`・`store/review-note.txt`。

**Apple のパレット（Web）**: 設計の調べ役が **2026-11-21** に読んだ（`v15/maps/palette-apple.md`。この契約の書き手は読み直していない）。

| 番号 | 中身 | URL |
| --- | --- | --- |
| A1 | iPad ユーザガイド「マークアップ」: ツールバーを画面のどの辺へもドラッグで動かせる。つかむのは画面の真ん中に一番近い辺。Auto-minimize | https://support.apple.com/guide/ipad/draw-and-handwrite-with-markup-ipad6350b8dc/ipados |
| A2 | 同じ案内の iPadOS 13 版（動かし方は 13 から同じ） | https://support.apple.com/guide/ipad/draw-in-apps-ipad6350b8dc/13.0/ipados/13.0 |
| A3 | iPhone ユーザガイド（動かす方法は書かれていない） | https://support.apple.com/guide/iphone/draw-in-apps-iph893c6f8bf/ios |
| A4 | PencilKit `PKToolPicker`（ウインドウの中で動かせる） | https://developer.apple.com/documentation/pencilkit/pktoolpicker |
| A5 | `PKToolPicker.frameObscured(in:)`・`PKToolPickerObserver` | https://developer.apple.com/documentation/pencilkit/pktoolpickerobserver |
| A6 | WWDC19 221（広い幅では浮いて端へ動かせる、狭い幅では下に固定） | https://developer.apple.com/videos/play/wwdc2019/221 |
| A7 | WWDC24 10214（iPhone では下に固定。accessoryItem） | https://developer.apple.com/videos/play/wwdc2024/10214/ |
| A8 | HIG Apple Pencil and Scribble（手に隠れないよう、動かせるように） | https://developer.apple.com/design/human-interface-guidelines/apple-pencil-and-scribble |
| A9 | 第三者のデザイン素材 PencilKitForSketch（動かしている間に丸、左右で縦）【未確認】 | https://github.com/WireFrameRate/PencilKitForSketch/blob/master/README.md |
| A10 | Apple のコミュニティの報告（Pages・Notes での置き場所）【未確認】 | https://discussions.apple.com/thread/256161206 ・ https://discussions.apple.com/thread/256192972 |

---

## 14. 記録

- 2026-11-21 **第 1 版**（契約の書き手。リードの指示で、設計 `v15/design/final.md`（決定 0e-1〜0e-25・凍結の変更・ファイル・文・テスト・写真と J-4・確かめ表・本人の選び・段・危険）と `all.json`（3 つの案と 2 つの審査）、コードの地図 8 つ（批評が正）を読んで書いた）。
  - **リードの調整を入れた**: 写真で見せる本人の選びは (A) 見出しの読み方と (B) 等倍の顔の 2 つだけ（`r141-q-alt` の DEBUG だけの写真の引数）。ほかの 6 つは確認ページに言葉で既定とともに書く（§0.4・§7.5）。本人にチャットで伝えたこと（§1.2）と、4 つの言葉・確かめていない版は出さない・提出の前の 1.4 の公開とまとめの決まりを §0.4・§9.4 に。
  - **コードで読み直した行**（56b7031）: `project.yml:21-23`、`PageHeaderView.swift:15-18`・`:62-68`・`:93-114`・`:120-161`・`:165-180`・`:205-234`・`:236-266`・`:314`、`CalendarRootScreen.swift:24-43`・`:339`・`:395-402`・`:553`・`:576`・`:600-616`・`:629-635`・`:690-743`・`:754`・`:851-925`・`:1042-1056`・`:1104-1110`・`:1139-1146`・`:1160-1168`・`:1601-1627`・`:1845-1849`・`:2830-2834`・`:2864-2870`・`:2896-2912`・`:2950-2955`・`:3111`、`InkCanvasView.swift:18-22`・`:140-145`・`:236-246`・`:445-521`・`:632-645`・`:980-996`・`:1126-1133`・`:1192-1232`・`:1243-1290`・`:1297-1346`・`:1396-1417`・`:1434-1450`・`:1779-1800`・`:2126-2150`・`:2410-2440`・`:2554-2598`・`:3040-3078`・`:3196-3218`、`ZoomPolicy.swift:108-170`、`SpanLayout.swift:99`・`:110`・`:127`、`AppSettings.swift:28`・`:52-61`・`:69`・`:113-122`・`:128`・`:156-166`・`:296-326`、`OnePageSession.swift:1-34`、`SettingsScreen.swift:440-476`、`ToolbarLogic.swift:1-110`・`:220-330`、`ToolbarDock.swift:1-70`、`ToolbarView.swift:57-113`・`:186-232`・`:312-317`、`InkTouchObserver.swift:15-40`、`PencilPhone.swift:128-148`、`WindowClass.swift:14-24`、`PaperSpec.swift:45-52`、`SpanPlan.swift:257-284`、`DuoChecks.swift:93-105`、`ScreenshotMode.swift:88-107`・`:180`・`:204`・`:334`・`:373-374`、`InkTools.swift:49-50`、`PrivacyInfo.xcprivacy:18`。テスト: `HeaderAndPaperUITests.swift:1-75`・`:155-163`、`PageHeaderRoomTests.swift:1-60`・`:120-135`、`YearTapUITests.swift:12-18`・`:80-122`、`EraserAndBelowDayUITests.swift:610-646`、`DuoLayoutUITests.swift:55-90`、`InkCanvasViewTests.swift:415-458`、`CalendarRootScreenTests.swift:404-430`・`:479-482`・`:487-510`、`ScreenshotModeTests.swift:363-383`、`ScreenshotModeSpanTests.swift:670-686`、`SettingsPageSectionTests.swift:76-98`・`:122-138`、`SpanGuideSeenSpanTests.swift:262-269`、`ScreenPathsSpanTests.swift:1226-1251`・`:1836-1856`・`:1930-1939`、`OnePageRevealTests.swift:15-40`、`InkCanvasSpanTests.swift:1215-1224`、`AppSettingsTests.swift:155-194`、`ToolbarFitTests.swift:52-57`、`PaperFitTests.swift:376-398`、`LocalizationBundleTests.swift:102-114`、`LanguageUITests.swift:39-43`。CI: `build.yml:65-87`・`:141-149`・`:438`・`:644-672`・`:911-914`・`:1685-1687`・`:1990-2013`・`:2116-2125`・`:2481-2488`・`:2967-2975`・`:3146`・`:3165-3180`・`:3337-3340`・`:3375-3380`・`:3591`・`:4017-4022`、`duo.yml:35-42`、`ja-baseline.yml:120-126`。表: `DATA_1_1.sha256`（20 行）、`TESTS_1_3.sha256`（29）、`TESTS_1_2_3.sha256`（8）、`FIXTURES_1_3.sha256`（37）、`lint-skip.txt`（注を除いて 20）。
  - **設計と違えた所（コードで直した行番号）**: step 7 は `:987-993`（設計は `:988-994`。`:994` は `update(from:)` の終わり）。`reveal()` は `:1412-1417`。`horizontalPanMayBegin` は `:2432-2440`（`palmHold` は `:2414`）。`isBandMoving` は `:3214-3218`。`ToolbarLogic` の「66 pt」の注は `:11-16`（批評の `:7-9` は頭の注）。設定の 9 つの並びは `SettingsPageSectionTests.swift:127-128`。
  - 1.4 の基準の数は M7D.md の「通しの run」と「StoreKit の直しの後の通しの run」で確かめた（KitChecks 40,826／閾値 40,776、単体 781、UI 43 が走った、compat10 599、span-compat 274/274/278/310）。
- 2026-11-21 **第 2 版**（2 つの審査の指摘で直した。commit の前）。直した所:
  - **iPhone は下だけ**（§0.1・§2.1・§4.3・§6.1・0e-14・§15）: `allowedEdges` に `isPad`（画面の `pencilPhone.isPad`。新しい idiom の読みは無い）を足し、Duo の内側の広い窓も下だけにした。第 1 版は idiom を読まず、Duo の内側に上と下（横では 4 つ）を許し、本人に伝えた「iPhone は下のまま」と §0.2・§8.4・行 18 に合わなかった。13 インチの横の ½ の Split View（約 683×1032）は上と下（§4.3）。
  - **並べ方 (b) の表**（§3.2・§6.2・§8.3〜§8.5）、**写真の枝の名前** `r141-q-alt` → `r141-alt`（`r141-q-*` は速い道で写真が撮れない。§6.6・§7.5）、**§7.4 の新しい写真は `screenshots` の外**（§7.1）。
  - **ピン留めの字の一覧を足した**（§5.6: `guide.dismiss()` の 3 つと `sheetsChanged()` の `if`、`allowFinger: allowFingerBinding,` の 2 つ、`pinchBegan`・`joinedTap`・`eraseAllInk`・`show`）。シートの取り消しは自分の `.onChange`、`ToolbarView(` の呼び出しは 1 つ（§4.6・§4.8）。
  - 数と形: 横の週の列の幅 vw × 190.857 / 4200（§6.1）、18 Pro Max の横の題名の場所 約 224（§3.5）、`ToolbarStep` の明示の init（§2.1）、`header.today` の `was` は 1.1 の行のまま（§8.1）、つまみの当たりが横の行の `ScrollView` の上の余白に重なること（§4.5）、写真モードの辺は画面の `@State`（§4.10）、はじいた滑りはテストにしない（§3.8）、`HeaderGlyphTests` は iOS 27.2 だけ（§13.1）、「1.1 の離れた 3 つ」と 20〜26 pt（§0.4・§3.1・0e-2）、やめる物は 7 つ（§3.2）。
  - 段: S0' を D0 の前（11/22）に（§0.3・§7.7・§9.1）。11 インチの写真は J-4 では iPad Pro 11（§7.3）。
  - 本人向けの §0: 等倍の意味（もとの大きさ）、§0.2 の食い違い 2 つ、§0.1 の「お約束」の言い方、§0.4 の言葉（並べ方・見た目・cm）と縦の月の小ささの数、§0.5 の箇条、§0.6 の Apple との比べ方と 1.4.2 の中身。
  - 出し方: 選びごとにやり直す確かめ表の行、うまくいかなかったときの表、`pull --ff-only`（§9.4）。確かめ表に同期と開き直しの 2 行（行 20・21。Duo は行 22）、行 6・8・15 を直した（§10）。SUPPORT の 3 か所と「4,000 字まで」（§8.3・§8.5）。§6.1 の表の切れ、§8.1 の列の名前、§4.8 の「本人の 2 列」の言い方。
- 2026-11-22 **第 3 版**（契約の書き手。本人の 11/22 の直し（12:2x・12:3x・12:4x）と既定への答え（13:0x）を、リードの設計 `rework/plan.md`（スクラッチ、リポジトリの外）と地図 3 つ（header・zoom・texts）から入れた。commit の前）。
  - **書き直した所**: 題名と頭の書き（第 3 版の注と「§16 が優先」）、§0（本人向け。変わること・変わらないこと・段取り・お願い・決めなくてよいこと・知っておいてほしいこと。ビルド 29 と確認ページ H6UmrMEkCvejMUp817VNJH を使わないこと）、§10（確かめ表 22 行。準備の文と行 1〜9・11〜13 を書き直し、行 10・14〜22 はそのまま。Duo の行 22 は「—」。第 2 版の注「0d-44 の直しを戻したとき…行 11・13 を替える」は消した。0d-44 は D1a で「残す」に決まったため（`docs/R1_4_1.md` の D1a の関門の表、`:195`）。「11/22 の表から変わった行」の注も消した（本人はビルド 29 の表を使わないため）。
  - **足した所**: §16（本人の言葉とリードの読み、見出しの並び案 B と写真の選びの案 A、日・週の等倍 `fit = vw / W` と状態としての覚え方 `zoomFit.<種類>`、凍結の 1 行目の 2 回目の作り直し（入力 `initialFit`・出力 `onZoomFitChange`・状態 `followsFit`）、役ごとのコードの変更、テスト、変異 MZ4〜MZ6・MS3、CI・J-4・関門 3・写真、文と訳、段 N0〜N6、本人への問い 8 つ（2〜8 は 13:0x で既定に決まった）、読み替える前の節の一覧）。
  - §1〜§9・§11〜§13・§15 の字は第 2 版のまま（§16.12 で読み替える）。
  - **コードで読み直した行**（`r141` a172cc5。コードは 2169117・be0a22b と同じ）: `Views/HeaderOrder.swift:1-65`、`Views/PageHeaderView.swift:6-45`・`:100-138`・`:195-286`、`TegakiKit/Sources/Layout/ZoomPolicy.swift:48-60`・`:110-195`・`:280-292`、`SpanLayout.swift:105-114`、`SpanPlan.swift:335-342`、`PageNavigation.swift:140-166`、`Ink/InkCanvasView.swift:236-252`・`:450-458`・`:1010-1014`・`:1100-1118`・`:1215-1310`・`:1328-1358`・`:1440-1532`・`:2195-2204`・`:2210-2234`・`:3122-3170`・`:3208-3218`、`Views/CalendarRootScreen.swift:74-80`・`:258-265`・`:584-642`・`:965-976`・`:1263`・`:1266-1300`・`:1736-1768`・`:2958-2975`・`:2993`・`:3000-3010`・`:3036-3045`・`:3310-3320`、`Span/ScreenPaths.swift:958-968`・`:998-1010`・`:1173-1190`・`:1245-1270`、`Support/ScreenshotMode.swift:260-276`・`:375-388`・`:438-450`・`:465`・`:501-504`、`Persistence/AppSettings.swift:125-135`・`:330-375`、`Views/ToolbarLogic.swift:20-36`、`Views/SettingsScreen.swift:18-24`・`:184-198`。テスト: `HeaderOrderTests.swift:1-95`、`HeaderAndPaperUITests.swift:1-60`・`:105-175`、`HeaderRoomUITests.swift:20-23`・`:60-82`、`PageHeaderRoomTests.swift:100-126`、`InkCanvasZoomResetTests.swift:227-518`（名前）・`:450-518`、`InkCanvasSpanZoomResetTests.swift:17-18`・`:113`・`:193-323`（名前）、`ZoomResetUITests.swift:30-100`・`:159`、`PaletteShotsUITests.swift:23-120`（写真の行）、`AppSettingsTests.swift:157-166`、`SettingsScreenTests.swift:268-302`、`HandSettingTests.swift:72-77`。CI と表: `build.yml:444`・`:655-685`・`:1999-2004`・`:2030`、`DATA_1_1.sha256`（20 行、1 行目 `23481b0f…2697`）、`TESTS_1_3` 29・`TESTS_1_2_3` 8・`FIXTURES_1_3` 37。文: `tools/l10n/source/app-P.json:429-452`、`Localizable.xcstrings:8583-8587`、`docs/i18n/GLOSSARY.md:218-246`、`docs/SUPPORT.md:147`・`:153`・`:157`、`docs/SUPPORT.en.md:158`・`:162`、`docs/store/review-note.txt`（3,924 バイト）、`docs/DESIGN.md:101`・`:212-219`、`README.md:60`・`:82`、`docs/M7_PLAN.md:11`・`:35`・`:228`・`:510`・`:522`・`:710-718`、`docs/R1_1_1.md:19`、`docs/M5_CONTRACT.md:482`、`docs/M7A_CONTRACT.md:7`。
  - **設計（plan.md）と違えた所**: P-4 の手のひらの理由は `docs/M7_PLAN.md:714`（plan の `:715` は選び B の行）。`PageNavigation.swift` は `TegakiKit/Sources/Layout/` の下。`HeaderAndPaperUITests` の範囲は `:113-132`・`:160-172`（plan は `:114-131`・`:158-171`）、`ZoomResetUITests` の 3 本目は `:67-94`（plan は `:67-98`）、`ScreenshotMode.Config.hand` は `:269-273`（plan の `:266-273` は `pencilPhone` を含む）。`build.yml` の持ち主は N1 では S の枝（plan は書いていない）。字の等倍のボタンの `r141-alt` の写真は、本人の 13:0x の答え（印）で既定を「撮らない」にした（plan は撮る）。
  - **2 つの見直し（事実・本人の目。11/22、commit の前）を入れた**: N1 の S と U は Z の物が無いとビルドできないので、速い道はまとめの枝 `r141-w-b2`（§16.10）。左右の端のしまうで fit が変わる（`paletteSideWidth`、§16.3.1・§16.3.5）。open = fit の所の「今日」と `zoomedIn` の viewport の無いときの式（§16.3.4・§16.5）。題名の場所の差の幅 ± 0.5 と 18 Pro Max の縦 142（§16.2）。⚙ と ‹ の間だけを 8 にする逃げ道（§16.2・§16.10）。§5.4 の手順 4 の J-4 を N4 に送る決定（§16.4）。左手の日付の寄せ方を §0.4 に戻した（§16.2）。`HeaderOrderTests` の範囲 `:20-24`、MZ3 と y を見る新しいテスト（§16.6・§16.7）、§16.12 の足りない行、iPhone 17 の横の 1 ページの道の行（§16.3.1）、`:1483`、【推定】の拠り所、`pinchAndReset`、`codeOnly`、`:2967` の名前、palette の `ok=yes` 18 行、1 回目の作り直しの commit。本人向け: §0.1 の引用を原文に、1.4 との比べ、案 A・案 B の名前、見える時間（日は 2〜3 時間。チャットでの「約 4 時間」との違い）、縦と横で分けて覚えないこと、いちばん小さくすれば戻ること、確かめ表の準備（ツールバーを下へ）と行 3・4・5・7・8・9・12・13 の字。

（結果は `docs/R1_4_1.md` に書く。ここは契約の版の記録だけ。）

---

## 15. 批判への答え（設計の 2 つの審査）

設計の 3 つの案（safe・apple・owner）を、2 つの審査（審査 1・審査 2）が比べ、誤り（E）と必ず直すこと（M）を出した。設計（final.md）と、この契約の答え。「採った」は審査の案のとおりにした所、「形を替えて採った」は狙いを受けて別の形にした所（理由を書いた）。採らなかった物は無い。

| id | 答え | 直した所と理由 |
| --- | --- | --- |
| 審査 1 E1・審査 2 E8 | 形を替えて採った | 設計は Duo の内側の縦（669×951）を上と下だけにした。契約の第 2 版で、iPhone（`pencilPhone.isPad` が false。Duo の内側の縦と横を含む）は窓の大きさに関わらず下だけにした（本人に伝えた「iPhone は下のまま」に合わせ、CI で開けない内側に確かめられない形を作らない。0e-14）。`ToolbarPlacementTests` の行（§6.1） |
| 審査 1 E2・審査 2 E6・M7・審査 1 M2 | 採った | 0d-44 を同じ作り直しで直す（0e-11、§3.10）。ピン留めのテストが変われば戻して確かめ表に行。`SpanGuard .prototype` は残して記録し、次へ送る |
| 審査 1 E3 | 採った | 下のバーが 1.4 と同じなのは iPhone と 1 辺だけの窓。iPad はつまみの分だけ明示の 8（0e-16）。J-4 の違ってよい (2)（§7.1） |
| 審査 1 E4・審査 2 E5・審査 1 M3・審査 2 M3 | 採った（取り消しは形を替えて） | 手のひらは凍結の `horizontalPanMayBegin` と、iPad の窓の新しい `PalmWatch`（0e-17）。取り消しは `onPenDown` の閉包ではなく `penDown()` の最初の行（閉包の字はピン留め、`SpanGuideSeenSpanTests.swift:264-268`）と PalmWatch の Pencil の触れ。一番近い辺と動かない範囲で手のひらの引きは今の辺に戻る（0e-18） |
| 審査 1 E5・審査 2 E9 | 採った | `isSettling` の守りを入れない。離して 0.1 秒でも効くテスト（§3.8・§6.1） |
| 審査 1 E6・E8・M4・審査 2 E7・M4 | 採った | 左右は列 ≥ 700（狭めた列 ≥ 626）で、`smallScreen` が替わらない（0e-14） |
| 審査 1 E7 | 採った | `PencilPhone.attach` は iPad ですぐ返るので、iPad に付ける新しい道（PalmWatch）。記録で 0d-39 を `PencilPhone` に狭める（0e-17） |
| 審査 1 E9・審査 2 E10 | 採った | 等倍は貯めずに落とす（保留の印を作らない）。後で関係の無い離しで動かない（0e-9） |
| 審査 1 E10 | 形を替えて採った | 0d-44 の直しは今の 2 行を変えるが、「足すだけ」の言い方を「足す行と名前を挙げた 2 行」に直し、記録に 2 行を書く。ピン留めのテストが変われば戻す（今の機種の回転の動きを変えないため。§5.4） |
| 審査 1 E11・M7 | 採った | ピン留めのソースの字を §5.6 に並べ、新しい引数は呼び出しの最後、狭めた幅は今の `viewportWidth` で |
| 審査 1 E12・審査 2 E3 | 採った | 速い道の正規表現は `build.yml:672`（§6.6） |
| 審査 1 M1・審査 2 M6 | 採った | 等倍は足す行だけ（引き金は最後、`:640` の隣、step 8 は次のターン、`scrollViewDidEndZooming` で終える）。守りは hasInitialZoom・!isLive・!isUsingTool と、横の道で指が押さえている間。滑りは先に止める。`isSettling` と保留の印は無し。凍結は 1 行目だけ、行の見直しと互換とバイトと守られたテストの後（0e-8・0e-9・§5.4） |
| 審査 1 M5・審査 2 M8 | 採った | 2 段目の等倍は `maxHeight: .infinity` と `fixedSize(vertical: true)`、PreferenceKey は使わない。関門は紙の領域の行と高さの確かめ（0e-4） |
| 審査 1 M6 | 採った | つまみの当たりは枠の中（下は間隔 0 ＋ 上の余白 8、74 のまま）。「ペン」.minY − 16 を iPhone と iPad 13 で（0e-16、D1b の関門） |
| 審査 1 M8 | 採った | `HeaderRoomUITests` で測ってから決める。ja の日の題 ≥ 115 の関門、間隔 4 の逃げ道、600〜700 の窓と祝日の題は記録（0e-6） |
| 審査 1 M9 | 採った | iPhone は下のまま・等倍は覚えた拡大も忘れる・横は紙を狭める・Apple と同じ細部は未確認・1.1.1 を戻すこと、を §0.6 に平たく書き、確かめ表 3・8・13・18 で見る |
| 審査 2 E1・M1 | 採った | blank-paper に iPad 13 のツールバーの UI テストの段。grep は `palette UI:`、関門 1 は段の結果で読む（0e-23、§6.6） |
| 審査 2 E2・M2 | 採った | iPad の横の写真は XCUI の回転と `simctl io screenshot` だけ（0e-23、§7.4） |
| 審査 2 E4 | 採った | キャンバスを作るのは `CalendarRootScreen.swift:1107` と `:2832`。引数は `:1165` と `:2900` の後（0e-7） |
| 審査 2 M5 | 採った | 置き場所は動かない 1 つのトランザクションで替え、puck と輪郭だけが動く（0e-18） |
| 審査 2 M9 | 形を替えて採った | iPhone と 1 辺だけの窓は 1.4 と 1 バイトも同じ。iPad で辺が 2 つ以上のときは、inset の間隔を 0 にしてバーの上に 8 の余白（74 のまま）。間隔の中の触れはつまみに届く保証が無い（審査 1 M6）ため、つまみを今の 8 pt の上の余白の中だけに描く形はやめた。関門 3 と「ペン」.minY − 16 で示す（0e-16） |
| 審査 2 M10 | 採った | のぞきは今の辺に重ねる（0e-20）。確かめ表 17 |
| 審査 2 M11 | 採った | 等倍のボタンの見た目の既定は記号（読み上げ「等倍に戻す」）、「等倍」の字は本人の選び (B)。字なら 9 言語・幅のテスト・逆翻訳、en に「Fit」を使わない（0e-2、§8.1） |
| 審査 2 M12 | 形を替えて採った | 詰めた行は duo.yml（`DuoLayoutUITests` 緑・外側 `header=2`・題名の場所 ≥ 80）で示せたときだけやめ、示せなければ計算し直して戻す（0e-3、D1c）。新しい狭い 1 段目は外側で 80 より広い見込み（84.6【推定】）なので、示せる道を先に試す |
| 審査 2 M13 | 採った | 規模を 3 週に（§9.2）。D3 の目安は 12/5〜12/12 |

---

## 16. 1.4.1 の直し（2026-11-22、本人の直しによる）

第 3 版で足した節。**前の節と食い違う所はこの節が優先**（読み替える節は §16.12）。行番号は `r141` の a172cc5（作業中に HEAD は 54e5b6b に進んだ。間は記録の 1 行だけ。`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` はビルド 29 の be0a22b・2 回目の通しの run の 2169117 と同じ。間の commit は文書だけ）で、この契約の書き手が 2026-11-22 にコードで読み直した（§14）。パスは断りが無ければ `Sources/TegakiCalendar/` からの相対、テストは `Tests/` の下。設計と作業の計画はリードの `rework/plan.md`（スクラッチ。リポジトリの外）と、その材料の地図 3 つ（`header.md`・`zoom.md`・`texts.md`）。印は前と同じ（【事実】【推定】【未確認】）。

### 16.1 本人の言葉とリードの読み

**本人の言葉（2026-11-22、そのまま。`docs/R1_4_1.md` の「本人の言葉と選び」から写した）**:

1. 12:2x（ビルド 29 の確認ページを渡した後）: 「大変申し訳ないのですが、＜今日＞と等倍は右端が右利き、にしてください。人間が使う場合そうなります。それと、日、週の等倍とは、最小のサイズではなく、日、週の幅が、ちょうど画面両端にくるサイズのことです。ここは私の言葉が足りませんでした。」
2. 12:3x: 「月と年は、横スクロールができる仕様にしてから、幅が両端にくる等倍を適用します。」
3. 12:4x: 「等倍は、そのように作った方が、ユーザーがいちいち指でピンチしなくてすみます。」
4. 13:0x（リードがチャットで示した既定への答え）: 「全て規定通りで進めてください。」

**リードの読み**:

| 言葉 | 読み | この契約での形 |
| --- | --- | --- |
| 1 の前半 | 右利き（既定）では「‹ 今日 ›」と等倍を右の端に、左利きはその左右逆。11/21 の「年月日は一番左側でいいです」（§1.2）は取り消されていない | 見出しの並びは案 B（§16.2）。案 A は確認ページの写真の選び |
| 1 の後半 | 日と週の等倍は、1 ページ（1 日・1 週）の幅が画面の両端にちょうど来る大きさ。月と年は言われていないので今のまま | `fit = vw / W`（§16.3.1） |
| 2 | 月と年は、まず横へスクロールできる作りにし、その後で幅の等倍。1.4.1 の月と年の等倍は今のまま（`Bounds.open`） | 月と年の横スクロールと幅の等倍は `docs/M7_PLAN.md` §4 の次の版の行（§16.3.6・§16.9） |
| 3 | 等倍のねらいは、ボタン 1 つでちょうどの大きさにし、ピンチを要らなくすること。設計の拠り所 | 等倍を状態として覚え、次に開く日・週も等倍（§16.3.4） |
| 4 | チャットで示した既定を全部採る: 右の端は「‹ 今日 ›」がいちばん端で等倍がその内側、日・週を開いたときの大きさは今のまま・等倍を一度押すとその種類は次から等倍、しまった丸いボタンは右利きで左下のまま、iPhone の横の日・週の等倍は 1 日・1 週が横いっぱい（チャットでは約 4 時間と伝えた。実際は週 4.6・日 2.6 時間【推定。zoom の地図の 18 Pro Max 横】。§0.6 で本人に違いを伝える）、等倍のボタンは虫めがねに「1」の印。並びは案 B（⚙ を左の端に置く案 A は写真で選べる）、月と年は次の版（記録の 13:0x の行のリードの読み） | §16.11 の問い 2〜8 は答え済み。問い 1（並び）だけが確認ページの写真で選べる |

- **ビルド 29（be0a22b、testflight の run 44961806963）と確認ページ（Artifact H6UmrMEkCvejMUp817VNJH）は店に使わない**。ビルド 29 の確かめ表も頼まない。新しいビルド（30 の見込み）と新しい Artifact で渡す（§16.10 の N4・N5）。
- 1.4 は 11/22 に App Store で公開され（edc3102 の commit の字）、main の edc3102 は 0fa3da4 で `r141` に入った【事実: `git merge-base --is-ancestor edc3102 r141` が真】。§9.4 の行 6 は済み。提出の前に要るのは本人の言葉だけ。

### 16.2 見出しの並び（案 B。0e-3・0e-5・0e-13 の読み替え）

**表**（左から右へ。印? は閲覧専用のときの広い行だけ。`HeaderOrder.pieces(arm:hand:readOnly:)`）:

| 行 | 右手（既定） | 左手（右手の逆。`Views/HeaderOrder.swift:60-63` の規則のまま） |
| --- | --- | --- |
| 広い行（列 ≥ 600、`HStack(spacing: 6)`） | [題名][切り替え 220][印?][＋][☁][⚙][等倍][‹今日›] | [‹今日›][等倍][⚙][☁][＋][印?][切り替え][題名] |
| 狭い 1 段目（`HStack(spacing: 4)`） | [題名][＋][☁][⚙][‹今日›] | [‹今日›][⚙][☁][＋][題名] |
| 狭い 2 段目（`HStack(spacing: 8)`、`.fixedSize(horizontal: false, vertical: true)`） | [切り替え ∞][等倍] | [等倍][切り替え ∞] |

- **コードで変わるのは表だけ**（`Views/HeaderOrder.swift:47-59` の右手の配列）:
  - `.wide`: `[.title, .picker] + (readOnly ? [.badge] : []) + [.add, .sync, .settings, .zoomReset, .today]`
  - `.compactFirst`: `[.title, .add, .sync, .settings, .today]`
  - `.compactSecond`: `[.picker, .zoomReset]`
- `HeaderPiece` の宣言の順（`:9-26`。`HeaderOrderTests.swift:27` が固める）と左手の規則（`:60-63`）は変えない。`layoutDirection` は使わない（§3.2 のまま）。
- **端の並び**: 「‹ 今日 ›」がいちばん端、等倍がその内側（本人の 13:0x の答え。今の左手で本人が写真で見た形）。
- **題名の寄せ**: `Views/PageHeaderView.swift:112` の `titleAlignment = hand == .left ? .trailing : .leading` を変えない。右手では題名が行の最初で左に寄るので、日付は左の端の余白 12 のすぐ後。空きは題名と切り替えの間（狭い行では題名と ＋ の間）にできる。第 2 版の並べ方 (b) の `gap`（`Spacer`）は作らない（`PageHeaderRoomTests.swift:104` の「`Spacer(` が無い」と `:113-114` の寄せの字の確かめは、そのまま通る）。
  - 左手の日付の寄せ方（既定は右の端。左寄せは §0.4 の言葉の選びとして残す。第 2 版の §0.4 の選びを引き継ぐ）: 本人が選んだら `titleAlignment` を `.leading` だけにし、`PageHeaderRoomTests.swift:113-114` の字を替え、確かめ表の行 1・12 をやり直してもらう（§9.4 の「左手の題名の左寄せ」の行のまま）。
- **閲覧専用の印**: 切り替えと ＋予定 の間のまま（M5 の「＋予定 の左」、`docs/M5_CONTRACT.md:482`）。`HeaderOrderTests.swift:62-71` は変えない。狭い行は今の注意の行（`readOnlyNotice`）のまま。
- **「‹ 今日 ›」の中の順**（◀ 今日 ▶）はどちらの手でも同じ（`PageHeaderView.swift:203-242` は `hand` を読まない）。
- **VoiceOver の読む順**（見た目の順。`sortPriority` は使わない、§4.2）:
  - 右手: 題名 → 切り替え → 印 → ＋ → ☁ → ⚙ → 等倍 → ◀ → 今日 → ▶
  - 左手: ◀ → 今日 → ▶ → 等倍 → ⚙ → ☁ → ＋ → 印 → 切り替え → 題名
- **隣り合うボタン（新しくなる所）**: 広い行では ⚙ と等倍が間隔 6、狭い 1 段目では ⚙ と ◀ が間隔 4 で隣り合う（1.4 でも「今日」と ＋ は間隔 4 で隣り合っていた）。押し間違えても設定のシートが開くかページが 1 つ動くだけで、書いた線に害は無い。確かめ表の行 3 で見る。× なら ⚙ と「‹ 今日 ›」の間だけを 4 → 8 にする（HStack の spacing は 4 のまま。`PageHeaderRoomTests.swift:101` の字も保つ）。題名の場所はどの狭い行でも 4 減り、Duo の外側は 84 → 80 で関門 ≥ 80 にぎりぎり【推定】なので測り直す。1 段目の間隔 4 つを全部 8 にすると 84 − 16 = 68 で関門を割るので、その形は採らない。既定は 4 のまま。
- **Duo と細い窓**: 狭い・広いの決め方は列の幅だけ（`CalendarRootScreen.compactWidth` 600）で、利き手は関係しない。Duo の外側（382）と iPad の細い窓（< 600）は狭い 2 段、Duo の内側（約 626〜669【推定】）と 678 の窓は広い行。iPhone の広い行（横と Duo の内側）は短い題名のまま（D2 のリードの決定、`CalendarRootScreen.usesShortTitle`）。Duo の詰めた行はやめたまま（D1c の決定）。

**題名に残る幅（pt）**: 部品の数と間隔の数が今と同じなので、計算上どれも変わらない。

| 機種 | 題名に残る幅 | 出典 |
| --- | --- | --- |
| iPhone 17 縦（402） | 約 104.6【推定】 | 402 − 297.4（`PageHeaderView.swift:37-39` の注） |
| iPhone 17 横（列 750、短い題名） | 168 | `docs/R1_4_1.md` の D1a「広い行の測り」と 2 回目の通しの run の `header room:` |
| iPhone 18 Pro Max 縦（440） | 142 | 同じ |
| iPhone 18 Pro Max 横（列 832） | 220 | 同じ |
| iPad mini 縦（744） | 162 | 同じ |
| iPad Air 11 縦（820） | 208 | 同じ |
| iPad Pro 13 縦（1032） | 367 | 同じ |
| Duo の外側（382） | 84.0 | `docs/R1_4_1.md` の D1c（写真で測った） |
| Duo の内側（約 626〜669、広い行・短い題名） | 約 44〜87【推定】 | 固定部分は mini で測った約 582 |
| iPad の細い窓（< 600） | iPhone の縦と同じ 2 段。Slide Over 320 で約 22.6【推定】 | — |
| iPad の 678 の窓（広い行） | 約 96【推定】 | — |

- **測り直し（関門。N2・N3）**:
  - `HeaderRoomUITests.swift:66-78` の題名の場所の式を案 B に替える: 狭い行 `add.minX − title.minX − compactGap`、広い行 `picker.minX − title.minX − wideGap`（題名が左寄せなので、題名の minX が場所の始まり）。測るのは今と同じく右手だけ。`build.yml` の段（`header room:` の grep）は変えない。
  - N2 の通しの run の `header room:` で、上の測った数（162・208・367・168・220・18 Pro Max の縦 142）と同じ（± 0.5）こと。差の幅は、新しい式が前と違う枠（▶.maxX や 等倍.maxX の代わりに title.minX）を読み、XCUI の枠が画素にそろう（2 倍で 0.5、3 倍で 0.33）ため。D1a の関門（ja の広い日の題「2026年10月15日(木)」≥ 115、mini・Air 11・Pro 13 の縦）と `PageHeaderRoomTests` の ≥ 70 がそのまま通ること。
  - Duo の外側は `r141-duo3` の写真（`outer-portrait-{week,day,month,year}-pencil.png`、3 倍）の 1 段目で、左の余白 12 の後から「＋」の玉の左の端までの幅から間隔 4 を引く。≥ 80（見込み 84.0）。
- **案 A（確認ページの写真の選び。本人が選んだときだけ既定にする）**:
  - 右手: 広い行 [⚙][☁][＋][印?][切り替え][題名][等倍][‹今日›]、狭い 1 段目 [⚙][☁][＋][題名][‹今日›]、2 段目 [切り替え][等倍]。左手は逆（ビルド 29 の右手と同じ並び）。
  - 題名の寄せは右手 `.trailing`、左手 `.leading`（`PageHeaderView.swift:112` を逆にし、`PageHeaderRoomTests.swift:113-114` の字も替える）。`HeaderOrderTests.swift:62-71` の符号が逆になる（右手 −1・左手 +1）。題名の場所の数は案 B と同じ。
  - 案 A の右手の見た目は、ビルド 29 の左手と同じ画素【推定】。写真は `r141-alt` の DEBUG だけの引数 `--screenshot-header-order a` で撮る（§16.8）。
  - 選ばれたら表と寄せを入れ替えてビルド 31 を作り、N2〜N4 の関門のうち見出しの物（`header room:`・切り抜き・`HeaderAndPaperUITests`・Duo）をやり直し、確かめ表の行 1・2・3・7・12 をやり直してもらう（§9.4 の決め方。行 2・3・7・12 の合格の字は書き直して渡す。案 A の iPhone の縦の 1 段目は [⚙][☁][＋][題名][‹今日›] で ⚙ と ‹ が隣り合わず、日付も左の端でなくなるため）。
- **使わない物**: 第 2 版の並べ方 (b)（日付のすぐ右に「‹ 今日 ›」。§3.2 の (b) の表と `gap`、§6.2 の (b) の不等式、`r141-alt` の 8d2dc72 の (b) の写真、`docs/i18n/back/store-1_4_1-b.md`）は記録として残すだけ。
- **理由**: 本人の 2 つの言葉（11/21「年月日は一番左側でいいです」・11/22「＜今日＞と等倍は右端が右利き」）の両方に字どおり合う。1.1.1 で本人が頼んだ「今日の日付を右側に変更」（`docs/R1_1_1.md:19`）と同じ向きで、1.4 の見出し（題名と切り替えが左、ボタンが右）にいちばん近い。利き手でよく押す「‹ 今日 ›」と等倍がその手の端に来る（「人間が使う場合そうなります」）。部品と間隔の数が同じなので、題名の場所・見出しの高さ・紙の領域・関門 3 の数がどれも変わらず、コードの変更は表だけ。案 A は、右利きの全員で ⚙ が左上になり（1.0〜1.4 はずっと右上）、日付が真ん中より右に来て「年月日は一番左側」に反し、閲覧専用の印も M5 の形の鏡になる。

### 16.3 等倍の規則（0e-7・0e-9・0e-10 の読み替え）

#### 16.3.1 狙いの倍率と式

- **日・週: `fit = vw / W`**（W は週 1400 lu、日 1000 lu。`ZoomPolicy.fitZoom`、`TegakiKit/Sources/Layout/ZoomPolicy.swift:52-57`。`Bounds.fit` に `:145` で入る今の値そのもの）。**月・年: 今のまま `Bounds.open`**。
- 新しい純粋な関数 `ZoomReset.target(_ kind:, bounds:)`（新しい `Views/ZoomReset.swift`。Kit の外に置く。§1.4・§2 の「TegakiKit を変えない」と K-6 を守るため。KitChecks 40,826 は同じ）: 週・日 → `bounds.clamped(bounds.fit)`、月・年 → `bounds.open`。`ZoomReset.followsFit(_ kind:)` は週・日で true、月・年で false。
- `vw` はキャンバスの `container.bounds.width`、つまり紙の列の幅。iPhone の横は安全域を引いた幅（874 → 750）、iPad でツールバーを左右に開いたときは −74（`Views/CalendarRootScreen.swift:3315-3317` の `paletteSideWidth`。74 になるのは `.expanded` で左右の端のときだけ）。だから左右の端で開く ↔ しまうと列が 74 変わり、step 4 で fit に合わせ直す（のぞき `.peek` は紙に重ねるので、しまったときと同じ列の幅）。**高さは式に入らない**（終日のレーン数と、上下の端の開く・しまう・のぞきは高さだけの変化で、fit は変わらない）。
- **clamp が要らない理由**: どの機種でも `min ≤ open ≤ fit ≤ max`。`open = min(vw/W, vh/H) ≤ fit`（`ZoomPolicy.swift:140-150`）。横つなぎの上限 `cap = vw/(pages·W) = fit/pages ≤ fit`（`cappedBounds`、`:158-167` は fit を変えない）。`max = max(4·fit, 2·readable) ≥ 4·fit`。念のため `clamped` は通す。
- fit/open は 1.0〜10.3【推定。下の表】で、`maxStoredRatio` 64（`ZoomPolicy.swift:191-193`）の内。だから fit/open の比の知らせも今の道（`sanitizedRatio`）で読める。

| 機種（縦は下のツールバーを開いて終日 1 レーン） | 週 open → fit（fit/open） | 日 open → fit（fit/open） |
| --- | --- | --- |
| iPhone 17 縦 | .2812 → .2871（1.02） | .2233 → .4020（1.80） |
| iPhone 17 横（列 750、横つなぎの上限） | .1786 → .5357（3.00） | .1500 → .7500（5.00） |
| iPhone 17 横（列 750、1 ページの道） | .0932 → .5357（5.75） | .0729 → .7500（10.3） |
| iPhone 18 Pro Max 縦 | open = fit = .3143（1.00） | .2575 → .4400（1.71） |
| iPad mini 縦 | .4573 → .5314（1.16） | .3642 → .7440（2.04） |
| iPad Air 11 縦 | .4818 → .5857（1.22）【推定】 | .3837 → .8200（2.14）【推定】 |
| iPad Pro 13 縦 | .5839 → .7371（1.26） | .4654 → 1.032（2.22） |
| iPad Pro 13 縦・左右のツールバー（列 958） | — | .4963 → .9580（1.93） |

- 出典: zoom の地図の表（実測は iPhone 17 の縦横・Pro Max の縦（17 Pro Max で測った値）・mini と Pro 13 の縦。Air 11 は推定）。fit はどれも幅だけで決まる。
- テストでよく使う大きさの fit: 834×955 の週 0.595714、1210×615 の週 0.864286、874×205 の週 0.624286・日 0.874、1024×1100 と 1024×1180 の週 0.731429・日 1.024、402×536 の日 0.402、440×622 の週 0.314286（= open）。

#### 16.3.2 押したとき（キャンバス）

- 関数の名前を `resetZoomToOpen` から `resetZoom` に替えてよい（1.4.1 の行。step 8 の呼び出し `Ink/InkCanvasView.swift:1014` と一緒に）。
- **守りは全部今のまま**（`:1459-1461`）: キャンバス・container・lastBounds のどれかが無い、最初の倍率の前、`isLive`、`isUsingTool`、`resetScroll`、`isMovingSelection`、横の道で指が帯を押さえている・引いている。`isSettling` では落とさない。はじいた滑り・矢印の滑りは先に止める（`:1465-1473`）。
- **変える所は 3 つ**:
  1. 狙い: `let open = bounds.open`（`:1462`）→ `let target = ZoomReset.target(appliedLayout.kind, bounds: bounds)`。後の `open` は全部 `target`（`:1479-1481`・`:1483`・`:1486`・`:1490-1491`・`:1497`。DEBUG の `:1499` は下）。
  2. 「何もしない」（`:1464` の guard）: |z − target| < 0.0005、かつ「1 ページの道」か「横つなぎで |offset.x − origin(slot)·target| < 0.5」（slot は画面の真ん中のページ `band.slot(atX: midX)`）。このとき:
     - 日・週でまだ `followsFit` でなければ **採る**: `followsFit = true` にして、`scrollViewDidEndZooming(canvas, with: nil, atScale: canvas.zoomScale)` で 1 回だけ知らせる（`finishZoom` の道。比と fit=true が次のターンに出る）。open = fit の機種（18 Pro Max の縦の週）で押したときの道。
     - そうでなければ何もしない（動かず知らせも無い）。月・年は今のとおり何もしない。
     - 横つなぎで倍率は合っているが端がずれているとき（はじいた後の 6 % の吸い付きで止まり切らなかったとき）は、「何もしない」に入らず、下の x の式で端をそろえる。
  3. 最後の `scrollViewDidEndZooming(canvas, with: nil, atScale: target)`（`:1497`）の前に `followsFit = ZoomReset.followsFit(appliedLayout.kind)`。
- **1 ページの道**: zoomScale = fit。紙の幅 W·fit = vw で左右の余白 0、x の範囲は [0, 0]（`clampedOffset`）。y は今の midY の規則（`y = midY·target − shown/2`）。紙が画面より高くないとき（`H·target ≤ vh + 0.5`）に上の端へ戻す規則（`:1488-1491`）は target で残す（fit の日・週はふつう紙が画面より高く、効くのは open = fit の 440×622 の週のような所だけ【推定】）。
- **横つなぎの道**: 今の式（`:1484-1487`）`x = (origin(slot) + W/2)·z − vw/2` は z = fit で `origin(slot)·fit` になり、真ん中のページの左右の端が画面の端に来る（隣は見えない）。turnAnchor を消し shift の確かめを頼む（`:1493-1496`）のは今のまま。
- DEBUG のログは `zoom: reset %.4f→%.4f fit=%d`（`:1499`）。`build.yml` はこの行を grep しない【事実: `grep -n 'zoom: reset' .github/workflows/build.yml` が空】。`ZoomResetUITests` は probe の倍率で読む（`zoomAfterReset`、`ZoomResetUITests.swift:159`）。
- 結果: 日・週では、開いたときの大きさで押すと拡大になる（第 2 版では何も起きなかった）。もう一度押しても最小へは戻さない（行き来はしない）。

#### 16.3.3 幅・高さが変わったとき（`Coordinator.followsFit`）

- 新しい状態 `private var followsFit = false`（Coordinator。`lastZoomResetTrigger` の隣、`Ink/InkCanvasView.swift:455`）。
- **立てる**: 日・週で等倍が効いたとき（16.3.2 の 3）、日・週で「採る」とき（16.3.2 の 2）、step 3 で `parent.initialFit` が true で種類が日・週のとき。
- **下ろす**: つまみの始まり（`scrollViewWillBeginZooming`、`:2199` に 1 行。コードで替える倍率では呼ばれない【推定: UIKit の動き。拠り所は、今の `InkCanvasZoomResetTests` が等倍の後に `zooming == [false]` を見て緑なこと（`:267`。コードで `zoomScale` を替えても `scrollViewWillBeginZooming` の `true` が来ていない）。新しいテスト「回転・左右のツールバーで fit についていく」（step 4 で倍率をコードで替えた後も fit のまま）でも確かめる。「fit でつまむ」はテストの `pinch`（`:149-156`）が自分で WillBegin を呼ぶので、拠り所にならない】）、step 3 で `initialFit` が false のとき（1 ページの道で新しいページが同じキャンバスに来たときも step 3 がもう一度走る。`:1107-1113`）。
- **幅が変わったとき**（step 4、`:1266-1300`。回転・Split View・左右のツールバー・Duo の開閉）:
  - `:1288` を `let newZoom = followsFit ? bounds.clamped(bounds.fit) : (atOpen ? bounds.open : (atMin ? bounds.min : bounds.clamped(targetZoom ?? oldZoom)))` にする。
  - `:1297` を `y: (atOpen || atMin) && !followsFit ? topY * newZoom : centerPaper.y * newZoom - viewport.height / 2` にする（fit では真ん中の規則）。
  - x は今の式のまま。1 ページの道は clamp で 0。横つなぎの道は `bandWidthChanged`（`:3144-3168`）が layoutMid を新しい倍率で真ん中に戻すので、`origin·fit'` で端がそろう。
  - open = fit の機種（18 Pro Max の縦の週）では atOpen と区別がつかないので、**数値で fit かどうかを決めない**（状態で持つ理由）。
  - 0d-44 の行（`:1276-1286`）と容れ物の `offsetBeforeNewFrame` は変えない。
- **高さだけが変わったとき**（`applyBounds`、`:1330-1355`）: `guard !isLive else { return }`（`:1339`）の後に分かれを 1 つ足す: `followsFit` なら、倍率が範囲の替えで動いていたときだけ fit に戻して上の紙の y を保ち、`targetZoom = bounds.fit` にして return。終日帯が縮む 2 度目の落ち着きや、open = fit の機種でレーンが増えたときも fit から動かない。
- **知らせ**（`finishZoom`、`:1518-1529`）: `let fit = followsFit` を取り、`deliverNextTurn` の中で `self.parent.onZoomRatioChange(ratio)` のすぐ後に `self.parent.onZoomFitChange(fit)` を呼ぶ（同じブロック・同じ次のターン。`onZoomingChange(false)` は今のまま最後）。

#### 16.3.4 覚えるものと、次に開くとき

- 覚え方は「**等倍の状態を種類ごとに覚える**」（本人の 12:4x と 13:0x の答え）。
- **鍵** `AppSettings.zoomFitKey(kind) = "zoomFit." + kind.rawValue`（Bool。週・日だけが立つ）。端末ごと（UserDefaults）。iCloud・書き出し・`isExistingUser` に入れない。置き場所は `Persistence/AppSettings.swift:351-354`（`hasPinched`）の後。
  - `static func zoomFit(for kind: PageKind) -> Bool`（月・年はいつも false）。
  - `static func setZoomFit(_ fit: Bool, for kind: PageKind)`: true なら鍵を立て、`zoomRatio.<種類>` を消す。false なら鍵を消す（比には触れない）。
- **書く時**（どれも画面の閉包。写真モードでは書かない。今の `guard !ScreenshotMode.isActive`、`CalendarRootScreen.swift:1270-1273`・`:3005-3008` と同じ形）:
  - 日・週で等倍が効いた後: キャンバスが次のターンに `onZoomRatioChange(fit/open)` → `onZoomFitChange(true)`。結果は「鍵が立ち、比は無い」。
  - 本当のつまみが終わった後: `onZoomRatioChange(r)` → `onZoomFitChange(false)`。比を今どおり保存し、鍵を消す。
  - 月・年の等倍: 今どおり比 1 で比を消す（`onZoomFitChange(false)` は何も変えない）。
  - 最初の配置（step 3 の最後の `scrollViewDidEndZooming`、`:1251`）も同じ道で知らせる。`initialFit` で開いたページは (fit/open, true)、ほかは (r, false) で、どちらも覚えた値を変えない。
- **次に開くとき**: 画面は `currentFit = ZoomReset.followsFit(kind) && ScreenshotMode.zoomFit(ScreenshotMode.current, kind: kind, stored: AppSettings.zoomFit(for: kind))` を計算し、キャンバスの `initialFit` に渡す。
  - キャンバスの step 3 は `initialFit` なら `bounds.clamped(bounds.fit)` を最初の倍率にし、`followsFit` を立てる。
  - x: 1 ページの道は画面の `initialScrollX` を visibleWidth = W で計算するので 0（`TegakiKit/Sources/Layout/PageNavigation.swift:150-163`）。横つなぎでは `ScreenPaths.bandStart`（`Span/ScreenPaths.swift:1179-1184`）が `origin(focus) + 0` を返すので x = origin(focus)·fit。
  - y: `initialScrollY`（今日のページは今の 1 時間前、ほかは 7:00）。
  - open = fit の機種（18 Pro Max の縦の週）では今の「比 ≤ 1.0005」の道（`InkCanvasView.swift:1231-1233`、`applyBandOpening :3127-3133`）を通る。結果は同じ x（origin·fit）で上の端【推定】。
- **最初のフレームの見積もり**（画面の側。fit は幅だけで決まるので見積もりも正確）:
  - `estimatedZoom`（`CalendarRootScreen.swift:630-639`）は fit のとき `ZoomPolicy.fitZoom(kind, viewportWidth:)`。
  - `initialViewport`（`:595-603`）は fit のとき `PaperViewport.initial(kind, viewportWidth:)`（`ZoomPolicy.swift:285-288`。オフセット 0）。
  - `joinedInitialViewport`（`:614-617`）と `joinedCanvas` の `zoom`（`:2967`）に `fit: currentFit`。
  - 「今日」の `paths.today(… ratio:)`（`:1741-1742`）にも `fit: currentFit`。fit/open が 1.001 を超える所では `zoomedIn` が真（今日の列と 1 時間前を見せる）。open = fit の所（18 Pro Max の縦の週）では偽で、今と同じ（近ければ滑らせる。同じページなら動かない）。`ZoomPolicy.ratio` は `sanitizedRatio` で 1 ± 0.001 を 1 にし（`ZoomPolicy.swift:185-187`）、1 は `overviewRatio` 1.0005（`Span/ScreenPaths.swift:124`）以下のため。
- **採らなかった形**:
  - (a) 覚えない: 毎回押すことになり、本人の 12:4x に反する。
  - (b) 比 fit/open を覚える: open は終日のレーン数・回転・ツールバーの辺・1 ページか横つなぎかで変わる。Pro 11 の縦の週で 1 レーンで覚えた比 1.198 は、0 レーンで約 23 pt はみ出し、3 レーンで約 43 pt 足りない【推定。zoom の地図】。
  - (c) 日・週の開く大きさそのものを fit にする: 本人が直したのは等倍の意味だけで、13:0x で「開いたときの大きさは今のまま」を採った。変えると 1.3 の「隣のページが見える」、P-B6 イ、写真・J-4・関門 3・KitChecks の open の行・保存済みの比の意味が全部変わる。
- **変えない**: `hasPinched`（`AppSettings.swift:351-354`）と `pinchHintDue`（§5.6）。fit だけを覚えた端末では、つまみのヒントが一度出うる（害は無い）。

#### 16.3.5 端のケース

| 場合 | 動き |
| --- | --- |
| ツールバーが左右の端 | fit = (列 − 74)/W。等倍のままツールバーを左右へ動かすと、新しい fit に合わせ直す（step 4）。左右の端で開く ↔ しまうも列が 74 変わるので同じく合わせ直す（のぞきは列を変えない）。上・下に動かしても vw は変わらないので何も起きない |
| iPhone の横の上限（P-B6 イ） | 上限は最小と開いたときの大きさだけに効き、fit は変わらない。等倍で 1 週・1 日が横いっぱい（週は上限の 3 倍、日は 5 倍）。見えるのは約 4 時間（週）・2〜3 時間（日）。本人の定義どおりで例外は作らない（13:0x） |
| Pencil で書いている最中 | 落として何も貯めない（今と同じ） |
| はじいて滑っている最中 | 止めてから等倍。fit でのはじきは `SpanPlan.flingTarget` の `fits = page ≤ vw + 1e-9`（`TegakiKit/Sources/Layout/SpanPlan.swift:339`）が真になり、1 ページずつ端がそろう。ゆっくり止めると 6 % の吸い付き。止まり切らなかったときは、もう一度押せばそろう（16.3.2 の 2） |
| ‹ › | `slidePages` は 1 ページ = vw だけ動かすので、端はそろったまま |
| 最大の倍率 | fit ≤ max/4 なので切られない。最大まで拡大してから押せば fit に縮み、いちばん縮めてから押せば fit に拡大する |
| 24 pt の動き出しの関門（`isAtOverview`、`InkCanvasView.swift:3212-3216`） | fit では効かない（すぐ動く）。open = fit の機種では今と同じ |
| 「今日」 | 倍率は変えない（`ScreenPathsSpanTests.swift:1228-1250` のピン留め）。fit/open が 1.001 を超える所では `zoomedIn` が真なので、今日の列と 1 時間前を見せる。open = fit の所（18 Pro Max の縦の週）では偽で、今と同じ（近ければ滑らせる。同じページなら動かない）（16.3.4） |
| 種類を替えた（週 → 月、日 → 週） | その種類の覚えで開く。月・年はいつも `initialFit` が false |
| 1 ページと横つなぎ（設定「ページ」） | 同じ鍵 `zoomFit.<種類>` を共に使う（`zoomRatio.<種類>` と同じ考え） |
| Duo の開閉 | 幅が変わるので、`followsFit` なら合わせ直す。`DuoFoldTests` の比の鍵は、つまみが無いので変わらない |
| 終日のレーン数・上下の端のツールバーの開く・しまう・のぞき（高さだけの変化）、左右の端ののぞき（紙に重なり、列はしまったときと同じ） | fit のまま（16.3.3） |
| 開く大きさ | 変えない（16.3.4 の (c)）。1.3 の「隣のページが見える」、P-B6 イ、J-4 と関門 3 の写真・状態の行、KitChecks はそのまま |

#### 16.3.6 月と年

- 今のまま `Bounds.open`。等倍は覚えた拡大を消し、次も開いたときの大きさで開く（§3.6・§3.9 のまま）。
- 「月と年の横スクロールと、幅に合わせる等倍」を `docs/M7_PLAN.md` §4 に次の版の行として足す（本人の 12:3x、13:0x の答え。§16.9）。

#### 16.3.7 写真モード

- 何も書かない（倍率・比・fit の鍵）。`currentFit` は写真モードでは `Config.zoomFit` だけを読む。
- 新しい引数 **`--screenshot-zoom fit`**: `ScreenshotMode.Config` の末尾に `var zoomFit: Bool = false` を足し（`hand` と同じ形、`Support/ScreenshotMode.swift:269-273`・`:442-446`）、`--screenshot-zoom` の値が `fit` のとき true。数の読み（`:379-384`）は変えない（`parseZoomRatio`（`:501-504`）は `fit` を nil にするので、比は 1 のまま）。
- `static func zoomFit(_ config: Config?, kind: PageKind, stored: Bool) -> Bool`: 写真モードでは `config.zoomFit`、そうでなければ `stored`（`ScreenshotMode.hand(_:stored:)`、`:465` と同じ形）。月・年は呼ぶ側の `ZoomReset.followsFit` で false。
- J-4・関門 3・blank-paper・span-shots-app の今の写真はこの引数を使わない（紙の画素と状態の行が変わらない理由。§16.8）。

### 16.4 凍結のキャンバスの作り直し 2 回目（§5.4 の読み替え）

**変えてよい行は `tools/compat10/DATA_1_1.sha256` の 1 行目（`Sources/TegakiCalendar/Ink/InkCanvasView.swift`）だけ**。2〜20 行目、`tools/l10n/lint-skip.txt` の 20 行、`tools/span/TESTS_1_3.sha256`（29）・`TESTS_1_2_3.sha256`（8）・`FIXTURES_1_3.sha256`（37）は変えない。

**入出力**: 入力 1 つ（`initialFit`）、出力 1 つ（`onZoomFitChange`）、Coordinator の状態 1 つ（`followsFit`）。§5.4 の「新しい出力は無い」は、この 2 回目に限り「入力 1 つ・出力 1 つを許す」と読み替える。**理由**: 本人の 12:4x（ピンチしなくてすむ）に応えるには、fit を覚えて次に開くページへ渡す口が要る。比の知らせ（`onZoomRatioChange`）だけでは、open = fit の機種と終日のレーン数の違いで fit を表せない（16.3.4 の (b)）。

**許す行の全部**（a172cc5 の行番号。合わせて約 30 行の見込み【推定】）:

| # | 場所 | 足す・替える | 中身 |
| --- | --- | --- | --- |
| Z2-1 | 入力。`zoomResetTrigger`（`:249`）の後 | 足す | `var initialFit: Bool = false` と注（日・週で fit（vw/W）で開き、幅が変わっても fit に合わせる。月・年は読まない） |
| Z2-2 | Z2-1 の後 | 足す | `var onZoomFitChange: (Bool) -> Void = { _ in }` と注（`finishZoom` の知らせの中で、`onZoomRatioChange` の後に、今の倍率が fit の状態か） |
| Z2-3 | Coordinator。`lastZoomResetTrigger`（`:455`）の隣 | 足す | `private var followsFit = false` と注 |
| Z2-4 | step 3。`:1221` | 替える（1 行） | `let zoom = parent.initialFit && ZoomReset.followsFit(appliedLayout.kind) ? bounds.clamped(bounds.fit) : ZoomPolicy.zoom(forRatio: parent.initialZoomRatio, bounds: bounds)` |
| Z2-5 | step 3。`:1221` の後 | 足す（1 行） | `followsFit = parent.initialFit && ZoomReset.followsFit(appliedLayout.kind)` |
| Z2-6 | step 4。`:1288` | 替える（1 行） | `newZoom` の頭に `followsFit ? bounds.clamped(bounds.fit) :` |
| Z2-7 | step 4。`:1297` | 替える（1 行） | topY の条件に `&& !followsFit` |
| Z2-8 | `applyBounds`。`:1339` の後 | 足す（分かれ 1 つ、約 6 行） | `followsFit` なら fit を保ち（動いていたときだけ zoom と上の y）、`targetZoom = bounds.fit`、return |
| Z2-9 | `scrollViewWillBeginZooming`（`:2199`） | 足す（1 行） | `followsFit = false` |
| Z2-10 | `finishZoom`（`:1518-1529`） | 足す（2 行） | `let fit = followsFit` と、`onZoomRatioChange` の後の `self.parent.onZoomFitChange(fit)` |
| Z2-11 | `resetZoomToOpen`（`:1458-1501`。1.4.1 の行） | 中身を直す | 16.3.2 の 3 つ（狙い・何もしないと採る・`followsFit` を立てる）と DEBUG のログ。名前を `resetZoom` に替えるなら step 8 の呼び出し（`:1014`）も |
| Z2-12 | 注 | 直す | 入力の注 `:244-249` と関数の注 `:1445-1457`（どちらも 1.4.1 の行） |

- **触らない**: `CanvasCommand`（`:20-`）、保存・merge・同期・墓標・台帳の行、0d-44 の行（`:1276-1286`）と容れ物の `offsetBeforeNewFrame`、step 8 の形（`:1010-1015`。呼ぶ関数の名前だけは替えてよい）、`applyBandOpening`・`bandWidthChanged`・`isAtOverview`、1.4.1 より前の行の注。
- `ZoomReset`（`Views/ZoomReset.swift`）は凍結の外の新しいファイル。凍結のファイルはそれを呼ぶだけ。

**手順**（§5.4 の 1〜6 と同じ形。N1 の Z の 1 つの commit）:

1. 同じ commit で表の 1 行目を書き直す。今の値は `23481b0faaa30f9d7cb48c0c4d25658edc4ee4182fbd731b4f2d9861fcdc2697`（1 回目の作り直し。c067210 で作り直し、bf3da7b で直した。1.4 は `fae62f5a…5b81`）【事実】。新しい値は commit で決まり、記録に書く。
2. 手元で `tools/l10n/lint-skip.txt` から `InkCanvasView.swift` を一時的に外して `python3 -I tools/l10n/lint.py` が OK、元の 20 行に戻す（`git diff` が空）。
3. `docs/R1_4_1.md` の「1.4.1 の直し」に: commit、足した行と替えた行の全部（Z2-1〜Z2-12 の実際の行番号）、新しい入出力 2 つとその理由（本人の 12:4x）、1 ページの道と横の道のどちらが通るか、その行を通る既存のテストの名前。
4. **行の見直しの前に緑**: 互換の相手（compat10 599・span-compat 274/274/278/310・`Real13LedgerTests` 5/5）、保存のバイトの関門 2（§5.7 の 3 つ）、`TESTS_1_3` 29・`TESTS_1_2_3` 8・`FIXTURES_1_3` 37 が 1 字も同じ、ピン留めの `InkCanvasViewTests`（77）・`InkCanvasSpanTests`（56）・`DuoFoldTests`（6）と `InkCanvasWidthCentreTests`（4）がそのまま緑（どれも `followsFit` の既定 false の道を通る）。
   - **§5.4 の手順 4 にあった J-4 は、ここでは行わず N4 で行う（決定）**。行の見直しは J-4 を待たない。理由: J-4 は同じ UTC の日の基準（`ja-baseline.yml`）と、全部を取り込んだ通しの run の写真が要る（1 回目も、J-4 は取り込みの後の通しの run で読んだ。記録の D1b）。また J-4 の写真は写真モードで撮り、`initialFit` も `followsFit` も既定の false なので、Z2 の行の新しい道は通らない。
5. リードが diff を 1 行ずつ見て、記録に「リードの決定」として書く。本人には最後の報告で知らせる。
6. `build.yml:444` の段の名前「Data code frozen (re-based in 1.4.1)」は 2 回目でも当たっているので変えない。この commit は Z のファイルだけ（§5.4 の 6 の C の行は無い）。

- ピン留めのテストが 1 つでも結果を変えたら、テストは直さず Z2 の行を直す（§5.5）。直せなければ止めて契約を直す。

### 16.5 コードの変更（役ごと）

**接点（宣言。N1 で S と U が Z と同時に作るため、先に固める）**: S の枝は Z の物（`Views/ZoomReset.swift` の `followsFit`、`InkCanvasView` の `initialFit`・`onZoomFitChange`）が無いとビルドできない。だから **S と U の速い道は、Z の上に S を `--no-ff` で入れたまとめの枝 `r141-w-b2` で回す**（決定。D1b の `r141-w-b` と同じ形。§16.10 の N1）。接点が下と違えば S の側で直す。Z の凍結の commit は Z の枝の 1 つのまま。

```swift
// Views/ZoomReset.swift（役 Z、新しい。凍結の外。import Layout）
enum ZoomReset {
    /// 週・日は true（等倍 = 1 ページの幅が画面の幅にちょうど）。月・年は false（等倍 = open）。
    static func followsFit(_ kind: PageKind) -> Bool
    /// 等倍の狙い: 週・日は bounds.clamped(bounds.fit)、月・年は bounds.open。
    static func target(_ kind: PageKind, bounds: ZoomPolicy.Bounds) -> CGFloat
}
// Ink/InkCanvasView.swift（役 Z、凍結。§16.4）
var initialFit: Bool = false                     // zoomResetTrigger（:249）の後
var onZoomFitChange: (Bool) -> Void = { _ in }  // その後。finishZoom の次のターンに onZoomRatioChange のすぐ後
// Persistence/AppSettings.swift（役 S）
static func zoomFitKey(_ kind: PageKind) -> String          // "zoomFit." + kind.rawValue
static func zoomFit(for kind: PageKind) -> Bool              // 月・年は false
static func setZoomFit(_ fit: Bool, for kind: PageKind)      // true: 鍵を立て zoomRatio.<種類> を消す。false: 鍵を消す
// Support/ScreenshotMode.swift（役 S）
var zoomFit: Bool = false                                     // Config の末尾。--screenshot-zoom fit
static func zoomFit(_ config: Config?, kind: PageKind, stored: Bool) -> Bool
// Span/ScreenPaths.swift（役 S）。どれも引数の末尾に `fit: Bool = false`（今の呼び方はそのまま通る）
static func bandZoom(layout:area:ratio:fit:)、bandViewport(layout:focusPageId:now:calendar:area:ratio:fit:)、
zoomedIn(layout:viewport:area:ratio:fit:)、func today(_:now:viewport:area:ratio:fit:)
```

| 役（枝） | ファイル | 関数・所 | 中身 |
| --- | --- | --- | --- |
| H（`r141-w-h2`） | `Views/HeaderOrder.swift` | `pieces(arm:hand:readOnly:)` の表 `:47-59`、頭の注 `:3-46`、`.zoomReset` の注 `:12` | 表を案 B に（16.2）。注: 等倍 = 日・週は 1 ページの幅、月・年は open。並びの理由は「利き手の側」（`:43` の「the buttons of the free hand on its side」を直す） |
| H | `Views/PageHeaderView.swift` | 注だけ: 頭の図 `:6-41`（`題名 [日\|週\|月\|年] ＋予定 ☁ ⚙ (1🔍)(‹ 今日 ›)` と 2 段の図、`:15-19` の「free hand's end」と「brings it back to the left」）、`titleAlignment` の注 `:111`、`zoomResetButton` の注 `:253-256`（「at the opening zoom a tap changes nothing」は日・週で違う） | コードは変えない |
| H | `Tests/TegakiCalendarTests/HeaderOrderTests.swift` | §16.6 | |
| Z（`r141-w-z2`） | 新しい `Views/ZoomReset.swift` | `followsFit`・`target` | 純粋。SwiftUI も UIKit も読まない |
| Z | `Ink/InkCanvasView.swift`（凍結の 1 行目） | §16.4 の Z2-1〜Z2-12 | |
| Z | `tools/compat10/DATA_1_1.sha256` | 1 行目 | §16.4 |
| Z | テスト: 新しい `ZoomResetTargetTests`、`InkCanvasZoomResetTests`・`InkCanvasSpanZoomResetTests` | §16.6 | |
| S（`r141-w-s2`） | `Persistence/AppSettings.swift` | `zoomFitKey`・`zoomFit(for:)`・`setZoomFit(_:for:)`（`:351-354` の後）。`Hand` の注 `:357-371` | 注: 丸いボタンの角は「書く手の手のひらの反対の角」（P-4、`docs/M7_PLAN.md:228`・`:714`）。`dockEdge` のコードは同じ |
| S | `Views/CalendarRootScreen.swift` | `currentFit`（`currentRatio` `:588-590` の隣）。`estimatedZoom :630-639`、`initialViewport :595-603`、`joinedInitialViewport :614-617`、`joinedCanvas` の `zoom :2967`、`goToday` の `paths.today :1741-1742`。2 つの `InkCanvasView` の呼び出しで `zoomResetTrigger:`（`:1296`・`:3041`）の後に `initialFit: currentFit` と `onZoomFitChange: { fit in guard !ScreenshotMode.isActive else { return }; AppSettings.setZoomFit(fit, for: kind) }`。注 `:76-78`・`:261-263`・`:1762-1763` | §5.6 のピン留めの字（`ScreenPathsSpanTests.swift:1840-1855` の 15 の配線、`PageHeaderRoomTests.swift:121` の `hand: hand, onZoomReset: { resetZoom() } )` ほか）は 1 字も変えない。新しい引数は呼び出しの最後。`joinedCanvas` の `let zoom`（`:2967`）は名前を変えない（配線 `offset: ScreenshotMode.current?.offset, viewportWidth: viewportWidth, zoom: zoom),` がこの名前を読む） |
| S | `Span/ScreenPaths.swift` | `bandZoom :1250-1252`（fit なら `zoomBounds(...).fit`）、`bandViewport :1257-1268`（中の `bandZoom` と比の判定に通す）、`zoomedIn :1003-1008`（viewport が無いとき `fit ? ZoomPolicy.ratio(forZoom: bounds.fit, bounds: bounds) > overviewRatio : ratio > overviewRatio`。bounds は `bandViewport` と同じ `layout.plan.zoomBounds(overview: InkCanvasView.bandOverview(layout), viewport: area)`。open = fit の所では偽になり、報告が来た後の答えと合う。16.3.4）、`today :962-`（中の 2 つの呼び出しに通す） | 末尾に `fit: Bool = false` |
| S | `Support/ScreenshotMode.swift` | `Config.zoomFit`、`--screenshot-zoom fit` の読み、`zoomFit(_:kind:stored:)` | 16.3.7 |
| S | `Views/SettingsScreen.swift` | 注だけ `:22`・`:188-191` | 「free hand」→ 書く手の手のひらの反対の角 |
| S | `.github/workflows/build.yml` | 速い道の正規表現 `:683` に `ZoomResetTargetTests\|ZoomFitWiringTests`。注 `:657-660`・`:2001-2002` | 1 つのファイルは 1 つの役（§2）。今回は C の仕事を S の枝が持つ（`:2001-2002` の見出しの注も S が直す） |
| S | テスト: `AppSettingsTests`（足す）、新しい `ZoomFitWiringTests`、`SettingsScreenTests.swift:283` の注 | §16.6 | |
| U（`r141-w-s2`。S と同じ枝） | `Tests/TegakiCalendarUITests/` の `HeaderAndPaperUITests`・`HeaderRoomUITests`・`ZoomResetUITests`・`PaletteShotsUITests` | §16.6 | |
| X（`r141-w-x2`） | `docs/i18n/GLOSSARY.md` §5、`tools/l10n/source/app-P.json`（`header.zoomReset.spoken` `:447-449`・`header.today` の comment `:433`）、`tools/l10n/translations/*.json`（8 言語の `header.zoomReset.spoken`）、`Resources/Localizable.xcstrings`（`build.py` が作り直す。`:8585` ほか） | §16.9 | |
| R（`r141-w-x2`） | `docs/i18n/REVIEW.md` の新しい節 15、`docs/i18n/back/` | §16.9 | |
| A・W（N3） | 店の文・審査メモ・SUPPORT・PROPOSALS・文書 | §16.9 | |
| C（N3） | 変異の枝 `r141-q-m1` と `tools/mutations/m1-expected.tsv`、`r141-duo3`、`r141-alt` | §16.7・§16.8 | |

- どの役も、ほかの役のファイルに触れない（§2）。凍結の作り直しの commit は Z のファイルだけ。
- `TegakiKit` は変えない（`ZoomPolicy`・`SpanPlan`・`PageNavigation` も）。

### 16.6 テスト

**書き直す・足す（どれも守られていないファイル）**:

| 役 | ファイル | 中身 |
| --- | --- | --- |
| H | `HeaderOrderTests.swift` | `:20-24` を案 B の値に（`:26-27` の `Arm.allCases`・`HeaderPiece.allCases` はそのまま）。`:39-42` の左手の値を替える（規則の `:31-38` はそのまま）。`:62-71` はそのまま。`:73-92` を `testTodayAndZoomResetSitAtTheWritingHandsEnd` に書き直す: 利き手の端から [today, zoomReset]、反対の端が .title、2 段目は利き手の端が .zoomReset。注 `:5-11`（MH1 の名前も） |
| U | `HeaderAndPaperUITests.swift` | 縦の不等式（`checkPortrait` の `:113-132`）を書き直す。右手: `title.minX ≤ window.minX + 13`、`title.maxX ≤ add.minX`、`settings.maxX ≤ previous.minX`、`next.maxX ≥ window.maxX − 13`、`picker.maxX ≤ zoom.minX`、`zoom.maxX ≥ window.maxX − 13`、等倍の高さ ≤ 切り替え ＋ 0.5、◀ 今日 ▶ の順。左手はその鏡。横の並び（`checkLandscape` の `:160-172`）を「題名 ≤ 切り替え ≤ ＋ ≤ ⚙ ≤ 等倍 ≤ ◀」とその鏡に（横は安全域があるので端の不等式は使わない）。テストの名前（`:25-48`）と注 `:9-13`・`:116` |
| U | `HeaderRoomUITests.swift:66-78` | 題名の場所の式（16.2） |
| Z | 新しい `ZoomResetTargetTests.swift`（速い道） | 種類ごとの狙い（週・日 = fit、月・年 = open）、`followsFit`、clamp（範囲の外の fit を持つ Bounds で） |
| Z | `InkCanvasZoomResetTests.swift`（1.4.1 の物） | 週の 2 本を書き直す: `testTheBandsSecondSettleEndsAtAFreshPagesOpeningZoom`（`:457-475`）は 1024×1100 で 2.0 から押す → fit 0.731429、帯が 1180 に伸びても fit のまま、知らせは 1 回で fit=true。`testAPageNoTallerThanTheScreenGoesBackToWhereItOpens`（`:482-517`）の週の半分は、上に戻るのを 440×622 の週（open = fit）で、1024×1180 の週は midY で確かめる（月の半分はそのまま）。月の 9 本はそのまま。足す: 開いたままの週・日で押す → fit（x 0、余白 0、`contentSize.width == vw`）／fit で押す → 動かず知らせも無い／440×622 の週で押す → 状態だけを採り、知らせは 1 回／左右のツールバー（1032 → 958 → 1032。左右の端でしまう 958 → 1032 も）と回転（402×536 ↔ 874×205）で fit についていく（倍率・x・`contentSize.width` を見る。回転の 1 本は y も真ん中の規則（Z2-7）で見る。y を見るテストは MZ3 でも落ちうるので、C が §16.7 の表に書く）／レーンが増減しても fit のまま／fit でつまむ → fit=false が知らされ、その後の回転は 1.4 の「絶対の倍率を保つ」／`initialFit` で開くと fit・x 0・y は `initialScrollY`／月は `initialFit` を読まない |
| Z | `InkCanvasSpanZoomResetTests.swift`（`:193`・`:224`・`:248`・`:273`・`:302` の 5 本） | 期待の倍率を 834×955 の週で 0.595714、1210×615 の週で 0.864286 に。「0:00 が上」を midY に。比 1 の知らせを、ratio と fit=true の 2 つの知らせに。`:273` は `testTheCappedIPhoneLandscapeGoesToOneWeekAndOneDayAcross`（1400·z = 874、1000·z = 874）に。足す: fit で境目がずれた帯 → x をそろえる／幅が変わっても origin·fit のまま |
| S | `AppSettingsTests.swift` | `testZoomFitReplacesTheRatio`（true で比が消えて鍵が立つ、false で鍵だけ消える、月・年は false）。`testToolbarKeys` の鍵の一覧（`:160-163`）に `zoomFitKey(.week)`・`zoomFitKey(.day)` |
| S | 新しい `ZoomFitWiringTests.swift`（速い道） | `ScreenPaths.bandZoom`・`bandViewport`・`zoomedIn` の `fit:`（offsetX = origin·fit）。`ScreenshotMode` の `--screenshot-zoom fit`（`zoomFit` が true、`zoomRatio` は 1、数の読みは同じ）と `zoomFit(_:kind:stored:)`。`CalendarRootScreen` の 2 つの呼び出しの字（`initialFit: currentFit` と `AppSettings.setZoomFit(fit, for: kind)` がちょうど 2 つ。注を除いたコード `WeekMemoSpanTests.codeOnly` で数える。S が注 `:76-78` も書き直すため） |
| U | `ZoomResetUITests.swift` | `:37-43` の週の半分: 戻した後の列の幅を area.width × 190.857/1400 ± 0.5 に（open の列との差は約 1.1 pt なので 0.5 では戻らない）。年の半分はそのまま。確かめは年と共用の `pinchAndReset`（`:100-132`。今は zoom を `open`、列を `before` と比べる）の中にあるので、種類ごとの狙い（週は fit と fit の列、年は open と `before`）を渡す形にする。クラスの注 `:4-22` を直し、使わなくなる `threeWeeks`（`:31`）を消す。`:45-65`: `zoomed / 2` の代わりに `area.width / 1400`。`:67-94` を `testTheJoinedWeekInLandscapeGoesToOneWeekAcross` に（1400·z = area.width ± 0.5、列 = area.width × 190.857/1400）。足す: 開いたままの日 → 1000·z = area.width ± 0.5／`--screenshot-zoom fit` の週では押しても何も起きない |
| U | `PaletteShotsUITests.swift` | 確認ページの写真を 4 枚足す: `ipad13-portrait-week-fit`・`ipad13-portrait-day-fit`・`iphone-portrait-day-fit`・`iphone-landscape-week-fit`（`--screenshot-span on`）。どれも `--screenshot-zoom fit`。J-4 の外 |

**変えない**:
- `PageHeaderRoomTests`・`HeaderTitleTests`・`HeaderGlyphTests`・`DuoLayoutUITests`・`PaletteMoveUITests`・`SettingsScreenTests`（`:283` の注のほか）・`HandSettingTests`・`ScreenshotModeHandPaletteTests`。
- `InkCanvasViewTests`（回転）・`InkCanvasSpanTests`・`DuoFoldTests`・`InkCanvasWidthCentreTests`（どれも `followsFit` の既定 false の道）。
- `ScreenPathsSpanTests`・`ScreenshotModeSpanTests`（新しい引数は既定値つき）、`TESTS_1_3`（29）・`TESTS_1_2_3`（8）の全部、KitChecks 40,826。

**数の見込み**: 単体テストは 861 本（run 44946307129）から、`ZoomResetTargetTests`・`ZoomFitWiringTests` と Z・S の足すテストの分だけ増える。UI テストは 67 本から `ZoomResetUITests` の足す 2 本の分だけ増える【推定】。名前を替えたテストは数が同じ。消えるテストは無い。数は N2 の run で書く。

### 16.7 変異（`r141-q-m1` を作り直す。取り込まない）

- 枝 `r141-q-m1` を N2 の後の `r141` の上に作り直し、`tools/mutations/m1-expected.tsv`（その枝だけ）を書き直す。落ちるはずのテストの名前は、Z・S・H が N1 でテストを書いた後、run の前に C が表に書く。
- **関門**: 1 回の run で、落ちたテストが表とちょうど同じ（足りない物も余分な物も 0）。

| 変異 | 中身 | 落ちるはずのテスト |
| --- | --- | --- |
| MZ1 | `resetZoom` の `!isUsingTool` を外す | `InkCanvasZoomResetTests.testUnderThePenThePressIsDroppedNotKept`（中身はそのまま。行の番号だけ直す） |
| MZ2 | 最後の `scrollViewDidEndZooming` を飛ばす | 今の表の `InkCanvasZoomResetTests` の 6 本（名前を替えた物は新しい名前で）と `InkCanvasSpanZoomResetTests` の 5 本に、新しい fit の知らせのテスト（知らせが 1 回で fit=true）を足す |
| MZ3 | 0d-44 の 2 行を戻す | `InkCanvasWidthCentreTests` の 3 本と、y を見る新しい fit のテスト（16.6 の回転の 1 本ほか。step 4 の fit は `centerPaper.y` を通る（Z2-7）ので、MZ3 が変える値を読む）。C が N1 のテストを読み、MZ3 で落ちる物を run の前に全部表に書く |
| **MZ4**（新しい） | `ZoomReset.target` が週・日でも open を返す | `ZoomResetTargetTests`、fit のキャンバスのテスト（開いたままで押す → fit ほか）、`InkCanvasSpanZoomResetTests` の帯の 5 本 |
| **MZ5**（新しい） | step 4 が `followsFit` を見ない（Z2-6・Z2-7 を戻す） | 幅が変わっても fit のままかを見るテスト（左右のツールバー・回転・帯の幅の変化） |
| **MZ6**（新しい） | つまみが `followsFit` を下ろさない（Z2-9 を外す） | 「fit でつまむ → fit=false が知らされ、その後の回転は絶対の倍率を保つ」 |
| MH1 | 左手の並びを逆にしない（`HeaderOrder.swift:62`） | `HeaderOrderTests` の `testLeftHandIsTheRightHandReversed`・`testBadgeSitsBetweenTheSwitchAndAdd`・`testTodayAndZoomResetSitAtTheWritingHandsEnd`（新しい名前） |
| MT1・MT2・MS1・MS2 | 中身はそのまま | 今の表のまま（行の番号だけ直す） |
| **MS3**（新しい） | `setZoomFit(true)` が比を消さない | `AppSettingsTests.testZoomFitReplacesTheRatio` |

- MZ1・MZ2・MZ3・MZ5・MZ6 は凍結のファイルに入るので、その枝の `DATA_1_1.sha256` の 1 行目もその枝で書き直す（1 回目と同じ扱い）。MZ4 は凍結の外（`ZoomReset.swift`）。

### 16.8 CI・J-4・関門 3・写真

**CI**: `build.yml` の速い道の正規表現（`:683`）に `ZoomResetTargetTests|ZoomFitWiringTests`、注 `:657-660`・`:2001-2002`（「free hand's end」）を直す（§16.5 の S の行）。ほかの段は変えない（ui-tests はクラスで選び、`:2030` の grep に `zoom-reset UI:` と `header room:` がもうある）。`duo.yml`・`ja-baseline.yml`・`testflight.yml` は変えない。

**基準**（前もっての宣言は `docs/R1_4_1.md` の「1.4.1 の直し」の N0。N1 の最初の run より前に書く）:
- コードの基準: 2 回目の通しの run **44946307129**（2169117）。単体 861（飛ばし 2・失敗 0）、UI 67（飛ばし 17・失敗 0）、KitChecks 40,826、compat10 599・span-compat 274/274/278/310・`Real13LedgerTests` 5/5、関門 3 の状態の行 71 本、palette-shots の attempt 3（14 枚・`ok=yes` 14 行）。
- J-4 の基準: 2fb8fb1 のまま（`tools/l10n/ja-baseline-ref-1.4.1.txt`。§7.1）。

**J-4**: 宣言 7 の除く行（見出しの帯・iPad のつまみの帯・`sheet-info`・設定の 2 枚）と、D1b で (4) に足した `ipad13-portrait-sheet-sync.png` の y 716–949 を、**そのまま使う**。見出しの高さは同じなので帯の行も同じ。写真モードは何も覚えず `zoomFit` も false なので、見出しの下の画素は変わらない見込み。同じ UTC の日に `shift_pair --max-strong 0` で、宣言の行の外の強い差 0（N4）。

**関門 3**: span-shots-app の状態の行 71 本（`;trace=` から後を除く）と `toolbar: paperArea=` の値の組が、run 44946307129 と同じ見込み。理由: 見出しの高さと題名の字は変わらず、開く大きさも同じで、写真モードは fit を使わない（`--screenshot-zoom fit` は §16.6 の新しい 4 枚だけ）。違えば止める。等倍の写真 4 枚の起動で増える `paperArea=` の値があれば、その写真の物と名前を挙げて書く（D1b の扱いと同じ）。

**ほかのログの関門**: `header room:` の数が 16.2 の測った数と同じ（± 0.5）で、D1a の ≥ 115。`zoom-reset UI:` の行が fit の値（16.6）。`PaletteMoveUITests` が緑。palette-shots の `ok=yes` は今の 14 行が同じで、新しい 4 枚の行も ok=yes（`shoot(…, edge: nil)` で撮るなら、辺を待たずにいつも ok=yes を書く。`PaletteShotsUITests.swift:68-92`。計 18 行の見込み）。

**写真**:
- **見出しの切り抜き（§7.3）**: 8 機種（iPhone 17 縦・横、18 Pro Max、iPad mini、Pro 11（J-4 の `ipad11`、834）、Air 11（blank-paper の `ipad11`、820）、Pro 13、Duo の外側）と、閲覧専用・拡大の 4 枚を撮り直し、役ごとに ○ × を記録に書く。前は 1.4 の写真（run 44853713800）、後は N2 の run（Duo は `r141-duo3`）。**ビルド 29 の写真は前にも後にも使わない**。
- **palette-shots**: `*-hand-left` の 3 枚の中身が案 B の鏡になる（「‹ 今日 ›」と等倍が左の端、日付が右の端）。`ok=` の 14 行は同じ。等倍の写真 4 枚（16.6）が加わる（辺の確かめは要らないので、行の形は U が決めて記録に書く。`shoot(…, edge: nil)` なら 4 行とも ok=yes で、計 18 行）。
- **Duo**: duo.yml を `r141-duo3` で回す（N3。頭が `[skip ci]` なら `gh workflow run duo.yml --ref r141-duo3 -f job=shots`）。`DuoLayoutUITests` が緑、`shot_checks` で外側 `header=2`、写真で測った外側の題名の場所 ≥ 80（16.2 の測り方。見込み 84.0）。
- **`r141-alt`**（合否に数えない run）: 新しい `r141` の上に作り直し、DEBUG だけの引数 `--screenshot-header-order a` で案 A を、iPad 13 インチと iPhone 6.9 インチの縦の週・日（4 枚）。**字の等倍のボタンの写真は既定で撮らない**: 本人が 13:0x に印を採った（§16.1 の 4）ので、確認ページの選びにしない。リードが要ると決めたときだけ、同じ run に足す（字は記録だけ）。
- **`ink_ref_xcui.tsv`**: 題名の位置が動くので、見出しの帯の警告がまた出る。記録だけで合否に数えない（D2 のリードの決定のとおり、`tools` は確かめた commit の後に変えない。次の版で見出しの帯のタイルを除く形に）。
- **店の写真**: 撮り直さない（§7.6 のまま。本人の 13:0x の答えにも入っていない）。

### 16.9 文・訳・元を見ない逆翻訳

**順**: GLOSSARY を最初に（X）→ アプリの 9 件（X）→ 元を見ない逆翻訳（R）→ 2 人の判定 → `docs/i18n/REVIEW.md` の新しい節 15 の × を 0 に。**アプリの文は `tools/` の下なので、N2 の確かめた run の前に済ませる**。店・Web の文は docs だけなので、確かめた run と並べてよい（N3）。

**アプリの文**:

| キー | 何をする | 訳 |
| --- | --- | --- |
| `header.zoomReset.spoken`（`tools/l10n/source/app-P.json:447-449`） | ja「等倍に戻す」は替えない。comment を「等倍 = 日と週は 1 日・1 週のページの幅が画面の幅にちょうど合う大きさ、月と年はページを初めて開いたときの大きさ」に | 8 言語を「元の大きさ」から「ズームを戻す」の意味に訳し直す（例: de Zoom zurücksetzen、zh-Hans 重置缩放）。en の Reset Zoom はそのまま（判定だけ）。ja の字が同じで jaSha1 が変わらないので、lint も `build.py` も古い訳を知らせない。X が手で直し、R が元を見ずに訳し戻し、2 人が判定（9 件） |
| `header.today`（`app-P.json:433`、`Localizable.xcstrings:8585`） | comment の「空いている手の側の端」を「利き手の側の端」に | 訳し直さない（jaSha1 が同じ）。`was`・`where` は替えない（§8.1） |

- その後 `build.py` で `Localizable.xcstrings` を作り直す（同じ commit）。確かめは §8.2 のまま（`lint.py`・`build.py --check`・`baseline.py --check`・CI の Localized bundle check）。
- **GLOSSARY §5**（`docs/i18n/GLOSSARY.md:220-221`・`:239-244`）: 等倍の定義を「日・週は 1 ページの幅が画面の幅にちょうど合う大きさ、月・年は開いたときの大きさ」に。名詞の等倍の行の 9 言語の語（今は「もとの大きさ」の語）を X が決め直す。「等倍に戻す」の行は「ズームを戻す」の形。**en に Fit を使わない決まりは残し**、理由を「月と年は幅に合わせないため（幅に合わせるのは日・週だけ）」に書き直す。「実際の大きさ」の語を使わない決まりはそのまま。
- 字の等倍のボタン（`header.zoomReset`）は作らない（本人が印を採った。§16.1 の 4）。

**店・Web の文**（A・W・X・R、N3）:
- **新機能の文**（16 ロケール。ja・source-ja と 11 の訳。en-GB・en-AU・en-CA・fr-CA は写し）の行 1・行 2:
  > ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。
  > ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。
  - 行 3・行 4・訳の断りの行は §8.3 のまま。字数（L-9 の数え方）は ja 207・source-ja 252【推定。文の地図】。
  - 15 ロケール（11 の訳）で行 1 と行 2 を訳し直し、元を見ない逆翻訳と判定（22 行）。案 A の行 1（「…「‹ 今日 ›」を右の端に移し、日付をその左に並べました。」）は、本人が案 A を選んだときだけ作る。
- **審査メモ**（`docs/store/review-note.txt`。今 3,924 バイト【事実: `wc -c`】）: 「What is new in 1.4.1」の 1・2 と、日本語の要約の 1・2 つ目の文を替える。ほかの段は 1 バイトも替えない。
  - 1: `1. The date is now at the left end of the header, and ‹ Today › and the 1× button (a magnifying glass with "1") are at the right end (on narrow screens, 1× ends the second row). Settings > Dominant Hand > Left Hand reverses this order.`
  - 2: `2. 1× resets the zoom: on day and week pages, one day or one week fits the screen width exactly; month and year pages go back to the size they open at. The next page of that type opens at the same size.`
  - 日本語の要約: 「左上に日付、右上に「‹ 今日 ›」と等倍のボタン（設定 › 利き手 › 左手 で逆）。」と「等倍は、日と週では 1 日・1 週の幅を画面の幅ちょうどに、月と年では開いたときの大きさにします。」
  - 見込み 3,992 バイト【推定。文の地図】。**4,000 以下が関門**（超えたら英語の「The next page…」の文を外す。日本語の要約には足さない）。英語の 1・2 は元を見ない逆翻訳をやり直す。
- **SUPPORT**（日英。公開の日に Web へ。§8.5 の読み替え）:
  - `docs/SUPPORT.md:153`（拡大・縮小の FAQ の 2 段落目）: 1 文目「右上の「‹ 今日 ›」のとなりにある、虫めがねに「1」の印のボタン（等倍）を押すと、すぐ等倍に戻ります（1.4.1 から）。日と週のページでは 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年のページではそのページを初めて開いたときの大きさになります。」。2 文目の「2 段目…の左」→「右」。3 文目の左手「右上（…2 段目の右）」→「左上（…2 段目の左）」。4〜5 文目「等倍に戻すと、次に開く同じ種類のページも、アプリを開き直したときも、等倍で開きます。」（指でつまむとその大きさを覚えることを一言足すかは W が決める）。
  - `:157`（左手の FAQ の 2 文目）: 「…左右逆になり、「‹ 今日 ›」と等倍のボタンが左の端に、日付が右の端に移ります。」
  - `docs/SUPPORT.en.md:158`・`:162`: 同じ所（文の地図の en の案。`next to “‹ Today ›” at the top right`、`at the right of the second row`、左手は `at the top left (on a narrow screen, at the left of the second row)`、`and the date to the right end`）。新しい英文は元を見ない逆翻訳と判定。
  - `:147`（丸いボタン）は替えない（角を動かさない）。
- **PROPOSALS_1_4_1**（`docs/store/PROPOSALS_1_4_1.md`）: §1〜§3 を作り直す。選びは「並び」（案 A・案 B）と「等倍の見た目」（印に決まった）。§3.1.1 の言い方は印の 1 組。字のボタンの 〈W〉 の上限（案 B で 19 字）は記録だけ。
- **ほかの文書**: DESIGN（`:101` の図・`:212-219`）、README（`:60`・`:82`）、M7_PLAN（`:11`・`:35`・`:510`・`:522` と、§4 に「月と年の横スクロールと幅の等倍」を次の版の行として）、`docs/store/README.md`・`locales.json`（行 1 の (a)・(b) → 案 A・案 B）、PLAN_MEMO_PAPER・PLAN_PEN_COLORS の 9 行目（注を足すだけ）。
- `docs/i18n/REVIEW.md` に新しい節 15。14 は記録として残す。使わなくなる物（行 1 (a)・(b) の訳と逆翻訳、`docs/i18n/back/store-1_4_1-b.md`、`back/*.json` の `header.zoomReset.spoken` の前の訳）は消さない。
- **リポジトリの外の道具**: `build_page141.py` の guard（元のファイルの字を確かめる。新しい字に）、`asc141/enter141.py` の `--line1 a|b`（案 A・案 B に読み替え。行 1 (b) を `HeaderOrder.swift` の並びと照らす所も）と `--button icon|word`（icon に決まった）。

### 16.10 段取り N0〜N6

| 段 | 担当（枝） | 中身 | 関門 |
| --- | --- | --- | --- |
| N0（11/22） | リード | 契約第 3 版（§0・§10・§16）と、記録の「1.4.1 の直し」の前もっての宣言（基準 run 44946307129、単体 861・UI 67、J-4 は宣言 7 の行のまま、関門 3 は同じ見込み、凍結の作り直し 2 回目の計画） | リードが読む |
| N1（11/22〜23。同時に 4 つ、`r141` から worktree） | H（`r141-w-h2`）・Z（`r141-w-z2`）・S と U（`r141-w-s2`）・X と R（`r141-w-x2`） | H: §16.2・§16.6 の見出し／Z: `ZoomReset`・凍結の diff・キャンバスのテスト・`DATA_1_1` の 1 行目／S と U（§16.5 の接点を先に固め、Z と同時に作る）: 画面・設定・`ScreenPaths`・写真モード・`build.yml`・UI テスト・palette の写真／X と R: GLOSSARY・アプリの 9 件・comment・逆翻訳と判定 | H・Z・X と R は、それぞれの速い道（`r141-q-*`）が緑。**S と U は、まとめの枝 `r141-w-b2`（Z の上に S を `--no-ff`。D1b の `r141-w-b` と同じ形）の速い道が緑**（S は Z の `ZoomReset.swift` と `InkCanvasView` の新しい引数が無いとビルドできないため。§16.5）。Z は、凍結の diff をリードが 1 行ずつ見る（§16.4 の 4・5） |
| N2（11/23） | リード | Z → S → H → X の順に `r141` へ取り込み（Z → S は `r141-w-b2` と同じ木）、通しの run #3 を回す | 単体・UI が失敗 0（数を記録）。`TESTS_1_3`・`TESTS_1_2_3`・`FIXTURES_1_3`・`DATA_1_1` の 2〜20 行目が同じ。compat と保存のバイトが緑。関門 3 が同じ。`header room:` の場所が同じ（± 0.5）で D1a の ≥ 115。`zoom-reset UI:` が fit。`PaletteMoveUITests` が緑。palette の `ok=yes`。Localized の確かめが緑 |
| N3（N2 と並べて） | C・A・W・X・R | 変異（新しい `r141-q-m1`）、Duo（`r141-duo3`）、`r141-alt`（案 A。合否に数えない）。店の 15 ロケール・審査メモ・SUPPORT・PROPOSALS・文書と、その逆翻訳 | 変異で落ちたテストが表とちょうど同じ。Duo が `header=2` で ≥ 80。審査メモが 4,000 バイト以下。判定の × は直してから受ける |
| N4（11/24） | リード | 同じ UTC の日に J-4（`ja-baseline.yml`）。見出しの切り抜きの ○ ×。testflight.yml でビルド 30（確かめた commit からの `git diff -- Sources TegakiKit Tests tools .github project.yml` が空）。アーカイブの確かめ（`iphoneos27.2`・`17.0`・`1, 2`）、Connect で VALID | 強い差が宣言の行の外で 0、切り抜きが全部 ○ |
| N5（11/24〜25） | リード | 新しい確認ページ（新しい Artifact。H6UmrMEkCvejMUp817VNJH は使わない）。中身: 2 つの直し、見出しの前と後（1.4 → 30）、日・週の等倍の前と後、左手、案 A の写真、16 ロケールの文、SUPPORT、審査メモ、確かめ表。3 人の目の見直しの後に渡す | 本人の「この内容で入れてよい」と、並びの選びの答え（無ければ案 B） |
| N6 | 本人 → リード | §9.4 の行 7 から後（提出・公開・まとめ） | 本人の 3 つの言葉 |

- run #3 で直しが要れば run #4 にする（ビルドの番号もずれうる。確かめ表の行 1 は渡すときの番号）。docs だけの commit は、確かめた run の後に入れてよい。
- CI の 1 回は 75〜95 分。変異・Duo・`r141-alt` は run #3 の後に順に回す（同時の上限 5）。
- 案 A が選ばれたら、表と寄せを入れ替えて N2〜N5 の見出しの関門をやり直し、ビルド 31 で確かめ表の行 1・2・3・7・12 を頼む（16.2）。

**危険と減らし方**（§11 に足す）:

| 危険 | 減らし方 |
| --- | --- |
| 凍結のキャンバスを 1.4.1 の中で 2 回変える | 互換の相手と保存のバイトを行の見直しの前に確かめる。変異 MZ4〜MZ6 で確かめる。ピン留めのテストは `followsFit` の既定 false で変わらない。リードが 1 行ずつ見る。確かめ表は全部の行をやり直してもらう |
| 日・週で押した時の見た目の変化が小さい機種がある（iPhone 17 の縦の週は 2 %、18 Pro Max の縦の週は 0）。等倍を一度押すとその種類は等倍で開くので、確かめ表の後の行で押しても変わらないことがある | 確かめ表の行 4 は iPad Air 11 で、いちばん小さくしてから押す（はっきり大きくなる）。合格の字は「紙の外の色も、隣のページも見えない」。行 8 は行 4 で押していない iPad、行 9 は先に拡大してから。準備でツールバーを下に戻してもらう。§0.6 で伝えた |
| 18 Pro Max の縦の週は open = fit で、押しても動かない | 状態だけを採り（16.3.2 の 2）、その後の回転で fit に合わせる。テストで固める（440×622 の週） |
| iPhone の縦で ⚙ と ‹ が隣り合う | 確かめ表の行 3 で見る（⚙ と ‹ を交互に 5 回ずつ）。× なら ⚙ と ‹ の間だけを 8 にし（HStack の spacing は 4 のまま）、Duo の外側の 80 を測り直す（16.2） |
| 見出しの帯の中は J-4 では捕まらない | 切り抜きを役ごとに見る（§16.8）。`ink_ref_xcui` の警告は記録だけ |
| 8 言語の読み上げの古い訳は lint で捕まらない（jaSha1 が同じ） | X・R・2 人の判定を確かめた run の前に済ませる |
| fit で覚えた端末で、あとから 1 ページの道と横つなぎを切り替える | 同じ鍵を共に使い、どちらの道も step 3 で fit を開く（16.3.5）。テストは `initialFit` の 1 ページと横つなぎの両方で |

### 16.11 本人への問いと既定

答えが無ければリードはこの既定で進む。**問い 2〜8 は本人の 13:0x の「全て規定通りで進めてください。」で既定に決まった**（§16.1 の 4）。確認ページで選べるのは問い 1 だけ。

| # | 問い | 既定 | 答え |
| --- | --- | --- | --- |
| 1 | 見出しの並び: 案 B（日付が左の端、「‹ 今日 ›」と等倍が右の端、⚙ は等倍の左）か、案 A（⚙ が左の端、日付は等倍のすぐ左） | **案 B** | 13:0x で既定を採った。新しい確認ページの写真で案 A を選べる。答えは記録の「本人の言葉と選び」に |
| 2 | 端の並び: 「‹ 今日 ›」がいちばん端で等倍がその内側か、その逆か | 「‹ 今日 ›」が端 | 既定（13:0x） |
| 3 | 日・週を最初から等倍（幅にちょうど）で開くか | いいえ（開き方は今のまま。1 回押せば、その種類は次から等倍） | 既定（13:0x） |
| 4 | 日・週で等倍を押した後、次に開く日・週も等倍で開く（覚える）か | はい（指でつまむと、その大きさを覚える） | 既定（13:0x） |
| 5 | しまったツールバーの丸いボタンの角も、利き手の側（右手なら右下）にするか | いいえ（右手は左下のまま。書く手の手のひらを避ける。10/31 に本人が選んだ形） | 既定（13:0x） |
| 6 | iPhone の横で日・週の等倍にすると、1 日・1 週が横いっぱいで、見えるのは週で 4 時間ほど、日で 2〜3 時間（チャットでは両方「約 4 時間」と伝えた。§0.6 で違いを伝える） | そのまま（本人の定義どおり） | 既定（13:0x） |
| 7 | 月と年の横スクロールと幅の等倍 | 次の版（1.4.1 の月と年の等倍は開いたときの大きさ） | 既定（13:0x） |
| 8 | 等倍のボタンの見た目（印か字か） | 虫めがねに「1」の印 | 既定（13:0x）。字の訳・幅の確かめ・写真は作らない |

- 丸いボタンの角（問い 5）を変えると、何も保存していない人（左下）と利き手を一度切り替えた人（右下）とで分かれ、移し替えの処理・脚注の 9 言語・`SettingsScreenTests.swift:270`・`:299-300`・`HandSettingTests.swift:75`・SUPPORT `:147` が替わる。既定で変えないので、直すのは注の理由（`AppSettings.swift:357-371`、`SettingsScreen.swift:22`・`:188-191`、`SettingsScreenTests.swift:283`）だけ。

### 16.12 読み替える前の節

第 2 版の字は残し、次のとおり読み替える（§0・§10・§14 と頭の書きは第 3 版で書き直した）。

| 節 | 第 2 版の字 | 読み替え |
| --- | --- | --- |
| §1.2 | 「‹ 今日 ›」と等倍を左の端に、年月日をそのすぐ後に／等倍は「ページを開いたときの大きさ」 | 本人の 11/22 の直し（§16.1）。右手は右の端、日・週の等倍は fit |
| §1.3 の行 2・4・5 | 「左の端」の見出し、凍結の 1 行目の作り直し（1 回）、行 4 の「覚えた倍率を忘れる」 | 行 2 は案 B（§16.2）。行 4・5 に 2 回目の作り直し（§16.4）を足す。行 4 の「忘れる」は、日・週では fit の状態を覚える（§16.3.4。月・年は忘れるのまま） |
| §1.3 の行 10 | 「本人の選びの 2 組」 | 1 組（並びの案 A の 4 枚。§16.8） |
| §2 の表・§2.1 | `HeaderOrder` の右手の表、`InkCanvasView` の注「open へ戻す」、`build.yml` は C | §16.2・§16.4・§16.5。新しいファイル `Views/ZoomReset.swift`（Z）。`Span/ScreenPaths.swift` は S。`build.yml` は N1 では S の枝 |
| 0e-2（と §3.1・§8.1 の字のボタン） | 等倍のボタンの見た目は記号が既定で、「等倍」の字は本人の選び (B) | 字の選びは閉じた（本人の 13:0x で印。§16.11 の問い 8）。字のボタン・訳・幅の確かめは作らない |
| §3.2・0e-3 | 広い行・狭い行の表、並べ方 (b) の表と `gap` | §16.2 の表。(b) は使わない |
| §3.4・0e-5 | 右手は「Z か枠のすぐ後」に `.leading` で、理由は「本人の言葉の受け取り方 (a)」 | 題名は行の最初で `.leading`（コードは同じ）。理由は本人の 11/21・11/22 の言葉 |
| §3.5・0e-6 | 題名の場所を ▶ と ＋（広い行は等倍と切り替え）の間で測る | 16.2 の式。数と関門（≥ 115）は同じ |
| §3.6・0e-7 | 等倍 = 比 1 = open。週・日は「拡大を戻すだけ」、open で押すと何も起きない、「幅に合わせる fit でもない」 | 週・日は fit（§16.3）。月・年は §3.6 のまま |
| §3.7・0e-8 | 足す行だけ、キャンバスの出力は増やさない | 2 回目の作り直しで入力 1・出力 1・状態 1（§16.4） |
| §3.8・0e-9 | 狙いは open、何もしないは \|z − open\| < 0.0005、上へ戻す規則は open で | §16.3.2（狙いは `ZoomReset.target`、「採る」、横つなぎの端のそろえ） |
| §3.9・0e-10 | 比 1 の知らせで覚えた拡大を消す、次の同じ種類も等倍 | 日・週は fit の状態を覚える（§16.3.4）。月・年は §3.9 のまま |
| §4.2・0e-13 | 理由「空いている手の側」。左手は「題名は右寄せ、Z は 2 段目の右の端」 | 理由は「利き手の側」（本人の 12:2x）。案 B の左手は題名が右の端、等倍は 2 段目の左の端。丸いボタンの角の理由は「書く手の手のひらの反対の角」（P-4、`docs/M7_PLAN.md:228`・`:714`） |
| §5.4 | 1 行目は 1 回だけ作り直す、新しい出力は無い、「今の注も直さない」、手順 4 の J-4 | 2 回目を許す（§16.4）。注は Z2-12 で 1.4.1 の行の注（`:244-249`・`:1445-1457`）だけを直す（1.4.1 より前の行の注は直さない）。J-4 は N4 で行い、行の見直しは J-4 を待たない（§16.4 の 4） |
| §5.6 | ピン留めの字 | そのまま。新しい 2 つの引数も呼び出しの最後 |
| §6.1・§6.2 | `HeaderOrderTests`（「Z はどの行でも空いている手の側」）、キャンバスと UI のテストの期待（open・3 週） | §16.6 |
| §6.5 | 変異 8 つ | §16.7（MZ4〜MZ6・MS3 を足す） |
| §6.6・0e-23 | 速い道の正規表現 | `ZoomResetTargetTests`・`ZoomFitWiringTests` を足す（§16.8） |
| §7.1・0e-24 | 宣言 7 | そのまま使う（§16.8） |
| §7.3 | 見出しの切り抜き | 撮り直す（§16.8） |
| §7.4 | 新しい写真 | 等倍の 4 枚を足す（§16.6） |
| §7.5 | (A) 並べ方 (a)・(b)、(B) 印・字 | 並びの案 A・案 B（案 A だけを写真で）。等倍の見た目は印に決まった（§16.8・§16.11） |
| §8.1・§8.2 | `header.zoomReset.spoken` の comment、GLOSSARY の等倍（もとの大きさ）、en に Fit を使わない理由 | §16.9 |
| §8.3〜§8.6 | 新機能の文の行 1・2、審査メモの 1・2、SUPPORT の場所と定義（左上・2 段目の左）、文書 | §16.9 |
| §9.1 | 段 D0〜D5 | 段 N0〜N6（§16.10） |
| §9.4 | ビルド 29、行 3 の「2 つの選び」、選びごとにやり直す行（「並べ方 (b)・「等倍」の字・3 つ離した「‹ 今日 ›」: 行 2・3・4・7・12」「左手の題名の左寄せ: 行 12」ほか） | ビルド 30。凍結に触れたので確かめ表は全部の行。行 3 の選びは 1 つ（並びの案 A・案 B）。やり直す行は、案 A: 行 1・2・3・7・12（行 2・3・7・12 の合格の字は書き直して渡す）。「等倍」の字は閉じた。3 つ離した「‹ 今日 ›」: 行 1・2・3・4・7・12 のまま。左手の日付の左寄せ: 行 1・12 のまま（§0.4 に残した。§16.2）。ほかの行は第 2 版のまま |
| §11 | 危険 | §16.10 の危険を足す |
| §12 | 0e-3・0e-5・0e-6・0e-7・0e-8・0e-9・0e-10・0e-13 | 上の各行 |
| §13.1 | 確かめていないこと | 足す: (1) Duo の内側の題名の場所（約 44〜87、CI の道 3 で開けない）、(2) 本人の端末での fit の見た目（行 4・6・7・11・13）、(3) open = fit の機種で「採る」が本人の手で分かるか、(4) 審査メモの 3,992 バイトと新機能の文の字数（文の地図の数え）、(5) 案 A の右手がビルド 29 の左手と同じ画素か |

---

## 17. 1.4.1 の直し 2（2026-11-22、「動かす」ボタン。第 4 版）

**§17 が前の節と食い違う所は §17 が優先**（§16 より後に書いた）。§16 までの字は記録として残す。

### 17.1 本人の答えとリードの読み

- **11/22 20:0x JST、ビルド 30 の確かめの答え（そのまま）**: 「ツールバーにつまみが無く、動かせない。これ関連のテストは出来ませんでした。後は○です。」
- 読み: 確かめ表（§10）の行 1〜12・18〜21 は ○、22 は「—」。行 13〜17（ツールバーを動かす行）は、動かせなかったので試せなかった。
- 原因の見立て【推定】:
  - ビルド 30 にもつまみは有る。run #3 の palette の行は `grip=on`。写真にも 36×5 の印が写っている（`ipad13-portrait-week-fit.png` の下のバーの上の真ん中）。
  - ただし印は、紙とバーの間 8 pt の帯にある短い灰色の線だけ。触れる範囲は 120×16 pt（iPad mini で約 22×3 mm）で、Apple の HIG の 44 pt を大きく下回る。
  - だから本人には「つまみ」に見えなかったか、指で押さえられなかった。CI の UI テストは座標で正確に引くので通った（§4.5 の「8 pt の帯だけでは指に細すぎる」の考えが、16 pt でもまだ足りなかった）。
- 消し切れない別の原因【未確認】: 実機の Pencil で `PalmWatch` の数が戻らず、手のひらの規則がずっと「否」になる形。CI では Pencil を使えないので見えない。下の「押すと選べる」は手のひらの規則を通らないので、この形でも動かせる。
- 決め方: 本人に問わず（許可で作業を止めない約束）、見つけやすく押しやすい形を足す。ビルド 31 で本人が見て、違えば言葉で替える。

### 17.2 「動かす」ボタン

- **出る所**: つまみと同じ条件（`ToolbarLogic.showsGrip(mode, allowed:)` = 開いたバーで、許す辺が 2 つ以上の iPad の窓）。
  - iPhone・Duo・細い窓・のぞき・丸いボタンには出ない。**iPhone のツールバーは 1 バイトも変えない**。
- **置き場所**: スクロールの外で、「しまう」のすぐ前。
  - 横のバー: [並び | 区切り | 動かす | しまう]
  - 縦のバー: [並び / 区切り / 動かす / しまう]
  - 「動かす」と「しまう」の間に区切りは入れない。
- **見た目**: 「しまう」と同じ face（`buttonFace`）。印は SF Symbols の `arrow.up.and.down.and.arrow.left.and.right`、名前は「動かす」（新しい鍵 `toolbar.move.title`）、色は `Color.primary`。
  - 幅と余白は道具のボタンと同じ考え（48 pt、間 0）。縦のバーでは列の幅。
  - **バーの高さは変えない**ので、紙の領域（`toolbar: paperArea=`）と関門 3 は同じ。
- **押す（タップ）**: 指・トラックパッド・マウス・Apple Pencil の**どれでも**開く。**手のひらの規則は通らない**（何も動かさず選ぶだけなので）。
  - ボタンを指した確かめの画面（iPad ではボタンから出る小さな吹き出し、`confirmationDialog`）を開く。
  - 題は「ツールバーを動かす」（`toolbar.grip.spoken`、見える題）。選びは `ToolbarLogic.moveTargets(allowed:current:)` の順に「上へ移す」「下へ移す」「左へ移す」「右へ移す」（`ToolbarLogic.moveToTitle`）。
  - 選ぶと、VoiceOver の操作と同じ道（`paletteMoveChosen`。写真モードでは `@State` だけ）で置く。アニメーションしない 1 つのトランザクション。
  - 吹き出しが出ている間に許す辺が替わり、選んだ辺がもう許されていなければ、何もしない。
- **引く（ドラッグ）**: 指・トラックパッド・マウスで、ボタンから 10 pt 動かすと、つまみと**まったく同じ**ドラッグになる（Pencil は入れない）。
  - 手のひらの規則・40 % のバー・puck・輪郭・吸い付き・取り消しの時（§4.6・§4.7）はつまみと同じ。
  - 受ける UIView はつまみの `GripView` の作りを共有し、写しは作らない。
- **タップとドラッグの分け方**: 10 pt 動く前に指が離れればタップ（吹き出し）、10 pt 動けばドラッグで、タップにはならない。
  - Pencil の触れはドラッグにならず、離れればタップ。
  - 作り方（`UITapGestureRecognizer` と pan の組み合わせか、触れの追いかけか）は作る人が決め、単体テストで分け方を固める（下の 17.4）。
- **VoiceOver**: ボタンは 1 つの要素。名前「ツールバーを動かす」、ヒント「上下左右の端へ移せます」（`toolbar.grip.hint`）、ボタンの trait、identifier `toolbar.move`。
  - つまみと同じ「…へ移す」の操作を持ち、ダブルタップで吹き出しを開く。
- **つまみ（§4.5）はそのまま**: 字・大きさ・印・テストを変えない。

### 17.3 文

- **アプリ**: 新しい鍵は `toolbar.move.title`「動かす」の 1 つ（10 pt の名前。「しまう」の `toolbar.collapse.title` と同じ扱い）。
  - 9 言語の訳（X、GLOSSARY を先に）→ 元を見ない逆翻訳（R）→ 判定 → `docs/i18n/REVIEW.md` の新しい節 16 の × を 0 に。
  - 48 pt に入らない言語は、縮み（`labelMinScale` 0.8）の範囲で入る短い語にする。Localized の写真で確かめる。
  - ほかの文は今の鍵を使う（`toolbar.grip.spoken`・`toolbar.grip.hint`・`toolbar.moveTo.*`）。
- **新機能の文（16 ロケール）は変えない**。行 4「iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。」は、ボタンでも正しいため。
- **審査メモ**（`docs/store/review-note.txt`）: 1.4.1 の段の 3（つまみの文と確かめ方）を、「動かす」ボタン（押して選ぶ・引く）と小さなつまみの文に替える。
  - 4,000 バイト以下。英語の部分は元を見ない逆翻訳。
  - 英語のボタンの名前は、アプリの en の訳の字。
- **SUPPORT**（日本語・英語。`docs/SUPPORT.md` と Web の `r141-legal`）: 「ツールバーを動かすには？」の答えを「動かす」ボタン（押すと選べる・引いても動く）中心に書き直し、つまみは「縁の小さなつまみを引いても動きます」と添える。
  - 「Apple Pencil では動きません」は「Apple Pencil では引けません（押して選ぶことはできます）」に。
  - 英語は元を見ない逆翻訳。
- 本人向けの §0.1 と確認ページの文も同じ形に直す。

### 17.4 テスト

- **単体**: 新しい組 `PaletteMoveButtonTests`（速い道の正規表現に足す）。
  - ボタンが出る条件は `showsGrip` と同じ（iPhone・1 辺・のぞき・丸いボタンでは無い）。
  - タップとドラッグの分け方（10 pt の前に離れればタップ、10 pt でドラッグ、ドラッグの後はタップにしない）。
  - タップはどの触れの種類でも、手のひらの規則が否でも開く。
  - ドラッグは Pencil を入れず、手のひらの規則が否なら始まらない（つまみと同じ）。
  - 吹き出しの選びは `moveTargets` と同じ並び。許されていない辺の選びは何もしない。
  - identifier・名前・ヒント・操作の一覧。
  - 今の `PaletteGripTests` は変えずに通す。
- **UI**（`PaletteMoveUITests`、13 インチ iPad、blank-paper の「Palette UI tests on the 13-inch iPad (1.4.1)」の段）に `testTheMoveButtonMovesTheBar` を足す。
  - 「動かす」を押す → 吹き出し → 「右へ移す」→ 辺が right、`areas` が 1 増える。
  - もう一度押す → 「上へ移す」→ top。
  - ボタンを指で引いて左へ → left。
  - 押して「下へ移す」→ bottom。
  - その段の grep（`build.yml` の `testTheGripMovesTheBarToEveryEdge.*passed`）に新しいテストの名前も足す。
  - `testThePhoneKeepsTheBottomBar` は、iPhone に `toolbar.move` が無いことも見る。
- **写真**（`PaletteShotsUITests`、確認ページだけ。J-4 の外）: 次の 3 枚を足す。
  - `ipad13-portrait-week-move`: 下のバーの右の端に「動かす」
  - `ipad13-portrait-week-move-menu`: 吹き出しが開いた所。写真モードの新しい引数 `--screenshot-palette-menu`
  - `ipadmini-portrait-week-left-move`: 縦のバーの「動かす」
- **変異**（新しい枝 `r141-q-m3`。取り込まない。build.yml の `MUTATIONS` に `r141-q-m3` を足すのは、その枝の上だけ。`r141-q-m2` と同じ形）: 次の 4 つ。
  - MB1: ボタンを許す辺の数を見ずに出す
  - MB2: タップで吹き出しを開かない
  - MB3: ボタンのドラッグに Pencil を入れる
  - MB4: 吹き出しの選びに今の辺も入れる
  - 落ちるテストの表は、run の前に記録に書く。落ちたテストが表とちょうど同じなら ○。

### 17.5 CI・J-4・関門

- **基準**: 通しの run #3（44993399706、b85ed4b）。単体 885・UI 69。新しい数は run #4 で書く。
- **関門 3**: span-shots-app の状態の行と `toolbar: paperArea=` の組が run #3 と同じ見込み（バーの高さが同じなので）。違えば止める。
- **J-4（前もっての宣言 9。run #4 の前に書く）**: 宣言 7 の行（`mytools/j4d2.sh`）を、iPad の開いた下のバーの写真（`ipad13-portrait-*`・`ipadmini-portrait-*`・`ipad11-portrait-*`・`store/ipad13/*`・`store/ipad11/*`。`toolbar-collapsed*` は除く）では、つまみの帯の上の端から**バーの下の端まで**に広げる。
  - 行の数は、基準の写真のバーの下の端（1.4 の run 44853713800 の写真で測る）。
  - ほかの写真と行は宣言 7 のまま。強い差は、その行の外で 0。
- **ツールバーの切り抜き（新）**: iPad 3 機種（13・11・mini）の下のバーを、1.4 → run #4 で並べて ○ ×。
  - 違ってよいのは、右の端の「動かす」と、それで並びの見える幅が減った所だけ。
- **ほかのログの関門**: `PaletteMoveUITests` の 2 本が緑。palette-shots の `ok=yes` が今の 18 行と同じで、新しい 3 枚も ok=yes（計 21 行）。`header room:`・`zoom-reset UI:` は run #3 と同じ。
- **変えない**: `TESTS_1_3`・`TESTS_1_2_3`・`FIXTURES_1_3`・`DATA_1_1` の 20 行（凍結のファイルに触れない）、保存のバイト、compat。

### 17.6 段取り P0〜P5

| 段 | だれ | すること | 次へ進む条件 |
| --- | --- | --- | --- |
| P0（11/22） | リード | この §17、記録の「1.4.1 の直し 2」と宣言 9 | — |
| P1（11/22〜23） | 作る役（`r141-w-mv`）・X と R（`r141-w-x3`）・文の役（W） | §17.2〜17.4 のコードとテスト・訳・審査メモと SUPPORT | 速い道 `r141-q-mv` が緑。2 つの目の見直しの指摘を直した |
| P2 | リード | `r141` へ取り込み、通しの run #4 | 単体・UI の失敗 0、関門 3 が同じ、§17.5 のログの関門 |
| P3 | リード・C | 変異 `r141-q-m3`、J-4（同じ UTC の日）、ツールバーの切り抜き、palette の写真 | 表とちょうど同じ／宣言の外で 0／切り抜きが全部 ○ |
| P4 | リード | testflight.yml でビルド 31（確かめた commit からコードの差が空）、Connect で VALID。確認ページ（1MgUBYmZBtXGgESqEebUFE を同じ URL で更新） | 本人に渡す |
| P5 | 本人 → リード | 確かめ表の行 1・10・13〜17・19（iPad）・20 と新しい行 23。ほかの行は ビルド 30 の ○ を使う（iPad のツールバーのほかに変えた所が無いため。行 10・20 はツールバーを動かした後の行なので、もう一度） | 本人の言葉（§9.4） |

### 17.7 確かめ表の読み替え（ビルド 31）

- 行 1: 「1.4.1（31）」。
- 行 13: 「小さなつまみを指でつかみ」→「『動かす』を押して『上へ移す』などを選ぶ。次に『動かす』を指で引いて、上・左・右・下へ動かす」。
- 行 14: 「Pencil で『動かす』を引いてみる」（押すと吹き出しは開いてよい）。
- 行 15〜17: 「つまみ」を「『動かす』」に読み替える。
- 新しい行 23（iPad）:
  - すること: 下のバーの「しまう」の左に「動かす」があるか見る。紙に近い縁の小さなつまみを指で引いてみる。
  - 合格: 「動かす」が有る。つまみでも動く（つまみで動かなくても、「動かす」で動けば ○。そのときは教えてください）。
- 行 18（iPhone）は ビルド 30 の ○ のまま（iPhone のツールバーは 1 バイトも変えない）。

---

## 18. 1.4.1 の直し 3（2026-11-22 夜、しまったときにも「動かす」。第 5 版）

**§18 が前の節（§17 を含む）と食い違う所は §18 が優先**。§17 の字は記録として残す。

### 18.1 見直しで見つけた事

§17 の作る役の後の見直し（見方 A、実機の UIKit・SwiftUI）が must を 1 つ出した。リードがコードと確かめ表で読み直して、事実を確かめた。

- 【事実】確かめ表（§10）の行 12 で、本人はツールバーをしまう（丸いボタンを見る）。行 13 の前に開き直す手順は無い。
- 【事実】しまった状態は `toolbar.collapsed` に保存され、アプリを開き直しても、TestFlight で版を上げても残る（`ToolbarLogic.startMode`）。
- 【事実】しまった状態で丸いボタンを押すと「のぞき」（`(.collapsed, .dockToolTapped)` → `.peek`）になる。のぞきのバーには、つまみが無い（§4.5、`showsGrip` は `.expanded` だけ）。開いたバーに戻る道は、丸いボタンの長押しの「ツールバーをいつも出す」（`.pinChosen`）だけ。
- 【事実】§17 の「動かす」もつまみと同じ条件（`showsMoveButton` = `showsGrip`）なので、のぞきには出ない。ビルド 31 をこのまま渡すと、行 13〜17・23 は同じ形で × になりうる。
- 【事実】CI の写真モードは、いつも開いたバーから始まる（`startState(shot:)` は保存した collapsed を読まない）。だから CI はこの形を一度も通らなかった。
- 【推定】本人の「ツールバーにつまみが無く」は、§17.1 の見立て（つまみが小さく見つけにくい）より、この形（しまった状態から丸いボタンで出したバー）によく合う。どちらの形かは確かめられないので、両方を塞ぐ。
- 決め方: 本人に問わず（許可で作業を止めない約束）、のぞきにも「動かす」を出す（下の 18.2）。確かめ表にも、しまってあるときの手順を書く（18.7）。

### 18.2 直し（コード）

- **出る所**: 「動かす」を、のぞきのバーにも出す。
  - `ToolbarLogic.showsMoveButton(mode, allowed:)` = `(mode == .expanded || mode == .peek) && allowed.count >= 2`。
  - つまみ（`showsGrip`）は今のまま、開いたバーだけ。丸いボタン（`.collapsed`）には何も足さない。
  - iPhone・Duo・細い窓（許す辺が下だけ）では、今のまま無い。**iPhone のツールバーは 1 バイトも変えない**。
- **のぞきの「動かす」は押すだけ**: 押すと §17.2 と同じ吹き出し（題「ツールバーを動かす」、選びは `moveTargets` の順）。どの触れの種類でも開き、手のひらの規則は通らない。
  - 引いても動かない（ドラッグは開いたバーだけ。のぞきは紙に重なっていて、40 % のバー・puck・輪郭の作りは開いたバーのため）。作り方は、のぞきでは pan が始まらないようにする（例: `mayBegin` が開いたバーのときだけ真）。
  - 10 pt 動いてから離した指は、タップにもならない（何も起きない。§17.2 の分け方のまま）。
- **のぞきで端を選ぶと、その端でツールバーを開いたまま残す（決定 0e-26）**。
  - 状態の表に `(.peek, .placementChosen)` → `ToolbarStep(mode: .expanded, storeCollapsed: false, storesPlacement: true)` を足す。
  - 置き場所の覚え方は §4.7 と同じ（`AppSettings.paletteEdge`。左右なら丸いボタンの角 `AppSettings.toolbarEdge` も）。`toolbar.collapsed` は false にする。
  - 置き場所と開くことは、アニメーションの無い 1 つのトランザクションで行う。紙の並び直しは 1 回。
  - 写真モードは `@State` だけ（`AppSettings` に書かない。§4.10）。
  - 「しまう」を押せば、またしまう（丸いボタンはその側の下の角。§4.9 のまま）。
  - 理由: 「動かす」で端を選ぶのは「ツールバーをそこに置きたい」ということ。のぞきは書き始めると消えるので、選んだ端に開いて見せるのがわかりやすい。確かめ表の行 13 の合格（その端に吸い付く・紙が 1 回だけ並び直る）にも合う。
- **開いたバーの「動かす」（§17.2）は変えない**（押す・引く・VoiceOver）。
- **吹き出しの閉じ方**: 吹き出しが開いている間に「動かす」が消えたら（のぞきが Pencil で閉じた・背景へ行った・窓が細くなった）、吹き出しも閉じる。今の `onChange(of: paletteHasGrip)` はのぞきの間は変わらないので、`paletteHasMoveButton` の変化でも閉じる。
- **VoiceOver**: のぞきの「動かす」も 1 つの要素で、§17.2 と同じ名前・ヒント・identifier `toolbar.move`・「…へ移す」の操作。操作で選んだときも、のぞきなら開いたまま残す（同じ道 `paletteMoveChosen`）。
- **変えない**: 丸いボタンとその長押しのメニュー（左下へ移す・右下へ移す・ツールバーをいつも出す）、つまみ、開いたバーの並びと高さ、のぞきの出る場所（§4.9）、iPhone。

### 18.3 テスト

- **単体**（凍結の外。1.4.1 の自分のテスト）:
  - `ToolbarLogicTests` と `ToolbarPlacementTests` の `(.peek, .placementChosen)` の期待を、新しい行に替える（覚えるのが `expanded placementChosen` と `peek placementChosen` の 2 つになる）。
  - `PaletteMoveButtonTests` に足す: `showsMoveButton(.peek, 2 辺以上)` は真、`(.peek, [.bottom])` と `(.collapsed, …)` は偽、`showsGrip(.peek, …)` は偽のまま。のぞきではドラッグが始まらない。`paletteDropped(mode: .peek)` が置き場所を覚える。画面の配線（選びが `paletteMoveChosen` を通り、そこで表の `.placementChosen` を当てる）を `codeOnly` で固める。
- **UI**（`PaletteMoveUITests`、13 インチ iPad）に `testThePeekedBarHasTheMoveButton` を足す。
  - `--screenshot-toolbar collapsed` で始める → 丸いボタンの道具を押す → のぞき。
  - つまみ（`toolbar.grip`）が無く、「動かす」（`toolbar.move`）が有る。
  - 「動かす」を押す → 吹き出し → 「右へ移す」→ ツールバーが右に開いたまま（`palette.state` の辺が right、開いた状態、`areas` が 1 増える）。丸いボタンは無い。
  - 「しまう」を押す → 丸いボタンが右下の角。
  - blank-paper の「Palette UI tests on the 13-inch iPad (1.4.1)」の段で、3 本とも `passed` を求める。
- **写真**（`PaletteShotsUITests`、確認ページだけ。J-4 の外）: `ipad13-portrait-week-peek-move`（のぞきのバーの「しまう」の左に「動かす」）を足す。palette-shots の行は 22。
- **変異**（`r141-q-m3` に足す）: 次の 2 つ。落ちるテストの表は run の前に記録に書く。
  - MB5: のぞきに「動かす」を出さない（`showsMoveButton` を `showsGrip` に戻す）
  - MB6: のぞきで選んでも、のぞきのまま（表の新しい行を消す）

### 18.4 文

- **アプリ**: 新しい鍵は無い。
- **SUPPORT**（日本語・英語。`docs/SUPPORT.md`・`docs/SUPPORT.en.md` と Web の `r141-legal`）: 「ツールバーを動かすには？」の答えに 1 文足す。
  - 日本語: 「ツールバーをしまっているときは、丸ボタンの道具の印を押して出たツールバーの「動かす」から選べます（選んだ端に、ツールバーが開いたまま残ります）。」
  - （11/23 の決定 0e-34 で、「丸いボタンを押して」を「丸ボタンの道具の印を押して」に替えた。英語も「tap the tool mark on the round button」。§18.8）
  - 英語は元を見ない逆翻訳。
- **審査メモ・新機能の文は変えない**（「Move button」の文はのぞきでも正しい。審査メモは 4,000 バイトに近い）。
- 本人向けの §0.1 と確認ページにも同じ形を書く。

### 18.5 CI・J-4・関門

- **J-4**: 写真モードにのぞきの引数は無く、J-4 の組にのぞきの写真は無い見込み。だから宣言 9 のまま。作る役が J-4 の写真で変わる物を見つけたら、run #4 の前にリードが宣言 10 を書く。
- **ログの関門**: `PaletteMoveUITests` の 3 本が緑。palette-shots の `ok=yes` が 22 行。ほかは §17.5 のまま。
- 単体と UI の数は run #4 で書く（UI は 70 から 1 増えて 71 の見込み）。

### 18.6 段取り

- P1'（作る役 `r141-w-pk`・文の役・2 つの見直し・直し。速い道 `r141-q-pk`）→ P2 から後は §17.6 のまま（run #4、変異 `r141-q-m3` は MB1〜MB6）。

### 18.7 確かめ表の読み替え（ビルド 31。§17.7 を替える）

- 行 1: 「1.4.1（31）」。
- 行 13:
  - すること: ツールバーがしまってあって丸いボタンだけのときは、丸いボタンの道具の印を押す（↶ は「元に戻す」）。出たツールバーの「しまう」の左の「動かす」を押し、「右へ移す」を選ぶ。次に「動かす」を押して「上へ移す」「左へ移す」「下へ移す」を順に選ぶ。次に「動かす」を指で引いて、上・左・右・下へ動かす。次に週で等倍を押し、ツールバーを左と右へ動かす。
  - 合格: 丸いボタンから出したツールバーにも「動かす」がある。選んだ端・引いた端に吸い付き、開いたまま残る。左右では縦に立つ。紙が 1 回だけ並び直る。等倍の週は、ツールバーを左右へ動かしても、1 週の左右の端が、ツールバーの横の紙の場所の左右の端にそろったまま。
- 行 14: 「Pencil で『動かす』を引いてみる」（押すと吹き出しは開いてよい）。合格: ツールバーは動かない。
- 行 15・16: 「つまみ」を「『動かす』」に読み替える。
- 行 17:
  - すること: 左か右の端で「しまう」を押す。丸いボタンを押す。出たツールバーに「動かす」があるのを見る。Pencil で書き始める。
  - 合格: 丸いボタンはその側の下の角。押すとその側にツールバーが出て、「動かす」がある。書き始めるとまたしまう。
- 行 23（iPad）:
  - すること: ツールバーが開いているとき（行 13 の後など）に、「しまう」の左（左右の端では「しまう」の上）に「動かす」があるか見る。紙に近い縁の小さなつまみを指で引いてみる。
  - 合格: 「動かす」が有る。つまみでも動く（つまみで動かなくても、「動かす」で動けば ○。そのときは教えてください）。
- 行 18（iPhone）は ビルド 30 の ○ のまま（iPhone のツールバーは 1 バイトも変えない）。

### 18.8 見直しで直したこと（2026-11-23。確認ページの下書きの 2 つの見直しから）

- **決定 0e-28（審査メモの 4）**: `docs/store/review-note.txt` の 4 の 1 文目「New text is only in Settings and VoiceOver labels.」と、日本語の要約の「新しい文は設定と読み上げだけ。」を**消す**。
  - 理由: §17 から、iPad のツールバーに「動かす」（Move）の字が出て、押すと吹き出しの題（`toolbar.grip.spoken`）と「…へ移す」（`toolbar.moveTo.*`）も画面に出る。§8.4 の (4)「新しい画面の文は設定と読み上げだけ」と、§17.3・§18.4 の「審査メモは 3 だけ替える」は、この点で事実と合わなくなった。
  - 新しい英文は足さない（3 が「Move」のボタンをもう書いている）。字を消すだけなので、元を見ない逆翻訳はやり直さない。4 は「4. Unchanged: data (…), handwriting storage, purchases and the age rating.」になる。
  - バイト数は 4 つの組（案 A・B × 「The next page…」あり・なし）とも減る。数え直して `PROPOSALS_1_4_1.md` §2.2 と `docs/store/README.md` に書く。PROPOSALS の「4 の『New text is only…』も正しい」「読み上げの名前は画面に出ないため」の注も今の事実に直す。
- **決定 0e-29（確かめ表の行 14・15。§18.7 を替える）**:
  - 行 14 のすること: 「「動かす」とつまみのすぐそばで Pencil で書く。Pencil で「動かす」とつまみを引いてみる（押すと吹き出しは開いてよい。吹き出しで端を選ぶと、Pencil でもツールバーはその端へ移る）」。合格: 「書いても、引いても、ツールバーは動き出さない」。前半（すぐそばで書く）を残すのは、§17.1 の【未確認】（Pencil で書いた後の手のひらの規則）を本人の端末で見る行がほかに無いため。
  - 行 15 の読み替え: 合格の「（つまみの真上から始めたときだけ、ツールバーが動きます）」は「（「動かす」かつまみの上から始めたときだけ、ツールバーが動きます）」にする。行 15 のほかの所と行 16 に「つまみ」は無い。
- **決定 0e-30（確認ページの試す順）**: 確認ページでは、やり直す 10 行を **1 → 13 → 23 → 10 → 20 → 14 → 15 → 16 → 17 → 19** の順に並べる（表の番号はそのまま）。前の行が残したツールバーの形のまま次の行を試せるようにするため（行 13 で開いて動かし、行 17 でしまって終わる。行 19 はツールバーを使わない）。行 13 の 1 文目（しまってあれば丸いボタンの道具の印を押す。↶ は「元に戻す」）は太字にし、最初の画面にも書く。
- **決定 0e-31（写真の材料。§17.6 P3 に足す）**: 確認ページの見出しの切り抜き 12 組と設定のシートの組は、1.4 の run と**通しの run #4**（45074645599、d416da8）の写真から作り直し、記録の「直し 3」に判定の表（| 機種 | 前 | 後 | ○ × | 中身 |）を書く。Duo の外側の切り抜きは **duo の run 45075275518**（d416da8、枝 `r141-duo4`）から。見出しのコードはビルド 30 から変えていないので、判定は全部 ○ の見込み（違えば止める）。
- **決定 0e-32（翻訳者向けの説明の残り）**: `tools/l10n/source/app-S.json` の `toolbar.grip.spoken`・`toolbar.moveTo.*` の説明は「読み上げ」のままだが、直すと生成の `Localizable.xcstrings`（`Sources` の中）が替わり、run #4 と確かめた commit からコードの差が出る。画面の字は替わらないので、**1.4.1 では直さない**。次の版で直す（記録に残す）。
- **決定 0e-33（確かめ表の行 13 の 1 文目。§18.7 をその場で替えた、11/23 その 2）**: 行 13 のすることの 1 文目を「ツールバーがしまってあって丸いボタンだけのときは、丸いボタンの道具の印を押す（↶ は「元に戻す」）。」にした（前の字は「…丸いボタンを押す。」）。0e-30 で太字にすると決めた中身（道具の印・↶）と、確認ページの太字の字を合わせるため。丸いボタンは道具の印と ↶ の 2 つでできていて（`ToolbarDock.swift`）、↶ を押すと線が 1 本消えるだけで、ツールバーは出ない。文書だけで、ビルド 31 のコードは変わらない。
- **決定 0e-34（SUPPORT の §18.4 の 1 文。§18.4 をその場で替えた）**: 日本語の「丸いボタンを押して出たツールバー」を「丸ボタンの道具の印を押して出たツールバー」に、英語の「tap the round button, then tap “Move”」を「tap the tool mark on the round button, then tap “Move”」にした。同じページの「ツールバーをしまうには？」と同じ呼び方（丸ボタン・道具の印・tool mark on the round button）にして、↶ を押して止まる読み違えを避けるため（確認ページの 2 回目の見直しの指摘。REVIEW 16.x の W の注も同じ点を挙げていた）。英語の 1 文は元を見ない逆翻訳と判定で ○（REVIEW 16.z）。Web の `r141-legal` も同じ字にする。審査メモと新機能の文は変えない。本人向けの §0.1 の「丸いボタンを押して出たツールバーに「動かす」があります」は、出る所の説明なので替えない（押す所は確認ページの最初の画面と行 13 に書く）。
- **決定 0e-35（§0 の古い字は替えない）**: §0.2 の並び（道具 → 色 → 細中太 → ↶↷ → 指でも書く → しまう）、§0.5「指でつまみを動かす」、§0.6「Pencil では動きません」は、第 3 版の字のまま残す。§17・§18 が上書きしていて、確認ページは今の事実の字（「動かす」と「しまう」、Apple Pencil では引けない・押して選べる）で書く（作る道具の読み替え）。
