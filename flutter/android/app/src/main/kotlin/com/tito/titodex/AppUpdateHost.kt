package com.tito.titodex

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Installs only newer host APKs with the current signing certificate. */
class AppUpdateHost(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()

    fun configure(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.tito.titodex/app_update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installed" -> {
                        val info = hostInfo()
                        result.success(mapOf(
                            "version" to info.versionName,
                            "buildNumber" to versionCode(info),
                            "packageName" to info.packageName,
                            "arm64" to Build.SUPPORTED_ABIS.contains("arm64-v8a"),
                        ))
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        val expectedHash = call.argument<String>("sha256")
                        val expectedVersion = call.argument<String>("version")
                        // A 95 MB APK hash/manifest parse must not block Flutter's UI.
                        executor.execute {
                            try {
                                val file = validate(path, expectedHash, expectedVersion)
                                activity.runOnUiThread {
                                    try {
                                        result.success(openInstaller(file))
                                    } catch (_: Exception) {
                                        result.error("installer_unavailable", "Cannot open the system installer", null)
                                    }
                                }
                            } catch (_: Exception) {
                                activity.runOnUiThread {
                                    result.error("apk_rejected", "APK identity, version or signature verification failed", null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun validate(path: String?, expectedHash: String?, expectedVersion: String?): File {
        require(activity.packageName == "com.tito.titodex")
        require(Build.SUPPORTED_ABIS.contains("arm64-v8a"))
        require(expectedHash != null && Regex("[a-f0-9]{64}").matches(expectedHash))
        require(expectedVersion != null && Regex("[0-9]+\\.[0-9]+\\.[0-9]+(-offline)?").matches(expectedVersion))
        val file = File(requireNotNull(path)).canonicalFile
        val expected = File(activity.cacheDir, "app_updates/update.apk").canonicalFile
        require(file == expected && file.isFile && file.length() in 15_000_000L..150_000_000L)
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count == -1) break
                digest.update(buffer, 0, count)
            }
        }
        require(digest.digest().joinToString("") { "%02x".format(it) } == expectedHash)
        val host = hostInfo()
        @Suppress("DEPRECATION")
        val apk = activity.packageManager.getPackageArchiveInfo(file.path, signatureFlags())
            ?: error("APK manifest missing")
        require(apk.packageName == host.packageName)
        require(apk.versionName == expectedVersion)
        require(expectedVersion.endsWith("-offline") == (host.versionName?.contains("-offline") == true))
        require(versionCode(apk) > versionCode(host))
        val signers = signerBytes(host)
        require(signers.isNotEmpty() && signerBytes(apk) == signers)
        return file
    }

    private fun openInstaller(file: File): String {
        check(!activity.isFinishing && !activity.isDestroyed)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}")))
            return "permission_required"
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.app_updates", file)
        activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
        return "started"
    }

    @Suppress("DEPRECATION")
    private fun hostInfo(): PackageInfo =
        activity.packageManager.getPackageInfo(activity.packageName, signatureFlags())

    @Suppress("DEPRECATION")
    private fun signatureFlags(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        info.longVersionCode else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signerBytes(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            info.signingInfo?.apkContentsSigners else info.signatures
        return signatures?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }?.toSet() ?: emptySet()
    }

    fun close() { executor.shutdown() }
}
