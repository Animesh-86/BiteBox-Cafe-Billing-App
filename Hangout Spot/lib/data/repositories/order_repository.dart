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
import 'package:hangout_spot/utils/constants/app_keys.dart';

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

  /// Title-cases a string (e.g. "GRILLED SANDWICH" → "Grilled Sandwich").
  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Returns item name with category suffix when the name alone is ambiguous.
  static String _itemDisplayName(String itemName, String categoryName) {
    if (categoryName.isEmpty) return itemName;
    final nameL = itemName.toLowerCase();
    final catWords = categoryName.toLowerCase().split(RegExp(r'[\s&]+'));
    final found = catWords
        .where((w) => w.length > 2)
        .any((w) => nameL.contains(w));
    if (found) return itemName;
    return '$itemName ${_titleCase(categoryName)}';
  }

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
        // BUG-14/26/37: Use RTDB atomic counter for collision-free multi-device
        // invoice generation. Falls back to local SQLite count when offline.
        invoiceNum = await _getNextCompletedInvoice(sessionManager);
      }
    } else if (status == 'completed' && invoiceNum.startsWith('HOLD-')) {
      // Converting a HOLD order to COMPLETED — assign a real sequential number.
      // BUG-14/26/37: Same atomic RTDB counter used here.
      invoiceNum = await _getNextCompletedInvoice(sessionManager);
    }

    // Get active outlet (required for order creation)
    // Use raw SQL to avoid RangeError if created_at has corrupted timestamps.
    String? activeOutletId;
    try {
      final activeOutlet = await (_db.select(
        _db.locations,
      )..where((t) => t.isActive.equals(true))).getSingleOrNull();
      activeOutletId = activeOutlet?.id;
    } catch (e) {
      // Fallback: raw SQL fetching only the id column
      logDebug('⚠️ Location query failed, using raw SQL fallback: $e');
      final rows = await _db
          .customSelect('SELECT id FROM locations WHERE is_active = 1 LIMIT 1')
          .get();
      if (rows.isNotEmpty) {
        activeOutletId = rows.first.read<String>('id');
      }
    }

    if (activeOutletId == null) {
      throw Exception(
        'No active outlet found. Please activate an outlet in Settings before creating orders.',
      );
    }

    // Look up category names so stored item names include category context
    // Fetch ALL categories for robust lookup (avoids isIn query edge-cases)
    final allCategories = await _db.select(_db.categories).get();
    final catMap = {for (final c in allCategories) c.id: c.name};

    await _db.transaction(() async {
      if (cart.orderId != null) {
        // Updating an existing pending order: delete its items, then update the
        // order row in-place. Using update() instead of INSERT OR REPLACE avoids
        // the SQLite behaviour where a UNIQUE-constraint conflict on invoiceNumber
        // would silently delete a *different* completed order that already holds the
        // same invoice number (BUG-data-integrity fix).
        await (_db.delete(
          _db.orderItems,
        )..where((t) => t.orderId.equals(cart.orderId!))).go();

        await (_db.update(
          _db.orders,
        )..where((t) => t.id.equals(cart.orderId!))).write(
          OrdersCompanion(
            invoiceNumber: Value(invoiceNum!),
            customerId: Value(platformCustomerId),
            locationId: Value(activeOutletId),
            subtotal: Value(cart.subtotal),
            discountAmount: Value(cart.totalDiscount),
            taxAmount: Value(cart.taxAmount),
            totalAmount: Value(cart.grandTotal),
            paymentMode: Value(cart.paymentMode),
            paidCash: Value(cart.paidCash),
            paidUPI: Value(cart.paidUPI),
            status: Value(status),
            isSynced: const Value(false),
          ),
        );
      } else {
        // New order: insertOrIgnore so a duplicate invoice number (possible in
        // offline multi-device scenarios) never silently deletes an existing order.
        await _db
            .into(_db.orders)
            .insert(
              OrdersCompanion(
                id: Value(orderId),
                invoiceNumber: Value(invoiceNum!),
                customerId: Value(platformCustomerId),
                locationId: Value(activeOutletId),
                subtotal: Value(cart.subtotal),
                discountAmount: Value(cart.totalDiscount),
                taxAmount: Value(cart.taxAmount),
                totalAmount: Value(cart.grandTotal),
                paymentMode: Value(cart.paymentMode),
                paidCash: Value(cart.paidCash),
                paidUPI: Value(cart.paidUPI),
                status: Value(status),
                createdAt: Value(DateTime.now()),
                isSynced: const Value(false),
              ),
              mode: InsertMode.insertOrIgnore,
            );

        // BUG-1 fix: if the row was silently dropped (invoice collision),
        // don't insert orphaned order items — throw so the caller sees the error.
        final inserted = await (_db.select(
          _db.orders,
        )..where((t) => t.id.equals(orderId))).getSingleOrNull();
        if (inserted == null) {
          throw StateError(
            'Invoice collision: order $orderId was not written '
            '(invoiceNumber $invoiceNum already exists). '
            'Retry to get a fresh invoice number.',
          );
        }
      }

      for (final ci in cart.items) {
        await _db
            .into(_db.orderItems)
            .insert(
              OrderItemsCompanion(
                id: Value(const Uuid().v4()),
                orderId: Value(orderId),
                itemId: Value(ci.item.id),
                itemName: Value(
                  _itemDisplayName(
                    ci.item.name,
                    catMap[ci.item.categoryId] ?? '',
                  ),
                ),
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
      activeOutletId,
      status,
    ).ignore();

    // Record to live analytics and kitchen display (only for completed orders)
    if (status == 'completed') {
      _decrementInventoryForCart(cart).ignore();
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
    SessionManager? sessionManager,
  }) async {
    int totalItems = 0;

    // BUG-5 fix: if the order still carries a HOLD invoice number, assign a
    // real sequential invoice before marking it completed.
    final existingOrder = await (_db.select(
      _db.orders,
    )..where((t) => t.id.equals(orderId))).getSingleOrNull();
    final String? newInvoiceNumber =
        (existingOrder != null &&
            existingOrder.invoiceNumber.startsWith('HOLD-'))
        ? await _getNextCompletedInvoice(sessionManager)
        : null;

    await _db.transaction(() async {
      final order = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingleOrNull();

      if (order == null) return;

      // Get order items to count total quantity
      final items = await (_db.select(
        _db.orderItems,
      )..where((t) => t.orderId.equals(orderId))).get();

      totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);

      final companion = newInvoiceNumber != null
          ? OrdersCompanion(
              invoiceNumber: Value(newInvoiceNumber),
              status: const Value('completed'),
              paymentMode: Value(paymentMode),
              isSynced: const Value(false),
            )
          : OrdersCompanion(
              status: const Value('completed'),
              paymentMode: Value(paymentMode),
              isSynced: const Value(false),
            );

      await (_db.update(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).write(companion);
      // recordSale is called AFTER the transaction with the updated order
      // to ensure it uses the correct paymentMode. (BUG-10)
    });

    // Re-read the order AFTER the write so recordSale gets the correct paymentMode
    if (_liveAnalytics != null) {
      final updatedOrder = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(orderId))).getSingleOrNull();
      if (updatedOrder != null) {
        await _liveAnalytics.recordSale(updatedOrder, itemCount: totalItems);
        logDebug(
          '✅ Recorded to Live Analytics: ${updatedOrder.invoiceNumber} (Items: $totalItems)',
        );
      }
    }

    // Push the payment update to Firestore immediately
    _tryPushOrderUpdate(orderId).ignore();
  }

  /// Returns the next invoice number for a completed order.
  /// Prefers the RTDB atomic counter (collision-free on multi-device) and
  /// falls back to the local SQLite-based sequential count when offline.
  Future<String> _getNextCompletedInvoice(
    SessionManager? sessionManager,
  ) async {
    if (_liveInvoiceCounter != null && sessionManager != null) {
      try {
        final sessionId = sessionManager.getCurrentSessionId();
        // BUG-FIX: Firebase RTDB runTransaction can hang forever when the
        // connection is forcefully killed. Add a timeout so we fall back to
        // the local SQLite counter instead of freezing the entire checkout.
        return await _liveInvoiceCounter
            .getNextInvoiceNumber(sessionId: sessionId, prefix: '#')
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        logDebug('⚠️ RTDB invoice counter failed, falling back to local: $e');
      }
    }
    if (sessionManager != null) {
      return await sessionManager.getNextInvoiceNumber();
    }
    // Last-resort fallback: non-sequential but unique.
    return "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-${const Uuid().v4().substring(0, 4)}";
  }

  Future<void> _decrementInventoryForCart(CartState cart) async {
    final repo = _inventoryRepo;
    if (repo == null) return;
    
    for (final ci in cart.items) {
      if (ci.quantity <= 0) continue;
      
      try {
        final originalName = ci.item.name;
        
        // Strategy 1: Attempt exact name match
        final exactItem = await repo.findItemByName(originalName);
        if (exactItem != null) {
          await repo.adjustStockTransaction(
            itemId: exactItem.id,
            delta: -ci.quantity.toDouble(),
            reason: 'order_sale',
          );
          continue;
        }

        // Strategy 2: Attempt title-case fallback
        final tcName = _titleCase(originalName);
        if (tcName != originalName) {
          final tcItem = await repo.findItemByName(tcName);
          if (tcItem != null) {
            await repo.adjustStockTransaction(
              itemId: tcItem.id,
              delta: -ci.quantity.toDouble(),
              reason: 'order_sale',
            );
            continue;
          }
        }
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
    void Function()? onCancelled,
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
    // Notify UI/dashboard immediately
    if (onCancelled != null) {
      onCancelled();
    }

    // Attempt immediate push of cancellation outside of database transaction
    // to prevent Firebase Realtime Database thread locks from hanging SQLite.
    try {
      // Revert customer stats and reward points for completed orders only.
      // Pending/held orders were never committed so no stats to revert.
      if (order != null && order.status == 'completed') {
        // Revert live analytics (only for completed orders that were recorded)
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _liveAnalytics?.revertSale(order, itemCount: itemCount);
        }

        if (customerRepo != null && order.customerId != null) {
          await customerRepo.revertVisitStats(
            order.customerId!,
            order.totalAmount,
            syncRepo: syncRepo,
          );
        }

        // Delete the 'earn' reward transaction for this order so the
        // customer's earned balance is reverted.
        await (_db.delete(_db.rewardTransactions)
              ..where((t) => t.orderId.equals(orderId) & t.type.equals('earn')))
            .go();

        // Delete the 'redeem' reward transaction for this order so any
        // points the customer redeemed at checkout are refunded. (BUG-29)
        await (_db.delete(_db.rewardTransactions)..where(
              (t) => t.orderId.equals(orderId) & t.type.equals('redeem'),
            ))
            .go();

        // Restock inventory for any beverage items on the order. (BUG-11)
        await revertOrderItems(orderId);
      }
    } catch (e) {
      logDebug('Failed to push live order cancellation bounds: $e');
    }

    // Push the cancellation to Firestore immediately
    _tryPushOrderUpdate(orderId).ignore();
  }

  Future<void> revertOrderItems(String orderId) async {
    final repo = _inventoryRepo;
    if (repo == null) return;

    const allowedNames = {
      'coca cola',
      'sprite',
      'fanta',
      'thumbs up',
      'water bottle (small)',
      'water bottle (large)',
    };

    final orderItems = await getOrderItems(orderId);

    for (final oi in orderItems) {
      if (oi.quantity <= 0) continue;

      // Prefer original item name from menu over display name (which may have
      // category suffix). This ensures proper matching in Firestore inventory.
      final menuItem = await (_db.select(
        _db.items,
      )..where((t) => t.id.equals(oi.itemId))).getSingleOrNull();
      final originalName = menuItem?.name ?? oi.itemName;

      if (!allowedNames.contains(originalName.toLowerCase())) continue;

      try {
        await repo.adjustStockByName(
          // BUG-13: normalise to Title-Case to match what Firestore stores.
          name: _titleCase(originalName),
          delta: oi.quantity.toDouble(), // positive = restock
          reason: 'order_cancel',
        );
      } catch (e) {
        logDebug('⚠️ Inventory revert skipped for $originalName: $e');
      }
    }
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
        customerId == CustomerDefaults.walkInId ||
        customerId == CustomerDefaults.zomatoId ||
        customerId == CustomerDefaults.swiggyId) {
      return; // No reward for platform/anonymous customers
    }

    // Check if reward system is enabled by querying settings
    final settings =
        await (_db.select(_db.settings)
              ..where((tbl) => tbl.key.equals(REWARD_FEATURE_TOGGLE_KEY)))
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
    if (customerId == CustomerDefaults.walkInId ||
        customerId == CustomerDefaults.zomatoId ||
        customerId == CustomerDefaults.swiggyId)
      return; // No stats for platform/anonymous customers

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

      syncRepo
          ?.syncCustomersNow(); // immediately propagate stats to other devices
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
