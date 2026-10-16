package com.tito.titodex.launcher

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private val worker = Executors.newSingleThreadExecutor()
    private var imageResult: MethodChannel.Result? = null
    private var lastAxisTime = 0L

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.tito.titodex.launcher/device")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "readSettings" -> result.success(getPreferences(0).getString("settings", null))
                "writeSettings" -> {
                    val json = call.argument<String>("json") ?: "{}"
                    worker.execute {
                        val ok = getPreferences(0).edit().putString("settings", json).commit()
                        if (ok) {
                            val kept = runCatching { org.json.JSONObject(json).optString("photo") }.getOrDefault("")
                            filesDir.listFiles()?.filter { it.name.startsWith("wallpaper-") && it.extension == "jpg" && it.absolutePath != kept }?.forEach { it.delete() }
                        }
                        runOnUiThread { if (ok) result.success(null) else result.error("storage", "设置未能保存", null) }
                    }
                }
                "apps" -> worker.execute {
                    try { val apps = loadApps(); runOnUiThread { result.success(apps) } }
                    catch (_: Exception) { runOnUiThread { result.error("apps", "无法读取应用列表", null) } }
                }
                "status" -> result.success(status())
                "launch" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val activity = call.argument<String>("activity")
                    val intent = if (activity.isNullOrBlank()) packageManager.getLaunchIntentForPackage(pkg)
                    else Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setComponent(ComponentName(pkg, activity))
                    result.success(open(intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)))
                }
                "appInfo" -> result.success(open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${call.argument<String>("package")}"))))
                "systemSettings" -> result.success(open(Intent(Settings.ACTION_SETTINGS)))
                "wifiSettings" -> result.success(open(Intent(Settings.ACTION_WIFI_SETTINGS)))
                "homeSettings" -> result.success(open(Intent(Settings.ACTION_HOME_SETTINGS)))
                "requestHome" -> {
                    val manager = if (Build.VERSION.SDK_INT >= 29) getSystemService(RoleManager::class.java) else null
                    if (manager != null && manager.isRoleAvailable(RoleManager.ROLE_HOME) && !manager.isRoleHeld(RoleManager.ROLE_HOME)) {
                        try {
                            startActivityForResult(manager.createRequestRoleIntent(RoleManager.ROLE_HOME), 605)
                            result.success(true)
                        } catch (_: Exception) { result.success(open(Intent(Settings.ACTION_HOME_SETTINGS))) }
                    } else result.success(open(Intent(Settings.ACTION_HOME_SETTINGS)))
                }
                "pickWallpaper" -> {
                    if (imageResult != null) result.error("busy", "图片选择器已打开", null)
                    else {
                        imageResult = result
                        try { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/*"), 604) }
                        catch (_: Exception) { imageResult = null; result.error("picker", "设备没有可用的图片选择器", null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun loadApps(): List<Map<String, Any>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val resolved = packageManager.queryIntentActivities(intent, 0)
        return resolved.filter { it.activityInfo.packageName != packageName }
            .distinctBy { "${it.activityInfo.packageName}/${it.activityInfo.name}" }
            .map { info ->
                val icon = try {
                    val drawable = info.loadIcon(packageManager)
                    val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
                    drawable.setBounds(0, 0, 96, 96); drawable.draw(Canvas(bitmap))
                    val bytes = ByteArrayOutputStream(); bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes); bitmap.recycle()
                    bytes.toByteArray()
                } catch (_: Exception) { byteArrayOf() }
                mapOf("package" to info.activityInfo.packageName, "activity" to info.activityInfo.name,
                    "label" to info.loadLabel(packageManager).toString(), "icon" to icon)
            }.sortedBy { (it["label"] as String).lowercase() }
    }

    private fun status(): Map<String, Any> {
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val network = getSystemService(ConnectivityManager::class.java)
        val caps = network.getNetworkCapabilities(network.activeNetwork)
        val home = packageManager.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
        return mapOf("battery" to (if (level < 0 || scale <= 0) -1 else level * 100 / scale),
            "charging" to ((battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0),
            "online" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true),
            "wifi" to (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true),
            "defaultHome" to (home?.activityInfo?.packageName == packageName))
    }

    private fun open(intent: Intent?): Boolean = try {
        if (intent == null) false else { startActivity(intent); true }
    } catch (_: Exception) { false }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (::channel.isInitialized && intent.hasCategory(Intent.CATEGORY_HOME)) channel.invokeMethod("home", null)
    }

    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 604) return
        val result = imageResult ?: return
        imageResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        worker.execute {
            try {
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, options) }
                require(options.outWidth > 0 && options.outHeight > 0)
                var sample = 1
                while (maxOf(options.outWidth, options.outHeight) / sample > 1600) sample *= 2
                val decoded = contentResolver.openInputStream(uri).use {
                    BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
                } ?: error("image")
                // Respect phone-camera orientation before storing a bounded private copy.
                val orientation = runCatching {
                    contentResolver.openInputStream(uri).use { stream ->
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
                val file = File(filesDir, "wallpaper-${System.currentTimeMillis()}.jpg")
                file.outputStream().use { check(upright.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
                if (upright !== decoded) upright.recycle()
                decoded.recycle()
                runOnUiThread { result.success(file.absolutePath) }
            } catch (_: Exception) { runOnUiThread { result.error("image", "图片无法读取，请选择其他图片", null) } }
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        window.decorView.post {
            fun focusFlutter(view: android.view.View): Boolean {
                if (view is io.flutter.embedding.android.FlutterView) {
                    if (Build.VERSION.SDK_INT >= 26) view.defaultFocusHighlightEnabled = false
                    view.requestFocus()
                    return true
                }
                if (view is android.view.ViewGroup) {
                    for (i in 0 until view.childCount) if (focusFlutter(view.getChildAt(i))) return true
                }
                return false
            }
            focusFlutter(window.decorView)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Flutter already maps gameButtonA to ActivateIntent. Preserve that event.
        if (event.keyCode == KeyEvent.KEYCODE_BUTTON_B) {
            if (event.action == KeyEvent.ACTION_UP) {
                @Suppress("DEPRECATION")
                onBackPressed()
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.isFromSource(android.view.InputDevice.SOURCE_JOYSTICK) && event.action == MotionEvent.ACTION_MOVE) {
            val x = event.getAxisValue(MotionEvent.AXIS_HAT_X).takeIf { kotlin.math.abs(it) > 0.5f } ?: event.getAxisValue(MotionEvent.AXIS_X)
            val y = event.getAxisValue(MotionEvent.AXIS_HAT_Y).takeIf { kotlin.math.abs(it) > 0.5f } ?: event.getAxisValue(MotionEvent.AXIS_Y)
            val key = when { x > 0.6 -> KeyEvent.KEYCODE_DPAD_RIGHT; x < -0.6 -> KeyEvent.KEYCODE_DPAD_LEFT; y > 0.6 -> KeyEvent.KEYCODE_DPAD_DOWN; y < -0.6 -> KeyEvent.KEYCODE_DPAD_UP; else -> 0 }
            if (key != 0 && event.eventTime - lastAxisTime > 180) {
                lastAxisTime = event.eventTime
                dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, key)); dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, key))
            }
            return true
        }
        return super.onGenericMotionEvent(event)
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
}
