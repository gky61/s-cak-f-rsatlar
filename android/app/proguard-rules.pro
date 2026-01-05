# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Play Core (Flutter deferred components için)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Gson (Firebase kullanıyorsa)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# OkHttp (Firebase kullanıyorsa)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.squareup.okhttp.**
-keep class com.squareup.okhttp.** { *; }
-keep interface com.squareup.okhttp.** { *; }

# OkHttp3 (yeni versiyon)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.internal.platform.**

# Okio
-keep class okio.** { *; }
-dontwarn okio.**

# gRPC
-keep class io.grpc.** { *; }
-keepclassmembers class io.grpc.** { *; }
-dontwarn io.grpc.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep custom model classes (Firestore models)
-keep class com.sicakfirsatlar.sicak_firsatlar.models.** { *; }

# Keep all Dart/Flutter model classes (CRITICAL!)
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Firestore için tüm model sınıflarını koru
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.DocumentId <fields>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.ServerTimestamp <fields>;
}

# Reflection ile kullanılan sınıfları koru
-keepclassmembers class * {
    public <init>(...);
}

# Keep all public classes/methods/fields
-keepclasseswithmembers class * {
    public <methods>;
    public <fields>;
}

# Enum sınıfları
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep data classes
-keep class * extends java.lang.Exception

# UTF-8 encoding için
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Google Fonts - KRİTİK (Türkçe karakterler için)
-keep class com.google.fonts.** { *; }
-keep class com.google.android.gms.fonts.** { *; }
-dontwarn com.google.fonts.**
-keep class androidx.core.provider.** { *; }
-keep class androidx.core.content.** { *; }

# CachedNetworkImage için
-keep class com.example.cachednetworkimage.** { *; }
-keep class *.ImageProvider { *; }

# Flutter Text Rendering - KRİTİK (Yazıların kaybolmaması için)
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.util.** { *; }

# Android TextVie ve Font sınıfları
-keep class android.widget.TextView { *; }
-keep class android.text.** { *; }
-keep class android.graphics.Typeface { *; }
-keep class android.graphics.fonts.** { *; }
-keepclassmembers class android.graphics.Typeface {
    public static *** create(...);
}

# Skia (Flutter rendering engine)
-keep class org.skia.** { *; }
-dontwarn org.skia.**

# SQLite (SharedPreferences ve cache için)
-keep class android.database.** { *; }
-keep class android.database.sqlite.** { *; }

# Intl ve Localization (Türkçe desteği için)
-keep class java.text.** { *; }
-keep class java.util.Locale { *; }
-keep class android.icu.** { *; }

# Remove logging in release (optimizasyon için)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

