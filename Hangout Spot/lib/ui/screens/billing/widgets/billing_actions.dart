import 'package:hangout_spot/utils/log_utils.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/services/printing_service.dart';
import 'package:hangout_spot/services/share_service.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:hangout_spot/ui/screens/customer/customer_list_screen.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_shared_widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
import 'package:hangout_spot/data/providers/realtime_services_provider.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';

import 'package:hangout_spot/services/thermal_printing_service.dart';

/// Prevents concurrent checkout / hold calls (double-tap guard).
/// Plain top-level bool so it never depends on a WidgetRef that might be
/// disposed before the finally-block can reset it.
bool _checkoutInProgress = false;

Future<bool> _isBillWhatsAppEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(BILL_WHATSAPP_ENABLED_KEY) ?? true;
}

/// Title-cases a string (e.g. "GRILLED SANDWICH" → "Grilled Sandwich").
String _titleCase(String s) {
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

/// Returns a display name for the item that includes category context
/// when the item name alone would be ambiguous (e.g. "Veg Cheese" → "Veg Cheese Grilled Sandwich").
String _displayName(String itemName, String categoryName) {
  if (categoryName.isEmpty) return itemName;
  final nameL = itemName.toLowerCase();
  // Check if any significant word from the category is already in the item name
  final catWords = categoryName.toLowerCase().split(RegExp(r'[\s&]+'));
  final found = catWords
      .where((w) => w.length > 2)
      .any((w) => nameL.contains(w));
  if (found) return itemName;
  return '$itemName ${_titleCase(categoryName)}';
}

Future<void> printKot(BuildContext context, WidgetRef ref) async {
  final cart = ref.read(cartProvider);
  if (cart.items.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
    }
    return;
  }

  // Capture context-dependent values BEFORE any async work
  final messenger = ScaffoldMessenger.of(context);
  final screenWidth = MediaQuery.of(context).size.width;
  final navState = Navigator.of(context);

  try {
    final sessionManager = ref.read(sessionManagerProvider);
    final invoiceNumber = await sessionManager.peekNextInvoiceNumber();
    final orderId = cart.orderId ?? const Uuid().v4();

    final order = Order(
      id: orderId,
      invoiceNumber: invoiceNumber,
      customerId: cart.customer?.id,
      subtotal: cart.subtotal,
      discountAmount: cart.totalDiscount,
      taxAmount: cart.taxAmount,
      totalAmount: cart.grandTotal,
      paidCash: cart.paidCash,
      paidUPI: cart.paidUPI,
      paymentMode: cart.paymentMode,
      status: 'pending',
      createdAt: DateTime.now(),
      isSynced: false,
    );

    // Look up category names so KOT prints clear item names
    final db = ref.read(appDatabaseProvider);
    final allCategories = await db.select(db.categories).get();
    final catMap = {for (final c in allCategories) c.id: c.name};
    logDebug('[KOT] Found ${allCategories.length} categories');

    // Build itemId → category name map for the thermal printer
    final itemCategoryMap = <String, String>{};
    for (final ci in cart.items) {
      final catName = catMap[ci.item.categoryId] ?? '';
      itemCategoryMap[ci.item.id] = _titleCase(catName);
      logDebug(
        '[KOT] Item "${ci.item.name}" catId=${ci.item.categoryId} catName="$catName"',
      );
    }

    final items = cart.items.map((ci) {
      final displayName = _displayName(
        ci.item.name,
        catMap[ci.item.categoryId] ?? '',
      );
      logDebug('[KOT] Final print name: "$displayName"');
      return OrderItem(
        id: const Uuid().v4(),
        orderId: orderId,
        itemId: ci.item.id,
        itemName: displayName,
        price: ci.item.price,
        quantity: ci.quantity,
        discountAmount: ci.discountAmount,
        note: ci.note,
      );
    }).toList();

    // Capture provider refs BEFORE popping (WidgetRef dies after pop)
    final thermalPrinter = ref.read(thermalPrintingServiceProvider);
    // Query active outlet directly — avoids StreamProvider hang
    Location? activeOutlet;
    try {
      activeOutlet = await (db.select(
        db.locations,
      )..where((t) => t.isActive.equals(true))).getSingleOrNull();
    } catch (e) {
      logDebug('[KOT] Active outlet lookup failed (non-fatal): $e');
    }

    // Close the Cart modal if on a mobile view BEFORE printing blocks
    messenger.showSnackBar(
      const SnackBar(
        content: Text("KOT sent to printer"),
        duration: Duration(milliseconds: 1500),
      ),
    );

    if (screenWidth <= 900 && navState.canPop()) {
      // Force modal close instantly using rootNavigator
      Navigator.of(context, rootNavigator: true).pop();
    }

    // Show loading dialog immediately after closing cart
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // Run print operation asynchronously
    Future<void> doPrint() async {
      try {
        await thermalPrinter.printKot(
          order,
          items,
          storeName: activeOutlet?.name,
          storeAddress: activeOutlet?.address,
          itemCategories: itemCategoryMap,
        );
      } catch (e) {
        logDebug("Thermal KOT print failed: $e");
      } finally {
        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
        }
      }
    }

    // Start print operation
    doPrint();
  } catch (e) {
    logDebug("KOT print failed: $e");
    try {
      messenger.showSnackBar(SnackBar(content: Text("Print failed: $e")));
    } catch (_) {}
  }
}

