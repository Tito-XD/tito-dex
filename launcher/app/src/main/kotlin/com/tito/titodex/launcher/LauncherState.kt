package com.tito.titodex.launcher

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Rect
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

enum class Mode { Home, Library, Edit }
enum class EditTab(val label: String) { layout("布局"), look("外观"), wall("壁纸") }
enum class InputKind { Touch, Pad }
enum class PadButton { A, B, X, Y, Start, Select, L1, R1 }
enum class Dir(val dc: Int, val dr: Int) { Up(0, -1), Down(0, 1), Left(-1, 0), Right(1, 0) }

sealed interface Pop {
    val anchor: Rect
    data class AppMenu(val app: AppEntry, val fromShelf: Boolean, override val anchor: Rect) : Pop
    data class Tito(override val anchor: Rect) : Pop
    data class Trainer(override val anchor: Rect) : Pop
    data class Weather(override val anchor: Rect) : Pop
}

data class ToastMsg(val id: Int, val text: String, val action: String? = null, val undoTo: Settings? = null, val millis: Long = 5000, val onAction: (() -> Unit)? = null)

class Session(val start: Settings) { val stack = ArrayDeque<Settings>() }

/** An app icon being dragged: shelf reorder / remove, or library → shelf. Position is in root pixels. */
data class IconDrag(val app: AppEntry, val pos: androidx.compose.ui.geometry.Offset, val fromShelf: Boolean, val insert: Int? = null, val overRemove: Boolean = false)

