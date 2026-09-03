# SubTrack — Product Requirements Document

**Product:** SubTrack (Personal Subscription & Fixed Expense Tracker)
**Version:** 1.0
**Status:** Approved for build — implementation not yet started
**Last updated:** 2026-09-03
**Companion docs:** [ADR.md](ADR.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [BUILD_PLAN.md](BUILD_PLAN.md)

---

## 1. Executive Summary & Objective

**Goal:** A lightweight, privacy-focused desktop/mobile app that tracks recurring
fixed expenses and calculates monthly/yearly financial burn rates without
connecting to bank APIs.

**Target architecture:** Flutter (UI + state) + local storage (`sqflite` or
`isar`). Zero network calls.

**Primary agentic testing goal:** Evaluate how effectively an AI agent can build a
complete Flutter app using strict data contracts, state management, form
validation, and local CRUD persistence.

### Scope

| In scope | Out of scope |
| --- | --- |
| Local CRUD for subscriptions | Bank / Plaid / open-banking integration |
| Monthly & yearly burn-rate calculation | Multi-currency conversion |
| Upcoming-bill list with relative due dates | Cloud sync / accounts / auth |
| Material 3 light & dark theme | Notifications / reminders (v1.1 candidate) |
| Offline-first single-file database | Analytics / telemetry SDKs |
| | Recurring-payment history / ledger |

---

## 2. Core User Stories

| ID | Story | Acceptance criteria |
| --- | --- | --- |
| US-1 | As a user, I want to add a recurring subscription (cost, cycle, due date, category) so I can record my fixed costs. | Add sheet saves a valid record to the DB; it appears in the list and updates totals without an app restart. |
| US-2 | As a user, I want to see my total monthly and yearly burn rates instantly at the top of the app. | Dashboard header shows `M_total`, `A_total`, and subscription count, recomputed on every CRUD action. |
| US-3 | As a user, I want a list of upcoming expenses sorted by due date so I know what bill is coming next. | List is sorted ascending by `nextDueDate`; each row shows a relative due-date label. |
| US-4 | As a user, I want to edit or delete existing subscriptions. | Tap opens a pre-filled edit sheet; swipe prompts a confirm modal then deletes. Both update list + totals. |
| US-5 | As a user, I want my data saved strictly on my local device so it persists across restarts without cloud lock-in. | Data survives cold restart. No network permission or request is issued by the app. |

---

## 3. Data Schema & Contracts

### 3.1 Entity: `Subscription`

| Field | Type | Nullable | Rules |
| --- | --- | --- | --- |
| `id` | `int` | No (auto) | Primary key, autoincrement. Assigned by DB on insert. |
| `name` | `String` | No | Trimmed. Non-empty after trim. Max 30 characters. |
| `cost` | `double` | No | Must be `> 0.00`. Stored with full precision; displayed to 2 dp. |
| `billingCycle` | `String` (enum) | No | One of: `monthly`, `yearly`. |
| `nextDueDate` | `DateTime` | No | Persisted as ISO-8601 string. Date-only semantics (time component normalized to 00:00 local). |
| `category` | `String` (enum) | No | One of: `Streaming`, `Software`, `Fitness`, `Utilities`, `Other`. |
| `iconName` | `String` | Yes (column) | Icon-catalog id (§3.5). The form always sets it (defaulting to the category's icon), so it is non-null in practice; column stays nullable → `null` renders the category's default icon. |

### 3.2 Enums

```
BillingCycle = { monthly, yearly }
Category     = { Streaming, Software, Fitness, Utilities, Other }
```

Persist enums as their lowercase/exact string value. On read, an unrecognized
value must fall back safely (`category → Other`, `billingCycle → monthly`) rather
than throw.

### 3.2a Icon catalog

A fixed, code-defined catalog maps a stable string id → a Material `IconData`.
The Add/Edit sheet shows these as a selectable grid (§5.2). Ids are lowercase,
stable, and never localized.

| id | Icon (Material) | Default for category |
| --- | --- | --- |
| `streaming` | `live_tv` | Streaming |
| `music` | `music_note` | — |
| `movie` | `movie` | — |
| `software` | `code` | Software |
| `cloud` | `cloud` | — |
| `design` | `brush` | — |
| `fitness` | `fitness_center` | Fitness |
| `sports` | `sports_basketball` | — |
| `health` | `favorite` | — |
| `utilities` | `bolt` | Utilities |
| `wifi` | `wifi` | — |
| `phone` | `smartphone` | — |
| `home` | `home` | — |
| `news` | `menu_book` | — |
| `gaming` | `sports_esports` | — |
| `shopping` | `shopping_cart` | — |
| `finance` | `account_balance` | — |
| `other` | `category` | Other |

- **Category → default icon id:** `Streaming→streaming`, `Software→software`,
  `Fitness→fitness`, `Utilities→utilities`, `Other→other`.
- **Fallback:** an `iconName` that is `null` or not in the catalog renders the
  current category's default icon. `fromMap()` never throws on it.
- Adding icons later is a code change only — no schema migration.

### 3.3 SQLite table (reference DDL)

```sql
CREATE TABLE subscriptions (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL,
  cost          REAL    NOT NULL CHECK (cost > 0),
  billing_cycle TEXT    NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
  next_due_date TEXT    NOT NULL,           -- ISO-8601, e.g. 2026-09-15T00:00:00.000
  category      TEXT    NOT NULL,
  icon_name     TEXT
);
```

- Single database file (`subtrack.db`) in the application documents directory.
- Schema version starts at `1`; migrations handled via an `onUpgrade` switch.
- Column names are `snake_case` in SQL; the Dart model exposes `camelCase` and
  maps in `toMap()` / `fromMap()`.

### 3.4 Model contract (Dart)

- `Subscription` is immutable with a `copyWith(...)`.
- `toMap()` omits `id` when null (insert); includes it otherwise (update).
- `fromMap()` is total: never throws on a well-formed row; applies enum
  fallbacks from §3.2.
- Equality by all fields (for state diffing / tests).

---

## 4. Functional Requirements & Calculations

### 4.1 Financial calculation engine

Computed from **all** stored subscriptions (v1 has no active/paused concept; every
row counts).

**Normalized monthly cost:**

```
M_total = Σ(cost where cycle == monthly) + Σ(cost / 12 where cycle == yearly)
```

**Normalized annual cost:**

```
A_total = M_total × 12
```

Rules:

- Empty list → `M_total = 0`, `A_total = 0`, count = 0. Show an empty state, not
  a blank card.
- Rounding: compute in full `double` precision; round only at display time.
- The engine is a pure function of `List<Subscription>` — no DB access inside it,
  so it is unit-testable in isolation.

### 4.2 Currency display

- All monetary values formatted via the `intl` package (`NumberFormat.currency`).
- Default locale/symbol: USD `$`, 2 decimal places, thousands separators
  (e.g. `$14.99`, `$1,200.00`).
- Currency symbol/locale is a single app-level constant (not per-subscription).

### 4.3 List sorting & date handling

- Sort ascending by `nextDueDate` (closest upcoming bill first).
- Tie-break by `name` (A→Z) for stable ordering.
- Relative date label derived from `nextDueDate` vs. today (local date, time
  ignored):

| Condition | Label | Styling |
| --- | --- | --- |
| `dueDate == today` | `Due today` | Warning/highlight color |
| `dueDate < today` | `Overdue by X day(s)` | Error color |
| `dueDate == today + 1` | `Tomorrow` | Default |
| `today < dueDate ≤ today + 7` | `In X days` | Default |
| `dueDate > today + 7` | `Next bill: MMM dd` (e.g. `Next bill: Oct 15`) | Muted |

- **Overdue handling (v1):** display only — mark as overdue. No automatic
  rollover of `nextDueDate`. (Auto-advance is a v1.1 candidate; see §8.)
- "Today" must be recomputed when the app resumes from background so labels do
  not go stale.

---

## 5. Screen Specifications & UI Flow

### 5.1 Screen 1 — Dashboard (`dashboard_screen.dart`)

**Header summary card**

- Total monthly burn rate (`M_total`), formatted currency.
- Total yearly burn rate (`A_total`), formatted currency.
- Total count of tracked subscriptions.

**Subscription list**

- Card-based list. Each card shows: icon, name, category tag, cost, billing
  cycle, next due date + relative label.
- `Dismissible` swipe-to-delete → confirmation modal (`Delete "<name>"?` /
  Cancel / Delete). Only deletes on confirm; swipe animates back on cancel.
- Tap a card → opens the Add/Edit sheet as a bottom sheet, pre-filled with that
  record's data (edit mode).
- Empty state: friendly message + prompt to add the first subscription.

**Floating action button**

- `+` FAB anchored bottom-right → opens Add/Edit sheet in add mode.

### 5.2 Screen 2 — Add / Edit modal (`add_edit_subscription_sheet.dart`)

Single component serving both **add** and **edit** modes. Mode is determined by
whether a `Subscription` is passed in.

**Form inputs**

| Field | Control | Validation |
| --- | --- | --- |
| Name | Text field | Required; trimmed non-empty; max 30 chars. |
| Cost | Numeric text field (decimal keyboard) | Required; parses to a positive `double` (`> 0`); reject `0`, negatives, non-numeric, `NaN`/`Infinity`. |
| Billing cycle | Segmented button (`Monthly` \| `Yearly`) | Required; defaults to `Monthly`. |
| Category | Dropdown (`Streaming`, `Software`, `Fitness`, `Utilities`, `Other`) | Required; defaults to `Other`. |
| Icon | Selectable grid of the §3.2a catalog icons (single-select, scrollable) | Required; must be a catalog id. Defaults to the selected category's default icon. |
| Next due date | Tap opens `showDatePicker` | Required; defaults to today. Allowed range: today − 1 year … today + 5 years. |

**Actions**

- **Save:** run form validation → on success, insert (add) or update (edit) in
  SQLite → refresh state → close sheet. On validation failure, show inline field
  errors and keep the sheet open.
- **Cancel:** close the sheet with no state mutation and no DB write. If the form
  is dirty, optionally confirm discard (nice-to-have).

**Behavior**

- Cost input accepts one decimal separator; strips currency symbols/whitespace
  before parsing.
- Editing preserves the original `id`.
- **Icon default tracking:** while the user has not manually picked an icon,
  changing the category updates the selected icon to that category's default.
  Once the user picks an icon explicitly, category changes no longer override it.
  In edit mode the stored `iconName` is pre-selected and treated as explicit.
- Sheet is scroll-safe with the keyboard open (`isScrollControlled: true` +
  viewInsets padding).

### 5.3 Navigation map

```
Dashboard
 ├─ FAB ─────────────► Add/Edit sheet (add mode) ──► save ──► Dashboard (refreshed)
 ├─ tap card ────────► Add/Edit sheet (edit mode) ─► save ──► Dashboard (refreshed)
 └─ swipe card ──────► Confirm modal ──► delete ───► Dashboard (refreshed)
```

App is single-screen; the sheet is a modal over the dashboard. No routing package
required.

---

## 6. State Management & Data Flow

Architecture is fixed by [ADR-005](ADR.md#adr-005-state-management-architecture)
and [ADR-006](ADR.md#adr-006-code-organization--feature-first-clean-architecture);
full detail is in [ARCHITECTURE.md](ARCHITECTURE.md). Summary of the binding
requirements:

- **State management:** `flutter_riverpod` + `AsyncNotifierProvider`. State stays
  reactive to every SQLite CRUD action — the dashboard totals and list update
  without manual refresh. The UI consumes `AsyncValue<SubscriptionsState>`
  (loading / error / data).
- **Layering (Feature-First Clean Architecture):**
  1. **domain** (pure Dart) — `Subscription` entity, `SubscriptionRepository`
     interface, use cases (`CalculateBurnRate`, `GetUpcomingBills`, add/update/
     delete). No Flutter, no `sqflite`.
  2. **data** — `SubscriptionLocalDataSource` (raw `sqflite`),
     `SubscriptionModel` (row mapping), `SubscriptionRepositoryImpl`.
  3. **presentation** — `SubscriptionNotifier` (`AsyncNotifier`) holds the sorted
     `List<Subscription>` + derived `M_total` / `A_total` / count; widgets read
     via `ref.watch` and mutate via `ref.read(...notifier)`.
- **Load:** on app start the Notifier's `build()` reads all rows once; subsequent
  reads come from state. Writes go through a use case → repository → DB, then a
  single state emission (write-through).
- **Derived values** are recomputed from the in-memory list, never stored.
- **Error surfacing:** DB failures surface as `AsyncError` (and a `SnackBar` on
  writes); the app never crashes on a write error.

---

## 7. Non-Functional & Technical Constraints

| Area | Requirement |
| --- | --- |
| Platform | Flutter cross-platform: iOS, Android, desktop (macOS/Windows/Linux). |
| State management | `flutter_riverpod` + `AsyncNotifierProvider` (ADR-005). Reactive to DB CRUD. |
| Architecture | Feature-First Clean Architecture (ADR-006); see [ARCHITECTURE.md](ARCHITECTURE.md). |
| Database | `sqflite`. Single DB file (`subtrack.db`) in app documents dir. `sqflite_common_ffi` for desktop/test. |
| Offline-first | 100% offline. No HTTP clients, network adapters, analytics, or crash SDKs. No `INTERNET`-dependent code paths. |
| UI style | Material 3 design system, dynamic light/dark theme following the OS. |
| Formatting | `intl` for all currency and date formatting. |
| Performance | Handles ≥ 200 subscriptions with smooth scrolling; startup read < 100 ms for typical data. |
| Accessibility | Semantic labels on interactive elements; respects text scaling; color is not the only overdue signal (also text). |
| Testing | Unit tests for the calculation engine and date-label logic; repository tests against an in-memory/FFI database; widget test for form validation. |
| Localization | Strings centralized; USD/`en_US` default. Full i18n out of scope for v1. |

### 7.1 Project structure

Defined by [ARCHITECTURE.md §1](ARCHITECTURE.md#1-architecture-style-feature-first-clean-architecture)
(Feature-First Clean Architecture): `lib/{app,core,features/subscriptions/{data,domain,presentation}}`.
See [ARCHITECTURE.md §5](ARCHITECTURE.md#5-mapping-to-prd-screens) for the exact
file each PRD screen and engine maps to.

---

## 8. Edge Cases & Business Rules

1. **Empty database:** dashboard shows zeroed totals + empty-state list.
2. **Cost = 0 or negative:** rejected at validation; never persisted.
3. **Non-numeric / malformed cost:** rejected; inline error.
4. **Name > 30 chars or whitespace-only:** rejected; inline error.
5. **Very large cost (e.g. 1e9):** accepted if `> 0`; display formatting must not
   overflow the card (truncate/ellipsize).
6. **Yearly cost / 12:** kept in full precision in the sum; only the displayed
   total is rounded.
7. **Overdue subscription:** flagged in the list; totals still include it; no
   auto-rollover in v1.
8. **Due date far in the past/future:** clamped to the date-picker allowed range.
9. **Timezone / DST:** all comparisons use local date with the time component
   zeroed; recompute "today" on resume.
10. **Corrupt/unknown enum value in DB:** falls back (`Other` / `monthly`), row
    still loads. Unknown/`null` `iconName` → renders the category's default icon.
11. **Delete cancelled:** `Dismissible` reverts; no DB change.
12. **Edit then Cancel:** no DB change; list unchanged.
13. **Rapid double-tap Save:** guard against duplicate inserts (disable button
    while writing).
14. **DB write failure:** SnackBar error; in-memory state left consistent with
    what is actually persisted.

### 8.1 v1.1 candidates (not in this build)

- Auto-advance `nextDueDate` by one cycle once a bill date passes.
- Local notifications / reminders before a due date.
- Active/paused toggle per subscription (excluded from burn rate when paused).
- Per-category breakdown chart.
- CSV export/import.
- Multi-currency.

---

## 9. Definition of Done

- [ ] All five user stories pass their acceptance criteria.
- [ ] `Subscription` model + repository implement the §3 contract exactly.
- [ ] Burn-rate engine matches §4.1 formulas and is unit-tested (incl. empty,
      monthly-only, yearly-only, mixed).
- [ ] Relative due-date labels match the §4.3 table and are unit-tested.
- [ ] Add, edit, delete all update list + totals with no restart.
- [ ] Data persists across a cold restart.
- [ ] Form validation covers every §5.2 / §8 case with inline errors.
- [ ] Icon picker (§3.2a catalog) works: category-default tracking, explicit pick
      sticks, edit mode pre-selects stored icon, unknown id falls back on render.
- [ ] Material 3 light and dark themes both render correctly.
- [ ] No network code, analytics, or cloud dependency anywhere in the app.
- [ ] Layering respected (ADR-006): `domain/` imports no Flutter / `sqflite` /
      `flutter_riverpod`; no DB calls in widgets; entities & models immutable.
- [ ] State via `flutter_riverpod` `AsyncNotifierProvider` (ADR-005); one state
      emission per mutation.
- [ ] `flutter analyze` clean; `flutter test` green on CI targets.
