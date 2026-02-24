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
import 'package:hangout_spot/services/live_analytics_service.dart';
import 'package:hangout_spot/services/live_invoice_counter_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangout_spot/data/repositories/inventory_repository.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/data/constants/customer_defaults.dart';

class OrderRepository {
  final AppDatabase _db;
  final LiveAnalyticsService? _liveAnalytics;
  final LiveInvoiceCounterService? _liveInvoiceCounter;
  final InventoryRepository? _inventoryRepo;

  OrderRepository(
    this._db, {
    LiveAnalyticsService? liveAnalytics,
    LiveInvoiceCounterService? liveInvoiceCounter,
    InventoryRepository? inventoryRepository,
  }) : _liveAnalytics = liveAnalytics,
       _liveInvoiceCounter = liveInvoiceCounter,
       _inventoryRepo = inventoryRepository;

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
    final platformCustomerId = cart.customer?.id ?? CustomerDefaults.walkInId;
    // Determine the order ID first (reuse if editing)
    final orderId = cart.orderId ?? const Uuid().v4();

    // Preserve existing invoice number if order is already saved
    String? invoiceNum;
    if (cart.orderId != null) {
      final existingOrder = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(cart.orderId!))).getSingleOrNull();
      invoiceNum = existingOrder?.invoiceNumber;
    }

    // Generate invoice number based on status
    if (invoiceNum == null) {
      if (status == 'pending') {
        // For HOLD orders, use temporary invoice number
        invoiceNum =
            _liveInvoiceCounter?.generateHoldInvoiceNumber() ??
            'HOLD-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // For COMPLETED orders, use real sequential invoice number
        if (sessionManager != null) {
          invoiceNum = await sessionManager.getNextInvoiceNumber();
        } else {
          // Fallback to timestamp-based if no session manager
          invoiceNum =
              "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
        }
      }
    } else if (status == 'completed' && invoiceNum.startsWith('HOLD-')) {
      // Converting a HOLD order to COMPLETED - use the same counter source as UI (Firestore via SessionManager)
      if (sessionManager != null) {
        invoiceNum = await sessionManager.getNextInvoiceNumber();
      } else {
        invoiceNum =
            "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
      }
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

    await _db.transaction(() async {
      // If updating an existing Pending order, delete it first (simplest way to update items)
      if (cart.orderId != null) {
        // Only delete items, as we will replace the order row
        await (_db.delete(
          _db.orderItems,
        )..where((t) => t.orderId.equals(cart.orderId!))).go();
      }

      await _db
          .into(_db.orders)
          .insert(
            OrdersCompanion(
              id: Value(orderId),
              invoiceNumber: Value(invoiceNum!),
              customerId: Value(platformCustomerId),
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
              isSynced: const Value(false), // Always start as unsynced
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
    });

    // Fire and forget Firestore sync in the background so UI doesn't lag
    _tryImmediatePush(
      orderId,
      invoiceNum,
      cart,
      activeOutlet.id,
      status,
    ).ignore();

    // Record to live analytics and kitchen display (only for completed orders)
    if (status == 'completed') {
      await _decrementInventoryForCart(cart);
      _recordToLiveServices(orderId, invoiceNum).ignore();
    }

    return orderId;
  }

  /// Record order to Live Analytics and Kitchen Display System
  Future<void> _recordToLiveServices(String orderId, String invoiceNum) async {
    try {
      // Get order with items from database
      final order = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingleOrNull();

      if (order == null) return;

      // Get order items to count total quantity
      final items = await (_db.select(
        _db.orderItems,
      )..where((t) => t.orderId.equals(orderId))).get();

      final totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);

      // Record to Live Analytics with item count
      if (_liveAnalytics != null) {
        await _liveAnalytics.recordSale(order, itemCount: totalItems);
        debugPrint(
          '✅ Recorded to Live Analytics: $invoiceNum (Items: $totalItems)',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to record to live services: $e');
    }
  }

  Future<void> _decrementInventoryForCart(CartState cart) async {
    final repo = _inventoryRepo;
    if (repo == null) return;
    await repo.ensureDefaultBeverageInventory();
    const allowedNames = {
      'coca cola',
      'sprite',
      'fanta',
      'thumbs up',
      'water bottle (small)',
      'water bottle (large)',
    };
    for (final ci in cart.items) {
      if (ci.quantity <= 0) continue;
      final nameKey = ci.item.name.toLowerCase();
      if (!allowedNames.contains(nameKey)) continue;
      try {
        await repo.adjustStockByName(
          name: ci.item.name,
          delta: -ci.quantity.toDouble(),
          reason: 'order_sale',
        );
      } catch (e) {
        debugPrint('⚠️ Inventory adjust skipped for ${ci.item.name}: $e');
      }
    }
  }

  Future<void> _tryImmediatePush(
    String orderId,
    String invoiceNum,
    CartState cart,
    String locationId,
    String status,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Convert cart items to JSON format
        final itemsData = cart.items
            .map(
              (ci) => {
                'itemId': ci.item.id,
                'itemName': ci.item.name,
                'price': ci.item.price,
                'quantity': ci.quantity,
                'note': ci.note,
                'discountAmount': ci.discountAmount,
              },
            )
            .toList();

        final orderData = {
          'id': orderId,
          'invoiceNumber': invoiceNum,
          'customerId': cart.customer?.id,
          'locationId': locationId,
          'subtotal': cart.subtotal,
          'discountAmount': cart.totalDiscount,
          'taxAmount': cart.taxAmount,
          'totalAmount': cart.grandTotal,
          'paymentMode': cart.paymentMode,
          'paidCash': cart.paidCash,
          'paidUPI': cart.paidUPI,
          'status': status,
          'createdAt': DateTime.now().toIso8601String(),
          'isSynced': true,
          'lastModified': FieldValue.serverTimestamp(),
          'items': itemsData, // Include items in the order data
        };

        // Push as individual order document (better for multi-device sync)
        await FirebaseFirestore.instance
            .collection('cafes')
            .doc(user.uid)
            .collection('orders')
            .doc(orderId)
            .set(orderData, SetOptions(merge: true));

        final orderDataArray = Map<String, dynamic>.from(orderData);
        orderDataArray['lastModified'] = DateTime.now().toIso8601String();

        // Also update the legacy array-based structure for backward compatibility
        await FirebaseFirestore.instance
            .collection('cafes')
            .doc(user.uid)
            .collection('data')
            .doc('orders')
            .set({
              'list': FieldValue.arrayUnion([orderDataArray]),
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        // Push orderItems to separate collection for manual restore support
        for (final itemData in itemsData) {
          final itemWithOrderId = Map<String, dynamic>.from(itemData);
          itemWithOrderId['orderId'] = orderId;
          itemWithOrderId['id'] = const Uuid()
              .v4(); // Generate unique ID for orderItem

          await FirebaseFirestore.instance
              .collection('cafes')
              .doc(user.uid)
              .collection('data')
              .doc('order_items')
              .set({
                'list': FieldValue.arrayUnion([itemWithOrderId]),
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }

        // Mark as synced locally
        await (_db.update(_db.orders)..where((t) => t.id.equals(orderId)))
            .write(const OrdersCompanion(isSynced: Value(true)));

        debugPrint('✅ Order pushed to Firestore: $invoiceNum');
      }
    } catch (e) {
      debugPrint("⚠️ Immediate Push failed (will be retried later): $e");
    }
  }

  // Soft Delete strategy: Cancel instead of Delete
  Future<void> voidOrder(String orderId) async {
    await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
      const OrdersCompanion(
        status: Value('cancelled'),
        isSynced: Value(
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

      await (_db.update(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
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

  /// Retry syncing orders that failed to push to Firestore
  /// Called by background sync service or manual backup
  Future<int> syncUnsyncedOrders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ Not logged in, skipping unsynced orders sync');
        return 0;
      }

      // Get all unsynced orders
      final unsyncedQuery = _db.select(_db.orders)
        ..where((tbl) => tbl.isSynced.equals(false));

      final unsyncedOrders = await unsyncedQuery.get();

      if (unsyncedOrders.isEmpty) {
        return 0;
      }

      debugPrint(
        '🔄 Retrying sync for ${unsyncedOrders.length} unsynced orders...',
      );

      int successCount = 0;
      for (var order in unsyncedOrders) {
        try {
          final orderData = {
            'id': order.id,
            'invoiceNumber': order.invoiceNumber,
            'customerId': order.customerId,
            'locationId': order.locationId,
            'subtotal': order.subtotal,
            'discountAmount': order.discountAmount,
            'taxAmount': order.taxAmount,
            'totalAmount': order.totalAmount,
            'paymentMode': order.paymentMode,
            'paidCash': order.paidCash,
            'paidUPI': order.paidUPI,
            'status': order.status,
            'createdAt': order.createdAt.toIso8601String(),
            'isSynced': true,
            'lastModified': FieldValue.serverTimestamp(),
          };

          // Push as individual document (preferred)
          await FirebaseFirestore.instance
              .collection('cafes')
              .doc(user.uid)
              .collection('orders')
              .doc(order.id)
              .set(orderData, SetOptions(merge: true));

          final orderDataArray = Map<String, dynamic>.from(orderData);
          orderDataArray['lastModified'] = DateTime.now().toIso8601String();

          // Also update legacy array structure
          await FirebaseFirestore.instance
              .collection('cafes')
              .doc(user.uid)
              .collection('data')
              .doc('orders')
              .set({
                'list': FieldValue.arrayUnion([orderDataArray]),
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          // Mark as synced in local DB
          await (_db.update(_db.orders)..where((t) => t.id.equals(order.id)))
              .write(const OrdersCompanion(isSynced: Value(true)));

          successCount++;
          debugPrint('✅ Synced order: ${order.invoiceNumber}');
        } catch (e) {
          debugPrint('❌ Failed to sync order ${order.invoiceNumber}: $e');
          // Continue with next order
        }
      }

      debugPrint(
        '✅ Successfully synced $successCount/${unsyncedOrders.length} orders',
      );
      return successCount;
    } catch (e) {
      debugPrint('❌ Error in syncUnsyncedOrders: $e');
      return 0;
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final inventoryRepo = ref.watch(inventoryRepositoryProvider);

  // Initialize Firebase Realtime Database services
  final liveAnalytics = LiveAnalyticsService();
  final liveInvoiceCounter = LiveInvoiceCounterService();

  return OrderRepository(
    db,
    liveAnalytics: liveAnalytics,
    liveInvoiceCounter: liveInvoiceCounter,
    inventoryRepository: inventoryRepo,
  );
});
