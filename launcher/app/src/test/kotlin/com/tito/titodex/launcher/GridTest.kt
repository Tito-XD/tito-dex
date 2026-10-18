package com.tito.titodex.launcher

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GridTest {
    private val sq = Orient.square
    private val roam = Grid.template(sq, Template.roam)

    private fun cells(o: Orient, layout: List<Sticker>): List<Pair<Int, Int>> = layout.filter { !it.hidden }.flatMap { st ->
        val z = Grid.sizeOf(st, o)
        (0 until z.w).flatMap { dc -> (0 until z.h).map { dr -> (st.c + dc) to (st.r + dr) } }
    }

    @Test fun quietTemplateUsesVerticalClockInBothOrientations() {
        for (orientation in Orient.entries) {
            val clock = Grid.template(orientation, Template.quiet).first { it.id == "clock" }
            val size = Grid.sizeOf(clock, orientation)
            assertEquals(1 to 2, size.w to size.h)
        }
    }

    @Test fun templatesFitWithoutOverlap() {
        for (o in Orient.entries) for (t in Template.entries) {
            val layout = Grid.template(o, t)
            val c = cells(o, layout)
            assertEquals("$o $t", c.size, c.toSet().size)
            val g = Grid.spec(o)
            assertTrue(c.all { (x, y) -> x in 0 until g.cols && y in 0 until g.rows })
        }
    }

    @Test fun orientationThreshold() {
        assertEquals(Orient.square, Grid.orientFor(480f, 480f))
        assertEquals(Orient.square, Grid.orientFor(600f, 480f))
        assertEquals(Orient.land, Grid.orientFor(640f, 360f))
    }

    @Test fun moveToFreeCell() {
        val moved = Grid.move(sq, roam, "tito", 0, 2)
        assertNotNull(moved)
        assertEquals(0 to 2, moved!!.first { it.id == "tito" }.let { it.c to it.r })
    }

    @Test fun moveSwapsOneForOne() {
        // clock 2x1 at (0,0) and trainer 2x1 at (2,0) trade places.
        val moved = Grid.move(sq, roam, "clock", 2, 0)!!
        assertEquals(2 to 0, moved.first { it.id == "clock" }.let { it.c to it.r })
        assertEquals(0 to 0, moved.first { it.id == "trainer" }.let { it.c to it.r })
    }

    @Test fun moveRejectsOutOfBoundsAndMultiOverlap() {
        assertNull(Grid.move(sq, roam, "shelf", 2, 3))
        val large = Grid.options(sq, "clock").first { it.key == "l" }
        assertEquals(2 to 1, large.w to large.h)
        // a 4x2 shelf dropped on the origin covers the clock and the trainer card
        val grown = Grid.resize(sq, roam, "shelf", Grid.options(sq, "shelf").first { it.key == "c" })!!
        assertNull(Grid.move(sq, grown, "shelf", 0, 0))
    }

    @Test fun resizeInPlaceOrRelocates() {
        val l = Grid.options(sq, "clock").first { it.key == "l" }
        val grown = Grid.resize(sq, roam, "clock", l)!!
        assertEquals("l", grown.first { it.id == "clock" }.size)
        val c = cells(sq, grown)
        assertEquals(c.size, c.toSet().size)
        val big = Grid.options(sq, "shelf").first { it.key == "c" }
        val shelf = Grid.resize(sq, roam, "shelf", big)!!.first { it.id == "shelf" }
        assertEquals("c", shelf.size)
        assertTrue(Grid.inBounds(sq, shelf.c, shelf.r, 4, 2))
    }

    @Test fun showPicksSmallerFormWhenNeeded() {
        val quiet = Grid.template(sq, Template.quiet)
        val shown = Grid.show(sq, quiet, "trainer")!!
        val t = shown.first { it.id == "trainer" }
        assertFalse(t.hidden)
        val c = cells(sq, shown)
        assertEquals(c.size, c.toSet().size)
    }

    @Test fun widgetsParseSpanAndRespectMinimum() {
        val w = Sticker.widget(42, 0, 1, 3, 2)
        assertEquals(42, w.widgetId)
        assertTrue(w.isWidget)
        assertEquals(3 to 2, Grid.sizeOf(w, sq).let { it.w to it.h })
        val opts = Grid.widgetOptions(sq, 2, 2)
        assertTrue(opts.all { it.w >= 2 && it.h >= 2 })
        assertTrue(opts.isNotEmpty())
        val tooBig = Grid.widgetOptions(Orient.land, 9, 9)
        assertEquals(listOf("6x3"), tooBig.map { it.key })
    }

    @Test fun addWidgetFindsSpaceOrHides() {
        val added = Grid.addWidget(sq, roam, 7, 2, 2)
        val w = added.first { it.widgetId == 7 }
        assertFalse(w.hidden)
        val c = cells(sq, added)
        assertEquals(c.size, c.toSet().size)
        val full = Grid.addWidget(sq, added, 8, 4, 3)
        assertTrue(full.first { it.widgetId == 8 }.hidden)
    }

    @Test fun sanitizeDedupesAndRestoresBuiltIns() {
        val messy = listOf(
            Sticker("clock", 0, 0, "s"), Sticker("clock", 2, 2, "l"), Sticker("tito", 0, 0, "s", hidden = true),
            Sticker("widget:3", 0, 0, "2x2"), Sticker("weird", 0, 0, "s"),
        )
        val fixed = Grid.sanitize(sq, messy)
        assertEquals(listOf("clock", "tito", "widget:3", "trainer", "shelf"), fixed.map { it.id })
        assertFalse(fixed.first { it.id == "tito" }.hidden)
        assertTrue(fixed.first { it.id == "trainer" }.hidden)
        val c = cells(sq, fixed)
        assertEquals(c.size, c.toSet().size)
    }
}
