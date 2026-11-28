# ストア 1.4.3 の逆翻訳（en：新機能の文・審査メモの 1.4.3 の段・SUPPORT.en.md の新しい FAQ と替わった文）

D2 の R（元を見ない逆翻訳の役の Claude）が、日本語の元を見ずに訳し戻した表です（2026-11-28 12:23〜 JST に書いた）。R はこの仕事の間、日本語の元を一度も開いていません。元との照らし合わせ（○・△・×）は R の仕事に入れていないので、このファイルにはありません（判定はリードが [REVIEW.md](../REVIEW.md) の 20 で行う）。母語の人の確認ではありません。10 の訳の新機能の文は [store-1_4_3.md](store-1_4_3.md) です。判定の後に替えた英語の 7 文の 2 回目の逆翻訳は、最後の節「2 回目」です（1 回目の表は替える前の字のまま）。

- **R が読んだもの**（逆翻訳を書く前。どれも枝 `r143-w-d2s` の 50d0779）: `docs/store/en-US/whatsnew.txt` を丸ごと。`docs/store/review-note.txt` の 1〜12 行（日本語の字を含む行は機械で伏せて読んだ。ファイル全体で伏せた行は 3）と、66ec030 からの差分（同じく伏せた。英語で替わったのは「What is new in 1.4.3」の段だけ）。`docs/SUPPORT.en.md` の 66ec030 からの差分（日本語の字を含む行は機械で伏せて読んだ。伏せた行は 0）と、見出しの一覧と、替わった所のまわりの英語の行。替わった 3 つの段落は、前の英語（差分の - の行）と文ごとに機械で照らし、新しい文と替わった文だけを訳し戻した（同じ字の文は訳していない）。
- **差分の起点**: 指示の `r143..HEAD` の `r143` は、この枝を切った後に 2 つ進んでいる（e044831。店の ja のプロモーションテキストと en のサブタイトル・キーワード）ので、この枝の起点 66ec030（`git merge-base r143 HEAD`）から見た。
- **読んでいないもの**: 日本語の元（`docs/store/source-ja`・`docs/store/ja`、`docs/SUPPORT.md`、審査メモの日本語の要約）、契約 R1_4_3_CONTRACT.md（どの節も開いていない）、`docs/i18n/GLOSSARY.md`、`docs/store/PROPOSALS_1_4_3.md`、この枝の `docs/store/README.md`、記録 `docs/R1_4_3.md`、アプリの字（`tools/l10n`・`Localizable.xcstrings`。日本語も en の訳も）、X と W の報告。
- **先に目に入ったもの**: [store-1_4_3.md](store-1_4_3.md) の頭の 1〜5 と同じです。とくに、この役への指示の文（英語）に、月の形のア（いちばん短い月の最後の行が伸びて、メモ欄がそろう）と、アプリの日本語の語の名前「指でも書く」「等倍」「メモ欄」がありました。だから S.m6a〜S.m6c（月の最後の行が伸びる話）と、notes area を「メモ欄」と訳し戻した所は、元を見ない逆翻訳として少し弱い物です。新機能の文の 3 つ目の点の出だしが「iPad と iPhone の両方を」であることも先に分かっていました（W3 の ＊）。
- アプリの語（引用符つきの名前と、設定の道の名前）は、英語の字のあとに R の訳を（）で添えました。アプリの字を見ていないので、（）の中はアプリの ja の字と違ってかまいません。
- 文は 1 つずつ訳し戻し、文の数と順を英語と同じにしました。
- **【年】**: 年のページのことを言っている行です。年が 1.4.4 に遅れたときに替わる見込みの行（R の見立て）。最後の節に一覧があります。

