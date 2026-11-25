# ストア 1.4.2 の逆翻訳（en：新機能の文・審査メモの 1.4.2 の段・SUPPORT.en.md の 2 つの FAQ と版の FAQ の 1 文）

R が日本語の元を見ずに訳し戻した表です（2026-11-26 05:1x、D2 の R）。母語の人の確認ではありません。日本語の元との照らし合わせ（○・△・×）は、逆翻訳を書き終えてから元を読んで行い、最後の節「元との照らし合わせ」に書きました。

- **R が読んだもの**（逆翻訳を書く前）: 枝 `r142-w-d2a`（b33485a）の `docs/store/en-US/whatsnew.txt`、`docs/store/review-note.txt` の「What is new in 1.4.2」の段（日本語の字を含む行は機械で伏せて読んだ）、`docs/SUPPORT.en.md` の 0d9241a からの差分（日本語の字を含む行は機械で伏せて読んだ。伏せた行は 0）。
- **読んでいないもの**（逆翻訳を書く前）: 日本語の元（`docs/store/source-ja`・`docs/store/ja`、`docs/SUPPORT.md`、審査メモの日本語の要約、契約 R1_4_2_CONTRACT.md の §8）、アプリの日本語の字（`tools/l10n/source`・`Localizable.xcstrings`・J-1）。
- **先に目に入ったもの**（正直に書きます）: `docs/store/README.md` の審査メモの「1.4.2 から」の段（A が書いた、1.4.2 の段の 3 つの中身の日本語の説明。元の文そのものではない）と、同じ README の新機能の文の表の 1.4.2 の行の頭（「3 つの点。ペンの色・メモ欄の紙・ダークモードの丸」まで）、commit b33485a の英語の本文。審査メモの 3「Unchanged: …」は 1.4.1 の 4 と同じ字で、その 1.4.1 の逆翻訳（`store-1_4_1-en.md` の RN141.4）も書式を見るときに目に入りました。3 の判定は 1.4.1 のもの（REVIEW.md の 14・16.y）が今も有効なので、下の 3 は参考です。
- en-GB・en-AU・en-CA は en-US の写しです（`docs/store/locales.json` の `copyOf`）。
- アプリの語（Other Color…・Reset Colors・Brown・Notes Paper・Lined・Dot Grid・Blank・Notes・Free Notes・This Page as PDF）は、英語の字のあとに R の訳を（）で添えました。アプリの日本語の字は見ていないので、（）の中はアプリの ja の字と違ってかまいません。

## 新機能の文（`docs/store/en-US/whatsnew.txt`）

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.2.W1.en-US | • Added more pen colors. Tap the highlighted color dot again (or touch and hold it) to replace its color with one of 12 colors or any color you like. | ・ペンの色を増やしました。強調表示されている色の丸をもう一度タップする（または長押しする）と、その丸の色を、12 色のどれか、または好きな色に替えられます。 | 「12 色」に前からの色が入っているかは、この行からは分かりません。「好きな色」をどう選ぶか（システムの色選び）は書いていません。ペンを選んでいるときの話だとは書いていませんが、「pen colors」から読めます |
| 1.4.2.W2.en-US | • Added “Notes Paper” to Settings. For the paper of the “Notes” and “Free Notes” areas, you can choose “Lined”, “Dot Grid” or “Blank”. Your handwriting stays as it is. | ・設定に「Notes Paper（メモの紙）」を加えました。「Notes（メモ）」と「Free Notes（自由メモ）」の欄の紙を、「Lined（罫線）」「Dot Grid（ドット方眼）」「Blank（無地）」から選べます。手書きはそのままです。 | どのページの欄かは書いていません |
| 1.4.2.W3.en-US | • In Dark Mode, the dark color dots in the toolbar are now easier to see. | ・ダークモードで、ツールバーの暗い色の丸が見やすくなりました。 | どの色が「暗い色」か、どう見やすくしたか（縁など）は書いていません |
| 1.4.2.AI.en-US | Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes. | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | 1.4.1 と同じ字 |

## 審査メモ（`review-note.txt` の「What is new in 1.4.2」）

