plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.tito.titodex.launcher"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.tito.titodex.launcher"
        minSdk = 24
        targetSdk = 36
        versionCode = 6
        versionName = "0.3.1-motion.1"
        ndk { abiFilters += "arm64-v8a" }
    }
    buildTypes {
        release {
            // Development-signed pre-release; preserves upgrades from existing device previews.
            // Production distribution needs a dedicated release signer.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { compose = true; buildConfig = true }
    testOptions { unitTests.isIncludeAndroidResources = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    val bom = platform("androidx.compose:compose-bom:2025.09.01")
    implementation(bom)
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    testImplementation(bom)
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("org.robolectric:robolectric:4.16.1")
    testImplementation("androidx.compose.ui:ui-test-junit4")
    testImplementation("androidx.test:core:1.7.0")
}

// Keep desktop validation bounded on 16 GB development machines.
tasks.withType<Test>().configureEach {
    maxHeapSize = "1g"
    maxParallelForks = 1
}
