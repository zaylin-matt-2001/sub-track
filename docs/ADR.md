# SubTrack — Architecture Decision Records

**Status:** Accepted — updated for v1.1
**Last updated:** 2026-09-04
**Companion docs:** [PRD.md](PRD.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [BUILD_PLAN.md](BUILD_PLAN.md)

> These ADRs are binding technical constraints. Do **not** switch libraries,
> patterns, or the persistence strategy mid-development without a new ADR that
> supersedes the relevant one.

| #       | Decision area          | Selected strategy                                      | Primary benefit                                      |
| ------- | ---------------------- | ------------------------------------------------------ | ---------------------------------------------------- |
| ADR-001 | Storage                | SQLite via `sqflite`                                   | Deterministic relational schema & native SQL queries |
| ADR-002 | State (superseded)     | ~~`ChangeNotifier` + `Provider`~~ → see ADR-005        | —                                                    |
| ADR-003 | Formulas & dates       | In-memory runtime normalization; ISO-8601 date strings | Precise totals without altering raw user input       |
| ADR-004 | UI                     | Flutter Material 3, built-in widgets only              | High out-of-the-box polish, minimal styling code     |
| ADR-005 | State                  | `flutter_riverpod` + `AsyncNotifierProvider`           | Compile-time DI safety, built-in async state         |
| ADR-006 | Code organization      | Feature-First Clean Architecture                       | Inward-only dependencies; no logic in widgets        |
| ADR-007 | Database Migration     | `sqflite` `onUpgrade`                                  | Safe offline schema evolution                        |
| ADR-008 | Offline Multi-Currency | Static user-defined exchange rates                     | 100% offline accuracy without network APIs           |
| ADR-009 | Charting Library       | `fl_chart`                                             | Robust local rendering for category breakdowns       |

---

## ADR-001: Local Data Persistence Strategy

**Status:** Accepted

### Context

The app needs lightweight, reliable local storage for user subscriptions,
offline. Network calls and cloud database dependencies are strictly out of scope.

### Decision

Use **`sqflite`** (SQLite plugin for Flutter) rather than `shared_preferences` or
`hive` / `hive_flutter`.

### Rationale

- `shared_preferences` is unsuitable for relational / queryable list data.
- `sqflite` provides ACID compliance, structured SQL schemas, and native query
  capability for sorting by due date.
- SQL migrations give a clear path for schema updates as the app evolves during
  testing.

### Consequences

- Requires explicit table setup, SQL queries, and mapping helpers
  (`toMap()` / `fromMap()`).
- Requires a web fallback (`sqflite_common_ffi_web`) if tested on web, and
  `sqflite_common_ffi` for desktop and unit tests. Native mobile/desktop is the
  primary target.
- The database is a single file (`subtrack.db`) in the application documents
  directory; schema version starts at `1` with an `onUpgrade` switch.

---

## ADR-002: State Management Pattern

**Status:** Superseded by [ADR-005](#adr-005-state-management-architecture)

### Context

The UI must reactively update the financial summary (total monthly / yearly burn
rate) and the list whenever a subscription is added, updated, or deleted.

### Original decision (no longer in force)

Use `ChangeNotifier` + `Provider`.

### Why superseded

The Architecture Specification adopted Feature-First Clean Architecture and
required compile-time-safe dependency injection with first-class async state.
`ChangeNotifier` + `Provider` does not provide compile-time DI checking and needs
custom loading/error wrappers. Replaced by `flutter_riverpod` +
`AsyncNotifierProvider` — see ADR-005. The invariants below still hold under
ADR-005 and are restated there.

### Retained invariants

- **All** database writes pass through the presentation controller (the
  Notifier); the UI never calls the repository or DB directly.
- Derived values (`M_total`, `A_total`) are computed from the in-memory list,
  never stored.

---

## ADR-003: Financial Calculation & Date Normalization Strategy

**Status:** Accepted

### Context

Subscriptions have different billing cycles (`monthly` or `yearly`). The app must
compute consistent monthly and annual expenses without rounding drift.

### Decision

Normalize all expense calculations **in memory** using `double`-precision
floating-point, and **format outputs only at the presentation layer** via `intl`
(`NumberFormat.currency`). Store `nextDueDate` as an **ISO-8601 string**
(`YYYY-MM-DDTHH:mm:ss.sss`) in SQLite.

### Rationale

- Normalizing yearly subscriptions to monthly (`cost / 12`) at runtime keeps the
  stored raw value accurate to the user's actual invoice while still producing
  accurate aggregated totals.
- ISO-8601 strings enable simple lexicographic sorting in SQL and
  straightforward `DateTime.parse()` conversion in Dart.

### Consequences

- Division by 12 produces repeating decimals in floating-point memory; currency
  formatting must handle rounding **at display time only**, uniformly across all
  screens. Never round intermediate sums.
- The burn-rate calculator is a pure function of `List<Subscription>` — no DB
  access — so it is unit-testable in isolation.
- Date comparisons use local date with the time component zeroed; "today" is
  recomputed on app resume.

---

## ADR-004: UI Framework & Design System

**Status:** Accepted

### Context

The UI needs a clean, modern look with minimal custom styling code so effort goes
to functional correctness.

### Decision

Use **Material 3** (`useMaterial3: true`) with built-in Flutter widgets only.

### Rationale

- Material 3 supplies the needed primitives out of the box: `Card`,
  `SegmentedButton`, `showModalBottomSheet`, `ListTile`, `Dismissible`,
  `showDatePicker`, `FloatingActionButton`.
- Dark mode is supported automatically via `ThemeData` light/dark + `ThemeMode`
  following the OS, with no extra theme code.

### Consequences

- No external third-party UI packages — reduces package-conflict surface area.
- Custom styling is limited to a small `app_theme.dart` (color scheme seed,
  text-scaling respect, overdue color roles).

---

## ADR-005: State Management Architecture

**Status:** Accepted (supersedes ADR-002)

### Context

The app requires reactive updates across multiple widgets when subscriptions are
created, updated, or deleted. State logic must remain decoupled from UI widgets,
and database reads have loading / error / data phases.

### Decision

Use **`flutter_riverpod`** with **`AsyncNotifierProvider`** for the subscription
list and its derived financial state.

### Rationale

- **Compile-time safety:** Riverpod catches provider/dependency errors at compile
  time rather than runtime.
- **Built-in async state:** `AsyncNotifier` handles loading / error / data for
  database reads without custom wrapper boilerplate.
- **Agent-friendly:** clear input/output boundaries discourage leaking state into
  UI widgets.

### Consequences

- The root app is wrapped in `ProviderScope`.
- UI widgets extend `ConsumerWidget` / `ConsumerStatefulWidget` and read state via
  `ref.watch(...)`; mutations go through
  `ref.read(subscriptionNotifierProvider.notifier).<method>(...)`.
- Repository / data-source instances are provided via Riverpod providers (DI) —
  no service locators, no global singletons.
- Retained invariants from ADR-002: all writes flow through the Notifier; derived
  totals are computed in memory, never persisted.

---

## ADR-006: Code Organization — Feature-First Clean Architecture

**Status:** Accepted

### Context

An AI agent building the app can scatter business logic into widgets or create
circular dependencies without an enforced structure.

### Decision

Adopt **Feature-First Clean Architecture** with three layers per feature
(`domain`, `data`, `presentation`) plus shared `app/` and `core/` folders. Full
directory layout and layer rules are in [ARCHITECTURE.md](ARCHITECTURE.md).

### Rationale

- Clear boundaries; dependencies point inward only
  (`presentation → domain ← data`).
- The `domain` layer is pure Dart — no Flutter, no `sqflite` — so business logic
  and calculations are trivially unit-testable.
- Feature folders keep related code co-located as the app grows during testing.

### Consequences

- More files/boilerplate than a flat `lib/` (interfaces + impls, entities +
  models). Accepted for the clarity it buys an agent.
- `domain/entities` (pure) and `data/models` (DB mapping) are **separate types**;
  the data layer maps between them.
- Use cases (`CalculateBurnRate`, `GetUpcomingBills`) live in
  `domain/usecases` and are called by the presentation Notifier.

---

## ADR-007: Database Migration Strategy (v1.1)

**Status:** Accepted

### Context

v1.1 introduces new fields (`is_active`, `currency_code`) to the existing `subscriptions` table and adds two new tables (`settings`, `exchange_rates`).

### Decision

Use the built-in `onUpgrade` callback in `sqflite` to execute raw `ALTER TABLE` and `CREATE TABLE` commands. The schema version is bumped from `1` to `2`.

### Consequences

- Existing v1 user data will not be lost.
- Default values must be provided during the `ALTER TABLE` to satisfy `NOT NULL` constraints (`is_active DEFAULT 1`, `currency_code DEFAULT 'USD'`).

---

## ADR-008: Offline Multi-Currency Strategy

**Status:** Accepted

### Context

The app must remain 100% offline (no `INTERNET` permission), but users want to track subscriptions in different currencies and see a unified total in a base currency.

### Decision

Rely on **static, user-defined exchange rates**.

- The user selects a base currency (e.g., USD).
- Subscriptions can be tagged with any 3-letter currency code (e.g., JPY, EUR).
- The user must manually input the exchange rate to their base currency in the app's Settings.

### Rationale

- Completely preserves the offline-first privacy model (ADR-001 / PRD constraints).
- Removes the complexity of historical daily rates; a fixed recurring expense usually has a somewhat predictable normalized impact the user can average out manually.

### Consequences

- Burn-rate calculations become slightly more complex (joining exchange rates in memory).
- If an exchange rate is missing, the engine falls back to `1.0` and the UI should ideally render a warning.

---

## ADR-009: Charting Library

**Status:** Accepted

### Context

v1.1 requires a Pie chart or Bar chart for the Category Breakdown (US-8).

### Decision

Add the `fl_chart` package.

### Rationale

- It is the most robust, highly maintained charting library for Flutter.
- Renders entirely locally using Canvas, fitting our offline and Material 3 design constraints seamlessly.

### Consequences

- Adds one new external UI dependency.
- Must ensure chart colors map correctly to the app's `ThemeData` (M3 ColorScheme).

---

## Master architectural constraints (include in every agent prompt)

1. **Strict dependency rule:** dependencies point inward only
   (`presentation → domain ← data`). The `domain` layer must never import Flutter
   or `sqflite`.
2. **Immutability:** all entities and models are immutable, via `copyWith` or
   `freezed`.
3. **No database calls in UI:** widgets call
   `ref.read(subscriptionNotifierProvider.notifier).addSubscription(...)`. Direct
   DB calls in `initState` or `onPressed` are forbidden.
4. **Reactive state signals:** changing a subscription triggers a single state
   emission that re-calculates `M_total` and `A_total` in memory.

---

## Allowed dependencies

| Package                  | Purpose                                         | ADR     |
| ------------------------ | ----------------------------------------------- | ------- |
| `sqflite`                | Local SQLite database                           | ADR-001 |
| `sqflite_common_ffi`     | Desktop + unit-test DB backend                  | ADR-001 |
| `sqflite_common_ffi_web` | Web fallback (only if web is tested)            | ADR-001 |
| `path` / `path_provider` | Resolve the documents directory for the DB file | ADR-001 |
| `flutter_riverpod`       | State management + dependency injection         | ADR-005 |
| `intl`                   | Currency + date formatting                      | ADR-003 |
| `cupertino_icons`        | Already present in the template                 | ADR-004 |
| `fl_chart`               | Local canvas charting (v1.1)                    | ADR-009 |

**Optional (immutability, ADR-006 rule 2) — only if the agent chooses `freezed`
over hand-written `copyWith`:** `freezed_annotation` (dep) + `freezed`,
`build_runner` (dev deps). Hand-written immutable classes with `copyWith` are
equally acceptable and add no dependency.

Anything not on this list requires a new ADR before being added. Explicitly
**disallowed:** `provider` (replaced by Riverpod), any HTTP client,
analytics/telemetry SDK, crash reporter, cloud SDK, or third-party UI kit (other than `fl_chart`).
