# 1.4 の店の文と SUPPORT の案（本人の確認ページで見せる）

**対象の版: 1.4**。ここは案で、どれもまだ Connect にも Web にも入れていない。本人の確認ページ（[M7D_CONTRACT.md](../M7D_CONTRACT.md) §9.4 の 3）で一緒に見せ、「この内容で入れてよい」をもらってから入れる。本人の「この内容で入れてよい」は、ここに書いた全部の組み合わせに効く（契約 §8.1）。どの文を使うかは、提出の前に `duo-hinge` の結果と確かめ表（契約 §10）の答えで決め、M7D.md に書く（1.3 の確認ページの「選ぶ 1」と同じ形）。

## 3. 審査メモと SUPPORT の、条件で替わる文（案 B と Apple Pencil の文。役 N）

- 元: 契約 §8.3（審査メモ）・§8.4（SUPPORT）。
- ファイルには**案 A を入れた**（`docs/store/review-note.txt`・`docs/SUPPORT.md`・`docs/SUPPORT.en.md`）。案 B と、条件が満ちたときだけ入れる Apple Pencil の文は、ファイルに入れずにここに置く。
- 「指でも書く」はアプリの `toolbar.fingerToggle` の ja、「Draw with Finger」は同じキーの en の訳（`tools/l10n/translations/en.json`）と同じ字。
- K-8 の句（古い端末での見え方）は、どの文にも入れない（契約 §5.2。1.4 は新しい欄も新しい形も無い）。

### 3.1 どの文を使うか

| 条件 | 審査メモの (2) と日本語の要約 | SUPPORT の Duo の文 | SUPPORT の Apple Pencil の文 |
| --- | --- | --- | --- |
| 開閉を確かめられた（27.3 の正式版の `duo-hinge` で `DuoHingeUITests` が緑、または本人の Duo で確かめ表の行 18 と 25 が ○。新機能の文の行 1 と同じ条件） | 案 A（今のファイル） | 案 A（今のファイル） | — |
| 開閉を確かめられなかった | 案 B（3.2） | 案 B（3.2） | — |
| 本人の Duo で確かめ表の行 19 と 20 が ○（新機能の文の行 2 と同じ条件） | — | — | 入れる（3.3） |
| 行 19 か 20 が × か「—」 | — | — | 入れない（確かめていない動きは書かない） |

- 審査メモの (3)（Duo の Apple Pencil と「Draw with Finger」）は、Apple Pencil の文を入れないときも書く（契約 §8.3。審査の人が Duo と Pencil で試すときの手引きのため）。

### 3.2 案 B（開閉を確かめられなかったとき）

| 所 | 案 A（今のファイル） | 案 B |
| --- | --- | --- |
| 審査メモの (2)（en） | 2. The layout now follows the window size, not the device type. On iPhone Duo the app fills the screen, inner or outer, and adjusts when the device is opened or closed (the page and handwriting stay the same). To check: open a week page, then open and close the device. | 2. The layout now follows the window size, not the device type. On iPhone Duo the app fills the screen, inner or outer, and fits its width (the page and handwriting stay the same). To check: open a week page, then open and close the device. |
| 審査メモの日本語の要約 | …iPhone Duo では内側・外側の画面いっぱいに出て開閉に追います。… | …iPhone Duo では内側・外側の画面いっぱいに出て幅に合わせます。… |
| SUPPORT（ja） | iPhone Duo では、開いた大きな画面いっぱいに、閉じたときは外側の画面に合わせて表示します（1.4 から）。 | iPhone Duo では、画面の幅に合わせて表示します（1.4 から）。 |
| SUPPORT（en） | On iPhone Duo, the App fills the large screen when the device is open, and fits the outer screen when it is closed (from version 1.4). | On iPhone Duo, the App fits the width of the screen (from version 1.4). |

- 審査メモの案 B は、契約 §8.3 のとおり (2) の「開閉に追う」（adjusts when the device is opened or closed）を「幅に合わせる」（fits its width）に替えるだけ。案 B の審査メモは 3,964 バイト（`wc -c`。最後の改行を除くと 3,963 バイト・3,687 字）。
- **リードが決めること（案 B のときだけ）**: 契約は (2) の句の入れ替えだけを言うので、案 B でも確かめ方「To check: open a week page, then open and close the device.」と括弧「(the page and handwriting stay the same)」は残る。残すと、確かめられていない開閉を審査の人に試してもらうことになる。替えるときの候補（契約に無い文。使うなら元を見ない逆翻訳をしてから）: 括弧を外し、確かめ方を「To check: open a week page on the inner screen and on the outer screen.」にする（バイトは減る）。既定は契約のまま（残す）。

### 3.3 SUPPORT の Apple Pencil の文（まだ入れていない）

