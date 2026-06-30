import 'package:path_provider/path_provider.dart';
import 'package:watch_me/objectbox.g.dart';

import '../models/day_stats.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';

class ObjectBoxService {
  final Store store;
  late final Box<Habit> habitBox;
  late final Box<HabitEntry> habitEntryBox;
  late final Box<DayStats> dayStatsBox;
  late final Box<AppUser> userBox;
  late final Box<AuthSession> authSessionBox;

  ObjectBoxService._(this.store) {
    habitBox = store.box<Habit>();
    habitEntryBox = store.box<HabitEntry>();
    dayStatsBox = store.box<DayStats>();
    userBox = store.box<AppUser>();
    authSessionBox = store.box<AuthSession>();
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

  static String get directory {
    final d = _directory;
    if (d == null) throw StateError('ObjectBoxService not initialized.');
    return d;
  }

  static Future<String> resolveDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/penguin-obx';
  }

  static Future<ObjectBoxService> init() async {
    final existing = _instance;
    if (existing != null) return existing;

    final dir = await resolveDirectory();
    final store = await openStore(directory: dir);

    _directory = dir;
    return _instance = ObjectBoxService._(store);
  }

  static Future<ObjectBoxService> initAt(String directory) async {
    final existing = _instance;
    if (existing != null) return existing;

    final store = await openStore(directory: directory);
    _directory = directory;
    return _instance = ObjectBoxService._(store);
  }

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
