# 1.4 の店の文と SUPPORT の案（本人の確認ページで見せる）

**対象の版: 1.4**。ここは案で、どれもまだ Connect にも Web にも入れていない。本人の確認ページ（[M7D_CONTRACT.md](../M7D_CONTRACT.md) §9.4 の 3）で一緒に見せ、「この内容で入れてよい」をもらってから入れる。本人の「この内容で入れてよい」は、ここに書いた全部の組み合わせに効く（契約 §8.1）。どの文を使うかは、提出の前に `duo-hinge` の結果と確かめ表（契約 §10）の答えで決め、M7D.md に書く（1.3 の確認ページの「選ぶ 1」と同じ形）。

§1・§2 は新機能の文（契約 §8.1・§8.2。行ごとの訳は役 X、元を見ない逆翻訳は R（§1 の表の右の欄。1 回目と、直した字だけの 2 回目は 2026-11-20 で、全文と R の注は [docs/i18n/back/store-1_4.md](../i18n/back/store-1_4.md)）、照合と判定は [docs/i18n/REVIEW.md](../i18n/REVIEW.md)）。§3 は審査メモと SUPPORT の条件で替わる文（役 N）。新機能の文は、まだ `docs/store/<ロケール>/whatsnew.txt` にも入れていない（使う行を決めたときに入れる。§2.4）。

## 1. 新機能の文の行と条件、行ごとの訳（役 X）

使う行は 行 1 → 行 2 → 行 3 → 行 4 の順に並べ、空の行を 1 つ置いて、訳についての 1 行（ja には無い）。行 1 は案 A か案 B のどちらか 1 つ。表の右の欄は R が、日本語の元と §1.0 を見ずに書く。右の欄の終わりの（○）（△）は役 J の判定（理由は [REVIEW.md](../i18n/REVIEW.md) の 4 の「1.4 の店の文」）。行 1 案 A の es-ES・es-MX・fr-FR・it・pt-BR・pt-PT は 1 回目で × になり、訳の欄は J が直した字で、右の欄はその字の 2 回目の逆翻訳と判定（§1.7）。

### 1.0 訳の決まり（X が守ったこと）

- 元は契約 §8.1 の 5 つの行（行 1 案 A・行 1 案 B・行 2・行 3・行 4）。下の日本語と条件は契約の字そのまま（機械で契約から読んだ）。ja と `source-ja` はこの字を使う。
- ロケール: 訳したのは 11 組（en-US・de-DE・es-ES・es-MX・fr-FR・it・ko・pt-BR・pt-PT・zh-Hans・zh-Hant）。en-GB・en-AU・en-CA は en-US の写し、fr-CA は fr-FR の写し（`docs/store/locales.json` の `copyOf`）。ja と合わせて 16 ロケール。
- **es-ES** は es-MX から直した（1.3 と同じ）。違うのは行 3 と行 4 の時制だけ（es-MX の pasó・se ajustaron → es-ES の ha pasado・se han ajustado。1.3 の se corrigió → se ha corregido と同じ直し）。行 1 の 2 案と行 2 は同じ字。
- **pt-PT** は pt-BR の写しにせず別に書いた（aplicação・ecrã・deslocar・noutros・dias de descanso・「passa a」の形）。行 2 のアプリの画面の名前（“Traçar com o dedo”・barra de ferramentas）は、そう表示されるのでアプリの pt-BR の語のまま（[GLOSSARY.md](../i18n/GLOSSARY.md) §1）。
- **「指でも書く」**は、各言語のアプリの `toolbar.fingerToggle` の訳と同じ字（`tools/l10n/translations/<言語>.json`。契約の `tools/l10n/source/app-S.json:2862` はこのキーの ja の元で、訳はこちらにある）。機械で照らした（§2.3）。
- **行 2 の 2 つ目の文**（「指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。」）は、初めての案内の 3 枚目（`onboarding.pen.text`）にある同じ字の文の、アプリの訳をそのまま使った（9 言語とも 1 字も違わない。§2.3）。en の 1 つ目の文の「as on iPad」は、§3.3 の SUPPORT の Pencil の文（役 N）と同じ言い方。
- 用語集（GLOSSARY §2）の語: 紙（paper・Papier・papier・carta・papel・종이・纸张・紙張。zh の「纸张」「紙張」はアプリの `export.pdf.note` の語）、祝日（Holidays・Feiertage・jours fériés・festività・días festivos・feriados・공휴일・节假日・假日）。丁寧さと引用符は GLOSSARY §1（fr の « » の内側は U+00A0）。
- 製品の名前（iPhone Duo・iPad・iPhone・Apple Pencil・iOS）はどの言語もそのまま。冠詞は 1.2 からの説明（`description.txt` の 1 行目）にそろえた（de dem・fr l’・es el・pt o。it は冠詞なし）。
- 「開く・閉じる」は、Apple の Duo の姿勢の名前（Open・Closed。`docs/m7d/FACTS.md` の S9・S10・S15）に合う普通の動詞にした。ko は折りたたみの端末の普通の語 펼치다・접다、zh は 展开・合上（zh-Hant は 展開・闔上）。
- 「ほかの iPhone」は Duo でない iPhone のことなので、「ほかの iPhone の機種」の語にした（models・Modelle・modèles・modelli・modelos・모델・机型・機型）。ko は「iPad와 다른 iPhone」が「iPad と違う iPhone」とも読めるので、「iPad에서도, 다른 iPhone 모델에서도」と分けた。
- 書いていないこと: K-8 の句（契約 §5.2。1.4 は新しい欄も形も無い）、確かめていない動き、無い改善（R1_2_2.md:694）、価格と通貨の記号（L-9）。
- **訳についての 1 行**は、1.3 の各ロケールの `whatsnew.txt` の最後の行の字のまま（1.2.3 から変えていない。1.3 の判定で ○）。
- ここに無い物: N-3 の言い方の案（契約 §1.5。確認ページで選ぶ。既定は今のまま）は、1.3 の訳と元を見ない逆翻訳をそのまま使うので写さない（[PROPOSALS_1_3.md](PROPOSALS_1_3.md) §2）。

