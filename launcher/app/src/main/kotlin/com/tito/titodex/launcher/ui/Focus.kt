package com.tito.titodex.launcher.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.tito.titodex.launcher.InputKind
import com.tito.titodex.launcher.LauncherState
import com.tito.titodex.launcher.LauncherTheme
import com.tito.titodex.launcher.Mode

/** Registry of focus requesters so Home / B / mode changes can put the pad focus somewhere sensible. */
object FocusTargets {
    val requesters = mutableMapOf<String, FocusRequester>()
    fun request(key: String): Boolean {
        val r = requesters[key] ?: return false
        return runCatching { r.requestFocus(); true }.getOrDefault(false)
    }
}

/**
 * A gamepad / keyboard target. A (mapped to DPAD_CENTER) activates it; its bounds are recorded for popovers and drops.
 * Touch is handled by the surrounding gesture layer so long-press and drag stay a single continuous gesture.
 */
fun Modifier.padTarget(state: LauncherState, key: String, label: String? = null, cornerDp: Float = 18f, onActivate: () -> Unit): Modifier = composed {
    var focused by remember { mutableStateOf(false) }
    val requester = remember(key) { FocusRequester() }
    val look = LocalLook.current
    val motion = LocalLauncherMotion.current
    val active = LocalMotionControls.current && when {
        key.startsWith("lib") || key.startsWith("l:") -> state.mode == Mode.Library
        key.startsWith("st:") || key.startsWith("e:") -> state.mode == Mode.Edit
        key in setOf("tito", "trainer", "wx", "handle") || key.startsWith("shelf:") -> state.mode == Mode.Home && state.pop == null && !state.settingsOpen
        else -> true
    }
    var pressed by remember { mutableStateOf(false) }
    val press by animateFloatAsState(if (pressed && active) 1f else 0f,
        if (pressed) motion.press() else motion.settle(), label = "launcher press")
    val arrival = remember { Animatable(1f) }
    val showFocus = focused && active && state.input == InputKind.Pad
    LaunchedEffect(showFocus, motion) {
        if (showFocus && motion.enabled) {
            arrival.snapTo(0f)
            arrival.animateTo(1f, motion.settle())
        } else arrival.snapTo(1f)
    }
    LaunchedEffect(active) { if (!active) pressed = false }
    DisposableEffect(key, active) {
        if (active) FocusTargets.requesters[key] = requester
        onDispose {
            state.rects.remove(key)
            if (FocusTargets.requesters[key] === requester) FocusTargets.requesters.remove(key)
        }
    }
    this
        .onGloballyPositioned { if (active) state.rects[key] = it.boundsInRoot() }
        .semantics {
            role = Role.Button
            if (label != null) contentDescription = label
            if (active) onClick(label) { onActivate(); true }
        }
        .focusProperties { canFocus = active }
        .focusRequester(requester)
        .onFocusChanged {
            focused = it.isFocused
            if (!it.isFocused) pressed = false
            if (it.isFocused && active) state.focusKey = key
        }
        .onKeyEvent {
            val activate = it.key == Key.DirectionCenter || it.key == Key.Enter || it.key == Key.NumPadEnter || it.key == Key.ButtonA
            if (!active || !activate) false else {
                pressed = it.type == KeyEventType.KeyDown
                if (it.type == KeyEventType.KeyUp) onActivate()
                true
            }
        }
        .focusable(enabled = active)
        .pointerInput(active) {
            if (!active) return@pointerInput
            // Observe, never consume: the existing long-press/drag owner keeps the gesture.
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                pressed = true
                try {
                    while (true) {
                        val change = awaitPointerEvent(PointerEventPass.Initial).changes.firstOrNull { it.id == down.id } ?: break
                        if (!change.pressed) break
                        if ((change.position - down.position).getDistance() > viewConfiguration.touchSlop) pressed = false
                    }
                } finally { pressed = false }
            }
        }
        .drawWithContent {
            val p = if (motion.enabled) press.coerceIn(-.08f, 1f) else 0f
            val pressUnit = 1.dp.toPx()
            withTransform({
                when (look.theme) {
                    LauncherTheme.journal -> { translate(top = p * pressUnit); rotate(-.35f * p); scale(1f + .003f * p, 1f - .012f * p) }
                    LauncherTheme.plastic -> { translate(top = p * 2 * pressUnit); scale(1f + .006f * p, 1f - .025f * p) }
                    LauncherTheme.flat -> scale(1f - .01f * p, 1f - .01f * p)
                }
            }) { this@drawWithContent.drawContent() }
            if (pressed && active) drawRoundRect(Navy.copy(alpha = .07f), cornerRadius = CornerRadius(cornerDp.dp.toPx()))
            if (showFocus) {
                val settle = if (motion.enabled) (1f - arrival.value).coerceIn(-.03f, 1f) else 0f
                val inset = ((if (look.theme == LauncherTheme.flat) -5 else -3) - settle * 2).dp.toPx()
                val tl = Offset(inset, inset)
                val sz = Size(size.width - inset * 2, size.height - inset * 2)
                val r = CornerRadius(cornerDp.dp.toPx())
                when (look.theme) {
                    LauncherTheme.journal -> {
                        drawRoundRect(Color(0x2ef7d977), tl, sz, r)
                        drawRoundRect(Color(0xffae9562), tl, sz, r, style = Stroke(4.5.dp.toPx()))
                        drawRoundRect(Yellow, tl, sz, r, style = Stroke(3.dp.toPx()))
                    }
                    LauncherTheme.plastic -> {
                        drawRoundRect(Color(0x66b9dfe7), Offset(tl.x - 6.dp.toPx(), tl.y - 6.dp.toPx()), Size(sz.width + 12.dp.toPx(), sz.height + 12.dp.toPx()), CornerRadius(r.x + 6.dp.toPx()), style = Stroke(8.dp.toPx()))
                        drawRoundRect(Color(0xf2ffffff), tl, sz, r, style = Stroke(2.dp.toPx()))
                    }
                    LauncherTheme.flat -> drawRoundRect(FlatInk, tl, sz, r, style = Stroke(3.5.dp.toPx()))
                }
            }
        }
}
