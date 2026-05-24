package com.digaudio.digaudio

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// AudioServiceActivity returns the shared FlutterEngine that the audio_service
// plugin caches (FlutterActivity's default per-activity engine fails the
// plugin's binary-messenger identity check).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MediaStoreChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
