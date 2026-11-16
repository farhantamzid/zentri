# Zentri — Handoff for a New Chat

**Date:** 2026-11-15 (header, commit and status tables updated after Task 14 completed; sections 4–5 and 8 below still describe the Task 11 → 12 handoff in detail — the SDD ledger is authoritative for Tasks 12–14)
**Repo:** `/Users/farhantamzid/code/zentri`
**Branch:** `feature/zentri-v1`
**Current HEAD:** `57a45c0` (final-review fix wave)
**Next step:** All 19 tasks complete; final whole-branch review done (11 Important fixed in `2bc993c..57a45c0`, re-review clean, residuals parked in the ledger). Controller verified core 467 / app unit 241 / UI 34 on iPhone 17 + widget build. Waiting on the user: finishing option (merge / PR / keep), owner decisions (omitted spec features, back-dated manual transactions, model-unavailable handling), and the README device checklist (all unperformed).
**Controller:** now Claude Code with the `superpowers:subagent-driven-development` plugin skill (same process). Commits from Task 12 on carry a Claude `Co-Authored-By` trailer instead of the plan's CommandCodeBot line (ledger ruling).
**Main:** contains the approved design spec and implementation plan; do not commit implementation to `main`.

This document is the entry point for a fresh session. Read it, then read the SDD ledger, the spec, and the plan before dispatching any work.

---

## 1. What this project is

Zentri is a private, on-device iOS finance tracker. It turns bank transaction SMS into structured transactions without direct SMS access:

```
Shortcuts "Message Received" automation
  → CaptureSMSIntent (App Intent)
  → IngestionService (shared core)
  → regex / Foundation Models / hybrid parser
  → validation → categorization → SwiftData (App Group)
  → widget snapshot → WidgetKit
```

The app shows one combined bank-account balance, transaction history, category insights, meaningful charts, and home-screen widgets. Data is exportable/importable as versioned JSON, with automatic snapshots to a user-chosen iCloud Drive folder so data survives app deletion.

**User requirements locked in**
- iPhone 17 Pro Max, iOS 27.x; Xcode 27.2; Swift 6.4.2.
- iOS cannot read SMS directly; the Shortcuts automation is user-created and cannot be installed by the app.
- Per-account, separate debit/credit regex rules with named groups and a live tester; no hardcoded bank formats.
- Foundation Models as a full parsing mode and a hybrid fallback; a side-by-side tester to judge whether regex can be retired later.
- One app-wide currency, selected at setup and changeable later as **display-only**; amounts are never converted. Number grouping is independent: Western `1,000,000.00`, Indian `10,00,000.00`, or system. Widgets must honor it.
- Bank accounts only; single combined balance; no credit cards/cash/multi-currency.
- One bank SMS sometimes includes the balance → checkpoint-based balance with “as of” time.
- Core v1 only: no budgets, subscriptions, credit cards, cash, CSV, CloudKit sync, or bulk historical SMS import.
- Beautiful native SwiftUI, Liquid Glass where it serves a purpose, clean widgets, strong reporting.
- The user explicitly requires the installed **SwiftUI Pro** skill for all SwiftUI work.

---

## 2. Skills to use in the new session

### Mandatory for all implementation and UI review
**`swiftui-pro`**
- Path: `/Users/farhantamzid/.commandcode/skills/swiftui-pro/SKILL.md`
- Read the SKILL and the relevant files under `references/` before writing or reviewing SwiftUI.
- Enforce: `foregroundStyle`, `clipShape(.rect(cornerRadius:))`, `Tab`, zero/two-parameter `onChange`, `sensoryFeedback`, `ContentUnavailableView`, `@Observable`, `@Bindable`, private `@State`, `@ContentBuilder` for new view builders, no `UIScreen.main`, no deprecated API, Dynamic Type, VoiceOver, Reduce Motion/Transparency, 44pt targets, selective Liquid Glass.
- The user asked for this explicitly; do not skip it on UI tasks.

### Current execution process
**`subagent-driven-development`**
- Path: `/Users/farhantamzid/.commandcode/skills/subagent-driven-development/SKILL.md`
- One fresh implementer subagent per task, an independent task reviewer after each, a fix loop capped at five rounds, and a final whole-branch review.
- Templates: `implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`.
- Scripts:
  - `scripts/sdd-workspace PLAN_FILE`
  - `scripts/task-brief PLAN_FILE N`
  - `scripts/review-package PLAN_FILE BASE HEAD`
- Do not dispatch multiple implementation subagents in parallel.
- The controller never fixes review findings itself; resume the implementer or dispatch a fresh one.
- Continuous execution: do not pause between tasks; rule on ambiguities and keep going.

### Already completed
- `brainstorming` — used to produce the approved design spec.
- `writing-plans` — used to produce the approved implementation plan.
- Do not re-run these unless the user changes scope.

### At the end
- `requesting-code-review` — final whole-branch review using its `code-reviewer.md`, on the most capable available model.
- `finishing-a-development-branch` — after the final review is clean and residual findings are adjudicated.
- `verification-before-completion` — before claiming the work is done.
- `test-driven-development` — the plan mandates TDD; use it if implementation guidance is needed.

---

## 3. Sources of truth

Read in this order:

