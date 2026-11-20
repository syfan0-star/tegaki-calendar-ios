# ストア 1.4 の逆翻訳（新機能の文の行・審査メモの 1.4 の段・SUPPORT の Duo の文）

R が日本語の元を見ずに訳し戻した表です。1.4 の新機能の文は行ごとに作ったので（[M7D_CONTRACT.md](../../M7D_CONTRACT.md) §8.1）、1.3 までのロケールごとのファイル（`store-<ロケール>.md`）に節を足さず、このファイルにまとめました。照合と判定は、訳を書いた Claude（X・N）とも R とも別の Claude（J）がしました（`REVIEW.md` の 4 の「1.4 の店の文」）。母語の人の確認ではありません。

- R に渡したもの: [docs/store/PROPOSALS_1_4.md](../../store/PROPOSALS_1_4.md) §1.1〜§1.5 の「訳」の欄（11 組 × 5 行。10c504a）と、N の英語の文（`docs/store/review-note.txt` の「What is new in 1.4」の段、`PROPOSALS_1_4.md` §3 の案 B・確かめ方の任意の案・(3) の替え文、`docs/SUPPORT.en.md` の Duo の文と §3.3 の Apple Pencil の文。e123b4c）。
- 渡していないもの: 日本語の元（契約 §8.1・§8.3・§8.4、審査メモの日本語の要約、`docs/SUPPORT.md`）、`PROPOSALS_1_4.md` §1.0 の訳の決まり、行の条件。訳についての 1 行は 1.3 と同じ字（`REVIEW.md` の 4 で ○）なので渡していません。
- en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写しです（`locales.json` の `copyOf`）。R の注は R が書いたままです。

## 1 回目（2026-11-20）

R の全体の注（R が書いたまま）:

- 行 2 の「（iOS 27.2 以降）」は、どの言語でも 1 文目の後ろに付いています。1 文目全体（Pencil で書く・指で紙を動かす）にかかると読めますが、2 文目の切り替えにもかかるかは文からは分かりません。
- 行 1 案 A は、どの言語でも「大きな画面いっぱい」とだけ言っています。閉じたとき（外側の画面）にどう出るかは書いていません。

### 新機能の文（行ごと）

id は `1.4.<行>.<ロケール>` で、行は L1A（行 1 案 A）・L1B（行 1 案 B）・L2〜L4（行 2〜行 4）です。判定が × の行（L1A の es-ES・es-MX・fr-FR・it・pt-BR・pt-PT）は、ここにあるのが前の字です（J が直した字と、その元を見ない逆翻訳は下の「2 回目」）。

#### en-US（en-GB・en-AU・en-CA も）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.en-US | • The app now fills the large screen of iPhone Duo. Whether you open it or close it, you can just keep writing. | ・アプリが iPhone Duo の大きな画面いっぱいに表示されるようになりました。それを開いても閉じても、そのまま書き続けられます。 | 「it」は iPhone Duo と読むのが自然です。ただ、直前の名詞は「large screen」で、主語は「The app」なので、アプリと読める余地も少しあります。「just keep writing」は「ただ書き続ければよい」とも読めます |
| 1.4.L1B.en-US | • The app now adjusts its layout to the large screen of iPhone Duo. | ・アプリが iPhone Duo の大きな画面に合わせてレイアウトを調整するようになりました。 | なし |
| 1.4.L2.en-US | • On iPhone Duo, as on iPad, you write with Apple Pencil and move the paper with your finger (iOS 27.2 or later). To also write with your finger, turn on “Draw with Finger” in the toolbar. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「Draw with Finger（指で描く）」をオンにしてください。 | 本文は「write（書く）」、切り替えの名前は「Draw（描く）」で、動詞が違います |
| 1.4.L3.en-US | • The app has moved to the new development environment for iOS 27. How you use it on iPad and other iPhone models stays the same. | ・アプリは iOS 27 向けの新しい開発環境に移行しました。iPad やほかの iPhone の機種での使い方は変わりません。 | 「other iPhone models」は Duo 以外の iPhone と読めます |
| 1.4.L4.en-US | • Holidays in China for 2027 have been updated to match the announced days off. | ・中国の 2027 年の祝日を、発表された休みの日に合わせて更新しました。 | 誰が発表したかは書いていません。「days off」は振替を含む休みの取り決めとも読めます |

