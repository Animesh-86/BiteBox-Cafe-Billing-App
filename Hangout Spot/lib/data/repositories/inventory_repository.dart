import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';

class InventoryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  InventoryRepository(this._firestore, this._auth);

  DocumentReference<Map<String, dynamic>> _baseRef() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not logged in');
    }
    return _firestore.collection('cafes').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> _itemsRef() {
    return _baseRef().collection('inventory_items');
  }

  CollectionReference<Map<String, dynamic>> _dailyRef() {
    return _baseRef().collection('inventory_daily');
  }

  CollectionReference<Map<String, dynamic>> _movementsRef() {
    return _baseRef().collection('inventory_movements');
  }

  CollectionReference<Map<String, dynamic>> _remindersRef() {
    return _baseRef().collection('inventory_reminders');
  }

  CollectionReference<Map<String, dynamic>> _platformOrdersRef() {
    return _baseRef().collection('platform_orders');
  }

  Stream<List<InventoryItem>> watchItems() {
    return _itemsRef()
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => InventoryItem.fromDoc(doc)).toList(),
        );
  }

  Future<void> upsertItem(InventoryItem item) async {
    await _itemsRef().doc(item.id).set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> addItem(InventoryItem item) async {
    final ref = _itemsRef().doc(item.id);
    await ref.set(item.toMap());
  }

  Future<void> deleteItem(String itemId) async {
    await _itemsRef().doc(itemId).set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DailyInventory?> watchDaily(DateTime date) {
    final dateId = _dateId(date);
    return _dailyRef().doc(dateId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DailyInventory.fromDoc(doc);
    });
  }

  Future<void> upsertDaily(DailyInventory daily) async {
    await _dailyRef().doc(daily.id).set(daily.toMap(), SetOptions(merge: true));
  }

  Future<void> adjustStockTransaction({
    required String itemId,
    required double delta,
    required String reason,
  }) async {
    final itemRef = _itemsRef().doc(itemId);
    final movementRef = _movementsRef().doc();

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(itemRef);
      final current = _toDouble(snapshot.data()?['currentQty']);
      final next = current + delta;
      if (next < 0) {
        throw StateError('Insufficient stock');
      }

      tx.update(itemRef, {
        'currentQty': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(movementRef, {
        'itemId': itemId,
        'delta': delta,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<InventoryItem?> findItemByName(String name) async {
    final query = await _itemsRef()
        .where('name', isEqualTo: name)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return InventoryItem.fromDoc(query.docs.first);
  }

  Future<void> adjustStockByName({
    required String name,
    required double delta,
    String reason = 'order_sale',
  }) async {
    final item = await findItemByName(name);
    if (item == null) return;
    await adjustStockTransaction(itemId: item.id, delta: delta, reason: reason);
  }

  Future<void> batchRestock(
    Map<String, double> deltas, {
    String reason = 'restock',
  }) async {
    final batch = _firestore.batch();

    for (final entry in deltas.entries) {
      final itemRef = _itemsRef().doc(entry.key);
      batch.update(itemRef, {
        'currentQty': FieldValue.increment(entry.value),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final movementRef = _movementsRef().doc();
      batch.set(movementRef, {
        'itemId': entry.key,
        'delta': entry.value,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Stream<List<InventoryReminder>> watchReminders() {
    return _remindersRef()
        .orderBy('title')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => InventoryReminder.fromDoc(doc)).toList(),
        );
  }

  Future<void> upsertReminder(InventoryReminder reminder) async {
    await _remindersRef()
        .doc(reminder.id)
        .set(reminder.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteReminder(String id) async {
    await _remindersRef().doc(id).delete();
  }

  Future<void> createPlatformOrder(PlatformOrder order) async {
    await _platformOrdersRef().doc(order.id).set(order.toMap());
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchPlatformOrders({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    var query = _platformOrdersRef()
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchMovements({
    required String itemId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) {
    // Requires index: inventory_movements (itemId ASC, createdAt DESC)
    var query = _movementsRef()
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  Future<void> ensureDefaultBeverageInventory() async {
    final defaults = [
      {
        'name': 'Coca Cola',
        'category': 'Cold Drink',
        'unit': 'pcs',
        'currentQty': 50.0,
        'minQty': 10.0,
        'price': 20.0,
      },
      {
        'name': 'Sprite',
        'category': 'Cold Drink',
        'unit': 'pcs',
        'currentQty': 50.0,
        'minQty': 10.0,
        'price': 20.0,
      },
      {
        'name': 'Fanta',
        'category': 'Cold Drink',
        'unit': 'pcs',
        'currentQty': 50.0,
        'minQty': 10.0,
        'price': 20.0,
      },
      {
        'name': 'Thumbs Up',
        'category': 'Cold Drink',
        'unit': 'pcs',
        'currentQty': 50.0,
        'minQty': 10.0,
        'price': 20.0,
      },
      {
        'name': 'Water Bottle (Small)',
        'category': 'Water Bottle',
        'unit': 'pcs',
        'currentQty': 80.0,
        'minQty': 20.0,
        'price': 10.0,
      },
      {
        'name': 'Water Bottle (Large)',
        'category': 'Water Bottle',
        'unit': 'pcs',
        'currentQty': 60.0,
        'minQty': 15.0,
        'price': 20.0,
      },
    ];

    for (final item in defaults) {
      final existing = await findItemByName(item['name'] as String);
      if (existing != null) continue;

      final id = _slugify(item['name'] as String);
      await _itemsRef().doc(id).set({
        'name': item['name'],
        'category': item['category'],
        'unit': item['unit'],
        'currentQty': item['currentQty'],
        'minQty': item['minQty'],
        'price': item['price'],
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  String _dateId(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<InventoryAnalyticsSummary> loadInventoryAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final itemsSnapshot = await _itemsRef().get();
    final items = {
      for (final doc in itemsSnapshot.docs) doc.id: InventoryItem.fromDoc(doc),
    };

    final dailySnapshot = await _dailyRef()
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final lowStockCounts = <String, int>{};
    var totalLowStockEvents = 0;

    for (final doc in dailySnapshot.docs) {
      final daily = DailyInventory.fromDoc(doc);
      for (final entry in daily.items.entries) {
        final item = items[entry.key];
        if (item == null) continue;
        if (entry.value < item.minQty) {
          lowStockCounts[entry.key] = (lowStockCounts[entry.key] ?? 0) + 1;
          totalLowStockEvents += 1;
        }
      }
    }

    String? topLowStockItem;
    if (lowStockCounts.isNotEmpty) {
      final topEntry = lowStockCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      topLowStockItem = items[topEntry.key]?.name;
    }

    final movementsSnapshot = await _movementsRef()
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final consumedTotals = <String, double>{};
    final restockTrend = <String, double>{};
    var restockTotal = 0.0;

    for (final doc in movementsSnapshot.docs) {
      final data = doc.data();
      final itemId = data['itemId']?.toString();
      if (itemId == null) continue;
      final delta = _toDouble(data['delta']);
      final createdAt = _toDateTime(data['createdAt']) ?? startDate;
      final dayKey = _dateId(createdAt);

      if (delta < 0) {
        final item = items[itemId];
        if (item == null) continue;
        final category = item.category.toLowerCase();
        final isRaw =
            category.contains('raw') || category.contains('ingredient');
        if (isRaw) {
          consumedTotals[itemId] = (consumedTotals[itemId] ?? 0) + delta.abs();
        }
      }

      if (delta > 0) {
        restockTotal += delta;
        restockTrend[dayKey] = (restockTrend[dayKey] ?? 0) + delta;
      }
    }

    String? mostConsumedItem;
    if (consumedTotals.isNotEmpty) {
      final topEntry = consumedTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      mostConsumedItem = items[topEntry.key]?.name;
    }

    final platformSnapshot = await _platformOrdersRef()
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final platformBreakdown = <String, double>{};
    for (final doc in platformSnapshot.docs) {
      final data = doc.data();
      final platform = (data['platform'] ?? 'Other').toString();
      final total = _toDouble(data['total']);
      platformBreakdown[platform] = (platformBreakdown[platform] ?? 0) + total;
    }

    return InventoryAnalyticsSummary(
      lowStockEvents: totalLowStockEvents,
      topLowStockItem: topLowStockItem,
      mostConsumedItem: mostConsumedItem,
      restockTotal: restockTotal,
      restockTrend: restockTrend,
      platformBreakdown: platformBreakdown,
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value.toString()) ?? 0;
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

String _slugify(String value) {
  final cleaned = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final collapsed = cleaned.replaceAll(RegExp('-+'), '-');
  return collapsed.replaceAll(RegExp(r'^-|-$'), '');
}