1. **This handoff**
2. **SDD ledger:** `.superpowers/sdd/2026-11-14-zentri-implementation/progress.md`
   - Preflight scan, every task status, every deferred minor, and every ruling (through Task 12's pre-dispatch rulings).
   - Git-ignored scratch but essential for recovery. Do not delete it until the plan is finished.
3. **Spec:** `docs/superpowers/specs/2026-11-14-zentri-design.md` (approved, committed at `8e97a22`)
4. **Plan:** `docs/superpowers/plans/2026-11-14-zentri-implementation.md` (approved, committed at `f5ae116`)
5. **Task 12 brief:** `.superpowers/sdd/2026-11-14-zentri-implementation/task-12-brief.md` (generated; implementer not dispatched)
6. Existing code under `ZentriCore/`, `ZentriApp/`, `ZentriWidgets/`

The spec is binding. The plan is its argument. If they conflict, the spec wins and you record a ruling in the ledger.

---

## 4. Current progress

### Commits

| Item | Commit |
|---|---|
| Approved spec | `8e97a22` |
| Approved plan | `f5ae116` |
| Task 1 — scaffold | `72ee775` |
| Task 2 — core types/settings/money | `f98ad83` + fix `0fd54d1` |
| Task 3 — SwiftData schema/balance | `cca83db` |
| Task 4 — regex parser | `7cba7d8` + fixes `b6bd51a`, `513af02` |
| Task 5 — Foundation Models/hybrid | `6384eb7` + fix `6f85fa7` |
| Task 6 — categorization/insights | `c756d90` + fix `5ae92d1` |
| Task 7 — ingestion/snapshot | `0774594` + fix `57832f2` |
| Task 8 — backup | `b0b9509` + fix `29396ef` |
| Task 9 — app shell/design system | `539b7b4` + fix `36278df` |
| Task 10 — onboarding | `10587d4` + fix `02f25f9` |
| Task 11 — overview | `cd3603e` + fix `5f49e81` |
| Task 12 — transactions | `e8617b5`, `0920cb1`, `78f68da` + fix `7549e34` |
| Task 13 — insights | `5afa74c`, `dd62293`, `eee3577` + fixes `2d87ba7`, `7c37f83` |
| Task 14 — settings/accounts/categories | `dddd09f`, `8607020`, `4d62e99` |
| **Current HEAD** | **`4d62e99`** |

### Task status

| Task | Status |
|---|---|
| 1 Scaffold | ✅ complete |
| 2 Core types/settings/money | ✅ complete |
| 3 SwiftData schema/balance | ✅ complete |
| 4 Regex parsing | ✅ complete (2 fix rounds) |
| 5 Foundation Models/hybrid | ✅ complete (1 fix round) |
| 6 Categorization/insights | ✅ complete (1 fix round) |
| 7 Ingestion/snapshot | ✅ complete (1 fix round) |
| 8 Backup core | ✅ complete (1 fix round) |
| 9 App shell/design system | ✅ complete (1 fix round) |
| 10 Onboarding | ✅ complete (1 fix round) |
| 11 Overview | ✅ complete (1 fix round) |
| 12 Transactions | ✅ complete (1 fix round) |
| 13 Insights UI | ✅ complete (2 fix rounds) |
| 14 Settings/accounts/categories | ✅ complete (no fix round) |
| 15 Rules/tester/raw inbox | ✅ complete (1 fix round: reprocess timestamp/balance, multi-account Reprocess Failures) |
| 16 CaptureSMSIntent/Shortcuts | ✅ complete (1 fix round: foreground refresh/shared container, multi-account capture by matched rule; manual Shortcuts run deferred to Task 19 checklist) |
| 17 Widgets | ✅ complete (1 fix round: VoiceOver under privacy redaction, reload only on changed snapshot; manual Home/Lock Screen check deferred to Task 19 checklist) |
| 18 Backup UI/iCloud | ✅ complete (1 fix round: hold automatic backups to a folder that already has other backups; manual iCloud reinstall-restore deferred to Task 19 checklist) |
| 19 Face ID/accessibility/final | ✅ complete (1 fix round) |

### Current verification

**As of Task 14 (`4d62e99`), implementer-reported after its last change:** core 334/334, app unit 87, UI 18/18 on iPhone 17. The figures below are the Task 11 snapshot.

- `swift test --package-path ZentriCore`: **282/282 passing** (re-confirmed at handoff write time).
- App unit tests (`ZentriAppTests`): **35/35 passing** (17 from Tasks 9-10 + 18 `OverviewModelTests`, 5 of which cover the failure state).
- UI tests (`ZentriUITests`): **6/6 passing** on iPhone 17 — AppShell 1, Onboarding 1, Overview 4.
- `xcodebuild -project Zentri.xcodeproj -scheme ZentriApp -destination 'platform=iOS Simulator,name=iPhone 17' build`: **succeeds**. The only warning is the expected AppIntents metadata warning until Task 16.
- The widget extension build was last verified in Task 7; re-run it at Task 17 and before the final review.

### Current working tree

Clean except for `docs/HANDOFF.md` (this file, untracked) and a `.gitignore` addition for `.swiftpm/`.

**Known build side effect:** Xcode re-serializes `ZentriApp/Resources/Localizable.xcstrings` on build (reformats it as `"key" : value` and auto-extracts empty entries such as `"0.00"`). This shows up as a huge whitespace diff. It loses no keys. Restore it with `git checkout -- ZentriApp/Resources/Localizable.xcstrings` rather than committing the churn.

### Current codebase

```
ZentriCore/Sources/ZentriCore/
  AppGroup.swift                  # constants + SharedContainer URLs
  Models/
    DomainEnums.swift
    Account.swift, Transaction.swift, BalanceCheckpoint.swift,
    RawMessage.swift, ParsingRule.swift, Category.swift, CategorizationRule.swift
  Settings/AppSettings.swift, FileSettingsStore.swift
                                  # SettingsRepository + load/save/remove
  Formatting/MoneyFormat.swift, CurrencyCatalog.swift
                                  # + supportedCurrencyCodes
  Persistence/ZentriSchema.swift, ZentriContainer.swift, SeedData.swift
                                  # + SeedData.insert(into:) (no save)
  Balance/BalanceValues.swift, BalanceCalculator.swift
  Parsing/
    ParseTypes.swift, AmountNormalizer.swift, DateParser.swift,
    TransactionValidator.swift, RegexParsingEngine.swift,
    ModelParsingTypes.swift, FoundationModelsClient.swift,
    FoundationModelsParsingEngine.swift, HybridParsingEngine.swift,
    ParserFactory.swift, TimeoutRace.swift
  Categorization/CategorizationService.swift
  Insights/InsightsTypes.swift, InsightsCalculator.swift
  Ingestion/Dedupe.swift, IngestionService.swift
  Snapshot/WidgetSnapshot.swift, WidgetSnapshotBuilder.swift,
           WidgetSnapshotStore.swift, WidgetSnapshotRefresher.swift
  Backup/
    BackupDocument.swift, BackupCodec.swift,
    BackupExporter.swift, BackupImporter.swift
  Onboarding/OnboardingCommitter.swift
  Tests/ZentriCoreTests/          # 282 tests, 23 files
ZentriApp/
  App/
    ZentriApp.swift, AppState.swift, SettingsStore.swift,
    RootView.swift, RootTabView.swift, AppTab.swift,
    TransactionFilter.swift, UITestSupport.swift, DashboardFixture.swift,
    ContainerUnavailableView.swift, SettingsRecoveryView.swift,
    TabPlaceholderView.swift, InMemorySettingsRepository.swift
  Onboarding/                     # 20 files (unchanged since Task 10)
  Overview/                       # 17 files (Task 11)
    OverviewView.swift, OverviewContent.swift, OverviewModel.swift,
    OverviewSummary.swift, OverviewTransaction.swift,
    OverviewLoadState.swift, OverviewStoreReads.swift, OverviewCards.swift,
    MonthSummaryCard.swift, SevenDayChart.swift,
    TopCategoriesCard.swift, TopCategoryRow.swift,
    RecentTransactionsCard.swift, RecentTransactionRow.swift,
    IngestionHealth.swift, IngestionHealthCard.swift, SummaryRow.swift
  DesignSystem/
    Theme.swift, MoneyText.swift, SectionCard.swift,
    BalanceHero.swift, CategoryBadge.swift, ChartCard.swift
  Resources/
    Assets.xcassets/              # AccentColor, Canvas, Ink, SecondaryInk,
                                  # Income, Spending, 8 category colors,
                                  # light/dark + high-contrast text tokens
    Localizable.xcstrings         # 118 keys, extractionState manual
  Info.plist, ZentriApp.entitlements
ZentriAppTests/                   # AppState, OnboardingModel, OverviewModel,
                                  # SettingsStore, scaffold (35 tests)
ZentriUITests/                    # AppShell, Onboarding, Overview, scaffold (6 tests)
ZentriWidgets/                    # minimal scaffold + placeholder widget
docs/
  superpowers/specs/2026-11-14-zentri-design.md
  superpowers/plans/2026-11-14-zentri-implementation.md
  HANDOFF.md
```

### Key APIs available to later tasks

**Core data and persistence**
- `AppGroup.identifier` = `group.com.farhantamzid.zentri`; `SharedContainer.widgetSnapshotURL` / `.settingsURL` (optional).
- `AppSettings`, `FileSettingsStore`, `SettingsRepository` (`load`/`save`/`remove`), `MoneyFormat`, `CurrencyCatalog` (+ `supportedCurrencyCodes`).
- `ZentriContainer.make(inMemory:)`, `SeedData.seed(into:)`, `SeedData.insert(into:)` (inserts only, no save), `ZentriContainer` protection helpers.
- `SeedData.builtInCategoryNames` / `.fallbackCategoryName` — the single source of truth for the built-in category names; `CategorizationService` reads them.
- `BalanceCalculator.balance/combined`, `CheckpointValue`, `TransactionValue`.
- `RegexParsingEngine`, `FoundationModelsParsingEngine`, `HybridParsingEngine`, `ParserFactory` / `ParserBuilding`.
- `TransactionValidator`, `ParseResult`, `TransactionDraft` (has `matchedRuleID`).
- `CategorizationService.match(merchant:rules:suggestion:categories:)`; `CategorySnapshot`, `CategorizationRuleSpec`, `CategoryMatch`, `CategorizationService.fallbackCategoryName` / `.builtInCategoryNames`.
- `InsightsCalculator.summary(transactions:period:calendar:)`; month-over-month fields require an exact calendar-month period (ruling 20).
- `IngestionRequest`, `IngestionOutcome`, `@MainActor IngestionService` (`ingest`, `retryPending`), `Dedupe`.
- `WidgetSnapshot`, `WidgetSnapshotBuilder`, `WidgetSnapshotStore` / `FileWidgetSnapshotStore(fileURL: URL?)`, `WidgetSnapshotRefresher` / `LiveWidgetSnapshotRefresher`.

**Backup (Task 8)**
- `BackupDocument` with `schemaVersion`, `appVersion`, `exportedAt`, `settings`, and seven DTO arrays. Amounts and dates are strings; relationships are stable UUIDs.
- `BackupCodec.encode(_:)`, `.decode(_:)`, `currentSchemaVersion = 1`.
- `BackupExporter(settings: AppSettings).export(context:appVersion:) throws -> BackupDocument` (`@MainActor`).
- `BackupImporter.import(document:into:mode:) throws -> ImportSummary` (`@MainActor`); `ImportMode.replace/.merge`; `ImportSummary` per-kind created/skipped counts.
- `BackupError` with `.duplicateID`, `.unsupportedVersion`, `.brokenReference`, `.malformedDecimal`, `.malformedDate`, `.accountWithoutCheckpoint`, `.invalidFile(reason:)`.
- The importer never writes settings. `.merge` leaves settings alone; `.replace` replaces SwiftData rows only. Task 18 must apply `document.settings` through `SettingsStore` for a full restore.
- Export uses deterministic ordering and excludes derived widget/insights data.

**App shell (Task 9)**
- `@MainActor @Observable AppState` — `container`, `settingsStore`, `parserBuilder`, `snapshotRefresher`, `selectedTab`, `transactionFilter`, `dataRevision`, `mutate()`, `retryPendingIngestion()`.
- `@MainActor @Observable SettingsStore` — optional `settings`, `loadFailure`, `load()`, `save()`, `completeOnboarding()`, `reset()`, and internal `repository`.
- `RootView` selects recovery (`loadFailure`), onboarding (`settings == nil`), or `RootTabView`.
- `RootTabView` is four `Tab`s with four `NavigationStack`s; the `.overview` branch now renders `OverviewView`, the other three still `TabPlaceholderView`.
- `AppTab`, `TransactionFilter` (at `ZentriApp/App/TransactionFilter.swift`), `UITestSupport`, `DashboardFixture`.
- Design system: `Theme` (spacing/radii/colors, `categoryColor(for:)`), `MoneyText` (environment `\.moneyFormat`), `SectionCard` (`@ContentBuilder`), `BalanceHero(balance:asOf:todaySpend:)` (glass + Reduce Transparency fallback), `CategoryBadge(name:symbolName:colorToken:)`, `ChartCard(title)`.
- UI-test launch arguments: `-UITestMode` (in-memory container/settings, no App Group), `-UITestSkipOnboarding`, `-UITestSeed`, `-UITestReset`. `-UITestSeed` currently seeds categories/rules **plus** the Overview fixture (ruling 46). Task 12 will need to extend it with transaction fixtures for its own tests.
- `Localizable.xcstrings` contains 118 keys, all `extractionState: "manual"`; add new keys for new screens.

**Overview (Task 11)**
- `OverviewView` (reads `AppState`, supplies context + `dataRevision` + the empty-state action) wraps `OverviewContent` (owns the model, renders three states).
- `@MainActor @Observable OverviewModel(context:now:calendar:)` with `summary: OverviewSummary?`, `loadState: OverviewLoadState` (`.loading/.loaded/.failed`), and `refresh()`. It also has a second initializer taking injected `OverviewStoreReads` for failure testing.
- `OverviewStoreReads` — three injectable store reads (`accounts`, `messages`, `categories`); the seam that lets a test make a read throw.
- `OverviewLoadState` — `.loading` / `.loaded` / `.failed`; `.loaded` + `summary == nil` means "no active account", `.failed` means "the read threw", and the two render opposite advice.
- `OverviewSummary` (Sendable value: `balance`, `asOf`, `todaySpend`, `monthSpend`, `monthIncome`, `sevenDaySpend`, `topCategories`, `recentTransactions`, `health`, computed `monthNet`), `OverviewTransaction`, `IngestionHealth`.
- Cards: `OverviewCards`, `MonthSummaryCard`, `SevenDayChart` (Swift Charts `BarMark`, per-bar a11y + table-style `accessibilityValue`, Reduce Motion gates the reveal), `TopCategoriesCard`/`TopCategoryRow`, `RecentTransactionsCard`/`RecentTransactionRow`, `IngestionHealthCard`, `SummaryRow`.
- `DashboardFixture.seed(into:)` — one account, `.opening` checkpoint 1,000,000, debit 250 "Starbucks" (Dining), credit 5,000 "Salary" (Income), one `.failed` raw message. Rows are staggered by seconds so balance math applies the transactions after the checkpoint.
- Stable accessibility identifiers: `overview.finishSetup`, `overview.retry`, `overview.health.lastMessage`, `overview.health.lastSuccess`, `overview.health.failureCount`.

**Onboarding (Task 10)**
- `@MainActor public struct OnboardingCommitter`, `init(settingsRepository: any SettingsRepository)`, `@discardableResult commit(settings:accountName:institutionName:openingBalance:faceIDEnabled:context:) throws -> Account`. Writes settings first, one context save, rolls back rows and restores/removes the settings document on failure. Internal `saveHandler` test seam (production never assigns it).
- `SettingsRepository.remove()`; `FileSettingsStore.remove()` treats a missing file as success; `InMemorySettingsRepository.remove()`/`clear()`.
- `SettingsStore.repository` is internal; onboarding passes it to the committer and adopts settings in memory only on "Go to Overview" (`completeOnboarding`).
- `OnboardingFlow` (one `NavigationStack`, progress + footer insets, `\.moneyFormat` override, availability task), `OnboardingModel(locale:)` (validation, steps, `effectiveSettings`, `commit(using:context:)`, locale-aware balance parsing), `OnboardingStep`, step views, shared onboarding rows/tiles, `SetupCompleteView`.
- Stable accessibility identifiers: `onboarding.continue`, `onboarding.back`, `onboarding.currency.<CODE>`, `onboarding.grouping.western|indian|system`, `onboarding.account.name|institution|balance`, `onboarding.keyboard.done`, `onboarding.parser.rules|foundationModels|hybrid`, `onboarding.rules.continue`, `onboarding.shortcuts.open`, `onboarding.faceID.toggle`, `setupComplete.balance`, `setupComplete.continue`.
- `SettingsRecoveryView` (extended in place): "Use Defaults" deletes the damaged settings file and reopens onboarding while keeping accounts/transactions; "Restore Backup" explains Task 18.

**Not yet implemented:** Transactions, Insights UI, Settings/accounts/categories, rule editor/tester/raw inbox, App Intent, widgets, backup UI/iCloud, Face ID enforcement, final accessibility/README.

---

## 5. Immediate next action — implement Task 12

Task 11 is complete and reviewed (spec ✅, 1 Important fixed, 18 minors deferred). Task 12 has a generated brief and no implementation.

**Task 12 brief:** `.superpowers/sdd/2026-11-14-zentri-implementation/task-12-brief.md`
**BASE:** `5f49e81`
**Report path:** `.superpowers/sdd/2026-11-14-zentri-implementation/task-12-report.md`

### What to do

1. Activate `subagent-driven-development` and read its `implementer-prompt.md`.
2. Read the ledger, the Task 12 brief, spec §12.4 (Transactions) and §13 (visual design), and the existing Task 9/11 app code.
3. Compose the dispatch to a fresh `general` implementer. Include:
   - The brief path as the requirements source.
   - The SwiftUI Pro skill requirement (read the SKILL plus relevant references before writing UI).
   - The interfaces from Tasks 2, 3, 6, 7, 9, 10, and 11 the brief cannot know (below).
   - The binding rulings below (30, 54, 55).
   - The report path.
4. Generate the review package with the recorded BASE and dispatch an independent reviewer with the brief, report, diff, Global Constraints, spec §12.4, and the SwiftUI Pro review lens.
5. Run the fix loop if needed (max 5 rounds), mark Task 12 complete in the ledger, and continue to Task 13 without pausing.

### Interfaces to include in the Task 12 dispatch

**Core values and services**
- `BalanceCalculator.combined/balance`, `CheckpointValue`, `TransactionValue`; `signedAmount` is credit +, debit −.
- `CategorizationService.match(merchant:rules:suggestion:categories:) -> CategoryMatch`; build `[CategorizationRuleSpec]` from `CategorizationRule` rows and `[CategorySnapshot]` from `Category` rows.
- `CategorySnapshot(id:name:symbolName:colorToken:)`, `CategorizationRuleSpec(keyword:categoryName:priority:isEnabled:)`.
- `CategorizationService.fallbackCategoryName` (= `"Other"`).
- `WidgetSnapshotRefresher` protocol: `func refresh() async`; `LiveWidgetSnapshotRefresher` is `@MainActor`. `AppState.snapshotRefresher` is already a `LiveWidgetSnapshotRefresher`.
- `IngestionService` is the precedent for a main-actor service with an internal `saveHandler` test seam.

**SwiftData models (app target)**
- `ZentriCore.Account`: `id`, `name`, `institutionName`, `sortOrder`, `createdAt`, `archivedAt`, `transactions`, `checkpoints`, `rules`.
- `ZentriCore.Transaction`: `id`, `account`, `amount`, `direction`, `occurredAt`, `recordedAt`, `merchantRaw`, `merchantDisplay`, `category`, `categorySource`, `balanceAfter`, `rawMessage`, `parseEngine`, `matchedRuleID`, `isTransfer`, `note`, `createdAt`, `updatedAt`.
- `ZentriCore.Category`: `id`, `name`, `symbolName`, `colorToken`, `sortOrder`, `isSystem`.
- `ZentriCore.CategorizationRule`: `id`, `keyword`, `category`, `priority`, `isEnabled`. Creating one needs a `Category` object.
- `ZentriCore.RawMessage`: `text`, `sender`, `receivedAt`, `ingestedAt`, `status`, `engine`, `matchedRuleID`, `errorDescription`, `transaction`.
- `ParseEngine` = `.rules/.foundationModels/.manual`; `CategorySource` = `.rule/.ai/.manual/.default`.
- Qualify `ZentriCore.Transaction` / `ZentriCore.Category` / `ZentriCore.CategorizationRule` in app-target files (ruling 7).

**App shell and design system**
- `AppState`: `container`, `settingsStore`, `selectedTab`, `transactionFilter` (a `var`, already used as an Insights→Transactions handoff), `dataRevision`, `mutate()`, `moneyFormat(locale:)`.
- `RootTabView` owns the four `NavigationStack`s; Task 12 replaces only the `.transactions` branch with `TransactionsView` (ruling 50 for Task 11 shows the pattern).
- `BalanceHero`, `SectionCard(title) { }`, `MoneyText`, `CategoryBadge`, `Theme`, `ChartCard`.
- `UITestSupport.prepare` and `DashboardFixture` are the existing fixture pattern; extend `-UITestSeed` with whatever Task 12's UI test needs without breaking `OverviewUITests` (which asserts the current fixture's balance/categories/recent rows).
- `Localizable.xcstrings` manual keys; add new keys for every new string.

