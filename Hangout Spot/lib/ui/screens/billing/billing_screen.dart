import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/offers/promo_provider.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/ui/screens/billing/billing_items_grid.dart';
import 'package:hangout_spot/ui/screens/billing/billing_providers.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_actions.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_cart_mobile.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_cart_panel.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_category_sidebar.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_held_orders.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_styles.dart';

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

    // Apply promo discount if any
    ref.read(cartProvider.notifier).setPromoDiscount(promoDiscount);

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Consumer(
          builder: (context, ref, _) {
            final activeOutlet = ref.watch(activeOutletProvider).valueOrNull;

            return Row(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'POS Terminal',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (activeOutlet != null)
                      Text(
                        activeOutlet.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        'No Active Outlet',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          // Customer Select
          TextButton.icon(
            onPressed: () => showCustomerSelect(context, ref),
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
            onPressed: () => printKot(context, ref),
          ),
          // Held Orders
          const HeldOrdersButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: isTablet ? const _TabletLayout() : const _MobileLayout(),
    );
  }
}

/// Mobile Layout: Categories sidebar (left - adjustable) + Items (right)
class _MobileLayout extends ConsumerWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              color: billingSurface(context, darkOpacity: 0.04),
              borderRadius: BorderRadius.circular(16),
              boxShadow: billingShadow(context),
            ),
            child: const CategorySidebar(),
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
              color: billingOutline(context),
              child: MouseRegion(
                child: Center(
                  child: Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: billingOutline(context, darkOpacity: 0.4),
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
              // Cart Summary at TOP
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: billingSurface(context, darkOpacity: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: billingShadow(context),
                ),
                child: const CartMobileBottomBar(),
              ),

              // Items Grid (expanded)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: billingSurface(context, darkOpacity: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: billingShadow(context),
                  ),
                  child: const BillingItemsGrid(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tablet Layout: Sidebar -> Grid -> Cart Panel
class _TabletLayout extends StatelessWidget {
  const _TabletLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Categories Sidebar
        Container(
          width: 130, // Fixed width for tablet sidebar
          margin: const EdgeInsets.fromLTRB(16, 0, 8, 16),
          decoration: BoxDecoration(
            color: billingSurface(context, darkOpacity: 0.04),
            borderRadius: BorderRadius.circular(16),
            boxShadow: billingShadow(context),
          ),
          child: const CategorySidebar(),
        ),

        // Items Grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            decoration: BoxDecoration(
              color: billingSurface(context, darkOpacity: 0.04),
              borderRadius: BorderRadius.circular(16),
              boxShadow: billingShadow(context),
            ),
            child: const BillingItemsGrid(),
          ),
        ),

        // Cart Panel (Right side)
        const SizedBox(
          width: 350,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 16, 16),
            child: CartPanel(),
          ),
        ),
      ],
    );
  }
}
