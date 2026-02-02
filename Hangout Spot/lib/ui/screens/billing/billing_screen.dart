import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/ui/screens/customer/customer_list_screen.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

// Providers
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final sidebarFlexProvider = StateProvider<double>((ref) => 20.0);

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

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Printing KOT...")));
            },
          ),
          // Held Orders
          _HeldOrdersButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: isTablet ? _TabletLayout() : _MobileLayout(),
    );
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
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const _ItemsGrid(),
          ),
        ),
        // Cart Panel (35%)
        Expanded(
          flex: 35,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              color: Colors.white.withOpacity(0.1),
              child: MouseRegion(
                child: Center(
                  child: Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const _ItemsGrid(),
                ),
              ),
              // Cart Summary at bottom
              if (itemCount > 0)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getCategoryIcon(cat.name),
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white60,
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
                                      : Colors.white60,
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

/// Items Grid
class _ItemsGrid extends ConsumerWidget {
  const _ItemsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItemsAsync = ref.watch(allItemsStreamProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return allItemsAsync.when(
      data: (items) {
        // Filter to show only available items
        final availableItems = items.where((i) => i.isAvailable).toList();

        final filtered = (selectedCat == null || selectedCat == 'all')
            ? availableItems
            : availableItems.where((i) => i.categoryId == selectedCat).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              "No items",
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          );
        }

        final crossAxisCount = isTablet
            ? ((screenWidth - 50) / 180).floor().clamp(2, 5)
            : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _ItemCard(item: filtered[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }
}

/// Item Card
class _ItemCard extends ConsumerWidget {
  final Item item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider).items;
    final notifier = ref.read(cartProvider.notifier);
    final inCart = cartItems.any((i) => i.item.id == item.id);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (inCart) {
          notifier.removeByItemId(item.id);
        } else {
          notifier.addItem(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: inCart
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.2),
                    colorScheme.primary.withOpacity(0.1),
                  ],
                )
              : null,
          color: inCart ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: inCart ? colorScheme.primary : Colors.white.withOpacity(0.1),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: inCart
                      ? LinearGradient(
                          colors: [
                            colorScheme.primary.withOpacity(0.15),
                            colorScheme.primary.withOpacity(0.05),
                          ],
                        )
                      : null,
                  color: inCart ? null : Colors.white.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: inCart
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 28,
                          color: colorScheme.primary,
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            item.name.isNotEmpty
                                ? item.name[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "₹${item.price.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (item.discountPercent > 0)
                          Text(
                            "Discount: ${item.discountPercent.toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
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
                      const Icon(
                        Icons.shopping_cart,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
                      child: Text(
                        '#${1000 + DateTime.now().millisecondsSinceEpoch % 9000}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (cart.customer != null) const SizedBox(width: 8),
                    if (cart.customer != null)
                      const Icon(Icons.person, size: 12, color: Colors.white60),
                    if (cart.customer != null) const SizedBox(width: 4),
                    if (cart.customer != null)
                      Expanded(
                        child: Text(
                          cart.customer!.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
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
                    style: TextStyle(color: Colors.white60, fontSize: 12),
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
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "₹${item.total.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
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
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white60,
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
                                    color: Colors.white.withOpacity(0.08),
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
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.remove,
                                            size: 14,
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => notifier.updateQuantity(
                                          item.id,
                                          item.quantity + 1,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.add,
                                            size: 14,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Discount Input
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.discount,
                        size: 16,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Discount %',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.2),
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
                const SizedBox(height: 10),
                // Payment Method
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payment,
                            size: 16,
                            color: Colors.white60,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Payment',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Cash',
                                  labelStyle: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'UPI',
                                  labelStyle: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
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
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            "₹${cart.subtotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      if (cart.totalDiscount > 0) const SizedBox(height: 4),
                      if (cart.totalDiscount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Discount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            Text(
                              "-₹${cart.totalDiscount.toStringAsFixed(2)}",
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
                            const Text(
                              'Tax',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            Text(
                              "+₹${cart.taxAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      const Divider(height: 12, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
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
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
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
                        child: const Text(
                          'Pay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
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
                color: Colors.black,
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
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  "₹${cart.grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Order',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
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
                        child: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              if (cart.items.isNotEmpty) const SizedBox(height: 10),
              if (cart.items.isNotEmpty)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${1000 + DateTime.now().millisecondsSinceEpoch % 9000}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (cart.customer != null) const SizedBox(width: 10),
                    if (cart.customer != null)
                      const Icon(Icons.person, size: 14, color: Colors.white60),
                    if (cart.customer != null) const SizedBox(width: 4),
                    if (cart.customer != null)
                      Expanded(
                        child: Text(
                          cart.customer!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              // Customer Selection & Rewards Section
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showCustomerSelect(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Customer',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                            if (cart.customer == null)
                              const Text(
                                'Tap to select',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              )
                            else
                              Text(
                                '${cart.customer!.name} (${cart.customer!.totalVisits} visits)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (cart.customer != null)
                        Container(
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
                        ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.white60,
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
              ? const Center(
                  child: Text(
                    'Cart is empty',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return GestureDetector(
                      onTap: () =>
                          notifier.updateQuantity(item.id, item.quantity + 1),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "₹${item.total.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "₹${item.item.price} each",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
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
                                            size: 16,
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.white,
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
                                            size: 16,
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
            color: Colors.white.withOpacity(0.03),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            children: [
              // Discount Input
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.discount, size: 18, color: Colors.white60),
                    const SizedBox(width: 8),
                    const Text(
                      'Discount %',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.payment,
                          size: 18,
                          color: Colors.white60,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Payment Method',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cash',
                                labelStyle: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'UPI',
                                labelStyle: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
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
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                        Text(
                          "₹${cart.subtotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    if (cart.totalDiscount > 0) const SizedBox(height: 6),
                    if (cart.totalDiscount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Discount',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            "-₹${cart.totalDiscount.toStringAsFixed(2)}",
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
                          const Text(
                            'Tax',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            "+₹${cart.taxAmount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    const Divider(height: 16, color: Colors.white24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
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
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '₹${(balance * 1.0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Hold', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cart.items.isNotEmpty
                          ? () => _showRedemptionDialog(context, ref)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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

    if (balance <= 0) {
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

              await _checkout(context, ref);
            }
          },
          onSkip: () {
            Navigator.pop(ctx);
            _checkout(context, ref);
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
    final pendingOrdersStream = ref.watch(
      orderRepositoryProvider.select((r) => r.watchPendingOrders()),
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
                    style: const TextStyle(fontSize: 9, color: Colors.white),
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
    final pendingOrdersStream = ref.watch(
      orderRepositoryProvider.select((r) => r.watchPendingOrders()),
    );

    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: const Text(
                "Held Orders",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                    return const Center(
                      child: Text(
                        "No held orders",
                        style: TextStyle(color: Colors.white60),
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
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeago.format(order.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white60,
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
                                                color: Colors.black,
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
                                        backgroundColor: Colors.grey[900],
                                        title: const Text(
                                          "Delete?",
                                          style: TextStyle(color: Colors.white),
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
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white70,
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
