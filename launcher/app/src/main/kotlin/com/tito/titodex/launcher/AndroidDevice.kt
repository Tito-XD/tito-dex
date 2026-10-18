package com.tito.titodex.launcher

import android.app.Activity
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.icu.text.AlphabeticIndex
import android.icu.text.Collator
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings as SystemSettings
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

const val REQUEST_PHOTO = 604
const val REQUEST_HOME = 605

class AndroidDevice(private val activity: Activity, private val onAppsChanged: () -> Unit) : Device {
    /** 0.2 stored settings through Activity.getPreferences, which names the file after the activity class. */
    private val prefs = activity.getSharedPreferences("MainActivity", Context.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()
    private val icons = ConcurrentHashMap<String, ImageBitmap>()
    private var photoResult: ((Result<String?>) -> Unit)? = null
    private val iconPx = (52 * activity.resources.displayMetrics.density).toInt().coerceAtLeast(48)

    override val widgets = WidgetHostBridge(activity)

    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) = onAppsChanged()
    }

    init {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED); addAction(Intent.ACTION_PACKAGE_REMOVED); addAction(Intent.ACTION_PACKAGE_CHANGED)
            addDataScheme("package")
        }
        activity.registerReceiver(packageReceiver, filter)
    }

    fun dispose() {
        runCatching { activity.unregisterReceiver(packageReceiver) }
        worker.shutdown()
    }

    override fun loadSettings(): String? {
        val raw = prefs.getString("settings", null)
        val kept = runCatching { org.json.JSONObject(raw ?: "{}").optString("photo") }.getOrDefault("")
        // Only at startup: undo snapshots in memory may still point at the previous photo during a session.
        activity.filesDir.listFiles()?.filter { it.name.startsWith("wallpaper-") && it.extension == "jpg" && it.absolutePath != kept }?.forEach { it.delete() }
        return raw
    }

    override fun saveSettings(json: String) {
        check(prefs.edit().putString("settings", json).commit()) { "设置未能保存" }
    }

    override fun loadApps(): List<AppEntry> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val resolved = pm.queryIntentActivities(intent, 0)
            .filter { it.activityInfo.packageName != activity.packageName }
            .distinctBy { "${it.activityInfo.packageName}/${it.activityInfo.name}" }
        val index = AlphabeticIndex<String>(Locale.SIMPLIFIED_CHINESE).addLabels(Locale.ENGLISH).buildImmutableIndex()
        val collator = Collator.getInstance(Locale.SIMPLIFIED_CHINESE)
        val entries = resolved.map { info ->
            val label = info.loadLabel(pm).toString().trim().ifEmpty { info.activityInfo.packageName }
            val bucket = index.getBucketIndex(label)
            val name = index.getBucket(bucket).label
            val group = if (name.length == 1 && name[0] in 'A'..'Z') name else "#"
            val entry = AppEntry(info.activityInfo.packageName, info.activityInfo.name, label, group)
            if (!icons.containsKey(entry.id)) runCatching {
                val d = info.loadIcon(pm)
                val bmp = Bitmap.createBitmap(iconPx, iconPx, Bitmap.Config.ARGB_8888)
                d.setBounds(0, 0, iconPx, iconPx); d.draw(Canvas(bmp))
                icons[entry.id] = bmp.asImageBitmap()
            }
            entry
        }
        return entries.sortedWith(compareBy<AppEntry> { if (it.group == "#") 1 else 0 }.thenBy { it.group }.thenComparator { a, b -> collator.compare(a.label, b.label) })
    }

    override fun icon(app: AppEntry): ImageBitmap? = icons[app.id]

    override fun status(): DeviceStatus {
        val battery = activity.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val network = activity.getSystemService(ConnectivityManager::class.java)
        val caps = network?.getNetworkCapabilities(network.activeNetwork)
        val home = activity.packageManager.resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), android.content.pm.PackageManager.MATCH_DEFAULT_ONLY,
        )
        return DeviceStatus(
            battery = if (level < 0 || scale <= 0) -1 else level * 100 / scale,
            charging = (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0,
            online = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true,
            wifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true,
            defaultHome = home?.activityInfo?.packageName == activity.packageName,
        )
    }

    private fun start(intent: Intent?): Boolean = try {
        if (intent == null) false else { activity.startActivity(intent); true }
    } catch (_: Exception) { false }

    override fun launch(app: AppEntry): Boolean = start(
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setComponent(ComponentName(app.pkg, app.activity))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED),
    )

    override fun launchPackage(pkg: String): Boolean =
        start(activity.packageManager.getLaunchIntentForPackage(pkg)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED))

    override fun appInfo(pkg: String): Boolean = start(Intent(SystemSettings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))

    override fun open(entry: SystemEntry): Boolean = when (entry) {
        SystemEntry.wifi -> start(Intent(SystemSettings.ACTION_WIFI_SETTINGS))
        SystemEntry.settings -> start(Intent(SystemSettings.ACTION_SETTINGS))
        SystemEntry.homeSettings -> start(Intent(SystemSettings.ACTION_HOME_SETTINGS))
        SystemEntry.requestHome -> {
            val manager = if (Build.VERSION.SDK_INT >= 29) activity.getSystemService(RoleManager::class.java) else null
            if (Build.VERSION.SDK_INT >= 29 && manager != null && manager.isRoleAvailable(RoleManager.ROLE_HOME) && !manager.isRoleHeld(RoleManager.ROLE_HOME)) {
                try {
                    @Suppress("DEPRECATION")
                    activity.startActivityForResult(manager.createRequestRoleIntent(RoleManager.ROLE_HOME), REQUEST_HOME)
                    true
                } catch (_: Exception) { start(Intent(SystemSettings.ACTION_HOME_SETTINGS)) }
            } else start(Intent(SystemSettings.ACTION_HOME_SETTINGS))
        }
    }

    override fun pickPhoto(result: (Result<String?>) -> Unit) {
        if (photoResult != null) { result(Result.failure(IllegalStateException("图片选择器已打开"))); return }
        photoResult = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/*"), REQUEST_PHOTO)
        } catch (_: Exception) {
            photoResult = null
            result(Result.failure(IllegalStateException("设备没有可用的图片选择器")))
        }
    }

    fun onPhotoResult(ok: Boolean, uri: Uri?) {
        val result = photoResult ?: return
        photoResult = null
        if (!ok || uri == null) { result(Result.success(null)); return }
        worker.execute {
            val out = runCatching { importPhoto(uri) }.recoverCatching { throw IllegalStateException("图片无法读取，请选择其他图片") }
            activity.runOnUiThread { result(out) }
        }
    }

    private fun importPhoto(uri: Uri): String {
        val resolver = activity.contentResolver
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, options) }
        require(options.outWidth > 0 && options.outHeight > 0)
        var sample = 1
        while (maxOf(options.outWidth, options.outHeight) / sample > 1600) sample *= 2
        val decoded = resolver.openInputStream(uri).use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: error("image")
        val orientation = runCatching {
            resolver.openInputStream(uri).use { stream ->
                if (stream == null) ExifInterface.ORIENTATION_NORMAL
                else ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            }
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix().apply {
            when (orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { setRotate(90f); postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE -> { setRotate(-90f); postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(-90f)
            }
        }
        val upright = if (matrix.isIdentity) decoded else Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        val file = File(activity.filesDir, "wallpaper-${System.currentTimeMillis()}.jpg")
        file.outputStream().use { check(upright.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
        if (upright !== decoded) upright.recycle()
        decoded.recycle()
        return file.absolutePath
    }

    override fun photo(path: String): ImageBitmap? {
        val file = File(path)
        if (!file.isFile || file.parentFile?.absolutePath != activity.filesDir.absolutePath) return null
        return BitmapFactory.decodeFile(path)?.asImageBitmap()
    }
}
