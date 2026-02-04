import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/services/printing_service.dart';
import 'package:hangout_spot/services/share_service.dart';
import 'package:hangout_spot/ui/screens/customer/customer_list_screen.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:hangout_spot/logic/offers/promo_provider.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hangout_spot/ui/screens/billing/billing_providers.dart';
import 'package:hangout_spot/ui/screens/billing/billing_items_grid.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';
import 'package:uuid/uuid.dart';

Color _billingSurface(BuildContext context, {double darkOpacity = 0.08}) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surface.withOpacity(darkOpacity)
      : theme.colorScheme.surface;
}

Color _billingSurfaceVariant(
  BuildContext context, {
  double darkOpacity = 0.12,
}) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceVariant.withOpacity(darkOpacity)
      : theme.colorScheme.surfaceVariant;
}

Color _billingOutline(BuildContext context, {double darkOpacity = 0.2}) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outline.withOpacity(darkOpacity)
      : theme.colorScheme.outline.withOpacity(0.6);
}

Color _billingText(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color _billingMutedText(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Widget _billingPricePill(BuildContext context, String text) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final caramel = isDark
      ? theme.colorScheme.secondary
      : const Color(0xFFEDAD4C);
  final coffeeDark = isDark
      ? theme.colorScheme.onSurface
      : const Color(0xFF98664D);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: caramel.withOpacity(0.25),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: coffeeDark,
      ),
    ),
  );
}

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _BillingView();
  }
}

/// Main Billing View - Optimized for mobile and tablet
class _BillingView extends ConsumerWidget {
  const _BillingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cart = ref.watch(cartProvider);
    final promoDiscount = ref.watch(promoDiscountProvider);
    ref.read(cartProvider.notifier).setPromoDiscount(promoDiscount);

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.point_of_sale_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'POS Terminal',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 18,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          // Customer Select
          TextButton.icon(
            onPressed: () => _showCustomerSelect(context, ref),
            icon: const Icon(Icons.person_outline, size: 16),
            label: Text(
              cart.customer?.name ?? 'Walk-in',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          // KOT Print
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 18),
            tooltip: "Print KOT",
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: () => _printKot(context, ref),
          ),
          // Held Orders
          _HeldOrdersButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: isTablet ? _TabletLayout() : _MobileLayout(),
    );
  }

  Future<void> _printKot(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
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

      await ref.read(printingServiceProvider).printKot(order, items);

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
}

/// Tablet Layout: Categories (left) | Items (center) | Cart (right)
class _TabletLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Categories Sidebar (15%)
        Expanded(
          flex: 15,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _billingSurface(context, darkOpacity: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _billingOutline(context)),
            ),
            child: const _CategorySidebar(),
          ),
        ),
        // Items Grid (50%)
        Expanded(
          flex: 50,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _billingSurface(context, darkOpacity: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _billingOutline(context)),
            ),
            child: const BillingItemsGrid(),
          ),
        ),
        // Cart Panel (35%)
        Expanded(
          flex: 35,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _billingSurface(context, darkOpacity: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _billingOutline(context)),
            ),
            child: const _CartPanel(),
          ),
        ),
      ],
    );
  }
}

