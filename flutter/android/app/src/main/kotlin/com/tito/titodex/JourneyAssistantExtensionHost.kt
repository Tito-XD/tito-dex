package com.tito.titodex

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.security.MessageDigest

class JourneyAssistantExtensionHost(private val activity: Activity) {
    private val packageManager = activity.packageManager
    private var channel: MethodChannel? = null

    fun configure(flutterEngine: FlutterEngine) {
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "inspect" -> result.success(
                        inspect(
                            call.argument<String>("packageId"),
                            call.argument<String>("providerAuthority"),
                            call.argument<String>("readPermission"),
                        ),
                    )
                    "install" -> {
                        try {
                            result.success(
                                install(
                                    call.argument<String>("apkPath"),
                                    call.argument<String>("packageId"),
                                    call.argument<String>("providerAuthority"),
                                    call.argument<String>("readPermission"),
                                ),
                            )
                        } catch (error: ExtensionHostException) {
                            result.error(error.code, error.message, null)
                        } catch (_: Exception) {
                            result.error("install_failed", "Unable to start APK install", null)
                        }
                    }
                    "readTextFile" -> result.success(
                        readTextFile(call.argument<String>("path")),
                    )
                    "uninstall" -> {
                        uninstall(call.argument<String>("packageId"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun handleIntent(intent: Intent?): Boolean {
        if (intent?.action != INSTALL_STATUS_ACTION) return false
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirmation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT) as? Intent
            }
            confirmation?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (confirmation != null) activity.startActivity(confirmation)
            return true
        }
        channel?.invokeMethod(
            "statusChanged",
            mapOf(
                "status" to status,
                "message" to intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE),
            ),
        )
        return true
    }

    private fun inspect(
        expectedPackageId: String?,
        expectedAuthority: String?,
        expectedPermission: String?,
    ): Map<String, Any?> {
        requireContract(expectedPackageId, expectedAuthority, expectedPermission)
        val packageInfo = installedPackageInfo(expectedPackageId!!) ?: return mapOf(
            "installed" to false,
        )
        if (!sameSigner(packageInfo, hostPackageInfo())) return mapOf("installed" to false)
        val provider = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveContentProvider(
                expectedAuthority!!,
                PackageManager.ComponentInfoFlags.of(
                    PackageManager.MATCH_DISABLED_COMPONENTS.toLong(),
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveContentProvider(
                expectedAuthority!!,
                PackageManager.MATCH_DISABLED_COMPONENTS,
            )
        }
        if (provider?.packageName != expectedPackageId ||
            provider.readPermission != expectedPermission
        ) {
            return mapOf("installed" to false)
        }
        val packManifest = readPackManifest(expectedAuthority)
            ?: return mapOf("installed" to false)
        return mapOf(
            "installed" to true,
            "versionName" to packageInfo.versionName,
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            },
            "contentVersion" to packManifest.contentVersion,
            "capabilities" to packManifest.capabilities,
        )
    }

    private fun readPackManifest(authority: String): PackManifest? {
        return try {
            val rawJson = activity.contentResolver.openInputStream(
                Uri.parse("content://$authority/manifest"),
            )?.use { input ->
                readBounded(input, MAX_MANIFEST_BYTES)?.toString(Charsets.UTF_8)
            } ?: return null
            val json = JSONObject(rawJson)
            val minHostVersion = json.optString("minHostVersion")
            if (json.optInt("protocolVersion") != 1 ||
                json.optString("extensionId") != EXTENSION_ID ||
                json.optString("packageId") != EXTENSION_PACKAGE_ID ||
                json.optInt("contentVersion") <= 0 ||
                json.optJSONArray("files") == null ||
                json.optJSONArray("games") == null ||
                json.optJSONArray("locales") == null ||
                !hostVersionAtLeast(minHostVersion)
            ) return null
            val files = json.getJSONArray("files")
            val verifiedFiles = mutableMapOf<String, PackFile>()
            for (index in 0 until files.length()) {
                val file = files.optJSONObject(index) ?: return null
                val path = file.optString("path")
                val digest = file.optString("sha256")
                val sizeBytes = file.optLong("sizeBytes")
                if (path.isBlank() || path.startsWith('/') || path.contains("..") ||
                    sizeBytes <= 0L || sizeBytes > MAX_PACK_FILE_BYTES ||
                    !digest.matches(Regex("^[a-fA-F0-9]{64}$")) ||
                    file.optString("contentType") != "application/json" ||
                    verifiedFiles.containsKey(path)
                ) return null
                verifiedFiles[path] = PackFile(sizeBytes, digest.lowercase())
            }
            if (!verifiedFiles.containsKey("progression_hints.json")) return null
            val capabilitiesJson = json.optJSONArray("capabilities") ?: return null
            val capabilities = buildList {
                for (index in 0 until capabilitiesJson.length()) {
                    capabilitiesJson.optString(index)
                        .takeIf { it.isNotBlank() }
                        ?.let(::add)
                }
            }
            if (!capabilities.contains("progression_hints")) return null
            val games = json.getJSONArray("games")
            if (games.length() == 0 || (0 until games.length()).any { index ->
                    !games.optString(index).matches(Regex("^[a-z0-9_-]+$"))
                }
            ) return null
            val locales = json.getJSONArray("locales")
            if (locales.length() == 0 || (0 until locales.length()).none { index ->
                    locales.optString(index) == "zh-Hans"
                }
            ) return null
            PackManifest(json.getInt("contentVersion"), capabilities, verifiedFiles)
        } catch (_: Exception) {
            null
        }
    }

