package com.tito.titodex.launcher.ui

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.tito.titodex.launcher.LauncherTheme

/**
 * Native interpretation of Motion Prompt #001, #002, #009, #010 and #011 (MIT,
 * Shohei Ohtaki), studied at 770eefb7091cc725ab0eb6d4ef5cbf28b28e282c:
 * https://github.com/showheyohtaki/motion-prompt
 * Concepts only: no JavaScript or reference artwork is included. UI amplitudes
 * are deliberately smaller, finite and interruptible; input never waits on motion.
 */
internal data class LauncherMotion(val theme: LauncherTheme, val enabled: Boolean) {
    fun settle(): FiniteAnimationSpec<Float> = when {
        !enabled -> snap()
        theme == LauncherTheme.journal -> spring(dampingRatio = .82f, stiffness = 650f, visibilityThreshold = .001f)
        theme == LauncherTheme.plastic -> spring(dampingRatio = 1f, stiffness = 850f, visibilityThreshold = .001f)
        else -> tween(150, easing = CubicBezierEasing(.2f, 0f, 0f, 1f))
    }

    // Exits are short and monotonic so surfaces never bounce back over active controls.
    fun exit(): FiniteAnimationSpec<Float> = if (!enabled) snap() else tween(
        if (theme == LauncherTheme.flat) 120 else 180,
        easing = CubicBezierEasing(.4f, 0f, 1f, 1f),
    )

    fun press(): FiniteAnimationSpec<Float> = if (!enabled) snap() else tween(
        if (theme == LauncherTheme.flat) 60 else 80,
        easing = CubicBezierEasing(.2f, 0f, 0f, 1f),
    )

    val revealDp: Float get() = when (theme) {
        LauncherTheme.journal -> 6f
        LauncherTheme.plastic -> 4f
        LauncherTheme.flat -> 2f
    }
}

internal val LocalLauncherMotion = staticCompositionLocalOf { LauncherMotion(LauncherTheme.journal, false) }
internal val LocalMotionControls = staticCompositionLocalOf { true }

/** Read immediately, then observe changes, including changes while a motion is running. */
@Composable
internal fun launcherMotion(theme: LauncherTheme, requested: Boolean): LauncherMotion {
    val resolver = LocalContext.current.contentResolver
    fun readScale() = Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    var scale by remember(resolver) { mutableFloatStateOf(readScale()) }
    DisposableEffect(resolver) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) { scale = readScale() }
        }
        resolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)
        // Close the read/register race when returning from Android settings.
        scale = readScale()
        onDispose { resolver.unregisterContentObserver(observer) }
    }
    return LauncherMotion(theme, requested && scale > 0f)
}

@Composable
internal fun motionFloat(target: Float, motion: LauncherMotion): Float {
    val value by animateFloatAsState(target, motion.settle(), label = "launcher settle")
    // Bypass the animation state on the very first reduced-motion frame.
    return if (motion.enabled) value else target
}

private class DragHandoff { var last: Float? = null }

/**
 * Drag coordinates go straight to layout, without a coroutine/frame of latency.
 * Release starts at the last drawn coordinate. Re-targeting cancels animateTo
 * and retains its current position/velocity; no completion callback mutates UI state.
 */
@Composable
internal fun dragMotionFloat(
    target: Float, direct: Float?, motion: LauncherMotion, exiting: Boolean = false,
): Float {
    val value = remember { Animatable(target) }
    val handoff = remember { DragHandoff() }
    // Keep observing the animator even while direct input/handoff is painted.
    // Otherwise the first release frame could stop subscribing to its updates.
    val animated = value.value
    SideEffect { if (direct != null) handoff.last = direct }
    LaunchedEffect(target, direct, motion, exiting) {
        if (direct != null) {
            value.snapTo(direct)
        } else {
            handoff.last?.let { value.snapTo(it) }
            handoff.last = null
            if (motion.enabled) value.animateTo(target, if (exiting) motion.exit() else motion.settle())
            else value.snapTo(target)
        }
    }
    return direct ?: if (!motion.enabled) target else handoff.last ?: animated
}

/** One bounded arrival, restarted only for a new identity, never for clock ticks. */
@Composable
internal fun revealProgress(identity: Any, motion: LauncherMotion = LocalLauncherMotion.current): Float {
    val progress = remember(identity) { Animatable(if (motion.enabled) 0f else 1f) }
    LaunchedEffect(identity, motion) {
        if (motion.enabled) progress.animateTo(1f, motion.settle()) else progress.snapTo(1f)
    }
    return if (motion.enabled) progress.value else 1f
}

/** Paint only: focus bounds and touch targets are available at their final geometry immediately. */
internal fun Modifier.motionReveal(identity: Any, order: Int = 0): Modifier = composed {
    val motion = LocalLauncherMotion.current
    val progress = revealProgress(identity, motion)
    this.drawWithContent {
        val lag = if (motion.enabled) order.coerceIn(0, 2) * .07f else 0f
        val p = ((progress - lag) / (1f - lag)).coerceIn(0f, 1.025f)
        val travel = motion.revealDp.dp.toPx()
        withTransform({
            translate(top = (1f - p) * travel)
            val zoom = .96f + .04f * p
            scale(zoom, zoom)
        }) { this@drawWithContent.drawContent() }
    }
}
