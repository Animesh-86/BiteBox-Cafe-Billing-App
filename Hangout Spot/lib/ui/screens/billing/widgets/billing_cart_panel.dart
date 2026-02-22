import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';

import 'package:hangout_spot/ui/screens/billing/widgets/billing_cart_widgets.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_styles.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
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
            color: Theme.of(context).cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              bottom: BorderSide(
                color:
                    Theme.of(context).dividerTheme.color ??
                    billingOutline(context),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold,
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
                          onTap: () {
                            // Show confirmation dialog before clearing
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Clear Cart'),
                                content: const Text(
                                  'Are you sure you want to clear all items?',
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
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            );
                          },
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
                      child: cart.invoiceNumber != null
                          ? Text(
                              cart.invoiceNumber!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : FutureBuilder<String>(
                              future: ref
                                  .watch(sessionManagerProvider)
                                  .peekNextInvoiceNumber(),
                              builder: (context, snapshot) => Text(
                                snapshot.data ?? '... ',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold,
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: billingMutedText(context),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: billingMutedText(context)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
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
              color: billingSurface(context, darkOpacity: 0.04),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: billingShadow(context),
            ),
            child: SingleChildScrollView(child: const CartFooter()),
          ),
        ),
      ],
    );
  }
}
