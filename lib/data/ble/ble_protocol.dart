/// Protokół komunikacji apka ↔ Bangle.js 2.
///
/// Format: każda wiadomość to JSON + '\n' (linia).
/// Bangle obsługuje to natywnie - można robić `print(JSON.stringify(...))`
/// w Espruino i lecieć linią przez UART.
///
/// Typy wiadomości w obie strony:
///
/// === APKA → ZEGAREK ===
/// {"t":"hello","appVer":1}                      handshake
/// {"t":"syncReq"}                                "wyślij mi wszystko czego nie mam"
/// {"t":"habitsPush","habits":[...]}              push nowych/zmienionych nawyków
/// {"t":"timeSync","ts":1716800000}               synchronizacja zegara (epoch sekundy)
///
/// === ZEGAREK → APKA ===
/// {"t":"hello","fwVer":"0.1.0","battery":78}     odpowiedź na handshake
/// {"t":"habitDone","uuid":"...","day":20260527,"at":1716800000}
/// {"t":"dayStats","day":20260527,"steps":7234,"streak":5,"hcDone":3,"hcTotal":4}
/// {"t":"ack","ref":"syncReq"}                    potwierdzenie obsługi
///
/// Reguły:
/// - Krótkie nazwy pól ('t' zamiast 'type', 'uuid' zamiast 'habitUuid') -
///   pamięć Bangle to ~100KB, MTU BLE to 20B. Każdy bajt się liczy.
/// - Brak nested objects gdzie się da - flat structure.
/// - Każda wiadomość samodzielna - bez sesji, bez kolejności.
library;

enum BleMessageType {
  hello('hello'),
  syncRequest('syncReq'),
  habitsPush('habitsPush'),
  timeSync('timeSync'),
  habitDone('habitDone'),
  dayStats('dayStats'),
  ack('ack'),
  unknown('?');

  final String code;
  const BleMessageType(this.code);

  static BleMessageType fromCode(String? code) {
    return BleMessageType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => BleMessageType.unknown,
    );
  }
}

/// Wiadomość przychodząca z zegarka po sparsowaniu z JSON.
class IncomingMessage {
  final BleMessageType type;
  final Map<String, dynamic> raw;

  IncomingMessage(this.type, this.raw);

  factory IncomingMessage.fromJson(Map<String, dynamic> json) {
    return IncomingMessage(BleMessageType.fromCode(json['t'] as String?), json);
  }
}

/// Builder wiadomości wychodzących do zegarka.
class OutgoingMessage {
  static String hello({int appVer = 1}) => '{"t":"hello","appVer":$appVer}\n';

  static String syncRequest() => '{"t":"syncReq"}\n';

  static String timeSync(DateTime time) {
    final epochSec = time.millisecondsSinceEpoch ~/ 1000;
    return '{"t":"timeSync","ts":$epochSec}\n';
  }

  /// Push nawyków do zegarka. Tylko niezbędne pola.
  /// Jeśli payload za duży - dzielimy na batche w warstwie wyżej.
  static String habitsPush(List<Map<String, dynamic>> habits) {
    final list = habits
        .map(
          (h) =>
              '{"u":"${h['uuid']}","n":"${h['shortName']}","o":${h['order']}}',
        )
        .join(',');
    return '{"t":"habitsPush","habits":[$list]}\n';
  }
}
