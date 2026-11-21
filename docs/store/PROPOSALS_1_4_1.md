# 1.4.1 の店の文と SUPPORT の案（本人の確認ページで見せる）

**対象の版: 1.4.1**。ここは案で、どれもまだ Connect にも Web にも入れていない。本人の確認ページ（[R1_4_1_CONTRACT.md](../R1_4_1_CONTRACT.md) §0.4・§9.1 の D3）で一緒に見せ、「この内容で入れてよい」をもらってから入れる。本人の「この内容で入れてよい」は、ここに書いた全部の組み合わせに効く（契約 §8.3）。どの文を使うかは、同じ確認ページの 2 つの選び（契約 §0.4 の 1「見出しの並べ方」と 2「等倍のボタンの見た目」）の答えで決まる。選ばなければ既定（並べ方 (a)・虫めがねに「1」の印のボタン）のままで、`ja/whatsnew.txt`・`source-ja/whatsnew.txt`・`review-note.txt` には既定の字をもう入れた（2026-11-22）。決めた組み合わせは `docs/R1_4_1.md` に書く。

§1 は新機能の文（契約 §8.3。ja 以外の訳は D2 で役 X、元を見ない逆翻訳は R、照合と判定は [docs/i18n/REVIEW.md](../i18n/REVIEW.md)。契約 §8.2）。§2 は審査メモの、選びで替わる文（契約 §8.4）。§3 は SUPPORT の言い方（契約 §8.5。役 W）。

## 1. 新機能の文の行と、並べ方 (b) の 1 つ目の行

### 1.0 決まり

- 元は契約 §8.3 の 4 つの行と、並べ方 (b) のときの 1 つ目の行。契約の `>` の行から機械で読んだ（手で写していない）。ja と `source-ja` はこの字を使う。
- 並べ方: 行 1 → 行 2 → 行 3 → 行 4。ja 以外は、空の行を 1 つ置いて訳についての 1 行（1.4 の `source-ja/whatsnew.txt` と 15 のロケールの最後の行と同じ字。1.2.3 から変えていない）。
- 行 1 は (a)（既定）か (b) のどちらか 1 つ。行 2 は「等倍」の字のボタンが選ばれても同じ（ボタンの見た目を書かないため。契約 §8.3）。行 3 と行 4 はいつも。
- 書いていないこと: K-8 の句（契約 §5.2。新しい欄も形も無い）、無い改善（R1_2_2.md:694）、価格と通貨の記号（L-9）。契約 §0.1 の最後の点（拡大しているときに回転すると見ていた所が少し横にずれる、0d-44 の直し）も、契約 §8.3 の行に無いので書かない（その直しは、ピン留めのテストが 1 つでも結果を変えたら戻す。契約 §3.10）。
- 訳（D2。まだ）: 1.4 と同じ 11 組を訳す（en-GB・en-AU・en-CA は en-US の写し、fr-CA は fr-FR の写し。`locales.json` の `copyOf`）。「今日」はアプリの `header.today`、「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` の、各言語の訳と同じ字にする（X が写す）。「ツールバー」は、アプリの `onboarding.pen.text` の訳の語（1.4 の行 2 と同じ。[PROPOSALS_1_4.md](PROPOSALS_1_4.md) §2.3 の表）にする。「‹ ›」の記号はそのまま。「等倍」は GLOSSARY の語（拡大も縮小もしていないもとの大きさ。契約 §8.2）。es-ES は es-MX から直し、pt-PT は別に書く（README の「X への手引き」）。それまで 15 のロケールの `whatsnew.txt` は 1.4 の字のまま（README の「新機能の文の組み立て」）。

### 1.1 行（ja と source-ja の字）

| 行 | いつ使うか | ja（source-ja も） |
| --- | --- | --- |
| 行 1 (a) | 既定（並べ方 (a)。本人が選ばないときも） | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 |
| 行 1 (b) | 本人が並べ方 (b) を選んだとき | ・画面の上の「‹ 今日 ›」を、左の端の日付のすぐ右に移しました。 |
| 行 2 | いつも（「等倍」の字のボタンでも同じ） | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 |
| 行 3 | いつも | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 |
| 行 4 | いつも | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 |
| 訳についての 1 行 | ja 以外（`source-ja` の最後。Connect の ja には入れない） | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 |

### 1.2 全文

**ja・既定**（`ja/whatsnew.txt` に入れた字。訳についての 1 行は無い）:

```text
・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。
・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。
・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。
・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。
```

**ja・並べ方 (b)**:

```text
・画面の上の「‹ 今日 ›」を、左の端の日付のすぐ右に移しました。
・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。
・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。
・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。
```

**source-ja・既定**（`source-ja/whatsnew.txt` に入れた字。ja 以外の日本語の元。Connect には入れない）:

```text
・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。
・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。
・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。
・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。

訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。
```

**source-ja・並べ方 (b)**:

```text
・画面の上の「‹ 今日 ›」を、左の端の日付のすぐ右に移しました。
・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。
・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。
・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。

訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。
```

### 1.3 字数（上限 4,000 字）

数え方は L-9（`tools/l10n/lint.py` の `store_text`）と同じで、ファイルの末尾の改行 1 つを除いた字の数。

| | 既定（並べ方 (a)） | 並べ方 (b) | 上限 |
| --- | ---: | ---: | ---: |
| ja | 175 | 173 | 4,000 |
| source-ja | 220 | 218 | 4,000 |

### 1.4 行 1 (b) の訳（11 組。D2）

本人が並べ方 (b) を選んだときだけ、各ロケールの `whatsnew.txt` の 1 行目をこの字に替える（2 行目から後と訳についての 1 行はそのまま）。訳は D2 の X（2026-11-22、Workflow wf_282a113b-ce4 の直し）、元を見ない逆翻訳と判定は 11 組とも ○（[REVIEW.md](../i18n/REVIEW.md) の 14、`docs/i18n/back/store-1_4_1-b.md` の最後の節）。字数は (b) にしても 4,000 字に入る（同じファイルの表）。

| ロケール | 行 1 (b) |
| --- | --- |
| en-US（en-GB・en-AU・en-CA も） | • Moved “‹ Today ›” at the top of the screen so that it is immediately to the right of the date, which is at the left end. |
| zh-Hans | • 屏幕顶部的“‹ 今天 ›”已移到左端日期的右边，紧挨着日期。 |
| zh-Hant | • 螢幕頂端的「‹ 今天 ›」已移到左端日期的右邊，緊鄰日期。 |
| ko | • 화면 위쪽의 ‘‹ 오늘 ›’을 왼쪽 끝에 있는 날짜의 바로 오른쪽으로 옮겼어요. |
| fr-FR（fr-CA も） | • En haut de l’écran, « ‹ Auj. › » a été déplacé juste à droite de la date, qui se trouve tout à gauche. |
| de-DE | • „‹ Heute ›“ oben auf dem Bildschirm wurde direkt rechts neben das Datum verschoben, das am linken Rand steht. |
| it | • In alto sullo schermo, “‹ Oggi ›” è stato spostato subito a destra della data, che si trova all’estremità sinistra. |
| pt-BR | • No alto da tela, “‹ Hoje ›” foi movido para logo à direita da data, que fica no extremo esquerdo. |
| pt-PT | • No topo do ecrã, “‹ Hoje ›” foi movido para logo à direita da data, que fica no extremo esquerdo. |
| es-MX | • En la parte superior de la pantalla, “‹ Hoy ›” se movió justo a la derecha de la fecha, que está en el extremo izquierdo. |
| es-ES | • En la parte superior de la pantalla, “‹ Hoy ›” se ha movido justo a la derecha de la fecha, que está en el extremo izquierdo. |

## 2. 審査メモの、選びで替わる文（契約 §8.4）

- `review-note.txt` には既定（並べ方 (a)・虫めがねに「1」の印のボタン）を入れた: **3,924 バイト**（`wc -c`。最後の改行を除くと 3,923 バイト・3,554 字）。1.4 の文（3,964 バイト）の「What is new in 1.4」の段を「What is new in 1.4.1」の 4 つに入れ替え、日本語の要約の 1.4 の分（「Xcode 27.2（iOS 27.2 SDK）で作り、…新しい画面の文は無し。」）を 1.4.1 の分に入れ替えた。ほかの段と、要約の最後の「データ・購入・年齢区分は同じ。規約類は日本語が正本で、英語は参考訳。サインイン不要。」は 1 字も変えていない（README の「審査メモ」の「1.4.1 から」）。
- 2 つの選びは別々に効くので、組み合わせは 4 つ（既定・(b)・「等倍」の字・(b) と「等倍」の字）。替わるのは「What is new in 1.4.1」の 1・2・4 と、日本語の要約の 1 つ目の文と「新しい文」の文だけ。3（ツールバーと確かめ方）とほかの段はどの組み合わせでも同じ。
- **〈W〉** は「等倍」の字のボタンの en の字（D2 の訳。`header.zoomReset` の en、契約 §8.1）。**まだ決まっていない**ので、ここでは 〈W〉 と書く。**en に「Fit」は使わない**（意味が違う。契約 §8.1）。D2 で決まったら、その字を入れてこの節のバイトを数え直す。
- 日本語の要約はボタンを「等倍のボタン」と書くので、「等倍」の字のボタンでも 1 つ目の文は同じ。

### 2.1 並べ方 (b)（虫めがねの印のまま）

| 所 | 既定（今のファイル） | 並べ方 (b) |
| --- | --- | --- |
| 1（en） | 1. ‹ Today › and the 1× button (a magnifying glass with "1") are now at the left end of the header, with the date right after them (on narrow screens, 1× starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. The date is now at the left end of the header, with ‹ Today › and the 1× button (a magnifying glass with "1") right after it (on narrow screens, 1× starts the second row). Settings > Dominant Hand > Left Hand reverses this order. |
| 日本語の要約の 1 つ目の文 | 左上に「‹ 今日 ›」と等倍のボタン、すぐ右に日付（設定 › 利き手 › 左手 で逆）。 | 左上に日付、すぐ右に「‹ 今日 ›」と等倍のボタン（設定 › 利き手 › 左手 で逆）。 |

- 2・3・4 と要約のほかの文は既定と同じ。幅の狭い画面の等倍は (b) でも 2 段目の左（契約 §3.2 の (b) の表）なので、1 の括弧は同じ。
- 並べ方 (b) の審査メモは **3,921 バイト**（`wc -c`。最後の改行を除くと 3,920 バイト・3,551 字）。

### 2.2 「等倍」の字のボタン（並べ方 (a)）

| 所 | 既定（今のファイル） | 「等倍」の字のボタン |
| --- | --- | --- |
| 1（en） | 1. ‹ Today › and the 1× button (a magnifying glass with "1") are now at the left end of the header, with the date right after them (on narrow screens, 1× starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. ‹ Today › and the "〈W〉" button are now at the left end of the header, with the date right after them (on narrow screens, that button starts the second row). Settings > Dominant Hand > Left Hand reverses this order. |
| 2（en） | 2. 1× returns the page to its original size, neither zoomed in nor out (as when first opened), and clears the zoom remembered for that page type. | 2. "〈W〉" returns the page to its original size, neither zoomed in nor out (as when first opened), and clears the zoom remembered for that page type. |
| 4（en） | 4. New text is only in Settings and VoiceOver labels. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating. | 4. New text: the "〈W〉" button, Settings and VoiceOver labels. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating. |
| 日本語の要約の「新しい文」の文 | 新しい文は設定と読み上げだけ。 | 新しい文は等倍のボタンと設定と読み上げだけ。 |

- 4 と要約の文を替えるのは、字のボタンでは見出しに新しい字（`header.zoomReset`）が出るため（契約 §8.1。既定では、新しい文は設定と読み上げだけ）。
- 字のボタンのとき、1 の幅の狭い画面の括弧は 〈W〉 でなく「that button」にした（〈W〉 を 3 か所にして、バイトを抑えるため）。
- バイトは **3,926 ＋ 3 × 〈W〉 の字数**（`wc -c`。〈W〉 の所を空にした数。〈W〉 は 3 か所で、英字は 1 字 1 バイト）。〈W〉 が 24 字までなら 4,000 バイトに入る。

### 2.3 並べ方 (b) と「等倍」の字のボタン

| 所 | 既定（今のファイル） | 並べ方 (b) と「等倍」の字のボタン |
| --- | --- | --- |
| 1（en） | 1. ‹ Today › and the 1× button (a magnifying glass with "1") are now at the left end of the header, with the date right after them (on narrow screens, 1× starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. The date is now at the left end of the header, with ‹ Today › and the "〈W〉" button right after it (on narrow screens, that button starts the second row). Settings > Dominant Hand > Left Hand reverses this order. |

- 2・4 と要約の「新しい文」の文は §2.2 の字、要約の 1 つ目の文は §2.1 の (b) の字。3 とほかの段は既定と同じ。
- バイトは **3,923 ＋ 3 × 〈W〉 の字数**（数え方は §2.2 と同じ）。〈W〉 が 25 字までなら 4,000 バイトに入る。

### 2.4 書いたこと（役 A、2026-11-22）

- 1〜4 は契約 §8.4 の (1)〜(4) の順。確かめ方は、1.4 の 2 と同じく、その点（3）の終わりに「To check:」で書いた（契約 §8.4 の「iPad で週のページを開き、つまみを右の端へ引く」）。
- 1 の「1× button (a magnifying glass with "1")」は、ボタンの印（SF Symbols の `1.magnifyingglass`、契約 §3.1）を審査の人が見つけられるように添えた。幅の狭い画面（列の幅が 600 pt 未満。iPhone の縦と iPad の細い窓）では等倍が 2 段目の左にある（契約 §3.2）ので、括弧で書いた。契約 §0.1・§8.5 の言い方の「iPhone の縦」にしなかったのは、iPhone Duo の開いた画面は縦でも幅が 600 pt 以上で見出しが 1 段になり、等倍は「‹ 今日 ›」のとなりにあるため（契約 §3.5・§4.3。3 で審査の人を Duo の開いた画面へ向けるので、そこで食い違わないようにした。2026-11-22 の見直しの指摘）。
- 2 の「original size, neither zoomed in nor out (as when first opened)」は、契約 §8.4 の (2) の「拡大も縮小もしていないもとの大きさ（初めて開いたときの大きさ）」、「clears the zoom remembered for that page type」は「その種類の覚えた拡大も忘れる」（契約 §3.9）。
- 3 の「Apple Pencil cannot」は Pencil では動かないこと（契約 §4.6）、「On iPhone, even on iPhone Duo's inner screen, it stays at the bottom」は iPhone は Duo の開いた画面も下のまま（契約 §4.3。1.4 の 2 の「inner or outer」と同じ語）。狭い窓で下に戻ること（契約 §4.3）は、契約 §8.4 の (3) に無いので書いていない。
- 4 の「New text is only in Settings and VoiceOver labels」は、契約 §8.4 の (4) の「新しい画面の文は設定と読み上げだけ」。読み上げの名前は画面に出る字ではないので、英語では「on-screen」を付けなかった（2026-11-22 の見直しの指摘。日本語の要約は契約の字のまま）。
- 4 の年齢区分は「the age rating」だけにした（1.4 の 4 にあった新しい 2 問の括弧は 1.4 で答えた物で、契約 §8.4 の (4) は「年齢区分は変わらない」だけ）。
- 設定の英語の名前（Dominant Hand・Left Hand）は、今のアプリの en の訳（`tools/l10n/translations/en.json`、r141-quick の 277cef4）の字。D2 の訳で替わったら、審査メモとこの節を一緒に直す。
- バイトは、1.4 の文のほかの段を 1 字も変えずに、4 つの組み合わせを機械で組み立てて数えた。K-8 の句は、どの組み合わせにも無い。
- 元を見ない逆翻訳と判定は D2（まだ。R に、今のファイルの「What is new in 1.4.1」の段と §2.1〜§2.3 の英語の文を、日本語の要約と元を見せずに渡す）。

## 3. SUPPORT の言い方（4 つの組）

### 3.1 SUPPORT の等倍のボタンの言い方（4 つの組。役 W）

- 元: 契約 §8.5 の「等倍のボタンの言い方」と、本人が写真で選ぶ 2 つ（契約 §0.4 の 1・2）。
- ファイル（`docs/SUPPORT.md`・`docs/SUPPORT.en.md`）には**既定の組（並べ方 (a)・虫めがねの印）**を入れた。ほかの 3 つの組はファイルに入れずにここに置く。確認ページでは選ばれた組を見せる。選ばれたら、下の表の字で入れ替える。
- 替わるのは、「拡大・縮小するには？」（英語は “How do I zoom in and out?”）の 2 つ目の段落の**最初の 1 文だけ**。続く 2 文（幅の狭い画面と左手）は 4 つの組とも同じ（3.1.2）。幅の狭い画面では、どの組も「2 段目の左」。
- ほかの文は、どの組でも本当になるように書いたので、組で替えない:
  - 「予定が出ない」の 4（`SUPPORT.md:64`、英語は :69）は字を変えない（3.2）。
  - 「左手で使うには？」は「「‹ 今日 ›」と等倍のボタンが右側に移ります」と書いた。(a) では右の端、(b) では右の端の日付のすぐ左で、どちらも右側。「等倍のボタン」は、印でも字でも同じ言い方。英語は “the Reset Zoom button”（読み上げの名前）。
  - 左手のときの場所「右上（幅の狭い画面では 2 段目の右）」も、4 つの組で同じ。
- 字の組の英語の 〈W〉 は、§2 の 〈W〉 と同じ（「等倍」の字のボタンの en の字。まだ決まっていないこと・「Fit」は使わないことは §2 の頭の箇条）。読み上げの名前 “Reset Zoom”（`header.zoomReset.spoken`）は字の組でも残るので、括弧で添える。
- 「幅の狭い画面（iPhone の縦と iPad の細い窓。iPhone Duo の開いた画面は除く）」: 契約 §0.1・§8.5 は「iPhone の縦」と言うが、iPhone Duo の開いた画面は縦でも幅が 600 pt 以上で見出しが 1 段になり、等倍は「‹ 今日 ›」のとなりにある（審査メモの 1 の「on narrow screens」と同じ考え。§2.4。2026-11-22 の見直しの指摘）。
- K-8 の句は入れない（契約 §5.2）。1.4.1 に無い改善は書かない。
- 元を見ない逆翻訳と判定（R・J）はまだ。英語の 4 文と、3.1.2 の文、ほかの新しい文（「左手で使うには？」「ツールバーを動かすには？」、しまう・拡大の段落に足した文）を、まとめて頼む。

#### 3.1.1 4 つの組（替わる 1 文）

| 組 | ja | en |
| --- | --- | --- |
| (a)・印（既定。今のファイル） | 左上の「‹ 今日 ›」のとなりにある、虫めがねに「1」の印のボタン（等倍）を押すと、拡大も縮小もしていないもとの大きさ（そのページを初めて開いたときの大きさ）にすぐ戻ります（1.4.1 から）。 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). |
| (a)・字 | 左上の「‹ 今日 ›」のとなりにある「等倍」のボタンを押すと、拡大も縮小もしていないもとの大きさ（そのページを初めて開いたときの大きさ）にすぐ戻ります（1.4.1 から）。 | Tap the “〈W〉” button (Reset Zoom), next to “‹ Today ›” at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). |
| (b)・印 | 左上の日付の右、「‹ 今日 ›」のとなりにある、虫めがねに「1」の印のボタン（等倍）を押すと、拡大も縮小もしていないもとの大きさ（そのページを初めて開いたときの大きさ）にすぐ戻ります（1.4.1 から）。 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” to the right of the date at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). |
| (b)・字 | 左上の日付の右、「‹ 今日 ›」のとなりにある「等倍」のボタンを押すと、拡大も縮小もしていないもとの大きさ（そのページを初めて開いたときの大きさ）にすぐ戻ります（1.4.1 から）。 | Tap the “〈W〉” button (Reset Zoom), next to “‹ Today ›” to the right of the date at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). |

#### 3.1.2 どの組でも同じ文（替わる 1 文のすぐ後）

| 言語 | 文 |
| --- | --- |
| ja | 幅の狭い画面（iPhone の縦と iPad の細い窓。iPhone Duo の開いた画面は除く）では、このボタンは 2 段目（日・週・月・年の切り替え）の左にあります。設定 › 利き手 で「左手」にしているときは、右上（幅の狭い画面では 2 段目の右）にあります。 |
| en | On a narrow screen (a narrow iPad window, or iPhone in portrait except on the inner screen of iPhone Duo), this button is at the left of the second row (the Day, Week, Month and Year switch). When “Left Hand” is chosen in the App's Settings > Dominant Hand, it is at the top right (on a narrow screen, at the right of the second row). |

- 段落の残り（「等倍に戻すと、そのページの種類で覚えていた拡大も忘れます。…」）は、4 つの組とも今のファイルのまま。

### 3.2 SUPPORT の今のファイルに入れたもの（既定の組）の覚え

- 「予定が出ない」の 4（`:64`、英語 :69）は字を変えていない。「画面の上の「今日」」には位置の語が無いので、どの場合でも正しい。右手と左手、並べ方 (a) と (b)、公開の日にまだ 1.4 以前を使っている人の、どれでも正しい。「左の端の「‹ 今日 ›」」と書くと、左手（右側にある）・(b)（左の端は日付）・1.4 以前（右側にある）の 3 つで正しくなくなる。押すのは「今日」のボタンそのもの（‹ と › は 1 ページずつ動く別のボタン）。
- Apple Pencil の切り替えの節（`:119`）: 「画面下の」を取って「ツールバーで切り替えてください」にした。上・左・右に置いた iPad では、ツールバーは画面の下に無いため。
- 「ツールバーをしまうには？」:
  - 「右端」の後に「（左右の端に置いたときは下の端）」を足した。
  - 丸ボタンの角を書いた。設定 › 利き手 で「左手」を選ぶと右下、iPad で左の端に置いてから「しまう」を押すと左下、右の端なら右下。丸ボタンはツールバーを開いている間は画面に無いので、「置くと移ります」でなく「しまうと出ます」の形にした（契約 §4.9。英語は “if you move the toolbar to the left edge and then hide it, the round button appears at the bottom left”。2026-11-22 の見直しの指摘）。
  - 長押しの「右下へ移したり」は、「もう一方の下の角へ移したり」に直した（左手のときは、丸ボタンがもう右下にあるため）。
  - 角の決まりは、契約 §4.1・§4.9 と r141-q の `Hand.dockEdge` に合わせた。最後にしたことが勝つ。丸ボタンは、いつも下の角に出る。
- 「拡大・縮小するには？」:
  - 月と年の文に「（iPad でツールバーを左右の端に置いたときは、紙の幅が狭くなる分だけ小さく開くことがあります）」を足した。横の画面では紙の高さで大きさが決まるページもあるので、「ことがあります」にした。英語の「by that much」は指す物が無いので「by the width of the toolbar」にした（2026-11-22 の見直しの指摘）。
  - 等倍の段落を足した: 場所、幅の狭い画面、左手のときの場所、覚えた拡大を忘れること、次に開くページと開き直したときも等倍、ほかの種類はそのまま。
- 新しい FAQ 2 つ（「左手で使うには？」「ツールバーを動かすには？」）は、「拡大・縮小するには？」のすぐ後に、契約 §0.1 の順で置いた。英語は “How do I use it with my left hand?” と “How do I move the toolbar?”。
  - 「ツールバーを動かすには？」の細い窓の箇条は、契約 §4.3 の 2 通りを書いた: 短い辺が 600 pt 以上で列が 700 pt 未満の窓（13 インチの横の ⅔ の Split View など）では、左右の端に置いたツールバーは下に出て、上に置いたものは上のまま。短い辺が 600 pt 未満の窓（Slide Over など）では、上に置いたものも下に出る。前の字（「下に戻ります（窓の広さによっては、上と下にだけ置けます）」）は、言い切りと括弧が食い違って読めたので直した（2026-11-22 の見直しの指摘）。
  - 英語の「the paper becomes smaller by that much instead」は指す物が無いので、「instead, the paper becomes smaller to make room for it」にした（上の端ではツールバーの高さ、左右の端では幅の分なので、「width」とは書かなかった。2026-11-22 の見直しの指摘）。
- 新しい機能の所には「（1.4.1 から）」を付けた（1.4 の「（1.4 から）」と同じ書き方）。英語は “(from version 1.4.1)”。
- 書かなかったこと:
  - 本人の言葉で替わりうる細かい所（契約 §0.4）: 動かしている間の見た目、左右のツールバーの幅と cm の数、3 つを離した形。
  - 契約 §8.5 に無い事: Pencil で書いている最中に等倍を押しても何も起きないこと、VoiceOver の「上へ移す」などの操作、K-8 の句。
- 最終更新の日付と「お知らせ」は変えていない（公開の日にリードが決める。1.4 と同じ）。

## リードの直し（2026-11-22 00:3x）

- 行 1 (a) の「日付を**そのすぐ右に**並べました」を「日付を**その右に**並べました」にした（ja・source-ja・この文書）。広い行では「‹ 今日 ›」と日付の間に等倍のボタンが入るので、「すぐ」は正しくない。契約 §8.3 の案の字から替えた所として docs/R1_4_1.md に書く。
- 審査メモの日本語の要約の「新しい画面の文は…」を「新しい文は…」にした（英語の段の「New text is only in…」に合わせた。読み上げの名前は画面に出ないため）。バイトは数え直した（既定 3,924・(b) 3,921・字 3,926 ＋ 3 × 〈W〉・(b) と字 3,923 ＋ 3 × 〈W〉。〈W〉 は 24 字まで、(b) と一緒なら 25 字まで）。
