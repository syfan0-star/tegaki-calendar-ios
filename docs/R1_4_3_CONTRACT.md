# 1.4.3 実装契約（月と年を横につなげる・月と年の等倍を幅にちょうど）

> **第 1 版（2026-11-28）**: 1.4.2 を 11/28 02:15 に公開し、main（4a2211d）にまとめた後に書いた最初の版です。
>
> **本人が読む所**: すぐ下の §0（まとめ）だけで足ります。§15 の確かめ表は、TestFlight のビルドが届いたときに Claude が番号を書いて改めて渡します（今は開かなくて大丈夫です）。§1 から後は、作る人のための約束です。
>
> **この文書の決まり**: 1.4.3 の作業はこの文書に従います。元は本人の 2026-11-22 の言葉（「月と年は、横スクロールができる仕様にしてから、幅が両端にくる等倍を適用します」）、[M7_PLAN.md](M7_PLAN.md) §4 の「次の版」の行と 1.7・1.8 の行、[R1_4_2_CONTRACT.md](R1_4_2_CONTRACT.md) の 0f-2（「次の版」は 1.4.2 の後。番号と中身はその版の契約で決め、1.7・1.8 と一緒に設計する）、[B_DESIGN.md](B_DESIGN.md) の §2〜§6・§8・§11・§12（月 §3.4、年 §3.5）、[M7C_CONTRACT.md](M7C_CONTRACT.md)（1.3 の横つなぎ B-1 の約束と、月・年へ送った約束）、[R1_4_1_CONTRACT.md](R1_4_1_CONTRACT.md) §16（等倍の規則）です。B_DESIGN は 1.3 の前の番号（B-1 = 1.5、年 = 1.6、月 = 1.7）と m7a のコードの行で書かれている（読み替えは M7C_CONTRACT §1.2）。**食い違う所はこの文書が優先**です。結果と前もっての宣言は `docs/R1_4_3.md`（S0 でリードが作る）に書きます（この文書の §19 は契約の版の記録だけ）。節の形は [R1_4_2_CONTRACT.md](R1_4_2_CONTRACT.md) にそろえました。
>
> **材料**: 調べ役の地図 5 つ（しくみ、月、年と等倍、段取りと CI、本人の言葉と時期。2026-11-28 に main 4a2211d を読んだだけ）。**行番号は main 4a2211d**（`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は 1.4.2 の確かめた commit 57ffd0f と 1 バイトも同じ。`git diff 57ffd0f 4a2211d -- …` が空）。この契約の書き手が 2026-11-28 に主な行をコードで読み直した（§18.2）。パスは断りが無ければ `Sources/TegakiCalendar/` からの相対、テストは `Tests/` の下。印: 【事実】はコードか記録で確かめた事、【推定】は事実から考えた事、【未確認】は確かめられなかった事、【計算】は数で出した事。決定の番号は **0g-1〜0g-51**（§17。1.4.2 の 0f-n の続き）。

---

## 0. まとめ（本人向け）

### 0.1 1.4.3 ですること

11/22 のお言葉「月と年は、横スクロールができる仕様にしてから、幅が両端にくる等倍を適用します」のとおりに、**月と年のページを横につなげてから、月と年の等倍を「幅にちょうど」にする**版です。1.7（月）・1.8（年）の予定だった「月と年を横につなげる」を、この 1.4.3 に前倒しします（ほかの版の番号は変えません）。

**月のページ**
- 指で横にすべらせると、となりの月の表が続いて出てきます（1.3 からの週・日と同じ動き）。10 月の表の右に 11 月の表が並び、表と表の間に濃い縦の線が入ります。iPhone で「指でも書く」がオンのときは 2 本指で動かします。iPad では、一覧でも指 1 本で横に動くようになります。
- 表と表の間では、日付は続きません（右どなりは 4〜5 週あとの日です。11/1 のお答え「この形でよい」のとおり）。月末から月初へ日付どおりに書くのは、今と同じく 1 つの表の中か、週のページです。
- **月の境目をまたいで書けるのは、下のメモ欄です。** メモ欄が横に 1 本の帯になり、「年末までに: 大掃除 → 年賀状 → 帰省の切符」のように、10 月から 11 月へ続けて書けます。
- 前後の月の薄い日は、今までどおり両方の表に出ます。10 月の表の薄い 11/1 に書いたものは、すぐ右の 11 月の表の 11/1 には出ません（同じ画面に 11/1 のマスが 2 つ並ぶことがあります）。今日の印も、薄い方にも付きます。
- 曜日の行の、各表の左端に月の名前の札（「11月」）が付きます。左へ出ていった月の札は、画面の左端に残ります。
- メモ欄の上の区切りの線と罫線（ドット方眼なら点）は、となりの月と同じ高さにそろえます。格子の短い月では、格子と区切りの線の間に白い紙が入ります（メモ欄の一部で、書けます）。メモ欄の下も、となりのいちばん長い月の分だけ白紙が続きます。
- **月の並べ方は、3 通りの写真を見て選べます**（P-B3。§0.4）: **ア（おすすめ）** メモ欄だけそろえる（上のとおり）／イ 格子の行の高さも全部そろえる（1 枚の大きな表のよう。となりの月の予定で行が伸びる）／ウ そろえない（今の月をそのまま並べる。メモ欄の高さが月ごとにずれる）。何もおっしゃらなければアで作ります。

**年のページ**
- 12 月の右に、次の年の日付の列と 1〜12 月が続きます。日付の列の上に「2027」の札が付きます。
- 同じ日付が横一直線に並ぶよう、行の高さを、となりの年のいちばん高い行にそろえます（見た目だけで、書いたものは動きません）。
- 15 日の行で 10 月から翌年 2 月へ矢印を引く、12 月から 1 月へ印を付ける、のように年をまたいで書けます。12/31 から 1/1 へは、12 月の列の下から 1 月の列の上への斜めの線になります。
- iPad の縦の一覧では、左右に前の年の 12 月と次の年の 1 月が少し見えます（今は机の色の余白がある所です）。
- iPhone を横にした年の一覧は、週と同じく 3 年分までの大きさにします（11/18 の「上限ありが良いです」のとおり）。1 年全部は縦に入らないので、上下にすべらせて見ます。

**等倍（虫めがねに「1」のボタン）**
- 月と年でも、等倍が「1 ページの幅が画面の幅にちょうど合う大きさ」になります（日と週は 1.4.1 から）。
- 開いたときの大きさは今のままです。一度押すと、その種類は次からも等倍で開きます。2 本の指で大きさを変えると、次からはその大きさで開きます（日・週と同じ）。
- 縦の iPad の月と、縦の iPhone の月と年は、開いたときにもう幅がちょうどなので、押しても見た目はほとんど変わりません。それでも等倍として覚えるので、その後に端末を横にすると、幅にちょうどになります。
- 横の iPad で月の等倍を押すと、6 週のうち 4 週前後が見え、残りの週とメモ欄は下へすべらせて見ます。年の等倍で見える日数は、31 日のうち、iPad の縦で 26〜28 日ほど、横で 11〜14 日ほど、iPhone の横で 6〜7 日ほどです【計算。作った後にもう一度測ります】。
- 設定 › ページ で横につなげるのをオフにしても、等倍は同じ（1 ページの幅にちょうど）です。

### 0.2 変わらないこと

- 書いた線の保存の形・iCloud の記録・書き出しの形は変えません。**今までの手書きは 1 本も動きません。** 新しい名前も、移し替えもありません。またいで書いた線は、線の真ん中があるページに 1 本で保存します（週・日と同じ）。
- 設定 › ページ の「前後のページを横につなげる」をオフにすると、月も年も今までどおり 1 ページずつです。
- 週と日のページは 1.4.2 のままです。「‹ 今日 ›」、利き手、ツールバー、ペンの色、メモ欄の紙、日付のダブルタップ、年の日付のタップも、そのままです。
- 「このページ」の PDF には、週・日と同じく、となりのページから入ってくる線の、紙の中の部分も出ます。
- 一覧よりさらに縮めることはしません（P-B10 ア）。はじくと、となりの月（年）で止まります（P-B5 ア）。
- iOS 17 以上の iPad・iPhone で使えるのも同じです。データは集めません。広告もありません。値段も同じです。

### 0.3 版の番号・順番・目安の日

- 版の番号は **1.4.3** です。1.5（指で予定）から後の番号は変えません。1.7・1.8 の中身（月と年を横につなげる）は、この版へ移します。
- 1.4.2 の約束（11/24）のとおり、1.4.2 の次の版です。
- 1 つの版で、月と年と等倍を一緒に出します（B の設計書の「月と年を 1 つの版にまとめると手間が少し減る」のとおり）。作る順は**月が先、年が後**です（11/1 のお答え「iPad でいちばん使うのは月」）。
- **年が間に合わないとき**: 12/5 の朝に年の部分が自動の確かめを通っていなければ、1.4.3 は月だけ（月の横つなぎと月の等倍）にし、年は次の 1.4.4 で出します。そのときは年の等倍も 1.4.4 まで今のまま（開いたときの大きさ）です（お言葉の「横スクロールの後に等倍」の順を守るため）。切り替えたら、その日のうちにお知らせします。
- 年末の前（12/18 めど）の提出をねらいます。

| いつ（目安） | すること | 本人にお願いすること |
| --- | --- | --- |
| 11/28 | この約束（第 1 版）と、作る前の決めごとの記録 | このまとめを読む（返事は要りません） |
| 11/28〜11/29 | 自動の確かめの準備（版の番号・比べる元の写真） | なし |
| 11/28〜12/5 | 月と年を横につなげる仕組み・紙・見出し・等倍を作る（月が先、年が後）。わざと壊して確かめが落ちるかも見る | なし |
| 12/1〜12/3 | 月の 3 通りの見本の写真と、月の等倍の前と後の写真を、先にお送りする | 選ぶ（何も言わなければア） |
| 12/5 | 年が間に合わなければ、月だけを 1.4.3 にし、年は 1.4.4 へ（お知らせします） | なし |
| 12/4〜12/8 | 新しい文の訳・サポートページ・新機能の文・審査メモ | なし |
| 12/9〜12/10 | TestFlight 1.4.3（ビルド 33 以上）と確認ページ（撮り直した App Store の写真も） | 確かめ表（§15）、「この内容で入れてよい」 |
| 確かめ表が全部 ○ になった後 | 審査に提出（手動公開） | 「1.4.3 を審査に提出して良い」 |
| 審査が通った後 | 公開 → 本流にまとめる | 「1.4.3 を公開して良い」「まとめて良い」 |
| 12/12 | 確認ページが渡せていなければお知らせします | — |
| 12/18 | 年末の前の最後の提出日の目安（12/19〜1/4 は審査が遅れることがあるため【未確認】） | — |

- 自動の確かめは 1 回に 1 時間半〜2 時間かかり、1 日に回せるのは数回です。直しが要れば、日が 1 日ほどずれます。進められる所は前倒しします。

### 0.4 本人にお願いすること（言葉と操作の一覧。ほかの節はここを指します）

- **見本の写真のページ 1 回（12/1〜12/3 ごろ）**: 月の並べ方 3 通り（ア・イ・ウ）を、同じ見本の手書きと予定で並べた写真（11 インチと 13 インチの縦・横、iPhone）と、月の等倍の前と後の写真（お手元の 4 台の大きさ）を、1 つのページでお送りします（1.3 の前に約束した「月の並べ方は月の版の見本で見てもらいます」のとおり）。
  - **選んでいただくのは月の並べ方だけです**（「イ」のように一言）。TestFlight のビルドを作り始める前（12/8 ごろ）までにお答えが無ければ、アで作ります。
  - 年の行のそろえ（前と後）と年の等倍の写真は、そろっていればこのページに、間に合わなければ確認ページに入れます（見るだけで、選ぶものではありません。違うと思ったら言ってください）。
- **確認ページ 1 回（12/9〜12/10 ごろ）**: 月と年の見え方、等倍、設定 › ページ の説明の新しい文（10 の言葉）、初めて開いたときの案内の札の新しい文、新機能の文（16 の言葉）、サポートページの変わる所（日本語・英語）、審査メモ、撮り直した App Store の写真を、1 つのページで見せます。「**この内容で入れてよい**」の言葉をください。
  - 設定 › ページ の説明の 2 つ目の文「月と年は、次の版から順に対応します。」は、前に本人に承認していただいた文です。1.4.3 では事実と合わなくなるので、確認ページで新しい文を見ていただき、この言葉で替えます。新しい文の案（§13.1）:「週・日・月・年のページで、前後のページが横につながり、境目をまたいで書けます（月のページでは、下のメモ欄でまたげます）。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。」
- **TestFlight 1.4.3 の確かめ表**（§15）。**本人の端末でしか確かめられません。** iPhone Duo の行は「—」で構いません（Duo はお持ちでないので、自動の確かめだけで見ます）。
- **できれば: iPad mini を、確かめ表の行 16 まで 1.4.2 のままにしてください**（古い版での見え方を見るため。1.3 のときの iPad Pro 13 と同じ形）。TestFlight で入れたアプリなら、TestFlight 1.4.3 が届く前（12/9 ごろまで）に、TestFlight の中の「てがきカレンダー」で自動アップデートをオフにしてください。できなかったとき・1.4.3 が入ってしまったときは、その行は「—」で構いません（自動の確かめで見ます）。
- **言葉**: 「**この内容で入れてよい**」「**1.4.3 を審査に提出して良い**」「**1.4.3 を公開して良い**」「**まとめて良い**」（1.4.3 を本流にまとめること）。前もってまとめてもらっても構いません（1.4.2 の 11/27 と同じ）。**本人がご自分の端末で確かめていない版は出しません。** 審査で戻されてアプリを直したときは、前にもらった公開の言葉は使いません。
- 年が間に合わず年を 1.4.4 にしたときは、1.4.4 の言葉は別にいただきます。
- **年齢区分の新しい問いが App Store Connect に出たときだけ、お聞きします**（答えは本人の言葉でいただきます）。

### 0.5 本人が決めなくてよいこと

- 版の番号、月と年を 1 つの版にまとめること、年が遅れたときの切り替え、試作版（TestFlight の試し）を作らないこと、設定オフ（1 ページずつ）でも等倍を幅にちょうどにすること、iPhone 横の年の上限、作り方・確かめ方・訳の手順。どれも既定で決め、理由を §17 に書きました。
- 前にお答えいただいたことは、そのとおりに作ります。もう一度お聞きすることはありません: P-B11 ア（月はこの形でよい）、P-B2 月（月を年より先に）、P-B5 ア（はじくと隣で止まる。またいで問題なく書けること）、P-B6 イ（iPhone 横は上限あり）、P-B10 ア（一覧より縮めない）、P-B4・P-B7・P-B8 はおまかせ（重なる日は今のまま両方の表に出す・設定は 1 つのスイッチ・PDF に隣の線）。
- **言っていただければ替えられること**（問いにはしません）: iPhone 横の年の上限を外す（1 年全部が入る今の一覧のままにする）、縦で等倍を押したときに覚えないようにする、月の重なる日の薄い行を低くする（P-B4）。

### 0.6 知っておいてほしいこと

- **試作版（TestFlight の試し）は作りません。** しくみと手ざわり（手のひら・はじき・2 本指）は 1.3 の週・日と同じで、11/18 にお答えいただいた形のまま月と年に広げるためです。B の設計書では「年の重さは試作版で確かめてもらう」とお約束していましたが、お手元の年は 152 本（11/6）と軽く、試作版では重さを感じにくいので、自動の確かめで重い年（数千本）を測り、TestFlight 1.4.3 の確かめ表で本物のデータを見ていただく形に替えます。
- 線がとても多いと、その種類だけ 1 ページずつに戻ることがあります（1 回お知らせします。書いたものは消えません。1.3 からの決まり）。B の設計書にあった「となりのページを見るだけにする」段は、この版では作りません（お手元の本数ではそこまで届かないため。測った値で後の版で考えます）。
- **1.4.2 までの端末では**、月・年の境目をまたいだ線は、保存されたページにだけ出て、紙の端で切れて見えます（消えてはいません）。古い版でその線を消すと、新しい版でも消えます。年の行のそろえとメモ欄のそろえも、古い版にはありません（見た目だけで、データは同じ）。iPad と iPhone の両方を 1.4.3 にしてください。
- 月の等倍で横にすると、月の表の下の方の週とメモ欄は、下へすべらせて見ます（1 ページの幅を画面の幅に合わせると、縦が入りきらないため）。小さくしたいときは 2 本の指でつまんでください。次からも、その大きさで開きます。
- 月のページは iPad でいちばんよく使うページなので、変わり方がいちばん目に入ります。気になる所があれば、確かめ表の × と写真で教えてください。
- **App Store の写真**のうち、月と年の写真（iPad 13 インチ・iPhone 6.9 インチと 6.3 インチ・iPhone Duo、16 の言葉）を、横につながった画面で撮り直します（1.4.1 のときの撮り忘れを繰り返さないため）。週と日の写真と、先頭の横つなぎ（週）の写真はそのままです。

---

## 1. 土台・決定・範囲

### 1.1 土台のコード

- 枝 `r143`。main の 4a2211d（1.4.2 を `--no-ff` でまとめた commit）から切る。`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は **57ffd0f（ビルド 32、1.4.2 の公開したビルド。確かめた commit）と 1 バイトも違わない**【事実】。確かめた通しの run は **45721608435**（57ffd0f、attempt 5 で 6 つのジョブが全部緑。`docs/R1_4_2.md` の V）。
- 1.4.2 は 11/28 02:15 JST に公開（READY_FOR_SALE）、Web main 4a9fbf3。main の run **46040646988**（4a2211d）は 11/27 17:46Z の時点で走っていた（compat-v1.0 は success）【事実】。**S0 でリードがその結果と日本の App Store の表示を `docs/R1_4_2.md` の D5 に書いたことを確かめる**（無ければ先に書く）。赤なら §14.1 の揺れの読み方で読み、本当の落ちなら D0 の前に止める。
- 版は `MARKETING_VERSION "1.4.3"`（今は `project.yml:23` で "1.4.2"）。配る先は iOS 17.0 のまま（`project.yml:21`）、`TARGETED_DEVICE_FAMILY "1,2"`（`project.yml:22`）も変えない。ビルドの番号は testflight.yml の run 番号（`testflight.yml:295`）で、1.4.2 が 32 を使ったので **33 以上**（0g-1）。
- この Mac には Xcode もシミュレータも無い（Command Line Tools だけ）。TegakiKit は `swift build` と KitChecks、アプリは `tools/typecheck/typecheck.sh [work-dir]`（Mac Catalyst。`TYPECHECK_DEFINES=DEBUG` で `#if DEBUG` も見る。`typecheck.sh:8-33`）まで。**iOS の本当のビルド・単体テスト・UI テスト・写真は GitHub Actions の CI だけ**。作る人は commit の前に typecheck を DEBUG あり・なしの 2 回通す。Xcode 27.2（27B52）・XcodeGen 2.46.0 は 1.4.2 と同じで、道具は替えない。

### 1.2 本人の依頼と決定（確定。再検討しない）

**本人の言葉（2026-11-22、そのまま。R1_4_1_CONTRACT.md:1261-1266）**:
1. 12:2x「日、週の等倍とは、最小のサイズではなく、日、週の幅が、ちょうど画面両端にくるサイズのことです」（1.4.1 で済み）。
2. 12:3x「月と年は、横スクロールができる仕様にしてから、幅が両端にくる等倍を適用します」。
3. 12:4x「等倍は、そのように作った方が、ユーザーがいちいち指でピンチしなくてすみます」。
4. 13:0x「全て規定通りで進めてください」（開く大きさは今のまま、一度押すとその種類は次から等倍で開く、を含む。R1_4_1_CONTRACT.md:75-81・§16.3.4 の (c)）。

**この契約での読み方**: 2 の「横スクロールができる仕様」は、本人が 11/01 から使う「横スクロールで、期間の境界をまたいで手書き」（P-9 の B、`docs/M7_PLAN.md:239`・:758、`docs/B_DESIGN.md:76-79`）、つまり B-3（月）と B-2（年）の横つなぎを指す【推定。強い裏づけ】。「してから」は作る順（横につなげた後に等倍）と読む。だから月・年の横つなぎと幅の等倍は、同じ版で、横つなぎが入った種類にだけ等倍を広げる（0g-3・0g-26）。

**本人の答え（記録済み）**:
- P-9 = B（2026-11-01）。P-B11 = ア（月はこの形でよい）、P-B1 = ウ、P-B2 = 月（2026-11-01。`docs/M7_PLAN.md:759`、`docs/M7C_CONTRACT.md:189`）。
- P-B9（2026-11-06）: いちばん線の多いページ 1,016 本、今年の年のページ 152 本（いつも使う 1 台の数。`docs/M7_PLAN.md:760`）。
- P-B3・P-B5・P-B10 は 11/07「全部おすすめで」でア（見本と試作を見た後に変えられる。`docs/M7_PLAN.md:761`、`docs/M7C_CONTRACT.md:1292`）。
- P-B6 = イ（2026-11-18「上限ありが良いです」。`docs/B_DESIGN.md:917-925`、M7C_CONTRACT 0c-18 :303）。P-B5 の答えは「となりの週で止まる方が好みですが、週をまたいで手書きする時には、問題なく書ける必要があります」（`docs/M7C.md:889-899`）。
- P-B4・P-B7・P-B8 はおまかせ（`docs/M7_PLAN.md:762`）。

**送られてきた約束**:
- 月の 3 通り（P-B3）と年のそろえは、月・年の版の前に見本の写真で見てもらう（M7C_CONTRACT 0c-20 :305、:755・:757「答えが無くても進める」、本人向けの字 :78「月の並べ方（P-B3）は月の版（1.7）の見本で見てもらいます」、B_DESIGN §8.1）。→ 段 P（0g-43）。
- iPhone 横の年の上限は「1.8 で決め直す」（M7C_CONTRACT.md:708）。→ 0g-23。
- 段 1（見るだけの外側）は「1.8 で」（M7C_CONTRACT.md:690、`Layout/SpanLayout.swift:47-48` の注）。→ 0g-25。
- 月の帯の fixture は「1.7」（M7C_CONTRACT.md:650）。→ 0g-30。
- 古い 1 ページの道を消すかは「月・年がそろった後（1.8 の後）の版の契約で」（M7C_CONTRACT.md:128）。→ 0g-48。
- 設定の脚注の 2 つ目の文は本人が承認した固定の文で、本人が選んだときだけ替える（`tools/l10n/source/app-U.json:1836-1839` の comment、M7D_CONTRACT.md:142）。→ 0g-34。

**前からの決まり（R1_4_2_CONTRACT §1.2 と同じ）**:
- 進め方: 「予定に拘らず進める」（11/13）、「どんどん進めて」（11/20）、進められる物は前倒し（11/8）。途中で許可を取らず、既定で決めて記録し、最後にまとめて報告する。
- 本人の言葉が要るのは、確認ページ・提出・公開・main へまとめる の 4 つと、本人が選ぶこと（P-B3）と、実機の確かめだけ（§0.4）。
- **本人が自分の端末で確かめていない版は出さない**。Duo の行は「—」。
- Web 版は変えない（ほかの Pages は出さない約束）。公開の日に出すのは SUPPORT の 2 ページだけ。
- 本人の端末: iPad Pro 13・iPad Air 11・iPad mini・iPhone（Pro Max 級、18 Pro Max）。Duo は持っていない。本人の 11/28 の言葉「1.4.2に変更済みです。」は、お手元の端末が 1.4.2 になったと読む【推定】。

### 1.3 範囲

| # | 何をする | 決定 | 役 | 段 |
| --- | --- | --- | --- | --- |
| 1 | 版 1.4.3、CI の枝の配線（`r143*`）、J-4 の基準を 57ffd0f に、1.4.2 のテストの守りの表 | 0g-1・0g-29・0g-40・0g-41 | C | D0 |
| 2 | Kit: 月・年の下限（そろえ）、月の 3 通り、年の 31 行、月のずらしの y の補正、新しい KitChecks、互換の新しい fixture | 0g-10〜0g-12・0g-17・0g-21・0g-30 | K・C | D1a |
| 3 | 月を横の道へ: 種類の集合、道、セッションの下限、紙（凍結のキャンバスの作り直し 3 回目）、境目の線、見出しと月の札、焦点、今日、PDF、案内の札、月の等倍、写真モード、守られたテストの作り直し（月） | 0g-8・0g-9・0g-13〜0g-20・0g-26〜0g-28・0g-31〜0g-33 | S・P・Z・U | D1b |
| 4 | 見本の写真（月の 3 通り・月の等倍。年はそろえば） | 0g-43 | C・U・リード | P |
| 5 | 年を横の道へ: 行のそろえ、見出しと年の札、iPhone 横の上限、予定（終日だけ）、今日、PDF、案内の札、年の等倍、重さの測り、守られたテストの作り直し（年） | 0g-21〜0g-26・0g-28 | K・S・P・U | D1y |
| 6 | 変異・Duo の確かめ | §11.5 | 各役・C・U | D1c |
| 7 | 新しい文と訳・逆翻訳、設定の脚注、SUPPORT、新機能の文、審査メモ、GLOSSARY、文書 | 0g-34〜0g-38 | X・R・A・W・リード | D2 |
| 8 | 写真（J-4・新しい写真のジョブ・Duo・店の写真の撮り直し） | 0g-39〜0g-41 | C・U・リード | D1〜D3 |

### 1.4 範囲外（1.4.3 ではしない。0g-7）

- 段 1（焦点 ±1 より外を「見るだけ」にする）、年のための平行移動だけのずらし、照合の速い道、主スレッドの外での先読み、年の予定を焦点 ±1 から先に読むこと（B_DESIGN §2.4 の 4・9・10、§6.3）。測って記録だけする（0g-25）。
- 月・年を日付どおりに続ける形（P-B11 イ。本人はアを選んだ）、一覧より縮める形（P-B10 イ）、月の重なる日の薄い行を低くする形（P-B4。おまかせで今のまま）。
- 古い 1 ページの道を消すこと（0g-48）。
- 1.9 の重点欄（年の上の欄・月の重点）と、それを窓でそろえる行（0g-49）。
- 予定を指で隣の月・年へ運ぶこと（1.5・1.5.1）。
- ⌘0 などのショートカット、Web 版の月・年、CRA の見直し（§1.5）。
- App Store の写真のうち、週・日（02-week・03-day・01-week）と 00-span（週の横つなぎ）の撮り直し（0g-39）。

### 1.5 1.4.2 と 1.3 から送られたもの（0g-50）

