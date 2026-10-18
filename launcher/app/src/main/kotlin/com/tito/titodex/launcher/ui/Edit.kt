package com.tito.titodex.launcher.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tito.titodex.launcher.Effect
import com.tito.titodex.launcher.EditTab
import com.tito.titodex.launcher.Grid
import com.tito.titodex.launcher.Hints
import com.tito.titodex.launcher.LauncherState
import com.tito.titodex.launcher.LauncherTheme
import com.tito.titodex.launcher.Orient
import com.tito.titodex.launcher.Pop
import com.tito.titodex.launcher.Template
import com.tito.titodex.launcher.Wall
import java.util.Calendar

/** Where the shrunken stage sits in 整理桌面, so the real desktop stays the preview. */
data class StageFrame(val scale: Float, val x: Float, val y: Float)

fun stageFrame(editing: Boolean, tab: EditTab, o: Orient, w: Float, h: Float): StageFrame {
    if (!editing) return StageFrame(1f, 0f, 0f)
    return when {
        tab == EditTab.layout -> { val s = (h - 46 - 56) / h; StageFrame(s, (w - w * s) / 2, 46f) }
        o == Orient.square -> { val s = (h - 46 - 216) / h; StageFrame(s, (w - w * s) / 2, 46f) }
        else -> { val s = minOf((w - 300 - 24) / w, (h - 46 - 12) / h); StageFrame(s, 12f, 46 + ((h - 46 - 12) - h * s) / 2) }
    }
}

@Composable
fun EditChrome(state: LauncherState, wDp: Float, hDp: Float, photo: ImageBitmap?, now: Calendar) {
    val look = LocalLook.current
    val trayInk = when (look.theme) { LauncherTheme.journal -> JournalInk; LauncherTheme.plastic -> Color(0xffdfe9f2); LauncherTheme.flat -> FlatInk }
    Box(Modifier.fillMaxSize()) {
        Row(
            Modifier.padding(horizontal = 8.dp).padding(top = 6.dp).fillMaxWidth().height(34.dp).motionReveal("edit toolbar"),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            val canUndo = (state.session?.stack?.size ?: 0) > 0
            Box(Modifier.alpha(if (canUndo) 1f else .38f)) { Chip(state, "e:undo", "↶ 撤销", label = "撤销") { state.undo() } }
            Row(
                Modifier.weight(1f).height(34.dp).background(Paper.copy(alpha = .82f), RoundedCornerShape(12.dp)).padding(3.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterHorizontally),
            ) {
                for (t in EditTab.entries) {
                    val on = state.tab == t
                    Box(
                        Modifier.fillMaxHeight().padTarget(state, "e:tab:${t.name}", t.label, 9f) { state.tab = t; state.selected = null; state.holding = null }
                            .background(if (on) Navy else Color.Transparent, RoundedCornerShape(9.dp))
                            .pointerInput(t) { detectTapGestures { state.tab = t; state.selected = null; state.holding = null } }
                            .padding(horizontal = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) { Text(t.label, style = text(13.sp, FontWeight.ExtraBold, if (on) Cream else Navy)) }
                }
            }
            Chip(state, "e:done", "完成", primary = true) { state.finishEdit() }
        }
        when (state.tab) {
            EditTab.layout -> Tray(state, trayInk, Modifier.align(Alignment.BottomStart).padding(bottom = 6.dp).motionReveal(state.tab, order = 1))
            else -> {
                val land = state.orient == Orient.land
                val shape = if (land) RoundedCornerShape(topStart = 20.dp) else RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
                val bg = when (look.theme) {
                    LauncherTheme.journal -> Paper.copy(alpha = .97f)
                    LauncherTheme.plastic -> Color(0xf2ecf4f7)
                    LauncherTheme.flat -> FlatPaper
                }
                Column(
                    (if (land) Modifier.align(Alignment.TopEnd).padding(top = 46.dp).width(300.dp).fillMaxHeight()
                    else Modifier.align(Alignment.BottomStart).fillMaxWidth().height(212.dp))
                        .motionReveal(state.tab, order = 1).clip(shape).background(bg, shape)
                        .pointerInput(Unit) { detectTapGestures { } }
                        .verticalScroll(rememberScrollState())
                        .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 14.dp),
                ) {
                    if (state.tab == EditTab.look) LookPanel(state, wDp, hDp, photo, now) else WallPanel(state)
                }
            }
        }
    }
}

