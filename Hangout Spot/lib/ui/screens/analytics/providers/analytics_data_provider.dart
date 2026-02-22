import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/analytics_repository.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/logic/billing/session_provider.dart';

// Data Models
class AnalyticsData {
  // Overview metrics
  final double totalSales;
  final int totalOrders;
  final int totalItemsSold;
  final int totalCustomers;
  final double salesChange;
  final double ordersChange;
  final double itemsSoldChange;
  final double customersChange;
  final String smartBrief;

  // Daily sales for chart
  final List<DailySales> dailySales;

  // Item share data
  final List<ItemShare> itemShare;

  // Hourly data
  final List<HourlyData> hourlyOrders;

  // Day of week data
  final List<DayOfWeekData> dayOfWeekOrders;

  // Forecast data
  final List<ItemForecast> itemForecast;
  final List<BundleSuggestion> bundleSuggestions;

  // BCG Matrix data
  final List<BCGMatrixItem> bcgMatrix;

  // Revenue leakage
  final double discountsGiven;
  final int discountedOrdersCount;
  final int walkInGuests;

  // Loyalty data
  final int newCustomers;
  final int returningCustomers;
  final List<AtRiskCustomer> atRiskCustomers;

  // NEW: Payment method data
  final List<Map<String, dynamic>>? paymentMethodDistribution;

  // NEW: Category performance
  final List<CategoryPerformance> categoryPerformance;

  // NEW: Monthly sales
  final List<MonthlySales> monthlySales;

  // NEW: Customer frequency segments
  final List<Map<String, dynamic>>? customerFrequencySegments;

  // NEW: AOV data
  final double averageOrderValue;
  final double aovChange;

  // NEW: Day of week sales (enhanced with amounts)
  final List<DayOfWeekSales> dayOfWeekSales;

  // NEW: Discount effectiveness
  final DiscountEffectiveness discountEffectiveness;

  // NEW: Peak hours by day of week
  final List<PeakHourByDay> peakHoursByDay;

  // NEW: Today's peak hour forecast
  final TodayPeakForecast? todayPeakForecast;

  AnalyticsData({
    required this.totalSales,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.totalCustomers,
    required this.salesChange,
    required this.ordersChange,
    required this.itemsSoldChange,
    required this.customersChange,
    required this.smartBrief,
    required this.dailySales,
    required this.itemShare,
    required this.hourlyOrders,
    required this.dayOfWeekOrders,
    required this.itemForecast,
    required this.bundleSuggestions,
    required this.bcgMatrix,
    required this.discountsGiven,
    required this.discountedOrdersCount,
    required this.walkInGuests,
    required this.newCustomers,
    required this.returningCustomers,
    required this.atRiskCustomers,
    required this.paymentMethodDistribution,
    required this.categoryPerformance,
    required this.monthlySales,
    required this.customerFrequencySegments,
    required this.averageOrderValue,
    required this.aovChange,
    required this.dayOfWeekSales,
    required this.discountEffectiveness,
    required this.peakHoursByDay,
    this.todayPeakForecast,
  });
}

class DailySales {
  final DateTime date;
  final double amount;

  DailySales({required this.date, required this.amount});
}

class ItemShare {
  final String itemName;
  final int quantity;

  ItemShare({required this.itemName, required this.quantity});
}

class HourlyData {
  final int hour;
  final int count;

  HourlyData({required this.hour, required this.count});
}

class DayOfWeekData {
  final int dayOfWeek; // 0 = Monday, 6 = Sunday
  final int count;

  DayOfWeekData({required this.dayOfWeek, required this.count});
}

class ItemForecast {
  final String itemName;
  final double expectedQuantity;

  ItemForecast({required this.itemName, required this.expectedQuantity});
}

class BundleSuggestion {
  final String item1;
  final String item2;
  final int count;

  BundleSuggestion({
    required this.item1,
    required this.item2,
    required this.count,
  });
}