| 残り（元） | 1.4.3 で | 役 | 確かめ |
| --- | --- | --- | --- |
| 1.4.2 の main の CI（run 46040646988）と日本の店の表示の記録（`docs/R1_4_2.md:14`・D5） | S0 で記録を確かめる（無ければ `docs/R1_4_2.md` の D5 に先に書く） | リード | 記録 |
| `StoreKitSessionTests.testExpiringMakesItReadOnly`（`StoreKitSessionTests.swift:576`）の揺れの見張り（`docs/R1_4_2.md:1136` の (4)） | 同じ形で 2 回続けて落ちたら本当の落ちとして直す。それまで記録だけ | リード | 単体テスト |
| iPhone の月の写真に Dynamic Island が出たり出なかったりする（`docs/R1_4_2.md:1139`） | J-4 の × が状態バーの帯の中だけなら、写真を撮り直す（揺れの回し直しに数えない） | C・リード | J-4 |
| palette-shots の `ok=` は辺しか見ない（`docs/R1_4_2.md:1096`） | 確認ページと見本のページに使う写真は、リードが目で手書きと札が写っていることを確かめる（新しい写真も同じ） | リード | 目 |
| 中国の 2027 年の祝日（python-holidays 0.109 にまだ無い、`docs/R1_4_2.md:23`。本人の前もっての了承 `docs/M7D.md:10`） | S0 で正式版に入ったかを見る。入っていれば、1.4.2 までと同じ道具で取り込み、D2 の commit に入れる（訳は無い）。無ければ記録だけ | リード・C | 祝日のテスト |
| CRA の見直し（`docs/M7_PLAN.md` §4「2027 年 12 月より前の版の契約で」）と、EU で 2026-12-09 より後に出す版の新しい製造物責任指令（M7C_CONTRACT §8.6 の行） | 1.4.3 はデータの扱いを変えないので、記録だけ。1.4.3 は 12/9 より後に出る見込みなので、S0 でリードが M7C_CONTRACT §8.6 を読み直し、要ることがあれば `docs/R1_4_3.md` に書いて T0 までに扱う【未確認】 | リード | — |
| `SpanGuard` の `.prototype`（凍結の 19 行目） | 残す（R1_4_1_CONTRACT §1.5） | — | — |
| B_DESIGN.md:344 の行番号（m7a の `YearLayoutEngine.swift:318-331`。今は :312-337） | 直さない（B_DESIGN は記録）。この契約の行番号を使う | — | — |

---

## 2. 構成とファイル所有

1 つのファイルの持ち主は 1 つの役。commit は `git add <ファイル名>` で、持ち主のファイルだけを入れる。役の表は §14.3。

```
project.yml                                          C  MARKETING_VERSION "1.4.3"（だけ）
.github/workflows/build.yml                          C  r143 の配線（§12.1）、TESTS_1_4_2・FIXTURES_1_4_3 の段、compat-span-143 の段、
                                                        速い道の組の名前、ui-tests の grep、新しい写真のジョブ span-shots-my と数の行
.github/workflows/ja-baseline.yml                    C  基準のファイルを 1.4.3 に（:124 の FILE=）
.github/workflows/duo.yml                            C  枝 r143-duo*、月と年も横の道で撮る（:899-911・:916 の case）
.github/workflows/store-shots.yml                    C  月と年を横の道で撮る、ja の組も月と年（§12.6）
tools/l10n/ja-baseline-ref-1.4.3.txt                 C  新しい。57ffd0f418d66dbf2e669a8313d773e2e97a09e2 の 1 行
tools/span/TESTS_1_4_2.sha256                        C  新しい（0g-29）
tools/span/FIXTURES_1_4_3.sha256                     C  新しい（0g-30）
tools/span/TESTS_1_3.sha256                          S  R0m・R0y・R0f の commit の 2 行だけ（ScreenPathsSpanTests・SettingsPageSectionTests。§8.5）
tools/span/TESTS_1_4_1.sha256                        S  R0m・R0y の commit の 4 行だけ（§8.5）
tools/compat10/DATA_1_1.sha256                       Z  1 行目だけ（R3 の commit。§8.4）
TegakiKit/Sources/Layout/SpanAlign.swift             K  Floors の新しい欄・MonthForm・monthFloors・yearFloors
TegakiKit/Sources/Layout/LayoutEvent.swift           K  MonthLayoutInput の下限の入力（既定値つき）
TegakiKit/Sources/Layout/MonthLayoutEngine.swift・MonthPageLayout.swift  K  下限の入力、MonthPageLayout.memoLine
TegakiKit/Sources/Layout/YearLayoutEngine.swift      K  YearLayoutInput.rowFloors
TegakiKit/Sources/Layout/PageLayout.swift            K  PageScroll.scrollDelta の月の窓の枝
TegakiKit/Sources/Layout/SpanLayout.swift            K  kind・真ん中のページ id を読む口（答えは変えない）
TegakiKit/Sources/KitChecks/SpanMonthYearChecks.swift（新しい）と KitChecks の入口   K
TegakiKit/Tests/Fixtures/compat-span-143/（新しい）・その作り手と読み手のテスト（新しい）   C
Sources/TegakiCalendar/Span/SpanKinds.swift          S  新しい。横につなぐ種類の集合（1 か所）
Sources/TegakiCalendar/Span/ScreenPaths.swift        S  joins・focus・today と上限の今日・paper(of:)・見出し・singlePageDemo・photoGuide
Sources/TegakiCalendar/Span/SpanSession.swift        S  layoutPages・relayoutPages（月・年の下限）、予定の終日だけ
Sources/TegakiCalendar/Views/CalendarRootScreen.swift  S  月・年の道のつなぎ（要る所だけ）
Sources/TegakiCalendar/Views/SpanGuideView.swift     S  joinedKinds・text（月・年の札）
Sources/TegakiCalendar/Views/ZoomReset.swift         S  followsFit（月・年）
Sources/TegakiCalendar/Calendar/EventStoreModel.swift  S  events(from:to:allDayOnly:)
Sources/TegakiCalendar/Support/ScreenshotMode.swift  S  新しい引数（既定値つき）、月・年のまたぐ見本
Sources/TegakiCalendar/Persistence/AppSettings.swift  S  注だけ（zoomFit の月・年）
Sources/TegakiCalendar/Paper/PaperSpan.swift         P  window(for:focus:)、月・年の窓
Sources/TegakiCalendar/Paper/PaperView.swift         P  drawSpan の月の境目の線
Sources/TegakiCalendar/Paper/MonthPaper.swift        P  区切りの線・罫線・点・「メモ」の札を memoLine から
Sources/TegakiCalendar/Views/StickyHeaderView.swift  P  spanMonthRow・spanYearRow（新しい）
Sources/TegakiCalendar/Export/PDFPageRenderer.swift  P  月の矩形に隣から入るメモの線
Sources/TegakiCalendar/Ink/InkCanvasView.swift       Z  paperSpan(for:focus:) の本体だけ（R3。§8.4）
tools/l10n/lint-skip.txt                             Z  R3 の手元の lint の間だけ外し、元に戻す（最後は同じ字）
Tests/TegakiCalendarTests/（新しい）・Tests/TegakiCalendarUITests/（新しい）   各役  §11
Tests/TegakiCalendarTests/ScreenPathsSpanTests.swift・SettingsPageSectionTests.swift   S  R0m・R0y・R0f の行だけ（§8.5）
Tests/TegakiCalendarTests/ZoomResetTargetTests.swift・ZoomFitWiringTests.swift   S  R0m・R0y の行だけ
Tests/TegakiCalendarTests/InkCanvasZoomResetTests.swift   Z  R0m・R0y の行だけ
Tests/TegakiCalendarUITests/ZoomResetUITests.swift   U  R0y の行だけ
Tests/TegakiCalendarTests/AppSettingsTests.swift     S  :302-310 を読み替え（守られていない）
tools/l10n/source/app-U.json・app-P.json（comment）・translations/*.json（9）  X  §13.1（D1b・D1y の 4 キーの ja と仮の訳だけは S。§13.1）
Sources/TegakiCalendar/Resources/Localizable.xcstrings  X  build.py が作り直す（同じ commit）
docs/i18n/GLOSSARY.md                                X  §7「1.4.3 の語」と §5 の等倍の定義
docs/i18n/REVIEW.md・docs/i18n/back/*.json           R  REVIEW の新しい節（19・20）と、元を見ない逆翻訳
docs/store/*/whatsnew.txt・review-note.txt・README.md の表の行・PROPOSALS_1_4_3.md  A  §13.3・§13.4
docs/SUPPORT.md・SUPPORT.en.md                       W  §13.5
docs/R1_4_3.md・docs/M7_PLAN.md・docs/DESIGN.md・README.md・docs/B_DESIGN.md の頭の注  リード  記録・§13.6
```

- **変えないもの**: 凍結の表 `tools/compat10/DATA_1_1.sha256` の 2〜20 行目（§8.4）、`tools/span/TESTS_1_2_3.sha256`（8 行）・`FIXTURES_1_3.sha256`（37 行）の全部、`TESTS_1_3` と `TESTS_1_4_1` の §8.5 に名前の無い行、`tools/l10n/lint-skip.txt` の 20 件（最後の字）、`tools/duo/idiom-allow.txt`、compat10・compat11・compat-span の fixture と 2 つの `EXPECTED_MIN`（225・599）、`tools/l10n/ja-baseline.tsv`（J-1）、`ja-baseline-ref*.txt` の今のファイル（記録として残す）、TegakiKit の `InkModel` の 9 ファイル、`SpanComposer`・`SpanGuard`・`InkLedger`・`SyncEngine`（どれも種類を見ない。§3.1）。
- **画面の字で守られた所**（ピン留めのテストがソースの字を読む。§8.6）は、平らにした形で 1 字も変えない。
- **役 L（台帳）と Y（同期）は作らない**。保存・merge・同期・墓標・台帳の行に触れる直しが要ると分かったら止めて、契約を直す。

### 2.1 接点（宣言。新しい引数には既定値を付け、省けば 1.4.2 と同じ動き・同じ答え）

```swift
// Span/SpanKinds.swift（役 S、新しい）
enum SpanKinds {
    /// 1.4.3: 設定がオンのとき横につなぐ種類。落とし所（0g-3）では .year をここから外す（ここだけを替える）。
    static let joined: Set<PageKind> = [.week, .day, .month, .year]
    /// 並びのある形（SpanGuide.joinedKinds、写真の順）。週・日・月・年の順で、joined に入る物だけ。
    static var ordered: [PageKind] { [PageKind.week, .day, .month, .year].filter { joined.contains($0) } }
}

// TegakiKit/Sources/Layout/SpanAlign.swift（役 K）
public enum MonthForm: Sendable, Equatable { case memo /* ア */, rows /* イ */, none /* ウ */ }
public static let monthForm: MonthForm = .memo        // P-B3。本人がイ・ウを選んだら、ここだけを替える（0g-10）
// Floors に既定値つきで足す。Floors.none == Floors(dayExtra: 0, weekExtra: 0) は今のまま（凍結の SpanChecks.swift:628-631）。
//   public var monthMemoLine: CGFloat = 0        // ア: 窓の区切りの線の y（窓のページの memo.minY の最大）。0 は下限なし
//   public var monthBottom: CGFloat = 0          // ア・イ: 窓の紙の下端（メモの帯の下をそろえる）。0 は下限なし
//   public var monthRows: [CGFloat] = []         // イ: 6 行の高さの下限。空は下限なし
//   public var yearRows: [CGFloat] = []          // 31 行の高さの下限。空は下限なし
//   floor(for: .month / .year) は今のまま 0 を返す（凍結の SpanChecks.swift:628-631。月・年は新しい関数で読む）。
public struct MonthNatural: Equatable, Sendable { public var rows: [CGFloat]; public var memoTop: CGFloat; public var bottom: CGFloat }
public static func monthFloors(previous: Floors, naturals: [MonthNatural], form: MonthForm, change: Change) -> Floors
public static func yearFloors(previous: Floors, naturalRows: [[CGFloat]], change: Change) -> Floors

// TegakiKit/Sources/Layout/LayoutEvent.swift の MonthLayoutInput（役 K）に既定値つきで足す（:44-61 の形）
//   var memoLineFloor: CGFloat = 0     // 区切りの線の y の下限（ア）。memo の矩形は動かさない（§4.1）
//   var bottomFloor: CGFloat = 0       // 紙の下端の下限（memo の高さを伸ばす）
//   var rowFloors: [CGFloat] = []      // 6 行の高さの下限（イ）
// MonthPageLayout（役 K）に足す:
//   public var memoLine: CGFloat       // 区切りの線・罫線・点・「メモ」の札の y。= max(memo.minY, memoLineFloor)。下限なしなら memo.minY

// TegakiKit/Sources/Layout/YearLayoutEngine.swift の YearLayoutInput（役 K。:6-26）に既定値つきで足す
//   var rowFloors: [CGFloat] = []      // 31 行の高さの下限。row の高さ = max(今の高さ, rowFloors[r])

// TegakiKit/Sources/Layout/PageLayout.swift（役 K）
//   PageScroll.scrollDelta(old:new:topVisibleY:)（:168-172）: old と new が月の SpanLayout で 2 ページ以上なら、old の真ん中の
//   ページを new の中で同じ id で探し、そのページの band と bandTop で比べる（無ければ 0）。週・日・年と窓 1 ページは今の答えのまま。

// Paper/PaperSpan.swift（役 P）
//   static func window(for layout: SpanLayout, focus: Int) -> PaperSpan?
//     週・日: 今の init?(layout:bands:focus:) と同じ答え（帯は各ページの allDayBand。InkCanvasView.swift:2625-2637 の今の中身を移す）。
//     月・年: ページの紙だけ、bands は空。
//   init?(pages:bands:focus:)（:37-44）: 月・年は bands が空のときだけ通す。週・日の条件は今のまま。single（:65-68）は今のまま（月・年は nil）。

// Ink/InkCanvasView.swift（役 Z、R3。§8.4）
//   static func paperSpan(for layout: SpanLayout, focus: Int) -> PaperSpan? { PaperSpan.window(for: layout, focus: focus) }

// Views/StickyHeaderView.swift（役 P）
//   body（:46-64）の span.isJoined の switch を種類ごとに: .day → spanDayRow、.week → spanWeekRow、.month → spanMonthRow（新しい）、
//   .year → spanYearRow（新しい）。新しい 2 つの行の高さは、1 ページの monthRow（:72）・yearRow（:277）と同じ。

// Calendar/EventStoreModel.swift（役 S）
//   func events(from start: DayKey, to end: DayKey, allDayOnly: Bool = false) -> [LayoutEvent]
//   （:163-174。allDayOnly を EventKitService.events(…, allDayOnly:, keepingEarlier: true) へ渡す。SpanSession は年で true を渡す）

// Views/ZoomReset.swift（役 S）
//   static func followsFit(_ kind: PageKind) -> Bool { kind == .week || kind == .day || SpanKinds.joined.contains(kind) }
//   target(_:bounds:) は今の式のまま（followsFit なら bounds.clamped(bounds.fit)）。

// Support/ScreenshotMode.swift（役 S）。Config に既定値つきで足す（今までの引数の Config は同じ値）
//   var spanCrossingAll: Bool = false   // --screenshot-span-crossing all: 月のメモの帯と年の 12 月→1 月をまたぐ見本の線を足す
//   var monthTall: Bool = false         // --screenshot-month-tall: 焦点の右どなりの月の行を高くする見本（予定と格子の手書き）
//   r143-alt の枝だけ（取り込まない。DEBUG）: --screenshot-month-form a|i|u（SpanAlign.monthForm を写真の中だけ替える）
```

---

## 3. しくみ（月と年に開く）

### 3.1 今のしくみと、開く所（0g-8）

- **種類を見ない所はそのまま使う**【事実】: `SpanPlan`（4 種の番号・id・原点・半開区間・ヒステリシス 6 %・R・ずらし量・はじき・D18 の上限・本数の見積もり。`TegakiKit/Sources/Layout/SpanPlan.swift:114`・:127-143・:167-180・:207-258・:315-356）、`SpanName`（`m1-YYYY-MM|`・`y-YYYY|` を読む、`Layout/SpanName.swift:78-103`）、`SpanGuard.isWriteForm`（`m1-`・`y-` を通す、`InkModel/SpanGuard.swift:56-67`）、`SpanComposer`、`InkLedger`（`ownerId` :218、journal :225、`applyCanvasChange(allowRemovals:)` :355-、`needsMoreRoom` は strip してから :463-465、`pruneHistory` :541）、`SyncEngine` の `pagesOpened` と `onRemoteDelete`、`SpanSession` の窓・先読み・受け箱・安全網・epoch・保存の順（D8）・iCloud の更新と削除、`SpanLayout.drop`・`inkCell`（中心の x の半開区間、`Layout/SpanLayout.swift:154-173`）、`joinedTap`（`ScreenPaths.swift:1286-1292`）、`joinedDoubleTap`（`CalendarRootScreen.swift:3367`）、`eventTarget`、`windowShift`・`flingTarget`（幅 1,400 で正しい）。`SpanSession.pageLayout`（`Span/SpanSession.swift:660-685`）には月と年の枝がもうある。凍結の `SpanSessionTests` は月と年のセッションを開いて compat-span の形を作っている（`SpanSessionTests.swift:439-458`）。
- **月と年で止まっている所**（ここを開く。1 つでも漏れると「月は開くが紙が無い」「札が出ない」「PDF が空」になる）:
  1. 道を決める所 `ScreenPaths.joins`（`Span/ScreenPaths.swift:262-265`）。→ §3.2。
  2. `SpanSession.layoutPages` の下限（:642-658。:650-651 が `case .month, .year: break`）と `relayoutPages`（:687-696。`.extra` の下端だけを見る）。→ §3.3。
  3. `SpanAlign.Floors`（`TegakiKit/Sources/Layout/SpanAlign.swift:16-36`）と、MonthLayoutInput・YearLayoutInput の下限の入力。→ §3.3・§4・§5。
  4. 凍結の `InkCanvasView.paperSpan`（`Ink/InkCanvasView.swift:2625-2637`。週・日以外で nil）と `PaperSpan`（`Paper/PaperSpan.swift:37-61`）。→ §3.4。
  5. 見出し `makeHeadingSpan`（`ScreenPaths.swift:861-877`）と `StickyHeaderView`（:46-64）。→ §3.8。
  6. ずらしの後の y の補正（`SpanLayout.band/bandTop`、`Layout/SpanLayout.swift:221-229`、`PageScroll.scrollDelta`、`InkCanvasView.swift:3097`）。→ §3.5。
  7. 焦点の持ち越し `ScreenPaths.focus`（:1115-1118）。→ §3.6。
  8. 今日 `ScreenPaths.today`・`todayRect`・`atCappedOverview`・`cappedOpeningY`・`cappedTodayRect`（:963-1087）。→ §3.7。
  9. PDF `ScreenPaths.paper(of:)`（:1171-1175）と `PDFPageRenderer` の月の枝（`Export/PDFPageRenderer.swift:71-77`）。→ §4.7・§5.6。
  10. 等倍 `ZoomReset`（`Views/ZoomReset.swift:16-29`）。→ §6。
  11. 案内 `SpanGuide`（`Views/SpanGuideView.swift:22-43`）。→ §7.3。
  12. 写真モード `crossingSamples`（`Support/ScreenshotMode.swift:1036-1062`）と `singlePageDemo`（`ScreenPaths.swift:465-470`）。→ §12.4。
  13. CI の `week|day` の分かれ（`duo.yml:899-911`、`store-shots.yml:425-435`）。→ §12。
  14. 予定の読み方 `EventStoreModel.events(from:to:)`（`Calendar/EventStoreModel.swift:163-174`。終日だけの口が無い）。→ §5.5。
- **種類の集合は 1 か所**: 新しい `SpanKinds.joined`（§2.1）。`joins`・`SpanGuide.joinedKinds`・`SpanGuide.text`・`ZoomReset.followsFit`・`PaperSpan.window`（月・年の枝）・`ScreenPaths.paper(of:)`・`singlePageDemo`・見出しの行は、どれもここから引く（種類ごとの `case` に、集合に無い種類で何もしない形を書く）。CI の `case` は shell なので集合を読めない。C は CI の各所に「SpanKinds.joined と同じ」の注を書き、落とし所（0g-3）のときは同じ commit で直す。
- 理由: 月だけ先に出す落とし所（0g-3）を、1 か所の替えで取れるようにする。

### 3.2 道を決める所・設定オフ・段 2・写真モード（0g-9）

- `ScreenPaths.joins`（`ScreenPaths.swift:262-265`）の guard を `SpanKinds.joined.contains(kind), !fallenBack.contains(kind)` にする。後ろ（写真モードでは `screenshotSpan && !singlePage`、ふだんは `setting`）は今のまま。注の「Month and year are always one page in 1.3」を直す。
- **設定オフ**: 今のまま 1 ページの道（`OnePageSession`、:405-424）。鍵は `AppSettings.pageSpanKey "page.span"`（`Persistence/AppSettings.swift:119-122`）で、4 種で 1 つ（P-B7 おまかせ）。オンにしたとき `fallenBack` を空にし（:694-696）、画面が開き直す（`CalendarRootScreen.swift:3301`）のも今のまま。
- **段 2**: 窓の線の合計が上限（D18。iPad 20,000・iPhone 12,000、`SpanPlan.swift:131-136`）を超えたら、その種類だけその回の起動のあいだ 1 ページの道に戻し、1 回だけ知らせる（`ScreenPaths.fallBack` :685-690、止まったときの判断 :1103-1108、`span.stageTwo.notice`）。種類を見ないので、月・年でもそのまま働く。
- **写真モード**: 今のまま、`--screenshot-span on` のときだけ横の道（`ScreenshotMode.swift:349-351`）。**引数を付けない今の月・年の写真（J-4・blank-paper・l10n-shots・店の JPEG の元）は、1 ページの道のままで 1 画素も変わらない**（§12.2）。
- 2 本の道は同時に同じページを開かない（K-3。切り替えは全部保存してから開き直す）。今のまま。

### 3.3 セッションの下限（月・年。0g-12）

- `SpanSession.layoutPages`（:642-658）の `case .month, .year: break` を開く:
  1. 窓の各ページを、まず**下限なし**で並べる（今の `pageLayout(index:pageId:inkBottoms:)`。自然な形）。
  2. その答えから自然な数を取る。月は `MonthNatural`（6 行の高さ・`memo.minY`・紙の下端 = `memo.minY` ＋ `PaperGrowth.tailHeight`）、年は 31 行の高さ（12 か月の最大、`YearLayoutEngine.swift:324-336`）。
  3. `SpanAlign.monthFloors(previous:naturals:form: SpanAlign.monthForm, change:)` または `yearFloors(previous:naturalRows:change:)` で下限を決める（純粋。§4・§5）。
  4. 下限ありでもう一度並べる（MonthLayoutInput の `memoLineFloor`・`bottomFloor`・`rowFloors`、YearLayoutInput の `rowFloors`）。
  - 2 回並べる費用は小さい【推定】（年の 1 ページは 372 マス。窓 7 ページで 2 回）。D1y の重さの測り（§3.10）で時間をログに出す。
- **下限の上げ下げ**（週・日の D16 と同じ規則。B_DESIGN §3.1、`SpanAlign.Change`）: `.shift`（窓のずらし）では下げない（見えている行が縮まない）。`.inkShrank`（消して自然な高さが下がった）と `.redecide`（ずらしの後に読んだページ・予定・30 秒の見直し）では、窓の自然な数の最大まで下げる。`.inkGrew` は上げるだけ。開き直し・回転・ピンチの終わりでも決め直す（今と同じ）。
- `relayoutPages`（:687-696）を月・年に広げる: 月はメモ欄の手書き（下端）と格子の手書き（行の高さ → `memo.minY`）、年は格子の手書き（行の高さ）で、窓の自然な数を出し直し、前の下限と比べて `.inkGrew` か `.inkShrank` を決める。週・日の道（`.extra` の下端）は今の字のまま。
  - キャンバスが `onInkBoundsChanged` を月・年の格子のマスでも知らせるか（1 ページの月で行が手書きで伸びる道、`growsWithInk`・`needsMoreRoom` は strip した名前で見る）を、S が D1b の最初に確かめて記録する【未確認】。知らせない形なら、凍結のキャンバスに触れずに、セッションの側（受け箱を空にした後・止まったとき）で見直す形にする。
- キャンバスの軽い道（`SpanLayout.onlyTailHeightChanged`、`InkCanvasView.swift:3070`）: 月でメモ欄の下だけが伸びたときは軽い道（今の 1 ページの月と同じ）。区切りの線の y（`memoLine`）や行が動いたら重い道（絵を作り直す）。答えは KitChecks で固める（§11.1）。
- **K-4**: そろえで動くのはマスの位置と大きさだけで、マスの意味（左上からの相対座標）は変えない。月のアでは `memo` の矩形の原点も動かない（§4.1）。

### 3.4 紙（凍結のキャンバスの作り直し 3 回目。0g-27）

- 今は、凍結の `InkCanvasView.paperSpan(for:focus:)`（:2625-2637）が週・日以外で nil を返し、`updatePaperSpan`（:3140-3147）が `paperView.span = nil` にして、1 ページの紙が x 0 に 1 枚だけ描かれる【事実】。だから横の道の月・年に紙を出すには、凍結のファイルに触れるしかない。
- **R3**: `paperSpan(for:focus:)` の本体を、凍結の外の `PaperSpan.window(for:focus:)` を呼ぶ 1 行にする（今の中身は `PaperSpan.window` の週・日の枝へ移す）。署名・`static`・呼ぶ所は変えない。これでキャンバスは「どの種類に紙があるか」を持たなくなり、後の種類（1.9 の欄など）で凍結に触れずに済む。手順は §8.4。
- `PaperSpan`（P）: `window(for:focus:)` を足す。月・年は `bands` が空の窓（`init?(pages:bands:focus:)` の guard を、月・年なら bands が空のときだけ通す形に）。`single`（:65-68）は今のまま月・年で nil（凍結の `PaperSpanTests.swift:265-266` が「年は 1 ページ」の意味で見ている。1 ページの道の月・年は終日帯を持たないので、この答えは 1.4.3 でも正しい）。`days(of:)`（:104-110）も今のまま月・年は空（終日帯を作らない、§3.8）。注の「Only weeks and days are joined in 1.3」を直す。
- `PaperView.drawSpan`（`Paper/PaperView.swift:397-421`）には `.month` と `.year` の枝がもうある【事実】。月の境目の線（§4.3）を足すだけ。窓 1 ページは今のまま切りも動かしもしない（凍結の画素のテスト）。
- `bandOverview`（`InkCanvasView.swift:2642-2645`。真ん中のページの `ZoomPolicy.overviewSize`）は変えない。月はアの作りで `memo.minY` が動かないので、一覧の倍率は自分の格子の高さのまま（§4.6）。年は窓でそろえた紙の高さ（B_DESIGN §3.1。§5.4）。

### 3.5 ずらしの後の y の補正（0g-17）

