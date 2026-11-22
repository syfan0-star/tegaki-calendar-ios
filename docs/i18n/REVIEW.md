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

### 1.3 の週のメモの文（新機能の文の 2 つ目の点と K-8 の句の案、2026-11-18）

元は `docs/store/source-ja/whatsnew.txt` の 2 つ目の点（[M7C_CONTRACT.md](../M7C_CONTRACT.md) §8.3 の固定の行「・週のページにも、24 時の下に自由メモができました。」。ja と同じ字）と、その行に K-8（契約 §6.2・§6.5 の「週の下のメモ」の行）の句を足した案（`docs/store/PROPOSALS_1_3.md` の 4「・週のページにも、24 時の下に自由メモができました（古い版の端末では見えませんが、消えてはいません）。」。本人の確認ページで選んでもらう）です。11 組（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・es-MX・es-ES・pt-PT）の訳は、文の書き手の Claude が書きました（14074ba）。R には各ロケールの訳の 2 つの文だけを渡し、日本語の元を見ずに訳し戻してもらいました。判定は、書き手とも R とも別の Claude です（1 回目と 2 回目は、また別の Claude）。母語の人の確認ではありません。逆翻訳の全文と R の注は `docs/i18n/back/store-<ロケール>.md` の「1.3 の週のメモの文」にあります。en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`locales.json` の `copyOf`）。

判定は 1.2 と同じ **○**（同じ意味）／**△**（言い回しの差。意味は同じ）／**×**（意味の違い、または元に無い読みを招く。直す）です。

**1 回目**: 2 つ目の点は 11 組とも ○。K-8 の案は ○ 7・△ 1（fr-FR）・× 3（ko・zh-Hans・zh-Hant）。× の 3 件は、括弧の「古い版の端末」の訳（이전 버전의 기기・旧版本的设备・舊版本的裝置）が「古い型の端末（機種）」とも読めることでした（R の注）。そう読むと「古い機種では見えない」という元に無い事実になるので、3 件を「古い版を使う端末」（이전 버전을 쓰는 기기・使用旧版本的设备・使用舊版本的裝置）に直しました（6ac0d1c）。

**2 回目**（直した 3 件の今の字だけを R にもう 1 回渡した。R は 1 回目の字・逆翻訳・日本語の元を見ていない）: ko は ○。zh-Hans・zh-Hant は、括弧は「旧バージョンを使っている端末」と読まれ、古い型の読みは出ませんでした（○）。ただ、括弧の前の「24 点以下」「24 點以下」を、R が 1 回目に続いてもう一度、位置の「下」より数の「24 時以下（24 時まで）」と読まれやすく、紙の下側という意味が伝わりにくいと挙げ、誤解の無い語として「24 点下方」を示しました。**最後の判定で、この点を × とし、zh-Hans・zh-Hant の 2 つ目の点（今の `whatsnew.txt`）と K-8 の案の両方を「24 点下方」「24 點下方」に直しました。** 最後の回なので、直した字は元を見ない逆翻訳を通していません（下の「決まっていないこと」）。**その後、リードが 11/18 に 3 回目として、直した 4 文（2 つ目の点と K-8 の案の zh-Hans・zh-Hant）だけを別の Claude に元を渡さずに訳し戻してもらい、4 文とも「24 時の下に」と読まれました（○。逆翻訳と注は `docs/i18n/back/store-zh-*.md` の「3 回目」の行）。**

1 回目の判定は、この点を ○ にしていました。アプリのトースト（`toast.eventBelowDay`「24 点以下的自由备忘栏不能创建日程」、1.2 で ○）が同じ字を使うことと、時刻はどれも 24 時以下なので時刻の幅として読むと意味をなさないことが理由で、母語の人に見てもらうときの候補にとどめていました。2 回目は別の R が別に読んで、同じ点を「読まれやすい」とより強く挙げました。新機能の文は「何が・どこに」できたかを伝える 1 行で、その「どこ」が「24 時までの欄」と読まれると元に無い事実になります。直しは 2 字（以下 → 下方）で、指すものは変わらず、どちらの読みでも元と同じ意味になる形です。案と今の 2 つ目の点は、括弧の前が 1 字も違わない形のままです。

2 つ目の点（今の `whatsnew.txt`）:

| ロケール | 1 回目 | 最後 | 理由・見たこと |
| --- | --- | --- | --- |
| en-US | ○ | ○ | 「」と「欄」が付いた（Free Notes area）。アプリの見出し（`paper.freeMemo`）と SUPPORT の言い方（the “Free Notes” area）に合わせた形で、指すものは同じ |
| zh-Hans | ○ | **直した**（24 点以下 → 24 点下方） | 「新しく加わりました」は「できました」と同じ意味。「24 点以下」は上のとおり、2 回目の判定で直した。「现在也在……新增了」が少しくどい（R の注）のは言い回しで、意味は同じなので変えていない |
| zh-Hant | ○ | **直した**（24 點以下 → 24 點下方） | zh-Hans と同じ |
| ko | ○ | ○ | 元と同じ。자유 메모 칸はアプリのトーストと同じ語 |
| fr-FR | ○ | ○ | 「sous 24:00」はアプリのトースト（1.2 で ○）と同じ字。「24 時未満」とも取れる・「24 h」が普通という R の注は、母語の人に見てもらうときの候補 |
| de-DE | ○ | ○ | 「unter 24:00」はアプリのトーストと同じ字。「24 時前」とも読める・「24:00 Uhr」が普通という R の注は、母語の人に見てもらうときの候補 |
| it | ○ | ○ | 「sotto le 24:00」はアプリのトーストと同じ字 |
| pt-BR | ○ | ○ | 「abaixo de 24:00」はアプリのトーストと同じ字（pt-PT は das）。「das」の方が自然という R の注は、母語の人に見てもらうときの候補 |
| es-MX | ○ | ○ | 元と同じ |
| es-ES | ○ | ○ | 元と同じ（es-MX と同じ字） |
| pt-PT | ○ | ○ | 「加わりました」（passam também a ter）は「できました」と同じ意味 |

K-8 の句を足した案（`PROPOSALS_1_3.md` の 4。括弧の前は上の 2 つ目の点と同じ字）:

| ロケール | 1 回目 | 2 回目 | 最後 | 理由・見たこと |
| --- | --- | --- | --- | --- |
| en-US | ○ | — | ○ | 古い版の端末では見えない・消えていない、が同じ。older version がアプリか OS か、消えていないのが欄か中身か、のあいまいさ（R の注）は、元の「古い版の端末」「消えてはいません」にも同じだけある。新機能の文の中なので、version はアプリの版と読める |
| de-DE | ○ | — | ○ | en と同じ。unter 24:00 は今の 2 つ目の点の字のまま |
| es-MX | ○ | — | ○ | no se eliminó は 5 つ目の点（no se eliminaron）と同じ形 |
| es-ES | ○ | — | ○ | no se ha eliminado は 5 つ目の点と同じ形 |
| fr-FR | △ | — | △ | restés（のまま）が足された。古い版の端末は、まだ新しくしていない端末のことなので同じ（11 の still と同じ扱い） |
| it | ○ | — | ○ | 元と同じ |
| ko | ×（이전 버전의 기기） | ○ | ○ | 1 回目: 「古い型の機器」とも読める（元に無い読み）ので「이전 버전을 쓰는 기기」に直した。2 回目: 「以前のバージョンを使っている端末」と読まれた。주 페이지の「주」が単独では「主」とも読めるという R の注は、24시・메모と並ぶ文の中では週と読め、今の 2 つ目の点・1 つ目の点（주 페이지와 일 페이지）・アプリの訳（주 페이지）と同じ語なので変えていない |
| pt-BR | ○ | — | ○ | 元と同じ。abaixo de 24:00 は今の 2 つ目の点の字のまま |
| pt-PT | ○ | — | ○ | 元と同じ |
| zh-Hans | ×（旧版本的设备） | 括弧は ○、「24 点以下」は × | **直した**（24 点以下 → 24 点下方） | 1 回目: 「古い型の端末」とも読めるので「使用旧版本的设备」に直した。2 回目: 括弧は「旧バージョンを使っている端末」と読まれた。「24 点以下」は上のとおり最後の判定で直した（今の 2 つ目の点も同じ直し） |
| zh-Hant | ×（舊版本的裝置） | 括弧は ○、「24 點以下」は × | **直した**（24 點以下 → 24 點下方） | zh-Hans と同じ（使用舊版本的裝置、24 點下方） |

決まっていないこと（判定には入れていない）:

- **zh-Hans・zh-Hant の「24 点下方」「24 點下方」**は、最後の判定で直した字です。リードが 11/18 に 3 回目の元を見ない逆翻訳に通し、4 文とも意味が合いました（○）。そのときの注（「24 点」より「24:00」が普通、K-8 の括弧の主語）は、母語の人に見てもらうときの候補です。
- **アプリのトーストの「24 点以下」「24 點以下」**（`toast.eventBelowDay`、`tools/l10n/translations/zh-Hans.json`・`zh-Hant.json`）は、この段の文の持ち物でないので変えていません。新機能の文と同じ読みのおそれがあるので、直すかはリードが決めます（直すなら訳のファイルと `build.py`、L10nTests）。リードの決定（11/18）: 今はそろえない。トーストは予定を作ろうとしたその場で出るので位置は取り違えにくい。母語の人に見てもらうときの候補に足す（[M7C.md](../M7C.md)「週のメモの作る段のリードの決定」の 4）。
- **fr・de・it・pt-BR の「sous・unter・sotto le・abaixo de 24:00」**も、1 回目の R が「24 時前・24 時未満とも読める」と挙げました（2 回目には回していない）。アプリのトースト（1.2 で ○）と同じ字で、判定は ○ のままです。zh と同じ考えで直すかは、母語の人の確認かリードの判断を待ちます。
- 新機能の文の **2 つ目の点に K-8 の句を足すか**は、本人の確認ページで選んでもらいます（週のメモの計画の決めどころ 8）。どちらを選んでも、上の判定の字のまま入れられます。

### 1.3 の H1 の点の新しい文と審査メモの直し（2026-11-19）

元は 2 つです。(1) `docs/store/source-ja/whatsnew.txt` の 4 つ目の点（ja と同じ字。[M7C_CONTRACT.md](../M7C_CONTRACT.md) §8.3 の H1 の行の文）「・1.2.4 の直しに続いて、ほかの端末で手書きを全て消したあと、この端末の画面に残っていた手書きが iCloud に戻ってしまうことがありうる問題も直しました。」。1.2.4（2026-11-19 公開）の 2 つ目の点が、1.3 の前の H1 の点（上の「1.3 の新機能の文と審査メモ」の 3）と同じ文と訳だった（1.2.4 では H4 の直しの点）ので 1.2.4 の公開の後に外し（92caae1）、1.2.4 に H1 の直しは入っていないので、リードの決定 (a)（[M7C.md](../M7C.md) の「main（1.2.4）の取り込みと新機能の文の H1 の点」）で、1.2.4 の文と食い違わない新しい文にして戻したものです（2c1fdf6）。(2) 審査メモ `docs/store/review-note.txt` の「What is new in 1.3」の直した 4 つの文（確認ページの文の仕事、M7C.md の「週のメモの見直しのリードの決定」の 4）について書き手が書いた日本語の意味と、日本語の要約です。

R には、11 組（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・es-MX・es-ES・pt-PT）の新しい点の 1 文と、審査メモの直した英語の 4 文だけを渡し、日本語の元を見ずに訳し戻してもらいました（前後の文は渡していない）。判定は、文を書いた Claude とも R とも別の Claude が、逆翻訳と日本語の元を照らしたものです。母語の人の確認ではありません。逆翻訳の全文と R の注は `docs/i18n/back/store-<ロケール>.md` の「1.3 の H1 の点の新しい文」と `store-review-note.md` の「1.3 の直し（2026-11-19）」にあります。en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`locales.json` の `copyOf`）。

判定は上と同じ ○／△／× です。とくに、(i) 1.2.4 で出した直しを 1.3 の新しい直しのように言っていないか、(ii) 手書きが消える（失われる）と読めないか、を見ました。

**× は 1 回目から 0 件でした。直した字はありません。** 新機能の文の新しい点は 11 組とも ○、審査メモの直した 4 つの文は ○ 2・△ 2 です。抜けた事実も、元に無い事実もありませんでした。(i) と (ii) に当たる読みは、どの文にもありませんでした。

機械で照らしたこと:

- 11 組とも、新しい点は「1.2.4 の直し」と「〜も」（also・auch・también・également・anche・도・也）を持ち、1.2.4 の直しに続く別の直しと読める形です。
- 「手書きを全て消した」の動詞は、92caae1 で外した前の H1 の点（上の 3 で ○）と同じ語で、アプリの「全て消す」（`settings.data.erase.all`）の訳の動詞とも同じです（erase・löschen・borrar・effacer・cancellare・지우다・apagar・抹掉・清除）。「手書き」の語も前の点と同じです。it は前の「dopo la cancellazione di」を「una volta cancellata」に、ko は「지웠을 때（消したとき）」を「지운 뒤（消したあと）」にしました（元の「消したとき」→「消したあと」と同じ替え方）。
- 新しい点で前の点から増えた語は、「1.2.4 の直しに続いて」「も」と「画面に」（on the screen・auf dem Bildschirm・en la pantalla・à l’écran・sullo schermo・화면에・na tela・no ecrã・屏幕上・螢幕上）だけです（de-DE などの語順の入れ替えと、上の it・ko の替え方を除く）。
- 審査メモの Erase All・Erase and Start・Undo・Free Notes は en の訳（`tools/l10n/translations/en.json`）と同じ語です。審査メモは 3,683 字・3,993 バイト（最後の改行を除く。`docs/store/README.md` の数え方）で、L-9 は ok です。

新機能の文の新しい点（4 つ目の点）:

| ロケール | 判定 | 理由・見たこと |
| --- | --- | --- |
| en-US | ○ | 逆翻訳は元とほぼ同じ字。Following が時の「後」とも「続き」とも読める（R の注）のは、元の「続いて」にも両方の読みがある。「iCloud に戻る」で何が困るか伝わりにくい（R の注）のは元と同じ書き方で、前の H1 の点と同じ（上の 3 で ○）。also で、1.2.4 の直しに足した直しと読める |
| de-DE | ○ | 元と同じ意味。landen（行き着く）・alle Handschrift・löschen と nachdem 節を文末に置く形（R の注）は、前の H1 の点と同じ字（上の 3 で ○。「再び iCloud に入る」も、手書きが iCloud に戻ること）。löschen はアプリの「全て消す」（Alles löschen）と同じ動詞 |
| es-MX | ○ | 元と同じ意味。「de la versión 1.2.4」が「バージョン 1.2.4 そのものを直したこと」とも読める（R の注）のは、元の「1.2.4 の直し」の「の」にも同じだけある。también があるので、どちらの読みでも「1.2.4 に続く別の直し」で、1.2.4 の直しを新しいとは言っていない。volver a iCloud と escritura a mano の繰り返しは前の H1 の点と同じ字 |
| es-ES | ○ | es-MX と同じ（se ha corregido） |
| fr-FR | ○ | 元と同じ意味。Dans la continuité de（〜の延長として）は、元の「続いて」の「続き」の意味。renvoyer vers iCloud（送り返す）と、文末の après… の形は前の H1 の点と同じ字。après… のかかり先（R の注）はどちらでも同じ意味 |
| it | ○ | 元と同じ意味。Dopo と una volta で「後」が 2 回（R の注）は、元の「続いて」「あと」と同じ数で言い回しの差。「バージョン 1.2.4 自体が直された後」の読みは es-MX と同じ扱い（anche） |
| ko | ○ | 元とほぼ同じ字。해요체（R の注）は 1〜3・5 つ目の点と同じ文体 |
| pt-BR | ○ | 元と同じ意味。Após と depois que（R の注）は it と同じ扱い。「バージョン自体の修正」の読みは es-MX と同じ扱い（também）。escrita à mão の繰り返しは前の H1 の点と同じ字 |
| pt-PT | ○ | pt-BR と同じ。noutro・ecrã は本国の語 |
| zh-Hans | ○ | 元とほぼ同じ字（继…之后＝「続いて」、也＝「も」）。「回到 iCloud」（R の注）は前の H1 の点と同じ字 |
| zh-Hant | ○ | zh-Hans と同じ（繼…之後、也、清除・這部裝置・螢幕） |

審査メモの直した文（`docs/store/review-note.txt` の「What is new in 1.3」）:

| 文 | 判定 | 理由・見たこと |
| --- | --- | --- |
| 1 の 2 つ目の文「It is saved whole on the page holding its center (same file and iCloud record format); older versions show it on that page only.」 | △ | 中心のあるページにまるごと保存される・ファイルと iCloud のレコードの形は同じ・古い版ではそのページにだけ出る、の 3 つが元と同じ。主語が「そのような線は」（前の字は Such a stroke）から It になった（4,000 バイトに入れるため詰めた）。メモの中では直前の節の a stroke（線は境目をまたげる）を指し、「中心を持つページにまるごと保存される」は線にしか当たらないので、ほかのものと取り違える読みは出にくい（R は前後を見ずに読んだので「何を指すか分からない」と書いた）。same … format が何と同じか書いていない（R の注）のは、元の「形は同じ」と前の字（in the same … format）も同じで、前と同じ形と読む |
| 2 の 2 つ目の文「Off shows one page at a time as before.」 | ○ | オフにすると、前のとおり 1 ページずつ表示する。元と同じ。Off が主語の短い文（R の注）は、同じ段の前の文の one switch を受ける（前の字 Off gives … も同じ形）。「前のとおり」は 1 ページずつ出ることを言い、スイッチがオフでも出る週のメモ（4）と食い違わない |
| 4「Week pages now also have Free Notes below 24:00, like day pages since 1.1, even with the switch off.」 | △ | 週のページにも、日のページ（1.1 から）と同じく 24 時の下に自由メモができた・スイッチがオフでも出る、が元と同じ。the switch は 2 のスイッチ（R は前後を見ていない）。even with the switch off が day pages since 1.1 にかかるとも読める（R の注）が、like day pages since 1.1 は前後のコンマで挟んだ挿入句で、普通の読みでは文の本体（週のページにある）にかかる。日のページにかけて読んでも、日の自由メモもスイッチに関わらず出るので、元に無い事実にはならない |
| 5「Screen-side fixes after 1.2.4's sync fixes: handwriting erased with Erase All (on any device) or Erase and Start can no longer come back via the open page or Undo and be sent to iCloud again.」 | ○ | 1.2.4 の同期の直しに続く画面の側の直し・「全て消す」（どの端末でも）と「消して始める」・開いているページと取り消しから戻って iCloud へもう一度送られることはなくなった、が元と同じ。1.2.4 で直したページの取得（H4）は挙げていない（(i)）。Erase and Start が何か分からない（R の注）のはアプリのボタンの名前で、en の訳と同じ語。(on any device) が Erase All だけにかかる読みは、元の（どの端末でも）の位置と同じ。「戻ってから送られる」一連の流れと読む読みも元と同じ |

日本語の要約（R には渡していない。英語の段と照らした）: 1 つ目の文の「（古い版では片方のページにだけ出ます）」は、「、またいだ線が」を外したので主語が書いていないが、すぐ前の「境目をまたいで書けます」から、またいで書いた線のことと読める（英語の 1 と同じ）。「週にも 24 時の下の自由メモ。」は 4 と、「1.2.4 に続き、全て消した手書きが画面から iCloud に戻りうる穴を直しました。」は 5 と同じ（要約なので「消して始める」と取り消しは省いた）。どれも (i) と (ii) に当たる読みは無い。

決まっていないこと（判定には入れていない）:

- 新しい点の R の注の言い回し（de-DE の landen・alle Handschrift、es・it・pt の語や「後」の繰り返し、zh の「回到 iCloud」で何が困るか）は、母語の人に見てもらうときの候補です。どれも前の H1 の点（上の 3 で ○）と同じ字のところです。
- 審査メモの 1 の It（前の字は Such a stroke）は、バイトの余り（今 7 バイト）が 9 バイト以上になったら戻す候補です。4 は、バイトの変わらない語順の替え（even with the switch off を 24:00 の後へ）が、次に審査メモを直すときの候補です。

`lint.py`（L-1〜L-14。L-9 は 12 ロケールで ok）・`build.py --check`・`baseline.py --check` は、この記録の後の字で 3 つとも終了 0 です。

### 1.4 の店の文（新機能の文の行・審査メモの 1.4 の段・SUPPORT の Duo の文、2026-11-20）

元は 3 つです。(1) 新機能の文の 5 つの行（[M7D_CONTRACT.md](../M7D_CONTRACT.md) §8.1 の行 1 案 A・行 1 案 B・行 2・行 3・行 4。条件で使う行を選び、この順に並べる）と、その 11 組の訳（役 X、`docs/store/PROPOSALS_1_4.md` §1、10c504a）。(2) 審査メモ `docs/store/review-note.txt` の「What is new in 1.4」の段と、条件で替わる英語の文（(2) の案 B、確かめ方の任意の案、(3) の 2 つ目の文の替え文。役 N、`PROPOSALS_1_4.md` §3、e123b4c）。日本語の元は契約 §8.3 と、審査メモの日本語の要約です。(3) `docs/SUPPORT.en.md` の Duo の文（案 A・案 B）と Apple Pencil の文（条件が満ちたときだけ入れる。まだ入れていない）。日本語の元は契約 §8.4 と `docs/SUPPORT.md` の同じ文です。

R には、訳の字（`PROPOSALS_1_4.md` §1 の「訳」の欄の 11 組 × 5 行）と N の英語の文だけを渡し、日本語の元・§1.0 の訳の決まり・行の条件・このファイルを見ずに訳し戻してもらいました。判定は、訳を書いた Claude（X・N）とも R とも別の Claude（J）が、逆翻訳と日本語の元を照らしたものです。母語の人の確認ではありません。逆翻訳の全文と R の注は `docs/i18n/back/store-1_4.md` にあります（行ごとに作った文なので、ロケールごとのファイルに節を足さず、1 つにまとめました）。en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`locales.json` の `copyOf`）。訳についての 1 行は 1.3 と同じ字（上の「1.3 の新機能の文と審査メモ」で ○）なので、R に渡していません。

判定は 1.3 と同じ **○**（同じ意味）／**△**（言い回しの差。意味は同じ）／**×**（意味の違い、または元に無い読みを招く。直す）です。とくに、(i) 無い改善や確かめていない動きを言っていないか（契約 §8.1、R1_2_2.md:694）、(ii) K-8 の句（古い版の端末での見え方。契約 §5.2 で 1.4 は入れない）が無いか、(iii)「指でも書く」がアプリの `toolbar.fingerToggle` の訳と同じ字か、を見ました。

**1 回目は × 6 件でした。** どれも行 1 案 A の 2 つ目の文で、es-ES・es-MX・fr-FR・it・pt-BR・pt-PT です。「中断なく」（sin interrupciones・sans interruption・senza interruzioni・sem interrupção。R の注でも、元に無い語として挙がった）が、開閉の間も書くことが途切れないと読めます。元の「そのまま書き続けられます」は、開いても閉じても同じページと線のまま続けて書けることで、書きながら閉じたときに書きかけの 1 本が消えることがある（契約 §4.9 の 3、確かめ表の行 25）のと食い違いません。「中断なく」はそれと食い違い、(i) の無い改善を言うことになるので × にしました。pt-BR・pt-PT は、加えて「Ao abrir ou fechar o dispositivo」（開いたり閉じたりするとき）が開閉の最中と読まれました。6 件は J が直し（下の「× と直した訳」）、直した字だけを 2 回目の R に渡しました。**2 回目は 6 件とも ○ で、× は残っていません**（下の「2 回目」）。ほかの行と、審査メモ・SUPPORT の文は 1 回目から × 0 で、直した字はありません。(ii) と (iii) に当たる字は、1 回目から 0 件です。

結果（1 回目）:

| 言語 | ○ | △ | × |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も） | 4 | 1 | 0 |
| de-DE | 4 | 1 | 0 |
| es-ES | 3 | 1 | 1 |
| es-MX | 3 | 1 | 1 |
| fr-FR（fr-CA も） | 3 | 1 | 1 |
| it | 3 | 1 | 1 |
| ko | 4 | 1 | 0 |
| pt-BR | 3 | 1 | 1 |
| pt-PT | 3 | 1 | 1 |
| zh-Hans | 4 | 1 | 0 |
| zh-Hant | 3 | 2 | 0 |
| 新機能の文の計（11 組 × 5 行） | 37 | 12 | 6 |
| en の審査メモ（1.4 の段 5 つと、条件で替わる文 3 つ） | 5 | 3 | 0 |
| en の SUPPORT（Duo の文の 2 案と Apple Pencil の文） | 3 | 0 | 0 |

結果（2 回目の後。最後）:

| 言語 | ○ | △ | × |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も） | 4 | 1 | 0 |
| de-DE | 4 | 1 | 0 |
| es-ES | 4 | 1 | 0 |
| es-MX | 4 | 1 | 0 |
| fr-FR（fr-CA も） | 4 | 1 | 0 |
| it | 4 | 1 | 0 |
| ko | 4 | 1 | 0 |
| pt-BR | 4 | 1 | 0 |
| pt-PT | 4 | 1 | 0 |
| zh-Hans | 4 | 1 | 0 |
| zh-Hant | 3 | 2 | 0 |
| 新機能の文の計（11 組 × 5 行） | 43 | 12 | 0 |
| en の審査メモ（1.4 の段 5 つと、条件で替わる文 3 つ） | 5 | 3 | 0 |
| en の SUPPORT（Duo の文の 2 案と Apple Pencil の文） | 3 | 0 | 0 |

機械で照らしたこと（J。直した後の字で。2 回目の後にもう一度照らし、同じ結果）:

- 行 2 の「指でも書く」は、11 組ともアプリの `toolbar.fingerToggle` の訳と同じ字です（`tools/l10n/translations/<言語>.json`。pt-PT はアプリの pt-BR の語。`PROPOSALS_1_4.md` §2.3 の表）。審査メモと `SUPPORT.en.md` の Draw with Finger は en の訳と、`SUPPORT.md` の「指でも書く」は ja と同じ字です。
- K-8 の句（older version・ältere・versión anterior・version précédente・versione precedente・versão anterior・이전 버전・旧版・舊版、not deleted などの「消えていない」の語）は、11 組の 5 行のどれにもありません。審査メモの 1.4 の段と SUPPORT の新しい文にもありません。
- 「中断なく」の語（interrup・unterbrech・중단・中断・不间断 など）は、直した後の字にありません。
- 字数: 直した 6 つで、いちばん長い組み合わせ（案 A ＋ 行 2 ＋ 行 3 ＋ 行 4）が es-ES 694 → 683、es-MX 685 → 674、fr-FR 723 → 716、it 672 → 667、pt-BR 656 → 658、pt-PT 671 → 673 になりました（`PROPOSALS_1_4.md` §2.2。数え方は L-9 と同じ）。どれも 4,000 字に入ります。既定（案 B ＋ 行 3）の字は変わりません。

新機能の文の 1 回目の判定（判定の並びは `PROPOSALS_1_4.md` の表の順。en-US・de-DE・es-ES・es-MX・fr-FR・it・ko・pt-BR・pt-PT・zh-Hans・zh-Hant。行 1 案 A の × の 6 つは、直した字が下の「2 回目」で ○）:

| 行 | 元の日本語 | en-US | de-DE | es-ES | es-MX | fr-FR | it | ko | pt-BR | pt-PT | zh-Hans | zh-Hant | 理由・見たこと |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 行 1 案 A | ・iPhone Duo の大きな画面いっぱいに表示されるようになりました。開いても閉じても、そのまま書き続けられます。 | ○ | ○ | × | × | × | × | ○ | × | × | ○ | ○ | ○ の 5 組は「大きな画面いっぱい（全体・全画面）に表示・開いても閉じてもそのまま書き続けられる」が元と同じ。en の it は iPhone Duo と読むのが自然（R の注。アプリと読む余地は少しあるが、開いて閉じるのは端末で、閉じたのに書き続けられるとは読みにくい）。just keep writing・einfach weiterschreiben・그대로 계속・直接继续书写 は元の「そのまま」。ko の 쓰다 が「使う」とも読める（R の注）のは、どちらの読みでも開閉の後に続けられることで、元に無い事実にはならない。× の 6 組は上のとおり「中断なく」（pt-BR・pt-PT は「開いたり閉じたりするときも」も）。1 つ目の文は 11 組とも元と同じ。閉じたとき（外側の画面）の見え方を言っていない（R の全体の注）のは、元も同じ |
| 行 1 案 B | ・iPhone Duo の大きな画面に合わせて表示するようにしました。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 11 組とも「iPhone Duo の大きな画面に合わせて表示（レイアウト）を調整する」。de・es・fr・it・pt は主語が「表示」（Darstellung・visualización・affichage・visualizzazione・exibição・apresentação）、en は「アプリがレイアウトを」で、どちらも元の「表示するようにしました」と同じこと。pt-PT の passa a（〜するようになる）の現在形は、1.3 の passam também a ter と同じ扱い |
| 行 2 | ・iPhone Duo では iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | 11 組とも元と同じ。en・de・es・pt で本文の「書く」と切り替えの名前の動詞が違う（Draw・zeichnen・Dibujar・Traçar。R の注）のは、アプリの `toolbar.fingerToggle` の訳の字そのもので（契約 §8.1 の指定。画面に出る名前と同じ）、2 つ目の文もアプリの初めての案内（`onboarding.pen.text`）の訳の字。it の切り替えの名前 Scrivi（tu の命令形）と本文の Lei の違い（R の注）も同じ理由。es・it・pt-PT の主語の無い 3 人称は丁寧の形（GLOSSARY §1）で、R も人が書くと読んだ。「（iOS 27.2 以降）」が 2 つ目の文にもかかるか分からない（R の全体の注）のは、元の括弧の位置と同じ |
| 行 3 | ・iOS 27 の新しい開発環境に移りました。iPad とほかの iPhone での使い方は変わりません。 | △ | △ | △ | △ | △ | △ | △ | △ | △ | △ | △ | 11 組とも「ほかの iPhone」が「ほかの iPhone の機種」（models・Modelle・modelos・modèles・modelli・모델・机型・機型）に戻った。Duo でない iPhone のことだと分かるように X が足した語（`PROPOSALS_1_4.md` §1.0）で、元の「ほかの iPhone」が指すものと同じ。en・de の「iOS 27 向け」（for）、de の受け身、es-MX の単純過去は言い回し。ko・zh が何を移したか書いていない（R の注）のは元も同じ |
| 行 4 | ・中国の 2027 年の祝日を、発表された休みに合わせました。 | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ | △ | 11 組とも「中国の 2027 年の祝日を、発表された休み（の日・日程）に合わせた」。en の updated to match は「合わせて更新」で同じこと。zh の 放假安排 は政府の休みの日程（振替を含む。R の注）で、元の「発表された休み」と同じ。zh-Hant の 假日 は「休日」とも読める広い語（R の注）だが、用語集（GLOSSARY §2）の zh-Hant の「祝日」の語で、アプリの「表示する祝日」（顯示的假日）と同じ字なので △ |

× と直した訳（行 1 案 A。1 つ目の文は変えていない）:

| ロケール | 前の字（1 回目に R が読んだ字） | 今の字（J が直した字。2 回目で ○） | 1 回目の逆翻訳（2 つ目の文） | 直した所 |
| --- | --- | --- | --- | --- |
| es-ES・es-MX | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin interrupciones. | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin más. | それを開いても閉じても、途切れることなく書き続けられます。 | sin interrupciones（中断なく）→ sin más（そのまま・それだけで）。en の just と同じ「そのまま」の語 |
| fr-FR（fr-CA も） | • L’app occupe désormais tout le grand écran de l’iPhone Duo. Que vous l’ouvriez ou le fermiez, vous pouvez continuer à écrire sans interruption. | • L’app occupe désormais tout le grand écran de l’iPhone Duo. Que vous l’ouvriez ou le fermiez, vous pouvez simplement continuer à écrire. | それを開いても閉じても、中断せずに書き続けられます。 | sans interruption を外し、simplement（そのまま）を動詞の前に |
| it | • Ora l’app occupa tutto il grande schermo di iPhone Duo. Che lo apra o lo chiuda, può continuare a scrivere senza interruzioni. | • Ora l’app occupa tutto il grande schermo di iPhone Duo. Che lo apra o lo chiuda, può semplicemente continuare a scrivere. | それを開いても閉じても、中断なく書き続けられます。 | senza interruzioni を外し、semplicemente（そのまま）を動詞の前に |
| pt-BR | • Agora o app ocupa toda a tela grande do iPhone Duo. Ao abrir ou fechar o dispositivo, você pode continuar escrevendo sem interrupção. | • Agora o app ocupa toda a tela grande do iPhone Duo. Mesmo que você abra ou feche o dispositivo, pode simplesmente continuar escrevendo. | デバイスを開いたり閉じたりするときも、中断なく書き続けられます。 | sem interrupção を外し simplesmente に。Ao abrir ou fechar（開いたり閉じたりするとき）を Mesmo que … abra ou feche（開いても閉じても）に |
| pt-PT | • A aplicação passa a ocupar todo o ecrã grande do iPhone Duo. Ao abrir ou fechar o dispositivo, pode continuar a escrever sem interrupção. | • A aplicação passa a ocupar todo o ecrã grande do iPhone Duo. Mesmo que abra ou feche o dispositivo, pode simplesmente continuar a escrever. | デバイスを開いたり閉じたりするときも、中断なく書き続けられます。 | pt-BR と同じ直し（você は書かない。pt-PT の 1.3 の文と同じ） |

2 回目（直した 6 つの字だけ、2026-11-20）: 上の「今の字」の 6 つ（行 1 案 A の全文。fr-CA は fr-FR と同じ字）だけを、id と訳だけで R に渡しました。前の字・1 回目の逆翻訳・日本語の元・ほかの行・このファイルは渡していません。逆翻訳の全文と R の注は `docs/i18n/back/store-1_4.md` の「2 回目」です。**6 つとも ○ で、× は残っていません。** 1 回目の × の理由だった「中断なく」と、開閉の最中（開いたり閉じたりするとき）の読みは、どれにも出ませんでした。(i) の無い改善と (ii) の K-8 の句も、どれにもありません。6 つに共通する R の注「閉じたときにどの画面で書くのかは書かれていない」は、元も書いていない（1 回目の R の全体の注と同じ。閉じたときの見え方は審査メモ (2) と SUPPORT の Duo の文が言う）ので、元と同じです。

| ロケール | 2 回目の逆翻訳（元を見ない） | 判定 | 理由・見たこと |
| --- | --- | --- | --- |
| es-ES | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。開いても閉じても、そのまま書き続けられます。 | ○ | 元とほぼ同じ字。「これからは」（Ahora。R の注で「前より変わったこと」）は元の「表示されるようになりました」、「画面全体」は「画面いっぱい」。sin más は「そのまま」と読まれた（R の注「特に何もせず、そのまま」）。lo は端末（iPhone Duo）と読まれた。usted は GLOSSARY §1 の丁寧さ |
| es-MX | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。開いても閉じても、そのまま書き続けられます。 | ○ | es-ES と同じ字・同じ逆翻訳。メキシコ向けとしても不自然でない（R の注） |
| fr-FR（fr-CA も） | • アプリは今後、iPhone Duo の大きな画面全体を使うようになりました。開いても閉じても、そのまま書き続けることができます。 | ○ | 元と同じ意味。désormais と「使うようになりました」は元の「ようになりました」。simplement は「そのまま」。l’ が文法上アプリとも取れる（R の注）が、le fermiez の男性形から端末と読まれた（1 回目の R の読みと同じ） |
| it | • これで、アプリが iPhone Duo の大きな画面全体を使うようになりました。開いても閉じても、ただそのまま書き続けられます。 | ○ | 元と同じ意味。semplicemente の「ただそのまま」は、en の just（1 回目で ○。R は「ただ書き続ければよい」とも読めると書いた）と同じ扱いで、無い改善は言っていない。lo が schermo（画面）も指せる（R の注）が、Duo では画面を開け閉めするのは端末を開け閉めするのと同じ動きなので、どちらの読みでも元に無い事実にはならない。Lei は 1 回目と同じ |
| pt-BR | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。端末を開いても閉じても、そのまま書き続けられます。 | ○ | 元と同じ意味。Mesmo que は「開いても閉じても」と読まれ（R の注「たとえ〜しても」の譲歩）、1 回目の「開いたり閉じたりするときも」の読みは出なかった。o dispositivo で開け閉めするものがはっきりしている。simplesmente は「そのまま」 |
| pt-PT | • アプリは、iPhone Duo の大きな画面全体を使うようになります。端末を開いても閉じても、そのまま書き続けられます。 | ○ | 元と同じ意味。passa a の現在形は「使うようになります」と読まれ、すでに変わったともこれから変わるとも読める（R の注）。新機能の文の中なのでこの版での変化と読め、行 1 案 B の pt-PT（1 回目で ○）と 1.3 の passam também a ter と同じ扱い。Mesmo que と simplesmente は pt-BR と同じ。ecrã・aplicação は本国の語（R の注） |

審査メモ（en。`docs/store/review-note.txt` の「What is new in 1.4」と `PROPOSALS_1_4.md` §3 の条件で替わる文。元は契約 §8.3 の (1)〜(4)）:

| 段 | 判定 | 理由・見たこと |
| --- | --- | --- |
| 見出し What is new in 1.4 | ○ | 「1.4 の新しい点」。1.3 の見出しと同じ形 |
| (1) | ○ | Xcode 27.2（iOS 27.2 SDK）で作った・対応する最小の iOS は 17.0 のまま、が §8.3 (1) と日本語の要約と同じ |
| (2) 案 A（今のファイル） | ○ | 端末の種類でなく窓の大きさで決める・Duo では内側でも外側でも画面いっぱい・開閉に追う・ページと手書きはそのまま・確かめ方（週のページを開き、開いて閉じる）が §8.3 (2) と同じ。何が調整されるか書いていない（R の注）のは、前の文の layout を受ける。the page … stay the same の 2 つの読み（R の注）は、元の「ページと手書きはそのまま」にも同じだけある。確かめ方に「iPhone Duo で」が無いのは、同じ段の Duo の話の中で the device が Duo と読めるため |
| (3) | △ | §8.3 (3) の中身（Duo では iPad と同じ・Apple Pencil（USB-C、iOS 27.2 以降）で書き指で紙を動かす・Pencil の触れか折り目で Draw with Finger をオフ・1.3 から更新した端末は Pencil の触れだけ・機種名も窓の大きさも読まない・ツールバーのスイッチで戻せる）が全部ある。first（初めて）は §8.3 の字に無い語だが、§4.8 の決め方の表（オフへ（1 回））のとおりで、一度だけの動きという R の読みは本当の動きと同じ。Pencil が「書く」と道具が主語の形は言い回し。USB-C と iOS 27.2 以降のかかり先（R の注）は §8.3 の括弧と同じ。折り目の句が `PencilPhone.usesHinge` に左右されることは下の「決まっていないこと」 |
| (4) | △ | 新しい画面の文は無い・データ（データの収集なし）・手書きの保存・購入・年齢区分（新しい 2 問はどちらも No）は変わらない、が §8.3 (4) と同じ。handwriting storage が「手書きの保存」と読まれ、契約の「保存先」とまでは言っていない（1.3 の Unchanged の行と同じ △。保存先は同じメモのサーバー無しの段にある）。4+ は契約 §9.5 のとおり（4+ のまま）。2 問の名前の and が重なって区切りが読みにくい（R の注）のは言い回しで、both new questions から 2 つと読まれた |
| (2) 案 B（§3.2） | ○ | §8.3 の「案 B のときは (2) の『開閉に追う』を『幅に合わせる』に」のとおり。its width は画面の幅と読まれた（R の注）。「いっぱい」と「幅に合わせる」の重なり（R の注）は、案 B の日本語の要約（画面いっぱいに出て幅に合わせます）にも同じだけある。確かめ方が今も開閉を求める（R の注）のは訳の違いではなく、§8.3 のとおりに句だけ替えたため（N が §3.2 にリードの決めることとして書いた。下の「決まっていないこと」） |
| 確かめ方の任意の案（§3.2） | ○ | 「内側の画面と外側の画面で週のページを開く」。§3.2 の日本語の説明と同じで、開閉の操作を言わない（R の読みのとおり）。契約に無い文なので、使うかはリードが決める |
| (3) の 2 つ目の文の替え文（§3.4） | △ | Apple Pencil の触れを見たら Draw with Finger をオフにする、が §8.3 (3) から折り目を外した形と同じ。first は (3) と同じ扱い。that iPhone は (3) の 1 つ目の文の iPhone Duo を受ける（R は前後を見ずに読んだので「この文だけでは分からない」と書いた） |

日本語の要約（R には渡していない。英語の段と照らした）: 「Xcode 27.2（iOS 27.2 SDK）で作り、対応は iOS 17.0 からのまま。」は (1) と、「レイアウトは窓の大きさで決め、iPhone Duo では内側・外側の画面いっぱいに出て開閉に追います。」は (2) 案 A と、「Duo では iPad と同じく Apple Pencil で書き、指で紙を動かします。」は (3) の 1 つ目の文と、「新しい画面の文は無し。」は (4) と同じ。後ろの「データ・購入・年齢区分は同じ。…」は 1.3 の字のまま。案 B の要約の「幅に合わせます」は (2) 案 B と同じ。(i) の無い改善と (ii) の K-8 の句は、英語にも要約にも無い。

SUPPORT（en。`docs/SUPPORT.en.md` の「Can I use it on iPhone or Mac?」に足す文）:

| 文 | 元の日本語 | 渡した英語 | 逆翻訳（元を見ない） | 判定 | 理由・R の注 |
| --- | --- | --- | --- | --- | --- |
| Duo の文 案 A（今のファイル） | iPhone Duo では、開いた大きな画面いっぱいに、閉じたときは外側の画面に合わせて表示します（1.4 から）。 | On iPhone Duo, the App fills the large screen when the device is open, and fits the outer screen when it is closed (from version 1.4). | iPhone Duo では、デバイスを開いているときは、本アプリは大きな画面いっぱいに表示されます。閉じているときは外側の画面に合わせます（バージョン 1.4 から）。 | ○ | 開いたときは大きな画面いっぱい・閉じたときは外側の画面に合わせる・1.4 から、が同じ。「バージョン」は from version 1.4 の読みで、1.3 の SUPPORT の「1.3 から」（11 で ○）と同じ形。the App は規約で決めた語「本アプリ」と読まれた（R の注。同じ文書の書き方） |
| Duo の文 案 B（§3.2） | iPhone Duo では、画面の幅に合わせて表示します（1.4 から）。 | On iPhone Duo, the App fits the width of the screen (from version 1.4). | iPhone Duo では、本アプリは画面の幅に合わせます（バージョン 1.4 から）。 | ○ | 同じ。内側・外側のどちらの画面か言わない（R の注）のは元も同じ |
| Apple Pencil の文（§3.3。まだ入れていない） | iPhone Duo では iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かします。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。 | On iPhone Duo, as on iPad, you write with Apple Pencil (USB-C, iOS 27.2 or later) and move the paper with your finger. If you also want to write with your finger, turn on “Draw with Finger” in the toolbar. | iPhone Duo では、iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かします。指でも書きたい場合は、ツールバーの「Draw with Finger（指で描く）」をオンにしてください。 | ○ | 元と同じ。Draw with Finger はアプリの en の訳（`toolbar.fingerToggle`）と、同じ節の前の文の字（R の注の「書く」と「描く」の違いは行 2 と同じ扱い）。USB-C・iOS 27.2 以降のかかり先（R の注）は元の括弧と同じ |

決まっていないこと（判定には入れていない）:

- **審査メモ (2) の案 B の確かめ方**（「To check: open a week page, then open and close the device.」）は、案 B（開閉を確かめられなかったとき）でも開閉を審査の人に試してもらう形です（R も「今も開閉を求めています」と挙げた）。訳の違いではないので判定は ○ のままで、替えるかは N が `PROPOSALS_1_4.md` §3.2 に書いたとおりリードが決めます。替えるときの任意の案は 1 回目で ○ なので、そのまま入れられます。
- **審査メモ (3) の折り目の句**は、`PencilPhone.usesHinge` が false のまま出すと本当でなくなります（N の §3.4）。替え文は 1 回目で △（意味は同じ）なので、リードが決めればそのまま入れられます。
- 母語の人に見てもらうときの候補（直さない）: en・de・es・pt の切り替えの名前の動詞（Draw・zeichnen・Dibujar・Traçar）と本文の「書く」の違い、it の切り替えの名前（tu の命令形）と本文の Lei（どれもアプリの画面の字で、変えるならアプリの訳から）、en の行 1 案 A の it の指す先、ko の 쓰다（書く・使う）、zh-Hant の 假日、審査メモ (4) の 2 問の名前の and の重なり。2 回目の R の注から、行 1 案 A の fr の l’（文法上アプリとも取れる）と it の lo（画面とも取れる）の指す先、pt-PT の passa a の時（すでに変わったか、これから変わるか）。

`lint.py`（L-1〜L-14）は、この記録の後の字で終了 0 です（2 回目の記録の後にも走らせ、終了 0。`PROPOSALS_1_4.md` と `store-1_4.md` は L-9 の見る欄ではない。`review-note.txt` と SUPPORT の字はこの節で変えていない）。

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

## 13. 1.3 の週のメモ（SUPPORT の 2 段落と訳者向けの説明、2026-11-18）

元は `docs/SUPPORT.md` の 2 つの段落で、週のページの 24 時の下の「自由メモ」（[M7C_CONTRACT.md](../M7C_CONTRACT.md) §5）を入れるのに合わせて、3 つの文を変えました（§8.7 の 2 つ目、週のメモの計画の §8.1。ほかの文は 1.2 の字のまま）。

- 「1 ページにどれだけ書けますか？」の 2 つ目の文: 「日のページの」→「日と週のページの」。
- 「iPad と iPhone で版が違うと？」の 1 つ目の文: 日のページは 1.1 から、週のページは 1.3 から。括弧の「週のページでは、設定 › ページ で横につなげるのをオフにしても出ます」は計画の決めどころ 27（契約 §6.5 の「設定オフの端末（1.3）」の行の脚注にあたる）。
- 同じ段落の 2 つ目の文: 「1.0 や 1.0.1 のままの端末」→「それより前の版のままの端末」（日と週で版が違うので）。

英語は `docs/SUPPORT.en.md` の同じ 2 つの段落の同じ 3 文です。R には英語のこの 3 つの文だけを渡し、日本語の元を見ずに訳し戻してもらいました。判定は、英語を書いた Claude とも R とも別の Claude が、逆翻訳と日本語の元を照らしたものです。母語の人の確認ではありません。逆翻訳は `docs/i18n/back/legal-en.md` の同じ段落にあります（2 つの段落のほかの文は 1.2 の逆翻訳のまま）。

**○ 2・△ 1・× 0。直した字はありません**（× が無いので、2 回目の R は回していません）。抜けた事実も、元に無い事実もありませんでした（月のメモ欄と日・週の自由メモは最初から下まで開いている、日は 1.1 から・週は 1.3 から、週は設定でオフにしても出る、前の版の端末では見えないが消えていない、新しい版にすると見える）。

