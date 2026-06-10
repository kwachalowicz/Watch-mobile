/// Konwersja DateTime ↔ dayKey (YYYYMMDD jako int).
///
/// Używamy intowego dayKey zamiast DateTime, bo:
/// - łatwo indeksować i porównywać (range queries)
/// - identyczny format po stronie Espruino (też używamy YYYYMMDD)
/// - timezone-agnostic: dzień to dzień, nie 86400 sekund
class DayKey {
  /// 27 maja 2026 → 20260527
  static int fromDate(DateTime d) {
    return d.year * 10000 + d.month * 100 + d.day;
  }

  static int today() => fromDate(DateTime.now());

  /// 20260527 → DateTime(2026, 5, 27)
  static DateTime toDate(int dayKey) {
    final year = dayKey ~/ 10000;
    final month = (dayKey ~/ 100) % 100;
    final day = dayKey % 100;
    return DateTime(year, month, day);
  }

  /// Pierwszy dzień miesiąca jako dayKey.
  static int firstOfMonth(int year, int month) =>
      year * 10000 + month * 100 + 1;

  /// Ostatni dzień miesiąca jako dayKey.
  static int lastOfMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return year * 10000 + month * 100 + lastDay;
  }
}
