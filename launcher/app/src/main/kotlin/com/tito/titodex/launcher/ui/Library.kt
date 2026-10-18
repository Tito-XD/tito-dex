package com.tito.titodex.launcher.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.AwaitPointerEventScope
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tito.titodex.launcher.AppEntry
import com.tito.titodex.launcher.IconDrag
import com.tito.titodex.launcher.LauncherState
import com.tito.titodex.launcher.MAX_PINNED
import com.tito.titodex.launcher.Mode
import com.tito.titodex.launcher.Orient
import com.tito.titodex.launcher.Pop
import com.tito.titodex.launcher.filterApps
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private sealed interface LibRow {
    data class Header(val text: String) : LibRow
    data class App(val app: AppEntry, val key: String, val letter: String?, val star: Boolean) : LibRow
}

/** Waits for tap, move beyond slop, or (with [timeout]) a long press. */
internal suspend fun AwaitPointerEventScope.gestureOutcome(down: PointerInputChange, timeout: Long?): String {
    val slop = viewConfiguration.touchSlop
    val track: suspend AwaitPointerEventScope.() -> String = {
        var result: String? = null
        while (result == null) {
            val c = awaitPointerEvent().changes.firstOrNull { it.id == down.id }
            result = when {
                c == null -> "cancel"
                !c.pressed -> "up"
                (c.position - down.position).getDistance() > slop -> "move"
                else -> null
            }
        }
        result
    }
    return if (timeout == null) track() else withTimeoutOrNull(timeout) { track() } ?: "long"
}

@Composable
fun LibrarySheet(state: LauncherState, wDp: Float, hDp: Float) {
    val look = LocalLook.current
    val density = LocalDensity.current
    val sheetH = with(density) { (hDp - 30f).dp.toPx() }
    val motion = LocalLauncherMotion.current
    val open = state.mode == Mode.Library
    // Normalized travel survives size changes; direct pixel input remains exactly 1:1.
    val fraction = dragMotionFloat(if (open) 0f else 1f, state.sheetPull?.div(sheetH), motion, exiting = !open)
    val offset = fraction.coerceIn(-.012f, 1f) * sheetH
    val currentOffset by rememberUpdatedState(offset)
    val exitPicture = rememberGraphicsLayer()
    val dragFromLib = state.iconDrag?.fromShelf == false
    if (offset >= sheetH && !open && state.sheetPull == null && !dragFromLib) return

    val scrimAlpha = (1f - offset / sheetH).coerceIn(0f, 1f)
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().background(Color(0xff08101c).copy(alpha = .38f * scrimAlpha))
                .then(if (open && !dragFromLib) Modifier.pointerInput(Unit) { detectTapGestures { state.closeLibrary() } } else Modifier),
        )
        val shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp)
        val bg = when {
            look.journal -> Modifier.background(Paper, shape).border(1.25.dp, JournalLine, shape)
            look.plastic -> Modifier.background(Brush.verticalGradient(listOf(Color(0xf2f0f8fa), Color(0xf0dceaf0))), shape).border(1.1.dp, Color.White.copy(alpha = .85f), shape)
            else -> Modifier.background(FlatPaper, shape)
        }
        val sheetModifier = Modifier.offset { IntOffset(0, (30.dp.toPx() + offset).roundToInt()) }
            .fillMaxWidth().height((hDp - 30f).dp)
        if (!open && state.sheetPull == null && !dragFromLib) {
            // A drawing-only exit has no stale focus nodes, semantics or touch targets.
            Box(sheetModifier.drawWithContent { drawLayer(exitPicture) })
            return@Box
        }
        CompositionLocalProvider(LocalMotionControls provides (open && !dragFromLib)) {
        Column(
            sheetModifier.testTag("library-sheet").drawWithContent {
                exitPicture.record { this@drawWithContent.drawContent() }
                drawLayer(exitPicture)
            }.clip(shape).then(bg),
        ) {
            val dragHeader = Modifier.pointerInput(sheetH) {
                val velocity = VelocityTracker()
                detectVerticalDragGestures(
                    onDragStart = { velocity.resetTracking(); state.sheetPull = currentOffset.coerceAtLeast(0f) },
                    onVerticalDrag = { change, dy ->
                        change.consume()
                        // Track in the stationary root, not the moving header's local space.
                        velocity.addPosition(change.uptimeMillis, change.position + Offset(0f, currentOffset))
                        state.sheetPull = ((state.sheetPull ?: 0f) + dy).coerceAtLeast(0f)
                    },
                    onDragEnd = {
                        val p = state.sheetPull ?: 0f
                        if (p > sheetH * .25f || velocity.calculateVelocity().y > 1200f) state.closeLibrary()
                        state.sheetPull = null
                    },
                    onDragCancel = { state.sheetPull = null },
                )
            }
            Box(dragHeader.fillMaxWidth().height(20.dp).pointerInput(Unit) { detectTapGestures { state.closeLibrary() } }, contentAlignment = Alignment.Center) {
                Box(Modifier.size(42.dp, 5.dp).background(Navy.copy(alpha = .3f), RoundedCornerShape(3.dp)))
            }
            Header(state, dragHeader)
            SearchField(state)
            LibraryGrid(state, sheetH, wDp, currentOffset, (1f - fraction).coerceIn(0f, 1f))
        }
        }
    }
}

