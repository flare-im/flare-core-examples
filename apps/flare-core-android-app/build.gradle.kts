plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
    // Applied by the app module only when the Firebase client configuration is present (see app/build.gradle.kts).
    id("com.google.gms.google-services") version "4.4.2" apply false
}
