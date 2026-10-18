package com.tito.titodex.launcher

import android.view.View
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import com.tito.titodex.launcher.ui.LauncherApp
import kotlinx.coroutines.Dispatchers
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

class FakeWidgets : WidgetBridge {
    val ids = mutableListOf<Int>()
    val deleted = mutableListOf<Int>()
    private var next = 100
    val provider = WidgetProvider("demo/.Clock", "示例时钟", "示例", "demo", 110, 40, null)
    override fun providers() = listOf(provider)
    override fun add(provider: WidgetProvider, result: (Int?) -> Unit) { val id = next++; ids += id; result(id) }
    override fun info(id: Int) = if (id in ids) WidgetInfo(provider.label, provider.minWidthDp, provider.minHeightDp) else null
    override fun view(id: Int, onLongPress: () -> Unit): View = View(ApplicationProvider.getApplicationContext())
    override fun resize(id: Int, widthDp: Int, heightDp: Int) {}
    override fun delete(id: Int) { ids -= id; deleted += id }
    override fun allocated() = ids.toList()
}

class FakeDevice(var stored: String? = null) : Device {
    val launched = mutableListOf<String>()
    override val widgets = FakeWidgets()
    override fun loadSettings() = stored
    override fun saveSettings(json: String) { stored = json }
    override fun loadApps() = listOf(
        AppEntry("com.a", "A", "Alpha", "A"),
        AppEntry("com.b", "B", "Beta", "B"),
        AppEntry("com.retro", "R", "RetroArch", "R"),
    )
    override fun icon(app: AppEntry): ImageBitmap? = null
    override fun status() = DeviceStatus(battery = 80, wifi = true, online = true)
    override fun launch(app: AppEntry): Boolean { launched += app.id; return true }
    override fun launchPackage(pkg: String): Boolean { launched += pkg; return true }
    override fun appInfo(pkg: String) = true
    override fun open(entry: SystemEntry) = true
    override fun pickPhoto(result: (Result<String?>) -> Unit) = result(Result.success(null))
    override fun photo(path: String): ImageBitmap? = null
}

object NoWeather : WeatherSource {
    override fun search(query: String): List<City> = emptyList()
    override fun current(city: City): WeatherReading = error("offline")
}

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w480dp-h480dp-hdpi")
class LauncherUiTest {
    @get:Rule val rule = createComposeRule()

    private fun launch(device: FakeDevice = FakeDevice(JSONObject().put("schema", 3).put("coachSeen", true).toString()),
        clock: () -> java.util.Calendar = { java.util.Calendar.getInstance() }): Pair<FakeDevice, LauncherState> {
        lateinit var state: LauncherState
        rule.setContent {
            val scope = rememberCoroutineScope()
            state = remember { LauncherState(device, NoWeather, scope, Dispatchers.Unconfined) }
            LaunchedEffect(Unit) { state.start() }
            LauncherApp(state, clock)
        }
        rule.waitUntil(5_000) { state.loaded && state.apps.isNotEmpty() }
        rule.waitForIdle()
        return device to state
    }

