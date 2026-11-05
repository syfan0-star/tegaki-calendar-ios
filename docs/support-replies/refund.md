# 返金してほしい（refund）

使う場面: 返金を求められたとき。開発者は返金できない（App Store の購入は Apple が扱い、返金も Apple が決める。利用規約 第 5 条 3 項）。理由がアプリの不具合なら、不具合の段落を足して、何が起きたかを聞く。相手が EU（欧州連合）にいるなら EU の段落を足し、ドイツならもう 1 文足す。

## English

```text
Hello {name},

Thank you for your message about Tegaki, and I am sorry for the trouble.

I am not able to give refunds myself. Purchases in the App Store are handled by Apple, and Apple decides on refunds. You can request a refund from Apple here:

https://reportaproblem.apple.com/

Sign in with the Apple Account you used for the purchase, choose the option to request a refund, and follow the steps.

To stop future payments, please also cancel the subscription in the Settings app: tap your name, then Subscriptions, then the Tegaki subscription, and then Cancel Subscription.

This reply was written with the help of machine translation. If anything is unclear, please let me know.

Best regards,
Masataka Ikeda
Developer of Tegaki (てがきカレンダー)
```

理由が不具合のときに足す段落（「To stop future payments…」の段落の後）:

```text
If the reason is a problem in the app, could you tell me what happened? The model of your device, its iOS or iPadOS version and a screenshot would help. I would like to fix it.
```

相手が EU にいるときに足す段落（「Sign in with…」の段落の後）。相手の国が分からなくても、「If you live in the EU」で始まるので足してよい:

```text
If you live in the EU, you may also be able to withdraw from your first subscription within 14 days of receiving your receipt (this does not apply to each renewal). Apple handles this as well. The steps are in the Apple Media Services Terms and Conditions for your country: https://www.apple.com/legal/internet-services/itunes/ie/terms.html (this is the Irish version; choose your country under “Choose your country/region” on that page).
```

相手がドイツにいるときは、EU の段落に続けてもう 1 文。ドイツ向けの Apple の規約には、いつでも解約して残りの期間の分を返してもらう定めがある（アイルランド版・フランス版の同じ節には見当たらない。実際の手続きは確かめられなかったので、手順は書かず Apple のサポートへ。契約 §11.6、§11.9）:

```text
If you live in Germany, Apple's terms for Germany also cover ending a subscription early and a refund for the rest of the period, so please ask Apple Support.
```

## 日本語（逆翻訳）

```text
{name} 様

Tegaki についてのメッセージをありがとうございます。ご迷惑をおかけしてすみません。

私自身は返金をすることができません。App Store での購入は Apple が扱っていて、返金は Apple が決めます。返金は、次のページから Apple に申し込めます。

https://reportaproblem.apple.com/

購入に使った Apple Account でサインインし、返金を申し込む項目を選んで、手順に沿って進めてください。

この先の支払いを止めるには、「設定」アプリでサブスクリプションも解約してください。ご自分の名前、「サブスクリプション」、Tegaki のサブスクリプション、「サブスクリプションをキャンセル」の順に押します。

この返事は、機械翻訳の助けを借りて書いています。分かりにくいところがあれば、お知らせください。

よろしくお願いします。
池田 雅高
Tegaki（てがきカレンダー）の開発者
```

不具合の段落の逆翻訳:

```text
理由がアプリの不具合なら、何が起きたかを教えていただけますか。端末の機種、iOS か iPadOS のバージョン、画面の写真があると助かります。直したいと思います。
```

EU の段落の逆翻訳:

```text
EU にお住まいなら、領収書を受け取ってから 14 日以内は、最初のサブスクリプションを撤回できることもあります（更新のたびには使えません）。これも Apple が扱います。手順は、お住まいの国の Apple メディアサービス利用規約に書かれています。https://www.apple.com/legal/internet-services/itunes/ie/terms.html （これはアイルランド版です。そのページの “Choose your country/region” で国を選んでください）。
```

ドイツの 1 文の逆翻訳:

```text
ドイツにお住まいなら、ドイツ向けの Apple の規約には、サブスクリプションを期間の途中で終えることと、残りの期間の分の返金についての定めもあるので、Apple のサポートにお尋ねください。
```
