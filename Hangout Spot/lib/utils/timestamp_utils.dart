import 'package:cloud_firestore/cloud_firestore.dart';

/// DateTime field names used by Drift-generated model classes.
///
/// When Firestore data is passed to Drift's `fromJson`, these fields must be
/// ISO 8601 strings. Cloud data may contain Firestore [Timestamp] objects or
/// raw epoch integers instead — this helper normalises them.
const _dateTimeKeys = {'createdAt', 'lastVisit', 'lastSyncedAt', 'updatedAt'};

/// Normalises a map coming from Firestore so that any DateTime-typed field
/// is an ISO 8601 string, which is what Drift's default [ValueSerializer]
/// expects inside `fromJson`.
///
/// Handles:
/// - [Timestamp] (Firestore native) → ISO 8601 string
/// - [int] epoch values (seconds / milliseconds / microseconds) → ISO 8601
/// - [String] → left as-is (assumed ISO 8601 already)
/// - `null` → left as-is
Map<String, dynamic> sanitiseDateFields(Map<String, dynamic> map) {
  final result = Map<String, dynamic>.from(map);
  for (final key in _dateTimeKeys) {
    if (!result.containsKey(key)) continue;
    final value = result[key];
    if (value == null || value is String) continue;

    if (value is Timestamp) {
      result[key] = value.toDate().toIso8601String();
    } else if (value is int) {
      result[key] = _epochIntToIso(value);
    }
  }
  return result;
}

/// Converts an integer epoch value to an ISO 8601 string.
///
/// Drift 2.x stores DateTimes as Unix epoch **seconds** in SQLite.
/// Firebase RTDB uses **milliseconds**.  Legacy data from incorrect
/// migrations may contain **microseconds**.  We distinguish by magnitude:
///
/// | Digits | Unit         | Example value              |
/// |--------|--------------|----------------------------|
/// | ≤ 10   | seconds      | 1_773_163_573              |
/// | 13     | milliseconds | 1_773_163_573_000          |
/// | 16     | microseconds | 1_773_163_573_000_000      |
/// | ≥ 19   | nanos / bad  | 1_773_163_573_000_000_000  |
String _epochIntToIso(int value) {
  if (value.abs() > 1e15) {
    // Microseconds or larger — convert via microseconds
    return DateTime.fromMicrosecondsSinceEpoch(value).toIso8601String();
  }
  if (value.abs() > 1e11) {
    // Milliseconds (13 digits)
    return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
  }
  // Seconds (≤ 10–11 digits) — Drift's native format
  return DateTime.fromMillisecondsSinceEpoch(value * 1000).toIso8601String();
}