@Composable
private fun Header(state: LauncherState, drag: Modifier) {
    val look = LocalLook.current
    Row(drag.fillMaxWidth().padding(start = 16.dp, end = 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        if (state.picker) {
            Text("挑选常玩", style = text(19.sp, FontWeight.ExtraBold, look.sheetInk))
            Text("已选 ${state.settings.pinned.size}/$MAX_PINNED", style = text(12.sp, color = look.sheetInk.copy(alpha = .6f)), modifier = Modifier.weight(1f))
            Chip(state, "l:pickdone", "完成", primary = true) { state.closeLibrary() }
        } else {
            Text("应用库", style = text(19.sp, FontWeight.ExtraBold, look.sheetInk))
            Text("${state.apps.size} 个", style = text(12.sp, color = look.sheetInk.copy(alpha = .6f)), modifier = Modifier.weight(1f))
            Chip(state, "l:pick", "挑选常玩", tinted = true) { state.openLibrary(pick = true) }
            Chip(state, "l:settings", "⚙", tinted = true, label = "设置") { state.openSettings() }
        }
    }
}

@Composable
private fun SearchField(state: LauncherState) {
    val look = LocalLook.current
    val focus = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(state.searchFocusRequest, state.mode) {
        if (state.searchFocusRequest > 0 && state.mode == Mode.Library) {
            // Focus is available as soon as the field is composed, even during arrival.
            runCatching { focus.requestFocus() }
            keyboard?.show()
        }
    }
    Box(Modifier.fillMaxWidth().padding(start = 14.dp, end = 14.dp, bottom = 6.dp)) {
        BasicTextField(
            value = state.query,
            onValueChange = { state.query = it },
            singleLine = true,
            enabled = LocalMotionControls.current,
            textStyle = text(14.sp, FontWeight.Normal, look.sheetInk),
            cursorBrush = SolidColor(Coral),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
            keyboardActions = KeyboardActions(onGo = { filterApps(state.apps, state.query).firstOrNull()?.let { state.launch(it) } }),
            modifier = Modifier.fillMaxWidth().height(38.dp).focusRequester(focus)
                .background(Color.White.copy(alpha = .7f), RoundedCornerShape(12.dp))
                .border(1.25.dp, Navy.copy(alpha = .3f), RoundedCornerShape(12.dp)),
            decorationBox = { inner ->
                Row(Modifier.fillMaxSize().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Canvas(Modifier.size(16.dp)) {
                        val c = look.sheetInk.copy(alpha = .5f)
                        drawCircle(c, size.width * .34f, Offset(size.width * .45f, size.height * .45f), style = Stroke(2.4.dp.toPx()))
                        drawLine(c, Offset(size.width * .72f, size.height * .72f), Offset(size.width * .95f, size.height * .95f), 2.4.dp.toPx(), StrokeCap.Round)
                    }
                    Spacer(Modifier.width(8.dp))
                    Box(Modifier.weight(1f)) {
                        if (state.query.isEmpty()) Text("搜索应用或包名", style = text(14.sp, FontWeight.Normal, look.sheetInk.copy(alpha = .45f)))
                        inner()
                    }
                }
            },
        )
    }
}

@Composable
private fun LibraryGrid(state: LauncherState, sheetH: Float, wDp: Float, sheetOffset: Float, arrival: Float) {
    val look = LocalLook.current
    val density = LocalDensity.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val grid = rememberLazyGridState()
    val currentOffset by rememberUpdatedState(sheetOffset)
    val cols = state.settings.libraryColumns + if (state.orient == Orient.land) 2 else 0
    val apps = state.apps
    val pinned = state.settings.pinned
    val q = state.query.trim()
    val rows: List<LibRow> = remember(apps, pinned, q, state.picker) {
        buildList {
            if (q.isNotEmpty()) {
                val res = filterApps(apps, q)
                if (res.isNotEmpty()) {
                    add(LibRow.Header("${res.size} 个结果 · Enter 打开第一个"))
                    res.forEach { add(LibRow.App(it, "lib:${it.id}", null, it.id in pinned && !state.picker)) }
                }
            } else {
                if (!state.picker && pinned.isNotEmpty()) {
                    add(LibRow.Header("常玩 · 长按可拖到桌面"))
                    pinned.mapNotNull { id -> apps.firstOrNull { it.id == id } }.forEach { add(LibRow.App(it, "libp:${it.id}", null, true)) }
                }
                add(LibRow.Header("全部 · A–Z"))
                apps.forEachIndexed { i, a ->
                    val letter = if (i == 0 || apps[i - 1].group != a.group) a.group else null
                    add(LibRow.App(a, "lib:${a.id}", letter, a.id in pinned && !state.picker))
                }
            }
        }
    }
    val groups = remember(apps) { apps.map { it.group }.distinct() }
    fun indexOfGroup(gr: String) = rows.indexOfFirst { it is LibRow.App && it.key.startsWith("lib:") && it.letter == gr }

    LaunchedEffect(state.libJumpRequest) {
        val (dir, _) = state.libJumpRequest ?: return@LaunchedEffect
        val starts = rows.mapIndexedNotNull { i, r -> if (r is LibRow.App && r.letter != null && r.key.startsWith("lib:")) i else null }
        if (starts.isEmpty()) return@LaunchedEffect
        val fi = rows.indexOfFirst { it is LibRow.App && it.key == state.focusKey }
        var gi = if (fi < 0) -1 else starts.count { it <= fi } - 1
        gi = if (dir > 0) (gi + 1).coerceAtMost(starts.size - 1) else (if (fi == starts.getOrNull(gi)) gi - 1 else gi).coerceAtLeast(0)
        val target = rows[starts[gi]] as LibRow.App
        grid.scrollToItem(starts[gi])
        delay(32)
        FocusTargets.request(target.key)
    }

    // Pull down at the top of the list keeps dragging the sheet; release decides.
    val connection = remember(sheetH) {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                val p = state.sheetPull ?: return Offset.Zero
                if (available.y < 0) {
                    val next = (p + available.y).coerceAtLeast(0f)
                    state.sheetPull = next
                    return Offset(0f, next - p)
                }
                return Offset.Zero
            }
            override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
                if (available.y > 0 && source == NestedScrollSource.UserInput) {
                    state.sheetPull = (state.sheetPull ?: currentOffset.coerceAtLeast(0f)) + available.y
                    return Offset(0f, available.y)
                }
                return Offset.Zero
            }
            override suspend fun onPreFling(available: Velocity): Velocity {
                val p = state.sheetPull ?: return Velocity.Zero
                if (p > sheetH * .25f || available.y > 1200f) state.closeLibrary()
                state.sheetPull = null
                return available
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        if (apps.isEmpty()) {
            Text(
                state.appsError ?: "正在读取应用…", style = text(13.sp, color = look.sheetInk.copy(alpha = .7f)),
                modifier = Modifier.align(Alignment.TopCenter).padding(30.dp).pointerInput(Unit) { detectTapGestures { state.refreshApps() } },
            )
        } else if (rows.isEmpty()) {
            Text("没有匹配的应用", style = text(13.sp, color = look.sheetInk.copy(alpha = .7f)), modifier = Modifier.align(Alignment.TopCenter).padding(30.dp))
        }
        LazyVerticalGrid(
            GridCells.Fixed(cols),
            state = grid,
            userScrollEnabled = LocalMotionControls.current,
            modifier = Modifier.fillMaxSize().nestedScroll(connection).padding(start = 10.dp, end = 28.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 18.dp),
        ) {
            itemsIndexed(rows, key = { _, r -> if (r is LibRow.App) r.key else "h:" + (r as LibRow.Header).text }, span = { _, r -> GridItemSpan(if (r is LibRow.Header) maxLineSpan else 1) }) { index, r ->
                when (r) {
                    is LibRow.Header -> Text(r.text, style = text(11.sp, FontWeight.ExtraBold, look.sheetInk.copy(alpha = .55f), .8.sp), modifier = Modifier.padding(start = 6.dp, top = 10.dp, bottom = 2.dp))
                    is LibRow.App -> LibIcon(state, r, haptics, density.density, arrival, index / cols)
                }
            }
        }
        if (q.isEmpty() && groups.size > 1) {
            var bubble by remember { mutableStateOf<Pair<String, Float>?>(null) }
            var railCoords by remember { mutableStateOf<LayoutCoordinates?>(null) }
            fun scrub(y: Float, h: Float) {
                val gi = ((y / h) * groups.size).toInt().coerceIn(0, groups.size - 1)
                val idx = indexOfGroup(groups[gi])
                if (idx >= 0) scope.launch { grid.scrollToItem(idx) }
                bubble = groups[gi] to y
            }
            Column(
                Modifier.align(Alignment.TopEnd).padding(top = 8.dp, bottom = 14.dp, end = 3.dp).width(22.dp).fillMaxHeight()
                    .onGloballyPositioned { railCoords = it }
                    .pointerInput(groups, rows) {
                        awaitEachGesture {
                            val down = awaitFirstDown()
                            down.consume()
                            scrub(down.position.y, size.height.toFloat())
                            while (true) {
                                val c = awaitPointerEvent().changes.firstOrNull { it.id == down.id } ?: break
                                c.consume()
                                if (!c.pressed) break
                                scrub(c.position.y, size.height.toFloat())
                            }
                            bubble = null
                        }
                    },
                verticalArrangement = Arrangement.SpaceAround, horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                groups.forEach { Text(it, style = text(9.5.sp, FontWeight.ExtraBold, look.sheetInk.copy(alpha = .75f))) }
            }
            bubble?.let { (letter, y) ->
                Box(
                    Modifier.align(Alignment.TopEnd).offset { IntOffset(-40.dp.roundToPx(), (y - 40.dp.toPx()).roundToInt().coerceAtLeast(0)) }
                        .size(54.dp).background(Navy, RoundedCornerShape(16.dp)),
                    contentAlignment = Alignment.Center,
                ) { Text(letter, style = text(26.sp, FontWeight.ExtraBold, Cream)) }
            }
        }
    }
}

