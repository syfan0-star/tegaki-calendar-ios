# M7d 実装契約（1.4「新しい開発環境（Xcode 27）と iPhone Duo」）

> **本人が読む所**: すぐ下の §0（まとめ）だけで足ります。§10 の確かめ表は、TestFlight のビルドが届いたときに Claude が番号を書いて改めて渡します（今は開かなくて大丈夫です）。§1 から後は、作る人のための約束です。
>
> **この文書の決まり**: 1.4 の作業はこの文書に従います。元は [M7_PLAN.md](M7_PLAN.md) §4.5・§6.2（2026-10-31 の第 2 版の事実）と [M7C_CONTRACT.md](M7C_CONTRACT.md) §6.4・§12.4・§14 です。計画を書いた後に Web の事実が変わった所（Xcode 27.2 が出た・写真を上げる API が替わった・年齢区分の 2 問が API に入った、など）は、この文書で今に合わせました。**本人の決定（2026-11-20「Duoでもペンシルを使うので、その前提で作って下さい。」）は §1.2 と §4.8 で、計画（M7_PLAN §5 の末尾・§6.2 の「初回に Pencil が触れたら 1 回だけ案内」）より優先**します。**食い違う所はこの文書が優先**です。結果は `docs/M7D.md` に書きます（この文書の §14 は契約の版の記録だけ）。
>
> **材料**: 調査担当の [FACTS.md](m7d/FACTS.md)（Web。**2026-11-20 に読んだ**。URL は §13.2）と、コードの調べ役の [CODE_SURVEY.md](m7d/CODE_SURVEY.md)（origin/main 7895d40 を読んだ。コードは 955fe67 と 1 バイトも違わない）。**行番号は 7895d40 のもの**。印: 【未確認】は確かめられなかった事、【推定】は事実から考えた事。**第 2 版**で、2 つの批評（事実と実行の見方 F1〜F13、互換・データ・テストの見方 C1〜C20）の 33 件に答えた。答えの一覧は §15。

---

## 0. まとめ（本人向け）

### 0.1 1.4 ですること

- **アプリを作る Apple の道具を、新しい版（Xcode 27）に切り替えます。** 11/18 に Apple から届いたメール（ITMS-90725）のとおり、2027 年 4 月からは新しい道具で作ったアプリしか App Store に出せなくなるためです。
- **折りたたみの iPhone（iPhone Duo）で、画面いっぱいに表示します。** 今の 1.3 は、Duo の開いた大きな画面では真ん中に小さく出ます。1.4 では、開いた画面でも、閉じたときの外側の画面でも、その画面の広さに合わせて出します。
- **iPhone Duo では iPad と同じように、Apple Pencil で書き、指で紙を動かします**（11/20 のご指示どおり）。Pencil で書いている間は、手のひらが触れても線は引かれず、紙も横に動きません。指でも書きたいときは、今と同じくツールバーの「指でも書く」をオンにします。
  - 「指でも書く」は、Duo では iPad と同じくオフになります。いつオフになるかは次のとおりです。
    - **1.3 から更新した Duo**: Apple Pencil で**最初の 1 本を書き終えたとき**。それまで指で書いていた人が、更新しただけで書けなくならないようにするためです。
    - **1.4 を初めて入れた Duo**: Pencil で最初の 1 本を書き終えたとき。自動の確かめで「Duo の折り目（ちょうつがい）」をアプリが読めると分かったときは、初めて開いたときから。
    - **1.4 にしてから、ツールバーか設定で自分で切り替えたことがあれば**、その選び方のままです。
  - Duo かどうかは、機種の名前では見分けません。「**Apple Pencil が触れたこと**」と「**画面の折り目があること**」で見分けます。どちらも Apple の部品が教えてくれることです。画面の広さでは見分けません（Mac の iPhone ミラーリングでは、ふつうの iPhone の窓も広くできるためです）。
- **開いた広い画面では、見た目を iPad に近づけます**: 初めて開くページは月にし、横にしたときの一覧に上限をかけません（1 日の 0 時〜24 時がほぼ見えます）。設定などのシートの形は、**自動の確かめで開いた画面を撮れたときだけ** iPad と同じにします。閉じた外側の画面は、ふつうの iPhone と同じ見た目です。
- **App Store に iPhone Duo 用の写真を足します**（2027 年 4 月から必要になります。1.4 に間に合わなければ次の版で足します）。
- 1.3 のときの小さな残り（画面に出ない注の直しなど）を片づけます。

### 0.2 変わらないこと

- iPad と、ふつうの iPhone での使い方と、紙・線・字の見た目は 1.3 と同じです。**ふつうの iPhone の「指でも書く」も今までどおりオンです。**（Mac の iPhone ミラーリングで窓を大きく広げたときだけ、初めて開くページや横の一覧の見た目が広い窓の形になります。書き方は変わりません。）
- ボタンやシートなど、iOS の部品の形がほんの少し変わることはあります（新しい道具で作ると、iOS 27 の部品の形になるためです）。違いの大きい所は、確認ページに前と後の写真を載せます。
- 書いた線の保存の形・iCloud の記録・書き出しの形は変えません。**今までの手書きは 1 本も動きません。** 1.3 の端末とも今までどおり同期します。
- 画面の文は変えません。新しい文も足しません（設定の 1 文だけ、変える案を確認ページで見てもらいます。§0.4）。
- iOS 17 以上の iPad・iPhone で使えるのも同じです。
- データは集めません。広告もありません。値段も同じです。

### 0.3 段取りと目安の日

| いつ（目安） | すること | 本人にお願いすること |
| --- | --- | --- |
| 11/20〜11/21 | この契約。CI（自動の確かめ）を新しい道具へ切り替える | このまとめを読む（返事は要りません。§0.4 の問いは、答えられれば） |
| 11/21〜11/23 | Duo への対応（画面の広さ・Apple Pencil）、1.3 の残りの片づけ、Duo の写真、新機能の文の訳 | なし |
| 11/22 の夜 | 11/23（祝日）に TestFlight を渡せるかを決めて知らせる | 知らせるだけ |
| 11/23（早い道。**見込みは低め**）か 11/26〜11/27（ふつうの道） | TestFlight 1.4 と確認ページ | 確かめ表（§10）と、確認ページの「この内容で入れてよい」 |
| 確かめの後 | 審査に提出（早い道は 11/24、ふつうの道は 11/30〜12/1）→ 公開 → まとめる | 「1.4 を審査に提出して良い」「1.4 を公開して良い」「まとめて良い」 |
| 12/10 | ここまでに提出できていなければ知らせます | 知らせるだけ |
| 12/18 | 年末の前の最後の提出日（12/19〜1/4 は審査が遅れることがあるため【未確認】） | — |

- 計画の期限（遅くとも 2027-03-15 に提出）よりずっと前に出す段取りです。
- 自動の確かめ（CI）は、1 回に 1 時間半ほどかかります。GitHub では同時に動かせる数に上限（5 つ）があり、順番待ちが出ます。1 日に回せるのは数回です。早い道は、どの確かめも 1 回目で通ったときだけ間に合います。
- Claude の 1 週間の使える量が 95% に届いたら、その週の作業は止まります。止まっても間に合うように、12 月 18 日まで 3 週以上の余裕を置いています。

### 0.4 本人にお願いすること（言葉と操作の一覧。ほかの節はここを指します）

- **確認ページ 1 回**: 新機能の文（16 の言語）・iPhone Duo の写真（撮れたとき）・サポートページの変わる所（日本語・英語）・新しい道具で形が変わった部品の前と後の写真を、1 つのページで見せます。「**この内容で入れてよい**」の言葉をください。
  - 同じページで 1 つだけ選べます（**選ばなければ今のまま**）: 設定 › ページ の説明の「月と年は、**次の版から**順に対応します。」を「月と年は、**今後の版で**順に対応します。」に変えるか。1.4 は月と年を横につながないので、「次の版」が 1.4 のことと読まれうるためです（9 言語の訳は 1.3 のときに用意してあります）。
- **TestFlight 1.4 の確かめ表**（§10）。**ここは本人の端末でしか確かめられません。** iPad・iPhone の行と、**iPhone Duo（iOS 27.2 以降）と Apple Pencil（USB-C）の行（§10 の 18〜27）**があります。Pencil で書けるか・手のひらで線が出ないかは、自動の確かめ（シミュレータ）では試せないので、本人の Duo だけが頼りです。Duo が手元に無いときは、その行は「—」で構いません（そのときは自動の確かめの写真で判断し、新機能の文の Pencil の行は入れません）。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（TestFlight では無料。1.2.4 のときと同じです）。
- **言葉**: 「**1.4 を審査に提出して良い**」「**1.4 を公開して良い**」「**まとめて良い**」（1.4 を本流にまとめること）。前もってまとめてもらっても構いません（1.2.4 の「三つともYes」と同じ）。
- **答えてほしいこと（1 つ。答えが無くても既定で進めます）**:
  1. **中国の 2027 年の祝日が、祝日のデータの元（python-holidays）に入ったら、取り寄せて入れてよいですか。** 11/20 の時点ではまだ入っていません（中国政府の発表は 11/5 に出ています）。入れるときは、**ほかの国の祝日のデータも同じ版に新しくなります**（例: ハンガリーの 12 月 24 日）。既定: 入ったときに改めて聞きます。前もって「入ったら取り寄せてよい」と言ってもらえれば、待たずに入れます。

### 0.5 本人が決めなくてよいこと

- 道具の版、自動の確かめのやり方、写真の撮り方と大きさ、Duo での細かい動き（Duo の見分け方・初めて開くページ・シートの形・縮めたときの上限・外側の画面での動き・新しい iPhone に移したときの扱い）、1.3 の残りの片づけ方。どれも既定で決め、理由を §12 に書きました。
- **Duo で Pencil を使う前提**は 11/20 のご指示で決まりなので、もう一度お聞きすることはありません。
- **年齢区分の新しい 2 問**（位置を人と共有するか・出会いの機能があるか）は、2 問とも「いいえ」で Claude が入れます。年齢区分は 4+ のままです。Apple の仕組み（API）に 11/18 から入ったので、本人の操作は要らない見込みです。

### 0.6 知っておいてほしいこと

- iPhone Duo の画面の大きさ（ポイント）は、Apple がまだ出していません。自動の確かめのシミュレータで測ってから決めます。
- **自動の確かめで Duo を「開いた形」にできる見込みは低いです**（シミュレータは閉じた外側の画面で起動します。開く操作の道具は、まだ試作の版の Xcode にしかありません）。**開けない前提で進めます**: App Store の Duo の写真は外側の画面だけ、設定などのシートの形は今のまま、新機能の文は確かめられた範囲だけを書きます（§8.1）。開いた画面の見え方は、本人の Duo（あれば）で見てもらいます。
- Duo の Apple Pencil は **iOS 27.2 から**使えます（Apple の案内、11/5）。Duo の iOS が 27.2 より前なら、先に iOS を新しくしてください。Duo で使える Pencil（USB-C）には、ダブルタップ・スクイーズ・筆圧・ホバーがありません（Apple の案内）。外側の画面でも Pencil が使えるかは、Apple の案内に書いてありません【未確認】（§10 の 24 で見ます）。
- Duo で Pencil を使わない人も、ツールバーの「指でも書く」をオンにすれば指で書けます（iPad と同じ）。
- Duo のバックアップを Pencil の使えない iPhone に戻したときは、アプリが自動でオフにした「指でも書く」は 1 回だけオンに戻ります（指で書けなくならないように）。自分でオフにしていたときは、そのままです。
- Apple の期限: iOS 27 の道具での提出は **2027 年 4 月から**（何日かはまだ出ていません）。Duo の写真も **2027 年 4 月から**。年齢区分の 2 問は **2027-01-12 まで**。
- 1.4 を 12 月の初めに出せれば、次の 1.4.1（ペンの色・メモ欄の紙）を前倒しできます（その版の契約で決めます）。ペンの色とメモ欄の紙は、画面の新しい文と手書きのデータの部品に触れるので、1.4 には混ぜません（§1.4）。

---

## 1. 土台・決定・範囲

### 1.1 土台のコード

