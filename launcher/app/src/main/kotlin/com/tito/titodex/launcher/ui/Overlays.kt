package com.tito.titodex.launcher.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tito.titodex.launcher.BuildConfig
import com.tito.titodex.launcher.City
import com.tito.titodex.launcher.EditTab
import com.tito.titodex.launcher.Hints
import com.tito.titodex.launcher.InputKind
import com.tito.titodex.launcher.LauncherState
import com.tito.titodex.launcher.LauncherTheme
import com.tito.titodex.launcher.Mode
import com.tito.titodex.launcher.PadButton
import com.tito.titodex.launcher.Pop
import com.tito.titodex.launcher.R
import com.tito.titodex.launcher.SystemEntry
import com.tito.titodex.launcher.TITODEX_PACKAGE
import com.tito.titodex.launcher.WidgetProvider
import com.tito.titodex.launcher.weatherDescription
import kotlin.math.roundToInt

private val Shadowy = Color(0x5908101c)

@Composable
private fun Modifier.card(look: Look, radius: Int = 16): Modifier {
    val shape = RoundedCornerShape(if (look.plastic) radius + 4 else radius).let { it }
    val bg = when (look.theme) { LauncherTheme.journal -> Paper; LauncherTheme.plastic -> Color(0xf2f2f8fa); LauncherTheme.flat -> FlatPaper }
    return this.shadow(14.dp, shape, ambientColor = Shadowy, spotColor = Shadowy).background(bg, shape)
        .then(if (look.journal) Modifier.border(1.25.dp, Navy.copy(alpha = .25f), shape) else if (look.plastic) Modifier.border(1.dp, Color.White.copy(alpha = .8f), shape) else Modifier)
}

@Composable
fun MenuItem(state: LauncherState, key: String, label: String, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().height(40.dp).padTarget(state, key, label, 11f, onClick)
            .pointerInput(onClick) { detectTapGestures { onClick() } }.padding(horizontal = 10.dp),
        contentAlignment = Alignment.CenterStart,
    ) { Text(label, style = text(13.5.sp, FontWeight.Bold, Navy)) }
}

@Composable
private fun Note(t: String) = Text(t, style = text(10.5.sp, FontWeight.Bold, Navy.copy(alpha = .6f)), modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp))

@Composable
fun Field(value: String, onChange: (String) -> Unit, max: Int, modifier: Modifier = Modifier, hint: String = "", onDone: (() -> Unit)? = null) {
    BasicTextField(
        value, { onChange(it.take(max)) }, singleLine = true, textStyle = text(14.sp, FontWeight.Normal, Navy), cursorBrush = SolidColor(Coral),
        keyboardOptions = KeyboardOptions(imeAction = if (onDone != null) ImeAction.Search else ImeAction.Done),
        keyboardActions = KeyboardActions(onSearch = { onDone?.invoke() }, onDone = { onDone?.invoke() }),
        modifier = modifier.fillMaxWidth().height(36.dp).background(Color.White, RoundedCornerShape(10.dp)).border(1.25.dp, Navy.copy(alpha = .3f), RoundedCornerShape(10.dp)),
        decorationBox = { inner ->
            Box(Modifier.fillMaxSize().padding(horizontal = 10.dp), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) Text(hint, style = text(14.sp, FontWeight.Normal, Navy.copy(alpha = .4f)))
                inner()
            }
        },
    )
}

