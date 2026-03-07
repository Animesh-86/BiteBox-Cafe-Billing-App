import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class InventoryRemindersScreen extends ConsumerWidget {
  const InventoryRemindersScreen({super.key});

  static final Map<String, String> _scheduledTimes = {};
  static bool _permissionsRequested = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(inventoryRemindersStreamProvider);

    return SafeArea(
      child: remindersAsync.when(
        data: (reminders) {
          _scheduleEnabledTimeReminders(reminders);
          return _buildList(context, ref, reminders);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<InventoryReminder> reminders,
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
          _buildReminderTile(context, ref, dailyUpdate),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _sendTestNotification(context),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openReminderDialog(context, ref, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reminders
            .where((r) => r.type != 'daily_update')
            .map((r) => _buildDismissibleReminder(context, ref, r))
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
        subtitle: const Text('Scheduled daily at 1:00 AM'),
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
      onDismissed: (_) async {
        final repo = ref.read(inventoryRepositoryProvider);
        await repo.deleteReminder(reminder.id);
        await NotificationService.instance.cancel(_hashId(reminder.id));

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reminder deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await repo.upsertReminder(reminder);
                  if (reminder.isEnabled &&
                      (reminder.type == 'time' ||
                          reminder.type == 'daily_update')) {
                    final time = _parseTime(reminder.time);
                    await NotificationService.instance.scheduleDaily(
                      id: _hashId(reminder.id),
                      title: reminder.title,
                      body: 'Inventory reminder',
                      time: time,
                    );
                  }
                },
              ),
            ),
          );
        }
      },
      child: _buildReminderTile(context, ref, reminder),
    );
  }

  Widget _buildReminderTile(
    BuildContext context,
    WidgetRef ref,
    InventoryReminder reminder,
  ) {
    final isTimeBased =
        reminder.type == 'time' || reminder.type == 'daily_update';

    return Card(
      child: ListTile(
        title: Text(reminder.title.isNotEmpty ? reminder.title : 'Reminder'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_subtitle(reminder, null)),
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
          onPressed: () => _openReminderDialog(context, ref, reminder),
        ),
      ),
    );
  }

  String _subtitle(InventoryReminder reminder, String? itemName) {
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
      try {
        await _ensurePermissions();
        final time = _parseTime(reminder.time);
        await NotificationService.instance.scheduleDaily(
          id: _hashId(reminder.id),
          title: reminder.title,
          body: 'Inventory reminder',
          time: time,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to schedule reminder toggle: $e');
      }
    }
  }

  Future<void> _createDailyUpdateReminder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    const defaultTime = TimeOfDay(hour: 1, minute: 0);

    final reminder = InventoryReminder(
      id: const Uuid().v4(),
      type: 'daily_update',
      title: 'Update inventory before session ends',
      time: _formatTime(defaultTime),
      isEnabled: true,
    );

    final repo = ref.read(inventoryRepositoryProvider);
    await repo.upsertReminder(reminder);
    try {
      await _ensurePermissions(context: context);
      await NotificationService.instance.scheduleDaily(
        id: _hashId(reminder.id),
        title: reminder.title,
        body: 'Please update today\'s inventory values.',
        time: defaultTime,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to schedule daily update: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily update reminder enabled.')),
      );
    }
  }

  Future<void> _scheduleEnabledTimeReminders(
    List<InventoryReminder> reminders,
  ) async {
    try {
      final timeReminders = reminders.where(
        (r) => r.isEnabled && (r.type == 'time' || r.type == 'daily_update'),
      );

      await _ensurePermissions();

      for (final reminder in timeReminders) {
        final key = '${reminder.id}_${reminder.time}';
        if (_scheduledTimes[reminder.id] == key) continue;

        final time = _parseTime(reminder.time);
        await NotificationService.instance.scheduleDaily(
          id: _hashId(reminder.id),
          title: reminder.title,
          body: reminder.type == 'daily_update'
              ? "Please update today's inventory values."
              : 'Inventory reminder',
          time: time,
        );

        _scheduledTimes[reminder.id] = key;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to schedule reminders: $e');
    }
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    try {
      await _ensurePermissions(context: context);

      // Show an immediate notification to verify the channel works
      final testId = _hashId('test_${DateTime.now().millisecondsSinceEpoch}');
      await NotificationService.instance.showNow(
        id: testId,
        title: 'Test notification',
        body: 'If you see this, notifications are working!',
      );

      // Also schedule one via zonedSchedule to test the alarm path
      try {
        await NotificationService.instance.scheduleTest(
          id: testId + 1,
          title: 'Scheduled test',
          body: 'This fired via zonedSchedule - reminders will work!',
          seconds: 15,
        );
      } catch (e) {
        debugPrint('⚠️ scheduleTest failed: $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instant notification sent + scheduled one in ~15s'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Test notification failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openReminderDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryReminder? reminder,
  ) async {
    final titleController = TextEditingController(text: reminder?.title ?? '');
    TimeOfDay time = _parseTime(reminder?.time ?? '09:00');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(reminder == null ? 'Add Reminder' : 'Edit Reminder'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
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
      type: 'time',
      title: titleController.text.trim().isEmpty
          ? 'Reminder'
          : titleController.text.trim(),
      time: _formatTime(time),
      isEnabled: reminder?.isEnabled ?? true,
    );

    await repo.upsertReminder(newReminder);

    try {
      await _ensurePermissions(context: context);
      await NotificationService.instance.scheduleDaily(
        id: _hashId(id),
        title: newReminder.title,
        body: 'Inventory reminder',
        time: time,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to schedule reminder: $e');
    }
  }

  Future<bool> _ensurePermissions({BuildContext? context}) async {
    if (_permissionsRequested) return true;
    _permissionsRequested = true;
    try {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission denied. Reminders won\'t work. '
              'Please enable notifications in Settings.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return granted;
    } catch (e) {
      debugPrint('⚠️ Permission request failed: $e');
      return false;
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