Future<void> holdOrder(BuildContext context, WidgetRef ref) async {
  // Guard against double-tap / concurrent calls (same flag as checkout)
  if (_checkoutInProgress) return;
  _checkoutInProgress = true;

  final cart = ref.read(cartProvider);
  if (cart.items.isEmpty) {
    _checkoutInProgress = false;
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
    }
    return;
  }

  // Capture context-dependent values BEFORE any async work
  final messenger = ScaffoldMessenger.of(context);
  final screenWidth = MediaQuery.of(context).size.width;
  final navState = Navigator.of(context);

  try {
    final sessionManager = ref.read(sessionManagerProvider);

    // ── INSTANT UI DISMISSAL ──
    if (screenWidth <= 900 && navState.canPop()) {
      navState.pop();
    }
    ref.read(cartProvider.notifier).clearCart();
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Holding order..."),
        duration: Duration(milliseconds: 1000),
      ),
    );

    // ── BACKGROUND SAVE ──
    await ref
        .read(orderRepositoryProvider)
        .createOrderFromCart(
          cart,
          status: 'pending',
          sessionManager: sessionManager,
        );

    messenger.showSnackBar(
      const SnackBar(
        content: Text("Order held!"),
        duration: Duration(milliseconds: 1500),
      ),
    );
  } catch (e) {
    logDebug("Hold order error: $e");
    // Restore cart if background hold fails
    try {
      ref.read(cartProvider.notifier).restoreCart(cart);
      logDebug("Cart restored after failed hold.");
    } catch (_) {}

    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Failed to hold — Cart restored. Error: $e"),
        ),
      );
    } catch (_) {}
  } finally {
    try {
      _checkoutInProgress = false;
    } catch (_) {}
  }
}

