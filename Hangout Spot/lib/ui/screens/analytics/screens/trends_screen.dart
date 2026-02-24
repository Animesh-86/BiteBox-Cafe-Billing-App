import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/ui/screens/analytics/services/analytics_export_service.dart';
import 'package:intl/intl.dart';
import '../widgets/analytics_header.dart';

class TrendsScreen extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const TrendsScreen({super.key, required this.onMenuPressed});

  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  DateFilter _dateFilter = DateFilter.last7Days();
  DateTime get _startDate => _dateFilter.startDate;
  DateTime get _endDate => _dateFilter.endDate;
  bool _isExporting = false;

  void _applyDateFilter(DateFilter filter) {
    setState(() {
      _dateFilter = filter;
    });
  }

  Future<void> _exportData() async {
    // Show dialog to select export date range
    final selectedFilter = await showDialog<DateFilter>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AnalyticsTheme.cardBackground,
        title: const Text(
          'Export Date Range',
          style: TextStyle(color: AnalyticsTheme.primaryText),
        ),
        content: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.calendar_month,
                  color: AnalyticsTheme.primaryGold,
                ),
                title: const Text(
                  'This Year',
                  style: TextStyle(color: AnalyticsTheme.primaryText),
                ),
                onTap: () => Navigator.pop(context, DateFilter.thisYear()),
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: AnalyticsTheme.primaryGold,
                ),
                title: const Text(
                  'This Month',
                  style: TextStyle(color: AnalyticsTheme.primaryText),
                ),
                onTap: () => Navigator.pop(context, DateFilter.thisMonth()),
              ),
              ListTile(
                leading: const Icon(
                Icons.date_range,
                color: AnalyticsTheme.primaryGold,
              ),
              title: const Text(
                'This Week',
                style: TextStyle(color: AnalyticsTheme.primaryText),
              ),
              onTap: () => Navigator.pop(context, DateFilter.thisWeek()),
            ),
            ListTile(
              leading: const Icon(
                Icons.event,
                color: AnalyticsTheme.primaryGold,
              ),
              title: const Text(
                'Custom Range',
                style: TextStyle(color: AnalyticsTheme.primaryText),
              ),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(
                    start: _startDate,
                    end: _endDate,
                  ),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AnalyticsTheme.primaryGold,
                          surface: AnalyticsTheme.cardBackground,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  _performExport(DateFilter.custom(picked.start, picked.end));
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.highlight,
                color: AnalyticsTheme.primaryGold,
              ),
              title: const Text(
                'Current Selection',
                style: TextStyle(color: AnalyticsTheme.primaryText),
              ),
              subtitle: Text(
                '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: TextStyle(
                  color: AnalyticsTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
              onTap: () => Navigator.pop(context, _dateFilter),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AnalyticsTheme.primaryGold),
            ),
          ),
        ],
      ),
    );

    if (selectedFilter != null) {
      _performExport(selectedFilter);
    }
  }

  Future<void> _performExport(DateFilter filter) async {
    setState(() => _isExporting = true);
    try {
      final exportData = await ref.read(
        analyticsDataProvider((
          startDate: filter.startDate,
          endDate: filter.endDate,
          filterName: filter.label,
        )).future,
      );

      await AnalyticsExportService.exportToExcel(
        exportData,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics exported successfully!'),
            backgroundColor: AnalyticsTheme.primaryGold,
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
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsData = ref.watch(
      analyticsDataProvider((
        startDate: _startDate,
        endDate: _endDate,
        filterName: _dateFilter.label,
      )),
    );
    return Column(
      children: [
        AnalyticsHeader(
          title: 'Trends',
          onMenuPressed: widget.onMenuPressed,
          currentFilter: _dateFilter,
          onFilterChanged: _applyDateFilter,
          onExportPressed: _exportData,
          isExporting: _isExporting,
        ),
        Expanded(
          child: analyticsData.when(
            data: (data) => _buildContent(data),
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AnalyticsTheme.primaryGold,
              ),
            ),
            error: (error, stack) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(AnalyticsData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily Sales Trend
          _buildSectionCard(
            icon: Icons.trending_up_rounded,
            title: 'Daily Sales Trend',
            subtitle: 'Revenue by day',
            child: _buildDailySalesTrendChart(data),
          ),
          const SizedBox(height: 24),

          // Item Share
          _buildSectionCard(
            icon: Icons.pie_chart_rounded,
            title: 'Item Share',
            subtitle: 'Top items contribution',
            child: _buildItemShareChart(data),
          ),
          const SizedBox(height: 24),

          // Peak Hours
          _buildSectionCard(
            icon: Icons.access_time_rounded,
            title: 'Peak Hours',
            subtitle: 'Order distribution during operating hours',
            child: _buildPeakHoursChart(data),
          ),
          const SizedBox(height: 24),

          // Hourly Heat Map
          _buildSectionCard(
            icon: Icons.grid_on_rounded,
            title: 'Hourly Heat Map',
            subtitle: 'Intensity by hour',
            child: _buildHourlyHeatMap(data),
          ),
          const SizedBox(height: 24),

          // Top Selling Items
          _buildSectionCard(
            icon: Icons.star_rounded,
            title: 'Top Selling Items',
            subtitle: 'Best performers',
            child: _buildTopSellingChart(data),
          ),
          const SizedBox(height: 24),

          // Low Performing Items
          _buildSectionCard(
            icon: Icons.warning_rounded,
            title: 'Low Performing Items',
            subtitle: 'Items needing attention',
            child: _buildLowPerformingList(data),
          ),
          const SizedBox(height: 24),

          // Orders by Day of Week
          _buildSectionCard(
            icon: Icons.bar_chart_rounded,
            title: 'Orders by Day of Week',
            subtitle: 'Traffic pattern across the week',
            child: _buildDayOfWeekChart(data),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AnalyticsTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: AnalyticsTheme.iconContainer(),
                child: Icon(icon, color: AnalyticsTheme.primaryGold, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildDailySalesTrendChart(AnalyticsData data) {
    if (data.dailySales.isEmpty) {
      return _buildEmptyState(
        icon: Icons.show_chart_rounded,
        title: 'No Sales Data',
        subtitle: 'Daily sales trend will appear after orders',
      );
    }

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 500,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.white10, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < data.dailySales.length) {
                    final date = data.dailySales[value.toInt()].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: TextStyle(
                          color: AnalyticsTheme.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₹${value.toInt()}',
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.dailySales.length,
                (index) =>
                    FlSpot(index.toDouble(), data.dailySales[index].amount),
              ),
              isCurved: true,
              color: AnalyticsTheme.primaryGold,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AnalyticsTheme.primaryGold.withOpacity(0.3),
                    AnalyticsTheme.primaryGold.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemShareChart(AnalyticsData data) {
    if (data.itemShare.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No Items Sold',
        subtitle: 'Complete some orders to see item distribution',
      );
    }

    final total = data.itemShare.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return SizedBox(
      height: 250,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: List.generate(
                  data.itemShare.length > 5 ? 5 : data.itemShare.length,
                  (index) {
                    final item = data.itemShare[index];
                    final percentage = (item.quantity / total * 100);
                    return PieChartSectionData(
                      value: item.quantity.toDouble(),
                      title: '${percentage.toStringAsFixed(0)}%',
                      color:
                          AnalyticsTheme.chartColors[index %
                              AnalyticsTheme.chartColors.length],
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                data.itemShare.length > 5 ? 5 : data.itemShare.length,
                (index) {
                  final item = data.itemShare[index];
                  final percentage = (item.quantity / total * 100);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                AnalyticsTheme.chartColors[index %
                                    AnalyticsTheme.chartColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(
                                  color: AnalyticsTheme.primaryText,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: AnalyticsTheme.secondaryText,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursChart(AnalyticsData data) {
    if (data.hourlyOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.access_time_rounded,
        title: 'No Order Data',
        subtitle: 'Peak hours will appear after taking orders',
      );
    }

    // Operating hours: 2PM (14) to 2AM (2) next day
    // Reorder to show: 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 0, 1
    final operatingHours = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 0, 1, 2];

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.white10, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 &&
                      value.toInt() < operatingHours.length) {
                    final hour = operatingHours[value.toInt()];
                    // Show time in 12-hour format
                    final displayHour = hour == 0
                        ? '12AM'
                        : hour < 12
                        ? '${hour}AM'
                        : hour == 12
                        ? '12PM'
                        : '${hour - 12}PM';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          displayHour,
                          style: TextStyle(
                            color: AnalyticsTheme.secondaryText,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(operatingHours.length, (index) {
            final hour = operatingHours[index];
            final hourData = data.hourlyOrders.firstWhere(
              (h) => h.hour == hour,
              orElse: () => HourlyData(hour: hour, count: 0),
            );
            // Highlight peak dinner time (7PM-10PM)
            final isPeakTime = hour >= 19 && hour <= 22;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: hourData.count.toDouble(),
                  color: isPeakTime
                      ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.secondaryBeige,
                  width: 12,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHourlyHeatMap(AnalyticsData data) {
    final maxCount = data.hourlyOrders.isEmpty
        ? 1.0
        : data.hourlyOrders
              .map((h) => h.count)
              .reduce((a, b) => a > b ? a : b)
              .toDouble();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(24, (hour) {
        final hourData = data.hourlyOrders.firstWhere(
          (h) => h.hour == hour,
          orElse: () => HourlyData(hour: hour, count: 0),
        );
        final intensity = hourData.count / maxCount;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AnalyticsTheme.primaryGold.withOpacity(intensity * 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AnalyticsTheme.borderColor, width: 1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hour == 0
                  ? '12 AM'
                  : hour < 12
                  ? '$hour AM'
                  : hour == 12
                  ? '12 PM'
                  : '${hour - 12} PM',
              style: TextStyle(
                color: AnalyticsTheme.secondaryText,
                fontSize: 9,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTopSellingChart(AnalyticsData data) {
    final topItems = data.itemShare.take(5).toList();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.white10, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < topItems.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        topItems[value.toInt()].itemName.split(' ').first,
                        style: TextStyle(
                          color: AnalyticsTheme.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            topItems.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: topItems[index].quantity.toDouble(),
                  color: AnalyticsTheme.chartBlue,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLowPerformingList(AnalyticsData data) {
    final lowItems = data.itemShare.reversed.take(5).toList();

    return Column(
      children: lowItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AnalyticsTheme.iconContainer(),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: AnalyticsTheme.primaryGold,
                  size: 20,
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
                  color: AnalyticsTheme.primaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.quantity} units',
                  style: const TextStyle(
                    color: AnalyticsTheme.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayOfWeekChart(AnalyticsData data) {
    if (data.dayOfWeekSales.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No Day of Week Data',
        subtitle: 'Sales pattern will appear after more orders',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.white10, strokeWidth: 1);
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      if (value.toInt() >= 0 && value.toInt() < days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            days[value.toInt()],
                            style: TextStyle(
                              color: AnalyticsTheme.secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
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
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (index) {
                final dayData = data.dayOfWeekSales.firstWhere(
                  (d) => d.dayOfWeek == index,
                  orElse: () =>
                      DayOfWeekSales(dayOfWeek: index, amount: 0, count: 0),
                );
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: dayData.amount,
                      color: AnalyticsTheme.primaryGold,
                      width: 30,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    const days = [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ];
                    final dayData = data.dayOfWeekSales.firstWhere(
                      (d) => d.dayOfWeek == group.x,
                      orElse: () => DayOfWeekSales(
                        dayOfWeek: group.x.toInt(),
                        amount: 0,
                        count: 0,
                      ),
                    );
                    return BarTooltipItem(
                      '${days[group.x.toInt()]}\n₹${dayData.amount.toStringAsFixed(0)}\n${dayData.count} orders',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Day Summary Cards
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(7, (index) {
            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final dayData = data.dayOfWeekSales.firstWhere(
              (d) => d.dayOfWeek == index,
              orElse: () =>
                  DayOfWeekSales(dayOfWeek: index, amount: 0, count: 0),
            );
            final isTop =
                data.dayOfWeekSales.indexWhere(
                  (d) =>
                      d.amount ==
                      data.dayOfWeekSales
                          .map((e) => e.amount)
                          .reduce((a, b) => a > b ? a : b),
                ) ==
                index;

            return Container(
              width: (MediaQuery.of(context).size.width - 80) / 4,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTop
                    ? AnalyticsTheme.primaryGold.withOpacity(0.2)
                    : AnalyticsTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTop
                      ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.borderColor,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    days[index],
                    style: TextStyle(
                      color: isTop
                          ? AnalyticsTheme.primaryGold
                          : AnalyticsTheme.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${dayData.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AnalyticsTheme.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dayData.count} orders',
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 250,
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
}
