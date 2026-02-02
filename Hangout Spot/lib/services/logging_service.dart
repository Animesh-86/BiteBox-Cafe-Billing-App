import 'dart:developer' as developer;

class LoggingService {
  static void logError(String message, Object error, [StackTrace? stack]) {
    developer.log(
      message,
      error: error,
      stackTrace: stack,
      name: 'HangoutSpot',
    );
  }

  static void logInfo(String message) {
    developer.log(message, name: 'HangoutSpot');
  }
}
