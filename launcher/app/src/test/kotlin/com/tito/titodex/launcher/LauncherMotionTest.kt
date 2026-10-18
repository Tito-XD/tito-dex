package com.tito.titodex.launcher

import android.content.Context
import android.provider.Settings as AndroidSettings
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import com.tito.titodex.launcher.ui.FocusTargets
import com.tito.titodex.launcher.ui.LauncherApp
import com.tito.titodex.launcher.ui.LauncherMotion
import com.tito.titodex.launcher.ui.dragMotionFloat
import com.tito.titodex.launcher.ui.launcherMotion
import com.tito.titodex.launcher.ui.revealProgress
import kotlinx.coroutines.Dispatchers
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w480dp-h480dp-hdpi")
class LauncherMotionTest {
    @get:Rule val rule = createComposeRule()
    private val resolver get() = ApplicationProvider.getApplicationContext<Context>().contentResolver
    private var oldScale = 1f

    @Before fun enableSystemMotion() {
        oldScale = AndroidSettings.Global.getFloat(resolver, AndroidSettings.Global.ANIMATOR_DURATION_SCALE, 1f)
        setScale(1f)
    }

    @After fun restoreSystemMotion() { setScale(oldScale) }

    private fun setScale(value: Float) {
        AndroidSettings.Global.putFloat(resolver, AndroidSettings.Global.ANIMATOR_DURATION_SCALE, value)
        resolver.notifyChange(AndroidSettings.Global.getUriFor(AndroidSettings.Global.ANIMATOR_DURATION_SCALE), null)
    }

    // Publish external mutations before advancing a paused animation clock.
    // Otherwise Robolectric may assert against the previous composition.
    private fun mutate(action: () -> Unit) {
        rule.runOnIdle {
            action()
            Snapshot.sendApplyNotifications()
        }
    }

    private fun frame() {
        rule.mainClock.advanceTimeByFrame()
        rule.waitForIdle()
    }

    private fun launch(settings: Settings = Settings(coachSeen = true)): Pair<FakeDevice, LauncherState> {
        val device = FakeDevice(settings.encode())
        lateinit var state: LauncherState
        rule.setContent {
            val scope = rememberCoroutineScope()
            state = remember { LauncherState(device, NoWeather, scope, Dispatchers.Unconfined) }
            LaunchedEffect(Unit) { state.start() }
            LauncherApp(state)
        }
        rule.waitUntil(5_000) { state.loaded && state.apps.isNotEmpty() }
        rule.waitForIdle()
        return device to state
    }

    @Test fun allThemesReverseFromCurrentPositionAndLatestTargetWins() {
        val target = mutableStateOf(1f)
        val values = mutableMapOf<LauncherTheme, Float>()
        rule.setContent {
            for (theme in LauncherTheme.entries) {
                val value = dragMotionFloat(target.value, null, LauncherMotion(theme, true), exiting = target.value == 1f)
                SideEffect { values[theme] = value }
            }
        }
        rule.mainClock.autoAdvance = false
        mutate { target.value = 0f }
        rule.mainClock.advanceTimeBy(80)
        rule.waitForIdle()
        val before = values.toMap()
        assertTrue(before.values.all { it > 0f && it < 1f })
        mutate { target.value = 1f }
        frame()
        for (theme in LauncherTheme.entries) {
            assertTrue("$theme jumped to an endpoint on reversal", values.getValue(theme) < 1f)
            assertTrue("$theme lost its current position", kotlin.math.abs(values.getValue(theme) - before.getValue(theme)) < .3f)
        }
        rule.mainClock.advanceTimeBy(32)
        mutate { target.value = 0f }
        rule.mainClock.advanceTimeBy(1_200)
        rule.waitForIdle()
        assertTrue(values.values.all { kotlin.math.abs(it) < .001f })
        // No old close completion may revive the sheet after the latest open.
        rule.mainClock.advanceTimeBy(1_200)
        rule.waitForIdle()
        assertTrue(values.values.all { kotlin.math.abs(it) < .001f })
    }

