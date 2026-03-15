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
              final data = change.doc.data();
              if (data == null) continue;

              // Skip echo-back: if the doc has isSynced=true and matches a
              // local order that is already synced with same status, this is
              // likely our own push echoing back from Firestore.
              final docId = data['id'] as String?;
              if (docId != null) {
                final local = await (_db.select(
                  _db.orders,
                )..where((t) => t.id.equals(docId))).getSingleOrNull();
                if (local != null &&
                    local.isSynced &&
                    local.status == (data['status'] as String?) &&
                    local.paymentMode == (data['paymentMode'] as String?) &&
                    local.invoiceNumber == (data['invoiceNumber'] as String?)) {
                  // This is our own write echoing back — skip
                  continue;
                }
              }

              final changed = await _processSingleOrder(data);
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
      final sanitised = sanitiseDateFields(orderMap);
      final cloudOrder = Order.fromJson(sanitised);
      final cloudSyncVersion = (orderMap['syncVersion'] as num?)?.toInt() ?? 1;

      // Check if order exists locally by ID
      final localOrder = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(cloudOrder.id))).getSingleOrNull();

      if (localOrder == null) {
        // ── NEW ORDER (not seen locally before) ──
        // Check for invoiceNumber collision with a different order ID
        final conflictingOrder =
            await (_db.select(_db.orders)..where(
                  (t) => t.invoiceNumber.equals(cloudOrder.invoiceNumber),
                ))
                .getSingleOrNull();

        if (conflictingOrder != null) {
          // Invoice collision with different order ID — resolve by status priority
          if (cloudOrder.status == 'completed' &&
              conflictingOrder.status != 'completed') {
            logDebug(
              '⚔️ Collision resolved: Cloud COMPLETED wins. Replacing local ${conflictingOrder.status}.',
            );
          } else if (conflictingOrder.status == 'completed' &&
              cloudOrder.status != 'completed') {
            logDebug(
              '⚔️ Collision resolved: Local COMPLETED protects against Cloud ${cloudOrder.status}.',
            );
            return false;
          } else {
            // Both same status — newer wins
            if (cloudOrder.createdAt.isAfter(conflictingOrder.createdAt)) {
              logDebug('⚔️ Collision resolved: Cloud is newer.');
            } else {
              logDebug('⚔️ Collision resolved: Local is newer.');
              return false;
            }
          }
        } else {
          logDebug('🆕 New Order received: ${cloudOrder.invoiceNumber}');
        }

        // Insert the cloud order
        await _db
            .into(_db.orders)
            .insert(cloudOrder, mode: InsertMode.insertOrReplace);

        // Restore orderItems if available
        await _restoreOrderItems(cloudOrder.id, orderMap);
        return true;
      } else {
        // ── EXISTING ORDER (update) ──

        // Guard: locally-cancelled orders are protected from stale pending updates
        if (localOrder.status == 'cancelled' &&
            cloudOrder.status == 'pending') {
          logDebug(
            '⏭️ Skipping update – protecting local cancellation from stale pending: '
            '${cloudOrder.invoiceNumber}',
          );
          return false;
        }

        // If the local order was modified locally and not yet synced, protect it
        // unless the cloud version has a higher syncVersion or is strictly newer.
        if (!localOrder.isSynced) {
          // Local has unsynced changes — only accept cloud if it has higher version
          if (cloudSyncVersion <= localOrder.syncVersion) {
            logDebug(
              '⏭️ Skipping update – local has unsynced changes (v${localOrder.syncVersion} >= cloud v$cloudSyncVersion): '
              '${cloudOrder.invoiceNumber}',
            );
            return false;
          }
        }

        // Compare using lastModified (proper field, no longer falling back to createdAt)
        final cloudModified = orderMap['lastModified'];
        final localModified = localOrder.lastModified ?? localOrder.createdAt;

        bool shouldUpdate = false;

        if (cloudModified != null) {
          DateTime? cloudTime;
          if (cloudModified is Timestamp) {
            cloudTime = cloudModified.toDate();
          } else if (cloudModified is String) {
            cloudTime = DateTime.tryParse(cloudModified);
          }

          if (cloudTime != null) {
            if (cloudTime.isAfter(localModified)) {
              shouldUpdate = true;
              logDebug(
                '🔄 Updating Order (cloud newer): ${cloudOrder.invoiceNumber}',
              );
            } else {
              logDebug(
                '⏭️ Skipping update (local newer): ${cloudOrder.invoiceNumber}',
              );
              return false;
            }
          } else {
            // Invalid timestamp — fall back to field comparison
            shouldUpdate =
                localOrder.status != cloudOrder.status ||
                localOrder.paymentMode != cloudOrder.paymentMode;
          }
        } else {
          // No timestamp — fall back to syncVersion and field comparison
          if (cloudSyncVersion > localOrder.syncVersion) {
            shouldUpdate = true;
          } else {
            shouldUpdate =
                localOrder.status != cloudOrder.status ||
                localOrder.paymentMode != cloudOrder.paymentMode;
          }
        }

        if (shouldUpdate) {
          logDebug('🔄 Updating Order: ${cloudOrder.invoiceNumber}');
          await _db.update(_db.orders).replace(cloudOrder);
          await _restoreOrderItems(cloudOrder.id, orderMap);
          return true;
        }
        return false;
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
          // Preserve the original item ID from cloud to prevent duplicates.
          // Only generate a new UUID if the cloud data doesn't include an ID.
          final itemId = (itemMap['id'] as String?) ?? const Uuid().v4();
          await _db
              .into(_db.orderItems)
              .insert(
                OrderItemsCompanion(
                  id: Value(itemId),
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
                mode: InsertMode.insertOrReplace,
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
