/// UUID-y serwisu Nordic UART (NUS) używanego przez Bangle.js 2.
///
/// Bangle to peripheral. My (apka) jesteśmy central.
/// - RX (write) z perspektywy peripherala = my piszemy tam komendy
/// - TX (notify) z perspektywy peripherala = stamtąd dostajemy odpowiedzi
class BleConstants {
  static const String nusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// My piszemy tutaj komendy do zegarka.
  static const String nusRxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// Subskrybujemy notify - tu dostajemy dane z zegarka.
  static const String nusTxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  /// Bangle.js advertisuje się z prefixem "Bangle.js".
  static const String deviceNamePrefix = 'Bangle.js';

  /// Maksymalny rozmiar paczki - 20 bajtów dla default MTU.
  /// Dłuższe wiadomości trzeba dzielić na chunki.
  static const int maxPayloadBytes = 20;

  /// Timeout skanowania (sekundy).
  static const int scanTimeoutSec = 15;
}