    private fun hostVersionAtLeast(minimum: String): Boolean {
        if (minimum.isBlank()) return false
        val current = hostPackageInfo().versionName ?: return false
        fun parts(value: String): List<Int> = Regex("\\d+")
            .findAll(value.substringBefore('+'))
            .map { it.value.toIntOrNull() ?: 0 }
            .take(3)
            .toList()
        val currentParts = parts(current)
        val minimumParts = parts(minimum)
        if (currentParts.isEmpty() || minimumParts.isEmpty()) return false
        for (index in 0 until maxOf(currentParts.size, minimumParts.size)) {
            val left = currentParts.getOrElse(index) { 0 }
            val right = minimumParts.getOrElse(index) { 0 }
            if (left != right) return left > right
        }
        return true
    }

    private fun readTextFile(path: String?): String? {
        val safePath = path?.takeIf {
            it.isNotBlank() && !it.startsWith('/') && !it.contains("..")
        } ?: return null
        val info = inspect(
            EXTENSION_PACKAGE_ID,
            EXTENSION_PROVIDER_AUTHORITY,
            EXTENSION_READ_PERMISSION,
        )
        if (info["installed"] != true) return null
        val packFile = readPackManifest(EXTENSION_PROVIDER_AUTHORITY)
            ?.files
            ?.get(safePath)
            ?: return null
        return try {
            val bytes = activity.contentResolver.openInputStream(
                Uri.parse("content://$EXTENSION_PROVIDER_AUTHORITY/files/$safePath"),
            )?.use { input -> readBounded(input, packFile.sizeBytes) } ?: return null
            if (bytes.size.toLong() != packFile.sizeBytes ||
                sha256Hex(bytes) != packFile.sha256
            ) return null
            bytes.toString(Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    private fun readBounded(input: InputStream, maximumBytes: Long): ByteArray? {
        if (maximumBytes < 0L || maximumBytes > Int.MAX_VALUE.toLong()) return null
        val output = ByteArrayOutputStream(minOf(maximumBytes.toInt(), 16 * 1024))
        val buffer = ByteArray(8 * 1024)
        var total = 0L
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            if (total > maximumBytes) return null
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { byte -> "%02x".format(byte) }

    private fun install(
        apkPath: String?,
        expectedPackageId: String?,
        expectedAuthority: String?,
        expectedPermission: String?,
    ): String {
        requireContract(expectedPackageId, expectedAuthority, expectedPermission)
        val apk = apkPath?.let(::File)
            ?: throw ExtensionHostException("apk_missing", "APK path is missing")
        val cacheRoot = activity.cacheDir.canonicalFile
        val canonicalApk = apk.canonicalFile
        if (!canonicalApk.isFile || !canonicalApk.path.startsWith("${cacheRoot.path}/")) {
            throw ExtensionHostException("apk_path_rejected", "APK is outside app cache")
        }
        val archiveInfo = archivePackageInfo(canonicalApk)
            ?: throw ExtensionHostException("apk_invalid", "APK manifest cannot be read")
        if (archiveInfo.packageName != expectedPackageId) {
            throw ExtensionHostException("apk_package_mismatch", "Unexpected APK package")
        }
        if (!sameSigner(archiveInfo, hostPackageInfo())) {
            throw ExtensionHostException("apk_signature_mismatch", "APK signer is not TitoDex")
        }
        val provider = archiveInfo.providers?.firstOrNull {
            it.authority?.split(';')?.contains(expectedAuthority) == true
        }
        if (provider == null || provider.readPermission != expectedPermission) {
            throw ExtensionHostException(
                "apk_provider_mismatch",
                "APK does not expose the expected protected provider",
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            activity.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}"),
                ),
            )
            return "permission_required"
        }

        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(expectedPackageId)
            setSize(canonicalApk.length())
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            canonicalApk.inputStream().use { input ->
                session.openWrite("base.apk", 0, canonicalApk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val statusIntent = Intent(activity, MainActivity::class.java).apply {
                action = INSTALL_STATUS_ACTION
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val sender = PendingIntent.getActivity(
                activity,
                INSTALL_REQUEST_CODE,
                statusIntent,
                flags,
            ).intentSender
            session.commit(sender)
        }
        return "started"
    }

    private fun uninstall(expectedPackageId: String?) {
        if (expectedPackageId != EXTENSION_PACKAGE_ID) return
        activity.startActivity(
            Intent(Intent.ACTION_DELETE, Uri.parse("package:$expectedPackageId")),
        )
    }

    private fun requireContract(
        packageId: String?,
        authority: String?,
        permission: String?,
    ) {
        if (packageId != EXTENSION_PACKAGE_ID ||
            authority != EXTENSION_PROVIDER_AUTHORITY ||
            permission != EXTENSION_READ_PERMISSION
        ) {
            throw ExtensionHostException("contract_mismatch", "Unexpected extension contract")
        }
    }

    private fun installedPackageInfo(packageId: String): PackageInfo? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageId, packageInfoFlags())
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageId, packageInfoFlagsLegacy())
        }
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    private fun hostPackageInfo(): PackageInfo = if (
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    ) {
        packageManager.getPackageInfo(activity.packageName, packageInfoFlags())
    } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(activity.packageName, packageInfoFlagsLegacy())
    }