class BCGMatrixItem {
  final String itemName;
  final double revenue;
  final int volume;

  BCGMatrixItem({
    required this.itemName,
    required this.revenue,
    required this.volume,
  });
}

class AtRiskCustomer {
  final String name;
  final DateTime lastVisit;

  AtRiskCustomer({required this.name, required this.lastVisit});
}

class CategoryPerformance {
  final String category;
  final int quantity;
  final double revenue;

  CategoryPerformance({
    required this.category,
    required this.quantity,
    required this.revenue,
  });
}

class MonthlySales {
  final String month;
  final double amount;

  MonthlySales({required this.month, required this.amount});
}

class DayOfWeekSales {
  final int dayOfWeek; // 0 = Monday, 6 = Sunday
  final double amount;
  final int count;

  DayOfWeekSales({
    required this.dayOfWeek,
    required this.amount,
    this.count = 0,
  });
}

class DiscountEffectiveness {
  final int ordersWithDiscount;
  final double revenueWithDiscount;
  final double totalDiscountAmount;
  final int ordersWithoutDiscount;
  final double revenueWithoutDiscount;

  DiscountEffectiveness({
    required this.ordersWithDiscount,
    required this.revenueWithDiscount,
    required this.totalDiscountAmount,
    required this.ordersWithoutDiscount,
    required this.revenueWithoutDiscount,
  });
}

class PeakHourByDay {
  final String dayName; // Monday, Tuesday, etc.
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final int peakHour; // 0-23
  final int orderCount;

  PeakHourByDay({
    required this.dayName,
    required this.dayOfWeek,
    required this.peakHour,
    required this.orderCount,
  });
}

class TodayPeakForecast {
  final int expectedPeakHour; // 0-23
  final String formattedTime; // "7:00 PM"
  final int historicalOrderCount;
  final String dayName; // "Sunday"

  TodayPeakForecast({
    required this.expectedPeakHour,
    required this.formattedTime,
    required this.historicalOrderCount,
    required this.dayName,
  });
}

// State provider specifically isolated for the Analytics dashboards,
// allowing "All Outlets" selection without affecting the global active POS outlet
final analyticsSelectedOutletProvider = StateProvider<Location?>((ref) => null);