- 今は、ずらしの後に `PageScroll.scrollDelta(old: oldBand, new: newBand, topVisibleY:)`（`TegakiKit/Sources/Layout/PageLayout.swift:168-172`、呼ぶ所 `InkCanvasView.swift:3097`）が、`SpanLayout.band(atY:)` と `bandTop`（`Layout/SpanLayout.swift:221-229`。「真ん中のページ」の答え）で比べる【事実】。週・日・年は行を共有するので正しい。**月は行がページごとに違う**ので、古い窓の真ん中の月の row:k と、新しい窓の真ん中の別の月の row:k を比べ、見えている格子とメモ欄が縦に跳ぶ【推定】。
- 直す所は凍結の外の `PageScroll.scrollDelta` だけ（K）: old と new が月の `SpanLayout` で 2 ページ以上なら、old の真ん中のページの id を new の中で探し、そのページ自身の `band(atY:)` と `bandTop` で差を出す（見つからなければ 0）。下限が変わらないずらしでは 0。区切りの線が下がったときは、メモ欄を見ていれば、その分だけ追う。
- `SpanLayout.band(atY:)`・`bandTop` の答えは変えない（凍結の `SpanChecks.swift:816-820`「窓 1 ページはそのページの答え」と :952「週の窓で band(atY:100) == .grid」）。週・日・年の `scrollDelta` の答えも、今と 1 つも違わない（KitChecks で固める）。
- 凍結の `InkCanvasView` の行は変えない。

### 3.6 焦点の持ち越し（0g-18）

- 今の `ScreenPaths.focus(_:kind:weekStart:movedTo:)`（:1115-1118）は「焦点 ＋（新しいページの最初の日 − 今の表示範囲の最初の日）」【事実】。週と日では正しい。月は表示範囲が 42 日の格子の始まりなので誤る【計算】: 10/31 から 11 月へ動くと 12/4 に、11/30 から 10 月へ動くと 11/5 になる（同じ月のまま）。年もうるう年で誤る（2028-12-31 から 2027 年へ動くと 2028-01-01）。
- 新しい規則（S）:
  - 週・日: 今の式のまま（凍結の `ScreenPathsSpanTests` の週・日の答えを守る）。
  - 月: 行き先は `pageFirstDay` の年月。日は焦点と同じ日、その月に無ければ月末（例 1/31 → 2/28）。
  - 年: 行き先は `pageFirstDay` の年。月日は同じ、2/29 はうるう年でなければ 2/28。
- 呼ぶ所: `stopped`（:1095）と `CalendarRootScreen.spanFocusMoved`（:3292-3296）。題名・`remember`・種類の切り替え（月 → 週で開く週）・書き出しの題が、この焦点を読む。

### 3.7 今日（0g-19）

- 1.1.1 の決まり「月と年は今日のマスを画面に出す」（1 ページの道の `goToday`、`CalendarRootScreen.swift:1909-1933`、`PageNavigation.todayRect` :193-200）を、横の道の月・年にも広げる。
- `ScreenPaths.today`（:963-991）: 今日のページが窓の中なら滑って行き、**今日のマスが画面に入るように縦も合わせる**（今日のマスがもう見えていれば縦は動かさない）。遠ければ今と同じく開き直す。月・年の `todayRect`（:1020-1035。今は「ページの幅全部と initialScrollY」）は、今日のマスの矩形（`PageNavigation.todayRect` を局所座標で）にする。週・日の答えは今のまま。
- **上限ありの年（iPhone 横、0g-23）**: `atCappedOverview`・`cappedOpeningY`・`cappedTodayRect`（:1043-1087）を年にも広げる。焦点が今日の年なら、開く y は今日の行の 2 行上（`PageNavigation.initialScrollY` の年の式、`PageNavigation.swift:170-180` と同じ）。「今日」で今日の年が焦点なら、今日の行が見えていなければ縦だけ動く（週の「今の 1 時間前」と同じ形、M7C_CONTRACT §3.6）。
- 倍率は変えない（凍結の `ScreenPathsSpanTests.swift:1228-1250` のピン留め）。

### 3.8 見出しと終日帯（0g-20）

- **終日帯は月・年では作らない**（1 ページの道でも無い）。`makeHeadingSpan`（:861-877）は、月・年では `lanes.bands(...)` を呼ばない。今のままだと `AllDayBandEngine.pages`（`TegakiKit/Sources/Layout/AllDayBand.swift:179-190`）が月・年の日を「7 列の週」として刻み、答えが誤るうえに年は 365 日 × 窓で重い【事実】。
- 見出しは窓のページを原点つきで並べる（週・日と同じ考え）。`StickyHeaderView` の `span.isJoined` の分かれ（:47-53。今は日か「それ以外は週」の 2 通り）を種類ごとにし、`spanMonthRow`（各ページの曜日の行、7 列 × 200 lu、と月の札、§4.4）と `spanYearRow`（各ページの日付の列 56 lu と 12 か月の名前 112 lu ずつ、と年の札、§5.3）を足す（P）。
- **新しい 2 つの行の高さは、1 ページの道の `monthRow`（:72）・`yearRow`（:277）と同じ**。紙の領域（`toolbar: paperArea=`）と開く大きさ（open）が、1 ページの道と横の道で同じになる。
- `paths.heading?.viewport` が月・年でも来るようになり、`shownViewport`（`CalendarRootScreen.swift:641-644`）が `joinedInitialViewport` のままにならない。ずらしと同じターンで見出しへ渡す（1.3 の版つきの viewport）。
- 年の見出しの月の名前は、今と同じくボタン（押すとその月のページ、`CalendarRootScreen.swift:780`）。名前の字は今の `PaperWords.yearColumnTitles`（列の幅で縮む）。

### 3.9 予定の読み込み

- 窓のページごとに読む今の形（`SpanSession.readSlot` :513-518 → `loadEvents` :595-598、4 年未満に切る `eventQueries` :578-587）はそのまま。年は 1 年分を 1 回で読む。
- 年だけ、終日の予定だけを読む（§5.5）。月は今のまま（チップに時刻の予定も出る）。
- `reloadEvents`（:602-608。カレンダーが変わると窓の全部を読む）と、主スレッドで 1 ページずつ `Task.yield` する先読み（:524-547）は変えない（0g-25）。

### 3.10 重さと線の上限（0g-25）

- 窓の大きさ【計算。`SpanPlan.referenceViewport` :265-286 と `ZoomPolicy.baseSize`】: 月は iPad の縦・横と iPhone の縦で 5 ページ、iPhone の横 7。年は iPad の縦 5、iPad の横 7、iPhone の縦 5、iPhone の横 7（上限 3）。凍結の KitChecks（`SpanChecks.swift:354-361`、`OverviewCapChecks.swift:24-42`）がこの表を固めている。
- 本人の数（P-B9）なら、年の窓 7 ページでも約 1,100 本、いちばん多いページ 1,016 本が月でも 7 ページで約 7,100 本で、上限（iPad 20,000・iPhone 12,000）より下【計算】。
- **作らない物**（B_DESIGN §6.3 で 1.6・1.8 の段だった物）: 段 1（見るだけ。`SpanLayout.viewOnly` は空のまま、`Layout/SpanLayout.swift:48`・:159）、平行移動だけのずらし（今はずらすたびに `setWindowDrawing(ledger.relayout(newBand))` で絵を全部作り直す、`InkCanvasView.swift:3082`）、照合の速い道、主スレッドの外での先読み、年の予定を焦点 ±1 から先に読むこと。理由: 本人の数では要らない。段 2 が上限の安全弁として働く。凍結のキャンバスに触れる範囲を R3 の 1 関数に抑える。**黙って落とさないよう、ここに書いて記録し、後の版の契約で測った値を見て決める。**
- **測る**（S・Z。新しい単体テスト `SpanWeightLogTests`、合否には数えない）: 年の窓 7 ページで 1 ページ 152 本・1,000 本・2,800 本（合計 19,600 本。iPad の上限の下）の 3 つの形で、セッションの compose と relayout、キャンバスのずらし 1 回（絵の作り直しを含む）の時間を `span weight: kind=year pages=7 strokes=<n> compose=<ms> shift=<ms>` の形でログに出す。月の窓 5 ページ × 1,016 本も同じ。`docs/R1_4_3.md` に書く。19,600 本でずらし 1 回が CI で 1,000 ms を超えたら、リードが見直す（段 2 の上限を下げるかを含めて記録する）。

---

## 4. 月の形

### 4.1 3 通りと既定（0g-10・0g-11）

- 3 通りを TegakiKit の 1 つの値 `SpanAlign.monthForm`（§2.1）で切り替える。**既定はア**（P-B3 の 11/07 の既定）。本人が段 P の写真でイ・ウを選んだら、この値だけを替える（作り直しにしない）。答えの期限は V を始める時（12/8 めど）。
  - **ア メモ欄だけそろえる**: 区切りの線から下の柄（区切りの線・罫線・ドットの点・「メモ」の札）の y を、窓のページの `memo.minY` の最大にそろえる（`memoLineFloor`）。格子の行はそろえない。メモの帯の下端もそろえる（`bottomFloor`）。
  - **イ 行もそろえる**: 6 行の高さを、行ごとに窓の最大にそろえる（`rowFloors`）。格子の高さがそろうので、区切りの線も自然にそろう。下端もそろえる。
  - **ウ そろえない**: 下限なし。各月の表をそのまま並べる（区切りの線と下端は月ごとにずれる。短い月の下は紙の色の外）。
- **アの作り（B_DESIGN §3.4 と違えた所）**: B_DESIGN は「格子が短い月は最後の行をのばす（上限は行の 1,200 lu）」と書く。この契約では**最後の行をのばさず、`memo` の矩形の原点（`memo.minY`）は動かさない**。短い月では、格子の下端（自分の `memo.minY`）からそろえた区切りの線（`memoLine`）までが、線の無い白い紙になる。そこは `memo` のマスの一部で、書いた線はメモ欄の線として保存される。理由:
  1. 多くの月では最後の行（6 行目）は全部が次の月の薄い日で、`outTint` で塗られる（`Paper/MonthPaper.swift:33-34`）。のばすと大きな灰色の帯になり、そこに書いた線は「メモ」ではなく薄い日のマスに保存され、隣の表の同じ日にも出ない（調べ役の地図の危険）。
  2. 行の上限 1,200 lu（`PaperSpec.monthRowMax`、`TegakiKit/Sources/Layout/PaperSpec.swift:15`）を超える差でもそろえられる（上限でそろわない時の形を決めずに済む）。
  3. `memo.minY` が動かないので、月の一覧の倍率（`ZoomPolicy.overviewSize` が `memo.minY` を読む、`ZoomPolicy.swift:79-82`）は自分の格子の高さのまま（B_DESIGN §3.1 の規則を、新しい欄なしで満たす。§4.6）。
  4. 古い端末と設定オフ（1 ページの道）では、白い紙に書いた線は自分のメモ欄の上の方（区切りの線のすぐ下）に出る（格子の下端からの位置は同じ）。データの意味は変わらない（K-4）。横の道の PDF は画面のまま（§4.7）。
  5. 下限が 0 なら `memoLine == memo.minY` で、1 ページの道の画素は 1.4.2 と同じ。
  - B_DESIGN §0 の本人向けの字「月の最後の行がのびることがあります」とは見え方が違うので、§0.1 で「格子と区切りの線の間に白い紙が入ります（メモ欄の一部で、書けます）」と書き、段 P の写真で見せる。
- 月の重なる日・今日の印・薄い日は今のまま（§4.5）。

### 4.2 メモの帯（ア・イ）

- 区切りの線（`lineStrong`）・罫線（50 lu ごと、左右 20 lu 内側）・ドット方眼の点（x 30…1,380、28 列）・無地は、`MonthPaper.swift:65-106` と `Paper/MemoPaperStyle.swift:56-80` の今の描き方のまま、起点の y を `memo.minY` から `layout.memoLine` に替える（P）。罫線と点の行は区切りの線から数えるので、窓の全部のページで同じ y に並ぶ。境目で点の列は 1,380 → 1,430 と 50 lu で続き、罫線は 40 lu あく（1.4.2 の約束「横につながったページの境目でも、点の間隔はそろいます」、R1_4_2_CONTRACT.md:38、`MemoPaperStyle.swift:63-67` の注）。
- 「メモ」の札は `(20, memoLine + 6)`（今は `memo.minY + 6`、`MonthPaper.swift:99-105`）。
- `memo.minY` から `memoLine` までは、紙の色だけ（線も点も描かない）。
- 下端: メモの帯の下端を窓の最大にそろえる（`bottomFloor` で `memo` の高さを伸ばす。今の `PaperGrowth.tailHeight` = max(6,000, 下端 ＋ 50)、`TegakiKit/Sources/Layout/PaperGrowth.swift:32-35`）。短い月の下も白紙が続き、書けばその月の欄が伸びる。「メモ欄はここまでです」はページごと（今のまま）。
- 1 つの月の行が手書きで伸びると、窓の全部のページの区切りの線が下がる（§3.3 の `.inkGrew`）。ずらしでは下げない。消して縮めば下げる。
- **ウ**: 起点は各ページの `memo.minY` のまま（1 ページの描き方そのまま）。点の列は境目で続くが、行はずれる。

### 4.3 月の境目の線（0g-13）

- 今の格子の縦の線は列 1〜6 の内側だけで、x = 0 と 1,400 には線が無い（`MonthPaper.swift:47-60`）【事実】。並べると 2 つの表がくっついて見える。
- 横の道の月だけ、隣り合うページの境目に濃い縦の線を引く（`PaperView.drawSpan` の後で、P。色は `lineStrong`、太さは画面で 2 pt 相当。形は P が決めて記録）。y は格子の上端から、左右 2 ページの区切りの線の y の小さい方まで（アとイでは同じ値。ウでは格子の短い方の月の格子の下端まで）。**メモの帯には引かない**（帯が 1 本に見えるように）。
- 1 ページの道と窓 1 ページには引かない（画素は 1.4.2 と同じ）。
- 年には引かない（日付の列が境目の印になる）。

### 4.4 月の札（0g-14）

- `spanMonthRow`（P）で、曜日の行の各表の左端（その表の最初の曜日のマスの左上）に、小さな札で月の名前を出す。字は題名の月の名前と同じ作り（`PageNavigation.title` の月の部分の作り方。新しい文を作らない）。
- 左へ出ていった表の札は、その表の見出しが画面に残っている間、画面の左端に貼り付く。次の表の札が来たら押し出される（ふつうの「貼り付く見出し」）。
- 狭いとき: 札と曜日の字が両方入らなければ、数字だけ（「11」）、それも入らなければ出さない（題名に月があるため。週の見出しの時刻の列の札が入らないときに出さないのと同じ考え、`StickyHeaderView.swift:384-397`）。iPhone 縦の一覧では 1 列が約 57 pt【計算】で、曜日の字とぶつかりうる。言葉ごとの長さ（en Nov・de・fr）は単体テストで測る（§11.2）。
- **1 ページの道の見出しには出さない**（J-4 の月の写真と店の JPEG の元を 1 画素も変えないため。1 ページでは題名が月を言う）。
- 見出しの高さは今の曜日の行のまま（§3.8）。

### 4.5 重なる日・今日の印・薄い日（0g-15）

- 月の表はいつも 6 行 42 日（`MonthLayoutEngine.swift:61`、`MonthLayout.swift:26-30`）。隣の表と 7 日か 14 日重なる（例 月曜始まりの 2026 年: 10 月の表 9/28〜11/8、11 月の表 10/26〜12/6）【事実】。マスの鍵は日付なので、`m1-2026-10` の 2026-11-01 と `m1-2026-11` の 2026-11-01 は別ページの別マス。
- 薄い日は両方の表に今のまま出す（P-B4 おまかせ）。今日の印も薄い方に付く（`MonthLayoutEngine.swift:102`、塗りの順は 今日 > 月の外 > 土日祝、`MonthPaper.swift:26-45`）。1 画面に今日の印が 2 つ出ることがある（例 11/30 は 11 月の表と 12 月の表の薄い日）。
- 薄い日に書いた線は、その表のマスに保存され、隣の表の同じ日には出ない。§0.1 と SUPPORT（§13.5）で知らせる。

### 4.6 月の一覧の倍率（0g-16）

- 開く大きさ（open）は今のまま `fitAll(1400 × 1050)`（`ZoomPolicy.swift:59-70`・:140-150）。何が書いてあっても同じ。
- いちばん小さくしたときの大きさ（min）は `min(open, fitAll(1400 × memo.minY))`。アでは `memo.minY` が自分の格子の高さのまま（§4.1）なので、隣に予定の多い月があっても min は変わらない（B_DESIGN §3.1 の規則）。イではそろえた格子の高さになり、隣の月で min が下がりうる（イを選んだときの気になる点として段 P の写真に添える）。
- 横に動いただけで倍率が変わることは無い（今の `applyBounds` は形が変わったときだけ、`InkCanvasView.swift:3090-3094`）。

### 4.7 PDF（月。0g-32）

- 今は、横の道の月・年では `ScreenPaths.paper(of:)`（:1171-1175）が nil を返し、`pdfInput`（:1163-1168）も nil になって、`runExport`（`CalendarRootScreen.swift:2631-2636`）が 1 ページの道の `onePage.page`（古いページか空のページ）で PDF を作る【推定。地図の読み】。本人には「書いた線が PDF に出ない」と見える。
- `paper(of:)` に月と年を足す（S）。月の PDF は焦点のページ 1 枚で、隣から入ってくる線の紙の中の部分も描く（D17、P-B8 おまかせ）。紙は画面が見せているまま（そろえた後。`PDFPageRenderer.swift:4-11` の規則）。
- `PDFPageRenderer.paperRect` の月の枝（:71-77）に、日・週の `neighborExtraBottom`（:78-99）と同じ形で、隣から入るメモの線の下端を足す（P）。メモ欄に自分の線も隣の線も無ければ今のまま格子だけ。矩形は `memoLine` から下の柄が切れない高さ（形は P が決めて記録）。
- 1 ページの道の PDF は 1 バイトも変えない（今のテスト）。

---

## 5. 年の形

### 5.1 行のそろえ（0g-21）

- 今の年は、31 行それぞれが 12 か月のマスの最大の高さ（終日のレーンと手書き）を取る（`YearLayoutEngine.swift:312-337`、行の高さ = min(400, max(60, 16 ＋ レーン × 18 ＋ 8, 手書きの下端 ＋ 12))、:275-280）【事実】。
- これを窓の年まで広げる: 行 r の高さの下限 = 窓のページの自然な行 r の高さの最大（`yearFloors`、`YearLayoutInput.rowFloors`）。自然な高さは 400 以下なので、下限も 400 以下（古い端末で見える行の上限の中）。同じ日付が年をまたいで横一直線に並ぶ（B_DESIGN §3.5 の実測: 行の上端のずれ 152 lu → 0）。
- 上げ下げの規則は §3.3。そろえで動くのはマスの位置と高さだけ（K-4）。
- 予定は終日だけ（§5.5）なので、自然な高さは予定を読み終えた年で決まる（読み終える前の年は手書きだけ。読み終えたら `.redecide`）。

### 5.2 日付の列と持ち主

- 年の紙は幅 1,400 lu（日付の列 56 lu ＋ 12 か月 × 112 lu、`PaperSpec.swift:90-112`）。1 ページの年では、日付の列と左の外は 1 月、右の外は 12 月が持ち主（`YearLayoutEngine.swift:149-158`）。
- 横の道では、持ち主は線の中心の x が入るページの半開区間（`SpanPlan.owner`、`SpanPlan.swift:211-223`）。だから 2027 年の日付の列に中心がある線は `y-2027` の 1 月のマスに入り、x が負になる（1.0 からの規則、B_DESIGN §4.1）。凍結の `SpanSessionTests.swift:450-456` はもう年の窓で 12/20 から右へ書いている。
- 例: 12 月 20 日から 1 月 10 日への横の線は、中心が 12 月の列なら `y-2026` の 12 月のマス（x が 1,400 を超える）、中心が 2027 年の日付の列か 1 月なら `y-2027` の 1 月のマス（x が負）。

### 5.3 年の札（0g-22）

- `spanYearRow`（P）で、各ページの日付の列の上（今の 1 ページの年では `Color.clear`、`StickyHeaderView.swift:285-286`）に年の数字（「2027」）を出す。左へ出ていった年は画面の左端に「2026」を残す（月の札と同じ貼り付き）。
- 字は題名の年の作り（新しい文を作らない）。日付の列は 56 lu で、iPad 13 の縦の開く大きさ（0.618）で約 35 pt、iPhone 縦（0.287）で約 16 pt、iPhone 横の上限（0.208）で約 12 pt【計算】。入らなければ下 2 桁（「’27」）、それも入らなければ出さない（題名に年がある）。
- 1 ページの道の見出しには出さない（J-4 と店の 04-year の元の画素を変えないため）。

### 5.4 年の一覧の倍率と、iPhone 横の上限（0g-23）

- 開く大きさは今のまま `fitAll(1400 × 1860)`。min は窓でそろえた紙の高さ（年の一覧の矩形は紙の全部、`ZoomPolicy.swift:89`。B_DESIGN §3.1「週・日・年は、そろえた高さで決める」）なので、行の高い年が隣にあると min が下がりうる。開く大きさと等倍は変わらない。
- **iPhone 横の上限は年 3 ページのまま**（`SpanPlan.overviewCapPages`、`SpanPlan.swift:76-83`。凍結の `OverviewCapChecks.swift:42`）。1.3 では年が横の道に入らなかったので、この 3 は一度も効いていない【事実】。1.4.3 から効く: iPhone 横の年の一覧は 0.124 から 0.208 へ大きくなり、1 年は縦に入らない（1,860 × 0.208 ≈ 387 pt ＞ 230 pt）【計算】。
  - 理由: 本人が 11/18 に選んだ P-B6 イの問いの本文に「年は 6 割ほど」とあった（B_DESIGN.md:747）。週・日と同じ考えにする。KitChecks（凍結）がもう 3 を固めている。言っていただければ外せる（§0.5）。外すときは `overviewCapPages` の年を nil にし、凍結の `OverviewCapChecks` の作り直し（§8.5 の例外 (d) を広げる）が要る。
- B_DESIGN §6.2 の窓（iPhone 横 上限ありで 3 → 7 ページ）。

### 5.5 予定（終日だけ。0g-24）

- 1 ページの年は終日の予定だけを読む（`EventStoreModel.swift:153-154` の `allDayOnly: kind == .year`。理由は `EventKitService.swift:126-141`）。横の道の `events(from:to:)`（:163-174）は `allDayOnly` を渡さず、`keepingEarlier: true` で全部の EKEvent を `fetched` にためる（`EventKitService.swift:162-166`）【事実】。年の窓 5〜7 年分で、時刻の予定を全部読んでためることになる（年のエンジンは終日だけを使う）。
- `events(from:to:allDayOnly: Bool = false)` にし、`SpanSession` が年で true を渡す（S）。凍結の `EventStoreModelSpanTests`（TESTS_1_3）は引数を省くので、今の答えのまま通る。
- 1 回の問い合わせが 4 年を超えない（`eventQueryMaxDays` :236-238）のは今のまま。年 1 年分を読む時間を `SpanWeightLogTests` で 1 回ログに出す（B_DESIGN §8.2 の測り）。

### 5.6 PDF（年。0g-32）

- `paper(of:)` に年を足す（§4.7）。年の PDF は焦点の年 1 枚で、紙の全部（`PDFPageRenderer.swift:100`、`paper.layout.size`）。隣の年から入ってくる線も、紙の中の部分を描く（D17）。紙はそろえた後の行の高さ（画面のまま）。

---

## 6. 等倍（月と年も幅にちょうど。0g-26）

### 6.1 規則

- `ZoomReset.followsFit` を月・年でも true にする（`SpanKinds.joined` に入っている種類。§2.1）。`target` は今の式のまま `bounds.clamped(bounds.fit)`（fit = 紙の列の幅 ÷ 1,400 lu）。
- **両方の道（横の道と、設定オフの 1 ページの道）で同じ**。鍵は今の `zoomFit.<種類>`（`AppSettings.swift:375-377`。4 種の名前はもうある）を両方の道で共に使う（1.4.1 の §16.3.5 と同じ考え）。端末ごと、iCloud に送らない。
- **開く大きさ（open）は変えない**（1.4.1 の §16.3.4 の (c) と同じ）。一度押すとその種類は次から等倍で開く。2 本指で大きさを変えると等倍の状態は消え、その大きさで開く（open より小さくしたときは open で開く）。
- 鎖は全部 `followsFit` で閉じているので、ほかの行は変えずに付いて来る【事実】: `CalendarRootScreen.currentFit`（:619-621）と最初のフレームの見積もり（:628-630・:649-651・:666-667）、`AppSettings.zoomFit(for:)`・`setZoomFit`（:381-399）、`ScreenshotMode.zoomFit`（`ScreenshotMode.swift:542-545`）、`ScreenPaths.bandZoom`・`bandViewport`（:1260-1276）。
- 落とし所（0g-3）で年を外したときは、`SpanKinds.joined` から外れるので年の等倍は open のまま（本人の言葉の順）。

### 6.2 凍結のキャンバスとの関係

- キャンバスは `ZoomReset.followsFit(appliedLayout.kind)` と `ZoomReset.target` を呼ぶだけ（`InkCanvasView.swift:1236-1237`・:1304・:1313・:1356-1364・:1471-1544・:1569-1573・:2247）【事実】。**等倍のために凍結の行は 1 行も変えない**（R3 は紙だけ。§8.4）。
- 横の道の `resetZoom` は、もう「真ん中のページを画面の真ん中に」置く（:1522-1525）。幅が変わったとき（回転・Split View・左右のツールバー・Duo の開閉）に fit を追う step 4 と、高さだけの変化で fit を保つ `applyBounds` も、種類を見ない。

### 6.3 数【計算。`SpanPlan.referenceViewport` と `docs/R1_1_1.md:50-109` の紙の領域から。D1b・D1y の写真の probe で測り直して `docs/R1_4_3.md` に書く】

| 端末（ツールバーは下） | 月 open → fit | 月の等倍で見える量 | 年 open → fit | 年の等倍で見える量 |
| --- | --- | --- | --- | --- |
| iPad Pro 13 縦 | 0.7371 → 0.7371（同じ） | 6 行とメモの頭 | 0.6183 → 0.7371（×1.19） | 31 行のうち約 26 行 |
| iPad Air 11 縦（推定 820 × 954） | open = fit | 同じ | 0.5129 → 0.5857（×1.14） | 約 27 行 |
| iPad mini 縦 | 0.5314 → 0.5314 | 同じ | 0.4876 → 0.5314（×1.09） | 約 28 行 |
| iPhone 縦 | 0.2871 → 0.2871 | 同じ | open = fit | 同じ |
| iPad Pro 13 横 | 0.7905 → 0.9757（×1.23） | 約 4.9 週 | 0.4462 → 0.9757（×2.19） | 約 14 行 |
| iPad 11 横 | 0.6095 → 0.8643（×1.42） | 約 4.2 週 | ×2.51 | 約 12 行 |
| iPad mini 横 | 0.5238 → 0.8093（×1.55） | 約 3.9 週 | ×2.74 | 約 11 行 |
| iPhone 横（列 750） | 0.2190 → 0.5357（×2.45） | 約 2〜2.5 週 | 横の道は上限で ×3.00（1 ページの道は ×4.5〜5.0） | 約 6〜7 行 |

