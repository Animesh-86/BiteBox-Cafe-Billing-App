import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/services/share_service.dart';
import 'package:intl/intl.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final Customer customer;
  const CustomerProfileScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationId = ref.watch(currentLocationIdProvider).valueOrNull;
    final ordersStream = ref
        .watch(orderRepositoryProvider)
        .watchOrdersByCustomer(customer.id, locationId: locationId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: Column(
        children: [
          _ProfileHeader(customer: customer),
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
                    return ListTile(
                      title: Text('Order ${order.invoiceNumber}'),
                      subtitle: Text(
                        DateFormat('dd MMM, hh:mm a').format(order.createdAt),
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
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: 'Share Bill',
                            onPressed: () async {
                              final items = await ref
                                  .read(orderRepositoryProvider)
                                  .getOrderItems(order.id);
                              await ref
                                  .read(shareServiceProvider)
                                  .shareInvoiceWhatsApp(order, items, customer);
                            },
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
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Customer customer;
  const _ProfileHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(customer.phone ?? 'No phone'),
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
