# ストア 1.4.1 の逆翻訳（en・de・fr：新機能の文・審査メモの 1.4.1 の段と替え文・SUPPORT.en.md の 4 つの FAQ と替え文）

R が日本語の元を見ずに訳し戻した表です。en・de・fr の担当の R が書きました（`store-1_4_1.md` はほかの R が先に書いていたので、このファイルに分けました）。母語の人の確認ではありません。

- R が読んだもの（2026-11-22）: `docs/store/en-US/whatsnew.txt`・`docs/store/de-DE/whatsnew.txt`・`docs/store/fr-FR/whatsnew.txt`、`docs/store/review-note.txt` の「What is new in 1.4.1」の段（英語の部分だけ）、`docs/SUPPORT.en.md` の FAQ 4 つ（How do I hide the toolbar? / How do I zoom in and out? / How do I use it with my left hand? / How do I move the toolbar?）、`docs/store/PROPOSALS_1_4_1.md` §2・§3 の英語の案（日本語の字は全部伏せ字にして読んだ）。アプリの字は `tools/l10n/translations/{en,de,fr}.json` の 11 キーの text だけ（逆翻訳は `back/en.json`・`back/de.json`・`back/fr.json`）。
- 読んでいないもの: 日本語の元（契約 R1_4_1_CONTRACT.md、`docs/store/source-ja`・`docs/store/ja`、`docs/SUPPORT.md`、審査メモの日本語の要約）、`tools/l10n/source`、GLOSSARY.md、画面のコード、git の履歴と差分。
- PROPOSALS §2・§3 の英語の案のうち「“…” button」の中の字は日本語の字だったので、伏せ字のまま「〔ボタンの字〕」と書きました（何の字かは読んでいません）。
- en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`locales.json` の `copyOf`）。

## R の全体の注

- 3 言語とも「利き手・左手・右手」は手の名前（Dominant Hand / Left Hand / Right Hand、Dominante Hand / Linke Hand / Rechte Hand、Main dominante / Main gauche / Main droite）で、「左利きの人」（Linkshänder・gaucher など、性で形が変わる語）は使っていません。
- 等倍のボタンの名前が文によって 3 通りあります。アプリの VoiceOver と SUPPORT は「Reset Zoom（ズームをリセット）」、審査メモは「1× button（1 倍のボタン）」、新機能の文は「a single button（ボタン 1 つ）」。審査メモには「a magnifying glass with "1"」と見た目が書いてあるので、同じボタンだとつなげられます。
- 「元の大きさ」は 3 言語とも「拡大も縮小もしていない」と言い添えてあり、取り違えはありません（original size / Originalgröße / taille d’origine。de・fr は単独だと「原寸」とも読めます）。

## en-US（en-GB・en-AU・en-CA も）

### 新機能の文（whatsnew.txt）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.1.W1.en-US | • Moved “‹ Today ›” at the top of the screen to the left end and placed the date to its right. | ・画面上部の「‹ Today（今日） ›」を左端に移し、その右に日付を置きました。 | 虫めがねのボタン（等倍）も一緒に動いたのかは、この行からは分かりません |
| 1.4.1.W2.en-US | • After you zoom in or out, a single button now takes you back to the original size, neither zoomed in nor out. | ・拡大や縮小をした後、ボタン 1 つで、拡大も縮小もしていない元の大きさに戻れるようになりました。 | どのボタンか・どこにあるかは書いていません |
| 1.4.1.W3.en-US | • Added “Dominant Hand” to Settings. If you choose “Left Hand”, the order of the buttons at the top of the screen is reversed from left to right. | ・設定に「利き手」を加えました。「左手」を選ぶと、画面上部のボタンの並び順が左右逆になります。 | 丸いボタンが右下へ移ることは書いていません（アプリの説明の文には書いてあります） |
| 1.4.1.W4.en-US | • On iPad, you can now use your finger to move the toolbar to the top, bottom, left or right edge. | ・iPad では、指でツールバーを上・下・左・右の端に動かせるようになりました。 | 「edge」は画面の端と読むのが自然です。Apple Pencil では動かないことまでは書いていません |
| 1.4.1.AI.en-US | Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes. | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | なし |

