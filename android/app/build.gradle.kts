plugins {
    id("com.android.application")
    id("com.google.gms.google-services") apply false
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Build an isolated test application only when explicitly requested. Normal
// debug and release builds continue to use the existing Google configuration.
val isolatedWorkflowTest = System.getenv("PARTWK_ISOLATED_TEST") == "1"
if (!isolatedWorkflowTest) apply(plugin = "com.google.gms.google-services")

android {
    if (isolatedWorkflowTest) {
        buildFeatures { resValues = true }
    }
    namespace = "com.pkgames.partwk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pkgames.partwk"
        if (isolatedWorkflowTest) {
            applicationId = "com.pkgames.partwk.emutest"
            resValue("string", "google_app_id", "1:1234567890:android:0123456789abcdef")
            // Firebase Installations validates API-key syntax even when all
            // Firebase services are routed to emulators. This is a synthetic,
            // non-production value, not a real Google API key.
            resValue("string", "google_api_key", "AIza00000000000000000000000000000000000")
            resValue("string", "gcm_defaultSenderId", "1234567890")
            resValue("string", "project_id", "demo-partwk-text")
            resValue("string", "google_storage_bucket", "demo-partwk-text.appspot.com")
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
