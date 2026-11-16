# Zentri on a real iPhone: build, install, set up, test

Zentri 1.0 needs **iOS 27.0 or later**. Nothing in this document has been run on a physical device
yet; the test cases in Part 4 are the first device pass.

## Part 1 — Build the IPA

An unsigned IPA has to be signed before it installs. Build it like this (about two minutes):

```bash
cd ~/code/zentri
brew install xcodegen            # once
xcodegen generate

xcodebuild archive \
  -project Zentri.xcodeproj -scheme ZentriApp -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath DerivedData/ipa/Zentri.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

cd DerivedData/ipa
rm -rf Payload && mkdir Payload
cp -R Zentri.xcarchive/Products/Applications/ZentriApp.app Payload/
zip -qry Zentri-1.0-unsigned.ipa Payload
```

Result: `DerivedData/ipa/Zentri-1.0-unsigned.ipa` (arm64, Release, not signed). `DerivedData/` is
git-ignored.

What is inside:

| Bundle | Bundle ID | Entitlements it needs |
|---|---|---|
| `Payload/ZentriApp.app` | `com.farhantamzid.zentri` | `ZentriApp/ZentriApp.entitlements` |
| `Payload/ZentriApp.app/PlugIns/ZentriWidgets.appex` | `com.farhantamzid.zentri.widgets` | `ZentriWidgets/ZentriWidgets.entitlements` |

There are no embedded frameworks; the Swift package is linked statically.

## Part 2 — Sign and install with FlareStore

FlareStore's steps below come from its own guide and FAQ (flarestore.app/guide/ios, flarestore.app/faq,
flarestore.vip) as of November 2026. None of this has been tried with Zentri yet.

### 2.1 What to buy

Zentri needs no JIT, so a **distribution** certificate is enough. FlareStore's plans are one device,
one-time payment, valid one year, with no revoke protection:

| Plan | Certificate | Fits Zentri? |
|---|---|---|
| Basic | Distribution | Yes — cheapest option that works |
| Standard | Development (JIT) | Works, but needs Developer Mode on the phone; JIT is not needed |
| Pro | Distribution | Yes |
| Premium | Distribution + Development | Yes; more than Zentri needs |

After paying you are sent to a redemption page that asks for the phone's **UDID** (FlareStore points
to udid.website to read it). The UDID cannot be changed afterwards, so enter the iPhone you will
install on.

### 2.2 Install the FlareStore app and certificate

1. Sign and install the FlareStore app with the **FlareStore Web Signer** (linked from your
   redemption page / flarestore.app).
2. Open FlareStore. A certificate used by the Web Signer is imported automatically. If it is not
   there: **Settings › Certificates › Add Certificate**, pick the **P12** and the **Mobile
   Provision**, and enter the P12 password if it has one.
3. If iOS says the developer is untrusted when you open an installed app: Settings › General › VPN &
   Device Management › trust the certificate. With a development certificate also turn on Settings ›
   Privacy & Security › Developer Mode.

### 2.3 Get the IPA onto the phone

Send `DerivedData/ipa/Zentri-1.0-flarestore-unsigned.ipa` (the build made for your FlareStore
certificate, see 2.5) from the Mac to the iPhone: AirDrop it and choose
**Save to Files**, or put it in iCloud Drive.

### 2.4 Sign and install Zentri

1. FlareStore home page › **+ Import** › choose `Zentri-1.0-flarestore-unsigned.ipa`.
2. **Library** tab › select Zentri › **Sign**.
3. Before signing, tap **Edit** only if you must. **Leave the Bundle ID as
   `com.farhantamzid.zentri`** — FlareStore's FAQ says an update only keeps your data when it is
   signed with the same certificate and the same bundle ID as the installed copy. If there is an
   option to remove extensions/plug-ins, leave it off, or the widgets are stripped.
4. When signing finishes tap **Install** and accept the prompt ("Open this Page in iTunes" or
   "localhost.flarestore.vip would like to install…").
5. If no prompt appears or you get a domain lookup error, FlareStore's guide says to make sure an ad
   blocker, VPN or ISP is not blocking `*.flarestore.vip`, or to use the 1.1.1.1 DNS app.

### 2.5 The App Group: check this before relying on widgets

Zentri's widgets read the app's data through the App Group `group.com.farhantamzid.zentri`, which is
compiled into the app. A FlareStore certificate belongs to someone else's Apple developer team, so
that exact group is not in its provisioning profile.

What to expect if the group is not granted:

