package com.tito.titodex.launcher.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.tito.titodex.launcher.Grid
import com.tito.titodex.launcher.InputKind
import com.tito.titodex.launcher.LauncherState
import com.tito.titodex.launcher.LauncherTheme
import com.tito.titodex.launcher.Mode
import kotlinx.coroutines.delay
import java.util.Calendar

@Composable
fun LauncherApp(state: LauncherState, clock: () -> Calendar = { Calendar.getInstance() }) {
    BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black)) {
        val wDp = maxWidth.value
        val hDp = maxHeight.value
        val o = Grid.orientFor(wDp, hDp)
        SideEffect {
            state.screenDp = wDp to hDp
            if (state.orient != o) state.orient = o
        }
        var now by remember { mutableStateOf(clock()) }
        LaunchedEffect(Unit) {
            while (true) {
                now = clock()
                state.refreshWeather()
                delay(60_000L - now.get(Calendar.SECOND) * 1000L - now.get(Calendar.MILLISECOND) + 50)
            }
        }
        LaunchedEffect(state.settings.photo) { state.loadPhoto() }
        LaunchedEffect(state.input, state.mode, state.homeFocusRequest, state.settingsOpen, state.loaded) {
            if (state.input != InputKind.Pad || !state.loaded || state.settingsOpen) return@LaunchedEffect
            delay(80)
            val current = state.focusKey
            val owned = when (state.mode) {
                Mode.Home -> current != null && !current.startsWith("lib") && !current.startsWith("e:") && !current.startsWith("st:")
                Mode.Edit -> current != null && (current.startsWith("e:") || current.startsWith("st:"))
                Mode.Library -> current != null && (current.startsWith("lib") || current.startsWith("l:"))
            }
            if (owned && FocusTargets.requesters.containsKey(current)) return@LaunchedEffect
            when (state.mode) {
                Mode.Home -> FocusTargets.request("tito")
                Mode.Edit -> FocusTargets.request("st:tito")
                Mode.Library -> FocusTargets.requesters.keys.firstOrNull { it.startsWith("lib") }?.let { FocusTargets.request(it) }
            }
        }

        val look = lookOf(state.settings)
        val motion = launcherMotion(look.theme, state.settings.motion)
        CompositionLocalProvider(LocalLook provides look, LocalLauncherMotion provides motion) {
            val editing = state.mode == Mode.Edit
            Box(Modifier.fillMaxSize().background(editBackdrop(look.theme)))
            val f = stageFrame(editing, state.tab, o, wDp, hDp)
            val scale = motionFloat(f.scale, motion)
            val tx = motionFloat(f.x, motion)
            val ty = motionFloat(f.y, motion)
            val density = LocalDensity.current.density
            Stage(
                state, state.settings, o, wDp, hDp, live = true,
                editLayout = editing && state.tab == com.tito.titodex.launcher.EditTab.layout,
                photo = state.photoBitmap, now = now,
                modifier = Modifier.graphicsLayer {
                    transformOrigin = TransformOrigin(0f, 0f)
                    scaleX = scale; scaleY = scale
                    translationX = tx * density; translationY = ty * density
                    if (scale < .999f) { clip = true; shape = RoundedCornerShape((18 / scale).dp); shadowElevation = 18.dp.toPx() }
                },
            )
            if (editing) EditChrome(state, wDp, hDp, state.photoBitmap, now)
            LibrarySheet(state, wDp, hDp)
            SettingsScreen(state)
            LicensesScreen(state)
            HintsLayer(state)
            CoachLayer(state)
            DragLayer(state)
            PopLayer(state, wDp, hDp)
            CityDialog(state)
            WidgetPicker(state)
            ToastLayer(state)
        }
    }
}

private fun editBackdrop(t: LauncherTheme): Brush = when (t) {
    LauncherTheme.journal -> Brush.verticalGradient(listOf(Color(0xff2a3550), Color(0xff1b2338)))
    LauncherTheme.plastic -> Brush.verticalGradient(listOf(Color(0xff27333d), Color(0xff161d24)))
    LauncherTheme.flat -> Brush.verticalGradient(listOf(Color(0xff2f3438), Color(0xff1d2124)))
}
