import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';

// --- state ---
class CartItem {
  final String id; // temporary id for cart
  final Item item;
  final int quantity;
  final String? note;
  final double discountAmount;

  CartItem({
    required this.id,
    required this.item,
    this.quantity = 1,
    this.note,
    this.discountAmount = 0.0,
  });

  double get total => (item.price * quantity) - discountAmount;

  CartItem copyWith({int? quantity, String? note, double? discountAmount}) {
    return CartItem(
      id: id,
      item: item,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }
}

class CartState {
  final String? orderId; // If editing a pending/held order
  final List<CartItem> items;
  final Customer? customer;
  final String paymentMode; // 'Cash', 'UPI', 'Card', 'Split'
  final double paidCash;
  final double paidUPI;
  final double manualDiscount;
  final double promoDiscount;
  final bool canUndo;
  final bool canRedo;

  CartState({
    this.orderId,
    this.items = const [],
    this.customer,
    this.paymentMode = 'Cash',
    this.paidCash = 0.0,
    this.paidUPI = 0.0,
    this.manualDiscount = 0.0,
    this.promoDiscount = 0.0,
    this.canUndo = false,
    this.canRedo = false,
  });

  // Alias for backward compatibility with new reward code
  Customer? get selectedCustomer => customer;

  double get subtotal =>
      items.fold(0, (sum, item) => sum + (item.item.price * item.quantity));

  double get totalDiscount {
    double itemDiscounts = items.fold(
      0,
      (sum, item) => sum + item.discountAmount,
    );
    double afterItemDiscount = subtotal - itemDiscounts;
    double custDiscount = customer != null
        ? (afterItemDiscount * (customer!.discountPercent / 100))
        : 0.0;
    final rawDiscount =
        itemDiscounts + custDiscount + manualDiscount + promoDiscount;
    return rawDiscount.clamp(0.0, subtotal);
  }

  double get taxAmount {
    // Tax removed - using discount system instead
    return 0.0;
  }

  double get grandTotal =>
      (subtotal - totalDiscount).clamp(0.0, double.infinity);

  CartState copyWith({
    String? orderId,
    List<CartItem>? items,
    Customer? customer,
    String? paymentMode,
    double? paidCash,
    double? paidUPI,
    double? manualDiscount,
    double? promoDiscount,
    bool? canUndo,
    bool? canRedo,
  }) {
    return CartState(
      orderId: orderId ?? this.orderId,
      items: items ?? this.items,
      customer: customer ?? this.customer,
      paymentMode: paymentMode ?? this.paymentMode,
      paidCash: paidCash ?? this.paidCash,
      paidUPI: paidUPI ?? this.paidUPI,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      promoDiscount: promoDiscount ?? this.promoDiscount,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }
}

// --- notifier ---
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState()) {
    _pushState(state);
  }

  final List<CartState> _history = [];
  int _historyIndex = -1;

