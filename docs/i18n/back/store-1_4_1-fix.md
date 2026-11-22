# ストア 1.4.1 の直しの逆翻訳（本人の 11/22 の直しの後: 新機能の文の行 1・行 2、審査メモの 1・2、SUPPORT.en の 6 文）

R が日本語の元を見ずに訳し戻した表です（2026-11-22）。母語の人の確認ではありません。判定は [REVIEW.md](../REVIEW.md) の 15 です。

- **R に渡したもの**: X が用意した訳の字の 30 行（リードのスクラッチの `rework/d2-for-R.txt`。各行は「所 TAB 行番号 TAB 訳の字」）。新機能の文は 11 のフォルダの `whatsnew.txt` の 1 行目（並び 案 B）と 2 行目、審査メモは「What is new in 1.4.1」の 1・2、SUPPORT.en は `docs/SUPPORT.en.md` の替わった 6 文です。R へ渡す段取りはリードの Workflow です。
- **日本語の元は渡していません**（`docs/store/source-ja`・`docs/store/ja`・`docs/SUPPORT.md`・審査メモの日本語の要約）。渡した 30 行に日本語の字が無いこと（かなが 0）は、X と FIX が機械で確かめました。
- R の逆翻訳はスクラッチの `rework/d2-back.txt` に書かれ、FIX がこの表に機械で写しました（訳の字と逆翻訳の字は 1 字も変えていない）。訳の字は commit のファイルの字と 30 行とも同じです（e52f6b2 で FIX が機械で照らした）。
- en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`docs/store/locales.json` の `copyOf`）。
- 案 A の英語（審査メモの案 A の 1、左手の FAQ の 2 文目の案 A。[PROPOSALS_1_4_1.md](../../store/PROPOSALS_1_4_1.md) §2.1・§3.2）と、案 A の行 1 の訳は、この 30 行に入っていません（REVIEW.md の 15 の「元を見ない逆翻訳がまだの物」）。

## 新機能の文（`docs/store/<ロケール>/whatsnew.txt` の 1 行目と 2 行目）

