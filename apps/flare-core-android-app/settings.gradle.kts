pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        if (!providers.gradleProperty("FLARE_JPUSH_APP_KEY").orNull.isNullOrBlank()) {
            exclusiveContent {
                forRepository {
                    maven { url = uri("https://maven.jiguang.cn/nexus/content/repositories/releases/") }
                }
                filter { includeGroup("cn.jiguang.sdk") }
            }
        }
        // 个推的制品只在它自己的仓库里；只让 com.getui 下的坐标走这里，别的依赖不去问它。
        exclusiveContent {
            forRepository {
                maven {
                    name = "Getui"
                    url = uri("https://mvn.getui.com/nexus/content/repositories/releases/")
                }
            }
            filter {
                includeGroupByRegex("com\\.getui(\\..+)?")
                // gtsdk pulls com.zxid.sdk:sdk-prod-channel-getui from the same repository.
                includeGroupByRegex("com\\.zxid(\\..+)?")
            }
        }
        mavenLocal()
        // kit 的远端来源（main 分支用）。顺序即优先级：mavenLocal 命中则用本地，
        // 否则回落到这里的发布版——于是单独 clone 本仓也能构建。
        // 详见 flare-im-design/docs/DISTRIBUTION-DESIGN.md。
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/flare-im/flare-im-design")
            credentials {
                username = (providers.gradleProperty("gpr.user")
                    .orElse(providers.environmentVariable("GITHUB_ACTOR"))).orNull ?: ""
                password = (providers.gradleProperty("gpr.token")
                    .orElse(providers.environmentVariable("GITHUB_TOKEN"))).orNull ?: ""
            }
        }
    }
}

rootProject.name = "flare-core-android-app"
include(":app")
include(":flare-core-android-sdk")
include(":flare-core-android-lifecycle")
include(":flare-core-android-update")
include(":flare-core-android-update-play")
include(":flare-core-android-push")
include(":flare-core-android-push-getui")
include(":flare-core-android-keepalive")

project(":flare-core-android-sdk").projectDir = file("../../../flare-core-sdk/packages/flare-core-android-sdk")
// The core package's PlatformLifecycle module (no native library); the core package depends on it.
project(":flare-core-android-lifecycle").projectDir = file("../../../flare-core-sdk/packages/flare-core-android-sdk/platform-lifecycle")
// The update center: the installer and controller, their binding to the kit, and Play In-App Updates for the play flavor.
project(":flare-core-android-update").projectDir = file("../../../flare-commercial-client-runtime/packages/update/flare-core-android-update")
project(":flare-core-android-update-play").projectDir = file("../../../flare-commercial-client-runtime/packages/update/flare-core-android-update/installers/play")
// Platform push (FCM, notifications, taps; the core package depends on it) and its optional Getui channel.
project(":flare-core-android-push").projectDir = file("../../../flare-commercial-client-runtime/packages/push/flare-core-android-push")
project(":flare-core-android-push-getui").projectDir = file("../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/providers/getui")
// Resident connection mode (optional, off by default): offered only in builds without a push provider.
project(":flare-core-android-keepalive").projectDir = file("../../../flare-commercial-client-runtime/packages/keepalive/flare-core-android-keepalive")

// A sibling design checkout is authoritative during workspace development.
val localDesignKit = file("../../../flare-im-design/packages/android-im-ui")
if (localDesignKit.isDirectory && providers.gradleProperty("flare.usePublishedKit").orNull != "true") {
    includeBuild(localDesignKit) {
        dependencySubstitution {
            substitute(module("com.flare.im:im-ui-compose")).using(project(":"))
        }
    }
}

include(":flare-core-android-push-core-bridge")
project(":flare-core-android-push-core-bridge").projectDir = file("../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/core-bridge")

include(":flare-core-android-update-core-bridge")
project(":flare-core-android-update-core-bridge").projectDir = file("../../../flare-commercial-client-runtime/packages/update/flare-core-android-update/core-bridge")

include(":flare-core-android-push-fcm")
project(":flare-core-android-push-fcm").projectDir = file("../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/providers/fcm")

if (!providers.gradleProperty("FLARE_JPUSH_APP_KEY").orNull.isNullOrBlank()) {
    include(":flare-core-android-push-jpush")
    project(":flare-core-android-push-jpush").projectDir =
        file("../../../flare-commercial-client-runtime/packages/push/flare-core-android-push/providers/jpush")
}
