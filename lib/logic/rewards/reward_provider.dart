import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:uuid/uuid.dart';

// Constants for reward system
const double REWARD_EARNING_RATE = 0.08; // 8% of order amount
const double REWARD_REDEMPTION_RATE = 1.0; // 1 point = 1 rupee
const String REWARD_FEATURE_TOGGLE_KEY = 'reward_system_enabled';
const String REWARD_RATE_KEY = 'reward_earning_rate';
const String REDEMPTION_RATE_KEY = 'reward_redemption_rate';

// Settings provider to get/set reward feature toggle
final rewardSettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(appDatabaseProvider);

  // Get all settings
  final settings = await (db.select(db.settings)).get();

  final settingsMap = <String, String>{};
  for (var setting in settings) {
    settingsMap[setting.key] = setting.value;
  }

  // Set defaults if not exist
  if (!settingsMap.containsKey(REWARD_FEATURE_TOGGLE_KEY)) {
    settingsMap[REWARD_FEATURE_TOGGLE_KEY] = 'true';
  }
  if (!settingsMap.containsKey(REWARD_RATE_KEY)) {
    settingsMap[REWARD_RATE_KEY] = REWARD_EARNING_RATE.toString();
  }
  if (!settingsMap.containsKey(REDEMPTION_RATE_KEY)) {
    settingsMap[REDEMPTION_RATE_KEY] = REWARD_REDEMPTION_RATE.toString();
  }

  return settingsMap;
});

// Check if reward system is enabled
final isRewardSystemEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(rewardSettingsProvider.future);
  final enabled = settings[REWARD_FEATURE_TOGGLE_KEY] ?? 'true';
  return enabled.toLowerCase() == 'true';
});

// Get customer's current reward balance
final customerRewardBalanceProvider = FutureProvider.family<double, String>((
  ref,
  customerId,
) async {
  final db = ref.watch(appDatabaseProvider);

  final transactions = await (db.select(
    db.rewardTransactions,
  )..where((tbl) => tbl.customerId.equals(customerId))).get();

  double balance = 0.0;
  for (var transaction in transactions) {
    if (transaction.type == 'earn') {
      balance += transaction.amount;
    } else if (transaction.type == 'redeem') {
      balance -= transaction.amount;
    }
  }

  return balance;
});

// Get reward transaction history for a customer
final customerRewardHistoryProvider =
    FutureProvider.family<List<RewardTransaction>, String>((
      ref,
      customerId,
    ) async {
      final db = ref.watch(appDatabaseProvider);

      return await (db.select(
        db.rewardTransactions,
      )..where((tbl) => tbl.customerId.equals(customerId))).get();
    });

// Reward provider for business logic
final rewardNotifierProvider = StateNotifierProvider<RewardNotifier, void>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return RewardNotifier(db);
});

class RewardNotifier extends StateNotifier<void> {
  final AppDatabase _db;

  RewardNotifier(this._db) : super(null);

  /// Earn reward points from an order
  Future<void> earnReward({
    required String customerId,
    required double orderAmount,
    required String orderId,
  }) async {
    // Get earning rate from settings
    final settings = await (_db.select(
      _db.settings,
    )..where((tbl) => tbl.key.equals(REWARD_RATE_KEY))).get();

    final rateStr = settings.isNotEmpty
        ? settings.first.value
        : REWARD_EARNING_RATE.toString();
    final rate = double.tryParse(rateStr) ?? REWARD_EARNING_RATE;

    // Calculate points (e.g., ₹100 order = 8 points at 8% rate)
    final pointsEarned = orderAmount * rate;

    if (pointsEarned > 0) {
      final transaction = RewardTransactionsCompanion(
        id: Value(const Uuid().v4()),
        customerId: Value(customerId),
        type: const Value('earn'),
        amount: Value(pointsEarned),
        orderId: Value(orderId),
        description: Value('Earned from order #$orderId'),
      );

      await _db.into(_db.rewardTransactions).insert(transaction);
    }
  }

  /// Redeem reward points
  Future<bool> redeemReward({
    required String customerId,
    required double pointsToRedeem,
    String? description,
  }) async {
    // Get customer's current balance
    final balance = await _getCustomerBalance(customerId);

    if (balance < pointsToRedeem) {
      return false; // Insufficient points
    }

    // Create redemption transaction
    final transaction = RewardTransactionsCompanion(
      id: Value(const Uuid().v4()),
      customerId: Value(customerId),
      type: const Value('redeem'),
      amount: Value(pointsToRedeem),
      description: Value(description ?? 'Redeemed $pointsToRedeem points'),
    );

    await _db.into(_db.rewardTransactions).insert(transaction);
    return true;
  }

  /// Adjust reward points (for admin)
  Future<void> adjustReward({
    required String customerId,
    required double amount,
    String? description,
  }) async {
    final type = amount > 0 ? 'earn' : 'adjustment';

    final transaction = RewardTransactionsCompanion(
      id: Value(const Uuid().v4()),
      customerId: Value(customerId),
      type: Value(type),
      amount: Value(amount.abs()),
      description: Value(description ?? 'Manual adjustment'),
    );

    await _db.into(_db.rewardTransactions).insert(transaction);
  }

  /// Toggle reward system on/off
  Future<void> setRewardSystemEnabled(bool enabled) async {
    final setting = SettingsCompanion(
      key: const Value(REWARD_FEATURE_TOGGLE_KEY),
      value: Value(enabled ? 'true' : 'false'),
      description: const Value('Enable/disable reward system'),
    );

    await _db.into(_db.settings).insertOnConflictUpdate(setting);
  }

  /// Update reward earning rate
  Future<void> setRewardEarningRate(double rate) async {
    final setting = SettingsCompanion(
      key: const Value(REWARD_RATE_KEY),
      value: Value(rate.toString()),
      description: const Value('Reward earning rate (percentage)'),
    );

    await _db.into(_db.settings).insertOnConflictUpdate(setting);
  }

  /// Update reward redemption rate
  Future<void> setRedemptionRate(double rate) async {
    final setting = SettingsCompanion(
      key: const Value(REDEMPTION_RATE_KEY),
      value: Value(rate.toString()),
      description: const Value('Reward redemption rate (rupees per point)'),
    );

    await _db.into(_db.settings).insertOnConflictUpdate(setting);
  }

  // Helper method to get customer balance
  Future<double> _getCustomerBalance(String customerId) async {
    final transactions = await (_db.select(
      _db.rewardTransactions,
    )..where((tbl) => tbl.customerId.equals(customerId))).get();

    double balance = 0.0;
    for (var transaction in transactions) {
      if (transaction.type == 'earn') {
        balance += transaction.amount;
      } else if (transaction.type == 'redeem') {
        balance -= transaction.amount;
      }
    }

    return balance;
  }
}
