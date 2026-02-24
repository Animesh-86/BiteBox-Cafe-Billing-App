import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/data/repositories/inventory_repository.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart'
    as billing_session;

class DailyTrackerScreen extends ConsumerStatefulWidget {
  const DailyTrackerScreen({super.key});

  @override
  ConsumerState<DailyTrackerScreen> createState() => _DailyTrackerScreenState();
}

class _DailyTrackerScreenState extends ConsumerState<DailyTrackerScreen> {
  DateTime? _selectedDate;
  final Map<String, TextEditingController> _controllers = {};
  String? _lastDateId;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final sessionManager = ref.read(billing_session.sessionManagerProvider);
    final initialDate = _selectedDate ?? sessionManager.getCurrentSessionDate();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionManager = ref.watch(billing_session.sessionManagerProvider);
    final date = _selectedDate ?? sessionManager.getCurrentSessionDate();
    final dateId = _dateId(date);
    if (_lastDateId != dateId) {
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _lastDateId = dateId;
    }
    final itemsAsync = ref.watch(inventoryItemsStreamProvider);
    final dailyAsync = ref.watch(dailyInventoryStreamProvider(date));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Date: ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Change'),
              ),
            ],
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              return dailyAsync.when(
                data: (daily) {
                  return _buildList(context, items, daily);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _saveDaily(date),
              child: const Text('Save Daily Tracker'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    List<InventoryItem> items,
    DailyInventory? daily,
  ) {
    final map = daily?.items ?? {};

    for (final item in items) {
      _controllers.putIfAbsent(
        item.id,
        () => TextEditingController(text: map[item.id]?.toString() ?? ''),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final controller = _controllers[item.id]!;

        return Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: item.unit,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDaily(DateTime date) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final values = <String, double>{};

    for (final entry in _controllers.entries) {
      final value = double.tryParse(entry.value.text.trim());
      if (value != null) {
        values[entry.key] = value;
      }
    }

    final daily = DailyInventory(id: _dateId(date), date: date, items: values);

    await repo.upsertDaily(daily);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Daily tracker saved.')));
    }
  }

  String _dateId(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
