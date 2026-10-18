package com.tito.titodex.launcher

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class ModelTest {
    private val apps = listOf(
        AppEntry("com.a", "A", "Alpha 游戏", "A"),
        AppEntry("com.b", "B", "Beta", "B"),
        AppEntry("com.retro", "R", "RetroArch", "R"),
    )

    @Test fun filterMatchesLabelAndPackage() {
        assertEquals(apps, filterApps(apps, "  "))
        assertEquals(listOf("com.retro"), filterApps(apps, "retro").map { it.pkg })
        assertEquals(listOf("com.a"), filterApps(apps, "游戏").map { it.pkg })
        assertEquals(listOf("com.b"), filterApps(apps, "COM.B").map { it.pkg })
    }

    @Test fun shelfFillsWithRecentsUpToSix() {
        val s = Settings(pinned = listOf("com.b/B"), recent = listOf("com.b/B", "com.a/A", "gone/X"))
        val items = shelfItems(s, apps)
        assertEquals(listOf("com.b/B" to false, "com.a/A" to true), items.map { it.app.id to it.auto })
        assertEquals(1, shelfItems(s.copy(fillRecent = false), apps).size)
    }

    @Test fun pinnedCapAndReorder() {
        var s = Settings()
        repeat(MAX_PINNED) { s = s.togglePinned("p$it")!! }
        assertNull(s.togglePinned("extra"))
        s = s.movePinned("p0", 3)
        assertEquals(listOf("p1", "p2", "p0", "p3"), s.pinned.take(4))
        s = s.movePinned("p5", 0)
        assertEquals("p5", s.pinned.first())
    }

    @Test fun recentIsDedupedAndCapped() {
        var s = Settings()
        repeat(20) { s = s.recordLaunch("a${it % 14}") }
        assertEquals(12, s.recent.size)
        assertEquals(s.recent.size, s.recent.toSet().size)
    }

    @Test fun widgetIdsSpanBothOrientations() {
        val s = Settings().withLayout(Orient.square, Grid.addWidget(Orient.square, Settings().layout(Orient.square), 5, 1, 1))
            .withLayout(Orient.land, Grid.addWidget(Orient.land, Settings().layout(Orient.land), 9, 1, 1))
        assertEquals(setOf(5, 9), s.widgetIds())
    }

    @Test fun clockAndDate() {
        val cal = Calendar.getInstance().apply { set(2026, Calendar.OCTOBER, 17, 0, 5) }
        assertEquals("00" to "05", clockParts(cal, true))
        assertEquals("12" to "05", clockParts(cal, false))
        assertEquals("10/17 周六", dateLabel(cal))
        assertEquals("夜深了，早点休息", greeting(2))
    }
}
