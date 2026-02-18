import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Service for getting Android device information
class DeviceInfoService {
  /// Get comprehensive device information for Android
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    final androidInfo = await deviceInfo.androidInfo;

    // Determine if phone or tablet (simplified - can be enhanced)
    final deviceType = androidInfo.isPhysicalDevice
        ? 'Phone' // Default to phone, can enhance with screen size detection
        : 'Emulator';

    // Create readable device name
    final brand = androidInfo.brand.isNotEmpty
        ? _capitalize(androidInfo.brand)
        : 'Unknown';
    final model = androidInfo.model.isNotEmpty ? androidInfo.model : 'Device';

    final deviceName = '$brand $model'.replaceAll('_', ' ').trim();

    return {
      'deviceName': deviceName,
      'deviceType': deviceType,
      'appVersion': packageInfo.version,
      'androidVersion': 'Android ${androidInfo.version.release}',
      'manufacturer': androidInfo.manufacturer,
      'model': androidInfo.model,
    };
  }

  /// Capitalize first letter of a string
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Generate unique session ID
  static String generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}';
  }
}
