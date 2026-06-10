import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_constants.dart';
import 'ble_protocol.dart';

/// Stany połączenia z zegarkiem.
enum BangleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Niskopoziomowa obsługa BLE z Bangle.js 2 (flutter_blue_plus 2.x).
///
/// Odpowiada za:
/// - skanowanie urządzeń o nazwie zaczynającej się "Bangle.js"
/// - utrzymywanie połączenia z wybranym zegarkiem
/// - subskrypcję notify na TX characteristic
/// - bufowanie częściowych linii (BLE notify może je tnąć)
/// - emitowanie sparsowanych IncomingMessage
///
/// NIE zna logiki domenowej (nawyki, statystyki) - to robi warstwa wyżej.
class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar; // do zapisywania (apka → zegarek)
  BluetoothCharacteristic? _txChar; // do czytania (zegarek → apka)

  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  final _stateController = StreamController<BangleConnectionState>.broadcast();
  final _messageController = StreamController<IncomingMessage>.broadcast();

  // Bufor na niedokończone linie - BLE notify nie gwarantuje że dostaniemy
  // dokładnie jedną wiadomość JSON na callback.
  String _rxBuffer = '';

  BangleConnectionState _state = BangleConnectionState.disconnected;

  Stream<BangleConnectionState> get stateStream => _stateController.stream;
  Stream<IncomingMessage> get messages => _messageController.stream;
  BangleConnectionState get currentState => _state;
  BluetoothDevice? get device => _device;

  void _setState(BangleConnectionState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  /// Skanuje urządzenia Bangle.js przez maksymalnie [timeoutSec] sekund.
  /// Zwraca strumień znalezionych urządzeń (mogą się pojawiać stopniowo).
  Stream<List<ScanResult>> scanForBangles({int? timeoutSec}) async* {
    // flutter_blue_plus 2.x: sprawdź wsparcie zanim ruszymy.
    if (!await FlutterBluePlus.isSupported) {
      _setState(BangleConnectionState.error);
      return;
    }

    _setState(BangleConnectionState.scanning);

    await FlutterBluePlus.stopScan();

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSec ?? BleConstants.scanTimeoutSec),
      // Filtrujemy po nazwie w post-processingu - Bangle advertisuje
      // "Bangle.js xxxx" (xxxx to ostatnie 4 znaki MAC). Część platform nie
      // wspiera filtra po nazwie w startScan.
    );

    yield* FlutterBluePlus.onScanResults.map((results) {
      return results
          .where(
            (r) =>
                r.device.platformName.startsWith(BleConstants.deviceNamePrefix),
          )
          .toList();
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    if (_state == BangleConnectionState.scanning) {
      _setState(BangleConnectionState.disconnected);
    }
  }

  /// Łączy się z wybranym zegarkiem i konfiguruje notify.
  Future<void> connect(BluetoothDevice device) async {
    _setState(BangleConnectionState.connecting);
    await stopScan();

    try {
      _device = device;
      // flutter_blue_plus 2.x wymaga jawnej deklaracji licencji.
      // Penguin Tracker to projekt naukowy/non-profit → License.nonprofit.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );

      // Nasłuchuj nagłego rozłączenia.
      _connStateSub?.cancel();
      _connStateSub = device.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected) {
          _cleanupAfterDisconnect();
        }
      });

      // Znajdź serwis NUS i jego dwie charakterystyki.
      final services = await device.discoverServices();
      final nus = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == BleConstants.nusServiceUuid,
        orElse: () =>
            throw StateError('Nordic UART service not found on device'),
      );

      _rxChar = nus.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == BleConstants.nusRxCharUuid,
      );
      _txChar = nus.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == BleConstants.nusTxCharUuid,
      );

      // Włącz notify na TX i zacznij słuchać.
      await _txChar!.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = _txChar!.lastValueStream.listen(_onIncomingBytes);

      _setState(BangleConnectionState.connected);
    } catch (e) {
      _setState(BangleConnectionState.error);
      await device.disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _cleanupAfterDisconnect();
  }

  void _cleanupAfterDisconnect() {
    _notifySub?.cancel();
    _connStateSub?.cancel();
    _notifySub = null;
    _connStateSub = null;
    _rxChar = null;
    _txChar = null;
    _device = null;
    _rxBuffer = '';
    _setState(BangleConnectionState.disconnected);
  }

  /// Wysyła wiadomość do zegarka. Jeśli payload > MTU - dzieli na chunki.
  Future<void> send(String message) async {
    final char = _rxChar;
    if (char == null) {
      throw StateError('Not connected to Bangle');
    }

    final bytes = utf8.encode(message);
    const chunkSize = BleConstants.maxPayloadBytes;

    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      final chunk = bytes.sublist(i, end);
      await char.write(chunk, withoutResponse: false);
    }
  }

  /// Callback z notify - może przyjść częściowa linia.
  void _onIncomingBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    _rxBuffer += utf8.decode(bytes, allowMalformed: true);

    // Parsuj kompletne linie. Resztę zostaw w buforze.
    while (_rxBuffer.contains('\n')) {
      final idx = _rxBuffer.indexOf('\n');
      final line = _rxBuffer.substring(0, idx).trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);

      if (line.isEmpty || !line.startsWith('{')) continue;

      try {
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        _messageController.add(IncomingMessage.fromJson(decoded));
      } catch (_) {
        // Niepoprawny JSON - olewamy, mogliśmy złapać śmieci z konsoli Espruino.
      }
    }
  }

  Future<void> dispose() async {
    await _notifySub?.cancel();
    await _connStateSub?.cancel();
    await _stateController.close();
    await _messageController.close();
  }
}
