# Zentri

Zentri is a private finance tracker for iPhone and iPad. It turns the bank SMS messages you share
with it, through a Shortcuts automation, into transactions, balances, insights, and Home Screen
widgets. Everything is parsed and stored on the device: there is no account, no server, no
analytics, and the app makes no network requests of its own.

- SwiftUI, SwiftData, Swift Charts, WidgetKit, and App Intents; iOS 27; Swift 6 with complete strict
  concurrency; no third-party dependencies.
- Targets: `ZentriCore` (a Swift package with the domain, parsing, ingestion, persistence, backup,
  and widget-snapshot logic), `ZentriApp`, `ZentriWidgets`, `ZentriAppTests`, and `ZentriUITests`.
- The design is in `docs/superpowers/specs/2026-11-14-zentri-design.md`.

## Building

The Xcode project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
and is not checked in.

```bash
brew install xcodegen
xcodegen generate        # run again after adding or removing files
open Zentri.xcodeproj
```

Xcode 27.2 or later is required. Tests:

```bash
swift test --package-path ZentriCore
xcodebuild test -project Zentri.xcodeproj -scheme ZentriApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project Zentri.xcodeproj -scheme ZentriWidgets \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

UI tests run the app with `-UITestMode`, which keeps every store, settings file, widget snapshot,
and backup folder in memory or inert, so a test run never touches real data. The other launch
switches (`-UITestSkipOnboarding`, `-UITestSeed`, `-UITestSeedHistory`, `-UITestSeedInsights`,
`-UITestSeedParsing`, `-UITestReset`, `-UITestUnreadableSettings`, and
`-UITestMockBiometrics success|failure`) are documented in `ZentriApp/App/UITestSupport.swift`.

## Signing: free and paid teams

| | Free Apple ID (personal team) | Paid Apple Developer Program team |
|---|---|---|
| Simulator | Everything, including widgets and Shortcuts | Everything |
| Physical device: the app | Runs (re-sign every 7 days) | Runs |
| Physical device: widgets and Shortcuts capture with shared data | No — App Groups need the paid team | Yes |

Bundle identifiers: `com.farhantamzid.zentri` (app) and `com.farhantamzid.zentri.widgets` (widget
extension). Change `bundleIdPrefix` and the two `PRODUCT_BUNDLE_IDENTIFIER` values in `project.yml`
if you sign with a different team.

### The App Group

The app, its Shortcuts action, and the widgets share data through the App Group
`group.com.farhantamzid.zentri`, declared in `ZentriApp/ZentriApp.entitlements` and
`ZentriWidgets/ZentriWidgets.entitlements`. The SwiftData store, the settings document, and the
widget snapshot all live in that container. To run on a device:

1. In Xcode, select your paid team under Signing & Capabilities for both `ZentriApp` and
   `ZentriWidgets`.
2. Make sure the App Groups capability lists the same group for both targets. If you changed the
   bundle prefix, register a matching group and update both entitlements files and
   `ZentriCore/Sources/ZentriCore/AppGroup.swift`.
3. Run `xcodegen generate` again after editing `project.yml` or the entitlements.

Without the group the app still launches — it falls back to app-local storage — but the widgets
show their placeholder and a capture from Shortcuts cannot reach the app's data.

## Capturing bank messages with Shortcuts

iOS does not let apps read SMS. Zentri instead offers a **Capture Bank SMS** action that a Shortcuts
**Message** automation runs for each message from your bank:

1. Open Zentri › Settings › Shortcuts (also offered during setup) and follow the guide.
2. In the Shortcuts app, create a personal automation: **Message**, sender is your bank, **Run
   Immediately** on.
3. Add Zentri's **Capture Bank SMS** action and pass the message's **Content** as **SMS Text**.
   Optionally choose an account; otherwise the matching parsing rule's account is used.

The action runs in the background without opening Zentri. It parses the message with the engine
chosen in Settings › Parsing (regex rules, Apple Intelligence where available, or both), stores the
transaction, updates the widget snapshot, and reloads the widgets. Every message is archived in
Settings › Parsing › Message Inbox, parsed or not, so nothing is lost and a failed message can be
reprocessed after you fix a rule.

### Manual test: Shortcuts capture

The Capture Bank SMS action cannot be exercised by the automated suites, because they cannot drive the
Shortcuts app. Check it by hand on a simulator or a device after any change to capture or ingestion.

#### Simulator: run the action with pasted text

1. Build and run the `ZentriApp` scheme, finish onboarding, and note the account's balance on Overview.
2. Optionally add a parsing rule in Settings › Parsing that reads your sample message, or choose the
   Hybrid or Apple Intelligence engine.
3. Open the Shortcuts app, create a new shortcut, and add the **Capture Bank SMS** action from Zentri.
4. Paste a sample bank message into **SMS Text**, for example
   `MYBANK: 42.75 spent at Fixture Cafe. Thank you.`, and run the shortcut.
5. Expect a dialog such as "Recorded $42.75 at Fixture Cafe." — the amount is shown in the currency
   chosen during onboarding, whatever symbol the message used. Open Zentri: the transaction is on
   Overview and in Transactions, and Settings › Parsing › Message Inbox lists the message as parsed.
6. Run the shortcut again with the same text. Expect "This message is already in Zentri, so nothing was
   added.", and no second transaction.
7. Run it with text no rule reads, such as `Your code is 123456.` Expect a "not a transaction" or "couldn't
   read" dialog, and the message in the inbox.
8. Add a second account and a rule for it that reads a new sample message. Run the action with that
   message without choosing an account: the transaction lands on the rule's account. With a message only
   Apple Intelligence reads, expect the dialog asking for a rule or an account in the Shortcut; choose an
   account in the action and run it again, and the transaction lands on that account.
9. With Zentri open in the background (switch away without closing it), run the action, then switch back:
   the new transaction shows on Overview without relaunching.

#### Device: real message automation

1. Follow Settings › Shortcuts in Zentri to create a **Message** automation for your bank's sender, with
   **Run Immediately** on, passing the message's **Content** as **SMS Text**.
2. With Zentri closed (swiped away), have the bank send a transaction message, or send yourself one from
   another phone using a sender the automation matches.
3. Expect the transaction to appear without opening Zentri: the Home Screen widgets update, and opening
   Zentri shows it on Overview. The ingestion health card shows the new last message and last parse.
4. Lock the device after it has been unlocked once since restart and repeat: capture must still work.

## On-device restrictions

- **Message access.** Only a Shortcuts automation can hand Zentri a message; there is no background
  SMS reading. If the automation is turned off or asks before running, messages are missed. The
  Overview ingestion health card shows when the last message arrived.
- **First unlock.** The store and the widget snapshot use
  `completeUntilFirstUserAuthentication` protection, so captures work while the device is locked,
  but not between a restart and the first unlock.
- **Apple Intelligence.** The Foundation Models engine only runs where Apple Intelligence is
  available and enabled. Elsewhere the Hybrid engine uses your regex rules and the inbox records
  why the model could not run.
- **Widgets** reload when a capture or an edit changes the snapshot, within WidgetKit's reload
  budget, and otherwise refresh hourly.
- **Face ID.** The optional lock uses Face ID with the device passcode as fallback. It covers the app
  in the app switcher and asks again each time the app returns from the background. It does not
  encrypt the store or backups, and it does not apply to the Shortcuts action, which never shows the
  app. On a device with neither Face ID nor a passcode the lock cannot check anyone, so it explains
  that and offers to turn itself off rather than asking in a loop.

## Backup and restore

Zentri never syncs on its own. Two kinds of backup are available in Settings › Backup:

- **Export** writes one JSON file (`Zentri-YYYY-MM-DD-HHmm.json`) with every account, balance
  checkpoint, transaction, raw message, rule, category, and the settings. **Import** validates a
  file and shows what it holds before you choose **Replace** (all data replaced in one step) or
  **Merge** (only what is missing is added). An invalid file never changes your data.
- **Automatic snapshots** go to a folder you choose once — ideally `iCloud Drive/Zentri Backups`.
  Zentri writes a snapshot a couple of seconds after each change and when it goes to the
  background, keeps the newest ten, and lists them under **Restore from Folder**. A folder that
  already holds backups from another install is held until you confirm, so a fresh install does not
  overwrite them.

The folder is a normal, user-visible folder on purpose: an app's private iCloud container can be
removed with the app, but `iCloud Drive/Zentri Backups` survives deleting Zentri. To move to a new
device or reinstall: install Zentri and finish setup, then in Settings › Backup choose the same
folder and restore its newest snapshot with **Restore from Folder**, or import a file, using
**Replace**. (If Zentri cannot read its settings at launch, its recovery screen also offers
**Restore Backup**.)

Backups contain the raw text of your bank messages and are **not encrypted**. Keep them somewhere
you trust.

## Privacy

- All parsing and storage happen on the device. No analytics, telemetry, crash reporting, or
  third-party SDKs. Zentri makes no network requests; iCloud Drive syncing of a backup folder is
  done by the system, not by Zentri.
- Logs never contain message text, merchants, amounts, or backup contents.
- Each widget has a **Hide Amounts** option, and the widgets support the system's redacted
  appearance on a locked device.
- Settings › About › Delete All Data removes the store, the widget snapshot, and the backup folder
  bookmark. Files you exported or backups already in your folder are yours and are not deleted.

## Device checklist

None of the checks below has been performed yet. They need a physical device signed with the paid
team (the App Group), Face ID hardware, or the Shortcuts app, which the automated suites cannot
drive. Mark each one when it has been run.

**Shortcuts capture** (see the manual test above)

- [ ] Not yet performed — real bank SMS → Message automation → transaction, with Zentri closed.
- [ ] Not yet performed — running Capture Bank SMS from the Shortcuts app: it runs in the background
  without opening Zentri; the account parameter suggests Zentri's accounts; the result dialog reads
  correctly; the widgets reload afterwards.
- [ ] Not yet performed — capture while the device is locked (after first unlock).

**Widgets**

- [ ] Not yet performed — Home Screen widgets (balance, recent transactions, categories, trend) and
  the Lock Screen accessory widget show real data after a capture.
- [ ] Not yet performed — tinted and clear Home Screen appearances.
- [ ] Not yet performed — **Hide Amounts** shows `••••` without moving the layout; the redacted
  appearance on a locked device, including what VoiceOver reads there.
- [ ] Not yet performed — the accessory rectangular widget's text fits at large text sizes.
- [ ] Not yet performed — tapping a widget opens the matching tab (`zentri://overview`,
  `zentri://transactions`, `zentri://insights`), including while the Face ID lock is on (the tab
  opens after unlocking).
