package com.digaudio.digaudio

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge: Dart side pushes the latest engine state to
 * every active widget instance. One call per track switch + one per
 * play-state change. Called from [AudioEngine._onTrackChanged] and
 * a `playerStateStream` listener in `_DigaudioAppState.initState`.
 *
 * Channel: `digaudio/widget`, method `update` with arguments
 * `{title: String?, artist: String?, isPlaying: bool}`.
 */
class WidgetChannel(private val context: Context) {
    companion object {
        private const val CHANNEL = "digaudio/widget"
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val title = call.argument<String?>("title")
                        val artist = call.argument<String?>("artist")
                        val isPlaying = call.argument<Boolean?>("isPlaying") ?: false
                        DigaudioWidgetProvider.pushUpdate(
                            context, title, artist, isPlaying
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
