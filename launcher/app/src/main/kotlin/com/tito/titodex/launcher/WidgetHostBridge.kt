package com.tito.titodex.launcher

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import androidx.compose.ui.graphics.asImageBitmap
import kotlin.math.abs

const val REQUEST_WIDGET_BIND = 701
const val REQUEST_WIDGET_CONFIGURE = 702
private const val HOST_ID = 0x7D30

/** Hands long presses to the launcher while leaving taps and scrolls to the widget itself. */
class LauncherWidgetView(context: Context) : AppWidgetHostView(context) {
    var onLongPress: (() -> Unit)? = null
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private var downX = 0f
    private var downY = 0f
    private var fired = false
    private val trigger = Runnable {
        fired = true
        parent?.requestDisallowInterceptTouchEvent(true)
        onLongPress?.invoke()
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                fired = false; downX = ev.x; downY = ev.y
                postDelayed(trigger, ViewConfiguration.getLongPressTimeout().toLong())
            }
            MotionEvent.ACTION_MOVE -> if (abs(ev.x - downX) > slop || abs(ev.y - downY) > slop) removeCallbacks(trigger)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> removeCallbacks(trigger)
        }
        return fired
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (fired) {
            if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) fired = false
            return true
        }
        return super.onTouchEvent(event)
    }

    override fun cancelLongPress() {
        super.cancelLongPress()
        removeCallbacks(trigger)
    }
}

private class LauncherWidgetHost(context: Context) : AppWidgetHost(context, HOST_ID) {
    override fun onCreateView(context: Context, appWidgetId: Int, appWidget: AppWidgetProviderInfo?): AppWidgetHostView = LauncherWidgetView(context)
}

class WidgetHostBridge(private val activity: Activity) : WidgetBridge {
    private val manager = AppWidgetManager.getInstance(activity)
    private val host = LauncherWidgetHost(activity.applicationContext)
    private val views = HashMap<Int, LauncherWidgetView>()
    private var pending: Pair<Int, (Int?) -> Unit>? = null
    private val density get() = activity.resources.displayMetrics.density

    fun startListening() = runCatching { host.startListening() }
    fun stopListening() = runCatching { host.stopListening() }

    override fun providers(): List<WidgetProvider> {
        val pm = activity.packageManager
        return manager.installedProviders.mapNotNull { info ->
            runCatching {
                val appLabel = runCatching { pm.getApplicationLabel(pm.getApplicationInfo(info.provider.packageName, 0)).toString() }.getOrDefault(info.provider.packageName)
                val icon = runCatching {
                    val d = info.loadIcon(activity, activity.resources.displayMetrics.densityDpi) ?: return@runCatching null
                    val px = (30 * density).toInt()
                    val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
                    d.setBounds(0, 0, px, px); d.draw(Canvas(bmp)); bmp.asImageBitmap()
                }.getOrNull()
                val (w, h) = minDp(info)
                WidgetProvider(info.provider.flattenToString(), info.loadLabel(pm), appLabel, info.provider.packageName, w, h, icon)
            }.getOrNull()
        }.sortedWith(compareBy({ it.appLabel.lowercase() }, { it.label.lowercase() }))
    }

    private fun minDp(info: AppWidgetProviderInfo): Pair<Int, Int> {
        val w = if (info.resizeMode and AppWidgetProviderInfo.RESIZE_HORIZONTAL != 0 && info.minResizeWidth > 0) info.minResizeWidth else info.minWidth
        val h = if (info.resizeMode and AppWidgetProviderInfo.RESIZE_VERTICAL != 0 && info.minResizeHeight > 0) info.minResizeHeight else info.minHeight
        return (w / density).toInt() to (h / density).toInt()
    }

    private fun providerInfo(key: String) = manager.installedProviders.firstOrNull { it.provider.flattenToString() == key }

    override fun add(provider: WidgetProvider, result: (Int?) -> Unit) {
        val info = providerInfo(provider.key) ?: return result(null)
        pending?.let { (id, cb) -> host.deleteAppWidgetId(id); cb(null) }
        val id = host.allocateAppWidgetId()
        pending = id to result
        val bound = runCatching { manager.bindAppWidgetIdIfAllowed(id, info.profile, info.provider, null) }.getOrDefault(false)
        if (bound) { configure(id); return }
        val ask = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, info.provider)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER_PROFILE, info.profile)
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(ask, REQUEST_WIDGET_BIND)
        } catch (_: Exception) { finish(false) }
    }

    private fun configure(id: Int) {
        val info = manager.getAppWidgetInfo(id) ?: return finish(false)
        val optional = Build.VERSION.SDK_INT >= 28 && (info.widgetFeatures and AppWidgetProviderInfo.WIDGET_FEATURE_CONFIGURATION_OPTIONAL) != 0
        if (info.configure == null || optional) return finish(true)
        try { host.startAppWidgetConfigureActivityForResult(activity, id, 0, REQUEST_WIDGET_CONFIGURE, null) }
        catch (_: Exception) { finish(false) }
    }

    private fun finish(ok: Boolean) {
        val (id, cb) = pending ?: return
        pending = null
        if (ok) cb(id) else { host.deleteAppWidgetId(id); cb(null) }
    }

    /** Returns true when the result belonged to the widget flow. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean = when (requestCode) {
        REQUEST_WIDGET_BIND -> { if (resultCode == Activity.RESULT_OK) pending?.first?.let { configure(it) } else finish(false); true }
        REQUEST_WIDGET_CONFIGURE -> { finish(resultCode == Activity.RESULT_OK); true }
        else -> false
    }

    override fun info(id: Int): WidgetInfo? {
        val info = manager.getAppWidgetInfo(id) ?: return null
        val (w, h) = minDp(info)
        return WidgetInfo(info.loadLabel(activity.packageManager), w, h)
    }

    override fun view(id: Int, onLongPress: () -> Unit): View? {
        val v = views[id] ?: run {
            val info = manager.getAppWidgetInfo(id) ?: return null
            (host.createView(activity, id, info) as LauncherWidgetView).also { views[id] = it }
        }
        v.onLongPress = onLongPress
        (v.parent as? ViewGroup)?.removeView(v)
        return v
    }

    override fun resize(id: Int, widthDp: Int, heightDp: Int) {
        val v = views[id] ?: return
        @Suppress("DEPRECATION")
        runCatching { v.updateAppWidgetSize(Bundle(), widthDp, heightDp, widthDp, heightDp) }
    }

    override fun delete(id: Int) {
        views.remove(id)?.let { (it.parent as? ViewGroup)?.removeView(it) }
        runCatching { host.deleteAppWidgetId(id) }
    }

    override fun allocated(): List<Int> =
        if (Build.VERSION.SDK_INT >= 26) runCatching { host.appWidgetIds.toList() }.getOrDefault(emptyList()).filter { it != pending?.first } else emptyList()
}
