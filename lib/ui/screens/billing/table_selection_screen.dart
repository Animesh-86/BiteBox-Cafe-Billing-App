import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/table_repository.dart';
import 'package:hangout_spot/ui/widgets/glass_container.dart';

class TableSelectionScreen extends ConsumerWidget {
  final Function(String tableId) onTableSelected;

  const TableSelectionScreen({super.key, required this.onTableSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Select Table',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 32), // Increased size
            tooltip: 'Create New Table',
            onPressed: () => _showCreateTableDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: tablesAsync.when(
          data: (tables) {
            if (tables.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_restaurant,
                      size: 80,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tables yet',
                      style: TextStyle(
                        fontSize: 20,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateTableDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Table'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Reduced from 4 to 3 for larger cards
                childAspectRatio:
                    1.0, // Changed from 1.2 to 1.0 for square cards
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: tables.length,
              itemBuilder: (context, index) {
                final table = tables[index];
                return _TableCard(
                  table: table,
                  onTap: () => onTableSelected(table.id),
                  onLongPress: () => _showTableOptions(context, ref, table.id),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  void _showCreateTableDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _CreateTableDialog(
        onCreateTable: (tableNumber) async {
          await ref.read(tableRepositoryProvider).createTable(tableNumber);
        },
        getNextTableNumber: () async {
          return await ref.read(tableRepositoryProvider).getNextTableNumber();
        },
      ),
    );
  }

  void _showTableOptions(BuildContext context, WidgetRef ref, String tableId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Table'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(tableRepositoryProvider).deleteTable(tableId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCard extends ConsumerWidget {
  final table;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TableCard({
    required this.table,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tableWithOrderAsync = ref.watch(tableWithOrderProvider(table.id));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black,
        opacity: 0.5,
        padding: const EdgeInsets.all(24), // Increased from 16
        child: tableWithOrderAsync.when(
          data: (tableWithOrder) {
            final hasOrder = tableWithOrder?.activeOrder != null;
            final orderTotal = tableWithOrder?.activeOrder?.totalAmount ?? 0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Table Number
                Text(
                  table.tableNumber,
                  style: TextStyle(
                    fontSize: 48, // Increased from 32
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12), // Increased from 8
                // Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, // Increased from 12
                    vertical: 6, // Increased from 4
                  ),
                  decoration: BoxDecoration(
                    color: hasOrder ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasOrder ? 'Occupied' : 'Available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Increased from 12
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasOrder) ...[
                  const SizedBox(height: 12), // Increased from 8
                  Text(
                    '₹${orderTotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 24, // Increased from 18
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Icon(Icons.error),
        ),
      ),
    );
  }
}

class _CreateTableDialog extends StatefulWidget {
  final Future<void> Function(String) onCreateTable;
  final Future<String> Function() getNextTableNumber;

  const _CreateTableDialog({
    required this.onCreateTable,
    required this.getNextTableNumber,
  });

  @override
  State<_CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<_CreateTableDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNextTableNumber();
  }

  Future<void> _loadNextTableNumber() async {
    final nextNumber = await widget.getNextTableNumber();
    _controller.text = nextNumber;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Table'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Table Number',
          hintText: '1001',
        ),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  await widget.onCreateTable(_controller.text);
                  if (mounted) Navigator.pop(context);
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