- 左右の端のツールバーでは列が 74 狭くなり、fit もその分だけ小さい（R1_4_1_CONTRACT §16.3.1）。iPhone 18 Pro Max の横の紙の高さは記録が無い【未確認】。D1b の probe で測る。

### 6.4 端のケース

| 場合 | 動き |
| --- | --- |
| open = fit の所で押す（月はどの端末の縦でも、年は iPhone の縦） | 見た目は変わらない。それでも等倍の状態を立てて覚える（1.4.1 の §16.3.2 の 2 と同じ）。その後に横にすると、step 4 で幅にちょうどになる。§0.1 と確かめ表の行 5・14 で、この順（縦で押す → 横にする）を試す |
| 横の iPad の月・縦の iPad の年 | 縦のスクロールが要る（1 ページの幅を画面の幅に合わせるため）。等倍で開いた月は上の端から（`PageNavigation.swift:169-188` で月は 0）。「今日」で今日のマスへ（§3.7） |
| iPhone 横の年（上限 3） | 上限は min と open だけに効き、fit は変えない（`ZoomPolicy.cappedBounds`、`ZoomPolicy.swift:158-167`）。等倍で 1 年が横いっぱい（上限の 3 倍） |
| 種類を替えた | その種類の覚えで開く（月・年も `initialFit` を読む） |
| 1 ページと横の道 | 同じ鍵（§6.1） |
| 今まで月・年で押していた端末 | 1.4.1・1.4.2 の月・年の等倍は比 1 を書いて `zoomRatio.<種類>` を消すだけで、`zoomFit` は書かなかった（`AppSettings.swift:352-359`）【事実】。だから 1.4.3 を入れても、月・年は等倍で開かず、open（または覚えた拡大）で開く |
| 月・年の比を覚えていた（ピンチした） | 今のまま（等倍の状態が無ければ比で開く） |

### 6.5 写真モード

- `--screenshot-zoom fit`（`ScreenshotMode.swift:428-430`・:535）は、月・年でも効くようになる（`followsFit` が真のため）。今の J-4・blank-paper・span-shots-app の写真は、月・年でこの引数を使っていない【事実: `grep`】ので変わらない。
- 新しい写真（§12.4）で、月・年の等倍の前と後を撮る。iPad の横は XCUI の回転で撮る（`PaletteShotsUITests` の `.landscapeLeft` の形、`build.yml:3661`）。倍率の数は `--screenshot-probe` の XCUI で読む（iOS 27 のシミュレータの `log show` は NSLog を `<compose failure>` と出す、`build.yml:1625-1631`）。

---

## 7. 設定・端末・案内

### 7.1 設定オン・オフ

- 4 種で 1 つのスイッチ（P-B7）。オフは 1 ページの道。オフの端末では、ページをまたいで書いた線は片方のページにだけ出る（消えていない）。
- 設定の脚注 `settings.page.span.footer` を新しい字にする（§13.1、0g-34）。スイッチの名前「前後のページを横につなげる」は変えない（comment だけ「月と年も」に直す、`app-U.json:1828`）。

### 7.2 iPhone・iPad・横向き・Duo（手のひらと指）

- 指の動きは 1.3 の横の道のまま（種類を見ない）: iPad・「指でも書く」オフは指 1 本で上下左右、オンは 2 本指で動かし指 1 本で書く。iPhone は「指でも書く」オン（既定）で 2 本指。方向のロック、手のひらの手当て（Pencil が触れている間と離して 0.5 秒は指の横の動きで紙を動かさない、一覧では横の動き出しに約 24 pt、`InkCanvasView.swift:3212-3216` の `isAtOverview`）、はじき（P-B5 ア、`SpanPlan.flingTarget`）、‹ › でちょうど 1 ページ。
- **月の iPad の縦の一覧は V = 1.00**（隣が見えない）。横に動くことに気づきにくいので、案内の札（§7.3）に頼る。iPad の横では左右に前後の月の表の端（11 インチで約 1.5 列ずつ）が見える。
- 年の iPad の縦は V 1.09〜1.19 で左右に少し、横は V 2.19〜2.74 で 2〜3 年。
- Duo の内側（推定 V 月 1.00・年 1.27）は、幅が許す所は iPad と同じ（広い窓の横の道には上限を付けない、M7D 0d-8）。外側は iPhone と同じ（年は上限 3）。duo.yml で月・年も横の道で撮る（§12.1）。確かめ表の Duo の行は「—」。
- 回転・Split View・Duo の開閉: 幅が変わる → V が変わる → 止まったときに窓を決め直す。焦点のページを保つ（今の規則）。

### 7.3 初めての案内（月・年の札。0g-33）

- 横につないだ種類を、更新後に初めて開いたとき（端末ごと・種類ごとに 1 回）、紙の上の端に小さな札を出す（1.3 の形。8 秒で消える、触れても消える、写真モード・設定オフ・段 2・テストのホストでは出さない。`SpanGuide.isDue`）。
- `SpanGuide.joinedKinds` は `SpanKinds.ordered`。`SpanGuide.text` に月・年の 4 つの鍵（§13.1）。
- 月の文は「メモ欄で境目をまたげる」と言う（月の格子では日付が続かないので、週・日の語を替えるだけでは間違った案内になる）。
- 写真の札（`ScreenPaths.photoGuide`、:1247）も月・年で撮れる（`--screenshot-span-guide one|two` を月・年のページで）。

---

## 8. データ互換

### 8.1 保存の形（変えない）

- 新しいページ id・マス名・線の項目・保存の形を作らない。`v` と書き出し `tegaki-app-export` v1 を上げない（K-5）。月のページは `m1-YYYY-MM`、年は `y-YYYY` のまま（`TegakiKit/Sources/DayKit/DayKey.swift:156-158`、`PageNavigation.swift:20-21`・:39-47）。週の始まりに関係なく同じ id（K-11 の 4）。
- またいだ線は、外接矩形の中心の x が入るページに 1 本で保存し、隣の紙の上に出た点も切らずに持つ（x が負、または 1,400 を超える。座標の上限 ±100,000 lu の内）。持ち主は書いたときに 1 回だけ決め、レイアウトが変わっても決め直さない（B_DESIGN §4.1）。
- 新しい鍵は無い（`zoomFit.month`・`zoomFit.year` は名前がもうあり、端末の UserDefaults だけ）。App Privacy（データの収集なし）は変わらない。
- 移行は無い。そろえは位置の変更だけで、保存される物は変わらない（B_DESIGN §4.4）。

### 8.2 K-1〜K-11 とこの版での当てはめ

規則の正文は [M7_PLAN.md](M7_PLAN.md) §1.3。B_DESIGN §4.2 の対照も読む。

| 規則 | 1.4.3 での当てはめ |
| --- | --- |
| K-1 `allday` で始まる名前を使わない | 新しいマス名・ページ id を作らない。前置した名前 `<pageId>|…` と仮想 id `span~…` は端末のメモリの中だけ（1.3 のまま） |
| K-2 同じ id の線を別のマスへ付け替えない | ページをまたぐ投げなわの移動は、行き先に新しい id、元に墓標（`moveStrokes`、1.3 のまま）。月の重なる日（10 月の表の 11/1 → 11 月の表）も同じ。新しい互換の fixture で示す（§8.3） |
| K-3 1 つのページに 2 枚のキャンバスで書かない | 種類ごとにキャンバスは 1 枚、窓の中の同じページ id は 1 回だけ。2 本の道は同時に同じページを開かない |
| K-4 マスの意味を変えない | そろえで動くのはマスの位置と大きさだけ。月のアでは `memo` の原点も動かない（§4.1） |
| K-5 線に項目を足さない、`v`・v1 を上げない | 足さない・上げない。InkModel の 9 ファイルは 1 バイトも変えない |
| K-6 伸びる欄は一覧から外す | 月の一覧は `memo.minY`（自分の格子の高さ）のまま。年は紙の全部（伸びる欄が無い） |
| K-7 互換テストは古い版の本物のコードで | 1.0・<1.1.1>・1.2.3・1.3 の相手をそのまま走らせ、新しい fixture のフォルダも読ませる（§8.3） |
| K-8 古い端末での見え方を新機能の文に | 新機能の文に K-8 の文（B_DESIGN.md:413 の字そのまま）を入れる（§13.3）。SUPPORT の「版が違うと？」に 1 文（§13.5） |
| K-9 線の予算は持ち主のページで | 今のまま（`InkCanvasView.budgetCount(ofPage:)`、:2602-2611。伸びの上限は strip した後の `PaperGrowth.isTail`、:3631 で、月のメモでも働く）。年は 1 年 = 1 ページ |
| K-10 名前に `|` と `~` を使わない | 新しい名前が無い |
| K-11 週の始まりとページ | 月・年の id は週の始まりで変わらない。月の表の最初の日は週の始まりで決まる（`MonthLayout.swift:54-56`）。日曜始まりの月の fixture を足す（§8.3） |

### 8.3 互換の相手（変えない）と、新しい fixture（0g-30）

- compat-v1.0（macos-26・Xcode 26.6）で、1.0（a21e469）・<1.1.1>・1.2.3（43fe366）・1.3（955fe67）の本物のコードが今の fixture を読む。1.4.2 の V の数: compat10 **631**・失敗 0、compat-span real **631**（EXPECTED_MIN 599）、span-compat 1.0 **274**・<1.1.1> **274**・1.2.3 **278**・1.3 **310**、Real10/Real123/Real13 **4/4/5**（`docs/R1_4_2.md:1097`）。**相手は足さない**: 1.4.3 が触れる凍結のファイルは `InkCanvasView` の紙の 1 関数だけで、データのコード（2〜20 行目）は 1.3 の基準から変わっていないため（K-7 の注「データのコードに触れる版は基準の commit を相手に足す」に当たらない）。
- 今の compat-span（FIXTURES_1_3 で凍結。フォルダの中のファイルの一覧も固定、`build.yml:494-516`）には、月の overhang-right・overlap-day 2 つ・年の overhang がもうある（`TegakiKit/Tests/Fixtures/compat-span/MANIFEST`）【事実】。
- **新しいフォルダ `TegakiKit/Tests/Fixtures/compat-span-143/`**（C。作り手は KitChecks の新しい書き出し `--write-compat-span-143-fixtures`、MANIFEST の形は今の compat-span と同じ）に 4 組:
  - 8: 月のメモの線が右のページから左へはみ出す（`m1-2026-11` の `memo`、x −160〜260。B_DESIGN §4.1 の例）。
  - 9: 月の重なる日の投げなわの移動（`m1-2026-10` の 2026-11-01 から `m1-2026-11` の格子へ。元に墓標、行き先に新しい id）。
  - 10: 年の日付の列に中心がある線（`y-2027` の 1 月のマス、x −128〜70）と、12 月 → 1 月の横の線で持ち主が 12 月のもの（`y-2026`、x が 1,400 を超える）。
  - 11: 日曜始まりの月のメモをまたぐ線（形は sunday）。
- 新しい守りの表 `tools/span/FIXTURES_1_4_3.sha256`（新しいフォルダの全部のファイル、MANIFEST を含む）と、build.yml の段「1.4.3's fixtures unchanged (FIXTURES_1_4_3)」（`FIXTURES_1_3` の段と同じ形で、フォルダの中のファイルの一覧も表と同じ）。**FIXTURES_1_3 の表とフォルダは 1 バイトも変えない**。
- 読み手: 本物の 1.0・<1.1.1>・1.2.3・1.3 と 1.0 の凍結の写しで、新しいフォルダの線の数・座標・マス名・墓標が変わらず、描く対象と投げなわの候補に入り、merge で残り、書き戻すバイトが同じ（今の compat-span と同じ確かめ。新しいテストのファイル `CompatSpan143Tests` と、compat-v1.0 の段に新しいフォルダを足す。形は C が決めて記録）。数は増える。増えた数を D1a の取り込みの前に `docs/R1_4_3.md` に宣言する。`EXPECTED_MIN`（225・599。条件は「以上」）は変えない。

### 8.4 凍結の表（`tools/compat10/DATA_1_1.sha256`、20 行）と R3（0g-27）

**1.4.3 で変えてよい行は 1 行目（`Sources/TegakiCalendar/Ink/InkCanvasView.swift`）だけ**。2〜20 行目は 1 バイトも変えない（`build.yml:456-459` の `shasum -c`）。

| 行 | ファイル | 1.4.3 での使い方 |
| --- | --- | --- |
| 1 | `Ink/InkCanvasView.swift` | **R3: `paperSpan(for:focus:)` の本体だけ**（§3.4）。等倍・ずらし・y の補正の行は変えない（§3.5・§6.2） |
| 2〜11 | `InkLedger`・`InkOverlayView`・`InkSnapshot`・`InkTools`・`InkTouchObserver`・`InkTrace`・`PencilInteraction`・`InkPageStore`・`InkPageRecord`・`SyncEngine` | 触れない（種類を見ない） |
| 12〜20 | `TegakiKit/Sources/InkModel/` の 9 ファイル（`SpanComposer`・`SpanGuard` を含む） | 触れない（例外なし） |

**R3 の許す行の全部**（4a2211d の行番号）:

| # | 場所 | 足す・替える | 中身 |
| --- | --- | --- | --- |
| R3-1 | `paperSpan(for:focus:)` の本体（:2626-2637 の `var bands` から `return PaperSpan(...)` まで） | 替える（約 12 行 → 1 行） | `PaperSpan.window(for: layout, focus: focus)` |
| R3-2 | その注（:2620-2624） | 直す | 「4 種の窓の紙は `PaperSpan.window` が決める。キャンバスは種類を持たない（1.4.3）」 |

- **触らない**: `bandOverview`、`applyPendingSpan` と y の補正（:3027-3100）、等倍の行（§6.2）、`updatePaperSpan` の形（:3140-3147）、保存・merge・同期・墓標・台帳の行。
- 前例: 1.4.1 は 1 行目だけを 2 回作り直した（R1_4_1_CONTRACT §5.4・§16.4。c067210/bf3da7b と 03652a8）。今の値は `d0250f23ba2e76c12c2d7d2dca9558579c27660b250c5767003d1d4e0b22a503`【事実: shasum】。

**手順**（R1_4_1_CONTRACT §16.4 の 1〜6 と同じ形。D1b の Z の 1 つの commit）:
1. 同じ commit で表の 1 行目を書き直す。新しい値は commit で決まり、記録に書く。
2. 手元で `tools/l10n/lint-skip.txt` から `InkCanvasView.swift` を一時的に外して `python3 -I tools/l10n/lint.py` が OK、元の 20 行に戻す（`git diff` が空）。
3. `docs/R1_4_3.md` の D1b に: commit、替えた行の全部（実際の行番号）、1 ページの道と横の道のどちらが通るか、その行を通る今のテストの名前。
4. **行の見直しの前に緑**: 互換の相手（compat10 631・span-compat 274/274/278/310・Real13 5/5）、保存のバイトの関門 2（§8.7 の 3 つ）、`TESTS_1_2_3` 8・`FIXTURES_1_3` 37 が 1 字も同じ、`TESTS_1_3` と `TESTS_1_4_1` は §8.5 の行の外が 1 字も同じ、ピン留めの `InkCanvasViewTests`（TESTS_1_2_3）・`InkCanvasSpanTests`（TESTS_1_3）・`DuoFoldTests`・`InkCanvasWidthCentreTests`・`InkCanvasSpanZoomResetTests`（TESTS_1_4_1）がそのまま緑（週・日の窓は `PaperSpan.window` の週・日の枝で、今と同じ値が来る）。
5. リードが diff を 1 行ずつ見て、記録に「リードの決定」として書く。本人には最後の報告で知らせる。
6. `build.yml:456` の段の名前を「Data code frozen (re-based in 1.4.1 and 1.4.3)」に直す（C。同じ commit でなくてよい）。

- ピン留めのテストが 1 つでも結果を変えたら、テストは直さず R3 の行を直す。直せなければ止めて契約を直す。

### 8.5 守られたテストの作り直し（R0。例外 (d)。0g-28・0g-29）

**なぜ要るか**: 次の守られたテストは「月・年はいつも 1 ページ」「月・年の等倍は open」を、1.3・1.4.1 の機能として言い切っている【事実】。1.4.3 はその機能を本人の言葉で変える版なので、コードを直して通す道が無い。今の決まり（TESTS_1_3 は M7D_CONTRACT §5.5 の (a)(b)(c) で SDK の揺れ・API・システムの飾りだけ、TESTS_1_4_1 は「落ちたらコードを直す、テストが間違いなら止めてリードが決める」、R1_4_2_CONTRACT.md:626-629）のどれにも当たらない。だから、この契約がリードの決定として例外 (d) を足す。**既定値つきの引数で古い断言を残す形（たとえば `joins(…, monthAndYear: false)`）は採らない**（古い断言が意味の無い道を確かめ続け、守りを黙って弱めるため）。

**例外 (d) の決まり**:
- 作り直してよいのは、下の表に名前を挙げた断言だけ。ほかの行は 1 字も変えない。
- **消さない**。同じテストの名前のまま、期待を 1.4.3 の答えに置き換え、月・年が加わった分の確かめを足す（確かめの数を減らさない）。週・日の断言は 1 字も変えない。
- 自分の commit（`R0m`＝月、D1b。`R0y`＝年、D1y。`R0f`＝設定の脚注の字、D2）に、そのテストのファイルと、表の行の書き直しだけを入れる。表の行は、その commit の blob から M7D_CONTRACT §5.5 の printf の行で作る。機能の commit とは別。
- 作る役は R0 の前に、表のファイルを `grep -n` で読み、月・年を 1 ページ・open と言う断言を全部挙げて `docs/R1_4_3.md` に書く（下の表は調べ役の地図の行。漏れがあれば足し、足した行も記録する）。
- リードが diff を 1 行ずつ見て、記録に「リードの決定」と書く。
- 落とし所（0g-3）で年を外したら、`R0y` は作らない（年の断言は今のまま正しい）。

| 表 | ファイル | 作り直す断言（4a2211d の行） | 1.4.3 の答え | commit |
| --- | --- | --- | --- | --- |
| TESTS_1_3 | `Tests/TegakiCalendarTests/ScreenPathsSpanTests.swift` | :191-195（`joins` が月・年で false）、:212・:216・:273・:996・:1703（`open` が月・年で `.onePage`）、:1826（月の写真の札が無い） | 設定オン・写真モードの `--screenshot-span on` で `.joined`、設定オフ・`fallenBack`・`--screenshot-single-page` で `.onePage`。月・年にも札がある | R0m（月）・R0y（年） |
| TESTS_1_3 | `Tests/TegakiCalendarTests/SettingsPageSectionTests.swift` | :258-261（`SpanGuide.text` が月・年で nil、`joinedKinds == [.week, .day]`）、:333-334（`showIfDue` が月・年で false）、:352（`isDue` が月で false）。:19 と :135（脚注 N-3 の全文） | 月・年の札の字、`joinedKinds == [.week, .day, .month, .year]`、月・年でも due。脚注は新しい字（§13.1。本人の「この内容で入れてよい」の字） | R0m（月の行）・R0y（年の行）・**R0f**（:19 と :135。D2 で、落とし所を決めた後、脚注の ja と訳を替える commit の直後。落とし所なら月だけの字） |
| TESTS_1_4_1 | `Tests/TegakiCalendarTests/ZoomResetTargetTests.swift` | :14-19（`followsFit` が月・年で false）、:29-38（年・月の target が open）、:65-80（月・年は open） | `followsFit` が 4 種とも true、target は fit（年 834/1400・月 1366/1400 など、式で） | R0m・R0y |
| TESTS_1_4_1 | `Tests/TegakiCalendarTests/ZoomFitWiringTests.swift` | :218-222（月に等倍の状態が無い）、:228-238（`followsFit == week || day`） | 月・年にも等倍の状態がある、`followsFit == SpanKinds.joined.contains` | R0m・R0y |
| TESTS_1_4_1 | `Tests/TegakiCalendarTests/InkCanvasZoomResetTests.swift` | :321-（横の iPad の月の等倍が open）、:826-844（`testTheMonthDoesNotReadInitialFit`）、ほか月・年の等倍を open と言う所（Z が `grep` で全部挙げる） | 月は `initialFit` を読み fit で開く、等倍は fit、幅の変化で fit を追う | R0m・R0y |
| TESTS_1_4_1 | `Tests/TegakiCalendarUITests/ZoomResetUITests.swift` | :11-12 の注と :44-48（年を open へ、`toFit: false`） | 年は fit へ（iPhone 17 の縦では open = fit なので、倍率は同じで状態が立つ。期待は U が決めて記録） | R0y |

- **作り直さない（そのまま通すこと）**: `ScreenshotModeSpanTests.swift:144-148`・:632-640（月・年の `spanDemoPage` は 1 ページの見本のまま。月・年のまたぐ見本は新しい引数 `--screenshot-span-crossing all` の時だけ、§12.4）、`PaperSpanTests.swift:265-266`（`PaperSpan.single` は月・年で nil のまま、§3.4）、`SpanRerunUITests.swift:28`・:52-60（月の 4 本を横の道で飛ばすのは今のまま。月の横の道は新しい UI テストで見る）、`SpanShotsUITests`（週・日だけを撮る、:97・:121・:169）、KitChecks の `SpanChecks.swift`（`Floors.none` と `floor(for: .month/.year) == 0` は新しい欄の既定 0 で通る、:628-631。V の表 :354-361、band の答え :816-820・:952）と `OverviewCapChecks.swift`（年 3・月 nil、:24-42）、`EventStoreModelSpanTests`（`allDayOnly` は既定 false）、`SpanSessionTests`（月・年のセッションの compat の形。§8.7）、`TESTS_1_2_3` の 8 ファイル。どれかが落ちたら、テストは直さずコードを直す。直せなければ止めて契約を直す。
- **新しい守りの表 `tools/span/TESTS_1_4_2.sha256`**（D0。C が作り、`build.yml` の TESTS_1_4_1 の段 :488-492 の後に同じ形の段「1.4.2 tests frozen (1.4.3)」）。1.4.2 で足した単体テスト 11（`ColorPanelFitTests`・`ColorPanelLogicTests`・`ColorPanelWatchTests`・`ColorPanelWiringTests`・`InkColorRoundTripTests`・`MemoPaperDrawTests`・`MemoPaperRedrawTests`・`MemoPaperStyleTests`・`PenSlotsTests`・`ScreenshotModeColorMemoTests`・`SwatchRimTests`）と UI 4（`ColorPanelPadUITests`・`ColorPanelUITests`・`MemoPaperShotsUITests`・`MemoPaperUITests`）の 15 が候補（`git diff --name-status 2e3ee75 57ffd0f -- Tests`）。C が D0 で確かめて表にする（1.4.3 で写真の行を足すファイルがあれば除く）。57ffd0f の blob から作る。理由: 1.4.3 は 1.4.2 で直した紙（`MonthPaper`）と画面に触れる。1.4.2 の動き（メモ欄の紙・色の板）を確かめるテストを、作る人がうっかり弱めないようにする。
- `AppSettingsTests.swift:302-310`（月・年は等倍の状態を持たない）は守られていないので、ふつうに読み替える（S）。

### 8.6 画面の字で守られた所と、変えない数・形

R1_4_2_CONTRACT §5.6 の一覧（`CalendarRootScreen.swift` の `guide.close()` 3 つ・`guide.dismiss()` 3 つ・`sheetIsUp` の本体・`allowFinger: allowFingerBinding,` 2 つ・`ToolbarView(` 1 つ・`joinedCanvas` の字・`OnePageRevealTests` の字・`PaletteMoveButtonTests.swift:467-537` の字・`colorPanel: ColorPanelHook(openSlot: $colorPanelSlot), axis: axis, move: paletteMoveButton )` 1 つ、`SettingsScreen.swift` の `Form` の 9 つと `pageSection` の中身）は、平らにした形で 1 字も変えない。1.4.2 で足した `ColorPanelWiringTests`（TESTS_1_4_2 に入る）が読む字も同じ。

変えない数と形:
- `StartState` の欄、`toolbar: paperArea=`・`toolbar: safeArea=`・`toolbar: palette=` の行の形、`span cap:` の行の形。
- `Sheet.allCases.count == 11`、`SettingsSection == ["page"]`（`ScreenshotModeTests.swift:302-303`、`ScreenshotModeSpanTests.swift:255`・:673-674）。
- `MonthPaperContent`・`WeekPaperContent`・`DayPaperContent`（`PaperView.swift:8-25`）の欄。`PaperView.init(content:zoomScale:)` の形と、init で描き直しを頼まないこと。
- 見出しの 1 ページの道の行（`monthRow`・`weekRow`・`dayRow`・`yearRow`）の中身と高さ。

### 8.7 保存のバイト（関門 2）

- `InkLedgerTests.testLedgerWritesTheCompatShapes`・`ScreenshotModeTests.testDemoPagesMatchCompatFixtures`・`SpanSessionTests.testSpanSessionWritesTheCompatSpanShapes` が、作り直さずに今の fixture と 1 バイトも同じ（R1_4_2_CONTRACT §5.7 と同じ 3 つ）。月・年のセッションで下限が入っても、保存される点はマスからの相対なので同じ見込み【推定】（窓の隣のページは空で、行の自然な高さは線のあるページがいちばん高い）。D0 と、D1a・D1b・D1y の通しの run で見る。違えば止める。

---

## 9. ↶・投げなわ・消しゴム・PDF・同期（月と年をまたいで）

### 9.1 ↶ ↷

- 窓全体で 1 本の履歴（1.3 のまま）。1 回の ↶ が 2 ページを変えてよい（ページをまたぐ移動は 1 歩で戻る）。窓から出るページにかかわる操作は捨てる（`pruneHistory`）。前後 R ページ以内にいる間は残る。
- 確かめ: 新しい単体テスト（月の窓で隣の月のメモへ書く → ↶ で消える → ↷ で戻る。年の 12 月 → 1 月の線を消しゴムで消す → ↶ で戻る。窓を 2 回ずらした後の ↶ は窓の外のページに書かない）。

### 9.2 投げなわ・予定ツール・「予定にする」

- 投げなわは窓の全ページの線から選ぶ。移動の上限は帯の紙。選んでいる間は窓をずらさない（1.3 のまま、`refreshSelection` で黙って外れないように）。移動の写しの持ち主は移動後の中心で決め直し、ページが変われば行き先に新しい id、元に墓標（K-2）。
- 「予定にする」と予定ツールは、選んだ範囲の中心のページのレイアウトで日時を決める（`SpanLayout.eventTarget`）。月はそのマスの日の終日の予定、メモ欄なら今と同じ（その月の今日か 1 日、`MonthPageLayout.swift:262-273`）。年は終日の予定。日をまたぐ予定は作らない（今と同じ）。
- 月の重なる日: 10 月の表の 11/1 の線を投げなわで 11 月の表の 11/1 へ動かすと、新しい id の写しと墓標（fixture 9、§8.3）。

### 9.3 消しゴム

- PencilKit の線ごとの消しゴムは窓のどこでも効き、墓標は前置した id から持ち主のページへ（1.3 のまま）。1 回の変化で消える線が多すぎるときの守り（B_DESIGN §2.4 の 6 の (b)）も種類を見ない。
- 消しゴムで自然な高さが下がると、下限も下がる（§3.3 の `.inkShrank`）。

### 9.4 PDF

- §4.7・§5.6。「このページ」は焦点のページ 1 枚、隣から入る線の紙の中の部分も（P-B8）。

### 9.5 同期

- 記録の形は 1 ページ = 1 件のまま。窓のどのページの iCloud の更新も、`remoteUpdated`・`pendingRemote` で受ける（:923-985）。ほかの端末の「全て消す」は `onRemoteDelete` で窓のページを空に（:923-951）。ページをまたぐ操作は 2 件の記録で、行き先を先に保存する（D8、:815-846）。どれも種類を見ない。
- 確かめ: 新しい単体テスト（月の窓の隣のページに外から更新が届くと、キャンバスに出る。年の窓の 1 ページが外で消されると、空になり ↶ からも外れる）。

---

## 10. アクセシビリティ

- 月の札・年の札は見出しの要素（`.isHeader`）。読み上げの字は札の字（題名と同じ作り）。左端に貼り付いた札は、元の札と同じ要素として 1 回だけ読む（2 回読ませない）。
- 年の見出しの月の名前のボタンは、今の読み上げの字（年と月を言う。例「2026年3月（月表示へ）」、`ZoomResetUITests.swift:44` の `marchLabel`）を、窓の各年で使う。
- 案内の札は今の札と同じ読み上げ（1.3 の形）。
- 等倍のボタンの読み上げ「等倍に戻す」は変えない（comment だけ直す、§13.1）。
- 境目の線と白い紙は飾り（読み上げない）。
- Dynamic Type: 札は紙と同じく倍率で決まる（今の見出しの字と同じ扱い）。動きを減らす設定: 滑らす動きは週・日と同じ扱い（1.3 のまま）。
- VoiceOver で横に動く方法は 1.3 と同じ（‹ › のボタン）。

---

## 11. テスト

新しいテストは新しいファイル。時間を待つテストは `TestSleeper`。新しい UI テストの待ち方は「期限の後にもう 1 回読む・回数で数える」形（R1_4_2_CONTRACT §1.5）。「直しが無いとどう落ちるか」は変異で確かめる（§11.5）。結果と run の番号を `docs/R1_4_3.md` に書く。

### 11.1 Kit（`TegakiKit/Sources/KitChecks/SpanMonthYearChecks.swift`、新しい。役 K）

- **下限の入力を省けば今の出力と `==`**: MonthLayoutInput・YearLayoutInput を下限なしで作った答えが、今の答えとどのマスも同じ（今の KitChecks 40,826 がそのまま緑）。`memoLine == memo.minY`。
- `monthFloors`: ア（`memoLine` が窓の `memo.minY` の最大、行は変わらない、`memo` の原点は変わらない、下端がそろう）、イ（6 行が行ごとに窓の最大、区切りの線と下端がそろう、どのマスも x と幅が同じ）、ウ（下限なし）。`.shift` で下げない、`.inkShrank` で窓の最大まで下げる、`.redecide` で決め直す、`.inkGrew` で上げるだけ（週・日の `dayFloors`・`weekFloors` と同じ表）。
- `yearFloors`: 31 行が行ごとに窓の最大、どの行も 400 以下、x と幅が同じ、上げ下げの規則。
- `PageScroll.scrollDelta`: 月の窓（行の高さの違う 5 か月）を 1 ページずらすと、下限が同じなら 0（格子の中・メモ欄の中・区切りの線の上）。区切りの線が 120 下がると、メモ欄を見ていれば 120。週・日・年の窓と窓 1 ページは今の答えと同じ（全部の窓の形で比べる）。
- `SpanLayout`: 月・年の窓で `drop`・`inkCell` が中心の x のページへ（境目の左・右・ちょうど、年の日付の列、月のメモ欄、月の白い紙は `memo`）、前置した名前で `hit`・`dayAt`・`eventRange`・`growsWithInk` が素の名前と同じ答え、`onlyTailHeightChanged` が月のメモの下だけのとき真、区切りの線が動いたとき偽。
- 焦点の規則の純粋な部分（月末・2/29）を TegakiKit に置くなら、その確かめもここに（置き場所は K と S が決める）。
- 数は D1a の取り込みの前に `docs/R1_4_3.md` に書く（40,826 から増える。閾値 40,776 は「以上」なのでそのまま）。

### 11.2 新しい単体テスト（アプリ）

| 役 | ファイル（新しい） | テスト | 直しが無いと（変異） |
| --- | --- | --- | --- |
| S | `SpanKindsTests.swift` | `SpanKinds.joined` が 4 種、`ordered` の順。`joins`（設定オン）・`SpanGuide.joinedKinds`・`ZoomReset.followsFit`・`ScreenPaths.paper(of:)`（nil でない）・`PaperSpan.window`（nil でない）が、4 種のどれでも `SpanKinds.joined.contains` と同じ答え（落とし所で年を外しても、このテストは書き直さずに通る形で書く） | MS1・MS4 |
| S | `ScreenPathsMonthYearTests.swift` | `open` が月・年で、設定オン → `.joined`、オフ → `.onePage`、`fallenBack` → `.onePage`、写真モードは `--screenshot-span on` だけ。焦点の規則（10/31 → 11 月は 11/30、11/30 → 10 月は 10/30、1/31 → 2/28、2028-12-31 → 2027 は 2027-12-31、2028-02-29 → 2027 は 2027-02-28、週・日の答えは今の式と同じ）。今日（月・年の `todayRect` が今日のマス、上限の年の `cappedOpeningY` が今日の 2 行上、`cappedTodayRect`）。`paper(of:)` と `pdfInput` が月・年で nil でない。見出しに月・年の帯が無い | MS2・MS5 |
| S | `SpanSessionMonthYearTests.swift` | 月の窓で下限が入る（アの `memoLine`、下端）、年の窓で 31 行がそろう。メモ欄に書くと `.inkGrew`、消すと `.inkShrank`。ずらしで下げない。予定を読み終えた年で `.redecide`。年の予定の問い合わせが `allDayOnly: true`。compat の形が同じ（§8.7） | MS6・MS7・MS3 |
| S | `EventStoreModelYearTests.swift` | `events(from:to:allDayOnly: true)` が時刻の予定を返さず、`keepingEarlier` で終日だけをためる。引数を省くと今と同じ | MS3 |
| S | `ZoomResetMonthYearTests.swift` | 4 種の `followsFit` と `target`（11 インチの縦の年 834/1400、横の iPad の月 1366/1400、iPhone 横の上限の年で fit は上限の 3 倍）。`AppSettings.zoomFit(for: .month/.year)` を覚える。`ScreenshotMode.zoomFit` が月・年でも `--screenshot-zoom fit` で真 | MS4 |
| S | `SpanGuideMonthYearTests.swift` | 月・年の 4 つの文が 10 の言語のバンドルにある、`isDue` が月・年で真（設定オン・横の道・未表示・写真モードでない・テストのホストでない）、段 2 で戻った種類では偽 | — |
| S | `ScreenshotModeMonthYearTests.swift` | 新しい引数（`--screenshot-span-crossing all`・`--screenshot-month-tall`）を読む。今までの引数の Config は同じ値。引数なしの月・年の見本は今のまま（凍結の `ScreenshotModeSpanTests` と同じ答え）。またぐ見本の線が月はメモ欄に、年は 12 月 → 1 月に、持ち主が左右 1 本ずつ | — |
| S・Z | `SpanWeightLogTests.swift` | §3.10 の測り（ログだけ。合否は落ちない形） | — |
| P | `PaperSpanMonthYearTests.swift` | `window(for:)` が 4 種で窓を作る、週・日は今の `init?(layout:bands:focus:)` と `==`、月・年は bands が空、`single` は月・年で nil のまま、原点と大きさ | MP1 |
| P | `MonthPaperLineTests.swift`（凍結の `PaperViewTests` の画素の読み方を写す） | 下限なしの月は 1.4.2 と 1 画素も同じ（罫線・ドット・無地）。`memoLine` を下げた月で、区切りの線・罫線・点・「メモ」の札がその y から、`memo.minY` から `memoLine` までが紙の色。つないだ月の窓で、境目の線が格子だけに引かれ、メモの帯には無い。窓 1 ページには線が無い | MP2 |
| P | `StickyHeaderMonthYearTests.swift` | 横の道の月で `spanMonthRow`、年で `spanYearRow`（週の行に落ちない）。行の高さが 1 ページの行と同じ。札の字が題名と同じ作り、狭いときの縮め方（数字だけ・出さない）を ja・en・de で、iPhone 縦の開く大きさと iPad 横で。貼り付き（左へ出た札が左端に残る） | MP4 |
| P | `PDFMonthYearTests.swift` | 横の道の月の PDF に、隣から入るメモの線の紙の中の部分が出る（矩形が下まで）。年の PDF に隣の年の線の紙の中の部分。1 ページの道の PDF は今と同じバイト | MP3 |
| Z | `InkCanvasMonthYearTests.swift`（`InkCanvasSpanTests` の rig を写す） | 月・年の窓でキャンバスの紙が窓になる（`paperView.span` が nil でない）。ずらしの前後で見えている線の画面の位置が 0.5 pt 以内で同じ（月の行の高さが違っても）。月・年の等倍が fit（横の道と 1 ページの道）、幅が変わると fit を追う、ピンチで状態が消える | MZ1 |

### 11.3 UI テスト（U）

| ファイル（新しい） | 道 | テスト |
| --- | --- | --- |
| `SpanMonthYearUITests.swift` | ui-tests（iPhone 17）。ログ `span-my UI:` | 月のページを `--screenshot-span on` で開く → 2 本指で横に動かすと題名が 1 回だけ変わる → 境目を真ん中にして、指 1 本でメモ欄に線を引く → probe で保存されたページの `memo` に x < 0 か x > 1,400 の点がある → ‹ › で 1 か月すべり、キャンバスの識別子が変わらない（作り直していない）。年でも同じ（12 月 → 1 月）。設定の写真モードの切り替えでオフにすると 1 ページの道（`path=one`）、オンに戻すとつながる。年で等倍を押す → `zoom: reset` の行が fit（縦では状態だけ） |
| `SpanMonthYearShotsUITests.swift` | 新しいジョブ span-shots-my（§12.4） | §12.4 の写真 |

- 既存の UI テストは写真モードの既定（1 ページの道）なので、月・年の答えは変わらない見込み（`YearTapUITests`・`HeaderAndPaperUITests.swift:52-80`・`EraserAndBelowDayUITests` の月）。
- `ZoomResetUITests` は R0y（§8.5）。

### 11.4 そのまま通すテスト（変えない）

- `TESTS_1_2_3`（8）・`FIXTURES_1_3`（37）・新しい `TESTS_1_4_2`（15 の候補）の全部。`TESTS_1_3`（29）・`TESTS_1_4_1`（16）の §8.5 に名前の無い行の全部（とくに `PaperViewTests`・`WeekMemoPaperSpanTests`・`PaperSpanTests`・`PaperSpanFrozen123`・`ScreenshotModeSpanTests`・`SpanSessionTests`・`InkCanvasSpanTests`・`EventStoreModelSpanTests`・`SpanGuideSeenSpanTests`・`StageTwoNoticeSpanTests`・`SpanShotsUITests`・`SpanRerunUITests`・KitChecks の 4 ファイル、`InkCanvasSpanZoomResetTests`・`InkCanvasWidthCentreTests`・`PaletteMoveButtonTests`）。
- KitChecks（数は増える）、compat10・compat-span・span-compat・Real10/123/13、保存のバイトの関門 2。
- 1.4.2 の数（基準。`docs/R1_4_2.md` の V、run 45721608435）: 単体 **975**（飛ばし 2・失敗 0）、Kit のテスト **364**、UI tests (iPhone) **78**（飛ばし 24・失敗 0）、iPad 13 の Palette UI の段 **6**（飛ばし 1）、同期の繰り返し 4,000。1.4.3 の新しいテストの分だけ増える（数は run で書く）。

### 11.5 変異

- **Kit の変異は手元の `swift run KitChecks`**（CI を使わない。M7D §6 の置き場所）: MK1 `monthFloors` が `.shift` で下げる、MK2 `PageScroll.scrollDelta` が月でも真ん中の答えで比べる、MK3 `yearFloors` が隣の年を見ない、MK4 MonthLayoutInput が `memoLineFloor` を読まない。どれも `SpanMonthYearChecks` が落ちる。
- **アプリの変異は 1 本の枝 `r143-q-m1`**（取り込まない）。落ちるはずのテストの表 `tools/mutations/m1-expected.tsv`（変異の枝にだけ置く）を run の前に書き、頭に変異ごとの場所（ファイル:行）と書き換える字を書く。**落ちたテストが表とちょうど同じなら ○**。UI テストは速い道で走らないので、変異は単体テストで捕まる物にする。

| 変異 | 中身（場所と書き換え） | 落ちるはずのテスト |
| --- | --- | --- |
| MS1 | `ScreenPaths.joins` の guard を `kind == .week || kind == .day` に戻す | `SpanKindsTests`・`ScreenPathsMonthYearTests`・R0 した `ScreenPathsSpanTests` |
| MS2 | `ScreenPaths.focus` の月・年の規則を消し、今の式にする | `ScreenPathsMonthYearTests` |
| MS3 | `SpanSession` が年で `allDayOnly` を渡さない | `SpanSessionMonthYearTests` のみ（`EventStoreModel` は変えないので `EventStoreModelYearTests` は通る） |
| MS4 | `ZoomReset.followsFit` を週・日だけに戻す | `ZoomResetMonthYearTests`・R0 した `ZoomResetTargetTests`・`ZoomFitWiringTests`・`SpanKindsTests` |
| MS5 | 月の `todayRect` を今の「ページの幅全部」に戻す | `ScreenPathsMonthYearTests` |
| MS6 | `layoutPages` の月・年を `break` に戻す | `SpanSessionMonthYearTests` |
| MS7 | `relayoutPages` が月のメモを見ない | `SpanSessionMonthYearTests` |
| MP1 | `PaperSpan.window` が月・年で nil | `PaperSpanMonthYearTests`・`InkCanvasMonthYearTests` |
| MP2 | `MonthPaper` が区切りの線を `memo.minY` から描く（`memoLine` を読まない） | `MonthPaperLineTests` |
| MP3 | `PDFPageRenderer` の月の枝が隣の線を見ない | `PDFMonthYearTests` |
| MP4 | 見出しの `.month` を `spanWeekRow` に落とす | `StickyHeaderMonthYearTests` |
| MZ1 | （R3 の後の木で）`InkCanvasView.paperSpan` の本体を、今の週・日だけの中身に戻す（凍結のファイルの変異は枝の中だけ。DATA_1_1 の段はこの枝で落ちてよいので、表の外として読む） | `InkCanvasMonthYearTests` のみ（`PaperSpan.window` は変えないので `PaperSpanMonthYearTests` は通る） |

- 表と違うテストが落ちたら理由を書く（R1_4_2_CONTRACT §6.4 と同じ形）。

---

## 12. CI と写真

### 12.1 CI の道（0g-40）

- **枝の配線（D0、C）**: `r143` の名前を足す。`branches-ignore` に `r143-duo*`（`build.yml:103`）、速い道 `QUICK` に `r143-quick`・`r143-q-*`・**`r143-w-*`**（:161。作る役の枝を上げても通しの run を起こさない）、`MUTATIONS` に `r143-q-m1`（:167）、ジョブの `if:` の速い道の字（:1732・:2559・:3136・:3720）に同じ名前（**:2179 の compat-v1.0 だけは形が違い、`(startsWith(github.ref_name, 'r143-q-') && github.ref_name != 'r143-q-m1')` の形で足す**）、言語の写真の段に `r143`（:4417-4419・:4506）、duo.yml に `r143-duo*`（`duo.yml:43`）、ja-baseline.yml の `FILE=`（:119-126）。`r13`・`r14`・`r141`・`r142` の名前は残す。
- **写真を撮る枝に `q-` を付けない**: `r143-q-*` と `r143-w-*` は速い道で、写真の段とジョブが走らない。見本の写真の枝は `r143-alt`、写真だけの試しの枝は `r143-shots<n>`。
- 速い道の単体テストの組（`build.yml:688-694` の一覧）に、§11.2 の新しい単体テストの組を名前で足す。
- ui-tests（iPhone 17）に `SpanMonthYearUITests`。grep に `span-my UI:` を足す。
- D0 で `TESTS_1_4_2` の段、D1a で `FIXTURES_1_4_3` の段と compat-span-143 の読み手の段。
- duo.yml: 月・年も横の道で撮る（:901・:910 の `case "$KIND" in week|day)` を 4 種に。:916 の一覧の回しに月・年を足し、外側の年は上限 3 で撮る）。「SpanKinds.joined と同じ」の注。
- **新しいジョブ span-shots-my**（§12.4）。span-shots-app はもう 107 分 47 秒 / 120 分、4 機種の段は 83 分 / 90 分（`docs/R1_4_2.md:1094`）で余りが無いので、同じジョブに足さない。macOS のジョブは同時に 5 つまで（今 6 つ）なので待ちが増える。C は「通しの run の時間を 30 分より多く延ばさない」「どのジョブも上限に 10 分以上の余りを残す」の 2 つを守る形を決めて記録する（写真の数を減らす、ジョブの順を替える、blank-paper と分け合う、など）。
- 理由: 新しいテストを毎回の道で走らせ、写真は通しの run だけで撮る。

### 12.2 J-4 の基準と違ってよい所（0g-41）

- 新しい基準 `tools/l10n/ja-baseline-ref-1.4.3.txt` = `57ffd0f418d66dbf2e669a8313d773e2e97a09e2`（ビルド 32、1.4.2 の公開したビルド）。`ja-baseline.yml` の `FILE=` をこれに。前の `-1.4.2.txt` などは記録として残す。
- J-4 の `screenshots` を撮る今の写真の段は、`build.yml` と `ja-baseline.yml` で同じ字のまま（1.4.3 はその段を変えない）。**§12.4 の新しい写真は `screenshots` に入れず別の成果物にし、`ja-baseline.yml` には足さない**（`compare_shots` は片側だけの写真で落ちる、R1_4_2_CONTRACT §7.1）。
- 合否は、同じ UTC の日に撮り、2 つの env.txt の Xcode と**実行環境の版（runner image）が同じ組でだけ**決める（1.4.2 の V では同じ run の中でも 20261104.0337.1 と 20261123.0387.2 がまざった、`docs/R1_4_2.md:1086`）。run が UTC の 0:00 をまたいだら、2 つの日の基準の両方で比べる。版が違えば、同じ版の基準を取り直す。
- **D0（CI だけの commit）**: 違ってよい強い差は `ipad13-portrait-sheet-info.png` の版の字（「1.4.2 (1)」→「1.4.3 (1)」）だけ。
- **機能の commit（D1〜D2）で違ってよい所**（D0 の前に `docs/R1_4_3.md` に行の範囲で書く。行は S0' の控えの写真で測る）:
  1. `ipad13-portrait-sheet-info.png`（版の字。1.4.2 の行は y 1607–1631）。
  2. `ipad13-portrait-sheet-sync.png`: 設定 › ページ の節（1.4.2 の測りで帯 716–1332 の中の 990–1291、`docs/R1_4_2.md:73`・:82）。脚注の新しい字で強い差が出る。
  3. `ipad13-portrait-sheet-settings.png` と `store/ipad13/06-settings.jpg`: 差は 0 の見込み（ページの節は写らない）。それでも宣言する。
  - **これ以外は強く違ってはいけない**。とくに、1 ページの道の月と年の全部の写真（`*-portrait-month*`・`*-portrait-year*`・`*-landscape-month*`・`*-landscape-year`・`*-month-memo`・`zoom2`・`readonly`・店の JPEG の 01-month・02-month・04-year）は、1.4.2 と画素が同じであること（1 ページの道は札も境目の線も出さない、§4.3・§4.4・§5.3）。
  - 違ってよい所は `tools/shots/shift_pair.swift --exclude-rows <行> --max-strong 0` で示す。
- 理由: 1.4.3 は横の道だけを変え、写真モードの既定は 1 ページの道なので、J-4 は「1 ページの道は同じ」を強く示せる。

### 12.3 関門 3（紙の領域）

- 既定の写真の `toolbar: paperArea=` の値の組と、span-shots-app の状態の行 71 本（`pages`・`zoom`・`ox`・`oy`・`span cap:`。時間の欄 `waited=` を除く）が、**基準の run 45721608435** と同じ。`header room:` の 7 種と `zoom: reset` の 32 行も同じ。
- 新しい写真（月・年の横の道）の `paperArea=` は、同じ置き場所の 1 ページの月・年と同じ（見出しの高さが同じ、§3.8）。違えば止める。新しい状態の行（`span-shots-my` の `pages`・`zoom`・`ox`・`oy`・`span cap:`）は V の run を基準として記録する。

### 12.4 新しい写真（J-4 の組の外。0g-31）

- **新しいジョブ span-shots-my**（成果物 `span-shots-my`。`SpanMonthYearShotsUITests`）。数は D1b の前に C が `docs/R1_4_3.md` に書き、ジョブの「N expected」の行に。候補:
  - ipad13・ipad11・ipadmini・iphone69 の縦の月と年: 一覧（`--screenshot-span on`）と境目を真ん中（`--screenshot-offset-x -0.5`、`--screenshot-span-crossing all` のまたぐ見本つき）。
  - ipad13・ipad11 の横（XCUI の回転）の月と年の一覧。iphone69 の横の月の一覧と、年の上限 3 の一覧。
  - 等倍の前と後（`--screenshot-zoom fit`）: 4 機種の縦の年、ipad13・ipad11 の横の月と年、iphone69 の横の月と年。
  - ずらしの前と後の組（`--screenshot-span-shift 1`）: ipad11 の縦の月で、見出しの札を除いた 2 枚の差がほぼ 0（§3.5 の y の補正）。`tools/shots/shift_pair.swift` で読む。
  - 古い版の見え方（`--screenshot-single-page --screenshot-span-crossing all`）: iphone と ipad13 の月と年。新機能の文と SUPPORT の「紙の端で切れる」の根拠（B_DESIGN §4.3）。
  - 月の PDF 1 枚（隣から入るメモの線）。
  - 案内の札（`--screenshot-span-guide one|two`）: 月と年の ja。de・fr・疑似の言語の月の札（言葉の長さ）。
  - メモ欄の紙のドット方眼で、つないだ月の境目（`--screenshot-memo-paper dots`）: ipad13 の縦（1.4.2 の約束「境目でも点の間隔はそろう」の写真）。
- **span-shots-app-languages**（今の成果物）の 設定 › ページ の写真（`SpanShotsUITests.swift:332`、10 の言語）は、脚注の新しい字で変わる。J-4 の外なので、リードが目で比べ、字が新しい訳であることを確かめる。
- 写真モードの新しい引数（§2.1）は既定値つき。引数を付けなければ、今の写真は 1 バイトも変わらない（凍結の `ScreenshotModeSpanTests` で守られる）。
- 新しい写真は、リードが比べる（自動では落とさない。`ok=no` は警告）。**確認ページと見本のページに使う写真は、リードが目で見て、仕込んだ手書き・札・境目の線が写っていることを確かめる**（§1.5）。

### 12.5 見本の写真（段 P。`r143-alt`。取り込まない。0g-43）

- 使い捨ての枝 `r143-alt`（`r143` に D1a と D1b を入れた木から切る）に、DEBUG だけの引数 `--screenshot-month-form a|i|u` を作る（`r143` にも main にも入れない）。枝の名前に `q-` を付けない。写真はその枝の `build.yml` に足す写真だけの段で撮り、別の成果物にする。その run は J-4・関門 3・D1 の関門の合否に数えない。run の番号と写真を `docs/R1_4_3.md` の P に書く。
- 撮るもの（同じ見本の手書きと予定。`--screenshot-month-tall` で右どなりの月の行を高くし、3 通りの違いが見えるようにする。今の見本ではどの月も格子の高さが同じ 1,063 lu で、3 通りの写真がほとんど同じに見える、`ScreenshotMode.swift:735-771`・:831-860）:
  - 月の 3 通り × ipad11 の縦（境目を真ん中）・ipad11 の横の一覧（XCUI）・ipad13 の縦（境目を真ん中）・iphone69 の縦（境目を真ん中）。
  - 月の等倍の前と後: ipad13・ipad11・ipadmini の横、iphone69 の横（縦は同じ見た目なので 1 枚だけ添える）。
  - 年の行のそろえの前と後、年の等倍（4 機種）は、D1y の木がそろっていれば足す（間に合わなければ確認ページ）。
- 送り方: リードが写真を目で確かめてから、**1 つの Artifact のページ（非公開）**にして本人へ送る。頭に「選ぶのは月の並べ方だけ（ア・イ・ウ）。何も言わなければア。年と等倍は見るだけ」。ア・イ・ウの気になる点（イは隣の月で行が伸び一覧の下限が下がる、ウは区切りの線と下端がずれる）を 1 行ずつ添える。1.4.2 の約束（メモの点は境目でそろう）がウではメモの行に当たらないことも添える。
- 答えは `docs/R1_4_3.md` の「本人の言葉と選び」に、そのまま・時刻つきで写す。**V を始める時（12/8 めど）までに答えが無ければア**。イ・ウなら `SpanAlign.monthForm` を替え、D1b の関門（月の単体テストと写真）をやり直してから V。V の後の答えは §14.4 の「やり直す行」。

### 12.6 店の写真（撮り直す物。0g-39）

