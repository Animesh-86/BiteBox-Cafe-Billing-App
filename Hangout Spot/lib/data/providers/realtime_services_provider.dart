import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/services/live_analytics_service.dart';
import 'package:hangout_spot/services/live_invoice_counter_service.dart';
import 'package:hangout_spot/services/shared_cart_service.dart';

/// Providers for Firebase Realtime Database services

/// Live Analytics Service Provider
final liveAnalyticsServiceProvider = Provider<LiveAnalyticsService>((ref) {
  return LiveAnalyticsService();
});

/// Live Invoice Counter Service Provider
final liveInvoiceCounterServiceProvider = Provider<LiveInvoiceCounterService>((
  ref,
) {
  return LiveInvoiceCounterService();
});

/// Shared Cart Service Provider
final sharedCartServiceProvider = Provider<SharedCartService>((ref) {
  return SharedCartService();
});

/// Stream provider for today's revenue (live)
final liveRevenueProvider = StreamProvider<double>((ref) {
  final service = ref.watch(liveAnalyticsServiceProvider);
  return service.watchTodayRevenue();
});

/// Stream provider for today's order count (live)
final liveOrderCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(liveAnalyticsServiceProvider);
  return service.watchTodayOrderCount();
});

/// Stream provider for today's item count (live)
final liveItemCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(liveAnalyticsServiceProvider);
  return service.watchTodayItemCount();
});

/// Stream provider for hourly revenue chart data
final liveHourlyRevenueProvider = StreamProvider<Map<int, double>>((ref) {
  final service = ref.watch(liveAnalyticsServiceProvider);
  return service.watchTodayHourlyRevenue();
});

/// Stream provider for payment breakdown
final livePaymentBreakdownProvider = StreamProvider<Map<String, double>>((ref) {
  final service = ref.watch(liveAnalyticsServiceProvider);
  return service.watchTodayPaymentBreakdown();
});

/// Stream provider for average order value (live)
final liveAverageOrderValueProvider = StreamProvider<double>((ref) {
  final service = ref.watch(liveAnalyticsServiceProvider);
  return service.watchAverageOrderValue();
});

/// Stream provider for active shared carts
final activeSharedCartsProvider = StreamProvider<List<SharedCart>>((ref) {
  final service = ref.watch(sharedCartServiceProvider);
  return service.watchActiveCarts();
});
