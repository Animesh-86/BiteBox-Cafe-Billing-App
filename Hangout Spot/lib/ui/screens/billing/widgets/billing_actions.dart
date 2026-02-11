import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

import 'package:hangout_spot/services/thermal_printing_service.dart';

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

  try {
    final sessionManager = ref.read(sessionManagerProvider);
    final invoiceNumber = await sessionManager.getNextInvoiceNumber();
    final orderId = cart.orderId ?? const Uuid().v4();

    final order = Order(
      id: orderId,
      invoiceNumber: invoiceNumber,
      customerId: cart.customer?.id,
      tableId: null,
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

    final items = cart.items
        .map(
          (ci) => OrderItem(
            id: const Uuid().v4(),
            orderId: orderId,
            itemId: ci.item.id,
            itemName: ci.item.name,
            price: ci.item.price,
            quantity: ci.quantity,
            discountAmount: ci.discountAmount,
            note: ci.note,
          ),
        )
        .toList();

    // 1. Try Thermal Print
    try {
      await ref.read(thermalPrintingServiceProvider).printKot(order, items);
    } catch (e) {
      debugPrint("Thermal print failed: $e");
    }

    // 2. Fallback/Parallel PDF Print (Optional, keeping existing behavior)
    // await ref.read(printingServiceProvider).printKot(order, items);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("KOT sent to printer")));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Print failed: $e")));
    }
  }
}

Future<void> holdOrder(BuildContext context, WidgetRef ref) async {
  final cart = ref.read(cartProvider);
  if (cart.items.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
    }
    return;
  }

  try {
    final sessionManager = ref.read(sessionManagerProvider);
    await ref
        .read(orderRepositoryProvider)
        .createOrderFromCart(
          cart,
          status: 'pending',
          sessionManager: sessionManager,
        );
    ref.read(cartProvider.notifier).clearCart();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Order held!")));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}

Future<void> checkout(BuildContext context, WidgetRef ref) async {
  final cart = ref.read(cartProvider);
  if (cart.items.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
    }
    return;
  }

  try {
    final customer = cart.selectedCustomer;
    final sessionManager = ref.read(sessionManagerProvider);
    final orderId = await ref
        .read(orderRepositoryProvider)
        .createOrderFromCart(
          cart,
          status: 'completed',
          sessionManager: sessionManager,
        );

    // Update customer stats and reward points if customer is selected
    if (cart.selectedCustomer != null) {
      await ref
          .read(orderRepositoryProvider)
          .updateCustomerStats(cart.selectedCustomer!.id, cart.grandTotal);

      final rewardBaseAmount = cart.grandTotal + cart.manualDiscount;
      await ref
          .read(orderRepositoryProvider)
          .processRewardForOrder(
            orderId,
            rewardBaseAmount,
            cart.selectedCustomer?.id,
          );
    }

    // FETCH FULL ORDER OBJECT FOR PRINTING
    final db = ref.read(appDatabaseProvider);
    final order = await (db.select(
      db.orders,
    )..where((t) => t.id.equals(orderId))).getSingle();

    final items = cart.items
        .map(
          (ci) => OrderItem(
            id: const Uuid().v4(), // IDs don't matter for printing
            orderId: orderId,
            itemId: ci.item.id,
            itemName: ci.item.name,
            price: ci.item.price,
            quantity: ci.quantity,
            discountAmount: ci.discountAmount,
            note: ci.note,
          ),
        )
        .toList();

    // AUTO-PRINT THERMAL BILL
    try {
      await ref
          .read(thermalPrintingServiceProvider)
          .printBill(order, items, customer);
    } catch (e) {
      debugPrint("Thermal print failed: $e");
    }

    ref.read(cartProvider.notifier).clearCart();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Order completed!")));
    }

    // Auto-Send to WhatsApp if customer has phone
    if (customer != null && (customer.phone?.isNotEmpty ?? false)) {
      try {
        await ref
            .read(shareServiceProvider)
            .shareInvoiceWhatsApp(order, items, customer);
      } catch (e) {
        debugPrint("WhatsApp share failed: $e");
      }
    }

    // if (context.mounted) {
    //   await showPostCheckoutActions(context, ref, orderId, customer);
    // }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}

Future<void> showPostCheckoutActions(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  Customer? customer,
) async {
  final db = ref.read(appDatabaseProvider);
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: const CustomerListScreen(isSelectionMode: true),
      ),
    ),
  ).then((selected) {
    if (selected is Customer) {
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
  final isEnabled = await ref.watch(isRewardSystemEnabledProvider.future);
  if (!isEnabled) {
    await checkout(context, ref);
    return;
  }

  // Get customer's reward balance
  final balance = await ref.read(
    customerRewardBalanceProvider(customer.id).future,
  );

  if (balance < MIN_REDEMPTION_POINTS) {
    await checkout(context, ref);
    return;
  }

  // Show redemption dialog
  if (context.mounted) {
    final settings = await ref.read(rewardSettingsProvider.future);
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

            // Apply redemption
            final discountAmount = (pointsToRedeem * redemptionRate);

            // Update cart with redemption
            ref.read(cartProvider.notifier).applyManualDiscount(discountAmount);

            // Record redemption transaction
            await ref
                .read(rewardNotifierProvider.notifier)
                .redeemReward(
                  customerId: customer.id,
                  pointsToRedeem: pointsToRedeem.toDouble(),
                  description:
                      'Redeemed $pointsToRedeem points for ₹${discountAmount.toStringAsFixed(2)} discount',
                );

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
}
