plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FCM：有 Firebase 客户端配置（app/google-services.json，不入库）时才用 Google 服务插件。没有时照常构建运行，
// 只是不登记 FCM 令牌，消息只走长连接。
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// 个推按构建启用，与原生 Android 应用的 FLARE_GETUI_APP_ID 同名：`--dart-define=FLARE_GETUI_APP_ID=<个推 app id>`。
// Flutter 把 --dart-define 逐条 base64 后以逗号串经 dart-defines 属性交给 Gradle：同一个值填个推 SDK 清单里的
// GETUI_APPID 占位符，Dart 侧读到它才在登录后启动个推。没给时模块照样编进来，运行时不初始化。
val getuiAppId: String =
    (project.findProperty("dart-defines") as String?)
        .orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { runCatching { String(java.util.Base64.getDecoder().decode(it), Charsets.UTF_8) }.getOrNull() }
        .firstOrNull { it.startsWith("FLARE_GETUI_APP_ID=") }
        ?.substringAfter("=")
        ?.trim()
        .orEmpty()

android {
    namespace = "com.example.flare_im"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flare_im"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GETUI_APPID"] = getuiAppId
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    // flare_core_flutter_push 按类名启用个推，插件自己不依赖它：可选模块由应用带进来。
    implementation(project(":flare-core-android-push-getui"))
}

val verifyRustFfiAndroid by tasks.registering(Exec::class) {
    workingDir = rootProject.file("../../../../../flare-core-sdk/examples")
    commandLine("cargo", "xtask", "build", "android-verify")
    environment("FLUTTER_EXAMPLE_DIR", rootProject.projectDir.parentFile.absolutePath)
}

tasks.matching { task ->
    task.name.startsWith("merge") && task.name.endsWith("NativeLibs")
}.configureEach {
    dependsOn(verifyRustFfiAndroid)
}
