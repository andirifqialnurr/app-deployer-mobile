package com.appdeployer.mobile

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val downloadPreferences by lazy {
        getSharedPreferences(DOWNLOAD_PREFERENCES_NAME, Context.MODE_PRIVATE)
    }

    private val downloadManager by lazy {
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app_deployer/installer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledVersionCode" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(getInstalledVersionCode(packageName))
                }
                "openApkInstaller" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_FILE", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(openApkInstaller(filePath))
                }
                "openInstalledApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(openInstalledApp(packageName))
                }
                "openAppInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(openAppInfo(packageName))
                }
                "requestUninstall" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(requestUninstall(packageName))
                }
                "canRequestPackageInstalls" -> {
                    result.success(canRequestPackageInstalls())
                }
                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app_deployer/download_manager"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enqueueApkDownload" -> {
                    val releaseId = call.argument<String>("releaseId")
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName")
                    val title = call.argument<String>("title")
                    val description = call.argument<String>("description")
                    val versionName = call.argument<String>("versionName")
                    val versionCode = call.argument<Number>("versionCode")?.toLong()
                    val headers = call.argument<Map<*, *>>("headers") ?: emptyMap<Any, Any>()
                    if (releaseId.isNullOrBlank() || url.isNullOrBlank() || fileName.isNullOrBlank()) {
                        result.error(
                            "INVALID_DOWNLOAD",
                            "releaseId, url, and fileName are required",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(
                        enqueueApkDownload(
                            releaseId = releaseId,
                            url = url,
                            fileName = fileName,
                            title = title,
                            description = description,
                            versionName = versionName,
                            versionCode = versionCode,
                            headers = headers,
                        )
                    )
                }
                "queryDownload" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_DOWNLOAD", "downloadId is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(queryDownload(downloadId))
                }
                "removeDownload" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_DOWNLOAD", "downloadId is required", null)
                        return@setMethodCallHandler
                    }
                    val removed = downloadManager.remove(downloadId) > 0
                    clearDownloadById(downloadId)
                    result.success(removed)
                }
                "findDownload" -> {
                    val releaseId = call.argument<String>("releaseId")
                    if (releaseId.isNullOrBlank()) {
                        result.error("INVALID_DOWNLOAD", "releaseId is required", null)
                        return@setMethodCallHandler
                    }
                    result.success(findDownload(releaseId))
                }
                else -> result.notImplemented()
            }
        }

    }

    private fun enqueueApkDownload(
        releaseId: String,
        url: String,
        fileName: String,
        title: String?,
        description: String?,
        versionName: String?,
        versionCode: Long?,
        headers: Map<*, *>,
    ): Long {
        val existingDownloadId = downloadPreferences.getLong(downloadKey(releaseId), -1L)
        if (existingDownloadId >= 0) {
            val existingStatus = queryDownload(existingDownloadId)
            if (existingStatus != null && existingStatus["status"] != "failed") {
                return existingDownloadId
            }
            clearDownloadById(existingDownloadId)
        }

        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle(title ?: "APK download")
            setDescription(description ?: "Downloading APK")
            setMimeType("application/vnd.android.package-archive")
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            setAllowedOverMetered(true)
            setAllowedOverRoaming(false)
            headers.forEach { (key, value) ->
                if (key is String && value is String) {
                    addRequestHeader(key, value)
                }
            }
            setDestinationInExternalFilesDir(
                this@MainActivity,
                Environment.DIRECTORY_DOWNLOADS,
                fileName,
            )
        }
        val downloadId = downloadManager.enqueue(request)
        downloadPreferences.edit()
            .putLong(downloadKey(releaseId), downloadId)
            .putString(downloadReleaseIdKey(downloadId), releaseId)
            .putString(downloadTitleKey(downloadId), title ?: "APK download")
            .putString(
                downloadVersionKey(downloadId),
                listOfNotNull(versionName, versionCode?.toString()).joinToString(" "),
            )
            .apply()
        return downloadId
    }

    private fun findDownload(releaseId: String): Map<String, Any?>? {
        val downloadId = downloadPreferences.getLong(downloadKey(releaseId), -1L)
        if (downloadId < 0) return null

        val status = queryDownload(downloadId)
        if (status == null) {
            clearDownloadById(downloadId)
        }
        return status
    }

    private fun queryDownload(downloadId: Long): Map<String, Any?>? {
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) return null

            val status = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            )
            val reason = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
            )
            val receivedBytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            )
            val totalBytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            )
            val localUri = cursor.getString(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)
            )

            return mapOf(
                "downloadId" to downloadId,
                "status" to downloadStatus(status),
                "reason" to reason,
                "receivedBytes" to receivedBytes,
                "totalBytes" to totalBytes,
                "localUri" to localUri,
                "filePath" to localUri?.let { Uri.parse(it).path },
            )
        }
    }

    private fun clearDownloadById(downloadId: Long) {
        val editor = downloadPreferences.edit()
        downloadPreferences.all.forEach { (key, value) ->
            if ((value is Long && value == downloadId) ||
                key.startsWith("download:$downloadId:")
            ) {
                editor.remove(key)
            }
        }
        editor.apply()
    }

    private fun downloadStatus(status: Int): String {
        return when (status) {
            DownloadManager.STATUS_PENDING -> "pending"
            DownloadManager.STATUS_RUNNING -> "running"
            DownloadManager.STATUS_PAUSED -> "paused"
            DownloadManager.STATUS_SUCCESSFUL -> "successful"
            DownloadManager.STATUS_FAILED -> "failed"
            else -> "unknown"
        }
    }

    private fun getInstalledVersionCode(packageName: String): Long? {
        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun openApkInstaller(filePath: String): Boolean {
        val file = File(filePath)
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return startIntent(intent)
    }

    private fun openInstalledApp(packageName: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return startIntent(intent)
    }

    private fun openAppInfo(packageName: String): Boolean {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return startIntent(intent)
    }

    private fun requestUninstall(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_DELETE).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return startIntent(intent)
    }

    private fun startIntent(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val uri = Uri.parse("package:${applicationContext.packageName}")
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }
}