#### de-DE

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.de-DE | • Die App füllt jetzt den großen Bildschirm des iPhone Duo aus. Ob Sie es öffnen oder schließen, Sie können einfach weiterschreiben. | ・アプリは今、iPhone Duo の大きな画面いっぱいに表示されます。それを開いても閉じても、そのまま書き続けられます。 | 「es」は中性なので、iPhone（das iPhone）を指します。アプリ（die App）ではありません。敬称 Sie で書かれています |
| 1.4.L1B.de-DE | • Die Darstellung passt sich jetzt an den großen Bildschirm des iPhone Duo an. | ・表示が iPhone Duo の大きな画面に合わせて調整されるようになりました。 | 主語は「Darstellung」＝表示・見え方。「アプリ」という語はありません |
| 1.4.L2.de-DE | • Auf dem iPhone Duo schreiben Sie wie auf dem iPad mit dem Apple Pencil und bewegen das Papier mit dem Finger (ab iOS 27.2). Um auch mit dem Finger zu schreiben, aktivieren Sie „Mit Finger zeichnen“ in der Werkzeugleiste. | ・iPhone Duo では iPad と同じように Apple Pencil で書き、指で紙を動かします（iOS 27.2 から）。指でも書くには、ツールバーの「指で描く」をオンにしてください。 | 切り替えの名前は「zeichnen」＝描く。本文は「schreiben」＝書く |
| 1.4.L3.de-DE | • Die App wurde auf die neue Entwicklungsumgebung für iOS 27 umgestellt. Die Bedienung auf dem iPad und auf anderen iPhone-Modellen ändert sich nicht. | ・アプリは iOS 27 向けの新しい開発環境に切り替えられました。iPad とほかの iPhone の機種での操作は変わりません。 | 受け身の過去形です |
| 1.4.L4.de-DE | • Die Feiertage in China für 2027 wurden an die bekannt gegebenen freien Tage angepasst. | ・2027 年の中国の祝日は、発表された休みの日に合わせて調整されました。 | 受け身 |

#### es-ES

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.es-ES | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin interrupciones. | ・今ではアプリが iPhone Duo の大きな画面全体を使います。それを開いても閉じても、途切れることなく書き続けられます。 | 「lo」は男性形なので iPhone Duo を指します。敬称 usted。「sin interrupciones」＝中断なく、が入っています |
| 1.4.L1B.es-ES | • Ahora la visualización se adapta a la pantalla grande del iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。 | なし |
| 1.4.L2.es-ES | • En el iPhone Duo, igual que en el iPad, escribe con el Apple Pencil y mueve el papel con el dedo (iOS 27.2 o posterior). Para escribir también con el dedo, active “Dibujar con el dedo” en la barra de herramientas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で描く」をオンにしてください。 | 「escribe／mueve」は主語のない 3 人称単数で、usted の現在形と読めます。形の上では tú の命令形とも同じです。切り替えの名前は「Dibujar」＝描く |
| 1.4.L3.es-ES | • La app ha pasado al nuevo entorno de desarrollo de iOS 27. La forma de usarla en el iPad y en otros modelos de iPhone no cambia. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad やほかの iPhone の機種での使い方は変わりません。 | 「de iOS 27」は「iOS 27 の」で、「向け」とまでは言っていません。現在完了です |
| 1.4.L4.es-ES | • Los días festivos de China en 2027 se han ajustado a los días de descanso anunciados. | ・2027 年の中国の祝日を、発表された休みの日に合わせて調整しました。 | 現在完了 |

