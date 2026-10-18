package com.tito.titodex.launcher

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import com.tito.titodex.launcher.ui.LauncherApp

class MainActivity : ComponentActivity() {
    private lateinit var device: AndroidDevice
    private lateinit var state: LauncherState
    private var lastAxisTime = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        device = AndroidDevice(this) { if (::state.isInitialized) state.refreshApps() }
        state = LauncherState(device, OpenMeteo(), lifecycleScope)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() { state.back() }
        })
        setContent { LauncherApp(state) }
        state.start()
    }

    override fun onStart() {
        super.onStart()
        device.widgets.startListening()
    }

    override fun onStop() {
        device.widgets.stopListening()
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        state.refreshStatus()
        state.refreshWeather()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.hasCategory(Intent.CATEGORY_HOME)) state.goHome()
    }

    @Deprecated("Activity result bridge for system pickers")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_PHOTO -> device.onPhotoResult(resultCode == RESULT_OK, data?.data)
            REQUEST_HOME -> state.refreshStatus()
            else -> device.widgets.onActivityResult(requestCode, resultCode)
        }
    }

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (ev.actionMasked == MotionEvent.ACTION_DOWN && ev.isFromSource(InputDevice.SOURCE_TOUCHSCREEN)) state.input = InputKind.Touch
        return super.dispatchTouchEvent(ev)
    }

    // Overriding dispatchKeyEvent itself is public API; lint trips on androidx.core's restricted overload.
    @SuppressLint("RestrictedApi")
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val pad = padButton(code)
        val dpad = code == KeyEvent.KEYCODE_DPAD_UP || code == KeyEvent.KEYCODE_DPAD_DOWN || code == KeyEvent.KEYCODE_DPAD_LEFT || code == KeyEvent.KEYCODE_DPAD_RIGHT
        if (pad != null || dpad || code == KeyEvent.KEYCODE_BUTTON_A || code == KeyEvent.KEYCODE_DPAD_CENTER) state.input = InputKind.Pad
        when {
            code == KeyEvent.KEYCODE_BUTTON_A -> return super.dispatchKeyEvent(
                KeyEvent(event.downTime, event.eventTime, event.action, KeyEvent.KEYCODE_DPAD_CENTER, event.repeatCount, event.metaState, event.deviceId, event.scanCode, event.flags, event.source),
            )
            code == KeyEvent.KEYCODE_BUTTON_B -> { if (event.action == KeyEvent.ACTION_UP) state.back(); return true }
            pad != null -> { if (event.action == KeyEvent.ACTION_UP) state.pad(pad); return true }
            dpad && state.holding != null -> {
                if (event.action == KeyEvent.ACTION_DOWN) state.padMove(
                    when (code) { KeyEvent.KEYCODE_DPAD_UP -> Dir.Up; KeyEvent.KEYCODE_DPAD_DOWN -> Dir.Down; KeyEvent.KEYCODE_DPAD_LEFT -> Dir.Left; else -> Dir.Right },
                )
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun padButton(code: Int): PadButton? = when (code) {
        KeyEvent.KEYCODE_BUTTON_X -> PadButton.X
        KeyEvent.KEYCODE_BUTTON_Y -> PadButton.Y
        KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_MENU -> PadButton.Start
        KeyEvent.KEYCODE_BUTTON_SELECT -> PadButton.Select
        KeyEvent.KEYCODE_BUTTON_L1 -> PadButton.L1
        KeyEvent.KEYCODE_BUTTON_R1 -> PadButton.R1
        else -> null
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.isFromSource(InputDevice.SOURCE_JOYSTICK) && event.action == MotionEvent.ACTION_MOVE) {
            val x = event.getAxisValue(MotionEvent.AXIS_HAT_X).takeIf { kotlin.math.abs(it) > 0.5f } ?: event.getAxisValue(MotionEvent.AXIS_X)
            val y = event.getAxisValue(MotionEvent.AXIS_HAT_Y).takeIf { kotlin.math.abs(it) > 0.5f } ?: event.getAxisValue(MotionEvent.AXIS_Y)
            val key = when { x > 0.6 -> KeyEvent.KEYCODE_DPAD_RIGHT; x < -0.6 -> KeyEvent.KEYCODE_DPAD_LEFT; y > 0.6 -> KeyEvent.KEYCODE_DPAD_DOWN; y < -0.6 -> KeyEvent.KEYCODE_DPAD_UP; else -> 0 }
            if (key != 0 && event.eventTime - lastAxisTime > 180) {
                lastAxisTime = event.eventTime
                dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, key)); dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, key))
            }
            return true
        }
        return super.dispatchGenericMotionEvent(event)
    }

    override fun onDestroy() {
        device.dispose()
        super.onDestroy()
    }
}