## 新機能の文（`docs/store/en-US/whatsnew.txt`）

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.3.W1.en-US | • Month and year pages are now also joined sideways with the pages before and after them. Slide your finger sideways to bring in the neighboring month or year (when “Use Finger” is on, move sideways with two fingers). You can write straight across the boundary: on month pages, in the notes area at the bottom; on year pages, from December into January of the next year. | ・月と年のページも、今は前と後ろのページと横につながっています。指を横へ滑らせると、隣の月や年が入ってきます（“Use Finger”（指を使う）がオンのときは、2 本の指で横へ動かします）。境目をまっすぐまたいで書けます: 月のページでは、下のメモ欄（notes area）で。年のページでは、12 月から次の年の 1 月へ。 | 【年】「also（も）」が何と同じかは、この点には書いていない（日と週のページは 2 つ目の点で初めて出る）。straight は「そのまま」とも「まっすぐ」とも読める。notes area は小文字で引用符が無い（アプリの名前としてではなく、ふつうの名詞として書いている） |
| 1.4.3.W2.en-US | • On month and year pages too, the button with a magnifying glass and “1” now resets the zoom so that one page fits the width of the screen exactly, as on day and week pages. | ・月と年のページでも、虫めがねと「1」のボタンが、今は、日と週のページと同じように、1 ページが画面の幅にちょうど合うようにズームを戻します。 | 【年】「虫めがねと 1」で、1 が虫めがねの中か横かは書いていない（SUPPORT.en と審査メモは「a magnifying glass with “1”」＝ 1 の付いた虫めがね） |
| 1.4.3.W3.en-US ＊ | • Please update both your iPad and your iPhone to this version. On older versions, strokes written across pages appear on only one of the pages (they have not been deleted). If you erase such a stroke on an older version, it is erased in this version too. | ・iPad と iPhone の両方を、この版に更新してください。古い版では、ページをまたいで書いた線は、ページのうち 1 つにだけ出ます（消されたのではありません）。古い版でそのような線を消すと、この版でも消えます。 | 1.3 の公開の字（8efca47）と 1 字も同じ。「古い版」がどの版までか（月と年のページの線では 1.4.2 まで）は書いていない |
| 1.4.3.AI.en-US | Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes. | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | 1.4.2（66ec030）と 1 字も同じ。参考 |

## 審査メモ（`review-note.txt` の「What is new in 1.4.3」）

見出し「What is new in 1.4.3」は「1.4.3 の新しいこと」。文ごとに分けました（a・b…は R が付けた印で、ファイルには無い）。

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| RN143.1a | 1. Month and year pages now join sideways with the pages before and after, as week and day pages have since 1.3. | 1. 月と年のページが、週と日のページが 1.3 からそうであるように、今は前と後ろのページと横につながります。 | 【年】 |
| RN143.1b | On a month page, handwriting can cross from one month to the next in the notes area below the calendar; on a year page, from December into January of the next year. | 月のページでは、カレンダーの下のメモ欄（notes area）で、手書きが 1 つの月から次の月へまたげます。年のページでは、12 月から次の年の 1 月へ。 | 【年】「from one month to the next」は向きを 1 つだけ書いているが、境目をまたぐという意味と読める |
| RN143.1c | Settings > Pages turns it off. | 設定 > Pages（ページ）が、それをオフにします。 | 「it」は横につながること。週と日のつながりも一緒にオフになるのか、月と年だけかは、この文からは分からない（SUPPORT.en では全部のページが 1 枚ずつになる）。Pages の中の項目の名前は書いていない |
| RN143.2 | 2. The 1× button (a magnifying glass with "1") now fits one month or one year page to the screen width, as it does for days and weeks. | 2. 1× のボタン（「1」の付いた虫めがね）は、日と週でそうしているように、今は 1 つの月のページまたは 1 つの年のページを画面の幅に合わせます。 | 【年】ボタンの名前を「1×」と書き、形を（ ）で書いている。「ズームを戻す」とは書かず「幅に合わせる」と書いている |
| RN143.3 | 3. To check: open a month page, swipe left with one finger (two fingers when "Use Finger" is on, the default on iPhone) and write across the boundary in the notes area. | 3. 確かめ方: 月のページを開き、1 本の指で左へスワイプし（"Use Finger"（指を使う）がオンのときは 2 本の指。iPhone ではそれが最初の設定）、メモ欄（notes area）で境目をまたいで書いてください。 | 「the default on iPhone」は、"Use Finger" がオンなのが iPhone の最初の設定、と読める。スワイプの後に境目が画面に見えたままか（指を離すと次の月にぴったり止まるのか、途中で止まるのか）は書いていない。年のページの確かめ方は無い |
| RN143.4 | 4. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating. | 4. 変わらないもの: データ（App のプライバシーは「データの収集なし」のまま）、手書きの保存、購入、年齢区分。 | 1.4.2 の 3 と番号のほかは 1 字も同じ。参考 |

## SUPPORT.en.md

### How do I keep writing onto the neighboring page on month and year pages?（月と年のページで、隣のページへ続けて書くには？）【年】

