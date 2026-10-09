plugins {
    id("com.android.application")

    // Flutter Gradle plugin must be applied after
    // the Android application plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.clinexa"

    compileSdk = maxOf(
        35,
        flutter.compileSdkVersion
    )

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        // Keep Java and Kotlin on the same JVM target.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.clinexa"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Development configuration.
            // Replace with a real release signing configuration
            // before publishing the application.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}