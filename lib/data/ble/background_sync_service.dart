import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

import '../local/objectbox_service.dart';
import '../repositories/ble_sync_coordinator.dart';
import '../repositories/habit_repository.dart';
import 'ble_service.dart';

/// Background service hostujący synchronizację BLE z Bangle.js 2.
///
/// Architektura (decyzja projektowa: "pełny background z fallbackiem"):
/// - Na fizycznym urządzeniu to jest PRYMARNY kanał synchronizacji - żyje poza
///   cyklem życia UI, w osobnym izolacie, jako foreground service.
/// - ObjectBox jest współdzielony z głównym izolatem przez Store.attach (ten
///   sam proces). Gdy główny izolat nie żyje, izolat tła otwiera store sam.
/// - Gdy apka jest na pierwszym planie, foreground bleAutoSyncProvider działa
///   jako fallback (patrz core/providers.dart).
///
/// Uwaga: tej ścieżki nie da się zweryfikować na emulatorze (brak BLE) -
/// wymaga testu na fizycznym Bangle.js 2. Auto-reconnect po zapisanym id
/// urządzenia jest oznaczony jako TODO do implementacji on-device.
const String backgroundNotificationChannelId = 'penguin_ble_sync';
const int backgroundNotificationId = 7411;

/// Konfiguruje (ale nie startuje) background service. Wołane raz w main() na
/// fizycznym urządzeniu. autoStart=false - start jest jawny, po nadaniu
/// uprawnień / połączeniu z zegarkiem.
Future<void> configureBackgroundSync() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: backgroundNotificationChannelId,
      initialNotificationTitle: 'Penguin Tracker',
      initialNotificationContent: 'Synchronizacja z zegarkiem',
      foregroundServiceNotificationId: backgroundNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundStart,
      onBackground: _onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

/// Entry point izolatu background service.
@pragma('vm:entry-point')
Future<void> onBackgroundStart(ServiceInstance service) async {
  // Pluginy nie są automatycznie zarejestrowane w izolacie tła.
  DartPluginRegistrant.ensureInitialized();

  // Współdziel bazę z głównym izolatem (ten sam proces) albo otwórz własną,
  // gdy główny izolat nie żyje.
  final dir = await ObjectBoxService.resolveDirectory();
  ObjectBoxService obx;
  try {
    obx = ObjectBoxService.attach(dir);
  } catch (_) {
    obx = await ObjectBoxService.initAt(dir);
  }

  final ble = BleService();
  final coordinator = BleSyncCoordinator(
    ble: ble,
    habits: HabitRepository(obx: obx),
  );
  coordinator.start();

  // TODO(on-device): odczytać zapisane id ostatniego Bangle.js i wykonać
  // auto-reconnect (ble.connect), z retry/backoff przy zerwaniu połączenia.

  service.on('stop').listen((_) async {
    await coordinator.stop();
    await ble.dispose();
    await service.stopSelf();
  });
}
