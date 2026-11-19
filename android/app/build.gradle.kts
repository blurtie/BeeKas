import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads android/key.properties (never committed; docs/cloud-checklist.md).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) FileInputStream(keystorePropertiesFile).use { load(it) }
}
val keystoreKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

// A release build without the key fails here instead of falling back to the debug key.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        val missing = keystoreKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Release signing: android/key.properties is missing or lacks " +
                    missing.joinToString() + ". See docs/cloud-checklist.md (Signing APK rilis)."
            )
        }
    }
}

android {
    namespace = "id.beekas.beekas"
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
        applicationId = "id.beekas.beekas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keystoreProperties.getProperty("storeFile")?.let { storeFile = rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
