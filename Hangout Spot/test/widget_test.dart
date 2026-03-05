// BiteBox / Hangout Spot – basic smoke tests.
//
// These tests avoid Firebase and SharedPreferences by exercising
// pure-Dart utilities and model classes that can run without a host app.

import 'package:flutter_test/flutter_test.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';

void main() {
  group('InventoryReminder', () {
    test('toMap produces correct keys', () {
      final reminder = InventoryReminder(
        id: 'r1',
        type: 'time',
        title: 'Restock check',
        time: '18:00',
        isEnabled: true,
      );

      final map = reminder.toMap();
      expect(map['type'], 'time');
      expect(map['title'], 'Restock check');
      expect(map['time'], '18:00');
      expect(map['isEnabled'], true);
      expect(map.containsKey('updatedAt'), true);
    });

    test('disabled reminder round-trips correctly', () {
      final reminder = InventoryReminder(
        id: 'r2',
        type: 'daily_update',
        title: 'End of day',
        time: '21:30',
        isEnabled: false,
      );

      final map = reminder.toMap();
      expect(map['isEnabled'], false);
      expect(map['type'], 'daily_update');
      expect(map['time'], '21:30');
    });
  });

  group('InventoryAnalyticsSummary', () {
    test('can be constructed with required fields', () {
      final summary = InventoryAnalyticsSummary(
        lowStockEvents: 3,
        topLowStockItem: 'Milk',
        mostConsumedItem: 'Sugar',
        restockTotal: 1250.50,
        restockTrend: {'2026-03-01': 500.0, '2026-03-02': 750.50},
      );

      expect(summary.lowStockEvents, 3);
      expect(summary.topLowStockItem, 'Milk');
      expect(summary.mostConsumedItem, 'Sugar');
      expect(summary.restockTotal, 1250.50);
      expect(summary.restockTrend.length, 2);
    });
  });
}
