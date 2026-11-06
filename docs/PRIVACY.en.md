# Tegaki Privacy Policy (App)

This is a translation for convenience. The Japanese version prevails.

[日本語版（正本）](PRIVACY.md)

**Summary**: “Tegaki”, the app for iPad and iPhone, collects **no information** about you. There is no developer server, no account registration, and no advertising or analytics. Your handwriting and settings are saved only on your device (iPad or iPhone) and in your own iCloud, and the developer cannot see them. The App reads and writes events through the Calendar on your device, but that data is never sent outside the App. Apple handles payments, and the developer does not receive card details. Section 12 explains what happens when you email support.

Related documents: [Terms of Service](TERMS.en.md) / [Support](SUPPORT.en.md)

Last updated: November 6, 2026

---

## 1. Information the App collects: none

- The App collects none of your name, email address, location, device identifiers, records of how you use it, or similar information.
- There is no developer server. The App communicates only with Apple's iCloud (your own storage space) and Apple's App Store (to check purchases).
- The holiday data is built into the App, and the App does not go online to show holidays.
- To learn about changes in iCloud, the App uses Apple's push notification system (silent notifications), but nothing appears on the screen, and the notifications contain no content.
- There are no ads. There is no analytics or tracking either. No SDKs (software components) from other companies are used.
- There is no account registration or login.

## 2. Where data is saved: your device and your iCloud

| Data | Where it is saved | Can the developer see it? |
| --- | --- | --- |
| Handwriting (stroke data) | On the device, and in iCloud (private database) | No |
| Settings (pen color, calendars to show, and so on) | On the device | No |
| Saved copy of events (temporary, to show them faster) | On the device | No |
| Subscription status | Managed by Apple. The App receives from Apple only whether it is active and when it expires | No |
| Saved copy of the subscription status (the last checked status and its time) | On the device (UserDefaults) | No |

- **iCloud (private database)** is a storage space that Apple provides only for your Apple Account. According to Apple, data put there is not shown in the developer's dashboard, and it counts toward your iCloud storage. When you are not signed in to iCloud, data is saved only on the device.
- The developer does not receive your handwriting or events and cannot view, restore or delete them.

## 3. Why the App asks for full access to your calendars

In the guide shown when you first use the App, tapping the button that shows the permission screen makes iOS or iPadOS ask whether to allow full access to your calendars (the App never shows this request on its own).

- **Why full access**: iOS and iPadOS have no permission for only reading events. Even just to show events on the screen, Apple's system requires “Full Access”.
- **What it is used for**:
  - to show events on the day, week, month and year pages
  - to save events you create from handwriting to the calendar you choose
  - to apply the changes you make when you edit or delete events
- **What it is not used for**: The App never sends the contents of events outside the device (to the developer or anyone else). It never creates or changes events on its own while you are not using it.
- **About Google Calendar**: The App does not connect to Google. iOS or iPadOS syncs the Google account you added in the Settings app on your device, and the App reads the result from the Calendar on your device. How Google handles your data is governed by Google's privacy policy.
- **Turning permission off**: You can change it at any time in Settings > Privacy & Security > Calendars > Tegaki. If you turn it off, events are not shown, but handwriting still works.

## 4. Handwriting and Apple Pencil

- Handwriting is saved as “stroke coordinates”. It is never read as text and analyzed, or sent anywhere.
- When you write with Apple Pencil in the title field of an event and it turns into text, this is done by the Scribble feature of iPadOS, on the device.
- For double-tap and squeeze on Apple Pencil, the App reads the settings in Settings > Apple Pencil and follows them. This is also processed only on the device.
- The files you create with “Export Handwriting” in the App's settings (JSON and PDF) go only to the place you choose in the share sheet (the Files app, AirDrop, Mail and so on). They are not sent to the developer. The data file (JSON) contains the strokes of your handwriting and marks that tell which device wrote them (random identifiers for this App; not device names or serial numbers).

## 5. Purchases and fees

- Apple handles purchasing, billing, cancellation and refunds of subscriptions. The developer does not receive your card number or billing address.
- What the developer receives from Apple is only sales totals in a form that cannot identify individuals.
- Apple decides whether you can use the free trial (whether you have tried it before), and the App is told only whether you are eligible.

## 6. Sharing the App's data with third parties: none

