package com.tito.titodex.launcher

data class GridSpec(val cols: Int, val rows: Int)

data class SizeOption(val key: String, val w: Int, val h: Int, val label: String)

data class Spot(val c: Int, val r: Int)

data class Placement(val ok: Boolean, val swap: Sticker? = null)

/** Snap grid for both screen shapes. Stickers come in a few sizes, each with its own form. */
object Grid {
    const val PAD = 12f
    const val TOP = 24f
    const val BOTTOM = 30f

    val BUILT_IN = listOf("clock", "trainer", "tito", "shelf")

    val LABEL = mapOf("clock" to "时间天气", "trainer" to "Trainer Card", "tito" to "TitoDex", "shelf" to "常玩")

    fun spec(o: Orient) = if (o == Orient.square) GridSpec(4, 4) else GridSpec(6, 3)

    fun orientFor(widthDp: Float, heightDp: Float) = if (widthDp > heightDp * 1.25f) Orient.land else Orient.square

    private val SIZES: Map<Orient, Map<String, List<SizeOption>>> = mapOf(
        Orient.square to mapOf(
            "clock" to listOf(SizeOption("s", 2, 1, "紧凑"), SizeOption("l", 2, 1, "大字"), SizeOption("v", 1, 2, "竖排"), SizeOption("w", 4, 1, "横幅")),
            "trainer" to listOf(SizeOption("s", 1, 1, "徽章"), SizeOption("m", 2, 1, "名片"), SizeOption("l", 2, 2, "完整")),
            "tito" to listOf(SizeOption("s", 1, 1, "徽章"), SizeOption("m", 2, 1, "带标签")),
            "shelf" to listOf(SizeOption("a", 3, 1, "一排"), SizeOption("b", 4, 1, "整排"), SizeOption("c", 4, 2, "两排")),
        ),
        Orient.land to mapOf(
            "clock" to listOf(SizeOption("s", 2, 1, "紧凑"), SizeOption("l", 2, 1, "大字"), SizeOption("v", 1, 2, "竖排"), SizeOption("w", 3, 1, "横幅")),
            "trainer" to listOf(SizeOption("s", 1, 1, "徽章"), SizeOption("m", 2, 1, "名片"), SizeOption("l", 2, 2, "完整")),
            "tito" to listOf(SizeOption("s", 1, 1, "徽章"), SizeOption("m", 2, 1, "带标签")),
            "shelf" to listOf(SizeOption("a", 4, 1, "一排"), SizeOption("b", 5, 1, "整排"), SizeOption("c", 6, 2, "两排")),
        ),
    )

    private val TEMPLATES: Map<Orient, Map<Template, List<Sticker>>> = mapOf(
        Orient.square to mapOf(
            Template.roam to listOf(Sticker("clock", 0, 0, "s"), Sticker("trainer", 2, 0, "m"), Sticker("tito", 0, 3, "s"), Sticker("shelf", 1, 3, "a")),
            Template.panel to listOf(Sticker("clock", 0, 0, "w"), Sticker("trainer", 0, 1, "m"), Sticker("tito", 2, 1, "m"), Sticker("shelf", 0, 2, "c")),
            Template.quiet to listOf(Sticker("clock", 0, 0, "v"), Sticker("trainer", 2, 0, "s", true), Sticker("shelf", 0, 3, "a"), Sticker("tito", 3, 3, "s")),
        ),
        Orient.land to mapOf(
            Template.roam to listOf(Sticker("clock", 0, 0, "s"), Sticker("trainer", 4, 0, "m"), Sticker("tito", 0, 2, "s"), Sticker("shelf", 1, 2, "b")),
            Template.panel to listOf(Sticker("clock", 0, 0, "w"), Sticker("trainer", 3, 0, "m"), Sticker("tito", 5, 0, "s"), Sticker("shelf", 0, 1, "c")),
            Template.quiet to listOf(Sticker("clock", 0, 0, "v"), Sticker("trainer", 4, 0, "s", true), Sticker("shelf", 1, 2, "a"), Sticker("tito", 5, 2, "s")),
        ),
    )

