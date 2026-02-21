import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/data/local/seed_data.dart';
import 'package:hangout_spot/ui/screens/main_screen.dart';
import 'package:hangout_spot/ui/screens/auth/login_screen.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/services/realtime_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _navigated = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    // Defer _seedData() to after first frame to avoid ref.read() in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedData();
    });
    // Safety timeout: 4 seconds max for splash
    _timeoutTimer = Timer(const Duration(seconds: 4), () {
      _navigateAway();
    });
  }

  // ... (existing imports)

  Future<void> _seedData() async {
    try {
      final menuRepo = ref.read(menuRepositoryProvider);
      await MenuSeeder.seed(menuRepo);

      final db = ref.read(appDatabaseProvider);
      await LocationSeeder.seed(db);
    } catch (e) {
      debugPrint("Seeding error: $e");
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
        debugPrint('🧹 Factory reset detected - skipping cloud restore');
        return;
      }
      final skipAutoRestore = prefs.getBool('skip_auto_restore') ?? false;
      if (skipAutoRestore) {
        debugPrint('⏭️ Auto-restore disabled until manual restore');
        return;
      }
      final lastSyncVersion = prefs.getString('last_sync_app_version');
      const currentVersion = '1.0.0'; // TODO: Get from package_info

      // Force sync if:
      // 1. Never synced before (fresh install)
      // 2. App version changed (new APK installed)
      if (lastSyncVersion != currentVersion) {
        debugPrint('🔄 Fresh install detected - forcing cloud sync...');

        try {
          final syncRepo = ref.read(syncRepositoryProvider);
          await syncRepo.restoreData();

          // Start real-time listener for order sync
          final orderService = ref.read(realTimeOrderServiceProvider);
          orderService.startListening();

          // Save current version
          await prefs.setString('last_sync_app_version', currentVersion);
          debugPrint('✅ Cloud sync completed');
        } catch (e) {
          debugPrint('⚠️ Cloud sync failed (might be new user): $e');
          // Continue anyway - might be a new account with no data
        }
      } else {
        // Not a fresh install, but still start real-time listener
        final orderService = ref.read(realTimeOrderServiceProvider);
        orderService.startListening();
        debugPrint('✅ Real-time order sync started');
      }
    } catch (e) {
      debugPrint('⚠️ Sync check failed: $e');
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/splash.mp4');
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
        _controller.setLooping(false);
        _controller.addListener(_checkVideoEnd);
      }
    } catch (e) {
      debugPrint("Video Splash Error: $e");
      _navigateAway();
    }
  }

  void _checkVideoEnd() {
    if (_controller.value.isInitialized &&
        !_controller.value.isPlaying &&
        _controller.value.position >= _controller.value.duration) {
      _navigateAway();
    }
  }

  Future<void> _navigateAway() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    _controller.removeListener(_checkVideoEnd);

    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;

    if (!mounted) return;

    if (user != null) {
      // Already logged in - check if we need to force sync
      await _checkAndSyncData();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      // Not logged in — go to login screen
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
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _navigateAway, // Tap to skip
        child: Center(
          child: _initialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
