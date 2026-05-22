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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}
// Принудительное обновление compileSdk и targetSdk для всех подключаемых плагинов
gradle.afterProject {
    if (hasProperty("android")) {
        val androidExtension = property("android") as? com.android.build.gradle.BaseExtension
        androidExtension?.apply {
            compileSdkVersion(36)
            defaultConfig {
                targetSdkVersion(36)
            }
        }
    }
}

include(":app")
