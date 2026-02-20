import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/ui/screens/analytics/services/analytics_export_service.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class OverviewScreen extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const OverviewScreen({super.key, required this.onMenuPressed});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  DateFilter _currentFilter = DateFilter.last7Days();

  void _applyFilter(DateFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final analyticsData = ref.watch(
      analyticsDataProvider((
        startDate: _currentFilter.startDate,
        endDate: _currentFilter.endDate,
      )),
    );
    final activeOutlet = ref.watch(activeOutletProvider).valueOrNull;

    return Column(
      children: [
        _buildTopBar(activeOutlet),
        _buildDateFilters(),
        Expanded(
          child: analyticsData.when(
            data: (data) => _buildContent(data),
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AnalyticsTheme.primaryGold,
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading analytics',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(activeOutlet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnalyticsTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AnalyticsTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: AnalyticsTheme.primaryGold,
            onPressed: widget.onMenuPressed,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Overview',
                  style: AnalyticsTheme.headingLarge,
                  textAlign: TextAlign.center,
                ),
                if (activeOutlet != null)
                  Text(
                    activeOutlet.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: AnalyticsTheme.primaryGold.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            color: AnalyticsTheme.primaryGold,
            tooltip: 'Export to Excel',
            onPressed: () => _exportData(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AnalyticsTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AnalyticsTheme.borderColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            DateFilterChip(
              label: 'Yesterday',
              isSelected: _currentFilter.type == DateFilterType.yesterday,
              onSelected: () => _applyFilter(DateFilter.yesterday()),
            ),
            const SizedBox(width: 8),
            DateFilterChip(
              label: 'This Week',
              isSelected: _currentFilter.type == DateFilterType.thisWeek,
              onSelected: () => _applyFilter(DateFilter.thisWeek()),
            ),
            const SizedBox(width: 8),
            DateFilterChip(
              label: 'This Month',
              isSelected: _currentFilter.type == DateFilterType.thisMonth,
              onSelected: () => _applyFilter(DateFilter.thisMonth()),
            ),
            const SizedBox(width: 8),
            DateFilterChip(
              label: 'This Year',
              isSelected: _currentFilter.type == DateFilterType.thisYear,
              onSelected: () => _applyFilter(DateFilter.thisYear()),
            ),
            const SizedBox(width: 8),
            DateFilterChip(
              label: 'Last 7 Days',
              isSelected: _currentFilter.type == DateFilterType.last7Days,
              onSelected: () => _applyFilter(DateFilter.last7Days()),
            ),
            const SizedBox(width: 8),
            DateFilterChip(
              label: 'Last 30 Days',
              isSelected: _currentFilter.type == DateFilterType.last30Days,
              onSelected: () => _applyFilter(DateFilter.last30Days()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final analyticsData = await ref.read(
      analyticsDataProvider((
        startDate: _currentFilter.startDate,
        endDate: _currentFilter.endDate,
      )).future,
    );

    try {
      await AnalyticsExportService.exportToExcel(
        analyticsData,
        startDate: _currentFilter.startDate,
        endDate: _currentFilter.endDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildContent(AnalyticsData data) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Smart Brief
          _buildSmartBrief(data),
          const SizedBox(height: 24),

          // Key Metrics Grid (with AOV)
          Text('Key Metrics', style: AnalyticsTheme.headingMedium),
          const SizedBox(height: 16),
          _buildMetricsGrid(data, currencyFormat),
          const SizedBox(height: 32),

          // Monthly Sales Bar Graph
          Text('Monthly Sales Trend', style: AnalyticsTheme.headingMedium),
          const SizedBox(height: 16),
          _buildMonthlySalesChart(data),
          const SizedBox(height: 32),

          // Category Performance
          if (data.categoryPerformance.isNotEmpty) ...[
            Text('Category Performance', style: AnalyticsTheme.headingMedium),
            const SizedBox(height: 16),
            _buildCategoryPerformance(data),
            const SizedBox(height: 32),
          ],

          // Top Selling Items
          Text('Top Selling Items', style: AnalyticsTheme.headingMedium),
          const SizedBox(height: 16),
          _buildTopSellingItems(data),
        ],
      ),
    );
  }

  Widget _buildSmartBrief(AnalyticsData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AnalyticsTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: AnalyticsTheme.iconContainer(),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: AnalyticsTheme.primaryGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Smart Brief', style: AnalyticsTheme.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data.smartBrief,
            style: const TextStyle(
              color: AnalyticsTheme.primaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(AnalyticsData data, NumberFormat currencyFormat) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          icon: Icons.payments_rounded,
          title: 'Total Sales',
          value: currencyFormat.format(data.totalSales),
          change: data.salesChange,
        ),
        _buildMetricCard(
          icon: Icons.receipt_long_rounded,
          title: 'Orders',
          value: '${data.totalOrders}',
          change: data.ordersChange,
        ),
        _buildMetricCard(
          icon: Icons.shopping_cart_rounded,
          title: 'Avg Order Value',
          value: currencyFormat.format(data.averageOrderValue),
          change: data.aovChange,
        ),
        _buildMetricCard(
          icon: Icons.people_rounded,
          title: 'Customers',
          value: '${data.totalCustomers}',
          change: data.customersChange,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required double change,
  }) {
    final isPositive = change >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AnalyticsTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: AnalyticsTheme.iconContainer(),
                child: Icon(icon, color: AnalyticsTheme.primaryGold, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (isPositive
                              ? AnalyticsTheme.chartGreen
                              : AnalyticsTheme.chartRed)
                          .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: isPositive
                          ? AnalyticsTheme.chartGreen
                          : AnalyticsTheme.chartRed,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${change.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPositive
                            ? AnalyticsTheme.chartGreen
                            : AnalyticsTheme.chartRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AnalyticsTheme.primaryGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: AnalyticsTheme.subtitle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingItems(AnalyticsData data) {
    if (data.itemShare.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No Sales Data',
        subtitle: 'Start taking orders to see top selling items',
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AnalyticsTheme.glassCard(),
      child: Column(
        children: data.itemShare.take(5).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AnalyticsTheme.primaryGold.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.itemName,
                    style: const TextStyle(
                      color: AnalyticsTheme.primaryText,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AnalyticsTheme.chartBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: AnalyticsTheme.chartBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AnalyticsTheme.glassCard(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnalyticsTheme.primaryGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AnalyticsTheme.primaryGold.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AnalyticsTheme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: AnalyticsTheme.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesChart(AnalyticsData data) {
    if (data.monthlySales.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No Monthly Data',
        subtitle: 'Sales data will appear as you make transactions',
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: AnalyticsTheme.glassCard(),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              data.monthlySales
                  .map((e) => e.amount)
                  .reduce((a, b) => a > b ? a : b) *
              1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final month = data.monthlySales[groupIndex].month;
                final amount = rod.toY;
                return BarTooltipItem(
                  '$month\n₹${amount.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < data.monthlySales.length) {
                    final month = data.monthlySales[value.toInt()].month;
                    final parts = month.split('-');
                    if (parts.length == 2) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          parts[1], // Just show month number
                          style: TextStyle(
                            color: AnalyticsTheme.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₹${(value / 1000).toStringAsFixed(0)}k',
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.monthlySales.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.amount,
                  color: AnalyticsTheme.primaryGold,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryPerformance(AnalyticsData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AnalyticsTheme.glassCard(),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < data.categoryPerformance.length; i++) ...[
            _buildCategoryRow(data.categoryPerformance[i], i == 0),
            if (i < data.categoryPerformance.length - 1)
              const Divider(color: Colors.white10, height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(CategoryPerformance category, bool isTop) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isTop
                ? AnalyticsTheme.primaryGold.withOpacity(0.2)
                : AnalyticsTheme.chartBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.category_rounded,
            color: isTop
                ? AnalyticsTheme.primaryGold
                : AnalyticsTheme.chartBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.category,
                style: const TextStyle(
                  color: AnalyticsTheme.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${category.quantity} items sold',
                style: TextStyle(
                  color: AnalyticsTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${category.revenue.toStringAsFixed(0)}',
              style: TextStyle(
                color: isTop
                    ? AnalyticsTheme.primaryGold
                    : AnalyticsTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
