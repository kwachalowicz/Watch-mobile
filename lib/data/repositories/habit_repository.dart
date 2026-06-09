import 'package:uuid/uuid.dart';
import 'package:watch_me/objectbox.g.dart';

import '../../core/day_key.dart';
import '../local/objectbox_service.dart';
import '../models/day_stats.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';

/// Podsumowanie dnia - to co pokazujemy w karcie kalendarza i na ekranie szczegółów.
class DaySummary {
  final int dayKey;
  final DateTime date;
  final int habitsDone;
  final int habitsTotal;
  final int steps;
  final int stepGoal;
  final int streakDays;
  final List<HabitEntry> entries;

  DaySummary({
    required this.dayKey,
    required this.date,
    required this.habitsDone,
    required this.habitsTotal,
    required this.steps,
    required this.stepGoal,
    required this.streakDays,
    required this.entries,
  });

  /// 0.0 - 1.0; używane do koloru w kalendarzu i do ringów.
  double get habitProgress => habitsTotal == 0 ? 0 : habitsDone / habitsTotal;

  double get stepProgress =>
      stepGoal == 0 ? 0 : (steps / stepGoal).clamp(0, 1);

  bool get isToday => dayKey == DayKey.today();
  bool get hasData => habitsTotal > 0 || steps > 0;
}

/// Dostęp do danych nawyków na bazie ObjectBox. Baza = single source of truth.
class HabitRepository {
  final ObjectBoxService _obx;
  final _uuid = const Uuid();

  HabitRepository({ObjectBoxService? obx}) : _obx = obx ?? ObjectBoxService.instance;

  Box<Habit> get _habits => _obx.habitBox;
  Box<HabitEntry> get _entries => _obx.habitEntryBox;
  Box<DayStats> get _stats => _obx.dayStatsBox;

  // ─── HABITS ─────────────────────────────────────────────────────────

  Future<List<Habit>> getActiveHabits() async {
    final q = _habits
        .query(Habit_.isActive.equals(true))
        .order(Habit_.order)
        .build();
    try {
      return q.find();
    } finally {
      q.close();
    }
  }

