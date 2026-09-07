# SubTrack — Product Requirements Document

**Product:** SubTrack (Personal Subscription & Fixed Expense Tracker)
**Version:** 1.1
**Status:** Completed (v1.1)
**Last updated:** 2026-09-07
**Companion docs:** [ADR.md](ADR.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [BUILD_PLAN.md](BUILD_PLAN.md)

---

## 1. Executive Summary & Objective

**Goal:** A lightweight, privacy-focused desktop/mobile app that tracks recurring
fixed expenses and calculates monthly/yearly financial burn rates without
connecting to bank APIs.

**Target architecture:** Flutter (UI + state) + local storage (`sqflite`). Zero network calls.

**Primary agentic testing goal:** Evaluate how effectively an AI agent can build a
complete Flutter app using strict data contracts, state management, form
validation, local CRUD persistence, and safely handle schema migrations (v1.1).

### Scope

| In scope                                         | Out of scope                            |
| ------------------------------------------------ | --------------------------------------- |
| Local CRUD for subscriptions                     | Bank / Plaid / open-banking integration |
| Monthly & yearly burn-rate calculation           | Cloud sync / accounts / auth            |
| Upcoming-bill list with relative due dates       | Analytics / telemetry SDKs              |
| Material 3 light & dark theme                    | Recurring-payment history / ledger      |
| Offline-first database & migrations              | Live/Network exchange rates (API)       |
| Active / Paused toggle                           |                                         |
| Auto-advancing due dates                         |                                         |
| Category breakdown charts                        |                                         |
| Multi-currency with manual static exchange rates |                                         |

---

## 2. Core User Stories

| ID   | Story                                                                                                                         | Acceptance criteria                                                                                                         |
| ---- | ----------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| US-1 | As a user, I want to add a recurring subscription (cost, cycle, due date, category, currency) so I can record my fixed costs. | Add sheet saves a valid record to the DB; it appears in the list and updates totals without an app restart.                 |
| US-2 | As a user, I want to see my total monthly and yearly burn rates instantly at the top of the app.                              | Dashboard header shows `M_total`, `A_total`, and subscription count, recomputed on every CRUD action.                       |
| US-3 | As a user, I want a list of upcoming expenses sorted by due date so I know what bill is coming next.                          | List is sorted ascending by `nextDueDate`; each row shows a relative due-date label.                                        |
| US-4 | As a user, I want to edit or delete existing subscriptions.                                                                   | Tap opens a pre-filled edit sheet; swipe prompts a confirm modal then deletes. Both update list + totals.                   |
| US-5 | As a user, I want my data saved strictly on my local device so it persists across restarts without cloud lock-in.             | Data survives cold restart. No network permission or request is issued by the app.                                          |
| US-6 | As a user, I want to pause a subscription temporarily so it doesn't count towards my burn rate.                               | A toggle on the edit sheet marks it paused; it dims on the list and is omitted from `M_total`/`A_total`.                    |
| US-7 | As a user, I want my due dates to auto-advance when the date passes so I don't have to manually update them.                  | On app open, any bill with `nextDueDate < today` has its date pushed forward by one cycle until it is ≥ today.              |
| US-8 | As a user, I want to see a chart of my spending by category so I know where my money goes.                                    | A chart widget shows the breakdown of active costs grouped by category.                                                     |
| US-9 | As a user, I want to track subscriptions in different currencies and set offline exchange rates so I can see a unified total. | Settings page allows setting a base currency and static exchange rates; dashboard converts everything to the base currency. |

---

## 3. Data Schema & Contracts

### 3.1 Entity: `Subscription`

| Field          | Type            | Nullable     | Rules                                                                                         |
| -------------- | --------------- | ------------ | --------------------------------------------------------------------------------------------- |
| `id`           | `int`           | No (auto)    | Primary key, autoincrement. Assigned by DB on insert.                                         |
| `name`         | `String`        | No           | Trimmed. Non-empty after trim. Max 30 characters.                                             |
| `cost`         | `double`        | No           | Must be `> 0.00`. Stored with full precision; displayed to 2 dp.                              |
| `billingCycle` | `String` (enum) | No           | One of: `monthly`, `yearly`.                                                                  |
| `nextDueDate`  | `DateTime`      | No           | Persisted as ISO-8601 string. Date-only semantics (time component normalized to 00:00 local). |
| `category`     | `String` (enum) | No           | One of: `Streaming`, `Software`, `Fitness`, `Utilities`, `Other`.                             |
| `iconName`     | `String`        | Yes (column) | Icon-catalog id.                                                                              |
| `isActive`     | `bool`          | No           | True if active, false if paused. Defaults to true.                                            |
| `currencyCode` | `String`        | No           | 3-letter code (e.g. `USD`, `EUR`). Defaults to base currency.                                 |

### 3.2 Enums & Catalog

```
BillingCycle = { monthly, yearly }
Category     = { Streaming, Software, Fitness, Utilities, Other }
```

Persist enums as their lowercase/exact string value. On read, an unrecognized
value must fall back safely.

_(Icon catalog defined via code exactly as in v1.0)_

### 3.3 SQLite tables (reference DDL v2)

```sql
CREATE TABLE subscriptions (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL,
  cost          REAL    NOT NULL CHECK (cost > 0),
  billing_cycle TEXT    NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
  next_due_date TEXT    NOT NULL,           -- ISO-8601
  category      TEXT    NOT NULL,
  icon_name     TEXT,
  is_active     INTEGER NOT NULL DEFAULT 1, -- 1=true, 0=false
  currency_code TEXT    NOT NULL DEFAULT 'USD'
);

CREATE TABLE settings (
  key           TEXT PRIMARY KEY,
  value         TEXT NOT NULL
);

CREATE TABLE exchange_rates (
  currency_code TEXT PRIMARY KEY,
  rate_to_base  REAL NOT NULL
);
```

- Schema version bumped to `2`.
- Migrations handled via an `onUpgrade` switch in `AppDatabase`.
- `settings` stores the base currency (e.g., `key = 'base_currency'`, `value = 'USD'`).

### 3.4 Model contract (Dart)

- `Subscription` is immutable with a `copyWith(...)`.
- `toMap()` omits `id` when null.
- Equality by all fields.

---

## 4. Functional Requirements & Calculations

### 4.1 Financial calculation engine & Multi-Currency

Computed from **all active** stored subscriptions.

**Normalized monthly cost (per subscription in base currency):**

```
monthly_cost = (cycle == monthly ? cost : cost / 12)
cost_in_base = monthly_cost * ExchangeRate(subscription.currencyCode)
```

_(If the subscription currency is the base currency, ExchangeRate is 1.0. If an exchange rate is missing, fallback to 1.0)._

**Totals:**

```
M_total = Σ(cost_in_base where isActive == true)
A_total = M_total × 12
```

Rules:

- Empty list → `M_total = 0`, `A_total = 0`, count = 0.
- The engine is a pure function of `List<Subscription>` and a `Map<String, double>` of exchange rates.

### 4.2 Auto-Advance Due Dates

- Upon loading the list from the database, if `nextDueDate < today`:
  - Automatically add 1 month (if monthly) or 1 year (if yearly) repeatedly until `nextDueDate ≥ today`.
  - Batch update the modified records in the DB.

### 4.3 Category Breakdown

- Sum the `cost_in_base` of active subscriptions, grouped by `Category`.
- Provide data points for the `fl_chart` widget.

### 4.4 List sorting & date handling

- Sort ascending by `nextDueDate` (closest upcoming bill first).
- Tie-break by `name` (A→Z).
- Paused subscriptions drop to the bottom of the list, sorted by name.

---

## 5. Screen Specifications & UI Flow

### 5.1 Dashboard (`dashboard_screen.dart`)

- **Header summary card**: Total monthly and yearly burn rates in the Base Currency.
- **Category Chart**: Expandable or separate tab showing the Pie chart of expenses.
- **Subscription list**: Paused items are visually dimmed/greyed out.

### 5.2 Add / Edit modal (`add_edit_subscription_sheet.dart`)

- **Form inputs** added to v1.0:
  - **Active Toggle**: Switch to pause/resume.
  - **Currency**: Dropdown or text field for the 3-letter currency code. New
    subscriptions default to the selected base currency.

### 5.3 Settings Screen (New)

- Set the global **Base Currency**.
- List and edit **Static Exchange Rates** (e.g. `EUR` -> `1.10`).
- Changing the base currency updates all displayed dashboard amounts to that
  currency immediately, including converted subscription costs.

---

## 6. State Management & Data Flow

- **State management:** `flutter_riverpod` + `AsyncNotifierProvider`.
- New Providers:
  - `settingsNotifierProvider` for Base Currency.
  - `exchangeRateNotifierProvider` for the conversion table.
  - `subscriptionNotifierProvider` now depends on both to calculate accurate totals.

---

## 7. Non-Functional & Technical Constraints

- Architecture remains Feature-First Clean Architecture (ADR-006).
- Database migrations must preserve v1 user data.
- UI uses `fl_chart` for category charting.

---

## 8. Edge Cases & Business Rules

1. **Empty database:** dashboard shows zeroed totals + empty-state list.
2. **Paused items:** keep track of them in DB, but don't count towards burn rate.
3. **Missing exchange rate:** assume 1:1, maybe show a warning icon on the subscription card.
4. **Auto-advance logic:** must handle leap years correctly by leveraging Dart's `DateTime` semantics.

---

## 9. Definition of Done

- [x] DB Migration logic updates `subscriptions` table and creates `settings` + `exchange_rates` tables.
- [x] Active/Paused toggle works; paused items are excluded from totals and dimmed.
- [x] Auto-advance logic successfully pushes past-due dates forward on app launch.
- [x] Multi-currency conversion logic is accurate based on static offline rates.
- [x] Settings screen allows managing the base currency and rates.
- [x] Category pie chart accurately groups active expenses.
- [x] All new logic is fully unit-tested (especially auto-advance math and currency conversion).