/** Small anchored menus: app options, TitoDex, Trainer Card editing, weather. Outside taps close them. */
@Composable
fun PopLayer(state: LauncherState, wDp: Float, hDp: Float) {
    val pop = state.pop ?: return
    val look = LocalLook.current
    val density = LocalDensity.current
    Box(Modifier.fillMaxSize().pointerInput(pop) { detectTapGestures { state.pop = null } })
    var size by remember(pop) { mutableStateOf(IntSize.Zero) }
    val a = pop.anchor
    val wPx = with(density) { wDp.dp.toPx() }
    val hPx = with(density) { hDp.dp.toPx() }
    val m = with(density) { 8.dp.toPx() }
    var x = a.center.x - size.width / 2f
    var y = a.bottom + m * .75f
    if (y + size.height > hPx - m) y = a.top - size.height - m * .75f
    x = x.coerceIn(m, (wPx - size.width - m).coerceAtLeast(m))
    y = y.coerceAtLeast(m)
    val trainer = pop is Pop.Trainer
    Column(
        Modifier.then(if (trainer) Modifier.imePadding() else Modifier)
            .offset { IntOffset(x.roundToInt(), y.roundToInt()) }
            .motionReveal(pop)
            .onSizeChanged { size = it }
            .width(minOf(wDp - 16f, when (pop) { is Pop.Trainer -> 236f; is Pop.Weather -> 350f; else -> 196f }).dp)
            .heightIn(max = (hDp - 16f).coerceAtLeast(1f).dp).card(look).pointerInput(Unit) { detectTapGestures { } }.padding(6.dp).verticalScroll(rememberScrollState())
            .graphicsLayer { alpha = if (size == IntSize.Zero) 0f else 1f },
    ) {
        when (pop) {
            is Pop.AppMenu -> {
                val app = pop.app
                Row(Modifier.padding(start = 6.dp, end = 6.dp, top = 5.dp, bottom = 7.dp), verticalAlignment = Alignment.CenterVertically) {
                    state.device.icon(app)?.let { Image(it, null, Modifier.size(30.dp)) }
                    Spacer(Modifier.width(8.dp))
                    Text(app.label, style = text(14.sp, FontWeight.ExtraBold, Navy), maxLines = 1)
                }
                val pinned = app.id in state.settings.pinned
                MenuItem(state, "p:open", "▶ 打开") { state.launch(app) }
                MenuItem(state, "p:pin", if (pinned) "☆ 移出常玩" else if (pop.fromShelf) "★ 固定到常玩" else "★ 加入常玩") { state.togglePin(app) }
                MenuItem(state, "p:info", "ⓘ 应用信息") { state.appInfo(app.pkg) }
                Note(if (pop.fromShelf) "按住拖动可调整顺序；拖到顶部可移出" else "按住拖动，可直接放到桌面常玩架")
            }
            is Pop.Tito -> {
                Row(Modifier.padding(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    TitoEmblem(30); Spacer(Modifier.width(8.dp)); Text("TitoDex", style = text(14.sp, FontWeight.ExtraBold, Navy))
                }
                MenuItem(state, "p:open", "▶ 打开 TitoDex") { state.launchTitoDex() }
                MenuItem(state, "p:info", "ⓘ 应用信息") { state.appInfo(TITODEX_PACKAGE) }
                MenuItem(state, "p:edit", "✎ 整理桌面") { state.enterEdit() }
                Note("固定入口，可移动、换尺寸，不能隐藏")
            }
            is Pop.Trainer -> {
                var name by remember { mutableStateOf(state.settings.name) }
                var motto by remember { mutableStateOf(state.settings.motto) }
                Text("Trainer Card", style = text(14.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.padding(6.dp))
                Text("称呼", style = text(11.sp, FontWeight.ExtraBold, Navy.copy(alpha = .6f)), modifier = Modifier.padding(horizontal = 2.dp))
                Field(name, { name = it }, 20, Modifier.padding(top = 3.dp, bottom = 7.dp))
                Text("一句话签名（完整尺寸显示）", style = text(11.sp, FontWeight.ExtraBold, Navy.copy(alpha = .6f)), modifier = Modifier.padding(horizontal = 2.dp))
                Field(motto, { motto = it }, 40, Modifier.padding(top = 3.dp, bottom = 7.dp))
                MenuItem(state, "p:save", "✓ 完成") { state.saveTrainer(name, motto) }
                Note("只保存在这台掌机上")
            }
            is Pop.Weather -> {
                val city = state.settings.city
                val w = state.weather
                Text(
                    w?.let { "${it.temperature.roundToInt()}° ${it.description}" } ?: state.weatherError ?: if (city == null) "添加天气" else "正在获取…",
                    style = text(18.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.padding(start = 6.dp, top = 4.dp, bottom = 2.dp),
                )
                if (w == null || (w.hours.isEmpty() && w.days.isEmpty())) {
                    Note(if (w == null && state.weatherError == null && city != null) "正在获取最近几小时和未来几天" else "暂时没有预报")
                } else {
                    if (w.hours.isNotEmpty()) {
                        Text("未来几小时", style = text(14.sp, FontWeight.ExtraBold, Navy.copy(alpha = .55f)), modifier = Modifier.padding(start = 6.dp, top = 4.dp))
                        Row(Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                            w.hours.forEach { hour ->
                                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(hour.label, style = text(12.sp, FontWeight.Bold, Navy.copy(alpha = .7f)))
                                    Text("${hour.temperature}°", style = text(16.sp, FontWeight.ExtraBold, Navy))
                                    Text(weatherDescription(hour.code), style = text(11.sp, FontWeight.Bold, Navy.copy(alpha = .75f)), maxLines = 1)
                                }
                            }
                        }
                    }
                    if (w.days.isNotEmpty()) {
                        Text("未来几天", style = text(14.sp, FontWeight.ExtraBold, Navy.copy(alpha = .55f)), modifier = Modifier.padding(start = 6.dp))
                        Row(Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 4.dp)) {
                            w.days.forEach { day ->
                                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(day.label, style = text(13.sp, FontWeight.ExtraBold, Navy))
                                    Text("${day.high}°", style = text(15.sp, FontWeight.ExtraBold, Navy))
                                    Text("${day.low}°", style = text(12.sp, FontWeight.Bold, Navy.copy(alpha = .6f)))
                                    Text(weatherDescription(day.code), style = text(12.sp, color = Navy), maxLines = 1)
                                }
                            }
                        }
                    }
                }
                if (w != null && state.weatherError != null) Note("刷新失败，显示上次获取的预报")
                if (city != null) MenuItem(state, "p:r", "↻ 刷新") { state.refreshWeather(force = true) }
                MenuItem(state, "p:c", if (city == null) "⌖ 选择城市" else "⌖ 更换城市") { state.pop = null; state.cityDialog = true }
                if (city != null) MenuItem(state, "p:o", "✕ 关闭天气") { state.pop = null; state.setCity(null) }
            }
        }
    }
    LaunchedEffect(pop) {
        if (state.input == InputKind.Pad) {
            kotlinx.coroutines.delay(60)
            FocusTargets.request(if (pop is Pop.Trainer) "p:save" else if (pop is Pop.Weather) "p:c" else "p:open")
        }
    }
}