    @Test fun draggingBypassesEasingAndReleaseStartsAtLastDrawnPosition() {
        val direct = mutableStateOf<Float?>(null)
        var value = 0f
        rule.setContent {
            val current = dragMotionFloat(0f, direct.value, LauncherMotion(LauncherTheme.journal, true))
            SideEffect { value = current }
        }
        rule.mainClock.autoAdvance = false
        for (position in listOf(17f, 93f, 41f)) {
            mutate { direct.value = position }
            frame()
            assertEquals("drag must not interpolate", position, value, .001f)
        }
        mutate { direct.value = null }
        frame()
        assertTrue("release flashed back to the old rest position", value > 30f)
        rule.mainClock.advanceTimeBy(1_000)
        rule.waitForIdle()
        assertEquals(0f, value, .001f)
    }

    @Test fun disablingAppMotionMidFlightSnapsButStillAllowsDirectDrag() {
        val enabled = mutableStateOf(true)
        val target = mutableStateOf(1f)
        val direct = mutableStateOf<Float?>(null)
        var value = 1f
        var reveal = 0f
        rule.setContent {
            val motion = launcherMotion(LauncherTheme.journal, enabled.value)
            val current = dragMotionFloat(target.value, direct.value, motion)
            val arrival = revealProgress(target.value, motion)
            SideEffect { value = current; reveal = arrival }
        }
        rule.mainClock.autoAdvance = false
        mutate { target.value = 0f }
        rule.mainClock.advanceTimeBy(64)
        mutate { enabled.value = false }
        frame()
        assertEquals(0f, value, 0f)
        assertEquals(1f, reveal, 0f)
        mutate { direct.value = .43f }
        frame()
        assertEquals(.43f, value, 0f)
        mutate { direct.value = null; target.value = 1f }
        frame()
        assertEquals(1f, value, 0f)
    }

    @Test fun systemScaleZeroCancelsAnActiveMotionAndReenableDoesNotReplayReveal() {
        val target = mutableStateOf(1f)
        var value = 1f
        var reveal = 0f
        var enabled = true
        rule.setContent {
            val motion = launcherMotion(LauncherTheme.plastic, true)
            val current = dragMotionFloat(target.value, null, motion)
            val arrival = revealProgress(target.value, motion)
            SideEffect { value = current; reveal = arrival; enabled = motion.enabled }
        }
        rule.mainClock.autoAdvance = false
        mutate { target.value = 0f }
        rule.mainClock.advanceTimeBy(64)
        mutate { setScale(0f) }
        repeat(3) { frame() }
        assertFalse(enabled)
        assertEquals(0f, value, 0f)
        assertEquals(1f, reveal, 0f)
        mutate { setScale(1f) }
        repeat(3) { frame() }
        assertTrue(enabled)
        assertEquals(1f, reveal, 0f)
    }

    @Test fun closingLibraryRemovesItsTargetsWhileHomeRemainsTouchable() {
        val (device, state) = launch()
        mutate { state.openLibrary() }
        rule.waitForIdle()
        rule.mainClock.autoAdvance = false
        mutate { state.closeLibrary() }
        frame()
        rule.onNodeWithTag("library-sheet").assertDoesNotExist()
        assertFalse(FocusTargets.requesters.keys.any { it.startsWith("lib") || it.startsWith("l:") })
        // Real touch, not just a semantics action: the drawing-only exit must let it through.
        val tito = rule.onNodeWithContentDescription("打开 TitoDex").fetchSemanticsNode().boundsInRoot.center
        rule.onRoot().performTouchInput { click(tito) }
        assertEquals(listOf(TITODEX_PACKAGE), device.launched)
        assertEquals(Mode.Home, state.mode)
    }