    private fun archivePackageInfo(apk: File): PackageInfo? = if (
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    ) {
        packageManager.getPackageArchiveInfo(apk.path, packageInfoFlags())
    } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageArchiveInfo(apk.path, packageInfoFlagsLegacy())
    }

    private fun packageInfoFlags(): PackageManager.PackageInfoFlags =
        PackageManager.PackageInfoFlags.of(
            (PackageManager.GET_PROVIDERS or PackageManager.GET_SIGNING_CERTIFICATES).toLong(),
        )

    @Suppress("DEPRECATION")
    private fun packageInfoFlagsLegacy(): Int =
        PackageManager.GET_PROVIDERS or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

    private fun sameSigner(left: PackageInfo, right: PackageInfo): Boolean {
        val leftSigners = signerDigests(left)
        val rightSigners = signerDigests(right)
        return leftSigners.isNotEmpty() && leftSigners == rightSigners
    }

    private fun signerDigests(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo ?: return emptySet()
            signingInfo.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures ?: return emptySet()
        }
        return signatures.map { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte) }
        }.toSet()
    }

    private class ExtensionHostException(val code: String, message: String) :
        Exception(message)

    private data class PackManifest(
        val contentVersion: Int,
        val capabilities: List<String>,
        val files: Map<String, PackFile>,
    )

    private data class PackFile(
        val sizeBytes: Long,
        val sha256: String,
    )

    private companion object {
        const val CHANNEL_NAME = "com.tito.titodex/journey_assistant_extension"
        const val EXTENSION_PACKAGE_ID =
            "com.tito.titodex.extension.journeyassistant"
        const val EXTENSION_ID = "journey_assistant"
        const val EXTENSION_PROVIDER_AUTHORITY =
            "com.tito.titodex.extension.journeyassistant.provider"
        const val EXTENSION_READ_PERMISSION =
            "com.tito.titodex.permission.READ_EXTENSION_PACK"
        const val INSTALL_STATUS_ACTION =
            "com.tito.titodex.JOURNEY_ASSISTANT_INSTALL_STATUS"
        const val INSTALL_REQUEST_CODE = 47023
        const val MAX_MANIFEST_BYTES = 256L * 1024L
        const val MAX_PACK_FILE_BYTES = 8L * 1024L * 1024L
    }
}