Future<void> checkout(BuildContext context, WidgetRef ref) async {
  // Guard against double-tap / concurrent calls
  if (_checkoutInProgress) {
    logDebug('[BILL] Checkout blocked: already in progress');
    return;
  }
  _checkoutInProgress = true;
  logDebug('[BILL] Checkout started');

  final cart = ref.read(cartProvider);
  if (cart.items.isEmpty) {
    _checkoutInProgress = false; // BUG-20
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
    }
    return;
  }

  // Robustness Check: Validate Split Payment Totals
  if (cart.paymentMode == 'Split') {
    final totalPaid = cart.paidCash + cart.paidUPI;
    // Allow small rounding difference (0.5)
    if ((totalPaid - cart.grandTotal).abs() > 0.5) {
      _checkoutInProgress = false; // BUG-30
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Payment mismatch! Paid: ₹${totalPaid.toStringAsFixed(2)}, Bill: ₹${cart.grandTotal.toStringAsFixed(2)}",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // Stop checkout
    }
  }

  // Capture context-dependent values BEFORE any async work.
  // After Navigator.pop the BuildContext is deactivated and lookups crash.
  final messenger = ScaffoldMessenger.of(context);
  final screenWidth = MediaQuery.of(context).size.width;
  final navState = Navigator.of(context);

  try {
    // ── Capture ALL provider references BEFORE clearing cart / popping ──
    // After Navigator.pop the WidgetRef is disposed and ref.read() will throw.
    final customer = cart.selectedCustomer;
    final sessionManager = ref.read(sessionManagerProvider);
    final grandTotal = cart.grandTotal;
    final customerId = customer?.id;
    final orderRepo = ref.read(orderRepositoryProvider);
    final syncRepo = ref.read(syncRepositoryProvider);
    final db = ref.read(appDatabaseProvider);
    final thermalPrinter = ref.read(thermalPrintingServiceProvider);
    final shareService = ref.read(shareServiceProvider);
    // Capture sync notifier BEFORE pop (WidgetRef dies after Navigator.pop)
    final syncNotifier = ref.read(remoteSyncGenerationProvider.notifier);
    // Capture reward redemption info before cart is cleared
    final rewardPointsRedeemed = cart.rewardPointsRedeemed;
    final rewardNotifier = ref.read(rewardNotifierProvider.notifier);
    // Pre-fetch reward balance if customer selected.
    Future<double?>? rewardBalanceFuture;
    if (customer != null) {
      rewardBalanceFuture = ref
          .read(customerRewardBalanceProvider(customer.id).future)
          .then<double?>((v) => v)
          .catchError((_) => null as double?)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    }

    // ── INSTANT UI DISMISSAL ──
    // Pop the modal BEFORE clearing the cart and BEFORE awaiting anything.
    if (screenWidth <= 900 && navState.canPop()) {
      navState.pop();
    }
    ref.read(cartProvider.notifier).clearCart();
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Processing order..."),
        duration: Duration(milliseconds: 1000),
      ),
    );

    // ── EVERYTHING BELOW RUNS IN BACKGROUND ──
    
    // Query active outlet directly — avoids StreamProvider which can hang
    Location? activeOutlet;
    try {
      activeOutlet = await (db.select(
        db.locations,
      )..where((t) => t.isActive.equals(true))).getSingleOrNull();
    } catch (e) {
      logDebug('[BILL] Active outlet lookup failed (non-fatal): $e');
    }

    // Look up category names so bill prints clear item names
    final allCategories = await db.select(db.categories).get();
    final catMap = {for (final c in allCategories) c.id: c.name};

    // Resolve reward balance BEFORE the DB write
    final rewardBalance = rewardBalanceFuture != null ? await rewardBalanceFuture : null;

    // ── DB WRITE ──
    final orderId = await orderRepo.createOrderFromCart(
      cart,
      status: 'completed',
      sessionManager: sessionManager,
    );

    // Bump sync generation so dashboard live stats re-query local DB
    try {
      syncNotifier.state++;
    } catch (_) {}

    // Build Order from in-memory cart data + fast PK lookup for invoice number
    final dbOrder = await (db.select(
      db.orders,
    )..where((t) => t.id.equals(orderId))).getSingleOrNull();
    final order = Order(
      id: orderId,
      invoiceNumber: dbOrder?.invoiceNumber ?? orderId,
      customerId: customer?.id,
      locationId: activeOutlet?.id,
      subtotal: cart.subtotal,
      discountAmount: cart.totalDiscount,
      taxAmount: cart.taxAmount,
      totalAmount: cart.grandTotal,
      paymentMode: cart.paymentMode,
      paidCash: cart.paidCash,
      paidUPI: cart.paidUPI,
      status: 'completed',
      createdAt: dbOrder?.createdAt ?? DateTime.now(),
      isSynced: false,
    );

    final items = cart.items
        .map(
          (ci) => OrderItem(
            id: const Uuid().v4(),
            orderId: orderId,
            itemId: ci.item.id,
            itemName: _displayName(
              ci.item.name,
              catMap[ci.item.categoryId] ?? '',
            ),
            price: ci.item.price,
            quantity: ci.quantity,
            discountAmount: ci.discountAmount,
            note: ci.note,
          ),
        )
        .toList();

    messenger.showSnackBar(
      const SnackBar(
        content: Text("Order completed!"),
        duration: Duration(milliseconds: 1500),
      ),
    );

    // ── Everything below runs in background — uses captured refs only ──

    // PRINT bill first — await to ensure it completes
    try {
      await thermalPrinter.printBill(
        order,
        items,
        customer,
        storeName: activeOutlet?.name,
        storeAddress: activeOutlet?.address,
        customerRewardBalance: rewardBalance,
      );
    } catch (e) {
      logDebug("Thermal bill print failed: $e");
    }

    // Update customer stats and reward points (fire-and-forget)
    if (customerId != null) {
      orderRepo
          .updateCustomerStats(customerId, grandTotal, syncRepo: syncRepo)
          .catchError((e) => logDebug("Customer stats update failed: $e"));

      // BUG-24: reward base is the actual amount paid (after ALL discounts),
      // not the pre-manual-discount amount. Adding manualDiscount back inflated
      // points proportionally to how large the discount was.
      final rewardBaseAmount = grandTotal;
      orderRepo
          .processRewardForOrder(orderId, rewardBaseAmount, customerId)
          .catchError((e) => logDebug("Reward processing failed: $e"));

      // Commit the redemption that was staged in the cart (atomic with order).
      if (rewardPointsRedeemed > 0) {
        rewardNotifier
            .redeemReward(
              customerId: customerId,
              pointsToRedeem: rewardPointsRedeemed,
              orderId:
                  orderId, // BUG-29: link redemption to order for cancel refund
              description:
                  'Redeemed ${rewardPointsRedeemed.toInt()} points on order',
            )
            .catchError((e) {
              logDebug("Reward redemption commit failed: $e");
              return false;
            });
      }
    }

    // Auto-Send to WhatsApp (fire-and-forget)
    _isBillWhatsAppEnabled()
        .then((isEnabled) {
          if (isEnabled &&
              customer != null &&
              (customer.phone?.isNotEmpty ?? false)) {
            shareService
                .shareInvoiceWhatsApp(order, items, customer)
                .catchError((e) => logDebug("WhatsApp share failed: $e"));
          }
        })
        .catchError((_) {});

    // if (context.mounted) {
    //   await showPostCheckoutActions(context, ref, orderId, customer);
    // }
  } catch (e) {
    logDebug("Checkout error: $e");
    
    // RESTORE CART IF FALLBACK FAILS
    try {
      ref.read(cartProvider.notifier).restoreCart(cart);
      logDebug("Cart restored after failed checkout.");
    } catch (_) {}

    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Checkout failed — Cart restored. Error: $e"),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {}
  } finally {
    try {
      _checkoutInProgress = false;
    } catch (_) {}
    logDebug('[BILL] Checkout completed');
  }
}

