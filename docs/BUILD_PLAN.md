# SubTrack — Build Plan

**Status:** Ready to execute — no code written yet
**Last updated:** 2026-09-03
**Companion docs:** [PRD.md](PRD.md) · [ADR.md](ADR.md) · [ARCHITECTURE.md](ARCHITECTURE.md)

Work top to bottom. Each milestone ends in a compiling, testable state. Do not
start a milestone before the one above it is green.

Ground rules (from [ADR.md](ADR.md#master-architectural-constraints-include-in-every-agent-prompt)):
inward-only dependencies (`presentation → domain ← data`); `domain/` imports no
Flutter / `sqflite` / `flutter_riverpod`; entities & models immutable; no DB
calls in widgets; one state emission per mutation.

---

## M0 — Project setup & dependencies

- [ ] Add to `pubspec.yaml` dependencies: `flutter_riverpod`, `sqflite`, `path`,
      `path_provider`, `intl`.
- [ ] Add dev dependencies: `sqflite_common_ffi` (desktop + test DB backend).
- [ ] (Optional) `freezed_annotation` + dev `freezed`, `build_runner` — only if
      choosing `freezed` over hand-written `copyWith`. Default: hand-written.
- [ ] `flutter pub get`; confirm `flutter analyze` is clean on the template.
- [ ] Create the folder skeleton from
      [ARCHITECTURE.md §1](ARCHITECTURE.md#1-architecture-style-feature-first-clean-architecture)
      (`lib/app`, `lib/core/{database,constants,utils}`,
      `lib/features/subscriptions/{data,domain,presentation}`).
- [ ] Delete the template counter app; leave `main.dart` minimal.

**Done when:** `flutter run` shows a blank scaffold; `flutter test` passes (no tests yet).

---

## M1 — Core constants & utils (pure)

- [ ] `core/constants/enums.dart` — `BillingCycle`, `Category` with
      string (de)serialization + safe fallbacks ([PRD §3.2](PRD.md#32-enums)).
- [ ] `core/constants/subscription_icons.dart` — id → `IconData` catalog,
      `Category` → default icon id, lookup with fallback
      ([PRD §3.2a](PRD.md#32a-icon-catalog)).
- [ ] `core/utils/currency_formatter.dart` — `intl` `NumberFormat.currency`
      wrapper, single app-level locale/symbol constant ([PRD §4.2](PRD.md#42-currency-display)).
- [ ] `core/utils/due_date_formatter.dart` — relative label from a date + "today"
      ([PRD §4.3](PRD.md#43-list-sorting--date-handling) table).
- [ ] **Tests:** enum fallbacks; icon fallback; currency formatting
      (`$14.99`, `$1,200.00`); every due-date label branch (overdue, today,
      tomorrow, in-N-days, future date).

**Done when:** all util/constant tests green.

---

## M2 — Domain layer (pure Dart)

- [ ] `domain/entities/subscription.dart` — immutable, `copyWith`, value equality
      ([PRD §3.1](PRD.md#31-entity-subscription), [§3.4](PRD.md#34-model-contract-dart)).
- [ ] `domain/repositories/subscription_repository.dart` — abstract interface:
      `getAll()`, `add()`, `update()`, `delete(id)`.
- [ ] `domain/usecases/calculate_burn_rate.dart` — pure function
      `List<Subscription> → (monthly, yearly, count)` ([PRD §4.1](PRD.md#41-financial-calculation-engine)).
- [ ] `domain/usecases/get_upcoming_bills.dart` — sort ascending by
      `nextDueDate`, tie-break by name.
- [ ] `domain/usecases/{add,update,delete}_subscription.dart` — thin wrappers
      over the repository (validation lives here or in the entity factory).
- [ ] **Tests:** burn rate for empty / monthly-only / yearly-only / mixed;
      yearly/12 precision (no rounding drift); sort + tie-break ordering.

**Done when:** domain tests green; `grep` confirms no `flutter`/`sqflite`/`riverpod`
import under `domain/`.

---

## M3 — Data layer

- [ ] `core/database/app_database.dart` — open/create `subtrack.db` in the
      documents dir, `onCreate` DDL ([PRD §3.3](PRD.md#33-sqlite-table-reference-ddl)),
      `onUpgrade` switch, schema version `1`. FFI init path for desktop/tests.
- [ ] `data/models/subscription_model.dart` — `fromMap` / `toMap`,
      `snake_case` ↔ `camelCase`, enum + icon string handling, `id` omitted on
      insert; `toEntity()` / `fromEntity()`.
- [ ] `data/datasources/subscription_local_data_source.dart` — raw CRUD SQL.
- [ ] `data/repositories/subscription_repository_impl.dart` — implements the
      domain interface; maps model ⇄ entity; the only mapping site.
- [ ] **Tests (against `sqflite_common_ffi` in-memory):** insert→getAll round-trip;
      update; delete; malformed/unknown enum & icon rows still load;
      `cost > 0` CHECK enforced.

**Done when:** repository tests green.

---

## M4 — State layer (Riverpod)

- [ ] Providers: `appDatabaseProvider` (overridden), `...LocalDataSourceProvider`,
      `subscriptionRepositoryProvider`
      ([ARCHITECTURE.md §2](ARCHITECTURE.md#2-adr-005--state-management-details)).
- [ ] `SubscriptionsState` immutable value object (list + monthly + yearly + count).
- [ ] `SubscriptionNotifier extends AsyncNotifier<SubscriptionsState>` —
      `build()` loads + computes; `addSubscription` / `updateSubscription` /
      `deleteSubscription` call use cases then emit once.
- [ ] `main.dart` — `WidgetsFlutterBinding.ensureInitialized()`, open DB,
      `ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)])`.
- [ ] **Tests:** notifier starts in loading→data; add/update/delete produce one
      `AsyncData` emission with recomputed totals; DB error → `AsyncError`.

**Done when:** notifier tests green.

---

## M5 — Dashboard UI ([PRD §5.1](PRD.md#51-screen-1--dashboard-dashboard_screendart))

- [ ] `app/theme/app_theme.dart` — M3 light + dark `ColorScheme` (seeded),
      `ThemeMode.system`, overdue/warning color roles.
- [ ] `presentation/screens/dashboard_screen.dart` — `ConsumerWidget`; renders
      `AsyncValue` loading / error / data; `Scaffold` + FAB.
- [ ] `presentation/widgets/expense_summary_card.dart` — `M_total`, `A_total`,
      count; formatted via `currency_formatter`.
- [ ] `presentation/widgets/subscription_tile.dart` — icon, name, category tag,
      cost, cycle, due date + relative label with color; `Dismissible` +
      confirm dialog on swipe; tap → edit sheet.
- [ ] Empty state widget.
- [ ] **Tests:** widget test — empty state renders; a seeded list shows correct
      totals and ordering; swipe shows confirm dialog.

**Done when:** dashboard renders real data in light + dark.

---

## M6 — Add / Edit sheet ([PRD §5.2](PRD.md#52-screen-2--add--edit-modal-add_edit_subscription_sheetdart))

- [ ] `presentation/widgets/icon_picker.dart` — single-select scrollable grid
      over the §3.2a catalog.
- [ ] `presentation/widgets/add_edit_subscription_sheet.dart` — `Form` with
      name / cost / segmented cycle / category dropdown / icon picker / date
      picker; add vs edit by whether a `Subscription` is passed.
- [ ] Validation: name (trim, non-empty, ≤30); cost (positive double, reject
      `0`/neg/`NaN`/`Infinity`, strip symbols); date range today−1y…today+5y;
      icon must be a catalog id.
- [ ] Icon default-tracking behavior ([PRD §5.2 Behavior](PRD.md#52-screen-2--add--edit-modal-add_edit_subscription_sheetdart)).
- [ ] Save → notifier method → close; Cancel → close, no mutation. Disable Save
      while writing (no double-insert).
- [ ] **Tests:** widget tests for each validation rule; add path adds a row +
      updates totals; edit path preserves `id`; cancel mutates nothing;
      category change moves the icon until an explicit pick.

**Done when:** full add/edit/delete loop works with no app restart.

---

## M7 — Polish & Definition of Done

- [ ] Walk the [PRD §9 Definition of Done](PRD.md#9-definition-of-done) checklist.
- [ ] Persistence across cold restart verified manually on one desktop + one
      mobile target.
- [ ] Confirm zero network code: no `http`/`dio`, no analytics, no cloud SDK;
      Android manifest has no `INTERNET`-dependent features added.
- [ ] Large-value / long-name card layout doesn't overflow.
- [ ] "Today" recomputed on app resume (labels don't go stale).
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] Update [README.md](../README.md) with a one-paragraph description + run/test
      commands.

**Done when:** every DoD box is checked.

---

## Test matrix summary

| Layer | Kind | Backend |
| --- | --- | --- |
| `core/utils`, `core/constants` | unit | none (pure) |
| `domain/usecases`, `domain/entities` | unit | none (pure) |
| `data/*` | integration | `sqflite_common_ffi` in-memory |
| `presentation/controllers` | unit | fake/in-memory repository |
| `presentation/screens`, `presentation/widgets` | widget | `ProviderScope` with overrides |
