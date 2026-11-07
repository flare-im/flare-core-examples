plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

/** The build settings that name where the SDK connects (see AppAccess.kt). */
val accessBuildSettings = listOf(
    "FLARE_ACCESS_JSON",
    "FLARE_DEV_WS_URL",
    "FLARE_DEV_QUIC_URL",
    "FLARE_DEV_CORE_API_URL",
    "FLARE_DEV_MEDIA_URL",
)

/** A Gradle property first, then the environment variable of the same name; blank is unset. */
fun accessBuildSetting(name: String): String =
    providers.gradleProperty(name).orElse(providers.environmentVariable(name)).orNull?.trim().orEmpty()

/** The release pre-build of every distribution flavor: the check below stops a release build there. */
val releasePreBuild = Regex("pre(Direct|Play)ReleaseBuild")

android {
    namespace = "com.flare.im.app"
    compileSdk = 35
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.flare.im.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += "arm64-v8a"
        }

        fun buildConfigString(value: String): String =
            "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

        // 接入配置（core SDK 的 `sdkConfig.access`），见 AppAccess.kt。每项先读 Gradle 属性
        // （`-PFLARE_DEV_WS_URL=...`），再读同名环境变量；空串算没给：
        // - FLARE_ACCESS_JSON：整段 access（正式配置，或带 accessPoints 的完整开发配置）；release 构建必须给。
        // - FLARE_DEV_WS_URL / FLARE_DEV_QUIC_URL / FLARE_DEV_CORE_API_URL / FLARE_DEV_MEDIA_URL：只在 debug
        //   构建、没给 FLARE_ACCESS_JSON 时组装开发模式；缺的取模拟器访问宿主机的本地默认值（10.0.2.2）。
        for (name in accessBuildSettings) {
            buildConfigField("String", name, buildConfigString(accessBuildSetting(name)))
        }
        // 可用 `-PaccessToken=...` 预填「接入 token」，免去在设备上手输 —— 256 字符的
        // JWT 用 adb input text 打不进去（实测只落 12~26 个字符就被 IME 丢掉）。
        // 传 token 而不是 tokenSecret：签名密钥不该进客户端产物。
        val defaultAccessToken = (project.findProperty("accessToken") as String?) ?: ""
        // 信任 CA（base64 DER 或 PEM）：连自建 CA 签发证书的服务端时用 `-PtlsCaCert=...`。
        val defaultTlsCaCert = (project.findProperty("tlsCaCert") as String?) ?: ""
        // 首次使用保持账号为空；测试构建仍可显式用 `-PuserId=hugo` 预填。
        val defaultUserId = (project.findProperty("userId") as String?) ?: ""
        buildConfigField("String", "DEFAULT_ACCESS_TOKEN", buildConfigString(defaultAccessToken))
        buildConfigField("String", "DEFAULT_TLS_CA_CERT", buildConfigString(defaultTlsCaCert))
        buildConfigField("String", "DEFAULT_USER_ID", buildConfigString(defaultUserId))
        // 更新渠道：发布清单按它选（`stable`、`beta`、`internal`）。
        buildConfigField("String", "FLARE_UPDATE_CHANNEL", buildConfigString(accessBuildSetting("FLARE_UPDATE_CHANNEL").ifEmpty { "stable" }))
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    buildTypes {
        release {
            // Development endpoints never reach a release build's BuildConfig.
            for (name in accessBuildSettings.filter { it.startsWith("FLARE_DEV_") }) {
                buildConfigField("String", name, "\"\"")
            }
        }
    }

    // How the app reaches a device. The release manifest picks a package by `app.distribution`, which the install source
    // cannot tell for every store, so each flavor states it. Only `direct` may install packages (its manifest declares
    // REQUEST_INSTALL_PACKAGES), and only `play` carries Play code. A store channel is written like `play`, without that
    // module, and is added to `releasePreBuild`.
    flavorDimensions += "distribution"
    productFlavors {
        create("direct") {
            dimension = "distribution"
            isDefault = true
            buildConfigField("String", "FLARE_DISTRIBUTION", "\"direct\"")
        }
        create("play") {
            dimension = "distribution"
            buildConfigField("String", "FLARE_DISTRIBUTION", "\"play\"")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

// A release build connects through its production access configuration only: without FLARE_ACCESS_JSON, or with a
// development one, it stops here instead of shipping development endpoints.
tasks.matching { releasePreBuild.matches(it.name) }.configureEach {
    doFirst {
        val access = accessBuildSetting("FLARE_ACCESS_JSON")
        if (access.isEmpty()) {
            throw GradleException("Release builds need the production access configuration in FLARE_ACCESS_JSON; see README.md")
        }
        if (access.contains("\"development\"") || access.contains("developmentEndpoints")) {
            throw GradleException("FLARE_ACCESS_JSON is a development configuration; a release build needs the production one")
        }
    }
}

dependencies {
    implementation(project(":flare-core-android-sdk"))
    implementation(project(":flare-core-android-update-ui"))
    "playImplementation"(project(":flare-core-android-update-play"))
    implementation("com.flare.im:im-ui-compose:2.0.0-rc.1")

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation(kotlin("test"))
    testImplementation("junit:junit:4.13.2")
    // android.jar's org.json is a stub (every call throws "not mocked"); AppAccess parses FLARE_ACCESS_JSON with it.
    testImplementation("org.json:json:20240303")

    // 真机/模拟器用例：经真实核心（本地库，不连网）验证保存到下载位置、缓存统计。
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
