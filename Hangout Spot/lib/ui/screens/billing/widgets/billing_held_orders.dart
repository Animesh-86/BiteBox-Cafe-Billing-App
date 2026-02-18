import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_cart_mobile.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_styles.dart';
import 'package:timeago/timeago.dart' as timeago;

class HeldOrdersButton extends ConsumerWidget {
  const HeldOrdersButton({super.key});

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
              builder: (_) => const HeldOrdersDialog(),
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
                    style: TextStyle(fontSize: 9, color: billingText(context)),
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

class HeldOrdersDialog extends ConsumerWidget {
  const HeldOrdersDialog({super.key});

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
              decoration: BoxDecoration(boxShadow: billingShadow(context)),
              child: Text(
                "Held Orders",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: billingText(context),
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
                        style: TextStyle(color: billingMutedText(context)),
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
                          color: billingSurface(context, darkOpacity: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: billingShadow(context),
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
                                    color: billingText(context),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeago.format(order.createdAt),
                                  style: TextStyle(
                                    color: billingMutedText(context),
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
                                              child: MobileCartModal(
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
                                            color: billingText(context),
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
                                          .voidOrder(order.id);
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
                                      Icons
                                          .delete_forever, // Changed icon to indicate void/cancel
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
