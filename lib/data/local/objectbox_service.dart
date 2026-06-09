import 'package:path_provider/path_provider.dart';
import 'package:watch_me/objectbox.g.dart';

import '../models/day_stats.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';

/// Pojedynczy właściciel instancji ObjectBox Store dla domeny nawyków.
///
/// ObjectBox pozwala otworzyć dany katalog tylko raz w procesie. Dlatego:
/// - główny izolat woła [init] (otwiera/tworzy store przez openStore),
/// - izolat background service woła [attach] (dołącza do już otwartego store
///   po ścieżce katalogu - bez ponownego otwierania pliku bazy).
///
/// Dzięki temu BLE sync w tle i UI na froncie dzielą tę samą bazę = single
/// source of truth.
class ObjectBoxService {
  final Store store;
  late final Box<Habit> habitBox;
  late final Box<HabitEntry> habitEntryBox;
  late final Box<DayStats> dayStatsBox;

  ObjectBoxService._(this.store) {
    habitBox = store.box<Habit>();
    habitEntryBox = store.box<HabitEntry>();
    dayStatsBox = store.box<DayStats>();
  }

  static ObjectBoxService? _instance;
  static String? _directory;

  static ObjectBoxService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'ObjectBoxService not initialized. Call init() (main isolate) or '
        'attach() (background isolate) first.',
      );
    }
    return i;
  }

  /// Ścieżka katalogu store - przekazywana do izolatu background, by mógł
  /// zrobić [attach].
  static String get directory {
    final d = _directory;
    if (d == null) throw StateError('ObjectBoxService not initialized.');
    return d;
  }

  /// Główny izolat: otwórz (lub utwórz) store.
  static Future<ObjectBoxService> init() async {
    final existing = _instance;
    if (existing != null) return existing;

    final docs = await getApplicationDocumentsDirectory();
    final dir = '${docs.path}/penguin-obx';
    final store = await openStore(directory: dir);

    _directory = dir;
    return _instance = ObjectBoxService._(store);
  }

  /// Izolat background service: dołącz do store otwartego przez główny izolat.
  static ObjectBoxService attach(String directory) {
    final existing = _instance;
    if (existing != null) return existing;

    final store = Store.attach(getObjectBoxModel(), directory);
    _directory = directory;
    return _instance = ObjectBoxService._(store);
  }

  void close() {
    store.close();
    _instance = null;
    _directory = null;
  }
}
