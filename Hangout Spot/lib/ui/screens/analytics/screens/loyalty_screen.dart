import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/ui/screens/analytics/services/analytics_export_service.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:intl/intl.dart';

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

  Future<void> _exportData(AnalyticsData data) async {
    setState(() => _isExporting = true);
    try {
      await AnalyticsExportService.exportToExcel(
        data,
        startDate: _startDate,
        endDate: _endDate,
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
      setState(() {
        _dateFilter = DateFilter.custom(picked.start, picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsData = ref.watch(
      analyticsDataProvider((startDate: _startDate, endDate: _endDate)),
    );

    return Column(
      children: [
        _buildTopBar(),
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

  Widget _buildTopBar() {
    final activeOutlet = ref.watch(activeOutletProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnalyticsTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AnalyticsTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                color: AnalyticsTheme.primaryGold,
                onPressed: widget.onMenuPressed,
              ),
              const Expanded(
                child: Text(
                  'Loyalty',
                  style: AnalyticsTheme.headingLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              activeOutlet.when(
                data: (data) => _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AnalyticsTheme.primaryGold,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.file_download_outlined),
                        color: AnalyticsTheme.primaryGold,
                        onPressed: () {
                          ref
                              .read(
                                analyticsDataProvider((
                                  startDate: _startDate,
                                  endDate: _endDate,
                                )).future,
                              )
                              .then(_exportData);
                        },
                        tooltip: 'Export to Excel',
                      ),
                loading: () => const SizedBox(width: 48),
                error: (_, __) => const SizedBox(width: 48),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.store_rounded,
                color: AnalyticsTheme.primaryGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              activeOutlet.when(
                data: (outlet) => Text(
                  outlet?.name ?? 'All Outlets',
                  style: const TextStyle(
                    color: AnalyticsTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                loading: () => Text(
                  'Loading...',
                  style: TextStyle(
                    color: AnalyticsTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                error: (_, __) => const Text(
                  'All Outlets',
                  style: TextStyle(
                    color: AnalyticsTheme.primaryText,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DateFilterChip(
                  label: 'Yesterday',
                  isSelected: _dateFilter.type == DateFilterType.yesterday,
                  onSelected: () => _applyDateFilter(DateFilter.yesterday()),
                ),
                const SizedBox(width: 8),
                DateFilterChip(
                  label: 'This Week',
                  isSelected: _dateFilter.type == DateFilterType.thisWeek,
                  onSelected: () => _applyDateFilter(DateFilter.thisWeek()),
                ),
                const SizedBox(width: 8),
                DateFilterChip(
                  label: 'This Month',
                  isSelected: _dateFilter.type == DateFilterType.thisMonth,
                  onSelected: () => _applyDateFilter(DateFilter.thisMonth()),
                ),
                const SizedBox(width: 8),
                DateFilterChip(
                  label: 'This Year',
                  isSelected: _dateFilter.type == DateFilterType.thisYear,
                  onSelected: () => _applyDateFilter(DateFilter.thisYear()),
                ),
                const SizedBox(width: 8),
                DateFilterChip(
                  label: 'Last 7 Days',
                  isSelected: _dateFilter.type == DateFilterType.last7Days,
                  onSelected: () => _applyDateFilter(DateFilter.last7Days()),
                ),
                const SizedBox(width: 8),
                DateFilterChip(
                  label: 'Last 30 Days',
                  isSelected: _dateFilter.type == DateFilterType.last30Days,
                  onSelected: () => _applyDateFilter(DateFilter.last30Days()),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _dateFilter.type == DateFilterType.custom
                          ? AnalyticsTheme.primaryGold
                          : AnalyticsTheme.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AnalyticsTheme.primaryGold,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: _dateFilter.type == DateFilterType.custom
                              ? Colors.black
                              : AnalyticsTheme.primaryGold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Custom',
                          style: TextStyle(
                            color: _dateFilter.type == DateFilterType.custom
                                ? Colors.black
                                : AnalyticsTheme.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AnalyticsData data) {
    final dateFormat = DateFormat('dd MMM');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          Text('Customer Loyalty', style: AnalyticsTheme.headingMedium),
          const SizedBox(height: 4),
          Text(
            'Retention & engagement for ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
            style: AnalyticsTheme.subtitle,
          ),
          const SizedBox(height: 24),

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

    final segmentData = [
      {
        'label': 'VIP (10+ orders)',
        'count':
            segments.firstWhere(
                  (s) => s['segment'] == 'VIP',
                  orElse: () => {'count': 0},
                )['count']
                as int? ??
            0,
        'color': AnalyticsTheme.primaryGold,
        'icon': Icons.diamond_rounded,
      },
      {
        'label': 'Regulars (5-9 orders)',
        'count':
            segments.firstWhere(
                  (s) => s['segment'] == 'Regular',
                  orElse: () => {'count': 0},
                )['count']
                as int? ??
            0,
        'color': AnalyticsTheme.chartBlue,
        'icon': Icons.star_rounded,
      },
      {
        'label': 'Occasional (2-4 orders)',
        'count':
            segments.firstWhere(
                  (s) => s['segment'] == 'Occasional',
                  orElse: () => {'count': 0},
                )['count']
                as int? ??
            0,
        'color': AnalyticsTheme.chartAmber,
        'icon': Icons.favorite_rounded,
      },
      {
        'label': 'One-time (1 order)',
        'count':
            segments.firstWhere(
                  (s) => s['segment'] == 'One-time',
                  orElse: () => {'count': 0},
                )['count']
                as int? ??
            0,
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
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AnalyticsTheme.chartGreen,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '✅ All regulars are still active!',
              style: const TextStyle(
                color: AnalyticsTheme.chartGreen,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