新しい FAQ です（「How do I hide the toolbar?」の後、「How do I zoom in and out?」の前）。

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.j.1 | Like week and day pages (from version 1.3), month and year pages are joined sideways with the pages before and after them (from version 1.4.3). | 週と日のページ（バージョン 1.3 から）と同じように、月と年のページは、前と後ろのページと横につながっています（バージョン 1.4.3 から）。 | 【年】 |
| S.j.2 | Slide your finger sideways to bring in the neighboring month or year (when “Use Finger” is on, move sideways with two fingers). | 指を横へ滑らせると、隣の月や年が入ってきます（“Use Finger”（指を使う）がオンのときは、2 本の指で横へ動かします）。 | 【年】新機能の文の 1 つ目の点の 2 文目と 1 字も同じ |
| S.m0 | On month pages: | 月のページでは: | なし |
| S.m1 | The dates do not continue from one month's calendar to the next (on the same row, the calendar on the right is 4 to 5 weeks later). | 日付は、1 つの月のカレンダーから次の月のカレンダーへは続いていません（同じ行では、右のカレンダーは 4〜5 週あとです）。 | 「4 to 5 weeks later」は、同じ行の右のカレンダーの日付が 4〜5 週あと、と読める |
| S.m2 | The notes area at the bottom is where you can write across the boundary between months. | 下のメモ欄（notes area）が、月と月の境目をまたいで書ける所です。 | なし |
| S.m3 | The notes areas line up into one long strip, so you can keep writing straight into the neighboring month. | メモ欄が並んで 1 本の長い帯になるので、隣の月へそのまま（まっすぐ）書き続けられます。 | なし |
| S.m4 | To write from the end of one month into the start of the next by date, write within one month's calendar or on a week page, as before. | 日付で見て、ある月の終わりから次の月の初めへ書くには、今までどおり、1 つの月のカレンダーの中か、週のページに書いてください。 | 「by date」は「日付のマスの上で」と読んだ。1 つの月のカレンダーの中でどう月をまたぐか（前後の月の薄いマスを使う）は、この文には無く、次の文から読める |
| S.m5a | The faded cells for days of the previous or next month appear in both calendars (so one screen can show the same day twice, and if it is today, both have the mark for today). | 前の月や次の月の日の薄いマスは、両方のカレンダーに出ます（だから 1 つの画面に同じ日が 2 回出ることがあり、それが今日なら、両方に今日の印があります）。 | 「both calendars」は、隣り合う 2 つの月のカレンダーと読める |
| S.m5b | What you write in one of them stays in that calendar and does not appear on the same day in the calendar next to it. | そのどちらかに書いたものは、そのカレンダーに残り、隣のカレンダーの同じ日には出ません。 | 「one of them」は、2 回出た同じ日のマスのどちらか、と読める |
| S.m6a | In a month whose calendar is shorter than the neighboring month's because it has fewer events or less writing, the bottom row grows so that the notes areas line up (what you wrote in the notes area moves down with it, so your writing and the lines stay together). | 予定が少ない、または書いたものが少ないために、カレンダーが隣の月のものより短い月では、メモ欄の高さがそろうように、いちばん下の行が伸びます（メモ欄に書いたものもそれと一緒に下へ動くので、手書きと線は離れません）。 | 短くなるわけとして、予定と書いたものの量だけを書いている（月の週の行の数が違うときのことは書いていない）。「the lines」は、メモ欄の罫線と読んだ。「with it」は、伸びた行（またはメモ欄）と一緒に、と読める |
| S.m6b | What you write in the grown part goes into the cells of that row. | 伸びた部分に書いたものは、その行のマスに入ります。 | なし |
| S.m6c | When pages are shown one at a time (when the joining is turned off, or on a device with version 1.4.2 or earlier), that row grows to fit what you wrote there. | ページが 1 枚ずつ出るとき（つなぎをオフにしたとき、またはバージョン 1.4.2 以前の端末で）は、その行は、そこに書いたものに合うように伸びます。 | 「there」は、伸びた部分（その行）に書いたもの、と読める |
| S.y0 | On year pages: | 年のページでは: | 【年】 |
| S.y1a | To the right of December come the date column and January to December of the next year. | 12 月の右に、日付の列と、次の年の 1 月から 12 月が来ます。 | 【年】 |
| S.y1b | You can write straight across the boundary from December into January of the next year. | 12 月から次の年の 1 月へ、境目をまっすぐまたいで書けます。 | 【年】間に日付の列があるので、またいだ線は日付の列の上を通る、と読める |
| S.y2 | Row heights line up with the neighboring year, so that the same dates run in one straight line across. | 行の高さは隣の年とそろうので、同じ日付が横に 1 本のまっすぐな線で並びます。 | 【年】「so that」は目的（そろえてある）とも結果とも読める。意味は同じ |
| S.y3a | On an iPhone in landscape, a year page zooms out only as far as three years across the screen (it also opens at this size). | 横向きの iPhone では、年のページは、画面の横に 3 年が並ぶところまでしか縮まりません（開いたときもこの大きさです）。 | 【年】「three years across the screen」は、画面の幅に 3 年分が並ぶ大きさ、と読んだ |
| S.y3b | A whole year does not fit from top to bottom, so slide up and down to see it. | 1 年の全部は上から下まで入らないので、上下に滑らせて見てください。 | 【年】 |
| S.j.3 | If you turn off “Join Neighboring Pages Sideways” in the App's Settings > Pages, all pages are shown one at a time, as before. | アプリの 設定 > Pages（ページ）で “Join Neighboring Pages Sideways”（隣のページと横につなぐ）をオフにすると、今までどおり、すべてのページが 1 枚ずつ出ます。 | 「all pages」で、週と日も一緒に 1 枚ずつになると分かる |