#### es-MX

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.es-MX | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin interrupciones. | ・今ではアプリが iPhone Duo の大きな画面全体を使います。それを開いても閉じても、途切れることなく書き続けられます。 | es-ES と同じ文です |
| 1.4.L1B.es-MX | • Ahora la visualización se adapta a la pantalla grande del iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。 | es-ES と同じ |
| 1.4.L2.es-MX | • En el iPhone Duo, igual que en el iPad, escribe con el Apple Pencil y mueve el papel con el dedo (iOS 27.2 o posterior). Para escribir también con el dedo, active “Dibujar con el dedo” en la barra de herramientas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で描く」をオンにしてください。 | es-ES と同じ |
| 1.4.L3.es-MX | • La app pasó al nuevo entorno de desarrollo de iOS 27. La forma de usarla en el iPad y en otros modelos de iPhone no cambia. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad やほかの iPhone の機種での使い方は変わりません。 | 単純過去です。es-ES の現在完了との差は、日本語では出ません |
| 1.4.L4.es-MX | • Los días festivos de China en 2027 se ajustaron a los días de descanso anunciados. | ・2027 年の中国の祝日を、発表された休みの日に合わせて調整しました。 | 単純過去。日本語では es-ES と同じになります |

#### fr-FR（fr-CA も）

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.fr-FR | • L’app occupe désormais tout le grand écran de l’iPhone Duo. Que vous l’ouvriez ou le fermiez, vous pouvez continuer à écrire sans interruption. | ・これからは、アプリが iPhone Duo の大きな画面全体を使います。それを開いても閉じても、中断せずに書き続けられます。 | 「le fermiez」が男性形なので、iPhone Duo を指します。「désormais」＝これからは |
| 1.4.L1B.fr-FR | • L’affichage s’adapte désormais au grand écran de l’iPhone Duo. | ・これからは、表示が iPhone Duo の大きな画面に合わせて調整されます。 | なし |
| 1.4.L2.fr-FR | • Sur l’iPhone Duo, comme sur l’iPad, vous écrivez avec l’Apple Pencil et déplacez le papier avec le doigt (iOS 27.2 ou version ultérieure). Pour écrire aussi avec le doigt, activez « Écrire au doigt » dans la barre d’outils. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で書く」をオンにしてください。 | 切り替えの名前も「Écrire」＝書く、で本文と同じ動詞です |
| 1.4.L3.fr-FR | • L’app est passée au nouvel environnement de développement d’iOS 27. Son utilisation sur l’iPad et sur les autres modèles d’iPhone ne change pas. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。 | なし |
| 1.4.L4.fr-FR | • Les jours fériés de 2027 en Chine ont été alignés sur les congés annoncés. | ・中国の 2027 年の祝日を、発表された休み（休暇）にそろえました。 | 受け身。「congés」＝休暇・休み |

#### it

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.it | • Ora l’app occupa tutto il grande schermo di iPhone Duo. Che lo apra o lo chiuda, può continuare a scrivere senza interruzioni. | ・今ではアプリが iPhone Duo の大きな画面全体を使います。それを開いても閉じても、中断なく書き続けられます。 | 「lo」は男性形なので iPhone Duo を指します。敬称 Lei の 3 人称の形です |
| 1.4.L1B.it | • Ora la visualizzazione si adatta al grande schermo di iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。 | なし |
| 1.4.L2.it | • Su iPhone Duo, come su iPad, scrive con Apple Pencil e sposta la carta con il dito (iOS 27.2 o versioni successive). Per scrivere anche con il dito, attivi “Scrivi con il dito” nella barra degli strumenti. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で書く」をオンにしてください。 | 「scrive／sposta」は主語のない 3 人称で、Lei と読めます。前後がなければ「アプリが書く」とも読めます。切り替えの名前「Scrivi con il dito」は親称 tu の命令形で、本文の Lei とそろっていません |
| 1.4.L3.it | • L’app è passata al nuovo ambiente di sviluppo di iOS 27. L’uso su iPad e sugli altri modelli di iPhone non cambia. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。 | なし |
| 1.4.L4.it | • Le festività della Cina per il 2027 sono state allineate ai giorni di riposo annunciati. | ・中国の 2027 年の祝日は、発表された休みの日にそろえられました。 | 受け身 |

