# Keep kotlinx.serialization generated serializers for the model classes.
-keepclassmembers class com.vacantaurora.pricemonitor.model.** {
    *** Companion;
}
-keepclasseswithmembers class com.vacantaurora.pricemonitor.model.** {
    kotlinx.serialization.KSerializer serializer(...);
}