// Provider
final analyticsDataProvider =
    FutureProvider.family<
      AnalyticsData,
      ({DateTime startDate, DateTime endDate, String? filterName})
    >((ref, params) async {
      final db = ref.watch(appDatabaseProvider);
      final repository = AnalyticsRepository(db);
      final sessionManager = ref.watch(sessionManagerProvider);

      // Get active analytics outlet
      final activeOutlet = ref.watch(analyticsSelectedOutletProvider);
      final locationId = activeOutlet?.id;

      // Smart shift-aware date bounds calculation
      DateTime startDate = params.startDate;
      DateTime endDate = params.endDate;

      if (params.filterName == 'Today' || params.filterName == 'Yesterday') {
        final referenceDate = params.filterName == 'Today'
            ? DateTime.now()
            : DateTime.now().subtract(const Duration(days: 1));

        startDate = DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
          sessionManager.openingHour,
        );

        if (sessionManager.closingHour <= sessionManager.openingHour) {
          endDate = DateTime(
            referenceDate.year,
            referenceDate.month,
            referenceDate.day,
            sessionManager.closingHour,
          ).add(const Duration(days: 1));
        } else {
          endDate = DateTime(
            referenceDate.year,
            referenceDate.month,
            referenceDate.day,
            sessionManager.closingHour,
          );
        }
      } else if (params.filterName == 'Custom Range') {
        // Push the end date to the end of the day to capture the whole day
        endDate = DateTime(
          params.endDate.year,
          params.endDate.month,
          params.endDate.day,
          23,
          59,
          59,
        );
      } else {
        // For 'This Week', 'This Month', etc., just let the end boundary be the current moment
        // We do not artificially add +1 day anymore to prevent bleeding into tomorrow
      }

      final daysDiff = endDate.difference(startDate).inDays;
      final previousStart = startDate.subtract(
        Duration(days: daysDiff == 0 ? 1 : daysDiff),
      );
      final previousEnd = startDate;

      // Fetch current period data
      final totalSales = await repository.getSessionSales(
        startDate,
        endDate,
        locationId: locationId,
      );
      final totalOrders = await repository.getSessionOrdersCount(
        startDate,
        endDate,
        locationId: locationId,
      );
      final totalItemsSold = await repository.getSessionItemsSold(
        startDate,
        endDate,
        locationId: locationId,
      );
      final totalCustomers = await repository.getSessionUniqueCustomersCount(
        startDate,
        endDate,
        locationId: locationId,
      );

      // Fetch previous period data for comparison
      final previousSales = await repository.getSessionSales(
        previousStart,
        previousEnd,
        locationId: locationId,
      );
      final previousOrders = await repository.getSessionOrdersCount(
        previousStart,
        previousEnd,
        locationId: locationId,
      );
      final previousItemsSold = await repository.getSessionItemsSold(
        previousStart,
        previousEnd,
        locationId: locationId,
      );
      final previousCustomers = await repository.getSessionUniqueCustomersCount(
        previousStart,
        previousEnd,
        locationId: locationId,
      );

      // Fetch AOV
      final currentAOV = await repository.getAverageOrderValue(
        startDate,
        endDate,
        locationId: locationId,
      );
      final previousAOV = await repository.getAverageOrderValue(
        previousStart,
        previousEnd,
        locationId: locationId,
      );

      // Calculate changes
      final salesChange = _calculateChange(totalSales, previousSales);
      final ordersChange = _calculateChange(
        totalOrders.toDouble(),
        previousOrders.toDouble(),
      );
      final itemsSoldChange = _calculateChange(
        totalItemsSold.toDouble(),
        previousItemsSold.toDouble(),
      );
      final customersChange = _calculateChange(
        totalCustomers.toDouble(),
        previousCustomers.toDouble(),
      );
      final aovChange = _calculateChange(currentAOV, previousAOV);

      // Fetch detailed data
      final dailySalesRaw = await repository.getDailySales(
        startDate,
        endDate,
        locationId: locationId,
      );
      final topItemsRaw = await repository.getTopSellingItemsSince(
        startDate,
        endDate,
        limit: 20,
        locationId: locationId,
      );
      final hourlyDataRaw = await repository.getPeakHours(
        startDate,
        endDate,
        locationId: locationId,
      );
      final dayOfWeekDataRaw = await repository.getOrdersByWeekday(
        startDate,
        endDate,
        locationId: locationId,
      );
      final combosRaw = await repository.getTopBundles(
        startDate,
        endDate,
        limit: 10,
        locationId: locationId,
      );
      final revenueLeakage = await repository.getRevenueLeakage(
        startDate,
        endDate,
        locationId: locationId,
      );
      final bcgDataRaw = await repository.getItemBcgData(
        startDate,
        endDate,
        locationId: locationId,
      );
      final customerSegments = await repository.getCustomerSegments(
        startDate,
        endDate,
        locationId: locationId,
      );
      final atRiskRaw = await repository.getAtRiskCustomers(
        minVisits: 2,
        lastSeenDays: 30,
      );

      // NEW: Fetch payment method data
      final paymentMethodDist = await repository.getPaymentMethodDistribution(
        startDate,
        endDate,
        locationId: locationId,
      );

      // NEW: Fetch category performance
      final categoryPerfRaw = await repository.getCategoryPerformance(
        startDate,
        endDate,
        locationId: locationId,
      );

      // NEW: Fetch monthly sales
      final monthlySalesRaw = await repository.getMonthlySales(
        locationId: locationId,
        months: 12,
      );

      // NEW: Fetch customer frequency segments
      final freqSegments = await repository.getCustomerFrequencySegments(
        startDate,
        endDate,
        locationId: locationId,
      );

      // NEW: Fetch day of week sales with amounts
      final dayOfWeekSalesRaw = await repository.getDayOfWeekSales(
        startDate,
        endDate,
        locationId: locationId,
      );

      // NEW: Fetch discount effectiveness
      final discEffRaw = await repository.getDiscountEffectivenessData(
        startDate,
        endDate,
        locationId: locationId,
      );

      // Generate smart brief
      final avgDailySales = totalSales / daysDiff;
      final smartBrief = _generateSmartBrief(
        totalSales,
        avgDailySales,
        totalOrders,
        salesChange,
      );

      // Calculate forecast (weighted moving average)
      final forecast = _calculateForecast(topItemsRaw);

      // Build BCG Matrix
      final bcgMatrix = bcgDataRaw.map((item) {
        return BCGMatrixItem(
          itemName: item['name'] as String? ?? 'Unknown',
          revenue: item['revenue'] as double? ?? 0.0,
          volume: (item['qty'] as double? ?? 0.0).toInt(),
        );
      }).toList();

      // Process hourly data
      final hourlyOrders = hourlyDataRaw
          .map((h) => HourlyData(hour: h.key, count: h.value.toInt()))
          .toList();

      // Build item share list
      final itemShare = topItemsRaw
          .map((i) => ItemShare(itemName: i.key, quantity: i.value.toInt()))
          .toList();

      // Process category performance
      final categoryPerformance = categoryPerfRaw
          .map(
            (c) => CategoryPerformance(
              category: c['category'] as String? ?? 'Unknown',
              quantity: c['quantity'] as int? ?? 0,
              revenue: c['revenue'] as double? ?? 0.0,
            ),
          )
          .toList();

      // Process monthly sales
      final monthlySales = monthlySalesRaw
          .map((m) => MonthlySales(month: m.key, amount: m.value))
          .toList();

      // Process day of week sales
      final dayOfWeekSales = dayOfWeekSalesRaw
          .map((d) => DayOfWeekSales(dayOfWeek: d.key, amount: d.value))
          .toList();

      // Process discount effectiveness
      final discountEffectiveness = DiscountEffectiveness(
        ordersWithDiscount: discEffRaw['ordersWithDiscount'] as int,
        revenueWithDiscount: discEffRaw['revenueWithDiscount'] as double,
        totalDiscountAmount: discEffRaw['totalDiscountAmount'] as double,
        ordersWithoutDiscount: discEffRaw['ordersWithoutDiscount'] as int,
        revenueWithoutDiscount: discEffRaw['revenueWithoutDiscount'] as double,
      );

      // Process customer frequency segments into list format for UI
      final frequencySegmentsList = [
        {'segment': 'VIP', 'count': freqSegments['vip'] ?? 0},
        {'segment': 'Regular', 'count': freqSegments['regular'] ?? 0},
        {'segment': 'Occasional', 'count': freqSegments['occasional'] ?? 0},
        {'segment': 'One-time', 'count': freqSegments['oneTime'] ?? 0},
      ];

      // Fetch peak hours by day of week
      final peakHoursByDayRaw = await repository.getPeakHoursByDayOfWeek(
        locationId: locationId,
      );

      // Process peak hours by day
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final peakHoursByDay = <PeakHourByDay>[];

      for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
        final hourData = peakHoursByDayRaw[dayOfWeek];
        if (hourData != null && hourData.isNotEmpty) {
          // Find peak hour for this day
          final peakEntry = hourData.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          peakHoursByDay.add(
            PeakHourByDay(
              dayName: dayNames[dayOfWeek - 1],
              dayOfWeek: dayOfWeek,
              peakHour: peakEntry.key,
              orderCount: peakEntry.value,
            ),
          );
        }
      }

      // Fetch today's peak forecast
      final todayPeakData = await repository.getTodayPeakForecast(
        locationId: locationId,
      );

      TodayPeakForecast? todayPeakForecast;
      if (todayPeakData != null) {
        todayPeakForecast = TodayPeakForecast(
          expectedPeakHour: todayPeakData['expectedPeakHour'] as int,
          formattedTime: todayPeakData['formattedTime'] as String,
          historicalOrderCount: todayPeakData['historicalOrderCount'] as int,
          dayName: todayPeakData['dayName'] as String,
        );
      }

      return AnalyticsData(
        totalSales: totalSales,
        totalOrders: totalOrders,
        totalItemsSold: totalItemsSold,
        totalCustomers: totalCustomers,
        salesChange: salesChange,
        ordersChange: ordersChange,
        itemsSoldChange: itemsSoldChange,
        customersChange: customersChange,
        smartBrief: smartBrief,
        dailySales: dailySalesRaw
            .map((d) => DailySales(date: d.key, amount: d.value))
            .toList(),
        itemShare: itemShare,
        hourlyOrders: hourlyOrders,
        dayOfWeekOrders: _buildDayOfWeekData(dayOfWeekDataRaw),
        itemForecast: forecast,
        bundleSuggestions: combosRaw.map((c) {
          final parts = c.key.split(' + ');
          return BundleSuggestion(
            item1: parts.isNotEmpty ? parts[0] : c.key,
            item2: parts.length > 1 ? parts[1] : '',
            count: c.value.toInt(),
          );
        }).toList(),
        bcgMatrix: bcgMatrix,
        discountsGiven: revenueLeakage['totalDiscount'] as double,
        discountedOrdersCount: revenueLeakage['discountedOrders'] as int,
        walkInGuests: revenueLeakage['walkInOrders'] as int,
        newCustomers: customerSegments['new'] ?? 0,
        returningCustomers: customerSegments['returning'] ?? 0,
        atRiskCustomers: atRiskRaw
            .map(
              (c) => AtRiskCustomer(
                name: c['name'] as String? ?? 'Unknown',
                lastVisit: c['lastVisit'] as DateTime? ?? DateTime.now(),
              ),
            )
            .toList(),
        paymentMethodDistribution: paymentMethodDist,
        categoryPerformance: categoryPerformance,
        monthlySales: monthlySales,
        customerFrequencySegments: frequencySegmentsList,
        averageOrderValue: currentAOV,
        aovChange: aovChange,
        dayOfWeekSales: dayOfWeekSales,
        discountEffectiveness: discountEffectiveness,
        peakHoursByDay: peakHoursByDay,
        todayPeakForecast: todayPeakForecast,
      );
    });