  void _pushState(CartState newState) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(newState.copyWith(canUndo: false, canRedo: false));
    _historyIndex = _history.length - 1;
    _applyState(newState, push: false);
  }

  void _applyState(CartState newState, {bool push = true}) {
    if (push) {
      _pushState(newState);
      return;
    }
    final canUndo = _historyIndex > 0;
    final canRedo = _historyIndex < _history.length - 1;
    state = newState.copyWith(canUndo: canUndo, canRedo: canRedo);
  }

  void undo() {
    if (_historyIndex <= 0) return;
    _historyIndex -= 1;
    _applyState(_history[_historyIndex], push: false);
  }

  void redo() {
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex += 1;
    _applyState(_history[_historyIndex], push: false);
  }

  void addItem(Item item) {
    // Check if exists
    final index = state.items.indexWhere(
      (i) => i.item.id == item.id && i.note == null,
    );

    // Calculate discount based on item discount percent
    final discountAmount = (item.price * item.discountPercent) / 100;

    if (index != -1) {
      // Update qty
      final old = state.items[index];
      final newItems = [...state.items];
      newItems[index] = old.copyWith(quantity: old.quantity + 1);
      _applyState(state.copyWith(items: newItems));
    } else {
      _applyState(
        state.copyWith(
          items: [
            ...state.items,
            CartItem(
              id: const Uuid().v4(),
              item: item,
              discountAmount: discountAmount,
            ),
          ],
        ),
      );
    }
  }

  void updateQuantity(String cartId, int qty) {
    if (qty <= 0) {
      removeItem(cartId);
      return;
    }
    _applyState(
      state.copyWith(
        items: state.items.map((i) {
          if (i.id == cartId) return i.copyWith(quantity: qty);
          return i;
        }).toList(),
      ),
    );
  }

  void removeItem(String cartId) {
    _applyState(
      state.copyWith(items: state.items.where((i) => i.id != cartId).toList()),
    );
  }

  // Remove item by ITEM ID (for toggle logic)
  void removeByItemId(String itemId) {
    _applyState(
      state.copyWith(
        items: state.items.where((i) => i.item.id != itemId).toList(),
      ),
    );
  }

  void updateNote(String cartId, String note) {
    _applyState(
      state.copyWith(
        items: state.items.map((i) {
          if (i.id == cartId) return i.copyWith(note: note);
          return i;
        }).toList(),
      ),
    );
  }

  void updateItemDiscount(String cartId, double discount) {
    _applyState(
      state.copyWith(
        items: state.items.map((i) {
          if (i.id == cartId) return i.copyWith(discountAmount: discount);
          return i;
        }).toList(),
      ),
    );
  }

  void setCustomer(Customer? customer) {
    _applyState(state.copyWith(customer: customer));
  }

  void setOrderId(String? orderId) {
    _applyState(state.copyWith(orderId: orderId));
  }

  void setPaymentMode(String mode) {
    _applyState(state.copyWith(paymentMode: mode));
  }

  void setPaymentSplit(double cash, double upi) {
    _applyState(
      state.copyWith(paymentMode: 'Split', paidCash: cash, paidUPI: upi),
    );
  }

  void setManualDiscount(double discount) {
    final itemDiscounts = state.items.fold(
      0.0,
      (sum, item) => sum + item.discountAmount,
    );
    final afterItemDiscount = state.subtotal - itemDiscounts;
    final custDiscount = state.customer != null
        ? (afterItemDiscount * (state.customer!.discountPercent / 100))
        : 0.0;
    final maxManual = math.max(
      0.0,
      state.subtotal - itemDiscounts - custDiscount - state.promoDiscount,
    );

    final nextManual = discount.clamp(0.0, maxManual);
    _applyState(state.copyWith(manualDiscount: nextManual));
  }

  void clearCart() {
    _applyState(CartState());
  }

  void loadOrder(
    Order order,
    List<({OrderItem orderItem, Item realItem})> details,
    Customer? customer,
  ) {
    _applyState(
      CartState(
        orderId: order.id,
        customer: customer,
        items: details
            .map(
              (d) => CartItem(
                id: const Uuid().v4(),
                item: d.realItem, // Uses real item with taxPercent
                quantity: d.orderItem.quantity,
                note: d.orderItem.note,
                discountAmount: d.orderItem.discountAmount,
              ),
            )
            .toList(),
      ),
    );
  }

  void applyManualDiscount(double discountAmount) {
    final itemDiscounts = state.items.fold(
      0.0,
      (sum, item) => sum + item.discountAmount,
    );
    final afterItemDiscount = state.subtotal - itemDiscounts;
    final custDiscount = state.customer != null
        ? (afterItemDiscount * (state.customer!.discountPercent / 100))
        : 0.0;
    final maxManual = math.max(
      0.0,
      state.subtotal - itemDiscounts - custDiscount - state.promoDiscount,
    );

    final nextManual = (state.manualDiscount + discountAmount).clamp(
      0.0,
      maxManual,
    );
    _applyState(state.copyWith(manualDiscount: nextManual));
  }

  void setPromoDiscount(double discount) {
    final nextPromo = discount.clamp(0.0, state.subtotal);
    if (nextPromo == state.promoDiscount) return;
    _applyState(state.copyWith(promoDiscount: nextPromo));
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
