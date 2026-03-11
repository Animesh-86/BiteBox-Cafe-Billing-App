import 'package:hangout_spot/utils/log_utils.dart';
import 'package:hangout_spot/utils/timestamp_utils.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/data/providers/realtime_services_provider.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// Service to listen for real-time order updates and sync to local DB
class RealTimeOrderService {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final VoidCallback? _onRemoteOrderSynced;

  StreamSubscription? _individualOrdersSubscription;

  RealTimeOrderService(
    this._db,
    this._auth,
    this._firestore, {
    VoidCallback? onRemoteOrderSynced,
  }) : _onRemoteOrderSynced = onRemoteOrderSynced;

  // Start listening to orders collection (individual document subcollection)
  void startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing subscriptions if any
    stopListening();

    logDebug('🎧 Starting Real-Time Order Listener...');

    try {
      // Listen to individual order documents (scalable, multi-device safe)
      final individualOrdersRef = _firestore
          .collection('cafes')
          .doc(user.uid)
          .collection('orders')
          .snapshots();

      _individualOrdersSubscription = individualOrdersRef.listen(
        (snapshot) async {
          bool anyChanges = false;
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final changed = await _processSingleOrder(change.doc.data()!);
              if (changed) anyChanges = true;
            }
          }
          // Notify analytics providers once per batch
          if (anyChanges) {
            _onRemoteOrderSynced?.call();
          }
        },
        onError: (e) {
          logDebug('❌ Error in Order Listener: $e');
        },
      );
    } catch (e) {
      logDebug('❌ Failed to start listeners: $e');
    }
  }

  void stopListening() {
    _individualOrdersSubscription?.cancel();
    _individualOrdersSubscription = null;
  }

  // Process individual order document (better conflict resolution)
  // Returns true if local DB was updated.
  Future<bool> _processSingleOrder(Map<String, dynamic> orderMap) async {
    try {
      return await _syncSingleOrder(orderMap);
    } catch (e) {
      logDebug('❌ Error processing single order: $e');
      return false;
    }
  }

  // Unified sync logic with timestamp-based conflict resolution.
  // Returns true if local DB was modified.
  Future<bool> _syncSingleOrder(Map<String, dynamic> orderMap) async {
    try {
      final cloudOrder = Order.fromJson(sanitiseDateFields(orderMap));

      // Check if order exists locally
      final localOrder = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(cloudOrder.id))).getSingleOrNull();

      if (localOrder == null) {
        // New Order - Insert
        logDebug('🆕 New Order received: ${cloudOrder.invoiceNumber}');
        await _db
            .into(_db.orders)
            .insert(cloudOrder, mode: InsertMode.insertOrReplace);

        // Restore orderItems if available
        await _restoreOrderItems(cloudOrder.id, orderMap);
        return true;
      } else {
        // Existing Order - Use timestamp to resolve conflicts

        // BUG-1 fix: guard locally-cancelled orders. A cashier's explicit
        // cancellation must never be silently reverted by a stale cloud snapshot
        // that arrived after the local change. Only the cloud's own 'cancelled'
        // status can override a local cancellation.
        if (localOrder.status == 'cancelled' &&
            cloudOrder.status != 'cancelled') {
          logDebug(
            '⏭️ Skipping update – protecting local cancellation: '
            '${cloudOrder.invoiceNumber}',
          );
          return false;
        }

        final cloudModified = orderMap['lastModified'];
        // BUG-1 fix: local orders don't have a persisted lastModified field,
        // so fall back to createdAt as an approximation. This is still
        // imperfect but the cancellation guard above covers the highest-risk
        // case. A proper fix requires adding a lastModified column to orders.
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
              logDebug(
                '🔄 Updating Order (no timestamp): ${cloudOrder.invoiceNumber}',
              );
              await _db.update(_db.orders).replace(cloudOrder);
            }
            return shouldUpdate;
          }

          // Cloud is newer, update local
          if (cloudTime.isAfter(localModified)) {
            logDebug(
              '🔄 Updating Order (cloud newer): ${cloudOrder.invoiceNumber}',
            );
            await _db.update(_db.orders).replace(cloudOrder);
            // Update orderItems as well
            await _restoreOrderItems(cloudOrder.id, orderMap);
            return true;
          } else {
            logDebug(
              '⏭️ Skipping update (local newer): ${cloudOrder.invoiceNumber}',
            );
            return false;
          }
        } else {
          // No timestamp, fall back to field comparison
          shouldUpdate =
              localOrder.status != cloudOrder.status ||
              localOrder.paymentMode != cloudOrder.paymentMode;
          if (shouldUpdate) {
            logDebug(
              '🔄 Updating Order (field changed): ${cloudOrder.invoiceNumber}',
            );
            await _db.update(_db.orders).replace(cloudOrder);
            // Update orderItems as well
            await _restoreOrderItems(cloudOrder.id, orderMap);
          }
          return shouldUpdate;
        }
      }
    } catch (e) {
      logDebug('❌ Error syncing order: $e');
      return false;
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
        logDebug('⚠️ No items data in cloud order: $orderId');
        return;
      }

      // OFFLINE-3 fix: wrap delete+insert in a transaction so a mid-sync app
      // kill never leaves an order with no items (which would show as empty on
      // the dashboard and break totals).
      await _db.transaction(() async {
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
      });

      logDebug('✅ Restored ${itemsData.length} items for order: $orderId');
    } catch (e) {
      logDebug('❌ Error restoring orderItems: $e');
    }
  }
}

final realTimeOrderServiceProvider = Provider<RealTimeOrderService>((ref) {
  return RealTimeOrderService(
    ref.watch(appDatabaseProvider),
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
    onRemoteOrderSynced: () {
      // Bump the generation counter so analytics providers auto-refresh
      ref.read(remoteSyncGenerationProvider.notifier).state++;
      logDebug('📊 Remote sync generation bumped → analytics will refresh');
    },
  );
});
