/// Custom exceptions for the app with user-friendly messages
/// These exceptions separate technical details from user-facing messages

/// Base app exception
class AppException implements Exception {
  final String userMessage;
  final String? technicalMessage;
  final String? errorCode;
  final dynamic originalError;

  AppException({
    required this.userMessage,
    this.technicalMessage,
    this.errorCode,
    this.originalError,
  });

  @override
  String toString() {
    if (technicalMessage != null) {
      return 'AppException: $userMessage (Technical: $technicalMessage)';
    }
    return 'AppException: $userMessage';
  }
}

/// Network/Connection related errors
class NetworkException extends AppException {
  NetworkException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ??
             'Unable to connect. Please check your internet connection.',
         technicalMessage: technicalMessage,
         errorCode: 'NETWORK_ERROR',
         originalError: originalError,
       );
}

/// Authentication related errors
class AuthException extends AppException {
  AuthException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ?? 'Authentication failed. Please sign in again.',
         technicalMessage: technicalMessage,
         errorCode: 'AUTH_ERROR',
         originalError: originalError,
       );
}

/// Database/Storage errors
class DatabaseException extends AppException {
  DatabaseException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage: userMessage ?? 'Failed to save data. Please try again.',
         technicalMessage: technicalMessage,
         errorCode: 'DATABASE_ERROR',
         originalError: originalError,
       );
}

/// Firebase Realtime Database errors
class RealtimeDBException extends AppException {
  RealtimeDBException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ??
             'Unable to sync data. Please check your connection.',
         technicalMessage: technicalMessage,
         errorCode: 'REALTIME_DB_ERROR',
         originalError: originalError,
       );
}

/// Permission/Authorization errors
class PermissionException extends AppException {
  PermissionException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ??
             'Permission denied. Please check your access rights.',
         technicalMessage: technicalMessage,
         errorCode: 'PERMISSION_ERROR',
         originalError: originalError,
       );
}

/// Validation errors (user input)
class ValidationException extends AppException {
  ValidationException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage: userMessage ?? 'Invalid input. Please check your data.',
         technicalMessage: technicalMessage,
         errorCode: 'VALIDATION_ERROR',
         originalError: originalError,
       );
}

/// Invoice/Counter errors
class InvoiceException extends AppException {
  InvoiceException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ??
             'Failed to generate invoice number. Please try again.',
         technicalMessage: technicalMessage,
         errorCode: 'INVOICE_ERROR',
         originalError: originalError,
       );
}

/// Printing related errors
class PrintingException extends AppException {
  PrintingException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ?? 'Printing failed. Please check your printer.',
         technicalMessage: technicalMessage,
         errorCode: 'PRINTING_ERROR',
         originalError: originalError,
       );
}

/// Bluetooth connection errors
class BluetoothException extends AppException {
  BluetoothException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ??
             'Bluetooth connection failed. Please check your device.',
         technicalMessage: technicalMessage,
         errorCode: 'BLUETOOTH_ERROR',
         originalError: originalError,
       );
}

/// Export/Import errors
class ExportException extends AppException {
  ExportException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage: userMessage ?? 'Failed to export data. Please try again.',
         technicalMessage: technicalMessage,
         errorCode: 'EXPORT_ERROR',
         originalError: originalError,
       );
}

/// Cart/Order processing errors
class OrderException extends AppException {
  OrderException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage:
             userMessage ?? 'Failed to process order. Please try again.',
         technicalMessage: technicalMessage,
         errorCode: 'ORDER_ERROR',
         originalError: originalError,
       );
}

/// Timeout errors
class TimeoutException extends AppException {
  TimeoutException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage: userMessage ?? 'Operation timed out. Please try again.',
         technicalMessage: technicalMessage,
         errorCode: 'TIMEOUT_ERROR',
         originalError: originalError,
       );
}

/// Generic operation failed error
class OperationFailedException extends AppException {
  OperationFailedException({
    String? userMessage,
    String? technicalMessage,
    dynamic originalError,
  }) : super(
         userMessage: userMessage ?? 'Operation failed. Please try again.',
         technicalMessage: technicalMessage,
         errorCode: 'OPERATION_FAILED',
         originalError: originalError,
       );
}
