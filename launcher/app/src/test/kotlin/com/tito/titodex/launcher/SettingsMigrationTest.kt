package com.tito.titodex.launcher

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SettingsMigrationTest {
    /** Shape written by the 0.2.0 Flutter build (schema 2). */
    private val v2 = """
        {"style":"plastic","wallpaper":"photo","effect":"frost","name":"小智","photo":"/data/user/0/com.tito.titodex.launcher/files/wallpaper-1.jpg",
         "city":{"name":"上海 · 中国","lat":31.22,"lon":121.46},"favorites":["a.b/A","c.d/C"],"use24Hour":false,"schema":2,
         "layout":"dashboard","modules":[{"id":"trainer","visible":false,"wide":false},{"id":"titodex","visible":true,"wide":false},
         {"id":"favorites","visible":true,"wide":true},{"id":"recent","visible":true,"wide":true}],
         "opacity":0.86,"blurPanels":false,"reduceMotion":true,"showWeather":false,"showKeyHints":true,"libraryColumns":4,
         "motto":"去冒险","recent":["c.d/C","e.f/E"]}
    """.trimIndent()

    @Test fun migratesEveryV2Field() {
        val s = Settings.decode(v2)
        assertEquals(LauncherTheme.plastic, s.theme)
        assertEquals(Wall.photo, s.wallpaper)
        assertEquals(Effect.frost, s.effect)
        assertEquals("小智", s.name)
        assertEquals("去冒险", s.motto)
        assertEquals("上海 · 中国", s.city?.name)
        assertEquals(listOf("a.b/A", "c.d/C"), s.pinned)
        assertEquals(listOf("c.d/C", "e.f/E"), s.recent)
        assertFalse(s.use24Hour)
        assertFalse(s.showWeather)
        assertFalse(s.blurPanels)
        assertFalse(s.motion)
        assertEquals(Hints.always, s.hints)
        assertEquals(4, s.libraryColumns)
        assertTrue(s.fillRecent)
        assertEquals((1 - .86f) / .42f, s.reveal, 1e-4f)
    }

    @Test fun dashboardBecomesPanelAndModulesBecomeHiddenFlags() {
        val s = Settings.decode(v2)
        for (o in Orient.entries) {
            val panel = Grid.template(o, Template.panel)
            val layout = s.layout(o)
            assertEquals(panel.map { it.id to (it.c to it.r) }, layout.map { it.id to (it.c to it.r) })
            assertTrue(layout.first { it.id == "trainer" }.hidden)
            assertFalse(layout.first { it.id == "shelf" }.hidden)
            assertFalse(layout.first { it.id == "tito" }.hidden)
        }
    }

    @Test fun roundTripsSchema3() {
        val s = Settings.decode(v2)
        val again = Settings.decode(s.encode())
        assertEquals(s, again)
        assertEquals(3, JSONObject(s.encode()).getInt("schema"))
    }

    @Test fun keepsPreferenceKeyNamesReadableByTheOldBuild() {
        val json = JSONObject(Settings.decode(v2).encode())
        assertEquals("plastic", json.getString("style"))
        assertEquals(2, json.getJSONArray("favorites").length())
    }

    @Test fun recentHiddenOrMissingModules() {
        val hidden = Settings.decode("""{"schema":2,"modules":[{"id":"recent","visible":false}]}""")
        assertFalse(hidden.fillRecent)
        val noModules = Settings.decode("""{"schema":2}""")
        assertTrue(noModules.fillRecent)
    }

    @Test fun clampsOpacityAndDefaultsV1() {
        assertEquals(0f, Settings.decode("""{"schema":2,"opacity":5}""").reveal, 1e-4f)
        assertEquals(.3f / .42f, Settings.decode("""{"schema":2,"opacity":0.1}""").reveal, 1e-4f)
        val v1 = Settings.decode("""{"style":"flat","name":"红"}""")
        assertEquals(LauncherTheme.flat, v1.theme)
        assertEquals("红", v1.name)
        assertEquals(Grid.template(Orient.square, Template.roam), v1.layout(Orient.square))
    }

    @Test fun corruptDataNeverThrows() {
        assertEquals(Settings(), Settings.decode(null))
        assertEquals(Settings(), Settings.decode("not json"))
        val s = Settings.decode("""{"schema":3,"style":42,"wallpaper":"photo","photo":null,"layouts":{"square":[{"id":"bogus"},{"id":"tito","c":9,"r":9,"size":"zz"},{"id":"tito"}]}}""")
        assertEquals(LauncherTheme.journal, s.theme)
        assertEquals(Wall.none, s.wallpaper)
        val sq = s.layout(Orient.square)
        assertEquals(Grid.BUILT_IN.toSet(), sq.map { it.id }.toSet())
        val tito = sq.first { it.id == "tito" }
        assertFalse(tito.hidden)
        assertTrue(Grid.inBounds(Orient.square, tito.c, tito.r, 1, 1))
        assertEquals(Grid.template(Orient.land, Template.roam), s.layout(Orient.land))
    }

    @Test fun longStringsAreTrimmed() {
        val s = Settings.decode(JSONObject().put("schema", 3).put("name", "x".repeat(50)).put("motto", "😀".repeat(50)).toString())
        assertEquals(20, s.name.length)
        assertEquals(40, s.motto.codePointCount(0, s.motto.length))
        assertNull(s.city)
    }
}