### Task 12 rulings to apply

- **Ruling 30 (Task 9) — `AppState.transactionFilter` is additively extendable.** Task 12 may extend `TransactionFilter` with new fields.
- **Ruling 54 — no second `TransactionFilter`.** The brief says `Create: ZentriApp/Transactions/TransactionFilter.swift`, but Task 9 already ships `ZentriApp/App/TransactionFilter.swift`. Extend that file in place with `engine: ParseEngine?` and `dateRange: DateRange?` (or equivalent). Do not create a duplicate type or file.
- **Ruling 55 — the mutation service is async.** `save`/`delete`/`setTransfer` are `async throws`, not the brief's synchronous `throws`, because `WidgetSnapshotRefresher.refresh()` is `async` and a detached `Task` would make the snapshot race the `dataRevision` bump.

### Task 12 review focus

- List: day sections newest first, stable IDs, merchant/category/account/amount with direction color; sticky day headers.
- Search matches merchant, note, **and raw SMS text**.
- Filters: account, category, direction, date range, engine.
- Detail: all fields, category picker, transfer toggle, raw SMS, engine/matched rule, note, reprocess action.
- Edit and delete with confirmation; edits recompute the balance (the mutation service must refresh the snapshot, and the caller must `mutate()` so Overview reloads).
- Manual add marks the source `.manual`; invalid amounts and missing accounts are rejected.
- Editing must preserve the raw-message link; delete must never delete the raw message.
- Category change sets `categorySource = .manual`; "Always categorize this merchant as…" creates a `CategorizationRule`.
- Empty state explains that SMS ingestion will populate the list.
- SwiftUI Pro compliance: modern APIs, Dynamic Type, VoiceOver, 44pt targets, localized strings, no deprecated API, no `UIScreen.main`.

