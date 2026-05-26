package com.digaudio.digaudio

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// AudioServiceActivity returns the shared FlutterEngine that the audio_service
// plugin caches (FlutterActivity's default per-activity engine fails the
// plugin's binary-messenger identity check).
class MainActivity : AudioServiceActivity() {
    private val voice = VoiceChannel(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MediaStoreChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        WidgetChannel(applicationContext).register(flutterEngine)
        AudioInfoChannel(applicationContext).register(flutterEngine)
        voice.register(flutterEngine)
    }

    // Deprecated activity-result delivery — kept because the modern
    // registerForActivityResult API needs ComponentActivity in the compile-
    // time superclass chain, which AudioServiceActivity's chain doesn't
    // expose to this module. See VoiceChannel kdoc.
    @Deprecated("VoiceChannel uses the pre-Jetpack Activity Result API")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!voice.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