- ブランチ `r14`。main の **7895d40**（1.3 を main に入れた commit、2026-11-20）から切る。`Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は **955fe67**（1.3 の凍結の表の基準、ビルド 26 のコード）と 1 バイトも違わない（`git diff --stat 955fe67 7895d40` は `docs/M7C.md` と 13 の `whatsnew.txt` だけ）。
- `r13` の最後の記録 ff4e3c4（`docs/M7C.md` の 3 行だけ、main に無い）は、リードが `r14` の最初の docs の commit に写す（[skip ci]）。
- 版は `MARKETING_VERSION "1.4"`（今は `project.yml:23` で "1.3"）。配る先は **iOS 17.0 のまま**（`project.yml:8`・`:21`・`:45`・`:147`・`:184`）。`TARGETED_DEVICE_FAMILY "1,2"`・`UIRequiresFullScreen: false`・4 方向（`project.yml:99-110`）も変えない。
- この Mac には Xcode もシミュレータも無い。TegakiKit は `swift build` と KitChecks、アプリは `tools/typecheck/typecheck.sh`（Mac Catalyst。CLT の macOS 27.2 SDK・Swift 6.4.2 で、7895d40 のアプリ・テスト・Kit とも OK・警告 0、CODE_SURVEY の頭）まで。**iOS 27 SDK の本当のビルド・シミュレータ・Duo は GitHub Actions の CI だけ**。

### 1.2 本人の決定（確定。再検討しない）

- M7_PLAN §4.5: 1.4 は新しい開発環境と iPhone Duo だけ。他の機能は混ぜない。遅くとも 2027-03-15 に提出。
- 1.4.1 = ペンの色・メモ欄の紙（2026-11-07「ほかは全部おすすめで」。PLAN_PEN_COLORS.md・PLAN_MEMO_PAPER.md の頭）。
- 進め方: 「予定に拘らず進める」（11/13）、「なるべく前倒し」、「どんどん進めていきましょう」（11/20）。途中で許可を取らず、既定で決めて記録し、最後にまとめて報告する。本人の言葉が要るのは、実機の確かめ・確認ページ・提出・公開・main へまとめる・外からのデータの取り寄せだけ。
- **2026-11-20「Duoでもペンシルを使うので、その前提で作って下さい。」**: Duo では iPad と同じに振る舞う。Pencil が書き、指が紙を動かす。「指でも書く」は Duo では既定オフ。書いている間の手のひらの規則は iPad と同じ。ツールバーと初めての案内は、幅が許す所は iPad と同じ。Duo の見分け方と外側の画面での動きは契約で決める（§4.8）。**本人にもう一度聞かない。**

### 1.3 範囲

| # | 何をする | どこ（役） | 段 |
| --- | --- | --- | --- |
| 1 | CI を `xcode-27` の実行機の **Xcode 27.2** へ（compat-v1-0 は除く、§3.9）。機種の名前・必須の機種の確かめ・**XcodeGen を版と sha256 を決めた公式の zip で入れる**（§3.3 の 4） | C | D0 |
| 2 | 版 1.4。アーカイブの SDK と最低版の確かめ（`testflight.yml`）と、TestFlight へ試しに上げる（配らない） | C・リード | D0 |
| 3 | J-4 の基準を 955fe67 の Xcode 27.2 の写真に替える。**SDK の差の地図を D0 の関門にする**（§3.5・§3.6） | C・リード | D0 |
| 3b | 1.3 のテストと fixture のバイトを守る表 `TESTS_1_3.sha256`・`FIXTURES_1_3.sha256`（§5.5） | C | D0 |
| 4 | Duo を測る（新しい `duo.yml` の `duo-probe` → `duo-shots`）と、測った値の KitChecks の節「duo (1.4)」 | C・U・K | D0〜D1 |
| 5 | **見た目を窓の大きさ（W）で決める**: 初めて開くページ（§4.3）、シートの形（§4.4）、広い窓の横の一覧に上限をかけない（§4.7。窓の plan の `overviewCap` を外す） | S・U・K | D1 |
| 5b | **Duo の Apple Pencil（本人の決定）**: 「指でも書く」の決め方（Kit の純粋な状態の型 `FingerDefault`。信号は Pencil の触れ P と折り目 H だけ）、触れの見張り（凍結の `InkTouchObserver` を窓に付けて使うだけ）、端末に結びつけた印（§4.8） | S | D1 |
| 6 | 倍率を窓から: `InkSnapshot` を呼ぶ 2 か所、`PaperView`（§4.5） | S・P | D1 |
| 7 | Duo の UI テスト（`DuoLayoutUITests`）、開閉のテスト（`DuoFoldTests`、`DuoHingeUITests`） | U・S | D1 |
| 8 | 1.3 の残り（§1.5 の表） | X・S・K・U | D1 |
| 9 | 互換の相手に本物の 1.3（955fe67）を足す（§5.3） | C | D1 |
| 10 | 端末の種類の見張り `idiom_check.py`（§4.1） | C | D1 |
| 11 | App Store: Duo の写真（§7）・16 ロケールの新機能の文・審査メモ・SUPPORT（§8）と、訳と逆翻訳 | U・C・A・W・X・R・リード | D2 |
| 12 | 年齢区分の新しい 2 問を API で「いいえ」（§9.5） | リード | S0'〜D4 |
| 13 | 中国の 2027 年の祝日（**python-holidays の正式版に入ったときだけ**。了承はそのときに聞く。§9.6） | C | 条件つき |

### 1.4 範囲外（1.4 ではしない）

- **ペンの色・メモ欄の紙（1.4.1）**。どちらも小さく切り離せない: ペンの色は新しい色の板と新しい文（7〜8 件、PLAN_PEN_COLORS.md §5.5）が要り、凍結の `Ink/PencilInteraction.swift`（`DATA_1_1.sha256` の 8 行目）に触れる案もある（PLAN_PEN_COLORS.md:103、M7C_CONTRACT §6.4）。メモ欄の紙は設定の新しい行と文（PLAN_MEMO_PAPER.md §2）が要る。どちらも 9 言語の訳と逆翻訳と、本人の見た目の確かめがかかり、「画面の文を変えない・機能を混ぜない」1.4 の形と合わない。
- Pencil が初めて触れたときの**新しい文の**案内（M7_PLAN §5 の末尾・§6.2 の案「『指でも書く』をオフにすると、手のひらで線が出ません」）。本人の決定で Duo の既定そのものを iPad と同じ（オフ）にするので、新しい文は要らない（§4.8）。
- Duo の設定の画面の変更（「Apple Pencil」の行・消しゴムの脚注）。Duo の Apple Pencil（USB-C）には**ダブルタップ・スクイーズ・筆圧・バレルロールが無く、Duo ではホバーも使えない【事実 [S54][S19]】**ので、iPad だけの行は iPad だけのまま（§4.1 の 8・9）。
- 折り目（`UIHinge`）をレイアウトに使うこと（Apple が「レイアウトに使わない」と書く [S52]。1.4 は「指でも書く」の既定にだけ使う、§4.8）。半開きの折り目を避ける `ReservedRegion`、複数の窓（`UIApplicationSupportsMultipleScenes`。入れると K-3 が破れうる、M7C_CONTRACT §3.13）、Duo だけの画面。
- 1 ページの道の幅の読み違い（凍結の `InkCanvasView.swift:1257-1260`）の直し（§1.5。受けて記録し、次に凍結の表を作り直す版で直す）。
- 米国の年齢の法律（2027-01-01、カリフォルニア州・アラバマ州）の見直し（R1_2_2.md:758 の約束。12 月に Apple の発表を読む）は 1.4 と別の仕事。直しが要ると分かったら、その日に 1.4 に入れるか別の版にするかを決め、M7D.md に書く（入れるなら 1.4 は確かめ直し）。
- アプリの画面の文の変更（L-3。8 キーの comment は利用者に出ないので除く。N-3 の 1 文は本人が確認ページで選んだときだけ、§1.5）。zh のトーストの語（M7C.md:882 の 4）も変えない。
- 凍結の表の 20 ファイルの変更（§5.4 の例外の手順を除く）。`SpanGuard` の `.prototype`・`prototypePrefix` も残す（§12 の 0d-16）。
- 1.2 から持ち越した細かい訳の直し。主言語（en-US のまま）。nl-NL・sv の文（足さない）。Web 版の変更。
- iPad の横向きの CI の写真（iPadOS は向きの要求を無視する、M7C_CONTRACT §10.5）。
- 店の今の写真（13 インチ・6.9 インチ・6.3 インチ）の撮り直し（§7.4）。

### 1.5 1.3 の残りの扱い

| 残り（元） | 1.4 で | 役 | 確かめ |
| --- | --- | --- | --- |
| S6 のリードの決定 2 (a): 8 キーの comment（`settings.page.header`・`settings.page.span`・`settings.page.span.footer`・`span.guide.day.oneFinger`・`.twoFingers`・`span.guide.week.oneFinger`・`.twoFingers`・`span.stageTwo.notice`。`tools/l10n/source/app-U.json:1700`〜`:2243`） | 「jaOnly …」の古い comment を、今の役目の comment に書き直す。xcstrings は `tools/l10n/build.py` が作り直す（同じ commit） | X | 「Localized bundle check」（作り直しと `git diff --exit-code`）。利用者に出ない |
| S6 のリードの決定 2 (b): 1 ページの道で H1・H2 がキャンバスを作り直すときに `revealRect` を消す | `CalendarRootScreen.swift:1751-1758`（`remoteDeleted`）と `:2344-2348`（`chooseAccount` の `closed:`）に `revealRect = nil` を 1 行ずつ | S | `OnePageRevealTests`（§6） |
| S6 のリードの決定 2 (c): 試作がまだあるように読める古い注 | `TegakiKit/Sources/Layout/SpanPlan.swift:4-7`（「Duo の内側は 1.4 の」）・`:113`・`:117`・`:121-122`・`:130`、`WeekLayoutEngine.swift:31`、`Views/SpanGuideView.swift:16` の注だけ（`:157` の来歴の注は残す）。**`TegakiKit/Sources/KitChecks/SpanChecks.swift:380-383`（「1.4 checks it again」）は直さない**（`TESTS_1_3` に入れる。測った値の行は `DuoChecks.swift` の注が指す） | K・U | 注だけ。KitChecks の数は同じ |
| S6 のリードの決定 1: `SpanGuard` の `.prototype` | **残す**（凍結の 19 行目。消すと表の作り直しと KitChecks の数の変更）。次に表を作り直す版（1.4.1 の見込み）で決める | — | — |
| S6 のリードの決定 3: 本物の 1.3 を互換の相手に | 足す（§5.3） | C | compat-v1-0 |
| 上限ありのリードの決定 1（倍率の比の鍵が 2 本の道で 1 つ） | 受けたまま。Duo での差（内側 1.0〜1.1 倍、外側 1.2〜1.5 倍【推定】、CODE_SURVEY §3.2）を `duo-shots` で測って M7D.md に書く | U | 記録 |
| 上限ありのリードの決定 2（レーンが多いとき窓を広げるのは、上限のある所では働かない） | 受けたまま。Duo の内側（広い窓）は §4.7 で上限をかけないので、窓は広がりうる（iPad と同じ） | — | DuoChecks |
| 上限ありの確かめの残り | 無し（M7C.md の「1.3 の後に残すもの」） | — | — |
| **1 ページの道の幅の読み違い**（M7C.md:824 の 7「1.4 以降で考える」）。凍結の `InkCanvasView.swift:1257-1260` は、幅が変わったとき、新しい幅と古い位置を混ぜて真ん中を読む（`centerPaper.x = (oldOffset.x + viewport.width / 2) / oldZoom`）。Duo の開閉（669 → 466 pt）では、拡大しているとき約 100 pt 横にずれる【推定】 | **直さない（受けて記録）**。凍結の 1 行目に触れ、iPad・iPhone の回転の動きも変わる（1.4 は今の機種の動きを変えない版）。保存・同期には触れない（見ている位置だけ）。次に凍結の表を作り直す版（1.4.1 の見込み）で直す。確かめ表の行 25 に「見ていた所が少し横にずれることがある（前からの動き）」と書く | — | `DuoFoldTests` の 1 ページの道は、真ん中の x を比べない（§4.9） |
| **N-3 の言い方**（M7C.md:535 の 2、`docs/store/PROPOSALS_1_3.md` §2）。「月と年は、次の版から順に対応します」は、1.4 では「次の版＝1.4」と読まれうる | **確認ページで選べるようにする（既定は今のまま）**。本人が「変える」を選んだときだけ、L-3 の例外として `settings.page.span.footer` の 2 つ目の文を ja と 9 言語で替える（訳と元を見ない逆翻訳は 1.3 で済み。jaSha1 も替わる）。そのときは J-1 の基準・`baseline.py`・`lint.py` を直し、J-4 で違ってよい写真にその文が写る設定の写真を足す（名前は前もって M7D.md に）。選ばなければ今のまま（1.3 の確認ページの「選ぶ 3」と同じ扱い。本人が承認した固定の文を、本人の言葉なしに変えない） | X・リード | `build.py --check`・`baseline.py --check`・lint・J-4 |
| 審査メモの 1 の「It」と 4（M7C.md:475） | 1.4 の審査メモで「What is new in 1.3」の段ごと入れ替わるので消える（§8.3） | A | — |
| 中国の 2027 年の祝日 | §9.6（条件つき） | C | CI の祝日のテスト |
| 年齢区分の 2 問 | §9.5 | リード | 読み戻し |
| Xcode 27 への移行（ITMS-90725） | この版の中心（§3） | C | §3.3 の関門 |

---

## 2. 構成とファイル所有

1 つのファイルの持ち主は 1 つの役。commit は `git add <ファイル名>` で、持ち主のファイルだけを入れる。役の表は §9.3。

```
.github/workflows/build.yml          C  実行機・Xcode 27.2・機種・必須の機種の確かめ・XcodeGen の固定・TESTS_1_3・FIXTURES_1_3・idiom_check・KitChecks の閾値・compat-v1-0 の v13・時間の上限（§3、§5）
.github/workflows/duo.yml            C  新しい。duo-probe（D0）・duo-shots（D1）・duo-hinge。workflow_dispatch と枝 r14-duo* だけで走る（§3.10）
.github/workflows/testflight.yml     C  実行機・Xcode 27.2・XcodeGen の固定・アーカイブの SDK と最低版の確かめ（§3.4）
.github/workflows/ja-baseline.yml    C  実行機・Xcode 27.2・基準 955fe67・写真の段を 955fe67 の build.yml から写し直す（§3.5）
.github/workflows/store-shots.yml    C  実行機・Xcode 27.2・XcodeGen の固定・Duo の組（§7）
project.yml                          C  MARKETING_VERSION "1.4"（だけ）
tools/ci/install-xcodegen.sh         C  新しい。版と sha256 を決めた XcodeGen の公式の zip を入れて、版を確かめる（9 か所から呼ぶ。§3.3 の 4）
tools/l10n/ja-baseline-ref-1.4.txt   C  新しい。955fe678ec9f999ac45fac1b372f246e43c02f95 の 1 行
tools/span/TESTS_1_3.sha256          C  新しい（§5.5）。D0 の commit
tools/span/FIXTURES_1_3.sha256       C  新しい（§5.5）。D0 の commit
tools/duo/idiom_check.py・idiom-allow.txt  C  新しい（§4.1）
tools/duo/shot_checks.py             C  新しい。Duo の写真の確かめ（黒い写真・端の列・寸法・measure の行）と、その確かめを落とす作り物の写真の自己試験（§6）
tools/span-compat/run.sh・README.md・Probe/main.swift  C  v13 と、版ごとの確かめの口 versionExtraChecks（§5.3）
tools/span-compat/v10・v11・v123/Version.swift  C  何もしない versionExtraChecks を足すだけ
tools/span-compat/v13/Version.swift  C  新しい
tools/span-compat/AppTests/Real13LedgerTests.swift  C  新しい
TegakiKit/Sources/KitChecks/DuoChecks.swift  K  新しい。節「duo (1.4)」の span plan の行（§4.6・§4.7）と、状態の行を計算し直す口 --span-state（§3.3 の関門 3）
TegakiKit/Sources/KitChecks/main.swift       K  2 つの節（duo・window & finger）と --span-state を呼ぶ行
TegakiKit/Sources/Layout/SpanPlan.swift      K  注だけ（§1.5 (c)）。規則・数は 1 字も変えない
TegakiKit/Sources/Layout/WeekLayoutEngine.swift  K  注だけ（§1.5 (c)）
TegakiKit/Sources/Layout/WindowClass.swift   S  新しい。窓の大きさで見た目を決める純粋な関数と、初めて開くページを 1 回だけ決める小さな状態の型（§2.1）
TegakiKit/Sources/Layout/FingerDefault.swift S  新しい。「指でも書く」をアプリが替えるかを決める純粋な状態の型（§2.1・§4.8）
TegakiKit/Sources/KitChecks/WindowFingerChecks.swift  S  新しい。節「window & finger (1.4)」（§6。手元の swift run KitChecks で変異を見る）
Sources/TegakiCalendar/Support/PencilPhone.swift  S  新しい。FingerDefault のつなぎ: 端末の印・折り目の見張り（H）・触れの見張り（凍結の InkTouchObserver を窓に付ける）・本人の切り替え（§2.1・§4.8）
Sources/TegakiCalendar/Persistence/AppSettings.swift  S  新しい鍵 1 つ（allowFingerDrawingAuto）と、週と日の案内の札の記録を消す口。isExistingUser の 3 つの鍵は変えない
Sources/TegakiCalendar/Views/CalendarRootScreen.swift  S  初めて開くページ（§4.3）・InkSnapshot の scale（§4.5）・revealRect（§1.5 (b)）・シートに窓の大きさを渡す・PencilPhone のつなぎと Binding（§4.8）・ScreenPaths に今の窓を読む口を渡す（§4.7）
Sources/TegakiCalendar/Span/ScreenPaths.swift   S  Device に wide。makeSession が overviewCap: !wide と、今の窓を読む口を SpanSession に渡す（§4.7）。atCappedOverview・shotPaperOffset は変えない
Sources/TegakiCalendar/Span/SpanSession.swift   S  redecide で次の plan の overviewCap を口から読む（口が無ければ 1.3 のまま。§4.7）
Sources/TegakiCalendar/Views/PaywallSheet.swift  U  シートの形（§4.4）
Sources/TegakiCalendar/Views/EventEditorSheet.swift  U  シートの形（§4.4。Scribble の注は変えない）
Sources/TegakiCalendar/Views/SpanGuideView.swift  U  注だけ（§1.5 (c)）
Sources/TegakiCalendar/Support/ScreenshotMode.swift  U  写真モードの --screenshot-measure（測った値をログへ。§4.2）と --screenshot-pencil-phone（Duo の写真。§7.3）
Sources/TegakiCalendar/Paper/PaperView.swift     P  倍率を特性の変化でも読み直す（§4.5）
tools/l10n/source/app-U.json（と作られる xcstrings）  X  8 キーの comment（§1.5 (a)）。N-3 の文は本人が選んだときだけ（§1.5）
Tests/TegakiCalendarTests/WindowClassTests.swift      S  新しい（つなぎの確かめ。純粋な関数の表は KitChecks）
Tests/TegakiCalendarTests/PencilPhoneTests.swift      S  新しい（§4.8）
Tests/TegakiCalendarTests/CappedOverviewWideTests.swift  S  新しい（§4.7）
Tests/TegakiCalendarTests/OnePageRevealTests.swift    S  新しい
Tests/TegakiCalendarTests/SnapshotScaleTests.swift    S  新しい
Tests/TegakiCalendarTests/DuoFoldTests.swift          S  新しい（テストだけ。凍結のコードは呼ぶだけ）
Tests/TegakiCalendarTests/PaperViewScaleTests.swift   P  新しい
Tests/TegakiCalendarUITests/DuoLayoutUITests.swift    U  新しい（Duo のときだけ走る）
Tests/TegakiCalendarUITests/DuoHingeUITests.swift     U  新しい（#if DUO_HINGE の中だけ。duo-hinge のジョブだけ）
docs/store/*/whatsnew.txt（12 のロケールのフォルダと source-ja）・review-note.txt  A  §8
docs/SUPPORT.md・SUPPORT.en.md       W  §8.4
docs/i18n/（逆翻訳と REVIEW.md）     R  §8.2
docs/M7D.md・docs/M7_PLAN.md の注    リード  記録・§4.5 の頭に「1.4 の約束は M7D_CONTRACT.md」
```

- **変えないもの**: 凍結の表の 20 ファイル（§5.4。`InkTouchObserver` は新しいインスタンスを作って使うだけ）、`TESTS_1_2_3.sha256` の 8 ファイル、`TESTS_1_3.sha256` と `FIXTURES_1_3.sha256` のファイル（§5.5。KitChecks の `OverviewCapChecks.swift`・`SpanChecks.swift`・`SpanInkChecks.swift`・`WeekMemoChecks.swift` を含む）、compat11・Compat10・compat-span の fixture と `EXPECTED_MIN`（225・599）、`tools/l10n/ja-baseline-ref.txt`（<1.1.1>。compat-v1.0 の weekstart-compat が読む）と `ja-baseline-ref-1.3.txt`（記録として残す。1.4 では読まない）、画面の日本語の文（L-3。N-3 の例外は §1.5）、`ToolbarView.swift`・`SettingsScreen.swift`・`OnboardingView.swift`・`SpanGuideView.swift` の動き（ツールバー・設定・初めての案内は今のままで iPad と同じになる、§4.8）、`AppSettings.isExistingUser` の 3 つの鍵と、`allowFingerChosen` を書く時（1.2 の「前からの利用者」の見分けを動かさない）、`SpanPlan` の規則と数（§4.7）。
- **Kit の新しいコードは Swift 6.3（Xcode 26.6）でも通ること**（compat-v1-0 が `macos-26` で今の木の Kit をビルドする、§3.9）。iOS 27・Swift 6.4 だけの API を Kit に入れない（UIKit の `UIHingeInteraction` などはアプリの側だけ）。
- **役 L（台帳とキャンバス）と Y（同期）は 1.4 では作らない**。要る直しが出たら §5.4 の例外の手順（§12 の 0d-15）。

### 2.1 接点（宣言。新しい引数には既定値を付け、省けば 1.3 と同じ動き）

```swift
// TegakiKit/Sources/Layout/WindowClass.swift（役 S）。窓の大きさで「見た目」だけを決める（Apple の Duo の案内 [S15]: 窓の大きさで決め、
// idiom・サイズクラス・UIScreen.main で端末を見分けない）。入力（「指でも書く」）には使わない: Mac の iPhone ミラーリングでは、
// ふつうの iPhone の窓も広くできる [S15]（§4.8）。純粋な関数。Swift 6.3 でも通る形。
public enum WindowClass {
    /// 広い窓の短い辺の下限（pt）。アプリの見出しが 1 段になる幅 CalendarRootScreen.compactWidth（:319）と同じ 600
    /// （アプリのテスト testWideShortSideIsTheCompactWidth で同じことを確かめる）。§4.2 で測って決め直すことがある（§4.7）。
    public static let wideShortSide: CGFloat = 600
    /// 広い窓: 短い辺が wideShortSide 以上。nil・0・負・有限でない大きさは false。
    public static func isWide(_ windowSize: CGSize?) -> Bool
    /// 初めて開くページ: stored があればそれ（覚えたページ）。iPad は月（1.3 のまま）。それ以外は、大きさが測れていれば
    /// isWide で月、でなければ週（幅でなく短い辺: ふつうの iPhone を横にして初めて開いても週、1.3 と同じ）。測れていなければ nil。
    public static func openingKind(stored: PageKind?, isPad: Bool, windowSize: CGSize?) -> PageKind?
    /// 広い窓でもフォームシートにするか。§4.4 の確かめで D1 に決める定数。既定 false（1.3 と同じ。内側を撮れないときは false のまま）。
    public static let formSheetOnWide: Bool
    /// フォームシートにするか: isPad || (formSheetOnWide && isWide(windowSize))。
    public static func usesFormSheet(isPad: Bool, windowSize: CGSize?) -> Bool
    /// 横の道の窓の plan に一覧の上限（P-B6 イ）をかけるか: !isWide(windowSize)（測れていなければ true＝1.3 と同じ）。
    /// iPad は plan の機種が .iPhone でないので、どちらでも上限は無い（SpanPlan.overviewCapPages）。
    public static func capsOverview(windowSize: CGSize?) -> Bool

    /// 初めて開くページを 1 回だけ決める状態。窓の大きさが appear() より先でも後でもよい（C2）。決めた後は替えない。
    public struct Opening: Equatable, Sendable {
        public init(stored: PageKind?, isPad: Bool)          // stored か iPad なら、ここで決まる
        public private(set) var decided: PageKind?
        public mutating func windowSize(_ size: CGSize?) -> PageKind?   // まだなら openingKind で決める。決まった後は同じ値
    }
}

// TegakiKit/Sources/Layout/FingerDefault.swift（役 S）。「指でも書く」をアプリが替えるかを決める純粋な状態の型（§4.8）。
// UIKit・UserDefaults・窓の大きさを読まない。入力は下の口だけ。Swift 6.3 でも通る形。
public struct FingerDefault: Equatable, Sendable {
    /// 今の「指でも書く」の値を誰が書いたか（印 allowFingerDrawingAuto から。§4.8 の表）。
    public enum Origin: Equatable, Sendable { case app, carried, moved, person }
    /// 信号。窓の大きさ（W）は入れない（F1）。
    public enum Signal: Equatable, Sendable, CaseIterable { case hinge, pencil }
    /// アプリがすること（つなぎ PencilPhone.apply が UserDefaults と AppSettings に書く）。
    public enum Action: Equatable, Sendable {
        case turnOff(rearmGuide: Bool)   // allowFinger = false、印 = この端末。rearmGuide なら週と日の札の記録を消す（.app のときだけ true）
        case turnOnAgain                 // allowFinger = true、印 = この端末（別の端末でアプリがオフにした値を、Pencil の無い端末で 1 回だけ戻す）
        case rebind                      // 印 = この端末（値は替えない。別の端末から来たオフを、折り目のある端末で受け継ぐ）
    }
    /// 印の読み方: "person" → .person。device と同じ → .app。無い・空 → .carried。ほかの字 → .moved。
    /// device が nil（端末の印がまだ読めない）なら、"person" 以外は .carried（この起動では P だけで動く。安全な側）。
    public static func origin(mark: String?, device: String?) -> Origin
    public init(isPad: Bool)
    /// appear() が 1.3 の既定を書いた後に 1 回（origin は必ず書いた後に読む。C2）。
    public mutating func appeared(allowFinger: Bool, origin: Origin) -> Action?
    /// 折り目の見張りの答え。true: hinge がある。false: 無い・API が無い・使わない・2 秒来ない。何度来てもよい。true の後に false が来ても true のまま。
    public mutating func hinge(_ present: Bool) -> Action?
    /// 紙でもボタンでも、窓のどこかに触れた（Pencil か）。数を 1 足す。Pencil なら P を覚える。
    public mutating func touchDown(pencil: Bool) -> Action?
    /// 離れた・取り消された（数を 1 引く）。0 になったときに保留の動きをする。
    public mutating func touchUp() -> Action?
    /// 見張りの reset（残った触れを全部離れたと数える）。
    public mutating func touchesReset() -> Action?
    /// 本人がスイッチを触った（origin = .person）。以後は何もしない。
    public mutating func personSwitched()
}
// 動く条件（全部そろったときだけ。§4.8 の表）: !isPad、appeared 済み、触れている数が 0、本人がまだ触っていない。
// 1 つの入力で返す動きは高々 1 つ。返した後の状態（allowFinger・origin）は型の中で更新する（turnOff・turnOnAgain・rebind の後は .app）。

// Support/PencilPhone.swift（役 S）。FingerDefault のつなぎ。iPad では何も付けない。
@MainActor final class PencilPhone {
    static let markKey = "allowFingerDrawingAuto"   // String。"person" か、アプリが値を書いた端末の印。UserDefaults.standard だけ（iCloud では同期しない。バックアップと機種の移し替えでは運ばれうる【推定】）
    static let personMark = "person"
    /// この端末の印: UIDevice.current.identifierForVendor?.uuidString。別の端末では別の値、端末の再起動の後で最初のロック解除の前は nil [S60]。
    /// 外へは送らない（App Privacy の「データの収集なし」は変わらない）。
    static func deviceMark() -> String?
    static func origin(_ defaults: UserDefaults, device: String?) -> FingerDefault.Origin
    /// 本人の切り替え: allowFinger を書き、印を "person" に。CalendarRootScreen が ToolbarView（:886）と SettingsScreen（:938）に渡す
    /// Binding の set がここを呼ぶ（get は今の allowFinger）。
    static func personSet(_ value: Bool, defaults: UserDefaults)
    /// 折り目を使うか。§4.2 の測りで D1 に決める定数（Duo のシミュレータで hinge が nil でなく、iPhone 17 で nil と測れたときだけ true）。
    static let usesHinge: Bool
    /// 窓に付ける（iPad でないときだけ）: 凍結の InkTouchObserver の新しいインスタンスを UIWindow に足し、onChange の .down(type)・.up を
    /// FingerDefault.touchDown(pencil: type == .pencil)・touchUp に渡す（Pencil・指・ポインタを全部数える。C6）。delegate は同時の認識を全部 true。
    /// usesHinge が true、iOS 27.1 以上、Mac Catalyst でない（#if !targetEnvironment(macCatalyst)。Xcode 27.2 の既知の不具合 185924957 [S5]）とき
    /// だけ、UIHingeInteraction を窓のルートの view に足し、update の hinge != nil を FingerDefault.hinge に渡す [S52][S53]。
    /// それ以外はすぐ hinge(false)。最初の update が 2 秒来なければ hinge(false)（待ちは注入できる sleep で）。レイアウトには使わない。
    func attach(to window: UIWindow, isPad: Bool)
    /// 動きを書く（写真モードでも同じ）。turnOff: allowFinger = false・印 = deviceMark()・rearmGuide なら AppSettings で週と日の札の記録を消す。
    /// turnOnAgain: allowFinger = true・印 = deviceMark()。rebind: 印 = deviceMark()。deviceMark() が nil なら印は書かない。
    func apply(_ action: FingerDefault.Action)
}

// Views/CalendarRootScreen.swift（役 S）。§4.8
//   appear() の今の既定の書き込み（:1253-1257、allowFingerChosen の書く時と値は変えない）で書いたとき（その起動が初めての起動）だけ、
//   同時に印 = deviceMark()（nil なら書かない → .carried）。その後に FingerDefault.appeared(allowFinger:origin:)。
//   ToolbarView と SettingsScreen に渡す allowFinger の Binding を包み、set で PencilPhone.personSet と FingerDefault.personSwitched。
//   最初の配置で窓（UIWindow）が分かったら PencilPhone.attach。
//   初めて開くページは WindowClass.Opening（init で作り、noteWindowSize :2863-2872 で windowSize を渡す）。決まるまでキャンバスを作らない（§4.3）。

// TegakiKit/Sources/Layout/SpanPlan.swift（役 K）。注だけ。maxVisiblePages・overviewCapPages・zoomBounds の規則と数は変えない（§4.7）。

// Span/ScreenPaths.swift（役 S）。§4.7
//   struct Device（:33-36）に `var wide: Bool = false` を足す（既定値つき: 既存のテストの書き方は同じ）。device(isPad:windowSize:screen:)（:265-269）が
//   WindowClass.isWide(windowSize) を入れる。makeSession（:414-425）は overviewCap: WindowClass.capsOverview(windowSize)（1.3 は true 固定）と、
//   overviewCapNow（今の窓を読む口。CalendarRootScreen が渡す）を SpanSession に渡す。
//   atCappedOverview（:1022-1027）と shotPaperOffset（:1186-）は変えない。どちらも layout.plan.overviewCap を見るので、広い窓では false になり、
//   今日のページは 0:00 から開く（C1）。

// Span/SpanSession.swift（役 S）。§4.7
//   init に `overviewCapNow: (() -> Bool)? = nil` を足す。`let overviewCap`（:262）を `private(set) var` に。
//   redecide(orientation:paperArea:)（:1059-1064）は、口があれば overviewCap = overviewCapNow() にしてから次の plan を作る。口が無ければ 1.3 と同じ。
//   口は今の窓の大きさを UIKit の窓の bounds から読む（場面の窓。SwiftUI の windowSize の更新の順に頼らない。凍結のキャンバスの redecideWindow
//   :3289-3296 が呼ぶ時に、UIKit の窓の bounds はもう新しい）。

// Views/PaywallSheet.swift・EventEditorSheet.swift（役 U）
//   init に `windowSize: CGSize? = nil` を足す。nil なら今の idiom の分かれ道（1.3 と同じ）。
//   値があれば WindowClass.usesFormSheet の答えで: true → iOS 18 以上は .presentationSizing(.form.fitted(...))（今の iPad と同じ）、
//   iOS 17 は今の iPad と同じ素のまま。false → .presentationDetents([.large])。

// Views/CalendarRootScreen.swift（役 S）
//   InkSnapshot.render(strokes:cells:) の 2 か所（:1935・:2989）に scale: displayScale（@Environment(\.displayScale)）を渡す。
//   InkSnapshot.swift（凍結）の既定の引数 UIScreen.main.scale は残すが、アプリから既定のまま呼ぶ所は無くなる。

// Paper/PaperView.swift（役 P）
//   didMoveToWindow の読み方（:228-233）は残し、registerForTraitChanges([UITraitDisplayScale.self]) でも同じ読み直しをする
//   （値は traitCollection.displayScale。window?.screen.scale は使わない）。値が今と同じなら何もしない（描き直しを頼まない。
//   PaperViewTests の displayRequestCount を変えない。§5.5）。

// Support/ScreenshotMode.swift（役 U）
//   新しい引数 --screenshot-measure（写真モードだけ）。最初の配置の後と、折り目の答えが来た後に 1 行のログ
//   "duo measure: window=<w>x<h> safe=<t,l,b,r> scale=<s> screen=<w>x<h> header=<1|2> paper=<w>x<h> plan=<class>,<orient> cap=<on|off>
//    V=<v> R=<r> maxPages=<n|nil> capped=<bool> wide=<bool> hinge=<closed|partiallyOpen|fullyOpen|unknown|nil|off> origin=<app|carried|moved|person> finger=<bool>"
//   を出す（種類ごと）。hinge= は、測るために usesHinge に依らず、この引数のときだけ別の UIHingeInteraction で読む（FingerDefault にはつながない）。
//   hinge=off は API が無い（iOS 27.1 より前・Mac Catalyst）。利用者のビルドの動きは変えない（引数が無ければ何もしない）。
//   新しい引数 --screenshot-pencil-phone（写真モードだけ）: その起動の最初に「指でも書く」をオフで保存する（Duo の店の写真を、
//   外側の画面でも iPad と同じツールバーで撮るため。§7.3）。シミュレータのデータなので、本物の利用者には届かない。
//   写真モードと UI テストは、起動の引数（-allowFingerDrawingChosen NO・-allowFingerDrawingAuto ""）で初めての起動と同じにする。
```

---

## 3. CI を Xcode 27 へ

### 3.1 実行機と Xcode【事実、FACTS §1・§2、2026-11-20 に読んだ】

| 事実 | 値 | 出典 |
| --- | --- | --- |
| 実行機のラベル | **`xcode-27`**（標準。arm64・3 コア・7 GB）。`xcode-27-xlarge` もある。`macos-26` と `macos-15` に Xcode 27 は入らない（GitHub の方針「1 つの環境は Xcode の 1 つの大きな版」） | [S28][S29][S34][S36] |
| 料金 | `xcode-27` は標準の実行機の表にあり、公開リポジトリでは標準の実行機は無料で回数の上限なし | [S36] |
| 同時に動くジョブ | Free・Pro・Team は macOS のジョブが同時に 5 まで | [S55] |
| 状態 | GitHub は 10/15 に GA と告知。runner-images の README と issue #14404 は今も「preview」の印 | [S28][S33][S34] |
| 一般向けの環境 | 20261104.0337.1（macOS 27.0.1）。Xcode 27.0・**27.1（既定）**・**27.2（27B52、`/Applications/Xcode_27.2.app`、別名 `Xcode_27.2.0.app`）** | [S29] |
| 配り中の環境 | 20261119.0378.1（macOS 27.2、prerelease）。**Xcode 27.3 beta（27C5020n）を `/Applications/Xcode_27.3_beta.app` に置き、`Xcode_27.3.app`・`Xcode_27.3.0.app` という名前の別名も作る**（名前では正式版と見分けられない）。**iOS 27.3 のシミュレータの実行環境は無い**（27.0・27.1（Duo）・27.2・27.2（Duo）だけ）。どのジョブが当たるかは選べない | [S37][S56] |
| 配布の最低版 | Xcode 27.x は iOS 15〜27 → **17.0 のままでよい** | [S2] |
| App Store の受け付け | Xcode 27.2 のビルドは 10/30 から提出に使える。27.3 beta は TestFlight だけ。**27.2（27B52）は公開の直後の約 19 時間、Connect に ITMS-90534 で断られた**（のちに受け付け） | [S14][S57] |
| 実行環境 | iOS 27.0（ふつうの機種）、**iOS 27.1 は iPhone Duo だけ**、iOS 27.2 は「ふつうの機種の組（24B8117）」と「iPhone Duo の組（24B91016s）」の 2 つ。iOS 26.x・17.x は入っていない。GitHub の方針は「Xcode の版ごとに実行環境は 3 つの x.y まで」 | [S28][S29][S41] |
| 機種の名前 | `iPhone 17`・`iPhone 17e`・`iPhone 18 Pro`・`iPhone 18 Pro Max`・`iPhone Air`・`iPad Pro 13-inch (M5)`・`iPad Pro 11-inch (M5)`・`iPad Air 11-inch (M4)`・`iPad Air 13-inch (M4)`・`iPad (A16)`、iPad mini は 27.0 が `iPad mini (A17 Pro)`、27.2 が `iPad mini (A20 Pro)`、**`iPhone Duo`**（20261119 の環境にも同じ物がある）。**`iPhone 17 Pro Max`・`iPhone 17 Pro`・`iPhone 16 Pro Max` は無い** | [S29][S56] |

- **Xcode は 27.2 に決める**（§12 の 0d-1）。選び方: `/Applications/Xcode_27.2*.app` の候補を全部 `xcodebuild -version` で読み、版が `27.2` か `27.2.x` で、**Build の字の最後が数字の物（最後が小文字なら beta）**のうち一番新しい物。**パスの名前では正式版と beta を見分けない**（20261119 の別名の罠）。無ければ**ジョブを落とす**（今の「あれば選ぶ」`build.yml:122-125` は、無いと黙って既定の Xcode で走り、J-4 の約束が崩れる）。選んだ後に `sudo xcodebuild -runFirstLaunch`（何度走らせてもよい。#15342 の直しと同じ考え）。
- 27.3 beta は提出のビルドに使わない。`duo-hinge` のジョブ（§4.2・§4.9）だけが、記録のために使ってよい。
- 新しい Xcode が出た日には替えない（27.2 は公開の直後に Connect で断られた [S57]）。版を上げるのは、別の決めごととして M7D.md に書いてから。

### 3.2 機種の名前（前もって決める。build.yml・ja-baseline.yml・store-shots.yml・duo.yml の同じ並びを同じ字で直す）

| 役目（ID） | 今（macos-26） | 1.4（xcode-27） | 実行環境 |
| --- | --- | --- | --- |
| 単体テスト | 前置 `iPad Pro 13-inch` → … → "iPhone 17"（`build.yml:368-398`） | 同じ（`iPad Pro 13-inch (M5)` に当たる） | 27.2 |
| UI テスト | `iPhone 17`（`:1248-1290`） | 同じ | 27.2 |
| `ipad13` | `iPad Pro 13-inch (M5)` | 同じ | 27.2 |
| `iphone` | `iPhone 17` | 同じ | 27.2 |
| `iphone69` | `iPhone 17 Pro Max`（,`iPhone 17 Pro`,`iPhone 16 Pro Max`）（`:990`・`:1977`、`ja-baseline.yml:559`、`store-shots.yml:171`） | **`iPhone 18 Pro Max`**（前置の並び `iPhone 18 Pro Max,iPhone 17 Pro Max`） | 27.2 |
| `ipadmini` | `iPad mini (A17 Pro)`（前置 `iPad mini`） | **同じ**（27.0 にだけある。本人の mini と 1.3 の写真の数に近いまま比べるため）。**27.3 の正式版が環境に入って 27.0 の実行環境が消えたら**（3 つの x.y まで、の方針 [S28]）、必須の機種の確かめで落ちるので、`iPad mini (A20 Pro)`（27.2）へ移し、J-4 の基準をその日に撮り直す（M7D.md に書く） | 27.0 |
| `ipad11` | `iPad Pro 11-inch (M5)`・`iPad Air 11-inch (M4)` | 同じ | 27.2 |
| `duo`（新しい） | — | **`iPhone Duo`**。iOS 27.2 の Duo の実行環境の機種を **UDID で**指す（`OS=27.2` だけでは 2 つの実行環境を区別できない恐れ [S41]）。27.1 の Duo は使わない | 27.2 |
| compat-v1-0 | iPad 13 の順・"iPhone 17" | **変えない**（macos-26 のまま、§3.9） | 26.x |

- `blank-paper` の名前を直に書いた所（`build.yml:1957` `-destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)"`）は、ほかの段と同じく UDID で指す形にする。
- **必須の機種の確かめ（新しい段、各ジョブの Xcode の選びの直後）**: 上の表の機種（そのジョブが使う物）が `simctl list -j devices available` にあることを確かめ、**無ければ落とす**。前置の並び（例 `iPad mini`）で表と違う機種（`iPad mini (A20 Pro)` など）に当たったときも落とす（選んだ機種の名前と実行環境を env.txt に書き、表と同じ字かを見る）。今は見つからないと `::warning::No simulator for $ID; skipping.` で黙って飛ばす（`store-shots.yml:200`、`build.yml:1022`・`:1796`・`:2009`。6.9 インチが全部飛ばされても緑になる。span-shots-app の `:2221` だけは今も落とす）。
- `iPhone 18 Pro Max` の写真の画素が 6.9 インチの受ける寸法（`accepted()` の `1320x2868 1290x2796 1260x2736`、`build.yml:1147-1155`）に入るかは【未確認】。入らなければ今の形どおり警告だけ（店の 6.9 インチは撮り直さない、§7.4）。寸法を env.txt と M7D.md に書く。
- iOS 27.2 の実行環境で機種を複製すると失敗することがある（188407822 [S5]）。並列テスト（`-parallel-testing-enabled`）は使わない（今も使っていない。`build.yml` に無い）ことを D0 で確かめ、使っていたら `NO` にする。

### 3.3 D0（最初の CI）: Xcode だけを替える

**中身（これだけ）**:
1. `build.yml` の 5 つのジョブ（build-and-test・ui-tests・l10n-shots・blank-paper・span-shots-app）と `testflight.yml`・`ja-baseline.yml`・`store-shots.yml` の `runs-on` を `xcode-27` に。compat-v1-0 は `macos-26` のまま（§3.9）。新しい `duo.yml` に `duo-probe`（§4.2。build.yml には足さない、§3.10）。
2. Xcode の選び（§3.1）、必須の機種の確かめ、機種の並び（§3.2）。
3. env.txt に足す: `xcodebuild -version`、選んだ Xcode のパス、`$ImageOS`・`$ImageVersion`（実行機の環境の版）、`xcrun simctl list runtimes`、`xcodegen --version`、`python3 --version`。
4. **XcodeGen を版と sha256 を決めて入れる**: 今は各ジョブが `HOMEBREW_NO_AUTO_UPDATE=1` で `brew install xcodegen` をする（`build.yml:264`・`:1236`・`:1566`・`:1701`・`:1940`・`:2126`、`ja-baseline.yml:137`、`store-shots.yml:104`、`testflight.yml:129` の 9 か所）。入る版は実行機の環境に焼かれた formula の写しで決まり、環境の版ごとに違う（1.3 の最後の run 44474759145 は全部のジョブが 2.46.0。Homebrew には 11/17 に 2.47.0 が入った [S59][S61]）。2.47.0 で scheme の既定（`buildArchitectures`・`xcodeVersion`）が替わり、作られる project が違う [S51]。そこで:
   - 新しい `tools/ci/install-xcodegen.sh` が、**XcodeGen 2.46.0 の公式の `xcodegen.zip`**（`https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip`、**sha256 `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`**。GitHub の release の digest を 11/20 に読んだ [S58]）を落とし、sha256 を確かめ、作業の場所に解いて PATH に足し、`xcodegen --version` が `2.46.0` でなければ落とす。9 か所の `brew install xcodegen` を全部これに替える（compat-v1-0 の `macos-26` も同じ）。2.46.0 は 1.3 の CI が作った project と同じ生成器なので、D0 で替わるのは Xcode だけになる。
   - 2.46.0 の zip が `xcode-27` の環境で動かない【未確認】ときだけ、2.48.0（`sha256 620c9f0dc10849f94728ab5df52d225ebab8187439dd6fee1925e59e80dff892` [S58]。XcodeGen 自体に macOS 14 が要る）を 9 か所全部で使い、M7D.md に書く（作られる project が 1.3 と違うことも書き、関門 1〜3・7 で見る）。
   - 版を上げるのは、`install-xcodegen.sh` の版と sha256 をわざと書き換える commit だけ。`projectFormat` は書かない（今の形のまま）。
5. `project.yml` の `MARKETING_VERSION "1.4"`（1.3 は公開済みで、1.3 のままでは Connect がビルドを受けない【推定】）。
6. `tools/l10n/ja-baseline-ref-1.4.txt` と `ja-baseline.yml` の基準の替え（§3.5）。
7. `testflight.yml` のアーカイブの確かめ（§3.4）。
8. `tools/span/TESTS_1_3.sha256`・`FIXTURES_1_3.sha256` と、build-and-test の 2 つの段（§5.5。新しい SDK のせいで落ちたテストや fixture を、D0b で書き換えて通すことを最初から防ぐ）。
9. build-and-test の時間の上限を 90 → **110 分**（1.3 の最後の run は 72.2 分で、新しい環境の最初のシミュレータの起動が遅い [S4]）。D0 で測り、余れば D1 で戻す。**D0b（11/20、M7D.md の L5）で 160 分に**（D0 の遅い実行機で 141 分前後の見込み）。ほかの上限も同じ時に: 同期の繰り返しの段 14 分、blank-paper の段 70 分・ジョブ 80 分、span-shots-app の段 80 分・ジョブ 110 分、ja-baseline のジョブ 130 分。

**D0 で変えないもの**: `Sources`・`TegakiKit/Sources`・`Tests` は 955fe67 と 1 バイトも同じ（`git diff 955fe67 -- Sources TegakiKit/Sources Tests` が空。リードが M7D.md に書く）。

**順番（同時に動く macOS のジョブは 5 まで [S55]）**: `build.yml`（6 つのジョブ。5 つが動き 1 つが待つ、1.3 と同じ）→ 終わってから `ja-baseline.yml`（同じ UTC の日に）→ `testflight.yml` → `duo.yml`（duo-probe）。同じ時に別の workflow を足さない。

**D0 の関門（全部そろって D1 へ）**:
1. 全部のジョブが緑: KitChecks 40,020（閾値 39,970）、Kit のテスト 364 本、アプリの単体テスト 745 本・失敗 0、同期の 20 回、UI テスト 43 本、compat-v1.0（macos-26）、l10n-shots、blank-paper、span-shots-app（1.3 の S6 の run 44474759145 の数）。`TESTS_1_3`・`FIXTURES_1_3` の段も緑。
2. **保存のバイトが同じ**: `InkLedgerTests.testLedgerWritesTheCompatShapes`（`ledger-*.json`）・`ScreenshotModeTests.testDemoPagesMatchCompatFixtures`（写真モードの `screenshot-*.json`。`TESTS_1_2_3` の 6 行目）・`SpanSessionTests.testSpanSessionWritesTheCompatSpanShapes`（compat-span）が、作り直さずに今の fixture と 1 バイトも同じ（新しい SDK の Foundation でも JSON のバイトが同じ証拠。K-5、§5.6）。
3. **レイアウトの数**（2 段。span-shots-app のログを 44474759145 と同じ名前の機種・種類ごとに比べる）:
   - (a) `toolbar: paperArea=` の行が同じなら、状態の行（`pages`・`zoom`・`ox`・`oy`・`span cap:`）も同じ数であること。
   - (b) `paperArea=` が違う（安全域や字の大きさなど OS の部品の差）なら、その紙の領域を `swift run KitChecks --span-state <種類> <機種> <向き> <幅>x<高さ>`（役 K、§2）に入れて `zoom`・`pages`・`span cap` を計算し直し、`ox`・`oy` は計算した `zoom` と紙の幅から手で出す（式と数を M7D.md に）。合えば SDK の差として受けて §3.6 の地図に書く。
   - **止めるのは、同じ紙の領域で数が違うときだけ**（Kit の計算そのものは関門 1 の KitChecks が見ている）。
4. J-4（§3.5）: 違ってよい写真は `ipad13-portrait-sheet-info.png` の版の字（「1.3」→「1.4」）の所だけ。**これは同じコードを同じ道具で撮った比べで、写し間違いを捕まえる物。新しい SDK による悪化は関門 7 で見る。**
5. `testflight.yml` を `r14` で走らせ、アーカイブの確かめ（§3.4）が通り、Connect でビルドが **VALID**。
6. `duo-probe` が env と写真を残した（合否には使わない。§4.2）。
7. **SDK の差の地図（§3.6）の規則が全部 ○**: 組 3 の切り抜きで操作部品が全部見える。組 4 に、説明のつかない強い差が無い。
8. 全部のジョブの env.txt の `xcodegen --version` が固定の版。

- SDK の動きの違いで 1〜3・7 が落ちたら、直しは D0 の後の別の commit（D0b）にし、何が落ちてどう直したかを M7D.md に書く。凍結の 20 ファイルに及ぶときは §5.4 の例外の手順。`TESTS_1_3`・`FIXTURES_1_3` のファイルは §5.5 の (a)(b) のときしか替えない。2 と 3 が落ちたとき（保存のバイトや、同じ紙の領域でのレイアウトの数が変わる）は**止めて調べる**（直さずに先へ進まない）。
- **D0 のビルドは配らない**: 内部のグループに足さない。グループが自動で配る設定なら、VALID を確かめた後すぐ期限切れにする（1.3 の試作のビルド 24 と同じ。TestFlight で「閲覧専用」が出る手間を本人に 1 回で済ませるため、本人に入れてもらうのは D3 の候補だけ）。

### 3.4 アーカイブの確かめ（`testflight.yml` の「Check the archive」に足す）

- アーカイブのアプリの `Info.plist` を PlistBuddy で読む（`plutil -extract` は使わない、`testflight.yml` の今の注）:
  - `DTSDKName` が **`iphoneos27.2`**（違えば落とす。「iOS 27.2 SDK で作っていません」）。
  - `MinimumOSVersion` が **`17.0`**（違えば落とす。「配る先が iOS 17.0 ではありません。iOS 17 の人が更新を受けられなくなります」）。
  - `UIDeviceFamily` が `1, 2`。
  - `DTXcode`・`DTXcodeBuild`・`DTPlatformVersion` はログと M7D.md に書く（27B52 の見込み。最後が小文字の Build なら beta なので落とす）。
- 今の確かめ（年齢区分の権限・`DeclaredAgeRange` の弱いリンク、`testflight.yml:250-262`）はそのまま。
- アップロード（`altool`、`:300-`）が通り、Connect で VALID になったことを `asc12/`（リポジトリの外）の読み取りで確かめて M7D.md に書く。ITMS-90725 の予告のメールが来なくなるかは、本人のメールなので見ない（SDK の字で十分）。

### 3.5 J-4 の基準の替え方（日本語の写真の比べ）

- **新しい基準**: `tools/l10n/ja-baseline-ref-1.4.txt` = `955fe678ec9f999ac45fac1b372f246e43c02f95`（1.3 のビルド 26 のコード）。`ja-baseline.yml` はこれを読む。`ja-baseline-ref.txt`（<1.1.1>）と `ja-baseline-ref-1.3.txt`（43fe366）は変えない。
- `ja-baseline.yml` の写真の段を **955fe67 の `build.yml` から写し直す**（955fe67 と 7895d40 の `build.yml` は同じ）。写した後に替えてよいのは、1.4 の `build.yml` と**同じ字で**替える (a) 実行機と Xcode の選び、(b) 機種の並び（§3.2）、(c) 必須の機種の確かめ、(d) env.txt に足す行、(e) XcodeGen を入れる段（§3.3 の 4）、だけ。**D0b（11/20、M7D.md の L4 とその後の直し）で (f)(g)(h) を足した**: (f) 写真の段の手書きの確かめと、手書きが足りないときの起動し直しによる撮り直し（`tools/shots/ink_check.swift`・`ink_ref.tsv`・`ink_retake.sh`。1 枚 2 回まで、段ごとに撮り直しは 180 秒まで、結果は全部 `shots/ink.txt`、撮り直しで足りた写真は `::notice::`）、(g) 横の写真は PNG が縦長のときだけ回す（iOS 27.2 は横で書く）、(h) 写真の段の外の 2 つの段（「Build the handwriting check in the background」と「The app logs' reach」）。どれも 2 つのファイルで**同じ字**。今の `ja-baseline.yml` の頭の注にある 2 つの足し物（11 のシートの `screen_ready.swift` の待ち、`launchctl` の一覧を全部読む）は、955fe67 の `build.yml` に入っているので、写すだけで同じになる。
- 比べ方は今の J-4 のまま（`tools/l10n/compare_shots.swift`、M7B.md C1）。**合否は、同じ UTC の日（日本時間 9:00〜翌 8:59）に撮り、2 つの env.txt の Xcode と実行環境の版の行が同じ組でだけ決める**。違えば基準を撮り直す（配り中の新しい環境 20261119 が途中で当たることがある、§3.8）。
- **J-4 は同じ道具どうしの比べ**なので、新しい SDK による悪化（部品が隠れる・字が切れる）は J-4 では捕まらない。それは §3.6（D0 の関門 7）で見る。
- **1.4 で違ってよい写真（前もって M7D.md に書く）**: `ipad13-portrait-sheet-info.png` の版の字の所だけ（N-3 の文を本人が替えると選んだときは、その文が写る設定の写真を足す。§1.5）。D1 の変更（初めて開くページ・シートの形・倍率・revealRect・注・「指でも書く」の決め方・広い窓の上限）は、今の機種の写真を変えない（写真モードは `shot.page` で開き、シートの形は iPad とふつうの iPhone で今と同じ、倍率は今の機種で同じ値、「指でも書く」は iPad とふつうの iPhone で 1.3 と同じ値（Pencil の触れも折り目も無い）、上限は今の iPhone の窓では 1.3 と同じ（§4.7））。Duo の写真は J-4 に入らない（新しいジョブ、基準に無い）。

### 3.6 新しい SDK・シミュレータだけで変わる写真の読み方（SDK の差の地図。**D0 の関門 7**）

**同じコード（955fe67）を Xcode 26.6 と Xcode 27.2 で撮った写真**を比べ、新しい SDK で何が変わるかを確かめる。地図は M7D.md に残し、本人の確かめ表（§10 の 2）と確認ページで「どこが変わってよいか」を言えるようにする。**下の規則に合わない差があれば D0 で止める**（D0b）。

- 比べる 2 つ:
  - (A) 955fe67 の CI の run **44474759145** の成果物 6 つ（`screenshots`・`ui-tests`・`span-shots-app`・`blank-paper`・`l10n-screenshots`・`span-shots-app-languages`）。期限は `ui-tests` が 2026-11-26T07:13:40Z、`span-shots-app` が 07:37:30Z、`screenshots` が 08:01:58Z（日本時間 11/26 の 16〜17 時。gh api で 11/20 に読んだ [S59]）。**リードが 11/20（S0'）に 6 つ全部を `~/.local/share/tegaki-backup/1.4/` に控える**。間に合わなければ `r13` の `ja-baseline.yml`（Xcode 26.6 のまま）で 955fe67 を撮り直す。
  - (B) D0 の `ja-baseline-955fe67`（Xcode 27.2）と、D0 の build.yml の run の同じ名前の成果物。
- 読み方（写真ごとに 1 つの組に分けて数える）:

| 組 | 例 | 扱い |
| --- | --- | --- |
| 1 状態の帯 | 時刻・iPad の日付・電池 | 雑音（今までどおり） |
| 2 大きさが違う | `iphone69-*`（機種が iPhone 18 Pro Max に替わった） | 比べない。寸法を書く |
| 3 iOS の部品 | シートのガラス・ぼかし・トグル・メニュー・アラート・ナビゲーションの帯・スクロールの帯 | 形の差は SDK の差として受ける。ただし**前もって決めた切り抜き（§3.7 の 10）で、アプリの操作部品が全部見えて押せる形であること**（ボタン・トグル・行が隠れない、ほかの物と重ならない、字が切れない）。リードが切り抜きごとに ○ か × を M7D.md に書く。× なら D0b で直すか決める（§12 の 0d-5）。直さずに先へ進まない |
| 4 アプリが描く物 | 紙・格子・見出し・終日帯・予定・手書きの線・アプリの字 | 同じはず。強い差があれば、(a) §3.3 の関門 2・3（保存のバイトと状態の数）が同じか、(b) PencilKit の線の描き方だけの差（線の形は同じで縁のなめらかさだけ）か、(c) 字の描き方（CoreText）だけの差か、を切り抜きで見て書く。**(a) が同じで、差が (b) か (c) なら受ける。それ以外（(a) が違う、または (b) でも (c) でもない強い差）は止めて調べる** |

- 数（組ごとの写真の数・強い差の画素）と、組 3・4 の写真の名前と判断を M7D.md に書く。
- **確認ページ**（§9.4 の 3）に、組 3・4 で差の強い写真の切り抜きを 3〜5 組（前と後）載せる。確かめ表の行 2 の「少し違うのはかまいません」は、この写真の範囲のことと書く。

### 3.7 前もって M7D.md に書くこと（D0 の最初の run より前）

1. D0 の commit の `Sources`・`TegakiKit/Sources`・`Tests` が 955fe67 と同じこと（§3.3）。
2. J-4 で違ってよい写真（§3.5）: `ipad13-portrait-sheet-info.png` の版の字の所だけ。
3. env.txt で見込む値: Xcode 27.2（27B52）、実行環境 iOS 27.2（24B8117）と、mini だけ iOS 27.0、Duo は iOS 27.2 の Duo の組（24B91016s）、XcodeGen 2.46.0。
4. 機種の替わり（`iphone69` は iPhone 18 Pro Max）と、SDK の差の地図の組（§3.6）。
5. 関門 3 の 2 段の比べ方（`paperArea=` が同じなら数も同じ。違えば `--span-state` で計算し直す）。
6. `duo-probe` で測る物の一覧（§4.2）と、内側を開く道の既定（道 3、§4.2）。
7. KitChecks の今の数 40,020 と、D1 で 2 つの節を足した後の数と閾値（数 − 50）を、足した commit で書く。
8. D1 の J-4 で違ってよい写真は D0 と同じ 1 枚だけ（§3.5。D1 の変更は今の機種の写真を変えない）。D1 の前に、この 1 行をもう一度書く。
9. §4.7 の広い窓の数（短い辺 600）と、§4.2 で測った窓がその数のどちら側にあるべきか（内側 ≥ 600・外側 < 600）。
10. **組 3 の切り抜きの一覧**（J-4 の写真の名前と、その中の部品）: 予定の画面の「保存」「キャンセル」と題名の欄、購入の画面の EULA・プライバシーの行と「あとで」、設定の画面のトグル（「指でも書く」「横につなげる」）と閉じるボタン、ツールバーの左端と右端（ペン・消しゴム・投げなわ・↶↷・「指でも書く」）、見出しのボタン（◀ ▶「今日」・⚙・ページの種類）、写真にあればアラートのボタン。写真の名前は D0 の前に 44474759145 の成果物から選んで書く。
11. `TESTS_1_3`・`FIXTURES_1_3` の行の数と、955fe67 の blob から作ったこと（§5.5）。

### 3.8 Xcode 27 系の既知の不具合への構え【事実、FACTS §1.3・§2.4】

| 不具合 | 構え |
| --- | --- |
| 最初のシミュレータの起動に数分（27.1）[S4] | `-runFirstLaunch` と、写真の前の 120 秒の待ち（今の FIX3 と同じ）。build-and-test の上限を D0 だけ 110 分（§3.3 の 9）。測った分を M7D.md に書く |
| Duo の写真と録画が起動から数分は黒い（27.2、187146039）[S5] | Duo の写真の前に 180 秒待つ。撮った写真の明るさの平均が閾値より低ければ（ほぼ黒）、30 秒おいて 3 回まで撮り直す。それでも黒ければ落とす（§7.3） |
| 27.2 の実行環境の複製の失敗（188407822）[S5] | 並列テストを使わない（§3.2） |
| Mac Catalyst で iOS 27.1 の API がコンパイルエラー（27.2、185924957）[S5] | `UIHingeInteraction` を使う所を `#if !targetEnvironment(macCatalyst)` で囲む（`tools/typecheck/typecheck.sh` は Mac Catalyst）。iOS のビルドは CI で通る |
| 実行環境が起動中に外れて UI テストが落ちる（20261112 の環境、#15334・#15337、直しの PR #15342）[S38] | 落ちたジョブを 1 回だけ走らせ直し（1.3 の FLAKE-1・FLAKE-2 と同じ扱い）、M7D.md に run と環境の版を書く。2 回続けば、その日は止めて環境の版を見る |
| 配り中の環境 20261119（macOS 27.2・Xcode 27.3 beta）が途中で当たる [S37][S56] | env.txt の `$ImageVersion` で見分ける。J-4 は同じ環境の版の組でだけ合否（§3.5）。Xcode は Build の字で選ぶ（§3.1） |
| 27.3 の正式版が入ると 27.0 の実行環境が消えうる（3 つの x.y まで）[S28] | `ipadmini` を A20 Pro（27.2）へ移し、J-4 の基準を撮り直す（§3.2） |
| 新しい Xcode が公開の直後に Connect で断られる（27.2 で約 19 時間、ITMS-90534）[S57] | 出た日に替えない（§3.1） |
| Python 3.15 が環境の python3 [S29]（CODE_SURVEY §1.6） | D0 で `lint.py`・`build.py`・`baseline.py` と機種選びの `python3 -I -c` が通ることを見る。落ちれば `actions/setup-python` で 3.12 に固定（版を書く） |

### 3.9 compat-v1-0 は macos-26（Xcode 26.6）のまま

- compat-v1-0 は、1.0（a21e469）・1.2.3（43fe366）・**1.3（955fe67、§5.3）** のアプリ全体を、その実行機の Xcode でビルドしてテストする（`build.yml:1571-1650`）。古い木のコードは直せない（直すと本物でなくなる）。
- **既定: このジョブだけ `macos-26` と Xcode 26.6 に残す**（§12 の 0d-2）。理由: (1) 互換の確かめは「古い版の本物のコードが、今のデータを読む」こと。古い版は Xcode 26.x で作って配ったので、同じ道具で作る方が本物に近い。(2) Swift 6.4 で古い木がエラーになる恐れを避ける【未確認】。(3) このジョブは提出のビルドを作らない（Apple の 4 月の決まりに当たらない）。
- **このジョブは今の木の TegakiKit も Xcode 26.6（Swift 6.3）でビルドして走らせる**（`build.yml:1439` `swift run --package-path TegakiKit KitChecks --write-compat-fixtures`）。だから **1.4 の Kit の新しいコード（`WindowClass`・`FingerDefault`・`DuoChecks`・`WindowFingerChecks`）は Swift 6.3 でも通ること**。iOS 27・Swift 6.4 だけの API を Kit に入れない。compat-v1-0 が落ちたら、まずここを見る。
- `macos-26` に Xcode 26.6 が無くなったら（環境の更新で）、今の「あれば選ぶ」ではなく落として気づく形にし、そのときに `xcode-27` へ移すかを決める（古い木が Xcode 27 で作れなければ、その版の相手は Kit の Probe だけにし、M7D.md に書く）。

### 3.10 CI の変更の一覧と、回し方

| 場所 | 変更 | 段 |
| --- | --- | --- |
| build-and-test | 実行機・Xcode 27.2・必須の機種・env・XcodeGen の固定・`TESTS_1_3`・`FIXTURES_1_3`・上限 110 分（D0）。D1 から: KitChecks の閾値（2 つの節の分）、`idiom_check.py`（§4.1）、`DUO_HINGE` が `project.yml` に無いことの検査（`AGE_FORCE` の検査 `build.yml:226-230` と同じ形）、新しい単体テスト。上限は測って戻す | D0・D1 |
| ui-tests | 実行機・Xcode・XcodeGen。`DuoLayoutUITests` は Duo でないと飛ぶ（§6）ので、数の確かめ（43 本）は飛んだ物を除いて数える | D0・D1 |
| l10n-shots・blank-paper・span-shots-app | 実行機・Xcode・XcodeGen・機種の並び（§3.2） | D0 |
| compat-v1-0 | **macos-26 のまま**。XcodeGen の固定。D1 で v13（§5.3）。上限 45 → 65 分（測って戻す） | D0・D1 |
| **duo.yml（新しい workflow）** | `workflow_dispatch`（入力 `job`: `probe`・`shots`・`hinge`）と、枝 `r14-duo*` への push だけで走る。**`r14` への push では走らない**（build.yml の 6 つと合わせて同時の上限 5 を超えないため [S55]） | D0・D1 |
| duo-probe（duo.yml、D0） | §4.2。合否に使わない | D0 |
| duo-shots（duo.yml、D1。duo-probe を置き換える） | §4.2・§7.3。`DuoLayoutUITests`（Duo で走った数 ≥ 道ごとに前もって書いた数・失敗 0）と写真と `shot_checks.py` | D1 |
| duo-hinge（duo.yml、入力 `hinge` のときだけ） | 環境の Xcode のうち、`xcodebuild -version` が 27.3 系の物を Build の字で見分ける。**正式版（最後が数字）で、その Xcode が Duo の実行環境で `XCUIHinge` を使えるときだけ**合否に使う。beta しか無いときは走らせてもよいが**記録だけ**（写真も店に使わない）。`SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DUO_HINGE` で UI テストを作り `DuoHingeUITests` | D1 |
| testflight.yml | 実行機・Xcode・XcodeGen・アーカイブの確かめ（§3.4） | D0 |
| ja-baseline.yml | 実行機・Xcode・基準 955fe67・写真の段の写し直し（§3.5） | D0 |
| store-shots.yml | 実行機・Xcode・XcodeGen・機種。D2 で Duo の組（§7）。入力 `sets`（既定 `duo`。`ipad13,iphone69` も選べる）。今の写真は撮り直さない | D0・D2 |

**回し方（同時の上限 5 と、1 回 1 時間半を前提に）**:
- 速い確かめの道（`r13-quick`・`r13-q-*`、`build.yml` の `QUICK`）は `r14-quick`・`r14-q-*` にも効くように直す（1.3 の名前は残す）。D1 の間はここで回し、関門の前だけ `r14` で全部を回す。
- **Kit と純粋な関数の変異は CI で回さない**: `WindowClass`・`FingerDefault`・`SpanPlan` の変異は、この Mac で作業の木の写しに変異を入れて `swift run --package-path TegakiKit KitChecks` を走らせ、落ちることを見て戻す（M7D.md に変異の名前と落ちた行を書く）。v13 の Probe（§5.3）も手元の `swift build` で先に通す。
- **アプリと UI の変異はまとめる**: 別々のテストに当たる変異を 1 本の枝（`r14-q-m1`、UI は `r14-duo-m1`）に全部入れ、1 回の run でどのテストが落ちたかで見分ける（§6）。見込みは 2〜3 回。
- 1 日の流れ: build.yml（約 1.5 時間）の間は、ほかの workflow を足さない。duo.yml・ja-baseline・store-shots・testflight は build.yml の後に 1 つずつ。

---

## 4. iPhone Duo

### 4.1 方針と、端末の種類で決めている 11 か所

方針:
- **見た目（レイアウト）は端末の種類ではなく窓の大きさで決める**（M4B D6。Apple の Duo の案内 [S15][S43]: `UIScreen.main` で寸法や倍率を取らない・端末の向きで決めない・idiom やサイズクラスで端末を見分けない。「iPhone Duo と大きさを変えられる iPhone ミラーリングでは、iPhone のアプリがどの組み合わせのサイズクラスにもなる」）。
- **入力（Pencil と指）は、窓の大きさで決めない**（ミラーリングで、ふつうの iPhone の窓も広くなる [S15]）。**Pencil の触れ（P）と、画面の折り目（H）という、端末そのものの物で決める**（本人の決定、§4.8）。
- **画面の文を変えずに済み、今の機種（iPad・ふつうの iPhone の画面）の動きが 1 つも変わらない形**を選ぶ（L-3、1.4 には機能を混ぜない）。Duo は idiom が `.phone`（内側も外側も）。

| # | 所（7895d40） | 今 | 1.4 | 理由 |
| --- | --- | --- | --- | --- |
| 1 | `CalendarRootScreen.swift:432-433`（`fallbackKind`、`init` の中） | iPhone は週から | **窓の短い辺で**（`WindowClass.Opening`、§4.3） | 内側は iPad mini と同じほどの広さ。幅で見るとふつうの iPhone の横（874 pt）も月になるので、短い辺で見る |
| 2 | `:1253-1257`（`allowFinger` の既定） | iPad 以外はオン | **既定の書き込みはそのまま。Pencil の触れ（P）か折り目（H）でオフへ**（`FingerDefault`、§4.8） | 本人の決定（Duo は iPad と同じ）。ふつうの iPhone は 1.3 のまま |
| 3 | `:1049`・`:2745`・`:1769-1771`（`usesMinTapTarget(isPhone:width:)`） | iPhone はどの幅でも年の的 44 pt | **変えない** | Duo の既定（「指でも書く」オフ）では、`DateTap.minTarget` は小さな画面かどうかに依らず月・年とも 44 pt（`TegakiKit/Sources/Layout/DateTap.swift:9-12・:27`）で、iPad と同じ的になる。オンにした Duo だけ iPhone の的（年 44 pt）のまま。内側の年のマスは約 37 × 20 pt【推定】で 44 pt より小さく、大きな的の方が安全。凍結のテスト `CalendarRootScreenTests.swift:116-128` も変えずに済む |
| 4 | `:1503` → `Span/ScreenPaths.swift:265-269` → `SpanPlan.swift:19-32` | Duo は `.iPhone` | **機種は変えない**（§4.6）。広い窓の plan は上限なし（§4.7） | 測った紙の領域で窓が広がる。KitChecks の数を変えない |
| 5 | `Views/PaywallSheet.swift:196-206` | `.phone` なら `.large` | **`WindowClass.usesFormSheet`**（§4.4） | 内側は広い |
| 6 | `Views/EventEditorSheet.swift:135-141` | 同じ | 同じ | 同じ |
| 7 | `EventEditorSheet.swift:119`・`:268-272`（Scribble の注） | iPad だけ | 変えない | 能力の話。iPhone の Scribble は【未確認】。文に触れない |
| 8 | `Views/SettingsScreen.swift:111-115`・`:208`・`:456`（消しゴムの脚注） | iPad で Pencil の文 | 変えない（Duo は iPhone の文「指を離すと…」） | iPad の文（`.pad`）は「ダブルタップやスクイーズ」を言うが、Duo の Apple Pencil（USB-C）には無い【事実 [S54]】。iPhone の文は足りないが誤りではない。文を変えると 9 言語の訳。凍結でないテスト `SettingsScreenTests.swift:136-148` も変えない |
| 9 | `SettingsScreen.swift:458-468`（Apple Pencil の行） | iPad だけ | 変えない | 行はダブルタップ／スクイーズの動作の話で、Duo の Pencil（USB-C）には無い【事実 [S54]】。脚注も「iPad の『設定 › Apple Pencil』」 |
| 10 | `Ink/InkSnapshot.swift:24`（**凍結**） | 既定の引数 `UIScreen.main.scale` | 呼ぶ側 `CalendarRootScreen.swift:1935`・`:2989` で `scale:` を渡す（§4.5） | 凍結を崩さない |
| 11 | `Paper/PaperView.swift:228-233` | `didMoveToWindow` だけで `window?.screen.scale` | 特性の変化でも読み直す（§4.5） | 開閉で画面が替わる |

- **見張り `tools/duo/idiom_check.py`（役 C、build-and-test の段）**: `Sources/TegakiCalendar` の Swift のうち凍結の 20 ファイル（`lint-skip.txt`）を除く物で、`userInterfaceIdiom`・`UIScreen.main`・`UIDevice.current.orientation`・`interfaceOrientation` と、機種の名前を読む物（`utsname`・`hw.machine`・`UIDevice.current.model`・`"iPhone1`〜`"iPhone9` で始まる字。凍結の `InkTrace.swift` の記録は読まない）の出る所を数え、`tools/duo/idiom-allow.txt`（1 行に「パス|その行の中の字|理由」）に無い物があれば落とす。1.4 の後の allow の行は上の表の 2（`isPad`、iPad の既定と `FingerDefault(isPad:)`・`PencilPhone.attach` に渡す所）・3（呼ぶ所の `isPhone:`）・4（`isPad:`）・5・6（`isPad:` に渡す所）・7・8・9 と、写真モードの回転（`CalendarRootScreen.swift:1408-1415`、`Support/ScreenshotMode.swift`）、`AgeRangeAsker.swift:92`、`InkCanvasView.swift:625`（凍結なので読まない）など、D1 の最初に全部を数えて書く。**`UIScreen.main` と機種の名前は allow に入れない**（1.4 の後は凍結の外に 0 件）。`identifierForVendor` は端末の種類でないので数えない。

### 4.2 Duo を測る（duo.yml の duo-probe → duo-shots）

Apple は Duo の pt の寸法を出していない（FACTS §4.2）。第三者の推定（内側 669 × 951 か 626 × 890、外側 466 × 678）と、フォーラムの利用者の報告（シミュレータは外側だけで起動し、窓は 382 × 644 pt。`simctl io` で 2 つ目の画面 2007 × 2853 px も見えた）は、どれも【未確認】。**推定で作らず、CI で測ってから決める**。

- **D0 の `duo-probe`**（コードは変えない）: Xcode 27.2 で、iOS 27.2 の Duo の機種を UDID で起動 → 180 秒待つ → `xcrun simctl io <udid> enumerate`（画面の一覧）・`simctl list -j devicetypes`（Duo の機種の識別子）・`simctl help` に姿勢（posture・hinge・fold）の口があるか → 写真モードで週を開き `simctl io <udid> screenshot`（既定の画面と、`--display` で選べる画面の全部）→ 写真の画素と、今の写真モードのログの行（`span cap:`・状態の行・`toolbar: paperArea=`）を `duo-probe/env.txt` へ。環境の Xcode の一覧と、それぞれの `xcodebuild -version`（Build の字）も書く。D0 はコマンドだけで、テストのファイルは足さない。
- **D1 の `duo-shots`**: 写真モードの新しい引数 `--screenshot-measure`（§2.1）で、外側（と、開けるなら内側）の縦と横、週・日・月・年の「duo measure:」の行を取り、写真（§7.3）を撮る。同じ引数で `iPhone 17` の行も 1 つ取る。**測った値を M7D.md の表に書き、KitChecks の節「duo (1.4)」（§4.6・§4.7）に写す**。前もって決めた見込み:
  - `wide=` は外側で false、内側で true（§4.7 の見た目の W）。違えば止めて、§4.7 の数の決め方に従う。
  - `hinge=` は `iPhone 17` で `nil`（折り目の無い階層では hinge が nil [S52]）。**Duo のどれかの画面で `nil` でなければ `PencilPhone.usesHinge = true`**（H を使う）。Duo のどの画面でも `nil` なら `usesHinge = false`（H を使わず、P だけの道。§4.8）。どちらにしたかと、外側の値を M7D.md に書く（`hinge=` は `--screenshot-measure` のときだけ、`usesHinge` に依らず読む測りの値（§2.1）なので、`usesHinge` を決める前の D1 の最初の duo-shots で読める）。
- **シミュレータで Pencil の触れを作れるか**【未確認】（XCUITest に Pencil の触れを作る口は見つけていない）。D0 の `duo-probe` で、Simulator の「Apple Pencil の入力」が Duo の機種で選べるかを `simctl help`・`defaults read com.apple.iphonesimulator` で見て書く（使えても合否には使わない）。P の信号の確かめは、Kit の状態の型の表（§6、手元でも走る）と、凍結の `InkTouchObserver` に作り物の UITouch を渡す単体テスト（§6）と、本人の Duo（§10 の 19〜21）に頼る。
- **内側を開く道（前もって決める）。11/23 までの既定は道 3**:
  1. 27.2 のコマンド（`simctl` の姿勢の口、`simctl io` の画面の選び）で内側を開いて撮れる → それを使う。
  2. 1 がだめで、環境に **27.3 の正式版**（Build の字で見分ける、§3.1）があり、Duo の実行環境で `XCUIHinge` [S6] で開ける → `duo-hinge` のジョブで、開いてから `simctl io` で撮る（写真と内側の測りだけ。提出のビルドは 27.2 のまま）。20261119 の環境の 27.3 は beta で、iOS 27.3 の実行環境も無い [S56]。27.2 の Duo の実行環境で `XCUIHinge` が動くかは【未確認】。**beta で開けても記録だけ**（店の写真・新機能の文・シートの決めには使わない）。
  3. どちらもだめ（**既定**）→ 内側は測れない。内側の窓は推定のまま KitChecks に入れず（§4.7 の上限の規則は窓の短い辺で決まるので、推定の値でも今の機種の答えは変わらない）、`WindowClass.formSheetOnWide = false`（§4.4）、新機能の文は案 B（§8.1）、店の写真は外側だけ（§7.1）。内側の見え方は、本人の Duo の確かめ表（§10 の 18・22・26）で見る。
- **duo-shots の宣言の数（`DuoLayoutUITests` が Duo で走るべき数）は道ごとに前もって書く**: 道 3 は外側だけのテスト（`testOuterHeaderRows`・`testJoinedWeekSwipesOnDuo`・`testSheetsFitOnDuo` の外側・`testFingerDefaultFollowsTheHinge` の外側）の数。道 1・2 は内側のテストも足した数。内側だけのテストは、道 3 では宣言から外す（飛んだ物は数えない）。

### 4.3 初めて開くページを窓の短い辺で

- 対象は**その端末で初めて開くとき（覚えたページの種類 `AppSettings.lastKindKey` が無いとき）だけ**。今の利用者は覚えたページで開くので、1.4 にしても変わらない。写真モードは `shot.page` で開く（変わらない）。
- 決め方: `WindowClass.Opening`（§2.1）。iPad は月（今のまま）。それ以外は、**窓の大きさ（`windowSize`。`opening()` が使うのと同じ値、`noteWindowSize` `CalendarRootScreen.swift:2863-2872` が書く）が測れたときに 1 回だけ**: 広い窓（短い辺が 600 pt 以上、`WindowClass.isWide`）なら月、そうでなければ週。窓の大きさが `appear()` より先に来ても後に来ても同じ答え（決める型が `appear` に頼らない。C2）。Duo の内側は縦でも横でも月、外側は縦でも横でも週。ふつうの iPhone は横で初めて開いても週（1.3 と同じ。幅で見ると横の 874 pt が月になってしまう）。
- 決まるまで（`init` から窓の大きさが来るまで）は、紙のキャンバスを作らない（紙の色だけ）。週のキャンバスを作ってから月に替えると、組み立てが 2 回走り、一瞬ちらつく。
- 決めた後は今と同じく覚える。**開閉で後から幅が変わっても、ページの種類は替えない**（書いている紙が勝手に替わらないため）。
- ミラーリングで広げた窓で初めて開いたふつうの iPhone も月になる（見た目だけ。Apple の勧めどおり窓で決める）。
- 理由: `init` の中では窓の幅がまだ無い（CODE_SURVEY §1.2 の 1）。`UIScreen.main` で幅を取るのは Apple が止めてと言う書き方。

### 4.4 シートの形

- `WindowClass.usesFormSheet(isPad:windowSize:)` = **iPad か、(`formSheetOnWide` かつ広い窓)**。ふつうの iPhone は縦でも横でも短い辺が 440 pt 以下なので false（1.3 と同じ `.large`）。iPad は true（1.3 と同じ）。
- `formSheetOnWide` は D1 に決める定数で、**既定は false**（Duo の内側も `.large`、1.3 と同じ）。
- `PaywallSheet`・`EventEditorSheet` に `windowSize` を渡すのは `CalendarRootScreen`（シートを出す所）。`nil` なら今の分かれ道（§2.1）。
- **確かめ（前もって決める）**: 内側を撮れる道（§4.2 の 1）のときだけ、`duo-shots` で内側と外側でこの 2 つのシートを撮る（写真モードのシートの引数。購入の画面の写真は店には出さない）。内側で (a) 購入の画面の EULA の行と「あとで」がスクロールせずに見える、(b) 予定の画面の「保存」と「キャンセル」が見える、の両方が○なら `formSheetOnWide = true` にする。どちらかが×、または内側を撮れない（道 3、既定）なら false のまま（確かめていない見え方を出さない）。どちらにしたかを M7D.md に書く。

### 4.5 倍率は窓から

- `InkSnapshot.render` を呼ぶ 2 か所（`CalendarRootScreen.swift:1935` 1 ページの道の「予定にする」、`:2989` 横の道）に `scale: displayScale` を渡す（`@Environment(\.displayScale)`）。`InkSnapshot.image` の呼び出しは、もう倍率を渡している（`InkCanvasView.swift:2267-2268`、`Export/PDFPageRenderer.swift:254`・`:259`）。凍結の `InkSnapshot.swift` は変えない。
- `PaperView` は `didMoveToWindow` に加えて、`registerForTraitChanges([UITraitDisplayScale.self])` で `traitCollection.displayScale` を読み直す。**値が今と同じなら何もしない**（窓に入るときにも特性の変化が来るので、描き直しを 2 回頼まないため。`PaperViewTests.swift:74-109` の `displayRequestCount` を変えない。§5.5）。
- Duo の内側（430 ppi）と外側（460 ppi）の倍率が違うかは【未確認】（店の写真の寸法から、どちらも 3 倍の見込み【推定】）。違わなくても、Apple の求める書き方に直す（§4.1 の見張りで `UIScreen.main` を 0 件に保つ）。

### 4.6 span plan の機種（内側と外側）

- **Duo は内側も外側も `.iPhone`**（`SpanDeviceClass(screen:isPad:)`、`isPad` が false なら必ず `.iPhone`）。向きは場面の画面の形、窓の大きさは iPhone の行（402 pt）の R と、**測った紙の領域**の R の大きい方（`SpanSession.windowRadius`、`SpanSession.swift:416-420`）。窓の線の上限は iPhone の 12,000 本（`SpanPlan.swift:131`・`:134-136`）で、超える見積もりなら行の R に戻る（`:422-429`）。
- 推定の計算（CODE_SURVEY §3.2、`duo_span_calc.py`）では、窓は 5〜9 ページで今の iPhone・iPad の範囲の中。内側の横（広い窓、上限なし）は、上限の無い iPhone の横の行（1.3 の P-B6 ア の数。週 9・日 15 ページの窓）と測った紙の領域で決まる。新しい機種の行（`SpanDeviceClass` の新しい case）は作らない（作ると KitChecks の窓の表と門の数が変わり、1.3 の確かめ直しが増える。得る物が無い）。
- **KitChecks の新しい節「duo (1.4)」（`DuoChecks.swift`、役 K）**: §4.2 で測った紙の領域（外側の縦・横、測れたら内側の縦・横 × 週・日。測れない所は推定の値で、そう注に書く）ごとに、`SpanDeviceClass(screen:, isPad: false) == .iPhone`、`overviewCap` は `WindowClass.capsOverview(その画面の窓)` の答え（外側 true・内側 false）で作った plan の `visiblePages(viewport:)`（手で出した V、±0.006）、`SpanPlan.radius(forVisiblePages:)`、`maxVisiblePages(viewport:)`、`zoomBounds` の最小、一番縮めたときに見える時間（手で出した字）。内側の横は**終日帯が 35 % の上限のときの紙の領域**の行も足す（帯の高さで答えが替わらないことの確かめ。§4.7）。期待は手で出した字で書く（1.3 の PLAN_PB6 §2.3 と同じ）。1.3 の推定の行（`SpanChecks.swift:380-383`「1.4 checks it again」）は 1.3 の確かめとして残し（`TESTS_1_3` に入る）、`DuoChecks.swift` の頭の注に「1.3 の推定の行は SpanChecks に残す。測った値はここ」と書く。
- **`--span-state`（役 K、同じファイル）**: `swift run KitChecks --span-state <種類> <機種> <向き> <幅>x<高さ> [cap|nocap]` で、その紙の領域の `zoomBounds`・`visiblePages`・`maxVisiblePages`・R を出す（§3.3 の関門 3 の (b) で使う。KitChecks の数には入らない）。
- 数と閾値: 2 つの節（「duo (1.4)」と「window & finger (1.4)」）で足した数を M7D.md と `build.yml` の注に書き、閾値を「新しい数 − 50」に（N − 50 の規則）。

### 4.7 一覧の上限（P-B6 イ）を Duo でどう当てるか

- 今の規則: 機種が `.iPhone` で、**紙の領域が横長**のとき、週・年 3 ページ・日 5 ページの上限（`SpanPlan.swift:76-83`・`:91-94`）。上限の倍率が今の最小より上のときだけ効く（`ZoomPolicy.cappedBounds`、`ZoomPolicy.swift:158-167`）。効いた一覧（`ScreenPaths.atCappedOverview`）では、今日のページは今の 1 時間前から開き、「今日」は上下だけ動く。上限は窓の plan の `overviewCap` が true のときだけ（1.3 は `ScreenPaths.makeSession` が true 固定、`ScreenPaths.swift:420`）。
- 推定（CODE_SURVEY §3.2）: 外側の横では、はっきり効く（今の iPhone 横に近い）。内側の縦では効かない。**内側の横は、紙の領域で決めると境目になる**: 日で紙の高さが 446 pt なら効き、472 pt なら効かない。しかも紙の高さは終日帯のレーンの数で変わる（帯は紙と帯の領域の 35 % まで高くなる、`AllDayBand.swift:278`）。紙の領域で線を引くと、同じ端末で週ごとに「今日のページが今の 1 時間前から開く／0:00 から開く」が替わる（C12）。
- **1.4 の規則（既定）: 広い窓（窓の短い辺が 600 pt 以上、`WindowClass.isWide`）の横の道の窓には、上限をかけない**。
  - `ScreenPaths.makeSession` が `overviewCap: WindowClass.capsOverview(windowSize)` を渡す（広い窓なら false）。窓を決め直すとき（開閉・回転）は、`SpanSession.redecide` が口 `overviewCapNow` で今の窓を読み直して次の plan を作る（§2.1）。**`SpanPlan` の規則と数は 1 字も変えない**（`overviewCap: false` は 1.3 の P-B6 ア の数そのもので、KitChecks がもう確かめている）。
  - **窓の短い辺は終日帯のレーンで変わらない**ので、内側の横はいつも上限なし、外側の横はいつも上限あり（境目の揺れが無い）。
  - `ScreenPaths.atCappedOverview`（`:1022-1027`）と `shotPaperOffset`（`:1186-1188`）は `layout.plan.overviewCap` を見るので、**変えずに**広い窓では false になり、今日のページは 0:00 から開く（C1。今日を開く高さを決める `CalendarRootScreen.swift:2776` の道も同じ plan を読む）。
  - **今の機種では答えが 1 つも変わらない**: ふつうの iPhone の窓は縦横とも短い辺が 440 pt 以下なので `overviewCap` は 1.3 と同じ true。iPad は plan の機種が `.iPhone` でないので元から上限なし。Mac のミラーリングで広げた窓は上限なし（見た目だけ。Apple の勧めどおり窓で決める）。
  - **Duo**: 外側の横（推定 554〜678 × 243〜269 の紙）は上限あり（今の iPhone 横と同じ。週 3・日 5、今日は 1 時間前から）。内側の横（推定 890〜951 × 403〜472 の紙）は上限なし（iPad と同じ。0:00 から開き、一番縮めると 24 時間がほぼ入る）。内側の縦は紙が縦長なので元から上限なし。
  - **開閉の時**: 凍結のキャンバスは、幅が変わったその配置では今の plan で倍率の範囲を当て（`InkCanvasView.swift:3035-3038`）、窓の決め直し（`redecideWindow` `:3289-3296`）は紙に触れていない・止まった後にする（`isAtRest` `:3223-3225`）。だから上限の付け外しは、その決め直しの時に替わる。開いた直後の一瞬は前の plan の上限のまま（倍率が 2 回変わることがある）【推定: DuoFoldTests の (g) で見る】。
  - 理由: 本人の決定「幅が許す所は iPad と同じ」。上限は 874 × 205 の小さな横の紙のために決めた物（P-B6 イ）。紙でなく窓で決めると、帯のレーンで揺れない（C12）。
  - **数の決め方**: 600 は §4.3・§4.4 と同じ短い辺の数（1 か所 `WindowClass.wideShortSide`）。§4.2 で**測った内側の短い辺が 600 未満、または外側の短い辺が 600 以上なら止めて**、外側と内側の間で、441 以上（今の iPhone の短い辺は全部 440 以下）の数に決め直す（リードの決定として M7D.md に。見出しの 1 段の `compactWidth` は変えない。そのときは `testWideShortSideIsTheCompactWidth` を「wideShortSide ≤ compactWidth」に替える）。内側を測れないときは推定のまま入れる（今の機種の答えは変わらないので害が無い）。
  - **1.3 の確かめは書き換えない**: `OverviewCapChecks` の期待・`ScreenPathsSpanTests`（`TESTS_1_3` に入る）は 1 字も変えない。
- 倍率の比の鍵（`AppSettings.swift:107-113`）は今のまま（§1.5）。

### 4.8 Apple Pencil（Duo。本人の決定 2026-11-20）

**事実**: iPhone Duo は **iOS 27.2 で Apple Pencil（USB-C）に対応**（Apple の記事、2026-11-05 公開。Pro・第 2 世代・第 1 世代の表に Duo は無い）[S19]。Duo の発売時の OS は iOS 27.1 [S9][S10]。Apple Pencil（USB-C）は筆圧・ダブルタップ・スクイーズ・バレルロールに対応しない。**Duo と使うときはホバーも使えない** [S54]。iOS 27.2 は 10/26 に公開済み [S7]。どちらの画面（内側・外側）で使えるかは書いていない【未確認】。iPhone で Apple Pencil が使えるのは Duo だけ [S19]。

**約束（Duo では iPad と同じ）**:
1. **Pencil が書き、指が紙を動かす**: 「指でも書く」がオフなら、`drawingPolicy = .pencilOnly`（`InkCanvasView.swift:678`・`:924`）で Pencil だけが書き、指 1 本で紙が動く（横の道は 1 本指で横。`SpanGuide` の札 N-4・N-6）。これは今の iPad の動きそのもので、凍結のファイルは変えない。
2. **「指でも書く」は Duo ではオフになる**。下の「見分け方」と「決め方の表」で決める。
3. **手のひらの規則は iPad と同じ**: (a) 「指でも書く」がオフなので、手のひらの触れは線にならない（PencilKit の `.pencilOnly`。`InkCanvasView.writes(_:)` `:1906-1908` も指を書く物と数えない）。(b) Pencil が触れている間と離して 0.5 秒は横に動かさない（`InkCanvasView.palmHold`・`panMayBegin` `:2412-2439`。触れの種類と時刻だけで決め、端末の種類を読まない【コード】）。手を加える所は無い。ホバーが無いので、Pencil の先が着く前に置いた手のひらで紙が動くことはありうる（iPad でも Pencil が着く前は同じ規則）【未確認: Duo の手のひらの見分けは実機で見る、§10 の 20】。
4. **ツールバーは今のまま**: ツールバー（`ToolbarView`）はどの端末でも同じ部品で、「指でも書く」のボタンもある（`:310-318`）。見出しは幅 600 pt 以上で 1 段（`CalendarRootScreen.swift:810`）。内側は 1 段で iPad と同じ、外側の縦は 2 段（幅が許さない）。
5. **初めての案内は今のまま**: 初めての案内の 3 枚目（`onboarding.pen.text`、どの端末でも同じ文）は「Apple Pencil で紙に書きます。指はスクロール…手のひらが触れても線は引かれません。指でも書きたいときは、ツールバーの『指でも書く』をオンに…」で、iPad の動きの説明そのもの。横の道の札（`SpanGuide.text`）は「指でも書く」に従うので、オフなら 1 本指の札（N-4・N-6）。**新しい文は無い**。
6. **設定の画面は今のまま**（§4.1 の 8・9）。

**Duo の見分け方（機種の名前も窓の大きさも読まない）**: 次の 2 つの、端末そのものの物で知る。
- **P（Pencil の触れ）**: iPad 以外で、触れの種類が `UITouch.TouchType.pencil`。Pencil が使える iPhone は Duo だけ [S19]。見るのは**凍結の `InkTouchObserver` の新しいインスタンス**（凍結の表の 6 行目。ファイルは変えず、使うだけ）を UIWindow に付けた物。1.3 からキャンバスの入れ物で使っている形そのもの（Pencil・指・ポインタを受け、何も認識しない。`.possible` のまま、最後の触れが離れたら `.failed`。`reset()` で残りを離れたと知らせる。`cancelsTouchesInView`・`delaysTouchesBegan`・`delaysTouchesEnded`・`requiresExclusiveTouchType` は false、`InkTouchObserver.swift` の頭の注）。窓のどこ（紙・ツールバー・シート）に Pencil が触れても P。
- **H（画面の折り目）**: `UIHingeInteraction`（iOS 27.1 から [S52]）を窓のルートの view に付け、update の `hinge` が nil でなければ H。ハンドラは「最初の状態」で 1 回呼ばれ、その後は変わるたびと階層が移るたびに呼ばれる [S53]。折り目の無い階層では `hinge` が nil [S52]。Duo は発売時から iOS 27.1 以上 [S9][S10]。**レイアウトには使わない**（Apple の注意 [S52]。使うのは「指でも書く」の決め方だけ）。`#if !targetEnvironment(macCatalyst)` で囲む（Xcode 27.2 の既知の不具合 185924957 [S5]）。**`PencilPhone.usesHinge` が true のときだけ使う**（§4.2 で、Duo のシミュレータのどれかの画面で nil でなく、`iPhone 17` で nil と測れたとき。測れなければ false で、H は来ない）。外側の画面で nil でないかは【未確認】（§4.2 で測る）。
- **使わない物**: W（窓の広さ）。Mac の iPhone ミラーリングでは、ふつうの iPhone の窓も広くできる [S15]。W で替えると、Pencil の無い iPhone で「指でも書く」がオフになる（F1）。W は見た目だけ（§4.3・§4.4・§4.7）。ほかに機種名・`UIScreen.main`・idiom・`UIPencilInteraction.prefersPencilOnlyDrawing`（Duo の iOS にその設定があるか【未確認】で、本人の意図と合うかも分からない）。
- iPad（idiom `.pad`。Mac の iPad のアプリも `.pad`）では何も付けない・何もしない。iPad の既定は 1.3 のままオフ。

**誰が今の値を書いたか（印 `allowFingerDrawingAuto`、String。§2.1）**:
- 1.4 の `appear()` が初めての起動の既定（1.3 と同じ値）を書いたとき、**その端末の印**（`identifierForVendor` [S60]）を書く。アプリが替えたときも、その端末の印を書く。本人がツールバーか設定のスイッチを触ったら `"person"`。
- 読み方: `"person"` → **本人**。この端末の印 → **アプリ**。無い → **1.3 以前から持ち越し**。**ほかの端末の印 → 移ってきた**（バックアップから戻した・新しい iPhone に移した。UserDefaults は iCloud では同期しないが、バックアップと機種の移し替えでは運ばれうる【推定: iOS の一般の動き。今回 Web では読んでいない】。`identifierForVendor` は別の端末では別の値 [S60]）。
- この端末の印が読めない（再起動の後で最初のロック解除の前は nil [S60]）起動では、`"person"` 以外を「持ち越し」と読み、印も書かない（その起動は P だけで動く。安全な側）。

**「指でも書く」の決め方（`FingerDefault`。オンのときに、オフへ替えるか）**:

| 誰が今の値を書いたか | H（折り目）を見たとき | P（Pencil の触れ）を見たとき |
| --- | --- | --- |
| アプリ（この端末。1.4 の初めての起動の既定か、アプリが替えた） | オフへ（1 回）。札を出し直す | オフへ（1 回）。札を出し直す |
| 1.3 以前から持ち越し（印が無い） | **替えない** | オフへ（1 回）。札は出さない |
| 移ってきた（ほかの端末の印） | **替えない**（下の「戻し」は別） | オフへ（1 回）。札は出さない |
| 本人（`"person"`） | 替えない | 替えない |

- **戻し（移ってきた、かつ「指でも書く」がオフのときだけ。1 回）**: ほかの端末でアプリがオフにした値が運ばれてきた。この端末が折り目のある端末か（H）で決める: H がある → オフのまま、印をこの端末に（rebind）。H が無い（ふつうの iPhone、`usesHinge` が false、iOS 27.1 より前、2 秒答えが無い）→ **オンに戻し**、印をこの端末に（turnOnAgain）。どちらも以後は「アプリ」の行で動く（戻した後に Pencil が触れれば、またオフへ）。本人がオフにした値（`"person"`）は運ばれても戻さない（本人の選び。ツールバーで戻せる）。
- **1.4 で初めて入れた Duo**: `usesHinge` が true で、その画面で折り目が読めれば、起動の直後（H）にオフ（iPad と同じ）。読めなければ、初めはふつうの iPhone と同じオンで、Pencil で最初の 1 本を書き終えたとき（P）にオフ。
- **1.3 から更新した Duo**: 1.3 は iPhone の既定（オン）を書いた。それまで指で書いていた人を、更新しただけで書けなくしないため、**Pencil が初めて触れたとき（P）だけ**オフへ替える。Pencil で書く人（本人の決定の前提）は、最初の 1 本を書き終えた時にオフになる。
- **ふつうの iPhone から Duo へ移した人**（1.4 で指で書いていた）も、1.3 から更新した人と同じく P だけで替える（C8 の (2)。移ってきた人を折り目だけで書けなくしない）。
- **本人の選びは守る**: ツールバーか設定でスイッチを触ったら（`CalendarRootScreen` が包んだ Binding の set）、印は `"person"`。以後アプリは替えない。
- **替える時（C6）**: 窓の `InkTouchObserver` が数える**全部の触れ（Pencil・指・ポインタ）が離れた時**だけ。P は「Pencil が触れた」を覚えておき、全部が離れた時に替える。H と戻しも、何も触れていない時に替える（触れている間に来たら、全部が離れるまで待つ）。だから、指で書いている線の途中で開いても、Pencil で書いている途中でも、`drawingPolicy` は線の途中で替わらない（キャンバスは `updateUIView` で次の値を当てる、`InkCanvasView.swift:922-926`。PencilKit の方針は次の線から効く）。
- **順（C2）**: `FingerDefault` は `appeared`（`appear()` が既定を書いた後の値と印）を受けるまで何もしない。H や触れが先に来ても覚えておき、`appeared` の後に 1 回だけ動く。
- **替えた後（F10）**: 「アプリ」の行（1.4 で初めて入れた人）だけ、週と日の横の道の札の記録（`AppSettings.spanGuideShown`、`AppSettings.swift:181-187`）を消して、次に開いた時に 1 本指の札（N-4・N-6、今の文）を 1 回出す。札の最初の文「前後の週が横につながりました」は 1.3 の人には起きていない事なので、**持ち越し・移ってきた人には札を出さない**（ツールバーの「指でも書く」ボタンが消えた色になることと、初めての案内の 3 枚目と同じ動きであることで足りるとする）。**1 ページの道（設定で横につなげるをオフ）では、札は誰にも出ない**（`SpanGuideView.swift:100` `showIfDue` は joined のときだけ）。
- **外側の画面**: 見た目は幅で決まる（2 段の見出し・週から開く・`.large` のシート・横の一覧は上限あり、§4.3・§4.4・§4.7）。**入力の仕方は開閉で替えない**（「指でも書く」は端末に 1 つ）。オフになった後は外側でも Pencil が書き、指が動かす。外側で Pencil が使えない場合も、指で動かし、ツールバーで「指でも書く」をオンにできる（iPad と同じ道）。
- **写真モード**: 同じ規則で動く（CI に Pencil は無いので P は来ない）。起動の引数で初めての起動と同じにできる（§2.1）。Duo の店の写真は `--screenshot-pencil-phone` でオフの形を撮る（§7.3）。
- **iPad とふつうの iPhone が変わらない証拠**: iPad は何も付けず、`FingerDefault(isPad: true)` は何も返さない（KitChecks の表）。ふつうの iPhone は P が来ない（Pencil が使えない [S19]）、H は nil（`iPhone 17` のシミュレータの単体テストと `duo measure:` の行で確かめる）。戻しは「移ってきた、かつアプリがオフにした値」のときだけで、それはアプリがオフにした端末（Duo）から運ばれた値にしか無い。`appear()` の既定の書き込みと `allowFingerChosen` を書く時は 1.3 のまま（`AppSettings.isExistingUser` が読む鍵、1.2 の「前からの利用者」の見分けを動かさない）。J-4 と UI テスト（`iPhone 17`、「指でも書く」オン）が同じであること。

### 4.9 開閉と、書いている途中の開閉

**約束（1.4 の動き）**:
1. 開く・閉じるは「窓の幅が変わる」として扱う。端末の種類（`.iPhone`）・ページの種類・焦点のページは替えない（§4.3 のとおり、初めて開くページの決め直しもしない）。
2. **横の道の窓の決め直しは、紙に触れている間（ペン・指）とスクロールの間は待ち、離して止まった後に 1 回**（凍結の `isAtRest` `InkCanvasView.swift:3223-3225` が `touchingPaper` を見る。`bandWidthChanged` `:3060-3083` → `redecideWindow` `:3289-`）。**倍率と位置は、1 ページの道でも横の道でも、幅が変わったその配置で替わる**（`:1245-1272`。ピンチとスクロールの間だけ止める `if !live`。ペンが触れていても替わる）。1 ページの道で拡大しているときは、幅の読み違い（`:1257-1260`）で、見ていた所が少し横にずれることがある（1.2.3 からの動き。§1.5。1.4 では直さない）。
3. **書き終えた線は失わない**（台帳にある。保存の予約は今のまま 1.5 秒）。書いている途中の 1 本は、閉じたときにシステムが触れを取り消すと、PencilKit が捨てることがある【未確認】。これは Apple の動きで、1.4 では直さない（確かめ表の行 25 で見る）。
4. 倍率は種類ごとの比の鍵のまま（倍率そのものは幅で変わる）。見出しは幅 600 で 1 段と 2 段が替わる（`CalendarRootScreen.swift:810`）。横の一覧の上限は、窓の決め直しの時に今の窓で決まる（§4.7）。
5. 画面（`windowScene.screen`）が替わっても、`sceneScreenSize`（`CalendarRootScreen.swift:1489-1494`）と `redecideWindow`（`InkCanvasView.swift:3295`、凍結）は今の値を読む。替わるのか、同じ画面の `bounds` が替わるのかは【未確認】（`duo-hinge` が動けば記録）。
6. **入力の仕方（「指でも書く」）は開閉そのものでは替えない**（§4.8）。ただし、1.4 で初めて入れて外側だけで使っていた Duo は、開いて初めて折り目が読めた時（H、`usesHinge` が true のとき）に 1 回だけオフへ替わることがある。そのときも、何も触れていない時だけ（線の途中では替わらない）。

**確かめ**:
- `DuoFoldTests`（単体、役 S。テストだけで、凍結のコードは呼ぶだけ）。窓の幅を 669 → 466 → 669 pt に変える（書いている印あり・なし）。**期待は道ごとに分ける**:
  - **横の道（週・日）**: (a) 紙に触れている間は窓の決め直しをしない（`touchingPaper`）、(b) 離して止まった後に窓の決め直しが 1 回、(c) 焦点のページと種類が同じ、(d) 台帳のページの JSON が前後で 1 バイトも同じ、(e) 保存の印（dirty）が立たない（線を足していないので）、(f) 保存した比の鍵（`zoomRatio.<kind>`）が変わらない、(g) 口 `overviewCapNow` を外側（true）↔ 内側（false）に替えて紙の領域を 678 × 256 ↔ 951 × 446 にすると、決め直しの後に `zoomBounds` の最小が上限あり ↔ なしに替わる（§4.7）。
  - **1 ページの道（月・年と、横につなげるをオフにした週・日）**: (c)・(d)・(e)・(f) だけ。真ん中の x（§1.5 の読み違い）と「書いている間は替えない」（1 ページの道の約束ではない）は比べない。
  - 幅の数は §4.2 で測った値に置き換える（測れなければ推定のまま、そう書く）。
- `DuoHingeUITests`（UI、`#if DUO_HINGE`、`duo-hinge` だけ）: 開く → 週で書く → 閉じる → 開く で線の数が同じ、閉じたまま書いて開く、書きながら閉じる（それまでの線が残る）。27.3 の正式版で動いたときだけ合否。beta なら記録だけ。
- **直しが凍結の `InkCanvasView.swift` に及ぶと分かったら**、1.4 の作業を止めて §5.4 の例外の手順で契約を直す（§12 の 0d-15）。

### 4.10 Duo でしないこと

- 折り目（`UIHinge`）をレイアウトに使うこと。半開きの折り目を避ける `ReservedRegion`（iOS 27.1 から）。
- 複数の窓（`UIApplicationSupportsMultipleScenes` を入れない。内側で 2 つのアプリを並べると窓が細くなるだけで、窓の大きさで追う）。
- Duo だけの画面・設定・文。
- Pencil のための新しい文の案内（§4.8）。

---

## 5. データ互換

### 5.1 保存の形（変えない）

- 新しいページ id・マス名・線の項目を作らない。`v` と書き出し `tegaki-app-export` v1 を上げない（K-5）。**1.4 は新しい保存の形を書かない**ので、新しい fixture は無い。`tools/compat-span/EXPECTED_MIN`（599）と `tools/compat10/EXPECTED_MIN`（225）は変えない。
- 仮想の名前（`span~…`・`<pageId>|…`）は端末のメモリの中だけ（1.3 の `SpanGuard` のまま。M7C_CONTRACT §6.1）。

### 5.2 K-1〜K-11 とこの版での当てはめ

規則の正文は [M7_PLAN.md](M7_PLAN.md) §1.3。

| 規則 | 1.4 での当てはめ |
| --- | --- |
| K-1 `allday` で始まる名前を使わない | 新しい名前は無い |
| K-2 同じ id の線を付け替えない | 台帳とキャンバスのコードを変えない（凍結）。付け替えの道は増えない |
| K-3 1 つのページに 2 枚のキャンバスで書かない | 窓は 1 つのまま（`UIApplicationSupportsMultipleScenes` を入れない）。開閉は同じ場面の中で窓の幅が変わるだけ |
| K-4 マスの意味を変えない | 変えない（Duo でもレイアウトは同じ Kit） |
| K-5 線に項目を足さない、`v`・v1 を上げない | 足さない・上げない。InkModel の 9 ファイルは 1 バイトも変えない。**新しい SDK でも保存のバイトが同じ**ことを D0 で確かめる（§5.6） |
| K-6 伸びる紙の一覧は固定部分 | 変えない（Duo も同じ `ZoomPolicy`） |
| K-7 互換テストは古い版の本物のコードで | 1.0・<1.1.1>・1.2.3 に、**本物の 1.3（955fe67）を足す**（§5.3）。古い木は macos-26・Xcode 26.6 で作る（§3.9） |
| K-8 古い端末での見え方を新機能の文に | 1.4 は新しい欄も新しい形も無いので、新機能の文に K-8 の句は入れない（1.2.4 と同じ）。1.3 より前の端末での見え方は 1.3 のまま（M7C_CONTRACT §6.5） |
| K-9 線の予算 | 変えない（持ち主のページで数える。Duo の窓の上限は iPhone の 12,000 本） |
| K-10 名前の文字 | 新しい名前が無いので当たらない。`SpanGuard` はそのまま |
| K-11 週の始まりとページ | 変えない |
| （1.3 の注）紙の外の点を切らない | 変えない |

### 5.3 本物の 1.3（955fe67）を互換の相手に足す（役 C）

M7C_CONTRACT §6.4 の最後と、S6 のリードの決定 3 の仕事。1.4 は凍結の 20 ファイルを変えないが、**1.3 で作り直したデータのコード（`InkLedger`・`InkCanvasView`・`SyncEngine`）が 1.1.1 と違うバイトになったので、1.4 から本物の 1.3 を相手に入れておく**（1.4.1 で凍結のファイル（ペンの色の `PencilInteraction` など）を変えることになっても、もう相手がいる）。

1. `tools/span-compat/run.sh:23-26` の case に `v13`。`:6-9` の注に `955fe678ec9f999ac45fac1b372f246e43c02f95`。取り出しは `git fetch --depth=1 origin <SHA>` → `git archive`（v123 と同じ、`build.yml:1540-1552`）。
2. 新しい `tools/span-compat/v13/Version.swift`: `versionName = "1.3 (955fe67)"`、`versionFolder = "v13"`。`versionLayout` は **1.3 の画面と同じ**に `WeekLayoutInput(..., freeMemo: true)` と日の `extraFloor` を渡す（省くと 1.2.3 の週になる。CODE_SURVEY §4.2 の 2）。`expectedDrawn` は 1.3 で数え直す（週のメモの見本 `w-2026-12-14`・`w-2026-12-21`・`w-2026-12-20` は 1.3 ではメモの線も描く。数は見本のファイルから数えて書く）。
   - **v13 だけの確かめ**: 全部の見本のページを 1.3 の `SpanGuard.checkForSave` に通し、直した項目が 0 であること（1.3 の端末がその見本を保存し直しても何も落とさない）。
   - **置き場所（C11）**: Probe は `run.sh:38-41` で `Common.swift`・`main.swift`・`Version.swift` を 1 つのパッケージにまとめ、上から順に動くコードは `main.swift` にしか書けない。そこで `Probe/main.swift` に `versionExtraChecks(pages:)` を呼ぶ 1 行を足し、`v10`・`v11`・`v123` の `Version.swift` には**何もしない同じ名前の関数**を足す。`v13/Version.swift` の物だけが `checkForSave` を数えて、0 でなければ落とす。このことを README の「見本を足すとき」と「版を足すとき」に書く。
   - Probe は Kit だけを使うので、**この Mac の `swift build` で先に通す**（`run.sh v13 <955fe67 の TegakiKit を git archive で出した所>`。Xcode は要らない）。CI の前に手元で緑にして、M7D.md に書く。
3. 新しい `tools/span-compat/AppTests/Real13LedgerTests.swift`（`Real123LedgerTests.swift` の形。955fe67 のアプリのテストの的で走る）:
   - 1 ページの道: **compat-span の見本だけ**を、1.3 の `InkLedger(page:layout:)`（1.3 のレイアウト）で読み、描く線の数が `expectedDrawn`、入る途中で何も動かない（`ledger.page == page`、`Real123LedgerTests.swift:140` と同じ確かめ）、書き戻しのバイトが元と同じ。**compat11 の見本は入れない**（`from10`・`legacy` の見本は帯の移しが働くので、バイトは元と同じにならない（C10）。compat11 は v13 の Probe（Kit）と、今の木の Compat のテストが見る）。
   - 同期: 一時フォルダの `InkPageStore`・`InMemoryCloudDatabase` の上の live の `SyncEngine` で、見本を `mergeRemote` に通しても中身が変わらない。保存しても同じバイト。
   - **横の道**: 週と日の見本のページのまわりで `SpanSession` の窓を開いて閉じる（月曜と日曜の週の両方）。窓に全部の線が入り（数）、`saveAll` の後もファイルが 1 バイトも同じ（dirty にならない）、`SpanGuard` の直しが 0。1.3 の利用者の既定は横の道なので、これが一番本物に近い。
   - 使う API は 955fe67 の `InkLedger.swift`・`SyncEngine.swift`・`SpanSession.swift` とテストの的（`TestSleeper` など）で確かめて書く（1.3 で口が変わった: `ownerId`、`pagesOpened`、`onRemoteDelete`）。
4. `build.yml` の compat-v1-0 に: 「Take out 1.3 (955fe67) at v13 and v13app」、`:1554-1561` の `for V in v10 v11 v123` に `v13`、「1.3's ledger and sync on the compat-span fixtures (Real13LedgerTests)」（`:1613-1650` の写し）。`:1384-1388` の注と、上限 45 → 65 分（測って M7D.md に書き、余れば戻す）。
5. `tools/span-compat/README.md` の表・走らせ方・「見本を足すとき」に v13 と `versionExtraChecks`。
6. **噛むことの確かめ**: 変異（取り込まない）で、見本の写しの 1 つに前置名のマス（`w-2026-12-14|grid`）を混ぜると、v13 の Probe の `SpanGuard` の確かめ（手元の `swift build` で見る）と `Real13LedgerTests` の横の道の確かめ（変異の枝 `r14-q-m1` の compat-v1-0）が落ちること。もう 1 つの変異で、見本の写しから線を 1 本消すと描く数の確かめが落ちること。run の番号と手元の結果を M7D.md に書く。

### 5.4 凍結の表（`tools/compat10/DATA_1_1.sha256`、20 行）

**1.4 で変えてよい行: 無し**（基準は 955fe67 のまま）。CI の段の名前「Data code frozen (re-based in 1.3)」も変えない。`lint-skip.txt` も同じ 20 行。

| 行 | ファイル | 1.4 |
| --- | --- | --- |
| 1 | `Ink/InkCanvasView.swift` | 変えない。Duo の開閉の直しが要るときは例外の手順（§4.9） |
| 2 | `Ink/InkLedger.swift` | 変えない |
| 3 | `Ink/InkOverlayView.swift` | 変えない |
| 4 | `Ink/InkSnapshot.swift` | 変えない（倍率は呼ぶ側で渡す、§4.5） |
| 5〜7 | `Ink/InkTools.swift`・`InkTouchObserver.swift`・`InkTrace.swift` | 変えない（`InkTouchObserver` は §4.8 で新しいインスタンスを窓に付けて使うだけ。ファイルは 1 バイトも変えない） |
| 8 | `Ink/PencilInteraction.swift` | 変えない（ペンの色の 1.4.1 で） |
| 9 | `Persistence/InkPageStore.swift` | 変えない |
| 10 | `Sync/InkPageRecord.swift` | 変えない |
| 11 | `Sync/SyncEngine.swift` | 変えない |
| 12〜20 | `TegakiKit/Sources/InkModel/` の 9 ファイル（`BandMigration`・`InkImport`・`InkPage`・`InkPageCodec`・`InkStroke`・`JSONValue`・`SpanComposer`・`SpanGuard`・`WebImport`） | **変えない（例外なし）**。要るなら 1.4 を止めて契約を直す |

**例外の手順（行 1〜11 だけ。§12 の 0d-15）**: 次の全部がそろったときだけ。
1. 理由が「新しい SDK が強いた」こと（iOS 27.2 SDK でのコンパイルのエラー、または新しい SDK でだけ落ちるテストが CI のログにある）か、Duo の開閉の直しが `DuoFoldTests`・`DuoHingeUITests` で要ると示されたこと。
2. 変えるのはその直しに要る最小の行で、保存・merge・同期・墓標の行ではない。
3. 同じ commit で表の行を書き直す。S6-RM-5 のとおり、手元で `lint-skip.txt` からそのファイルを一時的に外して `lint.py` が OK、元に戻す。
4. M7D.md に 1 行: commit・ファイル・変えた行の数・1 ページの道と横の道のどちらが通るか・理由・その行を通る既存のテストの名前（M7C_CONTRACT §6.4 の記録の形）。
5. §5.3 の本物の 1.3 の相手、§5.6 のバイトの確かめ、`TESTS_1_2_3`・`TESTS_1_3`、J-4 が全部緑。
6. リードがその commit の diff を 1 行ずつ見て、M7D.md に「リードの決定」として書く。本人には最後の報告で知らせる。

### 5.5 1.3 のテストと fixture の表（`tools/span/TESTS_1_3.sha256`・`FIXTURES_1_3.sha256`、新しい。D0 の commit）

- 1.2.4・1.3 で足した、データ・同期・台帳・キャンバス・横の道・写真モード・案内の札・設定を見張るテストのファイルと、1.4 が触る所（`PaperView`・`SpanPlan`・写真モード・札の記録）を見張る前からのテストを、**955fe67 のバイトのまま**守る（1.2.3 の `TESTS_1_2_3.sha256` と同じ考え。新しい SDK で落ちたテストを、テストの側を書き換えて通すことを防ぐ）。
- **D0 の commit で入れる**（D0b の SDK の直しより前に。C5）。各行は**今の木からではなく 955fe67 の blob から**作る: `printf '%s  %s\n' "$(git show 955fe67:"$f" | shasum -a 256 | cut -d' ' -f1)" "$f"`。作った表で、D0 の木に `shasum -a 256 -c` が全部 OK になることも確かめる（7895d40 と 955fe67 のコードは同じ）。
- **`TESTS_1_3.sha256` の行**（`TESTS_1_2_3` の 8 ファイルは入れない。もう守られている）:
  - `Tests/TegakiCalendarTests/`: `InkLedgerSpanTests.swift`・`InkCanvasSpanTests.swift`・`SpanSessionTests.swift`・`ScreenEraseTests.swift`・`SyncEngineSpanTests.swift`・`SyncEngineEraseFetchTests.swift`・`SyncEngineZoneAccountTests.swift`・`ScreenPathsSpanTests.swift`・`ScreenPathsCanvasSpanTests.swift`・`WeekMemoSpanTests.swift`・`PaperSpanFrozen123.swift`・`PaperSpanTests.swift`・`SpanGuideSeenSpanTests.swift`・`ScreenshotModeSpanTests.swift`・`WeekMemoPaperSpanTests.swift`・`StageTwoNoticeSpanTests.swift`・`SettingsPageSectionTests.swift`・`EventStoreModelSpanTests.swift`・`PaperViewTests.swift`（`:74-109` が描き直しの数を数える。§4.5 の読み直しで変えない）。
  - `Tests/TegakiCalendarUITests/`: `SpanUITests.swift`・`SpanShotsUITests.swift`・`SpanRerunUITests.swift`（新しいシミュレータで一番揺れやすい所。揺れたら下の (a)）。
  - `TegakiKit/Tests/CompatSpanTests/` の全部と `TegakiKit/Tests/CompatSpanFixtures/` の `.swift` の全部（compat-span の期待を作る）。
  - `TegakiKit/Sources/KitChecks/`: `OverviewCapChecks.swift`（§4.7 の「1 字も変えない」を守る仕組み）・`SpanChecks.swift`（注も直さない、§1.5 (c)）・`SpanInkChecks.swift`・`WeekMemoChecks.swift`。
  - 行の数は D0 の前に M7D.md に書く（§3.7 の 11）。
- **`FIXTURES_1_3.sha256` の行**: `TegakiKit/Tests/Fixtures/compat11/`・`TegakiKit/Tests/Fixtures/compat-span/`（`MANIFEST` を含む）・`TegakiKit/Tests/CompatFixtures/` の全部のファイルと、`tools/compat10/EXPECTED_MIN`・`tools/compat-span/EXPECTED_MIN`。今 CI がハッシュで守るのは `TegakiKit/Tests/Compat10/FROZEN.sha256`（`build.yml:197`）・`DATA_1_1`（`:249`）・`TESTS_1_2_3`（`:259`）だけで、compat11・compat-span の JSON と MANIFEST は守っていない（`TEGAKI_FIXTURE_OUT` から書き直せる）。Compat10 は `FROZEN.sha256` のまま。
- build-and-test の 2 つの段:
  - 「1.3's tests unchanged (TESTS_1_3)」: `shasum -a 256 -c tools/span/TESTS_1_3.sha256`。
  - 「1.3's fixtures unchanged (FIXTURES_1_3)」: `shasum -a 256 -c tools/span/FIXTURES_1_3.sha256` と、**3 つのフォルダの中のファイルの一覧が表の行と同じ**こと（足した・消したファイルも落とす。1.4 は新しい fixture を作らない、§5.1）。
- 新しいテストは全部新しいファイルへ（§6）。
- **`TESTS_1_3` のファイルを変えてよいとき**: (a) 新しい SDK で揺れる（同じコードで通ったり落ちたりする）ことを 2 回以上の run で示し、原因（待ち方など）を書けたとき、(b) 新しい SDK で API が変わってコンパイルできないとき、(c) 新しい SDK の UIKit が、テストの描画の道具（テストのファイルの中の手順）に、アプリの描く物ではないシステムの飾りを足すことを試しの run で示したとき（直しはその飾りを消すことだけ。D0b、11/20 の L1）。どれも確かめの強さを下げない（期待の数・比べ方を緩めない）。同じ commit で表の行を書き直し、M7D.md に run の番号と理由を書く。**`FIXTURES_1_3` のファイルは変えない**（変えたくなったら止めて、§12 の 0d-15 で契約を直す）。

### 5.6 新しい SDK で保存のバイトが同じこと

- Xcode 27.2 の CI で、`InkLedgerTests.testLedgerWritesTheCompatShapes`（`ledger-*.json`）・`ScreenshotModeTests.testDemoPagesMatchCompatFixtures`（写真モードの `screenshot-*.json`。`Tests/TegakiCalendarTests/ScreenshotModeTests.swift:646-`、`TESTS_1_2_3` の 6 行目。`Compat10FixtureTests.swift` は K の小さな fixture と digests だけで、この JSON には触れない（`:4-7`））・`SpanSessionTests.testSpanSessionWritesTheCompatSpanShapes`（compat-span）が、作り直さずに今の fixture と 1 バイトも同じであること（§3.3 の関門 2。fixture そのものは `FIXTURES_1_3` が守る）。新しい Foundation で JSON の数の書き方や鍵の並びが変わっていないことの証拠になる。この 3 つの名前を、M7D.md の確かめの一覧にもこの字で入れる。
- 違ったら**止める**: 新しい SDK で保存のバイトが変わると、1.3 以前の端末との merge の F4（同じ id の線の勝ち負け）は中身で決まるので線は失わないが、全部のページが「変わった」と見なされて送り直される恐れがある【推定】。原因を書き、§12 の 0d-15 で決める（fixture を作り直すことはしない）。
- iCloud へ送る圧縮（lzfse、`InkPageRecord`）のバイトは OS で変わりうるが、解いた中身は同じ（比べない）。

---

## 6. テスト

1.3 の既存のテストのファイル（`TESTS_1_2_3`・`TESTS_1_3`）と fixture（`FIXTURES_1_3`）は変えない。新しいテストは新しいファイル。時間を待つテストは `TestSleeper`（本物の sleep を使わない）。「直しが無いとどう落ちるか」は、直しを入れる前の木（D0 の木）か、変異で確かめる。**変異の置き場所（§3.10）**: Kit と純粋な関数の変異は**手元の `swift run KitChecks`**（CI を使わない）。アプリの変異は 1 本の枝 `r14-q-m1` にまとめ、UI の変異は `r14-duo-m1`（duo.yml）にまとめ、1 回の run で、落ちたテストの名前で見分ける。結果と run の番号を M7D.md に書く（1.3 の形）。

| 役 | ファイル（新しい） | テスト | 直しが無いと（変異はどこで） |
| --- | --- | --- | --- |
| K | `DuoChecks.swift`（KitChecks の節「duo (1.4)」） | §4.6 の測った行（外側の縦・横、測れたら内側の縦・横 × 週・日）: 機種 `.iPhone`、V（±0.006）、R、`maxVisiblePages`、`zoomBounds` の最小、一番縮めて見える時間。外側の横（`overviewCap` あり）は 3 / 5、内側の横（なし）は nil。内側の横の「終日帯が 35 % の上限」の紙の領域でも nil（帯で答えが替わらない） | 節が無いと数が閾値（新しい数 − 50）を割って落ちる。変異 KM-d1（`SpanPlan` の iPhone の横の上限を外す）で外側の横の行と `OverviewCapChecks` が落ちる。**手元** |
| S | `WindowFingerChecks.swift`（KitChecks の節「window & finger (1.4)」） | **WindowClass**: `isWide`（402×874・874×402・440×956・956×440 → false、669×951・951×669・626×890 → true、599.9×900 → false、600×600 → true、nil・0・負・NaN・無限 → false）、`openingKind`（stored が勝つ・iPad は月・402×874 → 週・**874×402 → 週**・669×951 → 月・951×669 → 月・466×678 と 678×466 → 週・測れない → nil）、`usesFormSheet`（`formSheetOnWide` が false なら iPad だけ。true なら広い窓も）、`capsOverview`（今の iPhone の窓の大きさ全部（`SpanPlan.referenceViewport` の iPhone の行と 1.3 の機種の表）で true、669×951・951×669 で false、測れないと true）、`Opening`（大きさが先でも後でも 1 回だけ・その後 669 → 466 でも替わらない・stored なら最初から）。**FingerDefault**: `origin`（"person"・同じ印・無い・空・別の印・device nil）、§4.8 の表の全部の組（4 つの誰 × H・P × オン・オフ × iPad かどうか）、戻し（移ってきた・オフで H true → rebind、false → turnOnAgain、まだ来ない → 待つ。移ってきた・オンなら何もしない。本人のオフは戻さない）、順（`appeared` の前に H や触れが来ても、`appeared` の後に 1 回だけ）、触れている間は何もしない（指だけでも Pencil だけでも）・全部離れた時に 1 回・`touchesReset` でも離れたと数える、2 回目は何もしない、本人の後は何もしない、`rearmGuide` は「アプリ」のときだけ true、`Signal.allCases == [.hinge, .pencil]`（窓が無い） | 1.3 の木には型が無い。**変異は手元の KitChecks**: M-w1（短い辺でなく幅）で 874×402 と 678×466 の行、M-w2（大きさのたびに決め直す）で開閉の行、M-f1（持ち越し × H でオフ）、M-f2（本人を見ない）、M-f3（触れている間にも動く）、M-f4（`appeared` の前に動く・origin を既定で .app と読む）、M-f5（戻しを消す）、M-f6（`rearmGuide` をいつも true）、M-f7（窓の広さを信号に足す）が、それぞれの行で落ちる |
| S | `WindowClassTests.swift`（アプリ。つなぎ） | `testWideShortSideIsTheCompactWidth`（`WindowClass.wideShortSide == CalendarRootScreen.compactWidth`）、`testWideWindowSessionHasNoCap`（`ScreenPaths.device(isPad: false, windowSize: 669×951, …)` の `wide` が true で、作った窓の plan の `overviewCap` が false。402×874 と 874×402 では true（1.3 と同じ））、`testRedecideReadsTheWindowNow`（`SpanSession` の口 `overviewCapNow` を true → false にして `redecide` すると次の plan の `overviewCap` が替わる。口が無ければ 1.3 と同じ値のまま） | 変異（`makeSession` が `overviewCap: true` のまま）で 2 本目、（`redecide` が口を読まない）で 3 本目が落ちる。`r14-q-m1` |
| S | `PencilPhoneTests.swift`（アプリ。つなぎ） | `testOriginReadsTheMark`（試験用の UserDefaults の suite で、"person"・同じ印・無い・別の印 → 4 つ）、`testPersonSetMarksThePerson`（`personSet` で値と "person"）、`testFirstLaunchWritesTheMarkOnly`（`allowFingerChosen` が無いときだけ印を書く。あれば書かない＝1.3 からの更新は持ち越し）、**`testWatcherCountsEveryTouch`**（凍結の `InkTouchObserver` の新しいインスタンスを UIWindow に付け、このファイルの中だけの作り物の `UITouch`（`private final class`。`InkCanvasViewTests.swift:2447-2459` の `StandInTouch` と同じ形の写し。元のファイルは `TESTS_1_2_3` なので変えない）の `.pencil`・`.direct`・`.indirectPointer` で `touchesBegan`・`touchesEnded`・`touchesCancelled` を呼ぶ: Pencil で `touchDown(pencil: true)` が 1 回、指は数えるが Pencil にしない、全部離れた時に数が 0、`reset()` で離れたと数える、状態は `.possible` か `.failed` だけ）、**`testPencilLiftTurnsFingerOffEndToEnd`**（同じ作り物の触れで、Pencil が触れる → 離れる → `allowFinger` が false・印がこの端末・「アプリ」なら週と日の札の記録が消え、持ち越しなら消えない。指が触れたままなら替わらず、離した後に 1 回）、**`testHingeIsNilOffTheDuo`**（iOS 27.1 以上のシミュレータ（単体テストの機種、27.2）で `UIHingeInteraction` を窓の view に付けると、最初の update の `hinge` が nil。Mac Catalyst では作らない）、`testNoModelNames`（`PencilPhone.swift`・`WindowClass.swift`・`FingerDefault.swift` の字に `utsname`・`hw.machine`・`.model`・`UIScreen.main`・`userInterfaceIdiom` が無い。ソースを読む形は名前の見張りだけ） | 1.3 の木には型が無い。変異（つなぎが指も Pencil と数える）で 4・5 本目、（札をいつも消す）で 5 本目、（Binding の set が "person" を書かない）で 2 本目が落ちる。`r14-q-m1` |
| S | `CappedOverviewWideTests.swift` | `testWideWindowIsNotCappedThroughShotPaperOffset`（`overviewCap` なしの窓（951×446 の紙、日・週）で、一番縮めた倍率でも `atCappedOverview` が false、**`shotPaperOffset` の開く高さが 0:00（todayY が nil）**。`overviewCap` ありの 874×205 は 1.3 と同じ `cappedOpeningY`）、`testFoldSwitchesTheCapAtTheRedecide`（678×256 ↔ 951×446 で口を替えて `redecide` すると、`zoomBounds` の最小が上限あり ↔ なしに替わる） | 変異（`makeSession` が `overviewCap: true` のまま）で 1 本目の 951×446 の行が落ちる（今日が 1 時間前から開く。C1）。`r14-q-m1` |
| S | `OnePageRevealTests.swift` | `testRemoteDeletedForgetsTheTodayRect`・`testEraseAndStartClosedForgetsTheTodayRect`（1.3 の `testEraseAllForgetsTheTodayRect` と同じ、ソースを読む形） | 1.3 の木（`:1751-1758`・`:2344-2348` に `revealRect = nil` が無い）で落ちる |
| S | `SnapshotScaleTests.swift` | `testEverySnapshotPassesTheWindowScale`（凍結の外の `Sources` の `InkSnapshot.render(` の呼び出しが全部 `scale:` を持つ。ソースを読む形）、`testSnapshotHonorsTheScale`（`render(..., scale: 2)` と `3` で画像の `scale` と画素が違う） | 1.3 の木の 2 か所は `scale:` が無いので 1 本目が落ちる |
| S | `DuoFoldTests.swift` | §4.9 の確かめ。横の道は (a)〜(g)、1 ページの道は (c)〜(f)。`testWidthChangeWhileDrawingWaitsForPenUp`（横の道）・`testFoldRedecidesTheWindowOnceAfterSettling`（横の道）・`testFoldKeepsKindFocusAndBytes`（両方）・`testFoldMarksNoPageDirty`（両方）・`testFoldKeepsTheZoomRatioKey`（両方）・`testFoldSwitchesTheCap`（横の道） | 1.3 の動きを固めるテスト。変異で凍結の `InkCanvasView` の `pendingRedecide` の道を外すと 1・2 本目が落ちることを確かめる（`r14-q-m1`。取り込まない） |
| P | `PaperViewScaleTests.swift` | `testScaleFollowsTheDisplayScaleTrait`（窓に置いた `PaperView` の `traitOverrides.displayScale` を 2 → 3 にすると `contentScaleFactor` と `layer.contentsScale` がついて来る）、`testSameScaleRequestsNoDisplay`（同じ値の特性の変化では描き直しを頼まない） | 1.3 の木は `didMoveToWindow` だけなので、窓を替えずに特性だけ変えると 2 のままで 1 本目が落ちる。`PaperViewTests`（`TESTS_1_3`）の数が変わらないことも同じ run で見る |
| U | `DuoLayoutUITests.swift`（`TEST_RUNNER_TEGAKI_DEVICE=duo` のときだけ。ほかは `XCTSkip`） | `testOuterHeaderRows`（外側の縦は 2 段）、`testInnerHeaderIsOneRow`（内側が開ける道 1・2 だけ）、`testJoinedWeekSwipesOnDuo`（ツールバーの「指でも書く」がオフなら 1 本指、オンなら 2 本指で横に動かすと、題名が 1 回だけ変わる）、`testSheetsFitOnDuo`（外側は `.large` で「保存」「キャンセル」と EULA の行が見える。内側は道 1・2 だけで §4.4 の (a)・(b)）、**`testFingerDefaultFollowsTheHinge`**（起動の引数 `-allowFingerDrawingChosen NO`・`-allowFingerDrawingAuto ""` で初めての起動と同じにし、ツールバーの「指でも書く」の値を読む: `usesHinge` が true でその画面の `hinge=` が nil でないならオフ、そうでなければオン。期待は §4.2 の測りの後に、この規則で前もって決めて書く） | 変異（`compactWidth` の比べを idiom に戻す）で見出しの行が落ちる。変異（H をつながない）で `testFingerDefaultFollowsTheHinge` が落ちる（`usesHinge` が true のときだけ。false なら変異は無く、そう書く）。`r14-duo-m1`。`duo-shots` は「Duo で走った数 ≥ 道ごとに前もって書いた数（§4.2）・失敗 0」でなければ落とす（飛んだ物を数えない） |
| U | `DuoHingeUITests.swift`（`#if DUO_HINGE`） | §4.9 の 3 本 | 27.3 の正式版のときだけ合否。beta は記録だけ |
| C | build-and-test の段 | `TESTS_1_3` と `FIXTURES_1_3` の `shasum -c` とファイルの一覧（D0）、`idiom_check.py`、`DUO_HINGE` が `project.yml` に無い、`xcodegen --version` が固定の版 | 変異（凍結の外のファイルに `UIScreen.main` を 1 つ足す）で `idiom_check.py` が落ちる。`TESTS_1_3` のファイルに 1 字足すと落ちる。fixture のフォルダにファイルを 1 つ足すと落ちる。`r14-q-m1` |
| C | `testflight.yml` | アーカイブの `DTSDKName`・`MinimumOSVersion`（§3.4） | 直しが無いと（今の `macos-26` の Xcode 26.6 で作ると）`DTSDKName` が `iphoneos26.5` で落ちる。ITMS-90725 のメールが言う 1.2.4 の「iOS 26.5 SDK」と同じ事実 |
| C | compat-v1-0 | v13 の Probe（`SpanGuard` の直し 0 を含む）、`Real13LedgerTests`（1 ページの道・同期・横の道） | §5.3 の 6 の変異で落ちる（Probe は手元、`Real13LedgerTests` は `r14-q-m1`） |
| C | `tools/duo/shot_checks.py`（duo-shots の段） | 黒い写真の確かめ（明るさの平均）、**端の列が全部黒でない**（「真ん中に小さく」でない。互換の表示ではアプリから見える窓も小さいので、アプリの中のテストでは分からない。合否はこの写真の確かめで決める）、Duo の店の寸法（§7.1）、`duo measure:` の行が全部の種類で出た | 確かめの道具そのものを、端を黒く塗った作り物の写真・黒一色の写真・寸法を 1 画素ずらした作り物の写真にかけて落ちることを確かめる（`shot_checks.py --self-test`。**手元**の python と `sips` で走る。本物の「真ん中に小さく」の写真は、Xcode 26.6 が `xcode-27` の環境に無いので撮れない） |

- 既存のテストはそのまま全部通す: アプリの単体 745 本、Kit 364 本、UI 43 本、同期の 20 回（`SyncEngineSpanTests`・`SpanSessionTests`・`ScreenEraseTests`・`SyncEngineEraseFetchTests`・`SyncEngineZoneAccountTests` を含む）、KitChecks。
- 第 1 版にあった `testPaperFillsTheScreen`（紙の幅＝窓の幅−安全域）は**やめた**（互換の表示ではアプリの窓そのものが小さいので、決して落ちない。C13）。`PencilSeenRecognizer` の設定を字で読むテストもやめた（新しい認識器を作らず、凍結の `InkTouchObserver` を使う。C7）。
- **iOS 17 で起動できるかの試し（1 回だけ、合否に使わない）**: `xcode-27` の環境に iOS 17 の実行環境は無い [S29]。D1 で 1 回だけ、`xcodebuild -downloadPlatform iOS -buildVersion 17.5`（などで取れるか【未確認】）で iOS 17 の iPhone を作り、1.4 のアプリが写真モードで起動して週を描くかを撮る（新しい SDK が iOS 17 に無い物を弱いリンクなしで使っていないか。`UIHingeInteraction` は `if #available(iOS 27.1, *)` の中だけ）。取れなければ M7D.md に【未確認】と書き、今の弱いリンクの確かめ（`testflight.yml`）に頼る。起動しなければ止めて調べる（iOS 17 の人が開けなくなるため）。

---

## 7. 写真

### 7.1 App Store の Duo の写真

- 寸法【事実 [S13]】: **外側 1398 × 2034**（縦）／2034 × 1398（横）、**内側 2007 × 2853**（縦）／2853 × 2007（横）。2027 年 4 月から必須（対象の書き方が仕様のページとニュースで食い違う。厳しい方に合わせる）[S9][S13]。内側と外側の**両方**が要るかは【未確認】。
- **既定: 縦の外側と（撮れれば）内側**を、今の 6.9 インチの組と同じ 5 枚（`00-span`・`01-week`・`02-month`・`03-day`・`04-year`）で、**16 ロケールの全部**（store-shots の組: en・en-GB・zh-Hans・zh-Hant・ko・fr・de・it・es・es-ES・pt-BR と、**ja は 5 枚とも**。en-CA・en-AU・fr-CA・pt-PT・es-MX は今の対応のまま）。主言語は en-US なので、無いロケールは英語の写真になってしまう【推定】。それを避けるため ja を含めて全部撮る。
- 寸法の合わせ方: 内側の写真が 2007 × 2853 で撮れればそのまま。1878 × 2670（画面の画素 [S18]）なら `sips -z 2853 2007` で拡大（縦横の比 0.7034 と 0.7035、ほぼ同じ）。外側は 1398 × 2034 のはず。ほかの寸法なら警告して使わない。`accepted()`（`build.yml:1147-1155`・`store-shots.yml:258-264`）に `duoOuter) 1398x2034`・`duoInner) 2007x2853` を足す。
- **内側を撮れない（§4.2 の道 3、既定）とき: 外側だけを出す**。外側も撮れないときは、1.4 は Duo の写真なしで出し、4 月より前の次の版で足す（§12 の 0d-23）。
- 中身は今の店の写真と同じ約束: 価格と Apple の商標を入れない（M6.md §4.6）、状態の帯は 9:41（store-shots の FIX4・FIX5）、見本の字（`--screenshot-store-ink`）、最初に 180 秒待つ（§3.8）。Duo の写真は全部 `--screenshot-pencil-phone`（「指でも書く」オフ。ツールバーのボタンが iPad の写真と同じ消えた色になる。§2.1）。写真の中に Apple Pencil の絵は入れない（Pencil の製品の絵は Apple の物）。Duo の写真を出すと店に「iPhone Duo に最適化」の印が出る [S9][S13]（画面いっぱいに出るので、実態と合う）。
- **本人の確認ページで見てもらってから入れる**（§0.4。新機能の文・SUPPORT と同じページ）。

### 7.2 上げ方（Connect）

- Duo の写真は **App Asset Library の API でしか指せない**（表示の種類 `IPHONE_DUO`。前からの `appScreenshotSets` などは API 4.5.1 で非推奨で、Duo の値が無い）[S21][S24][S25][S26]。
- リードが `asc12/`（リポジトリの外）に新しいスクリプト（例 `shots14.py`）を作る: `GET /v1/appAssetLibraryRefData` で置き場所の組と寸法を読み（名前は決め打ちしない [S26]）、`POST /v1/appAssetLibraryImages` → 上げる → `uploaded: true` で確定 → `POST /v1/appAssetLibraryPlacements` → 順番、の後に**読み戻して数と順と寸法を確かめる**。**処理の後に Connect が付ける `specId` も読み戻し、思った仕様（Duo の外側か内側か）と同じかを確かめる** [S26]（VERIFY OK を M7D.md に）。今の写真（`shots13.py` の道）には触れない。
- **置き場所（placement）は、版が直せる状態（`PREPARE_FOR_SUBMISSION`）のときしか作れない** [S26]。だから Duo の写真は **1.4 の提出の前**に入れる。提出の後や公開の後には足せない（足すのは次の版、例 1.4.1 の提出の時）。
- 1.3 の `shots13.py` がどの API を使っていたかは【未確認】（リポジトリの外。リードが D2 の最初に読む）。

### 7.3 CI の写真（`duo-shots`。本人の確認ページにも使う）

| 写真 | 見えていなければならないもの |
| --- | --- |
| 外側の縦: 月・週（横の道）・日（横の道）・年 | 紙が画面いっぱい（端に黒い帯が無い、`shot_checks.py`）。見出しは 2 段。ツールバーが切れない |
| 外側の横: 週・日の一番縮めた形 | 上限ありの一覧（週 3・日 5）。今日のページは今の 1 時間前から（§4.7） |
| 内側の縦・横（開ける道 1・2 のとき） | 紙が画面いっぱい。見出しは 1 段。横の一番縮めた形は上限なし（0:00 から） |
| 設定・購入・予定の 3 つのシート（外側と、開けるとき内側） | 字が切れない。「保存」「キャンセル」・EULA の行・「あとで」が見える（§4.4） |
| 外側の縦: 写真モード（`--screenshot-pencil-phone` なし）・起動の引数で初めての起動と同じにした週 | ツールバーの「指でも書く」が、`usesHinge` が true でその画面の `hinge=` が nil でなければオフ、そうでなければオン（§4.8。期待は §4.2 の測りの後に前もって書く） |
| 内側の縦（開けるとき）: 同じ | 同じ規則 |
| `iPhone 17` の縦: 同じ引数の週（1 枚） | 「指でも書く」がオン、`hinge=nil`（ふつうの iPhone が変わらない証拠） |
| `duo measure:` の行（env） | 窓・安全域・倍率・紙の領域・V・R・上限・`wide=`・`hinge=`・`origin=`（§4.2） |

- 写真の明るさの平均の確かめと、端の列の確かめ（§6 の C の行）。成果物は 7 日で消える（`retention-days: 7`）。確認ページはその間に作る。

### 7.4 今の写真

- 13 インチ・6.9 インチ・6.3 インチの店の写真は**撮り直さない**（1.4 の画面は今の機種で 1.3 と同じ。Connect は新しい版を作ると前の版の写真を引き継ぐ【推定】。Connect に版 1.4 を作った後に読み戻して確かめる）。
- CI の今の写真（J-4・blank-paper・l10n-shots・span-shots-app）は、機種の替わり（§3.2）だけで撮り続ける。

---

## 8. 文字・訳・App Store

### 8.1 新機能の文（16 ロケール。ja はこの文、ほかは訳。最後の行は AI の訳の断り（ja 以外））

**行ごとに作る**（行ごとに訳と逆翻訳をし、使う行をこの順に並べる）:

**行 1 案 A**（開閉を確かめられたとき: 27.3 の正式版の `duo-hinge` で `DuoHingeUITests` が緑、または本人の Duo で確かめ表の行 18 と 25 が ○。既定の道 3 では本人の Duo だけが頼り）:

> ・iPhone Duo の大きな画面いっぱいに表示されるようになりました。開いても閉じても、そのまま書き続けられます。

**行 1 案 B**（確かめられなかったとき）:

> ・iPhone Duo の大きな画面に合わせて表示するようにしました。

**行 2**（Duo の Apple Pencil。本人の Duo で確かめ表の行 19 と 20 が ○ のときだけ）:

> ・iPhone Duo では iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。

**行 3**（いつも）:

> ・iOS 27 の新しい開発環境に移りました。iPad とほかの iPhone での使い方は変わりません。

**行 4**（中国の祝日を入れたときだけ）:

> ・中国の 2027 年の祝日を、発表された休みに合わせました。

- 全部の行の訳を先に作り（訳と逆翻訳は 1 回で済ませる）、確認ページには**全部の行と、どの行を使うかの条件**（上の括弧）を書く。本人の「この内容で入れてよい」は全部の組み合わせに効く。提出の前に、`duo-hinge` の結果と確かめ表の行 18・19・20・25 の答えで決め、M7D.md に書く（1.3 の確認ページの「選ぶ 1」と同じ形）。「指でも書く」の語は、各言語のアプリの `toolbar.fingerToggle` の訳と同じ字にする（`tools/l10n/source/app-S.json:2862` の訳。X が写す）。無い改善は書かない（R1_2_2.md:694）。K-8 の句は入れない（§5.2）。4,000 字まで。en-GB・en-AU・en-CA は en-US の写し、fr-CA は fr-FR の写し（`docs/store/locales.json`）。
- プロモーションテキストは新しい版で空になるので、今の文を入れ直して読み戻す（`docs/store/README.md:12`）。

### 8.2 訳と逆翻訳（X・R）

- 新しい文は店の文だけ（行 1 の案 A・案 B・行 2・行 3・行 4、と審査メモの段、SUPPORT の 2 文）。9 言語の訳（X、`docs/i18n/GLOSSARY.md`）→ 元を見ない逆翻訳（R、`docs/i18n/back`）→ `REVIEW.md` の × を 0 に。
- アプリの文は増えない（L-3）。8 キーの comment（§1.5 (a)）は訳の対象でない。`lint.py`（L-1〜L-14）・`build.py --check`・`baseline.py --check` が緑。日本語の基準（J-1）は 516 のまま（N-3 の文を本人が替えると選んだときは、数は 516 のままで、その 1 キーの ja と 9 言語と jaSha1 が替わる。訳と元を見ない逆翻訳は 1.3 で済んだ物（`docs/store/PROPOSALS_1_3.md` §2）を使う。§1.5）。
- 言語ごとの確認表は、確認ページ 1 回の中で全部そろえて見せる（M7B-18 の「はい」は 1.2 の分だけ）。

### 8.3 審査メモ（`docs/store/review-note.txt`。英語が主で日本語の要約、4,000 バイトまで）

- 今は 3,994 バイト（7895d40）。「What is new in 1.3」の段（1〜5）と日本語の要約の 1.3 の分を、次の「What is new in 1.4」に入れ替える（1.3 の 1 の「It」と 4 の言い方の △ も、これで消える）。ほかの段（ログイン不要・言語・データの扱い）はそのまま。
- 書くこと: (1) Xcode 27.2（iOS 27.2 SDK）で作った。配る先は iOS 17.0 のまま。(2) レイアウトは端末の種類ではなく窓の大きさで決める。iPhone Duo では内側の画面と外側の画面のどちらでも画面いっぱいに出て、開閉に追う（ページと手書きはそのまま）。確かめ方: iPhone Duo で週のページを開き、開く・閉じる。(3) iPhone Duo では iPad と同じく、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かす（その iPhone で Apple Pencil の触れか、画面の折り目（`UIHingeInteraction`）を見たら「Draw with finger」をオフにする。1.3 から更新した端末は Pencil の触れのときだけ。機種の名前も窓の大きさも読まない。ツールバーのスイッチで指でも書ける）。(4) 新しい画面の文は無い。データの扱い（App Privacy は「データの収集なし」）・手書きの保存先・購入・年齢区分（新しい 2 問はどちらも No）は変わらない。案 B のときは (2) の「開閉に追う」を「幅に合わせる」に。(3) は行 2 を入れないときも書く（審査の人が Duo と Pencil で試すときの手引きのため）。
- 入れ替えた後のバイト数を M7D.md に書く（4,000 を超えたら、1.2 からの段を短くする）。

### 8.4 SUPPORT（日本語・英語。W。公開の日に Web へ。承認は確認ページの 1 回）

- 「iPhone や Mac でも使えますか？」（`docs/SUPPORT.md:121-123`、英語は同じ節）に 1 文足す: 「iPhone Duo では、開いた大きな画面いっぱいに、閉じたときは外側の画面に合わせて表示します（1.4 から）。」（案 B のときは「画面の幅に合わせて表示します」）。
- **Pencil の文は、本人の Duo で確かめられたときだけ**足す（確かめ表の行 19 と 20 が ○。新機能の文の行 2 と同じ条件）: 「iPhone Duo では iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かします。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。」確かめていない動きは書かない。入れる所は同じ節の「手書きは指で書きます（ツールバーの「指でも書く」）。」（`docs/SUPPORT.md:123`）のすぐ後（その文はふつうの iPhone の話として残す）。英語の `SUPPORT.en.md` も同じ所。
- 公開のスクリプトの確かめ（1.3 の `release13.py web` の形）に「Web の SUPPORT 2 ページが新しい文になっている」を入れる。

### 8.5 アプリの文

- 画面の日本語の文は 1 字も変えない（L-3）。新しいキーも無い。例外は N-3 の 1 文だけで、本人が確認ページで「変える」を選んだときだけ（§1.5、0d-43）。
- 8 キーの comment は §1.5 (a)。`app-U.json` を直し、`build.py` で xcstrings を作り直して同じ commit に入れる（CI の「Localized bundle check」が見る）。

---

## 9. 段取り・役・出し方

### 9.1 段と目安の日（2026-11-20 時点。M7D.md に実績を書いて直す）

CI の時間の見込み（1.3 の最後の run 44474759145 のジョブの時間 [S59]: build-and-test 72.2 分・span-shots-app 65.9・blank-paper 41.0・l10n-shots 39.2・ui-tests 26.4・compat-v1.0 13.2）: build.yml は 6 つのジョブのうち 5 つが同時に動き、1 つが待つので、**1 回 75〜95 分**。同時の上限は 5 [S55] なので、ほかの workflow は build.yml の後に 1 つずつ（§3.10）。D0 の日は build.yml → ja-baseline → testflight → duo.yml で、**通しで 4〜5 時間**。D1 は統合の run（build.yml と duo.yml）と、変異の枝 2〜3 回で、**1 日に 3〜4 回**が限り。

| 段 | 目安 | 中身 | 関門 |
| --- | --- | --- | --- |
| S0 | 11/20 | この契約・枝 `r14`・M7_PLAN §4.5 の頭の注・M7D.md の前もっての宣言（§3.7）・ff4e3c4 の記録の写し | — |
| S0' | **11/20** | **955fe67 の run 44474759145 の成果物 6 つを全部 `~/.local/share/tegaki-backup/1.4/` に控える**（11/26 の 16〜17 時（日本時間）に消える、§3.6）。年齢区分の 2 問を版なしで API から（§9.5 の 1） | 控えの数と大きさを M7D.md に。読み戻し |
| D0 | 11/20〜11/21 | §3.3（Xcode だけを替える。XcodeGen の固定と `TESTS_1_3`・`FIXTURES_1_3` を含む）→ build.yml → ja-baseline（同じ UTC の日）→ testflight（試しに上げる、配らない）→ duo.yml（duo-probe）。SDK の差の地図（関門 7）。VALID の後、Connect に版 1.4 の入れ物を作る（年齢区分の 2 問の 2 の道、§9.5） | §3.3 の関門 1〜8 |
| D0b | 要るとき | SDK の差の直し（§3.3） | 同じ |
| D1 | 11/21〜11/23 | §1.3 の 4〜10（5b の Duo の Apple Pencil を含む）。役ごとに並べて作る。Kit と純粋な関数の変異は手元の KitChecks で先に済ませる。統合の枝で build.yml と duo.yml を回し、アプリと UI の変異は `r14-q-m1`・`r14-duo-m1` にまとめる。ふだんは `r14-quick` | 全部のジョブが緑。J-4 は §3.5 の 1 枚だけ。§6 の変異が落ちることを確かめた。KitChecks の新しい数と閾値。`usesHinge` と `formSheetOnWide` の答え（§4.2・§4.4） |
| D2 | 11/21〜11/23（D1 と並べる） | 店の文の訳と逆翻訳（§8.1 の全部の行）・審査メモ・SUPPORT・Duo の店の写真（store-shots の Duo の組）・`shots14.py`・確認ページ（SDK の差の前と後の写真と、N-3 の選びを含む） | 確認ページがそろう |
| 判断 | **11/22 の夜** | D1 が全部のジョブで緑で、D2 の確認ページがそろう見込みなら早い道（D3 を 11/23）、そうでなければふつうの道。**早い道は、D0・D1 のどの run も 1 回目で通ったときだけで、見込みは低い**。本人に知らせる | — |
| D3 | 早い道 **11/23（祝）**、ふつうの道 11/26〜11/27 | TestFlight 1.4 の候補を内部のテストに配る（D0 のビルドでないこと）。確かめ表（§10）と確認ページ（§9.4 の 3）を同時に渡す。ふつうの道では、その前に D1 を仕上げる | D1 の関門 |
| D4 | 早い道 11/23〜11/24、ふつうの道 11/28〜11/29（週末）に確かめ、11/30〜12/1 に提出 | 本人の確かめ表（Duo の行を含む）・「この内容で入れてよい」・「1.4 を審査に提出して良い」→ 新機能の文の行を決める（§8.1）→ Connect に入れて読み戻し（Duo の写真は提出の前だけ、§7.2）→ 提出（§9.4 の 7） | 確かめ表が全部 ○（Duo の行は ○ か「—」） |
| D5 | 提出の後 2〜5 日 | 審査が通ったら「1.4 を公開して良い」→ 公開 →「まとめて良い」→ main へ（`--no-ff`） | — |
| 前ぶれ | **12/10** | 提出できていなければ本人に知らせる | — |
| 決まり | **12/18** | 年末の前の最後の提出日。過ぎたら 1/5〜1/8（年齢区分の期限 1/12 の前。§9.5 の 4） | — |
| 計画の期限 | 2027-03-15 | 遅くとも提出（M7_PLAN §4.5） | — |

- Duo の写真が提出の時までにそろわないとき（§4.2 の道 3 で外側も撮れない、§7.1）は、写真を待たずに出す（§12 の 0d-23）。写真は次の版の提出の時に足す（置き場所は直せる版にしか作れない、§7.2）。新機能の文を待たせる物は無い（全部の行の訳を先に作る）。本人の Duo の行が × なら、直してビルドし直す（Duo は 1.4 の中心なので、× のまま出さない）。「—」（Duo が手元に無い）なら、行 2 と SUPPORT の Pencil の文を入れずに出す。
- 作業の木はスクラッチパッド（`/private/tmp` の下）にあり、毎日 0:00 の掃除で古いファイルが消えうる。こまめに commit し、リードが `r14` を GitHub に上げて控えを残す。
- Claude の週の使える量が 95% に届いたら、その週は止まる。進み具合は M7D.md に残し、止まっても再開できるようにする。

### 9.2 規模

| 部分 | 里程 | 元 |
| --- | --- | --- |
| D0（CI の切り替え・アーカイブの確かめ・J-4 の基準・SDK の地図・duo-probe） | 0.1〜0.15 | この契約 |
| Duo のコード（窓の広さで決める 3 つ・倍率 2 つ・測り）とテスト | 0.15〜0.2 | M7_PLAN §4.5（0.8〜1 の中の Duo の分） |
| Duo の Apple Pencil（Kit の `FingerDefault` と KitChecks の表・`PencilPhone` のつなぎ・折り目の見張り・端末の印・札の出し直し）とテスト | 0.08〜0.12 | §4.8（本人の決定で足した。第 2 版で H・端末の印・戻しを足した。新しい文は無い） |
| 本物の 1.3 の相手・`TESTS_1_3`・`FIXTURES_1_3`・`idiom_check`・XcodeGen の固定 | 0.1〜0.15 | CODE_SURVEY §4.2 |
| 1.3 の確かめ直し（Xcode 27 での全部のジョブ、Duo の窓と上限、KitChecks「duo (1.4)」） | 0.15〜0.2 | M7C_CONTRACT §14 の 0.2〜0.3 のうち、CI が自動で済ませる分を引いた |
| 1.3 の残り | 0.03 | §1.5 |
| 店（Duo の写真・`shots14.py`・文・訳・確認ページ） | 0.15〜0.2 | 1.3 の実績 |
| **合計** | **0.8〜1.1** | 1 里程 ≈ 1.5 週だが、1.2・1.3 の実績はずっと速い。日程は CI（1 回 75〜95 分、同時の上限 5 で順番待ちあり、§9.1）・本人の確かめ・審査が律速 |

### 9.3 役

| 役 | 仕事 | 持ち物 |
| --- | --- | --- |
| C | CI・Xcode・XcodeGen の固定・機種・`duo.yml`・互換（v13）・`TESTS_1_3`・`FIXTURES_1_3`・`idiom_check`・`shot_checks.py`・版・store-shots の Duo の組 | §2 の C の行 |
| K | KitChecks「duo (1.4)」と `--span-state`・Kit の注（`SpanPlan` の規則は変えない） | §2 の K の行 |
| S | Kit の `WindowClass`・`FingerDefault` と KitChecks「window & finger (1.4)」・`PencilPhone`（つなぎ）・`AppSettings` の鍵・`CalendarRootScreen` の直し・`ScreenPaths` の Device と makeSession・`SpanSession` の口・`DuoFoldTests` ほか | §2 の S の行 |
| P | `PaperView` の倍率 | §2 の P の行 |
| U | シート・写真モードの測りと `--screenshot-pencil-phone`・Duo の UI テスト・注 | §2 の U の行 |
| X・R | 店の文の訳・元を見ない逆翻訳・8 キーの comment | `tools/l10n/source/app-U.json`・`docs/i18n` |
| A・W | 新機能の文・審査メモ・SUPPORT | `docs/store/`・`docs/SUPPORT*.md` |
| リード | 順番・確かめ・M7D.md・Connect（年齢区分・版 1.4・写真・文・提出・公開）・本人への知らせ | — |

### 9.4 出し方（本人の言葉が要る所。一覧は §0.4）

| 順 | だれ | すること | 本人の言葉 |
| --- | --- | --- | --- |
| 1 | 各役 | この契約のとおりに作り、`r14` に commit | 不要 |
| 2 | リード | `r14` を GitHub に上げ、CI が全部緑。D0 のビルドは配らない | 不要 |
| 3 | リード | 確認ページ（新機能の文 16 ロケール・Duo の写真（撮れたとき）・SUPPORT の変わる所の日英・審査メモの 1.4 の段と日本語の要約・SDK の差の前と後の写真（§3.6）・N-3 の選び（§1.5、既定は今のまま）） | 「**この内容で入れてよい**」（N-3 は選んだときだけ） |
| 4 | リード | testflight.yml を `r14` で走らせ、TestFlight 1.4 の候補を内部のテストに配る。確かめ表（§10）を番号付きで渡す（3 と同時でよい） | 不要 |
| 5 | 本人 | 確かめ表 | 「全部○」か×の所 |
| 6 | 本人 → リード | 提出のお願い | 「**1.4 を審査に提出して良い**」 |
| 7 | リード | Connect の版 1.4（D0 の後に作った入れ物）に 16 ロケールの新機能の文・プロモーションテキスト・審査メモ・Duo の写真（`shots14.py`）・ビルド（D0 のビルドでないことを確かめる）を入れて読み戻す。年齢区分の 2 問がまだなら入れる。手動公開で提出 | 2 問が API で入らないときだけ「押した」の返事 |
| 8 | 本人 → リード | 審査に通ったら公開。同じお願いで、main へまとめてよいか | 「**1.4 を公開して良い**」と「**まとめて良い**」 |
| 9 | リード | 公開の後、Web の SUPPORT 2 ページ、日本の App Store の表示が 1.4 になったことを M7D.md に。`r14` を main に `git merge --no-ff`、main の CI を見る。本人の手元の main を `pull --ff-only` | — |

- 公開は、本人の確かめ（5）と本人の言葉（8）の後だけ。言葉は前もってもらってもよい（1.2.4 の「三つともYes」、1.3 の 11/19）。
- × が出たら、直してビルドし直し、確かめ直す（提出の後なら審査から取り下げる）。
- **Duo の写真が確認ページに間に合わないとき**: 確認ページは 1 回のまま、写真の行は「1.4 では入れない（次の版で足す）」と書いて見せる。後から撮れても 1.4 には入れない（本人が見ていない写真を入れない。置き場所は 1.4 の提出の前にしか作れないので、次の版（1.4.1）の提出の時に、その版の確認ページで見てもらってから足す。§7.2）。

### 9.5 年齢区分の新しい 2 問（期限 2027-01-12）

（§1.3 の 12）

- 事実: 2 問（Shared Location・Dating and Relationships）は、**App Store Connect API 4.6.1（2026-11-18）**で `AgeRatingDeclaration` の `sharedLocation`・`datingAndRelationships`（boolean）として入った。`PATCH /v1/ageRatingDeclarations/{id}` で入れる [S20][S23]。期限は 2027-01-12。「更新を出すときに答える」とも書かれている [S11]。答えは今のところブラジルの区分にだけ効く [S20]。
- 答え: **2 問とも「いいえ」（false）**。このアプリは位置を共有せず、出会いや交際の機能も無い（M7B.md:2001 と同じ）。4+ のまま。
- 手順:
  1. **11/20〜11/21（S0'）**: 公開中の App 情報の `ageRatingDeclaration` に PATCH し、読み戻す。入れば終わり（M7D.md に記録）。
  2. 1 が断られたら（直せる状態の App 情報が無い）: D0 の VALID の後に Connect に版 1.4 の入れ物を作り、それと一緒にできる直せる App 情報の `ageRatingDeclaration` に PATCH して読み戻す。1.4 の提出で一緒に出る。
  3. API がどちらも断るときだけ、本人に Connect の画面で 1 回の操作をお願いする（画面の言葉はその時に合わせて書く。§0.4）。
  4. 1.4 を 12/18 までに出せないときは、1/5〜1/8 に、1.4 か、1.3 と同じコードを Xcode 27.2 で作った小さな版（番号はそのときに決め、中身の名前で知らせる）で出す。

### 9.6 中国の 2027 年の祝日（条件つき）

（§1.3 の 13）

- 事実: python-holidays の最新は **0.109（2026-11-17）**。`china.py` の調整の表の最後は 2026 年で、**2027 年は 0.109 にも開発の枝 `dev`（83be068、11/19）にも無い**。PR も issue も無い（11/20 に検索）[S45][S46]。去年は通知の約 1 週間後に入った（PR #3052、2025-11-12）[S48]。中国政府の通知は 2026-11-05（春節 2/5〜2/13 など）[S49]。0.108 から Python 3.11 以上が要る [S47]（手元の 3.12.16 は満たす）。
- 既定: D3（TestFlight の候補）の前に、2027 年の中国を含む**正式版**が出ていれば、本人に取り寄せの了承を聞き（§0.4 の問い 1 で前もってもらえていればそれで）、`tools/holidays/README.md:57-70` の手順で入れる（`requirements.txt` の版と hash、`TegakiKit/HolidayData/*.json`・`SOURCE.json`・`index.json`、`HolidayDataLicense.swift:11`・`:41`、`HolidayChecks.swift` の中国の最後の公式の年 `:175-190` ほか、`WorldHolidaysTests.swift`、`gen.py:97`）。版を上げるとほかの国のデータも変わる（0.108・0.109 の変更 [S47]）ので、変わった国の数と中身を M7D.md に書き、KitChecks の数と閾値を直す。新機能の文に中国の 1 行（§8.1）。
- 1.4 の提出の後に入ったら: 春節の前（1/20 ごろまで）に、祝日のデータだけの小さな版を出す（0d-26）。それより後なら次の版。
- 確かめは CI の祝日のデータのテスト。本人の確かめ表には入れない（祝日を中国にしている人だけに出る所で、データだけの変更のため。M7C_CONTRACT §9.3 と同じ）。

---

## 10. 本人の確かめ表（TestFlight 1.4）

**対象の版: 1.4（TestFlight。ビルドの番号は Claude が渡すときに書きます）**。この表は、ビルドが本人の端末に届いた後に、番号を書いて改めて渡します。上から順に ○ か ×。× のときは画面の写真を送ってください。

**準備**: 全部の端末（iPad Pro 13・iPad Air 11・iPad mini・iPhone、あれば iPhone Duo）に、TestFlight で 1.4 を入れてください。iPhone Duo は、設定 › 一般 › 情報 で iOS が 27.2 以上か見て、低ければ先に更新してください（Apple Pencil は iOS 27.2 から）。Apple Pencil（USB-C）は Duo と使えるようにつないでおいてください（つなぎ方は Apple の案内のとおり）。Duo が手元に無いときは 18〜27 を「—」にしてください。TestFlight で「閲覧専用」と出たら、TestFlight の中で購読し直してください（無料。1.2.4 のときと同じで、TestFlight の購読の決まりによるものです）。**「全て消す」と Apple アカウントの切り替えはお願いしません。**

| # | 端末 | すること | こうなれば合格 |
| --- | --- | --- | --- |
| 1 | 全部 | アプリの右上の ⚙（設定）› 情報 で「バージョン」を見る | 1.4（括弧の中は Claude が知らせたビルドの番号） |
| 2 | iPad Air 11 | 月・週・日・年のページを順に開く。＋（予定を作る）と ⚙（設定）も開いて、保存せずに閉じる | 紙・線・字が 1.3 と同じ。ボタンやシートの形が少し違うのは、確認ページに載せた「前と後」の写真の範囲ならかまいません（iOS 27 の部品の形）。ボタンが隠れる・押せない・字が切れるときは × |
| 3 | iPad Air 11 | 週のページを指で横にすべらせ、日曜の夜から月曜の朝へ Apple Pencil で 1 本の線を書く | となりの週が続いて出てくる。線が途中で切れない |
| 4 | iPad Air 11 と iPad mini | Pencil で書きながら、手のひらを紙に置く | 紙が横に動かない |
| 5 | iPad Air 11 | 週のページを指で横にはじく。次に、ゆっくり動かして止める | はじくと、となりの週でぴたりと止まる。ゆっくりなら止めた所で止まる。止まった後に見た目が動かない |
| 6 | iPad Air 11 | 指を斜めに動かす | 紙は上下か左右のどちらかにだけ動く |
| 7 | iPad mini | 縦と横の両方で、週と日のページを横にすべらせ、境目をまたいで書く | 3 と同じ |
| 8 | iPad Air 11 | 日のページの 24 時の下（自由メモ）で、前の日から次の日へ続けて書く | 続けて書ける |
| 9 | iPad Pro 13 | Apple Pencil のダブルタップ（かスクイーズ）で、ペンと消しゴムを切り替える（設定 › Apple Pencil で切り替えにしているときだけ） | 1.3 と同じに切り替わる |
| 10 | iPhone | 週のページで、指 1 本で書く。2 本指で横に動かす | 書ける。2 本指で、となりの週が出てくる |
| 11 | iPhone | 横にして、2 本指で週と日をいちばん縮める | 週は 3 週、日は 5 日が横に並ぶ（1.3 と同じ） |
| 12 | iPhone と iPad Pro 13 | 年のページで日付をタップする | その日のページが開く |
| 13 | iPad Air 11 | 投げなわで線を囲み、「予定にする」を押す。予定の画面の線の絵を見て、保存せずに閉じる | 線の絵がぼやけずに出る |
| 14 | iPhone | ＋（予定を作る）を押す。保存せずに閉じる | 予定の画面が下まで見える |
| 15 | iPad Air 11 | 週のページの PDF を書き出す | 1.3 と同じに出る |
| 16 | iPad と iPhone | 片方で書き足し、もう片方を開く | 書き足した線が届く。上の印は「保存済み」 |
| 17 | どれか 1 台 | 機内モードにして書く → 機内モードを切って開き直す。そのあとアプリを完全に閉じて（下の端から上へゆっくり指を動かして止め、てがきカレンダーの絵を上へ払う）、開き直す | 書いている間は「オフライン」、戻すと「保存済み」。開き直しても書いた線が全部残っている。「別の iCloud アカウントです」は出ない |
| 18 | iPhone Duo（開いた画面） | 開いて、月・週・日・年のページを順に開く | 紙が大きな画面いっぱい（真ん中に小さくならない）。上の見出しは 1 段 |
| 19 | iPhone Duo（開いた画面）と Apple Pencil | 週のページに Pencil で書く。指 1 本で紙を横にすべらせる。ツールバーの「指でも書く」を見る（見えないときは、ツールバーを指で横にすべらせる） | Pencil で書ける。指では線が出ず、紙が動いて、となりの週が出てくる。「指でも書く」はオフ（1.4 から新しく入れた Duo では、開いてすぐにオフです。1.3 から更新した Duo は、Pencil で最初の 1 本を書き終えたときにオフに替わります。そのとき案内の札は出ません。ツールバーの「指でも書く」のボタンの色が変わります） |
| 20 | iPhone Duo（開いた画面）と Apple Pencil | 手のひらを画面に置いたまま Pencil で書く | 手のひらで線が出ない。書いている間、紙が横に動かない |
| 21 | iPhone Duo（開いた画面）と Apple Pencil | 月のページに Pencil で書く。指で紙を上下に動かす | Pencil で書ける。指では線が出ず、紙が動く |
| 22 | iPhone Duo（開いた画面） | 年のページで、日付を指でタップする | その日のページが開く |
| 23 | iPhone Duo（開いた画面） | 週のページを指で横にはじく | となりの週でぴたりと止まる |
| 24 | iPhone Duo（閉じた外側の画面）と Apple Pencil | 閉じて、外側の画面で Pencil で書き、指で紙を動かす。ツールバーを指で横にすべらせて「指でも書く」を見る（外側の画面ではツールバーが狭く、このボタンは右の端の外にあります） | 19 と同じ（外側の画面で Pencil が使えないときは、その旨を書いて「—」） |
| 25 | iPhone Duo | 開いた画面で週のページに書く。閉じて外側で見る。また開く。最後に、Pencil で書きながら閉じる | 閉じても開いても同じ週と線のまま。書きながら閉じたとき、それまでに書いた線は残っている（書きかけの 1 本は消えることがあります。月や年のページで拡大していると、閉じたり開いたりした後に見ていた所が少し横にずれることがあります。前からの動きです） |
| 26 | iPhone Duo（開いた画面を横にして） | 週のページを 2 本指でいちばん縮める | 3 週ほどが横に並び、1 日の上から下（0 時〜24 時）がほぼ見える（ふつうの iPhone の横のように、今の時刻のあたりからにはならない） |
| 27 | iPhone Duo | ツールバーの「指でも書く」をオンにして指で書く（見えないときは、ツールバーを指で横にすべらせる）。オフに戻す | オンのとき指で書ける（紙は 2 本指で動く）。オフに戻すと 19 と同じ |
| 28 | 全部 | アプリを完全に閉じて開き直し（17 と同じやり方）、手書きのあるページ（月・週・日・年）を順に開く | 書いた線が全部見える。一部の線が欠けて見えるときは、そのページの写真を送り、指で紙を少し動かすと出てくるかも書いてください |

---

## 11. 危険と減らし方

| 危険 | 減らし方 |
| --- | --- |
| `xcode-27` の環境が不安定（実行環境が外れる #15334、配り中の新しい環境） | 1 回だけ走らせ直し、環境の版を記録（§3.8）。J-4 は同じ日・同じ環境の版の組だけで合否（§3.5） |
| 27.3 beta を正式版と取り違える（20261119 の別名 `Xcode_27.3.app`） | Xcode は `xcodebuild -version` の Build の字で選ぶ（§3.1）。アーカイブの確かめでも見る（§3.4） |
| 27.3 の正式版で 27.0 の実行環境が消え、`iPad mini (A17 Pro)` が無くなる | 必須の機種の確かめで落ちて気づく。A20 Pro へ移し、J-4 の基準を撮り直す（§3.2） |
| 機種が無いのに黙って飛ばされる（6.9 インチが全部飛ぶ） | 必須の機種の確かめで落とす（§3.2） |
| CI の同時の上限（macOS 5）で待たされ、日程が延びる | Duo のジョブは別の workflow（`duo.yml`）で、`r14` の push では走らせない。D0 は順に。Kit と純粋な関数の変異は手元。アプリと UI の変異は 1 本の枝にまとめる（§3.10）。早い道は見込みが低いと書いた（§0.3・§9.1） |
| XcodeGen の版が環境で変わる（Homebrew の formula の写しで決まる） | 版と sha256 を決めた公式の zip（2.46.0）を 9 か所で（§3.3 の 4） |
| 新しい SDK で保存のバイトが変わる（Foundation の JSON） | §3.3 の関門 2・§5.6。違えば止める。fixture は作り直さない。`FIXTURES_1_3` で守る |
| 新しい SDK でレイアウトの数が変わる | span-shots-app の状態の行を、紙の領域が同じなら同じ数、違えば Kit で計算し直して比べる（§3.3 の関門 3） |
| 新しい SDK で操作部品が隠れる・重なる（J-4 は同じ道具どうしなので捕まえない） | SDK の差の地図を D0 の関門にし、前もって決めた切り抜きで部品が全部見えるかを見る。説明のつかない強い差は止める（§3.6）。確認ページに前と後の写真 |
| 新しい SDK で PencilKit・手のひら・シートの動きが本人の端末で変わる | §3.6、確かめ表の 2〜8・13・14 |
| 1.3 のテストや fixture を書き換えて通す | `TESTS_1_3`・`FIXTURES_1_3` を D0 の commit で（§5.5） |
| 古い木（1.0・1.2.3・1.3）が Xcode 27 で作れない | compat-v1-0 を macos-26・Xcode 26.6 に残す（§3.9） |
| Kit の新しいコードが Swift 6.3 で通らない（compat-v1-0 が今の Kit をビルドする） | Swift 6.4 だけの物を Kit に入れない。落ちたらまずここ（§3.9） |
| `macos-26` から Xcode 26.6 が消える | 選べなければ落として気づく。そのときに決める（§3.9） |
| Python の版が途中で変わる | 版を記録して見張る（§3.8） |
| Mac Catalyst の typecheck が iOS 27.1 の API で落ちる（185924957） | `#if !targetEnvironment(macCatalyst)`（§3.8） |
| Duo の内側を CI で開けない（見込みが高い） | 既定を道 3 にした（§4.2）: 外側だけの写真・シートは今のまま・案 B。内側は本人の Duo で見る |
| Duo の pt が推定と違う | 測ってから KitChecks に（§4.2・§4.6） |
| Duo の起動直後の黒い写真 | 180 秒待ち、明るさで確かめて撮り直す（§3.8） |
| 内側の横で上限が効いたり効かなかったりする（終日帯のレーンで紙の高さが変わる） | 上限は紙でなく窓の短い辺で決める（§4.7）。帯が 35 % のときの行も KitChecks に |
| **ふつうの iPhone を Duo と取り違える**（Mac の iPhone ミラーリングで窓を広げる） | 窓の広さ（W）を入力に使わない。P（Pencil の触れ）と H（折り目）だけ（§4.8）。H は CI で Duo だけ nil でないと測れたときだけ使う（§4.2） |
| **バックアップ・機種の移し替えで「指でも書く」のオフが Pencil の無い iPhone に運ばれる** | 印を端末に結びつける（`identifierForVendor`）。ほかの端末でアプリがオフにした値は、折り目の無い端末で 1 回だけオンに戻す（§4.8）。本人がオフにした値は運ばれたまま（本人の選び。ツールバーで戻せる。1.3 と同じ） |
| `identifierForVendor` が TestFlight と App Store の入れ替えで変わるか【未確認】 | 変わると「移ってきた」と読む。オフなら折り目で守る（rebind）か、1 回オンに戻して Pencil の次の 1 本でまたオフ。線やデータには触れない |
| Pencil を持たない Duo の人が、開いた画面で初めて入れて指で書けない | 初めての案内の 3 枚目とツールバーの「指でも書く」で iPad と同じ道がある（§4.8）。1.3 から更新した人・移ってきた人は Pencil が触れるまで替えない |
| 1.3 から更新した Duo の人が、Pencil の初めての 1 本の後に指で書けなくなって戸惑う | 本人の決定（Duo は iPad と同じ）。初めての案内の 3 枚目と同じ動き。ツールバーのボタンの色が変わる。札は出さない（最初の文が 1.3 の人には合わない、§4.8）。ツールバーで戻せる。1.4 で本人が切り替えたことがあれば替えない |
| 触れの見張りが、書く・動かす・タップを邪魔する | 凍結の `InkTouchObserver`（1.3 からキャンバスで使っている、何も認識しない形）を窓にもう 1 つ付けるだけ。iPad には付けない。作り物の触れの単体テスト（§6）と本人の Duo（§10 の 19〜21・27） |
| 線の途中で「指でも書く」が替わる | 全部の触れ（Pencil・指・ポインタ）が離れた時だけ替える（§4.8）。PencilKit の方針は次の線から効く（`InkCanvasView.swift:922-926`） |
| シミュレータで Pencil の触れを作れず、P の道を CI の UI テストで通せない | Kit の表（手元でも走る）と、作り物の触れで凍結の見張りを動かす単体テスト（§6）と本人の Duo。× なら直してビルドし直す |
| Duo の手のひらの見分け（ホバーなし [S54]）が iPad より弱い【未確認】 | 「指でも書く」オフで手のひらは線にならない。紙が動くのは Pencil が着く前だけ（iPad と同じ規則）。§10 の 20 で見る。直しが凍結に及ぶなら止める |
| 外側の画面で Pencil が使えない【未確認】 | 指で動かし、「指でも書く」で指でも書ける（iPad と同じ道）。§10 の 24 で見て、新機能の文と SUPPORT は確かめた所だけ |
| 開閉で、1 ページの道の見ていた所が少し横にずれる（凍結の読み違い） | 受けて記録（§1.5）。1.4.1 で凍結の表を作り直すときに直す。確かめ表 25 に書く |
| 内側のフォームシートが崩れる | 内側を撮れて確かめたときだけ（§4.4）。既定は今のまま |
| 初めて開くページを幅で決めるときにちらつく | 決まるまでキャンバスを作らない（§4.3） |
| 書きながら閉じたときに書きかけの 1 本が消える | Apple の動きとして受け、確かめ表 25 で見る。直しが凍結に及ぶなら止める（§4.9） |
| 凍結のファイルを直したくなる | 例外の手順だけ（§5.4）。行 12〜20 は例外なし |
| iOS 17 で起動しなくなる（新しい SDK の物を弱いリンクなしで使う） | アーカイブの確かめ（§3.4）、iOS 17 の試し（§6 の最後）。`UIHingeInteraction` は `#available` の中だけ |
| Duo の写真の API（Asset Library）が新しく、前の API は非推奨 | 新しいスクリプトで上げて、`specId` まで読み戻す（§7.2） |
| Duo の写真の置き場所は、直せる版にしか作れない | 1.4 の提出の前に入れる。遅れたら次の版で（§7.2・§9.1） |
| Duo の写真の決まりがあいまい（両方要るか、全部のアプリか） | 厳しい方に合わせて、撮れる物を 16 ロケール（§7.1） |
| iOS 27 SDK の義務の日付が未発表 | 12 月の初めに出す。3/15 まで余裕 |
| 新しい Xcode が出た日に Connect で断られる（27.2 で約 19 時間） | 出た日に替えない（§3.1） |
| 年齢区分の 2 問が API で入らない | 版 1.4 の入れ物で。だめなら本人に画面で 1 回（§9.5） |
| 年末の審査の遅れ | 12/18 までに提出。過ぎたら 1/5〜1/8（§9.1） |
| TestFlight の「閲覧専用」 | 確かめ表の準備に書いた。D0 のビルドは配らない（§3.3） |
| 955fe67 の写真が 11/26 に消える | 11/20 に 6 つ全部を控える（§3.6・§9.1 の S0'）。だめなら撮り直す |
| 中国の 2027 年の祝日がまだ無い | 条件つき（§9.6）。春節（2/5）の前に小さな版を出せる道を残す。版を上げるとほかの国も変わることを本人の問いに書いた（§0.4） |
| Claude の週の使える量の上限 | 12/18 まで 3 週以上の余裕。M7D.md に進み具合 |
| 作業の木が夜中の掃除で消える | こまめに commit、リードが GitHub に上げる |

---

## 12. 決めどころ（既定と理由。番号は 0d-n）

| # | 決めどころ | 既定 | 理由 |
| --- | --- | --- | --- |
| 0d-1 | Xcode の版 | **27.2**（27B52）。27.1（環境の既定）でも 27.3 beta でもない。`xcodebuild -version` の Build の字で選ぶ。新しい Xcode が出た日には替えない | 同じ環境にある正式版で一番新しい。10/30 から提出に使える [S14]。Duo の Pencil は iOS 27.2 から [S19]。27.1 の実行環境は Duo だけ [S29]。計画（27.1）を書いた時には 27.2 が無かった。27.2 は公開の直後の約 19 時間 Connect に断られた [S57]。20261119 の環境は 27.3 beta に正式版のような名前の別名を作る [S56] |
| 0d-2 | 実行機 | `xcode-27`。**compat-v1-0 だけ `macos-26`・Xcode 26.6** | GitHub は GA と告知 [S34]。標準の実行機で、公開リポジトリは無料 [S36]。古い木は作った道具で（§3.9） |
| 0d-3 | 機種 | §3.2 の表（6.9 インチは iPhone 18 Pro Max、mini は A17 Pro の 27.0、Duo は 27.2 を UDID で）。27.0 が消えたら mini は A20 Pro へ | 今の名前が無い [S29]。mini は本人の端末と 1.3 の数に近いまま。方針は x.y を 3 つまで [S28] |
| 0d-4 | J-4 の基準 | 955fe67 を Xcode 27.2 で撮る（`ja-baseline-ref-1.4.txt`） | 同じ道具どうしでないと、コードの差と道具の差を分けられない（CODE_SURVEY §6 の 8）。SDK の差は 0d-5 で別に見る |
| 0d-5 | SDK の差の扱い | **D0 の関門 7**（§3.6）。組 3 は前もって決めた切り抜きで操作部品が全部見えること。組 4 は説明のつかない強い差で止める。確認ページに前と後 | J-4 は同じ道具どうしなので、SDK による悪化を捕まえない（C4）。本人の端末はもう iOS 27.2 |
| 0d-6 | D0 のビルド | 配らない（自動で配られるなら期限切れに） | 「閲覧専用」の手間を 1 回にする。中身が 1.3 と同じ物を本人に確かめてもらう意味が無い |
| 0d-7 | Duo の機種の分け方 | `.iPhone` のまま。新しい行は作らない | 測った紙の領域で窓が広がる。KitChecks の窓の表と門を変えない |
| 0d-8 | Duo の一覧の上限 | **広い窓（短い辺 600 以上）の横の道の窓には上限をかけない**（窓の plan の `overviewCap` を外す。`SpanPlan` の規則は変えない）。外側の横は今の iPhone 横と同じく上限あり（§4.7） | 本人の決定「幅が許す所は iPad と同じ」。紙の高さでなく窓で決めるので、終日帯のレーンで揺れない（C12）。今の iPhone の答えは 1 つも変わらない。`atCappedOverview` と今日を開く高さが変えずに付いてくる（C1） |
| 0d-9 | 初めて開くページ | 広い窓（短い辺 600 以上）で月（窓の大きさが来た時に 1 回、開閉で替えない。`appear` との順に依らない） | M7_PLAN §6.2。幅で見るとふつうの iPhone の横が月になる。今の利用者には効かない |
| 0d-10 | 「指でも書く」の既定（Duo） | **本人の決定でオフ（iPad と同じ）**。決め方は §4.8 の表（`FingerDefault`）。新しい文の案内は足さない | 本人の決定（11/20）。新しい文と訳を要さない |
| 0d-11 | 年の 44 pt の的 | 変えない（Duo も iPhone のまま） | Duo の既定（オフ）では、もともと iPad と同じ的になる（`DateTap`）。凍結のテスト |
| 0d-12 | シートの形 | iPad、または（`formSheetOnWide` かつ広い窓）でフォームシート。`formSheetOnWide` の既定は false。内側を撮れて (a)(b) が ○ のときだけ true（§4.4） | 今の機種は 1 つも変わらない。内側を撮れない見込みが高い（F5）ので、確かめていない見え方を出さない |
| 0d-13 | Scribble の注・設定の Pencil の行と脚注 | 変えない（Duo でも iPhone のまま） | Duo の Pencil（USB-C）にダブルタップ・スクイーズ・筆圧・バレルロールは無く、Duo ではホバーも無い【事実 [S54]】。文を変えると訳。iPhone の Scribble・Duo の「設定 › Apple Pencil」は【未確認】 |
| 0d-14 | 倍率 | 呼ぶ側で `displayScale`、`PaperView` は特性の変化でも（値が同じなら何もしない） | 凍結の `InkSnapshot` を変えない。`PaperViewTests` の数を変えない |
| 0d-15 | 凍結の 20 行 | 変えない。行 1〜11 は SDK が強いたときと Duo の開閉の直しだけ例外の手順、行 12〜20 は例外なし（§5.4） | 1.4 はデータのコードに触れない版。例外の道を先に決めて、止まらずに進める |
| 0d-16 | `SpanGuard.prototype` | 残す | 消すと表の作り直しと KitChecks の数の変更。次に表を作り直す版で |
| 0d-17 | 1.3 のテストと fixture の表 | `TESTS_1_3.sha256`・`FIXTURES_1_3.sha256` を **D0 の commit で**、955fe67 の blob から（§5.5） | 新しい SDK で落ちたテストや fixture を書き換えて通すことを、D0b より前から防ぐ（C5） |
| 0d-18 | 本物の 1.3 の相手 | 足す（Probe と、1 ページの道・同期・横の道の台帳のテスト。バイトの比べは compat-span だけ） | M7C_CONTRACT §6.4・S6 の決定 3。1.3 の利用者の既定は横の道。compat11 は移す見本があるのでバイトが同じにならない（C10） |
| 0d-19 | 端末の種類の見張り | `idiom_check.py` を足す（§4.1） | 1.5 から先で `UIScreen.main` や idiom の判断が戻らないように |
| 0d-20 | 1.3 の残り (a)(b)(c) | 1.4 で片づける（§1.5）。`SpanChecks.swift` の注は直さない | どれも小さく、凍結の外。`SpanChecks.swift` は `TESTS_1_3` で守る |
| 0d-21 | zh のトーストの語・1.2 の訳の持ち越し | 変えない | 文を変えない版 |
| 0d-22 | 新機能の文 | 行ごと（§8.1）。行 1 は開閉を確かめられたら案 A、でなければ案 B。行 2（Duo の Pencil）は本人の Duo の 19・20 が ○ のときだけ | 確かめていない動きは書かない |
| 0d-23 | Duo の店の写真 | 外側と、撮れれば内側の縦 5 枚 × 16 ロケール（既定の道 3 では外側だけ）。そろわなければ 1.4 は写真なしで出し、**次の版の提出の時に足す**（置き場所は直せる版にしか作れない [S26]） | 4 月からの決まりに間に合えばよい。1.4 を写真待ちで遅らせない |
| 0d-24 | 今の店の写真 | 撮り直さない | 今の機種で画面が同じ |
| 0d-25 | 年齢区分の 2 問 | API で 2 問とも false（§9.5） | API 4.6.1 で入った [S20] |
| 0d-26 | 中国の 2027 年の祝日 | 正式版に入れば、了承を聞いて入れる（ほかの国のデータも変わることを問いに書いた）。1.4 の提出の後に入ったら、春節（2027-02-05）の前に祝日のデータだけの小さな版を出す（番号はそのとき、中身の名前で知らせる）（§9.6） | 今は 0.109 にも dev にも無い [S46]。取り寄せは毎回本人の了承が要る（`tools/holidays/README.md:61`） |
| 0d-27 | ペンの色・メモ欄の紙 | 1.4.1（§1.4） | 新しい画面と文（訳・逆翻訳・本人の見た目の確かめ）が要り、ペンの色は凍結の `PencilInteraction` に触れる案もある。小さく切り離せない |
| 0d-28 | XcodeGen | **2.46.0 の公式の zip を sha256 で固定**（9 か所。`tools/ci/install-xcodegen.sh`）。動かなければ 2.48.0 を全部で。上げるのはわざと書き換える commit だけ | brew は環境の formula の写しで版が決まり、環境の入れ替わりで変わる（F3）。2.46.0 は 1.3 の CI と同じ生成器なので、D0 で替わるのは Xcode だけ。2.47 から scheme の既定が替わる [S51] |
| 0d-29 | SUPPORT | Duo の表示の 1 文。Pencil の文は本人の Duo で確かめたときだけ（§8.4） | 確かめていない動きは書かない |
| 0d-30 | 複数の窓・折り目のレイアウト | しない | K-3、1.4 に機能を混ぜない。Apple は折り目をレイアウトに使わないと書く [S52] |
| 0d-31 | 主言語 | en-US のまま | 1.3 の公開の後、日本は日本語で出た（`r13` の ff4e3c4 の M7C.md の記録。§1.1 で `r14` に写す） |
| 0d-32 | 早い道 | 11/22 の夜に決める。見込みは低いと前もって本人に書いた | 本人の「どんどん進めて」。CI の同時の上限と 1 回 1 時間半で、1 回目で全部通ったときだけ間に合う（F4） |
| 0d-33 | 確かめ表 | 候補のビルドで 1 回だけ。27 行（Duo の 10 行は手元に無ければ「—」）。1.3 の確かめの 2〜6・9〜10 のやり直しを含む（3・4・5・6・7・8 行） | 1.3 の契約が約束した（M7C_CONTRACT:1282、C9）。Pencil と手のひらは本人の Duo でしか確かめられない |
| 0d-34 | 開閉の UI テスト | `duo-hinge` は 27.3 の**正式版**（Build の字で見分ける）で Duo を開けるときだけ合否。beta は記録だけ。11/23 までの既定は道 3（開けない） | 20261119 の 27.3 は beta で、別名は正式版のような名前。iOS 27.3 の実行環境も無い [S56]（F5） |
| 0d-35 | iOS 17 の試し | 1 回だけ試す（合否に使わない。起動しなければ止める） | 環境に iOS 17 が無い [S29]。本人の端末は 27.2 で、iOS 17 の人の不具合に気づく道が無い |
| 0d-36 | Duo の見分け方（入力） | **P（`UITouch.TouchType.pencil`）と H（`UIHingeInteraction` の hinge が nil でない）だけ**。窓の広さ（W）は入力に使わない。H は `usesHinge`（CI で測って決める）が true のときだけ | Mac の iPhone ミラーリングでは、ふつうの iPhone の窓も広くできる [S15]（F1）。H は Apple の文書にある口で、折り目の無い階層では nil [S52][S53]。閉じた外側で初めて起動した Duo でも、読めれば最初からオフにできる（F2） |
| 0d-37 | 1.3 から更新した Duo・移ってきた端末 | P のときだけオフへ。H では替えない。移ってきてアプリのオフが運ばれたときは、H で守る（rebind）か、無ければ 1 回だけオンに戻す | 指で書いていた人を、更新や機種の移し替えだけで書けなくしない（C8）。Pencil で書く人（本人の決定の前提）は最初の 1 本でオフになる |
| 0d-38 | 切り替えた後の知らせ | 「アプリ」の行（1.4 で初めて入れた人）だけ、週と日の 1 本指の札（今の文）を 1 回出し直す。持ち越し・移ってきた人と、1 ページの道では出さない | 札の最初の文「前後の週が横につながりました」は 1.3 の人には合わない（F10）。新しい文を足さない |
| 0d-39 | 触れの見方 | 凍結の `InkTouchObserver` の新しいインスタンスを窓に付ける（Pencil・指・ポインタを数え、何も認識しない）。iPad には付けない。新しい認識器は作らない | 1.3 からキャンバスで使っている形そのもの（reset・同時の認識の決まりも同じ。C7）。凍結のファイルは変えない。全部の触れが離れた時に替えられる（C6） |
| 0d-40 | 外側の画面 | 見た目は窓の大きさで（2 段・週・`.large`・上限あり）。入力は開閉で替えない | 書いている途中に入力の仕方が替わらない。「指でも書く」は端末に 1 つ |
| 0d-41 | Duo の店の写真の「指でも書く」 | オフの形（`--screenshot-pencil-phone`） | 本人の決定の前提（Pencil を使う）と、iPad の写真に合わせる |
| 0d-42 | 端末の印 | `identifierForVendor` の字を印にして、`allowFingerDrawingAuto`（String）に書く。外へは送らない | UserDefaults はバックアップと機種の移し替えで運ばれうる【推定】。別の端末では別の値 [S60]（F8・C8） |
| 0d-43 | N-3 の「次の版から」 | 確認ページで選べる。既定は今のまま | 1.4 は月と年をつながない（C16）。本人が承認した固定の文なので、本人の言葉なしに変えない。訳は 1.3 で用意済み |
| 0d-44 | 1 ページの道の幅の読み違い | 直さない（受けて記録）。1.4.1 で凍結の表を作り直すときに | 凍結の 1 行目に触れ、iPad・iPhone の回転の動きも変わる。保存・同期には触れない（C3） |
| 0d-45 | Duo の CI のジョブ | 別の workflow `duo.yml`（手で起動と `r14-duo*`）。`r14` の push では走らせない | 同時の上限 5 [S55]。build.yml は今でも 6 つで 1 つ待つ（F4） |
| 0d-46 | 純粋な決め方の置き場所 | `WindowClass` と `FingerDefault` は TegakiKit（Layout）に置き、KitChecks で表を見る | この Mac で `swift run KitChecks` が走るので、変異を CI を使わずに確かめられる（F4）。アプリにはつなぎだけ |

---

## 13. 確かめていないこと・出典

### 13.1 確かめていないこと【未確認】

1. iPhone Duo の内側・外側の pt の寸法、安全域、ステータスバーの位置（Apple は未公表 [S15][S16][S17]）。開閉で `windowScene.screen` が替わるのか、`bounds` だけが替わるのか。
2. CI のシミュレータで Duo を開けるか（`simctl` の口は見つからない [S40]。`XCUIHinge` は 27.3 beta [S6] だけで、20261119 の環境に iOS 27.3 の実行環境は無い [S56]。27.2 の Duo の実行環境で `XCUIHinge` が動くか）。Duo の機種の識別子の字。
3. Duo の写真で、内側と外側の両方が要るか。「2027 年 4 月から必須」の対象（全部のアプリか、iOS 27.1 SDK 以降か）[S9][S13]。
4. iOS 27 SDK の義務の正確な日（2027 年 4 月の何日か）[S8][S12]。
5. Xcode 27.3 の正式版の日と、そのとき `xcode-27` の環境から 27.0 の実行環境が消えるか。
6. `iPhone 18 Pro Max` の写真が 6.9 インチの受ける寸法に入るか。
7. 古い木（a21e469・43fe366・955fe67）が Xcode 27 で作れるか（作らない既定、§3.9）。
8. iOS 17 の実行環境を `xcode-27` の環境で取り寄せられるか。
9. Duo の内側でのフォームシートの見え方。iPhone の Scribble と、Duo の「設定 › Apple Pencil」。
10. 書きながら閉じたときに PencilKit が書きかけの 1 本を残すか捨てるか。
11. 年齢区分の 2 問を、公開中の App 情報に版なしで入れられるか（§9.5 の 1）。
12. 1.3 の `shots13.py` がどの写真の API を使っていたか。非推奨の写真の API がいつ使えなくなるか [S21]。
13. Connect が新しい版で前の版の写真を引き継ぐか（版 1.4 を作った後に読み戻す）。
14. 中国の 2027 年が python-holidays に入る日。
15. Duo のどちらの画面で Apple Pencil（USB-C）が使えるか（Apple の記事は機種だけを書く [S19]）。Duo の手のひらの見分け（ホバーなし [S54]）。
16. シミュレータ（XCUITest・Simulator）で Pencil の触れを作れるか。
17. Duo の窓の短い辺が、内側で 600 pt 以上・外側で 600 pt 未満か（見た目の W の前提。§4.2 で測る）。
18. **Duo の外側の画面（とシミュレータ）で `UIHingeInteraction` の hinge が nil でないか**（H の前提。§4.2 で測る）。
19. Mac の iPhone ミラーリングで窓をどこまで広げられるか（短い辺が 600 pt を超えるか）。Apple は「どの組み合わせのサイズクラスにもなる」と書く [S15]。
20. UserDefaults がバックアップと機種の移し替えで運ばれること（iOS の一般の動き。今回 Web では読んでいない）。`identifierForVendor` が TestFlight と App Store の入れ替えで変わるか（Apple の文書は Xcode のテストのビルドと ad-hoc で変わりうると書く [S60]）。
21. XcodeGen 2.46.0 の公式の zip が `xcode-27`（macOS 27）で動くか。

### 13.2 出典（調査担当が **2026-11-20** に読んだ。FACTS.md §10 の番号）

| 番号 | 中身 | URL |
| --- | --- | --- |
| S2 | Xcode の SDK and system requirements（配布の最低版 iOS 15–27） | https://developer.apple.com/support/xcode/ |
| S4 | Xcode 27.1 Release Notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes |
| S5 | Xcode 27.2 Release Notes（Duo の写真が黒い・複製の失敗） | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes |
| S6 | Xcode 27.3 Release Notes（beta 2、`XCUIHinge`） | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_3-release-notes |
| S7 | Apple security releases（iOS 27.2 は 2026-10-26） | https://support.apple.com/en-us/100100 |
| S8 | ニュース 2026-09-09（2027 年 4 月から iOS 27 SDK） | https://developer.apple.com/news/?id=k1mtkt1k |
| S9 | ニュース 2026-10-05（Duo の写真、2027 年 4 月から） | https://developer.apple.com/news/?id=kkphp5qo |
| S11 | ニュース 2026-11-02（年齢区分の新しい 2 問、期限 2027-01-12） | https://developer.apple.com/news/?id=yxkh08us |
| S12 | Upcoming Requirements | https://developer.apple.com/news/upcoming-requirements/ |
| S13 | Screenshot specifications（Duo 外側 1398 × 2034・内側 2007 × 2853） | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications |
| S14 | App Store Connect Release notes（Xcode 27.2 の受け付け 10/30） | https://developer.apple.com/help/app-store-connect/release-notes/ |
| S15 | Three steps to make your app shine on iPhone Duo | https://developer.apple.com/iphone-duo/prepare/ |
| S16 | HIG Designing for iPhone Duo | https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo |
| S17 | HIG Layout | https://developer.apple.com/design/human-interface-guidelines/layout |
| S18 | iPhone Duo の仕様（画素・Pencil（USB-C）、ホバーなし） | https://www.apple.com/iphone-duo/specs/ |
| S19 | Apple Pencil compatibility（2026-11-05 公開。Duo は iOS 27.2） | https://support.apple.com/en-us/108937 |
| S20 | App Store Connect API 4.6.1（2026-11-18。`sharedLocation`・`datingAndRelationships`） | https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-6-1-release-notes |
| S21 | App Store Connect API 4.5.1（Asset Library・`IPHONE_DUO`・前の写真の API は非推奨） | https://developer.apple.com/documentation/appstoreconnectapi/app-store-connect-api-4-5-1-release-notes |
| S23 | `AgeRatingDeclaration.Attributes` | https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclaration/attributes-data.dictionary |
| S24 | `ScreenshotDisplayType`（Duo の値が無い） | https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype |
| S25 | `AppAssetLibraryDisplayClass`（`IPHONE_DUO`） | https://developer.apple.com/documentation/appstoreconnectapi/appassetlibrarydisplayclass |
| S26 | Migrating to the App Asset Library | https://developer.apple.com/documentation/appstoreconnectapi/migrating-to-the-app-asset-library |
| S28 | actions/runner-images README（ラベルと方針） | https://github.com/actions/runner-images/blob/main/README.md |
| S29 | `xcode-27-arm64-Readme.md`（20261104.0337.1） | https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md |
| S33 | issue #14404（preview の印） | https://github.com/actions/runner-images/issues/14404 |
| S34 | GitHub Changelog 2026-10-15（Xcode 27 の環境は GA） | https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/ |
| S36 | GitHub Docs GitHub-hosted runners | https://docs.github.com/en/actions/reference/runners/github-hosted-runners |
| S37 | issue #15369 と releases（20261119 の prerelease） | https://github.com/actions/runner-images/issues/15369 |
| S38 | issue #15334・#15337、PR #15342（実行環境が外れる不具合と直し） | https://github.com/actions/runner-images/issues/15334 |
| S40 | Apple Developer Forums 847883（Duo のシミュレータを開く方法。利用者だけ） | https://developer.apple.com/forums/thread/847883 |
| S41 | Apple Developer Forums 854476（iOS 27.2 のシミュレータが 2 つ） | https://developer.apple.com/forums/thread/854476 |
| S43 | Apple Developer Forums 847909（`UIScreen.main`。DTS の答え） | https://developer.apple.com/forums/thread/847909 |
| S45 | PyPI の holidays（最新 0.109） | https://pypi.org/pypi/holidays/json |
| S46 | vacanza/holidays の `china.py`（v0.109・dev に 2027 年が無い） | https://github.com/vacanza/holidays/blob/v0.109/holidays/countries/china.py |
| S47 | vacanza/holidays v0.108・v0.109 の release notes | https://github.com/vacanza/holidays/releases/tag/v0.109 |
| S48 | PR #3052（2026 年の中国、2025-11-12） | https://github.com/vacanza/holidays/pull/3052 |
| S49 | 新華網「国务院办公厅关于2027年部分节假日安排的通知」（2026-11-05） | https://www.news.cn/politics/20261105/f90cd6ad4df94ab4833b141e52ccfc13/c.html |
| S51 | XcodeGen の releases（2.47.0・2.48.0） | https://github.com/yonaskolb/XcodeGen/releases |
| S52 | UIKit `UIHingeInteraction`（iOS 27.1。折り目の無い階層では hinge が nil。レイアウトに使わない）。**第 2 版のために 11/20 に読んだ**（JSON） | https://developer.apple.com/documentation/uikit/uihingeinteraction |
| S53 | `UIHingeInteraction.init(updateHandler:)`（最初の状態で呼ばれる）。`UIHinge`・`UIHinge.Status`（closed・partiallyOpen・fullyOpen・unknown）。11/20 | https://developer.apple.com/documentation/uikit/uihingeinteraction/init(updatehandler:) ・ https://developer.apple.com/documentation/uikit/uihinge |
| S54 | Apple Pencil の比べのページ（USB-C は筆圧・ダブルタップ・スクイーズ・バレルロールに対応しない。「Hover is not supported when using Apple Pencil (USB-C) with iPhone Duo」）。批評役が 11/20 に読んだ | https://www.apple.com/apple-pencil/ |
| S55 | GitHub Docs「Actions limits」（Free・Pro・Team の macOS の同時のジョブは 5）。批評役が 11/20 に読んだ | https://docs.github.com/en/actions/reference/limits |
| S56 | actions/runner-images の release「xcode-27-arm64 (20261119) Image Update」（prerelease）とその版の README（27.3 beta の別名、iOS 27.3 の実行環境なし、機種の一覧）。11/20 | https://github.com/actions/runner-images/releases |
| S57 | Apple Developer Forums 854417・854462（Xcode 27.2（27B52）が公開の直後の約 19 時間 ITMS-90534、のちに受け付け）。批評役が 11/20 に読んだ | https://developer.apple.com/forums/thread/854417 ・ https://developer.apple.com/forums/thread/854462 |
| S58 | XcodeGen 2.46.0・2.48.0 の release の資産と digest（`xcodegen.zip` の sha256。GitHub API で 11/20 に読んだ） | https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0 ・ https://github.com/yonaskolb/XcodeGen/releases/tag/2.48.0 |
| S59 | run 44474759145（955fe67、2026-11-19）のログ（XcodeGen 2.46.0）・ジョブの時間・成果物の期限（gh api で 11/20 に読んだ。批評役） | https://github.com/syfan0-star/tegaki-calendar-ios/actions/runs/44474759145 |
| S60 | UIKit `UIDevice.identifierForVendor`（別の端末では別の値。再起動の後で最初のロック解除の前は nil。その会社のアプリを全部消して入れ直すと替わる。Xcode のテストのビルドと ad-hoc でも替わりうる）。11/20 | https://developer.apple.com/documentation/uikit/uidevice/identifierforvendor |
| S61 | homebrew-core の xcodegen の formula の履歴（2.47.0 は 2026-11-17、commit dd9725fec）。批評役が gh api で 11/20 に読んだ | https://github.com/Homebrew/homebrew-core/commits/main/Formula/x/xcodegen.rb |

---

## 14. 記録

- 2026-11-20 契約の第 1 版の下書き（契約の設計の役。FACTS.md・CODE_SURVEY.md・M7_PLAN §4.5・§6.2・M7C_CONTRACT・M7C.md の 1.3 の記録と残り・R1_2_4.md を読んで書いた。途中で切れた）
- 2026-11-20 第 1 版（同じ役が下書きを直して仕上げた。読み手と批評の見直しの前）: 本人の決定「Duoでもペンシルを使うので、その前提で作って下さい。」を入れた（§0.1・§1.2・§4.8 を書き直し、Duo の見分け方 W・P と「指でも書く」の切り替えの表、外側の画面、Pencil の触れを見る認識器、確かめ表の Duo の 7 行、新機能の文の行 2、SUPPORT・審査メモの Pencil の文）。§0.4 の「Duo を持っていますか」の問いを消した（本人の決定で前提が決まった）。一覧の上限は「広い紙にはかけない」規則に替えた（下書きの ア／イ' をやめた。§4.7）。初めて開くページとシートは窓の短い辺で決める（幅で見るとふつうの iPhone の横が変わるため。§4.3）。米国の年齢の法律の見直しを範囲外に書いた（§1.4）。コードの行は 7895d40 で読み直した（`InkCanvasView.swift:1906-1908`・`:2412-2439`、`ToolbarView.swift:310-318`、`DateTap.swift:9-27`、`OverviewCapChecks.swift:87-92`・`:164`、`AppSettings.swift:119-122`、`onboarding.pen.text` は `tools/l10n/source/app-S.json:1501`、`docs/SUPPORT.md:121-123`）

- 2026-11-20 **第 2 版**（同じ役が、2 つの批評の 33 件（F1〜F13・C1〜C20）に答えた。§15）: 窓の広さ（W）を入力の信号から外し、P（Pencil の触れ）と H（`UIHingeInteraction`）にした（§4.8）。決め方を Kit の状態の型 `FingerDefault` にし、`appear` との順・触れている間・端末の印（`identifierForVendor`）・移ってきた値の戻しを入れた。触れの見張りは凍結の `InkTouchObserver` を窓に付けて使う（新しい認識器をやめた）。一覧の上限は紙でなく窓の短い辺で（窓の plan の `overviewCap`。`SpanPlan` は変えない、§4.7）。XcodeGen を 2.46.0 の zip で固定（§3.3）。Duo のジョブを `duo.yml` に分け、変異は手元とまとめた枝で（§3.10）。Xcode を Build の字で選ぶ。内側を開く道の既定を道 3 に（§4.2）。SDK の差の地図を D0 の関門 7 に（§3.6）。`TESTS_1_3` を D0 で 955fe67 の blob から作り、`FIXTURES_1_3` を足した（§5.5）。Probe の `versionExtraChecks`、`Real13LedgerTests` のバイトの比べは compat-span だけ（§5.3）。1 ページの道の読み違いは記録（§1.5）。N-3 は確認ページで選べる（§1.5）。確かめ表を 27 行に（§10）。Asset Library の `specId` と置き場所の決まり（§7.2）。出典 S52〜S61 を足した。コードの行は 7895d40 で読み直した（`ScreenPaths.swift:33-36`・`:265-269`・`:414-425`・`:1022-1027`・`:1186-1188`、`SpanSession.swift:262`・`:368-374`・`:1059-1064`、`InkCanvasView.swift:922-926`・`:1245-1272`・`:3035-3038`・`:3223-3225`・`:3289-3296`、`InkTouchObserver.swift`、`InkCanvasViewTests.swift:2447-2459`、`CalendarRootScreen.swift:187-188`・`:886`・`:938`・`:1253-1257`・`:2776`・`:2863-2872`、`AppSettings.swift:26-27`・`:96`・`:121`・`:181-187`、`SpanGuideView.swift:100`、`AllDayBand.swift:278`、`tools/span-compat/run.sh:20-56`、`build.yml` の 9 か所の `brew install xcodegen`）
- 2026-11-20 **D0b の足し**（リードの決定 L1〜L6 と、2 つの見直しの後の直し。M7D.md「D0b」）: §5.5 に (c)、§3.5 に (f)(g)(h)、§3.3 の 9 に新しい上限。§0.5 のとおり自動の確かめのやり方なので本人の決定は要らない。

- 2026-11-20 **D1c・D1d の足し**（§10 の言い回しだけ。M7D.md「D1b の CI の試しと D1c」）: 外側の小さいツールバーでは「指でも書く」のボタンが右の端の外にあるため、行 19・24・27 に「ツールバーを指で横にすべらせて見る」と足した。行 19 に「1.4 から新しく入れた Duo では、開いてすぐにオフ」と足した（`usesHinge = true`、duo-shots run 44717450692 の測りの行 `hinge=closed origin=app finger=false`）。確かめの中身と期待は変えていない。
- 2026-11-21 **行 28 の足し**（§10）: 「手書きのあるページを開き直して、線が全部見えるか」。CI の写真で、線は入ったのに描かれない形が、1.4 の環境と 1.3 の CI の両方で時々あった（M7D.md「D0b の run」の「前の節の直し」、D2 の 2 回目の run の en の月）。使う人への影響は本人の端末で見て決める、と M7D.md に書いた約束の行。

（結果は `docs/M7D.md` に書く。ここは契約の版の記録だけ。）

---

## 15. 批判への答え（第 2 版）

2 つの批評（事実と実行の見方 F1〜F13、互換・データ・テストの見方 C1〜C20）の全部に答えた。「採った」は批評の案のとおりに直した所、「形を替えて採った」は狙いは受けて、別の形で直した所（理由を書いた）。採らなかった物は無い。

| id | 答え | 直した所と理由 |
| --- | --- | --- |
| F1 | 採った | 窓の広さ（W）を入力の信号から外し、見た目（初めて開くページ・シート・一覧の上限）だけに使う。入力は P と H だけ（§4.8、0d-36）。§0.1・§0.2 の言い方を直し、ミラーリングで広げたときは見た目だけが変わると書いた。「W は Apple の文書にある口で止めてと言う物ではない」「ふつうの iPhone は W が当たらない」は消した。`FingerDefault.Signal` に窓が無いことを KitChecks で固め、変異 M-f7（窓を信号に足す）で落ちる（§6） |
| F2 | 採った | `UIHingeInteraction`（iOS 27.1）の hinge が nil でないことを H にした（§4.8）。レイアウトには使わない。`#if !targetEnvironment(macCatalyst)` で囲む。`--screenshot-measure` に `hinge=`、`iPhone 17` の行も取る（§4.2）。Duo のシミュレータのどれかの画面で nil でなければ `usesHinge = true`、どこでも nil なら false で P だけの道（記録は M7D.md）。`testFingerDefaultFollowsTheHinge` は、外側でも hinge が読めれば「オフ」を期待にする（§6）。1.3 から更新した人は P だけのまま |
| F3 | 形を替えて採った | brew をやめ、版と sha256 を決めた公式の zip を 9 か所（compat-v1-0 も）で入れる（§3.3 の 4、0d-28）。ただし版は案の 2.48.0 でなく **2.46.0**（1.3 の最後の CI が全部のジョブで使った生成器。D0 で替わる物を Xcode だけにするため）。2.46.0 の sha256 は GitHub の release の digest を 11/20 に読んだ（[S58]）。2.46.0 の zip が動かないときだけ 2.48.0 を全部で使う。FACTS §2.6 の「2.48.0 以降になる【推定】」は使わない |
| F4 | 採った | (1) Duo のジョブを別の workflow `duo.yml`（手で起動と `r14-duo*` だけ）にした（§3.10、0d-45）。(2) `WindowClass`・`FingerDefault` を Kit に置き、変異を手元の `swift run KitChecks` で見る（0d-46）。KM-d2・KM-d3 は `SpanPlan` を変えないので無くなった。(3) アプリと UI の変異は 1 本の枝ずつにまとめる。(4) D0 は build.yml → ja-baseline → testflight → duo.yml の順。(5) §0.3・§9.1 の時間を待ちを入れて書き直し、早い道は見込みが低いと書いた。build-and-test は D0 で 110 分 |
| F5 | 採った | Xcode を `xcodebuild -version` の Build の字で選び、パスの名前では見分けない（§3.1）。11/23 までの既定は道 3（§4.2）。`duo-hinge` は 27.3 の正式版で開けるときだけ合否、beta は記録だけ（店の写真にも使わない）。§0.1・§0.6 を道 3 の前提の言い方にした |
| F6 | 採った | §0.1: シートの形は「自動の確かめで開いた画面を撮れたときだけ」。「1.4 にしてから…切り替えたことがあれば」。初めて入れた Duo は「Pencil で最初の 1 本を書き終えたとき（折り目が読めると分かったときは初めから）」と、条件どおりに書いた |
| F7 | 採った | 関門 3 を 2 段にした（`paperArea=` が同じなら数も同じ。違えば Kit の `--span-state` で計算し直して合えば受ける。止めるのは同じ紙の領域で数が違うときだけ）（§3.3）。D0 はコードを変えないので、紙の領域は今のログの `toolbar: paperArea=` の行を使う |
| F8 | 採った | 印を端末に結びつけた（`identifierForVendor` の字、0d-42）。ほかの端末でアプリがオフにした値が運ばれたら、H があればそのまま、無ければ 1 回だけオンに戻す（§4.8 の「戻し」）。§11 にも書いた |
| F9 | 採った | §13.1 の旧 14（料金）と旧 18（Pencil の機能）を消し、§3.1・§1.4・§4.1 の 8・9・0d-13 を【事実】にして出典を付けた（[S36][S54]）。§3.2 の mini の行に 27.0 が消えたときの移り方。0d-1 に 27.2 が公開の直後に断られたこと（[S57]）を足した |
| F10 | 採った（案 (a)） | 札の出し直しは「アプリ」の行（1.4 で初めて入れた人）だけ。持ち越し・移ってきた人には出さない。1 ページの道では誰にも出ないことも書いた（§4.8、0d-38）。確かめ表の行 19 の説明も合わせた |
| F11 | 採った | §0.4 の問い 1 に「ほかの国の祝日のデータも同じ版に新しくなります（例: ハンガリーの 12 月 24 日）」を足した |
| F12 | 採った | §7.2 に `specId` の読み戻しと、置き場所は `PREPARE_FOR_SUBMISSION` のときだけ作れることを書いた。0d-23・§9.1 に「遅れたら次の版の提出の時に足す」。確認ページは 1 回のまま（1.4 で写真が遅れたら、1.4 の確認ページの写真の行は「無し」で、写真は次の版の確認ページで見てもらう） |
| F13 | 採った | §3.6・§9.1 の S0' を「11/20 に 6 つの成果物を全部控える」にし、期限を時刻で書いた |
| C1 | 形を替えて採った | `shotPaperOffset` に紙の高さを足す代わりに、**広い窓の横の道の窓の plan を `overviewCap: false` で作る**（§4.7）。`atCappedOverview`・`shotPaperOffset` は `layout.plan.overviewCap` を見るので、変えずに広い窓で false になり、今日のページは 0:00 から開く（`CalendarRootScreen.swift:2776` の道も同じ plan）。`CappedOverviewWideTests` は `shotPaperOffset` を通して試し、変異「`makeSession` が true のまま」で落ちる（§6） |
| C2 | 採った | 「指でも書く」は Kit の状態の型 `FingerDefault` が決め、`appeared`（既定を書いた後の値と印）を受けるまで何もしない。H や触れが先でも後でも 1 回だけ（§2.1・§4.8）。初めて開くページも `WindowClass.Opening` で大きさと `appear` の順に依らない（§4.3）。両方の順を KitChecks の行で固め、変異 M-f4 で落ちる |
| C3 | 採った（(ii) を選んだ） | §1.5 に行を足し、1 ページの道の読み違いは**直さずに記録**とした（凍結の 1 行目に触れ、iPad・iPhone の回転の動きも変わるため。保存・同期には触れない。0d-44）。確かめ表 25 に書いた。§4.9 の 2 を「横の道の窓の決め直しは離して止まった後。倍率と位置は 1 ページの道でも横の道でもその場で替わる」に直した。`DuoFoldTests` の期待を道ごとに分けた |
| C4 | 採った | §3.6 を D0 の関門 7 にした。組 4 で説明のつかない強い差は止める。組 3 は前もって決めた切り抜きで操作部品が全部見えること（§3.7 の 10 に一覧）。確認ページに前と後の写真。確かめ表の行 2 の言い方も合わせた |
| C5 | 採った | `TESTS_1_3` を D0 の commit で、955fe67 の blob から作る。挙げられたファイル（`PaperSpanTests`・`SpanGuideSeenSpanTests`・`ScreenshotModeSpanTests`・`WeekMemoPaperSpanTests`・`StageTwoNoticeSpanTests`・`SettingsPageSectionTests`・`EventStoreModelSpanTests`・`CompatSpanFixtures/*.swift`・UI の 3 つ・KitChecks の 4 つ・`PaperViewTests`）を足した。`SpanChecks.swift` の注は直さない。`FIXTURES_1_3.sha256` で compat11・compat-span・MANIFEST・`EXPECTED_MIN` を守り、ファイルの一覧も比べる（§5.5） |
| C6 | 採った | 切り替えは、窓の見張りが数える全部の触れ（Pencil・指・ポインタ）が離れた時だけ（§4.8）。見張りは凍結の `InkTouchObserver`（3 種類を受ける）。「指が触れている間は替わらず、離した後に 1 回」を KitChecks と `PencilPhoneTests` で固めた |
| C7 | 形を替えて採った | 新しい認識器を作らず、**凍結の `InkTouchObserver` そのもの**の新しいインスタンスを窓に付ける（reset・canPrevent・requiresExclusiveTouchType は 1.3 と同じ）。作り物の `UITouch`（`StandInTouch` の形の写しを、テストのファイルの中だけで private に。元のファイルは `TESTS_1_2_3` なので動かさない）で、P・指・離す・reset・状態の動きのテストを書いた。字を読むテストは機種名の見張りだけに絞った（§6） |
| C8 | 採った | 印を端末に結びつけ、ほかの端末の印は「移ってきた」と読む（0d-42）。移ってきた人は P だけで替える（ふつうの iPhone から Duo へ移した人も守る）。アプリが別の端末でオフにした値は、折り目の無い端末で 1 回だけオンに戻す（本人の切り替えが優先）。§0.2・§2.1 の「この端末だけ」を「iCloud では同期しない（バックアップでは移りうる）」に直した。本人がオフにした値は移っても戻さない（本人の選び。§11 に書いた） |
| C9 | 採った | 確かめ表に 1.3 の 5（はじく・止める）・6（斜め）・10（日の自由メモを日をまたいで）を足した（行 5・6・8）。Duo にも「はじく」（行 23）。0d-33 の行数を 27 に直した |
| C10 | 採った | `Real13LedgerTests` のバイトの比べは compat-span の見本だけにした（§5.3 の 3） |
| C11 | 採った | `Probe/main.swift` に `versionExtraChecks(pages:)` を呼ぶ 1 行、v10・v11・v123 に何もしない同じ名前の関数（§5.3 の 2、§2） |
| C12 | 形を替えて採った | 帯を引く前の高さを渡す代わりに、**紙でなく窓の短い辺で決める**（窓の plan の `overviewCap`、§4.7）。凍結のキャンバスは帯を引いた紙の領域で `zoomBounds` を呼ぶ（`InkCanvasView.swift:3035-3038`）ので、紙の高さの規則では帯の揺れを無くせない。窓の短い辺は帯のレーンで変わらないので、揺れが無くなる。KitChecks に「内側の横、帯が 35 %」の行を足した |
| C13 | 採った | `testPaperFillsTheScreen` を消した。合否は `shot_checks.py` の端の列の確かめだけで、その確かめは作り物の写真で落ちる自己試験つき（§6） |
| C14 | 採った | 出典を `ScreenshotModeTests.testDemoPagesMatchCompatFixtures` に直し、関門 2 と §5.6 に 3 つのテストの名前を同じ字で書いた |
| C15 | 採った | F7 と同じ（関門 3 の 2 段） |
| C16 | 採った | §1.5 に N-3 の行を足し、確認ページで選べる（既定は今のまま）とした（§0.4、0d-43）。選ばれたら L-3 の例外として J-1 と訳と J-4 を直す |
| C17 | 採った | F6 と同じ（「1.4 にしてから…」） |
| C18 | 採った | §2 にそろえた: `SpanChecks.swift` は直さない（`TESTS_1_3`）。`personSet` を §2.1 に宣言した。§1.5 (c) に `SpanPlan.swift:4-7` を足した。`SpanPlan.swift` は注だけ |
| C19 | 採った | §2 と §3.9 に「Kit の新しいコードは Swift 6.3 でも通ること」と、compat-v1-0 が落ちたときにまず見る所を書いた |
| C20 | 採った | Duo の行に「月のページに Pencil で書き、指で動かす」（21）と「年のページで日付を指でタップ」（22）を足した。`duo-shots` の宣言の数を道ごとに前もって書き、内側だけのテストは道 3 では宣言から外す（§4.2） |