- **The app itself should work fully**, including the Shortcuts capture action: the app and the
  action run in the same process and fall back to app-local storage.
- **Widgets show only their placeholder**, because the widget extension cannot see that storage.
- Section E of the test cases will fail; everything else is unaffected.

**Checked on 16 Nov 2026 for your certificate.** Its profile does not contain Zentri's own group
but does contain five of its own: `group.a1a3126d75ee90bd.1` to `.5`. Its app identifier is the
explicit `AXSTP35NFJ.app.amethyst4184.corn1816`, and it expires on 27 Sep 2027.

`DerivedData/ipa/Zentri-1.0-flarestore-unsigned.ipa` is therefore built with
**`group.a1a3126d75ee90bd.5`** in place of `group.com.farhantamzid.zentri`. The repository itself
still uses the original group; to rebuild this variant, replace the group ID in
`ZentriApp/ZentriApp.entitlements`, `ZentriWidgets/ZentriWidgets.entitlements` and
`AppGroup.identifier` in `ZentriCore/Sources/ZentriCore/AppGroup.swift`, then repeat Part 1 (do it
in a copy of the repo, and do not commit it).

Still to confirm on the phone:

- **That FlareStore's signer keeps the App Group entitlement on both the app and the widget
  extension.** Test cases E1 and E2 answer this: real data in a widget means it worked; a
  placeholder means the entitlement was dropped.
- **The bundle ID.** The profile names one explicit app ID rather than a wildcard. Leave Zentri's
  bundle ID alone first; if installation fails, set the Bundle ID in FlareStore's **Edit** screen to
  `app.amethyst4184.corn1816` and sign again. Pick one and keep it: a different bundle ID installs
  as a separate app with separate data.
- **Other apps signed with this certificate.** Every app you sign with it can be given the same
  five groups, so another sideloaded app could read Zentri's shared container — which holds the
  database with your bank messages. Only sign apps you trust with this certificate.

To re-check a profile (for a renewed or different certificate):

```bash
security cms -D -i ~/Downloads/YOUR.mobileprovision > /tmp/profile.plist
/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' /tmp/profile.plist
/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' /tmp/profile.plist
```

A renewed certificate may come with different group IDs. If so, export a backup, rebuild with the
new group, install, and restore.

Other consequences of signing this way:

- **One certificate, one year.** Re-sign and reinstall over the top with the same certificate and
  bundle ID before it expires; data is kept.
- **Revokes.** If Apple revokes the certificate the app stops opening. FlareStore offers no revoke
  protection. Your data stays on the phone only as long as the app is not deleted, and a different
  certificate may not be able to install over it. **Turn on automatic backups to iCloud Drive
  (Part 3, step 5) on day one** so a revoke costs you nothing but a reinstall and a restore.
- **Trust.** The signer and the certificate's owner are third parties. Zentri makes no network
  requests and FlareStore signs on the device, but you are relying on their tooling with an app that
  holds your bank messages.

**Upgrading later:** install a new build over the old one with the same certificate, bundle ID and
group and your data stays. Deleting the app deletes its data; restore from a backup (Part 3, step 6).

## Part 3 — First-time setup on the phone

1. **Open Zentri and finish onboarding.**
   - Currency: pick yours (for example BDT). It is a label only; amounts are never converted.
   - Number grouping: System, Western `1,000,000.00`, or Indian `10,00,000.00`.
   - Account: name, bank, and the current balance as the opening balance.
   - Parsing engine: **Hybrid** (rules first, Apple Intelligence as fallback) is the default. Choose
     **Rules** if the phone has no Apple Intelligence.
   - Face ID: optional; turning it on asks for Face ID once.
2. **Add a parsing rule for your bank.** Settings › Parsing › add a rule for the account. Paste a
   real message into the tester and adjust the pattern until amount, direction, merchant and
   balance read correctly. Add one rule per message shape (spend, deposit, transfer).
3. **Create the Shortcuts automation** (Zentri cannot read SMS itself). Settings › Shortcuts shows
   the same guide:
   - Shortcuts app › Automation › **+** › **Message**.
   - **Sender**: your bank's sender name or number. Turn on **Run Immediately**; turn off Notify
     When Run if you like.
   - Add action **Capture Bank SMS** (Zentri). Set **SMS Text** to the automation's **Shortcut
     Input › Content**. Leave Account empty unless this sender maps to exactly one account.
   - Repeat for each bank sender.
4. **Add widgets.** Long-press the Home Screen › Edit › Add Widget › Zentri: balance, recent
   transactions, categories, trend. Lock Screen: customise › add the Zentri accessory widget. Each
   widget has a **Hide Amounts** option.
