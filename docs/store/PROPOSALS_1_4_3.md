# 1.4.3 の店の文の字の選び（本人の確認ページで見せる）

**対象の版: 1.4.3**（契約 [R1_4_3_CONTRACT.md](../R1_4_3_CONTRACT.md) の第 3 版。月の並べ方は本人の 2026-11-28 の答え「ア」）。ここにある字は、どれもまだ Connect にも Web にも入れていない。本人の確認ページ（契約 §0.4）で全部の行を見せ、「この内容で入れてよい」をもらってから入れる（契約 §13.3。その言葉は全部の組み合わせに効く）。

**本人が選ぶものは無い**: 新機能の文と審査メモには、月の並べ方（ア・イ・ウ）で替わる字が無い（並べ方で替わるのは SUPPORT の文。役 W、契約 §13.5）。年が 1.4.4 に遅れたときに替える文は §4 にまとめた。

§1 は新機能の文（契約 §13.3。ja 以外の訳は役 X）、§2 は審査メモ（§13.4）、§3 は設定の脚注の語（§13.1。アプリの文なので、ここは案だけ）、§4 は年が遅れたとき（0g-3）、§5 は確かめたこととまだのこと。書いた人は D2 の役 X（2026-11-28、枝 `r143-w-d2s`）。語の決まりは [GLOSSARY.md](../i18n/GLOSSARY.md) §5（等倍）と §7（1.4.3 の語）。

## 1. 新機能の文

### 1.1 ja と source-ja（契約の字のまま）

- `ja/whatsnew.txt` は契約 §13.3 の 3 つの `>` の行を機械で写した。**契約の案の字から替えた所は無い**（決まりで替えなければならない所が無かった）。3 つ目の点は K-8 の文で、1.3 の ja の最後の点（8efca47）と 1 字も同じことを、写すときに機械で照らした。
- `source-ja/whatsnew.txt` は ja と同じ 3 つの点 → 空の行 → 訳についての 1 行（1.4.2 と 1 字も同じ）。
- 字数（L-9 の数え方。ファイルの末尾の改行 1 つを除く）: ja 285・source-ja 330。ファイルのバイト（`wc -c`）: ja 802・source-ja 925。

### 1.2 訳の字の選び（11 組）

1 つ目と 2 つ目の点は新しく訳した。3 つ目の点は、同じ ja の 1.3 の訳（8efca47 の各フォルダの最後の点）を 1 バイトも替えずに使った（1.3 の元を見ない逆翻訳と判定は [REVIEW.md](../i18n/REVIEW.md) の 4 で × 0。横つなぎの語も指のスイッチの名前も含まないので、今の語と食い違わない）。訳についての 1 行は 1.4.2 の各フォルダの最後の行と 1 字も同じ。en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の写し（`locales.json` の `copyOf`。フォルダは無い）。es-ES の 1 つ目と 2 つ目の点は es-MX と同じ字（過去形などスペインで替える語が無い）。pt-PT は別に書いた（passa a、a seguir、ecrã、repor）。

