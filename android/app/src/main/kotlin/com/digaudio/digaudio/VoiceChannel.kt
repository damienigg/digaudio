package com.digaudio.digaudio

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge to Android's built-in speech recogniser.
 * Channel `digaudio/voice`, method `recognize` → launches
 * `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` (Google's "Listening…"
 * dialog) and returns the first hypothesis as a String, or null if
 * cancelled / no recogniser installed / no audio captured.
 *
 * Activity-scoped (not applicationContext) because the launcher must
 * be registered before STARTED — see [register] usage in
 * [MainActivity.onCreate].
 */
class VoiceChannel(private val activity: ComponentActivity) {
    companion object {
        private const val CHANNEL = "digaudio/voice"
    }

    private var pending: MethodChannel.Result? = null

    private val launcher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { res ->
        val p = pending ?: return@registerForActivityResult
        pending = null
        val text = if (res.resultCode == Activity.RESULT_OK) {
            res.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
        } else null
        p.success(text)
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognize" -> {
                        if (pending != null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        pending = result
                        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                            putExtra(
                                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                            )
                            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                            putExtra(RecognizerIntent.EXTRA_PROMPT, "Search digaudio")
                        }
                        try {
                            launcher.launch(intent)
                        } catch (_: Exception) {
                            pending = null
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
