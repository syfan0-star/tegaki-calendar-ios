# 訳の照らし合わせ（1.2「世界対応」）

訳は Claude（X）が書き、別の Claude（R）が日本語の元を見ずに訳し戻して照らしました（[M7B_CONTRACT.md](../M7B_CONTRACT.md) §6.1 の 3）。**各言語を母語とする人の確認はありません。** 本人は日本語しか読めません。誤りはサポートのメールで受け、次の版で直します（§6.1 の 8）。

**R へ**: 訳し戻しを書くまで、このファイルを読まないでください（読むと訳し戻しが元に引きずられます）。2 回目は `m7b-impl/R/work/changed.py` が出すキーだけを、`tools/l10n/translations/<言語>.json` の値とキーの `comment` だけから訳し戻します。

判定: **○** 同じ意味 ／ **△** 言い回しの差（理由を書く）／ **×** 意味の違い（直して R がもう一度訳し戻す）。逆翻訳の全文は `docs/i18n/back/` にあります。

## 1. 結果

| 言語 | ○ | △ | × |
| --- | --- | --- | --- |
| en | 434 | 42 | 0 |
| zh-Hans | 440 | 36 | 0 |
| zh-Hant | 439 | 37 | 0 |
| ko | 439 | 37 | 0 |
| fr | 410 | 66 | 0 |
| de | 416 | 60 | 0 |
| es | 407 | 69 | 0 |
| it | 413 | 63 | 0 |
| pt-BR | 409 | 67 | 0 |
| 合計（476 キー × 9 言語） | 3807 | 477 | 0 |

- **アプリの文字列**: × は 0 件です（1 回目の × は 2 の表のとおり直し、R の 2 回目で確かめました）。
- **ストアの文（11 組と審査メモ）**: × は 0 件（4）。「か月分」にあたる語は 0 件です。
- **英語の 3 文書（§11.3 の文を含む）**: × は 0 件（5）。
- **検証の後に FIX が変えた訳とストアの字**は 10 にあります。FIX の逆翻訳は元を見て書いたものなので、2026-11-05 に別の Claude が元を見ずに 33 件を訳し戻し、判定しました（○ 12・△ 19・× 2）。× の 2 件（de の `toast.weekStart.otherForm.*`）は直し、直した字を含む 6 件をもう一度元を見ずに訳し戻しました（R4。○ 0・△ 6・× 0）。その後の直しも R5 で元を見ずに訳し戻しました。**今、元を見ない逆翻訳を通っていないのは FIX4 の pt-BR の見本の語 `Chope` 1 件だけです**（10）。
- **審査メモの TestFlight と審査のビルドの段落**は R の 2 回目で訳し戻し、○ と判定しました（6）。

## 2. × と直した訳

| キー | 言語 | 元の日本語 | 逆翻訳（1 回目） | 判定 | 意味の違い | 直した訳 | 逆翻訳（2 回目） |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `settings.weekStart.confirm.message.sunday` | fr | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、月曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（何も削除されません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | Les pages de semaine sont séparées pour les semaines qui commencent le lundi et celles qui commencent le dimanche. L’écriture manuscrite déjà présente sur vos pages de semaine reste masquée jusqu’au retour au lundi (elle n’est pas supprimée). L’écriture des pages de mois passe dans la case de la même date. Toutefois, une partie de ce qui est écrit dans les cases des jours du mois précédent ou suivant peut rester masquée jusqu’au retour (rien n’est supprimé). | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。あなたの週のページにすでにある手書きは、月曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れたままのことがあります（何も削除されません）。 |
| `settings.weekStart.confirm.message.sunday` | es | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、月曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（削除されません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | Las páginas de semana son distintas para las semanas que empiezan en lunes y las que empiezan en domingo. La escritura a mano que ya tiene en las páginas de semana queda oculta hasta que vuelva a lunes (no se elimina). La escritura de las páginas de mes pasa a la casilla de la misma fecha. Sin embargo, parte de lo escrito en casillas de días del mes anterior o siguiente puede quedar oculta hasta que vuelva (no se elimina). | 週のページは、月曜に始まる週と日曜に始まる週とで別のものです。週のページにすでにある手書きは、月曜に戻るまで隠れます（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れることがあります（削除されません）。 |
| `settings.weekStart.confirm.message.sunday` | it | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、月曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（削除されません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | Le pagine della settimana sono separate per le settimane che iniziano di lunedì e quelle che iniziano di domenica. La scrittura a mano già presente nelle pagine della settimana resta nascosta finché non torna a lunedì (non viene eliminata). La scrittura delle pagine del mese passa nella casella con la stessa data. Tuttavia, parte di ciò che è scritto nelle caselle dei giorni del mese precedente o successivo può restare nascosta finché non torna indietro (non viene eliminata). | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、月曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、元に戻るまで隠れたままのことがあります（削除されません）。 |
| `settings.weekStart.confirm.message.sunday` | pt-BR | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、月曜に戻すまで隠れたままです（消えません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（消えません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | As páginas da semana são separadas para semanas que começam na segunda-feira e semanas que começam no domingo. A escrita à mão que você já tem nas páginas da semana fica oculta até você voltar para segunda-feira (ela não é apagada). A escrita das páginas do mês passa para a célula da mesma data. No entanto, parte do que foi escrito em células de dias do mês anterior ou seguinte pode ficar oculta até você voltar (não é apagada). | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、月曜に戻るまで隠れます（消されません）。月のページに書いたものは、同じ日付のセルに移ります。ただし、前の月か次の月の日のセルに書かれたものの一部は、戻るまで隠れることがあります（消されません）。 |
| `settings.weekStart.confirm.message.sunday` | ko | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜始まりと日曜始まりで別のページです。今書いた週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは同じ日付のマスへ移ります。ただし、前後の月の日付のマスに書いたものは、一部が戻すまで見えないことがあります（消えません）。 | ○（2 回目） | 「いま書いてある」が「たった今書いた」（지금 쓴）になり、さっき書いた分だけと読める | 주 페이지는 월요일 시작과 일요일 시작이 서로 다른 페이지예요. 지금까지 쓴 주 손글씨는 월요일 시작으로 되돌릴 때까지 보이지 않아요(지워지지 않아요). 월 페이지의 손글씨는 같은 날짜의 칸으로 옮겨져요. 다만 앞뒤 달의 날짜 칸에 쓴 것은 일부가 되돌릴 때까지 보이지 않을 수 있어요(지워지지 않아요). | 週のページは、月曜始まりと日曜始まりが互いに別のページです。これまでに書いた週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日付のマスに書いたものは、一部が戻すまで見えないことがあります（消えません）。 |
| `settings.weekStart.confirm.message.monday` | fr | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、日曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（何も削除されません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | Les pages de semaine sont séparées pour les semaines qui commencent le lundi et celles qui commencent le dimanche. L’écriture manuscrite déjà présente sur vos pages de semaine reste masquée jusqu’au retour au dimanche (elle n’est pas supprimée). L’écriture des pages de mois passe dans la case de la même date. Toutefois, une partie de ce qui est écrit dans les cases des jours du mois précédent ou suivant peut rester masquée jusqu’au retour (rien n’est supprimé). | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。あなたの週のページにすでにある手書きは、日曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れたままのことがあります（何も削除されません）。 |
| `settings.weekStart.confirm.message.monday` | es | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、日曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（削除されません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | Las páginas de semana son distintas para las semanas que empiezan en lunes y las que empiezan en domingo. La escritura a mano que ya tiene en las páginas de semana queda oculta hasta que vuelva a domingo (no se elimina). La escritura de las páginas de mes pasa a la casilla de la misma fecha. Sin embargo, parte de lo escrito en casillas de días del mes anterior o siguiente puede quedar oculta hasta que vuelva (no se elimina). | 週のページは、月曜に始まる週と日曜に始まる週とで別のものです。週のページにすでにある手書きは、日曜に戻るまで隠れます（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れることがあります（削除されません）。 |
| `settings.weekStart.confirm.message.monday` | it | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、日曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（削除されません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | Le pagine della settimana sono separate per le settimane che iniziano di lunedì e quelle che iniziano di domenica. La scrittura a mano già presente nelle pagine della settimana resta nascosta finché non torna a domenica (non viene eliminata). La scrittura delle pagine del mese passa nella casella con la stessa data. Tuttavia, parte di ciò che è scritto nelle caselle dei giorni del mese precedente o successivo può restare nascosta finché non torna indietro (non viene eliminata). | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、日曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、元に戻るまで隠れたままのことがあります（削除されません）。 |
| `settings.weekStart.confirm.message.monday` | pt-BR | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週の手書きは、日曜に戻すまで隠れたままです（消えません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスに書いたものの一部は、戻すまで隠れたままのことがあります（消えません）。 | ○（2 回目） | 「いま書いてある週の手書き（全部の週）」が「今の週の手書き」になり、今週の分だけと読める。切り替えの文で、隠れる物を取り違えるのは危ない | As páginas da semana são separadas para semanas que começam na segunda-feira e semanas que começam no domingo. A escrita à mão que você já tem nas páginas da semana fica oculta até você voltar para domingo (ela não é apagada). A escrita das páginas do mês passa para a célula da mesma data. No entanto, parte do que foi escrito em células de dias do mês anterior ou seguinte pode ficar oculta até você voltar (não é apagada). | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、日曜に戻るまで隠れます（消されません）。月のページに書いたものは、同じ日付のセルに移ります。ただし、前の月か次の月の日のセルに書かれたものの一部は、戻るまで隠れることがあります（消されません）。 |
| `settings.weekStart.confirm.message.monday` | ko | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | 週のページは、月曜始まりと日曜始まりで別のページです。今書いた週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは同じ日付のマスへ移ります。ただし、前後の月の日付のマスに書いたものは、一部が戻すまで見えないことがあります（消えません）。 | ○（2 回目） | 「いま書いてある」が「たった今書いた」（지금 쓴）になり、さっき書いた分だけと読める | 주 페이지는 월요일 시작과 일요일 시작이 서로 다른 페이지예요. 지금까지 쓴 주 손글씨는 일요일 시작으로 되돌릴 때까지 보이지 않아요(지워지지 않아요). 월 페이지의 손글씨는 같은 날짜의 칸으로 옮겨져요. 다만 앞뒤 달의 날짜 칸에 쓴 것은 일부가 되돌릴 때까지 보이지 않을 수 있어요(지워지지 않아요). | 週のページは、月曜始まりと日曜始まりが互いに別のページです。これまでに書いた週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日付のマスに書いたものは、一部が戻すまで見えないことがあります（消えません）。 |
| `toast.weekStart.otherForm.one` | fr | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ の週のページはもう一方の最初の日（%1$@）で、削除されていません。設定 > 週の最初の日。 | △（R4） | 文が「設定 > 週の最初の日」で終わり、「切り替えると見える」が落ちていた（3 行に入れるための短縮が行きすぎ） | %2$@ page de semaine (1er jour : %1$@), non supprimée. Pour la voir : Réglages > Premier jour de la semaine. | 週ページ %2$@ ページ（1日目：%1$@）、削除はされていません。それを見るには：設定 > 週の最初の日。 |
| `toast.weekStart.otherForm.one` | it | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ の週のページはもう一方の最初の日（%1$@）を使っていて、削除されていません。設定 > 週の最初の日 を見てください。 | △（2 回目） | 文が「設定 > 週の最初の日 を見てください」で終わり、「切り替えると見える」が落ちていた | %2$@ pagina settimanale (inizio: %1$@), non eliminata. Per vederla: Impostazioni > Primo giorno della settimana. | 週ページ %2$@ ページ（始まり：%1$@）、削除はされていません。それを見るには：設定 > 週の最初の日。 |
| `toast.weekStart.otherForm.other` | fr | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ の週のページはもう一方の最初の日（%1$@）で、削除されていません。設定 > 週の最初の日。 | △（R4） | 文が「設定 > 週の最初の日」で終わり、「切り替えると見える」が落ちていた（3 行に入れるための短縮が行きすぎ） | %2$@ pages de semaine (1er jour : %1$@), non supprimées. Pour les voir : Réglages > Premier jour de la semaine. | 週ページ %2$@ ページ（1日目：%1$@）、削除はされていません。それらを見るには：設定 > 週の最初の日。 |
| `toast.weekStart.otherForm.other` | it | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ の週のページはもう一方の最初の日（%1$@）を使っていて、削除されていません。設定 > 週の最初の日 を見てください。 | △（2 回目） | 文が「設定 > 週の最初の日 を見てください」で終わり、「切り替えると見える」が落ちていた | %2$@ pagine settimanali (inizio: %1$@), non eliminate. Per vederle: Impostazioni > Primo giorno della settimana. | 週ページ %2$@ ページ（始まり：%1$@）、削除はされていません。それらを見るには：設定 > 週の最初の日。 |
| `onboarding.dayPageTap` | en | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | 日のページを開くには、年のページで日付か左端の数字（今月のその日）をタップするか、月のページで日付の数字をタップするか、週・月・年のページのマスを指でダブルタップします。 | ○（2 回目） | 「指で」が最後のダブルタップにしか掛からず、日付のタップは Apple Pencil でもよいと読める。元は 3 つとも指 | To open a day page with your finger, tap a date or the number on the left edge (that day of this month) on the year page, tap a date number on the month page, or double-tap a cell on the week, month or year page. | 指で日のページを開くには、年のページで日付か左端の数字（今月のその日）をタップするか、月のページで日付の数字をタップするか、週・月・年のページでセルをダブルタップします。 |
| `onboarding.dayPageTap` | fr | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | 日のページを開くには: 年のページで日付か左端の数字（今月のその日）をタップ、月のページで日付の数字をタップ、週・月・年のページでマスを指でダブルタップします。 | ○（2 回目） | 「指で」が最後のダブルタップにしか掛からず、日付のタップは Apple Pencil でもよいと読める。元は 3 つとも指 | Pour ouvrir une page du jour avec le doigt : sur la page de l’année, touchez une date ou le chiffre du bord gauche (ce jour du mois en cours) ; sur la page du mois, touchez le chiffre d’une date ; sur les pages de semaine, de mois et d’année, touchez deux fois une case. | 指で日のページを開くには: 年のページでは、日付か左端の数字（今の月のその日）をタップしてください。月のページでは、日付の数字をタップしてください。週・月・年のページでは、マスを 2 回タップしてください。 |
| `onboarding.dayPageTap` | de | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | 日のページを開くには: 年のページで日付か左端の数字（今月のその日）をタップする、月のページで日付の数字をタップする、または週・月・年のページでマスを指でダブルタップします。 | ○（2 回目） | 「指で」が最後のダブルタップにしか掛からず、日付のタップは Apple Pencil でもよいと読める。元は 3 つとも指 | So öffnen Sie eine Tagesseite mit dem Finger: Tippen Sie auf der Jahresseite auf ein Datum oder die Zahl am linken Rand (dieser Tag im aktuellen Monat), tippen Sie auf der Monatsseite auf eine Datumszahl, oder tippen Sie auf Wochen-, Monats- und Jahresseiten doppelt auf ein Feld. | 指で日のページを開くには次のとおりです: 年のページで日付か左端の数字（今の月のその日）をタップするか、月のページで日付の数字をタップするか、週・月・年のページで枠（Feld）をダブルタップしてください。 |
| `onboarding.dayPageTap` | es | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | 日のページを開くには: 年のページで日付か左端の数字（今月のその日）をタップ、月のページで日付の数字をタップ、週・月・年のページでマスを指でダブルタップします。 | ○（2 回目） | 「指で」が最後のダブルタップにしか掛からず、日付のタップは Apple Pencil でもよいと読める。元は 3 つとも指 | Para abrir una página del día con el dedo: en la página del año, toque una fecha o el número del borde izquierdo (ese día del mes actual); en la página del mes, toque el número de una fecha; en las páginas de semana, mes y año, toque dos veces una casilla. | 指で日のページを開くには: 年のページでは、日付か左端の数字（今の月のその日）をタップしてください。月のページでは、日付の数字をタップしてください。週・月・年のページでは、マスを 2 回タップしてください。 |
| `onboarding.dayPageTap` | it | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | 日のページを開くには: 年のページで日付か左端の数字（今月のその日）をタップ、月のページで日付の数字をタップ、週・月・年のページでマスを指でダブルタップします。 | ○（2 回目） | 「指で」が最後のダブルタップにしか掛からず、日付のタップは Apple Pencil でもよいと読める。元は 3 つとも指 | Per aprire una pagina del giorno con il dito: nella pagina dell’anno tocchi una data o il numero sul bordo sinistro (quel giorno del mese corrente); nella pagina del mese tocchi il numero di una data; nelle pagine di settimana, mese e anno tocchi due volte una casella. | 指で日のページを開くには: 年のページでは、日付か左端の数字（今の月のその日）をタップしてください。月のページでは、日付の数字をタップしてください。週・月・年のページでは、マスを 2 回タップしてください。 |
| `onboarding.dayPageTap` | pt-BR | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | 日のページを開くには: 年のページで日付か左端の数字（今月のその日）をタップ、月のページで日付の数字をタップ、週・月・年のページでマスを指でダブルタップします。 | ○（2 回目） | 「指で」が最後のダブルタップにしか掛からず、日付のタップは Apple Pencil でもよいと読める。元は 3 つとも指 | Para abrir uma página do dia com o dedo: na página do ano, toque em uma data ou no número da borda esquerda (esse dia do mês atual); na página do mês, toque no número de uma data; nas páginas de semana, mês e ano, toque duas vezes em uma célula. | 指で日のページを開くには: 年のページでは、日付か左端の数字（今の月のその日）をタップしてください。月のページでは、日付の数字をタップしてください。週・月・年のページでは、セルを 2 回タップしてください。 |
| `demo.event.morningMeeting` | de | 朝会 | 朝（「明日」とも読める語） | △（2 回目） | Morgen は「朝」のほかに「明日」とも読め、朝会と読めない（ストアの写真に出る） | Daily | デイリー（Daily。毎日の短い打ち合わせを指す英語の借用語。「朝」にあたる語は入っていない） |
| `demo.event.dentalCheck` | de | 歯科 | 歯（歯科） | △（2 回目） | Zahn は「歯」だけで、歯科の予定と読めない | Zahncheck | 歯のチェック（Zahncheck。歯の検診のくだけた言い方） |
| `demo.event.payday` | es | 給料日 | 支払い（給料日の意味にも読める） | △（2 回目） | Pago は「支払い」で、払う方の予定とも読める | Nómina | 給与（Nómina。給与・給与明細の意。「日」にあたる語は入っていない） |
| `demo.event.farewell` | it | 送別会 | あいさつ（お別れ） | △（2 回目） | Saluti は「あいさつ」が先に読まれ、送別と読みにくい | Addio | 別れ（Addio。「さようなら」の意の語で、長い別れ・最後の別れの響きがある。「会」や「集まり」にあたる語は入っていない） |

測り直し: `toast.weekStart.otherForm.*` の直しの後、Mac Catalyst の字で `ToolbarFitTests`・`PaperFitTests`・`WeekStartChoiceTests` を走らせて 38 本すべて通りました（`testWeekStartToastsFitThreeLines` は 402 pt で 3 行以内。375 pt で 4 行になっていた de・it・pt-BR の文は、検証の後に FIX が短くして、この Mac では 3 行に入ります。10）。本当の判定は CI-0 のシミュレータです。見本の語の幅（10 pt）: Daily 25.0、Zahncheck 55.3（5.7 em まで）、Nómina 38.0（4.2 em まで）、Addio 28.9（5.7 em まで）。

it の `toast.weekStart.otherForm.*` の判定と「逆翻訳（2 回目）」は、FIX が短くした今の字を 2026-11-05 に別の Claude が元を見ずに訳し戻したものです（10）。「もう一方の」が無いので ○ から △ に変えました。

fr の同じキーの「直した訳」は、311 pt の 3 行に入れるために短くした後、R4 が直した今の字です（10 の R4 の表）。「逆翻訳（2 回目）」は R5 が元を見ずに書いたものです（10 の R5 の表）。「もう一方の」が無いので ○ から △ に変えました。

## 3. §6.1 で特に見ること

### `toast.pinchHint` の向き（広げる = 拡大、つまむ = 縮小）

元の日本語: 2 本の指を広げると拡大、つまむと縮小します

| 言語 | 訳 | 逆翻訳 | 向き |
| --- | --- | --- | --- |
| en | Spread two fingers to zoom in, pinch to zoom out | 2 本の指を広げると拡大、つまむと縮小します | ○ |
| zh-Hans | 双指张开可放大，双指捏合可缩小 | 2 本の指を開くと拡大、2 本の指でつまむと縮小します | ○ |
| zh-Hant | 兩指張開可放大，兩指捏合可縮小 | 2 本の指を開くと拡大、2 本の指でつまむと縮小します | ○ |
| ko | 두 손가락을 벌리면 확대, 오므리면 축소돼요 | 2 本の指を広げると拡大、すぼめると縮小します | ○ |
| fr | Écartez deux doigts pour zoomer, pincez pour dézoomer | 2 本の指を広げると拡大、つまむと縮小します | ○ |
| de | Zwei Finger spreizen zum Vergrößern, zusammenziehen zum Verkleinern | 2 本の指を広げると拡大、寄せると縮小します | ○ |
| es | Separe dos dedos para ampliar y júntelos para reducir | 2 本の指を離すと拡大、寄せると縮小します | ○ |
| it | Allarghi due dita per ingrandire, le avvicini per rimpicciolire | 2 本の指を広げると拡大、近づけると縮小します | ○ |
| pt-BR | Afaste dois dedos para ampliar e aproxime-os para reduzir | 2 本の指を離すと拡大、近づけると縮小します | ○ |

9 言語とも、指を広げる = 拡大、指を寄せる（つまむ）= 縮小です。R は §6.2 の用語集（この文の日本語と英語の対応）を読んだ後で訳し戻しているので（M7B.md の R の節）、逆翻訳だけに頼らず、X2 が 9 言語の訳の字も直接読んで同じ向きを確かめました。

### 切り替えの文（`settings.weekStart.confirm.message.*`）

- **向き**: `.sunday`（日曜にする）は「月曜に戻すまで」、`.monday`（月曜にする）は「日曜に戻すまで」。9 言語とも元と同じです。
- **消えないこと**: 週の手書きと、前後の月の日のマスの手書きの 2 か所とも、9 言語で「消えない」と言っています。
- **何が隠れるか**: 1 回目の fr・es・it・pt-BR は「今の週の手書き」と読め、ko は「さっき書いた手書き」と読めたので × にして直しました（2）。en・de・zh は「いまある手書き」と読めます。
- 月のページの手書きが同じ日付のマスへ移ることも、9 言語で元と同じです。

### 週の始まりの文の向き

- `toast.weekStart.regionChanged.monday`: 月曜にした → 日曜始まりの手書きは消えていない。`.sunday` はその逆。9 言語とも元と同じです。
- `toast.weekStart.adopted.*`・`import.otherWeekStart.*`・`settings.weekStart.confirm.title.*`・`.ok.*`: キーの曜日と文の曜日が 9 言語で合っています。

### §10.4 の 23 キー

契約 §10.4 の表のキーと日本語の値を、元のファイルと機械で照らしました。23 キーとも持ち主（U 21・S 2）と日本語が同じで、9 言語の訳と逆翻訳があります。`weekStart`・`otherWeekStart` を名前に持つキーはこの 23 だけです。`toast.pinchHint` の日本語は `<1.1.1>`（今は仮の 31d243c）の `CalendarRootScreen.pinchHintToast` と同じです。

### 入力の脚注（§6.3）

- `settings.input.eraserAutoReturn.footer.pad`: 9 言語とも「Apple Pencil のダブルタップやスクイーズで選んだ消しゴムでも同じ」と読めます。
- `settings.input.eraserAutoReturn.footer.phone`: 9 言語とも Apple Pencil と iPad の語がありません。

### ストアの「か月分」（§6.6）

`docs/store/` の 11 組の `*.txt` と `subscriptions/*.json` に、月数の語（months・mois・Monate・meses・mesi・个月・個月・개월・か月 ＋ 数字）は 0 件です。`docs/i18n/back/store-*.md`・`store-review-note.md`・`legal-en.md` に「か月分」は 0 件です（`legal-en.md` の「か月」は TERMS の「1 か月あたり 200 円」と責任の上限の「直前の 12 か月」の 2 か所で、値引きの文ではありません）。アプリの `kit.plan.savings.*` にはありますが、購入の画面の札で、価格から計算します（§6.6 の禁止の外）。

## 4. ストアの文（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・pt-PT・es-MX・es-ES と審査メモ）

逆翻訳は `docs/i18n/back/store-<ロケール>.md`、元は `docs/store/source-ja/` です。en-GB・en-AU・en-CA・fr-CA は同じ文です（`locales.json`）。**× は 0 件です。** アプリの画面の語（「予定にする」「手書きを書き出す」「表示する祝日」「週の始まり」「なし」）が各ロケールの文とアプリの訳で同じことを機械でも照らしました（0 件の違い）。

| 欄 | 判定 | △ の理由・見たこと |
| --- | --- | --- |
| `name.txt` 第 1 案 | ○ | 11 組とも「Tegaki ＋ 手書きカレンダー」の語 |
| `name.txt` 退き先 2 つ | △ | 重複で拒まれたときの候補で、各言語の自然な語にした。it・pt-BR・es は「手で書いた手帳」、fr-FR・it は「手帳の上のインク」のように元と語が少し違う。どれも Apple の商標を含まない |
| `subtitle.txt` | △ | fr・de・it・es・pt は 30 字に入れるため「予定の上にそのまま」を落とした（README の指定）。zh・ko は残した |
| `promo.txt` | △ | fr・it・es・pt は 170 字に入れるため「そのまま」を落とした言語がある。14 日間の無料は全ロケールにあり、価格も月数の語も無い |
| `keywords.txt` | △ | 訳ではなく、その言語の検索語を選んだ（名前とサブタイトルの語を避けた、README）。元の語の意味の範囲に入っている |
| `description.txt` の本文 | △ | fr・de・it・es・pt は箇条書きが動詞の原形や命令の形（「書く」「見る」）で、元の「書けます」と形が違う。各言語の店頭の普通の形で、できることの中身は同じ |
| `description.txt`「週の始まり」の行 | ○ | 月曜・日曜から選べること、24 時間の表示。11 組とも元と同じ |
| `description.txt` の利用規約の行 | ○ | Apple 標準 EULA の URL と今の日本語の `app/terms.html`（0-38） |
| `description.txt` の最後の 1 文 | ○ | 11 組とも「訳は AI、母語の人の確認はまだ、誤りを知らせてほしい」（§6.1） |
| `pt-PT/description.txt` の 10 行目 | △ | 元に無い行。「アプリの画面のポルトガル語はブラジルのもの」（§11.2 の指定） |
| `whatsnew.txt` の 5 点 | ○ | 言語・言語の戻し方・祝日・週の始まり（元に戻すまで見えないが消えない、古い版の端末の注）・端末ごとの設定。11 組とも元と同じ。pt-PT の「ポルトガル語（ブラジル）」は §11.2 の指定。de-DE は全文を 2026-11-05 に元を見ずに訳し戻した（R4、10。アプリ内の設定の 2 か所を「in Tegaki」に直した） |
| `en-US/whatsnew.txt` の 6・8 行目 | ○ | ホーム画面の名前と日本語の段落（§6.3 の指定で en-US だけ） |
| `whatsnew.txt` の最後の 1 文 | ○ | `description.txt` と同じ |
| `subscriptions/*.json` の表示名 | ○ | 「Tegaki ＋ 月額／年額」の語。価格なし |
| `subscriptions/*.json` の説明 | △ | 45 字に入れるため「〜が使える月額プラン」を「手書き、予定の作成、iCloud 同期」の形にした。fr・de・it・pt は「予定の作成」を「予定」に、es は iCloud を落とした。年額は「同じ機能を年ごとの請求で」。価格なし |
| `review-note.txt` | ○ | 言語・祝日・週の始まり・購入の流れ・復元・規約の場所・サインイン不要。EU の文は無い（§6.6）。6 の段落も ○ |

### 1.3 の新機能の文と審査メモ（2026-11-13）

元は `docs/store/source-ja/whatsnew.txt`（ja と同じ 4 つの点 → 訳についての 1 行。[M7C_CONTRACT.md](../M7C_CONTRACT.md) §8.3 の文から、1.3 に入らない週のメモの行を外し、最後の点に iPad での見え方の 1 文を足したもの。この 1 文は後でリードが外した。下の「決まっていないこと」）と、審査メモ `docs/store/review-note.txt` の日本語の要約と契約 §8.4 です。訳した 11 組（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・es-MX・es-ES・pt-PT）の `whatsnew.txt` の全文と、審査メモの英語の部分（日本語の要約より上）だけを別の Claude（R）に渡し、日本語の元を見ずに訳し戻してもらいました。判定は、訳とメモを書いた Claude とも R とも別の Claude が、逆翻訳と日本語の元を照らしたものです。母語の人の確認ではありません。逆翻訳の全文は `docs/i18n/back/store-<ロケール>.md` と `store-review-note.md` の「1.3」の節にあります。en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`locales.json` の `copyOf`）。

**× は 1 回目から 0 件でした。直した字はありません。** 新機能の文は 11 組 × 5 つ（4 つの点と訳についての 1 行）＝ 55 件で ○ 49・△ 6・× 0、審査メモは 12 の段で ○ 11・△ 1・× 0 です。抜けた事実も、元に無い事実もありませんでした。

アプリの画面の語は機械で照らしました（違いは 0 件）。11 組の文の「指でも書く」（`toolbar.fingerToggle`）と「設定」（`settings.title`）は origin/r13 の訳と、節の名前「ページ」（`settings.page.header`、N-1）は X の枝 r13-w-s5x（7c49b02）の訳と同じ語です（pt-PT はアプリの pt-BR の語、§11.2）。審査メモの Draw with Finger・Erase All・Erase and Start・Input・Purchase・Restore Purchases・Version・Pages も en の訳と同じです。月数の語（「か月分」にあたる語）は 0 件です。

新機能の文（判定の並びは en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・es-MX・es-ES・pt-PT）:

| 点 | 元の日本語 | en-US | zh-Hans | zh-Hant | ko | fr-FR | de-DE | it | pt-BR | es-MX | es-ES | pt-PT | △ の理由・見たこと |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 週と日のページが、前後のページと横につながりました。指で横にすべらせると、となりの週（日）が続いて出てきます。境目をまたいで、そのまま書けます（「指でも書く」がオンのときは、2 本指で横に動かします）。 | △ | ○ | ○ | ○ | △ | △ | △ | ○ | △ | △ | ○ | en-US・fr-FR・it・es-MX・es-ES は「続いて」が抜けた（逆翻訳は「隣の週（または日）が出てきます」「現れます」。bring in・faire apparaître・compare・aparecerá）。となりの週（日）が出てくることは同じ。de-DE・it は 2 本指で動かすものに「ページを」が付いた（die Seiten・le pagine）。指の数と向きは同じ。ko の「指で横に押す」は 밀다（韓国語の画面で、すべらせる操作の普通の語）。「（日）」は 11 組とも「（または日）」「（日）」で、日のページでは日と読める |
| 2 | 設定の「ページ」で、横につなげるのをオフにできます。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 11 組とも「設定の『ページ』（の項目）で、横のつながりをオフにできる」 |
| 3 | ほかの端末で手書きを全て消したとき、この端末に残っていた手書きが iCloud に戻ってしまうことがありうる問題を直しました。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 逆翻訳の多くは「消したあと」「戻ってしまうことがある」。訳はどれも可能の形（could・可能・수 있는・pouvait・konnte・poteva・podia・podía）で、起こりうる穴を直したという元の意味と同じ（起きたとは書いていない）。fr-FR の「送り返される」、de-DE の「再び iCloud に入る」も、手書きが iCloud に戻ること |
| 4 | iPad と iPhone の両方をこの版にしてください。古い版では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。古い版でその線を消すと、こちらでも消えます。この版の iPad では、縦でも横でも、前後のページが横につながって見えます。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 両方を更新する・古い版では片方のページにだけ出る（削除ではない）・古い版で消すとこの版でも消える、の 3 つが 11 組とも同じ。最後の文は、zh-Hans・zh-Hant・ko が元とほぼ同じ文に、ほかの 8 組が「iPad では、この版は縦でも横でも前後のページを横につなげる」と版を主語にした形に戻った（つながって見える、と同じこと）。**最後の文はリードの確認を待っている案**（下の「決まっていないこと」） |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 1.2.3 と同じ字（変えていない）。11 組とも「AI の訳・母語の人の確認はまだ・誤りを知らせてほしい」 |

審査メモ（`docs/store/review-note.txt`。3,935 バイト）:

| 段 | 判定 | △ の理由・見たこと |
| --- | --- | --- |
| サインイン不要 | ○ | 1.2.3 と同じ字 |
| What is new in 1.3 の 1 | ○ | 週と日のページが前後と横につながる・横にすべらせると隣の週や日・境目をまたいで書ける・またいだ線は中心のページに 1 本で保存（契約 D15）・ファイルと iCloud のレコードの形は同じ・古い版ではそのページにだけ出る・月と年は 1 ページずつ。日本語の要約の「保存の形は同じ。古い版では、またいだ線が片方のページにだけ出ます」と同じ |
| 同 2 | ○ | 設定の新しい節「ページ」にスイッチ 1 つ、既定はオン、端末ごと（契約 §3.14、`page.span`）。オフで 1.2.3 と同じ週と日のページ。要約の「設定 › ページ で切り替え」と同じ |
| 同 3 | ○ | 横につないだページを初めて開いたときの札、8 秒、端末ごと・種類ごとに 1 回（契約 §3.14） |
| 同 4 | ○ | 「全て消す」（この端末でもほかの端末でも）・「消して始める」で消した手書きが、開いているページ・取り消し・ページの取得から戻って iCloud へ送られることはもう無い。要約の「全て消した手書きが iCloud に戻りうる穴を直しました」と同じ |
| Unchanged の行 | △ | データ（データの収集なし）・購入・年齢区分・1.2.2 の年齢層の確認は同じ。handwriting storage が「手書きの保存方法」と読まれた（契約 §8.4 は「手書きの保存先（端末と本人の iCloud）」）。保存先は同じメモのサーバー無しの段に書いてあり、どちらの読みでも「変わらない」で意味は通る |
| 言語 | ○ | 1.2.3 と同じ字 |
| To test | ○ | 1.2.3 の字の後ろに 1.3 の確かめ方を足した。週のページを横にすべらせる（iPad は 1 本指、iPhone は 2 本指。iPhone は「指でも書く」が既定でオン、契約 §3.13）・2 つの週の境目をまたいで書く・設定 › ページ を試す（§8.4）。§8.4 の「日曜と月曜の境目」は、週の始まりが日曜の端末では週の境目が土曜と日曜になるので、両方を書いてある（書いた Claude の判断。§8.4 と同じ確かめ） |
| 購読 | ○ | 1.2.3 と同じ字 |
| TestFlight と審査のビルド | ○ | 1.2.3 と同じ字（1.2 の 6 で ○）。今回は題の「記録」を伏せずに渡した |
| サーバー無し | ○ | 1.2.3 と同じ字 |
| 6 つの URL | ○ | 1.2.3 と同じ字 |

決まっていないこと（判定には入れていない）:

- **4 つ目の点の最後の文**（「この版の iPad では、縦でも横でも、前後のページが横につながって見えます。」）は、**リードが外しました（2026-11-13）**。契約 §8.3 の「iPad での見え方の 1 文」は、古い版の iPad で、ページをまたいだ線のはみ出した部分が余白に見えるか紙の端で切れるか（§4.5、§6.5）のことで、この版の iPad の見え方の文ではありませんでした。また、iPad の横は CI の写真に無く、§11.3 の 8・9 の本人の確かめの前です。上の表の 4 の判定（○）は外す前の文のもので、外した後の 4 つ目の点は、残った 3 つの文の判定のままです。古い版の iPad の見え方が確かめられたら、その 1 文を足し、11 組を訳して、その文だけ元を見ない逆翻訳をします。
- **節の名前「ページ」**は、ストアの文と X の訳（`settings.page.header`）が今は同じ語です。どちらかを変えるときは両方を一緒に変えます。

## 5. 英語の 3 文書（`docs/TERMS.en.md`・`PRIVACY.en.md`・`SUPPORT.en.md`）

元は日本語の 3 文書（§11.3 の T-1〜T-9・P-1〜P-4・S-1〜S-6、§10.4 の FAQ、1.1.1 の文を含む）、逆翻訳は `docs/i18n/back/legal-en.md` です。全文を節ごとに照らしました。**× は 0 件です。** 価格・試用・解約・撤回の権利（最初の契約だけ、提供が始まるとなくなることがある、手続きは Apple）・準拠法と EU の消費者の裁判所・メールの扱い（Gmail、AI）・GDPR の権利・十分性の決定の範囲は、元と同じ意味でした。

| 場所 | 判定 | 理由 |
| --- | --- | --- |
| 解約などの道（TERMS 第 5 条、PRIVACY 第 9 節、SUPPORT の FAQ） | △ | 「設定 ›「Apple Account」› …（17 は Apple ID）」を「設定 > お名前（Apple Account。17 では Apple ID と呼ぶ）> …」に。Apple の英語の記事の手順の語（GLOSSARY の 3） |
| 冒頭の「翻訳です。日本語版が優先します」、末尾の AI の英訳の 1 文 | △ | 元に無い文。§6.4・§6.1 の 6 の指定 |
| SUPPORT の連絡先「日本の 1 人の開発者。英語か日本語で。機械翻訳で数営業日」、Apple の 118428 の案内 | △ | 元に無い文。§6.4 の指定 |
| SUPPORT の「翻訳について」、python-holidays の著作権表示と許諾文 | △ | 元に無い節。§6.1・§6.4 の指定（英語のサポートページに書く） |
| SUPPORT の言語の FAQ | △ | 元の「端末の表示が英語のときは Settings › …」を、英語のページでは「日本語の端末では「設定」› …」に入れ替えた（読み手が逆なので） |
| PRIVACY の Apple のプライバシーポリシーの URL | △ | 元の日本語版の URL を、英語の版 `apple.com/legal/privacy/` に（第 6 節） |
| お知らせの「Month DD」 | △ | 日付はまだ入らない（S-5。W の `check-legal` が見る。公開の日にリードが入れる、§11.1 の順 5） |
| 画面の名前 | ○ | Import from the Web Version・Holidays to Show・Week Starts On・Draw with Finger・Page with the Most Strokes などが `translations/en.json` の値と同じ（機械で照らした） |

## 6. 審査メモの TestFlight と審査のビルドの段落

`docs/store/review-note.txt` の次の段落は、中に日本語の「記録」があるので、R の 1 回目の手順（かな・漢字を含む行を飛ばす）で飛ばされました。R の 2 回目で訳し戻しました（`docs/i18n/back/store-review-note.md` の 9。「記録」の字は伏せて読んでいます）。

> In TestFlight and App Review builds (sandbox receipt) only, touching and holding Settings > About > Version opens a log sheet titled 「記録」 (in Japanese in every language) …

**判定は ○ です。** 逆翻訳の全文を英文と日本語の要約（「審査用のビルドでは「バージョン」の長押しで、開発者に送る動作の記録（書いた中身・日付・個人の情報なし）が開きます」）に照らしました。ビルドの限定（TestFlight と審査だけ、App Store のビルドには出ない）、長押しの場所、自動では送らないこと、中身の一覧、手書きの中身と日付と個人の情報が入らないことが合っています。R は「長押し」の語が合格の条件だと知って書いているので（M7B.md の R2 の節）、語の有無でなく全文で見ました。

## 7. R が引っかかった語の判定

R が元を見ずに「訳し戻すときに引っかかった」と申し送った語です。

| キー | 言語 | 訳 | 判定 | 理由 |
| --- | --- | --- | --- | --- |
| `toolbar.tool.marker` | es・pt-BR | Marcar | △ | 幅（F-12。Marcador は 47.8 pt で上限 47.5 pt を超える）。道具の並びの中ではマーカーと読める |
| `toolbar.width.thin` | fr | Fin | △ | Moyen・Épais と並ぶので太さと読める |
| `selection.deselect` | fr・es | Annuler・Cancelar | △ | 幅（F-15）。× の印が付いていて、押すと選択が解けるので、動きとの食い違いは無い。fr は `toolbar.undo` も Annuler で、読み上げの語は同じになる |
| `toolbar.collapse.title` | de | Ablegen | △ | 幅（F-12）。読み上げは ausblenden |
| `allday.label.short` | it | 24h | △ | 幅（F-7）。正式な形は Tutto il giorno |
| `selection.makeEvent`・`toolbar.tool.event` | fr | RDV | △ | 幅。用語集に書いた略 |
| `toast.weekStart.otherForm.*` | fr | 動詞を省いた短い文 | △（R4） | 「切り替えると見える」が落ちていた。直した（it も同じ）。その後 311 pt の 3 行に入れるため `avec début %1$@` にしたが、元を見ない逆翻訳（10）で「何の始まりか書かれていない」と言われ、`(1er jour : %1$@)` に直した |
| `toast.weekStart.otherForm.*` | de | 動詞を省いた短い文 | △ | 元を見ない逆翻訳（10）で「見える」が落ちていると分かり、Wechseln（切り替え）を Ansehen（見る）に直した。直した字は R4 の元を見ない逆翻訳で「見るには」と読まれた |
| `demo.event.birthday` | de | Feier | △ | 見本。Geburtstag は 4.2 em に入らない（56.6 pt） |
| `demo.event.morningMeeting` | de | Morgen | △（2 回目） | 「明日」と読める。Daily に直した |
| `demo.event.morningMeeting` | it | Mattutina | △ | 形容詞だけで予定の名に見えにくいので、FIX が Riunione に直した（10） |
| `demo.event.camping` | it・pt-BR | Tenda | △ | 見本。Camping は 44.4 pt で 4.2 em を超える。pt-BR は FIX3（10）。ブラジルでは Barraca の方がふつうの語だが、40.7 pt で写真の 2 日の帯に切れないかが写真でしか分からず、Tenda にした |
| `demo.event.farewell` | it | Saluti | △（2 回目） | あいさつと読める。Addio に直した |
| `demo.event.farewell` | fr | Départ | △ | 見本。pot de départ の略として通じる |
| `demo.event.payday` | es | Pago | △（2 回目） | 支払いと読める。Nómina に直した |
| `demo.event.checkup` | en | Exam | △ | 見本。Checkup は 44.2 pt で 4.2 em を超える |
| `demo.event.camping` | es | Carpa | △ | 見本。前の Acampar は CI の年の写真で「Acam...」に切れたので短い語にした（FIX3、10）。Mac Catalyst の字で 31.2 pt（上限 4.2 em は 42 pt）。スペインではテントは tienda がふつうだが、見本の語なので es-ES でも同じ字 |
| `demo.event.deadline` | es・it | Plazo・Scad. | △ | 見本。前の Entrega・Termine は iPhone の週の 1 日の帯で切れたので短い語にした（FIX3、10）。it の Scad. は scadenza の略 |
| `demo.event.drinks` | pt-BR | Chope | △ | 見本。前の Happy hour は CI の iPhone の月の写真で「Happy h...」に切れたので短い語にした（FIX4、10）。Chope はブラジルの生ビールの語で、飲み会そのものの語ではない（母語の人の確認は無い。O-6）。見本の語で写真にだけ出るので、短さを取った |
| `pt-PT/description.txt` の 10 行目 | pt-PT | | △ | §11.2 の指定 |
| `en-US/whatsnew.txt` の 6・8 行目 | en-US | | ○ | §6.3 の指定 |
| `SUPPORT.en.md` の「Month DD」 | en | | △ | S-5。W の検査の対象 |

## 8. △ の理由の一覧（アプリの文字列）

| キー | 言語 | 理由 |
| --- | --- | --- |
| `CFBundleDisplayName`・`app.name`・`kit.app.name`・`paywall.title` | 全部 | 名前は全言語で Tegaki（§6.2、M7B-1） |
| `kit.export.jsonFileName` | 全部 | ファイル名の頭も Tegaki（`kit.app.name` と同じ） |
| `allday.label.short` | en・fr・de・es・it・pt-BR | 10 pt で 24 pt に入れる短い形（F-7）。it の 24h は「24 時間」、All・Jour・Tag・Día・Dia は「全部」「日」の語。正式な形は `allday.label` にある |
| `header.today` | fr | Aujourd’hui は iPhone の題名の幅を削りすぎる（F-16） |
| `header.picker.week` | fr・es・it・pt-BR | 13 pt の semibold で 44 pt に入らないので略した形（F-16） |
| `toolbar.tool.event`・`toolbar.hint.event`・`selection.makeEvent` | fr | Évènement は 10 pt で 53 pt あり上限 47.5 pt に入らない。RDV（rendez-vous）はふつうの略で、文の中は évènement（F-12・F-14・F-15） |
| `toolbar.tool.marker` | es・pt-BR | Marcador は 47.8 pt で上限 47.5 pt を超える。Marcar は動詞の形だが、道具の並びの中ではマーカーと読める。文の中は marcador（F-12） |
| `toolbar.tool.marker`・`toolbar.badge.marker` | fr | Feutre（フェルトペン）。Marqueur より短い（F-12）。用語集の語 |
| `toolbar.collapse.title` | de・fr・it | Ausblenden・Masquer・Nascondi が 38 pt を超える。Ablegen（置く）・Réduire・Riduci（縮める）で「しまう」の動きと合う（F-12） |
| `toolbar.collapse.spoken` | fr・it | 目で見る名前（Réduire・Riduci）にそろえた |
| `toolbar.collapse.title`・`toolbar.collapse.spoken` | en・ko・es・pt-BR | 「隠す」の語。英語は契約の語 Hide（§6.2）で、ほかも同じ意味 |
| `selection.makeEvent` | de | In Termin umwandeln は 3 つの合計 220 pt に入らない（F-15）。Als Termin（予定として） |
| `selection.deselect` | fr・es | Désélectionner・Deseleccionar だと 3 つの合計が 220 pt を超える（F-15）。iOS の選択の画面を抜けるボタンと同じ語。× の印が付いていて、押すと選択が解ける（`.clearSelection`）。fr は `toolbar.undo` も Annuler なので、選択中は読み上げの語が同じになる（見た目は × の印で分かる。略の Désélect. より読みやすい方を残した） |
| `toolbar.hint.eraser`・`toolbar.hint.eraser.toPen`・`toolbar.hint.eraser.toMarker` | en・fr・de・es・it・pt-BR | 12 pt で 144 pt に入らないので「まるごと」を落とした（F-14） |
| `toolbar.hint.lasso` | fr・de・es・it・pt-BR | 155 pt に入れるため「枠の中を」を落とした（F-14） |
| `toolbar.hint.event` | de・es・it・pt-BR | 155 pt に入れるため「予定を」を落とした（F-14） |
| `toolbar.fingerToggle`・`settings.input.allowFinger` | pt-BR | Desenhar com o dedo は 13 pt で 137.9 pt あり上限 136 pt を超える（F-13）。Traçar（線を引く） |
| `toolbar.width.thin` | fr | Fin（細い）は「終了」と同じ綴りだが、Moyen・Épais と並ぶので太さと読める |
| `toolbar.moveEdge.*` | de | ボタンの短い形（「左下へ」）。動きは同じ |
| `toast.weekStart.hiddenInk.*` | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | iPhone の幅に 3 行で入れる短い言い方（§10.4）。「いまの週の始まり」が「今の設定」など。消えていないこと・戻すと見えることは残した |
| `toast.weekStart.otherForm.*` | de | 3 行に入れるため 1 文にまとめた（§10.4）。「もう一方の」は曜日で分かる形に。「消えていません」と「見る（Ansehen）: 設定 > 週の最初の日」は残した。「切り替えると」は設定の名前で分かる形 |
| `toast.weekStart.otherForm.*` | fr | 幅 375 pt で 3 行に入れるため 1 文にまとめた（§10.4）。「もう一方の」は曜日で分かる形に。曜日の %1$@ は設定の行と同じ大文字の字（Lundi・Dimanche）なので、設定の値を括弧に置く形（1er jour : Dimanche）にした。「消えていません」と「見るには: 設定 > 週の最初の日」は残した |
| `toast.weekStart.otherForm.*` | it | 幅 375 pt で 3 行に入れるため 1 文にまとめた（§10.4）。「もう一方の」は曜日で分かる形に（文の中で大文字にならないよう、fr と同じ括弧の `(inizio: %1$@)`。R5）。「消えていません」と「見るには: 設定 > 週の最初の日」は残した |
| `toast.weekStart.otherForm.*` | pt-BR | 幅 375 pt で 3 行に入れるため 1 文にまとめた（§10.4）。「別の始まり（曜日）」「消えていません」「見るには: 設定 > 週の最初の日」は残した |
| `holidayPicker.subdivisions`・`holidayPicker.subdivisionHint`・`holidayPicker.subdivisions.footer` | de | 「州」にあたる語が国で違う（Bundesland はドイツとオーストリア、米国などは Bundesstaat）ので、国を問わず Regionen（地域）にした |
| `toast.weekStart.adopted.*`・`toast.weekStart.regionChanged.*` | fr・es・it・pt-BR | 3 行に入れる短い言い方（§10.4）。「週の始まりを月曜に」が「週を月曜に」（es と、pt-BR の `regionChanged` は「週は月曜に始まる」）。曜日の向きは元と同じ |
| `demo.event.*`・`demo.calendar.*` | 全部 | ストアの写真の見本の語。年のチップ 4.2 em・月のチップ 5.7 em に入れる短い語（§7.4、GLOSSARY の 4）。意味は同じ系統で、文として読む物ではない |
| `kit.plan.cancelPath`・`kit.plan.paymentPath` | 全部 | Apple の 9 言語の記事の手順の語（「設定 > 自分の名前 > …」、GLOSSARY の 3）。iOS 17 の Apple ID の時代でも同じ道になる |
| `notice.calendar.denied`・`onboarding.pen.text`・`settings.input.pencil.footer`・`sync.footer.unknown`・`toast.event.noAccess` | es | 「設定」アプリを Ajustes (Configuración) と両方書いた。スペインの iOS は Ajustes、中南米は Configuración で、es の画面は 1 つ（GLOSSARY の 3） |
| `settings.weekStart.footer` | 全部 | 「（日本は月曜）」を書かない（契約の英語のとおり。日本以外の読み手に当てはまらない） |
| `settings.data.importFooter` | 全部 | Web 版の機能名を日本語のまま置き、その言語の説明を添えた（Web 版は日本語だけ。§6.2、`allowJapanese`） |
| `settings.holidays.footer` | 全部 | 内閣府を「日本の内閣府」に（日本以外の読み手のため）。旧暦は fr・de・es・it・pt-BR で「太陰暦」（各言語で通じる語）。en は契約の文のまま |
| `kit.plan.savings.*` | zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 「お得」を「節約」に。購入の画面の札で、価格から計算した月数を出す（ストアの文ではない。§6.6 の禁止の外） |
| `settings.calendar.google.howTo` | 全部 | 「データの取得方法」は各言語の iOS の実際の名前（GLOSSARY の 3）。es は Ajustes (Configuración) と Añadir / Agregar を両方。「15 分ごと」と語の一部は TestFlight で確かめる（GLOSSARY の「確かめられなかった語」） |
| `event.scribbleNote` | ko・es・it・pt-BR | スクリブルの各言語の名前（Apple の記事の語、GLOSSARY の 3） |
| `export.json.note`・`settings.data.exportFooter`・`settings.data.import`・`import.title` | en・fr・de・es・it・pt-BR | 「Web 版の手書きを取り込む」の英語は契約の語 Import from the Web Version（§6.2）で、ほかも同じ形 |
| `kit.holiday.dayOff` | 全部 | 英語は H の指定の Day off、中国語は 休息日（M7B.md の H の節）。データの短い名前が空のときだけ出す短い語で（FIX3 で年のマスのほか日・週・月の見出しにも）、0.107 ではこの語が出る型が無い（次の版の受け皿） |
| `kit.legal.appleEULATitle` | 全部 | Apple の店頭と審査の語 Terms of Use（利用規約）に EULA を括弧で添えた。指す文書は同じ |
| `notice.calendar.notDetermined` | 全部 | 「読み取りを許可」を「アクセスを許可」に。実際に出る許可の画面はフルアクセスなので、この方が画面と合う |
| `notice.calendar.restricted` | 全部 | 「手書きだけ使えます」を「手書きは使えます」に。予定が使えないことは前の文で分かる |
| `settings.input.eraseAfterConvert` | de・es・it・pt-BR | 設定の行の短い言い方（「予定の後に手書きを消す」）。動きは同じ |
| `settings.input.eraseAfterConvert.footer` | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 「初期値」を「最初の選択」と平易に。意味は同じ |
| `settings.input.eraserAutoReturn.title` | 全部 | 行の短い言い方（「消した後にペンに戻る」）。下の脚注に消しゴムと書いてある |
| `settings.weekStart.title` | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | iOS の「言語と地域」の同じ項目の語にそろえた（「週の最初の日」、GLOSSARY の 2）。意味は同じ |

## 9. アプリの文字列の全部の表

同じ逆翻訳の言語は 1 行にまとめました。「全部」は 9 言語です。△ の理由は 8、× の理由は 2 にあります。10 の表の 25 件の逆翻訳は、2026-11-05 に別の Claude が元を見ずに書いたものです（de の `toast.weekStart.otherForm.*` と pt-BR の `toast.weekStart.regionChanged.sunday` は、同じ日のもう 1 回〔R4〕で今の字を元を見ずに訳し戻したもの。fr の `toast.weekStart.otherForm.*` だけは、R4 の後に直した字を判定した Claude が元を見て書きました）。

| キー | 元の日本語 | 言語 | 逆翻訳 | 判定 | 直した訳 |
| --- | --- | --- | --- | --- | --- |
| `CFBundleDisplayName` | てがきカレンダー | en | Tegaki（手書き。ローマ字の名前） | △ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | Tegaki（ローマ字の名前） | △ |  |
| `NSCalendarsFullAccessUsageDescription` | カレンダーの予定を手帳のページに表示し、手書きから予定を作るために使います。iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスをお願いしています。予定はこの端末の中だけで扱い、外部には送りません。 | en | カレンダーの予定を手帳のページに表示するためと、手書きから予定を作るために使います。iOS と iPadOS には読み取り専用の許可がないので、アプリは「フルアクセス」を求めます。予定はこの端末の中だけで扱われ、どこにも送られません。 | ○ |  |
|  |  | zh-Hans | 手帳のページにカレンダーの予定を表示するためと、手書きの内容から予定を作るために使います。iOS と iPadOS には読み取り専用の権限がないので、「フルアクセス」が必要です。予定はこの端末の中だけで処理され、外部に送られません。 | ○ |  |
|  |  | zh-Hant | 手帳のページにカレンダーの予定を表示するためと、手書きの内容から予定を作るために使います。iOS と iPadOS には読み取り専用の権限がないので、「フルアクセス権限」が必要です。予定はこの端末の中だけで処理され、外部に送られません。 | ○ |  |
|  |  | ko | カレンダーの予定をプランナーのページに表示し、手書きから予定を作るために使います。iOS と iPadOS には読み取り専用の権限がないので、フルアクセスの権限を求めます。予定はこの端末の中だけで扱い、外部に送りません。 | ○ |  |
|  |  | fr | カレンダーの予定を手帳のページに表示するためと、手書きの文字から予定を作るために使います。iOS と iPadOS には読み取り専用の許可がないので、アプリはフルアクセスを求めます。予定はこの端末の中だけで処理され、どこにも送られません。 | ○ |  |
|  |  | de | カレンダーの予定をプランナーのページに表示するためと、手書きから予定を作るために使います。iOS と iPadOS には読み取りだけの権限がないので、フルアクセスを求めます。予定はこの端末の中だけで処理され、外部に送られません。 | ○ |  |
|  |  | es・it | カレンダーの予定を手帳のページに表示するためと、手書きから予定を作るために使います。iOS と iPadOS には読み取り専用の許可がないので、フルアクセスを求めます。予定はこの端末の中だけで扱われ、外部に送られません。 | ○ |  |
|  |  | pt-BR | カレンダーの予定を手帳のページに表示するためと、手書きから予定を作るために使います。iOS と iPadOS には読み取り専用の許可がないので、アプリは「フルアクセス」を求めます。予定はこの端末の中だけで扱われ、外部に送られません。 | ○ |  |
| `account.cancel` | キャンセル | 全部 | キャンセル | ○ |  |
| `account.erase` | 手書きを消して使い始める | en・ko・fr・de・es・it・pt-BR | 手書きを消して始める | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を消して使い始める | ○ |  |
| `account.eraseConfirm` | 消して始める | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 消して始める | ○ |  |
|  |  | ko | 消して開始 | ○ |  |
| `account.eraseMessage` | この端末の手書きを全て消して、新しいアカウントで始めます。この操作は元に戻せません。 | en | この端末の手書きがすべて消され、新しいアカウントで始めます。元に戻せません。 | ○ |  |
|  |  | zh-Hans | この端末のすべての手書きの内容を消し、新しいアカウントで始めます。この操作は取り消せません。 | ○ |  |
|  |  | zh-Hant | この端末のすべての手書きの内容を消し、新しいアカウントで始めます。この操作は元に戻せません。 | ○ |  |
|  |  | ko | この端末の手書きをすべて消し、新しいアカウントで始めます。この操作は元に戻せません。 | ○ |  |
|  |  | fr | この端末のすべての手書きが消され、新しいアカウントで始めます。この操作は取り消せません。 | ○ |  |
|  |  | de | この端末のすべての手書きが消され、新しいアカウントで始めます。元に戻せません。 | ○ |  |
|  |  | es・pt-BR | この端末のすべての手書きが消され、新しいアカウントで始めます。この操作は元に戻せません。 | ○ |  |
|  |  | it | この端末のすべての手書きが消され、新しいアカウントで始まります。この操作は取り消せません。 | ○ |  |
| `account.eraseTitle` | 本当に消しますか？ | en | 本当に消してよいですか？ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | 本当に消しますか？ | ○ |  |
| `account.keep` | 手書きを残して使い始める | en・ko・fr・de・es・it・pt-BR | 手書きを残して始める | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を残して使い始める | ○ |  |
| `account.later` | あとで | en | あとで | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | 後で | ○ |  |
| `account.message` | この端末の手書きは、前に同期していた iCloud アカウントのものです。いまサインインしているアカウントで使い始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。 | en | この端末の手書きは、以前に同期していた iCloud アカウントのものです。今サインインしているアカウントで使い始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | この端末の手書きの内容は、以前に同期していた iCloud アカウントのものです。今ログインしているアカウントで使い始めますか？ 手書きの内容を残すと、新しいアカウントの iCloud に送られます。 | ○ |  |
|  |  | ko・de | この端末の手書きは、以前に同期していた iCloud アカウントのものです。今ログインしているアカウントで始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。 | ○ |  |
|  |  | fr | この端末の手書きは、以前に同期していた iCloud アカウントのものです。今サインインしているアカウントで始めますか？ 残すと、新しいアカウントの iCloud に送られます。 | ○ |  |
|  |  | es・it | この端末の手書きは、以前に同期していた iCloud アカウントのものです。今サインインしているアカウントで始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。 | ○ |  |
|  |  | pt-BR | この端末の手書きは、以前に同期していた iCloud アカウントのものです。今接続しているアカウントで始めますか？ 手書きを残すと、新しいアカウントの iCloud に送られます。 | ○ |  |
| `account.title` | 別の iCloud アカウントです | en・fr・de・es・it・pt-BR | 別の iCloud アカウント | ○ |  |
|  |  | zh-Hans・zh-Hant | これは別の iCloud アカウントです | ○ |  |
|  |  | ko | 別の iCloud アカウントです | ○ |  |
| `alert.saveFailed.ok` | OK | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | OK | ○ |  |
|  |  | ko | 確認 | ○ |  |
| `alert.saveFailed.title` | 手書きを保存できませんでした | en・ko・de・es・pt-BR | 手書きを保存できませんでした | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を保存できません | ○ |  |
|  |  | fr・it | 手書きを保存できません | ○ |  |
| `allday.bar.spoken` | %@（予定を編集） | 全部 | %@（予定を編集） | ○ |  |
| `allday.column.spoken` | %@ の終日予定を追加 | 全部 | %@ に終日の予定を追加 | ○ |  |
| `allday.label` | 終日 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 終日 | ○ |  |
|  |  | fr | 終日（まる一日） | ○ |  |
| `allday.label.short` | 終日 | en | 終日（短い形。All） | △ |  |
|  |  | zh-Hans・zh-Hant・ko | 終日 | ○ |  |
|  |  | fr | 日（Jour） | △ |  |
|  |  | de | 日（Tag） | △ |  |
|  |  | es | 日（Día） | △ |  |
|  |  | it | 24 時間（24h） | △ |  |
|  |  | pt-BR | 日（Dia） | △ |  |
| `app.name` | てがきカレンダー | en | Tegaki（手書き。ローマ字の名前） | △ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | Tegaki（ローマ字の名前） | △ |  |
| `census.counting` | 数えています… | en・zh-Hans・ko・fr・de・es・it・pt-BR | 数えています… | ○ |  |
|  |  | zh-Hant | 計算しています… | ○ |  |
| `census.entry` | %1$@・%2$@ | 全部 | %1$@ · %2$@ | ○ |  |
| `census.legacyNote` | （古い版の端末では一部が表示されません） | en・fr・de・es・it・pt-BR |  （古い版の端末では一部が表示されません） | ○ |  |
|  |  | zh-Hans | （古い版の入った端末では、一部の内容が表示されません） | ○ |  |
|  |  | zh-Hant | （古い版を入れた端末では、一部の内容が表示されません） | ○ |  |
|  |  | ko |  （以前の版の端末では一部が表示されません） | ○ |  |
| `census.noInk` | まだ手書きがありません | en・fr・de・es・it・pt-BR | 手書きはまだありません | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容はまだありません | ○ |  |
|  |  | ko | まだ手書きがありません | ○ |  |
| `demo.calendar.events` | 行事 | en・de | 予定 | △ |  |
|  |  | zh-Hans・zh-Hant | 行事（イベント） | △ |  |
|  |  | ko | 行事 | ○ |  |
|  |  | fr・es・it・pt-BR | 予定（イベント） | △ |  |
| `demo.calendar.family` | 家族 | en・ko・fr・de・es・it・pt-BR | 家族 | ○ |  |
|  |  | zh-Hans・zh-Hant | 家庭 | △ |  |
| `demo.calendar.personal` | 個人 | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 個人 | ○ |  |
|  |  | de | 私用 | △ |  |
| `demo.calendar.work` | 仕事 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 仕事 | ○ |  |
|  |  | ko | 業務 | △ |  |
| `demo.event.birthday` | 誕生日 | en・zh-Hans・zh-Hant・ko | 誕生日 | ○ |  |
|  |  | fr | 誕生日（略） | △ |  |
|  |  | de | お祝いの会 | △ |  |
|  |  | es | 誕生日（くだけた略） | △ |  |
|  |  | it・pt-BR | お祝い（パーティー） | △ |  |
| `demo.event.businessTrip` | 出張（大阪） | en・ko・fr・de・es・it・pt-BR | 大阪 | △ |  |
|  |  | zh-Hans・zh-Hant | 大阪出張 | △ |  |
| `demo.event.call` | 電話 | 全部 | 電話 | ○ |  |
| `demo.event.camping` | キャンプ | en・zh-Hans・zh-Hant・ko・fr | キャンプ | ○ |  |
|  |  | de | キャンプ（テント泊） | △ |  |
|  |  | es・it・pt-BR | テント | △ |  |
| `demo.event.checkup` | 健康診断 | en | 検査（試験とも読める） | △ |  |
|  |  | zh-Hans・zh-Hant・ko | 健康診断 | ○ |  |
|  |  | fr | 健康診断（検査の結果の確認） | △ |  |
|  |  | de | チェック（検査） | △ |  |
|  |  | es | 検診（チェック） | △ |  |
|  |  | it | 診察 | △ |  |
|  |  | pt-BR | 検査 | △ |  |
| `demo.event.clinic` | 通院 | en・fr・es・it・pt-BR | クリニック | △ |  |
|  |  | zh-Hans | 通院 | ○ |  |
|  |  | zh-Hant | 診察 | △ |  |
|  |  | ko | 病院 | △ |  |
|  |  | de | 医者 | △ |  |
| `demo.event.deadline` | 締切 | en・ko | 締め切り | △ |  |
|  |  | zh-Hans・zh-Hant | 締め切りの日 | △ |  |
|  |  | fr | 締め切り（期限） | △ |  |
|  |  | de・es・pt-BR | 期限 | △ |  |
|  |  | it | 期限（scadenza の略） | △ |  |
| `demo.event.dentalCheck` | 歯科 | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 歯科 | ○ |  |
|  |  | de | 歯のチェック（Zahncheck。歯の検診のくだけた言い方） | △（2 回目） |  |
| `demo.event.dentist` | 歯医者 | en・fr・de・es・it・pt-BR | 歯医者 | ○ |  |
|  |  | zh-Hans・zh-Hant | 歯医者にかかる | △ |  |
|  |  | ko | 歯科の診療 | △ |  |
| `demo.event.drinks` | 飲み会 | en | 飲み会 | ○ |  |
|  |  | zh-Hans・zh-Hant | 会食 | △ |  |
|  |  | ko | 会食（職場の飲み会） | △ |  |
|  |  | fr | アペロ（軽い飲み会） | △ |  |
|  |  | de | 仕事の後の飲み会 | △ |  |
|  |  | es | 乾杯（飲み会） | △ |  |
|  |  | it | アペリティーヴォ（軽い飲み会） | △ |  |
|  |  | pt-BR | 生ビール（飲みに行く予定） | △ |  |
| `demo.event.familyTrip` | 家族旅行 | en・fr・es・it・pt-BR | 旅行 | △ |  |
|  |  | zh-Hans・zh-Hant・ko | 家族旅行 | ○ |  |
|  |  | de | 休暇の旅行 | △ |  |
| `demo.event.farewell` | 送別会 | en・zh-Hans・zh-Hant・ko | 送別会 | ○ |  |
|  |  | fr | 出発（送別の意味にも読める） | △ |  |
|  |  | de | 別れ（送別） | △ |  |
|  |  | es・pt-BR | 送別 | △ |  |
|  |  | it | 別れ（Addio。「さようなら」の意の語で、長い別れ・最後の別れの響きがある。「会」や「集まり」にあたる語は入っていない） | △（2 回目） |  |
| `demo.event.lunch` | ランチ | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 昼食 | △ |  |
|  |  | de | 昼 | △ |  |
| `demo.event.meeting` | 打合せ | 全部 | 会議 | △ |  |
| `demo.event.morningMeeting` | 朝会 | en | 朝礼（立ったまま短くする打ち合わせ） | △ |  |
|  |  | zh-Hans・zh-Hant | 朝礼 | △ |  |
|  |  | ko | 朝の会議 | △ |  |
|  |  | fr | 朝の打ち合わせ | △ |  |
|  |  | de | デイリー（Daily。毎日の短い打ち合わせを指す英語の借用語。「朝」にあたる語は入っていない） | △（2 回目） |  |
|  |  | es・pt-BR | 朝の（会） | △ |  |
|  |  | it | 会議 | △ |  |
| `demo.event.oneOnOne` | 面談 | en | 1 対 1 の面談 | △ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・it | 面談 | ○ |  |
|  |  | es | 面談（面接） | △ |  |
|  |  | pt-BR | 話（面談） | △ |  |
| `demo.event.payday` | 給料日 | en・zh-Hans・zh-Hant・ko・de | 給料日 | ○ |  |
|  |  | fr・it・pt-BR | 給料 | △ |  |
|  |  | es | 給与（Nómina。給与・給与明細の意。「日」にあたる語は入っていない） | △（2 回目） |  |
| `demo.event.report` | 資料提出 | en | 報告 | △ |  |
|  |  | zh-Hans・zh-Hant | 資料を提出 | △ |  |
|  |  | ko | 資料の提出 | △ |  |
|  |  | fr・de・es・pt-BR | 報告書 | △ |  |
|  |  | it | 報告書（Report） | △ |  |
| `demo.event.reportDeadline` | 資料提出締切 | en | 報告 | △ |  |
|  |  | zh-Hans・zh-Hant | 資料の締め切り | △ |  |
|  |  | ko | 提出の締め切り | △ |  |
|  |  | fr・de・es | 報告書 | △ |  |
|  |  | it | 報告書（Report） | △ |  |
|  |  | pt-BR | 提出 | △ |  |
| `demo.event.review` | レビュー | en・ko・fr・de | レビュー | ○ |  |
|  |  | zh-Hans | レビュー（審査） | △ |  |
|  |  | zh-Hant | 審査 | △ |  |
|  |  | es | レビュー（点検） | △ |  |
|  |  | it・pt-BR | レビュー（見直し） | △ |  |
| `demo.event.sportsDay` | 運動会 | en | スポーツ（運動） | △ |  |
|  |  | zh-Hans・zh-Hant・ko | 運動会 | ○ |  |
|  |  | fr・de・es・it・pt-BR | スポーツ | △ |  |
| `demo.event.trashDay` | ゴミの日 | en・fr・de・es・it・pt-BR | ごみ | △ |  |
|  |  | zh-Hans・zh-Hant | ごみ出しの日 | △ |  |
|  |  | ko | ごみの日 | △ |  |
| `demo.event.weeklyMeeting` | 週次定例 | en・es・pt-BR | 週次 | △ |  |
|  |  | zh-Hans | 週例会議 | △ |  |
|  |  | zh-Hant | 週例会 | △ |  |
|  |  | ko | 週次の会議 | △ |  |
|  |  | fr | 週次（略） | △ |  |
|  |  | de | 定例の打ち合わせ | △ |  |
|  |  | it | 会合 | △ |  |
| `demo.source` | 見本 | en・zh-Hans・zh-Hant・ko・es | サンプル | ○ |  |
|  |  | fr・de・it・pt-BR | 例（サンプル） | ○ |  |
| `event.allDay` | 終日 | en・zh-Hans・zh-Hant・de・es・it・pt-BR | 終日 | ○ |  |
|  |  | ko | 一日中（終日） | ○ |  |
|  |  | fr | 終日（まる一日） | ○ |  |
| `event.calendar` | カレンダー | 全部 | カレンダー | ○ |  |
| `event.calendarReadOnlyNote` | このカレンダーは変更できません（読み取り専用） | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | このカレンダーは変更できません（読み取り専用） | ○ |  |
|  |  | de | このカレンダーは変更できません（書き込み禁止） | ○ |  |
| `event.cancel` | キャンセル | 全部 | キャンセル | ○ |  |
| `event.close` | 閉じる | 全部 | 閉じる | ○ |  |
| `event.delete` | 削除 | en・zh-Hans・zh-Hant・ko・fr・de・es・it | 削除 | ○ |  |
|  |  | pt-BR | 消す（削除） | ○ |  |
| `event.deleteConfirm` | この予定を削除しますか？ | en・zh-Hans・zh-Hant・ko・fr・de・es・it | この予定を削除しますか？ | ○ |  |
|  |  | pt-BR | この予定を消しますか？ | ○ |  |
| `event.end` | 終了 | 全部 | 終了 | ○ |  |
| `event.endDay` | 終了日 | 全部 | 終了日 | ○ |  |
| `event.eraseInk` | この手書きを消す | en・ko・fr・de・es・it・pt-BR | この手書きを消す | ○ |  |
|  |  | zh-Hans・zh-Hant | この手書きの部分を消す | ○ |  |
| `event.error.calendarNotFound` | 登録先のカレンダーが見つかりません | en | この予定のカレンダーが見つかりません | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・es | 追加先のカレンダーが見つかりません | ○ |  |
|  |  | ko | 予定を入れるカレンダーが見つかりません | ○ |  |
|  |  | de・it・pt-BR | 追加先のカレンダーが見つかりませんでした | ○ |  |
| `event.error.emptyTitle` | タイトルを入力してください | en・zh-Hans・zh-Hant・ko・fr・de・it・pt-BR | 題名を入力してください | ○ |  |
|  |  | es | 題名を書いてください | ○ |  |
| `event.error.endBeforeStart` | 終了は開始より後にしてください | en・ko・fr・de・es・it・pt-BR | 終了は開始より後にしてください | ○ |  |
|  |  | zh-Hans・zh-Hant | 終了時刻は開始時刻より後にしてください | ○ |  |
| `event.error.endDayBeforeStart` | 終了日は開始日以降にしてください | en・ko | 終了日は開始日以降にしてください | ○ |  |
|  |  | zh-Hans・zh-Hant・de・it・pt-BR | 終了日は開始日より前にできません | ○ |  |
|  |  | fr・es | 終了日は開始日と同じか後にしてください | ○ |  |
| `event.error.eventNotFound` | 予定が見つかりません（別の端末で削除されたかもしれません） | en・zh-Hans・zh-Hant・ko・fr・de | 予定が見つかりません（別の端末で削除された可能性があります） | ○ |  |
|  |  | es・it | 予定が見つかりません（別の端末で削除されたかもしれません） | ○ |  |
|  |  | pt-BR | 予定が見つかりません（別の端末で消されたのかもしれません） | ○ |  |
| `event.error.failed` | 保存できませんでした: %@ | en・ko・es・pt-BR | 保存できませんでした: %@ | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・de・it | 保存できません: %@ | ○ |  |
| `event.error.noAccess` | カレンダーへのアクセスが許可されていません | en・zh-Hans・ko・fr・de・es・it・pt-BR | カレンダーへのアクセスが許可されていません | ○ |  |
|  |  | zh-Hant | カレンダーの利用が許可されていません | ○ |  |
| `event.error.noWritableCalendar` | 予定を登録できるカレンダーがありません | en・de | 新しい予定を入れられるカレンダーがありません | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 予定を追加できるカレンダーがありません | ○ |  |
|  |  | fr | 予定を受け入れられるカレンダーがありません | ○ |  |
|  |  | es・pt-BR | 新しい予定を受け付けるカレンダーがありません | ○ |  |
|  |  | it | 新しい予定を受け取れるカレンダーがありません | ○ |  |
| `event.error.readOnlyCalendar` | このカレンダーは変更できません | 全部 | このカレンダーは変更できません | ○ |  |
| `event.location` | 場所 | 全部 | 場所 | ○ |  |
| `event.notes` | メモ | 全部 | メモ | ○ |  |
| `event.recurringNote` | 繰り返しの予定です。保存・削除のときに「この回だけ」か「以降すべて」を選びます | en | これは繰り返しの予定です。保存や削除のときに「この予定だけ」か「これ以降の予定」を選びます | ○ |  |
|  |  | zh-Hans | これは繰り返しの予定です。保存または削除のときに「今回だけ」か「今回と以後」を選んでください | ○ |  |
|  |  | zh-Hant | これは繰り返しの予定です。保存または削除のときに「今回だけ」か「今回とこの後」を選んでください | ○ |  |
|  |  | ko | 繰り返しの予定です。保存や削除のときに「今回だけ」か「以後すべて」を選びます | ○ |  |
|  |  | fr | 繰り返しの予定です。保存や削除のときは「これだけ」か「これと以降」を選んでください | ○ |  |
|  |  | de | これは繰り返しの予定です。保存や削除のときに「この予定だけ」か「この予定とそれ以降すべて」を選びます | ○ |  |
|  |  | es | 繰り返す予定です。保存や削除のときに「この予定だけ」か「これと以降」を選んでください | ○ |  |
|  |  | it・pt-BR | 繰り返しの予定です。保存や削除のときに「この予定だけ」か「これと以降」を選んでください | ○ |  |
| `event.save` | 保存 | 全部 | 保存 | ○ |  |
| `event.saveFailed` | 保存できませんでした | en・ko・es・pt-BR | 保存できませんでした | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・de・it | 保存できません | ○ |  |
| `event.saving` | 保存中… | 全部 | 保存しています… | ○ |  |
| `event.scribbleNote` | Apple Pencil で欄の上に書くと、文字に変換されます（スクリブル） | en | 欄の上に Apple Pencil で書くと文字になります（スクリブル） | ○ |  |
|  |  | zh-Hans | Apple Pencil で欄の中に書くと、文字に変換できます（スクリブル） | ○ |  |
|  |  | zh-Hant | Apple Pencil で欄の上に書くと、文字に変換できます（スクリブル） | ○ |  |
|  |  | ko | Apple Pencil で欄の上に書くと文字に変換されます（手書き入力） | △ |  |
|  |  | fr・de | Apple Pencil で欄の上に書くと文字になります（スクリブル） | ○ |  |
|  |  | es・it | Apple Pencil で欄の上に書くと文字になります（手書き入力） | △ |  |
|  |  | pt-BR | テキストに変換するには、Apple Pencil で欄の上に書いてください（手で書く） | △ |  |
| `event.snapshotCaption` | 書いた内容 | en・fr・es・it・pt-BR | 書いたもの | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 書いた内容 | ○ |  |
|  |  | de | あなたの手書き | ○ |  |
| `event.start` | 開始 | 全部 | 開始 | ○ |  |
| `event.startDay` | 開始日 | 全部 | 開始日 | ○ |  |
| `event.subscribe` | 購読する | en・fr・de・es・it・pt-BR | 購読する | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 購読 | ○ |  |
| `event.subscriptionNote` | 予定の作成・編集は購読すると使えます。 | en・fr・es・it・pt-BR | 予定を作成・編集するには購読してください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 購読すると、予定の作成と編集ができます。 | ○ |  |
|  |  | ko・de | 購読すると予定を作成・編集できます。 | ○ |  |
| `event.title.create` | 予定を追加 | 全部 | 予定を追加 | ○ |  |
| `event.title.detail` | 予定の詳細 | en・zh-Hans・fr・de・es・it・pt-BR | 予定の詳細 | ○ |  |
|  |  | zh-Hant・ko | 予定の詳細情報 | ○ |  |
| `event.title.edit` | 予定を編集 | 全部 | 予定を編集 | ○ |  |
| `event.titleHeader` | タイトル | 全部 | 題名 | ○ |  |
| `event.titlePlaceholder` | ここにペンで書くと文字になります | en・ko・fr・de・es・it | ここにペンで書くと文字になります | ○ |  |
|  |  | zh-Hans・zh-Hant | ここにペンで書くと文字に変わります | ○ |  |
|  |  | pt-BR | テキストに変換するには、ここにペンで書いてください | ○ |  |
| `event.untitled` | （無題） | 全部 | （題名なし） | ○ |  |
| `event.when.dateTime` | %1$@ %2$@ | en・zh-Hans・zh-Hant・ko・fr | %1$@ %2$@ | ○ |  |
|  |  | de・es・it・pt-BR | %1$@, %2$@ | ○ |  |
| `export.close` | 閉じる | 全部 | 閉じる | ○ |  |
| `export.done.json.one` | %1$@（%2$@ ページ・%3$@） | 全部 | %1$@（%2$@ ページ · %3$@） | ○ |  |
| `export.done.json.other` | %1$@（%2$@ ページ・%3$@） | 全部 | %1$@（%2$@ ページ · %3$@） | ○ |  |
| `export.done.pdf` | %1$@（%2$@） | en・fr・de・es・it・pt-BR | %1$@ (%2$@) | ○ |  |
|  |  | zh-Hans・zh-Hant | %1$@（%2$@） | ○ |  |
|  |  | ko | %1$@(%2$@) | ○ |  |
| `export.done.title` | 書き出しました | en・zh-Hans・zh-Hant・ko・de・es・pt-BR | 書き出しました | ○ |  |
|  |  | fr・it | 書き出しが終わりました | ○ |  |
| `export.error.closed` | ファイルは閉じられています | en | ファイルが閉じられています | ○ |  |
|  |  | zh-Hans・zh-Hant | ファイルは閉じられています | ○ |  |
|  |  | ko | ファイルが閉じています | ○ |  |
|  |  | fr・de・es・it・pt-BR | ファイルは閉じています | ○ |  |
| `export.error.createFailed` | ファイルを作成できません: %@ | en・zh-Hans・fr・de・es・it・pt-BR | ファイルを作成できません: %@ | ○ |  |
|  |  | zh-Hant・ko | ファイルを作れません: %@ | ○ |  |
| `export.failed` | 書き出せませんでした: %@ | en・ko・es・pt-BR | 書き出せませんでした: %@ | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・de・it | 書き出せません: %@ | ○ |  |
| `export.json.note` | この端末に保存されている手書きをすべて 1 つのファイルにまとめます。設定 › データ › 「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。 | en | この端末に保存されているすべての手書きが 1 つのファイルに入ります。設定 > データ > 「Web 版から取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | △ |  |
|  |  | zh-Hans・zh-Hant | この端末に保存されたすべての手書きの内容を 1 つのファイルにまとめます。「設定」>「データ」>「Web 版の手書きの内容を取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | ○ |  |
|  |  | ko | この端末に保存された手書きをすべて 1 つのファイルに集めます。設定 > データ > 「Web 版の手書きを取り込む」でもう一度取り込めます（取り込みは購読中に使えます）。 | ○ |  |
|  |  | fr・de・it・pt-BR | この端末に保存されたすべての手書きを 1 つのファイルにまとめます。設定 > データ > 「Web 版から取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | △ |  |
|  |  | es | この端末に保存されたすべての手書きを 1 つのファイルに集めます。設定 > データ > 「Web 版から取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | △ |  |
| `export.json.title` | データファイル（JSON、すべてのページ） | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | データファイル（JSON、全ページ） | ○ |  |
|  |  | ko | データファイル（JSON、すべてのページ） | ○ |  |
| `export.nothing` | 書き出す手書きがありません | en・ko・fr・de・es・it・pt-BR | 書き出す手書きがありません | ○ |  |
|  |  | zh-Hans・zh-Hant | 書き出せる手書きの内容がありません | ○ |  |
| `export.pdf.building` | PDF を作っています… | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | PDF を作っています… | ○ |  |
|  |  | de | PDF を作成しています… | ○ |  |
| `export.pdf.note` | いま開いているページ（%1$@・%2$@）を 1 枚の PDF にします。紙・予定・祝日・手書きが画面のとおりに入ります。 | en | 開いているページ（%1$@ · %2$@）の 1 ページの PDF を作ります。紙・予定・祝日・手書きは画面と同じように入ります。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 今開いているページ（%1$@ · %2$@）を 1 ページの PDF にします。紙・予定・祝日・手書きの内容は画面のとおりに出ます。 | ○ |  |
|  |  | ko | 今開いているページ（%1$@ · %2$@）を PDF 1 枚にします。紙・予定・祝日・手書きが画面のとおりに入ります。 | ○ |  |
|  |  | fr・de | 開いているページ（%1$@ · %2$@）から 1 ページの PDF を作ります。紙・予定・祝日・手書きは画面と同じように出ます。 | ○ |  |
|  |  | es・it・pt-BR | 開いているページ（%1$@ · %2$@）で 1 枚の PDF を作ります。紙・予定・祝日・手書きは画面と同じように出ます。 | ○ |  |
| `export.pdf.title` | このページを PDF | en・ko・de | このページを PDF に | ○ |  |
|  |  | zh-Hans・zh-Hant | このページの PDF | ○ |  |
|  |  | fr・es・it・pt-BR | このページを PDF で | ○ |  |
| `export.progress.one` | 書き出しています… %1$@ / %2$@ ページ | en | 書き出しています… %2$@ ページ中 %1$@ ページ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de | 書き出しています… %1$@ / %2$@ ページ | ○ |  |
|  |  | es・it・pt-BR | 書き出しています… %2$@ ページ中 %1$@ | ○ |  |
| `export.progress.other` | 書き出しています… %1$@ / %2$@ ページ | en | 書き出しています… %2$@ ページ中 %1$@ ページ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de | 書き出しています… %1$@ / %2$@ ページ | ○ |  |
|  |  | es・it・pt-BR | 書き出しています… %2$@ ページ中 %1$@ | ○ |  |
| `export.renderFailed` | PDF を作れませんでした | en・ko | PDF を作れませんでした | ○ |  |
|  |  | zh-Hans・zh-Hant・fr | PDF を作れません | ○ |  |
|  |  | de・es・pt-BR | PDF を作成できませんでした | ○ |  |
|  |  | it | PDF を作成できません | ○ |  |
| `export.share` | 共有… | 全部 | 共有… | ○ |  |
| `export.title` | 手書きを書き出す | en・ko・fr・de・es・it・pt-BR | 手書きを書き出す | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を書き出す | ○ |  |
| `export.writeFailed` | ファイルを書けませんでした: %@ | en・ko・de・es・pt-BR | ファイルに書き込めませんでした: %@ | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・it | ファイルに書き込めません: %@ | ○ |  |
| `header.addEvent` | 予定 | 全部 | 予定 | ○ |  |
| `header.addEvent.spoken` | 予定を追加 | 全部 | 予定を追加 | ○ |  |
| `header.day.spoken` | %1$@（日表示へ） | 全部 | %1$@（日のページを開く） | ○ |  |
| `header.month.spoken` | %1$@（月表示へ） | 全部 | %1$@（月のページを開く） | ○ |  |
| `header.next.day` | 次の日 | en・ko・de・pt-BR | 次の日 | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・es・it | 翌日 | ○ |  |
| `header.next.month` | 次の月 | en・ko・de・pt-BR | 次の月 | ○ |  |
|  |  | zh-Hans・zh-Hant | 来月 | ○ |  |
|  |  | fr・es・it | 翌月 | ○ |  |
| `header.next.week` | 次の週 | en・zh-Hans・zh-Hant・ko・de・pt-BR | 次の週 | ○ |  |
|  |  | fr・es・it | 翌週 | ○ |  |
| `header.next.year` | 次の年 | en・zh-Hans・zh-Hant・ko・de・pt-BR | 次の年 | ○ |  |
|  |  | fr・es・it | 翌年 | ○ |  |
| `header.picker.day` | 日 | en・zh-Hans・zh-Hant・ko・it | 日 | ○ |  |
|  |  | fr | 日（Jour） | ○ |  |
|  |  | de | 日（Tag） | ○ |  |
|  |  | es | 日（Día） | ○ |  |
|  |  | pt-BR | 日（Dia） | ○ |  |
| `header.picker.month` | 月 | 全部 | 月 | ○ |  |
| `header.picker.spoken` | 表示の切替 | en・es・it・pt-BR | 表示を変える | ○ |  |
|  |  | zh-Hans・zh-Hant・de | 表示を切り替える | ○ |  |
|  |  | ko | 表示の切り替え | ○ |  |
|  |  | fr | 表示の形を変える | ○ |  |
| `header.picker.week` | 週 | en・zh-Hans・zh-Hant・ko・de | 週 | ○ |  |
|  |  | fr・es・it・pt-BR | 週（略） | △ |  |
| `header.picker.year` | 年 | 全部 | 年 | ○ |  |
| `header.pickerItem.day` | 日表示 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 日の表示 | ○ |  |
|  |  | fr | 日ごとの表示 | ○ |  |
| `header.pickerItem.month` | 月表示 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 月の表示 | ○ |  |
|  |  | fr | 月ごとの表示 | ○ |  |
| `header.pickerItem.week` | 週表示 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 週の表示 | ○ |  |
|  |  | fr | 週ごとの表示 | ○ |  |
| `header.pickerItem.year` | 年表示 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 年の表示 | ○ |  |
|  |  | fr | 年ごとの表示 | ○ |  |
| `header.previous.day` | 前の日 | en・ko・de・pt-BR | 前の日 | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・es・it | 前日 | ○ |  |
| `header.previous.month` | 前の月 | en・ko・de・pt-BR | 前の月 | ○ |  |
|  |  | zh-Hans・zh-Hant | 先月 | ○ |  |
|  |  | fr・es・it | 前月 | ○ |  |
| `header.previous.week` | 前の週 | en・zh-Hans・zh-Hant・ko・de・pt-BR | 前の週 | ○ |  |
|  |  | fr・es・it | 前週 | ○ |  |
| `header.previous.year` | 前の年 | en・zh-Hans・zh-Hant・ko・de・pt-BR | 前の年 | ○ |  |
|  |  | fr・es・it | 前年 | ○ |  |
| `header.readOnly.spoken` | 閲覧専用。購読の案内を開く | en | 閲覧のみ。購読の案内を開く | ○ |  |
|  |  | zh-Hans・zh-Hant | 閲覧のみ。購読の説明を開く | ○ |  |
|  |  | ko | 閲覧専用。購読の案内を開く | ○ |  |
|  |  | fr・es・it・pt-BR | 読み取り専用。購読の情報を開く | ○ |  |
|  |  | de | 見るだけ。購読の情報を開く | ○ |  |
| `header.settings.spoken` | 設定 | 全部 | 設定 | ○ |  |
| `header.sync.spoken` | 同期: %@ | 全部 | 同期: %@ | ○ |  |
| `header.today` | 今日 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 今日 | ○ |  |
|  |  | fr | 今日（略） | △ |  |
| `holidayPicker.auto` | 自動（この端末の地域：%@） | 全部 | 自動（この端末の地域: %@） | ○ |  |
| `holidayPicker.countries` | 国・地域 | en・fr・de・es・it・pt-BR | 国と地域 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 国または地域 | ○ |  |
| `holidayPicker.deviceRegion` | この端末の地域：%@ | 全部 | この端末の地域: %@ | ○ |  |
| `holidayPicker.localAreas` | その他の地域（市など） | en | そのほかの地域（市など） | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | その他の地域（都市など） | ○ |  |
|  |  | fr・de・es・it・pt-BR | そのほかの区域（市など） | ○ |  |
| `holidayPicker.none` | なし | 全部 | なし | ○ |  |
| `holidayPicker.search` | 国・地域を検索 | en | 国と地域を検索 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 国または地域を検索 | ○ |  |
|  |  | fr・de・es・it・pt-BR | 国や地域を検索 | ○ |  |
| `holidayPicker.subdivisionHint` | 州・地域を選ぶと、その地域の祝日が加わります | en・fr・es・it | 州や地域を選ぶと、その祝日が加わります | ○ |  |
|  |  | zh-Hans・zh-Hant | 州または地域を選ぶと、その地域の祝日が加わります | ○ |  |
|  |  | ko | 州や地域を選ぶと、その地域の祝日が加わります | ○ |  |
|  |  | de | その地域の祝日を追加するには、地域を選択してください | △ |  |
|  |  | pt-BR | 州や地域を選ぶと、そこの祝日が加わります | ○ |  |
| `holidayPicker.subdivisions` | 州・地域 | en・fr・es・it・pt-BR | 州と地域 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 州または地域 | ○ |  |
|  |  | de | 地域 | △ |  |
| `holidayPicker.subdivisions.footer` | 州・地域の名前は、データのままの表記（英語や現地の言葉）です。 | en | 州と地域の名前は、データのまま（英語か現地の言語で）表示されます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 州または地域の名前はデータのまま（英語または現地の言語で）表示されます。 | ○ |  |
|  |  | ko | 州と地域の名前は、データにあるまま（英語または現地の言語で）表示します。 | ○ |  |
|  |  | fr | 州と地域の名前は、データのまま（英語または現地の言語で）表示されます。 | ○ |  |
|  |  | de | 地域の名前は、データに載っているとおりに表示されます（英語またはその国の言語で）。 | △ |  |
|  |  | es・it・pt-BR | 州と地域の名前は、データにあるまま（英語か現地の言語で）表示されます。 | ○ |  |
| `holidayPicker.title` | 表示する祝日 | 全部 | 表示する祝日 | ○ |  |
| `holidayPicker.wholeCountry` | 国全体 | en・ko・fr・de・es・it・pt-BR | 国全体 | ○ |  |
|  |  | zh-Hans・zh-Hant | 全国 | ○ |  |
| `import.close` | 閉じる | 全部 | 閉じる | ○ |  |
| `import.confirmLarge.cancel` | やめる | 全部 | キャンセル | ○ |  |
| `import.confirmLarge.import` | 取り込む | 全部 | 取り込む | ○ |  |
| `import.confirmLarge.more.one` | ほか %@ ページ | en・ko・fr・de・es・it・pt-BR | ほか %@ ページ | ○ |  |
|  |  | zh-Hans・zh-Hant | ほかに %@ ページ | ○ |  |
| `import.confirmLarge.more.other` | ほか %@ ページ | en・ko・fr・de・es・it・pt-BR | ほか %@ ページ | ○ |  |
|  |  | zh-Hans・zh-Hant | ほかに %@ ページ | ○ |  |
| `import.confirmLarge.separator` | 、 | en・ko・fr・de・es・it・pt-BR | , | ○ |  |
|  |  | zh-Hans・zh-Hant | 、 | ○ |  |
| `import.confirmLarge.text` | 取り込むと、線が %1$@ 本を超えるページがあります（%2$@）。この版では全部表示されますが、古い版の端末ではその一部が表示されません。取り込みますか？ | en | 取り込むと、%1$@ 本より多くの線があるページができます（%2$@）。この版ではすべて表示されますが、古い版の端末では一部が表示されません。それでも取り込みますか？ | ○ |  |
|  |  | zh-Hans | 取り込むと、線が %1$@ 本を超えるページができます（%2$@）。この版ではすべて表示されますが、古い版の入った端末では一部が表示されません。取り込みますか？ | ○ |  |
|  |  | zh-Hant | 取り込むと、線が %1$@ 本を超えるページができます（%2$@）。この版ではすべて表示されますが、古い版を入れた端末では一部が表示されません。取り込みますか？ | ○ |  |
|  |  | ko | 取り込むと、線が %1$@ 本を超えるページができます（%2$@）。この版ではすべて表示されますが、以前の版の端末では一部が表示されません。取り込みますか？ | ○ |  |
|  |  | fr | 取り込むと、%1$@ 本を超える線のあるページができます（%2$@）。この版ではすべて表示されますが、古い版の端末では一部しか表示されません。取り込みますか？ | ○ |  |
|  |  | de・es・it・pt-BR | 取り込むと、一部のページの線が %1$@ 本を超えます（%2$@）。この版ではすべて表示されますが、古い版の端末では一部しか表示されません。取り込みますか？ | ○ |  |
| `import.confirmLarge.title` | 線がとても多いページがあります | en・ko・fr・de | 線がとても多いページがあります | ○ |  |
|  |  | zh-Hans・zh-Hant・es・it・pt-BR | 線が非常に多いページがあります | ○ |  |
| `import.invalidJSON` | ファイルを読めませんでした | en・ko・de・es・pt-BR | ファイルを読み取れませんでした | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・it | ファイルを読み取れません | ○ |  |
| `import.notAnExport` | このファイルは手書きの書き出し（Web 版またはこのアプリ）ではありません | en | このファイルは（Web 版やこのアプリから）書き出した手書きのファイルではありません | ○ |  |
|  |  | zh-Hans・zh-Hant | このファイルは（Web 版またはこのアプリからの）手書きの内容の書き出しファイルではありません | ○ |  |
|  |  | ko | このファイルは手書きの書き出しファイル（Web 版またはこのアプリ）ではありません | ○ |  |
|  |  | fr・es・pt-BR | このファイルは（Web 版やこのアプリの）手書きの書き出しではありません | ○ |  |
|  |  | de・it | このファイルは（Web 版やこのアプリからの）手書きの書き出しではありません | ○ |  |
| `import.nothing` | 取り込むものはありませんでした（すべて取り込み済みです） | en・fr・de・es・it・pt-BR | 取り込むものがありません（すべて取り込み済みです） | ○ |  |
|  |  | zh-Hans・zh-Hant | 取り込める内容がありません（すべて取り込み済みです） | ○ |  |
|  |  | ko | 取り込むものがありません（すべて取り込みました） | ○ |  |
| `import.otherWeekStart.monday` | 取り込んだ週のページの一部は、週の始まりを月曜にすると見えます。 | en | 取り込んだ週のページの一部は、週を月曜始まりにすると表示されます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 取り込んだ週のページのうち一部は、週の最初の日を月曜にすると見られます。 | ○ |  |
|  |  | ko | 取り込んだ週のページの一部は、週の最初の日を月曜にすると見えます。 | ○ |  |
|  |  | fr・de・pt-BR | 取り込んだ週のページの一部は、週が月曜に始まるときに現れます。 | ○ |  |
|  |  | es・it | 取り込んだ週のページの一部は、週が月曜に始まるときに見えます。 | ○ |  |
| `import.otherWeekStart.sunday` | 取り込んだ週のページの一部は、週の始まりを日曜にすると見えます。 | en | 取り込んだ週のページの一部は、週を日曜始まりにすると表示されます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 取り込んだ週のページのうち一部は、週の最初の日を日曜にすると見られます。 | ○ |  |
|  |  | ko | 取り込んだ週のページの一部は、週の最初の日を日曜にすると見えます。 | ○ |  |
|  |  | fr・de・pt-BR | 取り込んだ週のページの一部は、週が日曜に始まるときに現れます。 | ○ |  |
|  |  | es・it | 取り込んだ週のページの一部は、週が日曜に始まるときに見えます。 | ○ |  |
| `import.progress.one` | 取り込んでいます… %1$@ / %2$@ ページ | en | 取り込んでいます… %2$@ ページ中 %1$@ ページ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de | 取り込んでいます… %1$@ / %2$@ ページ | ○ |  |
|  |  | es・it・pt-BR | 取り込んでいます… %2$@ ページ中 %1$@ | ○ |  |
| `import.progress.other` | 取り込んでいます… %1$@ / %2$@ ページ | en | 取り込んでいます… %2$@ ページ中 %1$@ ページ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de | 取り込んでいます… %1$@ / %2$@ ページ | ○ |  |
|  |  | es・it・pt-BR | 取り込んでいます… %2$@ ページ中 %1$@ | ○ |  |
| `import.progress.reading` | 取り込んでいます… | 全部 | 取り込んでいます… | ○ |  |
| `import.result.app` | 手書きを取り込みました（%1$@・%2$@） | en・ko・fr・de・es・it・pt-BR | 手書きを取り込みました（%1$@ · %2$@） | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を取り込みました（%1$@ · %2$@） | ○ |  |
| `import.result.pages.one` | %@ ページ | 全部 | %@ ページ | ○ |  |
| `import.result.pages.other` | %@ ページ | 全部 | %@ ページ | ○ |  |
| `import.result.strokes.one` | %@ 本 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 本の線 | ○ |  |
|  |  | ko | 線 %@ 本 | ○ |  |
| `import.result.strokes.other` | %@ 本 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 本の線 | ○ |  |
|  |  | ko | 線 %@ 本 | ○ |  |
| `import.result.web` | Web 版の手書きを取り込みました（%1$@・%2$@） | en・ko・fr・de・es・it・pt-BR | Web 版の手書きを取り込みました（%1$@ · %2$@） | ○ |  |
|  |  | zh-Hans・zh-Hant | Web 版の手書きの内容を取り込みました（%1$@ · %2$@） | ○ |  |
| `import.saveFailed` | 保存できませんでした: %@ | en・ko・es・pt-BR | 保存できませんでした: %@ | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・de・it | 保存できません: %@ | ○ |  |
| `import.skipped.one` | %@ ページは対象外のため飛ばしました | en | %@ ページは取り込めないため飛ばしました | ○ |  |
|  |  | zh-Hans・zh-Hant | %@ ページを飛ばしました（取り込みの対象外） | ○ |  |
|  |  | ko | %@ ページは対象ではないので飛ばしました | ○ |  |
|  |  | fr・de・it・pt-BR | %@ ページは取り込めないので飛ばしました | ○ |  |
|  |  | es | 取り込めないので %@ ページを省きました | ○ |  |
| `import.skipped.other` | %@ ページは対象外のため飛ばしました | en | %@ ページは取り込めないため飛ばしました | ○ |  |
|  |  | zh-Hans・zh-Hant | %@ ページを飛ばしました（取り込みの対象外） | ○ |  |
|  |  | ko | %@ ページは対象ではないので飛ばしました | ○ |  |
|  |  | fr・de・it・pt-BR | %@ ページは取り込めないので飛ばしました | ○ |  |
|  |  | es | 取り込めないので %@ ページを省きました | ○ |  |
| `import.title` | Web 版の手書きを取り込む | en・fr・de・es・it・pt-BR | Web 版から取り込む | △ |  |
|  |  | zh-Hans・zh-Hant | Web 版の手書きの内容を取り込む | ○ |  |
|  |  | ko | Web 版の手書きを取り込む | ○ |  |
| `import.unsupportedVersion` | このファイルは新しい形式です（v%@）。アプリを更新してください | en | このファイルは新しい形式（v%@）です。アプリを更新してください | ○ |  |
|  |  | zh-Hans・zh-Hant・fr | このファイルは新しい形式（v%@）を使っています。アプリを更新してください | ○ |  |
|  |  | ko | このファイルは新しい形式です（v%@）。アプリをアップデートしてください | ○ |  |
|  |  | de | このファイルは新しい形式（v%@）です。アプリをアップデートしてください | ○ |  |
|  |  | es・it・pt-BR | このファイルは新しい形式（v%@）を使っています。アプリをアップデートしてください | ○ |  |
| `info.translationNote` | このアプリの訳は AI で作り、日本語に訳し戻して確かめました。まだネイティブの確認は受けていません。誤りを見つけたら syfan0@gmail.com までお知らせください。 | en・fr・es・it・pt-BR | このアプリの訳は AI で作り、日本語に訳し戻して確かめました。母語話者の確認はまだ受けていません。誤りを見つけたら syfan0@gmail.com までお書きください。 | ○ |  |
|  |  | zh-Hans | このアプリの訳文は AI が作り、日本語に訳し戻して照合しました。今のところ母語話者の確認は受けていません。誤りを見つけたら syfan0@gmail.com までお書きください。 | ○ |  |
|  |  | zh-Hant | このアプリの訳文は AI が作り、日本語に訳し戻して照合しています。今のところ母語話者の確認は受けていません。誤りを見つけたら syfan0@gmail.com までお便りください。 | ○ |  |
|  |  | ko | このアプリの翻訳は AI で作り、日本語に訳し戻して確かめました。まだ母語話者の確認は受けていません。誤りを見つけたら syfan0@gmail.com にお知らせください。 | ○ |  |
|  |  | de | このアプリの訳は AI で作り、日本語への逆翻訳で確かめました。母語話者の確認はまだ受けていません。誤りを見つけたら syfan0@gmail.com までお書きください。 | ○ |  |
| `kit.app.name` | てがきカレンダー | en | Tegaki（手書き。ローマ字の名前） | △ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | Tegaki（ローマ字の名前） | △ |  |
| `kit.budget.count.one` | %@ 本 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 本の線 | ○ |  |
|  |  | ko | 線 %@ 本 | ○ |  |
| `kit.budget.count.other` | %@ 本 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 本の線 | ○ |  |
|  |  | ko | 線 %@ 本 | ○ |  |
| `kit.budget.page.day` | 日のページ（%@） | 全部 | 日のページ（%@） | ○ |  |
| `kit.budget.page.month` | 月のページ（%@） | 全部 | 月のページ（%@） | ○ |  |
| `kit.budget.page.week` | 週のページ（%@） | 全部 | 週のページ（%@） | ○ |  |
| `kit.budget.page.year` | 年のページ（%@） | 全部 | 年のページ（%@） | ○ |  |
| `kit.export.jsonFileName` | てがきカレンダー 手書き %@.json | en | Tegaki の手書き %@.json | △ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | Tegaki 手書き %@.json | △ |  |
| `kit.export.kind.day` | 日 | en・zh-Hans・zh-Hant・ko・it | 日 | ○ |  |
|  |  | fr | 日（Jour） | ○ |  |
|  |  | de | 日（Tag） | ○ |  |
|  |  | es | 日（Día） | ○ |  |
|  |  | pt-BR | 日（Dia） | ○ |  |
| `kit.export.kind.month` | 月 | 全部 | 月 | ○ |  |
| `kit.export.kind.week` | 週 | 全部 | 週 | ○ |  |
| `kit.export.kind.year` | 年 | 全部 | 年 | ○ |  |
| `kit.holiday.dayOff` | 振替の休み | en | 休み | △ |  |
|  |  | zh-Hans・zh-Hant | 休日 | △ |  |
|  |  | ko・fr・de・es・it・pt-BR | 休みの日 | △ |  |
| `kit.holiday.estimatedSuffix` | （推定） | en・ko・fr・de・es・it・pt-BR |  （推定） | ○ |  |
|  |  | zh-Hans | （推算） | ○ |  |
|  |  | zh-Hant | （推定） | ○ |  |
| `kit.layout.more.one` | +%@件 | en・fr・de・es・it・pt-BR | +ほか %@ 件 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | +%@ 件 | ○ |  |
| `kit.layout.more.other` | +%@件 | en・fr・de・es・it・pt-BR | +ほか %@ 件 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | +%@ 件 | ○ |  |
| `kit.legal.appleEULATitle` | 使用許諾契約（Apple 標準 EULA） | en・pt-BR | 利用規約（Apple の標準 EULA） | △ |  |
|  |  | zh-Hans・zh-Hant | 利用条項（Apple 標準 EULA） | △ |  |
|  |  | ko | 利用規約（Apple 標準 EULA） | △ |  |
|  |  | fr・es・it | 利用条件（Apple の標準 EULA） | △ |  |
|  |  | de | 利用条件（Apple 標準 EULA） | △ |  |
| `kit.plan.badge.readOnly` | 閲覧専用 | en・zh-Hans・zh-Hant | 閲覧のみ | ○ |  |
|  |  | ko | 閲覧専用 | ○ |  |
|  |  | fr・es・it・pt-BR | 読み取り専用 | ○ |  |
|  |  | de | 見るだけ | ○ |  |
| `kit.plan.cancelPath` | 「設定」›「Apple Account」›「サブスクリプション」 | en・fr・de・it・pt-BR | 設定 > お名前 > サブスクリプション | △ |  |
|  |  | zh-Hans・zh-Hant | 「設定」> お名前 >「サブスクリプション」 | △ |  |
|  |  | ko | 設定 > ユーザーの名前 > サブスクリプション（購読） | △ |  |
|  |  | es | 設定（Ajustes／Configuración）> お名前 > サブスクリプション | △ |  |
| `kit.plan.date.expires` | 有効期限 | en・es・it | 期限 | ○ |  |
|  |  | zh-Hans・zh-Hant・de・pt-BR | 有効期限 | ○ |  |
|  |  | ko | 満了日 | ○ |  |
|  |  | fr | 期限の日 | ○ |  |
| `kit.plan.date.graceUntil` | 猶予の期限 | 全部 | 猶予期間の終わり | ○ |  |
| `kit.plan.date.renews` | 次回更新 | en・ko・fr・es・it・pt-BR | 次の更新 | ○ |  |
|  |  | zh-Hans・zh-Hant | 次回の更新 | ○ |  |
|  |  | de | 次の延長 | ○ |  |
| `kit.plan.date.trialEnds` | 試用の終了 | en | 無料トライアルの終わり | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・es・it・pt-BR | お試しの終わり | ○ |  |
|  |  | ko | 体験の終わり | ○ |  |
|  |  | de | お試し期間の終わり | ○ |  |
| `kit.plan.date.trialEndsPaid` | 試用の終了（有料に移行） | en | 無料トライアルの終わり（その後は有料） | ○ |  |
|  |  | zh-Hans・zh-Hant | お試しの終わり（その後は有料に切り替わる） | ○ |  |
|  |  | ko | 体験の終わり（その後は有料に切り替わる） | ○ |  |
|  |  | fr・es・it・pt-BR | お試しの終わり（その後は有料） | ○ |  |
|  |  | de | お試し期間の終わり（その後は有料） | ○ |  |
| `kit.plan.monthly` | 月額 | en・fr・es・it・pt-BR | 月額 | ○ |  |
|  |  | zh-Hans | 月ごと | ○ |  |
|  |  | zh-Hant | 月払い | ○ |  |
|  |  | ko | 月間 | ○ |  |
|  |  | de | 毎月 | ○ |  |
| `kit.plan.note.billingRetry` | お支払いに問題があります。%@でお支払い方法を確認してください。 | en・fr | 支払いに問題があります。%@ で支払い方法を確かめてください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | お支払いに問題があります。%@で支払い方法を確かめてください。 | ○ |  |
|  |  | ko・de・es・it・pt-BR | お支払いに問題があります。%@ で支払い方法を確かめてください。 | ○ |  |
| `kit.plan.note.expired` | サブスクリプションの期限が切れています。 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 購読の期限が切れました。 | ○ |  |
|  |  | ko | 購読が満了しました。 | ○ |  |
| `kit.plan.note.notSubscribed` | まだ購読していません。 | 全部 | まだ購読していません。 | ○ |  |
| `kit.plan.note.revoked` | 購入が返金または取り消されました。 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 購入は返金または取り消しになりました。 | ○ |  |
|  |  | ko | 購入が返金されたか、取り消されました。 | ○ |  |
| `kit.plan.note.unknown` | 購入の状態を確認できていません。回線が戻ると自動で確認します。 | en・de | 購入を確かめられませんでした。オンラインに戻ると自動で確かめます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 今は購入の状態を確かめられません。ネットワークが戻ると自動で確かめます。 | ○ |  |
|  |  | ko | 購入の状態を確かめられませんでした。インターネットにまた接続すると自動で確かめます。 | ○ |  |
|  |  | fr | 購入の状態を確かめられませんでした。接続が戻ると自動で確かめます。 | ○ |  |
|  |  | es・it・pt-BR | 購入を確かめられませんでした。接続が戻ると自動で確かめます。 | ○ |  |
| `kit.plan.paymentPath` | 「設定」›「Apple Account」›「お支払いと配送先」 | en | 設定 > お名前 > お支払いと配送先 | △ |  |
|  |  | zh-Hans・zh-Hant | 「設定」> お名前 >「お支払いと配送先」 | △ |  |
|  |  | ko | 設定 > ユーザーの名前 > お支払いと配送 | △ |  |
|  |  | fr・pt-BR | 設定 > お名前 > 支払いと配送 | △ |  |
|  |  | de・it | 設定 > お名前 > お支払いと配送 | △ |  |
|  |  | es | 設定（Ajustes／Configuración）> お名前 > 支払いと配送 | △ |  |
| `kit.plan.perPeriod.monthly` | /月 | 全部 | /月 | ○ |  |
| `kit.plan.perPeriod.yearly` | /年 | 全部 | /年 | ○ |  |
| `kit.plan.savings.one` | %@ か月分お得 | en・de | %@ か月分お得 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・it・pt-BR | %@ か月分節約 | △ |  |
|  |  | fr | %@ か月分の節約 | △ |  |
|  |  | es | %@か月節約してください | △ |  |
| `kit.plan.savings.other` | %@ か月分お得 | en・de | %@ か月分お得 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・it・pt-BR | %@ か月分節約 | △ |  |
|  |  | fr | %@ か月分の節約 | △ |  |
|  |  | es | %@か月節約してください | △ |  |
| `kit.plan.status.billingRetry` | お支払いに問題（閲覧専用） | en | 支払いの問題（閲覧のみ） | ○ |  |
|  |  | zh-Hans・zh-Hant | 支払いに問題あり（閲覧のみ） | ○ |  |
|  |  | ko | お支払いの問題（閲覧専用） | ○ |  |
|  |  | fr・es・it・pt-BR | 支払いの問題（読み取り専用） | ○ |  |
|  |  | de | 支払いの問題（見るだけ） | ○ |  |
| `kit.plan.status.expired` | 期限切れ（閲覧専用） | en・zh-Hans・zh-Hant | 期限切れ（閲覧のみ） | ○ |  |
|  |  | ko | 満了（閲覧専用） | ○ |  |
|  |  | fr・es・it・pt-BR | 期限切れ（読み取り専用） | ○ |  |
|  |  | de | 期限切れ（見るだけ） | ○ |  |
| `kit.plan.status.notSubscribed` | 未購入（閲覧専用） | en・zh-Hans・zh-Hant | 未購入（閲覧のみ） | ○ |  |
|  |  | ko | 未購入（閲覧専用） | ○ |  |
|  |  | fr・es・it・pt-BR | 未購入（読み取り専用） | ○ |  |
|  |  | de | 未購入（見るだけ） | ○ |  |
| `kit.plan.status.revoked` | 返金済み（閲覧専用） | en・zh-Hans・zh-Hant | 返金済み（閲覧のみ） | ○ |  |
|  |  | ko | 返金済み（閲覧専用） | ○ |  |
|  |  | fr・es・it・pt-BR | 返金済み（読み取り専用） | ○ |  |
|  |  | de | 返金済み（見るだけ） | ○ |  |
| `kit.plan.status.subscribed` | %@・有効 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ · 有効 | ○ |  |
|  |  | ko | %@ · 使用中 | ○ |  |
| `kit.plan.status.subscribedGrace` | %@・請求に問題（猶予中） | en・fr・de・es・it・pt-BR | %@ · 支払いの問題（猶予期間） | ○ |  |
|  |  | zh-Hans・zh-Hant | %@ · 支払いに問題あり（猶予期間中） | ○ |  |
|  |  | ko | %@ · お支払いの問題（猶予期間） | ○ |  |
| `kit.plan.status.trial` | %@・試用中 | en | %@ · 無料トライアル | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・es・it・pt-BR | %@ · お試し中 | ○ |  |
|  |  | ko | %@ · 体験中 | ○ |  |
|  |  | de | %@ · お試し期間 | ○ |  |
| `kit.plan.status.unknown` | 確認中（閲覧専用） | en | 確かめています（閲覧のみ） | ○ |  |
|  |  | zh-Hans・zh-Hant | 確認中（閲覧のみ） | ○ |  |
|  |  | ko | 確かめています（閲覧専用） | ○ |  |
|  |  | fr・es・it・pt-BR | 確かめています（読み取り専用） | ○ |  |
|  |  | de | 確かめています（見るだけ） | ○ |  |
| `kit.plan.yearly` | 年額 | en・fr・es・it・pt-BR | 年額 | ○ |  |
|  |  | zh-Hans | 年ごと | ○ |  |
|  |  | zh-Hant | 年払い | ○ |  |
|  |  | ko | 年間 | ○ |  |
|  |  | de | 毎年 | ○ |  |
| `license.contributors` | Contributors: %@ | en | 協力者: %@ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | Contributors（協力者）: %@（英語のまま） | ○ |  |
| `license.holidayData` | 祝日データ：python-holidays（MIT ライセンス） | 全部 | 祝日のデータ: python-holidays（MIT ライセンス） | ○ |  |
| `notice.calendar.denied` | 予定を表示するには設定でカレンダーを「フルアクセス」にしてください。 | en・ko・fr・de・it・pt-BR | 予定を表示するには、設定でカレンダーを「フルアクセス」にしてください。 | ○ |  |
|  |  | zh-Hans | 予定を表示するには、「設定」でカレンダーを「フルアクセス」にしてください。 | ○ |  |
|  |  | zh-Hant | 予定を表示するには、「設定」でカレンダーを「フルアクセス権限」にしてください。 | ○ |  |
|  |  | es | 予定を表示するには、設定（Ajustes／Configuración）でカレンダーを「フルアクセス」にしてください。 | △ |  |
| `notice.calendar.denied.openSettings` | 設定を開く | 全部 | 設定を開く | ○ |  |
| `notice.calendar.notDetermined` | 予定を表示するにはカレンダーの読み取りを許可してください。 | en・zh-Hans・ko・fr・de・es・it・pt-BR | 予定を表示するには、カレンダーへのアクセスを許可してください。 | △ |  |
|  |  | zh-Hant | 予定を表示するには、カレンダーの利用を許可してください。 | △ |  |
| `notice.calendar.notDetermined.allow` | 許可する | en・fr・de・es・it・pt-BR | 許可する | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 許可 | ○ |  |
| `notice.calendar.restricted` | この端末ではカレンダーへのアクセスが制限されています。手書きだけ使えます。 | en | この端末ではカレンダーへのアクセスが制限されています。手書きはこのままできます。 | △ |  |
|  |  | zh-Hans | この端末のカレンダーへのアクセスは制限されています。手書きはこのまま使えます。 | △ |  |
|  |  | zh-Hant | この端末のカレンダーの利用権限は制限されています。手書きはこのまま使えます。 | △ |  |
|  |  | ko | この端末ではカレンダーへのアクセスが制限されています。手書きは使えます。 | △ |  |
|  |  | fr・it・pt-BR | この端末ではカレンダーへのアクセスが制限されています。それでも手書きはできます。 | △ |  |
|  |  | de | この端末ではカレンダーへのアクセスが制限されています。手書きはそれでも使えます。 | △ |  |
|  |  | es | この端末ではカレンダーへのアクセスが制限されています。手書きは続けられます。 | △ |  |
| `notice.readOnly.button` | 購読する | en・fr・de・es・it・pt-BR | 購読する | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 購読 | ○ |  |
| `notice.readOnly.text` | 閲覧専用です。手書きと予定の作成は購読すると使えます。 | en | 閲覧のみです。手書きと予定の作成には購読してください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 閲覧のみ。購読すると手書きと予定の作成ができます。 | ○ |  |
|  |  | ko | 閲覧専用です。購読すると手書きと予定の作成を使えます。 | ○ |  |
|  |  | fr・es・it・pt-BR | 読み取り専用。手書きと予定の作成には購読してください。 | ○ |  |
|  |  | de | 見るだけ。手書きと予定の作成には購読してください。 | ○ |  |
| `onboarding.access.text` | 次の画面で、カレンダーへの「フルアクセス」を求めます。予定を手帳のページに表示し、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定はこの端末の中だけで扱い、開発者やほかの誰にも送りません。 | en | 次の画面で、アプリがカレンダーへの「フルアクセス」を求めます。手帳のページに予定を表示するためと、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の許可がないので、フルアクセスにする必要があります。予定はこの端末の中だけで扱われ、開発者にもほかの誰にも送られません。 | ○ |  |
|  |  | zh-Hans | 次の画面で、カレンダーの「フルアクセス」の権限を求めます。手帳のページに予定を表示するため、また手書きの内容から予定を作成するためです。<br><br>iOS と iPadOS には読み取り専用の権限がないため、「フルアクセス」が必要です。予定はこのデバイス上でのみ処理され、開発者やその他の誰にも送信されません。 | ○ |  |
|  |  | zh-Hant | 次の画面でカレンダーの「フルアクセス権限」を求めます。手帳のページに予定を表示するためと、手書きの内容から予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の権限がないので、「フルアクセス権限」が必要です。予定はこの端末の中だけで処理され、開発者にもほかの誰にも送られません。 | ○ |  |
|  |  | ko | 次の画面でカレンダーの「フルアクセス」を求めます。予定をプランナーのページに表示し、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の権限がないので、フルアクセスが必要です。予定はこの端末の中だけで扱い、開発者にもほかの誰にも送りません。 | ○ |  |
|  |  | fr | 次の画面でカレンダーへの「フルアクセス」を求めます。手帳のページに予定を表示するためと、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の許可がないので、フルアクセスにする必要があります。予定はこの端末の中だけで処理され、開発者にもほかの誰にも送られません。 | ○ |  |
|  |  | de | 次の画面でカレンダーへの「フルアクセス」を求めます。これで予定をプランナーのページに表示し、手書きから予定を作れます。<br><br>iOS と iPadOS には読み取りだけの権限がないので、フルアクセスが必要です。予定はこの端末の中だけで処理され、開発者にもほかの人にも送られません。 | ○ |  |
|  |  | es | 次の画面でカレンダーへの「フルアクセス」を求めます。手帳のページに予定を表示し、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の許可がないので、フルアクセスでなければなりません。予定はこの端末の中だけで扱われ、開発者にもほかの誰にも送られません。 | ○ |  |
|  |  | it | 次の画面でカレンダーへの「フルアクセス」を求めます。手帳のページに予定を表示するためと、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の許可がないので、フルアクセスでなければなりません。予定はこの端末の中だけで扱われ、開発者にもほかの人にも送られません。 | ○ |  |
|  |  | pt-BR | 次の画面で、アプリがカレンダーへの「フルアクセス」を求めます。手帳のページに予定を表示し、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の許可がないので、フルアクセスである必要があります。予定はこの端末の中だけで扱われ、開発者にもほかの誰にも送られません。 | ○ |  |
| `onboarding.access.title` | カレンダーへのアクセス | en・zh-Hans・ko・fr・de・es・it・pt-BR | カレンダーへのアクセス | ○ |  |
|  |  | zh-Hant | カレンダーの利用権限 | ○ |  |
| `onboarding.account.text` | このアプリは、この端末の「カレンダー」に入っている予定を表示します。<br><br>%@ | en | このアプリは、この端末のカレンダーアプリにある予定を表示します。<br><br>%@ | ○ |  |
|  |  | zh-Hans・zh-Hant | このアプリは、この端末の「カレンダー」の予定を表示します。<br><br>%@ | ○ |  |
|  |  | ko | このアプリは、この端末の「カレンダー」にある予定を表示します。<br><br>%@ | ○ |  |
|  |  | fr・es・it・pt-BR | このアプリは、この端末のカレンダーアプリの予定を表示します。<br><br>%@ | ○ |  |
|  |  | de | このアプリは、この端末の「カレンダー」アプリの予定を表示します。<br><br>%@ | ○ |  |
| `onboarding.account.title` | カレンダーのアカウント | 全部 | カレンダーのアカウント | ○ |  |
| `onboarding.askPermission` | 許可の画面を出す | en・fr・es・it・pt-BR | 許可の画面を出す | ○ |  |
|  |  | zh-Hans | 権限のリクエストを表示する | ○ |  |
|  |  | zh-Hant | 権限の画面を出す | ○ |  |
|  |  | ko | 権限の画面を表示 | ○ |  |
|  |  | de | 権限の確認を出す | ○ |  |
| `onboarding.dayPageTap` | 年のページは日付や左端の数字（今月のその日）、月のページは日付の数字を指でタップ、週・月・年のページはマスを指でダブルタップすると、その日のページが開きます。 | en | 指で日のページを開くには、年のページで日付か左端の数字（今月のその日）をタップするか、月のページで日付の数字をタップするか、週・月・年のページでセルをダブルタップします。 | ○（2 回目） |  |
|  |  | zh-Hans・zh-Hant | 日のページを開くには: 年のページで日付か左端の数字（今月のその日）を指でタップする、月のページで日付の数字をタップする、または週・月・年のページのマスを指でダブルタップします。 | ○ |  |
|  |  | ko | 年のページでは日付か左端の数字（今月のその日）を、月のページでは日付の数字を指でタップし、週・月・年のページではマスを指でダブルタップすると、その日のページが開きます。 | ○ |  |
|  |  | fr・es・it | 指で日のページを開くには: 年のページでは、日付か左端の数字（今の月のその日）をタップしてください。月のページでは、日付の数字をタップしてください。週・月・年のページでは、マスを 2 回タップしてください。 | ○（2 回目） |  |
|  |  | de | 指で日のページを開くには次のとおりです: 年のページで日付か左端の数字（今の月のその日）をタップするか、月のページで日付の数字をタップするか、週・月・年のページで枠（Feld）をダブルタップしてください。 | ○（2 回目） |  |
|  |  | pt-BR | 指で日のページを開くには: 年のページでは、日付か左端の数字（今の月のその日）をタップしてください。月のページでは、日付の数字をタップしてください。週・月・年のページでは、セルを 2 回タップしてください。 | ○（2 回目） |  |
| `onboarding.icloud.text` | 手書きはこの端末と、あなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きが見られます。<br><br>iCloud にサインインしていないときは、この端末の中だけに保存します。iCloud の設定は要りません（この端末でサインインしていれば自動で使われます）。<br><br>手書きは開発者には見えません。iCloud の容量はあなたのものを使います。 | en | 手書きはこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きを見られます。<br><br>iCloud にサインインしていなければ、この端末にだけ保存されます。iCloud の設定は要りません（この端末でサインインしていれば自動で使われます）。<br><br>開発者はあなたの手書きを見られません。あなた自身の iCloud の容量を使います。 | ○ |  |
|  |  | zh-Hans | 手書きの内容はこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きの内容を見られます。<br><br>iCloud にログインしていないときは、この端末にだけ保存されます。iCloud の設定は要りません（この端末でログインしていれば自動で使われます）。<br><br>開発者はあなたの手書きの内容を見られません。使うのはあなた自身の iCloud の容量です。 | ○ |  |
|  |  | zh-Hant | 手書きの内容はこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きの内容を見られます。<br><br>iCloud にログインしていないときは、この端末にだけ保存されます。iCloud を設定する必要はありません（この端末でログインしていれば自動で使われます）。<br><br>開発者はあなたの手書きの内容を見られません。使うのはあなた自身の iCloud の容量です。 | ○ |  |
|  |  | ko | 手書きはこの端末とユーザーの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きを見られます。<br><br>iCloud にログインしていないときは、この端末の中にだけ保存します。iCloud の設定は要りません（この端末でログインしていれば自動で使われます）。<br><br>開発者は手書きを見られません。iCloud の保存容量はユーザーのものを使います。 | ○ |  |
|  |  | fr | 手書きはこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも見られます。<br><br>iCloud に接続していなければ、この端末にだけ保存されます。iCloud の設定は要りません（この端末で接続していれば自動で使われます）。<br><br>開発者はあなたの手書きを見られません。使われるのはあなた自身の iCloud の容量です。 | ○ |  |
|  |  | de | 手書きはこの端末とあなたの iCloud に保存されます。同じ手書きをほかの iPad や iPhone でも見られます。<br><br>iCloud にログインしていなければ、この端末にだけ保存されます。iCloud の設定は要りません（この端末でログインしていれば自動で使われます）。<br><br>開発者はあなたの手書きを見られません。使うのはあなた自身の iCloud の容量です。 | ○ |  |
|  |  | es | 手書きはこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きを見られます。<br><br>iCloud にサインインしていなければ、この端末にだけ保存されます。iCloud を設定する必要はありません（この端末でサインインしていれば自動で使われます）。<br><br>開発者はあなたの手書きを見られません。使うのはあなた自身の iCloud の容量です。 | ○ |  |
|  |  | it | 手書きはこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きを見られます。<br><br>iCloud にサインインしていなければ、この端末にだけ保存されます。iCloud を設定する必要はありません（この端末でサインインしていれば自動で使われます）。<br><br>開発者はあなたの手書きを見られません。使うのはあなたの iCloud の容量です。 | ○ |  |
|  |  | pt-BR | 手書きはこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きを見られます。<br><br>iCloud に接続していなければ、この端末にだけ保存されます。iCloud を設定する必要はありません（この端末で接続していれば自動で使われます）。<br><br>開発者はあなたの手書きを見られません。使うのはあなた自身の iCloud の容量です。 | ○ |  |
| `onboarding.icloud.title` | iCloud と手書きの保存 | en・ko・fr・de・es・it | iCloud と手書きの保存 | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud と手書きの内容の保存 | ○ |  |
|  |  | pt-BR | iCloud と手書きの保存のしかた | ○ |  |
| `onboarding.next` | 次へ | 全部 | 次へ | ○ |  |
| `onboarding.openSettings` | 設定アプリを開く | en・ko・fr・es・it・pt-BR | 設定アプリを開く | ○ |  |
|  |  | zh-Hans・zh-Hant・de | 「設定」アプリを開く | ○ |  |
| `onboarding.pen.text` | Apple Pencil で紙に書きます。指はスクロール・ピンチ拡大・予定のタップに使います。手のひらが触れても線は引かれません。<br><br>指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。Apple Pencil のダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作どおりにペンと消しゴムを切り替えます。<br><br>%@ | en | Apple Pencil で紙に書きます。指ではスクロール、ピンチで拡大縮小、予定のタップをします。手のひらが画面に触れても線は引かれません。<br><br>指でも書くには、ツールバーの「指で描く」をオンにします。Apple Pencil のダブルタップやスクイーズで、iPad の設定 > Apple Pencil で選んだ動作に従い、ペンと消しゴムが切り替わります。<br><br>%@ | ○ |  |
|  |  | zh-Hans | Apple Pencil で紙に書きます。指はスクロール、2 本指のピンチで拡大縮小、予定のタップに使います。手のひらが画面に触れても線は引かれません。<br><br>指でも書きたいときは、ツールバーの「指で書く」をオンにします。Apple Pencil をダブルタップまたはスクイーズすると、iPad の「設定」> Apple Pencil で選んだ操作に従ってペンと消しゴムが切り替わります。<br><br>%@ | ○ |  |
|  |  | zh-Hant | Apple Pencil で紙に書きます。指はスクロール、2 本指のピンチで拡大縮小、予定のタップに使います。手のひらが画面に触れても線は引かれません。<br><br>指でも書きたいときは、ツールバーの「指で書く」をオンにします。Apple Pencil をダブルタップまたはスクイーズすると、iPad の「設定」> Apple Pencil で選んだ動作に従ってペンと消しゴムが切り替わります。<br><br>%@ | ○ |  |
|  |  | ko | Apple Pencil で紙に書きます。指はスクロール、2 本指の拡大・縮小、予定のタップに使います。手のひらが触れても線は引かれません。<br><br>指でも書きたいときは、ツールバーの「指で書く」をオンにしてください。Apple Pencil のダブルタップとスクイーズは、iPad の設定 > Apple Pencil で選んだ動作のとおりにペンと消しゴムを切り替えます。<br><br>%@ | ○ |  |
|  |  | fr | Apple Pencil で紙に書きます。指はスクロール、つまんでの拡大縮小、予定のタップに使います。手のひらが画面に触れても線は引かれません。<br><br>指でも書くには、ツールバーの「指で書く」をオンにします。Apple Pencil のダブルタップとスクイーズ（つまむ動作）は、iPad の設定 > Apple Pencil で選んだ動作に従ってペンと消しゴムを切り替えます。<br><br>%@ | ○ |  |
|  |  | de | Apple Pencil で紙に書きます。指ではスクロール、拡大縮小（2 本の指）、予定のタップをします。手のひらは画面に触れても線を引きません。<br><br>指でも書くには、ツールバーの「指で描く」をオンにします。Apple Pencil のダブルタップと押す動作（スクイーズ）は、iPad の「設定」>「Apple Pencil」で選んだ動作に応じて、ペンと消しゴムを切り替えます。<br><br>%@ | ○ |  |
|  |  | es | Apple Pencil で紙に書きます。指はスクロール、2 本の指での拡大、予定のタップに使います。手のひらは画面に触れても線を引きません。<br><br>指でも書くには、ツールバーの「指で描く」をオンにします。Apple Pencil のダブルタップとにぎる動作（スクイーズ）は、iPad の設定（Ajustes／Configuración）> Apple Pencil で選んだ動作に従って、ペンと消しゴムを切り替えます。<br><br>%@ | △ |  |
|  |  | it | Apple Pencil で紙に書きます。指はスクロール、2 本の指での拡大、予定のタップに使います。手のひらは画面に触れても線を引きません。<br><br>指でも書くには、ツールバーの「指で書く」をオンにします。Apple Pencil のダブルタップと押す動作（スクイーズ）は、iPad の設定 > Apple Pencil で選んだ動作に従って、ペンと消しゴムを切り替えます。<br><br>%@ | ○ |  |
|  |  | pt-BR | Apple Pencil で紙に書きます。指はスクロール、2 本の指での拡大、予定のタップに使います。手のひらは画面に触れても線を引きません。<br><br>指でも書くには、ツールバーの「指で線を引く」をオンにします。Apple Pencil のダブルタップとにぎる動作（スクイーズ）は、iPad の設定 > Apple Pencil で選んだ動作に従って、ペンと消しゴムを切り替えます。<br><br>%@ | ○ |  |
| `onboarding.pen.title` | ペンで書き、指で動かす | 全部 | ペンで書き、指で動かす | ○ |  |
| `paper.freeMemo` | 自由メモ | 全部 | 自由メモ | ○ |  |
| `paper.memo` | メモ | 全部 | メモ | ○ |  |
| `paywall.after.paid` | %@。自動更新です。いつでも解約できます。 | en・ko | %@。自動で更新されます。いつでも解約できます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %@。自動で更新します。いつでも解約できます。 | ○ |  |
|  |  | fr・es・it・pt-BR | %@。自動更新。いつでも解約できます。 | ○ |  |
|  |  | de | %@。自動延長。いつでも解約できます。 | ○ |  |
| `paywall.after.trial` | 試用後は %@。いつでも解約できます。 | en・de | その後は %@。いつでも解約できます。 | ○ |  |
|  |  | zh-Hans・zh-Hant・es・it・pt-BR | お試しの後は %@。いつでも解約できます。 | ○ |  |
|  |  | ko | 体験の後は %@。いつでも解約できます。 | ○ |  |
|  |  | fr | お試しの後: %@。いつでも解約できます。 | ○ |  |
| `paywall.billingRetryLead` | お支払いに問題があります。%@でお支払い方法を確認してください。 | en・fr | 支払いに問題があります。%@ で支払い方法を確かめてください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | お支払いに問題があります。%@で支払い方法を確かめてください。 | ○ |  |
|  |  | ko・de・es・it・pt-BR | お支払いに問題があります。%@ で支払い方法を確かめてください。 | ○ |  |
| `paywall.blockedLead` | 書く・消す・予定を作るには購読が必要です。 | en・fr・es・it・pt-BR | 書く・消す・予定を作るには購読してください。 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・de | 書く・消す・予定の作成には購読が必要です。 | ○ |  |
| `paywall.blockedTrial.one` | %@ 日間無料で試せます。 | en・fr・de・es・it・pt-BR |  %@ 日間、無料で試せます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %@ 日間、無料で試せます。 | ○ |  |
|  |  | ko |  %@ 日間、無料で体験できます。 | ○ |  |
| `paywall.blockedTrial.other` | %@ 日間無料で試せます。 | en・fr・de・es・it・pt-BR |  %@ 日間、無料で試せます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %@ 日間、無料で試せます。 | ○ |  |
|  |  | ko |  %@ 日間、無料で体験できます。 | ○ |  |
| `paywall.cta.buy` | 購入する | en・zh-Hans・zh-Hant・ko | 購入 | ○ |  |
|  |  | fr・de・es・it・pt-BR | 購入する | ○ |  |
| `paywall.cta.trial.one` | %@ 日間無料で試す | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 日間無料で試す | ○ |  |
|  |  | ko | %@ 日間無料で体験 | ○ |  |
| `paywall.cta.trial.other` | %@ 日間無料で試す | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 日間無料で試す | ○ |  |
|  |  | ko | %@ 日間無料で体験 | ○ |  |
| `paywall.disclosure.paid` | サブスクリプションは自動更新です。現在の期間が終わる 24 時間前までに解約しない限り、同じ期間・同じ価格で更新され、Apple Account に請求されます。料金は購入の確認時に請求されます。解約は端末の%@からいつでもできます。解約しても、支払い済みの期間が終わるまで使えます。 | en | サブスクリプションは自動で更新されます。今の期間が終わる 24 時間以上前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。購入を確定したときに請求されます。端末の %@ でいつでも解約できます。解約した後も、支払い済みの期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | サブスクリプションは自動で更新されます。今の期間が終わる 24 時間以上前に解約しない限り、同じ期間・同じ価格で更新され、あなたの Apple アカウントに課金されます。料金は購入を確定したときに課金されます。端末の%@でいつでも解約できます。解約後も、支払い済みの期間が終わるまで使えます。 | ○ |  |
|  |  | ko | 購読は自動で更新されます。今の期間が終わる少なくとも 24 時間前までに解約しないと、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。料金は購入を確定するときに請求されます。解約は端末の %@ でいつでもできます。解約しても、支払った期間が終わるまで使えます。 | ○ |  |
|  |  | fr | 購読は自動で更新されます。今の期間が終わる 24 時間以上前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントから引き落とされます。金額は購入の確定のときに引き落とされます。端末の %@ でいつでも解約できます。解約の後も、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | de | 購読は自動で延長されます。今の期間の終わりの 24 時間以上前に解約しない限り、同じ期間・同じ価格で延長され、Apple アカウントに請求されます。料金は購入の確定のときに請求されます。端末の %@ でいつでも解約できます。解約の後も、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | es・it | 購読は自動で更新されます。今の期間の終わりの少なくとも 24 時間前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。金額は購入の確定のときに請求されます。端末の %@ でいつでも解約できます。解約の後、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | pt-BR | 購読は自動で更新されます。今の期間の終わりの少なくとも 24 時間前に解約しない限り、同じ期間・同じ価格で更新され、金額は Apple アカウントに請求されます。金額は購入の確定のときに請求されます。端末の %@ でいつでも解約できます。解約の後、支払った期間の終わりまでアプリを使えます。 | ○ |  |
| `paywall.disclosure.trial` | サブスクリプションは自動更新です。現在の期間が終わる 24 時間前までに解約しない限り、同じ期間・同じ価格で更新され、Apple Account に請求されます。料金は無料試用の終了時に請求されます。解約は端末の%@からいつでもできます。解約しても、支払い済みの期間が終わるまで使えます。 | en | サブスクリプションは自動で更新されます。今の期間が終わる 24 時間以上前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。無料トライアルが終わると請求されます。端末の %@ でいつでも解約できます。解約した後も、支払い済みの期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | サブスクリプションは自動で更新されます。今の期間が終わる 24 時間以上前に解約しない限り、同じ期間・同じ価格で更新され、あなたの Apple アカウントに課金されます。料金は無料トライアルが終わったときに課金されます。端末の%@でいつでも解約できます。解約後も、支払い済みの期間が終わるまで使えます。 | ○ |  |
|  |  | ko | 購読は自動で更新されます。今の期間が終わる少なくとも 24 時間前までに解約しないと、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。料金は無料体験が終わるときに請求されます。解約は端末の %@ でいつでもできます。解約しても、支払った期間が終わるまで使えます。 | ○ |  |
|  |  | fr | 購読は自動で更新されます。今の期間が終わる 24 時間以上前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントから引き落とされます。金額は無料のお試しの終わりに引き落とされます。端末の %@ でいつでも解約できます。解約の後も、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | de | 購読は自動で延長されます。今の期間の終わりの 24 時間以上前に解約しない限り、同じ期間・同じ価格で延長され、Apple アカウントに請求されます。料金は無料のお試し期間の終わりに請求されます。端末の %@ でいつでも解約できます。解約の後も、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | es | 購読は自動で更新されます。今の期間の終わりの少なくとも 24 時間前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。金額は無料のお試しが終わるときに請求されます。端末の %@ でいつでも解約できます。解約の後、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | it | 購読は自動で更新されます。今の期間の終わりの少なくとも 24 時間前に解約しない限り、同じ期間・同じ価格で更新され、Apple アカウントに請求されます。金額は無料のお試しの終わりに請求されます。端末の %@ でいつでも解約できます。解約の後、支払った期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | pt-BR | 購読は自動で更新されます。今の期間の終わりの少なくとも 24 時間前に解約しない限り、同じ期間・同じ価格で更新され、金額は Apple アカウントに請求されます。金額は無料のお試しの終わりに請求されます。端末の %@ でいつでも解約できます。解約の後、支払った期間の終わりまでアプリを使えます。 | ○ |  |
| `paywall.feature.events` | 手書きから予定を作る。予定の作成・編集 | en・fr・de・es・it・pt-BR | 手書きから予定を作る。予定を作成・編集する | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容から予定を作る。予定の作成と編集 | ○ |  |
|  |  | ko | 手書きで予定を作る。予定の作成と編集 | ○ |  |
| `paywall.feature.ink` | 手書き（ペン・マーカー・消しゴム・投げなわ） | 全部 | 手書き（ペン、マーカー、消しゴム、投げなわ） | ○ |  |
| `paywall.feature.sync` | iCloud で iPad・iPhone と同期 | en・zh-Hans・zh-Hant | iCloud を通して iPad と iPhone で同期 | ○ |  |
|  |  | ko | iCloud で iPad、iPhone と同期 | ○ |  |
|  |  | fr | iPad と iPhone の iCloud 同期 | ○ |  |
|  |  | de・it | iCloud を通して iPad や iPhone と同期 | ○ |  |
|  |  | es・pt-BR | iCloud で iPad や iPhone と同期 | ○ |  |
| `paywall.intro` | iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。 | en・fr | iPad のカレンダーの上に Apple Pencil で自由に書ける手帳です。 | ○ |  |
|  |  | zh-Hans・zh-Hant | これは手帳です。iPad のカレンダーの上に Apple Pencil で自由に書けます。 | ○ |  |
|  |  | ko | iPad のカレンダーの上に Apple Pencil で自由に書けるプランナーです。 | ○ |  |
|  |  | de | iPad のカレンダーの上に、Apple Pencil で自由に書けるプランナーです。 | ○ |  |
|  |  | es | iPad のカレンダーの上に、Apple Pencil で自由に書くための手帳です。 | ○ |  |
|  |  | it | iPad のカレンダーの上に、Apple Pencil で自由に書ける手帳です。 | ○ |  |
|  |  | pt-BR | iPad のカレンダーの上に、Apple Pencil で思いのままに書ける手帳です。 | ○ |  |
| `paywall.later` | あとで | en | あとで | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | 後で | ○ |  |
| `paywall.manage` | サブスクリプションを管理 | en・zh-Hans・zh-Hant | サブスクリプションを管理 | ○ |  |
|  |  | ko | 購読の管理 | ○ |  |
|  |  | fr・de・es・it・pt-BR | 購読を管理 | ○ |  |
| `paywall.noPriceNote` | 価格を取得できません | en・zh-Hans・zh-Hant・ko・fr・de・es・it | 価格を取得できません | ○ |  |
|  |  | pt-BR | 価格を取得できませんでした | ○ |  |
| `paywall.privacy` | プライバシーポリシー | en・zh-Hans・zh-Hant・fr・es・pt-BR | プライバシーポリシー | ○ |  |
|  |  | ko | 個人情報処理方針（プライバシーポリシー） | ○ |  |
|  |  | de・it | プライバシーについての説明（プライバシーポリシー） | ○ |  |
| `paywall.recommended` | おすすめ | 全部 | おすすめ | ○ |  |
| `paywall.reload` | 再読み込み | en・zh-Hans・zh-Hant・ko・fr・de・it・pt-BR | 再読み込み | ○ |  |
|  |  | es | もう一度読み込む | ○ |  |
| `paywall.restore` | 購入を復元 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 購入を復元 | ○ |  |
|  |  | ko | 購入の復元 | ○ |  |
| `paywall.revokedLead` | 購入が返金または取り消されました。再び使うには購読してください。 | en | 購入は返金または取り消しになりました。もう一度アプリを使うには購読してください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 購入は返金または取り消しになりました。もう一度使うには購読してください。 | ○ |  |
|  |  | ko | 購入が返金されたか、取り消されました。また使うには購読してください。 | ○ |  |
|  |  | fr・de・es・it・pt-BR | 購入は返金または取り消しになりました。アプリをまた使うには購読してください。 | ○ |  |
| `paywall.terms` | 利用規約 | en | 利用規約 | ○ |  |
|  |  | zh-Hans・zh-Hant | サービス利用規約 | ○ |  |
|  |  | ko | サービス約款（利用規約） | ○ |  |
|  |  | fr・es・it | サービスの条件 | ○ |  |
|  |  | de | サービスの利用条件 | ○ |  |
|  |  | pt-BR | サービスの規約 | ○ |  |
| `paywall.title` | てがきカレンダー | en | Tegaki（手書き。ローマ字の名前） | △ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | Tegaki（ローマ字の名前） | △ |  |
| `paywall.trialIneligible` | 無料試用の対象外です（お試しは 1 つの Apple Account につき 1 回）。 | en | 無料トライアルは使えません（Apple アカウントごとに 1 回）。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 無料トライアルの条件を満たしていません（1 つの Apple アカウントにつきお試しは 1 回）。 | ○ |  |
|  |  | ko | 無料体験の対象ではありません（体験は Apple アカウントごとに 1 回）。 | ○ |  |
|  |  | fr | 無料のお試しを使う権利がありません（Apple アカウントごとに 1 回）。 | ○ |  |
|  |  | de | 無料のお試し期間はご利用になれません（Apple アカウントごとに 1 回）。 | ○ |  |
|  |  | es・it・pt-BR | 無料のお試しを使えません（Apple アカウントごとに 1 回）。 | ○ |  |
| `paywall.trialLead.one` | %@ 日間無料でお試し。 | en | %@ 日間、無料でお試しください。 | ○ |  |
|  |  | zh-Hans・zh-Hant・de | %@ 日間無料で試す。 | ○ |  |
|  |  | ko | %@ 日間の無料体験。 | ○ |  |
|  |  | fr・es・it・pt-BR | %@ 日間の無料お試し。 | ○ |  |
| `paywall.trialLead.other` | %@ 日間無料でお試し。 | en | %@ 日間、無料でお試しください。 | ○ |  |
|  |  | zh-Hans・zh-Hant・de | %@ 日間無料で試す。 | ○ |  |
|  |  | ko | %@ 日間の無料体験。 | ○ |  |
|  |  | fr・es・it・pt-BR | %@ 日間の無料お試し。 | ○ |  |
| `paywall.trialRest` | 試用期間が終わると自動的に有料になります。試用中に解約すれば料金はかかりません。 | en |  無料トライアルが終わると、自動で有料になります。無料トライアルの間に解約すれば、請求されません。 | ○ |  |
|  |  | zh-Hans・zh-Hant | お試し期間が終わると自動で有料に切り替わります。お試しの間に解約すれば課金されません。 | ○ |  |
|  |  | ko |  体験期間が終わると自動で有料になります。体験中に解約すると料金は請求されません。 | ○ |  |
|  |  | fr |  お試しが終わると、購読は自動で有料になります。お試しの間に解約すれば、何も請求されません。 | ○ |  |
|  |  | de |  お試し期間の後、購読は自動で有料になります。お試し期間中に解約すれば費用はかかりません。 | ○ |  |
|  |  | es・pt-BR |  お試しが終わると、自動で有料になります。お試しの間に解約すれば、何も請求されません。 | ○ |  |
|  |  | it |  お試しが終わると自動で有料になります。お試しの間に解約すれば、何も払いません。 | ○ |  |
| `paywall.yearlyNote.both` | 月あたり %1$@・%2$@ | en・fr・de | 1 か月あたり %1$@ · %2$@ | ○ |  |
|  |  | zh-Hans・zh-Hant | 毎月 %1$@ · %2$@ | ○ |  |
|  |  | ko | 月 %1$@ · %2$@ | ○ |  |
|  |  | es・it・pt-BR | 1 か月 %1$@ · %2$@ | ○ |  |
| `paywall.yearlyNote.perMonth` | 月あたり %@ | en・fr・de | 1 か月あたり %@ | ○ |  |
|  |  | zh-Hans・zh-Hant | 毎月 %@ | ○ |  |
|  |  | ko | 月 %@ | ○ |  |
|  |  | es・it・pt-BR | 1 か月 %@ | ○ |  |
| `recurrence.futureEvents` | 以降すべて | en | この予定とこれ以降の予定 | ○ |  |
|  |  | zh-Hans | 今回と以後 | ○ |  |
|  |  | zh-Hant | 今回とこの後 | ○ |  |
|  |  | ko | 以後すべて | ○ |  |
|  |  | fr・es・it・pt-BR | これと以降 | ○ |  |
|  |  | de | この予定とそれ以降すべて | ○ |  |
| `recurrence.message.delete` | この回だけ削除しますか？ 以降すべて削除しますか？ | en | この予定だけを削除しますか、それともこの予定とこれ以降のすべての予定を削除しますか？ | ○ |  |
|  |  | zh-Hans | 今回だけ削除しますか、それとも今回と以後のすべての予定を削除しますか？ | ○ |  |
|  |  | zh-Hant | 今回だけ削除しますか、それとも今回とこの後のすべての予定を削除しますか？ | ○ |  |
|  |  | ko | 今回だけ削除しますか？ 以後すべて削除しますか？ | ○ |  |
|  |  | fr | これだけを削除しますか、それともこれと以降のすべてを削除しますか？ | ○ |  |
|  |  | de | この予定だけを削除しますか、それともこの予定とそれ以降すべてを削除しますか？ | ○ |  |
|  |  | es・it | この予定だけを削除しますか、それともこれと以降のすべてを削除しますか？ | ○ |  |
|  |  | pt-BR | この予定だけを消しますか、それともこれと以降のすべてを消しますか？ | ○ |  |
| `recurrence.message.save` | この回だけ変更しますか？ 以降すべてに適用しますか？ | en | この予定だけを変更しますか、それともこの予定とこれ以降のすべての予定を変更しますか？ | ○ |  |
|  |  | zh-Hans | 今回だけ変更しますか、それとも今回と以後のすべての予定に適用しますか？ | ○ |  |
|  |  | zh-Hant | 今回だけ変更しますか、それとも今回とこの後のすべての予定に適用しますか？ | ○ |  |
|  |  | ko | 今回だけ変更しますか？ 以後すべてに適用しますか？ | ○ |  |
|  |  | fr | これだけを変更しますか、それともこれと以降のすべてを変更しますか？ | ○ |  |
|  |  | de | この予定だけを変更しますか、それともこの予定とそれ以降すべてを変更しますか？ | ○ |  |
|  |  | es・it・pt-BR | この予定だけを変更しますか、それともこれと以降のすべてを変更しますか？ | ○ |  |
| `recurrence.thisEvent` | この回だけ | en・de・es・it・pt-BR | この予定だけ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 今回だけ | ○ |  |
|  |  | fr | これだけ | ○ |  |
| `recurrence.title` | 繰り返しの予定です | en・zh-Hans・zh-Hant | これは繰り返しの予定です | ○ |  |
|  |  | ko・it・pt-BR | 繰り返しの予定です | ○ |  |
|  |  | fr・de | 繰り返しの予定 | ○ |  |
|  |  | es | 繰り返す予定です | ○ |  |
| `selection.delete` | 削除 | en・zh-Hans・zh-Hant・ko・fr・es・it | 削除 | ○ |  |
|  |  | de | 消す（Löschen。「削除」と同じ語） | ○ |  |
|  |  | pt-BR | 消す（削除） | ○ |  |
| `selection.deselect` | 選択解除 | en・it | 選択を解除 | ○ |  |
|  |  | zh-Hans・zh-Hant | 選択を取り消す | ○ |  |
|  |  | ko | 選択の解除 | ○ |  |
|  |  | fr | 取り消す（Annuler。「キャンセル」と同じ語で、選択の解除は語の上には出ない） | △ |  |
|  |  | de・pt-BR | 選択を外す | ○ |  |
|  |  | es | キャンセル（Cancelar。選択の解除は語の上には出ない） | △ |  |
| `selection.handwriting` | 選択した手書き | en・ko・fr・de・es・it・pt-BR | 選択した手書き | ○ |  |
|  |  | zh-Hans・zh-Hant | 選択した手書きの内容 | ○ |  |
| `selection.makeEvent` | 予定にする | en・zh-Hans・zh-Hant | 予定にする | ○ |  |
|  |  | ko・es・it・pt-BR | 予定を作る | ○ |  |
|  |  | fr | 予定（約束）を作る | △ |  |
|  |  | de | 予定として | △ |  |
| `settings.calendar.a11y.hidden` | 非表示 | en・ko・fr・de・es・it・pt-BR | 非表示 | ○ |  |
|  |  | zh-Hans・zh-Hant | 隠しています | ○ |  |
| `settings.calendar.a11y.shown` | 表示中 | en・fr・de・es・it・pt-BR | 表示 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 表示中 | ○ |  |
| `settings.calendar.access.allow` | 許可する | en・fr・de・es・it・pt-BR | 許可する | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 許可 | ○ |  |
| `settings.calendar.access.denied` | 許可されていません | en・ko・fr・de・es・it・pt-BR | 許可されていません | ○ |  |
|  |  | zh-Hans・zh-Hant | 未許可 | ○ |  |
| `settings.calendar.access.full` | 許可されています（フルアクセス） | en・zh-Hans・ko・fr・de・es・it・pt-BR | 許可済み（フルアクセス） | ○ |  |
|  |  | zh-Hant | 許可済み（フルアクセス権限） | ○ |  |
| `settings.calendar.access.notDetermined` | まだ許可していません | en・fr・de・es・it・pt-BR | まだ許可されていません | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | まだ許可していません | ○ |  |
| `settings.calendar.access.restricted` | この端末では制限されています | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | この端末では制限されています | ○ |  |
|  |  | ko | この端末で制限されています | ○ |  |
| `settings.calendar.access.title` | カレンダーへのアクセス | en・zh-Hans・ko・fr・de・es・it・pt-BR | カレンダーへのアクセス | ○ |  |
|  |  | zh-Hant | カレンダーの利用権限 | ○ |  |
| `settings.calendar.access.writeOnly` | 追加のみ（予定を表示できません） | en・zh-Hans・zh-Hant・de・es | 追加のみ（予定は表示できません） | ○ |  |
|  |  | ko | 追加のみ可能（予定は表示できません） | ○ |  |
|  |  | fr | 追加のみ（予定は表示されません） | ○ |  |
|  |  | it | 追加のみ（予定は見えません） | ○ |  |
|  |  | pt-BR | 追加のみ（予定は表示しません） | ○ |  |
| `settings.calendar.default` | 予定の登録先 | en・zh-Hans・zh-Hant・de・es・it・pt-BR | 新しい予定の追加先 | ○ |  |
|  |  | ko | 新しい予定を入れるカレンダー | ○ |  |
|  |  | fr | 新しい予定のカレンダー | ○ |  |
| `settings.calendar.empty` | カレンダーがありません | 全部 | カレンダーがありません | ○ |  |
| `settings.calendar.google.howTo` | Google カレンダーの予定を出すには、「設定」アプリで Google アカウントを追加します。<br>①「設定」→「アプリ」→「カレンダー」→「カレンダーアカウント」→「アカウントを追加」→「Google」（iOS・iPadOS 17 では「設定」→「カレンダー」→「アカウント」）<br>②「カレンダー」のスイッチをオン<br>③同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定の反映が早くなります。<br><br>iCloud カレンダーだけの人は、このままで大丈夫です。 | en | Google カレンダーの予定を表示するには、設定アプリで Google アカウントを追加します。<br>1. 設定 > アプリ > カレンダー > カレンダーアカウント > アカウントを追加 > Google（iOS・iPadOS 17 では 設定 > カレンダー > アカウント）<br>2. カレンダーをオンにします。<br>3. 同じ画面の「データの取得方法」で「15 分ごと」を選ぶと、予定が早く更新されます。<br><br>iCloud のカレンダーだけを使うなら、何もしなくて構いません。 | △ |  |
|  |  | zh-Hans・zh-Hant | Google カレンダーの予定を表示するには、「設定」アプリで Google アカウントを追加します。<br>①「設定」> アプリ >「カレンダー」>「カレンダーアカウント」>「アカウントを追加」> Google（iOS と iPadOS 17 は「設定」>「カレンダー」>「アカウント」）<br>②「カレンダー」のスイッチをオン<br>③ 同じ画面の「新規データの取得」で「15 分ごと」を選ぶと、予定が早く更新されます。<br><br>iCloud のカレンダーだけを使うなら、設定は要りません。 | △ |  |
|  |  | ko | Google カレンダーの予定を表示するには、設定アプリで Google アカウントを追加します。<br>① 設定 > アプリ > カレンダー > カレンダーアカウント > アカウントを追加 > Google（iOS および iPadOS 17: 設定 > カレンダー > アカウント）<br>② カレンダーのスイッチをオンにする<br>③ 同じ画面の「データの更新」で「15 分ごと」を選ぶと、予定がもっと早く反映されます。<br><br>iCloud のカレンダーだけを使うなら、このままで構いません。 | △ |  |
|  |  | fr | Google カレンダーの予定を表示するには、設定アプリで Google アカウントを追加します。<br>1. 設定 > アプリ > カレンダー > カレンダーアカウント > アカウントを追加 > Google（iOS・iPadOS 17 では 設定 > カレンダー > アカウント）<br>2. カレンダーをオンにします。<br>3. 同じ画面の「新規データの取得」で「15 分ごと」を選ぶと、予定がより早く更新されます。<br><br>iCloud のカレンダーだけを使うなら、何もしなくて構いません。 | △ |  |
|  |  | de | Google カレンダーの予定を表示するには、「設定」アプリで Google アカウントを追加します。<br>1. 設定 > アプリ > カレンダー > カレンダーアカウント > アカウントを追加 > Google（iOS・iPadOS 17 では 設定 > カレンダー > アカウント）<br>2. カレンダーをオンにします。<br>3. 同じ画面の「データの照合」で「15 分ごと」を選ぶと、予定が早く更新されます。<br><br>iCloud のカレンダーだけを使うなら、何もしなくて構いません。 | △ |  |
|  |  | es | Google カレンダーの予定を表示するには、設定（Ajustes／Configuración）アプリで Google アカウントを追加します。<br>1. 設定（Ajustes／Configuración）> アプリ > カレンダー > カレンダーアカウント > アカウントを追加（Añadir／Agregar）> Google（iOS・iPadOS 17 では 設定（Ajustes／Configuración）> カレンダー > アカウント）<br>2. カレンダーをオンにします。<br>3. 同じ画面の「データの取得」で「15 分ごと」を選ぶと、予定が早めに更新されます。<br><br>iCloud のカレンダーだけを使うなら、何もしなくて構いません。 | △ |  |
|  |  | it | Google カレンダーの予定を表示するには、設定アプリで Google アカウントを追加します。<br>1. 設定 > アプリ > カレンダー > カレンダーアカウント > アカウントを追加 > Google（iOS・iPadOS 17 では 設定 > カレンダー > アカウント）<br>2. カレンダーをオンにします。<br>3. 同じ画面の「新規データをダウンロード」で「15 分ごと」を選ぶと、予定が早く更新されます。<br><br>iCloud のカレンダーだけを使うなら、何もしなくて構いません。 | △ |  |
|  |  | pt-BR | Google カレンダーの予定を表示するには、設定アプリで Google アカウントを追加します。<br>1. 設定 > アプリ > カレンダー > カレンダーアカウント > アカウントを追加 > Google（iOS・iPadOS 17 では 設定 > カレンダー > アカウント）<br>2. カレンダーをオンにします。<br>3. 同じ画面の「新しいデータの取得」で「15 分ごと」を選ぶと、予定が早めに更新されます。<br><br>iCloud のカレンダーだけを使うなら、何もしなくて構いません。 | △ |  |
| `settings.calendar.google.title` | Google カレンダーを使うには | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | Google カレンダーを使う | ○ |  |
|  |  | ko | Google カレンダーを使うには | ○ |  |
| `settings.calendar.header` | カレンダー | 全部 | カレンダー | ○ |  |
| `settings.calendar.noAccess` | カレンダーへのアクセスを許可すると、ここに一覧が出ます | en・zh-Hans・ko | カレンダーへのアクセスを許可すると、ここに一覧が表示されます | ○ |  |
|  |  | zh-Hant | カレンダーの利用を許可すると、ここに一覧が表示されます | ○ |  |
|  |  | fr・de・es・it・pt-BR | カレンダーへのアクセスを許可すると、ここに一覧が見えます | ○ |  |
| `settings.calendar.otherSource` | その他 | 全部 | その他 | ○ |  |
| `settings.calendar.shown` | 表示するカレンダー | 全部 | 表示するカレンダー | ○ |  |
| `settings.data.erase.all` | 全て消す | 全部 | すべて消す | ○ |  |
| `settings.data.erase.cancel` | キャンセル | 全部 | キャンセル | ○ |  |
| `settings.data.erase.confirm` | 消す | en・zh-Hans・zh-Hant・ko・fr・es・it | 消す | ○ |  |
|  |  | de | 消す（Löschen。「削除」と同じ語） | ○ |  |
|  |  | pt-BR | 消す（削除） | ○ |  |
| `settings.data.erase.question.cloud` | この端末と iCloud に保存した手書きを全て消しますか？ | en・fr・de・es・it・pt-BR | この端末と iCloud に保存されたすべての手書きを消しますか？ | ○ |  |
|  |  | zh-Hans・zh-Hant | この端末と iCloud に保存されたすべての手書きの内容を消しますか？ | ○ |  |
|  |  | ko | この端末と iCloud に保存した手書きをすべて消しますか？ | ○ |  |
| `settings.data.erase.question.local` | この端末に保存した手書きを全て消しますか？ | en・fr・de・es・it・pt-BR | この端末に保存されたすべての手書きを消しますか？ | ○ |  |
|  |  | zh-Hans・zh-Hant | この端末に保存されたすべての手書きの内容を消しますか？ | ○ |  |
|  |  | ko | この端末に保存した手書きをすべて消しますか？ | ○ |  |
| `settings.data.erase.title` | 本当に消しますか？ | en | 本当に消してよいですか？ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | 本当に消しますか？ | ○ |  |
| `settings.data.erase.warning.cloud` | この操作は元に戻せません。ほかの iPad や iPhone の手書きも消えます。 | en・de | 元に戻せません。ほかの iPad や iPhone の手書きも消えます。 | ○ |  |
|  |  | zh-Hans | この操作は取り消せません。ほかの iPad や iPhone の手書きの内容も消えます。 | ○ |  |
|  |  | zh-Hant | この操作は元に戻せません。ほかの iPad や iPhone の手書きの内容も消えます。 | ○ |  |
|  |  | ko・es・pt-BR | この操作は元に戻せません。ほかの iPad や iPhone の手書きも消えます。 | ○ |  |
|  |  | fr・it | この操作は取り消せません。ほかの iPad や iPhone の手書きも消えます。 | ○ |  |
| `settings.data.erase.warning.local` | この操作は元に戻せません。 | en・de | 元に戻せません。 | ○ |  |
|  |  | zh-Hans・fr・it | この操作は取り消せません。 | ○ |  |
|  |  | zh-Hant・ko・es・pt-BR | この操作は元に戻せません。 | ○ |  |
| `settings.data.eraseAll` | この端末の手書きを全て消す | en・ko | この端末の手書きをすべて消す | ○ |  |
|  |  | zh-Hans・zh-Hant | この端末のすべての手書きの内容を消す | ○ |  |
|  |  | fr・de・es・it・pt-BR | この端末のすべての手書きを消す | ○ |  |
| `settings.data.export` | 手書きを書き出す | en・ko・fr・de・es・it・pt-BR | 手書きを書き出す | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を書き出す | ○ |  |
| `settings.data.exportFooter` | 「手書きを書き出す」は、この端末に保存されている手書きを 1 つのデータファイル（JSON）にするか、いま開いているページを PDF にします。データファイルは「Web 版の手書きを取り込む」から取り込み直せます（取り込みは購読中に行えます）。 | en | 「手書きを書き出す」は、この端末に保存された手書きを 1 つのデータファイル（JSON）にするか、開いているページの PDF を作ります。データファイルは「Web 版から取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | △ |  |
|  |  | zh-Hans・zh-Hant | 「手書きの内容を書き出す」は、この端末に保存された手書きの内容を 1 つのデータファイル（JSON）にまとめるか、今開いているページを PDF にします。データファイルは「Web 版の手書きの内容を取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | ○ |  |
|  |  | ko | 「手書きを書き出す」は、この端末に保存された手書きをデータファイル（JSON）1 つにするか、今開いているページを PDF にします。データファイルは「Web 版の手書きを取り込む」でもう一度取り込めます（取り込みは購読中に使えます）。 | ○ |  |
|  |  | fr・de・it・pt-BR | 「手書きを書き出す」は、この端末に保存された手書きを 1 つのデータファイル（JSON）にまとめるか、開いているページの PDF を作ります。データファイルは「Web 版から取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | △ |  |
|  |  | es | 「手書きを書き出す」は、この端末に保存された手書きを 1 つのデータファイル（JSON）に集めるか、開いているページの PDF を作ります。データファイルは「Web 版から取り込む」でもう一度取り込めます（取り込みには購読が必要です）。 | △ |  |
| `settings.data.header` | データ | 全部 | データ | ○ |  |
| `settings.data.import` | Web 版の手書きを取り込む | en・fr・de・es・it・pt-BR | Web 版から取り込む | △ |  |
|  |  | zh-Hans・zh-Hant | Web 版の手書きの内容を取り込む | ○ |  |
|  |  | ko | Web 版の手書きを取り込む | ○ |  |
| `settings.data.importFooter` | Web 版の設定で「手書きを書き出す（iPad アプリ用）」をして、そのファイルを選びます。同じファイルを二度取り込んでも手書きは二重になりません。 | en | Web 版の設定で「手書きを書き出す（iPad アプリ用）」（iPad アプリのために手書きを書き出す）を使い、そのファイルを選びます。同じファイルを 2 回取り込んでも、手書きは重複しません。 | △ |  |
|  |  | zh-Hans・zh-Hant | Web 版の設定で「手書きを書き出す（iPad アプリ用）」（手書きの内容を書き出す。iPad アプリで使うためのもの）を使い、そのファイルを選んでください。同じファイルを 2 回取り込んでも、手書きの内容は重複しません。 | △ |  |
|  |  | ko | Web 版の設定で「手書きを書き出す（iPad アプリ用）」（iPad アプリ用の手書きの書き出し）を実行してから、そのファイルを選びます。同じファイルを 2 回取り込んでも手書きは重複しません。 | △ |  |
|  |  | fr・de | Web 版の設定で「手書きを書き出す（iPad アプリ用）」（iPad アプリ用に手書きを書き出す）を使い、そのファイルを選んでください。同じファイルを 2 回取り込んでも、手書きは 2 倍になりません。 | △ |  |
|  |  | es | Web 版の設定で「手書きを書き出す（iPad アプリ用）」（iPad アプリのために手書きを書き出す）を使い、そのファイルを選んでください。同じファイルを 2 回取り込んでも、手書きは重複しません。 | △ |  |
|  |  | it・pt-BR | Web 版の設定で「手書きを書き出す（iPad アプリ用）」（iPad アプリ用に手書きを書き出す）を使い、そのファイルを選んでください。同じファイルを 2 回取り込んでも、手書きは重複しません。 | △ |  |
| `settings.data.lastImport` | 前回の取り込み: %@ | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 前回の取り込み: %@ | ○ |  |
|  |  | ko | 最後の取り込み: %@ | ○ |  |
| `settings.done` | 完了 | en・zh-Hans・zh-Hant・ko・de・es | 完了 | ○ |  |
|  |  | fr・pt-BR | OK | ○ |  |
|  |  | it | 終わり（Fine。「終了」と同じ語で、完了 の意味） | ○ |  |
| `settings.holidays.footer` | 日本の祝日は、このアプリが計算しています（内閣府の発表と照らし合わせて確かめています）。ほかの国の祝日は、公開されているデータ（python-holidays）にもとづきます。旧暦やイスラム暦の祝日など一部は推定で、「（推定）」と付けています。政府の最新の発表と違うことがあります。祝日の設定はこの端末だけに保存します。 | en | 日本の祝日はこのアプリが計算しています（内閣府の発表と照らして確かめています）。ほかの国の祝日は公開データ（python-holidays）に基づきます。旧暦やイスラム暦の祝日など一部は推定で、「（推定）」の印が付きます。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | zh-Hans | 日本の祝日はこのアプリが計算しています（日本の内閣府の公告と照合済み）。ほかの国の祝日は公開データ（python-holidays）に基づきます。旧暦やイスラム暦の祝日など一部の日付は推算で、「（推算）」の印が付きます。政府の最新の公告と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | zh-Hant | 日本の祝日はこのアプリが計算しています（日本の内閣府の公告と照合しています）。ほかの国の祝日は公開データ（python-holidays）に基づきます。旧暦やイスラム暦の祝日など一部の日付は推定で、「（推定）」の印が付きます。政府の最新の公告と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | ko | 日本の祝日はこのアプリが計算します（日本の内閣府の発表と照らして確かめました）。ほかの国の祝日は公開データ（python-holidays）に基づきます。旧暦やイスラム暦の祝日など一部は推定で、「（推定）」と表示します。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存します。 | △ |  |
|  |  | fr | 日本の祝日はこのアプリが計算しています（日本の内閣府の発表に照らして確かめています）。ほかの国の祝日は公開データ（python-holidays）から来ています。太陰暦やイスラム暦の祝日など一部は推定で、「（推定）」の印が付きます。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | de | 日本の祝日はこのアプリが計算しています（日本の内閣府の発表に照らして確かめています）。ほかの国の祝日は公開データ（python-holidays）に基づきます。太陰暦やイスラム暦の祝日など一部は推定で、「（推定）」の印が付きます。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | es | 日本の祝日はこのアプリが計算しています（日本の内閣府の発表で確かめています）。ほかの国の祝日は公開データ（python-holidays）に基づきます。太陰暦やイスラム暦のものなど一部は推定で、「（推定）」の印が付きます。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | it | 日本の祝日はこのアプリが計算しています（日本の内閣府の発表で確かめています）。ほかの国の祝日は公開データ（python-holidays）に基づきます。太陰暦やイスラム暦の祝日など一部は推定で、「（推定）」と付きます。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
|  |  | pt-BR | 日本の祝日はこのアプリが計算しています（日本の内閣の発表と照らして確かめています）。ほかの国の祝日は公開データ（python-holidays）に基づきます。太陰暦やイスラム暦の祝日など一部は推定で、「（推定）」の印が付きます。政府の最新の発表と違うことがあります。祝日の設定はこの端末にだけ保存されます。 | △ |  |
| `settings.holidays.header` | 祝日 | 全部 | 祝日 | ○ |  |
| `settings.holidays.note.beforeNotice` | %@ 年は発表前の推定 | en | %@ は発表前の推定です | ○ |  |
|  |  | zh-Hans | %@ 年は公告前の推算です | ○ |  |
|  |  | zh-Hant | %@ 年は公告前の推定です | ○ |  |
|  |  | ko | %@ 年は発表前の推定 | ○ |  |
|  |  | fr | %@: 公式の発表前の推定 | ○ |  |
|  |  | de | %@ は発表前の推定 | ○ |  |
|  |  | es・it・pt-BR | %@: 発表前の推定 | ○ |  |
| `settings.holidays.note.join` | %1$@・%2$@ | 全部 | %1$@ · %2$@ | ○ |  |
| `settings.holidays.note.nationalOnly` | 全国共通のみ | en・fr・de・es・it・pt-BR | 全国のみ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 全国共通のみ | ○ |  |
| `settings.holidays.note.nationalOnlyAuto` | 全国共通の祝日のみ | en・fr・de・es・it・pt-BR | 全国の祝日のみ | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 全国共通の祝日のみ | ○ |  |
| `settings.holidays.note.noData` | 祝日のデータがありません | en・zh-Hans・zh-Hant・fr・de | 祝日のデータがありません | ○ |  |
|  |  | ko・es・it・pt-BR | 祝日のデータなし | ○ |  |
| `settings.holidays.note.noDataFrom` | %@ 年以降のデータがありません | en・fr・de | %@ 以降のデータがありません | ○ |  |
|  |  | zh-Hans・zh-Hant | %@ 年以降のデータがありません | ○ |  |
|  |  | ko | %@ 年以降のデータなし | ○ |  |
|  |  | es・pt-BR | %@ 以降のデータなし | ○ |  |
|  |  | it | %@ からのデータなし | ○ |  |
| `settings.holidays.row` | 表示する祝日 | 全部 | 表示する祝日 | ○ |  |
| `settings.holidays.value.auto` | 自動（%@） | 全部 | 自動（%@） | ○ |  |
| `settings.holidays.value.autoNote` | 自動（%1$@・%2$@） | 全部 | 自動（%1$@ · %2$@） | ○ |  |
| `settings.holidays.value.none` | なし | 全部 | なし | ○ |  |
| `settings.holidays.value.regionNote` | %1$@（%2$@） | en・fr・de・es・it・pt-BR | %1$@ (%2$@) | ○ |  |
|  |  | zh-Hans・zh-Hant | %1$@（%2$@） | ○ |  |
|  |  | ko | %1$@(%2$@) | ○ |  |
| `settings.holidays.value.subdivision` | %1$@・%2$@ | 全部 | %1$@ · %2$@ | ○ |  |
| `settings.info.footer` | 線の数は、この端末に保存されているページを数えたものです（どこにも送りません）。1 ページに書ける線は %@ 本までです。 | en | 線の数は、この端末に保存されたページから数えています（どこにも送られません）。1 ページに %@ 本まで入ります。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 線の数は、この端末に保存されたページについて数えています（どこにも送られません）。1 ページに %@ 本まで書けます。 | ○ |  |
|  |  | ko | 線の数は、この端末に保存されたページを数えたものです（どこにも送りません）。1 ページに書ける線は %@ 本までです。 | ○ |  |
|  |  | fr・de・it・pt-BR | 線の数は、この端末に保存されたページから来ています（何も送られません）。1 ページに %@ 本まで入ります。 | ○ |  |
|  |  | es | 線の数は、この端末に保存されたページから出しています（どこにも送られません）。1 ページに %@ 本まで入ります。 | ○ |  |
| `settings.info.header` | 情報 | 全部 | 情報 | ○ |  |
| `settings.info.largestPage` | いちばん線の多いページ | 全部 | 線がいちばん多いページ | ○ |  |
| `settings.info.licenses` | オープンソースのライセンス | 全部 | オープンソースのライセンス | ○ |  |
| `settings.info.privacy` | プライバシーポリシー | en・zh-Hans・zh-Hant・fr・es・pt-BR | プライバシーポリシー | ○ |  |
|  |  | ko | 個人情報処理方針（プライバシーポリシー） | ○ |  |
|  |  | de・it | プライバシーについての説明（プライバシーポリシー） | ○ |  |
| `settings.info.support` | サポート | 全部 | サポート | ○ |  |
| `settings.info.terms` | 利用規約 | en | 利用規約 | ○ |  |
|  |  | zh-Hans・zh-Hant | サービス利用規約 | ○ |  |
|  |  | ko | サービス約款（利用規約） | ○ |  |
|  |  | fr・es・it | サービスの条件 | ○ |  |
|  |  | de | サービスの利用条件 | ○ |  |
|  |  | pt-BR | サービスの規約 | ○ |  |
| `settings.info.version` | バージョン | 全部 | バージョン | ○ |  |
| `settings.info.yearPage` | 今年の年のページ | en・zh-Hans・zh-Hant・ko・de | 今年の年のページ | ○ |  |
|  |  | fr・es・it・pt-BR | 今年のページ | ○ |  |
| `settings.input.allowFinger` | 指でも書く | en・de・es | 指で描く | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・it | 指で書く | ○ |  |
|  |  | pt-BR | 指で線を引く | △ |  |
| `settings.input.allowFinger.footer` | オンにすると指でも線が引けます。オフのときは指でスクロールとタップをします。手書きは iPad と Apple Pencil で書くのに向いています | en | オンのときは、指でも線を引けます。オフのときは、指でスクロールとタップをします。手書きは iPad と Apple Pencil でいちばんよく動きます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | オンにすると、指でも線を引けます。オフのときは、指はスクロールとタップに使います。手書きには iPad と Apple Pencil がいちばん適しています。 | ○ |  |
|  |  | ko | オンにすると指でも線を引けます。オフにすると指でスクロールとタップをします。手書きは iPad と Apple Pencil で書くのに向いています。 | ○ |  |
|  |  | fr | オンのときは指でも線を引けます。オフのときは指でスクロールとタップをします。手書きは主に iPad と Apple Pencil に向いています。 | ○ |  |
|  |  | de | オンのときは指でも線を引けます。オフのときは指でスクロールとタップをします。手書きは iPad と Apple Pencil にいちばん向いています。 | ○ |  |
|  |  | es・pt-BR | オンのときは指でも線を引けます。オフのときは指でスクロールとタップをします。手書きは iPad と Apple Pencil でいちばんよく動きます。 | ○ |  |
|  |  | it | オンのときは指でも線を引けます。オフのときは指でスクロールとタップをします。手書きは iPad と Apple Pencil が最適です。 | ○ |  |
| `settings.input.eraseAfterConvert` | 予定にした手書きを消す | en・ko | 予定にした手書きを消す | ○ |  |
|  |  | zh-Hans・zh-Hant | 予定にした手書きの内容を消す | ○ |  |
|  |  | fr | 予定に変えた手書きを消す | ○ |  |
|  |  | de・it | 予定の後に手書きを消す | △ |  |
|  |  | es | 予定を作ったときに書いたものを消す | △ |  |
|  |  | pt-BR | 予定を作った後に手書きを消す | △ |  |
| `settings.input.eraseAfterConvert.footer` | 投げなわで囲んだ手書きを予定にしたあと、その手書きを消すかどうかの初期値です | en | 投げなわで囲んだ手書きを予定にした後、消すかどうかの最初の選択です。 | △ |  |
|  |  | zh-Hans・zh-Hant | 投げなわで囲んだ手書きの内容を予定にした後、それを消すかどうかの最初の選択です。 | △ |  |
|  |  | ko | 投げなわで囲んだ手書きを予定にした後、その手書きを消すかどうかを決める既定の値です。 | ○ |  |
|  |  | fr・es・it・pt-BR | 投げなわで囲んだ手書きを予定に変えた後、消すかどうかの最初の選択です。 | △ |  |
|  |  | de | 投げなわで囲んだ手書きから予定を作った後、その手書きを消すかどうかの最初の選択です。 | △ |  |
| `settings.input.eraserAutoReturn.footer.pad` | 消しゴムで線を消して指や Apple Pencil を離すと、直前のペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムも同じです。 | en | 消しゴムで線を消して指や Apple Pencil を離すと、直前に使っていたペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムでも同じです。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 消しゴムで線を消して指か Apple Pencil を離すと、さっき使っていたペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムでも同じです。 | ○ |  |
|  |  | ko | 消しゴムで線を消して指や Apple Pencil を離すと、直前のペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムも同じです。 | ○ |  |
|  |  | fr | 消しゴムで線を消した後、指か Apple Pencil を離すと、道具は直前に使っていたペンかマーカーに戻ります。Apple Pencil のダブルタップやスクイーズで選んだ消しゴムでも同じです。 | ○ |  |
|  |  | de | 線を消して指か Apple Pencil を持ち上げると、道具は直前に使っていたペンかマーカーに戻ります。Apple Pencil のダブルタップや押す動作（スクイーズ）で選んだ消しゴムでも同じです。 | ○ |  |
|  |  | es・pt-BR | 消しゴムで線を消して指や Apple Pencil を持ち上げると、直前に使っていたペンかマーカーに戻ります。Apple Pencil のダブルタップやにぎる動作（スクイーズ）で選んだ消しゴムでも同じです。 | ○ |  |
|  |  | it | 消しゴムで線を消して指や Apple Pencil を持ち上げると、少し前に使っていたペンかマーカーに戻ります。Apple Pencil のダブルタップや押す動作（スクイーズ）で選んだ消しゴムでも同じです。 | ○ |  |
| `settings.input.eraserAutoReturn.footer.phone` | 消しゴムで線を消して指を離すと、直前のペンかマーカーに戻ります。 | en | 消しゴムで線を消して指を離すと、直前に使っていたペンかマーカーに戻ります。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 消しゴムで線を消して指を離すと、さっき使っていたペンかマーカーに戻ります。 | ○ |  |
|  |  | ko | 消しゴムで線を消して指を離すと、直前のペンかマーカーに戻ります。 | ○ |  |
|  |  | fr | 消しゴムで線を消した後、指を離すと、道具は直前に使っていたペンかマーカーに戻ります。 | ○ |  |
|  |  | de | 線を消して指を持ち上げると、道具は直前に使っていたペンかマーカーに戻ります。 | ○ |  |
|  |  | es・pt-BR | 消しゴムで線を消して指を持ち上げると、直前に使っていたペンかマーカーに戻ります。 | ○ |  |
|  |  | it | 消しゴムで線を消して指を持ち上げると、少し前に使っていたペンかマーカーに戻ります。 | ○ |  |
| `settings.input.eraserAutoReturn.title` | 消しゴムで消したらペンに戻る | en・zh-Hans・zh-Hant・fr・de・es・pt-BR | 消した後にペンに戻る | △ |  |
|  |  | ko | 消した後ペンに戻る | △ |  |
|  |  | it | 消しゴムの後にペンに戻る | △ |  |
| `settings.input.header` | 入力 | 全部 | 入力 | ○ |  |
| `settings.input.pencil` | Apple Pencil | 全部 | Apple Pencil | ○ |  |
| `settings.input.pencil.footer` | ダブルタップ／スクイーズは、iPad の「設定 › Apple Pencil」で選んだ動作に従います | en | ダブルタップとスクイーズは、iPad の設定 > Apple Pencil で選んだ動作に従います。 | ○ |  |
|  |  | zh-Hans | ダブルタップとスクイーズは、iPad の「設定」> Apple Pencil で選んだ操作を行います | ○ |  |
|  |  | zh-Hant | ダブルタップとスクイーズは、iPad の「設定」> Apple Pencil で選んだ動作を行います | ○ |  |
|  |  | ko・fr | ダブルタップとスクイーズは、iPad の設定 > Apple Pencil で選んだ動作に従います | ○ |  |
|  |  | de | ダブルタップと押す動作（スクイーズ）は、iPad の「設定」>「Apple Pencil」で選んだ動作に従います | ○ |  |
|  |  | es | ダブルタップとにぎる動作（スクイーズ）は、iPad の設定（Ajustes／Configuración）> Apple Pencil で選んだ動作に従います | △ |  |
|  |  | it | ダブルタップと押す動作（スクイーズ）は、iPad の設定 > Apple Pencil で選んだ動作に従います | ○ |  |
|  |  | pt-BR | ダブルタップとにぎる動作（スクイーズ）は、iPad の設定 > Apple Pencil で選んだ動作に従います | ○ |  |
| `settings.openSettingsApp` | 設定アプリを開く | en・ko・fr・es・it・pt-BR | 設定アプリを開く | ○ |  |
|  |  | zh-Hans・zh-Hant・de | 「設定」アプリを開く | ○ |  |
| `settings.purchase.footer.cancel` | 解約は端末の%@から。解約しても期間の終わりまで使えます。 | en | 解約するには、端末の %@ に進みます。解約した後も、期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | zh-Hans | キャンセルするには、デバイスの%@へ移動してください。キャンセル後も、現在の周期が終わるまで引き続き使用できます。 | ○ |  |
|  |  | zh-Hant | 解約するには、端末の%@へ進んでください。解約後も、期間の終わりまで使えます。 | ○ |  |
|  |  | ko | 解約は端末の %@ でできます。解約しても、期間が終わるまで使えます。 | ○ |  |
|  |  | fr | 解約するには、端末の %@ へ行ってください。解約の後も、期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | de | 解約は端末の %@ でできます。解約の後も、期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | es・it | 解約するには、端末の %@ へ行ってください。解約の後、期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | pt-BR | 解約するには、端末の %@ を開いてください。解約の後、期間の終わりまでアプリを使えます。 | ○ |  |
| `settings.purchase.footer.grace` | お支払いに問題があります。端末の%@でお支払い方法を確認してください。猶予の期限までは使えます。 | en | 支払いに問題があります。端末の %@ で支払い方法を確かめてください。猶予期間が終わるまでアプリを使えます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | お支払いに問題があります。端末の%@で支払い方法を確かめてください。猶予期間が終わるまでは使えます。 | ○ |  |
|  |  | ko | お支払いに問題があります。端末の %@ で支払い方法を確かめてください。猶予期間が終わるまでは使えます。 | ○ |  |
|  |  | fr | 支払いに問題があります。端末の %@ で支払い方法を確かめてください。猶予期間の終わりまでアプリを使えます。 | ○ |  |
|  |  | de・es・it・pt-BR | お支払いに問題があります。端末の %@ で支払い方法を確かめてください。猶予期間の終わりまでアプリを使えます。 | ○ |  |
| `settings.purchase.footer.readOnly` | %@閲覧専用では、予定と手書きの閲覧、ページ移動、拡大、iCloud からの受信、この端末の手書きを全て消す、手書きの書き出し、設定の変更ができます。新しく書く・消す・動かす、予定の作成・編集、Web 版からの取り込みは購読すると使えます。 | en | %@ 閲覧のみでは、予定と手書きを見る、ページを移動する、拡大縮小する、iCloud から受け取る、この端末の手書きをすべて消す、手書きを書き出す、設定を変えることができます。手書きを書く・消す・動かす、予定を作成・編集する、Web 版から取り込むには購読してください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %@閲覧のみのときは、予定と手書きの内容を見る、ページをめくる、拡大縮小、iCloud から受け取る、この端末のすべての手書きの内容を消す、手書きの内容を書き出す、設定を変えることができます。購読すると、手書きの内容を書く・消す・動かす、予定の作成と編集、Web 版からの取り込みができます。 | ○ |  |
|  |  | ko | %@ 閲覧専用では、予定と手書きを見る、ページの移動、拡大、iCloud から受け取る、この端末の手書きをすべて消す、手書きの書き出し、設定の変更ができます。新しく書く、消す、移す、予定の作成と編集、Web 版からの取り込みは、購読すると使えます。 | ○ |  |
|  |  | fr | %@ 読み取り専用では、予定と手書きを見る、ページを変える、拡大縮小、iCloud から受け取る、この端末のすべての手書きを消す、書き出す、設定を変えることができます。書く・消す・動かす、予定の作成や編集、Web 版からの取り込みには購読してください。 | ○ |  |
|  |  | de | %@ 「見るだけ」では、予定と手書きを見る、ページを移る、拡大縮小、iCloud から受け取る、この端末のすべての手書きを消す、手書きを書き出す、設定を変えることができます。購読すると、書く・消す・動かす、予定の作成と編集、Web 版からの取り込みができます。 | ○ |  |
|  |  | es・it・pt-BR | %@ 読み取り専用では、予定と手書きを見る、ページを変える、拡大する、iCloud から受け取る、この端末のすべての手書きを消す、書き出す、設定を変えることができます。書く・消す・動かす、予定の作成や編集、Web 版からの取り込みには購読してください。 | ○ |  |
| `settings.purchase.footer.trial` | 解約は端末の%@から。解約しても期間の終わりまで使えます。試用中に解約すれば料金はかかりません。 | en | 解約するには、端末の %@ に進みます。解約した後も、期間の終わりまでアプリを使えます。無料トライアルの間に解約すれば、請求されません。 | ○ |  |
|  |  | zh-Hans | キャンセルするには、デバイスの%@へ移動してください。キャンセル後も、現在の周期が終わるまで引き続き使用できます。試用期間中にキャンセルすると、料金はかかりません。 | ○ |  |
|  |  | zh-Hant | 解約するには、端末の%@へ進んでください。解約後も、期間の終わりまで使えます。お試しの間に解約すれば課金されません。 | ○ |  |
|  |  | ko | 解約は端末の %@ でできます。解約しても、期間が終わるまで使えます。体験中に解約すると料金は請求されません。 | ○ |  |
|  |  | fr | 解約するには、端末の %@ へ行ってください。解約の後も、期間の終わりまでアプリを使えます。お試しの間に解約すれば、何も請求されません。 | ○ |  |
|  |  | de | 解約は端末の %@ でできます。解約の後も、期間の終わりまでアプリを使えます。お試し期間中に解約すれば費用はかかりません。 | ○ |  |
|  |  | es | 解約するには、端末の %@ へ行ってください。解約の後、期間の終わりまでアプリを使えます。お試しの間に解約すれば、何も請求されません。 | ○ |  |
|  |  | it | 解約するには、端末の %@ へ行ってください。解約の後、期間の終わりまでアプリを使えます。お試しの間に解約すれば、何も払いません。 | ○ |  |
|  |  | pt-BR | 解約するには、端末の %@ を開いてください。解約の後、期間の終わりまでアプリを使えます。お試しの間に解約すれば、何も請求されません。 | ○ |  |
| `settings.purchase.header` | 購入 | 全部 | 購入 | ○ |  |
| `settings.purchase.manage` | サブスクリプションを管理 | en・zh-Hans・zh-Hant | サブスクリプションを管理 | ○ |  |
|  |  | ko | 購読の管理 | ○ |  |
|  |  | fr・de・es・it・pt-BR | 購読を管理 | ○ |  |
| `settings.purchase.plan` | 現在のプラン | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 今のプラン | ○ |  |
|  |  | de | 今の料金プラン | ○ |  |
| `settings.purchase.restore` | 購入を復元 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 購入を復元 | ○ |  |
|  |  | ko | 購入の復元 | ○ |  |
| `settings.purchase.subscribe` | 購読する | en・fr・de・es・it・pt-BR | 購読する | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 購読 | ○ |  |
| `settings.purchase.trial.one` | %@ 日間無料で試す | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 日間無料で試す | ○ |  |
|  |  | ko | %@ 日間無料で体験 | ○ |  |
| `settings.purchase.trial.other` | %@ 日間無料で試す | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | %@ 日間無料で試す | ○ |  |
|  |  | ko | %@ 日間無料で体験 | ○ |  |
| `settings.sync.header` | 同期 | 全部 | 同期 | ○ |  |
| `settings.sync.icloud` | iCloud 同期 | en・zh-Hans・zh-Hant・ko・fr・de・it | iCloud 同期 | ○ |  |
|  |  | es・pt-BR | iCloud との同期 | ○ |  |
| `settings.sync.lastSync` | 最後に同期 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 前回の同期 | ○ |  |
|  |  | ko | 最後の同期 | ○ |  |
| `settings.sync.lastSync.none` | まだありません | en・fr・de・es・it・pt-BR | まだありません | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | まだなし | ○ |  |
| `settings.sync.newAccount` | 新しいアカウントで使い始める… | 全部 | 新しいアカウントで始める… | ○ |  |
| `settings.sync.now` | 今すぐ同期 | 全部 | 今すぐ同期 | ○ |  |
| `settings.title` | 設定 | 全部 | 設定 | ○ |  |
| `settings.weekStart.auto` | 自動（%@） | 全部 | 自動（%@） | ○ |  |
| `settings.weekStart.confirm.message.monday` | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | en | 週のページは、月曜始まりの週と日曜始まりの週で別々です。今ある週の手書きは、日曜に戻すまで隠れます（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスにある手書きの一部は、戻すまで隠れることがあります（削除されません）。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 月曜始まりと日曜始まりの週のページは別のページです。今書いてある週の手書きの内容は、日曜始まりに戻すまで表示されません（削除されません）。月のページの手書きの内容は同じ日付のマスへ移ります。ただし、前後の月の日付のマスに書いた内容は、一部が戻すまで表示されないことがあります（削除されません）。 | ○ |  |
|  |  | ko | 週のページは、月曜始まりと日曜始まりが互いに別のページです。これまでに書いた週の手書きは、日曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日付のマスに書いたものは、一部が戻すまで見えないことがあります（消えません）。 | ○（2 回目） |  |
|  |  | fr | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。あなたの週のページにすでにある手書きは、日曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れたままのことがあります（何も削除されません）。 | ○（2 回目） |  |
|  |  | de | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週のページの手書きは、日曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスにあるものの一部は、戻すまで隠れたままのことがあります（削除されません）。 | ○ |  |
|  |  | es | 週のページは、月曜に始まる週と日曜に始まる週とで別のものです。週のページにすでにある手書きは、日曜に戻るまで隠れます（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れることがあります（削除されません）。 | ○（2 回目） |  |
|  |  | it | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、日曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、元に戻るまで隠れたままのことがあります（削除されません）。 | ○（2 回目） |  |
|  |  | pt-BR | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、日曜に戻るまで隠れます（消されません）。月のページに書いたものは、同じ日付のセルに移ります。ただし、前の月か次の月の日のセルに書かれたものの一部は、戻るまで隠れることがあります（消されません）。 | ○（2 回目） |  |
| `settings.weekStart.confirm.message.sunday` | 週のページは、月曜始まりと日曜始まりで別のページになります。いま書いてある週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日のマスに書いたものは、一部が戻すまで見えなくなることがあります（消えません）。 | en | 週のページは、月曜始まりの週と日曜始まりの週で別々です。今ある週の手書きは、月曜に戻すまで隠れます（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスにある手書きの一部は、戻すまで隠れることがあります（削除されません）。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 月曜始まりと日曜始まりの週のページは別のページです。今書いてある週の手書きの内容は、月曜始まりに戻すまで表示されません（削除されません）。月のページの手書きの内容は同じ日付のマスへ移ります。ただし、前後の月の日付のマスに書いた内容は、一部が戻すまで表示されないことがあります（削除されません）。 | ○ |  |
|  |  | ko | 週のページは、月曜始まりと日曜始まりが互いに別のページです。これまでに書いた週の手書きは、月曜始まりに戻すまで見えません（消えません）。月のページの手書きは、同じ日付のマスに移ります。ただし、前後の月の日付のマスに書いたものは、一部が戻すまで見えないことがあります（消えません）。 | ○（2 回目） |  |
|  |  | fr | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。あなたの週のページにすでにある手書きは、月曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れたままのことがあります（何も削除されません）。 | ○（2 回目） |  |
|  |  | de | 週のページは、月曜に始まる週と日曜に始まる週で別々です。今の週のページの手書きは、月曜に戻すまで隠れたままです（削除されません）。月のページの手書きは、同じ日付のマスへ移ります。ただし、前後の月の日のマスにあるものの一部は、戻すまで隠れたままのことがあります（削除されません）。 | ○ |  |
|  |  | es | 週のページは、月曜に始まる週と日曜に始まる週とで別のものです。週のページにすでにある手書きは、月曜に戻るまで隠れます（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、戻るまで隠れることがあります（削除されません）。 | ○（2 回目） |  |
|  |  | it | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、月曜に戻るまで隠れたままです（削除されません）。月のページに書いたものは、同じ日付のマスに移ります。ただし、前の月か次の月の日のマスに書かれたものの一部は、元に戻るまで隠れたままのことがあります（削除されません）。 | ○（2 回目） |  |
|  |  | pt-BR | 週のページは、月曜に始まる週と日曜に始まる週とで分かれています。週のページにすでにある手書きは、月曜に戻るまで隠れます（消されません）。月のページに書いたものは、同じ日付のセルに移ります。ただし、前の月か次の月の日のセルに書かれたものの一部は、戻るまで隠れることがあります（消されません）。 | ○（2 回目） |  |
| `settings.weekStart.confirm.ok.monday` | 月曜にする | en・zh-Hans・zh-Hant | 月曜にする | ○ |  |
|  |  | ko | 月曜に設定 | ○ |  |
|  |  | fr | 月曜を選ぶ | ○ |  |
|  |  | de・es・it・pt-BR | 月曜を使う | ○ |  |
| `settings.weekStart.confirm.ok.sunday` | 日曜にする | en・zh-Hans・zh-Hant | 日曜にする | ○ |  |
|  |  | ko | 日曜に設定 | ○ |  |
|  |  | fr | 日曜を選ぶ | ○ |  |
|  |  | de・es・it・pt-BR | 日曜を使う | ○ |  |
| `settings.weekStart.confirm.title.monday` | 週の始まりを月曜にしますか？ | en | 週を月曜始まりにしますか？ | ○ |  |
|  |  | zh-Hans・zh-Hant | 週の最初の日を月曜にしますか？ | ○ |  |
|  |  | ko | 週の最初の日を月曜に設定しますか？ | ○ |  |
|  |  | fr・de・es・it・pt-BR | 週を月曜から始めますか？ | ○ |  |
| `settings.weekStart.confirm.title.sunday` | 週の始まりを日曜にしますか？ | en | 週を日曜始まりにしますか？ | ○ |  |
|  |  | zh-Hans・zh-Hant | 週の最初の日を日曜にしますか？ | ○ |  |
|  |  | ko | 週の最初の日を日曜に設定しますか？ | ○ |  |
|  |  | fr・de・es・it・pt-BR | 週を日曜から始めますか？ | ○ |  |
| `settings.weekStart.footer` | 自動は端末の地域に合わせます（日本は月曜）。この設定は端末ごとです。週の手書きをどの端末でも見られるように、同じ設定にしてください。 | en | 自動は端末の地域に従います。この設定は端末ごとです。同じ週の手書きを見るには、どの端末でも同じ設定にしてください。 | △ |  |
|  |  | zh-Hans・zh-Hant | 「自動」は端末の地域に従います。この設定は端末ごとに保存されます。どの端末でも同じ週の手書きの内容を見るには、同じ設定にしてください。 | △ |  |
|  |  | ko | 自動は端末の地域に従います。この設定は端末ごとに別々に保存します。どの端末でも同じ週の手書きを見るには、同じ設定に合わせてください。 | △ |  |
|  |  | fr | 自動は端末の地域に従います。この設定は端末ごとです。週で同じ手書きを見るには、どの端末でも同じ設定にしてください。 | △ |  |
|  |  | de | 「自動」は端末の地域に従います。この設定は端末ごとです。週のページで同じ手書きを見るには、どの端末でも同じ設定にしてください。 | △ |  |
|  |  | es・it・pt-BR | 自動は端末の地域に従います。この設定は端末ごとのものです。週で同じ手書きを見るには、どの端末でも同じ設定にしてください。 | △ |  |
| `settings.weekStart.monday` | 月曜 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 月曜 | ○ |  |
|  |  | ko | 月曜日 | ○ |  |
| `settings.weekStart.otherPages.one` | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。切り替えると見えます。 | en | %2$@ の週のページは、もう一方の週の始まり（%1$@）を使っています。切り替えると見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %2$@ の週のページは、もう一方の週の最初の日（%1$@）を使っています。切り替えると見られます。 | ○ |  |
|  |  | ko | もう一方の週の最初の日（%1$@）の週のページが %2$@ あります。切り替えると見えます。 | ○ |  |
|  |  | fr・es・it・pt-BR | %2$@ の週のページは、もう一方の最初の日（%1$@）を使っています。見るには設定を変えてください。 | ○ |  |
|  |  | de | %2$@ の週のページは、もう一方の週の始まり（%1$@）を使っています。見るには切り替えてください。 | ○ |  |
| `settings.weekStart.otherPages.other` | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。切り替えると見えます。 | en | %2$@ の週のページは、もう一方の週の始まり（%1$@）を使っています。切り替えると見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %2$@ の週のページは、もう一方の週の最初の日（%1$@）を使っています。切り替えると見られます。 | ○ |  |
|  |  | ko | もう一方の週の最初の日（%1$@）の週のページが %2$@ あります。切り替えると見えます。 | ○ |  |
|  |  | fr・es・it・pt-BR | %2$@ の週のページは、もう一方の最初の日（%1$@）を使っています。見るには設定を変えてください。 | ○ |  |
|  |  | de | %2$@ の週のページは、もう一方の週の始まり（%1$@）を使っています。見るには切り替えてください。 | ○ |  |
| `settings.weekStart.sunday` | 日曜 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 日曜 | ○ |  |
|  |  | ko | 日曜日 | ○ |  |
| `settings.weekStart.title` | 週の始まり | en | 週の始まり | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR | 週の最初の日 | △ |  |
| `store.error.productNotFound` | 商品が見つかりません | 全部 | 商品が見つかりません | ○ |  |
| `store.error.unknownPurchaseResult` | 購入の結果を解釈できません | en | 購入の結果が分かりません | ○ |  |
|  |  | zh-Hans・zh-Hant | 購入の結果を読み取れません | ○ |  |
|  |  | ko・es・it・pt-BR | 購入の結果を解釈できません | ○ |  |
|  |  | fr | 購入の結果を理解できません | ○ |  |
|  |  | de | 購入の結果を評価できません | ○ |  |
| `store.generic` | 購入できませんでした（%@） | en | 購入を完了できませんでした（%@） | ○ |  |
|  |  | zh-Hans・zh-Hant | 購入を完了できません（%@） | ○ |  |
|  |  | ko・es・pt-BR | 購入できませんでした（%@） | ○ |  |
|  |  | fr・de・it | 購入できません（%@） | ○ |  |
| `store.notAvailable` | お住まいの地域ではこのプランを購入できません | en | このプランはお住まいの地域では購入できません | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | お住まいの地域ではこのプランを購入できません | ○ |  |
|  |  | de | お住まいの地域ではこの料金プランを購入できません | ○ |  |
| `store.nothingToRestore` | 復元できる購入がありません。購入したときと同じ Apple Account でサインインしているか確認してください | en・es・it | 復元する購入がありません。購入に使った Apple アカウントでサインインしているか確かめてください | ○ |  |
|  |  | zh-Hans・zh-Hant | 復元できる購入がありません。購入に使った Apple アカウントでログインしているか確かめてください | ○ |  |
|  |  | ko | 復元する購入がありません。購入のときと同じ Apple アカウントでログインしているか確かめてください | ○ |  |
|  |  | fr・pt-BR | 復元する購入がありません。購入に使った Apple アカウントで接続しているか確かめてください | ○ |  |
|  |  | de | 復元する購入がありません。購入に使った Apple アカウントでログインしているか確かめてください | ○ |  |
| `store.offline` | App Store に接続できません。回線を確認してもう一度お試しください | en・de・es・pt-BR | App Store に接続できません。接続を確かめてもう一度お試しください | ○ |  |
|  |  | zh-Hans・zh-Hant | App Store に接続できません。ネットワークを確かめてもう一度お試しください | ○ |  |
|  |  | ko | App Store に接続できません。インターネットの接続を確かめてもう一度お試しください | ○ |  |
|  |  | fr・it | App Store に接続できません。接続を確かめてやり直してください | ○ |  |
| `store.pending` | 承認待ちです。承認されると自動で使えるようになります | en・es・it | 承認を待っています。承認されると自動でアプリを使えます | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 承認を待っています。承認されると自動で使えます | ○ |  |
|  |  | fr | 承認を待っています。購入が承認されると自動でアプリを使えます | ○ |  |
|  |  | de | 承認を待っています。承認の後、アプリは自動で使えるようになります | ○ |  |
|  |  | pt-BR | 承認を待っています。承認の後、自動でアプリを使えます | ○ |  |
| `store.productsUnavailable` | App Store から価格を取得できませんでした。回線を確認して「再読み込み」を押してください | en | App Store から価格を取得できませんでした。接続を確かめて「再読み込み」をタップしてください | ○ |  |
|  |  | zh-Hans・zh-Hant | App Store から価格を取得できません。ネットワークを確かめて「再読み込み」をタップしてください | ○ |  |
|  |  | ko | App Store から価格を取得できませんでした。インターネットの接続を確かめて「再読み込み」を押してください | ○ |  |
|  |  | fr | App Store の価格を取得できません。接続を確かめて「再読み込み」をタップしてください | ○ |  |
|  |  | de | App Store から価格を読み込めませんでした。接続を確かめて「再読み込み」をタップしてください | ○ |  |
|  |  | es | App Store の価格を取得できませんでした。接続を確かめて「もう一度読み込む」をタップしてください | ○ |  |
|  |  | it | App Store から価格を取得できません。接続を確かめて「再読み込み」をタップしてください | ○ |  |
|  |  | pt-BR | App Store の価格を取得できませんでした。接続を確かめて「再読み込み」をタップしてください | ○ |  |
| `store.purchased` | 購読を開始しました。ありがとうございます | en | サブスクリプションが始まりました。ありがとうございます | ○ |  |
|  |  | zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 購読が始まりました。ありがとうございます | ○ |  |
|  |  | ko | 購読を始めました。ありがとうございます | ○ |  |
| `store.restored` | 購入を復元しました | 全部 | 購入を復元しました | ○ |  |
| `store.trialStarted.one` | %@ 日間の無料試用を開始しました | en・zh-Hans・zh-Hant | %@ 日間の無料トライアルが始まりました | ○ |  |
|  |  | ko | %@ 日の無料体験を始めました | ○ |  |
|  |  | fr・es・it・pt-BR | %@ 日間の無料お試しが始まりました | ○ |  |
|  |  | de | %@ 日間の無料のお試し期間が始まりました | ○ |  |
| `store.trialStarted.other` | %@ 日間の無料試用を開始しました | en・zh-Hans・zh-Hant | %@ 日間の無料トライアルが始まりました | ○ |  |
|  |  | ko | %@ 日の無料体験を始めました | ○ |  |
|  |  | fr・es・it・pt-BR | %@ 日間の無料お試しが始まりました | ○ |  |
|  |  | de | %@ 日間の無料のお試し期間が始まりました | ○ |  |
| `store.unverified` | 購入を確認できませんでした。しばらくしてから「購入を復元」をお試しください | en | 購入を確かめられませんでした。しばらく待ってから「購入を復元」をお試しください | ○ |  |
|  |  | zh-Hans・zh-Hant | 購入を確かめられません。しばらくしてから「購入を復元」をお試しください | ○ |  |
|  |  | ko | 購入を確かめられませんでした。しばらくしてから「購入の復元」をお試しください | ○ |  |
|  |  | fr | 購入を確かめられません。少し待ってから「購入を復元」を試してください | ○ |  |
|  |  | de | 購入を確認できませんでした。少し待ってから「購入を復元」をお試しください | ○ |  |
|  |  | es | 購入を検証できませんでした。少し待ってから「購入を復元」を試してください | ○ |  |
|  |  | it | 購入を検証できません。少し待ってから「購入を復元」を試してください | ○ |  |
|  |  | pt-BR | 購入を確かめられませんでした。少し待ってから「購入を復元」を試してください | ○ |  |
| `sync.footer.accountMismatch` | この端末の手書きは、前に同期していた iCloud アカウントのものです。「新しいアカウントで使い始める」から選んでください。 | en・ko・it | この端末の手書きは、以前に同期していた iCloud アカウントのものです。「新しいアカウントで始める」から選んでください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | この端末の手書きの内容は、以前に同期していた iCloud アカウントのものです。「新しいアカウントで始める」から選んでください。 | ○ |  |
|  |  | fr・de・es・pt-BR | この端末の手書きは、以前に同期していた iCloud アカウントのものです。「新しいアカウントで始める」で選んでください。 | ○ |  |
| `sync.footer.noAccount` | iCloud にサインインするとほかの端末と同期できます。手書きはこの端末の中だけに保存しています。 | en・es・it | ほかの端末と同期するには iCloud にサインインしてください。手書きはこの端末にだけ保存されます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud にログインすると、ほかの端末と同期できます。手書きの内容は今のところこの端末にだけ保存されています。 | ○ |  |
|  |  | ko | iCloud にログインすると、ほかの端末と同期できます。手書きは今この端末の中にだけ保存しています。 | ○ |  |
|  |  | fr | ほかの端末と同期するには iCloud に接続してください。手書きはこの端末にだけ保存されています。 | ○ |  |
|  |  | de | ほかの端末と同期するには iCloud にログインしてください。手書きはこの端末にだけ保存されます。 | ○ |  |
|  |  | pt-BR | ほかの端末と同期するには iCloud に接続してください。手書きはこの端末にだけ保存されます。 | ○ |  |
| `sync.footer.offline` | オフラインです。手書きはこの端末に保存され、接続が戻ると同期されます。 | en | オフラインです。手書きはこの端末に保存され、オンラインに戻ると同期します。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 今はオフラインです。手書きの内容はこの端末に保存され、接続が戻ると同期します。 | ○ |  |
|  |  | ko・fr・de・it・pt-BR | オフラインです。手書きはこの端末に保存され、接続が戻ると同期されます。 | ○ |  |
|  |  | es | 接続がありません。手書きはこの端末に保存され、接続が戻ると同期されます。 | ○ |  |
| `sync.footer.permission` | iCloud の設定でこのアプリの利用が許可されていません。 | en | iCloud の設定で、このアプリの iCloud の利用が許可されていません。 | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud の設定で、このアプリの利用が許可されていません。 | ○ |  |
|  |  | ko | iCloud の設定で、このアプリの使用が許可されていません。 | ○ |  |
|  |  | fr | iCloud の設定がこのアプリを許可していません。 | ○ |  |
|  |  | de | iCloud の設定で、このアプリは許可されていません。 | ○ |  |
|  |  | es・it・pt-BR | iCloud の設定がこのアプリの使用を許可していません。 | ○ |  |
| `sync.footer.quota` | iCloud の容量が不足しているため、手書きを同期できません。この端末には保存されています。 | en | iCloud の容量がいっぱいなので手書きを同期できません。この端末には保存されています。 | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud の容量が足りないので手書きの内容を同期できません。内容はこの端末に保存されています。 | ○ |  |
|  |  | ko | iCloud の保存容量が足りないので手書きを同期できません。この端末には保存されています。 | ○ |  |
|  |  | fr・es・it・pt-BR | iCloud の容量が足りないので同期できません。手書きはこの端末に保存されています。 | ○ |  |
|  |  | de | iCloud の容量が足りないので手書きを同期できません。この端末には保存されています。 | ○ |  |
| `sync.footer.restricted` | 手書きはこの端末の中だけに保存しています。 | en・de・es・it・pt-BR | 手書きはこの端末にだけ保存されます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容はこの端末にだけ保存されます。 | ○ |  |
|  |  | ko | 手書きはこの端末の中にだけ保存しています。 | ○ |  |
|  |  | fr | 手書きはこの端末にだけ保存されています。 | ○ |  |
| `sync.footer.serverError` | 手書きの同期に失敗しました。この端末には保存されています（あとで再試行します）。<br>%@ | en | 手書きを同期できませんでした。この端末には保存されています（アプリが後でもう一度試します）。<br>%@ | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容の同期に失敗しました。内容はこの端末に保存されています（後でもう一度試します）。<br>%@ | ○ |  |
|  |  | ko | 手書きの同期に失敗しました。この端末には保存されています（後でもう一度試します）。<br>%@ | ○ |  |
|  |  | fr・it | 同期に失敗しました。手書きはこの端末に保存されています（後でもう一度試します）。<br>%@ | ○ |  |
|  |  | de | 同期に失敗しました。手書きはこの端末には保存されています（後でもう一度試します）。<br>%@ | ○ |  |
|  |  | es・pt-BR | 同期できませんでした。手書きはこの端末に保存されています（後でもう一度試します）。<br>%@ | ○ |  |
| `sync.footer.synced` | 手書きはこの端末と、あなたの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きが見られます。 | en | 手書きはこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きを見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容はこの端末とあなたの iCloud に保存されます。ほかの iPad や iPhone でも同じ手書きの内容を見られます。 | ○ |  |
|  |  | ko | 手書きはこの端末とユーザーの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きを見られます。 | ○ |  |
|  |  | fr | 手書きはこの端末とあなたの iCloud に保存されています。ほかの iPad や iPhone でも見られます。 | ○ |  |
|  |  | de | 手書きはこの端末とあなたの iCloud に保存されています。同じ手書きをほかの iPad や iPhone でも見られます。 | ○ |  |
|  |  | es・it・pt-BR | 手書きはこの端末とあなたの iCloud に保存されています。ほかの iPad や iPhone でも同じ手書きを見られます。 | ○ |  |
| `sync.footer.syncing` | 書いた手書きを iCloud へ送っています。 | en・de | 手書きを iCloud に送っています。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 手書きの内容を iCloud に送っています。 | ○ |  |
|  |  | ko | 書いた手書きを iCloud に送っています。 | ○ |  |
|  |  | fr・es・it・pt-BR | 手書きを iCloud へ送っています。 | ○ |  |
| `sync.footer.unknown` | 「設定」アプリで iCloud を確認してください。手書きはこの端末の中だけに保存しています。 | en・it・pt-BR | 設定アプリで iCloud を確かめてください。手書きはこの端末にだけ保存されます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 「設定」アプリで iCloud を確かめてください。手書きの内容は今のところこの端末にだけ保存されています。 | ○ |  |
|  |  | ko | 設定アプリで iCloud を確かめてください。手書きは今この端末の中にだけ保存しています。 | ○ |  |
|  |  | fr | 設定アプリで iCloud を確かめてください。手書きはこの端末にだけ保存されています。 | ○ |  |
|  |  | de | 「設定」アプリで iCloud を確かめてください。手書きはこの端末にだけ保存されます。 | ○ |  |
|  |  | es | 設定（Ajustes／Configuración）アプリで iCloud を確かめてください。手書きはこの端末にだけ保存されます。 | △ |  |
| `sync.header.error` | エラー | 全部 | エラー | ○ |  |
| `sync.header.localOnly` | この端末のみ | 全部 | この端末のみ | ○ |  |
| `sync.header.offline` | オフライン | en・zh-Hans・zh-Hant・ko・fr・de・it・pt-BR | オフライン | ○ |  |
|  |  | es | 接続なし | ○ |  |
| `sync.header.saved` | 保存済み | 全部 | 保存済み | ○ |  |
| `sync.header.stopped` | 停止中 | en・ko・fr・de・es・pt-BR | 停止 | ○ |  |
|  |  | zh-Hans・zh-Hant | 停止しました | ○ |  |
|  |  | it | 中断 | ○ |  |
| `sync.header.syncing` | 同期中 | en・zh-Hans・zh-Hant・ko・de・es・pt-BR | 同期中 | ○ |  |
|  |  | fr・it | 同期中（略）… | ○ |  |
| `sync.status.accountMismatch` | 別の iCloud アカウントです | en・fr・de・es・it・pt-BR | 別の iCloud アカウント | ○ |  |
|  |  | zh-Hans・zh-Hant | これは別の iCloud アカウントです | ○ |  |
|  |  | ko | 別の iCloud アカウントです | ○ |  |
| `sync.status.noAccount` | iCloud にサインインしていません | en・it | iCloud にサインインしていません | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・de | iCloud にログインしていません | ○ |  |
|  |  | fr・pt-BR | iCloud に接続していません | ○ |  |
|  |  | es | iCloud のセッションなし（サインインしていない） | ○ |  |
| `sync.status.offline` | オフライン | en・zh-Hans・zh-Hant・ko・fr・de・it・pt-BR | オフライン | ○ |  |
|  |  | es | 接続なし | ○ |  |
| `sync.status.permission` | iCloud を使えません | 全部 | iCloud を使えません | ○ |  |
| `sync.status.quota` | iCloud の容量が足りません | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | iCloud の容量が足りません | ○ |  |
|  |  | ko | iCloud の保存容量が足りません | ○ |  |
| `sync.status.restricted` | この端末では iCloud が制限されています | en・ko・fr・de・es・it・pt-BR | この端末では iCloud が制限されています | ○ |  |
|  |  | zh-Hans・zh-Hant | この端末の iCloud は制限されています | ○ |  |
| `sync.status.serverError` | 同期に失敗しました | en・zh-Hans・zh-Hant・de・it | 同期に失敗しました | ○ |  |
|  |  | ko・fr・pt-BR | 同期の失敗 | ○ |  |
|  |  | es | 同期のエラー | ○ |  |
| `sync.status.synced` | 同期済み | 全部 | 同期済み | ○ |  |
| `sync.status.syncing` | 同期中… | 全部 | 同期しています… | ○ |  |
| `sync.status.unknown` | iCloud を確認できません | 全部 | iCloud を確かめられません | ○ |  |
| `toast.eraseCloudFailed` | iCloud の手書きを消せませんでした。この端末の分は消しました。回線が戻ったらもう一度お試しください | en・de | iCloud の手書きを消せませんでした。この端末の手書きは消えました。オンラインに戻ったらもう一度お試しください | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud の手書きの内容を消せません。この端末の内容は消しました。ネットワークが戻ったらもう一度お試しください | ○ |  |
|  |  | ko | iCloud の手書きを消せませんでした。この端末の手書きは消しました。インターネットにまた接続したらもう一度お試しください | ○ |  |
|  |  | fr・it | iCloud の手書きを消せません。この端末の手書きは消えました。接続が戻ったらやり直してください | ○ |  |
|  |  | es・pt-BR | iCloud の手書きを消せませんでした。この端末の手書きは消えました。接続が戻ったらもう一度お試しください | ○ |  |
| `toast.erased` | 手書きを全て消しました | en・fr・de・es・it・pt-BR | すべての手書きを消しました | ○ |  |
|  |  | zh-Hans・zh-Hant | すべての手書きの内容を消しました | ○ |  |
|  |  | ko | 手書きをすべて消しました | ○ |  |
| `toast.event.created` | 予定を登録しました | 全部 | 予定を追加しました | ○ |  |
| `toast.event.deleted` | 予定を削除しました | en・zh-Hans・zh-Hant・ko・fr・de・es・it | 予定を削除しました | ○ |  |
|  |  | pt-BR | 予定を消しました | ○ |  |
| `toast.event.noAccess` | 予定を登録するには、設定でカレンダーへのアクセスを許可してください | en・ko・fr・de・it・pt-BR | 予定を追加するには、設定でカレンダーへのアクセスを許可してください | ○ |  |
|  |  | zh-Hans | 予定を追加するには、「設定」でカレンダーへのアクセスを許可してください | ○ |  |
|  |  | zh-Hant | 予定を追加するには、「設定」でカレンダーの利用を許可してください | ○ |  |
|  |  | es | イベントを追加するには、設定（Configuración）でカレンダーへのアクセスを許可してください | △ |  |
| `toast.event.noCalendar` | 予定を登録できるカレンダーがありません | en・de | 新しい予定を入れられるカレンダーがありません | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | 予定を追加できるカレンダーがありません | ○ |  |
|  |  | fr | 予定を受け入れられるカレンダーがありません | ○ |  |
|  |  | es・pt-BR | 新しい予定を受け付けるカレンダーがありません | ○ |  |
|  |  | it | 新しい予定を受け取れるカレンダーがありません | ○ |  |
| `toast.event.updated` | 予定を更新しました | 全部 | 予定を更新しました | ○ |  |
| `toast.eventBelowDay` | 24 時の下の自由メモ欄では予定を作れません | en | 24:00 より下の自由メモの部分には予定を作れません | ○ |  |
|  |  | zh-Hans・zh-Hant | 24 時より下の自由メモの欄には予定を作れません | ○ |  |
|  |  | ko | 24 時より下の自由メモの欄では予定を作れません | ○ |  |
|  |  | fr・de・es・it・pt-BR | 24:00 より下の自由メモには予定を作れません | ○ |  |
| `toast.growthCap` | メモ欄はここまでです | en | ここがメモの部分の終わりです | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | メモの欄はここまでです | ○ |  |
|  |  | fr・de・es・it・pt-BR | メモの部分はここで終わりです | ○ |  |
| `toast.pinchHint` | 2 本の指を広げると拡大、つまむと縮小します | en・fr | 2 本の指を広げると拡大、つまむと縮小します | ○ |  |
|  |  | zh-Hans・zh-Hant | 2 本の指を開くと拡大、2 本の指でつまむと縮小します | ○ |  |
|  |  | ko | 2 本の指を広げると拡大、すぼめると縮小します | ○ |  |
|  |  | de | 2 本の指を広げると拡大、寄せると縮小します | ○ |  |
|  |  | es | 2 本の指を離すと拡大、寄せると縮小します | ○ |  |
|  |  | it | 2 本の指を広げると拡大、近づけると縮小します | ○ |  |
|  |  | pt-BR | 2 本の指を離すと拡大、近づけると縮小します | ○ |  |
| `toast.readOnly` | 閲覧専用です。書く・消す・予定を作るには購読が必要です | en | 閲覧のみです。書く・消す・予定を作るには購読してください | ○ |  |
|  |  | zh-Hans・zh-Hant | 閲覧のみ。書く・消す・予定の作成には購読が必要です | ○ |  |
|  |  | ko | 閲覧専用です。書く・消す・予定の作成には購読が必要です | ○ |  |
|  |  | fr・es・it・pt-BR | 読み取り専用。書く・消す・予定を作るには購読してください | ○ |  |
|  |  | de | 見るだけ。書く・消す・予定の作成には購読が必要です | ○ |  |
| `toast.strokeBudget.full` | このページはいっぱいです（線 %@ 本）。線を消すと、また書けます。 | en・fr・de・es・it・pt-BR | このページはいっぱいです（%@ 本）。もう一度書くには線を消してください。 | ○ |  |
|  |  | zh-Hans・zh-Hant | このページは書き尽くしました（%@ 本の線）。線をいくらか消すと続けて書けます。 | ○ |  |
|  |  | ko | このページはいっぱいです（線 %@ 本）。線を消すとまた書けます。 | ○ |  |
| `toast.strokeBudget.many` | このページに書いた線が %1$@ 本を超えました。1 ページに書ける線は %2$@ 本までです。 | en | このページの線が %1$@ 本を超えました。1 ページに %2$@ 本まで入ります。 | ○ |  |
|  |  | zh-Hans・zh-Hant | このページの線が %1$@ 本を超えました。1 ページに %2$@ 本まで書けます。 | ○ |  |
|  |  | ko | このページの線が %1$@ 本を超えました。1 ページに書ける線は %2$@ 本までです。 | ○ |  |
|  |  | fr・it・pt-BR | このページは %1$@ 本を超えました。1 ページに %2$@ 本まで入ります。 | ○ |  |
|  |  | de・es | このページの線は %1$@ 本を超えました。1 ページに %2$@ 本まで入ります。 | ○ |  |
| `toast.weekStart.adopted.monday` | iCloud の手書きに合わせて、週の始まりを月曜にしました。設定で変えられます。 | en・de | iCloud の手書きに合わせて、週の始まりを月曜にしました。設定で変えられます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud の手書きの内容に合わせて週の最初の日を月曜にしました。設定で変えられます。 | ○ |  |
|  |  | ko | iCloud の手書きに合わせて、週の最初の日を月曜に設定しました。設定で変えられます。 | ○ |  |
|  |  | fr・it・pt-BR | iCloud の手書きに合わせて、週を月曜に設定しました。設定で変えられます。 | △ |  |
|  |  | es | iCloud のあなたの手書きに従って、週は月曜日に始まります。設定で変更できます。 | △ |  |
| `toast.weekStart.adopted.sunday` | iCloud の手書きに合わせて、週の始まりを日曜にしました。設定で変えられます。 | en・de | iCloud の手書きに合わせて、週の始まりを日曜にしました。設定で変えられます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | iCloud の手書きの内容に合わせて週の最初の日を日曜にしました。設定で変えられます。 | ○ |  |
|  |  | ko | iCloud の手書きに合わせて、週の最初の日を日曜に設定しました。設定で変えられます。 | ○ |  |
|  |  | fr・it・pt-BR | iCloud の手書きに合わせて、週を日曜に設定しました。設定で変えられます。 | △ |  |
|  |  | es | iCloud のあなたの手書きに従って、週は日曜日に始まります。設定で変更できます。 | △ |  |
| `toast.weekStart.hiddenInk.one` | この月のページには、いまの週の始まりでは表示されない日に書いた線が %@ 本あります。消えていません。週の始まりを戻すと見えます。 | en | この月のページの %@ 本の線は、今の週の始まりでは隠れる日にあります。削除されていません。切り替えて戻すと見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | この月のページには、今の設定では表示されない日付に %@ 本の線があります。線は消えていません。週の最初の日を元に戻すと見られます。 | △ |  |
|  |  | ko | この月のページには、今の設定で見えない日に書いた線が %@ 本あります。消えていません。戻すと見えます。 | △ |  |
|  |  | fr | このページには、今の設定で隠れている日に %@ 本の線があります。削除されていません。見るには設定を戻してください。 | △ |  |
|  |  | de | この月のページには、隠れた日に %@ 本の線があります。削除されていません。切り替えて戻すと現れます。 | △ |  |
|  |  | es | この月のページには、今の設定で隠れている日に %@ 本の線があります。削除されていません。変えるとまた見えます。 | △ |  |
|  |  | it | このページには、今の設定で隠れている日に %@ 本の線があります。削除されていません。設定を変えるとまた見えます。 | △ |  |
|  |  | pt-BR | この月のページには、今の設定で隠れている日に %@ 本の線があります。消えていません。設定を変えると戻ります。 | △ |  |
| `toast.weekStart.hiddenInk.other` | この月のページには、いまの週の始まりでは表示されない日に書いた線が %@ 本あります。消えていません。週の始まりを戻すと見えます。 | en | この月のページの %@ 本の線は、今の週の始まりでは隠れる日にあります。削除されていません。切り替えて戻すと見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | この月のページには、今の設定では表示されない日付に %@ 本の線があります。線は消えていません。週の最初の日を元に戻すと見られます。 | △ |  |
|  |  | ko | この月のページには、今の設定で見えない日に書いた線が %@ 本あります。消えていません。戻すと見えます。 | △ |  |
|  |  | fr | このページには、今の設定で隠れている日に %@ 本の線があります。削除されていません。見るには設定を戻してください。 | △ |  |
|  |  | de | この月のページには、隠れた日に %@ 本の線があります。削除されていません。切り替えて戻すと現れます。 | △ |  |
|  |  | es | この月のページには、今の設定で隠れている日に %@ 本の線があります。削除されていません。変えるとまた見えます。 | △ |  |
|  |  | it | このページには、今の設定で隠れている日に %@ 本の線があります。削除されていません。設定を変えるとまた見えます。 | △ |  |
|  |  | pt-BR | この月のページには、今の設定で隠れている日に %@ 本の線があります。消えていません。設定を変えると戻ります。 | △ |  |
| `toast.weekStart.otherForm.one` | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | en | %2$@ の週のページは、もう一方の週の始まり（%1$@）を使っています。削除されていません。設定 > 週の始まり で切り替えると見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %2$@ の週のページは、もう一方の週の最初の日（%1$@）を使っています。消えていません。「設定」> 週の最初の日 で切り替えると見られます。 | ○ |  |
|  |  | ko | もう一方の週の最初の日（%1$@）の週のページが %2$@ あります。消えていません。設定 > 週の最初の日 で切り替えると見えます。 | ○ |  |
|  |  | fr | 週のページが %2$@ ページ（最初の日: %1$@）、削除されていません。見るには：設定 > 週の最初の日。 | △ |  |
|  |  | de | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ |  |
|  |  | es | %2$@ の週のページは、もう一方の最初の日（%1$@）を使っています。削除されていません。見るには: 設定 > 週の最初の日。 | ○ |  |
|  |  | it | 開始が %1$@ の週間ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △（2 回目） |  |
|  |  | pt-BR | 別の始まり（%1$@）の週のページが %2$@ ページ、消去されていません。見るには：設定 > 週の最初の日。 | △ |  |
| `toast.weekStart.otherForm.other` | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | en | %2$@ の週のページは、もう一方の週の始まり（%1$@）を使っています。削除されていません。設定 > 週の始まり で切り替えると見られます。 | ○ |  |
|  |  | zh-Hans・zh-Hant | %2$@ の週のページは、もう一方の週の最初の日（%1$@）を使っています。消えていません。「設定」> 週の最初の日 で切り替えると見られます。 | ○ |  |
|  |  | ko | もう一方の週の最初の日（%1$@）の週のページが %2$@ あります。消えていません。設定 > 週の最初の日 で切り替えると見えます。 | ○ |  |
|  |  | fr | 週のページが %2$@ ページ（最初の日: %1$@）、削除されていません。見るには：設定 > 週の最初の日。 | △ |  |
|  |  | de | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ |  |
|  |  | es | %2$@ の週のページは、もう一方の最初の日（%1$@）を使っています。削除されていません。見るには: 設定 > 週の最初の日。 | ○ |  |
|  |  | it | 開始が %1$@ の週間ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △（2 回目） |  |
|  |  | pt-BR | 別の始まり（%1$@）の週のページが %2$@ ページ、消去されていません。見るには：設定 > 週の最初の日。 | △ |  |
| `toast.weekStart.regionChanged.monday` | 端末の地域に合わせて、週の始まりを月曜にしました。日曜始まりの週の手書きは消えていません。 | en・de | 端末の地域に合わせて、週の始まりを月曜にしました。日曜始まりの週の手書きは削除されていません。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 端末の地域に合わせて週の最初の日を月曜にしました。日曜始まりの週の手書きの内容は消えていません。 | ○ |  |
|  |  | ko | 端末の地域に合わせて、週の最初の日を月曜に設定しました。日曜始まりの週の手書きは消えていません。 | ○ |  |
|  |  | fr・it | 端末の地域に合わせて、週を月曜に設定しました。日曜の週の手書きは削除されていません。 | △ |  |
|  |  | es | デバイスの地域に従って、週は月曜日に始まります。あなたの日曜日の週の書き込みは削除されていません。 | △ |  |
|  |  | pt-BR | デバイスの地域により、週は月曜日に始まります。日曜日の週の書き込みは消去されていません。 | △ |  |
| `toast.weekStart.regionChanged.sunday` | 端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは消えていません。 | en・de | 端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは削除されていません。 | ○ |  |
|  |  | zh-Hans・zh-Hant | 端末の地域に合わせて週の最初の日を日曜にしました。月曜始まりの週の手書きの内容は消えていません。 | ○ |  |
|  |  | ko | 端末の地域に合わせて、週の最初の日を日曜に設定しました。月曜始まりの週の手書きは消えていません。 | ○ |  |
|  |  | fr・it | 端末の地域に合わせて、週を日曜に設定しました。月曜の週の手書きは削除されていません。 | △ |  |
|  |  | es | デバイスの地域に従って、週は日曜日に始まります。あなたの月曜日の週の書き込みは削除されていません。 | △ |  |
|  |  | pt-BR | デバイスの地域により、週は日曜日に始まります。月曜日の週の書いたものは消されていません。 | △ |  |
| `toolbar.badge.marker` | マーカー・%@ | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | マーカー、%@ | ○ |  |
|  |  | fr | マーカー（フェルトペン）、%@ | △ |  |
| `toolbar.badge.pen` | ペン・%@ | 全部 | ペン、%@ | ○ |  |
| `toolbar.badge.penWidth` | ペン・%1$@・%2$@ | 全部 | ペン、%1$@、%2$@ | ○ |  |
| `toolbar.collapse.spoken` | ツールバーをしまう | en・ko・es・pt-BR | ツールバーを隠す | △ |  |
|  |  | zh-Hans・zh-Hant | ツールバーをしまう | ○ |  |
|  |  | fr・it | ツールバーを小さくする | △ |  |
|  |  | de | ツールバーを隠す | ○ |  |
| `toolbar.collapse.title` | しまう | en・ko・es・pt-BR | 隠す | △ |  |
|  |  | zh-Hans・zh-Hant | しまう | ○ |  |
|  |  | fr・it | 小さくする | △ |  |
|  |  | de | 置く（下ろす・しまう） | △ |  |
| `toolbar.color.black` | 黒 | 全部 | 黒 | ○ |  |
| `toolbar.color.blue` | 青 | 全部 | 青 | ○ |  |
| `toolbar.color.green` | 緑 | 全部 | 緑 | ○ |  |
| `toolbar.color.lightBlue` | 水色 | en・zh-Hans・zh-Hant・it | 水色 | ○ |  |
|  |  | ko | 空色 | ○ |  |
|  |  | fr・de・es・pt-BR | 水色（明るい青） | ○ |  |
| `toolbar.color.orange` | オレンジ | 全部 | オレンジ | ○ |  |
| `toolbar.color.pink` | ピンク | 全部 | ピンク | ○ |  |
| `toolbar.color.purple` | 紫 | 全部 | 紫 | ○ |  |
| `toolbar.color.red` | 赤 | 全部 | 赤 | ○ |  |
| `toolbar.color.unknown` | その他の色 | en・fr・de・es・it・pt-BR | ほかの色 | ○ |  |
|  |  | zh-Hans・zh-Hant・ko | その他の色 | ○ |  |
| `toolbar.color.yellow` | 黄 | 全部 | 黄 | ○ |  |
| `toolbar.dock.hint.toLeft` | 長押しで、左下へ移すか、ツールバーをいつも出すかを選べます | en・zh-Hans・zh-Hant | 長押しで左下へ移すか、ツールバーを常に表示します | ○ |  |
|  |  | ko | 長押しすると左下へ移すか、ツールバーを常に表示できます | ○ |  |
|  |  | fr | 指を押したままにすると、左下へ移すか、ツールバーを常に表示します | ○ |  |
|  |  | de・es・it | 押したままにすると、左下へ移すか、ツールバーを常に表示します | ○ |  |
|  |  | pt-BR | タッチしたまま押し続けると、左下へ移すか、ツールバーを常に表示します | ○ |  |
| `toolbar.dock.hint.toRight` | 長押しで、右下へ移すか、ツールバーをいつも出すかを選べます | en・zh-Hans・zh-Hant | 長押しで右下へ移すか、ツールバーを常に表示します | ○ |  |
|  |  | ko | 長押しすると右下へ移すか、ツールバーを常に表示できます | ○ |  |
|  |  | fr | 指を押したままにすると、右下へ移すか、ツールバーを常に表示します | ○ |  |
|  |  | de・es・it | 押したままにすると、右下へ移すか、ツールバーを常に表示します | ○ |  |
|  |  | pt-BR | タッチしたまま押し続けると、右下へ移すか、ツールバーを常に表示します | ○ |  |
| `toolbar.dock.spoken` | ツールバーを出す | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | ツールバーを表示 | ○ |  |
|  |  | ko | ツールバーの表示 | ○ |  |
| `toolbar.fingerToggle` | 指でも書く | en・de・es | 指で描く | ○ |  |
|  |  | zh-Hans・zh-Hant・ko・fr・it | 指で書く | ○ |  |
|  |  | pt-BR | 指で線を引く | △ |  |
| `toolbar.fingerToggle.hint` | オンにすると指でも線が引けます。オフのときは指でスクロールとタップをします | en | オンのときは、指でも線を引けます。オフのときは、指でスクロールとタップをします | ○ |  |
|  |  | zh-Hans・zh-Hant | オンにすると、指でも線を引けます。オフのときは、指はスクロールとタップに使います | ○ |  |
|  |  | ko | オンにすると指でも線を引けます。オフにすると指でスクロールとタップをします | ○ |  |
|  |  | fr・de・es・it・pt-BR | オンのときは指でも線を引けます。オフのときは指でスクロールとタップをします | ○ |  |
| `toolbar.hint.eraser` | 触れた線をまるごと消します | en・fr・de・es・it・pt-BR | 触れた線を消します | △ |  |
|  |  | zh-Hans・zh-Hant | 触れた線を 1 本まるごと消します | ○ |  |
|  |  | ko | 触れた線をまるごと消します | ○ |  |
| `toolbar.hint.eraser.toMarker` | 触れた線をまるごと消します<br>（消すとマーカーに戻ります） | en・fr・es・it・pt-BR | 触れた線を消します<br>（その後マーカーに戻ります） | △ |  |
|  |  | zh-Hans・zh-Hant | 触れた線を 1 本まるごと消します<br>（消した後マーカーに戻ります） | ○ |  |
|  |  | ko | 触れた線をまるごと消します<br>（消すとマーカーに戻ります） | ○ |  |
|  |  | de | 触れた線を消します<br>（その後またマーカー） | △ |  |
| `toolbar.hint.eraser.toPen` | 触れた線をまるごと消します<br>（消すとペンに戻ります） | en・fr・es・it・pt-BR | 触れた線を消します<br>（その後ペンに戻ります） | △ |  |
|  |  | zh-Hans・zh-Hant | 触れた線を 1 本まるごと消します<br>（消した後ペンに戻ります） | ○ |  |
|  |  | ko | 触れた線をまるごと消します<br>（消すとペンに戻ります） | ○ |  |
|  |  | de | 触れた線を消します<br>（その後またペン） | △ |  |
| `toolbar.hint.event` | なぞって予定を作ります。<br>予定をタップすると編集します | en・ko | なぞると予定を作ります。<br>予定をタップすると編集します | ○ |  |
|  |  | zh-Hans・zh-Hant | なぞって予定を作ります。<br>予定をタップすると編集できます | ○ |  |
|  |  | fr | なぞると予定（約束）を作ります。<br>タップすると編集します | △ |  |
|  |  | de | なぞると予定を作ります。<br>タップで編集 | △ |  |
|  |  | es・it・pt-BR | なぞると予定を作ります。<br>タップすると編集します | △ |  |
| `toolbar.hint.lasso` | 囲んで選びます。<br>枠の中をドラッグで動かせます | en | 囲むと選択します。<br>内側をドラッグすると動かします | ○ |  |
|  |  | zh-Hans・zh-Hant | 囲んで選択します。<br>枠の中でドラッグすると動かせます | ○ |  |
|  |  | ko | 囲んで選択します。<br>枠の中をドラッグして移します | ○ |  |
|  |  | fr | 囲むと選びます。<br>ドラッグすると動かします | △ |  |
|  |  | de | 囲むと選びます。<br>ドラッグで動かす | △ |  |
|  |  | es・it・pt-BR | 囲むと選択します。<br>ドラッグすると動かします | △ |  |
| `toolbar.moveEdge.toLeft` | 左下へ移す | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 左下へ移す | ○ |  |
|  |  | de | 左下へ | △ |  |
| `toolbar.moveEdge.toRight` | 右下へ移す | en・zh-Hans・zh-Hant・ko・fr・es・it・pt-BR | 右下へ移す | ○ |  |
|  |  | de | 右下へ | △ |  |
| `toolbar.pin` | ツールバーをいつも出す | en・zh-Hans・zh-Hant・ko・fr・de | ツールバーを常に表示 | ○ |  |
|  |  | es・it・pt-BR | バーを常に表示 | ○ |  |
| `toolbar.redo` | やり直す | en・zh-Hans・zh-Hant・es・pt-BR | やり直す | ○ |  |
|  |  | ko | やり直し | ○ |  |
|  |  | fr | やり直す（元に戻す前へ戻す） | ○ |  |
|  |  | de・it | 繰り返す（やり直す） | ○ |  |
| `toolbar.tool.eraser` | 消しゴム | 全部 | 消しゴム | ○ |  |
| `toolbar.tool.event` | 予定 | en・zh-Hans・zh-Hant・ko・de・es・it・pt-BR | 予定 | ○ |  |
|  |  | fr | 予定（約束の略） | △ |  |
| `toolbar.tool.lasso` | 投げなわ | 全部 | 投げなわ | ○ |  |
| `toolbar.tool.marker` | マーカー | en・zh-Hans・zh-Hant・ko・de・it | マーカー | ○ |  |
|  |  | fr | マーカー（フェルトペン） | △ |  |
|  |  | es・pt-BR | 印を付ける（動詞の形。道具の名前「マーカー」の短い形） | △ |  |
| `toolbar.tool.pen` | ペン | 全部 | ペン | ○ |  |
| `toolbar.undo` | 元に戻す | en・zh-Hans・zh-Hant・ko・es・pt-BR | 元に戻す | ○ |  |
|  |  | fr | 取り消す（Annuler。「キャンセル」と同じ語で、元に戻す の意味） | ○ |  |
|  |  | de | 取り消す（元に戻す） | ○ |  |
|  |  | it | 取り消す（Annulla。「キャンセル」と同じ語で、元に戻す の意味） | ○ |  |
| `toolbar.width.medium` | 中 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 中 | ○ |  |
|  |  | ko | 普通 | ○ |  |
| `toolbar.width.spoken` | 太さ: %@ | 全部 | 太さ: %@ | ○ |  |
| `toolbar.width.thick` | 太 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 太 | ○ |  |
|  |  | ko | 太く | ○ |  |
| `toolbar.width.thin` | 細 | en・zh-Hans・zh-Hant・de・es・it・pt-BR | 細 | ○ |  |
|  |  | ko | 細く | ○ |  |
|  |  | fr | 細（Fin。「終了」と同じ綴りの語） | △ |  |

## 10. 検証の後に FIX が変えた字

6 観点の検証（言葉の観点）の指摘で FIX が変えた字です。次の 3 つの表の「逆翻訳（FIX）」は、FIX が日本語の元を読んで書いたものです。**2026-11-05 に、別の Claude が日本語の元と前の逆翻訳を見ずに、アプリの 25 件・ストアの 5 欄・英語の 3 文の今の字を訳し戻しました。** その逆翻訳と判定は、この節の「元を見ない逆翻訳と判定」にあります。`docs/i18n/back/<言語>.json` と `docs/i18n/back/legal-en.md` の該当の行も、今はこの逆翻訳です（de の `otherForm` と pt-BR の `regionChanged.sunday` はその後のもう 1 回〔R4〕の逆翻訳）。`docs/i18n/back/store-*.md` の行は、de-DE の `whatsnew.txt` だけが R4 の逆翻訳で、ほかは FIX の字のままです。**R4 の後に直した fr の `otherForm` の 2 件と de-DE の `whatsnew.txt` の 2 か所は、元を見ない逆翻訳を通っていません**（この節の最後の表）。

### アプリの文字列

| キー | 言語 | 前の字 | 今の字 | 逆翻訳（FIX） | 変えた理由 |
| --- | --- | --- | --- | --- | --- |
| `kit.plan.savings.one` | es | Ahorra %@ mes | Ahorre %@ mes | %@ か月分節約 | tú の命令形にも読める。§6.1 の 1 の usted にそろえた |
| `kit.plan.savings.other` | es | Ahorra %@ meses | Ahorre %@ meses | %@ か月分節約 | 同じ |
| `toast.weekStart.adopted.monday` | es | Semanas puestas en lunes según su escritura a mano de iCloud. Puede cambiarlo en Ajustes. | La semana empieza en lunes según su escritura a mano de iCloud. Puede cambiarlo en Ajustes. | iCloud の手書きに合わせて、週は月曜に始まります。設定で変えられます。 | 「週を月曜に置いた」という直訳調 |
| `toast.weekStart.adopted.sunday` | es | Semanas puestas en domingo según su escritura a mano de iCloud. Puede cambiarlo en Ajustes. | La semana empieza en domingo según su escritura a mano de iCloud. Puede cambiarlo en Ajustes. | iCloud の手書きに合わせて、週は日曜に始まります。設定で変えられます。 | 同じ |
| `toast.weekStart.regionChanged.monday` | es | Semanas puestas en lunes según la región del dispositivo. Su escritura de las semanas de domingo no se ha eliminado. | La semana empieza en lunes según la región del dispositivo. Su escritura de las semanas de domingo no se ha eliminado. | 端末の地域に合わせて、週は月曜に始まります。日曜の週の手書きは削除されていません。 | 同じ |
| `toast.weekStart.regionChanged.sunday` | es | Semanas puestas en domingo según la región del dispositivo. Su escritura de las semanas de lunes no se ha eliminado. | La semana empieza en domingo según la región del dispositivo. Su escritura de las semanas de lunes no se ha eliminado. | 端末の地域に合わせて、週は日曜に始まります。月曜の週の手書きは削除されていません。 | 同じ |
| `toast.event.noAccess` | es | Para añadir eventos, permita el acceso a los calendarios en Ajustes | Para añadir eventos, permita el acceso a los calendarios en Ajustes (Configuración) | 予定を追加するには、設定（Ajustes／Configuración）でカレンダーへのアクセスを許可してください | `notice.calendar.denied` と同じ Ajustes (Configuración) に |
| `toast.weekStart.regionChanged.monday` | pt-BR | Semanas na segunda-feira conforme a região do dispositivo. Sua escrita das semanas de domingo não foi apagada. | A semana começa na segunda-feira pela região do dispositivo. A escrita das semanas de domingo não foi apagada. | 端末の地域により、週は月曜に始まります。日曜の週の手書きは消えていません。 | 動詞が無かった |
| `toast.weekStart.regionChanged.sunday` | pt-BR | Semanas no domingo conforme a região do dispositivo. Sua escrita das semanas de segunda não foi apagada. | A semana começa no domingo pela região do dispositivo. A escrita das semanas de segunda-feira não foi apagada. | 端末の地域により、週は日曜に始まります。月曜の週の手書きは消えていません。 | 同じ。2026-11-05 に de segunda を de segunda-feira にした（単独では「第 2 の」とも読めると訳者が注をつけたため） |
| `event.scribbleNote` | pt-BR | Escreva sobre o campo com o Apple Pencil para virar texto (Escrever à Mão) | Escreva sobre o campo com o Apple Pencil para converter em texto (Escrever à Mão) | Apple Pencil で欄の上に書くと文字に変換されます（手書き入力） | para virar texto は口語 |
| `event.titlePlaceholder` | pt-BR | Escreva aqui com a caneta para virar texto | Escreva aqui com a caneta para converter em texto | ここにペンで書くと文字に変換されます | 同じ |
| `toast.weekStart.otherForm.one` | pt-BR | %2$@ página da semana usa o outro primeiro dia (%1$@). Não foi apagada. Para vê-la: Ajustes > Primeiro dia da semana. | %2$@ página da semana com outro início (%1$@), não apagada. Para vê-la: Ajustes > Primeiro dia da semana. | %2$@ の週のページは別の始まり（%1$@）で、消えていません。見るには: 設定 > 週の最初の日。 | 375 pt で 3 行に |
| `toast.weekStart.otherForm.other` | pt-BR | %2$@ páginas da semana usam o outro primeiro dia (%1$@). Não foram apagadas. Para vê-las: Ajustes > Primeiro dia da semana. | %2$@ páginas da semana com outro início (%1$@), não apagadas. Para vê-las: Ajustes > Primeiro dia da semana. | %2$@ の週のページは別の始まり（%1$@）で、消えていません。見るには: 設定 > 週の最初の日。 | 同じ（4 行で「設定の道」が切れていた） |
| `settings.purchase.footer.cancel` | zh-Hans | 如需取消，请前往设备上的%@。取消后，你仍可使用到期末。 | 如需取消，请前往设备上的%@。取消后，你仍可使用到当前周期结束。 | 解約するには、端末の%@へ進んでください。解約後も、今の期間の終わりまで使えます。 | 「到期末」は学期末のようにも読める。`paywall.disclosure.*` の「当前周期结束」にそろえた |
| `settings.purchase.footer.trial` | zh-Hans | 如需取消，请前往设备上的%@。取消后，你仍可使用到期末。在试用期间取消不会收费。 | 如需取消，请前往设备上的%@。取消后，你仍可使用到当前周期结束。在试用期间取消不会收费。 | 解約するには、端末の%@へ進んでください。解約後も、今の期間の終わりまで使えます。お試しの間に解約すれば課金されません。 | 同じ |
| `onboarding.access.text` | zh-Hans | 下一屏幕将请求日历的“完全访问”权限，用于在手帐页面上显示日程，以及根据手写内容创建日程。<br><br>iOS 和 iPadOS 没有只读权限，因此需要“完全访问”。日程只在此设备上处理，不会发送给开发者或其他任何人。 | 下一个屏幕将请求日历的“完全访问”权限，用于在手帐页面上显示日程，以及根据手写内容创建日程。<br><br>iOS 和 iPadOS 没有只读权限，因此需要“完全访问”。日程只在此设备上处理，不会发送给开发者或其他任何人。 | 次の画面でカレンダーの「フルアクセス」の権限を求めます。手帳のページに予定を表示するためと、手書きの内容から予定を作るためです。<br><br>iOS と iPadOS には読み取り専用の権限がないので、「フルアクセス」が必要です。予定はこの端末の中だけで処理され、開発者にもほかの誰にも送られません。 | 「下一屏幕」→ 普通の「下一个屏幕」。逆翻訳は同じ |
| `onboarding.askPermission` | zh-Hans | 显示权限屏幕 | 显示权限请求 | 権限の要求を出す | 「显示权限屏幕」は直訳調 |
| `holidayPicker.subdivisions` | de | Bundesländer und Regionen | Regionen | 地域 | Bundesland はドイツとオーストリアの語で、米国の州などに合わない |
| `holidayPicker.subdivisionHint` | de | Wählen Sie ein Bundesland oder eine Region, um deren Feiertage hinzuzufügen | Wählen Sie eine Region, um deren Feiertage hinzuzufügen | 地域を選ぶと、その祝日が加わります | 同じ |
| `holidayPicker.subdivisions.footer` | de | Die Namen der Bundesländer und Regionen werden so angezeigt, wie sie in den Daten stehen (auf Englisch oder in der Landessprache). | Die Namen der Regionen werden so angezeigt, wie sie in den Daten stehen (auf Englisch oder in der Landessprache). | 地域の名前は、データにあるまま（英語か現地の言語で）表示されます。 | 同じ |
| `toast.weekStart.otherForm.one` | de | %2$@ Wochenseite mit anderem Wochenstart (%1$@), nicht gelöscht. Wechseln: Einstellungen > Erster Tag der Woche. | %2$@ Wochenseite mit Wochenstart %1$@, nicht gelöscht. Ansehen: Einstellungen > Erster Tag der Woche. | %2$@ の週のページは週の始まりが %1$@ で、削除されていません。切り替え: 設定 > 週の最初の日。 | 375 pt で 3 行に。今の字は 2026-11-05 に Wechseln を Ansehen に直した後の字（この節の下の表） |
| `toast.weekStart.otherForm.other` | de | %2$@ Wochenseiten mit anderem Wochenstart (%1$@), nicht gelöscht. Wechseln: Einstellungen > Erster Tag der Woche. | %2$@ Wochenseiten mit Wochenstart %1$@, nicht gelöscht. Ansehen: Einstellungen > Erster Tag der Woche. | %2$@ の週のページは週の始まりが %1$@ で、削除されていません。切り替え: 設定 > 週の最初の日。 | 同じ（4 行で「設定の道」が切れていた） |
| `toast.weekStart.otherForm.one` | it | %2$@ pagina settimanale usa l’altro primo giorno (%1$@), non eliminata. Per vederla: Impostazioni > Primo giorno della settimana. | %2$@ pagina settimanale (inizio: %1$@), non eliminata. Per vederla: Impostazioni > Primo giorno della settimana. | 週のページ %2$@ ページは始まりが %1$@ で、削除されていません。それを見るには: 設定 > 週の最初の日。 | 同じ |
| `toast.weekStart.otherForm.other` | it | %2$@ pagine settimanali usano l’altro primo giorno (%1$@), non eliminate. Per vederle: Impostazioni > Primo giorno della settimana. | %2$@ pagine settimanali (inizio: %1$@), non eliminate. Per vederle: Impostazioni > Primo giorno della settimana. | 週のページ %2$@ ページは始まりが %1$@ で、削除されていません。それらを見るには: 設定 > 週の最初の日。 | 同じ |
| `demo.event.morningMeeting` | it | Mattutina | Riunione | 会議（Riunione。「朝」にあたる語は入っていない） | Mattutina は形容詞だけで予定の名に見えにくい。10 pt で 43.5 pt（5.7 em まで） |

**今の字の × は 0 件です。** 判定は「元を見ない逆翻訳と判定」の表に、△ の理由は 8 にもあります。

幅: Mac Catalyst の字で、週の始まりのトーストは 10 言語のどの文も幅 375 − 64 = 311 pt と 402 − 64 = 338 pt で 3 行以内です（ja は FIX の測り。数は `.one` が 1、`.other` が 99。曜日は月曜）。**2026-11-05 に、R4 の後の字で ja を除く 9 言語の 8 種類を、曜日は月曜と日曜、数は `.one` が 1、`.other` が 2・9・10・99 で測り直し、504 行とも 3 行以内でした（`m7b-impl/R4/out_all.txt`）。** 前に fr の `otherForm.other` が日曜・10 ページ以上・311 pt で 4 行になった件は、e1073ae で短くして直りました（R4 の字で最後の行は 192 pt）。本当の判定は CI のシミュレータです。`testWeekStartToastsFitThreeLines` がジョブを落とす判定は 402 pt のままです。余裕の少ない文があるので（it の `hiddenInk.other` は 311 pt で最後の行が 310 pt）、375 pt はログだけにしています。

### ストアの字

| 欄 | ロケール | 今の字 | 逆翻訳（FIX） | 変えた理由 |
| --- | --- | --- | --- | --- |
| `subtitle.txt` | de-DE | Planer zum Schreiben von Hand（29 字） | 手で書くためのプランナー | 前の Handschreiben は名詞では「手書きの書簡（要人の親書など）」を指す語で、逆翻訳では見つからない語の誤りだった |
| `name.txt` の退き先 | de-DE | Tegaki: Handschrift-Planer | Tegaki: 手書きのプランナー | 前の Planer von Hand（手による手帳）は不自然 |
| `description.txt` | de-DE | Sie müssen keinen Account anlegen. | アカウントを作る必要はありません（前と同じ） | ほかの所と画面が Account なので Konto をそろえた |
| `whatsnew.txt` | de-DE | In Ländern mit Bundesländern, Bundesstaaten oder Regionen … | 州や地域のある国では…（前と同じ） | 米国の州なども読める語に |
| `whatsnew.txt` | it | se Le viene chiesto | 聞かれたら（前と同じ） | 敬称の Le は大文字（GLOSSARY の決まり） |
| `name.txt` の退き先 | fr-FR | Tegaki : agenda manuscrit（コロンの前は普通の空白） | Tegaki: 手書きの手帳（前と同じ） | 確かめずに使う案なので、Connect が受け付けるか分からない改行しない空白をやめた |

### 英語の 3 文書（`docs/i18n/back/legal-en.md` の該当の行は、今は元を見ない逆翻訳）

| 場所 | 今の字 | 逆翻訳（FIX） | 変えた理由 |
| --- | --- | --- | --- |
| `SUPPORT.en.md` の問い合わせ窓口 | If you do send them, they are deleted once your question has been dealt with (Section 12 of the Privacy Policy). | 送られた場合は、ご質問への対応が終わったら削除します（プライバシーポリシーの第 12 節）。 | 前の「保管せず、確かめた後に削除」は、Gmail に保存し対応の間は持っている第 12 節と合わなかった |
| `PRIVACY.en.md` 第 12 節の 1 つ目 | … your email address, any name you write, the text of your email and any attachments (such as screenshots). | …メールアドレス、書かれた名前、メールの本文、添付（画面の写真など）を受け取ります。 | サポートと定型文は画面の写真を頼むのに、受け取る物に無かった |
| `PRIVACY.en.md` 第 12 節の 2 つ目 | To read emails and to write replies, … the text of your email and its attachments to an AI service … | メールを読み、返事を書くために、…メールの本文と添付を AI のサービス…に渡すことがあります。 | 添付は同じ理由。「日本語以外の」と「翻訳」は、日本語のメールを渡さないと言い切れないので外した（2026-11-05、P2。この行の逆翻訳は P2 が元を見て書いた） |

日本語の元（`docs/SUPPORT.md`・`PRIVACY.md`）も同じ意味に直しました。契約 §11.3 の P-2 の案文も今の字に直しました（2026-11-05）。

### 元を見ない逆翻訳と判定（2026-11-05）

別の Claude に渡したのは今の字と言語だけで、日本語の元と前の逆翻訳は入っていません（入力は `m7b-impl/R3/input.json`、結果は `m7b-impl/R3/back.json`）。判定は、その結果と日本語の元を、訳した Claude とは別の Claude が照らしたものです。母語の人の確認ではありません。

**33 件: ○ 12・△ 19・× 2。** ストアの表の `whatsnew.txt`（de-DE）の Bundesland の文はこの入力に入っていませんでした（後の R4 の全文の逆翻訳で通しました）。`docs/i18n/back/store-*.md` の行は、de-DE の `whatsnew.txt` を除いて FIX の字のままで、この表の逆翻訳との違いは語の言い換えだけです（「手書きのプランナー」と「手書きプランナー」、「作る」と「作成する」、「聞かれたら」と「もし求められたら」）。

| 場所 | 言語 | 元の日本語 | 逆翻訳（元を見ない） | 判定 | 理由 |
| --- | --- | --- | --- | --- | --- |
| `kit.plan.savings.one` | es | %@ か月分お得 | %@か月節約してください | △ | 「お得」が「節約」の命令の形に。購入の画面の年額の札なので、得になる月数と読める（英語の Save %@ month と同じ形） |
| `kit.plan.savings.other` | es | %@ か月分お得 | %@か月節約してください | △ | 同じ |
| `toast.weekStart.adopted.monday` | es | iCloud の手書きに合わせて、週の始まりを月曜にしました。設定で変えられます。 | iCloud のあなたの手書きに従って、週は月曜日に始まります。設定で変更できます。 | △ | 「週の始まりを月曜にしました」が「週は月曜に始まります」に（3 行に入れる短い言い方、§10.4）。曜日は元と同じ。en lunes は「週の始まりの曜日」の言い方で、誤りではない（`settings.weekStart.confirm.message.*` の es も同じ形） |
| `toast.weekStart.adopted.sunday` | es | iCloud の手書きに合わせて、週の始まりを日曜にしました。設定で変えられます。 | iCloud のあなたの手書きに従って、週は日曜日に始まります。設定で変更できます。 | △ | 同じ |
| `toast.weekStart.regionChanged.monday` | es | 端末の地域に合わせて、週の始まりを月曜にしました。日曜始まりの週の手書きは消えていません。 | デバイスの地域に従って、週は月曜日に始まります。あなたの日曜日の週の書き込みは削除されていません。 | △ | 同じ短い言い方。「日曜始まりの週」が「日曜の週」で「始まり」の語は無いが、前の文が週の始まりの話なので読める。向きは元と同じ |
| `toast.weekStart.regionChanged.sunday` | es | 端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは消えていません。 | デバイスの地域に従って、週は日曜日に始まります。あなたの月曜日の週の書き込みは削除されていません。 | △ | 同じ |
| `toast.event.noAccess` | es | 予定を登録するには、設定でカレンダーへのアクセスを許可してください | イベントを追加するには、設定（Configuración）でカレンダーへのアクセスを許可してください | △ | 「設定」を Ajustes (Configuración) と両方書いた（8、GLOSSARY の 3）。「イベント」は eventos の読みで、用語集の「予定」の語。文末に句点が無いのは元と同じ |
| `toast.weekStart.regionChanged.monday` | pt-BR | 端末の地域に合わせて、週の始まりを月曜にしました。日曜始まりの週の手書きは消えていません。 | デバイスの地域により、週は月曜日に始まります。日曜日の週の書き込みは消去されていません。 | △ | 「週の始まりを月曜にしました」が「週は月曜に始まります」、「日曜始まりの週」が「日曜の週」に（3 行に入れる短い言い方）。向きは元と同じ |
| `toast.weekStart.regionChanged.sunday` | pt-BR | 端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは消えていません。 | デバイスの地域により、週は日曜日に始まります。月曜日の週の書き込みは消去されていません。 | △ | 同じ。de segunda は単独では「第 2 の」「二流の」とも読めると訳者が注をつけたが、訳者自身も「月曜の週」と読んだ。曜日の話の文なので読める（この字はこの後 de segunda-feira に変えた。今の字の判定は R4 の表） |
| `event.scribbleNote` | pt-BR | Apple Pencil で欄の上に書くと、文字に変換されます（スクリブル） | テキストに変換するには、Apple Pencil で欄の上に書いてください（手で書く） | △ | 「（スクリブル）」が Escrever à Mão（直訳は「手で書く」）。Apple の pt-BR の機能名（8、GLOSSARY の 3）。「書くと変換される」が「変換するには書いて」で、中身は同じ |
| `event.titlePlaceholder` | pt-BR | ここにペンで書くと文字になります | テキストに変換するには、ここにペンで書いてください | ○ | 「書くと文字になる」と「文字にするには書いて」で同じ。元もここは「ペン」で、Apple Pencil と書き分けている |
| `toast.weekStart.otherForm.one` | pt-BR | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | 別の始まり（%1$@）の週のページが %2$@ ページ、消去されていません。見るには：設定 > 週の最初の日。 | △ | 1 文にまとめた（375 pt で 3 行、§10.4）。「もう一方の」が「別の」、「切り替えると見えます」が「見るには: 設定 > 週の最初の日」。曜日・ページ数・消えていないことは残る |
| `toast.weekStart.otherForm.other` | pt-BR | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | 別の始まり（%1$@）の週のページが %2$@ ページ、消去されていません。見るには：設定 > 週の最初の日。 | △ | 同じ |
| `settings.purchase.footer.cancel` | zh-Hans | 解約は端末の%@から。解約しても期間の終わりまで使えます。 | キャンセルするには、デバイスの%@へ移動してください。キャンセル後も、現在の周期が終わるまで引き続き使用できます。 | ○ | 元の「期間の終わり」が「現在の周期が終わるまで」。同じ期間を指す。你 は用語集の決まり（GLOSSARY の 1） |
| `settings.purchase.footer.trial` | zh-Hans | 解約は端末の%@から。解約しても期間の終わりまで使えます。試用中に解約すれば料金はかかりません。 | キャンセルするには、デバイスの%@へ移動してください。キャンセル後も、現在の周期が終わるまで引き続き使用できます。試用期間中にキャンセルすると、料金はかかりません。 | ○ | 同じ。試用中の解約で料金がかからないことも元と同じ |
| `onboarding.access.text` | zh-Hans | 次の画面で、カレンダーへの「フルアクセス」を求めます。予定を手帳のページに表示し、手書きから予定を作るためです。<br><br>iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスになります。予定はこの端末の中だけで扱い、開発者やほかの誰にも送りません。 | 次の画面で、カレンダーの「フルアクセス」の権限を求めます。手帳のページに予定を表示するため、また手書きの内容から予定を作成するためです。<br><br>iOS と iPadOS には読み取り専用の権限がないため、「フルアクセス」が必要です。予定はこのデバイス上でのみ処理され、開発者やその他の誰にも送信されません。 | ○ | 2 段落とも元と同じ。訳者の注も無い |
| `onboarding.askPermission` | zh-Hans | 許可の画面を出す | 権限のリクエストを表示する | ○ | 「許可の画面」が「権限のリクエスト」。どちらも iOS の許可の画面を出すボタンで、動きは同じ |
| `holidayPicker.subdivisions` | de | 州・地域 | 地域 | △ | 「州」の語を落として Regionen に。国を問わない語にするため（8、GLOSSARY） |
| `holidayPicker.subdivisionHint` | de | 州・地域を選ぶと、その地域の祝日が加わります | その地域の祝日を追加するには、地域を選択してください | △ | 同じ。「選ぶと加わる」が「加えるには選んで」で、中身は同じ |
| `holidayPicker.subdivisions.footer` | de | 州・地域の名前は、データのままの表記（英語や現地の言葉）です。 | 地域の名前は、データに載っているとおりに表示されます（英語またはその国の言語で）。 | △ | 同じ。Landessprache は「その国の言語」寄りだが、元の「現地の言葉」と食い違うほどではない |
| `toast.weekStart.otherForm.one` | de | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。切り替え：設定 > 週の最初の日。 | × | **抜け。** 元の「切り替えると見えます」の「見えます」が無く、「切り替え: 設定 > …」だけで、何のために切り替えるのかが書かれていない（pt-BR・it・fr・es は「見るには」）。fr・it の 1 回目の × と同じ種類。下の表のとおり直した |
| `toast.weekStart.otherForm.other` | de | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。切り替え：設定 > 週の最初の日。 | × | 同じ |
| `toast.weekStart.otherForm.one` | it | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | 開始が %1$@ の週間ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ | 「もう一方の」が無い（375 pt で 3 行にするため。曜日が書いてあるので分かる）。「切り替えると見えます」が「見るには: 設定 > 週の最初の日」。**2 の表の ○（2 回目）は FIX が短くする前の読みだったので、△ に変えた** |
| `toast.weekStart.otherForm.other` | it | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | 開始が %1$@ の週間ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ | 同じ |
| `demo.event.morningMeeting` | it | 朝会 | 会議 | △ | 見本の語。「朝」の語は無い（8）。ストアの写真の中の語で、文として読む物ではない |
| `subtitle.txt` | de-DE | 予定の上にそのまま手書きできる手帳 | 手で書くためのプランナー | △ | 30 字に入れるため「予定の上にそのまま」を落とした（4、README の指定） |
| `name.txt` の退き先 | de-DE | Tegaki：手書きの手帳 | Tegaki：手書きプランナー | ○ | Planer は用語集の「手帳」、Handschrift は用語集の「手書き」 |
| `description.txt` のアカウントの文 | de-DE | アカウントの登録はありません。 | アカウントを作成する必要はありません。 | ○ | 「登録はありません」と「作る必要はありません」で同じ。Account は同じ文書の Kalender-Accounts・Google-Account と同じ語 |
| `whatsnew.txt` の Le の語 | it | 聞かれたら | もし求められたら | ○ | 文の断片だけを渡したので、何を聞かれるのかは訳に出ていない。全文では同じ文の中に「端末にどの言語を使うか」とある。大文字の Le は用語集の決まり |
| `name.txt` の退き先 | fr-FR | Tegaki：手書きの手帳 | Tegaki：手書きの手帳 | ○ | 元と同じ語。「手で書かれた手帳」とも読めるのは元の「手書きの手帳」も同じ |
| `SUPPORT.en.md` の問い合わせ窓口 | en | メールに、手書きの中身や予定の中身を送る必要はありません。送っていただいた場合も、問い合わせへの対応が終わったら消します（プライバシーポリシーの第 12 節）。 | 手書きや予定の内容をメールで送る必要はありません。送った場合、それらはご質問への対応が済み次第、削除されます（プライバシーポリシー第12節）。 | ○ | 元は「消します」、訳は受け身で、同じこと。「対応が済み次第」も元の「対応が終わったら」と同じ |
| `PRIVACY.en.md` 第 12 節の 1 つ目 | en | サポートにメールを送ると、開発者はあなたのメールアドレス、メールに書かれたお名前、本文、添付（画面の写真など）を受け取ります。これはアプリが集める情報ではありません。開発者は、問い合わせに答えるためだけに使います。 | サポートにメールを送ると、開発者は、あなたのメールアドレス、あなたが書いた名前、メールの本文、添付ファイル（スクリーンショットなど）を受け取ります。これはアプリが収集する情報ではありません。開発者はこれを、ご質問に答えるためだけに使います。 | ○ | 受け取る物の 4 つと使い道が同じ。差出人の名前が入るかが書かれていないのは元も同じ |
| `PRIVACY.en.md` 第 12 節の 2 つ目 | en | メールは Google の Gmail に保存されます。メールを読むときと返事を書くときは、本文や添付を AI（Anthropic の Claude）に渡すことがあります。 | メールは Google の Gmail に保存されます。メールを読むため、また返信を書くために、開発者はあなたのメールの本文と添付ファイルを AI サービス（Anthropic の Claude）に渡すことがあります。 | ○ | 同じ。読むのが開発者か AI かがはっきりしないのは元も同じ |

### 元を見ない逆翻訳の後に直した字（2026-11-05）

| キー | 言語 | 前の字 | 今の字 | 逆翻訳（判定した Claude が元を見て書いた） | 直した理由 |
| --- | --- | --- | --- | --- | --- |
| `toast.weekStart.otherForm.one` | de | %2$@ Wochenseite mit Wochenstart %1$@, nicht gelöscht. Wechseln: Einstellungen > Erster Tag der Woche. | %2$@ Wochenseite mit Wochenstart %1$@, nicht gelöscht. Ansehen: Einstellungen > Erster Tag der Woche. | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見る：設定 > 週の最初の日。 | 元の「切り替えると見えます」の「見えます」を入れた。Wechseln（切り替え）を Ansehen（見る）に。「切り替える」は設定の名前で分かる |
| `toast.weekStart.otherForm.other` | de | %2$@ Wochenseiten mit Wochenstart %1$@, nicht gelöscht. Wechseln: Einstellungen > Erster Tag der Woche. | %2$@ Wochenseiten mit Wochenstart %1$@, nicht gelöscht. Ansehen: Einstellungen > Erster Tag der Woche. | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見る：設定 > 週の最初の日。 | 元の「切り替えると見えます」の「見えます」を入れた。Wechseln（切り替え）を Ansehen（見る）に。「切り替える」は設定の名前で分かる |

**直した字は、この節の最後の R4 の表で元を見ない逆翻訳を通しました（△、× なし。理由は 8）。** 1 字短くなる直しです。幅: Mac Catalyst の字で 311 pt・338 pt とも 3 行です（数は 1 と 99、曜日は月曜と日曜。最後の行の幅は前の字以下）。本当の判定は CI-0 のシミュレータです。

### 写真の確認の後に直した見本の語（FIX3、2026-11-05）

見本の予定の名前は写真とストアにだけ出ます。CI の 1 回目の写真で切れた語を短くしました。判定は 4 件とも前と同じ △ で、合計の数（1 の表）は変わりません。

| キー | 言語 | 前の字 | 今の字 | 逆翻訳（FIX3 が元を見て書いた） | 幅（Mac Catalyst の 10 pt semibold。上限 4.2 em は 42 pt） |
| --- | --- | --- | --- | --- | --- |
| `demo.event.camping` | es | Acampar | Carpa | テント | 46.2 → 31.2 pt |
| `demo.event.camping` | pt-BR | Acampar | Tenda | テント | 46.2 → 31.5 pt |
| `demo.event.deadline` | es | Entrega | Plazo | 期限 | 40.7 → 28.5 pt（切れずに入っている pt-BR の Prazo は 29.8 pt） |
| `demo.event.deadline` | it | Termine | Scad. | 期限（scadenza の略） | 42.0 → 29.6 pt |

この 4 件は下の R5 で元を見ない逆翻訳を通しました（全部 △）。ブラジルでテントの意味なら Barraca の方がふつうです。見本の語なので、母語の人の確認が得られるまでこのままにします。

### 2 回目の写真の確認の後に直した見本の語（FIX4、2026-11-06）

CI の写真（`store-pt-BR/iphone69/02-month.jpg`）で切れた語です。判定は前と同じ △ で、合計の数（1 の表）は変わりません。**元を見ない逆翻訳は通っていません**（Chope は R5 の後の字）。見本の語で写真にだけ出ます。

| キー | 言語 | 前の字 | 今の字 | 逆翻訳（FIX4 が元を見て書いた） | 幅（Mac Catalyst の 10 pt semibold。上限 4.2 em は 42 pt） |
| --- | --- | --- | --- | --- | --- |
| `demo.event.drinks` | pt-BR | Happy hour | Chope | 生ビール（飲みに行く予定） | 60.5 → 33.6 pt |

### 元を見ない逆翻訳と判定のもう 1 回（R4、2026-11-05）

別の Claude に渡したのは、そのときの字と言語だけで、日本語の元と前の逆翻訳は入っていません（入力は `m7b-impl/R4/input.json`、結果は `m7b-impl/R4/back.json`）。判定は、その結果と日本語の元（`tools/l10n/source/app-U.json`・`docs/store/source-ja/whatsnew.txt`）を、訳した Claude とは別の Claude が照らしたものです。母語の人の確認ではありません。

**6 件: ○ 0・△ 6・× 0。** ストアの `whatsnew.txt` は全文で 1 件で、全文の判定が △ です。下の表では 1 行ずつに分けました（○ 4・△ 2）。

| 場所 | 言語 | 元の日本語 | 渡した字 | 逆翻訳（元を見ない） | 判定 | 理由 |
| --- | --- | --- | --- | --- | --- | --- |
| `toast.weekStart.otherForm.one` | de | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ Wochenseite mit Wochenstart %1$@, nicht gelöscht. Ansehen: Einstellungen > Erster Tag der Woche. | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ | 「もう一方の」が無い（曜日で分かる）。「切り替えると見えます」が「見るには: 設定 > 週の最初の日」。ページ数・曜日・消えていないこと・設定の道は残る。**R3 の × の「見えます」の抜けは直っている**。it・pt-BR と同じ形。訳者の注の「動詞が無い」「Ansehen: の置き方がやや不自然」は 3 行に入れる短さの差で、意味は違わない |
| `toast.weekStart.otherForm.other` | de | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ Wochenseiten mit Wochenstart %1$@, nicht gelöscht. Ansehen: Einstellungen > Erster Tag der Woche. | 週の始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ | 同じ。nicht gelöscht が何を指すかは語形で決まらないが、ページとしか読めない |
| `toast.weekStart.otherForm.one` | fr | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ page de semaine avec début %1$@, non supprimée. Pour la voir : Réglages > Premier jour de la semaine. | 始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ | de と同じ短い形で、意味は違わない。ただし訳者が「avec début は何の始まりか書かれておらず不自然」と注をつけたので、下の表のとおり直した。**この判定は前の字のもの。今の字の判定も △**（下の表） |
| `toast.weekStart.otherForm.other` | fr | もう一方の週の始まり（%1$@）の週のページが %2$@ ページあります。消えていません。設定 › 週の始まり で切り替えると見えます。 | %2$@ pages de semaine avec début %1$@, non supprimées. Pour les voir : Réglages > Premier jour de la semaine. | 始まりが %1$@ の週ページが %2$@ ページ、削除されていません。見るには：設定 > 週の最初の日。 | △ | 同じ |
| `toast.weekStart.regionChanged.sunday` | pt-BR | 端末の地域に合わせて、週の始まりを日曜にしました。月曜始まりの週の手書きは消えていません。 | A semana começa no domingo pela região do dispositivo. A escrita das semanas de segunda-feira não foi apagada. | デバイスの地域により、週は日曜日に始まります。月曜日の週の書いたものは消されていません。 | △ | 「週の始まりを日曜にしました」が「週は日曜に始まります」、「月曜始まりの週」が「月曜日の週」（3 行に入れる短い言い方）。向きは元と同じ。R3 の注の de segunda は segunda-feira で消えた。訳者の注の「pela região は原因とも準拠とも読める」「A escrita は手書きと限らない」は言い回しの差で、手帳のアプリの中の文として読み違えるほどではない |
| `whatsnew.txt` の 1 行目 | de-DE | ・これまでの日本語に加えて、英語、中国語（簡体字・繁体字）、韓国語、フランス語、ドイツ語、スペイン語、イタリア語、ポルトガル語で表示できるようになりました。端末の言語に合わせて切り替わります（ほかの言語の端末では英語になります）。 | • Zusätzlich zu Japanisch kann die App jetzt auf Englisch, Chinesisch (vereinfacht und traditionell), Koreanisch, Französisch, Deutsch, Spanisch, Italienisch und Portugiesisch angezeigt werden. Sie folgt der Sprache Ihres Geräts (auf Geräten mit einer anderen Sprache erscheint sie auf Englisch). | • 日本語に加えて、アプリを英語、中国語（簡体字と繁体字）、韓国語、フランス語、ドイツ語、スペイン語、イタリア語、ポルトガル語で表示できるようになりました。アプリはお使いのデバイスの言語に従います（別の言語のデバイスでは英語で表示されます）。 | ○ | 同じ。「別の言語」が挙げた言語の外を指すと書かれていないのは元も同じ |
| `whatsnew.txt` の 2 行目 | de-DE | ・アプリだけ端末と違う言語で使いたいときは、「設定」アプリ ›「アプリ」›「Tegaki」›「言語」で選んでください（iOS・iPadOS 17 では「設定」›「Tegaki」›「優先する言語」）。項目が無いときは、「設定」›「一般」›「言語と地域」で使いたい言語を追加すると出ます（追加するときに、端末の表示をどちらの言語にするか聞かれたら、今の言語のままを選んでください）。 | • Um nur für diese App eine andere Sprache zu verwenden, wählen Sie sie in der App „Einstellungen“ > „Apps“ > „Tegaki“ > „Sprache“ (bei iOS und iPadOS 17: „Einstellungen“ > „Tegaki“ > „Bevorzugte Sprache“). Fehlt der Eintrag, erscheint er, nachdem Sie unter „Einstellungen“ > „Allgemein“ > „Sprache & Region“ die gewünschte Sprache hinzugefügt haben (wenn Sie dabei gefragt werden, welche Sprache das Gerät anzeigen soll, behalten Sie die aktuelle Sprache). | • このアプリだけ別の言語を使うには、「設定」アプリ >「アプリ」>「Tegaki」>「言語」で選びます（iOS および iPadOS 17 では「設定」>「Tegaki」>「優先する言語」）。項目がない場合は、「設定」>「一般」>「言語と地域」で希望の言語を追加すると現れます（その際に、デバイスをどの言語で表示するか尋ねられたら、現在の言語のままにしてください）。 | ○ | 道も手順も同じ。「iOS und iPadOS 17」のかかり方は元の「iOS・iPadOS 17」も同じ |
| `whatsnew.txt` の 3 行目 | de-DE | ・世界の国と地域の祝日を表示できるようになりました。アプリの設定 › 祝日 ›「表示する祝日」で、国（アメリカの州などの地域も）や「なし」を選べます。州・地域のある国は、州・地域を選ぶとその地域の祝日が加わります。日本の祝日はこれまでどおりです。これまでお使いの方は、日本の祝日のままです。 | • Die App kann jetzt die Feiertage von Ländern und Regionen weltweit anzeigen. Gehen Sie in der App zu Einstellungen > Feiertage > „Angezeigte Feiertage“, um ein Land (auch eine Region, etwa einen US-Bundesstaat) oder „Keine“ zu wählen. In Ländern mit Bundesländern, Bundesstaaten oder Regionen kommen deren Feiertage dazu, wenn Sie eines davon wählen. Japanische Feiertage funktionieren wie bisher. Wenn Sie die App schon genutzt haben, zeigt sie weiter japanische Feiertage an. | • アプリは世界の国と地域の祝日を表示できるようになりました。アプリ内で 設定 > 祝日 >「表示する祝日」へ進み、国（米国の州のような地域も）または「なし」を選んでください。連邦州、州、または地域がある国では、そのうちの一つを選ぶと、それらの祝日が加わります。日本の祝日はこれまでどおり機能します。すでにアプリを使っていた場合は、引き続き日本の祝日を表示します。 | △ | × は無い。「それらの祝日」（deren）は選んだ 1 つとも全部とも読めるが、wenn Sie eines davon wählen が続くので選んだものと読める。「日本の祝日はこれまでどおりです」が「機能します」で少し不自然。「in der App zu Einstellungen」は前の行の「in der App „Einstellungen“」（iOS の設定）と紛らわしいので下の表のとおり直した |
| `whatsnew.txt` の 4 行目 | de-DE | ・週の始まりを月曜・日曜から選べるようになりました（設定 › 週の始まり）。これまでお使いの方は月曜始まりのままです。新しく使い始める方は端末の地域に合わせます。週のページの手書きは月曜始まりと日曜始まりで別々に保存します。切り替えると、もう一方の手書きは元に戻すまで見えませんが、消えません。月のページの手書きは日付についていきます。日曜始まりで書いた週の手書きは、古い版の端末では見えません（消えてはいません）。 | • Wochen können jetzt am Montag oder am Sonntag beginnen (Einstellungen > Erster Tag der Woche). Wenn Sie die App schon genutzt haben, bleibt es beim Montag. Wenn Sie neu sind, folgt die App der Region Ihres Geräts. Handschrift auf Wochenseiten wird für Wochen mit Montagsbeginn und Wochen mit Sonntagsbeginn getrennt gesichert. Beim Wechsel bleibt die Handschrift der anderen Einstellung ausgeblendet, bis Sie zurückwechseln, sie wird aber nicht gelöscht. Handschrift auf Monatsseiten folgt ihrem Datum. Wochenhandschrift mit Sonntagsbeginn ist auf Geräten mit einer älteren Version der App nicht zu sehen (sie ist nicht gelöscht). | • 週は月曜日または日曜日に始められるようになりました（設定 > 週の最初の日）。すでにアプリを使っていた場合は、月曜日のままです。新しく使う場合は、アプリはデバイスの地域に従います。週ページの手書きは、月曜始まりの週と日曜始まりの週で別々に保存されます。切り替えると、もう一方の設定の手書きは、戻すまで隠れたままになりますが、削除はされません。月ページの手書きは、その日付に従います。日曜始まりの週の手書きは、古いバージョンのアプリのデバイスでは見えません（削除されてはいません）。 | △ | × は無い。消えないこと・戻すまで見えないこと・古い版の注は全部ある。Wenn Sie neu sind は舌足らず、Wochenhandschrift は辞書に無い造語、folgt ihrem Datum は元の「日付についていく」より短いが、どれも意味は違わない。gesichert は保存の語で、アプリの `sync.header.saved` と同じ。設定の括弧はアプリ内の設定と書かれておらず、iOS の「言語と地域」にも同じ名前の項目があるので下の表のとおり直した |
| `whatsnew.txt` の 5 行目 | de-DE | ・祝日・言語・週の始まりの設定は端末ごとです。祝日と言語を変えても、手書きは同じ位置に残ります。 | • Die Einstellungen für Feiertage, Sprache und ersten Tag der Woche gelten pro Gerät. Wenn Sie Feiertage oder Sprache ändern, bleibt Ihre Handschrift an derselben Stelle. | • 祝日、言語、週の最初の日の設定はデバイスごとに適用されます。祝日や言語を変更しても、手書きは同じ場所にとどまります。 | ○ | 同じ。und ersten Tag に冠詞が無いのは言い回し |
| `whatsnew.txt` の最後の 1 文 | de-DE | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | Die Übersetzungen wurden mit KI erstellt und noch nicht von Muttersprachlern geprüft. Bitte teilen Sie uns Fehler mit. | 翻訳は AI で作成され、まだネイティブスピーカーの確認を受けていません。誤りがあればお知らせください。 | ○ | 同じ |

### R4 の後に直した字（2026-11-05）

| 場所 | 言語 | 前の字 | 今の字 | 逆翻訳（判定した Claude が元を見て書いた） | 判定 | 直した理由 |
| --- | --- | --- | --- | --- | --- | --- |
| `toast.weekStart.otherForm.one` | fr | %2$@ page de semaine avec début %1$@, non supprimée. Pour la voir : Réglages > Premier jour de la semaine. | %2$@ page de semaine (1er jour : %1$@), non supprimée. Pour la voir : Réglages > Premier jour de la semaine. | 週のページが %2$@ ページ（最初の日: %1$@）、削除されていません。見るには：設定 > 週の最初の日。 | △ | 「何の始まりか書かれておらず不自然」の注。「1er jour」で何の始まりかが分かり、続きの設定の名前（Premier jour de la semaine）と同じ語になる。「もう一方の」が無く、「切り替えると見えます」が「見るには: 設定 > 週の最初の日」なのは de・it・pt-BR と同じ。その前の字は `a l’autre premier jour (%1$@)` で、311 pt の 4 行を直すため e1073ae で `avec début` にした |
| `toast.weekStart.otherForm.other` | fr | %2$@ pages de semaine avec début %1$@, non supprimées. Pour les voir : Réglages > Premier jour de la semaine. | %2$@ pages de semaine (1er jour : %1$@), non supprimées. Pour les voir : Réglages > Premier jour de la semaine. | 週のページが %2$@ ページ（最初の日: %1$@）、削除されていません。見るには：設定 > 週の最初の日。 | △ | 同じ |
| `whatsnew.txt` の 3 行目 | de-DE | Gehen Sie in der App zu Einstellungen > Feiertage | Gehen Sie in Tegaki zu Einstellungen > Feiertage | Tegaki で 設定 > 祝日 > へ進み | △ | 前の行の「in der App „Einstellungen“」（iOS の設定アプリ）と語がほぼ同じで、アプリ内の設定を iOS の設定と読み違えやすい。アプリの名前で分ける。1 字短くなる |
| `whatsnew.txt` の 4 行目 | de-DE | (Einstellungen > Erster Tag der Woche) | (in Tegaki: Einstellungen > Erster Tag der Woche) | （Tegaki で: 設定 > 週の最初の日） | △ | iOS の「言語と地域」にも同じ名前の項目がある（GLOSSARY の 2）。こちらはアプリ内の設定と読めるようにする。11 字増える |

この 4 か所は下の R5 で元を見ない逆翻訳を通しました（全部 △）。de-DE の `whatsnew.txt` は 2,169 字（上限 4,000 字）で、L-9 は ok です。× に当たる物（意味が違う、抜け）は無かったので、ほかの字は変えていません（`funktionieren`・`Wenn Sie neu sind`・`Wochenhandschrift`・`und ersten Tag` は言い回しのまま残しました。母語の人に見てもらうときの候補です）。

**fr の案を変えた理由**: 案は `%2$@ page de semaine débutant le %1$@`。%1$@ に入る字を見ると、呼ぶ所は `WeekStartNotice.text` の `WeekStartChoice.name(form)` で、中身は `L.text("settings.weekStart.monday")`・`.sunday`。fr は設定の行の字の **Lundi・Dimanche（大文字）** です。`L.plural` と `KitStrings.fill` は字を変えず、Kit の字（`KitStrings.generated.swift`）に fr の曜日の全名はありません。案のままだと「débutant le Dimanche」になり、文の中で曜日を大文字で書くのは fr の誤りです。小文字にするには設定の行の字か呼ぶ所のコードを変えることになるので、訳だけで済む形にしました。括弧の中に設定の値を置く形は、元の「週の始まり（%1$@）」と同じ形で、キーの `comment` の「文の中の括弧にも入る」にも合います。「débutant le dimanche」にしたければ、呼ぶ所のコードを fr だけ変える必要があります。

**幅**（`m7b-impl/FIX/measure/lines`、Mac Catalyst の字、15 pt）: 今の fr の字は、日曜と月曜、1・2・9・10・99 ページで、311 pt と 338 pt とも 3 行です。311 pt の最後の行は全部 192 pt（前の `avec début` は日曜・10 ページ以上で 276 pt）。338 pt の最後の行は 133 pt（99 ページ・日曜だけ 192 pt）。本当の判定は CI のシミュレータです。

### R4 の後の字と見本の語の、元を見ない逆翻訳（R5、2026-11-05）

R4 の後に直した字と FIX3 の見本の語を、別の Claude が日本語の元と前の逆翻訳を見ずに訳し戻しました（入力は 10 件。`m7b-impl/R5/input.json`・`back.json`）。**× は 0、△ 10** で、1 の表の合計は変わりません。読み合わせの前に、it の `toast.weekStart.otherForm.*` を fr と同じ括弧の形に直しました（`con inizio Domenica` は文の中の大文字が誤りになるため。字は 1 字短くなり、CI の `testWeekStartToastsFitThreeLines` で見ます）。ほかの字は変えていません。

| 場所 | 言語 | 逆翻訳（元を見ない） | 判定 | 言われたこと、変えなかった理由 |
| --- | --- | --- | --- | --- |
| `toast.weekStart.otherForm.one` | fr | 週ページ %2$@ ページ（1日目：%1$@）、削除はされていません。それを見るには：設定 > 週の最初の日。 | △ | 「隠れている」が無く、「削除されていない」だけなので、削除に失敗した知らせと読まれるおそれがある、と言われた。`non supprimée` の字は元の「消えていません」に当たるので変えない |
| `toast.weekStart.otherForm.other` | fr | 週ページ %2$@ ページ（1日目：%1$@）、削除はされていません。それらを見るには：設定 > 週の最初の日。 | △ | 同じ |
| `toast.weekStart.otherForm.one` | it | 週ページ %2$@ ページ（始まり：%1$@）、削除はされていません。それを見るには：設定 > 週の最初の日。 | △ | fr と同じ。「(inizio: …)」は週の始まりと読めた |
| `toast.weekStart.otherForm.other` | it | 週ページ %2$@ ページ（始まり：%1$@）、削除はされていません。それらを見るには：設定 > 週の最初の日。 | △ | 同じ |
| `demo.event.camping` | es | テント | △ | 物の名前で予定らしくない。スペインでは `tienda` の方がふつう。`Camping` は 44.4 pt で上限 42 pt を超えるので変えない（見本の語で、写真にだけ出る） |
| `demo.event.camping` | pt-BR | テント | △ | ブラジルでは `barraca` の方がふつう。`Camping`・`Acampar` は上限を超える。`Barraca` は 40.7 pt で、写真の 2 日の帯に切れないかが写真でしか分からない（7 の表）。見本の語なので変えない |
| `demo.event.deadline` | es | 期限 | △ | 通じる |
| `demo.event.deadline` | it | 期限（略語） | △ | 略語は通じるが、日付なしでは切れた字にも見える。入る語が無いので変えない |
| `whatsnew.txt` の 3 行目 | de-DE | • アプリで、世界の国や地域の祝日を表示できるようになりました。Tegaki で 設定 > 祝日 > 「表示する祝日」 へ進み、国（米国の州のような地域も可）または「なし」を選んでください。連邦州、州、または地域がある国では、そのうちの一つを選ぶと、その祝日が加わります。日本の祝日はこれまでどおり機能します。すでにアプリをお使いの場合は、引き続き日本の祝日が表示されます。 | △ | 意味は同じ。「Tegaki で 設定 > 祝日」と読めた。`funktionieren` と語の並びの硬さを言われた（R4 と同じ） |
| `whatsnew.txt` の 4 行目 | de-DE | • 週の始まりを月曜または日曜にできるようになりました（Tegaki で：設定 > 週の最初の日）。すでにアプリをお使いの場合は、月曜のままです。初めてお使いの場合は、アプリはデバイスの地域に従います。週ページの手書きは、月曜始まりの週と日曜始まりの週で別々に保存されます。切り替えると、もう一方の設定の手書きは、元に戻すまで非表示のままですが、削除はされません。月ページの手書きはその日付に従います。日曜始まりの週の手書きは、古いバージョンのアプリのデバイスでは見えません（削除はされていません）。 | △ | 意味は同じ。「Tegaki で：設定 > 週の最初の日」と読めた。`gesichert`・`Wochenhandschrift`・`Wenn Sie neu sind` と長さを言われた（母語の人に見てもらうときの候補） |

## 11. 1.3 の SUPPORT（既知の制限の「マスをまたぐ手書き」、2026-11-13）

元は `docs/SUPPORT.md` の既知の制限の表の「マスをまたぐ手書き」の行です。1.3 で、週と日のページの横つなぎ・古い版での見え方・設定のオフの 7 文を、前からある 2 文の後ろに足しました（[M7C_CONTRACT.md](../M7C_CONTRACT.md) §8.7 の 1 つ目）。英語は `docs/SUPPORT.en.md` の同じ行（Handwriting across cells）です。自由メモの 2 段落（§8.7 の 2 つ目）は、週のメモが 1.3 に入らないので変えていません。

逆翻訳は、英語の行（表の題「Known limitations」と行の題、行の全文）だけを別の Claude に渡し、日本語の元を見ずに訳し戻したものです。行の全文を 1 つの段落として渡したので、前からある 2 文も入っています。判定は、その結果と日本語の元を、英語を書いた Claude とは別の Claude が照らしたものです。母語の人の確認ではありません。逆翻訳の全文は `docs/i18n/back/legal-en.md` の同じ行にあります。

**足した 7 文: ○ 4・△ 3・× 0。** 前からある 2 文は 1.2 と同じ字で、今回も ○ でした。題の「既知の制限 > セルをまたぐ手書き」も ○ です（cell が「セル」に戻っただけで、同じもの）。抜けた事実も、元に無い事実もありませんでした（線は真ん中があるページに 1 本で保存、古い版ではそのページにだけ出て消えていない、古い版で消すと新しい版でも消える、両方を最新に、設定でオフにできる、オフの端末では片方のページにだけ出る、月と年は今までどおり）。

| 文 | 元の日本語 | 渡した英語 | 逆翻訳（元を見ない） | 判定 | 理由 |
| --- | --- | --- | --- | --- | --- |
| 前からの 1 文目 | 手書きは日付のマスごとに保存されます。 | Handwriting is saved for each date cell. | 手書きは日付のセルごとに保存されます。 | ○ | 1.2 と同じ字（変えていない）。cell が「マス」でなく「セル」に戻ったが、同じもの（GLOSSARY でも「前後の月の日のマス」は cells） |
| 前からの 2 文目 | 終日の予定が増えてマスの高さが変わると、マスの境界をまたいで書いた線がわずかにずれて見えることがあります。 | When the height of the cells changes because more all-day events are added, strokes written across cell borders may look slightly out of place. | 終日の予定が増えてセルの高さが変わると、セルの境目をまたいで書いた線が少しずれて見えることがあります。 | ○ | 1.2 と同じ字（変えていない）。「境界」が「境目」、「わずかに」が「少し」で、同じ意味 |
| 足した 1 文目 | 1.3 から、週と日のページで、前後のページが横につながり、境目をまたいで書けます（月と年のページは今までどおり 1 ページずつです）。 | From version 1.3, week and day pages are joined side by side with the pages before and after them, and you can write across the borders between them (month and year pages are still shown one page at a time, as before). | バージョン 1.3 からは、週と日のページが前後のページと横につながり、ページの境目をまたいで書けるようになりました（月と年のページは、これまでどおり 1 ページずつの表示です）。 | ○ | 「1.3 から」に version を足した（1.3 が版の番号だと分かるように）。「書けます」が「書けるようになりました」に戻ったのは From version 1.3 の読みで、中身は同じ。括弧の中の「今までどおり 1 ページずつ」も同じ |
| 足した 2 文目 | ページをまたいで書いた線は、線の真ん中があるページに 1 本で保存されます。 | A stroke written across pages is saved as one stroke on the page where the middle of the stroke is. | ページをまたいで書いた線は、線の真ん中があるページに 1 本の線として保存されます。 | ○ | 「1 本で」が「1 本の線として」。どちらも 2 つのページに分けずに 1 本で保存する意味 |
| 足した 3 文目 | 1.3 より前の版の端末では、その線は保存されたページにだけ出ます（消えてはいません）。 | On a device still on a version before 1.3, that stroke appears only on the page where it is saved (it has not been deleted). | 1.3 より前のバージョンのままの端末では、その線は保存されたページにだけ表示されます（消えたわけではありません）。 | △ | 「のまま」（still）は元に無い。1.3 より前の版の端末は、まだ 1.3 にしていない端末のことなので、意味は同じ。「消えてはいません」が「消えたわけではありません」で、同じ |
| 足した 4 文目 | その端末でその線を消すと、新しい版でも消えます。 | If you erase that stroke on that device, it is erased on the new version too. | その端末でその線を消すと、新しいバージョンでも消えます。 | ○ | 同じ |
| 足した 5 文目 | iPad と iPhone の両方を最新の版にしてお使いください。 | Please update both your iPad and your iPhone to the latest version. | iPad と iPhone の両方を最新のバージョンにしてください。 | △ | 「してお使いください」が「にしてください」（update の 1 語）。頼んでいること（iPad と iPhone の両方を最新の版にする）は同じ |
| 足した 6 文目 | 設定 › ページ で横につなげるのをオフにすると、今までどおり 1 ページずつになります。 | If you turn off the side-by-side joining in Settings > Pages, pages are shown one at a time, as before. | 設定 > ページ で横につなげる設定をオフにすると、これまでどおり 1 ページずつの表示になります。 | △ | 逆翻訳は ○（「設定 > ページ」）。照合のあとで the App's を足した（下の「照合の後に直した字」）。日本語の元は、かぎかっこの無い「設定 ›」でアプリの中の設定を表す書き分けなので、意味は同じ |
| 足した 7 文目 | オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | On a device where it is turned off, a stroke written across pages appears on only one of the pages (it has not been deleted). | オフにしている端末では、ページをまたいで書いた線はどちらか一方のページにだけ表示されます（消えたわけではありません）。 | ○ | 「オフにした」が「オフにしている」、「片方の」が「どちらか一方の」で、同じ意味。「消えてはいません」も同じ（契約の N-3 の最後の文） |

### 照合の後に直した字（2026-11-13）

| 場所 | 前の字 | 今の字 | 逆翻訳（判定した Claude が元を見て書いた） | 直した理由 |
| --- | --- | --- | --- | --- |
| 足した 6 文目 | If you turn off the side-by-side joining in Settings > Pages, pages are shown one at a time, as before. | If you turn off the side-by-side joining in the App's Settings > Pages, pages are shown one at a time, as before. | アプリの 設定 > ページ で横につなげる設定をオフにすると、これまでどおり 1 ページずつの表示になります。 | 英語の「Settings > Pages」だけでは、iOS の設定アプリ（そこにある Apple の Pages アプリの項目）と読み違えやすい。日本語の元はかぎかっこの有無でアプリの中の設定と iOS の設定を書き分けているが、英語の文書はその書き分けをしていないので、同じ文書の祝日の FAQ（the App's Settings > Holidays）と同じ形にした。1.2 の R4 で de-DE の新機能の文を in Tegaki にしたのと同じ理由 |

この直し（the App's の 2 語）は、あとで元を見ない逆翻訳を通しました（すぐ下の「元を見ない逆翻訳（2 回目）」。○）。ほかの字は変えていません（△ の 2 文は言い回しの差で、意味は同じなのでそのまま）。

### 元を見ない逆翻訳（2 回目、2026-11-13）

the App's を足した 6 文目だけを、12 の「照合の後に直した 19 件」と同じ表に入れて、R にもう 1 回渡しました。サポートの字で R が読んだのは英語のこの 1 文だけで、日本語の元・1 回目の逆翻訳・行のほかの文は入っていません。判定は、英語を直した Claude とも R とも別の Claude が、逆翻訳と日本語の元を照らしたものです（12 と同じ ○ と × の 2 つで、言い回しの差は理由に書きました）。**○ でした（× 0）。** 英語の字は変えていません。`docs/i18n/back/legal-en.md` の同じ行の 6 文目は、この 2 回目の逆翻訳に替えました（1 回目の逆翻訳は上の表にあります）。

| 文 | 元の日本語 | 渡した英語 | 逆翻訳（元を見ない、2 回目） | 判定 | 理由 |
| --- | --- | --- | --- | --- | --- |
| 足した 6 文目 | 設定 › ページ で横につなげるのをオフにすると、今までどおり 1 ページずつになります。 | If you turn off the side-by-side joining in the App's Settings > Pages, pages are shown one at a time, as before. | アプリの［設定］＞［ページ］で「横につなぐ」機能をオフにすると、以前と同じようにページが1ページずつ表示されます。 | ○ | 「the App's」は「アプリの」と読まれ、iOS の設定アプリでなく、アプリの中の設定だと伝わった（直した理由のとおり）。日本語の元はかぎかっこの無い「設定 ›」でアプリの中の設定を表すので、指す所は同じ。「横につなげるのを」が「「横につなぐ」機能を」。R はかぎかっこを足したが、メモに「画面の項目名なのか説明なのか分からない」と書いた（日本語の元も英語も、スイッチの名前は引用していない。11 の「決まっていない語」）。「今までどおり」が「以前と同じように」。R は as before を「オンにする前と同じ」とも取れると書いたが、日本語の元の「今までどおり」も同じ幅で、どちらも 1 ページずつの表示のこと |

### 決まっていない語

- **「Pages」**: `settings.page.header`（N-1「ページ」）の英語の値に合わせた仮の語です。X の 1.3 の訳がまだ無いので、照らせていません。X の訳が入ったら、1.2 の 5 の「画面の名前」と同じく、`SUPPORT.en.md` の字を `tools/l10n/translations/en.json` の値と機械で照らし、違えば 1 語を直します。
- **スイッチの名前**（N-2「前後のページを横につなげる」）は、日本語の元と同じく引用していません（英語は the side-by-side joining）。
- **最後の文**は契約の N-3 の最後の文と同じ日本語です。X が N-3（`settings.page.span.footer`）を訳したら、英語の言い回しをそろえるかをリードが決めます（意味は今のままで同じ）。

### lint

`lint.py`（L-1〜L-14）・`build.py --check`・`baseline.py --check` は、直した後の字で 3 つとも終了 0 です（`baseline.py` は 9cbc3c9 の 516 字のまま。L-12 の字の幅の目安の警告 58 件は、この枝で変えていない `tools/l10n/source` の訳のもので、前からある）。

## 12. 1.3 のアプリの文字列（§8.1 の N-1〜N-8、2026-11-13）

元は [M7C_CONTRACT.md](../M7C_CONTRACT.md) §8.1 の固定した日本語の 8 キーです（`tools/l10n/source/app-U.json`。日本語は 1 字も変えていません）。訳は X が書き（7c49b02）、R には key・言語・訳の 72 行の表（日本語の元と comment は入っていない）だけを渡して、元を見ずに訳し戻してもらいました。判定は、訳を書いた Claude とも R とも別の Claude が、その逆翻訳と固定の日本語を 1 件ずつ照らしたものです。**母語の人の確認ではありません。** 逆翻訳の全文は `docs/i18n/back/<言語>.json` の同じキーにあります。

判定（1.3 は 2 つ）: **○** 同じ意味（抜けた事実も、元に無い事実も無い）／ **×** 意味の違い（直す）。1.2 の △（言い回しの差）にあたるものは ○ にして、理由の列に言い回しの差を書きました。

### 結果

| 言語 | ○（1 回目） | ×（1 回目） | 直した後の × |
| --- | --- | --- | --- |
| en | 8 | 0 | 0 |
| zh-Hans | 8 | 0 | 0 |
| zh-Hant | 8 | 0 | 0 |
| ko | 8 | 0 | 0 |
| fr | 4 | 4 | 0 |
| de | 4 | 4 | 0 |
| es | 3 | 5 | 0 |
| it | 8 | 0 | 0 |
| pt-BR | 3 | 5 | 0 |
| 合計（8 キー × 9 言語） | 54 | 18 | 0 |

- **× の 18 件は、全部「境目をまたいで書ける」と「ページをまたいで書いた線」の 1 つの考えでした。** fr・de・es・pt-BR の案内の札（N-4〜N-7）で、境目の「上に重ねて書く」とも読める言い方（par-dessus・über … schreiben・por encima de・por cima da）が、逆翻訳で「つなぎ目の上から書く」になり、またいで書けることが伝わっていませんでした（de の über den Übergang schreiben は「境目について書く」とも読めます）。es・pt-BR の脚注（N-3）は、同じ言い方と、「2 ページの間に」とも読める entre dos páginas・entre duas páginas でした。
- 直した訳は下の表のとおりです（19 件。× の 18 件と、それにそろえた fr の N-3）。日本語の元・comment・jaSha1 は変えていません。
- **直した 19 件は、今の字だけを R にもう 1 回渡し、元を見ずに訳し戻してもらいました（この節の最後の「元を見ない逆翻訳（2 回目）」）。○ 19・× 0 で、訳は変えていません。** 下の表の「逆翻訳（直した後、判定した Claude が元を見て書いた）」の列は、その前に判定した Claude が書いたものです（1.2 の 10 の FIX と同じ）。
- 店の文（§8.3 の新機能の文）とサポートの英語は、別の役の枝の物で、この節では見ていません。

### × と直した訳

| キー | 言語 | 元の日本語 | 逆翻訳（1 回目、元を見ない） | 判定 | 意味の違い | 前の訳 | 直した訳 | 逆翻訳（直した後、判定した Claude が元を見て書いた） | 判定（直した後） |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `settings.page.span.footer`（N-3） | fr | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | 週と日のページでは、前のページと次のページが横に並んでつながり、つなぎ目の上にまたがって書くことができます。月と年のページは、次のバージョンから一つずつ順に対応します。このオプションがオフの場合は、以前と同じようにページが1ページずつ表示されます。これがオフになっている端末では、2ページにまたがって書いた線はそのうち一方にしか表示されません（削除されてはいません）。 | ○ | × ではないが、N-4〜N-7 の直しにそろえて par-dessus la jonction を à cheval sur la jonction に（同じ言語の中で境目の言い方を 1 つに） | Sur les pages de la semaine et du jour, les pages précédente et suivante sont reliées côte à côte, et vous pouvez écrire par-dessus la jonction. Les pages du mois et de l’année seront prises en charge l’une après l’autre à partir de la prochaine version. Si cette option est désactivée, les pages s’affichent une par une, comme avant. Sur un appareil où elle est désactivée, les traits écrits à cheval sur deux pages n’apparaissent que sur l’une d’elles (ils ne sont pas supprimés). | Sur les pages de la semaine et du jour, les pages précédente et suivante sont reliées côte à côte, et vous pouvez écrire à cheval sur la jonction. Les pages du mois et de l’année seront prises en charge l’une après l’autre à partir de la prochaine version. Si cette option est désactivée, les pages s’affichent une par une, comme avant. Sur un appareil où elle est désactivée, les traits écrits à cheval sur deux pages n’apparaissent que sur l’une d’elles (ils ne sont pas supprimés). | 週と日のページでは、前のページと次のページが横に並んでつながり、つなぎ目にまたがって書くことができます。月と年のページは、次のバージョンから一つずつ順に対応します。このオプションがオフの場合は、以前と同じようにページが 1 ページずつ表示されます。オフになっている端末では、2 ページにまたがって書いた線はそのうち一方にしか表示されません（削除されてはいません）。 | ○ |
| `settings.page.span.footer`（N-3） | es | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | 週と日のページでは、前のページと次のページが横方向につながり、つなぎ目の上から書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に広がっていきます。オフの場合は、これまでどおりページが1ページずつ表示されます。オフになっている端末では、2ページの間（にまたがって）書いた線は、どちらか一方にしか表示されません（削除はされません）。 | × | 「境目をまたいで書けます」が「つなぎ目の上から書くことができます」（por encima de la unión は、つなぎ目の上に重ねて書くとも読め、またぐことが伝わらない）。「ページをまたいで書いた線」が「2ページの間（にまたがって）書いた線」で、R が括弧で迷いを書いた（entre dos páginas は「2 ページの間に」とも読める）。直し: por encima de la unión を cruzando la unión に。entre dos páginas を de una página a otra（ページからページへ）に、una de ellas を una de las dos（2 つのうち 1 つ）に | En las páginas de la semana y del día, las páginas anterior y siguiente se unen en horizontal y puede escribir por encima de la unión. La función llegará a las páginas del mes y del año, una tras otra, a partir de la próxima versión. Si está desactivado, las páginas se muestran de una en una, como hasta ahora. En un dispositivo donde esté desactivado, los trazos escritos entre dos páginas solo aparecen en una de ellas (no se eliminan). | En las páginas de la semana y del día, las páginas anterior y siguiente se unen en horizontal y puede escribir cruzando la unión. La función llegará a las páginas del mes y del año, una tras otra, a partir de la próxima versión. Si está desactivado, las páginas se muestran de una en una, como hasta ahora. En un dispositivo donde esté desactivado, los trazos escritos de una página a otra solo aparecen en una de las dos (no se eliminan). | 週と日のページでは、前のページと次のページが横方向につながり、つなぎ目を横切って書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に広がります。オフの場合は、これまでどおりページが 1 ページずつ表示されます。オフになっている端末では、ページからページへ書いた線は、2 ページのうち一方にしか表示されません（削除はされません）。 | ○ |
| `settings.page.span.footer`（N-3） | pt-BR | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | 週と日のページでは、前のページと次のページが横につながった状態になり、つなぎ目の上から書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に広がります。オフのときは、以前と同じようにページが1ページずつ表示されます。この設定をオフにしている端末では、2ページの間（にまたがって）書いた線は、そのうち一方にしか表示されません（消されてはいません）。 | × | 「境目をまたいで書けます」が「つなぎ目の上から書くことができます」（por cima da emenda は、つなぎ目の上に重ねて書くとも読め、またぐことが伝わらない）。「ページをまたいで書いた線」が「2ページの間（にまたがって）書いた線」で、R が括弧で迷いを書いた（entre duas páginas は「2 ページの間に」とも読める）。直し: por cima da emenda を atravessando a emenda に。entre duas páginas を de uma página para a outra（ページからページへ）に、uma delas を uma das duas に | Nas páginas da semana e do dia, as páginas anterior e seguinte ficam unidas na horizontal, e você pode escrever por cima da emenda. O recurso chegará às páginas do mês e do ano, uma depois da outra, a partir da próxima versão. Quando desativado, as páginas aparecem uma por vez, como antes. Em um dispositivo com o ajuste desativado, os traços escritos entre duas páginas aparecem só em uma delas (não são apagados). | Nas páginas da semana e do dia, as páginas anterior e seguinte ficam unidas na horizontal, e você pode escrever atravessando a emenda. O recurso chegará às páginas do mês e do ano, uma depois da outra, a partir da próxima versão. Quando desativado, as páginas aparecem uma por vez, como antes. Em um dispositivo com o ajuste desativado, os traços escritos de uma página para a outra aparecem só em uma das duas (não são apagados). | 週と日のページでは、前のページと次のページが横につながった状態になり、つなぎ目を横切って書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に広がります。オフのときは、以前と同じようにページが 1 ページずつ表示されます。この設定をオフにしている端末では、ページからページへ書いた線は、2 ページのうち一方にしか表示されません（消されてはいません）。 | ○ |
| `span.guide.week.oneFinger`（N-4） | fr | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週が、これからは横に並んでつながります。指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ。直し: 境目の言い方を à cheval sur la jonction（つなぎ目にまたがって）に。N-3 が線に使う à cheval sur deux pages と同じ語 | Les semaines précédente et suivante sont désormais reliées côte à côte. Faites glisser le doigt sur le côté pour voir la semaine voisine. Vous pouvez écrire directement par-dessus la jonction. | Les semaines précédente et suivante sont désormais reliées côte à côte. Faites glisser le doigt sur le côté pour voir la semaine voisine. Vous pouvez écrire directement à cheval sur la jonction. | 前の週と次の週が、これからは横に並んでつながります。指を横にすべらせると、隣の週が見られます。つなぎ目にまたがって、そのまま書くことができます。 | ○ |
| `span.guide.week.oneFinger`（N-4） | de | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週が横につながるようになりました。指で横になぞると、隣の週が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き。直し: N-3 と同じ hinweg を足した（über den Übergang hinweg）。iPhone の縦（315 pt）で 4 行に入れるため、語の並びを「境目を越えて、そのまま書ける」の順に | Vorherige und nächste Woche sind jetzt seitlich verbunden. Streichen Sie mit dem Finger seitwärts, um die Woche daneben zu sehen. Sie können direkt über den Übergang schreiben. | Vorherige und nächste Woche sind jetzt seitlich verbunden. Streichen Sie mit dem Finger seitwärts, um die Woche daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の週と次の週が横につながるようになりました。指で横にすべらせると、隣の週が見られます。境目を越えて、そのまま書くことができます。 | ○ |
| `span.guide.week.oneFinger`（N-4） | es | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週は、もう横方向につながっています。指を横方向にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ。直し: por encima de を cruzando（横切って）に | Las semanas anterior y siguiente ya están unidas en horizontal. Deslice el dedo en horizontal para ver la semana contigua. Puede escribir directamente por encima de la unión. | Las semanas anterior y siguiente ya están unidas en horizontal. Deslice el dedo en horizontal para ver la semana contigua. Puede escribir directamente cruzando la unión. | 前の週と次の週は、もう横方向につながっています。指を横方向にすべらせると、隣の週が見られます。つなぎ目を横切って、そのまま書くことができます。 | ○ |
| `span.guide.week.oneFinger`（N-4） | pt-BR | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週が、今は横につながっています。指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ。直し: por cima da を atravessando（横切って）に | As semanas anterior e seguinte agora estão unidas na horizontal. Deslize o dedo na horizontal para ver a semana ao lado. Você pode escrever direto por cima da emenda. | As semanas anterior e seguinte agora estão unidas na horizontal. Deslize o dedo na horizontal para ver a semana ao lado. Você pode escrever direto atravessando a emenda. | 前の週と次の週が、今は横につながっています。指を横にすべらせると、隣の週が見られます。つなぎ目を横切って、そのまま書けます。 | ○ |
| `span.guide.week.twoFingers`（N-5） | fr | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週が、これからは横に並んでつながります。2本の指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ。直し: 境目の言い方を à cheval sur la jonction（つなぎ目にまたがって）に。N-3 が線に使う à cheval sur deux pages と同じ語 | Les semaines précédente et suivante sont désormais reliées côte à côte. Faites glisser deux doigts sur le côté pour voir la semaine voisine. Vous pouvez écrire directement par-dessus la jonction. | Les semaines précédente et suivante sont désormais reliées côte à côte. Faites glisser deux doigts sur le côté pour voir la semaine voisine. Vous pouvez écrire directement à cheval sur la jonction. | 前の週と次の週が、これからは横に並んでつながります。2 本の指を横にすべらせると、隣の週が見られます。つなぎ目にまたがって、そのまま書くことができます。 | ○ |
| `span.guide.week.twoFingers`（N-5） | de | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週が横につながるようになりました。2本の指で横になぞると、隣の週が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き。直し: N-3 と同じ hinweg を足した（über den Übergang hinweg）。iPhone の縦（315 pt）で 4 行に入れるため、語の並びを「境目を越えて、そのまま書ける」の順に | Vorherige und nächste Woche sind jetzt seitlich verbunden. Streichen Sie mit zwei Fingern seitwärts, um die Woche daneben zu sehen. Sie können direkt über den Übergang schreiben. | Vorherige und nächste Woche sind jetzt seitlich verbunden. Streichen Sie mit zwei Fingern seitwärts, um die Woche daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の週と次の週が横につながるようになりました。2 本の指で横にすべらせると、隣の週が見られます。境目を越えて、そのまま書くことができます。 | ○ |
| `span.guide.week.twoFingers`（N-5） | es | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週は、もう横方向につながっています。2本の指を横方向にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ。直し: por encima de を cruzando（横切って）に | Las semanas anterior y siguiente ya están unidas en horizontal. Deslice dos dedos en horizontal para ver la semana contigua. Puede escribir directamente por encima de la unión. | Las semanas anterior y siguiente ya están unidas en horizontal. Deslice dos dedos en horizontal para ver la semana contigua. Puede escribir directamente cruzando la unión. | 前の週と次の週は、もう横方向につながっています。2 本の指を横方向にすべらせると、隣の週が見られます。つなぎ目を横切って、そのまま書くことができます。 | ○ |
| `span.guide.week.twoFingers`（N-5） | pt-BR | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | 前の週と次の週が、今は横につながっています。2本の指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ。直し: por cima da を atravessando（横切って）に | As semanas anterior e seguinte agora estão unidas na horizontal. Deslize dois dedos na horizontal para ver a semana ao lado. Você pode escrever direto por cima da emenda. | As semanas anterior e seguinte agora estão unidas na horizontal. Deslize dois dedos na horizontal para ver a semana ao lado. Você pode escrever direto atravessando a emenda. | 前の週と次の週が、今は横につながっています。2 本の指を横にすべらせると、隣の週が見られます。つなぎ目を横切って、そのまま書けます。 | ○ |
| `span.guide.day.oneFinger`（N-6） | fr | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日が、これからは横に並んでつながります。指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ。直し: 境目の言い方を à cheval sur la jonction（つなぎ目にまたがって）に。N-3 が線に使う à cheval sur deux pages と同じ語 | Les jours précédent et suivant sont désormais reliés côte à côte. Faites glisser le doigt sur le côté pour voir le jour voisin. Vous pouvez écrire directement par-dessus la jonction. | Les jours précédent et suivant sont désormais reliés côte à côte. Faites glisser le doigt sur le côté pour voir le jour voisin. Vous pouvez écrire directement à cheval sur la jonction. | 前の日と次の日が、これからは横に並んでつながります。指を横にすべらせると、隣の日が見られます。つなぎ目にまたがって、そのまま書くことができます。 | ○ |
| `span.guide.day.oneFinger`（N-6） | de | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日が横につながるようになりました。指で横になぞると、隣の日が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き。直し: N-3 と同じ hinweg を足した（über den Übergang hinweg）。iPhone の縦（315 pt）で 4 行に入れるため、語の並びを「境目を越えて、そのまま書ける」の順に | Vorheriger und nächster Tag sind jetzt seitlich verbunden. Streichen Sie mit dem Finger seitwärts, um den Tag daneben zu sehen. Sie können direkt über den Übergang schreiben. | Vorheriger und nächster Tag sind jetzt seitlich verbunden. Streichen Sie mit dem Finger seitwärts, um den Tag daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の日と次の日が横につながるようになりました。指で横にすべらせると、隣の日が見られます。境目を越えて、そのまま書くことができます。 | ○ |
| `span.guide.day.oneFinger`（N-6） | es | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日は、もう横方向につながっています。指を横方向にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ。直し: por encima de を cruzando（横切って）に | Los días anterior y siguiente ya están unidos en horizontal. Deslice el dedo en horizontal para ver el día contiguo. Puede escribir directamente por encima de la unión. | Los días anterior y siguiente ya están unidos en horizontal. Deslice el dedo en horizontal para ver el día contiguo. Puede escribir directamente cruzando la unión. | 前の日と次の日は、もう横方向につながっています。指を横方向にすべらせると、隣の日が見られます。つなぎ目を横切って、そのまま書くことができます。 | ○ |
| `span.guide.day.oneFinger`（N-6） | pt-BR | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日が、今は横につながっています。指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ。直し: por cima da を atravessando（横切って）に | Os dias anterior e seguinte agora estão unidos na horizontal. Deslize o dedo na horizontal para ver o dia ao lado. Você pode escrever direto por cima da emenda. | Os dias anterior e seguinte agora estão unidos na horizontal. Deslize o dedo na horizontal para ver o dia ao lado. Você pode escrever direto atravessando a emenda. | 前の日と次の日が、今は横につながっています。指を横にすべらせると、隣の日が見られます。つなぎ目を横切って、そのまま書けます。 | ○ |
| `span.guide.day.twoFingers`（N-7） | fr | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日が、これからは横に並んでつながります。2本の指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ。直し: 境目の言い方を à cheval sur la jonction（つなぎ目にまたがって）に。N-3 が線に使う à cheval sur deux pages と同じ語 | Les jours précédent et suivant sont désormais reliés côte à côte. Faites glisser deux doigts sur le côté pour voir le jour voisin. Vous pouvez écrire directement par-dessus la jonction. | Les jours précédent et suivant sont désormais reliés côte à côte. Faites glisser deux doigts sur le côté pour voir le jour voisin. Vous pouvez écrire directement à cheval sur la jonction. | 前の日と次の日が、これからは横に並んでつながります。2 本の指を横にすべらせると、隣の日が見られます。つなぎ目にまたがって、そのまま書くことができます。 | ○ |
| `span.guide.day.twoFingers`（N-7） | de | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日が横につながるようになりました。2本の指で横になぞると、隣の日が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き。直し: N-3 と同じ hinweg を足した（über den Übergang hinweg）。iPhone の縦（315 pt）で 4 行に入れるため、語の並びを「境目を越えて、そのまま書ける」の順に | Vorheriger und nächster Tag sind jetzt seitlich verbunden. Streichen Sie mit zwei Fingern seitwärts, um den Tag daneben zu sehen. Sie können direkt über den Übergang schreiben. | Vorheriger und nächster Tag sind jetzt seitlich verbunden. Streichen Sie mit zwei Fingern seitwärts, um den Tag daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の日と次の日が横につながるようになりました。2 本の指で横にすべらせると、隣の日が見られます。境目を越えて、そのまま書くことができます。 | ○ |
| `span.guide.day.twoFingers`（N-7） | es | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日は、もう横方向につながっています。2本の指を横方向にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ。直し: por encima de を cruzando（横切って）に | Los días anterior y siguiente ya están unidos en horizontal. Deslice dos dedos en horizontal para ver el día contiguo. Puede escribir directamente por encima de la unión. | Los días anterior y siguiente ya están unidos en horizontal. Deslice dos dedos en horizontal para ver el día contiguo. Puede escribir directamente cruzando la unión. | 前の日と次の日は、もう横方向につながっています。2 本の指を横方向にすべらせると、隣の日が見られます。つなぎ目を横切って、そのまま書くことができます。 | ○ |
| `span.guide.day.twoFingers`（N-7） | pt-BR | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | 前の日と次の日が、今は横につながっています。2本の指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ。直し: por cima da を atravessando（横切って）に | Os dias anterior e seguinte agora estão unidos na horizontal. Deslize dois dedos na horizontal para ver o dia ao lado. Você pode escrever direto por cima da emenda. | Os dias anterior e seguinte agora estão unidos na horizontal. Deslize dois dedos na horizontal para ver o dia ao lado. Você pode escrever direto atravessando a emenda. | 前の日と次の日が、今は横につながっています。2 本の指を横にすべらせると、隣の日が見られます。つなぎ目を横切って、そのまま書けます。 | ○ |

**直した後の × は 0 件です（72 件とも ○）。** 直した 19 件は、この節の最後の 2 回目の元を見ない逆翻訳でも ○ でした。

### 全部の表（72 件）

同じ逆翻訳で同じ判定の言語は 1 行にまとめました。「全部」は 9 言語です。直した訳は上の表にあり、ここでは 1 回目の逆翻訳と判定です。

| キー | 元の日本語 | 言語 | 逆翻訳（元を見ない） | 判定（1 回目） | 理由・言い回しの差 | 直した後 |
| --- | --- | --- | --- | --- | --- | --- |
| `settings.page.header`（N-1） | ページ | 全部 | ページ | ○ | 同じ | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | en | 隣り合うページを横につなげる | ○ | 「前後の」が「隣の（隣り合う・隣接する）」。ページの並びで隣り合うのは前後のページなので、指す物は同じ（日本語の N-4〜N-7 も同じ物を「となりの週」と書く。「前後の」は N-3 の訳に、前のページと次のページとして書いてある） | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | zh-Hans・zh-Hant | 前後のページを横につなげる | ○ | 同じ | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | ko | 前後のページを横につなぐ | ○ | 同じ | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | fr | 隣のページを横に並べてつなぐ | ○ | 「前後の」が「隣の（隣り合う・隣接する）」。ページの並びで隣り合うのは前後のページなので、指す物は同じ（日本語の N-4〜N-7 も同じ物を「となりの週」と書く。「前後の」は N-3 の訳に、前のページと次のページとして書いてある）。「並べて」は côte à côte（横に並べて）で、「横に」と同じ | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | de・pt-BR | 隣のページを横につなぐ | ○ | 「前後の」が「隣の（隣り合う・隣接する）」。ページの並びで隣り合うのは前後のページなので、指す物は同じ（日本語の N-4〜N-7 も同じ物を「となりの週」と書く。「前後の」は N-3 の訳に、前のページと次のページとして書いてある） | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | es | 隣接するページを横方向につなぐ | ○ | 「前後の」が「隣の（隣り合う・隣接する）」。ページの並びで隣り合うのは前後のページなので、指す物は同じ（日本語の N-4〜N-7 も同じ物を「となりの週」と書く。「前後の」は N-3 の訳に、前のページと次のページとして書いてある） | ○ |
| `settings.page.span`（N-2） | 前後のページを横につなげる | it | 隣のページを横方向につなげる | ○ | 「前後の」が「隣の（隣り合う・隣接する）」。ページの並びで隣り合うのは前後のページなので、指す物は同じ（日本語の N-4〜N-7 も同じ物を「となりの週」と書く。「前後の」は N-3 の訳に、前のページと次のページとして書いてある） | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | en | 週と日のページでは、前後のページが横につながり、境目をまたいで書くことができます。月と年のページは、次のバージョンから順に対応します。これをオフにすると、これまでどおりページが1ページずつ表示されます。これをオフにしている端末では、ページをまたいで書いた線は片方のページにだけ表示されます（削除はされません）。 | ○ | 「月と年は」が「月と年のページは」（同じ物）。「消えてはいません」が「削除はされません」の形（1.2 の切り替えの文でも同じ扱い） | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | zh-Hans | 週ページと日ページでは、前後のページが横につながり、境目をまたいで書くことができます。月ページと年ページは、次のバージョンから順次対応します。オフにすると、以前と同じように1ページずつ表示されます。この項目をオフにしている端末では、ページをまたいで書いた線はそのうち1ページにしか表示されません（削除されたわけではありません）。 | ○ | 「順に」が「順次」。「消えてはいません」が「削除はされません」の形（1.2 の切り替えの文でも同じ扱い） | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | zh-Hant | 週ページと日ページでは、前後のページが横につながり、境目をまたいで書くことができます。月ページと年ページは、次のバージョンから順に対応します。オフにすると、以前と同じように1ページずつ表示されます。この項目をオフにしている端末では、ページをまたいで書いた線はそのうち1ページにしか表示されません（削除されたわけではありません）。 | ○ | 「消えてはいません」が「削除はされません」の形（1.2 の切り替えの文でも同じ扱い） | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | ko | 週ページと日ページでは、前後のページが横につながって、境目を越えて書けます。月ページと年ページは、次のバージョンから順に対応する予定です。オフにすると、これまでどおり1ページずつ表示されます。この設定をオフにした端末では、ページを越えて書いた線が片方のページにしか表示されません（消えてはいません）。 | ○ | 「対応します」が「対応する予定です」（지원할 예정이에요）。次の版の話なので、韓国語のふつうの言い方で意味は同じ。「境目をまたいで」が「境目を越えて」 | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | fr | 週と日のページでは、前のページと次のページが横に並んでつながり、つなぎ目の上にまたがって書くことができます。月と年のページは、次のバージョンから一つずつ順に対応します。このオプションがオフの場合は、以前と同じようにページが1ページずつ表示されます。これがオフになっている端末では、2ページにまたがって書いた線はそのうち一方にしか表示されません（削除されてはいません）。 | ○ | 「境目」が「つなぎ目」（jonction。ページとページのつなぎ目で、同じ所）。「順に」が「一つずつ順に」。「消えてはいません」が「削除はされません」の形（1.2 の切り替えの文でも同じ扱い）。判定の後、N-4〜N-7 の直しにそろえて境目の言い方を変えた（下の「× と直した訳」） | 直した（○） |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | de | 週ページと日ページでは、前のページと次のページが横につながり、境目を越えて書くことができます。月ページと年ページは、次のバージョンから順に対応します。これをオフにすると、これまでどおりページが1ページずつ表示されます。これをオフにしている端末では、ページをまたいで書いた線は2ページのうち片方にだけ表示されます（削除はされません）。 | ○ | 「境目をまたいで」が「境目を越えて」（über den Übergang hinweg）。「消えてはいません」が「削除はされません」の形（1.2 の切り替えの文でも同じ扱い） | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | es | 週と日のページでは、前のページと次のページが横方向につながり、つなぎ目の上から書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に広がっていきます。オフの場合は、これまでどおりページが1ページずつ表示されます。オフになっている端末では、2ページの間（にまたがって）書いた線は、どちらか一方にしか表示されません（削除はされません）。 | × | 「境目をまたいで書けます」が「つなぎ目の上から書くことができます」（por encima de la unión は、つなぎ目の上に重ねて書くとも読め、またぐことが伝わらない）。「ページをまたいで書いた線」が「2ページの間（にまたがって）書いた線」で、R が括弧で迷いを書いた（entre dos páginas は「2 ページの間に」とも読める） | 直した（○） |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | it | 週と日のページでは、前のページと次のページが横方向につながっていて、境目をまたいで書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に加わります。オフの場合は、以前と同じようにページが1ページずつ表示されます。オフになっている端末では、2ページにまたがって書いた線は、そのうち片方にしか表示されません（削除はされません）。 | ○ | 「月と年は、次の版から順に対応します」が「この機能は次のバージョンから、月と年のページにも一つずつ順番に加わります」（同じ）。「消えてはいません」が「削除はされません」の形（1.2 の切り替えの文でも同じ扱い） | ○ |
| `settings.page.span.footer`（N-3） | 週と日のページで、前後のページが横につながり、境目をまたいで書けます。月と年は、次の版から順に対応します。オフにすると、今までどおり 1 ページずつになります。オフにした端末では、ページをまたいで書いた線が片方のページにだけ出ます（消えてはいません）。 | pt-BR | 週と日のページでは、前のページと次のページが横につながった状態になり、つなぎ目の上から書くことができます。この機能は次のバージョンから、月と年のページにも一つずつ順番に広がります。オフのときは、以前と同じようにページが1ページずつ表示されます。この設定をオフにしている端末では、2ページの間（にまたがって）書いた線は、そのうち一方にしか表示されません（消されてはいません）。 | × | 「境目をまたいで書けます」が「つなぎ目の上から書くことができます」（por cima da emenda は、つなぎ目の上に重ねて書くとも読め、またぐことが伝わらない）。「ページをまたいで書いた線」が「2ページの間（にまたがって）書いた線」で、R が括弧で迷いを書いた（entre duas páginas は「2 ページの間に」とも読める） | 直した（○） |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | en | 前の週と次の週が横につながりました。指を横にすべらせると、隣の週が見えます。境目をまたいでそのまま書くことができます。 | ○ | 「出てきます」が「見えます」（指で横にすべらせて、となりの週〔日〕を出すことは同じ） | ○ |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | zh-Hans・zh-Hant | 前の週と次の週が横につながりました。指で横にスライドすると、隣の週が現れます。境目をまたいでそのまま書くことができます。 | ○ | 同じ | ○ |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | ko | 前後の週が横につながりました。指で横にスワイプすると、隣の週が出てきます。境目を越えてそのまま書けます。 | ○ | 「すべらせる」が「スワイプ」。「境目をまたいで」が「境目を越えて」 | ○ |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | fr | 前の週と次の週が、これからは横に並んでつながります。指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ | 直した（○） |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | de | 前の週と次の週が横につながるようになりました。指で横になぞると、隣の週が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き | 直した（○） |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | es | 前の週と次の週は、もう横方向につながっています。指を横方向にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ | 直した（○） |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | it | 前の週と次の週が、今は横方向につながっています。指を横方向にすべらせると、隣の週が見られます。境目をまたいでそのまま書くことができます。 | ○ | 「つながりました」が「今は横方向につながっています」（ora）。「出てきます」が「見られます」 | ○ |
| `span.guide.week.oneFinger`（N-4） | 前後の週が横につながりました。指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | pt-BR | 前の週と次の週が、今は横につながっています。指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ | 直した（○） |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | en | 前の週と次の週が横につながりました。2本の指を横にすべらせると、隣の週が見えます。境目をまたいでそのまま書くことができます。 | ○ | 「出てきます」が「見えます」（指で横にすべらせて、となりの週〔日〕を出すことは同じ） | ○ |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | zh-Hans・zh-Hant | 前の週と次の週が横につながりました。2本の指で横にスライドすると、隣の週が現れます。境目をまたいでそのまま書くことができます。 | ○ | 同じ | ○ |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | ko | 前後の週が横につながりました。2本の指で横にスワイプすると、隣の週が出てきます。境目を越えてそのまま書けます。 | ○ | 「すべらせる」が「スワイプ」。「境目をまたいで」が「境目を越えて」 | ○ |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | fr | 前の週と次の週が、これからは横に並んでつながります。2本の指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ | 直した（○） |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | de | 前の週と次の週が横につながるようになりました。2本の指で横になぞると、隣の週が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き | 直した（○） |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | es | 前の週と次の週は、もう横方向につながっています。2本の指を横方向にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ | 直した（○） |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | it | 前の週と次の週が、今は横方向につながっています。2本の指を横方向にすべらせると、隣の週が見られます。境目をまたいでそのまま書くことができます。 | ○ | 「つながりました」が「今は横方向につながっています」（ora）。「出てきます」が「見られます」 | ○ |
| `span.guide.week.twoFingers`（N-5） | 前後の週が横につながりました。2 本指で横にすべらせると、となりの週が出てきます。境目をまたいで、そのまま書けます。 | pt-BR | 前の週と次の週が、今は横につながっています。2本の指を横にすべらせると、隣の週が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ | 直した（○） |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | en | 前の日と次の日が横につながりました。指を横にすべらせると、隣の日が見えます。境目をまたいでそのまま書くことができます。 | ○ | 「出てきます」が「見えます」（指で横にすべらせて、となりの週〔日〕を出すことは同じ） | ○ |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | zh-Hans・zh-Hant | 前の日と次の日が横につながりました。指で横にスライドすると、隣の日が現れます。境目をまたいでそのまま書くことができます。 | ○ | 同じ | ○ |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | ko | 前後の日が横につながりました。指で横にスワイプすると、隣の日が出てきます。境目を越えてそのまま書けます。 | ○ | 「すべらせる」が「スワイプ」。「境目をまたいで」が「境目を越えて」 | ○ |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | fr | 前の日と次の日が、これからは横に並んでつながります。指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ | 直した（○） |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | de | 前の日と次の日が横につながるようになりました。指で横になぞると、隣の日が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き | 直した（○） |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | es | 前の日と次の日は、もう横方向につながっています。指を横方向にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ | 直した（○） |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | it | 前の日と次の日が、今は横方向につながっています。指を横方向にすべらせると、隣の日が見られます。境目をまたいでそのまま書くことができます。 | ○ | 「つながりました」が「今は横方向につながっています」（ora）。「出てきます」が「見られます」 | ○ |
| `span.guide.day.oneFinger`（N-6） | 前後の日が横につながりました。指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | pt-BR | 前の日と次の日が、今は横につながっています。指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ | 直した（○） |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | en | 前の日と次の日が横につながりました。2本の指を横にすべらせると、隣の日が見えます。境目をまたいでそのまま書くことができます。 | ○ | 「出てきます」が「見えます」（指で横にすべらせて、となりの週〔日〕を出すことは同じ） | ○ |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | zh-Hans・zh-Hant | 前の日と次の日が横につながりました。2本の指で横にスライドすると、隣の日が現れます。境目をまたいでそのまま書くことができます。 | ○ | 同じ | ○ |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | ko | 前後の日が横につながりました。2本の指で横にスワイプすると、隣の日が出てきます。境目を越えてそのまま書けます。 | ○ | 「すべらせる」が「スワイプ」。「境目をまたいで」が「境目を越えて」 | ○ |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | fr | 前の日と次の日が、これからは横に並んでつながります。2本の指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで、そのまま書けます」が「つなぎ目の上からそのまま書くことができます」（par-dessus la jonction は、つなぎ目の上に重ねて書く・上書きするとも読め、またいで書けることが伝わらない）。「つながりました」が「これからは横に並んでつながります」（désormais）は同じ | 直した（○） |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | de | 前の日と次の日が横につながるようになりました。2本の指で横になぞると、隣の日が見られます。境目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「境目の上から」（über den Übergang schreiben は、hinweg が無いと「境目の上に書く」とも「境目について書く」とも読める。N-3 は hinweg があり ○）。「なぞる」は streichen（横に動かす）で同じ動き | 直した（○） |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | es | 前の日と次の日は、もう横方向につながっています。2本の指を横方向にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書くことができます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por encima de la unión。N-3 と同じ）。「もう横方向につながっています」は ya（今は）で同じ | 直した（○） |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | it | 前の日と次の日が、今は横方向につながっています。2本の指を横方向にすべらせると、隣の日が見られます。境目をまたいでそのまま書くことができます。 | ○ | 「つながりました」が「今は横方向につながっています」（ora）。「出てきます」が「見られます」 | ○ |
| `span.guide.day.twoFingers`（N-7） | 前後の日が横につながりました。2 本指で横にすべらせると、となりの日が出てきます。境目をまたいで、そのまま書けます。 | pt-BR | 前の日と次の日が、今は横につながっています。2本の指を横にすべらせると、隣の日が見られます。つなぎ目の上からそのまま書けます。 | × | 「境目をまたいで」が「つなぎ目の上から」（por cima da emenda。N-3 と同じ）。「今は横につながっています」（agora）は同じ | 直した（○） |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | en | このページは線がとても多いため、横につなげる代わりに1ページずつ表示しています。書いた内容はそのまま残っています。 | ○ | 同じ | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | zh-Hans・zh-Hant | このページは線が非常に多いため、横にはつなげず、1ページずつ表示します。書いた内容はそのままです。 | ○ | 同じ | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | ko | このページは線がとても多いので、横につながずに1ページずつ表示します。書いた内容はそのままです。 | ○ | 同じ | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | fr | このページにはとても多くの線があるため、ページはつながらずに1ページずつ表示されます。書いた内容は損なわれずにそのまま残ります。 | ○ | 「横につなげずに」の「横に」が無い（sans être reliées）。この案内の「つなげる」は横につなげることだけで、1 ページずつとの対比も残るので、意味は同じ。「損なわれずに」は reste intact | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | de | このページには線がとても多いため、ページは横につながらず、1ページずつ表示されます。書いた内容は保持されます。 | ○ | 「書いたものはそのままです」が「書いた内容は保持されます」（bleibt erhalten） | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | es | このページには線が非常に多いので、ページはつなげずに1ページずつ表示されます。書いた内容はそのまま保たれます。 | ○ | 「横につなげずに」の「横に」が無い（sin unirlas）。この案内の「つなげる」は横につなげることだけで、1 ページずつとの対比も残るので、意味は同じ | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | it | このページには線が非常に多いので、ページはつなげずに1ページずつ表示されます。書いた内容はそのままです。 | ○ | 「横につなげずに」の「横に」が無い（senza unirle）。この案内の「つなげる」は横につなげることだけで、1 ページずつとの対比も残るので、意味は同じ | ○ |
| `span.stageTwo.notice`（N-8） | このページは線がとても多いので、横につなげずに 1 ページずつ表示しています。書いたものはそのままです。 | pt-BR | このページには線がものすごく多いので、ページはつながらずに1ページずつ表示されます。書いた内容は変わらずそのままです。 | ○ | 「横につなげずに」の「横に」が無い（sem ficar unidas）。この案内の「つなげる」は横につなげることだけで、1 ページずつとの対比も残るので、意味は同じ。「ものすごく多い」は muitíssimos（とても多い） | ○ |

### 境目と札の長さ

- 直した後の各言語の「境目をまたいで書ける」: en write (straight) across the boundary ／ zh-Hans 跨过交界处 ／ zh-Hant 跨越交界處 ／ ko 경계를 넘어 ／ fr à cheval sur la jonction ／ de über den Übergang hinweg ／ es cruzando la unión ／ it a cavallo del confine ／ pt-BR atravessando a emenda。「ページをまたいで書いた線」: fr à cheval sur deux pages ／ es de una página a otra ／ pt-BR de uma página para a outra（ほかの言語は変えていない）。
- 札（N-4〜N-7）の長さ: この Mac の CoreText のシステムの字（13 pt。iOS のシミュレータではない）で、iPhone の縦の文の幅 315 pt でラテン系 6 言語は 4 行、zh・ko は 2 行（ja は 3 行）、iPad の 492 pt で 3 行以内です（直す前と同じ）。fr の週の 2 本指の札は、幅が 310 pt だと 5 行になります（直す前の字も同じ）。本当の見え方は、10 言語の写真（§10.5 の span-shots）か TestFlight で確かめます。段 2 の案内（N-8）は変えていません。

### lint

直した後の字で、`lint.py`（L-1〜L-14）・`build.py --check`・`baseline.py --check` は 3 つとも終了 0 です（`baseline.py` は 9cbc3c9 の 516 字のまま。L-12 の字の幅の目安の警告は 58 件で、直す前と同じ）。`Localizable.xcstrings` は `build.py` で作り直しました（471 キー。ja 471、ほかの 9 言語は各 438 で、残りの 33 キーは訳さない試作の文）。

### 元を見ない逆翻訳（2 回目。照合の後に直した 19 件、2026-11-13）

上の「× と直した訳」の 19 件（fr・es・pt-BR の N-3〜N-7、de の N-4〜N-7）の今の字だけを、R にもう 1 回渡しました。渡したのは key・言語・訳の表だけで、日本語の元・comment・1 回目の逆翻訳は入っていません。同じ表に、11 のサポートの英語の 1 文（the App's を足した文）も入れました（その判定は 11 の「元を見ない逆翻訳（2 回目）」）。判定は、訳を直した Claude とも R とも別の Claude が、逆翻訳と固定の日本語（`tools/l10n/source/app-U.json`）を 1 件ずつ照らしたものです。判定は 1 回目と同じ ○ と × の 2 つです。**母語の人の確認ではありません。**

**結果: ○ 19・× 0。** 直した所は 19 件とも、「つなぎ目をまたいで（書ける）」「ページをまたいで書いた線」「2 ページのうち一方」と読まれました。1 回目の「つなぎ目（境目）の上から書く」「2 ページの間に書いた線」の読みは、もう出ませんでした。直していない所も 1 回目と同じ意味に読まれ、抜けた事実も、元に無い事実もありません。訳は変えていません（札の長さも変わらないので、測り直していません）。

| 言語 | 件数 | ○ | × |
| --- | --- | --- | --- |
| fr | 5 | 5 | 0 |
| de | 4 | 4 | 0 |
| es | 5 | 5 | 0 |
| pt-BR | 5 | 5 | 0 |
| 合計 | 19 | 19 | 0 |

- R がメモに書いた別の読み（どれも 1 回目から変えていない語で、R の訳はいちばん自然な読みで元と同じ）: fr の sur le côté（「画面の端で」とも）、de の seitlich verbunden（何と何がつながるのか書かれていない。日本語の元も同じ書き方）、de の direkt（「すぐに」とも）、es の ya（「前からつながっていた」とも）、es の N-3 の Si está desactivado（直前の La función と性が合わない）、pt-BR の emenda（やや素朴な語）。直すと 3 回目の逆翻訳が要るので、直していません。母語の人に見てもらうときの候補にします。
- fr・es・pt-BR の N-3 の「次の版から順に」の 2 通りの読み（次の版から 1 つずつ／次の版で両方）は、日本語の元も同じ幅の言い方です（M7C.md の第 4 陣の決定 2）。
- `docs/i18n/back/fr.json`・`de.json`・`es.json`・`pt-BR.json` の 19 キーは、`text` を今の字に、`back` をこの 2 回目の逆翻訳に替えました（1 回目の逆翻訳は、上の「× と直した訳」の表にあります）。

| キー | 言語 | 訳 | 逆翻訳（元を見ない、2 回目） | 判定 | 理由 |
| --- | --- | --- | --- | --- | --- |
| `settings.page.span.footer`（N-3） | fr | Sur les pages de la semaine et du jour, les pages précédente et suivante sont reliées côte à côte, et vous pouvez écrire à cheval sur la jonction. Les pages du mois et de l’année seront prises en charge l’une après l’autre à partir de la prochaine version. Si cette option est désactivée, les pages s’affichent une par une, comme avant. Sur un appareil où elle est désactivée, les traits écrits à cheval sur deux pages n’apparaissent que sur l’une d’elles (ils ne sont pas supprimés). | 週と日のページでは、前後のページが横に並んでつながり、つなぎ目をまたいで書くことができます。月と年のページは、次のバージョンから順に対応します。このオプションをオフにすると、以前と同じようにページは1ページずつ表示されます。オフにしている端末では、2ページにまたがって書いた線は、どちらか一方のページにしか表示されません（削除はされません）。 | ○ | 「境目をまたいで書けます」が「つなぎ目をまたいで書くことができます」（à cheval sur la jonction。直した所が伝わった）。「横につながり」が「横に並んでつながり」（côte à côte）。「月と年は」が「月と年のページは」（同じ物）。「消えてはいません」が「削除はされません」の形（1 回目と同じ扱い）。R は l’une après l’autre à partir de la prochaine version を「次の版から 1 つずつ」とも「次の版で両方が順に」とも読めると書いたが、日本語の元の「次の版から順に」も同じ幅の言い方で、事実は変わらない（この文は直していない。元の言い方の話は M7C.md の第 4 陣の決定 2） |
| `settings.page.span.footer`（N-3） | es | En las páginas de la semana y del día, las páginas anterior y siguiente se unen en horizontal y puede escribir cruzando la unión. La función llegará a las páginas del mes y del año, una tras otra, a partir de la próxima versión. Si está desactivado, las páginas se muestran de una en una, como hasta ahora. En un dispositivo donde esté desactivado, los trazos escritos de una página a otra solo aparecen en una de las dos (no se eliminan). | 週と日のページでは、前後のページが横につながり、つなぎ目をまたいで書くことができます。この機能は次のバージョンから、月と年のページにも順に広がります。オフにすると、これまでどおりページは1ページずつ表示されます。オフにしている端末では、ページをまたいで書いた線は2ページのうち一方にしか表示されません（削除はされません）。 | ○ | 「境目をまたいで書けます」が「つなぎ目をまたいで書くことができます」（cruzando la unión。直した所が伝わった）。「ページをまたいで書いた線」（de una página a otra）と「片方のページ」（2 ページのうち一方、una de las dos）も、直したとおりに読まれた。「月と年は、次の版から順に対応します」が「この機能は次のバージョンから、月と年のページにも順に広がります」（同じ）。「消えてはいません」が「削除はされません」の形。R は La función（女性の名詞）の後の Si está desactivado（男性の形）で性が合わないと書いた。主語はスイッチ（設定）と補って読め、R の訳も「オフにすると」なので、意味は同じ（この文は 1 回目から変えていない） |
| `settings.page.span.footer`（N-3） | pt-BR | Nas páginas da semana e do dia, as páginas anterior e seguinte ficam unidas na horizontal, e você pode escrever atravessando a emenda. O recurso chegará às páginas do mês e do ano, uma depois da outra, a partir da próxima versão. Quando desativado, as páginas aparecem uma por vez, como antes. Em um dispositivo com o ajuste desativado, os traços escritos de uma página para a outra aparecem só em uma das duas (não são apagados). | 週と日のページでは、前後のページが横につながっていて、つなぎ目をまたいで書くことができます。この機能は次のバージョンから、月と年のページにも順に対応します。オフのときは、以前と同じようにページが1ページずつ表示されます。この設定をオフにしている端末では、ページをまたいで書いた線は2ページのうち一方にしか表示されません（消えるわけではありません）。 | ○ | 「境目をまたいで書けます」が「つなぎ目をまたいで書くことができます」（atravessando a emenda。直した所が伝わった）。「ページをまたいで書いた線」（de uma página para a outra）と「2 ページのうち一方」（uma das duas）も、直したとおりに読まれた。「横につながり」が「横につながっていて」。「消えてはいません」が「消えるわけではありません」。R は emenda が布や板の継ぎ目を思わせる、やや素朴な語だと書いたが、意味は通じる（この語は 1 回目から同じで、M7C.md の第 4 陣で決めた語） |
| `span.guide.week.oneFinger`（N-4） | fr | Les semaines précédente et suivante sont désormais reliées côte à côte. Faites glisser le doigt sur le côté pour voir la semaine voisine. Vous pouvez écrire directement à cheval sur la jonction. | 前後の週が横に並んでつながるようになりました。指を横にすべらせると、隣の週が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「横に並んでつながるようになりました」（désormais、côte à côte）。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（à cheval sur la jonction。直した所が伝わった）。R は sur le côté を「画面の端で」とも読めると書いたが、いちばん自然な読みは「横に」で、R の訳もそう読んだ（この語は 1 回目から変えていない） |
| `span.guide.week.oneFinger`（N-4） | de | Vorherige und nächste Woche sind jetzt seitlich verbunden. Streichen Sie mit dem Finger seitwärts, um die Woche daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の週と次の週が、横につながるようになりました。指で横にスワイプすると、隣の週が見られます。つなぎ目をまたいで、そのまま書くことができます。 | ○ | 「前後の週」が「前の週と次の週」（同じ）。「つながりました」が「つながるようになりました」（jetzt）。「すべらせる」が「スワイプ」（seitwärts streichen。同じ動き）。「出てきます」が「見られます」。「境目をまたいで」が「つなぎ目をまたいで」（über den Übergang hinweg。直した所が伝わった。語の並びを変えた文も、そのまま読まれた）。R は何と何がつながるのか書かれていないと書いたが、日本語の元の「前後の週が横につながりました」も同じ書き方で、事実は変わらない。direkt は「そのまま」と読まれた |
| `span.guide.week.oneFinger`（N-4） | es | Las semanas anterior y siguiente ya están unidas en horizontal. Deslice el dedo en horizontal para ver la semana contigua. Puede escribir directamente cruzando la unión. | 前後の週が横につながるようになりました。指を横にスライドすると、隣の週が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（ya）。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（cruzando la unión。直した所が伝わった）。R は ya を「前からつながっていた」とも取れなくはないと書いたが、自然な読みは新しくつながったことで、R の訳もそう読んだ（1 回目と同じ）。en horizontal が 2 回続くのは言い回しの話 |
| `span.guide.week.oneFinger`（N-4） | pt-BR | As semanas anterior e seguinte agora estão unidas na horizontal. Deslize o dedo na horizontal para ver a semana ao lado. Você pode escrever direto atravessando a emenda. | 前後の週が横につながるようになりました。指を横にスライドすると、隣の週が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（agora）。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（atravessando a emenda。直した所が伝わった）。direto は口語の「そのまま」。emenda の語感は N-3 と同じ |
| `span.guide.week.twoFingers`（N-5） | fr | Les semaines précédente et suivante sont désormais reliées côte à côte. Faites glisser deux doigts sur le côté pour voir la semaine voisine. Vous pouvez écrire directement à cheval sur la jonction. | 前後の週が横に並んでつながるようになりました。2本の指を横にすべらせると、隣の週が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「横に並んでつながるようになりました」（désormais、côte à côte）。「2 本指で」が「2 本の指を」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（à cheval sur la jonction。直した所が伝わった）。R は sur le côté を「画面の端で」とも読めると書いたが、いちばん自然な読みは「横に」で、R の訳もそう読んだ（この語は 1 回目から変えていない） |
| `span.guide.week.twoFingers`（N-5） | de | Vorherige und nächste Woche sind jetzt seitlich verbunden. Streichen Sie mit zwei Fingern seitwärts, um die Woche daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の週と次の週が、横につながるようになりました。2本の指で横にスワイプすると、隣の週が見られます。つなぎ目をまたいで、そのまま書くことができます。 | ○ | 「前後の週」が「前の週と次の週」（同じ）。「つながりました」が「つながるようになりました」（jetzt）。「2 本指で」が「2 本の指で」。「すべらせる」が「スワイプ」（seitwärts streichen。同じ動き）。「出てきます」が「見られます」。「境目をまたいで」が「つなぎ目をまたいで」（über den Übergang hinweg。直した所が伝わった。語の並びを変えた文も、そのまま読まれた）。R は何と何がつながるのか書かれていないと書いたが、日本語の元の「前後の週が横につながりました」も同じ書き方で、事実は変わらない。direkt は「そのまま」と読まれた |
| `span.guide.week.twoFingers`（N-5） | es | Las semanas anterior y siguiente ya están unidas en horizontal. Deslice dos dedos en horizontal para ver la semana contigua. Puede escribir directamente cruzando la unión. | 前後の週が横につながるようになりました。2本の指を横にスライドすると、隣の週が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（ya）。「2 本指で」が「2 本の指を」。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（cruzando la unión。直した所が伝わった）。R は ya を「前からつながっていた」とも取れなくはないと書いたが、自然な読みは新しくつながったことで、R の訳もそう読んだ（1 回目と同じ）。en horizontal が 2 回続くのは言い回しの話 |
| `span.guide.week.twoFingers`（N-5） | pt-BR | As semanas anterior e seguinte agora estão unidas na horizontal. Deslize dois dedos na horizontal para ver a semana ao lado. Você pode escrever direto atravessando a emenda. | 前後の週が横につながるようになりました。2本の指を横にスライドすると、隣の週が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（agora）。「2 本指で」が「2 本の指を」。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（atravessando a emenda。直した所が伝わった）。direto は口語の「そのまま」。emenda の語感は N-3 と同じ |
| `span.guide.day.oneFinger`（N-6） | fr | Les jours précédent et suivant sont désormais reliés côte à côte. Faites glisser le doigt sur le côté pour voir le jour voisin. Vous pouvez écrire directement à cheval sur la jonction. | 前後の日が横に並んでつながるようになりました。指を横にすべらせると、隣の日が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「横に並んでつながるようになりました」（désormais、côte à côte）。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（à cheval sur la jonction。直した所が伝わった）。R は sur le côté を「画面の端で」とも読めると書いたが、いちばん自然な読みは「横に」で、R の訳もそう読んだ（この語は 1 回目から変えていない） |
| `span.guide.day.oneFinger`（N-6） | de | Vorheriger und nächster Tag sind jetzt seitlich verbunden. Streichen Sie mit dem Finger seitwärts, um den Tag daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の日と次の日が、横につながるようになりました。指で横にスワイプすると、隣の日が見られます。つなぎ目をまたいで、そのまま書くことができます。 | ○ | 「前後の日」が「前の日と次の日」（同じ）。「つながりました」が「つながるようになりました」（jetzt）。「すべらせる」が「スワイプ」（seitwärts streichen。同じ動き）。「出てきます」が「見られます」。「境目をまたいで」が「つなぎ目をまたいで」（über den Übergang hinweg。直した所が伝わった。語の並びを変えた文も、そのまま読まれた）。R は何と何がつながるのか書かれていないと書いたが、日本語の元の「前後の日が横につながりました」も同じ書き方で、事実は変わらない。direkt は「そのまま」と読まれた |
| `span.guide.day.oneFinger`（N-6） | es | Los días anterior y siguiente ya están unidos en horizontal. Deslice el dedo en horizontal para ver el día contiguo. Puede escribir directamente cruzando la unión. | 前後の日が横につながるようになりました。指を横にスライドすると、隣の日が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（ya）。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（cruzando la unión。直した所が伝わった）。R は ya を「前からつながっていた」とも取れなくはないと書いたが、自然な読みは新しくつながったことで、R の訳もそう読んだ（1 回目と同じ）。en horizontal が 2 回続くのは言い回しの話 |
| `span.guide.day.oneFinger`（N-6） | pt-BR | Os dias anterior e seguinte agora estão unidos na horizontal. Deslize o dedo na horizontal para ver o dia ao lado. Você pode escrever direto atravessando a emenda. | 前後の日が横につながるようになりました。指を横にスライドすると、隣の日が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（agora）。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（atravessando a emenda。直した所が伝わった）。direto は口語の「そのまま」。emenda の語感は N-3 と同じ |
| `span.guide.day.twoFingers`（N-7） | fr | Les jours précédent et suivant sont désormais reliés côte à côte. Faites glisser deux doigts sur le côté pour voir le jour voisin. Vous pouvez écrire directement à cheval sur la jonction. | 前後の日が横に並んでつながるようになりました。2本の指を横にすべらせると、隣の日が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「横に並んでつながるようになりました」（désormais、côte à côte）。「2 本指で」が「2 本の指を」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（à cheval sur la jonction。直した所が伝わった）。R は sur le côté を「画面の端で」とも読めると書いたが、いちばん自然な読みは「横に」で、R の訳もそう読んだ（この語は 1 回目から変えていない） |
| `span.guide.day.twoFingers`（N-7） | de | Vorheriger und nächster Tag sind jetzt seitlich verbunden. Streichen Sie mit zwei Fingern seitwärts, um den Tag daneben zu sehen. Über den Übergang hinweg können Sie direkt schreiben. | 前の日と次の日が、横につながるようになりました。2本の指で横にスワイプすると、隣の日が見られます。つなぎ目をまたいで、そのまま書くことができます。 | ○ | 「前後の日」が「前の日と次の日」（同じ）。「つながりました」が「つながるようになりました」（jetzt）。「2 本指で」が「2 本の指で」。「すべらせる」が「スワイプ」（seitwärts streichen。同じ動き）。「出てきます」が「見られます」。「境目をまたいで」が「つなぎ目をまたいで」（über den Übergang hinweg。直した所が伝わった。語の並びを変えた文も、そのまま読まれた）。R は何と何がつながるのか書かれていないと書いたが、日本語の元の「前後の日が横につながりました」も同じ書き方で、事実は変わらない。direkt は「そのまま」と読まれた |
| `span.guide.day.twoFingers`（N-7） | es | Los días anterior y siguiente ya están unidos en horizontal. Deslice dos dedos en horizontal para ver el día contiguo. Puede escribir directamente cruzando la unión. | 前後の日が横につながるようになりました。2本の指を横にスライドすると、隣の日が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（ya）。「2 本指で」が「2 本の指を」。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（cruzando la unión。直した所が伝わった）。R は ya を「前からつながっていた」とも取れなくはないと書いたが、自然な読みは新しくつながったことで、R の訳もそう読んだ（1 回目と同じ）。en horizontal が 2 回続くのは言い回しの話 |
| `span.guide.day.twoFingers`（N-7） | pt-BR | Os dias anterior e seguinte agora estão unidos na horizontal. Deslize dois dedos na horizontal para ver o dia ao lado. Você pode escrever direto atravessando a emenda. | 前後の日が横につながるようになりました。2本の指を横にスライドすると、隣の日が見られます。つなぎ目をまたいで、そのまま書けます。 | ○ | 「つながりました」が「つながるようになりました」（agora）。「2 本指で」が「2 本の指を」。「すべらせる」が「スライド」。「出てきます」が「見られます」。「境目をまたいで、そのまま書けます」が「つなぎ目をまたいで、そのまま書けます」（atravessando a emenda。直した所が伝わった）。direto は口語の「そのまま」。emenda の語感は N-3 と同じ |