| 文 | 元の日本語 | 渡した英語 | 逆翻訳（元を見ない） | 判定 | 理由・R の注 |
| --- | --- | --- | --- | --- | --- |
| 書ける量の 2 つ目 | 月のメモ欄と、日と週のページの 24 時の下の「自由メモ」は、最初から下まで開いています。 | The Notes area of the month page and the “Free Notes” area below 24:00 on the day and week pages are open all the way down from the start. | 月のページのメモ欄と、日のページと週のページの24:00より下にある「自由メモ」欄は、最初から一番下まで開いています。 | ○ | 変えたのは and week の 2 語。R が挙げた open のあいまいさ（広がっている／書ける、from the start が「初めから」か「欄の上端から」か）は、元の「開いています」「最初から」にも同じだけある。1.2 の逆翻訳（最初からいちばん下まで開いています）も ○ だった |
| 版が違うときの 1 つ目 | 24 時の下の「自由メモ」は、日のページは 1.1 から、週のページは 1.3 からの機能です（週のページでは、設定 › ページ で横につなげるのをオフにしても出ます）。 | The “Free Notes” area below 24:00 is a feature from version 1.1 on the day page and from version 1.3 on the week page (on the week page, it appears even when the side-by-side joining is turned off in the App's Settings > Pages). | 24:00より下の「自由メモ」欄は、日のページではバージョン1.1から、週のページではバージョン1.3から使える機能です（週のページでは、アプリの設定＞ページで横につなげる機能をオフにしていても表示されます）。 | ○ | 日は 1.1 から・週は 1.3 から・週はオフでも出る、が全部同じ。「バージョン」「アプリの」は version と the App's の読みで、どちらも 11 で ○ になった形。R の注の the side-by-side joining が分かりにくいことは、SUPPORT の「Handwriting across cells」の行と新機能の文の 3 つ目の点と同じ語で、そろえてある。the App's Settings が iOS の設定アプリにあるこのアプリの項目とも読めるという注は、11 の 2 回目の R が「アプリの［設定］＞［ページ］」と読んだのと同じ字で、11 で ○ にした形のまま |
| 版が違うときの 2 つ目 | それより前の版のままの端末では表示されませんが、消えてはいません（その端末を新しい版にすると表示されます）。 | On a device still on an earlier version, it is not shown, but it has not been deleted (it appears when you update that device). | まだ以前のバージョンのままの端末では表示されませんが、削除されたわけではありません（その端末をアップデートすると表示されます）。 | △ | 「それより前の版」が「以前のバージョン」に戻った。earlier は直前の文の 1.1・1.3 と比べた語として読め、日のページなら 1.1 より前、週のページなら 1.3 より前、という元の意味と同じ。R の注の update that device が OS の更新とも読めること、it が欄か中身かのあいまいさは、1.2 の英語（同じ字で ○）と元の日本語に同じだけある。「表示されない」と「消えていない」の区別ははっきり伝わった |

### 訳者向けの説明（comment）

画面の文ではなく、訳す人への説明（`comment`）を 3 つ直しました（週のメモの計画の §8.2）。日本語の文（`ja`）と `jaSha1` は変えていないので、訳し直しは要らず、訳のファイル（`tools/l10n/translations/`）も変えていません。`comment` には訳が無いので、逆翻訳はありません。`Localizable.xcstrings` は `build.py` が作り直し、変わったのはこの 3 つの `comment` だけです。

| キー | 前の字 | 今の字 | 見たこと |
| --- | --- | --- | --- |
| `toast.eventBelowDay` | トースト。日のページの 24 時より下は予定にできない | トースト。日と週のページの 24 時より下は予定にできない | 週のメモの中でも予定を作らない（契約 §5.2、決めどころ 4）。同じお知らせで断るので、文は増えない |
| `toast.growthCap` | トースト。月のメモ欄や日の自由メモ欄の下の端まで書いたとき | トースト。月のメモ欄や日と週の自由メモ欄の下の端まで書いたとき | 週のメモも上限の下の端で同じお知らせ（契約 §5.2） |
| `paper.freeMemo` | 日のページの 24 時より下の欄の見出し。同じページに「メモ」もあるので別の語にする。（後ろは F-6 の字のまま） | 日と週のページの 24 時より下の欄の見出し。日のページには「メモ」もあるので別の語にする。（後ろは F-6 の字のまま） | 見出しが日と週の両方に出るので、「同じページに」を、同じページに「メモ」の欄がある日のページのことだと分かる「日のページには」に。見出しの語「自由メモ」とその訳は変えない（新機能の文の「自由メモ」もこの訳にそろえてある、4） |

### lint

`lint.py`（L-1〜L-14）・`build.py --check`・`baseline.py --check` は、この節と 4 の「1.3 の週のメモの文」の直しの後の字で、3 つとも終了 0 です。

## 14. 1.4.1 のアプリの文字列と新機能の文（2026-11-22）

元は 2 つです。(1) アプリの新しい 11 キー（[R1_4_1_CONTRACT.md](../R1_4_1_CONTRACT.md) §8.1。`header.zoomReset.spoken` は `tools/l10n/source/app-P.json`、`settings.hand.*` の 4 つは `app-U.json`、`toolbar.grip.*` と `toolbar.moveTo.*` の 6 つは `app-S.json`。日本語は 1 字も変えていません）。(2) 新機能の文（契約 §8.3。`docs/store/source-ja/whatsnew.txt` の 4 つの点と訳についての 1 行と、並べ方 (b) のときに 1 つ目の点と入れ替える行 1 (b)。[PROPOSALS_1_4_1.md](../store/PROPOSALS_1_4_1.md) §1.1）。

- **訳**: X が書きました。アプリの 11 キーは、D1 で入れた仮の訳（`tools/l10n/translations/<言語>.json`、796bff1）を GLOSSARY の §5（1.4.1 で足した語。等倍・利き手・ツールバーを動かす）と照らし、99 の字のうち 15 を直しました（`settings.hand.footer` の 7 言語、`toolbar.grip.hint` の fr・it・zh-Hans・zh-Hant、`toolbar.moveTo.top`・`toolbar.moveTo.bottom` の zh-Hans・zh-Hant）。残りの 84 は D1 の字のままです。新機能の文は、11 のフォルダ（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・pt-PT・es-MX・es-ES）の `whatsnew.txt` を 1.4 の字から 1.4.1 の字に替えました（en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しでフォルダは無い）。
- **元を見ない逆翻訳**: R が、訳の字だけを読んで訳し戻しました（日本語の元・comment・契約・GLOSSARY・画面のコードは読んでいない）。アプリの 11 キーは `docs/i18n/back/<言語>.json` の同じキー、新機能の文は `docs/i18n/back/store-1_4_1.md`（zh-Hans・zh-Hant・ko）・`store-1_4_1-en.md`（en-US・de-DE・fr-FR。審査メモの 1.4.1 の段と替え文、`SUPPORT.en.md` の FAQ 4 つ、PROPOSALS §2・§3 の英語の案も）・`store-1_4_1-it.md`（it・es-ES・es-MX・pt-BR・pt-PT）にあります。
- **判定**: 訳を書いた Claude とも R とも別の Claude 2 人（判定の 2 役）が、逆翻訳と日本語の元を 1 行ずつ照らしました。**2 人の行は合わせて 367 行で、× は 16 行でした。** この作業（× の直し）に渡されたのは × の 16 行だけで、× でない行の ○ と △ の分けと理由は渡されていません。下の全部の表は、× でない行を ○ と書きました。注の列は、この × を直した Claude（元を見て書いた）の注で、判定の 2 役の理由ではありません。
- **母語の人の確認ではありません。**

### 結果

| 対象 | 行 | ×（判定） | 直した後 |
| --- | --- | --- | --- |
| アプリの 11 キー（9 言語） | 99 | 0 | — |
| 新機能の文の 4 つの点と訳についての 1 行（11 組） | 55 | 0 | — |
| 新機能の文の行 1 (b)（11 組） | 11 | 11 組とも ×（訳が無い） | 11 組の訳を書いた。**元を見ない逆翻訳と判定はまだ** |
| `SUPPORT.en.md` の「How do I zoom in and out?」の 2 段落目の幅の狭い画面の文 | 1 | × | **直していない**（`SUPPORT.en.md` は役 W のファイル。直しの字は下の「× と直し」） |
| `PROPOSALS_1_4_1.md` §3.1.2 の en（上と同じ字） | 1 | × | **直していない**（`PROPOSALS_1_4_1.md` は役 A・W のファイル。同じ直しの字） |
| 審査メモの 1.4.1 の段（4）と替え文（PROPOSALS §2 の英語の案、5）、`SUPPORT.en.md` のほかの文、PROPOSALS §3.1.1 の 4 つの組 | — | 0 | — |

**× の 16 行は、2 つのことに集まります。** 1 人は行 1 (b) を組ごとに 11 行、もう 1 人は 11 組を 1 行で挙げ（12 行）、2 人とも `SUPPORT.en.md` と PROPOSALS §3.1.2 の同じ字を 1 行ずつ挙げました（4 行）。16 行とも受け入れました（退けた × はありません）。

- **行 1 (b) の訳が無い（12 行）**: 契約 §8.3・`docs/store/README.md` の「新機能の文の組み立て」・PROPOSALS §1.0 は、行 1 を (a) と (b) の 2 つとも D2 で訳すと決めています。本人はまだ並べ方を選んでいない（`docs/R1_4_1.md` の (A) は空）ので、本人が (b) を選ぶと、訳も判定も無い文を入れることになります。
- **幅の狭い画面の文の except のかかり方（4 行）**: 括弧の「(iPhone in portrait, except the inner screen of iPhone Duo, and a narrow iPad window)」は、except が後ろの a narrow iPad window にもかかり、「iPhone Duo の内側の画面と iPad の細い窓を除く」とも読めます（R の注）。元の「（iPhone の縦と iPad の細い窓。iPhone Duo の開いた画面は除く）」では iPad の細い窓は狭い画面に入るので、読み方によって、細い窓でボタンがどこにあるかが逆になります。1.3 の判定で、別の意味にも読める言い方を × にしたのと同じ扱いです。

### × と直し

| # | 対象 | 判定の × | 扱い | 前の字 | 直した字 | 元を見ない逆翻訳（直した後） |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 新機能の文の行 1 (b)、11 組 | 12 行 | 受け入れ。直した | （無い） | 下の表。`docs/i18n/back/store-1_4_1-b.md` に置いた | **まだ** |
| 2 | `SUPPORT.en.md` の「How do I zoom in and out?」の 2 段落目の 2 つ目の文 | 2 行 | 受け入れ。**この作業では直していない**（ファイルの持ち主は役 W。契約 §2。この作業の commit のファイルに入っていない） | On a narrow screen (iPhone in portrait, except the inner screen of iPhone Duo, and a narrow iPad window), this button is at the left of the second row (the Day, Week, Month and Year switch). | On a narrow screen (a narrow iPad window, or iPhone in portrait except on the inner screen of iPhone Duo), this button is at the left of the second row (the Day, Week, Month and Year switch). | **まだ**（W が入れた後に R へ） |
| 3 | `PROPOSALS_1_4_1.md` §3.1.2 の en の 1 つ目の文 | 2 行 | 受け入れ。**この作業では直していない**（ファイルの持ち主は役 A・W） | 2 と同じ字 | 2 と同じ字（文の続きの「When “Left Hand” is chosen …」は変えない） | **まだ**（2 と一緒に） |

2 と 3 の直しの字は、除くもの（iPhone Duo の内側の画面）を括弧のいちばん後ろに置き、except が iPhone の縦だけにかかるようにしました（iPad の細い窓が iPhone Duo の内側の画面の上にあることは無いので、ほかの読み方が残りません）。「iPhone Duo の開いた画面」は、今の en の字（the inner screen of iPhone Duo。審査メモの “iPhone Duo's inner screen”）のままです。

**行 1 (b) の 11 組の訳**（全文と字数は `docs/i18n/back/store-1_4_1-b.md`。2 行目から後は各ロケールの `whatsnew.txt` のまま。「今日」はアプリの `header.today`、「左の端」「画面の上」は同じロケールの行 1 (a) の語）:

| ロケール | 直した訳（行 1 (b)） | 逆翻訳（直した Claude が元を見て書いた。元を見ない逆翻訳ではない） | 判定（直した後） |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も） | • Moved “‹ Today ›” at the top of the screen so that it is immediately to the right of the date, which is at the left end. | ・画面の上の「‹ 今日 ›」を、左の端にある日付のすぐ右に来るように移しました。 | まだ（元を見ない逆翻訳の後） |
| zh-Hans | • 屏幕顶部的“‹ 今天 ›”已移到左端日期的右边，紧挨着日期。 | ・画面の上の「‹ 今日 ›」を、左端の日付の右に、日付のすぐとなりに移しました。 | まだ（元を見ない逆翻訳の後） |
| zh-Hant | • 螢幕頂端的「‹ 今天 ›」已移到左端日期的右邊，緊鄰日期。 | ・画面の上の「‹ 今日 ›」を、左端の日付の右に、日付のすぐとなりに移しました。 | まだ（元を見ない逆翻訳の後） |
| ko | • 화면 위쪽의 ‘‹ 오늘 ›’을 왼쪽 끝에 있는 날짜의 바로 오른쪽으로 옮겼어요. | ・画面の上の「‹ 今日 ›」を、左の端にある日付のすぐ右に移しました。 | まだ（元を見ない逆翻訳の後） |
| fr-FR（fr-CA も） | • En haut de l’écran, « ‹ Auj. › » a été déplacé juste à droite de la date, qui se trouve tout à gauche. | ・画面の上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左にあります。 | まだ（元を見ない逆翻訳の後） |
| de-DE | • „‹ Heute ›“ oben auf dem Bildschirm wurde direkt rechts neben das Datum verschoben, das am linken Rand steht. | ・画面の上の「‹ 今日 ›」を、左の端にある日付のすぐ右どなりに移しました。 | まだ（元を見ない逆翻訳の後） |
| it | • In alto sullo schermo, “‹ Oggi ›” è stato spostato subito a destra della data, che si trova all’estremità sinistra. | ・画面の上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左の端にあります。 | まだ（元を見ない逆翻訳の後） |
| pt-BR | • No alto da tela, “‹ Hoje ›” foi movido para logo à direita da data, que fica no extremo esquerdo. | ・画面の上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左の端にあります。 | まだ（元を見ない逆翻訳の後） |
| pt-PT | • No topo do ecrã, “‹ Hoje ›” foi movido para logo à direita da data, que fica no extremo esquerdo. | ・画面のいちばん上で、「‹ 今日 ›」を日付のすぐ右に移しました。日付はいちばん左の端にあります。 | まだ（元を見ない逆翻訳の後） |
| es-MX | • En la parte superior de la pantalla, “‹ Hoy ›” se movió justo a la derecha de la fecha, que está en el extremo izquierdo. | ・画面の上で、「‹ 今日 ›」が日付のすぐ右に移りました。日付はいちばん左の端にあります。 | まだ（元を見ない逆翻訳の後） |
| es-ES | • En la parte superior de la pantalla, “‹ Hoy ›” se ha movido justo a la derecha de la fecha, que está en el extremo izquierdo. | ・画面の上で、「‹ 今日 ›」が日付のすぐ右に移りました。日付はいちばん左の端にあります。 | まだ（元を見ない逆翻訳の後） |

### 元を見ない逆翻訳がまだの物（直した物の一覧）

直した Claude は日本語の元を読んで直しを書いたので、自分で訳し戻しても元を見ない逆翻訳になりません（記憶から元を消せない）。次の物は、R（日本語の元・契約・GLOSSARY・PROPOSALS・この節を読まない Claude）に訳の字だけを渡して訳し戻してもらい、判定の 2 役にかけるまで「まだ」です。

1. 新機能の文の行 1 (b)、11 組（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・pt-PT・es-MX・es-ES。上の表の「直した訳」の列、`docs/i18n/back/store-1_4_1-b.md`）。R の逆翻訳は同じファイルの表に列を足して書く。
2. `SUPPORT.en.md` の「How do I zoom in and out?」の 2 段落目の 2 つ目の文と、`PROPOSALS_1_4_1.md` §3.1.2 の en の同じ文（役 W・A が上の「直した字」を入れた後。今のファイルはまだ前の字）。

本人の確認ページで並べ方 (b) の行を見せるのは 1 の判定の後、SUPPORT の英語を Web に出すのは 2 の判定の後です。

**済み（2026-11-22 02:5x、リード。Workflow wf_7c2ec0aa-063）**: 1 と 2 は、訳の字だけ（ファイルもツールも使わない Claude）で元を見ずに訳し戻し、別の Claude が判定した。**12 行とも ○**（1 の 11 組と、2 の英文 1 つ）。2 の直した字は、リードが `SUPPORT.en.md` と `PROPOSALS_1_4_1.md` §3.1.2 に入れた（「On a narrow screen (a narrow iPad window, or iPhone in portrait except on the inner screen of iPhone Duo), this button is at the left of the second row (the Day, Week, Month and Year switch).」）。逆翻訳は「狭い画面（iPad の幅の狭いウィンドウ、または縦向きの iPhone。ただし iPhone Duo の内側の画面は除く）では、このボタンは2段目（日・週・月・年の切り替え）の左側にあります。」で、except が縦の iPhone だけにかかる。1 の逆翻訳の表は `docs/i18n/back/store-1_4_1-b.md` の最後の節。

### 全部の表（アプリの 11 キー、99 件）

同じ逆翻訳で同じ注の言語は 1 行にまとめました。「全部」は 9 言語です。逆翻訳の（ ）は R の注です。判定は判定の 2 役の × でない行を ○ と書きました（上の初めの点）。

| キー | 元の日本語 | 言語 | 逆翻訳（元を見ない） | 判定 | 注（直した Claude） |
| --- | --- | --- | --- | --- | --- |
| `header.zoomReset.spoken` | 等倍に戻す | en | ズームをリセット | ○ | 押すと等倍に戻る同じボタンの、英語の画面のふつうの名前（契約 §8.1 の案の Reset Zoom。GLOSSARY §5）。押した後の大きさは言わないが、ボタンの読み上げの名前なので足りる |
| `header.zoomReset.spoken` | 等倍に戻す | zh-Hans・zh-Hant・ko | 元の大きさに戻す | ○ | 「元の大きさ（元のサイズ）」は GLOSSARY §5 の等倍の語。「戻す」「戻る」は名前の形の差。「実際の大きさ」「合わせる」の語は無い |
| `header.zoomReset.spoken` | 等倍に戻す | fr | 元のサイズに戻る | ○ | 「元の大きさ（元のサイズ）」は GLOSSARY §5 の等倍の語。「戻す」「戻る」は名前の形の差。「実際の大きさ」「合わせる」の語は無い |
| `header.zoomReset.spoken` | 等倍に戻す | de | 元のサイズに戻す（リセットする） | ○ | 「元の大きさ（元のサイズ）」は GLOSSARY §5 の等倍の語。「戻す」「戻る」は名前の形の差。「実際の大きさ」「合わせる」の語は無い |
| `header.zoomReset.spoken` | 等倍に戻す | es・it・pt-BR | 元の大きさに戻る | ○ | 「元の大きさ（元のサイズ）」は GLOSSARY §5 の等倍の語。「戻す」「戻る」は名前の形の差。「実際の大きさ」「合わせる」の語は無い |
| `settings.hand.header` | 利き手 | en・zh-Hans・zh-Hant・fr・de・es・it・pt-BR | 利き手 | ○ | 同じ |
| `settings.hand.header` | 利き手 | ko | 主に使う手 | ○ | 「主に使う手」は利き手のこと（GLOSSARY §5） |
| `settings.hand.right` | 右手 | 全部 | 右手 | ○ | 同じ |
| `settings.hand.left` | 左手 | 全部 | 左手 | ○ | 同じ |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | en | 「左手」を選ぶと、画面上部のボタンの並び順が左右逆になり、隠したツールバーの丸いボタンが右下に移ります。紙とあなたの手書きはそのままです。 | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | zh-Hans | 「左手」を選ぶと、画面上部のボタンの並びが左右逆になり、ツールバーをしまったときの丸いボタンが右下に移ります。紙と手書きの内容はそのまま変わりません。 | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | zh-Hant | 「左手」を選ぶと、画面上端のボタンの並びが左右逆になり、ツールバーをしまったときの丸いボタンが右下に移ります。紙と手書きの内容はそのまま変わりません。 | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | ko | 「左手」を選ぶと、画面上部のボタンの順番が左右逆に変わり、隠したツールバーの丸いボタンが右下に移ります。紙と手書きはそのままです。 | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | fr | 「左手」を選ぶと、画面上部のボタンの順序が左右逆になり、最小化した（縮めた）ツールバーの丸いボタンが右下に移ります。紙と、あなたが書いたものはそのままです。 | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | de | 「左手」を選ぶと、画面上部のボタンが左右逆に並び、しまった（脇へ置いた）ツールバーの丸いボタンが右下へ移ります。紙とあなたの手書きは変わりません。 | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | es | 「左手」を選ぶと、画面上部のボタンの並び順が左右逆になり、隠したツールバーの丸いボタンが右下の隅に移ります。紙と、書いたものは変わりません。（「oculta」は「隠れた・隠した」の意味。敬語の usted で呼びかけている） | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | it | 「左手」を選ぶと、画面の上のほうにあるボタンの並び順が左右逆になり、縮めた（小さくした）ツールバーの丸いボタンが右下に移ります。紙と、あなたが書いたものはそのままです。（「ridotta」は「縮小した・小さくした」の意味。敬語の Lei で呼びかけている） | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `settings.hand.footer` | 左手にすると、画面の上のボタンの並びが左右逆になり、しまったツールバーの丸いボタンが右下へ移ります。紙と書いた文字はそのままです。 | pt-BR | 「左手」を選ぶと、画面上部のボタンの並び順が左右逆になり、隠したツールバーの丸いボタンが右下の隅へ行きます。紙と、あなたが書いたものは変わりません。（「oculta」は「隠れた・隠した」の意味。você で呼びかけている） | ○ | 「しまった」が「隠した」「しまったときの」「縮めた」「脇へ置いた」になるのは、各言語の今のアプリの、しまうの語（GLOSSARY §4・§5）。「書いた文字」は「手書き」「書いたもの」。抜けた事実も、元に無い事実も無い |
| `toolbar.grip.spoken` | ツールバーを動かす | en・zh-Hans・zh-Hant・fr・de | ツールバーを移動 | ○ | 同じ（「移動」「動かす」「移す」の差） |
| `toolbar.grip.spoken` | ツールバーを動かす | ko | ツールバーを移す | ○ | 同じ（「移動」「動かす」「移す」の差） |
| `toolbar.grip.spoken` | ツールバーを動かす | es・it・pt-BR | ツールバーを動かす | ○ | 同じ（「移動」「動かす」「移す」の差） |
| `toolbar.grip.hint` | 上下左右の端へ移せます | en | 上・下・左・右の端に動かせます | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | zh-Hans・zh-Hant | 上下左右の端に移動できます | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | ko | 上、下、左、右の端に移せます | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | fr | 画面の上・下・左・右の端へ動かせます（主語はないが、女性形の語尾からツールバーのこととわかる） | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | de | 上・下・左・右の端へ動かせます | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | es | 上・下・左・右の端に動かせます（「画面の」とは書いていない） | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | it | 画面の上・下・左・右の端に動かせます | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.grip.hint` | 上下左右の端へ移せます | pt-BR | 上・下・左・右の端に動かせます（「movida」は女性形で、ツールバー（a barra）を指すと読める。「画面の」とは書いていない） | ○ | 「画面の」の有無の差。元も「上下左右の端」で、comment は画面の端 |
| `toolbar.moveTo.top` | 上へ移す | en・fr | 上へ移動 | ○ | 元も「上へ移す」で、端までとは言っていない（読み上げの操作の名前） |
| `toolbar.moveTo.top` | 上へ移す | zh-Hans | 上部へ移動 | ○ | 元も「上へ移す」で、端までとは言っていない（読み上げの操作の名前） |
| `toolbar.moveTo.top` | 上へ移す | zh-Hant | 上端へ移動 | ○ | 元も「上へ移す」で、端までとは言っていない（読み上げの操作の名前） |
| `toolbar.moveTo.top` | 上へ移す | ko | 上へ移す | ○ | 元も「上へ移す」で、端までとは言っていない（読み上げの操作の名前） |
| `toolbar.moveTo.top` | 上へ移す | de | 上へ（動詞なし。「端」の語もない） | ○ | 今の `toolbar.moveEdge.*`（Nach unten links）と同じ、動詞の無い形（GLOSSARY §5） |
| `toolbar.moveTo.top` | 上へ移す | es・it・pt-BR | 上へ動かす（端までとは書いていない） | ○ | 元も「上へ移す」で、端までとは言っていない（読み上げの操作の名前） |
| `toolbar.moveTo.bottom` | 下へ移す | en・fr | 下へ移動 | ○ | 元も「下へ移す」で、端までとは言っていない |
| `toolbar.moveTo.bottom` | 下へ移す | zh-Hans・zh-Hant | 下部へ移動 | ○ | 元も「下へ移す」で、端までとは言っていない |
| `toolbar.moveTo.bottom` | 下へ移す | ko | 下へ移す | ○ | 元も「下へ移す」で、端までとは言っていない |
| `toolbar.moveTo.bottom` | 下へ移す | de | 下へ（動詞なし。「端」の語もない） | ○ | 今の `toolbar.moveEdge.*` と同じ、動詞の無い形 |
| `toolbar.moveTo.bottom` | 下へ移す | es・it・pt-BR | 下へ動かす（端までとは書いていない） | ○ | 元も「下へ移す」で、端までとは言っていない |
| `toolbar.moveTo.left` | 左へ移す | en・fr | 左へ移動 | ○ | 元も「左へ移す」で、端までとは言っていない |
| `toolbar.moveTo.left` | 左へ移す | zh-Hans・zh-Hant | 左側へ移動 | ○ | 元も「左へ移す」で、端までとは言っていない |
| `toolbar.moveTo.left` | 左へ移す | ko | 左へ移す | ○ | 元も「左へ移す」で、端までとは言っていない |
| `toolbar.moveTo.left` | 左へ移す | de | 左へ（動詞なし。「端」の語もない） | ○ | 今の `toolbar.moveEdge.*` と同じ、動詞の無い形 |
| `toolbar.moveTo.left` | 左へ移す | es・it・pt-BR | 左へ動かす（端までとは書いていない） | ○ | 元も「左へ移す」で、端までとは言っていない |
| `toolbar.moveTo.right` | 右へ移す | en・fr | 右へ移動 | ○ | 元も「右へ移す」で、端までとは言っていない |
| `toolbar.moveTo.right` | 右へ移す | zh-Hans・zh-Hant | 右側へ移動 | ○ | 元も「右へ移す」で、端までとは言っていない |
| `toolbar.moveTo.right` | 右へ移す | ko | 右へ移す | ○ | 元も「右へ移す」で、端までとは言っていない |
| `toolbar.moveTo.right` | 右へ移す | de | 右へ（動詞なし。「端」の語もない） | ○ | 今の `toolbar.moveEdge.*` と同じ、動詞の無い形 |
| `toolbar.moveTo.right` | 右へ移す | es・it・pt-BR | 右へ動かす（端までとは書いていない） | ○ | 元も「右へ移す」で、端までとは言っていない |

### 全部の表（新機能の文、11 組 × 5 行）

R の控えの訳の字が、今の `whatsnew.txt` の字と同じことを機械で照らしました（55 行とも同じ。fr-FR の行 1 (a) と行 3 は、R の控え `store-1_4_1-en.md` の « » の内側が普通の空白で、ファイルは U+00A0。違いはその空白だけで、字は同じ）。行 1 (b) は上の「× と直し」の表です。

| 行 | 元の日本語（`source-ja`） | ロケール | 逆翻訳（元を見ない） | 判定 | 注（直した Claude） |
| --- | --- | --- | --- | --- | --- |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | en-US（en-GB・en-AU・en-CA も） | ・画面上部の「‹ Today（今日） ›」を左端に移し、その右に日付を置きました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い。R の注: 虫めがねのボタン（等倍）も一緒に動いたのかは、この行からは分かりません |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | zh-Hans | ・画面上部の「‹ 今日 ›」を左端に移し、日付はその右に並ぶようになりました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | zh-Hant | ・画面上端の「‹ 今日 ›」を左端に移し、日付はその右に並ぶようになりました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | ko | ・画面上部の「‹ 今日 ›」を左端に移して、日付をその右に置きました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | fr-FR（fr-CA も） | ・画面上部で「‹ 今日 ›」（Auj.＝aujourd’hui の略）をいちばん左へ移し、日付がその右に出るようになりました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い。R の注: 「Auj.」は略語ですが、フランス語の読み手にはすぐ分かります |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | de-DE | ・画面上部の「‹ 今日 ›」を左端へ移し、日付はその右に来るようになりました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | it | ・画面の上部で、「‹ 今日 ›」をいちばん左の端に移し、日付はその右に出るようになりました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | pt-BR | ・画面の上部で、「‹ 今日 ›」をいちばん左の端に移し、日付はその右に置きました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | pt-PT | ・画面のいちばん上で、「‹ 今日 ›」をいちばん左の端に移し、日付はその右に置きました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | es-MX | ・画面の上部で、「‹ 今日 ›」がいちばん左の端に移り、日付はその右に置かれました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 1 (a) | ・画面の上の「‹ 今日 ›」を左の端に移し、日付をその右に並べました。 | es-ES | ・画面の上部で、「‹ 今日 ›」がいちばん左の端に移り、日付はその右に置かれました。 | ○ | 同じ。R の注（en）の「等倍のボタンも一緒に動いたかは分からない」は、元の行 1 (a) にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | en-US（en-GB・en-AU・en-CA も） | ・拡大や縮小をした後、ボタン 1 つで、拡大も縮小もしていない元の大きさに戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い。R の注: どのボタンか・どこにあるかは書いていません |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | zh-Hans | ・拡大や縮小をした後、ボタン一つだけで、拡大も縮小もしていない元の大きさに戻せるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | zh-Hant | ・拡大や縮小をした後、ボタン一つだけで、拡大も縮小もしていない元の大きさに戻せるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | ko | ・拡大・縮小した後に、ボタン一つで、拡大も縮小もしていない元の大きさに戻せるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | fr-FR（fr-CA も） | ・拡大や縮小をした後、ボタン 1 つで、ページが拡大も縮小もされていない元のサイズに戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | de-DE | ・拡大や縮小をした後、ボタン 1 つで元のサイズ（拡大も縮小もしていない状態）に戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い。R の注: 「Originalgröße」は単独だと「原寸」とも読めますが、かっこの言い添えで取り違えはありません |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | it | ・拡大や縮小をした後、ボタンひとつで元の大きさ（ページが拡大も縮小もされていない大きさ）に戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | pt-BR | ・拡大や縮小をした後、ボタンひとつで元の大きさ（ページが拡大も縮小もされていない大きさ）に戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | pt-PT | ・拡大や縮小をした後、ボタンひとつで元の大きさ（ページが拡大も縮小もされていない大きさ）に戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | es-MX | ・拡大や縮小をした後、ボタンひとつで元の大きさ（ページが拡大も縮小もされていない大きさ）に戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで、拡大も縮小もしていないもとの大きさ（等倍）に戻せるようになりました。 | es-ES | ・拡大や縮小をした後、ボタンひとつで元の大きさ（ページが拡大も縮小もされていない大きさ）に戻れるようになりました。 | ○ | 「等倍」は「拡大も縮小もしていない元の大きさ」と言い添えた形で、どのロケールも同じ。どのボタンかは元にも無い |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | en-US（en-GB・en-AU・en-CA も） | ・設定に「利き手」を加えました。「左手」を選ぶと、画面上部のボタンの並び順が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」。R の注: 丸いボタンが右下へ移ることは書いていません（アプリの説明の文には書いてあります） |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | zh-Hans | ・「設定」に「利き手」を新しく加えました。「左手」を選ぶと、画面上部のボタンの並びが左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | zh-Hant | ・「設定」に「利き手」を新しく加えました。「左手」を選ぶと、画面上端のボタンの並びが左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | ko | ・設定に「主に使う手」を加えました。「左手」を選ぶと、画面上部のボタンの順番が左右逆に変わります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | fr-FR（fr-CA も） | ・設定に「利き手」の欄を加えました。「左手」を選ぶと、画面上部のボタンの順序が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | de-DE | ・設定に「利き手」の欄ができました。「左手」を選ぶと、画面上部のボタンが左右逆に並びます。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」。R の注: 「Dominante Hand」はやや専門的（医学やスポーツの言い方）な響きですが、意味は「利き手」ではっきりしています。「seitenverkehrt」は「鏡に映したように左右逆」の語で、並びが逆になると読めます（ボタンの絵まで反転すると取る人は少ないと思います） |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | it | ・設定に「利き手」の項目が加わりました。「左手」を選ぶと、画面の上部のボタンの並び順が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | pt-BR | ・「設定」に「利き手」の項目が加わりました。「左手」を選ぶと、画面上部のボタンの並び順が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | pt-PT | ・「設定」に「利き手」の項目が加わりました。「左手」を選ぶと、画面のいちばん上のボタンの並び順が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | es-MX | ・「設定」に「利き手」の項目が加わりました。「左手」を選ぶと、画面上部のボタンの並び順が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 3 | ・設定に「利き手」を足しました。「左手」にすると、画面の上のボタンの並びが左右逆になります。 | es-ES | ・「設定」に「利き手」の項目が加わりました。「左手」を選ぶと、画面上部のボタンの並び順が左右逆になります。 | ○ | 「利き手」「左手」はアプリの `settings.hand.header`・`settings.hand.left` と同じ字（ko の「主に使う手」も同じ）。「足した」が「加えた」「欄ができた」 |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | en-US（en-GB・en-AU・en-CA も） | ・iPad では、指でツールバーを上・下・左・右の端に動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差）。R の注: 「edge」は画面の端と読むのが自然です。Apple Pencil では動かないことまでは書いていません |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | zh-Hans | ・iPad では、指でツールバーを上下左右の端に移せるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | zh-Hant | ・iPad では、指でツールバーを上下左右の端に移せるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | ko | ・iPad では、指でツールバーを上・下・左・右の端に移せるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | fr-FR（fr-CA も） | ・iPad では、指でツールバーを画面の上・下・左・右の端へ動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | de-DE | ・iPad では、指でツールバーを上・下・左・右の端へ動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | it | ・iPad では、指でツールバーを画面の上・下・左・右の端に動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | pt-BR | ・iPad では、指でツールバーを画面の上・下・左・右の端に動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | pt-PT | ・iPad では、指でツールバーを画面の上・下・左・右の端に動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | es-MX | ・iPad では、指でツールバーを画面の上・下・左・右の端に動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 行 4 | ・iPad では、ツールバーを指で上下左右の端へ動かせるようになりました。 | es-ES | ・iPad では、指でツールバーを画面の上・下・左・右の端に動かせるようになりました。 | ○ | 同じ（「画面の」の有無の差） |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | en-US（en-GB・en-AU・en-CA も） | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | zh-Hans | 訳文は AI が作ったもので、まだその言語を母語とする人の確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | zh-Hant | 訳文は AI で作ったもので、まだその言語を母語とする人の校閲を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | ko | 翻訳は AI で作ったもので、まだネイティブの確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | fr-FR（fr-CA も） | 翻訳は AI で作ったもので、まだ母語話者の校閲を受けていません。誤りをお知らせください。 | ○ | 1.4 と同じ字。R の注: 「Signalez-nous les erreurs.」は「どうぞ」に当たる語のない命令形で、少し素っ気なく聞こえます。「locuteurs natifs」は男性形を総称に使う形です |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | de-DE | 翻訳は AI で作られ、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字。R の注: 「Muttersprachlern」は男性形を総称に使う形です（ドイツ語ではふつうの言い方） |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | it | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせくださるようお願いします。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | pt-BR | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | pt-PT | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りがあればお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | es-MX | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りを見つけたらお知らせください。 | ○ | 1.4 と同じ字 |
| 訳についての 1 行 | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | es-ES | 翻訳は AI で作ったもので、まだ母語話者の確認を受けていません。誤りを見つけたらお知らせください。 | ○ | 1.4 と同じ字 |

### 機械で照らしたこと

- アプリの 11 キーの `docs/i18n/back/<言語>.json` の `text` は、9 言語とも今の `tools/l10n/translations/<言語>.json` の字と同じです（R が訳し戻した字が、そのまま入っている）。
- 新機能の文の「利き手」「左手」は、11 組ともアプリの `settings.hand.header`・`settings.hand.left` の訳と同じ字、行 1 の「今日」は `header.today` の訳と同じ字です（pt-PT はアプリの pt-BR の語）。行 1 (b) の 11 組も同じです。
- K-8 の句（古い版の端末での見え方）は、11 組の 5 行と行 1 (b) のどれにもありません（契約 §5.2）。
- 字数（L-9 の数え方）: 既定（行 1 (a)）で en-US 565・zh-Hans 176・zh-Hant 176・ko 274・fr-FR 678・de-DE 691・it 703・pt-BR 643・pt-PT 629・es-MX 677・es-ES 691。行 1 (b) にすると en-US 593・zh-Hans 178・zh-Hant 177・ko 273・fr-FR 685・de-DE 688・it 706・pt-BR 639・pt-PT 626・es-MX 687・es-ES 696。どれも 4,000 字に入ります。
- 行 1 (b) にした 11 のファイルを一度作業ツリーに置いて `lint.py` を走らせ、L-9 は ok でした。その後ファイルを (a) の字に戻し、11 のファイルの sha1 が前と同じことを確かめました（commit したのは (a) の字）。

### lint

この節の直しの後の字で、`build.py`（`Localizable.xcstrings` を作り直した。449 キー）、`build.py --check`・`lint.py`（L-1〜L-14）・`baseline.py --check` は 4 つとも終了 0 です（`baseline.py` は 9cbc3c9 の 516 字のまま。L-12 の字の幅の目安の警告は 58 件で、1.3 の 12 と同じ数。1.4.1 の 11 キーの警告はありません。11 キーのうち画面に出るのは利き手の見出し・選び・脚注だけで、`maxEm` はありません）。

`Localizable.xcstrings` を HEAD（796bff1）の字と JSON で比べました。キーの足し引きは無く、変わったのは 1.4.1 の 4 キーの、上の 15 の訳だけです（`settings.hand.footer` の de・es・fr・ko・pt-BR・zh-Hans・zh-Hant、`toolbar.grip.hint` の fr・it・zh-Hans・zh-Hant、`toolbar.moveTo.bottom`・`toolbar.moveTo.top` の zh-Hans・zh-Hant）。ほかの 7 キーは D1 の字のままで、11 キーの外は 1 字も変わっていません。ja の字・comment・`jaSha1` も変わっていません。

## 15. 1.4.1 の店と Web の文の直し（本人の 11/22 の直しの後、2026-11-22）

元は契約の第 3 版 §16.9 です（[R1_4_1_CONTRACT.md](../R1_4_1_CONTRACT.md)。本人の 11/22 の直し: 右手では「‹ 今日 ›」と等倍を右の端に、日と週の等倍は 1 ページの幅が画面の幅にちょうど合う大きさ）。替わった文は 3 つの所にあります。(1) 新機能の文の行 1（並び 案 B）と行 2（`docs/store/source-ja/whatsnew.txt`。W が契約の `>` の行から機械で写した。16f79a3）。(2) 審査メモの「What is new in 1.4.1」の 1・2（`docs/store/review-note.txt`。契約 §16.9 の英語そのまま。W）。(3) `docs/SUPPORT.en.md` の「How do I zoom in and out?」の 2 段落目の 1〜5 文目と、「How do I use it with my left hand?」の 2 文目（W。元は `docs/SUPPORT.md:153`・`:157`）。行 3・行 4・訳についての 1 行、審査メモの 3・4、SUPPORT のほかの文は替わっていないので、14 の判定が今も有効です。

- **訳**: X が書きました（e52f6b2）。11 のフォルダ（en-US・zh-Hans・zh-Hant・ko・fr-FR・de-DE・it・pt-BR・pt-PT・es-MX・es-ES）の `whatsnew.txt` の 1 行目と 2 行目だけです（11 × 2 = 22 行。en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写し）。行 2 は等倍を名詞で言わず、アプリの読み上げ（`header.zoomReset.spoken`。枝 `r141-w-x2` の 5c58e15 の字）と同じ「ズームを戻す」の動詞で書き、日と週・月と年の大きさをそのまま書きました。審査メモと SUPPORT の英語は W の字です。
- **元を見ない逆翻訳**: R が、X が用意した 30 行（新機能の文の 22 行・審査メモの 2 行・SUPPORT.en の 6 文）の訳の字だけを受け取って訳し戻しました（R へ渡す段取りはリードの Workflow。渡した字に日本語は無く、かなが 0 なのを X と FIX が機械で確かめた）。逆翻訳は `docs/i18n/back/store-1_4_1-fix.md` にあります。
- **判定**: 訳を書いた Claude とも R とも別の Claude 2 人（判定の 2 役。相談していない）が、30 行の訳と逆翻訳を、日本語の元・契約 §0・§8・§16・GLOSSARY（3c82210 の字に §16.9 の新しい等倍の定義を足したもの）・この文書の 14 と照らしました。判定 2 は、日本語の元の 6 つの所も、平たい言葉か・§16.9 の事実と合うかで見ました。**2 人の行は合わせて 60 行で、× は 0 でした。** △ は 2 つです（訳の行の 1 つと、日本語の元の 1 つ）。
- **この作業（FIX）**: 2 人の判定の全部（○・△・× と理由、ついでの気づき）を受け取り、△ と気づきを 1 つずつ契約・コードの枝・ファイルで確かめました。FIX は日本語の元を読んでいます。下の全部の表の注の列は、2 人の判定の理由を FIX がまとめたものです。
- **母語の人の確認ではありません。**
- **あとから足した 2 つ**（2026-11-22）: アプリの読み上げ `header.zoomReset.spoken` の訳し直し（9 行。契約 §16.9 の「アプリの文」）と、案 A の英語の 2 文（下の「元を見ない逆翻訳がまだの物」の 1）も、元を見ない逆翻訳と 2 人の判定にかけました。この節のいちばん下の 2 つの小見出し（「アプリの読み上げ `header.zoomReset.spoken` の訳し直し」「案 A の英語の 2 文」）に書きました。どちらも × 0 です。

### 結果

| 対象 | 行 | 判定 1 | 判定 2 | 直した後 |
| --- | --- | --- | --- | --- |
| 新機能の文の行 1（並び 案 B。11 組） | 11 | ○ 11 | ○ 11 | — |
| 新機能の文の行 2（11 組） | 11 | ○ 10・△ 1（pt-PT） | ○ 11 | 直さない（下の 1） |
| 審査メモの 1・2 | 2 | ○ 2 | ○ 2 | — |
| `SUPPORT.en.md` の 6 文 | 6 | ○ 6 | ○ 6 | — |
| **訳の行の計** | **30** | **○ 29・△ 1・× 0** | **○ 30・× 0** | **判定の後に替えた訳の行は 0** |
| 日本語の元（判定 2 だけ。行 1・行 2、審査メモの要約の 2 文、`SUPPORT.md:153`・`:157`） | 6 | — | ○ 5・△ 1（行 2） | 直さない（下の 2。リードが決める） |

どの行にも、次の誤りはありませんでした（2 人とも）: 左右の取り違え、月と年を「幅に合わせる」「元の大きさ」と言う形、月と年も幅に合うと読める形、画面の名前の取り違え。

### △ と気づきの扱い

| # | 誰の | 所 | 中身 | FIX が確かめたこと | 扱い |
| --- | --- | --- | --- | --- | --- |
| 1 | 判定 1 の △ | pt-PT の行 2 | 「repor o zoom」は pt-PT の言い方で、pt-PT の人が使うアプリは pt-BR なので、読み上げの名前は「Redefinir o zoom」 | アプリの pt-BR の読み上げは「Redefinir o zoom」（`r141-w-x2` 5c58e15 の `tools/l10n/translations/pt-BR.json`）。行 2 の動詞はボタンの名前を引いた形ではない（ほかの言語も文の中の動詞）。pt-PT の店の文は pt-BR の写しにせずポルトガルの書き方で書く決まり（`docs/store/README.md` の「X への手引き」）。「repor」はポルトガルでふつうの「リセット」の動詞で、取り消し（Desfazer）とは別の語。R の逆翻訳は「ズームを元に戻せる」で、等倍に戻せるという元の意味と同じ | **直さない**（2 人とも直さなくてよいとした。直すと 1 行の逆翻訳と判定のやり直しが要る）。そろえるなら「agora pode redefinir o zoom com um único botão」 |
| 2 | 判定 2 の △（S-2） | ja・source-ja の行 2 の「月と年では開いたときの大きさに戻ります」 | 月と年も拡大を覚えるので、拡大を覚えた人がそのページを開くと拡大したまま開き、押すと縮む。「開いたときの大きさ」には戻らない。「初めて開いたとき」と書くと正しい | 契約 §16.3.6（月と年は今のまま `Bounds.open`。等倍は覚えた拡大を消し、次も開いたときの大きさで開く）と `SUPPORT.md:151`（拡大した大きさは種類ごとに覚える）のとおりで、判定 2 の読みは正しい。同じ言い方は契約 §16.9 の行そのもの、審査メモの英語の 2（「the size they open at」）と日本語の要約（「開いたときの大きさ」）にもある。SUPPORT の日本語・英語は「初めて開いたとき」「when you first opened it」で正しい。訳の 11 組は元に忠実 | **直さない**（× ではない。そう読めるのは、月と年の拡大を覚えた人が初めて押す 1 回だけで、押した後は正しい。行は契約 §16.9 が決めた字で、直すと ja・source-ja と 11 組を替え、11 行の逆翻訳と判定をやり直すことになる）。**リードが決める**。直すときの字と数は下 |
| 3 | 判定 1 の気づき | `SUPPORT.md:153` の 2 本の指の文 | 括弧の中で「初めて開いたとき」が 2 回続く。短くするなら「（初めて開いたときより小さくしたときは、その最初の大きさで開きます）」 | 誤りではない（同じ語を繰り返しているので、指すものが 1 通りにしか読めない）。英語は「at that first size」で、すでに短い形 | **直さない**（日本語だけの言い回しの好み。直すかはリードが決めてよい。直しても英語と訳は替わらない） |
| 4 | 判定 1 の気づき | `SUPPORT.md:151`・`SUPPORT.en.md:156`（今回替えていない 1 段落目） | 「縮めた大きさは覚えません」とあるが、日と週の等倍から少し縮めても、初めて開いたときより大きければ、その大きさを覚える。そろえるなら「縮めた大きさ（初めて開いたときより小さい大きさ）は覚えません」 | 覚えるのは初めて開いたときの大きさとの比で、1 より小さい比だけを捨てる（`TegakiKit/Sources/Layout/ZoomPolicy.swift` の `sanitizedRatio` と `AppSettings.setZoomRatio`。3c82210 で FIX が読んだ）。1.4 でも、2 倍から 1.5 倍に縮めるとその大きさを覚えたので、この文の「縮めた」は前から「初めて開いたときより小さくした」の意味で、1.4.1 で新しくずれたのではない。2 段落目の新しい 2 本の指の文の括弧が、正しい境目（初めて開いたとき）を書いている。契約 §16.9 の替える所に入っていない | **直さない**（英語の文も替えることになり、その逆翻訳と判定が要る）。入れるかはリードが決める |
| 5 | 判定 2 の気づき | `docs/store/README.md:64` | 「2 つ目の点は等倍の名詞を使わず」のすぐ後に「「等倍」は GLOSSARY の新しい語」とあり、食い違って読める | そのとおり。行 2 の訳は等倍を名詞で言っていない | **直した**: 「「等倍」の意味は GLOSSARY の新しい定義」（訳の行ではない） |
| 6 | 判定 2 の気づき | 行 2 の動詞 | X の読み上げの字の判定で語が替わったら、行 2 の動詞を照らし直す | 今は 8 言語とも同じ動詞（en resets the zoom = Reset Zoom、zh 重置缩放・重置縮放、ko 확대·축소를 재설정 = 확대·축소 재설정、fr réinitialiser le zoom、de den Zoom zurücksetzen、it reimpostare lo zoom、pt-BR redefinir o zoom、es restablecer el zoom）。pt-PT だけ repor（上の 1） | 記録だけ（`r141-w-x2` の判定で読み上げの字が替わったら、行 2 を直して逆翻訳と判定にかける）。**読み上げの判定は 2 人とも 9 行 ○ で、字は替わらなかったので、行 2 はこのまま**（下の「アプリの読み上げ `header.zoomReset.spoken` の訳し直し」） |
| 7 | 判定 2 の気づき | `docs/SUPPORT.md:7` の最終更新の日 | 公開の日に替える | 契約 §8.5 のとおり | 今は替えない |

**2 を直すときの字と数**（リードが直すと決めたとき）:

- ja・source-ja の行 2 を「…月と年では初めて開いたときの大きさに戻ります。」にする。字数（L-9）は ja 207 → 210、source-ja 252 → 255（「初めて」は 3 字。判定 2 の 209・254 は数え違い）。
- 11 組の行 2 に「初めて」にあたる語を足す（判定 2 の案: en when you first opened them、zh 首次打开时・首次開啟時、ko 처음 열었을 때、fr la première fois que vous les avez ouvertes、de beim ersten Öffnen、it la prima volta che le ha aperte、pt-BR quando você as abriu pela primeira vez、pt-PT quando as abriu pela primeira vez、es al abrirlas por primera vez）。そのときは en・zh・ko・it・pt・es に、fr の alors・de の dann にあたる「押すと」の語を足すとよい（今は「日と週はいつも幅に合う」とも読める並べ方で、元の日本語も同じ並べ方）。11 行の元を見ない逆翻訳と判定をやり直す。
- 審査メモも合わせるなら（`wc -c`、今 3,992）: 英語の 2 を「…go back to the size they first open at.」にすると 3,998 バイトで入る。日本語の要約にも「初めて」を足すと 4,001（要約だけ）・4,007（両方）で上限を超えるので、契約 §16.9 の決まりで英語の「The next page of that type opens at the same size.」を外す（両方を直して外すと 3,956）。英語の 2 を替えたら、その逆翻訳と判定もやり直す。

### 判定の後に替えた字

- **訳の行（新機能の文・審査メモの英語・SUPPORT.en）は 1 つも替えていません。** だから、この節の 30 行のために、もう一度の元を見ない逆翻訳と判定は要りません。
- `docs/store/README.md:64`: 上の 5 の直しと、「元を見ない逆翻訳と判定は…節 15 で受ける（まだ）」を済みに。`:96`（審査メモ）の「1・2（と案 A の 1）はやり直す」を、1・2 は済み・案 A の 1 はまだ、に。
- `docs/store/PROPOSALS_1_4_1.md`: 頭の書きと §1.0・§1.4・§2.4・§3.1・§3.2 の「逆翻訳と判定はまだ・やり直す」を、30 行は済み（× 0）・案 A の英語はまだ、に（案の文の字は替えていない）。
- あとで（2026-11-22）、案 A の英語の 2 文を R と判定にかけ（× 0。この節の下の「案 A の英語の 2 文」）、`docs/store/README.md:96` と PROPOSALS §2.4・§3.2 の「案 A の 1（英文）はまだ」を済みにしました。案の文の字は替えていません。

### 元を見ない逆翻訳がまだの物

直した Claude（FIX）は日本語の元を読んだので、自分で訳し戻しても元を見ない逆翻訳になりません。次の物は、R に訳の字だけを渡して訳し戻してもらい、判定の 2 役にかけるまで「まだ」です（リードがかける）。

1. **案 A の英語の 2 文**: 審査メモの案 A の 1（[PROPOSALS_1_4_1.md](../store/PROPOSALS_1_4_1.md) §2.1 の「1. ‹ Today › and the 1× button (a magnifying glass with "1") are now at the right end of the header, with the date just before them (on narrow screens, 1× ends the second row). Settings > Dominant Hand > Left Hand reverses this order.」）と、左手の FAQ の 2 文目の案 A（§3.2 の「The order of the buttons at the top of the screen is reversed from left to right: “‹ Today ›” and the Reset Zoom button move to the left end, and ⚙ (Settings) to the right end.」）。R に渡した 30 行に入っていませんでした（X の範囲の外）。PROPOSALS §2.4・§3.2 は確認ページで両方の案を見せると決めているので、確認ページの前に要ります。**済み（2026-11-22）**: R が元を見ずに訳し戻し、判定の 2 人とも 2 行 ○（× 0）。判定の後に替えた字はありません。下の「案 A の英語の 2 文」。
2. **案 A の行 1 の 11 組の訳**: 本人が案 A を選んだときだけ作る（契約 §16.9）。まだ作っていません。作ったら 11 行を R と判定にかけます。
3. 上の 1（pt-PT）・2（S-2）を、リードが直すと決めたときの行（pt-PT は 1 行、S-2 は 11 行と審査メモの英語の 2）。

### 全部の表（新機能の文、11 組 × 2 行）

訳の字は `docs/i18n/back/store-1_4_1-fix.md` にあります。注の列は 2 人の判定の理由を FIX がまとめたものです。

| 行 | 元の日本語（`source-ja`） | ロケール | 逆翻訳（元を見ない） | 判定 1 | 判定 2 | 注 |
| --- | --- | --- | --- | --- | --- | --- |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | en-US（en-GB・en-AU・en-CA も） | • 画面上部の「‹ 今日 ›」を右端に移し、日付を左端に置きました。 | ○ | ○ | 右の端・左の端とも正しい向き。「the right end」は前の行 1 (a) の「the left end」と同じ形（14 で ○）。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | zh-Hans | • 画面上部の「‹ 今日 ›」を右端に移動し、日付は左端に配置しました。 | ○ | ○ | 右端・左端とも正しい向き。「屏幕顶部」は行 3 と同じ語。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | zh-Hant | • 画面上部の「‹ 今日 ›」を右端に移動し、日付は左端に配置しました。 | ○ | ○ | 右端・左端とも正しい向き。「螢幕頂端」は行 3 と同じ語。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | ko | • 画面上部の「‹ 今日 ›」を右端に移し、日付を左端に置きました。 | ○ | ○ | 右の端・左の端とも正しい向き。助詞（을）も合っている。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | fr-FR（fr-CA も） | • 画面の上部で、「‹ 今日 ›」がいちばん右に移動し、日付がいちばん左に表示されるようになりました。 | ○ | ○ | いちばん右・いちばん左とも正しい向き。「Auj.」はアプリの `header.today` の字。« » の内側は U+00A0 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | de-DE | • 画面上部の「‹ 今日 ›」が右端に移動し、日付は左端に表示されるようになりました。 | ○ | ○ | 右の端・左の端とも正しい向き。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | it | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に表示されるようになりました。 | ○ | ○ | 右の端・左の端とも正しい向き。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | pt-BR | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 | ○ | ○ | 右の端・左の端とも正しい向き。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | pt-PT | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 | ○ | ○ | 右の端・左の端とも正しい向き。「Hoje」はアプリの pt-BR の `header.today` の字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | es-MX | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 | ○ | ○ | 右の端・左の端とも正しい向き。「今日」はアプリの `header.today` と同じ字 |
| 行 1 | ・画面の上の「‹ 今日 ›」を右の端に移し、日付を左の端に置きました。 | es-ES | • 画面の上部で、「‹ 今日 ›」が右端に移動し、日付は左端に置かれました。 | ○ | ○ | 右の端・左の端とも正しい向き。「今日」はアプリの `header.today` と同じ字 |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | en-US（en-GB・en-AU・en-CA も） | • 拡大・縮小したあと、ボタン一つで拡大・縮小を元に戻せるようになりました。日と週のページでは、1日分または1週間分のページが画面の幅にぴったり収まります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | 「fits」は日と週の働きを言う動詞で、等倍やボタンの名前ではない（月と年には使っていない。GLOSSARY の「en に Fit を使わない」は名前の決まり）。逆翻訳の「元に戻せる」は resets the zoom を訳し戻した字で、取り消し（Undo）の意味ではない |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | zh-Hans | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日ページと週ページでは、1日または1週間のページの幅が画面の幅とちょうど同じになり、月ページと年ページでは、開いたときの大きさに戻ります。 | ○ | ○ | 「重置缩放」はアプリの読み上げと同じ字。「正好与屏幕宽度相同」で、合わせるの語（适合）は使っていない。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | zh-Hant | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日ページと週ページでは、1日または1週間のページの幅が画面の幅とちょうど同じになり、月ページと年ページでは、開いたときの大きさに戻ります。 | ○ | ○ | 「重置縮放」はアプリの読み上げと同じ字。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | ko | • 拡大・縮小したあと、ボタン一つで拡大・縮小をリセットできるようになりました。日ページと週ページでは1日または1週間のページの幅が画面の幅にぴったり合い、月ページと年ページでは開いたときの大きさに戻ります。 | ○ | ○ | 「딱 맞고」は動詞で、名前の「맞춤」ではない。「연」はアプリの切り替えの字と同じ。頭の「확대·축소」が 2 回出るのは前の行 2 と同じ形 |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | fr-FR（fr-CA も） | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、そのとき1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | 3 つの文に分けたが、「alors」で押した後のことと分かる。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | de-DE | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、そのとき1日または1週間のページの幅が画面の幅とちょうど同じになります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | 「dann」で押した後のことと分かる。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | it | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | Lei の形。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | pt-BR | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | 日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | pt-PT | • 拡大または縮小したあと、ボタン一つでズームを元に戻せるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 | △ | ○ | 判定 1 の △: 「repor o zoom」はポルトガルでふつうの「リセット」の動詞で、取り消し（Desfazer）ではない。pt-PT の端末の読み上げは pt-BR の「Redefinir o zoom」で動詞が違うが、行 2 はボタンの名前を引いていない。2 人とも直さなくてよいとした（下の「△ と気づきの扱い」の 1） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | es-MX | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | es-MX と es-ES は同じ字（前の版の行 2 も同じ）。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |
| 行 2 | ・拡大・縮小した後に、ボタン 1 つで等倍に戻せるようになりました。日と週では 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年では開いたときの大きさに戻ります。 | es-ES | • 拡大または縮小したあと、ボタン一つでズームをリセットできるようになりました。日と週のページでは、1日または1週間のページが画面の幅ちょうどに収まります。月と年のページは、開いたときの大きさに戻ります。 | ○ | ○ | es-MX と同じ字。日と週だけが幅に合い、月と年は開いたときの大きさ（月と年を幅に合わせる・「元の大きさ」と言う形は無い） |

### 全部の表（審査メモの英語と SUPPORT.en）

| 所 | 元の日本語 | 訳 | 逆翻訳（元を見ない） | 判定 1 | 判定 2 | 注 |
| --- | --- | --- | --- | --- | --- | --- |
| `review-note.txt` の「What is new in 1.4.1」の 1 | （意味の元）日本語の要約の 1 つ目の文「左上に日付、右上に「‹ 今日 ›」と等倍のボタン（設定 › 利き手 › 左手 で逆）。」と、契約 §16.2 の狭い 2 段目 [切り替え][等倍] | 1. The date is now at the left end of the header, and ‹ Today › and the 1× button (a magnifying glass with "1") are at the right end (on narrow screens, 1× ends the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. 日付は見出しの帯（ヘッダー）の左端に移り、‹ 今日 › と 1× ボタン（「1」の入った虫めがね）は右端に来ました（幅の狭い画面では、1× は2段目のいちばん最後に来ます）。設定 > 利き手 > 左手 にすると、この並びが逆になります。 | ○ | ○ | 契約 §16.9 の字と 1 字も違わない。§16.2 の狭い 2 段目 [切り替え][等倍] と合う（「1× ends the second row」）。日本語の要約の 1 つ目の文と同じ意味 |
| `review-note.txt` の「What is new in 1.4.1」の 2 | （意味の元）日本語の要約の 2 つ目の文「等倍は、日と週では 1 日・1 週の幅を画面の幅ちょうどに、月と年では開いたときの大きさにします。」と、契約 §16.3.4（次に開く同じ種類も同じ大きさ） | 2. 1× resets the zoom: on day and week pages, one day or one week fits the screen width exactly; month and year pages go back to the size they open at. The next page of that type opens at the same size. | 2. 1× で拡大・縮小がリセットされます。日と週のページでは1日または1週間が画面の幅にぴったり収まり、月と年のページは開いたときの大きさに戻ります。その種類の次のページも同じ大きさで開きます。 | ○ | ○ | §16.3.1・§16.3.4・§16.3.6 と合う。最後の「The next page of that type opens at the same size.」は日本語の要約に無いが、§16.9 が要約には足さないと決めた文。審査メモは 3,992 バイト |
| `SUPPORT.en.md:158`（How do I zoom in and out? の 2 段落目）の 1 文目 | `SUPPORT.md:153` の 1・2 文目: 右上の「‹ 今日 ›」のとなりにある、虫めがねに「1」の印のボタン（等倍）を押すと、すぐ等倍に戻ります（1.4.1 から）。日と週のページでは 1 日・1 週のページの幅が画面の幅にちょうど合い、月と年のページではそのページを初めて開いたときの大きさになります。 | Tap the button showing a magnifying glass with “1” (Reset Zoom), next to “‹ Today ›” at the top right, to reset the zoom at once (from version 1.4.1): on day and week pages, one day's or one week's page fits the width of the screen exactly; on month and year pages, the page goes back to the size it had when you first opened it. | 右上の「‹ 今日 ›」の隣にある、「1」の入った虫めがねのボタン（ズームをリセット）をタップすると、拡大・縮小を一度でリセットできます（バージョン 1.4.1 から）。日と週のページでは1日分または1週間分のページが画面の幅にぴったり収まり、月と年のページでは最初に開いたときの大きさに戻ります。 | ○ | ○ | 右上で案 B と合う。「(Reset Zoom)」は en の読み上げの字。「at once」は「すぐ」とも「一度で」とも読めるが、どちらでも正しい |
| `SUPPORT.en.md:158` の 2 文目 | `SUPPORT.md:153` の 3 文目: 幅の狭い画面（iPhone の縦と iPad の細い窓。iPhone Duo の開いた画面は除く）では、このボタンは 2 段目（日・週・月・年の切り替え）の右にあります。 | On a narrow screen (a narrow iPad window, or iPhone in portrait except on the inner screen of iPhone Duo), this button is at the right of the second row (the Day, Week, Month and Year switch). | 幅の狭い画面（iPad の幅の狭いウインドウ、または縦向きの iPhone。ただし iPhone Duo の内側の画面は除く）では、このボタンは2段目（日・週・月・年の切り替え）の右にあります。 | ○ | ○ | §16.2 と合う。except は縦の iPhone だけにかかる（14 で直した形のまま） |
| `SUPPORT.en.md:158` の 3 文目 | `SUPPORT.md:153` の 4 文目: 設定 › 利き手 で「左手」にしているときは、左上（幅の狭い画面では 2 段目の左）にあります。 | When “Left Hand” is chosen in the App's Settings > Dominant Hand, it is at the top left (on a narrow screen, at the left of the second row). | アプリの 設定 > 利き手 で「左手」を選んでいるときは、左上にあります（幅の狭い画面では2段目の左）。 | ○ | ○ | 左手では左上、狭い画面では 2 段目の左（§16.2） |
| `SUPPORT.en.md:158` の 4 文目 | `SUPPORT.md:153` の 5 文目: 等倍に戻すと、次に開く同じ種類のページも、アプリを開き直したときも、等倍で開きます。 | After you reset the zoom, pages of the same type keep opening that way, even after you reopen the App. | ズームをリセットすると、その後も同じ種類のページはその大きさで開きます。アプリを開き直しても変わりません。 | ○ | ○ | 元と同じ意味 |
| `SUPPORT.en.md:158` の 5 文目（2 本の指の文。W が足した） | `SUPPORT.md:153` の 6 文目: 2 本の指で大きさを変えると、次からは等倍ではなく、その大きさで開きます（初めて開いたときより小さくしたときは、初めて開いたときの大きさで開きます）。 | If you then change the size with two fingers, they open at the new size instead (or, if you made it smaller than the size the page had when you first opened it, at that first size). | そのあと2本の指で大きさを変えると、今度はその新しい大きさで開きます（ただし、最初に開いたときの大きさより小さくした場合は、その最初の大きさで開きます）。 | ○ | ○ | §16.3.4 と合う（つまむと比を覚えて等倍の印を消す。1 より小さい比は覚えない）。1 段落目の「縮めた大きさは覚えない」とも食い違わない（下の「△ と気づきの扱い」の 4） |
| `SUPPORT.en.md:162`（How do I use it with my left hand?）の 2 文目 | `SUPPORT.md:157` の 2 文目: 画面の上のボタンの並びが左右逆になり、「‹ 今日 ›」と等倍のボタンが左の端に、日付が右の端に移ります。 | The order of the buttons at the top of the screen is reversed from left to right: “‹ Today ›” and the Reset Zoom button move to the left end, and the date to the right end. | 画面上部のボタンの並びが左右逆になります。「‹ 今日 ›」とズームをリセットするボタンが左端に、日付が右端に移ります。 | ○ | ○ | 左右が合っている |

### 機械で照らしたこと

FIX が e52f6b2 の上で、python で照らしました（2 人の判定も同じことを照らしている）。

- R に渡した 30 行は、commit のファイルの字と 30 行とも同じです（新機能の文の 22 行は 11 のフォルダの `whatsnew.txt` の 1・2 行目、審査メモの 2 行と SUPPORT.en の 6 文はファイルにそのままある）。R に渡した字に、かなは 0 です。逆翻訳の 30 行は、渡した 30 行と同じ順・同じ所です。
- 11 のフォルダと ja・source-ja の `whatsnew.txt` の 3 行目から後は、3c82210 と同じです（sha1 が 13 とも同じ）。審査メモの差は 1・2 と日本語の要約の行の 3 行だけです（`git diff --numstat` で 3 行足して 3 行消した）。
- 行 1 の「‹ 今日 ›」の「今日」は、11 組ともアプリの `header.today` の字です（Today・今天・오늘・Auj.・Heute・Oggi・Hoje・Hoy。pt-PT はアプリの pt-BR の語）。fr-FR の « » の内側は U+00A0 です。
- 使わない語（original・origine・Originalgröße・原始・원래・Actual・réelle・reali・real・实际・實際・실제・名前の Fit・Ajuster・Einpassen・Adatta・适合・適合・맞춤、取り消しの Undo・Annuler・Rétablir・Deshacer・Desfazer・Annulla・Ripristina・Rückgängig・恢复・還原・撤销・復原）は、30 行のどれにもありません。
- 行 2 の動詞は、`r141-w-x2`（5c58e15）の読み上げの字と同じ動詞です（上の 6）。
- `Sources`・`TegakiKit`・`Tests`・`tools`・`.github`・`project.yml` は 3c82210 から変わっていません（`git diff` が空）。

### 字数とバイト

| 物 | 字数（L-9 の数え方。上限 4,000） | ファイルのバイト（`wc -c`） |
| --- | ---: | ---: |
| `ja/whatsnew.txt` | 207 | 586 |
| `source-ja/whatsnew.txt` | 252 | 709 |
| `en-US/whatsnew.txt` | 688 | 713 |
| `zh-Hans/whatsnew.txt` | 213 | 598 |
| `zh-Hant/whatsnew.txt` | 213 | 598 |
| `ko/whatsnew.txt` | 341 | 812 |
| `fr-FR/whatsnew.txt` | 867 | 950 |
| `de-DE/whatsnew.txt` | 840 | 879 |
| `it/whatsnew.txt` | 859 | 900 |
| `pt-BR/whatsnew.txt` | 771 | 814 |
| `pt-PT/whatsnew.txt` | 748 | 791 |
| `es-MX/whatsnew.txt` | 820 | 861 |
| `es-ES/whatsnew.txt` | 834 | 873 |
| `review-note.txt`（上限 4,000 バイト） | 3,618 字 | 3,992（最後の改行を除くと 3,991） |

### lint

この節の直しの後の字で、`tools/l10n/lint.py` は L-1〜L-14 とも終了 0 です（`L-9: ok: 12 locales, the URLs on the English side`）。L-12 の字の幅の目安の警告は 58 件で、14 と同じ数です（この節の文はアプリの文字列ではない）。

### アプリの読み上げ `header.zoomReset.spoken` の訳し直し（あとから。2026-11-22）

元は契約 §16.9 の「アプリの文」の表です。ja「等倍に戻す」（`tools/l10n/source/app-P.json`、jaSha1 92b8cb8312）は替えず、comment を新しい等倍の定義（日と週は 1 日・1 週のページの幅が画面の幅にちょうど合う大きさ、月と年はページを初めて開いたときの大きさ）にしました。虫めがねに「1」の印のボタンの読み上げだけの文で、画面に字は出ません（§4 の幅の決まりは関わらない）。14 の判定は前の訳（「元の大きさに戻す」の意味）にしたもので、記録として残します（14 の全部の表の `header.zoomReset.spoken` の 6 行）。

- **訳**: X が、8 言語（zh-Hans・zh-Hant・ko・fr・de・es・it・pt-BR）を「元の大きさに戻す」の意味から「ズームを戻す（リセットする）」の意味に訳し直しました（枝 `r141-w-x2` の 5c58e15。GLOSSARY §5 の「等倍に戻す」の行も同じ字）。en の「Reset Zoom」は替えていません（判定だけ）。`header.today` は comment だけの変更（「空いている手の側の端」→「利き手の側の端」）で、訳は替えていません。
- **元を見ない逆翻訳**: R が、8 言語の訳の字だけ（リードのスクラッチの `rework/x2-for-R.txt`。各行は「言語 TAB キー TAB 訳の字」）を受け取って訳し戻しました（`rework/r2-back.txt`）。逆翻訳は枝 `r141-w-x2` の `docs/i18n/back/app-1_4_1-fix.md`（e72b820）にあり、この枝と一緒に取り込みます。en は訳を替えていないので、新しい逆翻訳はありません。前の訳とその逆翻訳（`docs/i18n/back/<言語>.json` の同じキー）は消していません（契約 §16.9）。
- **判定**: 訳を書いた Claude とも R とも別の Claude 2 人（相談していない。判定 2 は判定 1 の表を読んでいない）が、9 行（8 言語と en）を照らしました。照らした物は、source の comment、契約 §8.1・§16.1・§16.3・§16.9、GLOSSARY §1・§5（`r141-w-x2` の字）、9 言語の `translations/*.json` のほかのキーです。判定 1 の表はリードのスクラッチの `rework/j2-judge.md`、判定 2 の表は `rework/j2b-judge.md` です。判定 1 は、`header.today` の 9 行と、GLOSSARY §5 の名詞「等倍」の 9 言語の語も見ました。
- **基準**（comment と GLOSSARY §5）: 意味は「ズームを戻す（リセットする）」。「もとの大きさ」「実際の大きさ」「合わせる（Fit）」の語を使わない。§2 の「元に戻す」「やり直す」と購入の復元の語を使わない。形は今の読み上げにそろえる（fr・es・pt-BR は不定詞と定冠詞、de は名詞と不定詞、it は命令形、zh は動詞と名詞、ko は名詞）。
- **この記録**: 2 人の判定と R の逆翻訳を、この節に写しました（枝 `r141-w-d2`）。訳の字は 1 つも替えていません。
- **母語の人の確認ではありません。**

**結果**

| 対象 | 行 | 判定 1 | 判定 2 | 直した後 |
| --- | --- | --- | --- | --- |
| `header.zoomReset.spoken`（8 言語の訳し直しと en） | 9 | ○ 9 | ○ 9 | — |
| `header.today`（comment だけ。訳は替えていない） | 9 | ○ 9 | （見ていない） | — |
| 参考: GLOSSARY §5 の名詞「等倍」の 9 言語の語（アプリのキーではない） | 9 | ○ 7・△ 2（de・pt-BR） | （見ていない） | 直さない（下の「`header.today` と参考の名詞」） |

**× は 0 です。** `header.zoomReset.spoken` は 2 人の 18 行とも ○ で、△ もありません。判定の後に替えた訳は無いので、この 9 行のために、もう一度の元を見ない逆翻訳と判定は要りません。読み上げの字が替わらなかったので、新機能の文の行 2 の動詞もこのままです（上の「△ と気づきの扱い」の 6）。

**全部の表（`header.zoomReset.spoken`、9 行）**

元の日本語は 9 行とも「等倍に戻す」です。注の列は、2 人の判定の理由をまとめたものです。

| 言語 | 訳 | 逆翻訳（元を見ない） | 判定 1 | 判定 2 | 注 |
| --- | --- | --- | --- | --- | --- |
| en | Reset Zoom | （無し。訳を替えていないので判定だけ） | ○ | ○ | 契約 §8.1 の案のまま。「reset」はどの大きさに戻すかを言わないので、日と週で押すと拡大になる場合も食い違わない（ブラウザーの Reset Zoom も、縮めた後なら拡大する）。Fit・Actual Size・original size は無い。Title Case は GLOSSARY §5 のとおり |
| zh-Hans | 重置缩放 | 拡大率をリセット | ○ | ○ | 缩放 はアプリの今の字（`onboarding.pen.text`・`settings.purchase.footer.readOnly`）。取り消しの 撤销・やり直しの 重做・購入の復元の 恢复购买 と別の語。前の訳 恢复原始大小 の「原始大小」と、購入の復元と同じ字の 恢复 が無くなった。動詞と名詞の形は 收起工具栏 と同じ |
| zh-Hant | 重置縮放 | 拡大率をリセット | ○ | ○ | 縮放 はアプリの今の字。取り消しの 還原（`toolbar.undo`）・重做・購入の 回復購買 と別。重置 は台湾・香港とも通じる「リセット」の語（判定 1 は、台湾の画面では 重設 も使われると注） |
| ko | 확대·축소 재설정 | 拡大・縮小をリセット | ○ | ○ | 확대·축소 は `onboarding.pen.text` と同じ字、재설정 は iOS の「リセット」の語。取り消しの 실행 취소・購入の 구입 복원・되돌리기 と別。名詞の形は 도구 막대 표시 と同じ。中黒「·」の読み上げは確かめていない（下の「確かめていないこと」） |
| fr | Réinitialiser le zoom | ズームをリセット | ○ | ○ | 取り消しの Annuler・やり直しの Rétablir・購入の Restaurer les achats と別。zoom は男性名詞で le が正しい。不定詞と定冠詞の形は Réduire la barre d’outils と同じ。記号が無いので U+00A0 の決まりは関わらない |
| de | Zoom zurücksetzen | ズームをリセット | ○ | ○ | Widerrufen・Wiederholen・Käufe wiederherstellen と別。名詞と不定詞の形は Werkzeugleiste ausblenden と同じ。前の訳 Auf Originalgröße zurücksetzen の Originalgröße は無い |
| es | Restablecer el zoom | ズームを元に戻す | ○ | ○ | 逆翻訳の「元に戻す」は restablecer（決まった状態にする＝リセット）を日本語に移したときの言い方で、取り消しの意味ではない。es の画面では取り消しは Deshacer という別の語なので、聞き違えは起きない。Restablecer はスペインでも中南米でも使う。Rehacer・Restaurar compras とも別。「もとの大きさ」の名詞は入っていない。不定詞と定冠詞の形は Ocultar la barra de herramientas と同じ |
| it | Reimposta lo zoom | ズームを設定し直す | ○ | ○ | 「設定し直す」は reimpostare の字面に寄った訳し戻しで、意味はリセット（「ズームを戻す」から外れていない）。購入の復元と同じ字になる Ripristina を避けた。Annulla・Ripeti とも別。zoom は z で始まる男性名詞で lo が正しい。命令形は Riduci la barra degli strumenti と同じ |
| pt-BR | Redefinir o zoom | ズームを設定し直す | ○ | ○ | 「設定し直す」は it と同じく redefinir の字面に寄った訳し戻し。Desfazer・Refazer・Restaurar compras と別。不定詞と定冠詞の形は Ocultar a barra de ferramentas と同じ。pt-PT の端末にもこの字が出る（GLOSSARY §1）が、Redefinir は pt-PT でも通じる |

**`header.today` と参考の名詞（判定 1 だけ）**

- `header.today`: 9 言語とも訳は替わっていません（Today・今天・今天・오늘・Auj.・Heute・Hoy・Oggi・Hoje）。comment の変更は置き場所（利き手の側の端）だけで語の意味に触れないので、9 行とも ○ です（契約 §16.9 の「訳し直さない」のとおり。jaSha1 574cd4fb79 は同じ）。fr の略した形 Auj. は comment どおりです（理由は 8 の表の F-16）。元を見ない逆翻訳は R の対象の外です。
- 参考の名詞（GLOSSARY §5 の「等倍（文の中の名詞）」の行）: en standard size・zh-Hans 标准大小・zh-Hant 標準大小・ko 표준 크기・fr taille standard・es tamaño estándar・it dimensione standard は ○。de Standardgröße は「既定の大きさ」とも読め、pt-BR tamanho padrão は pt-BR の画面ではまず「既定」と読まれるので △ です。GLOSSARY 自身が書いているとおり、名詞はできるだけ使わず、使う所では定義を添えれば足ります。今の新機能の文・審査メモ・`SUPPORT.en.md` に、この 9 つの語はありません（grep）。**直しません。**

**機械で照らしたこと**

- R に渡した 8 行（`rework/x2-for-R.txt`）は、`r141-w-x2` の `tools/l10n/translations/<言語>.json` の `header.zoomReset.spoken` の `text` と 8 行とも同じ字です。かなは 0 です。
- `r141-w-x2` の `docs/i18n/back/app-1_4_1-fix.md` の表の訳と逆翻訳は、`rework/x2-for-R.txt` と R の `rework/r2-back.txt` と 8 行とも同じ字です。上の全部の表の訳と逆翻訳も同じ字です。
- 9 言語の jaSha1 は 92b8cb8312 で同じです。en の `text` は「Reset Zoom」のままです。
- 新機能の文の行 2 の動詞は、今の読み上げと同じ動詞です（en resets the zoom、zh-Hans 重置缩放、zh-Hant 重置縮放、ko 확대·축소를 재설정、fr réinitialiser le zoom、de den Zoom … zurücksetzen、it reimpostare lo zoom、pt-BR redefinir o zoom、es-MX・es-ES restablecer el zoom。pt-PT だけ repor o zoom で、上の「△ と気づきの扱い」の 1）。
- 判定 2 は、8 つの訳が GLOSSARY §5 の「等倍に戻す」の行と 1 字ずつ同じこと、前の訳の語（原始大小・Originalgröße など）と「実際の大きさ」「合わせる」の語がどの言語にも無いこと、リセットの語（重置・재설정・Réinitialiser・zurücksetzen・Restablecer・Reimposta・Redefinir）がアプリのほかの文に無いこと（ほかのボタンの名前とぶつからない）を確かめました。判定 1 は、各言語の `toolbar.undo`・`toolbar.redo`・`settings.purchase.restore`・`paywall.restore` などの字と別の語であることを確かめました。

**確かめていないこと**

- **ko の中黒「·」**: VoiceOver の句読点の設定（既定は「一部」）で、この記号の名前を声に出すかは確かめていません。判定 1 は「句読点をすべて読む設定のときしか読まれない見込み（スラッシュより安全）」、判定 2 は「もし読むなら、空白にした「확대 축소 재설정」で避けられる」としました。字はアプリで今使っている 확대·축소 と同じで意味も正しいので、2 人とも × にしていません。**TestFlight で韓国語の VoiceOver を聞くときの確かめの項目にします。**
- **各言語の iOS の「リセット」の語**: 重置・재설정・Réinitialiser・zurücksetzen・Restablecer・Reimposta・Redefinir が iOS の「リセット」の語であることは判定の 2 人の知識で、出典は開いていません（判定 1 が【未確認】と書いた）。
- **「リセット」の響き**: どの言語でも少し「初めの状態に戻す」の響きがありますが、日と週では、開いたときの大きさで押すと拡大になります。en の Reset Zoom と同じ性質で、契約 §16.9 が「ズームを戻す」の形として採った所なので、判定は下げていません（判定 2）。
- 9 言語のどれも、その言語の VoiceOver でいちばんふつうに聞こえる名前かは、母語の人に確かめていません（GLOSSARY §5 の「確かめていないこと」と同じ）。

### 案 A の英語の 2 文（あとから。2026-11-22）

上の「元を見ない逆翻訳がまだの物」の 1 です。見出しの並び 案 A（契約 §0.4・§16.2。右手では ⚙ が左の端、日付は等倍のすぐ左）を本人が選んだときに使う英語の 2 文で、ファイルには入れず [PROPOSALS_1_4_1.md](../store/PROPOSALS_1_4_1.md) に置いてあります。確認ページで両方の案を見せるので（PROPOSALS §2.4・§3.2）、案 B の同じ所と同じく R と判定にかけました。

- **訳**: W の字です（PROPOSALS §2.1 の「1（en）」の案 A の列と、§3.2 の案 A の en）。元の日本語は、§2.1 の日本語の要約の 1 つ目の文の案 A と、§3.2 の案 A の ja です。
- **元を見ない逆翻訳**: R が、2 行の訳の字だけ（リードのスクラッチの `rework/a-for-R.txt`。各行は「所 TAB 訳の字」）を受け取って訳し戻しました（`rework/a-back.txt`）。日本語の元は渡していません。逆翻訳は `docs/i18n/back/store-1_4_1-fix.md` の最後の節に機械で写しました。
- **判定**: 訳を書いた Claude とも R とも別の Claude 2 人（相談していない）が、2 行の訳と逆翻訳を、元の日本語と契約 §0.4・§16.2 の案 A の並び（右手: 広い行 [⚙][☁][＋][印?][切り替え][題名][等倍][‹今日›]、狭い 1 段目 [⚙][☁][＋][題名][‹今日›]、2 段目 [切り替え][等倍]。題名の寄せは右手 `.trailing`。左手はすべて左右逆）と照らしました。判定 1 の表はリードのスクラッチの `rework/a-judge-1.md`、判定 2 の表は `rework/a-judge-2.md` です。
- **母語の人の確認ではありません。**

**結果**

| 対象 | 行 | 判定 1 | 判定 2 | 直した後 |
| --- | --- | --- | --- | --- |
| 審査メモ「What is new in 1.4.1」の 1、案 A（`review-1-A`） | 1 | ○ | ○ | — |
| `SUPPORT.en.md:162`（How do I use it with my left hand?）の 2 文目、案 A（`support-en-left-A`） | 1 | ○ | ○ | — |
| **計** | **2** | **○ 2・△ 0・× 0** | **○ 2・△ 0・× 0** | **判定の後に替えた字は 0** |

**× は 0 です。** 2 人とも、左右の取り違え、⚙ と日付の取り違え、狭い画面の等倍の場所の誤り、UI の名前（Settings・Dominant Hand・Left Hand・Reset Zoom・1×）の取り違えは無いとしました。判定の後に替えた字は無いので、この 2 行のために、もう一度の元を見ない逆翻訳と判定は要りません。案 A の行 1 の 11 組の訳（本人が案 A を選んだときだけ作る）は、上の「元を見ない逆翻訳がまだの物」の 2 のままです。

**全部の表（2 行）**

| 所 | 元の日本語 | 訳 | 逆翻訳（元を見ない） | 判定 1 | 判定 2 | 注 |
| --- | --- | --- | --- | --- | --- | --- |
| 審査メモの 1、案 A（PROPOSALS §2.1） | （意味の元）日本語の要約の 1 つ目の文の案 A「右上に「‹ 今日 ›」と等倍のボタン、すぐ左に日付（設定 › 利き手 › 左手 で逆）。」と、契約 §16.2 の狭い 2 段目 [切り替え][等倍] | 1. ‹ Today › and the 1× button (a magnifying glass with "1") are now at the right end of the header, with the date just before them (on narrow screens, 1× ends the second row). Settings > Dominant Hand > Left Hand reverses this order. | 1. ‹ 今日 › と 1× ボタン（「1」の入った虫めがね）がヘッダーの右端に移り、そのすぐ手前に日付が並ぶようになりました（幅の狭い画面では、1× は 2 行目の最後に来ます）。設定 > 利き手 > 左手 にすると、この並びが逆になります。 | ○ | ○ | 「右上に…と等倍のボタン」＝ at the right end of the header、「すぐ左に日付」＝ with the date just before them（左から右へ読む行で before は左。逆翻訳も「すぐ手前」で同じ向き）。広い行 [題名][等倍][‹今日›] で、日付は 2 つのボタンの組のすぐ左。狭い行は、括弧の「1× ends the second row」が 2 段目の最後の等倍を言う。左手は「reverses this order」で合い、before は並びの語なので逆にしても正しいまま。「now」も正しい（1.4 は ⚙ が右の端、日付は左寄り）。括弧の文と設定の道は案 B の 1 と同じ字 |
| `SUPPORT.en.md:162` の 2 文目、案 A（PROPOSALS §3.2） | 画面の上のボタンの並びが左右逆になり、「‹ 今日 ›」と等倍のボタンが左の端に、⚙（設定）が右の端に移ります。 | The order of the buttons at the top of the screen is reversed from left to right: “‹ Today ›” and the Reset Zoom button move to the left end, and ⚙ (Settings) to the right end. | 画面上部のボタンの並びが左右逆になります。「‹ 今日 ›」と「ズームをリセット」ボタンが左端に、⚙（設定）が右端に移ります。 | ○ | ○ | 案 B の字（上の全部の表で ○・○）から「the date」を「⚙ (Settings)」に替えただけで、日本語も「日付」→「⚙（設定）」だけ。§16.2 の案 A の左手（広い行 [‹今日›][等倍][題名]…[☁][⚙]、狭い 1 段目 [‹今日›][題名][＋][☁][⚙]）と合う。「Reset Zoom」は同じ FAQ の等倍の段落（`:158`）とアプリの読み上げと同じ名前。狭い画面で等倍が 2 段目の左にあることは `:158` が書いている（案 B と同じ組み立て） |

**気づき**（2 人とも判定の外。どれも直していません。足すかはリードが決める）

| # | 誰の | 中身 | 扱い |
| --- | --- | --- | --- |
| 1 | 判定 1・判定 2 | 案 A では ⚙ が右の端（1.0〜1.4）から左の端へ移るが、審査メモの 1 はそれを言っていない。日本語の要約の案 A も、新機能の文の行 1 案 A も言っていないので、訳の誤りではない | **直さない**（2 人とも「今のままでよい」「足さなくても困らない」とした。審査の人は「Settings > Dominant Hand」などから ⚙ を探せる）。足すときの字と数は下 |
| 2 | 判定 1・判定 2 | 「just before them」の向き: 逆翻訳は「すぐ手前」で、「左」の語は戻らなかった | **直さない**。並びの語なので、左手で「reverses this order」としても正しいまま残る（判定 2 は替えない方がよいとした）。向きをはっきりさせるなら「just to their left」（判定 1。3,996 バイトで入る。ただし左手では読み替えが要る、判定 2） |
| 3 | 判定 1 | 審査メモの「just」と、新機能の文の行 1 案 A の「その左」（「すぐ」無し）は食い違わない。審査メモの「them」は「‹ 今日 ›」と等倍の組で、日付はその組のすぐ左だから | 記録だけ |
| 4 | 判定 1・判定 2 | 案 A にしても、替えない文（`SUPPORT.en.md:158`・`SUPPORT.md:153` の等倍の段落、審査メモのほかの段）は正しいまま。⚙ を「右上」と書いた所は、SUPPORT の日英と審査メモに無い（grep） | 記録だけ。案 A で替える文は、PROPOSALS §2.1・§3.2 の 2 つと新機能の文の行 1 だけ |

**1 を足すときの字と数**（リードが足すと決めたとき。`wc -c`、今の案 A は 3,994）:

- 判定 1 の案: `1. ⚙ is now at the left end of the header; ‹ Today › and the 1× button (a magnifying glass with "1") are at the right end, with the date just before them (on narrow screens, 1× ends the second row). Settings > Dominant Hand > Left Hand reverses this order.` 英語だけ替えると 4,018 バイトで上限を超えるので、契約 §16.9 の決まりで 2 の「The next page of that type opens at the same size.」を外す（3,967）。日本語の要約の案 A も「左上に ⚙、右上に「‹ 今日 ›」と等倍のボタン、すぐ左に日付（設定 › 利き手 › 左手 で逆）。」にすると 4,034、外して 3,983。
- 判定 2 の案: 1 の最後に「 ⚙ is now at the left end.」を足すと 4,022、外して 3,971。
- どちらでも、英語の 1 の元を見ない逆翻訳と判定をやり直す。

**機械で照らしたこと**

- R に渡した 2 行（`rework/a-for-R.txt`）は、PROPOSALS §2.1・§3.2 の案 A の英語と 1 字も違いません（どちらもファイルに 1 回だけある）。かな・漢字は 0 です。
- 逆翻訳の 2 行（`rework/a-back.txt`）は、渡した 2 行と同じ順・同じ所です。上の全部の表と `docs/i18n/back/store-1_4_1-fix.md` の最後の節の訳と逆翻訳は、この 2 つのファイルと同じ字です。
- 審査メモを案 A にしたとき（英語の 1 と日本語の要約の 1 つ目の文を替える）は 3,994 バイトで、PROPOSALS §2.2 の数と同じです（上限 4,000）。上の「1 を足すときの字と数」と「just to their left」の 3,996 も、同じ組み立て方で数え直しました。

## 16. 1.4.1 の「動かす」（アプリの鍵 toolbar.move.title・審査メモの 3・SUPPORT の答え、2026-11-22）

元は契約の第 4 版 §17.3 です（[R1_4_1_CONTRACT.md](../R1_4_1_CONTRACT.md)。iPad のツールバーの「しまう」の左に「動かす」ボタンを足した直し 2）。替わった文は 3 つの所にあります。(1) アプリの新しい鍵 `toolbar.move.title`「動かす」（`tools/l10n/source/app-S.json`。10 pt のボタンの名前で、「しまう」の `toolbar.collapse.title` と同じ扱い）。(2) 審査メモの「What is new in 1.4.1」の 3（`docs/store/review-note.txt`。W、`r141-w-d3` の 78f81f9）。(3) `docs/SUPPORT.en.md` の「How do I move the toolbar?」（W、同じ 78f81f9。元は `docs/SUPPORT.md:161`・`:163`・`:166`）。審査メモの 3 の 3 文目（「On iPhone, even on iPhone Duo's inner screen, it stays at the bottom.」）と 4、SUPPORT.en のほかの文（1 文目の「On iPad, you can move the open toolbar …」、指を離すと吸い付く文、左右の端で縦に立つ文、紙に重ならない文、覚える端の点、細い窓の点）は替わっていないので、14 の判定が今も有効です。

- **訳**: X が書きました（`r141-w-x3`。GLOSSARY の行と理由は 49bdd06）。作る役が ca4a2e5 で入れた 9 言語の仮の訳を、GLOSSARY §4・§5 と照らして、そのまま決めました（だから `tools/l10n/translations/*.json` と `Localizable.xcstrings` は X の commit で変わっていない）。どの言語も、読み上げの「ツールバーを動かす」（`toolbar.grip.spoken`）から「ツールバー」を除いた動詞で、形は「しまう」の名前と同じです。例外は de だけで、Verschieben（59.6 pt）は 48 pt の面に入らず、Schieben（44.7 pt）も短くならないので、Bewegen にしました（投げなわの説明「Ziehen zum Bewegen」と同じ語）。審査メモと SUPPORT の英語は W の字です。
- **元を見ない逆翻訳**: R が、訳の字だけ（アプリの 9 言語の名前と、審査メモの英語の 3 文・SUPPORT.en の 6 文）を受け取って、日本語の元を見ずに訳し戻しました。R へ渡す段取りはリードの Workflow（wf_e907f63d-360）です。この節を書いた W は、その段取りを見ていません。結果はリードのスクラッチの `pk/review16_data.json` にあり、この節の表と `docs/i18n/back/<言語>.json` の `toolbar.move.title`（この節と一緒に足した）に機械で写しました（訳の字と逆翻訳の字は 1 字も変えていない）。
- **判定**: 判定の役が、18 行（アプリの 9 言語と英語の 9 文）を 1 行ずつ照らしました。14・15 と違い、判定は 1 人です。**18 行とも ○ で、△ と × は 0 でした。** en:2 にだけ、任意の案が 1 つあります（下の「判定の任意の案」）。下の表の注の列は、判定の理由（英語）を W が日本語にまとめたものです。
- **母語の人の確認ではありません。**

### 結果

| 対象 | 行 | 判定 | 直した後 |
| --- | --- | --- | --- |
| アプリの鍵 `toolbar.move.title`（9 言語） | 9 | ○ 9 | — |
| 審査メモの 3 の英語（替えた 3 文） | 3 | ○ 3 | — |
| `SUPPORT.en.md` の「How do I move the toolbar?」（替えた 6 文） | 6 | ○ 6 | — |
| **計** | **18** | **○ 18・△ 0・× 0** | **判定の後に替えた字は 0** |

**× は 0 です。** 契約 §17.3 の「`docs/i18n/REVIEW.md` の新しい節 16 の × を 0 に」は済みです。あとから足した下の「16.x §18.4 の 1 文」（`SUPPORT.en.md` の 1 文）も ○ で、× は 0 です（この表の 18 行には入れていない）。判定の後に替えた字は無いので、この 18 行のために、もう一度の元を見ない逆翻訳と判定は要りません。審査メモの日本語の要約の 3 つ目の文（「iPad はツールバーを「動かす」で上下左右へ（iPhone は下のまま）。」）は訳ではなく日本語の元なので、逆翻訳の対象の外です。

### 判定の任意の案

| # | 所 | 判定の案 | 扱い |
| --- | --- | --- | --- |
| 1 | en:2（審査メモの 3 の 2 文目「The small handle on the toolbar's inner edge also drags it.」） | バイトが許すなら（+4 バイト）「You can also drag the small handle on the toolbar's inner edge.」 | **入れていない**。審査メモは今 3,993 バイト（上限 4,000）で、入れると 3,997 バイト、並び 案 A の形では 3,999 バイトになり、残りが 1 バイトしかない（[PROPOSALS_1_4_1.md](../store/PROPOSALS_1_4_1.md) §2.2）。判定は今の字で ○（読み違えようがない）。入れると、この 1 文の元を見ない逆翻訳と判定のやり直しが要る |

### 全部の表（アプリの鍵 `toolbar.move.title`、9 行）

元の日本語は 9 行とも「動かす」です（jaSha1 b43eacf397）。幅は、作る役の速い道の run 45019147085 の `PaletteMoveButtonTests.testTheNameFitsTheFaceInEveryLanguage` のログの値で、確かめる上限は 47.5 pt です（ja の「動かす」は 28.1 pt）。38 pt を超える fr と de は、縮み（`labelMinScale` 0.8）の範囲で入ります（X の記録。GLOSSARY §4）。

| 言語 | 訳 | 逆翻訳（元を見ない） | 判定 | 10 pt の幅（pt。シミュレーター） | 注（判定の理由） |
| --- | --- | --- | --- | ---: | --- |
| en | Move | 移動 | ○ | 25.9 | 動かすの意味を保つ。4 つの操作の en（Move to Top・Move to Bottom・Move to Left・Move to Right）とそろう。10 pt で 48 pt の面に楽に入る |
| zh-Hans | 移动 | 移動 | ○ | 19.3 | 簡体字の画面でものを動かすときのふつうの動詞。4 つの操作（移到顶部 など）とそろう。2 字で楽に入る |
| zh-Hant | 移動 | 移動 | ○ | 18.7 | 繁体字の正しい形。4 つの操作（移到頂端・移到右側 など）とそろう。2 字で楽に入る |
| ko | 옮기기 | 移す | ○ | 26.0 | 「移す・動かす」の意味。ko の 4 つの操作（위로 옮기기・오른쪽으로 옮기기）と、しまうの 숨기기 の -기 の形とそろう。3 音節で、10 pt で約 30 pt に入る |
| fr | Déplacer | 移動 | ○ | 43.2（縮み約 0.88） | 要素を動かすときのふつうの動詞で、4 つの操作（Déplacer en haut・Déplacer à droite）とそろう。10 pt で約 40 pt で、縮みが 0.8 を下回らずに面に入る |
| de | Bewegen | 動かす | ○ | 44.0（縮み約 0.86） | 動かすの意味を持つ。判定の役は、Apple のドイツ語の画面でも使う語（たとえば「Bewegen nach」）とした（出典は開いていない）。10 pt で約 40 pt で入る。よく使う Verschieben は 48 pt の面に長すぎるので、Bewegen が正しい選び。W の注: 読み上げ（`toolbar.grip.spoken`）の Werkzeugleiste verschieben と動詞が違うのは de だけ（GLOSSARY §4・§5。しまうの Ablegen と ausblenden と同じ扱い） |
| es | Mover | 移動 | ○ | 29.8 | スペイン語の画面のふつうの動詞。4 つの操作（Mover arriba・Mover a la derecha）とそろい、短い |
| it | Sposta | 移動 | ○ | 33.4 | イタリア語の画面のふつうの命令形。4 つの操作（Sposta in alto・Sposta a destra）と、しまうの Riduci の形とそろい、短い |
| pt-BR | Mover | 移動 | ○ | 29.8 | pt-BR の画面のふつうの動詞。4 つの操作（Mover para cima・Mover para a direita）とそろい、短い |

### 全部の表（審査メモの英語と SUPPORT.en、9 行）

# の列は R と判定に渡した順です（en:1〜3 が審査メモの 3、en:4〜9 が SUPPORT.en）。文の番号は、下の 16.x の 1 文を足した後のファイルの数え方です（`SUPPORT.md:161`・`SUPPORT.en.md:166` は、その 1 文が 3 文目に入ったので、前の 3 文目が 4 文目、5 文目が 6 文目になった）。

| # | 所 | 元の日本語 | 訳 | 逆翻訳（元を見ない） | 判定 | 注（判定の理由） |
| --- | --- | --- | --- | --- | --- | --- |
| en:1 | `review-note.txt` の「What is new in 1.4.1」の 3 の 1 文目 | （意味の元）日本語の要約の 3 つ目の文「iPad はツールバーを「動かす」で上下左右へ（iPhone は下のまま）。」と、契約 §17.3（押して選ぶ・指で引く・Apple Pencil では引けない） | 3. On iPad, tap the toolbar's Move button to choose an edge, or drag it with a finger (not with Apple Pencil). | 3. iPad では、ツールバーの［移動］ボタンをタップして寄せる端を選ぶか、指でドラッグします（Apple Pencil ではドラッグできません）。 | ○ | §17.3 の 3 の中身（iPad で Move を押して端を選ぶか、指で引く。Apple Pencil では引けない）を保つ。UI の名前 Move は `toolbar.move.title` の en。「drag it」の it は Move ボタンを指し、正しい |
| en:2 | 3 の 2 文目 | （意味の元）契約 §17.3 の「小さなつまみの文」（ツールバーの内側の縁の小さなつまみでも動く） | The small handle on the toolbar's inner edge also drags it. | ツールバーの内側の端にある小さなつまみをドラッグしても動かせます。 | ○ | ツールバーの内側の縁の小さなつまみでもツールバーが動く、と言っている。「the handle … drags it」は少し詰めた言い方だが、読み違えようがない。審査メモの 4,000 バイトの狭い上限にも入る。任意の案が 1 つある（下の「判定の任意の案」） |
| en:3 | 3 の 4 文目（確かめ方） | （意味の元）契約 §17.3 の 3 の確かめ方（「動かす」を押して「右へ移す」を選ぶ。確かめ表の行 13 の手順の一部と同じ） | To check: on iPad, open a week page, tap Move and choose Move to Right. | 確かめ方：iPad で週のページを開き、［移動］をタップして［右へ移動］を選びます。 | ○ | 確かめの手順が合う（iPad で週のページを開き、Move を押して Move to Right を選ぶ）。2 つの UI の名前はアプリの en の字そのまま（`toolbar.move.title` = Move、`toolbar.moveTo.right` = Move to Right） |
| en:4 | `SUPPORT.en.md:166`（How do I move the toolbar?）の 2 文目 | `SUPPORT.md:161` の 2 文目: ツールバーの「しまう」の左にある「動かす」を押して、「上へ移す」などから移したい端を選んでください（左右の端に置いたときは、「動かす」は「しまう」の上にあります）。 | Tap “Move” to the left of “Hide” in the toolbar, and choose the edge you want, such as “Move to Top” (when the toolbar is at the left or right edge, “Move” is above “Hide”). | ツールバーの「隠す」の左にある「移動」をタップし、「上へ移動」など、移したい端を選びます（ツールバーが左端または右端にあるときは、「移動」は「隠す」の上にあります）。 | ○ | UI の名前が正しい（Hide は `toolbar.collapse.title`（しまう）の en、Move と Move to Top もアプリの字）。左右の端では Move が Hide の上にある、という括弧の意味も保つ |
| en:5 | `SUPPORT.en.md:166` の 4 文目 | `SUPPORT.md:161` の 4 文目: 「動かす」を指で引いて動かすこともできます。 | You can also drag “Move” with your finger. | 「移動」を指でドラッグして動かすこともできます。 | ○ | 元に忠実。UI の名前も正しい |
| en:6 | `SUPPORT.en.md:166` の 6 文目 | `SUPPORT.md:161` の 6 文目: ツールバーの、紙に近い側の縁にある小さなつまみを指で引いても、同じように動きます。 | Dragging the small handle on the edge of the toolbar nearer the paper with your finger moves it in the same way. | ツールバーの紙に近い側の端にある小さなつまみを指でドラッグしても、同じように動かせます。 | ○ | 「the edge of the toolbar nearer the paper」が「紙に近い側の縁」、「with your finger」が「指で」、「moves it in the same way」が「同じように動きます」を保つ。少し長いが明らか |
| en:7 | `SUPPORT.en.md:168`（1 つ目の点）の 1 文目 | `SUPPORT.md:163` の 1 文目: Apple Pencil では引けません（押して選ぶことはできます）。 | You cannot drag it with Apple Pencil (you can still tap and choose). | Apple Pencil ではドラッグできません（タップして選ぶことはできます）。 | ○ | 元に忠実（Apple Pencil では引けないが、押して選ぶことはできる）。iOS では「押す」に tap が合う |
| en:8 | `SUPPORT.en.md:168` の 2 文目 | `SUPPORT.md:163` の 2 文目: Apple Pencil で書いている間と、書き終えてから 0.5 秒の間は、手のひらが「動かす」やつまみに触れても、ツールバーは動き出しません。 | While you are writing with Apple Pencil, and for 0.5 seconds after, the toolbar does not start moving even if your palm touches “Move” or the handle. | Apple Pencil で書いている間と、書き終えてから 0.5 秒の間は、手のひらが「移動」やつまみに触れても、ツールバーは動き出しません。 | ○ | 手のひらの規則を保つ（Apple Pencil で書いている間と書き終えて 0.5 秒の間は、Move やつまみに触れても、ツールバーは動き出さない）。UI の名前も正しい |
| en:9 | `SUPPORT.en.md:171`（4 つ目の点） | `SUPPORT.md:166`: iPhone のツールバーは下のままです（「動かす」もつまみもありません）。 | On iPhone, the toolbar stays at the bottom (it has neither “Move” nor a handle). | iPhone では、ツールバーは画面の下に置かれたままです（「移動」もつまみもありません）。 | ○ | 元に忠実（iPhone ではツールバーは下のままで、Move もつまみも無い） |

### 機械で照らしたこと

- アプリの 9 言語の訳は、今の `tools/l10n/translations/<言語>.json` の `toolbar.move.title` の `text` と同じ字です。jaSha1 は 9 言語とも b43eacf397 です。
- `docs/i18n/back/<言語>.json` に `toolbar.move.title` を足しました（`text` は訳、`back` は R の逆翻訳。`about` にこの鍵の 1 文を足した）。これで 9 つの back のキーは、`translations/<言語>.json` のキーと同じ 496 になりました（足す前は `toolbar.move.title` だけが無かった）。
- 英語の 9 文は、ファイルに 1 回ずつあります（en:1〜3 は `review-note.txt` の 3、en:4〜9 は `SUPPORT.en.md` の「How do I move the toolbar?」）。9 文に、かな・漢字は 0 です。
- 英語の UI の名前は、アプリの en の字と同じです（Move = `toolbar.move.title`、Hide = `toolbar.collapse.title`、Move to Top = `toolbar.moveTo.top`、Move to Right = `toolbar.moveTo.right`）。
- 日本語の元（`SUPPORT.md` の 6 文と、審査メモの要約の 3 つ目の文）は、ファイルに 1 回ずつあります。
- 審査メモは 3,993 バイト（`wc -c`。最後の改行を除くと 3,992 バイト・3,639 字）で、上限 4,000 に入ります。並び 案 A と「The next page…」を外した形の 4 つの数は [PROPOSALS_1_4_1.md](../store/PROPOSALS_1_4_1.md) §2.2 です（3,993・3,995・3,942・3,944）。15 に書いた審査メモの数（3,992、案 A の 3,994、「1 を足すときの字と数」など）は第 3 版の 3 のときの数で、第 4 版の 3 では、どれも 1 バイト増えます（15 の字は記録として替えていない）。

### 確かめていないこと

- **母語の人の確認**: 9 言語のどれも、その言語の画面でいちばんふつうに読める名前かは、母語の人に確かめていません（GLOSSARY §5 の「確かめていないこと」と同じ）。
- **de の Bewegen が Apple の画面で使われること**: 判定の役の知識で、出典は開いていません。
- **fr と de の縮んだ字の見え方**: 幅の値はシミュレーターのログで確かめましたが、縮んだ字（約 0.88・0.86）が読みやすいかは、Localized の写真でリードが見る点です（X の記録）。
- **de の画面の名前と読み上げの名前**: W の気づき（判定の外）。de だけ、画面の名前（Bewegen）が読み上げの名前（Werkzeugleiste verschieben）に入っていません。音声コントロールで画面の字の名前を言ったときに押せるかは確かめていません。前からの「しまう」の Ablegen（読み上げは Werkzeugleiste ausblenden）と同じ形で、ほかの 8 言語と ja は、画面の名前が読み上げの名前に入っています。直しません。

### lint

この節の字と下の 16.x の 1 文を入れた後の枝 `r141-w-d4` で、`build.py --check`・`lint.py`（L-1〜L-14）・`baseline.py --check` は 3 つとも終了 0 です（`L-9: ok: 12 locales, the URLs on the English side`。審査メモの 3,993 バイトは L-9 の 4,000 バイトに入る）。L-12 の字の幅の目安の警告は 60 件で、14・15 の 58 件に `toolbar.move.title` の fr Déplacer（約 4.8 em）と de Bewegen（約 4.2 em。maxEm は 3.8）の 2 件が足されたものです。目安の警告で、本当の幅はテストが測ります（上の表の値。47.5 pt に入る）。de Radierer・pt-BR Borracha と同じ扱いです。凍結の 4 つの表（`DATA_1_1`・`TESTS_1_3`・`TESTS_1_2_3`・`FIXTURES_1_3`）は `shasum -a 256 -c` で全部 OK です。この枝で替えたのは `docs/` の下だけです。

### 16.x §18.4 の 1 文

元は契約の第 5 版 §18.4 です（しまったときにも「動かす」。§18.2 で、丸いボタンを押して出たツールバー（のぞき）にも「動かす」が出て、そこで端を選ぶと、その端にツールバーが開いたまま残る）。`SUPPORT.md` の「ツールバーを動かすには？」の答えに 1 文足し、`SUPPORT.en.md` の「How do I move the toolbar?」にも同じ所に英語の 1 文を足しました（W、枝 `r141-w-d4`）。

- **訳**: W が書きました（ceac036。書いた時の考えは表の下の「W の注」）。
- **元を見ない逆翻訳**: R が、英語の 1 文と、どこの文かの 1 行の説明（iPad・iPhone の手書きのカレンダーのアプリの、英語のサポートページの「How do I move the toolbar?」の文）だけを受け取って、日本語の元を見ずに訳し戻しました。R へ渡す段取りはリードの Workflow です。この 16.x を書いた W は、その段取りを見ていません。逆翻訳の字は、リードから受け取ったまま表に写しました（訳の字と逆翻訳の字は 1 字も変えていない）。
- **判定**: 判定の役が 1 人で照らしました（16 の 18 行と同じ）。**○ で、△ と × は 0 です。** 任意の案はありません。表の注の列は、判定の理由（英語）を W が日本語にまとめたものです。
- **判定の後に替えた字は 0 です**（`SUPPORT.en.md` と `SUPPORT.md` は ceac036 の字のまま）。だから、この 1 文のために、もう一度の元を見ない逆翻訳と判定は要りません。契約 §18.4 の「英語は元を見ない逆翻訳」は済みです。
- **母語の人の確認ではありません。**

| 所 | 元の日本語 | 訳 | 逆翻訳（元を見ない） | 判定 | 注（判定の理由） |
| --- | --- | --- | --- | --- | --- |
| `SUPPORT.en.md:166` の 3 文目（`SUPPORT.md:161` の 3 文目。「上へ移す」などを選ぶ文のすぐ後） | ツールバーをしまっているときは、丸いボタンを押して出たツールバーの「動かす」から選べます（選んだ端に、ツールバーが開いたまま残ります）。 | When the toolbar is hidden, tap the round button, then tap “Move” on the toolbar that appears and choose an edge (the toolbar stays open at the edge you choose). | ツールバーが隠れているときは、丸いボタンをタップし、表示されたツールバーの「移動」をタップして、置きたい端を選んでください（ツールバーは選んだ端で開いたままになります）。 | ○ | 元の意味を保つ。「hidden」は「しまっている」と、アプリの「しまう」の en（Hide）に合う。丸いボタン、出たツールバーの Move、端を選ぶ、の順を言い、選んだ端に開いたまま残るという括弧の点も保つ。元は「選べます」で、英語は「tap …, then tap …」の手順の形だが、ヘルプの文ではふつうで、意味は変わらない。「choose an edge」は 4 つの操作（Move to Top・Bottom・Left・Right）と元の「選んだ端」に合う。逆翻訳は Move を「移動」と書いたが、それは逆翻訳の役の字で、英語は UI の正しい名前 Move を使っている |

W の注（訳を書いた W は元を読んでいるので、この注は判定ではありません）:

- 日本語は契約 §18.4 の字そのままです。このページのほかの所は「丸ボタン」と書いていますが、契約の字の「丸いボタン」のままにしました。
- 英語の「the round button」は、`SUPPORT.en.md` の「How do I hide the toolbar?」と「How do I use it with my left hand?」の呼び方です。「押して」は、このページのほかの所と同じく tap にしました。「Move」はアプリの en の字（`toolbar.move.title`）です。
- 丸ボタンの ↶ は「元に戻す」で、ツールバーを出すのは丸ボタンの道具の印です（「ツールバーをしまうには？」の字）。契約の字は「丸いボタンを押して」なので、英語も「tap the round button」のままにしました（道具の印とは書いていない）。
- 「「動かす」から選べます」は、前の文（Tap “Move” …, and choose the edge you want）と同じく、Move を押して端を選ぶ手順として書きました（tap “Move” … and choose an edge）。
- 判定で見てほしい点: この 1 文のすぐ後に「「動かす」を指で引いて動かすこともできます。」（You can also drag “Move” with your finger.）が続きます。丸いボタンから出したツールバー（のぞき）の「動かす」は押すだけで、引いても動きません（契約 §18.2）。続けて読むと、のぞきでも引けると読めるかを見てください。

確かめていないこと（16.x）:

- **W の注の最後の点（次の文と続けて読むこと）**: 判定の理由は、この点に触れていません（判定の役に次の文が渡ったかを、W は見ていない）。だから、この点は判定で確かめていません。W の見方（判定ではない）: 日本語の元も同じ並びです（`SUPPORT.md` でも、§18.4 の文のすぐ後に「「動かす」を指で引いて動かすこともできます。」）。読み違えの余地があるなら日本語と英語で同じで、訳の字ではなく元の文の並びの点です。字も並びも替えていません。替えるなら日本語と英語の両方で、リードが決める点です。
- **母語の人の確認**: 英語の 1 文がいちばんふつうに読めるかは、母語の人に確かめていません。

この 16.x を埋めた後の枝 `r141-w-d4` でも、`build.py --check`・`lint.py`・`baseline.py --check` は 3 つとも終了 0 です（L-12 の目安の警告は 60 件のまま）。凍結の 4 つの表は `shasum -a 256 -c` で全部 OK です。この段で替えたのは `docs/i18n/REVIEW.md` だけです。
