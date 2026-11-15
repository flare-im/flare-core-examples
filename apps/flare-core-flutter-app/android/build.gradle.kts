allprojects {
    repositories {
        google()
        mavenCentral()
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
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
