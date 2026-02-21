import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:intl/intl.dart';

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
          const SizedBox(width: 48),
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
          Text('Demand Forecast', style: AnalyticsTheme.headingMedium),
          const SizedBox(height: 4),
          Text(
            'Predictions based on ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
            style: AnalyticsTheme.subtitle,
          ),
          const SizedBox(height: 24),

          // Expected Demand Section
          _buildSectionCard(
            icon: Icons.trending_up_rounded,
            title: 'Expected Demand',
            subtitle: 'Next day average forecast',
            child: _buildExpectedDemandList(data),
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
}
