# Proguard keep rules for TigerBay Loyalty App
-dontoptimize

# Stripe Android rules & missing pushProvisioning suppressions
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.stripe.android.**
-keep class com.stripe.android.** { *; }

# Flutter InAppWebView rules
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview_android.**

