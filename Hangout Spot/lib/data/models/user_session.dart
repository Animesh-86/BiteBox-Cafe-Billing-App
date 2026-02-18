import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user session on a device
class UserSession {
  final String sessionId;
  final String userId;
  final String deviceName;
  final String deviceType; // 'Phone', 'Tablet', 'Emulator'
  final String appVersion;
  final String? outletId;
  final DateTime lastActivity;
  final String status; // 'active', 'logged_out'
  final DateTime createdAt;
  final String? androidVersion;

  // Trust & Recovery Fields
  final String trustLevel; // 'trusted', 'approved', 'pending'
  final DateTime? approvedAt;
  final String? approvedBy; // sessionId of device that approved
  final int trustClaimAttempts; // Track password claim attempts
  final DateTime? lastClaimAttempt;

  UserSession({
    required this.sessionId,
    required this.userId,
    required this.deviceName,
    required this.deviceType,
    required this.appVersion,
    this.outletId,
    required this.lastActivity,
    required this.status,
    required this.createdAt,
    this.androidVersion,
    this.trustLevel = 'pending',
    this.approvedAt,
    this.approvedBy,
    this.trustClaimAttempts = 0,
    this.lastClaimAttempt,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'userId': userId,
    'deviceName': deviceName,
    'deviceType': deviceType,
    'appVersion': appVersion,
    'outletId': outletId,
    'lastActivity': FieldValue.serverTimestamp(),
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'androidVersion': androidVersion,
    'trustLevel': trustLevel,
    'approvedAt': approvedAt?.toIso8601String(),
    'approvedBy': approvedBy,
    'trustClaimAttempts': trustClaimAttempts,
    'lastClaimAttempt': lastClaimAttempt?.toIso8601String(),
  };

  /// Create from Firestore document
  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      deviceName: json['deviceName'] as String,
      deviceType: json['deviceType'] as String,
      appVersion: json['appVersion'] as String,
      outletId: json['outletId'] as String?,
      lastActivity: (json['lastActivity'] as Timestamp).toDate(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      androidVersion: json['androidVersion'] as String?,
      trustLevel: json['trustLevel'] as String? ?? 'pending',
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      approvedBy: json['approvedBy'] as String?,
      trustClaimAttempts: json['trustClaimAttempts'] as int? ?? 0,
      lastClaimAttempt: json['lastClaimAttempt'] != null
          ? DateTime.parse(json['lastClaimAttempt'] as String)
          : null,
    );
  }

  /// Copy with method for updates
  UserSession copyWith({
    String? sessionId,
    String? userId,
    String? deviceName,
    String? deviceType,
    String? appVersion,
    String? outletId,
    DateTime? lastActivity,
    String? status,
    DateTime? createdAt,
    String? androidVersion,
    String? trustLevel,
    DateTime? approvedAt,
    String? approvedBy,
    int? trustClaimAttempts,
    DateTime? lastClaimAttempt,
  }) {
    return UserSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      appVersion: appVersion ?? this.appVersion,
      outletId: outletId ?? this.outletId,
      lastActivity: lastActivity ?? this.lastActivity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      androidVersion: androidVersion ?? this.androidVersion,
      trustLevel: trustLevel ?? this.trustLevel,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      trustClaimAttempts: trustClaimAttempts ?? this.trustClaimAttempts,
      lastClaimAttempt: lastClaimAttempt ?? this.lastClaimAttempt,
    );
  }
}
