package com.debdownplus.debdown_plus

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.Keep
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.debdownplus/download"
    private val REQUEST_PICK_FOLDER = 1001
    private var pendingResult: Result? = null
    private var pendingDownloadInfo: DownloadInfo? = null

    data class DownloadInfo(
        val url: String,
        val dir: String,
        val name: String,
        val format: String
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "download" -> handleDownload(call, result)
                "defaultDir" -> handleDefaultDir(result)
                "init" -> handleInit(call, result)
                "update" -> handleUpdate(call, result)
                "cancel" -> handleCancel(call, result)
                "shareFile" -> handleShareFile(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleDownload(call: MethodCall, result: Result) {
        val url = call.argument<String>("url") ?: ""
        val dir = call.argument<String>("dir") ?: ""
        val name = call.argument<String>("name") ?: ""
        val format = call.argument<String>("format") ?: "mp4"

        if (url.isBlank()) {
            result.error("NO_URL", "URL is empty", null)
            return
        }

        pendingResult = result
        pendingDownloadInfo = DownloadInfo(url, dir, name, format)

        // Cek permission dulu
        if (hasStoragePermission()) {
            // Langsung download - akan diproses di native thread via yt-dlp
            result.success("permission_granted")
        } else {
            requestStoragePermission()
        }
    }

    private fun handleDefaultDir(result: Result) {
        val downloadDir = getDownloadDirectory()
        result.success(downloadDir)
    }

    private fun handleInit(call: MethodCall, result: Result) {
        // Initialize yt-dlp binary, check updates, etc.
        Thread {
            try {
                // Copy yt-dlp binary from assets to app files dir
                copyYtDlpBinary()
                result.success("initialized")
            } catch (e: Exception) {
                result.error("INIT_FAILED", e.message, null)
            }
        }.start()
    }

    private fun handleUpdate(call: MethodCall, result: Result) {
        Thread {
            try {
                updateYtDlp()
                result.success("updated")
            } catch (e: Exception) {
                result.error("UPDATE_FAILED", e.message, null)
            }
        }.start()
    }

    private fun handleCancel(call: MethodCall, result: Result) {
        // Send cancel signal to download thread
        result.success(true)
    }

    private fun handleShareFile(call: MethodCall, result: Result) {
        val path = call.argument<String>("path") ?: ""
        val text = call.argument<String>("text") ?: ""

        if (path.isBlank()) {
            result.error("NO_PATH", "Path is null", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("NOT_FOUND", "File not found: $path", null)
            return
        }

        val uri = androidx.core.content.FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            file
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4" // atau detect dari extension
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(Intent.createChooser(shareIntent, "Share via"))
        result.success(true)
    }

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+: MANAGE_EXTERNAL_STORAGE
            Environment.isExternalStorageManager()
        } else {
            // Android 10 dan bawah
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+: Buka Settings untuk All Files Access
            val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            startActivityForResult(intent, REQUEST_PICK_FOLDER)
        } else {
            // Android 10-: Request WRITE_EXTERNAL_STORAGE
            requestPermissions(
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                REQUEST_PICK_FOLDER
            )
        }
    }

    private fun getDownloadDirectory(): String {
        // Prioritas 1: MediaStore Downloads/DebDown+
        val debDownDir = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "DebDown+")
        if (debDownDir.exists() || debDownDir.mkdirs()) {
            return debDownDir.absolutePath
        }

        // Fallback: App-specific external files
        val appDir = File(getExternalFilesDir(null), "DebDown+")
        if (appDir.exists() || appDir.mkdirs()) {
            return appDir.absolutePath
        }

        // Last resort: Internal storage
        val internalDir = File(filesDir, "DebDown+")
        internalDir.mkdirs()
        return internalDir.absolutePath
    }

    private fun copyYtDlpBinary() {
        // Copy yt-dlp binary from assets to app files dir
        // This is handled by flutter_assets or native lib
    }

    private fun updateYtDlp() {
        // Download latest yt-dlp binary
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PICK_FOLDER) {
            if (grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                pendingResult?.success("permission_granted")
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Storage permission required", null)
            }
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_FOLDER) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (Environment.isExternalStorageManager()) {
                    pendingResult?.success("permission_granted")
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "All files access required", null)
                }
            }
            pendingResult = null
        }
    }

    @Keep
    fun saveFileToMediaStore(fileName: String, mimeType: String, data: ByteArray): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/DebDown+")
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            uri?.let { outputUri ->
                resolver.openOutputStream(outputUri)?.use { it.write(data) }
            }
            outputUri
        } else {
            // Legacy: direct file write
            val file = File(getDownloadDirectory(), fileName)
            FileOutputStream(file).use { it.write(data) }
            Uri.fromFile(file)
        }
    }

    @Keep
    fun getSaveFileUri(fileName: String, mimeType: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/DebDown+")
            }
            resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
        } else {
            val file = File(getDownloadDirectory(), fileName)
            Uri.fromFile(file)
        }
    }
}