plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

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

        // 默认服务地址：可在构建时用 `-PwsUrl=...` 覆盖（见 Makefile 的 WS= 变量），
        // 免改代码切换联调后端。运行时仍可在登录页「服务器地址」输入框临时改。
        fun buildConfigString(value: String): String =
            "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

        val defaultWsUrl = (project.findProperty("wsUrl") as String?) ?: "ws://10.0.2.2:60051/ws"
        // 网关 HTTP 基址：SDK 向 {httpUrl}/api/v1/auth/tokens 签发接入 token 并自动刷新。
        // 客户端不再持有签名密钥。可用 `-PhttpUrl=...` 覆盖。
        val defaultHttpUrl = (project.findProperty("httpUrl") as String?) ?: "http://10.0.2.2:50050"
        // 可用 `-PaccessToken=...` 预填「接入 token」，免去在设备上手输 —— 256 字符的
        // JWT 用 adb input text 打不进去（实测只落 12~26 个字符就被 IME 丢掉）。
        // 传 token 而不是 tokenSecret：签名密钥不该进客户端产物。
        val defaultAccessToken = (project.findProperty("accessToken") as String?) ?: ""
        // QUIC 地址与信任 CA（base64 DER 或 PEM）：连自建 CA 签发证书的服务端时用 `-PquicUrl=... -PtlsCaCert=...`。
        val defaultQuicUrl = (project.findProperty("quicUrl") as String?) ?: "quic://10.0.2.2:60052"
        val defaultTlsCaCert = (project.findProperty("tlsCaCert") as String?) ?: ""
        // 预选传输模式（WebSocket / Quic / Race），联调自动化用：`-PtransportMode=Quic`
        val defaultTransportMode = (project.findProperty("transportMode") as String?) ?: "WebSocket"
        // 预填用户 ID（模拟器自动化用，adb 往 Compose 输入框打字不可靠）：`-PuserId=hugo`
        val defaultUserId = (project.findProperty("userId") as String?) ?: "android-demo"
        buildConfigField("String", "DEFAULT_WS_URL", buildConfigString(defaultWsUrl))
        buildConfigField("String", "DEFAULT_HTTP_URL", buildConfigString(defaultHttpUrl))
        buildConfigField("String", "DEFAULT_ACCESS_TOKEN", buildConfigString(defaultAccessToken))
        buildConfigField("String", "DEFAULT_QUIC_URL", buildConfigString(defaultQuicUrl))
        buildConfigField("String", "DEFAULT_TLS_CA_CERT", buildConfigString(defaultTlsCaCert))
        buildConfigField("String", "DEFAULT_TRANSPORT_MODE", buildConfigString(defaultTransportMode))
        buildConfigField("String", "DEFAULT_USER_ID", buildConfigString(defaultUserId))
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
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

dependencies {
    implementation(project(":flare-core-android-sdk"))
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

    // 真机/模拟器用例：经真实核心（本地库，不连网）验证保存到下载位置、缓存统计。
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
