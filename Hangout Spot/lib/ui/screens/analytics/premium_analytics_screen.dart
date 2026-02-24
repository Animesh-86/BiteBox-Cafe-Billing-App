import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/screens/overview_screen.dart';
import 'package:hangout_spot/ui/screens/analytics/screens/trends_screen.dart';
import 'package:hangout_spot/ui/screens/analytics/screens/forecast_screen.dart';
import 'package:hangout_spot/ui/screens/analytics/screens/insights_screen.dart';
import 'package:hangout_spot/ui/screens/analytics/screens/loyalty_screen.dart';
import 'package:hangout_spot/ui/screens/analytics/screens/outlet_comparison_screen.dart';

enum AnalyticsSection {
  overview,
  trends,
  forecast,
  insights,
  loyalty,
  outletComparison,
}

class PremiumAnalyticsScreen extends ConsumerStatefulWidget {
  const PremiumAnalyticsScreen({super.key});

  @override
  ConsumerState<PremiumAnalyticsScreen> createState() =>
      _PremiumAnalyticsScreenState();
}

class _PremiumAnalyticsScreenState
    extends ConsumerState<PremiumAnalyticsScreen> {
  AnalyticsSection _currentSection = AnalyticsSection.overview;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _getCurrentScreen() {
    switch (_currentSection) {
      case AnalyticsSection.overview:
        return SafeArea(child: OverviewScreen(onMenuPressed: _openDrawer));
      case AnalyticsSection.trends:
        return SafeArea(child: TrendsScreen(onMenuPressed: _openDrawer));
      case AnalyticsSection.forecast:
        return SafeArea(child: ForecastScreen(onMenuPressed: _openDrawer));
      case AnalyticsSection.insights:
        return SafeArea(child: InsightsScreen(onMenuPressed: _openDrawer));
      case AnalyticsSection.loyalty:
        return SafeArea(child: LoyaltyScreen(onMenuPressed: _openDrawer));
      case AnalyticsSection.outletComparison:
        return SafeArea(
          child: OutletComparisonScreen(onMenuPressed: _openDrawer),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AnalyticsTheme.mainBackground,
      drawer: _buildDrawer(),
      body: SafeArea(child: _getCurrentScreen()),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AnalyticsTheme.mainBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AnalyticsTheme.glassCard(),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: AnalyticsTheme.primaryGold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analytics',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AnalyticsTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Premium Dashboard',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AnalyticsTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Overview',
                    section: AnalyticsSection.overview,
                  ),
                  _buildDrawerItem(
                    icon: Icons.trending_up_rounded,
                    title: 'Trends',
                    section: AnalyticsSection.trends,
                  ),
                  _buildDrawerItem(
                    icon: Icons.auto_graph_rounded,
                    title: 'Forecast',
                    section: AnalyticsSection.forecast,
                  ),
                  _buildDrawerItem(
                    icon: Icons.lightbulb_rounded,
                    title: 'Insights',
                    section: AnalyticsSection.insights,
                  ),
                  _buildDrawerItem(
                    icon: Icons.favorite_rounded,
                    title: 'Loyalty',
                    section: AnalyticsSection.loyalty,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white10, thickness: 1),
                  ),

                  _buildDrawerItem(
                    icon: Icons.store_rounded,
                    title: 'Outlet Comparison',
                    section: AnalyticsSection.outletComparison,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required AnalyticsSection section,
  }) {
    final isSelected = _currentSection == section;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentSection = section;
            });
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: isSelected ? AnalyticsTheme.selectedDrawerItem() : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.secondaryText,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AnalyticsTheme.primaryGold
                          : AnalyticsTheme.primaryText,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AnalyticsTheme.primaryGold,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