### 審査メモ（review-note.txt の「What is new in 1.4.1」）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| RN141.1 | 1. ‹ Today › and the 1× button (a magnifying glass with "1") are now at the left end of the header, with the date right after them (on narrow screens, 1× starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. ‹ Today（今日） › と 1× のボタン（「1」の入った虫めがね）がヘッダーの左端に来て、そのすぐ後に日付が続くようになりました（狭い画面では、1× は 2 段目の先頭に来ます）。「設定 > 利き手 > 左手」で、この並びが逆になります。 | ‹ Today › と 1× のどちらが左かは書いていません（書いた順なら ‹ Today › が先）。「1×」は「1 倍」と読めます |
| RN141.2 | 2. 1× returns the page to its original size, neither zoomed in nor out (as when first opened), and clears the zoom remembered for that page type. | 2. 1× は、ページを拡大も縮小もしていない元の大きさ（最初に開いたときと同じ）に戻し、その種類のページについて覚えていたズームを消します。 | なし |
| RN141.3 | 3. On iPad, a finger can drag the open toolbar by its small handle to any of the four edges; Apple Pencil cannot. On iPhone, even on iPhone Duo's inner screen, it stays at the bottom. To check: on iPad, open a week page and drag the toolbar's handle to the right edge. | 3. iPad では、開いているツールバーを、小さな取っ手をつかんで指で四辺のどの端へもドラッグできます。Apple Pencil ではできません。iPhone では、iPhone Duo の内側の画面でも、ツールバーは下のままです。確かめ方: iPad で週のページを開き、ツールバーの取っ手を右端へドラッグしてください。 | なし |
| RN141.4 | 4. New text is only in Settings and VoiceOver labels. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating. | 4. 新しい文言は、設定と VoiceOver のラベルの中だけです。変わらないもの: データ（App のプライバシーは「データの収集なし」のまま）、手書きの保存、購入、年齢区分。 | なし |