@Composable
private fun Sep() = Box(Modifier.width(1.dp).height(20.dp).background(Color(0x737f8ca0)))

@Composable
private fun Tray(state: LauncherState, ink: Color, modifier: Modifier) {
    val sel = state.selected?.let { id -> state.layout().firstOrNull { it.id == id } }
    Row(
        modifier.fillMaxWidth().height(46.dp).horizontalScroll(rememberScrollState()).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (sel != null) {
            for (z in state.sizeOptions(sel.id)) {
                Chip(state, "e:size:${z.key}", z.label, on = sel.size == z.key, small = if (sel.isWidget) null else "${z.w}×${z.h}") { state.resizeSelected(z) }
            }
            Sep()
            when (sel.id) {
                "shelf" -> {
                    Chip(state, "e:fill", "补最近", on = state.settings.fillRecent) { state.update { it.copy(fillRecent = !it.fillRecent) } }
                    Chip(state, "e:pick", "挑选常玩") { state.finishEdit(); state.openLibrary(pick = true) }
                }
                "clock" -> {
                    Chip(state, "e:wx", "天气", on = state.settings.showWeather) { state.update { it.copy(showWeather = !it.showWeather) } }
                    Chip(state, "e:city", if (state.settings.city == null) "选择城市" else "换城市") { state.cityDialog = true }
                    Chip(state, "e:24h", "24 小时制", on = state.settings.use24Hour) { state.update { it.copy(use24Hour = !it.use24Hour) } }
                }
                "trainer" -> Chip(state, "e:name", "编辑称呼") { state.pop = Pop.Trainer(state.rects["st:trainer"] ?: androidx.compose.ui.geometry.Rect.Zero) }
                "tito" -> Text("固定入口", style = text(11.sp, FontWeight.ExtraBold, ink.copy(alpha = .7f)))
                else -> Chip(state, "e:remove", "移除小组件", warn = true) { state.hide(sel.id) }
            }
        } else {
            val hidden = state.layout().filter { it.hidden }
            if (hidden.isNotEmpty()) {
                for (h in hidden) Chip(state, "e:show:${h.id}", "＋ ${state.stickerLabel(h)}", dashed = true) { state.show(h.id) }
                Sep()
            } else if ((state.session?.stack?.size ?: 0) == 0) {
                Text("拖动或轻点贴纸", style = text(11.sp, FontWeight.ExtraBold, ink))
                Sep()
            }
            Text("排布", style = text(11.sp, FontWeight.ExtraBold, ink))
            for (t in Template.entries) Chip(state, "e:tpl:${t.name}", t.label) { state.applyTemplate(t) }
            Sep()
            if (state.device.widgets != null) Chip(state, "e:widget", "＋ 小组件") { state.widgetPicker = true }
            Chip(state, "e:settings", "⚙ 设置") { state.openSettings() }
        }
    }
}

@Composable
private fun Ph(t: String, gap: Boolean = false) {
    Text(t, style = text(11.sp, FontWeight.ExtraBold, Navy.copy(alpha = .6f), .6.sp), modifier = Modifier.padding(top = if (gap) 14.dp else 2.dp, bottom = 7.dp))
}

