import 'package:objectbox/objectbox.dart';

/// Dzienne statystyki raportowane przez zegarek (kroki, streak, podsumowanie).
/// dayKey jest unikalny - jeden rekord na dzień.
@Entity()
class DayStats {
  @Id()
  int id = 0;

  /// Dzień jako YYYYMMDD.
  @Unique()
  int dayKey;

  /// Liczba kroków zaraportowana przez zegarek.
  int steps;

  /// Cel kroków na ten dzień (snapshot - cel mógł się zmienić później).
  int stepGoal;

  /// Aktualny streak na koniec tego dnia.
  int streakDays;

  /// Ile nawyków zaliczonych / wszystkich aktywnych w tym dniu.
  int habitsCompleted;
  int habitsTotal;

  /// Ostatni update - z zegarka albo z synca.
  @Property(type: PropertyType.date)
  DateTime updatedAt;

  bool syncedToCloud;

  DayStats({
    this.id = 0,
    required this.dayKey,
    required this.steps,
    required this.stepGoal,
    required this.streakDays,
    required this.habitsCompleted,
    required this.habitsTotal,
    required this.updatedAt,
    required this.syncedToCloud,
  });
}
