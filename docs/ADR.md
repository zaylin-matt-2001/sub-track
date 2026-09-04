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

_(Details for ADR-001 through ADR-006 remain identical to v1.0 and are omitted for brevity in this update, but their constraints remain fully in effect.)_

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
