# SubTrack — Architecture Specification

**Status:** Accepted — updated for v1.1
**Last updated:** 2026-09-04
**Companion docs:** [PRD.md](PRD.md) · [ADR.md](ADR.md) · [BUILD_PLAN.md](BUILD_PLAN.md)

Formalizes [ADR-005](ADR.md#adr-005-state-management-architecture) (Riverpod) and
[ADR-006](ADR.md#adr-006-code-organization--feature-first-clean-architecture)
(Feature-First Clean Architecture).

---

## 1. Architecture style: Feature-First Clean Architecture

Clear layer boundaries prevent circular dependencies and stop business logic from
being scattered inside UI widgets.

```
lib/
├── app/
│   ├── theme/                # app_theme.dart — M3 ColorScheme, light/dark
│   └── routes/               # (single screen; minimal or omitted in v1)
├── core/
│   ├── database/             # SQLite open/create, migrations, AppDatabase
│   ├── constants/            # enums (BillingCycle, Category), app strings
│   └── utils/                # currency + date formatters (intl wrappers)
└── features/
    ├── settings/             # (New in v1.1)
    │   ├── data/             # Settings & Exchange Rates local data sources
    │   ├── domain/           # Settings Repository, Exchange Rate entities
    │   └── presentation/     # Settings Screen, Notifiers
    └── subscriptions/
        ├── data/
        │   ├── datasources/    # SubscriptionLocalDataSource (raw sqflite)
        │   ├── models/         # SubscriptionModel (Map<String,dynamic> mapping)
        │   └── repositories/   # SubscriptionRepositoryImpl
        ├── domain/
        │   ├── entities/       # Subscription (pure Dart)
        │   ├── repositories/   # SubscriptionRepository (abstract interface)
        │   └── usecases/       # CalculateBurnRate, GetUpcomingBills,
        │                       #   AddSubscription, UpdateSubscription,
        │                       #   DeleteSubscription, AutoAdvanceDueDates,
        │                       #   GetCategoryBreakdown
        └── presentation/
            ├── controllers/    # SubscriptionNotifier (AsyncNotifier) + providers
            ├── screens/        # DashboardScreen
            └── widgets/        # ExpenseSummaryCard, SubscriptionTile,
                                #   AddEditSubscriptionSheet, CategoryChartWidget
```

### Layer responsibility rules

| Layer            | May import                                | Must NOT import                                               | Contains                                                                        |
| ---------------- | ----------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **domain**       | pure Dart only                            | Flutter, `sqflite`, `flutter_riverpod`, any package           | entities, repository interfaces, use cases, business calculations               |
| **data**         | domain, `sqflite`, `path_provider`        | `flutter_riverpod`, presentation, Flutter widgets             | data sources, models, repository implementations; maps rows ↔ models ↔ entities |
| **presentation** | domain, `flutter_riverpod`, Flutter       | `sqflite`, data-layer concretions (except via DI wiring file) | screens, widgets, controllers/notifiers                                         |
| **core**         | `sqflite`, `intl`, `path`/`path_provider` | features, presentation                                        | DB bootstrap, enums, formatters                                                 |
| **app**          | Flutter, presentation                     | data, `sqflite`                                               | theming, root widget                                                            |

- Dependencies point **inward only**: `presentation → domain ← data`.
- The one allowed composition seam: a Riverpod provider file in
  `presentation/controllers/` (or `core/di.dart`) that constructs
  `SubscriptionRepositoryImpl(SubscriptionLocalDataSource(db))` and exposes it as
  a `Provider<SubscriptionRepository>`. Everything else depends on the interface.

---

## 2. ADR-005 — state management details

**`flutter_riverpod` + `AsyncNotifierProvider`.**

### Providers

| Provider                              | Type                                                              | Responsibility                                                                         |
| ------------------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `appDatabaseProvider`                 | `Provider<Database>` (overridden at startup)                      | The open `sqflite` database. Overridden in `ProviderScope` after async open.           |
| `subscriptionLocalDataSourceProvider` | `Provider<SubscriptionLocalDataSource>`                           | Wraps the database.                                                                    |
| `subscriptionRepositoryProvider`      | `Provider<SubscriptionRepository>`                                | Returns `SubscriptionRepositoryImpl`.                                                  |
| `subscriptionNotifierProvider`        | `AsyncNotifierProvider<SubscriptionNotifier, SubscriptionsState>` | Owns the list, selected base currency, conversion inputs, and derived totals; all mutations. Depends on settings for multi-currency. |
| `settingsNotifierProvider`            | `AsyncNotifierProvider<..., SettingsState>`                       | Owns base currency preference.                                                         |
| `exchangeRateNotifierProvider`        | `AsyncNotifierProvider<..., Map<String, double>>`                 | Owns the exchange rates table.                                                         |

### `SubscriptionsState` (presentation state object, immutable)

```
SubscriptionsState {
  List<Subscription> subscriptions;   // already sorted ascending by nextDueDate
  double monthlyBurnRate;             // M_total (in base currency)
  double yearlyBurnRate;              // A_total (in base currency)
  String baseCurrency;                // drives every displayed dashboard amount
  int    count;
}
```

- Exposed to the UI as `AsyncValue<SubscriptionsState>` → the widget renders
  loading / error / data with no custom wrappers.
- `build()` loads all rows via the repository, triggers `AutoAdvanceDueDates`, runs `CalculateBurnRate` (passing exchange rates and base currency) and sort,
  returns the state.
- `addSubscription` / `updateSubscription` / `deleteSubscription`: call the
  matching use case → repository write → re-read (or update the in-memory list)
  → `state = AsyncData(newState)`. A single emission per mutation.
- Since totals depend on exchange rates, `SubscriptionNotifier` watches `exchangeRateNotifierProvider` and `settingsNotifierProvider`.

### Root wiring

```
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const SubTrackApp(),
    ),
  );
}
```

---

## 3. Data flow

```
┌─────────────────────────┐
│      Dashboard UI       │  ConsumerWidget
└───────────┬─────────────┘
            │ ref.watch(subscriptionNotifierProvider) → AsyncValue<SubscriptionsState>
            │ ref.read(...notifier).addSubscription(entity)   (mutations)
            ▼
┌─────────────────────────┐
│  SubscriptionNotifier   │  executes use cases:
│  (presentation)         │  CalculateBurnRate → M_total, A_total; sort by due date
│                         │  depends on Settings + Exchange Rates
└───────────┬─────────────┘
            │ calls domain interface  SubscriptionRepository
            ▼
┌─────────────────────────┐
│ SubscriptionRepository  │  Impl in data layer;
│   Impl + LocalDataSrc   │  maps Subscription ⇄ SubscriptionModel ⇄ Map row
└───────────┬─────────────┘
            │ SQL
            ▼
┌─────────────────────────┐
│   SQLite (sqflite)      │  single file: subtrack.db
└─────────────────────────┘
```

### Entity vs. model

- `domain/entities/Subscription` — pure Dart, immutable, the type the UI and use
  cases work with. Fields per [PRD §3.1](PRD.md#31-entity-subscription).
- `data/models/SubscriptionModel` — extends/wraps the entity with
  `fromMap(Map<String,dynamic>)` / `toMap()` and enum-string (de)serialization
  ([PRD §3.3–3.4](PRD.md#33-sqlite-table-reference-ddl)). `snake_case` columns ↔
  `camelCase` fields.
- The repository implementation is the only place that converts between them.

---

## 4. Master architectural constraints (for every agent prompt)

1. **Strict dependency rule** — dependencies point inward only
   (`presentation → domain ← data`). `domain` must never import Flutter,
   `sqflite`, or `flutter_riverpod`.
2. **Immutability** — every entity and model is immutable, via `copyWith` or
   `freezed`. No mutable public fields.
3. **No database calls in UI** — widgets call
   `ref.read(subscriptionNotifierProvider.notifier).addSubscription(...)`. Direct
   DB access inside `initState` or `onPressed` is forbidden.
4. **Reactive state signals** — a subscription change triggers exactly one state
   emission that re-computes `M_total` and `A_total` in memory.

---

## 5. Mapping to PRD screens

| PRD screen / component                                                                             | Lives at                                                                      |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Dashboard (`dashboard_screen.dart`)                                                                | `features/subscriptions/presentation/screens/dashboard_screen.dart`           |
| Header summary card                                                                                | `presentation/widgets/expense_summary_card.dart`                              |
| Subscription list row                                                                              | `presentation/widgets/subscription_tile.dart`                                 |
| Add / Edit modal (`add_edit_subscription_sheet.dart`)                                              | `presentation/widgets/add_edit_subscription_sheet.dart`                       |
| Burn-rate engine ([PRD §4.1](PRD.md#41-financial-calculation-engine))                              | `domain/usecases/calculate_burn_rate.dart` (pure)                             |
| Auto-Advance Engine (v1.1)                                                                         | `domain/usecases/auto_advance_due_dates.dart` (pure logic)                    |
| Relative due-date labels ([PRD §4.3](PRD.md#43-list-sorting--date-handling))                       | `core/utils/due_date_formatter.dart`                                          |
| Currency formatting ([PRD §4.2](PRD.md#42-currency-display))                                       | `core/utils/currency_formatter.dart`                                          |
| Enums ([PRD §3.2](PRD.md#32-enums))                                                                | `core/constants/enums.dart`                                                   |
| Icon catalog ([PRD §3.2a](PRD.md#32a-icon-catalog))                                                | `core/constants/subscription_icons.dart` (id → `IconData`, category defaults) |
| Icon picker grid ([PRD §5.2](PRD.md#52-screen-2--add--edit-modal-add_edit_subscription_sheetdart)) | `presentation/widgets/icon_picker.dart`                                       |
| DB open + migrations ([PRD §3.3](PRD.md#33-sqlite-table-reference-ddl))                            | `core/database/app_database.dart`                                             |
| Settings Screen (v1.1)                                                                             | `features/settings/presentation/screens/settings_screen.dart`                 |
| Category Chart (v1.1)                                                                              | `features/subscriptions/presentation/widgets/category_chart_widget.dart`      |