- **撮り直す**: 月と年の写真を、横の道（`--screenshot-span on`、境目は動かさない一覧）で、16 ロケールの全部（ja を含む）:
  - iPad 13 インチの `01-month`・`04-year`、iPhone 6.9 インチの `02-month`・`04-year`（6.3 インチの枠は 6.9 の写真を `sips` で縮めた物で、同じく替わる）、Duo の外側の `02-month`・`04-year`（store-duo）。
  - 理由: 設定の既定（オン）では、月の見出しに札が出て、iPad の年は左右に隣の年が見える（今の写真は 1 ページで、机の色の余白）。1.4.1 で、見える画面が変わったのに店の写真を撮り直さず、本人の訴えで撮り直した（R1_4_1_CONTRACT §7.6、`docs/R1_4_2.md:1020`）。同じ失敗を繰り返さない。
- **撮り直さない**: `00-span`（週の横つなぎ）・`02-week`・`03-day`・`01-week`（1.3 の D26 の形のまま。1.4.3 で変わらない）、`06-settings` などのほかの写真。
- 写真は**確かめた commit（V）で**、store-shots.yml で撮る（`store-shots.yml:425-435` の回しで、`month` と `year` に `--screenshot-span on` を足す。ja の組も月と年を撮る。C）。今の店の写真と画素で比べ、違う所（札・隣の年・状態バーの日付）を `docs/R1_4_3.md` に書く。手書きの確かめ（`ink_ref.tsv`、Duo の `duo_store.py`）の行は、新しい写真の行を C が足す（足すまでは写真どうしで比べる今の形）。
- D3 の確認ページで見せ、D4 で本人の「この内容で入れてよい」のもとで Connect に上げる（道具は T0 の `shots143.py`。16 ロケール × 枠 × 2 枚と Duo）。
- `build.yml` の店の JPEG（J-4 の組の `store/<機種>/01-month` など、:1602-1621）は 1 ページの道のまま（J-4 の比べのため）。Connect に上げる写真は store-shots.yml の物。
- B_DESIGN §9.4 の「段ごとに、またいで書いた見本の写真を店に足す（月はメモの帯、年は年をまたぐ線）」は、足さない（16 ロケール × 3 枠の写真が 1 枚ずつ増え、月・年の写真はページそのものに見えた方がよい）。またいで書く見本は `00-span`（週）が受け持つ。

### 12.7 控え（S0'）

- 1.4.2 の V の run 45721608435 の成果物（`screenshots` 15109405563 ほか）と、Duo の `duo-shots` 15086312697 は **12/3 ごろに消える**（7 日）。ja-baseline の `ja-baseline-fbd1f7a` 15089105306 は 12/26（`docs/R1_4_2.md:15`）。
- **D0 の前（遅くとも 11/30）に**、V の run の `screenshots`・`ui-tests`・`l10n-screenshots`・`blank-paper`・`span-shots-app`・`span-shots-app-languages`・`palette-shots`・`memo-paper-shots`・env と、Duo の `duo-shots` を `~/.local/share/tegaki-backup/<日付>/r143-base/` へ控え、`unzip -t` で確かめる。main の run 46040646988 が緑なら、その成果物も同じコードの控えとして足してよい。関門 3 の基準（`paperArea` の組・状態の行 71 本）と、§12.2 の画素の行の測りと、確認ページの前と後に使う。

---

## 13. 文字・訳・App Store

### 13.1 アプリの文（0g-33〜0g-35）

**新しい文（4 キー。`app-U.json`、`span.guide.*` の並び :2313-2356）**:

| キー | ja | 注 |
| --- | --- | --- |
| `span.guide.month.oneFinger` | 前後の月が横につながりました。指で横にすべらせると、となりの月が出てきます。下のメモ欄は、月の境目をまたいで、そのまま書けます。 | 月の札（N-4 の月）。「指でも書く」オフ |
| `span.guide.month.twoFingers` | 前後の月が横につながりました。2 本指で横にすべらせると、となりの月が出てきます。下のメモ欄は、月の境目をまたいで、そのまま書けます。 | 「指でも書く」オン |
| `span.guide.year.oneFinger` | 前後の年が横につながりました。指で横にすべらせると、となりの年が出てきます。境目をまたいで、そのまま書けます。 | 年の札。「指でも書く」オフ |
| `span.guide.year.twoFingers` | 前後の年が横につながりました。2 本指で横にすべらせると、となりの年が出てきます。境目をまたいで、そのまま書けます。 | 「指でも書く」オン |

- 足す時: 月の 2 つは D1b、年の 2 つは D1y で、作る役 S が ja と 9 言語の**仮の訳**を書いて足す（速い道の lint L-2 は 10 の言語がそろうことを求め、ja だけのキーでは速い道が赤になる。1.4.1・1.4.2 の前例、`docs/R1_4_2.md:233`・:327。§2 の「1 つのファイルの持ち主は 1 つの役」の外れとして記録する）。D2 で X が GLOSSARY に照らして訳し直す。

**ja を替える文（1 キー。本人が承認した固定の文。0g-34）**:

| キー | 今の ja（`app-U.json:1837`） | 新しい ja（案） |
| --- | --- | --- |
| `settings.page.span.footer` | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | 週・日・月・年のページで、前後のページが横につながり、境目をまたいで書けます（月のページでは、下のメモ欄でまたげます）。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 |

- 落とし所（0g-3）のとき: 「週・日・月のページで、…（月のページでは、下のメモ欄でまたげます）。年は、次の版で対応します。オフにすると、…」。D2 の文は、落とし所を決めた後（12/5）に 1 通りだけ書く。
- D2 で、落とし所を決めた後（12/5）に、X が ja と 9 言語の訳を 1 つの commit で替え、その直後に S が R0f（`SettingsPageSectionTests.swift:19`・:135 の字、§8.5）を入れる（2 つは同じ取り込みで `r143` へ。間で CI を回さない）。
- 同じキーの ja を替える（前の字の扱いと `was` は X が lint の決まりで）。jaSha1 が替わるので 9 言語を訳し直す。この鍵は J-1（`ja-baseline.tsv`）に無い【事実: 地図】ので、J-1 は変えない。comment の「2 つ目の文（月と年）は本人が承認した固定の文で…」は「1.4.3 の文は本人が確認ページ（<日付>）で承認した文」に直す。
- 本人が確認ページで違う字を望んだら、その字にして R0 の `SettingsPageSectionTests` の字と訳をやり直す（V のやり直し）。

**comment だけ替える（ja の字と jaSha1 は同じ）**:
- `settings.page.span`（`app-U.json:1828`）: 「月と年は 1 ページずつのまま」→「4 種のページが横につながる（1.4.3）」。
- `header.zoomReset.spoken`（`app-P.json:447-455`）: 等倍の定義を「日・週・月・年とも 1 ページの幅が画面の幅にちょうど合う大きさ（月と年は 1.4.3 から）」に。読み上げの字「等倍に戻す」は変えない。
- comment だけの鍵は lint と build.py が古い訳を知らせない。訳を見直す要るかを X が判断して記録する（画面の字は替わらないので、既定は訳し直さない）。

- アプリのコードに日本語の字を書かない（L-1）。月の札・年の札は題名と同じ作りで、新しい文は無い。

### 13.2 訳と逆翻訳（X・R）

- GLOSSARY を先に直す（X）: 新しい §7「1.4.3 の語」（月の札・年の札・「メモ欄でまたげる」の言い方、月と年の横つなぎの語を週・日の札の今の訳にそろえる）。§5 の等倍の定義（`docs/i18n/GLOSSARY.md:237-302`）を「4 種とも幅にちょうど」に直し、「Fit の語を名前に使わない」の理由（今は「月と年は幅に合わせないため」）を、名前はそのまま（Reset Zoom）で理由だけ替える。
- 9 言語の訳（X）→ 元を見ない逆翻訳（R、`docs/i18n/back` の新しいファイル。例 `app-1_4_3.md`・`store-1_4_3.md`・`store-1_4_3-en.md`）→ 判定の 2 役 → `docs/i18n/REVIEW.md` の**新しい節 19（アプリ）・20（店と Web）**を作り、× を 0 に。
- 確かめ: `lint.py`（L-1〜L-14）、`build.py --check`、`baseline.py --check`、CI の「Localized bundle check」（`build.yml:590`）、testflight の「Every word of the app in ten languages」（`testflight.yml:106`）。アプリの文は `tools/` の下なので、**確かめた run（V）より前に**済ませる。
- 言語ごとの確認表は、確認ページ 1 回の中で見せる。

### 13.3 新機能の文（16 ロケール。0g-36）

**案**（D2 で訳と逆翻訳。確認ページで全部の行を見せ、「この内容で入れてよい」は全部の組み合わせに効く）:

> ・月と年のページも、前後のページと横につながりました。指で横にすべらせると、となりの月（年）が続いて出てきます（「指でも書く」がオンのときは、2 本指で横に動かします）。月は下のメモ欄で、年は 12 月から次の年の 1 月へ、境目をまたいでそのまま書けます。
> ・月と年の等倍（虫めがねに「1」のボタン）も、日と週と同じく、1 ページの幅が画面の幅にちょうど合う大きさになりました。
> ・iPad と iPhone の両方をこの版にしてください。古い版では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。古い版でその線を消すと、こちらでも消えます。

- 3 つ目の点は K-8 の文（B_DESIGN.md:413）そのまま（1.3 の ja の新機能の文の最後の点と同じ字）。
- 落とし所（0g-3）のときは、1 つ目と 2 つ目を「月のページも…」「月の等倍も…」にする。
- ja は `docs/store/ja/whatsnew.txt`、ほかは `docs/store/source-ja/whatsnew.txt` から 11 の訳、en-GB・en-AU・en-CA は en-US の、fr-CA は fr-FR の写し（`docs/store/README.md:60-64`）。ja 以外は最後の行が AI の訳の断り（1.4.2 と同じ字）。4,000 字まで。アプリの語（「指でも書く」「等倍」「メモ欄」）はその言語のアプリの訳と同じ字（X が写す）。
- プロモーションテキストは新しい版で空になるので、今の文を入れ直して読み戻す。`docs/store/README.md` の新機能の文の表に 1.4.3 の行を足す。字の選びは `docs/store/PROPOSALS_1_4_3.md` にまとめる（脚注の字を含む）。

### 13.4 審査メモ（`docs/store/review-note.txt`。英語が主で日本語の要約、4,000 バイトまで。0g-37）

- 今は 3,665 バイト【事実: `wc -c`、11/28】。「What is new in 1.4.2」の段を「What is new in 1.4.3」に入れ替え、日本語の要約（`--- 日本語の要約 ---` の下）の 1.4.2 の文と新機能の行を 1.4.3 の物に入れ替える。**ほかの段は 1 バイトも替えない**。
- 書くこと（英語。アプリの en の字は D2 の訳に合わせる）:
  1. Month and year pages now join sideways with the pages before and after, as week and day pages have since 1.3. On a month page, handwriting can cross from one month to the next in the notes area below the calendar; on a year page, from December into January of the next year. Settings > Pages turns it off.
  2. The 1× button (a magnifier with "1") now fits one month or one year page to the screen width, as it does for days and weeks.
  3. To check: open a month page and swipe left with one finger (two fingers on iPhone when "Use Finger" is on), then write across the boundary in the notes area. Stroke data is unchanged; App Privacy stays "Data Not Collected".
- 入れ替えた後のバイト数を `docs/R1_4_3.md` に書く。4,000 を超えたら英語の 1 を短くする（ほかの段は替えない）。英語の新しい文は元を見ずに逆翻訳する（`docs/store/README.md:94-96`）。1.4.1 の 0e-28 の教訓（「新しい文は設定と読み上げだけ」のような言い方をしない。案内の札と脚注の字が画面に出る）。

### 13.5 SUPPORT（日本語・英語。W。公開の日に Web へ。承認は確認ページの 1 回。0g-38）

- `docs/SUPPORT.md:7`・`docs/SUPPORT.en.md:11` の最終更新の日（公開の日に、リードの段）。
- 「**拡大・縮小するには？**」（`SUPPORT.md:149-153`）の 2 段落目: 「日と週のページでは…月と年のページではそのページを初めて開いたときの大きさになります」を、「日・週・月・年のどのページでも、1 ページの幅が画面の幅にちょうど合います（月と年は 1.4.3 から）。縦の iPad の月のように、開いたときにもう幅がちょうどのときは見た目は変わりませんが、等倍として覚え、横にすると幅にちょうどになります」の形に（W が字を決める）。1 段落目の「月と年のページは、予定や手書きの量によらず同じ大きさで開きます」はそのまま正しい。
- **新しい FAQ 1 つ**「**月と年のページで、となりのページへ続けて書くには？**」（「拡大・縮小するには？」の前か後。W が置き場所を決める）: 月と年も前後のページと横につながる（1.4.3 から。週と日は 1.3 から）。指で横にすべらせる（「指でも書く」がオンなら 2 本指）。月の表と表の間では日付は続かない（右どなりは 4〜5 週あと）。月の境目をまたいで書けるのは下のメモ欄。月末から月初へ日付どおりに書くのは 1 つの表の中か週のページ。前後の月の薄い日は両方の表に出て、書いたものは表ごとに別々。格子の短い月では区切りの線の上に白い紙が入る（メモ欄の一部）。年は 12 月の右に次の年の 1 月、行の高さは隣の年とそろう。iPhone を横にした年の一覧は 3 年分まで。設定 › ページ でオフにできる。
- 「**メモ欄の紙を替えるには？**」（:183-185）の「横につながった週と日のページでも同じです」→「横につながったページ（週・日・月）でも同じです。月のページでは、となりの月と点や罫線の高さがそろいます」。
- 「**iPad と iPhone で版が違うと？**」（:191-195）に 1 文: 1.4.3 で月と年の境目をまたいで書いた線は、1.4.2 までの端末では保存されたページにだけ出て、紙の端で切れて見える（消えてはいない）。古い版で消すと新しい版でも消える。
- 既知の制限「**マスをまたぐ手書き**」（:246）の「（月と年のページは今までどおり 1 ページずつです）」→「1.4.3 から月と年のページも（月は下のメモ欄で）」。
- 英語の `SUPPORT.en.md`（:158・:251 ほか同じ所）も同じ。新しい英文は元を見ずに逆翻訳する。
- Web: 手元の枝 `r143-legal` を Web main 4a9fbf3 から作り（D2）、公開の日に早送りで送る（1.4.2 の `r142-legal` と同じ形）。公開の道具の確かめに「Web の SUPPORT 2 ページが新しい文になっている」を入れる。

### 13.6 文書（リード）

- `docs/DESIGN.md`: 等倍の行（:218 の「月と年は…」）、月・年の横つなぎ（月のメモの帯・札・境目の線・年の行のそろえ・年の札）を足す。
- `README.md`: :60 の等倍の行、月・年の横つなぎ、新しいファイル（`SpanKinds.swift`）。
- `docs/M7_PLAN.md` §4: この契約の第 1 版で「次の版」の行を 1.4.3 にして契約を指し、1.7・1.8 の行に「1.4.3 へ移した」を足した。時期と出した日はリードが記録の段で直す。
- `docs/B_DESIGN.md` の頭に 1 行の注（「1.4.3 で B-2・B-3 を作った。約束は R1_4_3_CONTRACT.md。§3.4 のアの作りと §6.3 の段 1 は契約で違えた」）。本文は記録として残す。

---

## 14. 段取り・役・出し方

### 14.1 段と目安の日（2026-11-28 時点。`docs/R1_4_3.md` に実績を書いて直す）

CI の時間の見込み: build.yml は 1 回 90〜110 分（macOS のジョブは 5 つまで同時）。build-and-test の上限 160 分、UI tests の段 45 分。**通しの run を 2 つ同時に走らせない**。

| 段 | 目安 | 中身 | 関門 |
| --- | --- | --- | --- |
| S0 | 11/28 | この契約。`docs/R1_4_3.md` の骨組みと前もっての宣言（基準の数を V の run 45721608435 から写す、J-4 の違ってよい所、KitChecks・compat・単体・UI・写真の数が増える見込み、R0 の行の一覧の下書き）。1.4.2 の main の run 46040646988 と日本の店の表示が `docs/R1_4_2.md` にあることを確かめる。中国の 2027 年の祝日と M7C_CONTRACT §8.6 を見る（§1.5）。本人に §0 を平たく伝える | リードが契約を読む。記録がある |
| S0' | 11/28〜11/30（D0 の前、成果物が消える 12/3 より前） | §12.7 の控え。§12.2 の画素の行を控えから測る | 控えの数と大きさを記録 |
| D0 | 11/28〜11/29 | CI だけの commit（`r143`）: 枝の配線、J-4 の基準のファイル、`MARKETING_VERSION "1.4.3"`、`TESTS_1_4_2` の表と段。`Sources`・`TegakiKit/Sources`・`Tests` は 57ffd0f と同じ | 下の D0 の関門 1〜8 |
| D1a | 11/28〜11/30 | Kit（K）: `SpanAlign` の月・年の下限と `MonthForm`、MonthLayoutInput・YearLayoutInput の下限、`MonthPageLayout.memoLine`、`PageScroll` の月、`SpanMonthYearChecks`。互換の新しいフォルダと表と読み手（C）。画面に出ない部品なので、段 P の答えを待たずに作る（M7C_CONTRACT §15 の 4 の読み） | **作る役の commit の後に 2 つの目（型とテスト／契約と B_DESIGN）で見直し、must を 0 にしてから `r143` へ取り込む。指摘と決めたことを `docs/R1_4_3.md` に書く**。`swift build`・KitChecks が緑（数は宣言どおりに増え、今の答えは同じ）。通しの run で compat の新しい数、`FIXTURES_1_4_3` の段、J-4 は D0 と同じ、関門 3 が同じ |
| D1b | 11/29〜12/3 | 月（S・P・Z・U）: `SpanKinds`（[週・日・月]）、`joins`、セッションの月の下限、`PaperSpan.window`、**R3**（§8.4）、境目の線、`spanMonthRow` と月の札、焦点、今日、月の PDF、月の案内の札、月の等倍、写真モードの引数、**R0m**（§8.5）、`span-shots-my` の月の写真、新しい単体テストと UI テスト | **D1a と同じ 2 つの目の見直しで must を 0 にしてから取り込む**。R3 は §8.4 の手順 4・5、R0m は §8.5 のリードの 1 行ずつの見直し。新しいテストと R0 したテストが緑、§8.5 のほかの守りがそのまま。J-4 は宣言の行だけ。関門 3 が同じ。保存のバイトが同じ。月の写真をリードが目で確かめる |
| P | 12/1〜12/3（D1b の月の写真がそろいしだい） | 見本の写真（§12.5）を本人へ | 送った日時を記録。**V を始める時までに答えが無ければア**。イ・ウなら `SpanAlign.monthForm` を替え、D1b の関門をやり直す |
| D1y | 12/1〜12/5 | 年（K・S・P・U）: `SpanKinds` に年、年の下限、`spanYearRow` と年の札、iPhone 横の上限の今日、年の予定（終日だけ）、年の PDF、年の案内の札、年の等倍、**R0y**、`span-shots-my` の年の写真、`SpanWeightLogTests` | D1b と同じ。重さの測りが記録にある |
| 決め | 12/5 の朝 | **落とし所（0g-3）**: D1y が取り込みの関門を通っていなければ、リードが月だけの 1.4.3 に切る（`SpanKinds` から年を外したまま、R0y を作らない、文は月だけ）。本人にその日のうちに知らせる | 決めたことと理由を記録 |
| D1c | 12/4〜12/6 | 変異（`r143-q-m1`、§11.5）と Kit の変異（手元）と Duo（duo.yml `r143-duo1`） | 変異で落ちたテストが表とちょうど同じ。`DuoLayoutUITests` と `shot_checks` が緑、月・年の横の道の Duo の写真がある |
| D2 | 12/4〜12/8 | 文（§13）: GLOSSARY、4 キーの訳し直しと脚注の新しい字の訳・逆翻訳・判定・REVIEW 19、脚注の **R0f**（§8.5）、2 つの comment、lint・build.py・baseline.py・バンドル。SUPPORT の日英と `r143-legal`、16 ロケールの新機能の文、審査メモ、PROPOSALS、文書 | 確認ページの材料がそろう。REVIEW の × が 0。R0f はリードの 1 行ずつの見直し |
| T0 | 12/4〜12/7 | 道具の移し（0g-46）: `asc142` → `asc143`（ver・whatsnew・enter・submit・release・web support と、**月と年の写真を 16 ロケール × 枠 × 2 枚と Duo で入れ替える `shots143.py`**）、`confirm142` → `confirm143`。guard を 1.4.3 の字と承認した commit に結ぶ。控えは `~/.local/share/tegaki-backup/<日付>/asc143`・`confirm143` | 偽の Connect の試験とオフラインの試しが失敗 0。試験の数を記録（1.4.1 では道具を移した後に契約が変わり、提出の直前に道具が止まった、`docs/R1_4_1.md:641`） |
| V | 12/8〜12/9（D2 の文の commit の後） | 通しの run 1 回（ほかの通しの run と同時に走らせない）。この run の commit を **「確かめた commit」** と呼び、run の番号とともに `docs/R1_4_3.md` に書く。同じコードの Duo の run も。店の写真をこの commit で撮る（§12.6） | 全部のジョブが緑（揺れの読み方どおり）、関門 3、同じ UTC の日・同じ版の J-4（宣言の行の外で強い差 0）、`span-shots-my`・palette-shots・memo-paper-shots の行、Duo の run も緑。この後に `Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` を変えたら V をやり直す |
| D3 | 12/9〜12/10 | TestFlight 1.4.3（ビルド 33 以上。**確かめた commit からコードの差が空の commit で作る**。アーカイブの確かめ `iphoneos27.2`・`17.0`・`1, 2`、Connect で VALID）。確認ページ 1 つ（§0.4 の中身、確かめ表、撮り直した店の写真）。**確認ページの写真は、確かめた run と、同じコードの duo の run の物だけ**。**下書きは、本人・事実・写真の 3 つの目で見直してから渡す**（どの文にも元のファイルの字を確かめる guard）。確認ページの道具の偽の試験を V の後・渡す前に通す。確認ページの最初の画面に、§15 の準備の字を同じ字で書く | 本人の「この内容で入れてよい」。P の選びが既定と違えば、このビルドに入っている |
| D4 | 本人の言葉の後（12/18 まで） | 本人の確かめ表が全部 ○ にそろい（Duo の行は「—」、古い版の行は「—」でもよい）、「1.4.3 を審査に提出して良い」をもらい、確かめた commit とのコードの差が空なら、Connect に版を作って提出（手動公開）。**`submit143.py check` が READY**（ビルド VALID、16 ロケールの新機能の文、プロモーションテキスト、審査メモ、月と年の写真の入れ替えと、ほかの写真の引き継ぎ、年齢区分 4+・新しい問い 0）。新しい問いが出たら止めて本人に聞く | そろって、check が READY |
| D5 | 審査の後 | 審査が通り、「1.4.3 を公開して良い」「まとめて良い」の後に公開 → 公開の日に SUPPORT を Web へ → main へ `--no-ff` → main の CI を見て、**run の番号と結果を `docs/R1_4_3.md` に書く** → 日本の App Store の表示を記録 → 本人の手元の main を `pull --ff-only` | 記録がある |
| 前ぶれ | 12/12 | D3 が渡せていなければ本人に知らせる | — |
| 決まり | 12/18 | 年末の前の最後の提出日の目安。過ぎたら 1/5〜 | — |

**D0 の関門**（全部そろって D1 へ。R1_4_2_CONTRACT §9.1 の関門 1〜8 を、基準のビルド 57ffd0f と基準の run 45721608435 に読み替えた）:
1. 全部のジョブが緑で、数が V の run と同じ: KitChecks 40,826（閾値 40,776）、Kit のテスト 364、単体 975（飛ばし 2・失敗 0）、同期の繰り返し 4,000、UI tests (iPhone) 78（飛ばし 24・失敗 0）、iPad 13 の Palette UI の段 6（飛ばし 1）、compat-v1.0（compat10 631・compat-span real 631・span-compat 274/274/278/310・Real10/123/13 4/4/5）、l10n-shots 80・blank-paper・span-shots-app 64 と PDF 1・言語の写真 60・palette-shots 33・memo-paper-shots 16 と PDF 1。`DATA_1_1`・`TESTS_1_3`・`TESTS_1_2_3`・`TESTS_1_4_1`・`FIXTURES_1_3`・新しい `TESTS_1_4_2` の段も緑（凍結の OK は 121 ＋ 新しい表の行）。
2. 保存のバイト（§8.7 の 3 つ）が作り直さずに同じ。
3. 関門 3（§12.3）が V の run と同じ。
4. J-4: 強い差は `ipad13-portrait-sheet-info.png` の版の字だけ。
5. D0 の木の `Sources`・`TegakiKit/Sources`・`Tests` が 57ffd0f と同じ（`git diff 57ffd0f -- Sources TegakiKit/Sources Tests` が空）。
6. env.txt が Xcode 27.2（27B52）・XcodeGen 2.46.0・iOS 27.2（24B8117）。実行環境の版を書く。
7. 速い道（`r143-quick`・`r143-q-*`・`r143-w-*`）で速い道の組だけが走る（1 回）。
8. duo.yml が `r143-duo*` で起きる（D1c の前に 1 回。合否は D1c で読む）。

**実行機の揺れの読み方**（1.4.2 の V のリードの読みと同じ、`docs/R1_4_2.md:1133-1136`、R1_4_2_CONTRACT.md:901）: 落ちた段は `gh run rerun --failed` で回し直す。**「attempt 3 まで」は、落ちた段ごとの回し直しの数**（run の attempt の番号ではない）。落ちたテストが attempt ごとに違い、どれも別の attempt か前の run で通っているなら、実行機の重さによる揺れとしてコードを変えない。同じテストが 2 回続けて同じ形で落ちたら、本当の落ちとして直す。打ち切り（renewjob timed out・load average の cancelled）は数えない。J-4 の写真の撮り直し（Dynamic Island など状態バーの帯の中だけ）は、揺れの回し直しに数えない。回し直しを使い切ったら、新しい通しの run を起こす（commit の本文に CI を飛ばす印の字を書かない。1.4.2 で run が起きなかった、`docs/R1_4_2.md:35`）。

- 作業の木はスクラッチパッドにあり、毎日 0:00 の掃除で古いファイルが消えうる（worktree の `.git` も消えたことがある）。こまめに commit し、リードが `r143` を GitHub に上げて控えを残す。消えたら `git worktree repair` で戻す。
- Claude の週の使える量が 95% に届いたら、その週は止まる。進み具合を `docs/R1_4_3.md` に残す。

### 14.2 規模

