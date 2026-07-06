# Google Play Services & Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase SDKs (Auth, Firestore, Messaging, etc.)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Generic attributes to preserve signature information
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
