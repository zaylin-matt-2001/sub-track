## M0 — Project setup & dependencies

- [x] Add to `pubspec.yaml` dependencies: `flutter_riverpod`, `sqflite`, `path`,
      `path_provider`, `intl`.
- [x] Add dev dependencies: `sqflite_common_ffi` (desktop + test DB backend).
- [x] (Optional) `freezed_annotation` + dev `freezed`, `build_runner` — only if
      choosing `freezed` over hand-written `copyWith`. Default: hand-written.
- [x] `flutter pub get`; confirm `flutter analyze` is clean on the template.
- [x] Create the folder skeleton from
      [ARCHITECTURE.md §1](ARCHITECTURE.md#1-architecture-style-feature-first-clean-architecture)
      (`lib/app`, `lib/core/{database,constants,utils}`,
      `lib/features/subscriptions/{data,domain,presentation}`).
- [x] Delete the template counter app; leave `main.dart` minimal.

**Done when:** `flutter run` shows a blank scaffold; `flutter test` passes (no tests yet).

---

## M1 — Core constants & utils (pure)

- [x] `core/constants/enums.dart` — `BillingCycle`, `Category` with
      string (de)serialization + safe fallbacks ([PRD §3.2](PRD.md#32-enums)).
- [x] `core/constants/subscription_icons.dart` — id → `IconData` catalog,
      `Category` → default icon id, lookup with fallback
      ([PRD §3.2a](PRD.md#32a-icon-catalog)).
- [x] `core/utils/currency_formatter.dart` — `intl` `NumberFormat.currency`
      wrapper, single app-level locale/symbol constant ([PRD §4.2](PRD.md#42-currency-display)).
- [x] `core/utils/due_date_formatter.dart` — relative label from a date + "today"
      ([PRD §4.3](PRD.md#43-list-sorting--date-handling) table).
- [x] **Tests:** enum fallbacks; icon fallback; currency formatting
      (`$14.99`, `$1,200.00`); every due-date label branch (overdue, today,
      tomorrow, in-N-days, future date).

**Done when:** all util/constant tests green.

---

## M2 — Domain layer (pure Dart)

- [x] `domain/entities/subscription.dart` — immutable, `copyWith`, value equality
      ([PRD §3.1](PRD.md#31-entity-subscription), [§3.4](PRD.md#34-model-contract-dart)).
- [x] `domain/repositories/subscription_repository.dart` — abstract interface:
      `getAll()`, `add()`, `update()`, `delete(id)`.
- [x] `domain/usecases/calculate_burn_rate.dart` — pure function
      `List<Subscription> → (monthly, yearly, count)` ([PRD §4.1](PRD.md#41-financial-calculation-engine)).
- [x] `domain/usecases/get_upcoming_bills.dart` — sort ascending by
      `nextDueDate`, tie-break by name.
- [x] `domain/usecases/{add,update,delete}_subscription.dart` — thin wrappers
      over the repository (validation lives here or in the entity factory).
- [x] **Tests:** burn rate for empty / monthly-only / yearly-only / mixed;
      yearly/12 precision (no rounding drift); sort + tie-break ordering.

**Done when:** domain tests green; `grep` confirms no `flutter`/`sqflite`/`riverpod`
import under `domain/`.

---

## M3 — Data layer

- [x] `core/database/app_database.dart` — open/create `subtrack.db` in the
      documents dir, `onCreate` DDL ([PRD §3.3](PRD.md#33-sqlite-table-reference-ddl)),
      `onUpgrade` switch, schema version `1`. FFI init path for desktop/tests.
- [x] `data/models/subscription_model.dart` — `fromMap` / `toMap`,
      `snake_case` ↔ `camelCase`, enum + icon string handling, `id` omitted on
      insert; `toEntity()` / `fromEntity()`.
- [x] `data/datasources/subscription_local_data_source.dart` — raw CRUD SQL.
- [x] `data/repositories/subscription_repository_impl.dart` — implements the
      domain interface; maps model ⇄ entity; the only mapping site.
- [x] **Tests (against `sqflite_common_ffi` in-memory):** insert→getAll round-trip;
      update; delete; malformed/unknown enum & icon rows still load;
      `cost > 0` CHECK enforced.

**Done when:** repository tests green.

---

## M4 — State layer (Riverpod)

- [x] Providers: `appDatabaseProvider` (overridden), `...LocalDataSourceProvider`,
      `subscriptionRepositoryProvider`
      ([ARCHITECTURE.md §2](ARCHITECTURE.md#2-adr-005--state-management-details)).
- [x] `SubscriptionsState` immutable value object (list + monthly + yearly + count).
- [x] `SubscriptionNotifier extends AsyncNotifier<SubscriptionsState>` —
      `build()` loads + computes; `addSubscription` / `updateSubscription` /
      `deleteSubscription` call use cases then emit once.
- [x] `main.dart` — `WidgetsFlutterBinding.ensureInitialized()`, open DB,
      `ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)])`.
- [x] **Tests:** notifier starts in loading→data; add/update/delete produce one
      `AsyncData` emission with recomputed totals; DB error → `AsyncError`.

**Done when:** notifier tests green.

---

## M5 — Dashboard UI ([PRD §5.1](PRD.md#51-screen-1--dashboard-dashboard_screendart))

- [x] `app/theme/app_theme.dart` — M3 light + dark `ColorScheme` (seeded),
      `ThemeMode.system`, overdue/warning color roles.
- [x] `presentation/screens/dashboard_screen.dart` — `ConsumerWidget`; renders
      `AsyncValue` loading / error / data; `Scaffold` + FAB.
- [x] `presentation/widgets/expense_summary_card.dart` — `M_total`, `A_total`,
      count; formatted via `currency_formatter`.
- [x] `presentation/widgets/subscription_tile.dart` — icon, name, category tag,
      cost, cycle, due date + relative label with color; `Dismissible` +
      confirm dialog on swipe; tap → edit sheet.
- [x] Empty state widget.
- [x] **Tests:** widget test — empty state renders; a seeded list shows correct
      totals and ordering; swipe shows confirm dialog.

**Done when:** dashboard renders real data in light + dark.

---

## M6 — Add / Edit sheet ([PRD §5.2](PRD.md#52-screen-2--add--edit-modal-add_edit_subscription_sheetdart))

- [x] `presentation/widgets/icon_picker.dart` — single-select scrollable grid
      over the §3.2a catalog.
- [x] `presentation/widgets/add_edit_subscription_sheet.dart` — `Form` with
      name / cost / segmented cycle / category dropdown / icon picker / date
      picker; add vs edit by whether a `Subscription` is passed.
- [x] Validation: name (trim, non-empty, ≤30); cost (positive double, reject
      `0`/neg/`NaN`/`Infinity`, strip symbols); date range today−1y…today+5y;
      icon must be a catalog id.
- [x] Icon default-tracking behavior ([PRD §5.2 Behavior](PRD.md#52-screen-2--add--edit-modal-add_edit_subscription_sheetdart)).
- [x] Save → notifier method → close; Cancel → close, no mutation. Disable Save
      while writing (no double-insert).
- [x] **Tests:** widget tests for each validation rule; add path adds a row +
      updates totals; edit path preserves `id`; cancel mutates nothing;
      category change moves the icon until an explicit pick.

**Done when:** full add/edit/delete loop works with no app restart.

---

## M7 — Polish & Definition of Done

- [x] Walk the [PRD §9 Definition of Done](PRD.md#9-definition-of-done) checklist.
- [ ] Persistence across cold restart verified manually on one desktop + one
      mobile target. _(Code path verified — `AppDatabase.open()` reuses the
      on-disk `subtrack.db` in the app documents dir; full manual device
      verification is out of scope for this sandboxed agent run.)_
- [x] Confirm zero network code: no `http`/`dio`, no analytics, no cloud SDK;
      Android `main` manifest has no `INTERNET` permission.
- [x] Large-value / long-name card layout doesn't overflow.
- [x] "Today" recomputed on app resume (labels don't go stale).
- [x] `flutter analyze` clean; `flutter test` green.
- [x] Update [README.md](../README.md) with a one-paragraph description + run/test
      commands.

**Done when:** every DoD box is checked.

---

## M8 — Database Migration (v1 to v2) & Active/Paused Toggle

- [x] `core/database/app_database.dart`: Bump `schemaVersion` to 2.
- [x] Implement `onUpgrade`: `ALTER TABLE subscriptions ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1`, `ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'USD'`.
- [x] Implement `onUpgrade`: `CREATE TABLE settings` and `CREATE TABLE exchange_rates`.
- [x] Update `Subscription` entity and `SubscriptionModel` to include `isActive` and `currencyCode`.
- [x] Update `CalculateBurnRate` usecase to ignore subscriptions where `isActive == false`.
- [x] Add Active/Paused switch to `AddEditSubscriptionSheet`.
- [x] Dim paused subscriptions in `SubscriptionTile`.
- [x] **Tests:** Verify burn rate ignores paused; DB migration tests if possible; Widget test for the toggle.

---

## M9 — Multi-Currency & Settings Layer

- [x] Create `features/settings` folder structure.
- [x] Implement `SettingsLocalDataSource` (raw sqflite for settings/exchange_rates).
- [x] Implement `SettingsNotifier` and `ExchangeRateNotifier`.
- [x] Update `CalculateBurnRate` to accept `Map<String, double> exchangeRates` and `String baseCurrency`, and apply multiplication.
- [x] Build `SettingsScreen` UI: Base currency picker, and list of text fields to define exchange rates.
- [x] **Tests:** Unit test `CalculateBurnRate` with varied exchange rates; verify fallback to 1.0 when missing.

---

## M9.1 — Base-Currency Display

- [x] Ensure currency symbols update based on the Base Currency setting, not a hardcoded app-wide constant. Dashboard totals and displayed subscription costs now render in the selected base currency (including MMK) using the same static conversion rates as the burn-rate calculation; new subscriptions default to that base currency.

---

## M10 — Auto-Advance Due Dates

- [x] Create `domain/usecases/auto_advance_due_dates.dart`.
- [x] Pure logic: Loop `nextDueDate` forward by 1 month or 1 year repeatedly until it is `≥ today`.
- [x] Update `SubscriptionNotifier.build()` and `refresh()` to invoke `AutoAdvanceDueDates` on all loaded subscriptions.
- [x] Batch update the database for any subscription that was modified.
- [x] **Tests:** Unit test the auto-advance logic (leap years, month-end wrapping, past due by multiple cycles).

---

## M11 — Category Breakdown Chart

- [x] Add `fl_chart` to `pubspec.yaml`.
- [x] Create `domain/usecases/get_category_breakdown.dart` (returns sum of active base-currency cost per Category).
- [x] Build `CategoryChartWidget` using `PieChart` from `fl_chart`.
- [x] Add the chart to `DashboardScreen` (e.g. at the top under the summary card or as a tab/bottom sheet).
- [x] **Tests:** Pure logic test for the breakdown grouping.

---

## M12 — Polish v1.1

- [x] `flutter analyze` clean; `flutter test` green.
- [x] Verify offline constraint is unbroken.

---

## Test matrix summary

| Layer                                          | Kind        | Backend                        |
| ---------------------------------------------- | ----------- | ------------------------------ |
| `core/utils`, `core/constants`                 | unit        | none (pure)                    |
| `domain/usecases`, `domain/entities`           | unit        | none (pure)                    |
| `data/*`                                       | integration | `sqflite_common_ffi` in-memory |
| `presentation/controllers`                     | unit        | fake/in-memory repository      |
| `presentation/screens`, `presentation/widgets` | widget      | `ProviderScope` with overrides |
