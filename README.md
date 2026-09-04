# SubTrack

**SubTrack** is a lightweight, privacy-focused desktop/mobile app that tracks recurring fixed expenses (streaming services, software subscriptions, utilities, fitness, etc.) and calculates monthly/yearly financial burn rates — all stored locally on the device with no network calls, analytics, or cloud sync. Built with Flutter + `sqflite`, organized in a Feature-First Clean Architecture (`domain` ← `data` / `presentation`), and reactive end-to-end via `flutter_riverpod`'s `AsyncNotifierProvider`. See [`docs/PRD.md`](docs/PRD.md), [`docs/ADR.md`](docs/ADR.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for the full spec.

## Run

```bash
flutter pub get
flutter run                       # mobile / desktop
flutter build apk                 # Android
flutter build ios                 # iOS
flutter build macos               # macOS desktop
flutter build linux               # Linux desktop
flutter build windows             # Windows desktop
```

## Test

```bash
flutter analyze                   # static analysis (must be clean)
flutter test                      # all unit + widget tests
flutter test test/domain          # only domain layer tests
flutter test test/data            # only data layer tests (sqflite_common_ffi in-memory)
flutter test test/presentation    # only widget + notifier tests
```

## Layout

```
lib/
├── app/                       # theme, root widget
├── core/                      # constants, utilities, database bootstrap
└── features/
    ├── settings/              # base currency + static exchange rates (v1.1)
    │   ├── data/              # sqflite datasource for settings + exchange_rates
    │   ├── domain/            # (reserved)
    │   └── presentation/      # SettingsScreen + notifiers
    └── subscriptions/
        ├── data/              # sqflite datasource + model + repo impl
        ├── domain/            # pure-Dart entities, repo interface, use cases
        └── presentation/      # Riverpod providers, notifier, screens, widgets
```

## Architectural ground rules

- `domain/` imports no Flutter, `sqflite`, or `flutter_riverpod`.
- `data/` may import `domain`, `sqflite`, `path_provider`, `intl` — never `flutter_riverpod` or widgets.
- `presentation/` may import `domain`, `flutter_riverpod`, Flutter — never `sqflite` directly.
- All DB writes flow through `SubscriptionNotifier` → use cases → repository → SQLite.
- Derived totals are recomputed in memory; never stored.
- See [`docs/ADR.md`](docs/ADR.md) for the binding constraints and [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for the milestone checklist.