| ja の語 | 選んだ語（どの語にそろえたか） |
| --- | --- |
| 横につながる | 週と日の案内の札と設定の行の今の訳の語（GLOSSARY §7）: en joined sideways、zh-Hans 横向相连、zh-Hant 橫向相連、ko 가로로 이어지다、fr reliées côte à côte、de seitlich verbunden、it unite in orizzontale、es se unen en horizontal、pt unidas na horizontal。**1.3 の店の文の語（en side by side、fr par-dessus la limite、de über die Grenze、es lado a lado など）は使わない**。読み手が画面の札と設定で見る語にそろえるため |
| 指で横にすべらせる | 札の語: en slide your finger sideways、zh 用手指横向滑动・橫向滑動、ko 손가락으로 가로로 밀면、fr faites glisser le doigt sur le côté、de mit dem Finger seitwärts streichen、it far scorrere il dito in orizzontale、es deslice el dedo en horizontal、pt deslize o dedo na horizontal |
| 2 本指で | 札の語: en two fingers、zh-Hans 双指、zh-Hant 兩指、ko 두 손가락、fr deux doigts、de zwei Finger、it due dita、es dos dedos、pt dois dedos |
| となりの月（年） | en the neighboring month or year（en は「（年）」を括弧にせず or で。括弧が 2 つ続くのを避けた）、zh 相邻的一个月（一年）、ko 이웃한 달(또는 해)、fr le mois voisin, ou l’année voisine、de der Monat bzw. das Jahr daneben、it il mese o l’anno accanto、es el mes o el año contiguo、pt o mês ou o ano ao lado |
| 「指でも書く」 | 各言語のアプリの `toolbar.fingerToggle` の今の字を、その言語の引用符で（en “Use Finger”、de „Fingereingabe“、es “Usar el dedo”、pt-BR “Usar o dedo” は 1.4.2 で短くした名前。pt-PT はアプリの pt-BR、es-MX・es-ES はアプリの es の字）。機械で照らした |
| 境目をまたいでそのまま書ける | 札の語: en write straight across the boundary、zh-Hans 跨过交界处直接书写、zh-Hant 跨越交界處直接書寫、ko 경계를 넘어 그대로 쓸 수 있어요、fr écrire directement à cheval sur la jonction、de direkt über den Übergang hinweg schreiben、it scrivere direttamente a cavallo del confine、es escribir directamente cruzando la unión、pt escrever direto（pt-PT diretamente）atravessando a emenda |
| 下のメモ欄 | メモ欄は `toast.growthCap` の語（en notes area、zh 备忘栏・備忘欄、ko 메모 칸、fr zone de notes、de Notizbereich、it area delle note、es zona de notas、pt área de notas）、下は位置の語（en at the bottom、zh 下方的、ko 아래쪽、fr du bas、de unten、it in basso、es de abajo、pt na parte de baixo）。1.4.2 の新機能の文の the “Notes” area（欄の見出しを引用符で引く形）にはしない。1.4.3 の文は欄の場所を言うため |
| 12 月から次の年の 1 月へ | 各言語の月の名前: en from December into January of the next year、zh 从（從）12 月跨到下一年的 1 月、ko 12월에서 다음 해 1월로、fr de décembre à janvier de l’année suivante、de vom Dezember in den Januar des nächsten Jahres、it da dicembre a gennaio dell’anno successivo、es de diciembre a enero del año siguiente、pt de dezembro para janeiro do ano seguinte |
| 等倍（虫めがねに「1」のボタン） | GLOSSARY §5 の決まりどおり、名詞の「標準の大きさ」は使わず、ボタンを見た目で言う（en the button showing a magnifying glass with “1”。SUPPORT.en の 1.4.1 からの字と同じ。初めの案の the button with a magnifying glass and “1” は、「1」が虫めがねの横にあるとも読めるので、判定の J1・T1 で直した。[REVIEW.md](../i18n/REVIEW.md) の 20）。zh 放大镜中带“1”的按钮・放大鏡中有「1」的按鈕、ko 돋보기 안에 ‘1’이 있는 버튼、fr le bouton avec une loupe et un « 1 »、de die Schaltfläche mit der Lupe und der „1“、it il pulsante con la lente d’ingrandimento e il numero “1”、es el botón con una lupa y el número “1”、pt o botão com uma lupa e o número “1” |
| …も、日と週と同じく、1 ページの幅が画面の幅にちょうど合う大きさになりました | 「ズームを戻す」の動詞（読み上げの Reset Zoom などと同じ語。en resets the zoom、zh 重置缩放・重置縮放、ko 확대·축소를 재설정、fr réinitialise le zoom、de setzt den Zoom … zurück、it reimposta lo zoom、es restablece el zoom、pt-BR redefine o zoom、pt-PT repor o zoom（1.4.1 の pt-PT の店の文の語））と、1.4.1 の新機能の文の各言語の幅の文の「1 日・1 週のページ」を「1 ページ」に替えた形（en one page fits the width of the screen exactly、zh 一页的宽度正好与屏幕宽度相同・一頁的寬度正好與螢幕寬度相同、ko 한 페이지의 너비가 화면 너비에 딱 맞는、fr une page occupe exactement la largeur de l’écran、de eine Seite genauso breit ist wie der Bildschirm、it una pagina occupi esattamente la larghezza dello schermo、es una página ocupe exactamente el ancho de la pantalla、pt uma página ocupe exatamente a largura da tela（pt-PT do ecrã）） |