@Composable
private fun LibIcon(state: LauncherState, r: LibRow.App, haptics: androidx.compose.ui.hapticfeedback.HapticFeedback, density: Float, arrival: Float, row: Int) {
    val look = LocalLook.current
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val app = r.app
    val motion = LocalLauncherMotion.current
    Box(
        Modifier.height(86.dp).fillMaxWidth()
            .onGloballyPositioned { coords = it }
            .padTarget(state, r.key, app.label, 16f) { if (state.picker) state.pickerToggle(app) else state.launch(app) }
            .pointerInput(app.id, state.picker) {
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    if (state.mode != Mode.Library) return@awaitEachGesture
                    when (gestureOutcome(down, if (state.picker) null else viewConfiguration.longPressTimeoutMillis)) {
                        "up" -> if (state.picker) state.pickerToggle(app) else state.launch(app)
                        "long" -> {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            state.pop = Pop.AppMenu(app, false, state.rects[r.key] ?: Rect.Zero)
                            var dragging = false
                            var aborted = false
                            while (true) {
                                val c = awaitPointerEvent().changes.firstOrNull { it.id == down.id } ?: break
                                c.consume()
                                if (!c.pressed) {
                                    val d = state.iconDrag
                                    state.iconDrag = null
                                    if (dragging && d != null) {
                                        if (d.insert != null) state.dropOnShelf(app, d.insert) else state.showToast("松手在常玩架上即可加入")
                                    }
                                    break
                                }
                                if (aborted) continue
                                if (!dragging && (c.position - down.position).getDistance() > 10 * density) {
                                    state.pop = null
                                    if (state.layout().firstOrNull { it.id == "shelf" }?.hidden != false) {
                                        state.showToast("常玩架已隐藏：先在「整理桌面」找回")
                                        aborted = true
                                        continue
                                    }
                                    dragging = true
                                    state.closeLibrary()
                                }
                                if (dragging) {
                                    val root = coords?.takeIf { it.isAttached }?.localToRoot(c.position) ?: continue
                                    state.iconDrag = IconDrag(app, root, false, state.shelfInsertAt(root, density))
                                }
                            }
                        }
                        else -> {}
                    }
                }
            },
    ) {
        IconTile(
            state.device.icon(app), app.label, look.sheetInk, Modifier.align(Alignment.Center).fillMaxWidth().drawWithContent {
                // Three short waves of paint only; all app targets exist from frame one.
                val lag = row.coerceIn(0, 2) * .07f
                val p = if (motion.enabled) ((arrival - lag) / (1f - lag)).coerceIn(0f, 1f) else 1f
                withTransform({
                    translate(top = (1f - p) * with(this@drawWithContent) { 4.dp.toPx() })
                    scale(.985f + .015f * p, .985f + .015f * p)
                }) { this@drawWithContent.drawContent() }
            }, width = 74, height = 86,
            letter = r.letter, star = r.star, check = if (state.picker) app.id in state.settings.pinned else null,
        )
    }
}

@Composable
fun Chip(
    state: LauncherState, key: String, text: String, modifier: Modifier = Modifier, on: Boolean = false, primary: Boolean = false, tinted: Boolean = false,
    warn: Boolean = false, dashed: Boolean = false, small: String? = null, label: String? = null, onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(17.dp)
    val bg = when {
        on || primary -> Navy
        tinted -> Navy.copy(alpha = .08f)
        else -> Paper.copy(alpha = .94f)
    }
    val fg = when { on || primary -> Cream; warn -> Color(0xffb03c3c); else -> Navy }
    Row(
        modifier.height(34.dp).padTarget(state, key, label ?: text, 17f, onClick)
            .clip(shape).background(bg)
            .then(if (!tinted && !on && !primary) Modifier.border(1.25.dp, Navy.copy(alpha = .22f), shape) else Modifier)
            .pointerInput(onClick) { detectTapGestures { onClick() } }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, style = text(12.5.sp, FontWeight.ExtraBold, fg), maxLines = 1)
        if (small != null) Text(" $small", style = text(10.sp, FontWeight.Bold, fg.copy(alpha = .6f)), maxLines = 1)
    }
}