---

## 6. SDD workflow commands

```bash
cd /Users/farhantamzid/code/zentri

# 1. Workspace / ledger
bash /Users/farhantamzid/.commandcode/skills/subagent-driven-development/scripts/sdd-workspace \
  docs/superpowers/plans/2026-11-14-zentri-implementation.md

# 2. Task brief
bash /Users/farhantamzid/.commandcode/skills/subagent-driven-development/scripts/task-brief \
  docs/superpowers/plans/2026-11-14-zentri-implementation.md 12

# 3. Review package (BASE recorded before the dispatch; never HEAD~1)
bash /Users/farhantamzid/.commandcode/skills/subagent-driven-development/scripts/review-package \
  docs/superpowers/plans/2026-11-14-zentri-implementation.md BASE HEAD

# 4. Focused/full core tests
swift test --package-path ZentriCore

# 5. Generate and build
xcodegen generate
xcodebuild -project Zentri.xcodeproj -scheme ZentriApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project Zentri.xcodeproj -scheme ZentriWidgets \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# 6. App unit tests and UI tests
xcodebuild test -project Zentri.xcodeproj -scheme ZentriApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ZentriAppTests
xcodebuild test -project Zentri.xcodeproj -scheme ZentriApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ZentriUITests/TransactionsUITests
```

**Important:** `Zentri.xcodeproj` is generated and git-ignored. Run `xcodegen generate` after checkout or after adding files/resources. XcodeGen is installed via Homebrew.

