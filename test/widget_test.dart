// Smoke tests for pure (DB-free) logic. The full app needs an initialized
// ObjectBox store, so widget-pumping the app is covered by integration tests
// on device; here we verify the timezone-agnostic DayKey conversions.

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_me/core/day_key.dart';

void main() {
  group('DayKey', () {
    test('fromDate encodes YYYYMMDD', () {
      expect(DayKey.fromDate(DateTime(2026, 5, 27)), 20260527);
      expect(DayKey.fromDate(DateTime(2026, 1, 1)), 20260101);
    });

    test('toDate is the inverse of fromDate', () {
      final d = DateTime(2026, 12, 31);
      expect(DayKey.toDate(DayKey.fromDate(d)), d);
    });

    test('first/last of month', () {
      expect(DayKey.firstOfMonth(2026, 2), 20260201);
      expect(DayKey.lastOfMonth(2026, 2), 20260228); // 2026 nie jest przestępny
      expect(DayKey.lastOfMonth(2024, 2), 20240229); // 2024 przestępny
    });
  });
}
