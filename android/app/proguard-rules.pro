# ── Flutter engine ────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── App entry point ───────────────────────────────────────────────────────────
-keep class in.fomrahousing.fomra_ls.** { *; }

# ── Kotlin runtime ────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# ── Android internals ─────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ── Obfuscate everything else ─────────────────────────────────────────────────
-repackageclasses 'fh'
-allowaccessmodification
-overloadaggressively

-ignorewarnings
