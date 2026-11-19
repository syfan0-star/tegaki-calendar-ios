# 1.3 の店の文の案（第 4 陣と週のメモ。本人の確認ページで見せる）

**対象の版: 1.3**。ここは案で、どれもまだ Connect にもアプリにも入れていない。本人の確認ページ（[M7C_CONTRACT.md](../M7C_CONTRACT.md) §12.3 の手順 4）で一緒に見せ、「この内容で入れてよい」をもらってから入れる。

## 1. 新機能の文の 5 つ目の点に足す 1 文（古い版での見え方）

- 点の番号: 足すのは「iPad と iPhone の両方をこの版にしてください。…」の点。週のメモの点が 2 つ目に入ったので、4 つ目から 5 つ目になった（週のメモの見直しで直した）。その後、1.2.4 で出した「ほかの端末で手書きを全て消したとき…」の点を 1.2.4 の公開の後に外したので（[R1_2_4.md](../R1_2_4.md) §4、2026-11-19）、また 4 つ目になった。同じ日に、H1 の点を 1.2.4 の文と食い違わない新しい文（「1.2.4 の直しに続いて、ほかの端末で手書きを全て消したあと…」）にして 4 つ目に戻したので（[M7C.md](../M7C.md) の「main（1.2.4）の取り込みと新機能の文の H1 の点」のリードの決定）、また 5 つ目になった（今の `ja/whatsnew.txt` の 5 行目）。点を足したり外したりして番号が変わっても、足す点はこの点。
- 入れる条件: §11.3 の行 18（1.2.3 の iPad Pro 13 で、はみ出した部分が紙の端で切れ、まわりの余白に線が出ていない）が ○ のとき（M7C.md、第 3 陣の第 2 段のリードの決定 6）。× なら入れない（SUPPORT は今の文で足りる）。
- 根拠: CI の古い版の余白の写真 30 枚（iPad 3 台 × 縦横 × 週・日と iPhone）が、どれも余白 0（M7C.md「古い版の余白の数」、run 43715400918 まで）。
- 入れる場所: 5 つ目の点の 2 つ目の文（「…片方のページにだけ出ます（消えてはいません）。」）の後。

| ロケール | 足す 1 文 | 元を見ない逆翻訳（1 回目 → 直した文の 2 回目） |
| --- | --- | --- |
| ja | はみ出した部分は、紙の端で切れて見えます。 | — |
| en-US（en-GB・en-AU・en-CA も） | The part that runs past the page appears cut off at the edge of the paper. | 1 回目「切れます」（注: 切り捨てたとも読める）→ 2 回目「紙の端で切れたように見えます」 |
| de-DE | Der Teil, der über die Seite hinausreicht, erscheint am Rand des Papiers abgeschnitten. | 1 回目「切り取られます」（同じ注）→ 2 回目「紙の端で切れたように見えます」 |
| es-ES・es-MX | La parte que sobresale de la página se ve cortada en el borde del papel. | 紙の端で切れて見えます |
| fr-FR（fr-CA も） | La partie qui dépasse de la page apparaît coupée au bord du papier. | 紙の端で切れて表示されます |
| it | La parte che oltrepassa la pagina appare tagliata sul bordo del foglio. | 紙の端で切れて表示されます |
| ko | 페이지 밖으로 나간 부분은 종이 가장자리에서 잘려 보여요. | ページの外に出た部分は、紙の端で切れて見えます |
| pt-BR | A parte que ultrapassa a página aparece cortada na borda do papel. | 紙の縁で切れて表示されます |
| pt-PT | A parte que ultrapassa a página aparece cortada na borda do papel. | 1 回目は extremidade（隅の響き）→ borda に直し、2 回目「紙の縁で切れたように見えます」 |
| zh-Hans | 超出页面的部分看起来会在纸的边缘被截断。 | 1 回目「断ち切られます」（同じ注）→ 2 回目「紙の端で途切れたように見えます」 |
| zh-Hant | 超出頁面的部分看起來會在紙的邊緣被截斷。 | 同上 |

