pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "flare-core-android-demo"
include(":app", ":flare-core-android-sdk", ":flare-core-android-lifecycle")
val sdk = file(".flare/sources/flare-core-sdk/packages/flare-core-android-sdk")
check(sdk.isDirectory) { "Run python3 scripts/bootstrap.py before opening this project." }
project(":flare-core-android-sdk").projectDir = sdk
project(":flare-core-android-lifecycle").projectDir = sdk.resolve("platform-lifecycle")
includeBuild(".flare/sources/flare-im-design/packages/android-im-ui") {
    dependencySubstitution { substitute(module("com.flare.im:im-ui-compose")).using(project(":")) }
}