- [ ] Not yet performed — Western `1,000,000` vs Indian `10,00,000` grouping and the chosen currency
  reach the widgets.

**Backup and restore**

- [ ] Not yet performed — choose an iCloud Drive folder → export → delete Zentri → reinstall →
  restore from the folder.
- [ ] Not yet performed — whether snapshots that iCloud has not downloaded yet appear in Restore
  from Folder.
- [ ] Not yet performed — the exporter saves with the `.zentri.json` name and extension.
- [ ] Not yet performed — the folder bookmark survives relaunching the app and restarting the device.
- [ ] Not yet performed — a snapshot is written when the app goes to the background (check its time
  in the folder).
- [ ] Not yet performed — choosing a folder that already holds another install's backups asks for
  confirmation before writing.

**Face ID and privacy**

- [ ] Not yet performed — turn on Settings › Appearance › Require Face ID (asks for Face ID first);
  leave and return: the lock asks once; cancelling shows Try Again without asking again on its own.
- [ ] Not yet performed — the app switcher shows the privacy cover, not data, including with a
  transaction's detail sheet or a file picker open.
- [ ] Not yet performed — cold launch with the lock on never shows data before the lock.
- [ ] Not yet performed — passcode fallback after repeated Face ID failures.
- [ ] Not yet performed — a capture from Shortcuts while the lock is on still records the
  transaction.

**Accessibility and layout**

- [ ] Not yet performed — Dynamic Type through the largest accessibility sizes on every screen.
- [ ] Not yet performed — a VoiceOver pass: balance hero, rows, charts (Chart Details offers the audio
  graph and data table), rule tester, onboarding fields, lock screen.
- [ ] Not yet performed — Reduce Motion (no chart reveal or numeric transitions), Reduce
  Transparency (the balance hero drops its glass), Increase Contrast, and dark mode.
- [ ] Not yet performed — iPhone Duo outer and inner displays in both orientations, and iPad Split
  View and Slide Over: every feature stays reachable.
- [ ] Not yet performed — drag to reorder categories in Settings › Categories.
