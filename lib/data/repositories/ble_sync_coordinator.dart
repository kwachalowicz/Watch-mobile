import 'dart:async';

import '../ble/ble_protocol.dart';
import '../ble/ble_service.dart';
import 'habit_repository.dart';

/// Koordynator synchronizacji - słucha wiadomości z BLE i zapisuje do bazy.
/// Również wysyła zmiany z apki na zegarek.
///
/// To miejsce gdzie dzieje się magia "single source of truth":
/// - Definicje nawyków: APKA ma rację (push do zegarka)
/// - Wykonanie nawyków: ZEGAREK ma rację (push do apki)
/// - Kroki / streaki: ZEGAREK ma rację
class BleSyncCoordinator {
  final BleService _ble;
  final HabitRepository _habits;

  StreamSubscription<IncomingMessage>? _msgSub;

  BleSyncCoordinator({
    required BleService ble,
    required HabitRepository habits,
  })  : _ble = ble,
        _habits = habits;

  /// Wystartuj nasłuchiwanie. Wołać raz po połączeniu z zegarkiem.
  void start() {
    _msgSub?.cancel();
    _msgSub = _ble.messages.listen(_handleMessage);
  }

  Future<void> stop() async {
    await _msgSub?.cancel();
    _msgSub = null;
  }

  Future<void> _handleMessage(IncomingMessage msg) async {
    switch (msg.type) {
      case BleMessageType.hello:
        // Zegarek się przedstawił - możemy wysłać sync.
        await _onHandshake();
      case BleMessageType.habitDone:
        await _onHabitDone(msg);
      case BleMessageType.dayStats:
        await _onDayStats(msg);
      case BleMessageType.ack:
        // Zegarek potwierdził odbiór czegoś - na razie nie reagujemy.
        break;
      case BleMessageType.syncRequest:
      case BleMessageType.timeSync:
      case BleMessageType.habitsPush:
        // Te typy zegarek nie wysyła - to my je wysyłamy.
        break;
      case BleMessageType.unknown:
        // Loguj i ignoruj.
        break;
    }
  }

  Future<void> _onHandshake() async {
    // Wyślij aktualny czas + wszystkie aktywne nawyki.
    await _ble.send(OutgoingMessage.timeSync(DateTime.now()));
    await pushAllHabits();
  }

  Future<void> _onHabitDone(IncomingMessage msg) async {
    final uuid = msg.raw['uuid'] as String?;
    final day = msg.raw['day'] as int?;
    final atEpoch = msg.raw['at'] as int?;

    if (uuid == null || day == null) return;

    final completedAt = atEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(atEpoch * 1000)
        : DateTime.now();

    await _habits.recordCompletion(
      habitUuid: uuid,
      dayKey: day,
      completed: true,
      completedAt: completedAt,
      source: 'watch',
    );
  }

  /// Zegarek prześle paczkę dziennych statów (kroki, streak, etc).
  /// Wiadomość: {"t":"dayStats","day":20260527,"steps":7234,
  ///             "streak":5,"hcDone":3,"hcTotal":4,"goal":10000}
  Future<void> _onDayStats(IncomingMessage msg) async {
    final day = msg.raw['day'] as int?;
    if (day == null) return;

    await _habits.upsertDayStats(
      dayKey: day,
      steps: (msg.raw['steps'] as int?) ?? 0,
      stepGoal: (msg.raw['goal'] as int?) ?? 10000,
      streakDays: (msg.raw['streak'] as int?) ?? 0,
      habitsCompleted: (msg.raw['hcDone'] as int?) ?? 0,
      habitsTotal: (msg.raw['hcTotal'] as int?) ?? 0,
    );
  }

  /// Wysyła listę aktywnych nawyków na zegarek.
  /// Wołane po połączeniu i po każdej edycji nawyków w apce.
  Future<void> pushAllHabits() async {
    final habits = await _habits.getActiveHabits();
    final payload = habits
        .map((h) => {
              'uuid': h.uuid,
              'shortName': h.shortName,
              'order': h.order,
            })
        .toList();

    await _ble.send(OutgoingMessage.habitsPush(payload));
  }
}
