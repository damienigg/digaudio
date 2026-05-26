package com.digaudio.digaudio

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the active audio output routing + the system mixer's output sample
 * rate so the Dart UI can show "FLAC 24-bit/96 kHz → USB: FiiO Q3 · 96 kHz"
 * and surface silent resampling by colouring the line amber whenever the
 * source sample rate doesn't match what Android is mixing at.
 *
 * Channel: `digaudio/audio_info`, single method `getRouting()` →
 * `{deviceName, deviceType, outputSampleRate}`. Polled from Dart on every
 * track change — that's the unit at which the user cares about format /
 * routing, no live callback needed.
 */
class AudioInfoChannel(private val context: Context) {
    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "digaudio/audio_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRouting" -> result.success(getRouting())
                    else -> result.notImplemented()
                }
            }
    }

    private fun getRouting(): Map<String, Any?> {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val device = pickActive(am.getDevices(AudioManager.GET_DEVICES_OUTPUTS))
        val outRate = am.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull()
        return mapOf(
            "deviceName" to device?.productName?.toString(),
            "deviceType" to typeLabel(device?.type),
            "outputSampleRate" to outRate,
        )
    }

    /**
     * Android picks the active media sink by a hardware priority chain
     * (USB > BT A2DP > wired > built-in). Reproducing that priority on the
     * list returned by `getDevices(GET_DEVICES_OUTPUTS)` matches what
     * `AudioTrack.getRoutedDevice()` would return without us holding a
     * reference to the actual AudioTrack (which lives inside ExoPlayer).
     */
    private fun pickActive(devices: Array<AudioDeviceInfo>): AudioDeviceInfo? {
        val priority = intArrayOf(
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
        )
        for (t in priority) devices.firstOrNull { it.type == t }?.let { return it }
        return devices.firstOrNull()
    }

    private fun typeLabel(type: Int?): String = when (type) {
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired"
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Speaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Earpiece"
        else -> "Other"
    }
}