### How do I zoom in and out?（拡大と縮小は？）の替わった 2 文

段落の 1 文目を替え、2 文目を足した（3〜7 文目は前の字のまま）。

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.z.1 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” at the top right, to reset the zoom at once (from version 1.4.1): on day, week, month and year pages alike, one page fits the width of the screen exactly (on month and year pages, from version 1.4.3). | 右上の “‹ Today ›”（‹ 今日 ›）の隣にある、「1」の付いた虫めがねを示すボタン（Reset Zoom（ズームを戻す））をタップすると、ズームが一度に戻ります（バージョン 1.4.1 から）: 日・週・月・年のページのどれでも同じように、1 ページが画面の幅にちょうど合います（月と年のページでは、バージョン 1.4.3 から）。 | 【年】前の字は「月と年のページでは、最初に開いたときの大きさに戻る」だった（英語の - の行）。それを替えた |
| S.z.2 | Where a page already fits the width of the screen when it opens, such as a month page on an iPad in portrait, or a month or year page on an iPhone in portrait, tapping the button hardly changes how the page looks, but the App still remembers that you reset the zoom, so the page fits the width of the screen when you then turn your device to landscape. | 縦向きの iPad の月のページや、縦向きの iPhone の月や年のページのように、開いたときにもうページが画面の幅に合っている所では、ボタンをタップしてもページの見た目はほとんど変わりませんが、アプリはそれでもズームを戻したことを覚えているので、そのあと端末を横向きにしたとき、ページは画面の幅に合います。 | 【年】（iPhone の縦の年のページ）。「Where」は「〜の所では・〜のときは」 |

### How do I change the notes paper?（メモの紙を変えるには？）の替わった 2 文

2 つ目の段落の 2 文目を替え、3 文目を足した（ほかは前の字のまま）。

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.p.1 | The same goes for pages joined sideways (week, day and month pages). | 横につながったページ（週・日・月のページ）も同じです。 | 前の字は「横に並んでつながった週と日のページも同じ」。年のページはメモ欄が無いので入っていない、と読める |
| S.p.2 | On month pages, the lines or dots are at the same heights as those of the neighboring month. | 月のページでは、線や点は、隣の月の線や点と同じ高さにあります。 | なし |

### What if my iPad and iPhone have different versions?（iPad と iPhone の版が違うときは？）の足した 1 段落

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.v.1 | On a device with version 1.4.2 or earlier, a stroke written across the boundary between month pages or between year pages (from version 1.4.3) appears only on the page where it is saved and looks cut off at the edge of the paper (it has not been deleted; if you erase that stroke on that device, it is erased on the new version too). | バージョン 1.4.2 以前の端末では、月のページどうし、または年のページどうしの境目をまたいで書いた線（バージョン 1.4.3 から）は、それが保存されているページにだけ出て、紙の端で切れたように見えます（消されたのではありません。その端末でその線を消すと、新しいバージョンでも消えます）。 | 【年】「(from version 1.4.3)」は、境目をまたいで書けるのが 1.4.3 から、と読める |

