import 'package:flutter/material.dart';
import '../exceptions/app_exceptions.dart';

/// UI Helper for displaying errors to users in a consistent,
/// professional manner across the app
class ErrorUI {
  /// Show error as SnackBar (for non-critical errors)
  static void showSnackBar(
    BuildContext context,
    dynamic error, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    final appException = error is AppException ? error : null;
    final message = appException?.userMessage ?? 'Something went wrong';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(appException),
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show success message as SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show error as Dialog (for critical errors requiring acknowledgment)
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;

    final appException = error is AppException ? error : null;
    final message = appException?.userMessage ?? 'Something went wrong';
    final errorTitle = title ?? _getErrorTitle(appException);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _getErrorIcon(appException),
              color: _getErrorColor(appException),
            ),
            const SizedBox(width: 12),
            Text(errorTitle),
          ],
        ),
      content: SafeArea(child: Text(message, style: const TextStyle(fontSize: 14))),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error as inline widget (for forms and cards)
  static Widget inlineError(dynamic error, {VoidCallback? onRetry}) {
    final appException = error is AppException ? error : null;
    final message = appException?.userMessage ?? 'Something went wrong';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getErrorColor(appException).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getErrorColor(appException).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getErrorIcon(appException),
            color: _getErrorColor(appException),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: _getErrorColor(appException),
                fontSize: 14,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  /// Show loading indicator with error handling
  static Widget loadingOrError({
    required bool isLoading,
    dynamic error,
    VoidCallback? onRetry,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: inlineError(error, onRetry: onRetry),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Get appropriate color for error type
  static Color _getErrorColor(AppException? error) {
    if (error == null) return Colors.red;

    if (error is NetworkException) return Colors.orange;
    if (error is AuthException) return Colors.deepOrange;
    if (error is ValidationException) return Colors.amber;
    if (error is TimeoutException) return Colors.orange;
    if (error is PermissionException) return Colors.deepOrange;

    return Colors.red;
  }

  /// Get appropriate icon for error type
  static IconData _getErrorIcon(AppException? error) {
    if (error == null) return Icons.error_outline;

    if (error is NetworkException) return Icons.wifi_off;
    if (error is AuthException) return Icons.lock_outline;
    if (error is ValidationException) return Icons.warning_amber;
    if (error is TimeoutException) return Icons.access_time;
    if (error is PermissionException) return Icons.block;
    if (error is PrintingException) return Icons.print_disabled;
    if (error is BluetoothException) return Icons.bluetooth_disabled;

    return Icons.error_outline;
  }

  /// Get appropriate title for error type
  static String _getErrorTitle(AppException? error) {
    if (error == null) return 'Error';

    if (error is NetworkException) return 'Connection Error';
    if (error is AuthException) return 'Authentication Error';
    if (error is ValidationException) return 'Invalid Input';
    if (error is TimeoutException) return 'Request Timeout';
    if (error is PermissionException) return 'Permission Required';
    if (error is PrintingException) return 'Printing Error';
    if (error is BluetoothException) return 'Bluetooth Error';
    if (error is InvoiceException) return 'Invoice Error';
    if (error is OrderException) return 'Order Error';
    if (error is ExportException) return 'Export Error';

    return 'Error';
  }

  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show info message
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
