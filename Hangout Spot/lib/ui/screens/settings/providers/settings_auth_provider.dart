import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the last time the user successfully entered their password for Settings access.
/// If non-null and within the timeout duration, access is granted automatically.
final settingsAuthSessionProvider = StateProvider<DateTime?>((ref) => null);

/// The duration a settings password session stays valid
const kSettingsAuthTimeout = Duration(minutes: 15);
