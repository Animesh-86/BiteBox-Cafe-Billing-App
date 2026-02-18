/// Model representing user account metadata for device trust management
class UserMetadata {
  final String userId;
  final String? firstDeviceSessionId; // Track original owner device
  final List<String> trustedSessionIds; // Max 3 trusted devices
  final int maxTrustedDevices; // Default: 3
  final String? recoveryEmail; // For email-based recovery
  final DateTime? lastRecoveryRequest;

  UserMetadata({
    required this.userId,
    this.firstDeviceSessionId,
    this.trustedSessionIds = const [],
    this.maxTrustedDevices = 3,
    this.recoveryEmail,
    this.lastRecoveryRequest,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'firstDeviceSessionId': firstDeviceSessionId,
    'trustedSessionIds': trustedSessionIds,
    'maxTrustedDevices': maxTrustedDevices,
    'recoveryEmail': recoveryEmail,
    'lastRecoveryRequest': lastRecoveryRequest?.toIso8601String(),
  };

  /// Create from Firestore document
  factory UserMetadata.fromJson(Map<String, dynamic> json) {
    return UserMetadata(
      userId: json['userId'] as String,
      firstDeviceSessionId: json['firstDeviceSessionId'] as String?,
      trustedSessionIds:
          (json['trustedSessionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      maxTrustedDevices: json['maxTrustedDevices'] as int? ?? 3,
      recoveryEmail: json['recoveryEmail'] as String?,
      lastRecoveryRequest: json['lastRecoveryRequest'] != null
          ? DateTime.parse(json['lastRecoveryRequest'] as String)
          : null,
    );
  }

  /// Copy with method for updates
  UserMetadata copyWith({
    String? userId,
    String? firstDeviceSessionId,
    List<String>? trustedSessionIds,
    int? maxTrustedDevices,
    String? recoveryEmail,
    DateTime? lastRecoveryRequest,
  }) {
    return UserMetadata(
      userId: userId ?? this.userId,
      firstDeviceSessionId: firstDeviceSessionId ?? this.firstDeviceSessionId,
      trustedSessionIds: trustedSessionIds ?? this.trustedSessionIds,
      maxTrustedDevices: maxTrustedDevices ?? this.maxTrustedDevices,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      lastRecoveryRequest: lastRecoveryRequest ?? this.lastRecoveryRequest,
    );
  }
}
