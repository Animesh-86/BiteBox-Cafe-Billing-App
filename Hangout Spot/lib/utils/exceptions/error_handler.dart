import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_exceptions.dart';

/// Centralized error handler that converts technical exceptions
/// into user-friendly AppException instances
class ErrorHandler {
  /// Convert any exception into an AppException with user-friendly message
  static AppException handle(dynamic error, {String? context}) {
    // Log the technical error for debugging
    _logError(error, context);

    // Convert known exception types to AppException
    if (error is AppException) {
      return error;
    }

    // Firebase Auth errors
    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthError(error);
    }

    // Firebase Database errors
    if (error is FirebaseException) {
      return _handleFirebaseDatabaseError(error);
    }

    // Network/Timeout errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException') ||
        error.toString().contains('Failed host lookup')) {
      return NetworkException(
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    if (error.toString().contains('TimeoutException') ||
        error.toString().contains('timed out')) {
      return TimeoutException(
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    // Bluetooth errors
    if (error.toString().contains('Bluetooth') ||
        error.toString().contains('bluetooth')) {
      return BluetoothException(
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    // Permission errors
    if (error.toString().contains('permission') ||
        error.toString().contains('Permission') ||
        error.toString().contains('PERMISSION_DENIED')) {
      return PermissionException(
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    // Generic Exception with message
    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');

      // Check if it's a user-facing message (doesn't contain stack trace or technical jargon)
      if (_isUserFriendlyMessage(message)) {
        return OperationFailedException(
          userMessage: message,
          originalError: error,
        );
      }

      return OperationFailedException(
        technicalMessage: message,
        originalError: error,
      );
    }

    // Unknown error
    return OperationFailedException(
      userMessage: 'Something went wrong. Please try again.',
      technicalMessage: error.toString(),
      originalError: error,
    );
  }

  /// Handle Firebase Auth specific errors
  static AppException _handleFirebaseAuthError(FirebaseAuthException error) {
    String userMessage;

    switch (error.code) {
      case 'user-not-found':
        userMessage = 'No account found with this email.';
        break;
      case 'wrong-password':
        userMessage = 'Incorrect password. Please try again.';
        break;
      case 'email-already-in-use':
        userMessage = 'This email is already registered.';
        break;
      case 'invalid-email':
        userMessage = 'Please enter a valid email address.';
        break;
      case 'user-disabled':
        userMessage = 'This account has been disabled.';
        break;
      case 'weak-password':
        userMessage = 'Please choose a stronger password.';
        break;
      case 'network-request-failed':
        userMessage = 'Network error. Please check your connection.';
        break;
      case 'too-many-requests':
        userMessage = 'Too many attempts. Please try again later.';
        break;
      case 'requires-recent-login':
        userMessage = 'Please sign in again to continue.';
        break;
      default:
        userMessage = 'Authentication failed. Please try again.';
    }

    return AuthException(
      userMessage: userMessage,
      technicalMessage: '${error.code}: ${error.message}',
      originalError: error,
    );
  }

  /// Handle Firebase Database errors
  static AppException _handleFirebaseDatabaseError(FirebaseException error) {
    String userMessage;

    switch (error.code) {
      case 'permission-denied':
      case 'PERMISSION_DENIED':
        userMessage = 'Access denied. Please check your permissions.';
        break;
      case 'unavailable':
        userMessage = 'Service temporarily unavailable. Please try again.';
        break;
      case 'network-error':
        userMessage = 'Network error. Please check your connection.';
        break;
      case 'write-canceled':
        userMessage = 'Operation was cancelled. Please try again.';
        break;
      case 'data-stale':
        userMessage = 'Data is outdated. Please refresh and try again.';
        break;
      case 'disconnected':
        userMessage = 'Connection lost. Please check your internet.';
        break;
      default:
        userMessage = 'Failed to sync data. Please try again.';
    }

    return RealtimeDBException(
      userMessage: userMessage,
      technicalMessage: '${error.code}: ${error.message}',
      originalError: error,
    );
  }

  /// Check if a message is already user-friendly
  static bool _isUserFriendlyMessage(String message) {
    // Technical indicators
    final technicalPatterns = [
      'Exception',
      'Error',
      'null',
      'Null',
      'Stack trace',
      'at line',
      'package:',
      'dart:',
      '{',
      '}',
      'RangeError',
      'FormatException',
      'StateError',
      'AssertionError',
    ];

    for (final pattern in technicalPatterns) {
      if (message.contains(pattern)) {
        return false;
      }
    }

    return message.length < 100; // User messages are typically short
  }

  /// Log error for debugging (only in debug mode)
  static void _logError(dynamic error, String? context) {
    if (kDebugMode) {
      final contextStr = context != null ? '[$context] ' : '';
      debugPrint('🔴 ${contextStr}Error: $error');

      // Print stack trace if available
      if (error is Error && error.stackTrace != null) {
        debugPrint('Stack trace:\n${error.stackTrace}');
      }
    }
  }

  /// Create a context-specific error handler
  static AppException handleWithContext(dynamic error, String context) {
    return handle(error, context: context);
  }

  /// Handle invoice-specific errors
  static AppException handleInvoiceError(dynamic error) {
    if (error.toString().contains('User not logged in')) {
      return AuthException(
        userMessage: 'Please sign in to generate invoices.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    if (error.toString().contains('Transaction failed')) {
      return InvoiceException(
        userMessage: 'Failed to generate invoice number. Please try again.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    return InvoiceException(
      technicalMessage: error.toString(),
      originalError: error,
    );
  }

  /// Handle order-specific errors
  static AppException handleOrderError(dynamic error) {
    if (error.toString().contains('empty') ||
        error.toString().contains('Empty')) {
      return OrderException(
        userMessage: 'Cannot create order with empty items.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    if (error.toString().contains('cart') ||
        error.toString().contains('Cart')) {
      return OrderException(
        userMessage: 'Cart error. Please refresh and try again.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    return OrderException(
      technicalMessage: error.toString(),
      originalError: error,
    );
  }

  /// Handle printing errors
  static AppException handlePrintingError(dynamic error) {
    if (error.toString().contains('No Bluetooth devices')) {
      return BluetoothException(
        userMessage: 'No printer found. Please pair your Bluetooth printer.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    if (error.toString().contains('Connection failed') ||
        error.toString().contains('not connected')) {
      return BluetoothException(
        userMessage: 'Printer not connected. Please check your printer.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    if (error.toString().contains('No device selected')) {
      return PrintingException(
        userMessage: 'Please select a printer first.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    return PrintingException(
      technicalMessage: error.toString(),
      originalError: error,
    );
  }

  /// Handle export errors
  static AppException handleExportError(dynamic error) {
    if (error.toString().contains('permission') ||
        error.toString().contains('Permission')) {
      return PermissionException(
        userMessage: 'Permission denied. Please allow storage access.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    if (error.toString().contains('Storage') ||
        error.toString().contains('storage')) {
      return ExportException(
        userMessage: 'Insufficient storage. Please free up space.',
        technicalMessage: error.toString(),
        originalError: error,
      );
    }

    return ExportException(
      technicalMessage: error.toString(),
      originalError: error,
    );
  }
}
