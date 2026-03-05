# Flutter-specific ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Bluetooth thermal printer classes
-keep class com.example.blue_thermal_printer.** { *; }
-dontwarn com.example.blue_thermal_printer.**

# flutter_local_notifications — CRITICAL for scheduled alarms
# R8 must not strip the BroadcastReceivers that AlarmManager invokes
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson — used by flutter_local_notifications for notification serialization
-keepattributes Signature
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }
-dontwarn com.google.gson.**

# Keep classes used via reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