5. **Turn on automatic backups.** Settings › Backup › choose a folder, ideally a new
   `iCloud Drive/Zentri Backups`. Backups are plain, unencrypted JSON and contain your raw bank
   messages.
6. **Restoring after a reinstall:** finish onboarding again, then Settings › Backup › choose the
   same folder › **Restore from Folder** › newest snapshot › **Replace**.

Things to know:

- Captures do not work between a phone restart and the first unlock.
- If the automation is disabled or set to ask before running, messages are missed. The Overview
  health card shows when the last message arrived.
- Every captured message is kept in Settings › Parsing › Message Inbox, parsed or not, and can be
  reprocessed after you fix a rule.

## Part 4 — Test cases

Mark each Pass / Fail. "Sample SMS" means a message your rule reads, for example
`MYBANK: BDT 1,250.00 spent at Fixture Cafe. Avl Bal BDT 48,750.00`. To send test messages without
your bank, create the automation for a second phone's number as sender.

### A. Install and onboarding

| # | Steps | Expected |
|---|---|---|
| A0 | Confirm you are installing `Zentri-1.0-flarestore-unsigned.ipa` | It is the build that uses your certificate's App Group |
| A1 | Sign and install with FlareStore (Part 2), open Zentri | Onboarding appears; no crash; no "untrusted developer" block after trusting the certificate |
| A2 | Complete onboarding with BDT, Indian grouping, opening balance 1000000 | Overview shows `10,00,000.00` with the BDT symbol/code and an "as of" time |
| A3 | In onboarding, turn Face ID on and cancel the Face ID prompt | Toggle stays off with a short message |
| A4 | Force-quit and reopen | Goes straight to Overview; data intact |
| A5 | Settings › Appearance: switch grouping to Western | Amounts everywhere become `1,000,000.00`; values unchanged |
| A6 | Change currency | Symbol/code changes; numbers are not converted |

### B. Rules and the tester

| # | Steps | Expected |
|---|---|---|
| B1 | Settings › Parsing › add a rule, paste the sample SMS in the tester | Amount, direction, merchant, balance shown correctly |
| B2 | Enter an invalid regex | Clear error; cannot save; app stays responsive |
| B3 | Test amounts `1,234.56`, `12,500`, `1.234,56` | Each either parses to the right amount or fails with a reason; never a silently wrong amount |
| B4 | Archive the account, then capture an SMS its rule would match | No transaction is filed on the archived account |

### C. Capture through Shortcuts

| # | Steps | Expected |
|---|---|---|
| C1 | In Shortcuts, run Capture Bank SMS manually with the sample SMS | Dialog like "Recorded … at Fixture Cafe"; Zentri does not open |
| C2 | Open Zentri | Transaction on Overview and in Transactions; balance equals the SMS balance; inbox shows the message as parsed |
| C3 | Run C1 again with the same text | "Already in Zentri"; no second transaction |
| C4 | Run with `Your code is 123456.` | "Not a transaction" or "couldn't read"; message is in the inbox |
| C5 | Real automation: with Zentri swiped away, receive a bank SMS | Transaction appears without opening Zentri; widgets update |
| C6 | Lock the phone (already unlocked once since restart), receive an SMS | Captured |
| C7 | With Zentri in the background, capture, switch back | New transaction visible without relaunching |
| C8 | Two accounts, each with a rule; capture without choosing an account | Lands on the account whose rule matched |
| C9 | SMS with a date and time (for example 9:30 pm today) | Transaction shows that local time and today's date, not shifted by your UTC offset |
| C10 | Hybrid mode, SMS no rule reads | Either parsed by Apple Intelligence with an amount that appears in the message, or listed as failed/ignored in the inbox; never an invented amount |
| C11 | Inbox › open a failed message › fix the rule › Reprocess | Becomes parsed; transaction created; balance correct |
| C12 | Restart the phone, do not unlock, receive an SMS, then unlock and open Zentri | Note what happens (capture is expected not to work before first unlock) |

### D. Transactions, balance, insights

