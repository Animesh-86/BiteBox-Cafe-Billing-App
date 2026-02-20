import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:intl/intl.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  final VoidCallback onMenuPressed;
  const ForecastScreen({super.key, required this.onMenuPressed});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();

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
                  'Forecast',
                  style: AnalyticsTheme.headingLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
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
          const SizedBox(height: 24),

          // Bundle Suggestions Section
          _buildSectionCard(
            icon: Icons.local_offer_rounded,
            title: 'Bundle Suggestions',
            subtitle: 'Popular item combinations',
            child: _buildBundleSuggestions(data),
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

    return Column(
      children: data.itemForecast.map((forecast) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AnalyticsTheme.iconContainer(),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AnalyticsTheme.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forecast.itemName,
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Expected quantity',
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
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AnalyticsTheme.primaryGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  forecast.expectedQuantity.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AnalyticsTheme.primaryGold,
                    fontSize: 16,
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

  Widget _buildBundleSuggestions(AnalyticsData data) {
    if (data.bundleSuggestions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No Bundle Suggestions',
        subtitle: 'Analyze more orders to discover combo patterns',
      );
    }

    return Column(
      children: data.bundleSuggestions.asMap().entries.map((entry) {
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
                  color: AnalyticsTheme.chartPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: AnalyticsTheme.chartPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bundle.item1} + ${bundle.item2}',
                      style: const TextStyle(
                        color: AnalyticsTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Frequently ordered together',
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
                  color: AnalyticsTheme.chartPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${bundle.count} orders',
                  style: const TextStyle(
                    color: AnalyticsTheme.chartPurple,
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
