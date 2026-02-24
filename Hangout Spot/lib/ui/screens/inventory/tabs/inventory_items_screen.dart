import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:uuid/uuid.dart';

class InventoryItemsScreen extends ConsumerStatefulWidget {
  const InventoryItemsScreen({super.key});

  @override
  ConsumerState<InventoryItemsScreen> createState() =>
      _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends ConsumerState<InventoryItemsScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsStreamProvider);

    return Scaffold(
      body: itemsAsync.when(
        data: (items) {
          final categoryMap = <String, String>{};
          for (final i in items) {
            final clean = _normalizedCategory(i.category);
            categoryMap.putIfAbsent(clean.toLowerCase(), () => clean);
          }

          final categories = ['All', ...categoryMap.values];

          final filteredItems = _selectedCategory == 'All'
              ? items
              : items
                    .where(
                      (i) =>
                          _normalizedCategory(i.category).toLowerCase() ==
                          _selectedCategory.toLowerCase(),
                    )
                    .toList();

          if (items.isEmpty) {
            return const Center(
              child: Text('No inventory items yet. Tap + to add.'),
            return Scaffold(
              body: SafeArea(
                child: itemsAsync.when(
                  data: (items) {
                    final categoryMap = <String, String>{};
                    for (final i in items) {
                      final clean = _normalizedCategory(i.category);
                      categoryMap.putIfAbsent(clean.toLowerCase(), () => clean);
                    }

                    final categories = ['All', ...categoryMap.values];

                    final filteredItems = _selectedCategory == 'All'
                        ? items
                        : items
                              .where(
                                (i) =>
                                    _normalizedCategory(i.category).toLowerCase() ==
                                    _selectedCategory.toLowerCase(),
                              )
                              .toList();

                    if (items.isEmpty) {
                      return const Center(
                        child: Text('No inventory items yet. Tap + to add.'),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      children: [
                        _CategoryFilterChips(
                          context,
                          categories: categories,
                          selected: _selectedCategory,
                          onSelected: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                        const SizedBox(height: 12),
                        _InventoryGrid(
                          context,
                          items: filteredItems,
                          onAdjust: (item, delta) =>
                              _quickBump(context, ref, item, delta: delta),
                          onEdit: (item) => _openItemDialog(context, ref, item),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            );
                    SelectableText(
                      err.message!,
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                  ],
                ],
              ),
            );
          }

          return Center(child: Text('Error: $err'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openItemDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _CategoryFilterChips(
    BuildContext context, {
    required List<String> categories,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: categories
                .map(
                  (c) => _pill(
                    context,
                    label: c,
                    isSelected: selected.toLowerCase() == c.toLowerCase(),
                    onTap: () => onSelected(c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _InventoryGrid(
    BuildContext context, {
    required List<InventoryItem> items,
    required void Function(InventoryItem, double) onAdjust,
    required void Function(InventoryItem) onEdit,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final crossAxisCount = isNarrow ? 1 : 2;
        final tileHeight = isNarrow ? 200.0 : 220.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: tileHeight,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _InventoryRow(
              item: item,
              onAdjust: (delta) => onAdjust(item, delta),
              onEdit: () => onEdit(item),
            );
          },
        );
      },
    );
  }

  String _normalizedCategory(String category) {
    final clean = category.trim();
    if (clean.isEmpty) return 'Uncategorized';
    return clean;
  }

  Future<void> _quickBump(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item, {
    required double delta,
  }) async {
    final repo = ref.read(inventoryRepositoryProvider);
    try {
      await repo.adjustStockTransaction(
        itemId: item.id,
        delta: delta,
        reason: delta > 0 ? 'quick_add' : 'quick_deduct',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough stock to deduct.')),
        );
      }
    }
  }

  Future<void> _openItemDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryItem? item, {
    String? presetCategory,
  }) async {
    final nameController = TextEditingController(text: item?.name ?? '');
    final categoryController = TextEditingController(
      text: item?.category ?? (presetCategory ?? 'Beverages'),
    );
    final unitController = TextEditingController(text: item?.unit ?? 'pcs');
    final priceController = TextEditingController(
      text: item?.price?.toString() ?? '',
    );
    final currentController = TextEditingController(
      text: item?.currentQty.toString() ?? '0',
    );
    final minController = TextEditingController(
      text: item?.minQty.toString() ?? '0',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Add Item' : 'Edit Item'),
        content: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: currentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Current Qty'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Min Qty'),
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
    );

    if (confirmed != true) return;

    final repo = ref.read(inventoryRepositoryProvider);
    final newItem = InventoryItem(
      id: item?.id ?? const Uuid().v4(),
      name: nameController.text.trim(),
      category: categoryController.text.trim(),
      unit: unitController.text.trim(),
      price: double.tryParse(priceController.text.trim()),
      currentQty: double.tryParse(currentController.text.trim()) ?? 0,
      minQty: double.tryParse(minController.text.trim()) ?? 0,
    );

    await repo.upsertItem(newItem);
  }
}

class _InventoryRow extends StatelessWidget {
  final InventoryItem item;
  final void Function(double delta) onAdjust;
  final VoidCallback onEdit;

  const _InventoryRow({
    required this.item,
    required this.onAdjust,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLow = item.currentQty <= item.minQty;
    final isOut = item.currentQty <= 0;
    final step = _stepForUnit(item.unit);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface.withOpacity(isLow ? 0.6 : 0.82),
                theme.colorScheme.surfaceVariant.withOpacity(isLow ? 0.4 : 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isLow
                  ? theme.colorScheme.error.withOpacity(0.35)
                  : theme.colorScheme.outline.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isOut)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Out of stock',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.currentQty} ${item.unit} • Min ${item.minQty}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _pillButton(
                    context,
                    icon: Icons.remove,
                    label: _stepLabel(step),
                    onTap: () => onAdjust(-step),
                  ),
                  const SizedBox(width: 8),
                  _pillButton(
                    context,
                    icon: Icons.add,
                    label: _stepLabel(step),
                    onTap: () => onAdjust(step),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tap card to edit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _stepForUnit(String unit) {
    final u = unit.toLowerCase();
    if (u.contains('kg')) return 0.1;
    if (u.contains('g')) return 10;
    if (u.contains('ml')) return 50;
    return 1;
  }

  String _stepLabel(double step) {
    if (step == step.roundToDouble()) {
      return step.toStringAsFixed(0);
    }
    return step.toString();
  }

  Widget _pillButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
