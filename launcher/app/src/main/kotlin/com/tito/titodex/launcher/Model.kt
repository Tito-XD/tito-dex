package com.tito.titodex.launcher

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

const val TITODEX_PACKAGE = "com.tito.titodex"
const val MAX_PINNED = 12
const val SCHEMA = 3

enum class LauncherTheme(val label: String, val blurb: String) {
    journal("训练家手帐", "纸贴纸 · 胶带 · 印章"),
    plastic("固态塑料", "半透外壳 · 压铸按键"),
    flat("扁平贴纸", "色块 · 大字 · 干脆"),
}

enum class Wall(val label: String) { none("主题默认"), coast("海岸"), dusk("暮色"), forest("森林"), photo("我的照片") }

enum class Effect(val label: String) { clear("原图"), frost("柔焦"), dim("暗色"), scanlines("扫描线") }

enum class Hints(val label: String) { auto("使用手柄时"), always("总是"), off("关闭") }

enum class Orient { square, land }

enum class Template(val label: String) { roam("漫游"), panel("面板"), quiet("留白") }

data class City(val name: String, val lat: Double, val lon: Double) {
    fun toJson(): JSONObject = JSONObject().put("name", name).put("lat", lat).put("lon", lon)

    companion object {
        fun parse(any: Any?): City? {
            if (any !is JSONObject) return null
            val name = any.opt("name") as? String ?: return null
            val lat = (any.opt("lat") as? Number)?.toDouble() ?: return null
            val lon = (any.opt("lon") as? Number)?.toDouble() ?: return null
            if (!lat.isFinite() || !lon.isFinite() || kotlin.math.abs(lat) > 90 || kotlin.math.abs(lon) > 180) return null
            return City(name, lat, lon)
        }
    }
}

/** A sticker on the home grid. Built-in ids: clock, trainer, tito, shelf. Widgets use `widget:<appWidgetId>`. */
data class Sticker(val id: String, val c: Int, val r: Int, val size: String, val hidden: Boolean = false) {
    val widgetId: Int? get() = if (id.startsWith(WIDGET_PREFIX)) id.removePrefix(WIDGET_PREFIX).toIntOrNull() else null
    val isWidget: Boolean get() = widgetId != null

    fun toJson(): JSONObject = JSONObject().put("id", id).put("c", c).put("r", r).put("size", size).put("hidden", hidden)

    companion object {
        const val WIDGET_PREFIX = "widget:"
        fun widget(id: Int, c: Int, r: Int, w: Int, h: Int) = Sticker("$WIDGET_PREFIX$id", c, r, "${w}x$h")
    }
}

