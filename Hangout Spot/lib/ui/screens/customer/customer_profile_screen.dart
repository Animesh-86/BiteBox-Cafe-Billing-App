import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/services/share_service.dart';
import 'package:intl/intl.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/main.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final Customer customer;
  const CustomerProfileScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isBillWhatsAppEnabled =
        prefs.getBool(BILL_WHATSAPP_ENABLED_KEY) ?? true;
    final locationId = ref.watch(currentLocationIdProvider).valueOrNull;
    final Stream<List<Order>> ordersStream = ref
        .watch(orderRepositoryProvider)
        .watchOrdersByCustomer(customer.id, locationId: locationId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: Column(
        children: [
          _ProfileHeader(
            customer: customer,
            isBillWhatsAppEnabled: isBillWhatsAppEnabled,
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: ordersStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return const Center(child: Text('No orders yet'));
                }

                return ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => Divider(
                    color: theme.dividerColor.withOpacity(0.3),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return FutureBuilder<List<OrderItem>>(
                      future: ref
                          .read(orderRepositoryProvider)
                          .getOrderItems(order.id),
                      builder: (context, itemSnapshot) {
                        final items = itemSnapshot.data ?? [];
                        final itemNames = items
                            .map((item) => item.itemName)
                            .toList();
                        final itemsDisplay = itemNames.isNotEmpty
                            ? itemNames.join(', ')
                            : 'No items';

                        return ListTile(
                          title: Text('Order ${order.invoiceNumber}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM, hh:mm a')
                                    .format(order.createdAt),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                itemsDisplay,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (isBillWhatsAppEnabled)
                                IconButton(
                                  icon: const Icon(Icons.share_outlined),
                                  tooltip: 'Share Bill',
                                  onPressed: () async {
                                    await ref
                                        .read(shareServiceProvider)
                                        .shareInvoiceWhatsApp(
                                          order,
                                          items,
                                          customer,
                                        );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final Customer customer;
  final bool isBillWhatsAppEnabled;
  const _ProfileHeader({
    required this.customer,
    required this.isBillWhatsAppEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(customer.phone ?? 'No phone'),
                    if (isBillWhatsAppEnabled &&
                        (customer.phone?.isNotEmpty ?? false)) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.green,
                          size: 20,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Chat on WhatsApp',
                        onPressed: () {
                          ref
                              .read(shareServiceProvider)
                              .openWhatsAppChat(
                                customer.phone!,
                                text: "Hi ${customer.name}!",
                              );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${customer.totalVisits} visits',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              Text(
                '₹${customer.totalSpent.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
