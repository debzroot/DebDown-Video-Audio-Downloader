/*
 * ProGuard rules for DebDown+
 * Keep yt-dlp binary and native libs
 */

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Kotlin
-keep class kotlin.** { *; }

# yt-dlp binary access
-keep class com.debdownplus.debdown_plus.** { *; }

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Share plus
-keep class com.example.share_plus.** { *; }

# File picker
-keep class com.mr.flutters.picker.** { *; }

# Native libs
-keep class * {
    native <methods>;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod