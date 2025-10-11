# Flutter plugins
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# Firebase
# Keep all Firebase classes to prevent R8 from removing essential code.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keepnames class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# uCrop Library
# This rule prevents the R8 shrinker from causing issues with the uCrop library.
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Kotlin Metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.metadata.**
-dontwarn kotlin.reflect.**

# Ignore common warnings that can safely be ignored during a release build.
-ignorewarnings