#### ko

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.ko | • 이제 iPhone Duo의 큰 화면을 가득 채워 표시해요. 펼쳐도 접어도 그대로 계속 쓸 수 있어요. | ・これからは iPhone Duo の大きな画面いっぱいに表示します。開いても閉じても、そのまま書き続けられます。 | 主語がありません。「쓰다」は「書く」とも「使う」とも読めるので、「使い続けられる」と取る余地があります。「펼치다／접다」＝広げる・折りたたむ |
| 1.4.L1B.ko | • iPhone Duo의 큰 화면에 맞춰 표시하도록 했어요. | ・iPhone Duo の大きな画面に合わせて表示するようにしました。 | 主語なし。過去形の「〜するようにしました」 |
| 1.4.L2.ko | • iPhone Duo에서는 iPad와 마찬가지로 Apple Pencil로 쓰고, 손가락으로 종이를 움직여요(iOS 27.2 이상). 손가락으로도 쓰고 싶다면 도구 막대의 ‘손가락으로 쓰기’를 켜 주세요. | ・iPhone Duo では iPad と同じように Apple Pencil で書き、指で紙を動かします（iOS 27.2 以上）。指でも書きたいなら、ツールバーの「指で書く」をオンにしてください。 | 切り替えの名前も「書く」で、本文と同じです |
| 1.4.L3.ko | • iOS 27의 새로운 개발 환경으로 옮겼어요. iPad에서도, 다른 iPhone 모델에서도 사용법은 바뀌지 않아요. | ・iOS 27 の新しい開発環境に移しました。iPad でも、ほかの iPhone の機種でも、使い方は変わりません。 | 何を移したか（アプリ）は書いていません |
| 1.4.L4.ko | • 중국의 2027년 공휴일을 발표된 휴무 일정에 맞췄어요. | ・中国の 2027 年の祝日を、発表された休み（休業）の日程に合わせました。 | なし |

#### pt-BR

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.pt-BR | • Agora o app ocupa toda a tela grande do iPhone Duo. Ao abrir ou fechar o dispositivo, você pode continuar escrevendo sem interrupção. | ・今ではアプリが iPhone Duo の大きな画面全体を使います。デバイスを開いたり閉じたりするときも、中断なく書き続けられます。 | 「o dispositivo」＝デバイス、と明示しています |
| 1.4.L1B.pt-BR | • Agora a exibição se adapta à tela grande do iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。 | なし |
| 1.4.L2.pt-BR | • No iPhone Duo, assim como no iPad, você escreve com o Apple Pencil e move o papel com o dedo (iOS 27.2 ou posterior). Para escrever também com o dedo, ative “Traçar com o dedo” na barra de ferramentas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指でなぞる（線を引く）」をオンにしてください。 | 切り替えの名前「Traçar」は「線を引く・なぞる」で、本文の「escrever」＝書く、と語が違います |
| 1.4.L3.pt-BR | • O app passou para o novo ambiente de desenvolvimento do iOS 27. O uso no iPad e em outros modelos de iPhone não muda. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。 | なし |
| 1.4.L4.pt-BR | • Os feriados da China em 2027 foram ajustados de acordo com os dias de folga anunciados. | ・2027 年の中国の祝日は、発表された休みの日に合わせて調整されました。 | 受け身。「dias de folga」＝休みの日 |

