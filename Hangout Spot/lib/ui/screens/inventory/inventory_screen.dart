import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/services/notification_service.dart';
import 'package:hangout_spot/main.dart';
import 'tabs/inventory_items_screen.dart';
import 'tabs/inventory_reminders_screen.dart';
import 'tabs/platform_orders_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure default beverage inventory exists for cold drinks and water
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryRepositoryProvider).ensureDefaultBeverageInventory();
    });
  }

  Future<void> _handleLowStockNotificationsFromAsyncValue(
    AsyncValue<List<InventoryItem>> itemsAsyncValue,
    AsyncValue<List<InventoryReminder>> remindersAsyncValue,
  ) async {
    final items = itemsAsyncValue.valueOrNull ?? [];
    final reminders = remindersAsyncValue.valueOrNull ?? [];

    if (items.isEmpty || reminders.isEmpty) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final todayKey = _dateKey(DateTime.now());
    final enabledReminders = reminders
        .where((r) => r.type == 'quantity' && r.isEnabled)
        .toList();
    if (enabledReminders.isEmpty) return;

    for (final reminder in enabledReminders) {
      if (reminder.itemId == null) continue;
      final item = items
          .where((i) => i.id == reminder.itemId)
          .cast<InventoryItem?>()
          .firstWhere((i) => i != null, orElse: () => null);
      if (item == null) continue;

      final threshold = reminder.threshold ?? item.minQty;
      if (item.currentQty >= threshold) continue;

      final key = 'low_stock_${item.id}_$todayKey';
      if (prefs.getBool(key) == true) continue;

      await NotificationService.instance.showNow(
        id: _hashId('low_${item.id}'),
        title: 'Low stock: ${item.name}',
        body: 'Only ${item.currentQty} ${item.unit} left.',
      );
      await prefs.setBool(key, true);
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _hashId(String value) {
    return value.hashCode & 0x7fffffff;
  }

  // stat pill helper removed

  @override
  Widget build(BuildContext context) {
    // Watch the streams to handle low stock notifications
    final itemsAsyncValue = ref.watch(inventoryItemsStreamProvider);
    final remindersAsyncValue = ref.watch(inventoryRemindersStreamProvider);

    if (itemsAsyncValue.hasValue && remindersAsyncValue.hasValue) {
      _handleLowStockNotificationsFromAsyncValue(
        itemsAsyncValue,
        remindersAsyncValue,
      );
    }

    // Set up listeners for low stock notifications
    ref.listen(inventoryItemsStreamProvider, (previous, next) {
      _handleLowStockNotificationsFromAsyncValue(
        next,
        ref.read(inventoryRemindersStreamProvider),
      );
    });

    ref.listen(inventoryRemindersStreamProvider, (previous, next) {
      _handleLowStockNotificationsFromAsyncValue(
        ref.read(inventoryItemsStreamProvider),
        next,
      );
    });

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(170),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topPad = MediaQuery.paddingOf(context).top;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: AppBar(
                      toolbarHeight: 0,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      flexibleSpace: Container(
                        padding: EdgeInsets.fromLTRB(18, topPad + 12, 18, 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.18),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Inventory',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Track stock, alerts, and platform orders',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 56,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.24),
                                ),
                              ),
                              child: TabBar(
                                labelColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                unselectedLabelColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.75),
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                                indicator: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                indicatorPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                tabs: const [
                                  Tab(text: 'Inventory'),
                                  Tab(text: 'Reminders'),
                                  Tab(text: 'Orders'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              InventoryItemsScreen(),
              InventoryRemindersScreen(),
              PlatformOrdersScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
