package com.digaudio.digaudio

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge to Android's built-in speech recogniser.
 * Channel `digaudio/voice`, method `recognize` → launches
 * `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` (Google's "Listening…"
 * dialog) and returns the first hypothesis as a String, or null if
 * cancelled / no recogniser installed / no audio captured.
 *
 * Uses the deprecated [Activity.startActivityForResult] /
 * [Activity.onActivityResult] pair (not `registerForActivityResult`)
 * because [MainActivity]'s compile-time superclass chain via
 * AudioServiceActivity → FlutterActivity → FragmentActivity does not
 * surface `ComponentActivity` in our module's classpath, so the
 * modern API fails to type-check. Activity-result API still works
 * fine; deprecation is cosmetic, not functional.
 */
class VoiceChannel(private val activity: Activity) {
    companion object {
        private const val CHANNEL = "digaudio/voice"
        const val REQUEST_CODE = 4242
    }

    private var pending: MethodChannel.Result? = null

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
                            @Suppress("DEPRECATION")
                            activity.startActivityForResult(intent, REQUEST_CODE)
                        } catch (_: Exception) {
                            pending = null
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Returns true iff this channel consumed the result (caller should
    /// short-circuit its own super.onActivityResult). False = unrelated
    /// request, fall through.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val p = pending ?: return true
        pending = null
        val text = if (resultCode == Activity.RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
        } else null
        p.success(text)
        return true
    }
}