data class Settings(
    val theme: LauncherTheme = LauncherTheme.journal,
    val wallpaper: Wall = Wall.none,
    val effect: Effect = Effect.clear,
    val photo: String? = null,
    val name: String = "训练家",
    val motto: String = "今天，也有新的冒险。",
    val city: City? = null,
    val use24Hour: Boolean = true,
    val showWeather: Boolean = true,
    val pinned: List<String> = emptyList(),
    val fillRecent: Boolean = true,
    val recent: List<String> = emptyList(),
    val layouts: Map<Orient, List<Sticker>> = Orient.entries.associateWith { Grid.template(it, Template.roam) },
    val reveal: Float = .45f,
    val motion: Boolean = true,
    val blurPanels: Boolean = true,
    val hints: Hints = Hints.auto,
    val libraryColumns: Int = 5,
    val coachSeen: Boolean = false,
) {
    fun layout(o: Orient): List<Sticker> = layouts[o] ?: Grid.template(o, Template.roam)

    fun withLayout(o: Orient, list: List<Sticker>) = copy(layouts = layouts + (o to list))

    fun updateSticker(o: Orient, id: String, f: (Sticker) -> Sticker) =
        withLayout(o, layout(o).map { if (it.id == id) f(it) else it })

    fun widgetIds(): Set<Int> = layouts.values.flatten().mapNotNull { it.widgetId }.toSet()

    fun recordLaunch(id: String) = copy(recent = (listOf(id) + recent.filter { it != id }).take(12))

    fun togglePinned(id: String): Settings? = when {
        id in pinned -> copy(pinned = pinned - id)
        pinned.size >= MAX_PINNED -> null
        else -> copy(pinned = pinned + id)
    }

    fun movePinned(id: String, insertAt: Int): Settings {
        val list = pinned.filter { it != id }.toMutableList()
        var index = insertAt
        val old = pinned.indexOf(id)
        if (old in 0 until index) index -= 1
        list.add(index.coerceIn(0, list.size), id)
        return copy(pinned = list)
    }

    fun resetWallpaper() = copy(wallpaper = Wall.none, effect = Effect.clear, photo = null)

    fun encode(): String {
        val json = JSONObject()
            .put("schema", SCHEMA)
            .put("style", theme.name)
            .put("wallpaper", wallpaper.name)
            .put("effect", effect.name)
            .put("photo", photo ?: JSONObject.NULL)
            .put("name", name)
            .put("motto", motto)
            .put("city", city?.toJson() ?: JSONObject.NULL)
            .put("use24Hour", use24Hour)
            .put("showWeather", showWeather)
            .put("favorites", JSONArray(pinned))
            .put("fillRecent", fillRecent)
            .put("recent", JSONArray(recent))
            .put("reveal", reveal.toDouble())
            .put("motion", motion)
            .put("blurPanels", blurPanels)
            .put("hints", hints.name)
            .put("libraryColumns", libraryColumns)
            .put("coachSeen", coachSeen)
        val layoutsJson = JSONObject()
        for ((o, list) in layouts) layoutsJson.put(o.name, JSONArray().apply { list.forEach { put(it.toJson()) } })
        json.put("layouts", layoutsJson)
        return json.toString()
    }

    companion object {
        /** Reads schema 3 and migrates schema 1/2 (0.1.0, 0.2.0) preferences. A corrupt value never blocks home. */
        fun decode(raw: String?): Settings {
            val base = Settings()
            val json = try { JSONObject(raw ?: return base) } catch (_: Exception) { return base }
            return try { read(json, base) } catch (_: Exception) { base }
        }

        private inline fun <reified E : Enum<E>> enumOf(value: Any?, fallback: E): E =
            enumValues<E>().firstOrNull { it.name == value } ?: fallback

        private fun strings(any: Any?): List<String> {
            if (any !is JSONArray) return emptyList()
            return (0 until any.length()).mapNotNull { any.opt(it) as? String }
        }

        private fun read(json: JSONObject, base: Settings): Settings {
            val schema = json.optInt("schema", 1)
            var s = base
            s = s.copy(
                theme = enumOf(json.opt("style"), LauncherTheme.journal),
                wallpaper = enumOf(json.opt("wallpaper"), Wall.none),
                effect = enumOf(json.opt("effect"), Effect.clear),
                photo = json.opt("photo") as? String,
                city = City.parse(json.opt("city")),
                use24Hour = json.opt("use24Hour") != false,
                showWeather = json.opt("showWeather") != false,
                pinned = strings(json.opt("favorites")).distinct().take(MAX_PINNED),
                recent = strings(json.opt("recent")).distinct().take(12),
                blurPanels = json.opt("blurPanels") != false,
            )
            if (s.wallpaper == Wall.photo && s.photo == null) s = s.copy(wallpaper = Wall.none)
            (json.opt("name") as? String)?.trim()?.takeIf { it.isNotEmpty() }?.let { s = s.copy(name = it.take(20)) }
            (json.opt("motto") as? String)?.let { m -> s = s.copy(motto = m.codePoints().limit(40).toArray().let { String(it, 0, it.size) }) }
            (json.opt("libraryColumns") as? Number)?.toInt()?.let { s = s.copy(libraryColumns = it.coerceIn(3, 6)) }
            return if (schema >= 3) readV3(json, s) else migrateV2(json, s)
        }

        private fun readV3(json: JSONObject, start: Settings): Settings {
            var s = start.copy(
                fillRecent = json.opt("fillRecent") != false,
                motion = json.opt("motion") != false,
                hints = enumOf(json.opt("hints"), Hints.auto),
                coachSeen = json.opt("coachSeen") == true,
            )
            (json.opt("reveal") as? Number)?.toDouble()?.takeIf { it.isFinite() }?.let { s = s.copy(reveal = it.toFloat().coerceIn(0f, 1f)) }
            val layouts = json.optJSONObject("layouts")
            val map = Orient.entries.associateWith { o ->
                val arr = layouts?.optJSONArray(o.name) ?: return@associateWith Grid.template(o, Template.roam)
                val parsed = (0 until arr.length()).mapNotNull { i ->
                    val row = arr.optJSONObject(i) ?: return@mapNotNull null
                    val id = row.opt("id") as? String ?: return@mapNotNull null
                    Sticker(id, row.optInt("c"), row.optInt("r"), row.optString("size"), row.optBoolean("hidden"))
                }
                Grid.sanitize(o, parsed)
            }
            return s.copy(layouts = map)
        }

        /** 0.2.0: layout preset + module list + opacity; 0.1.0 has none of these and gets the defaults. */
        private fun migrateV2(json: JSONObject, start: Settings): Settings {
            val template = when (json.opt("layout")) {
                "dashboard" -> Template.panel
                "quiet" -> Template.quiet
                else -> Template.roam
            }
            val visible = mutableMapOf<String, Boolean>()
            json.optJSONArray("modules")?.let { arr ->
                for (i in 0 until arr.length()) {
                    val row = arr.optJSONObject(i) ?: continue
                    val id = row.opt("id") as? String ?: continue
                    if (id !in visible) visible[id] = row.opt("visible") != false
                }
            }
            val layouts = Orient.entries.associateWith { o ->
                Grid.template(o, template).map { st ->
                    when (st.id) {
                        "trainer" -> visible["trainer"]?.let { st.copy(hidden = !it) } ?: st
                        "shelf" -> visible["favorites"]?.let { st.copy(hidden = !it) } ?: st
                        else -> st
                    }
                }
            }
            val opacity = (json.opt("opacity") as? Number)?.toDouble()?.takeIf { it.isFinite() }
            return start.copy(
                layouts = layouts,
                fillRecent = visible["recent"] ?: (json.has("modules").not()),
                reveal = if (opacity == null) start.reveal else ((1 - opacity.coerceIn(.7, 1.0)) / .42).toFloat().coerceIn(0f, 1f),
                motion = json.opt("reduceMotion") != true,
                hints = if (json.opt("showKeyHints") == true) Hints.always else Hints.auto,
            )
        }
    }
}

