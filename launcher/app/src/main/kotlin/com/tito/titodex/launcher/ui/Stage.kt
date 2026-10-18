package com.tito.titodex.launcher.ui

import androidx.compose.animation.core.animateDecay
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.AwaitPointerEventScope
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import com.tito.titodex.launcher.EditTab
import com.tito.titodex.launcher.Grid
import com.tito.titodex.launcher.IconDrag
import com.tito.titodex.launcher.LauncherState
import com.tito.titodex.launcher.Mode
import com.tito.titodex.launcher.Orient
import com.tito.titodex.launcher.Pop
import com.tito.titodex.launcher.Settings
import com.tito.titodex.launcher.Sticker
import com.tito.titodex.launcher.shelfItems
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.roundToInt

private data class StickerDrag(val id: String, val left: Float, val top: Float, val c: Int, val r: Int, val ok: Boolean)

private enum class Outcome { Up, Move, Long, Cancel }

/**
 * The home screen: wallpaper plus stickers on a snap grid. [live] is the real, interactive stage; previews in the
 * appearance panel render the same tree with [live] = false.
 */
@Composable
fun Stage(
    state: LauncherState, s: Settings, o: Orient, wDp: Float, hDp: Float, live: Boolean, editLayout: Boolean,
    photo: ImageBitmap?, now: Calendar, modifier: Modifier = Modifier,
) {
    val look = lookOf(s)
    val density = LocalDensity.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val g = Grid.spec(o)
    val cw = (wDp - Grid.PAD * 2) / g.cols
    val ch = (hDp - Grid.TOP - Grid.BOTTOM) / g.rows
    val layout = s.layout(o)
    var drag by remember { mutableStateOf<StickerDrag?>(null) }
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val motion = LocalLauncherMotion.current.copy(enabled = LocalLauncherMotion.current.enabled && s.motion && live)
    val currentMotion by rememberUpdatedState(motion)
    var shelfFling by remember { mutableStateOf<Job?>(null) }
    LaunchedEffect(motion.enabled) { if (!motion.enabled) shelfFling?.cancel() }
    val entry = revealProgress(editLayout, motion)
    // Paper settles once on entering edit, with no idle ticker.
    val wobble = if (editLayout && look.journal && motion.enabled) (1f - entry) * .7f else 0f
    val drawnRects = remember(o, wDp, hDp) { mutableMapOf<String, Rect>() }

    fun stickerRect(st: Sticker): Rect {
        drawnRects[st.id]?.let { return it }
        val z = Grid.sizeOf(st, o)
        return Rect(Grid.PAD + st.c * cw, Grid.TOP + st.r * ch, Grid.PAD + (st.c + z.w) * cw, Grid.TOP + (st.r + z.h) * ch)
    }
    fun stickerAt(px: Offset): Sticker? {
        val p = px / density.density
        return state.layout().filter { !it.hidden }.lastOrNull { stickerRect(it).contains(p) }
    }
    fun rootOf(local: Offset): Offset = coords?.takeIf { it.isAttached }?.localToRoot(local) ?: local
    fun hitKey(root: Offset): String? {
        val keys = state.rects.entries.filter { (k, r) -> (k.startsWith("shelf:") || k == "wx" || k == "handle") && r.contains(root) }
        return keys.firstOrNull { it.key.startsWith("shelf:") || it.key == "wx" }?.key ?: keys.firstOrNull()?.key
    }

    suspend fun AwaitPointerEventScope.waitOutcome(down: PointerInputChange, timeout: Long?): Pair<Outcome, PointerInputChange> {
        var last = down
        val slop = viewConfiguration.touchSlop
        val track: suspend AwaitPointerEventScope.() -> Outcome = {
            var result: Outcome? = null
            while (result == null) {
                val c = awaitPointerEvent().changes.firstOrNull { it.id == down.id }
                if (c == null) result = Outcome.Cancel
                else {
                    last = c
                    if (!c.pressed) result = Outcome.Up
                    else if ((c.position - down.position).getDistance() > slop) result = Outcome.Move
                }
            }
            result
        }
        val outcome = if (timeout == null) track() else withTimeoutOrNull(timeout) { track() } ?: Outcome.Long
        return outcome to last
    }

    suspend fun AwaitPointerEventScope.follow(id: androidx.compose.ui.input.pointer.PointerId, each: (PointerInputChange) -> Unit): PointerInputChange? {
        while (true) {
            val c = awaitPointerEvent().changes.firstOrNull { it.id == id } ?: return null
            c.consume()
            if (!c.pressed) return c
            each(c)
        }
    }

    suspend fun AwaitPointerEventScope.dragSticker(id: String, downPos: Offset, pointer: androidx.compose.ui.input.pointer.PointerId) {
        val st = state.layout().firstOrNull { it.id == id } ?: return
        val r = stickerRect(st)
        val grab = downPos / density.density - Offset(r.left, r.top)
        state.selected = id
        val z = Grid.sizeOf(st, o)
        fun update(p: Offset) {
            val pd = p / density.density
            val left = pd.x - grab.x
            val top = pd.y - grab.y
            val c = ((left - Grid.PAD) / cw).roundToInt().coerceIn(0, g.cols - z.w)
            val rr = ((top - Grid.TOP) / ch).roundToInt().coerceIn(0, g.rows - z.h)
            val cur = state.layout().firstOrNull { it.id == id } ?: return
            drag = StickerDrag(id, left, top, c, rr, Grid.tryPlace(o, state.layout(), cur, c, rr).ok)
        }
        update(downPos)
        try {
            val end = follow(pointer) { update(it.position) }
            val d = drag
            if (end != null && d != null && state.mode == Mode.Edit) state.moveSticker(id, d.c, d.r)
        } finally { drag = null }
    }

    val gestures = if (!live) Modifier else Modifier.pointerInput(o, wDp, hDp, state.homeFocusRequest) {
        try {
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false)
            shelfFling?.cancel()
            if (state.pop != null || state.settingsOpen) return@awaitEachGesture
            when (state.mode) {
                Mode.Library -> return@awaitEachGesture
                Mode.Edit -> {
                    if (state.tab != EditTab.layout) {
                        val (out, _) = waitOutcome(down, null)
                        if (out == Outcome.Up) state.select(null)
                        return@awaitEachGesture
                    }
                    val p = down.position / density.density
                    val badge = state.layout().filter { !it.hidden && it.id != "tito" }.lastOrNull {
                        val r = stickerRect(it)
                        Rect(r.left - 12, r.top - 12, r.left + 34, r.top + 34).contains(p)
                    }
                    val st = stickerAt(down.position)
                    val (out, _) = waitOutcome(down, null)
                    when (out) {
                        Outcome.Up -> when {
                            badge != null -> state.hide(badge.id)
                            st != null -> state.select(if (state.selected == st.id) null else st.id)
                            else -> state.select(null)
                        }
                        Outcome.Move -> if (st != null) dragSticker(st.id, down.position, down.id)
                        else -> {}
                    }
                }
                Mode.Home -> {
                    val root = rootOf(down.position)
                    val key = hitKey(root)
                    val st = stickerAt(down.position)
                    if (st?.isWidget == true) return@awaitEachGesture
                    val (out, last) = waitOutcome(down, viewConfiguration.longPressTimeoutMillis)
                    when (out) {
                        Outcome.Up -> when {
                            key == "handle" || key == "shelf:all" -> state.openLibrary()
                            key == "shelf:pick" -> state.openLibrary(pick = true)
                            key == "wx" -> if (state.settings.city == null) state.cityDialog = true else state.pop = Pop.Weather(state.rects["wx"] ?: Rect.Zero)
                            key != null && key.startsWith("shelf:") -> state.apps.firstOrNull { it.id == key.removePrefix("shelf:") }?.let { state.launch(it) }
                            st?.id == "tito" -> state.launchTitoDex()
                            st?.id == "trainer" -> state.pop = Pop.Trainer(state.rects["trainer"] ?: Rect.Zero)
                            else -> {}
                        }
                        Outcome.Move -> {
                            val delta = last.position - down.position
                            val shelfBox = state.rects["shelfbox"]
                            if (abs(delta.y) > abs(delta.x) && delta.y < 0) {
                                val sheetH = (hDp - 30f) * density.density
                                val tracker = VelocityTracker()
                                state.sheetPull = (sheetH + delta.y).coerceIn(0f, sheetH)
                                val end = follow(down.id) {
                                    tracker.addPosition(it.uptimeMillis, it.position)
                                    state.sheetPull = (sheetH + it.position.y - down.position.y).coerceIn(0f, sheetH)
                                }
                                val pulled = sheetH - (state.sheetPull ?: sheetH)
                                val vy = tracker.calculateVelocity().y
                                if (end != null && (pulled > sheetH * .22f || vy < -800f)) state.openLibrary()
                                state.sheetPull = null
                            } else if (abs(delta.x) > abs(delta.y) && shelfBox != null && shelfBox.contains(root)) {
                                val start = state.shelfScroll + (last.position.x - down.position.x)
                                val tracker = VelocityTracker()
                                follow(down.id) {
                                    tracker.addPosition(it.uptimeMillis, it.position)
                                    state.shelfScroll = (start - (it.position.x - down.position.x)).coerceIn(0f, state.shelfMax)
                                }
                                val v = -tracker.calculateVelocity().x
                                if (currentMotion.enabled) shelfFling = scope.launch {
                                    animateDecay(state.shelfScroll, v, androidx.compose.animation.core.FloatExponentialDecaySpec()) { value, _ -> state.shelfScroll = value.coerceIn(0f, state.shelfMax) }
                                }
                            } else follow(down.id) {}
                        }
                        Outcome.Long -> {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            val app = key?.takeIf { it.startsWith("shelf:") }?.let { k -> state.apps.firstOrNull { it.id == k.removePrefix("shelf:") } }
                            when {
                                app != null -> {
                                    state.pop = Pop.AppMenu(app, true, state.rects[key] ?: Rect.Zero)
                                    val slop = 10 * density.density
                                    var dragging = false
                                    val end = follow(down.id) { c ->
                                        if (!dragging && (c.position - down.position).getDistance() > slop) { dragging = true; state.pop = null }
                                        if (dragging) {
                                            val rp = rootOf(c.position)
                                            val over = rp.y < 46 * density.density
                                            state.iconDrag = IconDrag(app, rp, true, if (over) null else state.shelfInsertAt(rp, density.density), over)
                                        }
                                    }
                                    val d = state.iconDrag
                                    state.iconDrag = null
                                    if (end != null && d != null) {
                                        when {
                                            d.overRemove -> state.unpin(app)
                                            d.insert != null -> state.dropOnShelf(app, d.insert)
                                        }
                                    }
                                }
                                key == "handle" -> follow(down.id) {}
                                st != null -> {
                                    state.enterEdit(EditTab.layout, st.id)
                                    dragSticker(st.id, down.position, down.id)
                                }
                                else -> { state.enterEdit(); follow(down.id) {} }
                            }
                        }
                        Outcome.Cancel -> {}
                    }
                }
            }
        }
        } finally { drag = null; state.sheetPull = null; shelfFling?.cancel() }
    }

    CompositionLocalProvider(LocalLook provides look) {
        Box(
            modifier.size(wDp.dp, hDp.dp).clipToBounds().onGloballyPositioned { if (live) coords = it }.then(gestures),
        ) {
            Wallpaper(s.theme, s.wallpaper, s.effect, photo, Modifier.fillMaxSize())
            StatusBar(state, look.bgInk)
            if (editLayout) {
                for (r in 0 until g.rows) for (c in 0 until g.cols) {
                    Box(
                        Modifier.offset((Grid.PAD + c * cw + 5).dp, (Grid.TOP + r * ch + 5).dp).size((cw - 10).dp, (ch - 10).dp)
                            .background(Color.White.copy(alpha = .07f), RoundedCornerShape(14.dp))
                            .drawBehind { drawRoundRect(Color.White.copy(alpha = .55f), cornerRadius = CornerRadius(14.dp.toPx()), style = Stroke(1.2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f)))) },
                    )
                }
            }
            val items = shelfItems(s, state.apps)
            val hour = now.get(Calendar.HOUR_OF_DAY)
            for (st in layout) {
                if (st.hidden) continue
                key(st.id) {
                val z = Grid.sizeOf(st, o)
                val d = drag?.takeIf { it.id == st.id }
                val left = dragMotionFloat(Grid.PAD + st.c * cw, d?.left, motion)
                val top = dragMotionFloat(Grid.TOP + st.r * ch, d?.top, motion)
                SideEffect { drawnRects[st.id] = Rect(left, top, left + z.w * cw, top + z.h * ch) }
                val lift = motionFloat(if (d != null && motion.enabled) 1.035f else if (editLayout && look.plastic) .985f else 1f, motion)
                val selected = editLayout && state.selected == st.id
                val holding = editLayout && state.holding == st.id
                Box(
                    Modifier.offset { IntOffset(left.dp.roundToPx(), top.dp.roundToPx()) }.size((z.w * cw).dp, (z.h * ch).dp)
                        .then(if (editLayout && live) Modifier.padTarget(state, "st:${st.id}", state.stickerLabel(st), 20f) { state.padActivateSticker(st.id) } else Modifier)
                        .padding(5.dp),
                ) {
                    Box(
                        Modifier.fillMaxSize().graphicsLayer {
                            scaleX = lift; scaleY = lift
                            when {
                                d != null -> { rotationZ = if (look.flat || !motion.enabled) 0f else .7f; shadowElevation = 14.dp.toPx() }
                                editLayout -> rotationZ = if ((st.c + st.r) % 2 == 0) wobble else -wobble
                            }
                        },
                    ) {
                        val active = live && !editLayout
                        when {
                            st.id == "clock" -> ClockSticker(state, s, st.size, now, state.weather, active)
                            st.id == "trainer" -> TrainerSticker(state, s, st.size, hour, active)
                            st.id == "tito" -> TitoSticker(state, st.size, active)
                            st.id == "shelf" -> ShelfSticker(state, items, if (z.h >= 2) "c" else st.size, active)
                            st.widgetId != null -> WidgetSticker(state, st.widgetId!!, live, state.stickerLabel(st))
                        }
                        if (editLayout) Box(Modifier.fillMaxSize().pointerInput(Unit) {}.drawBehind {
                            val r = CornerRadius(20.dp.toPx())
                            if (selected || holding) drawRoundRect(Coral, cornerRadius = r, style = Stroke(if (holding) 3.dp.toPx() else 2.6.dp.toPx()))
                            else drawRoundRect(Color(0x8c2f4361), cornerRadius = r, style = Stroke(1.6.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(7f, 5f))))
                        })
                    }
                    if (editLayout) {
                        if (st.id == "tito") Text("固定", style = text(10.sp, FontWeight.ExtraBold, Cream), modifier = Modifier.offset((-3).dp, (-5).dp).background(Navy, RoundedCornerShape(9.dp)).padding(horizontal = 7.dp, vertical = 2.dp))
                        else Box(Modifier.offset((-8).dp, (-8).dp).size(28.dp).background(Danger, CircleShape).border(2.5.dp, Color.White, CircleShape), contentAlignment = Alignment.Center) {
                            Text("−", style = text(18.sp, FontWeight.ExtraBold, Color.White))
                        }
                    }
                }
                }
            }
            drag?.let { d ->
                val st = layout.firstOrNull { it.id == d.id }
                if (st != null) {
                    val z = Grid.sizeOf(st, o)
                    val color = if (d.ok) Color(0xff7ec8a8) else Danger
                    Box(
                        Modifier.offset((Grid.PAD + d.c * cw + 5).dp, (Grid.TOP + d.r * ch + 5).dp).size((z.w * cw - 10).dp, (z.h * ch - 10).dp)
                            .background(color.copy(alpha = if (d.ok) .2f else .14f), RoundedCornerShape(18.dp)).border(2.6.dp, color, RoundedCornerShape(18.dp)),
                    )
                }
            }
            if (!editLayout) Handle(state, live, Modifier.align(Alignment.BottomCenter))
        }
    }
}