@Composable
fun ToastLayer(state: LauncherState) {
    val t = state.toast ?: return
    Box(Modifier.fillMaxSize()) {
        Row(
            Modifier.align(if (state.mode == Mode.Edit) Alignment.BottomCenter else Alignment.TopCenter)
                .padding(top = 30.dp, bottom = 60.dp)
                .motionReveal(t.id)
                .shadow(10.dp, RoundedCornerShape(14.dp)).background(NavyDeep, RoundedCornerShape(14.dp))
                .height(40.dp).padding(start = 14.dp, end = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(t.text, style = text(13.sp, FontWeight.Bold, Cream), maxLines = 1)
            if (t.action != null) Box(
                Modifier.height(30.dp).padTarget(state, "toast:action", t.action, 10f) { state.toastAction() }
                    .background(Yellow, RoundedCornerShape(10.dp)).pointerInput(t.id) { detectTapGestures { state.toastAction() } }.padding(horizontal = 10.dp),
                contentAlignment = Alignment.Center,
            ) { Text(t.action, style = text(12.5.sp, FontWeight.ExtraBold, NavyDeep)) }
            else Spacer(Modifier.width(8.dp))
        }
    }
}

@Composable
fun CoachLayer(state: LauncherState) {
    if (!state.coach || state.pop != null || state.iconDrag != null) return
    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier.align(Alignment.BottomCenter).padding(bottom = 40.dp).width(300.dp)
                .shadow(10.dp, RoundedCornerShape(16.dp)).background(NavyDeep, RoundedCornerShape(16.dp)).padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 10.dp),
        ) {
            val y = text(12.5.sp, FontWeight.ExtraBold, Yellow)
            val n = text(12.5.sp, FontWeight.Bold, Cream).copy(lineHeight = 19.sp)
            Text(androidx.compose.ui.text.buildAnnotatedString {
                pushStyle(y.toSpanStyle()); append("上滑"); pop(); append("或轻点「应用库」打开全部应用。\n")
                pushStyle(y.toSpanStyle()); append("长按"); pop(); append("壁纸空白处整理桌面、换主题和壁纸；长按图标调整常玩。")
            }, style = n)
            Box(
                Modifier.align(Alignment.End).padding(top = 6.dp).height(28.dp).padTarget(state, "coach", "知道了", 9f) { state.dismissCoach() }
                    .background(Yellow, RoundedCornerShape(9.dp)).pointerInput(Unit) { detectTapGestures { state.dismissCoach() } }.padding(horizontal = 12.dp),
                contentAlignment = Alignment.Center,
            ) { Text("知道了", style = text(12.5.sp, FontWeight.ExtraBold, NavyDeep)) }
        }
    }
}

