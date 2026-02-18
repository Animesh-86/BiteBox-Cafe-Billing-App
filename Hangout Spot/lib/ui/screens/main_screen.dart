import 'package:flutter/material.dart';
import 'package:hangout_spot/ui/screens/dashboard/dashboard_screen.dart';
import 'package:hangout_spot/ui/screens/analytics/analytics_screen.dart';
import 'package:hangout_spot/ui/screens/menu/manage_menu_screen.dart';
import 'package:hangout_spot/ui/screens/billing/billing_screen.dart';
import 'package:hangout_spot/ui/screens/settings/settings_screen.dart';
import 'package:hangout_spot/ui/widgets/sidebar_navigation.dart';
import 'package:animations/animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/logic/auth/trust_provider.dart';
import 'package:hangout_spot/ui/screens/settings/sections/locations_settings.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Watch critical providers
    final activeOutletAsync = ref.watch(activeOutletProvider);
    final isTrustedAsync = ref.watch(isDeviceTrustedProvider);

    // Determine if we should block access
    final hasActiveOutlet = activeOutletAsync.valueOrNull != null;
    final isTrusted = isTrustedAsync.valueOrNull ?? false;

    // 1. Mobile / Desktop Check
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    // BLOCKING LOGIC: If no outlet is selected
    if (!hasActiveOutlet) {
      if (isTrusted) {
        // Trusted device: Force them to select/create an outlet
        return const LocationsSettingsScreen();
      } else {
        // Untrusted device: Show waiting screen
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  "No Outlet Selected",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Ask a manager to select an outlet for this device.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 2. Midnight Coffee Structure
    // No more gradients, just the dark theme background
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // 3. Desktop Sidebar
          if (isDesktop)
            SidebarNavigation(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _currentIndex = idx),
            ),

          // 4. Main Content Area
          Expanded(
            child: PageTransitionSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation, secondaryAnimation) {
                return FadeThroughTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
              },
              child: _getPage(_currentIndex),
            ),
          ),
        ],
      ),

      // 5. Mobile Bottom Bar (Dark)
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              backgroundColor:
                  Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Theme.of(context).primaryColor,
              onDestinationSelected: (idx) {
                setState(() => _currentIndex = idx);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: 'Billing',
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  selectedIcon: Icon(Icons.restaurant_menu),
                  label: 'Menu',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const BillingScreen();
      case 2:
        return const ManageMenuScreen();
      case 3:
        return const AnalyticsScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }
}
