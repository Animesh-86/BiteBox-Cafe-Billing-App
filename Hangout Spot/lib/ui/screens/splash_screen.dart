import 'package:hangout_spot/utils/log_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/data/local/seed_data.dart';
import 'package:hangout_spot/ui/screens/main_screen.dart';
import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/services/realtime_order_service.dart';
import 'package:hangout_spot/services/auto_sync_service.dart';
import 'package:hangout_spot/data/providers/inventory_providers.dart';
import 'package:hangout_spot/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hangout_spot/data/providers/realtime_services_provider.dart';
import 'package:hangout_spot/services/customer_sync_listener_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Defer _seedData() to after first frame to avoid ref.read() in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndNavigate();
    });
  }

  /// Run seeding + cloud sync, then navigate. A generous safety timeout
  /// prevents the splash from getting stuck forever if Firebase hangs.
  Future<void> _initAndNavigate() async {
    await _seedData();

    // Navigate as soon as sync finishes OR after a generous 30-second timeout
    await Future.any([
      _navigateAway(),
      Future.delayed(const Duration(seconds: 30)),
    ]);

    // If _navigateAway() hasn't completed yet, force navigation
    _forceNavigate();
  }

  Future<void> _seedData() async {
    try {
      // NOTE: Menu seeding is handled by MenuSeeder.seedDefaultMenu()
      // inside app_database.dart during DB initialization.
      // The old MenuSeeder.seed(menuRepo) was removed because it created
      // duplicate items with different UUIDs and casing.

      final db = ref.read(appDatabaseProvider);
      await LocationSeeder.seed(db);
    } catch (e) {
      logDebug("Seeding error: $e");
    }
  }

  /// Check if fresh install and force cloud sync
  Future<void> _checkAndSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resetCompleted = prefs.getBool('factory_reset_completed') ?? false;
      if (resetCompleted) {
        await prefs.setBool('factory_reset_completed', false);
        await prefs.remove('last_sync_app_version');
        logDebug('🧹 Factory reset detected - skipping cloud restore');
        return;
      }
      final skipAutoRestore = prefs.getBool('skip_auto_restore') ?? false;
      if (skipAutoRestore) {
        logDebug('⏭️ Auto-restore disabled until manual restore');
        return;
      }
      final lastSyncVersion = prefs.getString('last_sync_app_version');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Force sync if:
      // 1. Never synced before (fresh install)
      // 2. App version changed (new APK installed)
      if (lastSyncVersion != currentVersion) {
        logDebug('🔄 Fresh install detected - forcing cloud sync...');

        try {
          final syncRepo = ref.read(syncRepositoryProvider);
          await syncRepo.restoreData();
          // Bump so dashboard live stats show restored data
          ref.read(remoteSyncGenerationProvider.notifier).state++;

          // Start real-time listener for order sync
          final orderService = ref.read(realTimeOrderServiceProvider);
          orderService.startListening();

          // Save current version
          await prefs.setString('last_sync_app_version', currentVersion);
          logDebug('✅ Cloud sync completed');
        } catch (e) {
          logDebug('⚠️ Cloud sync failed (might be new user): $e');
          // Continue anyway - might be a new account with no data
        }
      } else {
        // Not a fresh install, but still start real-time listener
        final orderService = ref.read(realTimeOrderServiceProvider);
        orderService.startListening();
        logDebug('✅ Real-time order sync started');
      }
    } catch (e) {
      logDebug('⚠️ Sync check failed: $e');
    }
  }

  /// Reschedule all enabled time-based reminders on app startup so they
  /// survive cold restarts and OS-level notification pruning.
  Future<void> _rescheduleReminders() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final reminders = await repo.fetchReminders();
      await NotificationService.instance.rescheduleReminders(
        reminders
            .map(
              (r) => (
                id: r.id,
                title: r.title,
                type: r.type,
                time: r.time,
                isEnabled: r.isEnabled,
              ),
            )
            .toList(),
      );
    } catch (e) {
      logDebug('⚠️ Failed to reschedule reminders: $e');
    }
  }

  Future<void> _navigateAway() async {
    if (!mounted || _navigated) return;

    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;

    if (user != null) {
      // Already logged in – sync first, then navigate
      await _checkAndSyncData();

      // Start periodic auto-sync (reads enabled/interval from SharedPreferences)
      ref.read(autoSyncServiceProvider).start();

      // Start real-time Firestore listener so customer changes from any device
      // are immediately reflected in the local DB on this device.
      ref.read(customerSyncListenerServiceProvider).start();

      // Restore session tracking so the heartbeat and remote-logout
      // listener keep working after a cold restart.
      await authRepo.sessionManager.startSession();

      // Reschedule time-based inventory reminders so they survive app restarts
      await _rescheduleReminders();
    }

    _forceNavigate();
  }

  /// Navigate to the appropriate screen (MainScreen or LoginScreen).
  /// Safe to call multiple times — only navigates once.
  void _forceNavigate() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;

    if (!mounted) return;

    if (user != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: GestureDetector(
        onTap: _navigateAway,
        child: Center(
          child: Image.asset(
            'assets/logo.png',
            width: 200, // Roughly matching native splash proportions
          ),
        ),
      ),
    );
  }
}
