# 自分の情報を見せて・消して（privacy-request）

使う場面: 「自分の情報を見せてほしい」「消してほしい」と言われたとき（プライバシーポリシー 第 12 節・第 13 節）。EU（欧州連合）の人に限らず、誰から来ても同じように答える。

**届いた日から 1 か月以内に答える**（GDPR 第 12 条。専門家に確かめるとよい項目、契約 §11.6）。

## 何が対象か

開発者の手元にあるのは次の 3 つ。

| 物 | どこにあるか |
| --- | --- |
| メール（添付の画面の写真なども） | Gmail の受信と送信済み（ゴミ箱も） |
| 返事の下書き | Gmail の下書き |
| Claude に渡した会話の記録（本文と添付） | Claude の会話。Claude Code で渡したときは、この Mac の中の記録にも残る |

- 「持っているのはメールだけ」と書かない。返事の流れでは、本文が Claude との会話と下書きにも残るので、事実と違う。
- **消せたものだけ「消した」と書く。**
- アプリの手書き・予定・設定は開発者に届かないので、対象にならない（見せることも消すこともできない。消し方はプライバシーポリシーの第 9 節）。

## 本人の手順

消すのは本人（Claude は消さない）。

共通:

1. 依頼が、問い合わせをしたのと同じメールアドレスから来ているかを見る。違うアドレスからなら、見せる前に、元のアドレスから送ってもらう（別の人に渡さないため）。
2. 相手のアドレスと名前で、Gmail の受信・送信済み・下書き・ゴミ箱を探す。メールを読むときや返事を書くときに使った Claude の会話も探す（「このメールの本文を渡した会話を探して」と Claude に頼んでよい。この Mac の中の記録は、どれを消すかを本人が見て「消してよい」と言ってから消す）。
3. 次の版の直しの一覧などのメモに、相手の名前やアドレスを書いていないかも見る。

「見せて」のとき:

4. 下の「見せてほしいとき」の文に、持っている物を具体的に書き、メールの写しを貼るか添付する。

「消して」のとき（「見せて」の後に続けて頼まれたときも同じ）:

4. Gmail で該当のメールを削除し、ゴミ箱からも消す（受信と送信済みの両方。今回の依頼のメールは 7 で消す）。
5. 下書きを消す。Claude の該当の会話を消す。
6. 返事に、消した物を具体的に書く。消せなかった物は、消せなかったと書く。消していない物を「消した」と書かない。送るのは本人。
7. 返事を送った後で、今回の依頼のメール、送った返事、その下書き、返事を作るのに使った Claude の会話を消す（返事に「送った後で消す」と書いてあるので、忘れない）。

「直して」「使わないで」「写しがほしい」と言われたとき（第 13 節の権利）: 持っているのはメールの本文なので、写しは「見せて」の文で足りる。「使わないで」は「消して」を勧める。「直して」は、何を直すかを聞いて、本人が決める。

## English（見せてほしいとき）

```text
Hello {name},

Thank you for your message about Tegaki.

You asked to see the information I hold about you. I hold the following:

- your emails to me (with any attachments, such as screenshots) and my replies, stored in my Gmail: {dates of the emails}
- drafts of my replies, stored in my Gmail: {how many, or "none"}
- records of the conversations in which I passed the text of your emails, and any attachments, to an AI service (Claude, by Anthropic). They contain the same text and any translation of it.

A copy of the emails is below.

{the emails}

Your handwriting, events and settings in the app do not reach me, so I cannot show them to you.

If you would like me to delete this information, please let me know.

This reply was written with the help of machine translation. If anything is unclear, please let me know.

Best regards,
Masataka Ikeda
Developer of Tegaki (てがきカレンダー)
```

## 日本語（逆翻訳。見せてほしいとき）

```text
{name} 様

Tegaki についてのメッセージをありがとうございます。

私が持っているあなたの情報を見たいとのことでした。持っているのは次のものです。

- あなたから私へのメール（画面の写真などの添付があればそれも）と私の返事。私の Gmail に保存しています: {メールの日付}
- 私の返事の下書き。私の Gmail に保存しています: {いくつあるか、または「ありません」}
- あなたのメールの本文と添付を AI のサービス（Anthropic の Claude）に渡した会話の記録。同じ本文と、訳があればその訳が入っています。

メールの写しは下にあります。

{メール}

アプリの手書き、予定、設定は私に届かないので、お見せすることができません。

この情報を消してほしいときは、お知らせください。

この返事は、機械翻訳の助けを借りて書いています。分かりにくいところがあれば、お知らせください。

よろしくお願いします。
池田 雅高
Tegaki（てがきカレンダー）の開発者
```

## English（消してほしいとき）

`{ }` の点は、実際に消した物だけを残す。

```text
Hello {name},

Thank you for your message about Tegaki.

You asked me to delete the information I hold about you. I have deleted the following:

- {your emails to me (with any attachments) and my replies, from my Gmail and its trash}
- {the drafts of my replies, from my Gmail}
- {the records of the conversations in which I passed the text of your emails, and any attachments, to an AI service (Claude, by Anthropic)}

After I send this reply, I will also delete your latest email, this reply and the records used to write it.

Google and Anthropic run these services, and they may keep copies for some time under their own rules.

Your handwriting, events and settings in the app do not reach me, so I cannot show or delete them. Section 9 of the Privacy Policy explains how to delete them: https://syfan0-star.github.io/tegaki-calendar/app/en/privacy.html

Apple decides how information is handled in iCloud and the App Store. Please see Apple's privacy policy: https://www.apple.com/legal/privacy/

This reply was written with the help of machine translation. If anything is unclear, please let me know.

Best regards,
Masataka Ikeda
Developer of Tegaki (てがきカレンダー)
```

消せなかった物があるときに足す 1 文（3 つの点の後）:

```text
I could not delete {what}, because {why}.
```

## 日本語（逆翻訳。消してほしいとき）

```text
{name} 様

Tegaki についてのメッセージをありがとうございます。

私が持っているあなたの情報を消してほしいとのことでした。次のものを消しました。

- {あなたから私へのメール（添付があればそれも）と私の返事を、私の Gmail とそのゴミ箱から}
- {私の返事の下書きを、私の Gmail から}
- {あなたのメールの本文と添付を AI のサービス（Anthropic の Claude）に渡した会話の記録を}

この返事を送った後で、あなたの今回のメールと、この返事と、この返事を書くのに使った記録も消します。

これらのサービスは Google と Anthropic が運営していて、それぞれの決まりに沿って、写しをしばらく持っていることがあります。

アプリの手書き、予定、設定は私に届かないので、お見せすることも消すこともできません。消し方は、プライバシーポリシーの第 9 節に書いてあります。https://syfan0-star.github.io/tegaki-calendar/app/en/privacy.html

iCloud と App Store での情報の扱いは Apple が決めています。Apple のプライバシーポリシーをご覧ください。https://www.apple.com/legal/privacy/

この返事は、機械翻訳の助けを借りて書いています。分かりにくいところがあれば、お知らせください。

よろしくお願いします。
池田 雅高
Tegaki（てがきカレンダー）の開発者
```

足す 1 文の逆翻訳:

```text
{何を} は消せませんでした。{理由} ためです。
```

## 確かめていないこと

- Google と Anthropic の側で、消した後の写しがいつまで残るかは確かめていない。だから文は「しばらく持っていることがある」にして、期間を書かない（契約 §11.6 の 6）。
- この手順と文は法律の専門家に見てもらっていない（契約 §11.6、M7B-24。1.2 を出してから 1 年以内に 1 回聞く）。