@Composable
private fun StatusBar(state: LauncherState, ink: Color) {
    val st = state.status
    Row(
        Modifier.fillMaxWidth().height(24.dp).padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(7.dp, Alignment.End),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Canvas(Modifier.size(13.dp)) {
            val w = size.width
            val stroke = Stroke(w * .2f, cap = StrokeCap.Round)
            val a = if (st.online) 1f else .35f
            for ((i, rr) in listOf(.95f, .65f, .35f).withIndex()) {
                drawArc(ink.copy(alpha = a), 225f, 90f, false, Offset(w / 2 - w * rr / 1.1f, w * .85f - w * rr / 1.1f), Size(w * rr * 2 / 1.1f, w * rr * 2 / 1.1f), style = stroke)
                if (i == 2) drawCircle(ink.copy(alpha = a), w * .1f, Offset(w / 2, w * .85f))
            }
        }
        if (st.battery >= 0) {
            Text("${if (st.charging) "充电 · " else ""}${st.battery}%", style = text(11.sp, FontWeight.ExtraBold, ink))
            Canvas(Modifier.size(22.dp, 10.dp)) {
                val bw = size.width - 3.dp.toPx()
                drawRoundRect(ink, Offset.Zero, Size(bw, size.height), CornerRadius(3.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                val inset = 2.5.dp.toPx()
                drawRoundRect(ink, Offset(inset, inset), Size((bw - inset * 2) * st.battery / 100f, size.height - inset * 2), CornerRadius(1.dp.toPx()))
                drawRoundRect(ink, Offset(bw + 1.dp.toPx(), size.height * .3f), Size(2.dp.toPx(), size.height * .4f), CornerRadius(1.dp.toPx()))
            }
        }
    }
}

@Composable
private fun Handle(state: LauncherState, live: Boolean, modifier: Modifier) {
    val look = LocalLook.current
    val shape = if (look.journal) RoundedCornerShape(11.dp, 11.dp, 0.dp, 0.dp) else RoundedCornerShape(15.dp)
    val (bg, fg) = when {
        look.journal -> Paper.copy(alpha = .94f) to JournalInk
        look.plastic -> Color.White.copy(alpha = .42f) to look.bgInk
        else -> Navy to Cream
    }
    Box(modifier.width(140.dp).height(30.dp).then(if (live) Modifier.padTarget(state, "handle", "应用库", 14f) { state.openLibrary() } else Modifier), contentAlignment = Alignment.BottomCenter) {
        Row(
            Modifier.padding(bottom = if (look.journal) 0.dp else 5.dp).background(bg, shape)
                .then(if (look.journal) Modifier.border(1.25.dp, JournalLine, shape) else if (look.plastic) Modifier.border(1.dp, Color.White.copy(alpha = .7f), shape) else Modifier)
                .padding(horizontal = 16.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Canvas(Modifier.size(10.dp, 6.dp)) {
                drawLine(fg, Offset(0f, size.height), Offset(size.width / 2, 0f), 2.dp.toPx(), StrokeCap.Round)
                drawLine(fg, Offset(size.width / 2, 0f), Offset(size.width, size.height), 2.dp.toPx(), StrokeCap.Round)
            }
            Spacer(Modifier.width(5.dp))
            Text("应用库", style = text(12.sp, FontWeight.ExtraBold, fg))
        }
    }
}