- **en の 1 つ目の点の並び**: ja は「月は下のメモ欄で、年は 12 月から次の年の 1 月へ、境目をまたいで…」。ko のほかの 9 つ（en・zh-Hans・zh-Hant・fr・de・it・es・pt-BR・pt-PT）は「境目をまたいで書ける」を先に言い、コロンの後に月と年の場所を並べた（ja の語順のままだと、長い前置きの後に動詞が来て読みにくい）。ko は ja と同じ語順の 1 文。
- **2 つ目の点の語順**: de・it・es・pt は「日と週と同じく」を文の頭に置いた（文の終わりに置くと、「1 ページの幅…」の比べと読み違えやすい）。en・fr は ja と同じく「月と年も」を頭に置き、「日と週と同じく」を文の終わりに置いた。zh・ko は「月と年も」の直後に置いた。

### 1.3 字数（上限 4,000 字）

数え方は L-9（`tools/l10n/lint.py` の `store_text`）と同じで、ファイルの末尾の改行 1 つを除いた字の数。機械で数えた（2026-11-28。en-US は判定の後の直しの後の字。直す前は 915）。

| ロケール | 字 | ロケール | 字 |
| --- | ---: | --- | ---: |
| ja | 285 | it | 1,083 |
| source-ja | 330 | pt-BR | 983 |
| en-US（en-GB・en-AU・en-CA も） | 919 | pt-PT | 972 |
| zh-Hans | 295 | es-MX | 1,003 |
| zh-Hant | 295 | es-ES | 1,007 |
| ko | 441 | fr-FR（fr-CA も） | 1,134 |
| de-DE | 1,061 | | |

- どれも 4,000 字より下（いちばん長い fr-FR でも 2,866 字残る）。L-9 は ok（12 のロケール）。
- プロモーションテキスト（`promo.txt`）は替えていない。新しい版で空になるので、今の文を入れ直して読み戻す（契約 §13.3）。

## 2. 審査メモ（契約 §13.4）

- `review-note.txt` は **3,789 バイト**（`wc -c`。最後の改行を除くと 3,788 バイト・3,493 字。判定の後の直し（下の §2.1 の (d)・(e)）の前は 3,704 バイト、1.4.2 の文は 3,665 バイト）。替えたのは「What is new in 1.4.2」の段（3 つ）→「What is new in 1.4.3」の段（4 つ）と、日本語の要約の 1.4.2 の文だけ。ほかの段と、要約の最後の「データ・購入・年齢区分は同じ。規約類は日本語が正本で、英語は参考訳。サインイン不要。」は 1 バイトも替えていない（機械で照らした）。4,000 バイトまで 211 バイト残る。
- 新しい段（英語）:
  1. Month and year pages now join sideways with the pages before and after, as week and day pages have since 1.3. On a month page, handwriting can cross from one month to the next in the notes area below the calendar; on a year page, from December into January of the next year. Settings > Pages turns it off for all page types.
  2. The 1× button (a magnifying glass with "1") now fits one month or one year page to the screen width, as it does for days and weeks.
  3. To check: open a month page, drag left slowly with one finger (two fingers when "Use Finger" is on, the default on iPhone) until the boundary between two months is in the middle of the screen, and write across it in the notes area.
  4. Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating.
