import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';

class OrderRepository {
  final AppDatabase _db;

  OrderRepository(this._db);

  // Stream of Held/Pending Orders
  Stream<List<Order>> watchPendingOrders() {
    return (_db.select(_db.orders)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  // Get items for a specific order
  Future<List<OrderItem>> getOrderItems(String orderId) {
    return (_db.select(
      _db.orderItems,
    )..where((t) => t.orderId.equals(orderId))).get();
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

      await _db
          .into(_db.orders)
          .insert(
            OrdersCompanion(
              id: Value(orderId),
              invoiceNumber: Value(invoiceNum),
              customerId: Value(cart.customer?.id),
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
      return orderId;
    });
  }

  // Delete an order
  Future<void> deleteOrder(String orderId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.orderItems,
      )..where((t) => t.orderId.equals(orderId))).go();
      await (_db.delete(_db.orders)..where((t) => t.id.equals(orderId))).go();
    });
  }

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

    if (settings == null || settings.value != 'true') {
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
      debugPrint("Error updating customer stats: $e");
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OrderRepository(db);
});
