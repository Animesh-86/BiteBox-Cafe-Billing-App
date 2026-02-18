import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:hangout_spot/services/logging_service.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

class OrderRepository {
  final AppDatabase _db;

  OrderRepository(this._db);

  // Stream of Held/Pending Orders
  Stream<List<Order>> watchPendingOrders({String? locationId}) {
    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.status.equals('pending'));
    if (locationId != null && locationId.trim().isNotEmpty) {
      query.where((tbl) => tbl.locationId.equals(locationId));
    }

    return (query..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Get items for a specific order
  Future<List<OrderItem>> getOrderItems(String orderId) {
    return (_db.select(
      _db.orderItems,
    )..where((t) => t.orderId.equals(orderId))).get();
  }

  Stream<List<Order>> watchOrdersByCustomer(
    String customerId, {
    String? locationId,
  }) {
    final query = _db.select(_db.orders)
      ..where((t) => t.customerId.equals(customerId));
    if (locationId != null && locationId.trim().isNotEmpty) {
      query.where((t) => t.locationId.equals(locationId));
    }

    return (query..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<List<({OrderItem orderItem, Item realItem})>> getOrderDetails(
    String orderId,
  ) async {
    final query = _db.select(_db.orderItems).join([
      innerJoin(_db.items, _db.items.id.equalsExp(_db.orderItems.itemId)),
    ])..where(_db.orderItems.orderId.equals(orderId));

    final rows = await query.get();
    return rows
        .map(
          (row) => (
            orderItem: row.readTable(_db.orderItems),
            realItem: row.readTable(_db.items),
          ),
        )
        .toList();
  }

  Future<String> createOrderFromCart(
    CartState cart, {
    String status = 'completed',
    SessionManager? sessionManager,
  }) async {
    return _db.transaction(() async {
      // If updating an existing Pending order, delete it first (simplest way to update items)
      // Ideally we would diff, but replacing is safer for ensuring totals match exact cart state.
      if (cart.orderId != null) {
        // Only delete items, as we will replace the order row
        await (_db.delete(
          _db.orderItems,
        )..where((t) => t.orderId.equals(cart.orderId!))).go();
      }

      // Reuse ID if editing, else new
      final orderId = cart.orderId ?? const Uuid().v4();

      // Generate session-based invoice number
      String invoiceNum;
      if (sessionManager != null) {
        invoiceNum = await sessionManager.getNextInvoiceNumber();
      } else {
        // Fallback to timestamp-based if no session manager
        invoiceNum =
            "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
      }

      // Get active outlet (required for order creation)
      final activeOutlet = await (_db.select(
        _db.locations,
      )..where((t) => t.isActive.equals(true))).getSingleOrNull();

      if (activeOutlet == null) {
        throw Exception(
          'No active outlet found. Please activate an outlet in Settings before creating orders.',
        );
      }

      await _db
          .into(_db.orders)
          .insert(
            OrdersCompanion(
              id: Value(orderId),
              invoiceNumber: Value(invoiceNum),
              customerId: Value(cart.customer?.id),
              locationId: Value(activeOutlet.id), // Use active outlet
              subtotal: Value(cart.subtotal),
              discountAmount: Value(cart.totalDiscount),
              taxAmount: Value(cart.taxAmount),
              totalAmount: Value(cart.grandTotal),
              paymentMode: Value(cart.paymentMode),
              paidCash: Value(cart.paidCash),
              paidUPI: Value(cart.paidUPI),
              status: Value(status), // 'pending' or 'completed'
              createdAt: Value(DateTime.now()),
            ),
            mode: InsertMode.replace, // Replace if exists
          );

      for (final ci in cart.items) {
        await _db
            .into(_db.orderItems)
            .insert(
              OrderItemsCompanion(
                id: Value(const Uuid().v4()),
                orderId: Value(orderId),
                itemId: Value(ci.item.id),
                itemName: Value(ci.item.name),
                price: Value(ci.item.price),
                quantity: Value(ci.quantity),
                note: Value(ci.note),
                discountAmount: Value(ci.discountAmount),
              ),
            );
      }

      // IMMEDIATE PUSH: Send to Firestore for Real-Time Sync
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final orderData = {
            'id': orderId,
            'invoiceNumber': invoiceNum,
            'customerId': cart.customer?.id,
            'locationId': activeOutlet.id,
            'subtotal': cart.subtotal,
            'discountAmount': cart.totalDiscount,
            'taxAmount': cart.taxAmount,
            'totalAmount': cart.grandTotal,
            'paymentMode': cart.paymentMode,
            'paidCash': cart.paidCash,
            'paidUPI': cart.paidUPI,
            'status': status,
            'createdAt': DateTime.now().toIso8601String(),
            'isSynced': true, // Marked as synced since we are pushing now
          };

          // Push to Firestore order collection
          // We use 'data/orders' inside the user doc as per SyncRepository structure
          // Note: Full sync also pushes 'order_items', but for Invoice Numbering speed,
          // pushing the main Order doc is sufficient for the Listener to pick it up.
          // To be safe, we should match the SyncRepository structure exactly.

          /* 
             Ideally, we should reuse SyncRepository logic, but we need speed here.
             We will push to the specific document path.
          */

          // Push to Firestore order collection
          // Utilising FieldValue.arrayUnion to append to the list in `data/orders`

          await FirebaseFirestore.instance
              .collection('cafes')
              .doc(user.uid)
              .collection('data')
              .doc('orders')
              .set({
                'list': FieldValue.arrayUnion([orderData]),
              }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint("⚠️ Immediate Push failed: $e");
        // Don't fail the local transaction. Just log it. Sync will catch it later.
      }

      return orderId;
    });
  }

  // Soft Delete strategy: Cancel instead of Delete
  Future<void> voidOrder(String orderId) async {
    await _db
        .update(_db.orders)
        .replace(
          OrdersCompanion(
            id: Value(orderId),
            status: const Value('cancelled'),
            isSynced: const Value(
              false,
            ), // Mark unsynced so it pushes to cloud on next sync
          ),
        );

    // Attempt immediate push of cancellation
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // For array removal/update, it is tricky with just arrayUnion.
        // We might need to rely on the background SyncRepository for robust updates
        // or read-modify-write here.
        // For now, let's mark it locally. The RealTimeListener on OTHER devices
        // won't see the cancellation instantly unless we handle it,
        // but they definitely won't see a "Missing Number".

        // To notify others INSTANTLY, we would need to push the updated order.
        // But dealing with `list` updates for a specific item in Firestore is hard.
        // We will rely on BackupSync for full consistency of edits.
        // The critical part (Creation Numbering) is handled by `createOrder`.
      }
    } catch (e) {
      print(e);
    }
  }

  // Deprecated: Hard delete is removed to preserve invoice sequence
  // Future<void> deleteOrder(String orderId) async { ... }

  // Handle reward points for completed orders
  Future<void> processRewardForOrder(
    String orderId,
    double orderAmount,
    String? customerId,
  ) async {
    if (customerId == null || customerId.isEmpty) {
      return; // No reward for anonymous orders
    }

    // Check if reward system is enabled by querying settings
    final settings =
        await (_db.select(_db.settings)
              ..where((tbl) => tbl.key.equals('reward_system_enabled')))
            .getSingleOrNull();

    if (settings != null && settings.value != 'true') {
      return; // Reward system disabled
    }

    // Get earning rate
    final rateSettings = await (_db.select(
      _db.settings,
    )..where((tbl) => tbl.key.equals('reward_earning_rate'))).getSingleOrNull();

    final rate = rateSettings != null
        ? double.tryParse(rateSettings.value) ?? REWARD_EARNING_RATE
        : REWARD_EARNING_RATE;

    final pointsEarned = orderAmount * rate;

    if (pointsEarned > 0) {
      // Insert reward transaction
      await _db
          .into(_db.rewardTransactions)
          .insert(
            RewardTransactionsCompanion(
              id: Value(const Uuid().v4()),
              customerId: Value(customerId),
              type: const Value('earn'),
              amount: Value(pointsEarned),
              orderId: Value(orderId),
              description: Value('Earned from order #$orderId'),
            ),
          );
    }
  }

  // Update customer visit count and total spent
  Future<void> updateCustomerStats(
    String customerId,
    double orderAmount,
  ) async {
    try {
      final customer = await _db.customers.select().get();
      final cust = customer.firstWhere((c) => c.id == customerId);

      await _db
          .update(_db.customers)
          .replace(
            CustomersCompanion(
              id: Value(customerId),
              name: Value(cust.name),
              phone: Value(cust.phone),
              discountPercent: Value(cust.discountPercent),
              totalVisits: Value(cust.totalVisits + 1),
              totalSpent: Value(cust.totalSpent + orderAmount),
              lastVisit: Value(DateTime.now()),
            ),
          );
    } catch (e) {
      // Customer not found, skip update
      LoggingService.logError('Error updating customer stats', e);
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OrderRepository(db);
});