    @Test fun verticalClockKeepsDateWeekdayAndWeatherVisible() {
        val settings = Settings(city = City("测试城市", 31.0, 121.0), coachSeen = true)
            .withLayout(Orient.square, Grid.template(Orient.square, Template.quiet))
        val (_, state) = launch(FakeDevice(settings.encode())) {
            java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 13); set(java.util.Calendar.MINUTE, 57)
            }
        }
        rule.runOnIdle { state.weather = WeatherReading(19.0, 0, 0L) }
        rule.waitForIdle()
        rule.onNodeWithText("13\n57").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { action ->
            val layouts = mutableListOf<TextLayoutResult>()
            assertTrue(action(layouts))
            assertEquals(2, layouts.single().lineCount)
            assertFalse("clock numerals clipped", layouts.single().didOverflowHeight)
            assertFalse("clock numerals too wide", layouts.single().didOverflowWidth)
        }
        val now = java.util.Calendar.getInstance()
        val date = dateLabel(now)
        val weekday = java.text.SimpleDateFormat("EEE", java.util.Locale.US).format(now.time).uppercase(java.util.Locale.US)
        val dateBounds = rule.onNodeWithText(date.substringBefore(' ')).fetchSemanticsNode().boundsInRoot
        val weekdayBounds = rule.onNodeWithText(weekday).fetchSemanticsNode().boundsInRoot
        val dateLayouts = mutableListOf<TextLayoutResult>()
        val weekdayLayouts = mutableListOf<TextLayoutResult>()
        rule.onNodeWithText(date.substringBefore(' ')).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { assertTrue(it(dateLayouts)) }
        rule.onNodeWithText(weekday).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { assertTrue(it(weekdayLayouts)) }
        assertEquals(dateLayouts.single().layoutInput.style.fontSize, weekdayLayouts.single().layoutInput.style.fontSize)
        assertEquals("date and weekday baseline", dateBounds.top + dateLayouts.single().getLineBaseline(0),
            weekdayBounds.top + weekdayLayouts.single().getLineBaseline(0), 1f)
        rule.onNodeWithContentDescription(date.substringAfter(' ')).assertExists()
        for (label in listOf(date.substringBefore(' '), weekday, "19°")) {
            val bounds = rule.onNodeWithText(label).fetchSemanticsNode().boundsInRoot
            assertTrue("vertical clock clipped: $label $bounds", bounds.height >= 30f)
            assertTrue("outside 1x2 cell: $label $bounds", bounds.right <= 190f && bounds.bottom <= 356f)
        }
    }

    @Test fun largeClockReservesUnclippedDateAndWeatherRow() {
        val settings = Settings(city = City("测试城市", 31.0, 121.0), coachSeen = true)
        val layout = settings.layout(Orient.square).map { if (it.id == "clock") it.copy(size = "l") else it }
        val (_, state) = launch(FakeDevice(settings.withLayout(Orient.square, layout).encode()))
        rule.runOnIdle { state.weather = WeatherReading(19.0, 0, 0L) }
        rule.waitForIdle()
        val date = rule.onNodeWithText(dateLabel(java.util.Calendar.getInstance())).fetchSemanticsNode().boundsInRoot
        val weather = rule.onNodeWithText("19°").fetchSemanticsNode().boundsInRoot
        // hdpi (1.5×): 16sp metadata with a 20dp line must not collapse under the large numerals.
        assertTrue("date clipped: $date", date.height >= 30f)
        assertTrue("weather clipped: $weather", weather.height >= 30f)
        assertTrue("metadata below cell: $date / $weather", maxOf(date.bottom, weather.bottom) <= 196f)
    }

    @Test fun weatherPopoverShowsForecastAndBackDismissesIt() {
        val (_, state) = launch(FakeDevice(Settings(city = City("测试城市", 31.0, 121.0), coachSeen = true).encode()))
        rule.onNodeWithText("测试城市").assertDoesNotExist()
        rule.runOnIdle {
            state.weather = WeatherReading(19.0, 3, 0L,
                listOf(HourForecast("22时", 18, 61)),
                listOf(DayForecast("今天", 24, 16, 3)))
        }
        rule.onNodeWithContentDescription("天气").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("未来几小时").assertExists()
        rule.onNodeWithText("未来几天").assertExists()
        rule.onNodeWithText("22时").assertExists()
        rule.onNodeWithText("24°").assertExists()
        rule.runOnIdle { state.back() }
        rule.waitForIdle()
        assertEquals(null, state.pop)
        assertEquals(Mode.Home, state.mode)
    }

    @Test fun homeRendersStickersAndOpensTitoDex() {
        val (device, _) = launch()
        rule.onNodeWithContentDescription("Trainer Card").assertExists()
        rule.onNodeWithContentDescription("打开 TitoDex").performClick()
        rule.waitForIdle()
        assertEquals(listOf(TITODEX_PACKAGE), device.launched)
    }

    @Test fun handleOpensLibraryAndLaunchesApp() {
        val (device, state) = launch()
        rule.onNodeWithContentDescription("应用库").performClick()
        rule.waitForIdle()
        assertEquals(Mode.Library, state.mode)
        rule.onNodeWithText("3 个", substring = true).assertExists()
        rule.onNodeWithText("Beta").performClick()
        rule.waitForIdle()
        assertEquals(listOf("com.b/B"), device.launched)
        assertEquals(listOf("com.b/B"), state.settings.recent)
    }

    @Test fun longPressEmptyWallpaperEntersEditAndDoneLeaves() {
        val (_, state) = launch()
        rule.onRoot().performTouchInput { longClick(center.copy(y = height * .55f)) }
        rule.waitForIdle()
        assertEquals(Mode.Edit, state.mode)
        rule.onNodeWithText("完成").performClick()
        rule.waitForIdle()
        assertEquals(Mode.Home, state.mode)
    }

    @Test fun sizeChipResizesAndUndoRestores() {
        val (device, state) = launch()
        rule.runOnIdle { state.enterEdit(sel = "clock") }
        rule.onNodeWithText("大字").performClick()
        rule.waitForIdle()
        assertEquals("l", state.layout().first { it.id == "clock" }.size)
        assertTrue(device.stored!!.contains("\"size\":\"l\""))
        rule.onNodeWithText("↶ 撤销").performClick()
        rule.waitForIdle()
        assertEquals("s", state.layout().first { it.id == "clock" }.size)
    }

    @Test fun themeSwitchFromLookTab() {
        val (_, state) = launch()
        rule.runOnIdle { state.enterEdit() }
        rule.onNodeWithText("外观").performClick()
        rule.waitForIdle()
        rule.onNodeWithContentDescription(LauncherTheme.flat.label).performClick()
        rule.waitForIdle()
        assertEquals(LauncherTheme.flat, state.settings.theme)
    }

    @Test fun pickerPinsAppsToShelf() {
        val (_, state) = launch()
        rule.runOnIdle { state.openLibrary(pick = true) }
        rule.waitForIdle()
        rule.onNodeWithText("Alpha").performClick()
        rule.waitForIdle()
        assertEquals(listOf("com.a/A"), state.settings.pinned)
        rule.onNodeWithText("完成").performClick()
        rule.waitForIdle()
        assertEquals(Mode.Home, state.mode)
        rule.onNodeWithContentDescription("Alpha").assertExists()
    }

    @Test fun v2PreferencesSurviveAndAreRewrittenAsSchema3() {
        val v2 = """{"style":"flat","name":"小智","favorites":["com.retro/R"],"schema":2,"layout":"quiet","opacity":0.9,"libraryColumns":4}"""
        val (device, state) = launch(FakeDevice(v2))
        assertEquals("小智", state.settings.name)
        assertEquals(LauncherTheme.flat, state.settings.theme)
        rule.runOnIdle { state.dismissCoach() }
        rule.waitForIdle()
        val saved = JSONObject(device.stored!!)
        assertEquals(3, saved.getInt("schema"))
        assertEquals("小智", saved.getString("name"))
        assertEquals("com.retro/R", saved.getJSONArray("favorites").getString(0))
    }

    @Test fun widgetAddThenRemoveReleasesHostId() {
        val (device, state) = launch()
        rule.runOnIdle { state.enterEdit() }
        rule.onNodeWithText("＋ 小组件").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("示例时钟").performClick()
        rule.waitForIdle()
        val id = device.widgets.ids.single()
        assertTrue(state.settings.widgetIds().contains(id))
        assertEquals("widget:$id", state.selected)
        rule.onNodeWithText("移除小组件").performClick()
        rule.waitForIdle()
        assertFalse(state.settings.widgetIds().contains(id))
        // Still undoable inside the session, so the host id is kept until the session ends.
        assertTrue(id in device.widgets.ids)
        rule.onNodeWithText("完成").performClick()
        rule.waitForIdle()
        assertEquals(listOf(id), device.widgets.deleted)
    }

    @Test fun undoingSessionKeepsWidgetUntilToastExpires() {
        val (device, state) = launch()
        rule.runOnIdle { state.enterEdit() }
        rule.runOnIdle { state.addWidget(device.widgets.provider) }
        val id = device.widgets.ids.single()
        rule.runOnIdle { state.finishEdit() }
        rule.waitForIdle()
        assertTrue(id in state.settings.widgetIds())
        assertTrue(device.widgets.deleted.isEmpty())
        rule.runOnIdle { state.toastAction() }
        rule.waitForIdle()
        assertFalse(id in state.settings.widgetIds())
        assertEquals(listOf(id), device.widgets.deleted)
    }
}
