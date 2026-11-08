# 1.2.2 の App Store の文 — 新機能の文・審査メモ・プロモーションテキスト

- 版: 1.2.2（[R1_2_2.md](R1_2_2.md)）。Connect の版 1.2.2 はまだありません（1.2.1 の公開の後に作る。R1_2_2.md §9 の 7）。作業ブランチ `r122`。
- この文書が受け持つのは、R1_2_2.md §7 の **新機能の文**（16 ロケール。§1）・**審査メモ**（§2）・**プロモーションテキスト**（§3）です。キーワード・説明・名前・サブタイトル・URL は 1.2.1 のまま変えません（R1_2_2.md §7.3）。
- **Connect にはまだ何も入れていません。** 本人が R1_2_2.md §8 の 6（③ 新機能の文、④ 審査メモの日本語の意味）に「このまま入れてよい」と言った後に、Claude が入れます（R1_2_2.md §9 の 7）。
- 原稿は `docs/store/`（[README](store/README.md)）。数え方は README と同じで、ファイルの末尾の改行 1 つを除いて数えます。

## 1. 新機能の文（1.2.2、16 ロケール）

ja が元です。ja 以外は `source-ja/whatsnew.txt`（ja と同じ 1 つの点に、訳についての 1 行を足したもの）を訳しました。決まりは R1_2_1_STORE.md §4 と同じです。

- 訳についての 1 行は、どのロケールも 1.2.1 の新機能の文の最後の行と 1 字も違いません（ファイルから写した）。
- en-GB・en-AU・en-CA は en-US の写し、fr-CA は fr-FR の写し（フォルダは作らない。`locales.json` の `copyOf`）。
- 年齢の画面は Apple の画面なので、アプリの中の名前を引用符で囲む所はありません。pt-PT は、アプリの中の名前が出てこないので、ほかの文と同じくポルトガルの語で書きました（1.2.1 の pt-PT と同じ）。
- 「日本では出ません」とは書きません（旗を立てる地域は Apple が決め、将来変わりうるため。R1_2_2.md §7.1）。
- 2 つ目の点「・細かな改善をしました。」は入れません（1.2.2 で利用者に見える変更は年齢の画面だけで、アイコンも変わらないため。R1_2_2.md §1・§7.1）。
- 「年齢の区分」にあたる語は、各言語でふつうに使う語にしました（en age range、zh-Hans 年龄范围、zh-Hant 年齡範圍、ko 연령 범위、fr tranche d’âge、de Altersbereich、it fascia d’età、pt faixa etária、es rango de edad）。iOS・iPadOS の設定の画面がその言語で何と呼ぶかは確かめていません【未確認】。
- 訳し戻しは、訳した担当（Claude）が自分で日本語に戻したものです。1.2 のような、別の人による逆翻訳ではありません。

### ja（107 字）

```text
・米国の一部の州など、法律で年齢の確認が求められる地域では、アプリを開いたときに、年齢の区分を共有するかを尋ねる Apple の画面が出ることがあります。答えは保存も送信もせず、アプリの表示や使い方は変わりません。
```

### source-ja（ja 以外の元。入力しない。152 字）

```text
・米国の一部の州など、法律で年齢の確認が求められる地域では、アプリを開いたときに、年齢の区分を共有するかを尋ねる Apple の画面が出ることがあります。答えは保存も送信もせず、アプリの表示や使い方は変わりません。

訳は AI が作り、まだ母語の人の確認を受けていません。誤りがあればお知らせください。
```

### 各ロケール

最後の訳についての 1 行は 1.2.1 と同じなので、表には点の文だけを書きます（訳し戻しも点の文だけ）。