    fun template(o: Orient, t: Template): List<Sticker> = TEMPLATES.getValue(o).getValue(t)

    /** Built-ins use named sizes; widgets store their span directly as "WxH". */
    fun options(o: Orient, id: String): List<SizeOption> = SIZES.getValue(o)[id] ?: emptyList()

    fun sizeOf(st: Sticker, o: Orient): SizeOption {
        if (st.isWidget) {
            val parts = st.size.split('x').mapNotNull { it.toIntOrNull() }
            val g = spec(o)
            val w = parts.getOrNull(0)?.coerceIn(1, g.cols) ?: 2
            val h = parts.getOrNull(1)?.coerceIn(1, g.rows) ?: 1
            return SizeOption(st.size, w, h, "${w}×$h")
        }
        val list = options(o, st.id)
        return list.firstOrNull { it.key == st.size } ?: list.first()
    }

    /** Widget span choices that satisfy the provider's minimum (resizable minimum when allowed). */
    fun widgetOptions(o: Orient, minW: Int, minH: Int): List<SizeOption> {
        val g = spec(o)
        val spans = if (o == Orient.square) listOf(1 to 1, 2 to 1, 2 to 2, 3 to 1, 3 to 2, 4 to 1, 4 to 2, 4 to 3)
        else listOf(1 to 1, 2 to 1, 2 to 2, 3 to 1, 3 to 2, 4 to 1, 4 to 2, 6 to 2)
        val fit = spans.filter { (w, h) -> w >= minW && h >= minH && w <= g.cols && h <= g.rows }
        val list = fit.ifEmpty { listOf(minW.coerceIn(1, g.cols) to minH.coerceIn(1, g.rows)) }
        return list.map { (w, h) -> SizeOption("${w}x$h", w, h, "${w}×$h") }
    }

    fun inBounds(o: Orient, c: Int, r: Int, w: Int, h: Int): Boolean {
        val g = spec(o)
        return c >= 0 && r >= 0 && c + w <= g.cols && r + h <= g.rows
    }

    private fun overlap(a: Int, b: Int, w: Int, h: Int, c: Int, d: Int, w2: Int, h2: Int) =
        a < c + w2 && c < a + w && b < d + h2 && d < b + h

    fun occupants(o: Orient, layout: List<Sticker>, id: String, c: Int, r: Int, w: Int, h: Int): List<Sticker> =
        layout.filter { other ->
            if (other.id == id || other.hidden) return@filter false
            val z = sizeOf(other, o)
            overlap(c, r, w, h, other.c, other.r, z.w, z.h)
        }

    /** Free spot, or a one-for-one swap when the other sticker fits where the dragged one came from. */
    fun tryPlace(o: Orient, layout: List<Sticker>, st: Sticker, c: Int, r: Int): Placement {
        val z = sizeOf(st, o)
        if (!inBounds(o, c, r, z.w, z.h)) return Placement(false)
        val occ = occupants(o, layout, st.id, c, r, z.w, z.h)
        if (occ.isEmpty()) return Placement(true)
        if (occ.size == 1) {
            val other = occ[0]
            val oz = sizeOf(other, o)
            val fitsBack = inBounds(o, st.c, st.r, oz.w, oz.h) &&
                !overlap(c, r, z.w, z.h, st.c, st.r, oz.w, oz.h) &&
                occupants(o, layout.filter { it.id != st.id }, other.id, st.c, st.r, oz.w, oz.h).isEmpty()
            if (fitsBack) return Placement(true, other)
        }
        return Placement(false)
    }

    fun move(o: Orient, layout: List<Sticker>, id: String, c: Int, r: Int): List<Sticker>? {
        val st = layout.firstOrNull { it.id == id } ?: return null
        val p = tryPlace(o, layout, st, c, r)
        if (!p.ok) return null
        return layout.map {
            when (it.id) {
                id -> it.copy(c = c, r = r)
                p.swap?.id -> it.copy(c = st.c, r = st.r)
                else -> it
            }
        }
    }

