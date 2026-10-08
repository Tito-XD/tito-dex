package com.tito.titodex

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.ComponentName
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Bundle
import java.security.SecureRandom

/** Only the explicit PackageInstaller PendingIntent may enter this non-exported component. */
class ExtensionInstallStatusActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            handleStatus()
        } finally {
            finish()
        }
    }

    private fun handleStatus() {
        val callback = intent ?: return
        if (callback.action != ACTION) return
        val id = callback.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
        val prefs = getSharedPreferences(STORE, Context.MODE_PRIVATE)
        val token = prefs.getString("token_$id", null) ?: return
        if (callback.data?.toString() != "titodex-install://callback/$id/$token") return
        if (!callback.hasExtra(PackageInstaller.EXTRA_STATUS)) return
        val status = callback.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) {
            clear(this, id)
            return
        }
        if (prefs.getBoolean("used_$id", false)) return
        val session = packageManager.packageInstaller.getSessionInfo(id) ?: return
        if (session.installerPackageName != packageName ||
            session.appPackageName != "com.tito.titodex.extension.journeyassistant") return
        // Consume before accessing or launching the nested intent, including malformed callbacks.
        if (!prefs.edit().putBoolean("used_$id", true).commit()) return
        val confirmation = if (Build.VERSION.SDK_INT >= 33) {
            callback.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            callback.getParcelableExtra(Intent.EXTRA_INTENT) as? Intent
        } ?: return
        if (confirmation.action != "android.content.pm.action.CONFIRM_INSTALL" ||
            confirmation.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1) != id ||
            confirmation.selector != null || confirmation.clipData != null ||
            confirmation.data != null) return
        val target = packageManager.resolveActivity(confirmation, 0)?.activityInfo ?: return
        if (target.applicationInfo.flags and
            (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0) return
        confirmation.component = ComponentName(target.packageName, target.name)
        confirmation.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(confirmation)
    }

    companion object {
        const val ACTION = "com.tito.titodex.JOURNEY_ASSISTANT_INSTALL_STATUS"
        private const val STORE = "extension_install_callbacks"

        fun register(context: Context, id: Int): String {
            val token = ByteArray(32).also { SecureRandom().nextBytes(it) }
                .joinToString("") { "%02x".format(it) }
            check(context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit()
                .putString("token_$id", token).putBoolean("used_$id", false).commit())
            return token
        }

        fun clear(context: Context, id: Int) {
            val token = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
                .getString("token_$id", null)
            context.getSharedPreferences(STORE, Context.MODE_PRIVATE).edit()
                .remove("token_$id").remove("used_$id").commit()
            PendingIntent.getActivity(context, id,
                Intent(context, ExtensionInstallStatusActivity::class.java).apply {
                    action = ACTION
                    data = android.net.Uri.parse("titodex-install://callback/$id/$token")
                }, PendingIntent.FLAG_NO_CREATE or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)?.cancel()
        }
    }
}
