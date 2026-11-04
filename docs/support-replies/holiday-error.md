# 祝日が違う・出ない（holiday-error）

使う場面: 「祝日の日付が違う」「名前が違う」「州の祝日が出ない」などと言われたとき。日本の祝日はこのアプリの計算（JapaneseHolidays）、日本以外の祝日は python-holidays（Vacanza、MIT ライセンス。1.2 は 0.107）から作ってアプリに入れたデータ。データはアプリの更新でしか新しくならない（通信で取りに行かない）。

## 判断表（python-holidays に報告するか、次の版で直すか）

まず、相手の国・州（地域）・日付・期待した祝日の名前と、アプリの 設定 › 祝日 の行の値（「全国共通のみ」「発表前の推定」「データがありません」などの注記）を聞くか、確かめる。

| 知らせの中身 | 確かめること | どこの誤りか | 返事の型 | 直し方 |
| --- | --- | --- | --- | --- |
| 日本の祝日の日付・名前が違う | 内閣府の「国民の祝日について」のページと、アプリの JapaneseHolidays | アプリの計算 | A | 次の版で直す |
| 日本以外の祝日の日付・名前が違う（州・地域は正しく選んでいる） | 政府などの公式の発表と、python-holidays の最新のデータ（GitHub の公開のページを読む。新しい版の取り寄せはしない） | 最新のデータで直っていれば、アプリのデータが古い | A | 次の版で直す（新しい版を取り寄せてデータを作り直す。取り寄せは本人の了承を得てから、§5.11） |
| 〃（最新のデータでも同じ誤り） | 同上。公式の発表の出どころ（URL）を控える | python-holidays のデータ | B | python-holidays に報告する。直った版が出たら、次の版で入れる |
| 州・地域の祝日が出ない | 行の値が「全国共通のみ」（州・地域を選んでいない）か | 設定の選び方 | C-region | 直さない（選び方の案内だけ） |
| 「（推定）」の付いた祝日が 1 日ずれた | 月の見え方で決まる祝日か（旧暦・イスラム暦など） | データの性質（推定） | C-estimate | 直さない。公式の日が発表されていて、最新のデータでも違えば上の 2 行と同じ |
| 中国などの休み・振替出勤日が違う（行に「発表前の推定」） | その国の政府のその年の発表が、アプリのデータに入っているか | データがまだ発表の前 | C-notice | 毎年の更新（12 月ごろ、§5.11）で次の版に入れる |
| 任意の休み・銀行休業日・半日が出ない（例: ブラジルのカーニバル） | python-holidays でその日が標準（public）の祝日か | アプリの決め方（標準の祝日だけを出す） | C-type | 直さない |
| 祝日の名前の言語が違う・名前の訳がおかしい | データにその言語の名前があるか、契約 §5.5 の選び方のとおりか | 名前の訳なら python-holidays、選び方ならアプリ | B か A | 名前の訳は python-holidays に報告する。選び方の誤りは次の版で直す |
| 行に「祝日のデータがありません」「…年以降のデータがありません」 | その国のデータが無い（コソボなど）か、その年がデータの揃っている範囲の外か | データが無い | C-nodata | 直さない（python-holidays に入れば、次の版の更新で入る） |

- **python-holidays に報告する**: 英語で、GitHub の vacanza/holidays に issue を出す（国・州・年・日付・正しい内容と公式の出どころの URL）。公開の場に書くので、Claude が文と日本語訳を用意し、本人の「はい」を得てから出す。
- **次の版で直す**: リードが次の版の直しの一覧に記録する。直すかどうか・いつ直すかは本人が決める（返事では日付を約束しない）。

## English

挨拶と結び（どの型にも使う）:

```text
Hello {name},

Thank you for telling me about the holiday on {date} in {country or region}.

{one of the paragraphs below}

Changing the holiday settings does not move your handwriting.

This reply was written with the help of machine translation. If anything is unclear, please let me know.

Best regards,
Masataka Ikeda
Developer of Tegaki (てがきカレンダー)
```

A（次の版で直す）:

```text
I checked it, and you are right. I plan to correct it in a future update of the app. The holiday data is built into the app, so the correction will come with an app update.
```

B（python-holidays に報告する）:

```text
I checked it, and the holiday data that the app uses, from the open-source project python-holidays, has the same mistake. I will report it to the python-holidays project, and I plan to update the app's data after it is corrected there.
```

C-region（州・地域の選び方）:

```text
In {country}, some holidays are only for certain states or regions. In the app, open Settings > Holidays > Holidays to Show, choose {country}, and then choose your state or region. The holidays of that region are then added.
```

C-estimate（推定の祝日）:

```text
This holiday depends on the moon, as in the lunar calendar or the Islamic calendar, so its date in the app is an estimate and is marked "(est.)". The actual day can differ from the estimate. I am sorry for the confusion.
```

C-notice（政府の発表の前）:

```text
In {country}, the government announces the days off and the working weekends for each year. The app's data for {year} was made before that announcement, so the settings show that {year} is an estimate made before the announcement. I plan to update the data in a future update of the app after the announcement is included.
```

C-type（標準の祝日だけ）:

```text
The app shows only public holidays. Optional holidays, bank holidays and half days are not shown, so {holiday} does not appear in the app.
```

C-nodata（データが無い）:

```text
The holiday data that the app uses, from the open-source project python-holidays, does not have holidays for {country or region} {for that year}. I am sorry, but the app cannot show them now. If the data is added to python-holidays, it will come to the app with an update.
```

## 日本語（逆翻訳）

挨拶と結び:

```text
{name} 様

{国・地域} の {日付} の祝日について教えていただき、ありがとうございます。

{下の段落のどれか}

祝日の設定を変えても、手書きは動きません。

この返事は、機械翻訳の助けを借りて書いています。分かりにくいところがあれば、お知らせください。

よろしくお願いします。
池田 雅高
Tegaki（てがきカレンダー）の開発者
```

A:

```text
確かめたところ、おっしゃるとおりでした。アプリの今後の更新で直すつもりです。祝日のデータはアプリの中に入っているので、直したものはアプリの更新で届きます。
```

B:

```text
確かめたところ、アプリが使っている祝日のデータ（オープンソースの python-holidays というプロジェクトのもの）に同じ誤りがありました。python-holidays のプロジェクトに報告し、そちらで直った後に、アプリのデータを新しくするつもりです。
```

C-region:

```text
{国} では、一部の祝日は特定の州や地域だけのものです。アプリで 設定 › 祝日 › 表示する祝日 を開き、{国} を選んでから、お住まいの州か地域を選んでください。その地域の祝日が加わります。
```

C-estimate:

```text
この祝日は、旧暦やイスラム暦のように月で決まるので、アプリの日付は推定で、「(est.)」（推定）と付いています。実際の日は推定と違うことがあります。紛らわしくてすみません。
```

C-notice:

```text
{国} では、政府が毎年、休みの日と出勤になる週末を発表します。アプリの {年} 年のデータはその発表の前に作ったので、設定に {年} 年は発表前の推定だと出ています。発表がデータに入った後、アプリの今後の更新でデータを新しくするつもりです。
```

C-type:

```text
アプリが表示するのは標準の祝日だけです。任意の休み・銀行の休業日・半日の休みは出ないので、{祝日} はアプリに出ません。
```

C-nodata:

```text
アプリが使っている祝日のデータ（オープンソースの python-holidays というプロジェクトのもの）には、{国・地域} の（{その年の}）祝日がありません。すみませんが、今はアプリで表示できません。python-holidays にデータが入れば、アプリの更新で届きます。
```