/// Mobile Layout: Categories sidebar (left - adjustable) + Items (right)
class _MobileLayout extends ConsumerWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final itemCount = cart.items.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarFlex = ref.watch(sidebarFlexProvider);

    // Clamp sidebar flex between 15 and 35
    final constrainedFlex = sidebarFlex.clamp(15.0, 35.0);

    return Row(
      children: [
        // Categories Sidebar (left - adjustable)
        Expanded(
          flex: constrainedFlex.toInt(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    Theme.of(context).dividerTheme.color ??
                    _billingOutline(context),
              ),
            ),
            child: const _CategorySidebar(),
          ),
        ),
        // Draggable Divider
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              // Calculate new flex based on drag movement
              final newFlex =
                  constrainedFlex + (details.delta.dx / screenWidth * 100);
              ref.read(sidebarFlexProvider.notifier).state = newFlex.clamp(
                15.0,
                35.0,
              );
            },
            child: Container(
              width: 4,
              color: _billingOutline(context),
              child: MouseRegion(
                child: Center(
                  child: Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _billingOutline(context, darkOpacity: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Items Grid (middle - flexible)
        Expanded(
          flex: (100 - constrainedFlex.toInt()).clamp(65, 85).toInt(),
          child: Column(
            children: [
              // Items Grid (expanded)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          Theme.of(context).dividerTheme.color ??
                          _billingOutline(context),
                    ),
                  ),
                  child: const BillingItemsGrid(),
                ),
              ),
              // Cart Summary at bottom
              if (itemCount > 0)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _billingSurface(context, darkOpacity: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _billingOutline(context, darkOpacity: 0.3),
                    ),
                  ),
                  child: const _CartMobileBottomBar(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Categories Sidebar (Vertical for tablet/desktop)
class _CategorySidebar extends ConsumerWidget {
  const _CategorySidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    return categoriesAsync.when(
      data: (cats) {
        final allCats = [
          const Category(
            id: 'all',
            name: 'All',
            color: 0,
            sortOrder: -1,
            isDeleted: false,
            discountPercent: 0.0,
          ),
          ...cats,
        ];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allCats.length,
                itemBuilder: (context, index) {
                  final cat = allCats[index];
                  final isSelected =
                      selectedCat == cat.id ||
                      (selectedCat == null && cat.id == 'all');

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Material(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          ref.read(selectedCategoryProvider.notifier).state =
                              cat.id;
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.2)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getCategoryIcon(cat.name),
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withOpacity(0.6),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withOpacity(0.6),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('all')) return Icons.apps;
    if (lower.contains('coffee') || lower.contains('beverage'))
      return Icons.coffee;
    if (lower.contains('toast') || lower.contains('bread'))
      return Icons.breakfast_dining;
    if (lower.contains('sandwich')) return Icons.lunch_dining;
    if (lower.contains('pizza')) return Icons.local_pizza;
    if (lower.contains('burger')) return Icons.fastfood;
    if (lower.contains('dessert') || lower.contains('sweet')) return Icons.cake;
    return Icons.restaurant;
  }
}

/// Cart Panel (Tablet/Desktop)
class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel();

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final nonPromoDiscount = (cart.totalDiscount - cart.promoDiscount).clamp(
      0.0,
      cart.totalDiscount,
    );

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              bottom: BorderSide(
                color:
                    Theme.of(context).dividerTheme.color ??
                    _billingOutline(context),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: cart.canUndo ? notifier.undo : null,
                        icon: const Icon(Icons.undo, size: 18),
                        tooltip: 'Undo',
                      ),
                      IconButton(
                        onPressed: cart.canRedo ? notifier.redo : null,
                        icon: const Icon(Icons.redo, size: 18),
                        tooltip: 'Redo',
                      ),
                      if (cart.items.isNotEmpty)
                        GestureDetector(
                          onTap: () => notifier.clearCart(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (cart.items.isNotEmpty) const SizedBox(height: 8),
              if (cart.items.isNotEmpty)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FutureBuilder<String>(
                        future: ref
                            .watch(sessionManagerProvider)
                            .getNextInvoiceNumber(),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? '... ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    if (cart.customer != null) const SizedBox(width: 8),
                    if (cart.customer != null)
                      Icon(
                        Icons.person,
                        size: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    if (cart.customer != null) const SizedBox(width: 4),
                    if (cart.customer != null)
                      Expanded(
                        child: Text(
                          cart.customer!.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: _billingMutedText(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),

        // Cart Items
        Expanded(
          child: cart.items.isEmpty
              ? Center(
                  child: Text(
                    'Cart empty',
                    style: TextStyle(
                      color: _billingMutedText(context),
                      fontSize: 12,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return GestureDetector(
                      onTap: () =>
                          notifier.updateQuantity(item.id, item.quantity + 1),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _billingSurface(context, darkOpacity: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _billingOutline(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _billingText(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _billingPricePill(
                                  context,
                                  "₹${item.total.toStringAsFixed(0)}",
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "₹${item.item.price}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _billingMutedText(context),
                                      ),
                                    ),
                                    if (item.item.discountPercent > 0 ||
                                        item.discountAmount > 0)
                                      Text(
                                        'Discount: ₹${item.discountAmount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.orange.shade300,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _billingSurfaceVariant(
                                      context,
                                      darkOpacity: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => notifier.updateQuantity(
                                          item.id,
                                          item.quantity - 1,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.remove,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: Text(
                                          "${item.quantity}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: _billingText(context),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => notifier.updateQuantity(
                                          item.id,
                                          item.quantity + 1,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.add,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Footer (Totals & Actions)
        AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _billingSurface(context, darkOpacity: 0.04),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              border: Border(top: BorderSide(color: _billingOutline(context))),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Discount Input
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _billingSurfaceVariant(context, darkOpacity: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _billingOutline(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.discount,
                          size: 16,
                          color: _billingMutedText(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Discount %',
                          style: TextStyle(
                            fontSize: 11,
                            color: _billingMutedText(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 12,
                              color: _billingText(context),
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: _billingMutedText(
                                  context,
                                ).withOpacity(0.6),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: _billingOutline(context),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: _billingOutline(context),
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              final percent = double.tryParse(value) ?? 0.0;
                              final discountAmount =
                                  cart.subtotal * (percent / 100);
                              notifier.setManualDiscount(discountAmount);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Payment Method
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _billingSurfaceVariant(context, darkOpacity: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _billingOutline(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.payment,
                              size: 16,
                              color: _billingMutedText(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payment',
                              style: TextStyle(
                                fontSize: 11,
                                color: _billingMutedText(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _PaymentChip(
                              label: 'Cash',
                              isSelected: cart.paymentMode == 'Cash',
                              onTap: () => notifier.setPaymentMode('Cash'),
                            ),
                            _PaymentChip(
                              label: 'UPI',
                              isSelected: cart.paymentMode == 'UPI',
                              onTap: () => notifier.setPaymentMode('UPI'),
                            ),
                            _PaymentChip(
                              label: 'Split',
                              isSelected: cart.paymentMode == 'Split',
                              onTap: () => notifier.setPaymentMode('Split'),
                            ),
                          ],
                        ),
                        if (cart.paymentMode == 'Split')
                          const SizedBox(height: 8),
                        if (cart.paymentMode == 'Split')
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _billingText(context),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Cash',
                                    labelStyle: TextStyle(
                                      fontSize: 10,
                                      color: _billingMutedText(context),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final cash = double.tryParse(value) ?? 0.0;
                                    final upi = cart.grandTotal - cash;
                                    notifier.setPaymentSplit(
                                      cash,
                                      upi > 0 ? upi : 0,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(
                                    text: cart.paidUPI > 0
                                        ? cart.paidUPI.toStringAsFixed(2)
                                        : '',
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _billingText(context),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'UPI',
                                    labelStyle: TextStyle(
                                      fontSize: 10,
                                      color: _billingMutedText(context),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final upi = double.tryParse(value) ?? 0.0;
                                    final cash = cart.grandTotal - upi;
                                    notifier.setPaymentSplit(
                                      cash > 0 ? cash : 0,
                                      upi,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Price Breakdown
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _billingSurfaceVariant(context, darkOpacity: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: TextStyle(
                                fontSize: 11,
                                color: _billingMutedText(context),
                              ),
                            ),
                            Text(
                              "₹${cart.subtotal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 11,
                                color: _billingMutedText(context),
                              ),
                            ),
                          ],
                        ),
                        if (cart.promoDiscount > 0) const SizedBox(height: 4),
                        if (cart.promoDiscount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Promo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _billingMutedText(context),
                                ),
                              ),
                              Text(
                                "-₹${cart.promoDiscount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.pinkAccent,
                                ),
                              ),
                            ],
                          ),
                        if (nonPromoDiscount > 0) const SizedBox(height: 4),
                        if (nonPromoDiscount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Discount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _billingMutedText(context),
                                ),
                              ),
                              Text(
                                "-₹${nonPromoDiscount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        if (cart.taxAmount > 0) const SizedBox(height: 4),
                        if (cart.taxAmount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tax',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _billingMutedText(context),
                                ),
                              ),
                              Text(
                                "+₹${cart.taxAmount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _billingMutedText(context),
                                ),
                              ),
                            ],
                          ),
                        Divider(
                          height: 12,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                color: _billingText(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "₹${cart.grandTotal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Reward Points Display
                        if (cart.selectedCustomer != null)
                          FutureBuilder<bool>(
                            future: ref.watch(
                              isRewardSystemEnabledProvider.future,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !snapshot.data!) {
                                return const SizedBox.shrink();
                              }

                              final rewardBaseAmount =
                                  cart.grandTotal + cart.manualDiscount;
                              final pointsEarned =
                                  (rewardBaseAmount * REWARD_EARNING_RATE)
                                      .floor();

                              if (pointsEarned == 0) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.card_giftcard,
                                          size: 14,
                                          color: Colors.orange[300],
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Rewards Earned',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '+$pointsEarned pts',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _holdOrder(context, ref),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _billingOutline(context)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text(
                            'Hold',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _checkout(context, ref),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          child: Text(
                            'Pay',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _holdOrder(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
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

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
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

      ref.read(cartProvider.notifier).clearCart();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Order completed!")));
      }
      if (context.mounted) {
        await _showPostCheckoutActions(context, ref, orderId, customer);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _showPostCheckoutActions(
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
              await ref
                  .read(printingServiceProvider)
                  .printInvoice(order, items, customer);
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
}

/// Mobile Bottom Cart Bar (shows cart summary for mobile)
class _CartMobileBottomBar extends ConsumerWidget {
  const _CartMobileBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: _MobileCartModal(scrollController: controller),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${cart.items.length} items",
                  style: TextStyle(
                    fontSize: 12,
                    color: _billingMutedText(context),
                  ),
                ),
                Text(
                  "₹${cart.grandTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _billingText(context),
                  ),
                ),
              ],
            ),
            Icon(
              Icons.expand_less,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mobile Cart Modal (full cart view for mobile)
class _MobileCartModal extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const _MobileCartModal({this.scrollController});

  @override
  ConsumerState<_MobileCartModal> createState() => _MobileCartModalState();
}

class _MobileCartModalState extends ConsumerState<_MobileCartModal> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final nonPromoDiscount = (cart.totalDiscount - cart.promoDiscount).clamp(
      0.0,
      cart.totalDiscount,
    );

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _billingOutline(context))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<String>(
                    future: ref
                        .watch(sessionManagerProvider)
                        .getNextInvoiceNumber(),
                    builder: (context, snapshot) => Text(
                      'Order - ${snapshot.data ?? '...'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _billingText(context),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: cart.canUndo ? notifier.undo : null,
                        icon: const Icon(Icons.undo, size: 20),
                        tooltip: 'Undo',
                      ),
                      IconButton(
                        onPressed: cart.canRedo ? notifier.redo : null,
                        icon: const Icon(Icons.redo, size: 20),
                        tooltip: 'Redo',
                      ),
                      if (cart.items.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Cart'),
                                content: const Text(
                                  'Are you sure you want to clear the entire cart?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      notifier.clearCart();
                                      Navigator.pop(ctx);
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      if (cart.items.isNotEmpty) const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          color: _billingMutedText(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (cart.items.isNotEmpty) const SizedBox(height: 10),
              if (cart.items.isNotEmpty)
                Row(
                  children: [
                    if (cart.customer != null)
                      Icon(
                        Icons.person,
                        size: 14,
                        color: _billingMutedText(context),
                      ),
                    if (cart.customer != null) const SizedBox(width: 4),
                    if (cart.customer != null)
                      Expanded(
                        child: Text(
                          cart.customer!.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: _billingMutedText(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              // Customer Selection & Rewards Section
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showCustomerSelect(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _billingSurface(context, darkOpacity: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _billingOutline(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Customer',
                              style: TextStyle(
                                fontSize: 11,
                                color: _billingMutedText(context),
                              ),
                            ),
                            if (cart.customer == null)
                              Text(
                                'Tap to select',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _billingMutedText(context),
                                ),
                              )
                            else
                              Text(
                                '${cart.customer!.name} (${cart.customer!.totalVisits} visits)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _billingText(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (cart.customer != null)
                        FutureBuilder<bool>(
                          future: ref.watch(
                            isRewardSystemEnabledProvider.future,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ref
                                  .watch(
                                    customerRewardBalanceProvider(
                                      cart.customer!.id,
                                    ),
                                  )
                                  .when(
                                    data: (balance) => Text(
                                      '${balance.toInt()} pts',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    loading: () => const Text(
                                      '... pts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    error: (_, __) => const Text(
                                      '0 pts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            );
                          },
                        ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: _billingMutedText(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cart Items
        Expanded(
          child: cart.items.isEmpty
              ? Center(
                  child: Text(
                    'Cart empty',
                    style: TextStyle(
                      color: _billingMutedText(context),
                      fontSize: 12,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return GestureDetector(
                      onTap: () =>
                          notifier.updateQuantity(item.id, item.quantity + 1),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _billingSurface(context, darkOpacity: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _billingOutline(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _billingText(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _billingPricePill(
                                  context,
                                  "₹${item.total.toStringAsFixed(0)}",
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "₹${item.item.price}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _billingMutedText(context),
                                      ),
                                    ),
                                    if (item.item.discountPercent > 0 ||
                                        item.discountAmount > 0)
                                      Text(
                                        'Discount: ₹${item.discountAmount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade300,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _billingSurfaceVariant(
                                      context,
                                      darkOpacity: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => notifier.updateQuantity(
                                          item.id,
                                          item.quantity - 1,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.remove,
                                            size: 20,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          "${item.quantity}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _billingText(context),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => notifier.updateQuantity(
                                          item.id,
                                          item.quantity + 1,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.add,
                                            size: 20,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _billingSurface(context, darkOpacity: 0.05),
            border: Border(top: BorderSide(color: _billingOutline(context))),
          ),
          child: Column(
            children: [
              // Discount Input
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _billingSurfaceVariant(context, darkOpacity: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _billingOutline(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.discount,
                      size: 18,
                      color: _billingMutedText(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discount %',
                      style: TextStyle(
                        fontSize: 12,
                        color: _billingMutedText(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 13,
                          color: _billingText(context),
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: _billingMutedText(context).withOpacity(0.6),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: _billingOutline(context),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: _billingOutline(context),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          final percent = double.tryParse(value) ?? 0.0;
                          final discountAmount =
                              cart.subtotal * (percent / 100);
                          notifier.setManualDiscount(discountAmount);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Payment Method
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _billingSurfaceVariant(context, darkOpacity: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _billingOutline(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          size: 18,
                          color: _billingMutedText(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 12,
                            color: _billingMutedText(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _PaymentChip(
                          label: 'Cash',
                          isSelected: cart.paymentMode == 'Cash',
                          onTap: () => notifier.setPaymentMode('Cash'),
                        ),
                        _PaymentChip(
                          label: 'UPI',
                          isSelected: cart.paymentMode == 'UPI',
                          onTap: () => notifier.setPaymentMode('UPI'),
                        ),
                        _PaymentChip(
                          label: 'Split',
                          isSelected: cart.paymentMode == 'Split',
                          onTap: () => notifier.setPaymentMode('Split'),
                        ),
                      ],
                    ),
                    if (cart.paymentMode == 'Split') const SizedBox(height: 10),
                    if (cart.paymentMode == 'Split')
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 12,
                                color: _billingText(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cash',
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _billingMutedText(context),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onChanged: (value) {
                                final cash = double.tryParse(value) ?? 0.0;
                                final upi = cart.grandTotal - cash;
                                notifier.setPaymentSplit(
                                  cash,
                                  upi > 0 ? upi : 0,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                text: cart.paidUPI > 0
                                    ? cart.paidUPI.toStringAsFixed(2)
                                    : '',
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 12,
                                color: _billingText(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'UPI',
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: _billingMutedText(context),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onChanged: (value) {
                                final upi = double.tryParse(value) ?? 0.0;
                                final cash = cart.grandTotal - upi;
                                notifier.setPaymentSplit(
                                  cash > 0 ? cash : 0,
                                  upi,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Price Breakdown
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _billingSurfaceVariant(context, darkOpacity: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 12,
                            color: _billingMutedText(context),
                          ),
                        ),
                        Text(
                          "₹${cart.subtotal.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: _billingMutedText(context),
                          ),
                        ),
                      ],
                    ),
                    if (cart.promoDiscount > 0) const SizedBox(height: 6),
                    if (cart.promoDiscount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Promo',
                            style: TextStyle(
                              fontSize: 12,
                              color: _billingMutedText(context),
                            ),
                          ),
                          Text(
                            "-₹${cart.promoDiscount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.pinkAccent,
                            ),
                          ),
                        ],
                      ),
                    if (nonPromoDiscount > 0) const SizedBox(height: 6),
                    if (nonPromoDiscount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount',
                            style: TextStyle(
                              fontSize: 12,
                              color: _billingMutedText(context),
                            ),
                          ),
                          Text(
                            "-₹${nonPromoDiscount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    if (cart.taxAmount > 0) const SizedBox(height: 6),
                    if (cart.taxAmount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tax',
                            style: TextStyle(
                              fontSize: 12,
                              color: _billingMutedText(context),
                            ),
                          ),
                          Text(
                            "+₹${cart.taxAmount.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: _billingMutedText(context),
                            ),
                          ),
                        ],
                      ),
                    Divider(
                      height: 16,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 14,
                            color: _billingText(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "₹${cart.grandTotal.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    // Show reward points if customer selected
                    if (cart.customer != null) ...[
                      const SizedBox(height: 12),
                      ref
                          .watch(
                            customerRewardBalanceProvider(cart.customer!.id),
                          )
                          .when(
                            data: (balance) {
                              if (balance <= 0) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Reward Points',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        Text(
                                          '${balance.toInt()} points available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _billingText(context),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${(balance * 1.0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (balance >= MIN_REDEMPTION_POINTS)
                                          TextButton(
                                            onPressed: () =>
                                                _showRedemptionDialog(
                                                  context,
                                                  ref,
                                                ),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              minimumSize: const Size(0, 0),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Redeem',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cart.items.isNotEmpty
                          ? () => _holdOrder(context, ref)
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _billingOutline(context)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Hold', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cart.items.isNotEmpty
                          ? () => _checkout(context, ref)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        'Pay Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showRedemptionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final cart = ref.read(cartProvider);
    final customer = cart.selectedCustomer;

    if (customer == null) {
      await _checkout(context, ref);
      return;
    }

    // Check if reward system is enabled
    final isEnabled = await ref.watch(isRewardSystemEnabledProvider.future);
    if (!isEnabled) {
      await _checkout(context, ref);
      return;
    }

    // Get customer's reward balance
    final balance = await ref.read(
      customerRewardBalanceProvider(customer.id).future,
    );

    if (balance < MIN_REDEMPTION_POINTS) {
      await _checkout(context, ref);
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
              ref
                  .read(cartProvider.notifier)
                  .applyManualDiscount(discountAmount);

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

  Future<void> _holdOrder(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

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
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Order held!")));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    try {
      final sessionManager = ref.read(sessionManagerProvider);
      final orderId = await ref
          .read(orderRepositoryProvider)
          .createOrderFromCart(
            cart,
            status: 'completed',
            sessionManager: sessionManager,
          );

      // Update customer stats and reward points if customer selected
      if (cart.customer != null) {
        await ref
            .read(orderRepositoryProvider)
            .updateCustomerStats(cart.customer!.id, cart.grandTotal);

        final rewardBaseAmount = cart.grandTotal + cart.manualDiscount;
        await ref
            .read(orderRepositoryProvider)
            .processRewardForOrder(
              orderId,
              rewardBaseAmount,
              cart.customer?.id,
            );
      }

      ref.read(cartProvider.notifier).clearCart();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Order completed!")));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

/// Held Orders Button
class _HeldOrdersButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationId = ref.watch(currentLocationIdProvider).valueOrNull;
    final pendingOrdersStream = ref.watch(
      orderRepositoryProvider.select(
        (r) => r.watchPendingOrders(locationId: locationId),
      ),
    );

    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          icon: const Icon(Icons.history, size: 20),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const _HeldOrdersDialog(),
            );
          },
        ),
        StreamBuilder<List<Order>>(
          stream: pendingOrdersStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return Positioned(
                right: 8,
                top: 8,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    "${snapshot.data!.length}",
                    style: TextStyle(fontSize: 9, color: _billingText(context)),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// Held Orders Dialog
class _HeldOrdersDialog extends ConsumerWidget {
  const _HeldOrdersDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationId = ref.watch(currentLocationIdProvider).valueOrNull;
    final pendingOrdersStream = ref.watch(
      orderRepositoryProvider.select(
        (r) => r.watchPendingOrders(locationId: locationId),
      ),
    );

    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _billingOutline(context)),
                ),
              ),
              child: Text(
                "Held Orders",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _billingText(context),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Order>>(
                stream: pendingOrdersStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final orders = snapshot.data ?? [];

                  if (orders.isEmpty) {
                    return Center(
                      child: Text(
                        "No held orders",
                        style: TextStyle(color: _billingMutedText(context)),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _billingSurface(context, darkOpacity: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _billingOutline(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${order.invoiceNumber}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "₹${order.totalAmount.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _billingText(context),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeago.format(order.createdAt),
                                  style: TextStyle(
                                    color: _billingMutedText(context),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    try {
                                      final db = ref.read(appDatabaseProvider);
                                      final details = await ref
                                          .read(orderRepositoryProvider)
                                          .getOrderDetails(order.id);

                                      Customer? customer;
                                      if (order.customerId != null) {
                                        customer =
                                            await (db.select(db.customers)
                                                  ..where(
                                                    (tbl) => tbl.id.equals(
                                                      order.customerId!,
                                                    ),
                                                  ))
                                                .getSingleOrNull();
                                      }

                                      ref
                                          .read(cartProvider.notifier)
                                          .loadOrder(order, details, customer);

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        // Show cart modal
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => DraggableScrollableSheet(
                                            initialChildSize: 0.85,
                                            minChildSize: 0.5,
                                            maxChildSize: 0.95,
                                            builder: (_, controller) => Container(
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).scaffoldBackgroundColor,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                              ),
                                              child: _MobileCartModal(
                                                scrollController: controller,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text("Error: $e")),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.restore,
                                      size: 18,
                                      color: Colors.green.shade400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        title: Text(
                                          "Delete?",
                                          style: TextStyle(
                                            color: _billingText(context),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("No"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Yes"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await ref
                                          .read(orderRepositoryProvider)
                                          .deleteOrder(order.id);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment Chip Widget
class _PaymentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : _billingSurfaceVariant(context, darkOpacity: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : _billingOutline(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : _billingMutedText(context),
          ),
        ),
      ),
    );
  }
}

void _showCustomerSelect(BuildContext context, WidgetRef ref) {
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

// Redemption Dialog
class RedemptionDialog extends StatefulWidget {
  final String customerName;
  final int rewardBalance;
  final int maxRedemption;
  final double currentTotal;
  final Function(int) onRedeem;
  final VoidCallback onSkip;

  const RedemptionDialog({
    required this.customerName,
    required this.rewardBalance,
    required this.maxRedemption,
    required this.currentTotal,
    required this.onRedeem,
    required this.onSkip,
  });

  @override
  State<RedemptionDialog> createState() => _RedemptionDialogState();
}

class _RedemptionDialogState extends State<RedemptionDialog> {
  late TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redeem Reward Points'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customer: ${widget.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Points: ${widget.rewardBalance}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max Redemption: ₹${widget.maxRedemption}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Total: ₹${widget.currentTotal.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Points to Redeem:'),
            const SizedBox(height: 8),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixText: 'points',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
        ElevatedButton(
          onPressed: () {
            final points = int.tryParse(_pointsController.text) ?? 0;
            if (points <= 0) {
              widget.onSkip();
              return;
            }
            if (points > widget.rewardBalance) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Insufficient points')),
              );
              return;
            }
            widget.onRedeem(points);
          },
          child: const Text('Redeem'),
        ),
      ],
    );
  }
}
