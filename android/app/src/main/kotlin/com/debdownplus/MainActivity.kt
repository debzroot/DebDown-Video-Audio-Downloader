package com.debdownplus

import android.content.Intent
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharingintent.ReceiveSharingIntentPlugin

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.debdownplus/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSharedText") {
                val text = getSharedText()
                result.success(text)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent != null && Intent.ACTION_SEND == intent.action) {
            val type = intent.type
            if (type != null && type.startsWith("text/")) {
                val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (sharedText != null && sharedText.isNotEmpty()) {
                    // Store shared text for Flutter to retrieve
                    ReceiveSharingIntentPlugin.sharedText = sharedText
                }
            }
        }
    }

    private fun getSharedText(): String? {
        return ReceiveSharingIntentPlugin.sharedText
    }
}