#### pt-PT

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.pt-PT | • A aplicação passa a ocupar todo o ecrã grande do iPhone Duo. Ao abrir ou fechar o dispositivo, pode continuar a escrever sem interrupção. | ・アプリは iPhone Duo の大きな画面全体を使うようになります。デバイスを開いたり閉じたりするときも、中断なく書き続けられます。 | 「passa a」＝〜するようになる、の現在形です |
| 1.4.L1B.pt-PT | • A apresentação passa a adaptar-se ao ecrã grande do iPhone Duo. | ・表示が iPhone Duo の大きな画面に合わせて調整されるようになります。 | 「passa a」の現在形 |
| 1.4.L2.pt-PT | • No iPhone Duo, tal como no iPad, escreve com o Apple Pencil e desloca o papel com o dedo (iOS 27.2 ou posterior). Para escrever também com o dedo, ative “Traçar com o dedo” na barra de ferramentas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指でなぞる（線を引く）」をオンにしてください。 | 「escreve／desloca」は主語のない 3 人称です。切り替えの名前「Traçar」と本文の「書く」は語が違います。pt-BR と同じです |
| 1.4.L3.pt-PT | • A aplicação passou para o novo ambiente de desenvolvimento do iOS 27. A utilização no iPad e noutros modelos de iPhone não muda. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。 | なし |
| 1.4.L4.pt-PT | • Os feriados da China em 2027 foram ajustados de acordo com os dias de descanso anunciados. | ・2027 年の中国の祝日は、発表された休息日に合わせて調整されました。 | 受け身。「dias de descanso」＝休息日。pt-BR の「folga」と語が違いますが、意味は同じです |

#### zh-Hans

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.zh-Hans | • 现在会在 iPhone Duo 的大屏幕上全屏显示。无论展开还是合上，都可以直接继续书写。 | ・今後は iPhone Duo の大きな画面で全画面表示されます。広げても閉じても、そのまま書き続けられます。 | 主語なし。「展开／合上」＝広げる・閉じる |
| 1.4.L1B.zh-Hans | • 现在会根据 iPhone Duo 的大屏幕调整显示。 | ・今後は iPhone Duo の大きな画面に応じて表示を調整します。 | 主語なし |
| 1.4.L2.zh-Hans | • 在 iPhone Duo 上，和 iPad 一样，用 Apple Pencil 书写，用手指移动纸张（iOS 27.2 或更高版本）。如果也想用手指书写，请打开工具栏中的“用手指书写”。 | ・iPhone Duo では、iPad と同じく、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書きたい場合は、ツールバーの「指で書く」をオンにしてください。 | 切り替えの名前も「書く」 |
| 1.4.L3.zh-Hans | • 已迁移到 iOS 27 的新开发环境。在 iPad 和其他 iPhone 机型上的使用方法不变。 | ・iOS 27 の新しい開発環境へ移行済みです。iPad やほかの iPhone の機種での使い方は変わりません。 | 主語なし |
| 1.4.L4.zh-Hans | • 已按公布的放假安排调整中国 2027 年的节假日。 | ・公表された休みの取り決め（休暇の日程）に従って、中国の 2027 年の祝日を調整しました。 | 「放假安排」は、政府が出す振替を含む休みの日程と読めます |

#### zh-Hant

