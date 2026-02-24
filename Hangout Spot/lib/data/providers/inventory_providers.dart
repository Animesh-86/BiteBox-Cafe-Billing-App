import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/inventory_models.dart';
import 'package:hangout_spot/data/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final inventoryItemsStreamProvider = StreamProvider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchItems();
});

final inventoryRemindersStreamProvider =
    StreamProvider<List<InventoryReminder>>((ref) {
      return ref.watch(inventoryRepositoryProvider).watchReminders();
    });

final dailyInventoryStreamProvider =
    StreamProvider.family<DailyInventory?, DateTime>((ref, date) {
      return ref.watch(inventoryRepositoryProvider).watchDaily(date);
    });

final inventoryAnalyticsProvider =
    FutureProvider.family<
      InventoryAnalyticsSummary,
      ({DateTime startDate, DateTime endDate})
    >((ref, range) {
      return ref
          .watch(inventoryRepositoryProvider)
          .loadInventoryAnalytics(
            startDate: range.startDate,
            endDate: range.endDate,
          );
    });
