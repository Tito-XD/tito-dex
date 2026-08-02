package com.tito.titodex

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class DexDownloadForegroundService : Service() {
    private lateinit var notificationManager: NotificationManager
    private var foregroundStarted = false
    private var currentTitle = "TitoDex"

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "离线资料包下载",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "显示 TitoDex 离线资料包的下载与安装进度"
                    setShowBadge(false)
                },
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                showProgress(
                    intent.getIntExtra(EXTRA_PROGRESS, 0),
                    intent.getStringExtra(EXTRA_TEXT).orEmpty(),
                    startForegroundNow = true,
                )
            }
            ACTION_UPDATE -> showProgress(
                intent.getIntExtra(EXTRA_PROGRESS, 0),
                intent.getStringExtra(EXTRA_TEXT).orEmpty(),
                startForegroundNow = false,
            )
            ACTION_COMPLETE -> finishWithNotification(
                intent.getStringExtra(EXTRA_TITLE) ?: currentTitle,
                intent.getStringExtra(EXTRA_TEXT).orEmpty(),
                android.R.drawable.stat_sys_download_done,
            )
            ACTION_FAIL -> finishWithNotification(
                intent.getStringExtra(EXTRA_TITLE) ?: currentTitle,
                intent.getStringExtra(EXTRA_TEXT).orEmpty(),
                android.R.drawable.stat_notify_error,
            )
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (foregroundStarted) {
            finishWithNotification(
                "后台下载已停止",
                "重新打开 TitoDex 后可继续下载",
                android.R.drawable.stat_notify_error,
            )
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        finishWithNotification(
            "后台下载已暂停",
            "Android 已结束长时间后台任务，请返回 TitoDex 继续",
            android.R.drawable.stat_notify_error,
        )
    }

    private fun showProgress(progress: Int, text: String, startForegroundNow: Boolean) {
        val notification = buildNotification(
            title = currentTitle,
            text = text,
            icon = android.R.drawable.stat_sys_download,
            progress = progress.coerceIn(0, 100),
            ongoing = true,
        )
        if (startForegroundNow || !foregroundStarted) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            foregroundStarted = true
        } else {
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun finishWithNotification(title: String, text: String, icon: Int) {
        val notification = buildNotification(
            title = title,
            text = text,
            icon = icon,
            progress = null,
            ongoing = false,
        )
        if (!foregroundStarted) {
            startForeground(NOTIFICATION_ID, notification)
            foregroundStarted = true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        foregroundStarted = false
        notificationManager.notify(NOTIFICATION_ID, notification)
        stopSelf()
    }

    private fun buildNotification(
        title: String,
        text: String,
        icon: Int,
        progress: Int?,
        ongoing: Boolean,
    ): Notification {
        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }.apply {
            setSmallIcon(icon)
            setContentTitle(title)
            setContentText(text)
            setStyle(Notification.BigTextStyle().bigText(text))
            setContentIntent(contentIntent)
            setOnlyAlertOnce(true)
            setOngoing(ongoing)
            setAutoCancel(!ongoing)
            setCategory(Notification.CATEGORY_PROGRESS)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                setPriority(Notification.PRIORITY_LOW)
            }
            if (progress != null) {
                setProgress(100, progress, false)
            }
        }.build()
    }

    companion object {
        private const val CHANNEL_ID = "titodex_dex_download"
        private const val NOTIFICATION_ID = 47023
        private const val ACTION_START = "com.tito.titodex.dex.START"
        private const val ACTION_UPDATE = "com.tito.titodex.dex.UPDATE"
        private const val ACTION_COMPLETE = "com.tito.titodex.dex.COMPLETE"
        private const val ACTION_FAIL = "com.tito.titodex.dex.FAIL"
        private const val EXTRA_PROGRESS = "progress"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"

        fun start(context: Context, progress: Int, title: String, text: String) {
            dispatch(
                context,
                Intent(context, DexDownloadForegroundService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_PROGRESS, progress)
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_TEXT, text)
                },
            )
        }

        fun update(context: Context, progress: Int, text: String) {
            dispatch(
                context,
                Intent(context, DexDownloadForegroundService::class.java).apply {
                    action = ACTION_UPDATE
                    putExtra(EXTRA_PROGRESS, progress)
                    putExtra(EXTRA_TEXT, text)
                },
            )
        }

        fun complete(context: Context, title: String, text: String) {
            finish(context, ACTION_COMPLETE, title, text)
        }

        fun fail(context: Context, title: String, text: String) {
            finish(context, ACTION_FAIL, title, text)
        }

        fun cancel(context: Context) {
            context.stopService(Intent(context, DexDownloadForegroundService::class.java))
            context.getSystemService(NotificationManager::class.java)
                .cancel(NOTIFICATION_ID)
        }

        private fun finish(context: Context, actionName: String, title: String, text: String) {
            dispatch(
                context,
                Intent(context, DexDownloadForegroundService::class.java).apply {
                    action = actionName
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_TEXT, text)
                },
            )
        }

        private fun dispatch(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
