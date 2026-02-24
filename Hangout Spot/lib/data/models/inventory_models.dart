import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double currentQty;
  final double minQty;
  final double? price;
  final bool isActive;
  final DateTime? updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentQty,
    required this.minQty,
    this.price,
    this.isActive = true,
    this.updatedAt,
  });

  factory InventoryItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return InventoryItem(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      currentQty: _toDouble(data['currentQty']),
      minQty: _toDouble(data['minQty']),
      price: data['price'] == null ? null : _toDouble(data['price']),
      isActive: (data['isActive'] ?? true) == true,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'unit': unit,
      'currentQty': currentQty,
      'minQty': minQty,
      'price': price,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class DailyInventory {
  final String id;
  final DateTime date;
  final Map<String, double> items;
  final DateTime? updatedAt;

  DailyInventory({
    required this.id,
    required this.date,
    required this.items,
    this.updatedAt,
  });

  factory DailyInventory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final itemsRaw = (data['items'] as Map<String, dynamic>?) ?? {};
    final items = <String, double>{};
    for (final entry in itemsRaw.entries) {
      items[entry.key] = _toDouble(entry.value);
    }

    return DailyInventory(
      id: doc.id,
      date: _toDateTime(data['date']) ?? DateTime.now(),
      items: items,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class InventoryReminder {
  final String id;
  final String type;
  final String title;
  final String? itemId;
  final double? threshold;
  final String time;
  final bool isEnabled;
  final DateTime? updatedAt;

  InventoryReminder({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
    this.itemId,
    this.threshold,
    this.isEnabled = true,
    this.updatedAt,
  });

  factory InventoryReminder.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InventoryReminder(
      id: doc.id,
      type: (data['type'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      time: (data['time'] ?? '09:00').toString(),
      itemId: data['itemId']?.toString(),
      threshold: data['threshold'] == null
          ? null
          : _toDouble(data['threshold']),
      isEnabled: (data['isEnabled'] ?? true) == true,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'time': time,
      'itemId': itemId,
      'threshold': threshold,
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class PlatformOrder {
  final String id;
  final String platform;
  final double total;
  final String? notes;
  final DateTime createdAt;

  PlatformOrder({
    required this.id,
    required this.platform,
    required this.total,
    required this.createdAt,
    this.notes,
  });

  factory PlatformOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PlatformOrder(
      id: doc.id,
      platform: (data['platform'] ?? '').toString(),
      total: _toDouble(data['total']),
      notes: data['notes']?.toString(),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'total': total,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class InventoryAnalyticsSummary {
  final int lowStockEvents;
  final String? topLowStockItem;
  final String? mostConsumedItem;
  final double restockTotal;
  final Map<String, double> restockTrend;
  final Map<String, double> platformBreakdown;

  InventoryAnalyticsSummary({
    required this.lowStockEvents,
    required this.topLowStockItem,
    required this.mostConsumedItem,
    required this.restockTotal,
    required this.restockTrend,
    required this.platformBreakdown,
  });
}

DateTime? _toDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value.toString()) ?? 0;
}