### 審査メモの替え文（PROPOSALS_1_4_1.md §2 の英語の案）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| P2.1-b.1（並べ方 (b)、虫めがねの印） | 1. The date is now at the left end of the header, with ‹ Today › and the 1× button (a magnifying glass with "1") right after it (on narrow screens, 1× starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. 日付がヘッダーの左端に来て、そのすぐ後に ‹ Today（今日） › と 1× のボタン（「1」の入った虫めがね）が続くようになりました（狭い画面では、1× は 2 段目の先頭に来ます）。「設定 > 利き手 > 左手」で、この並びが逆になります。 | 今の新機能の文（3 言語とも「‹ Today › を左端へ移し、日付をその右へ」）とは並びが逆です。この案を使うなら、新機能の文の行 1 も合わせる必要があると読めます |
| P2.2-a.1（並べ方 (a)、字のボタン） | 1. ‹ Today › and the "〔ボタンの字〕" button are now at the left end of the header, with the date right after them (on narrow screens, that button starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. ‹ Today（今日） › と「〔ボタンの字〕」のボタンがヘッダーの左端に来て、そのすぐ後に日付が続くようになりました（狭い画面では、そのボタンが 2 段目の先頭に来ます）。「設定 > 利き手 > 左手」で、この並びが逆になります。 | 見た目の説明（虫めがね）がなくなり、ボタンの字だけで見分けることになります |
| P2.2-a.2 | 2. "〔ボタンの字〕" returns the page to its original size, neither zoomed in nor out (as when first opened), and clears the zoom remembered for that page type. | 2. 「〔ボタンの字〕」は、ページを拡大も縮小もしていない元の大きさ（最初に開いたときと同じ）に戻し、その種類のページについて覚えていたズームを消します。 | なし |
| P2.2-a.4 | 4. New text: the "〔ボタンの字〕" button, Settings and VoiceOver labels. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating. | 4. 新しい文言: 「〔ボタンの字〕」のボタン、設定、VoiceOver のラベル。変わらないもの: データ（App のプライバシーは「データの収集なし」のまま）、手書きの保存、購入、年齢区分。 | 「New text is only in …」の「only」がなくなり、画面に出る字が増えたことが分かる形です |
| P2.3-b.1（並べ方 (b)、字のボタン） | 1. The date is now at the left end of the header, with ‹ Today › and the "〔ボタンの字〕" button right after it (on narrow screens, that button starts the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. 日付がヘッダーの左端に来て、そのすぐ後に ‹ Today（今日） › と「〔ボタンの字〕」のボタンが続くようになりました（狭い画面では、そのボタンが 2 段目の先頭に来ます）。「設定 > 利き手 > 左手」で、この並びが逆になります。 | P2.1-b.1 と同じく、今の新機能の文とは並びが逆です |

### SUPPORT.en.md の FAQ

#### How do I hide the toolbar?（ツールバーを隠すには？）

> Tap “Hide” at the right end of the toolbar (at the bottom end when the toolbar is at the left or right edge), and the toolbar becomes a small round button at the bottom left. If you choose “Left Hand” in the App's Settings > Dominant Hand, the round button moves to the bottom right. On iPad, if you move the toolbar to the left edge and then hide it, the round button appears at the bottom left; at the right edge, it appears at the bottom right (both from version 1.4.1). Tap the tool mark on the round button to bring the toolbar back; it hides again automatically when you start writing on the paper. The ↶ on the round button is “Undo”. Touch and hold the round button to move it to the other bottom corner, or to go back to always showing the toolbar. This setting is remembered on each device.

逆翻訳: ツールバーの右端（ツールバーが左端か右端にあるときは下端）にある「Hide（隠す）」をタップすると、ツールバーは左下の小さな丸いボタンになります。アプリの「設定 > 利き手」で「左手」を選ぶと、丸いボタンは右下に移ります。iPad では、ツールバーを左端に動かしてから隠すと丸いボタンは左下に、右端なら右下に出ます（どちらもバージョン 1.4.1 から）。丸いボタンの道具の印をタップするとツールバーが戻り、紙に書き始めると自動でまた隠れます。丸いボタンの ↶ は「Undo（取り消す）」です。丸いボタンを長押しすると、もう一方の下の角へ動かすことも、ツールバーをいつも出しておく形に戻すこともできます。この設定は端末ごとに覚えられます。

R の注:

- 「左手」を選んでいて、iPad でツールバーを左端に置いて隠したとき、丸いボタンが左下か右下かは文からは決められません（「左手なら右下」と「左端なら左下」の 2 つの決まりがぶつかり、どちらが勝つか書いていません。書いた順からは「iPad の端の決まりが後に書いてあるので、そちらが優先」と読む人が多そうです）。
- 「This setting」が、長押しで選んだ角のことか、いつも出しておく形のことか、両方かははっきりしません。
- 「the tool mark」（道具の印）がどんな絵かは書いていません。

#### How do I zoom in and out?（拡大・縮小するには？）

> Spread two fingers to zoom in, and pinch to zoom out. Month and year pages open at the same size, no matter how many events or how much handwriting they have (on iPad, when the toolbar is at the left or right edge, they may open smaller, because the paper is narrower by the width of the toolbar). Pages with many events or a lot of handwriting can be scrolled down (with two fingers when “Draw with Finger” is on). When you pinch to zoom out, you can see the whole calendar. The device remembers the zoomed-in size for each page type. It does not remember the zoomed-out size.

逆翻訳: 2 本の指を広げると拡大、つまむと縮小します。月と年のページは、予定や手書きがどれだけ多くても同じ大きさで開きます（iPad でツールバーが左端か右端にあるときは、紙がツールバーの幅のぶん狭くなるので、小さめに開くことがあります）。予定や手書きが多いページは下へスクロールできます（「Draw with Finger（指で描く）」がオンのときは 2 本指で）。つまんで縮小すると、カレンダー全体が見られます。端末は、拡大した大きさをページの種類ごとに覚えます。縮小した大きさは覚えません。

> Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). On a narrow screen (iPhone in portrait, except the inner screen of iPhone Duo, and a narrow iPad window), this button is at the left of the second row (the Day, Week, Month and Year switch). When “Left Hand” is chosen in the App's Settings > Dominant Hand, it is at the top right (on a narrow screen, at the right of the second row). Resetting the zoom also makes the device forget the zoomed-in size it remembered for that page type. The next page of the same type also opens at the original size, even after you reopen the App. The sizes of the other page types stay as they are.

逆翻訳: 左上の「‹ Today（今日） ›」の隣にある、「1」の入った虫めがねのボタン（Reset Zoom＝ズームをリセット）をタップすると、拡大も縮小もしていない元の大きさ、つまりそのページを最初に開いたときの大きさにすぐ戻ります（バージョン 1.4.1 から）。狭い画面（縦向きの iPhone〔iPhone Duo の内側の画面は除く〕と、幅の狭い iPad のウインドウ）では、このボタンは 2 段目（日・週・月・年の切り替え）の左にあります。アプリの「設定 > 利き手」で「左手」を選んでいるときは右上にあります（狭い画面では 2 段目の右）。ズームをリセットすると、端末がその種類のページについて覚えていた拡大の大きさも忘れます。同じ種類の次のページも、アプリを開き直した後でも、元の大きさで開きます。ほかの種類のページの大きさはそのままです。

R の注:

- かっこの中「iPhone in portrait, except the inner screen of iPhone Duo, and a narrow iPad window」は、「iPhone Duo の内側の画面と、幅の狭い iPad のウインドウを除く」とも読めてしまいます（except が後ろの「a narrow iPad window」にもかかる読み方）。上の逆翻訳は、狭い iPad のウインドウも「狭い画面」に入る読み方を取りました。
- ボタンが「‹ Today ›」の左右どちら側の隣かは書いていません。
- 「the size the page had when you first opened it」は、直前の「neither zoomed in nor out」と合わせて、覚えた拡大の大きさではなく、最初の大きさのことだと分かります。
- 「the whole calendar」は、そのページ全体のことと読めます。

#### How do I use it with my left hand?（左手で使うには？）

> In the App's Settings > Dominant Hand, choose “Left Hand” (from version 1.4.1). The order of the buttons at the top of the screen is reversed from left to right: ⚙ (Settings) moves to the left end, and “‹ Today ›” and the Reset Zoom button move to the right side. The round button of the hidden toolbar also moves to the bottom right (touch and hold the round button to move it back to the bottom left). The paper and your handwriting stay as they are. Previous (‹) stays on the left and next (›) on the right. The order of Day, Week, Month and Year and the order inside the toolbar do not change either. This setting is remembered on each device (you can choose separately on your iPad and your iPhone).

逆翻訳: アプリの「設定 > 利き手」で「左手」を選びます（バージョン 1.4.1 から）。画面上部のボタンの並び順が左右逆になり、⚙（設定）が左端へ、「‹ Today（今日） ›」とズームをリセットするボタンが右側へ移ります。隠したツールバーの丸いボタンも右下へ移ります（丸いボタンを長押しすると左下へ戻せます）。紙とあなたの手書きはそのままです。前へ（‹）は左、次へ（›）は右のままです。日・週・月・年の並びと、ツールバーの中の並びも変わりません。この設定は端末ごとに覚えられます（iPad と iPhone で別々に選べます）。

R の注:

- 題の「use it with my left hand」は「左手で使う」で、日本語なら「左利きの人が使う」と読み替えて分かります。
- 「move to the right side」は「右側へ」で、右端とまでは言っていません。

#### How do I move the toolbar?（ツールバーを動かすには？）

> On iPad, you can move the open toolbar to the top, bottom, left or right edge of the screen (from version 1.4.1). With your finger, drag the small handle on the edge of the toolbar nearer the paper. When you lift your finger, the toolbar snaps to the nearest edge. At the left or right edge, the toolbar turns vertical. The toolbar does not cover the paper; instead, the paper becomes smaller to make room for it (at the top edge, the paper is the same size as at the bottom edge).
>
> - Apple Pencil does not move it. While you are writing with Apple Pencil (and just after), the toolbar does not move even if your palm touches the handle.
> - The edge you choose is remembered on each device. The toolbar stays at that edge after you reopen the App or rotate your iPad.
> - In a narrow window, such as Split View or Slide Over, a toolbar placed at the left or right edge appears at the bottom (in a narrower window, one placed at the top does too). When you widen the window, it goes back to the edge you chose.
> - On iPhone, the toolbar stays at the bottom (it has no handle).

逆翻訳: iPad では、開いているツールバーを画面の上・下・左・右の端に動かせます（バージョン 1.4.1 から）。ツールバーの、紙に近い側の縁にある小さな取っ手を指でドラッグします。指を離すと、ツールバーはいちばん近い端にぴたりと付きます。左端や右端では、ツールバーは縦になります。ツールバーは紙を覆いません。代わりに、紙がそのぶん小さくなります（上端のときの紙の大きさは、下端のときと同じです）。

- Apple Pencil では動きません。Apple Pencil で書いている間（と書いた直後）は、手のひらが取っ手に触れてもツールバーは動きません。
- 選んだ端は端末ごとに覚えられます。アプリを開き直しても、iPad を回しても、ツールバーはその端にとどまります。
- Split View や Slide Over などの狭いウインドウでは、左端や右端に置いたツールバーは下に出ます（もっと狭いウインドウでは、上に置いたものも下に出ます）。ウインドウを広げると、選んだ端に戻ります。
- iPhone では、ツールバーは下のままです（取っ手がありません）。

R の注:

- 「the small handle on the edge of the toolbar nearer the paper」は、「紙に近い側の縁にある取っ手」と読みました。「nearer the paper」が取っ手にかかる（取っ手のうち紙に近いもの）とも読めますが、取っ手は 1 つなので意味は変わりません。
- 「the open toolbar」は、隠していない（丸いボタンになっていない）ツールバーと読めます。

### SUPPORT の替え文（PROPOSALS_1_4_1.md §3 の英語の案）

§3.1.1 の 4 つの組（替わるのは等倍のボタンの 1 文だけ）:

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| P3-a-印 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). | 左上の「‹ Today（今日） ›」の隣にある、「1」の入った虫めがねのボタン（Reset Zoom＝ズームをリセット）をタップすると、拡大も縮小もしていない元の大きさ、つまりそのページを最初に開いたときの大きさにすぐ戻ります（バージョン 1.4.1 から）。 | 今の SUPPORT.en.md の字と同じです |
| P3-a-字 | Tap the “〔ボタンの字〕” button (Reset Zoom), next to “‹ Today ›” at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). | 左上の「‹ Today（今日） ›」の隣にある「〔ボタンの字〕」のボタン（Reset Zoom＝ズームをリセット）をタップすると、拡大も縮小もしていない元の大きさ、つまりそのページを最初に開いたときの大きさにすぐ戻ります（バージョン 1.4.1 から）。 | なし |
| P3-b-印 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” to the right of the date at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). | 左上で日付の右にある「‹ Today（今日） ›」の隣の、「1」の入った虫めがねのボタン（Reset Zoom＝ズームをリセット）をタップすると、拡大も縮小もしていない元の大きさ、つまりそのページを最初に開いたときの大きさにすぐ戻ります（バージョン 1.4.1 から）。 | 「to the right of the date」が「‹ Today ›」にかかるのか、ボタンにかかるのかは字からは決まりません（逆翻訳は ‹ Today › にかかる読み方） |
| P3-b-字 | Tap the “〔ボタンの字〕” button (Reset Zoom), next to “‹ Today ›” to the right of the date at the top left, to go straight back to the original size, neither zoomed in nor out: the size the page had when you first opened it (from version 1.4.1). | 左上で日付の右にある「‹ Today（今日） ›」の隣の「〔ボタンの字〕」のボタン（Reset Zoom＝ズームをリセット）をタップすると、拡大も縮小もしていない元の大きさ、つまりそのページを最初に開いたときの大きさにすぐ戻ります（バージョン 1.4.1 から）。 | P3-b-印 と同じかかり方のあいまいさがあります |

