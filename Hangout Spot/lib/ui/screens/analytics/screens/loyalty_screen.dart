import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/ui/screens/analytics/services/analytics_export_service.dart';
import 'package:intl/intl.dart';
import '../widgets/analytics_header.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const LoyaltyScreen({super.key, required this.onMenuPressed});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> {
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
        content: Column(
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
      analyticsDataProvider((startDate: _startDate, endDate: _endDate)),
    );
    return Column(
      children: [
        AnalyticsHeader(
          title: 'Loyalty',
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
          // Customer Frequency Pyramid
          if (data.customerFrequencySegments != null &&
              data.customerFrequencySegments!.isNotEmpty)
            _buildSectionCard(
              icon: Icons.layers_rounded,
              title: 'Customer Frequency Pyramid',
              subtitle: 'Segmentation by order frequency',
              child: _buildCustomerFrequencyPyramid(data),
            ),
          if (data.customerFrequencySegments != null &&
              data.customerFrequencySegments!.isNotEmpty)
            const SizedBox(height: 24),

          // Customer Return Rate
          _buildSectionCard(
            icon: Icons.refresh_rounded,
            title: 'Customer Return Rate',
            subtitle: 'New vs returning breakdown',
            child: _buildReturnRateCard(data),
          ),
          const SizedBox(height: 24),

          // At-Risk Customers
          _buildSectionCard(
            icon: Icons.warning_rounded,
            title: 'At-Risk Customers',
            subtitle: 'Regulars who haven\'t visited in 30+ days',
            child: _buildAtRiskCustomers(data),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerFrequencyPyramid(AnalyticsData data) {
    final segments = data.customerFrequencySegments;
    if (segments == null || segments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_rounded,
        title: 'No Customer Data',
        subtitle: 'Customer frequency data will appear here',
      );
    }
    final total = segments.fold<int>(
      0,
      (sum, seg) => sum + (seg['count'] as int? ?? 0),
    );

    final vipSegment = segments.firstWhere(
      (s) => s['segment'] == 'VIP',
      orElse: () => <String, Object>{'count': 0},
    );
    final regularSegment = segments.firstWhere(
      (s) => s['segment'] == 'Regular',
      orElse: () => <String, Object>{'count': 0},
    );
    final occasionalSegment = segments.firstWhere(
      (s) => s['segment'] == 'Occasional',
      orElse: () => <String, Object>{'count': 0},
    );
    final oneTimeSegment = segments.firstWhere(
      (s) => s['segment'] == 'One-time',
      orElse: () => <String, Object>{'count': 0},
    );

    final segmentData = [
      {
        'label': 'VIP (10+ orders)',
        'count': vipSegment['count'] as int? ?? 0,
        'color': AnalyticsTheme.primaryGold,
        'icon': Icons.diamond_rounded,
      },
      {
        'label': 'Regulars (5-9 orders)',
        'count': regularSegment['count'] as int? ?? 0,
        'color': AnalyticsTheme.chartBlue,
        'icon': Icons.star_rounded,
      },
      {
        'label': 'Occasional (2-4 orders)',
        'count': occasionalSegment['count'] as int? ?? 0,
        'color': AnalyticsTheme.chartAmber,
        'icon': Icons.favorite_rounded,
      },
      {
        'label': 'One-time (1 order)',
        'count': oneTimeSegment['count'] as int? ?? 0,
        'color': AnalyticsTheme.secondaryBeige,
        'icon': Icons.person_rounded,
      },
    ];

    return Column(
      children: segmentData.map((segment) {
        final count = segment['count'] as int;
        final percentage = total > 0 ? (count / total * 100) : 0.0;
        final width = percentage * 0.8; // Scale to 80% max width

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    segment['icon'] as IconData,
                    color: segment['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      segment['label'] as String? ?? 'Unknown',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '$count (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AnalyticsTheme.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: width / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: segment['color'] as Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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

  Widget _buildReturnRateCard(AnalyticsData data) {
    final total = data.newCustomers + data.returningCustomers;

    if (total == 0) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No Customer Data',
        subtitle: 'Start serving customers to track loyalty',
      );
    }

    final retentionRate = total == 0
        ? 0.0
        : (data.returningCustomers / total * 100);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: [
                PieChartSectionData(
                  value: data.newCustomers.toDouble(),
                  title: '${data.newCustomers}',
                  color: AnalyticsTheme.secondaryBeige,
                  radius: 40,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: data.returningCustomers.toDouble(),
                  title: '${data.returningCustomers}',
                  color: AnalyticsTheme.chartBlue,
                  radius: 40,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'New',
              '${data.newCustomers}',
              AnalyticsTheme.secondaryBeige,
            ),
            _buildStatItem(
              'Returning',
              '${data.returningCustomers}',
              AnalyticsTheme.chartBlue,
            ),
            _buildStatItem(
              'Retention',
              '${retentionRate.toStringAsFixed(1)}%',
              AnalyticsTheme.primaryGold,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AnalyticsTheme.subtitle),
      ],
    );
  }

  Widget _buildAtRiskCustomers(AnalyticsData data) {
    if (data.atRiskCustomers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            '✅ All regulars are still active!',
            style: const TextStyle(
              color: AnalyticsTheme.chartGreen,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Column(
      children: data.atRiskCustomers.map((customer) {
        final daysAgo = DateTime.now().difference(customer.lastVisit).inDays;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AnalyticsTheme.iconContainer(
                  color: AnalyticsTheme.chartAmber,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AnalyticsTheme.chartAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Last visit: ${DateFormat('dd MMM yyyy').format(customer.lastVisit)}',
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AnalyticsTheme.chartRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysAgo days',
                  style: const TextStyle(
                    color: AnalyticsTheme.chartRed,
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 200,
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