Future<void> showPostCheckoutActions(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  Customer? customer,
) async {
  final db = ref.read(appDatabaseProvider);
  final isWhatsAppEnabled = await _isBillWhatsAppEnabled();
  final order = await (db.select(
    db.orders,
  )..where((t) => t.id.equals(orderId))).getSingle();
  final items = await (db.select(
    db.orderItems,
  )..where((t) => t.orderId.equals(orderId))).get();

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Order completed'),
      content: const Text('Print or share the bill now?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Later'),
        ),
        TextButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            // Try Thermal first
            try {
              await ref
                  .read(thermalPrintingServiceProvider)
                  .printBill(order, items, customer);
            } catch (e) {
              // If thermal fails, fallback to PDF or show error
              if (context.mounted) {
                await ref
                    .read(printingServiceProvider)
                    .printInvoice(order, items, customer);
              }
            }
          },
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print Bill'),
        ),
        if (isWhatsAppEnabled)
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(shareServiceProvider)
                  .shareInvoiceWhatsApp(order, items, customer);
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share (WhatsApp)'),
          ),
      ],
    ),
  );
}

void showCustomerSelect(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar with Manage Customers shortcut
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.people_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Customer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx); // close dialog
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Manage'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(child: CustomerListScreen(isSelectionMode: true)),
          ],
        ),
      ),
    ),
  ).then((selected) {
    if (selected == "walk_in") {
      logDebug('🧍 Walk-in selected');
      ref.read(cartProvider.notifier).clearCustomerSelection();
    } else if (selected is Customer) {
      ref.read(cartProvider.notifier).setCustomer(selected);
    }
  });
}

Future<void> showRedemptionDialog(BuildContext context, WidgetRef ref) async {
  final cart = ref.read(cartProvider);
  final customer = cart.selectedCustomer;

  if (customer == null) {
    await checkout(context, ref);
    return;
  }

  // Check if reward system is enabled
  final isEnabled = await ref.read(isRewardSystemEnabledProvider.future);
  if (!context.mounted) return;
  if (!isEnabled) {
    await checkout(context, ref);
    return;
  }

  // Get customer's reward balance
  final balance = await ref.read(
    customerRewardBalanceProvider(customer.id).future,
  );
  if (!context.mounted) return;

  if (balance < MIN_REDEMPTION_POINTS) {
    await checkout(context, ref);
    return;
  }

  // Show redemption dialog
  final settings = await ref.read(rewardSettingsProvider.future);
  if (!context.mounted) return;

  final redemptionRate =
      double.tryParse(settings[REDEMPTION_RATE_KEY] ?? '1.0') ?? 1.0;

  final maxRedemption = math
      .min(balance * redemptionRate, cart.grandTotal)
      .floor();

  showDialog(
    context: context,
    builder: (ctx) => RedemptionDialog(
      customerName: customer.name,
      rewardBalance: balance.toInt(),
      maxRedemption: maxRedemption,
      currentTotal: cart.grandTotal,
      onRedeem: (pointsToRedeem) async {
        if (context.mounted) {
          Navigator.pop(ctx);

          // Apply redemption discount to cart (in-memory only).
          // The DB transaction is committed atomically inside checkout()
          // so points can never be lost if checkout doesn't complete.
          final discountAmount = (pointsToRedeem * redemptionRate);
          ref
              .read(cartProvider.notifier)
              .applyRewardDiscount(discountAmount, pointsToRedeem.toDouble());

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Applied ₹${discountAmount.toStringAsFixed(2)} discount',
                ),
              ),
            );
          }
        }
      },
      onSkip: () {
        Navigator.pop(ctx);
      },
    ),
  );
}