### 1.1 行 1 案 A

- 条件（契約 §8.1 のまま）: 開閉を確かめられたとき: 27.3 の正式版の `duo-hinge` で `DuoHingeUITests` が緑、または本人の Duo で確かめ表の行 18 と 25 が ○。既定の道 3 では本人の Duo だけが頼り

| ロケール | 訳 | 元を見ない逆翻訳（R） |
| --- | --- | --- |
| ja（source-ja も） | ・iPhone Duo の大きな画面いっぱいに表示されるようになりました。開いても閉じても、そのまま書き続けられます。 | — |
| en-US（en-GB・en-AU・en-CA も） | • The app now fills the large screen of iPhone Duo. Whether you open it or close it, you can just keep writing. | ・アプリが iPhone Duo の大きな画面いっぱいに表示されるようになりました。それを開いても閉じても、そのまま書き続けられます。（○） |
| de-DE | • Die App füllt jetzt den großen Bildschirm des iPhone Duo aus. Ob Sie es öffnen oder schließen, Sie können einfach weiterschreiben. | ・アプリは今、iPhone Duo の大きな画面いっぱいに表示されます。それを開いても閉じても、そのまま書き続けられます。（○） |
| es-ES | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin más. | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。開いても閉じても、そのまま書き続けられます。（○。2 回目。1 回目の字は 2 つ目の文が「Tanto si lo abre como si lo cierra, puede seguir escribiendo sin interrupciones.」で、逆翻訳「それを開いても閉じても、途切れることなく書き続けられます。」が ×。§1.7） |
| es-MX | • Ahora la app ocupa toda la pantalla grande del iPhone Duo. Tanto si lo abre como si lo cierra, puede seguir escribiendo sin más. | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。開いても閉じても、そのまま書き続けられます。（○。2 回目。1 回目の字は 2 つ目の文が「Tanto si lo abre como si lo cierra, puede seguir escribiendo sin interrupciones.」で、逆翻訳「それを開いても閉じても、途切れることなく書き続けられます。」が ×。§1.7） |
| fr-FR（fr-CA も） | • L’app occupe désormais tout le grand écran de l’iPhone Duo. Que vous l’ouvriez ou le fermiez, vous pouvez simplement continuer à écrire. | • アプリは今後、iPhone Duo の大きな画面全体を使うようになりました。開いても閉じても、そのまま書き続けることができます。（○。2 回目。1 回目の字は 2 つ目の文が「Que vous l’ouvriez ou le fermiez, vous pouvez continuer à écrire sans interruption.」で、逆翻訳「それを開いても閉じても、中断せずに書き続けられます。」が ×。§1.7） |
| it | • Ora l’app occupa tutto il grande schermo di iPhone Duo. Che lo apra o lo chiuda, può semplicemente continuare a scrivere. | • これで、アプリが iPhone Duo の大きな画面全体を使うようになりました。開いても閉じても、ただそのまま書き続けられます。（○。2 回目。1 回目の字は 2 つ目の文が「Che lo apra o lo chiuda, può continuare a scrivere senza interruzioni.」で、逆翻訳「それを開いても閉じても、中断なく書き続けられます。」が ×。§1.7） |
| ko | • 이제 iPhone Duo의 큰 화면을 가득 채워 표시해요. 펼쳐도 접어도 그대로 계속 쓸 수 있어요. | ・これからは iPhone Duo の大きな画面いっぱいに表示します。開いても閉じても、そのまま書き続けられます。（○） |
| pt-BR | • Agora o app ocupa toda a tela grande do iPhone Duo. Mesmo que você abra ou feche o dispositivo, pode simplesmente continuar escrevendo. | • これからは、アプリが iPhone Duo の大きな画面全体に表示されます。端末を開いても閉じても、そのまま書き続けられます。（○。2 回目。1 回目の字は 2 つ目の文が「Ao abrir ou fechar o dispositivo, você pode continuar escrevendo sem interrupção.」で、逆翻訳「デバイスを開いたり閉じたりするときも、中断なく書き続けられます。」が ×。§1.7） |
| pt-PT | • A aplicação passa a ocupar todo o ecrã grande do iPhone Duo. Mesmo que abra ou feche o dispositivo, pode simplesmente continuar a escrever. | • アプリは、iPhone Duo の大きな画面全体を使うようになります。端末を開いても閉じても、そのまま書き続けられます。（○。2 回目。1 回目の字は 2 つ目の文が「Ao abrir ou fechar o dispositivo, pode continuar a escrever sem interrupção.」で、逆翻訳「デバイスを開いたり閉じたりするときも、中断なく書き続けられます。」が ×。§1.7） |
| zh-Hans | • 现在会在 iPhone Duo 的大屏幕上全屏显示。无论展开还是合上，都可以直接继续书写。 | ・今後は iPhone Duo の大きな画面で全画面表示されます。広げても閉じても、そのまま書き続けられます。（○） |
| zh-Hant | • 現在會在 iPhone Duo 的大螢幕上全螢幕顯示。無論展開還是闔上，都可以直接繼續書寫。 | ・今後は iPhone Duo の大きな画面で全画面表示されます。広げても閉じても、そのまま書き続けられます。（○） |

### 1.2 行 1 案 B

- 条件（契約 §8.1 のまま）: 確かめられなかったとき