@Composable
fun HintsLayer(state: LauncherState) {
    val h = state.settings.hints
    if (!(h == Hints.always || (h == Hints.auto && state.input == InputKind.Pad)) || state.settingsOpen) return
    @Composable
    fun b(key: String, label: String, btn: PadButton?) {
        Row(
            Modifier.height(26.dp).pointerInput(btn) { detectTapGestures { if (btn != null) state.pad(btn) } }.padding(horizontal = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Box(Modifier.heightIn(min = 18.dp).widthIn(min = 18.dp).background(Cream, RoundedCornerShape(9.dp)).padding(horizontal = 4.dp), contentAlignment = Alignment.Center) {
                Text(key, style = text(10.sp, FontWeight.ExtraBold, NavyDeep))
            }
            Text(label, style = text(11.5.sp, FontWeight.ExtraBold, Cream))
        }
    }
    Box(Modifier.fillMaxSize()) {
        val bar = Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(30.dp)
        when (state.mode) {
            Mode.Edit -> Row(bar.background(Color(0xb808101c)), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                if (state.holding != null) { b("A", "放下", null); b("B", "取消", PadButton.B); Text("方向键 移动", style = text(11.5.sp, FontWeight.ExtraBold, Cream)) }
                else { b("A", "拿起", null); b("X", "尺寸", PadButton.X); b("Y", "隐藏", PadButton.Y); b("L/R", "切换", PadButton.R1); b("⊟", "撤销", PadButton.Select); b("B", "完成", PadButton.B) }
            }
            Mode.Library -> Row(bar.background(Color(0xb808101c)), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                b("A", "打开", null); b("X", "选项", PadButton.X); b("Y", "搜索", PadButton.Y); b("L/R", "跳字母", PadButton.R1); b("B", "返回", PadButton.B)
            }
            Mode.Home -> Row(bar.padding(horizontal = 6.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.background(Color(0x9e08101c), RoundedCornerShape(8.dp))) { b("A", "打开", null); b("X", "选项", PadButton.X) }
                Row(Modifier.background(Color(0x9e08101c), RoundedCornerShape(8.dp))) { b("Y", "搜索", PadButton.Y); b("☰", "整理", PadButton.Start); b("⊟", "设置", PadButton.Select) }
            }
        }
    }
}

@Composable
fun DragLayer(state: LauncherState) {
    val d = state.iconDrag ?: return
    val density = LocalDensity.current
    Box(Modifier.fillMaxSize()) {
        if (d.fromShelf) Box(
            Modifier.fillMaxWidth().height(46.dp).background(if (d.overRemove) Danger else Color(0xb8a03232)),
            contentAlignment = Alignment.Center,
        ) { Text("拖到这里：移出常玩", style = text(13.sp, FontWeight.ExtraBold, Color.White)) }
        val half = with(density) { 25.dp.toPx() }
        Box(
            Modifier.offset { IntOffset((d.pos.x - half).roundToInt(), (d.pos.y - half).roundToInt()) }
                .graphicsLayer { scaleX = 1.12f; scaleY = 1.12f; shadowElevation = 10.dp.toPx(); shape = RoundedCornerShape(14.dp); clip = false },
        ) { AppIcon(state.device.icon(d.app), d.app.label) }
    }
}

// ------------------------------------------------------------------ settings

@Composable
private fun Group(title: String, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(bottom = 8.dp).background(Navy.copy(alpha = .06f), RoundedCornerShape(14.dp)).padding(horizontal = 12.dp, vertical = 10.dp)) {
        Text(title, style = text(12.sp, FontWeight.ExtraBold, LocalLook.current.sheetInk.copy(alpha = .6f), .5.sp), modifier = Modifier.padding(bottom = 5.dp))
        content()
    }
}

