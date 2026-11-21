# ストアの文 1.4.1 の新機能の文、並べ方 (b) の 1 つ目の点の訳（11 組。元を見ない逆翻訳はまだ）

**R へ**: 訳し戻しを書くまで、このファイルを読まないでください（日本語の元と、元を見て書いた確かめがあります）。下の表の「行 1 (b) の訳」の列の 11 行だけを受け取って訳し戻します。

**対象の版: 1.4.1**。本人が見出しの並べ方 (b) を選んだときに、各ロケールの `docs/store/<ロケール>/whatsnew.txt` の 1 行目と入れ替える行です（契約 [R1_4_1_CONTRACT.md](../../R1_4_1_CONTRACT.md) §8.3、[PROPOSALS_1_4_1.md](../../store/PROPOSALS_1_4_1.md) §1.1 の「行 1 (b)」）。2 行目から後（行 2〜4 と訳についての 1 行）は `whatsnew.txt` のままです。

- 元（`source-ja` の行 1 (b)。契約 §8.3 の `>` の行）: ・画面の上の「‹ 今日 ›」を、左の端の日付のすぐ右に移しました。
- 書いた時: 2026-11-22。D2 の判定で「行 1 (b) の訳が無い」が 11 組とも × になり（[REVIEW.md](../REVIEW.md) の 14）、その直しとして書きました。
- 語: 「今日」は各言語のアプリの `header.today` の訳（pt-PT はアプリの pt-BR の語）。「左の端」と「画面の上」は、同じロケールの今の行 1 (a)（`whatsnew.txt` の 1 行目）と同じ語です。fr-FR の « » の内側は、行 1 (a) と同じ U+00A0 です。
- 写し: en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の字をそのまま使います（`locales.json` の `copyOf`）。
- 字数（L-9 の数え方。ファイルの末尾の改行 1 つを除く）: 行 1 を (b) にした全体で、どれも 4,000 字に入ります（下の表）。(b) にした 11 のファイルを一度作業ツリーに置いて `lint.py` を走らせ、L-9 は ok でした（その後、ファイルは (a) の字に戻して、sha1 が前と同じことを確かめました）。

**元を見ない逆翻訳と判定はまだです。** この訳を書いた Claude は日本語の元を知っているので、自分で訳し戻しても元を見ない逆翻訳になりません。下の表の「逆翻訳」の列は、訳を書いた Claude が元を見て書いた確かめで、R の逆翻訳ではありません。R（日本語の元・契約・GLOSSARY・PROPOSALS を読まない Claude）にこの表の「訳」の列だけを渡して訳し戻してもらい、判定の 2 役にかけてから、本人の確認ページに出します。