見出し「What is new in 1.4.2」は「1.4.2 の新しいこと」。文ごとに分けました（a・b…は R が付けた印で、ファイルには無い）。

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| RN142.1a | 1. Pen colors: tap the selected color dot again (or touch and hold it) to open a small panel with 12 colors, "Other Color…" (the system color picker) and "Reset Colors". | 1. ペンの色: 選ばれている色の丸をもう一度タップする（または長押しする）と、12 色と "Other Color…"（ほかの色…。システムの色選び）と "Reset Colors"（色をリセット）の入った小さなパネルが開きます。 | なし |
| RN142.1b | The choice replaces that dot and is remembered on this device. | 選んだものがその丸と入れ替わり、この端末に記憶されます。 | 字のとおりだと「丸と入れ替わる」で、「丸の色と入れ替わる」の意味に読むのが自然です |
| RN142.1c | Stroke data is unchanged (each stroke already stores its color as a hex value). | 線のデータは変わっていません（どの線も、前から色を 16 進の値で持っています）。 | なし |
| RN142.1d | To check: open a week page, tap the black dot again, choose Brown and write. | 確かめ方: 週のページを開き、黒の丸をもう一度タップし、Brown（茶色）を選んで書いてください。 | 「again」は、黒の丸がすでに選ばれている（最初の色が黒）ことを前提にした書き方です。ペンを選ぶ手順は書いていません |
| RN142.2a | 2. Settings > Notes Paper: Lined, Dot Grid or Blank for the Notes and Free Notes areas. | 2. 設定 > Notes Paper（メモの紙）: Notes（メモ）と Free Notes（自由メモ）の欄に、Lined（罫線）・Dot Grid（ドット方眼）・Blank（無地）のどれか。 | 動詞の無い短い書き方です（「選べる」と読めます） |
| RN142.2b | Only the pattern drawn on the paper changes; handwriting does not move. | 変わるのは紙に描かれる模様だけで、手書きは動きません。 | なし |
| RN142.3 | 3. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating. | 3. 変わらないもの: データ（App のプライバシーは「データの収集なし」のまま）、手書きの保存、購入、年齢区分。 | 1.4.1 の 4 と同じ字（番号だけ違う）。参考 |

## SUPPORT.en.md

### How do I change the pen color?（ペンの色を変えるには？）

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.pen.1 | When you choose the pen, six color dots appear in the toolbar. | ペンを選ぶと、ツールバーに 6 つの色の丸が出ます。 | なし |
| S.pen.2 | Tap the highlighted dot (the current pen color) again, or touch and hold it, and a color panel opens next to that dot (from version 1.4.2). | 強調表示されている丸（今のペンの色）をもう一度タップするか長押しすると、その丸の隣に色のパネルが開きます（バージョン 1.4.2 から）。 | なし |
| S.pen.3 | The panel has 12 colors (the six colors from before and six new ones), “Other Color…” and “Reset Colors”. | パネルには、12 色（前からの 6 色と新しい 6 色）と「Other Color…（ほかの色…）」と「Reset Colors（色をリセット）」があります。 | なし |
| S.pen.4 | With “Other Color…”, you can choose any color in the color picker that comes with iPad and iPhone. | 「Other Color…」では、iPad と iPhone に付いている色選び（カラーピッカー）で、どんな色でも選べます。 | なし |
| S.pen.5 | The color you choose goes into the dot you opened the panel from, and the pen changes to that color (the width stays the same). | 選んだ色は、パネルを開いたもとの丸に入り、ペンもその色に替わります（太さはそのまま）。 | なし |
| S.pen.6 | If another dot already has that color, that dot is simply selected (no two dots have the same color). | ほかの丸がもうその色を持っているときは、その丸が選ばれるだけです（同じ色の丸が 2 つになることはありません）。 | パネルを開いたもとの丸の色が変わらないことは、「simply」から読めます |
| S.pen.7 | “Reset Colors” sets the six dots back to the first six colors. | 「Reset Colors」は、6 つの丸を最初の 6 色に戻します。 | 「最初の 6 色」は S.pen.3 の「前からの 6 色」と同じと読めます |
| S.pen.8 | The panel closes when you start writing on the paper, when you touch outside it, or when you choose a color. | パネルは、紙に書き始めたとき、パネルの外に触れたとき、色を選んだときに閉じます。 | 「Other Color…」でシステムの色選びが開いたときにパネルがどうなるかは書いていません |
| S.pen.9 | If you start writing while it is open, that stroke is still written. | 開いているときに書き始めても、その線はちゃんと書かれます。 | なし |
| S.pen.10 | The colors of the dots are remembered on each device (separately on your iPad and your iPhone). | 丸の色は端末ごとに覚えられます（iPad と iPhone で別々に）。 | なし |
| S.pen.11 | The strokes you write keep their color and reach your other devices through iCloud. | 書いた線は色を保ったまま、iCloud でほかの端末に届きます。 | なし |
| S.pen.12 | The panel opens in the same way when, on iPad, the toolbar is at the top, left or right edge, and when you bring out the hidden toolbar with the tool mark on the round button. | iPad でツールバーが上・左・右の端にあるときも、隠したツールバーを丸いボタンの道具の印で出したときも、パネルは同じように開きます。 | なし |
| S.pen.13 | On iPhone, the panel appears above the toolbar. | iPhone では、パネルはツールバーの上（上側）に出ます。 | 「above」は位置が上という意味で、重なるという意味ではないと読みました |
| S.pen.14 | If you choose a light color close to the color of the paper, your strokes are hard to see. | 紙の色に近い明るい色を選ぶと、線が見えにくくなります。 | 「light」は「明るい・淡い」です |
| S.pen.15 | Then choose another color, or tap “Reset Colors”. | そのときは別の色を選ぶか、「Reset Colors」をタップしてください。 | なし |
| S.pen.16 | The marker still has 4 colors. | マーカーは今までどおり 4 色です。 | マーカーの色が替えられないことまでは書いていませんが、そう読めます |

