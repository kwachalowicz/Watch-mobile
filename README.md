# Penguin Tracker — Watch Mobile

Mobile companion app for the **Penguin Tracker** research project: a habit
tracker that talks to a **Bangle.js 2** smartwatch over BLE. The watch shows a
penguin mascot and progress rings; this app is the source of truth for habit
definitions and the long-term history.

> Status: **v0.1.0** — first functional milestone. See [CHANGELOG.md](CHANGELOG.md).

## Features

- Four tabs: **Główny** (today), **Kalendarz** (calendar), **Nawyki** (habits)
  and **Zegarek** (device/BLE).
- Local-first storage with **ObjectBox** — habits, per-day completions and
  daily stats (steps, streak).
- **BLE** sync with Bangle.js 2 over the Nordic UART Service, using a compact
  JSON-line protocol sized for the 20-byte MTU.
- **Background sync service** that keeps syncing on a physical device outside
  the app's lifecycle, with a foreground fallback while the app is open.
- Penguin mascot + steps/habits rings drawn with custom painters to mirror the
  watch UI. Polish locale, Material 3.

## Tech stack

| Concern            | Choice                          |
| ------------------ | ------------------------------- |
| State management   | flutter_riverpod 3.x            |
| Local database     | objectbox 5.x                   |
| BLE                | flutter_blue_plus 2.x           |
| Background work    | flutter_background_service 5.x  |
| Routing            | go_router                       |
| Calendar UI        | table_calendar                  |

## Architecture

```
lib/
  core/            DayKey helper, Riverpod providers
  data/
    models/        ObjectBox entities (Habit, HabitEntry, DayStats)
    local/         ObjectBoxService (single Store owner, attach-by-directory)
    ble/           constants, JSON-line protocol, BleService, background sync
    repositories/  HabitRepository (aggregations), BleSyncCoordinator
  features/        home / calendar / habits / device screens
  shared/widgets/  penguin & rings painters
  app.dart         go_router shell with the four tabs
  main.dart        bootstrap (DB always, BLE/background on device only)
```

### Key design decisions

- **UUID v4** for `Habit.uuid` — stable identity shared with the watch.
- **`dayKey` as `int` `YYYYMMDD`** — timezone-agnostic, identical to the
  Espruino firmware format.
- **BLE is a channel, the database is the single source of truth.** App owns
  habit definitions (push to watch); the watch owns completions and stats
  (push to app).
- **Soft delete** for habits keeps historical entries intact.

## Getting started

Requirements: Flutter (stable, Dart ≥ 3.11.1), Android SDK, an emulator or a
physical Android device. A real Bangle.js 2 is needed to exercise BLE.

```bash
flutter pub get
dart run build_runner build      # generate objectbox.g.dart
flutter run
```

The app runs fully on an Android emulator (database + all four tabs). BLE and
the background service are disabled there — they require a physical device.

## Tests

```bash
flutter test       # DayKey unit tests
flutter analyze
```
