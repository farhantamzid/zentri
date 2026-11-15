# Zentri

## Manual test: Shortcuts capture

The Capture Bank SMS action cannot be exercised by the automated suites, because they cannot drive the
Shortcuts app. Check it by hand on a simulator or a device after any change to capture or ingestion.

### Simulator: run the action with pasted text

1. Build and run the `ZentriApp` scheme, finish onboarding, and note the account's balance on Overview.
2. Optionally add a parsing rule in Settings › Parsing that reads your sample message, or choose the
   Hybrid or Apple Intelligence engine.
3. Open the Shortcuts app, create a new shortcut, and add the **Capture Bank SMS** action from Zentri.
4. Paste a sample bank message into **SMS Text**, for example
   `MYBANK: RM42.75 spent at Fixture Cafe. Thank you.`, and run the shortcut.
5. Expect a dialog such as "Recorded $42.75 at Fixture Cafe.", in the currency chosen during
   onboarding. Open Zentri: the transaction is on
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

### Device: real message automation

1. Follow Settings › Shortcuts in Zentri to create a **Message** automation for your bank's sender, with
   **Run Immediately** on, passing the message's **Content** as **SMS Text**.
2. With Zentri closed (swiped away), have the bank send a transaction message, or send yourself one from
   another phone using a sender the automation matches.
3. Expect the transaction to appear without opening Zentri: the Home Screen widgets update, and opening
   Zentri shows it on Overview. The ingestion health card shows the new last message and last parse.
4. Lock the device after it has been unlocked once since restart and repeat: capture must still work.
