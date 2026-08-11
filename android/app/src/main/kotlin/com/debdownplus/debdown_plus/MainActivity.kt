package com.debdownplus.debdown_plus

import android.os.Environment
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {

    private var progressSink: EventChannel.EventSink? = null
    private var currentProcessId: String? = null
    private val initialized = java.util.concurrent.atomic.AtomicBoolean(false)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "debdown/ytdl")
        val events = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "debdown/ytdl/progress")
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink = events
            }

            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    // Init yt-dlp + ffmpeg on background thread (extracts bundled binaries)
                    Thread {
                        try {
                            initEngines()
                            val version = YoutubeDL.getInstance().versionName(applicationContext)
                            runOnUiThread { result.success(version) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("INIT", e.message ?: "init failed", null) }
                        }
                    }.start()
                }

                "update" -> {
                    // Auto-update yt-dlp engine from GitHub (stable channel)
                    Thread {
                        try {
                            initEngines()
                            val status = YoutubeDL.getInstance()
                                .updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel._STABLE)
                            val version = YoutubeDL.getInstance().versionName(applicationContext)
                            runOnUiThread {
                                progressSink?.success(
                                    mapOf("type" to "update", "status" to status.toString(), "version" to version)
                                )
                                result.success("$status|$version")
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                progressSink?.success(
                                    mapOf("type" to "update", "status" to "ERROR", "error" to (e.message ?: "update failed"))
                                )
                                result.error("UPDATE", e.message ?: "update failed", null)
                            }
                        }
                    }.start()
                }

                "download" -> {
                    val url = call.argument<String>("url") ?: ""
                    val dir = call.argument<String>("dir") ?: ""
                    val name = call.argument<String>("name") ?: ""
                    val format = call.argument<String>("format") ?: "mp4"
                    if (url.isBlank()) {
                        result.error("NO_URL", "URL is empty", null)
                        return@setMethodCallHandler
                    }
                    val processId = UUID.randomUUID().toString()
                    currentProcessId = processId

                    Thread {
                        try {
                            initEngines()
                            File(dir).mkdirs()

                            val request = YoutubeDLRequest(url)
                            request.addOption(
                                "-o",
                                if (name.isBlank()) "$dir/%(title)s.%(ext)s" else "$dir/$name.%(ext)s"
                            )
                            request.addOption("--no-mtime")
                            request.addOption("--newline")
                            request.addOption("--no-playlist")
                            request.addOption("--no-warnings")
                            if (format == "mp3") {
                                request.addOption("-x")
                                request.addOption("--audio-format", "mp3")
                                request.addOption("--audio-quality", "0")
                            } else {
                                request.addOption("-f", "bv*+ba/b")
                                request.addOption("--merge-output-format", "mp4")
                            }

                            runOnUiThread {
                                progressSink?.success(
                                    mapOf("type" to "download", "processId" to processId, "status" to "started", "progress" to 0.0)
                                )
                            }

                            val response = YoutubeDL.getInstance().execute(request, processId) { progress, _, line ->
                                runOnUiThread {
                                    progressSink?.success(
                                        mapOf(
                                            "type" to "download",
                                            "processId" to processId,
                                            "progress" to (progress / 100.0),
                                            "line" to line
                                        )
                                    )
                                }
                            }

                            runOnUiThread {
                                progressSink?.success(
                                    mapOf("type" to "download", "processId" to processId, "status" to "done", "progress" to 1.0)
                                )
                                result.success("$dir")
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                progressSink?.success(
                                    mapOf(
                                        "type" to "download",
                                        "processId" to processId,
                                        "status" to "error",
                                        "error" to (e.message ?: "download failed")
                                    )
                                )
                                result.error("DOWNLOAD", e.message ?: "download failed", null)
                            }
                        }
                    }.start()
                }

                "cancel" -> {
                    currentProcessId?.let {
                        try {
                            YoutubeDL.getInstance().destroyProcessById(it)
                        } catch (_: Exception) {
                        }
                    }
                    result.success(true)
                }

                "defaultDir" -> {
                    // Selalu pakai folder publik Download/DebDown+ biar ketemu file manager biasa
                    val base = File(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                        "DebDown+"
                    )
                    val path = base.absolutePath
                    // Coba bikin folder kalau belum ada (bisa gagal kalau permission denied)
                    try {
                        if (!base.exists()) base.mkdirs()
                    } catch (e: Exception) {
                        // Biarkan error-nya ditangani yt-dlp / engine-nya sendiri
                    }
                    result.success(path)
                }

                "shareFile" -> {
                    val path = call.argument<String>("path")
                    val text = call.argument<String>("text")
                    if (path == null) {
                        result.error("NO_PATH", "Path is null", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("NOT_FOUND", "File not found: $path", null)
                        return@setMethodCallHandler
                    }
                    val uri = androidx.core.content.FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        file
                    )
                    val send = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(android.content.Intent.EXTRA_STREAM, uri)
                        putExtra(android.content.Intent.EXTRA_TEXT, text ?: "")
                        addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(android.content.Intent.createChooser(send, "Share DebDown+ Logs"))
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    @Synchronized
    private fun initEngines() {
        if (!initialized.get()) {
            YoutubeDL.getInstance().init(applicationContext)
            FFmpeg.init(applicationContext)
            initialized.set(true)
        }
    }
}