§3.1.2 のどの組でも同じ文（en）: 「On a narrow screen (iPhone in portrait, except the inner screen of iPhone Duo, and a narrow iPad window), this button is at the left of the second row (the Day, Week, Month and Year switch). When “Left Hand” is chosen in the App's Settings > Dominant Hand, it is at the top right (on a narrow screen, at the right of the second row).」は今の SUPPORT.en.md の字と同じです。逆翻訳と注は上の「How do I zoom in and out?」の 2 段落目にあります（かっこの中の except のかかり方の注も同じ）。

## de-DE

### 新機能の文（whatsnew.txt）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.1.W1.de-DE | • „‹ Heute ›“ oben auf dem Bildschirm wurde an den linken Rand verschoben, und das Datum steht jetzt rechts davon. | ・画面上部の「‹ 今日 ›」を左端へ移し、日付はその右に来るようになりました。 | なし |
| 1.4.1.W2.de-DE | • Nach dem Vergrößern oder Verkleinern können Sie jetzt mit einer einzigen Schaltfläche zur Originalgröße zurückkehren (weder vergrößert noch verkleinert). | ・拡大や縮小をした後、ボタン 1 つで元のサイズ（拡大も縮小もしていない状態）に戻れるようになりました。 | 「Originalgröße」は単独だと「原寸」とも読めますが、かっこの言い添えで取り違えはありません |
| 1.4.1.W3.de-DE | • In den Einstellungen gibt es jetzt den Bereich „Dominante Hand“. Wenn Sie „Linke Hand“ wählen, werden die Schaltflächen oben auf dem Bildschirm seitenverkehrt angeordnet. | ・設定に「利き手」の欄ができました。「左手」を選ぶと、画面上部のボタンが左右逆に並びます。 | 「Dominante Hand」はやや専門的（医学やスポーツの言い方）な響きですが、意味は「利き手」ではっきりしています。「seitenverkehrt」は「鏡に映したように左右逆」の語で、並びが逆になると読めます（ボタンの絵まで反転すると取る人は少ないと思います） |
| 1.4.1.W4.de-DE | • Auf dem iPad können Sie die Werkzeugleiste jetzt mit dem Finger an den oberen, unteren, linken oder rechten Rand verschieben. | ・iPad では、指でツールバーを上・下・左・右の端へ動かせるようになりました。 | なし |
| 1.4.1.AI.de-DE | Die Übersetzungen wurden mit KI erstellt und noch nicht von Muttersprachlern geprüft. Bitte teilen Sie uns Fehler mit. | 翻訳は AI で作られ、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | 「Muttersprachlern」は男性形を総称に使う形です（ドイツ語ではふつうの言い方） |