| ロケール | 訳 | 元を見ない逆翻訳（R） |
| --- | --- | --- |
| ja（source-ja も） | ・iPhone Duo の大きな画面に合わせて表示するようにしました。 | — |
| en-US（en-GB・en-AU・en-CA も） | • The app now adjusts its layout to the large screen of iPhone Duo. | ・アプリが iPhone Duo の大きな画面に合わせてレイアウトを調整するようになりました。（○） |
| de-DE | • Die Darstellung passt sich jetzt an den großen Bildschirm des iPhone Duo an. | ・表示が iPhone Duo の大きな画面に合わせて調整されるようになりました。（○） |
| es-ES | • Ahora la visualización se adapta a la pantalla grande del iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。（○） |
| es-MX | • Ahora la visualización se adapta a la pantalla grande del iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。（○） |
| fr-FR（fr-CA も） | • L’affichage s’adapte désormais au grand écran de l’iPhone Duo. | ・これからは、表示が iPhone Duo の大きな画面に合わせて調整されます。（○） |
| it | • Ora la visualizzazione si adatta al grande schermo di iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。（○） |
| ko | • iPhone Duo의 큰 화면에 맞춰 표시하도록 했어요. | ・iPhone Duo の大きな画面に合わせて表示するようにしました。（○） |
| pt-BR | • Agora a exibição se adapta à tela grande do iPhone Duo. | ・今では表示が iPhone Duo の大きな画面に合わせて調整されます。（○） |
| pt-PT | • A apresentação passa a adaptar-se ao ecrã grande do iPhone Duo. | ・表示が iPhone Duo の大きな画面に合わせて調整されるようになります。（○） |
| zh-Hans | • 现在会根据 iPhone Duo 的大屏幕调整显示。 | ・今後は iPhone Duo の大きな画面に応じて表示を調整します。（○） |
| zh-Hant | • 現在會配合 iPhone Duo 的大螢幕調整顯示。 | ・今後は iPhone Duo の大きな画面に合わせて表示を調整します。（○） |

### 1.3 行 2

- 条件（契約 §8.1 のまま）: Duo の Apple Pencil。本人の Duo で確かめ表の行 19 と 20 が ○ のときだけ

| ロケール | 訳 | 元を見ない逆翻訳（R） |
| --- | --- | --- |
| ja（source-ja も） | ・iPhone Duo では iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書きたいときは、ツールバーの「指でも書く」をオンにしてください。 | — |
| en-US（en-GB・en-AU・en-CA も） | • On iPhone Duo, as on iPad, you write with Apple Pencil and move the paper with your finger (iOS 27.2 or later). To also write with your finger, turn on “Draw with Finger” in the toolbar. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「Draw with Finger（指で描く）」をオンにしてください。（○） |
| de-DE | • Auf dem iPhone Duo schreiben Sie wie auf dem iPad mit dem Apple Pencil und bewegen das Papier mit dem Finger (ab iOS 27.2). Um auch mit dem Finger zu schreiben, aktivieren Sie „Mit Finger zeichnen“ in der Werkzeugleiste. | ・iPhone Duo では iPad と同じように Apple Pencil で書き、指で紙を動かします（iOS 27.2 から）。指でも書くには、ツールバーの「指で描く」をオンにしてください。（○） |
| es-ES | • En el iPhone Duo, igual que en el iPad, escribe con el Apple Pencil y mueve el papel con el dedo (iOS 27.2 o posterior). Para escribir también con el dedo, active “Dibujar con el dedo” en la barra de herramientas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で描く」をオンにしてください。（○） |
| es-MX | • En el iPhone Duo, igual que en el iPad, escribe con el Apple Pencil y mueve el papel con el dedo (iOS 27.2 o posterior). Para escribir también con el dedo, active “Dibujar con el dedo” en la barra de herramientas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で描く」をオンにしてください。（○） |
| fr-FR（fr-CA も） | • Sur l’iPhone Duo, comme sur l’iPad, vous écrivez avec l’Apple Pencil et déplacez le papier avec le doigt (iOS 27.2 ou version ultérieure). Pour écrire aussi avec le doigt, activez « Écrire au doigt » dans la barre d’outils. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で書く」をオンにしてください。（○） |
| it | • Su iPhone Duo, come su iPad, scrive con Apple Pencil e sposta la carta con il dito (iOS 27.2 o versioni successive). Per scrivere anche con il dito, attivi “Scrivi con il dito” nella barra degli strumenti. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指で書く」をオンにしてください。（○） |
| ko | • iPhone Duo에서는 iPad와 마찬가지로 Apple Pencil로 쓰고, 손가락으로 종이를 움직여요(iOS 27.2 이상). 손가락으로도 쓰고 싶다면 도구 막대의 ‘손가락으로 쓰기’를 켜 주세요. | ・iPhone Duo では iPad と同じように Apple Pencil で書き、指で紙を動かします（iOS 27.2 以上）。指でも書きたいなら、ツールバーの「指で書く」をオンにしてください。（○） |
| pt-BR | • No iPhone Duo, assim como no iPad, você escreve com o Apple Pencil e move o papel com o dedo (iOS 27.2 ou posterior). Para escrever também com o dedo, ative “Traçar com o dedo” na barra de ferramentas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指でなぞる（線を引く）」をオンにしてください。（○） |
| pt-PT | • No iPhone Duo, tal como no iPad, escreve com o Apple Pencil e desloca o papel com o dedo (iOS 27.2 ou posterior). Para escrever também com o dedo, ative “Traçar com o dedo” na barra de ferramentas. | ・iPhone Duo では、iPad と同じように、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書くには、ツールバーの「指でなぞる（線を引く）」をオンにしてください。（○） |
| zh-Hans | • 在 iPhone Duo 上，和 iPad 一样，用 Apple Pencil 书写，用手指移动纸张（iOS 27.2 或更高版本）。如果也想用手指书写，请打开工具栏中的“用手指书写”。 | ・iPhone Duo では、iPad と同じく、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以降）。指でも書きたい場合は、ツールバーの「指で書く」をオンにしてください。（○） |
| zh-Hant | • 在 iPhone Duo 上，和 iPad 一樣，用 Apple Pencil 書寫，用手指移動紙張（iOS 27.2 或以上版本）。如果也想用手指書寫，請開啟工具列中的「用手指書寫」。 | ・iPhone Duo では、iPad と同じく、Apple Pencil で書き、指で紙を動かします（iOS 27.2 以上のバージョン）。指でも書きたい場合は、ツールバーの「指で書く」をオンにしてください。（○） |

