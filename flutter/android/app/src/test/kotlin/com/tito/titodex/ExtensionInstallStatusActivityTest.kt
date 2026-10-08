package com.tito.titodex

import android.content.Intent
import android.content.Context
import android.content.pm.PackageInstaller
import android.net.Uri
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ExtensionInstallStatusActivityTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private fun callback(id: Int, token: String, status: Int) = Intent(context,
        ExtensionInstallStatusActivity::class.java).apply {
        action = ExtensionInstallStatusActivity.ACTION
        data = Uri.parse("titodex-install://callback/$id/$token")
        putExtra(PackageInstaller.EXTRA_SESSION_ID, id)
        putExtra(PackageInstaller.EXTRA_STATUS, status)
        putExtra(Intent.EXTRA_INTENT, Intent(Intent.ACTION_VIEW, Uri.parse("https://attacker.invalid")))
    }
    private fun deliver(intent: Intent) {
        val activity = Robolectric.buildActivity(ExtensionInstallStatusActivity::class.java, intent)
            .create().get()
        assertNull(shadowOf(activity).nextStartedActivity)
    }
    @Test fun callbackComponentIsPrivate() {
        val info = context.packageManager.getActivityInfo(
            android.content.ComponentName(context, ExtensionInstallStatusActivity::class.java), 0)
        assertFalse(info.exported)
    }
    @Test fun missingStaleAndWrongSessionCannotLaunch() {
        deliver(callback(987, "missing", PackageInstaller.STATUS_PENDING_USER_ACTION))
        val token = ExtensionInstallStatusActivity.register(context, 988)
        deliver(callback(988, "wrong", PackageInstaller.STATUS_PENDING_USER_ACTION))
        deliver(callback(989, token, PackageInstaller.STATUS_PENDING_USER_ACTION))
        deliver(callback(988, token, PackageInstaller.STATUS_PENDING_USER_ACTION))
        ExtensionInstallStatusActivity.clear(context, 988)
        deliver(callback(988, token, PackageInstaller.STATUS_PENDING_USER_ACTION))
    }
    @Test fun liveSessionConsumesPendingActionOnlyOnce() {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName("com.tito.titodex.extension.journeyassistant")
        val id = installer.createSession(params)
        // Robolectric does not populate the session owner like the Android service does.
        org.robolectric.util.ReflectionHelpers.setField(
            installer.getSessionInfo(id), "installerPackageName", context.packageName)
        val token = ExtensionInstallStatusActivity.register(context, id)
        val prefs = context.getSharedPreferences("extension_install_callbacks", Context.MODE_PRIVATE)
        deliver(callback(id, "wrong", PackageInstaller.STATUS_PENDING_USER_ACTION))
        assertFalse(prefs.getBoolean("used_$id", false))
        deliver(callback(id, token, PackageInstaller.STATUS_PENDING_USER_ACTION))
        assertTrue(prefs.getBoolean("used_$id", false))
        deliver(callback(id, token, PackageInstaller.STATUS_PENDING_USER_ACTION))
        deliver(callback(id, token, PackageInstaller.STATUS_FAILURE_ABORTED))
        assertNull(prefs.getString("token_$id", null))
    }
    @Test fun systemConfirmationLaunchesOnceForLiveSession() {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName("com.tito.titodex.extension.journeyassistant")
        val id = installer.createSession(params)
        org.robolectric.util.ReflectionHelpers.setField(
            installer.getSessionInfo(id), "installerPackageName", context.packageName)
        val token = ExtensionInstallStatusActivity.register(context, id)
        val confirmation = Intent("android.content.pm.action.CONFIRM_INSTALL").apply {
            putExtra(PackageInstaller.EXTRA_SESSION_ID, id)
        }
        val target = android.content.pm.ResolveInfo().apply {
            activityInfo = android.content.pm.ActivityInfo().apply {
                packageName = "com.android.packageinstaller"
                name = "ConfirmInstallActivity"
                applicationInfo = android.content.pm.ApplicationInfo().apply {
                    flags = android.content.pm.ApplicationInfo.FLAG_SYSTEM
                }
            }
        }
        shadowOf(context.packageManager).addResolveInfoForIntent(confirmation, target)
        val outer = callback(id, token, PackageInstaller.STATUS_PENDING_USER_ACTION).apply {
            putExtra(Intent.EXTRA_INTENT, confirmation)
        }
        val activity = Robolectric.buildActivity(ExtensionInstallStatusActivity::class.java, outer)
            .create().get()
        assertEquals("com.android.packageinstaller", shadowOf(activity).nextStartedActivity.component?.packageName)
        deliver(outer)
        ExtensionInstallStatusActivity.clear(context, id)
    }
    @Test fun onlyMatchingTerminalCallbackClearsState() {
        val token = ExtensionInstallStatusActivity.register(context, 990)
        val prefs = context.getSharedPreferences("extension_install_callbacks", Context.MODE_PRIVATE)
        deliver(callback(990, "wrong", PackageInstaller.STATUS_SUCCESS))
        assertEquals(token, prefs.getString("token_990", null))
        deliver(callback(990, token, PackageInstaller.STATUS_SUCCESS))
        assertNull(prefs.getString("token_990", null))
    }
}
