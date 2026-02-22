import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// Service to listen for real-time order updates and sync to local DB
class RealTimeOrderService {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  StreamSubscription? _orderSubscription;
  StreamSubscription? _individualOrdersSubscription;

  RealTimeOrderService(this._db, this._auth, this._firestore);

  // Start listening to orders collection (both legacy array and new subcollection)
  void startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing subscriptions if any
    stopListening();

    debugPrint('🎧 Starting Real-Time Order Listeners...');

    try {
      // Listen to individual order documents (NEW - better for multi-device)
      final individualOrdersRef = _firestore
          .collection('cafes')
          .doc(user.uid)
          .collection('orders')
          .snapshots();

      _individualOrdersSubscription = individualOrdersRef.listen(
        (snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              _processSingleOrder(change.doc.data()!);
            }
          }
        },
        onError: (e) {
          debugPrint('❌ Error in Individual Orders Listener: $e');
        },
      );

      // Listen to legacy array-based structure (backward compatibility)
      final ordersRef = _firestore
          .collection('cafes')
          .doc(user.uid)
          .collection('data')
          .doc('orders')
          .snapshots();

      _orderSubscription = ordersRef.listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            _processSnapshot(snapshot.data()!);
          }
        },
        onError: (e) {
          debugPrint('❌ Error in Legacy Order Listener: $e');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start listeners: $e');
    }
  }

  void stopListening() {
    _orderSubscription?.cancel();
    _orderSubscription = null;
    _individualOrdersSubscription?.cancel();
    _individualOrdersSubscription = null;
  }

  Future<void> _processSnapshot(Map<String, dynamic> data) async {
    try {
      final List<dynamic> ordersList = data['list'] ?? [];
      if (ordersList.isEmpty) return;

      debugPrint('📥 Received ${ordersList.length} orders from Cloud (Legacy)');

      // Process orders in background to verify against local DB
      // We only want to INSERT new orders or UPDATE modified ones
      // We do NOT delete local orders based on sync to prevent data loss

      await _db.transaction(() async {
        for (var orderMap in ordersList) {
          await _syncSingleOrder(orderMap);
        }
      });
    } catch (e) {
      debugPrint('❌ Error processing real-time snapshot: $e');
    }
  }

  // Process individual order document (better conflict resolution)
  Future<void> _processSingleOrder(Map<String, dynamic> orderMap) async {
    try {
      await _syncSingleOrder(orderMap);
    } catch (e) {
      debugPrint('❌ Error processing single order: $e');
    }
  }

  // Unified sync logic with timestamp-based conflict resolution
  Future<void> _syncSingleOrder(Map<String, dynamic> orderMap) async {
    try {
      final cloudOrder = Order.fromJson(orderMap);

      // Check if order exists locally
      final localOrder = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(cloudOrder.id))).getSingleOrNull();

      if (localOrder == null) {
        // New Order - Insert
        debugPrint('🆕 New Order received: ${cloudOrder.invoiceNumber}');
        await _db
            .into(_db.orders)
            .insert(cloudOrder, mode: InsertMode.insertOrReplace);

        // Restore orderItems if available
        await _restoreOrderItems(cloudOrder.id, orderMap);
      } else {
        // Existing Order - Use timestamp to resolve conflicts
        final cloudModified = orderMap['lastModified'];
        final localModified = localOrder.createdAt;

        bool shouldUpdate = false;

        // If cloud has timestamp, compare with local
        if (cloudModified != null) {
          DateTime cloudTime;
          if (cloudModified is Timestamp) {
            cloudTime = cloudModified.toDate();
          } else if (cloudModified is String) {
            cloudTime = DateTime.parse(cloudModified);
          } else {
            // No valid timestamp, fall back to status comparison
            shouldUpdate =
                localOrder.status != cloudOrder.status ||
                localOrder.paymentMode != cloudOrder.paymentMode;
            if (shouldUpdate) {
              debugPrint(
                '🔄 Updating Order (no timestamp): ${cloudOrder.invoiceNumber}',
              );
            }
            if (shouldUpdate) {
              await _db.update(_db.orders).replace(cloudOrder);
            }
            return;
          }

          // Cloud is newer, update local
          if (cloudTime.isAfter(localModified)) {
            debugPrint(
              '🔄 Updating Order (cloud newer): ${cloudOrder.invoiceNumber}',
            );
            await _db.update(_db.orders).replace(cloudOrder);
            // Update orderItems as well
            await _restoreOrderItems(cloudOrder.id, orderMap);
          } else {
            debugPrint(
              '⏭️ Skipping update (local newer): ${cloudOrder.invoiceNumber}',
            );
          }
        } else {
          // No timestamp, fall back to field comparison
          shouldUpdate =
              localOrder.status != cloudOrder.status ||
              localOrder.paymentMode != cloudOrder.paymentMode;
          if (shouldUpdate) {
            debugPrint(
              '🔄 Updating Order (field changed): ${cloudOrder.invoiceNumber}',
            );
            await _db.update(_db.orders).replace(cloudOrder);
            // Update orderItems as well
            await _restoreOrderItems(cloudOrder.id, orderMap);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing order: $e');
    }
  }

  // Restore orderItems from cloud data
  Future<void> _restoreOrderItems(
    String orderId,
    Map<String, dynamic> orderMap,
  ) async {
    try {
      final itemsData = orderMap['items'] as List<dynamic>?;
      if (itemsData == null || itemsData.isEmpty) {
        debugPrint('⚠️ No items data in cloud order: $orderId');
        return;
      }

      // Delete existing orderItems for this order
      await (_db.delete(
        _db.orderItems,
      )..where((t) => t.orderId.equals(orderId))).go();

      // Insert items from cloud
      for (final itemData in itemsData) {
        final itemMap = itemData as Map<String, dynamic>;
        await _db
            .into(_db.orderItems)
            .insert(
              OrderItemsCompanion(
                id: Value(const Uuid().v4()),
                orderId: Value(orderId),
                itemId: Value(itemMap['itemId'] as String),
                itemName: Value(itemMap['itemName'] as String),
                price: Value((itemMap['price'] as num).toDouble()),
                quantity: Value(itemMap['quantity'] as int),
                note: Value(itemMap['note'] as String? ?? ''),
                discountAmount: Value(
                  (itemMap['discountAmount'] as num?)?.toDouble() ?? 0.0,
                ),
              ),
            );
      }

      debugPrint('✅ Restored ${itemsData.length} items for order: $orderId');
    } catch (e) {
      debugPrint('❌ Error restoring orderItems: $e');
    }
  }
}

final realTimeOrderServiceProvider = Provider<RealTimeOrderService>((ref) {
  return RealTimeOrderService(
    ref.watch(appDatabaseProvider),
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});