- 2 回目の逆翻訳の注（直さない。母語の人に見てもらうときの候補）: zh の「截断」は、5 つの中ではいちばん「データが切り捨てられた」に近く読める（「看起来」と直前の「消えてはいません」があるので見込みは低い）。pt-PT の「cortada」には「線を引いて消す」の意味もある。

## 2. N-3（設定 › ページ の説明）の言い回しの案

- 今の ja（本人が承認した固定の文）: 「月と年は、**次の版から**順に対応します。」
- 案: 「月と年は、**今後の版で**順に対応します。」（月は 1.7・年は 1.8 の計画なので、「次の版」は 1.4 と読まれうる。M7C.md の第 1 陣の訳のリードの決定 2）
- 本人が「変える」と言ったら、キー `settings.page.span.footer` の 2 つ目の文を ja と 9 言語で替える（ja が変わるので、各言語の jaSha1 も替わる）。言わなければ今のまま。

| 言語 | 替える 2 つ目の文 | 元を見ない逆翻訳 |
| --- | --- | --- |
| en | Month and year pages will be supported one after another in future versions. | 1 回目は in turn（「その結果」とも読める）→ 直して 2 回目「今後のバージョンで順次対応する予定です」 |
| de | Monats- und Jahresseiten werden in künftigen Versionen nacheinander unterstützt. | 今後のバージョンで順に対応します |
| es | La función llegará a las páginas del mes y del año, una tras otra, en futuras versiones. | 今後のバージョンで、月と年のページに一つずつ順に加わります |
| fr | Les pages du mois et de l’année seront prises en charge l’une après l’autre dans de futures versions. | 今後のバージョンで一つずつ順に対応します |
| it | La funzione arriverà alle pagine del mese e dell’anno, una dopo l’altra, nelle versioni future. | 今後のバージョンで、一つずつ順に加わります |
| ko | 월 페이지와 연 페이지는 앞으로의 버전에서 차례로 지원할 예정이에요. | 今後のバージョンで順に対応する予定です |
| pt-BR | O recurso chegará às páginas do mês e do ano, uma depois da outra, em versões futuras. | 今後のバージョンで、一つずつ順に加わります |
| zh-Hans | 月页面和年页面将在今后的版本中依次支持。 | 今後のバージョンで順に対応します |
| zh-Hant | 月頁面和年頁面將在今後的版本中依序支援。 | 今後のバージョンで順に対応します |

- 逆翻訳の注: どの言語でも「次の版」とは読めない。ko の「연 페이지」は今の訳（承認済みの N-3）と同じ語。

## 3. App Store の写真の先頭の 1 枚（D26）

- `store-shots.yml` の run 43730832380（3d23aa3、11/16）: 12 組（en・en-GB・zh-Hans・zh-Hant・ko・fr・de・it・es・es-ES・pt-BR・ja）× 13 インチ iPad・6.9 インチ iPhone の `00-span.jpg`、24 枚。どれも Apple の大きさ（2064×2752・1320×2868）、警告 0。6.3 インチは 1.2 と同じく 6.9 インチを `sips -z 2622 1206` で縮めて作る。
- 中身: 週のページを横につないで、焦点の週（10/5〜10/11）の左の境目を画面の真ん中に置き、前の週の日曜の夜から月曜の朝へ 2 本の線がまたいでいる。前の週には予定とまたぐ線の半分だけ（見本の字は焦点の週だけ。3d23aa3 で、隣の週に同じ字が並んで写るのを直した）。
- 店の写真の順: `00-span` を先頭に、1.2 の 4 枚（`01`〜`04`）はそのまま。ja は先頭の 1 枚だけを足し、ほかは Connect の今の写真のまま。

## 4. 新機能の文の 2 つ目の点（週のメモ）に足す句（古い版での見え方。K-8）

- 根拠: 契約 §6.2 の K-8（古い端末での見え方を新機能の文に書く）と、§6.5 の「週の下のメモ」の行（古い版の端末では見えない・残る）。契約 §8.3 の固定の行は古い版のことを言わないので、句を足すかを本人に選んでもらう（週のメモの計画の決めどころ 8、M7C.md の「週のメモの計画のリードの決定」の 9）。
- 既定: 足す。足さないときは、今の `whatsnew.txt` の 2 つ目の点（契約の行とその訳）のまま。
- 入れる場所: 2 つ目の点の終わりの「。」の前（5 つ目の点の「（消えてはいません）」と同じ形）。
- 書かないこと: 設定で横につなげるのをオフにしても週のメモが出ることは、新機能の文には足さず、SUPPORT の「iPad と iPhone で版が違うと？」の括弧に書いた（決めどころ 27）。古い版の端末で「手書きを全て消す」をするとメモの手書きも消えることは、SUPPORT の同じ段落の最後の文が書いている。

