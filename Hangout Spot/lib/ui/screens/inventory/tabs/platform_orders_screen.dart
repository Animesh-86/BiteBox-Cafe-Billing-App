import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PlatformOrdersScreen extends ConsumerStatefulWidget {
  const PlatformOrdersScreen({super.key});

  @override
  ConsumerState<PlatformOrdersScreen> createState() =>
      _PlatformOrdersScreenState();
}

class _PlatformOrdersScreenState extends ConsumerState<PlatformOrdersScreen> {
  final List<PlatformOrder> _orders = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final repo = ref.read(inventoryRepositoryProvider);
    final snapshot = await repo.fetchPlatformOrders(startAfter: _lastDoc);

    if (snapshot.docs.isNotEmpty) {
      _lastDoc = snapshot.docs.last;
      _orders.addAll(snapshot.docs.map((doc) => PlatformOrder.fromDoc(doc)));
    }

    if (snapshot.docs.length < 20) {
      _hasMore = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Platform Orders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              FilledButton.icon(
                onPressed: () => _openOrderDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Order'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_orders.isEmpty && !_isLoading)
            const Text('No platform orders yet.'),
          ..._orders.map((order) => _buildOrderCard(context, order)).toList(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_hasMore && !_isLoading)
            TextButton(onPressed: _loadMore, child: const Text('Load more')),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, PlatformOrder order) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      child: ListTile(
        title: Text('${order.platform} • ₹${order.total.toStringAsFixed(2)}'),
        subtitle: Text(formatter.format(order.createdAt)),
        trailing: order.notes == null || order.notes!.isEmpty
            ? null
            : const Icon(Icons.sticky_note_2_outlined),
      ),
    );
  }

  Future<void> _openOrderDialog(BuildContext context) async {
    String platform = 'Swiggy';
    final totalController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Platform Order'),
          content: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: platform,
                    items: const [
                      DropdownMenuItem(value: 'Swiggy', child: Text('Swiggy')),
                      DropdownMenuItem(value: 'Zomato', child: Text('Zomato')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) =>
                        setState(() => platform = value ?? 'Other'),
                    decoration: const InputDecoration(labelText: 'Platform'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total Amount',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final total = double.tryParse(totalController.text.trim()) ?? 0;
    if (total == 0) return;

    final repo = ref.read(inventoryRepositoryProvider);
    final order = PlatformOrder(
      id: const Uuid().v4(),
      platform: platform,
      total: total,
      notes: notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    await repo.createPlatformOrder(order);

    if (mounted) {
      setState(() {
        _orders.insert(0, order);
      });
    }
  }
}