- 日本語の要約の新しい文: 「月と年のページも前後と横につながり、境目をまたいで書けます（月は下のメモ欄、年は 12 月から次の年の 1 月へ。設定 › ページ で切り替え）。等倍のボタンは、月と年でも 1 ページの幅を画面の幅ちょうどにします。」

### 2.1 契約 §13.4 の英語から替えた所（5 つ。(d)・(e) は判定の後）

| 所 | 契約の字 | 入れた字 | 理由 |
| --- | --- | --- | --- |
| (a) 2 | a magnifier with "1" | a magnifying glass with "1" | SUPPORT.en の 1.4.1 からの語（“a magnifying glass with “1” (Reset Zoom)”）と、1.4.1 の審査メモの形にそろえた。同じ物を 2 つの語で呼ばない（GLOSSARY §7） |
| (b) 3 | (two fingers on iPhone when "Use Finger" is on) | (two fingers when "Use Finger" is on, the default on iPhone) | 2 本指になるかは端末ではなく「指でも書く」のオンで決まる（iPad でもオンなら 2 本指。契約 §0.1・§7.2。案内の札も `SpanGuideView` が指のスイッチで選ぶ）。契約の字だと、iPad でオンのときに指 1 本で動くと読める |
| (c) 3・4 | 3 の最後に「Stroke data is unchanged; App Privacy stays "Data Not Collected".」 | 3 は確かめ方だけにし、1.4.2 の 3「Unchanged: data (App Privacy stays "Data Not Collected"), handwriting storage, purchases and the age rating.」を 4 として 1 字も替えずに残した | 中身は同じで、日本語の要約が言う購入と年齢区分も入る。前に判定を受けた字（REVIEW の 14・16.y・18）で、新しい英文を減らせる |
| (d) 3 | open a month page and swipe left with one finger (…), then write across the boundary in the notes area | open a month page, drag left slowly with one finger (…) until the boundary between two months is in the middle of the screen, and write across it in the notes area | 判定の J2（R の気づき 4）。速くはじくと、1 ページが画面の幅に入るとき（縦の iPad の月 V 1.00・縦の iPhone）は `SpanPlan.flingTarget` がとなりの月を画面の真ん中に止めるので、月の境目が画面の端に来て、審査の人がまたいで書く所を見つけにくい。ゆっくり動かして離すと、そこで止まる（ページの端が画面の端から 6 % の内のときだけ端にそろう。境目が真ん中ならそろわない）。+66 バイト |
| (e) 1 | Settings > Pages turns it off. | Settings > Pages turns it off for all page types. | 判定の J4・T6（nit、R の気づき 4）。「it」がどこまでかを言う。スイッチ（Join Neighboring Pages Sideways）は週・日・月・年に 1 つで、オフにすると全部の種類が 1 ページずつになる（`settings.page.span.footer` の en「When this is off, pages are shown one at a time」）。+19 バイト |

- 英語のアプリの語（"Use Finger"・Settings > Pages・the notes area）は、アプリの en の今の訳（`toolbar.fingerToggle`・`settings.page.header`・`toast.growthCap`）と同じ字。メモ欄は、審査の人が札を見ずに読むので、契約の字 the notes area below the calendar のまま（店の文と札は at the bottom。GLOSSARY §7）。引用符は 1.4.2 と同じ ASCII。
- 0e-28 の教訓（「新しい文は設定と読み上げだけ」のような文を書かない）どおり、新しい文の場所は書いていない（案内の札・月の札・年の札・設定の脚注の字が画面に出る）。

## 3. 設定の脚注の語（アプリの文。案だけ）

`settings.page.span.footer` の新しい ja（契約 §13.1、0g-34）は本人が承認した固定の文の替えで、アプリの文の段（12/5 の後に、落とし所を決めてから X が ja と 9 言語を 1 つの commit で入れ、続けて S が R0f）で入れる。**今はアプリのファイルに触れていない**（ほかの作る人がアプリの文を直している間のため）。下は、そのときに使う語の案（GLOSSARY §7 の 9 行目）。替わるのは 1 つ目の文と、消える 2 つ目の文（「月と年は、次の版から順に対応します。」）だけで、3 つ目と 4 つ目の文の訳は今のまま。

