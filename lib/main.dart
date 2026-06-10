import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/ble/background_sync_service.dart';
import 'data/local/objectbox_service.dart';

/// Czy aplikacja działa na emulatorze. BLE i background service nie mają sensu
/// na emulatorze (brak radia BLE), więc tam je pomijamy.
Future<bool> _isEmulator() async {
  if (kIsWeb) return false;
  final info = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final android = await info.androidInfo;
    return !android.isPhysicalDevice;
  } else if (Platform.isIOS) {
    final ios = await info.iosInfo;
    return !ios.isPhysicalDevice;
  }
  return false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Baza = single source of truth. Inicjalizowana ZAWSZE - ObjectBox działa
  // też na emulatorze, a UI potrzebuje bazy żeby cokolwiek pokazać.
  await ObjectBoxService.init();

  // Polskie nazwy miesięcy/dni - dla kalendarza i formatów dat.
  await initializeDateFormatting('pl_PL', null);

  // BLE + background sync tylko na fizycznym urządzeniu.
  if (!await _isEmulator()) {
    await configureBackgroundSync();
  } else {
    debugPrint('Running on emulator: BLE & background sync disabled.');
  }

  runApp(const ProviderScope(child: PenguinTrackerApp()));
}