double _calculateChange(double current, double previous) {
  if (previous == 0) return current > 0 ? 100.0 : 0.0;
  return ((current - previous) / previous) * 100;
}

String _generateSmartBrief(
  double totalSales,
  double avgDailySales,
  int totalOrders,
  double salesChange,
) {
  final changeDirection = salesChange >= 0 ? 'up' : 'down';
  final changeAmount = salesChange.abs().toStringAsFixed(1);

  return 'Your sales are $changeDirection $changeAmount% compared to the previous period. '
      'Average daily sales: ₹${avgDailySales.toStringAsFixed(0)}. '
      'Total orders processed: $totalOrders. '
      '${salesChange >= 0 ? "Great work! Keep up the momentum." : "Consider reviewing your menu or promotions."}';
}

List<ItemForecast> _calculateForecast(List<MapEntry<String, double>> items) {
  // Simple forecast: use average from period
  return items.take(10).map((item) {
    final avgPerDay = item.value / 7.0; // Assuming 7-day period
    return ItemForecast(itemName: item.key, expectedQuantity: avgPerDay);
  }).toList();
}

List<DayOfWeekData> _buildDayOfWeekData(List<MapEntry<int, double>> data) {
  return data.map((item) {
    return DayOfWeekData(dayOfWeek: item.key, count: item.value.toInt());
  }).toList();
}
