import 'package:hangout_spot/utils/log_utils.dart';
import 'package:drift/drift.dart';
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
import 'package:hangout_spot/data/repositories/customer_repository.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
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
    SyncRepository? syncRepo,
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
          // Fallback: unique but non-sequential (avoids collision via UUID suffix)
          invoiceNum =
              "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-${const Uuid().v4().substring(0, 4)}";
        }
      }
    } else if (status == 'completed' && invoiceNum.startsWith('HOLD-')) {
      // Converting a HOLD order to COMPLETED
      if (sessionManager != null) {
        invoiceNum = await sessionManager.getNextInvoiceNumber();
      } else {
        invoiceNum =
            "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-${const Uuid().v4().substring(0, 4)}";
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

    // NOTE: Orders are pushed individually via _tryImmediatePush.
    // Full backupData() is handled by AutoSyncService on a schedule.

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
        logDebug(
          '✅ Recorded to Live Analytics: $invoiceNum (Items: $totalItems)',
        );
      }
    } catch (e) {
      logDebug('❌ Failed to record to live services: $e');
    }
  }

  Future<void> markOrderAsPaid(
    String orderId,
    String paymentMode, {
    SyncRepository? syncRepo,
  }) async {
    await _db.transaction(() async {
      final order = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingleOrNull();

      if (order == null) return;

      // Get order items to count total quantity
      final items = await (_db.select(
        _db.orderItems,
      )..where((t) => t.orderId.equals(orderId))).get();

      final totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);

      await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('completed'),
          paymentMode: Value(paymentMode),
          isSynced: const Value(false), // Mark unsynced to push payment update
        ),
      );

      // Record to Live Analytics with item count
      if (_liveAnalytics != null) {
        await _liveAnalytics.recordSale(order, itemCount: totalItems);
        logDebug(
          '✅ Recorded to Live Analytics: ${order.invoiceNumber} (Items: $totalItems)',
        );
      }
    });

    // Push the payment update to Firestore immediately
    _tryPushOrderUpdate(orderId).ignore();
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
        logDebug('⚠️ Inventory adjust skipped for ${ci.item.name}: $e');
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
        // Fetch order items from DB to get proper IDs
        final orderItems = await getOrderItems(orderId);
        final itemsData = orderItems
            .map(
              (oi) => {
                'id': oi.id,
                'itemId': oi.itemId,
                'itemName': oi.itemName,
                'price': oi.price,
                'quantity': oi.quantity,
                'note': oi.note,
                'discountAmount': oi.discountAmount,
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

        // Push as individual order document (scalable for multi-device sync)
        await FirebaseFirestore.instance
            .collection('cafes')
            .doc(user.uid)
            .collection('orders')
            .doc(orderId)
            .set(orderData, SetOptions(merge: true));

        // Mark as synced locally
        await (_db.update(_db.orders)..where((t) => t.id.equals(orderId)))
            .write(const OrdersCompanion(isSynced: Value(true)));

        logDebug('✅ Order pushed to Firestore: $invoiceNum');
      }
    } catch (e) {
      logDebug("⚠️ Immediate Push failed (will be retried later): $e");
    }
  }

  /// Push a single order update (status change, payment change) to Firestore.
  /// Used for cancel/markAsPaid so changes sync without a full backup.
  Future<void> _tryPushOrderUpdate(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final order = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingleOrNull();
      if (order == null) return;

      // Fetch order items to include in the document
      final items = await getOrderItems(orderId);
      final itemsData = items
          .map(
            (oi) => {
              'id': oi.id,
              'itemId': oi.itemId,
              'itemName': oi.itemName,
              'price': oi.price,
              'quantity': oi.quantity,
              'note': oi.note,
              'discountAmount': oi.discountAmount,
            },
          )
          .toList();

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
        'items': itemsData,
      };

      await FirebaseFirestore.instance
          .collection('cafes')
          .doc(user.uid)
          .collection('orders')
          .doc(orderId)
          .set(orderData, SetOptions(merge: true));

      await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
        const OrdersCompanion(isSynced: Value(true)),
      );

      logDebug('✅ Order update pushed: ${order.invoiceNumber}');
    } catch (e) {
      logDebug('⚠️ Order update push failed (will retry): $e');
    }
  }

  // Soft Delete strategy: Cancel instead of Delete
  Future<void> cancelOrder(
    String orderId, {
    SyncRepository? syncRepo,
    CustomerRepository? customerRepo,
  }) async {
    // We need the order details before we cancel it to properly revert its impacts
    final order = await (_db.select(
      _db.orders,
    )..where((t) => t.id.equals(orderId))).getSingleOrNull();
    final items = await getOrderItems(orderId);
    final itemCount = items.fold<int>(0, (sum, item) => sum + item.quantity);

    await _db.transaction(() async {
      await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
        const OrdersCompanion(
          status: Value('cancelled'),
          isSynced: Value(
            false,
          ), // Mark unsynced so it pushes to cloud on next sync
        ),
      );
    });

    // Attempt immediate push of cancellation outside of database transaction
    // to prevent Firebase Realtime Database thread locks from hanging SQLite.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Revert analytics
        if (order != null) {
          await _liveAnalytics?.revertSale(order, itemCount: itemCount);
          if (customerRepo != null && order.customerId != null) {
            await customerRepo.revertVisitStats(
              order.customerId!,
              order.totalAmount,
              syncRepo: syncRepo,
            );
          }
        }
      }
    } catch (e) {
      logDebug('Failed to push live order cancellation bounds: $e');
    }

    // Push the cancellation to Firestore immediately
    _tryPushOrderUpdate(orderId).ignore();
  }

  Future<void> revertOrderItems(String orderId) async {
    // TODO: Implement logic to revert inventory for a cancelled order
    // This would involve fetching order items and calling inventoryRepo.adjustStockByName with positive delta
  }

  // Deprecated: Hard delete is removed to preserve invoice sequence
  // Future<void> deleteOrder(String orderId) async { ... }

  // Handle reward points for completed orders
  Future<void> processRewardForOrder(
    String orderId,
    double orderAmount,
    String? customerId, {
    SyncRepository? syncRepo,
  }) async {
    if (customerId == null ||
        customerId.isEmpty ||
        customerId == CustomerDefaults.walkInId) {
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
      await _db.transaction(() async {
        final order = await (_db.select(
          _db.orders,
        )..where((t) => t.id.equals(orderId))).getSingleOrNull();
        if (order == null) return;

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
                description: Value('Earned from Order #${order.invoiceNumber}'),
              ),
            );
      });
    }
    // We don't need a syncRepo call here because processRewardForOrder is always called immediately after createOrderFromCart, which already has one
  }

  // Update customer visit count and total spent
  Future<void> updateCustomerStats(
    String customerId,
    double orderAmount, {
    SyncRepository? syncRepo,
  }) async {
    if (customerId == CustomerDefaults.walkInId)
      return; // No stats for walk-in customer

    try {
      await _db.transaction(() async {
        final customer = await (_db.select(
          _db.customers,
        )..where((t) => t.id.equals(customerId))).getSingleOrNull();

        if (customer == null) {
          LoggingService.logError(
            'Customer not found for stats update',
            Exception('Customer not found'),
          );
          return;
        }

        await (_db.update(
          _db.customers,
        )..where((t) => t.id.equals(customerId))).write(
          CustomersCompanion(
            totalVisits: Value(customer.totalVisits + 1),
            totalSpent: Value(customer.totalSpent + orderAmount),
            lastVisit: Value(DateTime.now()),
          ),
        );
      });

      // NOTE: Customer stats sync handled by AutoSyncService schedule
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
        logDebug('⚠️ Not logged in, skipping unsynced orders sync');
        return 0;
      }

      // Get all unsynced orders
      final unsyncedQuery = _db.select(_db.orders)
        ..where((tbl) => tbl.isSynced.equals(false));

      final unsyncedOrders = await unsyncedQuery.get();

      if (unsyncedOrders.isEmpty) {
        return 0;
      }

      logDebug(
        '🔄 Retrying sync for ${unsyncedOrders.length} unsynced orders...',
      );

      int successCount = 0;
      for (var order in unsyncedOrders) {
        try {
          // Fetch order items to include in the document
          final orderItems = await getOrderItems(order.id);
          final itemsData = orderItems
              .map(
                (oi) => {
                  'id': oi.id,
                  'itemId': oi.itemId,
                  'itemName': oi.itemName,
                  'price': oi.price,
                  'quantity': oi.quantity,
                  'note': oi.note,
                  'discountAmount': oi.discountAmount,
                },
              )
              .toList();

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
            'items': itemsData,
          };

          // Push as individual document only (no legacy array)
          await FirebaseFirestore.instance
              .collection('cafes')
              .doc(user.uid)
              .collection('orders')
              .doc(order.id)
              .set(orderData, SetOptions(merge: true));

          // Mark as synced in local DB
          await (_db.update(_db.orders)..where((t) => t.id.equals(order.id)))
              .write(const OrdersCompanion(isSynced: Value(true)));

          successCount++;
          logDebug('✅ Synced order: ${order.invoiceNumber}');
        } catch (e) {
          logDebug('❌ Failed to sync order ${order.invoiceNumber}: $e');
          // Continue with next order
        }
      }

      logDebug(
        '✅ Successfully synced $successCount/${unsyncedOrders.length} orders',
      );
      return successCount;
    } catch (e) {
      logDebug('❌ Error in syncUnsyncedOrders: $e');
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