### Known limitations（既知の制限）の「Handwriting across cells」の行の替わった 3 文

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.l.1 | From version 1.3, week and day pages are joined side by side with the pages before and after them, and you can write across the borders between them. | バージョン 1.3 から、週と日のページは前と後ろのページと横に並んでつながり、その間の境目をまたいで書けます。 | 前の字の最後の（ ）「月と年のページは今までどおり 1 ページずつ」を外しただけ |
| S.l.2 | From version 1.4.3, month and year pages are joined in the same way (on month pages, you can write across in the notes area at the bottom). | バージョン 1.4.3 から、月と年のページも同じようにつながります（月のページでは、下のメモ欄（notes area）でまたいで書けます）。 | 【年】字に「も」は無いが、「in the same way」から「も」と読める |
| S.l.3 | On a device still on a version before 1.3 (for month and year pages, on version 1.4.2 or earlier), that stroke appears only on the page where it is saved (it has not been deleted). | まだ 1.3 より前のバージョンの端末では（月と年のページについては、バージョン 1.4.2 以前の端末では）、その線は、それが保存されているページにだけ出ます（消されたのではありません）。 | 【年】（ ）の中を足した |

## R の気づき（リードへ。直していない）

1. **notes area の大文字**: 新しい文（新機能の文・審査メモ・新しい FAQ・S.l.2）はどれも小文字の「notes area」。メモの紙の FAQ の前からの文は「The Notes area of the month page」と大文字で、同じ欄を 2 つの書き方で言っている。意味は通る。
2. **虫めがねと「1」**: 新機能の文は「the button with a magnifying glass and “1”」、SUPPORT.en は「a magnifying glass with “1”」、審査メモは「The 1× button (a magnifying glass with "1")」。同じボタンと分かる。
3. **新機能の文の 1 つ目の点の「also」**: 何と同じかがこの点の中に無い（10 の訳も同じ。store-1_4_3.md の気づきの 1）。
4. **審査メモの 1c と 3**: 1c の「it」がどこまでをオフにするか、3 のスワイプの後に境目が見えたままか、はこの段からは分からない。審査の人が月の境目を見つけられないと、確かめが止まるかもしれない。
5. **S.m6a**: カレンダーが短くなるわけを、予定と書いたものの量だけで書いている。週の行の数（月によって違う）でも高さが変わるのかは、R には分からない（アプリを見ていない）。判定で中身と照らしてほしい。
6. **新機能の文の 3 つ目の点は 1.3 の字のまま**: 「古い版」がどの版までかを書いていない。SUPPORT.en（S.v.1・S.l.3）は「1.4.2 以前」と書いている。

## 年が 1.4.4 に遅れたときに替わる見込みの行（R の見立て）

- 新機能の文: W1・W2（en-US と 10 の訳の全部、22 行）。W3 と AI の行は年を言っていない。
- 審査メモ: RN143.1a・1b・2。1c・3・4 は年を言っていない（3 は月だけ）。
- SUPPORT.en: 見出しと S.j.1・S.j.2、年のページの段の全部（S.y0〜S.y3b）、S.z.1・S.z.2、S.v.1、S.l.2・S.l.3。S.j.3（全部のページ）と月の段（S.m0〜S.m6c）とメモの紙の 2 文（S.p.1 は「週・日・月」で年は入っていない）は年を言っていない。

## 2 回目（2026-11-28 12:40〜 JST。判定の後に替えた英語の 7 文だけ）

判定の 2 役（J・T）の should と nit のうち、英語の字を替えた所です（[REVIEW.md](../REVIEW.md) の 20）。上の 1 回目の表は、替える前の字のまま残しています（記録）。

- **誰が訳し戻したか（正直に書きます）**: 2 回目は、X と W を兼ねる直しの役の Claude が、替えた英語の字だけを見て、文の字から読めることだけで訳し戻しました。ただ、**この Claude は直す前に日本語の元（`docs/SUPPORT.md`・`docs/store/ja`・審査メモの要約）と判定の指摘を読んでいます**。だから 1 回目の R より弱い、元を見ない逆翻訳です（REVIEW.md の 18.x と同じ形）。この作業の場には、別の Claude を立てる道具がありませんでした。別の Claude の 2 回目が要るとリードが決めたときは、下の表の id と「訳」の列だけを渡せます。
- 字はファイルから機械で写しました。en-GB・en-AU・en-CA は en-US と同じ字です。
- **【年】** は 1 回目と同じ意味です（年が 1.4.4 に遅れたときに替わる行）。