### How do I change the notes paper?（メモの紙を変えるには？）

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.paper.1 | In the App's Settings > Notes Paper, choose “Lined”, “Dot Grid” or “Blank” (from version 1.4.2). | アプリの 設定 > Notes Paper（メモの紙）で、「Lined（罫線）」「Dot Grid（ドット方眼）」「Blank（無地）」から選んでください（バージョン 1.4.2 から）。 | なし |
| S.paper.2 | Lined is the default. | 最初は Lined（罫線）です。 | なし |
| S.paper.3 | The Notes area of the month page, the “Notes” column on the right of the day page and the “Free Notes” area below 24:00 on the day and week pages all change together. | 月のページのメモ欄、日のページの右の「Notes（メモ）」の列、日と週のページの 24:00 より下の「Free Notes（自由メモ）」の欄が、全部いっしょに変わります。 | 月のページの「Notes area」だけ引用符がありません（ほかは引用符つき） |
| S.paper.4 | The same goes for week and day pages joined side by side. | 横につないだ週と日のページも同じです。 | なし |
| S.paper.5 | A PDF made with “This Page as PDF” has that pattern too. | 「This Page as PDF（このページを PDF に）」で作った PDF にも、その模様が付きます。 | なし |
| S.paper.6 | With Dot Grid, small dots are placed at the heights where the lines were, with the same spacing across. | Dot Grid では、線のあった高さに小さな点が置かれ、横にも同じ間隔で並びます。 | 「the same spacing」が何と同じ間隔か（線と線の間隔と同じ＝正方形の格子か、点どうしが等間隔というだけか）は、はっきりしません |
| S.paper.7 | With Blank, there are neither lines nor dots. | Blank では、線も点もありません。 | なし |
| S.paper.8 | Only the pattern of the paper changes; none of your handwriting moves. | 変わるのは紙の模様だけで、手書きはどれも動きません。 | なし |
| S.paper.9 | If you go back to Lined, the paper looks the same as before. | Lined に戻すと、紙は前と同じ見た目になります。 | なし |
| S.paper.10 | This setting is remembered on each device (you can choose separately on your iPad and your iPhone). | この設定は端末ごとに覚えられます（iPad と iPhone で別々に選べます）。 | なし |
| S.paper.11 | On a device with a version earlier than 1.4.2, the paper stays lined. | 1.4.2 より前のバージョンの端末では、紙は罫線のままです。 | なし |

### What if my iPad and iPhone have different versions?（iPad と iPhone の版が違うときは？）の足した 1 文