## fr-FR（fr-CA も）

### 新機能の文（whatsnew.txt）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.1.W1.fr-FR | • En haut de l’écran, « ‹ Auj. › » a été déplacé tout à gauche, et la date s’affiche à sa droite. | ・画面上部で「‹ 今日 ›」（Auj.＝aujourd’hui の略）をいちばん左へ移し、日付がその右に出るようになりました。 | 「Auj.」は略語ですが、フランス語の読み手にはすぐ分かります |
| 1.4.1.W2.fr-FR | • Après avoir zoomé ou dézoomé, vous pouvez désormais revenir avec un seul bouton à la taille d’origine, où la page n’est ni zoomée ni dézoomée. | ・拡大や縮小をした後、ボタン 1 つで、ページが拡大も縮小もされていない元のサイズに戻れるようになりました。 | なし |
| 1.4.1.W3.fr-FR | • Une section « Main dominante » a été ajoutée aux Réglages. Si vous choisissez « Main gauche », l’ordre des boutons en haut de l’écran est inversé de gauche à droite. | ・設定に「利き手」の欄を加えました。「左手」を選ぶと、画面上部のボタンの順序が左右逆になります。 | なし |
| 1.4.1.W4.fr-FR | • Sur l’iPad, vous pouvez désormais déplacer la barre d’outils avec le doigt vers le bord supérieur, inférieur, gauche ou droit de l’écran. | ・iPad では、指でツールバーを画面の上・下・左・右の端へ動かせるようになりました。 | なし |
| 1.4.1.AI.fr-FR | Les traductions ont été faites avec une IA et n’ont pas encore été relues par des locuteurs natifs. Signalez-nous les erreurs. | 翻訳は AI で作ったもので、まだ母語話者の校閲を受けていません。誤りをお知らせください。 | 「Signalez-nous les erreurs.」は「どうぞ」に当たる語のない命令形で、少し素っ気なく聞こえます。「locuteurs natifs」は男性形を総称に使う形です |
