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
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsStreamProvider);
    final dailyInvAsync = ref.watch(
      dailyInventoryStreamProvider(_selectedDate),
    );

    return Scaffold(
      body: itemsAsync.when(
        data: (items) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Manage Categories',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildShortGatewayCard(
                        context,
                        title: 'Cold Drink',
                        iconData: Icons.local_drink_rounded,
                        itemCount: items
                            .where(
                              (i) => i.category.toLowerCase() == 'cold drink',
                            )
                            .length,
                        items: items,
                      ),
                      const SizedBox(width: 12),
                      _buildShortGatewayCard(
                        context,
                        title: 'Water Bottle',
                        iconData: Icons.water_drop_rounded,
                        itemCount: items
                            .where(
                              (i) => i.category.toLowerCase() == 'water bottle',
                            )
                            .length,
                        items: items,
                      ),
                      const SizedBox(width: 12),
                      _buildAddCategoryCard(context),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildDailyTrackerInline(context, ref, items, dailyInvAsync),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildShortGatewayCard(
    BuildContext context, {
    required String title,
    required IconData iconData,
    required int itemCount,
    required List<InventoryItem> items,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showCategoryPopup(context, title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$itemCount Items',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        // TODO: Build Custom Category Maker logic
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Add New',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrackerInline(
    BuildContext context,
    WidgetRef ref,
    List<InventoryItem> items,
    AsyncValue<DailyInventory?> dailyInvAsync,
  ) {
    final theme = Theme.of(context);
    final trackerItems = items
        .where((i) => i.category.toLowerCase() == 'daily tracker')
        .toList();
    trackerItems.sort((a, b) => a.id.compareTo(b.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Tracker',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Date Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 1),
                    );
                  });
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_month_rounded, size: 20),
                label: Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Items List view
        dailyInvAsync.when(
          data: (dailyInv) {
            if (trackerItems.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No tracker items yet.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: trackerItems.length,
              itemBuilder: (context, index) {
                final item = trackerItems[index];
                return Dismissible(
                  key: ValueKey(
                    '${item.id}-${_selectedDate.toIso8601String()}-dismiss',
                  ),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 24),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  onDismissed: (_) {
                    final repo = ref.read(inventoryRepositoryProvider);
                    repo.deleteItem(item.id);
                    // Use field-level delete so we don't overwrite other
                    // fields that another device may have edited
                    repo.updateDailyItemField(
                      date: _selectedDate,
                      itemId: item.id,
                      value: null,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Tracker item deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              repo.upsertItem(item);
                              if (dailyInv != null) {
                                final oldVal = dailyInv.items[item.id];
                                if (oldVal != null) {
                                  repo.updateDailyItemField(
                                    date: _selectedDate,
                                    itemId: item.id,
                                    value: oldVal,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }
                  },
                  child: _DailyTrackerRow(
                    key: ValueKey(
                      '${item.id}-${_selectedDate.toIso8601String()}',
                    ),
                    item: item,
                    selectedDate: _selectedDate,
                    currentDaily: dailyInv,
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              final repo = ref.read(inventoryRepositoryProvider);
              final newItem = InventoryItem(
                id: const Uuid().v4(),
                name: '',
                category: 'Daily Tracker',
                unit: 'unit',
                currentQty: 0,
                minQty: 0,
              );
              repo.addItem(newItem);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Tracker Row'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48), // Bottom padding
      ],
    );
  }

  void _showCategoryPopup(BuildContext context, String categoryTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            final theme = Theme.of(context);
            return Consumer(
              builder: (context, ref, child) {
                final itemsAsync = ref.watch(inventoryItemsStreamProvider);
                final allItems = itemsAsync.valueOrNull ?? [];
                final categoryItems = allItems
                    .where(
                      (i) =>
                          i.category.toLowerCase() ==
                          categoryTitle.toLowerCase(),
                    )
                    .toList();

                return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setModalState) {
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const SizedBox(width: 24),
                              Text(
                                categoryTitle,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.add_rounded),
                                onPressed: () {
                                  _showAddItemDialog(context, categoryTitle, (
                                    newItem,
                                  ) {
                                    ref
                                        .read(inventoryRepositoryProvider)
                                        .upsertItem(newItem);
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: categoryItems.isEmpty
                                ? const Center(
                                    child: Text('No items in this category.'),
                                  )
                                : ListView.separated(
                                    controller: controller,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      120,
                                    ),
                                    itemCount: categoryItems.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = categoryItems[index];
                                      return _CategoryPopupListItem(
                                        item: item,
                                        onAdjust: (delta) => _quickBump(
                                          context,
                                          ref,
                                          item,
                                          delta: delta,
                                        ),
                                        onEdit: (newItem) {
                                          final repo = ref.read(
                                            inventoryRepositoryProvider,
                                          );
                                          repo.upsertItem(newItem);
                                        },
                                        onDelete: () {
                                          final repo = ref.read(
                                            inventoryRepositoryProvider,
                                          );
                                          repo.deleteItem(item.id);
                                          // TODO: Menu Repository Sync Hook
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _CategoryPopupListItem extends StatelessWidget {
  final InventoryItem item;
  final void Function(double delta) onAdjust;
  final void Function(InventoryItem newItem) onEdit;
  final VoidCallback onDelete;

  const _CategoryPopupListItem({
    required this.item,
    required this.onAdjust,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatQty(double qty) {
    return qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLow = item.currentQty <= item.minQty;
    final isOut = item.currentQty <= 0;
    final step = _stepForUnit(item.unit);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onTap: () => _showEditItemDialog(context, item, onEdit),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            border: Border.all(
              color: isLow
                  ? theme.colorScheme.error.withOpacity(0.35)
                  : theme.colorScheme.outline.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
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
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isOut)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
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
                    const SizedBox(height: 6),
                    Text(
                      '${_formatQty(item.currentQty)} ${item.unit} • Min ${_formatQty(item.minQty)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Row(
                    children: [
                      _pillButton(
                        context,
                        icon: Icons.remove,
                        label: _stepLabel(step),
                        onTap: () => onAdjust(-step),
                      ),
                      const SizedBox(width: 6),
                      _pillButton(
                        context,
                        icon: Icons.add,
                        label: _stepLabel(step),
                        onTap: () => onAdjust(step),
                      ),
                    ],
                  ),
                ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAddItemDialog(
  BuildContext context,
  String categoryTitle,
  void Function(InventoryItem) onSave,
) async {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '0');
  final minCtrl = TextEditingController(text: '0');

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('Add Item to $categoryTitle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Current Stock'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Minimum Stock'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              final newMin = double.tryParse(minCtrl.text.trim()) ?? 0.0;
              if (newName.isNotEmpty) {
                onSave(
                  InventoryItem(
                    id: const Uuid().v4(),
                    name: newName,
                    category: categoryTitle,
                    currentQty: newQty,
                    minQty: newMin,
                    unit: 'pcs',
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}

Future<void> _showEditItemDialog(
  BuildContext context,
  InventoryItem item,
  void Function(InventoryItem) onSave,
) async {
  String format(double val) =>
      val == val.roundToDouble() ? val.toInt().toString() : val.toString();

  final nameCtrl = TextEditingController(text: item.name);
  final qtyCtrl = TextEditingController(text: format(item.currentQty));
  final minCtrl = TextEditingController(text: format(item.minQty));

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Edit Item Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Current Stock'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Minimum Stock'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newQty =
                  double.tryParse(qtyCtrl.text.trim()) ?? item.currentQty;
              final newMin =
                  double.tryParse(minCtrl.text.trim()) ?? item.minQty;
              if (newName.isNotEmpty) {
                onSave(
                  item.copyWith(
                    name: newName,
                    currentQty: newQty,
                    minQty: newMin,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _DailyTrackerRow extends ConsumerStatefulWidget {
  final InventoryItem item;
  final DateTime selectedDate;
  final DailyInventory? currentDaily;

  const _DailyTrackerRow({
    super.key,
    required this.item,
    required this.selectedDate,
    required this.currentDaily,
  });

  @override
  ConsumerState<_DailyTrackerRow> createState() => _DailyTrackerRowState();
}

class _DailyTrackerRowState extends ConsumerState<_DailyTrackerRow> {
  late TextEditingController _nameController;
  late TextEditingController _valueController;
  final _nameFocus = FocusNode();
  final _valueFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    final val = widget.currentDaily?.items[widget.item.id];
    _valueController = TextEditingController(text: val ?? '');

    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && _nameController.text != widget.item.name) {
        _updateName();
      }
    });

    _valueFocus.addListener(() {
      if (!_valueFocus.hasFocus) {
        _updateValue();
      }
    });
  }

  @override
  void didUpdateWidget(_DailyTrackerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.name != widget.item.name && !_nameFocus.hasFocus) {
      _nameController.text = widget.item.name;
    }
    final oldVal = oldWidget.currentDaily?.items[oldWidget.item.id];
    final newVal = widget.currentDaily?.items[widget.item.id];
    if (oldVal != newVal && !_valueFocus.hasFocus) {
      _valueController.text = newVal ?? '';
    }
  }

  void _updateName() {
    final repo = ref.read(inventoryRepositoryProvider);
    repo.upsertItem(widget.item.copyWith(name: _nameController.text.trim()));
  }

  void _updateValue() {
    final text = _valueController.text.trim();
    final repo = ref.read(inventoryRepositoryProvider);
    final prevVal = widget.currentDaily?.items[widget.item.id];
    final prevQty = double.tryParse(prevVal ?? '') ?? 0.0;
    final newQty = double.tryParse(text) ?? prevQty;

    // Update the current item value
    repo.updateDailyItemField(
      date: widget.selectedDate,
      itemId: widget.item.id,
      value: text.isEmpty ? null : text,
    );

    // If this is a bottle or cold drink and stock increased, decrement relevant tracker
    final itemName = widget.item.name.toLowerCase();
    final itemCategory = widget.item.category.toLowerCase();
    final daily = widget.currentDaily;
    if (daily != null && newQty > prevQty) {
      // Bottle logic
      if (itemName.contains('bottle') || itemCategory.contains('bottle')) {
        final orderedBottleEntry = daily.items.entries.firstWhere(
          (e) =>
              e.value.toLowerCase().contains('ordered bottle') ||
              e.key.toLowerCase().contains('ordered bottle'),
          orElse: () => MapEntry('', ''),
        );
        if (orderedBottleEntry.key.isNotEmpty) {
          final orderedVal =
              double.tryParse(daily.items[orderedBottleEntry.key] ?? '') ?? 0.0;
          final newOrderedVal = orderedVal - 1;
          repo.updateDailyItemField(
            date: widget.selectedDate,
            itemId: orderedBottleEntry.key,
            value: newOrderedVal.toString(),
          );
        }
      }
      // Cold drink logic
      if (itemName.contains('cold drink') ||
          itemCategory.contains('cold drink')) {
        final orderedColdDrinkEntry = daily.items.entries.firstWhere(
          (e) =>
              e.value.toLowerCase().contains('ordered cold drink') ||
              e.key.toLowerCase().contains('ordered cold drink'),
          orElse: () => MapEntry('', ''),
        );
        if (orderedColdDrinkEntry.key.isNotEmpty) {
          final orderedVal =
              double.tryParse(daily.items[orderedColdDrinkEntry.key] ?? '') ??
              0.0;
          final newOrderedVal = orderedVal - 1;
          repo.updateDailyItemField(
            date: widget.selectedDate,
            itemId: orderedColdDrinkEntry.key,
            value: newOrderedVal.toString(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              onSubmitted: (_) => _updateName(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Item Name',
                isDense: true,
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _valueController,
              focusNode: _valueFocus,
              keyboardType: TextInputType.text,
              textAlign: TextAlign.right,
              onSubmitted: (_) => _updateValue(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Value',
                isDense: true,
              ),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_nameFocus.hasFocus || _nameController.text != widget.item.name)
      _updateName();
    if (_valueFocus.hasFocus) _updateValue();
    _nameController.dispose();
    _valueController.dispose();
    _nameFocus.dispose();
    _valueFocus.dispose();
    super.dispose();
  }
}
