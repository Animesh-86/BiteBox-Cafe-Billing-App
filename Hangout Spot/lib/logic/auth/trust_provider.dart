import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/repositories/auth_repository.dart';

/// Provider to check if the current device is trusted.
/// Returns false by default if status is loading or error.
final isDeviceTrustedProvider = FutureProvider<bool>((ref) async {
  final sessionManager = ref.watch(authRepositoryProvider).sessionManager;
  // Listen to auth state to re-trigger check on login/logout
  ref.watch(authStateProvider);

  return await sessionManager.isCurrentDeviceTrusted();
});

// Since authRepository doesn't expose sessionManager directly in the previous snippet,
// we might need to adjust AuthRepository or access SessionManager differently.
// Let's check AuthRepository again to be sure.
