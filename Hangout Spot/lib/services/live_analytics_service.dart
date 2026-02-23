import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';

/// Real-time analytics service using Firebase Realtime Database
/// Provides instant updates for live dashboards and counters
class LiveAnalyticsService {
  final DatabaseReference _database;
  final FirebaseAuth _auth;

  LiveAnalyticsService({DatabaseReference? database, FirebaseAuth? auth})
    : _database = database ?? FirebaseDatabase.instance.ref(),
      _auth = auth ?? FirebaseAuth.instance;

  /// Get reference to user's analytics node
  DatabaseReference? _getUserAnalyticsRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _database.child('analytics').child(user.uid);
  }

  /// Record a sale in real-time counters
  Future<void> recordSale(Order order, {int itemCount = 0}) async {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) {
      debugPrint('⚠️ Cannot record sale: User not logged in');
      return;
    }

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final hour = DateTime.now().hour;
      final yearMonth = DateFormat('yyyy-MM').format(DateTime.now());

      // Use atomic increments to avoid race conditions
      final dailyRef = analyticsRef.child('daily').child(today);
      final hourlyRef = dailyRef.child('hours').child(hour.toString());
      final monthlyRef = analyticsRef.child('monthly').child(yearMonth);

      await Future.wait([
        // Daily totals
        dailyRef.child('revenue').set(ServerValue.increment(order.totalAmount)),
        dailyRef.child('orderCount').set(ServerValue.increment(1)),
        // Increment item count
        if (itemCount > 0)
          dailyRef.child('itemCount').set(ServerValue.increment(itemCount))
        else
          dailyRef.child('itemCount').set(ServerValue.increment(0)),
        dailyRef.child('lastUpdated').set(ServerValue.timestamp),

        // Hourly breakdown
        hourlyRef
            .child('revenue')
            .set(ServerValue.increment(order.totalAmount)),
        hourlyRef.child('count').set(ServerValue.increment(1)),

        // Monthly totals
        monthlyRef
            .child('revenue')
            .set(ServerValue.increment(order.totalAmount)),
        monthlyRef.child('orderCount').set(ServerValue.increment(1)),
        monthlyRef.child('lastUpdated').set(ServerValue.timestamp),

        // Payment mode breakdown
        dailyRef
            .child('payments')
            .child(order.paymentMode)
            .set(ServerValue.increment(order.totalAmount)),

        // Update latest order info
        dailyRef.child('latestOrder').set({
          'invoiceNumber': order.invoiceNumber,
          'amount': order.totalAmount,
          'timestamp': ServerValue.timestamp,
        }),
      ]);

      debugPrint(
        '✅ Live analytics updated: ${order.invoiceNumber} (Items: $itemCount)',
      );
    } catch (e) {
      debugPrint('❌ Failed to update live analytics: $e');
    }
  }

  /// Stream today's revenue (updates in real-time)
  Stream<double> watchTodayRevenue() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value(0.0);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef
        .child('daily')
        .child(today)
        .child('revenue')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          return 0.0;
        });
  }

  /// Stream today's order count
  Stream<int> watchTodayOrderCount() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value(0);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef
        .child('daily')
        .child(today)
        .child('orderCount')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value == null) return 0;
          if (value is num) return value.toInt();
          return 0;
        });
  }

  /// Stream today's item count
  Stream<int> watchTodayItemCount() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value(0);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef
        .child('daily')
        .child(today)
        .child('itemCount')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value == null) return 0;
          if (value is num) return value.toInt();
          return 0;
        });
  }

  /// Stream hourly data for today (for charts)
  Stream<Map<int, double>> watchTodayHourlyRevenue() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value({});

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef.child('daily').child(today).child('hours').onValue.map((
      event,
    ) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <int, double>{};

      final Map<int, double> hourlyData = {};
      data.forEach((key, value) {
        final hour = int.tryParse(key.toString());
        if (hour != null && value is Map) {
          final revenue = value['revenue'];
          if (revenue is num) {
            hourlyData[hour] = revenue.toDouble();
          }
        }
      });

      return hourlyData;
    });
  }

  /// Stream payment mode breakdown for today
  Stream<Map<String, double>> watchTodayPaymentBreakdown() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value({});

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef
        .child('daily')
        .child(today)
        .child('payments')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null || data is! Map) return <String, double>{};

          final Map<String, double> payments = {};
          data.forEach((key, value) {
            if (value is num) {
              payments[key.toString()] = value.toDouble();
            }
          });

          return payments;
        });
  }

  /// Get latest order update (for notifications)
  Stream<Map<String, dynamic>?> watchLatestOrder() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value(null);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef
        .child('daily')
        .child(today)
        .child('latestOrder')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null || data is! Map) return null;

          return {
            'invoiceNumber': data['invoiceNumber'],
            'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
            'timestamp': data['timestamp'],
          };
        });
  }

  /// Reset daily counters (call at midnight or for testing)
  Future<void> resetDailyCounters({String? date}) async {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return;

    final targetDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await analyticsRef.child('daily').child(targetDate).remove();
      debugPrint('✅ Reset daily counters for $targetDate');
    } catch (e) {
      debugPrint('❌ Failed to reset counters: $e');
    }
  }

  /// Get current snapshot of today's data (one-time read)
  Future<Map<String, dynamic>> getTodaySnapshot() async {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return {};

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final snapshot = await analyticsRef.child('daily').child(today).get();

      if (!snapshot.exists) return {};

      final data = snapshot.value as Map?;
      if (data == null) return {};

      return {
        'revenue': (data['revenue'] as num?)?.toDouble() ?? 0.0,
        'orderCount': (data['orderCount'] as num?)?.toInt() ?? 0,
        'itemCount': (data['itemCount'] as num?)?.toInt() ?? 0,
        'lastUpdated': data['lastUpdated'],
      };
    } catch (e) {
      debugPrint('❌ Failed to get today snapshot: $e');
      return {};
    }
  }

  /// Calculate average order value (real-time)
  Stream<double> watchAverageOrderValue() {
    final analyticsRef = _getUserAnalyticsRef();
    if (analyticsRef == null) return Stream.value(0.0);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return analyticsRef.child('daily').child(today).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return 0.0;

      final revenue = (data['revenue'] as num?)?.toDouble() ?? 0.0;
      final orderCount = (data['orderCount'] as num?)?.toInt() ?? 0;

      if (orderCount == 0) return 0.0;
      return revenue / orderCount;
    });
  }

  /// Dispose/cleanup (if needed)
  void dispose() {
    // Firebase Realtime Database handles cleanup automatically
  }
}