| ロケール | 行 | 訳（R が読んだ字） | 元を見ない逆翻訳 |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も） | 行 1 | • Moved “‹ Today ›” at the top of the screen to the right end and placed the date at the left end. | • 画面上部の「‹ 今日 ›」を右端に移し、日付を左端に置きました。 |
| en-US（en-GB・en-AU・en-CA も） | 行 2 | • After you zoom in or out, a single button now resets the zoom. On day and week pages, the page for one day or one week fits the width of the screen exactly; month and year pages go back to the size they had when you opened them. | • 拡大・縮小したあと、ボタン一つで拡大・縮小を元に戻せるようになりました。日と週のページでは、1日分または1週間分のページが画面の幅にぴったり収まります。月と年のページは、開いたときの大きさに戻ります。 |
| zh-Hans | 行 1 | • 屏幕顶部的“‹ 今天 ›”已移到右端，日期则放在左端。 | • 画面上部の「‹ 今日 ›」を右端に移動し、日付は左端に配置しました。 |
| zh-Hans | 行 2 | • 放大或缩小后，现在只需一个按钮就能重置缩放。在日页面和周页面上，一天或一周的页面宽度正好与屏幕宽度相同；在月页面和年页面上，则会回到打开时的大小。 | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日ページと週ページでは、1日または1週間のページの幅が画面の幅とちょうど同じになり、月ページと年ページでは、開いたときの大きさに戻ります。 |
| zh-Hant | 行 1 | • 螢幕頂端的「‹ 今天 ›」已移到右端，日期則放在左端。 | • 画面上部の「‹ 今日 ›」を右端に移動し、日付は左端に配置しました。 |
| zh-Hant | 行 2 | • 放大或縮小後，現在只需一個按鈕就能重置縮放。在日頁面和週頁面上，一天或一週的頁面寬度正好與螢幕寬度相同；在月頁面和年頁面上，則會回到開啟時的大小。 | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日ページと週ページでは、1日または1週間のページの幅が画面の幅とちょうど同じになり、月ページと年ページでは、開いたときの大きさに戻ります。 |
| ko | 行 1 | • 화면 위쪽의 ‘‹ 오늘 ›’을 오른쪽 끝으로 옮기고, 날짜를 왼쪽 끝에 두었어요. | • 画面上部の「‹ 今日 ›」を右端に移し、日付を左端に置きました。 |
| ko | 行 2 | • 확대·축소한 뒤에 버튼 하나로 확대·축소를 재설정할 수 있게 되었어요. 일 페이지와 주 페이지에서는 하루 또는 한 주 페이지의 너비가 화면 너비에 딱 맞고, 월 페이지와 연 페이지에서는 열었을 때의 크기로 돌아가요. | • 拡大・縮小したあと、ボタン一つで拡大・縮小をリセットできるようになりました。日ページと週ページでは1日または1週間のページの幅が画面の幅にぴったり合い、月ページと年ページでは開いたときの大きさに戻ります。 |
| fr-FR（fr-CA も） | 行 1 | • En haut de l’écran, « ‹ Auj. › » a été déplacé tout à droite, et la date s’affiche maintenant tout à gauche. | • 画面の上部で、「‹ 今日 ›」がいちばん右に移動し、日付がいちばん左に表示されるようになりました。 |
| fr-FR（fr-CA も） | 行 2 | • Après avoir zoomé ou dézoomé, vous pouvez désormais réinitialiser le zoom avec un seul bouton. Sur les pages du jour et de la semaine, la page d’un jour ou d’une semaine occupe alors exactement la largeur de l’écran. Les pages du mois et de l’année reviennent à la taille qu’elles avaient quand vous les avez ouvertes. | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、そのとき1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 |
| de-DE | 行 1 | • „‹ Heute ›“ oben auf dem Bildschirm wurde an den rechten Rand verschoben, und das Datum steht jetzt am linken Rand. | • 画面上部の「‹ 今日 ›」が右端に移動し、日付は左端に表示されるようになりました。 |
| de-DE | 行 2 | • Nach dem Vergrößern oder Verkleinern können Sie den Zoom jetzt mit einer einzigen Schaltfläche zurücksetzen. Auf Tages- und Wochenseiten ist die Seite eines Tages bzw. einer Woche dann genauso breit wie der Bildschirm; Monats- und Jahresseiten kehren zu der Größe zurück, die sie beim Öffnen hatten. | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、そのとき1日または1週間のページの幅が画面の幅とちょうど同じになります。月と年のページは、開いたときの大きさに戻ります。 |
| it | 行 1 | • In alto sullo schermo, “‹ Oggi ›” è stato spostato all’estremità destra e la data ora compare all’estremità sinistra. | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に表示されるようになりました。 |
| it | 行 2 | • Dopo aver ingrandito o rimpicciolito, ora può reimpostare lo zoom con un solo pulsante. Nelle pagine del giorno e della settimana, la pagina di un giorno o di una settimana occupa esattamente la larghezza dello schermo; le pagine del mese e dell’anno tornano alla dimensione che avevano quando le ha aperte. | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 |
| pt-BR | 行 1 | • No alto da tela, “‹ Hoje ›” foi movido para o extremo direito, e a data foi colocada no extremo esquerdo. | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 |
| pt-BR | 行 2 | • Depois de ampliar ou reduzir, agora você pode redefinir o zoom com um único botão. Nas páginas do dia e da semana, a página de um dia ou de uma semana ocupa exatamente a largura da tela; as páginas do mês e do ano voltam ao tamanho que tinham quando você as abriu. | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 |
| pt-PT | 行 1 | • No topo do ecrã, “‹ Hoje ›” foi movido para o extremo direito e a data foi colocada no extremo esquerdo. | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 |
| pt-PT | 行 2 | • Depois de ampliar ou reduzir, agora pode repor o zoom com um único botão. Nas páginas do dia e da semana, a página de um dia ou de uma semana ocupa exatamente a largura do ecrã; as páginas do mês e do ano voltam ao tamanho que tinham quando as abriu. | • 拡大または縮小したあと、ボタン一つでズームを元に戻せるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 |
| es-MX | 行 1 | • En la parte superior de la pantalla, “‹ Hoy ›” se movió al extremo derecho y la fecha se colocó en el extremo izquierdo. | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 |
| es-MX | 行 2 | • Después de ampliar o reducir, ahora puede restablecer el zoom con un solo botón. En las páginas del día y de la semana, la página de un día o de una semana ocupa exactamente el ancho de la pantalla; las páginas del mes y del año vuelven al tamaño que tenían al abrirlas. | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 |
| es-ES | 行 1 | • En la parte superior de la pantalla, “‹ Hoy ›” se ha movido al extremo derecho y la fecha se ha colocado en el extremo izquierdo. | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 |
| es-ES | 行 2 | • Después de ampliar o reducir, ahora puede restablecer el zoom con un solo botón. En las páginas del día y de la semana, la página de un día o de una semana ocupa exactamente el ancho de la pantalla; las páginas del mes y del año vuelven al tamaño que tenían al abrirlas. | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 |

