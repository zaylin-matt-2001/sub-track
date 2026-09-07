# SubTrack — Personal Subscription & Fixed Expense Tracker

**SubTrack** is a lightweight, 100% offline, privacy-focused desktop/mobile application built with Flutter that tracks recurring fixed expenses (streaming services, software subscriptions, utilities, fitness, etc.) and calculates monthly and yearly financial burn rates.

All user data is stored strictly on the local device using SQLite (`sqflite`), with **zero network requests, third-party analytics, or cloud SDK dependencies**.

---

## Key Features (v1.1)

- 📊 **Category Breakdown Chart**: Interactive pie chart (`fl_chart`) visualizing active spending per category with formatted base-currency totals.
- 🔀 **Active / Paused Toggle**: Pause subscriptions to exclude them from financial burn rates while retaining full records in the database.
- 💱 **Offline Multi-Currency**: Assign individual currencies to subscriptions and define static, offline exchange rates to view unified dashboard totals in your preferred base currency.
- 🗓️ **Auto-Advancing Due Dates**: Bills with past-due dates automatically roll forward by billing cycle (monthly/yearly) upon app launch.
- 🎨 **Material 3 UI**: Clean M3 light and dark theme adaptation (`ThemeMode.system`) with responsive layouts for mobile and desktop viewports.
- 🔒 **100% Private & Offline**: Zero network permissions or telemetry. Complete data ownership on-device.

---

## Architecture

The project strictly follows **Feature-First Clean Architecture** (`presentation` → `domain` ← `data`):

```
lib/
├── app/                       # theme, app initialization
├── core/                      # constants, formatters, database bootstrap & migrations
└── features/
    ├── settings/              # Base currency & static exchange rates management
    │   ├── data/              # SQLite datasources for settings & exchange rates
    │   ├── domain/            # Entities, repo contracts & settings logic
    │   └── presentation/      # SettingsScreen, Notifiers & Riverpod providers
    └── subscriptions/
        ├── data/              # SQLite datasources, models & repository implementations
        ├── domain/            # Pure Dart entities, repository interfaces, use cases
        └── presentation/      # Riverpod providers, notifiers, screens & UI widgets
```

- **State Management**: `flutter_riverpod` (`AsyncNotifierProvider`)
- **Local Persistence**: `sqflite` (schema v2 with `onUpgrade` migration path)
- **Formatting**: `intl` currency and date formatters

---

## Getting Started

### Prerequisites

- Flutter SDK (3.x or higher)
- Dart SDK

### Run the App

```bash
flutter pub get
flutter run                       # Run on connected device / desktop / emulator
```

### Build Executables

```bash
flutter build apk                 # Android APK
flutter build ios                 # iOS App
flutter build macos               # macOS Desktop
flutter build linux               # Linux Desktop
flutter build windows             # Windows Desktop
```

---

## Testing & Quality

The codebase maintains a comprehensive test suite (135+ unit and widget tests) spanning all layers:

```bash
flutter analyze                   # Static analysis (must be 0 warnings/errors)
flutter test                      # Run all unit and widget tests
flutter test test/domain          # Pure domain logic tests (burn rate, auto-advance, breakdown)
flutter test test/data            # Data layer & SQLite migration integration tests
flutter test test/presentation    # Controller and UI widget tests
```

---

## Documentation Index

- [`docs/PRD.md`](docs/PRD.md) — Product Requirements Document (User Stories & Data Schema)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Architectural Specifications & Layer Rules
- [`docs/ADR.md`](docs/ADR.md) — Architecture Decision Records (ADR-001 to ADR-009)
- [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) — Implementation Milestones (M0 to M12)
