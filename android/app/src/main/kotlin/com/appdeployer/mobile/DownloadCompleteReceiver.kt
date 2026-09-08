package com.appdeployer.mobile

import android.Manifest
import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class DownloadCompleteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return

        val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        if (downloadId < 0) return

        val preferences = context.getSharedPreferences(
            DOWNLOAD_PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        val releaseId = preferences.getString(downloadReleaseIdKey(downloadId), null)
            ?: return

        val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) return

            val status = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            )
            if (status == DownloadManager.STATUS_SUCCESSFUL) {
                showCompletionNotification(context, downloadId, releaseId, preferences)
                return
            }

            if (status == DownloadManager.STATUS_FAILED) {
                showFailedNotification(context, downloadId, releaseId, preferences)
            }
        }
    }

    private fun showCompletionNotification(
        context: Context,
        downloadId: Long,
        releaseId: String,
        preferences: android.content.SharedPreferences,
    ) {
        val title = preferences.getString(downloadTitleKey(downloadId), null)
            ?: "APK download complete"
        val version = preferences.getString(downloadVersionKey(downloadId), null)
        val text = if (version.isNullOrBlank()) {
            "Tap to open App Deployer"
        } else {
            "Version $version is ready to install"
        }

        showNotification(
            context = context,
            downloadId = downloadId,
            releaseId = releaseId,
            title = title,
            text = text,
            icon = android.R.drawable.stat_sys_download_done,
        )
    }

    private fun showFailedNotification(
        context: Context,
        downloadId: Long,
        releaseId: String,
        preferences: android.content.SharedPreferences,
    ) {
        val title = preferences.getString(downloadTitleKey(downloadId), null)
            ?: "APK download failed"

        showNotification(
            context = context,
            downloadId = downloadId,
            releaseId = releaseId,
            title = title,
            text = "Tap to open App Deployer",
            icon = android.R.drawable.stat_notify_error,
        )
    }

    private fun showNotification(
        context: Context,
        downloadId: Long,
        releaseId: String,
        title: String,
        text: String,
        icon: Int,
    ) {
        if (!canPostNotifications(context)) return

        createNotificationChannel(context)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("releaseId", releaseId)
            putExtra("downloadId", downloadId)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            downloadId.toInt(),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        NotificationManagerCompat.from(context).notify(downloadId.toInt(), notification)
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "APK downloads",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "APK download completion alerts"
        }
        manager.createNotificationChannel(channel)
    }

    private companion object {
        const val CHANNEL_ID = "app_deployer_apk_downloads"
    }
}

const val DOWNLOAD_PREFERENCES_NAME = "app_deployer_downloads"

fun downloadKey(releaseId: String): String = "release:$releaseId"

fun downloadReleaseIdKey(downloadId: Long): String = "download:$downloadId:releaseId"

fun downloadTitleKey(downloadId: Long): String = "download:$downloadId:title"

fun downloadVersionKey(downloadId: Long): String = "download:$downloadId:version"