- 新しい ja（契約の案）: 週・日・月・年のページで、前後のページが横につながり、境目をまたいで書けます（月のページでは、下のメモ欄でまたげます）。オフにすると、…（今のまま）
- 1 つ目の文の訳の案:
  - en: On week, day, month and year pages, the previous and next pages are joined sideways, and you can write across the boundary (on month pages, in the notes area at the bottom).
  - zh-Hans: 在周、日、月、年页面上，前后页面会横向相连，可以跨过交界处书写（在月页面上，可在下方的备忘栏中跨过）。
  - zh-Hant: 在週、日、月、年頁面上，前後頁面會橫向相連，可以跨越交界處書寫（在月頁面上，可在下方的備忘欄中跨越）。
  - ko: 주·일·월·연 페이지에서 앞뒤 페이지가 가로로 이어져서, 경계를 넘어 쓸 수 있어요(월 페이지에서는 아래쪽 메모 칸에서 넘어 쓸 수 있어요).
  - fr: Sur les pages de la semaine, du jour, du mois et de l’année, les pages précédente et suivante sont reliées côte à côte, et vous pouvez écrire à cheval sur la jonction (sur les pages du mois, dans la zone de notes du bas).
  - de: Auf Wochen-, Tages-, Monats- und Jahresseiten werden die vorherige und die nächste Seite seitlich verbunden, und Sie können über den Übergang hinweg schreiben (auf Monatsseiten im Notizbereich unten).
  - it: Nelle pagine della settimana, del giorno, del mese e dell’anno, le pagine precedente e successiva sono unite in orizzontale e può scrivere a cavallo del confine (nelle pagine del mese, nell’area delle note in basso).
  - es: En las páginas de la semana, del día, del mes y del año, las páginas anterior y siguiente se unen en horizontal y puede escribir cruzando la unión (en las páginas del mes, en la zona de notas de abajo).
  - pt-BR: Nas páginas da semana, do dia, do mês e do ano, as páginas anterior e seguinte ficam unidas na horizontal, e você pode escrever atravessando a emenda (nas páginas do mês, na área de notas na parte de baixo).
- 年が遅れたときの ja（契約 §13.1）: 「週・日・月のページで、…（月のページでは、下のメモ欄でまたげます）。年は、次の版で対応します。オフにすると、…」。その訳は、そのときに 1 通りだけ書く。

## 4. 年が 1.4.4 に遅れたとき（契約 0g-3）に替える文

12/5 に年を 1.4.4 へ送ると決めたら、リードが次の文を月だけの文に替える（このファイルの字は目安。替えた文は元を見ない逆翻訳と判定をやり直す）。

| 所 | 替える文 | 目安 |
| --- | --- | --- |
| `ja/whatsnew.txt`・`source-ja/whatsnew.txt` | 1 つ目と 2 つ目の点（3 つ目の点と訳についての 1 行はそのまま） | 契約 §13.3 の「月のページも…」「月の等倍も…」 |
| 11 のフォルダの `whatsnew.txt` | 1 つ目と 2 つ目の点（en-GB・en-AU・en-CA・fr-CA は写しなので同じに替わる） | 1 つ目の点から年の語（となりの年・12 月から次の年の 1 月へ）を外す。2 つ目の点の「月と年」を「月」に |
| `review-note.txt` | 「What is new in 1.4.3」の 1・2 と、日本語の要約の 1 つ目と 2 つ目の文 | 下の英語と要約で 3,797 バイト（判定の後の直しの後の 3 と合わせて、機械で組み立てて数えた。直す前は 3,712。4,000 に入る） |
| [GLOSSARY.md](../i18n/GLOSSARY.md) | ファイルの頭の段落の「日・週・月・年とも」（判定の T8）、§5 の等倍の定義（「日・週・月・年」→「日・週・月」）と「合わせる」の理由の 3、§7 の頭（年の行 2・4・10・14、5 行目の注の「年の札」、「決めたこと」の年の 2 つの点は使わない。判定の J8） | 節の頭に書いた読み替え |
| `docs/store/README.md` | 新機能の文の表の 1.4.3 の行と、審査メモの「1.4.3 から」の段 | 字数とバイトを数え直す |
| `locales.json` | ja の `whatsnewSource` | 「月だけの文に替えた」と書く |
| このファイル | §1.2 の年の語、§1.3 の字数、§2 | 数え直す |
| ほかの役の文（記録だけ） | 設定の脚注（§3）、SUPPORT 日英（W、契約 §13.5。判定の後に足した拡大・縮小の FAQ の 1 段落目の括弧「iPhone を横にしたときの年のページのように…」の例も替わる。[REVIEW.md](../i18n/REVIEW.md) の 20）、案内の札の年の 2 キー（使わない） | — |