- 条件: 本人の Duo で確かめ表の行 19 と 20 が ○（契約 §8.4。新機能の文の行 2 と同じ条件）。
- 入れる所: 「iPhone や Mac でも使えますか？」の節の「手書きは指で書きます（ツールバーの「指でも書く」）。」のすぐ後（その文は、ふつうの iPhone の話として残す）。英語の `SUPPORT.en.md` も同じ所（「On iPhone, you write with your finger (“Draw with Finger” in the toolbar).」のすぐ後）。今のファイルでは、その所に Duo の表示の文（案 A）が続いているので、Apple Pencil の文はその前に入る。

| 言語 | 入れる文 |
| --- | --- |
| ja | iPhone Duo では iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かします。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。 |
| en | On iPhone Duo, as on iPad, you write with Apple Pencil (USB-C, iOS 27.2 or later) and move the paper with your finger. If you also want to write with your finger, turn on “Draw with Finger” in the toolbar. |

- 入れた後の段落（案 A のとき）:
  - ja: iPhone でも使えます（iOS 17 以上）。手書きは指で書きます（ツールバーの「指でも書く」）。**iPhone Duo では iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かします。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。** iPhone Duo では、開いた大きな画面いっぱいに、閉じたときは外側の画面に合わせて表示します（1.4 から）。iPad と iPhone で同じ Apple Account の iCloud を使うと、手書きが同期されます。…
  - en: You can use it on iPhone (iOS 17 or later). On iPhone, you write with your finger (“Draw with Finger” in the toolbar). **On iPhone Duo, as on iPad, you write with Apple Pencil (USB-C, iOS 27.2 or later) and move the paper with your finger. If you also want to write with your finger, turn on “Draw with Finger” in the toolbar.** On iPhone Duo, the App fills the large screen when the device is open, and fits the outer screen when it is closed (from version 1.4). If you use the iCloud of the same Apple Account on iPad and iPhone, your handwriting syncs. …

### 3.4 審査メモの (3) の折り目の句（`PencilPhone.usesHinge` が false のまま出すとき）

- 契約 §8.3 の (3) は、Apple Pencil の触れか画面の折り目（`UIHingeInteraction`）で「Draw with Finger」をオフにすると書く。けれども折り目を見るのは `PencilPhone.usesHinge` が true のときだけ（契約 §4.8・§4.2。Duo のシミュレータで測れたとき）で、今のコードは false（M7D.md の「測ってから決める物」）。false のまま出すと、折り目の句は本当でない。
- そのときは (3) の 2 つ目の文を次に替える（ほかの文は同じ。日本語の要約は折り目を言わないので替えない）。

| `usesHinge` | (3) の 2 つ目の文（en） |
| --- | --- |
| true（今のファイル） | The app turns Draw with Finger off when that iPhone first sees an Apple Pencil touch or a screen hinge (UIHingeInteraction); on a device updated from 1.3, only an Apple Pencil touch does this. |
| false | The app turns Draw with Finger off when that iPhone first sees an Apple Pencil touch. |

- バイトは減る（4,000 の内）。決めるのは duo-shots で `usesHinge` を決めた後（リード）。

### 3.5 今のファイルに入れたもの（案 A）の覚え

- 審査メモ: 「What is new in 1.3」の段（1〜5 と Unchanged の行）を「What is new in 1.4」の 4 つに入れ替え、日本語の要約の 1.3 の分（「週と日のページが…穴を直しました。」）を 1.4 の分に入れ替えた。ほかの段（サインイン不要・言語・確かめ方（To test。1.3 の確かめ方の文も残した）・購読・記録・サーバー無し・6 つの URL）と、要約の最後の「データ・購入・年齢区分は同じ。規約類は日本語が正本で、英語は参考訳。サインイン不要。」は 1 字も変えていない。1.2 からの段は短くしていない。**3,993 バイト**（`wc -c`。最後の改行を除くと 3,992 バイト・3,716 字。`lint.py --only L-9` は ok）。1.3 の 1 の「It」と 4 の言い方の △ は、段ごと替わったので無くなった（契約 §1.5）。
- 審査メモの年齢区分: 4+ のまま、新しい 2 問（Shared Location・Dating and Relationships）はどちらも No と書いた（契約 §9.5）。1.3 の行にあった「the age range check of 1.2.2」は、契約 §8.3 の (4) に無いので書いていない。
- SUPPORT の Duo の文: 契約 §8.4 は節だけを言い、文の位置を言わないので、「手書きは指で書きます（ツールバーの「指でも書く」）。」の後に置いた。節の最初の「iPhone でも使えます（iOS 17 以上）。」のすぐ後に置くと、続く「手書きは指で書きます」が Duo の話に読めて、その文をふつうの iPhone の話として残す契約の形と合わないため。英語も同じ所。
- SUPPORT の「最終更新」の日付と「お知らせ」は変えていない（1.3 も変えていない。公開の日に Web へ出すときにリードが決める）。
