package com.tito.titodex

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingSaveDocumentResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var pendingShortcutRoute: String? = null
    private var appShortcutChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShortcutRoute = shortcutRouteFrom(intent)
        appShortcutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_SHORTCUTS_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialRoute" -> {
                        result.success(pendingShortcutRoute)
                        pendingShortcutRoute = null
                    }
                    "updateShortcuts" -> {
                        updateShortcuts(
                            call.argument<List<Map<String, String>>>("shortcuts") ?: emptyList(),
                        )
                        result.success(null)
                    }
                    "getDynamicShortcutIds" -> result.success(dynamicShortcutIds())
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_LAUNCHER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listLaunchableApps" -> result.success(listLaunchableApps())
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    val activityName = call.argument<String>("activityName")
                    result.success(launchApp(packageName, activityName))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAVE_DOCUMENT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickSaveDocument" -> pickSaveDocument(result)
                "readSaveDocument" -> {
                    val uri = call.argument<String>("uri")
                    result.success(uri?.let { readSaveDocument(Uri.parse(it)) })
                }
                "releaseSaveDocument" -> {
                    releaseSaveDocument(call.argument<String>("uri"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEX_DOWNLOAD_NOTIFICATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val progress = call.argument<Int>("progress") ?: 0
                    val title = call.argument<String>("title") ?: "TitoDex"
                    val text = call.argument<String>("text") ?: ""
                    DexDownloadForegroundService.start(
                        applicationContext,
                        progress,
                        title,
                        text,
                    )
                    resolveNotificationPermission(result)
                }
                "update" -> {
                    DexDownloadForegroundService.update(
                        applicationContext,
                        call.argument<Int>("progress") ?: 0,
                        call.argument<String>("text") ?: "",
                    )
                    result.success(null)
                }
                "complete" -> {
                    DexDownloadForegroundService.complete(
                        applicationContext,
                        call.argument<String>("title") ?: "TitoDex",
                        call.argument<String>("text") ?: "",
                    )
                    result.success(null)
                }
                "fail" -> {
                    DexDownloadForegroundService.fail(
                        applicationContext,
                        call.argument<String>("title") ?: "TitoDex",
                        call.argument<String>("text") ?: "",
                    )
                    result.success(null)
                }
                "cancel" -> {
                    DexDownloadForegroundService.cancel(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = shortcutRouteFrom(intent) ?: return
        pendingShortcutRoute = null
        appShortcutChannel?.invokeMethod("shortcutOpened", route)
    }

    private fun shortcutRouteFrom(intent: Intent?): String? {
        if (intent?.action != APP_SHORTCUT_ACTION) {
            return null
        }
        return intent.getStringExtra(APP_SHORTCUT_ROUTE)?.takeIf { it.startsWith("/") }
    }

    private fun updateShortcuts(entries: List<Map<String, String>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) {
            return
        }
        val manager = getSystemService(ShortcutManager::class.java)
        manager.dynamicShortcuts = entries.take(3).mapIndexedNotNull { rank, entry ->
            val id = entry["id"]?.takeIf { it.isNotBlank() } ?: return@mapIndexedNotNull null
            val label = entry["label"]?.takeIf { it.isNotBlank() } ?: return@mapIndexedNotNull null
            val route = entry["route"]?.takeIf { it.startsWith("/") }
                ?: return@mapIndexedNotNull null
            val shortcutIntent = Intent(applicationContext, MainActivity::class.java).apply {
                action = APP_SHORTCUT_ACTION
                putExtra(APP_SHORTCUT_ROUTE, route)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            ShortcutInfo.Builder(this, id)
                .setShortLabel(label)
                .setLongLabel("TitoDex · $label")
                .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                .setRank(rank)
                .setIntent(shortcutIntent)
                .build()
        }
    }

    private fun dynamicShortcutIds(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) {
            return emptyList()
        }
        return getSystemService(ShortcutManager::class.java).dynamicShortcuts.map { it.id }
    }

    @Deprecated("Kept for the Storage Access Framework result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_SAVE_DOCUMENT_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val pendingResult = pendingSaveDocumentResult ?: return
        pendingSaveDocumentResult = null
        if (resultCode != Activity.RESULT_OK) {
            pendingResult.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pendingResult.success(null)
            return
        }

        val takeFlags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (_: SecurityException) {
            // Some providers return a usable URI without a persistable grant.
        }
        pendingResult.success(readSaveDocument(uri))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != POST_NOTIFICATIONS_REQUEST) {
            return
        }
        val result = pendingNotificationPermissionResult ?: return
        pendingNotificationPermissionResult = null
        result.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    private fun resolveNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.success(false)
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            POST_NOTIFICATIONS_REQUEST,
        )
    }

    private fun pickSaveDocument(result: MethodChannel.Result) {
        if (pendingSaveDocumentResult != null) {
            result.error("pick_in_progress", "A save document picker is already open", null)
            return
        }
        pendingSaveDocumentResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, PICK_SAVE_DOCUMENT_REQUEST)
    }

    private fun readSaveDocument(uri: Uri): Map<String, Any>? {
        return try {
            var fileName = uri.lastPathSegment ?: "save.sav"
            var modifiedMs = 0L
            contentResolver.query(
                uri,
                arrayOf(
                    OpenableColumns.DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        fileName = cursor.getString(nameIndex) ?: fileName
                    }
                    val modifiedIndex = cursor.getColumnIndex(
                        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                    )
                    if (modifiedIndex >= 0 && !cursor.isNull(modifiedIndex)) {
                        modifiedMs = cursor.getLong(modifiedIndex)
                    }
                }
            }
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: return null
            mapOf(
                "uri" to uri.toString(),
                "fileName" to fileName,
                "modifiedMs" to modifiedMs,
                "bytes" to bytes,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun releaseSaveDocument(uriString: String?) {
        if (uriString.isNullOrBlank()) {
            return
        }
        try {
            contentResolver.releasePersistableUriPermission(
                Uri.parse(uriString),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: Exception) {
            // The provider may not have granted a persistable permission.
        }
    }

    private fun listLaunchableApps(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }

        return activities
            .asSequence()
            .filter { it.activityInfo.packageName != packageName }
            .map {
                mapOf(
                    "packageName" to it.activityInfo.packageName,
                    "activityName" to it.activityInfo.name,
                    "appName" to it.loadLabel(packageManager).toString(),
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["appName"]?.lowercase() }
            .toList()
    }

    private fun launchApp(packageName: String?, activityName: String?): Boolean {
        if (packageName.isNullOrBlank()) {
            return false
        }

        val intent = if (!activityName.isNullOrBlank()) {
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                component = ComponentName(packageName, activityName)
            }
        } else {
            packageManager.getLaunchIntentForPackage(packageName) ?: return false
        }

        return try {
            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
            )
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val APP_LAUNCHER_CHANNEL = "com.tito.titodex/app_launcher"
        const val SAVE_DOCUMENT_CHANNEL = "com.tito.titodex/save_document"
        const val DEX_DOWNLOAD_NOTIFICATION_CHANNEL =
            "com.tito.titodex/dex_download_notification"
        const val APP_SHORTCUTS_CHANNEL = "com.tito.titodex/app_shortcuts"
        const val APP_SHORTCUT_ACTION = "com.tito.titodex.OPEN_SHORTCUT"
        const val APP_SHORTCUT_ROUTE = "route"
        const val PICK_SAVE_DOCUMENT_REQUEST = 47021
        const val POST_NOTIFICATIONS_REQUEST = 47022
    }
}
