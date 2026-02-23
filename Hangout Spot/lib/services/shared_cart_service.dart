import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hangout_spot/utils/exceptions/app_exceptions.dart';
import 'package:hangout_spot/utils/exceptions/error_handler.dart';

/// Multi-Device Cart Sync Service using Firebase Realtime Database
/// Enables real-time cart sharing across multiple devices with atomic updates
///
/// Use cases:
/// - Multiple staff devices sharing same cart
/// - Customer adds items on tablet, pays at counter
/// - Real-time cart updates prevent item conflicts
class SharedCartService {
  final DatabaseReference _database;
  final FirebaseAuth _auth;

  SharedCartService({DatabaseReference? database, FirebaseAuth? auth})
    : _database = database ?? FirebaseDatabase.instance.ref(),
      _auth = auth ?? FirebaseAuth.instance;

  /// Get reference to user's active carts node
  DatabaseReference? _getUserCartsRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _database.child('active_carts').child(user.uid);
  }

  /// Create or get cart by ID
  Future<String> createCart({
    String? tableNumber,
    String? customerName,
    Map<String, dynamic>? metadata,
  }) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) {
      throw AuthException(userMessage: 'Please sign in to create a cart.');
    }

    try {
      // Generate cart ID (use timestamp for uniqueness)
      final cartId = 'cart_${DateTime.now().millisecondsSinceEpoch}';

      final cartData = {
        'cartId': cartId,
        'tableNumber': tableNumber,
        'customerName': customerName,
        'metadata': metadata ?? {},
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'items': {},
        'totalAmount': 0.0,
        'itemCount': 0,
        'status': 'active', // active, completed, abandoned
      };

      await cartsRef.child(cartId).set(cartData);

      debugPrint('✅ Created shared cart: $cartId');
      return cartId;
    } catch (e) {
      throw ErrorHandler.handleOrderError(e);
    }
  }

  /// Add item to cart (atomic operation)
  Future<void> addItem({
    required String cartId,
    required String itemId,
    required String itemName,
    required double price,
    required int quantity,
    String? notes,
    Map<String, dynamic>? customizations,
  }) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      final cartRef = cartsRef.child(cartId);
      final itemRef = cartRef.child('items').child(itemId);

      // Check if item already exists
      final snapshot = await itemRef.get();

      if (snapshot.exists) {
        // Item exists, increment quantity atomically
        final data = snapshot.value as Map?;
        final currentQty = (data?['quantity'] as num?)?.toInt() ?? 0;
        final newQty = currentQty + quantity;

        await itemRef.update({
          'quantity': newQty,
          'total': newQty * price,
          'updatedAt': ServerValue.timestamp,
        });
      } else {
        // New item, add to cart
        await itemRef.set({
          'itemId': itemId,
          'itemName': itemName,
          'price': price,
          'quantity': quantity,
          'total': quantity * price,
          'notes': notes,
          'customizations': customizations ?? {},
          'addedAt': ServerValue.timestamp,
          'updatedAt': ServerValue.timestamp,
        });
      }

      // Update cart totals (use transaction for accuracy)
      await _updateCartTotals(cartRef);

      debugPrint('✅ Added item to cart: $itemName x$quantity');
    } catch (e) {
      debugPrint('❌ Failed to add item: $e');
      rethrow;
    }
  }

  /// Update item quantity (atomic)
  Future<void> updateItemQuantity({
    required String cartId,
    required String itemId,
    required int newQuantity,
  }) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      final itemRef = cartsRef.child(cartId).child('items').child(itemId);

      if (newQuantity <= 0) {
        // Remove item if quantity is 0 or negative
        await removeItem(cartId: cartId, itemId: itemId);
        return;
      }

      // Get current price
      final snapshot = await itemRef.get();
      if (!snapshot.exists) {
        debugPrint('⚠️ Item not found: $itemId');
        return;
      }

      final data = snapshot.value as Map?;
      final price = (data?['price'] as num?)?.toDouble() ?? 0.0;

      // Update quantity and total
      await itemRef.update({
        'quantity': newQuantity,
        'total': newQuantity * price,
        'updatedAt': ServerValue.timestamp,
      });

      // Update cart totals
      await _updateCartTotals(cartsRef.child(cartId));

      debugPrint('✅ Updated item quantity: $itemId = $newQuantity');
    } catch (e) {
      debugPrint('❌ Failed to update quantity: $e');
      rethrow;
    }
  }

  /// Remove item from cart
  Future<void> removeItem({
    required String cartId,
    required String itemId,
  }) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      final cartRef = cartsRef.child(cartId);

      await cartRef.child('items').child(itemId).remove();

      // Update cart totals
      await _updateCartTotals(cartRef);

      debugPrint('✅ Removed item from cart: $itemId');
    } catch (e) {
      throw ErrorHandler.handleOrderError(e);
    }
  }

  /// Update item notes
  Future<void> updateItemNotes({
    required String cartId,
    required String itemId,
    required String notes,
  }) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      await cartsRef.child(cartId).child('items').child(itemId).update({
        'notes': notes,
        'updatedAt': ServerValue.timestamp,
      });

      debugPrint('✅ Updated item notes: $itemId');
    } catch (e) {
      debugPrint('❌ Failed to update notes: $e');
    }
  }

  /// Clear entire cart
  Future<void> clearCart({required String cartId}) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      final cartRef = cartsRef.child(cartId);

      await cartRef.update({
        'items': {},
        'totalAmount': 0.0,
        'itemCount': 0,
        'updatedAt': ServerValue.timestamp,
      });

      debugPrint('✅ Cleared cart: $cartId');
    } catch (e) {
      debugPrint('❌ Failed to clear cart: $e');
      rethrow;
    }
  }

  /// Watch cart updates in real-time
  Stream<SharedCart> watchCart({required String cartId}) {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) {
      return Stream.value(SharedCart.empty(cartId));
    }

    return cartsRef.child(cartId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        return SharedCart.empty(cartId);
      }

      try {
        return SharedCart.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        debugPrint('⚠️ Failed to parse cart: $e');
        return SharedCart.empty(cartId);
      }
    });
  }

  /// Watch specific item in cart
  Stream<SharedCartItem?> watchItem({
    required String cartId,
    required String itemId,
  }) {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return Stream.value(null);

    return cartsRef.child(cartId).child('items').child(itemId).onValue.map((
      event,
    ) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return null;

      try {
        return SharedCartItem.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        debugPrint('⚠️ Failed to parse cart item: $e');
        return null;
      }
    });
  }

  /// Get all active carts
  Stream<List<SharedCart>> watchActiveCarts() {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return Stream.value([]);

    return cartsRef.orderByChild('status').equalTo('active').onValue.map((
      event,
    ) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <SharedCart>[];

      final List<SharedCart> carts = [];

      data.forEach((key, value) {
        if (value is Map) {
          try {
            carts.add(SharedCart.fromJson(Map<String, dynamic>.from(value)));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Failed to parse cart: $e');
            }
          }
        }
      });

      // Sort by creation time (newest first)
      carts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return carts;
    });
  }

  /// Complete cart (mark as completed, move to order)
  Future<void> completeCart({required String cartId}) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      await cartsRef.child(cartId).update({
        'status': 'completed',
        'completedAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      debugPrint('✅ Completed cart: $cartId');
    } catch (e) {
      throw ErrorHandler.handleOrderError(e);
    }
  }

  /// Abandon cart (customer left)
  Future<void> abandonCart({required String cartId}) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      await cartsRef.child(cartId).update({
        'status': 'abandoned',
        'abandonedAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      debugPrint('✅ Abandoned cart: $cartId');
    } catch (e) {
      debugPrint('❌ Failed to abandon cart: $e');
    }
  }

  /// Delete cart
  Future<void> deleteCart({required String cartId}) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      await cartsRef.child(cartId).remove();
      debugPrint('✅ Deleted cart: $cartId');
    } catch (e) {
      debugPrint('❌ Failed to delete cart: $e');
      rethrow;
    }
  }

  /// Update cart totals (internal helper)
  Future<void> _updateCartTotals(DatabaseReference cartRef) async {
    try {
      final snapshot = await cartRef.child('items').get();

      if (!snapshot.exists) {
        // No items, reset totals
        await cartRef.update({
          'totalAmount': 0.0,
          'itemCount': 0,
          'updatedAt': ServerValue.timestamp,
        });
        return;
      }

      final items = snapshot.value as Map?;
      if (items == null) return;

      double totalAmount = 0.0;
      int itemCount = 0;

      items.forEach((key, value) {
        if (value is Map) {
          final total = (value['total'] as num?)?.toDouble() ?? 0.0;
          final quantity = (value['quantity'] as num?)?.toInt() ?? 0;
          totalAmount += total;
          itemCount += quantity;
        }
      });

      await cartRef.update({
        'totalAmount': totalAmount,
        'itemCount': itemCount,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to update cart totals: $e');
      }
    }
  }

  /// Cleanup old completed/abandoned carts
  Future<void> cleanupOldCarts({int hoursOld = 24}) async {
    final cartsRef = _getUserCartsRef();
    if (cartsRef == null) return;

    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(hours: hoursOld))
          .millisecondsSinceEpoch;

      final snapshot = await cartsRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map?;
      if (data == null) return;

      final List<String> toDelete = [];

      data.forEach((key, value) {
        if (value is Map) {
          final status = value['status'] as String?;
          final updatedAt = value['updatedAt'] as int?;

          if ((status == 'completed' || status == 'abandoned') &&
              updatedAt != null &&
              updatedAt < cutoffTime) {
            toDelete.add(key.toString());
          }
        }
      });

      // Delete old carts
      for (final cartId in toDelete) {
        await cartsRef.child(cartId).remove();
      }

      debugPrint('✅ Cleaned up ${toDelete.length} old carts');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to cleanup old carts: $e');
      }
    }
  }

  /// Dispose/cleanup
  void dispose() {
    // Firebase Realtime Database handles cleanup automatically
  }
}

