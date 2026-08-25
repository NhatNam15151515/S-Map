# ==============================================================================
# S-Map Android ProGuard & R8 Configuration
# ==============================================================================

# Keep attributes needed for Reflection & Generic Type Inference
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# ------------------------------------------------------------------------------
# GraphHopper Core Rules (Critical: Reflection-based Algorithm/Weighting Factories)
# ------------------------------------------------------------------------------
-keep class com.graphhopper.** { *; }
-dontwarn com.graphhopper.**

# ------------------------------------------------------------------------------
# High Performance Primitive Collections (HPPC) used by GraphHopper
# ------------------------------------------------------------------------------
-keep class com.carrotsearch.hppc.** { *; }
-dontwarn com.carrotsearch.hppc.**

# ------------------------------------------------------------------------------
# Logging (SLF4J Android)
# ------------------------------------------------------------------------------
-keep class org.slf4j.** { *; }
-dontwarn org.slf4j.**

# ------------------------------------------------------------------------------
# Suppress Missing Class Warnings for Optional Transitive GraphHopper Dependencies
# (StAX XML parsers, Osmosis Protobuf, OSGi Annotations)
# ------------------------------------------------------------------------------
-dontwarn aQute.bnd.annotation.spi.ServiceProvider
-dontwarn com.google.protobuf.**
-dontwarn javax.xml.stream.**
-dontwarn org.codehaus.stax2.**
-dontwarn com.fasterxml.jackson.**
-dontwarn org.openstreetmap.osmosis.**

# ------------------------------------------------------------------------------
# S-Map Native Routing Module & Models (Prevent MethodChannel serialization strip)
# ------------------------------------------------------------------------------
-keep class com.vnsmap.app.routing.** { *; }
-keepclassmembers class com.vnsmap.app.routing.models.** { *; }
-keep class javax.lang.model.** { *; }

