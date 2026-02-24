import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/data/repositories/inventory_repository.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart'
    as billing_session;
import 'package:hangout_spot/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class InventoryRemindersScreen extends ConsumerWidget {
  const InventoryRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(inventoryRemindersStreamProvider);
    final itemsAsync = ref.watch(inventoryItemsStreamProvider);

    return remindersAsync.when(
      data: (reminders) {
        return itemsAsync.when(
          data: (items) {
            return _buildList(context, ref, reminders, items);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<InventoryReminder> reminders,
    List<InventoryItem> items,
  ) {
    final dailyUpdate = reminders.firstWhere(
      (r) => r.type == 'daily_update',
      orElse: () => InventoryReminder(
        id: '',
        type: 'daily_update',
        title: '',
        time: '18:00',
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (dailyUpdate.id.isEmpty)
          _buildDailyUpdateCard(context, ref)
        else
          _buildReminderTile(context, ref, dailyUpdate, items),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
            FilledButton.icon(
              onPressed: () => _openReminderDialog(context, ref, items, null),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reminders
            .where((r) => r.type != 'daily_update')
            .map((r) => _buildDismissibleReminder(context, ref, r, items))
            .toList(),
        if (reminders.where((r) => r.type != 'daily_update').isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('No reminders added yet.'),
          ),
      ],
    );
  }

  Widget _buildDailyUpdateCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: const Text('Daily inventory update reminder'),
        subtitle: const Text('Remind before session ends'),
        trailing: FilledButton(
          onPressed: () => _createDailyUpdateReminder(context, ref),
          child: const Text('Enable'),
        ),
      ),
    );
  }

  Widget _buildDismissibleReminder(
    BuildContext context,
    WidgetRef ref,
    InventoryReminder reminder,
    List<InventoryItem> items,
  ) {
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: Colors.red.shade400),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete reminder?'),
                content: const Text(
                  'This will remove the reminder permanently.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        final repo = ref.read(inventoryRepositoryProvider);
        await repo.deleteReminder(reminder.id);
        await NotificationService.instance.cancel(_hashId(reminder.id));
      },
      child: _buildReminderTile(context, ref, reminder, items),
    );
  }

  Widget _buildReminderTile(
    BuildContext context,
    WidgetRef ref,
    InventoryReminder reminder,
    List<InventoryItem> items,
  ) {
    String? itemName;
    InventoryItem? matchedItem;
    if (reminder.itemId != null) {
      for (final item in items) {
        if (item.id == reminder.itemId) {
          itemName = item.name;
          matchedItem = item;
          break;
        }
      }
    }

    final isQuantity = reminder.type == 'quantity';
    final threshold = reminder.threshold ?? matchedItem?.minQty ?? 0;
    final currentQty = matchedItem?.currentQty;
    final isLow = isQuantity && currentQty != null && currentQty < threshold;
    final isTimeBased =
        reminder.type == 'time' || reminder.type == 'daily_update';

    return Card(
      child: ListTile(
        title: Text(reminder.title.isNotEmpty ? reminder.title : 'Reminder'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_subtitle(reminder, itemName)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(
                  reminder.isEnabled ? 'On' : 'Off',
                  reminder.isEnabled
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  reminder.isEnabled
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.grey,
                ),
                if (isTimeBased)
                  _pill(
                    'Daily ${reminder.time}',
                    Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    Theme.of(context).colorScheme.primary,
                  ),
                if (isQuantity)
                  _pill(
                    'Threshold: ${threshold.toStringAsFixed(0)} ${matchedItem?.unit ?? ''}'
                        .trim(),
                    Colors.orange.withOpacity(0.12),
                    Colors.orange.shade800,
                  ),
                if (isQuantity && currentQty != null)
                  _pill(
                    'Stock: ${currentQty.toStringAsFixed(0)} ${matchedItem?.unit ?? ''}'
                        .trim(),
                    isLow
                        ? Colors.red.withOpacity(0.14)
                        : Colors.green.withOpacity(0.14),
                    isLow ? Colors.red.shade700 : Colors.green.shade800,
                  ),
              ],
            ),
          ],
        ),
        leading: Switch(
          value: reminder.isEnabled,
          onChanged: (value) => _toggleReminder(ref, reminder, value),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _openReminderDialog(context, ref, items, reminder),
        ),
      ),
    );
  }

  String _subtitle(InventoryReminder reminder, String? itemName) {
    if (reminder.type == 'quantity') {
      final threshold = reminder.threshold ?? 0;
      return '${itemName ?? 'Item'} below $threshold';
    }
    return 'Daily at ${reminder.time}';
  }

  Widget _pill(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _toggleReminder(
    WidgetRef ref,
    InventoryReminder reminder,
    bool value,
  ) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final updated = InventoryReminder(
      id: reminder.id,
      type: reminder.type,
      title: reminder.title,
      time: reminder.time,
      itemId: reminder.itemId,
      threshold: reminder.threshold,
      isEnabled: value,
    );
    await repo.upsertReminder(updated);

    if (!value) {
      await NotificationService.instance.cancel(_hashId(reminder.id));
      return;
    }

    if (reminder.type == 'time' || reminder.type == 'daily_update') {
      final time = _parseTime(reminder.time);
      await NotificationService.instance.scheduleDaily(
        id: _hashId(reminder.id),
        title: reminder.title,
        body: 'Inventory reminder',
        time: time,
      );
    }
  }

  Future<void> _createDailyUpdateReminder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final sessionManager = ref.read(billing_session.sessionManagerProvider);
    final defaultTime = TimeOfDay(
      hour: (sessionManager.closingHour - 1) % 24,
      minute: 0,
    );

    final reminder = InventoryReminder(
      id: const Uuid().v4(),
      type: 'daily_update',
      title: 'Update inventory before session ends',
      time: _formatTime(defaultTime),
      isEnabled: true,
    );

    final repo = ref.read(inventoryRepositoryProvider);
    await repo.upsertReminder(reminder);
    await NotificationService.instance.scheduleDaily(
      id: _hashId(reminder.id),
      title: reminder.title,
      body: 'Please update today\'s inventory values.',
      time: defaultTime,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily update reminder enabled.')),
      );
    }
  }

  Future<void> _openReminderDialog(
    BuildContext context,
    WidgetRef ref,
    List<InventoryItem> items,
    InventoryReminder? reminder,
  ) async {
    final titleController = TextEditingController(text: reminder?.title ?? '');
    String type = reminder?.type ?? 'time';
    InventoryItem? selectedItem;
    if (reminder?.itemId != null) {
      for (final item in items) {
        if (item.id == reminder!.itemId) {
          selectedItem = item;
          break;
        }
      }
    }
    final thresholdController = TextEditingController(
      text: reminder?.threshold?.toString() ?? '',
    );
    TimeOfDay time = _parseTime(reminder?.time ?? '09:00');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(reminder == null ? 'Add Reminder' : 'Edit Reminder'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'time', child: Text('Time-based')),
                    DropdownMenuItem(
                      value: 'quantity',
                      child: Text('Quantity-based'),
                    ),
                  ],
                  onChanged: (value) => setState(() => type = value ?? type),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                if (type == 'quantity') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<InventoryItem>(
                    value: selectedItem,
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedItem = value),
                    decoration: const InputDecoration(labelText: 'Item'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: thresholdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Threshold'),
                  ),
                ],
                if (type == 'time') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Time: ${_formatTime(time)}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (picked != null) {
                            setState(() => time = picked);
                          }
                        },
                        child: const Text('Pick'),
                      ),
                    ],
                  ),
                ],
              ],
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

    final repo = ref.read(inventoryRepositoryProvider);
    final id = reminder?.id ?? const Uuid().v4();
    final newReminder = InventoryReminder(
      id: id,
      type: type,
      title: titleController.text.trim().isEmpty
          ? 'Reminder'
          : titleController.text.trim(),
      time: _formatTime(time),
      itemId: selectedItem?.id,
      threshold: double.tryParse(thresholdController.text.trim()),
      isEnabled: reminder?.isEnabled ?? true,
    );

    await repo.upsertReminder(newReminder);

    if (type == 'time' || type == 'daily_update') {
      await NotificationService.instance.scheduleDaily(
        id: _hashId(id),
        title: newReminder.title,
        body: 'Inventory reminder',
        time: time,
      );
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  int _hashId(String value) {
    return value.hashCode & 0x7fffffff;
  }
}
