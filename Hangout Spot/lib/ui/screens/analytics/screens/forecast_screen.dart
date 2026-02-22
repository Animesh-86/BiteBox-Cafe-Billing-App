import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import '../widgets/analytics_header.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const ForecastScreen({super.key, required this.onMenuPressed});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  DateFilter _dateFilter = DateFilter.last7Days();
  DateTime get _startDate => _dateFilter.startDate;
  DateTime get _endDate => _dateFilter.endDate;

  void _applyDateFilter(DateFilter filter) {
    setState(() {
      _dateFilter = filter;
    });
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
          title: 'Demand Forecast',
          onMenuPressed: widget.onMenuPressed,
          currentFilter: _dateFilter,
          onFilterChanged: _applyDateFilter,
          onExportPressed: null,
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
          // Expected Demand Section
          _buildSectionCard(
            icon: Icons.trending_up_rounded,
            title: 'Expected Demand',
            subtitle: 'Next day average forecast',
            child: _buildExpectedDemandList(data),
          ),
          const SizedBox(height: 20),
          // Peak Hours by Day
          _buildSectionCard(
            icon: Icons.schedule_rounded,
            title: 'Peak Hours by Day',
            subtitle: 'Expected busiest hours for each day',
            child: _buildPeakHoursByDay(data),
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

  Widget _buildExpectedDemandList(AnalyticsData data) {
    if (data.itemForecast.isEmpty) {
      return _buildEmptyState(
        icon: Icons.insights_outlined,
        title: 'No Forecast Data',
        subtitle: 'Build sales history to generate demand forecasts',
      );
    }

    // Use GridView for better layout instead of long list
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: data.itemForecast.length,
      itemBuilder: (context, index) {
        final forecast = data.itemForecast[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AnalyticsTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AnalyticsTheme.primaryGold.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AnalyticsTheme.primaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AnalyticsTheme.primaryGold,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AnalyticsTheme.primaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      forecast.expectedQuantity.toStringAsFixed(0),
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                forecast.itemName,
                style: const TextStyle(
                  color: AnalyticsTheme.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Expected qty/day',
                style: TextStyle(
                  color: AnalyticsTheme.secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildPeakHoursByDay(AnalyticsData data) {
    if (data.peakHoursByDay.isEmpty) {
      return _buildEmptyState(
        icon: Icons.access_time_outlined,
        title: 'No Peak Hour Data',
        subtitle: 'Build sales history to see peak hours patterns',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.peakHoursByDay.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final peakHour = data.peakHoursByDay[index];

        // Format hour as 12-hour time
        final hour = peakHour.peakHour;
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final timeStr = '$displayHour:00 $period';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AnalyticsTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AnalyticsTheme.primaryGold.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Day icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AnalyticsTheme.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AnalyticsTheme.primaryGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Day info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peakHour.dayName,
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${peakHour.orderCount} orders',
                      style: TextStyle(
                        color: AnalyticsTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Peak time badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AnalyticsTheme.primaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AnalyticsTheme.primaryGold,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