### 1.4 行 3

- 条件（契約 §8.1 のまま）: いつも

| ロケール | 訳 | 元を見ない逆翻訳（R） |
| --- | --- | --- |
| ja（source-ja も） | ・iOS 27 の新しい開発環境に移りました。iPad とほかの iPhone での使い方は変わりません。 | — |
| en-US（en-GB・en-AU・en-CA も） | • The app has moved to the new development environment for iOS 27. How you use it on iPad and other iPhone models stays the same. | ・アプリは iOS 27 向けの新しい開発環境に移行しました。iPad やほかの iPhone の機種での使い方は変わりません。（△） |
| de-DE | • Die App wurde auf die neue Entwicklungsumgebung für iOS 27 umgestellt. Die Bedienung auf dem iPad und auf anderen iPhone-Modellen ändert sich nicht. | ・アプリは iOS 27 向けの新しい開発環境に切り替えられました。iPad とほかの iPhone の機種での操作は変わりません。（△） |
| es-ES | • La app ha pasado al nuevo entorno de desarrollo de iOS 27. La forma de usarla en el iPad y en otros modelos de iPhone no cambia. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad やほかの iPhone の機種での使い方は変わりません。（△） |
| es-MX | • La app pasó al nuevo entorno de desarrollo de iOS 27. La forma de usarla en el iPad y en otros modelos de iPhone no cambia. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad やほかの iPhone の機種での使い方は変わりません。（△） |
| fr-FR（fr-CA も） | • L’app est passée au nouvel environnement de développement d’iOS 27. Son utilisation sur l’iPad et sur les autres modèles d’iPhone ne change pas. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。（△） |
| it | • L’app è passata al nuovo ambiente di sviluppo di iOS 27. L’uso su iPad e sugli altri modelli di iPhone non cambia. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。（△） |
| ko | • iOS 27의 새로운 개발 환경으로 옮겼어요. iPad에서도, 다른 iPhone 모델에서도 사용법은 바뀌지 않아요. | ・iOS 27 の新しい開発環境に移しました。iPad でも、ほかの iPhone の機種でも、使い方は変わりません。（△） |
| pt-BR | • O app passou para o novo ambiente de desenvolvimento do iOS 27. O uso no iPad e em outros modelos de iPhone não muda. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。（△） |
| pt-PT | • A aplicação passou para o novo ambiente de desenvolvimento do iOS 27. A utilização no iPad e noutros modelos de iPhone não muda. | ・アプリは iOS 27 の新しい開発環境に移行しました。iPad とほかの iPhone の機種での使い方は変わりません。（△） |
| zh-Hans | • 已迁移到 iOS 27 的新开发环境。在 iPad 和其他 iPhone 机型上的使用方法不变。 | ・iOS 27 の新しい開発環境へ移行済みです。iPad やほかの iPhone の機種での使い方は変わりません。（△） |
| zh-Hant | • 已遷移至 iOS 27 的新開發環境。在 iPad 和其他 iPhone 機型上的使用方式不變。 | ・iOS 27 の新しい開発環境へ移行済みです。iPad やほかの iPhone の機種での使い方は変わりません。（△） |

### 1.5 行 4

- 条件（契約 §8.1 のまま）: 中国の祝日を入れたときだけ

| ロケール | 訳 | 元を見ない逆翻訳（R） |
| --- | --- | --- |
| ja（source-ja も） | ・中国の 2027 年の祝日を、発表された休みに合わせました。 | — |
| en-US（en-GB・en-AU・en-CA も） | • Holidays in China for 2027 have been updated to match the announced days off. | ・中国の 2027 年の祝日を、発表された休みの日に合わせて更新しました。（○） |
| de-DE | • Die Feiertage in China für 2027 wurden an die bekannt gegebenen freien Tage angepasst. | ・2027 年の中国の祝日は、発表された休みの日に合わせて調整されました。（○） |
| es-ES | • Los días festivos de China en 2027 se han ajustado a los días de descanso anunciados. | ・2027 年の中国の祝日を、発表された休みの日に合わせて調整しました。（○） |
| es-MX | • Los días festivos de China en 2027 se ajustaron a los días de descanso anunciados. | ・2027 年の中国の祝日を、発表された休みの日に合わせて調整しました。（○） |
| fr-FR（fr-CA も） | • Les jours fériés de 2027 en Chine ont été alignés sur les congés annoncés. | ・中国の 2027 年の祝日を、発表された休み（休暇）にそろえました。（○） |
| it | • Le festività della Cina per il 2027 sono state allineate ai giorni di riposo annunciati. | ・中国の 2027 年の祝日は、発表された休みの日にそろえられました。（○） |
| ko | • 중국의 2027년 공휴일을 발표된 휴무 일정에 맞췄어요. | ・中国の 2027 年の祝日を、発表された休み（休業）の日程に合わせました。（○） |
| pt-BR | • Os feriados da China em 2027 foram ajustados de acordo com os dias de folga anunciados. | ・2027 年の中国の祝日は、発表された休みの日に合わせて調整されました。（○） |
| pt-PT | • Os feriados da China em 2027 foram ajustados de acordo com os dias de descanso anunciados. | ・2027 年の中国の祝日は、発表された休息日に合わせて調整されました。（○） |
| zh-Hans | • 已按公布的放假安排调整中国 2027 年的节假日。 | ・公表された休みの取り決め（休暇の日程）に従って、中国の 2027 年の祝日を調整しました。（○） |
| zh-Hant | • 已依公布的放假安排調整中國 2027 年的假日。 | ・公表された休みの取り決めに従って、中国の 2027 年の休日を調整しました。（△） |