| 部分 | 里程 | 元 |
| --- | --- | --- |
| D0（CI の配線・基準・版・守りの表） | 0.05 | 1.4.2 の D0 の実績 |
| Kit（下限・3 通り・年の行・y の補正・KitChecks）と互換の fixture | 0.3〜0.4 | B_DESIGN §10 の行のそろえ 0.25・月の形の一部に、新しい fixture のフォルダの分 |
| 月を横の道へ（道・セッション・紙と R3・境目の線・見出しと札・焦点・今日・PDF・案内・等倍・写真モード・R0m）とテスト | 0.5〜0.65 | B-3 の 0.7〜0.9 から、1.3 の土台がある分と、段 P の写真の分 |
| 年を横の道へ（行のそろえ・見出しと札・上限・予定・今日・PDF・案内・等倍・R0y）と重さの測り | 0.45〜0.6 | B-2 の 1.0〜1.4 から、作らない重さの対策（約 0.45）を引いた |
| 変異・Duo | 0.05〜0.1 | 1.4.2 の実績 |
| 訳・店の文・SUPPORT・写真（新しいジョブ・店の写真の撮り直し）・確認ページ・道具 | 0.3〜0.35 | 1.4.2 の実績に、店の写真 16 ロケールの分 |
| **合計** | **1.65〜2.15** | 月と年を 1 つの版にまとめた節約（約 0.3、B_DESIGN §9.1）を含む。1 里程 ≈ 1.5 週だが、1.3〜1.4.2 の実績はずっと速い。**目安 2 週**。日程は CI（1 回 90〜110 分、同時の上限 5）と本人の確かめが律速 |

### 14.3 役

| 役 | 仕事 | 持ち物 |
| --- | --- | --- |
| C | CI・版・J-4 の基準・道の配線・守りの表・写真のジョブ・互換の新しい fixture と読み手・店の写真の撮り方 | §2 の C の行 |
| K | TegakiKit の Layout（下限・3 通り・年の行・y の補正・`memoLine`）と `SpanMonthYearChecks`・Kit の変異 | §2 の K の行 |
| S | 道とセッションと画面: `SpanKinds`・`ScreenPaths`・`SpanSession`・`CalendarRootScreen`・`SpanGuide`・`ZoomReset`・`EventStoreModel`・`ScreenshotMode`・R0 の S の行・その単体テスト | §2 の S の行 |
| P | 紙と見出しと PDF: `PaperSpan`・`PaperView` の境目の線・`MonthPaper` の `memoLine`・`StickyHeaderView` の 2 つの行・`PDFPageRenderer`・その単体テスト | §2 の P の行 |
| Z | 凍結のキャンバスの R3（§8.4）と `InkCanvasMonthYearTests`・R0 の `InkCanvasZoomResetTests` | §2 の Z の行 |
| U | UI テスト（`SpanMonthYearUITests`・`SpanMonthYearShotsUITests`・R0y の `ZoomResetUITests`） | §2 の U の行 |
| X・R | 訳・元を見ない逆翻訳・GLOSSARY・REVIEW | `tools/l10n/`・`docs/i18n/` |
| A・W | 新機能の文・審査メモ・SUPPORT | `docs/store/`・`docs/SUPPORT*.md` |
| リード | 順番・確かめ・`docs/R1_4_3.md`・見本と確認ページ・Connect・本人への知らせ・R3 と R0 の 1 行ずつの見直し・落とし所の決め | — |

- 作る役の枝は `r143-w-<名前>`（速い道。§12.1）。作る役は push しない。リードがまとめの枝へ取り込んでから上げる。S の枝が K・Z の物を要るときは、K・Z を `--no-ff` で入れたまとめの枝（例 `r143-w-b2`）で速い道を回す（1.4.1 の §16.5 と同じ形）。

### 14.4 出し方（本人の言葉が要る所。一覧は §0.4）

| 順 | だれ | すること | 本人の言葉 |
| --- | --- | --- | --- |
| 1 | 各役 | この契約のとおりに作り、`r143` に commit | 不要 |
| 2 | リード | `r143` を GitHub に上げ、CI が全部緑 | 不要 |
| 3 | リード | 見本の写真のページ（段 P） | 月の並べ方（ア・イ・ウ。答えが無ければア） |
| 4 | リード | 確認ページ（§14.1 の D3） | 「**この内容で入れてよい**」 |
| 5 | リード | testflight.yml を確かめた commit から走らせ、TestFlight 1.4.3 を内部のテストに配る。確かめ表（§15）を番号付きで渡す（4 と同時でよい） | 不要 |
| 6 | 本人 | 確かめ表 | 「全部○」か × の所 |
| 7 | 本人 → リード | 提出のお願い | 「**1.4.3 を審査に提出して良い**」 |
| 8 | リード | `git diff <確かめた commit> -- Sources TegakiKit Tests tools .github project.yml` が空を確かめ、Connect に版 1.4.3 を作り、16 ロケールの新機能の文・プロモーションテキスト・審査メモ・ビルド・月と年の写真を入れて読み戻す。手動公開で提出 | — |
| 9 | 本人 → リード | 審査に通ったら公開。同じお願いで、main へまとめてよいか | 「**1.4.3 を公開して良い**」と「**まとめて良い**」 |
| 10 | リード | 公開の日に Web の SUPPORT 2 ページ、日本の App Store の表示が 1.4.3 になったことを記録。`r143` を main へ `--no-ff`、main の CI を見て run の番号と結果を書く。本人の手元の main を `pull --ff-only` | — |

- **本人の言葉の受け方**: 本人の言葉は、そのまま・時刻つきで `docs/R1_4_3.md` の「本人の言葉と選び」に写す。全角の数字や空白の違いは同じ言葉と読み、道具の `--owner` には決まった形を渡す（道具は字のまま比べ、全角・空白の違いも断る、`docs/R1_4_2.md:1025`）。言葉はチャットの本人の発言からだけ取る。確かめ表の答えに無い行があれば、その行だけ聞き直す（1.4.2 の行 21、`docs/R1_4_2.md:1169`。提出は進め、公開はその行の ○ の後）。
- 公開は、本人の確かめ（6）と本人の言葉（9）の後だけ。言葉は前もってもらってもよい。**本人が自分の端末で確かめていない版は出さない**。
- × が出たら、直してビルドし直し、確かめ表の触れた行（下の決め方）と行 1 をやり直してもらう（提出の後なら審査から取り下げる）。
- **本人が既定と違う形を選んだとき、やり直してもらう確かめ表の行**（新しいビルドの番号で表を渡し直し、その行の答えがそろってから提出・公開する。ほかの行の答えは前のビルドの物を使う。V より前に答えをもらえれば、表は新しいビルドで 1 回で済む）: いつも行 1（版）。ほかは:
  - 月の並べ方 イ・ウ（V の後の答え）: 行 2・3・10・12・16・17・18。
  - 設定の脚注の字の替え: 行 12。
  - iPhone 横の年の上限を外す: 行 14（`OverviewCapChecks` の作り直しと V のやり直し）。
  - 縦で等倍を押したときに覚えない形: 行 5・14（AppSettings と画面の替え、V のやり直し）。
  - 直しが凍結のファイルや保存・同期に触れたときは、全部の行。

**うまくいかなかったとき**:

| 起きたこと | すること |
| --- | --- |
| 12/5 の朝に年が間に合っていない | 0g-3 の落とし所: 月だけの 1.4.3。年は 1.4.4（この契約の注で範囲を書き、言葉は別にもらう）。§0 の日程と確かめ表の年の行（7・8・14）を「—」にして渡す |
| 1.4.3 が審査で断られた | 指摘を `docs/R1_4_3.md` に写す。文・審査メモだけで直せる（コードの差が空）なら、直した文を確認ページで見せて「この内容で入れてよい」をもらい直す。コードを直すなら、触れた所の D1〜D2 の関門をやり直し、新しいビルドを TestFlight へ、確かめ表の触れた行をやり直してもらう。どちらも、出し直しの前に「1.4.3 を審査に提出して良い」をもう一度もらう。前にもらった公開の言葉は使わない |
| 確かめた後に main が動いた（1.4.2 の直しの版などで） | 提出しない。基準（J-4 のファイル・関門 3 の run）を新しい main の公開したビルドとその通しの run に替え、`r143` で D0 の関門から通しの run をやり直す。新しいビルドで確かめ表を全部やり直してもらう |
| 1.4.3 を出す前に、1.4.2 に重い不具合が見つかった | 小さければ 1.4.3 に入れる（確かめ表に行を足す）。急ぐなら、直す版を 1.4.3 とし、この契約の月と年は 1.4.4 へ送る（M7_PLAN §4・道具 asc・言葉の字を作り直す。R1_4_2_CONTRACT §9.4 の決まり） |
| 公開の後に重い不具合が見つかった | App Store では前の版に戻せない。直した版をできるだけ早く出す（版の番号は 1.4.4）。設定 › ページ のオフが、横の道の不具合の回り道になる（本人に知らせる）。流れは同じ |

---

## 15. 本人の確かめ表（TestFlight 1.4.3）

**対象の版: 1.4.3（TestFlight のビルド 33 以上。番号は Claude が渡すときに書きます）**。この表は、ビルドが本人の端末に届いた後に、番号を書いて改めて渡します。**上から順に**試して、○ か × を付けてください（前の行の終わりの形が、次の行の始まりになるように並べました）。× のときは画面の写真を送ってください。

**準備**:
- iPad Pro 13・iPad Air 11・iPhone 18 Pro Max に、TestFlight で 1.4.3 を入れてください。**iPad mini は、行 16 まで 1.4.2 のまま**にしてください（自動アップデートをオフに。入ってしまったら行 16 は「—」）。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（無料）。**「全て消す」と Apple アカウントの切り替えはお願いしません。** iPhone Duo の行は「—」にしてください。
- 始める前の形（4 台とも）:
  - 端末の画面表示は「ライト」。端末は縦で始めます。
  - ツールバーは**開いて下**。丸ボタンだけ（しまってある）なら、丸ボタンを**長押し**して「ツールバーをいつも出す」を押してください（丸ボタンの ↶ は「元に戻す」です）。iPad で、開いたツールバーが上・左・右にあれば「動かす」→「下へ移す」。
  - ペンは 黒・中（「ペン」を押し、黒の丸が光っていなければ黒の丸を押し、「中」を押す。光っている丸を押すと色の板が開くので、開いたら画面の上の見出しの何もない所に触れて閉じてください）。
  - 設定 › ページ の「前後のページを横につなげる」は「オン」（最初のまま）。設定 › メモ欄の紙 は「罫線」。iPad の「指でも書く」は「オフ」（iPhone は最初のまま「オン」）。
  - 月と年のページを開いたら、まず 2 本の指でつまんで、いちばん小さくしてください（前に拡大した大きさを覚えていると、その大きさで開くため）。
  - （この準備の字は、確認ページの最初の画面にも同じ字で書きます。）
- 行 2〜9 は iPad Pro 13 で続けて試します。月の並べ方は「ア」のときの書き方です（ほかを選んだときは、Claude が行の字を直して渡します）。

| # | 端末 | すること（1 文目は始まりの形） | こうなれば合格 |
| --- | --- | --- | --- |
| 1 | 全部（iPad mini は行 17 の後） | 設定 › 情報 で「バージョン」を見る | 1.4.3（Claude が知らせた番号） |
| 2 | iPad Pro 13 | 縦で、月のページの一覧（いちばん小さい形）。指 1 本で紙を左へゆっくりすべらせる。次に左へはじく。「‹ 今日 ›」の ▶ と ◀ を押す。最後に「今日」を押す | すべらせると、右に次の月の表が続いて出る。表と表の間に濃い縦の線がある。曜日の行の左端に「12月」のような札がある。はじくとちょうど 1 か月で止まる。▶ ◀ で 1 か月ずつ動く。「今日」で今月に戻り、今日のマスが見える |
| 3 | iPad Pro 13 | 縦の月の一覧。11 月と 12 月の境目が画面の真ん中に来るまで、指でゆっくりすべらせる。**Apple Pencil で**、下のメモ欄に 11 月から 12 月へ横に 1 本書く（手のひらを紙に置いたまま）。書き終えたら、指 1 本で紙を左右に少し動かす | 線が途中で切れずに書ける。書いている間に紙が横に動かない。離しても線は動かない。動かすと、線が 2 つの表の下を 1 本で通って見える。メモ欄の区切りの線と罫線が、境目で同じ高さにそろっている |
| 4 | iPad Pro 13 | 行 3 の続き。消しゴムで、行 3 の線を 12 月の側で消す。↶ を押す。投げなわで行 3 の線を囲み、12 月の表の格子の上へ動かす。↶ を押す | 消える。↶ で戻る。投げなわで動く。↶ で元の場所に戻る |
| 5 | iPad Pro 13 | 縦の月の一覧。等倍（虫めがねに「1」）を押す。端末を横にする。下へすべらせてメモ欄まで見る。2 本の指でいちばん小さくする | 縦で押しても見た目はほとんど変わらない。横にすると、1 か月の表が画面の幅いっぱいになり（4〜5 週ほどが見える）、下へすべらせると残りの週とメモ欄が見える。いちばん小さくすると、左右に前後の月の表の端が見える一覧に戻る |
| 6 | iPad Pro 13 | 横の月の一覧。等倍を押す。アプリを完全に閉じて開き直す（下の端から上へゆっくり指を動かして止め、てがきカレンダーの絵を上へ払う。開いたら月のページへ）。2 本の指でいちばん小さくする。端末を縦に戻す | 押すと幅にちょうど。開き直しても、月は等倍で開く。いちばん小さくした後は一覧に戻る |
| 7 | iPad Pro 13 | 縦で、年のページの一覧（いちばん小さい形）。左右の端を見る。指 1 本で紙を左へすべらせ、12 月と次の年の 1 月の境目が真ん中に来たら、**Pencil で** 12 月 20 日あたりから次の年の 1 月 10 日あたりへ、横に線を引く | 左右に前の年の 12 月と次の年の 1 月が少し見える（机の色の余白ではない）。すべらせると次の年が続く。日付の列の上に「2027」の札がある。同じ日付の行が横一直線にそろっている。線が書ける |
| 8 | iPad Pro 13 | 縦の年の一覧。等倍を押す。下へすべらせて 31 日まで見る。2 本の指でいちばん小さくする | 1 年の幅が画面の幅いっぱいになる（月の列が少し広がり、下の数日は下へすべらせて見る）。小さくすると一覧に戻る |
| 9 | iPad Pro 13 | 月のページで 11 月を開き、「このページを PDF」で書き出す。年のページで 2026 年を PDF にする | 11 月の PDF のメモ欄に、行 3 の線の 11 月の側（紙の中の部分）が出る。2026 年の PDF に、行 7 の線の 2026 年の側が出る |
| 10 | iPad Air 11 | 縦の月の一覧。指 1 本で横へすべらせ、はじく。端末を横にする。指 1 本で横に動かす。等倍を押し、2 本の指でいちばん小さくする。縦に戻す | 縦では、すべらせると隣の月が出る。横では、左右に前後の月の表の端（1 列半ほどずつ）が見える。等倍で 1 か月が幅いっぱい（4 週ほど）。小さくすると一覧に戻る |
| 11 | iPad Air 11 | 縦の月の一覧。ツールバーの「指でも書く」をオンにする。指 1 本でメモ欄に書く。2 本の指で横にすべらせる。「指でも書く」をオフに戻す | 指 1 本で書け、2 本の指で横に動く |
| 12 | iPad Air 11 | 設定 › ページ を開き、説明の文を読む。「前後のページを横につなげる」をオフにして、月のページ（行 3 の線のある 11 月と 12 月）と年のページを見る。オンに戻す | 説明が新しい文（確認ページで見た字）。オフでは月も年も 1 ページずつ（今までどおり）。行 3 の線は片方の月にだけ出る（消えていない）。オンに戻すと、またつながって見える |
| 13 | iPhone | 縦で、月のページ（1.4.3 で初めて開く）。紙の上の端の札を見る。2 本の指で横にすべらせる。指 1 本でメモ欄に書く | 小さな札（「前後の月が横につながりました…」）が出て、8 秒で消える（触れても消える）。2 本の指で隣の月が出る。指で書ける。（行 13 より前に月を開いていて札を見なかったときは、札の所だけ「—」） |
| 14 | iPhone | 縦で、年のページ。等倍を押す。端末を横にする。2 本の指でいちばん小さくする。2 本の指で左右と上下に動かす。縦に戻す | 縦で押しても見た目はほとんど変わらない。横にすると 1 年が横いっぱい（6〜7 日分の行が見え、上下にすべらせて続き）。いちばん小さくすると 3 年分までの大きさで、1 年は縦に入りきらず、上下にすべらせて見る |
| 15 | iPhone | 横で、月のページの一覧。等倍を押す。2 本の指でいちばん小さくする。縦に戻す | 一覧では約 3 か月分が並ぶ。等倍で 1 か月が横いっぱい（2〜3 週ほど）。小さくすると一覧に戻る |
| 16 | iPad mini（1.4.2 のまま） | 月のページで、行 3 の線のある 11 月と 12 月を見る。見えている行 3 の線を消しゴムで消す。iPad Pro 13 で同じ所を見る | mini では、線が片方の月にだけ出て、紙の端で切れて見える（または余白にはみ出す）。消えてはいない。mini で消すと、Pro 13 でも消える（Pro 13 の上の印が「保存済み」になった後） |
| 17 | iPad mini | TestFlight で 1.4.3 を入れる。月のページで、**Pencil で**メモ欄に境目をまたいで 1 本書く。iPad Pro 13 で同じ所を見る | mini でも月が横につながり、またいで書ける。Pro 13 にも届き、つながって見える |
| 18 | iPad Pro 13 | 設定 › メモ欄の紙 を「ドット方眼」にして、月の境目のメモ欄を見る。見終わったら「罫線」に戻す（1.4.2 のくり返し） | 点の列が境目でも同じ間隔・同じ高さで続く。罫線に戻すと前と同じ |
| 19 | iPad Air 11 と iPhone | 1.4.1・1.4.2 のくり返し。週のページで等倍を押す。「‹ 今日 ›」を押す。ペンの光っている丸を押して色の板を開き、「紺」で書き、もう一度板を開いて「最初の色に戻す」 | 前と同じ動き（1 週の幅が画面にちょうど、今日へ戻る、紺で書ける、黒に戻る） |
| 20 | どれか 1 台 | 機内モードにして月と年に書く → 機内モードを切る。アプリを完全に閉じて開き直し（行 6 と同じやり方）、手書きのあるページ（月・年・週・日）を順に開く | 書いている間は「オフライン」、戻すと「保存済み」。開き直しても書いた線が全部見える。一部の線が欠けて見えるときは、そのページの写真を送ってください |
| 21 | iPhone Duo | — | 「—」（Duo はお持ちでないので、自動の確かめだけで見ます） |

- 年が間に合わず月だけの 1.4.3 にしたときは、行 7・8・14 と行 9 の年の所を「—」にして渡します。
- 試し終わった後の等倍や設定は、お好きな形のまま使って構いません。

---

## 16. 危険と減らし方

| 危険 | 減らし方 |
| --- | --- |
| 道を決める所が散らばっていて、1 つ漏れると「月は開くが紙が無い」「札が出ない」「PDF が空」のような半端な形になる | 種類の集合を `SpanKinds` の 1 か所に（§3.1）。§3.1 の 14 の所を 1 つずつ開き、`SpanKindsTests` で全部が集合と同じ答えを言うことを確かめる。CI の `case` には注 |
| 凍結のキャンバスの作り直しが 3 回目になり、保存や同期の行に触れてしまう | R3 は `paperSpan` の本体 1 か所だけ、許す行を表で決めた（§8.4）。手順 4 の緑とリードの 1 行ずつの見直し。等倍・ずらし・y の補正は凍結の外で直す（§3.5・§6.2） |
| 守られたテストを書き直すことで、守りを黙って弱める | 例外 (d) は表に挙げた断言だけ、消さずに置き換え、確かめを減らさず、自分の commit で、リードが 1 行ずつ見る（§8.5）。既定値の引数で古い断言を残す形は採らない。ほかの守りはそのまま通す |
| 月のずらしで、見えている格子とメモ欄が縦に跳ぶ | `PageScroll.scrollDelta` を月だけ同じページで比べる（§3.5）。KitChecks・`InkCanvasMonthYearTests`（0.5 pt）・ずらしの前と後の写真の組 |
| 焦点の持ち越しの誤りで、題名が隣の月になる・月から週へ替えると思わぬ週が開く | 月・年の規則（§3.6）と単体テストの表（月末・2/29） |
| アの白い紙が分かりにくい（格子と区切りの線の間の空き） | 段 P の写真で 3 通りと一緒に見せる。白い紙はメモ欄の一部で、古い端末でもメモ欄に出る（§4.1）。本人がイを選べば行がそろう |
| 本人が段 P の写真に答えない、または V の後にイ・ウを選ぶ | 3 通りを 1 つの値で切り替える作り（§4.1）。V の前までに答えが無ければア（§12.5）。後の答えはやり直す行（§14.4） |
| 月の札が狭い列（iPhone 縦 約 57 pt）や長い言葉でぶつかる | 縮め方の規則（数字だけ・出さない）と ja・en・de の単体テスト（§4.4）。de・fr・疑似の言語の写真 |
| 横の道の月・年で PDF が古いページや空のページで作られる | `paper(of:)` に月・年、月の矩形に隣のメモの線（§4.7）。`PDFMonthYearTests`・確かめ表の行 9 |
| 年の窓で時刻の予定まで全部読み、メモリと開く時間が重くなる | `allDayOnly` を渡す（§5.5）。`EventStoreModelYearTests`・変異 MS3 |
| 線の多い年で、ずらしが引っかかる（段 1 と速い道を作らない） | 本人の数では上限の 1 割に届かない。段 2 が安全弁。`SpanWeightLogTests` で 19,600 本まで測り、閾値を超えたら見直す（§3.10） |
| 等倍の取り違え: 縦で押して見た目が変わらず、横にすると月が大きく開いて「一覧が消えた」と思われる | §0.1 と SUPPORT で先に伝え、確かめ表の行 5・14 でその順を試す。2 本指でいちばん小さくすれば戻る。言えば「覚えない」形にできる（§0.5） |
| iPhone 横の年が 1 年全部見えなくなる（上限 3） | P-B6 イの問いの本文に年があった。§0.1 で伝え、行 14 で試す。言えば外せる（§5.4） |
| 1 ページの道の月・年の画素が変わり、J-4 と店の写真が宣言の外で変わる | 札・境目の線・白い紙は横の道だけ（§4.3・§4.4・§5.3）。下限 0 で `memoLine == memo.minY`。J-4 で「1 ページの道は同じ」を示す（§12.2）。`MonthPaperLineTests` |
| 店の写真の撮り忘れ（1.4.1 §7.6 の失敗） | 撮り直す写真を名前で決めた（§12.6）。T0 の `shots143.py` と D4 の `submit143.py check` に写真の入れ替えを入れる |
| 設定の脚注の固定の文を、本人の言葉なしに替えてしまう | 新しい字を §0.4 で先に見せ、確認ページの「この内容で入れてよい」で替える（0g-34）。違う字を望まれたら、R0 の字と訳をやり直す |
| 年が遅れ、文・写真・確かめ表が 2 通り要る | 12/5 の朝の 1 回の決めで 1 通りにする（0g-3）。文は決めた後に書く（§13.1） |
| span-shots-app のジョブが 120 分の上限を超える | 新しいジョブ span-shots-my に分ける（§12.1）。時間の 2 つの守りを C が記録 |
| 同じ UTC の日・同じ実行環境の版の J-4 が組めない | 2 つの日・2 つの版の基準の両方を取る（1.4.2 と同じ）。版が違えば基準を取り直す（§12.2） |
| 実行機の重さで打ち切りや揺れが出て、run が半日に延びる | 通しの run を 2 つ同時に走らせない。作る役の枝は速い道。揺れの読み方を決めておく（§14.1） |
| V の成果物が 12/3 ごろ消え、関門 3 の基準と前の写真を失う | S0' で D0 の前に控える（§12.7） |
| 道具が 1.4.2 の字と写真の範囲（iPad 13 の 9 ロケール）に結び付いている | T0 で 1.4.3 用に移し、月と年の写真の入れ替えを足す。偽の Connect の試験を通してから使う（0g-46） |
| 古い版の端末の見え方をお手元で確かめられない（mini を 1.4.2 のままにできない） | 行 16 は「—」でよい。CI の古い版の見え方の写真（`--screenshot-single-page`、§12.4）と互換の fixture（§8.3）で見る |
| 手ざわり（はじき・手のひら・Pencil と指・2 本指）は CI で試せない | 確かめ表の行 2・3・10・11・13・14 で、始まりの形と Pencil か指かを行ごとに書いた。週・日の 1.3 の手当てをそのまま使う |
| 年末: 12/19〜1/4 は審査が遅れることがある【未確認】 | 12/18 の目安と 12/12 の前ぶれ。12/5 の落とし所 |
| 作業の木が夜中の掃除で消える | こまめに commit、リードが GitHub に上げる、`worktree repair` |

---

## 17. 決めどころ（既定と理由。番号は 0g-n）