@Composable
private fun SRow(state: LauncherState, key: String, title: String, value: String = "", onClick: (() -> Unit)? = null) {
    val ink = LocalLook.current.sheetInk
    Row(
        Modifier.fillMaxWidth().heightIn(min = 36.dp)
            .then(if (onClick != null) Modifier.padTarget(state, key, title, 10f, onClick).pointerInput(onClick) { detectTapGestures { onClick() } } else Modifier),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = text(13.sp, FontWeight.Bold, ink), modifier = Modifier.weight(1f))
        Text(value, style = text(12.sp, FontWeight.Bold, ink.copy(alpha = .65f)), maxLines = 1)
    }
}

@Composable
private fun Toggle(state: LauncherState, key: String, title: String, on: Boolean, onChange: (Boolean) -> Unit) =
    SRow(state, key, title, if (on) "开" else "关") { onChange(!on) }

@Composable
fun SettingsScreen(state: LauncherState) {
    if (!state.settingsOpen) return
    val look = LocalLook.current
    val s = state.settings
    val bg = when (look.theme) {
        LauncherTheme.journal -> Modifier.background(Paper)
        LauncherTheme.plastic -> Modifier.background(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(Color(0xffe6eff3), Color(0xffd5e3ea))))
        LauncherTheme.flat -> Modifier.background(FlatPaper)
    }
    Column(Modifier.fillMaxSize().then(bg).pointerInput(Unit) { detectTapGestures { } }) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip(state, "s:back", "←", tinted = true, label = "回到桌面") { state.settingsOpen = false }
            Text("设置", style = text(19.sp, FontWeight.ExtraBold, look.sheetInk))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 14.dp, end = 14.dp, bottom = 16.dp)) {
            Row(
                Modifier.fillMaxWidth().padding(bottom = 8.dp).background(Navy, RoundedCornerShape(14.dp)).padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("主题、壁纸、贴纸排布都在「整理桌面」里调整，能直接看到效果。", style = text(12.5.sp, FontWeight.Bold, Cream), modifier = Modifier.weight(1f))
                Box(
                    Modifier.height(30.dp).padTarget(state, "s:look", "去整理", 10f) { state.settingsOpen = false; state.enterEdit(EditTab.look) }
                        .background(Yellow, RoundedCornerShape(10.dp)).pointerInput(Unit) { detectTapGestures { state.settingsOpen = false; state.enterEdit(EditTab.look) } }
                        .padding(horizontal = 12.dp),
                    contentAlignment = Alignment.Center,
                ) { Text("去整理", style = text(13.sp, FontWeight.ExtraBold, NavyDeep)) }
            }
            Group("默认桌面") {
                SRow(state, "s:home", if (state.status.defaultHome) "已是默认桌面" else "设为默认桌面", "系统选择器") { state.system(SystemEntry.requestHome) }
                SRow(state, "s:homes", "切换其他桌面", "") { state.system(SystemEntry.homeSettings) }
            }
            Group("训练家") {
                SRow(state, "s:name", "称呼", s.name) { state.pop = Pop.Trainer(state.rects["s:name"] ?: androidx.compose.ui.geometry.Rect.Zero) }
                SRow(state, "s:motto", "一句话签名", s.motto.ifEmpty { "未填写" }) { state.pop = Pop.Trainer(state.rects["s:motto"] ?: androidx.compose.ui.geometry.Rect.Zero) }
            }
            Group("时间与天气") {
                SRow(state, "s:city", "天气城市", s.city?.name?.substringBefore(" · ") ?: "未设置") { state.cityDialog = true }
                if (s.city != null) SRow(state, "s:cityoff", "关闭天气", "") { state.setCity(null) }
                Toggle(state, "s:wx", "在时钟旁显示天气", s.showWeather) { v -> state.update { it.copy(showWeather = v) } }
                Toggle(state, "s:24h", "24 小时制", s.use24Hour) { v -> state.update { it.copy(use24Hour = v) } }
                Text("选择城市后联网获取天气，无需定位权限。天气由 Open-Meteo 提供，每 30 分钟更新一次。", style = text(11.sp, FontWeight.Bold, look.sheetInk.copy(alpha = .6f)))
            }
            Group("应用库") {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("每行图标", style = text(13.sp, FontWeight.Bold, look.sheetInk), modifier = Modifier.weight(1f))
                    for (c in 3..6) Chip(state, "s:cols:$c", "$c", on = s.libraryColumns == c) { state.update { it.copy(libraryColumns = c) } }
                }
                Text("横屏时每行多 2 个。", style = text(11.sp, FontWeight.Bold, look.sheetInk.copy(alpha = .6f)))
            }
            Group("手柄与按键") {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("按键提示", style = text(13.sp, FontWeight.Bold, look.sheetInk), modifier = Modifier.weight(1f))
                    for (h in Hints.entries) Chip(state, "s:h:${h.name}", h.label, on = s.hints == h) { state.update { it.copy(hints = h) } }
                }
                Text(
                    "方向键 / 左摇杆：移动焦点 · A：确认 · B：返回\nX：选项（整理时换尺寸）· Y：搜索（整理时隐藏）\nStart：整理桌面 · Select：设置（整理时撤销）· L1 / R1：跳字母 / 切换标签",
                    style = text(11.sp, FontWeight.Bold, look.sheetInk.copy(alpha = .6f)).copy(lineHeight = 17.sp),
                )
            }
            Group("性能") {
                Toggle(state, "s:blur", "柔焦与磨砂效果", s.blurPanels) { v -> state.update { it.copy(blurPanels = v) } }
                Toggle(state, "s:motion", "减少动态效果", !s.motion) { v -> state.update { it.copy(motion = !v) } }
            }
            Group("系统") {
                SRow(state, "s:wifi", "网络设置", "") { state.system(SystemEntry.wifi) }
                SRow(state, "s:sys", "系统设置", "") { state.system(SystemEntry.settings) }
            }
            Group("恢复") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("恢复全部默认", style = text(13.sp, FontWeight.Bold, look.sheetInk), modifier = Modifier.weight(1f))
                    Chip(state, "s:reset", "恢复", warn = true) { state.resetAll() }
                }
                Text("称呼、常玩、天气城市、外观和排布都会恢复；之后 5 秒内可撤销。", style = text(11.sp, FontWeight.Bold, look.sheetInk.copy(alpha = .6f)))
            }
            Group("关于") {
                SRow(state, "s:ver", "TitoDex Launcher", "${BuildConfig.VERSION_NAME} · 掌机预览版")
                Text(
                    "轻量桌面，连接你的应用与 TitoDex。称呼、常玩与外观只保存在这台掌机上。\n非官方个人项目，与 Nintendo、GAME FREAK、The Pokémon Company 无隶属或赞助关系。",
                    style = text(11.sp, FontWeight.Bold, look.sheetInk.copy(alpha = .6f)).copy(lineHeight = 17.sp),
                )
                SRow(state, "s:lic", "开源许可与来源", "") { state.licenses = true }
            }
        }
    }
}

