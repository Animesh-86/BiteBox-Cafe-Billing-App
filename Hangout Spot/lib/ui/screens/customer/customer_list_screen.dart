import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/customer_repository.dart';
import 'package:hangout_spot/ui/screens/customer/customer_profile_screen.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  const CustomerListScreen({super.key, this.isSelectionMode = false});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    final customersAsync = ref.watch(customersStreamProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        child: const Icon(Icons.add),
      ),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty && !widget.isSelectionMode) {
            return const Center(child: Text("No customers found."));
          }
          return ListView.builder(
            itemCount: widget.isSelectionMode
                ? customers.length + 1
                : customers.length,
            itemBuilder: (context, index) {
              // Add Walk-in option at the top in selection mode
              if (widget.isSelectionMode && index == 0) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    child: Icon(
                      Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Walk-in Customer'),
                  subtitle: const Text('Continue without customer selection'),
                  onTap: () {
                    Navigator.pop(context, "walk_in");
                  },
                );
              }
              final customerIndex = widget.isSelectionMode ? index - 1 : index;
              final customer = customers[customerIndex];
              return ListTile(
                leading: CircleAvatar(child: Text(customer.name[0])),
                title: Text(customer.name),
                subtitle: Text(customer.phone ?? 'No phone'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${customer.totalVisits} visits"),
                    Text("₹${customer.totalSpent.toStringAsFixed(0)}"),
                    Consumer(
                      builder: (context, ref, _) {
                        final pointsAsync = ref.watch(
                          customerRewardBalanceProvider(customer.id),
                        );
                        return pointsAsync.when(
                          data: (points) {
                            if (points <= 0) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${points.toStringAsFixed(0)} pts",
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  if (widget.isSelectionMode) {
                    Navigator.pop(context, customer);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerProfileScreen(customer: customer),
                      ),
                    );
                  }
                },
                onLongPress: () =>
                    _showAddEditDialog(context, customer: customer),
              );
            },
          );
        },
        error: (err, stack) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final discountController = TextEditingController(
      text: customer?.discountPercent.toString() ?? '0.0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountController,
                decoration: const InputDecoration(labelText: 'Discount %'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          if (customer != null)
            TextButton.icon(
              onPressed: () async {
                await ref
                    .read(customerRepositoryProvider)
                    .deleteCustomer(customer.id);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final repo = ref.read(customerRepositoryProvider);
                if (customer == null) {
                  repo.addCustomer(
                    CustomersCompanion(
                      id: drift.Value(const Uuid().v4()),
                      name: drift.Value(nameController.text),
                      phone: drift.Value(
                        phoneController.text.isEmpty
                            ? null
                            : phoneController.text,
                      ),
                      discountPercent: drift.Value(
                        double.tryParse(discountController.text) ?? 0.0,
                      ),
                    ),
                  );
                } else {
                  repo.updateCustomer(
                    customer.copyWith(
                      name: nameController.text,
                      phone: drift.Value(
                        phoneController.text.isEmpty
                            ? null
                            : phoneController.text,
                      ),
                      discountPercent:
                          double.tryParse(discountController.text) ?? 0.0,
                    ),
                  );
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

final customersStreamProvider = StreamProvider.family<List<Customer>, String>((
  ref,
  query,
) {
  return ref.watch(customerRepositoryProvider).watchCustomers(query);
});
