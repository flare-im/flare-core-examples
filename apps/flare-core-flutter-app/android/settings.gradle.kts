pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // FCM 的客户端配置；只有 app/google-services.json 存在时 app 模块才应用它。
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")

// flare_core_flutter_push 的原生推送模块（FCM 服务、通知渠道、点击、权限）。flare-core-sdk 没有根工程，由宿主登记。
include(":flare-core-android-push")
project(":flare-core-android-push").projectDir =
    file("../../../../flare-commercial-client-runtime/packages/push/flare-core-android-push")
// 个推（国内安卓推送）：插件按类名启用它，模块由应用带进来；构建给了 FLARE_GETUI_APP_ID 才在登录后启动。
include(":flare-core-android-push-getui")
project(":flare-core-android-push-getui").projectDir =
    file("../../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/providers/getui")

// flare_core_flutter_update's installer. The host registers it: flare-core-sdk has no root project.
include(":flare-core-android-update")
project(":flare-core-android-update").projectDir =
    file("../../../../flare-commercial-client-runtime/packages/update/flare-core-android-update")

include(":flare-core-android-push-fcm")
project(":flare-core-android-push-fcm").projectDir = file("../../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/providers/fcm")

if (providers.gradleProperty("flareKeepAlive").orNull == "true") {
    include(":flare-core-android-keepalive")
    project(":flare-core-android-keepalive").projectDir =
        file("../../../../flare-commercial-client-runtime/packages/keepalive/flare-core-android-keepalive")
}

if (!providers.gradleProperty("FLARE_JPUSH_APP_KEY").orNull.isNullOrBlank()) {
    include(":flare-core-android-push-jpush")
    project(":flare-core-android-push-jpush").projectDir =
        file("../../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/providers/jpush")
}