  Stream<List<Habit>> watchActiveHabits() {
    return _habits
        .query(Habit_.isActive.equals(true))
        .order(Habit_.order)
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  Future<Habit?> getByUuid(String uuid) async {
    final q = _habits.query(Habit_.uuid.equals(uuid)).build();
    try {
      return q.findFirst();
    } finally {
      q.close();
    }
  }

  Future<Habit> create({
    required String name,
    required String shortName,
    String? icon,
  }) async {
    final habits = await getActiveHabits();
    final nextOrder = habits.isEmpty ? 0 : habits.last.order + 1;
    final now = DateTime.now();

    final habit = Habit(
      uuid: _uuid.v4(),
      name: name,
      shortName: shortName,
      icon: icon,
      order: nextOrder,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );

    _habits.put(habit);
    return habit;
  }

  Future<void> update(Habit habit) async {
    habit.updatedAt = DateTime.now();
    habit.version += 1;
    _habits.put(habit);
  }

  Future<void> softDelete(Habit habit) async {
    habit.isActive = false;
    await update(habit);
  }

  // ─── ENTRIES (zaliczenia nawyków) ──────────────────────────────────

  Future<void> recordCompletion({
    required String habitUuid,
    required int dayKey,
    required bool completed,
    required DateTime completedAt,
    required String source,
  }) async {
    // Para (habitUuid, dayKey) jest logicznie unikalna - egzekwujemy ręcznie:
    // znajdź istniejący wpis i nadpisz reuse'ując jego id.
    final q = _entries
        .query(HabitEntry_.habitUuid
            .equals(habitUuid)
            .and(HabitEntry_.dayKey.equals(dayKey)))
        .build();
    final HabitEntry? existing;
    try {
      existing = q.findFirst();
    } finally {
      q.close();
    }

    final entry = existing ??
        HabitEntry(
          habitUuid: habitUuid,
          dayKey: dayKey,
          completed: completed,
          completedAt: completedAt,
          source: source,
          updatedAt: DateTime.now(),
          syncedToCloud: false,
        );

    entry
      ..completed = completed
      ..completedAt = completedAt
      ..source = source
      ..updatedAt = DateTime.now()
      ..syncedToCloud = false;

    _entries.put(entry);
  }

  Future<List<HabitEntry>> getEntriesForDay(int dayKey) async {
    final q = _entries.query(HabitEntry_.dayKey.equals(dayKey)).build();
    try {
      return q.find();
    } finally {
      q.close();
    }
  }

  /// Wszystkie zaliczenia w zakresie dni - do widoku miesięcznego.
  Future<List<HabitEntry>> getEntriesInRange(int fromDayKey, int toDayKey) async {
    final q =
        _entries.query(HabitEntry_.dayKey.between(fromDayKey, toDayKey)).build();
    try {
      return q.find();
    } finally {
      q.close();
    }
  }

  // ─── DAY STATS (statystyki dzienne z zegarka) ──────────────────────

  Future<void> upsertDayStats({
    required int dayKey,
    required int steps,
    required int stepGoal,
    required int streakDays,
    required int habitsCompleted,
    required int habitsTotal,
  }) async {
    final q = _stats.query(DayStats_.dayKey.equals(dayKey)).build();
    final DayStats? existing;
    try {
      existing = q.findFirst();
    } finally {
      q.close();
    }

    final stats = existing ??
        DayStats(
          dayKey: dayKey,
          steps: steps,
          stepGoal: stepGoal,
          streakDays: streakDays,
          habitsCompleted: habitsCompleted,
          habitsTotal: habitsTotal,
          updatedAt: DateTime.now(),
          syncedToCloud: false,
        );

    stats
      ..steps = steps
      ..stepGoal = stepGoal
      ..streakDays = streakDays
      ..habitsCompleted = habitsCompleted
      ..habitsTotal = habitsTotal
      ..updatedAt = DateTime.now()
      ..syncedToCloud = false;

    _stats.put(stats);
  }

  Future<DayStats?> getDayStats(int dayKey) async {
    final q = _stats.query(DayStats_.dayKey.equals(dayKey)).build();
    try {
      return q.findFirst();
    } finally {
      q.close();
    }
  }

  /// Stream statystyk dzisiejszego dnia - do ekranu głównego.
  /// Reaguje natychmiast jak zegarek prześle update.
  Stream<DayStats?> watchTodayStats() {
    final today = DayKey.today();
    return _stats
        .query(DayStats_.dayKey.equals(today))
        .watch(triggerImmediately: true)
        .map((q) {
      final list = q.find();
      return list.isEmpty ? null : list.first;
    });
  }

  // ─── AGREGACJE (dla UI) ────────────────────────────────────────────

  /// Pełne podsumowanie konkretnego dnia - dla ekranu szczegółów.
  Future<DaySummary> getDaySummary(int dayKey) async {
    final entries = await getEntriesForDay(dayKey);
    final stats = await getDayStats(dayKey);
    final activeHabits = await getActiveHabits();

    final done = entries.where((e) => e.completed).length;

    return DaySummary(
      dayKey: dayKey,
      date: DayKey.toDate(dayKey),
      habitsDone: done,
      habitsTotal: stats?.habitsTotal ?? activeHabits.length,
      steps: stats?.steps ?? 0,
      stepGoal: stats?.stepGoal ?? 10000,
      streakDays: stats?.streakDays ?? 0,
      entries: entries,
    );
  }

  /// Mapa dayKey → DaySummary dla całego miesiąca. Do kalendarza.
  /// Robimy w 2 query (wszystkie entry + wszystkie stats) zamiast 30 razy
  /// po dniu - znacznie szybciej dla pełnego miesiąca.
  Future<Map<int, DaySummary>> getMonthSummary(int year, int month) async {
    final from = DayKey.firstOfMonth(year, month);
    final to = DayKey.lastOfMonth(year, month);

    final entries = await getEntriesInRange(from, to);

    final statsQuery =
        _stats.query(DayStats_.dayKey.between(from, to)).build();
    final List<DayStats> stats;
    try {
      stats = statsQuery.find();
    } finally {
      statsQuery.close();
    }

    // Pogrupuj entry po dayKey.
    final entriesByDay = <int, List<HabitEntry>>{};
    for (final e in entries) {
      entriesByDay.putIfAbsent(e.dayKey, () => []).add(e);
    }

    // Mapa statystyk po dayKey.
    final statsByDay = {for (final s in stats) s.dayKey: s};

    final result = <int, DaySummary>{};
    for (var d = from; d <= to; d++) {
      // Tylko prawdziwe dni (omiń np. 20260532).
      final date = DayKey.toDate(d);
      if (date.month != month) continue;

      final dayEntries = entriesByDay[d] ?? [];
      final s = statsByDay[d];
      final done = dayEntries.where((e) => e.completed).length;

      result[d] = DaySummary(
        dayKey: d,
        date: date,
        habitsDone: done,
        habitsTotal: s?.habitsTotal ?? 0,
        steps: s?.steps ?? 0,
        stepGoal: s?.stepGoal ?? 10000,
        streakDays: s?.streakDays ?? 0,
        entries: dayEntries,
      );
    }
    return result;
  }
}
