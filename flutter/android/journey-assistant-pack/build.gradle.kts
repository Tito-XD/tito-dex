import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
}

val packApplicationId = "com.tito.titodex.extension.journeyassistant"
val packAuthority = "$packApplicationId.provider"
val packProtocolVersion = 1
val packMinHostVersion = providers.gradleProperty("journeyPackMinHostVersion")
    .orNull
    ?: "0.8.13"
val packVersionCode = providers.gradleProperty("journeyPackVersionCode")
    .orNull
    ?.toInt()
    ?: 1
val packVersionName = providers.gradleProperty("journeyPackVersionName")
    .orNull
    ?: "1.0.0"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val canonicalHintsFile = rootProject.layout.projectDirectory.file(
    "../../data/journey/progression_hints.json",
)
val generatedPackAssets = layout.buildDirectory.dir("generated/pack-assets")

fun ByteArray.sha256Hex(): String =
    MessageDigest.getInstance("SHA-256")
        .digest(this)
        .joinToString("") { byte -> "%02x".format(byte) }

val prepareJourneyAssistantPackAssets by tasks.registering {
    group = "build"
    description = "Copies canonical journey facts and generates the signed-pack manifest assets."
    inputs.file(canonicalHintsFile)
    inputs.property("protocolVersion", packProtocolVersion)
    inputs.property("minHostVersion", packMinHostVersion)
    outputs.dir(generatedPackAssets)

    doLast {
        val source = canonicalHintsFile.asFile
        require(source.isFile) {
            "Missing canonical journey data: ${source.invariantSeparatorsPath}"
        }

        val sourceBytes = source.readBytes()
        @Suppress("UNCHECKED_CAST")
        val sourceJson = JsonSlurper().parseText(sourceBytes.toString(Charsets.UTF_8))
            as Map<String, Any?>
        val datasetVersion = (sourceJson["datasetVersion"] as? Number)?.toInt()
            ?: error("progression_hints.json is missing integer datasetVersion")
        @Suppress("UNCHECKED_CAST")
        val entries = sourceJson["entries"] as? List<Map<String, Any?>>
            ?: error("progression_hints.json is missing entries")
        val games = entries
            .flatMap { entry ->
                @Suppress("UNCHECKED_CAST")
                (entry["games"] as? List<String>).orEmpty()
            }
            .distinct()
            .sorted()

        val outputDirectory = generatedPackAssets.get().asFile
        outputDirectory.deleteRecursively()
        outputDirectory.mkdirs()

        val payloadName = "progression_hints.json"
        outputDirectory.resolve(payloadName).writeBytes(sourceBytes)

        val manifest = linkedMapOf<String, Any>(
            "protocolVersion" to packProtocolVersion,
            "extensionId" to "journey_assistant",
            "contentVersion" to datasetVersion,
            "minHostVersion" to packMinHostVersion,
            "packageId" to packApplicationId,
            "capabilities" to listOf("progression_hints"),
            "games" to games,
            "locales" to listOf("zh-Hans"),
            "files" to listOf(
                linkedMapOf(
                    "path" to payloadName,
                    "sizeBytes" to sourceBytes.size,
                    "sha256" to sourceBytes.sha256Hex(),
                    "contentType" to "application/json",
                ),
            ),
        )
        outputDirectory.resolve("extension_manifest.json").writeText(
            JsonOutput.prettyPrint(JsonOutput.toJson(manifest)) + "\n",
            Charsets.UTF_8,
        )
    }
}

val verifyJourneyAssistantPackAssets by tasks.registering {
    group = "verification"
    description = "Verifies generated pack files against the canonical source and manifest digest."
    dependsOn(prepareJourneyAssistantPackAssets)
    inputs.file(canonicalHintsFile)
    inputs.dir(generatedPackAssets)

    doLast {
        val outputDirectory = generatedPackAssets.get().asFile
        val generatedPayload = outputDirectory.resolve("progression_hints.json")
        val canonicalBytes = canonicalHintsFile.asFile.readBytes()
        check(generatedPayload.readBytes().contentEquals(canonicalBytes)) {
            "Generated progression_hints.json differs from the canonical data"
        }

        @Suppress("UNCHECKED_CAST")
        val manifest = JsonSlurper().parse(outputDirectory.resolve("extension_manifest.json"))
            as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val files = manifest["files"] as? List<Map<String, Any?>>
            ?: error("Generated manifest has no files list")
        val payloadEntry = files.singleOrNull { it["path"] == "progression_hints.json" }
            ?: error("Generated manifest does not have exactly one progression_hints.json entry")
        check(payloadEntry["sha256"] == canonicalBytes.sha256Hex()) {
            "Generated manifest SHA-256 does not match canonical progression hints"
        }
        check((payloadEntry["sizeBytes"] as? Number)?.toInt() == canonicalBytes.size) {
            "Generated manifest size does not match canonical progression hints"
        }
    }
}

android {
    namespace = "com.tito.titodex.extension.journeyassistant"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = packApplicationId
        minSdk = 24
        targetSdk = 36
        versionCode = packVersionCode
        versionName = packVersionName
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
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
        }
    }

    sourceSets {
        getByName("main").assets.srcDir(generatedPackAssets)
    }

    androidResources {
        noCompress += "json"
    }

    testOptions {
        unitTests.all {
            it.useJUnit()
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

tasks.named("check").configure {
    dependsOn(verifyJourneyAssistantPackAssets)
}

tasks.named("preBuild").configure {
    dependsOn(verifyJourneyAssistantPackAssets)
}

tasks.register("assembleJourneyAssistantPack") {
    group = "build"
    description = "Builds the independently installable Journey Assistant companion APK."
    dependsOn("assembleRelease")
}
