import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:drift/drift.dart';

// Service to listen for real-time order updates and sync to local DB
class RealTimeOrderService {
  final AppDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  StreamSubscription? _orderSubscription;

  RealTimeOrderService(this._db, this._auth, this._firestore);

  // Start listening to orders collection
  void startListening() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Cancel existing subscription if any
    stopListening();

    debugPrint('🎧 Starting Real-Time Order Listener...');

    try {
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
          debugPrint('❌ Error in Real-Time Order Listener: $e');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start listener: $e');
    }
  }

  void stopListening() {
    _orderSubscription?.cancel();
    _orderSubscription = null;
  }

  Future<void> _processSnapshot(Map<String, dynamic> data) async {
    try {
      final List<dynamic> ordersList = data['list'] ?? [];
      if (ordersList.isEmpty) return;

      debugPrint('📥 Received ${ordersList.length} orders from Cloud');

      // Process orders in background to verify against local DB
      // We only want to INSERT new orders or UPDATE modified ones
      // We do NOT delete local orders based on sync to prevent data loss

      await _db.transaction(() async {
        for (var orderMap in ordersList) {
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
          } else {
            // Existing Order - Check if update needed (e.g. status changed)
            if (localOrder.status != cloudOrder.status ||
                localOrder.paymentMode != cloudOrder.paymentMode) {
              debugPrint('🔄 Updating Order: ${cloudOrder.invoiceNumber}');
              await _db.update(_db.orders).replace(cloudOrder);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error processing real-time snapshot: $e');
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
