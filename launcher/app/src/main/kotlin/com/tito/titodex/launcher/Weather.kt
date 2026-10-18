package com.tito.titodex.launcher

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Calendar
import java.util.SimpleTimeZone
import java.util.TimeZone
import kotlin.math.roundToInt

data class HourForecast(val label: String, val temperature: Int, val code: Int)

data class DayForecast(val label: String, val high: Int, val low: Int, val code: Int)

data class WeatherReading(
    val temperature: Double,
    val code: Int,
    val receivedAt: Long,
    val hours: List<HourForecast> = emptyList(),
    val days: List<DayForecast> = emptyList(),
) {
    val description: String get() = weatherDescription(code)
}

fun weatherDescription(code: Int) = when (code) {
    0 -> "晴"
    1, 2 -> "晴间多云"
    3 -> "阴"
    45, 48 -> "雾"
    51, 53, 55, 56, 57 -> "毛毛雨"
    61, 63, 65, 66, 67 -> "雨"
    71, 73, 75, 77 -> "雪"
    80, 81, 82 -> "阵雨"
    85, 86 -> "阵雪"
    95, 96, 97, 99 -> "雷雨"
    else -> "天气未知"
}

interface WeatherSource {
    fun search(query: String): List<City>
    fun current(city: City): WeatherReading
}

/** Open-Meteo, only after the user picks a city. No location permission. Blocking; call off the main thread. */
class OpenMeteo : WeatherSource {
    private fun get(url: String): JSONObject {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 10_000
        conn.readTimeout = 15_000
        try {
            if (conn.responseCode != 200) error("天气服务暂时不可用")
            val bytes = conn.inputStream.use { stream ->
                val out = java.io.ByteArrayOutputStream()
                val buf = ByteArray(8192)
                while (true) {
                    val n = stream.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                    if (out.size() > 256 * 1024) error("天气响应过大")
                }
                out.toByteArray()
            }
            return JSONObject(String(bytes, Charsets.UTF_8))
        } finally {
            conn.disconnect()
        }
    }

    override fun search(query: String): List<City> {
        val q = URLEncoder.encode(query.trim(), "UTF-8")
        val json = get("https://geocoding-api.open-meteo.com/v1/search?name=$q&count=8&language=zh&format=json")
        val rows = json.optJSONArray("results") ?: return emptyList()
        return (0 until rows.length()).mapNotNull { i ->
            val row = rows.optJSONObject(i) ?: return@mapNotNull null
            val name = listOf("name", "admin1", "country").mapNotNull { row.opt(it) as? String }.distinct().joinToString(" · ")
            City(name, row.optDouble("latitude"), row.optDouble("longitude")).takeIf { it.lat.isFinite() && it.lon.isFinite() }
        }
    }

    override fun current(city: City): WeatherReading {
        val json = get(
            "https://api.open-meteo.com/v1/forecast?latitude=${city.lat}&longitude=${city.lon}" +
                "&current=temperature_2m,weather_code" +
                "&hourly=temperature_2m,weather_code&forecast_hours=18" +
                "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=4" +
                "&temperature_unit=celsius&timezone=auto",
        )
        return parseOpenMeteo(json, System.currentTimeMillis())
    }
}

/** Current conditions plus the next hours and days. Missing forecast arrays stay empty. */
fun parseOpenMeteo(json: JSONObject, nowMillis: Long): WeatherReading {
    val current = json.getJSONObject("current")
    val temperature = current.getDouble("temperature_2m")
    require(temperature.isFinite())
    val zone = SimpleTimeZone(json.optInt("utc_offset_seconds", 0) * 1000, "forecast")
    return WeatherReading(
        temperature,
        current.getInt("weather_code"),
        nowMillis,
        parseHours(json.optJSONObject("hourly"), nowMillis, zone),
        parseDays(json.optJSONObject("daily"), nowMillis, zone),
    )
}

private fun parseHours(hourly: JSONObject?, nowMillis: Long, zone: TimeZone): List<HourForecast> {
    if (hourly == null) return emptyList()
    val times = hourly.optJSONArray("time") ?: return emptyList()
    val temps = hourly.optJSONArray("temperature_2m") ?: return emptyList()
    val codes = hourly.optJSONArray("weather_code") ?: return emptyList()
    val out = mutableListOf<HourForecast>()
    for (i in 0 until minOf(times.length(), temps.length(), codes.length())) {
        val at = parseLocalIso(times.optString(i), zone) ?: continue
        if (at + 60 * 60_000 <= nowMillis) continue
        val temp = temps.optDouble(i)
        if (!temp.isFinite()) continue
        val cal = Calendar.getInstance(zone).apply { timeInMillis = at }
        out.add(HourForecast("${cal.get(Calendar.HOUR_OF_DAY)}时", temp.roundToInt(), codes.optInt(i, -1)))
        if (out.size == 6) break
    }
    return out
}

private fun parseDays(daily: JSONObject?, nowMillis: Long, zone: TimeZone): List<DayForecast> {
    if (daily == null) return emptyList()
    val times = daily.optJSONArray("time") ?: return emptyList()
    val highs = daily.optJSONArray("temperature_2m_max") ?: return emptyList()
    val lows = daily.optJSONArray("temperature_2m_min") ?: return emptyList()
    val codes = daily.optJSONArray("weather_code") ?: return emptyList()
    val today = Calendar.getInstance(zone).apply { timeInMillis = nowMillis }
    val todayKey = today.get(Calendar.YEAR) * 1000 + today.get(Calendar.DAY_OF_YEAR)
    val out = mutableListOf<DayForecast>()
    for (i in 0 until minOf(times.length(), highs.length(), lows.length(), codes.length())) {
        val at = parseLocalIso(times.optString(i), zone) ?: continue
        val cal = Calendar.getInstance(zone).apply { timeInMillis = at }
        val key = cal.get(Calendar.YEAR) * 1000 + cal.get(Calendar.DAY_OF_YEAR)
        if (key < todayKey) continue
        val high = highs.optDouble(i)
        val low = lows.optDouble(i)
        if (!high.isFinite() || !low.isFinite()) continue
        val weekday = "周" + "日一二三四五六"[cal.get(Calendar.DAY_OF_WEEK) - 1]
        out.add(DayForecast(if (key == todayKey) "今天" else weekday, high.roundToInt(), low.roundToInt(), codes.optInt(i, -1)))
        if (out.size == 4) break
    }
    return out
}

/** Open-Meteo local timestamps: `2026-10-17T21:00` or `2026-10-17`. */
internal fun parseLocalIso(value: String, zone: TimeZone = TimeZone.getDefault()): Long? {
    val date = value.take(10).split("-")
    if (date.size != 3) return null
    val year = date[0].toIntOrNull() ?: return null
    val month = date[1].toIntOrNull() ?: return null
    val day = date[2].toIntOrNull() ?: return null
    if (!Regex("\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2})?").matches(value)) return null
    val cal = Calendar.getInstance(zone).apply {
        clear()
        isLenient = false
        set(Calendar.YEAR, year)
        set(Calendar.MONTH, month - 1)
        set(Calendar.DAY_OF_MONTH, day)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }
    if (value.length >= 16 && value[10] == 'T') {
        val hour = value.substring(11, 13).toIntOrNull() ?: return null
        val minute = value.substring(14, 16).toIntOrNull() ?: return null
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute)
    } else {
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
    }
    return runCatching { cal.timeInMillis }.getOrNull()
}
