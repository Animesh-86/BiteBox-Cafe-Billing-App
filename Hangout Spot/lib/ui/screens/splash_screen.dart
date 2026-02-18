import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';
import 'package:hangout_spot/data/repositories/menu_repository.dart';
import 'package:hangout_spot/data/local/seed_data.dart';
import 'package:hangout_spot/ui/screens/main_screen.dart';

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

  Future<void> _seedData() async {
    try {
      final menuRepo = ref.read(menuRepositoryProvider);
      await MenuSeeder.seed(menuRepo);
    } catch (e) {
      debugPrint("Seeding error: $e");
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
    _controller.removeListener(_checkVideoEnd); // Clean listener

    // Check Auth - if no user exists, use demo account or create anonymous session
    final authRepo = ref.read(authRepositoryProvider);
    var user = authRepo.currentUser;

    // If no user, attempt anonymous sign-in for demo/local POS usage
    if (user == null) {
      try {
        await authRepo.signInAnonymously();
        user = authRepo.currentUser;
      } catch (e) {
        debugPrint("Anonymous sign-in failed (Provider likely disabled): $e");
        // GRACEFUL FAIL: Proceed to MainScreen anyway.
        // The app can function in 'offline' mode or prompt for login later.
      }
    }

    // Always navigate to MainScreen (no login required for POS)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScreen(),
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
