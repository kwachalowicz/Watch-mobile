import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ble/ble_service.dart';
import '../data/models/day_stats.dart';
import '../data/models/habit.dart';
import '../data/repositories/ble_sync_coordinator.dart';
import '../data/repositories/habit_repository.dart';
import 'day_key.dart';

// Riverpod 3 - manualne (functional) providery, bez codegen. Stara wersja nie
// używała StateNotifier, więc klasyczne Provider/Stream/Future są zgodne 1:1.

// ─── SINGLETONY ────────────────────────────────────────────────────

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository();
});

final bleServiceProvider = Provider<BleService>((ref) {
  final svc = BleService();
  ref.onDispose(svc.dispose);
  return svc;
});

final bleSyncCoordinatorProvider = Provider<BleSyncCoordinator>((ref) {
  final coord = BleSyncCoordinator(
    ble: ref.watch(bleServiceProvider),
    habits: ref.watch(habitRepositoryProvider),
  );
  ref.onDispose(coord.stop);
  return coord;
});

// ─── STREAMY DANYCH ────────────────────────────────────────────────

final activeHabitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchActiveHabits();
});

final bleStateProvider = StreamProvider<BangleConnectionState>((ref) {
  return ref.watch(bleServiceProvider).stateStream;
});

/// Statystyki dnia dzisiejszego - reaktywne, odświeża się przy każdym
/// update z zegarka.
final todayStatsProvider = StreamProvider<DayStats?>((ref) {
  return ref.watch(habitRepositoryProvider).watchTodayStats();
});

// ─── AUTO-START SYNC PO CONNECT (foreground fallback) ──────────────

/// Słucha stanu BLE - gdy connect → start sync coordinatora, gdy disconnect →
/// stop. To "foreground" ścieżka synchronizacji: działa dopóki apka jest
/// otwarta. Na fizycznym urządzeniu prymarnym kanałem jest background service
/// (patrz data/ble/background_sync_service.dart); ten provider jest fallbackiem
/// gdy apka jest na pierwszym planie.
final bleAutoSyncProvider = Provider<void>((ref) {
  final coord = ref.watch(bleSyncCoordinatorProvider);

  ref.listen(bleStateProvider, (prev, next) {
    final state = next.value;
    if (state == BangleConnectionState.connected) {
      coord.start();
    } else if (state == BangleConnectionState.disconnected) {
      coord.stop();
    }
  });
});

// ─── AGREGOWANE WIDOKI (dla ekranów Home i Day detail) ─────────────

/// Pełne podsumowanie konkretnego dnia. Family - parametryzowane dayKey.
final daySummaryProvider =
    FutureProvider.family<DaySummary, int>((ref, dayKey) async {
  // Inwaliduj gdy zmienią się nawyki, today stats, albo aktywne habity.
  ref.watch(todayStatsProvider);
  ref.watch(activeHabitsProvider);
  return ref.read(habitRepositoryProvider).getDaySummary(dayKey);
});

/// Podsumowanie dzisiejszego dnia - shortcut.
final todaySummaryProvider = FutureProvider<DaySummary>((ref) async {
  // Reaguje na zmiany stats i listy nawyków.
  ref.watch(todayStatsProvider);
  ref.watch(activeHabitsProvider);
  final repo = ref.read(habitRepositoryProvider);
  return repo.getDaySummary(DayKey.today());
});