fun greeting(hour: Int) = when {
    hour < 6 -> "夜深了，早点休息"
    hour < 11 -> "早上好"
    hour < 14 -> "中午好"
    hour < 18 -> "下午好"
    else -> "晚上好"
}

fun clockParts(cal: Calendar, use24Hour: Boolean): Pair<String, String> {
    val h = cal.get(Calendar.HOUR_OF_DAY)
    val hour = if (use24Hour) h else if (h % 12 == 0) 12 else h % 12
    return hour.toString().padStart(2, '0') to cal.get(Calendar.MINUTE).toString().padStart(2, '0')
}

fun dateLabel(cal: Calendar): String {
    val wd = "日一二三四五六"[cal.get(Calendar.DAY_OF_WEEK) - 1]
    return "${cal.get(Calendar.MONTH) + 1}/${cal.get(Calendar.DAY_OF_MONTH)} 周$wd"
}

data class AppEntry(val pkg: String, val activity: String, val label: String, val group: String) {
    val id: String get() = "$pkg/$activity"
}

fun filterApps(apps: List<AppEntry>, query: String): List<AppEntry> {
    val needle = query.trim().lowercase()
    if (needle.isEmpty()) return apps
    return apps.filter { it.label.lowercase().contains(needle) || it.pkg.lowercase().contains(needle) }
}

data class ShelfItem(val app: AppEntry, val auto: Boolean)

/** Pinned apps first, then (optionally) recently opened ones to fill the shelf up to six. */
fun shelfItems(s: Settings, apps: List<AppEntry>): List<ShelfItem> {
    val byId = apps.associateBy { it.id }
    val pinned = s.pinned.mapNotNull { byId[it] }.map { ShelfItem(it, false) }
    if (!s.fillRecent) return pinned
    val autos = s.recent.filter { it !in s.pinned }.mapNotNull { byId[it] }
        .take((6 - pinned.size).coerceAtLeast(0)).map { ShelfItem(it, true) }
    return pinned + autos
}

/** Surface alpha per theme; "背景露出" pushes each theme along its own curve. */
fun plateAlpha(s: Settings): Float = when (s.theme) {
    LauncherTheme.journal -> 1 - s.reveal * .42f
    LauncherTheme.plastic -> maxOf(.22f, .9f - s.reveal * .66f)
    LauncherTheme.flat -> 1 - s.reveal * .5f
}

fun inkOnDark(s: Settings): Boolean = s.effect == Effect.dim || s.wallpaper == Wall.dusk || s.wallpaper == Wall.photo ||
    (s.wallpaper == Wall.none && s.theme == LauncherTheme.plastic)