審査メモの月だけの目安（英語の 1・2）:

1. Month pages now join sideways with the pages before and after, as week and day pages have since 1.3: handwriting can cross from one month to the next in the notes area below the calendar. Year pages stay one page at a time. Settings > Pages turns it off for all page types.
2. The 1× button (a magnifying glass with "1") now fits one month page to the screen width, as it does for days and weeks; year pages still go back to the size they open at.

日本語の要約の月だけの目安: 「月のページも前後と横につながり、下のメモ欄で月の境目をまたいで書けます（年は 1 ページずつのまま。設定 › ページ で切り替え）。等倍のボタンは、月でも 1 ページの幅を画面の幅ちょうどにします（年は開いたときの大きさ）。」

## 5. 確かめたことと、まだのこと

**機械で照らしたこと（X、2026-11-28）**:

- ja と source-ja の 3 つの点は、契約 §13.3 の `>` の行と 1 字も同じ。3 つ目の点は 1.3 の ja の最後の点と同じ。
- 11 のフォルダ: 3 つの点 → 空の行 → 訳についての 1 行の形。「指でも書く」は各言語のアプリの `toolbar.fingerToggle` の字がその言語の引用符の中にある（11/11）。古い名前（Draw with Finger・Mit Finger zeichnen・Dibujar con el dedo・Traçar com o dedo）は 0 件。3 つ目の点は 1.3 の訳と同じ（11/11）。訳についての 1 行は 1.4.2 と同じ（11/11）。
- `tools/l10n/lint.py --only L-9`: ok（12 のロケール、URL は英語の側）。価格の記号と Apple の商標の決まりにかかる字は足していない（新機能の文の iPad・iPhone は 1.3 からの K-8 の点の製品の名前）。
- 審査メモ: 1.4.2 の段と要約の 1.4.2 の文のほかは、1.4.2 のファイルと行ごとに同じ。4 は 1.4.2 の 3 と番号のほかは同じ。

**まだのこと**:

- **元を見ない逆翻訳と判定は済んだ**（2026-11-28、[REVIEW.md](../i18n/REVIEW.md) の 20）。R の逆翻訳（`docs/i18n/back/store-1_4_3.md`・`store-1_4_3-en.md`）と判定の 2 役（J・T）で、× の指摘は 0。should の 4 つ（J1・T1 の等倍のボタンの en、J2 の確かめ方、J3・T3 の拡大・縮小の FAQ、T2 の SUPPORT.en の設定の名前）と、nit のうち J4・T6 (b)（同じ所）・J8・J9・T5・T8 を直し、替えた文は 2 回目の逆翻訳と判定で ○。新機能の文の 10 の訳は替えていない。
- GLOSSARY §7 の語（とくに ko の 해、fr の jonction、pt の emenda、場所の語の de unten・it in basso・es de abajo・pt na parte de baixo）は、判定で × が出なかった（母語の人の確認ではない）。11 行目の en だけ直した（上の J1・T1）。
- 確認ページで本人に見せる（16 ロケール・審査メモ・設定の脚注の 10 の言葉）。