| id | 訳（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.zh-Hant | • 現在會在 iPhone Duo 的大螢幕上全螢幕顯示。無論展開還是闔上，都可以直接繼續書寫。 | ・今後は iPhone Duo の大きな画面で全画面表示されます。広げても閉じても、そのまま書き続けられます。 | zh-Hans と同じ意味です |
| 1.4.L1B.zh-Hant | • 現在會配合 iPhone Duo 的大螢幕調整顯示。 | ・今後は iPhone Duo の大きな画面に合わせて表示を調整します。 | 「配合」＝合わせる。zh-Hans は「根据」＝応じて |
| 1.4.L2.zh-Hant | • 在 iPhone Duo 上，和 iPad 一樣，用 Apple Pencil 書寫，用手指移動紙張（iOS 27.2 或以上版本）。如果也想用手指書寫，請開啟工具列中的「用手指書寫」。 | ・iPhone Duo では、iPad と同じく、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以上のバージョン）。指でも書きたい場合は、ツールバーの「指で書く」をオンにしてください。 | なし |
| 1.4.L3.zh-Hant | • 已遷移至 iOS 27 的新開發環境。在 iPad 和其他 iPhone 機型上的使用方式不變。 | ・iOS 27 の新しい開発環境へ移行済みです。iPad やほかの iPhone の機種での使い方は変わりません。 | 主語なし |
| 1.4.L4.zh-Hant | • 已依公布的放假安排調整中國 2027 年的假日。 | ・公表された休みの取り決めに従って、中国の 2027 年の休日を調整しました。 | 「假日」＝休日。zh-Hans の「节假日」（祝日と休日）より範囲の広い語です |

### 審査メモ（`docs/store/review-note.txt` の「What is new in 1.4」と、条件で替わる文）

審査メモの英語の段のうち、1.4 で替えた「What is new in 1.4」の段（見出しと 1〜4）と、`PROPOSALS_1_4.md` §3 の条件で替わる英語の文だけです。ほかの段は 1.3 の字のまま（`store-review-note.md` の「1.3」と「1.3 の直し」）。日本語の要約は R に渡していません。

| id | 所 | 字（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- | --- |
| 1.4.note.heading | 審査メモ 見出し | What is new in 1.4 | 1.4 の新しい点 | なし |
| 1.4.note.1 | 審査メモ (1) | 1. Built with Xcode 27.2 (iOS 27.2 SDK). The minimum iOS version stays 17.0. | 1. Xcode 27.2（iOS 27.2 SDK）でビルドしました。対応する最小の iOS のバージョンは 17.0 のままです。 | 主語なし |
| 1.4.note.2A | 審査メモ (2) 案 A（今のファイル） | 2. The layout now follows the window size, not the device type. On iPhone Duo the app fills the screen, inner or outer, and adjusts when the device is opened or closed (the page and handwriting stay the same). To check: open a week page, then open and close the device. | 2. レイアウトは、機種の種類ではなく、ウインドウの大きさに従うようになりました。iPhone Duo では、内側でも外側でも、アプリが画面いっぱいに表示され、デバイスを開いたり閉じたりすると調整されます（ページと手書きはそのまま変わりません）。確かめ方: 週のページを開き、それからデバイスを開いて閉じてください。 | 何が調整されるか（レイアウト）は書いていません。「the page … stay the same」は「表示中のページが別のページに移らない」とも「ページの中身が変わらない」とも読めます |
| 1.4.note.3 | 審査メモ (3) | 3. On iPhone Duo, as on iPad, Apple Pencil (USB-C, iOS 27.2 or later) writes and a finger moves the paper. The app turns Draw with Finger off when that iPhone first sees an Apple Pencil touch or a screen hinge (UIHingeInteraction); on a device updated from 1.3, only an Apple Pencil touch does this. The model name and the window size are not used for this. Finger drawing can be turned back on with the toolbar switch. | 3. iPhone Duo では、iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）が書き、指が紙を動かします。その iPhone が初めて Apple Pencil のタッチ、または画面のヒンジ（UIHingeInteraction）を検知したとき、アプリは Draw with Finger（指で描く）をオフにします。1.3 からアップデートしたデバイスでは、これを行うのは Apple Pencil のタッチだけです。このために機種名やウインドウの大きさは使いません。指で描くことは、ツールバーのスイッチで再びオンにできます。 | 「USB-C」は Pencil の型の名前とも端子とも読めます。「iOS 27.2 以降」は Pencil の条件とも、この動き全体の条件とも読めます。「first sees」＝初めて検知したとき、で一度だけの動きと読めます。Draw with Finger に引用符はありません。「1.3 から…」の文は「1.3 から上げた機器では、ヒンジではオフにならない」という意味になります |
| 1.4.note.4 | 審査メモ (4) | 4. No new on-screen text. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating (4+; both new questions, Shared Location and Dating and Relationships, answered No). | 4. 画面上の新しい文言はありません。変わらないもの: データ（App のプライバシーは「データの収集なし」のまま）、手書きの保存、購入、年齢区分（4+。新しい 2 つの質問、位置情報の共有と出会い・交際は、どちらも「いいえ」と回答）。 | 「Shared Location and Dating and Relationships」は「and」が重なっていて、質問の区切りが読み取りにくいです。前の「both new questions」から 2 つと分かります |
| 1.4.note.2B | 審査メモ (2) 案 B（§3.2） | 2. The layout now follows the window size, not the device type. On iPhone Duo the app fills the screen, inner or outer, and fits its width (the page and handwriting stay the same). To check: open a week page, then open and close the device. | 2. レイアウトは、機種の種類ではなく、ウインドウの大きさに従うようになりました。iPhone Duo では、内側でも外側でも、アプリが画面いっぱいに表示され、その幅に合わせます（ページと手書きはそのまま変わりません）。確かめ方: 週のページを開き、それからデバイスを開いて閉じてください。 | 「its width」は画面の幅とも、アプリの幅とも読めます。画面の幅と読むのが自然です。「いっぱいに表示」と「幅に合わせる」は少し重なっています。確かめ方では今も開閉を求めています |
| 1.4.note.check-alt | 審査メモ 確かめ方の任意の案（§3.2） | To check: open a week page on the inner screen and on the outer screen. | 確かめ方: 内側の画面と外側の画面で、週のページを開いてください。 | 開く・閉じるという操作は言っていません |
| 1.4.note.3-alt | 審査メモ (3) の 2 つ目の文の替え文（§3.4） | The app turns Draw with Finger off when that iPhone first sees an Apple Pencil touch. | その iPhone が初めて Apple Pencil のタッチを検知したとき、アプリは Draw with Finger（指で描く）をオフにします。 | 「that iPhone」は前の文の iPhone Duo を指します。この文だけでは何を指すか分かりません |