| ロケール | 句を足した 2 つ目の点（全文） |
| --- | --- |
| ja（source-ja も） | ・週のページにも、24 時の下に自由メモができました（古い版の端末では見えませんが、消えてはいません）。 |
| en-US（en-GB・en-AU・en-CA も） | • Week pages now also have a “Free Notes” area below 24:00 (it is not shown on devices with an older version, but it has not been deleted). |
| de-DE | • Auch die Wochenseiten haben jetzt unter 24:00 einen Bereich „Freie Notizen“ (auf Geräten mit einer älteren Version ist er nicht zu sehen, wurde aber nicht gelöscht). |
| es-MX | • Las páginas de la semana ahora también tienen la zona “Notas libres” debajo de las 24:00 (en los dispositivos con una versión anterior no se ve, pero no se eliminó). |
| es-ES | • Las páginas de la semana ahora también tienen la zona “Notas libres” debajo de las 24:00 (en los dispositivos con una versión anterior no se ve, pero no se ha eliminado). |
| fr-FR（fr-CA も） | • Les pages de la semaine ont désormais, elles aussi, une zone « Notes libres » sous 24:00 (elle n’apparaît pas sur les appareils restés sur une version précédente, mais elle n’a pas été supprimée). |
| it | • Ora anche le pagine della settimana hanno l’area “Note libere” sotto le 24:00 (sui dispositivi con una versione precedente non si vede, ma non è stata eliminata). |
| ko | • 주 페이지에도 24시 아래에 ‘자유 메모’ 칸이 생겼어요(이전 버전을 쓰는 기기에서는 보이지 않지만, 지워진 것은 아니에요). |
| pt-BR | • As páginas da semana agora também têm a área “Notas livres” abaixo de 24:00 (em dispositivos com uma versão anterior ela não aparece, mas não foi excluída). |
| pt-PT | • As páginas da semana passam também a ter a área “Notas livres” abaixo das 24:00 (nos dispositivos com uma versão anterior não aparece, mas não foi eliminada). |
| zh-Hans | • 周页面现在也在 24 点下方新增了“自由备忘”栏（在使用旧版本的设备上看不到，但并没有被删除）。 |
| zh-Hant | • 週頁面現在也在 24 點下方新增了「自由備忘」欄（在使用舊版本的裝置上看不到，但並沒有被刪除）。 |

- 括弧の前までは、今の `whatsnew.txt` の 2 つ目の点と 1 字も違わない。括弧の中の「消えていない」は、5 つ目の点（「iPad と iPhone の両方を…」）の括弧と同じ語にした（en の deleted、de の gelöscht、es-MX の eliminó・es-ES の ha eliminado、fr の supprimée、it の eliminata、ko の 지워진、pt-BR の excluída、pt-PT の eliminada、zh の 删除・刪除）。
- 元を見ない逆翻訳と判定は `docs/i18n/back/store-<ロケール>.md` と [docs/i18n/REVIEW.md](../i18n/REVIEW.md) の 4 の「1.3 の週のメモの文」（2026-11-18、3 回）。1 回目の判定で ko・zh-Hans・zh-Hant の括弧を「古い版を使う端末」の形に、2 回目の判定で zh-Hans・zh-Hant の「24 点以下」「24 點以下」を「24 点下方」「24 點下方」に直した（後の直しは今の `whatsnew.txt` の 2 つ目の点も同じ）。3 回目は、リードが zh-Hans・zh-Hant の直した 4 文（2 つ目の点と K-8 の案）だけを、元を渡さずに別の Claude に訳し戻してもらい、4 文とも「24 時の下に」と読まれた（○。`docs/i18n/back/store-zh-Hans.md`・`store-zh-Hant.md` の「3 回目」の行）。