class LauncherState(
    val device: Device,
    private val weatherSource: WeatherSource,
    private val scope: CoroutineScope,
    private val io: CoroutineDispatcher = Executors.newSingleThreadExecutor().asCoroutineDispatcher(),
) {
    var settings by mutableStateOf(Settings())
        private set
    var apps by mutableStateOf(emptyList<AppEntry>())
    var appsError by mutableStateOf<String?>(null)
    var status by mutableStateOf(DeviceStatus())
    var loaded by mutableStateOf(false)

    var mode by mutableStateOf(Mode.Home)
        private set
    var tab by mutableStateOf(EditTab.layout)
    var selected by mutableStateOf<String?>(null)
    var holding by mutableStateOf<String?>(null)
    var picker by mutableStateOf(false)
    var query by mutableStateOf("")
    var settingsOpen by mutableStateOf(false)
    var cityDialog by mutableStateOf(false)
    var widgetPicker by mutableStateOf(false)
    var licenses by mutableStateOf(false)
    var pop by mutableStateOf<Pop?>(null)
    var toast by mutableStateOf<ToastMsg?>(null)
        private set
    var input by mutableStateOf(InputKind.Touch)
    var orient by mutableStateOf(Orient.square)
    var focusKey by mutableStateOf<String?>(null)
    var searchFocusRequest by mutableIntStateOf(0)
    var homeFocusRequest by mutableIntStateOf(0)
    var libJumpRequest by mutableStateOf<Pair<Int, Int>?>(null)
    var iconDrag by mutableStateOf<IconDrag?>(null)
    /** Sheet offset from fully open, in px, while a finger drags it; null when it rests. */
    var sheetPull by mutableStateOf<Float?>(null)
    var shelfScroll by mutableStateOf(0f)
    var shelfMax by mutableStateOf(0f)

    var weather by mutableStateOf<WeatherReading?>(null)
    var weatherError by mutableStateOf<String?>(null)
    private var weatherAttempt = 0L
    private var weatherBusy = false
    private var weatherRequest = 0

    var session by mutableStateOf<Session?>(null)
        private set
    private var pickBefore: Settings? = null
    private var pendingWidget = false
    private var toastSeq = 0
    private var toastJob: Job? = null

    /** Hit areas in root coordinates, reported by composables for popover anchors and drag targets. */
    val rects = mutableMapOf<String, Rect>()

    val coach: Boolean get() = !settings.coachSeen && mode == Mode.Home && !settingsOpen

    fun layout(): List<Sticker> = settings.layout(orient)

    fun start() {
        scope.launch {
            val raw = withContext(io) { runCatching { device.loadSettings() }.getOrNull() }
            settings = Settings.decode(raw)
            loaded = true
            refreshApps()
            refreshStatus()
            refreshWeather()
            gcWidgets()
        }
    }

    fun refreshApps() {
        scope.launch {
            val result = withContext(io) { runCatching { device.loadApps() } }
            result.onSuccess { apps = it; appsError = null }.onFailure { appsError = "应用库读取失败，点击重试" }
        }
    }

    fun refreshStatus() {
        scope.launch { withContext(io) { runCatching { device.status() }.getOrNull() }?.let { status = it } }
    }

    fun refreshWeather(force: Boolean = false) {
        val city = settings.city ?: return
        if (weatherBusy) return
        val now = System.currentTimeMillis()
        if (!force && now - weatherAttempt < 30 * 60_000) return
        weatherAttempt = now
        weatherBusy = true
        val request = ++weatherRequest
        scope.launch {
            val result = withContext(io) { runCatching { weatherSource.current(city) } }
            if (request != weatherRequest) return@launch
            weatherBusy = false
            result.onSuccess { weather = it; weatherError = null }.onFailure { weatherError = "天气暂不可用" }
        }
    }

    fun searchCities(q: String, done: (Result<List<City>>) -> Unit) {
        scope.launch { done(withContext(io) { runCatching { weatherSource.search(q) } }) }
    }

    fun setCity(city: City?) {
        weatherRequest++
        weatherBusy = false
        weatherAttempt = 0
        weather = null
        weatherError = null
        commit(settings.copy(city = city, showWeather = true), if (city == null) "天气已关闭" else "天气城市：${city.name}")
        refreshWeather(force = true)
    }

    private fun persist() {
        val json = settings.encode()
        scope.launch(io) { runCatching { device.saveSettings(json) } }
    }

    /** Applies a change. Inside 整理桌面 it joins the undo stack; elsewhere an optional toast offers 撤销. */
    fun commit(next: Settings, toastText: String? = null): Boolean {
        if (next == settings) return false
        val before = settings
        val s = session
        if (mode == Mode.Edit && s != null) s.stack.addLast(before)
        else if (toastText != null) showToast(toastText, "撤销", undoTo = before)
        settings = next
        persist()
        return true
    }

    /** Silent change that is not worth an undo step (recent list, coach). */
    private fun quietly(next: Settings) {
        if (next == settings) return
        settings = next
        persist()
    }

    fun showToast(text: String, action: String? = null, undoTo: Settings? = null, millis: Long = 5000, onAction: (() -> Unit)? = null) {
        val t = ToastMsg(++toastSeq, text, action, undoTo, millis, onAction)
        toast = t
        toastJob?.cancel()
        toastJob = scope.launch {
            delay(millis)
            if (toast?.id == t.id) { toast = null; gcWidgets() }
        }
    }

    fun toastAction() {
        val t = toast ?: return
        toast = null
        t.undoTo?.let { restore(it) }
        t.onAction?.invoke()
        gcWidgets()
    }

    private fun restore(to: Settings) {
        settings = to
        persist()
    }

    fun dismissCoach() { if (!settings.coachSeen) quietly(settings.copy(coachSeen = true)) }

    // ---------------------------------------------------------------- navigation

    fun openLibrary(search: Boolean = false, pick: Boolean = false) {
        sheetPull = null
        pop = null
        dismissCoach()
        if (mode == Mode.Edit) finishEdit()
        settingsOpen = false
        mode = Mode.Library
        picker = pick
        if (pick) pickBefore = settings
        if (search) searchFocusRequest++
    }

    fun closeLibrary() {
        sheetPull = null
        if (picker) finishPicker()
        mode = Mode.Home
        query = ""
        pop = null
    }

    fun enterEdit(t: EditTab = EditTab.layout, sel: String? = null) {
        pop = null
        dismissCoach()
        settingsOpen = false
        if (mode == Mode.Library) closeLibrary()
        mode = Mode.Edit
        tab = t
        selected = sel
        holding = null
        session = Session(settings)
    }

    fun finishEdit() {
        val s = session ?: return
        session = null
        mode = Mode.Home
        selected = null
        holding = null
        pop = null
        if (settings != s.start) showToast("桌面已更新", "撤销本次整理", undoTo = s.start, millis = 10_000)
        else gcWidgets()
        homeFocusRequest++
    }

    fun undo() {
        val s = session ?: return
        val prev = s.stack.removeLastOrNull() ?: return
        settings = prev
        persist()
        if (selected != null && layout().none { it.id == selected && !it.hidden }) selected = null
    }

    fun openSettings() {
        if (mode == Mode.Edit) finishEdit()
        if (mode == Mode.Library) closeLibrary()
        pop = null
        settingsOpen = true
    }

    fun goHome() {
        sheetPull = null
        iconDrag = null
        pop = null
        cityDialog = false
        widgetPicker = false
        licenses = false
        settingsOpen = false
        when (mode) {
            Mode.Edit -> finishEdit()
            Mode.Library -> closeLibrary()
            Mode.Home -> {}
        }
        homeFocusRequest++
    }

    /** Android back and the B button. Returns false only when nothing was left to close. */
    fun back(): Boolean {
        when {
            pop != null -> pop = null
            licenses -> licenses = false
            cityDialog -> cityDialog = false
            widgetPicker -> widgetPicker = false
            settingsOpen -> settingsOpen = false
            mode == Mode.Library -> closeLibrary()
            mode == Mode.Edit && holding != null -> holding = null
            mode == Mode.Edit -> finishEdit()
            else -> { homeFocusRequest++; return false }
        }
        return true
    }

    // ---------------------------------------------------------------- apps

    fun launch(app: AppEntry) {
        pop = null
        if (device.launch(app)) {
            quietly(settings.recordLaunch(app.id))
            if (mode == Mode.Library) closeLibrary()
        } else {
            showToast("应用无法打开，可能已停用或卸载")
            refreshApps()
        }
    }

    fun launchTitoDex() {
        pop = null
        if (!device.launchPackage(TITODEX_PACKAGE)) showToast("尚未安装 TitoDex，请先安装正式版 TitoDex App")
        else apps.firstOrNull { it.pkg == TITODEX_PACKAGE }?.let { quietly(settings.recordLaunch(it.id)) }
    }

    fun appInfo(pkg: String) {
        pop = null
        if (!device.appInfo(pkg)) showToast("设备暂不支持此入口")
    }

    fun system(entry: SystemEntry) {
        if (!device.open(entry)) showToast("系统入口暂时不可用")
    }

    fun togglePin(app: AppEntry) {
        pop = null
        val pinned = app.id in settings.pinned
        val next = settings.togglePinned(app.id) ?: run { showToast("常玩最多 12 个，先移出一个"); return }
        commit(next, if (pinned) "已移出常玩：${app.label}" else "已加入常玩：${app.label}")
    }

    fun pickerToggle(app: AppEntry) {
        val next = settings.togglePinned(app.id) ?: run { showToast("常玩最多 12 个，先取消一个"); return }
        settings = next
        persist()
    }

    fun finishPicker() {
        val before = pickBefore
        pickBefore = null
        picker = false
        if (before != null && before != settings) showToast("常玩已更新", "撤销", undoTo = before)
    }

    /** Shelf reorder, library-to-shelf drop, or drag to the top strip to remove. */
    fun dropOnShelf(app: AppEntry, index: Int) {
        val adding = app.id !in settings.pinned
        if (adding && settings.pinned.size >= MAX_PINNED) { showToast("常玩最多 12 个，先移出一个"); return }
        commit(settings.movePinned(app.id, index), if (adding) "已加入常玩：${app.label}" else "常玩顺序已调整")
    }

    /** Insertion index on the home shelf for a dragged icon at [pos] (root px), or null when not over the shelf. */
    fun shelfInsertAt(pos: androidx.compose.ui.geometry.Offset, density: Float): Int? {
        val box = rects["shelfbox"] ?: return null
        if (layout().firstOrNull { it.id == "shelf" }?.hidden != false) return null
        val inside = pos.x >= box.left - 10 * density && pos.x <= box.right + 10 * density &&
            pos.y >= box.top - 24 * density && pos.y <= box.bottom + 10 * density
        if (!inside) return null
        val icons = settings.pinned.mapIndexedNotNull { i, id -> rects["shelf:$id"]?.let { i to it } }
        if (icons.isEmpty()) return 0
        val (i, r) = icons.minBy { (_, r) -> kotlin.math.hypot(pos.x - r.center.x, (pos.y - r.center.y) * 1.6f) }
        return i + if (pos.x > r.center.x) 1 else 0
    }

    fun unpin(app: AppEntry) {
        pop = null
        if (app.id in settings.pinned) commit(settings.copy(pinned = settings.pinned - app.id), "已移出常玩：${app.label}")
    }

    fun saveTrainer(name: String, motto: String) {
        pop = null
        val n = name.trim().ifEmpty { "训练家" }.take(20)
        val m = motto.trim().take(40)
        commit(settings.copy(name = n, motto = m), "名片已更新")
    }

    // ---------------------------------------------------------------- editing

    private fun commitLayout(list: List<Sticker>?) : Boolean {
        if (list == null) return false
        return commit(settings.withLayout(orient, list))
    }

    fun select(id: String?) { selected = id; tab = EditTab.layout }

    fun resizeSelected(option: SizeOption) {
        val id = selected ?: return
        if (!commitLayout(Grid.resize(orient, layout(), id, option)) && layout().firstOrNull { it.id == id }?.size != option.key)
            showToast("空间不够：先挪开或隐藏其他贴纸")
        resizeWidgetView(id)
    }

    fun cycleSize(id: String) {
        selected = id
        val opts = sizeOptions(id)
        if (opts.isEmpty()) return
        val st = layout().firstOrNull { it.id == id } ?: return
        val i = opts.indexOfFirst { it.key == st.size }
        resizeSelected(opts[(i + 1) % opts.size])
    }

    fun sizeOptions(id: String): List<SizeOption> {
        val st = layout().firstOrNull { it.id == id } ?: return emptyList()
        val wid = st.widgetId ?: return Grid.options(orient, id)
        val info = device.widgets?.info(wid)
        val (cw, ch) = cellDp()
        val minW = if (info == null) 1 else spanFor(info.minWidthDp, cw)
        val minH = if (info == null) 1 else spanFor(info.minHeightDp, ch)
        return Grid.widgetOptions(orient, minW, minH)
    }

    var screenDp: Pair<Float, Float> = 480f to 480f

    fun cellDp(): Pair<Float, Float> {
        val g = Grid.spec(orient)
        val (w, h) = screenDp
        return (w - Grid.PAD * 2) / g.cols to (h - Grid.TOP - Grid.BOTTOM) / g.rows
    }

    private fun spanFor(dp: Int, cell: Float) = kotlin.math.ceil((dp - 10f).coerceAtLeast(1f) / cell).toInt().coerceAtLeast(1)

    fun moveSticker(id: String, c: Int, r: Int): Boolean {
        val st = layout().firstOrNull { it.id == id } ?: return false
        if (st.c == c && st.r == r) return true
        val next = Grid.move(orient, layout(), id, c, r)
        if (next == null) { showToast("这里放不下，已放回原处"); return false }
        commitLayout(next)
        return true
    }

    fun hide(id: String) {
        if (id == "tito") { showToast("TitoDex 是固定入口，不能隐藏"); return }
        val st = layout().firstOrNull { it.id == id } ?: return
        if (st.isWidget) {
            commit(settings.copy(layouts = settings.layouts.mapValues { (_, l) -> l.filter { it.id != id } }))
            selected = null
            showToast("已移除小组件，可在上方撤销")
            return
        }
        commitLayout(layout().map { if (it.id == id) it.copy(hidden = true) else it })
        selected = null
        showToast("已隐藏 ${Grid.LABEL[id]}，可在下方托盘找回")
    }

    fun show(id: String) {
        val next = Grid.show(orient, layout(), id)
        if (next == null) { showToast("没有空位：先缩小或挪开其他贴纸"); return }
        commitLayout(next)
        selected = id
    }

    fun applyTemplate(t: Template) {
        val widgets = layout().filter { it.isWidget }
        var list = Grid.template(orient, t)
        for (w in widgets) {
            val z = Grid.sizeOf(w, orient)
            val spot = Grid.findFree(orient, list, w.id, Spot(w.c, w.r), z.w, z.h)
            list = list + if (spot == null) w.copy(hidden = true) else w.copy(c = spot.c, r = spot.r, hidden = false)
        }
        selected = null
        commitLayout(list)
    }

    fun padMove(dir: Dir) {
        val id = holding ?: return
        val st = layout().firstOrNull { it.id == id } ?: return
        Grid.move(orient, layout(), id, st.c + dir.dc, st.r + dir.dr)?.let { commitLayout(it) }
    }

    fun stickerLabel(st: Sticker): String =
        st.widgetId?.let { device.widgets?.info(it)?.label ?: "小组件" } ?: Grid.LABEL[st.id] ?: st.id

    // ---------------------------------------------------------------- widgets

    fun addWidget(p: WidgetProvider) {
        val bridge = device.widgets ?: return
        widgetPicker = false
        pendingWidget = true
        bridge.add(p) { id ->
            pendingWidget = false
            if (id == null) { showToast("没有添加小组件"); return@add }
            val (cw, ch) = cellDp()
            val w = spanFor(p.minWidthDp, cw)
            val h = spanFor(p.minHeightDp, ch)
            var next = settings
            for (o in Orient.entries) next = next.withLayout(o, Grid.addWidget(o, next.layout(o), id, w, h))
            val placed = next.layout(orient).first { it.widgetId == id }
            commit(next)
            if (placed.hidden) showToast("桌面没有空位：先缩小或隐藏贴纸，再从托盘找回 ${p.label}")
            else selected = placed.id
            resizeWidgetView(placed.id)
        }
    }

    suspend fun loadWidgetProviders(): List<WidgetProvider> =
        withContext(io) { runCatching { device.widgets?.providers() ?: emptyList() }.getOrDefault(emptyList()) }

    fun resizeWidgetView(id: String) {
        val st = layout().firstOrNull { it.id == id } ?: return
        val wid = st.widgetId ?: return
        val z = Grid.sizeOf(st, orient)
        val (cw, ch) = cellDp()
        device.widgets?.resize(wid, (z.w * cw - 10).toInt(), (z.h * ch - 10).toInt())
    }

    /** Releases host ids that no live state or undo snapshot can bring back. */
    fun gcWidgets() {
        val bridge = device.widgets ?: return
        if (pendingWidget) return
        val keep = buildSet {
            addAll(settings.widgetIds())
            session?.let { s -> addAll(s.start.widgetIds()); s.stack.forEach { addAll(it.widgetIds()) } }
            toast?.undoTo?.let { addAll(it.widgetIds()) }
            pickBefore?.let { addAll(it.widgetIds()) }
        }
        for (id in bridge.allocated()) if (id !in keep) bridge.delete(id)
    }

    // ---------------------------------------------------------------- appearance

    fun setTheme(t: LauncherTheme) = commit(settings.copy(theme = t))
    fun setWall(w: Wall) {
        if (w == Wall.photo && settings.photo == null) { pickPhoto(); return }
        commit(settings.copy(wallpaper = w))
    }
    fun setEffect(e: Effect) = commit(settings.copy(effect = e))
    fun resetWallpaper() = commit(settings.resetWallpaper(), "已恢复默认背景")

    private var revealBefore: Settings? = null
    fun previewReveal(v: Float) {
        if (revealBefore == null) revealBefore = settings
        settings = settings.copy(reveal = v)
    }
    fun commitReveal() {
        val before = revealBefore ?: return
        revealBefore = null
        val after = settings
        settings = before
        commit(after)
    }

    var photoBusy by mutableStateOf(false)
    var photoBitmap by mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null)
    private var photoLoaded: String? = null

    /** Decodes the private wallpaper copy off the main thread whenever the referenced file changes. */
    fun loadPhoto() {
        val path = settings.photo
        if (path == photoLoaded) return
        photoLoaded = path
        if (path == null) { photoBitmap = null; return }
        scope.launch {
            val bmp = withContext(io) { runCatching { device.photo(path) }.getOrNull() }
            if (photoLoaded == path) photoBitmap = bmp
        }
    }
    fun pickPhoto() {
        if (photoBusy) return
        photoBusy = true
        device.pickPhoto { result ->
            photoBusy = false
            result.onSuccess { path -> if (path != null) commit(settings.copy(wallpaper = Wall.photo, photo = path, effect = settings.effect)) }
                .onFailure { showToast("图片未能导入，请换一张图片重试") }
        }
    }

    fun update(f: (Settings) -> Settings) = commit(f(settings))

    fun resetAll() {
        val before = settings
        settingsOpen = false
        settings = Settings(coachSeen = true, city = null)
        persist()
        weather = null
        showToast("已恢复全部默认", "撤销", undoTo = before)
    }

    // ---------------------------------------------------------------- gamepad

    /** X / Y / Start / Select / L1 / R1. A and the D-pad go through Compose focus. */
    fun pad(btn: PadButton) {
        input = InputKind.Pad
        if (pop != null || settingsOpen || cityDialog || widgetPicker || licenses) {
            if (btn == PadButton.B) back()
            return
        }
        when (mode) {
            Mode.Edit -> when (btn) {
                PadButton.B -> back()
                PadButton.X -> focusKey?.removePrefix("st:")?.takeIf { focusKey?.startsWith("st:") == true }?.let { cycleSize(it) }
                PadButton.Y -> focusKey?.takeIf { it.startsWith("st:") }?.let { hide(it.removePrefix("st:")) }
                PadButton.Select -> undo()
                PadButton.Start -> finishEdit()
                PadButton.L1, PadButton.R1 -> {
                    val all = EditTab.entries
                    tab = all[(all.indexOf(tab) + if (btn == PadButton.R1) 1 else all.size - 1) % all.size]
                    selected = null
                    holding = null
                }
                PadButton.A -> {}
            }
            Mode.Library -> when (btn) {
                PadButton.B -> back()
                PadButton.X -> optionsForFocus()
                PadButton.Y -> searchFocusRequest++
                PadButton.L1, PadButton.R1 -> libJumpRequest = (if (btn == PadButton.R1) 1 else -1) to ++toastSeq
                else -> {}
            }
            Mode.Home -> when (btn) {
                PadButton.X -> optionsForFocus()
                PadButton.Y -> openLibrary(search = true)
                PadButton.Start -> enterEdit()
                PadButton.Select -> openSettings()
                PadButton.B -> back()
                else -> {}
            }
        }
    }

    fun padActivateSticker(id: String) {
        if (holding != null) { holding = null; return }
        holding = id
        selected = id
    }

    private fun optionsForFocus() {
        val key = focusKey ?: return
        val r = rects[key] ?: Rect.Zero
        pop = when {
            key == "tito" -> Pop.Tito(r)
            key == "trainer" -> Pop.Trainer(r)
            key.startsWith("shelf:") -> apps.firstOrNull { it.id == key.removePrefix("shelf:") }?.let { Pop.AppMenu(it, true, r) }
            key.startsWith("lib") -> apps.firstOrNull { it.id == key.substringAfter(':') }?.let { Pop.AppMenu(it, false, r) }
            else -> null
        }
    }
}