@Composable
fun LicensesScreen(state: LauncherState) {
    if (!state.licenses) return
    val context = LocalContext.current
    val ofl = remember { runCatching { context.resources.openRawResource(R.raw.nunito_ofl).bufferedReader().use { it.readText() } }.getOrDefault("") }
    Column(Modifier.fillMaxSize().background(Paper).pointerInput(Unit) { detectTapGestures { } }) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip(state, "lic:back", "←", tinted = true, label = "返回") { state.licenses = false }
            Text("开源许可与来源", style = text(19.sp, FontWeight.ExtraBold, JournalInk))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp)) {
            Text(
                "天气与城市搜索：Open-Meteo（open-meteo.com），天气数据 CC BY 4.0。仅在你选择城市后提交搜索词或城市坐标。\n\n" +
                    "背景与图形为原创矢量绘制，不含第三方素材。\n\n字体 Nunito：SIL Open Font License 1.1。\n",
                style = text(12.sp, FontWeight.Bold, JournalInk).copy(lineHeight = 18.sp),
            )
            Text(ofl, style = text(10.5.sp, FontWeight.Normal, JournalInk).copy(lineHeight = 15.sp))
        }
    }
}

@Composable
fun CityDialog(state: LauncherState) {
    if (!state.cityDialog) return
    val look = LocalLook.current
    var q by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<City>>(emptyList()) }
    var message by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    fun search() {
        if (loading) return
        if (q.trim().length < 2) { message = "请输入至少两个字，例如 上海 或 Shanghai"; return }
        loading = true
        message = null
        state.searchCities(q) { r ->
            loading = false
            r.onSuccess { results = it; if (it.isEmpty()) message = "没有找到城市，可尝试拼音或英文名" }
                .onFailure { message = "城市搜索暂时不可用，请检查网络后重试" }
        }
    }
    Box(Modifier.fillMaxSize().background(Color(0x6108101c)).pointerInput(Unit) { detectTapGestures { state.cityDialog = false } }.imePadding(), contentAlignment = Alignment.Center) {
        Column(Modifier.width(340.dp).heightIn(max = 400.dp).card(look, 18).pointerInput(Unit) { detectTapGestures { } }.padding(14.dp)) {
            Text("选择天气城市", style = text(17.sp, FontWeight.ExtraBold, Navy))
            Text("搜索词会发送给 Open-Meteo 城市服务。选择结果后才会开启天气。", style = text(11.sp, FontWeight.Bold, Navy.copy(alpha = .6f)), modifier = Modifier.padding(vertical = 6.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Field(q, { q = it }, 40, Modifier.weight(1f), hint = "城市名 / 拼音", onDone = { search() })
                Chip(state, "c:search", if (loading) "搜索中" else "搜索", primary = true) { search() }
            }
            message?.let { Text(it, style = text(12.sp, FontWeight.Bold, Navy.copy(alpha = .7f)), modifier = Modifier.padding(top = 8.dp)) }
            Column(Modifier.verticalScroll(rememberScrollState()).padding(top = 6.dp)) {
                results.forEachIndexed { i, c -> MenuItem(state, "c:r:$i", c.name) { state.cityDialog = false; state.setCity(c) } }
            }
            Row(Modifier.align(Alignment.End).padding(top = 6.dp)) { Chip(state, "c:cancel", "取消", tinted = true) { state.cityDialog = false } }
        }
    }
}