### SUPPORT.en.md の Duo の文と Apple Pencil の文

`docs/SUPPORT.en.md` の「Can I use it on iPhone or Mac?」の節に足す文です（案 A は今のファイル、案 B と Apple Pencil の文は `PROPOSALS_1_4.md` §3）。節のほかの文は 1.2 の逆翻訳のまま（`legal-en.md`）。

| id | 所 | 字（R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- | --- |
| 1.4.support.duoA | SUPPORT.en の Duo の文 案 A（今のファイル） | On iPhone Duo, the App fills the large screen when the device is open, and fits the outer screen when it is closed (from version 1.4). | iPhone Duo では、デバイスを開いているときは、本アプリは大きな画面いっぱいに表示されます。閉じているときは外側の画面に合わせます（バージョン 1.4 から）。 | 大文字の「the App」は規約で決めた語「本アプリ」と読めます。「it」は device を指します |
| 1.4.support.duoB | SUPPORT.en の Duo の文 案 B（§3.2） | On iPhone Duo, the App fits the width of the screen (from version 1.4). | iPhone Duo では、本アプリは画面の幅に合わせます（バージョン 1.4 から）。 | 内側・外側のどちらの画面かは言っていません |
| 1.4.support.pencil | SUPPORT.en の Apple Pencil の文（§3.3。まだ入れていない） | On iPhone Duo, as on iPad, you write with Apple Pencil (USB-C, iOS 27.2 or later) and move the paper with your finger. If you also want to write with your finger, turn on “Draw with Finger” in the toolbar. | iPhone Duo では、iPad と同じように、Apple Pencil（USB-C、iOS 27.2 以降）で書き、指で紙を動かします。指でも書きたい場合は、ツールバーの「Draw with Finger（指で描く）」をオンにしてください。 | 本文は「write（書く）」、切り替えの名前は「Draw（描く）」です。「USB-C」「iOS 27.2 以降」がどこにかかるかは、審査メモ (3) と同じく 2 通りに読めます |