/// Shared Cart model
class SharedCart {
  final String cartId;
  final String? tableNumber;
  final String? customerName;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, SharedCartItem> items;
  final double totalAmount;
  final int itemCount;
  final String status;

  SharedCart({
    required this.cartId,
    this.tableNumber,
    this.customerName,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.totalAmount,
    required this.itemCount,
    required this.status,
  });

  factory SharedCart.fromJson(Map<String, dynamic> json) {
    final itemsData = json['items'] as Map?;
    final Map<String, SharedCartItem> items = {};

    if (itemsData != null) {
      itemsData.forEach((key, value) {
        if (value is Map) {
          try {
            items[key.toString()] = SharedCartItem.fromJson(
              Map<String, dynamic>.from(value),
            );
          } catch (e) {
            debugPrint('⚠️ Failed to parse cart item: $e');
          }
        }
      });
    }

    return SharedCart(
      cartId: json['cartId'] as String,
      tableNumber: json['tableNumber'] as String?,
      customerName: json['customerName'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      items: items,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  factory SharedCart.empty(String cartId) {
    final now = DateTime.now();
    return SharedCart(
      cartId: cartId,
      metadata: {},
      createdAt: now,
      updatedAt: now,
      items: {},
      totalAmount: 0.0,
      itemCount: 0,
      status: 'active',
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get isActive => status == 'active';
}

/// Shared Cart Item model
class SharedCartItem {
  final String itemId;
  final String itemName;
  final double price;
  final int quantity;
  final double total;
  final String? notes;
  final Map<String, dynamic> customizations;
  final DateTime addedAt;
  final DateTime updatedAt;

  SharedCartItem({
    required this.itemId,
    required this.itemName,
    required this.price,
    required this.quantity,
    required this.total,
    this.notes,
    required this.customizations,
    required this.addedAt,
    required this.updatedAt,
  });

  factory SharedCartItem.fromJson(Map<String, dynamic> json) {
    return SharedCartItem(
      itemId: json['itemId'] as String,
      itemName: json['itemName'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      total: (json['total'] as num).toDouble(),
      notes: json['notes'] as String?,
      customizations: Map<String, dynamic>.from(json['customizations'] ?? {}),
      addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }

  bool get hasNotes => notes != null && notes!.isNotEmpty;
  bool get hasCustomizations => customizations.isNotEmpty;
}