@Composable
fun WidgetPicker(state: LauncherState) {
    if (!state.widgetPicker) return
    val look = LocalLook.current
    var providers by remember { mutableStateOf<List<WidgetProvider>?>(null) }
    LaunchedEffect(Unit) { providers = state.loadWidgetProviders() }
    Box(Modifier.fillMaxSize().background(Color(0x6108101c)).pointerInput(Unit) { detectTapGestures { state.widgetPicker = false } }) {
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().heightIn(max = 400.dp).card(look, 20).pointerInput(Unit) { detectTapGestures { } }
                .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("添加小组件", style = text(17.sp, FontWeight.ExtraBold, Navy), modifier = Modifier.weight(1f))
                Chip(state, "w:close", "取消", tinted = true) { state.widgetPicker = false }
            }
            Text("系统小组件会放到最近的空位；首次添加时 Android 会询问是否允许。", style = text(11.sp, FontWeight.Bold, Navy.copy(alpha = .6f)), modifier = Modifier.padding(vertical = 6.dp))
            val list = providers
            when {
                list == null -> Text("正在读取…", style = text(12.sp, color = Navy.copy(alpha = .7f)))
                list.isEmpty() -> Text("这台设备上没有可添加的小组件", style = text(12.sp, color = Navy.copy(alpha = .7f)))
                else -> Column(Modifier.verticalScroll(rememberScrollState())) {
                    var lastApp = ""
                    list.forEachIndexed { i, p ->
                        if (p.appLabel != lastApp) {
                            lastApp = p.appLabel
                            Text(p.appLabel, style = text(11.sp, FontWeight.ExtraBold, Navy.copy(alpha = .55f), .6.sp), modifier = Modifier.padding(top = 8.dp, bottom = 2.dp))
                        }
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 44.dp).padTarget(state, "w:$i", p.label, 11f) { state.addWidget(p) }
                                .pointerInput(p.key) { detectTapGestures { state.addWidget(p) } },
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            p.icon?.let { Image(it, null, Modifier.size(30.dp)) } ?: Spacer(Modifier.size(30.dp))
                            Text(p.label, style = text(13.5.sp, FontWeight.Bold, Navy), modifier = Modifier.weight(1f), maxLines = 1)
                            val (cw, ch) = state.cellDp()
                            val w = kotlin.math.ceil((p.minWidthDp - 10f).coerceAtLeast(1f) / cw).toInt().coerceAtLeast(1)
                            val h = kotlin.math.ceil((p.minHeightDp - 10f).coerceAtLeast(1f) / ch).toInt().coerceAtLeast(1)
                            Text("${w}×$h", style = text(11.sp, FontWeight.Bold, Navy.copy(alpha = .6f)))
                        }
                    }
                }
            }
        }
    }
}