| id | 訳（R が読んだ字） | 元を見ない逆翻訳 | R の注 |
| --- | --- | --- | --- |
| S.ver.1 | Strokes written in the colors that became available in version 1.4.2 also appear in those colors on a device with an earlier version (you just cannot choose those colors in that version's toolbar), and the notes paper stays lined there. | バージョン 1.4.2 で使えるようになった色で書いた線は、それより前のバージョンの端末でもその色で出ます（そのバージョンのツールバーではその色を選べないだけです）。また、そこではメモの紙は罫線のままです。 | 「there」は「前のバージョンの端末」と読めます |

## 元との照らし合わせ（逆翻訳を書き終えた後。2026-11-26 05:1x）

上の表を書き終えて（その時の字のファイルの sha256 は `246334e263280ae5afec0c401f2d0bbf35e1f80d4185a963cfa5b91ba1866609`。この節を足す前の字）から、日本語の元を読みました: `docs/store/ja/whatsnew.txt`・`docs/store/source-ja/whatsnew.txt`、審査メモの日本語の要約、`docs/SUPPORT.md` の 0d9241a からの差分、契約 R1_4_2_CONTRACT.md の §8（§8.4 の英語の字と §8.5 の中身）と §3.4〜§3.9。○ は意味が同じ、△ は意味は同じだが言い方にずれがある、× は意味が違う（直す）。

**結果: 41 行で ○ 40・△ 1・× 0**（新機能の文 4、審査メモ 7、SUPPORT 30（見出し 2 を含む））。直した字はありません。

### 新機能の文（en-US）

| id | 日本語の元（`source-ja/whatsnew.txt`） | 判定 | 注 |
| --- | --- | --- | --- |
| 1.4.2.W1.en-US | ・ペンの色を増やしました。光っている色の丸をもう一度押すと（長押しでも）、12 色やお好きな色から選んで、その丸の色を入れ替えられます。 | ○ | 「光っている」= highlighted。R の注の「好きな色の選び方」は元にも無い |
| 1.4.2.W2.en-US | ・設定に「メモ欄の紙」を足しました。メモ欄と自由メモの紙を、罫線・ドット方眼・無地から選べます。手書きはそのまま残ります。 | ○ | 欄の名前は引用符つき（“Notes”・“Free Notes”）で、アプリの en の字 |
| 1.4.2.W3.en-US | ・ダークモードで、ツールバーの濃い色の丸を見えやすくしました。 | ○ | 「濃い色」= dark color |
| 1.4.2.AI.en-US | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4.1 と同じ字 |

### 審査メモ（「What is new in 1.4.2」）

審査メモの英語は、契約 §8.4 が英語の字で決めています（日本語の元は要約の 3 文と、契約 §3・§4・§5 の中身）。§8.4 の字からの替えは 3 つで、どれも README（審査メモの「1.4.2 から」）の決まりどおりです: 「the reset button」→ アプリの en の字「"Reset Colors"」、「the notes areas」→「the Notes and Free Notes areas」、引用符 “ ” → 1.4.1 と同じ ASCII の "。

| id | 日本語の元 | 判定 | 注 |
| --- | --- | --- | --- |
| RN142.1a | 要約: 光っている色の丸をもう一度押す（長押しでも）と、色の板（12 色・その他の色…・最初の色に戻す）が開きます。 | ○ | 「最初の色に戻す」= アプリの en の「Reset Colors」（`toolbar.colorPanel.reset`、e3cec22） |
| RN142.1b | 要約: 選んだ色はその丸に入り、端末ごとに覚えます。 | △ | 「The choice replaces that dot」は字のとおりだと「丸と入れ替わる」で、元は「その丸に入る」。審査の人は丸の色が替わると読める。契約 §8.4 の英語の字そのままなので直さない |
| RN142.1c | （要約に無い）契約 §8.4 の英語の字、中身は §5（線は前から色を hex で持つ） | ○ | |
| RN142.1d | （要約に無い）契約 §8.4 の英語の字 | ○ | 最初のペンは黒（`InkTools.swift:57` の `defaultPen` は `penColors[0]` = #1f2937）なので、週のページを開いて黒の丸を「もう一度」押せば板が開く。茶 #92400e は板の 12 色にある（`ToolbarView.swift:729`） |
| RN142.2a | 要約: 設定 › メモ欄の紙 で罫線・ドット方眼・無地 | ○ | 欄の名前は元（要約）に無いが、新機能の文の「メモ欄と自由メモ」と同じ |
| RN142.2b | 要約: （手書きは動きません） | ○ | |
| RN142.3 | 要約: データ・購入・年齢区分は同じ。 | ○ | 1.4.1 の 4 と同じ字（判定は REVIEW.md の 14・16.y が今も有効） |

### SUPPORT.en.md（元は `docs/SUPPORT.md` の同じ所）

| id | 日本語の元 | 判定 | 注 |
| --- | --- | --- | --- |
| 見出し 1 | ペンの色を替えるには？ | ○ | |
| S.pen.1 | ペンを選ぶと、ツールバーに色の丸が 6 つ並びます。 | ○ | |
| S.pen.2 | 光っている丸（今のペンの色）をもう一度押すと（長押しでも）、その丸のそばに色の板が開きます（1.4.2 から）。 | ○ | |
| S.pen.3 | 板には、12 色（今までの 6 色と、新しい 6 色）と、「その他の色…」「最初の色に戻す」があります。 | ○ | |
| S.pen.4 | 「その他の色…」では、iPad・iPhone に元からある色選びの画面で、どんな色でも選べます。 | ○ | |
| S.pen.5 | 選んだ色は板を開いた丸に入り、ペンもその色になります（太さはそのままです）。 | ○ | |
| S.pen.6 | 選んだ色がほかの丸にもうあるときは、その丸を選ぶだけです（同じ色の丸が 2 つにはなりません）。 | ○ | 契約 §3.7 の `choose` の動きと同じ |
| S.pen.7 | 「最初の色に戻す」を押すと、6 つの丸が最初の 6 色に戻ります。 | ○ | |
| S.pen.8 | 板は、紙に書き始めたとき、板の外に触れたとき、色を選んだときに閉じます。 | ○ | R の注の「その他の色…」を押したときも閉じる（契約 §3.7）。元にも書いていないので同じ |
| S.pen.9 | 板を開いたまま書き始めても、その線は書けます。 | ○ | |
| S.pen.10 | 替えた丸の色は、端末ごとに覚えます（iPad と iPhone で別々です）。 | ○ | 元は「替えた丸の色」、英語は「丸の色」。意味は同じ |
| S.pen.11 | 書いた線は、その色のまま iCloud でほかの端末にも届きます。 | ○ | |
| S.pen.12 | iPad でツールバーを上・左・右の端に置いたときも、しまったツールバーを丸ボタンの道具の印で出したときも、同じように開きます。 | ○ | 「丸ボタンの道具の印」= the tool mark on the round button（1.4.1 の SUPPORT.en と同じ言い方） |
| S.pen.13 | iPhone では、ツールバーの上に板が出ます。 | ○ | 板は丸の上 8 pt に出る（契約 §3.8 の「下: 板の下端 = 丸の minY − 8」）ので「above」で合う |
| S.pen.14 | 紙の色に近い薄い色を選ぶと、書いた線が見えにくくなります。 | ○ | |
| S.pen.15 | そのときは、ほかの色を選ぶか、「最初の色に戻す」を押してください。 | ○ | |
| S.pen.16 | マーカーの色は 4 色のままです。 | ○ | |
| 見出し 2 | メモ欄の紙を替えるには？ | ○ | 見出しと S.ver.1 は「notes paper」を小文字の普通の名詞で書いている（設定の名前は S.paper.1 の “Notes Paper”）。元も同じ語を両方に使っているので意味は同じ |
| S.paper.1 | アプリの 設定 › メモ欄の紙 で、「罫線」「ドット方眼」「無地」から選べます（1.4.2 から）。 | ○ | |
| S.paper.2 | 最初は罫線です。 | ○ | |
| S.paper.3 | 月のページのメモ欄、日のページの右の「メモ」、日と週のページの 24 時の下の「自由メモ」が、そろって変わります。 | ○ | |
| S.paper.4 | 横につながった週と日のページでも同じです。 | ○ | |
| S.paper.5 | 「このページを PDF」で書き出す PDF も、その柄になります。 | ○ | 「This Page as PDF」はアプリの en の字（`export.pdf.title`） |
| S.paper.6 | ドット方眼では、罫線があった高さに、横も同じ間隔で小さな点が並びます。 | ○ | R の注の「何と同じ間隔か」は元の「横も同じ間隔で」も同じ書き方。逆翻訳は元と同じ形になった |
| S.paper.7 | 無地では、線も点もありません。 | ○ | |
| S.paper.8 | 変わるのは紙の柄だけで、手書きは 1 本も動きません。 | ○ | |
| S.paper.9 | 罫線に戻すと、前と同じ見た目に戻ります。 | ○ | |
| S.paper.10 | この設定は端末ごとに覚えます（iPad と iPhone で別々に選べます）。 | ○ | |
| S.paper.11 | 1.4.2 より前の版の端末では、罫線のままです。 | ○ | |
| S.ver.1 | 1.4.2 で選べるようになった色で書いた線は、前の版の端末でもその色で見え（前の版のツールバーでは、その色を選べないだけです）、メモ欄の紙は、前の版の端末では罫線のままです。 | ○ | |

### ほかの確かめ（機械。スクラッチの使い捨てのスクリプトで、枝 `r142-w-d2a` の b33485a の字を読んだ）

- **11 の訳の新機能の文**（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・pt-PT・es-MX・es-ES）: どれも 3 つの点 → 空の行 → 訳についての 1 行で、その 1 行は 0d9241a（1.4.1）の同じファイルの最後の行と 1 字も同じ。字数（最後の改行を除く）は en-US 505・zh-Hans 189・zh-Hant 189・ko 270・fr-FR 694・de-DE 639・it 635・pt-BR 600・pt-PT 595・es-MX 603・es-ES 607 で、どれも 4,000 字より下。
- **アプリの語**: 各言語の新機能の文に、アプリの訳（X の最後の訳、枝 `r142-w-d2x` の e3cec22 の `tools/l10n/translations/<言語>.json`。pt-PT はアプリの pt-BR、es-MX・es-ES はアプリの es）の `settings.title`・`settings.memoPaper.title`・`ruled`・`dots`・`plain`・`paper.memo`・`paper.freeMemo` の字がそのまま入っている（11 言語 × 7 語、欠け 0。設定の名前と欄の名前は、どの言語も引用符つき）。ペン（`toolbar.tool.pen`）とツールバー（`toolbar.grip.spoken` の名詞）の語も、9 言語ともアプリの字と同じ。色の名前は、どの言語の新機能の文にも無い。
- **写し**: en-GB・en-AU・en-CA は `copyOf` en-US、fr-CA は `copyOf` fr-FR で、どれもフォルダは無い（Connect には元の文をそのまま入れる）。`ja/whatsnew.txt` は契約 §8.3 の `>` の 3 行と 1 字も同じ（162 字）。`source-ja/whatsnew.txt` は同じ 3 行 → 空の行 → 1.4.1 の訳についての 1 行と 1 字も同じ（207 字）。
- **審査メモ**: 3,669 バイト（`wc -c` と同じ数。4,000 バイトまで 331）。0d9241a からの差は、「What is new in 1.4.1」の 5 行 → 「What is new in 1.4.2」の 4 行と、日本語の要約の 1 行（1.4.1 の 3 文 → 1.4.2 の 3 文。最後の「データ・購入・年齢区分は同じ。規約類は日本語が正本で、英語は参考訳。サインイン不要。」は同じ字）だけ。ほかの段は 1 バイトも違わない。3 は 1.4.1 の 4 と番号のほかは同じ字。アプリの en の語（Other Color…・Reset Colors・Brown・Notes Paper・Lined・Dot Grid・Blank・Notes・Free Notes・Settings）は e3cec22 の en の字と同じ。
- **SUPPORT**: 日英とも、足した 20 行に色の名前は 1 つも無い（en は 12 色の en の名前、ja は 12 色の日本語の名前で探した）。新しい 2 つの FAQ は日英とも「ツールバーを動かすには？」の後、「1 ページにどれだけ書けますか？」の前。

### 気づき（リードへ。直していない）

1. **アプリの訳の取り込みの順**: この枝の `tools/l10n/translations` は 0d9241a の仮の訳のまま（en の `toolbar.colorPanel.reset` は「Reset to Original Colors」）。店の文と審査メモと SUPPORT.en は X の最後の訳（e3cec22、「Reset Colors」）に合わせてあるので、`r142` には X の枝と一緒に取り込む必要があります（片方だけだと、店の文とアプリの字がずれる）。
2. 新機能の文は「highlighted」、審査メモは「selected」で、同じ丸を指しています（元はどちらも「光っている」）。審査メモの字は契約 §8.4 の英語の字なので、そのままにしました。
