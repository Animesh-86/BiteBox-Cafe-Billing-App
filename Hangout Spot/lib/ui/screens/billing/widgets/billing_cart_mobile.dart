import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_actions.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_cart_widgets.dart'; // Added
import 'package:hangout_spot/ui/screens/billing/widgets/billing_styles.dart';

class CartMobileBottomBar extends ConsumerWidget {
  const CartMobileBottomBar({super.key});

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
              child: MobileCartModal(scrollController: controller),
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
                    color: billingMutedText(context),
                  ),
                ),
                Text(
                  "₹${cart.grandTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: billingText(context),
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

class MobileCartModal extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const MobileCartModal({super.key, this.scrollController});

  @override
  ConsumerState<MobileCartModal> createState() => _MobileCartModalState();
}

class _MobileCartModalState extends ConsumerState<MobileCartModal> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(boxShadow: billingShadow(context)),
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
                        color: billingText(context),
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
                          color: billingMutedText(context),
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
                        color: billingMutedText(context),
                      ),
                    if (cart.customer != null) const SizedBox(width: 4),
                    if (cart.customer != null)
                      Expanded(
                        child: Text(
                          cart.customer!.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: billingMutedText(context),
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
                onTap: () => showCustomerSelect(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: billingSurface(context, darkOpacity: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: billingShadow(context),
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
                                color: billingMutedText(context),
                              ),
                            ),
                            if (cart.customer == null)
                              Text(
                                'Tap to select',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: billingMutedText(context),
                                ),
                              )
                            else
                              Text(
                                '${cart.customer!.name} (${cart.customer!.totalVisits} visits)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: billingText(context),
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
                        color: billingMutedText(context),
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
                      color: billingMutedText(context),
                      fontSize: 12,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return CartItemTile(
                      item: cart.items[index],
                      notifier: notifier,
                    );
                  },
                ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: billingSurface(context, darkOpacity: 0.05),
            boxShadow: billingShadow(context),
          ),
          child: const CartFooter(),
        ),
      ],
    );
  }
}
