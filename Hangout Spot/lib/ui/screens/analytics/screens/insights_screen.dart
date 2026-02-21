import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/ui/screens/analytics/services/analytics_export_service.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:intl/intl.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const InsightsScreen({super.key, required this.onMenuPressed});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
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

  Future<void> _showOutletSelector(Location? currentOutlet) async {
    final locations = await ref.read(locationsStreamProvider.future);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AnalyticsTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Outlet',
              style: TextStyle(
                color: AnalyticsTheme.primaryGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Add "All Outlets" option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentOutlet == null
                      ? AnalyticsTheme.primaryGold.withOpacity(0.2)
                      : AnalyticsTheme.secondaryBeige.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.store_mall_directory_rounded,
                  color: currentOutlet == null
                      ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.secondaryText,
                ),
              ),
              title: Text(
                'All Outlets',
                style: TextStyle(
                  color: currentOutlet == null
                      ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.primaryText,
                  fontWeight: currentOutlet == null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                'Combined analytics from all outlets',
                style: TextStyle(
                  color: AnalyticsTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
              trailing: currentOutlet == null
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AnalyticsTheme.primaryGold,
                    )
                  : null,
              onTap: () async {
                // Deactivate all outlets to show "All Outlets"
                final locations = await ref.read(
                  locationsStreamProvider.future,
                );
                for (final location in locations) {
                  await ref
                      .read(locationsControllerProvider.notifier)
                      .deactivateOutlet(location.id);
                }
                if (mounted) Navigator.pop(context);
              },
            ),
            const Divider(),
            ...locations.map(
              (location) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: location.id == currentOutlet?.id
                        ? AnalyticsTheme.primaryGold.withOpacity(0.2)
                        : AnalyticsTheme.secondaryBeige.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: location.id == currentOutlet?.id
                        ? AnalyticsTheme.primaryGold
                        : AnalyticsTheme.secondaryText,
                  ),
                ),
                title: Text(
                  location.name,
                  style: TextStyle(
                    color: location.id == currentOutlet?.id
                        ? AnalyticsTheme.primaryGold
                        : AnalyticsTheme.primaryText,
                    fontWeight: location.id == currentOutlet?.id
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  location.address ?? 'No address',
                  style: TextStyle(
                    color: AnalyticsTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: location.id == currentOutlet?.id
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AnalyticsTheme.primaryGold,
                      )
                    : null,
                onTap: () {
                  ref
                      .read(locationsControllerProvider.notifier)
                      .activateOutlet(location.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyticsData = ref.watch(
      analyticsDataProvider((startDate: _startDate, endDate: _endDate)),
    );
    final activeOutlet = ref.watch(activeOutletProvider).valueOrNull;

    return Column(
      children: [
        _buildTopBar(activeOutlet),
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

  Widget _buildTopBar(Location? activeOutlet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            activeOutlet?.address ?? 'All Outlets',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AnalyticsTheme.primaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showOutletSelector(activeOutlet),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AnalyticsTheme.cardBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AnalyticsTheme.primaryGold.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activeOutlet == null
                          ? Icons.store_mall_directory_rounded
                          : Icons.store_rounded,
                      color: AnalyticsTheme.primaryGold,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        activeOutlet?.name ?? 'All Outlets',
                        style: const TextStyle(
                          color: AnalyticsTheme.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AnalyticsTheme.primaryGold,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isExporting
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
                  icon: const Icon(Icons.download_rounded),
                  color: AnalyticsTheme.primaryGold,
                  tooltip: 'Export to Excel',
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ],
      ),
    );
  }

  Widget _buildDateFiltersRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
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
          Text('Menu Insights', style: AnalyticsTheme.headingMedium),
          const SizedBox(height: 4),
          Text(
            'Actionable intelligence for ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
            style: AnalyticsTheme.subtitle,
          ),
          const SizedBox(height: 24),

          // Payment Method Distribution
          if (data.paymentMethodDistribution != null &&
              data.paymentMethodDistribution!.isNotEmpty)
            _buildSectionCard(
              icon: Icons.payment_rounded,
              title: 'Payment Methods',
              subtitle: 'Transaction breakdown by payment type',
              child: _buildPaymentMethodChart(data),
            ),
          if (data.paymentMethodDistribution != null &&
              data.paymentMethodDistribution!.isNotEmpty)
            const SizedBox(height: 24),

          // Discount Effectiveness
          _buildSectionCard(
            icon: Icons.trending_up_rounded,
            title: 'Discount Effectiveness',
            subtitle: 'ROI analysis of discount campaigns',
            child: _buildDiscountEffectiveness(data),
          ),
          const SizedBox(height: 24),

          // Combo Intelligence
          _buildSectionCard(
            icon: Icons.local_offer_rounded,
            title: 'Combo Intelligence',
            subtitle: 'Items most often ordered together',
            child: _buildComboIntelligence(data),
          ),
          const SizedBox(height: 24),

          // Revenue Leakage Detector
          _buildSectionCard(
            icon: Icons.warning_amber_rounded,
            title: 'Revenue Leakage Detector',
            subtitle: 'Discounts given & untracked customers',
            child: _buildRevenueLeakage(data),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChart(AnalyticsData data) {
    final total = data.paymentMethodDistribution!.fold<double>(
      0,
      (sum, method) => sum + method['amount'],
    );

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.paymentMethodDistribution!.map((method) {
                  final percentage = (method['amount'] / total * 100);
                  final color = _getPaymentMethodColor(method['method']);
                  return PieChartSectionData(
                    value: method['amount'],
                    title: '${percentage.toStringAsFixed(0)}%',
                    color: color,
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
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
            children: data.paymentMethodDistribution!.map((method) {
              final color = _getPaymentMethodColor(method['method']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method['method'],
                            style: const TextStyle(
                              color: AnalyticsTheme.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${method['amount'].toStringAsFixed(0)} • ${method['count']} orders',
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
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AnalyticsTheme.chartGreen;
      case 'card':
        return AnalyticsTheme.chartBlue;
      case 'upi':
        return AnalyticsTheme.primaryGold;
      case 'credit':
        return AnalyticsTheme.chartAmber;
      default:
        return AnalyticsTheme.secondaryBeige;
    }
  }

  Widget _buildDiscountEffectiveness(AnalyticsData data) {
    final discount = data.discountEffectiveness;
    final roi = discount.totalDiscountAmount > 0
        ? ((discount.revenueWithDiscount - discount.totalDiscountAmount) /
              discount.totalDiscountAmount *
              100)
        : 0;
    final isPositive = roi > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnalyticsTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive
              ? AnalyticsTheme.chartGreen
              : AnalyticsTheme.chartRed,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isPositive
                              ? AnalyticsTheme.chartGreen
                              : AnalyticsTheme.chartRed)
                          .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: isPositive
                      ? AnalyticsTheme.chartGreen
                      : AnalyticsTheme.chartRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Discount Impact',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${discount.ordersWithDiscount} orders with discounts',
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
                    '${roi.toStringAsFixed(0)}% ROI',
                    style: TextStyle(
                      color: isPositive
                          ? AnalyticsTheme.chartGreen
                          : AnalyticsTheme.chartRed,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPositive ? 'Effective' : 'Review Needed',
                    style: TextStyle(
                      color: AnalyticsTheme.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discount Given',
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${discount.totalDiscountAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue with Discounts',
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${discount.revenueWithDiscount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders without Discount',
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${discount.ordersWithoutDiscount}',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue without Discounts',
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${discount.revenueWithoutDiscount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AnalyticsTheme.chartGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildBCGMatrix(AnalyticsData data) {
    if (data.bcgMatrix.isEmpty) {
      return _buildEmptyState(
        icon: Icons.scatter_plot_outlined,
        title: 'No Product Data',
        subtitle: 'Sell items to see product performance matrix',
      );
    }

    return SizedBox(
      height: 300,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: data.bcgMatrix.asMap().entries.map((entry) {
            final item = entry.value;
            return ScatterSpot(
              item.revenue,
              item.volume.toDouble(),
              dotPainter: FlDotCirclePainter(
                color: _getBCGQuadrantColor(
                  item.revenue,
                  item.volume.toDouble(),
                  data,
                ),
                radius: 8,
              ),
            );
          }).toList(),
          minX: 0,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.white24, strokeWidth: 1);
            },
            getDrawingVerticalLine: (value) {
              return FlLine(color: Colors.white24, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: Text('Revenue', style: AnalyticsTheme.subtitle),
              sideTitles: SideTitles(
                showTitles: true,
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
            leftTitles: AxisTitles(
              axisNameWidget: Text('Volume', style: AnalyticsTheme.subtitle),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
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
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.white10),
          ),
        ),
      ),
    );
  }

  Color _getBCGQuadrantColor(
    double revenue,
    double volume,
    AnalyticsData data,
  ) {
    if (data.bcgMatrix.isEmpty) {
      return AnalyticsTheme.primaryGold;
    }

    final avgRevenue =
        data.bcgMatrix.map((e) => e.revenue).reduce((a, b) => a + b) /
        data.bcgMatrix.length;
    final avgVolume =
        data.bcgMatrix.map((e) => e.volume).reduce((a, b) => a + b) /
        data.bcgMatrix.length;

    if (revenue > avgRevenue && volume > avgVolume) {
      return AnalyticsTheme.chartGreen; // Stars
    } else if (revenue > avgRevenue && volume <= avgVolume) {
      return AnalyticsTheme.primaryGold; // Cash Cows
    } else if (revenue <= avgRevenue && volume > avgVolume) {
      return AnalyticsTheme.chartAmber; // Question Marks
    } else {
      return AnalyticsTheme.chartRed; // Dogs
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AnalyticsTheme.secondaryText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildComboIntelligence(AnalyticsData data) {
    final colors = [
      AnalyticsTheme.primaryGold,
      Colors.grey,
      const Color(0xFFCD7F32), // bronze
      const Color(0xFF4A4A4A),
      const Color(0xFF2A9D8F),
    ];

    return Column(
      children: data.bundleSuggestions.take(5).toList().asMap().entries.map((
        entry,
      ) {
        final index = entry.key;
        final bundle = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors[index % colors.length].withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: colors[index % colors.length],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${bundle.item1} + ${bundle.item2}',
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
                  color: AnalyticsTheme.secondaryBeige.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${bundle.count}x',
                  style: const TextStyle(
                    color: AnalyticsTheme.secondaryBeige,
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

  Widget _buildRevenueLeakage(AnalyticsData data) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1810).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AnalyticsTheme.borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_offer_rounded,
                  color: AnalyticsTheme.primaryGold,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  currencyFormat.format(data.discountsGiven),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AnalyticsTheme.primaryGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discounts Given',
                  style: const TextStyle(
                    color: AnalyticsTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.discountedOrdersCount} orders affected',
                  style: TextStyle(
                    color: AnalyticsTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1010).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AnalyticsTheme.borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: AnalyticsTheme.chartRed,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  '${data.walkInGuests}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AnalyticsTheme.chartRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Walk-in Guests',
                  style: const TextStyle(
                    color: AnalyticsTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Loyalty opportunities missed',
                  style: TextStyle(
                    color: AnalyticsTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
      height: 300,
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
