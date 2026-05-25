package com.digaudio.digaudio

import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// AudioServiceActivity returns the shared FlutterEngine that the audio_service
// plugin caches (FlutterActivity's default per-activity engine fails the
// plugin's binary-messenger identity check).
class MainActivity : AudioServiceActivity() {
    private lateinit var voice: VoiceChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        // registerForActivityResult must be called before STARTED, so the
        // VoiceChannel is constructed in onCreate. configureFlutterEngine
        // (below) wires its MethodChannel handler once the engine exists.
        voice = VoiceChannel(this)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MediaStoreChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        WidgetChannel(applicationContext).register(flutterEngine)
        voice.register(flutterEngine)
    }
}
