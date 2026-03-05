import 'package:flutter/foundation.dart';

/// Production-safe debug logger.
///
/// In debug builds, delegates to [debugPrint] (throttled, safe).
/// In release/profile builds, the call is completely eliminated by the
/// compiler because [kDebugMode] is a compile-time constant.
void logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