| # | Steps | Expected |
|---|---|---|
| D1 | Add a manual transaction dated today | Appears in the list; balance moves by that amount |
| D2 | Edit its amount and category | Updates in the list, Overview and Insights |
| D3 | Delete it | Balance returns to the previous value |
| D4 | Add a manual transaction dated before the latest bank SMS | Listed; note whether the balance moves (see open question 2 in the hand-over) |
| D5 | Move an SMS transaction to another account | Both accounts' balances stay sensible; the old account no longer shows the other's bank balance |
| D6 | Search by merchant and by a word from the raw SMS | Matching rows only |
| D7 | Mark a transaction as a transfer | Stays in the list; excluded from spend and income totals |
| D8 | Insights: change month, tap a category slice | Totals change; tapping opens Transactions filtered to that category |
| D9 | Settings › Accounts › set balance | Overview balance and "as of" time update |
| D10 | Settings › Categories: add, rename, drag to reorder | Order persists after relaunch; "Other" cannot be renamed or deleted |

### E. Widgets (need the App Group — see 2.5)

| # | Steps | Expected |
|---|---|---|
| E1 | Add every Home Screen widget size and the Lock Screen widget | Real data, not the placeholder |
| E2 | Capture an SMS | Widgets update within a short time |
| E3 | Edit a widget › Hide Amounts | `••••` in place of amounts; layout does not jump |
| E4 | Lock the phone, view the Lock Screen widget | Amounts redacted if the system hides sensitive content |
| E5 | Tap each widget | Opens the matching tab (Overview, Transactions, Insights) |
| E6 | Tinted and clear Home Screen styles, dark mode | Text legible |
| E7 | Indian grouping and BDT set in the app | Widgets use the same grouping and currency |

### F. Backup and restore

| # | Steps | Expected |
|---|---|---|
| F1 | Settings › Backup › Export | File named `Zentri-YYYY-MM-DD-HHmm` with a JSON extension saved where you chose |
| F2 | Choose `iCloud Drive/Zentri Backups`, make an edit, background the app | A snapshot file appears in the folder with the current time |
| F3 | Relaunch the app; restart the phone | Folder is still selected; backups continue |
| F4 | Delete Zentri, reinstall, onboard, choose the same folder | Zentri asks before writing; the old snapshots are still there and listed |
| F5 | Restore the newest snapshot with Replace | All accounts, transactions, rules, categories and settings return; balance matches |
| F6 | Import a file with Merge on a phone that already has that data | Nothing duplicated |
| F7 | Import a truncated or edited-to-be-invalid JSON file | Rejected with a reason; existing data untouched |
| F8 | With many transactions, background the app | No visible freeze when returning |

### G. Face ID lock

| # | Steps | Expected |
|---|---|---|
| G1 | Settings › Appearance › Require Face ID | Asks for Face ID first; turns on only if it passes |
| G2 | Background the app, look at the app switcher | Privacy cover, no financial data |
| G3 | Same with a transaction detail sheet or file picker open | Still covered |
| G4 | Return to the app | Face ID prompt once; success unlocks |
| G5 | Cancel the prompt | Stays locked with Try Again; does not prompt in a loop |
| G6 | Fail Face ID repeatedly | Passcode fallback offered and works |
| G7 | Force-quit, cold launch with lock on | No data visible before unlocking |
| G8 | Lock on, type in a text field, background the app | Keyboard is not visible above the cover; nothing can be typed into the hidden field |
| G9 | Lock on, tap a widget | Asks to unlock, then opens the right tab |
| G10 | Lock on, capture an SMS through Shortcuts | Recorded without unlocking |

### H. Data deletion and recovery

| # | Steps | Expected |
|---|---|---|
| H1 | Settings › About › Delete All Data, type `DELET` | Delete button stays disabled |
| H2 | Type `DELETE` and confirm | App returns to onboarding; widgets show placeholders; backup files in your folder remain |

### I. Accessibility and layout

| # | Steps | Expected |
|---|---|---|
| I1 | Largest accessibility text size, visit every screen and onboarding | Nothing cut off or unreachable; buttons reachable by scrolling |
| I2 | VoiceOver: balance, rows, charts, rule tester, lock screen | Sensible labels; charts offer Chart Details with a data table |
| I3 | Reduce Motion, Reduce Transparency, Increase Contrast, dark mode | Readable; no animation-dependent content |
| I4 | Disabled Continue button in onboarding, light and dark | Visibly a button (light mode is faint, matching the system's own disabled style) |
| I5 | iPad or iPhone Duo, if you have one: rotate, Split View | Every feature reachable |

### Known limitations to keep in mind while testing

- A message captured while Apple Intelligence is unavailable or still downloading, with no matching
  rule, is filed as "not a transaction" and not retried automatically. Reprocess it from the inbox.
- Lock wording says "Face ID" and "iPhone" even on devices where that is wrong.
- "Recategorize all", the tester's "Save as transaction", and a rule editor inside onboarding are
  not built.
