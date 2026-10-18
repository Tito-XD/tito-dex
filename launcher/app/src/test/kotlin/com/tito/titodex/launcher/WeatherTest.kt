package com.tito.titodex.launcher

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertNull

class WeatherTest {
    @Test fun forecastKeepsUpcomingHoursAndDays() {
        val now = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.OCTOBER, 17, 21, 10, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val json = JSONObject(
            """
            {
              "current": {"temperature_2m": 22.4, "weather_code": 3},
              "hourly": {
                "time": ["2026-10-17T20:00", "2026-10-17T21:00", "2026-10-17T22:00", "2026-10-18T01:00"],
                "temperature_2m": [21.2, 22.4, 20.6, 18.1],
                "weather_code": [2, 3, 61, 0]
              },
              "daily": {
                "time": ["2026-10-16", "2026-10-17", "2026-10-18"],
                "temperature_2m_max": [24, 23, 19],
                "temperature_2m_min": [16, 15, 12],
                "weather_code": [0, 3, 61]
              }
            }
            """.trimIndent(),
        )
        val reading = parseOpenMeteo(json, now)
        assertEquals(22.4, reading.temperature, 0.01)
        assertEquals("阴", reading.description)
        assertEquals(listOf("21时", "22时", "1时"), reading.hours.map { it.label })
        assertEquals(listOf("今天", "周日"), reading.days.map { it.label })
        assertEquals(23, reading.days.first().high)
        assertEquals(15, reading.days.first().low)
    }

    @Test fun forecastUsesChosenCityOffsetAndKeepsCurrentHour() {
        val now = parseLocalIso("2026-10-17T13:50", TimeZone.getTimeZone("UTC"))!!
        val json = JSONObject("""{
          "utc_offset_seconds":28800,
          "current":{"temperature_2m":18,"weather_code":0},
          "hourly":{"time":["2026-10-17T20:00","2026-10-17T21:00","2026-10-17T22:00"],
          "temperature_2m":[20,19,18],"weather_code":[0,null,3]},
          "daily":{"time":["2026-10-17","2026-10-18"],
          "temperature_2m_max":[24,22],"temperature_2m_min":[15,14],"weather_code":[0,3]}
        }""")
        val reading = parseOpenMeteo(json, now)
        assertEquals(listOf("21时", "22时"), reading.hours.map { it.label })
        assertEquals("天气未知", weatherDescription(reading.hours.first().code))
        assertEquals(listOf("今天", "周日"), reading.days.map { it.label })
        assertNull(parseLocalIso("2026-02-31T20:00"))
    }

    @Test fun missingForecastStaysEmpty() {
        val reading = parseOpenMeteo(JSONObject("""{"current":{"temperature_2m":1,"weather_code":0}}"""), 0L)
        assertTrue(reading.hours.isEmpty())
        assertTrue(reading.days.isEmpty())
    }
}
