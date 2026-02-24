import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: billingMutedText(context),
                  ),
                ),
                Text(
                  "₹${cart.grandTotal.toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  cart.invoiceNumber != null
                      ? Text(
                          'Order - ${cart.invoiceNumber}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: billingText(context),
                              ),
                        )
                      : FutureBuilder<String>(
                          future: ref
                              .watch(sessionManagerProvider)
                              .peekNextInvoiceNumber(),
                          builder: (context, snapshot) => Text(
                            'Order - ${snapshot.data ?? '...'}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
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
                                content: SafeArea(
                                  child: const Text(
                                    'Are you sure you want to clear the entire cart?',
                                  ),
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
              const SizedBox(height: 10),
              CartCustomerSection(compact: true),
            ],
          ),
        ),

        // Cart Items
        Expanded(
          child: cart.items.isEmpty
              ? Center(
                  child: Text(
                    'Cart empty',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: billingMutedText(context),
                    ),
                  ),
                )
              : GridView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    return CartItemTile(
                      item: cart.items[index],
                      notifier: notifier,
                    );
                  },
                ),
        ),

        // Footer (compact, non-scrollable)
        AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: SafeArea(
            bottom: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: billingSurface(context, darkOpacity: 0.05),
                boxShadow: billingShadow(context),
              ),
              child: const CartFooter(),
            ),
          ),
        ),
      ],
    );
  }
}