| ロケール | 字数 | 点の文 | 日本語に訳し戻すと |
| --- | --- | --- | --- |
| en-US（en-GB・en-AU・en-CA も同じ） | 367 | • In regions where the law requires age checks, such as some U.S. states, an Apple screen asking whether to share your age range may appear when you open the app. The app does not save or send your answer, and the way it looks and works does not change. | ・米国の一部の州など、法律が年齢の確認を求める地域では、アプリを開いたときに、年齢の範囲を共有するかを尋ねる Apple の画面が出ることがあります。アプリはあなたの答えを保存も送信もせず、見た目と動きは変わりません。 |
| zh-Hans | 122 | • 在美国部分州等法律要求确认年龄的地区，打开 App 时可能会出现 Apple 的界面，询问是否共享年龄范围。App 不会保存或发送回答，App 的显示和使用方式也不会改变。 | ・米国の一部の州など、法律が年齢の確認を求める地域では、App を開いたときに Apple の画面が出て、年齢の範囲を共有するかを尋ねることがあります。App は答えを保存も送信もせず、App の表示と使い方も変わりません。 |
| zh-Hant | 122 | • 在美國部分州等法律要求確認年齡的地區，開啟 App 時可能會出現 Apple 的畫面，詢問是否分享年齡範圍。App 不會儲存或傳送回答，App 的顯示和使用方式也不會改變。 | ・米国の一部の州など、法律が年齢の確認を求める地域では、App を開いたときに Apple の画面が出て、年齢の範囲を共有するかを尋ねることがあります。App は答えを保存も送信もせず、App の表示と使い方も変わりません。 |
| ko | 174 | • 미국의 일부 주처럼 법으로 연령 확인을 요구하는 지역에서는 앱을 열 때 연령 범위를 공유할지 묻는 Apple 화면이 나타날 수 있어요. 앱은 답변을 저장하거나 전송하지 않으며, 앱의 화면과 사용 방법은 바뀌지 않아요. | ・米国の一部の州のように法律で年齢の確認を求める地域では、アプリを開くときに、年齢の範囲を共有するかを尋ねる Apple の画面が出ることがあります。アプリは答えを保存も送信もせず、アプリの画面と使い方は変わりません。 |
| fr-FR（fr-CA も同じ） | 446 | • Dans les régions où la loi exige une vérification de l’âge, comme certains États américains, un écran d’Apple vous demandant si vous voulez partager votre tranche d’âge peut apparaître quand vous ouvrez l’app. L’app n’enregistre ni n’envoie votre réponse, et son affichage comme son fonctionnement restent les mêmes. | ・法律が年齢の確認を求める地域（米国の一部の州など）では、アプリを開くときに、年齢の区分を共有したいかを尋ねる Apple の画面が出ることがあります。アプリはあなたの答えを保存も送信もせず、表示も動きも同じままです。 |
| de-DE | 446 | • In Regionen, in denen das Gesetz eine Altersprüfung verlangt, etwa in einigen US-Bundesstaaten, kann beim Öffnen der App ein Bildschirm von Apple erscheinen, der fragt, ob Sie Ihren Altersbereich teilen möchten. Die App speichert Ihre Antwort nicht und sendet sie nicht, und Aussehen und Bedienung der App ändern sich nicht. | ・法律が年齢の確認を求める地域（例えば米国のいくつかの州）では、アプリを開くときに、あなたの年齢の範囲を共有したいかを尋ねる Apple の画面が出ることがあります。アプリはあなたの答えを保存せず、送信もせず、アプリの見た目と操作は変わりません。 |
| it | 425 | • Nelle regioni in cui la legge richiede la verifica dell’età, come alcuni stati degli Stati Uniti, all’apertura dell’app può comparire una schermata di Apple che chiede se condividere la Sua fascia d’età. L’app non salva né invia la risposta, e l’aspetto e il funzionamento dell’app non cambiano. | ・法律が年齢の確認を求める地域（米国のいくつかの州など）では、アプリを開いたときに、あなたの年齢層を共有するかを尋ねる Apple の画面が出ることがあります。アプリは答えを保存も送信もせず、アプリの見た目と働きは変わりません。 |
| pt-BR | 380 | • Em regiões onde a lei exige a verificação de idade, como alguns estados dos EUA, uma tela da Apple perguntando se você quer compartilhar sua faixa etária pode aparecer quando você abre o app. O app não salva nem envia sua resposta, e a aparência e o uso do app não mudam. | ・法律が年齢の確認を求める地域（米国のいくつかの州など）では、アプリを開くときに、あなたの年齢層を共有したいかを尋ねる Apple の画面が出ることがあります。アプリはあなたの答えを保存も送信もせず、アプリの見た目と使い方は変わりません。 |
| pt-PT | 401 | • Em regiões onde a lei exige a verificação da idade, como alguns estados dos EUA, pode aparecer um ecrã da Apple a perguntar se pretende partilhar a sua faixa etária quando abre a aplicação. A aplicação não guarda nem envia a sua resposta, e o aspeto e o funcionamento da aplicação não mudam. | ・法律が年齢の確認を求める地域（米国のいくつかの州など）では、アプリを開くときに、あなたの年齢層を共有したいかを尋ねる Apple の画面が出ることがあります。アプリはあなたの答えを保存も送信もせず、アプリの見た目と働きは変わりません。 |
| es-MX | 391 | • En regiones donde la ley exige verificar la edad, como algunos estados de EE. UU., al abrir la app puede aparecer una pantalla de Apple que pregunta si desea compartir su rango de edad. La app no guarda ni envía su respuesta, y la apariencia y el uso de la app no cambian. | ・法律が年齢の確認を求める地域（米国のいくつかの州など）では、アプリを開くときに、あなたの年齢の範囲を共有したいかを尋ねる Apple の画面が出ることがあります。アプリはあなたの答えを保存も送信もせず、アプリの見た目と使い方は変わりません。 |
| es-ES | 392 | （es-MX と同じ点の文） | （es-MX と同じ。最後の 1 行は 1.2.1 の es-ES の文のまま） |