### 1.6 訳についての 1 行（ja 以外。1.3 のまま）

| ロケール | 訳 | 元を見ない逆翻訳（R） |
| --- | --- | --- |
| source-ja（元。入力しない） | 訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。 | — |
| en-US（en-GB・en-AU・en-CA も） | Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| de-DE | Die Übersetzungen wurden mit KI erstellt und noch nicht von Muttersprachlern geprüft. Bitte teilen Sie uns Fehler mit. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| es-ES | Las traducciones se han hecho con IA y todavía no las han revisado hablantes nativos. Avísenos si encuentra errores. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| es-MX | Las traducciones se hicieron con IA y todavía no las han revisado hablantes nativos. Avísenos si encuentra errores. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| fr-FR（fr-CA も） | Les traductions ont été faites avec une IA et n’ont pas encore été relues par des locuteurs natifs. Signalez-nous les erreurs. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| it | Le traduzioni sono state fatte con l’IA e non sono ancora state riviste da madrelingua. La preghiamo di segnalarci gli errori. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| ko | 번역은 AI로 만들었고 아직 원어민의 검토를 받지 않았어요. 오류가 있으면 알려 주세요. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| pt-BR | As traduções foram feitas com IA e ainda não foram revisadas por falantes nativos. Avise-nos sobre erros. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| pt-PT | As traduções foram feitas com IA e ainda não foram revistas por falantes nativos. Informe-nos sobre erros. | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| zh-Hans | 译文由 AI 生成，尚未经过母语人士审核。如有错误，请告诉我们。 | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |
| zh-Hant | 譯文由 AI 製作，尚未經過母語人士審閱。如有錯誤，請告訴我們。 | 1.3 と同じ字（REVIEW.md の 4 で ○）。R は要らない |

### 1.7 照合と判定（役 J、2026-11-20）

- R の 1 回目（2026-11-20）は、§1.1〜§1.5 の「訳」の欄と §3 の英語の文だけを読んだ（日本語の元・§1.0・行の条件・§2 は渡していない）。逆翻訳の全文と R の注は [docs/i18n/back/store-1_4.md](../i18n/back/store-1_4.md)。§1 の右の欄は、その逆翻訳と J の判定。判定の理由は [REVIEW.md](../i18n/REVIEW.md) の 4 の「1.4 の店の文」。
- 1 回目の判定: 新機能の文（11 組 × 5 行）は ○ 37・△ 12・× 6。§3 の審査メモの段と条件で替わる文は ○ 5・△ 3・× 0、SUPPORT.en の 3 文は ○ 3・× 0（直した字なし）。
- × の 6 件は、行 1 案 A の es-ES・es-MX・fr-FR・it・pt-BR・pt-PT。2 つ目の文の「中断なく」（sin interrupciones・sans interruption・senza interruzioni・sem interrupção）が、開閉の間も書くことが途切れないと読め、書きながら閉じたときに書きかけの 1 本が消えることがある（契約 §4.9 の 3、確かめ表の行 25）のと食い違う（無い改善。契約 §8.1）。元の「そのまま」にあたる語（en の just、de の einfach と同じ）に替えた。pt-BR・pt-PT は、開閉の最中と読まれた「Ao abrir ou fechar o dispositivo」（開いたり閉じたりするとき）も、「開いても閉じても」の形にした。1 つ目の文は変えていない。

| ロケール | 前の字（2 つ目の文） | 今の字（2 つ目の文） |
| --- | --- | --- |
| es-ES・es-MX | Tanto si lo abre como si lo cierra, puede seguir escribiendo sin interrupciones. | Tanto si lo abre como si lo cierra, puede seguir escribiendo sin más. |
| fr-FR（fr-CA も） | Que vous l’ouvriez ou le fermiez, vous pouvez continuer à écrire sans interruption. | Que vous l’ouvriez ou le fermiez, vous pouvez simplement continuer à écrire. |
| it | Che lo apra o lo chiuda, può continuare a scrivere senza interruzioni. | Che lo apra o lo chiuda, può semplicemente continuare a scrivere. |
| pt-BR | Ao abrir ou fechar o dispositivo, você pode continuar escrevendo sem interrupção. | Mesmo que você abra ou feche o dispositivo, pode simplesmente continuar escrevendo. |
| pt-PT | Ao abrir ou fechar o dispositivo, pode continuar a escrever sem interrupção. | Mesmo que abra ou feche o dispositivo, pode simplesmente continuar a escrever. |