@Composable
private fun LookPanel(state: LauncherState, wDp: Float, hDp: Float, photo: ImageBitmap?, now: Calendar) {
    val s = state.settings
    Ph("主题 · 轻点即在上方预览")
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (t in LauncherTheme.entries) {
            val on = s.theme == t
            Column(
                Modifier.weight(1f).padTarget(state, "e:theme:${t.name}", t.label, 14f) { state.setTheme(t) }
                    .background(if (on) Coral.copy(alpha = .08f) else Navy.copy(alpha = .06f), RoundedCornerShape(14.dp))
                    .border(2.5.dp, if (on) Coral else Color.Transparent, RoundedCornerShape(14.dp))
                    .pointerInput(t) { detectTapGestures { state.setTheme(t) } }
                    .padding(start = 5.dp, end = 5.dp, top = 5.dp, bottom = 7.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1.9f).clip(RoundedCornerShape(9.dp))) {
                    val k = maxWidth.value / 480f
                    Stage(
                        state, s.copy(theme = t), Orient.square, 480f, 480f, live = false, editLayout = false, photo = photo, now = now,
                        modifier = Modifier.wrapContentSize(Alignment.TopStart, unbounded = true).graphicsLayer { scaleX = k; scaleY = k; transformOrigin = TransformOrigin(0f, 0f) },
                    )
                }
                Text(t.label, style = text(12.5.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.padding(top = 5.dp))
                Text(t.blurb, style = text(9.5.sp, FontWeight.Bold, Navy.copy(alpha = .65f)), textAlign = TextAlign.Center)
            }
        }
    }
    Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("背景露出", style = text(12.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.width(56.dp))
        Text("少", style = text(11.sp, color = Navy.copy(alpha = .6f)))
        Slider(
            value = s.reveal, onValueChange = { state.previewReveal(it) }, onValueChangeFinished = { state.commitReveal() },
            steps = 19, modifier = Modifier.weight(1f).height(30.dp),
            colors = SliderDefaults.colors(thumbColor = Navy, activeTrackColor = Navy, inactiveTrackColor = Navy.copy(alpha = .2f), activeTickColor = Color.Transparent, inactiveTickColor = Color.Transparent),
        )
        Text("多", style = text(11.sp, color = Navy.copy(alpha = .6f)))
    }
    Ph("动态效果", gap = true)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Chip(state, "e:m1", "标准", on = s.motion) { state.update { it.copy(motion = true) } }
        Chip(state, "e:m0", "减少", on = !s.motion) { state.update { it.copy(motion = false) } }
    }
    Ph("按键提示", gap = true)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (h in Hints.entries) Chip(state, "e:h:${h.name}", h.label, on = s.hints == h) { state.update { it.copy(hints = h) } }
    }
}

@Composable
private fun WallPanel(state: LauncherState) {
    val s = state.settings
    Ph("壁纸")
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        val walls = Wall.entries.filter { it != Wall.photo || s.photo != null }
        for (w in walls) {
            val on = s.wallpaper == w
            Column(
                Modifier.width(74.dp).padTarget(state, "e:wall:${w.name}", w.label, 12f) { state.setWall(w) }
                    .border(2.5.dp, if (on) Coral else Color.Transparent, RoundedCornerShape(12.dp))
                    .pointerInput(w) { detectTapGestures { state.setWall(w) } }.padding(3.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Wallpaper(s.theme, w, Effect.clear, if (w == Wall.photo) state.photoBitmap else null, Modifier.fillMaxWidth().height(56.dp).clip(RoundedCornerShape(9.dp)))
                Text(w.label, style = text(11.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.padding(top = 3.dp))
            }
        }
        Column(
            Modifier.width(74.dp).padTarget(state, "e:photo", "选照片", 12f) { state.pickPhoto() }
                .pointerInput(Unit) { detectTapGestures { state.pickPhoto() } }.padding(3.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier.fillMaxWidth().height(56.dp).drawBehind {
                    drawRoundRect(Navy.copy(alpha = .4f), cornerRadius = CornerRadius(9.dp.toPx()), style = Stroke(1.6.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f))))
                },
                contentAlignment = Alignment.Center,
            ) { Text(if (state.photoBusy) "…" else "＋", style = text(20.sp, FontWeight.ExtraBold, Navy)) }
            Text(if (state.photoBusy) "正在导入" else "选照片…", style = text(11.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.padding(top = 3.dp))
        }
    }
    Ph("效果", gap = true)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for (e in Effect.entries) Chip(state, "e:eff:${e.name}", e.label, on = s.effect == e) { state.setEffect(e) }
    }
    Ph("恢复", gap = true)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Chip(state, "e:rw", "恢复默认背景") { state.resetWallpaper() }
        Text("仍可撤销", style = text(11.sp, color = Navy.copy(alpha = .6f)))
    }
}