**Simulators:** Xcode 27.2 provides `iPhone 17`, `iPhone Duo`, `iPad Pro 11-inch (M5)`, etc., on iOS 27.2.

**Signing:** Simulator builds work without a team. Device/IPA builds and home-screen widgets require App Groups, which require the paid Apple Developer team selected in Xcode. The Mac has a free account; the user has a paid account for iPhone testing. Do not claim device/widget success until that team is selected and the device checklist is run.

---

## 7. Rulings made so far (carry forward)

These are decisions made on the user’s behalf. Preserve them unless the user says otherwise, and record any new ruling in the ledger.

1. **Feature branch, not a worktree** — the available worktree tool requires an explicit user request; `feature/zentri-v1` keeps `main` untouched. Cost if wrong: none; can move to a worktree later.
2. **Session default model for subagents** — the harness does not expose explicit model names to the controller. Cost if wrong: cost-optimality only.
3. **Task 17 must add `CFBundleURLTypes` for `zentri`** to `ZentriApp/Info.plist` — the spec/plan require `zentri://overview`, `/transactions`, `/insights` widget deep links, and no task currently owns that plist edit. Cost if wrong: one config edit/rebuild.
4. **Task 18 owns the backup UTType/filename check** — verify `.zentri.json` through `fileExporter`/`fileImporter`; if it does not match, use the declared type with a `json` tag and keep the user-facing `Zentri-YYYY-MM-DD-HHmm.json` filename. Cost if wrong: one naming adjustment.
5. **Explicit grouping modes use invariant `en_US_POSIX`** — `.western`/`.indian` deliberately use Latin digits and deterministic `,`/`.` separators; `.system` is the only locale-inheriting mode. Cost if wrong: RTL/Indic-digit users see Latin digits in explicit modes; deterministic grouping was the user’s priority.
6. **Task 10 must expose an ordered currency-code list** for the onboarding picker (extend `CurrencyCatalog` or a single source of truth). Cost if wrong: one small list addition; avoids two drifting lists.
7. **Keep the spec’s model names `Category` and `Transaction`** — in app-target files qualify them as `ZentriCore.Category` / `ZentriCore.Transaction`; do not add module-level typealiases. The collision is a hard compile error, not a silent misbinding. Cost if wrong: noisy qualification; revisit only if sustained friction.
8. **Seed only during onboarding or restore** — never on every launch. Cost if wrong: deleted system categories could reappear or first-run data could be missing.
9. **Accept the validator API correction** — `TransactionValidator.validate` returns `Result<TransactionDraft, TransactionValidationError>` with `.diagnostics`, because `[ParseDiagnostic]` cannot conform to `Error`. Cost if wrong: one signature adjustment.
10. **Accept `TransactionDraft.matchedRuleID`** — additive, consumed by Task 7. Cost if wrong: an unused field.
11. **Task 5 diagnostic codes** — `ParseDiagnostic.Code` now includes `.modelUnavailable`, `.modelFailed`, `.modelTimedOut`, `.cancelled`. Cost if wrong: failure states cannot be expressed.
12. **Date fallback policy** — spec §10.2’s six common formats apply when `dateFormat` is nil; explicit format wins; `receivedAt` is the fallback; parsed years must be 2000...2099. Cost if wrong: pre-2000 dates are treated as unparseable.
13. **Task 7 must sort parsed rules by priority then `createdAt`** before mapping. Cost if wrong: nondeterministic equal-priority selection.
14. **Cancellation is `.cancelled`, not `.modelTimedOut`** — Task 7 must treat `.cancelled` anywhere in the diagnostics (not only `.first`) as retryable `.processing`, and check `Task.isCancelled` itself before persisting; do not rely on hybrid to propagate cancellation. Implemented in Task 7. Cost if wrong: a cancelled parse is archived as ignored/failed and lost.
15. **The 15-second timeout is cooperative** — it cannot hard-abandon a model that ignores cancellation. Code comments and UI copy must not promise a hard deadline. Cost if wrong: misleading UX/copy.
16. **Model amounts are corroborated against a numeric token in the SMS** (value comparison, not digit substring) and the model merchant is capped at 120 characters. Task 7 must not add a second, weaker check. Cost if wrong: a correct amount in an `AmountNormalizer`-unreadable format is rejected; role-aware corroboration is a known follow-up.
17. **Task 8 uses its own DTO and its own settings shape** — the settings document has no migration/date strategy, and backups must exclude the device-specific backup-folder bookmark. Cost if wrong: one DTO adjustment.
18. **Task 13 owns the spec §12.5 peak-day observation** — compute it in core (or an additive helper) with tests and format the date in the UI. Cost if wrong: small additive core work in Task 13.
19. **`SeedData` is the single source for the built-in category names** — it exposes ordered `builtInCategoryNames` and `fallbackCategoryName`; `CategorizationService` reads them. Cost if wrong: one additive edit to the seed file.
20. **Month-over-month insights fields require an exact calendar-month period** — Task 13 must pass `start = first instant of the month`, `end = last instant of the month` (inclusive), not an exclusive end. Cost if wrong: custom rolling-window callers lose deltas. Task 11 already follows this.
21. **Task 7 interface decisions (carry to Tasks 9/15/16/17)**
    - `IngestionOutcome`: `.transaction(UUID)`, `.duplicate`, `.notTransaction`, `.failed([ParseDiagnostic])`.
    - Account resolution: explicit `request.accountID`, else exactly one non-archived account, else `.failed` with an account diagnostic — never a guess.
    - `IngestionService` takes a live `@MainActor @Sendable () -> AppSettings` provider, not a frozen value.
    - Engines already validate; ingestion does not re-validate. `parseEngine` is `.rules` when the draft has a matched rule id, otherwise `.foundationModels`.
    - A successful parse persists the raw message, transaction, and optional `.sms` checkpoint in one save; the checkpoint shares the transaction’s `ingestedAt`, so the SMS balance excludes its own transaction.
    - Duplicates persist a `.duplicate` raw row with no transaction. `.failed` rows are exempt from dedupe, so a retry after failure re-parses.
    - `retryPending()` reuses the existing `.processing` row, ignores itself in dedupe, and leaves the row `.processing` when the account is ambiguous.
    - `FileWidgetSnapshotStore(fileURL: URL?)` accepts the optional from `SharedContainer`; a nil URL makes `read()` nil and `write` a no-op.
    - Snapshot refresh is non-throwing and called exactly once per outcome; a refresh failure never fails ingestion.
    - `WidgetSnapshot` amounts are decimal strings; `TopCategory.share` is a 0–100 percentage and a capped list’s shares do not sum to 100.
    - Cost if wrong: small interface adjustments in the consuming task.