| id | 訳（2 回目に読んだ字） | 元を見ない逆翻訳（2 回目） | 注 |
| --- | --- | --- | --- |
| 1.4.3.W2.en-US（2 回目） | • On month and year pages too, the button showing a magnifying glass with “1” now resets the zoom so that one page fits the width of the screen exactly, as on day and week pages. | ・月と年のページでも、「1」の付いた虫めがねが表示されたボタンが、今は、日と週のページと同じように、1 ページが画面の幅にちょうど合うようにズームを戻します。 | 【年】「a magnifying glass with “1”」は「1 の付いた（1 を持つ）虫めがね」で、1 つの印と読める（「and」の形のように、虫めがねと 1 が並ぶとは読みにくい）。SUPPORT.en の S.z.1 の「the button showing a magnifying glass with “1”」と 1 字も同じ |
| RN143.1c（2 回目） | Settings > Pages turns it off for all page types. | 設定 > Pages（ページ）で、すべての種類のページについて、それをオフにできます。 | 「it」は前の文までの「横につながること」。「for all page types」で、月と年だけでなく週と日も一緒にオフになると読める。スイッチの名前は書いていない |
| RN143.3（2 回目） | 3. To check: open a month page, drag left slowly with one finger (two fingers when "Use Finger" is on, the default on iPhone) until the boundary between two months is in the middle of the screen, and write across it in the notes area. | 3. 確かめ方: 月のページを開き、1 本の指で（"Use Finger"（指を使う）がオンのときは 2 本の指で。iPhone ではそれが最初の設定）、2 つの月の境目が画面の真ん中に来るまでゆっくり左へドラッグして、メモ欄（notes area）でその境目をまたいで書いてください。 | 「it」は「the boundary between two months」。止める所（画面の真ん中）を言っているので、どこで書けばよいかが字から分かる。年のページの確かめ方は無い（月だけ） |
| S.m6c（2 回目） | When pages are shown one at a time (when “Join Neighboring Pages Sideways” is turned off, or on a device with version 1.4.2 or earlier), that row grows to fit what you wrote there. | ページが 1 枚ずつ出るとき（“Join Neighboring Pages Sideways”（隣のページを横につなぐ）がオフのとき、またはバージョン 1.4.2 以前の端末で）は、その行は、そこに書いたものに合わせて伸びます。 | 1 回目の「the joining」を、設定のスイッチの名前（S.j.3 と同じ字）に替えた。何をオフにするのかが字から分かる |
| S.z.0（2 回目。拡大・縮小の FAQ の 1 段落目の 4 文目） | When you pinch to zoom out, you can see the whole calendar (on pages joined sideways, such as a year page on an iPhone in landscape, you may need to slide up and down). | つまんで縮小すると、カレンダー全体が見えます（横につながったページ、たとえば横向きの iPhone の年のページでは、上下に滑らせなければならないことがあります）。 | 【年】（例が年のページ）。括弧で、全体が一度に縦に入らないことがある、と読める。どのページでそうなるかは例 1 つだけで、全部は書いていない。1 回目では替わっていない文なので、1 回目の表に行は無い |
| S.l.1（2 回目） | From version 1.3, week and day pages are joined sideways with the pages before and after them, and you can write across the boundary between them. | バージョン 1.3 から、週と日のページは前と後ろのページと横につながり、その間の境目をまたいで書けます。 | 1 回目の「joined side by side」「the borders between them」を、新しい FAQ と同じ「joined sideways」「the boundary」に替えた。同じ行の「cell borders」（マスの境界）と語が分かれた |
| S.l.4（2 回目。既知の制限の行の、設定でオフにする文） | If you turn off “Join Neighboring Pages Sideways” in the App's Settings > Pages, pages are shown one at a time, as before. | アプリの 設定 > Pages（ページ）で “Join Neighboring Pages Sideways”（隣のページを横につなぐ）をオフにすると、今までどおり、ページは 1 枚ずつ出ます。 | 前の字は「the side-by-side joining」。S.j.3 と同じスイッチの名前になった。すぐ後の文「On a device where it is turned off, …」の「it」は、このスイッチと読める（その文は替えていない）。1 回目では替わっていない文なので、1 回目の表に行は無い |

### 2 回目の気づき（直していない）

1. **S.z.0 の例**: 例は iPhone を横にした年のページだけです。年が 1.4.4 に遅れたときは、年のページは横につながらないので、この例を替えるか括弧を外します（リード。週のページも当たるかは、iPhone 横の週の上限 3 ページで確かめてから）。
2. **RN143.3 の長さ**: 1 回目より 66 バイト長くなりました。審査メモは 3,789 バイトで、4,000 バイトの中です。