    @Test fun repeatedOpenCloseCanLaunchAVisibleIconBeforeArrivalCompletes() {
        val (device, state) = launch()
        rule.mainClock.autoAdvance = false
        mutate { state.openLibrary() }
        rule.mainClock.advanceTimeBy(64)
        mutate { state.closeLibrary() }
        rule.mainClock.advanceTimeBy(32)
        mutate { state.openLibrary() }
        rule.mainClock.advanceTimeBy(112)
        rule.waitForIdle()
        rule.onNodeWithContentDescription("Beta").performTouchInput { click(center) }
        assertEquals(listOf("com.b/B"), device.launched)
        rule.mainClock.advanceTimeBy(1_200)
        rule.waitForIdle()
        assertEquals(Mode.Home, state.mode)
        rule.onNodeWithTag("library-sheet").assertDoesNotExist()
    }

    @Test fun homeInterruptsAnUnfinishedSwipeWithoutReopeningOnRelease() {
        val (_, state) = launch()
        rule.mainClock.autoAdvance = false
        rule.onRoot().performTouchInput {
            down(Offset(width * .5f, height * .95f))
            moveBy(Offset(0f, -100f))
        }
        frame()
        assertNotNull(state.sheetPull)
        mutate { state.goHome() }
        frame()
        rule.onRoot().performTouchInput { up() }
        rule.mainClock.advanceTimeBy(1_200)
        rule.waitForIdle()
        assertNull(state.sheetPull)
        assertEquals(Mode.Home, state.mode)
        rule.onNodeWithTag("library-sheet").assertDoesNotExist()
    }

    @Test fun reducedMotionKeepsEditUndoAndPopupActionsReachable() {
        val (device, state) = launch(Settings(coachSeen = true, motion = false))
        rule.mainClock.autoAdvance = false
        mutate { state.enterEdit(); state.addWidget(device.widgets.provider) }
        frame()
        val id = device.widgets.ids.single()
        mutate { state.finishEdit() }
        frame()
        rule.onNodeWithContentDescription("撤销本次整理").performClick()
        frame()
        assertFalse(id in state.settings.widgetIds())
        assertEquals(listOf(id), device.widgets.deleted)
        rule.onNodeWithContentDescription("Trainer Card").performClick()
        frame()
        rule.onNodeWithContentDescription("✓ 完成").performClick()
        frame()
        assertNull(state.pop)
        rule.onNodeWithContentDescription("应用库").performClick()
        frame()
        rule.onNodeWithContentDescription("Beta").performClick()
        assertEquals(listOf("com.b/B"), device.launched)
    }

    @Test fun handleRemainsTouchableAfterReturningFromEdit() {
        val (_, state) = launch()
        mutate { state.enterEdit() }
        rule.waitForIdle()
        mutate { state.goHome() }
        rule.waitForIdle()
        mutate { setScale(0f) }
        rule.waitForIdle()
        val handle = rule.onNodeWithContentDescription("应用库").fetchSemanticsNode().boundsInRoot
        assertEquals("touch rect must match visible handle after editing", handle, state.rects["handle"])
        rule.onRoot().performTouchInput { click(handle.center) }
        rule.waitForIdle()
        assertEquals(Mode.Library, state.mode)
    }

    @Test fun undoInterruptsModuleMovementWithoutReallocatingWidgetIds() {
        val (device, state) = launch()
        mutate { state.enterEdit(); state.addWidget(device.widgets.provider) }
        rule.waitForIdle()
        val before = state.settings
        val ids = device.widgets.ids.toList()
        val tito = state.layout().first { it.id == "tito" }
        val grid = Grid.spec(state.orient)
        val destination = (0 until grid.rows).flatMap { r -> (0 until grid.cols).map { c -> c to r } }
            .first { (c, r) -> (c != tito.c || r != tito.r) && Grid.move(state.orient, state.layout(), "tito", c, r) != null }
        rule.mainClock.autoAdvance = false
        mutate { assertTrue(state.moveSticker("tito", destination.first, destination.second)) }
        rule.mainClock.advanceTimeBy(64)
        mutate { state.undo() }
        rule.mainClock.advanceTimeBy(1_200)
        rule.waitForIdle()
        assertEquals(before, state.settings)
        assertEquals(ids, device.widgets.ids)
        assertTrue(device.widgets.deleted.isEmpty())
        assertTrue(FocusTargets.requesters.containsKey("st:tito"))
    }
}