## 審査メモと SUPPORT.en

| 所 | 訳（R が読んだ字） | 元を見ない逆翻訳 |
| --- | --- | --- |
| `review-note.txt` の「What is new in 1.4.1」の 1 | 1. The date is now at the left end of the header, and ‹ Today › and the 1× button (a magnifying glass with "1") are at the right end (on narrow screens, 1× ends the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. 日付は見出しの帯（ヘッダー）の左端に移り、‹ 今日 › と 1× ボタン（「1」の入った虫めがね）は右端に来ました（幅の狭い画面では、1× は2段目のいちばん最後に来ます）。設定 > 利き手 > 左手 にすると、この並びが逆になります。 |
| `review-note.txt` の「What is new in 1.4.1」の 2 | 2. 1× resets the zoom: on day and week pages, one day or one week fits the screen width exactly; month and year pages go back to the size they open at. The next page of that type opens at the same size. | 2. 1× で拡大・縮小がリセットされます。日と週のページでは1日または1週間が画面の幅にぴったり収まり、月と年のページは開いたときの大きさに戻ります。その種類の次のページも同じ大きさで開きます。 |
| `SUPPORT.en.md:158`（How do I zoom in and out? の 2 段落目）の 1 文目 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” at the top right, to reset the zoom at once (from version 1.4.1): on day and week pages, one day's or one week's page fits the width of the screen exactly; on month and year pages, the page goes back to the size it had when you first opened it. | 右上の「‹ 今日 ›」の隣にある、「1」の入った虫めがねのボタン（ズームをリセット）をタップすると、拡大・縮小を一度でリセットできます（バージョン 1.4.1 から）。日と週のページでは1日分または1週間分のページが画面の幅にぴったり収まり、月と年のページでは最初に開いたときの大きさに戻ります。 |
| `SUPPORT.en.md:158` の 2 文目 | On a narrow screen (a narrow iPad window, or iPhone in portrait except on the inner screen of iPhone Duo), this button is at the right of the second row (the Day, Week, Month and Year switch). | 幅の狭い画面（iPad の幅の狭いウインドウ、または縦向きの iPhone。ただし iPhone Duo の内側の画面は除く）では、このボタンは2段目（日・週・月・年の切り替え）の右にあります。 |
| `SUPPORT.en.md:158` の 3 文目 | When “Left Hand” is chosen in the App's Settings > Dominant Hand, it is at the top left (on a narrow screen, at the left of the second row). | アプリの 設定 > 利き手 で「左手」を選んでいるときは、左上にあります（幅の狭い画面では2段目の左）。 |
| `SUPPORT.en.md:158` の 4 文目 | After you reset the zoom, pages of the same type keep opening that way, even after you reopen the App. | ズームをリセットすると、その後も同じ種類のページはその大きさで開きます。アプリを開き直しても変わりません。 |
| `SUPPORT.en.md:158` の 5 文目（2 本の指の文。W が足した） | If you then change the size with two fingers, they open at the new size instead (or, if you made it smaller than the size the page had when you first opened it, at that first size). | そのあと2本の指で大きさを変えると、今度はその新しい大きさで開きます（ただし、最初に開いたときの大きさより小さくした場合は、その最初の大きさで開きます）。 |
| `SUPPORT.en.md:162`（How do I use it with my left hand?）の 2 文目 | The order of the buttons at the top of the screen is reversed from left to right: “‹ Today ›” and the Reset Zoom button move to the left end, and the date to the right end. | 画面上部のボタンの並びが左右逆になります。「‹ 今日 ›」とズームをリセットするボタンが左端に、日付が右端に移ります。 |

## 判定（REVIEW.md の 15）

判定の 2 役（訳を書いた X とも R とも別の Claude 2 人。相談していない）が、30 行を日本語の元と照らしました。**2 人の 60 行で × は 0**、△ は判定 1 の pt-PT の行 2 の 1 つ（直さない。理由は REVIEW.md の 15）。判定の後に替えた訳の行はありません。