22. **Task 8 `BackupExporter` is a struct initialized with an injected `AppSettings`** — settings live in the App Group JSON, not SwiftData, and the brief’s `export(context:appVersion:)` has no settings parameter. Task 18 constructs it per backup; core must not read `SharedContainer` or `FileSettingsStore`. Cost if wrong: one initializer adjustment in Task 18.
23. **Task 8 importer never writes settings** — `.merge` preserves existing settings by never touching them; `.replace` replaces SwiftData rows only. Task 18 applies `document.settings` through `SettingsStore` for a full restore. Cost if wrong: Task 18 adds one settings save call.
24. **Backup DTOs use string amounts and dates** — money as plain decimal strings, dates ISO-8601 with fractional seconds on encode and both forms accepted on decode. `BackupCodec.decode` and `BackupImporter.import` both run the same whole-document validation. `BackupError.duplicateID` is named exactly. Cost if wrong: one DTO/error naming adjustment.
25. **Backup validation covers structural references only** — checkpoint account/source transaction, transaction account/category/raw message, parsing-rule account, categorization-rule category. `matchedRuleID` is a weak historical reference and must not reject a backup when the rule was deleted. Every account needs a checkpoint. Cost if wrong: a backup with a deleted rule is rejected until relaxed.
26. **`ImportSummary` keeps per-kind counts only** — Task 18 renders §16.2’s schema version and date range from the `BackupDocument` it already holds. Cost if wrong: Task 18 adds two derived summary fields.
27. **Task 8 merge provenance rule** — when an incoming raw message is a UUID/fingerprint duplicate of a stored message that already anchors a transaction, create the incoming transaction without a raw-message link. Never mutate the stored message or its transaction. Cost if wrong: the imported transaction shows no raw SMS until Task 15’s reprocess/link paths exist.
28. **Task 9 onboarding placeholder** — Task 9 showed a placeholder; Task 10 replaced it with the real flow. Cost if wrong: none now.
29. **The deferred Task 3 on-disk test uses a temp-directory `ModelConfiguration(url:)`** with `ZentriSchemaV1` and `ZentriMigrationPlan`; no production API change. Cost if wrong: the test duplicates production’s configuration rather than exercising `ZentriContainer.make`.
30. **`AppState.transactionFilter` is a small `Equatable, Sendable` value** (category/account/direction/search with defaults); Task 12 may extend it additively. Cost if wrong: one additive field set in Task 12.
31. **Settings recovery “Restore backup” is a placeholder until Task 18** — it explains that restore arrives with backup setup; “Use Defaults” works now. Cost if wrong: one button handler change in Task 18.
32. **`-UITestMode` never touches the App Group or the real settings file** — in-memory container, fixture settings repository, `FileWidgetSnapshotStore(fileURL: nil)`. Cost if wrong: UI tests touch shared simulator state.
33. **Task 9 Increase Contrast scope** — high-contrast variants exist for `AccentColor`, `Ink`, `SecondaryInk`, `Income`, `Spending` in light and dark. Category tokens remain static because they pair color with symbol and label; verify the dark high-contrast accent’s filled-button label contrast in Task 19. Cost if wrong: category colors stay static under Increase Contrast.
34. **Task 10 recovery screen path** — extend the existing `ZentriApp/App/SettingsRecoveryView.swift`; don’t create `ZentriApp/Settings/SettingsRecoveryView.swift`. `OnboardingPlaceholderView.swift` was deleted when the real flow landed. Cost if wrong: one file move.
35. **Task 10 seeding stays one save** — `SeedData.insert(into:)` inserts only; `seed(into:)` is `insert` + `save`; the onboarding committer calls `insert` plus the account/checkpoint in one `context.save()`. Cost if wrong: one additive seed API.
36. **Task 10 settings persistence** — the committer persists the given settings through an injected `SettingsRepository` before its single SwiftData save; if the context save throws, it rolls back and restores the prior settings state (delete the new file when there was none). The flow adopts settings in memory only on "Go to Overview". Cost if wrong: one ordering/initializer adjustment.
37. **Task 10 currency list** — `CurrencyCatalog.supportedCurrencyCodes` is the ordered list; the picker uses it; no duplicated app list. Cost if wrong: one catalog edit.
38. **Task 10 rules step** — no full regex editor in onboarding (Task 15 owns it). When Rules is selected, show the explanation and “Add your first rule in Settings → Parsing”. Cost if wrong: spec §12.2 step 5 is partially deferred one task.
39. **Task 10 committer shape** — `@MainActor public struct OnboardingCommitter` with `init(settingsRepository:)` and an instance `commit(...)`; the brief’s static call was adapted because ruling 36 injects the repository. Cost if wrong: one call-site signature change.
40. **`SettingsRepository.remove()`** — added so a failed context save can delete the settings document it just wrote when no prior settings existed. `FileSettingsStore` treats a missing file as success; `InMemorySettingsRepository` clears. Cost if wrong: one protocol method and two conformances.
41. **Committer save seam** — internal `saveHandler` mirrors `IngestionService` so the rollback path is testable; production never assigns it. Cost if wrong: one unused internal seam.
42. **Settings adoption timing** — `SettingsStore` exposes its repository internally; onboarding builds the committer from it and adopts settings in memory only when "Go to Overview" is tapped, so `SetupCompleteView` stays visible before `RootView` swaps to the tabs. Cost if wrong: one transition/initializer adjustment.
43. **Foundation Models availability is informational** — it never blocks Continue; Rules is always selectable. Cost if wrong: one UX rule.
44. **Shortcuts step scope** — a short summary plus "Open Shortcuts" (`shortcuts://`) and Continue; the full guide and test console remain Task 16. Cost if wrong: Task 16 adjusts copy and adds the link target.
45. **Currency codes ordering** — `CurrencyCatalog.supportedCurrencyCodes` is alphabetically sorted; a test pins the list. Cost if wrong: one ordering expectation.
46. **Task 11 `-UITestSeed` fixture** — it also seeds one active account, an `.opening` checkpoint at 1,000,000, one debit and one credit transaction, and one `.failed` raw message. Cost if wrong: one fixture switch/behavior adjustment.
47. **Task 11 health link** — show last message, last success, and failure count now; the inbox link waits for Task 15. Cost if wrong: one link addition.
48. **Task 11 empty state** — "Finish setup" selects the Settings tab; account creation is Task 14. Cost if wrong: one action change.
49. **Task 11 determinism** — `OverviewModel` takes injected `now` and `calendar`; `OverviewModelTests` covers balance, today spend, month totals, top three, recent five, and health with fixed values. Cost if wrong: one initializer/test adjustment.
50. **Task 11 scope** — replace only the `.overview` placeholder. Cost if wrong: one switch branch.
51. **Task 11 7-day chart** — the last seven calendar days including today, via `InsightsPeriod` + `dailySpend`, with a per-day accessibility summary and a table-like VoiceOver alternative. Cost if wrong: one period/accessibility adjustment.
52. **Task 11 health definitions** — `lastMessageAt` = newest `RawMessage.receivedAt`; `lastSuccessAt` = newest `.parsed` message’s `ingestedAt`; `failureCount` = `.failed` count only. Cost if wrong: one definition adjustment.
53. **Task 11 ordering** — recent list = five newest for non-archived accounts by `occurredAt` (ties by id), transfers included in the list but excluded from totals; top categories = the month summary’s first three. Cost if wrong: one ordering/filter adjustment.
54. **Task 12 has no second `TransactionFilter`** — the brief’s `Create: ZentriApp/Transactions/TransactionFilter.swift` predates Task 9’s shell, which already ships `ZentriApp/App/TransactionFilter.swift`. Extend that file in place additively (`engine`, `dateRange`). Cost if wrong: one file move.
55. **Task 12 mutation service is `async`** — `save`/`delete`/`setTransfer` are `async throws` because `WidgetSnapshotRefresher.refresh()` is `async` and a detached `Task` would race the `dataRevision` bump. Cost if wrong: one call-site signature change.
56. **A failed store read must never render as "no data"** — `OverviewModel` distinguishes `.loading`/`.loaded`/`.failed`, and a failed `RawMessage` read fails the whole dashboard rather than silently reporting "Never / Never / 0". Carry this pattern to any later screen that reads the store. Cost if wrong: a transient read failure shows a retry screen instead of the balance.
57. **The Overview 7-day chart is read-only** — §13.4’s chart interaction belongs to Task 13’s Insights screen, which §12.5 pairs with "tap to filter transactions". Cost if wrong: Task 13 adds charts it already owns; no Overview rework.