    fun findFree(o: Orient, layout: List<Sticker>, id: String, near: Spot, w: Int, h: Int): Spot? {
        val g = spec(o)
        var best: Spot? = null
        var bestDistance = Int.MAX_VALUE
        for (r in 0 until g.rows) for (c in 0 until g.cols) {
            if (!inBounds(o, c, r, w, h) || occupants(o, layout, id, c, r, w, h).isNotEmpty()) continue
            val d = kotlin.math.abs(c - near.c) + kotlin.math.abs(r - near.r)
            if (d < bestDistance) { bestDistance = d; best = Spot(c, r) }
        }
        return best
    }

    /** Resize in place when possible, otherwise move to the nearest spot that fits. */
    fun resize(o: Orient, layout: List<Sticker>, id: String, size: SizeOption): List<Sticker>? {
        val st = layout.firstOrNull { it.id == id } ?: return null
        val here = inBounds(o, st.c, st.r, size.w, size.h) && occupants(o, layout, id, st.c, st.r, size.w, size.h).isEmpty()
        val spot = if (here) Spot(st.c, st.r) else findFree(o, layout, id, Spot(st.c, st.r), size.w, size.h) ?: return null
        return layout.map { if (it.id == id) it.copy(size = size.key, c = spot.c, r = spot.r) else it }
    }

    /** Unhide a sticker, trying its current size first and then smaller forms. */
    fun show(o: Orient, layout: List<Sticker>, id: String): List<Sticker>? {
        val st = layout.firstOrNull { it.id == id } ?: return null
        val sizes = if (st.isWidget) listOf(sizeOf(st, o)) else options(o, id).sortedBy { if (it.key == st.size) 0 else 1 }
        for (z in sizes) {
            val spot = findFree(o, layout, id, Spot(st.c, st.r), z.w, z.h) ?: continue
            return layout.map { if (it.id == id) it.copy(hidden = false, size = z.key, c = spot.c, r = spot.r) else it }
        }
        return null
    }

    /** Places a new widget, falling back to a hidden entry the user can bring back after making room. */
    fun addWidget(o: Orient, layout: List<Sticker>, appWidgetId: Int, w: Int, h: Int): List<Sticker> {
        val g = spec(o)
        val ww = w.coerceIn(1, g.cols)
        val hh = h.coerceIn(1, g.rows)
        val spot = findFree(o, layout, "", Spot(0, 0), ww, hh)
        val st = Sticker.widget(appWidgetId, spot?.c ?: 0, spot?.r ?: 0, ww, hh).copy(hidden = spot == null)
        return layout + st
    }

    /**
     * Repairs persisted layouts: drops unknown or duplicate ids, adds missing built-ins from the default template,
     * keeps TitoDex visible, and hides anything that no longer fits.
     */
    fun sanitize(o: Orient, input: List<Sticker>): List<Sticker> {
        val seen = mutableSetOf<String>()
        val defaults = template(o, Template.roam)
        val kept = input.filter { st ->
            (st.id in BUILT_IN || st.isWidget) && seen.add(st.id)
        }.map { st ->
            val fixedSize = if (st.isWidget) st else st.copy(size = sizeOf(st, o).key)
            if (st.id == "tito") fixedSize.copy(hidden = false) else fixedSize
        }.toMutableList()
        for (d in defaults) if (kept.none { it.id == d.id }) kept.add(d.copy(hidden = d.id != "tito"))
        val placed = mutableListOf<Sticker>()
        for (st in kept.sortedBy { if (it.id == "tito") 0 else 1 }) {
            if (st.hidden) { placed.add(st); continue }
            val z = sizeOf(st, o)
            val ok = inBounds(o, st.c, st.r, z.w, z.h) && occupants(o, placed, st.id, st.c, st.r, z.w, z.h).isEmpty()
            if (ok) placed.add(st)
            else {
                val spot = findFree(o, placed, st.id, Spot(st.c, st.r), z.w, z.h)
                placed.add(if (spot != null) st.copy(c = spot.c, r = spot.r) else st.copy(hidden = st.id != "tito"))
            }
        }
        return kept.map { k -> placed.first { it.id == k.id } }
    }
}
