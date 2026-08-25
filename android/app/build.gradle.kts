import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// gitignored and never committed. CI only builds --debug, so a missing file
// must not break the build there; see the release buildType below for the
// guard that stops a release build from silently falling back to debug keys.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// android/local.properties. Gradle does not expose this file as project
// properties on its own - settings.gradle.kts only reads flutter.sdk out of
// it - so findProperty() never sees anything written here. docs/HUMAN_TASKS.md
// tells operators to put MAPS_API_KEY in local.properties, and without this
// block that key was silently dropped and the map kept reporting InvalidKey.
// The alternative sources findProperty() does read (gradle.properties) is
// tracked by git, so a secret must not go there.
val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    namespace = "jp.trustcar.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "jp.trustcar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps API key (Issue #43). Supplied via a Gradle property
        // (-PMAPS_API_KEY=...), android/local.properties, or the MAPS_API_KEY /
        // GOOGLE_MAPS_API_KEY env vars. Defaults to empty so builds succeed
        // without a key; the in-app map is gated on MapsConfig.isConfigured
        // and falls back to the distance list.
        manifestPlaceholders["MAPS_API_KEY"] =
            (project.findProperty("MAPS_API_KEY") as String?)
                ?: localProperties.getProperty("MAPS_API_KEY")
                ?: System.getenv("MAPS_API_KEY")
                ?: System.getenv("GOOGLE_MAPS_API_KEY")
                ?: ""
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Fail loudly rather than hand back a debug-signed artifact that
            // looks like a release. Play rejects debug keys, but only after
            // upload - and a debug-signed AAB is indistinguishable from a real
            // one until then. Debug builds are unaffected: this only trips when
            // a release task was actually requested.
            val wantsRelease = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true)
            }
            if (!hasReleaseKeystore && wantsRelease) {
                throw GradleException(
                    "android/key.properties not found. A release build needs " +
                        "storeFile / storePassword / keyAlias / keyPassword. " +
                        "See docs/MAINTENANCE_RUNBOOK.md."
                )
            }
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug"
            )
            // R8 は使っていないクラスを消す。ML Kit の日本語認識は
            // proguard-rules.pro で残す指定をしないと、release / profile で
            // 実行時に落ちる（車検証OCRが動かない）。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ML Kit Japanese text recognition model for 車検証 / invoice OCR.
    // google_mlkit_text_recognition only bundles the Latin model; non-Latin
    // scripts must be added explicitly (see the plugin README). Without this,
    // TextRecognitionScript.japanese fails at runtime and R8 cannot resolve
    // the Japanese recognizer classes in release builds.
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
}