- The developer does not give the App's data (your handwriting, events and settings) to anyone (the developer does not have it in the first place). Emails to support are covered in Section 12.
- Apple's iCloud and App Store work under your agreement with Apple. They follow Apple's privacy policy (<https://www.apple.com/legal/privacy/>).

## 7. Information that may reach the developer through Apple

- If you have turned on “Share With App Developers” in Settings > Privacy & Security > Analytics & Improvements, Apple may collect information about the App closing unexpectedly (crash logs) and show it to the developer in a form that does not identify you. This is Apple's system, and you can turn it off.
- App Store reviews and ratings are published through Apple's system. The App does not collect them.

## 8. Use by children

The App is not made for children, and it is not listed in the categories for children. Whatever your age, the App does not collect personal information.

## 9. Deleting data

- “Erase All Handwriting on This Device” in the App's settings erases your handwriting from both the device and iCloud.
- Deleting the App removes the data on the device. The iCloud data can be deleted in Settings > your name (your Apple Account; called Apple ID on iOS and iPadOS 17) > iCloud > Manage Account Storage > Tegaki.
- Events you created in the App remain as ordinary calendar events. To delete them, delete them in the Calendar app or in Google Calendar.
- The detailed steps are on the [support page](SUPPORT.en.md#how-do-i-delete-all-my-data). The App's data does not reach the developer, so there is no need to ask the developer to delete it. If you want an email you sent to support deleted, please write to the email address in Section 11 (see Sections 12 and 13).

## 10. Changes to this policy

For major changes, such as a change in the kinds of information collected, the developer will announce them in the App and on the [support page](SUPPORT.en.md) before they take effect. For small fixes in wording, the developer may only update the “Last updated” date on this page.

## 11. Contact

- Developer: Masataka Ikeda (池田 雅高), an individual
- Email: syfan0@gmail.com
- Support page: [Support](SUPPORT.en.md) (<https://syfan0-star.github.io/tegaki-calendar/app/en/support.html>)

## 12. Emails to support, and opening these pages

- When you email support, the developer receives your email address, any name you write, the text of your email and any attachments (such as screenshots). This is not information that the App collects. The developer uses it only to answer your question.
- Emails are stored in Google's Gmail. To read emails and to write replies, the developer may pass the text of your email and its attachments to an AI service (Claude, by Anthropic).
- Emails are kept only as long as they are needed to deal with your question, and are deleted when they are no longer needed.
- The Terms of Service, Privacy Policy and Support pages are published on GitHub Pages. When you open a page, GitHub records your IP address for security. The developer cannot see this record. The pages use no cookies or analytics.

## 13. If you live in the EU (European Union), Iceland, Norway, the UK or Switzerland

- For the email information in Section 12, the controller (the person who decides how it is used) is the developer. The contact details are in Section 11.
- The legal basis for using this information is the legitimate interest in answering your question (GDPR Article 6(1)(f)).
- You have the right to see your information, have it corrected or deleted, have its use restricted, receive a copy of it, and object to its use. Please write to the email address in Section 11.
- You can make a complaint to the data protection authority of your country.
- The developer is in Japan. Your email information is handled in Japan and in the countries where Google and Anthropic handle information. For Japan, there is an adequacy decision by the European Commission. This decision does not cover the countries where Google and Anthropic handle information.
- Sending an email is up to you. You can use the App without sending one. If you do not send one, we simply cannot answer your question.
- This information is not used for automated decisions or profiling.
- Your handwriting, events and settings in the App do not reach the developer, so the developer cannot show or delete them. Section 9 explains how to delete them.
- Apple decides how information is handled in iCloud and the App Store. Please see Apple's privacy policy (https://www.apple.com/legal/privacy/).

---

## Appendix A. Differences from the web version

The web version “手書きカレンダー”, which runs in a browser, signed in to Google and connected directly to Google Calendar and Google Drive (privacy policy of the web version, in Japanese: <https://syfan0-star.github.io/tegaki-calendar/privacy.html>). The app version neither signs in to Google nor saves anything to Google Drive. Google Calendar events come through iOS and iPadOS, and handwriting is saved in iCloud.

## Appendix B. Answers for App Privacy (the “Privacy” section of the App Store)

In App Store Connect, developers declare the types of data an app collects (the “privacy label”). The App's answers are as follows.

| Question in App Store Connect | Answer | Reason |
| --- | --- | --- |
| Does this app (or its third-party partners) collect data? | **No** | There is no developer server, and no way to receive data |
| Label shown as a result | **“Data Not Collected”** | |
| Does the app track users? | **No** | No advertising or analytics SDKs |
| Privacy policy URL | <https://syfan0-star.github.io/tegaki-calendar/app/privacy.html> | Required under guideline 5.1.1 |

- **How we see it**: In Apple's definition, “collecting” means sending data off the device so that the developer or third parties can use it later. In the App, events are only read from and written to the Calendar on the device, and handwriting is only saved in the user's own iCloud (an area the developer cannot access), so we consider that this is not “collecting”.
- **Proposed explanation if App Review asks**: “This app has no server. Calendar data is used with EventKit only to show and edit the events on the device, and it is not sent off the device. Handwriting data is saved in the user's own iCloud private database, which the developer cannot access. The app contains no analytics, ads or third-party SDKs.”
- **Calendar permission text** (the text iOS and iPadOS show when asking for permission; on devices in other languages, a translation of it is shown): 「カレンダーの予定を手帳のページに表示し、手書きから予定を作るために使います。iOS と iPadOS には読み取りだけの許可が無いため、フルアクセスをお願いしています。予定はこの端末の中だけで扱い、外部には送りません。」 It means: “This is used to show the events in your calendars on the planner pages and to create events from handwriting. iOS and iPadOS have no permission for only reading, so the App asks for full access. Events are handled only on this device and are not sent outside.”

---

How this document was made: The developer wrote the Japanese version based on text prepared with AI, and checked its contents. This English translation was made with AI and checked by translating it back into Japanese. No native English speaker has reviewed it.
