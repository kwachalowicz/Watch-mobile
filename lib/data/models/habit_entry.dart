import 'package:objectbox/objectbox.dart';

/// Pojedyncze zaliczenie nawyku w danym dniu.
///
/// Uwaga: para (habitUuid, dayKey) jest logicznie unikalna. ObjectBox nie ma
/// composite unique indexu, więc unikalność egzekwuje repozytorium
/// (query istniejącego wpisu → reuse id → put).
@Entity()
class HabitEntry {
  @Id()
  int id = 0;

  /// UUID nawyku - powiązanie z Habit.uuid.
  /// Trzymamy UUID a nie lokalne id, bo zegarek nie zna id z bazy.
  @Index()
  String habitUuid;

  /// Dzień jako YYYYMMDD (int) - łatwy do indexowania i porównania.
  @Index()
  int dayKey;

  /// Czy zaliczone w tym dniu.
  bool completed;

  /// Kiedy zaliczone - timestamp z zegarka.
  @Property(type: PropertyType.date)
  DateTime? completedAt;

  /// Źródło: 'watch' albo 'app' (manualne nadrobienie).
  String source;

  /// Dla conflict resolution - last update wins.
  @Property(type: PropertyType.date)
  DateTime updatedAt;

  /// Czy zsynchronizowane z chmurą (dla fazy 3).
  bool syncedToCloud;

  HabitEntry({
    this.id = 0,
    required this.habitUuid,
    required this.dayKey,
    required this.completed,
    this.completedAt,
    required this.source,
    required this.updatedAt,
    required this.syncedToCloud,
  });
}
