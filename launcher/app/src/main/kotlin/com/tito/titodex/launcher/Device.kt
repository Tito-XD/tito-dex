package com.tito.titodex.launcher

import android.view.View
import androidx.compose.ui.graphics.ImageBitmap

enum class SystemEntry { requestHome, homeSettings, wifi, settings }

data class DeviceStatus(val battery: Int = -1, val charging: Boolean = false, val online: Boolean = false, val wifi: Boolean = false, val defaultHome: Boolean = false)

data class WidgetProvider(
    val key: String,
    val label: String,
    val appLabel: String,
    val pkg: String,
    /** Minimum size in dp, already reduced to the resizable minimum when the provider allows resizing. */
    val minWidthDp: Int,
    val minHeightDp: Int,
    val icon: ImageBitmap?,
)

data class WidgetInfo(val label: String, val minWidthDp: Int, val minHeightDp: Int)

/** Everything the UI needs from Android, so the Compose tree can run under Robolectric with a fake. */
interface Device {
    fun loadSettings(): String?
    fun saveSettings(json: String)
    fun loadApps(): List<AppEntry>
    fun icon(app: AppEntry): ImageBitmap?
    fun status(): DeviceStatus
    fun launch(app: AppEntry): Boolean
    fun launchPackage(pkg: String): Boolean
    fun appInfo(pkg: String): Boolean
    fun open(entry: SystemEntry): Boolean
    /** Imports a photo into private storage; the callback gets the private path, or null when cancelled. */
    fun pickPhoto(result: (Result<String?>) -> Unit)
    fun photo(path: String): ImageBitmap?
    val widgets: WidgetBridge?
}

interface WidgetBridge {
    fun providers(): List<WidgetProvider>
    /** Allocates, binds (asking the user when needed) and configures. The callback gets the new id or null. */
    fun add(provider: WidgetProvider, result: (Int?) -> Unit)
    fun info(id: Int): WidgetInfo?
    fun view(id: Int, onLongPress: () -> Unit): View?
    fun resize(id: Int, widthDp: Int, heightDp: Int)
    fun delete(id: Int)
    fun allocated(): List<Int>
}