| ロケール | 今の行 1 (a)（比べるため） | 行 1 (b) の訳 | 逆翻訳（訳を書いた Claude が元を見て書いた。元を見ない逆翻訳ではない） | 全体の字数 (a) → (b) |
| --- | --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も） | • Moved “‹ Today ›” at the top of the screen to the left end and placed the date to its right. | • Moved “‹ Today ›” at the top of the screen so that it is immediately to the right of the date, which is at the left end. | ・画面の上の「‹ 今日 ›」を、左の端にある日付のすぐ右に来るように移しました。 | 565 → 593 |
| zh-Hans | • 屏幕顶部的“‹ 今天 ›”已移到左端，日期排在它的右边。 | • 屏幕顶部的“‹ 今天 ›”已移到左端日期的右边，紧挨着日期。 | ・画面の上の「‹ 今日 ›」を、左端の日付の右に、日付のすぐとなりに移しました。 | 176 → 178 |
| zh-Hant | • 螢幕頂端的「‹ 今天 ›」已移到左端，日期排在它的右邊。 | • 螢幕頂端的「‹ 今天 ›」已移到左端日期的右邊，緊鄰日期。 | ・画面の上の「‹ 今日 ›」を、左端の日付の右に、日付のすぐとなりに移しました。 | 176 → 177 |
| ko | • 화면 위쪽의 ‘‹ 오늘 ›’을 왼쪽 끝으로 옮기고, 날짜를 그 오른쪽에 두었어요. | • 화면 위쪽의 ‘‹ 오늘 ›’을 왼쪽 끝에 있는 날짜의 바로 오른쪽으로 옮겼어요. | ・画面の上の「‹ 今日 ›」を、左の端にある日付のすぐ右に移しました。 | 274 → 273 |
| fr-FR（fr-CA も） | • En haut de l’écran, « ‹ Auj. › » a été déplacé tout à gauche, et la date s’affiche à sa droite. | • En haut de l’écran, « ‹ Auj. › » a été déplacé juste à droite de la date, qui se trouve tout à gauche. | ・画面の上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左にあります。 | 678 → 685 |
| de-DE | • „‹ Heute ›“ oben auf dem Bildschirm wurde an den linken Rand verschoben, und das Datum steht jetzt rechts davon. | • „‹ Heute ›“ oben auf dem Bildschirm wurde direkt rechts neben das Datum verschoben, das am linken Rand steht. | ・画面の上の「‹ 今日 ›」を、左の端にある日付のすぐ右どなりに移しました。 | 691 → 688 |
| it | • In alto sullo schermo, “‹ Oggi ›” è stato spostato all’estremità sinistra e la data ora compare alla sua destra. | • In alto sullo schermo, “‹ Oggi ›” è stato spostato subito a destra della data, che si trova all’estremità sinistra. | ・画面の上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左の端にあります。 | 703 → 706 |
| pt-BR | • No alto da tela, “‹ Hoje ›” foi movido para o extremo esquerdo, e a data foi colocada à direita dele. | • No alto da tela, “‹ Hoje ›” foi movido para logo à direita da data, que fica no extremo esquerdo. | ・画面の上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左の端にあります。 | 643 → 639 |
| pt-PT | • No topo do ecrã, “‹ Hoje ›” foi movido para o extremo esquerdo e a data foi colocada à direita dele. | • No topo do ecrã, “‹ Hoje ›” foi movido para logo à direita da data, que fica no extremo esquerdo. | ・画面のいちばん上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左の端にあります。 | 629 → 626 |
| es-MX | • En la parte superior de la pantalla, “‹ Hoy ›” se movió al extremo izquierdo y la fecha se colocó a su derecha. | • En la parte superior de la pantalla, “‹ Hoy ›” se movió justo a la derecha de la fecha, que está en el extremo izquierdo. | ・画面の上で、「‹ 今日 ›」が日付のすぐ右に移りました。日付はいちばん左の端にあります。 | 677 → 687 |
| es-ES | • En la parte superior de la pantalla, “‹ Hoy ›” se ha movido al extremo izquierdo y la fecha se ha colocado a su derecha. | • En la parte superior de la pantalla, “‹ Hoy ›” se ha movido justo a la derecha de la fecha, que está en el extremo izquierdo. | ・画面の上で、「‹ 今日 ›」が日付のすぐ右に移りました。日付はいちばん左の端にあります。 | 691 → 696 |

訳を書いた Claude の注:

- 元の「左の端の日付」は、日付が左の端にあること（「‹ 今日 ›」が左の端へ行くのではない）なので、どの言語も「日付は左の端にある」を関係節かそれに当たる形で書き、「‹ 今日 ›」が左の端へ移ったとは読めないようにしました（en の “, which is at the left end”、fr の « qui se trouve tout à gauche »、de の „das am linken Rand steht“ など）。
- 「すぐ右」は immediately to the right of・紧挨着／緊鄰・바로 오른쪽・juste à droite・direkt rechts neben・subito a destra・logo à direita・justo a la derecha です。
- 行 1 (b) には等倍のボタンを書きません（契約 §8.3 の元の行に無い。行 1 (a) と同じ）。
