import 'package:hangout_spot/utils/log_utils.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hangout_spot/data/repositories/sync_repository.dart';
import 'package:hangout_spot/data/repositories/order_repository.dart';
import 'package:hangout_spot/utils/constants/app_keys.dart';

/// Periodically backs up non-order data and syncs unsynced orders.
/// Also listens to Firebase RTDB `.info/connected` to trigger an immediate
/// sync as soon as network connectivity is restored, ensuring minimal
/// data-sync delay for multi-device scenarios.
///
/// Reads settings from SharedPreferences:
///   [CLOUD_AUTO_SYNC_ENABLED_KEY]  – 'true' / 'false'
///   [CLOUD_AUTO_SYNC_INTERVAL_KEY] – minutes between syncs (default 2)
///
/// Call [start] once after login (e.g. from Splash / MainScreen).
/// Call [restart] whenever the user changes sync settings in the UI.
/// Call [stop] on logout.
class AutoSyncService {
  final SyncRepository _syncRepo;
  final OrderRepository _orderRepo;

  Timer? _timer;
  bool _isSyncing = false;
  bool _isRunning = false;

  /// Firebase RTDB connectivity listener
  StreamSubscription? _connectivitySub;
  bool _wasDisconnected = false;

  AutoSyncService(this._syncRepo, this._orderRepo);

  bool get isRunning => _isRunning;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Start the auto-sync timer using the current SharedPreferences settings.
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getString(CLOUD_AUTO_SYNC_ENABLED_KEY) == 'true';
    if (!enabled) {
      logDebug('⏸️ Auto-sync disabled by user');
      return;
    }

    final minutes =
        int.tryParse(prefs.getString(CLOUD_AUTO_SYNC_INTERVAL_KEY) ?? '2') ?? 2;

    _scheduleTimer(Duration(minutes: minutes));
    _startConnectivityListener();
    logDebug('🔄 Auto-Sync started (every $minutes min, connectivity-aware)');
  }

  /// Stop the running timer (e.g. on logout or when user disables auto-sync).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _wasDisconnected = false;
    _isRunning = false;
    logDebug('⏹️ Auto-Sync stopped');
  }

  /// Re-read settings and restart the timer. Call this when the user
  /// toggles the switch or changes the interval in Settings.
  Future<void> restart() async {
    stop();
    await start();
  }

  // ─── Internals ────────────────────────────────────────────────────────────

  void _scheduleTimer(Duration interval) {
    _timer?.cancel();
    _isRunning = true;

    // Run once immediately, then on interval
    _tick();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  /// Listen to Firebase RTDB `.info/connected` to detect connectivity changes.
  /// When the device goes offline and comes back online, trigger an immediate
  /// sync so that orders created offline are pushed without waiting for the
  /// next periodic tick.
  void _startConnectivityListener() {
    _connectivitySub?.cancel();
    _wasDisconnected = false;

    final connectedRef = FirebaseDatabase.instance.ref('.info/connected');
    _connectivitySub = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;

      if (!connected) {
        _wasDisconnected = true;
        logDebug('📡 Firebase disconnected — will sync on reconnect');
      } else if (_wasDisconnected) {
        // Just reconnected after being offline
        _wasDisconnected = false;
        logDebug('📡 Firebase reconnected — triggering immediate sync');
        _tick();
      }
    });
  }

  Future<void> _tick() async {
    if (_isSyncing) return; // skip if previous sync still running
    _isSyncing = true;
    try {
      // 1. Push any unsynced orders first (individual doc writes)
      await _orderRepo.syncUnsyncedOrders();

      // 2. Backup bounded data (menu, customers, config, prefs)
      await _syncRepo.backupData();

      logDebug('✅ Auto-sync tick completed');
    } catch (e) {
      logDebug('⚠️ Auto-sync tick failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Dispose resources. Must be called when the service is discarded.
  void dispose() {
    stop();
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);
  final service = AutoSyncService(syncRepo, orderRepo);

  ref.onDispose(() => service.dispose());

  return service;
});