- 直した 6 つの字（行 1 案 A の全文）だけを 2 回目の R に渡した（2026-11-20。id と訳だけで、前の字・1 回目の逆翻訳・日本語の元・ほかの行は渡していない）。
- 2 回目の判定: 6 つとも ○（× 0）。6 つとも「（これからは・今後）アプリが iPhone Duo の大きな画面全体に表示される（を使う）ようになった。（端末を）開いても閉じても、そのまま書き続けられる」と読まれ、元と同じ。「中断なく」や開閉の最中の読みは出なかった。sin más・simplement・semplicemente・simplesmente は「そのまま」（it は「ただそのまま」で、en の just と同じ扱い）、pt の Mesmo que は「開いても閉じても」と読まれた。理由は [REVIEW.md](../i18n/REVIEW.md) の 4 の「1.4 の店の文」の「2 回目」。× が残っていないので、3 回目は無い。
- 最後の判定（2 回目の後）: 新機能の文は ○ 43・△ 12・× 0。§3 の文は 1 回目のまま（審査メモの段と条件で替わる文は ○ 5・△ 3・× 0、SUPPORT.en は ○ 3・× 0）。§1 の訳の欄の字が、確認ページで見せる字（判定の上で直す字はもう無い。入れるのは本人の「この内容で入れてよい」の後）。
- 直した後の字で機械で照らしたこと: 行 2 の「指でも書く」は 11 組ともアプリの `toolbar.fingerToggle` の訳と同じ字（§2.3 の表のまま）。K-8 の句（古い版の端末での見え方）と「中断なく」の語は、11 組の 5 行のどれにも無い。字数は §2.2（直した 6 つの「いちばん長い組み合わせ」を直した。どれも 4,000 字に入る）。既定の全文（§2.1。案 B ＋ 行 3）は変わらない。

## 2. 新機能の文の既定の組み合わせの全文（行 1 案 B ＋ 行 3。役 X）

既定は、契約の既定の道 3（§4.2。CI では Duo を開けない）のまま、本人の Duo の確かめ表を待つ前の形: **行 1 案 B と行 3**（と、ja 以外は訳についての 1 行）。提出の前に、条件がそろった行を次のとおり替える・足す（決めた組み合わせは M7D.md に書く）。

- **行 1**: 開閉を確かめられたとき（27.3 の正式版の `duo-hinge` で `DuoHingeUITests` が緑、または本人の Duo で確かめ表の行 18 と 25 が ○。既定の道 3 では本人の Duo だけが頼り）は、案 B を**案 A に替える**（§1.1）。§3 の審査メモと SUPPORT の案 A・案 B と同じ条件。
- **行 2**: Duo の Apple Pencil。本人の Duo で確かめ表の行 19 と 20 が ○ のときだけ。行 1 のすぐ後に**足す**（§1.3）。§3.3 の SUPPORT の Apple Pencil の文と同じ条件。
- **行 4**: 中国の祝日を入れたときだけ（契約 §9.6）。行 3 のすぐ後に**足す**（§1.5）。

組み合わせは 8 つ（行 1 の 2 案 × 行 2 の有無 × 行 4 の有無）。下の全文は既定の 1 つ。ほかの 7 つは、§1 の表の行を同じ順で組み合わせた物（字は 1 字も変えない）。

### 2.1 ロケールごとの全文（既定）

**ja**（`ja/whatsnew.txt` に入れる字。訳についての 1 行は無い）:

```text
・iPhone Duo の大きな画面に合わせて表示するようにしました。
・iOS 27 の新しい開発環境に移りました。iPad とほかの iPhone での使い方は変わりません。
```

**source-ja**（ja 以外の日本語の元。Connect には入れない）:

```text
・iPhone Duo の大きな画面に合わせて表示するようにしました。
・iOS 27 の新しい開発環境に移りました。iPad とほかの iPhone での使い方は変わりません。

訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。
```

**en-US（en-GB・en-AU・en-CA も）**:

```text
• The app now adjusts its layout to the large screen of iPhone Duo.
• The app has moved to the new development environment for iOS 27. How you use it on iPad and other iPhone models stays the same.

Translations were made with AI and have not yet been reviewed by native speakers. Please tell us about mistakes.
```

**de-DE**:

```text
• Die Darstellung passt sich jetzt an den großen Bildschirm des iPhone Duo an.
• Die App wurde auf die neue Entwicklungsumgebung für iOS 27 umgestellt. Die Bedienung auf dem iPad und auf anderen iPhone-Modellen ändert sich nicht.

Die Übersetzungen wurden mit KI erstellt und noch nicht von Muttersprachlern geprüft. Bitte teilen Sie uns Fehler mit.
```

**es-ES**:

```text
• Ahora la visualización se adapta a la pantalla grande del iPhone Duo.
• La app ha pasado al nuevo entorno de desarrollo de iOS 27. La forma de usarla en el iPad y en otros modelos de iPhone no cambia.

Las traducciones se han hecho con IA y todavía no las han revisado hablantes nativos. Avísenos si encuentra errores.
```

**es-MX**:

```text
• Ahora la visualización se adapta a la pantalla grande del iPhone Duo.
• La app pasó al nuevo entorno de desarrollo de iOS 27. La forma de usarla en el iPad y en otros modelos de iPhone no cambia.

Las traducciones se hicieron con IA y todavía no las han revisado hablantes nativos. Avísenos si encuentra errores.
```

**fr-FR（fr-CA も）**:

```text
• L’affichage s’adapte désormais au grand écran de l’iPhone Duo.
• L’app est passée au nouvel environnement de développement d’iOS 27. Son utilisation sur l’iPad et sur les autres modèles d’iPhone ne change pas.

Les traductions ont été faites avec une IA et n’ont pas encore été relues par des locuteurs natifs. Signalez-nous les erreurs.
```

**it**:

```text
• Ora la visualizzazione si adatta al grande schermo di iPhone Duo.
• L’app è passata al nuovo ambiente di sviluppo di iOS 27. L’uso su iPad e sugli altri modelli di iPhone non cambia.

Le traduzioni sono state fatte con l’IA e non sono ancora state riviste da madrelingua. La preghiamo di segnalarci gli errori.
```

**ko**:

```text
• iPhone Duo의 큰 화면에 맞춰 표시하도록 했어요.
• iOS 27의 새로운 개발 환경으로 옮겼어요. iPad에서도, 다른 iPhone 모델에서도 사용법은 바뀌지 않아요.

번역은 AI로 만들었고 아직 원어민의 검토를 받지 않았어요. 오류가 있으면 알려 주세요.
```

**pt-BR**:

```text
• Agora a exibição se adapta à tela grande do iPhone Duo.
• O app passou para o novo ambiente de desenvolvimento do iOS 27. O uso no iPad e em outros modelos de iPhone não muda.

As traduções foram feitas com IA e ainda não foram revisadas por falantes nativos. Avise-nos sobre erros.
```

**pt-PT**:

```text
• A apresentação passa a adaptar-se ao ecrã grande do iPhone Duo.
• A aplicação passou para o novo ambiente de desenvolvimento do iOS 27. A utilização no iPad e noutros modelos de iPhone não muda.

As traduções foram feitas com IA e ainda não foram revistas por falantes nativos. Informe-nos sobre erros.
```

**zh-Hans**:

```text
• 现在会根据 iPhone Duo 的大屏幕调整显示。
• 已迁移到 iOS 27 的新开发环境。在 iPad 和其他 iPhone 机型上的使用方法不变。

译文由 AI 生成，尚未经过母语人士审核。如有错误，请告诉我们。
```

**zh-Hant**:

```text
• 現在會配合 iPhone Duo 的大螢幕調整顯示。
• 已遷移至 iOS 27 的新開發環境。在 iPad 和其他 iPhone 機型上的使用方式不變。

譯文由 AI 製作，尚未經過母語人士審閱。如有錯誤，請告訴我們。
```

### 2.2 字数（上限 4,000 字）

数え方は L-9（`tools/l10n/lint.py` の `store_text`）と同じで、ファイルの末尾の改行 1 つを除いた字の数（どの字も BMP の中なので、UTF-16 で数えても同じ）。いちばん長い組み合わせは 行 1 案 A ＋ 行 2 ＋ 行 3 ＋ 行 4、いちばん短いのは既定で、8 つの組み合わせはどれもその間。どのロケールも上限の 4,000 字に大きく余裕がある（1.3 の文より短い）。es-ES・es-MX・fr-FR・it・pt-BR・pt-PT のいちばん長い組み合わせは、J が行 1 案 A を直した後の字で数え直した（§1.7）。

| ロケール | 既定（案 B ＋ 行 3。いちばん短い） | いちばん長い組み合わせ（案 A ＋ 行 2 ＋ 行 3 ＋ 行 4） | 上限 |
| --- | ---: | ---: | ---: |
| ja | 89 | 248 | 4,000 |
| source-ja | 134 | 293 | 4,000 |
| en-US（en-GB・en-AU・en-CA も） | 311 | 624 | 4,000 |
| de-DE | 349 | 715 | 4,000 |
| es-ES | 320 | 683 | 4,000 |
| es-MX | 314 | 674 | 4,000 |
| fr-FR（fr-CA も） | 339 | 716 | 4,000 |
| it | 312 | 667 | 4,000 |
| ko | 151 | 325 | 4,000 |
| pt-BR | 284 | 658 | 4,000 |
| pt-PT | 304 | 673 | 4,000 |
| zh-Hans | 113 | 256 | 4,000 |
| zh-Hant | 113 | 256 | 4,000 |

### 2.3 機械で照らしたこと（X、書いた日に）

- 日本語の 5 つの行と条件は、契約 §8.1 の `>` の行と太字の見出しの括弧から読んだ（手で写していない）。
- 行 2 の「指でも書く」は、アプリの `toolbar.fingerToggle` の訳と同じ字。行 2 は `onboarding.pen.text` の訳の、その語を含む文で終わる:

| ロケール | アプリの言語 | `toolbar.fingerToggle` | `onboarding.pen.text` の文（行 2 の 2 つ目の文） |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も） | en | Draw with Finger | To also write with your finger, turn on “Draw with Finger” in the toolbar. |
| de-DE | de | Mit Finger zeichnen | Um auch mit dem Finger zu schreiben, aktivieren Sie „Mit Finger zeichnen“ in der Werkzeugleiste. |
| es-ES | es | Dibujar con el dedo | Para escribir también con el dedo, active “Dibujar con el dedo” en la barra de herramientas. |
| es-MX | es | Dibujar con el dedo | Para escribir también con el dedo, active “Dibujar con el dedo” en la barra de herramientas. |
| fr-FR（fr-CA も） | fr | Écrire au doigt | Pour écrire aussi avec le doigt, activez « Écrire au doigt » dans la barre d’outils. |
| it | it | Scrivi con il dito | Per scrivere anche con il dito, attivi “Scrivi con il dito” nella barra degli strumenti. |
| ko | ko | 손가락으로 쓰기 | 손가락으로도 쓰고 싶다면 도구 막대의 ‘손가락으로 쓰기’를 켜 주세요. |
| pt-BR | pt-BR | Traçar com o dedo | Para escrever também com o dedo, ative “Traçar com o dedo” na barra de ferramentas. |
| pt-PT | pt-BR | Traçar com o dedo | Para escrever também com o dedo, ative “Traçar com o dedo” na barra de ferramentas. |
| zh-Hans | zh-Hans | 用手指书写 | 如果也想用手指书写，请打开工具栏中的“用手指书写”。 |
| zh-Hant | zh-Hant | 用手指書寫 | 如果也想用手指書寫，請開啟工具列中的「用手指書寫」。 |

- 用語集の「紙」の語が行 2 に、「祝日」の語が行 4 にある（11 組）。Duo の行（行 1・行 2）には「iPhone Duo」の字がそのままある。
- 訳についての 1 行は 1.3 の `whatsnew.txt` の最後の行と同じ字（11 組と source-ja）。
- L-9 の価格と通貨の記号（`STORE_PRICE`）は 0 件。どの行も「• 」で始まる（ja は「・」）。es-ES は行 3・行 4 だけが es-MX と違う。fr の « » の内側は U+00A0。
- 字数は §2.2（8 つの組み合わせのどれも 4,000 字に入る）。`lint.py` は ok（このファイルは L-9 の見る欄ではない）。