字数は訳についての 1 行を含めた数で、Connect の上限 4,000 字の 1 割強までです。価格・通貨の記号は入れていません（L-9）。

## 2. 審査メモ（`docs/store/review-note.txt`）

R1_2_2.md §7.2 のとおり、1.2.1 の文の「What is new in 1.2.1」の段（3 つの点）を「What is new in 1.2.2」の段（2 つの点）に入れ替え、最後の日本語の要約も入れ替えました。ほかの段（サインイン不要・言語・確かめ方・購読・記録・サーバー無し・6 つの URL）は 1 字も変えていません。

- 大きさ: **3,406 字・3,670 バイト**（上限 4,000 バイト。R1_2_2.md §7.2 の見込みと同じ。lint の L-9 が見る）。
- "The privacy policy says so in Section 7." は、プライバシーポリシーに 1 項目足す既定（R1_2_2.md §5.2）によります。本人が「足さない」と言ったとき、または Web を提出より前に出すのを望まないときは、この 1 文を消して数え直します（R1_2_2.md §5.2）。
- 英語の段の日本語の意味と日本語の要約は R1_2_2.md §7.2 にあります（本人の §8 の 6 の ④ で見ていただく所）。

## 3. プロモーションテキスト

`docs/store/<ロケール>/promo.txt`（16 ロケール）は変えていません（1.2・1.2.1 と同じ文）。Connect の版 1.2.2 を作ったときに空になっていたら、この文（＝公開中の 1.2.1 と同じ文）を入れ直します（R1_2_2.md §7.3）。

## 4. Connect に入れるとき（R1_2_2.md §9 の 7）

| 欄 | ロケール | 値 |
| --- | --- | --- |
| 新機能の文 | 16 すべて | 各 `whatsnew.txt`（en-GB・en-AU・en-CA は en-US、fr-CA は fr-FR の値） |
| プロモーションテキスト | 16 すべて | 各 `promo.txt`（空なら入れる。§3） |
| 審査メモ | — | `docs/store/review-note.txt`（§2） |
| キーワード・説明・名前・サブタイトル・URL | — | 変えない。版を作った後に読み、1.2.1 と同じに写っていることを確かめる |

入れた後は読み戻して、原稿と 1 字も違わないことを確かめます（1.2.1 と同じ形）。

## 5. 確かめ

結果は R1_2_2.md §12.2 に書きました（`python3 -I tools/l10n/lint.py .` の L-9 を含む）。
