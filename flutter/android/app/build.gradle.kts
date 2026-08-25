import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tito.titodex"
    // Match working RG builds (0.2.11 / local 0.2.23): compile/target SDK 36.
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Preview/side-by-side installs: override the package, launcher label
        // and version suffix from the build environment without forking the
        // repo (e.g. TITODEX_APPLICATION_ID=com.tito.titodex.preview).
        applicationId = System.getenv("TITODEX_APPLICATION_ID") ?: "com.tito.titodex"
        // minSdk 24 keeps native .so Stored (uncompressed) — required for RG sideload.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName + (System.getenv("TITODEX_VERSION_NAME_SUFFIX") ?: "")
        manifestPlaceholders["appLabel"] = System.getenv("TITODEX_APP_LABEL") ?: "TitoDex"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // The Flat UI experiment must coexist with the signed TitoDex
            // release on one device. Namespace stays unchanged so native
            // activity/service classes and MethodChannels need no fork.
            applicationIdSuffix = ".flatui"
            versionNameSuffix = "-flat-ui-debug"
        }
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            ndk {
                // Shipping RG APKs stay arm64-only; debug keeps emulator ABIs
                // so Android integration tests can run on x86_64 CI hosts.
                abiFilters += listOf("arm64-v8a")
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}