### 2.4 この後（R・リード）

- R の 1 回目（2026-11-20）は §1 の表の「訳」の欄と §3 の英語の文だけを読んだ（日本語の元と §1.0 は渡していない）。行ごとに作った文なので、逆翻訳はロケールごとのファイルに節を足さず、`docs/i18n/back/store-1_4.md` にまとめた。§1 の右の欄はその写しと判定。照合と判定は REVIEW.md の 4 の「1.4 の店の文」（§1.7）。
- 行 1 案 A の直した 6 つの字は、2 回目の R（2026-11-20、直した字だけ）で 6 つとも ○。結果は `store-1_4.md` の「2 回目」と REVIEW.md の同じ節、§1 の右の欄に書いた。× の残りは無い。
- `docs/store/<ロケール>/whatsnew.txt` と `source-ja/whatsnew.txt`、`locales.json` の `whatsnewSource`、README の「新機能の文の組み立て」は、提出の前に組み合わせを決めたときに直す（今は 1.3 の字のまま）。

## 3. 審査メモと SUPPORT の、条件で替わる文（案 B と Apple Pencil の文。役 N）

- 元: 契約 §8.3（審査メモ）・§8.4（SUPPORT）。
- ファイルには**案 A を入れた**（`docs/store/review-note.txt`・`docs/SUPPORT.md`・`docs/SUPPORT.en.md`）。案 B と、条件が満ちたときだけ入れる Apple Pencil の文は、ファイルに入れずにここに置く。
- 「指でも書く」はアプリの `toolbar.fingerToggle` の ja、「Draw with Finger」は同じキーの en の訳（`tools/l10n/translations/en.json`）と同じ字。
- K-8 の句（古い端末での見え方）は、どの文にも入れない（契約 §5.2。1.4 は新しい欄も新しい形も無い）。
- 元を見ない逆翻訳と判定（2026-11-20、役 R と J）: 審査メモの段と条件で替わる文（3.2・3.4 の替え文と、確かめ方の任意の案）は ○ 5・△ 3・× 0、SUPPORT.en の 3 文（3.2 の案 A・案 B と 3.3）は ○ 3・× 0。直した字は無い。逆翻訳は [docs/i18n/back/store-1_4.md](../i18n/back/store-1_4.md)、判定は [REVIEW.md](../i18n/REVIEW.md) の 4 の「1.4 の店の文」。

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

- **決まった（2026-11-21、リード）: 今のファイル（true の行）のまま使う。** D1c で `PencilPhone.usesHinge` を true にした（5a9e7a2。duo-shots の run 44696154794 で Duo のシミュレータの初めの起動を測った）。r14 では 7eb842b で入った。下の false の行は使わない。ここから下は、決める前に書いた覚え。
- 契約 §8.3 の (3) は、Apple Pencil の触れか画面の折り目（`UIHingeInteraction`）で「Draw with Finger」をオフにすると書く。けれども折り目を見るのは `PencilPhone.usesHinge` が true のときだけ（契約 §4.8・§4.2。Duo のシミュレータで測れたとき）で、書いた時のコードは false（M7D.md の「測ってから決める物」）。false のまま出すと、折り目の句は本当でない。
- そのときは (3) の 2 つ目の文を次に替える（ほかの文は同じ。日本語の要約は折り目を言わないので替えない）。

| `usesHinge` | (3) の 2 つ目の文（en） |
| --- | --- |
| true（今のファイル） | The app turns Draw with Finger off when that iPhone first sees an Apple Pencil touch or a screen hinge (UIHingeInteraction); on a device updated from 1.3, only an Apple Pencil touch does this. |
| false | The app turns Draw with Finger off when that iPhone first sees an Apple Pencil touch. |

- バイトは減る（4,000 の内）。決めるのは duo-shots で `usesHinge` を決めた後（リード）。→ 上の「決まった」のとおり true。

### 3.5 今のファイルに入れたもの（案 A）の覚え

- 審査メモ: 「What is new in 1.3」の段（1〜5 と Unchanged の行）を「What is new in 1.4」の 4 つに入れ替え、日本語の要約の 1.3 の分（「週と日のページが…穴を直しました。」）を 1.4 の分に入れ替えた。ほかの段（サインイン不要・言語・確かめ方（To test。1.3 の確かめ方の文も残した）・購読・記録・サーバー無し・6 つの URL）と、要約の最後の「データ・購入・年齢区分は同じ。規約類は日本語が正本で、英語は参考訳。サインイン不要。」は 1 字も変えていない。1.2 からの段は短くしていない。**3,993 バイト**（`wc -c`。最後の改行を除くと 3,992 バイト・3,716 字。`lint.py --only L-9` は ok）。1.3 の 1 の「It」と 4 の言い方の △ は、段ごと替わったので無くなった（契約 §1.5）。
- 審査メモの年齢区分: 4+ のまま、新しい 2 問（Shared Location・Dating and Relationships）はどちらも No と書いた（契約 §9.5）。1.3 の行にあった「the age range check of 1.2.2」は、契約 §8.3 の (4) に無いので書いていない。
- SUPPORT の Duo の文: 契約 §8.4 は節だけを言い、文の位置を言わないので、「手書きは指で書きます（ツールバーの「指でも書く」）。」の後に置いた。節の最初の「iPhone でも使えます（iOS 17 以上）。」のすぐ後に置くと、続く「手書きは指で書きます」が Duo の話に読めて、その文をふつうの iPhone の話として残す契約の形と合わないため。英語も同じ所。
- SUPPORT の「最終更新」の日付と「お知らせ」は変えていない（1.3 も変えていない。公開の日に Web へ出すときにリードが決める）。
