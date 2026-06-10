# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-10

First functional milestone: the Penguin Tracker mobile app ported onto the
ObjectBox / Riverpod 3 / flutter_blue_plus 2.x / flutter_background_service
stack.

### Added
- **Local database (ObjectBox).** `Habit`, `HabitEntry` and `DayStats`
  entities with a single-owner `ObjectBoxService` that shares the store across
  isolates via `Store.attach`.
- **HabitRepository** with daily and monthly aggregations (`DaySummary`),
  reactive ObjectBox watchers, and soft delete that preserves history.
- **BLE layer (Nordic UART Service).** Scanning, connect/notify handling and a
  JSON-line protocol with short field names for the 20-byte MTU, on
  flutter_blue_plus 2.x (`License.nonprofit`).
- **BleSyncCoordinator** implementing the source-of-truth rules (app owns habit
  definitions, watch owns completions and stats).
- **Riverpod 3 providers** (manual/functional) with foreground BLE auto-sync.
- **Background sync service** hosting the BLE connection + sync loop in its own
  isolate on physical devices, gated off on the emulator.
- **Four screens** — Główny (home), Kalendarz (calendar), Nawyki (habits) and
  Zegarek (device) — plus day-detail and habit-edit, routed with go_router.
- **Custom painters** for the penguin mascot and the steps/habits rings,
  matched to the Bangle.js watch UI.
- Polish locale (`pl_PL`) and Material 3 theming.

### Design decisions
- UUID v4 for `Habit.uuid` (stable cross-device identity).
- `dayKey` as an `int` `YYYYMMDD` (timezone-agnostic, identical to the Espruino
  firmware format).
- BLE is a communication channel; the local database is the single source of
  truth.

### Notes
- BLE and the background service require a physical Bangle.js 2 to verify; they
  are disabled on the emulator.
- The Dart SDK lower bound was relaxed to `^3.11.1` to match the local stable
  Flutter toolchain.
