# ── Flutter ────────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Firebase ───────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }

# Firebase Auth (Google Sign-In)
-keep class com.google.android.gms.auth.** { *; }

# ── Gson (used by Firebase + Dio) ──────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ── Google Maps ────────────────────────────────────────────────────────────────
-keep class com.google.maps.** { *; }
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.maps.**

# ── OkHttp (Dio) ───────────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── RevenueCat ─────────────────────────────────────────────────────────────────
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ── Hive (local DB) ────────────────────────────────────────────────────────────
-keep class com.hivedb.** { *; }
-keep @com.hivedb.annotations.HiveType class * { *; }
-keep @com.hivedb.annotations.HiveField class * { *; }

# ── Keep app model classes (Hive + Firestore serialization) ────────────────────
-keep class com.pacmate.app.** { *; }
-keepclassmembers class com.pacmate.app.** { *; }

# ── Kotlin coroutines ──────────────────────────────────────────────────────────
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ── Suppress common warnings ──────────────────────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