---

## 8. Carry-forward notes by task

These are deferred minors and cross-task requirements from completed reviews. Triage them during the relevant task or at the final review; do not silently drop them.

### Task 11 — overview (complete; 18 minors deferred)
- `DashboardFixture`’s doc comment claims the UI test computes expectations from "the same numbers", but the test restates the literals and cannot import the app target. Say they are hand-synced.
- `OverviewTransaction` re-declares `TransactionSnapshot` field-for-field minus `accountID` for one computed property.
- Each refresh computes three full insights summaries, so the today and 7-day calls build and discard six months of history, merchant totals, largest transactions, and observations.
- The 7-day chart has no direct labels on key values; seven abbreviated weekday labels are dense at one phone width.
- The failure count and the category share use bare numeric `Text` instead of `MoneyText` (neither monospaced nor Reduce-Motion gated).
- The chart’s `"Day"`/`"Spent"` plottable labels have no catalog key; a manual catalog never extracts them.
- A recent row’s VoiceOver label omits the transfer tag the row shows visually.
- The UI test’s failure-count assertion splits the combined label and compares its last token.
- Two chart assertions are near-vacuous — the per-day check holds even if every day carried the debit amount.
- The change adds 15 files under `ZentriApp/Overview/` where the brief named 4 (one type per file is the project convention).
- The category read remains a silent `try?` degrading to `TransactionSnapshot` defaults — deliberate and tested.
- The failure screen has no end-to-end UI coverage; inducing a real container failure needs failure injection.
- The failure branch drops the last good summary instead of keeping it under an error banner; retry has no backoff.
- The caught read error is discarded with no diagnostic; `ZentriApp` has no logging facility at all.
- `OverviewStoreReads` exposes its three reads as `var` where `let` would close an unused mutation surface.
- `OverviewModel` has two initializers, one existing only to wrap `OverviewStoreReads`.
- New catalog keys are appended, so the file’s alphabetical ordering breaks; catalog translations exist for English only.

### Task 12 — transactions
- Qualify `ZentriCore.Transaction` / `ZentriCore.Category`.
- Search/filter/group by day; detail with raw SMS; edit/delete; transfer toggle; manual add; category override offers “always categorize this merchant”.
- Mutation service refreshes snapshot and bumps `dataRevision`; the caller must also refresh the Overview (it watches `dataRevision`).
- Extend `TransactionFilter` additively (ruling 54).
- The mutation service is `async` (ruling 55).
- The existing `-UITestSeed` fixture feeds `OverviewUITests`; extend it without breaking those assertions.

### Task 13 — insights
- Inject a fixed calendar into `InsightsCalculator`; pass a month period whose `end` is the month’s last instant (ruling 20).
- Implement the spec §12.5 peak-day observation (ruling 18).
- Month selector, daily chart, category donut/list, top merchants, six-month income/expense, largest transactions.
- Interactive chart selection + tap-to-filter-transactions belongs here (ruling 57).
- Insights minors from Task 6: `changePercent == nil` conflates “no previous-month spend” with “period is not a calendar month”; observations are English literals; a category dropping to zero produces no observation; `largestTransactions` includes credits; the observation cap is 3 category sentences plus the merchant sentence; rounding can call a −0.4% change “unchanged”.
- Drill-down sets `AppState.transactionFilter` and switches to Transactions.
- Accessibility summaries.

### Task 14 — settings/accounts/categories
- Account create/rename/archive/set balance; manual checkpoint.
- Category add/rename/reorder/delete (reassign to Other); keyword rules.
- Currency change shows “Amounts are not converted” warning.
- Grouping live preview.
- Wire Parsing/Backup/Shortcuts/Face ID to later tasks; placeholders until then.
- Reuse the existing `SettingsRecoveryView` if settings recovery is revisited.
- Consolidate `SettingsStore.reset()` onto `repository.remove()` and drop the injected delete closure if this task opens `ZentriApp.swift` (Task 10 minor).
- A rename of the `Other` category still leaves `TemplateSnapshot`-style defaults in place; the Overview resolves the live category by name, so consider whether renames should also update `fallbackCategoryName`.

### Task 15 — rules/tester/raw inbox
- RegexValidator compiles and requires an `amount` group; Save disabled otherwise.
- Rule editor: account, direction, pattern, flags, priority, optional date format, named-group cheat sheet, highlighted captures, extracted fields.
- Tester: side-by-side model, timing, availability status; no persistence.
- Run regex work off the main actor or bound pathological backtracking.
- Raw inbox: filters, detail, reprocess only after success, clear archive keeps transactions.
- Reprocess needs an account affordance: `retryPending()` cannot resolve an account when several are active.
- A retry whose save fails currently leaves two archive rows.
- Localize diagnostics through the app layer/String Catalog.
- `retryPending()` fetches every `RawMessage` and filters in memory; a predicate would be O(pending).
- The health card’s “link to inbox” (ruling 47) gets wired here.

### Task 16 — CaptureSMSIntent
- App Intent parameters: text, optional account/sender/messageDate.
- Handler uses `ParserFactory` + `LiveWidgetSnapshotRefresher`; tests inject stubs.
- Construct `IngestionService` with a live settings provider (`{ settingsStore.settings }`), not a snapshot.
- Missing onboarding → “Open Zentri to finish setup.”
- `.cancelled` retry handling.
- Widget reload after success; fetch the transaction by the id in `.transaction(UUID)` for the dialog.
- Shortcuts setup guide with five steps, “Open Shortcuts”, test-console link, troubleshooting; link the onboarding Shortcuts step to the full guide (ruling 44).
- Manual device test with the paid team.

### Task 17 — widgets
- Add `CFBundleURLTypes` for `zentri` to `ZentriApp/Info.plist` (ruling 3).
- `WidgetDisplayModel` lives in core and is tested there; use `FileWidgetSnapshotStore(fileURL: SharedContainer.widgetSnapshotURL)`. No separate duplicate loader.
- Parse snapshot decimal strings with an `en_US_POSIX` locale (or add an additive core decode helper — none exists).
- `TopCategory.share` is 0–100; a capped list’s shares do not sum to 100.
- Delete `PlaceholderWidget.swift`; one widget file per widget.
- Balance, Trend, Recent Transactions, Categories, Accessory; configurable hide-amounts/trend period.
- Missing/corrupt snapshot → placeholder; tinted/redacted/full-color; deep links; `.containerBackground`.
- Build the extension and manually add widgets in Simulator; device requires the paid team.

### Task 18 — backup UI/iCloud
- Security-scoped bookmark to a user-picked folder; coordinated atomic writes; rotate 10.
- `fileExporter`/`fileImporter` with the exported backup UTType; verify `.zentri.json`.
- Restore browser with counts/dates; replace/merge confirmation.
- Apply `document.settings` through `SettingsStore` on a full restore (ruling 23); “Restore backup” from settings recovery links here.
- Scheduler debounced 2s + on background; permission/space errors preserve the previous snapshot.
- Plain-JSON warning; backups include raw SMS.
- `BackupExporter(settings:)` is constructed per backup (ruling 22).

### Task 19 — Face ID/accessibility/final
- `BiometricAuthenticating` + `LocalAuthenticationService` + `AppLockController`; optional Face ID, default off; privacy cover on background. Onboarding already persists `faceIDEnabled`; Task 19 enforces it.
- Dynamic Type, VoiceOver, Reduce Motion/Transparency, Increase Contrast, 44pt, iPhone Duo/iPad.
- Verify category tokens under Increase Contrast and the dark high-contrast accent’s tinted-button labels (ruling 33).
- Fix `SettingsRecoveryView` overflow at AX5 if not already addressed; review the Task 10 accessibility minors.
- README: XcodeGen, signing, App Group/widget paid team, Shortcuts steps, backup/restore, privacy.
- Full verification: `swift test`, app tests on iPhone 17/Duo, iPad accessibility, widget build.
- Device checklist: real SMS automation, background ingestion, delete/reinstall restore, Face ID, accessibility, widgets.

### Final-review polish (deferred minors from Tasks 4–11)
- `normalized`/whitespace-collapse expressions are duplicated across `CategorizationService`, `InsightsCalculator`, `Dedupe`, and `IngestionService`.
- Untested tie-breaks/caps: lexicographic keyword/category tie-breaks, blank category rejection, `limit + 1` caps.
- `IngestionService` is 772 lines with ~6 responsibilities; the pure merchant sanitizer is the clean extraction.
- Silent catches: `WidgetSnapshotRefresher` catch has no log; six `try? context.fetch(...) ?? []` sites conflate fetch failure with no rows.
- `ZentriContainer` gained a `public` protection overload used only in-module; should be `internal`.
- `WidgetSnapshotBuilder` re-hardcodes the Other styling duplicated in `TransactionSnapshot` defaults and `SeedData`.
- The merchant-noise date regex can strip real words (“on 5th Ave”, “on 12 Main”).
- A retried success stamps `recordedAt` with the retry instant; checkpoint ordering ambiguity if another message wrote a checkpoint during the interruption.
- The storage-failure test fetches through the same context that rolled back; a fresh `ModelContext` would close the loop.
- Backup: `BackupSettings` is a hand-maintained mirror of `AppSettings` with no drift guard.
- Backup: export/encode never validate the document they write.
- Backup: ISO-8601 export truncates dates to milliseconds; sub-millisecond precision is lost on restore.
- Backup: per-value `ISO8601DateFormatter` allocation and double date parsing on the main actor.
- Backup: `BackupImporterTests` has one assertion that compares the fixture settings to itself; fixture helpers are duplicated across the two backup test files.
- Backup: merge’s “message skipped because its UUID is stored” branch is untested.
- Backup validation does not reject two transactions naming the same raw message or duplicate raw-message fingerprints.
- App: the Application Support settings fallback is unreachable and would desync the widget if it ran.
- App: container/settings load errors are discarded without a diagnostic.
- App: every `Localizable.xcstrings` key is `extractionState: "manual"`; automatic extraction would refresh keys.
- App: the canvas-background idiom is duplicated in five views; extract into the design system.
- App: `SettingsRecoveryView` can overflow at AX5 with no scroll affordance.
- App: `AppStateTests` exercises the retry counter, not the ingestion pipeline.
- App: app-wide `AppState.selectedTab` is shared across iPad/Duo windows; move window-specific selection to scene state.
- App: `AppIcon.appiconset` is empty; replace before submission.
- App: dark high-contrast accent tinted-button label contrast needs a screenshot pass.
- Onboarding balance parsing diverges from `AmountNormalizer`; reconcile the two normalizers.

---

## 9. Known gotchas / constraints

- **No direct SMS access.** The Shortcuts automation is user-created; the app cannot install it. The setup guide and test console are essential.
- **App Groups require a paid team on device.** Simulator is fine; home-screen widgets on the iPhone require the paid account selected in Xcode.
- **`ZentriCore.Transaction` / `ZentriCore.Category`** are ambiguous with SwiftUI/Objective-C names; qualify them in app-target files.
- **`FoundationModels` is conditional.** `swift test` on macOS may compile it or not; always run the iOS app build to compile the live client.
- **AppIntents metadata warning** is expected until Task 16 adds App Intents.
- **Generated project is ignored.** Run `xcodegen generate`; do not hand-edit `Zentri.xcodeproj`.
- **Xcode rewrites `Localizable.xcstrings` on build.** It reformats to `"key" : value` and auto-extracts empty entries. Restore with `git checkout --` rather than committing the churn.
- **No third-party runtime dependencies.** XcodeGen is build tooling only.
- **Do not commit to `main`.** Implementation stays on `feature/zentri-v1` until the user approves finishing.
- **Do not delete the SDD workspace** until the plan is finished and the final review is clean; it holds the ledger/reports.
- **`docs/HANDOFF.md` is untracked** and does not appear in review packages. Update it at checkpoints, not every task.
- **No secrets or network.** All parsing/storage on-device; backup folder access is user-granted.
- **Test seams stay internal:** `IngestionService.saveHandler`, `OnboardingCommitter.saveHandler`, `OverviewStoreReads`. Production never assigns them.
- **Backup settings ownership:** the importer never writes settings; Task 18 applies `document.settings`. The exporter receives settings through its initializer.
- **Backup dates are millisecond-precision ISO-8601 strings.** Sub-millisecond `Date` values do not round-trip exactly.
- **UI-test mode is isolated:** `-UITestMode` uses an in-memory container/settings and a nil snapshot URL. Never let a UI test touch the App Group.
- **`-UITestSeed` is now richer than categories/rules:** it also seeds an account, opening checkpoint, two transactions, and a failed raw message (ruling 46). Task 12 extends it further — keep `OverviewUITests` green.
- **`Localizable.xcstrings` extraction state is manual.** Add new keys when adding user-facing strings; English fallback can hide a missing key. New keys are appended, so the file is not alphabetized.
- **The asset catalog needs `AppIcon.appiconset` to compile.** It is empty today; replace it before submission.
- **Increase Contrast:** only the five text/semantic color sets have high-contrast variants; category tokens do not.
- **Onboarding balance parsing is locale-aware** (grouping first, then decimal), but `MoneyFormat`’s explicit modes always render `.` decimals.
- **Onboarding has 20 small view files** by design (SwiftUI Pro one-type-per-file); the Overview follows the same convention and now has 17.
- **Fixture expected values:** `-UITestSkipOnboarding` saves `AppSettings.defaultValue` (USD, Western), so UI tests must assert the formatted fixture balance computed from those settings; do not assume BDT/Indian.
- **Settings deletion has two paths:** `SettingsStore.reset()` uses its closure, while `SettingsRepository.remove()` exists for the committer. Consolidate when a task next opens `ZentriApp.swift`.

---

## 10. Final definition of done

- All 19 plan tasks implemented and independently reviewed.
- Final whole-branch review via `requesting-code-review` on the most capable model; deferred minors triaged.
- `swift test --package-path ZentriCore` green; app/UI tests green on iPhone 17, iPhone Duo, and iPad accessibility; widget extension builds.
- Device checklist from the spec passes with the paid team (real SMS → automation → transaction; widget reload; delete/reinstall restore; Face ID; accessibility; tinted/redacted widgets).
- README written.
- Use `finishing-a-development-branch` and let the user choose merge/handoff.
- Collect all `Ruling:` lines from the ledger into the final message under “Rulings I made,” with cost-if-wrong.

---

## 11. Quick resume checklist

```bash
cd /Users/farhantamzid/code/zentri
git status --short --branch
git log --oneline -10
cat docs/HANDOFF.md
cat .superpowers/sdd/2026-11-14-zentri-implementation/progress.md
swift test --package-path ZentriCore
```

Then:
1. Activate `subagent-driven-development`.
2. Confirm Task 12 status in the ledger (it has `BASE 5f49e81` and rulings 54–55, but no `Task 12: complete` line).
3. Read `.superpowers/sdd/2026-11-14-zentri-implementation/task-12-brief.md` and dispatch its implementer with the Task 12 rulings and interfaces in §5.
4. Review, fix, and continue Task 13 onward without pausing between tasks.