| # | 決めどころ | 既定 | 理由（参照） |
| --- | --- | --- | --- |
| 0g-1 | 版・枝・番号 | **1.4.3**（`project.yml:23`）、ビルド 33 以上。枝 `r143`（main 4a2211d から。コードは 57ffd0f と同じ）。M7_PLAN §4 の 1.7・1.8 は「1.4.3 へ移した」とし、1.5 から後の番号は変えない。契約はこの文書、結果は `docs/R1_4_3.md` | 1.4.1 を差し込んだときと同じく、後の番号（1.5 指で予定・1.6 写真と文字の札・1.9・1.10）を本人が覚えた形のまま保つ。1.7 にすると 1.5・1.6 より大きい番号を先に出すことになり、App Store は後で小さい番号を受け付けない。1.4.2 が 32 を使った |
| 0g-2 | 1 つの版にまとめる | 月（B-3）・年（B-2）・月と年の幅の等倍を 1 つの版に | 本人の言葉は月と年の両方を言う。B_DESIGN §9.1 が「1 つの版にまとめてもよい（約 0.3 里程の節約）」と書く。文・訳・店の写真・確かめ表が 1 回で済む |
| 0g-3 | 落とし所 | 12/5 の朝に D1y が取り込みの関門を通っていなければ、月だけの 1.4.3。年（横つなぎと等倍）は 1.4.4。年の等倍はそれまで open。`SpanKinds` から年を外すだけ、R0y を作らない、文は月だけ | 本人の言葉の順（横スクロールの後に等倍）を種類ごとに守る。12/18 の提出に間に合わせる。1 か所の替えで切れる作り（§3.1） |
| 0g-4 | 順 | 月が先（D1b）、年が後（D1y） | P-B2 = 月（B_DESIGN §9.1「本人が iPad で月を一番よく使うなら B-2 と B-3 を入れ替える」）。月は本人の選び（P-B3）があり、先に写真を撮れる |
| 0g-5 | 時期 | 12/18 より前の提出をねらう（§14.1） | 前倒しの決まり（11/8）。年末の審査の遅れ（R1_4_2_CONTRACT 0f-3） |
| 0g-6 | 範囲 | §1.3 の表 | 本人の言葉、M7_PLAN §4 の「次の版」と 1.7・1.8、R1_4_2_CONTRACT 0f-2 |
| 0g-7 | 範囲外 | §1.4 の一覧 | 本人の言葉の外か、測ってから決める物（0g-25） |
| 0g-8 | 種類の集合 | 新しい `SpanKinds.joined`（4 種）を 1 か所にし、道・案内・等倍・紙・PDF・写真の見本がそこから引く | 地図の危険「道を決める所が散らばっている」。落とし所を 1 か所で取る |
| 0g-9 | 道・設定オフ・段 2・写真モード | `joins` を集合で。設定オフ・段 2・`--screenshot-single-page` は 1 ページの道。写真モードの既定はオフのまま | 1.3 の 2 本の道（B_DESIGN §2.3、M7C D2）。今の写真を 1 画素も変えない |
| 0g-10 | 月の 3 通り | Kit の `SpanAlign.monthForm` で切り替え、既定ア。段 P の写真で本人に選んでもらい、V の前までに答えが無ければア | P-B3 の 11/07 の既定と、見本の約束（M7C_CONTRACT 0c-20・:755・:757、B_DESIGN §8.1）。遅い答えでも値の替えだけで済む |
| 0g-11 | アの作り | 区切りの線から下の柄の y を窓でそろえ（`memoLine`）、`memo` の原点と行は動かさない。短い月は格子と区切りの線の間が白い紙（メモ欄の一部）。最後の行はのばさない | のばすと灰色の薄い日の帯になり、そこに書いた線が薄い日のマスに入る。1,200 lu の上限でそろわない形が無くなる。一覧の倍率が自分の格子の高さのまま。1 ページの道の画素が同じ（§4.1） |
| 0g-12 | 下限の上げ下げ | ずらしでは下げない、消すと窓の最大まで下げる、読み直しで決め直す。メモの帯の下端もそろえる。2 回並べて自然な数を取る | 週・日の D16 と同じ規則（B_DESIGN §3.1、`SpanAlign.Change`）。見えている行が縮まない |
| 0g-13 | 月の境目の線 | 横の道の月だけ、格子に濃い縦の線。メモの帯と窓 1 ページと年には引かない | B_DESIGN §3.4「境目は濃い縦線」。今は x = 0・1,400 に線が無い（`MonthPaper.swift:47-60`）。帯を 1 本に見せる |
| 0g-14 | 月の札 | 横の道の見出しの曜日の行、各表の左端、左へ出た札は左端に貼り付く。字は題名と同じ作り。狭ければ数字だけ・出さない。1 ページの道には出さない | B_DESIGN §3.4。新しい文を作らない。J-4 と店の 1 ページの写真を変えない |
| 0g-15 | 重なる日・今日の印・薄い日 | 今のまま（両方の表に出す、今日の印も薄い方に） | P-B4 おまかせ。隠すと「見えないが消えない」手書きができる（B_DESIGN §3.4） |
| 0g-16 | 月の一覧の倍率 | 自分の格子の高さ（`memo.minY`）のまま。新しい欄は作らない | B_DESIGN §3.1 の規則。0g-11 の作りで自然に満たす |
| 0g-17 | ずらしの y の補正 | `PageScroll.scrollDelta` を、月の窓だけ古い窓の真ん中のページを新しい窓で探して比べる。`band(atY:)` の答えと、週・日・年の答えは変えない | 月は行がページごとに違う（§3.5）。凍結の `SpanChecks.swift:816-820`・:952 と凍結のキャンバスに触れずに直せる |
| 0g-18 | 焦点の持ち越し | 週・日は今の式。月は同じ日（無ければ月末）、年は同じ月日（2/29 は 2/28） | 今の式は月の 42 日の格子とうるう年で誤る【計算】（§3.6） |
| 0g-19 | 今日 | 月・年は今日のマスを画面に出す（滑って、縦も合わせる）。上限の年は今日の行の 2 行上から | 1.1.1 の決まり（`CalendarRootScreen.swift:1909-1933`）を横の道へ。週の上限の形（M7C_CONTRACT §3.6）と同じ考え |
| 0g-20 | 見出しと終日帯 | 月・年は終日帯を作らない。見出しは種類ごとの行（`spanMonthRow`・`spanYearRow`）で、高さは 1 ページの行と同じ | 今は月・年を週として刻み、誤って重い（`AllDayBand.swift:179-190`）。紙の領域と開く大きさを 1 ページと同じにする |
| 0g-21 | 年の行のそろえ | 31 行を行ごとに窓の最大に（400 以下） | B_DESIGN §3.5。今の「12 か月の最大でそろえる」を隣の年へ広げる形（`YearLayoutEngine.swift:312-337`） |
| 0g-22 | 年の札 | 横の道の見出しの日付の列に年。狭ければ下 2 桁・出さない。左へ出た年は左端に。1 ページの道には出さない | B_DESIGN §3.5。0g-14 と同じ理由 |
| 0g-23 | iPhone 横の年の上限 | 3 ページのまま（コードと凍結の KitChecks のとおり）。§0 で知らせ、言えば外せる | P-B6 イの問いの本文に「年は 6 割ほど」（B_DESIGN.md:747）。週・日と同じ考え。M7C_CONTRACT.md:708 の「1.8 で決め直す」をここで決めた |
| 0g-24 | 年の予定 | `events(from:to:allDayOnly:)` を足し、年で true | 1 ページの年と同じく終日だけ（`EventStoreModel.swift:153-154`）。窓 5〜7 年で時刻の予定を全部ためない。凍結のテストは既定 false で通る |
| 0g-25 | 重さ | 段 1・平行移動のずらし・照合の速い道・主スレッドの外の先読み・年の予定の順は作らない。測って記録し、後の版で決める。D18 と段 2 はそのまま | 本人の数（P-B9）では上限の 1 割に届かない。凍結のキャンバスに触れる範囲を小さくする。B_DESIGN §6.3 の約束を黙って落とさない |
| 0g-26 | 等倍 | `followsFit` を月・年も真（集合に入る種類）。両方の道、同じ鍵 `zoomFit.<種類>`。開く大きさは今のまま。open = fit の所で押しても状態を立てる | 本人の言葉（12:3x・12:4x・13:0x）。1.4.1 の §16.3.4 の (c)・§16.3.5・§16.3.2 の 2 と同じ規則。凍結のキャンバスの行を変えずに済む（§6.2）。両方の道にすると説明が 1 通りで済む |
| 0g-27 | 凍結のキャンバス R3 | `paperSpan(for:focus:)` の本体を `PaperSpan.window` を呼ぶ 1 行に。ほかの行は変えない。手順は 1.4.1 の §16.4 の形 | 今は週・日以外で紙が出ない（`InkCanvasView.swift:2625-2637`）。凍結の外へ出せば後の種類で凍結に触れずに済む |
| 0g-28 | 守られたテストの作り直し | 例外 (d): §8.5 の表の断言だけ、消さずに置き換え、自分の commit（R0m・R0y・R0f）、リードの 1 行ずつの見直し、記録。既定値の引数で古い断言を残す形は採らない | 今の決まり（M7D_CONTRACT §5.5 の (a)(b)(c)、R1_4_2_CONTRACT.md:626-629）は機能の替えを許していない。本人の言葉で機能を変える版なので、リードの決定として足す |
| 0g-29 | 新しい守りの表 | `tools/span/TESTS_1_4_2.sha256`（1.4.2 の新しいテスト 15 の候補、57ffd0f の blob）と段 | 1.4.3 は 1.4.2 で直した `MonthPaper` と画面に触れる。各版がテストを守りの表に入れてきた |
| 0g-30 | 互換 | 新しいフォルダ `compat-span-143`（4 組）と `FIXTURES_1_4_3`、本物の 4 つの相手で読む。FIXTURES_1_3 と相手は変えない | K-7。M7C_CONTRACT.md:650「月の帯の fixture は 1.7」。B_DESIGN §11.2。データのコードは 1.3 から変わっていないので相手は足さない |
| 0g-31 | 写真モード | `--screenshot-span-crossing all`・`--screenshot-month-tall`（既定値つき）。引数なしの月・年の見本は今のまま。`r143-alt` だけ `--screenshot-month-form` | 凍結の `ScreenshotModeSpanTests.swift:144-148`・:632-640 を守る。今の見本では 3 通りの違いが見えない |
| 0g-32 | PDF | `paper(of:)` に月・年。月の矩形に隣のメモの線。紙は画面のまま | P-B8 おまかせ（D17）。今は横の道の月・年で古いページか空のページで作る【推定】 |
| 0g-33 | 初めての案内 | 月・年の 4 つの札（月は「メモ欄でまたげる」と言う） | B_DESIGN §3.1 の案内を種類ごとに。月の格子では日付が続かない |
| 0g-34 | 設定の脚注 | 新しい字（§13.1）を §0.4 で先に見せ、確認ページの「この内容で入れてよい」で替える | 本人が承認した固定の文（M7D_CONTRACT.md:142）。1.4.3 では今の字が事実と合わない |
| 0g-35 | 新しい文と訳 | 4 つの新しいキーと脚注の訳、2 つの comment、GLOSSARY §7 と §5、REVIEW 19・20 | 1.4.2 と同じ手順（R1_4_2_CONTRACT §8.2） |
| 0g-36 | 新機能の文 | 3 つの点（月と年の横つなぎ、等倍、K-8 の文） | K-8（B_DESIGN.md:413）。1.3 の形 |
| 0g-37 | 審査メモ | 「What is new in 1.4.3」の段と日本語の要約だけを入れ替える | 1.4.2 の形（R1_4_2_CONTRACT §8.4） |
| 0g-38 | SUPPORT | 等倍の段落、新しい FAQ 1 つ、メモ欄の紙と版の FAQ の 1 文、既知の制限の 1 文 | 今の字が「月と年は 1 ページ・開いたときの大きさ」と言う（`SUPPORT.md:153`・:246） |
| 0g-39 | 店の写真 | 月と年の写真（iPad 13 の 01-month・04-year、iPhone 6.9 と 6.3 の 02-month・04-year、Duo の 02-month・04-year）を、横の道で 16 ロケール全部（ja を含む）撮り直す。週・日・00-span は撮り直さない。新しい写真は足さない | 既定のオンで見える画面が変わる（札・隣の年）。1.4.1 の撮り忘れ（R1_4_1_CONTRACT §7.6）を繰り返さない。1.3 の D26 は週・日を撮り直さなかった（変わらない） |
| 0g-40 | CI の道 | `r143*` の配線、作る役の枝は速い道、写真の枝に `q-` を付けない、新しいジョブ span-shots-my、duo.yml で月・年も横の道 | 1.4.2 の形（R1_4_2_CONTRACT 0f-27）。span-shots-app に余りが無い（`docs/R1_4_2.md:1094`） |
| 0g-41 | J-4 と関門 3 | 基準 `ja-baseline-ref-1.4.3.txt` = 57ffd0f、関門 3 の基準は V の run 45721608435。違ってよいのは版の字と、設定 › ページ の節の行だけ。同じ UTC の日・同じ実行環境の版でだけ合否 | 1.4.3 は 1 ページの道を変えない。1.4.2 の V の版のまざり（`docs/R1_4_2.md:1086`） |
| 0g-42 | 試作の TestFlight | 作らない。見本の写真（段 P）と本物の TestFlight の確かめ表で見る。B_DESIGN §0 の項目 7・9 の約束（年の重さを試作で）は、CI の測りと本物のデータの確かめに替えたと §0.6 で知らせる | しくみと手ざわりは 1.3 の週・日と同じで、本人の答え（11/18）が済んでいる。お手元の年は 152 本で重さを感じられない。1.3 の試作は感想まで 6 日かかった（11/12 → 11/18） |
| 0g-43 | 見本の写真（段 P） | `r143-alt` で、月の 3 通り（11 インチの縦・横、13 インチの縦、iPhone の縦）と月の等倍の前と後。年はそろえば。1 つの Artifact のページで、選ぶのは月の並べ方だけ | M7C_CONTRACT 0c-20・:755 と B_DESIGN §8.1 の約束。「契約の前に撮る」の字は、1.3 の §15 の 4 と同じく「画面に出る部品を作る前に見てもらう」と読み、画面に出ない Kit は先に作る（本人向けの字 M7C_CONTRACT.md:78 にはこの順の字が無いので、本人への約束は破らない） |
| 0g-44 | 古い版の端末 | できれば iPad mini を行 16 まで 1.4.2 のまま（TestFlight の自動アップデートをオフ）。できなければ「—」で CI の確かめ | 1.3 の形（M7C_CONTRACT §4.6 の手順 0）。月・年の古い版の見え方（K-8）をお手元で見られる。mini はいちばん使わない端末【推定】 |
| 0g-45 | 確かめ表の形 | 表の頭に版とビルド番号。各行の 1 文目に始まりの形。前の行の終わりが次の行の始まり。Pencil の行と指の行を分ける。準備でツールバーを下に開く（しまってあれば丸ボタンの長押しの「ツールバーをいつも出す」）。月・年はいちばん小さくしてから。準備の字は確認ページの最初の画面にも | 1.4.1 の 0e-29・0e-30・0e-33、1.4.2 の 0f-34 の教訓（しまったツールバーとのぞきの罠、R1_4_1_CONTRACT §18.1）。行番号は試す順に通しで付ける（1.4.2 の行 21 の抜け、`docs/R1_4_2.md:1169`） |
| 0g-46 | 道具の移し | 段 T0 で `asc142` → `asc143`（月と年の写真を入れ替える `shots143.py` を足す）、`confirm142` → `confirm143`。guard を 1.4.3 の字と承認した commit に。偽の Connect の試験を通す。提出の前に `submit143.py check` が READY | 道具が 1.4.2 の字と写真の範囲に結び付いている（`docs/R1_4_2.md:1018-1036`）。1.4.1 で道具を移した後に契約が変わり止まった |
| 0g-47 | 確かめた commit（段 V） | D2 の文の commit の後に通しの run を 1 回。TestFlight と店の写真はその commit から。確認ページの写真はその run と同じコードの duo の run の物だけ。下書きは 3 つの目で見直す | 1.4.2 の V の役（R1_4_2_CONTRACT 0f-37） |
| 0g-48 | 1 ページの道 | 残す（設定オフと段 2 の安全弁）。消すかは、月・年が実機で 1 版以上落ち着いた後の版の契約で決める | M7C_CONTRACT.md:128、B_DESIGN §9.1。古い版の見え方の写真もこの道で撮る |
| 0g-49 | 1.9 の重点欄との関係 | 今は作らない。`Floors` は欄を足せる形（年の上の欄・月の重点を後で足す）にしておくだけ | B_DESIGN §9.3。範囲を増やさない |
| 0g-50 | 送られたもの | §1.5 の表 | 1.4.2 の記録（`docs/R1_4_2.md:14`・:23・:1096・:1136・:1139）、M7_PLAN §4 の CRA |
| 0g-51 | 1.4.2 の重い直しが要るとき | 1.4.3 を出す前なら、小さければ 1.4.3 に入れ、急ぐなら直す版を 1.4.3 にして月と年を 1.4.4 へ。公開の後なら 1.4.4 | R1_4_2_CONTRACT §9.4 の決まり。App Store は出した番号より小さい番号を受け付けない |

---

## 18. 確かめていないこと・出典

### 18.1 確かめていないこと【未確認】

1. 月のずらしで、今のままだと格子が縦に跳ぶこと（§3.5。読みは地図とコードから）と、直した後に 0.5 pt 以内に収まること。
2. 横の道の月・年で、今の PDF が 1 ページの道の古いページか空のページで作られること（§4.7）。
3. アの白い紙が本人に分かりやすいか（段 P の写真で見る）。
4. 月の札と年の札が、狭い列と長い言葉で入るか（§4.4・§5.3）。
5. 月・年の等倍の倍率と見える量（§6.3 は計算。iPad Air 11 は紙の領域の推定、iPhone 18 Pro Max の横の紙の高さは記録が無い）。
6. 年の窓の重さ（§3.10。CI のシミュレータの値で、実機とは違う）と、年 1 年分の予定を読む時間。
7. 新しい写真のジョブを足した後の通しの run の時間（§12.1）。
8. 店の写真の撮り直しが、Connect で前の版の写真の引き継ぎとまざらずに入るか（`shots143.py` の形）。
9. 古い版（1.4.2）の iPad で、月・年をまたいだ線が余白にはみ出して見えるか、紙の端で切れるか（B_DESIGN §4.3。CI の写真で見る）。
10. 中国の 2027 年の祝日が python-holidays の正式版に入ったか（S0 で見る）。
11. EU の新しい製造物責任指令（2026-12-09 より後）で 1.4.3 にすることがあるか（S0 で M7C_CONTRACT §8.6 を読み直す）。
12. 年末の審査の遅れ（12/19〜1/4）。
13. main の run 46040646988 の結果（11/27 17:46Z に走っていた）。
14. 本人の 11/28 の言葉「1.4.2に変更済みです。」が、お手元の 4 台が 1.4.2 になった意味か（§1.2）。iPad mini の今のアプリが TestFlight から入れた物か App Store の物か。
15. 凍結の `SpanSessionTests` の月・年の形が、下限が入った後も保存のバイトで同じか（§8.7。見込みは同じ）。
16. `ZoomResetUITests` の年の断言が、iPhone 17 の縦（open = fit）でどう読まれるか（§8.5 の R0y）。
17. キャンバスが月・年の格子のマスの手書きの伸びでも `onInkBoundsChanged` を知らせるか（§3.3）。
18. 月と年の新しい 4 キーの仮の訳で、速い道の lint（L-2・L-6）と Localized bundle check が緑になるか（1.4.2 の前例どおりの見込み）。

### 18.2 出典

**調べ役の地図**（2026-11-28。main 4a2211d を読んだだけ。書き込みは無い）: しくみ（道・セッション・Kit・窓・上限・段 2・ずらし・先読み・持ち主と保存・紙・見出し・下限・y の補正・一覧の倍率・焦点・今日・PDF・等倍・文・写真モード・店の写真・凍結のテストと表・fixture・B_DESIGN との違い・開く所の一覧）、月（6 行 42 日・重なる日・行の高さ・メモ欄と紙・格子の線・今日の印・名前・見出し・open と fit の数・B_DESIGN の形・本人の決め・見本の材料・写真・凍結とのぶつかり・互換・文・PDF・重さ）、年と等倍（年の行のそろえ・持ち主・横スクロールの今・横の道・EventKit・線の数・1.4.1 の等倍のコードと鎖・Bounds・凍結のキャンバスとテスト・幅の等倍の数・前例・文・写真）、段取りと CI（土台・main の CI・本人の言葉・等倍・答え・見本の約束・番号・1.3 と 1.4.2 の段・言葉の受け方・CI の数と時間・配線・揺れ・J-4・凍結の表・互換・K・脚注・案内・訳・新機能の文・審査メモ・SUPPORT・店の写真・道具・確認ページ・確かめ表・古い版の端末・守りの候補・変異と Duo・この Mac・成果物の期限・危険の記録）、本人の言葉と時期（P-9・P-B の答え・試作の感想・等倍の言葉・0f-2・見本の約束・Duo・一覧・脚注・進め方・祝日、本人が選ぶこと・見るだけ・言えば替えられること・本人の操作・言葉・聞かないこと、§0 の材料、時期の材料）。

**この契約の書き手がコードで読み直した行**（main 4a2211d、11/28）: `Span/ScreenPaths.swift:255-268`・:460-472・:963・:1020・:1043-1070・:1110-1120・:1160-1178・:1247、`Span/SpanSession.swift:640-697`、`Ink/InkCanvasView.swift:2620-2648`・:3060-3110（と `grep` で種類を見る所は :2628-2630 だけ）、`Views/ZoomReset.swift:1-40`、`Views/StickyHeaderView.swift:40-70`、`Views/SpanGuideView.swift:18-45`、`Views/CalendarRootScreen.swift:619`・:641・:1909・:2625-2640・:3292、`Paper/PaperSpan.swift:1-115`、`Paper/PaperView.swift:395-425`、`Export/PDFPageRenderer.swift:68-100`、`Calendar/EventStoreModel.swift:148-176`、`Calendar/EventKitService.swift:138`、`TegakiKit/Sources/Layout/SpanAlign.swift:14-38`・`SpanPlan.swift:72-84`・`ZoomPolicy.swift:40-170`・`PageLayout.swift:139-141`・:160-180・`SpanLayout.swift:210-235`・`PaperSpec.swift:14-15`・:97。テスト: `ScreenPathsSpanTests.swift:184-197` と `grep`（:192・:212・:215・:216・:273・:996・:1703・:1826）、`SettingsPageSectionTests.swift`（`grep` で :258-259・:333-334・:352）、`ZoomResetTargetTests.swift:12-40`、`ZoomFitWiringTests.swift:214-240`、`ZoomResetUITests.swift:8-50`、`InkCanvasZoomResetTests.swift:318-330`・:820-846、`PaperSpanTests.swift:255-270` と `grep`、`ScreenshotModeSpanTests.swift:140-150`・:628-642、`SpanShotsUITests.swift:90-112` と `grep`（:97・:121・:169）、`SpanRerunUITests.swift`（`grep` で :55-67）。CI と表: `build.yml:450-520` とジョブの行（:111・:1730・:2183・:2561・:3134・:3718）、`grep` で `screenshot-zoom fit`・`screenshot-span`、`duo.yml:893-920`、`store-shots.yml:1-62`・:420-490、`DATA_1_1.sha256`（20 行、1 行目 d0250f23…）、`TESTS_1_3.sha256`（29）・`TESTS_1_2_3.sha256`（8）・`TESTS_1_4_1.sha256`（16）・`FIXTURES_1_3.sha256`（37）、`tools/l10n/lint-skip.txt`、`ja-baseline-ref*.txt`、`compat-span/MANIFEST`、2 つの `EXPECTED_MIN`（599・225）。文: `tools/l10n/source/app-U.json:1825-1842`・:2313-2370、`app-P.json:447-450`、`docs/SUPPORT.md:147-197`・:240-252、`docs/i18n/GLOSSARY.md:237-275` と節の見出し、`docs/i18n/REVIEW.md`（節の見出し）、`docs/store/review-note.txt`（3,665 バイト）、`docs/store/ja/whatsnew.txt` と `git show 955fe67:docs/store/ja/whatsnew.txt`、`README.md:55-62`、`docs/DESIGN.md:215-220`。記録: `docs/R1_4_2_CONTRACT.md`（全部）、`docs/R1_4_2.md:5-16`・:1084-1140、`docs/R1_4_1_CONTRACT.md:1405-1490`（§16.3.4〜§16.4）、`docs/M7_PLAN.md:1-45`・:495-560・:755-763、`docs/M7C_CONTRACT.md`（:78・:112・:128・:189-193・:302-305・:650・:690・:708・:747・:755・:757・:761・:779・:1292・:1294・:1369）、`docs/M7D_CONTRACT.md:140-144`・:743-770、`docs/B_DESIGN.md`（§0 :22-72、§3.1〜§3.6 :262-360、§4〜§8 :371-600、§9〜§12 :600-760）。

---

## 19. 記録

- 2026-11-28 **第 1 版**（契約の書き手。リードの指示で、調べ役の地図 5 つ（しくみ・月・年と等倍・段取りと CI・本人の言葉と時期）と、R1_4_2_CONTRACT・R1_4_2・R1_4_1_CONTRACT §16・M7_PLAN・M7C_CONTRACT・M7D_CONTRACT・B_DESIGN を読んで書いた。リードの既定は「版は 1.4.3、月と年と等倍を 1 つの版に、年が遅れたら月を先に、段は 1.3・1.4.2 の形、見本の写真の段を本体の前に、試作は契約で決める」で、全部そのまま採った）。
  - **B_DESIGN と違えた所**: (1) 月のア は最後の行をのばさず、区切りの線から下の柄だけをそろえ、短い月は白い紙（メモ欄の一部）にした（§4.1、0g-11）。(2) 段 1（見るだけ）・平行移動のずらし・照合の速い道・主スレッドの外の先読み・年の予定の順を作らず、測って記録する（§3.10、0g-25）。(3) 試作版を作らない（0g-42）。(4) 店の写真に「またいで書いた見本」を月・年では足さない（§12.6、0g-39）。(5) B_DESIGN §3.5 の「年の一覧が少し小さく開く」は、1.1.1 から開く大きさが固定なので当たらない（min だけが下がりうる、§5.4）。
  - **地図と違えた所・足した所**: 地図の開いた問いを、§17 の既定に決めた（番号・まとめ・落とし所・見本・試作・等倍の道・凍結のテスト・重さ・上限・今日・見出し・PDF・店の写真・脚注・1 ページの道・fixture）。地図の案のうち、`PaperSpan.single` と `ScreenshotModeSpanTests`・`PaperSpanTests`・`SpanRerunUITests`・KitChecks の 2 ファイルは、作りで今の答えを保てると分かったので、作り直しの表（§8.5）から外した。凍結のキャンバスは、等倍のためには触れずに済み（`ZoomReset` だけ）、紙のために `paperSpan` の本体だけを凍結の外へ出す形にした（§8.4）。ずらしの y の補正は、凍結のキャンバスにも `band(atY:)` の凍結の答えにも触れず、`PageScroll` の月の枝で直す形にした（§3.5）。年の予定は `allDayOnly` の既定値つきの引数で、凍結のテストを保った（§5.5）。互換の相手は、データのコードが 1.3 から変わっていないので足さないとした（§8.3）。
  - **コードで読み直して確かめた事**: 地図の主な行（`joins`・`layoutPages`・`relayoutPages`・`paperSpan`・`bandOverview`・`ZoomReset`・`SpanAlign.Floors`・`overviewCapPages`・`focus`・`paper(of:)`・`runExport`・`PDFPageRenderer` の月の枝・`EventStoreModel.events`・`StickyHeaderView` の分かれ・`SpanGuide`・`singlePageDemo`・`PageScroll.scrollDelta`・`SpanLayout.band`・脚注の字と comment・凍結の表の行と値・CI の凍結の段）は、読んだ所はどれも合っていた。凍結のキャンバスで種類を見るのは `paperSpan` の :2628-2630 だけだった。調べ役の 1 つが「DATA_1_1 に `SpanChecks.swift`」と書いた所は、実際は TESTS_1_3 の行（`SpanChecks.swift` は KitChecks の凍結）だった。
  - `docs/M7_PLAN.md` §4 の「次の版」の行を 1.4.3 の行にして 1.4.2 の行の後へ移し、この契約を指した。1.7・1.8 の行に「1.4.3 へ移した」を足した（ほかの行と番号は変えていない）。

（結果は `docs/R1_4_3.md` に書く。ここは契約の版の記録だけ。）