## 2 回目（2026-11-20。行 1 案 A の直した 6 つの字だけ）

1 回目の判定で × にした 6 つ（`REVIEW.md` の 4 の「1.4 の店の文」）を J が直した字です。2 回目の R には、この字（id と訳だけ）を渡しました。前の字・1 回目の逆翻訳・日本語の元・ほかの行は渡していません。fr-CA は fr-FR と同じ字です。判定は J で、6 つとも ○ でした（`REVIEW.md` の同じ節の「2 回目」）。× は残っていないので、3 回目はありません。R の注は R が書いたままです。

| id | 訳（2 回目に R が読んだ字） | 逆翻訳 | R の注 |
| --- | --- | --- | --- |
| 1.4.L1A.es-ES | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin más. | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。開いても閉じても、そのまま書き続けられます。 | 「Ahora」は「今では・これで」の意味で、前より変わったことを表す。「lo」は男性名詞の iPhone Duo を指し、開け閉めするのは端末と読める。「sin más」は「特に何もせず、そのまま」。丁寧語の usted。閉じたときにどの画面で書くのかは書かれていない |
| 1.4.L1A.es-MX | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin más. | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。開いても閉じても、そのまま書き続けられます。 | es-ES とまったく同じ文。注記も es-ES と同じ。メキシコ向けとしても不自然ではない |
| 1.4.L1A.fr-FR（fr-CA も同じ字） | • L’app occupe désormais tout le grand écran de l’iPhone Duo. Que vous l’ouvriez ou le fermiez, vous pouvez simplement continuer à écrire. | • アプリは今後、iPhone Duo の大きな画面全体を使うようになりました。開いても閉じても、そのまま書き続けることができます。 | 「désormais」は「今後は・これからは」。「l’ouvriez」の l’ は文法上アプリとも取れるが、後ろの「le fermiez」が男性形なので iPhone Duo（端末）と読むのが自然。閉じたときにどの画面で書くのかは書かれていない |
| 1.4.L1A.it | • Ora l’app occupa tutto il grande schermo di iPhone Duo. Che lo apra o lo chiuda, può semplicemente continuare a scrivere. | • これで、アプリが iPhone Duo の大きな画面全体を使うようになりました。開いても閉じても、ただそのまま書き続けられます。 | 「Ora」は「今では・これで」。「lo」は男性名詞なので iPhone Duo のほかに schermo（画面）も指せるが、意味の上では端末と読める。丁寧語の Lei。閉じたときにどの画面で書くのかは書かれていない |
| 1.4.L1A.pt-BR | • Agora o app ocupa toda a tela grande do iPhone Duo. Mesmo que você abra ou feche o dispositivo, pode simplesmente continuar escrevendo. | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。端末を開いても閉じても、そのまま書き続けられます。 | 「Mesmo que」は「たとえ〜しても」という譲歩の言い方。「o dispositivo（端末）」と書いてあるので、開け閉めするものは曖昧でない。閉じたときにどの画面で書くのかは書かれていない |
| 1.4.L1A.pt-PT | • A aplicação passa a ocupar todo o ecrã grande do iPhone Duo. Mesmo que abra ou feche o dispositivo, pode simplesmente continuar a escrever. | • アプリは、iPhone Duo の大きな画面全体を使うようになります。端末を開いても閉じても、そのまま書き続けられます。 | 「passa a ocupar」は「〜するようになる」で、変わることを表す現在形。すでに変わったとも、これから変わるとも読める。「ecrã」「aplicação」はポルトガル向けの言葉。閉じたときにどの画面で書くのかは書かれていない |
